extends Node

## 殿阁/全功能点击探针（HEADLESS 无窗口 · 单账号由环境变量 HALL_PROBE_ID 指定）· 2026-09-14 v3
##
## 用法：
##   godot --headless --path <proj> --scene res://tests/ui_hall_probe.tscn
##   并设置环境变量 HALL_PROBE_ID=<账号id>（如 acc_full / acc_1787418081）
##   （若未设置 HALL_PROBE_ID，则枚举 user://profiles 下所有账号依次跑）
##
## 每步立即 flush 落盘到固定绝对路径。真·死循环会卡死主线程，
## 由外层 runner 超时杀进程，日志最后一行即元凶。
##
## 日志：E:/Xiuxian/taixuanzongmenlu/.workbuddy/rig_art3/_hall_probe.log

const LOG_PATH := "E:/Xiuxian/taixuanzongmenlu/.workbuddy/rig_art3/_hall_probe.log"

const HALLS: Array = [
	"xichi", "yushou", "zhenfa", "tanwei", "cangjing", "zhifa",
	"gongxun", "lingtian", "kuangmai", "dantang", "qitang", "yuying", "futang",
]
const TABS: Array = ["宗门", "弟子", "殿阁", "历练", "纪事"]

var _log_path: String = LOG_PATH


func _log(s: String) -> void:
	printerr(s)
	var f := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(_log_path, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(s)
		f.close()


func _settle(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var w := FileAccess.open(_log_path, FileAccess.WRITE)
	if w != null:
		w.store_line("=== 殿阁点击探针 v3 (headless) 启动 · %s ===" % Time.get_datetime_string_from_system())
		w.close()

	# 内部 watchdog（主线程若真死循环，此 timer 也卡住；真正兜底靠 runner 杀进程）
	var t := Timer.new()
	t.wait_time = 220.0
	t.one_shot = true
	t.timeout.connect(func() -> void:
		_log(">>>WATCHDOG 触发（进程未自然结束，疑为卡死）")
		get_tree().quit())
	add_child(t)
	t.start()

	if Game == null:
		_log(">>>FAIL Game 单例缺失")
		get_tree().quit()
		return

	var ids: Array = []
	var forced := OS.get_environment("HALL_PROBE_ID")
	if forced != "":
		if FileAccess.file_exists("user://profiles/%s/save.json" % forced):
			ids = [forced]
			_log(">>> 单账号模式: %s" % forced)
		else:
			_log(">>>FAIL 指定的 HALL_PROBE_ID=%s 无 save.json" % forced)
			get_tree().quit()
			return
	else:
		ids = _枚举账号()
		_log(">>> 枚举账号 %d 个: %s" % [ids.size(), ", ".join(ids)])

	if ids.is_empty():
		_log(">>> 无存档账号，退出")
		get_tree().quit()
		return

	for id in ids:
		await _run_account(str(id))

	_log(">>>PROBE_ALL_DONE 账号数=%d" % ids.size())
	get_tree().quit()


func _枚举账号() -> Array:
	var ids: Array = []
	var da := DirAccess.open("user://profiles")
	if da == null:
		_log(">>>WARN 无法打开 user://profiles")
		return ids
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if not name.begins_with(".") and da.current_is_dir():
			if FileAccess.file_exists("user://profiles/%s/save.json" % name):
				ids.append(name)
		name = da.get_next()
	da.list_dir_end()
	return ids


func _run_account(id: String) -> void:
	_log(">>>ACCOUNT_BEGIN %s" % id)
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		_log(">>>ACCOUNT_FAIL %s main.tscn 加载失败" % id)
		return
	var main: Node = ps.instantiate()
	add_child(main)
	await _settle(8)
	main._登录_进入({"id": id})
	# _登录_进入 -> _进入主界面 内部才会创建并赋值 新UI
	var tries := 0
	while tries < 120 and (main.get("新UI") == null):
		await _settle(2)
		tries += 1
	if main.get("新UI") == null:
		_log(">>>ACCOUNT_FAIL %s 新UI 未就绪" % id)
		main.queue_free()
		return

	var ui = main.get("新UI")
	var 门派等级 = Game.get("门派等级")
	var 弟子数 = Game.弟子列表.size() if Game.弟子列表 != null else 0
	var 殿数 = Game.司职列表.size() if (Game.司职列表 is Dictionary) else 0
	_log(">>>ACCOUNT_ENTERED %s 门派等级=%s 弟子=%d 司职=%d" % [id, str(门派等级), 弟子数, 殿数])

	ui._show_page("殿阁")
	await _settle(10)
	var pages = ui.get("_pages")
	var hall_page = (pages as Dictionary).get("殿阁", null) if (pages is Dictionary) else null
	if hall_page == null or not hall_page.has_method("_on_hotspot_pressed"):
		_log(">>>ACCOUNT_FAIL %s 殿阁页缺失" % id)
		main.queue_free()
		return

	for k in HALLS:
		_log(">>>HALL_OPEN_BEGIN %s/%s" % [id, k])
		hall_page._on_hotspot_pressed(str(k))
		await _settle(10)
		var btn_count: int = _count_detail_buttons(hall_page)
		_log(">>>HALL_OPEN_OK %s/%s btn_count=%d" % [id, k, btn_count])
		var clicked := {}
		var guard := 0
		while guard < 120:
			var btns: Array = _collect_detail_buttons(hall_page)
			var b: Button = null
			var bname: String = ""
			for cand in btns:
				var nm: String = "%s/%s" % [cand.name, cand.text if not cand.text.is_empty() else ""]
				if not clicked.has(nm):
					b = cand
					bname = nm
					break
			if b == null:
				break
			clicked[bname] = true
			_log(">>>BTN_CLICK_BEGIN %s/%s -> %s" % [id, k, bname])
			b.emit_signal("pressed")
			await _settle(8)
			_log(">>>BTN_CLICK_OK %s/%s -> %s" % [id, k, bname])
			if hall_page.has_method("_on_back_pressed"):
				hall_page._on_back_pressed()
			await _settle(3)
			hall_page._on_hotspot_pressed(str(k))
			await _settle(6)
			guard += 1
		if hall_page.has_method("_on_back_pressed"):
			hall_page._on_back_pressed()
		await _settle(4)

	_log(">>>ACCOUNT_HALLS_DONE %s" % id)

	for tab in TABS:
		_log(">>>TAB_OPEN_BEGIN %s/%s" % [id, tab])
		ui._show_page(tab)
		await _settle(10)
		var tbtns: Array = _collect_page_buttons(ui, tab)
		_log(">>>TAB_OPEN_OK %s/%s btn_count=%d" % [id, tab, tbtns.size()])
		var tclicked := {}
		var tguard := 0
		while tguard < 150:
			var btns: Array = _collect_page_buttons(ui, tab)
			var b: Button = null
			var bname: String = ""
			for cand in btns:
				var nm: String = "%s/%s" % [cand.name, cand.text if not cand.text.is_empty() else ""]
				if not tclicked.has(nm):
					b = cand
					bname = nm
					break
			if b == null:
				break
			tclicked[bname] = true
			_log(">>>TABBTN_CLICK_BEGIN %s/%s -> %s" % [id, tab, bname])
			b.emit_signal("pressed")
			await _settle(8)
			_log(">>>TABBTN_CLICK_OK %s/%s -> %s" % [id, tab, bname])
			ui._show_page(tab)
			await _settle(4)
			tguard += 1
		_log(">>>TAB_DONE %s/%s" % [id, tab])

	main.queue_free()
	await _settle(4)
	_log(">>>ACCOUNT_DONE %s" % id)


func _count_detail_buttons(hall_page) -> int:
	if hall_page == null:
		return 0
	var dr = hall_page.get("_detail_root")
	if dr == null or not is_instance_valid(dr):
		return 0
	return _collect_buttons(dr, []).size()


func _collect_detail_buttons(hall_page) -> Array:
	if hall_page == null:
		return []
	var dr = hall_page.get("_detail_root")
	if dr == null or not is_instance_valid(dr):
		return []
	return _collect_buttons(dr, [])


func _collect_page_buttons(ui, tab: String) -> Array:
	var page = ui.get("_pages")
	if page == null or not (page is Dictionary):
		return []
	var p = (page as Dictionary).get(tab, null)
	if p == null or not is_instance_valid(p):
		return []
	return _collect_buttons(p, [])


func _collect_buttons(n: Node, out: Array) -> Array:
	if n is Button:
		var b := n as Button
		var nm: String = str(b.name)
		if nm.begins_with("TabBtn") or nm.contains("Back") or b.text == "返回":
			pass
		else:
			out.append(b)
	for c in n.get_children():
		_collect_buttons(c, out)
	return out

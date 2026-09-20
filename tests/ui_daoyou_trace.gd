extends Node

## 道友 trace v6：精确复刻原始探针「宗门」Tab 的按钮点击循环（点每个新按钮→_show_page 重置→循环）
## 环境变量 HALL_PROBE_ID=<账号id>（默认 acc_1787418081）

const LOG_PATH := "E:/Xiuxian/taixuanzongmenlu/.workbuddy/rig_art3/_trace.log"

func _log(s: String) -> void:
	printerr(s)
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(s)
		f.close()

func _settle(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _collect_buttons(n: Node, out: Array) -> Array:
	if n is Button:
		var b := n as Button
		out.append(b)
	for c in n.get_children():
		_collect_buttons(c, out)
	return out

func _collect_page_buttons(ui, tab: String) -> Array:
	var page = ui.get("_pages")
	if page == null or not (page is Dictionary):
		return []
	var p = (page as Dictionary).get(tab, null)
	if p == null or not is_instance_valid(p):
		return []
	return _collect_buttons(p, [])

func _ready() -> void:
	var w := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if w != null:
		w.store_line("=== 道友 trace v6 启动（复刻宗门Tab点击循环） ===")
		w.close()

	if Game == null:
		_log("FAIL Game 缺失")
		get_tree().quit()
		return

	var id := OS.get_environment("HALL_PROBE_ID")
	if id == "":
		id = "acc_1787418081"
	_log("TRACE login id=%s" % id)

	var ps := load("res://main.tscn") as PackedScene
	var main := ps.instantiate()
	add_child(main)
	await _settle(8)
	main._登录_进入({"id": id})

	var tries := 0
	while tries < 120 and main.get("新UI") == null:
		await _settle(2)
		tries += 1
	var ui = main.get("新UI")
	if ui == null:
		_log("FAIL 新UI 未就绪")
		get_tree().quit()
		return

	ui._show_page("宗门")
	await _settle(10)

	var tclicked := {}
	var tguard := 0
	while tguard < 150:
		var btns: Array = _collect_page_buttons(ui, "宗门")
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
		_log(">>>TABBTN_CLICK_BEGIN %s" % bname)
		b.emit_signal("pressed")
		_log(">>>EMIT_OK %s" % bname)
		await _settle(8)
		_log(">>>TABBTN_CLICK_OK %s" % bname)
		ui._show_page("宗门")
		await _settle(4)
		tguard += 1
	_log(">>>TAB DONE guard=%d" % tguard)
	get_tree().quit()

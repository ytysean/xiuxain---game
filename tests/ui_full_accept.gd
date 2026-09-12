extends Node

## 全量 UI 真实渲染验收（**非 headless**）· 2026-09-12
##
## 目的：B 类 UI 布局重构 + A/B/C 类累计改动之后，对**每一个**界面做一次真实渲染巡检。
## 覆盖：首页 → 底部 5 Tab → `ENTRY_SUB_PAGES` 全部二级页（绕过 gating 全量）→ 6 个特例页
##       → 首页入口路由完备性（静态，查「有入口无落点」）。
##
## 每页：① 标记 PAGE_BEGIN/END（便于把 SCRIPT ERROR 归属到页）
##       ② 递归扫描 Control 树（`_walk`），跑 3 条自动断言 + 截图（0.5 缩放 → 540×960）
##
## 三条自动断言（均只查 Control，且都排除了滚动容器内的正常溢出）：
##   BADSCROLL  ScrollContainer 且 size.x<60 或 size.y<60
##              → 根 Control + 直接 add_child 的老写法下，ScrollContainer 最小尺寸为 0
##                会被压成 0×0，clip_contents=true 把正文整块裁掉。**不报错、肉眼像空白页**。
##   OVERFLOW   Control 且 size.y>2800，且祖先链上无 ScrollContainer → 无滚动宿主的超高节点。
##   OFFSCREEN  可见且有尺寸（>4px）、却**纵向**出视口，且祖先链上无 ScrollContainer。
##              两个必须知道的收窄（否则误报）：
##                ① 排除 SubViewport 内节点（ov.get_viewport() != get_viewport()）——
##                   子视口坐标系与主视口矩形不可比，否则天下舆图页误报 28 条；
##                ② 只判纵向 —— 横向越界在本项目多为设计使然（可平移的地图画布、
##                   屏外待滑入的详情浮层），判横向噪声过大。
##
## 用法：<godot> --path <proj> --scene res://tests/ui_full_accept.tscn   ← 不要 --headless
##       （--headless 是 dummy 渲染器，本 harness 会失去意义）
## 判据：出现 >>>ACCEPT_ALL_DONE，且 SCRIPT_ERROR=0、PARSE_ERROR=0、
##       COLLAPSE=0、BADSCROLL=0、OVERFLOW=0、OFFSCREEN=0、PAGE_FAIL=0。
## 产物：res://accept_shots_full/*.png（64 张）+ 逐页 >>>SCAN 行。
##
## 历史：2026-09-12 首次运行即抓出 26 个页面的布局缺陷，分 4 批修复
##       （20 页内容区整块空白 / 5 页详情面板出屏 / 1 页 UIHint 悬空引用 /
##        1 页输入栏出屏）。全部缺陷在 `gate_all.py` **全绿**时依然存在。

const OUT_DIR := "res://accept_shots_full/"
const SHOT_SCALE := 0.5
const TABS: Array = ["宗门", "弟子", "殿阁", "历练", "纪事"]

var _ui: Node = null
var _shots: Array = []
var _issues: Array = []
var _stats: Array = []


func _ready() -> void:
	prints("=== 全量 UI 真实渲染验收启动 ===")
	_ensure_dir()

	# 自毁兜底（探针抛异常时 quit 不执行 → 永久挂死窗口）
	var t := Timer.new()
	t.wait_time = 420.0
	t.one_shot = true
	t.timeout.connect(func() -> void:
		printerr(">>>ACCEPT TIMEOUT 自毁触发")
		_report("TIMEOUT")
		get_tree().quit())
	add_child(t)
	t.start()

	if Game == null:
		printerr(">>>FAIL Game 单例缺失")
		get_tree().quit()
		return
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		printerr(">>>FAIL main.tscn 加载失败")
		get_tree().quit()
		return
	var main: Node = ps.instantiate()
	add_child(main)
	await _settle(6)

	main._登录_进入({"id": "acc_full"})
	await _settle(14)
	_ui = main.get("新UI")
	if _ui == null:
		printerr(">>>FAIL 新UI 为空")
		get_tree().quit()
		return
	prints(">>> 进入游戏 · 弟子=", Game.弟子列表.size(), " 灵石=", Game.灵石)

	# ── ① 首页 ──
	prints(">>>PAGE_BEGIN HOME")
	await _shot("00_home.png")
	_scan_page(_ui.get("_页_宗门"), "HOME")
	prints(">>>PAGE_END HOME")

	# ── ② 底部 5 Tab ──
	for tab in TABS:
		prints(">>>PAGE_BEGIN TAB:", tab)
		_ui._show_page(str(tab))
		await _settle(12)
		await _shot("TAB_%s.png" % str(tab))
		_scan_page(_ui.get("_current"), "TAB_" + str(tab))
		prints(">>>PAGE_END TAB:", tab)

	# ── ③ 全部二级页（直接 _show_sub_page，绕过 gating 以便全量覆盖）──
	var subs: Dictionary = _ui.ENTRY_SUB_PAGES
	var ids: Array = subs.keys()
	ids.sort()
	prints(">>> 二级页总数=", ids.size())
	var n := 0
	for id in ids:
		n += 1
		await _sub_step(str(id), subs[id], n)

	# ── ④ 特例页（非 ENTRY_SUB_PAGES 键）──
	await _special_step("X01_天下", "_open_world_map_page")
	await _special_step("X02_心弦", "_open_chat_page")
	await _special_step("X03_传讯中心", "_open_message_center")
	await _special_step("X04_宗主详情", "_open_master_detail")
	await _special_step("X05_玩家交易", "_open_player_trade_page")
	await _special_step("X06_离线管理", "_open_offline_manager_page")

	# ── ⑤ 首页入口路由完备性（静态）──
	_check_entry_routing()

	_report("DONE")
	prints(">>>ACCEPT_ALL_DONE")
	get_tree().quit()


# ══════════════ 步骤 ══════════════

func _sub_step(id: String, scene: PackedScene, idx: int) -> void:
	prints(">>>PAGE_BEGIN SUB:", id)
	_ui._show_sub_page(id, scene)
	await _settle(11)
	var cur: Node = _ui.get("_current_sub")
	if cur == null:
		_issues.append("SUB_NULL " + id)
		prints(">>>PAGE_FAIL SUB", id, "current_sub=null（实例化失败或未 add_child）")
	else:
		_scan_page(cur, "SUB_" + id)
	await _shot("S%02d_%s.png" % [idx, id])
	prints(">>>PAGE_END SUB:", id)


func _special_step(tag: String, method: String) -> void:
	prints(">>>PAGE_BEGIN SP:", tag)
	if not _ui.has_method(method):
		_issues.append("NO_METHOD " + method)
		prints(">>>PAGE_FAIL 无方法", method)
	else:
		_ui.call(method)
		await _settle(14)
		var cur: Node = _ui.get("_current_sub")
		if cur == null:
			_issues.append("SPECIAL_NULL " + tag)
			prints(">>>PAGE_FAIL SP", tag, "current_sub=null")
		else:
			_scan_page(cur, "SP_" + tag)
		await _shot("%s.png" % tag)
	prints(">>>PAGE_END SP:", tag)


# ══════════════ 扫描 ══════════════

func _scan_page(root: Node, tag: String) -> void:
	if root == null:
		_issues.append("SCAN_NULL " + tag)
		prints(">>>SCAN", tag, "root=null")
		return
	var st: Dictionary = {"nodes": 0, "labels": 0, "vis": 0, "vlab": 0,
		"collapse": [], "tall": [], "badscroll": [], "overflow": [], "offscreen": []}
	_walk(root, st, 0)
	var line: String = ">>>SCAN %s nodes=%d labels=%d vis=%d vlab=%d collapse=%d tall=%d badscroll=%d overflow=%d offscreen=%d" % [
		tag, int(st["nodes"]), int(st["labels"]), int(st["vis"]),
		int(st["vlab"]), (st["collapse"] as Array).size(), (st["tall"] as Array).size(),
		(st["badscroll"] as Array).size(), (st["overflow"] as Array).size(),
		(st["offscreen"] as Array).size()]
	prints(line)
	_stats.append(line)
	for c in (st["collapse"] as Array):
		prints(">>>COLLAPSE", tag, "|", str(c))
		_issues.append("COLLAPSE %s :: %s" % [tag, str(c)])
	for tl in (st["tall"] as Array):
		prints(">>>TALL", tag, "|", str(tl))
	# ScrollContainer 塌成 0×0 = 内容被 clip 整块裁掉（页面「有节点但全黑」的根因）
	for bs in (st["badscroll"] as Array):
		prints(">>>BADSCROLL", tag, "|", str(bs))
		_issues.append("BADSCROLL %s :: %s" % [tag, str(bs)])
	for of in (st["overflow"] as Array):
		prints(">>>OVERFLOW", tag, "|", str(of))
		_issues.append("OVERFLOW %s :: %s" % [tag, str(of)])
	# 屏幕外：可见且**有尺寸**的控件，却整体落在视口之外 → 用户永远看不到
	for osk in (st["offscreen"] as Array):
		prints(">>>OFFSCREEN", tag, "|", str(osk))
		_issues.append("OFFSCREEN %s :: %s" % [tag, str(osk)])
	if int(st["vis"]) < 3:
		prints(">>>SPARSE", tag, "vis=", int(st["vis"]))
		_issues.append("SPARSE %s vis=%d" % [tag, int(st["vis"])])


func _walk(n: Node, st: Dictionary, d: int) -> void:
	if d > 16:
		return
	st["nodes"] = int(st["nodes"]) + 1
	var vis := false
	if n is Control:
		vis = (n as Control).is_visible_in_tree()
		if vis:
			st["vis"] = int(st["vis"]) + 1
	if n is ScrollContainer and vis:
		var sc := n as ScrollContainer
		if sc.size.x < 60.0 or sc.size.y < 60.0:
			(st["badscroll"] as Array).append("%s pos=%s size=%s clip=%s" % [
				sc.name, str(sc.position), str(sc.size), str(sc.clip_contents)])
	# 容器溢出：高度远超屏幕(1920) 且**祖先链上没有滚动容器** → 内容被硬裁（阵营声望修复前的签名）
	if n is Control and vis and not (n is ScrollContainer):
		var ov := n as Control
		if ov.size.y > 2800.0:
			var anc: Node = ov.get_parent()
			var in_scroll := false
			while anc != null:
				if anc is ScrollContainer:
					in_scroll = true
					break
				anc = anc.get_parent()
			if not in_scroll:
				var pcls: String = "null"
				if ov.get_parent() != null:
					pcls = ov.get_parent().get_class()
				(st["overflow"] as Array).append("%s size=%s parent=%s" % [
					ov.name, str(ov.size), pcls])
		# 屏幕外：有实际尺寸、可见，却整体落在视口之外（排除滚动容器内的正常内容溢出）。
		# 2026-09-12 第 2 批缺陷签名：BOTTOM_WIDE 漏写 offset_top → 控件被算到父容器底边之外。
		# BADSCROLL 只查 ScrollContainer、OVERFLOW 只查 size.y>2800，都看不见这一类。
		# SubViewport 内的节点用子视口坐标系，与主视口矩形不可比 → 跳过（否则地图页整列误报）
		if ov.size.x > 4.0 and ov.size.y > 4.0 and ov.get_viewport() == get_viewport():
			var gr: Rect2 = ov.get_global_rect()
			var vr: Rect2 = get_viewport().get_visible_rect()
			var anc2: Node = ov.get_parent()
			var in_scroll2 := false
			while anc2 != null:
				if anc2 is ScrollContainer:
					in_scroll2 = true
					break
				anc2 = anc2.get_parent()
			if not in_scroll2:
				# 只判**纵向**出界。横向越界在本项目多为设计使然（可平移的大地图画布、
				# 屏外待滑入的详情浮层），噪声过大；而纵向越界几乎必是缺陷
				# （实例：page_daoyou 输入栏被算到 y=1795 > 二级页可视高 1762，整条不可见）。
				if gr.position.y >= vr.size.y or gr.end.y <= 0.0:
					var pn: String = "null"
					if ov.get_parent() != null:
						pn = ov.get_parent().get_class()
					(st["offscreen"] as Array).append("cls=%s rect=%s parent=%s" % [
						ov.get_class(), str(gr), pn])
	if n is Label:
		var lb := n as Label
		st["labels"] = int(st["labels"]) + 1
		if vis:
			st["vlab"] = int(st["vlab"]) + 1
			var tx: String = lb.text.strip_edges()
			var w: float = lb.size.x
			var h: float = lb.size.y
			var wrap: int = lb.autowrap_mode
			if wrap != TextServer.AUTOWRAP_OFF and tx.length() > 4 and w < 12.0:
				(st["collapse"] as Array).append("%s w=%.1f h=%.1f '%s'" % [
					lb.name, w, h, tx.substr(0, 12)])
			if wrap != TextServer.AUTOWRAP_OFF and h > 260.0:
				(st["tall"] as Array).append("%s w=%.1f h=%.1f '%s'" % [
					lb.name, w, h, tx.substr(0, 12)])
	for c in n.get_children():
		_walk(c, st, d + 1)


# ══════════════ 路由完备性（静态，查「有入口无落点」）══════════════

func _check_entry_routing() -> void:
	var home: GDScript = load("res://ui/sect_home_page.gd") as GDScript
	if home == null:
		_issues.append("ROUTE 读不到 sect_home_page.gd")
		return
	# 常量不在属性表里 → 必须走 get_script_constant_map()
	var cmap: Dictionary = home.get_script_constant_map()
	var all: Array = []
	for key in ["ENTRIES_LEFT", "ENTRIES_RIGHT", "QUICK_ENTRIES", "MORE_ENTRIES"]:
		var arr: Array = cmap.get(key, [])
		for e in arr:
			if e is Dictionary:
				all.append(str((e as Dictionary).get("id", "")))
	# MORE_GROUPS（B2 分组后的真源）结构 = {"组名": String, "入口": [id...]}
	for g in cmap.get("MORE_GROUPS", []):
		if g is Dictionary:
			for e in (g as Dictionary).get("入口", []):
				if e is Dictionary:
					all.append(str((e as Dictionary).get("id", "")))
				else:
					all.append(str(e))

	var subs: Dictionary = _ui.ENTRY_SUB_PAGES
	var alias: Dictionary = _ui.ENTRY_ALIAS
	var page_ids: Array = _ui.PAGE_IDS
	var seen: Dictionary = {}
	var un: Array = []
	var dup: Array = []
	for id in all:
		if id == "" or id == "更多":
			continue
		if seen.has(id):
			if not dup.has(id):
				dup.append(id)
			continue
		seen[id] = true
		var 落点: String = str(alias.get(id, id))
		var ok: bool = (id == "天下") or subs.has(id) or (落点 in page_ids) or (id in page_ids)
		if not ok:
			un.append(id)
	prints(">>>ROUTE 入口(含组)=%d 唯一=%d 无落点=%d 重复=%d" % [
		all.size(), seen.size(), un.size(), dup.size()])
	if un.size() > 0:
		var s1 := ""
		for u in un:
			s1 += str(u) + " "
		prints(">>>ROUTE_UNMAPPED ", s1)
		_issues.append("ROUTE_UNMAPPED %d: %s" % [un.size(), s1])
	if dup.size() > 0:
		var s2 := ""
		for u in dup:
			s2 += str(u) + " "
		prints(">>>ROUTE_DUP ", s2)
		_issues.append("ROUTE_DUP: " + s2)


# ══════════════ 工具 ══════════════

func _ensure_dir() -> void:
	var abs := ProjectSettings.globalize_path(OUT_DIR)
	if not DirAccess.dir_exists_absolute(abs):
		DirAccess.make_dir_recursive_absolute(abs)


func _settle(n: int) -> void:
	for i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	if vp == null or vp.get_texture() == null:
		printerr(">>>SHOT FAIL 无 viewport/texture")
		return
	var img: Image = vp.get_texture().get_image()
	if img == null:
		printerr(">>>SHOT FAIL 无 image")
		return
	if SHOT_SCALE != 1.0:
		img.resize(int(img.get_width() * SHOT_SCALE), int(img.get_height() * SHOT_SCALE),
			Image.INTERPOLATE_LANCZOS)
	var err: int = img.save_png(OUT_DIR + name)
	_shots.append("%s err=%d size=%s" % [name, err, str(img.get_size())])
	prints(">>>SHOT", name, "err=", err, "size=", str(img.get_size()))


func _report(tag: String) -> void:
	prints(">>>ISSUES_BEGIN n=", _issues.size())
	for i in _issues:
		prints(">>>  ISSUE ", str(i))
	prints(">>>ISSUES_END")
	prints(">>>SHOTS_BEGIN n=", _shots.size())
	for s in _shots:
		prints(">>>  SHOT ", str(s))
	prints(">>>SHOTS_END tag=", tag)

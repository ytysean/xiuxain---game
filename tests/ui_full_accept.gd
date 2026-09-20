extends Node

## 全量 UI 真实渲染验收（**非 headless**）· 2026-09-12
##
## 目的：B 类 UI 布局重构 + A/B/C 类累计改动之后，对**每一个**界面做一次真实渲染巡检。
## 覆盖：首页 → 底部 5 Tab → `ENTRY_SUB_PAGES` 全部二级页（绕过 gating 全量）→ 6 个特例页
##       → 首页入口路由完备性（静态，查「有入口无落点」）。
##
## 每页：① 标记 PAGE_BEGIN/END（便于把 SCRIPT ERROR 归属到页）
##       ② 递归扫描 Control 树（`_walk`），跑 3 条自动断言 + 截图（1.0 倍 → 720×1280 全解析度）
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
# 2026-09-16：0.5 → 1.0。开发期窗口 override = 720×1280（见 project.godot），
# backbuffer 即 720×1280，再 ×0.5 只剩 360×640 ⇒ 字号/圆角/描边细节全糊，无法用于 UI 精修审查。
const SHOT_SCALE := 1.0
const TABS: Array = ["宗门", "弟子", "殿阁", "历练", "纪事"]

# 动作型入口：点下去执行的是**当前页的动作**（如「隐藏UI」切换视图），本就不该有页面落点，
# 不参与「有入口无落点」判定。2026-09-16 加：此前被误报为 ROUTE_UNMAPPED。
const ACTION_ENTRIES: Array = ["隐藏UI"]
# 允许跨区重复：同一 id 在「一级入口（首页左右列 / dock）」与「更多」索引里各有一份，
# 属刻意双重入口。依据：老大 2026-09-15 定「幻形」换肤高频 → dock 留一级，更多面板再索引一份。
const DUP_ALLOWED: Array = ["幻形"]

var _ui: Node = null
var _shots: Array = []
var _issues: Array = []
var _stats: Array = []


func _ready() -> void:
	# ★ 2026-09-15 老大定：验收探针不许弹窗打扰 → 立即把窗口移出屏幕。
	#   本 harness 必须真实渲染（--headless 是 dummy 渲染器，会失去意义），故只挪位置不降级。
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)
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

	# ★ 2026-09-16：关键 UI 状态必须由探针**强制种值**，不能依赖存档。
	#   实证：本 harness 会走到「传讯中心」页 → MessageSystem 标记全部已读 → 退出时存档，
	#   于是下一轮的首页未读数恒为 0，顶栏未读角标整轮不出现 ⇒ 截图关卡对这块彻底失去回归能力
	#   （本轮排查红点时正是被这个「存档漂移」误导，误以为角标没渲染出来）。
	if is_instance_valid(Game) and Game.消息系统 != null:
		Game.消息系统.发送宗门传令("验收探针", "强制种未读：用于量测顶栏未读角标")
		Game.消息系统.发送宗门传令("验收探针", "强制种未读：用于量测顶栏未读角标")
	var _tbn: Node = _ui.get("_top_bar")
	if _tbn != null and _tbn.has_method("refresh"):
		_tbn.call("refresh")
	prints(">>> 种未读后 未读数=", Game.消息系统.获取总未读数())

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
		if str(tab) == "弟子":
			_probe_disciple()
		if str(tab) == "殿阁":
			_probe_building()
		if str(tab) == "历练":
			_probe_pfix_b1(_ui.get("_current"), "TAB_历练")
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
		if str(id) == "坊市":
			_probe_shop_s1(cur)
			_probe_shop_s2(cur)
		elif str(id) == "灵钓":
			_probe_fishing(cur)
		elif str(id) == "宗主管理":
			_probe_pfix_b1(cur, "SUB_宗主管理")
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


# 祖先链上是否存在「滚动容器」或「clip_contents = true」的容器。
# 语义：本节点越界若已被祖先裁剪，即属设计内容（可平移的大地图画布、屏外待滑入浮层），
# 不是缺陷；反之「容器漏设滚动/裁剪」才是缺陷签名，故不会误伤。
func _祖先链有裁剪容器(n: Node) -> bool:
	var a: Node = n.get_parent()
	while a != null:
		if a is ScrollContainer:
			return true
		if a is Control and (a as Control).clip_contents:
			return true
		a = a.get_parent()
	return false


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
		# 2026-09-16 收窄：祖先链上有「滚动容器」或「clip_contents=true」的容器 ⇒ 本节点越界属
		# **被裁剪的设计内容**（天下页大地图画布 4000² + 屏外待滑入的地图点位），不是缺陷。
		# 反过来：真缺陷的签名恰恰是「容器漏设滚动/裁剪」，故不会误伤。
		# 实证：该收窄一次消掉天下页 42 条 OVERFLOW/OFFSCREEN 误报，其余页面计数 0 变化。
		var 被裁剪: bool = _祖先链有裁剪容器(ov)
		if ov.size.y > 2800.0 and not 被裁剪:
			var pcls: String = "null"
			if ov.get_parent() != null:
				pcls = ov.get_parent().get_class()
			(st["overflow"] as Array).append("%s size=%s parent=%s" % [
				ov.name, str(ov.size), pcls])
		# 屏幕外：有实际尺寸、可见，却整体落在视口之外（排除滚动容器内的正常内容溢出）。
		# 2026-09-12 第 2 批缺陷签名：BOTTOM_WIDE 漏写 offset_top → 控件被算到父容器底边之外。
		# BADSCROLL 只查 ScrollContainer、OVERFLOW 只查 size.y>2800，都看不见这一类。
		# SubViewport 内的节点用子视口坐标系，与主视口矩形不可比 → 跳过（否则地图页整列误报）
		if ov.size.x > 4.0 and ov.size.y > 4.0 and ov.get_viewport() == get_viewport() and not 被裁剪:
			var gr: Rect2 = ov.get_global_rect()
			var vr: Rect2 = get_viewport().get_visible_rect()
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


# ══════════════ 搭车探针（02 弟子页 · 幻影族/margin 实测）══════════════

## ★ 2026-09-17 02 弟子页施工搭车探针（零额外 Godot：并入本渲染跑）。
##   打印三值；判据锚在目标节点本身（get_parent()），禁页级存在性：
##     [1] _list_root.get_parent() 名/类 + 四边距实测（钩子包 MarginWrap 后应见 24/24/12/12）
##     [2] 底垫 BottomSafeGap.custom_minimum_size
##     [3] DecisionPanel 底缘 与 底部 Tab 栏上沿 的实测差值
func _probe_disciple() -> void:
	var page: Node = _ui.get("_current")
	if page == null:
		prints(">>>PROBE_DISCIPLE FAIL page=null")
		return
	var lr: Node = page.get("_list_root")
	if lr == null or not (lr is Control):
		prints(">>>PROBE_DISCIPLE FAIL _list_root null/非Control")
		return
	var lc := lr as Control
	var wrap: Node = lc.get_parent()
	var wn := "<null>"
	var wcls := "<null>"
	var ml := -1
	var mr := -1
	var mt := -1
	var mb := -1
	if wrap != null:
		wn = String(wrap.name)
		wcls = wrap.get_class()
		if wrap is Control:
			var wc := wrap as Control
			ml = wc.get_theme_constant("margin_left")
			mr = wc.get_theme_constant("margin_right")
			mt = wc.get_theme_constant("margin_top")
			mb = wc.get_theme_constant("margin_bottom")
	prints(">>>PROBE_DISCIPLE [1] parent=", wn, "/", wcls, " margins_LRTB=", ml, "/", mr, "/", mt, "/", mb, " lr_global=", lc.get_global_rect())
	var gap: Node = lc.find_child("BottomSafeGap", true, false)
	if gap is Control:
		var gc := gap as Control
		prints(">>>PROBE_DISCIPLE [2] BottomSafeGap cms=", gc.custom_minimum_size, " size=", gc.size, " global_y=", gc.global_position.y)
	else:
		prints(">>>PROBE_DISCIPLE [2] BottomSafeGap NOT_FOUND")
	var dp: Node = lc.find_child("DecisionPanel", true, false)
	var bar: Node = _ui.get("_bottom_bar")
	if dp is Control and bar is Control:
		var dc := dp as Control
		var bc := bar as Control
		var dp_bottom: float = dc.global_position.y + dc.size.y
		var bar_top: float = bc.global_position.y
		prints(">>>PROBE_DISCIPLE [3] DP_bottom=", dp_bottom, " TabTop=", bar_top, " gap=", bar_top - dp_bottom, " panel_size=", dc.size)
	else:
		prints(">>>PROBE_DISCIPLE [3] missing dp=", dp != null, " bar=", bar != null)

# ══════════════ 搭车探针（03 殿阁页 · S1 标题实测）══════════════

## ★ 2026-09-17 03 殿阁页施工搭车探针（并入本渲染跑，不新增 .gd ⇒ 门1 计数不变）。
##   实测打印 03 页标题 Label 的字号/字色 ⇒ 直接证明 S1「字号 33→45 且字色仍 #E8CE8A」。
##   判据锚在目标节点本身（Label 的 theme 实测），禁「读代码推断」代替实测。
func _probe_building() -> void:
	var page: Node = _ui.get("_current")
	if page == null:
		prints(">>>PROBE_BUILDING FAIL page=null")
		return
	var lb: Label = null
	for n in page.find_children("*", "Label", true, false):
		var l := n as Label
		if l != null and l.text.strip_edges() == "◆ 宗门殿阁 ◆":
			lb = l
			break
	if lb == null:
		var t: Node = page.find_child("Title", true, false)
		if t is Label:
			lb = t as Label
	if lb == null:
		prints(">>>PROBE_BUILDING FAIL 未找到标题 Label（text=◆ 宗门殿阁 ◆ / name=Title）")
		return
	prints(">>>PROBE_BUILDING [1] text=", lb.text,
		" font_size=", lb.get_theme_font_size("font_size"),
		" font_color=", lb.get_theme_color("font_color"),
		" global_pos=", lb.global_position, " size=", lb.size)

# ══════════════ 搭车探针（04 坊市页 · S1 区标 / S2 去重 实测）══════════════

## ★ 2026-09-17 04 坊市页施工搭车探针（并入本渲染跑，不新增 .gd ⇒ 门1 计数不变）。
##   S1：区标 `GroupLabel_*` 实测字号/字色 ⇒ 证 `apply_project_font`(27) → `apply_section_title`(33)、色仍 COLOR_TEXT_GOLD。
##   S2：「今日缘法」(`Tehui_*`) 与「本周上架」(`Card_*`) 的 shop_id 集交集 ⇒ 证同屏不重复。
##   判据锚在节点本身（Label theme 实测 / 卡名后缀集合），禁读码推断。
func _probe_shop_s1(page: Node) -> void:
	var n := 0
	for c in page.find_children("GroupLabel_*", "Label", true, false):
		var lb := c as Label
		if lb == null:
			continue
		n += 1
		prints(">>>PROBE_SHOP_S1 [", lb.name, "] text=", lb.text,
			" font_size=", lb.get_theme_font_size("font_size"),
			" font_color=", lb.get_theme_color("font_color"))
	if n == 0:
		prints(">>>PROBE_SHOP_S1 FAIL 未找到 GroupLabel_* Label")

func _probe_shop_s2(page: Node) -> void:
	var host: Node = page.get("_scroll_vbox")
	var 特惠: Dictionary = {}
	var 上架: Dictionary = {}
	for c in page.find_children("*", "", true, false):
		if host != null and c.get_parent() != host:
			continue
		var nm := String(c.name)
		if nm.begins_with("Tehui_"):
			特惠[nm.substr(6)] = true
		elif nm.begins_with("Card_"):
			上架[nm.substr(5)] = true
	# ★ 原始「在售」集（未经 S2 过滤）—— 用于证明 S2 **真移除**，而非「本来就不重叠」的恒空假绿。
	var raw_ids: Dictionary = {}
	if page.has_method("_取灵石坊市在售"):
		for r in (page.call("_取灵石坊市在售") as Array):
			raw_ids[str((r as Dictionary).get("id", ""))] = true
	var 交集_raw: Array = []
	for k in 特惠.keys():
		if raw_ids.has(k):
			交集_raw.append(k)
	var 交集_上架: Array = []
	for k in 特惠.keys():
		if 上架.has(k):
			交集_上架.append(k)
	prints(">>>PROBE_SHOP_S2 host=", host != null, " 特惠卡=", 特惠.size(),
		" 在售原始=", raw_ids.size(), " 上架卡=", 上架.size(),
		" 原始交集=", 交集_raw.size(), " 上架交集=", 交集_上架.size(),
		" 原始交集项=", str(交集_raw))

## 05 灵钓页探针（F1/F2/F3/F4）：全部实测，禁以读码代替。
##   F2 顶栏：建顶栏产物 Title(font_size=45) + BackBtn(含 BackIcon 返回环)
##   F3 :110 内容标题 font_size=33；F4 _分隔 分节 font_size=33
##   F1 背景层 BGVeil 存在 + mouse_filter=IGNORE
func _probe_fishing(page: Node) -> void:
	# --- F2 顶栏标题 / 返回环 ---
	for c in page.find_children("Title", "Label", true, false):
		var lb := c as Label
		if lb == null:
			continue
		prints(">>>PROBE_FISH_F2_TITLE [", lb.name, "] path=", page.get_path_to(lb),
			" text=", lb.text,
			" font_size=", lb.get_theme_font_size("font_size"),
			" font_color=", lb.get_theme_color("font_color"))
	var 背钮: Array = page.find_children("BackBtn", "Button", true, false)
	var 环: int = 0
	if 背钮.size() > 0:
		环 = (背钮[0] as Button).find_children("BackIcon", "TextureRect", true, false).size()
	prints(">>>PROBE_FISH_F2_BACK 返回钮=", 背钮.size(), " 返回环BackIcon=", 环)
	# --- F3 内容标题（text 前缀「钓道境界：」）---
	var 内容命中: int = 0
	for c in page.find_children("*", "Label", true, false):
		var lb := c as Label
		if lb == null:
			continue
		if lb.text.begins_with("钓道境界："):
			内容命中 += 1
			prints(">>>PROBE_FISH_F3_CONTENT [", lb.name, "] text=", lb.text,
				" font_size=", lb.get_theme_font_size("font_size"),
				" font_color=", lb.get_theme_color("font_color"))
	prints(">>>PROBE_FISH_F3_CONTENT 命中=", 内容命中)
	# --- F4 分节（_分隔 产物：text「灵钓大赛（周常）」）---
	var 分节命中: int = 0
	for c in page.find_children("*", "Label", true, false):
		var lb := c as Label
		if lb == null:
			continue
		if lb.text == "灵钓大赛（周常）":
			分节命中 += 1
			prints(">>>PROBE_FISH_F4_SECTION [", lb.name, "] text=", lb.text,
				" font_size=", lb.get_theme_font_size("font_size"),
				" font_color=", lb.get_theme_color("font_color"))
	prints(">>>PROBE_FISH_F4_SECTION 命中=", 分节命中)
	# --- F1 背景层 ---
	var 背景: Array = page.find_children("BGVeil", "TextureRect", true, false)
	var 背景存在: bool = 背景.size() > 0
	var 忽略: bool = false
	var 有纹理: bool = false
	if 背景存在:
		var tr := 背景[0] as TextureRect
		忽略 = (tr.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		有纹理 = (tr.texture != null)
	prints(">>>PROBE_FISH_F1_BG 存在=", 背景存在, " mouse_filter_IGNORE=", 忽略, " 有纹理=", 有纹理)

# ══════════════ 搭车探针（PH7-VIS-FIX 批1 · 丙-b「margin 真失效族」）══════════════

## ★ 2026-09-17 PH7-VIS-FIX 批1（丙-b）施工搭车探针（并入本渲染跑，不新增 .gd）。
##   枚举当前页全部「margin 宿主」：① 裸键 "margin"（改前特征，被静默忽略）
##   ② 带前缀 margin_*（改后特征，被入树钩子包 MarginWrap 后生效）。
##   对②打印 宿主→父链（应＝MarginWrap/MarginContainer）+ 父四边距回读（应＝GRID=12 或 GRID*2=24）。
##   另对 explore `_detail_content` / sect_manager `_content` 之子卡做定点 drill。
##   判据锚在宿主本身，禁页级存在性；禁以读码代替实测量。
func _probe_pfix_b1(page: Node, tag: String) -> void:
	if page == null:
		prints(">>>PROBE_PFIXB1 ", tag, " FAIL page=null")
		return
	var bare := 0
	var pref := 0
	var wraps := 0
	for n in page.find_children("*", "MarginContainer", true, false):
		if String(n.name) == "MarginWrap":
			wraps += 1
	for n in page.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null:
			continue
		if c.has_theme_constant_override("margin"):
			bare += 1
		var haspre: bool = (c.has_theme_constant_override("margin_left")
			or c.has_theme_constant_override("margin_right")
			or c.has_theme_constant_override("margin_top")
			or c.has_theme_constant_override("margin_bottom"))
		if not haspre:
			continue
		pref += 1
		var p: Node = c.get_parent()
		var pn := "<null>"
		var pc := "<null>"
		if p != null:
			pn = String(p.name)
			pc = p.get_class()
		prints(">>>PROBE_PFIXB1 ", tag, " host=", c.name, "/", c.get_class(),
			" parent=", pn, "/", pc, " wrap_margins=", c.get_theme_constant("margin_left"),
			"/", c.get_theme_constant("margin_right"), "/", c.get_theme_constant("margin_top"),
			"/", c.get_theme_constant("margin_bottom"))
	prints(">>>PROBE_PFIXB1 ", tag, " SUMMARY bare=", bare, " prefixed=", pref, " MarginWrap=", wraps)
	# 定点 drill：explore `_detail_content`
	var dc: Node = page.get("_detail_content")
	if dc is Control:
		var dcp: Node = (dc as Control).get_parent()
		var dcpn := "<null>"
		var dcpc := "<null>"
		if dcp != null:
			dcpn = String(dcp.name)
			dcpc = dcp.get_class()
		prints(">>>PROBE_PFIXB1 ", tag, " _detail_content parent=", dcpn, "/", dcpc)
	# 定点 drill：sect_manager `_content` 之子卡 child0（改前=VBox/VBoxContainer，改后=MarginWrap/MarginContainer）
	var cont: Node = page.get("_content")
	if cont is Node:
		var i := 0
		for card in (cont as Node).get_children():
			if i >= 3:
				break
			i += 1
			var cn := (card as Node)
			if cn.get_child_count() <= 0:
				prints(">>>PROBE_PFIXB1 ", tag, " card[", String(cn.name), "] child0=<none>")
			else:
				var c0: Node = cn.get_child(0)
				prints(">>>PROBE_PFIXB1 ", tag, " card[", String(cn.name), "] child0=",
					String(c0.name), "/", c0.get_class())


# ══════════════ 路由完备性（静态，查「有入口无落点」）══════════════

func _check_entry_routing() -> void:
	var home: GDScript = load("res://ui/sect_home_page.gd") as GDScript
	if home == null:
		_issues.append("ROUTE 读不到 sect_home_page.gd")
		return
	# 常量不在属性表里 → 必须走 get_script_constant_map()
	var cmap: Dictionary = home.get_script_constant_map()
	# all     = 全部入口 id（含 MORE_ENTRIES 映射表）→ 用于「无落点」检测
	# 显示列表 = 不含 MORE_ENTRIES 的「显示清单」（有序，供判重）
	# ★ 口径修正（2026-09-13）：MORE_ENTRIES 是 id→图标 映射表（_make_more_entry / 图标查找
	#   的单一数据源），MORE_GROUPS 是显示分组表，二者分工不同、42 项 id 必然重叠。
	#   原实现把两张表一起判重 → 恒报 ROUTE_DUP ×36（误报）。故重复检测只看显示清单。
	var all: Array = []
	var 显示列表: Array = []
	for key in ["QUICK_ENTRIES", "MORE_ENTRIES"]:
		var arr: Array = cmap.get(key, [])
		for e in arr:
			if e is Dictionary:
				var eid := str((e as Dictionary).get("id", ""))
				all.append(eid)
				if key != "MORE_ENTRIES":
					显示列表.append(eid)
	# MORE_GROUPS（B2 分组后的真源）结构 = {"组名": String, "入口": [id...]}
	for g in cmap.get("MORE_GROUPS", []):
		if g is Dictionary:
			for e in (g as Dictionary).get("入口", []):
				if e is Dictionary:
					var gid := str((e as Dictionary).get("id", ""))
					all.append(gid)
					显示列表.append(gid)
				else:
					all.append(str(e))
					显示列表.append(str(e))

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
			continue
		seen[id] = true
		var 落点: String = str(alias.get(id, id))
		var ok: bool = (id == "天下") or subs.has(id) or (落点 in page_ids) or (id in page_ids)
		if not ok and not (id in ACTION_ENTRIES):
			un.append(id)
	# 判重：仅在「显示列表」内部（不含 MORE_ENTRIES 映射表）
	var seen2: Dictionary = {}
	for id in 显示列表:
		if id == "" or id == "更多":
			continue
		if seen2.has(id):
			if not dup.has(id) and not (id in DUP_ALLOWED):
				dup.append(id)
			continue
		seen2[id] = true
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
	# ★ 2026-09-16：原先只等 n 个 process_frame —— 那是**帧数**，不是**时间**。
	#   而 UI 的入场/角标/切页动画全是**时间制**（tween 0.15~0.3s）。本 harness 的窗口
	#   在屏幕外、vsync 基本失效 ⇒ n 帧可能只过去十几毫秒，截图必然拍到动画中途
	#   （实测：顶栏未读角标被拍成 scale≈0.3 的小红点，肉眼看像「没渲染」）。
	#   故补一条时间下限，让「截图 = 动画终态」成为稳定前提。
	var t0: int = Time.get_ticks_msec()
	for i in n:
		await get_tree().process_frame
	var 余: int = 260 - (Time.get_ticks_msec() - t0)
	if 余 > 0:
		await get_tree().create_timer(float(余) / 1000.0).timeout
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

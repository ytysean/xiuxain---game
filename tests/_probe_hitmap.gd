extends Node
## 首页入口「真实命中图」扫描探针（真实渲染 · 窗口移出屏幕）。
## 用法：<godot> --path . res://tests/_probe_hitmap.tscn
##
## 背景：_probe_route 实测到「点 Entry_天下 的几何中心，却打开了坊市二级页」。
##       静态读代码（bind 正确 / 坐标正确）无法解释 ⇒ 必须把**真实命中图**扫出来：
##       沿两列纵轴逐点真实点击，记录每次打开了哪个二级页，与节点上报矩形对照。
##       若命中区整体下移一格 ⇒ 有覆盖层/坐标空间错位；
##       若命中区与矩形一致、只是 id 串位 ⇒ 是绑定/路由问题。

const 探针账号 := "__probe_hitmap__"

var _main: Node = null
var _ui: Node = null


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)

	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	_main._登录_进入({"id": 探针账号})
	await _settle(24)

	_ui = _main.get("新UI")
	if _ui == null:
		prints(">>>FAIL 新UI 为空")
		get_tree().quit()
		return

	prints("\n===== 视口 / 窗口 =====")
	var vp: Viewport = get_viewport()
	prints("viewport visible_rect = %s" % str(vp.get_visible_rect()))
	prints("viewport final_transform = %s" % str(vp.get_final_transform()))
	prints("window size = %s  position = %s" % [str(get_window().size), str(get_window().position)])
	prints("DisplayServer name = %s" % DisplayServer.get_name())

	prints("\n===== 首页入口钮上报几何 =====")
	var 钮表: Array = []
	_收集按钮(_ui.get("_page_container"), 钮表)
	var 入口钮: Array = []
	for b in 钮表:
		var bb: Button = b
		if not str(bb.name).begins_with("Entry_"):
			continue
		入口钮.append(bb)
		prints("  %-16s offsetrect=%s globalrect=%s visible=%s filter=%d z=%d" % [
			str(bb.name), str(bb.get_rect()), str(bb.get_global_rect()),
			str(bb.visible), int(bb.mouse_filter), bb.z_index])
		# 父链上是否有 MOUSE_FILTER_STOP 的兄弟/祖先盖住（真正「点不动 / 点错」的常见成因）
		var p: Node = bb.get_parent()
		while p != null and p != _ui:
			if p is Control:
				var pc: Control = p
				prints("      祖先 %-18s rect=%s filter=%d visible=%s" % [
					str(pc.name), str(pc.get_global_rect()), int(pc.mouse_filter), str(pc.visible)])
			p = p.get_parent()

	# ── A：直接 emit（绕过命中，只测路由/绑定）──
	prints("\n===== A · 直接 emit Entry_天下.pressed（测绑定/路由）=====")
	for b in 入口钮:
		var bb: Button = b
		_重置()
		await _settle(3)
		bb.pressed.emit()
		await _settle(6)
		prints("  emit %-16s → 二级页 = %s" % [str(bb.name), _名(_ui.get("_current_sub"))])

	# ── B：真实点击扫描（测命中）──
	prints("\n===== B · 左列 x=81 纵向扫描 =====")
	await _扫描(81.0, 240.0, 640.0, 20.0)
	prints("\n===== B · 右列 x=999 纵向扫描 =====")
	await _扫描(999.0, 240.0, 780.0, 20.0)

	get_tree().quit()


func _扫描(x: float, y0: float, y1: float, 步: float) -> void:
	var y: float = y0
	while y <= y1:
		_重置()
		await _settle(3)
		_点击(Vector2(x, y))
		await _settle(5)
		var s: String = _名(_ui.get("_current_sub"))
		prints("  点(%.0f, %.1f) → %s" % [x, y, s])
		y += 步


func _重置() -> void:
	if _ui != null and _ui.has_method("_close_sub_page"):
		_ui.call("_close_sub_page")


func _收集按钮(n: Node, 出: Array) -> void:
	if n is Button:
		出.append(n)
	for c in n.get_children():
		_收集按钮(c, 出)


func _名(n: Variant) -> String:
	if n == null:
		return "（无 / 回到一级页）"
	if n is Node:
		return str((n as Node).name)
	return str(n)


func _点击(点: Vector2) -> void:
	# ★ 踩坑记录（2026-09-15）：不能直接把「画布坐标」丢给 push_input！
	#   push_input(ev, false) 会用 get_final_transform().affine_inverse() 把事件
	#   从**窗口坐标**换算回画布坐标；本工程 画布=1080×1920 / 窗口=720×1280
	#   ⇒ final_transform 缩放 0.6667，直接传画布点会被再乘 1.5，
	#   于是「点 y=337 的天下」实际打在「y=506 的坊市」上（曾据此误报游戏 bug）。
	#   正确做法：先经 final_transform 把画布点映射成窗口点再 push。
	var 窗口点: Vector2 = get_viewport().get_final_transform() * 点
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = 窗口点
	ev.global_position = 窗口点
	get_viewport().push_input(ev)
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.pressed = false
	ev2.position = 窗口点
	ev2.global_position = 窗口点
	get_viewport().push_input(ev2)


func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

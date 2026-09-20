extends Node
## 「← 返回宗门」按钮为什么点不动 —— 引擎拾取级取证探针。
## 用法：<godot> --path . res://tests/_probe_backbtn2.tscn
##
## 已知：page_beast/page_chess/page_family/page_master … 共 20 页的
##       `← 返回宗门` 按钮，声明了 signal 返回主页、_on返回() 也 emit，
##       game_ui._show_sub_page 也 connect 了，但真实点击后页面不关。
##       ⇒ 用 Viewport.gui_get_hovered_control()（引擎自己的拾取）判定
##         「点它的中心，引擎认为命中的是谁」，从而区分：
##         ① 被上层 Control 遮挡  ② 按钮实际 rect 在别处  ③ 信号真没接上

const 待查 := ["灵兽", "宗主", "家族", "论道棋弈", "宗门时令"]
const 探针账号 := "__probe_backbtn2__"

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
	var 页面表: Dictionary = _ui.get_script().get_script_constant_map().get("ENTRY_SUB_PAGES", {})

	for id in 待查:
		if not 页面表.has(id):
			prints("\n===== %s 不在 ENTRY_SUB_PAGES =====" % id)
			continue
		prints("\n========== %s ==========" % id)
		_重置()
		await _settle(3)
		_ui.call("_show_sub_page", id, 页面表[id])
		await _settle(10)
		await _查一页(id)
		_重置()
		await _settle(3)

	get_tree().quit()


func _查一页(id: String) -> void:
	var sub: Control = _ui.get("_current_sub")
	if sub == null:
		prints("  打不开")
		return
	prints("  _current_sub = %s  rect=%s" % [str(sub.name), str(sub.get_global_rect())])
	prints("  signal 返回主页 存在 = %s" % str(sub.has_signal("返回主页")))
	if sub.has_signal("返回主页"):
		var c: Callable = Callable(_ui, "_on_二级页返回")
		prints("  返回主页 是否已被 connect = %s" % str(sub.返回主页.is_connected(c)))

	var 容器: Control = _ui.get("_sub_page_container")
	prints("  _sub_page_container rect=%s filter=%d" % [str(容器.get_global_rect()), int(容器.mouse_filter)])

	# 找「← 返回宗门」
	var 钮们: Array = []
	_收集按钮(sub, 钮们)
	var 目标: Button = null
	for b in 钮们:
		var bb: Button = b
		if bb.text.strip_edges().contains("返回"):
			目标 = bb
			break
	if 目标 == null:
		prints("  找不到含「返回」的按钮")
		return
	prints("  目标钮 text=「%s」 rect=%s visible=%s filter=%d disabled=%s" % [
		目标.text, str(目标.get_global_rect()), str(目标.visible),
		int(目标.mouse_filter), str(目标.disabled)])
	# 父链
	var p: Node = 目标.get_parent()
	while p != null and p != _ui:
		if p is Control:
			var pc: Control = p
			prints("    祖先 %-16s rect=%s filter=%d visible=%s" % [
				str(pc.name), str(pc.get_global_rect()), int(pc.mouse_filter), str(pc.visible)])
		p = p.get_parent()

	var c: Vector2 = 目标.get_global_rect().get_center()
	prints("  按钮中心（画布）= %s" % str(c))

	# ① 引擎拾取：先移鼠标，再读 hovered control
	var 窗: Vector2 = get_viewport().get_final_transform() * c
	var mv := InputEventMouseMotion.new()
	mv.position = 窗
	mv.global_position = 窗
	get_viewport().push_input(mv)
	await _settle(3)
	var hov: Control = get_viewport().gui_get_hovered_control()
	prints("  ② 引擎 hovered control = %s (%s)" % [
		str(hov.name) if hov != null else "null",
		str(hov.get_class()) if hov != null else "-"])

	# ② 真实点击
	_点击(c)
	await _settle(10)
	var 现: Variant = _ui.get("_current_sub")
	prints("  ③ 点击后 _current_sub = %s  _舆图回跳=%s" % [
		str((现 as Node).name) if 现 != null else "null（已关闭 ✓）",
		str(_ui.get("_舆图回跳"))])

	# ③ 若没关，直接 emit 复测，判断「信号没接」还是「点击没到」
	if 现 != null:
		prints("  → 改直接 emit 复测")
		目标.pressed.emit()
		await _settle(8)
		var 现2: Variant = _ui.get("_current_sub")
		prints("     emit 后 _current_sub = %s" % (
			str((现2 as Node).name) if 现2 != null else "null（已关闭 ✓ ⇒ 信号链路正常，是「点击没到按钮」）"))


func _重置() -> void:
	if _ui != null and _ui.has_method("_close_sub_page"):
		_ui.call("_close_sub_page")


func _收集按钮(n: Node, 出: Array) -> void:
	if n is BaseButton:
		出.append(n)
	for c in n.get_children():
		_收集按钮(c, 出)


func _点击(点: Vector2) -> void:
	var 窗: Vector2 = get_viewport().get_final_transform() * 点
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = 窗
	ev.global_position = 窗
	get_viewport().push_input(ev)
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.pressed = false
	ev2.position = 窗
	ev2.global_position = 窗
	get_viewport().push_input(ev2)


func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

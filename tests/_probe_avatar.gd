extends Node
## 宗主头像点击链路探针（真实渲染 · 窗口移出屏幕，不弹窗干扰）。
## 用法：<godot> --path . res://tests/_probe_avatar.tscn
## 目的：老大反馈「主角头像点了没反应」。代码链路看着是完整的
##       （AvatarHit → _on_avatar_pressed → _open_frame_select → _预热弹窗 → 唤起），
##       故须区分两种断点：① 点击被上层节点拦截；② 弹窗本身创建/唤起失败。
##       ⇒ 先走**真实鼠标事件**（push_input），若弹窗未出，再走直接信号 emit 复测。

const 探针账号 := "__probe_avatar__"

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)

	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	main._登录_进入({"id": 探针账号})
	await _settle(24)

	var ui: Node = main.get("新UI")
	if ui == null:
		prints(">>>FAIL 新UI 为空")
		get_tree().quit()
		return
	var top: Node = ui.get("_top_bar")
	if top == null:
		prints(">>>FAIL _top_bar 为空")
		get_tree().quit()
		return
	prints("TOPBAR visible=%s size=%s" % [str(top.visible), str(top.size)])

	var hit: Button = top.find_child("AvatarHit", true, false) as Button
	prints("HIT = %s" % str(hit))
	if hit == null:
		prints(">>>FAIL 找不到 AvatarHit 热区")
		get_tree().quit()
		return
	var 中心: Vector2 = hit.global_position + hit.size * 0.5
	prints("HIT visible=%s global=%s size=%s filter=%d 中心=%s" % [
		str(hit.visible), str(hit.global_position), str(hit.size), int(hit.mouse_filter), str(中心)])

	# 该点最上层能收到鼠标的 Control 是谁？（鼠标命中测试）
	var 命中: Control = __鼠标命中(ui, 中心)
	prints("该点最上层 Control = %s (%s)" % [
		str(命中.name) if 命中 != null else "null",
		str(命中.get_class()) if 命中 != null else "-"])

	# ① 真实鼠标事件（能测出「被遮挡」）
	var pop0: Variant = top.get("_popup_instance")
	prints("点击前 POPUP = %s" % str(pop0))
	_点击(中心)
	await _settle(10)
	var pop1: Variant = top.get("_popup_instance")
	prints("真实点击后 POPUP = %s  visible=%s" % [
		str(pop1), str((pop1 as Control).visible) if pop1 is Control else "-"])
	await _shot("_probe_avatar_real.png")

	# ② 若真实点击无效 → 直接 emit 复测，区分「被遮挡」vs「弹窗坏」
	if not (pop1 is Control) or not (pop1 as Control).visible:
		prints("→ 真实点击未生效，改用直接 emit 复测")
		hit.pressed.emit()
		await _settle(10)
		var pop2: Variant = top.get("_popup_instance")
		prints("直接 emit 后 POPUP = %s  visible=%s" % [
			str(pop2), str((pop2 as Control).visible) if pop2 is Control else "-"])
		await _shot("_probe_avatar_emit.png")
	else:
		prints("→ 真实点击即生效，链路正常")

	get_tree().quit()


## 自顶向下找命中最上层的可见 Control（近似 Godot 的 pick 顺序：后添加的在上）
func __鼠标命中(根: Node, 点: Vector2) -> Control:
	var 结果: Control = null
	for c in 根.get_children():
		var r: Control = _递归命中(c, 点)
		if r != null:
			结果 = r
	return 结果

func _递归命中(n: Node, 点: Vector2) -> Control:
	if n is Control:
		var c: Control = n
		if not c.visible or c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return null
		var r: Rect2 = Rect2(c.global_position, c.size)
		if not r.has_point(点):
			return null
		# 先看子节点（子节点在上）
		for ch in c.get_children():
			var inner: Control = _递归命中(ch, 点)
			if inner != null:
				return inner
		return c
	return null


func _点击(点: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = 点
	ev.global_position = 点
	get_viewport().push_input(ev)
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.pressed = false
	ev2.position = 点
	ev2.global_position = 点
	get_viewport().push_input(ev2)


func _shot(名: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		prints(">>>FAIL 截图为空 %s" % 名)
		return
	var err: int = img.save_png("res://accept_shots_full/" + 名)
	prints(">>>SAVED %s err=%d" % [名, err])


func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

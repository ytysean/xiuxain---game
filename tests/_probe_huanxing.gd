extends Node
## 幻形页（洞天换肤）探针：验证底部「穿戴」按钮的几何与可点性。
## 老大反馈「皮肤能点击但不能更换，以前设计了一个穿戴按钮」。
## 代码里 _wear_btn / _on_wear_pressed 都在，故须实测区分：
##   ① 按钮在容器可视区之外（玩家看不见）  ② 按钮可见但点击被拦截  ③ 状态刷新错
## 窗口移出屏幕，不弹窗打扰。

const 探针账号 := "__probe_hx__"

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

	var vp: Viewport = get_viewport()
	prints(">>> viewport=%s  window=%s  final_scale=%s  UI_SCALE=%s" % [
		str(vp.get_visible_rect().size), str(DisplayServer.window_get_size()),
		str(vp.get_final_transform().get_scale()), str(UITheme.UI_SCALE)])

	var 容器: Control = ui.get("_sub_page_container") as Control
	if 容器 != null:
		prints(">>> _sub_page_container  逻辑 global=%s size=%s  clip=%s" % [
			str(容器.global_position / UITheme.UI_SCALE),
			str(容器.size / UITheme.UI_SCALE),
			str(容器.clip_contents)])
	prints(">>> UITheme.TOPBAR_H=%d  TAB_H=%d  (逻辑 %.2f / %.2f)" % [
		UITheme.TOPBAR_H, UITheme.TAB_H,
		float(UITheme.TOPBAR_H) / UITheme.UI_SCALE, float(UITheme.TAB_H) / UITheme.UI_SCALE])

	# 打印 ui 直接子节点的层级（找出谁可能盖住二级页底栏）
	prints(">>> ui 直接子节点（顺序 = 绘制序，后者在上）：")
	for i in ui.get_child_count():
		var c: Node = ui.get_child(i)
		if c is CanvasItem:
			prints("      [%2d] %-24s vis=%-5s z=%-4d" % [
				i, c.name, str((c as CanvasItem).visible), (c as CanvasItem).z_index])

	# 探针账号是新档 ⇒ 只有默认皮肤（unlock=always）。拉高等级/累计游戏日解锁全部，
	# 否则 _on_card_pressed 会被 _is_owned 守卫挡掉（表面看就是「点了不变」）。
	Game.门派等级 = 99
	Game.累计游戏日 = 999

	ui.call("_on_首页入口", "幻形")
	await _settle(20)

	var s0: float = UITheme.UI_SCALE
	prints(">>> 主要容器几何（逻辑）：")
	for nm in ["PageContainer", "SubPageContainer", "TopBar", "BottomTabBar"]:
		var n: Node = ui.find_child(nm, false, false)
		if n is Control:
			var cc := n as Control
			prints("      %-18s global=%-22s size=%-20s vis=%-5s z=%d" % [
				nm, str(cc.global_position / s0), str(cc.size / s0), str(cc.visible), cc.z_index])

	var 页: Control = ui.get("_current_sub") as Control
	if 页 == null:
		prints(">>>FAIL 幻形页没打开")
		get_tree().quit()
		return
	var s: float = UITheme.UI_SCALE
	prints(">>> 幻形页 %s  逻辑 global=%s size=%s" % [
		页.name, str(页.global_position / s), str(页.size / s)])

	# ── 底栏与穿戴按钮 ──
	var bar: Control = 页.find_child("BottomBar", true, false) as Control
	if bar != null:
		prints(">>> BottomBar  逻辑 global=%s size=%s visible=%s" % [
			str(bar.global_position / s), str(bar.size / s), str(bar.visible)])
	else:
		prints(">>>FAIL 找不到 BottomBar")

	var btn: Button = 页.find_child("WearBtn", true, false) as Button
	if btn == null:
		prints(">>>FAIL 找不到 WearBtn")
		get_tree().quit()
		return
	var 中心: Vector2 = btn.global_position + btn.size * 0.5
	prints(">>> WearBtn  逻辑 global=%s size=%s visible=%s 中心=%s" % [
		str(btn.global_position / s), str(btn.size / s), str(btn.visible), str(中心 / s)])

	# 容器/屏幕上下界（像素），判断按钮是否落在可视区
	var 容器下界: float = 容器.global_position.y + 容器.size.y if 容器 != null else vp.get_visible_rect().size.y
	prints(">>> 像素：容器 y=[%.1f, %.1f]   按钮 y=[%.1f, %.1f]   %s" % [
		容器.global_position.y if 容器 != null else 0.0, 容器下界,
		btn.global_position.y, btn.global_position.y + btn.size.y,
		"✓在容器内" if (btn.global_position.y + btn.size.y) <= 容器下界 + 0.5 else "×超出容器下界"])

	# 引擎拾取：这个点真正归谁
	var 命中: Control = vp.gui_get_hovered_control()
	prints(">>> 引擎拾取(光标处)=%s" % (str(命中.name) if 命中 != null else "null"))
	var 命中2: Control = _拾取(vp, 中心)
	prints(">>> 引擎拾取(按钮中心)=%s" % (str(命中2.name) if 命中2 != null else "null"))

	# ── 状态刷新：选一个未装备的皮肤，看按钮文案 ──
	var 当前装备: String = str(页.get("_equipped_id"))
	prints(">>> 当前装备=%s  当前选中=%s" % [当前装备, str(页.get("_selected_id"))])
	var 目标 := "taixu_yunhai" if 当前装备 != "taixu_yunhai" else "qiu_jinfeng"
	页.call("_on_card_pressed", 目标)
	await _settle(6)
	var 标签: Label = 页.find_child("WearLabel", true, false) as Label
	prints(">>> 点选「%s」后：_selected=%s  按钮文案=%s" % [
		目标, str(页.get("_selected_id")), (标签.text if 标签 != null else "?")])

	# ── 点击前先截一张「未装备 / 穿戴」态底栏 —— 老大报"看不到"的就是这一态 ──
	await RenderingServer.frame_post_draw
	var img0: Image = vp.get_texture().get_image()
	var h0: int = img0.get_height()
	img0.get_region(Rect2i(0, h0 - 320, img0.get_width(), 320)).save_png("res://_probe_hx_wear.png")
	prints(">>>SAVED res://_probe_hx_wear.png（未装备 · 穿戴态）")

	# ── 真实点击按钮 ──
	var 装备前: String = str(页.get("_equipped_id"))
	_点击(中心)
	await _settle(8)
	prints(">>> 真实点击穿戴：装备 %s → %s   Game.当前皮肤=%s" % [
		装备前, str(页.get("_equipped_id")), str(Game.get("当前皮肤"))])

	# 截图（供人工比对）—— 存到项目根，便于直接查看
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.save_png("res://_probe_hx.png")
	# 再存一张裁掉底部 260px 的放大图，专看底栏那条
	var h: int = img.get_height()
	var 底: Image = img.get_region(Rect2i(0, h - 320, img.get_width(), 320))
	底.save_png("res://_probe_hx_bottom.png")
	prints(">>>SAVED res://_probe_hx.png  /  _probe_hx_bottom.png")

	get_tree().quit()

func _拾取(vp: Viewport, 点: Vector2) -> Control:
	var 候选: Array = []
	_递归(vp, 点, 候选)
	return 候选[0] if 候选.size() > 0 else null

func _递归(n: Node, 点: Vector2, 候选: Array) -> void:
	for c in n.get_children():
		if c is Control and (c as Control).visible:
			var cc := c as Control
			if cc.get_global_rect().has_point(点) and cc.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				候选.append(cc)
		_递归(c, 点, 候选)

func _点击(点: Vector2) -> void:
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
	for i in n:
		await get_tree().process_frame

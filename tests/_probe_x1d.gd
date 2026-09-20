extends Node

# 天下页 header 遮挡归因探针（真实渲染 · 窗口移出屏外 · 2026-09-16）

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)
	var t := Timer.new()
	t.wait_time = 120.0
	t.one_shot = true
	t.timeout.connect(func(): get_tree().quit(1))
	add_child(t)
	t.start()
	_跑.call_deferred()

func _跑() -> void:
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	var main: Node = ps.instantiate()
	add_child(main)
	for i in 6:
		await get_tree().process_frame
	main._登录_进入({"id": "acc_x1"})
	for i in 14:
		await get_tree().process_frame
	var ui: Node = main.get("新UI")
	if ui == null:
		print(">>>X1D_FAIL 新UI为空")
		get_tree().quit(1)
		return
	ui._open_world_map_page()
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# 找到页面内 header 的全局矩形
	var 页: Control = ui.get("_current_sub")
	if 页 == null:
		print(">>>X1D_FAIL current_sub 为空")
		get_tree().quit(1)
		return
	print(">>>X1D 页面global=", 页.get_global_rect(), " visible=", 页.visible)
	print(">>>X1D 页面子树前2层：")
	for ch in 页.get_children():
		var nm: String = str(ch.name)
		var extra: String = ""
		if ch is Control:
			extra = " rect=%s vis=%s" % [(ch as Control).get_global_rect(), (ch as Control).visible]
		print(">>>X1D  · ", ch.get_class(), " name=", nm, extra)
		for g in ch.get_children():
			var nm2: String = str(g.name)
			var extra2: String = ""
			if g is Control:
				extra2 = " rect=%s vis=%s" % [(g as Control).get_global_rect(), (g as Control).visible]
			print(">>>X1D     · ", g.get_class(), " name=", nm2, extra2)

	# 枚举 game_ui 根部直接子节点：可见 + 与「天下舆图」标题区域相交者即嫌疑人
	var hr: Rect2 = Rect2(Vector2(12, 8) * 2.25, Vector2(200, 40) * 2.25)
	for ch in ui.get_children():
		if ch is Control:
			var c := ch as Control
			var g := c.get_global_rect()
			if c.visible and g.intersects(hr):
				print(">>>X1D 嫌疑 ", c.name, " global=", g, " z=", c.get_index(), " mouse=", c.mouse_filter)
	# game_ui 的父层（main）同级
	for ch in ui.get_parent().get_children():
		if ch is Control and ch != ui:
			var c2 := ch as Control
			if c2.visible and c2.get_global_rect().intersects(hr):
				print(">>>X1D 外层嫌疑 ", c2.name, " global=", c2.get_global_rect(), " z=", c2.get_index())

	# 高清截图（供像素分析）
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	var img: Image = vp.get_texture().get_image()
	if img != null:
		var err: int = img.save_png("res://accept_shots_full/_x1_probe.png")
		print(">>>X1D 截图 err=", err, " size=", img.get_size())
	print(">>>X1D_ALL_DONE")
	get_tree().quit(0)

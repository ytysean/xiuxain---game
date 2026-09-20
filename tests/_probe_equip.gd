extends Node
## 弟子详情页「装备」Tab 渲染探针（**非 headless**，要真实渲染）。
## 用法：<godot> --path . res://tests/_probe_equip.tscn
## 产出：res://accept_shots_full/_probe_equip.png（装备 Tab 全屏）
##       另出 _probe_equip_detail.png（详情 Tab，用于确认闲情雅趣移位结果）

const 探针账号 := "__probe_equip__"

func _ready() -> void:
	# ★ 铁律（2026-09-15 老大定）：跑探针**不许弹窗打扰**。
	#   但不能用 `--headless` —— 那是 dummy 渲染器，截不出图（本探针的价值就在真实渲染，
	#   例如底座 shader 编译失败就是靠真渲染 + stdout SHADER ERROR 才抓到的）。
	#   ⇒ 折中：真实渲染，但**立即把窗口移出屏幕**，用户完全看不到。
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)

	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		printerr(">>>FAIL main.tscn 加载失败")
		get_tree().quit()
		return
	var main: Node = ps.instantiate()
	add_child(main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	main._登录_进入({"id": 探针账号})
	await _settle(20)
	var ui: Node = main.get("新UI")
	if ui == null:
		printerr(">>>FAIL 新UI 为空")
		get_tree().quit()
		return
	if Game.弟子列表.size() == 0:
		printerr(">>>FAIL 本档无弟子")
		get_tree().quit()
		return
	var 目标 = Game.弟子列表[0]
	ui._open_disciple_detail(目标)
	await _settle(24)
	var 详情: Node = ui.get("_current_sub")
	if 详情 == null:
		printerr(">>>FAIL 弟子详情页未创建")
		get_tree().quit()
		return
	print(">>> 详情页就绪，弟子 = %s" % str(目标.姓名))

	# ① 装备 Tab
	详情.call("_on_tab_pressed", "装备")
	await _settle(16)
	await _shot("_probe_equip.png")

	# ② 详情 Tab（确认闲情雅趣已下沉到末段）
	详情.call("_on_tab_pressed", "详情")
	await _settle(16)
	await _shot("_probe_equip_detail.png")

	get_tree().quit()


func _shot(名: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		printerr(">>>FAIL 截图为空 %s" % 名)
		return
	var err: int = img.save_png("res://accept_shots_full/" + 名)
	print(">>>SAVED %s err=%d size=%s" % [名, err, str(img.get_size())])


func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

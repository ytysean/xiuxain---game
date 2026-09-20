extends Node

# 天下页（page_world_map_visual）顶栏几何探针（headless · 2026-09-16）
# 症状：X01 截图顶部只见任务浮窗与右上被裁白条，「天下舆图」标题与缩放/宗门/◇ 按钮整排不见。

func _ready() -> void:
	var t := Timer.new()
	t.wait_time = 20.0
	t.one_shot = true
	t.timeout.connect(func(): get_tree().quit(1))
	add_child(t)
	t.start()
	_跑.call_deferred()

func _跑() -> void:
	var 路径: String = "res://ui/page_world_map_visual.gd"
	if not ResourceLoader.exists(路径):
		print(">>>X1_FAIL 脚本不存在")
		get_tree().quit(1)
		return
	var sc: Script = load(路径)
	var 页: Control = sc.new()
	页.name = "SubPage_世界大地图"
	# 与 game_ui._open_world_map_page 相同顺序：先设锚点再入树
	页.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(页)
	# 模拟全屏容器
	页.size = Vector2(480, 854)
	await get_tree().process_frame
	await get_tree().process_frame
	print(">>>X1 页面 rect=%s pos=%s" % [页.size, 页.position])
	var header := 页.find_child("HBoxContainer", true, false)
	if header != null:
		print(">>>X1 header rect=%s pos=%s visible=%s" % [header.size, header.position, header.visible])
	else:
		print(">>>X1 header 未找到（HBox）")
	for 名 in ["ZoomLabel", "MapViewport"]:
		var n := 页.find_child(名, true, false)
		if n != null:
			print(">>>X1 %s rect=%s pos=%s" % [名, n.size, n.position])
		else:
			print(">>>X1 %s 未找到" % 名)
	print(">>>X1_ALL_DONE")
	get_tree().quit(0)

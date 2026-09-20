extends Node
## 微探针 v2：实测「主题常量名写错 ⇒ 静默失效」。
## v1 失败原因：容器布局在 add_child 当帧尚未结算，读到的 position 恒为 0（阳性对照也 0）。
## v2 修法：等 2 帧 + 显式 queue_sort，再做几何断言。

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	prints("===== A/B/C/D：容器内子节点 x（留白 40 的期望值）=====")
	await _测("A  VBox + offset_left=40      ", "offset_left", 40)
	await _测("B  VBox + margin_left=40      ", "margin_left", 40)
	await _测("C  VBox + margin=40           ", "margin", 40)
	await _测("D  MarginContainer + margin_left=40", "margin_left", 40, true)

	prints("\n===== E：Button 在 GridContainer 里的实宽 =====")
	await _测按钮宽("E1 clip_text=true 无 EXPAND ", true, false)
	await _测按钮宽("E2 clip_text=true + EXPAND  ", true, true)
	await _测按钮宽("E3 clip_text=false 无 EXPAND", false, false)

	var solo := Button.new()
	solo.text = "字号基准"
	add_child(solo)
	await get_tree().process_frame
	prints("\nF  裸 Button 默认 font_size = %d ；项目 FONT_BODY = %d" % [
		solo.get_theme_font_size("font_size"), 27])

	get_tree().quit()


func _测(名: String, 常量: String, 值: int, 用Margin: bool = false) -> void:
	var host := PanelContainer.new()
	add_child(host)
	host.size = Vector2(600, 200)
	host.position = Vector2(0, 0)
	var box: Container = MarginContainer.new() if 用Margin else VBoxContainer.new()
	box.name = "Box"
	host.add_child(box)
	var c := Label.new()
	c.name = "Child"
	c.text = "子"
	c.custom_minimum_size = Vector2(60, 30)
	box.add_child(c)
	box.add_theme_constant_override(常量, 值)
	await get_tree().process_frame
	await get_tree().process_frame
	var dx: float = c.global_position.x - host.global_position.x
	var dy: float = c.global_position.y - host.global_position.y
	prints("  %s 子 x=%.1f y=%.1f  => %s" % [名, dx, dy,
		"生效" if dx >= 值 - 0.5 else "★ 死常量（零效果）"])
	host.queue_free()


func _测按钮宽(名: String, clip: bool, expand: bool) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	add_child(grid)
	grid.size = Vector2(600, 200)
	for i in range(3):
		var b := Button.new()
		b.text = "提升战力%d" % i
		b.clip_text = clip
		if expand:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	grid.queue_sort()
	await get_tree().process_frame
	await get_tree().process_frame
	var b0: Button = grid.get_child(0)
	var 需: float = b0.get_theme_font("font").get_string_size(
		b0.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b0.get_theme_font_size("font_size")).x
	prints("  %s 按钮 w=%.1f  文字宽=%.1f  => %s" % [名, b0.size.x, 需,
		"文字会被裁掉" if b0.size.x < 需 else "文字放得下"])
	grid.queue_free()

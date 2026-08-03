@tool
extends VBoxContainer
class_name ToolboxPanel

# =============================================================================
# 太玄UI编辑器 —— 左侧控件工具箱
# =============================================================================
# 提供 4 类控件的添加按钮，点击后通过 request_add 信号通知主编辑器。
# 本面板属于“编辑器自身界面”，可使用容器布局（不影响被设计的游戏 UI）。
# =============================================================================

signal request_add(type: String)



func _ready() -> void:
	# 标题
	var title: Label = Label.new()
	title.text = "控件工具箱"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.8, 0.85, 0.6, 1))
	add_child(title)

	# 控件按钮列表：[类型名, 显示文字]
	var items: Array = [
		[TaixuanUIData.TYPE_TEXTURE, "图片控件"],
		[TaixuanUIData.TYPE_LABEL,   "文字控件"],
		[TaixuanUIData.TYPE_BUTTON,  "按钮控件"],
		[TaixuanUIData.TYPE_PANEL,   "面板控件"],
		[TaixuanUIData.TYPE_ANIMATED, "动画帧"],
		[TaixuanUIData.TYPE_SPRITESHEET, "精灵表/图集"],
	]
	for it in items:
		var b: Button = Button.new()
		b.text = it[1]
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(_on_add.bind(it[0]))
		add_child(b)

	# 间隔
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	add_child(spacer)

	# 提示
	var hint: Label = Label.new()
	hint.text = "点击控件添加到画布中心；添加后可在右侧属性面板调整。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	add_child(hint)


func _on_add(type: String) -> void:
	request_add.emit(type)

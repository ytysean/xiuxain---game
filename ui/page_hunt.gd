extends Control

# 入山采撷（GameUI 二级页）：休闲玩法入口，整合狩猎、采药、采矿等野外采集活动。
# 后端：Game.入山采撷系统；数据只读，写操作调Game对应函数。

signal 返回主页

var _built: bool = false
var _列表: VBoxContainer

func _ready() -> void:
	_build()
	refresh()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content: Control = UITheme.make_scene_background(self)
	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(vbox)

	_build_header(vbox)

	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_列表 = VBoxContainer.new()
	_列表.name = "List"
	_列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_列表.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_列表)

	var 说明 := Label.new()
	说明.name = "Note"
	说明.text = "入山采撷，天地灵材自取。弟子可前往山野狩猎妖兽、采集灵草、挖掘矿石，所得归宗门所有。"
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说明)
	说明.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(说明)

func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	parent.add_child(UITheme.建顶栏("入山采撷", _on_back_pressed, [], "入山采撷", "派遣弟子入山采撷，狩猎妖兽、采集灵草、挖掘矿石。\n所得灵材归入宗门库房，可用于炼丹、炼器、制符。"))
func refresh() -> void:
	if not _built:
		return
	for c in _列表.get_children():
		c.queue_free()
	# 待完善：狩猎、采药、采矿等活动入口
	var empty := Label.new()
	empty.text = "入山采撷系统正在完善中，敬请期待。"
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_text(empty)
	empty.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	_列表.add_child(empty)

func _on_back_pressed() -> void:
	返回主页.emit()

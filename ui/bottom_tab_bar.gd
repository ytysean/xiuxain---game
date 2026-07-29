extends Control

# 底部主导航（P2 §三：固定底部 TAB_H=72，深青面板底 + 顶部 1px 淡金分隔线，5-Tab 横向均匀）。
# 每个 tab 为 Button，内部用 VBoxContainer 自绘「图标在上 / 文字在下」，
# 绕过部分 Godot 4.7 build 中 Button 内置 icon+text 排版文字丢失的问题。
# 选中态 = 亮金图标+文字 + 底部细金线；未选中 = 暗金。仅发信号 tab_selected(tab_id)。
# 整 Tab（Button）为点击热区，非仅图标可点。

signal tab_selected(tab_id: String)

const TABS: Array = ["宗门", "弟子", "建筑", "历练", "纪事"]
const ICON_SIZE: int = 26

var _buttons: Array = []
var _underlines: Array = []
var _icons: Array = []
var _selected: String = ""

func _ready() -> void:
	_build()
	select(TABS[0])

func _build() -> void:
	custom_minimum_size = Vector2(0, UITheme.TAB_H)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)

	# 深青面板底
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = UITheme.COLOR_BG_BASE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 顶部 1px 淡金分隔线
	var top := ColorRect.new()
	top.name = "TopDivider"
	top.color = UITheme.COLOR_BORDER_GOLD
	top.custom_minimum_size = Vector2(0, 1)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top)

	var hbox := HBoxContainer.new()
	hbox.name = "Tabs"
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for id in TABS:
		var btn := Button.new()
		btn.name = "Tab_" + id
		btn.text = ""
		btn.flat = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, UITheme.TAB_H)
		btn.set_meta("tab_id", id)
		btn.pressed.connect(_on_tab_pressed.bind(id))

		# 内容区：图标 + 文字，垂直居中
		var vbox := VBoxContainer.new()
		vbox.name = "Content"
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.add_child(vbox)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tex: Texture2D = UITheme.load_icon_sized(id, ICON_SIZE)
		if tex != null:
			icon.texture = tex
		vbox.add_child(icon)

		var lbl := Label.new()
		lbl.name = "Label"
		lbl.text = id
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)

		# 选中下划线（独立于内容区，锚定底部；亮金 1-2px）
		var ul := ColorRect.new()
		ul.name = "Underline"
		ul.color = UITheme.COLOR_TEXT_GOLD
		ul.custom_minimum_size = Vector2(0, UITheme.BORDER_W + 1)
		ul.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ul.size_flags_vertical = Control.SIZE_SHRINK_END
		ul.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ul.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		ul.visible = false
		btn.add_child(ul)

		hbox.add_child(btn)
		_buttons.append(btn)
		_underlines.append(ul)
		_icons.append(icon)

func select(tab_id: String) -> void:
	_selected = tab_id
	for i in range(_buttons.size()):
		var id: String = _buttons[i].get_meta("tab_id", "")
		var sel: bool = (id == tab_id)
		UITheme.apply_tab_style(_buttons[i], sel)
		_underlines[i].visible = sel
		var lbl: Label = _buttons[i].get_node_or_null("Content/Label")
		if lbl != null:
			# Tab 名称用古风楷体（MaShanZheng）14px（P2 §一 Tab名称→楷体；§三 文字 14px），选中亮金 / 未选暗金
			UITheme.apply_title_font_sized(lbl, UITheme.FONT_AUX)
			lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD if sel else UITheme.COLOR_TEXT_AUX)
		var icon: TextureRect = _icons[i]
		if icon != null:
			# 图标 modulate：选中亮金 / 未选暗金（SVG 线稿本为金，multiply 调亮暗）
			icon.modulate = UITheme.COLOR_TEXT_GOLD if sel else UITheme.COLOR_TEXT_AUX

func get_selected() -> String:
	return _selected

func _on_tab_pressed(tab_id: String) -> void:
	select(tab_id)
	tab_selected.emit(tab_id)

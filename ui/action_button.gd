extends Control

# 可复用动作按钮：图标(占位)在上 + 文字在下；仅发信号，不连玩法。
# 大按钮高 64 / 小按钮高 48（§2.4）。样式全部来自 UITheme。

signal pressed(action_id: String)

@export var action_id: String = ""
@export var label_text: String = ""
@export var big: bool = true

var _btn: Button
var _label: Label
var _icon: TextureRect

func _ready() -> void:
	_build()
	_apply_theme()
	_btn.pressed.connect(_on_pressed)

func _build() -> void:
	_btn = Button.new()
	_btn.name = "Btn"
	_btn.text = ""
	_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_btn)
	_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	_btn.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 大按钮图标降到 32px、小按钮 20px；统一走 load_icon_sized 光栅化固定尺寸，
	# 避免原始 SVG 尺寸过大撑爆按钮（§2.4 / §3.1）。
	var isz: int = 32 if big else 20
	_icon.custom_minimum_size = Vector2(isz, isz)
	var tex: Texture2D = UITheme.load_icon_sized(action_id, isz)
	if tex != null:
		_icon.texture = tex
	vbox.add_child(_icon)

	_label = Label.new()
	_label.name = "Label"
	_label.text = label_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_label)

	# 大按钮最小高度提到 80（GRID*10），给 图标(32)+分隔(8)+文字 留出余量，文字不再被挤出。
	var h: int = UITheme.GRID * 10 if big else UITheme.BTN_H_SECONDARY
	custom_minimum_size = Vector2(0, h)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _apply_theme() -> void:
	if big:
		UITheme.apply_primary_button_style(_btn)
		UITheme.apply_body_font(_label)
	else:
		UITheme.apply_secondary_button_style(_btn)
		UITheme.apply_aux_font(_label)
	_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)

func _on_pressed() -> void:
	pressed.emit(action_id)

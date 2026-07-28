extends VBoxContainer

# 可折叠分类（§2.2 下部收纳区）。标题 Button + 内容 Container，默认折叠。
# 切换信号 toggled(open: bool)。内容由 design-strategist 后续填充。

signal toggled(open: bool)

@export var title_text: String = ""
@export var collapsed_by_default: bool = true

var _header: Button
var _chevron: TextureRect
var _content: VBoxContainer
var _open: bool = false

func _ready() -> void:
	_build()
	_apply_theme()
	set_open(not collapsed_by_default)

func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 整组件包一层 PanelContainer，给分类一个清晰可见的容器边界（§2.2 收纳区）。
	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(frame)

	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.add_theme_constant_override("separation", 0)
	frame.add_child(inner)

	_header = Button.new()
	_header.name = "Header"
	_header.text = title_text
	_header.flat = true
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.custom_minimum_size = Vector2(0, UITheme.SIZE_MD)
	_header.pressed.connect(_on_header_pressed)
	inner.add_child(_header)

	# 折叠状态指示（右侧 chevron：可展开 ↓ / 可收起 ↑）
	_chevron = TextureRect.new()
	_chevron.name = "Chevron"
	_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var cv_tex: Texture2D = UITheme.load_icon_sized("折叠", 24)
	if cv_tex != null:
		_chevron.texture = cv_tex
	_chevron.custom_minimum_size = Vector2(24, 24)
	_chevron.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_chevron.anchor_left = 1.0
	_chevron.anchor_right = 1.0
	_chevron.anchor_top = 0.5
	_chevron.anchor_bottom = 0.5
	_chevron.offset_left = -32
	_chevron.offset_right = -8
	_chevron.offset_top = -12
	_chevron.offset_bottom = 12
	# 旋转支点设到中央，绕中心旋 180°
	_chevron.pivot_offset = Vector2(12, 12)
	_header.add_child(_chevron)

	# header 下方加一条细分隔线，明确标题与内容的分界（§2.2）。
	inner.add_child(UITheme.make_divider_control())

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", UITheme.GRID)
	inner.add_child(_content)

func _apply_theme() -> void:
	UITheme.apply_title_font(_header)

func set_open(open: bool) -> void:
	_open = open
	_content.visible = open
	# chevron：折叠 → ↓(0°)；展开 → ↑(180°)
	if _chevron != null:
		_chevron.rotation_degrees = 180.0 if _open else 0.0
	toggled.emit(open)

func is_open() -> bool:
	return _open

func _on_header_pressed() -> void:
	set_open(not _open)

func add_content(node: Control) -> void:
	_content.add_child(node)

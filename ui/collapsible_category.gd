extends VBoxContainer

# 可折叠分类（§2.2 下部收纳区）。标题 Button + 内容 Container，默认折叠。
# 切换信号 toggled(open: bool)。内容由 design-strategist 后续填充。

signal toggled(open: bool)

@export var title_text: String = ""
@export var collapsed_by_default: bool = true

var _header: Button
var _content: VBoxContainer
var _open: bool = false

func _ready() -> void:
	_build()
	_apply_theme()
	set_open(not collapsed_by_default)

func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)

	_header = Button.new()
	_header.name = "Header"
	_header.text = title_text
	_header.flat = true
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.custom_minimum_size = Vector2(0, UITheme.SIZE_MD)
	_header.pressed.connect(_on_header_pressed)
	add_child(_header)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", UITheme.GRID)
	add_child(_content)

func _apply_theme() -> void:
	UITheme.apply_title_font(_header)

func set_open(open: bool) -> void:
	_open = open
	_content.visible = open
	toggled.emit(open)

func is_open() -> bool:
	return _open

func _on_header_pressed() -> void:
	set_open(not _open)

func add_content(node: Control) -> void:
	_content.add_child(node)

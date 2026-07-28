extends PanelContainer

# ItemSlot — 通用物品槽（背景底框 + 居中图标 + 右下角数量 + 品级染色）。
# 注：根为 PanelContainer（取 main_theme.tres 的面板框），而非 TextureRect —— 避免依赖缺失的背景 SVG 资源，
#     符合「基础视觉由 main_theme.tres 提供 + 不依赖缺失图标文件」红线。功能结构完全一致。
# 品级变更：调用 UIThemeConfig.set_quality_color 对自身 modulate 染色。
# 点击：发射 clicked(item_id)。对接真实数据走 Game autoload（只读展示），不引入 ConfigManager。

signal clicked(item_id: String)

@export var item_id: String = "":
	set(v):
		item_id = v

@export var item_count: int = 0:
	set(v):
		item_count = v
		if is_inside_tree():
			_refresh_count()

@export var quality: String = "fan":
	set(v):
		quality = v
		if not Engine.is_editor_hint() and is_inside_tree():
			UIThemeConfig.set_quality_color(self, quality)

@onready var _icon: TextureRect = $Inner/IconCenter/icon
@onready var _count_label: Label = $Inner/count_label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIThemeConfig.set_quality_color(self, quality)
	_refresh_count()
	gui_input.connect(_on_gui_input)

func _refresh_count() -> void:
	if _count_label == null:
		return
	if item_count > 0:
		_count_label.text = str(item_count)
		_count_label.visible = true
	else:
		_count_label.visible = false

func set_item(id: String, count: int, q: String = "") -> void:
	item_id = id
	item_count = count
	if q != "":
		quality = q
	UIThemeConfig.set_quality_color(self, quality)
	_refresh_count()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(item_id)

extends PanelContainer

# BasePanel — 通用面板基类（Autoload 不依赖；基础视觉来自 main_theme.tres）。
# 结构：根 PanelContainer → VBox[标题栏 HBox(标题 Label + 关闭 Button) + 内容区 PanelContainer("content_area")]。
# 红线：不触碰战斗/数值/玩法；只做结构与交互，取色/字号由 ui_theme.gd 提供。

signal closed

@onready var _title_label: Label = $VBox/TitleBar/title_label
@onready var _close_button: Button = $VBox/TitleBar/close_button
@onready var _content_area: PanelContainer = $VBox/ContentArea

func _ready() -> void:
	UITheme.apply_title_font(_title_label)
	_close_button.text = "关闭"
	_close_button.pressed.connect(_on_close_pressed)

func set_title(t: String) -> void:
	if _title_label != null:
		_title_label.text = t

func get_content_area() -> PanelContainer:
	return _content_area

func open_panel() -> void:
	visible = true
	pivot_offset = size * 0.5
	scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	var t: Tween = create_tween()
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	t.parallel().tween_property(self, "modulate:a", 1.0, 0.15)

func close() -> void:
	visible = false
	closed.emit()

func _on_close_pressed() -> void:
	close()

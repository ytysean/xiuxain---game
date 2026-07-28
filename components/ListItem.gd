extends PanelContainer

# ListItem — 通用列表行（标题 + 副标题 + 右数值 + 左图标）。
# 点击：缩放 0.98→1 反馈 + 发射 item_selected(data)。
# 红线：只读展示；图标统一走 UITheme.load_icon_sized（不自行 load SVG）。

signal item_selected(data: Dictionary)

var _data: Dictionary = {}

@onready var _icon: TextureRect = $HBox/icon
@onready var _title: Label = $HBox/texts/title_label
@onready var _subtitle: Label = $HBox/texts/subtitle_label
@onready var _value: Label = $HBox/value_label

func _ready() -> void:
	UITheme.apply_body_font(_title)
	UITheme.apply_aux_font(_subtitle)
	UITheme.apply_value_font(_value)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 子节点设为 IGNORE，确保整个行的 gui_input 落到自身
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HBox/texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gui_input.connect(_on_gui_input)

func set_data(data: Dictionary) -> void:
	_data = data
	if data.has("title"):
		_title.text = str(data["title"])
	if data.has("subtitle"):
		_subtitle.text = str(data["subtitle"])
	if data.has("value"):
		_value.text = str(data["value"])
	if data.has("icon") and data["icon"] is String:
		var tex: Texture2D = UITheme.load_icon_sized(data["icon"], UITheme.SIZE_SM)
		if tex != null:
			_icon.texture = tex
			_icon.visible = true
		else:
			_icon.visible = false
	else:
		_icon.visible = false

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pivot_offset = size * 0.5
		var t: Tween = create_tween()
		t.tween_property(self, "scale", Vector2(0.98, 0.98), 0.05)
		t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
		item_selected.emit(_data)

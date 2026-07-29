extends PanelContainer

# ListItem — 通用列表行（标题 + 副标题 + 右数值 + 左图标）。
# 点击：缩放 0.98→1 反馈 + 发射 item_selected(data)。
# 红线：只读展示；图标统一走 UITheme.load_icon_sized（不自行 load SVG）。

signal item_selected(data: Dictionary)

var _data: Dictionary = {}
var _pending_data: Dictionary = {}

var _icon: TextureRect
var _title: Label
var _subtitle: Label
var _value: Label
var _hbox: HBoxContainer
var _texts: VBoxContainer

func _ready() -> void:
	# 用户 Godot 4.7 build 对 @onready 的初始化存在不稳定情况，改为 _ready 内手动取节点并做 nil 保护。
	_hbox = get_node_or_null("HBox")
	_texts = get_node_or_null("HBox/texts")
	_icon = get_node_or_null("HBox/icon")
	_title = get_node_or_null("HBox/texts/title_label")
	_subtitle = get_node_or_null("HBox/texts/subtitle_label")
	_value = get_node_or_null("HBox/value_label")

	if _title != null:
		UITheme.apply_body_font(_title)
	if _subtitle != null:
		UITheme.apply_aux_font(_subtitle)
	if _value != null:
		UITheme.apply_value_font(_value)

	mouse_filter = Control.MOUSE_FILTER_STOP
	# 子节点设为 IGNORE，确保整个行的 gui_input 落到自身
	if _icon != null:
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _title != null:
		_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _subtitle != null:
		_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _value != null:
		_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _hbox != null:
		_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _texts != null:
		_texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gui_input.connect(_on_gui_input)

	# 若 instantiate 后立刻被 set_data，节点引用当时未就绪，延迟到 _ready 后应用。
	if not _pending_data.is_empty():
		set_data(_pending_data)
		_pending_data.clear()

func set_data(data: Dictionary) -> void:
	_data = data
	# 节点未就绪时暂存数据，避免直接访问 nil 节点崩溃。
	if _title == null or _subtitle == null or _value == null or _icon == null:
		_pending_data = data.duplicate()
		return

	if data.has("title"):
		_title.text = str(data["title"])
	if data.has("subtitle"):
		_subtitle.text = str(data["subtitle"])
	if data.has("value"):
		# 战力为负/异常标红：set_data 可选键 value_abnormal（默认 false），由页面侧传入。
		var abnormal: bool = data.get("value_abnormal", false)
		_value.text = str(data["value"])
		UITheme.apply_value_font(_value, abnormal)
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

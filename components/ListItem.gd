extends PanelContainer

# ListItem — 通用列表行（标题 + 副标题 + 右数值 + 左图标）。
# 点击：缩放反馈 + 发射 item_selected(data)。
# P2 §四：单条高度 ≥64px，整行点击热区；四态 正常/悬浮(提亮)/按下(缩放+描边)/选中(加深+金边)。
# 红线：只读展示；图标统一走 UITheme.load_icon_sized（不自行 load SVG）。

signal item_selected(data: Dictionary)

enum State { NORMAL, HOVER, PRESSED, SELECTED }

var _data: Dictionary = {}
var _pending_data: Dictionary = {}

var _icon: TextureRect
var _title: Label
var _subtitle: Label
var _value: Label
var _hbox: HBoxContainer
var _texts: VBoxContainer

var _state: int = State.NORMAL
var _selected: bool = false
var _hovered: bool = false

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

	# 单条高度 ≥64px（P2 §四）
	custom_minimum_size = Vector2(0, UITheme.SIZE_SM)

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
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# 初始面板样式（自绘四态）
	_refresh_panel()

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

# P2 §四：选中态（加深背景 + 金边）
func set_selected(value: bool) -> void:
	_selected = value
	_state = State.SELECTED if _selected else (State.HOVER if _hovered else State.NORMAL)
	_refresh_panel()

func is_selected() -> bool:
	return _selected

# 四态面板样式（自绘 StyleBoxFlat：正常=面板底；悬浮=提亮；按下=按下底色+金边；选中=加深+金边）
func _refresh_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	sb.set_border_width_all(UITheme.BORDER_W)
	sb.set_content_margin_all(UITheme.GRID)
	var bg: Color = UITheme.COLOR_PANEL_BG
	var border: Color = UITheme.COLOR_BORDER_GOLD
	match _state:
		State.HOVER:
			bg = UITheme.COLOR_PANEL_BG.lightened(0.12)
		State.PRESSED:
			bg = UITheme.COLOR_BTN_PRESSED
			border = UITheme.COLOR_TEXT_GOLD
		State.SELECTED:
			bg = UITheme.COLOR_PANEL_BG.darkened(0.35)
			border = UITheme.COLOR_TEXT_GOLD
	sb.bg_color = bg
	sb.border_color = border
	add_theme_stylebox_override("panel", sb)

func _on_mouse_entered() -> void:
	_hovered = true
	if _selected:
		_state = State.SELECTED
	else:
		_state = State.HOVER
	_refresh_panel()

func _on_mouse_exited() -> void:
	_hovered = false
	_state = State.SELECTED if _selected else State.NORMAL
	_refresh_panel()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_state = State.PRESSED
		_refresh_panel()
		# 按下反馈：缩放（UITween.button_press）+ 描边高亮（P2 §四）
		UITween.button_press(self)
		var tw: Tween = create_tween()
		tw.tween_interval(0.13)
		tw.tween_callback(_on_press_revert)
		item_selected.emit(_data)

func _on_press_revert() -> void:
	if not is_instance_valid(self):
		return
	if _selected:
		_state = State.SELECTED
	elif _hovered:
		_state = State.HOVER
	else:
		_state = State.NORMAL
	_refresh_panel()

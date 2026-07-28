extends Control

# 顶部状态栏（§2.2：固定顶部 48dp）。仅发信号，不连玩法/时间逻辑。
# 左：时辰占位；中：宗门等级 + 微型进度条（展开填充、内容居中）；
# 右：3 核心资源槽（图标16×16 + 紧贴数值标签）；
# 最右：「推演时日」按钮 -> 信号 time_advance_requested。
#
# 布局采用单 HBoxContainer，顺序固定为：
#   time(SHRINK_BEGIN) | mid(EXPAND_FILL) | res(SHRINK_END) | btn(SHRINK_END)
# 该结构保证 480 竖屏下元素不重叠、不被挤出：mid 吸收多余宽度，
# 末端元素（res / btn）固定靠右、time 固定靠左；资源槽紧凑（图标16 + 间距4 + 标签）。

signal time_advance_requested

const RESOURCES: Array = ["灵石", "灵气", "弟子"]

var _time_label: Label
var _level_label: Label
var _progress: ProgressBar
var _res_labels: Dictionary = {}
var _time_btn: Button

func _ready() -> void:
	_build()
	_apply_theme()
	_time_btn.pressed.connect(_on_time_pressed)

func _build() -> void:
	custom_minimum_size = Vector2(0, UITheme.TOPBAR_H)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = UITheme.COLOR_STATUSBAR_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var hbox := HBoxContainer.new()
	hbox.name = "Main"
	hbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	hbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	hbox.add_theme_constant_override("separation", UITheme.GRID)
	add_child(hbox)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 左：时辰占位（固定左对齐，不展开）
	_time_label = Label.new()
	_time_label.name = "Time"
	_time_label.text = "时辰 · —"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_time_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(_time_label)

	# 中：宗门等级 + 微型进度条（展开填充，内容垂直/水平居中）
	var mid := VBoxContainer.new()
	mid.name = "Mid"
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 2)
	hbox.add_child(mid)

	_level_label = Label.new()
	_level_label.name = "Level"
	_level_label.text = "宗门 Lv —"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_level_label)

	_progress = ProgressBar.new()
	_progress.name = "LevelProgress"
	_progress.custom_minimum_size = Vector2(64, UITheme.BORDER_W + 4)
	_progress.show_percentage = false
	_progress.value = 0.0
	_progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(_progress)

	# 右：3 核心资源槽（图标 16×16 + 紧贴数值标签）
	var res := HBoxContainer.new()
	res.name = "Resources"
	res.size_flags_horizontal = Control.SIZE_SHRINK_END
	res.add_theme_constant_override("separation", UITheme.GRID)
	hbox.add_child(res)
	for id in RESOURCES:
		res.add_child(_make_slot(id))

	# 最右：推演时日 按钮（已由工程侧处理为 图标+文字）
	_time_btn = Button.new()
	_time_btn.name = "TimeAdvance"
	_time_btn.text = "推演时日"
	_time_btn.icon = UITheme.load_icon_sized("推演时日", 22)
	_time_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_time_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_btn.custom_minimum_size = Vector2(72, 32)
	_time_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox.add_child(_time_btn)

func _make_slot(id: String) -> Control:
	var slot := HBoxContainer.new()
	slot.name = "Slot_" + id
	slot.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tex: Texture2D = UITheme.load_icon(id)
	if tex != null:
		icon.texture = tex
	icon.custom_minimum_size = Vector2(16, 16)
	slot.add_child(icon)
	var lbl := Label.new()
	lbl.name = "Value"
	lbl.text = "—"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	slot.add_child(lbl)
	_res_labels[id] = lbl
	return slot

func _apply_theme() -> void:
	UITheme.apply_aux_font(_time_label)
	UITheme.apply_aux_font(_level_label)
	for id in RESOURCES:
		var lbl: Label = _res_labels.get(id, null)
		if lbl != null:
			UITheme.apply_value_font(lbl, false)
	# 等级进度条填充/底由 main_theme.tres 的 ProgressBar 默认提供（令牌 success 绿 #7ED39A，D2 拍板）。
	UITheme.apply_primary_button_style(_time_btn)

func set_time(text: String) -> void:
	_time_label.text = text

func set_sect_level(text: String) -> void:
	_level_label.text = text

func set_level_progress(ratio: float) -> void:
	_progress.value = clampf(ratio, 0.0, 1.0) * 100.0

func set_resource(slot_id: String, value: String, abnormal: bool = false) -> void:
	var lbl: Label = _res_labels.get(slot_id, null)
	if lbl == null:
		return
	lbl.text = value
	UITheme.apply_value_font(lbl, abnormal)

func _on_time_pressed() -> void:
	time_advance_requested.emit()

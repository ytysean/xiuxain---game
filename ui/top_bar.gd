extends Control

# 顶部状态栏（P2 §二：固定顶部 TOPBAR_H=64，半透明深青底 + 底部 1px 淡金分隔线）。
# 仅发信号，不连玩法/时间逻辑。
# 三区横向（均 vertical_center，BoxContainer.ALIGNMENT_CENTER 控制交叉轴对齐）：
#   左（SHRINK_BEGIN）：时辰文字 + 宗门入口(等级/宗门名 + 微型进度条) + 3 核心资源槽
#   中（EXPAND_FILL，居中）：3 个等大功能图标按钮（推演 发 time_advance_requested + 2 占位图标）
#   右（SHRINK_END）：设置 + 调试 按钮（由 main.gd 通过 add_right_control 注入，样式统一）
#
# 布局采用单 HBox（margin=MARGIN, separation=GRID），三区各自 size_flags 控制对齐。

signal time_advance_requested

const RESOURCES: Array = ["灵石", "灵气", "弟子"]
const ICON_BTN_SIZE: int = 32   # 中部功能图标按钮单元格尺寸（图标光栅化 28，留触摸边距）

var _time_label: Label
var _level_label: Label
var _progress: ProgressBar
var _res_labels: Dictionary = {}
var _left: HBoxContainer
var _center: HBoxContainer
var _right: HBoxContainer

func _ready() -> void:
	_build()
	_apply_theme()

func _build() -> void:
	custom_minimum_size = Vector2(0, UITheme.TOPBAR_H)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	# 半透明深青底（P2 §二：Color(0.10,0.18,0.20,0.85) 类）
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = UITheme.COLOR_TOPBAR_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 底部 1px 淡金分隔线
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.color = UITheme.COLOR_BORDER_GOLD
	divider.custom_minimum_size = Vector2(0, 1)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.size_flags_vertical = Control.SIZE_SHRINK_END
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(divider)

	var hbox := HBoxContainer.new()
	hbox.name = "Main"
	hbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	hbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	hbox.add_theme_constant_override("separation", UITheme.GRID)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 左区：时辰 + 宗门入口 + 资源槽（左对齐，间距 GRID*2）
	_left = HBoxContainer.new()
	_left.name = "Left"
	_left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_left.add_theme_constant_override("separation", UITheme.GRID * 2)
	hbox.add_child(_left)

	_time_label = Label.new()
	_time_label.name = "Time"
	_time_label.text = "时辰"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_left.add_child(_time_label)

	# 宗门入口：等级文字 + 微型进度条（垂直居中）
	var sect := VBoxContainer.new()
	sect.name = "Sect"
	sect.alignment = BoxContainer.ALIGNMENT_CENTER
	sect.add_theme_constant_override("separation", 2)
	_left.add_child(sect)

	_level_label = Label.new()
	_level_label.name = "Level"
	_level_label.text = "宗门"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sect.add_child(_level_label)

	_progress = ProgressBar.new()
	_progress.name = "LevelProgress"
	_progress.custom_minimum_size = Vector2(56, UITheme.BORDER_W + 4)
	_progress.show_percentage = false
	_progress.value = 0.0
	_progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sect.add_child(_progress)

	# 资源槽（图标 20×20 + 紧贴数值）
	for id in RESOURCES:
		_left.add_child(_make_slot(id))

	# 中区：3 个大等图标按钮（推演 + 2 占位），居中、等大、等距、垂直居中
	_center = HBoxContainer.new()
	_center.name = "Center"
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.alignment = BoxContainer.ALIGNMENT_CENTER
	_center.add_theme_constant_override("separation", UITheme.GRID * 2)
	hbox.add_child(_center)

	# 两侧弹性占位，使 3 图标作为紧凑组水平居中（图标本身保持 28px 等大）
	_center.add_child(_spacer())
	_center.add_child(_make_icon_btn("推演时日", "推演时日", time_advance_requested.emit))
	_center.add_child(_make_icon_btn("纪事", "纪事（详见底部·纪事）", Callable()))
	_center.add_child(_make_icon_btn("账册", "账册（开发中）", Callable()))
	_center.add_child(_spacer())

	# 右区：预留，由 main.gd 注入 设置/调试 按钮（确保与顶部栏右区视觉统一）
	_right = HBoxContainer.new()
	_right.name = "Right"
	_right.size_flags_horizontal = Control.SIZE_SHRINK_END
	_right.alignment = BoxContainer.ALIGNMENT_CENTER
	_right.add_theme_constant_override("separation", UITheme.GRID)
	hbox.add_child(_right)

func _spacer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

func _make_slot(id: String) -> Control:
	var slot := HBoxContainer.new()
	slot.name = "Slot_" + id
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
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
	icon.custom_minimum_size = Vector2(20, 20)
	slot.add_child(icon)
	var lbl := Label.new()
	lbl.name = "Value"
	lbl.text = ""
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	slot.add_child(lbl)
	_res_labels[id] = lbl
	return slot

# 中部功能图标按钮：图标(28) + tooltip；on_press 非 null 时按下即 emit，否则纯占位（仅 tooltip）。
func _make_icon_btn(label: String, tooltip: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.name = "Icon_" + label
	btn.flat = true
	btn.text = ""
	btn.tooltip_text = tooltip
	btn.icon = UITheme.load_icon_sized(label, 28)
	btn.custom_minimum_size = Vector2(ICON_BTN_SIZE, ICON_BTN_SIZE)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# 统一图标按钮视觉：套用次按钮四态（淡金描边 + hover/press 反馈），避免裸图标无交互感
	UITheme.apply_secondary_button_style(btn)
	UITheme.apply_aux_font(btn)
	if not on_press.is_null():
		btn.pressed.connect(on_press)
	return btn

# main.gd 注入顶部右区控件（设置/调试按钮），确保与顶部栏右区视觉统一、不残留裸按钮。
func add_right_control(control: Control) -> void:
	if _right != null:
		_right.add_child(control)

func _apply_theme() -> void:
	UITheme.apply_aux_font(_time_label)
	UITheme.apply_aux_font(_level_label)
	for id in RESOURCES:
		var lbl: Label = _res_labels.get(id, null)
		if lbl != null:
			UITheme.apply_value_font(lbl, false)

func set_time(text: String) -> void:
	_time_label.text = text

func set_sect_level(text: String) -> void:
	# 避免「宗门 Lv —」这类占位横线露出；无有效等级时只显示「宗门」。
	_level_label.text = text if not text.ends_with("—") else "宗门"

func set_level_progress(ratio: float) -> void:
	_progress.value = clampf(ratio, 0.0, 1.0) * 100.0

func set_resource(slot_id: String, value: String, abnormal: bool = false) -> void:
	var lbl: Label = _res_labels.get(slot_id, null)
	if lbl == null:
		return
	# 占位符「—」在资源槽里会呈现为图标后的残留横线，统一显示为空。
	lbl.text = "" if value == "—" else value
	UITheme.apply_value_font(lbl, abnormal)

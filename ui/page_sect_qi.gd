extends Control

# 宗门气运（GameUI 二级页）：展示香火、愿力、功德、业力四大修真资源。
# 纯展示页面，读取 Game 数据，零数据层写入。

signal 返回主页

var _built: bool = false
var _状态标签: Label

# 资源配置：名称、字段、图标、说明
const QI_RESOURCES: Array = [
	{
		"name": "香火",
		"field": "香火值",
		"icon": "res_xianghuo",
		"desc": "凡人供奉香火，凝聚宗门信仰之力。香火越盛，宗门气运越旺，可转化为愿力。",
		"color": Color(0.95, 0.75, 0.35)  # 金黄
	},
	{
		"name": "愿力",
		"field": "愿力",
		"icon": "res_yuanli",
		"desc": "香火凝炼而成的愿力，是宗门修士突破境界、施展大神通的关键资源。",
		"color": Color(0.65, 0.85, 0.95)  # 淡蓝
	},
	{
		"name": "功德",
		"field": "功德",
		"icon": "res_gongde",
		"desc": "行善积德、济世救人所积累的功德。功德深厚者，天道庇佑，突破成功率提升。",
		"color": Color(0.75, 0.95, 0.65)  # 淡绿
	},
	{
		"name": "业力",
		"field": "业力",
		"icon": "res_yeli",
		"desc": "杀生害命、作恶多端所积累的业力。业力深重者，天道谴罚，心魔滋生。",
		"color": Color(0.95, 0.55, 0.55)  # 淡红
	},
]

func _ready() -> void:
	_build()
	refresh()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content: Control = UITheme.make_scene_background(self)
	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(vbox)
	_build_header(vbox)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(inner)
	# 气运总览
	inner.add_child(_建气运总览卡())
	# 四个资源卡片
	for res in QI_RESOURCES:
		inner.add_child(_建资源卡(res))
	# 气运说明
	inner.add_child(_建说明卡())

func _build_header(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.name = "HeaderBar"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	var back: Button = UITheme.make_back_button(_on_back_pressed)
	bar.add_child(back)
	var title := Label.new()
	title.name = "Title"
	title.text = "宗门气运  ⓘ"
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			UIHint.show_hint(title, "宗门气运", "香火、愿力、功德、业力四大修真资源。\n气运盛衰影响宗门发展与修士突破。"))
	UITheme.apply_page_title(title)
	bar.add_child(title)
	_状态标签 = Label.new()
	_状态标签.name = "Status"
	UITheme.apply_value_text(_状态标签)
	bar.add_child(_状态标签)
	parent.add_child(bar)

func _建气运总览卡() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "CardOverview"
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.C01_PANEL_A
	sb.border_color = UITheme.C01_LINE_GOLD
	sb.set_corner_radius_all(UITheme.RADIUS)
	sb.set_border_width_all(UITheme.BORDER)
	sb.set_content_margin_all(UITheme.MARGIN)
	panel.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID * 0.5)
	panel.add_child(vbox)
	# 标题
	var title := Label.new()
	title.text = "气运总览"
	UITheme.apply_section_title(title)
	vbox.add_child(title)
	# 气运值
	var 气运值: int = _计算气运值()
	var 气运描述: String = _气运描述(气运值)
	var val_label := Label.new()
	val_label.text = "宗门气运：%d  ·  %s" % [气运值, 气运描述]
	val_label.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	val_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	vbox.add_child(val_label)
	# 进度条
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = clampi(气运值, 0, 100)
	bar.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(bar)
	return panel

func _建资源卡(res: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Card_" + res["name"]
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.C01_PANEL_A
	sb.border_color = res["color"]
	sb.set_corner_radius_all(UITheme.RADIUS)
	sb.set_border_width_all(UITheme.BORDER)
	sb.set_content_margin_all(UITheme.MARGIN)
	panel.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(hbox)
	# 图标
	var icon := TextureRect.new()
	icon.texture = UITheme.load_hd_icon(res["icon"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(UITheme.ICON_LG, UITheme.ICON_LG)
	hbox.add_child(icon)
	# 内容
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", UITheme.GRID * 0.3)
	hbox.add_child(vbox)
	# 名称和数值
	var title_row := HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(title_row)
	var name_label := Label.new()
	name_label.text = res["name"]
	name_label.add_theme_color_override("font_color", res["color"])
	name_label.add_theme_font_size_override("font_size", UITheme.FONT_SUBTITLE)
	title_row.add_child(name_label)
	var val_label := Label.new()
	val_label.name = "ValueLabel"
	val_label.text = str(_读取资源值(res["field"]))
	val_label.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	val_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	title_row.add_child(val_label)
	# 说明
	var desc_label := Label.new()
	desc_label.text = res["desc"]
	desc_label.add_theme_color_override("font_color", UITheme.C01_TEXT_SECONDARY)
	desc_label.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	return panel

func _建说明卡() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "CardDesc"
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.C01_PANEL_LIGHT
	sb.border_color = UITheme.C01_LINE_GOLD
	sb.set_corner_radius_all(UITheme.RADIUS)
	sb.set_border_width_all(UITheme.BORDER)
	sb.set_content_margin_all(UITheme.MARGIN)
	panel.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID * 0.5)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "气运说明"
	UITheme.apply_section_title(title)
	vbox.add_child(title)
	var lines: Array = [
		"· 香火：凡人供奉，宗门信仰之力，可转化为愿力",
		"· 愿力：香火凝炼，突破境界、施展神通的关键",
		"· 功德：行善积德，天道庇佑，提升突破成功率",
		"· 业力：作恶多端，天道谴罚，心魔滋生",
		"· 气运 = 香火×0.3 + 愿力×0.3 + 功德×0.2 - 业力×0.2",
		"· 气运盛衰影响宗门发展、弟子突破与事件触发",
	]
	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_SECONDARY)
		lbl.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
		vbox.add_child(lbl)
	return panel

func _读取资源值(field: String) -> int:
	if not is_instance_valid(Game):
		return 0
	var raw: Variant = Game.get(field)
	if raw == null:
		return 0
	return int(raw)

func _计算气运值() -> int:
	if not is_instance_valid(Game):
		return 50
	if Game.has_method("获取气运值"):
		return Game.获取气运值()
	# 回退计算（与core保持一致：产出速率+存量模型，归一化到0-100）
	var 香火速率: float = float(_读取资源值("香火月产预估")) * 2.0
	var 愿力存量: float = float(_读取资源值("愿力")) * 0.1
	var 功德存量: float = float(_读取资源值("功德")) * 0.5
	var 业力存量: float = float(_读取资源值("业力")) * 0.5
	var 基础气运: float = 香火速率 + 愿力存量 + 功德存量 - 业力存量
	var 归一化: float = (基础气运 + 500.0) / 1500.0 * 100.0
	归一化 = clamp(归一化, 0.0, 100.0)
	return int(归一化)

func _气运描述(气运值: int) -> String:
	if not is_instance_valid(Game):
		return "气运平稳"
	if Game.has_method("获取气运等级"):
		return Game.获取气运等级()
	# 回退计算
	if 气运值 >= 80:
		return "气运昌隆"
	elif 气运值 >= 60:
		return "气运旺盛"
	elif 气运值 >= 40:
		return "气运平稳"
	elif 气运值 >= 20:
		return "气运低迷"
	else:
		return "气运衰败"

func refresh() -> void:
	if not _built:
		return
	# 更新状态标签
	var 气运值: int = _计算气运值()
	_状态标签.text = "气运：%d" % 气运值
	# 更新各资源数值
	for res in QI_RESOURCES:
		var card: PanelContainer = get_node_or_null("Root/Scroll/Inner/Card_" + res["name"])
		if card != null:
			var val_label: Label = card.get_node_or_null("HBoxContainer/VBoxContainer/TitleRow/ValueLabel")
			if val_label != null:
				val_label.text = str(_读取资源值(res["field"]))

func _on_back_pressed() -> void:
	返回主页.emit()

extends Control

# 玄洲玄榜（GameUI 二级页）：个人修士榜 / 宗门势力榜切换 + 多维指标 + 范围筛选。
# 当前无排行数据接口（排期表 P1），暂用样例数据只读展示；数据接口就绪后改读 Game 排行 API 即可。

signal 返回主页

var _built: bool = false
var _榜单类型: String = "个人"
var _指标: String = "战力"
var _范围: String = "本服"
var _列表: VBoxContainer
var _self_label: Label
var _chip_个人: Button
var _chip_宗门: Button
var _指标chips: Dictionary = {}
var _指标chips_row: HBoxContainer
var _范围chips: Dictionary = {}

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
	_build_tabs(vbox)
	_指标chips_row = HBoxContainer.new()
	_指标chips_row.name = "Metrics"
	_指标chips_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_指标chips_row)
	_rebuild_metric_chips()
	_build_range_chips(vbox)

	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_列表 = VBoxContainer.new()
	_列表.name = "List"
	_列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_列表.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_列表)

	_self_label = Label.new()
	_self_label.name = "SelfRow"
	UITheme.apply_aux_text(_self_label)
	_self_label.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(_self_label)

func _build_header(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.name = "HeaderBar"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	var back: Button = UITheme.make_back_button(_on_back_pressed)
	bar.add_child(back)
	var title := Label.new()
	title.name = "Title"
	title.text = "玄榜  ⓘ"
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			UIHint.show_hint(title, "玄榜", "天下宗门实力排行榜。\n含个人修士榜与宗门势力榜；宗门榜涵盖探索进度、天下财富、功勋、商道、名望诸维。\n排名根据宗门总战力、弟子数量、资源储备综合评定。"))
	UITheme.apply_page_title(title)
	bar.add_child(title)
	parent.add_child(bar)

func _build_tabs(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "Tabs"
	row.add_theme_constant_override("separation", UITheme.GRID)
	_chip_个人 = _make_chip("个人修士榜", "个人", true, row)
	_chip_宗门 = _make_chip("宗门势力榜", "宗门", false, row)
	parent.add_child(row)

func _rebuild_metric_chips() -> void:
	for c in _指标chips_row.get_children():
		_指标chips_row.remove_child(c)
		c.queue_free()
	_指标chips.clear()
	# 个人榜仅弟子真实可排维度（战力/境界）；宗门榜含虚拟对手的累计指标
	# P2-3.2：宗门榜补「探索 / 财富」两维 → 对应任务书「探索进度榜 / 大地图财富榜」
	var 集合: Array = ["战力", "境界"] if _榜单类型 == "个人" else ["战力", "探索", "财富", "功勋", "商道", "名望"]
	if not 集合.has(_指标):
		_指标 = "战力"
	for m in 集合:
		_指标chips[m] = _make_chip(m, m, m == _指标, _指标chips_row)

func _build_range_chips(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "Ranges"
	row.add_theme_constant_override("separation", UITheme.GRID)
	for r in ["本服", "赛区", "全服"]:
		_范围chips[r] = _make_chip(r, r, r == _范围, row)
	parent.add_child(row)

func _make_chip(text: String, key: String, selected: bool, parent: Control) -> Button:
	var b: Button = Button.new()
	b.name = "Chip_" + key
	b.text = text
	b.custom_minimum_size = Vector2(0, 32)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_chip(b, selected)
	b.pressed.connect(_on_chip_pressed.bind(key, b))
	parent.add_child(b)
	return b

func _style_chip(b: Button, selected: bool) -> void:
	b.add_theme_stylebox_override("normal", _chip_style(selected))
	if selected:
		UITheme.apply_button_label(b, true)
		b.add_theme_color_override("font_color", UITheme.color_text_title1())
	else:
		UITheme.apply_aux_text(b)
		b.add_theme_color_override("font_color", UITheme.color_text_body_dim())

func _chip_style(selected: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.784, 0.659, 0.416) if selected else Color(0.094, 0.176, 0.215)
	sb.set_corner_radius_all(8)
	return sb

func _on_chip_pressed(key: String, b: Button) -> void:
	if key == "个人" or key == "宗门":
		_榜单类型 = key
		_style_chip(_chip_个人, key == "个人")
		_style_chip(_chip_宗门, key == "宗门")
		_rebuild_metric_chips()
	elif _指标chips.has(key):
		_指标 = key
		for k in _指标chips.keys():
			_style_chip(_指标chips[k], k == key)
	else:
		_范围 = key
		for k in _范围chips.keys():
			_style_chip(_范围chips[k], k == key)
	refresh()

func refresh() -> void:
	if not _built:
		_build()
	_populate()

func _populate() -> void:
	if _列表 == null:
		return
	for c in _列表.get_children():
		_列表.remove_child(c)
		c.queue_free()
	var 数据: Array = []
	if is_instance_valid(Game) and Game.has_method("取玄榜"):
		数据 = Game.取玄榜(_榜单类型, _指标, _范围)
	var 序号: int = 0
	for e in 数据:
		序号 += 1
		_列表.add_child(_建行(序号, e))
	if _self_label != null:
		var info: Dictionary = _self_info()
		var gap_txt: String = ("↑ 距上一名差 %d 分" % int(info.get("gap", 0))) if int(info.get("gap", 0)) > 0 else "领先群雄"
		_self_label.text = "#%d %s · %s %d · %s" % [int(info.get("rank", 0)), str(info.get("name", "")), _指标, int(info.get("val", 0)), gap_txt]

func _建行(序号: int, e: Dictionary) -> Control:
	var 行 := HBoxContainer.new()
	行.name = "Row_%d" % 序号
	行.add_theme_constant_override("separation", UITheme.GRID)
	var 冠: bool = 序号 <= 3
	var 排名 := Label.new()
	if 序号 == 1:
		排名.text = "① 第 1 名"
	elif 序号 == 2:
		排名.text = "② 第 2 名"
	elif 序号 == 3:
		排名.text = "③ 第 3 名"
	else:
		排名.text = "第 %d 名" % 序号
	排名.custom_minimum_size = Vector2(110, 0)
	UITheme.apply_value_text(排名, false)
	if 冠:
		排名.add_theme_color_override("font_color", UITheme.color_text_title1())
	else:
		排名.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	行.add_child(排名)
	var 名 := Label.new()
	名.text = str(e.get("名", ""))
	名.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_body_text(名)
	if 冠:
		名.add_theme_color_override("font_color", UITheme.color_text_title2())
	else:
		名.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	行.add_child(名)
	if str(e.get("称号", "")) != "":
		var 号 := Label.new()
		号.text = "「%s」" % str(e.get("称号", ""))
		UITheme.apply_aux_text(号)
		号.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		行.add_child(号)
	var 值 := Label.new()
	值.text = "%s %d" % [_指标, int(e.get("值", 0))]
	值.custom_minimum_size = Vector2(160, 0)
	值.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.apply_value_text(值, false)
	值.add_theme_color_override("font_color", UITheme.color_text_title1())
	行.add_child(值)
	return 行

func _self_info() -> Dictionary:
	if is_instance_valid(Game) and Game.has_method("取玄榜_self"):
		return Game.取玄榜_self(_榜单类型, _指标, _范围)
	return {"rank": 0, "name": "%s（你）" % "太玄宗", "val": 0, "gap": 0}

func _on_back_pressed() -> void:
	返回主页.emit()

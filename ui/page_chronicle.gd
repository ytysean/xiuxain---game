extends Control

# 纪事页（§6 · 辅助信息）：只读展示 4 分类 chip（大事件/岁纪/庶务/异闻，默认 大事件）+ 条目列表。
# 数据源 = Game.宗门纪事 ∪ Game.传承史册，按 §4.1 映射分流（UI 侧规则，零 Game 写；未命中→庶务）。
# 稀有度为 天品 / 异闻 时高亮 gold（apply_value_font(abnormal=false)），绝不用红。
# 零 GameState 写入；chip 切换 / 条目点击仅 emit 占位信号。读数经 is_instance_valid(Game) + .get() 守卫。

signal 纪事分类切换(分类: String)
signal 纪事条目详情(索引: int)

const 分类列表: Array = ["大事件", "岁纪", "庶务", "异闻"]

var _built: bool = false
var _list_vbox: VBoxContainer
var _chips: Dictionary = {}
var _current_category: String = "大事件"
var _entry_list: Array = []

func _ready() -> void:
	_build()
	refresh()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	_build_header(vbox)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_list_vbox = VBoxContainer.new()
	_list_vbox.name = "ListVBox"
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_list_vbox)

func _build_header(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "Header"
	panel.custom_minimum_size = Vector2(0, UITheme.GRID * 7)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(top)

	var 图标 = UITheme.load_icon_sized("纪事", UITheme.SIZE_SM)
	if 图标 != null:
		var tr := TextureRect.new()
		tr.texture = 图标
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.custom_minimum_size = Vector2(24, 24)
		top.add_child(tr)

	var title := Label.new()
	title.text = "纪事"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_title_font(title)
	top.add_child(title)

	var chip_row := HBoxContainer.new()
	chip_row.name = "Chips"
	chip_row.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(chip_row)
	for cat in 分类列表:
		var btn := Button.new()
		btn.name = "Chip_" + cat
		btn.text = cat
		btn.flat = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_tab_style(btn, cat == _current_category)
		btn.pressed.connect(_on_chip_pressed.bind(cat))
		chip_row.add_child(btn)
		_chips[cat] = btn

	parent.add_child(panel)

func refresh() -> void:
	if not _built:
		_build()
	_populate()

# §4.1 分类映射（UI 侧规则，零 Game 写）。兜底未命中→庶务。
func _classify(entry: Dictionary) -> String:
	var 稀有度 = str(entry.get("稀有度", ""))
	var category = str(entry.get("category", ""))
	var 名称 = str(entry.get("名称", ""))
	if 稀有度 == "异闻" or category == "异闻":
		return "异闻"
	if 稀有度 == "天品" or 稀有度 == "宗门" or category == "传承":
		return "大事件"
	if "岁" in 名称 or "七载" in 名称 or "大典" in 名称 or "晋升" in 名称:
		return "岁纪"
	if 稀有度 == "琐事" or 稀有度 == "普通" or 稀有度 == "殿阁被动":
		return "庶务"
	return "庶务"

func _populate() -> void:
	if _list_vbox == null:
		return
	for child in _list_vbox.get_children():
		_list_vbox.remove_child(child)
		child.queue_free()
	var 全部: Array = []
	if is_instance_valid(Game):
		var a = Game.get("宗门纪事")
		if a is Array:
			全部.append_array(a)
		var b = Game.get("传承史册")
		if b is Array:
			全部.append_array(b)
	_entry_list.clear()
	for e in 全部:
		if e is Dictionary and _classify(e) == _current_category:
			_entry_list.append(e)
	if _entry_list.is_empty():
		var empty := Label.new()
		empty.text = "暂无此类纪事"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_aux_font(empty)
		_list_vbox.add_child(empty)
		return
	for idx in range(_entry_list.size()):
		_add_entry_row(_entry_list[idx], idx)

func _add_entry_row(e: Dictionary, idx: int) -> void:
	var row := PanelContainer.new()
	row.name = "Entry_%d" % idx
	row.custom_minimum_size = Vector2(0, UITheme.GRID * 8)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)

	var l1 := HBoxContainer.new()
	l1.add_theme_constant_override("separation", UITheme.GRID)
	var 日 := Label.new()
	日.text = "第" + str(e.get("日", "—")) + "日"
	UITheme.apply_aux_font(日)
	l1.add_child(日)
	var 稀有度 = str(e.get("稀有度", ""))
	var 稀有度标签 := Label.new()
	稀有度标签.text = 稀有度 if 稀有度 != "" else "—"
	if 稀有度 == "天品" or 稀有度 == "异闻":
		UITheme.apply_value_font(稀有度标签, false)
	else:
		UITheme.apply_aux_font(稀有度标签)
	l1.add_child(稀有度标签)
	var 名称 := Label.new()
	名称.text = str(e.get("名称", "—"))
	名称.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	名称.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_font(名称)
	l1.add_child(名称)
	vbox.add_child(l1)

	var 文案 := Label.new()
	文案.text = str(e.get("文案", ""))
	文案.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_font(文案)
	vbox.add_child(文案)

	_list_vbox.add_child(row)
	_list_vbox.add_child(UITheme.make_divider_control())
	_pass_through(row)
	row.gui_input.connect(_on_entry_gui_input.bind(idx))

func _on_chip_pressed(cat: String) -> void:
	_current_category = cat
	for c in _chips.keys():
		UITheme.apply_tab_style(_chips[c], c == cat)
	纪事分类切换.emit(cat)
	_populate()

func _on_entry_gui_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			纪事条目详情.emit(idx)

func _pass_through(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			_pass_through(child)
			continue
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pass_through(child)

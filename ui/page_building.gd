extends Control

# 建筑页（§4 · 核心经营）：只读展示 建筑总览（堂口数 + Σ等级）+ 堂口列表（12 行）+ 底部 建筑被动_负面事件减免。
# 零 GameState 写入；升级按钮仅 emit 占位信号（实际写操作由宿主后续接线）。读数经 is_instance_valid(Game) + .get() 守卫。

signal 建筑详情请求(key: String)
signal 建筑升级请求(key: String)

var _built: bool = false
var _overview_堂口数: Label
var _overview_总等级: Label
var _list_vbox: VBoxContainer
var _passive_label: Label

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

	_build_overview(vbox)
	_build_list_scroll(vbox)
	_build_passive_bar(vbox)

func _build_overview(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "Overview"
	panel.custom_minimum_size = Vector2(0, UITheme.GRID * 7)
	UITheme.apply_panel_style(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(hb)

	var 图标 = UITheme.load_icon("建筑")
	if 图标 != null:
		var tr := TextureRect.new()
		tr.texture = 图标
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.custom_minimum_size = Vector2(24, 24)
		hb.add_child(tr)

	var title := Label.new()
	title.text = "建筑总览"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_title_font(title)
	hb.add_child(title)

	var 堂口_cell := VBoxContainer.new()
	堂口_cell.alignment = BoxContainer.ALIGNMENT_CENTER
	var 堂口_cap := Label.new()
	堂口_cap.text = "堂口"
	UITheme.apply_aux_font(堂口_cap)
	堂口_cell.add_child(堂口_cap)
	_overview_堂口数 = Label.new()
	_overview_堂口数.text = "—"
	UITheme.apply_value_font(_overview_堂口数, false)
	堂口_cell.add_child(_overview_堂口数)
	hb.add_child(堂口_cell)

	var 等级_cell := VBoxContainer.new()
	等级_cell.alignment = BoxContainer.ALIGNMENT_CENTER
	var 等级_cap := Label.new()
	等级_cap.text = "总等级"
	UITheme.apply_aux_font(等级_cap)
	等级_cell.add_child(等级_cap)
	_overview_总等级 = Label.new()
	_overview_总等级.text = "—"
	UITheme.apply_value_font(_overview_总等级, false)
	等级_cell.add_child(_overview_总等级)
	hb.add_child(等级_cell)

	parent.add_child(panel)

func _build_list_scroll(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	_list_vbox = VBoxContainer.new()
	_list_vbox.name = "ListVBox"
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(_list_vbox)

func _build_passive_bar(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "PassiveBar"
	panel.custom_minimum_size = Vector2(0, UITheme.GRID * 6)
	UITheme.apply_panel_style(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(hb)
	var cap := Label.new()
	cap.text = "建筑被动"
	UITheme.apply_aux_font(cap)
	hb.add_child(cap)
	_passive_label = Label.new()
	_passive_label.text = "负面事件减免 0%"
	UITheme.apply_aux_font(_passive_label)
	hb.add_child(_passive_label)
	parent.add_child(panel)

func refresh() -> void:
	if not _built:
		_build()
	_populate()

func _populate() -> void:
	var 堂口数 := 0
	var 总等级 := 0
	if is_instance_valid(Game):
		var 列表 = Game.get("堂口列表")
		if 列表 is Dictionary:
			堂口数 = 列表.size()
			for k in 列表.keys():
				var e = 列表[k]
				if e is Dictionary:
					总等级 += int(e.get("等级", 1))
	_overview_堂口数.text = str(堂口数)
	_overview_总等级.text = str(总等级)

	var 减免 = 0.0
	if is_instance_valid(Game):
		减免 = Game.get("建筑被动_负面事件减免")
		if typeof(减免) != TYPE_FLOAT and typeof(减免) != TYPE_INT:
			减免 = 0.0
	_passive_label.text = "负面事件减免 %d%%" % int(abs(减免))

	_populate_list()

func _populate_list() -> void:
	if _list_vbox == null:
		return
	for child in _list_vbox.get_children():
		_list_vbox.remove_child(child)
		child.queue_free()
	if not is_instance_valid(Game):
		return
	var 列表 = Game.get("堂口列表")
	if 列表 == null or not (列表 is Dictionary):
		return
	for key in 列表.keys():
		var e = 列表[key]
		if e is Dictionary:
			_add_hall_row(key, e)

func _add_hall_row(key: String, entry: Dictionary) -> void:
	var row := PanelContainer.new()
	row.name = "Hall_%s" % key
	row.custom_minimum_size = Vector2(0, UITheme.GRID * 12)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	UITheme.apply_panel_style(row)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	row.add_child(vbox)

	var l1 := HBoxContainer.new()
	l1.add_theme_constant_override("separation", UITheme.GRID)
	var 名称 := Label.new()
	名称.text = str(entry.get("名称", "—"))
	名称.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_body_font(名称)
	l1.add_child(名称)
	var 职能 := Label.new()
	职能.text = "职能:" + str(entry.get("职能", "—"))
	UITheme.apply_aux_font(职能)
	l1.add_child(职能)
	var 等级 := Label.new()
	等级.text = "Lv" + str(int(entry.get("等级", 1)))
	UITheme.apply_value_font(等级, false)
	l1.add_child(等级)
	vbox.add_child(l1)

	var l2 := HBoxContainer.new()
	l2.add_theme_constant_override("separation", UITheme.GRID)
	var 产出 := Label.new()
	产出.text = "产出:" + str(entry.get("产出", "—"))
	UITheme.apply_aux_font(产出)
	l2.add_child(产出)
	var 主事obj = entry.get("负责人", null)
	var 主事文本 := "主事:缺"
	if 主事obj != null and 主事obj is Object:
		var 主事名 = 主事obj.get("姓名")
		if 主事名 != null:
			主事文本 = "主事:" + str(主事名)
	var 主事 := Label.new()
	主事.text = 主事文本
	UITheme.apply_aux_font(主事)
	l2.add_child(主事)
	var 成员 = entry.get("成员", [])
	var 成员数 := 0
	if 成员 is Array:
		成员数 = 成员.size()
	var 成员标签 := Label.new()
	成员标签.text = "成员:%d" % 成员数
	UITheme.apply_aux_font(成员标签)
	l2.add_child(成员标签)
	vbox.add_child(l2)

	var l3 := HBoxContainer.new()
	l3.add_theme_constant_override("separation", UITheme.GRID)
	var 被动 := Label.new()
	被动.text = "被动:" + str(entry.get("加成维度", "—"))
	被动.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_aux_font(被动)
	l3.add_child(被动)
	var 升级 := Button.new()
	升级.name = "Upgrade_%s" % key
	升级.text = "修葺"
	升级.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	UITheme.apply_primary_button_style(升级)
	升级.pressed.connect(_on_升级_pressed.bind(key))
	l3.add_child(升级)
	vbox.add_child(l3)

	_list_vbox.add_child(row)
	_list_vbox.add_child(UITheme.make_divider_control())
	_pass_through(row)
	row.gui_input.connect(_on_hall_gui_input.bind(key))

func _on_hall_gui_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			建筑详情请求.emit(key)

func _on_升级_pressed(key: String) -> void:
	建筑升级请求.emit(key)

func _pass_through(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			_pass_through(child)
			continue
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pass_through(child)

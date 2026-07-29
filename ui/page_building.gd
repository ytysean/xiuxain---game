extends Control

# 建筑页（§4 · 核心经营）：只读展示 建筑总览（堂口数 + Σ等级）+ 堂口列表（12 行）+ 底部 建筑被动_负面事件减免。
# 零 GameState 写入；升级/任免/开关按钮仅 emit 占位信号（实际写操作由宿主后续接线）。读数经 is_instance_valid(Game) + .get() 守卫。
# P1：新增建筑详情二级子视图（ListRoot / DetailRoot 显隐模式，复用 page_disciple 的 DetailRoot 范式）。

signal 建筑详情请求(key: String)
signal 建筑升级请求(key: String)
signal 建筑任免请求(key: String)
signal 建筑开关请求(key: String, 开启: bool)
signal 建筑详情返回()

# 建筑等级上限派生常量：设计规格 §2.4 指定「上限取常量 10」；真实上限来自 Game._建筑等级上限() (min(门派等级,7))。
const 建筑等级上限_兜底: int = 10

var _built: bool = false
var _list_root: Control
var _detail_root: Control
var _detail_vbox: VBoxContainer
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
	vbox.name = "ListRoot"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	_list_root = vbox

	_build_overview(vbox)
	_build_list_scroll(vbox)
	_build_passive_bar(vbox)

	_detail_root = VBoxContainer.new()
	_detail_root.name = "DetailRoot"
	_detail_root.visible = false
	_detail_root.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_detail_root.add_theme_constant_override("margin_right", UITheme.MARGIN)
	_detail_root.add_theme_constant_override("margin_top", UITheme.GRID)
	_detail_root.add_theme_constant_override("margin_bottom", UITheme.GRID)
	_detail_root.add_theme_constant_override("separation", UITheme.GRID * 2)
	_detail_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_detail_root)
	_build_detail_root()

func _build_overview(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "Overview"
	panel.custom_minimum_size = Vector2(0, UITheme.GRID * 7)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(hb)

	var 图标 = UITheme.load_icon_sized("建筑", UITheme.SIZE_SM)
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
	_list_vbox.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_list_vbox)

func _build_passive_bar(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "PassiveBar"
	panel.custom_minimum_size = Vector2(0, UITheme.GRID * 6)
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
	# 卡片高度提到 GRID*16，足以容纳 名称/职能/等级 + 产出/主事/成员 + 被动/修葺 三行；
	# 内容更高时 PanelContainer 会自动撑高，custom_minimum_size 仅作下限防贴边。
	row.custom_minimum_size = Vector2(0, UITheme.GRID * 16)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
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
	职能.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	职能.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	职能.custom_minimum_size = Vector2(UITheme.GRID * 8, 0)
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
	产出.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	产出.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	产出.custom_minimum_size = Vector2(UITheme.GRID * 10, 0)
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
	被动.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	被动.custom_minimum_size = Vector2(UITheme.GRID * 12, 0)
	UITheme.apply_aux_font(被动)
	l3.add_child(被动)
	var 升级 := Button.new()
	升级.name = "Upgrade_%s" % key
	升级.text = "修葺"
	升级.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	升级.pressed.connect(_on_升级_pressed.bind(key, 升级))
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
			_show_detail(key)

func _on_升级_pressed(key: String, btn: Button = null) -> void:
	if btn != null:
		UITween.button_press(btn)
	建筑升级请求.emit(key)

# ───────── 建筑详情二级子视图（ListRoot / DetailRoot 显隐，复用 page_disciple 范式）─────────
func _build_detail_root() -> void:
	var bar := HBoxContainer.new()
	bar.name = "BackBar"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	var back_btn := Button.new()
	back_btn.name = "BackBtn"
	back_btn.text = "← 返回"
	back_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	back_btn.pressed.connect(_on_back_pressed)
	bar.add_child(back_btn)
	var title := Label.new()
	title.text = "建筑详情"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_title_font(title)
	bar.add_child(title)
	_detail_root.add_child(bar)

	var scroll := ScrollContainer.new()
	scroll.name = "DetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_root.add_child(scroll)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.name = "DetailVBox"
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	scroll.add_child(_detail_vbox)

func _show_detail(key: String) -> void:
	if _detail_root == null or _list_root == null:
		return
	_populate_building_detail(key)
	_list_root.visible = false
	_detail_root.visible = true
	UITween.fade_in(_detail_root)

func _on_back_pressed() -> void:
	建筑详情返回.emit()
	_detail_root.visible = false
	if _list_root != null:
		_list_root.visible = true

func _populate_building_detail(key: String) -> void:
	if _detail_vbox == null:
		return
	for child in _detail_vbox.get_children():
		_detail_vbox.remove_child(child)
		child.queue_free()

	if not is_instance_valid(Game):
		return
	var 列表 = Game.get("堂口列表")
	if 列表 == null or not (列表 is Dictionary):
		return
	var entry = 列表.get(key, null)
	if entry == null or not (entry is Dictionary):
		return

	var 等级: int = int(_safe_get(entry, "等级", 1))
	var 上限: int = _建筑上限()

	_build_header(entry, 等级, 上限)

	var 产出区: VBoxContainer = _add_section("产出信息")
	_add_kv_row(产出区, "产出", str(_safe_get(entry, "产出", "—")))
	var 预估: int = 0
	if Game.has_method("预估建筑产出"):
		预估 = int(Game.预估建筑产出(key))
	_add_kv_row(产出区, "预估月产出", "%d" % 预估)
	var 等级乘区: float = 1.0 + 0.02 * max(0, 等级 - 1)
	_add_kv_row(产出区, "等级乘区", "x%.2f" % 等级乘区)

	var 升级区: VBoxContainer = _add_section("升级操作")
	_build_upgrade_bar(升级区, 等级, 上限)
	_build_upgrade_button(升级区, key, 等级, 上限)

	var 人员区: VBoxContainer = _add_section("人员管理")
	var 负责人obj = _safe_get(entry, "负责人", null)
	var 负责人名 := "缺"
	if 负责人obj != null and 负责人obj is Object:
		var 名v = 负责人obj.get("姓名")
		if 名v != null:
			负责人名 = str(名v)
	_add_kv_row(人员区, "主事", 负责人名)
	var 成员 = _safe_get(entry, "成员", [])
	var 成员数: int = 0
	if 成员 is Array:
		成员数 = 成员.size()
	_add_kv_row(人员区, "成员数", "%d" % 成员数)
	_build_任免_button(人员区, key)

	var 被动区: VBoxContainer = _add_section("被动效果")
	_build_被动效果(被动区, entry)

	# 功能开关区：仅当 entry 真实存在 负责人锁定(bool) 字段才展示 Toggle（设计规格附录A 降级项）
	var 锁定v = entry.get("负责人锁定", null)
	if typeof(锁定v) == TYPE_BOOL:
		var 开关区: VBoxContainer = _add_section("功能开关")
		_build_lock_toggle(开关区, key, bool(锁定v))

	_build_footer(key, 等级, 上限)

func _build_header(entry: Dictionary, 等级: int, 上限: int) -> void:
	var panel := PanelContainer.new()
	panel.name = "HeaderSection"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)

	var 名称 := Label.new()
	名称.text = str(_safe_get(entry, "名称", "—"))
	UITheme.apply_title_font(名称)
	vbox.add_child(名称)

	var 职能 := Label.new()
	职能.text = "职能：" + str(_safe_get(entry, "职能", "—"))
	UITheme.apply_aux_font(职能)
	vbox.add_child(职能)

	var 等级行 := HBoxContainer.new()
	等级行.add_theme_constant_override("separation", UITheme.GRID)
	var 等级标签 := Label.new()
	等级标签.text = "等级 %d / %d" % [等级, 上限]
	UITheme.apply_value_font(等级标签, false)
	等级行.add_child(等级标签)
	等级行.add_spacer(true)
	var 加成标签 := Label.new()
	加成标签.text = "加成：" + str(_safe_get(entry, "加成维度", "—"))
	UITheme.apply_aux_font(加成标签)
	等级行.add_child(加成标签)
	vbox.add_child(等级行)

	_detail_vbox.add_child(panel)

func _add_section(标题: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "Section_%s" % 标题
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)
	var t := Label.new()
	t.text = 标题
	UITheme.apply_title_font(t)
	vbox.add_child(t)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(content)
	_detail_vbox.add_child(panel)
	return content

func _add_kv_row(parent: Control, 标题: String, 值: String, 异常: bool = false) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var c := Label.new()
	c.text = 标题
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.custom_minimum_size = Vector2(UITheme.GRID * 12, 0)
	UITheme.apply_aux_font(c)
	hb.add_child(c)
	var v := Label.new()
	v.text = 值
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if 异常:
		UITheme.apply_value_font(v, true)
	else:
		UITheme.apply_body_font(v)
	hb.add_child(v)
	parent.add_child(hb)

func _build_upgrade_bar(parent: Control, 等级: int, 上限: int) -> void:
	var bar := ProgressBar.new()
	bar.name = "UpgradeBar"
	bar.min_value = 0.0
	bar.max_value = float(上限) if 上限 > 0 else 1.0
	bar.value = float(等级)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, UITheme.GRID * 2)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = UITheme.color_text_gold()
	fill.set_corner_radius_all(UITheme.RADIUS_BUTTON)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.color_bg_content()
	bg.set_corner_radius_all(UITheme.RADIUS_BUTTON)
	bar.add_theme_stylebox_override("background", bg)
	parent.add_child(bar)

	var cap := Label.new()
	cap.text = "修葺 Lv %d / %d" % [等级, 上限]
	UITheme.apply_aux_font(cap)
	parent.add_child(cap)

func _build_upgrade_button(parent: Control, key: String, 等级: int, 上限: int) -> void:
	var btn := Button.new()
	btn.name = "UpgradeBtn"
	btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_primary_button_style(btn)
	if 等级 < 上限:
		btn.text = "修葺升级"
		btn.disabled = false
	else:
		btn.text = "已达上限"
		btn.disabled = true
	btn.pressed.connect(_on_升级_pressed.bind(key, btn))
	parent.add_child(btn)

func _build_任免_button(parent: Control, key: String) -> void:
	var btn := Button.new()
	btn.name = "AppointBtn"
	btn.text = "任免主事"
	btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(btn)
	btn.pressed.connect(_on_任免_pressed.bind(btn, key))
	parent.add_child(btn)

func _build_被动效果(parent: Control, entry: Dictionary) -> void:
	var 加成 = _safe_get(entry, "加成维度", null)
	if 加成 is Dictionary:
		for k in 加成.keys():
			_add_kv_row(parent, str(k), str(加成[k]))
	elif 加成 is Array:
		for item in 加成:
			_add_kv_row(parent, "加成维度", str(item))
	else:
		_add_kv_row(parent, "加成维度", str(加成) if 加成 != null else "—")
	_add_kv_row(parent, "政绩", str(_safe_get(entry, "政绩", 0)))
	_add_kv_row(parent, "里程碑", str(_safe_get(entry, "里程碑", 0)))

func _build_lock_toggle(parent: Control, key: String, 锁定: bool) -> void:
	var check := CheckButton.new()
	check.name = "LockToggle"
	check.text = "主事锁定"
	check.button_pressed = 锁定
	check.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.pressed.connect(_on_lock_pressed.bind(check))
	check.toggled.connect(_on_lock_toggled.bind(key))
	parent.add_child(check)

func _build_footer(key: String, 等级: int, 上限: int) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var back := Button.new()
	back.name = "BackToList"
	back.text = "返回列表"
	back.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(back)
	back.pressed.connect(_on_back_pressed)
	hb.add_child(back)

	var up := Button.new()
	up.name = "UpgradeFooter"
	up.text = "升级"
	up.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_primary_button_style(up)
	if not (等级 < 上限):
		up.disabled = true
	up.pressed.connect(_on_升级_pressed.bind(key, up))
	hb.add_child(up)

	_detail_vbox.add_child(hb)

func _on_任免_pressed(btn: Button, key: String) -> void:
	UITween.button_press(btn)
	建筑任免请求.emit(key)

func _on_lock_pressed(btn: Button) -> void:
	UITween.button_press(btn)

func _on_lock_toggled(开启: bool, key: String) -> void:
	建筑开关请求.emit(key, 开启)

func _建筑上限() -> int:
	if is_instance_valid(Game) and Game.has_method("_建筑等级上限"):
		return int(Game._建筑等级上限())
	return 建筑等级上限_兜底

func _safe_get(obj: Variant, prop: String, default: Variant = null) -> Variant:
	if obj == null:
		return default
	if obj is Dictionary:
		return obj.get(prop, default)
	if obj is Object:
		var v = obj.get(prop)
		return v if v != null else default
	return default

# 让 PanelContainer 行整体可点：除 Button 外所有子节点设为 IGNORE，事件穿透到 PanelContainer。
func _pass_through(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			_pass_through(child)
			continue
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pass_through(child)

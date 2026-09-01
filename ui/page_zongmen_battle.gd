extends Control

# 宗门战页（GameUI 二级页）：战斗类型选择、队伍编制、护山大阵、战前增益、开始战斗
# 全部字体走 UITheme 角色 helper，战斗逻辑调用 ZongmenBattle 静态方法
signal 返回主页
signal 战斗开始(battle_type: String)

var _built: bool = false
var _当前战斗类型: String = "宗门攻防战"
var _当前队伍索引: int = 0
var _buffs: Dictionary = {"聚灵阵加持": false, "战鼓激励": false, "护盾结界": false, "丹药补给": false}
# S1-3 接线：3 队 × 5 槽的真实编制（元素为 Disciple 或 null）
var _队伍编制: Array = [[null, null, null, null, null], [null, null, null, null, null], [null, null, null, null, null]]
var _槽位名: Array = ["前", "前", "中", "中", "后"]

const BATTLE_TYPES: Array = ["宗门攻防战", "秘境争夺战", "妖兽围剿战", "阵营围剿战"]
const BATTLE_TYPE_DESC: Dictionary = {
	"宗门攻防战": "攻破护山大阵",
	"秘境争夺战": "争夺秘境资源",
	"妖兽围剿战": "围剿妖兽族群",
	"阵营围剿战": "阵营之间围剿",
}

func _ready() -> void:
	_build()
	refresh()

func _enter_tree() -> void:
	if _built:
		refresh.call_deferred()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var content: Control = UITheme.make_scene_background(self)

	var margin := MarginContainer.new()
	margin.name = "MarginRoot"
	margin.add_theme_constant_override("margin_left", UITheme.MARGIN)
	margin.add_theme_constant_override("margin_right", UITheme.MARGIN)
	margin.add_theme_constant_override("margin_top", UITheme.GRID)
	margin.add_theme_constant_override("margin_bottom", UITheme.GRID)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "BattleScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var root := VBoxContainer.new()
	root.name = "RootVBox"
	root.add_theme_constant_override("separation", UITheme.GRID)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	_build_header(root)
	_build_battle_types(root)
	_build_power_comparison(root)
	_build_team_section(root)
	_build_array_section(root)
	_build_buff_section(root)
	_build_battle_button(root)

func _build_header(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "HeaderBar"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(bar)

	var back: Button = UITheme.make_back_button(_on_back_pressed)
	bar.add_child(back)

	var title := Label.new()
	title.text = "宗门战"
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_RED)
	UITheme.apply_title_font(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(UITheme.BACK_BTN_SIZE, 0)
	bar.add_child(spacer)

func _build_battle_types(parent: Control) -> void:
	var grid := GridContainer.new()
	grid.name = "BattleTypes"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UITheme.GRID)
	grid.add_theme_constant_override("v_separation", UITheme.GRID)
	parent.add_child(grid)

	for btype in BATTLE_TYPES:
		var card := Button.new()
		card.name = "Type_" + btype
		card.custom_minimum_size = Vector2(0, UITheme.SIZE_MD)
		card.clip_text = true
		card.pressed.connect(_on_type_pressed.bind(btype))
		grid.add_child(card)

		var vbox := VBoxContainer.new()
		vbox.name = "TypeVBox"
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 4)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(vbox)

		var icon := Label.new()
		icon.text = "⚔️"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_title_font(icon)
		vbox.add_child(icon)

		var name := Label.new()
		name.text = btype
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_body_text(name)
		vbox.add_child(name)

		var desc := Label.new()
		desc.text = BATTLE_TYPE_DESC[btype]
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_aux_text(desc)
		vbox.add_child(desc)
	刷新类型卡()

func _build_power_comparison(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "PowerComparison"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UITheme.GRID)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var attacker := VBoxContainer.new()
	attacker.add_theme_constant_override("separation", 4)
	hbox.add_child(attacker)

	var attacker_label := Label.new()
	attacker_label.text = "我方战力"
	attacker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_aux_text(attacker_label)
	attacker.add_child(attacker_label)

	var attacker_value := Label.new()
	attacker_value.name = "AttackerPower"
	attacker_value.text = "0"
	attacker_value.add_theme_color_override("font_color", Color(0.39, 0.78, 1.0))
	UITheme.apply_title_font(attacker_value)
	attacker_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attacker.add_child(attacker_value)

	var vs := Label.new()
	vs.text = "VS"
	vs.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_body_text(vs)
	vs.custom_minimum_size = Vector2(60, 0)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(vs)

	var defender := VBoxContainer.new()
	defender.add_theme_constant_override("separation", 4)
	hbox.add_child(defender)

	var defender_label := Label.new()
	defender_label.text = "敌方战力"
	defender_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_aux_text(defender_label)
	defender.add_child(defender_label)

	var defender_value := Label.new()
	defender_value.name = "DefenderPower"
	defender_value.text = "0"
	defender_value.add_theme_color_override("font_color", UITheme.COLOR_TEXT_RED)
	UITheme.apply_title_font(defender_value)
	defender_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defender.add_child(defender_value)

func _build_team_section(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "TeamSection"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("offset_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_bottom", UITheme.PAD_PANEL)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "队伍编制"
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_body_text(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var hint := Label.new()
	hint.text = "每队5人，最多3队"
	UITheme.apply_aux_text(hint)
	header.add_child(hint)

	# 队伍Tab
	var team_tabs := HBoxContainer.new()
	team_tabs.name = "TeamTabs"
	team_tabs.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_child(team_tabs)

	for i in range(3):
		var tab := Button.new()
		tab.name = "TeamTab_%d" % i
		tab.text = "第%d队" % (i + 1)
		tab.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
		UITheme.apply_secondary_button_style(tab)
		if i == 0:
			UITheme.apply_primary_button_style(tab)
		tab.pressed.connect(_on_team_tab_pressed.bind(i))
		team_tabs.add_child(tab)

	# 队员格子：S1-3 改为可点击槽位（点击弹弟子选择）
	var grid := GridContainer.new()
	grid.name = "TeamGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", UITheme.GRID / 2)
	grid.add_theme_constant_override("v_separation", UITheme.GRID / 2)
	vbox.add_child(grid)

	for i in range(5):
		var slot := Button.new()
		slot.name = "Slot_%d" % i
		slot.custom_minimum_size = Vector2(0, UITheme.SIZE_MD)
		slot.clip_text = true
		UITheme.apply_secondary_button_style(slot)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(slot)

	# 站位说明
	var legend := Label.new()
	legend.text = "前排×2（抗伤）  中排×2（输出）  后排×1（辅助）｜点击槽位安排弟子"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(legend)
	vbox.add_child(legend)
	刷新槽位()

func _build_array_section(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "ArraySection"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("offset_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_bottom", UITheme.PAD_PANEL)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "护山大阵"
	title.add_theme_color_override("font_color", Color(0.39, 0.78, 1.0))
	UITheme.apply_body_text(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var level := Label.new()
	level.text = "防守方专属"
	UITheme.apply_aux_text(level)
	header.add_child(level)

	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(info)

	var array_name := Label.new()
	array_name.text = "太玄护山大阵"
	UITheme.apply_body_text(array_name)
	array_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(array_name)

	var array_level := Label.new()
	array_level.text = "Lv.1"
	UITheme.apply_aux_text(array_level)
	info.add_child(array_level)

	# 耐久条
	var durability_panel := PanelContainer.new()
	durability_panel.custom_minimum_size = Vector2(0, 16)
	durability_panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(true))
	vbox.add_child(durability_panel)

	var durability_bar := ProgressBar.new()
	durability_bar.name = "DurabilityBar"
	durability_bar.min_value = 0
	durability_bar.max_value = 100
	durability_bar.value = 100
	durability_bar.show_percentage = false
	durability_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	durability_panel.add_child(durability_bar)

	var durability_text := Label.new()
	durability_text.name = "DurabilityText"
	durability_text.text = "耐久：1000 / 1000"
	durability_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.apply_aux_text(durability_text)
	vbox.add_child(durability_text)

	# 大阵效果
	var effects := HBoxContainer.new()
	effects.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(effects)

	var effect1 := Label.new()
	effect1.text = "减伤+30%"
	effect1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect1.add_theme_color_override("font_color", Color(0.39, 0.78, 1.0))
	UITheme.apply_aux_text(effect1)
	effect1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects.add_child(effect1)

	var effect2 := Label.new()
	effect2.text = "反击+10%"
	effect2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect2.add_theme_color_override("font_color", Color(0.39, 0.78, 1.0))
	UITheme.apply_aux_text(effect2)
	effect2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects.add_child(effect2)

func _build_buff_section(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "BuffSection"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("offset_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_bottom", UITheme.PAD_PANEL)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "战前增益"
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.39))
	UITheme.apply_body_text(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var hint := Label.new()
	hint.text = "消耗资源激活"
	UITheme.apply_aux_text(hint)
	header.add_child(hint)

	var buffs: Array = [
		{"name": "聚灵阵加持", "effect": "攻击+10%，防御+10%，持续5回合", "cost": "500灵石"},
		{"name": "战鼓激励", "effect": "攻击+15%，持续3回合", "cost": "300灵石"},
		{"name": "护盾结界", "effect": "防御+20%，持续4回合", "cost": "400灵石"},
		{"name": "丹药补给", "effect": "生命+15%", "cost": "5丹药"},
	]
	for buff in buffs:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", UITheme.GRID / 2)
		vbox.add_child(item)

		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(info)

		var name := Label.new()
		name.text = buff["name"]
		name.add_theme_color_override("font_color", Color(1.0, 0.78, 0.39))
		UITheme.apply_body_text(name)
		info.add_child(name)

		var effect := Label.new()
		effect.text = buff["effect"]
		UITheme.apply_aux_text(effect)
		info.add_child(effect)

		var cost := Label.new()
		cost.text = buff["cost"]
		cost.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		UITheme.apply_aux_text(cost)
		cost.custom_minimum_size = Vector2(80, 0)
		item.add_child(cost)

		var toggle := Button.new()
		toggle.name = "Toggle_" + buff["name"]
		toggle.text = "OFF"
		toggle.custom_minimum_size = Vector2(60, UITheme.BTN_H_SECONDARY)
		UITheme.apply_secondary_button_style(toggle)
		toggle.pressed.connect(_on_buff_toggle.bind(buff["name"]))
		item.add_child(toggle)

func _build_battle_button(parent: Control) -> void:
	var btn := Button.new()
	btn.name = "StartBattleBtn"
	btn.text = "⚔️ 开始战斗"
	btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	UITheme.apply_primary_button_style(btn)
	btn.pressed.connect(_on_start_battle)
	parent.add_child(btn)

func refresh() -> void:
	if not _built:
		return
	刷新槽位()
	刷新类型卡()
	刷新战力对比()

# 我方战力 = 已编入槽位弟子的战力合计（未编制时为 0，不再用「全宗门战力」虚高误导）
func _编制战力() -> int:
	var total: int = 0
	for 队 in _队伍编制:
		for d in 队:
			if d != null and is_instance_valid(d):
				total += int(d.总战力())
	return total

func 刷新战力对比() -> void:
	var mine: int = _编制战力()
	var 系数: float = float(Game.宗门战难度系数.get(_当前战斗类型, 1.0)) if Game.has_method("发起宗门战") else 1.0
	var attacker_val = find_child("AttackerPower", true, false)
	if attacker_val != null:
		attacker_val.text = "%d" % mine
	var defender_val = find_child("DefenderPower", true, false)
	if defender_val != null:
		defender_val.text = "%d" % int(float(mine) * 系数)

func 刷新类型卡() -> void:
	for btype in BATTLE_TYPES:
		var card = find_child("Type_" + btype, true, false)
		if card == null:
			continue
		if btype == _当前战斗类型:
			UITheme.apply_primary_button_style(card)
		else:
			UITheme.apply_secondary_button_style(card)

func _on_type_pressed(btype: String) -> void:
	_当前战斗类型 = btype
	刷新类型卡()
	刷新战力对比()

func 刷新槽位() -> void:
	for i in range(5):
		var slot = find_child("Slot_%d" % i, true, false)
		if slot == null:
			continue
		var d = _队伍编制[_当前队伍索引][i]
		if d == null or not is_instance_valid(d):
			slot.text = "%s\n➕\n空位" % _槽位名[i]
			UITheme.apply_secondary_button_style(slot)
		else:
			slot.text = "%s\n%s\n战%d" % [_槽位名[i], d.姓名, int(d.总战力())]
			UITheme.apply_primary_button_style(slot)

func _on_back_pressed() -> void:
	返回主页.emit()

func _on_team_tab_pressed(index: int) -> void:
	_当前队伍索引 = index
	for i in range(3):
		var tab = find_child("TeamTab_%d" % i, true, false)
		if tab == null:
			continue
		if i == index:
			UITheme.apply_primary_button_style(tab)
		else:
			UITheme.apply_secondary_button_style(tab)
	刷新槽位()

# 槽位点击：弹出弟子选择（已编入其他槽的弟子不再列出，避免重复上阵）
func _on_slot_pressed(槽位: int) -> void:
	var 已占用: Array = []
	for 队 in _队伍编制:
		for d in 队:
			if d != null:
				已占用.append(d)
	var 可选: Array = []
	for d in Game.弟子列表:
		if d != null and not 已占用.has(d):
			可选.append(d)
	var 遮 := ColorRect.new()
	遮.color = Color(0, 0, 0, 0.72)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "选人弹窗"
	add_child(遮)
	var 外 := MarginContainer.new()
	外.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	外.add_theme_constant_override("margin_left", UITheme.MARGIN)
	外.add_theme_constant_override("margin_right", UITheme.MARGIN)
	外.add_theme_constant_override("margin_top", UITheme.MARGIN)
	外.add_theme_constant_override("margin_bottom", UITheme.MARGIN)
	遮.add_child(外)
	var 列 := VBoxContainer.new()
	列.add_theme_constant_override("separation", UITheme.GRID / 2)
	外.add_child(列)
	var 头 := Label.new()
	头.text = "第%d队·%s排 选择弟子" % [_当前队伍索引 + 1, _槽位名[槽位]]
	UITheme.apply_body_text(头)
	头.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	列.add_child(头)
	var 滚 := ScrollContainer.new()
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	列.add_child(滚)
	var 内列 := VBoxContainer.new()
	内列.add_theme_constant_override("separation", 4)
	滚.add_child(内列)
	if 可选.is_empty():
		var 空 := Label.new()
		空.text = "（无可派遣弟子：弟子已全部编入队伍）"
		UITheme.apply_aux_text(空)
		内列.add_child(空)
	else:
		可选.sort_custom(func(a, b): return int(a.总战力()) > int(b.总战力()))
		for d in 可选:
			var b := Button.new()
			b.text = "%s（%s 战%d）" % [d.姓名, d.境界, int(d.总战力())]
			b.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
			UITheme.apply_secondary_button_style(b)
			b.pressed.connect(func():
				_队伍编制[_当前队伍索引][槽位] = d
				遮.queue_free()
				刷新槽位()
				刷新战力对比()
			)
			内列.add_child(b)
	var 清 := Button.new()
	清.text = "清空此位"
	清.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	UITheme.apply_secondary_button_style(清)
	清.pressed.connect(func():
		_队伍编制[_当前队伍索引][槽位] = null
		遮.queue_free()
		刷新槽位()
		刷新战力对比()
	)
	列.add_child(清)
	var 撤 := Button.new()
	撤.text = "折返"
	撤.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	UITheme.apply_secondary_button_style(撤)
	撤.pressed.connect(func(): 遮.queue_free())
	列.add_child(撤)

func _on_buff_toggle(buff_name: String) -> void:
	_buffs[buff_name] = not _buffs[buff_name]
	var toggle = find_child("Toggle_" + buff_name, true, false)
	if toggle != null:
		if _buffs[buff_name]:
			toggle.text = "ON"
			UITheme.apply_primary_button_style(toggle)
		else:
			toggle.text = "OFF"
			UITheme.apply_secondary_button_style(toggle)

# 丹药库存：Game.宗门库房 中 类别=="丹药" 的道具（丹殿炼制 / 坊市购买均入此库）
func _库存丹药数() -> int:
	var n: int = 0
	for it in Game.宗门库房:
		if it != null and str(it.类别) == "丹药":
			n += 1
	return n

func _消耗丹药(数量: int) -> void:
	var 剩余: int = 数量
	var 待删: Array = []
	for it in Game.宗门库房:
		if 剩余 <= 0:
			break
		if it != null and str(it.类别) == "丹药":
			待删.append(it)
			剩余 -= 1
	for it in 待删:
		Game.宗门库房.erase(it)

func _on_start_battle() -> void:
	# 1 资源校验（灵石 + 丹药）
	var 灵石消耗: int = 0
	if _buffs["聚灵阵加持"]: 灵石消耗 += 500
	if _buffs["战鼓激励"]: 灵石消耗 += 300
	if _buffs["护盾结界"]: 灵石消耗 += 400
	var 丹药消耗: int = 5 if bool(_buffs["丹药补给"]) else 0
	if Game.灵石 < 灵石消耗:
		Game.添加提示("灵石匮乏，需要%d灵石" % 灵石消耗)
		return
	if 丹药消耗 > 0 and _库存丹药数() < 丹药消耗:
		Game.添加提示("丹药不足，「丹药补给」需%d颗丹药" % 丹药消耗)
		return
	# 2 编制校验
	var 出战队伍: Array = []
	for 队 in _队伍编制:
		var 成员: Array = []
		for d in 队:
			if d != null and is_instance_valid(d):
				成员.append(d)
		if 成员.size() > 0:
			出战队伍.append(成员)
	if 出战队伍.is_empty():
		Game.添加提示("请先在「队伍编制」中安排至少 1 名弟子")
		return
	# 3 扣费（失败时回滚）
	if 灵石消耗 > 0:
		Game.灵石 -= 灵石消耗
	if 丹药消耗 > 0:
		_消耗丹药(丹药消耗)
	# 4 发起宗门战（战斗逻辑全在 Game.发起宗门战，UI 不碰结算核心）
	if not Game.has_method("发起宗门战"):
		Game.灵石 += 灵石消耗
		Game.添加提示("宗门战后端未就绪")
		return
	var 结果: Dictionary = Game.发起宗门战(_当前战斗类型, 出战队伍, _buffs)
	if not bool(结果.get("ok", false)):
		Game.灵石 += 灵石消耗
		Game.添加提示("宗门战未开始：" + str(结果.get("error", "未知原因")))
		return
	战斗开始.emit(_当前战斗类型)
	_显示战报(结果)

# 战报结算面板：结果 / 回合 / 剩余队伍 / 大阵 / 奖励 / 战斗日志
func _显示战报(结果: Dictionary) -> void:
	var 战报: Dictionary = 结果.get("战报", {})
	var 结果文本: String = str(战报.get("战斗结果", ""))
	var 胜: bool = 结果文本 == "攻方胜利"
	var 遮 := ColorRect.new()
	遮.color = Color(0, 0, 0, 0.78)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "宗门战战报"
	add_child(遮)
	var 外 := MarginContainer.new()
	外.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	外.add_theme_constant_override("margin_left", UITheme.MARGIN)
	外.add_theme_constant_override("margin_right", UITheme.MARGIN)
	外.add_theme_constant_override("margin_top", UITheme.MARGIN * 2)
	外.add_theme_constant_override("margin_bottom", UITheme.MARGIN)
	遮.add_child(外)
	var 列 := VBoxContainer.new()
	列.add_theme_constant_override("separation", UITheme.GRID / 2)
	外.add_child(列)

	var 头 := Label.new()
	头.text = "⚔ %s：%s" % [str(战报.get("战斗类型", "")), 结果文本]
	头.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD if 胜 else UITheme.COLOR_TEXT_RED)
	UITheme.apply_title_font(头)
	列.add_child(头)

	var 摘要文本: String = "回合 %d ｜ 我方剩余队伍 %d ｜ 敌方剩余队伍 %d" % [
		int(战报.get("总回合数", 0)), int(战报.get("攻方剩余队伍数", 0)), int(战报.get("守方剩余队伍数", 0))]
	var 摘要 := Label.new()
	摘要.text = 摘要文本
	UITheme.apply_body_text(摘要)
	列.add_child(摘要)

	if bool(战报.get("大阵是否被破", false)):
		var 阵 := Label.new()
		阵.text = "敌方护山大阵已被攻破"
		阵.add_theme_color_override("font_color", Color(0.39, 0.78, 1.0))
		UITheme.apply_aux_text(阵)
		列.add_child(阵)

	var 奖 := Label.new()
	奖.text = "所得：%s" % str(结果.get("奖励文本", "无"))
	奖.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_text(奖)
	列.add_child(奖)

	var 日志标 := Label.new()
	日志标.text = "—— 战斗日志 ——"
	日志标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_aux_text(日志标)
	列.add_child(日志标)
	var 滚 := ScrollContainer.new()
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.custom_minimum_size = Vector2(0, 240)
	列.add_child(滚)
	var 日志列 := VBoxContainer.new()
	日志列.add_theme_constant_override("separation", 2)
	滚.add_child(日志列)
	for 行 in 战报.get("战斗日志", []):
		var 行标 := Label.new()
		行标.text = str(行)
		行标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_aux_text(行标)
		日志列.add_child(行标)

	var 确 := Button.new()
	确.text = "可"
	确.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	UITheme.apply_primary_button_style(确)
	确.pressed.connect(func():
		遮.queue_free()
		refresh()
	)
	列.add_child(确)

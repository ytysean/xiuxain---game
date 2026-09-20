extends Control

# 宗门战页（GameUI 二级页）：战斗类型选择、队伍编制、护山大阵、战前增益、开始战斗
# 全部字体走 UITheme 角色 helper，战斗逻辑调用 ZongmenBattle 静态方法
signal 返回主页
signal 战斗开始(battle_type: String)

var _built: bool = false
var _当前战斗类型: String = "宗门攻防战"
var _当前队伍索引: int = 0
var _buffs: Dictionary = {"聚灵阵加持": false, "战鼓激励": false, "护盾结界": false, "丹药补给": false, "赤焰战鼓": false, "玄龟护盾": false, "九转还魂丹": false}
# S32 战功道具 → battle_merit_shop.csv 商品 id（后端 发起宗门战 按此 id 硬扣库存）
const 战功道具映射: Dictionary = {"赤焰战鼓": "bm_drum", "玄龟护盾": "bm_shield", "九转还魂丹": "bm_hp"}
# S1-3 接线：3 队 × 5 槽的真实编制（元素为 Disciple 或 null）
var _队伍编制: Array = [[null, null, null, null, null], [null, null, null, null, null], [null, null, null, null, null]]
var _槽位名: Array = ["前", "前", "中", "中", "后"]

const BATTLE_TYPES: Array = ["宗门攻防战", "秘境争夺战", "妖兽围剿战", "阵营围剿战"]
# 四类战事的专属图标：一律用项目既有 emoji 资产 stem（art/icons/emoji/，禁自造图标）。
const BATTLE_TYPE_ICON: Dictionary = {
	"宗门攻防战": "emoji_offline_hall",
	"秘境争夺战": "emoji_world_location",
	"妖兽围剿战": "emoji_world_beast",
	"阵营围剿战": "emoji_faction_cross",
}
const BATTLE_TYPE_DESC: Dictionary = {
	"宗门攻防战": "攻破护山大阵｜宣战占领城池",
	"秘境争夺战": "争夺秘境资源｜宣战占领矿脉",
	"妖兽围剿战": "围剿妖兽族群｜宣战占领秘境",
	"阵营围剿战": "阵营之间围剿｜宣战占领灵脉",
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
	_build_merit_bar(root)
	_build_battle_types(root)
	_build_power_comparison(root)
	_build_team_section(root)
	_build_array_section(root)
	_build_buff_section(root)
	_build_territory_section(root)
	_build_battle_button(root)

func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	var 右侧 := []
	var 机缘label := Label.new()
	机缘label.name = "JiyuanLabel"
	if is_instance_valid(Game):
		var 检查: Dictionary = Game.检查机缘("征伐机缘")
		var VIP等级: int = Game.当前VIP等级()
		机缘label.text = "机缘：%d/%d（仙阶 %d）" % [检查.get("剩余", 0), 检查.get("上限", 0), VIP等级]
	UITheme.apply_aux_font(机缘label)
	机缘label.custom_minimum_size = Vector2(180, 0)
	右侧.append(机缘label)
	parent.add_child(UITheme.建顶栏("宗门战", _on_back_pressed, 右侧))
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
		# ★ 2026-09-16 修（#009 逐页精修 · 宗门战）：Grid 列宽按子项「最小宽」分配，
		#   而 Button 的最小宽不含其子节点 ⇒ 列宽没有任何外部依据，卡片文案一折行整列就塌成
		#   w=24 的竖排条（验收器实拍）。给卡片 EXPAND，让 Grid 把整行宽度均分到各列。
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.clip_text = true
		card.pressed.connect(_on_type_pressed.bind(btype))
		grid.add_child(card)
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.25)

		var vbox := VBoxContainer.new()
		vbox.name = "TypeVBox"
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 4)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(vbox)
		vbox.modulate.a = 0.0
		vbox.create_tween().tween_property(vbox, "modulate:a", 1.0, 0.25)

		var icon := TextureRect.new()
		# ★ 2026-09-16 修（#009 逐页精修 · 宗门战）：原实现四张卡顶部都顶着一个放大的「战」字
		#   （更早是 emoji「◆」，因项目字体不含 emoji 而显示成豆腐块 ⇒ 换成汉字兜底）。
		#   但「战」与卡名末字重复，视觉上等同缺图占位。改用项目既有 emoji 资产（58 张），
		#   四类战事各有专属图形，零新增出图成本，也符合「不许自造图标」的 UI 三连。
		icon.name = "TypeIcon"
		icon.texture = UITheme.emoji_icon_sized(
			String(BATTLE_TYPE_ICON.get(btype, "emoji_activity_battle")), 96)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(0, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(icon)
		icon.modulate.a = 0.0
		icon.create_tween().tween_property(icon, "modulate:a", 1.0, 0.25)

		var name := Label.new()
		name.text = btype
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_body_text(name)
		vbox.add_child(name)
		name.modulate.a = 0.0
		name.create_tween().tween_property(name, "modulate:a", 1.0, 0.25)

		var desc := Label.new()
		desc.text = BATTLE_TYPE_DESC[btype]
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_aux_text(desc)
		vbox.add_child(desc)
		desc.modulate.a = 0.0
		desc.create_tween().tween_property(desc, "modulate:a", 1.0, 0.25)
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
	attacker_label.text = "我方道行"
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
	defender_label.text = "敌方道行"
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
	vbox.add_theme_constant_override("margin_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_bottom", UITheme.PAD_PANEL)
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
		# ★ 2026-09-16 修：① 不给 EXPAND ⇒ HBox 只按「最小宽」排，三个队签挤在左侧一小撮；
		#   ② 不设字体 ⇒ 落到引擎默认 font_size 17（≈11dp）几乎不可读。两处一并收口。
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_project_font(tab, UITheme.FONT_BODY, true)
		UITheme.apply_secondary_button_style(tab)
		if i == 0:
			UITheme.apply_primary_button_style(tab)
		tab.pressed.connect(_on_team_tab_pressed.bind(i))
		team_tabs.add_child(tab)
		tab.modulate.a = 0.0
		tab.create_tween().tween_property(tab, "modulate:a", 1.0, 0.25)

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
		# ★ 2026-09-16 修（真缺陷 · 静默不可见）：与 page_atlas 意图 chip 同一根因 ——
		#   Button 在 clip_text=true 时最小宽度**不含文字宽**，而 GridContainer 列宽只按
		#   子项最小宽、只有子项带 EXPAND 才会被撑开。两者叠加 ⇒ 5 个队员槽位全塌成
		#   24 逻辑宽的竖条，`刷新槽位()` 写入的「前／＋／空位」三行字被整段裁掉，
		#   实机只见 5 个空框（静态闸门 + 布局扫描全绿，只有肉眼能看见）。
		slot.clip_text = false
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_project_font(slot, UITheme.FONT_AUX, true)
		UITheme.apply_secondary_button_style(slot)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(slot)
		slot.modulate.a = 0.0
		slot.create_tween().tween_property(slot, "modulate:a", 1.0, 0.25)

	# 站位说明
	var legend := Label.new()
	legend.text = "前排×2（抗伤）  中排×2（输出）  后排×1（辅助）｜轻触槽位安排弟子"
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
	vbox.add_theme_constant_override("margin_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_bottom", UITheme.PAD_PANEL)
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
	array_level.text = "第 %d 重" % int(Game.阵法等级.get("hushan", 0))
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
	vbox.add_theme_constant_override("margin_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_bottom", UITheme.PAD_PANEL)
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
		# S32 战功道具增益（库存由战功商店兑换而来，开战时后端扣 1）
		{"name": "赤焰战鼓", "effect": "攻击+25%，持续5回合", "cost": "道具×0"},
		{"name": "玄龟护盾", "effect": "防御+25%，持续6回合", "cost": "道具×0"},
		{"name": "九转还魂丹", "effect": "生命+30%，全程生效", "cost": "道具×0"},
	]
	for buff in buffs:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", UITheme.GRID / 2)
		vbox.add_child(item)
		item.modulate.a = 0.0
		item.create_tween().tween_property(item, "modulate:a", 1.0, 0.25)

		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(info)
		info.modulate.a = 0.0
		info.create_tween().tween_property(info, "modulate:a", 1.0, 0.25)

		var name := Label.new()
		name.text = buff["name"]
		name.add_theme_color_override("font_color", Color(1.0, 0.78, 0.39))
		UITheme.apply_body_text(name)
		info.add_child(name)
		name.modulate.a = 0.0
		name.create_tween().tween_property(name, "modulate:a", 1.0, 0.25)

		var effect := Label.new()
		effect.text = buff["effect"]
		UITheme.apply_aux_text(effect)
		info.add_child(effect)
		effect.modulate.a = 0.0
		effect.create_tween().tween_property(effect, "modulate:a", 1.0, 0.25)

		var cost := Label.new()
		cost.text = buff["cost"]
		cost.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		UITheme.apply_aux_text(cost)
		cost.name = "BuffCost_" + str(buff["name"])
		cost.custom_minimum_size = Vector2(80, 0)
		item.add_child(cost)
		cost.modulate.a = 0.0
		cost.create_tween().tween_property(cost, "modulate:a", 1.0, 0.25)

		var toggle := Button.new()
		toggle.name = "Toggle_" + buff["name"]
		toggle.text = "OFF"
		toggle.custom_minimum_size = Vector2(60, UITheme.BTN_H_SECONDARY)
		UITheme.apply_secondary_button_style(toggle)
		toggle.pressed.connect(_on_buff_toggle.bind(buff["name"]))
		item.add_child(toggle)
		toggle.modulate.a = 0.0
		toggle.create_tween().tween_property(toggle, "modulate:a", 1.0, 0.25)

func _build_battle_button(parent: Control) -> void:
	var btn := Button.new()
	btn.name = "StartBattleBtn"
	btn.text = "◆ 开始战斗"
	btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	UITheme.apply_primary_button_style(btn)
	btn.pressed.connect(_on_start_battle)
	parent.add_child(btn)


func _build_territory_section(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "TerritorySection"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_bottom", UITheme.PAD_PANEL)
	panel.add_child(vbox)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(header)
	var title: Label = Label.new()
	title.text = "宗门领地"
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_body_text(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var 月产: Label = Label.new()
	月产.name = "TerritoryYield"
	月产.text = "月产 —"
	UITheme.apply_aux_text(月产)
	header.add_child(月产)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "TerritoryList"
	list.add_theme_constant_override("separation", 2)
	vbox.add_child(list)

func 刷新领地() -> void:
	var list = find_child("TerritoryList", true, false)
	if list == null:
		return
	for c in list.get_children():
		c.queue_free()
	var 领地 = Game.宗门领地 if Game.has_method("宣战") else []
	var 总灵石: int = 0
	var 总声望: int = 0
	for 领 in 领地:
		总灵石 += int(领.get("月灵石", 0))
		总声望 += int(领.get("月声望", 0))
	var 月产标 = find_child("TerritoryYield", true, false)
	if 月产标 != null:
		月产标.text = "月产 灵石+%d 声望+%d（%d处）" % [总灵石, 总声望, 领地.size()]
	if 领地.is_empty():
		var 空: Label = Label.new()
		空.text = "（尚无比邻疆土，宣战可拓土）"
		UITheme.apply_aux_text(空)
		list.add_child(空)
	else:
		for i in range(领地.size()):
			var 领: Dictionary = 领地[i]
			var 行: HBoxContainer = HBoxContainer.new()
			行.add_theme_constant_override("separation", UITheme.GRID / 2)
			list.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
			var info: VBoxContainer = VBoxContainer.new()
			info.add_theme_constant_override("separation", 2)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			行.add_child(info)
			info.modulate.a = 0.0
			info.create_tween().tween_property(info, "modulate:a", 1.0, 0.25)
			var l: Label = Label.new()
			l.text = "· %s（%s） 灵石%d/月 声望%d/月" % [str(领.get("名称", "")), str(领.get("类型", "")), int(领.get("月灵石", 0)), int(领.get("月声望", 0))]
			UITheme.apply_aux_text(l)
			info.add_child(l)
			l.modulate.a = 0.0
			l.create_tween().tween_property(l, "modulate:a", 1.0, 0.25)
			var 守军: Array = 领.get("守军", [])
			var 防守线: int = int(领.get("防守线", 500))
			var 守力: int = 0
			for 名 in 守军:
				for d in Game.弟子列表:
					if d != null and str(d.姓名) == str(名):
						守力 += int(d.总战力())
						break
			var 守标: Label = Label.new()
			if 守军.is_empty():
				守标.text = "无守军 · 周结算 25%% 失守风险（防守线%d）" % 防守线
				守标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_RED)
			else:
				守标.text = "守军 %s ｜ 道行%d/%d" % [", ".join(PackedStringArray(守军)), 守力, 防守线]
				if 守力 >= 防守线:
					守标.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS)
				else:
					守标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_RED)
			UITheme.apply_aux_text(守标)
			info.add_child(守标)
			守标.modulate.a = 0.0
			守标.create_tween().tween_property(守标, "modulate:a", 1.0, 0.25)
			var 驻钮: Button = Button.new()
			驻钮.text = "守备"
			驻钮.custom_minimum_size = Vector2(72, UITheme.BTN_H_SECONDARY)
			UITheme.apply_secondary_button_style(驻钮)
			驻钮.pressed.connect(_show_garrison_panel.bind(i))
			行.add_child(驻钮)
			驻钮.modulate.a = 0.0
			驻钮.create_tween().tween_property(驻钮, "modulate:a", 1.0, 0.25)
func refresh() -> void:
	if not _built:
		return
	刷新槽位()
	刷新类型卡()
	刷新战力对比()
	刷新领地()
	刷新战功条()
	刷新道具库存()
	# P0修复：更新征伐机缘显示
	var 机缘label = get_node_or_null("MarginRoot/VBoxContainer/HeaderBar/HBoxContainer/JiyuanLabel")
	if 机缘label != null and is_instance_valid(Game):
		var 检查: Dictionary = Game.检查机缘("征伐机缘")
		var VIP等级: int = Game.当前VIP等级()
		机缘label.text = "机缘：%d/%d（仙阶 %d）" % [检查.get("剩余", 0), 检查.get("上限", 0), VIP等级]

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
			slot.text = "%s\n＋\n空位" % _槽位名[i]
			UITheme.apply_secondary_button_style(slot)
		else:
			slot.text = "%s\n%s\n道%d" % [_槽位名[i], d.姓名, int(d.总战力())]
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
		if d != null and not 已占用.has(d) and d.受伤剩余 <= 0:
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
			b.text = "%s（%s 道%d）" % [d.姓名, d.境界, int(d.总战力())]
			b.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
			UITheme.apply_secondary_button_style(b)
			b.pressed.connect(func():
				_队伍编制[_当前队伍索引][槽位] = d
				遮.queue_free()
				刷新槽位()
				刷新战力对比()
			)
			内列.add_child(b)
			b.modulate.a = 0.0
			b.create_tween().tween_property(b, "modulate:a", 1.0, 0.25)
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
	撤.text = "返回"
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
	# S32 战功道具库存校验（真实扣除在后端 发起宗门战，此处只做前置提示）
	for 道名 in 战功道具映射:
		if not bool(_buffs.get(道名, false)):
			continue
		var 道id: String = str(战功道具映射[道名])
		if int(Game.战功道具库存.get(道id, 0)) <= 0:
			Game.添加提示("「%s」存量不足，请先在战功商店兑换" % 道名)
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
		Game.添加提示("宗门战尚未开启")
		return
	var 结果: Dictionary = Game.宣战(_当前战斗类型, 出战队伍, _buffs)
	if not bool(结果.get("ok", false)):
		Game.灵石 += 灵石消耗
		Game.添加提示("宗门战未开始：" + str(结果.get("error", "未知原因")))
		return
	战斗开始.emit(_当前战斗类型)
	刷新战功条()
	刷新道具库存()
	刷新领地()

	# P2接入：播放战斗场景动画
	if Game.主UI != null and Game.主UI.has_method("播放战报"):
		# 从出战队伍提取攻方快照（第一队前3名）
		var 攻方快照: Array = []
		if 出战队伍.size() > 0:
			var 第一队: Array = 出战队伍[0]
			for i in range(min(3, 第一队.size())):
				var d = 第一队[i]
				if d != null and d.has_method("get_final_combat_attr"):
					攻方快照.append(d.get_final_combat_attr())
		# 守方快照：从结果中获取，如果没有则用攻方快照模拟
		var 守方快照: Array = 结果.get("守方快照", [])
		if 守方快照.is_empty() and 攻方快照.size() > 0:
			# 简化版：用攻方快照的副本作为守方（后续优化从敌方队伍提取）
			for s in 攻方快照:
				var 副本: Dictionary = s.duplicate(true)
				if 副本.has("名称"):
					副本["名称"] = "敌方" + str(副本["名称"])
				守方快照.append(副本)
		# 计算表演性战斗并播放
		if 攻方快照.size() > 0 and 守方快照.size() > 0:
			var 表演战报: Dictionary
			if 攻方快照.size() == 1 and 守方快照.size() == 1:
				表演战报 = BattleManager.发起1v1(攻方快照[0], 守方快照[0], "full", false)
			else:
				表演战报 = BattleManager.发起3v3(攻方快照, 守方快照, "full", false)
			# 连接战斗结束信号（一次性）
			if Game.主UI._battle_scene != null:
				var 结束信号 = Game.主UI._battle_scene.战斗结束
				Game.主UI.播放战报(表演战报, 攻方快照, 守方快照, _当前战斗类型)
				await 结束信号
			else:
				Game.主UI.播放战报(表演战报, 攻方快照, 守方快照, _当前战斗类型)
				await get_tree().create_timer(2.0).timeout

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
	头.text = "◆ %s：%s" % [str(战报.get("战斗类型", "")), 结果文本]
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
	if 结果.has("占领领地"):
		var 领地信息: Dictionary = 结果["占领领地"]
		var 领地标: Label = Label.new()
		领地标.text = "◇ 占领领地【%s】（%s） 岁入 灵石%d/月" % [str(领地信息.get("名称", "")), str(领地信息.get("类型", "")), int(领地信息.get("月灵石", 0))]
		领地标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		UITheme.apply_body_text(领地标)
		列.add_child(领地标)

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
		行标.modulate.a = 0.0
		行标.create_tween().tween_property(行标, "modulate:a", 1.0, 0.25)

	var 确 := Button.new()
	确.text = "可"
	确.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	UITheme.apply_primary_button_style(确)
	确.pressed.connect(func():
		遮.queue_free()
		refresh()
	)
	列.add_child(确)

# ============ S32 战功状态条 / 战功商店 / 领地守备 ============
func _build_merit_bar(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "MeritBar"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", UITheme.GRID / 2)
	panel.add_child(bar)
	var 功: Label = Label.new()
	功.name = "MeritValue"
	功.text = "战功 0"
	功.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_body_text(功)
	bar.add_child(功)
	var 额: Label = Label.new()
	额.name = "MeritQuota"
	额.text = "本周宣战 —"
	UITheme.apply_aux_text(额)
	额.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(额)
	var 季: Label = Label.new()
	季.name = "MeritSeason"
	季.text = "第1赛季"
	UITheme.apply_aux_text(季)
	bar.add_child(季)
	var 铺: Button = Button.new()
	铺.text = "战功商店"
	铺.custom_minimum_size = Vector2(88, UITheme.BTN_H_SECONDARY)
	UITheme.apply_secondary_button_style(铺)
	铺.pressed.connect(_show_merit_shop)
	bar.add_child(铺)

func 刷新战功条() -> void:
	var 功 = find_child("MeritValue", true, false)
	if 功 != null:
		功.text = "战功 %d" % int(Game.战功)
	var 额 = find_child("MeritQuota", true, false)
	if 额 != null:
		var 配: int = int(Game.获取宣战配额())
		额.text = "本周宣战 %d/%d（现实7日重置）" % [int(Game.宣战周已用), 配]
	var 季 = find_child("MeritSeason", true, false)
	if 季 != null:
		季.text = "第%d赛季 · 本季%d功" % [int(Game.赛季序号), int(Game.赛季累计战功)]

# 增益面板里三件战功道具的 cost 标签实时显示库存数
func 刷新道具库存() -> void:
	for 道名 in 战功道具映射:
		var 标 = find_child("BuffCost_" + str(道名), true, false)
		if 标 == null:
			continue
		var n: int = int(Game.战功道具库存.get(str(战功道具映射[道名]), 0))
		标.text = "道具×%d" % n
		if n <= 0:
			标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_DISABLED)
		else:
			标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)

# 战功商店：config/battle_merit_shop.csv 数据驱动，按类别分组
func _show_merit_shop() -> void:
	var 商品: Array = Game._读战功商店()
	var 遮: ColorRect = ColorRect.new()
	遮.color = Color(0, 0, 0, 0.78)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "战功商店"
	add_child(遮)
	var 外: MarginContainer = MarginContainer.new()
	外.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		外.add_theme_constant_override(k, UITheme.MARGIN)
	遮.add_child(外)
	var 列: VBoxContainer = VBoxContainer.new()
	列.add_theme_constant_override("separation", UITheme.GRID / 2)
	外.add_child(列)
	var 头: Label = Label.new()
	头.name = "ShopHeader"
	头.text = "战功商店 · 现存 %d 战功" % int(Game.战功)
	UITheme.apply_body_text(头)
	头.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	列.add_child(头)
	var 说: Label = Label.new()
	说.text = "战功来自宣战胜负、领地岁贡、周犒赏与赛季名次；丹药入宗门库房，战斗道具入战前增益"
	说.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说)
	列.add_child(说)
	var 滚: ScrollContainer = ScrollContainer.new()
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	列.add_child(滚)
	var 内: VBoxContainer = VBoxContainer.new()
	内.add_theme_constant_override("separation", 4)
	内.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚.add_child(内)
	if 商品.is_empty():
		var 空: Label = Label.new()
		空.text = "（战功商店配置未就绪）"
		UITheme.apply_aux_text(空)
		内.add_child(空)
	for 类 in ["辅助修炼", "辅助突破", "战斗道具", "特殊珍藏"]:
		var 本类: Array = []
		for it in 商品:
			if str(it.get("类别", "")) == 类:
				本类.append(it)
		if 本类.is_empty():
			continue
		var 类标: Label = Label.new()
		类标.text = "【%s】" % 类
		UITheme.apply_body_text(类标)
		类标.add_theme_color_override("font_color", UITheme.获取次文字色())
		内.add_child(类标)
		类标.modulate.a = 0.0
		类标.create_tween().tween_property(类标, "modulate:a", 1.0, 0.25)
		for it in 本类:
			var 行: HBoxContainer = HBoxContainer.new()
			行.add_theme_constant_override("separation", UITheme.GRID / 2)
			内.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
			var 信: VBoxContainer = VBoxContainer.new()
			信.add_theme_constant_override("separation", 2)
			信.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			行.add_child(信)
			信.modulate.a = 0.0
			信.create_tween().tween_property(信, "modulate:a", 1.0, 0.25)
			var 名标: Label = Label.new()
			名标.text = "%s（%s）×%d" % [str(it.get("名称", "")), str(it.get("品阶", "")), int(it.get("数量", 1))]
			UITheme.apply_body_text(名标)
			名标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
			信.add_child(名标)
			名标.modulate.a = 0.0
			名标.create_tween().tween_property(名标, "modulate:a", 1.0, 0.25)
			var 说标: Label = Label.new()
			说标.text = str(it.get("说明", ""))
			说标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UITheme.apply_aux_text(说标)
			信.add_child(说标)
			说标.modulate.a = 0.0
			说标.create_tween().tween_property(说标, "modulate:a", 1.0, 0.25)
			var 买: Button = Button.new()
			买.text = "%d功" % int(it.get("价格", 0))
			买.custom_minimum_size = Vector2(84, UITheme.BTN_H_SECONDARY)
			if int(Game.战功) >= int(it.get("价格", 0)):
				UITheme.apply_primary_button_style(买)
			else:
				UITheme.apply_secondary_button_style(买)
				买.disabled = true
			买.pressed.connect(_on_merit_buy.bind(str(it.get("id", "")), 遮))
			行.add_child(买)
			买.modulate.a = 0.0
			买.create_tween().tween_property(买, "modulate:a", 1.0, 0.25)
	var 关: Button = Button.new()
	关.text = "关闭"
	关.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	UITheme.apply_secondary_button_style(关)
	关.pressed.connect(func(): 遮.queue_free())
	列.add_child(关)

func _on_merit_buy(商品id: String, 遮: Control) -> void:
	var r: Dictionary = Game.兑换战功商品(商品id)
	if not bool(r.get("ok", false)):
		Game.添加提示(str(r.get("error", "兑换未成")))
		return
	Game.添加提示("已兑换 %s×%d" % [str(r.get("名称", "")), int(r.get("数量", 1))])
	刷新战功条()
	刷新道具库存()
	if 遮 != null and is_instance_valid(遮):
		遮.queue_free()
		_show_merit_shop()

# 领地守备：派驻/撤回守军（周结算按守军战力对防守线判失守）
func _show_garrison_panel(领地索引: int) -> void:
	if 领地索引 < 0 or 领地索引 >= Game.宗门领地.size():
		return
	var 领: Dictionary = Game.宗门领地[领地索引]
	var 守军: Array = 领.get("守军", [])
	var 遮: ColorRect = ColorRect.new()
	遮.color = Color(0, 0, 0, 0.78)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "领地守备"
	add_child(遮)
	var 外: MarginContainer = MarginContainer.new()
	外.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		外.add_theme_constant_override(k, UITheme.MARGIN)
	遮.add_child(外)
	var 列: VBoxContainer = VBoxContainer.new()
	列.add_theme_constant_override("separation", UITheme.GRID / 2)
	外.add_child(列)
	var 头: Label = Label.new()
	头.text = "【%s】守备（防守线 %d，上限 %d 人）" % [str(领.get("名称", "")), int(领.get("防守线", 500)), int(Game.守军上限)]
	UITheme.apply_body_text(头)
	头.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	列.add_child(头)
	var 滚: ScrollContainer = ScrollContainer.new()
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	列.add_child(滚)
	var 内: VBoxContainer = VBoxContainer.new()
	内.add_theme_constant_override("separation", 4)
	内.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚.add_child(内)
	var 现标: Label = Label.new()
	现标.text = "现驻守军" if 守军.size() > 0 else "现无守军（周结算 25% 失守风险）"
	UITheme.apply_aux_text(现标)
	内.add_child(现标)
	for 名 in 守军:
		var 撤: Button = Button.new()
		撤.text = "撤回 %s" % str(名)
		撤.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
		UITheme.apply_secondary_button_style(撤)
		撤.pressed.connect(_on_garrison_remove.bind(领地索引, str(名), 遮))
		内.add_child(撤)
		撤.modulate.a = 0.0
		撤.create_tween().tween_property(撤, "modulate:a", 1.0, 0.25)
	var 可标: Label = Label.new()
	可标.text = "可派驻弟子（养伤者不可派）"
	UITheme.apply_aux_text(可标)
	内.add_child(可标)
	var 已驻: Array = []
	for 地 in Game.宗门领地:
		for 名 in (地.get("守军", []) as Array):
			已驻.append(str(名))
	var 可选: Array = []
	for d in Game.弟子列表:
		if d == null:
			continue
		if int(d.受伤剩余) > 0:
			continue
		if str(d.姓名) in 已驻:
			continue
		可选.append(d)
	可选.sort_custom(func(a, b): return int(a.总战力()) > int(b.总战力()))
	if 可选.is_empty():
		var 空: Label = Label.new()
		空.text = "（无可派驻弟子）"
		UITheme.apply_aux_text(空)
		内.add_child(空)
	for d in 可选:
		var b: Button = Button.new()
		b.text = "派驻 %s（%s 道%d）" % [str(d.姓名), str(d.境界), int(d.总战力())]
		b.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
		UITheme.apply_secondary_button_style(b)
		b.pressed.connect(_on_garrison_add.bind(领地索引, d, 遮))
		内.add_child(b)
		b.modulate.a = 0.0
		b.create_tween().tween_property(b, "modulate:a", 1.0, 0.25)
	var 关: Button = Button.new()
	关.text = "关闭"
	关.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	UITheme.apply_secondary_button_style(关)
	关.pressed.connect(func(): 遮.queue_free())
	列.add_child(关)

func _on_garrison_add(领地索引: int, d: Object, 遮: Control) -> void:
	var r: Dictionary = Game.派驻守军(领地索引, d)
	if not bool(r.get("ok", false)):
		Game.添加提示(str(r.get("error", "派驻未成")))
		return
	刷新领地()
	if 遮 != null and is_instance_valid(遮):
		遮.queue_free()
		_show_garrison_panel(领地索引)

func _on_garrison_remove(领地索引: int, 姓名: String, 遮: Control) -> void:
	var r: Dictionary = Game.撤回守军(领地索引, 姓名)
	if not bool(r.get("ok", false)):
		Game.添加提示(str(r.get("error", "撤回未成")))
		return
	刷新领地()
	if 遮 != null and is_instance_valid(遮):
		遮.queue_free()
		_show_garrison_panel(领地索引)

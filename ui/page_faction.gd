extends Control

# 阵营声望页（GameUI 二级页）：展示五大阵营声望等级、进度、权益
# 全部字体走 UITheme 角色 helper，讯息从 Game.阵营声望 读取
signal 返回主页

var _built: bool = false
var _scroll_vbox: VBoxContainer
var _faction_cards: Dictionary = {}

const FACTION_LIST: Array = ["正道宗门", "魔道邪宗", "中立散修", "上古妖兽", "远古遗泽"]
const FACTION_SHORT: Dictionary = {
	"正道宗门": "正道", "魔道邪宗": "魔道", "中立散修": "散修",
	"上古妖兽": "妖兽", "远古遗泽": "遗泽"
}
const FACTION_COLOR: Dictionary = {
	"正道宗门": Color(0.29, 0.62, 1.0),
	"魔道邪宗": Color(1.0, 0.29, 0.29),
	"中立散修": Color(0.6, 0.6, 0.6),
	"上古妖兽": Color(0.29, 1.0, 0.48),
	"远古遗泽": Color(1.0, 0.84, 0.0),
}
const REPUTATION_LEVELS: Array = ["冷淡", "中立", "友善", "尊敬", "崇敬"]
const REPUTATION_THRESHOLDS: Array = [0, 100, 500, 2000, 5000]

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

	var root := VBoxContainer.new()
	root.name = "RootVBox"
	root.add_theme_constant_override("separation", UITheme.GRID)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	_build_header(root)
	_build_scroll(root)
	_build_comprehensive(root)

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
	title.text = "阵营声望"
	UITheme.apply_title_font(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(UITheme.BACK_BTN_SIZE, 0)
	bar.add_child(spacer)

func _build_scroll(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "FactionScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	_scroll_vbox = VBoxContainer.new()
	_scroll_vbox.name = "FactionVBox"
	_scroll_vbox.add_theme_constant_override("separation", UITheme.GRID)
	_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_scroll_vbox)

	for faction in FACTION_LIST:
		var card = _build_faction_card(faction)
		_scroll_vbox.add_child(card)
		_faction_cards[faction] = card

func _build_faction_card(faction: String) -> Control:
	var card := PanelContainer.new()
	card.name = "Card_" + faction
	card.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("offset_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_bottom", UITheme.PAD_PANEL)
	card.add_child(vbox)

	# 阵营名称 + 等级
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(header)

	var name_label := Label.new()
	name_label.name = "FactionName"
	name_label.text = faction
	name_label.add_theme_color_override("font_color", FACTION_COLOR[faction])
	UITheme.apply_body_text(name_label)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "冷淡"
	UITheme.apply_aux_text(level_label)
	header.add_child(level_label)

	# 声望进度条
	var progress_panel := PanelContainer.new()
	progress_panel.custom_minimum_size = Vector2(0, 16)
	progress_panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(true))
	vbox.add_child(progress_panel)

	var progress_bar := ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.show_percentage = false
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_panel.add_child(progress_bar)

	# 声望数值
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "0 / 100"
	UITheme.apply_aux_text(value_label)
	vbox.add_child(value_label)

	# 权益标签
	var benefits_label := Label.new()
	benefits_label.name = "BenefitsLabel"
	benefits_label.text = "权益：基础商品"
	UITheme.apply_aux_text(benefits_label)
	benefits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(benefits_label)

	return card

func _build_comprehensive(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "ComprehensivePanel"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("offset_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("offset_bottom", UITheme.PAD_PANEL)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "综合阵营权益"
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_body_text(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UITheme.GRID)
	grid.add_theme_constant_override("v_separation", UITheme.GRID / 2)
	vbox.add_child(grid)

	var items: Array = [
		{"label": "最高商店折扣", "key": "discount"},
		{"label": "最高任务加成", "key": "bonus"},
		{"label": "解锁特殊商品", "key": "special"},
		{"label": "解锁专属任务", "key": "exclusive"},
	]
	for item in items:
		var item_panel := PanelContainer.new()
		item_panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(true))
		grid.add_child(item_panel)

		var item_vbox := VBoxContainer.new()
		item_vbox.add_theme_constant_override("separation", 4)
		item_vbox.add_theme_constant_override("offset_left", 12)
		item_vbox.add_theme_constant_override("offset_right", 12)
		item_vbox.add_theme_constant_override("offset_top", 8)
		item_vbox.add_theme_constant_override("offset_bottom", 8)
		item_panel.add_child(item_vbox)

		var label := Label.new()
		label.text = item["label"]
		UITheme.apply_aux_text(label)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_vbox.add_child(label)

		var value := Label.new()
		value.name = "Value_" + item["key"]
		value.text = "-"
		UITheme.apply_body_text(value)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_vbox.add_child(value)

func refresh() -> void:
	if not _built:
		return
	# 更新每个阵营卡片
	for faction in FACTION_LIST:
		var card = _faction_cards.get(faction, null)
		if card == null:
			continue
		var rep_value: int = int(Game.阵营声望.get(faction, 0))
		var level_idx: int = _get_level_index(rep_value)
		var level_name: String = REPUTATION_LEVELS[level_idx]
		var next_threshold: int = REPUTATION_THRESHOLDS[min(level_idx + 1, REPUTATION_THRESHOLDS.size() - 1)]
		var current_threshold: int = REPUTATION_THRESHOLDS[level_idx]
		var progress: float = 0.0
		if next_threshold > current_threshold:
			progress = float(rep_value - current_threshold) / float(next_threshold - current_threshold) * 100.0
		# 更新UI
		var level_label = card.find_child("LevelLabel", true, false)
		if level_label != null:
			level_label.text = level_name
		var progress_bar = card.find_child("ProgressBar", true, false)
		if progress_bar != null:
			progress_bar.value = progress
		var value_label = card.find_child("ValueLabel", true, false)
		if value_label != null:
			if level_idx >= REPUTATION_LEVELS.size() - 1:
				value_label.text = "%d (已满级)" % rep_value
			else:
				value_label.text = "%d / %d（距%s：%d）" % [rep_value, next_threshold, REPUTATION_LEVELS[level_idx + 1], next_threshold - rep_value]
		var benefits_label = card.find_child("BenefitsLabel", true, false)
		if benefits_label != null:
			benefits_label.text = _get_benefits_text(faction, level_idx)
	# 更新综合权益
	_update_comprehensive()

func _get_level_index(rep_value: int) -> int:
	for i in range(REPUTATION_THRESHOLDS.size()):
		if rep_value < REPUTATION_THRESHOLDS[i]:
			return max(0, i - 1)
	return REPUTATION_LEVELS.size() - 1

func _get_benefits_text(faction: String, level_idx: int) -> String:
	var benefits: Array = []
	match faction:
		"正道宗门":
			if level_idx >= 2: benefits.append("商店95折")
			if level_idx >= 3: benefits.append("正道高阶功法")
			if level_idx >= 4: benefits.append("正道专属皮肤")
		"魔道邪宗":
			if level_idx >= 2: benefits.append("魔道任务")
			if level_idx >= 3: benefits.append("黑市交易")
			if level_idx >= 4: benefits.append("魔道专属皮肤")
		"中立散修":
			if level_idx >= 2: benefits.append("散修任务")
			if level_idx >= 3: benefits.append("竞猜玩法")
			if level_idx >= 4: benefits.append("散修专属皮肤")
		"上古妖兽":
			if level_idx >= 2: benefits.append("高阶灵兽契约")
			if level_idx >= 3: benefits.append("灵兽繁育")
			if level_idx >= 4: benefits.append("上古灵兽契约")
		"远古遗泽":
			if level_idx >= 2: benefits.append("圣品突破素材")
			if level_idx >= 3: benefits.append("道品锻造素材")
			if level_idx >= 4: benefits.append("远古传承")
	if benefits.is_empty():
		return "权益：基础商品"
	return "权益：" + "、".join(benefits)

func _update_comprehensive() -> void:
	var best_discount: float = 1.0
	var best_bonus: float = 1.0
	var has_special: bool = false
	var has_exclusive: bool = false
	for faction in FACTION_LIST:
		var rep_value: int = int(Game.阵营声望.get(faction, 0))
		var level_idx: int = _get_level_index(rep_value)
		if level_idx >= 2: best_discount = min(best_discount, 0.95)
		if level_idx >= 3: best_discount = min(best_discount, 0.90)
		if level_idx >= 4: best_discount = min(best_discount, 0.85)
		if level_idx >= 2: best_bonus = max(best_bonus, 1.05)
		if level_idx >= 3: best_bonus = max(best_bonus, 1.10)
		if level_idx >= 4: best_bonus = max(best_bonus, 1.15)
		if level_idx >= 3: has_special = true
		if level_idx >= 4: has_exclusive = true
	# 更新UI
	var root = find_child("ComprehensivePanel", true, false)
	if root != null:
		var discount_val = root.find_child("Value_discount", true, false)
		if discount_val != null: discount_val.text = "%d折" % int(best_discount * 100)
		var bonus_val = root.find_child("Value_bonus", true, false)
		if bonus_val != null: bonus_val.text = "+%d%%" % int((best_bonus - 1.0) * 100)
		var special_val = root.find_child("Value_special", true, false)
		if special_val != null: special_val.text = "✅" if has_special else "❌"
		var exclusive_val = root.find_child("Value_exclusive", true, false)
		if exclusive_val != null: exclusive_val.text = "✅" if has_exclusive else "❌"

func _on_back_pressed() -> void:
	返回主页.emit()

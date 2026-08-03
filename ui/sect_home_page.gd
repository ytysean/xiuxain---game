extends Control

# 宗门主权展示页（首页 = 一级页「宗门」），方案 B 中度模块化重构：
#   - 6 网格入口（殿阁/弟子/灵植/秘境/库藏/纪事），纯 UI 别名路由（见 game_ui.gd ENTRY_ALIAS）
#   - Hero 块「宗门进境」信息锚点：宗门等级 / 繁荣度 / 核心收益速率（灵气/m · 灵草/m）
#   - 左上角轻量 logo「太玄宗门录」；宗门动态卡（弟子数量/声望）+ 历练事件卡（秘境/赏赐）
# 红线条：仅展示 + 入口；所有数据只读 Game Autoload，绝不写 GameState / 玩法 / 战斗逻辑。

const OVERLAY_COLOR: Color = Color(0.086, 0.133, 0.114, 0.50)   # 背景叠层 #16221D@0.50

# 资源空值暗金（比正常数值 COLOR_TEXT_TITLE1 低一视觉层级）
const COLOR_EMPTY: Color = Color(0.75, 0.63, 0.42)

# 6 网格入口（顺序即 3×2 排布；高频→中频：殿阁/弟子/灵植 | 秘境/库藏/纪事）
const ENTRIES: Array[String] = ["殿阁", "弟子", "灵植", "秘境", "库藏", "纪事"]

# 宗门动态卡（繁荣度已并入 Hero；保留 弟子数量 + 声望）
const DYNAMICS_ROWS: Array[String] = ["弟子数量", "声望"]

# Hero 块三指标（只读 Game；label=显示名，value=Value 节点名）
const HERO_FIELDS: Array = [
	{"label": "宗门等级", "value": "Value_宗门等级"},
	{"label": "繁荣度", "value": "Value_繁荣度_Hero"},
	{"label": "收益速率", "value": "Value_收益速率"},
]

# 子面板（修炼收益已并入 Hero；历练事件保留）
const SUB_PANELS: Array = [
	{
		"name": "历练事件",
		"rows": [
			{"label": "秘境", "text": "—"},
			{"label": "赏赐", "text": "—"},
		],
	},
]

# 入口被点击（entry_id ∈ ENTRIES）。信号上行，由 GameUI 别名路由决定跳转，本页零导航逻辑。
signal entry_selected(entry_id: String)

var _hero_values: Dictionary = {}
var _panel_values: Dictionary = {}
var _sub_values: Dictionary = {}

func _ready() -> void:
	_apply_theme()
	_bind_values()
	refresh()

func _apply_theme() -> void:
	var overlay: ColorRect = get_node_or_null("Overlay")
	if overlay != null:
		overlay.color = OVERLAY_COLOR

	# 6 网格入口：TextureButton + 图标（正方形等比缩放）；图标下方显示入口名 Label
	for name in ENTRIES:
		var btn: TextureButton = get_node_or_null("EntryGrid/Entry_" + name)
		if btn != null:
			_style_entry_button(btn, name)
		var lbl: Label = get_node_or_null("EntryGrid/Entry_" + name + "/Label_" + name)
		if lbl != null:
			UITheme.apply_title_font_sized(lbl, 16)
			lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Hero 块「宗门进境」
	var hero: Control = get_node_or_null("HeroBlock")
	if hero != null:
		var hero_bg: Panel = hero.get_node_or_null("BG")
		if hero_bg != null:
			UITheme.apply_dynamics_panel_style(hero_bg, 0.85)
		var hero_title: Label = hero.get_node_or_null("Title")
		if hero_title != null:
			UITheme.apply_title_font_sized(hero_title, 18)
			hero_title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)
		var hero_div: ColorRect = hero.get_node_or_null("Divider")
		if hero_div != null:
			hero_div.color = Color(UITheme.COLOR_BORDER_GOLD, 0.5)
		for f in HERO_FIELDS:
			var hl: Label = hero.get_node_or_null("Label_" + f["label"])
			if hl != null:
				UITheme.apply_body_font_sized(hl, 16)
				hl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
			var hv: Label = hero.get_node_or_null(f["value"])
			if hv != null:
				UITheme.apply_value_font(hv, false)
				hv.add_theme_font_size_override("font_size", 18)
				hv.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)

	# 宗门动态卡（弟子数量/声望）
	var panel: Control = get_node_or_null("DynamicsPanel")
	if panel != null:
		var panel_bg: Panel = panel.get_node_or_null("BG")
		if panel_bg != null:
			UITheme.apply_dynamics_panel_style(panel_bg, 0.88)
		var title: Label = panel.get_node_or_null("Title")
		if title != null:
			UITheme.apply_title_font_sized(title, 16)
			title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)
		var divider: ColorRect = panel.get_node_or_null("Divider")
		if divider != null:
			divider.color = Color(UITheme.COLOR_BORDER_GOLD, 0.5)
		for label_text in DYNAMICS_ROWS:
			var lbl: Label = panel.get_node_or_null("Label_" + label_text)
			if lbl != null:
				UITheme.apply_body_font_sized(lbl, 14)
				lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
			var val: Label = panel.get_node_or_null("Value_" + label_text)
			if val != null:
				UITheme.apply_value_font(val, false)
				val.add_theme_font_size_override("font_size", 15)
				val.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)

	# 子面板（历练事件）
	for cfg in SUB_PANELS:
		var sub: Control = get_node_or_null("Panel_" + cfg["name"])
		if sub == null:
			continue
		var sub_bg: Panel = sub.get_node_or_null("BG")
		if sub_bg != null:
			UITheme.apply_dynamics_panel_style(sub_bg, 0.88)
		var title: Label = sub.get_node_or_null("Title")
		if title != null:
			UITheme.apply_title_font_sized(title, 16)
			title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)
		var divider: ColorRect = sub.get_node_or_null("Divider")
		if divider != null:
			divider.color = Color(UITheme.COLOR_BORDER_GOLD, 0.5)
		for row in cfg["rows"]:
			var lbl: Label = sub.get_node_or_null("Label_" + row["label"])
			if lbl != null:
				UITheme.apply_body_font_sized(lbl, 14)
				lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
			var val: Label = sub.get_node_or_null("Value_" + row["label"])
			if val != null:
				UITheme.apply_value_font(val, false)
				val.add_theme_font_size_override("font_size", 15)
				val.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)

	# 左上角 logo「太玄宗门录」（轻量书法感，左对齐，视觉权重低于资源数值）
	var logo: Label = get_node_or_null("LogoLabel")
	if logo != null:
		UITheme.apply_title_font_sized(logo, 16)
		logo.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)

func _style_entry_button(btn: TextureButton, entry_id: String) -> void:
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	if not btn.pressed.is_connected(_on_entry_pressed.bind(entry_id)):
		btn.pressed.connect(_on_entry_pressed.bind(entry_id))
	if not btn.button_down.is_connected(_on_entry_button_down.bind(btn)):
		btn.button_down.connect(_on_entry_button_down.bind(btn))
	if not btn.button_up.is_connected(_on_entry_button_up.bind(btn)):
		btn.button_up.connect(_on_entry_button_up.bind(btn))

func _on_entry_button_down(btn: TextureButton) -> void:
	btn.modulate = Color(0.85, 0.85, 0.85, 1.0)

func _on_entry_button_up(btn: TextureButton) -> void:
	btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_entry_pressed(entry_id: String) -> void:
	entry_selected.emit(entry_id)

func _bind_values() -> void:
	var hero: Control = get_node_or_null("HeroBlock")
	if hero != null:
		for f in HERO_FIELDS:
			var val: Label = hero.get_node_or_null(f["value"])
			if val != null:
				_hero_values[f["label"]] = val
	var panel: Control = get_node_or_null("DynamicsPanel")
	if panel != null:
		for label_text in DYNAMICS_ROWS:
			var val: Label = panel.get_node_or_null("Value_" + label_text)
			if val != null:
				_panel_values[label_text] = val
	for cfg in SUB_PANELS:
		var sub: Control = get_node_or_null("Panel_" + cfg["name"])
		if sub == null:
			continue
		for row in cfg["rows"]:
			var val: Label = sub.get_node_or_null("Value_" + row["label"])
			if val != null:
				_sub_values[cfg["name"] + "/" + row["label"]] = val

# 只读刷新（由 game_ui._refresh_all_pages 调用；推演 / 新游戏 / 读档后统一重拉，零玩法/战斗触碰）。
func refresh() -> void:
	if not is_instance_valid(Game):
		return

	# Hero 块
	# 宗门等级：优先 Game.宗门等级；当前 Game 以 门派等级 承载宗门等级语义，取其值兜底
	var 等级: Variant = Game.get("宗门等级")
	if 等级 == null:
		等级 = Game.get("门派等级")
	var 等级文本: String = "—"
	if 等级 != null:
		等级文本 = str(int(等级))
	_set_hero("宗门等级", 等级文本)

	var 繁荣: Variant = Game.get("繁荣")
	var 繁荣文本: String = "—"
	if 繁荣 != null:
		繁荣文本 = str(int(繁荣))
	_set_hero("繁荣度", 繁荣文本)

	var 灵气: int = 0
	var 灵草: int = 0
	var r灵气: Variant = Game.get("灵气")
	var r灵草: Variant = Game.get("灵草")
	if r灵气 != null:
		灵气 = int(r灵气)
	if r灵草 != null:
		灵草 = int(r灵草)
	_set_hero("收益速率", "灵气 %s/m · 灵草 %s/m" % [UITheme.format_resource(灵气), UITheme.format_resource(灵草)])

	# 宗门动态卡
	for label_text in DYNAMICS_ROWS:
		var text: String = "—"
		match label_text:
			"弟子数量":
				var raw: Variant = Game.get("弟子列表")
				var count: int = 0
				if raw is Array:
					count = raw.size()
				text = str(count)
			"声望":
				var raw: Variant = Game.get("声望")
				if raw != null:
					text = UITheme.format_resource(int(raw))
		_set_panel(label_text, text)

	# 子面板
	for cfg in SUB_PANELS:
		for row in cfg["rows"]:
			var text: String = "—"
			if row.has("text"):
				text = row["text"]
			_set_sub(cfg["name"], row["label"], text)

func _set_hero(label: String, text: String) -> void:
	var lbl: Label = _hero_values.get(label, null)
	if lbl == null:
		return
	lbl.text = text
	_apply_value_color(lbl, text)

func _set_panel(label: String, text: String) -> void:
	var lbl: Label = _panel_values.get(label, null)
	if lbl == null:
		return
	lbl.text = text
	_apply_value_color(lbl, text)

func _set_sub(panel: String, label: String, text: String) -> void:
	var lbl: Label = _sub_values.get(panel + "/" + label, null)
	if lbl == null:
		return
	lbl.text = text
	_apply_value_color(lbl, text)

# 资源空值统一暗金配色；正常数值用 COLOR_TEXT_TITLE1
func _apply_value_color(lbl: Label, text: String) -> void:
	if text == "—":
		lbl.add_theme_color_override("font_color", COLOR_EMPTY)
	else:
		lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)

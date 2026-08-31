extends Control

# 宗规（GameUI 二级页）：门规严格度 / 正邪路线 / 辈分字派 / 宗门戒律 条文展示。
# 严格度 / 字派 / 正邪路线读取 Game 数据（空桩时回退样例）；纯展示，零数据层写入。

signal 返回主页

var _built: bool = false
var _状态标签: Label

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
	inner.add_child(_建选择卡("CardStrict", "门规严格度",
		["宽松", "中庸", "严苛"], _严格度(), _严格度说明(_严格度())))
	inner.add_child(_建选择卡("CardAlign", "正邪路线",
		["玄门正道", "逍遥中立", "九幽邪道"], _正邪当前(), _正邪说明(_正邪当前())))
	inner.add_child(_建卡("CardZi", "辈分字派", [
		_字派(),
		"新入门弟子依字派排辈，掌门一脉承「玄」字，下衍道、真诸辈。",
		"（字派序列由系统依礼制自动生成，掌门不可手改）",
	], 132))
	inner.add_child(_建卡("CardJie", "宗门戒律", [
		"一、不得残害同门，违者革出师门",
		"二、不得擅自习邪修功法",
		"三、外敌来犯，同门须并力御之",
		"规制由掌门修订，影响弟子行为与宗门声望。",
	], 150))

func _build_header(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.name = "HeaderBar"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	var back: Button = UITheme.make_back_button(_on_back_pressed)
	bar.add_child(back)
	var title := Label.new()
	title.name = "Title"
	title.text = "宗规  ⓘ"
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			UIHint.show_hint(title, "宗规", "宗门门规戒律。\n违反宗规的弟子将受到相应处罚，严重者可被驱逐师门。"))
	UITheme.apply_page_title(title)
	bar.add_child(title)
	_状态标签 = Label.new()
	_状态标签.name = "Status"
	UITheme.apply_value_text(_状态标签)
	bar.add_child(_状态标签)
	parent.add_child(bar)

func _建卡(卡名: String, 标题: String, 行: Array, 高: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = 卡名
	card.custom_minimum_size = Vector2(0, 高)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.050, 0.110, 0.140)
	sb.border_color = Color(0.170, 0.290, 0.340)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("margin_left", 12)
	col.add_theme_constant_override("margin_right", 12)
	col.add_theme_constant_override("margin_top", 12)
	col.add_theme_constant_override("margin_bottom", 12)
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var t := Label.new()
	t.text = 标题
	UITheme.apply_section_title(t)
	col.add_child(t)
	for line in 行:
		var l := Label.new()
		l.text = str(line)
		UITheme.apply_aux_text(l)
		l.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		col.add_child(l)
	return card

func _严格度() -> String:
	if is_instance_valid(Game) and Game.has_method("get"):
		var v = Game.get("门规严格度")
		if v != null:
			return str(v)
	return "中庸"

func _正邪() -> String:
	if is_instance_valid(Game) and Game.has_method("get"):
		var v = Game.get("正邪路线")
		if v != null and str(v) != "":
			return str(v)
	return "正道 · 太玄一脉"

func _字派() -> String:
	if is_instance_valid(Game) and Game.has_method("get"):
		var v = Game.get("辈分字派")
		if v != null:
			var s: String = str(v)
			if s != "" and s != "0":
				return s
	return "玄 → 道 → 真 → 虚 → 静 → 明"

# ───────── 门规编辑（写回 Game，持久化）─────────
func _正邪当前() -> String:
	if is_instance_valid(Game) and Game.has_method("get"):
		var v = Game.get("正邪路线")
		if v != null:
			return str(v)
	return ""

func _严格度说明(v: String) -> String:
	match v:
		"宽松": return "宽松：弟子心性散漫，战力成长 -5%，叛门率 -10%，声望获取 -10%。"
		"严苛": return "严苛：弟子战力成长 +15%，叛门率 +8%，声望获取 +20%。"
		_: return "中庸：收支平衡，宗门稳步前行（默认）。"

func _正邪说明(v: String) -> String:
	match v:
		"玄门正道": return "持正守心：正道弟子心魔抗性强，邪修功法不可习，叛门代价更高。"
		"逍遥中立": return "逍遥中立：功法兼修，行事无拘，声望涨落平缓。"
		"九幽邪道": return "九幽邪道：邪修功法可习，战力暴涨但心魔缠身、正道排斥。"
		_: return "未定路线：掌门可于此处抉择宗门正邪归属。"

func _建选择卡(卡名: String, 标题: String, 选项: Array, 当前: String, 说明: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = 卡名
	card.custom_minimum_size = Vector2(0, 132)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.050, 0.110, 0.140)
	sb.border_color = Color(0.170, 0.290, 0.340)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("margin_left", 12)
	col.add_theme_constant_override("margin_right", 12)
	col.add_theme_constant_override("margin_top", 12)
	col.add_theme_constant_override("margin_bottom", 12)
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var t := Label.new()
	t.text = 标题
	UITheme.apply_section_title(t)
	col.add_child(t)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = 说明
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(hint)
	hint.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	hint.custom_minimum_size = Vector2(0, 40)
	col.add_child(hint)
	var row := HBoxContainer.new()
	row.name = "Opts"
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for opt in 选项:
		var b := Button.new()
		b.name = "Opt_" + str(opt)
		b.flat = true
		b.text = str(opt)
		b.custom_minimum_size = Vector2(110, 32)
		b.pressed.connect(_on_选择.bind(卡名, str(opt)))
		row.add_child(b)
	_刷新选择卡(card, 当前)
	return card

func _built_card(卡名: String) -> PanelContainer:
	var inner: Node = get_node_or_null("Root/Scroll/Inner")
	if inner == null:
		return null
	return inner.get_node_or_null(卡名) as PanelContainer

func _刷新选择卡(card: PanelContainer, 当前: String) -> void:
	var row: Node = card.get_node_or_null("Opts")
	if row == null:
		return
	for child in row.get_children():
		if child is Button:
			_style_选择(child, child.text == 当前)
	var hint: Label = card.get_node_or_null("Hint")
	if hint != null:
		if 当前 == _严格度():
			hint.text = _严格度说明(当前)
		elif 当前 == _正邪当前():
			hint.text = _正邪说明(当前)

func _style_选择(b: Button, sel: bool) -> void:
	b.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD if sel else UITheme.C01_TEXT_SECONDARY)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.910, 0.773, 0.447, 0.18) if sel else Color(0.055, 0.114, 0.141)
	sb.border_color = UITheme.C01_TEXT_GOLD if sel else Color(0.170, 0.290, 0.340)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	UITheme.apply_body_font_sized(b, UITheme.FONT_BODY)

func _on_选择(卡名: String, 值: String) -> void:
	match 卡名:
		"CardStrict": _写严格度(值)
		"CardAlign": _写正邪(值)
	var card: PanelContainer = _built_card(卡名)
	if card != null:
		_刷新选择卡(card, 值)

func _写严格度(v: String) -> void:
	if is_instance_valid(Game):
		Game.门规严格度 = v
		_save()
	if _状态标签 != null:
		_状态标签.text = "当前：" + _严格度()

func _写正邪(v: String) -> void:
	if is_instance_valid(Game):
		Game.正邪路线 = v
		_save()

func _save() -> void:
	if is_instance_valid(Game) and Game.has_method("save_game"):
		Game.save_game()

func refresh() -> void:
	if not _built:
		_build()
	if _状态标签 != null:
		_状态标签.text = "当前：" + _严格度()

func _on_back_pressed() -> void:
	返回主页.emit()

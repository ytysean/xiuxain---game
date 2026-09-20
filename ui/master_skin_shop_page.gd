extends Control

# 宗主皮肤商店页（仙衣阁·宗主）：宗主立绘皮肤购买/装备/预览
signal 返回主页

var _built: bool = false
var _当前分类: String = "全部"
var _当前性别: String = "男"  # 性别筛选：男/女
var _scroll_vbox: VBoxContainer
var _仙玉标签: Label
var _状态标签: Label
var _tab_buttons: Dictionary = {}
var _性别按钮: Dictionary = {}  # 性别按钮组
var _皮肤卡片字典: Dictionary = {}
var _详情弹窗: PanelContainer
var _详情立绘: TextureRect
var _详情描述: Label
var _详情特效: VBoxContainer
var _详情购买按钮: Button
var _当前查看皮肤: String = ""

const 分类列表: Array = ["全部", "宝品", "仙品", "神品"]
const 品级颜色: Dictionary = {
	"宝品": Color(0.79, 0.64, 0.36),
	"仙品": Color(0.61, 0.42, 0.78),
	"神品": Color(0.91, 0.66, 0.22)
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

	var root := VBoxContainer.new()
	root.name = "RootVBox"
	root.add_theme_constant_override("separation", UITheme.GRID)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	_build_header(root)
	_build_tabs(root)
	_build_skin_grid(root)
	_build_detail_popup(root)

	_状态标签 = Label.new()
	_状态标签.name = "StatusLabel"
	_状态标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_状态标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_aux_text(_状态标签)
	_状态标签.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	root.add_child(_状态标签)

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
	title.name = "Title"
	title.text = "宗主仙衣阁"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.apply_page_title(title)
	bar.add_child(title)

	_仙玉标签 = Label.new()
	_仙玉标签.name = "XianyuValue"
	_仙玉标签.text = "0"
	UITheme.apply_body_text(_仙玉标签)
	bar.add_child(_仙玉标签)

func _build_tabs(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "TabScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, UITheme.SIZE_MD + 8)
	parent.add_child(scroll)

	var hbox := HBoxContainer.new()
	hbox.name = "TabHBox"
	hbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	scroll.add_child(hbox)

	for 分类 in 分类列表:
		var btn := Button.new()
		btn.name = "Tab_" + 分类
		btn.text = 分类
		btn.flat = true
		btn.custom_minimum_size = Vector2(120, UITheme.SIZE_MD)
		btn.pressed.connect(_on_tab_pressed.bind(分类))
		_tab_buttons[分类] = btn
		hbox.add_child(btn)
	# 性别切换按钮（男宗主/女宗主）
	var 分隔 := Label.new()
	分隔.text = "|"
	分隔.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	hbox.add_child(分隔)
	for 性别 in ["男", "女"]:
		var 性别btn := Button.new()
		性别btn.name = "Gender_" + 性别
		性别btn.text = 性别 + "宗主"
		性别btn.flat = true
		性别btn.custom_minimum_size = Vector2(100, UITheme.SIZE_MD)
		性别btn.pressed.connect(_on_gender_pressed.bind(性别))
		_性别按钮[性别] = 性别btn
		hbox.add_child(性别btn)
	_update_tab_styles()
	_update_gender_styles()

func _update_tab_styles() -> void:
	for 分类 in _tab_buttons.keys():
		var btn: Button = _tab_buttons[分类]
		var sel: bool = (分类 == _当前分类)
		if sel:
			UITheme.apply_title_font_sized(btn, UITheme.FONT_BODY)
			btn.add_theme_color_override("font_color", UITheme.color_text_title1())
		else:
			UITheme.apply_body_font(btn)
			btn.add_theme_color_override("font_color", UITheme.color_text_body_dim())

func _update_gender_styles() -> void:
	for 性别 in _性别按钮.keys():
		var btn: Button = _性别按钮[性别]
		var sel: bool = (性别 == _当前性别)
		if sel:
			btn.flat = false
			UITheme.apply_title_font_sized(btn, UITheme.FONT_BODY)
			btn.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.85, 0.7, 0.4)
			style.set_corner_radius_all(6)
			style.set_border_width_all(1)
			style.border_color = Color(0.95, 0.85, 0.6)
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover", style)
			btn.add_theme_stylebox_override("pressed", style)
		else:
			btn.flat = true
			UITheme.apply_body_font(btn)
			btn.add_theme_color_override("font_color", UITheme.color_text_body_dim())
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")
			btn.remove_theme_stylebox_override("pressed")

func _build_skin_grid(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "SkinScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	_scroll_vbox = VBoxContainer.new()
	_scroll_vbox.name = "SkinVBox"
	_scroll_vbox.add_theme_constant_override("separation", UITheme.GRID)
	_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_scroll_vbox)

func _build_detail_popup(parent: Control) -> void:
	_详情弹窗 = PanelContainer.new()
	_详情弹窗.name = "DetailPopup"
	_详情弹窗.visible = false
	_详情弹窗.z_index = 100
	_详情弹窗.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.7)
	_详情弹窗.add_theme_stylebox_override("panel", bg_style)
	parent.add_child(_详情弹窗)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_详情弹窗.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(800, 1200)
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(true))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_bottom", UITheme.MARGIN)
	panel.add_child(vbox)

	var close_hbox := HBoxContainer.new()
	close_hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(close_hbox)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(60, 60)
	UITheme.apply_title_font_sized(close_btn, UITheme.FONT_H1)
	close_btn.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	close_btn.pressed.connect(_on_close_detail)
	close_hbox.add_child(close_btn)

	var detail_title := Label.new()
	detail_title.name = "DetailTitle"
	detail_title.text = "皮肤详情"
	UITheme.apply_page_title(detail_title)
	vbox.add_child(detail_title)

	_详情立绘 = TextureRect.new()
	_详情立绘.name = "DetailPortrait"
	_详情立绘.custom_minimum_size = Vector2(0, 500)
	_详情立绘.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_详情立绘.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(_详情立绘)

	_详情描述 = Label.new()
	_详情描述.name = "DetailDesc"
	_详情描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_text(_详情描述)
	vbox.add_child(_详情描述)

	var effect_title := Label.new()
	effect_title.text = "特效与加成"
	UITheme.apply_section_title(effect_title)
	vbox.add_child(effect_title)

	_详情特效 = VBoxContainer.new()
	_详情特效.name = "EffectList"
	_详情特效.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_child(_详情特效)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", UITheme.GRID)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	_详情购买按钮 = Button.new()
	_详情购买按钮.text = "购入"
	_详情购买按钮.custom_minimum_size = Vector2(300, UITheme.BTN_H_PRIMARY)
	_详情购买按钮.pressed.connect(_on_buy_pressed)
	_set_button_primary(_详情购买按钮)
	btn_hbox.add_child(_详情购买按钮)

func _set_button_primary(btn: Button) -> void:
	btn.flat = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.COLOR_BTN_PRIMARY
	sb.border_color = UITheme.color_border_gold()
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(UITheme.GRID)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("hover", sb)
	UITheme.apply_button_label(btn, true)

func _set_button_secondary(btn: Button) -> void:
	btn.flat = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.122, 0.169, 0.192, 0.90)
	sb.border_color = UITheme.color_border_gold()
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(UITheme.GRID)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("hover", sb)
	UITheme.apply_button_label(btn, false)

func refresh() -> void:
	if not _built:
		return
	if Game != null and Game.has_method("取仙玉"):
		_仙玉标签.text = str(Game.取仙玉())
	for child in _scroll_vbox.get_children():
		child.queue_free()
	_皮肤卡片字典.clear()
	var 所有皮肤: Dictionary = _加载宗主皮肤配置()
	var 显示列表: Array = []
	for 皮肤ID in 所有皮肤.keys():
		var 皮肤: Dictionary = 所有皮肤[皮肤ID]
		# 分类筛选 + 性别筛选
		var 分类匹配: bool = (_当前分类 == "全部" or 皮肤.get("rarity", "") == _当前分类)
		var 性别匹配: bool = (皮肤.get("gender", "") == _当前性别)
		if 分类匹配 and 性别匹配:
			显示列表.append(皮肤ID)
	var 行: HBoxContainer = null
	for i in range(显示列表.size()):
		if i % 2 == 0:
			行 = HBoxContainer.new()
			行.add_theme_constant_override("separation", UITheme.GRID)
			行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_scroll_vbox.add_child(行)
		var 卡片: Control = _make_skin_card(显示列表[i], 所有皮肤[显示列表[i]])
		卡片.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行.add_child(卡片)
	# 如果最后一行只有1个卡片，添加空占位保持2列布局（右边留空，后续新皮肤自动填充）
	if 行 != null and 行.get_child_count() == 1:
		var 占位 := Control.new()
		占位.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行.add_child(占位)
	if 显示列表.is_empty():
		var empty := Label.new()
		empty.text = "尚无皮肤"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_aux_text(empty)
		_scroll_vbox.add_child(empty)
	# 神品分类或全部分类下显示仙缘夺宝入口
	_add_lottery_entry()

func _add_lottery_entry() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	_scroll_vbox.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_left", UITheme.GRID)
	vbox.add_theme_constant_override("margin_right", UITheme.GRID)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID / 2)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "仙缘夺宝·宗主"
	UITheme.apply_section_title(title)
	vbox.add_child(title)
	var desc := Label.new()
	desc.text = "单次200仙玉 / 十连1800仙玉（让利10%）\n80次保底必出神品宗主皮肤"
	UITheme.apply_aux_text(desc)
	vbox.add_child(desc)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(hbox)
	var single_btn := Button.new()
	single_btn.text = "单次抽奖"
	single_btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	single_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	single_btn.pressed.connect(_on_lottery_single)
	_set_button_secondary(single_btn)
	hbox.add_child(single_btn)
	var ten_btn := Button.new()
	ten_btn.text = "十连抽奖"
	ten_btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	ten_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ten_btn.pressed.connect(_on_lottery_ten)
	_set_button_primary(ten_btn)
	hbox.add_child(ten_btn)

func _加载宗主皮肤配置() -> Dictionary:
	var 配置: Dictionary = {}
	var 路径: String = "res://config/master_skin_config.csv"
	if not FileAccess.file_exists(路径):
		return 配置
	var 文件: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		return 配置
	var 表头: Array = 文件.get_csv_line()
	while not 文件.eof_reached():
		var 行: Array = 文件.get_csv_line()
		if 行.size() < 2 or 行[0] == "":
			continue
		var 皮肤: Dictionary = {}
		for i in range(表头.size()):
			if i < 行.size():
				皮肤[表头[i]] = 行[i]
		var 皮肤ID: String = 皮肤.get("skin_id", "")
		if 皮肤ID != "":
			配置[皮肤ID] = 皮肤
	文件.close()
	return 配置

func _make_skin_card(皮肤ID: String, 皮肤: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "SkinCard_" + 皮肤ID
	card.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	card.custom_minimum_size = Vector2(0, 450)
	_皮肤卡片字典[皮肤ID] = card

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_left", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_right", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID / 2)
	card.add_child(vbox)

	# 缩略图（保持比例铺满，高度增加确保头部不被裁剪）
	var portrait_rect := TextureRect.new()
	portrait_rect.name = "Portrait"
	portrait_rect.custom_minimum_size = Vector2(0, 450)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_rect.clip_contents = true
	var 立绘路径: String = "res://art/characters/masters/skins/" + 皮肤ID + "/halfbody.png"
	if ResourceLoader.exists(立绘路径):
		portrait_rect.texture = load(立绘路径)
	vbox.add_child(portrait_rect)

	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_child(name_hbox)

	var name_label := Label.new()
	name_label.text = 皮肤.get("name", "")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_body_text(name_label)
	name_hbox.add_child(name_label)

	var 品级: String = 皮肤.get("rarity", "宝品")
	var rarity_label := Label.new()
	rarity_label.text = 品级
	rarity_label.add_theme_color_override("font_color", 品级颜色.get(品级, UITheme.color_text_body()))
	UITheme.apply_aux_text(rarity_label)
	name_hbox.add_child(rarity_label)

	# 全宗加成预览
	var bonus_cult: float = float(皮肤.get("bonus_cultivation", 0))
	var bonus_stone: float = float(皮肤.get("bonus_lingshi", 0))
	var bonus_all: float = float(皮肤.get("bonus_all_attr", 0))
	var bonus_text := "【全宗】"
	if bonus_cult > 0:
		bonus_text += "修为+%.1f%% " % bonus_cult
	if bonus_stone > 0:
		bonus_text += "灵石+%.1f%% " % bonus_stone
	if bonus_all > 0:
		bonus_text += "全属+%.1f%%" % bonus_all
	var bonus_label := Label.new()
	bonus_label.text = bonus_text.strip_edges()
	bonus_label.add_theme_color_override("font_color", UITheme.color_status_success())
	UITheme.apply_aux_text(bonus_label)
	vbox.add_child(bonus_label)

	var obtain_label := Label.new()
	obtain_label.text = "仙缘夺宝"
	obtain_label.add_theme_color_override("font_color", UITheme.color_text_gold())
	UITheme.apply_aux_text(obtain_label)
	vbox.add_child(obtain_label)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_child(btn_hbox)

	var view_btn := Button.new()
	view_btn.text = "预览"
	view_btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	view_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_btn.pressed.connect(_on_view_skin.bind(皮肤ID))
	_set_button_secondary(view_btn)
	btn_hbox.add_child(view_btn)

	# 已拥有的皮肤显示装备/已装备按钮
	var action_btn := Button.new()
	action_btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Game != null and Game.has_method("是否拥有宗主皮肤") and Game.是否拥有宗主皮肤(皮肤ID):
		if Game.has_method("取当前宗主皮肤") and Game.取当前宗主皮肤() == 皮肤ID:
			action_btn.text = "已装备"
			action_btn.disabled = true
			_set_button_secondary(action_btn)
		else:
			action_btn.text = "披挂"
			action_btn.pressed.connect(_on_equip_skin.bind(皮肤ID))
			_set_button_primary(action_btn)
	else:
		action_btn.text = "未拥有"
		action_btn.disabled = true
		_set_button_secondary(action_btn)
	btn_hbox.add_child(action_btn)

	return card

func _on_view_skin(皮肤ID: String) -> void:
	_当前查看皮肤 = 皮肤ID
	var 所有皮肤: Dictionary = _加载宗主皮肤配置()
	var 皮肤: Dictionary = 所有皮肤.get(皮肤ID, {})
	if 皮肤.is_empty():
		return
	_详情立绘.texture = null
	var 立绘路径: String = "res://art/characters/masters/skins/" + 皮肤ID + "/stand.png"
	if ResourceLoader.exists(立绘路径):
		_详情立绘.texture = load(立绘路径)
	_详情描述.text = 皮肤.get("desc", 皮肤.get("name", ""))
	for child in _详情特效.get_children():
		child.queue_free()
	var bonus_cult: float = float(皮肤.get("bonus_cultivation", 0))
	var bonus_stone: float = float(皮肤.get("bonus_lingshi", 0))
	var bonus_all: float = float(皮肤.get("bonus_all_attr", 0))
	if bonus_cult > 0:
		var lbl := Label.new()
		lbl.text = "全宗修为速度 +%.1f%%" % bonus_cult
		lbl.add_theme_color_override("font_color", UITheme.color_status_success())
		UITheme.apply_body_text(lbl)
		_详情特效.add_child(lbl)
	if bonus_stone > 0:
		var lbl := Label.new()
		lbl.text = "全宗灵石产出 +%.1f%%" % bonus_stone
		lbl.add_theme_color_override("font_color", UITheme.color_status_success())
		UITheme.apply_body_text(lbl)
		_详情特效.add_child(lbl)
	if bonus_all > 0:
		var lbl := Label.new()
		lbl.text = "全宗全属性 +%.1f%%" % bonus_all
		lbl.add_theme_color_override("font_color", UITheme.color_status_success())
		UITheme.apply_body_text(lbl)
		_详情特效.add_child(lbl)
	var title: String = 皮肤.get("title", "")
	if title != "":
		var lbl := Label.new()
		lbl.text = "专属称号：" + title
		lbl.add_theme_color_override("font_color", UITheme.color_text_gold())
		UITheme.apply_body_text(lbl)
		_详情特效.add_child(lbl)
	var effects: String = 皮肤.get("effects", "")
	if effects != "":
		var lbl := Label.new()
		lbl.text = "特效：" + effects
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		UITheme.apply_aux_text(lbl)
		_详情特效.add_child(lbl)
	# 弹窗按钮：已拥有→装备/已装备，未拥有→仙缘夺宝获取
	if Game != null and Game.has_method("是否拥有宗主皮肤") and Game.是否拥有宗主皮肤(皮肤ID):
		if Game.has_method("取当前宗主皮肤") and Game.取当前宗主皮肤() == 皮肤ID:
			_详情购买按钮.text = "已装备"
			_详情购买按钮.disabled = true
		else:
			_详情购买按钮.text = "披挂"
			_详情购买按钮.disabled = false
			_详情购买按钮.pressed.disconnect(_on_buy_pressed) if _详情购买按钮.pressed.is_connected(_on_buy_pressed) else null
			if not _详情购买按钮.pressed.is_connected(_on_equip_pressed):
				_详情购买按钮.pressed.connect(_on_equip_pressed)
	else:
		_详情购买按钮.text = "仙缘夺宝获取"
		_详情购买按钮.disabled = true
	_详情弹窗.visible = true

func _on_close_detail() -> void:
	_详情弹窗.visible = false

func _on_buy_pressed() -> void:
	if _当前查看皮肤 == "":
		return
	_on_buy_skin(_当前查看皮肤)

func _on_equip_pressed() -> void:
	if _当前查看皮肤 == "":
		return
	_on_equip_skin(_当前查看皮肤)

func _on_equip_skin(皮肤ID: String) -> void:
	if Game != null and Game.has_method("装备宗主皮肤"):
		Game.装备宗主皮肤(皮肤ID)
		_状态标签.text = "装备成功"
		_详情弹窗.visible = false
		refresh()

func _on_buy_skin(皮肤ID: String) -> void:
	var 所有皮肤: Dictionary = _加载宗主皮肤配置()
	var 皮肤: Dictionary = 所有皮肤.get(皮肤ID, {})
	var price: int = int(皮肤.get("price", "0"))
	if price <= 0:
		_状态标签.text = "该皮肤需通过仙缘夺宝获取"
		return
	if Game == null or not Game.has_method("消耗仙玉_付费"):
		_状态标签.text = "系统未就绪"
		return
	if not Game.消耗仙玉_付费(price):
		_状态标签.text = "非绑定仙玉匮乏（皮肤仅支持付费仙玉）"
		return
	if Game.has_method("获得宗主皮肤"):
		Game.获得宗主皮肤(皮肤ID)
	if Game.has_method("装备宗主皮肤"):
		Game.装备宗主皮肤(皮肤ID)
	_状态标签.text = "购买成功！已自动装备"
	refresh()

func _on_back_pressed() -> void:
	返回主页.emit()

func _on_tab_pressed(分类: String) -> void:
	_当前分类 = 分类
	_update_tab_styles()
	refresh()

func _on_gender_pressed(性别: String) -> void:
	_当前性别 = 性别
	_update_gender_styles()
	refresh()

# ============ 宗主仙缘夺宝抽奖 ============
var _宗主抽奖累计: int = 0
var _宗主抽奖保底剩余: int = 80

func _获取宗主奖池() -> Array:
	var 奖池: Array = []
	var 所有皮肤: Dictionary = _加载宗主皮肤配置()
	for 皮肤ID in 所有皮肤.keys():
		var 皮肤: Dictionary = 所有皮肤[皮肤ID]
		# 只包含抽奖类型且匹配当前性别的皮肤
		if 皮肤.get("obtain_type", "") == "lottery" and 皮肤.get("gender", "") == _当前性别:
			奖池.append(皮肤ID)
	return 奖池

func _执行宗主抽奖() -> Dictionary:
	_宗主抽奖累计 += 1
	_宗主抽奖保底剩余 -= 1
	var 所有皮肤: Dictionary = _加载宗主皮肤配置()
	# 按品级分组
	var 宝品池: Array = []
	var 仙品池: Array = []
	var 神品池: Array = []
	for 皮肤ID in 所有皮肤.keys():
		var 皮肤: Dictionary = 所有皮肤[皮肤ID]
		# 只包含抽奖类型且匹配当前性别的皮肤
		if 皮肤.get("obtain_type", "") != "lottery" or 皮肤.get("gender", "") != _当前性别:
			continue
		var 品级: String = 皮肤.get("rarity", "宝品")
		if 品级 == "神品":
			神品池.append(皮肤ID)
		elif 品级 == "仙品":
			仙品池.append(皮肤ID)
		else:
			宝品池.append(皮肤ID)
	var 皮肤ID: String = ""
	if _宗主抽奖保底剩余 <= 0 and not 神品池.is_empty():
		# 保底：随机一个未拥有的神品
		var 未拥有: Array = []
		for sid in 神品池:
			if not Game.是否拥有宗主皮肤(sid):
				未拥有.append(sid)
		if 未拥有.is_empty():
			未拥有 = 神品池
		皮肤ID = 未拥有.pick_random()
		_宗主抽奖保底剩余 = 80
	else:
		var r: float = randf()
		if r < 0.05 and not 神品池.is_empty():
			皮肤ID = 神品池.pick_random()
		elif r < 0.30 and not 仙品池.is_empty():
			皮肤ID = 仙品池.pick_random()
		elif not 宝品池.is_empty():
			皮肤ID = 宝品池.pick_random()
		elif not 仙品池.is_empty():
			皮肤ID = 仙品池.pick_random()
		else:
			皮肤ID = 神品池.pick_random() if not 神品池.is_empty() else ""
	if 皮肤ID == "":
		return {"success": false, "msg": "奖池为空"}
	var 皮肤名: String = 所有皮肤.get(皮肤ID, {}).get("name", 皮肤ID)
	return {"success": true, "skin_id": 皮肤ID, "skin_name": 皮肤名}

func _on_lottery_single() -> void:
	if Game == null or not Game.has_method("消耗仙玉"):
		_状态标签.text = "系统未就绪"
		return
	if not Game.消耗仙玉(200):
		_状态标签.text = "仙玉匮乏"
		return
	var 结果: Dictionary = _执行宗主抽奖()
	if 结果.get("success", false):
		var 皮肤ID: String = 结果.get("skin_id", "")
		Game.获得宗主皮肤(皮肤ID)
		_状态标签.text = "抽奖获得：" + 结果.get("skin_name", 皮肤ID)
		refresh()
	else:
		_状态标签.text = 结果.get("msg", "抽奖受阻")

func _on_lottery_ten() -> void:
	if Game == null or not Game.has_method("消耗仙玉"):
		_状态标签.text = "系统未就绪"
		return
	if not Game.消耗仙玉(1800):
		_状态标签.text = "仙玉匮乏"
		return
	var 文本: String = "十连抽获得："
	for i in range(10):
		var 结果: Dictionary = _执行宗主抽奖()
		if 结果.get("success", false):
			var 皮肤ID: String = 结果.get("skin_id", "")
			Game.获得宗主皮肤(皮肤ID)
			文本 += 结果.get("skin_name", 皮肤ID) + "、"
	_状态标签.text = 文本.trim_suffix("、")
	refresh()




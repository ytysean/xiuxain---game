extends Control

# 仙衣阁 - 立绘皮肤商店页（GameUI 二级页）
# 功能：皮肤展示/购买/装备、仙缘夺宝抽奖入口
signal 返回主页
signal 皮肤购买完成

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

const 分类列表: Array = ["全部", "灵品", "宝品", "仙品", "神品", "仙缘夺宝"]
const 品级颜色: Dictionary = {
	"灵品": Color(0.36, 0.66, 0.62),
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
	title.text = "仙衣阁"
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
	# 性别切换按钮（男/女）
	var 分隔 := Label.new()
	分隔.text = "|"
	分隔.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	hbox.add_child(分隔)
	for 性别 in ["男", "女"]:
		var 性别btn := Button.new()
		性别btn.name = "Gender_" + 性别
		性别btn.text = 性别 + "弟子"
		性别btn.flat = true
		性别btn.custom_minimum_size = Vector2(80, UITheme.SIZE_MD)
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
			# 选中状态用金色背景
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
	# 半透明黑色背景
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

	# 关闭按钮
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
	sb.bg_color = Color(0.12, 0.18, 0.17, 0.9)
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
	# 立即清空所有子节点（使用free而不是queue_free，避免异步释放导致新旧卡片混在一起）
	while _scroll_vbox.get_child_count() > 0:
		var child = _scroll_vbox.get_child(0)
		_scroll_vbox.remove_child(child)
		child.queue_free()
	_皮肤卡片字典.clear()
	# 延迟一帧再构建新卡片，确保旧卡片已完全释放
	call_deferred("_refresh_skin_cards")

func _refresh_skin_cards() -> void:
	if not is_instance_valid(_scroll_vbox):
		return
	var 所有皮肤: Dictionary = SkinManager.获取所有皮肤()
	var 显示列表: Array = []
	for 皮肤ID in 所有皮肤.keys():
		var 皮肤: Dictionary = 所有皮肤[皮肤ID]
		if _当前分类 == "全部" or 皮肤.get("rarity", "") == _当前分类:
			显示列表.append(皮肤ID)
	# 仙缘夺宝分类
	if _当前分类 == "仙缘夺宝":
		显示列表 = []
		for 皮肤ID in 所有皮肤.keys():
			var 皮肤: Dictionary = 所有皮肤[皮肤ID]
			if 皮肤.get("obtain_type", "") == "lottery":
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
	# 添加仙缘夺宝入口
	if _当前分类 == "仙缘夺宝" or _当前分类 == "全部":
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
	title.text = "仙缘夺宝"
	UITheme.apply_section_title(title)
	vbox.add_child(title)
	var desc := Label.new()
	desc.text = "单次200仙玉 / 十连1800仙玉（9折）\n80次保底必出神品皮肤"
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

func _make_skin_card(皮肤ID: String, 皮肤: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "SkinCard_" + 皮肤ID
	card.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	card.custom_minimum_size = Vector2(0, 400)
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
	portrait_rect.texture = null
	var 立绘路径: String = "res://art/characters/disciples/skins/" + 皮肤ID + "/" + _当前性别 + "_halfbody.png"
	if not ResourceLoader.exists(立绘路径):
		var 兜底性别: String = "女" if _当前性别 == "男" else "男"
		立绘路径 = "res://art/characters/disciples/skins/" + 皮肤ID + "/" + 兜底性别 + "_halfbody.png"
	if ResourceLoader.exists(立绘路径):
		var tex: Texture2D = ResourceLoader.load(立绘路径, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
		if tex != null:
			portrait_rect.texture = tex
	vbox.add_child(portrait_rect)

	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_child(name_hbox)

	var name_label := Label.new()
	name_label.text = 皮肤.get("name", "")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_body_text(name_label)
	name_hbox.add_child(name_label)

	var 品级: String = 皮肤.get("rarity", "灵品")
	var rarity_label := Label.new()
	rarity_label.text = 品级
	rarity_label.add_theme_color_override("font_color", 品级颜色.get(品级, UITheme.color_text_body()))
	UITheme.apply_aux_text(rarity_label)
	name_hbox.add_child(rarity_label)

	var price_label := Label.new()
	var price: int = int(皮肤.get("price", "0"))
	if price > 0:
		price_label.text = "仙玉 " + str(price)
	else:
		price_label.text = "仙缘夺宝"
	UITheme.apply_aux_text(price_label)
	vbox.add_child(price_label)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_child(btn_hbox)

	var view_btn := Button.new()
	view_btn.text = "查看"
	view_btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	view_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_btn.pressed.connect(_on_view_skin.bind(皮肤ID))
	_set_button_secondary(view_btn)
	btn_hbox.add_child(view_btn)

	var buy_btn := Button.new()
	buy_btn.text = "购入"
	buy_btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.pressed.connect(_on_buy_skin.bind(皮肤ID))
	_set_button_primary(buy_btn)
	btn_hbox.add_child(buy_btn)

	# 更新按钮状态
	if Game != null and Game.has_method("是否拥有皮肤"):
		if Game.是否拥有皮肤(皮肤ID):
			buy_btn.text = "已拥有"
			buy_btn.disabled = true

	return card

func _on_view_skin(皮肤ID: String) -> void:
	_当前查看皮肤 = 皮肤ID
	var 所有皮肤: Dictionary = SkinManager.获取所有皮肤()
	var 皮肤: Dictionary = 所有皮肤.get(皮肤ID, {})
	if 皮肤.is_empty():
		return
	_详情立绘.texture = null
	var 立绘路径: String = "res://art/characters/disciples/skins/" + 皮肤ID + "/" + _当前性别 + "_stand.png"
	if not ResourceLoader.exists(立绘路径):
		# 兜底：如果对应性别立绘不存在，尝试另一种性别
		var 兜底性别: String = "女" if _当前性别 == "男" else "男"
		立绘路径 = "res://art/characters/disciples/skins/" + 皮肤ID + "/" + 兜底性别 + "_stand.png"
	if ResourceLoader.exists(立绘路径):
		_详情立绘.texture = load(立绘路径)
	_详情描述.text = 皮肤.get("desc", 皮肤.get("name", ""))
	# 清空特效列表
	for child in _详情特效.get_children():
		child.queue_free()
	var bonus_cult: float = float(皮肤.get("bonus_cultivation", 0))
	var bonus_stone: float = float(皮肤.get("bonus_lingshi", 0))
	var bonus_all: float = float(皮肤.get("bonus_all_attr", 0))
	if bonus_cult > 0:
		var lbl := Label.new()
		lbl.text = "修为速度 +%.1f%%" % bonus_cult
		lbl.add_theme_color_override("font_color", UITheme.color_status_success())
		UITheme.apply_body_text(lbl)
		_详情特效.add_child(lbl)
	if bonus_stone > 0:
		var lbl := Label.new()
		lbl.text = "灵石产出 +%.1f%%" % bonus_stone
		lbl.add_theme_color_override("font_color", UITheme.color_status_success())
		UITheme.apply_body_text(lbl)
		_详情特效.add_child(lbl)
	if bonus_all > 0:
		var lbl := Label.new()
		lbl.text = "全属性 +%.1f%%" % bonus_all
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
	# 更新购买按钮
	var price: int = int(皮肤.get("price", "0"))
	if Game != null and Game.has_method("是否拥有皮肤") and Game.是否拥有皮肤(皮肤ID):
		_详情购买按钮.text = "已拥有"
		_详情购买按钮.disabled = true
	else:
		_详情购买按钮.text = "购买（仙玉 %d）" % price if price > 0 else "仙缘夺宝"
		_详情购买按钮.disabled = (price <= 0)
	_详情弹窗.visible = true

func _on_close_detail() -> void:
	_详情弹窗.visible = false

func _on_buy_pressed() -> void:
	if _当前查看皮肤 == "":
		return
	_on_buy_skin(_当前查看皮肤)

func _on_buy_skin(皮肤ID: String) -> void:
	var 配置: Dictionary = SkinManager.获取皮肤配置(皮肤ID)
	var price: int = int(配置.get("price", "0"))
	if price <= 0:
		_状态标签.text = "该皮肤需通过仙缘夺宝获取"
		return
	if Game == null or not Game.has_method("消耗仙玉_付费"):
		_状态标签.text = "系统未就绪"
		return
	if not Game.消耗仙玉_付费(price):
		_状态标签.text = "非绑定仙玉匮乏（皮肤仅支持付费仙玉）"
		return
	Game.获得弟子皮肤(皮肤ID)
	_状态标签.text = "购买成功！可在弟子详情中装备"
	皮肤购买完成.emit()
	refresh()

func _on_equip_skin(皮肤ID: String) -> void:
	if Game == null or not Game.has_method("装备宗主皮肤"):
		return
	Game.装备宗主皮肤(皮肤ID)
	_状态标签.text = "装备成功"
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

func _on_lottery_single() -> void:
	var 结果: Dictionary = SkinManager.单次抽奖()
	if 结果.get("success", false):
		var 皮肤ID: String = 结果.get("skin_id", "")
		_状态标签.text = "抽奖获得：" + 结果.get("skin_name", 皮肤ID)
		Game.获得弟子皮肤(皮肤ID)
		refresh()
	else:
		_状态标签.text = 结果.get("msg", "抽奖受阻")

func _on_lottery_ten() -> void:
	var 结果: Dictionary = SkinManager.十连抽奖()
	if 结果.get("success", false):
		var 获得列表: Array = 结果.get("results", [])
		var 文本: String = "十连抽获得："
		for r in 获得列表:
			if r is Dictionary and r.get("success", false):
				var 皮肤ID: String = r.get("skin_id", "")
				文本 += r.get("skin_name", 皮肤ID) + "、"
				Game.获得弟子皮肤(皮肤ID)
		_状态标签.text = 文本.trim_suffix("、")
		refresh()
	else:
		_状态标签.text = 结果.get("msg", "抽奖受阻")

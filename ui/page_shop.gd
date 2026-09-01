extends Control

# 仙玉商店页（GameUI 二级页）：对齐 Ardot 06 屏「商店：坊市」。
# 分类 Tab / 限时特惠 / 商品卡片 / 底部充值入口；全部字体走 UITheme 角色 helper。
# 购物流程仅调用 Game.购买仙玉商品，不改数据层既有字段。
signal 坊市购买完成
signal 返回主页
signal 仙衣阁请求
signal 宗主仙衣阁请求

var _built: bool = false
var _当前分类: String = "推荐"
var _scroll_vbox: VBoxContainer
var _featured_panel: PanelContainer
var _状态标签: Label
var _香火标签: Label
var _仙玉标签: Label
var _tab_buttons: Dictionary = {}

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
	_build_featured(root)
	_build_list(root)
	_build_bottom(root)

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
	title.text = "坊市"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			UIHint.show_hint(title, "坊市", "使用灵石、仙玉购买丹药、法器、材料等物资。\n\n· 灵石：宗门基础货币，由弟子供奉与贸易产出\n· 仙玉：稀有货币，可购买专属皮肤与珍贵道具\n· 仙衣阁：弟子与宗主专属皮肤商店"))
	UITheme.apply_page_title(title)
	bar.add_child(title)

	# 仙衣阁入口按钮
	var skin_btn := Button.new()
	skin_btn.name = "SkinShopBtn"
	skin_btn.text = "弟子仙衣"
	skin_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skin_btn.pressed.connect(_on_skin_shop_pressed)
	bar.add_child(skin_btn)

	# 宗主仙衣阁入口按钮
	var master_skin_btn := Button.new()
	master_skin_btn.name = "MasterSkinShopBtn"
	master_skin_btn.text = "宗主仙衣"
	master_skin_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	master_skin_btn.pressed.connect(_on_master_skin_shop_pressed)
	bar.add_child(master_skin_btn)

	# S1-4 付费：仙玉刷新坊市上架
	var 刷新btn := Button.new()
	刷新btn.name = "PayRefreshMarketBtn"
	刷新btn.text = "刷新坊市"
	if is_instance_valid(Game):
		刷新btn.text = "刷新坊市（%d仙玉）" % Game.付费单价.get("坊市刷新", 5)
	刷新btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	刷新btn.pressed.connect(_on_付费_刷新坊市)
	bar.add_child(刷新btn)

	_香火标签 = Label.new()
	_香火标签.name = "XianghuoValue"
	var xianghuo_capsule: PanelContainer = _make_currency_capsule("res://art/icons/hd/res_xianghuo_36.png", _香火标签)
	bar.add_child(xianghuo_capsule)

	_仙玉标签 = Label.new()
	_仙玉标签.name = "XianyuValue"
	var xianyu_capsule: PanelContainer = _make_currency_capsule("res://art/icons/hd/res_xianyu_36.png", _仙玉标签)
	bar.add_child(xianyu_capsule)

func _make_currency_capsule(icon_path: String, out_label: Label) -> PanelContainer:
	var capsule := PanelContainer.new()
	capsule.name = "CurrencyCapsule"
	capsule.custom_minimum_size = Vector2(0, 36)
	capsule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.118, 0.227, 0.271)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(4)
	capsule.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.name = "CapsuleHBox"
	hb.add_theme_constant_override("separation", 4)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	capsule.add_child(hb)

	var tex: Texture2D = load(icon_path) as Texture2D
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = tex
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(icon)

	out_label.text = "—"
	out_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.apply_value_font(out_label, false)
	out_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	hb.add_child(out_label)
	return capsule

func _build_tabs(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.name = "CategoryTabs"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	for cat: String in XianyuShop.分类列表:
		var btn := Button.new()
		btn.name = "Tab_" + cat
		btn.text = cat
		btn.flat = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_tab_pressed.bind(cat))
		_tab_buttons[cat] = btn
		bar.add_child(btn)
	for cat: String in ["出售", "收购", "回购"]:
		var btn := Button.new()
		btn.name = "Tab_" + cat
		btn.text = cat
		btn.flat = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_tab_pressed.bind(cat))
		_tab_buttons[cat] = btn
		bar.add_child(btn)
	parent.add_child(bar)
	_update_tab_styles()

func _update_tab_styles() -> void:
	for cat in _tab_buttons.keys():
		var btn: Button = _tab_buttons[cat]
		var sel: bool = (cat == _当前分类)
		if sel:
			UITheme.apply_title_font_sized(btn, UITheme.FONT_BODY)
		else:
			UITheme.apply_body_font_sized(btn, UITheme.FONT_BODY)
		btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD if sel else UITheme.color_text_body_dim())
		btn.add_theme_color_override("font_hover_color", UITheme.COLOR_TEXT_GOLD)
		btn.add_theme_color_override("font_pressed_color", UITheme.COLOR_TEXT_GOLD)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.118, 0.227, 0.271) if sel else Color(0, 0, 0, 0)
		sb.border_color = UITheme.COLOR_TEXT_GOLD if sel else Color(0, 0, 0, 0)
		sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
		sb.border_width_bottom = 3
		sb.set_content_margin_all(UITheme.GRID)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("focus", sb)

func _build_featured(parent: Control) -> void:
	_featured_panel = PanelContainer.new()
	_featured_panel.name = "FeaturedPanel"
	_featured_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.094, 0.176, 0.216)
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	_featured_panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(_featured_panel)

func _build_list(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	_scroll_vbox = VBoxContainer.new()
	_scroll_vbox.name = "ListVBox"
	_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_vbox.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_scroll_vbox)

func _build_bottom(parent: Control) -> void:
	var bar := PanelContainer.new()
	bar.name = "BottomBar"
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.067, 0.129, 0.165)
	bar.add_theme_stylebox_override("panel", sb)

	var btn := Button.new()
	btn.name = "RechargeBtn"
	btn.text = "供奉仙玉 · 以助道途"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 64)
	_apply_gold_gradient(btn)
	UITheme.apply_button_label(btn, true)
	btn.pressed.connect(_on_recharge_pressed)
	bar.add_child(btn)
	parent.add_child(bar)

func refresh() -> void:
	if not _built:
		_build()
	_populate()

func _populate() -> void:
	if _香火标签 != null and is_instance_valid(Game):
		var v: Variant = Game.get("香火值")
		_香火标签.text = UITheme.format_resource(0 if v == null else int(v))
	if _仙玉标签 != null and is_instance_valid(Game):
		var v: Variant = Game.get("仙玉_非绑定")
		_仙玉标签.text = UITheme.format_resource(0 if v == null else int(v))

	if _featured_panel != null:
		for child in _featured_panel.get_children():
			_featured_panel.remove_child(child)
			child.queue_free()
		if _当前分类 == "推荐":
			# 大厂标准：每日特惠商品列表（使用新添加的Game.获取商城每日特惠()）
			var 每日特惠列表: Array = []
			if is_instance_valid(Game):
				每日特惠列表 = Game.获取商城每日特惠()
			if not 每日特惠列表.is_empty():
				# 每日特惠标题
				var title_label := Label.new()
				title_label.name = "DailySpecialTitle"
				title_label.text = "每日特供"
				title_label.add_theme_font_size_override("font_size", 18)
				title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
				_featured_panel.add_child(title_label)
				
				# 每日特惠商品列表
				var 特惠vbox := VBoxContainer.new()
				特惠vbox.name = "DailySpecialVBox"
				特惠vbox.add_theme_constant_override("separation", 8)
				_featured_panel.add_child(特惠vbox)
				
				for 特惠商品 in 每日特惠列表:
					var 商品 = 特惠商品.get("商品", {})
					var 原价 = int(特惠商品.get("原价", 0))
					var 特惠价 = int(特惠商品.get("特惠价", 0))
					var 折扣百分比 = int(特惠商品.get("折扣百分比", 0))
					
					var 商品卡片 = _make_daily_special_card(商品, 原价, 特惠价, 折扣百分比)
					特惠vbox.add_child(商品卡片)
			else:
				# 原有限时特惠（仙玉商店）
				var featured: Dictionary = XianyuShop.取限时特惠()
				if not featured.is_empty():
					_featured_panel.add_child(_make_featured_card(featured))
		_featured_panel.visible = (_当前分类 == "推荐") and (_featured_panel.get_child_count() > 0)

	if _scroll_vbox == null:
		return
	for child in _scroll_vbox.get_children():
		_scroll_vbox.remove_child(child)
		child.queue_free()

	if _当前分类 == "收购":
		_populate_收购()
		return
	if _当前分类 == "出售":
		_populate_出售()
		return
	if _当前分类 == "回购":
		_populate_回购()
		return

	# 灵宝 Tab：纯 XianyuShop 仙玉商品（限时特惠 / 常规），不含坊市灵石商品
	var list: Array = XianyuShop.取分类商品(_当前分类)
	if list.is_empty():
		_add_empty("该分类尚无商品")
	else:
		for p: Dictionary in list:
			_scroll_vbox.add_child(_make_product_card(p))

func _make_featured_card(商品: Dictionary) -> Control:
	var hb := HBoxContainer.new()
	hb.name = "FeaturedHBox"
	hb.add_theme_constant_override("separation", UITheme.GRID)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN

	var icon_bg: PanelContainer = _make_icon_bg(商品)
	hb.add_child(icon_bg)

	var info := VBoxContainer.new()
	info.name = "FeaturedInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	hb.add_child(info)

	var tag := Label.new()
	tag.name = "FeaturedTag"
	tag.text = "限时机缘"
	UITheme.apply_aux_text(tag)
	tag.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	info.add_child(tag)

	var name_lbl := Label.new()
	name_lbl.name = "FeaturedName"
	name_lbl.text = str(商品.get("name", "—"))
	UITheme.apply_section_title(name_lbl)
	info.add_child(name_lbl)

	var price_row := HBoxContainer.new()
	price_row.name = "FeaturedPriceRow"
	price_row.add_theme_constant_override("separation", 8)
	info.add_child(price_row)

	var price := Label.new()
	price.name = "FeaturedPrice"
	price.text = "%d 仙玉" % int(商品.get("price", 0))
	UITheme.apply_value_text(price, false)
	price_row.add_child(price)

	var orig := Label.new()
	orig.name = "FeaturedOriginal"
	orig.text = "原价 %d" % int(商品.get("original_price", 0))
	UITheme.apply_aux_text(orig)
	orig.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	price_row.add_child(orig)

	var countdown := Label.new()
	countdown.name = "FeaturedCountdown"
	countdown.text = "剩余 02:14:33"
	UITheme.apply_aux_text(countdown)
	countdown.add_theme_color_override("font_color", Color(0.878, 0.639, 0.243))
	info.add_child(countdown)

	var buy := Button.new()
	buy.name = "FeaturedBuy"
	buy.text = "抢购"
	buy.custom_minimum_size = Vector2(96, 64)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_gold_gradient(buy)
	UITheme.apply_button_label(buy, true)
	buy.pressed.connect(_on_buy_pressed.bind(商品, buy))
	hb.add_child(buy)

	return hb

# 大厂标准：每日特惠商品卡片（带原价、特惠价、折扣标签）
func _make_daily_special_card(商品: Dictionary, 原价: int, 特惠价: int, 折扣百分比: int) -> Control:
	var card := PanelContainer.new()
	card.name = "DailySpecialCard"
	card.custom_minimum_size = Vector2(0, 90)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.15, 0.2, 1.0)
	card_style.border_color = Color(0.9, 0.6, 0.2, 1.0)
	card_style.border_width_left = 1
	card_style.border_width_right = 1
	card_style.border_width_top = 1
	card_style.border_width_bottom = 1
	card_style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", card_style)
	
	var hb := HBoxContainer.new()
	hb.name = "CardHBox"
	hb.add_theme_constant_override("separation", 12)
	card.add_child(hb)
	
	# 图标区域
	var icon_panel := PanelContainer.new()
	icon_panel.name = "IconPanel"
	icon_panel.custom_minimum_size = Vector2(64, 64)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.08, 0.1, 0.15, 1.0)
	icon_style.set_corner_radius_all(8)
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	
	var icon_label := Label.new()
	icon_label.name = "IconLabel"
	icon_label.text = "📦"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 28)
	icon_panel.add_child(icon_label)
	hb.add_child(icon_panel)
	
	# 信息区域
	var info := VBoxContainer.new()
	info.name = "InfoVBox"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hb.add_child(info)
	
	# 商品名称
	var name_label := Label.new()
	name_label.name = "ProductName"
	name_label.text = str(商品.get("item_name", "未知商品"))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	info.add_child(name_label)
	
	# 价格区域
	var price_hb := HBoxContainer.new()
	price_hb.name = "PriceHBox"
	price_hb.add_theme_constant_override("separation", 8)
	info.add_child(price_hb)
	
	# 特惠价
	var special_price := Label.new()
	special_price.name = "SpecialPrice"
	special_price.text = "💎 %d" % 特惠价
	special_price.add_theme_font_size_override("font_size", 18)
	special_price.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	price_hb.add_child(special_price)
	
	# 原价（划线）
	if 原价 > 特惠价:
		var original_price := Label.new()
		original_price.name = "OriginalPrice"
		original_price.text = "%d" % 原价
		original_price.add_theme_font_size_override("font_size", 14)
		original_price.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
		price_hb.add_child(original_price)
	
	# 折扣标签
	if 折扣百分比 > 0:
		var discount_badge := PanelContainer.new()
		discount_badge.name = "DiscountBadge"
		discount_badge.custom_minimum_size = Vector2(48, 20)
		var discount_style := StyleBoxFlat.new()
		discount_style.bg_color = Color(0.9, 0.2, 0.2, 1.0)
		discount_style.set_corner_radius_all(4)
		discount_badge.add_theme_stylebox_override("panel", discount_style)
		
		var discount_label := Label.new()
		discount_label.name = "DiscountLabel"
		discount_label.text = "-%d%%" % 折扣百分比
		discount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		discount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		discount_label.add_theme_font_size_override("font_size", 12)
		discount_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		discount_badge.add_child(discount_label)
		price_hb.add_child(discount_badge)
	
	# 购买按钮
	var buy_btn := Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.text = "购入"
	buy_btn.custom_minimum_size = Vector2(0, 32)
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	var btn_style_normal := StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.9, 0.6, 0.2, 1.0)
	btn_style_normal.set_corner_radius_all(6)
	buy_btn.add_theme_stylebox_override("normal", btn_style_normal)
	var btn_style_hover := StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.95, 0.65, 0.25, 1.0)
	btn_style_hover.set_corner_radius_all(6)
	buy_btn.add_theme_stylebox_override("hover", btn_style_hover)
	buy_btn.add_theme_color_override("font_color", Color(0.2, 0.15, 0.05, 1.0))
	buy_btn.add_theme_font_size_override("font_size", 14)
	buy_btn.pressed.connect(_on_daily_special_buy.bind(商品, 特惠价))
	info.add_child(buy_btn)
	
	return card

# 每日特惠购买按钮回调
func _on_daily_special_buy(商品: Dictionary, 价格: int) -> void:
	# 简化：显示购买提示
	var 商品名称 = str(商品.get("item_name", "未知商品"))
	UIHint.show_hint(self, "购买提示", "购买【%s】，价格：%d灵石\n\n（购买逻辑待接入）" % [商品名称, 价格])

func _make_product_card(商品: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Card_%s" % str(商品.get("id", ""))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UITheme.COLOR_PANEL_BG
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	panel.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.name = "CardHBox"
	hb.add_theme_constant_override("separation", UITheme.GRID)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(hb)

	var icon_bg: PanelContainer = _make_icon_bg(商品)
	hb.add_child(icon_bg)

	var info := VBoxContainer.new()
	info.name = "CardInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	hb.add_child(info)

	var name_lbl := Label.new()
	name_lbl.name = "CardName"
	name_lbl.text = str(商品.get("name", "—"))
	UITheme.apply_body_text(name_lbl)
	info.add_child(name_lbl)

	var desc := Label.new()
	desc.name = "CardDesc"
	desc.text = str(商品.get("desc", "—"))
	UITheme.apply_aux_text(desc)
	info.add_child(desc)

	var price := Label.new()
	price.name = "CardPrice"
	if str(商品.get("货币", "仙玉")) == "灵石":
		var 原价: int = int(商品.get("price_lingjing", 0))
		var 现价: int = 原价
		var 特惠倍: float = 1.0
		if is_instance_valid(Game) and Game.has_method("坊市物品现价"):
			var sid: String = str(商品.get("id", ""))
			现价 = Game.坊市物品现价(sid)
			if Game.has_method("坊市特惠倍率"):
				特惠倍 = Game.坊市特惠倍率(sid)
		price.text = "%d 灵石" % 现价
		if 特惠倍 != 1.0:
			price.text += "  ·特惠%d折" % int(特惠倍 * 100)
			price.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		else:
			price.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	else:
		price.text = "%d 仙玉" % int(商品.get("price", 0))
	UITheme.apply_value_text(price, false)
	info.add_child(price)

	var buy := Button.new()
	buy.name = "Buy_%s" % str(商品.get("id", ""))
	buy.text = "购入"
	buy.custom_minimum_size = Vector2(96, 64)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_gold_gradient(buy)
	UITheme.apply_button_label(buy, true)
	buy.pressed.connect(_on_buy_pressed.bind(商品, buy))
	hb.add_child(buy)

	return panel

func _make_icon_bg(商品: Dictionary) -> PanelContainer:
	var grade: String = str(商品.get("grade", "凡品"))
	var qkey: String = _品阶键(grade)
	var c: Color = UIThemeConfig.get_quality_color(qkey)

	var icon_bg := PanelContainer.new()
	icon_bg.name = "IconBg"
	icon_bg.custom_minimum_size = Vector2(120, 120)
	icon_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.114, 0.141)
	sb.border_color = c
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	sb.set_border_width_all(2)
	icon_bg.add_theme_stylebox_override("panel", sb)

	var center := CenterContainer.new()
	center.name = "IconCenter"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_bg.add_child(center)

	var icon_path: String = str(商品.get("icon", ""))
	var tex: Texture2D = load(icon_path) as Texture2D
	if tex != null:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(72, 72)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = tex
		icon.modulate = c
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)
	else:
		var placeholder := Label.new()
		placeholder.name = "IconPlaceholder"
		placeholder.text = _首字(str(商品.get("name", "—")))
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.apply_section_title(placeholder)
		placeholder.add_theme_color_override("font_color", c)
		center.add_child(placeholder)
	return icon_bg

func _品阶键(grade: String) -> String:
	if grade.contains("凡"): return "fan"
	if grade.contains("灵"): return "ling"
	if grade.contains("宝"): return "bao"
	if grade.contains("王"): return "wang"
	if grade.contains("圣"): return "sheng"
	if grade.contains("仙"): return "xian"
	if grade.contains("道"): return "dao"
	return "fan"

func _首字(文本: String) -> String:
	if 文本.length() > 0:
		return 文本.substr(0, 1)
	return "—"

func _apply_gold_gradient(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.910, 0.773, 0.447)
	normal.set_corner_radius_all(UITheme.RADIUS_PANEL)
	normal.set_content_margin_all(UITheme.GRID)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.788, 0.611, 0.271)
	pressed.set_corner_radius_all(UITheme.RADIUS_PANEL)
	pressed.set_content_margin_all(UITheme.GRID)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("disabled", pressed)
	btn.add_theme_stylebox_override("focus", normal)

func _add_empty(文本: String) -> void:
	var l := Label.new()
	l.name = "EmptyLabel"
	l.text = 文本
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_aux_text(l)
	l.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	_scroll_vbox.add_child(l)

func _确保坊市上架() -> void:
	if not is_instance_valid(Game):
		return
	if not Game.has_method("刷新坊市上架"):
		return
	if Game.坊市上架集.is_empty():
		Game.刷新坊市上架()

func _取灵石坊市在售() -> Array:
	var out: Array = []
	if not is_instance_valid(Game) or not Game.has_method("_坊市表"):
		return out
	var 上架: Array = Game.坊市上架集
	if 上架.is_empty():
		return out
	var 表: Array = Game._坊市表()
	for r in 表:
		var sid: String = str(r.get("shop_id", ""))
		if not 上架.has(sid):
			continue
		var 声望门槛: int = int(r.get("unlock_reputation", "0"))
		var 描述: String = "宗门坊市流通灵物"
		if 声望门槛 > 0:
			描述 = "需声望 %d 解锁" % 声望门槛
		out.append({
			"id": sid,
			"name": str(r.get("item_name", "—")),
			"grade": str(r.get("item_grade", "凡品")),
			"desc": 描述,
			"price_lingjing": int(r.get("price_lingjing", "0")),
			"货币": "灵石",
		})
	return out

func _on_tab_pressed(cat: String) -> void:
	_当前分类 = cat
	_update_tab_styles()
	_populate()

func _on_buy_pressed(商品: Dictionary, btn: Button) -> void:
	if btn != null:
		UITween.button_press(btn)
	var id: String = str(商品.get("id", ""))
	if not is_instance_valid(Game):
		_toast("讯息暂不可查")
		return
	if str(商品.get("货币", "仙玉")) == "灵石":
		if not Game.has_method("购买坊市物品"):
			_toast("坊市功法未就绪")
			return
		var 结果: Dictionary = Game.购买坊市物品(id)
		_toast(str(结果.get("msg", "—")))
	else:
		if not Game.has_method("购买仙玉商品"):
			_toast("讯息暂不可查")
			return
		var 结果: Dictionary = Game.购买仙玉商品(id)
		_toast(str(结果.get("msg", "—")))
	_populate()
	坊市购买完成.emit()

func _on_recharge_pressed() -> void:
	if is_instance_valid(Game) and Game.has_method("toast"):
		Game.toast("充值入口筹备中")

func _toast(文本: String) -> void:
	if _状态标签 != null:
		_状态标签.text = 文本

# ============ 坊市收购（玩家从坊市买入灵物，灵石结算）============
# 展示 game_state 坊市每日特惠 + 常规上架集（坊市上架集），全走 购买坊市物品。
# 与「出售/回购」并列：出售=玩家卖货给坊市、收购=玩家从坊市买货、回购=误售找回。
func _populate_收购() -> void:
	if not is_instance_valid(Game):
		_add_empty("讯息暂不可查")
		return
	_确保坊市上架()
	var 提示: Label = Label.new()
	提示.name = "BuyTip"
	提示.text = "宗门坊市 · 以灵石收购流通灵物（声望折扣 + 行情浮动 + 每日特惠）"
	UITheme.apply_aux_text(提示)
	提示.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	_scroll_vbox.add_child(提示)
	# 每日特惠（game_state 坊市特惠卡，走 购买坊市物品）
	_populate_特惠()
	# 常规上架集（坊市上架集 → 灵石商品卡）
	var 在售: Array = _取灵石坊市在售()
	if 在售.is_empty():
		_add_empty("本周坊市尚无上架灵物，可于集市期间前来采买")
		return
	var 上架标题: Label = Label.new()
	上架标题.name = "ShangjiaTitle"
	上架标题.text = "本周坊市上架"
	UITheme.apply_section_title(上架标题)
	上架标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	_scroll_vbox.add_child(上架标题)
	for p: Dictionary in 在售:
		_scroll_vbox.add_child(_make_product_card(p))

# ============ 坊市经营深化 UI：每日特惠 / 出售 / 回购 ============
func _populate_特惠() -> void:
	if not is_instance_valid(Game) or not Game.has_method("取坊市每日特惠"):
		return
	var 特惠: Array = Game.取坊市每日特惠()
	if 特惠.is_empty():
		return
	var 标题: Label = Label.new()
	标题.name = "TehuiTitle"
	标题.text = "每日特惠 · 限时折扣"
	UITheme.apply_section_title(标题)
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	_scroll_vbox.add_child(标题)
	for t in 特惠:
		var sid: String = str(t.get("shop_id", ""))
		var 倍率: float = float(t.get("倍率", 1.0))
		_scroll_vbox.add_child(_make_特惠_card(sid, 倍率))

func _make_特惠_card(shop_id: String, 倍率: float) -> PanelContainer:
	var 行: Dictionary = {}
	if is_instance_valid(Game) and Game.has_method("_坊市表"):
		for r in Game._坊市表():
			if r.get("shop_id", "") == shop_id:
				行 = r
				break
	var panel := PanelContainer.new()
	panel.name = "Tehui_%s" % shop_id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.094, 0.176, 0.216)
	sb.border_color = UITheme.COLOR_TEXT_GOLD
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.name = "TehuiHBox"
	hb.add_theme_constant_override("separation", UITheme.GRID)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(hb)

	var info := VBoxContainer.new()
	info.name = "TehuiInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	hb.add_child(info)

	var name_lbl := Label.new()
	name_lbl.name = "TehuiName"
	name_lbl.text = str(行.get("item_name", "—"))
	UITheme.apply_body_text(name_lbl)
	info.add_child(name_lbl)

	var 价: int = 0
	if is_instance_valid(Game) and Game.has_method("坊市物品现价"):
		价 = Game.坊市物品现价(shop_id)
	var price := Label.new()
	price.name = "TehuiPrice"
	price.text = "%d 灵石 ·特惠%d折" % [价, int(倍率 * 100)]
	UITheme.apply_value_text(price, false)
	price.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	info.add_child(price)

	var buy := Button.new()
	buy.name = "TehuiBuy_%s" % shop_id
	buy.text = "抢购"
	buy.custom_minimum_size = Vector2(96, 64)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_gold_gradient(buy)
	UITheme.apply_button_label(buy, true)
	buy.pressed.connect(_on_buy_坊市_pressed.bind(shop_id, buy))
	hb.add_child(buy)

	return panel

func _on_buy_坊市_pressed(shop_id: String, btn: Button) -> void:
	if btn != null:
		UITween.button_press(btn)
	if not is_instance_valid(Game) or not Game.has_method("购买坊市物品"):
		_toast("坊市功法未就绪")
		return
	var 结果: Dictionary = Game.购买坊市物品(shop_id)
	_toast(str(结果.get("msg", "—")))
	_populate()
	坊市购买完成.emit()

func _populate_出售() -> void:
	if not is_instance_valid(Game):
		_add_empty("讯息暂不可查")
		return
	var 库: Array = Game.宗门库房
	if 库.is_empty():
		_add_empty("库房空空如也，尚无可出售物品")
		return
	var 提示: Label = Label.new()
	提示.name = "SellTip"
	var 商队率: int = int(Game.商队回收系数 * 100) if is_instance_valid(Game) else 80
	提示.text = "双渠道回收：坊市按市价 60%% 结算（可原价找回）· 商队高价回收（当前 %d%%，不可找回）" % 商队率
	UITheme.apply_aux_text(提示)
	提示.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	_scroll_vbox.add_child(提示)
	for it in 库:
		_scroll_vbox.add_child(_make_出售_card(it))

func _make_出售_card(it: Variant) -> PanelContainer:
	var 名: String = str(it.get("名称", "—"))
	var 坊市价: int = 0
	var 商队价: int = 0
	if is_instance_valid(Game) and Game.has_method("_品阶售价"):
		坊市价 = int(round(float(Game._品阶售价(it)) * 0.6))
		商队价 = int(round(float(Game._品阶售价(it)) * Game.商队回收系数))
	var panel := PanelContainer.new()
	panel.name = "Sell_%s" % 名
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UITheme.COLOR_PANEL_BG
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	panel.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.name = "SellHBox"
	hb.add_theme_constant_override("separation", UITheme.GRID)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(hb)

	var info := VBoxContainer.new()
	info.name = "SellInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	hb.add_child(info)

	var name_lbl := Label.new()
	name_lbl.name = "SellName"
	name_lbl.text = "%s [%s·%s]" % [名, str(it.get("类别", "")), str(it.get("品阶", ""))]
	UITheme.apply_body_text(name_lbl)
	info.add_child(name_lbl)

	var p_坊市 := Label.new()
	p_坊市.name = "SellPriceShop"
	p_坊市.text = "坊市回收 %d 灵石（可找回）" % 坊市价
	UITheme.apply_value_text(p_坊市, false)
	p_坊市.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	info.add_child(p_坊市)

	var p_商队 := Label.new()
	p_商队.name = "SellPriceCaravan"
	p_商队.text = "商队高价 %d 灵石（不可找回）" % 商队价
	UITheme.apply_value_text(p_商队, false)
	p_商队.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	info.add_child(p_商队)

	var btns := VBoxContainer.new()
	btns.name = "SellBtns"
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btns.add_theme_constant_override("separation", 6)
	hb.add_child(btns)

	var btn_坊市 := Button.new()
	btn_坊市.name = "SellShopBtn_%s" % 名
	btn_坊市.text = "售予坊市"
	btn_坊市.custom_minimum_size = Vector2(96, 28)
	_apply_gold_gradient(btn_坊市)
	UITheme.apply_button_label(btn_坊市, true)
	btn_坊市.pressed.connect(_on_sell_pressed.bind(it, btn_坊市))
	btns.add_child(btn_坊市)

	var btn_商队 := Button.new()
	btn_商队.name = "SellCaravanBtn_%s" % 名
	btn_商队.text = "售予商队"
	btn_商队.custom_minimum_size = Vector2(96, 28)
	_apply_gold_gradient(btn_商队)
	UITheme.apply_button_label(btn_商队, true)
	btn_商队.pressed.connect(_on_sell_caravan_pressed.bind(it, btn_商队))
	btns.add_child(btn_商队)

	return panel

func _on_sell_pressed(it: Variant, btn: Button) -> void:
	if btn != null:
		UITween.button_press(btn)
	if not is_instance_valid(Game) or not Game.has_method("出售物品给坊市"):
		_toast("坊市功法未就绪")
		return
	var 结果: Dictionary = Game.出售物品给坊市(it)
	_toast(str(结果.get("msg", "—")))
	_populate()

func _on_sell_caravan_pressed(it: Variant, btn: Button) -> void:
	if btn != null:
		UITween.button_press(btn)
	if not is_instance_valid(Game) or not Game.has_method("出售物品给商队"):
		_toast("商队功法未就绪")
		return
	var 结果: Dictionary = Game.出售物品给商队(it)
	_toast(str(结果.get("msg", "—")))
	_populate()

func _populate_回购() -> void:
	if not is_instance_valid(Game) or not Game.has_method("取坊市回购列表"):
		_add_empty("讯息暂不可查")
		return
	var 表: Array = Game.取坊市回购列表()
	if 表.is_empty():
		_add_empty("尚无误售物品可找回")
		return
	var 提示: Label = Label.new()
	提示.name = "BuyBackTip"
	提示.text = "误售找回 · 按原价买回（最多保留最近 5 件）"
	UITheme.apply_aux_text(提示)
	提示.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	_scroll_vbox.add_child(提示)
	for i in 表.size():
		_scroll_vbox.add_child(_make_回购_card(表[i], i))

func _make_回购_card(e: Dictionary, idx: int) -> PanelContainer:
	var 名: String = str(e.get("名称", "—"))
	var 价: int = int(e.get("价", 0))
	var panel := PanelContainer.new()
	panel.name = "BuyBack_%d" % idx
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UITheme.COLOR_PANEL_BG
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	panel.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.name = "BuyBackHBox"
	hb.add_theme_constant_override("separation", UITheme.GRID)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(hb)

	var info := VBoxContainer.new()
	info.name = "BuyBackInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	hb.add_child(info)

	var name_lbl := Label.new()
	name_lbl.name = "BuyBackName"
	name_lbl.text = "%s [%s·%s]" % [名, str(e.get("类别", "")), str(e.get("品阶", ""))]
	UITheme.apply_body_text(name_lbl)
	info.add_child(name_lbl)

	var price := Label.new()
	price.name = "BuyBackPrice"
	price.text = "原价 %d 灵石" % 价
	UITheme.apply_value_text(price, false)
	price.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	info.add_child(price)

	var btn := Button.new()
	btn.name = "BuyBackBtn_%d" % idx
	btn.text = "买回"
	btn.custom_minimum_size = Vector2(96, 64)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_gold_gradient(btn)
	UITheme.apply_button_label(btn, true)
	btn.pressed.connect(_on_buyback_pressed.bind(idx, btn))
	hb.add_child(btn)

	return panel

func _on_buyback_pressed(idx: int, btn: Button) -> void:
	if btn != null:
		UITween.button_press(btn)
	if not is_instance_valid(Game) or not Game.has_method("买回坊市物品"):
		_toast("坊市功法未就绪")
		return
	var 结果: Dictionary = Game.买回坊市物品(idx)
	_toast(str(结果.get("msg", "—")))
	_populate()

func _on_back_pressed() -> void:
	返回主页.emit()

func _on_skin_shop_pressed() -> void:
	仙衣阁请求.emit()

func _on_master_skin_shop_pressed() -> void:
	宗主仙衣阁请求.emit()




# S1-4 付费：仙玉刷新坊市上架（调用 Game._pay_reserved_坊市购买）
func _on_付费_刷新坊市() -> void:
	if not is_instance_valid(Game):
		return
	var r: Dictionary = Game._pay_reserved_坊市购买()
	if r.get("成功", false):
		UIHint.show_hint(self, "坊市已刷新", "本周上架已重新生成")
	else:
		UIHint.show_hint(self, "仙玉匮乏", str(r.get("原因", "")))
	refresh()

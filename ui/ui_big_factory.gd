extends RefCounted
class_name UIBigFactory

# ===== 大厂标准UI组件工厂 =====
# 对标腾讯/网易顶尖手游的UI组件设计
# 提供统一的卡片、按钮、进度条、标签等组件

# ===== 进度条组件 =====
# 创建大厂风格的进度条
static func create_progress_bar(current: float, max: float, show_text: bool = true, bar_color: Color = Color(0.2, 0.6, 0.9, 1.0)) -> Control:
	var container := VBoxContainer.new()
	container.name = "ProgressBarContainer"
	container.add_theme_constant_override("separation", 4)
	
	if show_text:
		var text_label := Label.new()
		text_label.name = "ProgressText"
		text_label.text = "%d / %d (%.0f%%)" % [int(current), int(max), (current / max(max, 1)) * 100]
		text_label.add_theme_font_size_override("font_size", 14)
		text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
		container.add_child(text_label)
	
	var bar_bg := PanelContainer.new()
	bar_bg.name = "ProgressBarBG"
	bar_bg.custom_minimum_size = Vector2(0, 12)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	bg_style.set_corner_radius_all(6)
	bar_bg.add_theme_stylebox_override("panel", bg_style)
	
	var bar_fill := ColorRect.new()
	bar_fill.name = "ProgressBarFill"
	bar_fill.color = bar_color
	bar_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var progress = clamp(current / max(max, 1), 0.0, 1.0)
	bar_fill.custom_minimum_size = Vector2(progress * 200, 0)  # 临时宽度，实际由布局控制
	bar_bg.add_child(bar_fill)
	
	container.add_child(bar_bg)
	return container

# ===== 折扣标签组件 =====
# 创建大厂风格的折扣标签
static func create_discount_badge(discount_percent: int) -> Control:
	var badge := PanelContainer.new()
	badge.name = "DiscountBadge"
	badge.custom_minimum_size = Vector2(48, 24)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.2, 0.2, 1.0)
	style.set_corner_radius_all(4)
	badge.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.name = "DiscountLabel"
	label.text = "-%d%%" % discount_percent
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	badge.add_child(label)
	
	return badge

# ===== 限时标签组件 =====
# 创建大厂风格的限时标签
static func create_limited_badge(remaining_days: int) -> Control:
	var badge := PanelContainer.new()
	badge.name = "LimitedBadge"
	badge.custom_minimum_size = Vector2(60, 24)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.6, 0.1, 1.0)
	style.set_corner_radius_all(4)
	badge.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.name = "LimitedLabel"
	label.text = "剩%d日" % remaining_days
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	badge.add_child(label)
	
	return badge

# ===== 商品卡片组件 =====
# 创建大厂风格的商品卡片（支持原价、特惠价、折扣标签）
static func create_product_card(商品: Dictionary, 原价: int, 特惠价: int, 折扣百分比: int, on_press: Callable) -> Control:
	var card := PanelContainer.new()
	card.name = "ProductCard"
	card.custom_minimum_size = Vector2(0, 100)
	
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.15, 0.2, 1.0)
	card_style.border_color = Color(0.3, 0.35, 0.4, 1.0)
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
	icon_panel.custom_minimum_size = Vector2(72, 72)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.08, 0.1, 0.15, 1.0)
	icon_style.set_corner_radius_all(8)
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	
	var icon_label := Label.new()
	icon_label.name = "IconLabel"
	icon_label.text = "📦"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 32)
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
	var original_price := Label.new()
	original_price.name = "OriginalPrice"
	original_price.text = "%d" % 原价
	original_price.add_theme_font_size_override("font_size", 14)
	original_price.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
	original_price.add_theme_font_size_override("strikethrough", 1)
	price_hb.add_child(original_price)
	
	# 折扣标签
	if 折扣百分比 > 0:
		var discount_badge = create_discount_badge(折扣百分比)
		price_hb.add_child(discount_badge)
	
	# 购买按钮
	var buy_btn := Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.text = "立即购买"
	buy_btn.custom_minimum_size = Vector2(0, 36)
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	var btn_style_normal := StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.2, 0.5, 0.9, 1.0)
	btn_style_normal.set_corner_radius_all(6)
	buy_btn.add_theme_stylebox_override("normal", btn_style_normal)
	var btn_style_hover := StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.25, 0.55, 0.95, 1.0)
	btn_style_hover.set_corner_radius_all(6)
	buy_btn.add_theme_stylebox_override("hover", btn_style_hover)
	buy_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	buy_btn.add_theme_font_size_override("font_size", 14)
	buy_btn.pressed.connect(on_press)
	info.add_child(buy_btn)
	
	return card

# ===== 礼包卡片组件 =====
# 创建大厂风格的礼包卡片（支持限时活动、原价、活动价）
static func create_gift_card(礼包: Dictionary, 原价: int, 活动价: int, 折扣百分比: int, 剩余天数: int, on_press: Callable) -> Control:
	var card := PanelContainer.new()
	card.name = "GiftCard"
	card.custom_minimum_size = Vector2(0, 120)
	
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.12, 0.2, 1.0)
	card_style.border_color = Color(0.5, 0.3, 0.7, 1.0)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", card_style)
	
	var hb := HBoxContainer.new()
	hb.name = "CardHBox"
	hb.add_theme_constant_override("separation", 12)
	card.add_child(hb)
	
	# 图标区域
	var icon_panel := PanelContainer.new()
	icon_panel.name = "IconPanel"
	icon_panel.custom_minimum_size = Vector2(80, 80)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.1, 0.08, 0.15, 1.0)
	icon_style.set_corner_radius_all(10)
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	
	var icon_label := Label.new()
	icon_label.name = "IconLabel"
	icon_label.text = "🎁"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 40)
	icon_panel.add_child(icon_label)
	hb.add_child(icon_panel)
	
	# 信息区域
	var info := VBoxContainer.new()
	info.name = "InfoVBox"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	hb.add_child(info)
	
	# 礼包名称和限时标签
	var name_hb := HBoxContainer.new()
	name_hb.name = "NameHBox"
	name_hb.add_theme_constant_override("separation", 8)
	info.add_child(name_hb)
	
	var name_label := Label.new()
	name_label.name = "GiftName"
	name_label.text = str(礼包.get("名称", "未知礼包"))
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 1.0, 1.0))
	name_hb.add_child(name_label)
	
	if 剩余天数 > 0:
		var limited_badge = create_limited_badge(剩余天数)
		name_hb.add_child(limited_badge)
	
	# 礼包描述
	var desc_label := Label.new()
	desc_label.name = "GiftDesc"
	desc_label.text = str(礼包.get("描述", ""))
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_label)
	
	# 价格区域
	var price_hb := HBoxContainer.new()
	price_hb.name = "PriceHBox"
	price_hb.add_theme_constant_override("separation", 8)
	info.add_child(price_hb)
	
	# 活动价
	var special_price := Label.new()
	special_price.name = "SpecialPrice"
	special_price.text = "💎 %d" % 活动价
	special_price.add_theme_font_size_override("font_size", 20)
	special_price.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))
	price_hb.add_child(special_price)
	
	# 原价（划线）
	var original_price := Label.new()
	original_price.name = "OriginalPrice"
	original_price.text = "%d" % 原价
	original_price.add_theme_font_size_override("font_size", 14)
	original_price.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
	price_hb.add_child(original_price)
	
	# 折扣标签
	if 折扣百分比 > 0:
		var discount_badge = create_discount_badge(折扣百分比)
		price_hb.add_child(discount_badge)
	
	# 购买按钮
	var buy_btn := Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.text = "立即抢购"
	buy_btn.custom_minimum_size = Vector2(0, 40)
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	var btn_style_normal := StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.7, 0.3, 0.9, 1.0)
	btn_style_normal.set_corner_radius_all(8)
	buy_btn.add_theme_stylebox_override("normal", btn_style_normal)
	var btn_style_hover := StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.75, 0.35, 0.95, 1.0)
	btn_style_hover.set_corner_radius_all(8)
	buy_btn.add_theme_stylebox_override("hover", btn_style_hover)
	buy_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	buy_btn.add_theme_font_size_override("font_size", 16)
	buy_btn.pressed.connect(on_press)
	info.add_child(buy_btn)
	
	return card

# ===== 成就卡片组件 =====
# 创建大厂风格的成就卡片（支持进度条、已达成状态）
static func create_achievement_card(成就: Dictionary, 当前值: float, 目标值: float, 已达成: bool, on_claim: Callable) -> Control:
	var card := PanelContainer.new()
	card.name = "AchievementCard"
	card.custom_minimum_size = Vector2(0, 90)
	
	var card_style := StyleBoxFlat.new()
	if 已达成:
		card_style.bg_color = Color(0.12, 0.18, 0.12, 1.0)
		card_style.border_color = Color(0.3, 0.6, 0.3, 1.0)
	else:
		card_style.bg_color = Color(0.12, 0.15, 0.2, 1.0)
		card_style.border_color = Color(0.3, 0.35, 0.4, 1.0)
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
	if 已达成:
		icon_style.bg_color = Color(0.2, 0.5, 0.2, 1.0)
	else:
		icon_style.bg_color = Color(0.15, 0.18, 0.22, 1.0)
	icon_style.set_corner_radius_all(8)
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	
	var icon_label := Label.new()
	icon_label.name = "IconLabel"
	if 已达成:
		icon_label.text = "🏆"
	else:
		icon_label.text = "🔒"
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
	
	# 成就名称
	var name_label := Label.new()
	name_label.name = "AchievementName"
	name_label.text = str(成就.get("名称", "未知成就"))
	name_label.add_theme_font_size_override("font_size", 16)
	if 已达成:
		name_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
	info.add_child(name_label)
	
	# 成就描述
	var desc_label := Label.new()
	desc_label.name = "AchievementDesc"
	desc_label.text = str(成就.get("描述", ""))
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
	info.add_child(desc_label)
	
	# 进度条
	if not 已达成:
		var progress_bar = create_progress_bar(当前值, 目标值, true, Color(0.3, 0.7, 0.9, 1.0))
		info.add_child(progress_bar)
	else:
		var achieved_label := Label.new()
		achieved_label.name = "AchievedLabel"
		achieved_label.text = "✅ 已达成"
		achieved_label.add_theme_font_size_override("font_size", 14)
		achieved_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))
		info.add_child(achieved_label)
	
	# 领取奖励按钮（已达成但未领取时显示）
	if 已达成:
		var claim_btn := Button.new()
		claim_btn.name = "ClaimButton"
		claim_btn.text = "领取奖励"
		claim_btn.custom_minimum_size = Vector2(0, 32)
		claim_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.9, 0.7, 0.2, 1.0)
		btn_style.set_corner_radius_all(6)
		claim_btn.add_theme_stylebox_override("normal", btn_style)
		claim_btn.add_theme_color_override("font_color", Color(0.2, 0.15, 0.05, 1.0))
		claim_btn.add_theme_font_size_override("font_size", 12)
		claim_btn.pressed.connect(on_claim)
		info.add_child(claim_btn)
	
	return card


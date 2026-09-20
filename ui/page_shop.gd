extends Control

# 坊市页（GameUI 二级页）：宗门交易市场（对齐 Ardot 06 屏「商店：坊市」）。
# 页内按语义分两区：「仙缘阁」= 仙玉商城（XianyuShop 分类）；「坊市」= 灵石交易市场（出售/收购/回购）。
# 分类 Tab / 限时特惠 / 商品卡片 / 底部充值入口；全部字体走 UITheme 角色 helper。
# 购物流程仅调用 Game.购买仙玉商品 / 购买坊市物品，不改数据层既有字段。
signal 坊市购买完成
signal 返回主页
signal 仙衣阁请求
signal 宗主仙衣阁请求

# ★ 2026-09-17 T1：坊市回收比率单一真源（去魔数）；文案「按行价60%作价」保持字面量不变。
const 行价回收比率 := 0.6

var _built: bool = false
# ★ ECON-03 P0-B：默认落点必须是**灵石区**。旧默认「推荐」是仙缘阁（仙玉）分类，
#   打开即满屏仙玉价 ⇒ 造成「坊市全用仙玉买」的信息架构错觉（数据其实一直是灵石）。
var _当前分类: String = "收购"
var _scroll_vbox: VBoxContainer
var _featured_panel: PanelContainer
# ★ 2026-09-15：已放进「今日特供」区的商品 id —— 下方列表须排除它们，
#   否则同屏重复陈列（特供区 4 件 + 列表再原样列一遍）显得"货架很水"。
var _特供id: Dictionary = {}
# ★ 2026-09-17 S2：本页「今日缘法」特惠卡 shop_id —— 「本周坊市上架」列表须排除它们（同屏去重）。
var _特惠id: Dictionary = {}
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
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	var 右侧 := []
	var skin_btn := Button.new()
	skin_btn.name = "SkinShopBtn"
	skin_btn.text = "弟子仙衣"
	skin_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skin_btn.pressed.connect(_on_skin_shop_pressed)
	UITheme.apply_secondary_button_style(skin_btn)
	右侧.append(skin_btn)
	var master_skin_btn := Button.new()
	master_skin_btn.name = "MasterSkinShopBtn"
	master_skin_btn.text = "宗主仙衣"
	master_skin_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	master_skin_btn.pressed.connect(_on_master_skin_shop_pressed)
	UITheme.apply_secondary_button_style(master_skin_btn)
	右侧.append(master_skin_btn)
	var 刷新btn := Button.new()
	刷新btn.name = "PayRefreshMarketBtn"
	刷新btn.text = "刷新坊市"
	if is_instance_valid(Game):
		刷新btn.text = "刷新坊市（%d仙玉）" % Game.付费单价.get("坊市刷新", 5)
	刷新btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	刷新btn.pressed.connect(_on_付费_刷新坊市)
	UITheme.apply_secondary_button_style(刷新btn)
	右侧.append(刷新btn)
	_香火标签 = Label.new()
	_香火标签.name = "XianghuoValue"
	var xianghuo_capsule: PanelContainer = _make_currency_capsule("res://art/icons/resource/res_xianghuo_36.png", _香火标签)
	右侧.append(xianghuo_capsule)
	_仙玉标签 = Label.new()
	_仙玉标签.name = "XianyuValue"
	var xianyu_capsule: PanelContainer = _make_currency_capsule("res://art/icons/resource/res_xianyu_36.png", _仙玉标签)
	右侧.append(xianyu_capsule)
	parent.add_child(UITheme.建顶栏("坊市", _on_back_pressed, 右侧, "坊市", "宗门交易市场：以灵石买卖物资；仙玉珍品另设「仙缘阁」。\n\n· 坊市：灵石交易市场，出售 / 收购 / 回购丹药、法器、材料等物资\n· 仙缘阁：仙玉商城，以仙玉购置灵宝、功法、灵兽、外观等珍稀之物\n· 仙衣阁：弟子与宗主专属皮肤商店"))
func _make_currency_capsule(icon_path: String, out_label: Label) -> PanelContainer:
	var capsule := PanelContainer.new()
	capsule.name = "CurrencyCapsule"
	capsule.custom_minimum_size = Vector2(0, 36)
	capsule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UITheme.获取面板底色()
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(4)
	capsule.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.name = "CapsuleHBox"
	hb.add_theme_constant_override("separation", 4)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	capsule.add_child(hb)

	var tex: Texture2D = (load(icon_path) as Texture2D) if icon_path != "" else null
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(16, 16)
	# 修复（视觉收口 · 2026-09-13）：TextureRect 默认 expand_mode=EXPAND_KEEP_SIZE，
	# 其 get_minimum_size() 返回**贴图原始尺寸**（本项目图标为 512/72 高清图），
	# 会无视 custom_minimum_size 把父容器撑爆 → 图标在屏幕上超大。
	# 全项目 21 个文件均已设此值，本处为漏网。
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
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

# 分类栏分区（X12 一义一名一页）：
#   「仙缘阁」= 仙玉商城（XianyuShop 分类：推荐/灵宝/功法/灵兽/护道/机缘/客卿/符箓/外观）
#   「坊市」  = 灵石交易市场（出售 / 收购 / 回购）
# 二者同页不同语义，分区标注以防「坊市」被误读为仙玉充值商店。
func _build_tabs(parent: Control) -> void:
	_build_tab_group(parent, "仙缘阁", XianyuShop.分类列表, "仙玉")
	_build_tab_group(parent, "坊市", ["出售", "收购", "回购"], "灵石")
	_update_tab_styles()

# 副标只进「区标文字」，不进节点名 —— 节点名带「·」会污染既有 harness 的按名查找，
# 且区标是给玩家看货币归属的唯一线索（两套货币同页，必须一眼分清）。
func _build_tab_group(parent: Control, 区名: String, 分类: Array, 副标: String = "") -> void:
	var 组 := VBoxContainer.new()
	组.name = "TabGroup_" + 区名
	组.add_theme_constant_override("separation", 2)
	var 区标 := Label.new()
	区标.name = "GroupLabel_" + 区名
	区标.text = 区名 if 副标 == "" else "%s · %s" % [区名, 副标]
	UITheme.apply_section_title(区标)
	区标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	组.add_child(区标)
	var bar := HBoxContainer.new()
	bar.name = "CategoryTabs_" + 区名
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	for cat: String in 分类:
		var btn := Button.new()
		btn.name = "Tab_" + cat
		btn.text = cat
		btn.flat = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_tab_pressed.bind(cat))
		_tab_buttons[cat] = btn
		bar.add_child(btn)
	组.add_child(bar)
	parent.add_child(组)

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
		sb.bg_color = UITheme.获取面板底色() if sel else Color(0, 0, 0, 0)
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
	sb.bg_color = UITheme.获取面板底色()
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

	# ★ 2026-09-16（#009 逐页精修）：滚动区底部内边距。原实现滚到底时末卡直接贴住底部
	#   「供奉仙玉」通栏，观感像被裁断。VBoxContainer 的 separation **只作用于相邻子项之间**
	#   （末项之后不加），故只能用一个常驻高垫撑出留白。清空逻辑跳过它，
	#   每轮 populate 后由 _排尾垫() 移回末尾（_populate_impl 有 3 处 early return）。
	var 尾垫: Control = Control.new()
	尾垫.name = "ScrollTailPad"
	尾垫.custom_minimum_size = Vector2(0, int(UITheme.MARGIN * UITheme.UI_SCALE))
	尾垫.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_vbox.add_child(尾垫)

func _build_bottom(parent: Control) -> void:
	var bar := PanelContainer.new()
	bar.name = "BottomBar"
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.122, 0.169, 0.192)
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

# ★ 2026-09-16（#009 逐页精修）：本函数有 3 处 early return（收购/出售/回购），
#   尾垫的「移回末位」无法在内部收口 ⇒ 改为包装：真正实现下沉到 _populate_impl，
#   包装层在任一分支返回后统一重排尾垫。调用方（refresh / _on_tab_pressed）零改动。
func _populate() -> void:
	_populate_impl()
	_排尾垫()

## 把常驻尾垫移回 VBox 末位（见 _build_list 里尾垫的用途）。
func _排尾垫() -> void:
	var 垫: Node = _scroll_vbox.get_node_or_null("ScrollTailPad")
	if 垫 != null:
		_scroll_vbox.move_child(垫, -1)

func _populate_impl() -> void:
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
			# ★ 2026-09-15 改造（老大：「远古传承玉简怎么一直置顶着…能增加更多特价物品更好了，
			#   可以花仙玉刷新。现在没有图标，只有一个钻石样式的 emoji」）
			# 旧链路三条病（机理见 XianyuShop.取每日特供() 上方长注释）：
			#   只出一件（按 shop_id 去重，而 faction_shop.csv 列名是 item_id ⇒ 去重键恒 ""）/
			#   价格恒 0（读 price_lingjing，该表是 price）/ 数据源语义错位（阵营声望商店 ≠ 仙玉商城）。
			# 现改由**仙缘阁自己的商品库**按游戏日轮换 4 件 —— 自带 icon/price，图标与价格天然齐备。
			_特供id = {}
			var 特惠列表: Array = []
			if is_instance_valid(Game) and Game.has_method("取商城特供"):
				特惠列表 = Game.取商城特供()
			else:
				特惠列表 = XianyuShop.取每日特供(0, 4, 0)
			if not 特惠列表.is_empty():
				# 标题行：标题 + 仙玉刷新按钮（老大：「可以花仙玉刷新」）
				var 标题行 := HBoxContainer.new()
				标题行.name = "DailySpecialTitle"
				var title_label := Label.new()
				title_label.text = "今日特供"
				UITheme.apply_project_font(title_label, UITheme.FONT_TITLE, true)
				title_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
				title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				标题行.add_child(title_label)

				var 刷新价: int = 5
				if is_instance_valid(Game):
					刷新价 = Game.商城特供刷新价
				var 刷 := Button.new()
				刷.name = "RefreshTehuiBtn"
				刷.text = "仙玉刷新 · %d" % 刷新价
				刷.custom_minimum_size = Vector2(128, 30)
				刷.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				_apply_gold_gradient(刷)
				UITheme.apply_button_label(刷, true)
				刷.pressed.connect(_on_refresh_特供)
				标题行.add_child(刷)
				_featured_panel.add_child(标题行)
				
				# 每日特惠商品列表
				var 特惠vbox := VBoxContainer.new()
				特惠vbox.name = "DailySpecialVBox"
				特惠vbox.add_theme_constant_override("separation", 8)
				_featured_panel.add_child(特惠vbox)
				
				for p: Dictionary in 特惠列表:
					_特供id[str(p.get("id", ""))] = true
					var 特惠卡 := _make_daily_special_card(p)
					特惠vbox.add_child(_make_daily_special_card(p))
					_卡片淡入(特惠卡)
			else:
				# 原有限时特惠（仙玉商店）
				var featured: Dictionary = XianyuShop.取限时特惠()
				if not featured.is_empty():
					var 特惠主卡 := _make_featured_card(featured)
					_featured_panel.add_child(_make_featured_card(featured))
					_卡片淡入(特惠主卡)
		_featured_panel.visible = (_当前分类 == "推荐") and (_featured_panel.get_child_count() > 0)

	if _scroll_vbox == null:
		return
	for child in _scroll_vbox.get_children():
		# 常驻尾垫（滚动区底部内边距）不参与清空，否则每轮都要重建
		if child.name == "ScrollTailPad":
			continue
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
	# ★ 2026-09-15：推荐 Tab 上方已有「今日特供」区，此处排除其商品 ——
	#   否则同一件货同屏出现两次（特供区 + 列表），货架看着很水。
	if _当前分类 == "推荐" and not _特供id.is_empty():
		var 过滤: Array = []
		for p: Dictionary in list:
			if not _特供id.has(str(p.get("id", ""))):
				过滤.append(p)
		list = 过滤
	if list.is_empty():
		_add_empty("该分类尚无商品")
	else:
		for p: Dictionary in list:
			var 商品卡 := _make_product_card(p)
			_scroll_vbox.add_child(_make_product_card(p))
			_卡片淡入(商品卡)

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
	# ★ 2026-09-16（ECON-03 P1）：仙玉商品透出「灵石等价」，玩家一眼看清硬通货的真实成本（按当日汇率）。
	var 玉价1: int = int(商品.get("price", 0))
	var 等价1: int = Game.仙玉折灵石(玉价1) if (is_instance_valid(Game) and Game.has_method("仙玉折灵石")) else 0
	price.text = ("%d 仙玉（≈%d 灵石）" % [玉价1, 等价1]) if 等价1 > 0 else ("%d 仙玉" % 玉价1)
	UITheme.apply_value_text(price, false)
	price_row.add_child(price)

	var orig := Label.new()
	orig.name = "FeaturedOriginal"
	orig.text = "原值 %d" % int(商品.get("original_price", 0))
	UITheme.apply_aux_text(orig)
	orig.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	price_row.add_child(orig)

	var countdown := Label.new()
	countdown.name = "FeaturedCountdown"
	# ★ 2026-09-15 修：原为硬编码「剩余 02:14:33」——纯演示残留（没有真倒计时逻辑，
	#   老大问「最上面置顶锁定的展示物品干嘛用的」时正是被它误导）。
	#   今日特供按**游戏日**轮换（XianyuShop.取每日特供 以累计游戏日为种子），
	#   故如实写明轮换规则，不再伪造秒级倒计时。
	countdown.text = "存量无多 · 先缘者得"
	UITheme.apply_aux_text(countdown)
	countdown.add_theme_color_override("font_color", Color(0.878, 0.639, 0.243))
	info.add_child(countdown)

	var buy := Button.new()
	buy.name = "FeaturedBuy"
	buy.text = "购入"
	buy.custom_minimum_size = Vector2(96, 64)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_gold_gradient(buy)
	UITheme.apply_button_label(buy, true)
	buy.pressed.connect(_on_buy_pressed.bind(商品, buy))
	hb.add_child(buy)

	return hb

# 大厂标准：每日特惠商品卡片（带原价、特惠价、折扣标签）
## 今日特供卡（2026-09-15 重写）
## 旧版三处毛病，条条都是老大点到的：
##   ① 价格前缀硬编码"钻石 emoji + 数字" —— 老大：「现在没有图标，只有一个钻石样式的 emoji」；
##   ② 图标读 `商品.icon`，而旧数据源 faction_shop.csv **根本没有 icon 列**
##      ⇒ 永远落到"首字"占位（所以看着像"没有图标"）；
##   ③ 版式只有"名字 + 价格"两行，与普通商品卡辨识度拉不开，不像"特供"。
## 现版：左 = 真图标（80×80，品阶色描边）/ 中 = 名称 + 描述 /
##       右 = 仙玉图标 + 现价（打折时才补原价划线 + 折扣角标）/
##       最右 = 购入（**直接复用 _on_buy_pressed** —— 它内部按有无"货币"字段分流
##              购买坊市物品 / 购买仙玉商品，故本卡零经济逻辑、零风险）。
## 入参改为 XianyuShop 商品字典（id / name / price / original_price / icon / desc / grade）。
func _make_daily_special_card(商品: Dictionary) -> Control:
	var 现价: int = int(商品.get("price", 0))
	var 原价: int = int(商品.get("original_price", 0))
	var 折率: int = 0
	if 原价 > 现价 and 原价 > 0:
		折率 = int(round((1.0 - float(现价) / float(原价)) * 100.0))

	var card := PanelContainer.new()
	card.name = "DailySpecial_%s" % str(商品.get("id", ""))
	card.custom_minimum_size = Vector2(0, 96)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.129, 0.176, 0.200)
	sb.border_color = UITheme.COLOR_TEXT_GOLD
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	sb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.name = "TehuiHBox"
	hb.add_theme_constant_override("separation", 10)
	card.add_child(hb)

	# ── 左：真图标（80×80，品阶色描边）──
	var 品色: Color = UIThemeConfig.get_quality_color(_品阶键(str(商品.get("grade", "凡品"))))
	var icon_bg := PanelContainer.new()
	icon_bg.name = "TehuiIconBg"
	icon_bg.custom_minimum_size = Vector2(80, 80)
	icon_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ibs := StyleBoxFlat.new()
	ibs.bg_color = Color(0.122, 0.169, 0.192)
	ibs.border_color = 品色
	ibs.set_corner_radius_all(UITheme.RADIUS_PANEL)
	ibs.set_border_width_all(2)
	icon_bg.add_theme_stylebox_override("panel", ibs)
	var icen := CenterContainer.new()
	icen.name = "TehuiIconCenter"
	icon_bg.add_child(icen)
	var ipath: String = str(商品.get("icon", ""))
	var itex: Texture2D = null
	if ipath != "" and ResourceLoader.exists(ipath):
		itex = load(ipath) as Texture2D
	if itex != null:
		var itr := TextureRect.new()
		itr.name = "TehuiIcon"
		itr.texture = itex
		itr.custom_minimum_size = Vector2(66, 66)
		itr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		itr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		itr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icen.add_child(itr)
	else:
		var ph := Label.new()
		ph.name = "TehuiIconPlaceholder"
		ph.text = _首字(str(商品.get("name", "—")))
		ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.apply_section_title(ph)
		ph.add_theme_color_override("font_color", 品色)
		icen.add_child(ph)
	hb.add_child(icon_bg)

	# ── 中：名称 + 描述 ──
	var info := VBoxContainer.new()
	info.name = "TehuiInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 4)
	hb.add_child(info)

	var nm := Label.new()
	nm.name = "TehuiName"
	nm.text = str(商品.get("name", "—"))
	UITheme.apply_body_text(nm)
	info.add_child(nm)

	var de := Label.new()
	de.name = "TehuiDesc"
	de.text = str(商品.get("desc", ""))
	UITheme.apply_aux_text(de)
	de.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	de.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(de)

	# ── 右：价格列（仙玉图标 + 现价；真打折才补原价划线与折扣角标）──
	var 价列 := VBoxContainer.new()
	价列.name = "TehuiPriceCol"
	价列.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	价列.add_theme_constant_override("separation", 2)
	hb.add_child(价列)

	var 现价行 := HBoxContainer.new()
	现价行.name = "TehuiNowRow"
	现价行.add_theme_constant_override("separation", 2)
	价列.add_child(现价行)

	# 货币图标：原来这里是硬编码 emoji「◇」，现走真实资源图标 res_xianyu_36
	var 玉标 := TextureRect.new()
	玉标.name = "TehuiCoin"
	玉标.texture = UITheme.load_hd_icon("res_xianyu_36")
	玉标.custom_minimum_size = Vector2(18, 18)
	玉标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	玉标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	玉标.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	现价行.add_child(玉标)

	var 现价标 := Label.new()
	现价标.name = "TehuiPrice"
	现价标.text = str(现价)
	UITheme.apply_value_text(现价标, false)
	现价标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	现价行.add_child(现价标)

	if 折率 > 0:
		var 原价标 := Label.new()
		原价标.name = "TehuiOrig"
		原价标.text = "原值 %d" % 原价
		UITheme.apply_aux_text(原价标)
		原价标.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
		价列.add_child(原价标)

		var 角标 := PanelContainer.new()
		角标.name = "TehuiBadge"
		角标.custom_minimum_size = Vector2(46, 20)
		var 角框 := StyleBoxFlat.new()
		角框.bg_color = Color(0.85, 0.20, 0.18)
		角框.set_corner_radius_all(4)
		角标.add_theme_stylebox_override("panel", 角框)
		var 角字 := Label.new()
		角字.name = "TehuiBadgeLabel"
		角字.text = "-%d%%" % 折率
		角字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		角字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.apply_aux_text(角字)
		角字.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		角标.add_child(角字)
		价列.add_child(角标)

	# ── 最右：购入（复用商品卡既有回调，零经济逻辑）──
	var buy := Button.new()
	buy.name = "TehuiBuy_%s" % str(商品.get("id", ""))
	buy.text = "购入"
	buy.custom_minimum_size = Vector2(84, 56)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_gold_gradient(buy)
	UITheme.apply_button_label(buy, true)
	buy.pressed.connect(_on_buy_pressed.bind(商品, buy))
	hb.add_child(buy)

	return card

## 仙玉刷新「今日特供」：扣仙玉换一批
## 抽样逻辑在 Game.仙玉刷新商城特供() → XianyuShop.取每日特供(日, 数量, 偏移)；
## 本回调只负责"调用 + 提示 + 重绘"。
## ★ 2026-09-15：原 _on_daily_special_buy 已删除 —— 它只弹「购买逻辑待接入」的假提示，
##   而购入按钮现走 _on_buy_pressed（真结算）。
func _on_refresh_特供() -> void:
	if not is_instance_valid(Game) or not Game.has_method("仙玉刷新商城特供"):
		_toast("仙缘阁未就绪")
		return
	var 结果: Dictionary = Game.仙玉刷新商城特供()
	_toast(str(结果.get("msg", "—")))
	if bool(结果.get("ok", false)):
		_populate()


func _make_product_card(商品: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Card_%s" % str(商品.get("id", ""))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UITheme.获取面板底色()
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
			price.text += "  ·让利 %d%%" % int(round((1.0 - 特惠倍) * 100))   # PH7-BATCH1E：D5 口径，乘数→让利%
			price.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		else:
			price.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	else:
		# ★ 2026-09-16（ECON-03 P1）：仙玉商品透出「灵石等价」（按当日汇率现算，不落盘）。
		var 玉价2: int = int(商品.get("price", 0))
		var 等价2: int = Game.仙玉折灵石(玉价2) if (is_instance_valid(Game) and Game.has_method("仙玉折灵石")) else 0
		price.text = ("%d 仙玉（≈%d 灵石）" % [玉价2, 等价2]) if 等价2 > 0 else ("%d 仙玉" % 玉价2)
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
	# 2026-09-15（老大定）：商品图标原为 72px 装在 120px 框里 ⇒ 四周一圈 24px 空档，
	# 看着"图标小小一个框空空"。老大要求「放大跟框体一样大」试试观感。
	# 实现走「内缩 4px 边框宽」而非真 120 —— 留 12px 呼吸位，既不顶到品阶色描边，
	# 又让图标占满可视区（原 72→104，放大 1.44 倍）。
	icon_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.122, 0.169, 0.192)
	sb.border_color = c
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	sb.set_border_width_all(2)
	icon_bg.add_theme_stylebox_override("panel", sb)

	var center := CenterContainer.new()
	center.name = "IconCenter"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_bg.add_child(center)

	# ★ 2026-09-15（P0-C）：约定式寻址下 icon 键由 _坊市表() 补齐（已带 exists 判定），
	#   此处再加一道保护 —— 仙缘阁商品（XianyuShop 库）的 icon 是**库里硬写的全路径**，
	#   若哪天库改名而图未同步，这一层能拦住 load() 直抛 "Resource file not found" 的报错刷屏，
	#   静默回退「首字」占位。
	var icon_path: String = str(商品.get("icon", ""))
	var tex: Texture2D = null
	if icon_path != "" and ResourceLoader.exists(icon_path):
		tex = load(icon_path) as Texture2D
	if tex != null:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(104, 104)
		# 修复（视觉收口 · 2026-09-13）：TextureRect 默认 expand_mode=EXPAND_KEEP_SIZE，
		# 其 get_minimum_size() 返回**贴图原始尺寸**（本项目图标为 512/72 高清图），
		# 会无视 custom_minimum_size 把父容器撑爆 → 图标在屏幕上超大。
		# 全项目 21 个文件均已设此值，本处为漏网。
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = tex
		icon.modulate = Color.WHITE   # ★2026-09-15 修正：原为品阶色 c ⇒ 全彩具体图标被整图染成单色块（「图标看着不对」的真因）；品阶语义改由 IconBg 外框 border_color 承载
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
	# ★ 2026-09-16（#009 逐页精修）：空态升级为全项目统一组件（图标位 + 主文案 + 淡入），
	#   消除「整屏只有一行小字」的空白观感。货架类局部空态 ⇒ 紧凑模式。
	_scroll_vbox.add_child(UITheme.建空态(文本, "", "", true))

func _确保坊市上架() -> void:
	if not is_instance_valid(Game):
		return
	if not Game.has_method("刷新坊市上架"):
		return
	if Game.坊市上架集.is_empty():
		Game.刷新坊市上架()
		return
	# ★ 2026-09-15 修：旧存档的 fs_list 可能整批是「列名归一化之前」的空串/失效 id
	#   （上架集非空 ⇒ 原逻辑不重刷），表现为坊市页空、每日特惠全是 0 灵石。
	#   这里做一次自愈：只要有一条对不上现行商品表，就整批重刷（周刷新语义不变）。
	if not Game.has_method("_坊市表"):
		return
	var 有效: Dictionary = {}
	for r in Game._坊市表():
		有效[str(r.get("shop_id", ""))] = true
	for sid in Game.坊市上架集:
		if not 有效.has(str(sid)):
			Game.刷新坊市上架()
			return

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
		# ★ 2026-09-15（P0-C）补 icon 键 —— 本函数是个**手工映射层**（把 _坊市表() 的行重构成
		#   商品卡要的扁平字典）。探针实证：「每日特惠」卡（直接读 _坊市表() 的行）图标正常，
		#   而「本周坊市上架」卡（走本函数）整屏仍是「首字」占位 —— 差别就在这一处：
		#   _坊市表() 里补好的 icon 路径，在重构字典时被丢掉了。
		#   教训：单点补键 ≠ 全链路可达，**中间的手工映射层会静默丢字段**。
		out.append({
			"id": sid,
			"name": str(r.get("item_name", "—")),
			"grade": str(r.get("item_grade", "凡品")),
			"desc": 描述,
			"price_lingjing": int(r.get("price_lingjing", "0")),
			"icon": str(r.get("icon", "")),
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
		Game.添加提示("充值入口筹备中")

func _toast(文本: String) -> void:
	if _状态标签 != null:
		_状态标签.text = 文本
	if is_instance_valid(Game) and Game.has_method("添加提示"):
		Game.添加提示(文本)

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
	提示.text = "宗门坊市 · 以灵石收购流通灵物（声望让利 + 行情浮动 + 今日缘法）"
	UITheme.apply_aux_text(提示)
	提示.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	_scroll_vbox.add_child(提示)

	# 灵种购买（S1：灵田产出消耗灵种）
	var 灵种栏: HBoxContainer = HBoxContainer.new()
	灵种栏.add_theme_constant_override("separation", 10)
	_scroll_vbox.add_child(灵种栏)

	var 灵种信息: Label = Label.new()
	UITheme.apply_body_text(灵种信息)
	灵种信息.text = "灵种存量：%d份（灵田产出必需）" % int(Game.灵种)
	灵种信息.custom_minimum_size = Vector2(200, 32)
	灵种栏.add_child(灵种信息)

	var 买灵种按钮: Button = Button.new()
	买灵种按钮.text = "纳灵种十份（百灵石）"
	买灵种按钮.custom_minimum_size = Vector2(180, 32)
	买灵种按钮.pressed.connect(_on购买灵种)
	UITheme.apply_secondary_button_style(买灵种按钮)
	灵种栏.add_child(买灵种按钮)

	# 灵草/灵米售卖（S1：坊市售卖宗门产出）
	var 售卖栏: HBoxContainer = HBoxContainer.new()
	售卖栏.add_theme_constant_override("separation", 10)
	_scroll_vbox.add_child(售卖栏)

	var 售卖信息: Label = Label.new()
	UITheme.apply_body_text(售卖信息)
	售卖信息.text = "灵草：%d | 灵米：%d" % [int(Game.灵草), int(Game.灵米)]
	售卖信息.custom_minimum_size = Vector2(200, 32)
	售卖栏.add_child(售卖信息)

	var 卖灵草按钮: Button = Button.new()
	卖灵草按钮.text = "售灵草十份（二十灵石）"
	卖灵草按钮.custom_minimum_size = Vector2(160, 32)
	卖灵草按钮.pressed.connect(_on售卖灵草)
	UITheme.apply_secondary_button_style(卖灵草按钮)
	售卖栏.add_child(卖灵草按钮)

	var 卖灵米按钮: Button = Button.new()
	卖灵米按钮.text = "售灵米十份（三十灵石）"
	卖灵米按钮.custom_minimum_size = Vector2(160, 32)
	卖灵米按钮.pressed.connect(_on售卖灵米)
	UITheme.apply_secondary_button_style(卖灵米按钮)
	售卖栏.add_child(卖灵米按钮)

	# 每日特惠（game_state 坊市特惠卡，走 购买坊市物品）
	_populate_特惠()
	# 常规上架集（坊市上架集 → 灵石商品卡）
	var 在售: Array = _取灵石坊市在售()
	# ★ 2026-09-17 S2（V4 同屏去重）：排除「今日缘法」已陈列的 shop_id，避免同件货同屏两次。
	#   注：特惠项键为 `shop_id`，而 `_取灵石坊市在售()` 输出项键为 `id`（值同为 shop_id）
	#   ⇒ 两侧键名不同，按「值」比对（同 `_populate_impl:364-369` 手法）。
	if not _特惠id.is_empty():
		var 过滤: Array = []
		for p: Dictionary in 在售:
			if not _特惠id.has(str(p.get("id", ""))):
				过滤.append(p)
		在售 = 过滤
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
		var 商品卡 := _make_product_card(p)
		_scroll_vbox.add_child(_make_product_card(p))
		_卡片淡入(商品卡)

# ============ 坊市经营深化 UI：每日特惠 / 出售 / 回购 ============
func _populate_特惠() -> void:
	_特惠id = {}
	if not is_instance_valid(Game) or not Game.has_method("取坊市每日特惠"):
		return
	var 特惠: Array = Game.取坊市每日特惠()
	if 特惠.is_empty():
		return
	var 标题: Label = Label.new()
	标题.name = "TehuiTitle"
	标题.text = "今日缘法 · 限时应缘"
	UITheme.apply_section_title(标题)
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	_scroll_vbox.add_child(标题)
	for t in 特惠:
		var sid: String = str(t.get("shop_id", ""))
		_特惠id[sid] = true
		var 倍率: float = float(t.get("倍率", 1.0))
		var 缘法卡 := _make_特惠_card(sid, 倍率)
		_scroll_vbox.add_child(_make_特惠_card(sid, 倍率))
		_卡片淡入(缘法卡)

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
	var sb: StyleBoxFlat = UITheme.make_stylebox_node_units(UITheme.获取面板底色(), UITheme.COLOR_TEXT_GOLD, UITheme.RADIUS_PANEL, 2)
	panel.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.name = "TehuiHBox"
	hb.add_theme_constant_override("separation", UITheme.GRID)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(hb)

	# ── 左：商品图标（★ 2026-09-15 P0-C 接入）──
	# 本卡原先**整行只有文字**（名称 + 价格 + 抢购钮），而同屏的「今日特供」卡有图标 ⇒
	# 一排卡里图文混排 / 纯文字混排，观感断裂。这里补上图标位。
	# 零新增资产：本卡展示的正是 faction_shop 的同一批 shop_id 商品，
	# 直接复用 art/icons/shop/ 那 20 张（经 _坊市表() 的约定式寻址取到 `行["icon"]`）。
	# 尺寸取 80 框 / 66 图标，与「今日特供」卡一致（特供卡在 455~476 行是同样的 80/66）。
	var 特惠图标框 := PanelContainer.new()
	特惠图标框.name = "TehuiIconBg_%s" % shop_id
	特惠图标框.custom_minimum_size = Vector2(80, 80)
	特惠图标框.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ibs2 := UITheme.make_stylebox_node_units(Color(0.122, 0.169, 0.192), UITheme.COLOR_TEXT_GOLD, UITheme.RADIUS_PANEL, 2)
	特惠图标框.add_theme_stylebox_override("panel", ibs2)
	var 特惠图标心 := CenterContainer.new()
	特惠图标心.name = "TehuiIconCenter_%s" % shop_id
	特惠图标框.add_child(特惠图标心)
	var 特惠图路径: String = str(行.get("icon", ""))
	var 特惠贴图: Texture2D = null
	if 特惠图路径 != "" and ResourceLoader.exists(特惠图路径):
		特惠贴图 = load(特惠图路径) as Texture2D
	if 特惠贴图 != null:
		var 特惠图 := TextureRect.new()
		特惠图.name = "TehuiIcon_%s" % shop_id
		特惠图.texture = 特惠贴图
		特惠图.custom_minimum_size = Vector2(66, 66)
		特惠图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		特惠图.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		特惠图.mouse_filter = Control.MOUSE_FILTER_IGNORE
		特惠图标心.add_child(特惠图)
	else:
		var 特惠占位 := Label.new()
		特惠占位.name = "TehuiIconPlaceholder_%s" % shop_id
		特惠占位.text = _首字(str(行.get("item_name", "—")))
		特惠占位.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		特惠占位.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.apply_section_title(特惠占位)
		特惠占位.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		特惠图标心.add_child(特惠占位)
	hb.add_child(特惠图标框)

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
	price.text = "%d 灵石 · 让利 %d%%" % [价, int(round((1.0 - 倍率) * 100))]   # PH7-BATCH1E：D5 口径，乘数→让利%
	UITheme.apply_value_text(price, false)
	price.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	info.add_child(price)

	var buy := Button.new()
	buy.name = "TehuiBuy_%s" % shop_id
	buy.text = "购入"
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
	提示.text = "两途回售：坊市按行价60%作价（可原值赎回）· 商队高价相收（当前 %d%%，赎回无门）" % 商队率
	UITheme.apply_aux_text(提示)
	提示.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	_scroll_vbox.add_child(提示)
	for it in 库:
		var 售卡 := _make_出售_card(it)
		_scroll_vbox.add_child(_make_出售_card(it))
		_卡片淡入(售卡)

func _make_出售_card(it: Variant) -> PanelContainer:
	# ★ 2026-09-16 修（真 bug · 红线⑤同族）：库房元素是 Item（RefCounted，**非字典**），
	#   `.get(k, 默认)` 双参在 Godot 4.7 抛「Expected 1 argument(s)」并**中断本函数**
	#   ⇒ 坊市「出售」页整页卡片建不出来。改单参 .get(key) + null 兜底。
	var v名: Variant = it.get("名称")
	var 名: String = String(v名) if v名 != null else "—"
	var 坊市价: int = 0
	var 商队价: int = 0
	if is_instance_valid(Game) and Game.has_method("_品阶售价"):
		坊市价 = int(round(float(Game._品阶售价(it)) * 行价回收比率))
		商队价 = int(round(float(Game._品阶售价(it)) * Game.商队回收系数))
	var panel := PanelContainer.new()
	panel.name = "Sell_%s" % 名
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UITheme.获取面板底色()
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
	var v类别: Variant = it.get("类别")
	var v品阶: Variant = it.get("品阶")
	name_lbl.text = "%s [%s·%s]" % [名, String(v类别) if v类别 != null else "", String(v品阶) if v品阶 != null else ""]
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
	提示.text = "误售赎回 · 按原值买回（至多存近五件）"
	UITheme.apply_aux_text(提示)
	提示.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	_scroll_vbox.add_child(提示)
	for i in 表.size():
		var 回卡 := _make_回购_card(表[i], i)
		_scroll_vbox.add_child(_make_回购_card(表[i], i))
		_卡片淡入(回卡)

func _make_回购_card(e: Dictionary, idx: int) -> PanelContainer:
	var 名: String = str(e.get("名称", "—"))
	var 价: int = int(e.get("价", 0))
	var panel := PanelContainer.new()
	panel.name = "BuyBack_%d" % idx
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UITheme.获取面板底色()
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
	price.text = "原值 %d 灵石" % 价
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

func _卡片淡入(节点: Control) -> void:
	if 节点 == null or not is_instance_valid(节点):
		return
	节点.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(节点, "modulate:a", 1.0, 0.2)

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


func _on购买灵种() -> void:
	if not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.购买灵种(10)
	if bool(结果.get("成功", false)):
		UIHint.show_hint(self, "购买成功", "灵种+10")
	else:
		UIHint.show_hint(self, "购买失败", str(结果.get("原因", "")))
	refresh()


func _on售卖灵草() -> void:
	if not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.售卖灵草(10)
	if bool(结果.get("成功", false)):
		UIHint.show_hint(self, "售卖成功", "灵石+%d" % int(结果.get("灵石", 0)))
	else:
		UIHint.show_hint(self, "售卖失败", str(结果.get("原因", "")))
	refresh()


func _on售卖灵米() -> void:
	if not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.售卖灵米(10)
	if bool(结果.get("成功", false)):
		UIHint.show_hint(self, "售卖成功", "灵石+%d" % int(结果.get("灵石", 0)))
	else:
		UIHint.show_hint(self, "售卖失败", str(结果.get("原因", "")))
	refresh()

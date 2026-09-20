extends Control
# S54 全服玩家拍卖会UI
# 修真化：聚宝阁全服拍卖大典
# 入口：主界面 → 聚宝阁 → 全服拍卖

signal 返回主页

var _built: bool = false
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _提示: String = ""
var _查看寄拍: bool = false
var _查看历史: bool = false
var _查看委托: bool = false
var _查看成就: bool = false
var _查看皮肤: bool = false
var _查看担保: bool = false
var _查看交割: bool = false

func _ready() -> void:
	_build()
	refresh()

func _enter_tree() -> void:
	if _built:
		refresh.call_deferred()

func _on_back_pressed() -> void:
	返回主页.emit()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content: Control = UITheme.make_scene_background(self)
	_body = VBoxContainer.new()
	_body.name = "Root"
	_body.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_right", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_top", UITheme.GRID)
	_body.add_theme_constant_override("margin_bottom", UITheme.GRID)
	_body.add_theme_constant_override("separation", UITheme.GRID)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(_body)
	_build_header()
	_build_content_area()

func _build_header() -> void:
	var 灵石标: Label = Label.new()
	灵石标.text = "宗门灵石：%d" % Game.灵石
	UITheme.apply_aux_text(灵石标)
	_body.add_child(UITheme.建顶栏("聚宝阁·全服拍卖大典", _on_back_pressed, [灵石标]))

func _build_content_area() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_content)

func refresh() -> void:
	if not _built:
		_build()
	for c in _content.get_children():
		c.queue_free()
	if _提示 != "":
		var 提示: Label = Label.new()
		提示.text = _提示
		提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		提示.add_theme_color_override("font_color", UITheme.color_value(false))
		_content.add_child(提示)
		_提示 = ""
	_populate()

func _card() -> VBoxContainer:
	var p: PanelContainer = PanelContainer.new()
	UITheme.apply_panel_style(p, true)
	_content.add_child(p)
	p.modulate.a = 0.0
	p.create_tween().tween_property(p, "modulate:a", 1.0, 0.25)
	# PanelContainer 自身无子节点，必须先挂 VBox 再返回（原 p.get_child(0) 恒为 null）
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.modulate.a = 0.0
	v.create_tween().tween_property(v, "modulate:a", 1.0, 0.25)
	return v

func _label(文: String, 主: bool) -> Label:
	var l: Label = Label.new()
	l.text = 文
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if 主:
		UITheme.apply_body_text(l)
	else:
		UITheme.apply_aux_text(l)
	return l

func _段标题(文: String) -> void:
	var l: Label = Label.new()
	l.text = 文
	UITheme.apply_body_text(l)
	_content.add_child(l)

func _populate() -> void:
	# 切换栏
	_切换栏()
	if _查看寄拍:
		_寄拍区()
	elif _查看历史:
		_历史区()
	elif _查看委托:
		_委托区()
	elif _查看成就:
		_成就区()
	elif _查看皮肤:
		_皮肤区()
	elif _查看担保:
		_担保区()
	elif _查看交割:
		_交割区()
	else:
		_拍卖状态区()
		# S54 P3：弹幕区
		_弹幕区()
		if Game.全服拍卖系统.获取拍卖状态().get("激活", false):
			_当前拍品区()
			_全部拍品区()
		else:
			_未开启区()

func _切换栏() -> void:
	# 第一行：核心功能
	var 行1: HBoxContainer = HBoxContainer.new()
	行1.add_theme_constant_override("separation", UITheme.GRID / 2)
	# 拍卖大厅
	var 拍卖钮: Button = Button.new()
	var 拍卖选中: bool = (not _查看寄拍) and (not _查看历史) and (not _查看委托) and (not _查看成就) and (not _查看皮肤) and (not _查看担保)
	拍卖钮.text = "◆ 拍卖大厅" if 拍卖选中 else "拍卖大厅"
	拍卖钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	if 拍卖选中:
		UITheme.apply_primary_button_style(拍卖钮)
	else:
		UITheme.apply_secondary_button_style(拍卖钮)
	拍卖钮.pressed.connect(func():
		_查看寄拍 = false; _查看历史 = false; _查看委托 = false
		_查看成就 = false; _查看皮肤 = false; _查看担保 = false
		refresh()
	)
	行1.add_child(拍卖钮)
	# 我的寄拍
	var 寄拍钮: Button = Button.new()
	var 寄拍数: int = Game.全服拍卖系统.获取寄拍列表().size()
	寄拍钮.text = "◆ 寄拍(%d)" % 寄拍数 if _查看寄拍 else "寄拍(%d)" % 寄拍数
	寄拍钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	if _查看寄拍:
		UITheme.apply_primary_button_style(寄拍钮)
	else:
		UITheme.apply_secondary_button_style(寄拍钮)
	寄拍钮.pressed.connect(func():
		_查看寄拍 = true; _查看历史 = false; _查看委托 = false
		_查看成就 = false; _查看皮肤 = false; _查看担保 = false
		refresh()
	)
	行1.add_child(寄拍钮)
	# 委托竞价
	var 委托钮: Button = Button.new()
	var 委托数: int = Game.全服拍卖系统.获取委托列表().size()
	委托钮.text = "◆ 委托(%d)" % 委托数 if _查看委托 else "委托(%d)" % 委托数
	委托钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	if _查看委托:
		UITheme.apply_primary_button_style(委托钮)
	else:
		UITheme.apply_secondary_button_style(委托钮)
	委托钮.pressed.connect(func():
		_查看寄拍 = false; _查看历史 = false; _查看委托 = true
		_查看成就 = false; _查看皮肤 = false; _查看担保 = false
		refresh()
	)
	行1.add_child(委托钮)
	# 历史记录
	var 历史钮: Button = Button.new()
	历史钮.text = "◆ 历史" if _查看历史 else "历史"
	历史钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	if _查看历史:
		UITheme.apply_primary_button_style(历史钮)
	else:
		UITheme.apply_secondary_button_style(历史钮)
	历史钮.pressed.connect(func():
		_查看寄拍 = false; _查看历史 = true; _查看委托 = false
		_查看成就 = false; _查看皮肤 = false; _查看担保 = false
		refresh()
	)
	行1.add_child(历史钮)
	_content.add_child(行1)
	# 第二行：扩展功能
	var 行2: HBoxContainer = HBoxContainer.new()
	行2.add_theme_constant_override("separation", UITheme.GRID / 2)
	# 成就
	var 成就钮: Button = Button.new()
	var 统计: Dictionary = Game.全服拍卖系统.获取拍卖统计()
	成就钮.text = "◆ 成就(%d)" % int(统计.get("成就数", 0)) if _查看成就 else "成就(%d)" % int(统计.get("成就数", 0))
	成就钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	if _查看成就:
		UITheme.apply_primary_button_style(成就钮)
	else:
		UITheme.apply_secondary_button_style(成就钮)
	成就钮.pressed.connect(func():
		_查看寄拍 = false; _查看历史 = false; _查看委托 = false
		_查看成就 = true; _查看皮肤 = false; _查看担保 = false
		refresh()
	)
	行2.add_child(成就钮)
	# 皮肤
	var 皮肤钮: Button = Button.new()
	皮肤钮.text = "◆ 皮肤" if _查看皮肤 else "皮肤"
	皮肤钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	if _查看皮肤:
		UITheme.apply_primary_button_style(皮肤钮)
	else:
		UITheme.apply_secondary_button_style(皮肤钮)
	皮肤钮.pressed.connect(func():
		_查看寄拍 = false; _查看历史 = false; _查看委托 = false
		_查看成就 = false; _查看皮肤 = true; _查看担保 = false
		refresh()
	)
	行2.add_child(皮肤钮)
	# 担保交易
	var 担保钮: Button = Button.new()
	var 担保数: int = Game.全服拍卖系统.获取担保交易列表().size()
	担保钮.text = "◆ 担保(%d)" % 担保数 if _查看担保 else "担保(%d)" % 担保数
	担保钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	if _查看担保:
		UITheme.apply_primary_button_style(担保钮)
	else:
		UITheme.apply_secondary_button_style(担保钮)
	担保钮.pressed.connect(func():
		_查看寄拍 = false; _查看历史 = false; _查看委托 = false
		_查看成就 = false; _查看皮肤 = false; _查看担保 = true; _查看交割 = false
		refresh()
	)
	行2.add_child(担保钮)
	# 交割护送
	var 交割钮: Button = Button.new()
	var 交割数: int = Game.全服拍卖系统.获取待交割列表().size()
	var 护送数: int = Game.全服拍卖系统.获取护送任务列表().size()
	交割钮.text = "◆ 交割(%d)" % (交割数 + 护送数) if _查看交割 else "交割(%d)" % (交割数 + 护送数)
	交割钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	if _查看交割:
		UITheme.apply_primary_button_style(交割钮)
	else:
		UITheme.apply_secondary_button_style(交割钮)
	交割钮.pressed.connect(func():
		_查看寄拍 = false; _查看历史 = false; _查看委托 = false
		_查看成就 = false; _查看皮肤 = false; _查看担保 = false; _查看交割 = true
		refresh()
	)
	行2.add_child(交割钮)
	_content.add_child(行2)

func _拍卖状态区() -> void:
	var 状态: Dictionary = Game.全服拍卖系统.获取拍卖状态()
	var 卡: VBoxContainer = _card()
	var 标题: Label = Label.new()
	var 类型: String = str(状态.get("拍卖类型", "日常"))
	var 类型标: String = ""
	if 类型 == "周末大拍":
		类型标 = "★ 周末大拍"
	elif 类型 == "节日特拍":
		var 节日: String = str(Game.全服拍卖系统.全服拍卖.get("当前节日", ""))
		类型标 = "◆ %s特拍" % 节日
	elif 类型 == "VIP专属":
		类型标 = "◇ 仙阶专属"
	else:
		类型标 = "日常拍卖"
	if 状态.get("激活", false):
		标题.text = "◆ 【%s·进行中】剩余 %d 日 | 第 %d/%d 件" % [类型标, int(状态.get("剩余日", 0)), int(状态.get("当前拍品索引", 0)) + 1, int(状态.get("总拍品数", 0))]
		标题.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4))
	else:
		标题.text = "◆ 【大典未开启】诸位道友可提前寄拍物品"
		标题.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	UITheme.apply_body_text(标题)
	卡.add_child(标题)
	var 说明: Label = Label.new()
	if 状态.get("激活", false):
		if 类型 == "周末大拍":
			说明.text = "★ 周末大拍进行中！宝物翻倍，压轴之物稀世罕见，诸位道友实时竞价，价高者得。"
		elif 类型 == "节日特拍":
			说明.text = "◆ 节日特拍进行中！佳节之际，稀世之宝齐聚，诸位道友共襄盛举！"
		elif 类型 == "VIP专属":
			说明.text = "◇ 仙阶专属拍卖进行中！仅限尊贵道友参与，绝世珍宝唯君可得！"
		else:
			说明.text = "全服拍卖大典正在进行，诸位道友实时竞价，价高者得。最后阶段出价将延时，防止秒杀。"
	else:
		说明.text = "大典每30游戏日开启一次（约2现实小时），每7次日常拍卖后一次周末大拍，节日有特拍，仙阶有专属场。诸位道友可提前寄拍物品。"
	# ★ 2026-09-16 修（#009 逐页精修 · 全服拍卖）：本行原文案长达 60+ 字却**未开 autowrap**
	#   ⇒ 实机截图上直接冲出屏幕右沿被截断（「诸位道…」）。同函数 316 行的话术标本就设了
	#   AUTOWRAP_WORD_SMART，此处属漏设。项目铁律：长文案必须 AUTOWRAP_WORD_SMART。
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说明)
	卡.add_child(说明)
	# 拍卖师话术（进行中显示）
	if 状态.get("激活", false):
		var 话术列表: Array = Game.全服拍卖系统.获取拍卖师话术()
		if not 话术列表.is_empty():
			var 最新话术: Dictionary = 话术列表[-1]
			var 话术标: Label = Label.new()
			话术标.text = "◇ 拍卖师：%s" % str(最新话术.get("话术", ""))
			话术标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			话术标.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
			UITheme.apply_aux_text(话术标)
			卡.add_child(话术标)
	# 观战按钮（进行中显示）
	if 状态.get("激活", false):
		var 观战行: HBoxContainer = HBoxContainer.new()
		观战行.add_theme_constant_override("separation", UITheme.GRID / 2)
		var 观战钮: Button = Button.new()
		var 观战列表: Array = Game.全服拍卖系统.获取观战列表()
		var 在观战: bool = false
		for w in 观战列表:
			if str(w.get("名", "")) == "玩家(宗主)":
				在观战 = true
				break
		观战钮.text = "退出观战" if 在观战 else "加入观战"
		观战钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(观战钮)
		观战钮.pressed.connect(func(): _切换观战())
		观战行.add_child(观战钮)
		var 观战数: Label = Label.new()
		观战数.text = "观战人数：%d" % 观战列表.size()
		UITheme.apply_aux_text(观战数)
		观战行.add_child(观战数)
		卡.add_child(观战行)
	# 拍卖预告（未开启时显示）
	if not 状态.get("激活", false):
		var 预告: Dictionary = Game.全服拍卖系统.获取预告信息()
		if 预告.get("已发布", false):
			var 预告标: Label = Label.new()
			预告标.text = "◆ 拍卖预告："
			预告标.add_theme_color_override("font_color", Color(0.9, 0.5, 0.1))
			UITheme.apply_aux_text(预告标)
			卡.add_child(预告标)
			for p in 预告.get("预告拍品", []):
				var 行: Label = Label.new()
				行.text = "  · [%s] %s（底价%d灵石）" % [str(p.get("品阶", "")), str(p.get("名称", "")), int(p.get("底价", 0))]
				UITheme.apply_aux_text(行)
				卡.add_child(行)
				行.modulate.a = 0.0
				行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
		else:
			# 发布预告按钮
			var 预告钮: Button = Button.new()
			预告钮.text = "发布拍卖预告"
			预告钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(预告钮)
			预告钮.pressed.connect(func(): _发布预告())
			卡.add_child(预告钮)

func _未开启区() -> void:
	var 卡: VBoxContainer = _card()
	var 提示: Label = Label.new()
	提示.text = "拍卖大典尚未开启，诸位道友可前往「寄拍」页面提前寄拍物品。"
	UITheme.apply_body_text(提示)
	卡.add_child(提示)
	var 寄拍钮: Button = Button.new()
	寄拍钮.text = "前往寄拍"
	寄拍钮.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
	UITheme.apply_primary_button_style(寄拍钮)
	寄拍钮.pressed.connect(func():
		_查看寄拍 = true
		refresh()
	)
	卡.add_child(寄拍钮)

func _当前拍品区() -> void:
	var lot: Dictionary = Game.全服拍卖系统.获取当前拍品()
	if lot.is_empty():
		return
	_段标题("◆ 当前拍品")
	_lot_card(lot, true)

func _全部拍品区() -> void:
	_段标题("◆ 全部拍品")
	var 列表: Array = Game.全服拍卖系统.获取拍品列表()
	for lot in 列表:
		if str(lot.get("状态", "")) == "竞拍中":
			_lot_card(lot, false)

func _lot_card(lot: Dictionary, 当前: bool) -> void:
	var 卡: VBoxContainer = _card()
	var it: Item = Item.new()
	it.from_dict(lot.get("物品", {}))
	var 品类: String = str(lot.get("类别", "装备"))
	var 品阶: String = str(lot.get("品阶", ""))
	var 名称: String = str(lot.get("名称", ""))
	var 状态: String = str(lot.get("状态", ""))
	var 是神秘: bool = bool(lot.get("神秘物品", false)) or it.神秘物品
	# 标题
	var 标题: Label = Label.new()
	if 是神秘:
		if 当前:
			标题.text = "？ [未知·神秘] %s" % 名称
			标题.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))
		else:
			标题.text = "？ [未知·神秘] %s" % 名称
			标题.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))
	elif 当前:
		标题.text = "◆ [%s·%s] %s" % [品类, 品阶, 名称]
		标题.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	else:
		标题.text = "[%s·%s] %s" % [品类, 品阶, 名称]
	UITheme.apply_body_text(标题)
	卡.add_child(标题)
	标题.modulate.a = 0.0
	标题.create_tween().tween_property(标题, "modulate:a", 1.0, 0.25)
	# 神秘物品提示
	if 是神秘:
		var 神秘标: Label = Label.new()
		神秘标.text = "◇ 此物无人能识，或为稀世珍宝，或为唬人赝品，全凭慧眼！"
		神秘标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		神秘标.add_theme_color_override("font_color", Color(0.9, 0.6, 0.9))
		UITheme.apply_aux_text(神秘标)
		卡.add_child(神秘标)
		神秘标.modulate.a = 0.0
		神秘标.create_tween().tween_property(神秘标, "modulate:a", 1.0, 0.25)
		# 鉴定按钮
		var 鉴定钮: Button = Button.new()
		var 鉴定费: int = max(100, int(float(lot.get("底价", 1000)) * 0.1))
		鉴定钮.text = "◇ 鉴定(%d灵石)" % 鉴定费
		鉴定钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(鉴定钮)
		鉴定钮.pressed.connect(func():
			var 果: Dictionary = Game.全服拍卖系统.鉴定拍品(str(lot.get("id", "")))
			_提示 = str(果.get("原因", ""))
			refresh()
		)
		卡.add_child(鉴定钮)
		鉴定钮.modulate.a = 0.0
		鉴定钮.create_tween().tween_property(鉴定钮, "modulate:a", 1.0, 0.25)
	# 价格信息
	var 当前价: int = int(lot.get("当前价", 0))
	var 底价: int = int(lot.get("底价", 0))
	var 一口价: int = int(lot.get("一口价", 0))
	var 领先: String = str(lot.get("最高出价者", "（暂无）"))
	var 寄拍者: String = str(lot.get("寄拍者", ""))
	var 价格文: String = "底价 %d ｜ 当前价 %d ｜ 领先：%s ｜ 寄拍者：%s" % [底价, 当前价, 领先, 寄拍者]
	if 一口价 > 0:
		价格文 += " ｜ 一口价 %d" % 一口价
	var _fb1 := _label(价格文, false)
	卡.add_child(_fb1)
	_fb1.modulate.a = 0.0
	_fb1.create_tween().tween_property(_fb1, "modulate:a", 1.0, 0.25)
	# 竞价记录
	var 竞价记录: Array = lot.get("竞价记录", [])
	if 竞价记录.size() > 0:
		var 最近: Array = 竞价记录.slice(max(0, 竞价记录.size() - 3), 竞价记录.size())
		for r in 最近:
			var _fb2 := _label("　· %s 出价 %d" % [str(r.get("出价者", "")), int(r.get("出价", 0))], false)
			卡.add_child(_fb2)
			_fb2.modulate.a = 0.0
			_fb2.create_tween().tween_property(_fb2, "modulate:a", 1.0, 0.25)
	# 出价按钮（仅竞拍中）
	if 状态 == "竞拍中":
		var 行: HBoxContainer = HBoxContainer.new()
		行.add_theme_constant_override("separation", UITheme.GRID / 2)
		var 输入: LineEdit = LineEdit.new()
		var 步进: int = max(10, int(float(当前价) * 0.05))
		输入.placeholder_text = "出价（≥%d）" % (当前价 + 步进)
		输入.custom_minimum_size = Vector2(140, int(round(34.0 * UITheme.UI_SCALE)))
		行.add_child(输入)
		输入.modulate.a = 0.0
		输入.create_tween().tween_property(输入, "modulate:a", 1.0, 0.25)
		var 加价钮: Button = Button.new()
		加价钮.text = "+%d" % 步进
		加价钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(加价钮)
		加价钮.pressed.connect(func():
			输入.text = str(当前价 + 步进)
		)
		行.add_child(加价钮)
		加价钮.modulate.a = 0.0
		加价钮.create_tween().tween_property(加价钮, "modulate:a", 1.0, 0.25)
		var 出价钮: Button = Button.new()
		出价钮.text = "出价"
		出价钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		UITheme.apply_primary_button_style(出价钮)
		出价钮.pressed.connect(func(): _出价(lot, 输入))
		行.add_child(出价钮)
		出价钮.modulate.a = 0.0
		出价钮.create_tween().tween_property(出价钮, "modulate:a", 1.0, 0.25)
		# 一口价按钮
		if 一口价 > 0:
			var 一口价钮: Button = Button.new()
			一口价钮.text = "一口价(%d)" % 一口价
			一口价钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(一口价钮)
			一口价钮.pressed.connect(func(): _一口价(lot))
			行.add_child(一口价钮)
			一口价钮.modulate.a = 0.0
			一口价钮.create_tween().tween_property(一口价钮, "modulate:a", 1.0, 0.25)
		# 委托竞价按钮
		var 委托钮: Button = Button.new()
		委托钮.text = "委托"
		委托钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(委托钮)
		委托钮.pressed.connect(func(): _委托竞价(lot, 输入))
		行.add_child(委托钮)
		委托钮.modulate.a = 0.0
		委托钮.create_tween().tween_property(委托钮, "modulate:a", 1.0, 0.25)
		卡.add_child(行)
		行.modulate.a = 0.0
		行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	elif 状态 == "已成交":
		var 成交: Label = Label.new()
		成交.text = "✓ 已成交：%d灵石，竞得者：%s" % [int(lot.get("成交价", 0)), str(lot.get("竞得者", ""))]
		成交.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4))
		UITheme.apply_aux_text(成交)
		卡.add_child(成交)
		成交.modulate.a = 0.0
		成交.create_tween().tween_property(成交, "modulate:a", 1.0, 0.25)
	elif 状态 == "流拍":
		var 流拍: Label = Label.new()
		流拍.text = "× 流拍：无人应价"
		流拍.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		UITheme.apply_aux_text(流拍)
		卡.add_child(流拍)
		流拍.modulate.a = 0.0
		流拍.create_tween().tween_property(流拍, "modulate:a", 1.0, 0.25)

func _出价(lot: Dictionary, 输入: LineEdit) -> void:
	var 出价: int = int(输入.text)
	var 拍品ID: String = str(lot.get("id", ""))
	var 果: Dictionary = Game.全服拍卖系统.玩家出价(拍品ID, 出价)
	if bool(果.get("成功", false)):
		_提示 = str(果.get("原因", "出价成功"))
	else:
		_提示 = str(果.get("原因", "出价失败"))
	refresh()

func _一口价(lot: Dictionary) -> void:
	var 一口价: int = int(lot.get("一口价", 0))
	var 拍品ID: String = str(lot.get("id", ""))
	var 果: Dictionary = Game.全服拍卖系统.玩家出价(拍品ID, 一口价)
	if bool(果.get("成功", false)):
		_提示 = str(果.get("原因", "一口价成交！"))
	else:
		_提示 = str(果.get("原因", "失败"))
	refresh()

# S54 P1：发布拍卖预告
func _发布预告() -> void:
	var 果: Dictionary = Game.全服拍卖系统.发布拍卖预告()
	if bool(果.get("成功", false)):
		_提示 = "拍卖预告已发布！"
	else:
		_提示 = str(果.get("原因", "发布失败"))
	refresh()

# S54 P1：委托竞价
func _委托竞价(lot: Dictionary, 输入: LineEdit) -> void:
	var 委托价: int = int(输入.text)
	var 拍品ID: String = str(lot.get("id", ""))
	var 果: Dictionary = Game.全服拍卖系统.设置委托竞价(拍品ID, 委托价)
	if bool(果.get("成功", false)):
		_提示 = str(果.get("原因", "委托竞价设置成功"))
	else:
		_提示 = str(果.get("原因", "设置失败"))
	refresh()

# S54 P2：切换观战
func _切换观战() -> void:
	var 观战列表: Array = Game.全服拍卖系统.获取观战列表()
	var 在观战: bool = false
	for w in 观战列表:
		if str(w.get("名", "")) == "玩家(宗主)":
			在观战 = true
			break
	if 在观战:
		Game.全服拍卖系统.退出观战()
		_提示 = "已退出观战"
	else:
		var 果: Dictionary = Game.全服拍卖系统.加入观战()
		_提示 = str(果.get("原因", "加入观战成功"))
	refresh()

# S54 P2：拍卖成就区
func _成就区() -> void:
	_段标题("◆ 拍卖成就")
	var 统计: Dictionary = Game.全服拍卖系统.获取拍卖统计()
	var 统计卡: VBoxContainer = _card()
	统计卡.add_child(_label("累计成交额：%d灵石" % int(统计.get("累计成交额", 0)), true))
	统计卡.add_child(_label("累计成交数：%d件" % int(统计.get("累计成交数", 0)), false))
	统计卡.add_child(_label("累计寄拍数：%d件" % int(统计.get("累计寄拍数", 0)), false))
	统计卡.add_child(_label("已达成成就：%d个" % int(统计.get("成就数", 0)), false))
	var 成就: Dictionary = Game.全服拍卖系统.获取拍卖成就()
	if 成就.is_empty():
		_content.add_child(_label("（暂无成就，继续参与拍卖吧！）", false))
		return
	_段标题("◆ 已达成成就")
	for k in 成就.keys():
		var a: Dictionary = 成就[k]
		var 卡: VBoxContainer = _card()
		var _fb3 := _label("★ %s" % str(k), true)
		卡.add_child(_fb3)
		_fb3.modulate.a = 0.0
		_fb3.create_tween().tween_property(_fb3, "modulate:a", 1.0, 0.25)
		var _fb4 := _label(str(a.get("描述", "")), false)
		卡.add_child(_fb4)
		_fb4.modulate.a = 0.0
		_fb4.create_tween().tween_property(_fb4, "modulate:a", 1.0, 0.25)
		var _fb5 := _label("达成日：第%d日" % int(a.get("日", 0)), false)
		卡.add_child(_fb5)
		_fb5.modulate.a = 0.0
		_fb5.create_tween().tween_property(_fb5, "modulate:a", 1.0, 0.25)

# S54 P3：弹幕区
func _弹幕区() -> void:
	var 弹幕列表: Array = Game.全服拍卖系统.获取弹幕列表()
	if 弹幕列表.is_empty():
		return
	_段标题("◇ 拍卖弹幕")
	var 卡: VBoxContainer = _card()
	# 只显示最近10条
	var 显示数: int = min(10, 弹幕列表.size())
	for i in range(弹幕列表.size() - 显示数, 弹幕列表.size()):
		var d: Dictionary = 弹幕列表[i]
		var 行: Label = Label.new()
		var 类型: String = str(d.get("类型", ""))
		var 前缀: String = ""
		if 类型 == "玩家":
			前缀 = "◇ "
		elif 类型 == "跨服":
			前缀 = "◇ "
		else:
			前缀 = "◇ "
		行.text = "%s%s：%s" % [前缀, str(d.get("发送者", "")), str(d.get("内容", ""))]
		行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if 类型 == "跨服":
			行.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		elif 类型 == "玩家":
			行.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		UITheme.apply_aux_text(行)
		卡.add_child(行)
		行.modulate.a = 0.0
		行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	# 发送弹幕输入框
	var 输入行: HBoxContainer = HBoxContainer.new()
	输入行.add_theme_constant_override("separation", UITheme.GRID / 2)
	var 输入: LineEdit = LineEdit.new()
	输入.placeholder_text = "发送弹幕..."
	输入.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	输入行.add_child(输入)
	var 发送钮: Button = Button.new()
	发送钮.text = "发送"
	发送钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	UITheme.apply_primary_button_style(发送钮)
	发送钮.pressed.connect(func():
		var 果: Dictionary = Game.全服拍卖系统.发送弹幕(输入.text)
		_提示 = str(果.get("原因", ""))
		refresh()
	)
	输入行.add_child(发送钮)
	卡.add_child(输入行)

# S54 P3：皮肤区
func _皮肤区() -> void:
	_段标题("◆ 拍卖皮肤")
	var 皮肤: Dictionary = Game.全服拍卖系统.获取皮肤信息()
	# 当前配置
	var 当前卡: VBoxContainer = _card()
	当前卡.add_child(_label("当前拍卖师：%s" % str(皮肤.get("当前拍卖师", "")), true))
	当前卡.add_child(_label("当前大厅背景：%s" % str(皮肤.get("当前背景", "")), false))
	# 拍卖师列表
	_段标题("◆ 拍卖师")
	for a in 皮肤.get("拍卖师配置", []):
		var 名: String = str(a.get("名", ""))
		var 已解锁: bool = 名 in 皮肤.get("已解锁拍卖师", [])
		var 卡: VBoxContainer = _card()
		var _fb6 := _label("◇ %s" % 名, true)
		卡.add_child(_fb6)
		_fb6.modulate.a = 0.0
		_fb6.create_tween().tween_property(_fb6, "modulate:a", 1.0, 0.25)
		var _fb7 := _label(str(a.get("描述", "")), false)
		卡.add_child(_fb7)
		_fb7.modulate.a = 0.0
		_fb7.create_tween().tween_property(_fb7, "modulate:a", 1.0, 0.25)
		var _fb8 := _label("解锁条件：%s" % str(a.get("解锁条件", "")), false)
		卡.add_child(_fb8)
		_fb8.modulate.a = 0.0
		_fb8.create_tween().tween_property(_fb8, "modulate:a", 1.0, 0.25)
		if 已解锁:
			var 切换钮: Button = Button.new()
			切换钮.text = "使用中" if str(皮肤.get("当前拍卖师", "")) == 名 else "切换"
			切换钮.custom_minimum_size = Vector2(0, int(round(30.0 * UITheme.UI_SCALE)))
			if str(皮肤.get("当前拍卖师", "")) == 名:
				UITheme.apply_primary_button_style(切换钮)
			else:
				UITheme.apply_secondary_button_style(切换钮)
				切换钮.pressed.connect(func():
					Game.全服拍卖系统.切换拍卖师(名)
					_提示 = "已切换拍卖师：%s" % 名
					refresh()
				)
			卡.add_child(切换钮)
			切换钮.modulate.a = 0.0
			切换钮.create_tween().tween_property(切换钮, "modulate:a", 1.0, 0.25)
		else:
			var 价格: int = int(a.get("价格", 0))
			var 解锁钮: Button = Button.new()
			解锁钮.text = "解锁(%d灵石)" % 价格
			解锁钮.custom_minimum_size = Vector2(0, int(round(30.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(解锁钮)
			解锁钮.pressed.connect(func():
				var 果: Dictionary = Game.全服拍卖系统.解锁拍卖师(名)
				_提示 = str(果.get("原因", ""))
				refresh()
			)
			卡.add_child(解锁钮)
			解锁钮.modulate.a = 0.0
			解锁钮.create_tween().tween_property(解锁钮, "modulate:a", 1.0, 0.25)
	# 大厅背景列表
	_段标题("◆ 大厅背景")
	for b in 皮肤.get("背景配置", []):
		var 名: String = str(b.get("名", ""))
		var 已解锁: bool = 名 in 皮肤.get("已解锁背景", [])
		var 卡: VBoxContainer = _card()
		var _fb9 := _label("◇ %s" % 名, true)
		卡.add_child(_fb9)
		_fb9.modulate.a = 0.0
		_fb9.create_tween().tween_property(_fb9, "modulate:a", 1.0, 0.25)
		var _fb10 := _label(str(b.get("描述", "")), false)
		卡.add_child(_fb10)
		_fb10.modulate.a = 0.0
		_fb10.create_tween().tween_property(_fb10, "modulate:a", 1.0, 0.25)
		var _fb11 := _label("解锁条件：%s" % str(b.get("解锁条件", "")), false)
		卡.add_child(_fb11)
		_fb11.modulate.a = 0.0
		_fb11.create_tween().tween_property(_fb11, "modulate:a", 1.0, 0.25)
		if 已解锁:
			var 切换钮: Button = Button.new()
			切换钮.text = "使用中" if str(皮肤.get("当前背景", "")) == 名 else "切换"
			切换钮.custom_minimum_size = Vector2(0, int(round(30.0 * UITheme.UI_SCALE)))
			if str(皮肤.get("当前背景", "")) == 名:
				UITheme.apply_primary_button_style(切换钮)
			else:
				UITheme.apply_secondary_button_style(切换钮)
				切换钮.pressed.connect(func():
					Game.全服拍卖系统.切换背景(名)
					_提示 = "已切换背景：%s" % 名
					refresh()
				)
			卡.add_child(切换钮)
			切换钮.modulate.a = 0.0
			切换钮.create_tween().tween_property(切换钮, "modulate:a", 1.0, 0.25)
		else:
			var 价格: int = int(b.get("价格", 0))
			var 解锁钮: Button = Button.new()
			解锁钮.text = "解锁(%d灵石)" % 价格
			解锁钮.custom_minimum_size = Vector2(0, int(round(30.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(解锁钮)
			解锁钮.pressed.connect(func():
				var 果: Dictionary = Game.全服拍卖系统.解锁背景(名)
				_提示 = str(果.get("原因", ""))
				refresh()
			)
			卡.add_child(解锁钮)
			解锁钮.modulate.a = 0.0
			解锁钮.create_tween().tween_property(解锁钮, "modulate:a", 1.0, 0.25)

# S54 P3：担保交易区
func _担保区() -> void:
	_段标题("◆ 担保交易")
	var 说明: Label = Label.new()
	说明.text = "担保交易：玩家间直接交易，聚宝阁担保，收取5%担保费。物品暂存聚宝阁，买家确认后完成交易。"
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说明)
	_content.add_child(说明)
	# 发起担保交易
	_段标题("◆ 发起担保交易")
	var 发起卡: VBoxContainer = _card()
	发起卡.add_child(_label("选择库房物品发起担保交易（未认主物品可交易）", false))
	# 显示可交易物品
	var 可交易: Array = []
	for it in Game.宗门库房:
		if it.是否可交易():
			可交易.append(it)
	if 可交易.is_empty():
		发起卡.add_child(_label("（库房暂无可交易物品）", false))
	else:
		for it in 可交易:
			var 行: HBoxContainer = HBoxContainer.new()
			行.add_theme_constant_override("separation", UITheme.GRID / 2)
			var 名标: Label = Label.new()
			名标.text = "[%s] %s" % [str(it.品阶), str(it.名称)]
			名标.custom_minimum_size = Vector2(200, 0)
			UITheme.apply_body_text(名标)
			行.add_child(名标)
			名标.modulate.a = 0.0
			名标.create_tween().tween_property(名标, "modulate:a", 1.0, 0.25)
			var 价格输入: LineEdit = LineEdit.new()
			价格输入.placeholder_text = "价格"
			价格输入.custom_minimum_size = Vector2(80, int(round(28.0 * UITheme.UI_SCALE)))
			行.add_child(价格输入)
			价格输入.modulate.a = 0.0
			价格输入.create_tween().tween_property(价格输入, "modulate:a", 1.0, 0.25)
			var 发起钮: Button = Button.new()
			发起钮.text = "发起"
			发起钮.custom_minimum_size = Vector2(0, int(round(28.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(发起钮)
			发起钮.pressed.connect(func():
				var 价格: int = int(价格输入.text)
				var 买家: String = "AI买家·%s" % ["散修", "商会", "宗门"][randi() % 3]
				var 果: Dictionary = Game.全服拍卖系统.发起担保交易(it, 价格, 买家)
				_提示 = str(果.get("原因", ""))
				refresh()
			)
			行.add_child(发起钮)
			发起钮.modulate.a = 0.0
			发起钮.create_tween().tween_property(发起钮, "modulate:a", 1.0, 0.25)
			发起卡.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	# 担保交易列表
	_段标题("◆ 担保交易记录")
	var 交易列表: Array = Game.全服拍卖系统.获取担保交易列表()
	if 交易列表.is_empty():
		_content.add_child(_label("（暂无担保交易）", false))
		return
	for t in 交易列表:
		var 卡: VBoxContainer = _card()
		var 状态: String = str(t.get("状态", ""))
		var 状态色: Color = Color(0.2, 0.8, 0.4) if 状态 == "已完成" else (Color(1.0, 0.5, 0.0) if 状态 == "担保中" else Color(0.6, 0.6, 0.6))
		var _fb12 := _label("[%s] %s ｜ 价格：%d灵石 ｜ 状态：%s" % [str(t.get("物品名", "")), str(t.get("买家", "")), int(t.get("价格", 0)), 状态], true)
		卡.add_child(_fb12)
		_fb12.modulate.a = 0.0
		_fb12.create_tween().tween_property(_fb12, "modulate:a", 1.0, 0.25)
		var _fb13 := _label("担保费：%d灵石 ｜ 发起日：第%d日" % [int(t.get("担保费", 0)), int(t.get("发起日", 0))], false)
		卡.add_child(_fb13)
		_fb13.modulate.a = 0.0
		_fb13.create_tween().tween_property(_fb13, "modulate:a", 1.0, 0.25)
		if 状态 == "担保中":
			var 行: HBoxContainer = HBoxContainer.new()
			行.add_theme_constant_override("separation", UITheme.GRID / 2)
			var 确认钮: Button = Button.new()
			确认钮.text = "模拟买家确认"
			确认钮.custom_minimum_size = Vector2(0, int(round(28.0 * UITheme.UI_SCALE)))
			UITheme.apply_primary_button_style(确认钮)
			确认钮.pressed.connect(func():
				var 果: Dictionary = Game.全服拍卖系统.确认担保交易(str(t.get("id", "")))
				_提示 = str(果.get("原因", ""))
				refresh()
			)
			行.add_child(确认钮)
			确认钮.modulate.a = 0.0
			确认钮.create_tween().tween_property(确认钮, "modulate:a", 1.0, 0.25)
			var 取消钮: Button = Button.new()
			取消钮.text = "取消交易"
			取消钮.custom_minimum_size = Vector2(0, int(round(28.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(取消钮)
			取消钮.pressed.connect(func():
				var 果: Dictionary = Game.全服拍卖系统.取消担保交易(str(t.get("id", "")))
				_提示 = str(果.get("原因", ""))
				refresh()
			)
			行.add_child(取消钮)
			取消钮.modulate.a = 0.0
			取消钮.create_tween().tween_property(取消钮, "modulate:a", 1.0, 0.25)
			卡.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)

# S54 P5：交割护送区
func _交割区() -> void:
	_段标题("◆ 交割与护送")
	var 说明: Label = Label.new()
	说明.text = "修真界交割宝物需谨慎：当场交割可能被魔道修士盯上；委托聚宝阁高手护送安全但需交费；自行带回风险自担。"
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说明)
	_content.add_child(说明)
	# 待交割列表
	_段标题("◆ 待交割物品")
	var 待交割: Array = Game.全服拍卖系统.获取待交割列表()
	var 有待交割: bool = false
	for d in 待交割:
		if str(d.get("状态", "")) == "待交割":
			有待交割 = true
			var 卡: VBoxContainer = _card()
			var 被盯上: bool = bool(d.get("被盯上", false))
			var 风险: int = int(d.get("打劫风险", 0))
			var _fb14 := _label("[%s] %s ｜ 成交价：%d灵石" % [str(d.get("品阶", "")), str(d.get("物品名", "")), int(d.get("成交价", 0))], true)
			卡.add_child(_fb14)
			_fb14.modulate.a = 0.0
			_fb14.create_tween().tween_property(_fb14, "modulate:a", 1.0, 0.25)
			if 被盯上:
				var 警告: Label = Label.new()
				警告.text = "⚠ 此物品阶太高，已被魔道修士盯上！打劫风险%d%%" % 风险
				警告.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				UITheme.apply_aux_text(警告)
				卡.add_child(警告)
				警告.modulate.a = 0.0
				警告.create_tween().tween_property(警告, "modulate:a", 1.0, 0.25)
			# 交割方式选择
			var 行: HBoxContainer = HBoxContainer.new()
			行.add_theme_constant_override("separation", UITheme.GRID / 2)
			# 当场交割
			var 当场钮: Button = Button.new()
			当场钮.text = "当场交割"
			当场钮.custom_minimum_size = Vector2(0, int(round(28.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(当场钮)
			当场钮.pressed.connect(func():
				var 果: Dictionary = Game.全服拍卖系统.选择交割方式(str(d.get("id", "")), "当场交割")
				_提示 = str(果.get("原因", ""))
				refresh()
			)
			行.add_child(当场钮)
			当场钮.modulate.a = 0.0
			当场钮.create_tween().tween_property(当场钮, "modulate:a", 1.0, 0.25)
			# 委托护送（选择境界）
			var 护送选择: OptionButton = OptionButton.new()
			护送选择.custom_minimum_size = Vector2(0, int(round(28.0 * UITheme.UI_SCALE)))
			var 境界列表: Array = Game.全服拍卖系统.获取护送境界列表()
			for g in 境界列表:
				var 费: int = Game.全服拍卖系统.计算护送费(int(d.get("成交价", 0)), str(g.get("境界", "")))
				护送选择.add_item("%s(%d灵石·%s)" % [str(g.get("境界", "")), 费, str(g.get("安全度", ""))])
			行.add_child(护送选择)
			护送选择.modulate.a = 0.0
			护送选择.create_tween().tween_property(护送选择, "modulate:a", 1.0, 0.25)
			var 护送钮: Button = Button.new()
			护送钮.text = "委托护送"
			护送钮.custom_minimum_size = Vector2(0, int(round(28.0 * UITheme.UI_SCALE)))
			UITheme.apply_primary_button_style(护送钮)
			护送钮.pressed.connect(func():
				var 选境界: String = str(境界列表[护送选择.selected].get("境界", "金丹期"))
				var 果: Dictionary = Game.全服拍卖系统.选择交割方式(str(d.get("id", "")), "委托护送", 选境界)
				_提示 = str(果.get("原因", ""))
				refresh()
			)
			行.add_child(护送钮)
			护送钮.modulate.a = 0.0
			护送钮.create_tween().tween_property(护送钮, "modulate:a", 1.0, 0.25)
			# 自行带回
			var 自行钮: Button = Button.new()
			自行钮.text = "自行带回"
			自行钮.custom_minimum_size = Vector2(0, int(round(28.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(自行钮)
			自行钮.pressed.connect(func():
				var 果: Dictionary = Game.全服拍卖系统.选择交割方式(str(d.get("id", "")), "自行带回")
				_提示 = str(果.get("原因", ""))
				refresh()
			)
			行.add_child(自行钮)
			自行钮.modulate.a = 0.0
			自行钮.create_tween().tween_property(自行钮, "modulate:a", 1.0, 0.25)
			卡.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	if not 有待交割:
		_content.add_child(_label("（暂无待交割物品）", false))
	# 护送中任务
	_段标题("◆ 护送中")
	var 护送列表: Array = Game.全服拍卖系统.获取护送任务列表()
	var 有护送: bool = false
	for t in 护送列表:
		if str(t.get("状态", "")) == "护送中":
			有护送 = true
			var 卡: VBoxContainer = _card()
			var 剩余日: int = max(0, int(t.get("到达日", 0)) - int(Game.累计游戏日))
			var _fb15 := _label("[%s] ｜ 护送者：%s" % [str(t.get("物品名", "")), str(t.get("护送高手", ""))], true)
			卡.add_child(_fb15)
			_fb15.modulate.a = 0.0
			_fb15.create_tween().tween_property(_fb15, "modulate:a", 1.0, 0.25)
			var _fb16 := _label("预计%d日后送达 ｜ 护送费：%d灵石" % [剩余日, int(t.get("护送费", 0))], false)
			卡.add_child(_fb16)
			_fb16.modulate.a = 0.0
			_fb16.create_tween().tween_property(_fb16, "modulate:a", 1.0, 0.25)
	if not 有护送:
		_content.add_child(_label("（暂无护送差事）", false))
	# 打劫记录
	_段标题("◆ 打劫记录")
	var 打劫记录: Array = Game.全服拍卖系统.获取打劫记录()
	if 打劫记录.is_empty():
		_content.add_child(_label("（暂无打劫记录）", false))
	else:
		for r in 打劫记录.slice(max(0, 打劫记录.size() - 5), 打劫记录.size()):
			var 卡: VBoxContainer = _card()
			var 被打劫: bool = bool(r.get("被打劫", false))
			var 结果: String = str(r.get("结果", ""))
			var 结果色: Color = Color(0.2, 0.8, 0.4) if 结果 == "击退" or 结果 == "躲过" else (Color(1.0, 0.3, 0.3) if 结果 == "被抢" else Color(0.6, 0.6, 0.6))
			var _fb17 := _label("%s ｜ %s ｜ 第%d日" % [str(r.get("物品", "")), 结果, int(r.get("日", 0))], true)
			卡.add_child(_fb17)
			_fb17.modulate.a = 0.0
			_fb17.create_tween().tween_property(_fb17, "modulate:a", 1.0, 0.25)
			if 被打劫 and str(r.get("打劫者", "")) != "":
				var _fb18 := _label("打劫者：%s" % str(r.get("打劫者", "")), false)
				卡.add_child(_fb18)
				_fb18.modulate.a = 0.0
				_fb18.create_tween().tween_property(_fb18, "modulate:a", 1.0, 0.25)
	# 玩家打劫NPC（可选玩法）
	_段标题("◆ 黑吃黑（打劫NPC）")
	var 黑吃黑说明: Label = Label.new()
	黑吃黑说明.text = "修真界弱肉强食，亦可打劫其他竞拍者。但此举有损正道声望，且有失败风险。"
	黑吃黑说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	黑吃黑说明.add_theme_color_override("font_color", Color(0.9, 0.5, 0.1))
	UITheme.apply_aux_text(黑吃黑说明)
	_content.add_child(黑吃黑说明)
	var 打劫钮: Button = Button.new()
	打劫钮.text = "◆ 寻找目标打劫"
	打劫钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	UITheme.apply_secondary_button_style(打劫钮)
	打劫钮.pressed.connect(func():
		var 果: Dictionary = Game.全服拍卖系统.玩家打劫NPC("")
		_提示 = str(果.get("原因", ""))
		refresh()
	)
	_content.add_child(打劫钮)

func _寄拍区() -> void:
	_段标题("◆ 我的寄拍（待开拍）")
	var 寄拍列表: Array = Game.全服拍卖系统.获取寄拍列表()
	if 寄拍列表.is_empty():
		_content.add_child(_label("（暂无寄拍物品）", false))
	else:
		for lot in 寄拍列表:
			var 卡: VBoxContainer = _card()
			var it: Item = Item.new()
			it.from_dict(lot.get("物品", {}))
			var _fb19 := _label("[%s·%s] %s" % [str(lot.get("类别", "")), str(lot.get("品阶", "")), str(lot.get("名称", ""))], true)
			卡.add_child(_fb19)
			_fb19.modulate.a = 0.0
			_fb19.create_tween().tween_property(_fb19, "modulate:a", 1.0, 0.25)
			var _fb20 := _label("底价：%d ｜ 一口价：%d ｜ 栈租：%d" % [int(lot.get("底价", 0)), int(lot.get("一口价", 0)), int(lot.get("栈租", 0))], false)
			卡.add_child(_fb20)
			_fb20.modulate.a = 0.0
			_fb20.create_tween().tween_property(_fb20, "modulate:a", 1.0, 0.25)
	# 寄拍按钮
	_段标题("◆ 寄拍新物品")
	if Game.宗门库房.is_empty():
		_content.add_child(_label("（宗门库房为空）", false))
	else:
		var 卡: VBoxContainer = _card()
		卡.add_child(_label("选择要寄拍的物品（未认主物品可寄拍）", false))
		var 物品选项: OptionButton = OptionButton.new()
		for i in range(Game.宗门库房.size()):
			var it: Item = Game.宗门库房[i]
			if it.是否可交易():
				物品选项.add_item("[%s] %s" % [it.品阶, it.名称])
		if 物品选项.item_count == 0:
			卡.add_child(_label("（没有可寄拍的物品，认主物品不可寄拍）", false))
		else:
			# ★ 2026-09-16 修（孤儿节点 · 真功能缺陷）：原实现建了「物品选项」并逐项 add_item()，
			#   却**从未 add_child()** ⇒ 玩家根本看不到选物品的下拉框，
			#   而 _寄拍物品() 读 `物品选项.selected` 恒为 -1 ⇒ 永远提示「请选择物品」，寄拍流程实际走不通。
			卡.add_child(物品选项)
			var 底价输入: LineEdit = LineEdit.new()
			底价输入.placeholder_text = "底价（灵石）"
			底价输入.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
			卡.add_child(底价输入)
			var 一口价输入: LineEdit = LineEdit.new()
			一口价输入.placeholder_text = "一口价（可选，0=不设）"
			一口价输入.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
			卡.add_child(一口价输入)
			# 寄拍时长选择
			var 时长行: HBoxContainer = HBoxContainer.new()
			时长行.add_theme_constant_override("separation", UITheme.GRID / 2)
			var 时长标签: Label = Label.new()
			时长标签.text = "寄拍时长："
			UITheme.apply_aux_font(时长标签)
			时长行.add_child(时长标签)
			var 时长选项: OptionButton = OptionButton.new()
			时长选项.add_item("7日（栈租×0.5）")
			时长选项.add_item("1月（标准）")
			时长选项.add_item("3月（栈租×2）")
			时长选项.add_item("6月（栈租×3）")
			时长选项.select(1)  # 默认1月
			时长行.add_child(时长选项)
			卡.add_child(时长行)
			var 寄拍钮: Button = Button.new()
			寄拍钮.text = "确认寄拍（栈租5%）"
			寄拍钮.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
			UITheme.apply_primary_button_style(寄拍钮)
			寄拍钮.pressed.connect(func(): _寄拍物品(物品选项, 底价输入, 一口价输入, 时长选项))
			卡.add_child(寄拍钮)

func _寄拍物品(物品选项: OptionButton, 底价输入: LineEdit, 一口价输入: LineEdit, 时长选项: OptionButton) -> void:
	var 索引: int = 物品选项.selected
	if 索引 < 0:
		_提示 = "请选择物品"
		refresh()
		return
	# 找到可交易物品的真实索引
	var 可交易索引: int = 0
	var 真实索引: int = -1
	for i in range(Game.宗门库房.size()):
		var it: Item = Game.宗门库房[i]
		if it.是否可交易():
			if 可交易索引 == 索引:
				真实索引 = i
				break
			可交易索引 += 1
	if 真实索引 < 0:
		_提示 = "物品索引无效"
		refresh()
		return
	var 底价: int = int(底价输入.text)
	var 一口价: int = int(一口价输入.text)
	var 时长列表: Array = ["7日", "1月", "3月", "6月"]
	var 时长: String = 时长列表[时长选项.selected] if 时长选项.selected >= 0 and 时长选项.selected < 时长列表.size() else "1月"
	var 果: Dictionary = Game.全服拍卖系统.玩家寄拍(真实索引, 底价, 一口价, 时长)
	if bool(果.get("成功", false)):
		_提示 = str(果.get("原因", "寄拍成功"))
	else:
		_提示 = str(果.get("原因", "寄拍失败"))
	refresh()

func _历史区() -> void:
	_段标题("◆ 历史成交记录")
	var 历史: Array = Game.全服拍卖系统.获取历史记录()
	if 历史.is_empty():
		_content.add_child(_label("（暂无历史记录）", false))
		return
	for r in 历史:
		var 卡: VBoxContainer = _card()
		var _fb21 := _label("[%s] %s" % [str(r.get("品阶", "")), str(r.get("名称", ""))], true)
		卡.add_child(_fb21)
		_fb21.modulate.a = 0.0
		_fb21.create_tween().tween_property(_fb21, "modulate:a", 1.0, 0.25)
		var _fb22 := _label("成交价：%d灵石 ｜ 竞得者：%s ｜ 第%d日" % [int(r.get("成交价", 0)), str(r.get("竞得者", "")), int(r.get("日", 0))], false)
		卡.add_child(_fb22)
		_fb22.modulate.a = 0.0
		_fb22.create_tween().tween_property(_fb22, "modulate:a", 1.0, 0.25)
		# 竞价记录详情
		var 竞价记录: Array = r.get("竞价记录", [])
		if not 竞价记录.is_empty():
			var _fb23 := _label("竞价记录：", false)
			卡.add_child(_fb23)
			_fb23.modulate.a = 0.0
			_fb23.create_tween().tween_property(_fb23, "modulate:a", 1.0, 0.25)
			for b in 竞价记录:
				var _fb24 := _label("  · %s 出价 %d灵石（第%d日）" % [str(b.get("出价者", "")), int(b.get("出价", 0)), int(b.get("日", 0))], false)
				卡.add_child(_fb24)
				_fb24.modulate.a = 0.0
				_fb24.create_tween().tween_property(_fb24, "modulate:a", 1.0, 0.25)

# S54 P1：委托竞价区
func _委托区() -> void:
	_段标题("◆ 委托竞价")
	var 说明: Label = Label.new()
	说明.text = "设置委托价后，离线时系统将自动为您出价，最高不超过委托价。委托期间灵石将被冻结，取消委托后返还。"
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说明)
	_content.add_child(说明)
	var 委托列表: Array = Game.全服拍卖系统.获取委托列表()
	if 委托列表.is_empty():
		_content.add_child(_label("（暂无委托竞价）", false))
		return
	var 拍品表: Array = Game.全服拍卖系统.获取拍品列表()
	for w in 委托列表:
		var 卡: VBoxContainer = _card()
		var 状态: String = str(w.get("状态", ""))
		var 状态色: Color = Color(0.2, 0.8, 0.4) if 状态 == "活跃" else Color(0.6, 0.6, 0.6)
		# C-1（GO7）：拍品ID 属内部标识 ⇒ 不上屏。显示层反查拍品名（走公开 获取拍品列表()），反查不到退化「拍品」。
		var 拍品名: String = "拍品"
		for _lot in 拍品表:
			if str(_lot.get("id", "")) == str(w.get("拍品ID", "")):
				拍品名 = str(_lot.get("名称", "拍品"))
				break
		var _fb25 := _label("%s ｜ 委托价：%d灵石 ｜ 状态：%s" % [拍品名, int(w.get("委托价", 0)), 状态], true)
		卡.add_child(_fb25)
		_fb25.modulate.a = 0.0
		_fb25.create_tween().tween_property(_fb25, "modulate:a", 1.0, 0.25)
		var _fb26 := _label("冻结灵石：%d ｜ 设置日：第%d日" % [int(w.get("冻结灵石", 0)), int(w.get("设置日", 0))], false)
		卡.add_child(_fb26)
		_fb26.modulate.a = 0.0
		_fb26.create_tween().tween_property(_fb26, "modulate:a", 1.0, 0.25)

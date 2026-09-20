extends Control

# ===== S57 玩家间交易系统UI（商队运输）=====
# 符合修真世界观：委托商队运输，三种运输方式，货到付款，二次确认


var _当前页签: String = "发起交易"
var _content: VBoxContainer = null
var _提示: String = ""

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# 背景
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 主容器
	var main: VBoxContainer = VBoxContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 8)
	main.add_theme_constant_override("margin_left", UITheme.MARGIN)
	main.add_theme_constant_override("margin_right", UITheme.MARGIN)
	add_child(main)

	# 标题栏
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main.add_child(header)

	var title: Label = Label.new()
	title.text = "◇ 商队交易"
	UITheme.apply_project_font(title, UITheme.FONT_H1, true)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	header.add_child(title)

	header.add_spacer(false)

	var close_btn: Button = Button.new()
	close_btn.text = "◇"
	close_btn.custom_minimum_size = Vector2(40, 36)
	UITheme.apply_secondary_button_style(close_btn)
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# 页签栏
	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	main.add_child(tab_bar)

	var 页签列表: Array = ["发起交易", "运输中", "待收货", "交易记录"]
	for 页签 in 页签列表:
		var btn: Button = Button.new()
		btn.text = 页签
		btn.custom_minimum_size = Vector2(0, 32)
		if _当前页签 == 页签:
			UITheme.apply_primary_button_style(btn)
		else:
			UITheme.apply_secondary_button_style(btn)
		btn.pressed.connect(func(t=页签):
			_当前页签 = t
			_refresh()
		)
		tab_bar.add_child(btn)
		btn.modulate.a = 0.0
		btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)

	# 滚动区域
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	_refresh()

func _refresh() -> void:
	if _content == null:
		return
	# 清空
	for child in _content.get_children():
		child.queue_free()

	match _当前页签:
		"发起交易":
			_build发起交易()
		"运输中":
			_build运输中()
		"待收货":
			_build待收货()
		"交易记录":
			_build交易记录()

	# 提示
	if _提示 != "":
		var tip: Label = Label.new()
		tip.text = _提示
		tip.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		_content.add_child(tip)
		_提示 = ""

func _build发起交易() -> void:
	# 说明
	var tip: Label = Label.new()
	tip.text = "（委托商队向其他宗门运送物品，支持货到付款）"
	UITheme.apply_project_font(tip, UITheme.FONT_BODY, false)
	tip.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_content.add_child(tip)

	# 买家名称输入
	var 买家行: HBoxContainer = HBoxContainer.new()
	买家行.add_theme_constant_override("separation", 8)
	_content.add_child(买家行)

	var 买家标签: Label = Label.new()
	买家标签.text = "买家宗门："
	UITheme.apply_body_text(买家标签)
	买家标签.custom_minimum_size = Vector2(100, 0)
	买家行.add_child(买家标签)

	var 买家输入: LineEdit = LineEdit.new()
	买家输入.placeholder_text = "输入买家宗门名称"
	买家输入.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	买家行.add_child(买家输入)

	# 价格输入
	var 价格行: HBoxContainer = HBoxContainer.new()
	价格行.add_theme_constant_override("separation", 8)
	_content.add_child(价格行)

	var 价格标签: Label = Label.new()
	价格标签.text = "交易价格："
	UITheme.apply_body_text(价格标签)
	价格标签.custom_minimum_size = Vector2(100, 0)
	价格行.add_child(价格标签)

	var 价格输入: LineEdit = LineEdit.new()
	价格输入.placeholder_text = "输入灵石数量"
	价格输入.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	价格行.add_child(价格输入)

	# 运输方式选择
	var 运输标签: Label = Label.new()
	运输标签.text = "运输方式："
	UITheme.apply_project_font(运输标签, UITheme.FONT_H2, true)
	运输标签.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_content.add_child(运输标签)

	var 运输方式: Array = ["普通商队", "精锐商队", "传送阵"]
	for 方式 in 运输方式:
		var 配置: Dictionary = Game.商队系统.玩家运输配置[方式]
		var 方式行: HBoxContainer = HBoxContainer.new()
		方式行.add_theme_constant_override("separation", 8)
		_content.add_child(方式行)
		方式行.modulate.a = 0.0
		方式行.create_tween().tween_property(方式行, "modulate:a", 1.0, 0.25)

		var 方式标签: Label = Label.new()
		if 方式 == "普通商队":
			方式标签.text = "◇ 普通商队"
		elif 方式 == "精锐商队":
			方式标签.text = "◆ 精锐商队"
		else:
			方式标签.text = "◇ 传送阵"
		方式标签.custom_minimum_size = Vector2(120, 0)
		方式标签.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
		方式行.add_child(方式标签)
		方式标签.modulate.a = 0.0
		方式标签.create_tween().tween_property(方式标签, "modulate:a", 1.0, 0.25)

		var 描述标签: Label = Label.new()
		描述标签.text = str(配置.get("描述", ""))
		UITheme.apply_project_font(描述标签, UITheme.FONT_BODY, false)
		描述标签.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		描述标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		方式行.add_child(描述标签)
		描述标签.modulate.a = 0.0
		描述标签.create_tween().tween_property(描述标签, "modulate:a", 1.0, 0.25)

	# 货到付款开关
	var 货到付款行: HBoxContainer = HBoxContainer.new()
	货到付款行.add_theme_constant_override("separation", 8)
	_content.add_child(货到付款行)

	var 货到付款标签: Label = Label.new()
	货到付款标签.text = "货到付款："
	UITheme.apply_body_text(货到付款标签)
	货到付款标签.custom_minimum_size = Vector2(100, 0)
	货到付款行.add_child(货到付款标签)

	var 货到付款开关: CheckButton = CheckButton.new()
	货到付款开关.text = "买家收货时支付货款"
	货到付款行.add_child(货到付款开关)

	# 二次确认提示
	var 确认提示: Label = Label.new()
	确认提示.text = "⚠ 发起交易后将扣除运输费用，取消交易仅退还50%。请仔细核对买家和物品。"
	UITheme.apply_project_font(确认提示, UITheme.FONT_BODY, false)
	确认提示.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
	确认提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(确认提示)

	# 发起按钮（简化版，实际应从库藏选择物品）
	var 发起钮: Button = Button.new()
	发起钮.text = "发起交易（演示：发送1件物品）"
	发起钮.custom_minimum_size = Vector2(0, 40)
	UITheme.apply_primary_button_style(发起钮)
	发起钮.pressed.connect(func():
		var 买家名: String = 买家输入.text.strip_edges()
		var 价格: int = 0
		if 价格输入.text.strip_edges() != "":
			价格 = int(价格输入.text)
		if 买家名.is_empty():
			_提示 = "请输入买家宗门名称"
			_refresh()
			return
		# 选择运输方式（默认普通商队，这里简化）
		var 方式: String = "普通商队"
		var 物品列表: Array = [{"名称": "演示物品", "数量": 1}]
		var 结果: Dictionary = Game.商队系统.发起玩家交易("npc_" + 买家名, 买家名, 物品列表, 价格, 方式, 货到付款开关.button_pressed)
		if bool(结果.get("成功", false)):
			_提示 = "交易已发起，运输费用：%d灵石" % int(结果.get("运输费用", 0))
		else:
			_提示 = str(结果.get("原因", "发起失败"))
		_refresh()
	)
	_content.add_child(发起钮)

func _build运输中() -> void:
	var 运输中: Array = Game.商队系统.获取玩家运输中列表()
	if 运输中.is_empty():
		var 空: Label = Label.new()
		空.text = "（暂无运输中的物品）"
		空.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		空.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_content.add_child(空)
		return

	for 交易 in 运输中:
		_build交易卡片(交易, false)

func _build待收货() -> void:
	var 待收货: Array = Game.商队系统.获取玩家待收货列表()
	if 待收货.is_empty():
		var 空: Label = Label.new()
		空.text = "（暂无待收货物品）"
		空.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		空.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_content.add_child(空)
		return

	for 交易 in 待收货:
		_build交易卡片(交易, true)

func _build交易记录() -> void:
	var 记录: Array = Game.商队系统.获取玩家交易列表(50)
	if 记录.is_empty():
		var 空: Label = Label.new()
		空.text = "（暂无交易记录）"
		空.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		空.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_content.add_child(空)
		return

	for 交易 in 记录:
		_build交易卡片(交易, false)

func _build交易卡片(交易: Dictionary, 显示收货按钮: bool) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 100)
	_content.add_child(card)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# 标题行
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var 状态: String = str(交易.get("状态", ""))
	var 状态颜色: Color = Color(0.7, 0.7, 0.7)
	if 状态 == "已完成":
		状态颜色 = Color(0.4, 0.9, 0.4)
	elif 状态 == "运输中":
		状态颜色 = Color(0.4, 0.7, 1.0)
	elif 状态 == "待收货":
		状态颜色 = Color(0.9, 0.7, 0.3)
	elif 状态 == "已被劫":
		状态颜色 = Color(0.9, 0.4, 0.4)
	elif 状态 == "已取消":
		状态颜色 = Color(0.5, 0.5, 0.5)

	var 状态标签: Label = Label.new()
	状态标签.text = "[%s]" % 状态
	状态标签.add_theme_color_override("font_color", 状态颜色)
	UITheme.apply_project_font(状态标签, UITheme.FONT_H2, true)
	title_row.add_child(状态标签)

	title_row.add_spacer(false)

	var 日期标签: Label = Label.new()
	日期标签.text = "发起日：第%d日" % int(交易.get("发起日", 0))
	UITheme.apply_project_font(日期标签, UITheme.FONT_BODY, false)
	日期标签.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	title_row.add_child(日期标签)

	# 交易信息
	var 信息标签: Label = Label.new()
	信息标签.text = "买家：%s | 价格：%d灵石 | 运输：%s" % [
		str(交易.get("买家名称", "")),
		int(交易.get("价格", 0)),
		str(交易.get("运输方式", ""))
	]
	UITheme.apply_project_font(信息标签, UITheme.FONT_BODY, false)
	信息标签.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(信息标签)

	# 预计送达
	if 状态 == "运输中" or 状态 == "待确认":
		var 送达标签: Label = Label.new()
		送达标签.text = "预计送达：第%d日" % int(交易.get("预计送达日", 0))
		UITheme.apply_project_font(送达标签, UITheme.FONT_BODY, false)
		送达标签.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(送达标签)

	# 被劫赔偿
	if 状态 == "已被劫":
		var 赔偿标签: Label = Label.new()
		赔偿标签.text = "商队被劫，获得赔偿：%d灵石" % int(交易.get("赔偿金额", 0))
		UITheme.apply_project_font(赔偿标签, UITheme.FONT_BODY, false)
		赔偿标签.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		vbox.add_child(赔偿标签)

	# 货到付款标识
	if bool(交易.get("货到付款", false)):
		var 货到标签: Label = Label.new()
		货到标签.text = "（货到付款）"
		UITheme.apply_project_font(货到标签, UITheme.FONT_BODY, false)
		货到标签.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		vbox.add_child(货到标签)

	# 操作按钮
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	btn_row.add_spacer(false)

	if 显示收货按钮:
		var 收货钮: Button = Button.new()
		收货钮.text = "确认收货"
		收货钮.custom_minimum_size = Vector2(100, 30)
		UITheme.apply_primary_button_style(收货钮)
		收货钮.pressed.connect(func():
			# 二次确认防护
			_提示 = "请再次确认：确认收货后交易完成，货款将转给卖家。"
			var 确认钮: Button = Button.new()
			确认钮.text = "我确认，完成收货"
			确认钮.custom_minimum_size = Vector2(0, 30)
			UITheme.apply_primary_button_style(确认钮)
			确认钮.pressed.connect(func():
				var 结果: Dictionary = Game.商队系统.确认玩家收货(str(交易.get("id", "")))
				if bool(结果.get("成功", false)):
					_提示 = "收货成功，交易完成！"
				else:
					_提示 = str(结果.get("原因", "收货失败"))
				_refresh()
			)
			_content.add_child(确认钮)
		)
		btn_row.add_child(收货钮)

	if 状态 == "待确认":
		var 取消钮: Button = Button.new()
		取消钮.text = "取消交易"
		取消钮.custom_minimum_size = Vector2(100, 30)
		UITheme.apply_secondary_button_style(取消钮)
		取消钮.pressed.connect(func():
			var 结果: Dictionary = Game.商队系统.取消玩家交易(str(交易.get("id", "")))
			if bool(结果.get("成功", false)):
				_提示 = "交易已取消，退还50%运输费用。"
			else:
				_提示 = str(结果.get("原因", "取消失败"))
			_refresh()
		)
		btn_row.add_child(取消钮)

func _on_close() -> void:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("_close_sub_page"):
			n._close_sub_page()
			return
		n = n.get_parent()
	queue_free()

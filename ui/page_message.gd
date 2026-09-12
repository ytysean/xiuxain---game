extends Control

# ===== S56 修真世界消息中心 =====
# 整合：天音法旨、仙盟邸报、坊市闲谈、密语传音、天机秘闻、宗门传令
# 符合修真世界观：传音符、神识传音、邸报、闲谈等


var _当前类型: String = "全部"
var _content: VBoxContainer = null
var _提示: String = ""

func _ready() -> void:
	_build_ui()

func _on_close() -> void:
	# 向上找到game_ui并调用_close_sub_page
	var n: Node = get_parent()
	while n != null:
		if n.has_method("_close_sub_page"):
			n._close_sub_page()
			return
		n = n.get_parent()
	# 兜底：直接释放
	queue_free()

func _open_mail() -> void:
	# 向上找到game_ui并打开灵讯页面
	var n: Node = get_parent()
	while n != null:
		if n.has_method("_show_page"):
			n._close_sub_page()
			n._show_page("灵讯")
			return
		n = n.get_parent()

func _open_gazette() -> void:
	# 邸报在纪事页面中
	var n: Node = get_parent()
	while n != null:
		if n.has_method("_show_page"):
			n._close_sub_page()
			n._show_page("纪事")
			return
		n = n.get_parent()

func _open_chat() -> void:
	# 打开宗门频道聊天
	var n: Node = get_parent()
	while n != null:
		if n.has_method("_open_chat_page"):
			n._open_chat_page()
			return
		n = n.get_parent()

func _open_trade() -> void:
	# 打开商队交易
	var n: Node = get_parent()
	while n != null:
		if n.has_method("_open_player_trade_page"):
			n._open_player_trade_page()
			return
		n = n.get_parent()

# S56-P2：主动打探情报
func _on_打探() -> void:
	var 结果: Dictionary = Game.消息系统.主动打探情报()
	if bool(结果.get("成功", false)):
		var 结果类型: String = str(结果.get("结果", ""))
		if 结果类型 == "天机秘闻":
			_提示 = "打探成功！获得天机秘闻一条。"
		elif 结果类型 == "坊市闲谈":
			_提示 = "打探到一些坊市闲谈。"
		else:
			_提示 = "打探数日，一无所获。"
	else:
		_提示 = str(结果.get("原因", "打探失败"))
	_refresh()

# S56-P2：卧底管理
func _on_卧底管理() -> void:
	_提示 = "卧底管理功能：可在弟子详情页派遣忠诚≥80的弟子卧底。"
	_refresh()

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
	add_child(main)

	# 标题栏
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main.add_child(header)

	var title: Label = Label.new()
	title.text = "📜 修真消息阁"
	title.add_theme_font_size_override("font_size", UITheme.FONT_H1)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	header.add_child(title)

	header.add_spacer(false)

	var 全部已读钮: Button = Button.new()
	全部已读钮.text = "全部已读"
	全部已读钮.custom_minimum_size = Vector2(100, 36)
	UITheme.apply_secondary_button_style(全部已读钮)
	全部已读钮.pressed.connect(func():
		Game.消息系统.标记全部已读()
		_refresh()
	)
	header.add_child(全部已读钮)

	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 36)
	UITheme.apply_secondary_button_style(close_btn)
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# 类型标签栏
	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	main.add_child(tab_bar)

	var 类型列表: Array = ["全部", "天音法旨", "仙盟邸报", "坊市闲谈", "密语传音", "天机秘闻", "宗门传令"]
	for 类型 in 类型列表:
		var btn: Button = Button.new()
		var 未读数: int = Game.消息系统.获取类型未读数(类型) if 类型 != "全部" else Game.消息系统.获取总未读数()
		btn.text = 类型 + ("(%d)" % 未读数 if 未读数 > 0 else "")
		btn.custom_minimum_size = Vector2(0, 32)
		if _当前类型 == 类型:
			UITheme.apply_primary_button_style(btn)
		else:
			UITheme.apply_secondary_button_style(btn)
		btn.pressed.connect(func(t=类型):
			_当前类型 = t
			_refresh()
		)
		tab_bar.add_child(btn)

	# 现有系统入口
	var existing_bar: HBoxContainer = HBoxContainer.new()
	existing_bar.add_theme_constant_override("separation", 8)
	main.add_child(existing_bar)

	var 灵讯钮: Button = Button.new()
	灵讯钮.text = "📨 灵讯（邮件）"
	灵讯钮.custom_minimum_size = Vector2(0, 30)
	UITheme.apply_secondary_button_style(灵讯钮)
	灵讯钮.pressed.connect(_open_mail)
	existing_bar.add_child(灵讯钮)

	var 邸报钮: Button = Button.new()
	邸报钮.text = "王朝邸报"
	邸报钮.custom_minimum_size = Vector2(0, 30)
	UITheme.apply_secondary_button_style(邸报钮)
	邸报钮.pressed.connect(_open_gazette)
	existing_bar.add_child(邸报钮)

	var 聊天钮: Button = Button.new()
	聊天钮.text = "心弦"
	聊天钮.custom_minimum_size = Vector2(0, 30)
	UITheme.apply_secondary_button_style(聊天钮)
	聊天钮.pressed.connect(_open_chat)
	existing_bar.add_child(聊天钮)

	var 交易钮: Button = Button.new()
	交易钮.text = "商队交易"
	交易钮.custom_minimum_size = Vector2(0, 30)
	UITheme.apply_secondary_button_style(交易钮)
	交易钮.pressed.connect(_open_trade)
	existing_bar.add_child(交易钮)

	# S56-P2：情报功能入口
	var p2_bar: HBoxContainer = HBoxContainer.new()
	p2_bar.add_theme_constant_override("separation", 8)
	main.add_child(p2_bar)

	# 传音符显示
	var 传音符标签: Label = Label.new()
	传音符标签.text = "🎵 传音符：%d" % Game.消息系统.传音符数量
	传音符标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	传音符标签.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
	p2_bar.add_child(传音符标签)

	# 天机阁声望
	var 声望标签: Label = Label.new()
	声望标签.text = "🔮 天机阁声望：%d" % Game.消息系统.天机阁声望
	声望标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	声望标签.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
	p2_bar.add_child(声望标签)

	p2_bar.add_spacer(false)

	# 主动打探按钮
	var 打探钮: Button = Button.new()
	if Game.消息系统.打探冷却 > 0:
		打探钮.text = "打探冷却(%d日)" % Game.消息系统.打探冷却
	else:
		打探钮.text = "🔍 主动打探(500灵石+50贡献)"
	打探钮.custom_minimum_size = Vector2(0, 30)
	UITheme.apply_secondary_button_style(打探钮)
	打探钮.pressed.connect(_on_打探)
	p2_bar.add_child(打探钮)

	# 卧底管理按钮
	var 卧底钮: Button = Button.new()
	卧底钮.text = "🕵️ 卧底管理(%d人)" % Game.消息系统.卧底弟子.size()
	卧底钮.custom_minimum_size = Vector2(0, 30)
	UITheme.apply_secondary_button_style(卧底钮)
	卧底钮.pressed.connect(_on_卧底管理)
	p2_bar.add_child(卧底钮)

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

	# 获取消息列表
	var 消息列表: Array
	if _当前类型 == "全部":
		消息列表 = Game.消息系统.获取最新消息(100)
	else:
		消息列表 = Game.消息系统.获取类型消息(_当前类型, 50)

	if 消息列表.is_empty():
		var 空: Label = Label.new()
		空.text = "（暂无消息）"
		空.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		空.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_content.add_child(空)
		return

	# 显示消息
	for msg in 消息列表:
		_build消息卡片(msg)

	# 提示
	if _提示 != "":
		var tip: Label = Label.new()
		tip.text = _提示
		tip.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		_content.add_child(tip)
		_提示 = ""

func _build消息卡片(msg: Dictionary) -> void:
	var 类型: String = str(msg.get("类型", ""))
	var 颜色: Color = Game.消息系统.获取类型颜色(类型)
	var 图标: String = Game.消息系统.获取类型图标(类型)
	var 已读: bool = bool(msg.get("已读", false))

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)
	_content.add_child(card)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# 标题行
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var 类型标签: Label = Label.new()
	类型标签.text = "%s [%s]" % [图标, 类型]
	类型标签.add_theme_color_override("font_color", 颜色)
	类型标签.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	title_row.add_child(类型标签)

	if not 已读:
		var 未读标签: Label = Label.new()
		未读标签.text = "●"
		未读标签.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		title_row.add_child(未读标签)

	title_row.add_spacer(false)

	var 日期标签: Label = Label.new()
	日期标签.text = "第%d日" % int(msg.get("日", 0))
	日期标签.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	日期标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	title_row.add_child(日期标签)

	# 标题
	var 标题: Label = Label.new()
	标题.text = str(msg.get("标题", ""))
	标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	if not 已读:
		标题.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	else:
		标题.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(标题)

	# 内容
	var 内容: Label = Label.new()
	内容.text = str(msg.get("内容", ""))
	内容.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	内容.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	内容.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(内容)

	# 发送者
	var 发送者行: HBoxContainer = HBoxContainer.new()
	发送者行.add_theme_constant_override("separation", 8)
	vbox.add_child(发送者行)

	var 发送者标签: Label = Label.new()
	发送者标签.text = "传讯者：%s" % str(msg.get("发送者", ""))
	发送者标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	发送者标签.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	发送者行.add_child(发送者标签)

	发送者行.add_spacer(false)

	# 坊市闲谈验证按钮
	var 附加数据: Dictionary = msg.get("附加数据", {})
	if 类型 == "坊市闲谈" and bool(附加数据.get("可验证", false)):
		if bool(附加数据.get("已验证", false)):
			# 已验证，显示结果
			var 验证结果: String = str(附加数据.get("验证结果", ""))
			var 结果标签: Label = Label.new()
			if 验证结果 == "真":
				结果标签.text = "✓ 已验证：属实"
				结果标签.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			elif 验证结果 == "半真半假":
				结果标签.text = "~ 已验证：半真半假"
				结果标签.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
			else:
				结果标签.text = "✗ 已验证：不实"
				结果标签.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
			结果标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			发送者行.add_child(结果标签)
		else:
			# 未验证，显示验证按钮
			var 验证钮: Button = Button.new()
			验证钮.text = "验证(100灵石)"
			验证钮.custom_minimum_size = Vector2(120, 28)
			UITheme.apply_secondary_button_style(验证钮)
			验证钮.pressed.connect(func():
				var 结果: Dictionary = Game.消息系统.验证坊市闲谈(str(msg.get("id", "")))
				if bool(结果.get("成功", false)):
					_提示 = "验证完成：%s" % str(结果.get("结果", ""))
				else:
					_提示 = str(结果.get("原因", "验证失败"))
				_refresh()
			)
			发送者行.add_child(验证钮)

	# S56-P2：天机秘闻领取奖励
	if 类型 == "天机秘闻":
		var 秘闻等级: String = str(附加数据.get("秘闻等级", "普通"))
		var 已领取: bool = bool(附加数据.get("已领取", false))
		var 过期: bool = Game.消息系统.秘闻是否过期(str(msg.get("id", "")))
		# 显示秘闻等级
		var 等级标签: Label = Label.new()
		if 秘闻等级 == "传说":
			等级标签.text = "【传说】"
			等级标签.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		elif 秘闻等级 == "史诗":
			等级标签.text = "【史诗】"
			等级标签.add_theme_color_override("font_color", Color(0.8, 0.4, 0.9))
		else:
			等级标签.text = "【稀有】"
			等级标签.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		等级标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		发送者行.add_child(等级标签)

		if 已领取:
			var 已领标签: Label = Label.new()
			已领标签.text = "✓ 已领取"
			已领标签.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			已领标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			发送者行.add_child(已领标签)
		elif 过期:
			var 过期标签: Label = Label.new()
			过期标签.text = "✗ 已过期"
			过期标签.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			过期标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			发送者行.add_child(过期标签)
		else:
			var 领取钮: Button = Button.new()
			领取钮.text = "领取奖励"
			领取钮.custom_minimum_size = Vector2(100, 28)
			UITheme.apply_primary_button_style(领取钮)
			领取钮.pressed.connect(func():
				var 结果: Dictionary = Game.消息系统.领取秘闻奖励(str(msg.get("id", "")))
				if bool(结果.get("成功", false)):
					_提示 = "领取成功：贡献点+%d，声望+%d" % [int(结果.get("贡献点", 0)), int(结果.get("声望", 0))]
				else:
					_提示 = str(结果.get("原因", "领取失败"))
				_refresh()
			)
			发送者行.add_child(领取钮)

	# 标记已读按钮
	if not 已读:
		var 已读钮: Button = Button.new()
		已读钮.text = "标记已读"
		已读钮.custom_minimum_size = Vector2(80, 28)
		UITheme.apply_secondary_button_style(已读钮)
		已读钮.pressed.connect(func():
			Game.消息系统.标记已读(str(msg.get("id", "")))
			_refresh()
		)
		发送者行.add_child(已读钮)

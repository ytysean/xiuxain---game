extends Control

# ===== S59 闭关嘱托UI =====
# 宗主闭关/离线时，设置副宗主代理事务 + 闭关前法旨
# 符合修真世界观：垂拱而治，权柄下放，留下法旨


var _content: VBoxContainer = null
var _提示: String = ""

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# 背景
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.086, 0.125, 0.141, 0.95)
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
	title.text = "◇ 闭关嘱托"
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

	# 权益状态
	var 权益面板: PanelContainer = PanelContainer.new()
	权益面板.custom_minimum_size = Vector2(0, 50)
	main.add_child(权益面板)

	var 权益盒: HBoxContainer = HBoxContainer.new()
	权益盒.add_theme_constant_override("separation", 16)
	权益面板.add_child(权益盒)

	var 卡级标签: Label = Label.new()
	var 卡级文本: String = "普通"
	if Game.永久卡激活:
		卡级文本 = "永久卡"
	elif Game.季卡有效():
		卡级文本 = "季卡"
	elif Game.月卡有效():
		卡级文本 = "月卡"
	卡级标签.text = "◇ 当前权益：%s" % 卡级文本
	UITheme.apply_project_font(卡级标签, UITheme.FONT_BODY, false)
	卡级标签.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
	权益盒.add_child(卡级标签)

	var VIP标签: Label = Label.new()
	VIP标签.text = "★ 仙阶 %d" % Game.当前VIP等级()
	UITheme.apply_project_font(VIP标签, UITheme.FONT_BODY, false)
	VIP标签.add_theme_color_override("font_color", Color(0.7, 0.6, 0.8))
	权益盒.add_child(VIP标签)

	var 代理数标签: Label = Label.new()
	代理数标签.text = "代理：%d/%d" % [Game.闭关嘱托.获取已开启数(), Game.闭关嘱托.获取最大代理数()]
	UITheme.apply_project_font(代理数标签, UITheme.FONT_BODY, false)
	代理数标签.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	权益盒.add_child(代理数标签)

	# 说明
	var 说明: Label = Label.new()
	说明.text = "宗主闭关期间，副宗主依嘱托代掌宗门。生产事务由各殿弟子依【法旨】执行，经营决策由副宗主代理。代理效率低于亲为，关键决策仍需宗主定夺。"
	UITheme.apply_project_font(说明, UITheme.FONT_BODY, false)
	说明.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(说明)

	# 页签
	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	main.add_child(tab_bar)

	var 页签列表: Array = ["代理项目", "法旨管理", "执行日志"]
	for 页签 in 页签列表:
		var btn: Button = Button.new()
		btn.text = 页签
		btn.custom_minimum_size = Vector2(0, 32)
		UITheme.apply_secondary_button_style(btn)
		btn.pressed.connect(func(t=页签):
			_显示页签(t)
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

	# 默认显示代理项目
	_显示代理项目()

func _显示页签(页签: String) -> void:
	match 页签:
		"代理项目":
			_显示代理项目()
		"法旨管理":
			_显示法旨管理()
		"执行日志":
			_显示执行日志()

## 代理开关回调：名称与当前状态由 bind 传入（快照），不依赖外部循环变量
func _on_代理开关(名称: String, 当前已开启: bool) -> void:
	if 当前已开启:
		Game.闭关嘱托.关闭代理(名称)
	else:
		var 结果: Dictionary = Game.闭关嘱托.开启代理(名称)
		if not bool(结果["成功"]):
			_提示 = str(结果["原因"])
	_显示代理项目()

# ===== 代理项目 =====
func _显示代理项目() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()

	var 标题: Label = Label.new()
	标题.text = "◇ 副宗主代理（经营决策类）"
	UITheme.apply_project_font(标题, UITheme.FONT_H2, true)
	标题.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	_content.add_child(标题)

	var 项目列表: Array = Game.闭关嘱托.获取所有项目状态()
	for 项目 in 项目列表:
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 80)
		_content.add_child(card)
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.25)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		card.add_child(hbox)
		hbox.modulate.a = 0.0
		hbox.create_tween().tween_property(hbox, "modulate:a", 1.0, 0.25)

		var 图标标签: Label = Label.new()
		图标标签.text = str(项目["图标"])
		图标标签.custom_minimum_size = Vector2(40, 0)
		UITheme.apply_project_font(图标标签, UITheme.FONT_H1, true)
		图标标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(图标标签)
		图标标签.modulate.a = 0.0
		图标标签.create_tween().tween_property(图标标签, "modulate:a", 1.0, 0.25)

		var info: VBoxContainer = VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info)
		info.modulate.a = 0.0
		info.create_tween().tween_property(info, "modulate:a", 1.0, 0.25)

		var 名称标签: Label = Label.new()
		名称标签.text = str(项目["名称"])
		UITheme.apply_project_font(名称标签, UITheme.FONT_H2, true)
		名称标签.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
		info.add_child(名称标签)
		名称标签.modulate.a = 0.0
		名称标签.create_tween().tween_property(名称标签, "modulate:a", 1.0, 0.25)

		var 描述标签: Label = Label.new()
		描述标签.text = str(项目["描述"])
		UITheme.apply_project_font(描述标签, UITheme.FONT_BODY, false)
		描述标签.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		info.add_child(描述标签)
		描述标签.modulate.a = 0.0
		描述标签.create_tween().tween_property(描述标签, "modulate:a", 1.0, 0.25)

		var 效率行: HBoxContainer = HBoxContainer.new()
		效率行.add_theme_constant_override("separation", 12)
		info.add_child(效率行)
		效率行.modulate.a = 0.0
		效率行.create_tween().tween_property(效率行, "modulate:a", 1.0, 0.25)

		var 效率标签: Label = Label.new()
		效率标签.text = "效率：%d%%" % int(float(项目["当前效率"]) * 100)
		UITheme.apply_project_font(效率标签, UITheme.FONT_BODY, false)
		效率标签.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		效率行.add_child(效率标签)
		效率标签.modulate.a = 0.0
		效率标签.create_tween().tween_property(效率标签, "modulate:a", 1.0, 0.25)

		var 卡级标签: Label = Label.new()
		卡级标签.text = "需：%s" % str(项目["所需卡级"])
		UITheme.apply_project_font(卡级标签, UITheme.FONT_BODY, false)
		if bool(项目["资格合格"]):
			卡级标签.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		else:
			卡级标签.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
		效率行.add_child(卡级标签)
		卡级标签.modulate.a = 0.0
		卡级标签.create_tween().tween_property(卡级标签, "modulate:a", 1.0, 0.25)

		var 冷却标签: Label = Label.new()
		if int(项目["冷却日"]) > 0:
			冷却标签.text = "每%d日执行" % int(项目["冷却日"])
		else:
			冷却标签.text = "事件触发"
		UITheme.apply_project_font(冷却标签, UITheme.FONT_BODY, false)
		冷却标签.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		效率行.add_child(冷却标签)
		冷却标签.modulate.a = 0.0
		冷却标签.create_tween().tween_property(冷却标签, "modulate:a", 1.0, 0.25)

		var 开关钮: Button = Button.new()
		if bool(项目["已开启"]):
			开关钮.text = "✓ 已开启"
			开关钮.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		else:
			开关钮.text = "开启"
			if not bool(项目["资格合格"]):
				开关钮.disabled = true
				开关钮.text = "未解锁"
		开关钮.custom_minimum_size = Vector2(80, 32)
		UITheme.apply_secondary_button_style(开关钮)
		# 用 bind 快照「名称/当前状态」：lambda 默认参数写法会被未声明标识符扫描判为
		# 未声明中文标识符（scan 无法识别 lambda 形参默认值），且 bind 天然避免闭包捕获循环变量
		开关钮.pressed.connect(_on_代理开关.bind(str(项目["名称"]), bool(项目["已开启"])))
		hbox.add_child(开关钮)
		开关钮.modulate.a = 0.0
		开关钮.create_tween().tween_property(开关钮, "modulate:a", 1.0, 0.25)

	if _提示 != "":
		var tip: Label = Label.new()
		tip.text = "⚠ %s" % _提示
		tip.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
		_content.add_child(tip)
		_提示 = ""

# ===== 法旨管理 =====
func _显示法旨管理() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()

	var 标题: Label = Label.new()
	标题.text = "◇ 宗主法旨（生产差事）"
	UITheme.apply_project_font(标题, UITheme.FONT_H2, true)
	标题.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	_content.add_child(标题)

	var 说明: Label = Label.new()
	说明.text = "闭关前下达法旨，各殿弟子依优先级执行。生产事务无需代理，弟子自行完成。"
	UITheme.apply_project_font(说明, UITheme.FONT_BODY, false)
	说明.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(说明)

	# 下达法旨区域
	var 下达面板: PanelContainer = PanelContainer.new()
	下达面板.custom_minimum_size = Vector2(0, 120)
	_content.add_child(下达面板)

	var 下达盒: VBoxContainer = VBoxContainer.new()
	下达盒.add_theme_constant_override("separation", 6)
	下达面板.add_child(下达盒)

	var 下达标题: Label = Label.new()
	下达标题.text = "◇ 下达新法旨"
	UITheme.apply_project_font(下达标题, UITheme.FONT_H2, true)
	下达标题.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	下达盒.add_child(下达标题)

	# 法旨类型选择
	var 类型行: HBoxContainer = HBoxContainer.new()
	类型行.add_theme_constant_override("separation", 8)
	下达盒.add_child(类型行)

	var 类型标签: Label = Label.new()
	类型标签.text = "类型："
	类型标签.custom_minimum_size = Vector2(50, 0)
	UITheme.apply_project_font(类型标签, UITheme.FONT_BODY, false)
	类型行.add_child(类型标签)

	var 类型列表: Array = Game.闭关嘱托.获取法旨类型()
	var 类型按钮: Array = []
	var 当前类型: String = str(类型列表[0]["类型"])
	for 类型 in 类型列表:
		var btn: Button = Button.new()
		btn.text = "%s %s" % [str(类型["图标"]), str(类型["类型"])]
		btn.custom_minimum_size = Vector2(70, 28)
		UITheme.apply_secondary_button_style(btn)
		btn.pressed.connect(func(t=str(类型["类型"])):
			当前类型 = t
		)
		类型行.add_child(btn)
		btn.modulate.a = 0.0
		btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)

	# 目标和数量
	var 目标行: HBoxContainer = HBoxContainer.new()
	目标行.add_theme_constant_override("separation", 8)
	下达盒.add_child(目标行)

	var 目标标签: Label = Label.new()
	目标标签.text = "目标："
	目标标签.custom_minimum_size = Vector2(50, 0)
	UITheme.apply_project_font(目标标签, UITheme.FONT_BODY, false)
	目标行.add_child(目标标签)

	var 目标输入: LineEdit = LineEdit.new()
	目标输入.placeholder_text = "如：筑基丹、青锋剑..."
	目标输入.custom_minimum_size = Vector2(150, 28)
	目标行.add_child(目标输入)

	var 数量标签: Label = Label.new()
	数量标签.text = "数量："
	UITheme.apply_project_font(数量标签, UITheme.FONT_BODY, false)
	目标行.add_child(数量标签)

	var 数量输入: LineEdit = LineEdit.new()
	数量输入.placeholder_text = "10"
	数量输入.custom_minimum_size = Vector2(60, 28)
	目标行.add_child(数量输入)

	# 优先级和下达按钮
	var 优先行: HBoxContainer = HBoxContainer.new()
	优先行.add_theme_constant_override("separation", 8)
	下达盒.add_child(优先行)

	var 优先标签: Label = Label.new()
	优先标签.text = "优先级："
	优先标签.custom_minimum_size = Vector2(50, 0)
	UITheme.apply_project_font(优先标签, UITheme.FONT_BODY, false)
	优先行.add_child(优先标签)

	var 当前优先级: int = 2
	var 优先级列表: Array = [{"名": "低", "值": 1}, {"名": "中", "值": 2}, {"名": "高", "值": 3}]
	for 优先 in 优先级列表:
		var btn: Button = Button.new()
		btn.text = str(优先["名"])
		btn.custom_minimum_size = Vector2(50, 28)
		UITheme.apply_secondary_button_style(btn)
		btn.pressed.connect(func(v=int(优先["值"])):
			当前优先级 = v
		)
		优先行.add_child(btn)
		btn.modulate.a = 0.0
		btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)

	优先行.add_spacer(false)

	var 下达钮: Button = Button.new()
	下达钮.text = "◇ 下达法旨"
	下达钮.custom_minimum_size = Vector2(100, 32)
	UITheme.apply_primary_button_style(下达钮)
	下达钮.pressed.connect(func():
		var 目标: String = 目标输入.text.strip_edges()
		var 数量: int = int(数量输入.text) if 数量输入.text.strip_edges() != "" else 1
		if 目标 == "":
			_提示 = "请填写法旨目标"
			_显示法旨管理()
			return
		var 结果: Dictionary = Game.闭关嘱托.下达法旨(当前类型, 目标, 数量, 当前优先级)
		if bool(结果["成功"]):
			目标输入.text = ""
			数量输入.text = ""
		else:
			_提示 = str(结果["原因"])
		_显示法旨管理()
	)
	优先行.add_child(下达钮)

	# 当前法旨列表
	var 列表标题: Label = Label.new()
	列表标题.text = "◇ 当前执行中法旨"
	UITheme.apply_project_font(列表标题, UITheme.FONT_H2, true)
	列表标题.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	_content.add_child(列表标题)

	var 当前法旨: Array = Game.闭关嘱托.获取当前法旨()
	if 当前法旨.is_empty():
		var 空标签: Label = Label.new()
		空标签.text = "暂无执行中法旨"
		UITheme.apply_project_font(空标签, UITheme.FONT_BODY, false)
		空标签.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_content.add_child(空标签)
	else:
		for 法旨 in 当前法旨:
			var card: PanelContainer = PanelContainer.new()
			card.custom_minimum_size = Vector2(0, 70)
			_content.add_child(card)
			card.modulate.a = 0.0
			card.create_tween().tween_property(card, "modulate:a", 1.0, 0.25)

			var hbox: HBoxContainer = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 12)
			card.add_child(hbox)
			hbox.modulate.a = 0.0
			hbox.create_tween().tween_property(hbox, "modulate:a", 1.0, 0.25)

			var 图标标签: Label = Label.new()
			图标标签.text = str(法旨["图标"])
			图标标签.custom_minimum_size = Vector2(30, 0)
			UITheme.apply_project_font(图标标签, UITheme.FONT_TITLE, true)
			hbox.add_child(图标标签)
			图标标签.modulate.a = 0.0
			图标标签.create_tween().tween_property(图标标签, "modulate:a", 1.0, 0.25)

			var info: VBoxContainer = VBoxContainer.new()
			info.add_theme_constant_override("separation", 2)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(info)
			info.modulate.a = 0.0
			info.create_tween().tween_property(info, "modulate:a", 1.0, 0.25)

			var 名称标签: Label = Label.new()
			var 优先文本: String = ["低", "中", "高"][int(法旨["优先级"]) - 1]
			名称标签.text = "%s %s×%d（优先级：%s）" % [str(法旨["执行殿阁"]), str(法旨["目标"]), int(法旨["数量"]), 优先文本]
			UITheme.apply_project_font(名称标签, UITheme.FONT_BODY, false)
			名称标签.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
			info.add_child(名称标签)
			名称标签.modulate.a = 0.0
			名称标签.create_tween().tween_property(名称标签, "modulate:a", 1.0, 0.25)

			# 负责人
			var 负责人标签: Label = Label.new()
			负责人标签.text = "负责人：%s" % str(法旨.get("负责人", "执事弟子"))
			UITheme.apply_project_font(负责人标签, UITheme.FONT_BODY, false)
			负责人标签.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			info.add_child(负责人标签)
			负责人标签.modulate.a = 0.0
			负责人标签.create_tween().tween_property(负责人标签, "modulate:a", 1.0, 0.25)

			var 进度标签: Label = Label.new()
			var 进度: float = float(法旨["已完成"]) / float(max(1, int(法旨["数量"])))
			进度标签.text = "进度：%d/%d（%d%%）" % [int(法旨["已完成"]), int(法旨["数量"]), int(进度 * 100)]
			UITheme.apply_project_font(进度标签, UITheme.FONT_BODY, false)
			进度标签.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
			info.add_child(进度标签)
			进度标签.modulate.a = 0.0
			进度标签.create_tween().tween_property(进度标签, "modulate:a", 1.0, 0.25)

			# 最近执行事件
			var 记录: Array = 法旨.get("执行记录", [])
			if 记录.size() > 0:
				var 最近事件: Dictionary = 记录[记录.size() - 1]
				var 事件标签: Label = Label.new()
				事件标签.text = "◇ %s" % str(最近事件["事件"])
				UITheme.apply_project_font(事件标签, UITheme.FONT_AUX, false)
				事件标签.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
				事件标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				info.add_child(事件标签)
				事件标签.modulate.a = 0.0
				事件标签.create_tween().tween_property(事件标签, "modulate:a", 1.0, 0.25)

			var 取消钮: Button = Button.new()
			取消钮.text = "取消"
			取消钮.custom_minimum_size = Vector2(60, 28)
			UITheme.apply_secondary_button_style(取消钮)
			取消钮.pressed.connect(func(id=str(法旨["id"])):
				Game.闭关嘱托.取消法旨(id)
				_显示法旨管理()
			)
			hbox.add_child(取消钮)
			取消钮.modulate.a = 0.0
			取消钮.create_tween().tween_property(取消钮, "modulate:a", 1.0, 0.25)

	# 历史法旨（已完成）
	var 历史标题: Label = Label.new()
	历史标题.text = "◇ 近期完成法旨"
	UITheme.apply_project_font(历史标题, UITheme.FONT_H2, true)
	历史标题.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	_content.add_child(历史标题)

	var 历史法旨: Array = Game.闭关嘱托.法旨历史.duplicate()
	历史法旨.reverse()
	历史法旨 = 历史法旨.slice(0, min(5, 历史法旨.size()))
	if 历史法旨.is_empty():
		var 空标签2: Label = Label.new()
		空标签2.text = "暂无历史记录"
		UITheme.apply_project_font(空标签2, UITheme.FONT_BODY, false)
		空标签2.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_content.add_child(空标签2)
	else:
		for 法旨 in 历史法旨:
			var card: PanelContainer = PanelContainer.new()
			card.custom_minimum_size = Vector2(0, 50)
			_content.add_child(card)
			card.modulate.a = 0.0
			card.create_tween().tween_property(card, "modulate:a", 1.0, 0.25)

			var hbox: HBoxContainer = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 12)
			card.add_child(hbox)
			hbox.modulate.a = 0.0
			hbox.create_tween().tween_property(hbox, "modulate:a", 1.0, 0.25)

			var 图标标签: Label = Label.new()
			图标标签.text = str(法旨["图标"])
			图标标签.custom_minimum_size = Vector2(30, 0)
			UITheme.apply_project_font(图标标签, UITheme.FONT_H2, true)
			hbox.add_child(图标标签)
			图标标签.modulate.a = 0.0
			图标标签.create_tween().tween_property(图标标签, "modulate:a", 1.0, 0.25)

			var info: VBoxContainer = VBoxContainer.new()
			info.add_theme_constant_override("separation", 2)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(info)
			info.modulate.a = 0.0
			info.create_tween().tween_property(info, "modulate:a", 1.0, 0.25)

			var 名称标签: Label = Label.new()
			名称标签.text = "%s %s×%d" % [str(法旨["执行殿阁"]), str(法旨["目标"]), int(法旨["数量"])]
			UITheme.apply_project_font(名称标签, UITheme.FONT_BODY, false)
			名称标签.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
			info.add_child(名称标签)
			名称标签.modulate.a = 0.0
			名称标签.create_tween().tween_property(名称标签, "modulate:a", 1.0, 0.25)

			var 完成标签: Label = Label.new()
			var 完成等级: String = str(法旨.get("完成等级", "已完成"))
			var 完成度: int = int(float(法旨.get("完成度", 1.0)) * 100)
			var 完成文案: String = str(法旨.get("完成文案", ""))
			完成标签.text = "%s（完成度%d%%）- %s" % [完成等级, 完成度, 完成文案]
			UITheme.apply_project_font(完成标签, UITheme.FONT_BODY, false)
			# 颜色根据完成等级
			if 完成等级 == "超额功果":
				完成标签.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
			elif 完成等级 == "圆满完成":
				完成标签.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			elif 完成等级 == "略有不足":
				完成标签.add_theme_color_override("font_color", Color(0.7, 0.7, 0.4))
			elif 完成等级 == "勉强交差":
				完成标签.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
			else:
				完成标签.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
			完成标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(完成标签)
			完成标签.modulate.a = 0.0
			完成标签.create_tween().tween_property(完成标签, "modulate:a", 1.0, 0.25)

			# 意外收获
			var 意外: String = str(法旨.get("意外收获", ""))
			if 意外 != "":
				var 意外标签: Label = Label.new()
				意外标签.text = "◆ 意外收获：%s" % 意外
				UITheme.apply_project_font(意外标签, UITheme.FONT_AUX, false)
				意外标签.add_theme_color_override("font_color", Color(0.9, 0.6, 0.8))
				info.add_child(意外标签)
				意外标签.modulate.a = 0.0
				意外标签.create_tween().tween_property(意外标签, "modulate:a", 1.0, 0.25)

	if _提示 != "":
		var tip: Label = Label.new()
		tip.text = "⚠ %s" % _提示
		tip.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
		_content.add_child(tip)
		_提示 = ""

# ===== 执行日志 =====
func _显示执行日志() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()

	var 标题: Label = Label.new()
	标题.text = "◇ 代理执行日志"
	UITheme.apply_project_font(标题, UITheme.FONT_H2, true)
	标题.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	_content.add_child(标题)

	var 日志: Array = Game.闭关嘱托.获取日志(30)
	if 日志.is_empty():
		var 空标签: Label = Label.new()
		空标签.text = "暂无执行记录"
		UITheme.apply_project_font(空标签, UITheme.FONT_BODY, false)
		空标签.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_content.add_child(空标签)
	else:
		for 记录 in 日志:
			var card: PanelContainer = PanelContainer.new()
			card.custom_minimum_size = Vector2(0, 36)
			_content.add_child(card)
			card.modulate.a = 0.0
			card.create_tween().tween_property(card, "modulate:a", 1.0, 0.25)

			var hbox: HBoxContainer = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 12)
			card.add_child(hbox)
			hbox.modulate.a = 0.0
			hbox.create_tween().tween_property(hbox, "modulate:a", 1.0, 0.25)

			var 日标签: Label = Label.new()
			日标签.text = "第%d日" % int(记录["日"])
			日标签.custom_minimum_size = Vector2(60, 0)
			UITheme.apply_project_font(日标签, UITheme.FONT_BODY, false)
			日标签.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
			hbox.add_child(日标签)
			日标签.modulate.a = 0.0
			日标签.create_tween().tween_property(日标签, "modulate:a", 1.0, 0.25)

			var 文本标签: Label = Label.new()
			文本标签.text = str(记录["文本"])
			UITheme.apply_project_font(文本标签, UITheme.FONT_BODY, false)
			文本标签.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			文本标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(文本标签)
			文本标签.modulate.a = 0.0
			文本标签.create_tween().tween_property(文本标签, "modulate:a", 1.0, 0.25)

func _on_close() -> void:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("_close_sub_page"):
			n._close_sub_page()
			return
		n = n.get_parent()
	queue_free()

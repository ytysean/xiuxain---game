extends Control
# 家族系统UI：总览 / 成员 / 宝库 / 功法 / 秘宝 / 排行
# 后端：game_state.gd 家族系统（60+函数已完整实现）
# 入口：main.gd 宗门页快捷网格「家族」→ 二级页
# 代码纪律：局部变量一律 `var x: Type = ...`（禁 := walrus）；按钮回调用 Callable.connect。

signal 返回主页

const TABS: Array = ["总览", "成员", "宝库", "功法", "秘宝", "排行"]

var _built: bool = false
var _cur: String = "总览"
var _body: MarginContainer = null
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}
var _提示: String = ""
var _当前家族ID: String = ""


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	# 修复（实机验收抓出 · 2026-09-12）：本页根节点是 Control（非容器），子节点 anchors 全 0，
	# ScrollContainer 最小尺寸为 0 → 塌成 0×0 且 clip_contents=true 把正文整块裁掉。
	# 与 page_chat 同构：先挂一个全屏 VBoxContainer 作为唯一布局宿主。
	var main: VBoxContainer = VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	# ★ PH7-13：手搓 66 高顶栏（文字方钮 120×36 + FONT_TITLE 标题）
	#   → 收口到 UITheme.建顶栏（90×90 返回环 + 页面标题语义，与全站一致）
	main.add_child(UITheme.建顶栏("家族系统", _on返回))

	# 标签栏
	var 标签栏: HBoxContainer = HBoxContainer.new()
	标签栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(标签栏)

	# ★ 2026-09-16（#009 逐页精修）：建钮循环收口到 UITheme.建标签栏（原先 19 页各自手搓，
	#   且 custom_minimum_size 宽度在 80/90/100/110 之间漂移）。统一为最小宽 100 + EXPAND_FILL
	#   ⇒ 少量页签自动均分不空、多量页签不溢出、宽度全局一致。
	_tab_btns = UITheme.建标签栏(标签栏, TABS, Callable(self, "_切换标签"), _cur)

	# 内容滚动区
	var 滚: ScrollContainer = ScrollContainer.new()
	滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(滚)

	# ★ PH7-13：正文原贴屏幕左边缘（x=0），与顶栏 36px 内边距不一致
	#   ⇒ 按 page_quest.gd 合规页口径套 UITheme.MARGIN 四边边距
	_body = MarginContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_right", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_top", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_bottom", UITheme.MARGIN)
	滚.add_child(_body)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_content)

	_刷新标签按钮()
	_刷新内容()


func _切换标签(标签名: String) -> void:
	_cur = 标签名
	_刷新标签按钮()
	_刷新内容()


func _刷新标签按钮() -> void:
	# ★ PH7-13：手搓页签高亮（选中 1.0/0.9/0.6、未选 0.7 灰，与全站口径不符）
	#   → 收口到 UITheme.刷新标签高亮（选中 1 / 未选 0.6，全项目既定口径）
	UITheme.刷新标签高亮(_tab_btns, _cur)
func _刷新内容() -> void:
	for c in _content.get_children():
		c.queue_free()

	# ★ PH7-13（D6）：原「发起联姻/结仇/联姻此家族」先 _添加空状态 再 _刷新内容()，
	#   刚加的结果行立刻被 queue_free ⇒ 玩家永远看不到操作反馈。改用 _提示 一次性呈现
	#   （_提示 字段原声明后从未被使用）。
	if _提示 != "":
		var 提示标签: Label = Label.new()
		提示标签.text = "· " + _提示
		提示标签.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS)
		提示标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_project_font(提示标签, UITheme.FONT_BODY)
		_content.add_child(提示标签)
		_提示 = ""

	match _cur:
		"总览":
			_填总览()
		"成员":
			_填成员()
		"宝库":
			_填宝库()
		"功法":
			_填功法()
		"秘宝":
			_填秘宝()
		"排行":
			_填排行()
# ==================== 总览页 ====================
func _填总览() -> void:
	# 检查是否有家族
	var 玩家家族ID: String = _获取玩家家族ID()
	if 玩家家族ID == "":
		_添加空状态("宗门尚无家族", "弟子可自行创立家族，或加入已有家族。待首位弟子立族后自显。")
		return

	_当前家族ID = 玩家家族ID
	var 详情: Dictionary = Game.获取家族完整详情(玩家家族ID)
	if 详情.is_empty():
		_添加空状态("家族数据加载失败", "请稍后重试。")
		return

	var 基本信息: Dictionary = 详情.get("基本信息", {})
	var 实力评分: Dictionary = 详情.get("实力评分", {})

	# 家族名称和等级
	var 名称栏: HBoxContainer = HBoxContainer.new()
	名称栏.add_theme_constant_override("separation", UITheme.GRID)
	_content.add_child(名称栏)

	var 家族名: Label = Label.new()
	家族名.text = "「%s」" % str(基本信息.get("名", "未知"))
	家族名.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	UITheme.apply_project_font(家族名, UITheme.FONT_H1, true)
	名称栏.add_child(家族名)

	var 等级标签: Label = Label.new()
	等级标签.text = "%d 阶" % int(基本信息.get("等级", 1))
	等级标签.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	等级标签.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# ★ PH7-13：原 FONT_TITLE(45) 与顶栏标题同级 ⇒ 降 H2(33)，层级 家族名48 > 等级33 > 正文27
	UITheme.apply_project_font(等级标签, UITheme.FONT_H2, true)
	名称栏.add_child(等级标签)

	var 兴衰标签: Label = Label.new()
	兴衰标签.text = "[%s]" % str(基本信息.get("兴衰周期", "未知"))
	兴衰标签.add_theme_color_override("font_color", Color(0.8, 0.6, 0.6))
	兴衰标签.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# ★ PH7-13：补齐字号（原落引擎默认 fs=15，实机取证）
	UITheme.apply_project_font(兴衰标签, UITheme.FONT_BODY)
	名称栏.add_child(兴衰标签)

	# 基本信息面板
	_添加面板标题("基本信息")
	var 信息网格: GridContainer = GridContainer.new()
	信息网格.columns = 2
	信息网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(信息网格)

	# ★ PH7-13（D1）：后端 family_system.gd 获取家族完整详情 的 基本信息 键名被写成
	#   "Game.声望"（非 "声望"）⇒ 原代码恒取默认 0。实机取证：家族声望 320 却显示 0。
	var 声望值: int = int(基本信息.get("声望", 基本信息.get("Game.声望", 0)))
	_添加信息项(信息网格, "家族声望", str(声望值))
	_添加信息项(信息网格, "贡献池", str(int(基本信息.get("贡献池", 0))))
	_添加信息项(信息网格, "成员数量", str(详情.get("成员数量", 0)))
	_添加信息项(信息网格, "创立时间", "第%d日" % int(基本信息.get("创立时间", 0)))
	# ★ PH7-13（D2）：后端把「血脉功法」Dictionary 直接 str() 化 ⇒ 原样显示 `{ "名": ... }`
	#   字典字面量。改取功法名（读 Game.获取家族 的原始字典，与「功法」页同源）。
	_添加信息项(信息网格, "血脉功法", _血脉功法名(玩家家族ID))
	_添加信息项(信息网格, "家族阵法", str(详情.get("阵法", "无")) if str(详情.get("阵法", "")) != "" else "未布置")

	# 实力评面板
	_添加面板标题("实力评分")
	var 评分总: Label = Label.new()
	评分总.text = "总评分：%d 分" % int(实力评分.get("评分", 0))
	评分总.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	# ★ PH7-13：原 FONT_TITLE(45) 与顶栏标题同级 ⇒ 降 H2(33)
	UITheme.apply_project_font(评分总, UITheme.FONT_H2, true)
	_content.add_child(评分总)

	var 评分网格: GridContainer = GridContainer.new()
	评分网格.columns = 2
	评分网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(评分网格)

	_添加信息项(评分网格, "等级分", "%d" % int(实力评分.get("等级分", 0)))
	_添加信息项(评分网格, "成员分", "%d" % int(实力评分.get("成员分", 0)))
	_添加信息项(评分网格, "道行分", "%d" % int(实力评分.get("战力分", 0)))
	_添加信息项(评分网格, "声望分", "%d" % int(实力评分.get("声望分", 0)))
	_添加信息项(评分网格, "阵法分", "%d" % int(实力评分.get("阵法分", 0)))
	_添加信息项(评分网格, "秘宝分", "%d" % int(实力评分.get("秘宝分", 0)))
	_添加信息项(评分网格, "总道行", str(int(实力评分.get("总战力", 0))))

	# 社交关系
	_添加面板标题("社交关系")
	var 联盟列表: Array = 详情.get("联盟", [])
	var 联姻列表: Array = 详情.get("联姻", [])
	var 敌对列表: Array = 详情.get("敌对", [])

	var 社交文本: Label = Label.new()
	社交文本.text = "联盟家族：%d 个  |  联姻家族：%d 个  |  敌对家族：%d 个" % [联盟列表.size(), 联姻列表.size(), 敌对列表.size()]
	社交文本.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	UITheme.apply_project_font(社交文本, UITheme.FONT_BODY)
	_content.add_child(社交文本)

	# 家族外交操作
	var 外交栏: HBoxContainer = HBoxContainer.new()
	外交栏.add_theme_constant_override("separation", UITheme.GRID)
	_content.add_child(外交栏)

	var 联姻按钮: Button = Button.new()
	联姻按钮.text = "发起联姻"
	联姻按钮.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	联姻按钮.pressed.connect(_on发起联姻)
	UITheme.apply_project_font(联姻按钮, UITheme.FONT_BODY, true)
	外交栏.add_child(联姻按钮)

	var 结仇按钮: Button = Button.new()
	结仇按钮.text = "发起结仇"
	结仇按钮.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	结仇按钮.pressed.connect(_on发起结仇)
	UITheme.apply_project_font(结仇按钮, UITheme.FONT_BODY, true)
	外交栏.add_child(结仇按钮)

	# 可联姻家族列表
	var 可联姻: Array = Game.获取可联姻家族()
	if not 可联姻.is_empty():
		var 可联姻标题: Label = Label.new()
		可联姻标题.text = "可联姻家族："
		可联姻标题.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
		可联姻标题.custom_minimum_size = Vector2(0, UITheme.GRID * 4)
		可联姻标题.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		UITheme.apply_project_font(可联姻标题, UITheme.FONT_BODY)
		_content.add_child(可联姻标题)
		for f in 可联姻:
			var 家族行: HBoxContainer = HBoxContainer.new()
			家族行.add_theme_constant_override("separation", UITheme.GRID)
			_content.add_child(家族行)
			var 候选家族名: Label = Label.new()
			候选家族名.text = "「%s」%d 阶" % [str(f.get("名称", "")), int(f.get("等级", 1))]
			候选家族名.custom_minimum_size = Vector2(0, UITheme.GRID * 4)
			候选家族名.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			候选家族名.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			UITheme.apply_project_font(候选家族名, UITheme.FONT_BODY)
			家族行.add_child(候选家族名)
			var 联姻此家族: Button = Button.new()
			联姻此家族.text = "联姻"
			联姻此家族.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
			联姻此家族.pressed.connect(Callable(self, "_on联姻此家族").bind(str(f.get("家族ID", ""))))
			UITheme.apply_project_font(联姻此家族, UITheme.FONT_BODY, true)
			家族行.add_child(联姻此家族)

	# 最近事件
	_添加面板标题("最近事件")
	var 事件列表: Array = 详情.get("最近事件", [])
	if 事件列表.is_empty():
		var 无事件: Label = Label.new()
		无事件.text = "暂无事件记录"
		无事件.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		UITheme.apply_project_font(无事件, UITheme.FONT_BODY)
		_content.add_child(无事件)
	else:
		for 事件 in 事件列表:
			var 事件行: Label = Label.new()
			事件行.text = "· %s" % str(事件)
			事件行.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
			事件行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UITheme.apply_project_font(事件行, UITheme.FONT_AUX)
			_content.add_child(事件行)
# ==================== 成员页 ====================
func _填成员() -> void:
	var 玩家家族ID: String = _获取玩家家族ID()
	if 玩家家族ID == "":
		_添加空状态("宗门尚无家族", "弟子可自行创立家族，或加入已有家族。")
		return

	var 成员列表: Array = Game.获取家族成员列表(玩家家族ID)
	if 成员列表.is_empty():
		_添加空状态("家族暂无成员", "家族成员列表为空。")
		return

	_添加面板标题("家族成员（共 %d 人）" % 成员列表.size())

	# ★ PH7-13：列宽按 FONT_AUX(21) 内容宽重算（原总宽 430 仅占屏 40%，且 21px 下
	#   境界/血脉列内容宽于列底 ⇒ 表头与数据行错列）；各列 EXPAND_FILL 均分剩余宽
	#   ＋ clip_text ⇒ 表头与数据行列宽恒等（对错列不敏感）。
	var 列宽: Array = [84, 108, 96, 84, 96, 132, 84]
	var 列名: Array = ["职位", "姓名", "境界", "资质", "道行", "血脉", "状态"]

	var 表头: HBoxContainer = HBoxContainer.new()
	表头.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(表头)

	for i in range(列名.size()):
		var 列标签: Label = Label.new()
		列标签.text = 列名[i]
		列标签.custom_minimum_size = Vector2(列宽[i], UITheme.GRID * 3)
		列标签.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		列标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		列标签.clip_text = true
		UITheme.apply_project_font(列标签, UITheme.FONT_AUX, true)
		表头.add_child(列标签)

	var 分隔: HSeparator = HSeparator.new()
	_content.add_child(分隔)

	for 成员 in 成员列表:
		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(行)
		行.modulate.a = 0.0
		行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)

		var 职位颜色: Color = Color(0.7, 0.7, 0.7)
		var 职位: String = str(成员.get("职位", "外门"))
		if 职位 == "老祖":
			职位颜色 = Color(1.0, 0.85, 0.4)
		elif 职位 == "长老":
			职位颜色 = Color(0.8, 0.7, 1.0)
		elif 职位 == "核心":
			职位颜色 = Color(0.7, 0.9, 1.0)
		_建表格单元(行, 职位, 列宽[0], 职位颜色, true)

		_建表格单元(行, str(成员.get("姓名", "未知")), 列宽[1], Color(0, 0, 0, 0))
		_建表格单元(行, str(成员.get("境界", "未知")), 列宽[2], Color(0, 0, 0, 0))
		# ★ PH7-13：资质原样输出内部码（实机取证显示 `fan_su`）⇒ 走 Disciple.资质显示 映射
		var 资质码: String = str(成员.get("资质", ""))
		_建表格单元(行, str(Disciple.资质显示.get(资质码, 资质码 if 资质码 != "" else "未知")), 列宽[3], Color(0, 0, 0, 0))
		_建表格单元(行, str(int(成员.get("战力", 0))), 列宽[4], Color(0.8, 0.9, 1.0), true)

		var 血脉: String = str(成员.get("血脉", "凡人血脉"))
		var 血脉觉醒: bool = bool(成员.get("血脉觉醒", false))
		if 血脉 != "凡人血脉":
			_建表格单元(行, 血脉 + ("★" if 血脉觉醒 else ""), 列宽[5], Color(1.0, 0.7, 0.7), true)
		else:
			_建表格单元(行, 血脉 + ("★" if 血脉觉醒 else ""), 列宽[5], Color(0, 0, 0, 0))

		if str(成员.get("状态", "")) == "在宗":
			_建表格单元(行, str(成员.get("状态", "未知")), 列宽[6], Color(0.6, 1.0, 0.6), true)
		else:
			_建表格单元(行, str(成员.get("状态", "未知")), 列宽[6], Color(0.7, 0.7, 0.5), true)
# ==================== 宝库页 ====================
func _填宝库() -> void:
	var 玩家家族ID: String = _获取玩家家族ID()
	if 玩家家族ID == "":
		_添加空状态("宗门尚无家族", "弟子可自行创立家族，或加入已有家族。")
		return

	var 宝库: Dictionary = Game.查看家族宝库(玩家家族ID)
	if 宝库.is_empty():
		_添加空状态("家族宝库为空", "家族成员可将物品存入家族宝库，供其他成员取用。")
		return

	_添加面板标题("家族宝库（共 %d 种物品）" % 宝库.size())

	for 物品ID in 宝库.keys():
		# ★ PH7-13（D3）：后端 家族宝库 形状为 {物品ID: 数量(int)}（见 family_system.gd
		#   存入家族宝库），原代码把值当 Dictionary 用 ⇒ 类型不符抛错、整段中断。此处容错两形。
		var 原始 = 宝库[物品ID]
		var 物品名文本: String = str(物品ID)
		var 品阶文本: String = "—"
		var 数量值: int = 0
		var 描述文本: String = ""
		if typeof(原始) == TYPE_DICTIONARY:
			物品名文本 = str(原始.get("名", 物品ID))
			品阶文本 = str(原始.get("品阶", "未知"))
			数量值 = int(原始.get("数量", 0))
			描述文本 = str(原始.get("描述", ""))
		else:
			数量值 = int(原始)

		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行.add_theme_constant_override("separation", UITheme.GRID)
		_content.add_child(行)
		行.modulate.a = 0.0
		行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)

		var 物品名: Label = Label.new()
		物品名.text = 物品名文本
		物品名.custom_minimum_size = Vector2(240, UITheme.GRID * 3)
		UITheme.apply_project_font(物品名, UITheme.FONT_BODY)
		行.add_child(物品名)

		var 品阶: Label = Label.new()
		品阶.text = "[%s]" % 品阶文本
		品阶.custom_minimum_size = Vector2(120, UITheme.GRID * 3)
		品阶.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		UITheme.apply_project_font(品阶, UITheme.FONT_AUX)
		行.add_child(品阶)

		var 数量: Label = Label.new()
		数量.text = "×%d" % 数量值
		数量.custom_minimum_size = Vector2(108, UITheme.GRID * 3)
		数量.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		UITheme.apply_project_font(数量, UITheme.FONT_AUX)
		行.add_child(数量)

		var 描述: Label = Label.new()
		描述.text = 描述文本
		描述.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		描述.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_project_font(描述, UITheme.FONT_AUX)
		行.add_child(描述)
# ==================== 功法页 ====================
func _填功法() -> void:
	var 玩家家族ID: String = _获取玩家家族ID()
	if 玩家家族ID == "":
		_添加空状态("宗门尚无家族", "弟子可自行创立家族，或加入已有家族。")
		return

	var 家族: Dictionary = Game.获取家族(玩家家族ID)
	if 家族.is_empty():
		_添加空状态("家族数据加载失败", "请稍后重试。")
		return

	# 血脉功法
	var 血脉功法: Dictionary = 家族.get("血脉功法", {})
	if typeof(血脉功法) != TYPE_DICTIONARY:
		血脉功法 = {}
	_添加面板标题("家传血脉功法")

	if 血脉功法.is_empty():
		var 无血脉: Label = Label.new()
		无血脉.text = "家族暂无血脉功法"
		无血脉.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		UITheme.apply_project_font(无血脉, UITheme.FONT_BODY)
		_content.add_child(无血脉)
	else:
		var 功法名: Label = Label.new()
		功法名.text = "「%s」" % str(血脉功法.get("名", "未知"))
		功法名.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		UITheme.apply_project_font(功法名, UITheme.FONT_H2, true)
		_content.add_child(功法名)

		var 功法描述: Label = Label.new()
		功法描述.text = str(血脉功法.get("描述", ""))
		功法描述.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		功法描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_project_font(功法描述, UITheme.FONT_BODY)
		_content.add_child(功法描述)

		var 创立时间: Label = Label.new()
		创立时间.text = "创立时间：第 %d 日" % int(血脉功法.get("创立时间", 0))
		创立时间.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		UITheme.apply_project_font(创立时间, UITheme.FONT_AUX)
		_content.add_child(创立时间)

	# 家族功法列表
	var 家族功法列表: Array = 家族.get("家族功法", [])
	_添加面板标题("家族功法（共 %d 部）" % 家族功法列表.size())

	if 家族功法列表.is_empty():
		var 无功法: Label = Label.new()
		无功法.text = "家族暂无其他功法"
		无功法.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		UITheme.apply_project_font(无功法, UITheme.FONT_BODY)
		_content.add_child(无功法)
	else:
		for 功法 in 家族功法列表:
			var 功法数据: Dictionary = 功法 if typeof(功法) == TYPE_DICTIONARY else {"名": str(功法)}
			var 行: HBoxContainer = HBoxContainer.new()
			行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			行.add_theme_constant_override("separation", UITheme.GRID)
			_content.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)

			var 名: Label = Label.new()
			名.text = "· %s" % str(功法数据.get("名", "未知"))
			名.custom_minimum_size = Vector2(300, UITheme.GRID * 3)
			UITheme.apply_project_font(名, UITheme.FONT_BODY)
			行.add_child(名)

			var 描述: Label = Label.new()
			描述.text = str(功法数据.get("描述", ""))
			描述.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			描述.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UITheme.apply_project_font(描述, UITheme.FONT_AUX)
			行.add_child(描述)
# ==================== 秘宝页 ====================
func _填秘宝() -> void:
	var 玩家家族ID: String = _获取玩家家族ID()
	if 玩家家族ID == "":
		_添加空状态("宗门尚无家族", "弟子可自行创立家族，或加入已有家族。")
		return

	var 家族: Dictionary = Game.获取家族(玩家家族ID)
	var 秘宝列表: Array = 家族.get("家族秘宝", [])

	_添加面板标题("家族秘宝（已拥有 %d 件）" % 秘宝列表.size())

	if 秘宝列表.is_empty():
		var 无秘宝: Label = Label.new()
		无秘宝.text = "家族暂无秘宝，可通过家族试炼或特殊事件获得。"
		无秘宝.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		无秘宝.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_project_font(无秘宝, UITheme.FONT_BODY)
		_content.add_child(无秘宝)
	else:
		for 秘宝ID in 秘宝列表:
			var 秘宝配置: Dictionary = _秘宝配置表().get(秘宝ID, {})
			if 秘宝配置.is_empty():
				continue

			var 行: VBoxContainer = VBoxContainer.new()
			行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)

			var 名栏: HBoxContainer = HBoxContainer.new()
			名栏.add_theme_constant_override("separation", UITheme.GRID)
			行.add_child(名栏)

			var 名: Label = Label.new()
			名.text = "◆ %s" % str(秘宝配置.get("名", "未知"))
			名.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
			UITheme.apply_project_font(名, UITheme.FONT_H2, true)
			名栏.add_child(名)

			var 类型: Label = Label.new()
			类型.text = "[%s]" % str(秘宝配置.get("类型", "未知"))
			类型.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
			类型.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			UITheme.apply_project_font(类型, UITheme.FONT_BODY)
			名栏.add_child(类型)

			var 效果: Label = Label.new()
			效果.text = "修炼加成 +%.1f%%  |  道行加成 +%.1f%%" % [float(秘宝配置.get("修炼加成", 0)) * 100, float(秘宝配置.get("战力加成", 0)) * 100]
			效果.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
			UITheme.apply_project_font(效果, UITheme.FONT_BODY)
			行.add_child(效果)

			var 描述: Label = Label.new()
			描述.text = str(秘宝配置.get("描述", ""))
			描述.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UITheme.apply_project_font(描述, UITheme.FONT_AUX)
			行.add_child(描述)

			var 分隔: HSeparator = HSeparator.new()
			行.add_child(分隔)

	# 可获得的秘宝列表
	_添加面板标题("传世秘宝图鉴")
	var 所有秘宝: Dictionary = _秘宝配置表()
	for 秘宝ID in 所有秘宝.keys():
		var 秘宝配置: Dictionary = 所有秘宝[秘宝ID]
		var 已拥有: bool = 秘宝列表.has(秘宝ID)

		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行.add_theme_constant_override("separation", UITheme.GRID)
		_content.add_child(行)
		行.modulate.a = 0.0
		行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)

		var 名: Label = Label.new()
		名.text = "%s %s" % ["✓" if 已拥有 else "○", str(秘宝配置.get("名", "未知"))]
		名.custom_minimum_size = Vector2(300, UITheme.GRID * 3)
		if 已拥有:
			名.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		else:
			名.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		UITheme.apply_project_font(名, UITheme.FONT_BODY)
		行.add_child(名)

		var 类型: Label = Label.new()
		类型.text = "[%s]" % str(秘宝配置.get("类型", "未知"))
		类型.custom_minimum_size = Vector2(120, UITheme.GRID * 3)
		UITheme.apply_project_font(类型, UITheme.FONT_AUX)
		行.add_child(类型)

		var 效果: Label = Label.new()
		效果.text = "修炼+%.1f%% 道行+%.1f%%" % [float(秘宝配置.get("修炼加成", 0)) * 100, float(秘宝配置.get("战力加成", 0)) * 100]
		效果.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		效果.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_project_font(效果, UITheme.FONT_AUX)
		行.add_child(效果)
# ==================== 排行页 ====================
func _填排行() -> void:
	var 汇总数据: Dictionary = Game.获取家族UI汇总数据()
	var 排行榜: Array = 汇总数据.get("家族排行榜", [])
	# ★ PH7-13（D4）：后端 获取家族UI汇总数据 按不存在的键 "总分" 排序 ⇒ 实为插入序
	#   （实机取证：2 阶家族排在 3 阶家族之前）。前端按真实键「评分」重排。
	排行榜 = 排行榜.duplicate()
	排行榜.sort_custom(func(a, b): return int(a.get("实力评分", {}).get("评分", 0)) > int(b.get("实力评分", {}).get("评分", 0)))

	if 排行榜.is_empty():
		_添加空状态("暂无家族排行", "当前尚无任何家族，待首族立后自显。")
		return

	_添加面板标题("家族排行榜（共 %d 个家族）" % 排行榜.size())

	var 排名列宽: Array = [84, 240, 96, 96, 132, 108]
	var 排名列名: Array = ["排名", "家族名", "等级", "成员", "总道行", "评分"]

	var 表头: HBoxContainer = HBoxContainer.new()
	表头.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(表头)

	for i in range(排名列名.size()):
		var 列标签: Label = Label.new()
		列标签.text = 排名列名[i]
		列标签.custom_minimum_size = Vector2(排名列宽[i], UITheme.GRID * 3)
		列标签.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		列标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		列标签.clip_text = true
		UITheme.apply_project_font(列标签, UITheme.FONT_AUX, true)
		表头.add_child(列标签)

	var 分隔: HSeparator = HSeparator.new()
	_content.add_child(分隔)

	var 玩家家族ID: String = _获取玩家家族ID()
	for i in range(排行榜.size()):
		var 家族数据: Dictionary = 排行榜[i]
		var 基本信息: Dictionary = 家族数据.get("基本信息", {})
		var 实力评分: Dictionary = 家族数据.get("实力评分", {})

		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(行)
		行.modulate.a = 0.0
		行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)

		var 是玩家家族: bool = str(基本信息.get("ID", "")) == 玩家家族ID

		var 排名颜色: Color = Color(0.7, 0.7, 0.7)
		var 排名文本: String = str(i + 1)
		if i == 0:
			排名颜色 = Color(1.0, 0.85, 0.3)
			排名文本 = "★"
		elif i == 1:
			排名颜色 = Color(0.8, 0.8, 0.9)
			排名文本 = "★"
		elif i == 2:
			排名颜色 = Color(0.8, 0.5, 0.3)
			排名文本 = "★"
		_建表格单元(行, 排名文本, 排名列宽[0], 排名颜色, true)

		_建表格单元(行, str(基本信息.get("名", "未知")) + (" (我方)" if 是玩家家族 else ""), 排名列宽[1], Color(0.6, 1.0, 0.8), 是玩家家族)
		_建表格单元(行, "%d 阶" % int(基本信息.get("等级", 1)), 排名列宽[2], Color(0, 0, 0, 0))
		_建表格单元(行, str(家族数据.get("成员数量", 0)), 排名列宽[3], Color(0, 0, 0, 0))
		_建表格单元(行, str(int(实力评分.get("总战力", 0))), 排名列宽[4], Color(0.7, 0.9, 1.0), true)
		# ★ PH7-13：评分键在实力评分里叫「评分」（后端另有不存在的 "总分"）
		_建表格单元(行, str(int(实力评分.get("评分", 0))), 排名列宽[5], Color(1.0, 0.9, 0.5), true)

	# 资源点
	_添加面板标题("资源点争夺")
	var 资源点列表: Array = 汇总数据.get("资源点", [])
	for 资源点 in 资源点列表:
		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行.add_theme_constant_override("separation", UITheme.GRID)
		_content.add_child(行)
		行.modulate.a = 0.0
		行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)

		var 名: Label = Label.new()
		名.text = "· %s" % str(资源点.get("名", "未知"))
		名.custom_minimum_size = Vector2(240, UITheme.GRID * 3)
		UITheme.apply_project_font(名, UITheme.FONT_BODY)
		行.add_child(名)

		var 产出: Label = Label.new()
		产出.text = str(资源点.get("产出", ""))
		产出.custom_minimum_size = Vector2(240, UITheme.GRID * 3)
		产出.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		UITheme.apply_project_font(产出, UITheme.FONT_AUX)
		行.add_child(产出)

		var 占领者: Label = Label.new()
		占领者.text = "占领者：%s" % str(资源点.get("占领者", "无"))
		占领者.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		占领者.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_project_font(占领者, UITheme.FONT_AUX)
		行.add_child(占领者)
# ==================== 工具函数 ====================
# ==================== PH7-13 新增 helper（均有调用方） ====================
func _建表格单元(行: HBoxContainer, 文本: String, 宽: int, 色: Color, 上色: bool = false) -> Label:
	# ★ PH7-13：家族页两张表（成员/排行）原为逐行手搓 Label。统一走本 helper：
	#   列底宽 + EXPAND_FILL + clip_text ⇒ 表头与数据行**列宽恒等**（不因内容长短错列）。
	var 单元: Label = Label.new()
	单元.text = 文本
	单元.custom_minimum_size = Vector2(宽, UITheme.GRID * 3)
	单元.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	单元.clip_text = true
	单元.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if 上色:
		单元.add_theme_color_override("font_color", 色)
	UITheme.apply_project_font(单元, UITheme.FONT_AUX)
	行.add_child(单元)
	return 单元


func _血脉功法名(家族ID: String) -> String:
	# ★ PH7-13（D2）：获取家族完整详情 里的「血脉功法」被后端 str() 化 ⇒ 取原始家族字典的「名」。
	var 家族: Dictionary = Game.获取家族(家族ID)
	var 血缘 = 家族.get("血脉功法", {})
	if typeof(血缘) == TYPE_DICTIONARY:
		if 血缘.is_empty():
			return "无"
		return str(血缘.get("名", "无"))
	var 文本: String = str(血缘)
	return 文本 if 文本 != "" else "无"


func _秘宝配置表() -> Dictionary:
	# ★ PH7-13（D5）：原代码读 Game._家族秘宝配置 —— 该变量实际挂在 Game.家族系统
	#   （FamilySystem 实例）上 ⇒ `"_家族秘宝配置" in Game` 恒 false，秘宝页恒空。
	var 家族系统实例: FamilySystem = Game.家族系统
	if 家族系统实例 == null:
		return {}
	if "_家族秘宝配置" in 家族系统实例:
		return 家族系统实例._家族秘宝配置
	return {}

func _获取玩家家族ID() -> String:
	# 遍历所有弟子，找到第一个有家族ID的
	for d in Game.弟子列表:
		if d != null and d is Disciple and d.家族ID != "":
			return d.家族ID
	return ""


func _添加空状态(标题: String, 描述: String) -> void:
	var 空状态: VBoxContainer = VBoxContainer.new()
	空状态.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	空状态.add_theme_constant_override("separation", 10)
	_content.add_child(空状态)

	var 空标题: Label = Label.new()
	空标题.text = 标题
	空标题.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	# ★ PH7-13：原 FONT_TITLE(45) 与顶栏标题同级 ⇒ 降 H2(33)，层级不塌
	UITheme.apply_project_font(空标题, UITheme.FONT_H2, true)
	空标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	空状态.add_child(空标题)

	var 空描述: Label = Label.new()
	空描述.text = 描述
	空描述.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	# ★ PH7-13：补齐正文字号（原落引擎默认 fs=15，实机取证）
	UITheme.apply_project_font(空描述, UITheme.FONT_BODY)
	空描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	空描述.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	空状态.add_child(空描述)
func _添加面板标题(标题: String) -> void:
	var 间距: Control = Control.new()
	间距.custom_minimum_size = Vector2(0, UITheme.GRID)
	_content.add_child(间距)

	var 标题标签: Label = Label.new()
	标题标签.text = "▎ %s" % 标题
	# ★ PH7-13：硬编码金 Color(0.85,0.75,0.5) → 语义角色 apply_section_title（33 Bold 米白）
	UITheme.apply_section_title(标题标签)
	_content.add_child(标题标签)

	var 分隔: HSeparator = HSeparator.new()
	_content.add_child(分隔)
func _添加信息项(网格: GridContainer, 标签: String, 值: String) -> void:
	var 标签控件: Label = Label.new()
	标签控件.text = 标签 + "："
	标签控件.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	标签控件.custom_minimum_size = Vector2(150, UITheme.GRID * 3)
	# ★ PH7-13：补齐字号（原落引擎默认 fs=15）——标签 AUX / 值 BODY
	UITheme.apply_project_font(标签控件, UITheme.FONT_AUX)
	网格.add_child(标签控件)

	var 值控件: Label = Label.new()
	值控件.text = 值
	值控件.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	值控件.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ★ 注意：此处**不可**开 autowrap —— GridContainer 无伸缩列时 autowrap 会把最小宽压到 1px，
	#   整列塌陷 + 逐字换行导致行高暴涨（2026-09-18 首轮 after 帧实测 1×341 的畸形单元）。
	UITheme.apply_project_font(值控件, UITheme.FONT_BODY)
	网格.add_child(值控件)
func _on返回() -> void:
	返回主页.emit()


func _on发起联姻() -> void:
	# ★ PH7-13（D6）：原实现只 _刷新内容()（无任何提示）；改为给出可执行引导
	_提示 = "请从下方「可联姻家族」中择一，发起秦晋之好。"
	_刷新内容()
func _on发起结仇() -> void:
	# 简化：随机选择一个家族结仇
	var 可联姻: Array = Game.获取可联姻家族()
	if 可联姻.is_empty():
		_提示 = "当前没有可结仇的目标家族。"
		_刷新内容()
		return
	var 目标: Dictionary = 可联姻[randi() % 可联姻.size()]
	var 结果: Dictionary = Game.发起家族结仇(str(目标.get("家族ID", "")), "利益冲突")
	if bool(结果.get("成功", false)):
		_提示 = "与「%s」结为敌对家族！" % str(目标.get("名称", ""))
	else:
		_提示 = "结仇未成：%s" % str(结果.get("原因", "未知错误"))
	_刷新内容()
func _on联姻此家族(家族ID: String) -> void:
	var 结果: Dictionary = Game.发起家族联姻(家族ID)
	if bool(结果.get("成功", false)):
		_提示 = "与「%s」结为秦晋之好！" % str(结果.get("家族2", ""))
	else:
		_提示 = "联姻未成：%s" % str(结果.get("原因", "未知错误"))
	_刷新内容()

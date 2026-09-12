extends Control
# 家族系统UI：总览 / 成员 / 宝库 / 功法 / 秘宝 / 排行
# 后端：game_state.gd 家族系统（60+函数已完整实现）
# 入口：main.gd 宗门页快捷网格「家族」→ 二级页
# 代码纪律：局部变量一律 `var x: Type = ...`（禁 := walrus）；按钮回调用 Callable.connect。

signal 返回主页

const TABS: Array = ["总览", "成员", "宝库", "功法", "秘宝", "排行"]

var _built: bool = false
var _cur: String = "总览"
var _body: VBoxContainer = null
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

	# 顶部返回栏
	var 顶栏: HBoxContainer = HBoxContainer.new()
	顶栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(顶栏)

	var 返回按钮: Button = Button.new()
	返回按钮.text = "← 返回宗门"
	返回按钮.custom_minimum_size = Vector2(120, 36)
	返回按钮.pressed.connect(_on返回)
	顶栏.add_child(返回按钮)

	var 标题: Label = Label.new()
	标题.text = "  家族系统"
	标题.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	标题.add_theme_font_size_override("font_size", 20)
	顶栏.add_child(标题)

	# 标签栏
	var 标签栏: HBoxContainer = HBoxContainer.new()
	标签栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(标签栏)

	for 标签名 in TABS:
		var 按钮: Button = Button.new()
		按钮.text = 标签名
		按钮.custom_minimum_size = Vector2(80, 32)
		按钮.pressed.connect(Callable(self, "_切换标签").bind(标签名))
		标签栏.add_child(按钮)
		_tab_btns[标签名] = 按钮

	# 内容滚动区
	var 滚: ScrollContainer = ScrollContainer.new()
	滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(滚)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	for 标签名 in _tab_btns.keys():
		var 按钮: Button = _tab_btns[标签名]
		if 标签名 == _cur:
			按钮.modulate = Color(1.0, 0.9, 0.6)
		else:
			按钮.modulate = Color(0.7, 0.7, 0.7)


func _刷新内容() -> void:
	for c in _content.get_children():
		c.queue_free()

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
		_添加空状态("宗门尚无家族", "弟子可自行创立家族，或加入已有家族。家族系统将在第一位弟子创立家族后激活。")
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
	_content.add_child(名称栏)

	var 家族名: Label = Label.new()
	家族名.text = "「%s」" % str(基本信息.get("名", "未知"))
	家族名.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	家族名.add_theme_font_size_override("font_size", 24)
	名称栏.add_child(家族名)

	var 等级标签: Label = Label.new()
	等级标签.text = "  Lv.%d" % int(基本信息.get("等级", 1))
	等级标签.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	等级标签.add_theme_font_size_override("font_size", 18)
	名称栏.add_child(等级标签)

	var 兴衰标签: Label = Label.new()
	兴衰标签.text = "  [%s]" % str(基本信息.get("兴衰周期", "未知"))
	兴衰标签.add_theme_color_override("font_color", Color(0.8, 0.6, 0.6))
	名称栏.add_child(兴衰标签)

	# 基本信息面板
	_添加面板标题("基本信息")
	var 信息网格: GridContainer = GridContainer.new()
	信息网格.columns = 2
	信息网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(信息网格)

	_添加信息项(信息网格, "家族声望", str(int(基本信息.get("声望", 0))))
	_添加信息项(信息网格, "贡献池", str(int(基本信息.get("贡献池", 0))))
	_添加信息项(信息网格, "成员数量", str(详情.get("成员数量", 0)))
	_添加信息项(信息网格, "创立时间", "第%d日" % int(基本信息.get("创立时间", 0)))
	_添加信息项(信息网格, "血脉功法", str(详情.get("血脉功法", "无")))
	_添加信息项(信息网格, "家族阵法", str(详情.get("阵法", "无")) if str(详情.get("阵法", "")) != "" else "未布置")

	# 实力评面板
	_添加面板标题("实力评分")
	var 评分总: Label = Label.new()
	评分总.text = "总评分：%d 分" % int(实力评分.get("评分", 0))
	评分总.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	评分总.add_theme_font_size_override("font_size", 18)
	_content.add_child(评分总)

	var 评分网格: GridContainer = GridContainer.new()
	评分网格.columns = 2
	评分网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(评分网格)

	_添加信息项(评分网格, "等级分", "%d" % int(实力评分.get("等级分", 0)))
	_添加信息项(评分网格, "成员分", "%d" % int(实力评分.get("成员分", 0)))
	_添加信息项(评分网格, "战力分", "%d" % int(实力评分.get("战力分", 0)))
	_添加信息项(评分网格, "声望分", "%d" % int(实力评分.get("声望分", 0)))
	_添加信息项(评分网格, "阵法分", "%d" % int(实力评分.get("阵法分", 0)))
	_添加信息项(评分网格, "秘宝分", "%d" % int(实力评分.get("秘宝分", 0)))
	_添加信息项(评分网格, "总战力", str(int(实力评分.get("总战力", 0))))

	# 社交关系
	_添加面板标题("社交关系")
	var 联盟列表: Array = 详情.get("联盟", [])
	var 联姻列表: Array = 详情.get("联姻", [])
	var 敌对列表: Array = 详情.get("敌对", [])

	var 社交文本: Label = Label.new()
	社交文本.text = "联盟家族：%d 个  |  联姻家族：%d 个  |  敌对家族：%d 个" % [联盟列表.size(), 联姻列表.size(), 敌对列表.size()]
	社交文本.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_content.add_child(社交文本)

	# 家族外交操作
	var 外交栏: HBoxContainer = HBoxContainer.new()
	_content.add_child(外交栏)

	var 联姻按钮: Button = Button.new()
	联姻按钮.text = "发起联姻"
	联姻按钮.custom_minimum_size = Vector2(100, 32)
	联姻按钮.pressed.connect(_on发起联姻)
	外交栏.add_child(联姻按钮)

	var 结仇按钮: Button = Button.new()
	结仇按钮.text = "发起结仇"
	结仇按钮.custom_minimum_size = Vector2(100, 32)
	结仇按钮.pressed.connect(_on发起结仇)
	外交栏.add_child(结仇按钮)

	# 可联姻家族列表
	var 可联姻: Array = Game.获取可联姻家族()
	if not 可联姻.is_empty():
		var 可联姻标题: Label = Label.new()
		可联姻标题.text = "\n可联姻家族："
		可联姻标题.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
		_content.add_child(可联姻标题)
		for f in 可联姻:
			var 家族行: HBoxContainer = HBoxContainer.new()
			_content.add_child(家族行)
			var 候选家族名: Label = Label.new()
			候选家族名.text = "  「%s」Lv.%d" % [str(f.get("名称", "")), int(f.get("等级", 1))]
			候选家族名.custom_minimum_size = Vector2(150, 24)
			家族行.add_child(候选家族名)
			var 联姻此家族: Button = Button.new()
			联姻此家族.text = "联姻"
			联姻此家族.custom_minimum_size = Vector2(60, 24)
			联姻此家族.pressed.connect(Callable(self, "_on联姻此家族").bind(str(f.get("家族ID", ""))))
			家族行.add_child(联姻此家族)

	# 最近事件
	_添加面板标题("最近事件")
	var 事件列表: Array = 详情.get("最近事件", [])
	if 事件列表.is_empty():
		var 无事件: Label = Label.new()
		无事件.text = "暂无事件记录"
		无事件.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_content.add_child(无事件)
	else:
		for 事件 in 事件列表:
			var 事件行: Label = Label.new()
			事件行.text = "· %s" % str(事件)
			事件行.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
			事件行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

	# 表头
	var 表头: HBoxContainer = HBoxContainer.new()
	表头.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(表头)

	var 列宽: Array = [60, 80, 60, 50, 60, 60, 60]
	var 列名: Array = ["职位", "姓名", "境界", "资质", "战力", "血脉", "状态"]
	for i in range(列名.size()):
		var 列标签: Label = Label.new()
		列标签.text = 列名[i]
		列标签.custom_minimum_size = Vector2(列宽[i], 24)
		列标签.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		表头.add_child(列标签)

	# 分隔线
	var 分隔: HSeparator = HSeparator.new()
	_content.add_child(分隔)

	# 成员列表
	for 成员 in 成员列表:
		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(行)

		var 职位颜色: Color = Color(0.7, 0.7, 0.7)
		var 职位: String = str(成员.get("职位", "外门"))
		if 职位 == "老祖":
			职位颜色 = Color(1.0, 0.85, 0.4)
		elif 职位 == "长老":
			职位颜色 = Color(0.8, 0.7, 1.0)
		elif 职位 == "核心":
			职位颜色 = Color(0.7, 0.9, 1.0)

		var 职位标签: Label = Label.new()
		职位标签.text = 职位
		职位标签.custom_minimum_size = Vector2(列宽[0], 24)
		职位标签.add_theme_color_override("font_color", 职位颜色)
		行.add_child(职位标签)

		var 姓名标签: Label = Label.new()
		姓名标签.text = str(成员.get("姓名", "未知"))
		姓名标签.custom_minimum_size = Vector2(列宽[1], 24)
		行.add_child(姓名标签)

		var 境界标签: Label = Label.new()
		境界标签.text = str(成员.get("境界", "未知"))
		境界标签.custom_minimum_size = Vector2(列宽[2], 24)
		行.add_child(境界标签)

		var 资质标签: Label = Label.new()
		资质标签.text = str(成员.get("资质", "未知"))
		资质标签.custom_minimum_size = Vector2(列宽[3], 24)
		行.add_child(资质标签)

		var 战力标签: Label = Label.new()
		战力标签.text = str(int(成员.get("战力", 0)))
		战力标签.custom_minimum_size = Vector2(列宽[4], 24)
		战力标签.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		行.add_child(战力标签)

		var 血脉标签: Label = Label.new()
		var 血脉: String = str(成员.get("血脉", "凡人血脉"))
		var 血脉觉醒: bool = bool(成员.get("血脉觉醒", false))
		血脉标签.text = 血脉 + ("★" if 血脉觉醒 else "")
		血脉标签.custom_minimum_size = Vector2(列宽[5], 24)
		if 血脉 != "凡人血脉":
			血脉标签.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
		行.add_child(血脉标签)

		var 状态标签: Label = Label.new()
		状态标签.text = str(成员.get("状态", "未知"))
		状态标签.custom_minimum_size = Vector2(列宽[6], 24)
		if str(成员.get("状态", "")) == "在宗":
			状态标签.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		else:
			状态标签.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
		行.add_child(状态标签)


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
		var 物品数据: Dictionary = 宝库[物品ID]
		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(行)

		var 物品名: Label = Label.new()
		物品名.text = str(物品数据.get("名", 物品ID))
		物品名.custom_minimum_size = Vector2(150, 24)
		行.add_child(物品名)

		var 品阶: Label = Label.new()
		品阶.text = "[%s]" % str(物品数据.get("品阶", "未知"))
		品阶.custom_minimum_size = Vector2(80, 24)
		品阶.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		行.add_child(品阶)

		var 数量: Label = Label.new()
		数量.text = "×%d" % int(物品数据.get("数量", 0))
		数量.custom_minimum_size = Vector2(60, 24)
		数量.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		行.add_child(数量)

		var 描述: Label = Label.new()
		描述.text = str(物品数据.get("描述", ""))
		描述.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_添加面板标题("家传血脉功法")

	if 血脉功法.is_empty():
		var 无血脉: Label = Label.new()
		无血脉.text = "家族暂无血脉功法"
		无血脉.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_content.add_child(无血脉)
	else:
		var 功法名: Label = Label.new()
		功法名.text = "「%s」" % str(血脉功法.get("名", "未知"))
		功法名.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		功法名.add_theme_font_size_override("font_size", 18)
		_content.add_child(功法名)

		var 功法描述: Label = Label.new()
		功法描述.text = str(血脉功法.get("描述", ""))
		功法描述.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		功法描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(功法描述)

		var 创立时间: Label = Label.new()
		创立时间.text = "创立时间：第 %d 日" % int(血脉功法.get("创立时间", 0))
		创立时间.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_content.add_child(创立时间)

	# 家族功法列表
	var 家族功法列表: Array = 家族.get("家族功法", [])
	_添加面板标题("家族功法（共 %d 部）" % 家族功法列表.size())

	if 家族功法列表.is_empty():
		var 无功法: Label = Label.new()
		无功法.text = "家族暂无其他功法"
		无功法.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_content.add_child(无功法)
	else:
		for 功法 in 家族功法列表:
			var 功法数据: Dictionary = 功法 if typeof(功法) == TYPE_DICTIONARY else {"名": str(功法)}
			var 行: HBoxContainer = HBoxContainer.new()
			行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content.add_child(行)

			var 名: Label = Label.new()
			名.text = "· %s" % str(功法数据.get("名", "未知"))
			名.custom_minimum_size = Vector2(150, 24)
			行.add_child(名)

			var 描述: Label = Label.new()
			描述.text = str(功法数据.get("描述", ""))
			描述.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		_content.add_child(无秘宝)
	else:
		for 秘宝ID in 秘宝列表:
			var 秘宝配置: Dictionary = Game._家族秘宝配置.get(秘宝ID, {}) if "_家族秘宝配置" in Game else {}
			if 秘宝配置.is_empty():
				continue

			var 行: VBoxContainer = VBoxContainer.new()
			行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content.add_child(行)

			var 名栏: HBoxContainer = HBoxContainer.new()
			行.add_child(名栏)

			var 名: Label = Label.new()
			名.text = "◆ %s" % str(秘宝配置.get("名", "未知"))
			名.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
			名.add_theme_font_size_override("font_size", 16)
			名栏.add_child(名)

			var 类型: Label = Label.new()
			类型.text = "  [%s]" % str(秘宝配置.get("类型", "未知"))
			类型.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
			名栏.add_child(类型)

			var 效果: Label = Label.new()
			效果.text = "修炼加成 +%.1f%%  |  战力加成 +%.1f%%" % [float(秘宝配置.get("修炼加成", 0)) * 100, float(秘宝配置.get("战力加成", 0)) * 100]
			效果.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
			行.add_child(效果)

			var 描述: Label = Label.new()
			描述.text = str(秘宝配置.get("描述", ""))
			描述.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			行.add_child(描述)

			var 分隔: HSeparator = HSeparator.new()
			行.add_child(分隔)

	# 可获得的秘宝列表
	_添加面板标题("传世秘宝图鉴")
	var 所有秘宝: Dictionary = Game._家族秘宝配置 if "_家族秘宝配置" in Game else {}
	for 秘宝ID in 所有秘宝.keys():
		var 秘宝配置: Dictionary = 所有秘宝[秘宝ID]
		var 已拥有: bool = 秘宝列表.has(秘宝ID)

		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(行)

		var 名: Label = Label.new()
		名.text = "%s %s" % ["✓" if 已拥有 else "○", str(秘宝配置.get("名", "未知"))]
		名.custom_minimum_size = Vector2(150, 24)
		if 已拥有:
			名.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		else:
			名.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		行.add_child(名)

		var 类型: Label = Label.new()
		类型.text = "[%s]" % str(秘宝配置.get("类型", "未知"))
		类型.custom_minimum_size = Vector2(60, 24)
		行.add_child(类型)

		var 效果: Label = Label.new()
		效果.text = "修炼+%.1f%% 战力+%.1f%%" % [float(秘宝配置.get("修炼加成", 0)) * 100, float(秘宝配置.get("战力加成", 0)) * 100]
		效果.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		行.add_child(效果)


# ==================== 排行页 ====================
func _填排行() -> void:
	var 汇总数据: Dictionary = Game.获取家族UI汇总数据()
	var 排行榜: Array = 汇总数据.get("家族排行榜", [])

	if 排行榜.is_empty():
		_添加空状态("暂无家族排行", "当前尚无任何家族，排行将在第一个家族创立后激活。")
		return

	_添加面板标题("家族排行榜（共 %d 个家族）" % 排行榜.size())

	# 表头
	var 表头: HBoxContainer = HBoxContainer.new()
	表头.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(表头)

	var 排名列宽: Array = [50, 120, 60, 60, 80, 80]
	var 排名列名: Array = ["排名", "家族名", "等级", "成员", "总战力", "评分"]
	for i in range(排名列名.size()):
		var 列标签: Label = Label.new()
		列标签.text = 排名列名[i]
		列标签.custom_minimum_size = Vector2(排名列宽[i], 24)
		列标签.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		表头.add_child(列标签)

	var 分隔: HSeparator = HSeparator.new()
	_content.add_child(分隔)

	# 排行榜
	var 玩家家族ID: String = _获取玩家家族ID()
	for i in range(排行榜.size()):
		var 家族数据: Dictionary = 排行榜[i]
		var 基本信息: Dictionary = 家族数据.get("基本信息", {})
		var 实力评分: Dictionary = 家族数据.get("实力评分", {})

		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(行)

		var 是玩家家族: bool = str(基本信息.get("ID", "")) == 玩家家族ID

		var 排名颜色: Color = Color(0.7, 0.7, 0.7)
		var 排名文本: String = str(i + 1)
		if i == 0:
			排名颜色 = Color(1.0, 0.85, 0.3)
			排名文本 = "🥇"
		elif i == 1:
			排名颜色 = Color(0.8, 0.8, 0.9)
			排名文本 = "🥈"
		elif i == 2:
			排名颜色 = Color(0.8, 0.5, 0.3)
			排名文本 = "🥉"

		var 排名标签: Label = Label.new()
		排名标签.text = 排名文本
		排名标签.custom_minimum_size = Vector2(排名列宽[0], 24)
		排名标签.add_theme_color_override("font_color", 排名颜色)
		行.add_child(排名标签)

		var 家族名标签: Label = Label.new()
		家族名标签.text = str(基本信息.get("名", "未知")) + (" (我方)" if 是玩家家族 else "")
		家族名标签.custom_minimum_size = Vector2(排名列宽[1], 24)
		if 是玩家家族:
			家族名标签.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
		行.add_child(家族名标签)

		var 等级标签: Label = Label.new()
		等级标签.text = "Lv.%d" % int(基本信息.get("等级", 1))
		等级标签.custom_minimum_size = Vector2(排名列宽[2], 24)
		行.add_child(等级标签)

		var 成员标签: Label = Label.new()
		成员标签.text = str(家族数据.get("成员数量", 0))
		成员标签.custom_minimum_size = Vector2(排名列宽[3], 24)
		行.add_child(成员标签)

		var 战力标签: Label = Label.new()
		战力标签.text = str(int(实力评分.get("总战力", 0)))
		战力标签.custom_minimum_size = Vector2(排名列宽[4], 24)
		战力标签.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		行.add_child(战力标签)

		var 评分标签: Label = Label.new()
		评分标签.text = str(int(实力评分.get("评分", 0)))
		评分标签.custom_minimum_size = Vector2(排名列宽[5], 24)
		评分标签.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		行.add_child(评分标签)

	# 资源点
	_添加面板标题("资源点争夺")
	var 资源点列表: Array = 汇总数据.get("资源点", [])
	for 资源点 in 资源点列表:
		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(行)

		var 名: Label = Label.new()
		名.text = "· %s" % str(资源点.get("名", "未知"))
		名.custom_minimum_size = Vector2(120, 24)
		行.add_child(名)

		var 产出: Label = Label.new()
		产出.text = str(资源点.get("产出", ""))
		产出.custom_minimum_size = Vector2(120, 24)
		产出.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		行.add_child(产出)

		var 占领者: Label = Label.new()
		占领者.text = "占领者：%s" % str(资源点.get("占领者", "无"))
		占领者.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		行.add_child(占领者)


# ==================== 工具函数 ====================
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
	空标题.add_theme_font_size_override("font_size", 18)
	空标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	空状态.add_child(空标题)

	var 空描述: Label = Label.new()
	空描述.text = 描述
	空描述.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	空描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	空描述.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	空状态.add_child(空描述)


func _添加面板标题(标题: String) -> void:
	var 间距: Control = Control.new()
	间距.custom_minimum_size = Vector2(0, 8)
	_content.add_child(间距)

	var 标题标签: Label = Label.new()
	标题标签.text = "▎ %s" % 标题
	标题标签.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	标题标签.add_theme_font_size_override("font_size", 16)
	_content.add_child(标题标签)

	var 分隔: HSeparator = HSeparator.new()
	_content.add_child(分隔)


func _添加信息项(网格: GridContainer, 标签: String, 值: String) -> void:
	var 标签控件: Label = Label.new()
	标签控件.text = 标签 + "："
	标签控件.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	标签控件.custom_minimum_size = Vector2(100, 24)
	网格.add_child(标签控件)

	var 值控件: Label = Label.new()
	值控件.text = 值
	值控件.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	网格.add_child(值控件)


func _on返回() -> void:
	返回主页.emit()


func _on发起联姻() -> void:
	_刷新内容()


func _on发起结仇() -> void:
	# 简化：随机选择一个家族结仇
	var 可联姻: Array = Game.获取可联姻家族()
	if 可联姻.is_empty():
		_添加空状态("无可结仇家族", "当前没有可结仇的目标家族。")
		return
	var 目标: Dictionary = 可联姻[randi() % 可联姻.size()]
	var 结果: Dictionary = Game.发起家族结仇(str(目标.get("家族ID", "")), "利益冲突")
	if bool(结果.get("成功", false)):
		_添加空状态("结仇成功", "与「%s」结为敌对家族！" % str(目标.get("名称", "")))
	else:
		_添加空状态("结仇失败", str(结果.get("原因", "未知错误")))
	_刷新内容()


func _on联姻此家族(家族ID: String) -> void:
	var 结果: Dictionary = Game.发起家族联姻(家族ID)
	if bool(结果.get("成功", false)):
		_添加空状态("联姻成功", "与「%s」结为秦晋之好！" % str(结果.get("家族2", "")))
	else:
		_添加空状态("联姻失败", str(结果.get("原因", "未知错误")))
	_刷新内容()

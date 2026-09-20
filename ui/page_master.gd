extends Control
# 宗主修炼界面UI：总览 / 修炼 / 技艺 / 装备 / 背包
# 后端：game_state.gd 宗主实体（Disciple复用）
# 入口：game_ui.gd ENTRY_SUB_PAGES

signal 返回主页

const TABS: Array = ["总览", "修炼", "技艺", "装备", "背包", "管理"]

var _built: bool = false
var _cur: String = "总览"
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}


func _ready() -> void:
	_build()


func refresh() -> void:
	if _built:
		_render()


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
	main.add_theme_constant_override("margin_left", UITheme.MARGIN)
	main.add_theme_constant_override("margin_right", UITheme.MARGIN)
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
	标题.text = "  宗主修炼"
	标题.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	UITheme.apply_project_font(标题, UITheme.FONT_TITLE, true)
	顶栏.add_child(标题)

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

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚.add_child(_content)

	_render()


func _切换标签(标签名: String) -> void:
	_cur = 标签名
	for k in _tab_btns.keys():
		var btn: Button = _tab_btns[k]
		if k == 标签名:
			btn.modulate = Color(1.0, 0.9, 0.6)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)
	_render()


func _on返回() -> void:
	返回主页.emit()


func _render() -> void:
	if _content == null:
		return
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()

	if Game == null or Game.宗主 == null:
		var 提示: Label = Label.new()
		提示.text = "宗主数据尚未就绪，请重新读档"
		UITheme.apply_body_text(提示)
		_content.add_child(提示)
		return

	match _cur:
		"总览":
			_render总览()
		"修炼":
			_render修炼()
		"技艺":
			_render技艺()
		"装备":
			_render装备()
		"背包":
			_render背包()
		"管理":
			_render管理()


func _render总览() -> void:
	var m: Disciple = Game.宗主

	# 宗主头像和基本信息
	var 信息区: VBoxContainer = VBoxContainer.new()
	信息区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(信息区)

	var 名栏: HBoxContainer = HBoxContainer.new()
	信息区.add_child(名栏)

	var 名: Label = Label.new()
	名.text = "【宗主】%s" % str(m.姓名)
	名.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	UITheme.apply_project_font(名, UITheme.FONT_H1, true)
	名栏.add_child(名)

	var 境界: Label = Label.new()
	境界.text = "  %s%d层" % [str(m.境界), int(m.层数)]
	境界.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	UITheme.apply_project_font(境界, UITheme.FONT_TITLE, true)
	名栏.add_child(境界)

	# 属性网格
	var 属性表: GridContainer = GridContainer.new()
	属性表.columns = 3
	属性表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	信息区.add_child(属性表)

	var 属性: Array = [
		["道行", str(m.战力)],
		["寿元", "%d年" % int(m.寿元)],
		["年龄", "%.1f岁" % float(m.年龄)],
		["心境", str(m.心境)],
		["道心", str(m.道心)],
		["资质", str(m.资质)],
		["灵根", str(m.灵根品阶)],
		["道途", str(m.道途) if m.道途 != "" else "未入门"],
		["性格", str(m.性格)],
	]
	# P0修复：增加游历机缘显示
	var 机缘检查: Dictionary = Game.检查机缘("游历机缘")
	属性.append(["游历机缘", "%d/%d" % [机缘检查.get("剩余", 0), 机缘检查.get("上限", 0)]])
	for p in 属性:
		var l: Label = Label.new()
		l.text = "%s：%s" % [str(p[0]), str(p[1])]
		l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.7))
		属性表.add_child(l)

	# 精力和威望
	var 资源栏: HBoxContainer = HBoxContainer.new()
	信息区.add_child(资源栏)

	var 精力: Label = Label.new()
	精力.text = "精力：%d/%d" % [int(Game.宗主精力), int(Game.宗主精力上限)]
	精力.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	资源栏.add_child(精力)

	var 威望: Label = Label.new()
	威望.text = "  威望：%d" % int(Game.宗主威望)
	威望.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5))
	资源栏.add_child(威望)

	# 闭关状态
	var 闭关状态: Label = Label.new()
	if Game.宗主闭关中:
		闭关状态.text = "  【闭关中】已闭关%d天" % int(Game.宗主闭关累计天)
		闭关状态.add_theme_color_override("font_color", Color(0.8, 0.6, 0.9))
	else:
		闭关状态.text = "  【未闭关】"
		闭关状态.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	资源栏.add_child(闭关状态)

	# 寿元显示
	var 寿元状态: Label = Label.new()
	var 剩余寿元: int = int(Game.宗主剩余寿元)
	if 剩余寿元 <= 50:
		寿元状态.text = "  【寿元危急】剩余%d年" % 剩余寿元
		寿元状态.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	elif 剩余寿元 <= 100:
		寿元状态.text = "  【寿元不足】剩余%d年" % 剩余寿元
		寿元状态.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	else:
		寿元状态.text = "  【寿元】剩余%d年" % 剩余寿元
		寿元状态.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	资源栏.add_child(寿元状态)

	# 闭关/出关按钮
	var 闭关按钮: Button = Button.new()
	if Game.宗主闭关中:
		闭关按钮.text = "出关（结算闭关收益）"
		闭关按钮.modulate = Color(0.9, 0.8, 0.6)
	else:
		闭关按钮.text = "进入闭关（修炼×2，精力恢复×2）"
		闭关按钮.modulate = Color(0.6, 0.8, 0.9)
	闭关按钮.custom_minimum_size = Vector2(0, 36)
	闭关按钮.pressed.connect(_on宗主闭关)
	信息区.add_child(闭关按钮)

	# E：传承选项（寿元耗尽时显示）
	if Game.宗主传承触发中:
		var 传承标题: Label = Label.new()
		传承标题.text = "\n⚠ 宗主寿元耗尽！请选择传承方式："
		传承标题.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
		信息区.add_child(传承标题)

		var 转世按钮: Button = Button.new()
		转世按钮.text = "转世重修（保留30%修为+50%威望，从练气重新开始）"
		转世按钮.modulate = Color(0.7, 0.6, 0.9)
		转世按钮.custom_minimum_size = Vector2(0, 40)
		转世按钮.pressed.connect(_on宗主转世)
		信息区.add_child(转世按钮)

		var 传位标题: Label = Label.new()
		传位标题.text = "\n或选择弟子继承宗主之位："
		传位标题.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
		信息区.add_child(传位标题)

		var 候选: Array = Game.获取继承候选弟子()
		for d in 候选:
			if d == null:
				continue
			var 传位按钮: Button = Button.new()
			传位按钮.text = "传位：%s（%s境，道行%d）" % [str(d.姓名), str(d.境界), int(d.战力)]
			传位按钮.custom_minimum_size = Vector2(0, 32)
			传位按钮.pressed.connect(Callable(self, "_on宗主传位").bind(int(d.弟子ID)))
			信息区.add_child(传位按钮)

	# 修为进度
	var 修文: Label = Label.new()
	修文.text = "\n修为进度：%.1f%%" % (float(m.修炼进度) * 100.0)
	修文.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	信息区.add_child(修文)

	var 修条: ProgressBar = ProgressBar.new()
	修条.min_value = 0.0
	修条.max_value = 1.0
	修条.value = 0.0
	修条.custom_minimum_size = Vector2(0, 20)
	信息区.add_child(修条)
	# ★ 2026-09-16（#18）：修为条自 0 生长到当前值（数值瞬跳观感廉价，成长反馈是修仙游戏的核心爽点）。
	UITheme.进度缓动(修条, float(m.修炼进度))

	# 瓶颈打磨
	if m.瓶颈打磨值 > 0:
		var 瓶文: Label = Label.new()
		瓶文.text = "瓶颈打磨：%.1f%%" % (float(m.瓶颈打磨值) * 100.0)
		瓶文.add_theme_color_override("font_color", Color(0.8, 0.6, 0.6))
		信息区.add_child(瓶文)

		var 瓶条: ProgressBar = ProgressBar.new()
		瓶条.min_value = 0.0
		瓶条.max_value = 1.0
		瓶条.value = 0.0
		瓶条.custom_minimum_size = Vector2(0, 16)
		信息区.add_child(瓶条)
		# ★ 2026-09-16（#18）：瓶颈条自 0 生长
		UITheme.进度缓动(瓶条, float(m.瓶颈打磨值))

	# 宗主探索秘境入口
	var 探索标题: Label = Label.new()
	探索标题.text = "\n宗主亲自探索（消耗精力25+体力10）："
	探索标题.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	信息区.add_child(探索标题)

	var 秘境列表: Array = Game.获取宗主秘境列表()
	for 秘境名 in 秘境列表:
		var 探索按钮: Button = Button.new()
		探索按钮.text = "探索%s" % str(秘境名)
		探索按钮.custom_minimum_size = Vector2(0, 32)
		探索按钮.pressed.connect(Callable(self, "_on宗主探索").bind(str(秘境名)))
		信息区.add_child(探索按钮)

	# 探索结果提示
	var 探索结果: Label = Label.new()
	探索结果.name = "探索结果"
	探索结果.text = ""
	探索结果.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	探索结果.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	信息区.add_child(探索结果)


func _render修炼() -> void:
	var m: Disciple = Game.宗主

	var 区: VBoxContainer = VBoxContainer.new()
	区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(区)
	区.modulate.a = 0.0
	区.create_tween().tween_property(区, "modulate:a", 1.0, 0.25)

	# 修炼状态
	var 状态: Label = Label.new()
	状态.text = "当前境界：%s%d层" % [str(m.境界), int(m.层数)]
	状态.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	UITheme.apply_project_font(状态, UITheme.FONT_TITLE, true)
	区.add_child(状态)

	# 修为进度
	var 修文: Label = Label.new()
	修文.text = "修为：%.1f%%" % (float(m.修炼进度) * 100.0)
	UITheme.apply_aux_text(修文)
	区.add_child(修文)

	var 修条: ProgressBar = ProgressBar.new()
	修条.min_value = 0.0
	修条.max_value = 1.0
	修条.value = 0.0
	修条.custom_minimum_size = Vector2(0, 24)
	区.add_child(修条)
	# ★ 2026-09-16（#18）：修为条自 0 生长
	UITheme.进度缓动(修条, float(m.修炼进度))

	# 突破按钮
	if int(m.层数) >= 10 and float(m.修炼进度) >= 1.0:
		var 突破按钮: Button = Button.new()
		突破按钮.text = "突破境界"
		突破按钮.custom_minimum_size = Vector2(0, 40)
		突破按钮.modulate = Color(0.8, 1.0, 0.8)
		突破按钮.pressed.connect(_on宗主突破)
		区.add_child(突破按钮)

		var 提示: Label = Label.new()
		提示.text = "大圆满境界，可尝试突破"
		提示.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		区.add_child(提示)
	else:
		var 提示: Label = Label.new()
		提示.text = "修炼中...（月度推演自动推进）"
		提示.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		区.add_child(提示)

	# 修炼信息
	var 信息: Label = Label.new()
	信息.text = "\n修炼速度：%.2f\n心境：%d\n道心：%d\n丹毒：%.1f\n稳固期剩余：%.1f天" % [
		float(m.修炼速度), int(m.心境), int(m.道心), float(m.丹毒), float(m.稳固期剩余)]
	信息.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	区.add_child(信息)

	# 已学功法
	var 功法文: Label = Label.new()
	功法文.text = "\n已学功法：%d本" % m.已学功法.size()
	功法文.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	区.add_child(功法文)

	for gid in m.已学功法:
		var 功法信息: Dictionary = {}
		var 是自创: bool = false
		# 先查基础功法库
		if GongFaSystem.功法库.has(gid):
			功法信息 = GongFaSystem.功法库[gid]
		else:
			# 查自创功法
			for zc in Game.自创功法列表:
				if str(zc.get("id", "")) == str(gid):
					功法信息 = zc
					是自创 = true
					break
		var 功法名: String = str(功法信息.get("名称", gid))
		var 功法品阶: String = str(功法信息.get("品阶", ""))
		var 功法效果: String = str(功法信息.get("效果", 功法信息.get("描述", "")))
		var 品阶标签: String = GongFaSystem.获取品阶标签(功法品阶) if 功法品阶 != "" else "自创功法"
		var gl: Label = Label.new()
		gl.text = "  · 《%s》[%s] %s" % [功法名, 品阶标签, 功法效果]
		gl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		区.add_child(gl)
		# 纳入藏经阁按钮（仅非自创功法，自创功法已自动纳入）
		if not 是自创:
			var 已纳入: bool = false
			for cj in Game.藏经阁功法列表:
				if str(cj.get("id", "")) == str(gid):
					已纳入 = true
					break
			if not 已纳入:
				var 纳btn = Button.new()
				纳btn.text = "    纳入藏经阁（全宗可参悟）"
				纳btn.custom_minimum_size = Vector2(0, 32)
				纳btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				纳btn.pressed.connect(_on纳入藏经阁.bind(gid, 功法名, 功法品阶, "功法", 功法效果))
				区.add_child(纳btn)


func _on纳入藏经阁(功法ID: String, 功法名: String, 功法品阶: String, 功法类型: String, 功法效果: String) -> void:
	var 结果: Dictionary = Game.纳入藏经阁(功法ID, 功法名, 功法品阶, 功法类型, 功法效果, Game.宗主名)
	if bool(结果.get("成功", false)):
		_加提示("《%s》已纳入藏经阁，全宗弟子可参悟！" % 功法名)
	else:
		_加提示("纳入失败：%s" % str(结果.get("原因", "")))
	_render()


func _render技艺() -> void:
	var m: Disciple = Game.宗主

	var 区: VBoxContainer = VBoxContainer.new()
	区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(区)
	区.modulate.a = 0.0
	区.create_tween().tween_property(区, "modulate:a", 1.0, 0.25)

	var 技艺表: Array = [
		["炼丹", int(m.炼丹等级)],
		["炼器", int(m.炼器等级)],
	]

	# 检查是否有制符等级
	var 制符等级: int = 1
	if "制符等级" in m:
		制符等级 = int(m.制符等级)
	技艺表.append(["制符", 制符等级])

	for s in 技艺表:
		var 行: HBoxContainer = HBoxContainer.new()
		区.add_child(行)

		var 名: Label = Label.new()
		名.text = "%s品级：" % str(s[0])
		名.custom_minimum_size = Vector2(120, 0)
		名.add_theme_color_override("font_color", Color(0.8, 0.75, 0.5))
		行.add_child(名)

		var 级: Label = Label.new()
		级.text = "第 %d 重" % int(s[1])
		级.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		行.add_child(级)

	var 提示: Label = Label.new()
	提示.text = "\n宗主独立场所（不与弟子殿阁共用，可升级提升生产效率）："
	提示.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	区.add_child(提示)

	# 宗主场所列表
	var 场所列表: Array = Game.获取宗主场所列表()
	for 场所 in 场所列表:
		var 场所行: HBoxContainer = HBoxContainer.new()
		场所行.add_theme_constant_override("separation", 10)
		var 场所名: Label = Label.new()
		场所名.text = "%s（Lv%d）" % [场所["名称"], int(场所["等级"])]
		场所名.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		场所行.add_child(场所名)
		var 场所描述: Label = Label.new()
		场所描述.text = str(场所["描述"])
		场所描述.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
		场所行.add_child(场所描述)
		var 升级按钮: Button = Button.new()
		升级按钮.text = "升级"
		升级按钮.custom_minimum_size = Vector2(60, 28)
		升级按钮.pressed.connect(_on升级宗主场所.bind(str(场所["场所"])))
		场所行.add_child(升级按钮)
		区.add_child(场所行)

	var 生产提示: Label = Label.new()
	生产提示.text = "\n宗主亲自生产（消耗精力，使用对应独立场所）："
	生产提示.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	区.add_child(生产提示)

	# 炼丹按钮
	var 炼丹按钮: Button = Button.new()
	炼丹按钮.text = "丹房炼丹（精力20）"
	炼丹按钮.custom_minimum_size = Vector2(0, 36)
	炼丹按钮.pressed.connect(_on宗主炼丹)
	区.add_child(炼丹按钮)

	# 炼器按钮
	var 炼器按钮: Button = Button.new()
	炼器按钮.text = "炼器室炼器（精力30）"
	炼器按钮.custom_minimum_size = Vector2(0, 36)
	炼器按钮.pressed.connect(_on宗主炼器)
	区.add_child(炼器按钮)

	# 制符按钮
	var 制符按钮: Button = Button.new()
	制符按钮.text = "制符室绘符（精力15）"
	制符按钮.custom_minimum_size = Vector2(0, 36)
	制符按钮.pressed.connect(_on宗主制符)
	区.add_child(制符按钮)

	# 毒道区域（优化版：总览在上，毒药按类型分组）
	var 毒道总览: Dictionary = Game.毒道总览()

	# 毒道总览面板
	var 毒道总览面板: PanelContainer = PanelContainer.new()
	毒道总览面板.custom_minimum_size = Vector2(0, 100)
	var 总览内框: VBoxContainer = VBoxContainer.new()
	总览内框.add_theme_constant_override("separation", 5)
	毒道总览面板.add_child(总览内框)
	区.add_child(毒道总览面板)

	var 毒道标题: Label = Label.new()
	毒道标题.text = "◆ 毒道总览（旁门大道，毒医双修）"
	毒道标题.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
	总览内框.add_child(毒道标题)

	var 境界行: HBoxContainer = HBoxContainer.new()
	境界行.add_theme_constant_override("separation", 20)
	var 毒道境界标签: Label = Label.new()
	毒道境界标签.text = "毒道境界：%s（%d修为）" % [str(毒道总览["毒道境界"]), int(毒道总览["毒道经验"])]
	毒道境界标签.add_theme_color_override("font_color", Color(0.9, 0.6, 0.4))
	境界行.add_child(毒道境界标签)
	var 毒体标签: Label = Label.new()
	毒体标签.text = "毒体：%s（%d修为）" % [str(毒道总览["毒体境界"]), int(毒道总览["毒体经验"])]
	毒体标签.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	境界行.add_child(毒体标签)
	总览内框.add_child(境界行)

	var 加成行: HBoxContainer = HBoxContainer.new()
	加成行.add_theme_constant_override("separation", 20)
	var 解毒标签: Label = Label.new()
	解毒标签.text = "解毒效果：%d%%" % int(float(毒道总览["解毒药效果加成"]) * 100)
	解毒标签.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	加成行.add_child(解毒标签)
	var 炼丹标签: Label = Label.new()
	炼丹标签.text = "炼丹加成：+%d%%" % int(float(毒道总览["炼丹成功率加成"]) * 100)
	炼丹标签.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	加成行.add_child(炼丹标签)
	var 毒室标签: Label = Label.new()
	毒室标签.text = "毒室：%d 重 | 存量：%d 种" % [int(毒道总览["毒室等级"]), int(毒道总览["毒药数量"])]
	毒室标签.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
	加成行.add_child(毒室标签)
	总览内框.add_child(加成行)

	# 毒药列表（按类型分组）
	var 毒药提示: Label = Label.new()
	毒药提示.text = "\n◆ 毒药炼制（按类型分组，杀伤性毒增加业力心魔）"
	毒药提示.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))
	区.add_child(毒药提示)

	var 毒药列表: Array = Game.获取毒药列表()
	var 毒药类型分组: Dictionary = {}
	for 毒药 in 毒药列表:
		var 类型: String = str(毒药["类型"])
		if not 毒药类型分组.has(类型):
			毒药类型分组[类型] = []
		毒药类型分组[类型].append(毒药)

	for 类型 in 毒药类型分组.keys():
		# 类型标题
		var 类型标题: Label = Label.new()
		var 类型描述: String = ""
		match 类型:
			"腐蚀毒": 类型描述 = "（腐蚀肉身法宝，杀伤性）"
			"麻痹毒": 类型描述 = "（麻痹灵力行动，控制性，无业力）"
			"元神毒": 类型描述 = "（侵蚀元神道心，杀伤性）"
			"瘟疫毒": 类型描述 = "（传染性群体伤害，杀伤性）"
			"慢性毒": 类型描述 = "（长期积累发作，杀伤性）"
			"解毒药": 类型描述 = "（解除毒素，正面，加正道声望）"
			_: 类型描述 = ""
		类型标题.text = "  【%s】%s" % [类型, 类型描述]
		if 类型 == "解毒药":
			类型标题.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		elif 类型 == "麻痹毒":
			类型标题.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
		else:
			类型标题.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
		区.add_child(类型标题)

		for 毒药 in 毒药类型分组[类型]:
			var 毒药行: HBoxContainer = HBoxContainer.new()
			毒药行.add_theme_constant_override("separation", 10)
			var 毒药名: Label = Label.new()
			毒药名.text = "    %s（%s）" % [毒药["名称"], 毒药["品阶"]]
			毒药名.custom_minimum_size = Vector2(160, 0)
			毒药名.add_theme_color_override("font_color", Color(0.8, 0.6, 0.6))
			毒药行.add_child(毒药名)
			var 毒药效果: Label = Label.new()
			毒药效果.text = "%s | 毒伤%d" % [str(毒药["效果"]), int(毒药["伤害"])]
			毒药效果.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))
			毒药行.add_child(毒药效果)
			var 炼制按钮: Button = Button.new()
			炼制按钮.text = "炼制"
			炼制按钮.custom_minimum_size = Vector2(60, 28)
			炼制按钮.pressed.connect(_on炼制毒药.bind(str(毒药["名称"])))
			毒药行.add_child(炼制按钮)
			区.add_child(毒药行)

	# 毒丹系统（毒医双修高阶应用）
	var 毒丹提示: Label = Label.new()
	毒丹提示.text = "\n◆ 毒丹（毒医双修高阶应用，需毒师以上境界，无业力）"
	毒丹提示.add_theme_color_override("font_color", Color(0.7, 0.5, 0.7))
	区.add_child(毒丹提示)

	# 毒丹列表
	var 毒丹列表: Array = Game.获取毒丹列表()
	for 毒丹 in 毒丹列表:
		var 毒丹行: HBoxContainer = HBoxContainer.new()
		毒丹行.add_theme_constant_override("separation", 10)
		var 毒丹名: Label = Label.new()
		毒丹名.text = "%s（%s/%s）" % [毒丹["名称"], 毒丹["品阶"], 毒丹["类型"]]
		毒丹名.custom_minimum_size = Vector2(160, 0)
		毒丹名.add_theme_color_override("font_color", Color(0.8, 0.6, 0.8))
		毒丹行.add_child(毒丹名)
		var 毒丹效果: Label = Label.new()
		毒丹效果.text = str(毒丹["效果"])
		毒丹效果.add_theme_color_override("font_color", Color(0.6, 0.5, 0.6))
		毒丹行.add_child(毒丹效果)
		var 炼毒丹按钮: Button = Button.new()
		炼毒丹按钮.text = "炼制"
		炼毒丹按钮.custom_minimum_size = Vector2(60, 28)
		炼毒丹按钮.pressed.connect(_on炼制毒丹.bind(str(毒丹["名称"])))
		毒丹行.add_child(炼毒丹按钮)
		var 服毒丹按钮: Button = Button.new()
		服毒丹按钮.text = "宗主服用"
		服毒丹按钮.custom_minimum_size = Vector2(80, 28)
		服毒丹按钮.pressed.connect(_on服用毒丹.bind(str(毒丹["名称"])))
		毒丹行.add_child(服毒丹按钮)
		区.add_child(毒丹行)

	# 生产结果提示
	var 结果提示: Label = Label.new()
	结果提示.name = "生产结果"
	结果提示.text = ""
	结果提示.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	结果提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	区.add_child(结果提示)


func _render装备() -> void:
	var m: Disciple = Game.宗主

	var 区: VBoxContainer = VBoxContainer.new()
	区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(区)
	区.modulate.a = 0.0
	区.create_tween().tween_property(区, "modulate:a", 1.0, 0.25)

	if m.装备.is_empty():
		var 空: Label = Label.new()
		空.text = "宗主暂无装备"
		空.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		区.add_child(空)
	else:
		for key in m.装备.keys():
			var it = m.装备[key]
			if it == null:
				continue
			var 行: HBoxContainer = HBoxContainer.new()
			区.add_child(行)

			var 槽: Label = Label.new()
			槽.text = "[%s]" % str(key)
			槽.custom_minimum_size = Vector2(80, 0)
			槽.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
			行.add_child(槽)

			var 名: Label = Label.new()
			名.text = str(it.名称) if it != null else "空"
			名.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
			行.add_child(名)


func _render背包() -> void:
	var m: Disciple = Game.宗主

	var 区: VBoxContainer = VBoxContainer.new()
	区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(区)
	区.modulate.a = 0.0
	区.create_tween().tween_property(区, "modulate:a", 1.0, 0.25)

	if m.背包.is_empty():
		var 空: Label = Label.new()
		空.text = "宗主背包为空"
		空.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		区.add_child(空)
	else:
		var 文: Label = Label.new()
		文.text = "背包物品：%d件" % m.背包.size()
		文.add_theme_color_override("font_color", Color(0.7, 0.75, 0.6))
		区.add_child(文)

		for it in m.背包:
			var il: Label = Label.new()
			il.text = "  · %s" % str(it.名称) if it != null else "  · 空"
			il.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			区.add_child(il)


func _on宗主突破() -> void:
	if Game == null or Game.宗主 == null:
		return
	var 前境界: String = Game.宗主.境界
	Game.宗主.突破()
	if is_instance_valid(Game.宗主) and Game.宗主.境界 != 前境界:
		VFXBus.emit_breakthrough(self)   # 突破成功 → 暗金爆发
	_render()


func _on宗主炼丹() -> void:
	if Game == null or Game.宗主 == null:
		return
	var 丹方列表: Array = Game.已解锁丹方列表
	if 丹方列表.is_empty():
		return
	var 结果: Dictionary = Game.宗主炼丹(str((丹方列表[0] as Dictionary).get("丹方ID", "")))
	_显示生产结果(结果)
	if bool(结果.get("成功", false)):
		VFXBus.emit_sparkle(self)   # 炼丹成丹 → 灵气 sparkle
	_render()


func _on宗主炼器() -> void:
	if Game == null or Game.宗主 == null:
		return
	var 配方列表: Array = Game.配置表配方.keys()
	if 配方列表.is_empty():
		return
	var 结果: Dictionary = Game.宗主炼器(str(配方列表[0]))
	_显示生产结果(结果)
	_render()


func _on宗主制符() -> void:
	if Game == null or Game.宗主 == null:
		return
	var 符箓列表: Array = Game.获取宗主符箓列表()
	if 符箓列表.is_empty():
		return
	var 结果: Dictionary = Game.宗主制符(符箓列表[0])
	_显示生产结果(结果)
	_render()


func _on升级宗主场所(场所: String) -> void:
	if Game == null:
		return
	var 结果: Dictionary = Game.升级宗主场所(场所)
	if bool(结果.get("成功", false)):
		UIHint.show_hint(self, "场所升级", "%s升级至%d级！" % [场所, int(结果["新等级"])])
		Game.添加提示("场所升级")
	else:
		UIHint.show_hint(self, "升级失败", str(结果.get("原因", "")))
		Game.添加提示("升级失败")
	_render()


func _on炼制毒药(毒药名: String) -> void:
	if Game == null or Game.宗主 == null:
		return
	var 结果: Dictionary = Game.炼制毒药(毒药名, Game.宗主)
	if bool(结果.get("成功", false)):
		UIHint.show_hint(self, "炼制成功", "获得%s（%s）" % [毒药名, 结果["品阶"]])
		Game.添加提示("炼制成功")
	else:
		UIHint.show_hint(self, "炼制失败", str(结果.get("原因", "")))
		Game.添加提示("炼制失败")
	_render()


func _on炼制毒丹(毒丹名: String) -> void:
	if Game == null or Game.宗主 == null:
		return
	var 结果: Dictionary = Game.炼制毒丹(毒丹名, Game.宗主)
	if bool(结果.get("成功", false)):
		UIHint.show_hint(self, "炼制成功", "获得%s（%s/%s）" % [毒丹名, 结果["品阶"], 结果["类型"]])
		Game.添加提示("炼制成功")
	else:
		UIHint.show_hint(self, "炼制失败", str(结果.get("原因", "")))
		Game.添加提示("炼制失败")
	_render()

func _on服用毒丹(毒丹名: String) -> void:
	if Game == null or Game.宗主 == null:
		return
	var 结果: Dictionary = Game.服用毒丹(毒丹名, Game.宗主)
	if bool(结果.get("成功", false)):
		UIHint.show_hint(self, "服用成功", "%s服用%s，%s" % [Game.宗主.姓名, 毒丹名, str(结果.get("效果", ""))])
		Game.添加提示("服用成功")
	else:
		UIHint.show_hint(self, "服用失败", str(结果.get("原因", "")))
		Game.添加提示("服用失败")
	_render()


func _显示生产结果(结果: Dictionary) -> void:
	if _content == null:
		return
	var 结果标签 = _content.find_child("生产结果", true, false)
	if 结果标签 != null and 结果标签 is Label:
		if bool(结果.get("成功", false)):
			结果标签.text = "成功！获得：%s" % str(结果.get("产出", ""))
			结果标签.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		else:
			结果标签.text = "失败：%s" % str(结果.get("原因", ""))
			结果标签.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))


func _on宗主探索(秘境ID: String) -> void:
	if Game == null or Game.宗主 == null:
		return
	var 结果: Dictionary = Game.宗主探索秘境(秘境ID)
	if _content != null:
		var 结果标签 = _content.find_child("探索结果", true, false)
		if 结果标签 != null and 结果标签 is Label:
			if bool(结果.get("成功", false)):
				var 奖励: String = "灵石%d" % int(结果.get("奖励灵石", 0))
				var 物品: String = str(结果.get("获得物品", ""))
				if 物品 != "":
					奖励 += "，%s" % 物品
				结果标签.text = "探索成功！获得：%s（威望+1）" % 奖励
				结果标签.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
			else:
				结果标签.text = "探索失败：%s" % str(结果.get("原因", ""))
				结果标签.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
	_render()


func _on宗主闭关() -> void:
	if Game == null or Game.宗主 == null:
		return
	if Game.宗主闭关中:
		var 结果: Dictionary = Game.宗主退出闭关()
		if bool(结果.get("成功", false)):
			_加提示("出关成功！闭关%d天，修为+%.1f%%" % [int(结果.get("闭关天数", 0)), float(结果.get("额外修为", 0)) * 100])
	else:
		var 结果: Dictionary = Game.宗主进入闭关()
		if bool(结果.get("成功", false)):
			_加提示("进入闭关，修炼速度×2，精力恢复×2")
	_render()


func _加提示(文本: String) -> void:
	if _content == null:
		return
	var 提示: Label = Label.new()
	提示.text = 文本
	提示.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	_content.add_child(提示)


func _on宗主转世() -> void:
	if Game == null or Game.宗主 == null:
		return
	var 结果: Dictionary = Game.宗主转世重修()
	if bool(结果.get("成功", false)):
		_加提示("转世重修成功！第%d世，保留%.0f%%修为" % [int(结果.get("转世次数", 1)), float(结果.get("保留修为", 0)) * 100])
	_render()


func _on宗主传位(弟子ID: int) -> void:
	if Game == null or Game.宗主 == null:
		return
	var 结果: Dictionary = Game.宗主传位弟子(弟子ID)
	if bool(结果.get("成功", false)):
		_加提示("传位成功！新宗主：%s" % str(结果.get("新宗主", "")))
	_render()


func _render管理() -> void:
	var 区: VBoxContainer = VBoxContainer.new()
	区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(区)
	区.modulate.a = 0.0
	区.create_tween().tween_property(区, "modulate:a", 1.0, 0.25)

	# 宗门资源（基础资源+新材料）
	var 资源标题: Label = Label.new()
	资源标题.text = "宗门资源"
	资源标题.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	区.add_child(资源标题)

	var 资源文本: Label = Label.new()
	var 资源行: Array = []
	资源行.append("灵石：%d" % int(Game.灵石))
	资源行.append("灵草：%d" % int(Game.灵草))
	资源行.append("灵米：%d" % int(Game.灵米))
	资源行.append("矿石：%d" % int(Game.矿石))
	资源行.append("灵晶：%d" % int(Game.灵晶))
	资源行.append("灵气：%d" % int(Game.灵气))
	资源文本.text = "  ".join(资源行)
	资源文本.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	区.add_child(资源文本)

	# 高阶炼器矿物
	var 矿物标题: Label = Label.new()
	矿物标题.text = "\n炼器矿物（按品阶）"
	矿物标题.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	区.add_child(矿物标题)

	var 矿物文本: Label = Label.new()
	var 矿物行: Array = []
	矿物行.append("精铁：%d" % int(Game.精铁))
	矿物行.append("玄铁：%d" % int(Game.玄铁))
	矿物行.append("庚金：%d" % int(Game.庚金))
	矿物行.append("紫晶：%d" % int(Game.紫晶))
	矿物行.append("星辰铁：%d" % int(Game.星辰铁))
	矿物行.append("太阳精金：%d" % int(Game.太阳精金))
	矿物文本.text = "  ".join(矿物行)
	矿物文本.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	区.add_child(矿物文本)

	# 高阶炼丹灵草
	var 灵草标题: Label = Label.new()
	灵草标题.text = "\n炼丹灵草（按品阶）"
	灵草标题.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	区.add_child(灵草标题)

	var 灵草文本: Label = Label.new()
	var 灵草行: Array = []
	灵草行.append("灵品灵草：%d" % int(Game.灵品灵草))
	灵草行.append("宝品灵草：%d" % int(Game.宝品灵草))
	灵草行.append("王品灵草：%d" % int(Game.王品灵草))
	灵草行.append("圣品灵草：%d" % int(Game.圣品灵草))
	灵草行.append("仙品灵草：%d" % int(Game.仙品灵草))
	灵草文本.text = "  ".join(灵草行)
	灵草文本.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	区.add_child(灵草文本)

	# 妖兽材料
	var 妖兽标题: Label = Label.new()
	妖兽标题.text = "\n妖兽材料（按等阶）"
	妖兽标题.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	区.add_child(妖兽标题)

	var 妖兽文本: Label = Label.new()
	var 妖兽行: Array = []
	for 等阶 in ["一阶", "二阶", "三阶", "四阶", "五阶", "六阶", "七阶", "八阶", "九阶"]:
		var 内丹数: int = Game.获取妖兽内丹(等阶)
		var 精血数: int = Game.获取妖兽精血(等阶)
		if 内丹数 > 0 or 精血数 > 0:
			妖兽行.append("%s：内丹%d/精血%d" % [等阶, 内丹数, 精血数])
	if 妖兽行.is_empty():
		妖兽行.append("（暂无妖兽材料，历练/秘境击杀妖兽可获得）")
	妖兽文本.text = "  ".join(妖兽行)
	妖兽文本.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7))
	区.add_child(妖兽文本)

	# 副宗主信息
	var 标题: Label = Label.new()
	标题.text = "副宗主"
	标题.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	区.add_child(标题)

	var 副宗主: Disciple = Game.获取副宗主()
	if 副宗主 != null:
		var 信息: Label = Label.new()
		信息.text = "现任副宗主：%s（%s境，道行%d）" % [str(副宗主.姓名), str(副宗主.境界), int(副宗主.战力)]
		信息.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		区.add_child(信息)

		var 解除按钮: Button = Button.new()
		解除按钮.text = "解除副宗主"
		解除按钮.custom_minimum_size = Vector2(0, 32)
		解除按钮.pressed.connect(_on解除副宗主)
		区.add_child(解除按钮)
	else:
		var 无: Label = Label.new()
		无.text = "未任命副宗主（闭关时代管效率降低）"
		无.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
		区.add_child(无)

		# 任命候选
		var 候选标题: Label = Label.new()
		候选标题.text = "\n可任命副宗主（金丹及以上）："
		候选标题.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		区.add_child(候选标题)

		var 候选: Array = Game.获取副宗主候选()
		if 候选.is_empty():
			var 无候选: Label = Label.new()
			无候选.text = "暂无可任命弟子（需金丹及以上境界）"
			无候选.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			区.add_child(无候选)
		else:
			for d in 候选:
				if d == null:
					continue
				var 任命按钮: Button = Button.new()
				任命按钮.text = "任命：%s（%s境，道行%d）" % [str(d.姓名), str(d.境界), int(d.战力)]
				任命按钮.custom_minimum_size = Vector2(0, 32)
				任命按钮.pressed.connect(Callable(self, "_on任命副宗主").bind(int(d.弟子ID)))
				区.add_child(任命按钮)

	# 代管权能设置
	var 权能标题: Label = Label.new()
	权能标题.text = "\n闭关代管权能（勾选=副宗主可处理）"
	权能标题.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	区.add_child(权能标题)

	var 权能列表: Array = [
		["日常资源", "灵田/矿脉/灵脉等日常产出"],
		["弟子修炼", "弟子修炼推进/突破"],
		["自动招徒", "自动招收弟子"],
		["方针执行", "历练派遣/丹药炼制等方针"],
		["殿阁升级", "殿阁升级（消耗资源）"],
		["弟子任命", "任命/解除负责人"],
		["重大事件", "特殊事件/奇遇"],
		["外交事务", "王朝/其他宗门外交"],
	]
	for item in 权能列表:
		var 行: HBoxContainer = HBoxContainer.new()
		区.add_child(行)

		var 复选: CheckBox = CheckBox.new()
		复选.text = "%s（%s）" % [str(item[0]), str(item[1])]
		复选.button_pressed = bool(Game.代管权能.get(str(item[0]), false))
		复选.toggled.connect(Callable(self, "_on权能切换").bind(str(item[0])))
		行.add_child(复选)

	# 待处理事件
	var 事件标题: Label = Label.new()
	事件标题.text = "\n待处理事件（闭关期间副宗主无法处理）"
	事件标题.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5))
	区.add_child(事件标题)

	var 待处理: Array = Game.获取待处理事件()
	if 待处理.is_empty():
		var 无事件: Label = Label.new()
		无事件.text = "暂无待处理事件"
		无事件.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		区.add_child(无事件)
	else:
		for e in 待处理:
			var 事件行: Label = Label.new()
			事件行.text = "  [%s] %s" % [str(e.get("类型", "")), str(e.get("描述", ""))]
			事件行.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
			事件行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			区.add_child(事件行)

		var 清空按钮: Button = Button.new()
		清空按钮.text = "清空待处理事件"
		清空按钮.custom_minimum_size = Vector2(0, 32)
		清空按钮.pressed.connect(_on清空事件)
		区.add_child(清空按钮)

	# 宗门建设
	var 建设标题: Label = Label.new()
	建设标题.text = "\n宗门建设"
	建设标题.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	区.add_child(建设标题)

	# 洞府扩建
	var 洞府消耗: int = Game.获取洞府扩建消耗()
	var 洞府按钮: Button = Button.new()
	洞府按钮.text = "扩建洞府（+5容量，消耗%d灵石）" % 洞府消耗
	洞府按钮.custom_minimum_size = Vector2(0, 32)
	洞府按钮.pressed.connect(_on扩建洞府)
	区.add_child(洞府按钮)

	# 灵脉升级
	var 灵脉消耗: Dictionary = Game.获取灵脉升级消耗()
	var 灵脉按钮: Button = Button.new()
	灵脉按钮.text = "升级灵脉（%d 品→%d 品，消耗%d灵石+%d灵晶）" % [int(Game.灵脉等级), int(Game.灵脉等级)+1, int(灵脉消耗.get("灵石", 0)), int(灵脉消耗.get("灵晶", 0))]
	灵脉按钮.custom_minimum_size = Vector2(0, 32)
	灵脉按钮.pressed.connect(_on升级灵脉)
	区.add_child(灵脉按钮)

	# 宗主延寿
	var 延寿按钮: Button = Button.new()
	延寿按钮.text = "宗主延寿+50年（消耗延寿丹×1）"
	延寿按钮.custom_minimum_size = Vector2(0, 32)
	延寿按钮.pressed.connect(_on宗主延寿)
	区.add_child(延寿按钮)


func _on任命副宗主(弟子ID: int) -> void:
	if Game == null:
		return
	var 结果: Dictionary = Game.任命副宗主(弟子ID)
	if bool(结果.get("成功", false)):
		_加提示("任命成功！副宗主：%s" % str(结果.get("副宗主", "")))
	else:
		_加提示("任命失败：%s" % str(结果.get("原因", "")))
	_render()


func _on解除副宗主() -> void:
	if Game == null:
		return
	Game.解除副宗主()
	_加提示("已解除副宗主")
	_render()


func _on权能切换(勾选: bool, 权能项: String) -> void:
	if Game == null:
		return
	Game.设置代管权能(权能项, 勾选)


func _on清空事件() -> void:
	if Game == null:
		return
	Game.清空待处理事件()
	_加提示("已清空待处理事件")
	_render()


func _on扩建洞府() -> void:
	if Game == null:
		return
	var 结果: Dictionary = Game.扩建洞府()
	if bool(结果.get("成功", false)):
		_加提示("洞府扩建成功！容量+5")
	else:
		_加提示("扩建失败：%s" % str(结果.get("原因", "")))
	_render()


func _on升级灵脉() -> void:
	if Game == null:
		return
	var 结果: Dictionary = Game.升级灵脉()
	if bool(结果.get("成功", false)):
		_加提示("灵脉升级成功！%d 品" % int(Game.灵脉等级))
	else:
		_加提示("升级失败：%s" % str(结果.get("原因", "")))
	_render()


func _on宗主延寿() -> void:
	if Game == null or Game.宗主 == null:
		return
	# 检查是否有延寿丹
	var 有延寿丹: bool = false
	for it in Game.宗门库房:
		if it != null and "延寿" in str(it.名称):
			有延寿丹 = true
			Game.宗门库房.erase(it)
			break
	if not 有延寿丹:
		_加提示("延寿失败：库房无延寿丹")
		return
	Game.宗主延寿(50)
	_加提示("宗主延寿成功！寿元+50年")
	_render()

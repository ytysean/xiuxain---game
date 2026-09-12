extends Control
# 卜算星盘 UI（休闲玩法 S49-P0/P1/P2/P3）
# 后端：Game.卜算系统；图录复用 Game.收藏图录_已收集（天机录）
# P1：天机境界进度段 + 宗门运势  P2：星盘玉 求购与切换  P3：观星大会周赛参与
# 颜色一律走 UITheme 真实 const，禁硬编码

const UITheme = preload("res://ui_theme.gd")

signal 返回主页

const TABS: Array = ["总览", "卜算", "天机录"]

var _built: bool = false
var _cur: String = "总览"
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}
var _最近结果: Dictionary = {}
var _状态文本: Label = null
var _当前类型: String = "日常吉凶"
var _用星盘玉: bool = false

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
	var 顶栏: HBoxContainer = HBoxContainer.new()
	顶栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(顶栏)
	var 返回按钮: Button = Button.new()
	返回按钮.text = "← 返回宗门"
	返回按钮.custom_minimum_size = Vector2(120, 36)
	返回按钮.pressed.connect(_on返回)
	顶栏.add_child(返回按钮)
	var 标题: Label = Label.new()
	标题.text = "  卜算星盘"
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	标题.add_theme_font_size_override("font_size", 20)
	顶栏.add_child(标题)
	var 标签栏: HBoxContainer = HBoxContainer.new()
	标签栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(标签栏)
	for 标签名 in TABS:
		var 按钮: Button = Button.new()
		按钮.text = 标签名
		按钮.custom_minimum_size = Vector2(100, 32)
		按钮.pressed.connect(Callable(self, "_切换标签").bind(标签名))
		标签栏.add_child(按钮)
		_tab_btns[标签名] = 按钮
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
	for k in _tab_btns:
		_tab_btns[k].modulate = Color(1, 1, 1, 1) if k == _cur else Color(0.6, 0.6, 0.6, 1)

func _刷新内容() -> void:
	for c in _content.get_children():
		c.queue_free()
	match _cur:
		"总览": _建_总览()
		"卜算": _建_卜算()
		"天机录": _建_天机录()

func _on返回() -> void:
	返回主页.emit()

func _建_总览() -> void:
	var 卜: DivineSystem = Game.卜算系统
	var 标题: Label = Label.new()
	标题.text = "卜算星盘·总览"
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	标题.add_theme_font_size_override("font_size", 24)
	_content.add_child(标题)
	var 次: Label = Label.new()
	次.text = "累计卜算 %d 次。夜观天象、卜算吉凶，机缘所至皆入天机录。" % 卜.累计卜算次数
	次.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	次.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(次)
	var 提示: Label = Label.new()
	提示.text = "卜算星盘为天机卜算子型：卜算吉凶、观星应验，吉兆机缘、天机秘示皆受控触发。"
	提示.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(提示)
	# P1 天机境界进度段
	_content.add_child(_分隔("天机境界"))
	var 境文: String = "当前境界：%s" % 卜.天机境界名()
	var 进: Dictionary = 卜.天机进度()
	if 进.满:
		境文 += "（已臻化境）"
	else:
		境文 += "（修为 %d / %d）" % [进.已得, 进.需]
	var 境: Label = Label.new()
	境.text = 境文
	境.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	境.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(境)
	# 宗门运势段
	_content.add_child(_分隔("宗门运势"))
	var 运: Label = Label.new()
	运.text = "当前宗门运势：%d / 100（吉兆增、凶兆减，本系统内部追踪）" % 卜.宗门运势
	运.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	运.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(运)
	# P3 观星大会段
	_content.add_child(_分隔("观星大会"))
	var 周: Dictionary = 卜.获取本周观星周()
	var 周文: String = "本周擂台【%s】：%s（威望 %d）" % [周.get("名称", ""), 周.get("描述", ""), int(周.get("奖励威望", 0))]
	var 周标: Label = Label.new()
	周标.text = 周文
	周标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	周标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(周标)
	var 余: Label = Label.new()
	余.text = "本周已参与 %d / 3（应验积分排行，威望入账）" % 卜.本周观星参与
	余.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	_content.add_child(余)
	var 参: Button = Button.new()
	参.text = "参与本周观星大会"
	参.custom_minimum_size = Vector2(0, 48)
	参.pressed.connect(_参与观星周)
	_content.add_child(参)

func _建_卜算() -> void:
	_content.add_child(_分隔("卜算类型"))
	for t in Game.卜算系统.卜算类型表:
		var 名: String = t.get("类型", "")
		var 资: int = int(t.get("卦资", 0))
		var 按钮: Button = Button.new()
		按钮.text = "%s（卦资 %d）" % [名, 资]
		按钮.custom_minimum_size = Vector2(0, 44)
		if 名 == _当前类型:
			按钮.modulate = Color(1, 0.95, 0.6, 1)
		else:
			按钮.modulate = Color(1, 1, 1, 1)
		按钮.pressed.connect(Callable(self, "_选类型").bind(名))
		_content.add_child(按钮)
	_content.add_child(_分隔("辅助消耗品"))
	var 玉文: String = "星盘玉（提应验率）：%s" % ("已持" if Game.卜算系统.库房计数("星盘玉") > 0 else "未持")
	var 玉: Label = Label.new()
	玉.text = 玉文
	玉.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	_content.add_child(玉)
	var 求玉: Button = Button.new()
	求玉.text = "求购星盘玉（300灵石）"
	求玉.custom_minimum_size = Vector2(0, 44)
	求玉.pressed.connect(_求购星盘玉)
	_content.add_child(求玉)
	var 切玉: Button = Button.new()
	切玉.text = "卜算用星盘玉：%s" % ("是" if _用星盘玉 else "否")
	切玉.custom_minimum_size = Vector2(0, 44)
	切玉.pressed.connect(_切换用星盘玉)
	_content.add_child(切玉)
	var 卜按钮: Button = Button.new()
	卜按钮.text = "卜算（%s）" % _当前类型
	卜按钮.custom_minimum_size = Vector2(0, 48)
	卜按钮.pressed.connect(_卜算)
	_content.add_child(卜按钮)
	_状态文本 = Label.new()
	_状态文本.text = "选类型、卜算吉凶。"
	_状态文本.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	_状态文本.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_状态文本)
	if not _最近结果.is_empty():
		var r: Label = Label.new()
		r.text = _格式结果(_最近结果)
		r.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS if _最近结果.get("成功", false) else UITheme.COLOR_TEXT_RED)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(r)

func _选类型(名: String) -> void:
	_当前类型 = 名
	_刷新内容()

func _卜算() -> void:
	_最近结果 = Game.卜算系统.结算卜算(_当前类型, _用星盘玉)
	_刷新内容()
	if _最近结果.get("成功", false):
		var 附: String = ""
		if _最近结果.get("境界突破", false):
			附 += "·天机突破"
		_update状态("卜得【%s】（%s）·宗门运势 %d%s" % [_最近结果.get("分层", ""), _最近结果.get("类型", ""), int(_最近结果.get("运势", 0)), 附])
	else:
		_update状态("卜算未成：%s" % _最近结果.get("原因", ""))

func _求购星盘玉() -> void:
	var r: Dictionary = Game.卜算系统.求购消耗品("星盘玉")
	_刷新内容()
	_update状态("求购星盘玉：%s" % (("成功，耗 %d 灵石" % r.get("价", 0)) if r.get("成功", false) else r.get("原因", "")))

func _切换用星盘玉() -> void:
	_用星盘玉 = not _用星盘玉
	_刷新内容()
	_update状态("卜算用星盘玉：%s" % ("是" if _用星盘玉 else "否"))

func _参与观星周() -> void:
	var r: Dictionary = Game.卜算系统.参与观星周()
	_刷新内容()
	if r.get("成功", false):
		_update状态("参与观星大会【%s】，获宗主威望 %d（已 %d/3）" % [r.get("规则", ""), int(r.get("威望", 0)), int(r.get("参与", 0))])
	else:
		_update状态("观星大会：%s" % r.get("原因", ""))

func _update状态(t: String) -> void:
	if _状态文本 != null:
		_状态文本.text = t

func _格式结果(r: Dictionary) -> String:
	if not r.get("成功", false):
		return "空手：%s" % r.get("原因", "")
	var 附: String = ""
	if r.get("境界突破", false):
		附 += "·天机突破"
	return "卜得【%s】（%s）\n卦资 %d 灵石\n宗门运势 %d\n得天机修为 %d%s" % [r.get("分层", ""), r.get("类型", ""), int(r.get("卦资", 0)), int(r.get("运势", 0)), int(r.get("经验", 0)), 附]

func _建_天机录() -> void:
	var 已收: Array = Game.收藏图录_已收集.get("天机", [])
	var 全部: Array = []
	for r in Game.图录配置:
		if r.get("类别") == "天机":
			全部.append(r.get("匹配名", ""))
	var 标题: Label = Label.new()
	标题.text = "天机录：已收录 %d / %d" % [已收.size(), 全部.size()]
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	标题.add_theme_font_size_override("font_size", 22)
	_content.add_child(标题)
	for 名 in 全部:
		var l: Label = Label.new()
		if 已收.has(名):
			l.text = "✓ %s" % 名
			l.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS)
		else:
			l.text = "✗ %s（未收录）" % 名
			l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
		_content.add_child(l)

func _分隔(t: String) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	l.add_theme_font_size_override("font_size", 18)
	return l

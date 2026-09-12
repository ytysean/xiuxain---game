extends Control
# 饲灵育兽 UI（休闲玩法 S48-P0/P1/P2/P3）
# 后端：Game.饲灵系统；图录复用 Game.收藏图录_已收集
# P1：御兽境界进度段  P2：嗜好食/驯养鞭 求购与切换  P3：灵兽斗周赛参与
# 颜色一律走 UITheme 真实 const，禁硬编码

const UITheme = preload("res://ui_theme.gd")

signal 返回主页

const TABS: Array = ["总览", "饲灵", "图录"]

var _built: bool = false
var _cur: String = "总览"
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}
var _最近结果: Dictionary = {}
var _状态文本: Label = null
var _用嗜好食: bool = false
var _用驯养鞭: bool = false

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
	标题.text = "  饲灵育兽"
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
		"饲灵": _建_饲灵()
		"图录": _建_图录()

func _on返回() -> void:
	返回主页.emit()

func _建_总览() -> void:
	var 饲: BeastRaiseSystem = Game.饲灵系统
	var 标题: Label = Label.new()
	标题.text = "饲灵育兽·总览"
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	标题.add_theme_font_size_override("font_size", 24)
	_content.add_child(标题)
	var 次: Label = Label.new()
	次.text = "累计饲灵 %d 次。所获灵兽产出、兽魂、奇遇蛋皆归宗门，反哺育兽与御兽。" % 饲.累计饲灵次数
	次.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	次.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(次)
	var 提示: Label = Label.new()
	提示.text = "饲灵育兽为灵兽养成子型：喂食抚摸、驯养灵兽，机缘所得皆入灵兽志。"
	提示.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(提示)
	# P1 御兽境界进度段
	_content.add_child(_分隔("御兽境界"))
	var 境界名: String = 饲.御兽境界名()
	var 进: Dictionary = 饲.御兽进度()
	var 境文: String = "当前境界：%s" % 境界名
	if 进.满:
		境文 += "（已臻化境）"
	else:
		境文 += "（修为 %d / %d）" % [进.已得, 进.需]
	var 境: Label = Label.new()
	境.text = 境文
	境.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	境.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(境)
	# P3 灵兽斗周赛段
	_content.add_child(_分隔("灵兽斗周赛"))
	var 周: Dictionary = 饲.获取本周探兽周()
	var 周文: String = "本周擂台【%s】：%s（威望 %d）" % [周.get("名称", ""), 周.get("描述", ""), int(周.get("奖励威望", 0))]
	var 周标: Label = Label.new()
	周标.text = 周文
	周标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	周标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(周标)
	var 余: Label = Label.new()
	余.text = "本周已参与 %d / 3（擂台零伤亡，威望入账）" % 饲.本周探兽参与
	余.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	_content.add_child(余)
	var 参: Button = Button.new()
	参.text = "参与本周灵兽斗"
	参.custom_minimum_size = Vector2(0, 48)
	参.pressed.connect(_参与灵兽斗周)
	_content.add_child(参)

func _建_饲灵() -> void:
	_content.add_child(_分隔("饲灵驯养"))
	var 参: Button = Button.new()
	参.text = "喂食抚摸·饲灵"
	参.custom_minimum_size = Vector2(0, 48)
	参.pressed.connect(_饲灵)
	_content.add_child(参)
	_状态文本 = Label.new()
	_状态文本.text = "点按饲灵，灵兽亲昵。"
	_状态文本.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	_状态文本.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_状态文本)
	# P2 消耗品区块
	_content.add_child(_分隔("辅助消耗品"))
	var 嗜文: String = "嗜好食（提稀有率）：%s" % ("已持" if Game.饲灵系统.库房计数("嗜好食") > 0 else "未持")
	var 嗜: Label = Label.new()
	嗜.text = 嗜文
	嗜.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	_content.add_child(嗜)
	var 求嗜: Button = Button.new()
	求嗜.text = "求购嗜好食（180灵石）"
	求嗜.custom_minimum_size = Vector2(0, 44)
	求嗜.pressed.connect(_求购嗜好食)
	_content.add_child(求嗜)
	var 切嗜: Button = Button.new()
	切嗜.text = "饲灵用嗜好食：%s" % ("是" if _用嗜好食 else "否")
	切嗜.custom_minimum_size = Vector2(0, 44)
	切嗜.pressed.connect(_切换用嗜好食)
	_content.add_child(切嗜)
	var 鞭文: String = "驯养鞭（提兽魂率）：%s" % ("已持" if Game.饲灵系统.库房计数("驯养鞭") > 0 else "未持")
	var 鞭: Label = Label.new()
	鞭.text = 鞭文
	鞭.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	_content.add_child(鞭)
	var 求鞭: Button = Button.new()
	求鞭.text = "求购驯养鞭（220灵石）"
	求鞭.custom_minimum_size = Vector2(0, 44)
	求鞭.pressed.connect(_求购驯养鞭)
	_content.add_child(求鞭)
	var 切鞭: Button = Button.new()
	切鞭.text = "饲灵用驯养鞭：%s" % ("是" if _用驯养鞭 else "否")
	切鞭.custom_minimum_size = Vector2(0, 44)
	切鞭.pressed.connect(_切换用驯养鞭)
	_content.add_child(切鞭)
	if not _最近结果.is_empty():
		var r: Label = Label.new()
		r.text = _格式结果(_最近结果)
		r.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS if _最近结果.get("成功", false) else UITheme.COLOR_TEXT_RED)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(r)

func _饲灵() -> void:
	var 参: Dictionary = Game.饲灵系统.开始饲灵()
	_最近结果 = Game.饲灵系统.结算饲灵("饲灵", _用嗜好食, _用驯养鞭)
	_刷新内容()
	if _最近结果.get("成功", false):
		var 附: String = ""
		if _最近结果.get("变异", false):
			附 += "·幼兽变异"
		if _最近结果.get("境界突破", false):
			附 += "·御兽突破"
		_update状态("饲灵得【%s】（%s·%s阶）%s" % [_最近结果.get("名称", ""), _最近结果.get("分层", ""), _最近结果.get("品阶", ""), 附])
	else:
		_update状态("饲灵无获：%s" % _最近结果.get("原因", ""))

func _求购嗜好食() -> void:
	var r: Dictionary = Game.饲灵系统.求购消耗品("嗜好食")
	_刷新内容()
	_update状态("求购嗜好食：%s" % (("成功，耗 %d 灵石" % r.get("价", 0)) if r.get("成功", false) else r.get("原因", "")))

func _求购驯养鞭() -> void:
	var r: Dictionary = Game.饲灵系统.求购消耗品("驯养鞭")
	_刷新内容()
	_update状态("求购驯养鞭：%s" % (("成功，耗 %d 灵石" % r.get("价", 0)) if r.get("成功", false) else r.get("原因", "")))

func _切换用嗜好食() -> void:
	_用嗜好食 = not _用嗜好食
	_刷新内容()
	_update状态("饲灵用嗜好食：%s" % ("是" if _用嗜好食 else "否"))

func _切换用驯养鞭() -> void:
	_用驯养鞭 = not _用驯养鞭
	_刷新内容()
	_update状态("饲灵用驯养鞭：%s" % ("是" if _用驯养鞭 else "否"))

func _参与灵兽斗周() -> void:
	var r: Dictionary = Game.饲灵系统.参与探兽周()
	_刷新内容()
	if r.get("成功", false):
		_update状态("参与灵兽斗周赛【%s】，获宗主威望 %d（已 %d/3）" % [r.get("规则", ""), int(r.get("威望", 0)), int(r.get("参与", 0))])
	else:
		_update状态("灵兽斗周赛：%s" % r.get("原因", ""))

func _update状态(t: String) -> void:
	if _状态文本 != null:
		_状态文本.text = t

func _格式结果(r: Dictionary) -> String:
	if not r.get("成功", false):
		return "空手：%s" % r.get("原因", "")
	var 附: String = ""
	if r.get("变异", false):
		附 += "·幼兽变异"
	if r.get("境界突破", false):
		附 += "·御兽突破"
	return "饲灵得【%s】（%s·%s阶）\n%s\n用途：%s\n得御兽修为 %d%s" % [r.get("名称", ""), r.get("分层", ""), r.get("品阶", ""), r.get("描述", ""), r.get("用途", ""), int(r.get("经验", 0)), 附]

func _建_图录() -> void:
	var 已收: Array = Game.收藏图录_已收集.get("灵兽", [])
	var 全部: Array = []
	for r in Game.图录配置:
		if r.get("类别") == "灵兽":
			全部.append(r.get("匹配名", ""))
	var 标题: Label = Label.new()
	标题.text = "灵兽志：已收录 %d / %d" % [已收.size(), 全部.size()]
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

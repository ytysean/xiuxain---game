extends Control
# 论道棋弈 UI（休闲玩法 S51-P0/P1/P2/P3）
# 后端：Game.论道系统；图录复用 Game.收藏图录_已收集
# P1：棋道境界进度段 + 道韵/悟性增益  P2：棋谱/悟道茶 求购与切换  P3：论道大会周赛参与
# 颜色一律走 UITheme 真实 const，禁硬编码

const UITheme = preload("res://ui_theme.gd")

signal 返回主页

const TABS: Array = ["总览", "论道", "棋谱录"]

var _built: bool = false
var _cur: String = "总览"
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}
var _最近结果: Dictionary = {}
var _状态文本: Label = null
var _用棋谱: bool = false
var _用悟道茶: bool = false

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
	标题.text = "  论道棋弈"
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
		"论道": _建_论道()
		"棋谱录": _建_图录()

func _on返回() -> void:
	返回主页.emit()

func _建_总览() -> void:
	var 棋 = Game.论道系统
	var 标题: Label = Label.new()
	标题.text = "论道棋弈·总览"
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	标题.add_theme_font_size_override("font_size", 24)
	_content.add_child(标题)
	var 次: Label = Label.new()
	次.text = "累计论道 %d 局。棋道通玄，悟性增益反哺修炼，棋谱机锋皆归宗门。" % 棋.累计论道次数
	次.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	次.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(次)
	var 提示: Label = Label.new()
	提示.text = "论道棋弈为轻对抗智力子型：点按落子，禁限时，赢棋得道韵与悟性增益，无伤亡之忧。"
	提示.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(提示)
	# P1 棋道境界进度段
	_content.add_child(_分隔("棋道境界"))
	var 境界名: String = 棋.棋道境界名()
	var 进: Dictionary = 棋.棋道进度()
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
	# 道韵 + 悟性增益
	_content.add_child(_分隔("道韵与悟性增益"))
	var 韵文: String = "道韵：%d（赢棋所得，通玄之资）" % 棋.道韵
	var 韵: Label = Label.new()
	韵.text = 韵文
	韵.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	韵.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(韵)
	var 增: Dictionary = 棋.当前悟性增益()
	var 增文: String = "悟性增益：剩余 %d 日，修炼速度 +%.0f%%" % [int(增.get("剩余日", 0)), float(增.get("幅度", 0.0)) * 100.0]
	var 增标: Label = Label.new()
	增标.text = 增文
	增标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD if 增.get("剩余日", 0) > 0 else UITheme.COLOR_TEXT_AUX)
	增标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(增标)
	# P3 论道大会周赛段
	_content.add_child(_分隔("论道大会周赛"))
	var 周: Dictionary = 棋.获取本周论道周()
	var 周文: String = "本周论道【%s】：%s（威望 %d）" % [周.get("名称", ""), 周.get("描述", ""), int(周.get("奖励威望", 0))]
	var 周标: Label = Label.new()
	周标.text = 周文
	周标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	周标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(周标)
	var 余: Label = Label.new()
	余.text = "本周已参与 %d / 3（论道无伤亡，威望入账）" % 棋.本周论道参与
	余.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	_content.add_child(余)
	var 参: Button = Button.new()
	参.text = "参与本周论道大会"
	参.custom_minimum_size = Vector2(0, 48)
	参.pressed.connect(_参与论道大会)
	_content.add_child(参)

func _建_论道() -> void:
	_content.add_child(_分隔("对弈棋类"))
	if Game.论道系统.棋类表.is_empty():
		var 空: Label = Label.new()
		空.text = "棋类配置未加载。"
		空.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
		_content.add_child(空)
	for c in Game.论道系统.棋类表:
		var 棋类id: String = c.get("棋类id", "")
		var 名: String = c.get("棋类名", "")
		var 难度: int = int(c.get("难度星", 1))
		var 对手: String = c.get("对手", "")
		var 需境: int = int(c.get("需求棋道境界", 0))
		var 门控: bool = Game.论道系统.棋道境界 < 需境
		var 胜率: float = Game.论道系统.基础胜率(棋类id)
		var 额外: String = ""
		if _用棋谱 and Game.论道系统.库房计数("棋谱") > 0:
			额外 = "（用棋谱 +%.0f%%）" % (float(Game.论道系统.消耗品配置("棋谱").get("数值", 0.0)) * 100.0)
		var 锁: String = "（锁·需%s）" % Game.论道系统.棋道境界表[需境].get("名", "") if 门控 else ""
		var 文: String = "%s · 对【%s】 · 胜率%.0f%%%s%s" % [名, 对手, 胜率 * 100.0, 额外, 锁]
		var 按钮: Button = Button.new()
		按钮.text = 文
		按钮.custom_minimum_size = Vector2(0, 48)
		按钮.pressed.connect(Callable(self, "_论道").bind(棋类id))
		_content.add_child(按钮)
	_状态文本 = Label.new()
	_状态文本.text = "点按棋类，与对手对弈。"
	_状态文本.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	_状态文本.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_状态文本)
	# P2 消耗品区块
	_content.add_child(_分隔("辅助消耗品"))
	var 棋文: String = "棋谱（提胜率/解锁高难）：%s" % ("已持" if Game.论道系统.库房计数("棋谱") > 0 else "未持")
	var 棋: Label = Label.new()
	棋.text = 棋文
	棋.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	_content.add_child(棋)
	var 求棋: Button = Button.new()
	求棋.text = "求购棋谱（200灵石）"
	求棋.custom_minimum_size = Vector2(0, 44)
	求棋.pressed.connect(_求购棋谱)
	_content.add_child(求棋)
	var 切棋: Button = Button.new()
	切棋.text = "对弈用棋谱：%s" % ("是" if _用棋谱 else "否")
	切棋.custom_minimum_size = Vector2(0, 44)
	切棋.pressed.connect(_切换用棋谱)
	_content.add_child(切棋)
	var 茶文: String = "悟道茶（提悟性幅度）：%s" % ("已持" if Game.论道系统.库房计数("悟道茶") > 0 else "未持")
	var 茶: Label = Label.new()
	茶.text = 茶文
	茶.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	_content.add_child(茶)
	var 求茶: Button = Button.new()
	求茶.text = "求购悟道茶（180灵石）"
	求茶.custom_minimum_size = Vector2(0, 44)
	求茶.pressed.connect(_求购悟道茶)
	_content.add_child(求茶)
	var 切茶: Button = Button.new()
	切茶.text = "对弈用悟道茶：%s" % ("是" if _用悟道茶 else "否")
	切茶.custom_minimum_size = Vector2(0, 44)
	切茶.pressed.connect(_切换用悟道茶)
	_content.add_child(切茶)
	if not _最近结果.is_empty():
		var r: Label = Label.new()
		r.text = _格式结果(_最近结果)
		r.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS if _最近结果.get("成功", false) else UITheme.COLOR_TEXT_RED)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(r)

func _论道(棋类id: String) -> void:
	_最近结果 = Game.论道系统.结算论道(棋类id, _用棋谱, _用悟道茶)
	_刷新内容()
	if not _最近结果.get("成功", false):
		_update状态("对弈未成：%s" % _最近结果.get("原因", ""))
		return
	if _最近结果.get("胜", false):
		var 附: String = ""
		if _最近结果.get("收谱", false):
			附 += "·收录棋谱"
		if _最近结果.get("机锋", false):
			附 += "·机锋妙语"
		if _最近结果.get("秘匣", false):
			附 += "·棋道秘匣"
		if _最近结果.get("境界突破", false):
			附 += "·棋道突破"
		_update状态("对弈【%s】胜·得道韵 %d%s" % [_最近结果.get("棋类", ""), int(_最近结果.get("道韵", 0)), 附])
	else:
		_update状态("对弈【%s】负，棋道修为小进 %d（无损耗）" % [_最近结果.get("棋类", ""), int(_最近结果.get("经验", 0))])

func _求购棋谱() -> void:
	var r: Dictionary = Game.论道系统.求购消耗品("棋谱")
	_刷新内容()
	_update状态("求购棋谱：%s" % (("成功，耗 %d 灵石" % r.get("价", 0)) if r.get("成功", false) else r.get("原因", "")))

func _求购悟道茶() -> void:
	var r: Dictionary = Game.论道系统.求购消耗品("悟道茶")
	_刷新内容()
	_update状态("求购悟道茶：%s" % (("成功，耗 %d 灵石" % r.get("价", 0)) if r.get("成功", false) else r.get("原因", "")))

func _切换用棋谱() -> void:
	_用棋谱 = not _用棋谱
	_刷新内容()
	_update状态("对弈用棋谱：%s" % ("是" if _用棋谱 else "否"))

func _切换用悟道茶() -> void:
	_用悟道茶 = not _用悟道茶
	_刷新内容()
	_update状态("对弈用悟道茶：%s" % ("是" if _用悟道茶 else "否"))

func _参与论道大会() -> void:
	var r: Dictionary = Game.论道系统.参与论道大会()
	_刷新内容()
	if r.get("成功", false):
		_update状态("参与论道大会【%s】，获宗主威望 %d（已 %d/3）" % [r.get("规则", ""), int(r.get("威望", 0)), int(r.get("参与", 0))])
	else:
		_update状态("论道大会：%s" % r.get("原因", ""))

func _update状态(t: String) -> void:
	if _状态文本 != null:
		_状态文本.text = t

func _格式结果(r: Dictionary) -> String:
	if not r.get("成功", false):
		return "未成：%s" % r.get("原因", "")
	var 附: String = ""
	if r.get("收谱", false):
		附 += "·收录棋谱"
	if r.get("机锋", false):
		附 += "·机锋妙语"
	if r.get("秘匣", false):
		附 += "·棋道秘匣"
	if r.get("境界突破", false):
		附 += "·棋道突破"
	return "对弈【%s】对【%s】·胜率%.0f%%·%s\n得道韵 %d · 悟性增益 +%d日/%.0f%%\n棋道修为 %d%s" % [r.get("棋类", ""), r.get("对手", ""), float(r.get("胜率", 0.0)) * 100.0, ("胜" if r.get("胜", false) else "负"), int(r.get("道韵", 0)), int(r.get("悟性增益日", 0)), float(r.get("悟性增益幅", 0.0)) * 100.0, int(r.get("经验", 0)), 附]

func _建_图录() -> void:
	var 已收: Array = Game.收藏图录_已收集.get("棋谱录", [])
	var 全部: Array = []
	for r in Game.图录配置:
		if r.get("类别") == "棋谱录":
			全部.append(r.get("匹配名", ""))
	var 标题: Label = Label.new()
	标题.text = "棋谱录：已收录 %d / %d" % [已收.size(), 全部.size()]
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

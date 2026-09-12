extends Control
# 药圃经营 UI（休闲玩法 S50-P0/P1/P2/P3）
# 后端：Game.药圃系统；图录复用 Game.收藏图录_已收集（灵植志）
# P1：灵植境界进度段  P2：灵肥/引灵露 求购与切换  P3：灵植博览周赛参与
# 颜色一律走 UITheme 真实 const，禁硬编码

const UITheme = preload("res://ui_theme.gd")

signal 返回主页

const TABS: Array = ["总览", "种植", "灵植志"]

var _built: bool = false
var _cur: String = "总览"
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}
var _最近结果: Dictionary = {}
var _状态文本: Label = null
var _用灵肥: bool = false
var _用引灵露: bool = false

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
	标题.text = "  药圃经营"
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
		"种植": _建_种植()
		"灵植志": _建_灵植志()

func _on返回() -> void:
	返回主页.emit()

func _建_总览() -> void:
	var 圃: HerbSystem = Game.药圃系统
	var 标题: Label = Label.new()
	标题.text = "药圃经营·总览"
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	标题.add_theme_font_size_override("font_size", 24)
	_content.add_child(标题)
	var 次: Label = Label.new()
	次.text = "累计种植 %d 次。播灵植、育异种，所产丹材皆归宗门库房，反哺炼丹。" % 圃.累计种植次数
	次.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	次.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(次)
	var 提示: Label = Label.new()
	提示.text = "药圃经营为灵植种植子型：播种浇灌、催熟灵植，异种灵根皆入灵植志。"
	提示.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(提示)
	# P1 灵植境界进度段
	_content.add_child(_分隔("灵植境界"))
	var 境文: String = "当前境界：%s" % 圃.灵植境界名()
	var 进: Dictionary = 圃.灵植进度()
	if 进.满:
		境文 += "（已臻化境）"
	else:
		境文 += "（修为 %d / %d）" % [进.已得, 进.需]
	var 境: Label = Label.new()
	境.text = 境文
	境.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	境.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(境)
	# P3 灵植博览段
	_content.add_child(_分隔("灵植博览"))
	var 周: Dictionary = 圃.获取本周观博周()
	var 周文: String = "本周擂台【%s】：%s（威望 %d）" % [周.get("名称", ""), 周.get("描述", ""), int(周.get("奖励威望", 0))]
	var 周标: Label = Label.new()
	周标.text = 周文
	周标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	周标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(周标)
	var 余: Label = Label.new()
	余.text = "本周已参与 %d / 3（年份评比，威望入账）" % 圃.本周观博参与
	余.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	_content.add_child(余)
	var 参: Button = Button.new()
	参.text = "参与本周灵植博览"
	参.custom_minimum_size = Vector2(0, 48)
	参.pressed.connect(_参与观博周)
	_content.add_child(参)

func _建_种植() -> void:
	_content.add_child(_分隔("种植培育"))
	var 种: Button = Button.new()
	种.text = "播种浇灌·种植"
	种.custom_minimum_size = Vector2(0, 48)
	种.pressed.connect(_种植)
	_content.add_child(种)
	_状态文本 = Label.new()
	_状态文本.text = "点按种植，灵植生长。"
	_状态文本.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	_状态文本.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_状态文本)
	# P2 消耗品区块
	_content.add_child(_分隔("辅助消耗品"))
	var 肥文: String = "灵肥（加速年份档）：%s" % ("已持" if Game.药圃系统.库房计数("灵肥") > 0 else "未持")
	var 肥: Label = Label.new()
	肥.text = 肥文
	肥.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	_content.add_child(肥)
	var 求肥: Button = Button.new()
	求肥.text = "求购灵肥（160灵石）"
	求肥.custom_minimum_size = Vector2(0, 44)
	求肥.pressed.connect(_求购灵肥)
	_content.add_child(求肥)
	var 切肥: Button = Button.new()
	切肥.text = "种植用灵肥：%s" % ("是" if _用灵肥 else "否")
	切肥.custom_minimum_size = Vector2(0, 44)
	切肥.pressed.connect(_切换用灵肥)
	_content.add_child(切肥)
	var 露文: String = "引灵露（提异种率）：%s" % ("已持" if Game.药圃系统.库房计数("引灵露") > 0 else "未持")
	var 露: Label = Label.new()
	露.text = 露文
	露.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	_content.add_child(露)
	var 求露: Button = Button.new()
	求露.text = "求购引灵露（200灵石）"
	求露.custom_minimum_size = Vector2(0, 44)
	求露.pressed.connect(_求购引灵露)
	_content.add_child(求露)
	var 切露: Button = Button.new()
	切露.text = "种植用引灵露：%s" % ("是" if _用引灵露 else "否")
	切露.custom_minimum_size = Vector2(0, 44)
	切露.pressed.connect(_切换用引灵露)
	_content.add_child(切露)
	if not _最近结果.is_empty():
		var r: Label = Label.new()
		r.text = _格式结果(_最近结果)
		r.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS if _最近结果.get("成功", false) else UITheme.COLOR_TEXT_RED)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(r)

func _种植() -> void:
	_最近结果 = Game.药圃系统.结算种植(_用灵肥, _用引灵露)
	_刷新内容()
	if _最近结果.get("成功", false):
		var 附: String = ""
		if _最近结果.get("异种", false):
			附 += "·灵植异种"
		if _最近结果.get("灵根", false):
			附 += "·万年灵根"
		if _最近结果.get("境界突破", false):
			附 += "·灵植突破"
		_update状态("种得【%s】（%s·%s·%s阶）%s" % [_最近结果.get("名称", ""), _最近结果.get("年份", ""), _最近结果.get("分层", ""), _最近结果.get("品阶", ""), 附])
	else:
		_update状态("种植无获：%s" % _最近结果.get("原因", ""))

func _求购灵肥() -> void:
	var r: Dictionary = Game.药圃系统.求购消耗品("灵肥")
	_刷新内容()
	_update状态("求购灵肥：%s" % (("成功，耗 %d 灵石" % r.get("价", 0)) if r.get("成功", false) else r.get("原因", "")))

func _求购引灵露() -> void:
	var r: Dictionary = Game.药圃系统.求购消耗品("引灵露")
	_刷新内容()
	_update状态("求购引灵露：%s" % (("成功，耗 %d 灵石" % r.get("价", 0)) if r.get("成功", false) else r.get("原因", "")))

func _切换用灵肥() -> void:
	_用灵肥 = not _用灵肥
	_刷新内容()
	_update状态("种植用灵肥：%s" % ("是" if _用灵肥 else "否"))

func _切换用引灵露() -> void:
	_用引灵露 = not _用引灵露
	_刷新内容()
	_update状态("种植用引灵露：%s" % ("是" if _用引灵露 else "否"))

func _参与观博周() -> void:
	var r: Dictionary = Game.药圃系统.参与观博周()
	_刷新内容()
	if r.get("成功", false):
		_update状态("参与灵植博览【%s】，获宗主威望 %d（已 %d/3）" % [r.get("规则", ""), int(r.get("威望", 0)), int(r.get("参与", 0))])
	else:
		_update状态("灵植博览：%s" % r.get("原因", ""))

func _update状态(t: String) -> void:
	if _状态文本 != null:
		_状态文本.text = t

func _格式结果(r: Dictionary) -> String:
	if not r.get("成功", false):
		return "空手：%s" % r.get("原因", "")
	var 附: String = ""
	if r.get("异种", false):
		附 += "·灵植异种"
	if r.get("灵根", false):
		附 += "·万年灵根"
	if r.get("境界突破", false):
		附 += "·灵植突破"
	return "种得【%s】（%s·%s·%s阶）\n%s\n用途：%s\n得灵植修为 %d%s" % [r.get("名称", ""), r.get("年份", ""), r.get("分层", ""), r.get("品阶", ""), r.get("描述", ""), r.get("用途", ""), int(r.get("经验", 0)), 附]

func _建_灵植志() -> void:
	var 已收: Array = Game.收藏图录_已收集.get("灵植", [])
	var 全部: Array = []
	for r in Game.图录配置:
		if r.get("类别") == "灵植":
			全部.append(r.get("匹配名", ""))
	var 标题: Label = Label.new()
	标题.text = "灵植志：已收录 %d / %d" % [已收.size(), 全部.size()]
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

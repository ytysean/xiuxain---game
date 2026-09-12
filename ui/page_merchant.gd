extends Control
# 商道总览 UI（经商商道系统 S8 深化：P0 商道境界 + P1 行情 + P2 商铺经营 + P3 护卫/稀有 + 周常/图录/消耗品）
# 后端：Game.商队系统（CaravanSystem）；图录复用 Game.收藏图录_已收集
# 颜色一律走 UITheme 真实 const，禁硬编码

const UITheme = preload("res://ui_theme.gd")

signal 返回主页

const TABS: Array = ["总览", "商铺", "行情", "商道录"]

var _built: bool = false
var _cur: String = "总览"
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}
var _选城市: OptionButton = null
var _选类型: OptionButton = null

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
	标题.text = "  商道"
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
		"商铺": _建_商铺()
		"行情": _建_行情()
		"商道录": _建_图录()

func _on返回() -> void:
	返回主页.emit()

func _分隔(t: String) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	l.add_theme_font_size_override("font_size", 18)
	return l

func _标(t: String, c: Color, 大: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", c)
	if 大:
		l.add_theme_font_size_override("font_size", 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _商() -> CaravanSystem:
	return Game.商队系统

# ---------- 总览 ----------
func _建_总览() -> void:
	var 商 = _商()
	_content.add_child(_标("商道·总览", UITheme.COLOR_TEXT_GOLD, true))
	_content.add_child(_标("宗门运转，商道为脉。行商有境，低买高卖，分店置产，奇珍可期。", UITheme.COLOR_TEXT_BODY))
	# 商道境界进度
	_content.add_child(_分隔("商道境界"))
	var 境序 = -1
	var 下一需 = -1
	var 境表 = 商.商道境界表
	for i in range(境表.size()):
		if str(境表[i].get("境界", "")) == 商.商道境界:
			境序 = i
	if 境序 >= 0 and 境序 + 1 < 境表.size():
		下一需 = int(境表[境序 + 1].get("所需经验", 0))
	var 境文 = "当前境界：%s（修为 %d" % [商.商道境界, 商.商道经验]
	if 下一需 >= 0:
		境文 += " / 下一境 %d）" % 下一需
	else:
		境文 += "，已臻化境）"
	_content.add_child(_标(境文, UITheme.COLOR_TEXT_BODY_GOLD))
	_content.add_child(_标("价差加成 +%.0f%%　风险减免 -%.0f%%" % [商.获取商道境界加成() * 100, 商.获取商道风险减免() * 100], UITheme.COLOR_TEXT_BODY))
	# 累计
	_content.add_child(_分隔("贸易总览"))
	_content.add_child(_标("累计贸易 %d 次，累计收益 %d 灵石" % [商.累计贸易次数, 商.累计贸易收益], UITheme.COLOR_TEXT_BODY))
	# 周常
	_content.add_child(_分隔("宗门商道会（周常）"))
	_content.add_child(_标("本周参与贸易大赛 %d / 3（威望奖励，防通胀）" % 商.商道周常本周参与, UITheme.COLOR_TEXT_BODY))
	var 大赛: Button = Button.new()
	大赛.text = "参与贸易大赛（威望+30）"
	大赛.custom_minimum_size = Vector2(220, 36)
	大赛.pressed.connect(_参与大赛)
	_content.add_child(大赛)
	# 消耗品 sink
	_content.add_child(_分隔("商道消耗 · 求购"))
	var 令: Button = Button.new(); 令.text = "求购商道令（价差+8%，200灵石）"; 令.custom_minimum_size = Vector2(260, 34); 令.pressed.connect(_求购.bind("令")); _content.add_child(令)
	var 符: Button = Button.new(); 符.text = "求购通商符（降时30%，150灵石）"; 符.custom_minimum_size = Vector2(260, 34); 符.pressed.connect(_求购.bind("符")); _content.add_child(符)
	var 帖: Button = Button.new(); 帖.text = "求购拜帖（解锁商单，120灵石）"; 帖.custom_minimum_size = Vector2(260, 34); 帖.pressed.connect(_求购.bind("帖")); _content.add_child(帖)

func _参与大赛() -> void:
	var r: Dictionary = _商().参与贸易大赛()
	_吐(r.get("消息", ""))
	_刷新内容()

func _求购(类: String) -> void:
	var r: Dictionary
	match 类:
		"令": r = _商().求购商道令()
		"符": r = _商().求购通商符()
		"帖": r = _商().求购拜帖()
	_吐(r.get("消息", ""))
	_刷新内容()

func _吐(msg: String) -> void:
	var l: Label = Label.new()
	l.text = "▶ " + str(msg)
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)

# ---------- 商铺 ----------
func _建_商铺() -> void:
	var 商 = _商()
	_content.add_child(_标("商铺经营·分店放置", UITheme.COLOR_TEXT_GOLD, true))
	_content.add_child(_标("于已开通商路之城设铺，每日自动产销（真实耗货闭环，过经济阀门防通胀）。等级上限随商道境界：%d级。" % 商.商铺等级上限(), UITheme.COLOR_TEXT_BODY))
	# 现有商铺
	_content.add_child(_分隔("现有商铺 (%d)" % 商.商铺列表.size()))
	if 商.商铺列表.is_empty():
		_content.add_child(_标("尚无分店，于下方开设。", UITheme.COLOR_TEXT_AUX))
	for i in range(商.商铺列表.size()):
		var 铺 = 商.商铺列表[i]
		var 行: HBoxContainer = HBoxContainer.new()
		var 文: Label = Label.new()
		文.text = "%s@%s　%d级" % [str(铺.get("类型", "")), _城市名(str(铺.get("城市ID", ""))), int(铺.get("等级", 1))]
		文.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
		行.add_child(文)
		var 升: Button = Button.new(); 升.text = "升级"; 升.custom_minimum_size = Vector2(70, 30); 升.pressed.connect(_升级.bind(i)); 行.add_child(升)
		var 关: Button = Button.new(); 关.text = "关闭"; 关.custom_minimum_size = Vector2(70, 30); 关.pressed.connect(_关闭.bind(i)); 行.add_child(关)
		_content.add_child(行)
	# 开设区
	_content.add_child(_分隔("开设新铺"))
	_选城市 = OptionButton.new(); _选城市.custom_minimum_size = Vector2(160, 32)
	for d in 商.商队地区:
		if 商.检查商路城市解锁(str(d.get("unlock_condition", "")), str(d.get("id", ""))):
			_选城市.add_item("%s" % str(d.get("名称", "")))
	_content.add_child(_标("选择城邦：", UITheme.COLOR_TEXT_AUX))
	_content.add_child(_选城市)
	_选类型 = OptionButton.new(); _选类型.custom_minimum_size = Vector2(160, 32)
	for 类型 in 商.可开商铺类型():
		_选类型.add_item(类型)
	_content.add_child(_标("选择类型（受商道境界限制）：", UITheme.COLOR_TEXT_AUX))
	_content.add_child(_选类型)
	var 开: Button = Button.new(); 开.text = "开设商铺"; 开.custom_minimum_size = Vector2(160, 36); 开.pressed.connect(_开设); _content.add_child(开)

func _城市名(id: String) -> String:
	for d in _商().商队地区:
		if str(d.get("id", "")) == id:
			return str(d.get("名称", id))
	return id

func _开设() -> void:
	var 商 = _商()
	var 名 = _选城市.get_item_text(_选城市.get_selected())
	var 城市id = ""
	for d in 商.商队地区:
		if str(d.get("名称", "")) == 名:
			城市id = str(d.get("id", "")); break
	var 类型 = _选类型.get_item_text(_选类型.get_selected())
	var r: Dictionary = 商.开设商铺(城市id, 类型)
	_吐(r.get("消息", ""))
	_刷新内容()

func _升级(i: int) -> void:
	_吐(_商().升级商铺(i).get("消息", ""))
	_刷新内容()

func _关闭(i: int) -> void:
	_吐(_商().关闭商铺(i).get("消息", ""))
	_刷新内容()

# ---------- 行情 ----------
func _建_行情() -> void:
	_content.add_child(_标("商路行情一览", UITheme.COLOR_TEXT_GOLD, true))
	_content.add_child(_标("各地分品类行情倍率（绿=低迷可囤，红=暴涨可抛）。按现实日刷新。", UITheme.COLOR_TEXT_BODY))
	var 一览 = _商().获取行情一览()
	if 一览.is_empty():
		_content.add_child(_标("暂无已开通商路。", UITheme.COLOR_TEXT_AUX))
	for 城 in 一览:
		_content.add_child(_分隔(str(城.get("地区名", ""))))
		for q in 城.get("行情", []):
			var 倍 = float(q.get("倍率", 1.0))
			var c = UITheme.COLOR_TEXT_BODY
			if 倍 <= 0.95:
				c = UITheme.COLOR_STATUS_SUCCESS
			elif 倍 >= 1.2:
				c = UITheme.COLOR_TEXT_RED
			_content.add_child(_标("%s：×%.2f（%s）" % [str(q.get("类别", "")), 倍, str(q.get("状态", ""))], c))

# ---------- 商道录 ----------
func _建_图录() -> void:
	var 已收: Array = Game.收藏图录_已收集.get("商道", [])
	var 全部: Array = []
	for r in Game.图录配置:
		if r.get("类别") == "商道":
			全部.append(r.get("匹配名", ""))
	_content.add_child(_标("商道录：已收录 %d / %d" % [已收.size(), 全部.size()], UITheme.COLOR_TEXT_GOLD, true))
	_content.add_child(_标("跨域/高风险商路贸易淘得稀世奇珍，即录入商道录，流芳商界。", UITheme.COLOR_TEXT_BODY))
	for 名 in 全部:
		var l: Label = Label.new()
		if 已收.has(名):
			l.text = "✓ %s" % 名
			l.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS)
		else:
			l.text = "✗ %s（未收录）" % 名
			l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
		_content.add_child(l)

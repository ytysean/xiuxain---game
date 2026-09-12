extends Control
# 机缘 UI（每日机缘次数总览 · 跨系统通用资粮）
# 后端：Game.每日机缘配置 / Game.检查机缘(类型) / Game.使用机缘符(符类型) / Game.使用悟道令()
# 颜色一律走 UITheme 真实 const，禁硬编码

const UITheme = preload("res://ui_theme.gd")

signal 返回主页

const TABS: Array = ["机缘总览", "机缘符"]
const 符表: Array = ["探秘境缘符", "游历机缘符", "历练机缘符", "征伐机缘符", "入山机缘符"]

var _built: bool = false
var _cur: String = "机缘总览"
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}
var _状态文本: Label = null

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
	标题.text = "  机缘"
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	标题.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	顶栏.add_child(标题)
	var 标签栏: HBoxContainer = HBoxContainer.new()
	标签栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(标签栏)
	for 标签名 in TABS:
		var 按钮: Button = Button.new()
		按钮.text = 标签名
		按钮.custom_minimum_size = Vector2(110, 32)
		按钮.pressed.connect(Callable(self, "_切换标签").bind(标签名))
		标签栏.add_child(按钮)
		_tab_btns[标签名] = 按钮
	var 滚: ScrollContainer = ScrollContainer.new()
	滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(滚)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚.add_child(_content)
	_状态文本 = Label.new()
	_状态文本.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	_状态文本.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(_状态文本)
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
		"机缘总览": _建_总览()
		"机缘符": _建_机缘符()

func _on返回() -> void:
	返回主页.emit()

func _建_总览() -> void:
	_content.add_child(_标题("每日机缘"))
	_content.add_child(_说明("机缘为跨系统通用资粮：探秘、游历、历练、征伐、入山各有其缘，用尽须待明日。"))
	for 类型 in Game.每日机缘配置:
		var 配置 = Game.每日机缘配置[类型]
		if 配置 == null:
			continue
		var 查: Dictionary = Game.检查机缘(str(类型))
		var 剩余: int = int(查.get("剩余", 0))
		_content.add_child(_行("%s：剩余 %d / %d" % [str(配置.get("描述", 类型)), 剩余, int(查.get("上限", 0))], UITheme.COLOR_TEXT_BODY_GOLD if 剩余 > 0 else UITheme.COLOR_TEXT_AUX))

func _建_机缘符() -> void:
	_content.add_child(_标题("机缘符"))
	_content.add_child(_说明("机缘符可补一次对应机缘；悟道令可补全部机缘各一次。"))
	for 符 in 符表:
		var 持: int = _库房数(str(符))
		var 按钮: Button = Button.new()
		按钮.text = "使用【%s】（持有 %d）" % [str(符), 持]
		按钮.custom_minimum_size = Vector2(0, 44)
		按钮.disabled = 持 <= 0
		按钮.pressed.connect(Callable(self, "_用符").bind(str(符)))
		_content.add_child(按钮)
	_content.add_child(_分隔("悟道令"))
	var 令数: int = _库房数("悟道令")
	var 令钮: Button = Button.new()
	令钮.text = "使用【悟道令】（持有 %d）· 全部机缘各 +1" % 令数
	令钮.custom_minimum_size = Vector2(0, 44)
	令钮.disabled = 令数 <= 0
	令钮.pressed.connect(_用悟道令)
	_content.add_child(令钮)

func _库房数(名: String) -> int:
	var n: int = 0
	for it in Game.宗门库房:
		if it != null and it is Item and str(it.名称) == 名:
			n += int(it.数量)
	return n

func _用符(符: String) -> void:
	var r: Dictionary = Game.使用机缘符(符)
	_刷新内容()
	_update状态(str(r.get("原因", "")))

func _用悟道令() -> void:
	var r: Dictionary = Game.使用悟道令()
	_刷新内容()
	_update状态(str(r.get("原因", "")))

func _update状态(t: String) -> void:
	if _状态文本 != null:
		_状态文本.text = t

func _标题(t: String) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	l.add_theme_font_size_override("font_size", UITheme.FONT_H1)
	return l

func _分隔(t: String) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	l.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	return l

func _行(t: String, 色: Color) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", 色)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _说明(t: String) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

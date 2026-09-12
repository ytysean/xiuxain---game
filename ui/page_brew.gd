extends Control
# 灵酿 UI（宗主酝造 · 仙家灵酒）
# 后端：Game.获取灵酿配方列表() / Game.开始酿造灵酿(id) / Game.灵酿列表 / Game.举办灵酿宴席(名称)
# 颜色一律走 UITheme 真实 const，禁硬编码

const UITheme = preload("res://ui_theme.gd")

signal 返回主页

const TABS: Array = ["酝造", "在酿", "宴席"]

var _built: bool = false
var _cur: String = "酝造"
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
	标题.text = "  灵酿"
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	标题.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
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
		"酝造": _建_酝造()
		"在酿": _建_在酿()
		"宴席": _建_宴席()

func _on返回() -> void:
	返回主页.emit()

func _建_酝造() -> void:
	_content.add_child(_标题("酿道"))
	_content.add_child(_行("酿道等级：%d（修为 %d）· 今日已酝 %d / 5" % [int(Game.酿道等级), int(Game.酿道经验), int(Game.今日酿酒次数)], UITheme.COLOR_TEXT_BODY_GOLD))
	var 配方表: Array = Game.获取灵酿配方列表()
	_content.add_child(_说明("已解锁 %d 道配方；酝造耗灵草，入窖待其自熟，熟则入库。" % 配方表.size()))
	_content.add_child(_分隔("可酿配方"))
	for 配方 in 配方表:
		var 名: String = str(配方.get("名称", ""))
		var 材文: String = ""
		for 材 in 配方.get("材料", []):
			材文 += ("" if 材文 == "" else "、") + str(材)
		var 按钮: Button = Button.new()
		按钮.text = "酝造【%s】（%s · 需 %d 日）" % [名, 材文, int(配方.get("发酵日", 0))]
		按钮.custom_minimum_size = Vector2(0, 48)
		按钮.pressed.connect(Callable(self, "_酝造").bind(str(配方.get("id", ""))))
		_content.add_child(按钮)
		_content.add_child(_说明("    %s" % str(配方.get("描述", ""))))

func _建_在酿() -> void:
	_content.add_child(_标题("在酿之酒"))
	if Game.灵酿列表.is_empty():
		_content.add_child(_行("窖中暂无在酿之酒。", UITheme.COLOR_TEXT_AUX))
		return
	for 酿 in Game.灵酿列表:
		if 酿 == null:
			continue
		var 余: int = int(酿.get("完成日", 0)) - int(Game.累计游戏日)
		_content.add_child(_行("%s · 尚需 %d 日" % [str(酿.get("名称", "")), max(0, 余)], UITheme.COLOR_TEXT_BODY_GOLD if 余 <= 0 else UITheme.COLOR_TEXT_BODY))
		_content.add_child(_说明("    %s" % str(酿.get("效果", ""))))

func _建_宴席() -> void:
	_content.add_child(_标题("灵酿宴席"))
	_content.add_child(_说明("以灵酿宴请全宗，弟子欢欣，忠诚同增。"))
	var 数: int = 0
	for it in Game.宗门库房:
		if it == null or not (it is Item):
			continue
		if str(it.类别) != "灵酿":
			continue
		数 += 1
		var 按钮: Button = Button.new()
		按钮.text = "设宴【%s】（存 %d）" % [str(it.名称), int(it.数量)]
		按钮.custom_minimum_size = Vector2(0, 44)
		按钮.pressed.connect(Callable(self, "_设宴").bind(str(it.名称)))
		_content.add_child(按钮)
	if 数 == 0:
		_content.add_child(_行("库中暂无成酿，先去酝造。", UITheme.COLOR_TEXT_AUX))

func _酝造(配方ID: String) -> void:
	var r: Dictionary = Game.开始酿造灵酿(配方ID)
	_刷新内容()
	if bool(r.get("成功", false)):
		_update状态("已入窖酝造【%s】，待第 %d 日功成" % [str(r.get("名称", "")), int(r.get("完成日", 0))])
	else:
		_update状态("酝造未成：%s" % str(r.get("原因", "")))

func _设宴(名: String) -> void:
	var r: Dictionary = Game.举办灵酿宴席(名)
	_刷新内容()
	if bool(r.get("成功", false)):
		_update状态("以【%s】宴请全宗：%s" % [名, str(r.get("效果", ""))])
	else:
		_update状态("设宴未成：%s" % str(r.get("原因", "")))

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

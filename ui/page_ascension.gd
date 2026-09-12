extends Control
# 飞升 UI（飞升前兆 · 飞升大典 · 散仙名录）
# 后端：Game.飞升前兆队列 / Game.举办飞升大典(弟子ID) / Game.散仙列表
# 颜色一律走 UITheme 真实 const，禁硬编码

const UITheme = preload("res://ui_theme.gd")

signal 返回主页

const TABS: Array = ["飞升前兆", "散仙名录"]

var _built: bool = false
var _cur: String = "飞升前兆"
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
	标题.text = "  飞升"
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
		"飞升前兆": _建_前兆()
		"散仙名录": _建_散仙()

func _on返回() -> void:
	返回主页.emit()

func _建_前兆() -> void:
	_content.add_child(_标题("飞升前兆"))
	_content.add_child(_说明("门下修为圆满者，天地感应，飞升之兆先现。兆现三十日内，可设大典助其渡劫。"))
	if Game.飞升前兆队列.is_empty():
		_content.add_child(_行("门下暂无飞升之兆。渡劫大圆满者方有感召。", UITheme.COLOR_TEXT_AUX))
		return
	for 兆 in Game.飞升前兆队列:
		if 兆 == null:
			continue
		var 余: int = int(兆.get("飞升日", 0)) - int(Game.累计游戏日)
		_content.add_child(_分隔("%s · %s" % [str(兆.get("姓名", "")), str(兆.get("境界", ""))]))
		_content.add_child(_行("兆现于第 %d 日 · 飞升之期尚余 %d 日" % [int(兆.get("预警日", 0)), max(0, 余)], UITheme.COLOR_TEXT_BODY_GOLD))
		var 按钮: Button = Button.new()
		按钮.text = "举办飞升大典（灵石 1000 · 灵草 100）"
		按钮.custom_minimum_size = Vector2(0, 48)
		按钮.pressed.connect(Callable(self, "_办大典").bind(str(兆.get("弟子ID", "0"))))
		_content.add_child(按钮)

func _建_散仙() -> void:
	_content.add_child(_标题("散仙名录"))
	_content.add_child(_说明("渡劫失败而兵解者，舍肉身以元婴存世，不占弟子编制，可护宗门。"))
	if Game.散仙列表.is_empty():
		_content.add_child(_行("暂无散仙。", UITheme.COLOR_TEXT_AUX))
		return
	for 仙 in Game.散仙列表:
		if 仙 == null:
			continue
		_content.add_child(_分隔("%s · %s" % [str(仙.get("姓名", "")), str(仙.get("类型", ""))]))
		_content.add_child(_行("寿元 %d 年 · 已渡劫 %d 次 · 战力 %d" % [int(仙.get("寿元", 0)), int(仙.get("已渡劫数", 0)), int(仙.get("战力", 0))], UITheme.COLOR_TEXT_BODY))
		_content.add_child(_说明("    功德 %d · 业力 %d" % [int(仙.get("功德", 0)), int(仙.get("业力", 0))]))

func _办大典(id文: String) -> void:
	var r: Dictionary = Game.举办飞升大典(int(id文))
	_刷新内容()
	if bool(r.get("成功", false)):
		_update状态(str(r.get("消息", "飞升大典功成")))
	else:
		_update状态("大典未成：%s" % str(r.get("原因", "")))

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

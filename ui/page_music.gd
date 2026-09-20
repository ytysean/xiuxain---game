extends Control
# 音律 UI（抚琴养性 · 引灵潮）
# 后端：Game.获取琴曲列表() / Game.宗主抚琴(琴曲ID) / Game.琴曲熟练度 / Game.琴道等级
# 颜色一律走 UITheme 真实 const，禁硬编码


signal 返回主页

const TABS: Array = ["总览", "抚琴"]

var _built: bool = false
var _cur: String = "总览"
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}
var _状态文本: Label = null
var _最近: Dictionary = {}

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
	main.add_theme_constant_override("margin_left", UITheme.MARGIN)
	main.add_theme_constant_override("margin_right", UITheme.MARGIN)
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
	标题.text = "  音律"
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_project_font(标题, UITheme.FONT_TITLE, true)
	顶栏.add_child(标题)
	var 标签栏: HBoxContainer = HBoxContainer.new()
	标签栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(标签栏)
	# ★ 2026-09-16（#009 逐页精修）：建钮循环收口到 UITheme.建标签栏（原先 19 页各自手搓，
	#   且 custom_minimum_size 宽度在 80/90/100/110 之间漂移）。统一为最小宽 100 + EXPAND_FILL
	#   ⇒ 少量页签自动均分不空、多量页签不溢出、宽度全局一致。
	_tab_btns = UITheme.建标签栏(标签栏, TABS, Callable(self, "_切换标签"), _cur)
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
	UITheme.刷新标签高亮(_tab_btns, _cur)

func _刷新内容() -> void:
	for c in _content.get_children():
		c.queue_free()
	match _cur:
		"总览": _建_总览()
		"抚琴": _建_抚琴()

func _on返回() -> void:
	返回主页.emit()

func _建_总览() -> void:
	var _fb1 := _标题("琴道")
	_content.add_child(_fb1)
	_fb1.modulate.a = 0.0
	_fb1.create_tween().tween_property(_fb1, "modulate:a", 1.0, 0.25)
	var _fb2 := _行("琴道品级：%d（修为 %d）· 今日已抚 %d / 5" % [int(Game.琴道等级), int(Game.琴道经验), int(Game.今日抚琴次数)], UITheme.COLOR_TEXT_BODY_GOLD)
	_content.add_child(_fb2)
	_fb2.modulate.a = 0.0
	_fb2.create_tween().tween_property(_fb2, "modulate:a", 1.0, 0.25)
	var _fb3 := _行("当前琴曲：%s" % (str(Game.当前琴曲) if str(Game.当前琴曲) != "" else "未抚"), UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb3)
	_fb3.modulate.a = 0.0
	_fb3.create_tween().tween_property(_fb3, "modulate:a", 1.0, 0.25)
	var _fb4 := _说明("抚琴养性，引灵潮入宗门；知音偶遇，皆随缘而至。")
	_content.add_child(_fb4)
	_fb4.modulate.a = 0.0
	_fb4.create_tween().tween_property(_fb4, "modulate:a", 1.0, 0.25)
	var _fb5 := _分隔("琴曲熟练度")
	_content.add_child(_fb5)
	_fb5.modulate.a = 0.0
	_fb5.create_tween().tween_property(_fb5, "modulate:a", 1.0, 0.25)
	if Game.琴曲熟练度.is_empty():
		var _fb6 := _说明("尚无一曲入熟。")
		_content.add_child(_fb6)
		_fb6.modulate.a = 0.0
		_fb6.create_tween().tween_property(_fb6, "modulate:a", 1.0, 0.25)
	else:
		for 曲 in Game.琴曲熟练度:
			var _fb7 := _行("%s · 熟练 %d" % [str(曲), int(Game.琴曲熟练度[曲])], UITheme.COLOR_TEXT_AUX)
			_content.add_child(_fb7)
			_fb7.modulate.a = 0.0
			_fb7.create_tween().tween_property(_fb7, "modulate:a", 1.0, 0.25)
	if not _最近.is_empty():
		var _fb8 := _分隔("上次抚琴")
		_content.add_child(_fb8)
		_fb8.modulate.a = 0.0
		_fb8.create_tween().tween_property(_fb8, "modulate:a", 1.0, 0.25)
		var 成: bool = bool(_最近.get("成功", false))
		var _fb9 := _行(str(_最近.get("效果", _最近.get("原因", ""))), UITheme.COLOR_STATUS_SUCCESS if 成 else UITheme.COLOR_TEXT_RED)
		_content.add_child(_fb9)
		_fb9.modulate.a = 0.0
		_fb9.create_tween().tween_property(_fb9, "modulate:a", 1.0, 0.25)

func _建_抚琴() -> void:
	var _fb10 := _标题("抚琴")
	_content.add_child(_fb10)
	_fb10.modulate.a = 0.0
	_fb10.create_tween().tween_property(_fb10, "modulate:a", 1.0, 0.25)
	var 曲表: Array = Game.获取琴曲列表()
	var _fb11 := _说明("已通 %d 曲；琴道愈深，可抚之曲愈高。每日抚琴五次为度。" % 曲表.size())
	_content.add_child(_fb11)
	_fb11.modulate.a = 0.0
	_fb11.create_tween().tween_property(_fb11, "modulate:a", 1.0, 0.25)
	for 曲 in 曲表:
		var 名: String = str(曲.get("名称", ""))
		var 按钮: Button = Button.new()
		按钮.text = "抚《%s》（%s）" % [名, str(曲.get("效果", ""))]
		按钮.custom_minimum_size = Vector2(0, 48)
		按钮.pressed.connect(Callable(self, "_抚琴").bind(str(曲.get("id", ""))))
		_content.add_child(按钮)
		按钮.modulate.a = 0.0
		按钮.create_tween().tween_property(按钮, "modulate:a", 1.0, 0.25)
		var _fb12 := _说明("    %s" % str(曲.get("描述", "")))
		_content.add_child(_fb12)
		_fb12.modulate.a = 0.0
		_fb12.create_tween().tween_property(_fb12, "modulate:a", 1.0, 0.25)

func _抚琴(琴曲ID: String) -> void:
	_最近 = Game.宗主抚琴(琴曲ID)
	_刷新内容()
	if bool(_最近.get("成功", false)):
		_update状态("抚《%s》，%s（熟练 %d）" % [str(_最近.get("琴曲", "")), str(_最近.get("效果", "")), int(_最近.get("熟练度", 0))])
	else:
		_update状态("抚琴未成：%s" % str(_最近.get("原因", "")))

func _update状态(t: String) -> void:
	if _状态文本 != null:
		_状态文本.text = t

func _标题(t: String) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_project_font(l, UITheme.FONT_H1, true)
	return l

func _分隔(t: String) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	UITheme.apply_project_font(l, UITheme.FONT_TITLE, true)
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

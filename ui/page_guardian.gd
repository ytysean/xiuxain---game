extends Control
# 护道人 UI（门下超潜力/亲传/嫡系弟子的护道体系）
# 后端：Game.护道人列表 / Game.检查护道人需求(d) / Game.自动配备护道人(d) / Game.护道人配置
# 颜色一律走 UITheme 真实 const，禁硬编码
# ★ PH7-12 逐页精修（2026-09-18）：手搓 66 高顶栏 → UITheme.建顶栏；_分隔() → apply_section_title；
#   _行()/_说明()/_状态文本 补字号档（原不设字号 ⇒ 落引擎默认 15px、未设项目字体）；配备按钮高 44 → 48。
#   业务逻辑一行未动。


signal 返回主页

const TABS: Array = ["在册护道", "待配备"]

var _built: bool = false
var _cur: String = "在册护道"
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
	main.add_theme_constant_override("margin_left", UITheme.MARGIN)
	main.add_theme_constant_override("margin_right", UITheme.MARGIN)
	add_child(main)
	# ★ PH7-12：手搓 66 高顶栏（文字方钮 + FONT_TITLE 标题）→ 收口到 建顶栏
	#   （金环返回键 + 亮金页面标题 + 72 高，全站二级页同款）。
	main.add_child(UITheme.建顶栏("护道人", _on返回))
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
	UITheme.apply_project_font(_状态文本, UITheme.FONT_AUX)
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
		"在册护道": _建_在册()
		"待配备": _建_待配备()

func _on返回() -> void:
	返回主页.emit()

func _弟子名表() -> Dictionary:
	var 表: Dictionary = {}
	for d in Game.弟子列表:
		if d != null and d is Disciple:
			表[int(d.弟子ID)] = str(d.姓名)
	return 表

func _建_在册() -> void:
	var _fb1 := _标题("在册护道名录")
	_content.add_child(_fb1)
	_fb1.modulate.a = 0.0
	_fb1.create_tween().tween_property(_fb1, "modulate:a", 1.0, 0.25)
	var 名表: Dictionary = _弟子名表()
	if Game.护道人列表.is_empty():
		var _fb2 := _行("暂无在册护道人。门下超潜力、宗主亲传、嫡系血脉弟子需要护道。", UITheme.COLOR_TEXT_AUX, true)
		_content.add_child(_fb2)
		_fb2.modulate.a = 0.0
		_fb2.create_tween().tween_property(_fb2, "modulate:a", 1.0, 0.25)
		return
	for 弟子ID in Game.护道人列表:
		var 护 = Game.护道人列表[弟子ID]
		if 护 == null:
			continue
		var 名: String = str(名表.get(int(弟子ID), "弟子#%d" % int(弟子ID)))
		var 剩余: int = int(护.get("到期日", 0)) - int(Game.累计游戏日)
		var 符: String = "（持替死玉符）" if bool(护.get("替死玉符", false)) else ""
		var _fb3 := _行("%s · %s【%s】%s" % [名, str(护.get("护道人等级", "")), str(护.get("护道人姓名", "")), 符], UITheme.COLOR_TEXT_BODY_GOLD)
		_content.add_child(_fb3)
		_fb3.modulate.a = 0.0
		_fb3.create_tween().tween_property(_fb3, "modulate:a", 1.0, 0.25)
		var _fb4 := _说明("    功德 %d · 护道剩余 %d 日 · 修炼加成 +%.0f%%" % [int(护.get("功德", 0)), max(0, 剩余), Game.获取护道人修炼加成(int(弟子ID)) * 100.0])
		_content.add_child(_fb4)
		_fb4.modulate.a = 0.0
		_fb4.create_tween().tween_property(_fb4, "modulate:a", 1.0, 0.25)
	var _fb5 := _分隔("护道阶位（仙阶所需）")
	_content.add_child(_fb5)
	_fb5.modulate.a = 0.0
	_fb5.create_tween().tween_property(_fb5, "modulate:a", 1.0, 0.25)
	for 等级 in Game.护道人配置:
		var 配置 = Game.护道人配置[等级]
		if 配置 == null:
			continue
		var _fb6 := _说明("    %s：修炼 +%.0f%% · 突破 +%.0f%% · 救济 %.0f%%（仙阶 %d）" % [str(等级), float(配置.get("修炼加成", 0.0)) * 100.0, float(配置.get("突破加成", 0.0)) * 100.0, float(配置.get("救援概率", 0.0)) * 100.0, int(配置.get("VIP需求", 0))])
		_content.add_child(_fb6)
		_fb6.modulate.a = 0.0
		_fb6.create_tween().tween_property(_fb6, "modulate:a", 1.0, 0.25)

func _建_待配备() -> void:
	var _fb7 := _标题("待配护道弟子")
	_content.add_child(_fb7)
	_fb7.modulate.a = 0.0
	_fb7.create_tween().tween_property(_fb7, "modulate:a", 1.0, 0.25)
	var _fb8 := _说明("超潜力（天品灵根·资质≥90·未满30）、宗主亲传、嫡系血脉，皆当配护道。")
	_content.add_child(_fb8)
	_fb8.modulate.a = 0.0
	_fb8.create_tween().tween_property(_fb8, "modulate:a", 1.0, 0.25)
	var 数: int = 0
	for d in Game.弟子列表:
		if d == null or not (d is Disciple):
			continue
		var 需求: String = str(Game.检查护道人需求(d))
		if 需求 == "":
			continue
		if Game.护道人列表.has(d.弟子ID):
			continue
		数 += 1
		var 按钮: Button = Button.new()
		按钮.text = "为【%s】配备护道人（%s）" % [str(d.姓名), 需求]
		按钮.custom_minimum_size = Vector2(0, 48)
		按钮.pressed.connect(Callable(self, "_配备").bind(d))
		_content.add_child(按钮)
		按钮.modulate.a = 0.0
		按钮.create_tween().tween_property(按钮, "modulate:a", 1.0, 0.25)
	if 数 == 0:
		var _fb9 := _行("当前无需配备护道人的弟子。", UITheme.COLOR_TEXT_AUX, true)
		_content.add_child(_fb9)
		_fb9.modulate.a = 0.0
		_fb9.create_tween().tween_property(_fb9, "modulate:a", 1.0, 0.25)

func _配备(d: Disciple) -> void:
	var r: Dictionary = Game.自动配备护道人(d)
	_刷新内容()
	if bool(r.get("成功", false)):
		_update状态("已为【%s】配备%s【%s】" % [str(d.姓名), str(r.get("护道人等级", "")), str(r.get("护道人姓名", ""))])
	else:
		_update状态("配备未成：%s" % str(r.get("原因", "")))

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
	# ★ PH7-12：分区标题收口到语义角色 apply_section_title（33 Bold 米白），
	#   原 FONT_TITLE(45) 与页面标题 FONT_H1(48) 视觉同级 ⇒ 层级塌陷。
	var l: Label = Label.new()
	l.text = t
	UITheme.apply_section_title(l)
	return l

func _行(t: String, 色: Color, 辅: bool = false) -> Label:
	# ★ PH7-12：原不设字号 ⇒ 落引擎默认 15px。按语义补档：辅=FONT_AUX(21) / 默认 FONT_BODY(27)。
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", 色)
	UITheme.apply_project_font(l, UITheme.FONT_AUX if 辅 else UITheme.FONT_BODY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _说明(t: String) -> Label:
	# ★ PH7-12：补 FONT_AUX(21)（原落引擎默认 15px）。
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	UITheme.apply_project_font(l, UITheme.FONT_AUX)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

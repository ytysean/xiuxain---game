extends Control
# 风水堪舆 UI（堪舆地脉 · 寻灵眼）
# 后端：Game.堪舆地脉() / Game.已发现灵眼 / Game.堪舆等级 / Game.风水布局
# 颜色一律走 UITheme 真实 const，禁硬编码


signal 返回主页

const TABS: Array = ["总览", "堪舆"]
const 方位表: Array = ["东方", "西方", "南方", "北方", "中央", "东南", "东北", "西南", "西北"]

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
	# 修复（实机验收抓出 · 2026-09-12）：本页根节点是 Control（非容器），子节点 anchors
	# 全 0 → ScrollContainer 最小尺寸为 0，会塌成 0×0 且 clip_contents=true 把正文整块
	# 裁掉（实机 dump：ScrollContainer size=(0.0, 0.0)）。与 page_chat 同构：
	# 先挂一个全屏 VBoxContainer 作为唯一布局宿主。
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
	标题.text = "  风水堪舆"
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
	# 关横向滚动：否则 ScrollContainer 不拉伸子节点，autowrap Label 最小宽度≈1px
	# → 修好宿主后正文仍会逐字竖排（上轮同一坑：三条叠加时只改一条肉眼无效）。
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
		"堪舆": _建_堪舆()

func _on返回() -> void:
	返回主页.emit()

func _建_总览() -> void:
	var _fb1 := _标题("宗门堪舆")
	_content.add_child(_fb1)
	_fb1.modulate.a = 0.0
	_fb1.create_tween().tween_property(_fb1, "modulate:a", 1.0, 0.25)
	var _fb2 := _行("堪舆造诣：%d 级（修为 %d）· 今日已堪 %d / 3" % [int(Game.堪舆等级), int(Game.堪舆经验), int(Game.今日堪舆次数)], UITheme.COLOR_TEXT_BODY_GOLD)
	_content.add_child(_fb2)
	_fb2.modulate.a = 0.0
	_fb2.create_tween().tween_property(_fb2, "modulate:a", 1.0, 0.25)
	var _fb3 := _说明("堪舆造诣愈深，寻得灵眼之机愈大；灵眼既得，殿阁布局其上则可望大吉。")
	_content.add_child(_fb3)
	_fb3.modulate.a = 0.0
	_fb3.create_tween().tween_property(_fb3, "modulate:a", 1.0, 0.25)
	var _fb4 := _分隔("已得灵眼 %d 处" % Game.已发现灵眼.size())
	_content.add_child(_fb4)
	_fb4.modulate.a = 0.0
	_fb4.create_tween().tween_property(_fb4, "modulate:a", 1.0, 0.25)
	if Game.已发现灵眼.is_empty():
		var _fb5 := _行("宗门四方尚无灵眼。", UITheme.COLOR_TEXT_AUX)
		_content.add_child(_fb5)
		_fb5.modulate.a = 0.0
		_fb5.create_tween().tween_property(_fb5, "modulate:a", 1.0, 0.25)
	for 位 in Game.已发现灵眼:
		var _fb6 := _行("◆ %s" % str(位), UITheme.COLOR_STATUS_SUCCESS)
		_content.add_child(_fb6)
		_fb6.modulate.a = 0.0
		_fb6.create_tween().tween_property(_fb6, "modulate:a", 1.0, 0.25)
	var _fb7 := _分隔("风水评级")
	_content.add_child(_fb7)
	_fb7.modulate.a = 0.0
	_fb7.create_tween().tween_property(_fb7, "modulate:a", 1.0, 0.25)
	var 评文: String = ""
	for 级 in Game.风水评级:
		评文 += ("" if 评文 == "" else " → ") + str(级)
	var _fb8 := _行(评文, UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb8)
	_fb8.modulate.a = 0.0
	_fb8.create_tween().tween_property(_fb8, "modulate:a", 1.0, 0.25)
	if Game.风水布局.size() > 0:
		var _fb9 := _分隔("殿阁布局既成 %d 处" % Game.风水布局.size())
		_content.add_child(_fb9)
		_fb9.modulate.a = 0.0
		_fb9.create_tween().tween_property(_fb9, "modulate:a", 1.0, 0.25)
		for 殿 in Game.风水布局:
			var 布 = Game.风水布局[殿]
			if 布 == null:
				continue
			var _fb10 := _说明("    %s：%s · %s" % [str(殿), str(布.get("位置", "")), str(布.get("评级", ""))])
			_content.add_child(_fb10)
			_fb10.modulate.a = 0.0
			_fb10.create_tween().tween_property(_fb10, "modulate:a", 1.0, 0.25)
	if not _最近.is_empty():
		var 成: bool = bool(_最近.get("成功", false))
		var 得: bool = bool(_最近.get("发现灵眼", false))
		var _fb11 := _分隔("上次堪舆")
		_content.add_child(_fb11)
		_fb11.modulate.a = 0.0
		_fb11.create_tween().tween_property(_fb11, "modulate:a", 1.0, 0.25)
		var _fb12 := _行(("于%s发现灵眼一处！" % str(_最近.get("灵眼位置", ""))) if 得 else ("未获新灵眼" if 成 else str(_最近.get("原因", ""))), UITheme.COLOR_STATUS_SUCCESS if 得 else (UITheme.COLOR_TEXT_BODY if 成 else UITheme.COLOR_TEXT_RED))
		_content.add_child(_fb12)
		_fb12.modulate.a = 0.0
		_fb12.create_tween().tween_property(_fb12, "modulate:a", 1.0, 0.25)

func _建_堪舆() -> void:
	var _fb13 := _标题("堪舆地脉")
	_content.add_child(_fb13)
	_fb13.modulate.a = 0.0
	_fb13.create_tween().tween_property(_fb13, "modulate:a", 1.0, 0.25)
	var _fb14 := _说明("一日堪舆三次为度。堪舆既毕，或于某方寻得灵眼。")
	_content.add_child(_fb14)
	_fb14.modulate.a = 0.0
	_fb14.create_tween().tween_property(_fb14, "modulate:a", 1.0, 0.25)
	var 按钮: Button = Button.new()
	按钮.text = "堪舆宗门地脉"
	按钮.custom_minimum_size = Vector2(0, 52)
	按钮.disabled = int(Game.今日堪舆次数) >= 3
	按钮.pressed.connect(_堪舆)
	_content.add_child(按钮)
	按钮.modulate.a = 0.0
	按钮.create_tween().tween_property(按钮, "modulate:a", 1.0, 0.25)
	var _fb15 := _分隔("灵眼方位一览")
	_content.add_child(_fb15)
	_fb15.modulate.a = 0.0
	_fb15.create_tween().tween_property(_fb15, "modulate:a", 1.0, 0.25)
	for 位 in 方位表:
		var 有: bool = Game.已发现灵眼.has(str(位))
		var _fb16 := _行("%s%s" % ["◆ " if 有 else "◇ ", str(位)], UITheme.COLOR_STATUS_SUCCESS if 有 else UITheme.COLOR_TEXT_AUX)
		_content.add_child(_fb16)
		_fb16.modulate.a = 0.0
		_fb16.create_tween().tween_property(_fb16, "modulate:a", 1.0, 0.25)

func _堪舆() -> void:
	_最近 = Game.堪舆地脉()
	_刷新内容()
	if bool(_最近.get("成功", false)):
		if bool(_最近.get("发现灵眼", false)):
			_update状态("堪舆得灵眼一处，在宗门%s" % str(_最近.get("灵眼位置", "")))
		else:
			_update状态("堪舆已毕，此番未见灵眼。")
	else:
		_update状态("堪舆未成：%s" % str(_最近.get("原因", "")))

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

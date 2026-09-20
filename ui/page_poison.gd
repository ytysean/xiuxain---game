extends Control
# 毒道 UI（毒医双修 · 修真界毒道旁门）
# 后端：Game.毒道总览() / Game.毒道境界表 / Game.毒体境界表 / Game.宗门库房（类别 du_yao）
# 颜色一律走 UITheme 真实 const，禁硬编码


signal 返回主页

const TABS: Array = ["总览", "毒物库", "境界"]

var _built: bool = false
var _cur: String = "总览"
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}

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
	标题.text = "  毒道"
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
		"毒物库": _建_毒物库()
		"境界": _建_境界()

func _on返回() -> void:
	返回主页.emit()

func _建_总览() -> void:
	var 览: Dictionary = Game.毒道总览()
	var _fb1 := _标题("毒道总览")
	_content.add_child(_fb1)
	_fb1.modulate.a = 0.0
	_fb1.create_tween().tween_property(_fb1, "modulate:a", 1.0, 0.25)
	var _fb2 := _行("毒道境界：%s（修为 %d）" % [str(览.get("毒道境界", "")), int(览.get("毒道经验", 0))], UITheme.COLOR_TEXT_BODY_GOLD)
	_content.add_child(_fb2)
	_fb2.modulate.a = 0.0
	_fb2.create_tween().tween_property(_fb2, "modulate:a", 1.0, 0.25)
	var _fb3 := _行("毒体境界：%s" % str(览.get("毒体境界", "")), UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb3)
	_fb3.modulate.a = 0.0
	_fb3.create_tween().tween_property(_fb3, "modulate:a", 1.0, 0.25)
	var _fb4 := _说明("毒医双修：毒道愈深，炼丹愈精、解毒愈强；毒体愈固，万毒难侵。")
	_content.add_child(_fb4)
	_fb4.modulate.a = 0.0
	_fb4.create_tween().tween_property(_fb4, "modulate:a", 1.0, 0.25)
	var _fb5 := _分隔("宗门毒室")
	_content.add_child(_fb5)
	_fb5.modulate.a = 0.0
	_fb5.create_tween().tween_property(_fb5, "modulate:a", 1.0, 0.25)
	var _fb6 := _行("毒室品级：%d" % int(览.get("毒室等级", 0)), UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb6)
	_fb6.modulate.a = 0.0
	_fb6.create_tween().tween_property(_fb6, "modulate:a", 1.0, 0.25)
	var _fb7 := _行("炼丹成功率加成：+%.0f%%" % (float(览.get("炼丹成功率加成", 0.0)) * 100.0), UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb7)
	_fb7.modulate.a = 0.0
	_fb7.create_tween().tween_property(_fb7, "modulate:a", 1.0, 0.25)
	var _fb8 := _行("解毒药效果：×%.1f" % float(览.get("解毒药效果加成", 1.0)), UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb8)
	_fb8.modulate.a = 0.0
	_fb8.create_tween().tween_property(_fb8, "modulate:a", 1.0, 0.25)
	var _fb9 := _行("可炼制毒药：%d 种 · 库中存有 %d 种" % [int(览.get("可炼制毒药", 0)), int(览.get("毒药数量", 0))], UITheme.COLOR_TEXT_AUX)
	_content.add_child(_fb9)
	_fb9.modulate.a = 0.0
	_fb9.create_tween().tween_property(_fb9, "modulate:a", 1.0, 0.25)

func _建_毒物库() -> void:
	var _fb10 := _标题("库中毒物")
	_content.add_child(_fb10)
	_fb10.modulate.a = 0.0
	_fb10.create_tween().tween_property(_fb10, "modulate:a", 1.0, 0.25)
	var 数: int = 0
	for it in Game.宗门库房:
		if it == null or not (it is Item):
			continue
		if str(it.类别) != "du_yao":
			continue
		数 += 1
		var _fb11 := _行("%s ×%d" % [str(it.名称), int(it.数量)], UITheme.COLOR_TEXT_BODY)
		_content.add_child(_fb11)
		_fb11.modulate.a = 0.0
		_fb11.create_tween().tween_property(_fb11, "modulate:a", 1.0, 0.25)
		if str(it.描述) != "":
			var _fb12 := _说明("    %s" % str(it.描述))
			_content.add_child(_fb12)
			_fb12.modulate.a = 0.0
			_fb12.create_tween().tween_property(_fb12, "modulate:a", 1.0, 0.25)
	if 数 == 0:
		var _fb13 := _行("库中暂无毒物。炼制毒药需先建毒室、备齐毒草。", UITheme.COLOR_TEXT_AUX)
		_content.add_child(_fb13)
		_fb13.modulate.a = 0.0
		_fb13.create_tween().tween_property(_fb13, "modulate:a", 1.0, 0.25)

func _建_境界() -> void:
	var _fb14 := _标题("毒道五境")
	_content.add_child(_fb14)
	_fb14.modulate.a = 0.0
	_fb14.create_tween().tween_property(_fb14, "modulate:a", 1.0, 0.25)
	var 当前道: String = str(Game.获取毒道境界())
	for 境 in Game.毒道境界表:
		var 名: String = str(境.get("境界", ""))
		var 标: bool = 名 == 当前道
		var _fb15 := _行("%s%s · 需修为 %d" % ["◆ " if 标 else "◇ ", 名, int(境.get("所需经验", 0))], UITheme.COLOR_TEXT_BODY_GOLD if 标 else UITheme.COLOR_TEXT_BODY)
		_content.add_child(_fb15)
		_fb15.modulate.a = 0.0
		_fb15.create_tween().tween_property(_fb15, "modulate:a", 1.0, 0.25)
		var _fb16 := _说明("    %s" % str(境.get("描述", "")))
		_content.add_child(_fb16)
		_fb16.modulate.a = 0.0
		_fb16.create_tween().tween_property(_fb16, "modulate:a", 1.0, 0.25)
	var _fb17 := _分隔("毒体六境")
	_content.add_child(_fb17)
	_fb17.modulate.a = 0.0
	_fb17.create_tween().tween_property(_fb17, "modulate:a", 1.0, 0.25)
	var 当前体: String = str(Game.获取毒体境界())
	for 境 in Game.毒体境界表:
		var 名: String = str(境.get("境界", ""))
		var 标: bool = 名 == 当前体
		var _fb18 := _行("%s%s · 毒抗 %.0f%%" % ["◆ " if 标 else "◇ ", 名, float(境.get("毒抗", 0.0)) * 100.0], UITheme.COLOR_TEXT_BODY_GOLD if 标 else UITheme.COLOR_TEXT_BODY)
		_content.add_child(_fb18)
		_fb18.modulate.a = 0.0
		_fb18.create_tween().tween_property(_fb18, "modulate:a", 1.0, 0.25)
		var _fb19 := _说明("    %s" % str(境.get("描述", "")))
		_content.add_child(_fb19)
		_fb19.modulate.a = 0.0
		_fb19.create_tween().tween_property(_fb19, "modulate:a", 1.0, 0.25)

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

extends Control
# 商道总览 UI（经商商道系统 S8 深化：P0 商道境界 + P1 行情 + P2 商铺经营 + P3 护卫/稀有 + 周常/图录/消耗品）
# 后端：Game.商队系统（CaravanSystem）；图录复用 Game.收藏图录_已收集
# 颜色一律走 UITheme 真实 const，禁硬编码
# ★ PH7-11 逐页精修（2026-09-18）：手搓 66 高顶栏 → UITheme.建顶栏；_标() 补字号档
#   （原「非大」分支不设字号 ⇒ 落引擎默认 15、连项目字体都未设）；分区标题 FONT_TITLE(45) → apply_section_title(33)；
#   按钮/下拉高 30–36 → 48（对齐全站主流，30/32/34 高在手机端低于触控标准）。业务逻辑一行未动。


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
	main.add_theme_constant_override("margin_left", UITheme.MARGIN)
	main.add_theme_constant_override("margin_right", UITheme.MARGIN)
	add_child(main)
	# ★ PH7-11：手搓 66 高顶栏（文字方钮 + FONT_TITLE 标题）→ 收口到 建顶栏
	#   （金环返回键 + 亮金页面标题 + 72 高，全站二级页同款）。
	main.add_child(UITheme.建顶栏("商道", _on返回))
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
	UITheme.刷新标签高亮(_tab_btns, _cur)

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
	# ★ PH7-11：分区标题收口到语义角色 apply_section_title（33 Bold 米白），
	#   原 FONT_TITLE(45) 与页面标题 FONT_H1(48) 视觉同级 ⇒ 层级塌陷。
	var l: Label = Label.new()
	l.text = t
	UITheme.apply_section_title(l)
	return l

func _标(t: String, c: Color, 大: bool = false, 辅: bool = false) -> Label:
	# ★ PH7-11：原「非大」分支**不设字号** ⇒ 落引擎默认 15（且未设项目字体）。
	#   现按语义补档：大=FONT_H1(48) / 辅=FONT_AUX(21) / 默认 FONT_BODY(27)，字体一并回到思源黑体。
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", c)
	if 大:
		UITheme.apply_project_font(l, UITheme.FONT_H1, true)
	elif 辅:
		UITheme.apply_project_font(l, UITheme.FONT_AUX)
	else:
		UITheme.apply_project_font(l, UITheme.FONT_BODY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _商() -> CaravanSystem:
	return Game.商队系统

# ---------- 总览 ----------
func _建_总览() -> void:
	var 商 = _商()
	var _fb1 := _标("商道·总览", UITheme.COLOR_TEXT_GOLD, true)
	_content.add_child(_fb1)
	_fb1.modulate.a = 0.0
	_fb1.create_tween().tween_property(_fb1, "modulate:a", 1.0, 0.25)
	var _fb2 := _标("宗门运转，商道为脉。行商有境，低买高卖，分店置产，奇珍可期。", UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb2)
	_fb2.modulate.a = 0.0
	_fb2.create_tween().tween_property(_fb2, "modulate:a", 1.0, 0.25)
	# 商道境界进度
	var _fb3 := _分隔("商道境界")
	_content.add_child(_fb3)
	_fb3.modulate.a = 0.0
	_fb3.create_tween().tween_property(_fb3, "modulate:a", 1.0, 0.25)
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
	var _fb4 := _标(境文, UITheme.COLOR_TEXT_BODY_GOLD)
	_content.add_child(_fb4)
	_fb4.modulate.a = 0.0
	_fb4.create_tween().tween_property(_fb4, "modulate:a", 1.0, 0.25)
	var _fb5 := _标("价差加成 +%.0f%%　风险减免 -%.0f%%" % [商.获取商道境界加成() * 100, 商.获取商道风险减免() * 100], UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb5)
	_fb5.modulate.a = 0.0
	_fb5.create_tween().tween_property(_fb5, "modulate:a", 1.0, 0.25)
	# 累计
	var _fb6 := _分隔("贸易总览")
	_content.add_child(_fb6)
	_fb6.modulate.a = 0.0
	_fb6.create_tween().tween_property(_fb6, "modulate:a", 1.0, 0.25)
	var _fb7 := _标("累计贸易 %d 次，累计收益 %d 灵石" % [商.累计贸易次数, 商.累计贸易收益], UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb7)
	_fb7.modulate.a = 0.0
	_fb7.create_tween().tween_property(_fb7, "modulate:a", 1.0, 0.25)
	# 周常
	var _fb8 := _分隔("宗门商道会（周常）")
	_content.add_child(_fb8)
	_fb8.modulate.a = 0.0
	_fb8.create_tween().tween_property(_fb8, "modulate:a", 1.0, 0.25)
	var _fb9 := _标("本周参与贸易大赛 %d / 3（威望奖励，防通胀）" % 商.商道周常本周参与, UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb9)
	_fb9.modulate.a = 0.0
	_fb9.create_tween().tween_property(_fb9, "modulate:a", 1.0, 0.25)
	var 大赛: Button = Button.new()
	大赛.text = "参与贸易大赛（威望+30）"
	大赛.custom_minimum_size = Vector2(220, 48)
	大赛.pressed.connect(_参与大赛)
	_content.add_child(大赛)
	大赛.modulate.a = 0.0
	大赛.create_tween().tween_property(大赛, "modulate:a", 1.0, 0.25)
	# 消耗品 sink
	var _fb10 := _分隔("商道消耗 · 求购")
	_content.add_child(_fb10)
	_fb10.modulate.a = 0.0
	_fb10.create_tween().tween_property(_fb10, "modulate:a", 1.0, 0.25)
	var 令: Button = Button.new(); 令.text = "求购商道令（价差+8%，200灵石）"; 令.custom_minimum_size = Vector2(260, 48); 令.pressed.connect(_求购.bind("令")); _content.add_child(令)
	令.modulate.a = 0.0
	令.create_tween().tween_property(令, "modulate:a", 1.0, 0.25)
	var 符: Button = Button.new(); 符.text = "求购通商符（降时30%，150灵石）"; 符.custom_minimum_size = Vector2(260, 48); 符.pressed.connect(_求购.bind("符")); _content.add_child(符)
	符.modulate.a = 0.0
	符.create_tween().tween_property(符, "modulate:a", 1.0, 0.25)
	var 帖: Button = Button.new(); 帖.text = "求购拜帖（解锁商单，120灵石）"; 帖.custom_minimum_size = Vector2(260, 48); 帖.pressed.connect(_求购.bind("帖")); _content.add_child(帖)
	帖.modulate.a = 0.0
	帖.create_tween().tween_property(帖, "modulate:a", 1.0, 0.25)

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
	UITheme.apply_project_font(l, UITheme.FONT_AUX)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)

# ---------- 商铺 ----------
func _建_商铺() -> void:
	var 商 = _商()
	var _fb11 := _标("商铺经营·分店放置", UITheme.COLOR_TEXT_GOLD, true)
	_content.add_child(_fb11)
	_fb11.modulate.a = 0.0
	_fb11.create_tween().tween_property(_fb11, "modulate:a", 1.0, 0.25)
	var _fb12 := _标("于已开通商路之城设铺，每日自动产销。品级上限随商道境界：%d品。" % 商.商铺等级上限(), UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb12)
	_fb12.modulate.a = 0.0
	_fb12.create_tween().tween_property(_fb12, "modulate:a", 1.0, 0.25)
	# 现有商铺
	var _fb13 := _分隔("现有商铺 (%d)" % 商.商铺列表.size())
	_content.add_child(_fb13)
	_fb13.modulate.a = 0.0
	_fb13.create_tween().tween_property(_fb13, "modulate:a", 1.0, 0.25)
	if 商.商铺列表.is_empty():
		var _fb14 := _标("尚无分店，于下方开设。", UITheme.COLOR_TEXT_AUX, false, true)
		_content.add_child(_fb14)
		_fb14.modulate.a = 0.0
		_fb14.create_tween().tween_property(_fb14, "modulate:a", 1.0, 0.25)
	for i in range(商.商铺列表.size()):
		var 铺 = 商.商铺列表[i]
		var 行: HBoxContainer = HBoxContainer.new()
		var 文: Label = Label.new()
		文.text = "%s@%s　%d级" % [str(铺.get("类型", "")), _城市名(str(铺.get("城市ID", ""))), int(铺.get("等级", 1))]
		文.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
		UITheme.apply_project_font(文, UITheme.FONT_BODY)
		行.add_child(文)
		文.modulate.a = 0.0
		文.create_tween().tween_property(文, "modulate:a", 1.0, 0.25)
		var 升: Button = Button.new(); 升.text = "升级"; 升.custom_minimum_size = Vector2(70, 48); 升.pressed.connect(_升级.bind(i)); 行.add_child(升)
		升.modulate.a = 0.0
		升.create_tween().tween_property(升, "modulate:a", 1.0, 0.25)
		var 关: Button = Button.new(); 关.text = "关闭"; 关.custom_minimum_size = Vector2(70, 48); 关.pressed.connect(_关闭.bind(i)); 行.add_child(关)
		关.modulate.a = 0.0
		关.create_tween().tween_property(关, "modulate:a", 1.0, 0.25)
		_content.add_child(行)
		行.modulate.a = 0.0
		行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	# 开设区
	var _fb15 := _分隔("开设新铺")
	_content.add_child(_fb15)
	_fb15.modulate.a = 0.0
	_fb15.create_tween().tween_property(_fb15, "modulate:a", 1.0, 0.25)
	_选城市 = OptionButton.new(); _选城市.custom_minimum_size = Vector2(160, 48)
	for d in 商.商队地区:
		if 商.检查商路城市解锁(str(d.get("unlock_condition", "")), str(d.get("id", ""))):
			_选城市.add_item("%s" % str(d.get("名称", "")))
	var _fb16 := _标("选择城邦：", UITheme.COLOR_TEXT_AUX, false, true)
	_content.add_child(_fb16)
	_fb16.modulate.a = 0.0
	_fb16.create_tween().tween_property(_fb16, "modulate:a", 1.0, 0.25)
	_content.add_child(_选城市)
	_选城市.modulate.a = 0.0
	_选城市.create_tween().tween_property(_选城市, "modulate:a", 1.0, 0.25)
	_选类型 = OptionButton.new(); _选类型.custom_minimum_size = Vector2(160, 48)
	for 类型 in 商.可开商铺类型():
		_选类型.add_item(类型)
	var _fb17 := _标("选择类型（受商道境界限制）：", UITheme.COLOR_TEXT_AUX, false, true)
	_content.add_child(_fb17)
	_fb17.modulate.a = 0.0
	_fb17.create_tween().tween_property(_fb17, "modulate:a", 1.0, 0.25)
	_content.add_child(_选类型)
	_选类型.modulate.a = 0.0
	_选类型.create_tween().tween_property(_选类型, "modulate:a", 1.0, 0.25)
	var 开: Button = Button.new(); 开.text = "开设商铺"; 开.custom_minimum_size = Vector2(160, 48); 开.pressed.connect(_开设); _content.add_child(开)
	开.modulate.a = 0.0
	开.create_tween().tween_property(开, "modulate:a", 1.0, 0.25)

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
	var _fb18 := _标("商路行情一览", UITheme.COLOR_TEXT_GOLD, true)
	_content.add_child(_fb18)
	_fb18.modulate.a = 0.0
	_fb18.create_tween().tween_property(_fb18, "modulate:a", 1.0, 0.25)
	var _fb19 := _标("各地分品类行情倍率（绿=低迷可囤，红=暴涨可抛）。按现实日刷新。", UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb19)
	_fb19.modulate.a = 0.0
	_fb19.create_tween().tween_property(_fb19, "modulate:a", 1.0, 0.25)
	var 一览 = _商().获取行情一览()
	if 一览.is_empty():
		var _fb20 := _标("暂无已开通商路。", UITheme.COLOR_TEXT_AUX, false, true)
		_content.add_child(_fb20)
		_fb20.modulate.a = 0.0
		_fb20.create_tween().tween_property(_fb20, "modulate:a", 1.0, 0.25)
	for 城 in 一览:
		var _fb21 := _分隔(str(城.get("地区名", "")))
		_content.add_child(_fb21)
		_fb21.modulate.a = 0.0
		_fb21.create_tween().tween_property(_fb21, "modulate:a", 1.0, 0.25)
		for q in 城.get("行情", []):
			var 倍 = float(q.get("倍率", 1.0))
			var c = UITheme.COLOR_TEXT_BODY
			if 倍 <= 0.95:
				c = UITheme.COLOR_STATUS_SUCCESS
			elif 倍 >= 1.2:
				c = UITheme.COLOR_TEXT_RED
			var _fb22 := _标("%s：×%.2f（%s）" % [str(q.get("类别", "")), 倍, str(q.get("状态", ""))], c)
			_content.add_child(_fb22)
			_fb22.modulate.a = 0.0
			_fb22.create_tween().tween_property(_fb22, "modulate:a", 1.0, 0.25)

# ---------- 商道录 ----------
func _建_图录() -> void:
	var 已收: Array = Game.收藏图录_已收集.get("商道", [])
	var 全部: Array = []
	for r in Game.图录配置:
		if r.get("类别") == "商道":
			全部.append(r.get("匹配名", ""))
	var _fb23 := _标("商道录：已收录 %d / %d" % [已收.size(), 全部.size()], UITheme.COLOR_TEXT_GOLD, true)
	_content.add_child(_fb23)
	_fb23.modulate.a = 0.0
	_fb23.create_tween().tween_property(_fb23, "modulate:a", 1.0, 0.25)
	var _fb24 := _标("跨域/高风险商路贸易淘得稀世奇珍，即录入商道录，流芳商界。", UITheme.COLOR_TEXT_BODY)
	_content.add_child(_fb24)
	_fb24.modulate.a = 0.0
	_fb24.create_tween().tween_property(_fb24, "modulate:a", 1.0, 0.25)
	for 名 in 全部:
		var l: Label = Label.new()
		if 已收.has(名):
			l.text = "✓ %s" % 名
			l.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS)
		else:
			l.text = "× %s（未收录）" % 名
			l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
		UITheme.apply_project_font(l, UITheme.FONT_BODY)
		_content.add_child(l)
		l.modulate.a = 0.0
		l.create_tween().tween_property(l, "modulate:a", 1.0, 0.25)

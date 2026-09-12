extends Control
# 探遗迹 UI（休闲玩法 S47-P0 核心探秘闭环）
# 后端：Game.探秘系统；图录复用 Game.收藏图录_已收集
# 颜色一律走 UITheme 真实 const，禁硬编码

const UITheme = preload("res://ui_theme.gd")

signal 返回主页

const TABS: Array = ["总览", "探秘", "图录"]

var _built: bool = false
var _cur: String = "总览"
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}
var _最近结果: Dictionary = {}
var _状态文本: Label = null
var _当前遗迹索引: int = 0
var _用符: bool = false
var _用香: bool = false

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
	标题.text = "  探遗迹"
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
		"探秘": _建_探秘()
		"图录": _建_图录()

func _on返回() -> void:
	返回主页.emit()

func _建_总览() -> void:
	var 探: RelicSystem = Game.探秘系统
	var 标题: Label = Label.new()
	标题.text = "探遗迹·总览"
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	标题.add_theme_font_size_override("font_size", 24)
	_content.add_child(标题)
	var 次: Label = Label.new()
	次.text = "累计探秘 %d 次。所获天材地宝入宗门库房，反哺炼器炼丹。" % 探.累计探秘次数
	次.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	次.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(次)
	var 提示: Label = Label.new()
	提示.text = "探遗迹为秘境探秘子型：择遗迹、参悟阵法，机缘所得皆归宗门。"
	提示.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(提示)
	var 探2: RelicSystem = Game.探秘系统
	var 境名: String = 探2.阵道境界名()
	var 进度: Dictionary = 探2.阵道进度()
	var 境: Label = Label.new()
	if 进度.get("满", false):
		境.text = "阵道境界：【%s】（已臻圆满）  累计探秘 %d 次" % [境名, 探2.累计探秘次数]
	else:
		var 下名: String = 探2.阵道境界表[探2.阵道境界 + 1].get("名", "") if 探2.阵道境界 + 1 < 探2.阵道境界表.size() else ""
		境.text = "阵道境界：【%s】  经验 %d / %d（再参悟得 %d 经验可晋%s）  累计探秘 %d 次" % [境名, 进度.get("已得", 0), 进度.get("需", 0), int(进度.get("需", 0)) - int(进度.get("已得", 0)), 下名, 探2.累计探秘次数]
	境.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	境.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(境)
	var 周规: Dictionary = 探2.获取本周探秘周()
	var 周: Label = Label.new()
	周.text = "本周探秘周：【%s】——%s（威望%d）  已参与 %d/3" % [周规.get("名称", ""), 周规.get("描述", ""), int(周规.get("奖励威望", 0)), 探2.本周探秘参与]
	周.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	周.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(周)

func _建_探秘() -> void:
	_content.add_child(_分隔("择遗迹·参悟阵法"))
	var 探: RelicSystem = Game.探秘系统
	var n: int = 探.遗迹数()
	for i in range(n):
		var 信息: Dictionary = 探.可探遗迹(i)
		var 行: Button = Button.new()
		var 锁: String = ("（不可探：需%s）" % 信息.get("需求境界名", "")) if not 信息.get("可探", false) else ""
		var 率: String = "%.0f%%" % (float(信息.get("成功率", 0.0)) * 100.0)
		行.text = "%s · %s阵（难度%d星）成功率%s %s" % [信息.get("名称", ""), 信息.get("阵法", ""), int(信息.get("难度星", 1)), 率, 锁]
		行.custom_minimum_size = Vector2(0, 44)
		行.pressed.connect(Callable(self, "_选遗迹").bind(i))
		if i == _当前遗迹索引:
			行.modulate = Color(1.0, 0.92, 0.6, 1.0)
		_content.add_child(行)
	_content.add_child(_分隔("破阵符·引灵香（消耗品）"))
	var 探3: RelicSystem = Game.探秘系统
	var 求符: Button = Button.new()
	求符.text = "求购破阵符（灵石%d）" % int(探3.消耗品配置("破阵符").get("价格", 0))
	求符.custom_minimum_size = Vector2(0, 40)
	求符.pressed.connect(_求购破阵符)
	_content.add_child(求符)
	var 求香: Button = Button.new()
	求香.text = "求购引灵香（灵石%d）" % int(探3.消耗品配置("引灵香").get("价格", 0))
	求香.custom_minimum_size = Vector2(0, 40)
	求香.pressed.connect(_求购引灵香)
	_content.add_child(求香)
	var 用符: Button = Button.new()
	用符.text = ("停用破阵符" if _用符 else "用破阵符（降难度）")
	用符.custom_minimum_size = Vector2(0, 40)
	用符.pressed.connect(_切换用符)
	_content.add_child(用符)
	var 用香: Button = Button.new()
	用香.text = ("停用引灵香" if _用香 else "用引灵香（提秘藏率）")
	用香.custom_minimum_size = Vector2(0, 40)
	用香.pressed.connect(_切换用香)
	_content.add_child(用香)
	var 参: Button = Button.new()
	参.text = "参悟阵法·入遗迹探秘"
	参.custom_minimum_size = Vector2(0, 48)
	参.pressed.connect(_探秘)
	_content.add_child(参)
	var 周赛: Button = Button.new()
	周赛.text = "参与本周探秘周赛"
	周赛.custom_minimum_size = Vector2(0, 44)
	周赛.pressed.connect(_参与探秘周)
	_content.add_child(周赛)
	_状态文本 = Label.new()
	_状态文本.text = "点按遗迹择之，再参悟阵法。"
	_状态文本.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	_状态文本.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_状态文本)
	if not _最近结果.is_empty():
		var r: Label = Label.new()
		r.text = _格式结果(_最近结果)
		r.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS if _最近结果.get("成功", false) else UITheme.COLOR_TEXT_RED)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(r)

func _探秘() -> void:
	var 参: Dictionary = Game.探秘系统.开始探秘(_当前遗迹索引)
	_最近结果 = Game.探秘系统.结算探秘(_当前遗迹索引, _用符, _用香)
	_刷新内容()
	if not _最近结果.get("成功", false):
		_update状态("探秘无获：%s" % _最近结果.get("原因", ""))
	elif not _最近结果.get("破阵", false):
		_update状态(_最近结果.get("提示", "阵法紊乱，参悟未成。"))
	else:
		_update状态("参悟功成，探得【%s】。" % _最近结果.get("名称", ""))

func _选遗迹(索引: int) -> void:
	_当前遗迹索引 = 索引
	_刷新内容()
	var 信息: Dictionary = Game.探秘系统.可探遗迹(索引)
	if 信息.get("可探", false):
		_update状态("已择【%s】，成功率 %.0f%%。点按参悟。" % [信息.get("名称", ""), float(信息.get("成功率", 0.0)) * 100.0])
	else:
		_update状态("【%s】不可探：%s" % [信息.get("名称", ""), 信息.get("原因", "")])

func _求购破阵符() -> void:
	var r: Dictionary = Game.探秘系统.求购消耗品("破阵符")
	if r.get("成功", false):
		_update状态("求购破阵符成功，耗灵石 %d。" % r.get("价", 0))
	else:
		_update状态("求购失败：%s" % r.get("原因", ""))

func _求购引灵香() -> void:
	var r: Dictionary = Game.探秘系统.求购消耗品("引灵香")
	if r.get("成功", false):
		_update状态("求购引灵香成功，耗灵石 %d。" % r.get("价", 0))
	else:
		_update状态("求购失败：%s" % r.get("原因", ""))

func _切换用符() -> void:
	var r: Dictionary = Game.探秘系统.配制破阵符(not _用符)
	if r.get("成功", false):
		_用符 = r.get("用", false)
		_update状态("破阵符：%s" % ("已启用" if _用符 else "已停用"))
	else:
		_update状态("不可启用：%s" % r.get("原因", ""))

func _切换用香() -> void:
	var r: Dictionary = Game.探秘系统.配制引灵香(not _用香)
	if r.get("成功", false):
		_用香 = r.get("用", false)
		_update状态("引灵香：%s" % ("已启用" if _用香 else "已停用"))
	else:
		_update状态("不可启用：%s" % r.get("原因", ""))

func _参与探秘周() -> void:
	var r: Dictionary = Game.探秘系统.参与探秘周()
	if r.get("成功", false):
		_update状态("参与本周探秘周赛【%s】，获宗主威望 %d（已参与%d次）。" % [r.get("规则", ""), r.get("威望", 0), r.get("参与", 0)])
	else:
		_update状态("参与失败：%s" % r.get("原因", ""))

func _update状态(t: String) -> void:
	if _状态文本 != null:
		_状态文本.text = t

func _格式结果(r: Dictionary) -> String:
	if not r.get("成功", false):
		return "空手：%s" % r.get("原因", "")
	if not r.get("破阵", false):
		return "阵法紊乱，参悟未成，然无损伤。"
	var s: String = "探得【%s】（%s·%s阶）\n%s\n用途：%s" % [r.get("名称", ""), r.get("分层", ""), r.get("品阶", ""), r.get("描述", ""), r.get("用途", "")]
	if r.get("秘藏", false):
		s += "\n★ 启出秘藏：【%s】" % r.get("秘藏名", "")
	if r.get("传承", false):
		s += "\n◆ 得上古传承残篇！"
	if r.get("经验", 0) > 0:
		s += "\n阵道经验 +%d" % r.get("经验", 0)
	return s

func _建_图录() -> void:
	var 已收: Array = Game.收藏图录_已收集.get("遗迹", [])
	var 全部: Array = []
	for r in Game.图录配置:
		if r.get("类别") == "遗迹":
			全部.append(r.get("匹配名", ""))
	var 标题: Label = Label.new()
	标题.text = "遗迹图录：已收录 %d / %d" % [已收.size(), 全部.size()]
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

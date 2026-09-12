extends Control
# 灵钓 UI（休闲玩法 S46-P0 核心钓鱼闭环）
# 后端：Game.灵钓系统（钓鱼产出/钓道境界/钓具）；图录复用 Game.收藏图录_已收集
# 交互：竖屏 1080x1920，下半屏单指 hold 收线 / release 放线，禁 QTE 精准点按
# 颜色一律走 UITheme 真实 const，禁硬编码（audit_uitheme_calls 0 臆造）


signal 返回主页

const TABS: Array = ["总览", "垂钓", "图录"]

var _built: bool = false
var _cur: String = "总览"
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}

# 垂钓运行时状态
var _垂钓中: bool = false
var _按住: bool = false
var _当前灵渊id: int = 0
var _张力参数: Dictionary = {}
var _张力: float = 0.0
var _渔获进度: float = 0.0
var _最近结果: Dictionary = {}
var _收线热区: Button = null
var _张力条: ProgressBar = null
var _渔获条: ProgressBar = null
var _状态文本: Label = null
var _选中图录: String = ""   # 图录详情展开的鱼名（空=未展开）

func _ready() -> void:
	_build()
	set_process(true)

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
	标题.text = "  灵渊垂钓"
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
	_垂钓中 = false
	_按住 = false
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
		"垂钓": _建_垂钓()
		"图录": _建_图录()

func _on返回() -> void:
	返回主页.emit()

# ===== 总览 =====
func _建_总览() -> void:
	var 钓 = Game.灵钓系统
	var 进度: Dictionary = 钓.钓道境界进度()
	var 标题: Label = Label.new()
	标题.text = "钓道境界：%s" % 钓.钓道境界名()
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	标题.add_theme_font_size_override("font_size", 24)
	_content.add_child(标题)
	var 进度文: Label = Label.new()
	if 进度.get("满", false):
		进度文.text = "已臻钓道极致。累计钓获 %d 次。" % 钓.累计钓获次数
	else:
		进度文.text = "经验 %d / %d（再获 %d 经验可晋%s）\n累计钓获 %d 次" % [进度.get("已得", 0), 进度.get("需", 0), 进度.get("需", 0) - 进度.get("已得", 0), 钓.钓道境界表[钓.钓道境界 + 1].get("名", ""), 钓.累计钓获次数]
	进度文.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	进度文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(进度文)
	var 钓具: Dictionary = 钓.获取钓具(int(钓.钓具配置.get("阶", 0)))
	var 钓具文: Label = Label.new()
	钓具文.text = "当前钓具：%s / %s / %s（断线率 %s）" % [钓具.get("灵杆", "青竹竿"), 钓具.get("灵线", "麻纶线"), 钓具.get("灵饵", "凡饵"), 钓具.get("断线率", "0.12")]
	钓具文.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	_content.add_child(钓具文)
	# 神秘类统计
	var 回溯符数: int = 钓.获取回溯符数量()
	var 混沌数: int = 钓.获取混沌孑遗图鉴().size()
	if 回溯符数 > 0 or 混沌数 > 0:
		var 神秘文: Label = Label.new()
		神秘文.text = "时空回溯符：%d枚 | 混沌孑遗收录：%d只" % [回溯符数, 混沌数]
		神秘文.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		_content.add_child(神秘文)
	var 提示: Label = Label.new()
	提示.text = "灵钓为道心憩息之地：零惩罚、强收集、所获灵物入宗门库房，反哺丹膳兽符。"
	提示.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(提示)
	var 晋: Button = Button.new()
	晋.text = "以灵材淬炼钓具（晋阶）"
	晋.custom_minimum_size = Vector2(0, 44)
	晋.pressed.connect(_晋升钓具)
	_content.add_child(晋)
	_content.add_child(_分隔("灵钓大赛（周常）"))
	var 规: Dictionary = Game.灵钓系统.获取本周大赛()
	var 规文: Label = Label.new()
	规文.text = "本周规则：%s\n%s（奖励宗主威望 %d）" % [规.get("名称", ""), 规.get("描述", ""), int(规.get("奖励威望", 0))]
	规文.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	规文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(规文)
	var 参赛: Button = Button.new()
	参赛.text = "参与本周灵钓大赛"
	参赛.custom_minimum_size = Vector2(0, 44)
	参赛.pressed.connect(_参与大赛)
	_content.add_child(参赛)

# ===== 垂钓 =====
func _建_垂钓() -> void:
	var 钓 = Game.灵钓系统
	_content.add_child(_分隔("选择灵渊"))
	for 渊 in 钓.可钓灵渊():
		var b: Button = Button.new()
		b.text = 渊.get("名", "灵渊")
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(Callable(self, "_选灵渊").bind(int(渊.get("id"))))
		_content.add_child(b)
	var 锁: Array = []
	for 渊 in 钓.灵渊表:
		if int(渊.get("需境界")) > 钓.钓道境界:
			锁.append("%s（需钓道【%s】）" % [渊.get("名"), 钓.钓道境界表[int(渊.get("需境界"))].get("名", "")])
	if not 锁.is_empty():
		var 锁文: Label = Label.new()
		锁文.text = "未解锁：%s" % "、".join(锁)
		锁文.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
		_content.add_child(锁文)
	_content.add_child(_分隔("灵饵"))
	for 饵 in Game.灵钓系统.钓鱼灵饵表:
		var eb: Button = Button.new()
		eb.text = 饵.get("名称", "凡饵")
		eb.custom_minimum_size = Vector2(0, 36)
		eb.pressed.connect(Callable(self, "_选灵饵").bind(饵.get("名称", "凡饵")))
		_content.add_child(eb)
	_content.add_child(_分隔(""))
	var 抛竿: Button = Button.new()
	抛竿.text = "抛竿入水"
	抛竿.custom_minimum_size = Vector2(0, 48)
	抛竿.pressed.connect(_抛竿)
	_content.add_child(抛竿)
	_张力条 = ProgressBar.new()
	_张力条.max_value = 100.0
	_张力条.value = 0.0
	_张力条.custom_minimum_size = Vector2(0, 24)
	_content.add_child(_张力条)
	_渔获条 = ProgressBar.new()
	_渔获条.max_value = 1.0
	_渔获条.value = 0.0
	_渔获条.custom_minimum_size = Vector2(0, 24)
	_content.add_child(_渔获条)
	_状态文本 = Label.new()
	_状态文本.text = "按住下方水域收线、松开放线；保持张力于绿区（42~68）待鱼力竭。"
	_状态文本.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	_状态文本.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_状态文本)
	# 单指收线热区（覆盖下半屏）
	_收线热区 = Button.new()
	_收线热区.text = "▼ 按住收线 · 松开放线 ▼"
	_收线热区.custom_minimum_size = Vector2(0, 120)
	_收线热区.visible = false
	_收线热区.button_down.connect(_on收线按下)
	_收线热区.button_up.connect(_on收线抬起)
	_content.add_child(_收线热区)
	if not _最近结果.is_empty():
		if bool(_最近结果.get("成功", false)) and String(_最近结果.get("名称", "")) != "":
			var 鱼图: TextureRect = TextureRect.new()
			# 混沌孑遗使用变体立绘
			var 变体ID: int = int(_最近结果.get("混沌变体ID", -1))
			鱼图.texture = Game.灵钓系统.获取灵鱼立绘(String(_最近结果.get("名称", "")), 变体ID)
			if 鱼图.texture != null:
				鱼图.custom_minimum_size = Vector2(0, 308)
				鱼图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				鱼图.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				鱼图.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_content.add_child(鱼图)
		var r: Label = Label.new()
		r.text = _格式结果(_最近结果)
		r.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS if _最近结果.get("成功", false) else UITheme.COLOR_TEXT_RED)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(r)
		# 混沌孑遗命名输入框
		if bool(_最近结果.get("需要命名", false)):
			var 命名行: HBoxContainer = HBoxContainer.new()
			命名行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content.add_child(命名行)
			var 输入框: LineEdit = LineEdit.new()
			输入框.placeholder_text = "为混沌孑遗命名..."
			输入框.custom_minimum_size = Vector2(0, 36)
			输入框.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			命名行.add_child(输入框)
			var 命名按钮: Button = Button.new()
			命名按钮.text = "命名收录"
			命名按钮.custom_minimum_size = Vector2(100, 36)
			命名按钮.pressed.connect(func(): _on混沌命名(输入框.text))
			命名行.add_child(命名按钮)
		# 回溯符使用按钮（如果有回溯符且有可回溯的结果）
		if Game.灵钓系统.获取回溯符数量() > 0:
			var 回溯行: HBoxContainer = HBoxContainer.new()
			回溯行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content.add_child(回溯行)
			var 回溯信息: Label = Label.new()
			回溯信息.text = "时空回溯符：%d枚" % Game.灵钓系统.获取回溯符数量()
			回溯信息.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
			回溯信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			回溯行.add_child(回溯信息)
			var 回溯按钮: Button = Button.new()
			回溯按钮.text = "使用回溯符"
			回溯按钮.custom_minimum_size = Vector2(120, 36)
			回溯按钮.pressed.connect(_on使用回溯符)
			回溯行.add_child(回溯按钮)

func _选灵渊(id: int) -> void:
	_当前灵渊id = id

func _抛竿() -> void:
	_张力参数 = Game.灵钓系统.开始灵钓(_当前灵渊id)
	_垂钓中 = true
	_张力 = 0.0
	_渔获进度 = 0.0
	if _收线热区 != null:
		_收线热区.visible = true
	_update状态("已抛竿，静待鱼讯……")

func _on收线按下() -> void:
	_按住 = true

func _on收线抬起() -> void:
	_按住 = false

func _update状态(t: String) -> void:
	if _状态文本 != null:
		_状态文本.text = t

func _process(delta: float) -> void:
	if not _垂钓中 or _张力参数.is_empty():
		return
	var 上限: float = float(_张力参数.get("张力上限", 100.0))
	var 升速: float = float(_张力参数.get("升速", 9.0))
	var 降速: float = float(_张力参数.get("降速", 12.0))
	if _按住:
		_张力 += 升速 * delta
	else:
		_张力 -= 降速 * delta
	_张力 = clampf(_张力, 0.0, 上限)
	if _张力 >= 上限:
		_断线()
		return
	var 绿下: float = float(_张力参数.get("绿区下", 42.0))
	var 绿上: float = float(_张力参数.get("绿区上", 68.0))
	if _张力 >= 绿下 and _张力 <= 绿上:
		_渔获进度 += delta * 0.35   # 绿区每秒约 0.35 进度 [PLACEHOLDER·待实机调]
	else:
		_渔获进度 -= delta * 0.25
	_渔获进度 = clampf(_渔获进度, 0.0, 1.0)
	if _张力条 != null:
		_张力条.value = _张力
	if _渔获条 != null:
		_渔获条.value = _渔获进度
	if _渔获进度 >= 1.0:
		_起钩()

func _断线() -> void:
	_垂钓中 = false
	_按住 = false
	_张力 = 0.0
	_渔获进度 = 0.0
	if _收线热区 != null:
		_收线热区.visible = false
	_最近结果 = {"成功": false, "原因": "张力过载，鱼线崩断"}
	_update状态("张力过载，鱼线崩断，空手而归。")
	_刷新内容()

func _起钩() -> void:
	_垂钓中 = false
	_按住 = false
	if _收线热区 != null:
		_收线热区.visible = false
	var 表现: float = 1.0   # 进度满即视为理想收线
	_最近结果 = Game.灵钓系统.结算钓获(表现, _当前灵渊id)
	_update状态("起钩！")
	_刷新内容()

func _格式结果(r: Dictionary) -> String:
	if not r.get("成功", false):
		return "空篓：%s" % r.get("原因", "")
	# 神秘类生物特殊格式
	if r.get("品阶", "") == "神秘":
		var s: String = "★ 神秘遭遇！【%s】\n%s" % [r.get("名称", ""), r.get("提示", "")]
		if r.get("需要命名", false):
			s += "\n\n此乃混沌孑遗，形态无定，请为其命名收录。"
			s += "\n特征：%s" % r.get("混沌特征", "")
		if r.get("获得回溯符", false):
			s += "\n\n获得「时空回溯符」×1（当前持有：%d）" % int(r.get("回溯符数量", 0))
		if r.get("境界突破", false):
			s += "\n◆ 钓道境界突破！"
		return s
	# 仙阶现身格式
	if r.get("仙阶现身", false):
		return "★ 仙缘降临！【%s】现身！\n%s\n\n此等仙物非力可致，需以诚心结缘。" % [r.get("名称", ""), r.get("提示", "")]
	var s: String = "钓得【%s】（%s·%s属·%s阶）\n灵韵%d 重%.1f钧 长%.1f尺 难度%d\n用途：%s" % [
		r.get("名称", ""), r.get("分层", ""), r.get("五行", ""), r.get("品阶", ""),
		int(r.get("灵韵", 0)), float(r.get("重量", 0.0)), float(r.get("长度", 0.0)), int(r.get("钓获难度", 0)),
		r.get("用途", ""),
	]
	if r.get("新收录", false):
		s += "\n★ 图录新收录！"
	if r.get("境界突破", false):
		s += "\n◆ 钓道境界突破！"
	return s

# ===== 混沌孑遗命名回调 =====
func _on混沌命名(名字: String) -> void:
	var 结果: Dictionary = Game.灵钓系统.命名混沌孑遗(名字)
	if bool(结果.get("成功", false)):
		# 命名成功，刷新页面显示结果
		_最近结果 = {"成功": true, "名称": 结果.get("玩家命名", ""), "品阶": "神秘", "提示": "混沌孑遗「%s」已收录！特征：%s" % [结果.get("玩家命名", ""), 结果.get("特征描述", "")]}
		_刷新内容()
		UIHint.show_hint(self, "灵钓 · 命名", "混沌孑遗「%s」已收录！" % 结果.get("玩家命名", ""))
	else:
		UIHint.show_hint(self, "灵钓 · 命名", "命名失败：%s" % 结果.get("原因", ""))

# ===== 使用回溯符回调 =====
func _on使用回溯符() -> void:
	var 结果: Dictionary = Game.灵钓系统.使用回溯符()
	if bool(结果.get("成功", false)):
		# 回溯成功，清空最近结果，允许重新垂钓
		_最近结果 = {}
		_刷新内容()
		UIHint.show_hint(self, "灵钓 · 回溯", "时空回溯！上一次钓鱼结果已撤销，可重新垂钓")
	else:
		UIHint.show_hint(self, "灵钓 · 回溯", "回溯失败：%s" % 结果.get("原因", ""))

# ===== 图录 =====
# 灵鱼图鉴墙：2 列卡片（立绘缩略 + 名称），未收录压暗；点卡片展开详情（大图 + 描述）。
# 立绘走 Game.灵钓系统.获取灵鱼立绘(名)，无资产回落「暂无画像」占位（禁崩）。
func _建_图录() -> void:
	var 已收: Array = Game.收藏图录_已收集.get("灵钓", [])
	var 灵钓行: Array = []
	for r in Game.图录配置:
		if String(r.get("类别", "")) == "灵钓":
			灵钓行.append(r)
	var 标题: Label = Label.new()
	标题.text = "灵钓图录：已收录 %d / %d" % [已收.size(), 灵钓行.size()]
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	_content.add_child(标题)
	if _选中图录 != "":
		_content.add_child(_建_图录详情(_选中图录, 已收.has(_选中图录), 灵钓行))
	var 网格: GridContainer = GridContainer.new()
	网格.columns = 2
	网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	网格.add_theme_constant_override("h_separation", UITheme.GRID)
	网格.add_theme_constant_override("v_separation", UITheme.GRID)
	_content.add_child(网格)
	for r in 灵钓行:
		var 名: String = String(r.get("匹配名", r.get("名称", "")))
		if 名 == "":
			continue
		网格.add_child(_建_图录卡片(名, 已收.has(名)))

func _建_图录卡片(名: String, 已收录: bool) -> Control:
	var 卡: Button = Button.new()
	卡.custom_minimum_size = Vector2(0, 196)
	卡.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	卡.tooltip_text = 名
	卡.pressed.connect(Callable(self, "_选图录").bind(名))
	var 盒: VBoxContainer = VBoxContainer.new()
	盒.mouse_filter = Control.MOUSE_FILTER_IGNORE
	盒.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	盒.add_theme_constant_override("separation", UITheme.GRID_SM)
	卡.add_child(盒)
	var 图: TextureRect = TextureRect.new()
	图.texture = Game.灵钓系统.获取灵鱼立绘(名)
	图.custom_minimum_size = Vector2(0, 132)
	图.size_flags_vertical = Control.SIZE_EXPAND_FILL
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if 图.texture == null:
		var 占位: Label = Label.new()
		占位.text = "暂无画像"
		占位.custom_minimum_size = Vector2(0, 132)
		占位.size_flags_vertical = Control.SIZE_EXPAND_FILL
		占位.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		占位.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		占位.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
		占位.add_theme_color_override("font_color", UITheme.COLOR_TEXT_DISABLED)
		占位.mouse_filter = Control.MOUSE_FILTER_IGNORE
		盒.add_child(占位)
	else:
		if not 已收录:
			图.modulate = UITheme.COLOR_TEXT_DISABLED   # 未收录压暗（沿用禁用灰 token，不新造色）
		盒.add_child(图)
	var 名标: Label = Label.new()
	名标.text = 名 if 已收录 else "%s（未收录）" % 名
	名标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	名标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	名标.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
	名标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD if 已收录 else UITheme.COLOR_TEXT_DISABLED)
	名标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	盒.add_child(名标)
	return 卡

func _建_图录详情(名: String, 已收录: bool, 灵钓行: Array) -> Control:
	var 数据: Dictionary = {}
	for r in 灵钓行:
		if String(r.get("匹配名", r.get("名称", ""))) == 名:
			数据 = r
			break
	var 面板: PanelContainer = PanelContainer.new()
	UITheme.apply_panel_style(面板)
	var 盒: HBoxContainer = HBoxContainer.new()
	盒.add_theme_constant_override("separation", UITheme.GRID)
	面板.add_child(盒)
	var 大图: TextureRect = TextureRect.new()
	大图.texture = Game.灵钓系统.获取灵鱼立绘(名)
	大图.custom_minimum_size = Vector2(230, 230)
	大图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	大图.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if 大图.texture == null:
		var 占位: Label = Label.new()
		占位.text = "暂无画像"
		占位.custom_minimum_size = Vector2(230, 230)
		占位.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		占位.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		占位.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
		占位.add_theme_color_override("font_color", UITheme.COLOR_TEXT_DISABLED)
		盒.add_child(占位)
	else:
		if not 已收录:
			大图.modulate = UITheme.COLOR_TEXT_DISABLED
		盒.add_child(大图)
	var 信息: VBoxContainer = VBoxContainer.new()
	信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	信息.add_theme_constant_override("separation", UITheme.GRID_SM)
	盒.add_child(信息)
	var 名标: Label = Label.new()
	名标.text = "%s%s" % [名, "" if 已收录 else "（尚未收录）"]
	名标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	名标.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	名标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD if 已收录 else UITheme.COLOR_TEXT_DISABLED)
	信息.add_child(名标)
	var 描: Label = Label.new()
	描.text = String(数据.get("描述", ""))
	描.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	描.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
	描.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	信息.add_child(描)
	return 面板

func _选图录(名: String) -> void:
	_选中图录 = "" if _选中图录 == 名 else 名
	_刷新内容()

func _分隔(t: String) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	l.add_theme_font_size_override("font_size", 18)
	return l

func _晋升钓具() -> void:
	var r: Dictionary = Game.灵钓系统.晋升钓具()
	_刷新内容()
	if r.get("成功", false):
		_update状态("钓具晋阶成功：%s·%s·%s" % [r.get("灵杆", ""), r.get("灵线", ""), r.get("灵饵", "")])
	else:
		_update状态("晋阶失败：%s" % r.get("原因", ""))

func _选灵饵(名: String) -> void:
	var r: Dictionary = Game.灵钓系统.配制灵饵(名)
	if r.get("成功", false):
		_update状态("已配制灵饵：【%s】，抛竿时将耗灵材引聚灵物。" % 名)
	else:
		_update状态("配制失败：%s" % r.get("原因", ""))

func _参与大赛() -> void:
	var r: Dictionary = Game.灵钓系统.参与大赛()
	_刷新内容()
	if r.get("成功", false):
		_update状态("参赛成功！获宗主威望 %d。" % int(r.get("威望", 0)))
	else:
		_update状态("参赛失败：%s" % r.get("原因", ""))

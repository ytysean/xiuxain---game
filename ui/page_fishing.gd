extends Control
# 灵钓 UI（休闲玩法 S46-P0 核心钓鱼闭环）
# 后端：Game.灵钓系统（钓鱼产出/钓道境界/钓具）；图录复用 Game.收藏图录_已收集
# 交互：竖屏 1080x1920，下半屏单指 hold 收线 / release 放线，禁 QTE 精准点按
# 颜色一律走 UITheme 真实 const，禁硬编码（audit_uitheme_calls 0 臆造）


signal 返回主页

const TABS: Array = ["总览", "垂钓", "图录"]
const 渔获增速_绿区: float = 0.35
const 渔获衰减_非绿区: float = 0.25

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
	# ★ 2026-09-17 F1（05 灵钓）：背景晕影画框——顶 0–11% / 底 88–100% 压暗，中部 11–88% 全透明（非蒙版）。
	#   仅引用 UITheme.建背景晕影渐变()（原样，禁改停点 / 禁改 获取场景压暗色() 本体）；零新色值。
	#   置于 main 之前 ⇒ 层级在内容之下；mouse_filter=IGNORE 不拦触控。
	var 背景: TextureRect = TextureRect.new()
	背景.name = "BGVeil"
	背景.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var 背景渐变 := GradientTexture2D.new()
	背景渐变.gradient = UITheme.建背景晕影渐变()
	背景渐变.fill_from = Vector2(0.5, 0.0)
	背景渐变.fill_to = Vector2(0.5, 1.0)
	背景.texture = 背景渐变
	背景.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	背景.stretch_mode = TextureRect.STRETCH_SCALE
	背景.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(背景)
	# 修复（实机验收抓出 · 2026-09-12）：本页根节点是 Control（非容器），子节点 anchors 全 0，
	# ScrollContainer 最小尺寸为 0 → 塌成 0×0 且 clip_contents=true 把正文整块裁掉。
	# 与 page_chat 同构：先挂一个全屏 VBoxContainer 作为唯一布局宿主。
	var main: VBoxContainer = VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 8)
	main.add_theme_constant_override("margin_left", UITheme.MARGIN)
	main.add_theme_constant_override("margin_right", UITheme.MARGIN)
	add_child(main)
	# ★ 2026-09-17 F2（05 灵钓）：顶栏接统一房模板（18 页同款，含坊市 page_shop.gd:104）。
	#   返回钮走 make_back_button ⇒ 得返回环；标题走 apply_page_title(FONT_TITLE=45)。
	#   M1 随本条自然消解：原「␣␣灵渊垂钓」前导空格 hack 一并移除。
	main.add_child(UITheme.建顶栏("灵渊垂钓", _on返回))
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
	_关收杆结算()   # 切页时收起结算弹窗，避免残留遮挡
	_cur = 标签名
	_垂钓中 = false
	_按住 = false
	_刷新标签按钮()
	_刷新内容()

func _刷新标签按钮() -> void:
	UITheme.刷新标签高亮(_tab_btns, _cur)

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
	UITheme.apply_project_font(标题, UITheme.FONT_H2, true)
	_content.add_child(标题)
	var 进度文: Label = Label.new()
	if 进度.get("满", false):
		进度文.text = "已臻钓道极致。累计钓获 %d 次。" % 钓.累计钓获次数
	else:
		进度文.text = "修为 %d / %d（再积 %d 修为可晋%s）\n累计钓获 %d 次" % [进度.get("已得", 0), 进度.get("需", 0), 进度.get("需", 0) - 进度.get("已得", 0), 钓.钓道境界表[钓.钓道境界 + 1].get("名", ""), 钓.累计钓获次数]
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
	UITheme.apply_secondary_button_style(晋)
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
	UITheme.apply_secondary_button_style(参赛)
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
		UITheme.apply_secondary_button_style(b)
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
		UITheme.apply_secondary_button_style(eb)
		eb.custom_minimum_size = Vector2(0, 36)
		eb.pressed.connect(Callable(self, "_选灵饵").bind(饵.get("名称", "凡饵")))
		_content.add_child(eb)
	# ★ 2026-09-17 F4（05 灵钓）：空标题当间隔条 → 改显式 Control 间隔（GRID_SM）。
	var 间隔: Control = Control.new()
	间隔.custom_minimum_size = Vector2(0, UITheme.GRID_SM)
	_content.add_child(间隔)
	var 抛竿: Button = Button.new()
	抛竿.text = "抛竿入水"
	UITheme.apply_secondary_button_style(抛竿)
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
	var 可钓: Array = Game.灵钓系统.可钓灵渊()
	var 可选id: Array = []
	for 渊 in 可钓:
		可选id.append(int(渊.get("id")))
	if _当前灵渊id <= 0 or not 可选id.has(_当前灵渊id):
		UIHint.show_hint(self, "灵钓 · 抛竿", "请先择定一处灵渊，再抛竿入水。")
		return
	_张力参数 = Game.灵钓系统.开始灵钓(_当前灵渊id)
	_垂钓中 = true
	_张力 = 0.0
	_渔获进度 = 0.0
	if _收线热区 != null:
		_收线热区.visible = true
		_收线热区.self_modulate = Color.WHITE
	_update状态("已抛竿，静待鱼讯……")

func _on收线按下() -> void:
	_按住 = true
	if _收线热区 != null:
		_收线热区.self_modulate = UITheme.COLOR_TEXT_GOLD

func _on收线抬起() -> void:
	_按住 = false
	if _收线热区 != null:
		_收线热区.self_modulate = Color.WHITE

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
		_渔获进度 += delta * 渔获增速_绿区
	else:
		_渔获进度 -= delta * 渔获衰减_非绿区
	_渔获进度 = clampf(_渔获进度, 0.0, 1.0)
	_刷新张力反馈(绿下, 绿上)
	if _张力条 != null:
		_张力条.value = _张力
	if _渔获条 != null:
		_渔获条.value = _渔获进度
	if _渔获进度 >= 1.0:
		_起钩()

func _刷新张力反馈(绿下: float, 绿上: float) -> void:
	if _状态文本 == null:
		return
	if _张力 >= 绿下 and _张力 <= 绿上:
		_状态文本.text = "✓ 张力适中（绿区），保持收线待鱼力竭"
		_状态文本.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS)
	elif _张力 > 绿上:
		_状态文本.text = "↑ 张力过高，松开放线降温"
		_状态文本.add_theme_color_override("font_color", UITheme.COLOR_TEXT_RED)
	else:
		_状态文本.text = "↓ 张力不足，按住收线蓄力"
		_状态文本.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)

func _断线() -> void:
	_垂钓中 = false
	_按住 = false
	_张力 = 0.0
	_渔获进度 = 0.0
	if _收线热区 != null:
		_收线热区.visible = false
		_收线热区.self_modulate = Color.WHITE
	UIHint.show_hint(self, "灵钓 · 断线", "张力过载，鱼线崩断，空手而归。")
	_最近结果 = {"成功": false, "原因": "张力过载，鱼线崩断"}
	_update状态("张力过载，鱼线崩断，空手而归。")
	if _状态文本 != null:
		_状态文本.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
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
	_弹收杆结算()   # 收杆结算弹窗（页内结果保留，关弹窗后仍可查）

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

# ===== 收杆结算弹窗 =====
# 参考模拟垂钓品类惯例（Stardew 的「鱼名 + 尺寸 + 首次收录 / 新纪录」三件套，
# COTW / Fishing Planet 的稀有度色框 + 光效 + 入场动画），按本项目修真口径落地：
#   - 品阶色取 UIThemeConfig.QUALITY_COLOR（唯一色源，禁在本页造色值）；
#   - 重量「钧」/ 长度「尺」沿用后端字段，文案修真化；
#   - 晕影基色走 UITheme.获取场景压暗色()（铁律：禁用 获取面板底色()）。
# 立绘走抠底通道（fish_cut/），资产未到位时后端自动回退原图 —— 不白屏。
const 品阶_STEM: Dictionary = {
	"凡阶": "fan", "灵阶": "ling", "宝阶": "bao",
	"王阶": "wang", "圣阶": "sheng", "仙阶": "xian", "道阶": "dao",
}

var _结算层: Control = null

func _品阶色(品阶名: String) -> Color:
	var stem: String = String(品阶_STEM.get(品阶名, ""))
	if stem == "":
		return UITheme.COLOR_TEXT_GOLD   # 神秘 / 未知品阶 → 金
	return UIThemeConfig.get_quality_color(stem)

func _关收杆结算() -> void:
	if _结算层 != null and is_instance_valid(_结算层):
		_结算层.queue_free()
	_结算层 = null

func _弹收杆结算() -> void:
	var r: Dictionary = _最近结果
	if not bool(r.get("成功", false)):
		return
	var 名称: String = String(r.get("名称", ""))
	if 名称 == "":
		return
	_关收杆结算()
	var 色: Color = _品阶色(String(r.get("品阶", "")))

	# —— 全屏层：遮罩 + 居中内容；mouse_filter=STOP 拦截穿透 ——
	var 层: Control = Control.new()
	层.name = "FishingResult"
	层.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	层.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(层)
	_结算层 = 层

	var 墨: Color = UITheme.获取场景压暗色()
	墨.a = 0.88
	var 遮罩: ColorRect = ColorRect.new()
	遮罩.color = 墨
	遮罩.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮罩.mouse_filter = Control.MOUSE_FILTER_IGNORE
	层.add_child(遮罩)

	# 居中宿主：CenterContainer 保证子节点保持自身最小尺寸并居中。
	# 坑：直接给 VBox 用 PRESET_CENTER，size=0 时 offsets 全 0，撑开后会向右下延伸，
	#     立绘区被压扁、内容整体偏位（实机探针抓出）。
	var 居中: CenterContainer = CenterContainer.new()
	居中.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	居中.mouse_filter = Control.MOUSE_FILTER_IGNORE
	层.add_child(居中)

	var 外框: VBoxContainer = VBoxContainer.new()
	外框.custom_minimum_size = Vector2(UITheme.RESULT_PANEL_W, 0)
	外框.alignment = BoxContainer.ALIGNMENT_CENTER
	外框.add_theme_constant_override("separation", UITheme.GRID)
	居中.add_child(外框)
	# 结算内容居中卡片 ⇒ 缩放弹入。scale 不与 CenterContainer 的居中重排冲突（它只管 position/size）。
	UITheme.弹窗入场(外框, 遮罩, 0.26, true)

	# —— 品阶横幅 ——
	var 横幅: Label = Label.new()
	if String(r.get("品阶", "")) == "神秘":
		横幅.text = "◆ 神 秘 遭 遇 ◆"
	elif bool(r.get("仙阶现身", false)):
		横幅.text = "◆ 仙 缘 降 临 ◆"
	else:
		横幅.text = "— %s · %s · %s —" % [r.get("品阶", ""), r.get("五行", ""), r.get("分层", "")]
	UITheme.apply_project_font(横幅, UITheme.FONT_H2, true)
	横幅.add_theme_color_override("font_color", 色)
	横幅.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	外框.add_child(横幅)

	# —— 立绘（抠底通道）——
	var 立绘: TextureRect = TextureRect.new()
	立绘.texture = Game.灵钓系统.获取灵鱼立绘(名称, int(r.get("混沌变体ID", -1)), true)
	立绘.custom_minimum_size = Vector2(0, UITheme.RESULT_ART_H)
	立绘.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	立绘.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	立绘.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if 立绘.texture == null:
		var 占位: Label = Label.new()
		占位.text = "暂无画像"
		占位.custom_minimum_size = Vector2(0, UITheme.RESULT_ART_H)
		占位.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		占位.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.apply_project_font(占位, UITheme.FONT_AUX, false)
		占位.add_theme_color_override("font_color", UITheme.COLOR_TEXT_DISABLED)
		外框.add_child(占位)
	else:
		外框.add_child(立绘)

	# —— 名号（品阶色）——
	var 名标: Label = Label.new()
	名标.text = 名称
	UITheme.apply_project_font(名标, UITheme.FONT_H1, true)
	名标.add_theme_color_override("font_color", 色)
	名标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	名标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	外框.add_child(名标)

	# —— 徽记行（首见 / 新纪录 / 破境 / 回溯符）——
	var 徽记: Array = []
	if bool(r.get("新收录", false)):
		徽记.append("★ 图录首见")
	if bool(r.get("新纪录", false)):
		徽记.append("★ 新纪录")
	if bool(r.get("境界突破", false)):
		徽记.append("◆ 钓道突破")
	if bool(r.get("获得回溯符", false)):
		徽记.append("◆ 得回溯符")
	if not 徽记.is_empty():
		var 徽记标: Label = Label.new()
		徽记标.text = "　".join(徽记)
		UITheme.apply_project_font(徽记标, UITheme.FONT_BODY, true)
		徽记标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		徽记标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		徽记标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		外框.add_child(徽记标)

	# —— 数据行 ——
	var 数据: Label = Label.new()
	if String(r.get("品阶", "")) == "神秘" or bool(r.get("仙阶现身", false)):
		数据.text = String(r.get("提示", ""))
	else:
		数据.text = "灵韵 %d · 重 %.1f 钧 · 长 %.1f 尺 · 难度 %d" % [
			int(r.get("灵韵", 0)), float(r.get("重量", 0.0)),
			float(r.get("长度", 0.0)), int(r.get("钓获难度", 0)),
		]
	UITheme.apply_project_font(数据, UITheme.FONT_BODY, false)
	数据.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	数据.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	数据.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	外框.add_child(数据)

	var 用途: String = String(r.get("用途", ""))
	if 用途 != "":
		var 用途标: Label = Label.new()
		用途标.text = "用途：%s" % 用途
		UITheme.apply_project_font(用途标, UITheme.FONT_AUX, false)
		用途标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
		用途标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		用途标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		外框.add_child(用途标)

	var 来处标: Label = Label.new()
	来处标.text = "钓自 %s · 钓道修为 +%d" % [r.get("灵渊名", "灵渊"), int(r.get("获得经验", 0))]
	UITheme.apply_project_font(来处标, UITheme.FONT_AUX, false)
	来处标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	来处标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	外框.add_child(来处标)

	# —— 混沌孑遗赐名 ——
	var 命名框: LineEdit = null
	if bool(r.get("需要命名", false)):
		var 特征: String = String(r.get("混沌特征", ""))
		if 特征 != "":
			var 特征标: Label = Label.new()
			特征标.text = "特征：%s" % 特征
			UITheme.apply_project_font(特征标, UITheme.FONT_AUX, false)
			特征标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
			特征标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			特征标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			外框.add_child(特征标)
		命名框 = LineEdit.new()
		命名框.placeholder_text = "为此孑遗赐名…"
		命名框.custom_minimum_size = Vector2(0, UITheme.RESULT_INPUT_H)
		命名框.alignment = HORIZONTAL_ALIGNMENT_CENTER
		外框.add_child(命名框)

	# —— 按钮行 ——
	var 按钮行: HBoxContainer = HBoxContainer.new()
	按钮行.alignment = BoxContainer.ALIGNMENT_CENTER
	按钮行.add_theme_constant_override("separation", UITheme.GRID)
	外框.add_child(按钮行)

	if 命名框 != null:
		var 命名钮: Button = Button.new()
		命名钮.text = "赐名收录"
		UITheme.apply_secondary_button_style(命名钮)
		命名钮.custom_minimum_size = Vector2(UITheme.RESULT_BTN_W, UITheme.RESULT_BTN_H)
		命名钮.pressed.connect(func():
			_on混沌命名(命名框.text)
			_关收杆结算()
		)
		按钮行.add_child(命名钮)

	var 继续钮: Button = Button.new()
	继续钮.text = "继续垂钓"
	UITheme.apply_secondary_button_style(继续钮)
	继续钮.custom_minimum_size = Vector2(UITheme.RESULT_BTN_W, UITheme.RESULT_BTN_H)
	继续钮.pressed.connect(_关收杆结算)
	按钮行.add_child(继续钮)

	if Game.灵钓系统.获取回溯符数量() > 0:
		var 回溯钮: Button = Button.new()
		回溯钮.text = "使用回溯符"
		UITheme.apply_secondary_button_style(回溯钮)
		回溯钮.custom_minimum_size = Vector2(UITheme.RESULT_BTN_W, UITheme.RESULT_BTN_H)
		回溯钮.pressed.connect(func():
			_on使用回溯符()
			_关收杆结算()
		)
		按钮行.add_child(回溯钮)

	# —— 入场动画：整层淡入 + 外框缩放弹入 ——
	await get_tree().process_frame
	if not is_instance_valid(层):
		return
	外框.pivot_offset = 外框.size * 0.5
	外框.scale = Vector2(0.86, 0.86)
	层.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(层, "modulate:a", 1.0, 0.22)
	tw.tween_property(外框, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	UITheme.apply_project_font(标题, UITheme.FONT_H2, true)
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
		UITheme.apply_project_font(占位, UITheme.FONT_AUX, false)
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
	UITheme.apply_project_font(名标, UITheme.FONT_AUX, false)
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
		UITheme.apply_project_font(占位, UITheme.FONT_AUX, false)
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
	UITheme.apply_project_font(名标, UITheme.FONT_BODY, false)
	名标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD if 已收录 else UITheme.COLOR_TEXT_DISABLED)
	信息.add_child(名标)
	var 描: Label = Label.new()
	描.text = String(数据.get("描述", ""))
	描.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_project_font(描, UITheme.FONT_AUX, false)
	描.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	信息.add_child(描)
	return 面板

func _选图录(名: String) -> void:
	_选中图录 = "" if _选中图录 == 名 else 名
	_刷新内容()

func _分隔(t: String) -> Label:
	# ★ 2026-09-17 F3+F4（05 灵钓）：收口到统一分节组件 apply_section_title（FONT_H2=33）。
	#   保留本页既有暗金分节色（显式 token 覆盖，承 03 判例「显式裁定>口头默认」），零未授权色变。
	var l: Label = Label.new()
	l.text = t
	UITheme.apply_section_title(l)
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
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

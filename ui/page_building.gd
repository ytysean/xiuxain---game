extends Control

# 殿阁页（§4 · 核心经营）：只读展示 殿阁总览（司职数 + Σ等级）+ 司职列表（12 行）+ 底部 殿阁被动_负面事件减免。
# 零 GameState 写入；升级/任免/开关按钮仅 emit 占位信号（实际写操作由宿主后续接线）。读数经 is_instance_valid(Game) + .get() 守卫。
# P1：新增殿阁详情二级子视图（ListRoot / DetailRoot 显隐模式，复用 page_disciple 的 DetailRoot 范式）。
# S1 ENG-S1-HALLYUSHOU：新增 hall_yushou（御兽堂）分区（完整UX设计规范 §2.2 / §7 命名表 / Q1 裁定
#   「灵兽入口 → 殿阁 hall_yushou 分区」）。灵兽展示逻辑只读移植自 main.gd 刷新御兽()（R8 复用端口，未删），
#   但完全用本页自己的 PanelContainer + UITheme 范式重写，不调用 main.gd 任何私有 helper / mutation handler。

signal 殿阁详情请求(key: String)
signal 殿阁升级请求(key: String)
signal 殿阁任免请求(key: String)
signal 殿阁开关请求(key: String, 开启: bool)
signal 殿阁详情返回()

# hall_yushou 操作信号。S1 ENG-S1-YUSHOU-WIRE 起不再是「只 emit 的占位」：
# 本页在 _connect_signals() 内把这 5 条信号自连到 _on_灵兽_* handler，由 handler 调用 GameState
# 真实 mutation（解绑灵兽 / 绑定灵兽给首只合格 / 灵兽兑换_启停·删除·新增）并重绘（见文件末「信号接线」区）。
# 信号本身仍保持公开：宿主日后可再 connect 一份做 toast / 埋点，与本页自连互不干扰。
signal 灵兽_卸下_request(弟子, 槽: String)
signal 灵兽_绑定_request(灵兽)
signal 灵兽_兑换_启停_request(序号: int)
signal 灵兽_兑换_删除_request(序号: int)
signal 灵兽_兑换_新增_request()

# 殿阁等级上限派生常量：设计规格 §2.4 指定「上限取常量 10」；真实上限来自 Game._殿阁等级上限() (min(门派等级,7))。
const 殿阁等级上限_兜底: int = 10

# hall_yushou 字号：锁定合法字号集 {22,18,17,16,15,13}（完整UX设计规范 §3.3 / 附录 Q6）。
# 注：不走 apply_title_font(30) / apply_aux_font(14)（两者超出合法集），改用可控字号版 helper。
const YUSHOU_FONT_TITLE: int = 18
const YUSHOU_FONT_SUB: int = 15
const YUSHOU_FONT_BODY: int = 15
const YUSHOU_FONT_AUX: int = 13

# 引育计划预设表（标签 / 偏好 / 单次拨付经费）。
# 与 main.gd _弹出兑换新增() 的预设表【同源同价】，保证新旧两个入口（旧御兽页 / 殿阁御兽堂）
# 拨付经费口径一致；此处为只读常量副本，不跨文件引用 main.gd 私有方法（R8 模块边界）。
# 标签刻意做短，供 2 列 GridContainer 在 480 宽竖屏内不折行。
const YUSHOU_引育预设: Array = [
	{"标签": "泛性 600", "偏好": {}, "cost": 600},
	{"标签": "凡阶 200", "偏好": {"品阶": "fan_jie"}, "cost": 200},
	{"标签": "灵阶 600", "偏好": {"品阶": "ling_jie"}, "cost": 600},
	{"标签": "宝阶 1500", "偏好": {"品阶": "bao_jie"}, "cost": 1500},
	{"标签": "王阶 4000", "偏好": {"品阶": "wang_jie"}, "cost": 4000},
	{"标签": "圣阶 10000", "偏好": {"品阶": "sheng_jie"}, "cost": 10000},
	{"标签": "仙阶 25000", "偏好": {"品阶": "xian_jie"}, "cost": 25000},
	{"标签": "道阶 60000", "偏好": {"品阶": "dao_jie"}, "cost": 60000},
	{"标签": "攻伐型 600", "偏好": {"类型": "attack"}, "cost": 600},
	{"标签": "防御型 600", "偏好": {"类型": "defense"}, "cost": 600},
	{"标签": "辅助型 600", "偏好": {"类型": "support"}, "cost": 600},
]

var _built: bool = false
var _list_root: Control
var _detail_root: Control
var _detail_vbox: VBoxContainer
var _overview_司职数: Label
var _overview_总等级: Label
var _list_vbox: VBoxContainer
var _passive_label: Label
var _scroll_vbox: VBoxContainer
var _yushou_root: VBoxContainer
var _yushou_vbox: VBoxContainer

# hall_yushou 交互态（S1 ENG-S1-YUSHOU-WIRE）
var _signals_connected: bool = false          # _connect_signals() 幂等守卫，保证 5 条信号只连一次
var _yushou_状态: String = ""                  # 最近一次灵兽操作的结果文案（轻量 toast 占位，渲染于御兽堂顶部）
var _yushou_状态_成功: bool = true             # 决定状态行取 success 还是 danger 色 token
var _yushou_新增展开: bool = false             # 「＋ 新增引育计划」预设选择器的展开态

func _ready() -> void:
	_connect_signals()
	_build()
	refresh()

# 切 Tab 重挂载时自动重拉只读数据。
# game_ui._show_page() 是「从 PageContainer 摘除旧页 / 挂入新页」，并不会调 page.refresh()
# （refresh 只在首屏 _apply_safe_defaults 与 推演/读档 的 refresh_all 时统一触发）。
# 故本页自行在重新入树时补一次刷新，保证切到「殿阁」Tab 看到的御兽堂是最新数据。
# 仅改本文件、不动 game_ui 路由；_built 守卫使首次入树（此时尚未 _build）交给 _ready 首刷，不重复。
# 用 call_deferred：refresh() 会 remove_child/queue_free 重建子节点，而 _enter_tree 正处于引擎
# 「入树传播」窗口内，直接改子节点树有重入风险；延后到本帧空闲执行，行为等价且安全。
func _enter_tree() -> void:
	if _built:
		# 重新进入殿阁 Tab 视为「一次新的访问」，清掉上次灵兽操作留下的结果文案（见 _yushou_状态 注释）。
		_yushou_状态 = ""
		refresh.call_deferred()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.name = "ListRoot"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	_list_root = vbox

	_build_overview(vbox)
	_build_list_scroll(vbox)
	_build_passive_bar(vbox)

	_detail_root = VBoxContainer.new()
	_detail_root.name = "DetailRoot"
	_detail_root.visible = false
	_detail_root.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_detail_root.add_theme_constant_override("margin_right", UITheme.MARGIN)
	_detail_root.add_theme_constant_override("margin_top", UITheme.GRID)
	_detail_root.add_theme_constant_override("margin_bottom", UITheme.GRID)
	_detail_root.add_theme_constant_override("separation", UITheme.GRID * 2)
	_detail_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_detail_root)
	_build_detail_root()

func _build_overview(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "Overview"
	panel.custom_minimum_size = Vector2(0, UITheme.GRID * 7)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(hb)

	var 图标 = UITheme.load_icon_sized("殿阁", UITheme.SIZE_SM)
	if 图标 != null:
		var tr := TextureRect.new()
		tr.texture = 图标
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.custom_minimum_size = Vector2(24, 24)
		hb.add_child(tr)

	var title := Label.new()
	title.text = "殿阁总览"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_title_font(title)
	hb.add_child(title)

	var 司职_cell := VBoxContainer.new()
	司职_cell.alignment = BoxContainer.ALIGNMENT_CENTER
	var 司职_cap := Label.new()
	司职_cap.text = "司职"
	UITheme.apply_aux_font(司职_cap)
	司职_cell.add_child(司职_cap)
	_overview_司职数 = Label.new()
	_overview_司职数.text = "—"
	UITheme.apply_value_font(_overview_司职数, false)
	司职_cell.add_child(_overview_司职数)
	hb.add_child(司职_cell)

	var 等级_cell := VBoxContainer.new()
	等级_cell.alignment = BoxContainer.ALIGNMENT_CENTER
	var 等级_cap := Label.new()
	等级_cap.text = "总等级"
	UITheme.apply_aux_font(等级_cap)
	等级_cell.add_child(等级_cap)
	_overview_总等级 = Label.new()
	_overview_总等级.text = "—"
	UITheme.apply_value_font(_overview_总等级, false)
	等级_cell.add_child(_overview_总等级)
	hb.add_child(等级_cell)

	parent.add_child(panel)

func _build_list_scroll(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	# ScrollVBox：单一滚动容器内纵向串联「司职列表 + hall_yushou 御兽堂」。
	# 不用二级 sub-scroll —— 480×854 竖屏内嵌套滚动会抢手势且易出现内层被压扁/溢出；
	# 同一个 ScrollVBox 让御兽堂随司职列表整体滚动，切到殿阁 Tab 后向下滑即达。
	_scroll_vbox = VBoxContainer.new()
	_scroll_vbox.name = "ScrollVBox"
	_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 刻意不加 SIZE_EXPAND_FILL 垂直：保持与改造前 ListVBox 直挂 ScrollContainer 完全一致的
	# 「取自然最小高度、顶对齐、超出即滚动」语义，避免内容短时被拉伸、内容长时高度计算歧义。
	_scroll_vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	scroll.add_child(_scroll_vbox)

	_list_vbox = VBoxContainer.new()
	_list_vbox.name = "ListVBox"
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", UITheme.GRID)
	_scroll_vbox.add_child(_list_vbox)

	# hall_yushou 御兽堂：挂在 ListVBox 之后、同一滚动流内。
	# 注意：_populate_list() 只清空 _list_vbox 的子节点，故本分区节点不会被司职列表刷新误删。
	_build_yushou(_scroll_vbox)

func _build_passive_bar(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "PassiveBar"
	panel.custom_minimum_size = Vector2(0, UITheme.GRID * 6)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(hb)
	var cap := Label.new()
	cap.text = "殿阁被动"
	UITheme.apply_aux_font(cap)
	hb.add_child(cap)
	_passive_label = Label.new()
	_passive_label.text = "负面事件减免 0%"
	UITheme.apply_aux_font(_passive_label)
	hb.add_child(_passive_label)
	parent.add_child(panel)

func refresh() -> void:
	if not _built:
		_build()
	# 刻意【不】在此清 _yushou_状态：Game.解绑灵兽/绑定灵兽* 会 emit 弟子变动，而 main.gd 把它
	# CONNECT_DEFERRED 到 _on_弟子变动刷新新UI() → 新UI.refresh_all() → 本页 refresh()。
	# 若在此清空，卸下/绑定的结果文案会在同一 idle 帧被这条链路抹掉，而不 emit 弟子变动的
	# 引育增删启停却能留住提示 —— 五个操作的反馈行为将不一致。清理点统一收到 _enter_tree()。
	_populate()

func _populate() -> void:
	var 司职数 := 0
	var 总等级 := 0
	if is_instance_valid(Game):
		var 列表 = Game.get("司职列表")
		if 列表 is Dictionary:
			司职数 = 列表.size()
			for k in 列表.keys():
				var e = 列表[k]
				if e is Dictionary:
					总等级 += int(e.get("等级", 1))
	_overview_司职数.text = str(司职数)
	_overview_总等级.text = str(总等级)

	var 减免 = 0.0
	if is_instance_valid(Game):
		减免 = Game.get("殿阁被动_负面事件减免")
		if typeof(减免) != TYPE_FLOAT and typeof(减免) != TYPE_INT:
			减免 = 0.0
	_passive_label.text = "负面事件减免 %d%%" % int(abs(减免))

	_populate_list()
	_refresh_yushou()

func _populate_list() -> void:
	if _list_vbox == null:
		return
	for child in _list_vbox.get_children():
		_list_vbox.remove_child(child)
		child.queue_free()
	if not is_instance_valid(Game):
		return
	var 列表 = Game.get("司职列表")
	if 列表 == null or not (列表 is Dictionary):
		return
	for key in 列表.keys():
		var e = 列表[key]
		if e is Dictionary:
			_add_hall_row(key, e)

func _add_hall_row(key: String, entry: Dictionary) -> void:
	var row := PanelContainer.new()
	row.name = "Hall_%s" % key
	# 卡片高度提到 GRID*16，足以容纳 名称/职能/等级 + 产出/主事/成员 + 被动/修葺 三行；
	# 内容更高时 PanelContainer 会自动撑高，custom_minimum_size 仅作下限防贴边。
	row.custom_minimum_size = Vector2(0, UITheme.GRID * 16)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	row.add_child(vbox)

	var l1 := HBoxContainer.new()
	l1.add_theme_constant_override("separation", UITheme.GRID)
	var 名称 := Label.new()
	名称.text = str(entry.get("名称", "—"))
	名称.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_body_font(名称)
	l1.add_child(名称)
	var 职能 := Label.new()
	职能.text = "职能:" + str(entry.get("职能", "—"))
	职能.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	职能.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	职能.custom_minimum_size = Vector2(UITheme.GRID * 8, 0)
	UITheme.apply_aux_font(职能)
	l1.add_child(职能)
	var 等级 := Label.new()
	等级.text = "Lv" + str(int(entry.get("等级", 1)))
	UITheme.apply_value_font(等级, false)
	l1.add_child(等级)
	vbox.add_child(l1)

	var l2 := HBoxContainer.new()
	l2.add_theme_constant_override("separation", UITheme.GRID)
	var 产出 := Label.new()
	产出.text = "产出:" + str(entry.get("产出", "—"))
	产出.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	产出.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	产出.custom_minimum_size = Vector2(UITheme.GRID * 10, 0)
	UITheme.apply_aux_font(产出)
	l2.add_child(产出)
	var 主事obj = entry.get("负责人", null)
	var 主事文本 := "主事:缺"
	if 主事obj != null and 主事obj is Object:
		var 主事名 = 主事obj.get("姓名")
		if 主事名 != null:
			主事文本 = "主事:" + str(主事名)
	var 主事 := Label.new()
	主事.text = 主事文本
	UITheme.apply_aux_font(主事)
	l2.add_child(主事)
	var 成员 = entry.get("成员", [])
	var 成员数 := 0
	if 成员 is Array:
		成员数 = 成员.size()
	var 成员标签 := Label.new()
	成员标签.text = "成员:%d" % 成员数
	UITheme.apply_aux_font(成员标签)
	l2.add_child(成员标签)
	vbox.add_child(l2)

	var l3 := HBoxContainer.new()
	l3.add_theme_constant_override("separation", UITheme.GRID)
	var 被动 := Label.new()
	被动.text = "被动:" + str(entry.get("加成维度", "—"))
	被动.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	被动.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	被动.custom_minimum_size = Vector2(UITheme.GRID * 12, 0)
	UITheme.apply_aux_font(被动)
	l3.add_child(被动)
	var 升级 := Button.new()
	升级.name = "Upgrade_%s" % key
	升级.text = "修葺"
	升级.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	升级.pressed.connect(_on_升级_pressed.bind(key, 升级))
	l3.add_child(升级)
	vbox.add_child(l3)

	_list_vbox.add_child(row)
	_list_vbox.add_child(UITheme.make_divider_control())
	_pass_through(row)
	row.gui_input.connect(_on_hall_gui_input.bind(key))

func _on_hall_gui_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			殿阁详情请求.emit(key)
			_show_detail(key)

func _on_升级_pressed(key: String, btn: Button = null) -> void:
	if btn != null:
		UITween.button_press(btn)
	殿阁升级请求.emit(key)

# ═════════ hall_yushou · 御兽堂分区（S1 ENG-S1-HALLYUSHOU）═════════
# 来源裁定：完整UX设计规范 §2.2 分区表 / §7 命名铁则 / §9 Q1「灵兽入口 → 殿阁 hall_yushou 分区（S1）」。
# 展示逻辑只读移植自 main.gd 刷新御兽()（L2428+，R8 复用端口保留未删），但：
#   · 不调用 main.gd 私有 helper 小标题()/新面板()（跨文件私有，禁用），改用本页 PanelContainer + UITheme 范式；
#   · 不调用 main.gd mutation handler _on_卸下/_on_绑定/_on_兑换*，一律 emit 本页占位信号；
#   · 全程零 GameState 写入，读数经 is_instance_valid(Game) + .get() 守卫（与本页既有 refresh 纪律一致）。
func _build_yushou(parent: Control) -> void:
	_yushou_root = VBoxContainer.new()
	_yushou_root.name = "Hall_Yushou"
	_yushou_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_yushou_root.add_theme_constant_override("separation", UITheme.GRID)
	parent.add_child(_yushou_root)

	# 与上方司职列表之间的分区分隔（云纹分隔线，UITheme 统一资产）
	_yushou_root.add_child(UITheme.make_divider_control())

	var title := Label.new()
	title.name = "YushouTitle"
	title.text = "御兽堂"
	UITheme.apply_title_font_sized(title, YUSHOU_FONT_TITLE)
	title.add_theme_color_override("font_color", UITheme.color_text_title1())
	_yushou_root.add_child(title)

	_yushou_vbox = VBoxContainer.new()
	_yushou_vbox.name = "YushouVBox"
	_yushou_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_yushou_vbox.add_theme_constant_override("separation", UITheme.GRID)
	_yushou_root.add_child(_yushou_vbox)

# 御兽堂只读刷新入口：由 _populate() 调用（refresh() → _populate() → _refresh_yushou()）。
func _refresh_yushou() -> void:
	if _yushou_vbox == null:
		return
	for child in _yushou_vbox.get_children():
		_yushou_vbox.remove_child(child)
		child.queue_free()
	_yushou_状态行()
	if not is_instance_valid(Game):
		_yushou_空行("（御兽堂暂无灵兽）")
		return

	var 弟子列表: Array = _as_array(Game.get("弟子列表"))
	var 蛋列表: Array = _as_array(Game.get("灵兽蛋列表"))
	var 库存: Array = _as_array(Game.get("灵兽库存"))
	var 队列: Array = _as_array(Game.get("灵兽兑换队列"))

	# 是否已有任意已契约灵兽（双槽）——判定与 main.gd 刷新御兽() 一致
	var 有契约: bool = false
	for d in 弟子列表:
		if d == null or not (d is Object):
			continue
		if d.get("主宠灵兽") != null or d.get("副宠灵兽") != null:
			有契约 = true
			break

	if 蛋列表.is_empty() and 库存.is_empty() and not 有契约:
		_yushou_空行("（御兽堂暂无灵兽）")
	else:
		_yushou_契约区(弟子列表)
		_yushou_蛋区(蛋列表)
		_yushou_库存区(库存)
	# 引育计划队列独立于「有无灵兽」渲染：队列数据源是 Game.灵兽兑换队列（与蛋/库存/契约无关），
	# 且开局空态下若一并隐藏，「＋ 新增引育计划」入口将不可达 —— 与本任务「让灵兽系统正式可达」相悖。
	# 这是相对 main.gd 刷新御兽()（空态 return 前置、连队列一起吞掉）的唯一有意微调，仍为纯只读。
	_yushou_队列区(队列)

# ── 已契约灵兽（双槽：主宠 / 副宠）──
func _yushou_契约区(弟子列表: Array) -> void:
	var 行号: int = 0
	for d in 弟子列表:
		if d == null or not (d is Object):
			continue
		for 槽 in ["主宠", "副宠"]:
			var 槽名: String = str(槽)
			var 兽 = d.get("%s灵兽" % 槽名)
			if 兽 == null:
				continue
			if 行号 == 0:
				_yushou_子标题("已契约灵兽")
			行号 += 1
			var vb: VBoxContainer = _yushou_新面板("Contract_%d" % 行号)
			var 姓名: String = str(_safe_get(d, "姓名", "—"))
			_yushou_正文(vb, "【%s】%s灵兽：%s" % [姓名, 槽名, _兽_简介(兽)])
			var 卸: Button = _yushou_按钮(vb, "卸下%s" % 槽名)
			卸.pressed.connect(_on_灵兽卸下_pressed.bind(d, 槽名, 卸))

# ── 灵兽蛋（孵化中，纯文本行）──
func _yushou_蛋区(蛋列表: Array) -> void:
	if 蛋列表.is_empty():
		return
	_yushou_子标题("灵兽蛋")
	for 蛋 in 蛋列表:
		if 蛋 == null:
			continue
		var vb: VBoxContainer = _yushou_新面板("Egg_%d" % _yushou_vbox.get_child_count())
		# 蛋走无参 简介()（孵化中分支不看本体战力），与 main.gd 刷新御兽() 一致
		_yushou_正文(vb, _兽_简介(蛋, false))

# ── 库存未绑定灵兽 ──
func _yushou_库存区(库存: Array) -> void:
	if 库存.is_empty():
		return
	_yushou_子标题("待契约灵兽（库存）")
	for 灵兽 in 库存:
		if 灵兽 == null:
			continue
		var vb: VBoxContainer = _yushou_新面板("Stock_%d" % _yushou_vbox.get_child_count())
		_yushou_正文(vb, _兽_简介(灵兽))
		var 绑: Button = _yushou_按钮(vb, "绑定给空闲弟子", true)
		绑.pressed.connect(_on_灵兽绑定_pressed.bind(灵兽, 绑))

# ── T03 引育计划队列（拨付经费）──
func _yushou_队列区(队列: Array) -> void:
	_yushou_子标题("引育计划队列（拨付经费）")
	if 队列.is_empty():
		_yushou_空行("（未设置引育计划，点击下方按钮添加）")
	for i in 队列.size():
		var 条目 = 队列[i]
		if not (条目 is Dictionary):
			continue
		var vb: VBoxContainer = _yushou_新面板("Breed_%d" % i)
		var 启用: bool = bool(条目.get("启用", false))
		_yushou_正文(vb, "模式：%s | 拨付经费 %d 灵石 | %s" % [
			_引育模式文本(条目), int(条目.get("cost", 0)), ("启用" if 启用 else "停用")
		])
		var 行 := HBoxContainer.new()
		行.add_theme_constant_override("separation", UITheme.GRID)
		vb.add_child(行)
		var 启停: Button = _yushou_按钮(行, "停用" if 启用 else "启用")
		启停.pressed.connect(_on_灵兽兑换启停_pressed.bind(i, 启停))
		var 删: Button = _yushou_按钮(行, "删除")
		删.pressed.connect(_on_灵兽兑换删除_pressed.bind(i, 删))
	var 添加: Button = _yushou_按钮(_yushou_vbox, ("收起引育预设" if _yushou_新增展开 else "＋ 新增引育计划"), true)
	添加.name = "BreedAddBtn"
	添加.pressed.connect(_on_灵兽兑换新增_pressed.bind(添加))
	if _yushou_新增展开:
		_yushou_新增选择器()

# 「＋ 新增引育计划」展开后的预设选择器（页内内联，不弹窗）。
# 不做 main.gd 式的遮罩弹窗：本页无弹窗基建，且 480×854 竖屏内内联展开随 ScrollVBox 一起滚动，
# 手势更简单、也不会与殿阁详情二级视图的显隐模式打架。选中任一预设即入队并自动收起。
func _yushou_新增选择器() -> void:
	var vb: VBoxContainer = _yushou_新面板("BreedPresets")
	_yushou_正文(vb, "选择引育偏好与单次拨付经费，加入引育计划队列；周期结算时自动拨付灵石生成兽卵。")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", UITheme.GRID)
	grid.add_theme_constant_override("v_separation", UITheme.GRID)
	vb.add_child(grid)
	for i in YUSHOU_引育预设.size():
		var 预设: Dictionary = YUSHOU_引育预设[i]
		var b: Button = _yushou_按钮(grid, str(预设.get("标签", "—")))
		b.pressed.connect(_on_灵兽_兑换_新增_确认.bind(i, b))

# 引育计划模式文本：读 Beast.品阶显示 / Beast.类型中文 常量表（class_name Beast 全局可见，只读）
func _引育模式文本(条目: Dictionary) -> String:
	var 偏好 = 条目.get("偏好", {})
	if not (偏好 is Dictionary):
		return "泛性引育"
	var 品阶键: String = str(偏好.get("品阶", ""))
	if 品阶键 != "":
		return "定向品阶：" + str(Beast.品阶显示.get(品阶键, 品阶键))
	var 类型键: String = str(偏好.get("类型", ""))
	if 类型键 != "":
		return "定向属性：" + str(Beast.类型中文.get(类型键, 类型键))
	return "泛性引育"

# 灵兽简介只读取数：带战力时走 简介(本体战力())，否则走无参 简介()；缺方法即降级为「—」，不臆造 API。
func _兽_简介(兽: Variant, 带战力: bool = true) -> String:
	if 兽 == null or not (兽 is Object):
		return "—"
	if not 兽.has_method("简介"):
		return "—"
	if 带战力 and 兽.has_method("本体战力"):
		return str(兽.简介(兽.本体战力()))
	return str(兽.简介())

# ── hall_yushou UI 构件（本页私有，复用 UITheme token，无硬编码颜色/字号）──
func _yushou_子标题(文本: String) -> void:
	var l := Label.new()
	l.text = "—— %s ——" % 文本
	UITheme.apply_body_font_sized(l, YUSHOU_FONT_SUB)
	l.add_theme_color_override("font_color", UITheme.color_text_title2())
	_yushou_vbox.add_child(l)

func _yushou_空行(文本: String) -> void:
	var l := Label.new()
	l.text = 文本
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_font_sized(l, YUSHOU_FONT_AUX)
	l.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	_yushou_vbox.add_child(l)

func _yushou_新面板(节点名: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = 节点名
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vb)
	_yushou_vbox.add_child(panel)
	return vb

func _yushou_正文(parent: Control, 文本: String) -> void:
	var l := Label.new()
	l.text = 文本
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 竖屏 480 宽 + 灵兽简介偏长，必须自动换行，否则会横向溢出面板
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_font_sized(l, YUSHOU_FONT_BODY)
	parent.add_child(l)

func _yushou_按钮(parent: Control, 文本: String, 主要: bool = false) -> Button:
	var btn := Button.new()
	btn.text = 文本
	btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if 主要:
		UITheme.apply_primary_button_style(btn)
	else:
		UITheme.apply_secondary_button_style(btn)
	parent.add_child(btn)
	return btn

# ── hall_yushou 按钮事件：按钮只负责「按压反馈 + emit 信号」，不直接写 GameState。──
# 真正的 mutation 在下方「信号接线」区的 _on_灵兽_* handler 里做，保持「按钮 → 信号 → handler → 数据层」
# 单向链路，宿主日后接管其中任何一环都不必改按钮代码。
func _on_灵兽卸下_pressed(弟子: Variant, 槽: String, btn: Button = null) -> void:
	if btn != null:
		UITween.button_press(btn)
	灵兽_卸下_request.emit(弟子, 槽)

func _on_灵兽绑定_pressed(灵兽: Variant, btn: Button = null) -> void:
	if btn != null:
		UITween.button_press(btn)
	灵兽_绑定_request.emit(灵兽)

func _on_灵兽兑换启停_pressed(序号: int, btn: Button = null) -> void:
	if btn != null:
		UITween.button_press(btn)
	灵兽_兑换_启停_request.emit(序号)

func _on_灵兽兑换删除_pressed(序号: int, btn: Button = null) -> void:
	if btn != null:
		UITween.button_press(btn)
	灵兽_兑换_删除_request.emit(序号)

func _on_灵兽兑换新增_pressed(btn: Button = null) -> void:
	if btn != null:
		UITween.button_press(btn)
	灵兽_兑换_新增_request.emit()

# ═════════ hall_yushou · 信号接线（S1 ENG-S1-YUSHOU-WIRE）═════════
# 上一轮 ENG-S1-HALLYUSHOU 只建了 5 条 request 信号（只 emit、无订阅者），灵兽因此不可操作。
# 本轮把它们接到 GameState 真实 mutation 上，御兽堂即刻可用。
#
# 为什么「自连」而不是等宿主接线：
#   全项目 grep 这 5 条信号，除本文件 emit 外没有任何 connect —— 交给宿主意味着继续悬空。
#   自连让御兽堂自给自足，同时信号仍是公开契约（宿主可另行 connect 做 toast / 埋点，不冲突）。
# 模块边界（R8）：全程只调 Game.* 公有方法，不 call main.gd 的 _on_卸下/_on_绑定/_on_兑换*，
#   main.gd 那套复用端口原样保留、行为仅作参考。
# 反馈策略：本页无弹窗/Toast 基建，故把数据层返回的中文文案写进 _yushou_状态，由 _yushou_状态行()
#   渲染在御兽堂顶部（success/danger 双色 token）；失败路径额外 push_warning，全程不阻塞。
func _connect_signals() -> void:
	if _signals_connected:
		return
	_signals_connected = true
	灵兽_卸下_request.connect(_on_灵兽_卸下)
	灵兽_绑定_request.connect(_on_灵兽_绑定)
	灵兽_兑换_启停_request.connect(_on_灵兽_兑换_启停)
	灵兽_兑换_删除_request.connect(_on_灵兽_兑换_删除)
	灵兽_兑换_新增_request.connect(_on_灵兽_兑换_新增)

# 解除主宠/副宠契约 → Game.解绑灵兽(弟子, 槽位)（game_state.gd L3321，返回结果文案，灵兽退回 灵兽库存）
func _on_灵兽_卸下(弟子: Variant, 槽: String) -> void:
	if not _yushou_数据层就绪("解绑灵兽"):
		return
	# 信号签名里 弟子 是无类型 Variant（信号契约不引入 Disciple 依赖），故此处显式收窄再传给 typed API，
	# 否则 null / 已释放实例会直接把 GDScript 的参数类型检查打成运行时错误。
	if not (弟子 is Disciple) or not is_instance_valid(弟子):
		_yushou_提示("卸下失败：弟子对象已失效。", false)
		_yushou_重绘()
		return
	var 槽位: String = "副宠" if 槽 == "副宠" else "主宠"
	_yushou_提示(str(Game.解绑灵兽(弟子 as Disciple, 槽位)), true)
	_yushou_重绘()

# 库存灵兽绑定给空闲弟子 → Game.绑定灵兽给首只合格(灵兽)（game_state.gd L3294，内部转调 绑定灵兽给指定弟子 L3303）
func _on_灵兽_绑定(灵兽: Variant) -> void:
	if not _yushou_数据层就绪("绑定灵兽给首只合格"):
		return
	if not (灵兽 is Beast) or not is_instance_valid(灵兽):
		_yushou_提示("绑定失败：灵兽对象已失效。", false)
		_yushou_重绘()
		return
	var 结果: String = str(Game.绑定灵兽给首只合格(灵兽 as Beast))
	# 数据层成功/失败都只返回文案（无资质匹配的弟子时返回「无符合条件的空闲弟子可绑定…」），
	# 不返回 bool；故以「该灵兽是否已被移出库存」作为客观成功判据，避免解析文案。
	var 成功: bool = not _as_array(Game.get("灵兽库存")).has(灵兽)
	_yushou_提示(结果, 成功)
	_yushou_重绘()

# 引育计划：启停 / 删除 / 展开新增选择器 → Game.灵兽兑换_*（game_state.gd，本轮新增，含越界守卫）
func _on_灵兽_兑换_启停(序号: int) -> void:
	if not _yushou_数据层就绪("灵兽兑换_启停"):
		return
	# 与「删除」一致：先判定合法性再调用，不依赖实参求值顺序（启停虽不改 size，但保持同一写法便于阅读）。
	var 合法: bool = _队列序号合法(序号)
	_yushou_提示(str(Game.灵兽兑换_启停(序号)), 合法)
	_yushou_重绘()

func _on_灵兽_兑换_删除(序号: int) -> void:
	if not _yushou_数据层就绪("灵兽兑换_删除"):
		return
	# 合法性必须在删除【之前】判定：删完 size 会变小，事后再比对序号会误判。
	var 合法: bool = _队列序号合法(序号)
	_yushou_提示(str(Game.灵兽兑换_删除(序号)), 合法)
	_yushou_重绘()

# 「＋ 新增引育计划」本身不入队，只切换页内预设选择器的展开态（真正入队在 _on_灵兽_兑换_新增_确认）。
# 与 main.gd _弹出兑换新增() 同构：那边弹窗选预设，这边内联展开选预设，都不做「盲目新增默认计划」。
func _on_灵兽_兑换_新增() -> void:
	_yushou_新增展开 = not _yushou_新增展开
	_yushou_重绘()

# 选定预设 → Game.灵兽兑换_新增(偏好, 经费)（game_state.gd，本轮新增；内部对偏好深拷贝，规避 const 只读）
func _on_灵兽_兑换_新增_确认(预设序号: int, btn: Button = null) -> void:
	if btn != null:
		UITween.button_press(btn)
	if not _yushou_数据层就绪("灵兽兑换_新增"):
		return
	if 预设序号 < 0 or 预设序号 >= YUSHOU_引育预设.size():
		_yushou_提示("新增失败：引育预设序号越界。", false)
		_yushou_重绘()
		return
	var 预设: Dictionary = YUSHOU_引育预设[预设序号]
	var 偏好: Variant = 预设.get("偏好", {})
	var 结果: String = str(Game.灵兽兑换_新增(偏好 if 偏好 is Dictionary else {}, int(预设.get("cost", 0))))
	_yushou_新增展开 = false   # 选完即收起，避免预设面板长期占据竖屏高度
	_yushou_提示("%s（%s）" % [结果, str(预设.get("标签", "—"))], true)
	_yushou_重绘()

# 数据层就绪守卫：Game 未就位或缺方法时给出可见提示并 push_warning，绝不臆造 API、绝不静默失败。
# 失败分支自行触发一次重绘，否则提示只写进变量却没人渲染（handler 在守卫失败时就 return 了）。
# 注意 _refresh_yushou() 先渲染状态行、再判 Game 有效性，故 Game 为空时提示依然可见。
func _yushou_数据层就绪(方法名: String) -> bool:
	if not is_instance_valid(Game):
		_yushou_提示("御兽堂数据未就绪（Game 未加载）。", false)
		_yushou_重绘()
		return false
	if not Game.has_method(方法名):
		_yushou_提示("操作失败：数据层缺 %s()。" % 方法名, false)
		_yushou_重绘()
		return false
	return true

func _队列序号合法(序号: int) -> bool:
	return 序号 >= 0 and 序号 < _as_array(Game.get("灵兽兑换队列")).size()

# 御兽堂重绘（handler 专用）：一律延后到 idle 帧，绝不在按钮 pressed 回调内同步重建子树。
# 依据 main.gd L379 的既有裁定注释「避免招徒等 pressed 回调内同步刷新重建当前页→释放发射者节点崩溃」，
# 以及 main.gd _on_卸下/_on_绑定 开头那句 await get_tree().process_frame —— 二者是同一个躲避动作。
# 本页 _enter_tree() 早已用 refresh.call_deferred() 处理过同类重入风险，此处沿用同一手法。
# 注：卸下/绑定还会经 弟子变动(CONNECT_DEFERRED) → refresh_all() 再刷一次；两次重绘幂等，不冲突。
func _yushou_重绘() -> void:
	_refresh_yushou.call_deferred()

func _yushou_提示(文本: String, 成功: bool) -> void:
	_yushou_状态 = 文本
	_yushou_状态_成功 = 成功
	if not 成功:
		push_warning("[hall_yushou] " + 文本)

# 御兽堂顶部结果行：由 _refresh_yushou() 在清空子节点后第一个渲染，无内容时不占位。
func _yushou_状态行() -> void:
	if _yushou_状态 == "" or _yushou_vbox == null:
		return
	var l := Label.new()
	l.name = "YushouStatus"
	l.text = _yushou_状态
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_font_sized(l, YUSHOU_FONT_AUX)
	l.add_theme_color_override("font_color", UITheme.color_status_success() if _yushou_状态_成功 else UITheme.color_status_danger())
	_yushou_vbox.add_child(l)

func _as_array(v: Variant) -> Array:
	if v is Array:
		return v
	return []

# ───────── 殿阁详情二级子视图（ListRoot / DetailRoot 显隐，复用 page_disciple 范式）─────────
func _build_detail_root() -> void:
	var bar := HBoxContainer.new()
	bar.name = "BackBar"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	var back_btn := Button.new()
	back_btn.name = "BackBtn"
	back_btn.text = "← 返回"
	back_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	back_btn.pressed.connect(_on_back_pressed)
	bar.add_child(back_btn)
	var title := Label.new()
	title.text = "殿阁详情"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_title_font(title)
	bar.add_child(title)
	_detail_root.add_child(bar)

	var scroll := ScrollContainer.new()
	scroll.name = "DetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_root.add_child(scroll)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.name = "DetailVBox"
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	scroll.add_child(_detail_vbox)

func _show_detail(key: String) -> void:
	if _detail_root == null or _list_root == null:
		return
	_populate_building_detail(key)
	_list_root.visible = false
	_detail_root.visible = true
	UITween.fade_in(_detail_root)

func _on_back_pressed() -> void:
	殿阁详情返回.emit()
	_detail_root.visible = false
	if _list_root != null:
		_list_root.visible = true

func _populate_building_detail(key: String) -> void:
	if _detail_vbox == null:
		return
	for child in _detail_vbox.get_children():
		_detail_vbox.remove_child(child)
		child.queue_free()

	if not is_instance_valid(Game):
		return
	var 列表 = Game.get("司职列表")
	if 列表 == null or not (列表 is Dictionary):
		return
	var entry = 列表.get(key, null)
	if entry == null or not (entry is Dictionary):
		return

	var 等级: int = int(_safe_get(entry, "等级", 1))
	var 上限: int = _殿阁上限()

	_build_header(entry, 等级, 上限)

	var 产出区: VBoxContainer = _add_section("产出信息")
	_add_kv_row(产出区, "产出", str(_safe_get(entry, "产出", "—")))
	var 预估: int = 0
	if Game.has_method("预估殿阁产出"):
		预估 = int(Game.预估殿阁产出(key))
	_add_kv_row(产出区, "预估月产出", "%d" % 预估)
	var 等级乘区: float = 1.0 + 0.02 * max(0, 等级 - 1)
	_add_kv_row(产出区, "等级乘区", "x%.2f" % 等级乘区)

	var 升级区: VBoxContainer = _add_section("升级操作")
	_build_upgrade_bar(升级区, 等级, 上限)
	_build_upgrade_button(升级区, key, 等级, 上限)

	var 人员区: VBoxContainer = _add_section("人员管理")
	var 负责人obj = _safe_get(entry, "负责人", null)
	var 负责人名 := "缺"
	if 负责人obj != null and 负责人obj is Object:
		var 名v = 负责人obj.get("姓名")
		if 名v != null:
			负责人名 = str(名v)
	_add_kv_row(人员区, "主事", 负责人名)
	var 成员 = _safe_get(entry, "成员", [])
	var 成员数: int = 0
	if 成员 is Array:
		成员数 = 成员.size()
	_add_kv_row(人员区, "成员数", "%d" % 成员数)
	_build_任免_button(人员区, key)

	var 被动区: VBoxContainer = _add_section("被动效果")
	_build_被动效果(被动区, entry)

	# 功能开关区：仅当 entry 真实存在 负责人锁定(bool) 字段才展示 Toggle（设计规格附录A 降级项）
	var 锁定v = entry.get("负责人锁定", null)
	if typeof(锁定v) == TYPE_BOOL:
		var 开关区: VBoxContainer = _add_section("功能开关")
		_build_lock_toggle(开关区, key, bool(锁定v))

	_build_footer(key, 等级, 上限)

func _build_header(entry: Dictionary, 等级: int, 上限: int) -> void:
	var panel := PanelContainer.new()
	panel.name = "HeaderSection"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)

	var 名称 := Label.new()
	名称.text = str(_safe_get(entry, "名称", "—"))
	UITheme.apply_title_font(名称)
	vbox.add_child(名称)

	var 职能 := Label.new()
	职能.text = "职能：" + str(_safe_get(entry, "职能", "—"))
	UITheme.apply_aux_font(职能)
	vbox.add_child(职能)

	var 等级行 := HBoxContainer.new()
	等级行.add_theme_constant_override("separation", UITheme.GRID)
	var 等级标签 := Label.new()
	等级标签.text = "等级 %d / %d" % [等级, 上限]
	UITheme.apply_value_font(等级标签, false)
	等级行.add_child(等级标签)
	等级行.add_spacer(true)
	var 加成标签 := Label.new()
	加成标签.text = "加成：" + str(_safe_get(entry, "加成维度", "—"))
	UITheme.apply_aux_font(加成标签)
	等级行.add_child(加成标签)
	vbox.add_child(等级行)

	_detail_vbox.add_child(panel)

func _add_section(标题: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "Section_%s" % 标题
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)
	var t := Label.new()
	t.text = 标题
	UITheme.apply_title_font(t)
	vbox.add_child(t)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(content)
	_detail_vbox.add_child(panel)
	return content

func _add_kv_row(parent: Control, 标题: String, 值: String, 异常: bool = false) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var c := Label.new()
	c.text = 标题
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.custom_minimum_size = Vector2(UITheme.GRID * 12, 0)
	UITheme.apply_aux_font(c)
	hb.add_child(c)
	var v := Label.new()
	v.text = 值
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if 异常:
		UITheme.apply_value_font(v, true)
	else:
		UITheme.apply_body_font(v)
	hb.add_child(v)
	parent.add_child(hb)

func _build_upgrade_bar(parent: Control, 等级: int, 上限: int) -> void:
	var bar := ProgressBar.new()
	bar.name = "UpgradeBar"
	bar.min_value = 0.0
	bar.max_value = float(上限) if 上限 > 0 else 1.0
	bar.value = float(等级)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, UITheme.GRID * 2)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = UITheme.color_text_gold()
	fill.set_corner_radius_all(UITheme.RADIUS_BUTTON)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.color_bg_content()
	bg.set_corner_radius_all(UITheme.RADIUS_BUTTON)
	bar.add_theme_stylebox_override("background", bg)
	parent.add_child(bar)

	var cap := Label.new()
	cap.text = "修葺 Lv %d / %d" % [等级, 上限]
	UITheme.apply_aux_font(cap)
	parent.add_child(cap)

func _build_upgrade_button(parent: Control, key: String, 等级: int, 上限: int) -> void:
	var btn := Button.new()
	btn.name = "UpgradeBtn"
	btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_primary_button_style(btn)
	if 等级 < 上限:
		btn.text = "修葺升级"
		btn.disabled = false
	else:
		btn.text = "已达上限"
		btn.disabled = true
	btn.pressed.connect(_on_升级_pressed.bind(key, btn))
	parent.add_child(btn)

func _build_任免_button(parent: Control, key: String) -> void:
	var btn := Button.new()
	btn.name = "AppointBtn"
	btn.text = "任免主事"
	btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(btn)
	btn.pressed.connect(_on_任免_pressed.bind(btn, key))
	parent.add_child(btn)

func _build_被动效果(parent: Control, entry: Dictionary) -> void:
	var 加成 = _safe_get(entry, "加成维度", null)
	if 加成 is Dictionary:
		for k in 加成.keys():
			_add_kv_row(parent, str(k), str(加成[k]))
	elif 加成 is Array:
		for item in 加成:
			_add_kv_row(parent, "加成维度", str(item))
	else:
		_add_kv_row(parent, "加成维度", str(加成) if 加成 != null else "—")
	_add_kv_row(parent, "政绩", str(_safe_get(entry, "政绩", 0)))
	_add_kv_row(parent, "里程碑", str(_safe_get(entry, "里程碑", 0)))

func _build_lock_toggle(parent: Control, key: String, 锁定: bool) -> void:
	var check := CheckButton.new()
	check.name = "LockToggle"
	check.text = "主事锁定"
	check.button_pressed = 锁定
	check.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.pressed.connect(_on_lock_pressed.bind(check))
	check.toggled.connect(_on_lock_toggled.bind(key))
	parent.add_child(check)

func _build_footer(key: String, 等级: int, 上限: int) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var back := Button.new()
	back.name = "BackToList"
	back.text = "返回列表"
	back.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(back)
	back.pressed.connect(_on_back_pressed)
	hb.add_child(back)

	var up := Button.new()
	up.name = "UpgradeFooter"
	up.text = "升级"
	up.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_primary_button_style(up)
	if not (等级 < 上限):
		up.disabled = true
	up.pressed.connect(_on_升级_pressed.bind(key, up))
	hb.add_child(up)

	_detail_vbox.add_child(hb)

func _on_任免_pressed(btn: Button, key: String) -> void:
	UITween.button_press(btn)
	殿阁任免请求.emit(key)

func _on_lock_pressed(btn: Button) -> void:
	UITween.button_press(btn)

func _on_lock_toggled(开启: bool, key: String) -> void:
	殿阁开关请求.emit(key, 开启)

func _殿阁上限() -> int:
	if is_instance_valid(Game) and Game.has_method("_殿阁等级上限"):
		return int(Game._殿阁等级上限())
	return 殿阁等级上限_兜底

func _safe_get(obj: Variant, prop: String, default: Variant = null) -> Variant:
	if obj == null:
		return default
	if obj is Dictionary:
		return obj.get(prop, default)
	if obj is Object:
		var v = obj.get(prop)
		return v if v != null else default
	return default

# 让 PanelContainer 行整体可点：除 Button 外所有子节点设为 IGNORE，事件穿透到 PanelContainer。
func _pass_through(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			_pass_through(child)
			continue
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pass_through(child)

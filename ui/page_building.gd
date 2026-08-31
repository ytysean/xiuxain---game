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

const RedDotBadge := preload("res://ui/red_dot_badge.gd")

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

# 炼丹系统
var _选中丹方: String = ""
var _丹方详情区: VBoxContainer = null
var _丹药库区: VBoxContainer = null

# 炼器系统
var _选中配方: String = ""

# 灵田/矿脉系统
var _选中灵材: String = ""
var _选中矿石: String = ""
var _当前天数: int = 1  # 缓存当前游戏天数

# 调试模式：运行时拖动热区和文字
var _调试模式: bool = false
var _调试提示: Label = null
var _坐标显示: Label = null
var _拖动控件: Control = null
var _拖动起始鼠标: Vector2 = Vector2.ZERO
var _拖动起始anchor: Vector2 = Vector2.ZERO
var _热区控件: Dictionary = {}  # key -> Control
var _标签控件: Dictionary = {}  # key -> Control
var _当前选中key: String = ""
var _当前选中是否热区: bool = false

# hall_yushou 交互态（S1 ENG-S1-YUSHOU-WIRE）
var _signals_connected: bool = false          # _connect_signals() 幂等守卫，保证 5 条信号只连一次
var _任免展开: bool = false                    # 殿阁详情内联「任免主事」选择器展开态
var _任免_key: String = ""                     # 当前展开选择器的殿阁 key
var _yushou_状态: String = ""                  # 最近一次灵兽操作的结果文案（轻量 toast 占位，渲染于御兽堂顶部）
var _yushou_状态_成功: bool = true             # 决定状态行取 success 还是 danger 色 token
var _yushou_新增展开: bool = false             # 「＋ 新增引育计划」预设选择器的展开态

func _ready() -> void:
	_connect_signals()
	_build()
	refresh()
	set_process_input(true)  # 启用_input用于调试模式拖动

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and _导出面板 != null and is_instance_valid(_导出面板):
			_导出面板.queue_free()
			_导出面板 = null
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F3:
			_toggle_debug_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F4 and _调试模式:
			_export_coordinates()
			get_viewport().set_input_as_handled()

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

	var content: Control = UITheme.make_scene_background(self)

	# 根容器：页头 + 列表/详情两态，统一边距
	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("margin_left", UITheme.MARGIN)
	root.add_theme_constant_override("margin_right", UITheme.MARGIN)
	root.add_theme_constant_override("margin_top", UITheme.GRID)
	root.add_theme_constant_override("margin_bottom", UITheme.GRID)
	root.add_theme_constant_override("separation", UITheme.GRID)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(root)

	# 5Tab 同级切换页：不要 page_header（不要返回键、不要「殿阁」标题），
	# 与弟子/历练/纪事三个 Tab 风格一致。
	# 注意：本页内部的「殿阁详情二级子视图（ListRoot / DetailRoot）」走 line 777 的 make_back_button，
	# 那条返回键是「详情 → 列表」内部切换，与 5Tab 切换无关，必须保留。

	var panorama := Control.new()
	panorama.name = "ListRoot"
	panorama.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panorama.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panorama)
	_list_root = panorama

	_build_panorama_view(panorama)

	_detail_root = VBoxContainer.new()
	_detail_root.name = "DetailRoot"
	_detail_root.visible = false
	_detail_root.add_theme_constant_override("separation", UITheme.GRID * 2)
	_detail_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_detail_root)
	_build_detail_root()

func _build_panorama_view(parent: Control) -> void:
	# 全景图背景
	var bg := TextureRect.new()
	bg.name = "PanoramaBG"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var bg_tex = load("res://art/ui/building_scenes/panorama_bg.png")
	if bg_tex != null:
		bg.texture = bg_tex
	parent.add_child(bg)
	
	# 12个殿阁的配置（key, 名称, 热点区位置x,y,w,h, 标签位置x,y, 标签方向left/right）
	# 坐标基于用户手动调整的最终位置，y坐标已减80px（顶部资源栏高度）
	var buildings: Array = [
		{"key": "xichi", "name": "洗池·灵泉", "hx": 440, "hy": 255, "hw": 189, "hh": 94, "lx": 569, "ly": 345, "side": "left"},
		{"key": "yushou", "name": "御兽堂", "hx": 351, "hy": 150, "hw": 94, "hh": 146, "lx": 294, "ly": 154, "side": "left"},
		{"key": "zhenfa", "name": "阵法堂", "hx": 639, "hy": 142, "hw": 72, "hh": 142, "lx": 701, "ly": 158, "side": "left"},
		{"key": "tanwei", "name": "探微堂", "hx": 383, "hy": 517, "hw": 318, "hh": 330, "lx": 371, "ly": 508, "side": "left"},
		{"key": "cangjing", "name": "藏经阁", "hx": 56, "hy": 837, "hw": 218, "hh": 297, "lx": 274, "ly": 1035, "side": "left"},
		{"key": "zhifa", "name": "执法堂", "hx": 723, "hy": 561, "hw": 150, "hh": 329, "lx": 850, "ly": 599, "side": "left"},
		{"key": "gongxun", "name": "功勋堂", "hx": 192, "hy": 572, "hw": 179, "hh": 257, "lx": 154, "ly": 581, "side": "left"},
		{"key": "lingtian", "name": "灵田", "hx": 0, "hy": 1230, "hw": 149, "hh": 285, "lx": 177, "ly": 1218, "side": "left"},
		{"key": "kuangmai", "name": "矿脉", "hx": 851, "hy": 1193, "hw": 197, "hh": 322, "lx": 779, "ly": 1215, "side": "left"},
		{"key": "dantang", "name": "丹堂", "hx": 207, "hy": 1261, "hw": 252, "hh": 308, "lx": 361, "ly": 1387, "side": "left"},
		{"key": "qitang", "name": "器堂", "hx": 769, "hy": 879, "hw": 255, "hh": 302, "lx": 722, "ly": 1029, "side": "left"},
		{"key": "yuying", "name": "接引殿", "hx": 405, "hy": 1584, "hw": 288, "hh": 301, "lx": 340, "ly": 1621, "side": "left"},
	]
	
	for b in buildings:
		var key: String = b.key
		# 热区按钮（anchor百分比定位，参考尺寸1080x1920）
		var btn := Button.new()
		btn.name = "Hotspot_" + key
		btn.flat = true
		btn.modulate.a = 0.0  # 正常模式完全透明
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.anchor_left = float(b.hx) / 1080.0
		btn.anchor_top = float(b.hy) / 1920.0
		btn.anchor_right = float(b.hx + b.hw) / 1080.0
		btn.anchor_bottom = float(b.hy + b.hh) / 1920.0
		btn.offset_left = 0
		btn.offset_top = 0
		btn.offset_right = 0
		btn.offset_bottom = 0
		btn.pressed.connect(func(): _on_hotspot_pressed(key))
		btn.gui_input.connect(func(e): _on_drag_gui_input(e, btn, key, true))
		parent.add_child(btn)
		_热区控件[key] = btn
		
		# 文字标签（anchor定位，固定字号，增强可读性）
		var label := Label.new()
		label.name = "Label_" + key
		label.text = b.name
		label.mouse_filter = Control.MOUSE_FILTER_STOP  # 关键：Label默认不收鼠标事件
		label.anchor_left = float(b.lx) / 1080.0
		label.anchor_top = float(b.ly) / 1920.0
		label.offset_left = 0
		label.offset_top = 0
		label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))  # 更亮的金色
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))  # 纯黑阴影
		label.add_theme_constant_override("shadow_offset_x", 3)
		label.add_theme_constant_override("shadow_offset_y", 3)
		label.add_theme_font_size_override("font_size", 26)  # 增大字号
		label.add_theme_constant_override("outline_size", 4)  # 文字描边
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05, 0.95))  # 深金描边
		label.gui_input.connect(func(e): _on_drag_gui_input(e, label, key, false))
		parent.add_child(label)
		_标签控件[key] = label

	# 调试提示标签（放底部，不挡操作）
	_调试提示 = Label.new()
	_调试提示.name = "DebugHint"
	_调试提示.visible = false
	_调试提示.anchor_left = 0
	_调试提示.anchor_right = 1
	_调试提示.anchor_bottom = 1
	_调试提示.offset_left = 10
	_调试提示.offset_right = -10
	_调试提示.offset_top = -35
	_调试提示.offset_bottom = -5
	_调试提示.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	_调试提示.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_调试提示.add_theme_font_size_override("font_size", 16)
	_调试提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(_调试提示)
	# 实时坐标显示（左上角，避开御兽堂x:282+/y:143+）
	_坐标显示 = Label.new()
	_坐标显示.name = "CoordDisplay"
	_坐标显示.visible = false
	_坐标显示.anchor_left = 0
	_坐标显示.anchor_top = 0
	_坐标显示.anchor_right = 0
	_坐标显示.anchor_bottom = 0
	_坐标显示.offset_left = 8
	_坐标显示.offset_top = 8
	_坐标显示.custom_minimum_size = Vector2(260, 130)
	_坐标显示.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
	_坐标显示.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_坐标显示.add_theme_font_size_override("font_size", 14)
	_坐标显示.text = "【坐标】点击热区/标签查看"
	parent.add_child(_坐标显示)

func _on_hotspot_pressed(key: String) -> void:
	if _调试模式:
		return  # 调试模式下不触发详情
	print("[PageBuilding] 热点区被点击: ", key)
	殿阁详情请求.emit(key)
	_show_detail(key)

## === 调试模式：拖动热区和文字 ===
var _拖动是否热区: bool = false
var _拖动宽百分比: float = 0.0
var _拖动高百分比: float = 0.0
var _拖动模式: String = "move"  # "move"移动 / "resize"调整大小
var _拖动起始右下: Vector2 = Vector2.ZERO  # resize模式下记录起始anchor_right/bottom

func _on_drag_gui_input(event: InputEvent, control: Control, key: String, is_hotspot: bool) -> void:
	# 正常模式：文字标签点击跳转
	if not _调试模式:
		if not is_hotspot and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_hotspot_pressed(key)
		return
	# 调试模式：拖动逻辑
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_拖动控件 = control
		_拖动是否热区 = is_hotspot
		_当前选中key = key
		_当前选中是否热区 = is_hotspot
		_拖动起始鼠标 = get_viewport().get_mouse_position()
		_拖动起始anchor = Vector2(control.anchor_left, control.anchor_top)
		_拖动模式 = "move"
		if is_hotspot:
			_拖动宽百分比 = control.anchor_right - control.anchor_left
			_拖动高百分比 = control.anchor_bottom - control.anchor_top
			_拖动起始右下 = Vector2(control.anchor_right, control.anchor_bottom)
			var 局部鼠标 = control.get_local_mouse_position()
			var 控件尺寸 = control.size
			if 控件尺寸.x > 0 and 控件尺寸.y > 0:
				var 距右 = 控件尺寸.x - 局部鼠标.x
				var 距下 = 控件尺寸.y - 局部鼠标.y
				if 距右 < 25 and 距下 < 25:
					_拖动模式 = "resize"
		_更新坐标显示()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not _调试模式 or _拖动控件 == null:
		return
	if event is InputEventMouseMotion:
		var 当前鼠标 = get_viewport().get_mouse_position()
		var 偏移 = 当前鼠标 - _拖动起始鼠标
		var 父 = _拖动控件.get_parent()
		if 父 != null and 父.size.x > 0 and 父.size.y > 0:
			if _拖动模式 == "move":
				# 移动模式：更新左上，保持宽高
				var 新anchor_x = clampf(_拖动起始anchor.x + 偏移.x / 父.size.x, 0, 0.9)
				var 新anchor_y = clampf(_拖动起始anchor.y + 偏移.y / 父.size.y, 0, 0.9)
				_拖动控件.anchor_left = 新anchor_x
				_拖动控件.anchor_top = 新anchor_y
				if _拖动是否热区:
					_拖动控件.anchor_right = clampf(新anchor_x + _拖动宽百分比, 0.1, 1)
					_拖动控件.anchor_bottom = clampf(新anchor_y + _拖动高百分比, 0.1, 1)
			elif _拖动模式 == "resize":
				# 调整大小模式：更新右下，保持左上
				var 新right = clampf(_拖动起始右下.x + 偏移.x / 父.size.x, _拖动起始anchor.x + 0.02, 1)
				var 新bottom = clampf(_拖动起始右下.y + 偏移.y / 父.size.y, _拖动起始anchor.y + 0.02, 1)
				_拖动控件.anchor_right = 新right
				_拖动控件.anchor_bottom = 新bottom
			_update_debug_hint()
			_更新坐标显示()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_拖动控件 = null
		_update_debug_hint()
		_更新坐标显示()
		get_viewport().set_input_as_handled()

func _toggle_debug_mode() -> void:
	_调试模式 = not _调试模式
	_update_debug_visuals()

func _update_debug_visuals() -> void:
	for key in _热区控件:
		var btn = _热区控件[key]
		if _调试模式:
			btn.modulate = Color(1, 0.2, 0.2, 0.4)
			btn.flat = false
		else:
			btn.modulate.a = 0.0
			btn.flat = true
	for key in _标签控件:
		var label = _标签控件[key]
		if _调试模式:
			label.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
			label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1))
			label.add_theme_constant_override("outline_size", 4)
		else:
			label.add_theme_color_override("font_color", Color(0.91, 0.83, 0.72))
			label.remove_theme_constant_override("outline_size")
	if _调试提示 != null:
		_调试提示.visible = _调试模式
		_update_debug_hint()
	if _坐标显示 != null:
		_坐标显示.visible = _调试模式
		if _调试模式:
			_坐标显示.text = "【坐标】点击红框/蓝字查看"

func _update_debug_hint() -> void:
	if _调试提示 == null or not _调试模式:
		return
	var 信息 = "【调试】F3退出 F4导出 | 拖红框中间=移动 拖右下角=改大小 拖蓝字=移动标签"
	if _拖动控件 != null:
		信息 += " | %s中..." % ("调整大小" if _拖动模式 == "resize" else "移动")
	_调试提示.text = 信息

func _更新坐标显示() -> void:
	if _坐标显示 == null or not _调试模式:
		return
	if _当前选中key == "":
		_坐标显示.text = "【坐标】点击红框/蓝字查看"
		return
	var 名称 = ""
	if _当前选中是否热区:
		var btn = _热区控件.get(_当前选中key, null)
		if btn != null:
			var hx = int(round(btn.anchor_left * 1080.0))
			var hy = int(round(btn.anchor_top * 1920.0))
			var hw = int(round((btn.anchor_right - btn.anchor_left) * 1080.0))
			var hh = int(round((btn.anchor_bottom - btn.anchor_top) * 1920.0))
			名称 = _标签控件.get(_当前选中key, null).text if _标签控件.has(_当前选中key) else _当前选中key
			_坐标显示.text = "【%s·热区】\nhx=%d\nhy=%d\nhw=%d\nhh=%d" % [名称, hx, hy, hw, hh]
	else:
		var label = _标签控件.get(_当前选中key, null)
		if label != null:
			var lx = int(round(label.anchor_left * 1080.0))
			var ly = int(round(label.anchor_top * 1920.0))
			名称 = label.text
			_坐标显示.text = "【%s·标签】\nlx=%d\nly=%d" % [名称, lx, ly]

var _导出面板: Control = null

func _export_coordinates() -> void:
	# 如果已有导出面板，关闭它
	if _导出面板 != null and is_instance_valid(_导出面板):
		_导出面板.queue_free()
		_导出面板 = null
		return
	# 输出到控制台
	print("\n=== 殿阁坐标导出 ===")
	var 坐标文本 = ""
	for key in _热区控件:
		var btn = _热区控件[key]
		var label = _标签控件.get(key, null)
		var hx = int(round(btn.anchor_left * 1080.0))
		var hy = int(round(btn.anchor_top * 1920.0))
		var hw = int(round((btn.anchor_right - btn.anchor_left) * 1080.0))
		var hh = int(round((btn.anchor_bottom - btn.anchor_top) * 1920.0))
		var lx = 0
		var ly = 0
		var 名称 = ""
		if label != null:
			lx = int(round(label.anchor_left * 1080.0))
			ly = int(round(label.anchor_top * 1920.0))
			名称 = label.text
		var 行 = '\t\t{"key": "%s", "name": "%s", "hx": %d, "hy": %d, "hw": %d, "hh": %d, "lx": %d, "ly": %d, "side": "left"},' % [key, 名称, hx, hy, hw, hh, lx, ly]
		print(行)
		坐标文本 += 行 + "\n"
	print("=== 导出结束 ===")
	# 创建全屏导出面板
	var panel := ColorRect.new()
	panel.name = "ExportPanel"
	panel.color = Color(0, 0, 0, 0.9)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "【坐标已导出】截图复制下方坐标，按F4或ESC关闭"
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var label := Label.new()
	label.text = 坐标文本
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	label.add_theme_font_size_override("font_size", 16)
	scroll.add_child(label)
	# 点击关闭
	panel.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			panel.queue_free()
			_导出面板 = null
	)
	add_child(panel)
	_导出面板 = panel

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

	# S1-4 付费：仙玉立即领取殿阁产出
	if is_instance_valid(Game):
		var 殿阁产出_btn := Button.new()
		殿阁产出_btn.name = "PayHallBtn"
		殿阁产出_btn.text = "领取殿阁产出（%d仙玉）" % Game.付费单价.get("殿阁产出", 25)
		殿阁产出_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		殿阁产出_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		殿阁产出_btn.pressed.connect(_on_付费_殿阁)
		hb.add_child(殿阁产出_btn)

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
	# 全景图视图：这些变量可能不存在（null），需要检查
	if _overview_司职数 != null:
		_overview_司职数.text = str(司职数)
	if _overview_总等级 != null:
		_overview_总等级.text = str(总等级)

	var 减免 = 0.0
	if is_instance_valid(Game):
		减免 = Game.get("殿阁被动_负面事件减免")
		if typeof(减免) != TYPE_FLOAT and typeof(减免) != TYPE_INT:
			减免 = 0.0
	if _passive_label != null:
		_passive_label.text = "负面事件减免 %d%%" % int(abs(减免))

	# 全景图视图：列表和御兽堂分区不显示，跳过
	if _list_vbox != null:
		_populate_list()
	if _yushou_vbox != null:
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

	# 殿阁升级红点
	var 升级红点: RedDotBadge = RedDotBadge.new()
	升级红点.name = "UpgradeRedDot_%s" % key
	升级红点.设置类型("dot")
	升级.add_child(升级红点)
	# 判断殿阁是否可升级
	var 可升级: bool = false
	if is_instance_valid(Game) and Game.has_method("升级殿阁"):
		var 殿阁等级: int = int(entry.get("等级"))
		var 上限: int = 10
		if Game.has_method("_殿阁等级上限"):
			上限 = int(Game._殿阁等级上限())
		var 门派等级: int = int(Game.get("门派等级"))
		if 殿阁等级 < 上限 and 门派等级 >= 2:
			var 费: int = 0
			if Game.has_method("_升级消耗_灵石"):
				费 = int(Game._升级消耗_灵石(殿阁等级))
			var 灵石: int = int(Game.get("灵石"))
			可升级 = 灵石 >= 费
	升级红点.visible = 可升级
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
	if not is_instance_valid(Game) or not Game.has_method("升级殿阁"):
		_toast("精进失败：功法未就绪。")
		return
	var 结果: Dictionary = Game.升级殿阁(key)
	_toast(str(结果.get("msg", "升级完成")))
	# 延后重建详情子树：pressed 回调内同步重建会释放当前按钮节点导致崩溃（同 _yushou_重绘 手法）。
	_show_detail.call_deferred(key)

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
		_yushou_空行("（御兽堂尚无灵兽）")
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
		_yushou_空行("（御兽堂尚无灵兽）")
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

	# S1-4 付费：仙玉立即孵化灵兽
	if is_instance_valid(Game):
		var 孵btn := _yushou_按钮(_yushou_vbox, "仙玉立即孵化灵兽（%d仙玉）" % Game.付费单价.get("灵兽孵化", 30), true)
		孵btn.pressed.connect(_on_付费_灵兽.bind(孵btn))
		_yushou_vbox.add_child(孵btn)

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
		_yushou_提示("气机紊乱：数据层缺 %s()。" % 方法名, false)
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
	var back_btn: Button = UITheme.make_back_button(_on_back_pressed)
	bar.add_child(back_btn)
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
	_add_kv_row(产出区, "预估日产出", "%d" % 预估)
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
	if _任免展开 and _任免_key == key:
		_任免选择器(人员区, key)

	var 被动区: VBoxContainer = _add_section("被动效果")
	_build_被动效果(被动区, entry)

	# 功能开关区：仅当 entry 真实存在 负责人锁定(bool) 字段才展示 Toggle（设计规格附录A 降级项）
	var 锁定v = entry.get("负责人锁定", null)
	if typeof(锁定v) == TYPE_BOOL:
		var 开关区: VBoxContainer = _add_section("功能开关")
		_build_lock_toggle(开关区, key, bool(锁定v))

	# 丹堂专属：炼丹系统
	if key == "dantang":
		_build_alchemy_ui(等级)
	# 器堂专属：炼器系统
	if key == "qitang":
		_build_forge_ui(等级)
	# 灵田专属：种植系统
	if key == "lingtian":
		_build_lingtian_ui(等级)
	# 矿脉专属：开采系统
	if key == "kuangmai":
		_build_kuangmai_ui(等级)
	# 藏经阁专属：功法系统
	if key == "cangjing":
		_build_cangjing_ui(等级)
	# 接引殿专属：新弟子招募
	if key == "yuying":
		_build_yuying_ui(等级)
	# 洗池·灵泉专属：命格重铸
	if key == "xichi":
		_build_xichi_ui(等级)
	# 执法堂专属：门规纪律
	if key == "zhifa":
		_build_zhifa_ui(等级)
	# 功勋堂专属：功绩声望
	if key == "gongxun":
		_build_gongxun_ui(等级)
	# 阵法堂专属：护山大阵
	if key == "zhenfa":
		_build_zhenfa_ui(等级)
	# 探微堂专属：藏宝图探查
	if key == "tanwei":
		_build_tanwei_ui(等级)

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
	# D2 收口：升级进度条 fill/bg 继承 main_theme.tres 默认（sb_pbar_fill=success 绿 / sb_pbar_bg=content），
	# 不再手写 StyleBoxFlat（原金 fill 已按主理人裁定改为绿）。radius=6 由 .tres 继承，像素等价。
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
	up.text = "精进"
	up.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_primary_button_style(up)
	if not (等级 < 上限):
		up.disabled = true
	up.pressed.connect(_on_升级_pressed.bind(key, up))
	hb.add_child(up)

	_detail_vbox.add_child(hb)

## === 炼丹系统 UI ===
func _build_alchemy_ui(丹堂等级: int) -> void:
	if _detail_vbox == null:
		return
	# 安全检查：仓库未初始化则创建
	if Game == null or not ("仓库" in Game) or Game.仓库 == null:
		if Game != null:
			Game.仓库 = []
		else:
			return
	# 丹方列表
	var 丹方区: VBoxContainer = _add_section("丹方秘录")
	var 丹方grid := GridContainer.new()
	丹方grid.columns = 2
	丹方grid.add_theme_constant_override("h_separation", UITheme.GRID)
	丹方grid.add_theme_constant_override("v_separation", UITheme.GRID)
	丹方区.add_child(丹方grid)
	var 丹方列表: Array = AlchemySystem.丹方库.keys()
	for fid in 丹方列表:
		var 丹方 = AlchemySystem.丹方库[fid]
		var btn := Button.new()
		btn.text = "%s\n%s" % [str(丹方.get("名称","")), str(丹方.get("品阶",""))]
		btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY * 1.5)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_secondary_button_style(btn)
		if _选中丹方 == fid:
			btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		btn.pressed.connect(_on_丹方选中.bind(fid))
		丹方grid.add_child(btn)
	# 选中丹方详情
	if _选中丹方 != "":
		var 详情区: VBoxContainer = _add_section("丹方详情")
		var 丹方 = AlchemySystem.丹方库.get(_选中丹方, {})
		_add_kv_row(详情区, "丹方", str(丹方.get("名称","")))
		_add_kv_row(详情区, "品阶", str(丹方.get("品阶","")))
		_add_kv_row(详情区, "产出", str(丹方.get("产出","")))
		var 成功率: float = float(丹方.get("基础成功率",50)) + float(max(0,丹堂等级-1))*2.0
		成功率 = clampf(成功率, 5.0, 95.0)
		_add_kv_row(详情区, "成功率", "%.0f%%（含丹堂等级加成）" % 成功率)
		# 材料需求
		var 材料label := Label.new()
		材料label.text = "所需材料："
		UITheme.apply_body_font(材料label)
		详情区.add_child(材料label)
		var 背包: Array = Game.仓库
		for mat in 丹方.get("材料", []):
			var 需求名: String = str(mat["名"])
			var 需求数: int = int(mat["数量"])
			var 拥有数: int = 0
			for item in 背包:
				if item != null and typeof(item)==TYPE_OBJECT and "名称" in item and str(item.名称)==需求名:
					拥有数 += 1
			var 足够: bool = 拥有数 >= 需求数
			var row := Label.new()
			row.text = "  · %s：%d/%d %s" % [需求名, 拥有数, 需求数, "✓" if 足够 else "✗"]
			UITheme.apply_body_font(row)
			if not 足够:
				row.add_theme_color_override("font_color", Color(0.8,0.4,0.4))
			详情区.add_child(row)
		# 炼丹按钮
		var 炼btn := Button.new()
		炼btn.text = "开始炼丹"
		炼btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
		炼btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_primary_button_style(炼btn)
		炼btn.pressed.connect(_on_炼丹_pressed.bind(_选中丹方, 丹堂等级))
		详情区.add_child(炼btn)
	# 丹药库
	var 库区: VBoxContainer = _add_section("丹药库")
	var 背包: Array = Game.仓库
	var 丹药数: int = 0
	for item in 背包:
		if item != null and typeof(item)==TYPE_OBJECT and "类别" in item and str(item.类别)=="dan_yao":
			丹药数 += 1
	if 丹药数 == 0:
		var empty := Label.new()
		empty.text = "尚无丹药，去炼丹吧"
		UITheme.apply_aux_font(empty)
		库区.add_child(empty)
	else:
		var 药grid := GridContainer.new()
		药grid.columns = 2
		药grid.add_theme_constant_override("h_separation", UITheme.GRID)
		药grid.add_theme_constant_override("v_separation", UITheme.GRID)
		库区.add_child(药grid)
		for i in range(背包.size()):
			var item = 背包[i]
			if item == null or typeof(item)!=TYPE_OBJECT or "类别" not in item or str(item.类别)!="dan_yao":
				continue
			var btn := Button.new()
			btn.text = "%s\n%s" % [str(item.名称), str(item.品阶)]
			btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY * 1.3)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UITheme.apply_secondary_button_style(btn)
			btn.pressed.connect(_on_服用丹药_pressed.bind(i))
			药grid.add_child(btn)

func _on_丹方选中(fid: String) -> void:
	_选中丹方 = fid
	_show_detail.call_deferred("dantang")

func _on_炼丹_pressed(fid: String, 丹堂等级: int) -> void:
	# 使用封装函数，自动更新仓库、统计和事件触发
	var 结果 = Game.执行炼丹(fid, 丹堂等级)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "炼丹", str(结果.get("原因","")))
	_show_detail.call_deferred("dantang")

func _on_服用丹药_pressed(索引: int) -> void:
	var 背包: Array = Game.仓库
	if 索引 < 0 or 索引 >= 背包.size():
		return
	var 丹药 = 背包[索引]
	if 丹药 == null:
		return
	# 暂存提示（服用需要指定弟子，S1先显示丹药效果说明）
	var 效果 = AlchemySystem.丹药效果.get(str(丹药.名称), {})
	var 提示: String = "%s\n%s\n\n（S1：服用需指定弟子，将在弟子详情页接入）" % [str(丹药.名称), str(效果.get("描述",""))]
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "丹药说明", 提示)

## === 器堂：炼器系统UI ===
func _build_forge_ui(器堂等级: int) -> void:
	# 安全检查：仓库未初始化则创建
	if Game == null or not ("仓库" in Game) or Game.仓库 == null:
		if Game != null:
			Game.仓库 = []
		else:
			return
	# 炼器等级显示
	var 炼器等级区: VBoxContainer = _add_section("炼器等级")
	var 炼器加成: Dictionary = Game.获取炼器加成() if Game != null and Game.has_method("获取炼器加成") else {"等级": 1, "成功率加成": 0, "高品质加成": 0}
	var 炼器等级label := Label.new()
	炼器等级label.text = "当前等级：Lv.%d  成功率加成：+%.0f%%  高品质加成：+%.0f%%" % [int(炼器加成["等级"]), float(炼器加成["成功率加成"]), float(炼器加成["高品质加成"]) * 100]
	UITheme.apply_body_font(炼器等级label)
	炼器等级区.add_child(炼器等级label)
	if Game != null and "炼器经验值" in Game:
		var 炼器经验label := Label.new()
		炼器经验label.text = "炼器经验：%d" % int(Game.炼器经验值)
		UITheme.apply_aux_font(炼器经验label)
		炼器等级区.add_child(炼器经验label)
	# 配方列表
	var 配方区: VBoxContainer = _add_section("炼器秘录")
	var 配方grid := GridContainer.new()
	配方grid.columns = 2
	配方grid.add_theme_constant_override("h_separation", UITheme.GRID)
	配方grid.add_theme_constant_override("v_separation", UITheme.GRID)
	配方区.add_child(配方grid)
	var 配方列表: Array = ForgeSystem.配方库.keys()
	for fid in 配方列表:
		var 配方 = ForgeSystem.配方库[fid]
		var btn := Button.new()
		btn.text = "%s\n%s" % [str(配方.get("名称","")), str(配方.get("品阶",""))]
		btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY * 1.5)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_secondary_button_style(btn)
		if _选中配方 == fid:
			btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		btn.pressed.connect(_on_配方选中.bind(fid))
		配方grid.add_child(btn)
	# 选中配方详情
	if _选中配方 != "":
		var 详情区: VBoxContainer = _add_section("配方详情")
		var 配方 = ForgeSystem.配方库.get(_选中配方, {})
		_add_kv_row(详情区, "配方", str(配方.get("名称","")))
		_add_kv_row(详情区, "品阶", str(配方.get("品阶","")))
		_add_kv_row(详情区, "产出", str(配方.get("产出名","")))
		var 类别名: String = Item.类别中文名.get(str(配方.get("产出类别","fa_qi")), "法器")
		_add_kv_row(详情区, "类别", 类别名)
		var 成功率: float = float(配方.get("基础成功率",50)) + float(max(0,器堂等级-1))*2.0
		成功率 = clampf(成功率, 5.0, 95.0)
		_add_kv_row(详情区, "成功率", "%.0f%%（含器堂等级加成）" % 成功率)
		# 材料需求
		var 材料label := Label.new()
		材料label.text = "所需材料："
		UITheme.apply_body_font(材料label)
		详情区.add_child(材料label)
		var 背包: Array = Game.仓库
		for mat in 配方.get("材料", []):
			var 需求名: String = str(mat["名"])
			var 需求数: int = int(mat["数量"])
			var 拥有数: int = 0
			for item in 背包:
				if item != null and typeof(item)==TYPE_OBJECT and "名称" in item and str(item.名称)==需求名:
					拥有数 += 1
			var 足够: bool = 拥有数 >= 需求数
			var row := Label.new()
			row.text = "  · %s：%d/%d %s" % [需求名, 拥有数, 需求数, "✓" if 足够 else "✗"]
			UITheme.apply_body_font(row)
			if not 足够:
				row.add_theme_color_override("font_color", Color(0.8,0.4,0.4))
			详情区.add_child(row)
		# 炼器按钮
		var 炼btn := Button.new()
		炼btn.text = "开始炼器"
		炼btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
		炼btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_primary_button_style(炼btn)
		炼btn.pressed.connect(_on_炼器_pressed.bind(_选中配方, 器堂等级))
		详情区.add_child(炼btn)
	# 装备库
	var 库区: VBoxContainer = _add_section("装备库")
	var 背包: Array = Game.仓库
	var 装备数: int = 0
	for item in 背包:
		if item != null and typeof(item)==TYPE_OBJECT and "类别" in item and str(item.类别) in ["fa_qi", "shen_bing", "fabao"]:
			装备数 += 1
	if 装备数 == 0:
		var empty := Label.new()
		empty.text = "尚无装备，去炼器吧"
		UITheme.apply_aux_font(empty)
		库区.add_child(empty)
	else:
		var 装grid := GridContainer.new()
		装grid.columns = 2
		装grid.add_theme_constant_override("h_separation", UITheme.GRID)
		装grid.add_theme_constant_override("v_separation", UITheme.GRID)
		库区.add_child(装grid)
		for i in range(背包.size()):
			var item = 背包[i]
			if item == null or typeof(item)!=TYPE_OBJECT or "类别" not in item or str(item.类别) not in ["fa_qi", "shen_bing", "fabao"]:
				continue
			var btn := Button.new()
			btn.text = "%s\n%s 战力:%d" % [str(item.名称), str(item.品阶), int(item.战力加成)]
			btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY * 1.3)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UITheme.apply_secondary_button_style(btn)
			btn.pressed.connect(_on_查看装备_pressed.bind(i))
			装grid.add_child(btn)

func _on_配方选中(fid: String) -> void:
	_选中配方 = fid
	_show_detail.call_deferred("qitang")

func _on_炼器_pressed(fid: String, 器堂等级: int) -> void:
	# 使用Game.执行炼器方法，自动管理炼器经验
	var 结果 = Game.执行炼器(fid, 器堂等级) if Game != null and Game.has_method("执行炼器") else ForgeSystem.炼器(fid, Game.仓库, 器堂等级)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "炼器", str(结果.get("原因","")))
	_show_detail.call_deferred("qitang")

func _on_查看装备_pressed(索引: int) -> void:
	var 背包: Array = Game.仓库
	if 索引 < 0 or 索引 >= 背包.size():
		return
	var 装备 = 背包[索引]
	if 装备 == null:
		return
	var 词缀文本: String = ""
	if 装备.词缀 != null and 装备.词缀.size() > 0:
		词缀文本 = "\n词缀：" + ", ".join(装备.词缀)
	var 套装文本: String = ""
	if 装备.套装ID != null and str(装备.套装ID) != "":
		var 套装名 = Item.套装库.get(str(装备.套装ID), {}).get("名称", str(装备.套装ID))
		套装文本 = "\n套装：%s" % 套装名
	var 提示: String = "%s\n%s\n战力：%d%s%s" % [str(装备.名称), str(装备.品阶), int(装备.战力加成), 词缀文本, 套装文本]
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "装备详情", 提示)

## === 灵田：种植系统UI ===
func _build_lingtian_ui(灵田等级: int) -> void:
	_当前天数 = Game.累计游戏日 if Game != null and "累计游戏日" in Game else 1
	# 初始化灵田数据（首次）
	if Game.灵田地块 == null or Game.灵田地块.size() == 0:
		Game.灵田地块 = LingTianSystem.初始化(灵田等级)
	# 升级后地块扩容：如果当前地块数 < 等级对应数量，补充新地块
	var 应有地块数 = LingTianSystem.获取地块数(灵田等级)
	while Game.灵田地块.size() < 应有地块数:
		Game.灵田地块.append({"索引": Game.灵田地块.size(), "状态": "空闲", "种植ID": "", "种植时间": 0, "成熟时间": 0})
	# 地块列表
	var 地块区: VBoxContainer = _add_section("灵田地块（%d块）" % LingTianSystem.获取地块数(灵田等级))
	var 地块grid := GridContainer.new()
	地块grid.columns = 3
	地块grid.add_theme_constant_override("h_separation", UITheme.GRID)
	地块grid.add_theme_constant_override("v_separation", UITheme.GRID)
	地块区.add_child(地块grid)
	for i in range(Game.灵田地块.size()):
		var 地块 = Game.灵田地块[i]
		var btn := Button.new()
		var 状态 = str(地块.get("状态", "空闲"))
		if 状态 == "空闲":
			btn.text = "地块%d\n空闲" % (i + 1)
		elif 状态 == "种植中":
			var 灵材ID = str(地块.get("种植ID", ""))
			var 灵材 = LingTianSystem.灵材库.get(灵材ID, {})
			var 灵材名 = str(灵材.get("名称", "未知"))
			var 成熟时间 = int(地块.get("成熟时间", 0))
			var 剩余 = 成熟时间 - _当前天数
			if 剩余 <= 0:
				btn.text = "地块%d\n%s\n✓可收获" % [(i + 1), 灵材名]
				btn.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
			else:
				btn.text = "地块%d\n%s\n%d日后" % [(i + 1), 灵材名, 剩余]
		btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY * 1.8)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_secondary_button_style(btn)
		btn.pressed.connect(_on_灵田地块点击.bind(i))
		地块grid.add_child(btn)
	# 可种植灵材列表
	var 灵材区: VBoxContainer = _add_section("选择灵材（选中后点击空闲地块种植）")
	var 灵材grid := GridContainer.new()
	灵材grid.columns = 2
	灵材grid.add_theme_constant_override("h_separation", UITheme.GRID)
	灵材grid.add_theme_constant_override("v_separation", UITheme.GRID)
	灵材区.add_child(灵材grid)
	for lid in LingTianSystem.灵材库.keys():
		var 灵材 = LingTianSystem.灵材库[lid]
		var btn := Button.new()
		btn.text = "%s\n%s | %d日" % [str(灵材.get("名称","")), str(灵材.get("品阶","")), int(灵材.get("成熟天数",1))]
		btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY * 1.5)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_secondary_button_style(btn)
		if _选中灵材 == lid:
			btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		btn.pressed.connect(_on_灵材选中.bind(lid))
		灵材grid.add_child(btn)
	# 操作提示
	var 提示label := Label.new()
	if _选中灵材 != "":
		var 灵材 = LingTianSystem.灵材库.get(_选中灵材, {})
		提示label.text = "已选中：%s，点击空闲地块开始种植" % str(灵材.get("名称",""))
	else:
		提示label.text = "提示：先选择灵材，再点击空闲地块种植；成熟后点击地块收获"
	UITheme.apply_aux_font(提示label)
	提示label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	_add_section("").add_child(提示label)

func _on_灵材选中(lid: String) -> void:
	_选中灵材 = lid
	_show_detail.call_deferred("lingtian")

func _on_灵田地块点击(地块索引: int) -> void:
	if 地块索引 < 0 or 地块索引 >= Game.灵田地块.size():
		return
	var 地块 = Game.灵田地块[地块索引]
	var 状态 = str(地块.get("状态", "空闲"))
	if 状态 == "空闲":
		# 种植
		if _选中灵材 == "":
			if UIHint != null and UIHint.has_method("show_hint"):
				UIHint.show_hint(null, "指点", "请先选择要种植的灵材")
			return
		var 灵田等级 = _获取殿阁等级("lingtian")
		var 结果 = LingTianSystem.种植(Game.灵田地块, 地块索引, _选中灵材, _当前天数, 灵田等级)
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "种植", str(结果.get("原因","")))
		_选中灵材 = ""
	elif 状态 == "种植中":
		# 收获（如果成熟）
		if LingTianSystem.是否成熟(地块, _当前天数):
			var 灵田等级 = _获取殿阁等级("lingtian")
			var 结果 = LingTianSystem.收获(Game.灵田地块, 地块索引, _当前天数, 灵田等级)
			if 结果.get("成功", false):
				var 产出 = 结果.get("产出", null)
				var 数量 = int(结果.get("数量", 1))
				for n in range(数量):
					Game.仓库.append(产出.duplicate())
			if UIHint != null and UIHint.has_method("show_hint"):
				UIHint.show_hint(null, "收获", str(结果.get("原因","")))
		else:
			var 剩余 = int(地块.get("成熟时间", 0)) - _当前天数
			if UIHint != null and UIHint.has_method("show_hint"):
				UIHint.show_hint(null, "指点", "尚未成熟，还需%d日" % 剩余)
	_show_detail.call_deferred("lingtian")

## === 矿脉：开采系统UI ===
func _build_kuangmai_ui(矿脉等级: int) -> void:
	_当前天数 = Game.累计游戏日 if Game != null and "累计游戏日" in Game else 1
	var 矿脉等级实际 = _获取殿阁等级("kuangmai")
	# 初始化矿脉数据（首次）
	if Game.矿脉矿点 == null or Game.矿脉矿点.size() == 0:
		Game.矿脉矿点 = KuangMaiSystem.初始化(矿脉等级实际)
	# 升级后矿点扩容：如果当前矿点数 < 等级对应数量，补充新矿点
	var 应有矿点数 = KuangMaiSystem.获取矿点数(矿脉等级实际)
	while Game.矿脉矿点.size() < 应有矿点数:
		Game.矿脉矿点.append({"索引": Game.矿脉矿点.size(), "状态": "空闲", "开采ID": "", "开采时间": 0, "完成时间": 0})
	# 矿点列表
	var 矿点区: VBoxContainer = _add_section("矿脉矿点（%d个）" % KuangMaiSystem.获取矿点数(矿脉等级实际))
	var 矿点grid := GridContainer.new()
	矿点grid.columns = 3
	矿点grid.add_theme_constant_override("h_separation", UITheme.GRID)
	矿点grid.add_theme_constant_override("v_separation", UITheme.GRID)
	矿点区.add_child(矿点grid)
	for i in range(Game.矿脉矿点.size()):
		var 矿点 = Game.矿脉矿点[i]
		var btn := Button.new()
		var 状态 = str(矿点.get("状态", "空闲"))
		if 状态 == "空闲":
			btn.text = "矿点%d\n空闲" % (i + 1)
		elif 状态 == "开采中":
			var 矿石ID = str(矿点.get("开采ID", ""))
			var 矿石 = KuangMaiSystem.矿石库.get(矿石ID, {})
			var 矿石名 = str(矿石.get("名称", "未知"))
			var 完成时间 = int(矿点.get("完成时间", 0))
			var 剩余 = 完成时间 - _当前天数
			if 剩余 <= 0:
				btn.text = "矿点%d\n%s\n✓可收获" % [(i + 1), 矿石名]
				btn.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
			else:
				btn.text = "矿点%d\n%s\n%d日后" % [(i + 1), 矿石名, 剩余]
		btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY * 1.8)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_secondary_button_style(btn)
		btn.pressed.connect(_on_矿脉矿点点击.bind(i))
		矿点grid.add_child(btn)
	# 可开采矿石列表
	var 矿石区: VBoxContainer = _add_section("选择矿石（选中后点击空闲矿点开采）")
	var 矿石grid := GridContainer.new()
	矿石grid.columns = 2
	矿石grid.add_theme_constant_override("h_separation", UITheme.GRID)
	矿石grid.add_theme_constant_override("v_separation", UITheme.GRID)
	矿石区.add_child(矿石grid)
	for oid in KuangMaiSystem.矿石库.keys():
		var 矿石 = KuangMaiSystem.矿石库[oid]
		var btn := Button.new()
		btn.text = "%s\n%s | %d日" % [str(矿石.get("名称","")), str(矿石.get("品阶","")), int(矿石.get("开采天数",1))]
		btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY * 1.5)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_secondary_button_style(btn)
		if _选中矿石 == oid:
			btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		btn.pressed.connect(_on_矿石选中.bind(oid))
		矿石grid.add_child(btn)
	# 操作提示
	var 提示label := Label.new()
	if _选中矿石 != "":
		var 矿石 = KuangMaiSystem.矿石库.get(_选中矿石, {})
		提示label.text = "已选中：%s，点击空闲矿点开始开采" % str(矿石.get("名称",""))
	else:
		提示label.text = "提示：先选择矿石，再点击空闲矿点开采；完成后点击矿点收获"
	UITheme.apply_aux_font(提示label)
	提示label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	_add_section("").add_child(提示label)

func _on_矿石选中(oid: String) -> void:
	_选中矿石 = oid
	_show_detail.call_deferred("kuangmai")

## 获取殿阁等级（从Game.司职列表动态读取）
func _获取殿阁等级(key: String) -> int:
	if Game == null or not is_instance_valid(Game):
		return 1
	var 列表 = Game.get("司职列表")
	if 列表 == null or not (列表 is Dictionary) or not 列表.has(key):
		return 1
	return int(列表[key].get("等级", 1))

## === 藏经阁：功法系统UI ===
var _选中功法: String = ""

func _build_cangjing_ui(藏经阁等级: int) -> void:
	# 悟道点余额
	var 余额区: VBoxContainer = _add_section("悟道点")
	var 余额label := Label.new()
	余额label.text = "当前悟道点：%d（每日产出+%d）" % [int(Game.悟道点), GongFaSystem.计算月产出(藏经阁等级)]
	余额label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	余额label.add_theme_font_size_override("font_size", 22)
	余额区.add_child(余额label)
	# 功法列表
	var 功法区: VBoxContainer = _add_section("功法秘录（选中后参悟学习）")
	var 功法grid := GridContainer.new()
	功法grid.columns = 2
	功法grid.add_theme_constant_override("h_separation", UITheme.GRID)
	功法grid.add_theme_constant_override("v_separation", UITheme.GRID)
	功法区.add_child(功法grid)
	for gid in GongFaSystem.功法库.keys():
		var 功法 = GongFaSystem.功法库[gid]
		var btn := Button.new()
		btn.text = "%s\n%s | %s" % [str(功法.get("名称","")), str(功法.get("品阶","")), str(功法.get("类型",""))]
		btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY * 1.5)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_secondary_button_style(btn)
		if _选中功法 == gid:
			btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		btn.pressed.connect(_on_功法选中.bind(gid))
		功法grid.add_child(btn)
	# 选中功法详情
	if _选中功法 != "":
		var 详情区: VBoxContainer = _add_section("功法详情")
		var 功法 = GongFaSystem.功法库.get(_选中功法, {})
		_add_kv_row(详情区, "功法", str(功法.get("名称","")))
		_add_kv_row(详情区, "品阶", str(功法.get("品阶","")))
		_add_kv_row(详情区, "类型", str(功法.get("类型","")))
		_add_kv_row(详情区, "修炼加成", "+%.0f%%" % (float(功法.get("修炼加成",0))*100))
		_add_kv_row(详情区, "战力加成", "+%d" % int(功法.get("战力加成",0)))
		_add_kv_row(详情区, "解锁境界", str(功法.get("解锁境界","练气")))
		_add_kv_row(详情区, "所需悟道点", "%d" % int(功法.get("所需悟道点",10)))
		_add_kv_row(详情区, "描述", str(功法.get("描述","")))
		# 参悟学习按钮
		var 学btn := Button.new()
		学btn.text = "参悟学习（消耗%d悟道点）" % int(功法.get("所需悟道点",10))
		学btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
		学btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_primary_button_style(学btn)
		学btn.pressed.connect(_on_参悟学习.bind(_选中功法))
		详情区.add_child(学btn)
	# 已学功法列表
	var 已学区: VBoxContainer = _add_section("弟子已学功法")
	var 弟子列表 = Game.get("弟子列表") if Game != null else null
	if 弟子列表 != null and 弟子列表.size() > 0:
		# 显示第一个弟子的已学功法（简化版本，后续可以添加弟子选择）
		var 目标弟子 = 弟子列表[0]
		if 目标弟子 != null:
			var 已学功法 = 目标弟子.get("已学功法", [])
			if 已学功法 == null or 已学功法.size() == 0:
				var empty := Label.new()
				empty.text = "尚无已学功法"
				UITheme.apply_aux_font(empty)
				已学区.add_child(empty)
			else:
				for 功法ID in 已学功法:
					var 已学功法信息 = GongFaSystem.功法库.get(功法ID, {})
					if 已学功法信息.is_empty():
						continue
					var 等级: int = GongFaSystem.获取功法等级(目标弟子, 功法ID)
					var 熟练度: int = GongFaSystem.获取功法熟练度(目标弟子, 功法ID)
					var 所需熟练度: int = 0
					if 等级 < GongFaSystem.功法升级熟练度.size():
						所需熟练度 = GongFaSystem.功法升级熟练度[等级]
					var 功法btn := Button.new()
					功法btn.text = "%s Lv.%d\n熟练度：%d/%d" % [str(已学功法信息.get("名称","")), 等级, 熟练度, 所需熟练度 if 等级 < GongFaSystem.功法等级上限 else "已满级"]
					功法btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY * 1.3)
					功法btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					UITheme.apply_secondary_button_style(功法btn)
					功法btn.pressed.connect(_on_遗忘功法.bind(功法ID))
					已学区.add_child(功法btn)
				# 提示
				var hint := Label.new()
				hint.text = "点击功法可遗忘（返还50%+悟道点）"
				UITheme.apply_aux_font(hint)
				hint.add_theme_color_override("font_color", UITheme.color_text_body_dim())
				已学区.add_child(hint)
	else:
		var empty := Label.new()
		empty.text = "尚无弟子"
		UITheme.apply_aux_font(empty)
		已学区.add_child(empty)

func _on_功法选中(gid: String) -> void:
	_选中功法 = gid
	_show_detail.call_deferred("cangjing")

func _on_遗忘功法(功法ID: String) -> void:
	# 查找第一个学习了此功法的弟子
	var 弟子列表 = Game.get("弟子列表") if Game != null else null
	if 弟子列表 == null or 弟子列表.size() == 0:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "尚无弟子")
		return
	var 目标弟子 = null
	for 弟子 in 弟子列表:
		if 弟子 == null:
			continue
		var 已学功法 = 弟子.get("已学功法", [])
		if 已学功法 != null and 已学功法.has(功法ID):
			目标弟子 = 弟子
			break
	if 目标弟子 == null:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "没有弟子学习此功法")
		return
	# 遗忘功法
	var 结果 = Game.遗忘功法(目标弟子, 功法ID) if Game != null and Game.has_method("遗忘功法") else GongFaSystem.遗忘功法(目标弟子, 功法ID)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "遗忘", str(结果.get("原因","")))
	_show_detail.call_deferred("cangjing")

func _on_参悟学习(功法ID: String) -> void:
	# 查找第一个符合条件的弟子
	var 弟子列表 = Game.get("弟子列表") if Game != null else null
	if 弟子列表 == null or 弟子列表.size() == 0:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "尚无弟子")
		return
	var 目标弟子 = null
	for 弟子 in 弟子列表:
		if 弟子 == null:
			continue
		var 检查 = GongFaSystem.可学习(弟子, 功法ID)
		if 检查.get("可学", false):
			目标弟子 = 弟子
			break
	if 目标弟子 == null:
		var 功法 = GongFaSystem.功法库.get(功法ID, {})
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "没有符合条件的弟子（需%s及以上）" % str(功法.get("解锁境界","练气")))
		return
	# 学习功法
	var 结果 = GongFaSystem.学习功法(目标弟子, 功法ID, int(Game.悟道点))
	if 结果.get("成功", false):
		Game.悟道点 -= int(结果.get("消耗", 0))
		# S1-2：学习新功法（玩家决策）。埋点放调用方，保持 gongfa.gd 纯数据层不依赖 Game
		Game.记任务进度("learn_gongfa")
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "参悟", str(结果.get("原因","")))
	_show_detail.call_deferred("cangjing")

## === 接引殿：新弟子招募UI ===
func _build_yuying_ui(接引殿等级: int) -> void:
	_当前天数 = Game.累计游戏日 if Game != null and "累计游戏日" in Game else 1
	var 招募信息 = RecruitSystem.招募弟子(接引殿等级)
	# 招募信息
	var 信息区: VBoxContainer = _add_section("接引招募")
	_add_kv_row(信息区, "接引殿等级", "Lv.%d" % 接引殿等级)
	_add_kv_row(信息区, "招募消耗", "%d灵石" % int(招募信息.get("消耗", 100)))
	_add_kv_row(信息区, "招募冷却", "%d日" % int(招募信息.get("冷却", 3)))
	_add_kv_row(信息区, "高品质加成", "+%.0f%%" % (float(招募信息.get("等级加成", 0))*100))
	# 招募按钮
	var 招btn := Button.new()
	var 冷却剩余 = int(Game.招募冷却剩余) if Game != null else 0
	if 冷却剩余 > 0:
		招btn.text = "招募气机未复（剩余%d日）" % 冷却剩余
		招btn.disabled = true
	else:
		招btn.text = "接引新弟子（消耗%d灵石）" % int(招募信息.get("消耗", 100))
		招btn.disabled = false
	招btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	招btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_primary_button_style(招btn)
	招btn.pressed.connect(_on_招募弟子.bind(接引殿等级))
	信息区.add_child(招btn)
	# 宗门弟子概览
	var 弟子列表 = Game.get("弟子列表") if Game != null else null
	var 弟子数 = 弟子列表.size() if 弟子列表 != null else 0
	var 概览区: VBoxContainer = _add_section("宗门弟子（共%d人）" % 弟子数)
	if 弟子数 == 0:
		var empty := Label.new()
		empty.text = "尚无弟子，去接引新弟子吧"
		UITheme.apply_aux_font(empty)
		概览区.add_child(empty)
	else:
		# 显示最近5个弟子
		var 显示数 = min(5, 弟子数)
		for i in range(弟子数 - 显示数, 弟子数):
			var 弟子 = 弟子列表[i]
			if 弟子 == null:
				continue
			var row := Label.new()
			row.text = "· %s | %s | %s | %s" % [str(弟子.姓名), str(弟子.资质), str(弟子.灵根), str(弟子.境界)]
			UITheme.apply_body_font(row)
			概览区.add_child(row)

func _on_招募弟子(接引殿等级: int) -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 招募信息 = RecruitSystem.招募弟子(接引殿等级)
	var 消耗 = int(招募信息.get("消耗", 100))
	if Game.灵石 < 消耗:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "灵石匮乏（需%d）" % 消耗)
		return
	# 消耗灵石
	Game.灵石 -= 消耗
	# 设置冷却
	Game.招募冷却剩余 = int(招募信息.get("冷却", 3))
	# 创建新弟子
	var 新弟子 = Disciple.new()
	# 加入宗门弟子列表
	if Game.has_method("添加弟子"):
		Game.添加弟子(新弟子)
	else:
		var 弟子列表 = Game.get("弟子列表")
		if 弟子列表 != null:
			弟子列表.append(新弟子)
		# P1-4：累计招募弟子数改接真实招募路径（原后端 招收弟子() 为零调用者死函数，成就永不可达；现 UI 真实招募处自增，成就于下次复检触发）
		Game.累计招募弟子数 += 1
	# S1-2：招募弟子（玩家决策，新手 newbie_001/newbie_007）
	#   埋点在 UI 层：后端 招收弟子()(game_state.gd:2966) 是零调用者死函数
	Game.记任务进度("recruit_count")
	var 提示 = "接引成功！新弟子：%s（%s/%s）" % [str(新弟子.姓名), str(新弟子.资质), str(新弟子.灵根)]
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "接引", 提示)
	_show_detail.call_deferred("yuying")

## === 洗池·灵泉：命格重铸UI ===
func _build_xichi_ui(洗池等级: int) -> void:
	var 信息区: VBoxContainer = _add_section("灵泉重铸")
	_add_kv_row(信息区, "洗池等级", "Lv.%d" % 洗池等级)
	_add_kv_row(信息区, "重铸消耗", "%d灵石" % XiChiSystem.重铸消耗(洗池等级))
	_add_kv_row(信息区, "重铸成功率", "%.0f%%" % (XiChiSystem.重铸成功率(洗池等级)*100))
	# 命格重铸按钮
	var btn1 := Button.new()
	btn1.text = "重铸命格（随机弟子）"
	btn1.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	btn1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_primary_button_style(btn1)
	btn1.pressed.connect(_on_重铸命格.bind(洗池等级))
	信息区.add_child(btn1)
	# 性格重铸按钮
	var btn2 := Button.new()
	btn2.text = "重铸性格（随机弟子）"
	btn2.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY)
	btn2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(btn2)
	btn2.pressed.connect(_on_重铸性格.bind(洗池等级))
	信息区.add_child(btn2)

func _on_重铸命格(洗池等级: int) -> void:
	var 弟子列表 = Game.get("弟子列表") if Game != null else null
	if 弟子列表 == null or 弟子列表.size() == 0:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "尚无弟子")
		return
	var 消耗 = XiChiSystem.重铸消耗(洗池等级)
	if Game.灵石 < 消耗:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "灵石匮乏（需%d）" % 消耗)
		return
	Game.灵石 -= 消耗
	var 目标弟子 = 弟子列表.pick_random()
	var 结果 = XiChiSystem.重铸命格(目标弟子, 洗池等级)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "命格重铸", "%s：%s" % [str(目标弟子.姓名), str(结果.get("原因",""))])
	_show_detail.call_deferred("xichi")

func _on_重铸性格(洗池等级: int) -> void:
	var 弟子列表 = Game.get("弟子列表") if Game != null else null
	if 弟子列表 == null or 弟子列表.size() == 0:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "尚无弟子")
		return
	var 消耗 = XiChiSystem.重铸消耗(洗池等级)
	if Game.灵石 < 消耗:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "灵石匮乏（需%d）" % 消耗)
		return
	Game.灵石 -= 消耗
	var 目标弟子 = 弟子列表.pick_random()
	var 结果 = XiChiSystem.重铸性格(目标弟子, 洗池等级)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "性格重铸", "%s：%s" % [str(目标弟子.姓名), str(结果.get("原因",""))])
	_show_detail.call_deferred("xichi")

## === 执法堂：门规纪律UI ===
func _build_zhifa_ui(执法堂等级: int) -> void:
	var 信息区: VBoxContainer = _add_section("门规戒律")
	_add_kv_row(信息区, "执法堂等级", "Lv.%d" % 执法堂等级)
	_add_kv_row(信息区, "当前贡献点", "%d" % int(Game.贡献点) if Game != null else "0")
	_add_kv_row(信息区, "月度贡献产出", "+%d/月" % (10 + max(0, 执法堂等级 - 1) * 5))
	# 月度结算按钮
	var btn := Button.new()
	btn.text = "月度结算（领取贡献点）"
	btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_primary_button_style(btn)
	btn.pressed.connect(_on_月度结算.bind(执法堂等级))
	信息区.add_child(btn)
	# 违纪类型说明
	var 违纪区: VBoxContainer = _add_section("违纪惩戒")
	for 类型 in ZhiFaSystem.违纪类型.keys():
		var 信息 = ZhiFaSystem.违纪类型[类型]
		var row := Label.new()
		row.text = "· %s：%s（扣贡献%d/灵石%d）" % [类型, str(信息.get("描述","")), int(信息.get("惩罚贡献",5)), int(信息.get("惩罚灵石",10))]
		row.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
		UITheme.apply_aux_font(row)
		违纪区.add_child(row)

func _on_月度结算(执法堂等级: int) -> void:
	var 结果 = ZhiFaSystem.月度结算(执法堂等级)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "月度结算", str(结果.get("原因","")))
	_show_detail.call_deferred("zhifa")

## === 功勋堂：功绩声望UI ===
func _build_gongxun_ui(功勋堂等级: int) -> void:
	var 信息区: VBoxContainer = _add_section("功绩声望")
	_add_kv_row(信息区, "功勋堂等级", "Lv.%d" % 功勋堂等级)
	_add_kv_row(信息区, "当前贡献点", "%d" % int(Game.贡献点) if Game != null else "0")
	_add_kv_row(信息区, "宗门声望", "随弟子功绩提升")
	# 兑换商店
	var 商店区: VBoxContainer = _add_section("贡献兑换")
	for 商品 in GongXunSystem.兑换商品:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_lbl := Label.new()
		name_lbl.text = str(商品.get("名称", ""))
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var cost_lbl := Label.new()
		cost_lbl.text = "%d贡献" % int(商品.get("消耗贡献", 0))
		cost_lbl.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
		cost_lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(cost_lbl)
		var buy_btn := Button.new()
		buy_btn.text = "兑换"
		buy_btn.custom_minimum_size = Vector2(80, 36)
		UITheme.apply_secondary_button_style(buy_btn)
		buy_btn.pressed.connect(_on_兑换商品.bind(str(商品.get("ID", ""))))
		row.add_child(buy_btn)
		商店区.add_child(row)

func _on_兑换商品(商品ID: String) -> void:
	var 结果 = GongXunSystem.兑换(商品ID)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "兑换", str(结果.get("原因","")))
	_show_detail.call_deferred("gongxun")

## === 阵法堂：护山大阵UI ===
func _build_zhenfa_ui(阵法堂等级: int) -> void:
	# 总效果显示
	var 效果区: VBoxContainer = _add_section("大阵总效果")
	var 总效果 = ZhenFaSystem.计算效果(Game.阵法等级) if Game != null else {"防御":0, "修炼":0, "产出":0}
	_add_kv_row(效果区, "阵法堂等级", "Lv.%d" % 阵法堂等级)
	_add_kv_row(效果区, "防御加成", "+%d" % int(总效果.get("防御", 0)))
	_add_kv_row(效果区, "修炼加成", "+%d%%" % int(总效果.get("修炼", 0)))
	_add_kv_row(效果区, "产出加成", "+%d%%" % int(总效果.get("产出", 0)))
	# 阵法列表
	var 阵法区: VBoxContainer = _add_section("阵法布置")
	for 阵法ID in ZhenFaSystem.阵法库.keys():
		var 阵法 = ZhenFaSystem.阵法库[阵法ID]
		var 解锁等级 = int(阵法.get("解锁等级", 1))
		var 当前等级 = int(Game.阵法等级.get(阵法ID, 0)) if Game != null else 0
		var 已解锁 = 阵法堂等级 >= 解锁等级
		# 阵法卡片
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, UITheme.GRID * 5)
		阵法区.add_child(card)
		var card_vb := VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 4)
		card.add_child(card_vb)
		# 名称行
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		var name_lbl := Label.new()
		name_lbl.text = "%s [%s]" % [str(阵法.get("名称","")), str(阵法.get("类型",""))]
		name_lbl.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60) if 已解锁 else Color(0.4, 0.4, 0.4))
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(name_lbl)
		var lv_lbl := Label.new()
		lv_lbl.text = "Lv.%d" % 当前等级 if 当前等级 > 0 else "未激活"
		lv_lbl.add_theme_color_override("font_color", Color(0.35, 0.68, 0.62) if 当前等级 > 0 else Color(0.5, 0.5, 0.5))
		lv_lbl.add_theme_font_size_override("font_size", 20)
		name_row.add_child(lv_lbl)
		card_vb.add_child(name_row)
		# 描述
		var desc_lbl := Label.new()
		desc_lbl.text = str(阵法.get("描述", ""))
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
		desc_lbl.add_theme_font_size_override("font_size", 16)
		card_vb.add_child(desc_lbl)
		# 效果
		if 当前等级 > 0:
			var effect_lbl := Label.new()
			var 防御 = int(阵法.get("基础防御",0)) + (当前等级-1)*int(阵法.get("每级防御",0))
			var 修炼 = int(阵法.get("基础修炼",0)) + (当前等级-1)*int(阵法.get("每级修炼",0))
			var 产出 = int(阵法.get("基础产出",0)) + (当前等级-1)*int(阵法.get("每级产出",0))
			var effect_text = "效果："
			if 防御 > 0: effect_text += "防御+%d " % 防御
			if 修炼 > 0: effect_text += "修炼+%d%% " % 修炼
			if 产出 > 0: effect_text += "产出+%d%% " % 产出
			effect_lbl.text = effect_text
			effect_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
			effect_lbl.add_theme_font_size_override("font_size", 16)
			card_vb.add_child(effect_lbl)
			# 耐久度显示
			var 最大耐久度: int = ZhenFaSystem.计算最大耐久度(当前等级)
			var 当前耐久度: int = int(Game.阵法耐久度.get(阵法ID, 最大耐久度)) if Game != null else 最大耐久度
			var dur_lbl := Label.new()
			var 耐久度颜色 = Color(0.6, 0.8, 0.6) if 当前耐久度 > 最大耐久度 * 0.5 else (Color(0.9, 0.7, 0.3) if 当前耐久度 > 最大耐久度 * 0.2 else Color(0.9, 0.4, 0.4))
			dur_lbl.text = "耐久度：%d/%d（%.0f%%）" % [当前耐久度, 最大耐久度, float(当前耐久度) / float(max(1, 最大耐久度)) * 100]
			dur_lbl.add_theme_color_override("font_color", 耐久度颜色)
			dur_lbl.add_theme_font_size_override("font_size", 16)
			card_vb.add_child(dur_lbl)
			# 修复按钮（耐久度不满时显示）
			if 当前耐久度 < 最大耐久度:
				var 修复消耗: int = ZhenFaSystem.计算修复消耗(当前耐久度, 最大耐久度)
				var repair_btn := Button.new()
				repair_btn.text = "修复阵法（消耗%d灵石）" % 修复消耗
				repair_btn.custom_minimum_size = Vector2(0, 36)
				repair_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				UITheme.apply_secondary_button_style(repair_btn)
				repair_btn.pressed.connect(_on_修复阵法.bind(阵法ID))
				card_vb.add_child(repair_btn)
		# 升级按钮
		if 已解锁:
			var 消耗 = ZhenFaSystem.获取升级消耗(阵法ID, 当前等级)
			var up_btn := Button.new()
			up_btn.text = "升级（消耗%d灵石）" % 消耗 if 当前等级 > 0 else "激活（消耗%d灵石）" % 消耗
			up_btn.custom_minimum_size = Vector2(0, 40)
			up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UITheme.apply_secondary_button_style(up_btn)
			up_btn.pressed.connect(_on_升级阵法.bind(阵法ID, 当前等级, 阵法堂等级))
			card_vb.add_child(up_btn)
		else:
			var lock_lbl := Label.new()
			lock_lbl.text = "🔒 需阵法堂Lv.%d解锁" % 解锁等级
			lock_lbl.add_theme_color_override("font_color", Color(0.6, 0.5, 0.3))
			lock_lbl.add_theme_font_size_override("font_size", 16)
			card_vb.add_child(lock_lbl)

func _on_升级阵法(阵法ID: String, 当前等级: int, 阵法堂等级: int) -> void:
	# 使用Game.升级阵法封装方法，自动更新等级和耐久度
	var 结果 = Game.升级阵法(阵法ID, 阵法堂等级) if Game != null and Game.has_method("升级阵法") else ZhenFaSystem.升级阵法(阵法ID, 当前等级, 阵法堂等级)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "阵法升级", str(结果.get("原因","")))
	_show_detail.call_deferred("zhenfa")

func _on_修复阵法(阵法ID: String) -> void:
	# 使用Game.修复阵法封装方法，自动更新耐久度
	var 结果 = Game.修复阵法(阵法ID) if Game != null and Game.has_method("修复阵法") else {"成功": false, "原因": "修复方法不存在"}
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "阵法修复", str(结果.get("原因","")))
	_show_detail.call_deferred("zhenfa")

## === 探微堂：藏宝图探查UI ===
func _build_tanwei_ui(探微堂等级: int) -> void:
	var 信息区: VBoxContainer = _add_section("江湖探查")
	_add_kv_row(信息区, "探微堂等级", "Lv.%d" % 探微堂等级)
	_add_kv_row(信息区, "探查范围", "方圆%d里" % (探微堂等级 * 100))
	_add_kv_row(信息区, "藏宝图", "可定向探查秘境")
	var btn := Button.new()
	btn.text = "随机探查（消耗50灵石）"
	btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_primary_button_style(btn)
	btn.pressed.connect(_on_随机探查.bind(探微堂等级))
	信息区.add_child(btn)

func _on_随机探查(探微堂等级: int) -> void:
	if Game == null:
		return
	if Game.灵石 < 50:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "灵石匮乏（需50）")
		return
	Game.灵石 -= 50
	# 随机探查结果
	var 结果池 = ["发现灵材×3", "发现矿石×2", "发现藏宝图碎片", "遇到散修，获得情报", "发现秘境入口", "一无所获"]
	var 结果 = 结果池.pick_random()
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "探查结果", 结果)
	_show_detail.call_deferred("tanwei")

func _on_矿脉矿点点击(矿点索引: int) -> void:
	if 矿点索引 < 0 or 矿点索引 >= Game.矿脉矿点.size():
		return
	var 矿点 = Game.矿脉矿点[矿点索引]
	var 状态 = str(矿点.get("状态", "空闲"))
	if 状态 == "空闲":
		# 开采
		if _选中矿石 == "":
			if UIHint != null and UIHint.has_method("show_hint"):
				UIHint.show_hint(null, "指点", "请先选择要开采的矿石")
			return
		var 矿脉等级 = _获取殿阁等级("kuangmai")
		var 结果 = KuangMaiSystem.开采(Game.矿脉矿点, 矿点索引, _选中矿石, _当前天数, 矿脉等级)
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "开采", str(结果.get("原因","")))
		_选中矿石 = ""
	elif 状态 == "开采中":
		# 收获（如果完成）
		if KuangMaiSystem.是否完成(矿点, _当前天数):
			var 矿脉等级 = _获取殿阁等级("kuangmai")
			var 结果 = KuangMaiSystem.收获(Game.矿脉矿点, 矿点索引, _当前天数, 矿脉等级)
			if 结果.get("成功", false):
				var 产出 = 结果.get("产出", null)
				var 数量 = int(结果.get("数量", 1))
				for n in range(数量):
					Game.仓库.append(产出.duplicate())
			if UIHint != null and UIHint.has_method("show_hint"):
				UIHint.show_hint(null, "收获", str(结果.get("原因","")))
		else:
			var 剩余 = int(矿点.get("完成时间", 0)) - _当前天数
			if UIHint != null and UIHint.has_method("show_hint"):
				UIHint.show_hint(null, "指点", "尚未完成，还需%d日" % 剩余)
	_show_detail.call_deferred("kuangmai")

func _on_任免_pressed(btn: Button, key: String) -> void:
	UITween.button_press(btn)
	_任免展开 = not _任免展开
	_任免_key = key
	# 延后重建详情子树：pressed 回调内同步重建会释放当前按钮节点导致崩溃（同 _yushou_重绘 手法）。
	_show_detail.call_deferred(key)

# 殿阁详情内联「任免主事」选择器：复用御兽堂引育预设选择器的内联范式（不弹窗、随 ScrollVBox 滚动）。
# 列出全部弟子，点击即 Game.任命负责人(key, d)；阶位门槛由 Game 内部闸判定，不足则返回 false 并提示。
func _任免选择器(parent: Control, key: String) -> void:
	var 提示 := Label.new()
	提示.text = "选择新主事（点击任命；再点「任免主事」收起）"
	提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	提示.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_aux_text(提示)
	parent.add_child(提示)
	var 列表 = Game.get("弟子列表")
	if 列表 == null or not (列表 is Array) or 列表.is_empty():
		var 空 := Label.new()
		空.text = "尚无弟子可任"
		UITheme.apply_aux_text(空)
		parent.add_child(空)
		return
	for d in 列表:
		if d == null or not (d is Object):
			continue
		var b := Button.new()
		b.text = "%s（%s）" % [str(_safe_get(d, "姓名", "—")), str(_safe_get(d, "阶位", "—"))]
		b.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		UITheme.apply_secondary_button_style(b)
		b.pressed.connect(_on_任免_确认.bind(d, key))
		parent.add_child(b)

func _on_任免_确认(d: Disciple, key: String) -> void:
	if not is_instance_valid(Game) or not Game.has_method("任命负责人"):
		_toast("任命受阻：功法未就绪。")
		return
	var r = Game.任命负责人(key, d)
	if r == false:
		_toast("%s 阶位不足，无法担任此职。" % str(_safe_get(d, "姓名", "—")))
	else:
		_toast("%s 已被任命为主事。" % str(_safe_get(d, "姓名", "—")))
	_任免展开 = false
	_show_detail.call_deferred(key)

func _toast(文本: String) -> void:
	if is_instance_valid(Game) and Game.has_method("toast"):
		Game.toast(文本)

func _on_lock_pressed(btn: Button) -> void:
	UITween.button_press(btn)

func _on_lock_toggled(开启: bool, key: String) -> void:
	if not is_instance_valid(Game):
		_toast("气机紊乱：功法未就绪。")
		return
	var 列表 = Game.get("司职列表")
	var 堂: Dictionary = (列表.get(key, {}) if (列表 is Dictionary) else {})
	if not 开启:
		# 单向解锁（Game 仅暴露 解除负责人锁定；锁定由任命隐含置位）
		if Game.has_method("解除负责人锁定"):
			Game.解除负责人锁定(key)
			_toast("已解除主事锁定。")
		else:
			_toast("气机紊乱：数据层缺 解除负责人锁定()。")
	else:
		# 锁定 = 对现任主事再任命（任命即置 负责人锁定=true）；已锁定则跳过，避免重复写纪事。
		var 已锁定: bool = bool(堂.get("负责人锁定", false))
		var 现任 = _safe_get(堂, "负责人", null)
		if 已锁定:
			pass
		elif 现任 != null and Game.has_method("任命负责人"):
			Game.任命负责人(key, 现任 as Disciple)
			_toast("已锁定主事。")
		elif 现任 == null:
			_toast("无主事可锁定。")
		else:
			_toast("气机紊乱：数据层缺 任命负责人()。")
	_show_detail.call_deferred(key)

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



# S1-4 付费：仙玉立即孵化灵兽（调用 Game._pay_reserved_灵兽加成）
func _on_付费_灵兽(_btn: Button = null) -> void:
	if not is_instance_valid(Game):
		return
	var r: Dictionary = Game._pay_reserved_灵兽加成()
	if r.get("成功", false):
		var n: int = int(r.get("完成数", 0))
		UIHint.show_hint(self, "灵兽孵化完成", "立即完成 %d 只孵化中灵兽" % n)
	else:
		UIHint.show_hint(self, "仙玉匮乏", str(r.get("原因", "")))
	refresh()

# S1-4 付费：仙玉立即领取殿阁产出（调用 Game._pay_reserved_殿阁加成）
func _on_付费_殿阁() -> void:
	if not is_instance_valid(Game):
		return
	var r: Dictionary = Game._pay_reserved_殿阁加成()
	if r.get("成功", false):
		UIHint.show_hint(self, "殿阁产出", "立即领取预估日产出灵石 %d" % int(r.get("额", 0)))
	else:
		UIHint.show_hint(self, "仙玉匮乏", str(r.get("原因", "")))
	refresh()





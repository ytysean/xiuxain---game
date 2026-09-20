extends Control

# ===== S58-P3 世界地图可视化（深度版） =====
# 五大功能：迷雾探索、地形系统、资源点采集、大地图事件、军队移动动画
# 美术落地：色块+几何图形，预留资源替换接口


# 地图配置
# 2026-09-14 无缝大地图 MVP：画布 2000² → 4000²（给内容扩展留空间）。
# 「世界看起来多大」由 世界映射系数 决定；逻辑坐标（world_map_system，±200 域内）保持不变
# ⇒ 商队运输 / 行军 / 被劫风险 / 资源衰减等平衡公式零适配，存档零迁移。
const 地图宽度: float = 4000.0
const 地图高度: float = 4000.0
const 世界映射系数: float = 2.4   # 逻辑坐标 → 视觉坐标（尺度问题只关在渲染层）
const 最小缩放: float = 0.3       # 绝对下限（实际下限由「视口覆盖法」动态抬高）
const 最大缩放: float = 2.0
const 缩放速度: float = 0.1
const 迷雾网格大小: float = 200.0  # 迷雾网格（视觉单位；4000/200 = 20×20 = 400 格）
const 拖动惯性衰减: float = 0.02   # 惯性：每秒末速度衰减至 2%

# 区域颜色
const 区域颜色: Dictionary = {
	"中州": Color(0.85, 0.75, 0.55, 0.6),
	"东域": Color(0.4, 0.6, 0.8, 0.6),
	"西域": Color(0.75, 0.65, 0.45, 0.6),
	"南疆": Color(0.45, 0.65, 0.45, 0.6),
	"北域": Color(0.7, 0.8, 0.9, 0.6),
}

# 地点类型
# 图标 = art/icons/emoji/ 资产 stem（ASCII）。此处原为 emoji 字符，批量字符清扫时
# 被塌成同一符号 ⇒ 九种地点标记长得一模一样，且查表落空只剩裸字符。
const 地点类型: Dictionary = {
	"宗门": {"颜色": Color(0.9, 0.3, 0.3), "大小": 16, "图标": "emoji_world_city"},
	"城镇": {"颜色": Color(0.3, 0.6, 0.9), "大小": 12, "图标": "emoji_world_village"},
	"秘境": {"颜色": Color(0.8, 0.4, 0.9), "大小": 14, "图标": "emoji_disciple_special"},
	"灵脉": {"颜色": Color(0.4, 0.9, 0.6), "大小": 10, "图标": "emoji_world_gem"},
	"妖兽领": {"颜色": Color(0.9, 0.5, 0.2), "大小": 12, "图标": "emoji_world_beast"},
	"矿脉": {"颜色": Color(0.7, 0.7, 0.3), "大小": 10, "图标": "emoji_world_mine"},
	"灵草丛": {"颜色": Color(0.3, 0.8, 0.4), "大小": 10, "图标": "emoji_world_herb"},
	"灵泉": {"颜色": Color(0.4, 0.85, 0.9), "大小": 11, "图标": "emoji_world_location"},
	"钓点": {"颜色": Color(0.35, 0.75, 0.85), "大小": 11, "图标": "emoji_world_fish"},
}

# 地形类型
const 地形类型: Dictionary = {
	"平原": {"颜色": Color(0.6, 0.8, 0.5, 0.3), "速度": 1.0, "可通行": true},
	"森林": {"颜色": Color(0.2, 0.5, 0.2, 0.4), "速度": 0.7, "可通行": true},
	"山脉": {"颜色": Color(0.5, 0.45, 0.4, 0.6), "速度": 0.3, "可通行": false},
	"河流": {"颜色": Color(0.2, 0.4, 0.8, 0.5), "速度": 0.5, "可通行": true},
	"沙漠": {"颜色": Color(0.85, 0.75, 0.45, 0.4), "速度": 0.8, "可通行": true},
	"冰原": {"颜色": Color(0.8, 0.9, 1.0, 0.4), "速度": 0.6, "可通行": true},
}

# 大地图事件库
const 事件库: Array = [
	{"名": "妖兽袭击", "描述": "前方妖兽出没，似有妖王坐镇。", "类型": "战斗", "奖励": "妖兽材料"},
	{"名": "商队求救", "描述": "一支商队被山匪围困，呼救声隐约可闻。", "类型": "选择", "奖励": "声望/灵石"},
	{"名": "秘境入口", "描述": "山间隐现灵光，似有上古秘境封印松动。", "类型": "探索", "奖励": "功法/材料"},
	{"名": "散修遗府", "描述": "发现一座散修坐化遗府，禁制尚存。", "类型": "探索", "奖励": "灵石/丹药"},
	{"名": "灵泉眼", "描述": "密林深处灵气汇聚，竟是一眼灵泉。", "类型": "采集", "奖励": "灵气"},
	{"名": "路遇同道", "描述": "偶遇游历散修，相谈甚欢。", "类型": "社交", "奖励": "声望/功法"},
	{"名": "邪修踪迹", "描述": "发现邪修祭炼生魂的痕迹，煞气冲天。", "类型": "战斗", "奖励": "功德/材料"},
	{"名": "古战场", "描述": "此地曾是上古战场，阴气缭绕，偶有残兵怨灵。", "类型": "探索", "奖励": "法器/材料"},
]

# 状态变量
var _地图容器: Control = null
var _地图层: Control = null
var _迷雾层: Control = null
var _缩放: float = 0.5
var _偏移: Vector2 = Vector2.ZERO
var _拖动中: bool = false
var _上次鼠标位置: Vector2 = Vector2.ZERO
var _地点标记: Array = []
var _详情面板: PanelContainer = null
var _拖动速度: Vector2 = Vector2.ZERO   # 平移惯性速度（松手后按 拖动惯性衰减 滑行）
var _迷雾图: Image = null               # 2026-09-14：迷雾遮罩位图（20×20，1 px = 1 格）
var _迷雾遮罩: ImageTexture = null      # 由 _迷雾图 生成，供单个 TextureRect 铺满画布
var _移动中队伍: Array = []
var _事件面板: PanelContainer = null
var _资源冷却: Dictionary = {}
var _地形数据: Array = []
var _舆图总览: Control = null   # B6：互补视图（区域特性/周边城镇/宗门迁移）

func _ready() -> void:
	_build_ui()
	_生成地形数据()
	_生成地图内容()
	_生成迷雾()
	_每日刷新()
	# 初始揭示：宗门左近一圈 + 宗门所在整域（你自然知晓本域）
	# 2026-09-14 实机验收：原半径 420 只揭 80/400 格（20%），首屏仍偏空；提到 520 ⇒ 约 113 格（28%）。
	var 宗门位置: Dictionary = Game.世界地图系统.获取宗门位置()
	var 宗门视: Vector2 = _域内转视觉(str(宗门位置["区域"]), float(宗门位置["x"]), float(宗门位置["y"]))
	_探索区域(宗门视.x, 宗门视.y, 520.0 * 世界映射系数)
	_揭示区域(str(Game.世界地图系统.宗门区域))
	# _ready 时视口 size 尚未解析 → 等一帧再定位 / 装边界约束
	await get_tree().process_frame
	_定位到宗门()
	resized.connect(_on_视口变化)

func _process(delta: float) -> void:
	_更新移动中队伍(delta)
	_推进平移惯性(delta)

# ===== 坐标双轨（本方案技术核心）=====
# 逻辑坐标（玩法权威，±200 域内不变）↔ 视觉坐标（渲染层，可任意放大）。
# 玩法看逻辑，好看靠映射：想「世界更大」只调 世界映射系数 / 画布，绝不碰逻辑坐标。
func _逻辑转视觉(lx: float, ly: float) -> Vector2:
	return Vector2(lx, ly) * 世界映射系数 + Vector2(地图宽度 / 2.0, 地图高度 / 2.0)

func _视觉转逻辑(vx: float, vy: float) -> Vector2:
	return (Vector2(vx, vy) - Vector2(地图宽度 / 2.0, 地图高度 / 2.0)) / 世界映射系数

# 「域内口径」点位 → 视觉坐标（2026-09-14 修）
# 背景：工程里并存两套逻辑口径，渲染层只认全局口径，此前却把两者一锅端地送进 _逻辑转视觉，
#   于是 21 个模拟宗门 + 12 个城镇 + 玩家宗门（全是域内 ±200）统统落在中州板上 —— 中州挤爆、
#   其余四域几乎空着，直接抵消了「内容密度」的观感。
# 凡 点位数据里带「区域」字段的（城镇/模拟宗门/玩家宗门），都要走本函数而非 _逻辑转视觉。
# 注：区域秘境 / 资源点 / 钓点 本就存全局口径，仍直接走 _逻辑转视觉。
func _域内转视觉(域: String, lx: float, ly: float) -> Vector2:
	var 全局: Vector2 = Game.世界地图系统.域内坐标转全局(域, lx, ly)
	return _逻辑转视觉(全局.x, 全局.y)

# 平移惯性：松手后按衰减滑行（"硬拖"→"顺滑"，无缝观感的一部分）
func _推进平移惯性(delta: float) -> void:
	if _拖动中:
		return
	if _拖动速度.length() < 1.0:
		_拖动速度 = Vector2.ZERO
		return
	# 2026-09-14 实机修：原 `_偏移 += _拖动速度` 未乘 delta ⇒ 帧率依赖。
	# 实测窗口 ~250fps 下每帧仅衰减 1.5%，滑行总里程约为 60fps 目标的 5 倍。
	# 以 60fps 为基准归一化后，滑动手感与帧率解耦。
	_偏移 += _拖动速度 * delta * 60.0
	_拖动速度 *= pow(拖动惯性衰减, max(delta, 0.0001))
	_更新地图变换()

func _build_ui() -> void:
	# 背景
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.086, 0.125, 0.141, 1.00)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 顶部标题栏
	var header: HBoxContainer = HBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 12
	header.offset_right = -12
	header.offset_top = 8
	header.offset_bottom = 44
	header.add_theme_constant_override("separation", 8)
	add_child(header)

	var title: Label = Label.new()
	title.text = "天下舆图"
	UITheme.apply_project_font(title, UITheme.FONT_H1, true)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	header.add_child(title)

	header.add_spacer(false)

	# ★ 2026-09-16 修（顶栏挤压 · 实机截图抓出）：原实现把 9 个控件全塞进这一条 HBox
	#   （标题 + −/%/+ + 宗门 + 舆图总览 + 天下 + ◇），固定宽合计 436 逻辑，
	#   而可用宽只有 480 − 左右留白 24 = 456 ⇒ 标题「天下舆图」被压到约 20 逻辑宽，
	#   实机上四个字竖排并与右侧按钮重叠。
	#   按地图类 App 惯例重排：**缩放控件下沉为地图区右下悬浮条**（贴近地图、拇指可及），
	#   顶栏只留「标题 + 三个入口 + 关闭」⇒ 标题恢复完整可读。
	#   （缩放三件套的新位置见下方 ZoomBar）

	var 定位钮: Button = Button.new()
	定位钮.text = "宗门"
	定位钮.custom_minimum_size = Vector2(70, 32)
	UITheme.apply_secondary_button_style(定位钮)
	定位钮.pressed.connect(_定位到宗门)
	header.add_child(定位钮)

	# B6：舆图总览（列表版）—— 承载「区域特性 / 周边城镇 / 宗门迁移」，
	# 与可视版（探索/迷雾/行军）互补；列表版曾为孤儿页，此处为其唯一入口。
	var 总览钮: Button = Button.new()
	总览钮.text = "舆图总览"
	总览钮.custom_minimum_size = Vector2(84, 32)
	UITheme.apply_secondary_button_style(总览钮)
	总览钮.pressed.connect(_打开舆图总览)
	header.add_child(总览钮)

	# 任务#004：天下总览（事件/资源/钓点/妖兽/弟子派遣 一屏汇总）
	var 天下钮: Button = Button.new()
	天下钮.text = "天下"
	天下钮.custom_minimum_size = Vector2(60, 32)
	UITheme.apply_secondary_button_style(天下钮)
	天下钮.pressed.connect(_打开天下总览)
	header.add_child(天下钮)

	var close_btn: Button = Button.new()
	close_btn.text = "◇"
	close_btn.custom_minimum_size = Vector2(36, 32)
	UITheme.apply_secondary_button_style(close_btn)
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# 地图视口
	var viewport: Control = Control.new()
	viewport.name = "MapViewport"
	viewport.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.offset_top = 48
	viewport.offset_bottom = -60
	viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	# 必须裁剪：缩放/定位会让 MapLayer（4000² 画布）越出视口矩形，溢出内容会盖住
	# 页面顶部自建标题栏（实测 header 整排不可见、仅右上 ◇ 残 4px），顶部只剩一条空绿带。
	viewport.clip_contents = true
	add_child(viewport)
	_地图容器 = viewport

	# 缩放悬浮条（顶栏重排的落点）：地图区右下角，既不压底部图例（y ≥ H−52），
	# 也不与顶栏争宽。玻璃质感底板 + 圆角，贴合「操作＝玻璃 dock」的 UI 口径。
	var 缩放条: PanelContainer = PanelContainer.new()
	缩放条.name = "ZoomBar"
	缩放条.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	缩放条.offset_left = -168
	缩放条.offset_top = -110
	缩放条.offset_right = -12
	缩放条.offset_bottom = -66
	var 条底: StyleBoxFlat = StyleBoxFlat.new()
	条底.bg_color = Color(0.086, 0.125, 0.141, 0.82)
	条底.border_color = Color(0.910, 0.773, 0.447, 0.28)
	条底.set_border_width_all(1)
	条底.set_corner_radius_all(18)
	条底.content_margin_left = 8
	条底.content_margin_right = 8
	条底.content_margin_top = 4
	条底.content_margin_bottom = 4
	缩放条.add_theme_stylebox_override("panel", 条底)
	add_child(缩放条)

	var 条行: HBoxContainer = HBoxContainer.new()
	条行.add_theme_constant_override("separation", 6)
	缩放条.add_child(条行)

	var zoom_out: Button = Button.new()
	zoom_out.text = "−"
	zoom_out.custom_minimum_size = Vector2(40, 32)
	UITheme.apply_secondary_button_style(zoom_out)
	zoom_out.pressed.connect(func(): _调整缩放(-缩放速度))
	条行.add_child(zoom_out)

	var zoom_label: Label = Label.new()
	zoom_label.text = "%d%%" % int(_缩放 * 100)
	zoom_label.name = "ZoomLabel"
	zoom_label.custom_minimum_size = Vector2(56, 0)
	UITheme.apply_project_font(zoom_label, UITheme.FONT_BODY, false)
	zoom_label.add_theme_color_override("font_color", UITheme.获取次文字色())
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	条行.add_child(zoom_label)

	var zoom_in: Button = Button.new()
	zoom_in.text = "+"
	zoom_in.custom_minimum_size = Vector2(40, 32)
	UITheme.apply_secondary_button_style(zoom_in)
	zoom_in.pressed.connect(func(): _调整缩放(缩放速度))
	条行.add_child(zoom_in)

	# 地图层
	_地图层 = Control.new()
	_地图层.name = "MapLayer"
	_地图层.custom_minimum_size = Vector2(地图宽度, 地图高度)
	_地图层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(_地图层)

	# 迷雾层（在地图层之上）
	_迷雾层 = Control.new()
	_迷雾层.name = "FogLayer"
	_迷雾层.custom_minimum_size = Vector2(地图宽度, 地图高度)
	_迷雾层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(_迷雾层)

	# 边界柔化：四边云雾渐隐（贴视口边缘、不随地图缩放），让「到边了」看起来像「云深处」
	_建边界渐隐(viewport)

	# 底部图例
	# ★ 2026-09-16 修（实机截图抓出 · 真缺陷）：原用 HBoxContainer，每项 = 10px 直角色块 + 正文，
	#   9 项固定宽合计 ≈850 逻辑 > 可用宽 456 ⇒ **HBox 不折行，后 4 项（灵草丛/妖兽领/灵泉/钓点）
	#   被直接裁出屏幕**，玩家看不到完整图例。
	#   改用 HFlowContainer（自动折行，永不裁切）+ 辅助字号 + 圆点标记（原直角色块在小尺寸下粗糙）。
	var legend: HFlowContainer = HFlowContainer.new()
	legend.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_left = 12
	legend.offset_right = -12
	legend.offset_top = -66
	legend.offset_bottom = -6
	legend.add_theme_constant_override("h_separation", 12)
	legend.add_theme_constant_override("v_separation", 6)
	add_child(legend)

	for 类型 in ["宗门", "城镇", "秘境", "灵脉", "矿脉", "灵草丛", "妖兽领", "灵泉", "钓点"]:
		# 防御：图例与 地点类型 表若失配，宁可少画一个图例，也不能让 _build_ui 中断
		# （2026-09-14 实机踩到：补「灵泉」图例时该键在 地点类型 缺失 → 本函数中断 ⇒
		#   其后创建的 详情面板/事件面板 与 viewport.gui_input 连接全部未执行 ⇒ 拖拽整个失效，
		#   而门禁 PARSE/gate_all 全绿，因为这是运行时字典缺键、不是语法错。）
		if not 地点类型.has(类型):
			continue
		var cfg: Dictionary = 地点类型[类型]
		var item: HBoxContainer = HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		legend.add_child(item)
		var dot: Panel = Panel.new()
		var dsb: StyleBoxFlat = StyleBoxFlat.new()
		dsb.bg_color = cfg["颜色"]
		dsb.set_corner_radius_all(5)
		dsb.border_color = Color(1, 1, 1, 0.35)
		dsb.set_border_width_all(1)
		dot.add_theme_stylebox_override("panel", dsb)
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(dot)
		var label: Label = Label.new()
		label.text = 类型
		UITheme.apply_aux_font(label)
		label.add_theme_color_override("font_color", UITheme.获取次文字色())
		item.add_child(label)

	# 详情面板
	_详情面板 = PanelContainer.new()
	_详情面板.name = "DetailPanel"
	_详情面板.visible = false
	_详情面板.custom_minimum_size = Vector2(280, 0)
	_详情面板.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_详情面板.offset_left = -300
	_详情面板.offset_right = -12
	_详情面板.offset_top = 56
	var 详情板: StyleBoxFlat = StyleBoxFlat.new()
	详情板.bg_color = UITheme.获取面板底色()
	详情板.border_color = Color(0.910, 0.773, 0.447, 0.28)
	详情板.set_border_width_all(1)
	详情板.set_corner_radius_all(12)
	_详情面板.add_theme_stylebox_override("panel", 详情板)
	add_child(_详情面板)

	# 事件面板
	_事件面板 = PanelContainer.new()
	_事件面板.name = "EventPanel"
	_事件面板.visible = false
	_事件面板.custom_minimum_size = Vector2(320, 0)
	_事件面板.set_anchors_preset(Control.PRESET_CENTER)
	_事件面板.offset_left = -160
	_事件面板.offset_right = 160
	_事件面板.offset_top = -100
	_事件面板.offset_bottom = 100
	var 事件板: StyleBoxFlat = StyleBoxFlat.new()
	事件板.bg_color = UITheme.获取面板底色()
	事件板.border_color = Color(0.910, 0.773, 0.447, 0.28)
	事件板.set_border_width_all(1)
	事件板.set_corner_radius_all(12)
	_事件面板.add_theme_stylebox_override("panel", 事件板)
	add_child(_事件面板)

	viewport.gui_input.connect(_on_地图输入)

# ===== 边界柔化（无缝观感）=====
# 四边云雾渐隐带：贴视口边缘、屏幕空间、不随地图缩放。
# 基色取 UITheme 场景压暗色（深墨），使边界"消散成云"，而非一条硬边。
func _建边界渐隐(父: Control) -> void:
	var 带: int = UITheme.边界渐隐带宽
	var 顶: TextureRect = _建渐隐条("顶")
	顶.set_anchors_preset(Control.PRESET_TOP_WIDE)
	顶.offset_top = 0
	顶.offset_bottom = 带
	父.add_child(顶)
	var 底: TextureRect = _建渐隐条("底")
	底.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	底.offset_top = -带
	底.offset_bottom = 0
	父.add_child(底)
	var 左: TextureRect = _建渐隐条("左")
	左.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	左.offset_left = 0
	左.offset_right = 带
	父.add_child(左)
	var 右: TextureRect = _建渐隐条("右")
	右.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	右.offset_left = -带
	右.offset_right = 0
	父.add_child(右)

func _建渐隐条(朝向: String) -> TextureRect:
	var 近: Color = UITheme.获取边界渐隐色(0.92)
	var 远: Color = UITheme.获取边界渐隐色(0.0)
	var g: Gradient = Gradient.new()
	g.set_color(0, 近)
	g.set_color(1, 远)
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.width = 8
	t.height = max(8, UITheme.边界渐隐带宽)
	match 朝向:
		"顶":
			t.fill_from = Vector2(0, 0)
			t.fill_to = Vector2(0, 1)
		"底":
			t.fill_from = Vector2(0, 1)
			t.fill_to = Vector2(0, 0)
		"左":
			t.fill_from = Vector2(0, 0)
			t.fill_to = Vector2(1, 0)
		"右":
			t.fill_from = Vector2(1, 0)
			t.fill_to = Vector2(0, 0)
	var tr: TextureRect = TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

# ===== 地形系统 =====
func _生成地形数据() -> void:
	# 随机生成地形斑块（简化版，后续可用噪声）
	_地形数据.clear()
	# 生成几条山脉
	for i in range(5):
		var x: float = randf_range(200, 地图宽度 - 200)
		var y: float = randf_range(200, 地图高度 - 200)
		for j in range(8):
			_地形数据.append({"类型": "山脉", "x": x + randf_range(-100, 100), "y": y + randf_range(-100, 100), "大小": randf_range(40, 80)})
	# 生成几条河流
	for i in range(3):
		var start_x: float = randf_range(100, 地图宽度 - 100)
		var start_y: float = randf_range(100, 地图高度 - 100)
		for j in range(15):
			_地形数据.append({"类型": "河流", "x": start_x + j * 30 + randf_range(-20, 20), "y": start_y + j * 20 + randf_range(-20, 20), "大小": randf_range(25, 40)})
	# 生成森林
	for i in range(8):
		_地形数据.append({"类型": "森林", "x": randf_range(100, 地图宽度 - 100), "y": randf_range(100, 地图高度 - 100), "大小": randf_range(60, 120)})

func _绘制地形() -> void:
	for 地形 in _地形数据:
		var cfg: Dictionary = 地形类型[地形["类型"]]
		var 尺寸: float = float(地形["大小"])
		var 位置: Vector2 = Vector2(float(地形["x"]) - 尺寸 / 2, float(地形["y"]) - 尺寸 / 2)
		# 2026-09-14 实机清理：原先此处先 new 一个永不入树的 ColorRect（死节点），已删。
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = cfg["颜色"]
		style.corner_radius_top_left = int(尺寸 / 2)
		style.corner_radius_top_right = int(尺寸 / 2)
		style.corner_radius_bottom_left = int(尺寸 / 2)
		style.corner_radius_bottom_right = int(尺寸 / 2)
		var panel: PanelContainer = PanelContainer.new()
		panel.position = 位置
		panel.size = Vector2(尺寸, 尺寸)
		panel.add_theme_stylebox_override("panel", style)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_地图层.add_child(panel)

# ===== 迷雾探索系统 =====
# 迷雾格持久化在 world_map_system.已探索网格（存档），不再随页面重建清零。
# 2026-09-14 实机验收改版：由「每格一个 201px ColorRect」改为「单张 20×20 遮罩纹理」。
#   旧法两个实机缺陷：① 400 个色块在非整数缩放下相邻边出现规则网格缝（截图可见，像渲染破损）；
#                      ② 400 个节点全部参与缩放变换。
#   改后：1 个节点、零接缝，且 LINEAR 过滤让「已探索↔未探索」边界自带云雾过渡。
func _生成迷雾() -> void:
	# 清除旧迷雾
	for child in _迷雾层.get_children():
		child.queue_free()
	var cols: int = int(地图宽度 / 迷雾网格大小)
	var rows: int = int(地图高度 / 迷雾网格大小)
	var 已探索: Dictionary = Game.世界地图系统.已探索网格
	var 色: Color = UITheme.获取迷雾色()
	_迷雾图 = Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	for j in range(rows):
		for i in range(cols):
			var a: float = 0.0 if 已探索.has("%d_%d" % [i, j]) else 色.a
			_迷雾图.set_pixel(i, j, Color(色.r, 色.g, 色.b, a))
	_迷雾遮罩 = ImageTexture.create_from_image(_迷雾图)
	var tr: TextureRect = TextureRect.new()
	tr.name = "FogMask"
	tr.texture = _迷雾遮罩
	tr.position = Vector2.ZERO
	tr.size = Vector2(地图宽度, 地图高度)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_迷雾层.add_child(tr)

# 置单格为「已探索」（只改位图；批量改完由 _刷迷雾纹理 统一回传，避免逐格 update 开销）
func _设迷雾已探(i: int, j: int) -> void:
	if _迷雾图 == null:
		return
	if i < 0 or j < 0 or i >= _迷雾图.get_width() or j >= _迷雾图.get_height():
		return
	var 色: Color = UITheme.获取迷雾色()
	_迷雾图.set_pixel(i, j, Color(色.r, 色.g, 色.b, 0.0))

func _刷迷雾纹理() -> void:
	if _迷雾遮罩 != null and _迷雾图 != null:
		_迷雾遮罩.update(_迷雾图)

func _探索区域(中心x: float, 中心y: float, 半径: float) -> void:
	var 已探索: Dictionary = Game.世界地图系统.已探索网格
	var cols: int = int(地图宽度 / 迷雾网格大小)
	var rows: int = int(地图高度 / 迷雾网格大小)
	for i in range(cols):
		for j in range(rows):
			var cell_x: float = i * 迷雾网格大小 + 迷雾网格大小 / 2
			var cell_y: float = j * 迷雾网格大小 + 迷雾网格大小 / 2
			var dist: float = sqrt((cell_x - 中心x) * (cell_x - 中心x) + (cell_y - 中心y) * (cell_y - 中心y))
			if dist <= 半径:
				var key: String = "%d_%d" % [i, j]
				if not 已探索.has(key):
					已探索[key] = true
					_设迷雾已探(i, j)
	_刷迷雾纹理()

# 揭示整片语义区域（首建时揭示宗门所在域 —— 你自然知晓本域的格局）
func _揭示区域(区域名: String) -> void:
	var 范围表: Dictionary = Game.世界地图系统.区域逻辑范围
	if not 范围表.has(区域名):
		return
	var 范围: Dictionary = 范围表[区域名]
	_揭示矩形(_逻辑转视觉(float(范围["x1"]), float(范围["y1"])), _逻辑转视觉(float(范围["x2"]), float(范围["y2"])))

# 按视觉矩形（左上/右下）揭示迷雾格
func _揭示矩形(左上: Vector2, 右下: Vector2) -> void:
	var 已探索: Dictionary = Game.世界地图系统.已探索网格
	var cols: int = int(地图宽度 / 迷雾网格大小)
	var rows: int = int(地图高度 / 迷雾网格大小)
	for i in range(cols):
		var cx: float = i * 迷雾网格大小 + 迷雾网格大小 / 2
		if cx < 左上.x or cx > 右下.x:
			continue
		for j in range(rows):
			var cy: float = j * 迷雾网格大小 + 迷雾网格大小 / 2
			if cy < 左上.y or cy > 右下.y:
				continue
			var key: String = "%d_%d" % [i, j]
			if not 已探索.has(key):
				已探索[key] = true
				_设迷雾已探(i, j)
	_刷迷雾纹理()

# ===== 地图内容生成 =====
func _生成地图内容() -> void:
	_绘制画布底()
	_绘制区域背景()
	_绘制装饰填充()
	_绘制地形()
	_生成地点标记()

# 画布底：4000² 画布远大于五域占位，外围原本无任何绘制 ⇒ 实机呈大面积纯黑（像没渲染完）。
# 铺一层水墨夜深底，未探索区变「沉色」而非「黑洞」，边界渐隐带也有了对齐的基色。
func _绘制画布底() -> void:
	var 底: ColorRect = ColorRect.new()
	底.color = UITheme.获取地图底色()
	底.position = Vector2.ZERO
	底.size = Vector2(地图宽度, 地图高度)
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_地图层.add_child(底)

# 区域底板：语义层 区域逻辑范围 驱动（唯一真源），经坐标双轨映射到视觉坐标。
# 2026-09-14 实机验收改版：原为「硬边圆角矩形」→ 相邻域直接相切成硬接缝（截图可见，像色块拼图）。
# 现改为「内缩实体 + 四边渐隐条」：域色在边缘 带宽 内渐隐到透明，域与域之间自然晕开。
func _绘制区域背景() -> void:
	var 范围表: Dictionary = Game.世界地图系统.区域逻辑范围
	for 区域 in 范围表.keys():
		if not 区域颜色.has(区域):
			continue
		var 范围: Dictionary = 范围表[区域]
		var 左上: Vector2 = _逻辑转视觉(float(范围["x1"]), float(范围["y1"]))
		var 右下: Vector2 = _逻辑转视觉(float(范围["x2"]), float(范围["y2"]))
		var 板色: Color = 区域颜色[区域]
		var 带宽: float = clampf(minf(右下.x - 左上.x, 右下.y - 左上.y) * 0.18, 60.0, 170.0)
		# 一、域色径向晕光（单节点，椭圆渐隐）——域板边界彻底消失
		_建域晕光(左上, 右下, 板色)
		# 二、内缩实体板（域芯，保证地名与点位可读）
		var 内左上: Vector2 = 左上 + Vector2(带宽, 带宽)
		var 内右下: Vector2 = 右下 - Vector2(带宽, 带宽)
		var 区域块: PanelContainer = PanelContainer.new()
		区域块.position = 内左上
		区域块.size = 内右下 - 内左上
		区域块.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = 板色
		var 圆: int = int(带宽 * 0.6)
		style.corner_radius_top_left = 圆
		style.corner_radius_top_right = 圆
		style.corner_radius_bottom_left = 圆
		style.corner_radius_bottom_right = 圆
		区域块.add_theme_stylebox_override("panel", style)
		var 标签: Label = Label.new()
		标签.text = 区域
		UITheme.apply_project_font(标签, UITheme.FONT_DISPLAY, true)
		标签.add_theme_color_override("font_color", UITheme.取同色异透(Color.WHITE, 0.3))
		标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		标签.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		区域块.add_child(标签)
		_地图层.add_child(区域块)

# 域色径向晕光：把「域」画成一团从域芯向边缘渐隐的椭圆色雾（单节点）。
# 为何不用四条矩形渐隐条：实机截图证明矩形条自身边界会在域板外露出硬直角矩形色块
# （2026-09-14 踩到）；径向渐变在结构上不可能产生矩形边界。
func _建域晕光(左上: Vector2, 右下: Vector2, 板色: Color) -> void:
	var g: Gradient = Gradient.new()
	g.set_color(0, UITheme.取同色异透(板色, 板色.a))
	g.set_color(1, UITheme.取同色异透(板色, 0.0))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var tr: TextureRect = TextureRect.new()
	tr.texture = t
	tr.position = 左上
	tr.size = 右下 - 左上
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_地图层.add_child(tr)

# 装饰填充（远山 / 聚落 / 云雾）：纯视觉、无交互、不参与任何判定。
# 目的：把画布留白填成「天下」的质感（内容密度的视觉层），不是玩法点位。
# 2026-09-14 实机改版：原 18 个小方块 alpha 0.15 → 实机看像噪点脏点；
# 改为 12 个「大而柔的圆形色斑」alpha 0.10，读作地貌斑块。
func _绘制装饰填充() -> void:
	var 范围表: Dictionary = Game.世界地图系统.区域逻辑范围
	for 区域 in 范围表.keys():
		if not 区域颜色.has(区域):
			continue
		var 范围: Dictionary = 范围表[区域]
		var 基色: Color = 区域颜色[区域]
		var 淡色: Color = UITheme.取同色异透(基色, 0.10)
		for i in range(12):
			var lx: float = randf_range(float(范围["x1"]), float(范围["x2"]))
			var ly: float = randf_range(float(范围["y1"]), float(范围["y2"]))
			var 视: Vector2 = _逻辑转视觉(lx, ly)
			var 尺寸: float = randf_range(90.0, 200.0)
			var 斑: PanelContainer = PanelContainer.new()
			斑.position = 视 - Vector2(尺寸, 尺寸) / 2.0
			斑.size = Vector2(尺寸, 尺寸)
			斑.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var 斑式: StyleBoxFlat = StyleBoxFlat.new()
			斑式.bg_color = 淡色
			var 斑圆: int = int(尺寸 / 2.0)
			斑式.corner_radius_top_left = 斑圆
			斑式.corner_radius_top_right = 斑圆
			斑式.corner_radius_bottom_left = 斑圆
			斑式.corner_radius_bottom_right = 斑圆
			斑.add_theme_stylebox_override("panel", 斑式)
			_地图层.add_child(斑)

func _生成地点标记() -> void:
	var 世界 = Game.世界地图系统
	# 玩家宗门
	var 宗门位置: Dictionary = 世界.获取宗门位置()
	var 宗门视: Vector2 = _域内转视觉(str(宗门位置["区域"]), float(宗门位置["x"]), float(宗门位置["y"]))
	_添加地点标记("太玄宗", "宗门", 宗门视.x, 宗门视.y, true)
	# 城镇（真源：世界地图系统.城镇坐标表 —— 域内口径，须按自身「区域」抬到全局）
	for 城镇ID in 世界.城镇坐标表.keys():
		var 城镇: Dictionary = 世界.城镇坐标表[城镇ID]
		var 城镇视: Vector2 = _域内转视觉(str(城镇.get("区域", "中州")), float(城镇["x"]), float(城镇["y"]))
		_添加地点标记(str(城镇["名称"]), "城镇", 城镇视.x, 城镇视.y, false, str(城镇ID))
	# 模拟其他宗门
	if 世界.其他宗门列表.is_empty():
		世界.生成模拟宗门(15)
	for 宗门 in 世界.其他宗门列表:
		var 宗门点: Vector2 = _域内转视觉(str(宗门.get("区域", "中州")), float(宗门["x"]), float(宗门["y"]))
		_添加地点标记(str(宗门["名称"]), "宗门", 宗门点.x, 宗门点.y, false)
	# 资源点（真源：世界地图系统.资源点列表 —— 仅已发现者上图，余者待探索揭示；全局口径）
	for 资源点 in 世界.资源点列表:
		if not bool(资源点.get("已发现", false)):
			continue
		var 资源视: Vector2 = _逻辑转视觉(float(资源点["x"]), float(资源点["y"]))
		_添加地点标记(str(资源点["名称"]), str(资源点["类型"]), 资源视.x, 资源视.y, false, str(资源点["ID"]))
	# 秘境（2026-09-14 补齐：原「秘境」详情分支有交互，却无点位生成 → 曾为不可达死分支）
	for 区域 in 世界.所有区域:
		for 秘 in 世界.获取区域秘境(str(区域)):
			var 秘视: Vector2 = _逻辑转视觉(float(秘["x"]), float(秘["y"]))
			_添加地点标记(str(秘["名称"]), "秘境", 秘视.x, 秘视.y, false)
	# 钓点（真源：灵钓系统 —— 各域按自身灵渊档生成；2026-09-14 扩容：原只画宗门所在域 1 处 → 五域各 1 处）
	for 区域 in 世界.所有区域:
		var 钓范围: Dictionary = 世界.区域逻辑范围.get(str(区域), {})
		for 钓点 in 世界.获取区域钓点(str(区域)):
			var 钓x: float = randf_range(float(钓范围.get("x1", -200.0)), float(钓范围.get("x2", 200.0)))
			var 钓y: float = randf_range(float(钓范围.get("y1", -200.0)), float(钓范围.get("y2", 200.0)))
			var 钓视: Vector2 = _逻辑转视觉(钓x, 钓y)
			_添加地点标记(str(钓点["名称"]), "钓点", 钓视.x, 钓视.y, false, str(钓点["ID"]))

func _添加地点标记(名称: String, 类型: String, x: float, y: float, 是玩家宗门: bool = false, 数据ID: String = "") -> void:
	var cfg: Dictionary = 地点类型.get(类型, {"颜色": Color.WHITE, "大小": 10, "图标": "emoji_world_location"})
	var 大小: float = float(cfg["大小"])
	if 是玩家宗门:
		大小 *= 1.5
	var 标记: Button = Button.new()
	# 2026-09-14：emoji 字符 → 圆形金框图标（豆包资产 emoji_world_*），无资产时回退字符。
	var 图标文本: String = str(cfg["图标"])
	var 图标tex: Texture2D = UITheme.emoji_icon_sized(图标文本, int(大小 * 1.5))
	if 图标tex != null:
		标记.icon = 图标tex
		标记.text = ""
		标记.expand_icon = false
	else:
		标记.text = 图标文本
	标记.custom_minimum_size = Vector2(大小 * 2, 大小 * 2)
	标记.position = Vector2(x - 大小, y - 大小)
	标记.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = cfg["颜色"]
	style.corner_radius_top_left = int(大小)
	style.corner_radius_top_right = int(大小)
	style.corner_radius_bottom_left = int(大小)
	style.corner_radius_bottom_right = int(大小)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.5) if 是玩家宗门 else Color(0, 0, 0, 0.3)
	标记.add_theme_stylebox_override("normal", style)
	标记.add_theme_stylebox_override("hover", style)
	标记.add_theme_stylebox_override("pressed", style)
	UITheme.apply_project_font(标记, int(大小), false)
	标记.add_theme_color_override("font_color", Color.WHITE)
	var 名称标签: Label = Label.new()
	名称标签.text = 名称
	UITheme.apply_project_font(名称标签, UITheme.FONT_AUX, false)
	名称标签.add_theme_color_override("font_color", Color.WHITE if 是玩家宗门 else Color(0.9, 0.9, 0.9))
	名称标签.position = Vector2(-20, 大小 * 2 + 2)
	名称标签.custom_minimum_size = Vector2(60, 14)
	名称标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	名称标签.mouse_filter = Control.MOUSE_FILTER_IGNORE
	标记.add_child(名称标签)
	标记.pressed.connect(func(节点=标记, n=名称, t=类型, px=x, py=y, ip=是玩家宗门, did=数据ID):
		_显示地点详情(n, t, px, py, ip, did)
	)
	_地图层.add_child(标记)
	_地点标记.append({"节点": 标记, "名称": 名称, "类型": 类型, "x": x, "y": y, "数据ID": 数据ID})

# ===== 地点详情与交互（全部走 world_map_system 真实逻辑）=====
func _添加说明行(vbox: VBoxContainer, 标签: String, 值: String) -> void:
	var 行: HBoxContainer = HBoxContainer.new()
	行.add_theme_constant_override("separation", 6)
	var a: Label = Label.new()
	a.text = 标签
	UITheme.apply_project_font(a, UITheme.FONT_BODY, false)
	a.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	a.custom_minimum_size = Vector2(76, 0)
	行.add_child(a)
	var b: Label = Label.new()
	b.text = 值
	UITheme.apply_project_font(b, UITheme.FONT_BODY, false)
	b.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 修复（实机验收 dump 抓出）：HBox 主轴水平，无 EXPAND_FILL 的子节点只拿最小宽度，
	# 而 autowrap Label 最小宽度 = 1px → 值列塌成 1px、正文一字一行。必须显式 EXPAND_FILL。
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	行.add_child(b)
	vbox.add_child(行)

func _显示地点详情(名称: String, 类型: String, x: float, y: float, 是玩家宗门: bool, 数据ID: String = "") -> void:
	_每日刷新()
	_详情面板.visible = true
	_面板淡入(_详情面板)
	for child in _详情面板.get_children():
		child.queue_free()
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_详情面板.add_child(vbox)

	var title: Label = Label.new()
	title.text = 名称
	UITheme.apply_project_font(title, UITheme.FONT_H2, true)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	vbox.add_child(title)
	_添加说明行(vbox, "类型", 类型)

	var 世界 = Game.世界地图系统
	if not 是玩家宗门:
		var 宗门位置: Dictionary = 世界.获取宗门位置()
		var 逻辑点: Vector2 = _视觉转逻辑(x, y)
		var 距离: float = 世界.计算距离(float(宗门位置["x"]), float(宗门位置["y"]), 逻辑点.x, 逻辑点.y)
		_添加说明行(vbox, "距离", "%.0f 里" % 距离)

	match 类型:
		"城镇":
			_建城镇操作(vbox, 数据ID, x, y, 名称)
		"宗门":
			if not 是玩家宗门:
				_建宗门战操作(vbox, x, y, 名称)
			else:
				_添加说明行(vbox, "区域", str(世界.宗门区域))
				var 特性: Dictionary = 世界.获取当前区域特性()
				_添加说明行(vbox, "修炼加成", "+%d%%" % int(float(特性.get("修炼加成", 0.0)) * 100.0))
		"灵脉", "矿脉", "灵草丛", "灵草从", "妖兽领", "灵泉":
			_建资源操作(vbox, 数据ID, 名称, 类型, x, y)
		"钓点":
			_建垂钓操作(vbox, 数据ID, 名称)
		"秘境":
			_添加操作按钮(vbox, "派遣探索", func(): _派遣队伍(x, y, "探索", 名称))

	_添加操作按钮(vbox, "关闭", func(): _详情面板.visible = false)

func _建城镇操作(vbox: VBoxContainer, 城镇ID: String, x: float, y: float, 名称: String) -> void:
	if 城镇ID == "":
		return
	var 世界 = Game.世界地图系统
	_添加说明行(vbox, "隶属", str(世界.获取城镇势力(城镇ID)))
	_添加说明行(vbox, "城镇好感", "%d / 100" % int(世界.获取城镇好感度(城镇ID)))
	var 运输: Dictionary = 世界.计算商队运输详情(城镇ID, "普通商队")
	if bool(运输.get("成功", false)):
		_添加说明行(vbox, "商路", "%d日 · 风险%d%% · 运费%d" % [
			int(运输.get("运输时间", 0)),
			int(float(运输.get("被劫风险", 0.0)) * 100.0),
			int(运输.get("运输费用", 0)),
		])
	# P1-2.2 城镇商情（真源：city_config 价率/特产/缺货 + goods_config 基价）
	var 商情: Dictionary = 世界.获取城镇商情(城镇ID)
	if bool(商情.get("成功", false)):
		_添加说明行(vbox, "物价", "买 %.2f · 卖 %.2f（基准 %.2f）" % [
			float(商情.get("买入价率", 1.0)), float(商情.get("卖出价率", 1.0)), float(商情.get("基准价率", 1.0))])
		var 特产: Array = 商情.get("特产清单", [])
		if not 特产.is_empty():
			var 特名: Array = []
			for gid in 特产:
				var 货: Dictionary = 世界.获取货品城价(城镇ID, str(gid))
				特名.append(str(货.get("货品", gid)))
			_添加说明行(vbox, "特产", "、".join(特名))
		var 缺货: Array = 商情.get("缺货清单", [])
		if not 缺货.is_empty():
			var 缺名: Array = []
			for gid in 缺货:
				var 货2: Dictionary = 世界.获取货品城价(城镇ID, str(gid))
				缺名.append(str(货2.get("货品", gid)))
			_添加说明行(vbox, "缺货", "、".join(缺名))
		var 珍品: Array = 世界.获取城镇珍品(城镇ID)
		if not 珍品.is_empty():
			var 珍名: Array = []
			for it in 珍品:
				珍名.append("%s（%d阶）" % [str(it.get("名称", "")), int(it.get("品阶", 1))])
			_添加说明行(vbox, "珍品", "、".join(珍名))
	_添加操作按钮(vbox, "派遣商队", func(): _派遣队伍(x, y, "商队", 名称, 城镇ID))
	_添加操作按钮(vbox, "通商（7日一次）", func(): _on_通商(城镇ID, 名称))
	_添加操作按钮(vbox, "朝贡（灵石300）", func(): _on_朝贡(城镇ID, 名称))

func _建宗门战操作(vbox: VBoxContainer, x: float, y: float, 名称: String) -> void:
	var 世界 = Game.世界地图系统
	var 战逻辑: Vector2 = _视觉转逻辑(x, y)
	var 目标: Dictionary = {
		"名称": 名称, "区域": 世界.宗门区域,
		"x": 战逻辑.x, "y": 战逻辑.y, "战力": randi_range(1000, 5000),
	}
	for 宗门 in 世界.其他宗门列表:
		if str(宗门["名称"]) == 名称:
			目标["战力"] = int(宗门.get("战力", 1000))
			目标["区域"] = str(宗门.get("区域", 世界.宗门区域))
			break
	# P2-3.1 社交联动：外交关系全貌 + 传音问候 / 缔结盟约 / 下战书（真源：宗门外交关系表）
	if 世界.has_method("获取遭遇宗门外交"):
		var 交: Dictionary = 世界.获取遭遇宗门外交(名称)
		if bool(交.get("成功", false)):
			_添加说明行(vbox, "宗门关系", "%s · 好感 %d / 100" % [str(交.get("关系", "中立")), int(交.get("好感度", 50))])
			if int(交.get("问候次数", 0)) > 0:
				_添加说明行(vbox, "往来", "已遣使 %d 次" % int(交.get("问候次数", 0)))
			var 协防: Dictionary = 世界.获取同盟协防(str(交.get("区域", "")))
			if int(协防.get("同盟数", 0)) > 0:
				_添加说明行(vbox, "同盟协防", "%d 宗守望 · 危险 -%d%%" % [
					int(协防.get("同盟数", 0)), int(float(协防.get("危险削减", 0.0)) * 100.0)])
	var 出征: Dictionary = 世界.计算宗门战出征详情(目标)
	if bool(出征.get("成功", false)):
		_添加说明行(vbox, "我方道行", str(出征.get("我方战力", 0)))
		_添加说明行(vbox, "敌方道行", str(出征.get("敌方战力", 0)))
		_添加说明行(vbox, "行军", "%d日 · 耗灵石%d" % [int(出征.get("行军时间", 0)), int(出征.get("行军消耗", 0))])
		_添加说明行(vbox, "预估胜率", "%d%%" % int(float(出征.get("预估胜率", 0.0)) * 100.0))
	_添加操作按钮(vbox, "传音问候", func(): _on_问候宗门(名称))
	_添加操作按钮(vbox, "缔结盟约", func(): _on_结盟宗门(名称))
	_添加操作按钮(vbox, "下战书", func(): _on_宣战宗门(名称))
	_添加操作按钮(vbox, "宣战讨伐", func(): _派遣队伍(x, y, "讨伐", 名称))

func _建资源操作(vbox: VBoxContainer, 资源点ID: String, 名称: String, 类型: String, x: float, y: float) -> void:
	var 世界 = Game.世界地图系统
	if 资源点ID == "":
		_添加说明行(vbox, "状态", "此处尚无宗门勘记")
		return
	var 目标: Dictionary = {}
	for r in 世界.获取可采集资源点():
		if str(r.get("ID", "")) == 资源点ID:
			目标 = r
			break
	if 目标.is_empty():
		_添加说明行(vbox, "状态", "宗门尚未勘明此处")
	else:
		var 可否: bool = bool(目标.get("可采集", false))
		_添加说明行(vbox, "品阶", "第%d阶" % int(目标.get("等级", 1)))
		_添加说明行(vbox, "今日已采", "%d / %d" % [int(目标.get("今日次数", 0)), int(目标.get("每日上限", 0))])
		_添加说明行(vbox, "状态", "可采集" if 可否 else "尚需休养 %d 日" % int(目标.get("冷却剩余", 0)))
	_添加操作按钮(vbox, "派人采集", func(): _on_采集(资源点ID, 名称, x, y))

func _建垂钓操作(vbox: VBoxContainer, 钓点ID: String, 名称: String) -> void:
	var 世界 = Game.世界地图系统
	var 鱼获: Array = 世界.获取钓点鱼获(钓点ID)
	_添加说明行(vbox, "可钓鱼类", "%d 种" % 鱼获.size())
	var 名录: Array = []
	for f in 鱼获:
		if f is Dictionary:
			名录.append("%s(%s)" % [str(f.get("名称", "?")), str(f.get("品阶", ""))])
		if 名录.size() >= 6:
			break
	if not 名录.is_empty():
		_添加说明行(vbox, "名录", "、".join(名录))
	else:
		_添加说明行(vbox, "名录", "钓道尚浅，未明此渊鱼性")
	_添加操作按钮(vbox, "垂钓", func(): _on_垂钓(钓点ID))

func _面板淡入(节点: CanvasItem) -> void:
	节点.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(节点, "modulate:a", 1.0, 0.2)
func _添加操作按钮(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 30)
	UITheme.apply_secondary_button_style(btn)
	btn.pressed.connect(callback)
	parent.add_child(btn)

# ===== 队伍派遣与到达（真实结算）=====
func _派遣队伍(目标x: float, 目标y: float, 任务类型: String, 目标名: String, 数据ID: String = "") -> void:
	var 世界 = Game.世界地图系统
	var 宗门位置: Dictionary = 世界.获取宗门位置()
	var 起点: Vector2 = _域内转视觉(str(宗门位置["区域"]), float(宗门位置["x"]), float(宗门位置["y"]))
	var 终点: Vector2 = Vector2(目标x, 目标y)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.9, 0.3, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(16, 16)
	panel.position = 起点 - Vector2(8, 8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_地图层.add_child(panel)
	_移动中队伍.append({
		"节点": panel,
		"起点": 起点,
		"终点": 终点,
		"进度": 0.0,
		"速度": 0.3,
		"任务类型": 任务类型,
		"目标名": 目标名,
		"目标x": 目标x,
		"目标y": 目标y,
		"数据ID": 数据ID,
	})
	_详情面板.visible = false

func _更新移动中队伍(delta: float) -> void:
	for i in range(_移动中队伍.size() - 1, -1, -1):
		var 队伍: Dictionary = _移动中队伍[i]
		队伍["进度"] = float(队伍["进度"]) + float(队伍["速度"]) * delta
		if float(队伍["进度"]) >= 1.0:
			var 节点: Control = 队伍["节点"]
			节点.queue_free()
			_队伍到达(队伍)
			_移动中队伍.remove_at(i)
		else:
			var 起点: Vector2 = 队伍["起点"]
			var 终点: Vector2 = 队伍["终点"]
			var 当前: Vector2 = 起点.lerp(终点, float(队伍["进度"]))
			队伍["节点"].position = 当前 - Vector2(8, 8)

func _队伍到达(队伍: Dictionary) -> void:
	var 世界 = Game.世界地图系统
	var 任务类型: String = str(队伍["任务类型"])
	var 目标名: String = str(队伍["目标名"])
	var 目标x: float = float(队伍["目标x"])
	var 目标y: float = float(队伍["目标y"])
	var 数据ID: String = str(队伍.get("数据ID", ""))
	_探索区域(目标x, 目标y, 200.0 * 世界映射系数)
	match 任务类型:
		"探索":
			var 事件: Dictionary = 世界.触发大地图事件(世界.宗门区域)
			if bool(事件.get("成功", false)):
				_弹出当前事件()
			else:
				var 发现数: int = _顺路探查(目标x, 目标y)
				if 发现数 > 0:
					_重绘地图内容()
					_触发事件("探明", "弟子于%s一带踏勘，探明 %d 处资源所在。" % [目标名, 发现数], [{"text": "确定", "result": "ok"}])
				else:
					_触发事件("无异常", "深入%s，一路平静，未见异动。" % 目标名, [{"text": "确定", "result": "ok"}])
		"商队":
			var 详情: Dictionary = 世界.计算商队运输详情(数据ID, "普通商队")
			if bool(详情.get("成功", false)):
				_触发事件("商队抵达", "商队抵达%s，历时%d日，耗运费%d灵石。" % [目标名, int(详情.get("运输时间", 0)), int(详情.get("运输费用", 0))], [{"text": "确定", "result": "ok"}])
			else:
				_触发事件("商队抵达", "商队已抵%s。" % 目标名, [{"text": "确定", "result": "ok"}])
		"讨伐":
			var 讨逻辑: Vector2 = _视觉转逻辑(目标x, 目标y)
			var 目标宗门: Dictionary = {
				"名称": 目标名, "区域": 世界.宗门区域,
				"x": 讨逻辑.x, "y": 讨逻辑.y, "战力": randi_range(1000, 5000),
			}
			var 出征: Dictionary = 世界.计算宗门战出征详情(目标宗门)
			_触发事件("宗门前锋", "大军已抵%s。预估胜率 %d%%，行军耗灵石 %d。" % [
				目标名,
				int(float(出征.get("预估胜率", 0.0)) * 100.0),
				int(出征.get("行军消耗", 0)),
			], [{"text": "开战", "result": "战斗"}, {"text": "退兵", "result": "撤退"}])
		"采集":
			var 采集结果: Dictionary = 世界.采集资源点(数据ID)
			if bool(采集结果.get("成功", false)):
				_触发事件("采集完成", "弟子自%s归，得%s x%d，已入宗门库藏。" % [目标名, str(采集结果.get("产出", "资源")), int(采集结果.get("数量", 0))], [{"text": "确定", "result": "ok"}])
			else:
				_触发事件("采集未成", "%s：%s" % [目标名, str(采集结果.get("原因", "此处暂无所得"))], [{"text": "确定", "result": "ok"}])

# 顺路探查：把目标点附近的未发现资源点标记为已发现
func _顺路探查(图上x: float, 图上y: float) -> int:
	var 世界 = Game.世界地图系统
	var 发现: int = 0
	for 资源点 in 世界.资源点列表:
		if bool(资源点.get("已发现", false)):
			continue
		var 视: Vector2 = _逻辑转视觉(float(资源点.get("x", 0.0)), float(资源点.get("y", 0.0)))
		if sqrt((视.x - 图上x) * (视.x - 图上x) + (视.y - 图上y) * (视.y - 图上y)) <= 320.0 * 世界映射系数:
			if bool(世界.发现资源点(str(资源点["ID"])).get("成功", false)):
				发现 += 1
	return 发现

# 重绘地点标记（资源点被发现后刷新）
func _重绘地图内容() -> void:
	for 记 in _地点标记:
		var n: Node = 记.get("节点", null)
		if n != null and is_instance_valid(n):
			n.queue_free()
	_地点标记.clear()
	_生成地点标记()

# ===== 大地图事件（真源：world_map_system 事件系统）=====
func _弹出当前事件() -> void:
	var 世界 = Game.世界地图系统
	var 事件: Dictionary = 世界.当前事件
	if 事件.is_empty():
		return
	var 选项: Array = []
	for o in 世界.获取当前事件选项():
		选项.append({"text": str(o.get("名", "确定")), "result": str(o.get("ID", "忽略"))})
	_事件来源 = "大地图"
	_触发事件(str(事件.get("名", "异闻")), str(事件.get("描述", "")), 选项)

func _触发事件(标题: String, 描述: String, 选项: Array) -> void:
	_事件面板.visible = true
	_面板淡入(_事件面板)
	for child in _事件面板.get_children():
		child.queue_free()
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_事件面板.add_child(vbox)

	var title: Label = Label.new()
	title.text = 标题
	UITheme.apply_project_font(title, UITheme.FONT_TITLE, true)
	title.add_theme_color_override("font_color", Color(0.95, 0.7, 0.3))
	vbox.add_child(title)

	var desc: Label = Label.new()
	desc.text = 描述
	UITheme.apply_project_font(desc, UITheme.FONT_BODY, false)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	for opt in 选项:
		var btn: Button = Button.new()
		btn.text = str(opt["text"])
		btn.custom_minimum_size = Vector2(0, 32)
		UITheme.apply_secondary_button_style(btn)
		btn.pressed.connect(func(r=str(opt["result"])):
			_事件结果(标题, r)
		)
		vbox.add_child(btn)

func _事件结果(事件名: String, 结果: String) -> void:
	_事件面板.visible = false
	if _事件来源 == "大地图":
		_事件来源 = ""
		var 处理: Dictionary = Game.世界地图系统.处理事件选择(结果)
		if bool(处理.get("成功", false)):
			var 赏: Dictionary = 处理.get("奖励", {})
			var 赏文: Array = []
			for k in 赏.keys():
				赏文.append("%s %s" % [str(k), str(赏[k])])
			var 描述: String = str(处理.get("描述", "事已了结"))
			if not 赏文.is_empty():
				描述 = "%s（%s）" % [描述, "、".join(赏文)]
			_触发事件(事件名, 描述, [{"text": "确定", "result": "ok"}])
		else:
			var 缘由: String = str(处理.get("原因", "事已了结"))
			_触发事件(事件名, 缘由, [{"text": "确定", "result": "ok"}])
		return
	# 简化版结果处理
	match 结果:
		"战斗":
			Game.添加纪事("神异", "大地图战斗", "于%s力战而胜，斩获颇丰。" % 事件名, 2)
		"探索":
			Game.添加纪事("神异", "秘境探索", "深入%s，偶有所获。" % 事件名, 2)
		"帮助":
			Game.添加纪事("声望", "仗义出手", "路见不平拔刀相助，江湖声望提升。", 1)
		"采集":
			Game.添加纪事("庶务", "灵泉采集", "采集灵泉，灵气充盈。", 1)
		"结交":
			Game.添加纪事("社交", "结识同道", "与游历散修结交，互赠功法。", 1)
		_:
			pass

# ===== 地图控制 =====
# 动态最小缩放：保证地图始终「盖满」视口（缩放极值保护 → 四边不露纯黑暗区）。
func _动态最小缩放() -> float:
	if _地图容器 == null:
		return 最小缩放
	var 视口: Vector2 = _地图容器.size
	if 视口.x <= 0.0 or 视口.y <= 0.0:
		return 最小缩放
	return max(最小缩放, max(视口.x / 地图宽度, 视口.y / 地图高度))

# 偏移约束：地图四边不得离开视口（无缝浏览的边界保护）。
func _约束偏移() -> void:
	if _地图容器 == null:
		return
	var 视口: Vector2 = _地图容器.size
	var 地图视: Vector2 = Vector2(地图宽度, 地图高度) * _缩放
	_偏移.x = clamp(_偏移.x, min(0.0, 视口.x - 地图视.x), 0.0)
	_偏移.y = clamp(_偏移.y, min(0.0, 视口.y - 地图视.y), 0.0)

func _调整缩放(增量: float) -> void:
	_缩放 = clamp(_缩放 + 增量, _动态最小缩放(), 最大缩放)
	_更新地图变换()
	_回显缩放()

func _回显缩放() -> void:
	# ★ 2026-09-16 修（回归 · 死键扫描实测「−」/「+」双判 DEAD 的根因）：
	#   顶栏重排时缩放三件套下沉为右下悬浮条 ZoomBar，ZoomLabel 随之变成**缩放条的子节点**
	#   ⇒ 原 get_node_or_null("ZoomLabel")（按页面根查找）恒返回 null ⇒ 缩放数值永不回显，
	#   玩家点「−」「+」看不到百分比变化，观感等同按钮坏了。改为递归查找，兼容后续再重排。
	var zoom_label: Node = find_child("ZoomLabel", true, false)
	if zoom_label is Label:
		(zoom_label as Label).text = "%d%%" % int(_缩放 * 100)

func _更新地图变换() -> void:
	if _地图层 == null:
		return
	_约束偏移()
	_地图层.scale = Vector2(_缩放, _缩放)
	_地图层.position = _偏移
	_迷雾层.scale = Vector2(_缩放, _缩放)
	_迷雾层.position = _偏移

func _定位到宗门() -> void:
	var 宗门位置: Dictionary = Game.世界地图系统.获取宗门位置()
	var 中心: Vector2 = _域内转视觉(str(宗门位置["区域"]), float(宗门位置["x"]), float(宗门位置["y"]))
	var 视口大小: Vector2 = _地图容器.size
	_缩放 = clamp(0.6, _动态最小缩放(), 最大缩放)
	_偏移 = 视口大小 / 2 - 中心 * _缩放
	_更新地图变换()
	_回显缩放()

# 视口尺寸变化（旋屏 / 布局重排）→ 重新约束，避免露出画布外
func _on_视口变化() -> void:
	_缩放 = clamp(_缩放, _动态最小缩放(), 最大缩放)
	_更新地图变换()

func _on_地图输入(事件: InputEvent) -> void:
	if 事件 is InputEventMouseButton:
		var mb: InputEventMouseButton = 事件
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_拖动中 = true
				_上次鼠标位置 = mb.position
				_拖动速度 = Vector2.ZERO
			else:
				_拖动中 = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_调整缩放(缩放速度)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_调整缩放(-缩放速度)
	elif 事件 is InputEventMouseMotion and _拖动中:
		var mm: InputEventMouseMotion = 事件
		var delta: Vector2 = mm.position - _上次鼠标位置
		_偏移 += delta
		_拖动速度 = delta.limit_length(80.0)
		_上次鼠标位置 = mm.position
		_更新地图变换()

## B6：以全屏浮层打开「舆图总览」（列表版），承载宗门迁移等可视版未覆盖的功能。
func _打开舆图总览() -> void:
	if _舆图总览 != null and is_instance_valid(_舆图总览):
		_舆图总览.visible = true
		return
	var 脚本: GDScript = load("res://ui/page_world_map.gd")
	if 脚本 == null:
		push_error("page_world_map.gd 加载失败")
		return
	var page: Control = Control.new()
	page.set_script(脚本)
	page.name = "WorldMapOverview"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	_舆图总览 = page


func _on_close() -> void:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("_close_sub_page"):
			n._close_sub_page()
			return
		n = n.get_parent()
	queue_free()
# ============================================================
# ===== 天下总览与系统联动（2026-09-12 workbuddy · 任务#004 P0）=====
# 本区块把 world_map_system 的 P4/P5/P6/P7 全部接上 UI，消灭「有后端无落点」。
# ============================================================
var _事件来源: String = ""
var _总览面板: PanelContainer = null
var _上次刷新日: int = -1

# 每日刷新（真源：world_map_system 每日重置 + 弟子归期结算）
func _每日刷新() -> void:
	if _上次刷新日 == Game.累计游戏日:
		return
	_上次刷新日 = Game.累计游戏日
	var 世界 = Game.世界地图系统
	世界.重置每日事件次数()
	世界.重置每日采集次数()
	var 归来: Array = 世界.检查探索归来()
	var 文案: Array = []
	for r in 归来:
		if bool(r.get("成功", false)):
			文案.append(str(r.get("弟子", "")))
	if not 文案.is_empty():
		_触发事件("弟子归来", "%s 已自外游历归来，宗门库藏与声望皆有进益。" % "、".join(文案), [{"text": "确定", "result": "ok"}])

func _总览标题(parent: VBoxContainer, 文本: String) -> void:
	var l: Label = Label.new()
	l.text = "— " + 文本
	UITheme.apply_project_font(l, UITheme.FONT_H2, true)
	l.add_theme_color_override("font_color", Color(0.9, 0.78, 0.45))
	parent.add_child(l)

# 打开/刷新天下总览
func _打开天下总览() -> void:
	if _总览面板 == null or not is_instance_valid(_总览面板):
		_总览面板 = PanelContainer.new()
		_总览面板.name = "WorldOverview"
		_总览面板.set_anchors_preset(Control.PRESET_FULL_RECT)
		var 总览板: StyleBoxFlat = StyleBoxFlat.new()
		总览板.bg_color = UITheme.获取面板底色()
		总览板.border_color = Color(0.910, 0.773, 0.447, 0.28)
		总览板.set_border_width_all(1)
		总览板.set_corner_radius_all(12)
		_总览面板.add_theme_stylebox_override("panel", 总览板)
		add_child(_总览面板)
	_总览面板.visible = true
	_面板淡入(_总览面板)
	_刷新天下总览()

func _刷新天下总览() -> void:
	_每日刷新()
	if _总览面板 == null or not is_instance_valid(_总览面板):
		return
	for child in _总览面板.get_children():
		child.queue_free()
	var 世界 = Game.世界地图系统
	var 外壳: VBoxContainer = VBoxContainer.new()
	外壳.add_theme_constant_override("separation", 8)
	_总览面板.add_child(外壳)

	var 顶: HBoxContainer = HBoxContainer.new()
	顶.add_theme_constant_override("separation", 8)
	外壳.add_child(顶)
	var 题: Label = Label.new()
	题.text = "天下总览"
	UITheme.apply_project_font(题, UITheme.FONT_TITLE, true)
	题.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	顶.add_child(题)
	顶.add_spacer(false)
	var 关: Button = Button.new()
	关.text = "关闭"
	关.custom_minimum_size = Vector2(72, 32)
	UITheme.apply_secondary_button_style(关)
	关.pressed.connect(func(): _总览面板.visible = false)
	顶.add_child(关)

	var 滚: ScrollContainer = ScrollContainer.new()
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 修复（实机验收抓出）：ScrollContainer 默认 AUTO 横向滚动「不拉伸子节点」，
	# 而正文 Label 开了 autowrap → 最小宽度塌缩到 ~1 字 → 正文一字一行、列宽=单字宽。
	# 关闭横向滚动后由 ScrollContainer 拉伸子节点，正文恢复正常通栏排版。
	滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	外壳.add_child(滚)
	var 列: VBoxContainer = VBoxContainer.new()
	列.add_theme_constant_override("separation", 6)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚.add_child(列)

	# 一、疆域
	var 总: Dictionary = 世界.获取天下玩法总览()
	var 位置: Dictionary = 总.get("宗门位置", {})
	_总览标题(列, "疆域")
	_添加说明行(列, "宗门所在", "%s（x %.0f，y %.0f）" % [str(位置.get("区域", "?")), float(位置.get("x", 0.0)), float(位置.get("y", 0.0))])
	_添加说明行(列, "周边城镇", "%d 座" % int(总.get("周边城镇数", 0)))
	_添加说明行(列, "附近宗门", "%d 家" % int(总.get("附近宗门数", 0)))
	_添加说明行(列, "已探秘境", "%d 处" % int(总.get("已探索秘境数", 0)))
	_添加说明行(列, "资源点", "%d 处（已探明 %d）" % [int(总.get("资源点数", 0)), int(总.get("已发现资源点", 0))])
	_添加说明行(列, "可采集", "%d 处" % int(总.get("可采集资源点数", 0)))
	_添加说明行(列, "迁移冷却", "%d 日" % int(总.get("迁移冷却剩余", 0)))

	# 二、可采集资源（真源：获取可采集资源点）
	_总览标题(列, "可采集资源")
	var 有可采: bool = false
	for r in 世界.获取可采集资源点():
		if not bool(r.get("可采集", false)):
			continue
		有可采 = true
		var 行: HBoxContainer = HBoxContainer.new()
		行.add_theme_constant_override("separation", 8)
		列.add_child(行)
		var 名: Label = Label.new()
		名.text = "%s（%s·第%d阶）" % [str(r.get("名称", "")), str(r.get("类型", "")), int(r.get("等级", 1))]
		UITheme.apply_project_font(名, UITheme.FONT_BODY, false)
		名.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		名.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行.add_child(名)
		var 钮: Button = Button.new()
		钮.text = "采集"
		钮.custom_minimum_size = Vector2(64, 28)
		UITheme.apply_secondary_button_style(钮)
		var rid: String = str(r.get("ID", ""))
		var r名: String = str(r.get("名称", ""))
		钮.pressed.connect(func(): _on_采集(rid, r名, 0.0, 0.0))
		行.add_child(钮)
	if not 有可采:
		_添加说明行(列, "—", "各处资源皆在休养，或尚未探明")

	# 三、本域钓点与妖兽（真源：灵钓系统 / beast.gd 名录）
	_总览标题(列, "本域钓点与妖兽")
	for 钓点 in 世界.获取区域钓点(世界.宗门区域):
		var 鱼获: Array = 世界.获取钓点鱼获(str(钓点.get("ID", "")))
		_添加说明行(列, str(钓点.get("名称", "灵渊")), "%d 种鱼获 · 难度 %.1f · %s" % [
			鱼获.size(),
			float(钓点.get("难度", 1.0)),
			"已通钓道" if bool(钓点.get("已解锁", false)) else "需钓道境界 %d" % int(钓点.get("需境界", 0)),
		])
	var 妖兽: Array = 世界.获取区域妖兽(世界.宗门区域)
	for i in range(mini(4, 妖兽.size())):
		var 兽: Dictionary = 妖兽[i]
		var 行2: HBoxContainer = HBoxContainer.new()
		行2.add_theme_constant_override("separation", 8)
		列.add_child(行2)
		var 名2: Label = Label.new()
		名2.text = "%s（%s·道行 %d）" % [str(兽.get("名", "")), str(兽.get("品阶名", "")), int(兽.get("战力", 0))]
		UITheme.apply_project_font(名2, UITheme.FONT_BODY, false)
		名2.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		名2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行2.add_child(名2)
		var 钮2: Button = Button.new()
		钮2.text = "降服"
		钮2.custom_minimum_size = Vector2(64, 28)
		UITheme.apply_secondary_button_style(钮2)
		var 兽ID: String = str(兽.get("ID", ""))
		钮2.pressed.connect(func(): _on_降服(兽ID))
		行2.add_child(钮2)

	# 四、弟子派遣（真源：派遣弟子探索 / 获取探索中弟子）
	_总览标题(列, "弟子派遣")
	for r in 世界.获取探索中弟子():
		_添加说明行(列, str(r.get("姓名", "")), "在外游历 · 还需 %d 日" % int(r.get("剩余天数", 0)))
	var 有可派: bool = false
	for d in Game.弟子列表:
		if d == null or not (d is Disciple):
			continue
		var 态: String = str(d.状态)
		if 态 == "失踪" or 态 == "陨落" or 态 == "叛出" or 态 == "外派":
			continue
		有可派 = true
		var 行3: HBoxContainer = HBoxContainer.new()
		行3.add_theme_constant_override("separation", 8)
		列.add_child(行3)
		var 名3: Label = Label.new()
		名3.text = "%s（%s）" % [str(d.姓名), str(d.境界)]
		UITheme.apply_project_font(名3, UITheme.FONT_BODY, false)
		名3.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		名3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行3.add_child(名3)
		var 钮3: Button = Button.new()
		钮3.text = "派遣"
		钮3.custom_minimum_size = Vector2(64, 28)
		UITheme.apply_secondary_button_style(钮3)
		var did: int = int(d.弟子ID)
		钮3.pressed.connect(func(): _on_派遣弟子(did))
		行3.add_child(钮3)
		var 钮6: Button = Button.new()
		钮6.text = "堪舆"
		钮6.custom_minimum_size = Vector2(64, 28)
		UITheme.apply_secondary_button_style(钮6)
		钮6.pressed.connect(func(): _on_寻宝(did))
		行3.add_child(钮6)
		if 列.get_child_count() > 36:
			break
	if not 有可派:
		_添加说明行(列, "—", "宗门暂无可以差遣的弟子")

	# 五、化身游历（真源：化身系统 派遣化身游历 ↔ 本系统五域桥接）
	_总览标题(列, "化身游历")
	var 有化身: bool = false
	for 化 in Game.化身列表:
		if not (化 is Dictionary):
			continue
		var 忙: bool = str(化.get("游历状态", "")) == "游历中"
		if 忙:
			_添加说明行(列, str(化.get("姓名", "化身")), "正于%s游历" % str(化.get("游历区域", "他乡")))
			continue
		有化身 = true
		var 行4: HBoxContainer = HBoxContainer.new()
		行4.add_theme_constant_override("separation", 8)
		列.add_child(行4)
		var 名4: Label = Label.new()
		名4.text = "%s（%s）" % [str(化.get("姓名", "化身")), str(化.get("境界", ""))]
		UITheme.apply_project_font(名4, UITheme.FONT_BODY, false)
		名4.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		名4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行4.add_child(名4)
		var 选: OptionButton = OptionButton.new()
		for 向 in 世界.获取化身游历总览():
			选.add_item("%s（%s）" % [str(向.get("区域", "")), str(向.get("游历地", ""))])
		行4.add_child(选)
		var 钮4: Button = Button.new()
		钮4.text = "派遣"
		钮4.custom_minimum_size = Vector2(64, 28)
		UITheme.apply_secondary_button_style(钮4)
		var 化ID: int = int(化.get("化身ID", 0))
		钮4.pressed.connect(func(): _on_派遣化身(化ID, str(选.get_item_text(选.selected))))
		行4.add_child(钮4)
	if not 有化身:
		for 向 in 世界.获取化身游历总览():
			_添加说明行(列, str(向.get("区域", "")), "%s · %s" % [str(向.get("游历地", "")), "已踏足" if bool(向.get("已探索", false)) else "未至"])

	# 六、风水选址（真源：区域特性.修炼加成 + 本系统地脉表）
	_总览标题(列, "风水选址")
	var 现风: Dictionary = 世界.获取区域风水(世界.宗门区域)
	if bool(现风.get("成功", false)):
		_添加说明行(列, "现址", "%s · 风水%s · 修炼%+d%% · 危险%d%%" % [
			str(现风.get("区域", "")), str(现风.get("评级", "平")),
			int(float(现风.get("修炼加成", 0.0)) * 100.0), int(float(现风.get("危险度", 0.0)) * 100.0)])
	var 本域地脉: Array = 世界.获取灵脉宝地(世界.宗门区域)
	if not 本域地脉.is_empty():
		var 脉名: Array = []
		for d in 本域地脉:
			脉名.append(str(d.get("名称", "")))
		_添加说明行(列, "本域地脉", "、".join(脉名))
	for 向 in 世界.获取化身游历总览():
		var 区: String = str(向.get("区域", ""))
		if 区 == str(世界.宗门区域):
			continue
		var 评: Dictionary = 世界.评估迁址(区, 0.0, 0.0)
		if not bool(评.get("成功", false)):
			continue
		var 行5: HBoxContainer = HBoxContainer.new()
		行5.add_theme_constant_override("separation", 8)
		列.add_child(行5)
		var 名5: Label = Label.new()
		名5.text = "%s · 风水%s · 修炼%+d%%" % [区, str(评.get("评级", "平")), int(float(评.get("修炼差", 0.0)) * 100.0)]
		UITheme.apply_project_font(名5, UITheme.FONT_BODY, false)
		名5.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		名5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行5.add_child(名5)
		var 钮5: Button = Button.new()
		钮5.text = "迁址"
		钮5.custom_minimum_size = Vector2(64, 28)
		UITheme.apply_secondary_button_style(钮5)
		钮5.pressed.connect(func(): _on_迁址(区))
		行5.add_child(钮5)

	# 七、跑商路线（真源：goods_config.base_price × city_config.base_price_rate）
	_总览标题(列, "跑商路线")
	var 路线: Array = 世界.获取跑商路线推荐(3)
	if 路线.is_empty():
		_添加说明行(列, "—", "各处物价相平，暂无厚利可图")
	for rt in 路线:
		var 甲情: Dictionary = 世界.获取城镇商情(str(rt.get("买入城", "")))
		var 乙情: Dictionary = 世界.获取城镇商情(str(rt.get("卖出城", "")))
		_添加说明行(列, "%s → %s" % [str(甲情.get("名称", "")), str(乙情.get("名称", ""))],
			"%s · 差价%d 运费%d · 保本%d件" % [str(rt.get("货品", "")), int(rt.get("差价", 0)),
				int(rt.get("运费", 0)), int(rt.get("保本量", 0))])

	# 八、天下见闻（真源：本系统统计，服务成就「踏遍五洲」等）
	_总览标题(列, "天下见闻")
	var 统: Dictionary = 世界.获取天下探索统计()
	_添加说明行(列, "踏足五域", "%d / %d" % [int(统.get("已探索区域", 0)), int(统.get("区域总数", 5))])
	_添加说明行(列, "探明资源", "%d / %d" % [int(统.get("已发现资源点", 0)), int(统.get("资源点总数", 0))])
	_添加说明行(列, "已探秘境", "%d 处" % int(统.get("已探索秘境", 0)))
	_添加说明行(列, "累计采集", "%d 次" % int(统.get("累计采集次数", 0)))
	_添加说明行(列, "降服灵兽", "%d 头" % int(统.get("降服灵兽数", 0)))

	# 九、宗门交游（P2-3.1：附近频道 + 同盟协防，真源：宗门外交关系表）
	_总览标题(列, "宗门交游")
	var 盟统: Dictionary = 世界.获取同盟协防(世界.宗门区域)
	_添加说明行(列, "本域同盟", "%d 宗 · 探索危险 -%d%%" % [
		int(盟统.get("同盟数", 0)), int(float(盟统.get("危险削减", 0.0)) * 100.0)])
	var 友数: int = 0
	var 敌数: int = 0
	var 临宗: int = 0
	for 宗 in 世界.其他宗门列表:
		if str(宗.get("区域", "")) != str(世界.宗门区域):
			continue
		临宗 += 1
		var 宗名: String = str(宗.get("名称", ""))
		if not Game.宗门关系.has(宗名):
			continue
		var 关系串: String = str(Game.宗门关系[宗名].get("关系", "中立"))
		if 关系串 == "友好":
			友数 += 1
		elif 关系串 == "敌对":
			敌数 += 1
	_添加说明行(列, "邻近宗门", "%d 宗（盟好 %d · 敌雠 %d）" % [临宗, 友数, 敌数])
	_添加说明行(列, "附近频道", "同域宗门传音")
	for 语 in 世界.获取附近频道(4):
		_添加说明行(列, "　", str(语))

	_添加说明行(列, "说明", "商队运时与风险、宗门战行军与胜率，皆由大地图距离与区域特性推得")

# ===== 操作回调 =====
func _on_通商(城镇ID: String, 名称: String) -> void:
	var 结果: Dictionary = Game.世界地图系统.城镇通商(城镇ID)
	if bool(结果.get("成功", false)):
		_触发事件("通商有成", "与%s通商，得灵石 %d，两地情谊更笃。" % [名称, int(结果.get("收益", 0))], [{"text": "确定", "result": "ok"}])
	else:
		_触发事件("通商未成", str(结果.get("原因", "商路不畅")), [{"text": "确定", "result": "ok"}])

func _on_朝贡(城镇ID: String, 名称: String) -> void:
	var 结果: Dictionary = Game.世界地图系统.城镇朝贡(城镇ID)
	if bool(结果.get("成功", false)):
		_触发事件("朝贡已成", "遣使往%s朝贡，耗灵石 %d，两地情谊渐厚。" % [名称, int(结果.get("消耗", 0))], [{"text": "确定", "result": "ok"}])
	else:
		_触发事件("朝贡未成", str(结果.get("原因", "府库不足")), [{"text": "确定", "result": "ok"}])

func _on_采集(资源点ID: String, 名称: String, x: float, y: float) -> void:
	if 资源点ID == "":
		return
	if x <= 0.0 and y <= 0.0:
		# 总览面板发起：就地采集，不走地图行军动画
		var 结果: Dictionary = Game.世界地图系统.采集资源点(资源点ID)
		if bool(结果.get("成功", false)):
			_触发事件("采集完成", "于%s得%s x%d，已入宗门库藏。" % [名称, str(结果.get("产出", "资源")), int(结果.get("数量", 0))], [{"text": "确定", "result": "ok"}])
		else:
			_触发事件("采集未成", "%s：%s" % [名称, str(结果.get("原因", "此处暂无所得"))], [{"text": "确定", "result": "ok"}])
		_刷新天下总览()
		return
	_派遣队伍(x, y, "采集", 名称, 资源点ID)

func _on_降服(妖兽ID: String) -> void:
	var 战力: int = int(Game.计算宗门总战力())
	var 结果: Dictionary = Game.世界地图系统.尝试降服灵兽(妖兽ID, 战力)
	if bool(结果.get("成功", false)):
		_触发事件("降服成功", "%s 俯首归顺，已入宗门灵兽库。" % str(结果.get("灵兽", "")), [{"text": "确定", "result": "ok"}])
	else:
		_触发事件("降服失利", str(结果.get("原因", "此兽凶悍，降服未成")), [{"text": "确定", "result": "ok"}])
	_刷新天下总览()

func _on_派遣弟子(弟子ID: int) -> void:
	var 结果: Dictionary = Game.世界地图系统.派遣弟子探索(str(弟子ID), 3)
	if bool(结果.get("成功", false)):
		_触发事件("派遣已定", "%s 领命外出，约定 %d 日后归宗。" % [str(结果.get("弟子", "")), int(结果.get("探索天数", 3))], [{"text": "确定", "result": "ok"}])
	else:
		_触发事件("派遣未成", str(结果.get("原因", "无法派遣")), [{"text": "确定", "result": "ok"}])
	_刷新天下总览()

func _on_垂钓(钓点ID: String) -> void:
	var 世界 = Game.世界地图系统
	var 鱼获: Array = 世界.获取钓点鱼获(钓点ID)
	var 名录: Array = []
	for f in 鱼获:
		if f is Dictionary:
			名录.append(str(f.get("名称", "?")))
	var 文: String = "、".join(名录) if not 名录.is_empty() else "钓道尚浅，未明此渊鱼性"
	_触发事件("灵渊垂钓", "此渊可钓 %d 种灵物：%s" % [鱼获.size(), 文], [{"text": "确定", "result": "ok"}])
# ===== P2-3.1 社交联动回调（传音问候 / 缔结盟约 / 下战书）=====
func _on_问候宗门(名称: String) -> void:
	var 世界 = Game.世界地图系统
	if not 世界.has_method("与其他宗门问候"):
		return
	var 果: Dictionary = 世界.与其他宗门问候(名称)
	if bool(果.get("成功", false)):
		UIHint.show_hint(self, "传音问候", "%s 回礼，好感 %+d，今为 %d" % [
			名称, int(果.get("好感变化", 0)), int(果.get("好感度", 0))])
	else:
		UIHint.show_hint(self, "传音问候", "%s：%s" % [名称, str(果.get("原因", "未能通传"))])
	_刷新天下总览()

func _on_结盟宗门(名称: String) -> void:
	var 世界 = Game.世界地图系统
	if not 世界.has_method("与其他宗门结盟"):
		return
	var 果: Dictionary = 世界.与其他宗门结盟(名称)
	if bool(果.get("成功", false)):
		UIHint.show_hint(self, "缔结盟约", str(果.get("效果", "结盟已成")))
	else:
		UIHint.show_hint(self, "缔结盟约", "%s：%s" % [名称, str(果.get("原因", "结盟未成"))])
	_刷新天下总览()

func _on_宣战宗门(名称: String) -> void:
	var 世界 = Game.世界地图系统
	if not 世界.has_method("与其他宗门宣战"):
		return
	var 果: Dictionary = 世界.与其他宗门宣战(名称)
	if bool(果.get("成功", false)):
		UIHint.show_hint(self, "下战书", str(果.get("效果", "已宣战")))
	else:
		UIHint.show_hint(self, "下战书", "%s：%s" % [名称, str(果.get("原因", "宣战未成"))])
	_刷新天下总览()

# ===== P1 联动回调（天下 → 化身 / 风水）=====
func _on_派遣化身(化身ID: int, 区域: String) -> void:
	var 世界 = Game.世界地图系统
	var 结果: Dictionary = 世界.派遣化身赴大地图(化身ID, 区域)
	if not bool(结果.get("成功", false)):
		UIHint.show_hint(self, "派遣化身", str(结果.get("原因", "未能成行")))
		return
	UIHint.show_hint(self, "派遣化身", str(结果.get("消息", "化身已启程")))
	_刷新天下总览()

func _on_迁址(区域: String) -> void:
	var 世界 = Game.世界地图系统
	var x: float = 0.0
	var y: float = 0.0
	for cid in 世界.城镇坐标表.keys():
		if str(世界.城镇坐标表[cid].get("区域", "")) == 区域:
			x = float(世界.城镇坐标表[cid].get("x", 0.0))
			y = float(世界.城镇坐标表[cid].get("y", 0.0))
			break
	var 结果: Dictionary = 世界.迁址至风水地(区域, x, y)
	if not bool(结果.get("成功", false)):
		UIHint.show_hint(self, "宗门迁址", str(结果.get("原因", "未能迁址")))
		return
	var 评: Dictionary = 结果.get("评估", {})
	UIHint.show_hint(self, "宗门迁址", "%s，新址风水%s，修炼%+d%%" % [
		str(结果.get("原因", "已迁址")), str(评.get("评级", "平")), int(float(评.get("修炼差", 0.0)) * 100.0)])
	_刷新天下总览()

func _on_寻宝(弟子ID: int) -> void:
	var 结果: Dictionary = Game.世界地图系统.风水寻宝(弟子ID)
	if bool(结果.get("得宝", false)):
		UIHint.show_hint(self, "堪舆寻宝", "循地脉而行，觅得%s×%d" % [str(结果.get("品类", "")), int(结果.get("数量", 0))])
	else:
		UIHint.show_hint(self, "堪舆寻宝", str(结果.get("消息", "此行空空")))
	_刷新天下总览()

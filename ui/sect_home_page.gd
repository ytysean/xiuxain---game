extends Control

# 宗门主权展示页（01 屏画布 v5 1:1 复刻 · Ardot 2:55，1080×1920 实机基准）。
# 坐标唯一数据源 = compose_v5_framed.py 1080p 实测值，按 UI_SCALE=2.25 反推为逻辑单位。
# 本文件内魔法数字均来自 v5 定稿，禁凭手感改。
# S1 红线：仅展示 + 入口；所有数据只读 Game Autoload，绝不写 GameState / 玩法 / 战斗逻辑。

signal entry_selected(entry_id: String)
signal hide_ui_requested(hidden: bool)
# B7：宗门气象带被点击 → 交由 game_ui 交互层打开抽屉（本页守 S1 红线：纯展示 + 入口）
signal 气象带请求

const RedDotBadge := preload("res://ui/red_dot_badge.gd")

# ───────── v5 定稿：左右侧边入口（149px 金边图标 + 25px 白粗体标签）─────────
const ENTRIES_LEFT: Array = [
	{"id": "天下",     "icon": "entry_tianxia_36"},
	{"id": "宗务", "icon": "entry_zongmenyaowu_36"},
	{"id": "坊市",     "icon": "entry_fangshi_36"},
]
const ENTRIES_RIGHT: Array = [
	{"id": "玄榜",   "icon": "entry_fengyunbang_36"},
	{"id": "宗门典藏",     "icon": "entry_tujian_36"},
	{"id": "碎片宝箱",     "icon": "entry_fragment_chest_36"},
]
const COL_LEFT_X: float = 36.0        # 81 / 2.25
const COL_RIGHT_X: float = 444.0      # 999 / 2.25
const ENTRY_YS: Array = [150.0, 222.0, 294.0, 366.0]  # 间距72px，更紧凑
const ENTRY_SIZE: float = 66.222222   # 149 / 2.25
const ENTRY_ICON_SIZE: float = 66.222222
const ENTRY_FONT: int = 13            # 增大字体，更清晰
const ENTRY_LABEL_H: float = 12.0     # 增大标签高度

# 红点（v5 定稿）：宗务强红点 "2"，宗门典藏弱红点
const RED_DOT_LEFT: Dictionary = {"id": "宗务", "num": "2", "strong": true}
const RED_DOT_RIGHT: Dictionary = {"id": "宗门典藏", "num": "", "strong": false}

# 底部快捷栏红点配置
const QUICK_RED_DOTS: Array = [
	{"id": "库藏", "strong": false},
	{"id": "灵讯", "strong": true},
	{"id": "日供", "strong": false},
]

# ───────── v5 定稿：底部快捷栏（7 项，72px 图标，20px 白粗体标签）─────────
# 顺序 = 库藏 / 灵讯 / 日供 / 宗规 / 道友 / 设置 / 更多
# 「更多」按钮控制折叠：折叠态仅显示「更多」；展开态显示全部 7 项（默认展开，与 v5 设计稿一致）
const QUICK_ENTRIES: Array = [
	{"id": "库藏",     "icon": "entry_kucang_36"},
	{"id": "灵讯", "icon": "entry_feifuchuanxin_36"},
	{"id": "日供", "icon": "entry_qiandao_36"},
	{"id": "设置",     "icon": "entry_shezhi_36"},
	{"id": "更多",     "icon": "entry_more_36", "fold": true},
]
const QUICK_Y: float = 710.0          # 下移，配合底部导航栏收窄
const QUICK_XS: Array = [106.0, 173.0, 240.0, 307.0, 374.0]  # 5个按钮居中显示
const QUICK_BTN_W: float = 32.0  # 调整宽度以容纳9个
const QUICK_BTN_H: float = 44.0       # ~99 / 2.25
const QUICK_ICON_SIZE: float = 30.0   # 调整图标大小
const QUICK_FONT: int = 9             # 20 / 2.25 ≈ 8.9
const QUICK_LABEL_H: float = 9.0

# B8：「更多」面板底部固定入口（宗门舆图）所占高度
const MORE_FOOTER_H: float = 40.0

# ───────── B7：宗门气象带（UX §4.13 · 置于中部留白区；本页只展示 + 抛出信号）─────────
# 纵坐标取 470：左侧入口最底缘 366+33.1=399.1 之下；快捷栏顶缘 710-22=688 之上。
const WEATHER_BAND_X: float = 24.0
const WEATHER_BAND_Y: float = 470.0
const WEATHER_BAND_W: float = 432.0
const WEATHER_BAND_H: float = 40.0
const WEATHER_ROTATE_SEC: float = 4.0    # 心念轮播间隔（秒）
const WEATHER_SHOW_MAX: int = 6          # 参与轮播的最近心念条数

# 更多弹窗入口（从首页和快捷栏移除的入口）
const MORE_ENTRIES: Array = [
	{"id": "宗主管理", "icon": "entry_zongzhuguanli_36"},
	{"id": "幻形", "icon": "entry_huanxing_36"},
	{"id": "功勋", "icon": "entry_gongxunbei_36"},
	{"id": "宗规", "icon": "entry_zongmenguizhi_36"},
	{"id": "道友", "icon": "entry_daoyou_36"},
	{"id": "阵营声望", "icon": "entry_fengyunbang_36"},
	{"id": "宗门战", "icon": "entry_zongmen_battle_new_36"},
	{"id": "傀儡", "icon": "entry_puppet_36"},
	{"id": "藏书阁", "icon": "entry_library_36"},
	{"id": "药园", "icon": "entry_herb_garden_36"},
	{"id": "丹方", "icon": "entry_pill_formula_36"},
	{"id": "装备图纸", "icon": "entry_equipment_blueprint_36"},
	{"id": "活动中心", "icon": "entry_activity_36"},
	{"id": "宗门气运", "icon": "entry_sect_qi_new_36"},
	{"id": "凡人王朝", "icon": "entry_dynasty_36"},
	{"id": "拍卖行", "icon": "entry_auction_36"},
	{"id": "商道", "icon": "entry_fangshi_36"},
	{"id": "传送阵", "icon": "entry_teleport_36"},
	{"id": "家族", "icon": "entry_family_36"},
	{"id": "法宝", "icon": "entry_treasure_36"},
	{"id": "科技", "icon": "entry_tech_36"},
	{"id": "灵兽", "icon": "entry_beast_new_36"},
	{"id": "宗主", "icon": "entry_master_36"},
	{"id": "祖师堂", "icon": "entry_zushitang_36"},
	{"id": "功绩堂", "icon": "entry_gongjitang_36"},
	{"id": "身外化身", "icon": "entry_huashen_36"},
	{"id": "入山采撷", "icon": "entry_ruishan_36"},
	{"id": "闲情雅趣", "icon": "entry_xianqing_36"},
	{"id": "论道棋弈", "icon": "entry_lundao_36"},
	{"id": "毒道", "icon": "entry_dudao_36"},
	{"id": "飞升", "icon": "entry_feisheng_36"},
	{"id": "护道人", "icon": "entry_hudao_36"},
	{"id": "机缘", "icon": "entry_qiyuan_36"},
	{"id": "灵酿", "icon": "entry_lingniang_36"},
	{"id": "音律", "icon": "entry_yinlv_36"},
	{"id": "风水堪舆", "icon": "entry_fengshui_36"},
]

# ───────── §3.3 更多面板主题分组（G1–G6，36 入口全覆盖；组数 ≤6、组内 ≤8）─────────
# 分组依据「玩家找东西的直觉」而非解锁阶段（UX 总纲 §3.3 / R1）。
# 组内入口仍走 _过滤已解锁（唯一 gating 来源）；整组无可见入口 → 整组不建。
# 组标题常显、组内容默认折叠（避免一屏 36 项按钮墙）。
const MORE_GROUPS: Array = [
	{"组名": "宗门经营", "入口": ["宗门气运", "凡人王朝", "传送阵", "风水堪舆", "灵酿", "科技"]},
	{"组名": "弟子养成", "入口": ["家族", "护道人", "身外化身", "毒道", "宗主管理", "宗主", "幻形"]},
	{"组名": "生产技艺", "入口": ["药园", "丹方", "装备图纸", "傀儡", "藏书阁", "灵兽"]},
	{"组名": "对外关系", "入口": ["阵营声望", "宗门战", "拍卖行", "活动中心", "道友", "商道"]},
	{"组名": "休闲雅趣", "入口": ["闲情雅趣", "论道棋弈", "机缘", "音律", "入山采撷"]},
	{"组名": "传承与荣誉", "入口": ["祖师堂", "功绩堂", "功勋", "宗规", "法宝", "飞升"]},
]

# ───────── 幻形·洞天换肤：皮肤 id → 宗门首页背景图路径 ─────────
const SKIN_BG: Dictionary = {
	"taixu_yunhai": "res://art/backgrounds/home_bg_sect_a.png",
	"chun_qinglan": "res://art/backgrounds/home_bg_season_spring.png",
	"xia_bihe":     "res://art/backgrounds/home_bg_season_summer.png",
	"qiu_jinfeng":  "res://art/backgrounds/home_bg_season_autumn.png",
	"dong_xueji":   "res://art/backgrounds/home_bg_season_winter.png",
	"xian_jiuqiao": "res://art/backgrounds/home_bg_season_immortal.png",
}

# ───────── 节点引用 ─────────
var _scene_root: Control = null
var _chrome: Control = null
var _hidden_ui: bool = false

# 快捷栏折叠状态
var _quick_folded: bool = false
var _quick_buttons: Dictionary = {}   # id -> Button
var _quick_icons: Dictionary = {}     # id -> TextureRect（日供动态图标用）
var _quick_labels: Dictionary = {}    # id -> Label

var _bg: TextureRect = null
var _more_panel: Control = null

# B7 宗门气象带节点引用（纯展示）
var _气象带: Button = null
var _气象文本: Label = null
var _气象红点: Control = null
var _气象轮播: Array = []
var _气象序号: int = 0
var _气象定时器: Timer = null

func _ready() -> void:
	_build()
	refresh()
	# 连接邮件变动信号，自动刷新灵讯红点
	if Game != null and Game.has_signal("邮件变动"):
		Game.邮件变动.connect(_refresh_red_dots, CONNECT_DEFERRED)

# ───────── 构建 ─────────
func _build() -> void:
	_scene_root = Control.new()
	_scene_root.name = "SceneRoot"
	_place(_scene_root, 0.0, -UITheme.TOPBAR_H / UITheme.UI_SCALE, 480.0, 854.0)
	_scene_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene_root)

	_build_base_and_bg()
	_build_chrome()
	_build_eye()

# 底色 + 山门主视觉背景图
func _build_base_and_bg() -> void:
	var base := ColorRect.new()
	base.name = "SceneBase"
	_place(base, 0.0, 0.0, 480.0, 854.0)
	base.color = UITheme.C01_SCENE_BASE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_root.add_child(base)

	var bg := TextureRect.new()
	bg.name = "BG"
	_place(bg, 0.0, 0.0, 480.0, 854.0)
	bg.texture = _load_bg_texture("res://art/backgrounds/home_bg_sect_a.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_root.add_child(bg)
	_bg = bg
	_apply_equipped_skin()

func _load_bg_texture(path: String) -> Texture2D:
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		return tex
	var img: Image = Image.load_from_file(path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

# 可隐藏浮层：左右入口 + 底部快捷栏
func _build_chrome() -> void:
	_chrome = Control.new()
	_chrome.name = "Chrome"
	_place(_chrome, 0.0, 0.0, 480.0, 854.0)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_root.add_child(_chrome)

	_build_entries()
	_build_quick_bar()
	_build_weather_band()

# v5 左右入口：图标 + 白字标签，无额外面板底
func _build_entries() -> void:
	var 左可见: Array = _过滤已解锁(ENTRIES_LEFT)
	for i in range(左可见.size()):
		_make_entry(左可见[i], COL_LEFT_X, ENTRY_YS[i])
	var 右可见: Array = _过滤已解锁(ENTRIES_RIGHT)
	for i in range(右可见.size()):
		_make_entry(右可见[i], COL_RIGHT_X, ENTRY_YS[i])
	_make_red_dots()

## P0-1 洋葱式解锁：过滤出「已解锁」入口（fold 折叠按钮恒保留）。
## 三个容器（侧边入口 / 快捷栏 /「更多」面板）共用此单一来源：
## 位置一律按「可见序号」紧凑排布，隐藏语义一致、不留空洞。
## 与布局解耦：重构 UI 只需替换坐标算法，不必再碰 gating 逻辑。
func _过滤已解锁(配置表: Array) -> Array:
	var 结果: Array = []
	for cfg in 配置表:
		if bool(cfg.get("fold", false)) or SystemUnlock.入口可显示(String(cfg["id"])):
			结果.append(cfg)
	return 结果

## 某入口在「已解锁入口表」中的可见序号（红点需据此与宿主图标对齐）；未解锁/不存在 → -1。
func _可见序号(全量表: Array, id: String) -> int:
	var 可见表: Array = _过滤已解锁(全量表)
	for i in range(可见表.size()):
		if String(可见表[i]["id"]) == id:
			return i
	return -1

func _make_entry(cfg: Dictionary, cx: float, cy: float) -> void:
	var id: String = cfg["id"]
	var x: float = cx - ENTRY_SIZE * 0.5
	var y: float = cy - ENTRY_SIZE * 0.5

	# 热区：覆盖 149px 图标圆
	var btn := Button.new()
	btn.name = "Entry_" + id
	btn.flat = true
	btn.text = ""
	_place(btn, x, y, ENTRY_SIZE, ENTRY_SIZE)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_entry_pressed.bind(id))
	_chrome.add_child(btn)

	# 金边图标：等比居中铺满热区
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = UITheme.load_hd_icon(cfg["icon"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(icon, 0.0, 0.0, ENTRY_ICON_SIZE, ENTRY_ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	# 标签：移到图标内部底部边缘（再向上收 6 逻辑单位，完全落入金边内暗色区），作为按钮子节点置顶显示
	var lbl: Label = _mk_label_in(btn, "Label_" + id, id,
		0.0, ENTRY_SIZE - ENTRY_LABEL_H - 6.0, ENTRY_SIZE, ENTRY_LABEL_H,
		ENTRY_FONT, UITheme.C01_TEXT_PRIMARY, true,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true)
	lbl.z_index = 10
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))

func _make_red_dots() -> void:
	# P0-1：红点跟随宿主入口的「可见序号」，入口未解锁则不建红点（避免红点飘在空位上）
	var 左idx: int = _可见序号(ENTRIES_LEFT, String(RED_DOT_LEFT["id"]))
	if 左idx >= 0:
		_make_red_dot(RED_DOT_LEFT, COL_LEFT_X, 左idx)
	var 右idx: int = _可见序号(ENTRIES_RIGHT, String(RED_DOT_RIGHT["id"]))
	if 右idx >= 0:
		_make_red_dot(RED_DOT_RIGHT, COL_RIGHT_X, 右idx)
	# 初始化后刷新红点状态
	_refresh_red_dots()

## 创建底部快捷栏红点
func _make_quick_red_dots() -> void:
	for cfg in QUICK_RED_DOTS:
		var id: String = cfg["id"]
		# 红点跟随宿主按钮的「可见序号」（未解锁 → -1，自然跳过）
		var idx: int = _可见序号(QUICK_ENTRIES, id)
		if idx < 0:
			continue

		# 红点位置：快捷栏按钮右上角
		var btn_x: float = QUICK_XS[idx]
		var btn_y: float = QUICK_Y
		var dot_offset_x: float = QUICK_BTN_W * 0.4
		var dot_offset_y: float = -QUICK_BTN_H * 0.3

		var dot: Panel
		if cfg["strong"]:
			dot = UITheme.make_red_dot_number(0, 16.0)
		else:
			dot = UITheme.make_red_dot(12.0)
		dot.name = "QuickRedDot_" + id
		var dot_size: Vector2 = dot.custom_minimum_size
		_place(dot, btn_x + dot_offset_x - dot_size.x / 2, btn_y + dot_offset_y - dot_size.y / 2, dot_size.x, dot_size.y)
		_chrome.add_child(dot)
		dot.visible = false

## 刷新红点状态（根据游戏数据动态显示/隐藏，带动画效果）
func _refresh_red_dots() -> void:
	# 宗务红点：新手目标有未完成项时显示
	var 宗务红点 = _chrome.get_node_or_null("RedDot_宗务")
	if 宗务红点 != null and Game != null and Game.has_method("新手_有红点"):
		var 应该显示: bool = bool(Game.新手_有红点())
		if 应该显示 and not 宗务红点.visible:
			UITheme.animate_red_dot_appear(宗务红点)
		elif not 应该显示 and 宗务红点.visible:
			UITheme.animate_red_dot_disappear(宗务红点)
	# 图录红点：暂时隐藏，等确认状态条件后再添加
	var 图录红点 = _chrome.get_node_or_null("RedDot_图录")
	if 图录红点 != null and 图录红点.visible:
		UITheme.animate_red_dot_disappear(图录红点)

	# 日供红点：今日可领取时显示
	var 日供红点 = _chrome.get_node_or_null("QuickRedDot_日供")
	if 日供红点 != null and Game != null and Game.has_method("日供_今日可领"):
		var 应该显示: bool = bool(Game.日供_今日可领())
		if 应该显示 and not 日供红点.visible:
			UITheme.animate_red_dot_appear(日供红点)
		elif not 应该显示 and 日供红点.visible:
			UITheme.animate_red_dot_disappear(日供红点)

	# 灵讯红点：有未读邮件时显示
	var 灵讯红点 = _chrome.get_node_or_null("QuickRedDot_灵讯")
	if 灵讯红点 != null and Game != null and "邮件列表" in Game:
		var 未读数: int = 0
		var 邮件列表 = Game.邮件列表
		if 邮件列表 != null:
			for 邮件 in 邮件列表:
				if 邮件 != null and 邮件.has("未读") and bool(邮件["未读"]):
					未读数 += 1
		var 应该显示: bool = 未读数 > 0
		if 应该显示 and not 灵讯红点.visible:
			UITheme.animate_red_dot_appear(灵讯红点)
		elif not 应该显示 and 灵讯红点.visible:
			UITheme.animate_red_dot_disappear(灵讯红点)

	# 库藏红点：暂时隐藏，等确认有新物品的判断条件后再添加
	var 库藏红点 = _chrome.get_node_or_null("QuickRedDot_库藏")
	if 库藏红点 != null and 库藏红点.visible:
		UITheme.animate_red_dot_disappear(库藏红点)

## y_idx = 宿主入口的「可见序号」（由 _可见序号 求得，与 _build_entries 的排布同源）
func _make_red_dot(cfg: Dictionary, col_x: float, y_idx: int) -> void:
	var id: String = cfg["id"]
	if y_idx < 0 or y_idx >= ENTRY_YS.size():
		return

	# 红点统一压在图标右上角：中心相对图标中心偏移约 0.42 倍图标尺寸
	var cx: float = col_x
	var cy: float = ENTRY_YS[y_idx]
	var dot_offset: float = ENTRY_SIZE * 0.42
	var dot_cx: float = cx + dot_offset
	var dot_cy: float = cy - dot_offset

	# 使用统一红点样式：强红点显示数字，弱红点显示圆点
	var dot: Panel
	if cfg["strong"]:
		dot = UITheme.make_red_dot_number(int(cfg.get("num", "0")), 20.0)
	else:
		dot = UITheme.make_red_dot(14.0)
	dot.name = "RedDot_" + id
	var dot_size: Vector2 = dot.custom_minimum_size
	_place(dot, dot_cx - dot_size.x / 2, dot_cy - dot_size.y / 2, dot_size.x, dot_size.y)
	_chrome.add_child(dot)
	# 初始隐藏，由_refresh_red_dots控制显示
	dot.visible = false

# ───────── B7：宗门气象带（纯展示 + 入口 · 守 S1 红线）─────────
## 中部留白区一条「宗门气象」滚动带：门人最新心念轮播 + 待批传讯红点。
## 本页只读 Game 并抛出信号；抽屉（含批复写操作）由 game_ui 交互层承载。
func _build_weather_band() -> void:
	var btn := Button.new()
	btn.name = "WeatherBand"
	btn.flat = true
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	_place(btn, WEATHER_BAND_X, WEATHER_BAND_Y, WEATHER_BAND_W, WEATHER_BAND_H)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_weather_band_pressed)
	_chrome.add_child(btn)
	_气象带 = btn

	# 半透明青玉底 + 金线描边（复用更多面板同款底/边，禁硬编码色）
	var 底 := Panel.new()
	底.name = "BandBG"
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(底, 0.0, 0.0, WEATHER_BAND_W, WEATHER_BAND_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.C01_PANEL_B
	sb.set_corner_radius_all(int(round(6.0 * UITheme.UI_SCALE)))
	sb.set_border_width_all(1)
	sb.border_color = UITheme.C01_GOLD_LINE
	底.add_theme_stylebox_override("panel", sb)
	btn.add_child(底)

	# 左：栏目名（金色）
	_mk_label_in(btn, "BandTitle", "宗门气象",
		10.0, 0.0, 68.0, WEATHER_BAND_H,
		12, UITheme.C01_TEXT_GOLD, true,
		HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, true)

	# 中：心念轮播文本（二级文字，超长裁剪）
	_气象文本 = _mk_label_in(btn, "BandText", "",
		82.0, 0.0, WEATHER_BAND_W - 82.0 - 34.0, WEATHER_BAND_H,
		11, UITheme.C01_TEXT_SECONDARY, false,
		HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, false)

	# 右：待批传讯红点（复用统一红点控件，初始隐藏）
	var dot: Panel = UITheme.make_red_dot_number(0, 18.0)
	dot.name = "BandRedDot"
	_place(dot, WEATHER_BAND_W - 26.0, (WEATHER_BAND_H - 18.0) * 0.5, 18.0, 18.0)
	btn.add_child(dot)
	dot.visible = false
	_气象红点 = dot

	# 轮播定时器
	_气象定时器 = Timer.new()
	_气象定时器.name = "WeatherTimer"
	_气象定时器.wait_time = WEATHER_ROTATE_SEC
	_气象定时器.autostart = true
	_气象定时器.timeout.connect(_气象轮播下一条)
	add_child(_气象定时器)

	_refresh_weather_band()

## 只读刷新：拉取最近心念形成轮播文案 + 待批传讯数（绝不写 Game）
func _refresh_weather_band() -> void:
	if _气象文本 == null:
		return
	# 心念：最近 N 条（数组最新在 [0]）
	_气象轮播 = []
	var ms = Game.get("消息系统") if is_instance_valid(Game) else null
	if ms != null and ms.has_method("获取宗门聊天"):
		var 记录: Array = ms.获取宗门聊天(WEATHER_SHOW_MAX)
		for m in 记录:
			var 内容: String = str(m.get("内容", ""))
			if 内容.is_empty():
				continue
			var 前缀: String = "宗主" if bool(m.get("是玩家", false)) else str(m.get("发送者", ""))
			_气象轮播.append("%s：%s" % [前缀, 内容])
	if _气象轮播.is_empty():
		_气象文本.text = "门人静默，山门无事"
	else:
		if _气象序号 >= _气象轮播.size():
			_气象序号 = 0
		_气象文本.text = String(_气象轮播[_气象序号])
	# 红点：待批传讯数（只读）
	var 待批: int = 0
	if is_instance_valid(Game) and Game.has_method("待处理传讯数量"):
		待批 = int(Game.待处理传讯数量())
	if _气象红点 != null:
		var 显示: bool = 待批 > 0
		_气象红点.visible = 显示
		if 显示:
			var 文本: String = "99+" if 待批 > 99 else str(待批)
			var 宽: float = 18.0 + 8.0 * float(文本.length())
			_place(_气象红点, WEATHER_BAND_W - 8.0 - 宽, (WEATHER_BAND_H - 18.0) * 0.5, 宽, 18.0)
			var lbl := _气象红点.get_node_or_null("Num")
			if lbl is Label:
				(lbl as Label).text = 文本

## 心念轮播下一条（定时器回调）
func _气象轮播下一条() -> void:
	if _气象轮播.is_empty() or _气象文本 == null:
		return
	_气象序号 = (_气象序号 + 1) % _气象轮播.size()
	_气象文本.text = String(_气象轮播[_气象序号])

func _on_weather_band_pressed() -> void:
	气象带请求.emit()

# v5 底部快捷栏
func _build_quick_bar() -> void:
	# P0-1：过滤后按「可见序号」紧凑排布（「更多」折叠按钮由 _过滤已解锁 恒保留）
	var 可见表: Array = _过滤已解锁(QUICK_ENTRIES)
	for i in range(可见表.size()):
		_make_quick_entry(可见表[i], i)
	_make_quick_red_dots()
	_refresh_quick_icons()
	_apply_quick_fold()

func _make_quick_entry(cfg: Dictionary, idx: int) -> void:
	var id: String = cfg["id"]
	var is_fold_btn: bool = cfg.get("fold", false)
	var x: float = QUICK_XS[idx] - QUICK_BTN_W * 0.5
	var y: float = QUICK_Y

	var btn := Button.new()
	btn.name = "Quick_" + id
	btn.flat = true
	btn.text = ""
	_place(btn, x, y, QUICK_BTN_W, QUICK_BTN_H)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_fold_btn:
		btn.pressed.connect(_on_quick_fold_toggle)
	else:
		btn.pressed.connect(_on_entry_pressed.bind(id))
	_chrome.add_child(btn)
	_quick_buttons[id] = btn

	var icon := TextureRect.new()
	icon.name = "Icon"
	var icon_x: float = (QUICK_BTN_W - QUICK_ICON_SIZE) * 0.5
	# 图标中心落在 qy+31 屏幕（即逻辑 QUICK_Y + 13.78）
	var icon_y: float = -2.222222
	_place(icon, icon_x, icon_y, QUICK_ICON_SIZE, QUICK_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	_quick_icons[id] = icon

	# 标签：移到图标内部底部边缘（再向上收 4 逻辑单位），作为按钮子节点置顶显示
	var label: Label = _mk_label_in(btn, "Label_" + id, id,
		0.0, QUICK_BTN_H - QUICK_LABEL_H - 4.0, QUICK_BTN_W, QUICK_LABEL_H,
		QUICK_FONT, UITheme.C01_TEXT_PRIMARY, true,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true)
	label.z_index = 10
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_quick_labels[id] = label

func _on_quick_fold_toggle() -> void:
	if _more_panel == null:
		_build_more_panel()
	_more_panel.visible = not _more_panel.visible

func _apply_quick_fold() -> void:
	for i in range(QUICK_ENTRIES.size()):
		var cfg: Dictionary = QUICK_ENTRIES[i]
		var id: String = cfg["id"]
		var is_fold: bool = cfg.get("fold", false)
		var btn: Button = _quick_buttons.get(id, null)
		if btn == null:
			continue
		var visible: bool = is_fold if _quick_folded else true
		btn.visible = visible
		var lbl: Label = _quick_labels.get(id, null) as Label
		if lbl != null:
			lbl.visible = visible
	var more_icon: TextureRect = _quick_icons.get("更多", null) as TextureRect
	if more_icon != null:
		more_icon.flip_h = _quick_folded

# 构建更多弹窗（§3.3 分组治理：G1–G6 主题分组；组标题常显、组内默认折叠、组内受 gating）
func _build_more_panel() -> void:
	# 半透明背景，点击后关闭弹窗
	var bg := ColorRect.new()
	bg.name = "MoreBG"
	_place(bg, 0.0, 0.0, 480.0, 854.0)
	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_more_bg_input)
	_scene_root.add_child(bg)

	# 弹窗面板（加高以容纳 6 组；改用 UITheme 底色 + 金线描边，替换原裸 Panel）
	var panel := Panel.new()
	panel.name = "MorePanel"
	var panel_w: float = 420.0
	var panel_h: float = 664.0
	var panel_x: float = (480.0 - panel_w) * 0.5
	var panel_y: float = (854.0 - panel_h) * 0.5
	_place(panel, panel_x, panel_y, panel_w, panel_h)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var 面板底色 := StyleBoxFlat.new()
	面板底色.bg_color = UITheme.C01_PANEL_B
	面板底色.set_corner_radius_all(int(round(8.0 * UITheme.UI_SCALE)))
	面板底色.set_border_width_all(1)
	面板底色.border_color = UITheme.C01_GOLD_LINE
	panel.add_theme_stylebox_override("panel", 面板底色)
	bg.add_child(panel)

	# 标题
	var title := Label.new()
	title.name = "Title"
	title.text = "更多功能"
	title.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(title, 0.0, 12.0, panel_w, 28.0)
	panel.add_child(title)

	# 滚动容器：6 组全部展开时可滚动，避免溢出
	var scroll := ScrollContainer.new()
	scroll.name = "MoreScroll"
	_place(scroll, 12.0, 48.0, panel_w - 24.0, panel_h - 60.0 - MORE_FOOTER_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.name = "MoreGroups"
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)

	# 逐组渲染：组内仍走 _过滤已解锁（唯一 gating 来源）；整组无可见入口 → 整组不建
	for grp in MORE_GROUPS:
		var 组配置: Array = []
		for eid in grp["入口"]:
			var sid: String = String(eid)
			组配置.append({"id": sid, "icon": _更多入口图标(sid)})
		var 可见: Array = _过滤已解锁(组配置)
		if 可见.is_empty():
			continue
		_make_more_group(vb, String(grp["组名"]), 可见)

	# B8：底部固定入口「宗门舆图」——不随分组折叠，永在「更多」面板末尾（UX §4.8 F1）
	var foot := Button.new()
	foot.name = "MoreAtlasBtn"
	foot.text = "宗门舆图 · 全法门索引"
	foot.custom_minimum_size = Vector2(0.0, MORE_FOOTER_H - 8.0)
	foot.focus_mode = Control.FOCUS_NONE
	foot.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	foot.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	UITheme.apply_secondary_button_style(foot)
	foot.pressed.connect(_on_more_atlas_pressed)
	_place(foot, 12.0, panel_h - MORE_FOOTER_H - 4.0, panel_w - 24.0, MORE_FOOTER_H - 8.0)
	panel.add_child(foot)

	_more_panel = bg
	_more_panel.visible = false

## §3.3：单个主题组 = 组标题（常显，点击折叠/展开）+ 组内 3 列入口网格（默认折叠）
func _make_more_group(parent: VBoxContainer, 组名: String, 可见: Array) -> void:
	var box := VBoxContainer.new()
	box.name = "MoreGroup_" + 组名
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)

	var head := Button.new()
	head.name = "MoreGroupHead_" + 组名
	head.text = "%s（%d）" % [组名, 可见.size()]
	head.custom_minimum_size = Vector2(0.0, 34.0)
	head.focus_mode = Control.FOCUS_NONE
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	head.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	box.add_child(head)

	var grid := GridContainer.new()
	grid.name = "MoreGroupGrid_" + 组名
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.visible = false
	box.add_child(grid)

	head.pressed.connect(func() -> void: grid.visible = not grid.visible)

	for cfg in 可见:
		_make_more_entry(grid, cfg)

## 更多面板入口按钮（3 列网格单元；位置由 GridContainer 自动排布，不再手算坐标）
func _make_more_entry(parent: GridContainer, cfg: Dictionary) -> void:
	var id: String = String(cfg["id"])
	var btn_w: float = 120.0
	var btn_h: float = 78.0
	var btn := Button.new()
	btn.name = "MoreBtn_" + id
	btn.flat = true
	btn.text = ""
	btn.custom_minimum_size = Vector2(btn_w, btn_h)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_more_entry_pressed.bind(id))
	parent.add_child(btn)

	# 图标
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = UITheme.load_hd_icon(String(cfg["icon"]))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(icon, (btn_w - 40.0) * 0.5, 4.0, 40.0, 40.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	# 标签
	var label := Label.new()
	label.name = "Label"
	label.text = id
	label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	label.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(label, 0.0, btn_h - 24.0, btn_w, 20.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(label)

## 更多面板入口 id → 图标 stem（唯一数据源 MORE_ENTRIES；缺项回退「更多」图标）
func _更多入口图标(id: String) -> String:
	for cfg in MORE_ENTRIES:
		if String(cfg["id"]) == id:
			return String(cfg["icon"])
	return "entry_more_36"

func _on_more_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_more_panel.visible = false

func _on_more_entry_pressed(id: String) -> void:
	_more_panel.visible = false
	entry_selected.emit(id)

# B8：更多面板底部「宗门舆图」固定入口（本页守 S1 红线：只抛信号，不碰玩法）
func _on_more_atlas_pressed() -> void:
	_more_panel.visible = false
	entry_selected.emit("宗门舆图")

func _refresh_quick_icons() -> void:
	for cfg in QUICK_ENTRIES:
		var id: String = cfg["id"]
		var icon: TextureRect = _quick_icons.get(id, null) as TextureRect
		if icon == null:
			continue
		var stem: String = cfg["icon"]
		if id == "日供":
			var 可领: bool = true
			if is_instance_valid(Game) and Game.has_method("日供_今日可领"):
				可领 = bool(Game.日供_今日可领())
			stem = "entry_qiandao_36" if 可领 else "entry_qiandao_36_done"
		icon.texture = UITheme.load_hd_icon(stem)

# 隐藏UI开关：仅图标，无底框无文字，放在声望下方紧邻框体
func _build_eye() -> void:
	var sz: float = 22.0   # 按钮热区大小（稍大一点，更容易点击）
	var icon_sz: float = 18.0  # 图标视觉大小
	var cx: float = 440.0  # 对齐声望图标中心（440）
	var x: float = cx - sz * 0.5
	var btn := Button.new()
	btn.name = "HideUIBtn"
	btn.flat = true
	btn.text = ""
	_place(btn, x, 84.0, sz, sz)  # y=84，完全在资源栏下方（CONTAINER_H=84）
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.z_index = 1000  # 设置很高的z_index，确保在最上层可点击
	var empty_sb := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("pressed", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)
	btn.pressed.connect(_on_hide_ui_pressed)

	var eye_icon := TextureRect.new()
	eye_icon.name = "EyeIcon"
	eye_icon.texture = UITheme.load_hd_icon("ui_hide_36")
	eye_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	eye_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 图标居中显示在按钮内，比按钮稍小，视觉上更精致
	var icon_x: float = (sz - icon_sz) * 0.5
	var icon_y: float = (sz - icon_sz) * 0.5
	_place(eye_icon, icon_x, icon_y, icon_sz, icon_sz)
	eye_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(eye_icon)

	# 添加到 _scene_root 中（永远可见，不会被 _chrome 的隐藏影响）
	_scene_root.add_child(btn)

# ───────── helper ─────────
func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	var s: float = UITheme.UI_SCALE
	c.layout_mode = 0
	c.offset_left = x * s
	c.offset_top = y * s
	c.offset_right = (x + w) * s
	c.offset_bottom = (y + h) * s
	c.size = Vector2(w * s, h * s)

func _mk_label_in(parent: Control, nm: String, txt: String, x: float, y: float, w: float, h: float,
		font_size: int, color: Color, bold: bool,
		align_h: int, align_v: int, shadow: bool) -> Label:
	var lbl := Label.new()
	lbl.name = nm
	lbl.text = txt
	_place(lbl, x, y, w, h)
	lbl.horizontal_alignment = align_h
	lbl.vertical_alignment = align_v
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = true
	var fsz: int = int(round(float(font_size) * UITheme.UI_SCALE))
	if bold:
		UITheme.apply_title_font_sized(lbl, fsz)
	else:
		UITheme.apply_body_font_sized(lbl, fsz)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	if shadow:
		var sh := Label.new()
		sh.name = nm + "_shadow"
		sh.text = txt
		_place(sh, x + 1.0, y + 1.0, w, h)
		sh.horizontal_alignment = align_h
		sh.vertical_alignment = align_v
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.clip_text = true
		if bold:
			UITheme.apply_title_font_sized(sh, fsz)
		else:
			UITheme.apply_body_font_sized(sh, fsz)
		sh.add_theme_color_override("font_color", UITheme.C01_SHADOW)
		parent.add_child(sh)
		parent.move_child(lbl, parent.get_child_count() - 1)
	return lbl

# ───────── 交互 ─────────
func _on_entry_pressed(entry_id: String) -> void:
	entry_selected.emit(entry_id)

func _on_hide_ui_pressed() -> void:
	_hidden_ui = !_hidden_ui
	if _chrome != null:
		_chrome.visible = !_hidden_ui
	hide_ui_requested.emit(_hidden_ui)

func set_chrome_visible(visible: bool) -> void:
	if _chrome != null and is_instance_valid(_chrome):
		_chrome.visible = visible

# ───────── 只读刷新 ─────────
func refresh() -> void:
	_apply_equipped_skin()
	_refresh_quick_icons()
	_refresh_red_dots()
	_refresh_weather_band()

func _apply_equipped_skin() -> void:
	if _bg == null:
		return
	var skin_id: String = "taixu_yunhai"
	if is_instance_valid(Game):
		var raw = Game.get("当前皮肤")
		if raw != null:
			skin_id = String(raw)
	var path: String = SKIN_BG.get(skin_id, "res://art/backgrounds/home_bg_sect_a.png")
	var tex: Texture2D = _load_bg_texture(path)
	if tex == null:
		tex = _load_bg_texture("res://art/backgrounds/home_bg_sect_a.png")
	if tex == null:
		return
	_bg.texture = tex
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

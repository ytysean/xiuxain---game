extends Control

# 宗门主权展示页（01 屏画布 v5 1:1 复刻 · Ardot 2:55，1080×1920 实机基准）。
# 坐标唯一数据源 = compose_v5_framed.py 1080p 实测值，按 UI_SCALE=2.25 反推为逻辑单位。
# @ui-space: logical —— 本文件是「480×854 逻辑空间孤岛」：几何一律写逻辑单位，
#   由 _place() 统一 ×UI_SCALE 落到 1080 真实树。故本文件内出现
#   `UITheme.XXX / UITheme.UI_SCALE` 是**把 1080 终值反推为逻辑单位的合法换算**，
#   不是口径混用（扫描器 audit_ui.py 依此标记判定，勿删该行）。
# 本文件内魔法数字均来自 v5 定稿，禁凭手感改。
# S1 红线：仅展示 + 入口；所有数据只读 Game Autoload，绝不写 GameState / 玩法 / 战斗逻辑。

signal entry_selected(entry_id: String)
signal hide_ui_requested(hidden: bool)
# B7：宗门气象带被点击 → 交由 game_ui 交互层打开抽屉（本页守 S1 红线：纯展示 + 入口）
signal 气象带请求
# P0-5 定稿：首页新信息面（时令横幅 / 传讯栏 / 快照卡）→ 一律抛信号，写操作留 game_ui 交互层
signal 时令横幅请求
signal 传讯栏请求
signal 快照卡请求(卡键: String)
# 测灵大典活动窗：首页常驻小窗，点击 → 交由 game_ui 交互层打开测灵大典面板
signal 测灵大典请求

const RedDotBadge := preload("res://ui/red_dot_badge.gd")

# ───────── ★ S3（2026-09-17）：左右侧边入口列与列红点已整体退役 ─────────
# ENTRIES_LEFT / ENTRIES_RIGHT / COL_LEFT_X / COL_RIGHT_X / ENTRY_YS / ENTRY_SIZE /
#   ENTRY_ICON_SIZE / ENTRY_FONT / ENTRY_LABEL_H / RED_DOT_LEFT 全部删除；
# 6 入口（天下/宗务/坊市/玄榜/宗门典藏/碎片宝箱）并入 MORE_ENTRIES ＋ MORE_GROUPS，
# 主视觉窗改由「更多」面板承载。红点仅保留 dock 的 QUICK_RED_DOTS（下方）。

# 底部快捷栏红点配置（C1：删「库藏」恒隐死配置）
const QUICK_RED_DOTS: Array = [
	{"id": "灵讯", "strong": true},
	{"id": "日供", "strong": false},
]

# ───────── 底部 dock（7 项：库藏 / 灵讯 / 日供 / 幻形 / 设置 / 隐藏UI / 更多）─────────
# 重排 2026-09-15：「幻形」从「更多 → 弟子养成」深层提升进 dock（换肤是一级高频操作）。
# 2026-09-16：「隐藏UI」图标从右边缘浮标移入 dock，放到「更多」前面，降低发现成本。
# 「更多」按钮控制折叠：折叠态仅显示「更多」；展开态显示全部 7 项。
const QUICK_ENTRIES: Array = [
	{"id": "库藏",     "icon": "entry_kucang_36"},
	{"id": "灵讯", "icon": "entry_feifuchuanxin_36"},
	{"id": "日供", "icon": "entry_qiandao_36"},
	{"id": "幻形", "icon": "entry_huanxing_36"},
	{"id": "设置",     "icon": "entry_shezhi_36"},
	{"id": "隐藏UI", "icon": "ui_hide_36"},
	{"id": "更多",     "icon": "entry_more_36", "fold": true},
]
const QUICK_Y: float = 700.0          # 按钮顶边；底座中心 = QUICK_Y + QUICK_BTN_H * 0.5
# QUICK_XS（静态槽位数组）已于 S3 退役：dock 走 _算dock中心列(可见表.size()) 动态复算
const QUICK_BTN_W: float = 32.0  # 调整宽度以容纳9个
const QUICK_BTN_H: float = 48.0       # 108 / 2.25（P1-A C2：44→48）
const QUICK_ICON_SIZE: float = 30.0   # 调整图标大小
const QUICK_FONT: int = 10            # 23 / 2.25 ≈ 10.2（P1-A C1：9→10）
const QUICK_LABEL_H: float = 16.0   # P1-A C2 校准：9→16（框高须 > fontH34）

# ★ M2（P1-A）：红点角标锚点中心 meta 键。必须 ASCII —— 中文 meta 键在 Godot 4 静默失效
#   （set_meta 报 `Invalid metadata identifier`；同 ui_theme.gd META_* 族：名中文、值 ASCII）。
const META_红点锚cx: String = "_red_dot_ancx"
const META_红点锚cy: String = "_red_dot_ancy"

# B8：「更多」面板底部固定入口（宗门舆图）所占高度
const MORE_FOOTER_H: float = 40.0

# ───────── 重排 2026-09-15：去面板化终版 ─────────
# 「宗门中枢」一板四段（222 高实心面板）拆散为三件悬浮薄玻璃，主视觉 70–560 连续：
#   时令胶囊（74.7 起，34 高）/ 宗门气象带（476，30 高玻璃带）/ 运转快照条（516，38 高单行）。
# 传讯并入主 CTA（临朝听政 / 领取今日供奉）。四者仍只读 Game + 抛原信号，S1 红线不变。
const INTEL_X: float = 24.0
const INTEL_Y: float = 74.7
const INTEL_W: float = 432.0
const INTEL_ROW_H: float = 40.0   # V2（PH7 首页 B1）：34→40，随 INTEL_H 同步（时令胶囊单行行高）
const INTEL_GAP: float = 1.0
const INTEL_H: float = 40.0   # 仅时令胶囊一行（原 222 实心面板归零）；V2：34→40

# ───────── S2（PH7 首页 B1）：宗门信息带 = 气象 ∪ 快照 并带 ─────────
# 单实心 Panel（x24 w432 y476 h82）：上分区＝气象（心念轮播 + 待批红点，h34）
# ＋ 1px 暗金分隔线 ＋ 下分区＝快照 3 栏（局部 y40 h42）。两分区各保留原信号分发。
const WETH_Y: float = 476.0                # 信息带顶（原气象带顶）
const WETH_H: float = 34.0                 # 上分区（气象）行高
const SNAP_IN_BAND_Y: float = 40.0         # 下分区（快照）在带内局部 y（= 上分区 34 + 空档 6）
const SNAP_H: float = 42.0   # P1-A B1：38→42（给标题行高）
const INTEL_BAND_H: float = 82.0           # 带总高（= 34 + 6 + 42）

# 主 CTA（大圆钮：临朝听政 / 领取今日供奉）
const CTA_D: float = 96.0
const CTA_CY: float = 618.0   # 圆心 Y（占 570–666）；V3（PH7 首页 B1）：612→618，与信息带底缘 gap 12

# B7 宗门气象带（现为情报面板第 2 行）；本页只展示 + 抛信号
const WEATHER_ROTATE_SEC: float = 4.0    # 心念轮播间隔（秒）
const WEATHER_SHOW_MAX: int = 6          # 参与轮播的最近心念条数

# 更多弹窗入口（从首页侧边列 / 快捷栏移除的入口；S3 起并入原左右侧边 6 项）
const MORE_ENTRIES: Array = [
	{"id": "宗主管理", "icon": "entry_zongzhuguanli_36"},
	{"id": "幻形", "icon": "entry_huanxing_36"},
	{"id": "功勋", "icon": "entry_gongxunbei_36"},
	{"id": "宗规", "icon": "entry_zongmenguizhi_36"},
	{"id": "道友", "icon": "entry_daoyou_36"},
	{"id": "阵营声望", "icon": "entry_faction_36"},   # S3/P2：对齐舆图 SSOT（原 entry_fengyunbang_36），与「玄榜」解撞
	{"id": "宗门战", "icon": "entry_zongmen_battle_36"},
	{"id": "傀儡", "icon": "entry_puppet_36"},
	{"id": "藏书阁", "icon": "entry_library_36"},
	{"id": "药园", "icon": "entry_herb_garden_36"},
	{"id": "丹方", "icon": "entry_pill_formula_36"},
	{"id": "装备图纸", "icon": "entry_equipment_blueprint_36"},
	{"id": "宗门时令", "icon": "entry_activity_36"},
	{"id": "宗门气运", "icon": "entry_sect_qi_36"},
	{"id": "凡人王朝", "icon": "entry_dynasty_36"},
	{"id": "拍卖行", "icon": "entry_auction_36"},
	{"id": "商道", "icon": "entry_fangshi_36"},   # TODO(S3): 商道图标待定，待资产批补 entry_shangdao_36
	{"id": "传送阵", "icon": "entry_teleport_36"},
	{"id": "家族", "icon": "entry_family_36"},
	{"id": "法宝", "icon": "entry_treasure_36"},
	{"id": "科技", "icon": "entry_tech_36"},
	{"id": "灵兽", "icon": "entry_beast_36"},
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
	# ★ S3（2026-09-17）：左右侧边入口列退役，6 入口并入「更多」（icon 沿用原 stem，缺项会静默回退 entry_more_36）
	{"id": "天下", "icon": "entry_tianxia_36"},
	{"id": "宗务", "icon": "entry_zongmenyaowu_36"},
	{"id": "坊市", "icon": "entry_fangshi_36"},
	{"id": "玄榜", "icon": "entry_fengyunbang_36"},
	{"id": "宗门典藏", "icon": "entry_tujian_36"},
	{"id": "碎片宝箱", "icon": "entry_fragment_chest_36"},
]

# ───────── §3.3 更多面板主题分组（G1–G6，42 入口全覆盖；组数 ≤6、组内 ≤8）─────────
# 分组依据「玩家找东西的直觉」而非解锁阶段（UX 总纲 §3.3 / R1）。
# 组内入口仍走 _过滤已解锁（唯一 gating 来源）；整组无可见入口 → 整组不建。
# 组标题常显、组内容默认折叠（避免一屏 36 项按钮墙）。
const MORE_GROUPS: Array = [
	# ★ S3（2026-09-17）：6 入口并入，组数 =6 / 组内 ≤8 / Σ=42（原 36）
	{"组名": "宗门经营", "入口": ["宗门气运", "凡人王朝", "传送阵", "风水堪舆", "灵酿", "科技", "宗务"]},
	# 2026-09-15（老大定）：「幻形」是**换肤/装扮**类，与"弟子养成"（培养弟子）语义无关，
	# 归入「休闲雅趣」更顺 —— 且正好把该组由 5 项凑满 6 项、弟子养成由 7 项收回 6 项，六组齐整。
	# （dock 里另有一级「幻形」入口，换肤高频；此处为「更多」索引的一份，两者不冲突。）
	{"组名": "弟子养成", "入口": ["家族", "护道人", "身外化身", "毒道", "宗主管理", "宗主"]},
	{"组名": "生产技艺", "入口": ["药园", "丹方", "装备图纸", "傀儡", "藏书阁", "灵兽", "碎片宝箱"]},
	{"组名": "对外关系", "入口": ["阵营声望", "宗门战", "拍卖行", "宗门时令", "道友", "商道", "天下", "坊市"]},
	# 2026-09-15：闲情雅趣（七般雅趣·总入口）由组首移至组末 —— 总入口压在子项之前违和。
	{"组名": "休闲雅趣", "入口": ["论道棋弈", "机缘", "音律", "入山采撷", "幻形", "闲情雅趣"]},
	{"组名": "传承与荣誉", "入口": ["祖师堂", "功绩堂", "功勋", "宗规", "法宝", "飞升", "玄榜", "宗门典藏"]},
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
# 测灵大典活动窗（首页左上角常驻小窗；S1 红线：仅展示 + 抛 测灵大典请求 信号）
var _测灵窗: Control = null
# ───────── ★ 2026-09-15：「隐藏UI」三处回归的收口状态 ─────────
# _hidden_ui         —— 玩家主动按「隐藏UI」开关（chrome 收起，但浮标仍需可点，否则回不来）
# _chrome_suppressed —— 外部（二级页 / 消息中心 / 大地图 / 宗主详情）要求收起 chrome
#   ⇒ 与 _hidden_ui 是**两个不同成因**，必须分开记。混成一个 bool 就会出现
#     「打开幻形页时浮标 z_index=1000 盖在二级页上」= 玩家报的「点其他界面之后隐藏ui图标还是显示」。
#   ⇒ 唯二信号源 = game_ui 的 set_chrome_visible(true/false)。已核实：全项目 1 处 true
#     （_close_sub_page:938，所有返回路径统一收口）+ 6 处 false（_show_sub_page / _open_message_center
#     / 4 个全屏页 opener），即「凡压下首页者必调 false」⇒ 无需在 game_ui 新增钩子。
#     切一级 Tab 时首页被 _page_container.remove_child 出树，浮标自动不渲染。
var _hidden_ui: bool = false
var _chrome_suppressed: bool = false
# _bg_veil —— 上下暗晕渐变（BGVeil）：顶 0–11% α0.80、中 11–88% 全透明、底 88–100% α0.85。
#   它的职责是「给顶栏 / 快捷栏托底」，UI 都藏了它必须一起藏，否则就是玩家报的
#   「按了隐藏UI之后上下还是有蒙版，看不到完整立绘」。
#   （旧实现挂 _scene_root 而非 _chrome，故 _chrome.visible = false 管不到它。）
var _bg_veil: TextureRect = null
# _eye_btn —— 隐藏UI 开关本体。不能放进 _chrome（一藏就再也点不回来），放 _scene_root，
#   由 _chrome_suppressed 决定显隐。
var _eye_btn: Button = null

# 快捷栏折叠状态
var _quick_folded: bool = false
var _quick_buttons: Dictionary = {}   # id -> Button
var _quick_icons: Dictionary = {}     # id -> TextureRect（日供动态图标用）
var _quick_labels: Dictionary = {}    # id -> Label

var _bg: TextureRect = null
# ★ 2026-09-15 否决「观景模式推近」：曾用「隐藏 UI 时把下部留白图放大 1.45 倍」补救素材留白，
#   老大判定「我不要你的缩进效果，要跟其他一样显示完整图」⇒ 整体移除。
#   背景一律 KEEP_ASPECT_COVERED 原比例铺满，任何皮肤都不裁切、不缩放；
#   下部留白属**素材问题**，须在素材侧解决（重出满构图版本），不靠运行时裁图掩盖。
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
	_build_测灵窗()

# 底色 + 山门主视觉背景图
func _build_base_and_bg() -> void:
	var base := ColorRect.new()
	base.name = "SceneBase"
	_place(base, 0.0, 0.0, 480.0, 854.0)
	base.color = UITheme.获取页面底色()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_root.add_child(base)

	var bg := TextureRect.new()
	bg.name = "BG"
	_place(bg, 0.0, 0.0, 480.0, 854.0)
	bg.texture = _load_bg_texture("res://art/backgrounds/home_bg_sect_a.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# P0-6 续：背景暗金化 —— 压暗降亮，使亮青蓝山水降为暗色氛围层（不改原图，可逆）
	bg.modulate = UITheme.获取背景压暗系数()
	_scene_root.add_child(bg)
	_bg = bg
	_apply_equipped_skin()
	_build_bg_veil()
	_build_ambient_qi()

## 上下暗晕渐变遮罩：顶部/底部更深，令背景与暗金资源栏 / 快捷栏自然融合
func _build_bg_veil() -> void:
	var grad: Gradient = UITheme.建背景晕影渐变()
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var veil := TextureRect.new()
	veil.name = "BGVeil"
	_place(veil, 0.0, 0.0, 480.0, 854.0)
	veil.texture = gt
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_root.add_child(veil)
	_bg_veil = veil

## 精修问题⑤（选 a）：首页门面加轻量「灵气光点」氛围粒子。
## 几缕金色光点自屏底缓慢上浮、淡入淡出；不抢内容、几乎零交互开销。
## 接「减少动效」开关：关闭时不建粒子（与全局动效层同口径）。
func _build_ambient_qi() -> void:
	if UITheme.动效强度 <= 0.0:
		return
	var 金环: Color = UITheme.获取金文字色()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, -1.0, 0.0)   # 向上漂（2D 中 -y 为上）
	pm.gravity = Vector3(0.0, -10.0, 0.0)
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 14.0
	pm.spread = 35.0
	pm.scale_min = 0.25
	pm.scale_max = 0.7
	pm.lifetime_randomness = 0.5
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(220.0 * UITheme.UI_SCALE, 30.0 * UITheme.UI_SCALE, 0.0)
	var ramp := Gradient.new()
	ramp.add_point(0.0, Color(金环.r, 金环.g, 金环.b, 0.0))
	ramp.add_point(0.5, Color(金环.r, 金环.g, 金环.b, 0.55))
	ramp.add_point(1.0, Color(金环.r, 金环.g, 金环.b, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var 粒子 := GPUParticles2D.new()
	粒子.name = "AmbientQi"
	粒子.texture = _建灵气光点纹理()
	粒子.amount = 16
	粒子.lifetime = 7.0
	粒子.process_material = pm
	粒子.position = Vector2(240.0 * UITheme.UI_SCALE, 720.0 * UITheme.UI_SCALE)
	_scene_root.add_child(粒子)

## 运行时生成一张柔边金色圆点纹理（避免依赖外部资产）。
func _建灵气光点纹理() -> Texture2D:
	var s: int = 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var c: float = float(s) * 0.5
	var 金环: Color = UITheme.获取金文字色()
	for y in range(s):
		for x in range(s):
			var dx: float = float(x) - c + 0.5
			var dy: float = float(y) - c + 0.5
			var d: float = sqrt(dx * dx + dy * dy)
			var r: float = float(s) * 0.5
			if d < r:
				var a: float = 1.0 - (d / r)
				a = a * a   # 柔化边缘
				img.set_pixel(x, y, Color(金环.r, 金环.g, 金环.b, a))
	return ImageTexture.create_from_image(img)

func _load_bg_texture(path: String) -> Texture2D:
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		return tex
	var img: Image = Image.load_from_file(path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

# 可隐藏浮层：底部快捷栏 + 信息带（S3：左右入口列已退役）
func _build_chrome() -> void:
	_chrome = Control.new()
	_chrome.name = "Chrome"
	_place(_chrome, 0.0, 0.0, 480.0, 854.0)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_root.add_child(_chrome)

	_build_sect_hub()
	_build_intel_band()
	_build_main_cta()
	_build_quick_bar()

## P0-5.1 栏底座：入口带 / 快捷条共用（与情报面板同宽同源材质，消除“一排悬浮图标”）
## P0-5.3 场景归位：底座可降为「玻璃 dock」（透明度 < 1）→ 主视觉窗的场景透出；
##   九宫格底 alpha=255，透明度经 modulate 施加，不改资产、完全可逆。
func _建栏底座(名: String, 中心Y: float, 高: float, 透明度: float = 1.0) -> void:
	var 底: Panel = UITheme.建卡片容器()
	底.name = 名
	_place(底, INTEL_X, 中心Y - 高 * 0.5, INTEL_W, 高)
	if 透明度 < 1.0:
		底.modulate.a = 透明度
	_chrome.add_child(底)

## P0-1 洋葱式解锁：过滤出「已解锁」入口（fold 折叠按钮恒保留）。
## 两个容器（快捷栏 /「更多」面板）共用此单一来源：
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

## 创建底部快捷栏红点
func _make_quick_red_dots(中心列: Array = []) -> void:
	for cfg in QUICK_RED_DOTS:
		var id: String = cfg["id"]
		# 红点跟随宿主按钮的「可见序号」（未解锁 → -1，自然跳过）
		var idx: int = _可见序号(QUICK_ENTRIES, id)
		if idx < 0 or idx >= 中心列.size():
			continue

		# 红点位置：快捷栏按钮右上角
		var btn_x: float = float(中心列[idx])
		var btn_y: float = QUICK_Y
		# 落点：红点中心须落在**图标**右上 45° 外沿上，才能"咬"住图标。
		# 旧值 (0.4W, -0.3H) 把红点整体推到按钮顶边之上 ⇒ 与图标脱开、看着游离。
		var dot_offset_x: float = QUICK_BTN_W * 0.5 + QUICK_ICON_SIZE * 0.35
		var dot_offset_y: float = QUICK_BTN_H * 0.42 - QUICK_ICON_SIZE * 0.35

		var dot: Panel
		if cfg["strong"]:
			dot = UITheme.make_red_dot_number(0, 16.0)
		else:
			dot = UITheme.make_red_dot(12.0)
		dot.name = "QuickRedDot_" + id
		var dot_size: Vector2 = dot.custom_minimum_size
		_place(dot, btn_x + dot_offset_x - dot_size.x / 2, btn_y + dot_offset_y - dot_size.y / 2, dot_size.x, dot_size.y)
		# ★ M2（P1-A）：记录角标锚点中心 —— 刷新时按真实位数重算宽度后重新落位
		dot.set_meta(META_红点锚cx, btn_x + dot_offset_x)
		dot.set_meta(META_红点锚cy, btn_y + dot_offset_y)
		_chrome.add_child(dot)
		dot.visible = false

## 刷新红点状态（根据游戏数据动态显示/隐藏，带动画效果）
func _refresh_red_dots() -> void:
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
		# ★ M2（P1-A）：旧实现建时 count=0、刷新从不回写 ⇒ 有未读仍显示 "0"。
		#   此处回写真实未读数，并按位数重算角标宽度（锚点=图标右上 45° 原中心）。
		var 文本: String = "99+" if 未读数 > 99 else str(未读数)
		var num_lbl := 灵讯红点.get_node_or_null("Num")
		if num_lbl is Label:
			(num_lbl as Label).text = 文本
		var 高: float = 16.0
		var 宽: float = maxf(高, 高 * (0.62 * float(文本.length()) + 0.38))
		var 锚cx: float = float(灵讯红点.get_meta(META_红点锚cx, 0.0))
		var 锚cy: float = float(灵讯红点.get_meta(META_红点锚cy, 0.0))
		_place(灵讯红点, 锚cx - 宽 * 0.5, 锚cy - 高 * 0.5, 宽, 高)
		var 应该显示: bool = 未读数 > 0
		if 应该显示 and not 灵讯红点.visible:
			UITheme.animate_red_dot_appear(灵讯红点)
		elif not 应该显示 and 灵讯红点.visible:
			UITheme.animate_red_dot_disappear(灵讯红点)

# ───────── 重排 2026-09-15：时令胶囊（原「宗门情报」面板第 1 行，现为中枢唯一一行）─────────
# 守 S1 红线：只读 Game + 抛信号（时令横幅请求）。
func _build_sect_hub() -> void:
	var 板: Panel = UITheme.建页面底面板()
	板.name = "SectHub"
	_place(板, INTEL_X, INTEL_Y, INTEL_W, INTEL_H)
	_chrome.add_child(板)
	_build_season_banner(板, 0.0)

var _时令横幅: Button = null
var _时令文本: Label = null

## 时令横幅：宗门时令名称 + 倒计时 + 前往（原「宗门时令」深埋「更多 → 对外关系」，提升为黄金位）
func _build_season_banner(父: Control, y: float) -> void:
	var btn := Button.new()
	btn.name = "SeasonBanner"
	btn.flat = true
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	_place(btn, 0.0, y, INTEL_W, INTEL_ROW_H)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_season_banner_pressed)
	父.add_child(btn)
	_时令横幅 = btn

	# 左：角标文案（金文字色）
	_mk_label_in(btn, "BannerTag", "大典盛事",
		12.0, (INTEL_ROW_H - 18.0) * 0.5, 60.0, 18.0,
		10, UITheme.获取金文字色(), true,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true)

	# 中：时令名 + 倒计时
	_时令文本 = _mk_label_in(btn, "BannerName", "平日",
		80.0, 0.0, INTEL_W - 80.0 - 62.0, INTEL_ROW_H,
		12, UITheme.获取主文字色(), true,
		HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, false)

	# 右：前往 ›
	_mk_label_in(btn, "BannerGo", "前往 ▶",
		INTEL_W - 60.0, 0.0, 52.0, INTEL_ROW_H,
		11, UITheme.获取金文字色(), true,
		HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_CENTER, true)

	_refresh_season_banner()

## 只读刷新：时令名 + 下一次重置倒计时（绝不写 Game）
func _refresh_season_banner() -> void:
	if _时令文本 == null:
		return
	var 名称: String = "平日"
	var 剩余: String = ""
	if is_instance_valid(Game):
		if Game.has_method("获取当前活动名称"):
			名称 = String(Game.获取当前活动名称())
		if Game.has_method("获取活动倒计时"):
			var 倒: Dictionary = Game.获取活动倒计时("日常")
			剩余 = String(倒.get("描述", ""))
	if 剩余 == "":
		_时令文本.text = 名称
	else:
		_时令文本.text = "%s　·　%s" % [名称, 剩余]

func _on_season_banner_pressed() -> void:
	时令横幅请求.emit()

# ───────── 重排 2026-09-15：传讯栏已并入「主 CTA」─────────
# 待批传讯数由 _refresh_main_cta 只读拉取；点击抛 传讯栏请求（信号不变，game_ui 交互层无感）。

# ───────── P0-7：运转快照段（S1 后为「宗门信息带」下分区 · 单行 3 栏 · 守 S1 红线：只读 + 抛信号）─────────
# 坐标源：A 骨架 物理 736–976 → 逻辑 327.1–433.8（3 栏等分）
# 判据：司职明细属殿阁 Tab（X12 一义一名一页）→ 首页只给概览数字 + 跳转，不摊明细。
var _快照卡: Array = []

## S2（PH7 首页 B1）：不再自建面板，作为「宗门信息带」下分区构建（父＝信息带 Panel，局部 y40 h42）。
## S1：4 栏收为 3 栏（门中弟子 / 司职在任 / 宗门气运）——「待批复」重复项收口到主 CTA 副文。
## 标题小字上、数值下（明细仍归殿阁 Tab）。
func _build_snapshot_strip(父: Panel) -> void:
	_快照卡 = []
	var 栏宽: float = INTEL_W / 3.0
	var 卡配置: Array = [
		{"键": "弟子", "标题": "门中弟子"},
		{"键": "司职", "标题": "司职在任"},
		{"键": "气运", "标题": "宗门气运"},
	]
	for i in range(卡配置.size()):
		var cfg: Dictionary = 卡配置[i]
		var 键: String = String(cfg["键"])
		var 栏: Button = Button.new()
		栏.name = "Snap_" + 键
		栏.flat = true
		栏.text = ""
		栏.focus_mode = Control.FOCUS_NONE
		栏.mouse_filter = Control.MOUSE_FILTER_STOP
		_place(栏, float(i) * 栏宽, SNAP_IN_BAND_Y, 栏宽, SNAP_H)
		栏.gui_input.connect(_on_snapshot_input.bind(键))
		父.add_child(栏)

		# 标题（上·次色小字）/ 数值（中·主色加粗）/ 小字引导·等级（下·次色更小）。
		# ★ 精修问题①：快照栏小字此前从未创建（死代码，小字恒为 null），
		#   司职空缺引导 / 气运等级名 永远不显示。现补齐三卡统一几何；弟子卡留空占位保纵向对齐。
		_mk_label_in(栏, "Title_" + 键, String(cfg["标题"]),
			4.0, 2.0, 栏宽 - 8.0, 13.0,
			10, UITheme.获取次文字色(), false,
			HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)

		var 值: Label = _mk_label_in(栏, "Value_" + 键, "—",
			4.0, 15.0, 栏宽 - 8.0, 16.0,
			12, UITheme.获取主文字色(), true,
			HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)

		var 小字: Label = _mk_label_in(栏, "Sub_" + 键, "",
			4.0, 31.0, 栏宽 - 8.0, 10.0,
			9, UITheme.获取次文字色(), false,
			HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)

		_快照卡.append({"键": 键, "值": 值, "小字": 小字})

		# 栏间竖分隔线（末栏不加；零新增色值）
		if i < 卡配置.size() - 1:
			var 线 := ColorRect.new()
			线.name = "SnapDivider_%d" % i
			线.mouse_filter = Control.MOUSE_FILTER_IGNORE
			线.color = UITheme.获取暗金边色()
			线.modulate.a = 0.7
			_place(线, float(i + 1) * 栏宽 - 0.5, SNAP_IN_BAND_Y + SNAP_H * 0.2, 1.0, SNAP_H * 0.6)
			父.add_child(线)

	_refresh_snapshot_band()

## 只读刷新：3 卡数字（弟子数 / 司职在任 / 宗门气运）；绝不写 Game
func _refresh_snapshot_band() -> void:
	if _快照卡.is_empty():
		return
	var 弟子数: int = 0
	var 在职: int = 0
	var 司职总: int = 0
	var 气运值: int = 0
	var 气运级: String = ""
	if is_instance_valid(Game):
		if "弟子列表" in Game:
			var 弟表 = Game.弟子列表
			if 弟表 != null:
				弟子数 = int(弟表.size())
		if "司职列表" in Game:
			var 司职 = Game.司职列表
			if 司职 is Dictionary:
				司职总 = (司职 as Dictionary).size()
				for k in (司职 as Dictionary).keys():
					var 项 = (司职 as Dictionary)[k]
					if 项 is Dictionary and (项 as Dictionary).get("负责", null) != null:
						在职 += 1
		if Game.has_method("获取气运值"):
			气运值 = int(Game.获取气运值())
		if Game.has_method("获取气运等级"):
			气运级 = String(Game.获取气运等级())
	for 条目 in _快照卡:
		var 值: Label = 条目["值"]
		var 小: Label = 条目["小字"]
		if 值 == null:
			continue
		match String(条目["键"]):
			"弟子":
				_animate_value(值, "弟子", 弟子数)
			"司职":
				_animate_value(值, "司职", 在职, 司职总)
				if 小 != null:
					if 司职总 <= 0 or 在职 >= 司职总:
						小.text = "司职齐备"
					else:
						小.text = "空缺 %d · 去殿阁 ▶" % (司职总 - 在职)
			"气运":
				_animate_value(值, "气运", 气运值)
				if 小 != null and 气运级 != "":
					小.text = 气运级

## 精修问题③：快照数值变化做 0.25s 滚动（整数插值）动画；减少动效时直接赋值。
func _animate_value(值: Label, 类型: String, a: int, b: int = 0) -> void:
	var 旧文本: String = 值.text
	var 新文本: String = _格式化快照值(类型, a, b)
	if UITheme.动效强度 <= 0.0:
		值.text = 新文本
		return
	var 旧数: Array = _提取整数(旧文本)
	var 新数: Array = _提取整数(新文本)
	if 旧数.is_empty() or 新数.is_empty() or 旧数.size() != 新数.size():
		值.text = 新文本
		return
	var tw := create_tween()
	tw.tween_method(func(p: float) -> void: 值.text = _插值格式化(类型, 旧数, 新数, p), 0.0, 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _格式化快照值(类型: String, a: int, b: int) -> String:
	match 类型:
		"弟子":
			return "%d名" % a
		"司职":
			return "%d/%d" % [a, b]
		_:
			return "%d" % a

func _插值格式化(类型: String, 旧数: Array, 新数: Array, p: float) -> String:
	var out: Array = []
	for i in range(旧数.size()):
		var v: int = int(round(lerpf(float(旧数[i]), float(新数[i]), p)))
		out.append(v)
	match 类型:
		"弟子":
			return "%d名" % out[0]
		"司职":
			return "%d/%d" % [out[0], out[1]]
		_:
			return "%d" % out[0]

func _提取整数(s: String) -> Array:
	var 结果: Array = []
	var n: String = ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			n += ch
		elif n != "":
			结果.append(int(n))
			n = ""
	if n != "":
		结果.append(int(n))
	return 结果

func _on_snapshot_input(event: InputEvent, 键: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		快照卡请求.emit(键)

# ───────── S2（PH7 首页 B1）：宗门信息带（气象 ∪ 快照 并为一条实心带）─────────
## 单 Panel（x24 w432 y476 h82），上分区＝气象 / 1px 暗金线 / 下分区＝快照 3 栏。
## 两分区各自保留原信号分发（气象带请求 / 快照卡请求）—— S1 红线（只展示 + 入口）不变。
func _build_intel_band() -> void:
	var 板: Panel = UITheme.建页面底面板()
	板.name = "IntelBand"
	_place(板, INTEL_X, WETH_Y, INTEL_W, INTEL_BAND_H)
	_chrome.add_child(板)
	_build_weather_ribbon(板)
	# V1：两分区之间 1px 横向暗金细线（x12…w−12，零新增色值）
	var 线 := ColorRect.new()
	线.name = "BandDivider"
	线.mouse_filter = Control.MOUSE_FILTER_IGNORE
	线.color = UITheme.获取暗金边色()
	线.modulate.a = 0.7
	_place(线, 12.0, WETH_H + (INTEL_BAND_H - WETH_H - SNAP_H) * 0.5, INTEL_W - 24.0, 1.0)
	板.add_child(线)
	_build_snapshot_strip(板)

# ───────── B7：宗门气象区（现并入「宗门信息带」上分区 · 纯展示 + 入口 · 守 S1 红线）─────────
## S2：不再自建面板，作为「宗门信息带」上分区子内容构建（父＝信息带 Panel，局部 y0 h34）：
## 门人最新心念轮播 + 待批传讯红点。本页只读 Game 并抛出信号；
## 抽屉（含批复写操作）由 game_ui 交互层承载。
func _build_weather_ribbon(父: Panel) -> void:
	var btn := Button.new()
	btn.name = "WeatherBand"
	btn.flat = true
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	_place(btn, 0.0, 0.0, INTEL_W, WETH_H)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_weather_band_pressed)
	父.add_child(btn)
	_气象带 = btn

	# 左：栏目名（金色）
	_mk_label_in(btn, "BandTitle", "宗门气象",
		10.0, 0.0, 64.0, WETH_H,
		10, UITheme.获取金文字色(), true,
		HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, true)

	# 中：心念轮播文本（二级文字，超长裁剪）
	_气象文本 = _mk_label_in(btn, "BandText", "",
		78.0, 0.0, INTEL_W - 78.0 - 30.0, WETH_H,
		10, UITheme.获取次文字色(), false,
		HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, false, true)   # allow_clip=true：唯一 clip 调用点（autowrap=3 折行会顶高 get_minimum_size().y ⇒ 必须 clip 钳高，详见 helper 处注释）

	# 右：待批传讯红点（复用统一红点控件，初始隐藏）
	var dot: Panel = UITheme.make_red_dot_number(0, 16.0)
	dot.name = "BandRedDot"
	_place(dot, INTEL_W - 22.0, (WETH_H - 16.0) * 0.5, 16.0, 16.0)
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
			var 宽: float = 16.0 + 6.0 * float(文本.length())
			_place(_气象红点, INTEL_W - 6.0 - 宽, (WETH_H - 16.0) * 0.5, 宽, 16.0)
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

# ───────── 重排 2026-09-15：主 CTA（一屏一个主行动按钮）─────────
## 大圆钮居主视觉窗下方：待裁决 > 0 → 「临朝听政 · N 件待裁决」；
## 否则今日日供可领 → 「领取供奉」；否则「临朝听政 · 宗门井然」。
## 只读 Game；点击抛 传讯栏请求 / entry_selected("日供")，写操作仍归 game_ui 交互层。
var _cta: Button = null
var _cta主文: Label = null
var _cta副文: Label = null

func _build_main_cta() -> void:
	var btn := Button.new()
	btn.name = "MainCTA"
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	var d: float = CTA_D
	_place(btn, 240.0 - d * 0.5, CTA_CY - d * 0.5, d, d)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	# 圆钮样式：页面底色 + 暗金描边（全部走 ui_theme token，零新增色值 → 棘轮免税）
	var r: int = int(d * 0.5 * UITheme.UI_SCALE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.获取页面底色()
	sb.border_color = UITheme.获取暗金边色()
	sb.set_border_width_all(int(2.0 * UITheme.UI_SCALE))
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h: StyleBoxFlat = sb.duplicate()
	sb_h.bg_color = sb.bg_color.lightened(0.06)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	btn.pressed.connect(_on_main_cta_pressed)
	_chrome.add_child(btn)
	_cta = btn

	# ★ 2026-09-16 精修（#009 首页）：主 CTA 是首页唯一「一屏一个主行动」的按钮，原为单层
	#   暗金细边的裸圆钮 —— 实机上像一枚贴在背景里的空圈，缺少主行动钮该有的仪式感。
	#   补两件事：① 内环 = 第二层金环 + 极淡内衬，制造纵深；② 呼吸脉冲引导视线。
	#   脉冲只挂**内环**、不挂按钮本体：全局手感层会给每个 BaseButton 挂「按下缩放」tween，
	#   本体再做循环缩放会与它抢同一属性而抖。内环是 Panel，不受该钩子影响。
	#   两个色值都由 获取金文字色() 调 alpha 得出 ⇒ 零新增色值（棘轮免税）。
	var 金环: Color = UITheme.获取金文字色()
	var 光晕 := Panel.new()
	光晕.name = "CtaHalo"
	var 光晕径: float = d - 14.0
	_place(光晕, (d - 光晕径) * 0.5, (d - 光晕径) * 0.5, 光晕径, 光晕径)
	光晕.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 缩放轴心必须显式设到圆心：Control 默认 pivot 在左上角，不设会把圆「撑歪」
	光晕.pivot_offset = Vector2(光晕径 * 0.5 * UITheme.UI_SCALE, 光晕径 * 0.5 * UITheme.UI_SCALE)
	var 光晕sb := StyleBoxFlat.new()
	光晕sb.bg_color = Color(金环.r, 金环.g, 金环.b, 0.07)
	光晕sb.border_color = Color(金环.r, 金环.g, 金环.b, 0.5)
	光晕sb.set_border_width_all(int(round(1.0 * UITheme.UI_SCALE)))
	光晕sb.set_corner_radius_all(int(round(光晕径 * 0.5 * UITheme.UI_SCALE)))
	光晕sb.set_content_margin_all(0)
	光晕.add_theme_stylebox_override("panel", 光晕sb)
	btn.add_child(光晕)

	# 主/副文之间的金色细分割：把「动作」与「状态」两层信息分开
	var 分割 := ColorRect.new()
	分割.name = "CtaRule"
	分割.color = Color(金环.r, 金环.g, 金环.b, 0.35)
	分割.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(分割, d * 0.5 - 18.0, d * 0.5, 36.0, 1.0)
	btn.add_child(分割)

	# 呼吸脉冲：2.4s 一周期，内环明暗 0.55↔1.0 + 缩放 1.0↔1.05（SINE 缓入缓出，无每帧重算）。
	# ★ 精修问题④：接「减少动效」开关（UITheme.动效强度）。关闭时内环保持静态，不建循环 tween。
	if UITheme.动效强度 > 0.0:
		var 呼吸: Tween = btn.create_tween().set_loops()
		呼吸.tween_property(光晕, "modulate:a", 0.55, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		呼吸.parallel().tween_property(光晕, "scale", Vector2(1.05, 1.05), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		呼吸.tween_property(光晕, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		呼吸.parallel().tween_property(光晕, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_cta主文 = _mk_label_in(btn, "CtaMain", "临朝听政",
		8.0, d * 0.5 - 28.0, d - 16.0, 24.0,
		15, UITheme.获取金文字色(), true,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true)

	_cta副文 = _mk_label_in(btn, "CtaSub", "",
		8.0, d * 0.5 + 5.0, d - 16.0, 16.0,
		10, UITheme.获取次文字色(), false,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)

	_refresh_main_cta()

## 只读刷新主 CTA 文案与警示色（绝不写 Game）
func _refresh_main_cta() -> void:
	if _cta主文 == null:
		return
	var 待批: int = 0
	var 可领: bool = false
	if is_instance_valid(Game):
		if Game.has_method("待处理传讯数量"):
			待批 = int(Game.待处理传讯数量())
		if Game.has_method("日供_今日可领"):
			可领 = bool(Game.日供_今日可领())
	if 待批 > 0:
		_cta主文.text = "临朝听政"
		_cta副文.text = "%d 条待批复传讯" % 待批
		_cta副文.add_theme_color_override("font_color", UITheme.获取警色())
	elif 可领:
		_cta主文.text = "领取供奉"
		_cta副文.text = "今日日供可领"
		_cta副文.add_theme_color_override("font_color", UITheme.获取次文字色())
	else:
		_cta主文.text = "临朝听政"
		_cta副文.text = "宗门井然"
		_cta副文.add_theme_color_override("font_color", UITheme.获取次文字色())

func _on_main_cta_pressed() -> void:
	var 待批: int = 0
	var 可领: bool = false
	if is_instance_valid(Game):
		if Game.has_method("待处理传讯数量"):
			待批 = int(Game.待处理传讯数量())
		if Game.has_method("日供_今日可领"):
			可领 = bool(Game.日供_今日可领())
	if 待批 <= 0 and 可领:
		entry_selected.emit("日供")
	else:
		传讯栏请求.emit()

# 底部 dock（原快捷栏，7 项）
func _build_quick_bar() -> void:
	# 重排 2026-09-15/16：dock 7 项（库藏/灵讯/日供/幻形/设置/隐藏UI/更多），底座几何不变
	# 底座中心 = 按钮中心 QUICK_Y + QUICK_BTN_H * 0.5 = 722，高 72 → 684..758（Tab 774 之上）。
	_建栏底座("QuickBarBG", QUICK_Y + QUICK_BTN_H * 0.5, 72.0, 0.82)
	# P0-1：过滤后按「可见序号」紧凑排布（「更多」折叠按钮由 _过滤已解锁 恒保留）
	var 可见表: Array = _过滤已解锁(QUICK_ENTRIES)
	var 中心列: Array = _算dock中心列(可见表.size())
	for i in range(可见表.size()):
		_make_quick_entry(可见表[i], 中心列[i])
	_make_quick_red_dots(中心列)
	_refresh_quick_icons()
	_apply_quick_fold()

## 根据当前可见按钮数量动态计算 dock 按钮中心 x，避免常量数组与运行时数量不同步。
func _算dock中心列(n: int) -> Array:
	if n <= 1:
		return [240.0]
	# 在底座 INTEL_W 内等距分布，左右各留 QUICK_BTN_W/2 边距
	var 可用宽: float = INTEL_W - QUICK_BTN_W
	var 间距: float = 可用宽 / float(n - 1)
	var 起始: float = INTEL_X + QUICK_BTN_W * 0.5
	var 列: Array = []
	for i in range(n):
		列.append(起始 + 间距 * float(i))
	return 列

func _make_quick_entry(cfg: Dictionary, cx: float) -> void:
	var id: String = cfg["id"]
	var is_fold_btn: bool = cfg.get("fold", false)
	var x: float = cx - QUICK_BTN_W * 0.5
	var y: float = QUICK_Y

	var btn := Button.new()
	btn.name = "Quick_" + id
	btn.flat = true
	btn.text = ""
	_place(btn, x, y, QUICK_BTN_W, QUICK_BTN_H)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	var _空框2 := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", _空框2)
	btn.add_theme_stylebox_override("pressed", _空框2)
	btn.add_theme_stylebox_override("hover", _空框2)
	btn.add_theme_stylebox_override("focus", _空框2)
	btn.add_theme_stylebox_override("disabled", _空框2)
	if is_fold_btn:
		btn.pressed.connect(_on_quick_fold_toggle)
	elif id == "隐藏UI":
		btn.pressed.connect(_on_hide_ui_pressed)
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
	# 图标底座：同「更多」面板口径，走白名单（见 UITheme.ICON_BASE_WHITELIST）。
	# dock 各项里若混有旧版自带徽章图，则自动跳过、不垫底座。
	if UITheme.图标需要底座(String(cfg["icon"])):
		var 底: TextureRect = UITheme.建图标底座(QUICK_ICON_SIZE)
		_place(底, icon_x, icon_y, QUICK_ICON_SIZE, QUICK_ICON_SIZE)
		btn.add_child(底)
	btn.add_child(icon)
	_quick_icons[id] = icon

	# 标签：移到图标内部底部边缘（再向上收 4 逻辑单位），作为按钮子节点置顶显示
	var label: Label = _mk_label_in(btn, "Label_" + id, id,
		0.0, QUICK_BTN_H - QUICK_LABEL_H - 4.0, QUICK_BTN_W, QUICK_LABEL_H,
		QUICK_FONT, UITheme.获取主文字色(), true,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true)
	label.z_index = 10
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", UITheme.C01_SHADOW)
	_quick_labels[id] = label

func _on_quick_fold_toggle() -> void:
	if _more_panel == null:
		_build_more_panel()
	_toggle_more_panel()

## 更多面板开/关转场（淡入 + 轻微上滑 0.22s；减少动效时直接显隐，与全局动效层同口径）。
func _toggle_more_panel() -> void:
	if _more_panel == null:
		return
	if _more_panel.visible:
		_close_more_panel()
	else:
		_open_more_panel()

func _open_more_panel() -> void:
	_more_panel.visible = true
	_more_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var 面板 := _more_panel.get_node_or_null("MorePanel") as Panel
	var 目标Y: float = 0.0
	if 面板 != null:
		目标Y = 面板.position.y
		面板.position.y = 目标Y + 30.0 * UITheme.UI_SCALE
	if UITheme.动效强度 <= 0.0:
		_more_panel.modulate.a = 1.0
		if 面板 != null:
			面板.position.y = 目标Y
		return
	var t := create_tween()
	t.tween_property(_more_panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if 面板 != null:
		t.parallel().tween_property(面板, "position:y", 目标Y, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _close_more_panel() -> void:
	var 面板 := _more_panel.get_node_or_null("MorePanel") as Panel
	if UITheme.动效强度 <= 0.0:
		_more_panel.visible = false
		return
	var t := create_tween()
	t.tween_property(_more_panel, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if 面板 != null:
		t.parallel().tween_property(面板, "position:y", 面板.position.y + 24.0 * UITheme.UI_SCALE, 0.18)
	t.tween_callback(_on_more_panel_closed)

func _on_more_panel_closed() -> void:
	if _more_panel != null and is_instance_valid(_more_panel):
		_more_panel.visible = false

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
	# ★ 2026-09-15 修复：本遮罩此前 z_index=0，而首页入口 / dock 标签为 z_index=10、
	#   隐藏UI浮标为 z_index=1000 ⇒ 面板打开后这些元素反而浮在遮罩**之上**，
	#   表现为「更多框打开后还能看到首页的东西」。取 1001 保证弹窗期间是 _scene_root 内
	#   真正的最上层；关闭后一切自然恢复（不污染其余节点的 z）。
	bg.z_index = 1001
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
	UITheme.应用九宫格(panel, "panel_bg")  # P0-4：整页浮层底材质（替代裸 StyleBoxFlat）
	bg.add_child(panel)

	# 标题
	var title := Label.new()
	title.name = "Title"
	title.text = "更多功能"
	UITheme.apply_project_font(title, UITheme.FONT_TITLE, true)
	title.add_theme_color_override("font_color", UITheme.获取金文字色())
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

	# ★ 修复 2026-09-15：本面板所有 theme 常量与 custom_minimum_size 必须×UI_SCALE。
	#   此前漏乘 → 按钮实际仅 120×78 物理像素，而图标/标签按逻辑值(_place 内已×2.25)定位
	#   → 图标溢出按钮边界、标签错位、互相遮挡、部分入口点不到（幻形即因此不可点）。
	var ms: float = UITheme.UI_SCALE
	var vb := VBoxContainer.new()
	vb.name = "MoreGroups"
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", int(round(8.0 * ms)))
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
	foot.custom_minimum_size = Vector2(0.0, (MORE_FOOTER_H - 8.0) * ms)
	foot.focus_mode = Control.FOCUS_NONE
	UITheme.apply_project_font(foot, UITheme.FONT_BODY, false)
	foot.add_theme_color_override("font_color", UITheme.获取金文字色())
	UITheme.apply_secondary_button_style(foot)
	foot.pressed.connect(_on_more_atlas_pressed)
	_place(foot, 12.0, panel_h - MORE_FOOTER_H - 4.0, panel_w - 24.0, MORE_FOOTER_H - 8.0)
	panel.add_child(foot)

	_more_panel = bg
	_more_panel.visible = false

## §3.3：单个主题组 = 组标题（常显，点击折叠/展开）+ 组内 3 列入口网格（默认折叠）
func _make_more_group(parent: VBoxContainer, 组名: String, 可见: Array) -> void:
	# ★ 2026-09-15 修复：theme 常量与 custom_minimum_size 一律 ×UI_SCALE（与 _place 同口径）
	var s: float = UITheme.UI_SCALE
	var box := VBoxContainer.new()
	box.name = "MoreGroup_" + 组名
	box.add_theme_constant_override("separation", int(round(6.0 * s)))
	parent.add_child(box)

	var head := Button.new()
	head.name = "MoreGroupHead_" + 组名
	head.text = "%s（%d）" % [组名, 可见.size()]
	head.custom_minimum_size = Vector2(0.0, 34.0 * s)
	head.focus_mode = Control.FOCUS_NONE
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	UITheme.apply_project_font(head, UITheme.FONT_H2, true)
	head.add_theme_color_override("font_color", UITheme.获取金文字色())
	box.add_child(head)

	var grid := GridContainer.new()
	grid.name = "MoreGroupGrid_" + 组名
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", int(round(8.0 * s)))
	grid.add_theme_constant_override("v_separation", int(round(10.0 * s)))
	grid.visible = false
	box.add_child(grid)

	head.pressed.connect(_on_more_group_toggle.bind(grid))

	for cfg in 可见:
		_make_more_entry(grid, cfg)

## 更多面板组内折叠/展开：展开时条目依次淡入（错峰 60ms），收起时直接隐藏。减少动效时直接显隐。
func _on_more_group_toggle(grid: GridContainer) -> void:
	if grid == null or not is_instance_valid(grid):
		return
	if grid.visible:
		grid.visible = false
		return
	grid.visible = true
	if UITheme.动效强度 <= 0.0:
		return
	var i: int = 0
	for 子 in grid.get_children():
		var c := 子 as Control
		if c == null:
			continue
		c.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(c, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(float(i) * 0.06)
		i += 1

## 更多面板入口按钮（3 列网格单元；位置由 GridContainer 自动排布，不再手算坐标）
## ★ 2026-09-15 修复：按钮 custom_minimum_size 必须 ×UI_SCALE —— 内嵌图标/标签由 _place() 定位
##   （其内部已 ×2.25），若按钮仍按逻辑值 120×78 声明，实际矩形只有内嵌元素的 40%
##   → 图标溢出按钮边界互相叠压、标签串到邻格、命中区与视觉错位（表现为「点不到」）。
func _make_more_entry(parent: GridContainer, cfg: Dictionary) -> void:
	var id: String = String(cfg["id"])
	var s: float = UITheme.UI_SCALE
	var btn_w: float = 126.0   # 逻辑宽：3×126 + 2×8 = 394 ≤ 396（scroll 净宽）
	var btn_h: float = 82.0
	var btn := Button.new()
	btn.name = "MoreBtn_" + id
	btn.flat = true
	btn.text = ""
	btn.custom_minimum_size = Vector2(btn_w * s, btn_h * s)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	var _空框3 := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", _空框3)
	btn.add_theme_stylebox_override("pressed", _空框3)
	btn.add_theme_stylebox_override("hover", _空框3)
	btn.add_theme_stylebox_override("focus", _空框3)
	btn.add_theme_stylebox_override("disabled", _空框3)
	btn.pressed.connect(_on_more_entry_pressed.bind(id))
	parent.add_child(btn)

	# 图标底座：与 dock 同口径，走 UITheme.图标需要底座() 白名单（理由见 ui_theme.gd
	# ENABLE_ICON_BASE 长注释）。底座必须先于 icon 添加，才能压在图标下层。
	# ★ 2026-09-15 补漏：本面板此前**没有**这段逻辑 —— 白名单内的裸金图标在小网格里裸奔，
	#   与 dock 的同名图标「一个有底座一个没有」，视觉断裂。这是纯代码遗漏，非白名单问题。
	if UITheme.图标需要底座(String(cfg["icon"])):
		var 底: TextureRect = UITheme.建图标底座(40.0)
		_place(底, (btn_w - 40.0) * 0.5, 5.0, 40.0, 40.0)
		btn.add_child(底)

	# 图标（40×40 逻辑，水平居中，距顶 5）
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = UITheme.load_hd_icon(String(cfg["icon"]))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(icon, (btn_w - 40.0) * 0.5, 5.0, 40.0, 40.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	# 标签：FONT_AUX 保证最长 5 字（如「身外化身」）不溢出 126 逻辑宽
	var label := Label.new()
	label.name = "Label"
	label.text = id
	UITheme.apply_project_font(label, UITheme.FONT_AUX, false)
	label.add_theme_color_override("font_color", UITheme.获取主文字色())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	_place(label, 0.0, 52.0, btn_w, 22.0)
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
		_close_more_panel()

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

# ───────── 隐藏UI 开关（视图控制类 · 贴右边缘悬浮球）─────────
# ★ 2026-09-15 重定位。旧落点 (cx 440, y 620) 的问题不是"被挡住"，而是**语义错位**：
#   它落在右列入口同一条竖带（入口 x 410.9~477.1）里，只靠 y 与入口区分，
#   视觉上像是"入口列的孤儿项"，玩家反馈里那条「隐藏UI图标放哪里比较好」正是此意。
#
# 改判依据（三条硬约束，逐条用现有坐标验证）：
#   ① 不能占主视觉区中心（立绘主体在屏中；y 116~744 / x 24~456 全是有内容的区块）；
#   ② 隐藏UI之后它必须还在（否则回不来）⇒ 不能进 _chrome；
#   ③ 不与既有任何区块重叠。
#   验证：右列入口 y 116.9~327.1 / 宗门气象带 x 60~420 (y 476~506) / 快照条 y 516~554 /
#   主 CTA 圆 x 192~288 (y 564~660) / dock 槽位 x 54~426 (y 700~744)。
#   ⇒ 取 y 中心 430、x 中心 452（右边缘内收 28 逻辑），与上列全部不相交；
#     落在 y 419~441 → 屏幕 50.4% 高的右侧边缘，是右手拇指自然位，
#     也与主视觉窗的视觉中心（心念轮播 / CTA）拉开距离。
#   行业对照：视图控制类开关的通行做法就是"贴边悬浮球"（iOS 辅助触控 / 元素视野钮），
#     常态低透明度待机、被激活时提亮 —— 本实现按此设定 two-state alpha。
const EYE_CX: float = 452.0    # 中心 x（右边缘内收 28 逻辑，避让侧边返回手势区）
const EYE_CY: float = 430.0    # 中心 y（屏幕 50.4% 高）
const EYE_SZ: float = 22.0     # 按钮热区（比图标大一圈，保证可点）
const EYE_ICON: float = 18.0   # 图标视觉尺寸

func _build_eye() -> void:
	var x: float = EYE_CX - EYE_SZ * 0.5
	var y: float = EYE_CY - EYE_SZ * 0.5
	var btn := Button.new()
	btn.name = "HideUIBtn"
	btn.flat = true
	btn.text = ""
	_place(btn, x, y, EYE_SZ, EYE_SZ)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.z_index = 1000  # 置顶，保证在 _scene_root 内可点
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
	var icon_x: float = (EYE_SZ - EYE_ICON) * 0.5
	var icon_y: float = (EYE_SZ - EYE_ICON) * 0.5
	_place(eye_icon, icon_x, icon_y, EYE_ICON, EYE_ICON)
	eye_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(eye_icon)

	# 放 _scene_root 而非 _chrome：_chrome 会被整体隐藏，开关进去了就再也点不回来。
	# 「其他界面不该显示」改由 _chrome_suppressed 精确控制（见 _update_eye_state）。
	_scene_root.add_child(btn)
	_eye_btn = btn
	_update_eye_state()

# 测灵大典活动窗：首页左上角常驻小窗（年度提醒 + 候选数 + 前往）。
# S1 红线：只读展示 + 抛 测灵大典请求 信号，写操作全在 game_ui 交互层。
func _build_测灵窗() -> void:
	var 窗 := Control.new()
	窗.name = "测灵大典窗"
	_place(窗, 20.0, 120.0, 196.0, 92.0)
	窗.mouse_filter = Control.MOUSE_FILTER_STOP
	窗.z_index = 900
	_chrome.add_child(窗)
	_测灵窗 = 窗

	var 板 := PanelContainer.new()
	板.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.13, 0.10, 0.07, 0.92)
	psb.border_color = Color(0.85, 0.66, 0.32, 0.95)
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(8)
	psb.content_margin_left = 12; psb.content_margin_right = 12
	psb.content_margin_top = 8; psb.content_margin_bottom = 8
	板.add_theme_stylebox_override("panel", psb)
	窗.add_child(板)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	板.add_child(vb)

	var 标题 := Label.new()
	标题.text = "◈ 测灵大典"
	标题.add_theme_color_override("font_color", Color(0.95, 0.80, 0.42))
	UITheme.apply_project_font(标题, UITheme.FONT_TITLE, true)
	vb.add_child(标题)

	var 提醒 := Label.new()
	提醒.name = "提醒"
	提醒.text = "一年一度的测灵大典将至，可择徒入门。"
	提醒.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	提醒.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78))
	UITheme.apply_project_font(提醒, UITheme.FONT_BODY, false)
	vb.add_child(提醒)

	var 脚 := Label.new()
	脚.name = "脚"
	脚.add_theme_color_override("font_color", Color(0.80, 0.70, 0.45))
	UITheme.apply_project_font(脚, UITheme.FONT_BODY, false)
	vb.add_child(脚)

	# 点击层：整窗可点 → 抛信号（交由 game_ui 打开测灵大典面板）
	var 点 := Button.new()
	点.flat = true
	点.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	点.mouse_filter = Control.MOUSE_FILTER_STOP
	var 空 := StyleBoxEmpty.new()
	点.add_theme_stylebox_override("normal", 空)
	点.add_theme_stylebox_override("pressed", 空)
	点.add_theme_stylebox_override("hover", 空)
	点.add_theme_stylebox_override("focus", 空)
	点.pressed.connect(func(): 测灵大典请求.emit())
	窗.add_child(点)

	_刷新测灵窗()

# 可见性 + 候选数随状态刷新（测灵完成后 refresh_all 重建时自动隐藏）
func _刷新测灵窗() -> void:
	if _测灵窗 == null:
		return
	if Game == null or not Game.测灵可用():
		_测灵窗.visible = false
		return
	_测灵窗.visible = true
	var 脚: Label = _测灵窗.get_node_or_null("脚") as Label
	if 脚 != null:
		脚.text = "候选 %d 人 · 前往 ▶" % Game.测灵名额()

# ───────── helper ─────────
func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	var s: float = UITheme.UI_SCALE
	c.layout_mode = 0
	c.offset_left = x * s
	c.offset_top = y * s
	c.offset_right = (x + w) * s
	c.offset_bottom = (y + h) * s
	c.size = Vector2(w * s, h * s)

## allow_clip：本页（01 屏）**唯一 clip 调用点** = BandText 心念轮播，传 true。真机制是**纵向**（非横向）：
## BandText 经全局「入树补折行」兜底拿到 autowrap_mode=3 ⇒ 按框宽折行 ⇒ get_minimum_size().y 被顶高
## （实测 框高 67.5 → 折行高 145）⇒ 撑破固定框高、挤坏相邻 UI ⇒ 必须保留 clip 把高度钳回 67.5 框高。
## 其余调用点一律 false —— clip 对它们是「框高 < 行高 ⇒ 整行不绘」的纵向安全网（见下方 P1-A2 护栏）。
## ★ 防后人「统一风格」删掉本形参：删了 clip，BandText 超长文案会折行顶高、撑破气象带。
func _mk_label_in(parent: Control, nm: String, txt: String, x: float, y: float, w: float, h: float,
		font_size: int, color: Color, bold: bool,
		align_h: int, align_v: int, shadow: bool, allow_clip: bool = false) -> Label:
	var lbl := Label.new()
	lbl.name = nm
	lbl.text = txt
	_place(lbl, x, y, w, h)
	lbl.horizontal_alignment = align_h
	lbl.vertical_alignment = align_v
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = allow_clip
	var fsz: int = int(round(float(font_size) * UITheme.UI_SCALE))
	if bold:
		UITheme.apply_title_font_sized(lbl, fsz)
	else:
		UITheme.apply_body_font_sized(lbl, fsz)
	# ── 不静默护栏（P1-A2 §2）──────────────────────────────────────────
	# 框高 < 字体行高 ⇒ Godot 会「整行不绘」且无任何告警（clip 时 get_minimum_size 恒返 (1,1)）。
	# 只报不修：绝不自动改几何，仅把风险自曝到日志。量纲 = frame 物理像素（逻辑 × UI_SCALE）；
	# 行高取应用字体后的 Font.get_height(fsz)。
	var 框高物理: float = h * UITheme.UI_SCALE
	var 行高物理: float = -1.0
	var _护栏字体: Font = lbl.get_theme_font("font")
	if _护栏字体 != null:
		行高物理 = _护栏字体.get_height(fsz)
	if 行高物理 > 框高物理:
		print("[P1A2护栏] 文字可能不上屏：节点 '%s' fsz=%d 行高=%.1f > 框高=%.1f（frame物理像素；逻辑高=%.1f UI_SCALE=%.2f clip_text=%s）" % [
			nm, fsz, 行高物理, 框高物理, h, UITheme.UI_SCALE, str(lbl.clip_text)])
	# 第二查（P1-A2 收尾）：抓「折行后多行累计高度顶高 get_minimum_size().y」——
	# 首查只比单行 Font.get_height(fsz)，看不到 autowrap 折行后的累计高度。只报不修、零行为改动。
	var 折行高物理: float = lbl.get_minimum_size().y
	if 折行高物理 > 框高物理:
		print("[P1A2护栏] 折行累计高可能撑破固定框：节点 '%s' fsz=%d 折行高=%.1f > 框高=%.1f（frame物理像素；逻辑高=%.1f clip_text=%s）" % [
			nm, fsz, 折行高物理, 框高物理, h, str(lbl.clip_text)])
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
		sh.clip_text = allow_clip
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
	_apply_chrome_visibility()
	hide_ui_requested.emit(_hidden_ui)

## 外部（game_ui）要求收起 / 恢复 01 屏 chrome。
## ★ 2026-09-15 语义升级：不再只切 _chrome，而是把「上下暗晕 + 浮标」一并纳入统一状态机，
##   并区分「玩家主动隐藏UI」与「被上层页压下」两个成因（混为一体就是浮标盖二级页的根因）。
##   对外契约不变（仍是一个 bool），调用方 7 处无需改动。
func set_chrome_visible(visible: bool) -> void:
	if visible:
		# 回到首页 / 关闭二级页：复位「玩家主动隐藏」，避免隐藏态残留到下次进首页。
		_chrome_suppressed = false
		_hidden_ui = false
	else:
		# 被二级页 / 消息中心 / 大地图 / 宗主详情压下：只置 suppressed，**不动 _hidden_ui**。
		_chrome_suppressed = true
	_apply_chrome_visibility()

## chrome 三件套统一出口。可见性判据 = 既没被玩家隐藏、也没被上层页压下。
## 新增 BGVeil 同步 —— 这是「按了隐藏UI之后上下还有蒙版」的修复点。
func _apply_chrome_visibility() -> void:
	var 显示: bool = (not _hidden_ui) and (not _chrome_suppressed)
	if _chrome != null and is_instance_valid(_chrome):
		_chrome.visible = 显示
	if _bg_veil != null and is_instance_valid(_bg_veil):
		_bg_veil.visible = 显示
	_update_eye_state()

## 隐藏UI 浮标显隐 / 亮度：
##   · 被上层页压下（_chrome_suppressed）→ 彻底不显示
##       ⇒ 修「点其他界面之后，隐藏ui图标还是显示」（旧实现放 _scene_root 且 z_index=1000，
##         二级页压上来时它反而浮在最上层）。
##   · 隐藏态（_hidden_ui）→ α0.95 提亮：此刻它是屏上唯一可点之物，必须找得到。
##   · 常态 → α0.55 低调待机（贴边悬浮球的通行做法）。
func _update_eye_state() -> void:
	if _eye_btn == null or not is_instance_valid(_eye_btn):
		return
	_eye_btn.visible = not _chrome_suppressed
	_eye_btn.modulate = Color(1, 1, 1, 0.95 if _hidden_ui else 0.55)

# ───────── 只读刷新 ─────────
func refresh() -> void:
	_apply_equipped_skin()
	_refresh_quick_icons()
	_refresh_red_dots()
	_refresh_weather_band()
	_refresh_season_banner()
	_refresh_main_cta()
	_refresh_snapshot_band()
	_刷新测灵窗()

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
	# 同步图标底座皮肤（共享 ShaderMaterial 改 4 个参数 → 全局底座同帧换色）
	UITheme.设图标底座皮肤(skin_id)

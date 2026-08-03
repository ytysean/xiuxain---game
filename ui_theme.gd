# ui_theme.gd — 《太玄宗门录》S1 UI 主题模块（Autoload: UITheme）
# 铁律：业务 UI 一律调用本模块，组件内禁止硬编码颜色/尺寸。
# 依据：design/06-角色与UI/UI交互规范_古风经营A版_V1.0.md §2~§4、§7
extends Node

# ───────── 色彩 token ─────────
const COLOR_BG_BASE: Color = Color(0.106, 0.153, 0.169)       # 暗青黛 底色
const COLOR_PANEL_BG: Color = Color(0.173, 0.243, 0.271)      # #2C3E45 深青灰面板底（降饱和，不要墨绿）
const COLOR_STATUSBAR_BG: Color = Color(0.055, 0.082, 0.090)  # 状态栏/墨底
const COLOR_TOPBAR_BG: Color = Color(0.173, 0.243, 0.271, 0.85)  # 顶部栏 半透明深青底（P2 §二）
const COLOR_BORDER_GOLD: Color = Color(0.788, 0.651, 0.337)   # #C9A656 暗金描边（1~2px）
const COLOR_TEXT_GOLD: Color = Color(1.000, 0.843, 0.478)     # 亮金 核心数值（正常）
const COLOR_TEXT_RED: Color = Color(0.878, 0.471, 0.471)      # color.status.danger #E07878 警示/异常（负值/预警）
const COLOR_TEXT_BODY: Color = Color(0.878, 0.835, 0.745)     # 浅米 正文（旧值，新正文走 COLOR_TEXT_BODY_GOLD）
const COLOR_TEXT_AUX: Color = Color(0.541, 0.494, 0.408)      # 浅灰 辅助（旧值，新辅助走 COLOR_TEXT_BODY_GOLD）
const COLOR_TEXT_BODY_GOLD: Color = Color(0.831, 0.722, 0.416) # #D4B86A 暗金：正文/数值/辅助统一色
const COLOR_TAB_UNSELECTED: Color = Color(0.788, 0.659, 0.396)  # #C9A865 底部 Tab 未选中暗金
const COLOR_BTN_PRESSED: Color = Color(0.078, 0.106, 0.110)   # 主按钮按下态 底色加深
const COLOR_BTN_DISABLED: Color = Color(0.180, 0.196, 0.196)

# ── S1 重架构：按《UI设计令牌v1.0》补齐的色常量（视觉基线；业务色最终收口 UIThemeConfig）──
# 背景分层（内嵌内容面）
const COLOR_BG_CONTENT: Color = Color(0.173, 0.239, 0.263)    # color.bg.content* #2C3D43 面板内嵌内容面
# 文字分层
const COLOR_TEXT_TITLE1: Color = Color(0.902, 0.780, 0.471)   # color.text.title1 #E6C778 一级标题
const COLOR_TEXT_TITLE2: Color = Color(0.941, 0.902, 0.824)   # color.text.title2 #F0E6D2 二级标题
const COLOR_TEXT_BODY_DIM: Color = Color(0.784, 0.722, 0.588) # color.text.body-dim* #C8B896 弱化正文
const COLOR_TEXT_DISABLED: Color = Color(0.333, 0.333, 0.310) # color.text.disabled #55554F 禁用灰
# 功能色
const COLOR_STATUS_SUCCESS: Color = Color(0.494, 0.827, 0.604)# color.status.success #7ED39A 成功/增益
# 业务色 — 品级（物品/装备 8 档）· 视觉基线
const COLOR_TIER_FAN: Color = Color(0.839, 0.839, 0.839)      # tier.fan 凡品 #D6D6D6
const COLOR_TIER_LIANG: Color = Color(0.298, 0.686, 0.478)    # tier.liang 良品 #4CAF7A
const COLOR_TIER_LING: Color = Color(0.247, 0.663, 0.788)     # tier.ling 灵品 #3FA9C9（主理人裁定-升档区分）
const COLOR_TIER_BAO: Color = Color(0.357, 0.545, 0.851)      # tier.bao 宝品 #5B8BD9
const COLOR_TIER_WANG: Color = Color(0.851, 0.627, 0.298)     # tier.wang 王品 #D9A04C
const COLOR_TIER_SHENG: Color = Color(0.690, 0.298, 0.851)    # tier.sheng 圣品 #B04CD9
const COLOR_TIER_XIAN: Color = Color(0.941, 0.902, 0.690)     # tier.xian 仙品 #F0E6B0
const COLOR_TIER_DAO: Color = Color(0.910, 0.941, 1.000)      # tier.dao 道品 #E8F0FF
# 业务色 — 境界（5 档）· 视觉基线
const COLOR_REALM_LIANQI: Color = Color(0.784, 0.722, 0.588)  # realm.lianqi 练气 #C8B896
const COLOR_REALM_ZHUJI: Color = Color(0.298, 0.686, 0.478)   # realm.zhuji 筑基 #4CAF7A
const COLOR_REALM_JINDAN: Color = Color(0.357, 0.545, 0.851)  # realm.jindan 金丹 #5B8BD9
const COLOR_REALM_YUANYING: Color = Color(0.851, 0.627, 0.298)# realm.yuanying 元婴 #D9A04C
const COLOR_REALM_HUASHEN: Color = Color(0.690, 0.298, 0.851) # realm.huashen 化神 #B04CD9

# ───────── 8px 栅格常量 ─────────
const GRID: int = 8
const MARGIN: int = 16
const PAD_PANEL: int = 16
const SIZE_SM: int = 48
const SIZE_MD: int = 64
const SIZE_LG: int = 120
const SIZE_XL: int = 240
const BTN_H_PRIMARY: int = 64
const BTN_H_SECONDARY: int = 48
const TAB_H: int = 60
const TOPBAR_H: int = 56
const OVERVIEW_H: int = 120
const CORE_GRID_H: int = 240

# ───────── 字号（P2 §一 规范：TITLE=30 / H2=22 / BODY=18 / AUX=14，全项目唯一来源，禁止散写魔法数字）─────────
const FONT_TITLE: int = 30
const FONT_VALUE: int = 18
const FONT_BODY: int = 18
const FONT_AUX: int = 14

# 令牌 §2.2 字号阶梯（扩展档，组件按需采用）
const FONT_DISPLAY: int = 40   # font.size.display 巨号/大标题
const FONT_H1: int = 32        # font.size.h1 一级标题
const FONT_H2: int = 22        # font.size.h2 二级标题
const FONT_DENSE: int = 18     # font.size.dense 密集数值

# ───────── 美术资产路径（图标 / 贴图 / 字体 · 集中管理）─────────
# 集中管理 res:// 资源位置；改皮 / 换套仅动本节，组件零硬编码（保持单文件样式管理）。
const ASSET_DIR: String = "res://art/"
# 旧 SVG 线稿图标已废弃，改用写实国漫油画风 PNG 图标（art/ui/buttons/）。
const ICON_DIR: String = "res://art/ui/buttons/"
const PANEL_INK_TEX: String = ASSET_DIR + "panel_ink.svg"
const DIVIDER_TEX: String = ASSET_DIR + "divider_cloud.svg"
# 字体路径：已落盘子集字体（tools/font_subset.py 生成，体积 < 1MB，Godot 4.7 可稳定导入）。
# 注：FONT_TITLE / FONT_BODY 已被上方字号 int 占用 → 路径常量命名 *_PATH 以示区别。
const FONT_TITLE_PATH: String = ASSET_DIR + "fonts/MaShanZheng-Subset.ttf"
const FONT_BODY_PATH: String = ASSET_DIR + "fonts/NotoSerifSC-Subset.otf"

# 中文 label → 图标文件 stem（不含扩展名）。组件按其 Chinese 标签取图，统一写实国漫油画风（§3.1）。
# 所有图标已迁移到 res://art/ui/buttons/，扩展名为 .png。
const ICON_BY_LABEL: Dictionary = {
	# ── 底部主导航（normal/selected 成对）──
	"宗门": "nav_jy_normal",
	"宗门_选中": "nav_jy_selected",
	"弟子": "nav_dz_normal",
	"弟子_选中": "nav_dz_selected",
	"历练": "nav_ll_normal",
	"历练_选中": "nav_ll_selected",
	"纪事": "nav_js_normal",
	"纪事_选中": "nav_js_selected",
	"殿阁": "grid_jz",              # 底部 5 Tab 中“殿阁”用六宫格总览图标
	"更多": "nav_gd_normal",
	"更多_选中": "nav_gd_selected",

	# ── 宗门首页六宫格入口 ──
	"殿阁总览": "grid_jz",
	"弟子录": "grid_dz",
	"丹器炼制": "grid_dq",
	"宗门洞府": "grid_df",
	"差事目标": "grid_rw",
	"宗门库藏": "grid_zc",

	# ── 殿阁页内部殿阁图标（bld_*）──
	"宗门正殿": "bld_zd",
	"执事殿": "bld_jy",
	"灵田": "bld_lt",
	"矿脉": "bld_km",
	"探微阁": "bld_tw",
	"丹殿": "bld_dt",
	"器殿": "bld_qt",
	"功勋阁": "bld_gx",
	"阵殿": "bld_zt",
	"藏书阁": "bld_cs",
	"商驿": "bld_sy",

	# ── 主操作按钮 / 返回按钮（长条底板，无中心图）──
	"主按钮_常态": "btn_primary_normal",
	"主按钮_悬浮": "btn_primary_hover",
	"主按钮_点击": "btn_primary_press",
	"次按钮_常态": "btn_secondary_normal",
	"次按钮_悬浮": "btn_secondary_hover",
	"次按钮_点击": "btn_secondary_press",
	"返回按钮_常态": "btn_back_normal",
	"返回按钮_点击": "btn_back_press",

	# ── 子标签 / 筛选标签（长条底板）──
	"子标签_常态": "subtab_normal",
	"子标签_选中": "subtab_selected",
	"筛选_常态": "filter_normal",
	"筛选_选中": "filter_selected",

	# ── 顶栏资源小图标（20×20）──
	"灵石": "res_lingshi",
	"灵气": "res_lingqi",
	"灵植": "res_lingzhi",
	"声望": "res_shengwang",
	# 旧兼容键（部分旧代码可能传小写 stem）
	"lingshi": "res_lingshi",
	"lingqi": "res_lingqi",
	"lingzhi": "res_lingzhi",
	"shengwang": "res_shengwang",

	# ── 玩法入口按钮（play_*）──
	"历练派遣": "play_lj",
	"炼制": "play_lz",
	"招募": "play_zm",
	"突破": "play_tp",

	# ── 管理操作按钮（op_*）──
	"任命": "op_renming",
	"罢免": "op_bamian",
	"自动": "op_auto",
	"调配": "op_tiaopei",
	"审核": "op_shenhe",
	"记录": "op_jilu",

	# ── 炼制操作按钮（refine_*）──
	"开始炼制": "refine_start",
	"加速炼制": "refine_speed",
	"切换丹方": "refine_recipe",
	"布阵": "refine_array",

	# ── 商店入口按钮（shop_*）──
	"签到": "shop_signin",
	"商城": "shop_mall",
	"活动": "shop_event",
	"首充": "shop_firstpay",

	# ── 物品品阶槽位（slot_*）──
	"槽位_凡": "slot_fan",
	"槽位_灵": "slot_ling",
	"槽位_宝": "slot_bao",
	"槽位_王": "slot_wang",
	"槽位_圣": "slot_sheng",
	"槽位_仙": "slot_xian",
	"槽位_道": "slot_dao",

	# ── 确认弹窗按钮（长条底板）──
	"确认_正常": "confirm_ok",
	"取消_正常": "confirm_cancel",
	"危险确认": "confirm_danger",
	"关闭_正常": "confirm_close",
}

# 字体缓存（首次探测后缓存，避免对缺失文件重复 load 刷错误日志）
var _font_probed: bool = false
var _font_title_res: FontFile
var _font_body_res: FontFile

# ───────── 组件形制常量 ─────────
const RADIUS_PANEL: int = 8
const RADIUS_BUTTON: int = 6
const BORDER_W: int = 1

# ───────── 色彩 getter ─────────
func color_bg_base() -> Color: return COLOR_BG_BASE
func color_panel_bg() -> Color: return COLOR_PANEL_BG
func color_statusbar_bg() -> Color: return COLOR_STATUSBAR_BG
func color_border_gold() -> Color: return COLOR_BORDER_GOLD
func color_text_gold() -> Color: return COLOR_TEXT_GOLD
func color_text_body() -> Color: return COLOR_TEXT_BODY
func color_text_aux() -> Color: return COLOR_TEXT_AUX
# 核心数值：正常暗金 / 异常暗红
func color_value(abnormal: bool) -> Color: return COLOR_TEXT_RED if abnormal else COLOR_TEXT_BODY_GOLD

# ── 令牌色 getter（对齐 UI设计令牌v1.0，供组件按需取色）──
func color_bg_content() -> Color: return COLOR_BG_CONTENT
func color_text_title1() -> Color: return COLOR_TEXT_TITLE1
func color_text_title2() -> Color: return COLOR_TEXT_TITLE2
func color_text_body_dim() -> Color: return COLOR_TEXT_BODY_DIM
func color_text_disabled() -> Color: return COLOR_TEXT_DISABLED
func color_status_success() -> Color: return COLOR_STATUS_SUCCESS
func color_status_danger() -> Color: return COLOR_TEXT_RED

# ───────── 字体 helper ─────────
# 优先取 FONT_TITLE_PATH / FONT_BODY_PATH 已落盘的字体文件，落盘缺失时退回字号+颜色 override（不阻断运行）。
func _ensure_fonts() -> void:
	if _font_probed:
		return
	_font_probed = true
	if FileAccess.file_exists(FONT_TITLE_PATH):
		_font_title_res = load(FONT_TITLE_PATH) as FontFile
	if FileAccess.file_exists(FONT_BODY_PATH):
		_font_body_res = load(FONT_BODY_PATH) as FontFile

func apply_title_font(control: Control) -> void:
	_ensure_fonts()
	control.add_theme_font_size_override("font_size", FONT_TITLE)
	control.add_theme_color_override("font_color", COLOR_TEXT_TITLE1)
	if _font_title_res != null:
		control.add_theme_font_override("font", _font_title_res)

# 小号楷体：标题 / 按钮文字 / Tab 名称 用古风楷体 MaShanZheng，但按需要缩小字号。
# apply_title_font 固定 30px 会撑爆小控件；P2 §一 要求 Tab名称/按钮文字→楷体，§三 要求 14px，故提供可控字号版。
func apply_title_font_sized(control: Control, size: int) -> void:
	_ensure_fonts()
	if _font_title_res != null:
		control.add_theme_font_override("font", _font_title_res)
	control.add_theme_font_size_override("font_size", size)

func apply_number_font(control: Control) -> void:
	# 数值（战力/资源）用古风等宽数字感：当前无独立数字字体文件，
	# 回落到宋体(_font_body_res) 并显式设定字号，开启 font_keep_to_baseline 让数字基线对齐。
	# P2 §一：全项目数值统一走本 helper，禁止裸 Label 用默认字体。
	_ensure_fonts()
	if _font_body_res != null:
		control.add_theme_font_override("font", _font_body_res)
	control.add_theme_font_size_override("font_size", FONT_VALUE)
	control.add_theme_constant_override("font_keep_to_baseline", 1)

func apply_value_font(control: Control, abnormal: bool = false) -> void:
	apply_number_font(control)
	control.add_theme_color_override("font_color", color_value(abnormal))

func apply_body_font(control: Control) -> void:
	_ensure_fonts()
	control.add_theme_font_size_override("font_size", FONT_BODY)
	control.add_theme_color_override("font_color", COLOR_TEXT_BODY_GOLD)
	if _font_body_res != null:
		control.add_theme_font_override("font", _font_body_res)

# 可控字号正文：与 apply_title_font_sized 对称，用于需要固定 14/18px 等宋体正文的场景。
func apply_body_font_sized(control: Control, size: int) -> void:
	_ensure_fonts()
	if _font_body_res != null:
		control.add_theme_font_override("font", _font_body_res)
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", COLOR_TEXT_BODY_GOLD)

func apply_aux_font(control: Control) -> void:
	_ensure_fonts()
	control.add_theme_font_size_override("font_size", FONT_AUX)
	control.add_theme_color_override("font_color", COLOR_TEXT_BODY_GOLD)
	if _font_body_res != null:
		control.add_theme_font_override("font", _font_body_res)

# 落盘探测：返回是否两套字体均就位（用于启动日志 / 降级提示，不阻断）。
func apply_fonts() -> bool:
	_ensure_fonts()
	return _font_title_res != null and _font_body_res != null

# ───────── 面板（圆角8 / 1px暗金描边 / 暗纹底 / 内边距16）─────────
# make_panel_stylebox(use_ink) 优先用 panel_ink.svg 自包含面板蒙皮（暗纹 + 暗金描边，9-slice 锁定四角），
# 缺失则退化为 StyleBoxFlat（panel 基色 + 严格 1px 暗金描边）。
# 注：自包含面板蒙皮的描边粗细随面板 9-slice 等比缩放（约 2-3px @ S1 典型面板尺寸），
#     比 V1.0 §2.4 规范的 1px 略粗以适配手机端可读性；如需严格 1px → 调用 make_panel_stylebox(false)。
func make_panel_stylebox(use_ink: bool = true) -> StyleBox:
	if use_ink:
		var tex: Texture2D = load_panel_ink()
		if tex != null:
			var sb_t := StyleBoxTexture.new()
			sb_t.texture = tex
			# 9-slice：锁定四角圆角区（与 panel_ink.svg 的 rx=16 对齐），中间拉伸
			sb_t.set_texture_margin_all(RADIUS_PANEL + 8)
			sb_t.set_content_margin_all(PAD_PANEL)
			return sb_t
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL_BG
	sb.border_color = COLOR_BORDER_GOLD
	sb.set_corner_radius_all(RADIUS_PANEL)
	sb.set_border_width_all(BORDER_W)
	sb.set_content_margin_all(PAD_PANEL)
	return sb

func apply_panel_style(control: Control, use_ink: bool = true) -> void:
	# 作用于 Panel / PanelContainer 的 "panel" 样式；其余容器请包裹 PanelContainer
	control.add_theme_stylebox_override("panel", make_panel_stylebox(use_ink))

# ───────── 统一扁平面板蒙皮（S1 首页三文件共用）─────────
# 替代原本各自硬编码的 StyleBoxFlat：统一深青灰底 + 暗金描边 + 小圆角 + 极淡内阴影。
# 顶栏胶囊、右侧悬浮节点、宗门动态面板均走此入口，保证视觉语言一致。
func make_panel_stylebox_flat(bg: Color, border: Color, radius: int, border_w: int) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.set_content_margin_all(PAD_PANEL)
	# 极淡内阴影：低透明黑 + 小 blur，增加温润质感，不抢主体
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 0)
	return sb

func apply_panel_style_flat(control: Control, bg: Color, border: Color, radius: int, border_w: int) -> void:
	control.add_theme_stylebox_override("panel", make_panel_stylebox_flat(bg, border, radius, border_w))

# ───────── 首页专用面板蒙皮（宗门动态面板 / 右侧悬浮节点）─────────
# 圆角 16 / 2px 暗金描边 / 面板底(COLOR_PANEL_BG=#2C3E45) @ 指定 alpha（透出背景山门）。
# 与 make_panel_stylebox 的区别：固定大圆角 + 2px 描边 + 半透明底（规格 §3.3/§3.4）。
func make_home_panel_stylebox(alpha: float = 0.85) -> StyleBox:
	return make_panel_stylebox_flat(Color(COLOR_PANEL_BG, alpha), COLOR_BORDER_GOLD, 16, 2)

func apply_home_panel_style(control: Control, alpha: float = 0.85) -> void:
	control.add_theme_stylebox_override("panel", make_home_panel_stylebox(alpha))

# 宗门动态面板蒙皮（规格 §3.3：432×148、圆角 12、2px 暗金描边、纯色半透明深青底 #2C3E45 @ α）。
func make_dynamics_panel_stylebox(alpha: float = 0.82) -> StyleBox:
	return make_panel_stylebox_flat(Color(COLOR_PANEL_BG, alpha), COLOR_BORDER_GOLD, 12, 2)

func apply_dynamics_panel_style(control: Control, alpha: float = 0.82) -> void:
	control.add_theme_stylebox_override("panel", make_dynamics_panel_stylebox(alpha))

# ───────── 顶部栏胶囊条蒙皮（参考图效果：整根圆角胶囊、半透明深青底、1px 暗金描边）─────────
func apply_topbar_capsule_style(control: Control) -> void:
	var sb: StyleBox = make_panel_stylebox_flat(Color(COLOR_TOPBAR_BG, 0.85), COLOR_BORDER_GOLD, 10, 1)
	sb.set_content_margin_all(6)
	control.add_theme_stylebox_override("panel", sb)

# ───────── 首页右侧悬浮资源节点蒙皮（规格 §3.4：~106×85、圆角 10、1px 暗金描边、深青半透明 α0.85）─────────
func apply_float_node_style(control: Control, alpha: float = 0.85) -> void:
	var sb: StyleBox = make_panel_stylebox_flat(Color(COLOR_PANEL_BG, alpha), COLOR_BORDER_GOLD, 10, 1)
	sb.set_content_margin_all(GRID)
	control.add_theme_stylebox_override("panel", sb)

# ───────── 主按钮（高64 / 圆角6 / 暗底金边 / 三态 normal/pressed/disabled）─────────
func apply_primary_button_style(btn: BaseButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_PANEL_BG
	normal.border_color = COLOR_BORDER_GOLD
	normal.set_corner_radius_all(RADIUS_BUTTON)
	normal.set_border_width_all(BORDER_W)
	normal.set_content_margin_all(GRID)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COLOR_BTN_PRESSED
	pressed.border_color = COLOR_TEXT_GOLD
	pressed.set_corner_radius_all(RADIUS_BUTTON)
	pressed.set_border_width_all(BORDER_W)
	pressed.set_content_margin_all(GRID)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = COLOR_BTN_DISABLED
	disabled.border_color = COLOR_BORDER_GOLD
	disabled.set_corner_radius_all(RADIUS_BUTTON)
	disabled.set_border_width_all(BORDER_W)
	disabled.set_content_margin_all(GRID)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("hover", normal)

# ───────── 次按钮（高48 / 圆角6 / 细描边）─────────
func apply_secondary_button_style(btn: BaseButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_PANEL_BG
	normal.border_color = COLOR_BORDER_GOLD
	normal.set_corner_radius_all(RADIUS_BUTTON)
	normal.set_border_width_all(BORDER_W)
	normal.set_content_margin_all(GRID)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COLOR_BTN_PRESSED
	pressed.border_color = COLOR_TEXT_GOLD
	pressed.set_corner_radius_all(RADIUS_BUTTON)
	pressed.set_border_width_all(BORDER_W)
	pressed.set_content_margin_all(GRID)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = COLOR_BTN_DISABLED
	disabled.border_color = COLOR_BORDER_GOLD
	disabled.set_corner_radius_all(RADIUS_BUTTON)
	disabled.set_border_width_all(BORDER_W)
	disabled.set_content_margin_all(GRID)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("hover", normal)

# ───────── Tab（高64 / 选中=暗金文字+细下划线）─────────
func apply_tab_style(btn: BaseButton, selected: bool) -> void:
	btn.add_theme_font_size_override("font_size", FONT_BODY)
	btn.add_theme_color_override("font_color", COLOR_TEXT_GOLD if selected else COLOR_TEXT_AUX)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT_GOLD)
	btn.add_theme_color_override("font_pressed_color", COLOR_TEXT_GOLD)

# ───────── 分割线（1px 暗金云纹）─────────
# 优先用 divider_cloud.svg（1px 暗金细线 + 云纹意象），缺失退化为纯暗金分割线。
func make_divider_stylebox() -> StyleBox:
	var tex: Texture2D = load_divider_cloud()
	if tex != null:
		var sb_t := StyleBoxTexture.new()
		sb_t.texture = tex
		# 9-slice 锁定细线主体（4px 高 + 左右各扩 2px 防云纹拉伸变形）
		sb_t.set_texture_margin_all(2)
		return sb_t
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BORDER_GOLD
	sb.set_content_margin_all(0)
	return sb

# 返回一条横向细暗金分割线（TextureRect 云纹平铺 / ColorRect 兜底，挂到容器即可）
func make_divider_control() -> Control:
	var tex: Texture2D = load_divider_cloud()
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.stretch_mode = TextureRect.STRETCH_TILE
		# 略高于 BORDER_W 以给云纹意象留呼吸空间（仍属极细装饰）
		tr.custom_minimum_size = Vector2(0, BORDER_W + 1)
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var c := ColorRect.new()
	c.color = COLOR_BORDER_GOLD
	c.custom_minimum_size = Vector2(0, BORDER_W)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func apply_divider(control: Control) -> void:
	control.add_theme_stylebox_override("panel", make_divider_stylebox())

# ───────── 资产加载 helper（图标 / 贴图）─────────
# 按 Chinese label 取图标（§3.1 修真器物映射）；label 不在 ICON_BY_LABEL → 返 null，调用方保留原占位。
# 图标已迁移为 .png；load() 内部按路径缓存结果，重复调用成本极低。
func load_icon(label: String) -> Texture2D:
	var stem: String = ICON_BY_LABEL.get(label, "")
	if stem == "":
		return null
	return load(ICON_DIR + stem + ".png") as Texture2D

# 取底部导航 Tab 图标，根据选中状态自动切换 normal/selected。
# label 为 Tab 中文名（宗门/弟子/历练/纪事/殿阁/更多）。
func load_tab_icon(label: String, selected: bool = false) -> Texture2D:
	var suffix: String = "_选中" if selected else ""
	var key: String = label + suffix
	# 没有成对状态的 Tab（如殿阁）fallback 到普通图标
	if not ICON_BY_LABEL.has(key):
		key = label
	return load_icon(key)

# 按 label 取图标并光栅化缩放到指定尺寸（正方形）。
# 用于绕过某些 Godot 4.7 build 中 Button.icon_max_width 不可用的问题。
func load_icon_sized(label: String, size: int) -> Texture2D:
	var tex: Texture2D = load_icon(label)
	if tex == null or size <= 0:
		return tex
	var img: Image = tex.get_image()
	if img == null:
		return tex
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

# ───────── 资源数值格式化（首页/顶栏万缀显示）─────────
# >=10000 显示为 X.X万（snapped 到 0.1），否则显示整数。纯函数，供 TopBar / 宗门动态面板复用。
static func format_resource(value: int) -> String:
	if value >= 10000:
		var wan: float = value / 10000.0
		return "%g万" % snapped(wan, 0.1)
	return str(value)

# 加载面板暗纹贴图；缺失返 null（make_panel_stylebox 退化为 StyleBoxFlat）。
func load_panel_ink() -> Texture2D:
	return load(PANEL_INK_TEX) as Texture2D

# 加载分割线云纹贴图；缺失返 null（make_divider_* 退化为纯暗金分割线）。
func load_divider_cloud() -> Texture2D:
	return load(DIVIDER_TEX) as Texture2D

# 暴露单个字体资源的方法（供外部场景按需读取标题/正文字体）。
func load_title_font() -> FontFile:
	_ensure_fonts()
	return _font_title_res

func load_body_font() -> FontFile:
	_ensure_fonts()
	return _font_body_res

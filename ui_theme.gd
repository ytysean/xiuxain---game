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
const COLOR_BTN_PRIMARY: Color = Color(0.173, 0.373, 0.322)   # #2C5F52 主按钮墨绿（头像选择「确认使用」钮）

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
# ── M2/M3 首页单源化收口：原 home_page.tscn 散落的栏底/分割线色（命名收口，非全局 token）──
const COLOR_HOME_BAR_BG: Color = Color(0.118, 0.169, 0.157)   # #1E2B28 首页栏/面板底（BarBG / PanelStyle 底）
const COLOR_HOME_DIVIDER: Color = Color(0.784, 0.659, 0.416)  # #C8A86A 首页分割线/描边（Divider / TopLine / PanelStyle 边）
# 品阶/境界色唯一来源 → UIThemeConfig.QUALITY_COLOR / REALM_COLOR（数据驱动换皮）

# ───────── 01 屏（主界面·宗门主城）画布 1:1 色 token ─────────
# 唯一数据源 = Ardot 画布 2:55，色值逐位取自画布节点 fills/strokes，组件禁止再散写字面量。
# 命名前缀 C01_ 表示「01 屏专属」，与全局 token 区分，避免污染既有换皮体系。
const C01_TOPBAR_BG: Color = Color(0.067, 0.129, 0.165)          # 2:181 顶部资源栏底
const C01_AVATAR_BG: Color = Color(0.122, 0.227, 0.271)          # 2:183 头像底
const C01_GOLD_LINE: Color = Color(0.549, 0.420, 0.247)          # 通用暗金描边（头像/浮层/历法条）
const C01_TEXT_PRIMARY: Color = Color(0.949, 0.960, 0.953)       # #F2F5F3 一级文字（宗主名/活跃度）
const C01_TEXT_GOLD: Color = Color(0.839, 0.690, 0.416)          # #D6B16A 金色数值/选中标签（定稿稿统一金色）
const C01_TEXT_SECONDARY: Color = Color(0.812, 0.776, 0.698)     # #CFC6B2 二级文字（资源名/入口标签）
const C01_TEXT_TERTIARY: Color = Color(0.624, 0.702, 0.690)      # #9FB3B0 三级文字（结算提示/未选中Tab）
const C01_FLOAT_BG: Color = Color(0.094, 0.176, 0.216)           # 2:222 日常进度浮层底
const C01_CALENDAR_BG: Color = Color(0.059, 0.118, 0.149, 0.90)  # 50:1 历法条底
const C01_ENTRY_BG: Color = Color(0.094, 0.173, 0.216, 0.45)     # 2:207 等 快捷入口底（提高 α 让图标/文字在山水背景上更清晰）
const C01_PROG_TRACK: Color = Color(0.055, 0.114, 0.141, 0.40)   # 2:224 活跃度轨道
const C01_PROG_FILL: Color = Color(0.839, 0.694, 0.416)          # 2:225 活跃度填充 / Tab 选中指示器
const C01_TAB_CAPSULE: Color = Color(0.066, 0.129, 0.164, 0.12)  # 2:227 Tab 胶囊容器底
const C01_TAB_ACTIVE: Color = Color(0.121, 0.227, 0.270, 0.25)   # 2:228 Tab 选中底
const C01_TAB_IDLE: Color = Color(0.121, 0.227, 0.270, 0.06)     # 2:231 等 Tab 未选中底
const C01_TAB_BAR_BG: Color = Color(0.027, 0.071, 0.078, 0.94)   # 2:226 底部 Tab 栏背景 #071214@0.94
const C01_TAB_ICON_BG_SEL: Color = Color(0.055, 0.165, 0.188, 0.80) # 2:117 选中图标底 #0E2A30@0.8
const C01_TAB_ICON_BG_IDLE: Color = Color(0.047, 0.118, 0.133, 0.60) # 2:119 未选中图标底 #0C1E22@0.6
const C01_CLOUD: Color = Color(0.620, 0.800, 0.860, 0.14)        # 2:203 云海（画布 fills 实测 α0.14）
const C01_SCENE_BASE: Color = Color(0.043, 0.078, 0.094)         # 2:55 底色 / 35:2 渐变终点
const C01_EYE_BG: Color = Color(0.043, 0.078, 0.094, 0.55)       # 35:5 隐藏UI开关底
const C01_EYE_BORDER: Color = Color(0.173, 0.290, 0.337, 0.80)   # 35:5 描边
const C01_EYE_ICON: Color = Color(0.788, 0.698, 0.494)           # 35:7 眼睛线条
# v5 稿新增/修正 token（compose_v5_framed.py 1080p 实测）
const C01_PANEL_A: Color = Color(0.047, 0.094, 0.086, 0.784)      # 2:181 顶部资源栏底（带 α）
const C01_PANEL_LIGHT: Color = Color(0.098, 0.176, 0.165, 0.706)  # 50:1 时间匾额底
const C01_TEXT_JADE: Color = Color(0.420, 0.769, 0.714)          # Lv.等级 青绿字
const C01_LINE_GOLD: Color = Color(0.839, 0.694, 0.416, 0.471)   # 顶部栏 2px 描边（带 α）
# 山水背景文字兜底 1px 深青灰投影（记忆铁律：浮在山水上的文字加此阴影，肉眼几乎无特效感）
const C01_SHADOW: Color = Color(0.039, 0.090, 0.122, 0.55)

# ───────── 05 屏（任务·宗务）画布 1:1 色 token ─────────
# 唯一数据源 = Ardot 画布 2:59。底色/页头/卡片底/图标圆底/文字与 C01_* 完全同值（直接复用 C01_*），
# 此处仅补齐 05 屏独有且 C01 未覆盖的颜色（进度青填充 / 奖励蓝 / 图标紫 / 金渐变按钮 / 按钮深色字）。
const C05_PROG_TRACK: Color = Color(0.055, 0.114, 0.141)        # 2:437 进度轨道（实心；C01_PROG_TRACK 带 α 故单列）
const C05_PROG_FILL_CYAN: Color = Color(0.310, 0.765, 0.690)    # 2:456 任务卡进度填充 青
const C05_REWARD_BLUE: Color = Color(0.290, 0.620, 0.878)       # 2:458 奖励·灵气 蓝
const C05_ICON_PURPLE: Color = Color(0.710, 0.482, 0.910)       # 2:450 宗门类图标圆底内字 紫
const C05_BTN_GRAD: Color = Color(0.910, 0.770, 0.450)          # 2:487 金渐变按钮基色（渐变近似为实色金）
const C05_BTN_GRAD_DK: Color = Color(0.790, 0.610, 0.270)       # 2:487 金渐变按钮按下/描边 暗金
const C05_BTN_TEXT_DARK: Color = Color(0.102, 0.071, 0.024)     # 2:487 金渐变按钮字 深色
# 07 屏（社交 · 道友）画布 1:1 色 token（Ardot 2:61；底色/页头/卡片底/头像底复用 C01_*）
const C05_TEXT_GOLD: Color = Color(0.910, 0.773, 0.447)        # 2:548/2:553 金色（标题/选中Tab/+号/互动）
const C05_TEXT_PRIMARY: Color = Color(0.929, 0.906, 0.847)    # 2:548 一级文字（标题/好友名/消息名）
const C05_TEXT_SECONDARY: Color = Color(0.576, 0.651, 0.671)  # 2:555 二级文字（未选中Tab/状态/消息内容）
const C05_TEXT_TERTIARY: Color = Color(0.368, 0.443, 0.471)   # 2:589 三级文字（消息时间/输入占位）
const C05_FRIEND_CYAN: Color = Color(0.494, 0.839, 0.647)     # 2:560 好友头像选中描边 青

# ───────── 8px 栅格常量 ─────────
# 设计基准分辨率 480×854 → 渲染 1080×1920（2.25× = 旧 1.5× 再 ×1.5）。所有 01 屏 UI 坐标/字号/面板圆角统一乘此值，
# 保证几何像素级 1:1 复刻且文字/线稿锐利。改分辨率须同步动本常量 + 下方派生渲染系常量（GRID/MARGIN/SIZE_*/FONT_* 等，已固化，须同步 ×1.5）。
const UI_SCALE: float = 2.25
const GRID: int = 12
const MARGIN: int = 24
const PAD_PANEL: int = 24
const SIZE_SM: int = 72
const SIZE_MD: int = 96
const SIZE_LG: int = 180
const SIZE_XL: int = 360
const BACK_BTN_SIZE: int = 40          # 二级页返回按钮设计基准（触控目标 ≥44px，统一纯箭头图标）
const BTN_H_PRIMARY: int = 96
const BTN_H_SECONDARY: int = 72
const TAB_H: int = 180      # 底部Tab栏收窄高度（80逻辑单位 × 2.25）
const TOPBAR_H: int = 158   # 顶部资源栏收窄高度（70逻辑单位 × 2.25）
const OVERVIEW_H: int = 180
const CORE_GRID_H: int = 360

# ───────── 字号（P2 §一 规范：TITLE=45 / H2=33 / BODY=27 / AUX=21，全项目唯一来源，禁止散写魔法数字 · 1080 基准 ×1.5）─────────
const FONT_TITLE: int = 45
const FONT_VALUE: int = 27
const FONT_BODY: int = 27
const FONT_AUX: int = 21

# 令牌 §2.2 字号阶梯（扩展档，组件按需采用 · 1080 基准 ×1.5）
const FONT_DISPLAY: int = 60   # font.size.display 巨号/大标题
const FONT_H1: int = 48        # font.size.h1 一级标题
const FONT_H2: int = 33        # font.size.h2 二级标题
const FONT_DENSE: int = 27     # font.size.dense 密集数值

# ───────── 美术资产路径（图标 / 贴图 / 字体 · 集中管理）─────────
# 集中管理 res:// 资源位置；改皮 / 换套仅动本节，组件零硬编码（保持单文件样式管理）。
const ASSET_DIR: String = "res://art/"
# 旧 SVG 线稿图标已废弃，改用写实国漫油画风 PNG 图标（art/ui/buttons/）。
const ICON_DIR: String = "res://art/ui/buttons/"
# 01 屏画布 1:1 高清青蓝图标（四档 LANCZOS + USM 优化产物，按目标像素整数落盘，禁二次缩放）。
const ICON_HD_DIR: String = "res://art/icons/hd/"
const PANEL_INK_TEX: String = ASSET_DIR + "panel_ink.svg"
const DIVIDER_TEX: String = ASSET_DIR + "divider_cloud.svg"
# 字体路径：已落盘子集字体（tools/font_subset.py 生成，体积 < 1MB，Godot 4.7 可稳定导入）。
# 注：FONT_TITLE / FONT_BODY 已被上方字号 int 占用 → 路径常量命名 *_PATH 以示区别。
# Ardot 画布字体 = Source Han Sans CN；标题/入口标签/Tab 标签用 Bold，数值/正文用 Medium。
# 本地无 Medium 字重文件，以 Regular + FontVariation 轻量 embolden 模拟 Medium。
const FONT_TITLE_PATH: String = ASSET_DIR + "fonts/SourceHanSansCN-Bold.otf"
const FONT_BODY_PATH: String = ASSET_DIR + "fonts/SourceHanSansCN-Regular.otf"

# 中文 label → 图标文件 stem（不含扩展名）。组件按其 Chinese 标签取图，统一写实国漫油画风（§3.1）。
# 所有图标已迁移到 res://art/ui/buttons/，扩展名为 .png。
const ICON_BY_LABEL: Dictionary = {
	# ── 底部主导航（normal/selected 成对）──
	"宗门": "res://art/icons/hd/tab_sect_36.png",
	"宗门_选中": "res://art/icons/hd/tab_sect_36.png",
	"弟子": "res://art/icons/hd/tab_disciple_36.png",
	"弟子_选中": "res://art/icons/hd/tab_disciple_36.png",
	"历练": "res://art/icons/hd/tab_explore_36.png",
	"历练_选中": "res://art/icons/hd/tab_explore_36.png",
	"纪事": "res://art/icons/hd/tab_chronicle_36.png",
	"纪事_选中": "res://art/icons/hd/tab_chronicle_36.png",
	"殿阁": "res://art/icons/hd/tab_building_36.png",
	"更多": "res://art/icons/entry/entry_more_36.png",
	"更多_选中": "res://art/icons/entry/entry_more_36.png",

	# ── 宗门首页六宫格入口 ──
	"殿阁总览": "res://art/icons/building/hall_zhishi_36.png",
	"弟子录": "res://art/icons/entry/entry_tujian_36.png",
	"丹器炼制": "res://art/icons/entry/entry_pill_formula_36.png",
	"宗门洞府": "res://art/icons/entry/entry_huanxing_36.png",
	"差事目标": "res://art/icons/entry/entry_zongmenyaowu_36.png",
	"宗门库藏": "res://art/icons/entry/entry_kucang_36.png",

	# ── 殿阁页内部殿阁图标（bld_*）──
	"宗门正殿": "res://art/icons/building/hall_tanwei_36.png",
	"执事殿": "res://art/icons/building/hall_zhishi_36.png",
	"灵田": "res://art/icons/building/hall_lingtian_36.png",
	"矿脉": "res://art/icons/building/hall_kuangmai_36.png",
	"探微阁": "res://art/icons/building/hall_qidian_36.png",
	"丹殿": "res://art/icons/building/hall_dantang_36.png",
	"器殿": "res://art/icons/building/hall_xichi_36.png",
	"功勋阁": "res://art/icons/building/hall_gongxun_36.png",
	"阵殿": "res://art/icons/building/hall_zhenfa_36.png",
	"藏书阁": "res://art/icons/building/hall_cangjing_36.png",
	"坊市": "res://art/icons/entry/entry_fangshi_36.png",

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
	"灵石": "res://art/icons/resource/res_lingshi_36.png",
	"灵气": "res://art/icons/resource/res_lingqi_36.png",
	"灵植": "res://art/icons/resource/res_lingzhi_36.png",
	"声望": "res://art/icons/resource/res_shengwang_36.png",
	# 旧兼容键（部分旧代码可能传小写 stem）
	"lingshi": "res://art/icons/resource/res_lingshi_36.png",
	"lingqi": "res://art/icons/resource/res_lingqi_36.png",
	"lingzhi": "res://art/icons/resource/res_lingzhi_36.png",
	"shengwang": "res://art/icons/resource/res_shengwang_36.png",

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
	"布阵": "res://art/icons/entry/entry_zhenfa_36.png",

	# ── 商店入口按钮（shop_*）──
	"签到": "res://art/icons/entry/entry_qiandao_36.png",
	"商城": "res://art/icons/entry/entry_fangshi_36.png",
	"活动": "res://art/icons/entry/entry_activity_36.png",
	"首充": "res://art/icons/entry/entry_activity_36.png",

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

# 字体缓存（首次探测后缓存，避免对缺失文件重复 load 刷错误日志）。
# 画布使用 Source Han Sans CN Medium；本地仅落盘 Regular，故用 FontVariation 做轻量 embolden 模拟 Medium。
var _font_probed: bool = false
var _font_title_res: Font
var _font_body_res: Font

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
	_font_title_res = _load_font(FONT_TITLE_PATH)
	_font_body_res = _load_medium_variation(FONT_BODY_PATH)

# 直接加载 Ardot 画布对应字重（Bold / Regular）。
func _load_font(path: String) -> Font:
	if not FileAccess.file_exists(path):
		return null
	return load(path) as FontFile

# 以 Regular 字体为 base，通过 FontVariation.variation_embolden 模拟 Medium 字重。
# 沙箱无 SourceHanSansCN-Medium.otf，此为工程可用方案；后续拿到 Medium 文件后替换本函数即可。
func _load_medium_variation(path: String) -> Font:
	if not FileAccess.file_exists(path):
		return null
	var base: FontFile = load(path) as FontFile
	if base == null:
		return null
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_embolden = 0.25
	return fv

func apply_title_font(control: Control) -> void:
	_ensure_fonts()
	control.add_theme_font_size_override("font_size", FONT_TITLE)
	control.add_theme_color_override("font_color", COLOR_TEXT_TITLE1)
	if _font_title_res != null:
		control.add_theme_font_override("font", _font_title_res)

# 标题字体：全局统一 Source Han Sans CN（思源黑体），标题 / 按钮文字 / Tab 名称 均走同一无衬线黑体。
# apply_title_font 固定 30px 会撑爆小控件；P2 §一 要求 Tab名称/按钮文字字号，§三 要求 14px，故提供可控字号版。
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

# ───────── 统一字体角色（字号+字重+颜色 一次性收口）─────────
# 业务 UI 按语义角色调用，禁止再散写 add_theme_font_size_override + font_color。
# 角色层级：Display > PageTitle > SectionTitle > Body/Value/Button > Aux

func apply_page_title(control: Control) -> void:
	# 页面大标题：45px Bold 亮金（如 弟子录 / 玄榜 / 设置）
	apply_title_font_sized(control, FONT_TITLE)
	control.add_theme_color_override("font_color", COLOR_TEXT_TITLE1)

func apply_section_title(control: Control) -> void:
	# 分区/卡片标题：33px Bold 米白（如 接引决策 / 门规严格度 / 音频）
	apply_title_font_sized(control, FONT_H2)
	control.add_theme_color_override("font_color", COLOR_TEXT_TITLE2)

func apply_body_text(control: Control) -> void:
	# 正文/行标签：27px Medium 暗金米
	apply_body_font(control)

func apply_aux_text(control: Control) -> void:
	# 辅助/说明/时间：21px Medium 暗金米
	apply_aux_font(control)

func apply_value_text(control: Control, abnormal: bool = false) -> void:
	# 数值/关键值：27px Medium，正常暗金 / 异常暗红
	apply_value_font(control, abnormal)

func apply_button_label(control: Control, dark: bool = false) -> void:
	# 按钮文字：27px Bold；dark=true 金底按钮用深色字，false 用金色字
	apply_title_font_sized(control, FONT_BODY)
	control.add_theme_color_override("font_color", COLOR_BTN_PRESSED if dark else COLOR_TEXT_GOLD)

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
	var r: int = int(round(float(radius) * UI_SCALE))
	var bw: int = int(round(float(border_w) * UI_SCALE))
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_corner_radius_all(r)
	sb.set_border_width_all(bw)
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
	apply_title_font_sized(btn, FONT_BODY)
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
# 支持两种格式：1) 完整路径（以 "res://" 开头）直接加载；2) stem 文件名（从 ICON_DIR 加载）。
# 图标已迁移为 .png；load() 内部按路径缓存结果，重复调用成本极低。
func load_icon(label: String) -> Texture2D:
	var stem: String = ICON_BY_LABEL.get(label, "")
	if stem == "":
		return null
	# 支持完整路径直接加载
	if stem.begins_with("res://"):
		if ResourceLoader.exists(stem):
			return load(stem) as Texture2D
		return null
	return load(ICON_DIR + stem + ".png") as Texture2D

# 01 屏画布 1:1 高清图标加载：stem 为图标文件名（不含扩展名）。
# 自动根据文件名前缀判断目录：
# - beast_* -> characters/beasts/
# - skill_* -> icons/skill/
# - array_* -> icons/array/
# - daotu_*/linggen_*/xingge_*/mingge_*/quality_*/realm_*/equip_* -> icons/disciple/
# - hall_* -> icons/building/
# - entry_* -> icons/entry/
# - res_* -> icons/resource/
# - 其他 -> icons/hd/
# 例：load_hd_icon("entry_shanmen_36") / load_hd_icon("res_lingshi_36") / load_hd_icon("tab_zongmen_36")。
# 图标已按目标像素整数落盘，使用时务必以原生尺寸摆放（TextureRect 用 STRETCH_KEEP_ASPECT_CENTERED），
# 二次缩放会破坏 USM 锐化边缘、导致画布上的清晰度在实机丢失。
func load_hd_icon(stem: String) -> Texture2D:
	if stem == "":
		return null
	# 根据文件名前缀判断目录
	var dir: String = ICON_HD_DIR
	if stem.begins_with("beast_"):
		dir = "res://art/characters/beasts/"
	elif stem.begins_with("skill_"):
		dir = "res://art/icons/skill/"
	elif stem.begins_with("array_"):
		dir = "res://art/icons/array/"
	elif stem.begins_with("daotu_") or stem.begins_with("linggen_") or stem.begins_with("xingge_") or stem.begins_with("mingge_") or stem.begins_with("quality_") or stem.begins_with("realm_") or stem.begins_with("equip_"):
		dir = "res://art/icons/disciple/"
	elif stem.begins_with("hall_"):
		dir = "res://art/icons/building/"
	elif stem.begins_with("entry_"):
		dir = "res://art/icons/entry/"
	elif stem.begins_with("res_"):
		dir = "res://art/icons/resource/"
	var path: String = dir + stem + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

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

# ========== 统一红点系统（大厂手游标准）==========
# 红点颜色：标准红色 + 白色描边
const RED_DOT_COLOR: Color = Color(0.9, 0.2, 0.2, 1.0)
const RED_DOT_BORDER: Color = Color(1.0, 1.0, 1.0, 1.0)

## 创建统一红点（圆点模式）
## size: 红点直径（像素）
func make_red_dot(size: float = 16.0) -> Panel:
	var dot := Panel.new()
	dot.name = "RedDot"
	dot.custom_minimum_size = Vector2(size, size)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = RED_DOT_COLOR
	sb.set_corner_radius_all(int(size / 2))
	sb.set_border_width_all(2)
	sb.border_color = RED_DOT_BORDER
	dot.add_theme_stylebox_override("panel", sb)
	return dot

## 创建统一数字红点
## count: 显示的数字，超过99显示"99+"
func make_red_dot_number(count: int, size: float = 20.0) -> Panel:
	var dot := Panel.new()
	dot.name = "RedDotNum"
	var width: float = size + 8.0 * len(str(count))
	if count > 99:
		width = size + 8.0 * 3  # "99+"
	dot.custom_minimum_size = Vector2(width, size)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = RED_DOT_COLOR
	sb.set_corner_radius_all(int(size / 2))
	sb.set_border_width_all(2)
	sb.border_color = RED_DOT_BORDER
	dot.add_theme_stylebox_override("panel", sb)

	var num_lbl := Label.new()
	num_lbl.name = "Num"
	num_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num_lbl.add_theme_font_size_override("font_size", int(size * 0.6))
	num_lbl.add_theme_color_override("font_color", Color.WHITE)
	if count > 99:
		num_lbl.text = "99+"
	else:
		num_lbl.text = str(count)
	dot.add_child(num_lbl)
	return dot

## 红点出现动画（缩放从0到1）
func animate_red_dot_appear(dot: Control) -> void:
	if dot == null or not is_instance_valid(dot):
		return
	dot.scale = Vector2(0, 0)
	dot.visible = true
	var tween := create_tween()
	tween.tween_property(dot, "scale", Vector2(1, 1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 红点消失动画（缩放从1到0）
func animate_red_dot_disappear(dot: Control, on_finish: Callable = Callable()) -> void:
	if dot == null or not is_instance_valid(dot):
		return
	var tween := create_tween()
	tween.tween_property(dot, "scale", Vector2(0, 0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		dot.visible = false
		dot.scale = Vector2(1, 1)
		if on_finish.is_valid():
			on_finish.call()
	)

## 红点呼吸效果（透明度循环变化）
func start_red_dot_breathe(dot: Control) -> void:
	if dot == null or not is_instance_valid(dot):
		return
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(dot, "modulate:a", 0.7, 0.8)
	tween.tween_property(dot, "modulate:a", 1.0, 0.8)

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
func load_title_font() -> Font:
	_ensure_fonts()
	return _font_title_res

func load_body_font() -> Font:
	_ensure_fonts()
	return _font_body_res

# ───────── 二级页统一返回按钮（左上角纯金色箭头，40×40 设计基准）─────────
func make_back_button(callback: Callable) -> Button:
	var btn := Button.new()
	btn.name = "BackBtn"
	btn.flat = true
	btn.text = ""
	btn.custom_minimum_size = Vector2(int(round(BACK_BTN_SIZE * UI_SCALE)), int(round(BACK_BTN_SIZE * UI_SCALE)))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.pressed.connect(callback)
	var icon := TextureRect.new()
	icon.name = "BackIcon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.texture = make_back_arrow_texture()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	return btn

func make_back_arrow_texture(scale: float = 2.0) -> Texture2D:
	# 圆环 + 内嵌箭头（与 Ardot 画布 01 屏页头返回键同款）
	# 圆 r=16 / 描边 1.2，箭头缩小到 25→13-27 让圆环有留白避免箭头触边
	var svg := "<svg width=\"40\" height=\"40\" viewBox=\"0 0 40 40\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\"><circle cx=\"20\" cy=\"20\" r=\"16\" stroke=\"#D6B16A\" stroke-width=\"1.2\" fill=\"none\"/><path d=\"M25 13 L15 20 L25 27\" stroke=\"#D6B16A\" stroke-width=\"2.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"
	var img := Image.new()
	img.load_svg_from_string(svg, scale)
	return ImageTexture.create_from_image(img)

# ───────── 二级页工业化背景（决策 4 升级：纯色全屏内容底，零建筑露出）─────────
# 用户实机反馈：顶部氛围场景图仍会露出宗门首页建筑，与库藏/坊市的纯色紧凑风格不统一。
# 结论：取消顶部氛围区（SECONDARY_TOP_BG_H = 0），全屏纯色底承载内容，各二级页统一从页顶开始排布。
# 调用方须在 _build 最先持有： var content: Control = UITheme.make_scene_background(self)
#   - 容器型页：把主内容容器 add 到 content（而非根）
#   - 绝对定位页：内容仍 add 到根（零改动），元素自带不透明底
const BG_SCENE_TEX: String = ASSET_DIR + "backgrounds/home_bg_sect_a.png"
const SECONDARY_TOP_BG_H: float = 0.0        # 顶部氛围区高：0 表示彻底关闭氛围图，统一纯色紧凑布局
const SECONDARY_CONTENT_BG: Color = Color(0.039, 0.071, 0.086)   # 内容区纯色底（深青，不透明）
const SECONDARY_TOP_LINE: Color = Color(0.910, 0.773, 0.447, 0.45)  # 氛围区底部分隔金线（氛围区关闭时不用）

func make_scene_background(parent: Control) -> Control:
	# 背景层（置于最底）
	var bg := Control.new()
	bg.name = "SceneBG"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	# 全屏不透明纯色内容底（覆盖整屏，保证内容区任何透明处均为纯色）
	var base := ColorRect.new()
	base.name = "ContentBase"
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.color = SECONDARY_CONTENT_BG
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(base)
	# 顶部场景氛围图（仅当 SECONDARY_TOP_BG_H > 0 时启用；当前已关闭）
	if SECONDARY_TOP_BG_H > 0.0:
		var tex: Texture2D = load(BG_SCENE_TEX) as Texture2D
		if tex != null:
			var tr := TextureRect.new()
			tr.name = "TopScene"
			tr.anchor_left = 0.0; tr.anchor_top = 0.0; tr.anchor_right = 1.0; tr.anchor_bottom = 0.0
			tr.offset_left = 0.0; tr.offset_top = 0.0; tr.offset_right = 0.0; tr.offset_bottom = SECONDARY_TOP_BG_H
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg.add_child(tr)
			# 顶部轻微暗化（HUD 之下过渡）
			var dim := ColorRect.new()
			dim.name = "TopDim"
			dim.anchor_left = 0.0; dim.anchor_top = 0.0; dim.anchor_right = 1.0; dim.anchor_bottom = 0.0
			dim.offset_left = 0.0; dim.offset_top = 0.0; dim.offset_right = 0.0; dim.offset_bottom = 48.0
			dim.color = Color(0.0, 0.0, 0.0, 0.28)
			dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg.add_child(dim)
			# 氛围区底部分隔金线
			var line := ColorRect.new()
			line.name = "TopLine"
			line.anchor_left = 0.0; line.anchor_top = 0.0; line.anchor_right = 1.0; line.anchor_bottom = 0.0
			line.offset_left = 0.0; line.offset_top = SECONDARY_TOP_BG_H - 2.0; line.offset_right = 0.0; line.offset_bottom = SECONDARY_TOP_BG_H
			line.color = SECONDARY_TOP_LINE
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg.add_child(line)
	# 内容承载容器（从 SECONDARY_TOP_BG_H 开始；当前为 0，即全屏）
	var content := Control.new()
	content.name = "PageContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.anchor_top = 0.0
	content.offset_top = SECONDARY_TOP_BG_H
	content.anchor_bottom = 1.0
	content.offset_bottom = 0.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(content)
	return content

# 二级页统一页头：带框体背景（墨绿底+暗金描边+圆角）的返回栏，标题居中。
# 调用方把返回的 PanelContainer 加到内容根即可；标题传空则只显示返回按钮。
func make_page_header(parent: Control, title: String, on_back: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "PageHeader"
	panel.add_theme_stylebox_override("panel", make_panel_stylebox(false))
	parent.add_child(panel)

	var hb := HBoxContainer.new()
	hb.name = "HeaderHBox"
	hb.add_theme_constant_override("separation", GRID)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(hb)

	var back: Button = make_back_button(on_back)
	hb.add_child(back)

	if not title.is_empty():
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(spacer)

		var lbl := Label.new()
		lbl.name = "HeaderTitle"
		lbl.text = title
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		apply_page_title(lbl)
		hb.add_child(lbl)

		var spacer2 := Control.new()
		spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(spacer2)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(spacer)

	return panel

# ───────── 二级页共享视觉常量归档（决策补充：保证后续所有二级页直接复用）─────────
# Tab 选中/未选中、空态文字、任务已领/可领态、主/次按钮、背景蒙层均已收口到本模块，组件禁止散写。
# 现行可直接复用的入口：
#   apply_tab_style(btn, sel)              二级页内子 Tab 选中态
#   make_back_button(cb)                   二级页统一返回按钮
#   make_scene_background()                二级页统一背景（决策 4）
#   空态占位：统一用 C01_TEXT_TERTIARY 弱文字（见各页 _add_empty 模式）
#   任务卡按钮双态：_style_gold_button(可领) / _apply_dark_capsule(已领)（见 page_quest）
#   任务类型色（卡片左色条）：主线=金 / 日常=青 / 宗门=紫 / 成就=金
const CARD_TYPE_COLOR_MAIN: Color = COLOR_TEXT_GOLD                  # 主线 金
const CARD_TYPE_COLOR_DAILY: Color = Color(0.310, 0.765, 0.690)     # 日常 青（= C05_PROG_FILL_CYAN）
const CARD_TYPE_COLOR_SECT: Color = Color(0.710, 0.482, 0.910)      # 宗门 紫（= C05_ICON_PURPLE）
const CARD_TYPE_COLOR_ACHV: Color = COLOR_TEXT_GOLD                 # 成就 金

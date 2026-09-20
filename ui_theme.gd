# ui_theme.gd — 《太玄宗门录》S1 UI 主题模块（Autoload: UITheme）
# 铁律：业务 UI 一律调用本模块，组件内禁止硬编码颜色/尺寸。
# 依据：design/06-角色与UI/UI交互规范_古风经营A版_V1.0.md §2~§4、§7
extends Node

# ───────── 色彩 token ─────────
const COLOR_BG_BASE: Color = Color(0.075, 0.180, 0.153)       # 暗青黛 底色
const COLOR_PANEL_BG: Color = Color(0.141, 0.204, 0.224)      # #243439 深青灰面板底（降饱和，不要墨绿）
const COLOR_STATUSBAR_BG: Color = Color(0.039, 0.106, 0.090)  # 状态栏/墨底
const COLOR_TOPBAR_BG: Color = Color(0.075, 0.180, 0.153, 0.88)  # 顶部栏 半透明深青底（P2 §二）
const COLOR_BORDER_GOLD: Color = Color8(200, 168, 106)   # #C8A86A 暗金描边（1~2px）
const COLOR_TEXT_GOLD: Color = Color(1.000, 0.878, 0.588)     # 亮金 核心数值（正常）
const COLOR_TEXT_RED: Color = Color(0.878, 0.471, 0.471)      # color.status.danger #E07878 警示/异常（负值/预警）
const COLOR_TEXT_BODY: Color = Color(0.878, 0.910, 0.882)     # 浅米 正文（旧值，新正文走 COLOR_TEXT_BODY_GOLD）
const COLOR_TEXT_AUX: Color = Color(0.549, 0.651, 0.612)      # 浅灰 辅助（旧值，新辅助走 COLOR_TEXT_BODY_GOLD）
const COLOR_TEXT_BODY_GOLD: Color = Color8(212, 184, 106) # #D4B86A 暗金：正文/数值/辅助统一色
const COLOR_TAB_UNSELECTED: Color = Color(0.749, 0.690, 0.498)  # #C9A865 底部 Tab 未选中暗金
const COLOR_BTN_PRESSED: Color = Color(0.043, 0.149, 0.122)   # 主按钮按下态 底色加深
const COLOR_BTN_DISABLED: Color = Color(0.235, 0.298, 0.278)
const COLOR_BTN_PRIMARY: Color = Color(0.173, 0.373, 0.322)   # #2C5F52 主按钮墨绿（头像选择「确认使用」钮）

# ── S1 重架构：按《UI设计令牌v1.0》补齐的色常量（视觉基线；业务色最终收口 UIThemeConfig）──
# 背景分层（内嵌内容面）
const COLOR_BG_CONTENT: Color = Color(0.114, 0.259, 0.220)    # color.bg.content* #2C3D43 面板内嵌内容面
# 文字分层
const COLOR_TEXT_TITLE1: Color = Color8(230, 199, 120)   # color.text.title1 #E6C778 一级标题
const COLOR_TEXT_TITLE2: Color = Color8(240, 230, 210)   # color.text.title2 #F0E6D2 二级标题
const COLOR_TEXT_BODY_DIM: Color = Color8(200, 184, 150) # color.text.body-dim* #C8B896 弱化正文
const COLOR_TEXT_DISABLED: Color = Color8(85, 85, 79) # color.text.disabled #55554F 禁用灰
# 功能色
const COLOR_STATUS_SUCCESS: Color = Color(0.494, 0.827, 0.604)# color.status.success #7ED39A 成功/增益（与 STATE_COLOR['success'] 同源，禁改值）
# ── M2/M3 首页单源化收口：原 home_page.tscn 散落的栏底/分割线色（命名收口，非全局 token）──
const COLOR_HOME_BAR_BG: Color = Color8(30, 43, 40)   # #1E2B28 首页栏/面板底（BarBG / PanelStyle 底）
const COLOR_HOME_DIVIDER: Color = Color8(200, 168, 106)  # #C8A86A 首页分割线/描边（Divider / TopLine / PanelStyle 边）
# 品阶/境界色唯一来源 → UIThemeConfig.QUALITY_COLOR / REALM_COLOR（数据驱动换皮）

# ───────── 01 屏（主界面·宗门主城）画布 1:1 色 token ─────────
# 唯一数据源 = Ardot 画布 2:55，色值逐位取自画布节点 fills/strokes，组件禁止再散写字面量。
# 命名前缀 C01_ 表示「01 屏专属」，与全局 token 区分，避免污染既有换皮体系。
const C01_TOPBAR_BG: Color = Color(0.055, 0.149, 0.125)          # 2:181 顶部资源栏底
const C01_AVATAR_BG: Color = Color(0.110, 0.259, 0.220)          # 2:183 头像底
const C01_GOLD_LINE: Color = Color(0.639, 0.541, 0.318)          # 通用暗金描边（头像/浮层/历法条）
const C01_TEXT_PRIMARY: Color = Color8(242, 245, 243)       # #F2F5F3 一级文字（宗主名/活跃度）
const C01_TEXT_GOLD: Color = Color8(214, 177, 106)          # #D6B16A 金色数值/选中标签（定稿稿统一金色）
const C01_TEXT_SECONDARY: Color = Color8(207, 198, 178)     # #CFC6B2 二级文字（资源名/入口标签）
const C01_TEXT_TERTIARY: Color = Color8(159, 179, 176)      # #9FB3B0 三级文字（结算提示/未选中Tab）
const C01_FLOAT_BG: Color = Color(0.075, 0.180, 0.153)           # 2:222 日常进度浮层底
const C01_CALENDAR_BG: Color = Color(0.055, 0.149, 0.125, 0.90)  # 50:1 历法条底
const C01_ENTRY_BG: Color = Color(0.078, 0.204, 0.169, 0.62)     # 2:207 等 快捷入口底（提高 α 让图标/文字在山水背景上更清晰）
const C01_PROG_TRACK: Color = Color(0.055, 0.137, 0.114, 0.45)   # 2:224 活跃度轨道
const C01_PROG_FILL: Color = Color(0.882, 0.765, 0.478)          # 2:225 活跃度填充 / Tab 选中指示器
const C01_TAB_CAPSULE: Color = Color(0.075, 0.180, 0.153, 0.18)  # 2:227 Tab 胶囊容器底
const C01_TAB_ACTIVE: Color = Color(0.129, 0.400, 0.325, 0.34)   # 2:228 Tab 选中底
const C01_TAB_IDLE: Color = Color(0.075, 0.180, 0.153, 0.10)     # 2:231 等 Tab 未选中底
const C01_TAB_BAR_BG: Color = Color(0.055, 0.145, 0.122, 0.94)   # 2:226 底部 Tab 栏背景 #071214@0.94
const C01_TAB_ICON_BG_SEL: Color = Color(0.106, 0.298, 0.247, 0.85) # 2:117 选中图标底 #0E2A30@0.8
const C01_TAB_ICON_BG_IDLE: Color = Color(0.063, 0.176, 0.145, 0.65) # 2:119 未选中图标底 #0C1E22@0.6
const C01_CLOUD: Color = Color(0.780, 0.878, 0.839, 0.18)        # 2:203 云海（画布 fills 实测 α0.14）
const C01_SCENE_BASE: Color = Color(0.039, 0.106, 0.090)         # 2:55 底色 / 35:2 渐变终点

# ───────── H项：复兴进度→色彩饱和/明度派生（太玄复兴三衡同源）─────────
# 设计理念：主色相（青黛+暗金）保持不变，只调饱和/明度
#   开局灰暗破败（低饱和+低明度）→ 中期金饰渐显 → 后期辉煌（高饱和+高明度）
# 复兴进度 0.0=破败（1品宗门）→ 1.0=辉煌（7品宗门）
# 零新增色值、零返工，纯工程可做
var 复兴进度: float = 0.0  # 运行时由Game.门派等级驱动，UI初始化时设置

## 设置复兴进度（由门派等级1-7映射到0.0-1.0）
func 设置复兴进度(门派等级: int) -> void:
	复兴进度 = clamp(float(门派等级 - 1) / 6.0, 0.0, 1.0)
	_色缓存.clear()  # P0-2：复兴度一变，语义色/组件色缓存全部失效（见文件末「Token 三层」）

## 根据复兴进度调整颜色（饱和度+0~20%，明度+0~15%）
## 主色相加亮，背景色微调（避免过亮刺眼）
func 复兴调整色(原色: Color, 是背景: bool = false) -> Color:
	var h: float = 原色.h
	var s: float = 原色.s
	var v: float = 原色.v
	var a: float = 原色.a
	# 饱和度提升：背景+0~10%，前景+0~20%
	var s提升: float = 复兴进度 * (0.10 if 是背景 else 0.20)
	s = clamp(s + s提升, 0.0, 1.0)
	# 明度提升：背景+0~8%，前景+0~15%
	var v提升: float = 复兴进度 * (0.08 if 是背景 else 0.15)
	v = clamp(v + v提升, 0.0, 1.0)
	return Color.from_hsv(h, s, v, a)

## 便捷函数：获取复兴调整后的关键颜色
func 获取背景色() -> Color:
	return 复兴调整色(COLOR_BG_BASE, true)
func 获取面板色() -> Color:
	return 复兴调整色(COLOR_PANEL_BG, true)
func 获取金色描边() -> Color:
	return 复兴调整色(COLOR_BORDER_GOLD, false)
func 获取金色文字() -> Color:
	return 复兴调整色(COLOR_TEXT_GOLD, false)
func 获取暗金正文() -> Color:
	return 复兴调整色(COLOR_TEXT_BODY_GOLD, false)

## 获取复兴阶段描述（用于UI展示）
func 获取复兴阶段名() -> String:
	if 复兴进度 < 0.2:
		return "破败初立"
	elif 复兴进度 < 0.4:
		return "渐有起色"
	elif 复兴进度 < 0.6:
		return "薪火相传"
	elif 复兴进度 < 0.8:
		return "声名鹊起"
	else:
		return "辉煌鼎盛"
const C01_EYE_BG: Color = Color(0.055, 0.149, 0.125, 0.55)       # 35:5 隐藏UI开关底
const C01_EYE_BORDER: Color = Color(0.216, 0.400, 0.353, 0.80)   # 35:5 描边
const C01_EYE_ICON: Color = Color(0.878, 0.812, 0.616)           # 35:7 眼睛线条
# v5 稿新增/修正 token（compose_v5_framed.py 1080p 实测）
const C01_PANEL_A: Color = Color(0.055, 0.149, 0.125, 0.86)      # 2:181 顶部资源栏底（带 α）
const C01_PANEL_LIGHT: Color = Color(0.098, 0.212, 0.180, 0.74)  # 50:1 时间匾额底
const C01_PANEL_B: Color = Color(0.078, 0.204, 0.169, 0.55)        # 次级面板/进度条底（与 C01_ENTRY_BG 同调）
const C01_TEXT_JADE: Color = Color(0.435, 0.906, 0.769)          # Lv.等级 青绿字
const C01_LINE_GOLD: Color = Color(0.847, 0.722, 0.416, 0.50)   # 顶部栏 2px 描边（带 α）
# 山水背景文字兜底 1px 深青灰投影（记忆铁律：浮在山水上的文字加此阴影，肉眼几乎无特效感）
const C01_SHADOW: Color = Color(0.031, 0.098, 0.078, 0.60)

# ───────── 05 屏（任务·宗务）画布 1:1 色 token ─────────
# 唯一数据源 = Ardot 画布 2:59。底色/页头/卡片底/图标圆底/文字与 C01_* 完全同值（直接复用 C01_*），
# 此处仅补齐 05 屏独有且 C01 未覆盖的颜色（进度青填充 / 奖励蓝 / 图标紫 / 金渐变按钮 / 按钮深色字）。
const C05_PROG_TRACK: Color = Color(0.055, 0.114, 0.141)        # 2:437 进度轨道（实心；C01_PROG_TRACK 带 α 故单列）
const C05_PROG_FILL_CYAN: Color = Color(0.310, 0.765, 0.690)    # 2:456 任务卡进度填充 青
const C05_PROG_FILL: Color = C05_PROG_FILL_CYAN   # 别名：进度填充统一青色
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
const GRID_SM: int = 6     # 紧凑栅格：卡片内间距/行距（GRID 的一半）
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
# ★ 2026-09-15 修：原 156 按顶栏**可见面板**高（70×2.25≈157.5）派生，而顶栏**根容器**
#   实高 = CONTAINER_H(84)×2.25 = 189。多出的 31.5px 透明死带曾让 20/52 个二级页的
#   「← 返回宗门」被压住上半截、且整条吃不到点击（引擎拾取实测 hovered=TopBar）。
#   首页根节点按 -TOPBAR_H/UI_SCALE 反向偏移 ⇒ 改此值首页版面零变化。
const TOPBAR_H: int = 189   # 顶部栏高度（= top_bar.gd CONTAINER_H 84 × 2.25）
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
	"宗门正殿": "res://art/icons/building/hall_zhishi_36.png",   # ★2026-09-15：原误用 hall_tanwei（探微阁图）；正殿用殿阁通用图
	"执事殿": "res://art/icons/building/hall_zhishi_36.png",
	"灵田": "res://art/icons/building/hall_lingtian_36.png",
	"矿脉": "res://art/icons/building/hall_kuangmai_36.png",
	"探微阁": "res://art/icons/building/hall_tanwei_36.png",     # ★2026-09-15：原误用 hall_qidian（器殿图），与器殿串位
	"丹殿": "res://art/icons/building/hall_dantang_36.png",
	"器殿": "res://art/icons/building/hall_qidian_36.png",      # ★2026-09-15：原误用 hall_xichi（洗池图）
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
const RADIUS_PANEL: int = 12
const RADIUS_BUTTON: int = 6
const BORDER_W: int = 1

# ───────── 收杆结算弹窗（page_fishing · 灵钓）─────────
# 语义尺寸 token：弹窗尺寸集中于此，勿在调用方散落裸数字。
const RESULT_PANEL_W: int = 620   # 弹窗内容宽
const RESULT_ART_H: int = 430     # 立绘区高
const RESULT_INPUT_H: int = 44    # 赐名输入框高
const RESULT_BTN_W: int = 180     # 弹窗按钮宽
const RESULT_BTN_H: int = 52      # 弹窗按钮高

# ───────── 大地图（page_world_map_visual）─────────
# 语义尺寸 token：四边云雾渐隐带宽度，勿在调用方散落裸数字。
const 边界渐隐带宽: int = 150     # 边界柔化：云雾淡出带宽度

# ───────── 色彩 getter ─────────
func color_border_gold() -> Color: return COLOR_BORDER_GOLD
func color_text_gold() -> Color: return COLOR_TEXT_GOLD
func color_text_body() -> Color: return COLOR_TEXT_BODY
func color_text_aux() -> Color: return COLOR_TEXT_AUX
# 核心数值：正常暗金 / 异常暗红
func color_value(abnormal: bool) -> Color: return COLOR_TEXT_RED if abnormal else COLOR_TEXT_BODY_GOLD

# ── 令牌色 getter（对齐 UI设计令牌v1.0，供组件按需取色）──
func color_text_title1() -> Color: return COLOR_TEXT_TITLE1
func color_text_title2() -> Color: return COLOR_TEXT_TITLE2
func color_text_body_dim() -> Color: return COLOR_TEXT_BODY_DIM
func color_status_success() -> Color: return COLOR_STATUS_SUCCESS
func color_status_danger() -> Color: return COLOR_TEXT_RED
func color_accent() -> Color: return COLOR_TEXT_GOLD

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

# 可控字号辅助文字：与 apply_title_font_sized / apply_body_font_sized 对称（补齐 FONT_AUX 家族缺口）。
func apply_aux_font_sized(control: Control, size: int) -> void:
	_ensure_fonts()
	control.add_theme_font_size_override("font_size", size)
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

# 语义别名：页面按「标题文本 / 按钮皮肤」通用语义调用（补齐主题 API 缺口）。
func apply_title_text(control: Control) -> void:
	apply_section_title(control)

# 通用：补回项目字体（思源黑体）+ 指定字号，颜色保持调用方原设置。
# 用于收口那些只写了 add_theme_font_size_override 而漏设 font 的地方
# （如战斗场景 Label / RichTextLabel），使其从 Godot 默认字体回到项目字体。
# bold=true 用 Bold 字体（标题/横幅/按钮），false 用 Regular（正文/数值）。
# 同时覆盖 Label 的 font/font_size 与 RichTextLabel 的 normal_font/normal_font_size。
func apply_project_font(control: Control, size: int, bold := false) -> void:
	_ensure_fonts()
	var f = _font_body_res
	if bold:
		f = _font_title_res
	if f == null:
		return
	if control is RichTextLabel:
		# 富文本：normal/bold 两套都设项目字体，保证 **加粗** 标记也走思源黑体
		control.add_theme_font_override("normal_font", f)
		control.add_theme_font_override("bold_font", f)
		control.add_theme_font_size_override("normal_font_size", size)
		control.add_theme_font_size_override("bold_font_size", size)
	else:
		control.add_theme_font_override("font", f)
		control.add_theme_font_size_override("font_size", size)

# 弹出菜单（PopupMenu/Popup，继承自 Window 而非 Control）字体收口。
# Window 与 Control 同样支持 add_theme_*_override，菜单的字体项名同为 "font"/"font_size"。
# 注意：popup 参数必须为 Window 系；若误传 Control 会被静态类型拒绝（反之亦然）。
func apply_popup_font(popup: Window, size: int, bold := false) -> void:
	_ensure_fonts()
	var f = _font_body_res
	if bold:
		f = _font_title_res
	if f == null:
		return
	popup.add_theme_font_override("font", f)
	popup.add_theme_font_size_override("font_size", size)

func apply_button_style(btn: BaseButton) -> void:
	apply_primary_button_style(btn)

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

# 自造弹窗（CanvasLayer 模态 Control）的面板统一蒙皮：
# 暗底 + 暗金描边 + 圆角，与改名/头像弹窗同款浮层样式。
# panel 为弹窗内承载内容的 Panel / PanelContainer 节点。
func style_popup_panel(panel: Control) -> void:
	panel.add_theme_stylebox_override("panel", make_panel_stylebox_flat(C01_FLOAT_BG, 获取金文字色(), 8, 2))

# 弹窗工具：tooltip 类浮层跟随锚点定位，并收口到真实安全区（顶栏/底部Tab 不遮挡、整屏不出界）。
# anchor_in_parent 为锚点（如点击位置）在其父容器局部坐标系的值；parent_size 为父容器尺寸
# （一般传 get_viewport_rect().size，因弹窗 shade 为 FULL_RECT 且页根为视口原点）。
# 默认置于锚点上方 16px；上方空间不足则置于下方；最后按安全区 clamp，绝不盖住顶部资源栏/底部主导航。
# 落地案例：disciple_detail_page._show_info_popup（替换原先魔法数 100/120 的硬编码安全区）。
func place_tooltip_near(panel: Control, anchor_in_parent: Vector2, parent_size: Vector2) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var pw: float = panel.size.x
	var ph: float = panel.size.y
	if pw < 10.0:
		pw = 640.0 * UI_SCALE
	if ph < 10.0:
		ph = 120.0 * UI_SCALE
	var 间距: float = 16.0 * UI_SCALE
	var 边距: float = float(GRID)
	var 安全顶: float = float(TOPBAR_H)
	var 安全底: float = float(TAB_H)
	var px: float = anchor_in_parent.x - pw * 0.5
	var py: float = anchor_in_parent.y - ph - 间距
	if py < 安全顶:
		py = anchor_in_parent.y + 间距
	px = clampf(px, 边距, parent_size.x - pw - 边距)
	py = clampf(py, 安全顶, maxf(安全顶, parent_size.y - ph - 安全底))
	panel.position = Vector2(px, py)

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

# ───────── 节点单位扁平蒙皮（radius/border_w **不乘** UI_SCALE）─────────
# 与 make_panel_stylebox_flat 的差别：几何按**节点单位**直用，且不加内阴影、不设内容边距。
# 存在理由：调用点已按节点单位算好几何（如 80×80 图标框、特惠卡），回移工厂只为消除
# 「裸 StyleBoxFlat.new()」的样式债，**逐像素等价**，不改变既有观感。
func make_stylebox_node_units(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	return sb

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
	_补按钮字体(btn)

# ★ 2026-09-16 补（#009 逐页精修 · 全项目字号脱节根因）：
#   两个按钮皮肤函数原本**只设 stylebox、完全不设字体**，于是所有「只调了 apply_*_button_style
#   或挂了 PrimaryButton/SecondaryButton 组件」的按钮，文字全部落到引擎默认 font_size 17
#   （≈11dp，肉眼几乎不可读），与正文 FONT_BODY=27 明显脱节 —— 这是全项目 259 处按钮调用点
#   的共同根因（灵讯「尽数阅之/尽数收取」、19 页页签、宗门战队签等实拍均偏小）。
#   在此统一收口，零调用点改动即全量修复。
#   ★ 守卫 `has_theme_font_size_override` 是必需的：页面常先自行指定字号（如顶栏帮助键 54、
#     首页舆图脚注 FONT_BODY）再调皮肤函数，此时必须**保留页面自己的设定**，不得覆盖。
#     两向都安全：页面若在皮肤函数之后才设字号，后写者胜，同样是页面的设定生效。
func _补按钮字体(btn: BaseButton) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	if btn.has_theme_font_size_override("font_size"):
		return
	apply_project_font(btn, FONT_BODY, true)

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
	_补按钮字体(btn)

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
# - emoji_* -> icons/emoji/   （2026-09-14 新增：旧 emoji 字符替换用的圆形金框图标）
# - res_* -> icons/resource/
# - 其他 -> icons/hd/
# 例：load_hd_icon("entry_tianxia_36") / load_hd_icon("res_lingshi_36") / load_hd_icon("tab_zongmen_36")。
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
	elif stem.begins_with("emoji_"):
		dir = "res://art/icons/emoji/"
	elif stem.begins_with("auction_"):
		dir = "res://art/icons/auction/"
	# ★ 2026-09-15（P0-C）：坊市灵石商品图标目录。
	#   约定：stem = <faction_shop.csv 的 item_id> + "_512"（当前 20 张，落 art/icons/shop/）。
	#   正常情况下坊市商品卡走 `商品["icon"]` 全路径 + load()（由 _坊市表() 补键），
	#   但**这里补上一条 stem 路由**，让「按 stem 找图」的调用方（以及后续新增入口）也能命中，
	#   路由表与 ICON_* 目录约定保持一一对应，不留暗角。
	elif stem.begins_with("shop_"):
		dir = "res://art/icons/shop/"
	elif stem.begins_with("res_") or stem.begins_with("pill_") or stem.begins_with("talisman_") or stem.begins_with("item_") or stem.begins_with("buff_") or stem.begins_with("herb_") or stem.begins_with("material_"):
		dir = "res://art/icons/resource/"
	var path: String = dir + stem + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

# ============ emoji 字符 → 圆形金框图标（2026-09-14 豆包出图后接入）============
# 资产目录 res://art/icons/emoji/（58 张，圆形金框+暗青黛底+金色线描，1024² RGBA）。
# 用法：UITheme.emoji_icon("◇") 或 UITheme.emoji_icon_sized("◇", 24)。
const EMOJI_TO_STEM: Dictionary = {
	"🏯": "emoji_world_city", "🏘️": "emoji_world_village", "🏘": "emoji_world_village",
	"💎": "emoji_world_gem", "🐺": "emoji_world_beast", "⛏️": "emoji_world_mine", "⛏": "emoji_world_mine",
	"🌿": "emoji_world_herb", "🎣": "emoji_world_fish", "📍": "emoji_world_location",
	"📅": "emoji_activity_calendar", "📆": "emoji_activity_calendar",
	"🔥": "emoji_activity_fire", "⚔️": "emoji_activity_battle", "⚔": "emoji_activity_battle",
	"🏆": "emoji_activity_trophy", "🗡️": "emoji_activity_sword", "🗡": "emoji_activity_sword",
	"🗺️": "emoji_activity_map", "🗺": "emoji_activity_map", "⭐": "emoji_activity_star",
	"📜": "emoji_offline_scroll", "⚠️": "emoji_offline_warning", "⚠": "emoji_offline_warning",
	"💳": "emoji_offline_money", "👑": "emoji_offline_crown",
	"🏛️": "emoji_offline_hall", "🏛": "emoji_offline_hall",
	"✍️": "emoji_offline_brush", "✍": "emoji_offline_brush",
	"🔒": "emoji_shop_lock", "🎁": "emoji_shop_gift", "❌": "emoji_faction_cross",
	"💬": "emoji_faction_chat", "😊": "emoji_faction_smile", "😞": "emoji_faction_angry",
	"⚡": "emoji_dynasty_lightning", "🧭": "emoji_dynasty_compass", "🎯": "emoji_dynasty_target",
	"📰": "emoji_dynasty_news", "👥": "emoji_dynasty_people",
	"🔗": "emoji_disciple_relation", "🩸": "emoji_disciple_bloodline", "💗": "emoji_disciple_favor",
	"👶": "emoji_disciple_child", "🤝": "emoji_disciple_friend", "🧠": "emoji_disciple_wisdom",
	"😐": "emoji_disciple_calm", "😠": "emoji_disciple_angry", "😨": "emoji_disciple_fear",
	"😢": "emoji_disciple_sad", "✨": "emoji_disciple_special", "👤": "emoji_disciple_person",
	"🔍": "emoji_general_search", "🌟": "emoji_general_rare", "🎊": "emoji_general_celebrate",
	"❓": "emoji_general_help", "🥇": "emoji_general_gold", "🥈": "emoji_general_silver",
	"🥉": "emoji_general_bronze", "💡": "emoji_general_inspiration", "🔮": "emoji_general_divination",
	"💰": "emoji_general_wealth", "📖": "emoji_general_book",
	"⚗️": "emoji_general_alchemy", "⚗": "emoji_general_alchemy", "🔨": "emoji_general_forge",
	"📋": "emoji_offline_scroll", "📝": "emoji_offline_brush",
}

# 取圆形金框图标（找不到返回 null，调用方自行回退到字符）。
# 入参二选一：① 资产 stem（"emoji_activity_fire"，推荐——代码内不留 emoji，
# 不受字体/编码/批量替换影响）② 旧式 emoji 字符（经 EMOJI_TO_STEM 转译，兼容 CSV 数据）。
func emoji_icon(ch: String) -> Texture2D:
	if ch == "":
		return null
	if ch.begins_with("emoji_"):
		return load_hd_icon(ch)
	if not EMOJI_TO_STEM.has(ch):
		return null
	return load_hd_icon(String(EMOJI_TO_STEM[ch]))

# 取 emoji 图标并光栅化到指定尺寸（正方形）。
# 用于 Button.icon 等无法可靠使用 icon_max_width 的场景（Godot 4.7 部分 build）。
func emoji_icon_sized(ch: String, size: int) -> Texture2D:
	var tex: Texture2D = emoji_icon(ch)
	if tex == null or size <= 0:
		return tex
	var img: Image = tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		if img.decompress() != OK:
			return tex
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

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
	# VRAM 压缩纹理（compress/mode=2）的 Image 为压缩格式，无法直接 resize；
	# 先解压为可操作格式再缩放（仅在压缩时解压，普通图走原路径，零资源改动）。
	if img.is_compressed():
		var err := img.decompress()
		if err != OK:
			return tex
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

# ========== 统一红点系统（大厂手游标准）==========
# 红点颜色：标准红色 + 白色描边
# ★ 2026-09-16 红点体系升级（对标大厂）：
#   原「亮白描边」有双向问题 —— 压在深色玻璃面板上像贴纸、飘在亮色山水背景上又糊成一团。
#   改为「深玄描边 + 柔和外发光」：深底靠暗描边收边不脏，亮背景靠发光把红点"抬"起来。
# ★ 2026-09-16 二次定标（对齐微信 / 原生桌面角标）：
#   一版走了「深玄描边 + 暗色外发光」的国风皮路线，实测**反向劣化** ——
#   暗色 shadow 在亮色山水背景上是圈脏灰污渍，在深色玻璃面板上则完全隐形（白付开销）；
#   深描边又把高饱和红压得发暗。而微信 Tab / iOS 桌面角标之所以「一眼看见」，
#   靠的是**纯色实心 + 高饱和 + 零修饰**：没有任何描边与发光，全靠色相本身跳出来。
#   ⇒ 主红提到 #FA4F4F 档、描边与发光全部归零。数字字形另用 RED_DOT_TEXT_EDGE
#     做极细深描边（只为小字号白字的边缘锐度，不构成视觉描边）。
const RED_DOT_COLOR: Color = Color(0.98, 0.31, 0.31, 1.0)
const RED_DOT_BORDER: Color = Color(0.98, 0.31, 0.31, 1.0)   # 同色 = 实际无描边
const RED_DOT_GLOW: Color = Color(0.0, 0.0, 0.0, 0.0)        # 全透明 = 实际无发光
const RED_DOT_TEXT_EDGE: Color = Color(0.58, 0.08, 0.10, 0.85)

## 创建统一红点（圆点模式）
## size: 红点直径（像素）
func make_red_dot(size: float = 16.0) -> Panel:
	var s: float = maxf(10.0, size)
	var dot := Panel.new()
	dot.name = "RedDot"
	dot.custom_minimum_size = Vector2(s, s)
	# 非容器父节点下 custom_minimum_size 不会自动生效（裸 Control 不参与布局），
	# 显式定 size 才能保证「宽=高」⇒ 圆角半径 s/2 恰好是正圆而不是圆角方块。
	dot.size = Vector2(s, s)
	# ★ 2026-09-15 修（根因）：Panel 默认 size_flags = SIZE_FILL ⇒ 放进 HBoxContainer 后
	#   会被「撑满剩余宽度」，圆角 8 / 2px 红描边的点被拉成一条满行宽的红色空心框
	#   （弟子详情页「◆ 互动培养」标题右侧那条红框的真因；page_quest/section_helper/
	#    sect_home_page/main 等 hb.add_child(dot) 处同病）。
	#   红点语义就是「一点」⇒ 一律 SHRINK_CENTER：容器内保持自身尺寸并居中。
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = RED_DOT_COLOR
	sb.border_color = RED_DOT_BORDER
	sb.shadow_color = RED_DOT_GLOW
	dot.add_theme_stylebox_override("panel", sb)
	# ★ 圆角/描边/发光必须**按最终像素尺寸自适应**，不能写死：
	#   本控件 size 的语义随使用方式不同 —— 首页走 _place()（内部 ×UI_SCALE，为设计逻辑），
	#   容器内则等于 custom_minimum_size（节点单位）。写死数值必在某一侧退化成圆角方块。
	#   实测：旧版 corner_radius=size/2 未随节点单位换算 ⇒ 圆角只有应有值的 1/2.25，
	#   12 逻辑的红点在屏上是「圆角方块」。
	var 同步 := func() -> void:
		var 边长: float = maxf(dot.size.x, dot.size.y)
		if 边长 <= 1.0:
			边长 = s * UI_SCALE
		sb.set_corner_radius_all(int(round(边长 * 0.5)))            # 正圆
		sb.set_border_width_all(0)   # 微信/原生规格：纯色实心角标，无描边
		sb.shadow_size = 0          # 且无外发光（暗色 shadow 在亮底上呈脏灰、深底上隐形）
		# 缩放动画必须绕中心：Control.scale 默认绕左上角，弹入会看成「从左上角铺开」。
		dot.pivot_offset = dot.size * 0.5
	同步.call()
	# 首页 _place() 在 add_child **之前**设 size，未入树时 resized 不触发（实测），
	# 必须补 tree_entered，否则红点停在初值尺寸上 —— 圆角按未放大的 s 算 ⇒ 退化为圆角方块。
	dot.resized.connect(同步)
	dot.tree_entered.connect(同步)
	挂红点动效(dot)
	return dot

## 创建统一数字红点
## count: 显示的数字，超过99显示"99+"
func make_red_dot_number(count: int, size: float = 20.0) -> Panel:
	var h: float = maxf(14.0, size)
	var 文本: String = "99+" if count > 99 else str(count)
	var dot := Panel.new()
	dot.name = "RedDotNum"
	# 胶囊宽度以「高」为基准：每位数字占 0.62h，两端各留 0.19h 内边距。
	# ★ 内边距取 0.19h 而非 0.26h 的理由：单位数时宽度须**恰好等于高**⇒ 正圆；
	#   旧式 0.52h 总内边距给出 1.14h ⇒ 单个数字角标渲染成椭圆（实测已复现）。
	var 位数: int = len(文本)
	var width: float = maxf(h, h * (0.62 * float(位数) + 0.38))
	dot.custom_minimum_size = Vector2(width, h)
	dot.size = Vector2(width, h)   # 同 make_red_dot：非容器父下 minimum 不生效
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # 同上：禁在容器里被撑满行宽
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = RED_DOT_COLOR
	sb.border_color = RED_DOT_BORDER
	sb.shadow_color = RED_DOT_GLOW
	dot.add_theme_stylebox_override("panel", sb)

	var num_lbl := Label.new()
	num_lbl.name = "Num"
	num_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num_lbl.add_theme_color_override("font_color", Color.WHITE)
	# 红底上的小字号白字若无描边会糊成一团 ⇒ 加与红点同色的深描边（大厂数字角标通行做法）
	num_lbl.add_theme_color_override("font_outline_color", RED_DOT_TEXT_EDGE)
	num_lbl.text = 文本
	dot.add_child(num_lbl)

	# 同 make_red_dot：几何全部随实际像素尺寸自适应（胶囊半径 = 高一半；字号/描边按高换算）
	var 同步 := func() -> void:
		var 高: float = dot.size.y
		if 高 <= 1.0:
			高 = h * UI_SCALE
		sb.set_corner_radius_all(int(round(高 * 0.5)))
		sb.set_border_width_all(0)   # 同 make_red_dot：纯色实心
		sb.shadow_size = 0           # 同 make_red_dot：无外发光
		dot.pivot_offset = dot.size * 0.5   # 同上：弹入绕中心
		# 字号占比 0.58 → 0.66：去掉描边后靠字号撑可读性（微信数字角标白字占高约 2/3）
		num_lbl.add_theme_font_size_override("font_size", int(round(高 * 0.66)))
		num_lbl.add_theme_constant_override("outline_size", maxi(1, int(round(高 * 0.10))))
	同步.call()
	# 同 make_red_dot：_place() 在入树前设 size ⇒ 必须补 tree_entered 才拿到最终尺寸
	dot.resized.connect(同步)
	dot.tree_entered.connect(同步)
	挂红点动效(dot)
	return dot

## 就地更新数字红点的数量（重算胶囊宽度，几何交给内部的 resized/tree_entered 同步）。
## 用途：角标数量在运行期变化（如顶栏未读消息数）——复用同一控件，避免每次重建节点。
func 设置红点数量(dot: Control, count: int) -> void:
	if dot == null or not is_instance_valid(dot):
		return
	var lbl: Label = dot.get_node_or_null("Num") as Label
	if lbl == null:
		return
	var 新文: String = "99+" if count > 99 else str(count)
	var 变: bool = lbl.text != 新文
	lbl.text = 新文
	var h: float = dot.custom_minimum_size.y
	var 位数: int = len(lbl.text)
	var w: float = maxf(h, h * (0.62 * float(位数) + 0.38))   # 同上：单位数须为正圆
	dot.custom_minimum_size = Vector2(w, h)
	dot.size = Vector2(w * UI_SCALE, h * UI_SCALE)   # 与 _place() 同口径（节点单位）
	if 变 and dot.is_visible_in_tree():
		红点脉冲(dot)   # 数字动了就跳一下：这是「又有新的了」的唯一低成本表达

# ───────── 红点自驱动效（工厂挂载 · 全项目调用点零改造）─────────
# 为什么挂在工厂而不是调用点：全项目 100+ 处 make_red_dot()，逐个接线的维护成本会失控，
#   且新页面必然漏接 ⇒ 把动效做成控件的固有属性，新红点天生带手感。
# 成本取舍：不起「每帧重算」的逐点动画，只在**显隐翻转的那一刻**建 tween，
#   且 bind_node 到红点本身（节点销毁即回收）。同屏可见红点通常 <20 个，开销可忽略。
const META_红点动画: String = "_red_dot_tw"        # ★ ASCII：中文 meta 键在 Godot 4 静默失效
const META_红点实测可见: String = "_red_dot_svis"
const META_红点呼吸: String = "_red_dot_breath"
const 红点_弹入时长: float = 0.26
# 呼吸**默认关闭**（幅度 1.0 = 恒定）。
# 微信 Tab / iOS 桌面角标都是**静止**的：它们靠高饱和纯色跳出来，不靠运动。
# 一版给了 1.09 幅度呼吸，实测在底部 Tab 这种小尺寸下更像「信号闪烁」而非「提示」，
# 且与顶栏既有的 alpha 呼吸叠加后整屏都在动 —— 反而削弱「一眼看见」。
# 需要时把幅度调到 1.04~1.07 即可开启，无需改调用点。
const 红点_呼吸周期: float = 1.6
const 红点_呼吸幅度: float = 1.0
const 红点_呼吸上限: int = 40   # 极端页面上限，防「一屏 100 个红点齐脉动」拖慢手机

## 全局动效强度（1.0 全开 / 0.0 全关）。设置页可关；autoload 实例变量即全局可达
## （GDScript 无 static var，别写成 static）。页面级/列表级/红点级动效统一读它。
var 动效强度: float = 1.0

## ★ 2026-09-16（#18 动效层收口）：把「减少动效」做成**玩家可达的开关**。
## 此前 `动效强度` 只有定义、没有任何 UI 入口 ⇒ 注释里写的「设置页可关」是空头支票，
## 而手机端省电与晕动症友好都依赖它。以下两函数补齐「设置页写入 → 运行时生效 → 读档回灌」闭环。
## 偏好值存于 Game.设置项["减少动效"]（随存档持久化）。
func 应用动效偏好(减少动效: bool) -> void:
	动效强度 = 0.0 if 减少动效 else 1.0

## 读档 / 新游戏后回灌一次（Game 在 UITheme 之后注册，故不能在 _ready 里读）。
func 载入动效偏好() -> void:
	if not is_instance_valid(Game):
		return
	var s: Variant = Game.get("设置项")
	if s is Dictionary:
		应用动效偏好(bool((s as Dictionary).get("减少动效", false)))
var _红点_呼吸中: int = 0

## 给任意红点控件挂自驱动效。公开给 RedDotBadge（ui/red_dot_badge.gd）——
## 项目内红点有两套产物：make_red_dot*（工厂裸 Panel）与 RedDotBadge（独立控件）。
## 两套样式已统一取色，动画也必须共用同一实现，否则同屏两种红点一个会弹一个不动。
func 挂红点动效(点: Control) -> void:
	点.visibility_changed.connect(_红点_评估.bind(点))
	点.tree_entered.connect(_红点_评估.bind(点))

## 只有「本节点自身 visible 翻转」才起动画。
## ★ 判据必须是 `visible` 而**不是** `is_visible_in_tree()`：父级隐藏时 Godot 会把
##   visibility_changed 传播到整棵子树，但子节点自身 visible 仍是 true —— 若用
##   is_visible_in_tree，每次切页（隐藏旧页 → 显示新页）都会被判成「红点重新出现」，
##   整屏红点齐刷刷重播弹入（观感像页面在抖）。
##   用 visible 则父级显隐被自动忽略，只有真正把红点显/隐时才播。
func _红点_评估(点: Control) -> void:
	if not is_instance_valid(点):
		return
	var 现: bool = 点.visible
	var 旧: bool = false
	if 点.has_meta(META_红点实测可见):
		旧 = bool(点.get_meta(META_红点实测可见))
	if 现 == 旧:
		return
	点.set_meta(META_红点实测可见, 现)
	if 现:
		_红点_出场(点)
	else:
		_红点_收(点)

func _红点_出场(点: Control) -> void:
	_红点_收(点)
	if 动效强度 <= 0.0:
		return
	点.pivot_offset = 点.size * 0.5
	点.scale = Vector2(0.35, 0.35)
	var t: Tween = create_tween().bind_node(点)
	var p: PropertyTweener = t.tween_property(点, "scale", Vector2.ONE, 红点_弹入时长)
	p.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.finished.connect(_红点_起呼吸.bind(点), CONNECT_ONE_SHOT)
	点.set_meta(META_红点动画, t)

func _红点_起呼吸(点: Control) -> void:
	if not is_instance_valid(点) or not 点.is_visible_in_tree():
		return
	# 幅度 1.0（默认）= 不呼吸：直接不建循环 tween，避免「建了又不动」的白开销
	if 红点_呼吸幅度 <= 1.0:
		return
	if 动效强度 <= 0.0 or _红点_呼吸中 >= 红点_呼吸上限:
		return
	var t: Tween = create_tween().bind_node(点)
	t.set_loops()
	t.set_meta(META_红点呼吸, true)
	var a: PropertyTweener = t.tween_property(点, "scale", Vector2.ONE * 红点_呼吸幅度, 红点_呼吸周期)
	a.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var b: PropertyTweener = t.tween_property(点, "scale", Vector2.ONE, 红点_呼吸周期)
	b.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	点.set_meta(META_红点动画, t)
	_红点_呼吸中 += 1

## 收动画：杀 tween 并复位 scale。
## 必须显式复位 —— 半路被打断（隐藏/重建）会停在 1.09 的放大态，下次出场从放大态起跳。
## 呼吸 tween 是 set_loops 的、永不 finish，所以计数只能在这里减；漏了就会只增不减，
## 攒到上限后所有红点永久失去呼吸（静默劣化，没有任何报错）。
func _红点_收(点: Control) -> void:
	if not is_instance_valid(点):
		return
	if 点.has_meta(META_红点动画):
		var t: Variant = 点.get_meta(META_红点动画)
		if t is Tween and (t as Tween).is_valid():
			if (t as Tween).has_meta(META_红点呼吸):
				_红点_呼吸中 = maxi(0, _红点_呼吸中 - 1)
			(t as Tween).kill()
	点.set_meta(META_红点动画, null)
	点.scale = Vector2.ONE

## 数字变动脉冲：1.0 → 1.18 → 1.0。
## 与「出场」语义不同、不可混用：出场从 0.35 弹入＝「第一次出现」；
## 脉冲只跳一下＝「又有新的了」。把脉冲做成重播弹入会让玩家以为红点消失后重现。
func 红点脉冲(dot: Control) -> void:
	if dot == null or not is_instance_valid(dot):
		return
	if not dot.is_visible_in_tree() or 动效强度 <= 0.0:
		return
	_红点_收(dot)
	dot.pivot_offset = dot.size * 0.5
	var t: Tween = create_tween().bind_node(dot)
	var a: PropertyTweener = t.tween_property(dot, "scale", Vector2.ONE * 1.18, 0.12)
	a.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var b: PropertyTweener = t.tween_property(dot, "scale", Vector2.ONE, 0.14)
	b.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.finished.connect(_红点_起呼吸.bind(dot), CONNECT_ONE_SHOT)
	dot.set_meta(META_红点动画, t)

## 红点出现（保留旧签名给既有调用点）。
## 内部转发到统一出场：红点已由工厂挂自驱，调用点再手工起 tween 会与自驱**同时写 scale**，
## 两条 tween 各按自己的曲线补间同一属性 ⇒ 观感是抖动而非弹入。转发后只剩一条。
func animate_red_dot_appear(dot: Control) -> void:
	if dot == null or not is_instance_valid(dot):
		return
	dot.visible = true
	_红点_出场(dot)

## 红点消失（保留旧签名）。先收自驱动画再收缩隐藏，on_finish 在隐藏之后回调。
func animate_red_dot_disappear(dot: Control, on_finish: Callable = Callable()) -> void:
	if dot == null or not is_instance_valid(dot):
		return
	_红点_收(dot)
	if 动效强度 <= 0.0:
		dot.visible = false
		if on_finish.is_valid():
			on_finish.call()
		return
	dot.pivot_offset = dot.size * 0.5   # 同上：绕中心收缩
	var tween: Tween = create_tween().bind_node(dot)
	tween.tween_property(dot, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		dot.visible = false
		dot.scale = Vector2.ONE
		if on_finish.is_valid():
			on_finish.call()
	)

## 红点呼吸效果（透明度循环变化）。**返回 Tween 句柄**：
## 调用方在角标隐藏时必须 `kill()`（否则隐藏期间空转，且再次显示会叠加第二条循环 tween
## ⇒ 呼吸越来越快）；kill 之后要把 `modulate.a` 显式复位成 1.0，否则会停在暗态。
func start_red_dot_breathe(dot: Control) -> Tween:
	if dot == null or not is_instance_valid(dot):
		return null
	var tween: Tween = create_tween()
	tween.set_loops()
	var 暗: PropertyTweener = tween.tween_property(dot, "modulate:a", 0.82, 0.85)
	暗.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var 亮: PropertyTweener = tween.tween_property(dot, "modulate:a", 1.0, 0.85)
	亮.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

# ───────── 红点状态源（由 red_dot_init 自注册 · 全项目只读）─────────
# 为什么挂在 UITheme：它已是 autoload，任何页面/控件直达，无需新增单例或改 project.godot
#   的 autoload 列表；且红点属纯展示层，UI 本就不该直接持有数据单例。
# 类型标 Object + has_method/call：管理器是 preload 的内部类，写死类型会牵扯循环依赖。
var 红点源: Object = null

func 红点可见(id: String) -> bool:
	if 红点源 == null or not is_instance_valid(红点源):
		return false
	if not 红点源.has_method("是否显示"):
		return false
	return bool(红点源.call("是否显示", id))

func 红点数值(id: String) -> int:
	if 红点源 == null or not is_instance_valid(红点源):
		return 0
	if not 红点源.has_method("获取数量"):
		return 0
	return int(红点源.call("获取数量", id))

# ───────── 资源数值格式化（首页/顶栏万缀显示）─────────
# >=10000 显示为 X.X万（snapped 到 0.1），否则显示整数。纯函数，供 TopBar / 宗门动态面板复用。
static func format_resource(value: int) -> String:
	# ★ 铁律（2026-09-15 实战定）：GDScript 的 `%` 走 String::sprintf 子集，合法符仅
	#   s/c/d/i/o/x/X/f/e/v/% —— **没有 %g**。原实现 `"%g万" % …` ⇒ 首页「坊市」一进即卡死。
	#   故一律用 %d / %.1f，并保留「亿」档，避免 9 位数拉成长串。
	if value >= 100000000:
		return "%d亿" % int(roundf(value / 100000000.0))
	if value >= 10000:
		var wan: float = snapped(value / 10000.0, 0.1)
		# 进位护栏：99999999 / 10000 = 9999.9999 → snapped(0.1) = 10000.0，
		# 若只按「万」输出会得到 "10000万"，必须升档到「亿」。
		if wan >= 10000.0:
			return "%d亿" % int(roundf(wan / 10000.0))
		# 整万不显示 .0（12.0万 → 12万）；非整万保留一位（1.2万）
		if is_equal_approx(wan, roundf(wan)):
			return "%d万" % int(roundf(wan))
		return "%.1f万" % wan
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

## 把「已定位好的文字返回钮」就地换成全站统一的「圆环 + 内嵌金色箭头」外观。
## ★ 2026-09-16（老模板页头升级）：丹方/器谱/藏书阁/傀儡/药园 5 页是早期自绘 60 高顶栏，
##   返回键写死文字「折返」方钮，与其余 60 个二级页的圆环箭头不一致。
##   本函数**只换内容、不动布局**（保留原 position/size ⇒ 热区反而更大，更好点），
##   因此可以直接在旧硬布局页里原地调用，无需重排整页 offset。
##   需要真正新建按钮时用 make_back_button()。
const META_已装返回钮: String = "_ui_back_decorated"

func 装饰为返回钮(b: Button) -> void:
	if b == null or not is_instance_valid(b):
		return
	if b.has_meta(META_已装返回钮):
		return
	b.set_meta(META_已装返回钮, true)
	b.text = ""
	b.flat = true
	var 空: StyleBoxEmpty = StyleBoxEmpty.new()
	for 态 in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(态, 空)
	var icon: TextureRect = TextureRect.new()
	icon.name = "BackIcon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.texture = make_back_arrow_texture()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)

# ── 统一标签栏（TabBar）──────────────────────────────────────
# ★ 2026-09-16（#009 逐页精修）：全项目约 25 个二级页各自手搓标签栏 ——
#   每页重复「for 名 in TABS: Button.new() + custom_minimum_size = Vector2(100,32)」，
#   以及 `modulate = Color(1,1,1,1) if k==_cur else Color(0.6,…)`。
#   高亮口径虽然碰巧一致，但建钮参数（尺寸/裁字/字重）各页在漂移，且**改一处要改 25 处**。
#   收口到本组件：新增页面直接调用，存量页面逐步替换。
func 建标签栏(宿主: Control, 标签列表: Array, 回调: Callable, 当前: String = "", 最小宽: int = 100) -> Dictionary:
	var 表: Dictionary = {}
	for 名 in 标签列表:
		var b: Button = Button.new()
		b.text = str(名)
		# 最小宽 100（原 19 页在 80/90/100/110 之间漂移）+ EXPAND_FILL ⇒ 页签少时自动均分不空、
		# 多时按最小宽排布，宽度全局一致，且不因改宽而溢出。
		b.custom_minimum_size = Vector2(最小宽, 32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		# ★ 2026-09-16 补：原 19 页手搓版**都没给页签设字体**，落到引擎默认 font_size 17
		#   （≈11dp），页签文字肉眼几乎不可读，与正文 27 明显脱节。此处统一收口到 FONT_BODY。
		apply_project_font(b, FONT_BODY, true)
		b.pressed.connect(回调.bind(名))
		宿主.add_child(b)
		表[str(名)] = b
	刷新标签高亮(表, 当前)
	return 表

## 标签高亮：选中=全亮，未选=压暗（0.6）。1 / 0.6 / alpha=1 为全项目既定口径，勿再散落。
func 刷新标签高亮(表: Dictionary, 当前: String) -> void:
	for k in 表:
		var b: Control = 表[k]
		if is_instance_valid(b):
			b.modulate = Color(1, 1, 1, 1) if str(k) == str(当前) else Color(0.6, 0.6, 0.6, 1)

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
	# P0-3.5：委托 建顶栏，使直接调用本函数的 3 页（宗务/日供/占位）与全 51 二级页顶栏同源
	# （暗金描边底 + 金环返回键 + 亮金标题）。建顶栏不自动加父级，由本函数负责 add_child。
	var tb := 建顶栏(title, on_back)
	parent.add_child(tb)
	return tb

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

# ============================================================================
# ★ P0-2 · Design Token 三层（2026-09-13 立项）
# 依据: design/06-角色与UI/UI视觉重构方案_深色暗金国风_v1.0.md §2 / §7
# ============================================================================
#
# 【为什么需要三层 —— 现状病灶（合并扫描器 .workbuddy/auto_ui/audit_ui.py 实测）】
#   现有常量按「设计稿编号」命名：C01_* = 01 屏、C05_* = 05 屏 —— 是**来源**不是**语义**。
#   于是同一语义「一级文字」存在三份互不相同的色值：
#       C01_TEXT_PRIMARY   (0.949, 0.960, 0.953)
#       C05_TEXT_PRIMARY   (0.929, 0.906, 0.847)
#       COLOR_TEXT_TITLE1  (0.902, 0.780, 0.471)
#   ⇒ 开发者找不到「该用哪个」，最终直接硬编码写死。
#   这是全项目 1242 处硬编码 Color 的**根因**（不是纪律问题，是命名体系问题）。
#
# 【三层职责】
#   Primitive  物理色值 —— 本节的 MAT_*；历史 COLOR_*/C01_*/C05_* **全部保留为兼容层**
#   Semantic   语义角色 + 复兴度派生 —— **唯一推荐出口**，带缓存
#   Component  组件级 Token —— 由 Semantic 组合，UI 组件只许用这一层
#
# 【★ 迁移纪律】本轮**不做批量替换**。旧常量保留、新层同步可用即达成 P0-2 判据；
#   1242 处硬编码的收敛留到 **P0-4 换肤阶段**（届时有 ui_full_accept 真实渲染验收兜底，
#   现在批量改等于闭眼改 83 个文件）。
#
# 【★ 性能】复兴调整色() 每次调用都做 HSV→RGB 转换。若 UI 组件每次刷新都调，
#   1080×1920 竖屏一屏数十个控件 = 每帧数十次三角函数级运算，手机端是隐患。
#   故 Semantic/Component 全部走 _取语义色() 缓存；缓存仅在 设置复兴进度() 时清空。
#
# ----------------------------------------------------------------------------
# Primitive：P0-1 材质色板（与 art/ui/patch/*.png 源图逐像素一致，单一真源）
# ----------------------------------------------------------------------------
const MAT_BASE_TOP: Color = Color8(34, 51, 58)        # #22333A 面板渐变·起
const MAT_BASE_BOTTOM: Color = Color8(22, 32, 36)     # #162024 面板渐变·止
const MAT_SURFACE: Color = Color8(27, 39, 43)         # #1B272B 浮层面
const MAT_ROW_TOP: Color = Color8(39, 57, 66)         # #273942 列表行·起
const MAT_ROW_BOTTOM: Color = Color8(28, 38, 44)      # #1C262C 列表行·止
const MAT_CARD_TOP: Color = Color8(43, 64, 73)        # #2B4049 卡片·起
const MAT_CARD_BOTTOM: Color = Color8(31, 43, 49)     # #1F2B31 卡片·止
const MAT_EDGE_DARK: Color = Color8(110, 87, 38)      # #6E5726 暗金描边
const MAT_EDGE_LIGHT: Color = Color8(232, 206, 138)   # #E8CE8A 亮金描边
const MAT_GOLD_TOP: Color = Color8(200, 168, 106)      # #C8A86A 金渐变·起
const MAT_GOLD_BOTTOM: Color = Color8(140, 110, 46)   # #8C6E2E 金渐变·止
const MAT_GOLD_HI: Color = Color8(240, 220, 160)      # #F0DCA0 金高光 / 状态角标
#
# ★ 三层明度梯度铁律（方案 §3.2，2026-09-13 定）
#   panel #162024 < row #1C262C < card #1F2B31（比**下端**色）
#   浮在上层的容器，其最暗处也必须比下层最暗处亮 Δ≥4/255，否则层级不成立。
#   （原 card 下端 #182226 ≈ panel 下端 #162024，卡片贴面板时下缘被吃掉 —— 已修）
#
# ----------------------------------------------------------------------------
# Semantic / Component 的缓存（唯一失效点：设置复兴进度）
# ----------------------------------------------------------------------------
var _色缓存: Dictionary = {}

## 取语义色（带缓存）。键 = 语义路径，如 "card.bg" / "text.primary"
func _取语义色(键: String, 原色: Color, 是背景: bool) -> Color:
	if _色缓存.has(键):
		return _色缓存[键]
	var c: Color = 复兴调整色(原色, 是背景)
	_色缓存[键] = c
	return c

# ----------------------------------------------------------------------------
# Semantic 层：语义角色（新增 UI 代码一律用这一层，不要再直接引用 COLOR_*/C01_*）
# ----------------------------------------------------------------------------
func 获取页面底色() -> Color:
	return _取语义色("bg.page", MAT_BASE_TOP, true)
func 获取面板底色() -> Color:
	return _取语义色("bg.panel", MAT_BASE_BOTTOM, true)
func 获取浮层底色() -> Color:
	return _取语义色("bg.surface", MAT_SURFACE, true)
func 获取主文字色() -> Color:
	return _取语义色("text.primary", C01_TEXT_PRIMARY, false)
func 获取次文字色() -> Color:
	return _取语义色("text.secondary", C01_TEXT_SECONDARY, false)
func 获取弱文字色() -> Color:
	return _取语义色("text.tertiary", C01_TEXT_TERTIARY, false)
func 获取金文字色() -> Color:
	return _取语义色("text.gold", MAT_EDGE_LIGHT, false)
func 获取暗金边色() -> Color:
	return _取语义色("edge.dark", MAT_EDGE_DARK, false)
func 获取亮金边色() -> Color:
	return _取语义色("edge.light", MAT_EDGE_LIGHT, false)
## 吉/凶/警 —— 修真化命名，对应 success / danger / warning
func 获取吉色() -> Color:
	return _取语义色("state.success", COLOR_STATUS_SUCCESS, false)
func 获取凶色() -> Color:
	return _取语义色("state.danger", COLOR_TEXT_RED, false)
func 获取警色() -> Color:
	return _取语义色("state.warning", C05_TEXT_GOLD, false)

# ----------------------------------------------------------------------------
# Component 层：组件级 Token（UI 组件只许用这一层）
# 与 art/ui/patch 资产一一对应，改资产必须同步改这里
# ----------------------------------------------------------------------------
## 卡片（card_bg · 框中框）
func 获取卡底色起() -> Color:
	return _取语义色("card.bg.top", MAT_CARD_TOP, true)
func 获取卡底色止() -> Color:
	return _取语义色("card.bg.bottom", MAT_CARD_BOTTOM, true)
func 获取卡描边色() -> Color:
	return _取语义色("card.border", MAT_EDGE_DARK, false)
func 获取卡内框色() -> Color:
	return _取语义色("card.frame", MAT_EDGE_LIGHT, false)
## 列表行（card_row_bg · 左侧书脊竖条）
func 获取行底色起() -> Color:
	return _取语义色("row.bg.top", MAT_ROW_TOP, true)
func 获取行底色止() -> Color:
	return _取语义色("row.bg.bottom", MAT_ROW_BOTTOM, true)
func 获取行描边色() -> Color:
	return _取语义色("row.border", MAT_EDGE_DARK, false)
func 获取书脊色() -> Color:
	return _取语义色("row.spine", MAT_EDGE_LIGHT, false)
## 按钮（btn_fill / btn_frame · 金渐变 + 端扣）
func 获取钮金起色() -> Color:
	return _取语义色("btn.gold.top", MAT_GOLD_TOP, false)
func 获取钮金止色() -> Color:
	return _取语义色("btn.gold.bottom", MAT_GOLD_BOTTOM, false)
func 获取钮金高光色() -> Color:
	return _取语义色("btn.gold.hi", MAT_GOLD_HI, false)
## 状态角标（corner_tab · 非 9-patch）
func 获取角标色() -> Color:
	return _取语义色("tab.corner", MAT_GOLD_HI, false)

## ★ 深墨场景压暗色（背景晕影专用）。
## 铁律：不可用 获取面板底色() 当晕影基色 —— 它 ≈ 卡片顶色（#2B4049 / #2C3E45），
##   越压背景越"像卡片"，卡片永远从场景里跳不出来（P0-5.1 实测踩到）。
func 获取场景压暗色() -> Color:
	return Color8(8, 28, 22)

## 大地图边界渐隐色（可调 alpha）：四边云雾淡出的基色。
## 铁律：基色必须取「场景压暗色」深墨，禁用 获取面板底色()（否则边缘像卡片）。
## 消费方：page_world_map_visual 边界柔化。
func 获取边界渐隐色(a: float) -> Color:
	var c: Color = 获取场景压暗色()
	return Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0))

## 大地图画布底色（水墨夜深）。2026-09-14 实机验收补：
## 画布 4000² 远大于内容占位，外围原本无任何绘制 ⇒ 大面积纯黑，像"没渲染完"。
## 铺一层略亮于场景压暗色的墨底，未探索区变"沉色"而非"黑洞"。
func 获取地图底色() -> Color:
	return Color8(24, 52, 44)

## 大地图迷雾色（未探索云雾）。2026-09-14 实机验收补：
## 取偏蓝墨而非纯黑，叠在水墨底上呈"云深不知处"；alpha 由消费方决定。
func 获取迷雾色(a: float = 0.88) -> Color:
	return Color(0.078, 0.180, 0.153, clampf(a, 0.0, 1.0))

## 取任意基色的透明度变体。调用方需要「同色不同 alpha」（渐隐条 / 浮雕底）时走这里，
## 避免在业务脚本里散落 Color(...) 字面量而触发 UI 棘轮（只减不增）。
func 取同色异透(基色: Color, a: float) -> Color:
	return Color(基色.r, 基色.g, 基色.b, clampf(a, 0.0, 1.0))

## 首页背景压暗系数（供 TextureRect.modulate）。
## P0-5.3 场景归位：面板底九宫格 alpha=255（完全不透明），读字不靠压暗；
##   故这里只做「轻微压暗 + 降蓝暖偏」，让背景图与洞天换肤皮肤真正可见。
## 消费方：sect_home_page。
func 获取背景压暗系数() -> Color:
	return Color(1.0, 0.99, 0.96, 1.0)

## 首页背景纵向晕影：**只压上下边缘，中部全透明**。
## 依据：panel_bg / card_bg 九宫格填充区 alpha=255（完全不透明），读字不依赖背景压暗；
##   故中部须全幅让出，作「主视觉窗」承载背景图与「洞天换肤」6 套皮肤。
## 消费方：sect_home_page。切勿在页面内新造色值（棘轮口径：Color 字面量须留在本文件）。
func 建背景晕影渐变() -> Gradient:
	var 墨: Color = 获取场景压暗色()
	var grad := Gradient.new()
	# 顶部 0–11%：为顶栏 / 资源栏做底，向下渐隐到全透明
	grad.set_color(0, Color(墨, 0.80))
	grad.add_point(0.055, Color(墨, 0.40))
	grad.add_point(0.11, Color(墨, 0.00))
	# 中部 11%–88%：全透明 —— 主视觉窗（背景 / 皮肤 / 动画全幅可见）
	grad.add_point(0.50, Color(墨, 0.00))
	grad.add_point(0.88, Color(墨, 0.00))
	# 底部 88%–100%：为快捷条 / 底部 Tab 做底，向上渐隐
	grad.add_point(0.94, Color(墨, 0.45))
	grad.set_color(grad.get_point_count() - 1, Color(墨, 0.85))
	return grad

## ★ P0-7 去面板化：顶栏底 —— 不再用「悬浮框」，改用「顶部 scrim 渐隐条」。
## 依据（外网调研）：网易游戏学院《窗口界面设计规范》明列窗口界面禁忌
##   「避免场景很亮、底板很暗的尴尬」；顶栏只做「可读性托底」，
##   不做「一块描边圆角贴在场景上的深色板」（后者正是"面板墙"观感来源）。
## 返回 Gradient；调用方自行包成 GradientTexture2D（与 建背景晕影渐变 同口径）。
func 建顶栏渐隐() -> Gradient:
	var 墨: Color = 获取场景压暗色()
	var grad := Gradient.new()
	# 顶边最实（托住状态栏/资源数字），向下 62% 处衰减、底边全透明 → 与场景无缝相接
	grad.set_color(0, Color(墨, 0.92))
	grad.add_point(0.62, Color(墨, 0.60))
	grad.set_color(grad.get_point_count() - 1, Color(墨, 0.00))
	return grad

# ----------------------------------------------------------------------------
# 迁移映射表（★ P0-4 换肤阶段执行，本轮只登记不动手）
# ----------------------------------------------------------------------------
#   旧常量 / 硬编码                     -> 新 Token                      备注
#   COLOR_PANEL_BG                      -> 获取面板底色()                色值由 #2C3E45 换为新色板
#   COLOR_BG_BASE                       -> 获取页面底色()
#   COLOR_BORDER_GOLD                   -> 获取暗金边色()
#   COLOR_TEXT_GOLD                     -> 获取金文字色()
#   COLOR_STATUS_SUCCESS/TEXT_RED       -> 获取吉色() / 获取凶色()
#   C01_TEXT_PRIMARY/SECONDARY/TERTIARY -> 获取主/次/弱文字色()          三屏重复定义，统一收口
#   C05_TEXT_PRIMARY/SECONDARY/TERTIARY -> 同上
#   COLOR_TEXT_TITLE1/TITLE2            -> 获取主文字色() / 获取次文字色()
#   CARD_TYPE_COLOR_*                   -> 保持（业务语义色，非组件色）
#   ui/battle_scene.gd 的 20 处裸字号   -> 逐行人工判断（同页混有已乘 UI_SCALE 的 72/96）
# ----------------------------------------------------------------------------

# ============================================================================
# ★ P0-3 组件库（9-patch 消费层）
# ----------------------------------------------------------------------------
# 存在的唯一理由：P0-1 生成的 6 张 9-patch 此前**没有任何代码消费**（死资产），
# 本层是它们的唯一消费入口。
#
# 性能红线（方案 §2.5）：贴图与 StyleBox 一律**预创建 + 进程内单例缓存**，
#   · 禁止在 _process / _draw 内 new StyleBox
#   · 缓存的 StyleBox 视为只读，任何调用方不得就地修改（否则污染全部共享者）
#   · 需要变体（按钮按下态）走 duplicate()，不碰缓存本体
#
# 兜底红线：资产缺失时退化 StyleBoxFlat，绝不返回 null —— 与既有
#   make_panel_stylebox / make_divider_stylebox 的兜底范式保持一致。
#
# 边距口径：PATCH_MARGIN 是**源图像素**，与 .workbuddy/auto_ui/gen_ui_patch.py
#   的 SPECS 严格一致；改资产尺寸必须同步改这里（并由 verify_p0_1.py 复验）。
# ============================================================================

## 九宫格边距（源图像素）
const PATCH_MARGIN := {
	"panel_bg": 48,
	"card_bg": 36,
	"card_row_bg": 36,
	"btn_fill": 40,
	"btn_frame": 40,
}

const PATCH_DIR := "res://art/ui/patch/"

var _patch_tex: Dictionary = {}   # 名 -> Texture2D（进程内单例，避免重复 IO）
var _patch_sb: Dictionary = {}    # 名[+变体] -> StyleBoxTexture（★ 预创建缓存）


## 取九宫格贴图（带缓存；缺失返回 null 并告警）
func 取九宫格贴图(名: String) -> Texture2D:
	if _patch_tex.has(名):
		return _patch_tex[名]
	var path: String = PATCH_DIR + 名 + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		push_warning("[UITheme] 九宫格资产缺失，退化 Flat: " + path)
		return null
	_patch_tex[名] = tex
	return tex


## 取九宫格 StyleBox（带缓存；缺失返回 null）
func 取九宫格样式(名: String) -> StyleBoxTexture:
	if _patch_sb.has(名):
		return _patch_sb[名]
	var tex: Texture2D = 取九宫格贴图(名)
	if tex == null:
		return null
	var m: int = int(PATCH_MARGIN.get(名, 36))
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(m)
	sb.set_content_margin_all(m)
	_patch_sb[名] = sb
	return sb


## 按钮状态变体：按下态靠 content margin 下移实现（不引入未知属性）
## 下移=0 时直接返回共享缓存本体
## ★ 2026-09-16（#009 UI 收敛 · 拆掉「两套按钮皮肤」互斥的硬障碍）
## 问题定性：项目里有两条按钮皮肤路径 ——
##   ① `apply_primary/secondary_button_style`（纯 StyleBoxFlat，259 处调用，**事实主力**）
##   ② `应用主/次按钮皮`（9-patch 金框贴图，质感更高，此前**只有测试脚本调用，生产零启用**）
## 二者此前**几何口径不同**：平肤 `content_margin = GRID(12)`，
##   而贴图皮直接沿用 `PATCH_MARGIN`（btn_fill/btn_frame = 40，那是**源图切片宽**，
##   是 9-patch 正确拉伸的前提，**不能改小**）⇒ 贴图皮按钮比平肤**高出 56 逻辑像素**。
## 后果：259 处永远无法逐页换成贴图皮（一换就整页版式位移）⇒ 换肤被锁死。
##
## 本函数把两者的**文字内边距口径**归一：纹理边距保持源图切片宽不动（拉伸正确性依赖它），
##   仅把 content_margin 压回 GRID ⇒ 两套皮肤**几何逐像素一致**，可安全逐页互换。
## 注意：`取九宫格样式()` 返回的是**共享只读缓存**（见本层红线），故一律 duplicate() 后再改。
func _按钮皮_归一(原: StyleBoxTexture, 下移: int = 0) -> StyleBoxTexture:
	if 原 == null:
		return null
	var v: StyleBoxTexture = 原.duplicate() as StyleBoxTexture
	v.set_content_margin_all(GRID)
	if 下移 != 0:
		# 按下态：内容整体下移 N 逻辑像素（不引入未知属性，与旧范式一致）
		v.content_margin_top = GRID + 下移
		v.content_margin_bottom = GRID - 下移
	return v


## 资产缺失兜底：Flat 版，保证不空窗
func _patch_flat(名: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(RADIUS_PANEL)
	sb.set_border_width_all(BORDER_W)
	sb.set_content_margin_all(int(PATCH_MARGIN.get(名, 36)))
	if 名 == "btn_fill":
		sb.bg_color = 获取钮金起色()
		sb.border_color = 获取亮金边色()
	elif 名 == "btn_frame":
		sb.bg_color = 获取浮层底色()
		sb.border_color = 获取暗金边色()
	elif 名 == "card_row_bg":
		sb.bg_color = 获取行底色止()
		sb.border_color = 获取行描边色()
	else:
		sb.bg_color = 获取卡底色止()
		sb.border_color = 获取卡描边色()
	return sb


## 给任意 Control 套九宫格皮（Panel 系走 "panel" 槽）
func 应用九宫格(控件: Control, 名: String) -> void:
	var sb: StyleBoxTexture = 取九宫格样式(名)
	if sb == null:
		控件.add_theme_stylebox_override("panel", _patch_flat(名))
		return
	控件.add_theme_stylebox_override("panel", sb)


## 建一个已套好皮的 Panel（默认不吃鼠标，避免遮住下层点击）
func 建九宫格面板(名: String) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	应用九宫格(p, 名)
	return p


## 建一个 NinePatchRect（用于需要直接铺贴图的场合）
func 建九宫格图(名: String, w: float, h: float) -> NinePatchRect:
	var r := NinePatchRect.new()
	r.texture = 取九宫格贴图(名)
	# 注：NinePatchRect 无 set_patch_margin_all（4.7 实测报 Nonexistent function），
	#     逐边赋值；StyleBoxTexture 则相反，有 set_texture_margin_all。
	var m: int = int(PATCH_MARGIN.get(名, 36))
	r.patch_margin_left = m
	r.patch_margin_top = m
	r.patch_margin_right = m
	r.patch_margin_bottom = m
	r.custom_minimum_size = Vector2(w, h)
	return r


# ───────── 语义组件（业务代码只应调用这一层，不直接写资产名）─────────

## 页面底面板
func 建页面底面板() -> Panel:
	return 建九宫格面板("panel_bg")


## 主卡 / 详情卡（框中框）
func 建卡片容器() -> Panel:
	return 建九宫格面板("card_bg")


## 列表行（左侧书脊竖条）
func 建列表行容器() -> Panel:
	return 建九宫格面板("card_row_bg")


## 通用空态（图标 + 主文案 + 说明）。
## ★ 为什么要它（#009 逐页精修实测）：原先各页自写空态，散成三套写法
##   （`page_quest._add_empty` / `page_shop._add_empty` / `page_activity._add_empty_label`），
##   且都只有「一行 21px 小字」—— 实机上整屏只有一句话，观感等同「这页没做」。
##   统一到本组件后：字号/颜色/间距全走语义层（禁各页硬编码），新增页面自动同源。
## 用法：`容器.add_child(UITheme.建空态("尚无灵物", "可于山野间寻觅"))`
## 图标名走 `load_hd_icon`，资源缺失自动降级为纯文案（不报错、不掉链）。
func 建空态(标题: String, 说明: String = "", 图标: String = "", 紧凑: bool = false) -> VBoxContainer:
	var 盒 := VBoxContainer.new()
	盒.name = "EmptyState"
	盒.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	盒.add_theme_constant_override("separation", int(GRID * 1.5 * UI_SCALE))
	# 上垫：把空态推到视觉中心偏上，避免贴着页头。
	# 紧凑=true 用于「货架筛选后无货」这类局部空态 —— 上方已有内容，再空 162 设计就假了。
	var 上垫 := Control.new()
	上垫.name = "EmptyTopPad"
	上垫.custom_minimum_size = Vector2(0, int(MARGIN * (1 if 紧凑 else 3) * UI_SCALE))
	上垫.mouse_filter = Control.MOUSE_FILTER_IGNORE
	盒.add_child(上垫)
	if 图标 != "":
		var tex: Texture2D = load_hd_icon(图标)
		if tex != null:
			var 图 := TextureRect.new()
			图.name = "EmptyIcon"
			图.texture = tex
			图.custom_minimum_size = Vector2(132, 132)
			图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			图.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			图.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			图.modulate = Color(1.0, 1.0, 1.0, 0.7)
			图.mouse_filter = Control.MOUSE_FILTER_IGNORE
			盒.add_child(图)
	# ★ 关键（2026-09-16 由 ui_full_accept 抓出回归）：autowrap 的 Label 放进「宽度由内容决定」
	#   的容器（ScrollContainer 内的 VBox 就是 —— 其子项宽度=内容最小宽）时会**塌缩成 1 字符宽、
	#   文本竖排成长条**（验收器原文：`COLLAPSE w=1.0 h=732.0`）。给一个最小宽度下限即解开
	#   这个「宽度↔折行」循环依赖。360 设计 ≈ 屏宽 33%，且小于最窄调用点（库藏网格区 448）
	#   避免溢出：短文案单行、长说明折两行。
	var 最小宽: float = 360.0
	var 主文 := Label.new()
	主文.name = "EmptyTitle"
	主文.text = 标题
	主文.custom_minimum_size = Vector2(最小宽, 0.0)
	主文.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	主文.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	主文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_section_title(主文)
	主文.add_theme_color_override("font_color", 获取次文字色())
	盒.add_child(主文)
	if 说明 != "":
		var 副文 := Label.new()
		副文.name = "EmptyHint"
		副文.text = 说明
		副文.custom_minimum_size = Vector2(最小宽, 0.0)
		副文.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		副文.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		副文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		apply_aux_text(副文)
		副文.add_theme_color_override("font_color", 获取弱文字色())
		盒.add_child(副文)
	# 淡入：空态是「页面已就绪」的信号，给一段入场避免硬切（对齐全局手感层节奏）
	页面入场(盒, 0.18)
	return 盒


# ───────── 图标底座换肤（2026-09-15 定稿 v3：shader 自绘金环）─────────
# 现状：底座**几何完全由 shader 生成**（径向环带 + 中心透空），图集只提供 ±0.05 的纹理微调。
#   原因（全是实测，不是推断）：v2 的「每皮肤一张 AI 实心彩盘」被老大判为不好看 ——
#   ① 实心填充与金色器物抢视觉，帧4(冬)/帧5(仙) 底色亮度 181~213 比金器还亮，直接糊成一片；
#   ② 改成"只留边框"后，素材的环**逐帧半径与圆心都不一致**（内径实测帧0 0.79 / 帧2 0.87，
#      帧3~5 偏心），core=0.62 时帧0/1/2 完整而帧3/4/5 缺口；压到 0.44 才全完整 ⇒ 与"无底色"冲突。
#   ⇒ 几何交给 shader（6 帧共用同一环，永无缺口），色相统一为金（与器物同色系）。
# 环宽按**物理像素**恒定（ico_ring_px=5.5）：内径由 instance uniform ico_dia_px（该图标物理直径）
#   反推，故 68px 的 dock 图标与 149px 的入口图标环宽一致 —— 固定归一化内径会让 dock 环只剩
#   3.2px，实机退化成"脏边"。共享材质不变，无材质副本，换肤仍是 O(1)。
# 增量维护：新皮肤 → AI 出一张 1024 底座（只影响环面纹理）丢进 art/_src/，跑 _atlas_build.py
#   追加帧 → SKIN_ICON_BASE 加一行 frame=N；未登记帧自动回落帧 0，功能不残。
# 素材全缺也不影响：环是 shader 画的，图集缺失时纹理微调项归零而已。
const ICON_BASE_ATLAS: String = "res://art/ui/icon_base_atlas.png"
const ICON_BASE_GRID: Vector2 = Vector2(8.0, 1.0)   # 列, 行 —— 与图集构建脚本同步
const ICON_BASE_TEX: String = "res://art/ui/icon_base.png"
const ICON_BASE_SHADER: String = "res://ui/icon_base_skin.gdshader"

## 6 套幻形皮肤 → 底座帧 + 目标金属色 + 框体档位
## ★ 2026-09-15 v4（老大定）：「框一直是金色」→ 改为**随皮肤（背景）换色**。
##   hue = 目标金属色相（0~1，0.116≈金）/ sat = 目标亮端饱和 / val = 明度倍率 / tint = 乘算染色。
##   tier = 框体档位（0 素环 / 1 双环 / 2 鎏金镶宝）—— 为「仙玉背景自带更高级框体」预留，
##   基础六皮肤一律 0，付费皮肤上档即可，**改这一行就生效、无需改 shader 或消费点**。
##   配色依据各皮肤名的字面意象（青瓷/嫩青/碧荷/金风/雪霁/九霄），出图核过观感再定稿。
const SKIN_ICON_BASE: Dictionary = {
	"taixu_yunhai": {"frame": 0.0, "hue": 0.470, "sat": 0.44, "val": 1.00, "tier": 0.0, "tint": Color(1.00, 1.00, 1.00, 1.0)},  # 青瓷玉环（配青绿山水）
	"chun_qinglan": {"frame": 1.0, "hue": 0.355, "sat": 0.50, "val": 1.02, "tier": 0.0, "tint": Color(1.00, 1.00, 1.00, 1.0)},  # 春·嫩青（偏黄绿，明快）
	"xia_bihe":     {"frame": 2.0, "hue": 0.445, "sat": 0.64, "val": 0.97, "tier": 0.0, "tint": Color(1.00, 1.00, 1.00, 1.0)},  # 夏·碧荷浓翠（最饱和）
	"qiu_jinfeng":  {"frame": 3.0, "hue": 0.095, "sat": 0.70, "val": 1.00, "tier": 0.0, "tint": Color(1.00, 1.00, 1.00, 1.0)},  # 秋·金风琥珀（暖橙金）
	"dong_xueji":   {"frame": 4.0, "hue": 0.585, "sat": 0.13, "val": 1.12, "tier": 0.0, "tint": Color(1.00, 1.00, 1.00, 1.0)},  # 冬·雪霁冰银（极低饱和 + 提亮）
	"xian_jiuqiao": {"frame": 5.0, "hue": 0.790, "sat": 0.52, "val": 1.00, "tier": 0.0, "tint": Color(1.00, 1.00, 1.00, 1.0)},  # 仙·九霄紫金
}

var _底座贴图: Texture2D = null
var _底座材质: ShaderMaterial = null      # ★ 全局唯一共享材质：改它的参数 = 全屏底座同步换色
var _当前底座皮肤: String = "taixu_yunhai"

func _ready() -> void:
	_取底座材质()
	_挂全局手感钩子()

# ══════════ 全局手感（按压反馈 · 页面入场）══════════
# ★ 2026-09-16 老大定「达到手游大厂水准，该有的特效全加上」。
#   本项目绝大多数字是按都是 `flat = true` + 四个状态全 StyleBoxEmpty 的**透明热区**
#   （顶栏入口、资源槽、图标钮…）⇒ 按下去**零视觉反馈**，点哪儿都像没反应。
#   逐个去 67 个页面里补反馈不可维护，故改为**一次性全局节点钩子**：
#   任何 BaseButton 一入树就自动获得「按下缩小 → 松开回弹」，新旧页面一并覆盖。
#   反馈量刻意做小（0.94 / 60ms 按下、120ms 回弹）：大厂手感是「能感觉到但看不到动作」，
#   缩放再大就会像整块 UI 在抖。
const 按压缩放: float = 0.94
const 按下时长: float = 0.06
const 回弹时长: float = 0.12
# 挂钩标记的 meta 键：必须 ASCII（见 _on_节点入树 注释）。
const META_已挂手感: String = "_ui_press_hooked"

func _挂全局手感钩子() -> void:
	var 树: SceneTree = get_tree()
	if 树 == null or 树.node_added.is_connected(_on_节点入树):
		return
	树.node_added.connect(_on_节点入树)

func _on_节点入树(n: Node) -> void:
	# 版式兜底先跑：与按钮无关，但同样只在「入树」这一个时机判定一次
	if n is Control:
		var c: Control = n
		_入树_补折行(c)
		_入树_包边距(c)
		_入树_补尾垫(c)
	if not (n is BaseButton):
		return
	var b: BaseButton = n
	# ★ meta 名**必须 ASCII**：Godot 4 对非 ASCII 的 metadata 名直接报
	#   `ERROR: Invalid metadata identifier` 并**静默不生效**（set_meta 返回 void，无从感知）。
	#   曾用中文名 "_ui_手感已挂钩"，结果守卫整条失效 —— 只是恰好被引擎自身的
	#   connect 去重兜住（重复连接会报 already connected），才没演成「按一次跳 N 次」。
	#   同理：用 meta 而非 instance_id 字典，是因为 instance_id 在节点释放后会被回收，
	#   新按钮复用同一 id 就会被误判「已挂钩」而永远拿不到反馈。
	if b.has_meta(META_已挂手感):
		return
	b.set_meta(META_已挂手感, true)
	b.button_down.connect(_手感_按下.bind(b))
	b.button_up.connect(_手感_松开.bind(b))
	b.mouse_exited.connect(_手感_松开.bind(b))

func _手感_按下(b: BaseButton) -> void:
	if not is_instance_valid(b):
		return
	# 轴心每次按下现算：按钮尺寸在布局后/换页后才定型，入树时取到的常是 0。
	b.pivot_offset = b.size * 0.5
	var tw: Tween = create_tween()
	var p: PropertyTweener = tw.tween_property(b, "scale", Vector2(按压缩放, 按压缩放), 按下时长)
	p.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _手感_松开(b: BaseButton) -> void:
	if not is_instance_valid(b):
		return
	if b.scale.is_equal_approx(Vector2.ONE):
		return   # 悬停移出也会走到这里，已是原尺寸就不再起 tween（省掉大量空动画）
	var tw: Tween = create_tween()
	var p: PropertyTweener = tw.tween_property(b, "scale", Vector2.ONE, 回弹时长)
	p.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ══════════ 全局版式兜底（无效边距 · 长文案折行）══════════
# ★ 2026-09-16（#009 逐页精修）两类跨页系统性缺陷，收口到同一个入树钩子：
#   ① `margin_left/right/top/bottom` 是 **MarginContainer 专有**主题常量。设在 VBox/HBox/Grid 上
#      **不报错、不生效**（全项目 33 页 / 230+ 处）⇒ 卡片左右直接贴屏边。
#      gdtoolkit、类型扫描、36 道闸门全看不见，只有真机截图看得出来（拍卖行/库藏页实证）。
#   ② Label 默认 `AUTOWRAP_OFF`，长文案溢出容器右沿被裁（「宗门灵石：1687」只剩半截）。
#      但 autowrap 会把 Label 最小宽压到「最长不可断片段」（中文≈1 字），
#      **凡宽度由 min 宽决定的宿主，一开就竖排塌缩** ⇒ 必须判完父链才敢开。
#   两条都只在「节点入树」判定一次，调用点零改动、新旧页面一并覆盖。
const META_已查折行: String = "_ui_aw_checked"      # ASCII：非 ASCII 的 meta 名会静默失效
const META_已包边距: String = "_ui_margin_wrapped"
const 全局折行兜底: bool = true                      # 关掉即可整体回退（排查用）

func _入树_补折行(c: Control) -> void:
	if not 全局折行兜底:
		return
	var lb: Label = c as Label
	if lb == null or lb.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return
	if lb.has_meta(META_已查折行):
		return
	lb.set_meta(META_已查折行, true)
	# 延迟到帧末：入树时祖先链往往还没挂完，当场判会判错
	_补折行_延迟.call_deferred(lb)

func _补折行_延迟(lb: Label) -> void:
	if not is_instance_valid(lb) or lb.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return
	if not _折行安全(lb):
		return
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

## 折行安全判定：沿父链上行，任一环「不保证给子项宽度」就判不安全。
##  - VBox / Margin / Panel / Tab / AspectRatio / VSplit：横向撑满子项 ⇒ 继续向上看它自己的宽度来源；
##  - ScrollContainer：只有水平滚动 DISABLED 才会把子项撑到视口宽（AUTO 会按 min 宽分配）；
##  - HBox / Grid / Center / HFlow：子项不带 EXPAND 时宽度=min 宽 ⇒ 不安全；
##  - 其余 Container：保守判不安全；
##  - 普通 Control / 非容器：**不负责给子项排布**，子项宽度只能靠自身锚点或最小宽撑
##    ⇒ 交给 _宽度独立 判定。
## ★ 两轮回归教训（都靠真机验收才抓到）：
##   ① 首版这里对「非容器父」直接 return true ⇒ 老模板页「丹方系统」这类锚点未拉伸的标题
##      Label 被压成 w=1 竖排（4 处 TALL）。
##   ② 二版改成「锚点拉伸即安全」仍不够 —— 宗门战 4 张类型卡的 desc 父链是
##      `Label ← VBox ← Button(非容器) ← GridContainer`，锚点拉伸继承的是 Button 的宽度，
##      而 Button 列宽由 Grid 按 min 宽分配 ⇒ 折行后整列塌成 w=24 竖排。
##      ⇒ 必须**递归判定到根**：只有「宽度真值与自身内容无关」才敢开折行。
func _折行安全(c: Control) -> bool:
	if (c.size_flags_horizontal & Control.SIZE_FILL) == 0:
		return false
	return _宽度独立(c)

## 该节点的横向宽度是否「与自身内容无关」。真值来源只有三类：
## 根（视口宽度）、容器排布规则、以及锚点/最小宽（锚点又需父级宽度独立才成立）。
func _宽度独立(c: Control) -> bool:
	var 父: Node = c.get_parent()
	if 父 == null or not (父 is Control):
		return true                                  # 根：宽度来自视口，与内容无关
	if 父 is HBoxContainer or 父 is GridContainer or 父 is CenterContainer or 父 is HFlowContainer:
		if (c.size_flags_horizontal & Control.SIZE_EXPAND) == 0:
			return false                             # 宽度=min 宽 ⇒ 一折行必塌
		return _宽度独立(父)
	if 父 is ScrollContainer:
		if (父 as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return false
		return _宽度独立(父)
	if 父 is VBoxContainer or 父 is MarginContainer or 父 is PanelContainer \
			or 父 is TabContainer or 父 is AspectRatioContainer or 父 is VSplitContainer:
		return _宽度独立(父)                          # 父横向撑满子项 ⇒ 取决于父自身宽度
	if 父 is Container:
		return false                                 # 其余容器保守
	# 父是普通 Control：不负责排布子项 ⇒ 宽度只能来自自身锚点或最小宽
	if c.custom_minimum_size.x > 0.0:
		return true
	if c.anchor_right > c.anchor_left:
		return _宽度独立(父)                          # 锚点拉伸的宽度继承自父，需父也独立
	if is_equal_approx(c.anchor_left, c.anchor_right) and c.offset_right - c.offset_left > 0.0:
		return true                                  # 固定宽
	return false

func _入树_包边距(c: Control) -> void:
	if not (c is VBoxContainer or c is HBoxContainer or c is GridContainer):
		return
	if c.has_meta(META_已包边距):
		return
	if not (c.has_theme_constant_override("margin_left") or c.has_theme_constant_override("margin_right")
			or c.has_theme_constant_override("margin_top") or c.has_theme_constant_override("margin_bottom")):
		return
	c.set_meta(META_已包边距, true)
	_包边距_延迟.call_deferred(c)

## 把「无效边距宿主」原地替换成 MarginContainer，补回开发者本意（横竖留白）。
## 关键：**整体平移原节点的 size_flags** —— MarginContainer 同为 Container，
## 宿主对「包」的排布与原先对原节点的排布逐项等价，因此对布局零副作用。
func _包边距_延迟(c: Control) -> void:
	if not is_instance_valid(c):
		return
	var 父: Node = c.get_parent()
	if 父 == null:
		return
	var 包: MarginContainer = MarginContainer.new()
	包.name = "MarginWrap"
	for 键 in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		if c.has_theme_constant_override(键):
			包.add_theme_constant_override(键, c.get_theme_constant(键))
	包.size_flags_horizontal = c.size_flags_horizontal
	包.size_flags_vertical = c.size_flags_vertical
	if not (父 is Container):
		# 原节点靠锚点定位（普通 Control 的子节点）：包必须继承同一套锚点，否则缩成 0×0
		包.anchor_left = c.anchor_left
		包.anchor_top = c.anchor_top
		包.anchor_right = c.anchor_right
		包.anchor_bottom = c.anchor_bottom
		包.offset_left = c.offset_left
		包.offset_top = c.offset_top
		包.offset_right = c.offset_right
		包.offset_bottom = c.offset_bottom
		c.anchor_left = 0.0
		c.anchor_top = 0.0
		c.anchor_right = 0.0
		c.anchor_bottom = 0.0
		c.offset_left = 0.0
		c.offset_top = 0.0
		c.offset_right = 0.0
		c.offset_bottom = 0.0
	var 位: int = c.get_index()
	父.remove_child(c)
	父.add_child(包)
	父.move_child(包, 位)
	包.add_child(c)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL

# ── 滚动区尾部留白（ScrollTailPad 全局化）──────────────────────
# ★ 2026-09-16（#009 逐页精修）：`VBoxContainer.separation` **只作用于相邻子项之间**，
#   末项之后不留白 ⇒ 滚到底时末卡紧贴容器下沿（坊市页实证）。
#   做法沿用同文件 `_入树_包边距` 的**结构包裹**思路：给滚动内容包一层带 `margin_bottom`
#   的 MarginContainer。**关键优点是不需要自愈** —— 包裹层是内容的**父**，
#   而页面 populate 清空的是「内容的子项」，不会波及包裹层。
#   ⚠️⚠️ 血案：曾用「末尾加一个 Control 尾垫 + 监听宿主 `child_order_changed` 自愈」实现，
#   **导致主场景启动即死循环挂起**（信号 → `move_child` → 再次触发信号 → …，
#   实机表现「游戏卡住不启动」，headless 与真实渲染同样挂，gate/gdtoolkit 全绿看不见）。
#   ⇒ 铁律：**版式兜底一律走「不可变结构」，绝不引入信号回环**。
const META_滚动尾垫: String = "_ui_tail_pad_wrapped"
const 全局尾垫兜底: bool = true

func _入树_补尾垫(c: Control) -> void:
	if not 全局尾垫兜底:
		return
	if not (c is ScrollContainer):
		return
	if c.has_meta(META_滚动尾垫):
		return
	c.set_meta(META_滚动尾垫, true)
	_补尾垫_延迟.call_deferred(c as ScrollContainer)

func _补尾垫_延迟(sc: ScrollContainer) -> void:
	if not is_instance_valid(sc):
		return
	if sc.get_node_or_null("TailPadWrap") != null:
		return
	# 只在「ScrollContainer 恰有一个容器子节点」时处理（这是它的既定用法）
	if sc.get_child_count() != 1:
		return
	var 内容: Node = sc.get_child(0)
	if not (内容 is VBoxContainer or 内容 is HBoxContainer or 内容 is GridContainer):
		return
	# 页面已自己手写尾垫（ui/page_shop.gd 的 ScrollTailPad）⇒ 跳过，避免双重留白
	if 内容.get_node_or_null("ScrollTailPad") != null:
		return
	var 包: MarginContainer = MarginContainer.new()
	包.name = "TailPadWrap"
	包.add_theme_constant_override("margin_bottom", int(float(MARGIN) * UI_SCALE * 0.75))
	包.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	包.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.remove_child(内容)
	sc.add_child(包)
	包.add_child(内容)

## 一级页（底部 Tab）切换入场：纯淡入。
## 平级跳转不该有方向语义，加位移反而会让人以为「进了下一层」。
func 页面入场(c: Control, 时长: float = 0.14) -> void:
	if c == null or not is_instance_valid(c):
		return
	if 动效强度 <= 0.0:
		c.modulate.a = 1.0   # 关动效时必须显式复位：否则页面停在上一轮残留的 alpha 上
		return
	c.modulate.a = 0.0
	var t: Tween = create_tween()
	t.tween_property(c, "modulate:a", 1.0, 时长).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 二级页入场：淡入 + 由右向左滑入。
## 滑入方向即层级语义（push），与「← 返回」形成一条可读的导航轴。
## 位移走 position 而非 anchor offset：调用方刚跑过 PRESET_FULL_RECT，
## 起止值都是相对同一基准的偏移，收尾必然回到 (0,0)，不会留下累积误差。
func 二级页入场(c: Control, 时长: float = 0.2, 位移: float = 34.0) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.modulate.a = 0.0
	c.position = Vector2(位移, 0.0)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	var pa: PropertyTweener = tw.tween_property(c, "modulate:a", 1.0, 时长)
	pa.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var pp: PropertyTweener = tw.tween_property(c, "position", Vector2.ZERO, 时长)
	pp.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ───────── 列表错峰入场（大厂观感：条目依次亮起，而非整块弹出）─────────
# ★ 只做**透明度**错峰，不碰 position/size：容器托管的子节点位置会被下一次 sort 覆写，
#   位移 tween 必与布局打架。透明度与页面级入场是 modulate **相乘**，天然叠加、零冲突。
const 错峰_间隔: float = 0.05
const 错峰_条目上限: int = 10
const 错峰_单条时长: float = 0.18
const META_错峰TWEEN: String = "_stagger_tw"   # ★ 必须 ASCII（中文键 Godot 4 静默失效）

func 列表错峰入场(根: Node, 间隔: float = 错峰_间隔, 上限: int = 错峰_条目上限) -> void:
	if 根 == null or not is_instance_valid(根):
		return
	if 动效强度 <= 0.0:
		return   # 条目本就是 alpha=1，直接不动即可
	var 容器: Node = _找首个列表容器(根)
	if 容器 == null:
		return
	var 条目: Array = 容器.get_children()
	if 条目.size() < 3:
		return   # 条目太少，错峰反而显拖沓
	var n: int = mini(条目.size(), 上限)
	for i in range(条目.size()):
		var c: Control = 条目[i] as Control
		if c == null:
			continue
		# 每次入场先杀上一条错峰 tween：快速来回切页时旧 tween 会被暂停在半路，
		# 不杀就会与新 tween 争 modulate:a，条目可能停在半透明。
		# 必须先 has_meta 再 get_meta —— `get_meta(key, null)` 缺键时仍会刷 ERROR。
		if c.has_meta(META_错峰TWEEN):
			var 旧: Variant = c.get_meta(META_错峰TWEEN)
			if 旧 is Tween and (旧 as Tween).is_valid():
				(旧 as Tween).kill()
		if i >= n:
			c.modulate.a = 1.0   # 上限之外直接待命，避免长列表整体延迟
			continue
		c.modulate.a = 0.0
		var t: Tween = create_tween().bind_node(c)
		t.tween_interval(间隔 * float(i))
		t.tween_property(c, "modulate:a", 1.0, 错峰_单条时长).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		c.set_meta(META_错峰TWEEN, t)

## ★ 2026-09-16（#18 动效层收口）：进度条数值缓动 —— 统一入口。
## 问题：全项目 24 处 ProgressBar 全是 `bar.value = x` 直接赋值 ⇒ 数值瞬跳，观感廉价。
## 大厂做法是让进度条自己「走」过去（成长反馈的视觉主体）。
##
## 两种用法都安全：
##   ① 新建的条（多数页面在 refresh 里 new）→ 先 `bar.value = 0.0` 再调本函数 ＝ 从 0 生长
##   ② 复用的条 → 直接调本函数 ＝ 值变化时平滑过渡，值没变则完全不动
## 自动处理：动效强度=0 时直接赋值（零 tween）；重复调用杀旧 tween（防快速刷新时抖动）。
const META_进度TWEEN: String = "_ui_bar_tw"

func 进度缓动(bar: ProgressBar, 目标: float, 时长: float = 0.38) -> void:
	if bar == null or not is_instance_valid(bar):
		return
	if 动效强度 <= 0.0:
		bar.value = 目标
		return
	if bar.has_meta(META_进度TWEEN):
		var 旧: Variant = bar.get_meta(META_进度TWEEN)
		if 旧 is Tween and (旧 as Tween).is_valid():
			(旧 as Tween).kill()
	if is_equal_approx(bar.value, 目标):
		return
	# 注意：tween 宿主是 UITheme（autoload Node），bind_node 只用于「节点释放即停」；
	# 故 bar 尚未 add_child 时动画照样推进，入树即可见 —— 调用方无需调整语句顺序。
	var t: Tween = create_tween().bind_node(bar)
	t.tween_property(bar, "value", 目标, 时长).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bar.set_meta(META_进度TWEEN, t)

# 语义定位：页面里第一个 ScrollContainer 的子 VBoxContainer ＝ 货架/名录。
# 退化为「首个 ScrollContainer 的首个子级」；都找不到返回 null（该页不做错峰）。
func _找首个列表容器(根: Node) -> Node:
	var 队列: Array = [根]
	while not 队列.is_empty():
		var cur: Node = 队列.pop_front()
		if cur is ScrollContainer:
			for ch in cur.get_children():
				if ch is VBoxContainer:
					return ch
			if cur.get_child_count() > 0:
				return cur.get_child(0)
		for ch in cur.get_children():
			队列.append(ch)
	return null

# ───────── 弹窗 / 抽屉入场 ─────────
# 遮罩与面板**分两条 tween**：面板若也做纯 alpha 淡入，会被遮罩的暗化「吃掉」半程，
#   看成「糊出来」而不是「弹出来」。遮罩只动 alpha 且先到位（0.7×时长），面板动 scale+alpha
#   ⇒ 玩家感受到的是「聚焦 → 弹现」。调用点只需两行：建好面板后 弹窗入场(面板, 遮罩)。
# ★ 只用 scale + modulate.a，**绝不用 position**：弹窗普遍走 anchor/offset 定位（如居中弹窗
#   anchor=0.5、全屏面板 PRESET_FULL_RECT），其 position 由 anchor 算出而非 (0,0)，
#   补间到 Vector2.ZERO 会直接把面板拖到左上角。scale 不参与 anchor 计算，安全。
func 弹窗入场(面板: Control, 遮罩: Control = null, 时长: float = 0.22, 缩放: bool = true) -> void:
	if 面板 == null or not is_instance_valid(面板):
		return
	if 动效强度 <= 0.0:
		面板.modulate.a = 1.0
		面板.scale = Vector2.ONE
		if 遮罩 != null and is_instance_valid(遮罩):
			遮罩.modulate.a = 1.0
		return
	面板.modulate.a = 0.0
	if 缩放:
		面板.pivot_offset = _弹窗轴心(面板)
		面板.scale = Vector2(0.9, 0.9)
	if 遮罩 != null and is_instance_valid(遮罩):
		var 原: float = 遮罩.modulate.a
		遮罩.modulate.a = 0.0
		var tm: Tween = create_tween().bind_node(遮罩)
		var pm: PropertyTweener = tm.tween_property(遮罩, "modulate:a", 原, 时长 * 0.7)
		pm.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var t: Tween = create_tween().bind_node(面板)
	t.set_parallel(true)
	var pa: PropertyTweener = t.tween_property(面板, "modulate:a", 1.0, 时长)
	pa.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if 缩放:
		var ps: PropertyTweener = t.tween_property(面板, "scale", Vector2.ONE, 时长)
		ps.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 弹窗轴心兜底：面板刚 add_child 时 size 常为 (0,0)（子节点尚未布局），
## 直接用 size 算会让缩放绕左上角、动画像「从角上铺开」。
## 依次退到 custom_minimum_size → get_combined_minimum_size()（PanelContainer 按内容算得非零），
## 三级都拿不到才接受左上角。
func _弹窗轴心(面板: Control) -> Vector2:
	var 尺寸: Vector2 = 面板.size
	if 尺寸.x < 2.0 or 尺寸.y < 2.0:
		尺寸 = 面板.custom_minimum_size
	if 尺寸.x < 2.0 or 尺寸.y < 2.0:
		尺寸 = 面板.get_combined_minimum_size()
	return 尺寸 * 0.5

# ───────── 抽屉入场（自屏幕边缘滑入）─────────
# ★ 仅限**绝对定位**的面板（构造时直接给 position/size）。
#   若面板走 anchor/offset 定位，其 position 由 anchor 算出，补间 position 会与 anchor 基准
#   叠加、收尾回不到原位 —— 这类面板请用 弹窗入场()（只动 scale/alpha）。
# 方向约定：Vector2(0, 1) = 从下方升起（底部抽屉）；Vector2(0, -1) = 从上方落下。
func 抽屉入场(面板: Control, 遮罩: Control = null, 方向: Vector2 = Vector2(0, 1), 位移: float = 140.0, 时长: float = 0.26) -> void:
	if 面板 == null or not is_instance_valid(面板):
		return
	var 终点: Vector2 = 面板.position
	if 动效强度 <= 0.0:
		面板.modulate.a = 1.0
		if 遮罩 != null and is_instance_valid(遮罩):
			遮罩.modulate.a = 1.0
		return
	var 单位: Vector2 = 方向.normalized()
	if 单位 == Vector2.ZERO:
		单位 = Vector2(0, 1)
	面板.position = 终点 + 单位 * 位移
	面板.modulate.a = 0.0
	if 遮罩 != null and is_instance_valid(遮罩):
		var 原: float = 遮罩.modulate.a
		遮罩.modulate.a = 0.0
		var tm: Tween = create_tween().bind_node(遮罩)
		var pm: PropertyTweener = tm.tween_property(遮罩, "modulate:a", 原, 时长 * 0.8)
		pm.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var t: Tween = create_tween().bind_node(面板)
	t.set_parallel(true)
	var pp: PropertyTweener = t.tween_property(面板, "position", 终点, 时长)
	pp.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var pa: PropertyTweener = t.tween_property(面板, "modulate:a", 1.0, 时长 * 0.7)
	pa.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## ★★★ 2026-09-15 v2 定案：底座从「全局开关」改为「按图标白名单」。
##
## 演进两段，都要看，别只读一半：
##
## 【v1 · 为什么全局关闭】当时 45 张 entry_* **全部**是「自带金环 + 方底」的成品徽章
##   （量测：边 5% 处 alpha 仍达 90~110、边 12% 达 200、中心 255），本项目根本不存在
##   "裸图标等一个框"的场景。在图标下层再垫一层青玉底座 ⇒ 必然：
##     ① 四角半透明像素把底座青绿金环**透出来** ⇒ 玩家描述「图标外有一大片色素」；
##     ② 图标自带金环 + 底座金环**错位叠加** ⇒ 玩家描述「重影 / 双环 / 乱」；
##     ③ hall_* 方底**溢出**底座内圆 ⇒ 殿阁卡片"一团杂乱"。
##   老大判定语（决定性）：「做底座之前图标是没出问题的」—— 与上述机理逐条对上。
##
## 【v2 · 为什么重新启用】2026-09-15 豆包交付 26 张**无背景无边框**的纯金裸器物图标
##   （原交付是 JPEG 冒充 PNG 且无 alpha，已用 rescue_entry_icons.py 抠底重建：
##    透明底 + 边缘底色污染 0% + 四边留白 ≥12% + 主体归一化到 76%，正好撑满底座
##    青玉内圈的 ~78%）。这类"裸主体"**必须**有底座才成立 —— 否则与仍在用的旧版徽章
##    混排会出现「有框 vs 无框」的断裂。**但旧版徽章绝不能再叠**（会复现 v1 的 ①②③）。
##
## ⇒ 结论：总开关打开，但**是否叠加由 ICON_BASE_WHITELIST 按图标名决定**。
## 后续：等旧版徽章全部重做成裸图后，把白名单逻辑反转成「例外表」即可全量统一。
const ENABLE_ICON_BASE: bool = true

## ★ 裸图标白名单：**只有**列在这里的 stem 才叠底座。
##   stem = load_hd_icon() 传入的名字（不含目录与扩展名），如 "entry_fangshi_36"。
##
## ★ 2026-09-15 二次裁定（老大：「首页入口图标还是没有加圆框」「更多里面也很多图标没圆框」）：
##   原判据「主体外沿半径 r≥0.85 = 自带徽章框」**已废弃** —— 宽底/方形/近圆的裸器物会被误判
##   （宗门典藏卷轴斜置四角远达 0.87、传送阵方台 0.89 都被当成"自带框"），于是被漏出白名单，
##   同屏出现「有框 vs 无框」断裂。
##   现判据 = **目视全量核验**：art/icons/entry/ 下 52 张 PNG 已逐张确认（8×8 总览图 + 关键图全分辨率）
##   **全部为裸器物（无任何自带圆环/徽章底）**，故圆环一律由本表的 shader 底座提供。
##   ⇒ 凡被入口表引用的 entry_* stem 全部入列；新增裸图照此加一行即可。
const ICON_BASE_WHITELIST: PackedStringArray = [
	# ── 首批（2026-09-15 豆包交付批次）──
	"entry_activity_36", "entry_auction_36", "entry_battle_36", "entry_beast_36",
	"entry_daoyou_36", "entry_dudao_36", "entry_dynasty_36", "entry_equipment_blueprint_36",
	"entry_faction_36", "entry_feifuchuanxin_36", "entry_feisheng_36",
	"entry_gongjitang_36", "entry_herb_garden_36", "entry_huanxing_36", "entry_kucang_36",
	"entry_library_36", "entry_lingniang_36", "entry_lundao_36", "entry_pill_formula_36",
	"entry_qiandao_36", "entry_qiyuan_36", "entry_treasure_36", "entry_zhenfa_36",
	"entry_zushitang_36", "entry_zongmenyaowu_36", "entry_fangshi_36",
	# ── 二次补登（首页四入口 / dock / 更多面板 的剩余裸图）──
	# 首页：天下 / 玄榜 / 宗门典藏 / 碎片宝箱；dock：设置 / 更多；
	# 更多：宗门气运 / 灵兽 / 宗门战 / 传送阵 / 风水堪舆 / 科技 / 家族 / 傀儡 / 宗主 /
	#       宗主管理 / 宗规 / 功勋 / 身外化身 / 入山采撷 / 闲情雅趣 / 护道人 / 音律 等。
	"entry_tianxia_36", "entry_fengyunbang_36", "entry_tujian_36", "entry_fragment_chest_36",
	"entry_shezhi_36", "entry_more_36",
	"entry_sect_qi_36", "entry_teleport_36", "entry_tech_36", "entry_fengshui_36",
	"entry_family_36", "entry_puppet_36", "entry_master_36", "entry_zongzhuguanli_36",
	"entry_zongmenguizhi_36", "entry_gongxunbei_36", "entry_huashen_36", "entry_ruishan_36",
	"entry_xianqing_36", "entry_hudao_36", "entry_yinlv_36", "entry_zongmen_battle_36",
	"entry_lingquan_36", "entry_shanmen_36", "entry_shoulie_36", "entry_grand_ceremony_36",
]

## 该图标是否需要叠底座 —— **消费点统一调用本函数**，不要直接读 ENABLE_ICON_BASE。
## （旧图标自带徽章的判断逻辑就藏在这一层，直接把开关撒到消费点会重演 v1 事故。）
static func 图标需要底座(stem: String) -> bool:
	if not ENABLE_ICON_BASE or stem == "":
		return false
	return ICON_BASE_WHITELIST.has(stem)

## 图标底座：圆形边框（shader 自绘环 + 中心透空），走共享 ShaderMaterial（切皮肤自动跟随）
## 返回 TextureRect（非 Panel）—— 只有贴图节点才能接 shader；调用方照旧叠中心图案。
## ⚠ 仅在 UITheme.图标需要底座(stem) 返回 true 时调用 —— 白名单制，理由见 ENABLE_ICON_BASE 上方长注释。
## 直接读 ENABLE_ICON_BASE 会在旧版自带徽章图上误叠，复现 v1 的「四角透青绿 + 双环」事故。
## ★ 2026-09-15：`直径` 参数（逻辑单位）现**真正参与渲染** —— 写入 instance_shader_parameter
##   让 shader 按物理直径反推环内径，保证各处环带宽视觉一致（dock 30 逻辑下细环只有 3.2px，
##   会退化成"脏边"）。共享材质不变，无材质副本。
func 建图标底座(直径: float, 选中: bool = false) -> TextureRect:
	var t := TextureRect.new()
	t.name = "IconBase"
	t.texture = _取底座贴图()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.material = _取底座材质()
	t.set_instance_shader_parameter("ico_dia_px", maxf(直径 * UI_SCALE, 1.0))
	# 选中态差异走 self_modulate（材质仍是共享的那一份，不破坏批处理）
	t.self_modulate = Color(1.18, 1.18, 1.18, 1.0) if 选中 else Color(1.0, 1.0, 1.0, 1.0)
	return t

## 切皮肤：改共享材质的帧号 + 目标金属色 + 框体档位（O(1)，全屏底座同帧生效）
func 设图标底座皮肤(skin_id: String) -> void:
	_当前底座皮肤 = skin_id
	if _底座材质 == null:
		return
	var cfg: Dictionary = SKIN_ICON_BASE.get(skin_id, SKIN_ICON_BASE["taixu_yunhai"])
	_底座材质.set_shader_parameter("ico_frame", float(cfg.get("frame", 0.0)))
	_底座材质.set_shader_parameter("ico_hue", float(cfg.get("hue", 0.116)))
	_底座材质.set_shader_parameter("ico_sat", float(cfg.get("sat", 0.62)))
	_底座材质.set_shader_parameter("ico_val", float(cfg.get("val", 1.0)))
	_底座材质.set_shader_parameter("ico_tier", float(cfg.get("tier", 0.0)))
	_底座材质.set_shader_parameter("ico_tint", cfg.get("tint", Color(1, 1, 1, 1)))

## 底座贴图：6 皮肤图集优先 → 单张模板 → 代码烘焙（三级兜底，保证零资产也能跑）
func _取底座贴图() -> Texture2D:
	if _底座贴图 != null:
		return _底座贴图
	if ResourceLoader.exists(ICON_BASE_ATLAS):
		var tex: Texture2D = load(ICON_BASE_ATLAS) as Texture2D
		if tex != null:
			_底座贴图 = tex
			if _底座材质 != null:
				_底座材质.set_shader_parameter("ico_grid", ICON_BASE_GRID)
			return tex
	if ResourceLoader.exists(ICON_BASE_TEX):
		var tex: Texture2D = load(ICON_BASE_TEX) as Texture2D
		if tex != null:
			_底座贴图 = tex
			return tex
	_底座贴图 = _烘底座贴图()
	return _底座贴图

## 共享材质（单例）；新建时立即套用当前皮肤参数
func _取底座材质() -> ShaderMaterial:
	if _底座材质 != null:
		return _底座材质
	var sh: Shader = load(ICON_BASE_SHADER) as Shader
	if sh == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = sh
	if _底座贴图 != null and ResourceLoader.exists(ICON_BASE_ATLAS):
		m.set_shader_parameter("ico_grid", ICON_BASE_GRID)
	_底座材质 = m
	设图标底座皮肤(_当前底座皮肤)
	return m

## 代码烘焙兜底底图：青瓷半透圆底 + 金环 + 边缘羽化（128×128，仅首帧一次）
func _烘底座贴图() -> Texture2D:
	var n: int = 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c: float = float(n) * 0.5
	var 底色: Color = C01_TAB_ICON_BG_IDLE
	var 环色: Color = 获取暗金边色()
	for y in range(n):
		for x in range(n):
			var dx: float = float(x) - c + 0.5
			var dy: float = float(y) - c + 0.5
			var d: float = sqrt(dx * dx + dy * dy) / c
			var col := Color(0.0, 0.0, 0.0, 0.0)
			if d <= 1.0:
				if d >= 0.90:
					col = 环色
					col.a = 0.95
				elif d >= 0.84:
					col = 环色
					col.a = 0.35
				else:
					col = 底色
					col.a = 0.72
				if d > 0.96:  # 外缘羽化，避免锯齿
					col.a *= clamp((1.0 - d) / 0.04, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## 金底按钮上的深墨文字色（与既有 apply_button_label(dark=true) 同源）
func 获取金底文字色() -> Color:
	return COLOR_BTN_PRESSED


## 主按钮皮：金渐变填充 + 端扣；按下 = 内容下移 3px；禁用 = 半透描边版
## ★ 2026-09-16：几何口径已与纯色平肤归一（见 _按钮皮_归一）⇒ 可与 apply_primary_button_style 逐页互换。
func 应用主按钮皮(btn: BaseButton) -> void:
	var normal: StyleBoxTexture = _按钮皮_归一(取九宫格样式("btn_fill"))
	if normal == null:
		apply_primary_button_style(btn)
		return
	var pressed: StyleBoxTexture = _按钮皮_归一(取九宫格样式("btn_fill"), 3)
	var disabled: StyleBoxTexture = _按钮皮_归一(取九宫格样式("btn_frame"))
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", pressed if pressed != null else normal)
	btn.add_theme_stylebox_override("disabled", disabled if disabled != null else normal)
	btn.add_theme_font_size_override("font_size", FONT_BODY)
	btn.add_theme_color_override("font_color", 获取金底文字色())
	btn.add_theme_color_override("font_hover_color", 获取金底文字色())
	btn.add_theme_color_override("font_pressed_color", 获取金底文字色())
	btn.add_theme_color_override("font_disabled_color", 获取弱文字色())


## 次按钮皮：半透深底 + 描边（幽灵按钮）
## ★ 2026-09-16：几何口径已与纯色平肤归一（见 _按钮皮_归一）⇒ 可逐页互换。
func 应用次按钮皮(btn: BaseButton) -> void:
	var normal: StyleBoxTexture = _按钮皮_归一(取九宫格样式("btn_frame"))
	if normal == null:
		apply_secondary_button_style(btn)
		return
	var pressed: StyleBoxTexture = _按钮皮_归一(取九宫格样式("btn_frame"), 3)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", pressed if pressed != null else normal)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_font_size_override("font_size", FONT_BODY)
	btn.add_theme_color_override("font_color", 获取金文字色())
	btn.add_theme_color_override("font_hover_color", 获取金文字色())
	btn.add_theme_color_override("font_pressed_color", 获取金文字色())
	btn.add_theme_color_override("font_disabled_color", 获取弱文字色())


## 状态角标（右上角金三角 · 非 9-patch，按需显隐）
func 建状态角标(尺寸: float = 36.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = 取九宫格贴图("corner_tab")
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(尺寸, 尺寸)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ─────────────────────────────────────────────────────────────
# ★ P0-3.5 TopBar 组件（二级页统一顶部导航栏）
# 返回 PanelContainer：暗金描边底（card_bg 9-patch）+ 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇。
# 业务页只需一行： parent.add_child(UITheme.建顶栏("坊市", _on_back_pressed))
# 带右侧簇：       parent.add_child(UITheme.建顶栏("功绩堂", _on_back_pressed, [状态标签, 创建按钮], "功绩堂", "说明..."))
# 视觉语言与卡片同源（建卡片容器 的 card_bg 材质），全 51 二级页顶栏一步统一。
const _PAGE_HELP: Dictionary = {
	"宗门时令": "宗门时令记录当旬节气、天象与机缘窗口。\n每逢时令更替，外出历练、坊市贸易、弟子心境皆受牵动。\n留意首页横幅提示，顺势而为可事半功倍。",
	"阵营声望": "阵营声望反映本宗在修真界各势力间的立场与名望。\n声望高低影响可承接的委托、可购入的珍稀物资与盟友支援。",
	"碎片 & 宝箱": "历练、论道、破解遗迹可得残卷碎片；集齐可合成功法、灵兽或灵宝图录。\n宝箱藏有随机机缘，开箱前留意所需钥匙或灵石。",
	"宗门战": "宗门战为宗门间的实力角逐，按赛季结算排名。\n胜者得气运、灵石与珍稀战功赏赐，败者折损威望。\n出战前须妥善排布弟子战阵与符箓。",
	"宗主管理": "宗主管理：任免司职、调配弟子、裁定宗务。\n你是宗门中枢，多数事务由弟子依职自动运转，你只需决策与裁决。",
	"宗务": "宗务：统筹宗门日常运转的待办与奏报。\n司职弟子会定期呈报请示，你只需审阅并裁决，不必亲力亲为。",
	"日供": "日供：宗门每日例行的灵石、灵气、物资供给与消耗结算。\n由司职弟子自动打理，可在殿阁总览中查看产出明细。",
}

# 通用「?」帮助按钮：点按经 UIHint 弹出系统简介。零玩法/战斗触碰。
func make_help_button(标题: String, 正文: String) -> Button:
	var b := Button.new()
	b.name = "HelpBtn"
	b.text = "?"
	b.flat = true
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_project_font(b, int(round(24.0 * UI_SCALE)), true)
	b.add_theme_color_override("font_color", 获取金文字色())
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = 获取金文字色()
	sb.set_corner_radius_all(999)
	sb.set_border_width_all(int(round(2.0 * UI_SCALE)))
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(func(): UIHint.show_hint(b, 标题, 正文))
	return b

func 建顶栏(标题: String, 返回回调: Callable, 右侧: Array = [], 提示标题: String = "", 提示文本: String = "", help_key: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "TopBar"
	var sb: StyleBox = 取九宫格样式("card_bg")
	if sb == null:
		sb = _patch_flat("card_bg")
	panel.add_theme_stylebox_override("panel", sb)
	var bar := HBoxContainer.new()
	bar.name = "Bar"
	bar.add_theme_constant_override("separation", GRID)
	bar.custom_minimum_size = Vector2(0, SIZE_SM)
	panel.add_child(bar)
	var back: Button = make_back_button(返回回调)
	bar.add_child(back)
	var title := Label.new()
	title.name = "Title"
	title.text = 标题
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_page_title(title)
	if 提示标题 != "" and 提示文本 != "":
		title.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				UIHint.show_hint(title, 提示标题, 提示文本))
	bar.add_child(title)
	# ★ 2026-09-15 修：原 `bar.add_spacer(true)` 会把 spacer 插到**索引 0**（内部
	#   move_child(spacer,0)），与 title 各分一半伸缩空间 ⇒ 返回键被顶到屏幕中部，
	#   全站二级页返回键都不在左上角。title 自身已 EXPAND_FILL，无需 spacer。
	# 帮助栏：显式 提示标题/提示文本 优先；否则按标题查 _PAGE_HELP；皆无则不显示。
	var help_title: String = 提示标题
	var help_body: String = 提示文本
	if help_body == "":
		help_body = _PAGE_HELP.get(标题, "")
		help_title = 标题 if help_body != "" else ""
	var rhs: Array = 右侧.duplicate()
	if help_body != "":
		rhs.append(make_help_button(help_title if help_title != "" else 标题, help_body))
	for c in rhs:
		if c is Control:
			bar.add_child(c)
	return panel

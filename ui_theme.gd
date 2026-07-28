# ui_theme.gd — 《太玄宗门录》S1 UI 主题模块（Autoload: UITheme）
# 铁律：业务 UI 一律调用本模块，组件内禁止硬编码颜色/尺寸。
# 依据：design/06-角色与UI/UI交互规范_古风经营A版_V1.0.md §2~§4、§7
extends Node

# ───────── 色彩 token ─────────
const COLOR_BG_BASE: Color = Color(0.110, 0.149, 0.157)       # 暗青黛 底色
const COLOR_PANEL_BG: Color = Color(0.137, 0.176, 0.180)      # 面板暗纹底（占位色，待美术暗纹贴图）
const COLOR_STATUSBAR_BG: Color = Color(0.055, 0.082, 0.090)  # 状态栏/墨底
const COLOR_BORDER_GOLD: Color = Color(0.784, 0.659, 0.416)   # 暗金 描边/标题
const COLOR_TEXT_GOLD: Color = Color(0.941, 0.808, 0.420)     # 亮金 核心数值（正常）
const COLOR_TEXT_RED: Color = Color(0.545, 0.227, 0.227)      # 暗红 异常（负值/预警）
const COLOR_TEXT_BODY: Color = Color(0.910, 0.878, 0.808)     # 浅米 正文
const COLOR_TEXT_AUX: Color = Color(0.659, 0.659, 0.627)      # 浅灰 辅助
const COLOR_BTN_PRESSED: Color = Color(0.078, 0.106, 0.110)   # 主按钮按下态 底色加深
const COLOR_BTN_DISABLED: Color = Color(0.180, 0.196, 0.196)  # 主按钮禁用态

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
const TAB_H: int = 64
const TOPBAR_H: int = 48
const OVERVIEW_H: int = 120
const CORE_GRID_H: int = 240

# ───────── 字号 ─────────
const FONT_TITLE: int = 24
const FONT_VALUE: int = 18
const FONT_BODY: int = 16
const FONT_AUX: int = 12

# ───────── 美术资产路径（图标 / 贴图 / 字体 · 集中管理）─────────
# 集中管理 res:// 资源位置；改皮 / 换套仅动本节，组件零硬编码（保持单文件样式管理）。
const ASSET_DIR: String = "res://ui/assets/"
const ICON_DIR: String = ASSET_DIR + "icons/"
const PANEL_INK_TEX: String = ASSET_DIR + "panel_ink.svg"
const DIVIDER_TEX: String = ASSET_DIR + "divider_cloud.svg"
# 字体路径：当前环境无法下载，故保留占位常量；放入字体文件后即被 apply_fonts() / apply_*_font 拾取。
# 注：FONT_TITLE / FONT_BODY 已被上方字号 int 占用 → 路径常量命名 *_PATH 以示区别。
const FONT_TITLE_PATH: String = ASSET_DIR + "fonts/MaShanZheng-Regular.ttf"
const FONT_BODY_PATH: String = ASSET_DIR + "fonts/NotoSerifSC-Regular.otf"

# 中文 label → 图标文件 stem（不含扩展名）。组件按其 Chinese 标签取图，统一线稿风格（§3.1）。
const ICON_BY_LABEL: Dictionary = {
	"建筑": "jianyu",
	"坊市": "suanpan",
	"修炼": "danhuo",
	"洞府": "shandong",
	"任务": "juanshu",
	"账册": "boce",
	"宗门": "zongmen",
	"弟子": "dizi",
	"历练": "lilian",
	"纪事": "jishi",
	"灵石": "lingshi",
	"灵气": "lingqi",
	"时辰": "shichen",
	"推演时日": "rili",
	"折叠": "chevron",
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
# 核心数值：正常亮金 / 异常暗红
func color_value(abnormal: bool) -> Color: return COLOR_TEXT_RED if abnormal else COLOR_TEXT_GOLD

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

func apply_title_font(label: Label) -> void:
	_ensure_fonts()
	label.add_theme_font_size_override("font_size", FONT_TITLE)
	label.add_theme_color_override("font_color", COLOR_BORDER_GOLD)
	if _font_title_res != null:
		label.add_theme_font_override("font", _font_title_res)

func apply_value_font(label: Label, abnormal: bool = false) -> void:
	_ensure_fonts()
	label.add_theme_font_size_override("font_size", FONT_VALUE)
	label.add_theme_color_override("font_color", color_value(abnormal))
	if _font_body_res != null:
		label.add_theme_font_override("font", _font_body_res)

func apply_body_font(label: Label) -> void:
	_ensure_fonts()
	label.add_theme_font_size_override("font_size", FONT_BODY)
	label.add_theme_color_override("font_color", COLOR_TEXT_BODY)
	if _font_body_res != null:
		label.add_theme_font_override("font", _font_body_res)

func apply_aux_font(label: Label) -> void:
	_ensure_fonts()
	label.add_theme_font_size_override("font_size", FONT_AUX)
	label.add_theme_color_override("font_color", COLOR_TEXT_AUX)
	if _font_body_res != null:
		label.add_theme_font_override("font", _font_body_res)

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
			sb_t.set_margin_all(RADIUS_PANEL + 8)
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
		sb_t.set_margin_all(2)
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
# Godot 4 原生支持 .svg 导入为 Texture2D；load() 内部按路径缓存结果，重复调用成本极低。
func load_icon(label: String) -> Texture2D:
	var stem: String = ICON_BY_LABEL.get(label, "")
	if stem == "":
		return null
	return load(ICON_DIR + stem + ".svg") as Texture2D

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

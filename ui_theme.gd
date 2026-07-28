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
func apply_title_font(label: Label) -> void:
	label.add_theme_font_size_override("font_size", FONT_TITLE)
	label.add_theme_color_override("font_color", COLOR_BORDER_GOLD)

func apply_value_font(label: Label, abnormal: bool = false) -> void:
	label.add_theme_font_size_override("font_size", FONT_VALUE)
	label.add_theme_color_override("font_color", color_value(abnormal))

func apply_body_font(label: Label) -> void:
	label.add_theme_font_size_override("font_size", FONT_BODY)
	label.add_theme_color_override("font_color", COLOR_TEXT_BODY)

func apply_aux_font(label: Label) -> void:
	label.add_theme_font_size_override("font_size", FONT_AUX)
	label.add_theme_color_override("font_color", COLOR_TEXT_AUX)

# ───────── 面板（圆角8 / 1px暗金描边 / 暗纹底占位 / 内边距16）─────────
func make_panel_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL_BG
	sb.border_color = COLOR_BORDER_GOLD
	sb.set_corner_radius_all(RADIUS_PANEL)
	sb.set_border_width_all(BORDER_W)
	sb.set_content_margin_all(PAD_PANEL)
	# 水墨暗纹底：占位标记，待美术提供暗纹贴图后改用 texture / set_texture_margin
	return sb

func apply_panel_style(control: Control) -> void:
	# 作用于 Panel / PanelContainer 的 "panel" 样式；其余容器请包裹 PanelContainer
	control.add_theme_stylebox_override("panel", make_panel_stylebox())

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

# ───────── 分割线（1px 暗金云纹占位）─────────
func make_divider_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BORDER_GOLD
	sb.set_content_margin_all(0)
	return sb

# 返回一条 1px 暗金分割线控件（直接挂到容器即可）
func make_divider_control() -> Control:
	var c := ColorRect.new()
	c.color = COLOR_BORDER_GOLD
	c.custom_minimum_size = Vector2(0, BORDER_W)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func apply_divider(control: Control) -> void:
	control.add_theme_stylebox_override("panel", make_divider_stylebox())

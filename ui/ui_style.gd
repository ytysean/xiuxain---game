extends RefCounted
class_name UIStyle

# ===== 字体大小统一配置 =====
# 标题字体（页面大标题）
const FONT_SIZE_TITLE: int = 28
# 副标题字体（区域标题）
const FONT_SIZE_SUBTITLE: int = 22
# 正文字体（普通文本）
const FONT_SIZE_BODY: int = 18
# 小字字体（辅助说明、标签）
const FONT_SIZE_SMALL: int = 14
# 极小字体（角标、提示）
const FONT_SIZE_TINY: int = 12

# ===== 颜色统一配置 =====
# 主色调（太虚蓝）
const COLOR_PRIMARY: Color = Color(0.2, 0.4, 0.8, 1.0)
# 次要色调（金色）
const COLOR_SECONDARY: Color = Color(0.9, 0.75, 0.3, 1.0)
# 成功色（绿色）
const COLOR_SUCCESS: Color = Color(0.2, 0.7, 0.3, 1.0)
# 警告色（橙色）
const COLOR_WARNING: Color = Color(0.95, 0.6, 0.1, 1.0)
# 危险色（红色）
const COLOR_DANGER: Color = Color(0.85, 0.2, 0.2, 1.0)
# 信息色（蓝色）
const COLOR_INFO: Color = Color(0.25, 0.55, 0.9, 1.0)
# 文本主色（深灰）
const COLOR_TEXT_PRIMARY: Color = Color(0.15, 0.15, 0.18, 1.0)
# 文本次色（中灰）
const COLOR_TEXT_SECONDARY: Color = Color(0.45, 0.45, 0.5, 1.0)
# 文本提示色（浅灰）
const COLOR_TEXT_HINT: Color = Color(0.65, 0.65, 0.7, 1.0)
# 背景色（米白）
const COLOR_BACKGROUND: Color = Color(0.96, 0.95, 0.92, 1.0)
# 卡片背景色（白色）
const COLOR_CARD: Color = Color(1.0, 1.0, 1.0, 1.0)
# 边框色（浅灰）
const COLOR_BORDER: Color = Color(0.85, 0.85, 0.88, 1.0)

# ===== 间距统一配置 =====
# 超小间距（元素内部）
const SPACING_TINY: int = 4
# 小间距（紧密元素）
const SPACING_SMALL: int = 8
# 中间距（普通元素）
const SPACING_MEDIUM: int = 12
# 大间距（区域分隔）
const SPACING_LARGE: int = 16
# 超大间距（页面边距）
const SPACING_HUGE: int = 24

# ===== 圆角统一配置 =====
# 小圆角（按钮、标签）
const CORNER_RADIUS_SMALL: int = 4
# 中圆角（卡片、输入框）
const CORNER_RADIUS_MEDIUM: int = 8
# 大圆角（弹窗、面板）
const CORNER_RADIUS_LARGE: int = 12
# 超大圆角（头像、特殊元素）
const CORNER_RADIUS_HUGE: int = 20

# ===== 阴影统一配置 =====
# 小阴影（按钮悬停）
const SHADOW_SMALL: int = 4
# 中阴影（卡片）
const SHADOW_MEDIUM: int = 8
# 大阴影（弹窗）
const SHADOW_LARGE: int = 16

# ===== 动画时长统一配置 =====
# 快速动画（按钮反馈）
const ANIMATION_FAST: float = 0.1
# 中速动画（页面切换）
const ANIMATION_MEDIUM: float = 0.2
# 慢速动画（特殊效果）
const ANIMATION_SLOW: float = 0.3

# ===== 工具函数 =====
# 创建统一风格的按钮
static func create_button(text: String, font_size: int = FONT_SIZE_BODY) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", COLOR_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", COLOR_PRIMARY)
	btn.add_theme_stylebox_override("normal", _create_stylebox(COLOR_CARD, COLOR_BORDER, CORNER_RADIUS_SMALL, 1))
	btn.add_theme_stylebox_override("hover", _create_stylebox(COLOR_PRIMARY.lightened(0.9), COLOR_PRIMARY, CORNER_RADIUS_SMALL, 1))
	btn.add_theme_stylebox_override("pressed", _create_stylebox(COLOR_PRIMARY.lightened(0.8), COLOR_PRIMARY, CORNER_RADIUS_SMALL, 1))
	btn.add_theme_stylebox_override("disabled", _create_stylebox(COLOR_BACKGROUND, COLOR_BORDER, CORNER_RADIUS_SMALL, 1))
	return btn

# 创建统一风格的标签
static func create_label(text: String, font_size: int = FONT_SIZE_BODY, color: Color = COLOR_TEXT_PRIMARY) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

# 创建统一风格的卡片面板
static func create_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _create_stylebox(COLOR_CARD, COLOR_BORDER, CORNER_RADIUS_MEDIUM, 1, SHADOW_MEDIUM))
	return panel

# 创建样式框（内部工具函数）
static func _create_stylebox(bg_color: Color, border_color: Color, corner_radius: int, border_width: int = 1, shadow: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	if shadow > 0:
		style.shadow_color = Color(0, 0, 0, 0.15)
		style.shadow_size = shadow
		style.shadow_offset = Vector2(0, 2)
	return style

# 应用统一字体大小到节点及其子节点
static func apply_unified_font(node: Node, font_size: int = FONT_SIZE_BODY) -> void:
	if node is Label:
		node.add_theme_font_size_override("font_size", font_size)
	elif node is Button:
		node.add_theme_font_size_override("font_size", font_size)
	elif node is LineEdit:
		node.add_theme_font_size_override("font_size", font_size)
	elif node is RichTextLabel:
		node.add_theme_font_size_override("normal_font_size", font_size)
	for child in node.get_children():
		apply_unified_font(child, font_size)

# 添加按钮点击反馈（缩放效果）
static func add_button_feedback(button: Button) -> void:
	button.button_down.connect(func():
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2(0.95, 0.95), ANIMATION_FAST)
	)
	button.button_up.connect(func():
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), ANIMATION_FAST)
	)
	button.mouse_exited.connect(func():
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), ANIMATION_FAST)
	)

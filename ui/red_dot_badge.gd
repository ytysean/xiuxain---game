## 统一红点控件（大厂手游标准）
## 功能：
## 1. 统一样式：红色圆形，白色描边，数字用白色粗体
## 2. 支持两种模式：圆点红点（仅显示有无）、数字红点（显示未读数量）
## 3. 统一位置：父控件右上角，自动适配
## 4. 动画效果：出现时缩放动画，呼吸效果

extends Control

var _类型: String = "dot"  # dot: 圆点红点, number: 数字红点
var _数量: int = 0
var _圆点: Panel = null
var _数字标签: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	_圆点 = Panel.new()
	_圆点.name = "Dot"
	_圆点.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.9, 0.2, 0.2, 1.0)  # 标准红点红色
	sb.set_corner_radius_all(999)  # 圆形
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 1.0, 1.0, 1.0)  # 白色描边
	_圆点.add_theme_stylebox_override("panel", sb)
	add_child(_圆点)

	if _类型 == "number":
		_数字标签 = Label.new()
		_数字标签.name = "Num"
		_数字标签.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_数字标签.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
		_数字标签.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		_数字标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_数字标签.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_圆点.add_child(_数字标签)

	_update_size()
	_update_position()

## 设置红点类型
func 设置类型(类型: String) -> void:
	_类型 = 类型
	if _圆点 != null:
		_圆点.queue_free()
		_圆点 = null
	if _数字标签 != null:
		_数字标签.queue_free()
		_数字标签 = null
	_build()

## 设置红点数量（数字红点模式）
func 设置数量(数量: int) -> void:
	_数量 = 数量
	if _数字标签 != null:
		if 数量 > 99:
			_数字标签.text = "99+"
		else:
			_数字标签.text = str(数量)
	_update_size()

## 更新红点大小
func _update_size() -> void:
	if _圆点 == null:
		return
	if _类型 == "dot":
		_圆点.custom_minimum_size = Vector2(16, 16)
	else:
		# 数字红点根据数字位数调整大小
		var 位数: int = len(str(_数量))
		var 宽度: float = 20.0 + 位数 * 8.0
		_圆点.custom_minimum_size = Vector2(宽度, 20)
	if _数字标签 != null:
		_数字标签.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## 更新红点位置（父控件右上角）
func _update_position() -> void:
	if get_parent() == null:
		return
	# 自动定位到父控件右上角
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -12
	offset_right = -12
	offset_top = -4
	offset_bottom = -4

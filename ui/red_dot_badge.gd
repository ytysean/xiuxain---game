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
	# ★ 必须判空再建：设置类型() 可能在入树前被调用（如 page_chronicle 的
	#   new → 设置类型 → add_child），那时它已经 _build() 过一次；此处若无条件再 _build()
	#   会叠出**两个** Dot 子节点，两个圆点错位重叠 —— 红点看起来「脏」「位置怪」的真因。
	if _圆点 == null:
		_build()
	# 与 ui_theme.make_red_dot* 共用同一套显隐动效（弹入 + 呼吸）。
	# 此前本控件文件头注释写了「出现时缩放动画，呼吸效果」但**一行都没实现** ——
	# 首页快捷栏/纪事/殿阁的红点全是硬切出现，正是「红点显得廉价」的直接来源。
	UITheme.挂红点动效(self)

func _build() -> void:
	_圆点 = Panel.new()
	_圆点.name = "Dot"
	_圆点.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	# 2026-09-16：配色改从 UITheme 取（**单一来源**）。此前本文件与 ui_theme.make_red_dot*
	# 各写一份颜色，导致同屏两种红点观感不一致。深玄描边 + 外发光理由见 ui_theme.RED_DOT_*。
	sb.bg_color = UITheme.RED_DOT_COLOR
	sb.set_corner_radius_all(999)  # 圆形
	# 微信/原生角标规格：纯色实心、无描边、无外发光。
	# 旧值（2px 深玄描边 + 2px 暗色外发光）在深色玻璃面板上把红点"收"暗了，
	# 在亮色山水背景上则呈现一圈脏灰 —— 双向削弱辨识度，与「一眼看见」正相反。
	sb.set_border_width_all(0)
	sb.border_color = UITheme.RED_DOT_BORDER
	sb.shadow_color = UITheme.RED_DOT_GLOW
	sb.shadow_size = 0
	_圆点.add_theme_stylebox_override("panel", sb)
	add_child(_圆点)

	if _类型 == "number":
		_数字标签 = Label.new()
		_数字标签.name = "Num"
		_数字标签.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.apply_project_font(_数字标签, UITheme.FONT_TITLE, true)
		_数字标签.add_theme_color_override("font_color", Color.WHITE)
		# 去描边后靠字号撑可读性；字缘用极细深红描边防糊（非视觉描边）
		_数字标签.add_theme_color_override("font_outline_color", UITheme.RED_DOT_TEXT_EDGE)
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
	var 变: bool = 数量 != _数量
	_数量 = 数量
	if _数字标签 != null:
		if 数量 > 99:
			_数字标签.text = "99+"
		else:
			_数字标签.text = str(数量)
	_update_size()
	if 变 and is_visible_in_tree():
		UITheme.红点脉冲(self)   # 数量动了跳一下 = 「又有新的了」，与出场弹入语义区分

## 更新红点大小
func _update_size() -> void:
	if _圆点 == null:
		return
	# 尺寸一律 ×UI_SCALE：本控件的父是任意 Control 且用 anchor/offset 定位 ⇒ 走**节点单位**，
	# 而 16/20 是设计逻辑值（与 ui_theme.make_red_dot* 的调用方口径一致），不换算会小 2.25 倍。
	var s: float = UITheme.UI_SCALE
	var 尺寸: Vector2
	if _类型 == "dot":
		尺寸 = Vector2(16, 16) * s
	else:
		# 数字红点根据数字位数调整大小（胶囊：高固定、宽随位数）
		var 位数: int = len(_数字标签.text) if _数字标签 != null else len(str(_数量))
		var 高度: float = 20.0 * s
		尺寸 = Vector2(maxf(高度, 高度 * 0.62 * float(位数) + 高度 * 0.52), 高度)
	_圆点.custom_minimum_size = 尺寸
	# ★ 2026-09-16 修根因：裸 Control 下 custom_minimum_size 不参与布局，旧代码只设 minimum
	#   ⇒ 红点实际尺寸恒为 0（只靠子节点溢出才看得见，位置与形状都不可控）。
	_圆点.size = 尺寸
	# 描边/发光/字号随实际尺寸换算 —— 与 ui_theme.make_red_dot* 用同一套几何规则。
	var sb: StyleBoxFlat = _圆点.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.set_border_width_all(0)   # 同 _build：纯色实心，描边归零
		sb.shadow_size = 0           # 同 _build：无外发光
	if _数字标签 != null:
		_数字标签.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_数字标签.add_theme_font_size_override("font_size", int(round(尺寸.y * 0.66)))
		_数字标签.add_theme_constant_override("outline_size", maxi(1, int(round(尺寸.y * 0.14))))
	_update_position()

## 更新红点位置（父控件右上角）
func _update_position() -> void:
	if get_parent() == null or _圆点 == null:
		return
	# 自动定位到父控件右上角。
	# ★ 2026-09-16 修根因：旧代码把 offset_left 与 offset_right 都写成 -12 —— 在
	#   PRESET_TOP_RIGHT 下「宽度 = offset_right - offset_left」恒为 0，红点尺寸与落点都不可控
	#   （只靠子节点溢出才看得见）。现按红点实际尺寸计算，使红点约 60% 压进父控件、
	#   40% 外溢「咬」住边角 —— 大厂数字角标的通行落点。
	var sz: Vector2 = _圆点.size
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_right = sz.x * 0.4
	offset_left = offset_right - sz.x
	offset_bottom = sz.y * 0.4
	offset_top = offset_bottom - sz.y
	# 缩放动画必须绕自身中心（anchor/offset 定位不受 scale 影响，轴心不会自己落对）。
	# pivot 相对**本控件**：其 size 已由上面四个 offset 定成红点尺寸，故直接用 sz。
	pivot_offset = sz * 0.5

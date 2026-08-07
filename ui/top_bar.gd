extends Control

# 顶部信息条（截图还原版：双行布局）。
# Row1 = 头像 + 宗门名 + Lv徽章 | 日期
# Row2 = 5资源大横栏（灵石/灵气/灵植/声望/仙玉）
# 本脚本只负责：样式应用 + 资源数值刷新 + 日期刷新。
# S1 红线：首页不显示设置/调试类入口；资源数值只读 Game Autoload，绝不写 GameState。

signal time_advance_requested

# 5 资源槽（截图中的横排顺序）
const RESOURCES: Array = [
	{"name": "灵石", "field": "灵石"},
	{"name": "灵气", "field": "灵气"},
	{"name": "灵植", "field": "灵草"},
	{"name": "声望", "field": "声望"},
	{"name": "仙玉", "field": "仙玉_绑定"},
]

var _res_values: Dictionary = {}   # name -> 数值 Label
var _unit_labels: Dictionary = {}  # name -> 单位 Label

func _ready() -> void:
	_apply_theme()
	_bind_values()
	refresh_resources()
	refresh_date()

func _apply_theme() -> void:
	# ── Row1: 信息栏样式 ──
	var sect_name: Label = get_node_or_null("InfoBar/SectName")
	if sect_name != null:
		UITheme.apply_title_font_sized(sect_name, 20)
		sect_name.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)

	var lv_label: Label = get_node_or_null("InfoBar/LvLabel")
	if lv_label != null:
		UITheme.apply_body_font_sized(lv_label, 14)
		lv_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)

	var avatar_lbl: Label = get_node_or_null("InfoBar/AvatarLabel")
	if avatar_lbl != null:
		UITheme.apply_aux_font(avatar_lbl)
		avatar_lbl.add_theme_font_size_override("font_size", 11)
		avatar_lbl.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))  # 局部微色·保留：头像名中性灰 #999485（比 COLOR_TEXT_AUX #8A7E68 更亮更中性，非 token）

	var date_lbl: Label = get_node_or_null("InfoBar/DateLabel")
	if date_lbl != null:
		UITheme.apply_body_font_sized(date_lbl, 14)
		date_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE2)

	# ── Row2: 资源栏样式 ──
	for cfg in RESOURCES:
		var val: Label = get_node_or_null("ResBar/Res_" + cfg["name"] + "/Val_" + cfg["name"])
		if val != null:
			UITheme.apply_value_font(val, false)
			val.add_theme_font_size_override("font_size", 22)
			val.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))  # 局部微色·保留：资源数值高亮暖白 #FFFAEB（刻意亮于 COLOR_TEXT_TITLE2 #F0E6D2，非 token）
		var unit: Label = get_node_or_null("ResBar/Res_" + cfg["name"] + "/Unit_" + cfg["name"])
		if unit != null:
			UITheme.apply_aux_font(unit)
			unit.add_theme_font_size_override("font_size", 13)
			unit.add_theme_color_override("font_color", Color(0.72, 0.68, 0.55))  # 局部微色·保留：单位后缀暗米 #B8AD8C（刻意暗于 COLOR_TEXT_BODY_DIM #C8B896，非 token）
		var icon: TextureRect = get_node_or_null("ResBar/Res_" + cfg["name"] + "/Icon_" + cfg["name"])
		if icon != null:
			icon.modulate = Color(1.0, 1.0, 1.0, 1.0)  # 局部微色·保留：图标 modulate 恒等（不染色），非 token

func _bind_values() -> void:
	for cfg in RESOURCES:
		var val: Label = get_node_or_null("ResBar/Res_" + cfg["name"] + "/Val_" + cfg["name"])
		if val != null:
			_res_values[cfg["name"]] = val
		var unit: Label = get_node_or_null("ResBar/Res_" + cfg["name"] + "/Unit_" + cfg["name"])
		if unit != null:
			_unit_labels[cfg["name"]] = unit

# S1 红线：首页不显示设置/调试类入口。main.gd 已不再调用本函数，保留以兼容旧调用。
func add_right_control(control: Control) -> void:
	pass

# 只读刷新资源数值（从 Game Autoload 取值，万缀格式化；绝不写 GameState）。
func refresh_resources() -> void:
	if not is_instance_valid(Game):
		return
	for cfg in RESOURCES:
		var raw: Variant = Game.get(cfg["field"])
		var v: int = 0
		if raw != null:
			v = int(raw)
		_set_value(cfg["name"], _format_resource_value(v), _format_unit(v))

# 刷新日期显示（从 Game 取年/月）
func refresh_date() -> void:
	if not is_instance_valid(Game):
		return
	var date_lbl: Label = get_node_or_null("InfoBar/DateLabel")
	if date_lbl == null:
		return
	var 年: Variant = Game.get("年")
	var 月: Variant = Game.get("月")
	var 年文本: String = "太玄"
	var 月文本: String = ""
	if 年 != null:
		年文本 = "太玄" + str(int(年))
	if 月 != null:
		月文本 = str(int(月)) + "月"
	date_lbl.text = 年文本 + 月文本

func _set_value(name: String, val_text: String, unit_text: String) -> void:
	var lbl: Label = _res_values.get(name, null)
	if lbl != null:
		lbl.text = val_text
	var unit: Label = _unit_labels.get(name, null)
	if unit != null:
		unit.text = unit_text

# 格式化数值：>=10000 显示为 X.X，否则显示原值
func _format_resource_value(v: int) -> String:
	if v >= 10000:
		return "%0.1f" % (float(v) / 10000.0)
	else:
		return str(v)

# 格式化单位：>=10000 显示"万"，否则空字符串
func _format_unit(v: int) -> String:
	if v >= 10000:
		return "万"
	return ""

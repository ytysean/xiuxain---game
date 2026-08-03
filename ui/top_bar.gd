extends Control

# 顶部信息条（编辑器静态场景版）。
# 所有节点在 top_bar.tscn 里摆好，可在 Godot 编辑器直接拖/改。
# 本脚本只负责：样式应用 + 资源数值刷新。
# S1 红线：首页不显示设置/调试类入口；资源数值只读 Game Autoload，绝不写 GameState。

signal time_advance_requested

# 4 资源槽：显示名、Game 字段名
const RESOURCES: Array = [
	{"name": "灵石", "field": "灵石"},
	{"name": "灵气", "field": "灵气"},
	{"name": "灵植", "field": "灵草"},
	{"name": "声望", "field": "声望"},
]

var _res_labels: Dictionary = {}   # name -> 数值 Label

func _ready() -> void:
	_apply_theme()
	_bind_values()
	refresh_resources()

func _apply_theme() -> void:
	var capsule: Panel = get_node_or_null("Capsule")
	if capsule != null:
		UITheme.apply_topbar_capsule_style(capsule)
	var title: Label = get_node_or_null("Capsule/Title")
	if title != null:
		UITheme.apply_title_font_sized(title, 30)
		title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)
	for cfg in RESOURCES:
		var name_lbl: Label = get_node_or_null("Capsule/Name_" + cfg["name"])
		if name_lbl != null:
			UITheme.apply_aux_font(name_lbl)
			name_lbl.add_theme_font_size_override("font_size", 14)
			name_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
		var val: Label = get_node_or_null("Capsule/Value_" + cfg["name"])
		if val != null:
			UITheme.apply_value_font(val, false)
			val.add_theme_font_size_override("font_size", 18)
			val.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)
		var icon: TextureRect = get_node_or_null("Capsule/Icon_" + cfg["name"])
		if icon != null:
			icon.modulate = Color.WHITE

func _bind_values() -> void:
	for cfg in RESOURCES:
		var val: Label = get_node_or_null("Capsule/Value_" + cfg["name"])
		if val != null:
			_res_labels[cfg["name"]] = val

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
		_set_value(cfg["name"], UITheme.format_resource(v))

func _set_value(name: String, text: String) -> void:
	var lbl: Label = _res_labels.get(name, null)
	if lbl == null:
		return
	lbl.text = text

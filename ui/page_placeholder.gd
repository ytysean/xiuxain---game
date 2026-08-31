extends Control

# 占位二级页：暂无真实系统的入口统一跳转到这里，显示「系统即将开放」并支持返回。
# 纯 UI 展示，零 GameState 写入。

signal 返回主页

var _built: bool = false
var _system_name: String = ""

func _ready() -> void:
	_build()

func set_system_name(name: String) -> void:
	_system_name = name
	if _built:
		_refresh()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	_build_header(vbox)

	var center := CenterContainer.new()
	center.name = "Center"
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(center)

	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.add_theme_constant_override("separation", UITheme.GRID)
	center.add_child(inner)

	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_page_title(title)
	inner.add_child(title)

	var hint := Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "系统即将开放，敬请期待"
	UITheme.apply_aux_text(hint)
	inner.add_child(hint)

	_refresh()

func _build_header(parent: Control) -> void:
	UITheme.make_page_header(parent, "", _on_back_pressed)

func _refresh() -> void:
	var title: Label = get_node_or_null("Root/Center/Inner/Title")
	if title != null:
		title.text = _system_name if not _system_name.is_empty() else "占位"

func _on_back_pressed() -> void:
	返回主页.emit()

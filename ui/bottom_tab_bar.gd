extends Control

# 底部主导航（§7.1：固定底部 64dp，5-Tab 左->右 宗门/弟子/建筑/历练/纪事）。
# 选中态 = 暗金文字 + 细下划线（ColorRect）。仅发信号 tab_selected(tab_id)。

signal tab_selected(tab_id: String)

const TABS: Array = ["宗门", "弟子", "建筑", "历练", "纪事"]

var _buttons: Array = []
var _underlines: Array = []
var _selected: String = ""

func _ready() -> void:
	_build()
	select(TABS[0])

func _build() -> void:
	custom_minimum_size = Vector2(0, UITheme.TAB_H)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)

	var hbox := HBoxContainer.new()
	hbox.name = "Tabs"
	add_child(hbox)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for id in TABS:
		var btn := Button.new()
		btn.name = "Tab_" + id
		btn.text = id
		btn.flat = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, UITheme.TAB_H)
		btn.set_meta("tab_id", id)
		var ul := ColorRect.new()
		ul.name = "Underline"
		ul.color = UITheme.COLOR_BORDER_GOLD
		ul.custom_minimum_size = Vector2(0, UITheme.BORDER_W)
		ul.size_flags_vertical = Control.SIZE_SHRINK_END
		ul.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(ul)
		btn.pressed.connect(_on_tab_pressed.bind(id))
		hbox.add_child(btn)
		_buttons.append(btn)
		_underlines.append(ul)

func select(tab_id: String) -> void:
	_selected = tab_id
	for i in range(_buttons.size()):
		var id: String = _buttons[i].get_meta("tab_id", "")
		var sel: bool = (id == tab_id)
		UITheme.apply_tab_style(_buttons[i], sel)
		_underlines[i].visible = sel

func get_selected() -> String:
	return _selected

func _on_tab_pressed(tab_id: String) -> void:
	select(tab_id)
	tab_selected.emit(tab_id)

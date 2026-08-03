extends Control

# 底部主导航（编辑器静态场景版 · 切图重皮 + 编辑器对位路线）。
# 布局节点全部在 bottom_tab_bar.tscn 里摆好（可在 Godot 编辑器直接拖/改），
# 本脚本只负责：连接点击信号 + 选中态样式切换（图标/文字变色 + 下划线显隐）。
# 红线：零玩法逻辑，仅 UI 展示。

signal tab_selected(tab_id: String)

const TABS: Array = ["宗门", "弟子", "殿阁", "历练", "纪事"]
const TAB_FONT_SIZE: int = 14

# Tab 中文名 → ui_theme.gd 图标 label 映射
const TAB_ICON_LABEL: Dictionary = {
	"宗门": "宗门",
	"弟子": "弟子",
	"殿阁": "殿阁",
	"历练": "历练",
	"纪事": "纪事",
}

var _selected: String = ""

func _ready() -> void:
	for id in TABS:
		var btn: Control = get_node_or_null("Tab_" + id)
		if btn != null:
			btn.pressed.connect(_on_tab_pressed.bind(id))
	select(TABS[0])

func _get_parts(id: String) -> Dictionary:
	var btn: Control = get_node_or_null("Tab_" + id)
	if btn == null:
		return {}
	return {
		"icon": btn.get_node_or_null("Icon"),
		"label": btn.get_node_or_null("Label"),
		"underline": btn.get_node_or_null("Underline"),
	}

func select(tab_id: String) -> void:
	_selected = tab_id
	for id in TABS:
		var p: Dictionary = _get_parts(id)
		if p.is_empty():
			continue
		var sel: bool = (id == tab_id)
		var color: Color = UITheme.COLOR_TEXT_TITLE1 if sel else UITheme.COLOR_TAB_UNSELECTED
		var lbl: Label = p["label"]
		if lbl != null:
			UITheme.apply_title_font_sized(lbl, TAB_FONT_SIZE)
			lbl.add_theme_color_override("font_color", color)
		var icon: TextureRect = p["icon"]
		if icon != null:
			icon.modulate = color
			var icon_label: String = TAB_ICON_LABEL.get(id, "")
			var new_tex: Texture2D = UITheme.load_tab_icon(icon_label, sel)
			if new_tex != null:
				icon.texture = new_tex
		var ul: ColorRect = p["underline"]
		if ul != null:
			ul.visible = sel

func get_selected() -> String:
	return _selected

func _on_tab_pressed(tab_id: String) -> void:
	select(tab_id)
	tab_selected.emit(tab_id)

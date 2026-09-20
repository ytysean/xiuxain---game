extends Control

# 闲情雅趣（GameUI 二级页）：休闲玩法总目录（UX 总纲 §11 R3）
# 七般雅趣直跳：灵钓 / 探遗迹 / 饲灵育兽 / 卜算星盘 / 药圃经营 / 论道棋弈 / 入山采撷
# 跳转机制：emit 雅趣请求(id) → GameUI._open_雅趣 按 ENTRY_SUB_PAGES 打开对应二级页。
# 设计定位（§5.9）：休闲＝宗门生活本身，不给打卡任务，产出以道心/感悟/图录等软价值为主。
# 颜色一律走 UITheme 真实 const，禁硬编码。

signal 返回主页
signal 雅趣请求(id: String)


# id 与 game_ui.ENTRY_SUB_PAGES 的键硬绑定（改名须同步两处）。
const 雅趣表: Array = [
	{"id": "灵钓", "名": "灵渊垂钓", "述": "单指收线，钓尽灵渊奇物"},
	{"id": "探遗迹", "名": "探遗迹", "述": "参悟古阵，寻访上古遗秘"},
	{"id": "饲灵育兽", "名": "饲灵育兽", "述": "饲育灵兽，结契约之缘"},
	{"id": "卜算星盘", "名": "卜算星盘", "述": "夜观星象，推演天机运势"},
	{"id": "药圃经营", "名": "药圃经营", "述": "躬耕灵田，栽育百草灵植"},
	{"id": "论道棋弈", "名": "论道棋弈", "述": "手谈一局，于棋中悟道"},
	{"id": "入山采撷", "名": "入山采撷", "述": "狩猎采药采矿，取山林之利"},
]

var _built: bool = false
var _列表: VBoxContainer = null

func _ready() -> void:
	_build()
	refresh()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content: Control = UITheme.make_scene_background(self)
	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(vbox)

	_build_header(vbox)

	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_列表 = VBoxContainer.new()
	_列表.name = "List"
	_列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_列表.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_列表)

	var 说明 := Label.new()
	说明.name = "Note"
	说明.text = "闲情雅趣，道心憩息。七般雅趣皆随缘自到，不设打卡、不迫不催；所悟所得尽入图录。"
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说明)
	说明.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(说明)

func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	parent.add_child(UITheme.建顶栏("闲情雅趣", _on_back_pressed, [], "闲情雅趣", "休闲玩法总入口。\n灵渊垂钓、探遗迹、饲灵育兽、卜算星盘、药圃经营、论道棋弈、入山采撷。\n于闲情中悟大道，零惩罚、强收集。"))
func refresh() -> void:
	if not _built:
		return
	for c in _列表.get_children():
		c.queue_free()
	for r in 雅趣表:
		var _fb1 := _建_雅趣项(String(r.get("id", "")), String(r.get("名", "")), String(r.get("述", "")))
		_列表.add_child(_fb1)
		_fb1.modulate.a = 0.0
		_fb1.create_tween().tween_property(_fb1, "modulate:a", 1.0, 0.25)

func _建_雅趣项(id: String, 名: String, 述: String) -> Control:
	var b := Button.new()
	b.name = "Leisure_" + id
	b.text = "%s\n%s" % [名, 述]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, UITheme.SIZE_MD)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(Callable(self, "_on_雅趣").bind(id))
	UITheme.apply_secondary_button_style(b)
	return b

func _on_雅趣(id: String) -> void:
	雅趣请求.emit(id)

func _on_back_pressed() -> void:
	返回主页.emit()

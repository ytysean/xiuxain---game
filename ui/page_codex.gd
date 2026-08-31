extends Control

# 收藏图录（GameUI 二级页）：按类别分段展示图录收藏状态，稀有藏品可供奉藏宝阁换声望。
# 数据只读 Game.图录配置 / 收藏图录_已收集 / 捐赠记录；写操作仅调 Game.捐赠图录(图录ID)。
# 严守数据层不可动。

signal 返回主页

var _built: bool = false
var _当前类别: String = ""
var _类别列表: Array = []
var _分段行: HBoxContainer
var _列表: VBoxContainer
var _状态标签: Label

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
	_build_segments(vbox)

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
	说明.text = "稀有藏品可供奉藏宝阁，换取宗门声望；普通藏品仅收录不捐。"
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说明)
	说明.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(说明)

	if is_instance_valid(Game) and Game.has_signal("图录更新"):
		Game.图录更新.connect(_on_图录更新)

func _build_header(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.name = "HeaderBar"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	var back: Button = UITheme.make_back_button(_on_back_pressed)
	bar.add_child(back)
	var title := Label.new()
	title.name = "Title"
	title.text = "收藏图录  ⓘ"
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			UIHint.show_hint(title, "收藏图录", "收录宗门 encountered 的法器、灵兽、功法等图鉴。\n收集更多条目可获得成就奖励。"))
	UITheme.apply_page_title(title)
	bar.add_child(title)
	_状态标签 = Label.new()
	_状态标签.name = "Status"
	_状态标签.text = "已捐 0"
	UITheme.apply_value_font(_状态标签, false)
	_状态标签.add_theme_color_override("font_color", UITheme.color_text_title1())
	bar.add_child(_状态标签)
	parent.add_child(bar)

func _build_segments(parent: Control) -> void:
	_类别列表 = _取类别列表()
	if _类别列表.is_empty():
		_类别列表 = ["全部"]
	_当前类别 = _类别列表[0]
	_分段行 = HBoxContainer.new()
	_分段行.name = "Segments"
	_分段行.add_theme_constant_override("separation", 8)
	for c in _类别列表:
		var b: Button = Button.new()
		b.name = "Seg_" + c
		b.text = c
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 32)
		_style_seg(b, c == _当前类别)
		b.pressed.connect(_on_seg_pressed.bind(c, b))
		_分段行.add_child(b)
	parent.add_child(_分段行)

func _style_seg(b: Button, selected: bool) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.784, 0.659, 0.416) if selected else Color(0.094, 0.176, 0.215)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	if selected:
		UITheme.apply_button_label(b, true)
		b.add_theme_color_override("font_color", UITheme.color_text_title1())
	else:
		UITheme.apply_aux_text(b)
		b.add_theme_color_override("font_color", UITheme.color_text_body_dim())

func _on_seg_pressed(cat: String, b: Button) -> void:
	_当前类别 = cat
	for child in _分段行.get_children():
		if child is Button:
			_style_seg(child, child.text == cat)
	refresh()

func refresh() -> void:
	if not _built:
		_build()
	_populate()

func _populate() -> void:
	if _列表 == null:
		return
	for c in _列表.get_children():
		_列表.remove_child(c)
		c.queue_free()
	var 配置: Array = []
	var 已捐: Dictionary = {}
	var 已收: Dictionary = {}
	if is_instance_valid(Game):
		配置 = Game.图录配置
		已捐 = Game.捐赠记录
		已收 = Game.收藏图录_已收集
	var 捐赠数: int = 0
	for id in 已捐.keys():
		if bool(已捐.get(id, false)):
			捐赠数 += 1
	if _状态标签 != null:
		_状态标签.text = "已捐 %d" % 捐赠数
	for r in 配置:
		if str(r.get("类别", "")) != _当前类别:
			continue
		_列表.add_child(_建卡(r, 已收, 已捐))

func _建卡(r: Dictionary, 已收: Dictionary, 已捐: Dictionary) -> Control:
	var 图录ID: String = str(r.get("图录ID", ""))
	var 名称: String = str(r.get("名称", ""))
	var 类别: String = str(r.get("类别", ""))
	var 是否稀有: bool = str(r.get("是否稀有", "否")) == "是"
	var 匹配名: String = str(r.get("匹配名", ""))
	var 已收列表: Array = 已收.get(类别, [])
	var 已收录: bool = 已收列表.has(匹配名)
	var 已捐赠: bool = bool(已捐.get(图录ID, false))

	var card := PanelContainer.new()
	card.name = "Card_" + 图录ID
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.050, 0.110, 0.140)
	sb.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("margin_left", 16)
	vbox.add_theme_constant_override("margin_right", 16)
	vbox.add_theme_constant_override("margin_top", 12)
	vbox.add_theme_constant_override("margin_bottom", 12)
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var 名 := Label.new()
	名.text = 名称
	UITheme.apply_body_text(名)
	名.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	vbox.add_child(名)

	var 元 := Label.new()
	元.text = "%s · %s藏品" % [类别, "稀有" if 是否稀有 else "普通"]
	UITheme.apply_aux_text(元)
	元.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(元)

	var 状态 := Label.new()
	if 已捐赠:
		状态.text = "已供奉"
	elif 已收录:
		状态.text = "已收录"
	else:
		状态.text = "未收录"
	UITheme.apply_aux_text(状态)
	if 已捐赠:
		状态.add_theme_color_override("font_color", UITheme.color_text_title1())
	else:
		状态.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(状态)

	if 是否稀有 and not 已捐赠:
		var btn := Button.new()
		btn.name = "Donate"
		btn.text = "供奉"
		btn.custom_minimum_size = Vector2(0, 32)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		UITheme.apply_button_label(btn, true)
		btn.pressed.connect(_on_捐赠.bind(图录ID, btn))
		vbox.add_child(btn)
	else:
		var btn := Button.new()
		btn.name = "Disabled"
		btn.text = "已录"
		btn.custom_minimum_size = Vector2(0, 32)
		btn.disabled = true
		UITheme.apply_button_label(btn, false)
		btn.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		vbox.add_child(btn)
	return card

func _on_捐赠(图录ID: String, btn: Button) -> void:
	if btn != null:
		UITween.button_press(btn)
	if not is_instance_valid(Game) or not Game.has_method("捐赠图录"):
		_toast("图录功法未就绪")
		return
	var res: Dictionary = Game.捐赠图录(图录ID)
	_toast(str(res.get("msg", "捐赠完成")))
	refresh()

func _on_图录更新() -> void:
	refresh()

func _toast(t: String) -> void:
	if is_instance_valid(Game) and Game.has_method("toast"):
		Game.toast(t)

func _取类别列表() -> Array:
	var 列表: Array = []
	if is_instance_valid(Game):
		for r in Game.图录配置:
			var c: String = str(r.get("类别", ""))
			if c != "" and not 列表.has(c):
				列表.append(c)
	return 列表

func _on_back_pressed() -> void:
	返回主页.emit()


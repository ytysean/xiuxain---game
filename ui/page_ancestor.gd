extends Control

# 祖师堂（GameUI 二级页）：展示飞升弟子档案、先贤堂坐化弟子、飞升前兆队列。
# 数据只读 Game.祖师堂 / Game.先贤堂 / Game.飞升前兆队列；写操作仅调 Game.举办飞升大典(弟子ID)。
# 严守数据层不可动。

signal 返回主页

var _built: bool = false
var _当前Tab: String = "祖师堂"
var _当前史馆分类: String = "全部"
var _列表: VBoxContainer
var _状态标签: Label
var _史馆分段行: HBoxContainer

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
	_build_tabs(vbox)
	_build史馆分段(vbox)

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
	说明.text = "祖师堂供奉飞升祖师，每位祖师为宗门带来气运加持（修炼速度+1%，上限30%）。先贤堂铭记坐化弟子事迹。"
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说明)
	说明.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(说明)

func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	var 右侧 := []
	_状态标签 = Label.new()
	_状态标签.name = "Status"
	_状态标签.text = "祖师 0 位"
	UITheme.apply_value_text(_状态标签)
	右侧.append(_状态标签)
	parent.add_child(UITheme.建顶栏("祖师堂", _on_back_pressed, 右侧, "祖师堂", "飞升祖师在此受供奉，为宗门带来气运加持。\n每位飞升祖师全宗修炼速度+1%，上限30%。"))
func _build_tabs(parent: Control) -> void:
	var tab_bar := HBoxContainer.new()
	tab_bar.name = "TabBar"
	tab_bar.add_theme_constant_override("separation", UITheme.GRID)
	var tabs: Array = ["祖师堂", "先贤堂", "宗门史馆", "飞升前兆"]
	for t in tabs:
		var btn := Button.new()
		btn.text = t
		btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		UITheme.apply_tab_style(btn, t == _当前Tab)
		btn.pressed.connect(func(): _on_tab_pressed(t))
		tab_bar.add_child(btn)
	parent.add_child(tab_bar)

func _on_tab_pressed(tab: String) -> void:
	_当前Tab = tab
	refresh()

func _build史馆分段(parent: Control) -> void:
	_史馆分段行 = HBoxContainer.new()
	_史馆分段行.name = "史馆分段"
	_史馆分段行.add_theme_constant_override("separation", 8)
	_史馆分段行.visible = false
	var 分类: Array = ["全部", "历代宗主录", "宗门大事记", "功法传承录", "名人堂"]
	for c in 分类:
		var b: Button = Button.new()
		b.text = c
		b.custom_minimum_size = Vector2(0, 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style史馆分段(b, c == _当前史馆分类)
		b.pressed.connect(func(): _on史馆分段_pressed(c, b))
		_史馆分段行.add_child(b)
	parent.add_child(_史馆分段行)

func _style史馆分段(b: Button, selected: bool) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.784, 0.659, 0.416) if selected else UITheme.获取面板底色()
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	if selected:
		UITheme.apply_button_label(b, true)
		b.add_theme_color_override("font_color", UITheme.color_text_title1())
	else:
		UITheme.apply_aux_text(b)
		b.add_theme_color_override("font_color", UITheme.color_text_body_dim())

func _on史馆分段_pressed(cat: String, b: Button) -> void:
	_当前史馆分类 = cat
	for child in _史馆分段行.get_children():
		if child is Button:
			_style史馆分段(child, child.text == cat)
	refresh()

func _show史馆分段() -> void:
	if _史馆分段行 != null:
		_史馆分段行.visible = true

func _hide史馆分段() -> void:
	if _史馆分段行 != null:
		_史馆分段行.visible = false

func refresh() -> void:
	if not _built:
		return
	for c in _列表.get_children():
		c.queue_free()
	if _当前Tab == "祖师堂":
		_hide史馆分段()
		_render祖师堂()
	elif _当前Tab == "先贤堂":
		_hide史馆分段()
		_render先贤堂()
	elif _当前Tab == "宗门史馆":
		_show史馆分段()
		_render宗门史馆()
	elif _当前Tab == "飞升前兆":
		_hide史馆分段()
		_render飞升前兆()

func _render祖师堂() -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 祖师列表: Array = Game.祖师堂
	_状态标签.text = "祖师 %d 位 | 气运加成 +%d%%" % [祖师列表.size(), int(Game.祖师堂气运加成() * 100)]
	if 祖师列表.is_empty():
		var empty := Label.new()
		empty.text = "尚无飞升祖师。渡劫境弟子历劫功成后，将白日飞升，入祖师堂受供奉。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_body_text(empty)
		empty.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		_列表.add_child(empty)
		return
	for 祖师 in 祖师列表:
		_render祖师卡片(祖师)

func _render祖师卡片(祖师: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "祖师卡片_" + str(祖师.get("弟子ID", ""))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID_SM)
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	panel.add_child(vbox)

	var 行1 := HBoxContainer.new()
	行1.add_theme_constant_override("separation", UITheme.GRID)
	var 名 := Label.new()
	名.text = str(祖师.get("姓名", "未知"))
	UITheme.apply_title_text(名)
	行1.add_child(名)
	var 境 := Label.new()
	境.text = str(祖师.get("境界", ""))
	UITheme.apply_value_text(境)
	行1.add_child(境)
	var 路线 := Label.new()
	路线.text = str(祖师.get("飞升路线", "普通飞升"))
	UITheme.apply_aux_text(路线)
	路线.add_theme_color_override("font_color", UITheme.color_accent())
	行1.add_child(路线)
	行1.add_spacer(true)
	vbox.add_child(行1)

	var 行2 := HBoxContainer.new()
	行2.add_theme_constant_override("separation", UITheme.GRID)
	var 飞升日 := Label.new()
	var 日: int = int(祖师.get("飞升日", 0))
	var 年: int = int(日 / 360.0)
	飞升日.text = "飞升于太玄 %d 年" % 年
	UITheme.apply_aux_text(飞升日)
	飞升日.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	行2.add_child(飞升日)
	var 功德业力 := Label.new()
	功德业力.text = "功德 %d | 业力 %d" % [int(祖师.get("功德", 0)), int(祖师.get("业力", 0))]
	UITheme.apply_aux_text(功德业力)
	功德业力.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	行2.add_child(功德业力)
	行2.add_spacer(true)
	vbox.add_child(行2)

	var 传承列表: Array = 祖师.get("传承列表", [])
	if 传承列表.size() > 0:
		var 传承标签 := Label.new()
		传承标签.text = "留下传承：" + "、".join(传承列表)
		传承标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_body_text(传承标签)
		vbox.add_child(传承标签)

	_列表.add_child(panel)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)

func _render先贤堂() -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 先贤列表: Array = Game.先贤堂
	_状态标签.text = "先贤 %d 位" % 先贤列表.size()
	if 先贤列表.is_empty():
		var empty := Label.new()
		empty.text = "尚无先贤入册。弟子寿元耗尽坐化后，将入先贤堂受铭记。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_body_text(empty)
		empty.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		_列表.add_child(empty)
		return
	for 先贤 in 先贤列表:
		_render先贤卡片(先贤)

func _render先贤卡片(先贤: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "先贤卡片_" + str(先贤.get("弟子ID", ""))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID_SM)
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	panel.add_child(vbox)

	var 行1 := HBoxContainer.new()
	行1.add_theme_constant_override("separation", UITheme.GRID)
	var 名 := Label.new()
	名.text = str(先贤.get("姓名", "未知"))
	UITheme.apply_title_text(名)
	行1.add_child(名)
	var 境 := Label.new()
	境.text = str(先贤.get("境界", ""))
	UITheme.apply_value_text(境)
	行1.add_child(境)
	行1.add_spacer(true)
	vbox.add_child(行1)

	var 事迹 := Label.new()
	事迹.text = str(先贤.get("事迹摘要", ""))
	事迹.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_text(事迹)
	vbox.add_child(事迹)

	_列表.add_child(panel)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)

func _render飞升前兆() -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 前兆列表: Array = Game.飞升前兆队列
	_状态标签.text = "前兆 %d 人" % 前兆列表.size()
	if 前兆列表.is_empty():
		var empty := Label.new()
		empty.text = "暂无飞升前兆。渡劫大圆满弟子有概率感应天地，出现飞升之兆。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_body_text(empty)
		empty.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		_列表.add_child(empty)
		return
	for 前兆 in 前兆列表:
		_render前兆卡片(前兆)

func _render前兆卡片(前兆: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "前兆卡片_" + str(前兆.get("弟子ID", ""))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID_SM)
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	panel.add_child(vbox)

	var 行1 := HBoxContainer.new()
	行1.add_theme_constant_override("separation", UITheme.GRID)
	var 名 := Label.new()
	名.text = str(前兆.get("姓名", "未知"))
	UITheme.apply_title_text(名)
	行1.add_child(名)
	var 境 := Label.new()
	境.text = str(前兆.get("境界", ""))
	UITheme.apply_value_text(境)
	行1.add_child(境)
	行1.add_spacer(true)
	vbox.add_child(行1)

	var 飞升日: int = int(前兆.get("飞升日", 0))
	var 剩余日: int = max(0, 飞升日 - Game.累计游戏日)
	var 提示 := Label.new()
	提示.text = "飞升之兆已现，预计 %d 日后历劫飞升。可举办飞升大典，消耗灵石1000、灵草100，提升飞升成功率至80%%。" % 剩余日
	提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_text(提示)
	vbox.add_child(提示)

	var btn := Button.new()
	btn.text = "举办飞升大典"
	btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	UITheme.apply_button_style(btn)
	btn.pressed.connect(func(): _on_举办飞升大典(int(前兆.get("弟子ID", 0))))
	vbox.add_child(btn)

	_列表.add_child(panel)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)

func _on_举办飞升大典(弟子ID: int) -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.举办飞升大典(弟子ID)
	if 结果.get("成功", false):
		UIHint.show_hint(self, "飞升大典", str(结果.get("消息", "飞升成功")))
	else:
		UIHint.show_hint(self, "飞升大典", str(结果.get("原因", "飞升失败")))
	refresh()

func _on_back_pressed() -> void:
	返回主页.emit()

func _render宗门史馆() -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 典籍列表: Array = Game.获取宗门典籍(_当前史馆分类, 50)
	_状态标签.text = "史馆 %d 条" % 典籍列表.size()
	if 典籍列表.is_empty():
		var empty := Label.new()
		empty.text = "宗门史馆尚无记载。随着宗门发展，历代宗主、杰出弟子、重要事件将载入史册。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_body_text(empty)
		empty.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		_列表.add_child(empty)
		return
	for 典籍 in 典籍列表:
		_render史馆卡片(典籍)

func _render史馆卡片(典籍: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "史馆卡片_" + str(典籍.get("标题", ""))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID_SM)
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	panel.add_child(vbox)

	var 行1 := HBoxContainer.new()
	行1.add_theme_constant_override("separation", UITheme.GRID)
	var 标题 := Label.new()
	标题.text = str(典籍.get("标题", "无标题"))
	UITheme.apply_title_text(标题)
	行1.add_child(标题)
	var 日期 := Label.new()
	var 日: int = int(典籍.get("日期", 0))
	var 年: int = int(日 / 360.0)
	日期.text = "太玄 %d 年" % 年
	UITheme.apply_aux_text(日期)
	日期.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	行1.add_child(日期)
	行1.add_spacer(true)
	vbox.add_child(行1)

	var 内容: String = str(典籍.get("内容", ""))
	if 内容 != "":
		var 内容标签 := Label.new()
		内容标签.text = 内容
		内容标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_body_text(内容标签)
		vbox.add_child(内容标签)

	_列表.add_child(panel)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)

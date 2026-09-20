extends Control
class_name PageFragmentChest

## 碎片合成 & 宝箱打开页面（GameUI 二级页）
## 包含两个标签页：碎片合成、宝箱打开
## 2026-08-29 新建：全新系统UI接入

signal 返回主页

const 标签列表: Array = ["碎片合成", "宝箱打开"]

var _built: bool = false
var _当前标签: String = "碎片合成"
var _标签按钮: Dictionary = {}   # 标签名 -> Button
var _内容容器: VBoxContainer
var _碎片列表: Array = []        # [{碎片ID, 名称, 类型, 数量, 所需数量, 可合成, 按钮}]
var _宝箱列表: Array = []        # [{宝箱ID, 名称, 类型, 数量, 按钮}]
var _结果标签: Label

func _ready() -> void:
	_build()
	refresh()

func _enter_tree() -> void:
	if _built:
		refresh.call_deferred()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

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
	_build_content(vbox)

# ───────── 顶部导航栏 ─────────
func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	parent.add_child(UITheme.建顶栏("碎片 & 宝箱", _on_back_pressed, []))
func _build_tabs(parent: Control) -> void:
	var tab_bar := HBoxContainer.new()
	tab_bar.name = "TabBar"
	tab_bar.add_theme_constant_override("separation", UITheme.GRID)
	for 标签名 in 标签列表:
		var btn := Button.new()
		btn.name = "Tab_" + 标签名
		btn.text = 标签名
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_tab_pressed.bind(标签名))
		_style_tab_button(btn, 标签名 == _当前标签)
		_标签按钮[标签名] = btn
		tab_bar.add_child(btn)
		btn.modulate.a = 0.0
		btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)
	parent.add_child(tab_bar)

func _style_tab_button(btn: Button, 选中: bool) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	if 选中:
		sb.bg_color = Color(0.910, 0.773, 0.447, 0.20)
		sb.border_color = Color(0.910, 0.773, 0.447)
		sb.set_border_width_all(2)
	else:
		sb.bg_color = Color(0.122, 0.169, 0.192)
		sb.border_color = Color(0.431, 0.341, 0.149)
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("focus", sb)
	UITheme.apply_button_label(btn, true)
	if 选中:
		btn.add_theme_color_override("font_color", Color(0.910, 0.773, 0.447))
	else:
		btn.add_theme_color_override("font_color", UITheme.获取主文字色())

# ───────── 内容区域 ─────────
func _build_content(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	_内容容器 = VBoxContainer.new()
	_内容容器.name = "Content"
	_内容容器.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_内容容器.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_内容容器)

	# 结果提示
	_结果标签 = Label.new()
	_结果标签.name = "ResultLabel"
	_结果标签.text = ""
	_结果标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_body_text(_结果标签)
	_内容容器.add_child(_结果标签)

func _clear_content() -> void:
	# 保留结果标签，清除其他内容
	for child in _内容容器.get_children():
		if child.name != "ResultLabel":
			_内容容器.remove_child(child)
			child.queue_free()

# ───────── 碎片合成标签 ─────────
func _build_fragment_content() -> void:
	_clear_content()
	_碎片列表.clear()

	var 配方列表: Array = FragmentCraftSystem.获取所有配方()
	if 配方列表.is_empty():
		var 空标签 := Label.new()
		空标签.text = "尚无碎片合成配方"
		空标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_body_text(空标签)
		_内容容器.add_child(空标签)
		return

	for 配方 in 配方列表:
		var 碎片ID: String = str(配方.get("碎片ID", ""))
		var 名称: String = str(配方.get("名称", ""))
		var 类型: String = str(配方.get("类型", ""))
		var 所需数量: int = int(配方.get("所需数量", 0))
		var 额外灵石: int = int(配方.get("额外灵石消耗", 0))
		var 描述: String = str(配方.get("描述", ""))
		var 当前数量: int = Game.获取碎片数量(碎片ID)
		var 可合成: bool = (当前数量 >= 所需数量) and (Game.灵石 >= 额外灵石)

		var card: PanelContainer = PanelContainer.new()
		card.name = "Fragment_" + 碎片ID
		card.custom_minimum_size = Vector2(0, 80)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.122, 0.169, 0.192)
		sb.set_corner_radius_all(8)
		card.add_theme_stylebox_override("panel", sb)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("margin_left", 16)
		hbox.add_theme_constant_override("margin_right", 16)
		hbox.add_theme_constant_override("margin_top", 12)
		hbox.add_theme_constant_override("margin_bottom", 12)
		hbox.add_theme_constant_override("separation", UITheme.GRID)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(hbox)
		hbox.modulate.a = 0.0
		hbox.create_tween().tween_property(hbox, "modulate:a", 1.0, 0.25)

		# 左侧：图标 + 名称 + 类型
		var left_vbox := VBoxContainer.new()
		left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_vbox.add_theme_constant_override("separation", 4)
		hbox.add_child(left_vbox)
		left_vbox.modulate.a = 0.0
		left_vbox.create_tween().tween_property(left_vbox, "modulate:a", 1.0, 0.25)

		var 名称标签 := Label.new()
		名称标签.text = 名称
		UITheme.apply_body_text(名称标签)
		left_vbox.add_child(名称标签)
		名称标签.modulate.a = 0.0
		名称标签.create_tween().tween_property(名称标签, "modulate:a", 1.0, 0.25)

		var 类型标签 := Label.new()
		类型标签.text = "类型：%s | 数量：%d/%d | 灵石：%d" % [类型, 当前数量, 所需数量, 额外灵石]
		类型标签.add_theme_color_override("font_color", UITheme.获取次文字色())
		UITheme.apply_body_font_sized(类型标签, UITheme.FONT_AUX)
		left_vbox.add_child(类型标签)
		类型标签.modulate.a = 0.0
		类型标签.create_tween().tween_property(类型标签, "modulate:a", 1.0, 0.25)

		var 描述标签 := Label.new()
		描述标签.text = 描述
		描述标签.add_theme_color_override("font_color", UITheme.获取弱文字色())
		UITheme.apply_body_font_sized(描述标签, UITheme.FONT_AUX)
		left_vbox.add_child(描述标签)
		描述标签.modulate.a = 0.0
		描述标签.create_tween().tween_property(描述标签, "modulate:a", 1.0, 0.25)

		# 右侧：合成按钮
		var 合成按钮 := Button.new()
		合成按钮.name = "CraftBtn"
		合成按钮.text = "炼化"
		合成按钮.custom_minimum_size = Vector2(80, 40)
		合成按钮.disabled = not 可合成
		合成按钮.pressed.connect(_on_craft_fragment.bind(碎片ID))
		_style_craft_button(合成按钮, 可合成)
		hbox.add_child(合成按钮)
		合成按钮.modulate.a = 0.0
		合成按钮.create_tween().tween_property(合成按钮, "modulate:a", 1.0, 0.25)

		_内容容器.add_child(card)
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.25)
		_碎片列表.append({"碎片ID": 碎片ID, "名称": 名称, "数量": 当前数量, "所需数量": 所需数量, "可合成": 可合成, "按钮": 合成按钮})

func _style_craft_button(btn: Button, 可合成: bool) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	if 可合成:
		sb.bg_color = Color(0.910, 0.773, 0.447)
		btn.add_theme_color_override("font_color", Color(0.086, 0.157, 0.173))
	else:
		sb.bg_color = UITheme.获取面板底色()
		btn.add_theme_color_override("font_color", UITheme.获取弱文字色())
	sb.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("focus", sb)
	UITheme.apply_button_label(btn, true)

func _on_craft_fragment(碎片ID: String) -> void:
	var 结果: Dictionary = Game.执行碎片合成(碎片ID)
	if 结果.get("成功", false):
		_结果标签.text = "✓ " + str(结果.get("原因", "合成成功"))
		_结果标签.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		_结果标签.text = "× " + str(结果.get("原因", "炼化失败"))
		_结果标签.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	refresh()

# ───────── 宝箱打开标签 ─────────
func _build_chest_content() -> void:
	_clear_content()
	_宝箱列表.clear()

	var 宝箱列表: Array = ChestSystem.获取所有宝箱()
	if 宝箱列表.is_empty():
		var 空标签 := Label.new()
		空标签.text = "尚无宝箱"
		空标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_body_text(空标签)
		_内容容器.add_child(空标签)
		return

	for 宝箱 in 宝箱列表:
		var 宝箱ID: String = str(宝箱.get("宝箱ID", ""))
		var 名称: String = str(宝箱.get("名称", ""))
		var 类型: String = str(宝箱.get("类型", ""))
		var 描述: String = str(宝箱.get("描述", ""))
		var 当前数量: int = Game.获取宝箱数量(宝箱ID)
		var 可打开: bool = 当前数量 > 0

		var card: PanelContainer = PanelContainer.new()
		card.name = "Chest_" + 宝箱ID
		card.custom_minimum_size = Vector2(0, 80)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.122, 0.169, 0.192)
		sb.set_corner_radius_all(8)
		card.add_theme_stylebox_override("panel", sb)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("margin_left", 16)
		hbox.add_theme_constant_override("margin_right", 16)
		hbox.add_theme_constant_override("margin_top", 12)
		hbox.add_theme_constant_override("margin_bottom", 12)
		hbox.add_theme_constant_override("separation", UITheme.GRID)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(hbox)
		hbox.modulate.a = 0.0
		hbox.create_tween().tween_property(hbox, "modulate:a", 1.0, 0.25)

		# 左侧：名称 + 类型 + 描述
		var left_vbox := VBoxContainer.new()
		left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_vbox.add_theme_constant_override("separation", 4)
		hbox.add_child(left_vbox)
		left_vbox.modulate.a = 0.0
		left_vbox.create_tween().tween_property(left_vbox, "modulate:a", 1.0, 0.25)

		var 名称标签 := Label.new()
		名称标签.text = 名称
		UITheme.apply_body_text(名称标签)
		left_vbox.add_child(名称标签)
		名称标签.modulate.a = 0.0
		名称标签.create_tween().tween_property(名称标签, "modulate:a", 1.0, 0.25)

		var 类型标签 := Label.new()
		类型标签.text = "类型：%s | 数量：%d" % [类型, 当前数量]
		类型标签.add_theme_color_override("font_color", UITheme.获取次文字色())
		UITheme.apply_body_font_sized(类型标签, UITheme.FONT_AUX)
		left_vbox.add_child(类型标签)
		类型标签.modulate.a = 0.0
		类型标签.create_tween().tween_property(类型标签, "modulate:a", 1.0, 0.25)

		var 描述标签 := Label.new()
		描述标签.text = 描述
		描述标签.add_theme_color_override("font_color", UITheme.获取弱文字色())
		UITheme.apply_body_font_sized(描述标签, UITheme.FONT_AUX)
		left_vbox.add_child(描述标签)
		描述标签.modulate.a = 0.0
		描述标签.create_tween().tween_property(描述标签, "modulate:a", 1.0, 0.25)

		# 右侧：打开按钮
		var 打开按钮 := Button.new()
		打开按钮.name = "OpenBtn"
		打开按钮.text = "打开"
		打开按钮.custom_minimum_size = Vector2(80, 40)
		打开按钮.disabled = not 可打开
		打开按钮.pressed.connect(_on_open_chest.bind(宝箱ID))
		_style_open_button(打开按钮, 可打开)
		hbox.add_child(打开按钮)
		打开按钮.modulate.a = 0.0
		打开按钮.create_tween().tween_property(打开按钮, "modulate:a", 1.0, 0.25)

		_内容容器.add_child(card)
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.25)
		_宝箱列表.append({"宝箱ID": 宝箱ID, "名称": 名称, "数量": 当前数量, "可打开": 可打开, "按钮": 打开按钮})

func _style_open_button(btn: Button, 可打开: bool) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	if 可打开:
		sb.bg_color = Color(0.910, 0.773, 0.447)
		btn.add_theme_color_override("font_color", Color(0.086, 0.157, 0.173))
	else:
		sb.bg_color = UITheme.获取面板底色()
		btn.add_theme_color_override("font_color", UITheme.获取弱文字色())
	sb.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("focus", sb)
	UITheme.apply_button_label(btn, true)

func _on_open_chest(宝箱ID: String) -> void:
	var 结果: Dictionary = Game.打开宝箱(宝箱ID)
	if 结果.get("成功", false):
		var 掉落文本: String = ""
		for 掉落 in 结果.get("掉落列表", []):
			掉落文本 += "%s×%d " % [str(掉落.get("物品ID", "")), int(掉落.get("数量", 1))]
		_结果标签.text = "✓ 打开成功！获得：" + 掉落文本
		_结果标签.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		_结果标签.text = "× " + str(结果.get("原因", "启封失败"))
		_结果标签.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	refresh()

# ───────── 事件处理 ─────────
func _on_tab_pressed(标签名: String) -> void:
	_当前标签 = 标签名
	for 名 in _标签按钮.keys():
		_style_tab_button(_标签按钮[名], 名 == _当前标签)
	_结果标签.text = ""
	refresh()

func _on_back_pressed() -> void:
	返回主页.emit()

func refresh() -> void:
	if not _built:
		_build()
	if _当前标签 == "碎片合成":
		_build_fragment_content()
	else:
		_build_chest_content()

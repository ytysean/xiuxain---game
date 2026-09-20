extends Control

# 功绩堂（GameUI 二级页）：展示宗门功绩（原成就系统）和宗门传承（原里程碑系统）。
# 数据只读 Game.成就配置 / Game.成就_已达成 / Game.已领取成就奖励 / Game.里程碑配置；
# 写操作仅调 Game.领取成就奖励(成就ID)。
# 修真世界观：功绩堂记录宗门功绩，传承殿记载宗门发展节点。

signal 返回主页

# 分批渲染：功绩/传承条目可达数百条，一次性全量建卡会让单页节点数破两千（移动端卡顿）。
# 改为首屏建 每批条 + 滚动近底续建，列表数据与渲染游标分离。
const 每批: int = 30

var _built: bool = false
var _当前Tab: String = "宗门功绩"
var _当前分类: String = "全部"
var _列表: VBoxContainer
var _滚动: ScrollContainer
var _待渲染: Array = []
var _渲染游标: int = 0
var _渲染模式: String = ""
var _状态标签: Label
var _分段行: HBoxContainer

# 分类修真化映射（旧分类→新分类）
const 分类映射: Dictionary = {
	"经营": "宗门经营",
	"成长": "弟子培养",
	"战斗": "征战杀伐",
	"收集": "典藏收集",
	"社交": "宗门外交",
	"探索": "秘境探索",
	"特殊": "隐世奇缘",
}

# 功绩分类顺序
const 功绩分类顺序: Array = ["全部", "宗门经营", "弟子培养", "征战杀伐", "典藏收集", "宗门外交", "秘境探索", "隐世奇缘"]

# 稀有度修真化映射
const 稀有度映射: Dictionary = {
	"普通": "凡功",
	"稀有": "奇功",
	"传说": "仙功",
}

# 稀有度颜色
const 稀有度颜色: Dictionary = {
	"凡功": Color(0.6, 0.6, 0.6),
	"奇功": Color(0.4, 0.8, 0.4),
	"仙功": Color(0.95, 0.75, 0.2),
}

func _ready() -> void:
	_build()
	refresh()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content: Control = UITheme.make_scene_background(self)
	# margin_* 常量对 VBoxContainer 无效（曾致 tab/分类条/卡片全部贴左右边缘）→ 用 MarginContainer 承载边距
	var margin := MarginContainer.new()
	margin.name = "RootMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UITheme.MARGIN)
	margin.add_theme_constant_override("margin_right", UITheme.MARGIN)
	margin.add_theme_constant_override("margin_top", UITheme.GRID)
	margin.add_theme_constant_override("margin_bottom", UITheme.GRID)
	content.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	margin.add_child(vbox)

	_build_header(vbox)
	_build_tabs(vbox)
	_build_segments(vbox)

	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_滚动 = scroll
	# 竖向滚动条在 ScrollContainer 就绪后才存在，延后一帧再连（首帧连会拿到 null）
	_连接滚动信号.call_deferred()
	_列表 = VBoxContainer.new()
	_列表.name = "List"
	_列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_列表.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_列表)

	var 说明 := Label.new()
	说明.name = "Note"
	说明.text = "功绩堂记载宗门历代功绩，达成可领赏赐。传承殿铭记宗门发展节点，达成自动获气运加持。"
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说明)
	说明.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(说明)

func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	var 右侧 := []
	_状态标签 = Label.new()
	_状态标签.name = "Status"
	_状态标签.text = "功绩 0/0"
	UITheme.apply_value_text(_状态标签)
	右侧.append(_状态标签)
	parent.add_child(UITheme.建顶栏("功绩堂", _on_back_pressed, 右侧, "功绩堂", "功绩堂记载宗门历代功绩，达成可领灵石、灵气、声望赏赐。\n传承殿铭记宗门发展节点，达成自动获气运加持。"))
func _build_tabs(parent: Control) -> void:
	var tab_bar := HBoxContainer.new()
	tab_bar.name = "TabBar"
	tab_bar.add_theme_constant_override("separation", UITheme.GRID)
	var tabs: Array = ["宗门功绩", "宗门传承"]
	for t in tabs:
		var btn := Button.new()
		btn.text = t
		btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		UITheme.apply_tab_style(btn, t == _当前Tab)
		btn.pressed.connect(func(): _on_tab_pressed(t))
		tab_bar.add_child(btn)
		btn.modulate.a = 0.0
		btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)
	parent.add_child(tab_bar)

func _build_segments(parent: Control) -> void:
	_分段行 = HBoxContainer.new()
	_分段行.name = "Segments"
	_分段行.add_theme_constant_override("separation", 6)
	for c in 功绩分类顺序:
		var b: Button = Button.new()
		b.text = c
		b.custom_minimum_size = Vector2(0, 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_seg(b, c == _当前分类)
		b.pressed.connect(func(): _on_seg_pressed(c, b))
		_分段行.add_child(b)
		b.modulate.a = 0.0
		b.create_tween().tween_property(b, "modulate:a", 1.0, 0.25)
	parent.add_child(_分段行)

func _style_seg(b: Button, selected: bool) -> void:
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

func _on_tab_pressed(tab: String) -> void:
	_当前Tab = tab
	if tab == "宗门传承":
		_分段行.visible = false
	else:
		_分段行.visible = true
	refresh()

func _on_seg_pressed(cat: String, b: Button) -> void:
	_当前分类 = cat
	for child in _分段行.get_children():
		if child is Button:
			_style_seg(child, child.text == cat)
	refresh()

func refresh() -> void:
	if not _built:
		return
	# 先摘出树再释放：仅 queue_free 会让旧卡片在帧末前仍参与布局，重建瞬间节点翻倍
	for c in _列表.get_children():
		_列表.remove_child(c)
		c.queue_free()
	_待渲染 = []
	_渲染游标 = 0
	_渲染模式 = ""
	if _当前Tab == "宗门功绩":
		_render功绩()
	elif _当前Tab == "宗门传承":
		_render传承()

## 滚动近底时续建下一批
func _on_scroll_changed(_v: float) -> void:
	if _滚动 == null or _渲染游标 >= _待渲染.size():
		return
	var bar: ScrollBar = _滚动.get_v_scroll_bar()
	if bar == null or bar.max_value <= 0.0:
		return
	if bar.value >= bar.max_value - bar.page * 0.8:
		_追加一批()

func _连接滚动信号() -> void:
	if _滚动 == null or not is_instance_valid(_滚动):
		return
	var bar: ScrollBar = _滚动.get_v_scroll_bar()
	if bar == null:
		return
	if not bar.value_changed.is_connected(_on_scroll_changed):
		bar.value_changed.connect(_on_scroll_changed)

## 开始一批渲染（列表数据只存引用，卡片按需建）
func _开始分批渲染(模式: String, 数据: Array) -> void:
	_渲染模式 = 模式
	_待渲染 = 数据
	_渲染游标 = 0
	_追加一批()

func _追加一批() -> void:
	if _渲染模式 == "" or _渲染游标 >= _待渲染.size():
		return
	var 末: int = mini(_渲染游标 + 每批, _待渲染.size())
	while _渲染游标 < 末:
		if _渲染模式 == "功绩":
			_render功绩卡片(_待渲染[_渲染游标])
		elif _渲染模式 == "传承":
			_render传承卡片(_待渲染[_渲染游标])
		_渲染游标 += 1
	# 首屏内容不足一屏时继续补，避免出现「还有条目却滚不动」的假底
	if _渲染游标 < _待渲染.size() and _列表.size.y > 0.0 and _列表.size.y < _滚动.size.y:
		_追加一批()

func _render功绩() -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 成就列表: Array = []
	var 已达成数: int = 0
	var 总数: int = 0
	for 成就 in Game.成就配置:
		var 旧分类: String = str(成就.get("category", ""))
		var 新分类: String = 分类映射.get(旧分类, "隐世奇缘")
		if _当前分类 != "全部" and 新分类 != _当前分类:
			continue
		成就列表.append(成就)
		总数 += 1
		if bool(成就.get("已达成", false)):
			已达成数 += 1
	_状态标签.text = "功绩 %d/%d" % [已达成数, 总数]
	if 成就列表.is_empty():
		var empty := Label.new()
		empty.text = "尚无此类功绩。宗门发展过程中，各类功绩将逐步解锁。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_body_text(empty)
		empty.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		_列表.add_child(empty)
		return
	_开始分批渲染("功绩", 成就列表)

func _render功绩卡片(成就: Dictionary) -> void:
	var 成就ID: String = str(成就.get("achievement_id", ""))
	var 名称: String = str(成就.get("ach_name", ""))
	var 描述: String = str(成就.get("condition_desc", ""))
	var 旧稀有度: String = str(成就.get("grade", "普通"))
	var 稀有度: String = 稀有度映射.get(旧稀有度, "凡功")
	var 已达成: bool = bool(成就.get("已达成", false))
	var 已领取: bool = Game.已领取成就奖励.has(成就ID) if Game != null else false
	var 奖励灵石: int = int(成就.get("reward_lingshi", 0))
	var 奖励灵气: int = int(成就.get("reward_lingqi", 0))
	var 奖励声望: int = int(成就.get("reward_shengwang", 0))

	var panel := PanelContainer.new()
	panel.name = "功绩卡片_" + 成就ID
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.122, 0.169, 0.192)
	sb.set_corner_radius_all(8)
	if 稀有度 == "仙功":
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.95, 0.75, 0.2, 0.6)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("margin_left", 12)
	vbox.add_theme_constant_override("margin_right", 12)
	vbox.add_theme_constant_override("margin_top", 8)
	vbox.add_theme_constant_override("margin_bottom", 8)
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# 名称行
	var 行1 := HBoxContainer.new()
	行1.add_theme_constant_override("separation", 8)
	var 名 := Label.new()
	名.text = 名称 if 已达成 else "？？？"
	UITheme.apply_body_text(名)
	名.add_theme_color_override("font_color", UITheme.获取主文字色())
	行1.add_child(名)
	var 稀有标签 := Label.new()
	稀有标签.text = "【%s】" % 稀有度
	UITheme.apply_aux_text(稀有标签)
	稀有标签.add_theme_color_override("font_color", 稀有度颜色.get(稀有度, Color(0.6, 0.6, 0.6)))
	行1.add_child(稀有标签)
	行1.add_spacer(true)
	vbox.add_child(行1)

	# 描述
	if 已达成:
		var 描述标签 := Label.new()
		描述标签.text = 描述
		描述标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_aux_text(描述标签)
		描述标签.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		vbox.add_child(描述标签)
	else:
		var 未达成标签 := Label.new()
		未达成标签.text = "未达成"
		UITheme.apply_aux_text(未达成标签)
		未达成标签.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		vbox.add_child(未达成标签)

	# 奖励
	if 已达成:
		var 奖励行 := HBoxContainer.new()
		奖励行.add_theme_constant_override("separation", 8)
		var 奖励文本: String = "赏赐："
		if 奖励灵石 > 0:
			奖励文本 += "灵石%d " % 奖励灵石
		if 奖励灵气 > 0:
			奖励文本 += "灵气%d " % 奖励灵气
		if 奖励声望 > 0:
			奖励文本 += "声望%d " % 奖励声望
		var 奖励标签 := Label.new()
		奖励标签.text = 奖励文本
		UITheme.apply_aux_text(奖励标签)
		奖励标签.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
		# 长赏赐串必须给有效宽度自动折行（HBox 内裸 Label 会溢出卡片被裁）
		奖励标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		奖励标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		奖励行.add_child(奖励标签)
		vbox.add_child(奖励行)

		# 领取按钮
		if not 已领取:
			var btn := Button.new()
			btn.text = "领取赏赐"
			btn.custom_minimum_size = Vector2(0, 28)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_END
			UITheme.apply_button_style(btn)
			btn.pressed.connect(func(): _on_领取赏赐(成就ID))
			vbox.add_child(btn)
		else:
			var 已领标签 := Label.new()
			已领标签.text = "✓ 已领取"
			UITheme.apply_aux_text(已领标签)
			已领标签.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			已领标签.size_flags_horizontal = Control.SIZE_SHRINK_END
			vbox.add_child(已领标签)

	_列表.add_child(panel)

func _render传承() -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 里程碑列表: Array = Game.获取所有里程碑列表()
	var 已达成数: int = 0
	var 总数: int = 里程碑列表.size()
	for 里程碑 in 里程碑列表:
		if bool(里程碑.get("已达成", false)):
			已达成数 += 1
	_状态标签.text = "传承 %d/%d" % [已达成数, 总数]
	if 里程碑列表.is_empty():
		var empty := Label.new()
		empty.text = "尚无宗门传承。宗门发展过程中，重要节点将载入传承殿。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_body_text(empty)
		empty.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		_列表.add_child(empty)
		return
	_开始分批渲染("传承", 里程碑列表)

func _render传承卡片(里程碑: Dictionary) -> void:
	var 名称: String = str(里程碑.get("名称", ""))
	var 描述: String = str(里程碑.get("描述", ""))
	var 已达成: bool = bool(里程碑.get("已达成", false))
	var 增益类型: String = str(里程碑.get("赏赐增益类型", ""))
	var 增益值: float = float(里程碑.get("赏赐增益值", 0))

	var panel := PanelContainer.new()
	panel.name = "传承卡片_" + 名称
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.122, 0.169, 0.192)
	sb.set_corner_radius_all(8)
	if 已达成:
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.4, 0.8, 0.4, 0.5)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("margin_left", 12)
	vbox.add_theme_constant_override("margin_right", 12)
	vbox.add_theme_constant_override("margin_top", 8)
	vbox.add_theme_constant_override("margin_bottom", 8)
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# 名称行
	var 行1 := HBoxContainer.new()
	行1.add_theme_constant_override("separation", 8)
	var 名 := Label.new()
	名.text = 名称
	UITheme.apply_body_text(名)
	名.add_theme_color_override("font_color", UITheme.获取主文字色())
	行1.add_child(名)
	var 状态标签 := Label.new()
	状态标签.text = "✓ 已达成" if 已达成 else "未达成"
	UITheme.apply_aux_text(状态标签)
	状态标签.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4) if 已达成 else UITheme.color_text_body_dim())
	行1.add_child(状态标签)
	行1.add_spacer(true)
	vbox.add_child(行1)

	# 描述
	var 描述标签 := Label.new()
	描述标签.text = 描述
	描述标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(描述标签)
	描述标签.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(描述标签)

	# 增益
	if 已达成 and 增益值 > 0:
		var 增益行 := HBoxContainer.new()
		增益行.add_theme_constant_override("separation", 8)
		var 增益文本: String = "气运加持：%s +%d%%" % [增益类型, int(增益值 * 100)]
		var 增益标签 := Label.new()
		增益标签.text = 增益文本
		UITheme.apply_aux_text(增益标签)
		增益标签.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
		增益行.add_child(增益标签)
		增益行.add_spacer(true)
		vbox.add_child(增益行)

	_列表.add_child(panel)

func _on_领取赏赐(成就ID: String) -> void:
	if Game == null or not is_instance_valid(Game):
		return
	if not Game.has_method("领取成就奖励"):
		UIHint.show_hint(self, "功绩堂", "功绩系统未就绪")
		Game.添加提示("功绩堂")
		return
	var 结果: Dictionary = Game.领取成就奖励(成就ID)
	if 结果.get("成功", false):
		UIHint.show_hint(self, "功绩堂", str(结果.get("消息", "赏赐领取成功")))
		Game.添加提示("功绩堂")
	else:
		UIHint.show_hint(self, "功绩堂", str(结果.get("原因", "领取失败")))
		Game.添加提示("功绩堂")
	refresh()

func _on_back_pressed() -> void:
	返回主页.emit()

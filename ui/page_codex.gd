extends Control

# 宗门典藏（GameUI 二级页）：按五大类展示宗门典藏，稀有度颜色区分，收集进度可视化。
# 数据只读 Game.图录配置 / 收藏图录_已收集 / 捐赠记录；写操作仅调 Game.捐赠图录(图录ID)。
# 修真世界观：万宝录、万兽谱、功法录、遗迹志、奇闻录

signal 返回主页

var _built: bool = false
var _当前类别: String = ""
var _类别列表: Array = []
var _分段行: HBoxContainer
var _列表: VBoxContainer
var _状态标签: Label
var _进度标签: Label
var _奖励标签: Label
# 分批渲染：典藏条目数以千计，一次建卡会拖慢首屏（实测 327ms）→ 首屏建一批，滚动近底再续建
var _滚动: ScrollContainer
var _待渲染: Array = []
var _渲染游标: int = 0
var _渲染上下文: Dictionary = {}
const 每批: int = 30

# 五大类分类映射（旧分类→新分类）
# 先贤事迹、天机已移出典藏，归入宗门典籍/观星系统
const 分类映射: Dictionary = {
	"阵法图谱": "功法录",
	"天材地宝": "万宝录",
	"灵草图录": "万宝录",
	"妖兽图录": "万兽谱",
	"功法残卷": "功法录",
	"灵钓": "奇闻录",
	"遗迹": "遗迹志",
	"灵兽": "万兽谱",
	"灵植": "万宝录",
	"棋谱录": "功法录",
	"商道": "奇闻录",
}

# 五大类显示顺序
const 大类顺序: Array = ["万宝录", "万兽谱", "功法录", "遗迹志", "奇闻录"]

# 稀有度颜色
const 稀有度颜色: Dictionary = {
	"凡品": Color(0.6, 0.6, 0.6),
	"良品": Color(0.4, 0.8, 0.4),
	"上品": Color(0.4, 0.6, 0.9),
	"极品": Color(0.8, 0.4, 0.9),
	"仙品": Color(0.95, 0.75, 0.2),
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
	# ★ 2026-09-16 修（#009 逐页精修 · 宗门典藏）：原代码把 margin_* 主题常量设在 **VBoxContainer**
	#   上 —— 这四个常量是 MarginContainer 专有，VBox 不认（只认 separation）⇒ 实机上等于没设，
	#   列表卡片直接贴死屏幕左右沿（实机截图可见，对照「阵营声望」同类卡片有边距）。
	#   改为真正的外层 MarginContainer，边距值与全项目其它页一致（MARGIN 直接按设计像素用）。
	var 边距 := MarginContainer.new()
	边距.name = "PageMargin"
	边距.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	边距.add_theme_constant_override("margin_left", UITheme.MARGIN)
	边距.add_theme_constant_override("margin_right", UITheme.MARGIN)
	边距.add_theme_constant_override("margin_top", UITheme.GRID)
	边距.add_theme_constant_override("margin_bottom", UITheme.GRID)
	边距.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(边距)
	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	边距.add_child(vbox)

	_build_header(vbox)
	_build_progress(vbox)
	_build_atmosphere(vbox)
	_build_segments(vbox)

	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_滚动 = scroll
	_列表 = VBoxContainer.new()
	_列表.name = "List"
	_列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_列表.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_列表)
	_连接滚动信号()

	var 说明 := Label.new()
	说明.name = "Note"
	说明.text = "宗门典藏，收录天下奇珍。仙品异物可供奉藏宝阁，换取宗门声望。"
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说明)
	说明.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(说明)

	if is_instance_valid(Game) and Game.has_signal("图录更新"):
		Game.图录更新.connect(_on_图录更新)

func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	var 右侧 := []
	_状态标签 = Label.new()
	_状态标签.name = "Status"
	_状态标签.text = "供奉 0"
	UITheme.apply_value_font(_状态标签, false)
	_状态标签.add_theme_color_override("font_color", UITheme.color_text_title1())
	右侧.append(_状态标签)
	parent.add_child(UITheme.建顶栏("宗门典藏", _on_back_pressed, 右侧, "宗门典藏", "宗门典藏阁，收录天下奇珍异宝、灵兽功法、遗迹秘闻。\n收集更多典藏可获宗门气运加持。"))
func _build_progress(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "ProgressPanel"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.122, 0.169, 0.192)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("margin_left", 12)
	vb.add_theme_constant_override("margin_right", 12)
	vb.add_theme_constant_override("margin_top", 8)
	vb.add_theme_constant_override("margin_bottom", 8)
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	_进度标签 = Label.new()
	_进度标签.name = "Progress"
	_进度标签.text = "总典藏进度：0/0"
	UITheme.apply_aux_text(_进度标签)
	_进度标签.add_theme_color_override("font_color", UITheme.color_text_title1())
	vb.add_child(_进度标签)
	var bar := ProgressBar.new()
	bar.name = "ProgressBar"
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 0
	bar.custom_minimum_size = Vector2(0, 10)
	vb.add_child(bar)
	# 集齐奖励展示
	_奖励标签 = Label.new()
	_奖励标签.name = "Reward"
	_奖励标签.text = ""
	_奖励标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(_奖励标签)
	_奖励标签.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	vb.add_child(_奖励标签)
	parent.add_child(panel)

func _build_atmosphere(parent: Control) -> void:
	# 典藏阁氛围描述，增加沉浸感
	var panel := PanelContainer.new()
	panel.name = "AtmospherePanel"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.122, 0.169, 0.192)
	sb.set_corner_radius_all(8)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.784, 0.659, 0.416, 0.3)
	panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("margin_left", 12)
	vb.add_theme_constant_override("margin_right", 12)
	vb.add_theme_constant_override("margin_top", 8)
	vb.add_theme_constant_override("margin_bottom", 8)
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	var 标题 := Label.new()
	标题.text = "◆ 典藏阁序 ◆"
	UITheme.apply_body_text(标题)
	标题.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	vb.add_child(标题)
	var 描述 := Label.new()
	描述.text = "太玄宗门典藏阁，藏天下奇珍异宝、灵兽功法、遗迹秘闻。凡入阁之物，皆录于册，以供后世弟子观瞻。仙品异物，可供奉藏宝阁，受宗门香火。"
	描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(描述)
	描述.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vb.add_child(描述)
	parent.add_child(panel)

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
		b.modulate.a = 0.0
		b.create_tween().tween_property(b, "modulate:a", 1.0, 0.25)
	parent.add_child(_分段行)

func _style_seg(b: Button, selected: bool) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.784, 0.659, 0.416) if selected else UITheme.获取面板底色()
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
	_update_progress()

func _update_progress() -> void:
	if _进度标签 == null:
		return
	var 配置: Array = []
	var 已收: Dictionary = {}
	if is_instance_valid(Game):
		配置 = Game.图录配置
		已收 = Game.收藏图录_已收集
	var 总数: int = 0
	var 已收数: int = 0
	var 增益值: float = 0.0
	for r in 配置:
		var 旧类别: String = str(r.get("类别", ""))
		# 先贤事迹、天机已移出典藏，不显示
		if not 分类映射.has(旧类别):
			continue
		var 新类别: String = 分类映射.get(旧类别, "奇闻录")
		if _当前类别 != "全部" and 新类别 != _当前类别:
			continue
		总数 += 1
		var 匹配名: String = str(r.get("匹配名", ""))
		var 已收列表: Array = 已收.get(旧类别, [])
		if 已收列表.has(匹配名):
			已收数 += 1
		if 增益值 <= 0.0:
			增益值 = float(r.get("增益值", 0.0))
	_进度标签.text = "%s进度：%d/%d" % [_当前类别, 已收数, 总数]
	var 进度条: ProgressBar = _进度标签.get_parent().get_node("ProgressBar")
	if 进度条 != null and 总数 > 0:
		进度条.value = float(已收数) / float(总数) * 100.0
	# 集齐奖励展示
	if _奖励标签 != null:
		if _当前类别 == "全部":
			_奖励标签.text = "集齐各类典藏可获宗门气运加持，产出最高+30%。"
		elif 已收数 >= 总数 and 总数 > 0:
			_奖励标签.text = "◆ 已圆满集齐！宗门产出+%d%%气运加持。" % int(增益值 * 100)
		elif 增益值 > 0:
			_奖励标签.text = "集齐奖励：宗门产出+%d%%（还差%d件）" % [int(增益值 * 100), 总数 - 已收数]
		else:
			_奖励标签.text = ""

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
		_状态标签.text = "供奉 %d" % 捐赠数
	# 只算该建哪些卡，卡片本身留到 _追加一批 按需建
	_待渲染 = []
	_渲染游标 = 0
	_渲染上下文 = {"已收": 已收, "已捐": 已捐}
	for r in 配置:
		var 旧类别: String = str(r.get("类别", ""))
		# 先贤事迹、天机已移出典藏，不显示
		if not 分类映射.has(旧类别):
			continue
		var 新类别: String = 分类映射.get(旧类别, "奇闻录")
		if _当前类别 != "全部" and 新类别 != _当前类别:
			continue
		_待渲染.append([r, 新类别])
	_追加一批()

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

func _追加一批() -> void:
	if _渲染游标 >= _待渲染.size():
		return
	var 末: int = mini(_渲染游标 + 每批, _待渲染.size())
	while _渲染游标 < 末:
		var 项: Array = _待渲染[_渲染游标]
		_列表.add_child(_建卡(项[0], _渲染上下文.get("已收", {}), _渲染上下文.get("已捐", {}), str(项[1])))
		_渲染游标 += 1
	# 首屏内容不足一屏时继续补，避免出现「还有条目却滚不动」的假底
	if _渲染游标 < _待渲染.size() and _列表.size.y > 0.0 and _列表.size.y < _滚动.size.y:
		_追加一批()

func _建卡(r: Dictionary, 已收: Dictionary, 已捐: Dictionary, 新类别: String) -> Control:
	var 图录ID: String = str(r.get("图录ID", ""))
	var 名称: String = str(r.get("名称", ""))
	var 旧类别: String = str(r.get("类别", ""))
	var 是否稀有: bool = str(r.get("是否稀有", "否")) == "是"
	var 匹配名: String = str(r.get("匹配名", ""))
	var 描述: String = str(r.get("描述", ""))
	var 已收列表: Array = 已收.get(旧类别, [])
	var 已收录: bool = 已收列表.has(匹配名)
	var 已捐赠: bool = bool(已捐.get(图录ID, false))

	# 稀有度判定
	var 稀有度: String = "凡品"
	if 是否稀有:
		稀有度 = "仙品"
	elif "极品" in 名称 or "上古" in 名称 or "太古" in 名称:
		稀有度 = "极品"
	elif "上品" in 名称 or "三百年" in 名称 or "五百年" in 名称:
		稀有度 = "上品"
	elif "良品" in 名称 or "百年" in 名称:
		稀有度 = "良品"

	var card := PanelContainer.new()
	card.name = "Card_" + 图录ID
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.122, 0.169, 0.192)
	sb.set_corner_radius_all(8)
	# 仙品边框高亮
	if 稀有度 == "仙品":
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.95, 0.75, 0.2, 0.6)
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("margin_left", 16)
	vbox.add_theme_constant_override("margin_right", 16)
	vbox.add_theme_constant_override("margin_top", 12)
	vbox.add_theme_constant_override("margin_bottom", 12)
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	vbox.modulate.a = 0.0
	vbox.create_tween().tween_property(vbox, "modulate:a", 1.0, 0.25)

	# 名称行（名称+稀有度标签）
	var 名行 := HBoxContainer.new()
	名行.add_theme_constant_override("separation", 8)
	vbox.add_child(名行)
	名行.modulate.a = 0.0
	名行.create_tween().tween_property(名行, "modulate:a", 1.0, 0.25)

	var 名 := Label.new()
	名.text = 名称 if 已收录 else "？？？"
	UITheme.apply_body_text(名)
	名.add_theme_color_override("font_color", UITheme.获取主文字色())
	名行.add_child(名)
	名.modulate.a = 0.0
	名.create_tween().tween_property(名, "modulate:a", 1.0, 0.25)

	var 稀有标签 := Label.new()
	稀有标签.text = "【%s】" % 稀有度
	UITheme.apply_aux_text(稀有标签)
	稀有标签.add_theme_color_override("font_color", 稀有度颜色.get(稀有度, Color(0.6, 0.6, 0.6)))
	名行.add_child(稀有标签)
	稀有标签.modulate.a = 0.0
	稀有标签.create_tween().tween_property(稀有标签, "modulate:a", 1.0, 0.25)

	# 描述
	if 已收录 and 描述 != "":
		var 描述标签 := Label.new()
		描述标签.text = 描述
		描述标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_aux_text(描述标签)
		描述标签.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		vbox.add_child(描述标签)
		描述标签.modulate.a = 0.0
		描述标签.create_tween().tween_property(描述标签, "modulate:a", 1.0, 0.25)

	# 元信息
	var 元 := Label.new()
	元.text = "%s · %s" % [新类别, 稀有度]
	UITheme.apply_aux_text(元)
	元.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(元)
	元.modulate.a = 0.0
	元.create_tween().tween_property(元, "modulate:a", 1.0, 0.25)

	# 状态
	var 状态 := Label.new()
	if 已捐赠:
		状态.text = "已供奉"
	elif 已收录:
		状态.text = "在册"
	else:
		状态.text = "未见"
	UITheme.apply_aux_text(状态)
	if 已捐赠:
		状态.add_theme_color_override("font_color", UITheme.color_text_title1())
	elif 已收录:
		状态.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		状态.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(状态)
	状态.modulate.a = 0.0
	状态.create_tween().tween_property(状态, "modulate:a", 1.0, 0.25)

	# 供奉按钮（仅仙品且已收录且未供奉）
	if 稀有度 == "仙品" and 已收录 and not 已捐赠:
		var btn := Button.new()
		btn.name = "Donate"
		btn.text = "供奉藏宝阁"
		btn.custom_minimum_size = Vector2(0, 32)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		UITheme.apply_button_label(btn, true)
		btn.pressed.connect(_on_捐赠.bind(图录ID, btn))
		vbox.add_child(btn)
		btn.modulate.a = 0.0
		btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)
	elif 已捐赠:
		var btn := Button.new()
		btn.name = "Donated"
		btn.text = "已供奉"
		btn.custom_minimum_size = Vector2(0, 32)
		btn.disabled = true
		UITheme.apply_button_label(btn, false)
		btn.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		vbox.add_child(btn)
		btn.modulate.a = 0.0
		btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)

	return card

func _on_捐赠(图录ID: String, btn: Button) -> void:
	if btn != null:
		UITween.button_press(btn)
	if not is_instance_valid(Game) or not Game.has_method("捐赠图录"):
		_toast("典藏功法未就绪")
		return
	var res: Dictionary = Game.捐赠图录(图录ID)
	_toast(str(res.get("msg", "供奉完成")))
	refresh()

func _on_图录更新() -> void:
	refresh()

func _toast(t: String) -> void:
	if is_instance_valid(Game) and Game.has_method("toast"):
		Game.添加提示(t)

func _取类别列表() -> Array:
	# 返回五大类（按顺序）
	var 列表: Array = ["全部"]
	列表.append_array(大类顺序)
	return 列表

func _on_back_pressed() -> void:
	返回主页.emit()

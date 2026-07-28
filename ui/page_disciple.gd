extends Control

# 弟子页（§3 · 高频核心）：只读展示 弟子列表 + 接引决策区 + 弟子详情二级页（页内子视图）。
# 零 GameState 写入；所有交互控件仅 emit 占位信号。读数统一经 is_instance_valid(Game) + .get() 守卫。
# 备注：命格 字段已于 2026-07-19 重构为 destiny_id，故本页用 destiny_id + DestinyDataLoader 解析名称，
#       资质 用 Disciple.资质显示 查表；二者均带安全 fallback，缺失即 "—"，绝不崩。

const DiscipleData := preload("res://disciple.gd")
const DestinyLoader := preload("res://DestinyDataLoader.gd")

signal 弟子详情请求(弟子ID: int)
signal 弟子排序请求(模式: String)
signal 待抉择_交宗(索引: int)
signal 待抉择_自留(索引: int)
signal 弟子详情返回()

var _built: bool = false
var _list_root: Control
var _detail_root: Control
var _power_value: Label
var _list_vbox: VBoxContainer
var _decision_body: Control
var _detail_vbox: VBoxContainer
var _row_map: Dictionary = {}

func _ready() -> void:
	_build()
	refresh()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_list_root = VBoxContainer.new()
	_list_root.name = "ListRoot"
	_list_root.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_list_root.add_theme_constant_override("margin_right", UITheme.MARGIN)
	_list_root.add_theme_constant_override("margin_top", UITheme.GRID)
	_list_root.add_theme_constant_override("margin_bottom", UITheme.GRID)
	_list_root.add_theme_constant_override("separation", UITheme.GRID * 2)
	_list_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_list_root)
	_build_list_header()
	_build_list_scroll()
	_build_decision_area()

	_detail_root = VBoxContainer.new()
	_detail_root.name = "DetailRoot"
	_detail_root.visible = false
	_detail_root.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_detail_root.add_theme_constant_override("margin_right", UITheme.MARGIN)
	_detail_root.add_theme_constant_override("margin_top", UITheme.GRID)
	_detail_root.add_theme_constant_override("margin_bottom", UITheme.GRID)
	_detail_root.add_theme_constant_override("separation", UITheme.GRID * 2)
	_detail_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_detail_root)
	_build_detail_root()

func _build_list_header() -> void:
	var panel := PanelContainer.new()
	panel.name = "Header"
	panel.custom_minimum_size = Vector2(0, UITheme.GRID * 7)
	UITheme.apply_panel_style(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(hb)

	var 图标 = UITheme.load_icon("弟子")
	if 图标 != null:
		var tr := TextureRect.new()
		tr.texture = 图标
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.custom_minimum_size = Vector2(24, 24)
		hb.add_child(tr)

	var title := Label.new()
	title.text = "弟子录"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UITheme.apply_title_font(title)
	hb.add_child(title)

	var power_box := VBoxContainer.new()
	power_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var cap := Label.new()
	cap.text = "总战力"
	UITheme.apply_aux_font(cap)
	power_box.add_child(cap)
	_power_value = Label.new()
	_power_value.text = "—"
	UITheme.apply_value_font(_power_value, false)
	power_box.add_child(_power_value)
	hb.add_child(power_box)

	var sort_btn := Button.new()
	sort_btn.name = "SortBtn"
	sort_btn.text = "排序"
	sort_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	sort_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	UITheme.apply_secondary_button_style(sort_btn)
	sort_btn.pressed.connect(_on_sort_pressed)
	hb.add_child(sort_btn)

	_list_root.add_child(panel)

func _build_list_scroll() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_root.add_child(scroll)
	_list_vbox = VBoxContainer.new()
	_list_vbox.name = "ListVBox"
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(_list_vbox)

func _build_decision_area() -> void:
	var panel := PanelContainer.new()
	panel.name = "DecisionPanel"
	panel.custom_minimum_size = Vector2(0, UITheme.GRID * 15)
	UITheme.apply_panel_style(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "接引决策"
	UITheme.apply_title_font(title)
	vbox.add_child(title)
	_decision_body = Control.new()
	_decision_body.name = "DecisionBody"
	_decision_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_decision_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_decision_body)
	_list_root.add_child(panel)

func _build_detail_root() -> void:
	var bar := HBoxContainer.new()
	bar.name = "BackBar"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	var back_btn := Button.new()
	back_btn.name = "BackBtn"
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	UITheme.apply_secondary_button_style(back_btn)
	back_btn.pressed.connect(_on_back_pressed)
	bar.add_child(back_btn)
	var title := Label.new()
	title.text = "弟子详情"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_title_font(title)
	bar.add_child(title)
	_detail_root.add_child(bar)

	var scroll := ScrollContainer.new()
	scroll.name = "DetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_root.add_child(scroll)
	_detail_vbox = VBoxContainer.new()
	_detail_vbox.name = "DetailVBox"
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	scroll.add_child(_detail_vbox)

# ───────── 只读刷新（公共，镜像 sect_home_page.refresh_overview）─────────
func refresh() -> void:
	if not _built:
		_build()
	_populate_list()
	_populate_decision()

func _populate_list() -> void:
	if _list_vbox == null:
		return
	for child in _list_vbox.get_children():
		_list_vbox.remove_child(child)
		child.queue_free()
	_row_map.clear()
	var power: int = 0
	if not is_instance_valid(Game):
		_power_value.text = "—"
		return
	var 列表 = Game.get("弟子列表")
	if 列表 == null or not (列表 is Array):
		_power_value.text = "—"
		return
	for i in range(列表.size()):
		var d = 列表[i]
		if d == null:
			continue
		var 战力值 = _safe_get(d, "战力", null)
		if typeof(战力值) == TYPE_INT or typeof(战力值) == TYPE_FLOAT:
			power += int(战力值)
		_row_map[i] = d
		_add_disciple_row(d, i)
	_power_value.text = str(power)

func _add_disciple_row(d: Object, 索引: int) -> void:
	var row := PanelContainer.new()
	row.name = "Row_%d" % 索引
	row.custom_minimum_size = Vector2(0, UITheme.GRID * 9)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	UITheme.apply_panel_style(row)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	row.add_child(hb)

	var 姓名 := Label.new()
	姓名.text = str(_safe_get(d, "姓名", "—"))
	姓名.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_body_font(姓名)
	hb.add_child(姓名)

	var 境界 := Label.new()
	境界.text = str(_safe_get(d, "境界", "—"))
	UITheme.apply_aux_font(境界)
	hb.add_child(境界)

	var 战力v = _safe_get(d, "战力", null)
	var 战力文本 := "战力 —"
	var 战力异常 := false
	if 战力v != null and (typeof(战力v) == TYPE_INT or typeof(战力v) == TYPE_FLOAT):
		战力异常 = int(战力v) < 0
		战力文本 = "战力 " + str(int(战力v))
	var 战力标签 := Label.new()
	战力标签.text = 战力文本
	UITheme.apply_value_font(战力标签, 战力异常)
	hb.add_child(战力标签)

	var 状态 := Label.new()
	状态.text = _derive_status(d)
	UITheme.apply_aux_font(状态)
	hb.add_child(状态)

	_list_vbox.add_child(row)
	_list_vbox.add_child(UITheme.make_divider_control())
	_pass_through(row)
	row.gui_input.connect(_on_row_gui_input.bind(索引))

func _derive_status(d: Object) -> String:
	var 堂口 = _safe_get(d, "堂口", "")
	if 堂口 == "" or 堂口 == null:
		return "未入门"
	var 突破 = _safe_get(d, "突破冷却剩余", 0)
	if typeof(突破) == TYPE_FLOAT or typeof(突破) == TYPE_INT:
		if float(突破) > 0.0:
			return "闭关养伤"
	var 考核 = _safe_get(d, "考核冷却剩余", 0)
	if typeof(考核) == TYPE_INT or typeof(考核) == TYPE_FLOAT:
		if int(考核) > 0:
			return "考核冷却"
	return "在岗"

func _on_row_gui_input(event: InputEvent, 索引: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			弟子详情请求.emit(索引)
			_show_detail(索引)

func _show_detail(索引: int) -> void:
	var d = _row_map.get(索引, null)
	if d == null:
		return
	_populate_detail(d, 索引)
	_list_root.visible = false
	_detail_root.visible = true

func _on_back_pressed() -> void:
	弟子详情返回.emit()
	_detail_root.visible = false
	_list_root.visible = true

func _populate_decision() -> void:
	if _decision_body == null:
		return
	for child in _decision_body.get_children():
		_decision_body.remove_child(child)
		child.queue_free()
	if not is_instance_valid(Game):
		_add_decision_empty()
		return
	var 待抉择 = Game.get("待抉择")
	if 待抉择 == null or not (待抉择 is Array) or 待抉择.size() == 0:
		_add_decision_empty()
		return
	var hscroll := HScrollContainer.new()
	hscroll.name = "Cards"
	hscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_ENABLED
	hscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_decision_body.add_child(hscroll)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", UITheme.GRID)
	hscroll.add_child(cards)
	for k in range(待抉择.size()):
		var entry = 待抉择[k]
		if entry == null or not (entry is Dictionary):
			continue
		_add_decision_card(entry, k, cards)

func _add_decision_empty() -> void:
	var lbl := Label.new()
	lbl.text = "暂无待抉择"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UITheme.apply_aux_font(lbl)
	_decision_body.add_child(lbl)

func _add_decision_card(entry: Dictionary, 索引: int, parent: Control) -> void:
	var card := PanelContainer.new()
	card.name = "Card_%d" % 索引
	card.custom_minimum_size = Vector2(120, 200)
	UITheme.apply_panel_style(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	card.add_child(vbox)

	var 弟子obj = entry.get("弟子", null)
	var 弟子名 := "—"
	if 弟子obj != null and 弟子obj is Object:
		弟子名 = str(_safe_get(弟子obj, "姓名", "—"))
	var 名 := Label.new()
	名.text = 弟子名
	UITheme.apply_body_font(名)
	vbox.add_child(名)

	var 物品obj = entry.get("物品", null)
	var 物品名 := "—"
	if 物品obj != null and 物品obj is Object:
		物品名 = str(_safe_get(物品obj, "名称", "—"))
	var 物 := Label.new()
	物.text = "得【%s】" % 物品名
	UITheme.apply_aux_font(物)
	vbox.add_child(物)

	var 文案 = entry.get("文本", "")
	var 文 := Label.new()
	文.text = str(文案)
	文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_font(文)
	vbox.add_child(文)

	vbox.add_spacer(true)

	var 交宗 := Button.new()
	交宗.name = "Accept_%d" % 索引
	交宗.text = "交宗"
	交宗.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	UITheme.apply_secondary_button_style(交宗)
	交宗.pressed.connect(_on_待抉择_交宗.bind(索引))
	vbox.add_child(交宗)

	var 自留 := Button.new()
	自留.name = "Keep_%d" % 索引
	自留.text = "自留"
	自留.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	UITheme.apply_secondary_button_style(自留)
	自留.pressed.connect(_on_待抉择_自留.bind(索引))
	vbox.add_child(自留)

	parent.add_child(card)

func _on_sort_pressed() -> void:
	弟子排序请求.emit("战力降")

func _on_待抉择_交宗(索引: int) -> void:
	待抉择_交宗.emit(索引)

func _on_待抉择_自留(索引: int) -> void:
	待抉择_自留.emit(索引)

# ───────── 弟子详情二级页（页内子视图，仅读 + 占位信号）─────────
func _populate_detail(d: Object, 索引: int) -> void:
	if _detail_vbox == null:
		return
	for child in _detail_vbox.get_children():
		_detail_vbox.remove_child(child)
		child.queue_free()

	var 基本信息: Array = [
		["姓名", str(_safe_get(d, "姓名", "—"))],
		["道号", str(_safe_get(d, "道号", "—"))],
		["身份", str(_safe_get(d, "身份", "—"))],
		["阶位", str(_safe_get(d, "阶位", "—"))],
		["来源", str(_safe_get(d, "来源", "—"))],
		["备注", str(_safe_get(d, "备注", "—"))],
	]
	_add_section("基本信息", 基本信息)

	var 资质key = _safe_get(d, "资质", "")
	var 资质文本 := "—"
	if 资质key != "" and 资质key != null:
		资质文本 = str(资质key)
		if DiscipleData != null and DiscipleData.get("资质显示") != null:
			var 映射 = DiscipleData.资质显示
			if 映射 is Dictionary:
				资质文本 = str(映射.get(资质key, 资质key))
	var did = _safe_get(d, "destiny_id", "")
	var 命格文本 := "—"
	if did != "" and did != null:
		if DestinyLoader != null and DestinyLoader.has_method("get_destiny"):
			var dt = DestinyLoader.get_destiny(str(did))
			if dt is Dictionary:
				命格文本 = str(dt.get("名称", did))
		else:
			命格文本 = str(did)
	var 职业v = _safe_get(d, "职业", "")
	var 职业文本 = "未入门" if (职业v == "" or 职业v == null) else str(职业v)
	var 资质灵根: Array = [
		["资质", 资质文本],
		["灵根", str(_safe_get(d, "灵根", "—"))],
		["灵根品阶", str(_safe_get(d, "灵根品阶", "—"))],
		["命格", 命格文本],
		["性格", str(_safe_get(d, "性格", "—"))],
		["职业", 职业文本],
	]
	_add_section("资质灵根", 资质灵根)

	var 进度v = _safe_get(d, "修炼进度", 0.0)
	var 进度文本 := "—"
	if typeof(进度v) == TYPE_FLOAT or typeof(进度v) == TYPE_INT:
		进度文本 = "%d%%" % int(float(进度v) * 100.0)
	var 年龄v = _safe_get(d, "年龄", 0.0)
	var 年龄文本 := "—"
	if typeof(年龄v) == TYPE_FLOAT or typeof(年龄v) == TYPE_INT:
		年龄文本 = "%.0f岁" % float(年龄v)
	var 修炼状态: Array = [
		["境界", str(_safe_get(d, "境界", "—"))],
		["层数", str(_safe_get(d, "层数", "—"))],
		["修炼进度", 进度文本],
		["寿元", str(_safe_get(d, "寿元", "—"))],
		["年龄", 年龄文本],
		["突破冷却剩余", str(_safe_get(d, "突破冷却剩余", "—"))],
		["瓶颈打磨值", str(_safe_get(d, "瓶颈打磨值", "—"))],
		["稳固期剩余", str(_safe_get(d, "稳固期剩余", "—"))],
		["丹毒", str(_safe_get(d, "丹毒", "—"))],
	]
	_add_section("修炼状态", 修炼状态)

	var 任职: Array = [
		["堂口", str(_safe_get(d, "堂口", "—"))],
		["阶位", str(_safe_get(d, "阶位", "—"))],
		["考核冷却剩余", str(_safe_get(d, "考核冷却剩余", "—"))],
		["考核心得", str(_safe_get(d, "考核心得", "—"))],
	]
	_add_section("任职", 任职)

	var 属性 = _safe_get(d, "属性", {})
	var 四维: Array = [
		["攻", _attr(属性, "攻")],
		["防", _attr(属性, "防")],
		["血", _attr(属性, "血")],
		["速", _attr(属性, "速")],
	]
	_add_section("四维", 四维)

	var 纪事行: Array = []
	if is_instance_valid(Game) and Game.has_method("取弟子纪事"):
		var 姓名v = str(_safe_get(d, "姓名", ""))
		var 纪事条目 = Game.取弟子纪事(索引, 姓名v)
		if 纪事条目 is Array and 纪事条目.size() > 0:
			for e in 纪事条目:
				if e is Dictionary:
					纪事行.append(["第%s日" % str(e.get("日", "—")), str(e.get("名称", "—"))])
	if 纪事行.is_empty():
		纪事行.append(["", "暂无个人纪事"])
	_add_section("个人纪事", 纪事行)

func _attr(属性, key: String) -> String:
	if 属性 is Dictionary:
		return str(属性.get(key, "—"))
	return "—"

func _add_section(标题: String, 行: Array) -> void:
	var panel := PanelContainer.new()
	panel.name = "Section_%s" % 标题
	UITheme.apply_panel_style(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)
	var t := Label.new()
	t.text = 标题
	UITheme.apply_title_font(t)
	vbox.add_child(t)
	for r in 行:
		var caption: String = r[0]
		var value: String = r[1]
		var abnormal: bool = r[2] if r.size() > 2 else false
		_add_kv(vbox, caption, value, abnormal)
	_detail_vbox.add_child(panel)

func _add_kv(parent: Control, caption: String, value: String, abnormal: bool) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var c := Label.new()
	c.text = caption
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.custom_minimum_size = Vector2(96, 0)
	UITheme.apply_aux_font(c)
	hb.add_child(c)
	var v := Label.new()
	v.text = value
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if abnormal:
		UITheme.apply_value_font(v, true)
	else:
		UITheme.apply_body_font(v)
	hb.add_child(v)
	parent.add_child(hb)

func _safe_get(obj: Variant, prop: String, default: Variant = null) -> Variant:
	if obj == null:
		return default
	if obj is Dictionary:
		return obj.get(prop, default)
	if obj is Object:
		var v = obj.get(prop)
		return v if v != null else default
	return default

# 让 PanelContainer 行整体可点：除 Button 外所有子节点设为 IGNORE，事件穿透到 PanelContainer。
func _pass_through(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			_pass_through(child)
			continue
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pass_through(child)

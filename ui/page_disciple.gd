extends Control

# 弟子页（§3 · 高频核心）：只读展示 弟子列表 + 接引决策区 + 弟子详情二级页（页内子视图）。
# 零 GameState 写入；所有交互控件仅 emit 占位信号。读数统一经 is_instance_valid(Game) + .get() 守卫。
# 备注：命格 字段已于 2026-07-19 重构为 destiny_id，故本页用 destiny_id + DestinyDataLoader 解析名称，
#       资质 用 Disciple.资质显示 查表；二者均带安全 fallback，缺失即 "—"，绝不崩。
#
# P1 品质升级（依据 design/06-角色与UI/P1-二级详情页设计规格.md §3）：
#   - 6 个 section 统一用 UITheme.make_panel_stylebox flat 面板包裹（apply_panel_style）。
#   - KV 行沿用 _add_kv，统一 UITheme 令牌字号；动态色走 UIThemeConfig（境界→REALM_COLOR / 品阶→QUALITY_COLOR / 异常→STATE_COLOR.danger）。
#   - 修炼进度/瓶颈打磨/丹毒(心魔代理)/道心(占位) 做 ProgressBar 可视化（UITheme 配色）。
#   - 动效统一 UITween：_show_detail 淡入；所有原生 Button pressed 接 button_press。
#   - 红点（本地标记位，无全局管理器）：突破(danger)/互动(暗金)/状态警示(danger)/装备(暗金)。
#   - 新增「装备」section：遍历 装备 Dict，每槽 ItemSlot 展示，品阶色接 UIThemeConfig。

const DiscipleData := preload("res://disciple.gd")
const DestinyLoader := preload("res://DestinyDataLoader.gd")
const ListItemScene: PackedScene = preload("res://components/ListItem.tscn")
const ItemSlotScene: PackedScene = preload("res://components/ItemSlot.tscn")

signal 弟子详情请求(弟子ID: int)
signal 弟子排序请求(模式: String)
signal 待抉择_交宗(索引: int)
signal 待抉择_自留(索引: int)
signal 弟子详情返回()
signal 弟子装备查看请求(弟子ID: int)

# ───────── 品阶/境界 中文 → UIThemeConfig stem 私有映射表（设计规格 §3.1 / 附录A）─────────
# 弟子.灵根品阶 取值域 = 凡品/良品/上品/极品/天品（5 档）→ QUALITY_COLOR 8 档近似映射。
const _LINGGEN_QUALITY_STEM: Dictionary = {
	"凡品": "fan",
	"良品": "liang",
	"上品": "ling",
	"极品": "wang",
	"天品": "xian",
}
# 装备 Item.品阶 真实取值域 = 凡阶/灵阶/宝阶/王阶/圣阶/仙阶/道阶（七品阶）→ QUALITY_COLOR 直映。
const _ITEM_QUALITY_STEM: Dictionary = {
	"凡阶": "fan",
	"灵阶": "ling",
	"宝阶": "bao",
	"王阶": "wang",
	"圣阶": "sheng",
	"仙阶": "xian",
	"道阶": "dao",
}
# 弟子.境界 取值域 = 练气/筑基/金丹/元婴/化神/仙阶/道阶（7 档）→ REALM_COLOR 仅 5 档；
# 仙阶/道阶 无对应 realm stem，回落化神色（避免 set_realm_color 警告；业务层补境界色后替换）。
const _REALM_STEM: Dictionary = {
	"练气": "lianqi",
	"筑基": "zhuji",
	"金丹": "jindan",
	"元婴": "yuanying",
	"化神": "huashen",
	"仙阶": "huashen",
	"道阶": "huashen",
}
# 装备槽位 key（= Item.穿戴位）→ 中文显示名，对齐 item.gd 槽显示。
const _EQUIP_SLOT_KEYS: Array = ["wuqi", "toukui", "yipao", "huzhi", "yaodai", "changku", "xuezi", "peishi", "本命法宝"]
const _EQUIP_SLOT_CN: Dictionary = {
	"wuqi": "法兵", "toukui": "道冠", "yipao": "法袍", "huzhi": "灵腕",
	"yaodai": "束灵带", "changku": "灵裤", "xuezi": "云靴", "peishi": "灵饰", "本命法宝": "本命法宝",
}
const _EQUIP_SLOT_COUNT: int = 9

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
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(hb)

	var 图标 = UITheme.load_icon_sized("弟子", UITheme.SIZE_SM)
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
	sort_btn.pressed.connect(_on_btn_press.bind(sort_btn, _on_sort_pressed))
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
	_list_vbox.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_list_vbox)

func _build_decision_area() -> void:
	var panel := PanelContainer.new()
	panel.name = "DecisionPanel"
	panel.custom_minimum_size = Vector2(0, UITheme.GRID * 15)
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
	back_btn.pressed.connect(_on_btn_press.bind(back_btn, _on_back_pressed))
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
	var 战力v = _safe_get(d, "战力", null)
	var 战力异常 := false
	var 战力文本 := "战力 —"
	if 战力v != null and (typeof(战力v) == TYPE_INT or typeof(战力v) == TYPE_FLOAT):
		战力异常 = int(战力v) < 0
		战力文本 = "战力 " + str(int(战力v))
	var 境界 = str(_safe_get(d, "境界", "—"))
	var 状态 = _derive_status(d)

	# 改用通用组件 ListItem（令牌 flat 面板 + 单行 title/subtitle/value/icon）。
	# 原行「境界」「状态」两字段合并进 subtitle；战力为负经 value_abnormal 标红。
	var 行 = ListItemScene.instantiate() as PanelContainer
	行.name = "Row_%d" % 索引
	行.custom_minimum_size = Vector2(0, UITheme.GRID * 9)
	行.set_data({
		"title": str(_safe_get(d, "姓名", "—")),
		"subtitle": "%s · %s" % [境界, 状态],
		"value": 战力文本,
		"icon": "弟子",
		"index": 索引,
		"value_abnormal": 战力异常,
	})
	行.item_selected.connect(_on_disciple_item_selected)
	_list_vbox.add_child(行)
	_list_vbox.add_child(UITheme.make_divider_control())

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

func _on_disciple_item_selected(data: Dictionary) -> void:
	var 索引 = int(data.get("index", -1))
	if 索引 < 0:
		return
	弟子详情请求.emit(索引)
	_show_detail(索引)

func _show_detail(索引: int) -> void:
	var d = _row_map.get(索引, null)
	if d == null:
		return
	_populate_detail(d, 索引)
	_list_root.visible = false
	# 动效（设计规格 §3.3）：对整个 _detail_root 淡入，替代直接 visible=true。
	UITween.fade_in(_detail_root)

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
	var hscroll := ScrollContainer.new()
	hscroll.name = "Cards"
	hscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
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
	交宗.pressed.connect(_on_btn_press.bind(交宗, _on_待抉择_交宗.bind(索引)))
	vbox.add_child(交宗)

	var 自留 := Button.new()
	自留.name = "Keep_%d" % 索引
	自留.text = "自留"
	自留.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	自留.pressed.connect(_on_btn_press.bind(自留, _on_待抉择_自留.bind(索引)))
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

	# ── 数值安全抽取（避免 Object/ Dict 类型差异与 nil 崩溃）──
	var 进度raw = _safe_get(d, "修炼进度", 0.0)
	var 进度v: float = float(进度raw) if (typeof(进度raw) in [TYPE_FLOAT, TYPE_INT]) else 0.0
	var 层数raw = _safe_get(d, "层数", 0)
	var 层数v: int = int(层数raw) if (typeof(层数raw) in [TYPE_FLOAT, TYPE_INT]) else 0
	var 打磨raw = _safe_get(d, "瓶颈打磨值", 0.0)
	var 打磨v: float = float(打磨raw) if (typeof(打磨raw) in [TYPE_FLOAT, TYPE_INT]) else 0.0
	var 冷却raw = _safe_get(d, "突破冷却剩余", 0.0)
	var 冷却v: float = float(冷却raw) if (typeof(冷却raw) in [TYPE_FLOAT, TYPE_INT]) else 0.0
	var 丹毒raw = _safe_get(d, "丹毒", 0.0)
	var 丹毒v: float = float(丹毒raw) if (typeof(丹毒raw) in [TYPE_FLOAT, TYPE_INT]) else 0.0

	# ── 红点本地判定（设计规格 §3.4，仅展示，绝不写 GameState）──
	var 突破红点 := false
	if (进度v >= 1.0 and 层数v < 10) or (层数v >= 10 and 打磨v >= 1.0 and 冷却v <= 0.0):
		突破红点 = true
	var 丹毒警示: bool = 丹毒v >= 0.5
	var 冷却警示: bool = 冷却v > 0.0
	var 有抉择 := false
	if is_instance_valid(Game):
		var 待抉择 = Game.get("待抉择")
		if 待抉择 is Array and 待抉择.size() > 0:
			有抉择 = true

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
		var 映射 = DiscipleData.资质显示
		if 映射 is Dictionary:
			资质文本 = str(映射.get(资质key, 资质key))
	var did = _safe_get(d, "destiny_id", "")
	var 命格文本 := "—"
	if did != "" and did != null:
		var dt = DestinyLoader.get_destiny(str(did))
		if dt is Dictionary:
			命格文本 = str(dt.get("名称", did))
		else:
			命格文本 = str(did)
	var 职业v = _safe_get(d, "职业", "")
	var 职业文本 = "未入门" if (职业v == "" or 职业v == null) else str(职业v)
	var 灵根品阶文本 = str(_safe_get(d, "灵根品阶", "—"))
	var 灵根stem = _LINGGEN_QUALITY_STEM.get(灵根品阶文本, "fan")
	var 灵根色 = UIThemeConfig.get_quality_color(灵根stem)
	var 资质灵根: Array = [
		["资质", 资质文本],
		["灵根", str(_safe_get(d, "灵根", "—"))],
		["灵根品阶", 灵根品阶文本, false, 灵根色],
		["命格", 命格文本],
		["性格", str(_safe_get(d, "性格", "—"))],
		["职业", 职业文本],
	]
	_add_section("资质灵根", 资质灵根)

	var 进度文本 := "—"
	if typeof(进度raw) == TYPE_FLOAT or typeof(进度raw) == TYPE_INT:
		进度文本 = "%d%%" % int(进度v * 100.0)
	var 年龄raw = _safe_get(d, "年龄", 0.0)
	var 年龄文本 := "—"
	if typeof(年龄raw) == TYPE_FLOAT or typeof(年龄raw) == TYPE_INT:
		年龄文本 = "%.0f岁" % float(年龄raw)
	var 境界文本 = str(_safe_get(d, "境界", "—"))
	var 境界stem = _REALM_STEM.get(境界文本, "huashen")
	var 境界色 = UIThemeConfig.get_realm_color(境界stem)
	var 修炼状态: Array = [
		["境界", 境界文本, false, 境界色],
		["层数", str(_safe_get(d, "层数", "—"))],
		["修炼进度", 进度文本],
		["寿元", str(_safe_get(d, "寿元", "—"))],
		["年龄", 年龄文本],
		["突破冷却剩余", str(_safe_get(d, "突破冷却剩余", "—")), 冷却警示],
		["瓶颈打磨值", str(_safe_get(d, "瓶颈打磨值", "—"))],
		["稳固期剩余", str(_safe_get(d, "稳固期剩余", "—"))],
		["丹毒", str(_safe_get(d, "丹毒", "—")), 丹毒警示],
	]
	# 进度可视化（设计规格 §3.2）：修为/打磨/丹毒(心魔代理)/道心(占位) 进度条。
	var 修炼状态_extra: Array = []
	修炼状态_extra.append(_make_progress("修炼进度", 进度v, UITheme.COLOR_TEXT_GOLD))
	修炼状态_extra.append(_make_progress("瓶颈打磨", 打磨v, UITheme.COLOR_STATUS_SUCCESS))
	var 丹毒色 = UITheme.COLOR_STATUS_SUCCESS if 丹毒v < 0.5 else UITheme.COLOR_TEXT_RED
	修炼状态_extra.append(_make_progress("丹毒(心魔风险)", 丹毒v, 丹毒色))
	修炼状态_extra.append(_make_progress("道心(待实装)", 0.0, UITheme.COLOR_TEXT_AUX))
	_add_section("修炼状态", 修炼状态, "danger" if 突破红点 else "", 修炼状态_extra)

	var 任职: Array = [
		["堂口", str(_safe_get(d, "堂口", "—"))],
		["阶位", str(_safe_get(d, "阶位", "—"))],
		["考核冷却剩余", str(_safe_get(d, "考核冷却剩余", "—"))],
		["考核心得", str(_safe_get(d, "考核心得", "—"))],
	]
	_add_section("任职", 任职, "gold" if 有抉择 else "")

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

	# 新增「装备」section（设计规格 §3.1 装备行）；装备红点：存在空槽(<9) 亮暗金点。
	var 装备d = _safe_get(d, "装备", {})
	var 装备红点 := false
	if 装备d is Dictionary and 装备d.size() < _EQUIP_SLOT_COUNT:
		装备红点 = true
	_add_equip_section("装备", d, "gold" if 装备红点 else "", 索引, 装备d)

func _attr(属性, key: String) -> String:
	if 属性 is Dictionary:
		return str(属性.get(key, "—"))
	return "—"

# ───────── section 构建（flat 面板包裹 + 标题红点 + KV 行 + 额外控件）─────────
func _add_section(标题: String, 行: Array, dot_type: String = "", extra: Array = []) -> void:
	var panel := PanelContainer.new()
	panel.name = "Section_%s" % 标题
	UITheme.apply_panel_style(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)
	vbox.add_child(_make_section_title(标题, dot_type))
	for r in 行:
		var caption: String = str(r[0])
		var value: String = str(r[1]) if r.size() > 1 else ""
		var abnormal: bool = r[2] if r.size() > 2 else false
		var color_override: Color = r[3] if r.size() > 3 else Color.WHITE
		_add_kv(vbox, caption, value, abnormal, color_override)
	for ex in extra:
		if ex is Control:
			vbox.add_child(ex)
	_detail_vbox.add_child(panel)

func _add_equip_section(标题: String, d: Object, dot_type: String, 索引: int, 装备d: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "Section_%s" % 标题
	UITheme.apply_panel_style(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)
	vbox.add_child(_make_section_title(标题, dot_type))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("hseparation", UITheme.GRID)
	grid.add_theme_constant_override("vseparation", UITheme.GRID)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)
	for slot_key in _EQUIP_SLOT_KEYS:
		var slot_cn: String = _EQUIP_SLOT_CN.get(slot_key, slot_key)
		var it = _safe_get(装备d, slot_key, null)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", UITheme.GRID / 2)
		cell.custom_minimum_size = Vector2(0, UITheme.SIZE_SM + UITheme.GRID * 3)
		var slot: PanelContainer = ItemSlotScene.instantiate()
		slot.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		var cap := Label.new()
		if it != null:
			var 名 = str(_safe_get(it, "名称", "装备"))
			var 品阶cn = str(_safe_get(it, "品阶", "凡阶"))
			var stem = _ITEM_QUALITY_STEM.get(品阶cn, "fan")
			slot.set_item(名, 1, stem)
			slot.clicked.connect(_on_equip_clicked.bind(索引))
			cap.text = "%s·%s" % [slot_cn, 名]
		else:
			cap.text = "%s·空" % slot_cn
		UITheme.apply_aux_font(cap)
		cell.add_child(slot)
		cell.add_child(cap)
		grid.add_child(cell)
		# 空槽灰显（ItemSlot._ready 已染白，入树后覆盖为 disabled 灰）。
		if it == null:
			slot.modulate = UIThemeConfig.get_state_color("disabled")
	_detail_vbox.add_child(panel)

func _make_section_title(标题: String, dot_type: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var t := Label.new()
	t.text = 标题
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_title_font(t)
	hb.add_child(t)
	if dot_type != "":
		hb.add_child(_make_red_dot(dot_type == "danger"))
	return hb

func _make_red_dot(danger: bool) -> Control:
	var dot := ColorRect.new()
	dot.name = "RedDot"
	dot.custom_minimum_size = Vector2(UITheme.GRID, UITheme.GRID)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if danger:
		dot.color = UIThemeConfig.get_state_color("danger")
	else:
		dot.color = UIThemeConfig.get_state_color("gold")
	return dot

# 自绘进度条（设计规格 §2.4 / §3.2）：track=COLOR_BG_CONTENT，fill 传入配色；禁用内置百分比，自绘 % 标签。
func _make_progress(caption: String, ratio: float, fill_color: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.GRID / 2)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var c := Label.new()
	c.text = caption
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UITheme.apply_aux_font(c)
	hb.add_child(c)
	var pct := Label.new()
	pct.text = "%d%%" % int(clamp(ratio, 0.0, 1.0) * 100.0)
	UITheme.apply_value_font(pct, false)
	hb.add_child(pct)
	box.add_child(hb)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.01
	bar.value = clamp(ratio, 0.0, 1.0)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, UITheme.GRID * 2)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.COLOR_BG_CONTENT
	bg.set_corner_radius_all(UITheme.RADIUS_BUTTON)
	bg.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(UITheme.RADIUS_BUTTON)
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("disabled", bg)
	box.add_child(bar)
	return box

func _add_kv(parent: Control, caption: String, value: String, abnormal: bool, color_override: Color = Color.WHITE) -> void:
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
	elif color_override != Color.WHITE:
		UITheme.apply_body_font(v)
		v.add_theme_color_override("font_color", color_override)
	else:
		UITheme.apply_body_font(v)
	hb.add_child(v)
	parent.add_child(hb)

func _on_equip_clicked(item_id: String, 索引: int) -> void:
	# 仅占位信号（设计规格 §3.5：装备仅展示，不接穿戴/强化逻辑）。
	弟子装备查看请求.emit(索引)

# 原生 Button pressed 统一接 UITween.button_press（设计规格 §3.3），再触发业务回调。
func _on_btn_press(btn: Control, cb: Callable) -> void:
	UITween.button_press(btn)
	cb.call()

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

extends Control

# 修真设定（2026-09-01）：命魂灯只表示生死二态——亮(生还)/灭(陨落)。
# 失踪/闭关/历练中/秘境 等活动信息不再由命魂灯表达，统一移至弟子卡片状态栏文字标签。
const _SOUL_LAMP_ALIVE = preload("res://assets/ui/icons/soul_lamp_alive.png")
const _SOUL_LAMP_DEAD = preload("res://assets/ui/icons/soul_lamp_dead.png")

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

signal 弟子详情请求(弟子对象: Object)
signal 弟子排序请求(模式: String)
signal 待抉择_交宗(索引: int)
signal 待抉择_自留(索引: int)
signal 弟子详情返回()
signal 弟子装备查看请求(弟子ID: int)

# ───────── 品阶/境界 中文 → UIThemeConfig stem 私有映射表（设计规格 §3.1 / 附录A）─────────
# 弟子.灵根品阶 取值域 = 凡品/良品/上品/极品/天品（5 档灵根轴）→ QUALITY_COLOR 7 档近似映射（良品归入灵阶色 ling，与 game_state 掉落映射一致）。
const _LINGGEN_QUALITY_STEM: Dictionary = {
	"凡品": "fan",
	"良品": "ling",
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
var _宗门气运条: Label
var _异闻容器: VBoxContainer
var _望宗门_btn: Button
var _宗门气运缓存: String = ""
var _宗门气运日: int = -1
var _decision_body: Control
var _detail_vbox: VBoxContainer
var _equip_detail_root: Control
var _equip_detail_vbox: VBoxContainer
var _row_map: Dictionary = {}
var _oath_area: VBoxContainer = null   # S36 心魔誓：弟子请誓待批 + 万仙大誓
var _sort_mode: String = "默认"
var _sort_btn: Button
var _sort_menu: PopupMenu = null
var _filter_identity: String = "全部"  # 身份筛选：全部/外门/内门/亲传
var _filter_realm: String = "全部"     # 境界筛选
var _filter_aptitude: String = "全部"  # 资质筛选
var _filter_daotu: String = "全部"     # 道途筛选
var _filter_linggen: String = "全部"   # 灵根品阶筛选
var _filter_buttons: Dictionary = {}  # 身份名 -> Button
var _filter_dropdowns: Dictionary = {}  # 筛选类型 -> OptionButton

var _方针_btn: Button = null   # C3：突破方针切换（宗主干预接口③）

# 排序模式循环（纯 UI 内部，不改 Game；与 _界序 一致的高阶境界权重）。
const _SORT_MODES: Array = ["战力降", "境界降", "资质降", "灵根降", "年龄升", "年龄降", "司职", "默认"]
const _境界序: Array = Disciple.境界序   # 唯一真源（2026-09-02）
# 资质排序权重（降序：旷世>妖孽>天才>优良>平庸>凡俗）
const _资质序: Dictionary = {"kuangshi": 6, "yaonie": 5, "tiancai": 4, "youliang": 3, "pingyong": 2, "fan_su": 1}
# 资质拼音→中文映射（对齐 disciple.gd 资质显示）
const _资质显示: Dictionary = {"fan_su": "凡俗", "pingyong": "平庸", "youliang": "优良", "tiancai": "天才", "yaonie": "妖孽", "kuangshi": "旷世"}
# 灵根品阶排序权重（降序：天品>极品>上品>良品>凡品）
const _灵根品阶序: Dictionary = {"天品": 5, "极品": 4, "上品": 3, "良品": 2, "凡品": 1}
# 道途列表
const _道途列表: Array = ["道修", "体修", "法修", "御兽师", "符箓师", "毒师", "傀儡师"]
# 境界列表
const _境界列表: Array = Disciple.境界序   # 唯一真源（2026-09-02）：原 7 阶，筛选下拉缺炼虚~渡劫
# 资质列表
const _资质列表: Array = ["凡俗", "平庸", "优良", "天才", "妖孽", "旷世"]
# 灵根品阶列表
const _灵根品阶列表: Array = ["凡品", "良品", "上品", "极品", "天品"]

func _ready() -> void:
	_build()
	# 监听弟子变动（含穿戴/卸载 emit）→ 自动回刷列表卡片与总战力
	if is_instance_valid(Game) and Game.has_signal("弟子变动"):
		Game.弟子变动.connect(refresh)
	refresh()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 二级页工业化背景（决策 4 升级：顶部氛围场景图 + 下方不透明纯色内容区）
	var content: Control = UITheme.make_scene_background(self)

	_list_root = VBoxContainer.new()
	_list_root.name = "ListRoot"
	_list_root.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_list_root.add_theme_constant_override("margin_right", UITheme.MARGIN)
	_list_root.add_theme_constant_override("margin_top", UITheme.GRID)
	_list_root.add_theme_constant_override("margin_bottom", UITheme.GRID)
	_list_root.add_theme_constant_override("separation", UITheme.GRID * 2)
	_list_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list_root.offset_top = 0
	content.add_child(_list_root)
	_build_list_header()
	_build_oath_area()   # S36 心魔誓区（置顶）
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
	content.add_child(_detail_root)
	_build_detail_root()

	# 装备详情根（页内子视图：点装备槽展开，与 _detail_root 同范式）。
	_equip_detail_root = VBoxContainer.new()
	_equip_detail_root.name = "EquipDetailRoot"
	_equip_detail_root.visible = false
	_equip_detail_root.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_equip_detail_root.add_theme_constant_override("margin_right", UITheme.MARGIN)
	_equip_detail_root.add_theme_constant_override("margin_top", UITheme.GRID)
	_equip_detail_root.add_theme_constant_override("margin_bottom", UITheme.GRID)
	_equip_detail_root.add_theme_constant_override("separation", UITheme.GRID * 2)
	_equip_detail_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(_equip_detail_root)
	_build_equip_detail_root()

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
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			UIHint.show_hint(title, "弟子录", "管理宗门所有弟子。\n\n· 点击弟子卡片查看详情\n· 可按境界、资质、道途筛选排序\n· 弟子自动修炼突破，无需手动操作"))
	UITheme.apply_page_title(title)
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
	sort_btn.text = "排序·默认"
	sort_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	sort_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	sort_btn.pressed.connect(_on_btn_press.bind(sort_btn, _on_sort_pressed))
	hb.add_child(sort_btn)
	_sort_btn = sort_btn

	var 测灵_btn := Button.new()
	测灵_btn.name = "CeilingBtn"
	测灵_btn.text = "举办测灵根"
	测灵_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	测灵_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	测灵_btn.pressed.connect(_on_举办测灵根.bind(测灵_btn))
	hb.add_child(测灵_btn)

	# S1-4 付费：仙玉加速全体弟子修炼
	var 修炼加速_btn := Button.new()
	修炼加速_btn.name = "PayCultivateBtn"
	修炼加速_btn.text = "仙玉加速修炼"
	修炼加速_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	修炼加速_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	if is_instance_valid(Game):
		修炼加速_btn.text = "仙玉加速修炼（%d仙玉）" % Game.付费单价.get("修炼加速", 50)
	修炼加速_btn.pressed.connect(_on_付费_修炼.bind(修炼加速_btn))
	hb.add_child(修炼加速_btn)

	# P1优化：批量操作按钮
	var 批量操作_btn := Button.new()
	批量操作_btn.name = "BatchBtn"
	批量操作_btn.text = "批量操作"
	批量操作_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	批量操作_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	批量操作_btn.pressed.connect(_on_批量操作.bind(批量操作_btn))
	hb.add_child(批量操作_btn)

	_list_root.add_child(panel)

	# 筛选区第一行：身份筛选按钮
	var filter_panel := PanelContainer.new()
	filter_panel.name = "FilterBar"
	filter_panel.custom_minimum_size = Vector2(0, int(round(UITheme.SIZE_SM * 0.8)))
	var filter_hb := HBoxContainer.new()
	filter_hb.add_theme_constant_override("separation", int(round(6 * UITheme.UI_SCALE)))
	filter_panel.add_child(filter_hb)
	for 身份名 in ["全部", "外门", "内门", "亲传"]:
		var 筛钮 := Button.new()
		筛钮.text = 身份名
		筛钮.custom_minimum_size = Vector2(0, int(round(UITheme.SIZE_SM * 0.7)))
		筛钮.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
		筛钮.pressed.connect(_on_identity_filter.bind(身份名))
		_filter_buttons[身份名] = 筛钮
		filter_hb.add_child(筛钮)
	_refresh_filter_buttons()
	_list_root.add_child(filter_panel)

	# 筛选区第二行：境界/资质/道途/灵根品阶下拉筛选
	var filter2_panel := PanelContainer.new()
	filter2_panel.name = "FilterBar2"
	filter2_panel.custom_minimum_size = Vector2(0, int(round(UITheme.SIZE_SM * 0.7)))
	var filter2_hb := HBoxContainer.new()
	filter2_hb.add_theme_constant_override("separation", int(round(8 * UITheme.UI_SCALE)))
	filter2_panel.add_child(filter2_hb)

	# 境界筛选
	var 境界_label := Label.new()
	境界_label.text = "境界:"
	UITheme.apply_aux_font(境界_label)
	filter2_hb.add_child(境界_label)
	var 境界_dropdown := OptionButton.new()
	境界_dropdown.name = "RealmFilter"
	境界_dropdown.custom_minimum_size = Vector2(80, 0)
	境界_dropdown.add_item("全部", 0)
	for i in range(_境界列表.size()):
		境界_dropdown.add_item(_境界列表[i], i + 1)
	境界_dropdown.item_selected.connect(_on_realm_filter.bind(境界_dropdown))
	_filter_dropdowns["境界"] = 境界_dropdown
	filter2_hb.add_child(境界_dropdown)

	# 资质筛选
	var 资质_label := Label.new()
	资质_label.text = "资质:"
	UITheme.apply_aux_font(资质_label)
	filter2_hb.add_child(资质_label)
	var 资质_dropdown := OptionButton.new()
	资质_dropdown.name = "AptitudeFilter"
	资质_dropdown.custom_minimum_size = Vector2(80, 0)
	资质_dropdown.add_item("全部", 0)
	for i in range(_资质列表.size()):
		资质_dropdown.add_item(_资质列表[i], i + 1)
	资质_dropdown.item_selected.connect(_on_aptitude_filter.bind(资质_dropdown))
	_filter_dropdowns["资质"] = 资质_dropdown
	filter2_hb.add_child(资质_dropdown)

	# 道途筛选
	var 道途_label := Label.new()
	道途_label.text = "道途:"
	UITheme.apply_aux_font(道途_label)
	filter2_hb.add_child(道途_label)
	var 道途_dropdown := OptionButton.new()
	道途_dropdown.name = "DaotuFilter"
	道途_dropdown.custom_minimum_size = Vector2(80, 0)
	道途_dropdown.add_item("全部", 0)
	for i in range(_道途列表.size()):
		道途_dropdown.add_item(_道途列表[i], i + 1)
	道途_dropdown.item_selected.connect(_on_daotu_filter.bind(道途_dropdown))
	_filter_dropdowns["道途"] = 道途_dropdown
	filter2_hb.add_child(道途_dropdown)

	# 灵根品阶筛选
	var 灵根_label := Label.new()
	灵根_label.text = "灵根:"
	UITheme.apply_aux_font(灵根_label)
	filter2_hb.add_child(灵根_label)
	var 灵根_dropdown := OptionButton.new()
	灵根_dropdown.name = "LinggenFilter"
	灵根_dropdown.custom_minimum_size = Vector2(80, 0)
	灵根_dropdown.add_item("全部", 0)
	for i in range(_灵根品阶列表.size()):
		灵根_dropdown.add_item(_灵根品阶列表[i], i + 1)
	灵根_dropdown.item_selected.connect(_on_linggen_filter.bind(灵根_dropdown))
	_filter_dropdowns["灵根"] = 灵根_dropdown
	filter2_hb.add_child(灵根_dropdown)

	_list_root.add_child(filter2_panel)

func _build_list_scroll() -> void:
	# 修真味·因果：山门气象面板——宗门级望气主入口（固定区，不随列表滚动）
	var 山门 := PanelContainer.new()
	山门.name = "KarmaSectPanel"
	var 山门盒 := VBoxContainer.new()
	山门盒.add_theme_constant_override("separation", int(round(4 * UITheme.UI_SCALE)))
	山门.add_child(山门盒)
	_宗门气运条 = Label.new()
	_宗门气运条.name = "SectAuraLabel"
	_宗门气运条.text = "未观山门气象"
	_宗门气运条.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
	_宗门气运条.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
	山门盒.add_child(_宗门气运条)
	_异闻容器 = VBoxContainer.new()
	_异闻容器.name = "RumorBox"
	山门盒.add_child(_异闻容器)
	_望宗门_btn = Button.new()
	_望宗门_btn.name = "SectDivineBtn"
	_望宗门_btn.text = "望宗门气运（%d灵石）" % Karma.望宗门价
	_望宗门_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	_望宗门_btn.pressed.connect(_on_望宗门)
	山门盒.add_child(_望宗门_btn)
	# C3 宗主干预接口③：突破方针（宗主定方向 → 整体平移弟子 AI 冲关阈值）
	_方针_btn = Button.new()
	_方针_btn.name = "BreakthroughPolicyBtn"
	_方针_btn.text = "突破方针：%s" % _当前突破方针()
	_方针_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	UITheme.apply_secondary_button_style(_方针_btn)
	_方针_btn.pressed.connect(_on_切换突破方针)
	山门盒.add_child(_方针_btn)
	_list_root.add_child(山门)

	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_root.add_child(scroll)
	_list_vbox = VBoxContainer.new()
	_list_vbox.name = "ListVBox"
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", int(round(4 * UITheme.UI_SCALE)))
	scroll.add_child(_list_vbox)

## C3：当前突破方针（读 Game；缺省「顺其自然」）
func _当前突破方针() -> String:
	if not is_instance_valid(Game) or "突破方针" not in Game:
		return "顺其自然"
	return String(Game.突破方针)


## C3：循环切换突破方针（稳中求进 → 顺其自然 → 搏一线天机），并回显方针释义
func _on_切换突破方针() -> void:
	if not is_instance_valid(Game):
		return
	var 表: Array = Game.获取突破方针列表()
	if 表.is_empty():
		return
	var idx: int = 表.find(_当前突破方针())
	var 下一个: String = String(表[(idx + 1) % 表.size()])
	var 结果: Dictionary = Game.设置突破方针(下一个)
	if _方针_btn != null:
		_方针_btn.text = "突破方针：%s" % _当前突破方针()
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(self, "突破方针 · %s" % 下一个, String(结果.get("说明", "")))


func _build_decision_area() -> void:
	var panel := PanelContainer.new()
	panel.name = "DecisionPanel"
	panel.custom_minimum_size = Vector2(0, UITheme.GRID * 15)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "接引决策"
	UITheme.apply_section_title(title)
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
	var back_btn: Button = UITheme.make_back_button(_on_back_pressed)
	bar.add_child(back_btn)
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

func _build_equip_detail_root() -> void:
	var bar := HBoxContainer.new()
	bar.name = "BackBar"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	var back_btn: Button = UITheme.make_back_button(_on_equip_detail_back)
	bar.add_child(back_btn)
	_equip_detail_root.add_child(bar)

	var scroll := ScrollContainer.new()
	scroll.name = "EquipDetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip_detail_root.add_child(scroll)
	_equip_detail_vbox = VBoxContainer.new()
	_equip_detail_vbox.name = "EquipDetailVBox"
	_equip_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip_detail_vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	scroll.add_child(_equip_detail_vbox)

# ───────── 只读刷新（公共，镜像 sect_home_page.refresh_overview）─────────
func refresh() -> void:
	if not _built:
		_build()
	_populate_list()
	_populate_oath_area()   # S36 心魔誓
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
	# 修真味·因果 L3：山门气象与异闻（宗门级情报，人人可见；异闻可点击直达本人）
	if _宗门气运条 != null:
		_宗门气运条.text = _宗门气运文本()
	if _异闻容器 != null:
		for c in _异闻容器.get_children():
			_异闻容器.remove_child(c)
			c.queue_free()
		var 异闻列表: Array = Karma.宗门异闻(列表)
		for 闻 in 异闻列表:
			var 闻钮 := Button.new()
			闻钮.text = "· " + str(闻.get("文本", ""))
			闻钮.flat = true
			闻钮.add_theme_font_size_override("font_size", int(round(11 * UITheme.UI_SCALE)))
			闻钮.pressed.connect(_on_异闻跳转.bind(闻.get("弟子", null)))
			_异闻容器.add_child(闻钮)
	if _望宗门_btn != null:
		_望宗门_btn.disabled = (int(Game.灵石) < Karma.望宗门价)
	# 纯 UI 内部排序（不改 Game）：先拷一份再按当前模式重排。
	var 有序列表: Array = []
	有序列表.append_array(列表)
	_apply_sort(有序列表)
	# 多条件筛选（身份/境界/资质/道途/灵根品阶）
	var 筛选后: Array = []
	for d in 有序列表:
		if d == null:
			continue
		var 身份 = str(_safe_get(d, "身份", "外门"))
		var 境界 = str(_safe_get(d, "境界", "练气"))
		var 资质 = str(_safe_get(d, "资质", "凡俗"))
		var 道途 = str(_safe_get(d, "道途", ""))
		var 灵根品阶 = str(_safe_get(d, "灵根品阶", "凡品"))
		# 身份筛选
		if _filter_identity != "全部" and 身份 != _filter_identity:
			continue
		# 境界筛选
		if _filter_realm != "全部" and 境界 != _filter_realm:
			continue
		# 资质筛选（需要转换拼音为中文）
		if _filter_aptitude != "全部":
			var 资质中文 = _资质显示.get(资质, 资质)
			if 资质中文 != _filter_aptitude:
				continue
		# 道途筛选
		if _filter_daotu != "全部" and 道途 != _filter_daotu:
			continue
		# 灵根品阶筛选
		if _filter_linggen != "全部" and 灵根品阶 != _filter_linggen:
			continue
		筛选后.append(d)
	var 显示序号: int = 0
	for d in 筛选后:
		var 战力值 = _safe_get(d, "战力", null)
		if typeof(战力值) == TYPE_INT or typeof(战力值) == TYPE_FLOAT:
			power += int(战力值)
		_row_map[显示序号] = d
		_add_disciple_row(d, 显示序号)
		显示序号 += 1
	# 筛选后无弟子时显示空占位
	if 筛选后.is_empty():
		var 空 := Label.new()
		if 列表.is_empty():
			空.text = "（尚无弟子在册，前往「接引」开启接引大典）"
		else:
			空.text = "（当前筛选条件下无弟子）"
		空.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
		空.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list_vbox.add_child(空)
	_power_value.text = str(power)

# 递归设置所有子控件的鼠标过滤为IGNORE，让鼠标事件穿透到父节点（卡片）
# 注意：不设置根节点本身的mouse_filter，只设置子控件
func _set_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_filter_ignore(child)

func _add_disciple_row(d: Object, 索引: int) -> void:
	var 战力v = _safe_get(d, "战力", null)
	var 战力文本 := "—"
	if 战力v != null and (typeof(战力v) == TYPE_INT or typeof(战力v) == TYPE_FLOAT):
		战力文本 = str(int(战力v))
	var 境界 = str(_safe_get(d, "境界", "—"))
	var 资质 = str(_safe_get(d, "资质", "凡俗"))
	var 身份 = str(_safe_get(d, "身份", "外门"))
	var 道途 = str(_safe_get(d, "道途", ""))
	var 年龄 = _safe_get(d, "年龄", 0)
	var 心境 = _safe_get(d, "心境", 0)
	var 道心 = _safe_get(d, "道心", 0)
	var 心魔值 = _safe_get(d, "心魔值", 0)
	var 命格 = str(_safe_get(d, "命格", "无"))
	var 灵根 = str(_safe_get(d, "灵根", "无"))
	var 状态 = str(_safe_get(d, "状态", "在宗"))
	var 性格 = str(_safe_get(d, "性格", "—"))
	var 品质色 = UIThemeConfig.get_aptitude_color(资质)

	# 紧凑列表式卡片，高度约90px（增加状态标签行）
	var 卡片 := PanelContainer.new()
	卡片.name = "Card_%d" % 索引
	卡片.custom_minimum_size = Vector2(0, int(round(90 * UITheme.UI_SCALE)))
	卡片.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 卡片样式 := StyleBoxFlat.new()
	卡片样式.bg_color = Color(0.08, 0.11, 0.16, 0.92)
	卡片样式.border_color = 品质色
	卡片样式.set_border_width_all(int(round(1 * UITheme.UI_SCALE)))
	卡片样式.set_corner_radius_all(int(round(6 * UITheme.UI_SCALE)))
	卡片.add_theme_stylebox_override("panel", 卡片样式)

	var 根hb := HBoxContainer.new()
	根hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	根hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	根hb.add_theme_constant_override("separation", int(round(10 * UITheme.UI_SCALE)))
	卡片.add_child(根hb)

	# 左侧：小头像（50x50，带品质边框）
	var 头像框 := PanelContainer.new()
	头像框.custom_minimum_size = Vector2(int(round(50 * UITheme.UI_SCALE)), int(round(50 * UITheme.UI_SCALE)))
	头像框.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	头像框.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var 头像样式 := StyleBoxFlat.new()
	头像样式.bg_color = Color(0.08, 0.12, 0.15, 0.9)
	头像样式.border_color = 品质色
	头像样式.set_border_width_all(int(round(2 * UITheme.UI_SCALE)))
	头像样式.set_corner_radius_all(int(round(25 * UITheme.UI_SCALE)))
	头像样式.set_content_margin_all(int(round(2 * UITheme.UI_SCALE)))
	头像框.add_theme_stylebox_override("panel", 头像样式)
	根hb.add_child(头像框)

	var 头像tex := TextureRect.new()
	头像tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	头像tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	头像tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	头像tex.clip_contents = true
	var 头像材质 := ShaderMaterial.new()
	头像材质.shader = load("res://ui/avatar_circle_mask.gdshader") as Shader
	头像tex.material = 头像材质
	var 头像加载成功: bool = false
	if d.has_method("取头像路径"):
		var 头像路径: String = d.取头像路径()
		var tex_res: Texture2D = _load_disciple_portrait_texture(头像路径)
		if tex_res == null and (头像路径.contains("_elite") or 头像路径.contains("_top")):
			var 普通路径: String = 头像路径.replace("_elite.png", ".png").replace("_top.png", ".png")
			tex_res = _load_disciple_portrait_texture(普通路径)
		if tex_res != null:
			var w: float = float(tex_res.get_width())
			var at := AtlasTexture.new()
			at.atlas = tex_res
			at.region = Rect2(0.0, (tex_res.get_height() - w) * 0.5, w, w)
			at.filter_clip = true
			头像tex.texture = at
			头像加载成功 = true
	if not 头像加载成功:
		var 占位首字: String = str(_safe_get(d, "姓名", "—"))
		if 占位首字.length() > 0:
			占位首字 = 占位首字[0]
		var 占位lbl: Label = Label.new()
		占位lbl.text = 占位首字
		占位lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		占位lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		占位lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		占位lbl.add_theme_font_size_override("font_size", int(round(24 * UITheme.UI_SCALE)))
		占位lbl.add_theme_color_override("font_color", 品质色)
		占位lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		头像框.add_child(占位lbl)
	头像框.add_child(头像tex)

	# 中间：信息区（2行紧凑布局）
	var 信息vb := VBoxContainer.new()
	信息vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	信息vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	信息vb.add_theme_constant_override("separation", int(round(2 * UITheme.UI_SCALE)))
	根hb.add_child(信息vb)

	# 第1行：名字 + 核心标签（境界、资质）
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", int(round(8 * UITheme.UI_SCALE)))
	信息vb.add_child(row1)

	# 命魂灯：一眼可见弟子生死（亮=在宗/失踪生还，灭=陨落）
	row1.add_child(_make_soul_lamp(状态))

	var 名字lbl := Label.new()
	名字lbl.text = str(_safe_get(d, "姓名", "—"))
	名字lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	名字lbl.add_theme_font_size_override("font_size", int(round(18 * UITheme.UI_SCALE)))
	row1.add_child(名字lbl)

	var 资质名: String = _资质显示.get(资质, "凡俗")
	# 核心标签1：资质（pill样式，突出显示）
	var 资质pill = _make_pill(资质名, 品质色, 4)
	资质pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	资质pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(资质pill)

	# 核心标签2：境界（pill样式，境界色）
	var 境界stem = _REALM_STEM.get(境界, "lianqi")
	var 境界色 = UIThemeConfig.get_realm_color(境界stem)
	var 境界pill = _make_pill(境界, 境界色, 4)
	境界pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	境界pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(境界pill)

	# 第2行：次要标签（道途、身份、灵根品阶、年龄）+ 战力
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", int(round(8 * UITheme.UI_SCALE)))
	信息vb.add_child(row2)

	# 次要标签：道途
	if 道途 != "" and 道途 != "无":
		var 道途lbl := Label.new()
		道途lbl.text = 道途
		道途lbl.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
		道途lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		row2.add_child(道途lbl)

	# 次要标签：身份
	var 身份lbl := Label.new()
	身份lbl.text = 身份
	身份lbl.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
	身份lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	row2.add_child(身份lbl)

	# 次要标签：灵根品阶
	var 灵根品阶 = str(_safe_get(d, "灵根品阶", "凡品"))
	var 灵根品阶lbl := Label.new()
	灵根品阶lbl.text = 灵根品阶 + "灵根"
	灵根品阶lbl.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
	灵根品阶lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	row2.add_child(灵根品阶lbl)

	# 次要标签：年龄
	var 年龄lbl := Label.new()
	年龄lbl.text = "%d岁" % int(年龄)
	年龄lbl.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
	年龄lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	row2.add_child(年龄lbl)

	# 战力（突出显示）
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(spacer)

	var 战力lbl := Label.new()
	战力lbl.text = "⚔%s" % 战力文本
	战力lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	战力lbl.add_theme_font_size_override("font_size", int(round(14 * UITheme.UI_SCALE)))
	row2.add_child(战力lbl)

	# 第3行：状态标签（突破中、稳固期、心魔高、道心低等）
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", int(round(6 * UITheme.UI_SCALE)))
	信息vb.add_child(row3)

	# 状态栏（P3.1 修真重构：命魂灯只表示生死，失踪/闭关/历练/秘境 等活动信息统一在此呈现）。
	# 优先级：历练中(autoload 实时) > 失踪/闭关/秘境(数据层) > 在宗(默认隐藏)
	# 显示策略：仅当弟子不在「在宗」时显示，默认留白降低视觉噪声。
	var 显示状态: String = _取显示状态(d)
	if 显示状态 != "在宗":
		var 状态色: Color
		match 显示状态:
			"历练中": 状态色 = Color(0.45, 0.78, 0.92)  # 青蓝（外出/行动的修真界色）
			"闭关":   状态色 = Color(0.70, 0.55, 0.95)  # 紫（修真「入定」之色）
			"秘境":   状态色 = Color(0.95, 0.55, 0.30)  # 橙（险地之色）
			"失踪":   状态色 = Color(0.95, 0.85, 0.40)  # 金（修真「下落不明」警示色，与命灯色严格区分）
			"陨落":   状态色 = Color(0.55, 0.55, 0.60)  # 冷灰（命灯灭的呼应）
			"叛出":   状态色 = Color(0.85, 0.35, 0.35)  # 暗红（叛离宗门，与陨落冷灰严格区分）
			_:        状态色 = Color(0.55, 0.70, 0.85)  # 默认（修真通用情报色）
		var 状态pill = _make_pill(显示状态, 状态色, 3)
		状态pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row3.add_child(状态pill)

	# 状态标签：突破状态
	var 突破状态 = str(_safe_get(d, "突破状态", ""))
	if 突破状态 != "" and 突破状态 != "无":
		var 突破pill = _make_pill(突破状态, Color(1.0, 0.6, 0.2), 3)
		突破pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row3.add_child(突破pill)

	# 状态标签：稳固期
	var 稳固期 = _safe_get(d, "稳固期", 0)
	if 稳固期 > 0:
		var 稳固pill = _make_pill("稳固期", Color(0.5, 0.8, 0.5), 3)
		稳固pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row3.add_child(稳固pill)

	# 状态标签：心魔高（心魔值 > 50）
	if 心魔值 > 50:
		var 心魔pill = _make_pill("心魔高", Color(0.9, 0.3, 0.3), 3)
		心魔pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row3.add_child(心魔pill)

	# 状态标签：道心低（道心 < 30）
	if 道心 < 30:
		var 道心低pill = _make_pill("道心低", Color(0.7, 0.5, 0.9), 3)
		道心低pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row3.add_child(道心低pill)

	# 状态标签：司职
	var 司职 = str(_safe_get(d, "司职", ""))
	if 司职 != "" and 司职 != "无":
		var 司职pill = _make_pill(司职, Color(0.4, 0.7, 0.9), 3)
		司职pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row3.add_child(司职pill)

	# 如果没有状态标签，显示心境/道心/心魔数值
	if row3.get_child_count() == 0:
		var 心境lbl := Label.new()
		心境lbl.text = "心%d" % int(心境)
		心境lbl.add_theme_font_size_override("font_size", int(round(11 * UITheme.UI_SCALE)))
		心境lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.75))
		row3.add_child(心境lbl)

		var 道心lbl2 := Label.new()
		道心lbl2.text = "道%d" % int(道心)
		道心lbl2.add_theme_font_size_override("font_size", int(round(11 * UITheme.UI_SCALE)))
		道心lbl2.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
		row3.add_child(道心lbl2)

		var 心魔lbl := Label.new()
		心魔lbl.text = "魔%d" % int(心魔值)
		心魔lbl.add_theme_font_size_override("font_size", int(round(11 * UITheme.UI_SCALE)))
		心魔lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5) if 心魔值 > 50 else Color(0.7, 0.6, 0.6))
		row3.add_child(心魔lbl)

	# 修真味·因果 L1：列表卡不再展示业力/功德数字，因果只经「气运(望气)」与「近日异闻」间接呈现

	# 右侧：箭头指示
	var 箭头lbl := Label.new()
	箭头lbl.text = "›"
	箭头lbl.add_theme_font_size_override("font_size", int(round(24 * UITheme.UI_SCALE)))
	箭头lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	箭头lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	箭头lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	根hb.add_child(箭头lbl)

	# 点击事件：确保所有子控件都穿透鼠标事件，让整个卡片区域都可点击
	_set_mouse_filter_ignore(卡片)
	卡片.gui_input.connect(_on_card_gui_input.bind(索引))
	_list_vbox.add_child(卡片)

# 通用 pill / tag 工厂：圆角矩形 bg+border，白字居中，点击穿透到卡片（保留整卡可点）。
# 颜色全部来自 UIThemeConfig（身份/资质/状态），本函数零硬编码色值。
func _make_pill(text: String, bg_color: Color, radius_px: int = 6) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = bg_color.lightened(0.3)
	sb.set_corner_radius_all(int(round(float(radius_px) * UITheme.UI_SCALE)))
	sb.set_border_width_all(int(round(2 * UITheme.UI_SCALE)))
	sb.set_content_margin(SIDE_LEFT, int(round(6 * UITheme.UI_SCALE)))
	sb.set_content_margin(SIDE_RIGHT, int(round(6 * UITheme.UI_SCALE)))
	sb.set_content_margin(SIDE_TOP, int(round(2 * UITheme.UI_SCALE)))
	sb.set_content_margin(SIDE_BOTTOM, int(round(2 * UITheme.UI_SCALE)))
	pill.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", int(round(11 * UITheme.UI_SCALE)))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(lbl)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return pill

# 修真味·因果：山门气象读值（会话内缓存，不写存档；过期需重设坛）
func _宗门气运文本() -> String:
	if _宗门气运缓存 == "":
		return "未观山门气象"
	if not is_instance_valid(Game):
		return _宗门气运缓存
	if (int(Game.累计游戏日) - _宗门气运日) >= Karma.望气有效期:
		return "山门气象已变，需重设坛观望"
	return _宗门气运缓存


# 修真味·因果 L2：望宗门气运——一次看清全宗整体气象（不点名，粗信号）
func _on_望宗门() -> void:
	if not is_instance_valid(Game):
		return
	if int(Game.灵石) < Karma.望宗门价:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "望气", "灵石不足，无法设坛")
		return
	var 列表 = Game.get("弟子列表")
	if 列表 == null or not (列表 is Array):
		return
	Game.灵石 -= Karma.望宗门价
	_宗门气运缓存 = Karma.宗门气象(列表)
	_宗门气运日 = int(Game.累计游戏日)
	Game._加推演条目("设坛望气，观山门气象：" + _宗门气运缓存, Game.ET_INFO, Game.PRIO_NORMAL)
	if _宗门气运条 != null:
		_宗门气运条.text = _宗门气运文本()
	if _望宗门_btn != null:
		_望宗门_btn.disabled = (int(Game.灵石) < Karma.望宗门价)


# 修真味·因果 L3：异闻点名后直达本人，闭合「发现 → 确认」链路
func _on_异闻跳转(d: Object) -> void:
	if d == null:
		return
	for k in _row_map:
		if _row_map[k] == d:
			_show_detail(k)
			return
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "异闻", "此人不在当前筛选之列，先放宽筛选")


func _on_card_gui_input(event: InputEvent, 索引: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var d = _row_map.get(索引, null)
		if d != null:
			弟子详情请求.emit(d)

func _derive_status(d: Object) -> String:
	var 司职 = _safe_get(d, "司职", "")
	if 司职 == "" or 司职 == null:
		return "未入门"
	var 突破 = _safe_get(d, "突破冷却剩余", 0)
	if typeof(突破) == TYPE_FLOAT or typeof(突破) == TYPE_INT:
		if float(突破) > 0.0:
			return "闭关养伤"
	var 试炼 = _safe_get(d, "试炼冷却剩余", 0)
	if typeof(试炼) == TYPE_INT or typeof(试炼) == TYPE_FLOAT:
		if int(试炼) > 0:
			return "试炼冷却"
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

# ───────── 命魂灯（修真设定：仅表示生死二态 ─────────
# 修真界规约：人活着 = 命灯长明；人死了 = 命灯熄灭。失踪/闭关/历练/秘境等活动信息
# 一律走弟子卡片「状态栏」文字标签，绝不让命魂灯参与活动状态机（绿/金/灰三态是错的）。
func _命牌状态(状态v: String) -> Dictionary:
	var 色: Color
	var 态: String
	if 状态v == "陨落":
		色 = Color(0.42, 0.43, 0.45)  # 命灯灭（暗灰，下沉）
		态 = "熄灭·陨落（命灯灭）"
	else:
		# 长明（生还）：失踪/闭关/历练中/秘境/在宗，命灯皆长明，颜色统一修真灵气绿
		色 = Color(0.36, 0.80, 0.54)  # #5ECB8A 命灯绿
		var 人类活动: String = 状态v if 状态v != "" and 状态v != "在宗" else ""
		态 = "长明·生还" + ("（" + 人类活动 + "）" if 人类活动 != "" else "")
	return {"色": 色, "态": 态}

# 修真设定：命魂灯只表示生死二态——亮（生还）/灭（陨落）。
# 用 SVG 图标替换旧 Panel 椭圆以体现修真意象（灯座+芯焰+烟气），与项目其他 SVG 图标风格统一。
func _make_soul_lamp(状态v: String, 直径: int = 16) -> Control:
	var 已陨落: bool = (状态v == "陨落")
	var tex := TextureRect.new()
	tex.texture = _SOUL_LAMP_DEAD if 已陨落 else _SOUL_LAMP_ALIVE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 尺寸 = int(round(直径 * UITheme.UI_SCALE))
	tex.custom_minimum_size = Vector2(尺寸, 尺寸)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var 数据 = _命牌状态(状态v)
	tex.tooltip_text = "命魂灯：" + 数据.态
	tex.name = "命魂灯"
	return tex

# 把数据字典里的 状态 字段 + ExpeditionSystem 历练中标志，统一为可读的活动状态文字。
# 优先级：陨落 > 历练中 > 失踪/闭关/秘境/原值 > 在宗。修真界「命灯活人在干什么」的唯一出口。
func _取显示状态(d: Variant) -> String:
	var 状态v: String = str(_safe_get(d, "状态", "在宗"))
	if 状态v == "":
		状态v = "在宗"
	var 弟子id: int = int(_safe_get(d, "弟子ID", -1))
	if 弟子id >= 0 and ExpeditionSystem != null and ExpeditionSystem.has_method("_弟子是否在历练中"):
		if bool(ExpeditionSystem._弟子是否在历练中(弟子id)):
			return "历练中"
	return 状态v

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
	lbl.text = "静待机缘"
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

# 排序按钮：点击弹出选项菜单（不再循环切换），选中某项后设定模式并刷新列表。
func _on_sort_pressed() -> void:
	if _sort_menu == null:
		_sort_menu = PopupMenu.new()
		_sort_menu.name = "SortMenu"
		_sort_menu.add_theme_font_size_override("font_size", int(round(14 * UITheme.UI_SCALE)))
		for m in _SORT_MODES:
			_sort_menu.add_item(m)
		_sort_menu.id_pressed.connect(_on_sort_selected)
		add_child(_sort_menu)
	if _sort_btn == null or not is_instance_valid(_sort_btn):
		return
	_sort_menu.position = _sort_btn.global_position + Vector2(0.0, _sort_btn.size.y)
	_sort_menu.popup()

func _on_sort_selected(id: int) -> void:
	if id < 0 or id >= _SORT_MODES.size():
		return
	_sort_mode = _SORT_MODES[id]
	if _sort_btn != null and is_instance_valid(_sort_btn):
		_sort_btn.text = "排序·%s" % _sort_mode
	_populate_list()

# 身份筛选处理
func _on_identity_filter(身份: String) -> void:
	_filter_identity = 身份
	_refresh_filter_buttons()
	_populate_list()

# 境界筛选处理
func _on_realm_filter(index: int, dropdown: OptionButton) -> void:
	if index == 0:
		_filter_realm = "全部"
	else:
		_filter_realm = _境界列表[index - 1]
	_populate_list()

# 资质筛选处理
func _on_aptitude_filter(index: int, dropdown: OptionButton) -> void:
	if index == 0:
		_filter_aptitude = "全部"
	else:
		_filter_aptitude = _资质列表[index - 1]
	_populate_list()

# 道途筛选处理
func _on_daotu_filter(index: int, dropdown: OptionButton) -> void:
	if index == 0:
		_filter_daotu = "全部"
	else:
		_filter_daotu = _道途列表[index - 1]
	_populate_list()

# 灵根品阶筛选处理
func _on_linggen_filter(index: int, dropdown: OptionButton) -> void:
	if index == 0:
		_filter_linggen = "全部"
	else:
		_filter_linggen = _灵根品阶列表[index - 1]
	_populate_list()

# 刷新筛选按钮选中状态
func _refresh_filter_buttons() -> void:
	for 名 in _filter_buttons:
		var b: Button = _filter_buttons[名]
		var 选中: bool = (名 == _filter_identity)
		b.modulate = UITheme.C01_TEXT_GOLD if 选中 else Color.WHITE

# ───────── 排序（纯 UI 内部）─────────
func _apply_sort(列表: Array) -> void:
	if _sort_mode == "默认":
		return
	if _sort_mode == "战力降":
		列表.sort_custom(func(a, b): return _sort_key_战力(a) > _sort_key_战力(b))
	elif _sort_mode == "境界降":
		列表.sort_custom(func(a, b): return _sort_key_境界(a) > _sort_key_境界(b))
	elif _sort_mode == "资质降":
		列表.sort_custom(func(a, b): return _sort_key_资质(a) > _sort_key_资质(b))
	elif _sort_mode == "灵根降":
		列表.sort_custom(func(a, b): return _sort_key_灵根(a) > _sort_key_灵根(b))
	elif _sort_mode == "年龄升":
		列表.sort_custom(func(a, b): return _sort_key_年龄(a) < _sort_key_年龄(b))
	elif _sort_mode == "年龄降":
		列表.sort_custom(func(a, b): return _sort_key_年龄(a) > _sort_key_年龄(b))
	elif _sort_mode == "司职":
		列表.sort_custom(func(a, b): return _sort_key_司职(a) < _sort_key_司职(b))

func _sort_key_战力(d: Variant) -> int:
	var v = _safe_get(d, "战力", 0)
	return int(v) if (typeof(v) in [TYPE_INT, TYPE_FLOAT]) else 0

func _sort_key_境界(d: Variant) -> int:
	var 名 = str(_safe_get(d, "境界", ""))
	var idx = _境界序.find(名)
	return idx if idx >= 0 else -1

func _sort_key_资质(d: Variant) -> int:
	var 资质 = str(_safe_get(d, "资质", "fan_su"))
	var 权重 = _资质序.get(资质, 0)
	return int(权重)

func _sort_key_灵根(d: Variant) -> int:
	var 灵根 = str(_safe_get(d, "灵根品阶", "凡品"))
	var 权重 = _灵根品阶序.get(灵根, 0)
	return int(权重)

func _sort_key_年龄(d: Variant) -> int:
	var v = _safe_get(d, "年龄", 0)
	return int(v) if (typeof(v) in [TYPE_INT, TYPE_FLOAT]) else 0

func _sort_key_司职(d: Variant) -> int:
	# 有司职在前（0），未入门（空）置后（1）。
	var 司职 = _safe_get(d, "司职", "")
	if 司职 == "" or 司职 == null:
		return 1
	return 0

func _on_待抉择_交宗(索引: int) -> void:
	if not is_instance_valid(Game) or not Game.has_method("交宗"):
		_toast("交宗失败：数据层未就绪。")
		return
	var 待抉择 = Game.get("待抉择")
	if 待抉择 == null or not (待抉择 is Array) or 索引 < 0 or 索引 >= 待抉择.size():
		_toast("交宗失败：条目无效。")
		return
	Game.交宗(待抉择[索引])
	_toast("已交予宗门，换得贡献点。")
	refresh.call_deferred()

func _on_待抉择_自留(索引: int) -> void:
	if not is_instance_valid(Game) or not Game.has_method("自留"):
		_toast("自留失败：数据层未就绪。")
		return
	var 待抉择 = Game.get("待抉择")
	if 待抉择 == null or not (待抉择 is Array) or 索引 < 0 or 索引 >= 待抉择.size():
		_toast("自留失败：条目无效。")
		return
	Game.自留(待抉择[索引])
	_toast("已自行留用。")
	refresh.call_deferred()

func _toast(文本: String) -> void:
	if is_instance_valid(Game) and Game.has_method("添加提示"):
		Game.添加提示(文本)


func _on驱逐弟子(弟子ID: int) -> void:
	if not is_instance_valid(Game):
		return
	var 结果: bool = Game.驱逐弟子(弟子ID)
	if 结果:
		_toast("弟子已逐出宗门")
		refresh()
	else:
		_toast("驱逐失败")

# 立绘安全加载：优先「绝对路径直读」绕开 Godot 资源系统（ResourceLoader / .import UID remap），
# 直接走 OS 文件系统读盘——规避中文目录名（如「弟子立绘」）在 ResourceLoader 下的静默失败。
# fallback：Godot 资源系统（无中文目录或已正确 import 的场景）。
func _load_disciple_portrait_texture(path: String) -> Texture2D:
	if path == "" or path == null:
		return null
	# 1) 优先：OS 文件系统直读（不经 ResourceLoader，中文路径安全）
	var abs_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img: Image = Image.load_from_file(abs_path)
		if img != null:
			return ImageTexture.create_from_image(img)
	# 2) fallback：Godot 资源系统（load 走 .import UID；失败再试 img.load）
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			return tex
		var img2: Image = Image.new()
		if img2.load(path) == OK:
			return ImageTexture.create_from_image(img2)
	return null

# ───────── 弟子详情二级页（页内子视图，仅读 + 占位信号）─────────
# P0-2：灵气助破瓶颈回调（扣灵气 → 加瓶颈打磨 → 写纪事 → 刷新详情）
# 修真味·因果 L2：望气术回调（扣灵石 → 写气象快照 → 刷新详情）
func _on_望气(d: Object, 索引: int) -> void:
	if d == null or not is_instance_valid(Game):
		return
	if int(Game.灵石) < Karma.望气价:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "望气", "灵石不足，无法设坛")
		return
	Game.灵石 -= Karma.望气价
	d.望气快照 = Karma.望气(d)
	d.望气日 = int(Game.累计游戏日)
	Game._加推演条目("【%s】设坛望气，观其气运。" % str(_safe_get(d, "姓名", "弟子")), Game.ET_INFO, Game.PRIO_NORMAL)
	_populate_detail(d, 索引)

# 业力不灭：超度法事回调（扣灵石 → 同时消减当前业力与历史业力 → 刷新详情）
func _on_超度(d: Object, 索引: int) -> void:
	if d == null or not is_instance_valid(Game):
		return
	if int(Game.灵石) < Karma.超度价:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "超度", "灵石不足，无法设坛")
		return
	Game.灵石 -= Karma.超度价
	d.消业(Karma.超度消业量)
	Game._加推演条目("【%s】设坛超度，为昔日杀业诵经消灾。" % str(_safe_get(d, "姓名", "弟子")), Game.ET_INFO, Game.PRIO_NORMAL)
	_populate_detail(d, 索引)

func _on化解走火入魔(d: Object, 索引: int, 方式: String) -> void:
	if d == null or not is_instance_valid(Game):
		return
	var 弟子ID: int = int(_safe_get(d, "弟子ID", -1))
	var r: Dictionary = Game.化解走火入魔(弟子ID, 方式)
	var 消息: String = r.get("原因", r.get("消息", "化解完成"))
	Game._加推演条目("【%s】走火入魔化解：%s" % [str(_safe_get(d, "姓名", "弟子")), 消息], Game.ET_INFO, Game.PRIO_NORMAL)
	_populate_detail(d, 索引)

func _on_灵气助破瓶颈(d: Object, 索引: int) -> void:
	if d == null or not is_instance_valid(Game):
		return
	if d.灵气助破瓶颈():
		Game._加推演条目("【%s】引灵气冲击瓶颈，打磨精进。" % str(_safe_get(d, "姓名", "弟子")), Game.ET_INFO, Game.PRIO_NORMAL)
	_populate_detail(d, 索引)

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
	# 天骄标签（修真味互补）
	if is_instance_valid(Game) and Game.是天骄(int(_safe_get(d, "弟子ID", -1))):
		基本信息.append(["天骄", "★ 天之骄子（修炼+20%）"])
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
	var 道途v = _safe_get(d, "道途", "")
	var 道途文本 = "未入门" if (道途v == "" or 道途v == null) else str(道途v)
	var 灵根品阶文本 = str(_safe_get(d, "灵根品阶", "—"))
	var 灵根stem = _LINGGEN_QUALITY_STEM.get(灵根品阶文本, "fan")
	var 灵根色 = UIThemeConfig.get_quality_color(灵根stem)
	var 资质灵根: Array = [
		["资质", 资质文本],
		["灵根", str(_safe_get(d, "灵根", "—"))],
		["灵根品阶", 灵根品阶文本, false, 灵根色],
		["命格", 命格文本],
		["性格", str(_safe_get(d, "性格", "—"))],
		["道途", 道途文本],
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
	# 修真味·因果：弟子杀业/善功 → 天劫倍率（口径取 Tribulation.因果天劫倍率，单一真源）
	# 修真味·因果 L2：不显数字，只显望气所得气象（未施术则气象不明）
	var 望气文本: String = str(_safe_get(d, "望气快照", ""))
	var 因果文本: String = "未施望气术，气象不明"
	if 望气文本 != "":
		因果文本 = 望气文本
	var 因果警示: bool = (望气文本 != "" and Tribulation.因果天劫倍率(d) > 1.02)
	# 修真味·因果 L3：世界回响人人可见（不需望气，越过阈值自有异闻）
	var 异闻文本: String = Karma.征兆(d)
	var 异闻警示: bool = (异闻文本 != "")
	if not 异闻警示:
		异闻文本 = "并无异闻"
	# 修真味·因果 L4：入魔之时，识海现故人
	var 入魔中: bool = bool(_safe_get(d, "走火入魔", false))
	var 幻境文本: String = "识海澄清，并无异象"
	if 入魔中:
		幻境文本 = Karma.入魔幻境(d)
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
		["气运", 因果文本, 因果警示],
		["近日异闻", 异闻文本, 异闻警示],
		["识海异象", 幻境文本, 入魔中],
	]
	# 进度可视化（设计规格 §3.2）：修为/打磨/丹毒(心魔代理)/道心(占位) 进度条。
	var 修炼状态_extra: Array = []
	修炼状态_extra.append(_make_progress("修炼进度", 进度v, UITheme.COLOR_TEXT_GOLD))
	修炼状态_extra.append(_make_progress("瓶颈打磨", 打磨v, UITheme.COLOR_STATUS_SUCCESS))
	var 丹毒色 = UITheme.COLOR_STATUS_SUCCESS if 丹毒v < 0.5 else UITheme.COLOR_TEXT_RED
	修炼状态_extra.append(_make_progress("丹毒(心魔风险)", 丹毒v, 丹毒色))
	修炼状态_extra.append(_make_progress("道心(待实装)", 0.0, UITheme.COLOR_TEXT_AUX))
	_add_section("修炼状态", 修炼状态, "danger" if 突破红点 else "", 修炼状态_extra)

	# 走火入魔化解入口（后端完整，UI零调用→此处接通）
	if 入魔中 and is_instance_valid(Game):
		var 入魔区 := VBoxContainer.new()
		入魔区.name = "HuomoResolveArea"
		入魔区.add_theme_constant_override("separation", 4)
		var 入魔标题 := Label.new()
		入魔标题.text = "⚠ 走火入魔中——识海异象，需尽快化解"
		入魔标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_RED)
		入魔区.add_child(入魔标题)
		var 入魔按钮行 := HBoxContainer.new()
		入魔按钮行.add_theme_constant_override("separation", 8)
		# 闭关化解（30%+道心加成）
		var 闭关_btn := Button.new()
		闭关_btn.name = "Huomo闭关Btn"
		闭关_btn.text = "闭关化解（30%+道心）"
		闭关_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		闭关_btn.pressed.connect(_on化解走火入魔.bind(d, 索引, "闭关"))
		入魔按钮行.add_child(闭关_btn)
		# 丹药化解（60%，需清心丹）
		var 丹药_btn := Button.new()
		丹药_btn.name = "Huomo丹药Btn"
		丹药_btn.text = "丹药化解（60%，需清心丹）"
		丹药_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		丹药_btn.pressed.connect(_on化解走火入魔.bind(d, 索引, "丹药"))
		入魔按钮行.add_child(丹药_btn)
		# 佛法化解（80%，需佛门功法）
		var 佛法_btn := Button.new()
		佛法_btn.name = "Huomo佛法Btn"
		佛法_btn.text = "佛法化解（80%，需佛门功法）"
		佛法_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		佛法_btn.pressed.connect(_on化解走火入魔.bind(d, 索引, "佛法"))
		入魔按钮行.add_child(佛法_btn)
		入魔区.add_child(入魔按钮行)
		_detail_vbox.add_child(入魔区)

	# P0-2 根本解法：接通「加瓶颈打磨()」的主动入口（后端 灵气助破瓶颈() 原为零调用者，
	# 致大圆满后只能干等 2880 日自然增长）。仅在大圆满(10层)且打磨未满时出现，避免误导。
	if 层数v >= 10 and 打磨v < 1.0 and is_instance_valid(Game):
		var 破瓶颈_btn := Button.new()
		破瓶颈_btn.name = "BreakBottleneckBtn"
		var 消耗: int = int(Disciple.瓶颈灵气消耗)
		破瓶颈_btn.text = "灵气助破瓶颈（%d灵气 / 打磨+%d%%）" % [消耗, int(Disciple.瓶颈灵气打磨加成 * 100.0)]
		破瓶颈_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		破瓶颈_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		破瓶颈_btn.disabled = (int(Game.灵气) < 消耗)
		破瓶颈_btn.pressed.connect(_on_灵气助破瓶颈.bind(d, 索引))
		_detail_vbox.add_child(破瓶颈_btn)
	# 修真味·因果 L2：望气术——灵石换知情权，因果不可白看
	if is_instance_valid(Game):
		var 望气_btn := Button.new()
		望气_btn.name = "KarmaDivineBtn"
		if Karma.望气已过期(d, int(Game.累计游戏日)):
			望气_btn.text = "设坛望气（%d灵石）" % Karma.望气价
		else:
			望气_btn.text = "再度望气（%d灵石）" % Karma.望气价
		望气_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		望气_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		望气_btn.disabled = (int(Game.灵石) < Karma.望气价)
		望气_btn.pressed.connect(_on_望气.bind(d, 索引))
		_detail_vbox.add_child(望气_btn)
	# 业力不灭：超度法事——唯一能真正消减旧业的出口
	if int(_safe_get(d, "历史业力", 0)) > 0 or int(_safe_get(d, "业力", 0)) > 0:
		var 超度_btn := Button.new()
		超度_btn.name = "KarmaAbsolveBtn"
		超度_btn.text = "设坛超度（%d灵石 / 消业%d）" % [Karma.超度价, Karma.超度消业量]
		超度_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		超度_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		超度_btn.disabled = (int(Game.灵石) < Karma.超度价)
		超度_btn.pressed.connect(_on_超度.bind(d, 索引))
		_detail_vbox.add_child(超度_btn)

	var 任职: Array = [
		["司职", str(_safe_get(d, "司职", "—"))],
		["阶位", str(_safe_get(d, "阶位", "—"))],
		["试炼冷却剩余", str(_safe_get(d, "试炼冷却剩余", "—"))],
		["试炼心得", str(_safe_get(d, "试炼心得", "—"))],
	]
	_add_section("任职", 任职, "gold" if 有抉择 else "")

	# ── 命牌（2026-08-31 P3 重构：命牌殿入口移除，状态集成至此；命魂灯可见生死）──
	var 状态v = str(_safe_get(d, "状态", "在宗"))
	var 命牌数据 = _命牌状态(状态v)
	var 行踪展示 = 状态v
	if 状态v == "失踪":
		行踪展示 = "失踪（生还）"
	elif 状态v == "陨落":
		行踪展示 = "陨落（命牌灭）"
	elif ExpeditionSystem != null and ExpeditionSystem._弟子是否在历练中(int(_safe_get(d, "弟子ID", -1))):
		行踪展示 = "历练中"
	var 命牌: Array = [
		["行踪", 行踪展示],
		["命牌", 命牌数据.态, false, 命牌数据.色],
	]
	var 护身 = int(_safe_get(d, "保命护身", 0))
	命牌.append(["保命护身", "%d 枚" % 护身])
	var 护身box := HBoxContainer.new()
	护身box.add_theme_constant_override("separation", UITheme.GRID)
	var 护身btn := Button.new()
	# S28：后端已改扣弟子「个人功勋账户」，文案同步（旧文案误导玩家以为是公中出钱）
	var 个人功勋: int = int(_safe_get(d, "贡献账户", 0))
	var 保命价: int = ContributionShop.保命价()
	护身btn.text = "以功勋兑换保命（现有 %d / 需 %d）" % [个人功勋, 保命价]
	护身btn.disabled = 个人功勋 < 保命价
	护身btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	护身btn.pressed.connect(func():
		if Game != null and Game.has_method("宗门兑换保命道具"):
			Game.宗门兑换保命道具(int(_safe_get(d, "弟子ID", -1)), 1)
			call_deferred("_populate_detail", d, 索引)
	)
	护身box.add_child(护身btn)
	# 命魂灯：与列表卡片一致的生死灯语（亮=在宗/失踪生还，灭=陨落）
	var 命魂灯 = _make_soul_lamp(状态v, 22)
	_add_section("命牌", 命牌, "", [命魂灯, 护身box])

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
		纪事行.append(["", "尚无个人纪事"])
	_add_section("个人纪事", 纪事行)

	# ── 渡劫履历（P0-2 UI集成：展示该弟子的渡劫历史记录和统计）──
	var 弟子IDv: int = int(_safe_get(d, "弟子ID", -1))
	var 渡劫履历行: Array = []
	var 渡劫履历_extra: Array = []
	if 弟子IDv >= 0 and Tribulation != null:
		var 渡劫记录: Array = Tribulation.获取弟子渡劫记录(弟子IDv)
		var 渡劫统计: Dictionary = Tribulation.获取渡劫统计()
		# 统计信息
		var 总渡劫: int = 渡劫记录.size()
		var 成功渡劫: int = 0
		var 完美渡劫: int = 0
		var 重伤渡劫: int = 0
		var 陨落渡劫: int = 0
		var 最高评分: float = 0.0
		for 记录 in 渡劫记录:
			var 结: String = str(记录.get("结果", ""))
			var 评: float = float(记录.get("评分", 0.0))
			if 结 == "完美":
				完美渡劫 += 1
				成功渡劫 += 1
			elif 结 == "成功":
				成功渡劫 += 1
			elif 结 == "重伤":
				重伤渡劫 += 1
			else:
				陨落渡劫 += 1
			if 评 > 最高评分:
				最高评分 = 评
		渡劫履历行.append(["总渡劫次数", str(总渡劫)])
		渡劫履历行.append(["成功", str(成功渡劫), false, UITheme.COLOR_STATUS_SUCCESS])
		渡劫履历行.append(["完美", str(完美渡劫), false, UITheme.C01_TEXT_GOLD])
		渡劫履历行.append(["重伤", str(重伤渡劫), false, UITheme.COLOR_TEXT_RED])
		渡劫履历行.append(["陨落", str(陨落渡劫), false, UITheme.COLOR_TEXT_RED])
		渡劫履历行.append(["最高评分", "%.1f" % 最高评分])
		# 历史记录列表（最多显示5条）
		if 渡劫记录.size() > 0:
			var 历史标题 := Label.new()
			历史标题.text = "渡劫历史（最近%d次）" % min(5, 渡劫记录.size())
			历史标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
			历史标题.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
			渡劫履历_extra.append(历史标题)
			var 显示条数: int = min(5, 渡劫记录.size())
			for i in range(显示条数):
				var 记录: Dictionary = 渡劫记录[i]
				var 天劫名: String = str(记录.get("天劫名", "未知"))
				var 目标境: String = str(记录.get("目标境", "未知"))
				var 结果: String = str(记录.get("结果", "未知"))
				var 评分: float = float(记录.get("评分", 0.0))
				var 时间: int = int(记录.get("时间", 0))
				var 叙事: String = str(记录.get("叙事", ""))
				var 结果色: Color = UITheme.C01_TEXT_TERTIARY
				match 结果:
					"完美": 结果色 = UITheme.C01_TEXT_GOLD
					"成功": 结果色 = UITheme.COLOR_STATUS_SUCCESS
					"重伤": 结果色 = UITheme.COLOR_TEXT_RED
					"陨落": 结果色 = UITheme.COLOR_TEXT_RED
				var 记录面板 := PanelContainer.new()
				记录面板.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(true))
				var 记录vb := VBoxContainer.new()
				记录vb.add_theme_constant_override("separation", UITheme.GRID / 4)
				记录面板.add_child(记录vb)
				var 记录row1 := HBoxContainer.new()
				记录row1.add_theme_constant_override("separation", UITheme.GRID)
				var 记录名 := Label.new()
				记录名.text = "%s → %s" % [天劫名, 目标境]
				记录名.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
				记录名.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
				记录名.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				记录row1.add_child(记录名)
				var 记录结果 := Label.new()
				记录结果.text = "[%s] 评分：%.1f" % [结果, 评分]
				记录结果.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
				记录结果.add_theme_color_override("font_color", 结果色)
				记录row1.add_child(记录结果)
				记录vb.add_child(记录row1)
				var 记录时间 := Label.new()
				记录时间.text = "第%d游戏日" % 时间
				记录时间.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
				记录时间.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
				记录vb.add_child(记录时间)
				if 叙事 != "":
					var 记录叙事 := Label.new()
					记录叙事.text = 叙事
					记录叙事.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
					记录叙事.add_theme_color_override("font_color", UITheme.C01_TEXT_SECONDARY)
					记录叙事.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					记录vb.add_child(记录叙事)
				渡劫履历_extra.append(记录面板)
		else:
			var 无记录 := Label.new()
			无记录.text = "该弟子尚未经历天劫"
			无记录.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			无记录.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
			渡劫履历_extra.append(无记录)
	_add_section("渡劫履历", 渡劫履历行, "", 渡劫履历_extra)

	# 新增「装备」section（设计规格 §3.1 装备行）；装备红点：存在空槽(<9) 亮暗金点。
	var 装备d = _safe_get(d, "装备", {})
	var 装备红点 := false
	if 装备d is Dictionary and 装备d.size() < _EQUIP_SLOT_COUNT:
		装备红点 = true
	_add_equip_section("装备", d, "gold" if 装备红点 else "", 索引, 装备d)

	# ── 修行操作（P0 核心闭环：阶位试炼 / 罢免接 Game 真实 mutation）──
	if d is Disciple:
		var op_panel := PanelContainer.new()
		op_panel.name = "Section_修行操作"
		UITheme.apply_panel_style(op_panel)
		var op_vbox := VBoxContainer.new()
		op_vbox.add_theme_constant_override("separation", UITheme.GRID)
		op_panel.add_child(op_vbox)
		op_vbox.add_child(_make_section_title("修行操作", ""))
		var op_hb := HBoxContainer.new()
		op_hb.add_theme_constant_override("separation", UITheme.GRID)
		var 试炼_btn := Button.new()
		试炼_btn.name = "TrialBtn"
		试炼_btn.text = "发起试炼"
		试炼_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_button_label(试炼_btn, false)
		试炼_btn.pressed.connect(_on_弟子_试炼.bind(d, 索引, 试炼_btn))
		op_hb.add_child(试炼_btn)
		var 罢免_btn := Button.new()
		罢免_btn.name = "DemoteBtn"
		罢免_btn.text = "罢免阶位"
		罢免_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_button_label(罢免_btn, false)
		罢免_btn.pressed.connect(_on_弟子_罢免.bind(d, 索引, 罢免_btn))
		op_hb.add_child(罢免_btn)
		op_vbox.add_child(op_hb)
		# 驱逐弟子（宗门管理）
		var 驱逐_btn := Button.new()
		驱逐_btn.name = "ExpelBtn"
		驱逐_btn.text = "逐出宗门"
		驱逐_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_button_label(驱逐_btn, false)
		驱逐_btn.pressed.connect(_on驱逐弟子.bind(int(d.弟子ID)))
		op_vbox.add_child(驱逐_btn)
		# 天劫渡劫：仅当下一境需渡劫时展示（元婴→化神 起，至 渡劫→仙阶 止）
		var 渡劫目标境: String = Tribulation.下一境(d.境界)
		if 渡劫目标境 != "" and Tribulation.需渡劫(渡劫目标境):
			var 渡劫_btn: Button = Button.new()
			渡劫_btn.name = "TribulationBtn"
			渡劫_btn.text = "渡劫 · %s" % str(Tribulation.取天劫配置(渡劫目标境).get("tribulation_name", "天劫"))
			渡劫_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UITheme.apply_button_label(渡劫_btn, false)
			渡劫_btn.pressed.connect(_on_弟子_渡劫.bind(d, 索引, 渡劫_btn))
			op_vbox.add_child(渡劫_btn)
		_detail_vbox.add_child(op_panel)

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
			slot.clicked.connect(_on_equip_clicked.bind(索引, it, slot_key))
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
	UITheme.apply_section_title(t)
	hb.add_child(t)
	if dot_type != "":
		hb.add_child(_make_red_dot(dot_type == "danger"))
	return hb

func _make_red_dot(danger: bool) -> Control:
	# 使用统一红点样式（大厂标准：红色圆形+白色描边）
	var dot: Panel = UITheme.make_red_dot(12.0)
	dot.name = "RedDot"
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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

func _on_equip_clicked(item_id: String, 索引: int, it: Variant, slot_key: String) -> void:
	# 占位信号保留（双轨，与弟子详情页风格一致）；同时页内直接展开装备详情。
	弟子装备查看请求.emit(索引)
	_show_equip_detail(索引, it, slot_key)

func _show_equip_detail(索引: int, it: Variant, slot_key: String) -> void:
	if it == null:
		return
	_populate_equip_detail(it, slot_key)
	_detail_root.visible = false
	UITween.fade_in(_equip_detail_root)

func _on_equip_detail_back() -> void:
	_equip_detail_root.visible = false
	_detail_root.visible = true

func _populate_equip_detail(it: Variant, slot_key: String) -> void:
	if _equip_detail_vbox == null:
		return
	for child in _equip_detail_vbox.get_children():
		_equip_detail_vbox.remove_child(child)
		child.queue_free()

	var 名称v = str(_safe_get(it, "名称", "—"))
	var 品阶v = str(_safe_get(it, "品阶", "凡阶"))
	var 类别v = str(_safe_get(it, "类别", "—"))
	var 穿戴位v = str(_safe_get(it, "穿戴位", ""))
	var 道途v = str(_safe_get(it, "道途", ""))
	var 战力v = _safe_get(it, "战力加成", 0)
	var 功效v = str(_safe_get(it, "功效", "—"))
	var 描述v = str(_safe_get(it, "描述", "—"))
	var 极品v = _safe_get(it, "极品", false)
	var 词缀v = _safe_get(it, "词缀", [])
	var 极品属性v = _safe_get(it, "极品属性", null)

	# 名称大标题（品阶色）
	var 品阶stem = _ITEM_QUALITY_STEM.get(品阶v, "fan")
	var 品阶色 = UIThemeConfig.get_quality_color(品阶stem)
	var title := Label.new()
	title.text = 名称v
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_page_title(title)
	title.add_theme_color_override("font_color", 品阶色)
	_equip_detail_vbox.add_child(title)

	# 基础属性 KV（品阶上色）
	var 穿戴位cn = _EQUIP_SLOT_CN.get(穿戴位v, 穿戴位v)
	var kv: Array = [
		["类别", 类别v],
		["品阶", 品阶v, false, 品阶色],
		["穿戴位", 穿戴位cn if 穿戴位v != "" else "—"],
		["道途", 道途v if 道途v != "" else "—"],
		["战力加成", "+%d" % int(战力v)],
	]
	if bool(极品v):
		kv.append(["品质", "极品"])
	_add_section("基础属性", kv)

	# 功效 / 描述 长文本块
	_add_text_block("功效", 功效v)
	_add_text_block("描述", 描述v)

	# 词缀列表（中文名 + 数值% + 档位）
	if 词缀v is Array and 词缀v.size() > 0:
		var lines: Array = []
		for a in 词缀v:
			if a is Dictionary:
				var 类 = "前缀" if bool(a.get("前缀", false)) else "后缀"
				var 名key = str(a.get("名", ""))
				var 中文名 = str(Item.词缀中文名.get(名key, 名key))
				var 档key = str(a.get("档", ""))
				var 档中文 = str(Item.词缀档中文名.get(档key, 档key))
				var 数值 = int(a.get("数值", 0))
				var 符 = "+" if 数值 >= 0 else ""
				lines.append("· [%s]%s %s%d%%（%s）" % [类, 中文名, 符, 数值, 档中文])
		_add_text_block("词缀（%d 条）" % 词缀v.size(), "\n".join(lines) if lines.size() > 0 else "—")

	# 极品特异词条
	if 极品属性v is Dictionary:
		var 名 = str(极品属性v.get("名", ""))
		var 描述 = str(极品属性v.get("描述", ""))
		_add_text_block("极品特异词条", "【%s】%s" % [名, 描述])

func _add_text_block(标题: String, 文本: String) -> void:
	var panel := PanelContainer.new()
	panel.name = "EquipTextBlock"
	UITheme.apply_panel_style(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)
	vbox.add_child(_make_section_title(标题, ""))
	var lbl := Label.new()
	lbl.text = 文本 if 文本 != "" else "—"
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_body_font(lbl)
	vbox.add_child(lbl)
	_equip_detail_vbox.add_child(panel)

# 原生 Button pressed 统一接 UITween.button_press（设计规格 §3.3），再触发业务回调。
func _on_btn_press(btn: Control, cb: Callable) -> void:
	UITween.button_press(btn)
	cb.call()

# ── 修行操作 handler（P0 核心闭环：接 Game 真实 mutation，严守数据层不可动）──
## 打开天劫渡劫弹窗（CanvasLayer 模态，复用 avatar_select_popup 范式）
## 弹窗自包含（ui/tribulation_popup.gd），预览走 Tribulation、结算走 Game.执行弟子渡劫。
func _on_弟子_渡劫(d: Object, 索引: int, btn: Button = null) -> void:
	if btn != null:
		UITween.button_press(btn)
	if not (d is Disciple) or not is_instance_valid(d):
		return
	var 脚本 = load("res://ui/tribulation_popup.gd")
	if 脚本 == null:
		push_error("tribulation_popup.gd 加载失败")
		return
	var popup层: CanvasLayer = CanvasLayer.new()
	popup层.name = "TribulationPopupLayer"
	popup层.layer = 100
	var 容器: Control = Control.new()
	容器.name = "Container"
	容器.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	容器.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup层.add_child(容器)
	add_child(popup层)
	var popup: Control = Control.new()
	popup.set_script(脚本)
	popup.配置(d)
	容器.add_child(popup)
	popup.渡劫结束.connect(func(_通过: bool) -> void:
		call_deferred("_populate_detail", d, 索引)
	)

func _on_弟子_试炼(d: Object, 索引: int, btn: Button = null) -> void:
	if btn != null:
		UITween.button_press(btn)
	if not (d is Disciple) or not is_instance_valid(d):
		return
	if not is_instance_valid(Game) or not Game.has_method("发起试炼"):
		if is_instance_valid(Game) and Game.has_method("添加提示"):
			Game.添加提示("试炼功法未就绪")
		return
	var r: Dictionary = Game.发起试炼(d as Disciple)
	var 文本: String
	if bool(r.get("ok", false)):
		文本 = "试炼成功，晋阶 %s" % str(r.get("阶位", ""))
	else:
		文本 = str(r.get("原因", "试炼未成"))
	if is_instance_valid(Game) and Game.has_method("添加提示"):
		Game.添加提示(文本)
	call_deferred("_populate_detail", d, 索引)

func _on_弟子_罢免(d: Object, 索引: int, btn: Button = null) -> void:
	if btn != null:
		UITween.button_press(btn)
	if not (d is Disciple) or not is_instance_valid(d):
		return
	if not is_instance_valid(Game) or not Game.has_method("罢免阶位"):
		if is_instance_valid(Game) and Game.has_method("添加提示"):
			Game.添加提示("罢免功法未就绪")
		return
	var r: Dictionary = Game.罢免阶位(d as Disciple)
	var 文本: String = "罢免完成" if bool(r.get("ok", false)) else str(r.get("原因", "罢免未成"))
	if is_instance_valid(Game) and Game.has_method("添加提示"):
		Game.添加提示(文本)
	call_deferred("_populate_detail", d, 索引)

func _on_举办测灵根(btn: Button = null) -> void:
	if btn != null:
		UITween.button_press(btn)
	if not is_instance_valid(Game) or not Game.has_method("举办测灵根"):
		if is_instance_valid(Game) and Game.has_method("添加提示"):
			Game.添加提示("测灵根功法未就绪")
		return
	var r: Dictionary = Game.举办测灵根()
	var 文本: String
	if int(r.get("冷却剩余", 0)) > 0:
		文本 = "测灵根气机未复（剩余 %d 日）" % int(r.get("冷却剩余", 0))
	else:
		文本 = "招收新徒 %d 人" % int(r.get("人数", 0))
	if is_instance_valid(Game) and Game.has_method("添加提示"):
		Game.添加提示(文本)
	refresh.call_deferred()

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


# S1-4 付费：仙玉加速全体弟子修炼（调用 Game._pay_reserved_修炼加成）
func _on_付费_修炼(_btn: Button = null) -> void:
	if not is_instance_valid(Game):
		return
	var r: Dictionary = Game._pay_reserved_修炼加成()
	if r.get("成功", false):
		UIHint.show_hint(self, "修炼加速", "全体弟子推进 7 日修炼")
	else:
		UIHint.show_hint(self, "仙玉匮乏", str(r.get("原因", "")))
	refresh()

# ───────────────── S36 心魔誓（宗门誓约事务区）─────────────────
func _build_oath_area() -> void:
	_oath_area = VBoxContainer.new()
	_oath_area.name = "OathArea"
	_oath_area.add_theme_constant_override("separation", UITheme.GRID)
	_list_root.add_child(_oath_area)
	_list_root.move_child(_oath_area, 0)

func _populate_oath_area() -> void:
	if _oath_area == null or Game == null:
		return
	for c in _oath_area.get_children():
		_oath_area.remove_child(c)
		c.queue_free()
	# ① 弟子请誓待批
	var 待批: Array = Game.誓约待批
	if 待批.size() > 0:
		var t1: Label = Label.new()
		t1.text = "弟子请誓（%d）" % 待批.size()
		UITheme.apply_section_title(t1)
		_oath_area.add_child(t1)
		for i in range(待批.size()):
			var 项: Dictionary = 待批[i] as Dictionary
			var 行: PanelContainer = PanelContainer.new()
			UITheme.apply_panel_style(行)
			_oath_area.add_child(行)
			var vb: VBoxContainer = VBoxContainer.new()
			vb.add_theme_constant_override("separation", 4)
			行.add_child(vb)
			var 名: Label = Label.new()
			名.text = "%s 请立「%s」" % [str(项.get("弟子名", "某弟子")), str(项.get("名称", ""))]
			UITheme.apply_body_text(名)
			vb.add_child(名)
			var 描: Label = Label.new()
			描.text = str(项.get("desc", ""))
			描.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UITheme.apply_aux_text(描)
			vb.add_child(描)
			var hb: HBoxContainer = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 8)
			vb.add_child(hb)
			var b1: Button = Button.new()
			b1.text = "准"
			UITheme.apply_primary_button_style(b1)
			b1.pressed.connect(_on_批准请誓.bind(i))
			hb.add_child(b1)
			var b2: Button = Button.new()
			b2.text = "驳回"
			UITheme.apply_secondary_button_style(b2)
			b2.pressed.connect(_on_驳回请誓.bind(i))
			hb.add_child(b2)
	# ② 万仙大誓
	var 大誓: Dictionary = Game.万仙大誓
	if not 大誓.is_empty():
		var t2: Label = Label.new()
		t2.text = "万仙大誓"
		UITheme.apply_section_title(t2)
		_oath_area.add_child(t2)
		var info: Label = Label.new()
		info.text = "「%s」　剩余 %d / %d 日　全宗修炼×%.2f" % [
			str(大誓.get("名称", "")), int(大誓.get("剩余日", 0)),
			int(大誓.get("期限", 0)), float(大誓.get("buff_cult", 1.0))]
		UITheme.apply_body_text(info)
		_oath_area.add_child(info)
		return
	var 表: Dictionary = Game._读表_万仙大誓()
	if 表.is_empty():
		return
	var t3: Label = Label.new()
	t3.text = "万仙大誓（全宗共誓）"
	UITheme.apply_section_title(t3)
	_oath_area.add_child(t3)
	for k in 表.keys():
		var 配: Dictionary = 表[k] as Dictionary
		var 行2: PanelContainer = PanelContainer.new()
		UITheme.apply_panel_style(行2)
		_oath_area.add_child(行2)
		var vb2: VBoxContainer = VBoxContainer.new()
		vb2.add_theme_constant_override("separation", 4)
		行2.add_child(vb2)
		var n2: Label = Label.new()
		n2.text = "%s（限期%d日）" % [str(配.get("name", "")), int(配.get("duration_days", 14))]
		UITheme.apply_body_text(n2)
		vb2.add_child(n2)
		var d2: Label = Label.new()
		d2.text = str(配.get("desc", ""))
		d2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_aux_text(d2)
		vb2.add_child(d2)
		var btn: Button = Button.new()
		btn.text = "率全宗共誓"
		UITheme.apply_primary_button_style(btn)
		btn.pressed.connect(_on_发起万仙大誓.bind(str(k)))
		vb2.add_child(btn)

func _on_批准请誓(idx: int) -> void:
	if Game == null:
		return
	Game.批准请誓(idx)
	refresh()

func _on_驳回请誓(idx: int) -> void:
	if Game == null:
		return
	Game.驳回请誓(idx)
	refresh()

func _on_发起万仙大誓(so_id: String) -> void:
	if Game == null:
		return
	Game.发起万仙大誓(so_id)
	refresh()

# P1优化：批量操作
func _on_批量操作(btn: Button) -> void:
	if Game == null:
		return
	# 弹出批量操作菜单（简单实现：直接执行常用批量操作）
	var 外门数: int = Game.外门弟子数()
	var 晋升数: int = 0
	# 一键晋升满足条件的外门弟子（筑基以上自动晋升内门）
	for d in Game.弟子列表:
		if d != null and d is Disciple and d.身份 == "外门":
			var 境界序: int = Disciple.境界序.find(d.境界)
			if 境界序 >= Disciple.境界序.find("筑基"):
				d.身份 = "内门弟子"
				晋升数 += 1
	# 一键赏赐所有弟子（增加忠诚度）
	var 赏赐数: int = 0
	for d in Game.弟子列表:
		if d != null and d is Disciple and d.忠诚 < 80:
			d.忠诚 = min(100, d.忠诚 + 5)
			赏赐数 += 1
	UIHint.show_hint(self, "批量操作完成", "晋升外门弟子%d名，赏赐弟子%d名" % [晋升数, 赏赐数])
	Game.弟子变动.emit()
	refresh()

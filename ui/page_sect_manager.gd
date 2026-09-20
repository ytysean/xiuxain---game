## 宗主管理系统页面
## 整合宗门的各种管理功能：发展路线、殿阁任命、弟子任职、戒律裁决、请示回应、批阅、科技、外交、议事会等

extends Control

signal 返回主页

const SectManager := preload("res://sect_manager.gd")

var _built: bool = false
var _current_tab: String = "概览"
var _body: VBoxContainer
var _content: VBoxContainer
# S2 商路贸易：派遣配置面板瞬时状态
var _派遣地区: Dictionary = {}
var _货物勾选: Dictionary = {}
var _派遣载具选: OptionButton = null
var _派遣可用载具: Array = []
var _派遣神行符勾选: CheckBox = null   # §11.15 优化：派遣面板「使用神行符」勾选状态
var _派遣灵舟选: OptionButton = null
var _派遣可用灵舟: Array = []
var _派遣岗位选: Dictionary = {}
var _派遣运力提示: Label = null
var _派遣接商单: String = ""   # §11.15 优化#74：本次派遣所接特殊商单（city_id；空=未接）
var _上次编组: Dictionary = {}  # §11.15 优化#66：上次成功派遣的编组（重复派遣用）
var _应用上次编组: bool = false  # §11.15 优化#66：本次开面板是否自动套用上次编组
var _tab_btns: Dictionary = {}
var _管理器: SectManager = null
# S27 宗门任务榜：发布面板瞬时状态
var _发布模板选: String = ""   # 当前选中的任务模板ID
var _发布档差: int = 0          # 报酬品阶相对标准档的档差（-2~+2）
var _任务榜提示: String = ""   # 上一次操作的结果回执
# S28 功勋堂：代兑面板瞬时状态
var _功勋弟子选: int = -1      # 当前选中的弟子ID（-1 = 未选）
var _功勋提示: String = ""     # 上一次兑换操作的结果回执
# 兽潮防务：上一次处置兽潮的回执文本（切换 tab 后仍保留，便于玩家确认结果）
var _兽潮回执: String = ""
# 宗门战事：上一次战事操作的回执文本
var _战事回执: String = ""
# 宗门战事：发起战争时选中的目标势力
var _战事目标选: String = ""
# 宗门战事：可宣战的势力列表
const 可宣战势力: Array = ["魔道邪宗", "中立散修", "上古妖兽", "远古遗泽", "丹器师公会"]
# 兽潮三策略说明（Game.兽潮防御 只接受这三个字符串）
const 兽潮策略说明: Dictionary = {
	"坚守": "以护山大阵硬扛：损失×0.5，另得奖励×0.5。最稳妥。",
	"出击": "主动迎战：胜则奖励×2并得 20 悟道点，败则损失×2。",
	"求和": "献灵石换退兵：无战斗无奖励，灵石不足则失败。",
}

const TABS = ["概览", "发展路线", "殿阁任命", "弟子任职", "戒律裁决", "弟子请示", "宗主批阅", "核心弟子", "宗门科技", "对外关系", "议事会", "商队管理", "阵营声望", "宗门派系", "宗门方针", "奏折决策", "宗门任务", "功勋堂", "兽潮防务", "宗门战事", "宗主道号", "护道人"]

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

	# 获取管理器实例
	_管理器 = get_node_or_null("/root/SectManager")
	if _管理器 == null:
		_管理器 = SectManager.new()
		_管理器.name = "SectManager"
		get_tree().root.add_child(_管理器)

	var content: Control = UITheme.make_scene_background(self)
	_body = VBoxContainer.new()
	_body.name = "Root"
	_body.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_right", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_top", UITheme.GRID)
	_body.add_theme_constant_override("margin_bottom", UITheme.GRID)
	_body.add_theme_constant_override("separation", UITheme.GRID)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(_body)

	_build_header(_body)
	_build_tabs(_body)
	_build_content_area(_body)

func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	parent.add_child(UITheme.建顶栏("宗主管理", _on_back_pressed, []))
func _build_tabs(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# S27：tab 增至 16 个，纵向改为可滚动，否则两列排布下第 5 个之后的 tab 无法触达
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, int(round(80.0 * UITheme.UI_SCALE)))
	parent.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UITheme.GRID / 2)
	grid.add_theme_constant_override("v_separation", UITheme.GRID / 2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for t in TABS:
		var btn := Button.new()
		btn.text = t
		btn.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_tab_pressed.bind(t))
		grid.add_child(btn)
		_tab_btns[t] = btn
	_update_tab_styles()

func _build_content_area(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_content)

func refresh() -> void:
	if not _built:
		_build()
	_update_tab_styles()
	_populate()

func _populate() -> void:
	for child in _content.get_children():
		child.queue_free()

	match _current_tab:
		"概览":
			_populate_overview()
		"发展路线":
			_populate_development_route()
		"殿阁任命":
			_populate_hall_appointment()
		"弟子任职":
			_populate_disciple_position()
		"戒律裁决":
			_populate_discipline()
		"弟子请示":
			_populate_requests()
		"宗主批阅":
			_populate_reviews()
		"核心弟子":
			_populate_core_disciples()
		"宗门科技":
			_populate_technology()
		"对外关系":
			_populate_diplomacy()
		"议事会":
			_populate_council()
		"商队管理":
			_populate_caravan()
		"阵营声望":
			_populate_faction()
		"宗门派系":
			_populate_faction_power()
		"宗门方针":
			_populate_policy()
		"奏折决策":
			_populate_memorial()
		"宗门任务":
			_populate_bounty()
		"功勋堂":
			_populate_merit()
		"兽潮防务":
			_populate_beast_wave()
		"宗门战事":
			_populate_war()
		"宗主道号":
			_populate_master_title()
		"护道人":
			_populate_hudao()

# ── 兽潮防务 ────────────────────────────────────────────────
# Game.兽潮防御(策略) 早有完整实现却长期零调用：兽潮月度触发检查 会触发兽潮，
# 但只有 兽潮防御 会清空 当前兽潮 —— 没有调用方就等于「兽潮触发一次后永久卡死」。
# 本 tab 把三个策略接成玩家可点的决策，死 API 由此变活。
func _populate_beast_wave() -> void:
	var card := _make_card("兽潮防务")
	var vb := card.find_child("VBox", true, false)

	var desc := Label.new()
	desc.text = "兽潮来袭须择一应对。在宗弟子的总道行越高，坚守减伤越多、出击胜率越高。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	var 兽潮: Dictionary = Game.获取当前兽潮() if Game != null else {}
	if 兽潮.is_empty():
		var idle := Label.new()
		idle.text = "当前无兽潮，山门安宁。"
		UITheme.apply_aux_text(idle)
		vb.add_child(idle)
		_content.add_child(card)
		return

	_add_info_row(vb, "兽潮名称", str(兽潮.get("名称", "未知")))
	_add_info_row(vb, "推荐道行", str(int(兽潮.get("推荐战力", 0))))
	_add_info_row(vb, "剩余怪物", str(int(兽潮.get("剩余怪物", 0))))
	_add_info_row(vb, "基础伤害", str(int(兽潮.get("基础伤害", 0))))
	_add_info_row(vb, "基础奖励", str(int(兽潮.get("基础奖励", 0))))

	var 宗门总战力: int = 0
	if Game != null:
		for d in Game.弟子列表:
			if d != null and d is Disciple and d.状态 == "在宗":
				宗门总战力 += int(d.战力)
	_add_info_row(vb, "宗门总道行", str(宗门总战力))

	for 策略 in 兽潮策略说明.keys():
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", UITheme.GRID)

		var btn := Button.new()
		btn.text = 策略
		btn.custom_minimum_size = Vector2(120, 0)
		# 循环内 lambda 捕获为引用，统一用 bind 传值（项目按钮回调范式）
		btn.pressed.connect(_on_兽潮策略.bind(策略))
		hb.add_child(btn)

		var lbl := Label.new()
		lbl.text = str(兽潮策略说明[策略])
		UITheme.apply_aux_text(lbl)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lbl)

		vb.add_child(hb)

	if not _兽潮回执.is_empty():
		var ret := Label.new()
		ret.text = _兽潮回执
		UITheme.apply_aux_text(ret)
		ret.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(ret)

	_content.add_child(card)

func _on_兽潮策略(策略: String) -> void:
	if Game == null:
		return
	var 结果: Dictionary = Game.兽潮防御(策略)
	if bool(结果.get("成功", false)):
		_兽潮回执 = str(结果.get("描述", "已处置"))
	else:
		_兽潮回执 = str(结果.get("原因", "处置失败"))
	refresh()

# ── 宗门战事 ────────────────────────────────────────────────
# 势力战争 + 阵营战争（正魔大战）的统一入口
func _populate_war() -> void:
	# 阵营战争（正魔大战）
	var 阵营战争: Dictionary = Game.获取进行中阵营战争() if Game != null else {}
	if not 阵营战争.is_empty():
		var card := _make_card("正魔大战")
		var vb := card.find_child("VBox", true, false)

		var desc := Label.new()
		desc.text = "正魔大战正酣，宗门须择一立场。参战可得阵营声望，中立可坐收渔利。"
		UITheme.apply_body_text(desc)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(desc)

		_add_info_row(vb, "战争名称", str(阵营战争.get("名称", "正魔大战")))
		_add_info_row(vb, "已过月数", "%d / %d" % [int(阵营战争.get("已过月数", 0)), int(阵营战争.get("持续月数", 3))])
		_add_info_row(vb, "正道战绩", str(int(阵营战争.get("正道战绩", 0))))
		_add_info_row(vb, "魔道战绩", str(int(阵营战争.get("魔道战绩", 0))))

		# 阵营选择按钮
		var 阵营选项: Dictionary = {
			"参战正道": "投入正道阵营，共抗魔道。正道声望+20，魔道声望-10",
			"参战魔道": "投入魔道阵营，与正道为敌。魔道声望+20，正道声望-10",
			"中立": "闭关中立，坐山观虎斗，得灵石100",
			"渔利": "趁乱取利，50%几率得灵石300-600，失败则损200-400",
		}
		for 选择 in 阵营选项.keys():
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", UITheme.GRID)
			var btn := Button.new()
			btn.text = 选择
			btn.custom_minimum_size = Vector2(120, 0)
			btn.pressed.connect(_on_阵营选择.bind(选择))
			hb.add_child(btn)
			var lbl := Label.new()
			lbl.text = str(阵营选项[选择])
			UITheme.apply_aux_text(lbl)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(lbl)
			vb.add_child(hb)

		_content.add_child(card)

	# 势力战争
	var 进行中战争: Dictionary = Game.获取进行中战争() if Game != null else {}
	var card2 := _make_card("势力征伐")
	var vb2 := card2.find_child("VBox", true, false)

	if 进行中战争.is_empty():
		# 无进行中战争，显示发起战争面板
		var desc := Label.new()
		desc.text = "宗门兵强马壮，可对外征伐。选择目标势力，遣弟子出战。"
		UITheme.apply_body_text(desc)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb2.add_child(desc)

		_add_info_row(vb2, "可争夺资源", "、".join(Game.获取可争夺资源点()) if Game != null else "")

		# 目标势力选择
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", UITheme.GRID)
		var lbl := Label.new()
		lbl.text = "目标势力："
		UITheme.apply_body_text(lbl)
		hb.add_child(lbl)
		var opt := OptionButton.new()
		for 势力 in 可宣战势力:
			opt.add_item(势力)
		if _战事目标选 == "":
			_战事目标选 = 可宣战势力[0]
		opt.select(可宣战势力.find(_战事目标选))
		opt.item_selected.connect(_on_战事目标选)
		hb.add_child(opt)
		vb2.add_child(hb)

		# 发起战争按钮
		var btn := Button.new()
		btn.text = "宣战出征"
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_on_发起战争)
		vb2.add_child(btn)
	else:
		# 有进行中战争，显示战争状态
		var desc := Label.new()
		desc.text = "战事正酣，可推进阵前交锋。"
		UITheme.apply_body_text(desc)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb2.add_child(desc)

		_add_info_row(vb2, "战争类型", str(进行中战争.get("类型", "未知")))
		_add_info_row(vb2, "目标势力", str(进行中战争.get("目标势力", "未知")))
		_add_info_row(vb2, "当前阵次", "%d / %d" % [int(进行中战争.get("回合", 0)), int(进行中战争.get("最大回合", 3))])
		_add_info_row(vb2, "我军法力", str(int(进行中战争.get("攻方战力", 0))))
		_add_info_row(vb2, "敌军法力", str(int(进行中战争.get("守方战力", 0))))
		_add_info_row(vb2, "我军折损", str(int(进行中战争.get("攻方损失", 0))))
		_add_info_row(vb2, "敌军折损", str(int(进行中战争.get("守方损失", 0))))

		# 推进回合按钮
		var btn := Button.new()
		btn.text = "推进阵前交锋"
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_on_推进战争)
		vb2.add_child(btn)

	# 战事回执
	if not _战事回执.is_empty():
		var ret := Label.new()
		ret.text = _战事回执
		UITheme.apply_aux_text(ret)
		ret.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb2.add_child(ret)

	_content.add_child(card2)

func _on_战事目标选(idx: int) -> void:
	if idx >= 0 and idx < 可宣战势力.size():
		_战事目标选 = 可宣战势力[idx]

func _on_发起战争() -> void:
	if Game == null:
		return
	# 自动选择在宗弟子作为出战队伍
	var 出战队伍: Array = []
	for d in Game.弟子列表:
		if d != null and d is Disciple and d.状态 == "在宗":
			出战队伍.append({"战力": d.战力, "姓名": d.姓名})
	if 出战队伍.is_empty():
		_战事回执 = "宗门无在宗弟子，无法出征"
		refresh()
		return
	var 结果: Dictionary = Game.发起势力战争("征伐", _战事目标选, 出战队伍)
	if bool(结果.get("成功", false)):
		_战事回执 = "已向%s宣战，战事开启！" % _战事目标选
	else:
		_战事回执 = str(结果.get("原因", "宣战失败"))
	refresh()

func _on_推进战争() -> void:
	if Game == null:
		return
	var 结果: Dictionary = Game.推进战争回合()
	if bool(结果.get("成功", false)):
		var msg: String = str(结果.get("回合结果", ""))
		if bool(结果.get("战争结束", false)):
			msg += "\n" + str(结果.get("战争结果", ""))
		_战事回执 = msg
	else:
		_战事回执 = str(结果.get("原因", "推进失败"))
	refresh()

func _on_阵营选择(选择: String) -> void:
	if Game == null:
		return
	var 结果: Dictionary = Game.阵营战争玩家选择(选择)
	if bool(结果.get("成功", false)):
		_战事回执 = str(结果.get("描述", "已选择"))
	else:
		_战事回执 = str(结果.get("原因", "选择失败"))
	refresh()

# ── 宗主道号 ────────────────────────────────────────────────
func _populate_master_title() -> void:
	if Game == null:
		return
	var card := _make_card("宗主道号")
	var vb := card.find_child("VBox", true, false)

	var desc := Label.new()
	desc.text = "宗主道号彰显宗门之主的修为与威望，装备后可获全宗增益。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	# 当前称号
	var 当前称号ID: String = Game.宗主当前称号 if "宗主当前称号" in Game else ""
	if 当前称号ID != "":
		var t: Dictionary = Game.获取称号详情(当前称号ID)
		if not t.is_empty():
			var cur_hb := HBoxContainer.new()
			cur_hb.add_theme_constant_override("separation", 12)
			var icon := Label.new()
			icon.text = "★"
			UITheme.apply_project_font(icon, UITheme.FONT_DISPLAY, true)
			cur_hb.add_child(icon)
			var cur_vb := VBoxContainer.new()
			cur_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var name_lbl := Label.new()
			name_lbl.text = str(t.get("title_name", ""))
			var 品质: String = str(t.get("quality", "凡品"))
			name_lbl.add_theme_color_override("font_color", Game.获取称号品质颜色(品质))
			UITheme.apply_project_font(name_lbl, UITheme.FONT_H1, true)
			cur_vb.add_child(name_lbl)
			var desc_lbl := Label.new()
			var 加成类型: String = str(t.get("bonus_type", ""))
			var 加成值: float = float(t.get("bonus_value", 0))
			var 加成文本: String = ""
			match 加成类型:
				"全宗修炼": 加成文本 = "全宗修炼速度+%.0f%%" % (加成值 * 100)
				"全宗产出": 加成文本 = "全宗产出+%.0f%%" % (加成值 * 100)
				"全宗战力": 加成文本 = "全宗道行+%.0f%%" % (加成值 * 100)
				"全宗突破": 加成文本 = "全宗突破率+%.0f%%" % (加成值 * 100)
				"全宗悟道": 加成文本 = "全宗悟道+%.0f%%" % (加成值 * 100)
				"全属性": 加成文本 = "全属性+%.0f%%" % (加成值 * 100)
			desc_lbl.text = "%s [%s] %s" % [str(t.get("description", "")), 品质, 加成文本]
			UITheme.apply_aux_text(desc_lbl)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cur_vb.add_child(desc_lbl)
			cur_hb.add_child(cur_vb)
			vb.add_child(cur_hb)
	else:
		var idle := Label.new()
		idle.text = "宗主尚未获得道号尊称"
		UITheme.apply_aux_text(idle)
		vb.add_child(idle)

	# 已获得称号列表
	var section_title := Label.new()
	section_title.text = "已得道号"
	UITheme.apply_section_title(section_title)
	vb.add_child(section_title)
	var 已获得: Array = Game.宗主已获得称号 if "宗主已获得称号" in Game else []
	if 已获得.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "尚未获得任何道号，提升宗主修为与宗门品级可得。"
		UITheme.apply_aux_text(empty_lbl)
		vb.add_child(empty_lbl)
	else:
		for tid in 已获得:
			var t: Dictionary = Game.获取称号详情(str(tid))
			if t.is_empty():
				continue
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 8)
			var name_lbl := Label.new()
			name_lbl.text = str(t.get("title_name", ""))
			var 品质: String = str(t.get("quality", "凡品"))
			name_lbl.add_theme_color_override("font_color", Game.获取称号品质颜色(品质))
			name_lbl.custom_minimum_size = Vector2(120, 0)
			hb.add_child(name_lbl)
			var desc_lbl := Label.new()
			desc_lbl.text = str(t.get("description", ""))
			UITheme.apply_aux_text(desc_lbl)
			desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(desc_lbl)
			if str(tid) != 当前称号ID:
				var equip_btn := Button.new()
				equip_btn.text = "装备"
				equip_btn.custom_minimum_size = Vector2(60, 28)
				equip_btn.pressed.connect(func(): _装备宗主称号(str(tid)))
				hb.add_child(equip_btn)
			else:
				var equipped_lbl := Label.new()
				equipped_lbl.text = "[当前]"
				equipped_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
				hb.add_child(equipped_lbl)
			vb.add_child(hb)

	_content.add_child(card)

func _装备宗主称号(title_id: String) -> void:
	if Game == null:
		return
	Game.宗主当前称号 = title_id
	refresh()

func _populate_overview() -> void:
	# 宗门概览
	var card := _make_card("宗门概览")
	var vb := card.find_child("VBox", true, false)

	var 路线名 = _管理器.获取发展路线() if _管理器 != null else "均衡发展"
	_add_info_row(vb, "当前发展路线", 路线名)
	_add_info_row(vb, "待裁决违规", str(_管理器.获取待裁决违规().size()) if _管理器 != null else "0")
	_add_info_row(vb, "待回应请示", str(_管理器.获取待回应请示().size()) if _管理器 != null else "0")
	_add_info_row(vb, "待批阅事务", str(_管理器.获取待批阅事务().size()) if _管理器 != null else "0")
	_add_info_row(vb, "核心弟子数", str(_管理器.获取核心弟子列表().size()) if _管理器 != null else "0")
	_add_info_row(vb, "已研究科技", str(_管理器.获取已研究科技().size()) if _管理器 != null else "0")
	_add_info_row(vb, "待决奏折", str(Game.待决奏折.size()) if Game != null else "0")
	# 兽潮触发后若未处置，月度触发检查会因「当前兽潮非空」而不再刷新 —— 必须在概览给出可见入口
	if Game != null and not Game.当前兽潮.is_empty():
		_add_info_row(vb, "兽潮警报", "有兽潮来袭，请到「兽潮防务」处置")
	# 战争进行中提示
	if Game != null and not Game.获取进行中战争().is_empty():
		_add_info_row(vb, "战事警报", "有进行中的征伐，请到「宗门战事」推进")
	if Game != null and not Game.获取进行中阵营战争().is_empty():
		_add_info_row(vb, "阵营战事", "正魔大战正酣，请到「宗门战事」择定立场")

	_content.add_child(card)

	# 快捷操作提示
	var tip := Label.new()
	tip.text = "提示：轻触上方各栏进入对应管理功能"
	UITheme.apply_aux_text(tip)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(tip)

func _populate_development_route() -> void:
	var card := _make_card("宗门发展路线")
	var vb := card.find_child("VBox", true, false)

	var desc := Label.new()
	desc.text = "选择宗门发展路线，将获得对应加成，但其他领域会略有下降。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	for 路线名 in SectManager.发展路线.keys():
		var 路线数据 = SectManager.发展路线[路线名]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", UITheme.GRID)

		var btn := Button.new()
		btn.text = 路线名
		btn.custom_minimum_size = Vector2(120, 0)
		if _管理器 != null and _管理器.获取发展路线() == 路线名:
			btn.disabled = true
			UITheme.apply_button_label(btn, true)
		btn.pressed.connect(func():
			if _管理器 != null:
				_管理器.设置发展路线(路线名)
				refresh()
		)
		hb.add_child(btn)

		var lbl := Label.new()
		lbl.text = 路线数据["desc"]
		UITheme.apply_aux_text(lbl)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lbl)

		vb.add_child(hb)

	_content.add_child(card)

func _populate_hall_appointment() -> void:
	var card := _make_card("殿阁负责人任命")
	var vb := card.find_child("VBox", true, false)

	var desc := Label.new()
	desc.text = "任命弟子担任各殿阁负责人，负责人天赋越高，殿阁效率加成越大。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	for 殿阁 in SectManager.殿阁列表:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", UITheme.GRID)

		var 名 := Label.new()
		名.text = 殿阁
		名.custom_minimum_size = Vector2(100, 0)
		UITheme.apply_body_text(名)
		hb.add_child(名)

		var 当前负责人ID = _管理器.获取殿阁负责人(殿阁) if _管理器 != null else -1
		var 负责人名 = "未任命"
		if 当前负责人ID >= 0 and Game != null:
			var d = _获取弟子(当前负责人ID)
			if d != null:
				负责人名 = str(d.姓名)

		var lbl := Label.new()
		lbl.text = "当前：" + 负责人名
		UITheme.apply_aux_text(lbl)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lbl)

		var btn := Button.new()
		btn.text = "任命"
		btn.custom_minimum_size = Vector2(80, 0)
		btn.pressed.connect(func():
			_弹出任命弟子(殿阁)
		)
		hb.add_child(btn)

		vb.add_child(hb)

	_content.add_child(card)

func _populate_disciple_position() -> void:
	var card := _make_card("弟子任职分配")
	var vb := card.find_child("VBox", true, false)

	var desc := Label.new()
	desc.text = "分配弟子到各殿阁任职，任职弟子在对应领域效率+50%。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	if Game != null:
		var 弟子列表 = Game.get("弟子列表")
		if 弟子列表 != null:
			for d in 弟子列表:
				if d == null:
					continue
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", UITheme.GRID)

				var 名 := Label.new()
				名.text = str(d.姓名)
				名.custom_minimum_size = Vector2(100, 0)
				UITheme.apply_body_text(名)
				hb.add_child(名)

				var 任职 = _管理器.获取弟子任职(int(d.弟子ID)) if _管理器 != null else {}
				var 任职名 = "未任职"
				if not 任职.is_empty():
					任职名 = 任职.get("殿阁", "") + "·" + 任职.get("岗位", "")

				var lbl := Label.new()
				lbl.text = "当前：" + 任职名
				UITheme.apply_aux_text(lbl)
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hb.add_child(lbl)

				var btn := Button.new()
				btn.text = "分配"
				btn.custom_minimum_size = Vector2(80, 0)
				btn.pressed.connect(func():
					_弹出分配任职(int(d.弟子ID))
				)
				hb.add_child(btn)

				var 解btn := Button.new()
				解btn.text = "解除"
				解btn.custom_minimum_size = Vector2(80, 0)
				解btn.pressed.connect(func():
					if _管理器 != null:
						_管理器.解除弟子任职(int(d.弟子ID))
						refresh()
				)
				hb.add_child(解btn)

				vb.add_child(hb)

	_content.add_child(card)

func _populate_discipline() -> void:
	var card := _make_card("戒律裁决")
	var vb := card.find_child("VBox", true, false)

	var 待裁决 = _管理器.获取待裁决违规() if _管理器 != null else []
	if 待裁决.is_empty():
		var lbl := Label.new()
		lbl.text = "尚无待裁决的违规事件"
		UITheme.apply_aux_text(lbl)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lbl)
	else:
		for i in range(待裁决.size()):
			var 违规 = 待裁决[i]
			var d = _获取弟子(违规["弟子ID"])
			var 弟子名 = str(d.姓名) if d != null else "未知弟子"

			var 事件卡 := _make_card("违规事件 #" + str(i + 1))
			var 事件vb := 事件卡.find_child("VBox", true, false)

			_add_info_row(事件vb, "涉事弟子", 弟子名)
			_add_info_row(事件vb, "违规类型", 违规["违规类型"])
			_add_info_row(事件vb, "详情", 违规["详情"])

			var 违规数据 = SectManager.违规类型.get(违规["违规类型"], {})
			var 处罚选项 = 违规数据.get("处罚", ["警告训诫"])

			var 处罚hb := HBoxContainer.new()
			处罚hb.add_theme_constant_override("separation", UITheme.GRID / 2)
			for 处罚 in 处罚选项:
				var btn := Button.new()
				btn.text = 处罚
				btn.pressed.connect(func():
					if _管理器 != null:
						var 结果 = _管理器.裁决违规(i, 处罚)
						if 结果.get("成功", false):
							Game.记任务进度("handle_event")
							UIHint.show_hint(self, "裁决完成", "已对弟子处以：" + 处罚)
							refresh()
				)
				处罚hb.add_child(btn)
			事件vb.add_child(处罚hb)

			vb.add_child(事件卡)

	_content.add_child(card)

func _populate_requests() -> void:
	var card := _make_card("弟子请示")
	var vb := card.find_child("VBox", true, false)

	var 待回应 = _管理器.获取待回应请示() if _管理器 != null else []
	if 待回应.is_empty():
		var lbl := Label.new()
		lbl.text = "尚无待回应的弟子请示"
		UITheme.apply_aux_text(lbl)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lbl)
	else:
		for i in range(待回应.size()):
			var 请示 = 待回应[i]
			var d = _获取弟子(请示["弟子ID"])
			var 弟子名 = str(d.姓名) if d != null else "未知弟子"

			var 事件卡 := _make_card("请示 #" + str(i + 1))
			var 事件vb := 事件卡.find_child("VBox", true, false)

			_add_info_row(事件vb, "请示弟子", 弟子名)
			_add_info_row(事件vb, "请示类型", 请示["请示类型"])
			var 详情 = 请示.get("详情", {})
			if 详情.has("内容"):
				_add_info_row(事件vb, "详情", str(详情["内容"]))

			var 请示数据 = SectManager.请示类型.get(请示["请示类型"], {})
			var 选项 = 请示数据.get("选项", ["准许", "驳回"])

			var 选项hb := HBoxContainer.new()
			选项hb.add_theme_constant_override("separation", UITheme.GRID / 2)
			for 选项名 in 选项:
				var btn := Button.new()
				btn.text = 选项名
				btn.pressed.connect(func():
					if _管理器 != null:
						var 结果 = _管理器.回应请示(i, 选项名)
						if 结果.get("成功", false):
							Game.记任务进度("appoint_zhishi")
							UIHint.show_hint(self, "已回应", "决定：" + 选项名)
							refresh()
				)
				选项hb.add_child(btn)
			事件vb.add_child(选项hb)

			vb.add_child(事件卡)

	_content.add_child(card)

func _populate_reviews() -> void:
	var card := _make_card("宗主批阅")
	var vb := card.find_child("VBox", true, false)

	var 待批阅 = _管理器.获取待批阅事务() if _管理器 != null else []
	if 待批阅.is_empty():
		var lbl := Label.new()
		lbl.text = "尚无待批阅的宗门事务"
		UITheme.apply_aux_text(lbl)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lbl)
	else:
		for i in range(待批阅.size()):
			var 事务 = 待批阅[i]
			var 事件卡 := _make_card("事务 #" + str(i + 1) + "：" + 事务["标题"])
			var 事件vb := 事件卡.find_child("VBox", true, false)

			_add_info_row(事件vb, "事务ID", 事务["事务ID"])
			var 详情 = 事务.get("详情", {})
			if 详情.has("内容"):
				_add_info_row(事件vb, "详情", str(详情["内容"]))

			var 选项hb := HBoxContainer.new()
			选项hb.add_theme_constant_override("separation", UITheme.GRID / 2)
			for 选项名 in ["批准", "驳回", "待议"]:
				var btn := Button.new()
				btn.text = 选项名
				btn.pressed.connect(func():
					if _管理器 != null:
						var 结果 = _管理器.批阅事务(i, 选项名)
						if 结果.get("成功", false):
							Game.记任务进度("handle_event")
							UIHint.show_hint(self, "批阅完成", "决定：" + 选项名)
							refresh()
				)
				选项hb.add_child(btn)
			事件vb.add_child(选项hb)

			vb.add_child(事件卡)

	_content.add_child(card)

func _populate_core_disciples() -> void:
	var card := _make_card("核心弟子管理")
	var vb := card.find_child("VBox", true, false)

	var desc := Label.new()
	desc.text = "核心弟子获得资源倾斜（修炼速度+50%），但普通弟子可能心生不满。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	if Game != null:
		var 弟子列表 = Game.get("弟子列表")
		if 弟子列表 != null:
			for d in 弟子列表:
				if d == null:
					continue
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", UITheme.GRID)

				var 名 := Label.new()
				名.text = str(d.姓名)
				名.custom_minimum_size = Vector2(100, 0)
				UITheme.apply_body_text(名)
				hb.add_child(名)

				var lbl := Label.new()
				var 是否核心 = _管理器.是否核心弟子(int(d.弟子ID)) if _管理器 != null else false
				lbl.text = "状态：" + ("核心弟子" if 是否核心 else "普通弟子")
				UITheme.apply_aux_text(lbl)
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hb.add_child(lbl)

				var btn := Button.new()
				btn.text = "设为核心" if not 是否核心 else "取消核心"
				btn.custom_minimum_size = Vector2(100, 0)
				btn.pressed.connect(func():
					if _管理器 != null:
						if 是否核心:
							_管理器.取消核心弟子(int(d.弟子ID))
						else:
							_管理器.设为核心弟子(int(d.弟子ID))
						refresh()
				)
				hb.add_child(btn)

				vb.add_child(hb)

	_content.add_child(card)

func _populate_technology() -> void:
	var card := _make_card("宗门科技树")
	var vb := card.find_child("VBox", true, false)

	var desc := Label.new()
	desc.text = "研究宗门科技，提升全宗实力。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	var 已研究 = _管理器.获取已研究科技() if _管理器 != null else {}
	if 已研究.is_empty():
		var lbl := Label.new()
		lbl.text = "尚无已研究的科技"
		UITheme.apply_aux_text(lbl)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lbl)
	else:
		for 科技ID in 已研究.keys():
			_add_info_row(vb, 科技ID, "已研究")

	_content.add_child(card)

func _populate_diplomacy() -> void:
	var card := _make_card("对外关系管理")
	var vb := card.find_child("VBox", true, false)

	var desc := Label.new()
	desc.text = "管理与其他宗门的外交关系。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	var 关系 = _管理器.获取所有对外关系() if _管理器 != null else {}
	if 关系.is_empty():
		var lbl := Label.new()
		lbl.text = "尚无对外关系记录"
		UITheme.apply_aux_text(lbl)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lbl)
	else:
		for 宗门ID in 关系.keys():
			_add_info_row(vb, 宗门ID, 关系[宗门ID])

	_content.add_child(card)

func _populate_council() -> void:
	var card := _make_card("宗门议事会")
	var vb := card.find_child("VBox", true, false)

	var desc := Label.new()
	desc.text = "召开宗门议事会，与长老们商议宗门大事。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	var 记录 = _管理器.获取议事会记录() if _管理器 != null else []
	if 记录.is_empty():
		var lbl := Label.new()
		lbl.text = "尚无议事会记录"
		UITheme.apply_aux_text(lbl)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lbl)
	else:
		for i in range(记录.size()):
			var 议题 = 记录[i]
			_add_info_row(vb, "议题 #" + str(i + 1), 议题.get("议题", ""))

	_content.add_child(card)

## ========== 辅助函数 ==========
func _make_card(标题: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	var vb := VBoxContainer.new()
	vb.name = "VBox"
	vb.add_theme_constant_override("margin_left", UITheme.GRID)
	vb.add_theme_constant_override("margin_right", UITheme.GRID)
	vb.add_theme_constant_override("margin_top", UITheme.GRID)
	vb.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vb.add_theme_constant_override("separation", UITheme.GRID / 2)
	card.add_child(vb)

	var title := Label.new()
	title.text = 标题
	UITheme.apply_title_font(title)
	vb.add_child(title)

	var sep := HSeparator.new()
	vb.add_child(sep)

	card.modulate.a = 0.0
	var sectmgr_卡入场 := card.create_tween()
	sectmgr_卡入场.tween_property(card, "modulate:a", 1.0, 0.2)
	return card

func _add_info_row(parent: VBoxContainer, 标签: String, 值: String) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)

	var lbl := Label.new()
	lbl.text = 标签 + "："
	UITheme.apply_aux_text(lbl)
	lbl.custom_minimum_size = Vector2(100, 0)
	hb.add_child(lbl)

	var val := Label.new()
	val.text = 值
	UITheme.apply_body_text(val)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(val)

	parent.add_child(hb)

func _获取弟子(弟子ID: int):
	if Game == null:
		return null
	var 弟子列表 = Game.get("弟子列表")
	if 弟子列表 == null:
		return null
	for d in 弟子列表:
		if d != null and int(d.弟子ID) == 弟子ID:
			return d
	return null

func _弹出任命弟子(殿阁: String) -> void:
	# 简化：直接任命第一个弟子
	if Game == null or _管理器 == null:
		return
	var 弟子列表 = Game.get("弟子列表")
	if 弟子列表 == null or 弟子列表.is_empty():
		return
	var d = 弟子列表[0]
	_管理器.任命殿阁负责人(殿阁, int(d.弟子ID))
	UIHint.show_hint(self, "任命完成", 殿阁 + "负责人已任命为：" + str(d.姓名))
	refresh()

func _弹出分配任职(弟子ID: int) -> void:
	# 简化：直接分配到第一个殿阁
	if _管理器 == null:
		return
	_管理器.分配弟子任职(弟子ID, "丹堂", "弟子")
	UIHint.show_hint(self, "任职完成", "已分配到丹堂任弟子")
	refresh()

func _update_tab_styles() -> void:
	for t in _tab_btns.keys():
		var b: Button = _tab_btns[t]
		if t == _current_tab:
			UITheme.apply_button_label(b, true)
		else:
			UITheme.apply_button_label(b, false)

func _on_tab_pressed(t: String) -> void:
	_current_tab = t
	_update_tab_styles()
	_populate()

# ===== 商队管理 =====
func _populate_caravan() -> void:
	var card := _make_card("商队管理")
	var vb := card.find_child("VBox", true, false)

	# §11.15 优化：打开面板即结算到期商队（现实时间模型，离线/未推演也能正确返还）+ 刷新每日配额
	if is_instance_valid(Game):
		Game.刷新商队配额()
		Game.结算到期商队()

	var desc := Label.new()
	desc.text = "派遣商队前往各地贸易，低买高卖赚取灵石。商队途中可能遭遇风险或偶遇高人。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	# §11.15 优化：商队槽位 / 每日配额概览
	if is_instance_valid(Game):
		var 配额信息 := Label.new()
		var 卡增益 = "（含月卡+1）" if (Game.月卡有效() or Game.季卡有效() or Game.永久卡激活) else ""
		var 总声望 = 0
		for v in Game.商队系统.商路声望.values():
			总声望 += int(v)
		配额信息.text = "◆ 商队槽位 %d/6（总声望%d）｜今日派遣 %d/%d%s" % [
			Game.商队槽位数(), 总声望, Game.商队系统.商队每日已派, Game.商队每日配额(), 卡增益
		]
		UITheme.apply_aux_text(配额信息)
		vb.add_child(配额信息)

	# 正在派遣的商队
	var 进行中头 := Label.new()
	进行中头.text = "◆ 进行中的商队"
	UITheme.apply_section_title(进行中头)
	vb.add_child(进行中头)

	if is_instance_valid(Game) and Game.商队系统.商队列表.size() > 0:
		for 商队 in Game.商队系统.商队列表:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", UITheme.GRID)
			var 名 := Label.new()
			名.text = "商队#%d" % int(商队["id"])
			名.custom_minimum_size = Vector2(80, 0)
			UITheme.apply_body_text(名)
			hb.add_child(名)
			var 信息 := Label.new()
			var 灵舟后缀 = ""
			var li = int(商队.get("灵舟索引", -1))
			if li >= 0 and li < Game.商队系统.灵舟库存.size():
				var 舟 = Game.商队系统.灵舟库存[li]
				灵舟后缀 = " | 灵舟:%s%s" % [str(舟.get("名称", "")), "【虚空瞬移】" if 商队.get("虚空瞬移", false) else ""]
			var 倒计时秒 = int(商队.get("预计完成真实秒", 0)) - int(Time.get_unix_time_from_system())
			var 倒计时txt = "即时"
			if 倒计时秒 > 0:
				倒计时txt = "约%d时%d分后返回" % [倒计时秒 / 3600, (倒计时秒 % 3600) / 60]
			信息.text = "%s | 货物价值:%d | %s%s" % [商队["地区名"], int(商队["货物价值"]), 倒计时txt, 灵舟后缀]
			UITheme.apply_aux_text(信息)
			信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(信息)
			var 仙玉btn: Button = Button.new()
			仙玉btn.text = "仙玉即时(%d)" % Game.商队系统.仙玉即时完成费
			UITheme.apply_button_label(仙玉btn, false)
			仙玉btn.custom_minimum_size = Vector2(115, 0)
			仙玉btn.tooltip_text = "消耗%d仙玉立即结算本次贸易" % Game.商队系统.仙玉即时完成费
			仙玉btn.pressed.connect(_on_仙玉即时完成.bind(int(商队["id"])))
			hb.add_child(仙玉btn)
			vb.add_child(hb)
	else:
		var 空 := Label.new()
		空.text = "尚无进行中的商队"
		UITheme.apply_aux_text(空)
		vb.add_child(空)

	_build_行情一览(vb)
	# 可派遣地区
	var 地区头 := Label.new()
	地区头.text = "◆ 可派遣地区"
	UITheme.apply_section_title(地区头)
	vb.add_child(地区头)

	if is_instance_valid(Game):
		for 地区 in Game.商队系统.商队地区:
			var rid = str(地区.get("id", ""))
			var 解锁 = Game.检查商路城市解锁(str(地区.get("unlock_condition", "")), rid)
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", UITheme.GRID)
			var 名 := Label.new()
			名.text = 地区["名称"]
			名.custom_minimum_size = Vector2(100, 0)
			UITheme.apply_body_text(名)
			hb.add_child(名)
			var 信息 := Label.new()
			信息.text = "距离:%d日 | 当前收购价:%.1fx | 风险:%.0f%% | 偏好:%s" % [
				int(地区["距离"]), float(地区.get("当前收购价", 地区["收购价"])), float(地区["风险"]) * 100, "、".join(地区.get("偏好类别", []))
			]
			UITheme.apply_aux_text(信息)
			信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(信息)
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(80, 0)
			if 解锁:
				btn.text = "派遣"
				btn.pressed.connect(_on_派遣商队.bind(地区["id"]))
			else:
				btn.text = "未解锁"
				btn.disabled = true
				# 信息栏追加解锁条件
				var 条件文本 = " | 解锁:%s" % str(地区.get("unlock_condition", ""))
				信息.text += 条件文本
			hb.add_child(btn)
			vb.add_child(hb)

	# 商路声望（§11.15 策略深度）
		var 声望头 := Label.new()
		声望头.text = "◆ 商路声望"
		UITheme.apply_section_title(声望头)
		vb.add_child(声望头)
		if is_instance_valid(Game) and Game.商队系统.商路声望.size() > 0:
			for 地区 in Game.商队系统.商队地区:
				var rid = str(地区.get("id", ""))
				var rep = int(Game.商队系统.商路声望.get(rid, 0))
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", UITheme.GRID)
				var 名 := Label.new()
				名.text = 地区["名称"]
				名.custom_minimum_size = Vector2(100, 0)
				UITheme.apply_body_text(名)
				hb.add_child(名)
				var 信息 := Label.new()
				信息.text = "%d 声望" % rep
				UITheme.apply_aux_text(信息)
				信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hb.add_child(信息)
				vb.add_child(hb)
		else:
			var 空 := Label.new()
			空.text = "尚无商路声望积累"
			UITheme.apply_aux_text(空)
			vb.add_child(空)

	# 商队历史
	var 历史头 := Label.new()
	历史头.text = "◆ 最近商队记录"
	UITheme.apply_section_title(历史头)
	vb.add_child(历史头)

	if is_instance_valid(Game) and Game.商队系统.商队历史.size() > 0:
		for i in range(min(5, Game.商队系统.商队历史.size())):
			var 记录 = Game.商队系统.商队历史[i]
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", UITheme.GRID)
			var 名 := Label.new()
			名.text = "商队#%d" % int(记录["id"])
			名.custom_minimum_size = Vector2(80, 0)
			UITheme.apply_body_text(名)
			hb.add_child(名)
			var 信息 := Label.new()
			# §11.20：货物已出库，成本 = 货值 + 启动资金；历史同时给出货款与净利，避免账目失真
			var 净利: int = int(记录.get("净利", int(记录["实际收益"]) - int(记录.get("货物价值", 0)) - int(记录.get("启动资金", 0))))
			# §11.21 BUG-A：事件字段尾「·优策/失策」揭示选项命中（crew 总分 ≥ 120 走 option1，< 120 走 option2）
			var 决策标签: String = ""
			var 事件名: String = str(记录.get("事件", ""))
			if 事件名.ends_with("·优策"):
				决策标签 = "｜策优（≥120分）"
			elif 事件名.ends_with("·失策"):
				决策标签 = "｜策失（<120分）"
			信息.text = "%s | %s%s | 货款:%d 净利:%+d灵石" % [
				记录["地区名"], 事件名, 决策标签, int(记录["实际收益"]), 净利
			]
			UITheme.apply_aux_text(信息)
			信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(信息)
			vb.add_child(hb)
	else:
		var 空 := Label.new()
		空.text = "尚无商队记录"
		UITheme.apply_aux_text(空)
		vb.add_child(空)

	# 行情动态（§11.15 策略深度：全局行情事件）
	var 行情头 := Label.new()
	行情头.text = "◆ 行情动态"
	UITheme.apply_section_title(行情头)
	vb.add_child(行情头)
	if is_instance_valid(Game) and Game.商队系统.行情事件列表.size() > 0:
		for ev in Game.商队系统.行情事件列表:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", UITheme.GRID)
			var 名 := Label.new()
			名.text = str(ev.get("名", "行情事件"))
			名.custom_minimum_size = Vector2(160, 0)
			UITheme.apply_body_text(名)
			hb.add_child(名)
			var 信息 := Label.new()
			信息.text = "%s ×%s · 剩%d日" % [str(ev.get("地区", "")), str(ev.get("倍率", "1.0")), int(ev.get("剩余天数", 0))]
			UITheme.apply_aux_text(信息)
			信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(信息)
			vb.add_child(hb)
	else:
		var 空 := Label.new()
		空.text = "暂无行情波动"
		UITheme.apply_aux_text(空)
		vb.add_child(空)

	# ===== §11.15 阶段三：灵舟（坞/炼制/拍卖会/库存） + 黑市 + NPC 商队竞争 =====
	if is_instance_valid(Game):
		# ---- 飞舟坞 ----
		var 坞头 := Label.new()
		坞头.text = "◆ 飞舟坞（跨域贸易）"
		UITheme.apply_section_title(坞头)
		vb.add_child(坞头)
		var 坞信息 := Label.new()
		if not Game.商队系统.灵舟坞建造中.is_empty():
			var 建中 = Game.灵舟坞建造信息()
			var 剩余 = int(建中.get("完成日", 0)) - Game.累计游戏日
			坞信息.text = "建造中：%s（目标%d品），预计剩余 %d 日" % [
				Game.商队系统.灵舟坞表.get("sd%02d" % int(建中.get("目标档", 0)), {}).get("dock_name", ""),
				int(建中.get("目标档", 0)), max(0, 剩余)]
		elif Game.已建灵舟坞():
			坞信息.text = "已建成飞舟坞（%d品），可跨域通商至紫府仙都/北海商港" % Game.商队系统.灵舟坞等级
		else:
			var 建 = Game.灵舟坞建造信息()
			if 建.get("可建", false):
				var 材料txt = ""
				for m in 建.get("材料", []):
					材料txt += "%s ×%d（有%d）  " % [str(m.get("名", "")), int(m.get("需", 0)), int(m.get("有", 0))]
				坞信息.text = "可建：%s（第%d品）｜需门派%d品｜工费灵石%d｜历时%d日\n灵材：%s" % [
					str(建.get("名称", "")), int(建.get("等级", 1)), int(建.get("需门派等级", 99)),
					int(建.get("工费", 0)), int(建.get("时日", 0)), 材料txt.strip_edges()]
			else:
				坞信息.text = "暂无可建飞舟坞"
		UITheme.apply_aux_text(坞信息)
		坞信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(坞信息)
		if Game.商队系统.灵舟坞建造中.is_empty() and not Game.已建灵舟坞():
			var 建btn := Button.new()
			建btn.text = "建造/升级飞舟坞"
			建btn.custom_minimum_size = Vector2(180, 0)
			建btn.pressed.connect(_on_建造灵舟坞)
			vb.add_child(建btn)

		# ---- 灵舟炼制 ----
		if Game.已建灵舟坞():
			var 炼头 := Label.new()
			炼头.text = "◆ 灵舟炼制（各阶灵材 + 时日）"
			UITheme.apply_section_title(炼头)
			vb.add_child(炼头)
			var 坞 = Game.商队系统.灵舟坞表.get("sd%02d" % Game.商队系统.灵舟坞等级, {})
			var 容量 = int(坞.get("max_ship_count", 1))
			var 余量 = 容量 - Game.商队系统.灵舟库存.size() - Game.商队系统.灵舟建造队列.size()
			var 容info := Label.new()
			容info.text = "飞舟坞容量 %d／已持%d＋炼制中%d（余%d）" % [容量, Game.商队系统.灵舟库存.size(), Game.商队系统.灵舟建造队列.size(), max(0, 余量)]
			UITheme.apply_aux_text(容info)
			vb.add_child(容info)
			for sid in Game.商队系统.宗门灵舟表.keys():
				var 舟 = Game.商队系统.宗门灵舟表[sid]
				var tier = int(舟.get("tier", 0))
				if int(坞.get("unlock_ship_tier", 0)) < tier:
					continue
				var 需等级 = int(str(舟.get("unlock_condition", "sect_level=1")).replace("sect_level=", ""))
				if Game.门派等级 < 需等级:
					continue
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", UITheme.GRID)
				var 名 := Label.new()
				名.text = str(舟.get("ship_name", ""))
				名.custom_minimum_size = Vector2(120, 0)
				UITheme.apply_body_text(名)
				hb.add_child(名)
				var 材料txt = ""
				for 段 in str(舟.get("build_material", "")).split("|"):
					if 段.strip_edges().is_empty():
						continue
					var p2 = 段.split(":")
					if p2.size() < 2:
						continue
					var gid = p2[0].strip_edges()
					var n = int(p2[1].strip_edges())
					var 中文 = Game.商队系统.灵材名称表.get(gid, gid)
					var 有 = 0
					for it in Game.宗门库房:
						# ★ 2026-09-16 修（真 bug · 红线⑤同族）：宗门库房元素是 Item（RefCounted），
						#   双参 .get() 抛错并中断 ⇒ 商队「灵材备货」统计恒为 0。
						var v名: Variant = it.get("名称") if it != null else null
						if v名 != null and String(v名) == 中文:
							有 += 1
					材料txt += "%s×%d(有%d) " % [中文, n, 有]
				var 信息 := Label.new()
				信息.text = "T%d｜需%d品炼器师｜核心%d阶｜槽%d｜%s｜工费%d｜%d日｜%s" % [
					tier, int(舟.get("required_forge_tier", 1)), int(舟.get("required_core_tier", 1)),
					int(舟.get("formation_slots", 0)), str(舟.get("features", "")),
					int(舟.get("build_cost", 0)), int(舟.get("build_days", 0)), 材料txt.strip_edges()]
				UITheme.apply_aux_text(信息)
				信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				hb.add_child(信息)
				var 炼 := Button.new()
				炼.text = "炼制"
				炼.custom_minimum_size = Vector2(70, 0)
				炼.pressed.connect(_on_炼制灵舟.bind(sid))
				hb.add_child(炼)
				vb.add_child(hb)

		# ---- 拍卖会（双向市场）----
		var 拍头 := Label.new()
		拍头.text = "◆ 拍卖会（纯灵石购成品 / 售本宗灵舟）"
		UITheme.apply_section_title(拍头)
		vb.add_child(拍头)
		var 在售 = Game.获取拍卖会灵舟()
		for s in 在售:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", UITheme.GRID)
			var 名 := Label.new()
			名.text = "%s（%s）" % [str(s.get("名称", "")), str(s.get("卖家", ""))]
			名.custom_minimum_size = Vector2(180, 0)
			UITheme.apply_body_text(名)
			hb.add_child(名)
			var 价 := Label.new()
			价.text = "%d 灵石" % int(s.get("价", 0))
			UITheme.apply_aux_text(价)
			价.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(价)
			var 买 := Button.new()
			买.text = "购买"
			买.custom_minimum_size = Vector2(70, 0)
			买.pressed.connect(_on_拍卖购买灵舟.bind(str(s.get("ship_id", ""))))
			hb.add_child(买)
			vb.add_child(hb)
		if 在售.is_empty():
			var 空a := Label.new()
			空a.text = "拍卖会暂无灵舟挂单"
			UITheme.apply_aux_text(空a)
			vb.add_child(空a)

		# ---- 灵舟库存 ----
		if Game.商队系统.灵舟库存.size() > 0:
			var 库头 := Label.new()
			库头.text = "◆ 灵舟存量"
			UITheme.apply_section_title(库头)
			vb.add_child(库头)
			if Game.商队系统.虚空大阵冷却日 > Game.累计游戏日:
				var 虚注 := Label.new()
				虚注.text = "（破虚神舰·虚空大阵冷却中，剩余 %d 日）" % (Game.商队系统.虚空大阵冷却日 - Game.累计游戏日)
				UITheme.apply_aux_text(虚注)
				vb.add_child(虚注)
			for i in range(Game.商队系统.灵舟库存.size()):
				var 舟 = Game.商队系统.灵舟库存[i]
				var eff = Game.灵舟有效属性(舟)
				var 阵法名: Array = []
				for fid in 舟.get("阵法", []):
					var fm = Game.商队系统.灵舟阵法表.get(str(fid), null)
					if fm != null:
						阵法名.append(str(fm.get("name", fid)))
				var 核心状态 = str(舟.get("核心状态", "正常"))
				# 有效属性行
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", UITheme.GRID)
				var 名 := Label.new()
				名.text = str(舟.get("名称", ""))
				名.custom_minimum_size = Vector2(110, 0)
				UITheme.apply_body_text(名)
				hb.add_child(名)
				var 信息 := Label.new()
				信息.text = "T%d｜耐久%d/%d｜降险%.0f%%｜提速%.0f%%｜核心:%s(%d阶)｜阵法:%s" % [
					int(舟.get("tier", 0)), int(舟.get("durability", 0)), int(eff["max_durability"]),
					eff["risk_reduce"] * 100, eff["speed_bonus"] * 100,
					核心状态, int(舟.get("核心品阶", 1)),
					"、".join(阵法名) if 阵法名.size() > 0 else "无"]
				UITheme.apply_aux_text(信息)
				信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				hb.add_child(信息)
				vb.add_child(hb)
				# 操作行：刻录阵法 / 补充核心 / 拍卖
				var bh := HBoxContainer.new()
				bh.add_theme_constant_override("separation", UITheme.GRID)
				var 刻 := Button.new()
				刻.text = "刻录阵法"
				刻.custom_minimum_size = Vector2(90, 0)
				刻.pressed.connect(_on_刻录灵舟阵法.bind(i))
				bh.add_child(刻)
				var 补 := Button.new()
				补.text = "补充核心"
				补.custom_minimum_size = Vector2(90, 0)
				补.disabled = (核心状态 == "正常")
				补.pressed.connect(_on_补充灵舟核心.bind(i))
				bh.add_child(补)
				var 余命名 = int(舟.get("可命名次数", 1))
				var 命名 := Button.new()
				命名.text = "命名" if 余命名 > 0 else "已命名"
				命名.custom_minimum_size = Vector2(70, 0)
				命名.disabled = (余命名 <= 0)
				命名.pressed.connect(_on_命名灵舟.bind(i))
				bh.add_child(命名)
				var 售 := Button.new()
				售.text = "拍卖"
				售.custom_minimum_size = Vector2(70, 0)
				售.pressed.connect(_on_拍卖出售灵舟.bind(i))
				bh.add_child(售)
				vb.add_child(bh)

		# 黑市（魔道专属）
		var 黑头 := Label.new()
		黑头.text = "◆ 黑市（魔道专属）"
		UITheme.apply_section_title(黑头)
		vb.add_child(黑头)
		if Game.正邪路线 != "九幽邪道":
			var 提示 := Label.new()
			提示.text = "黑市仅向魔道势力开放（需择「九幽邪道」路线）"
			UITheme.apply_aux_text(提示)
			vb.add_child(提示)
		elif Game.商队系统.黑市禁闭日 > 0:
			var 禁 := Label.new()
			禁.text = "正道执法封禁中，剩余 %d 天" % Game.商队系统.黑市禁闭日
			UITheme.apply_aux_text(禁)
			vb.add_child(禁)
		else:
			var 违禁 = Game.黑市违禁品列表()
			if 违禁.is_empty():
				var 空3 := Label.new()
				空3.text = "暂无可交易违禁品"
				UITheme.apply_aux_text(空3)
				vb.add_child(空3)
			else:
				for 物 in 违禁:
					var hb := HBoxContainer.new()
					hb.add_theme_constant_override("separation", UITheme.GRID)
					var 名 := Label.new()
					名.text = str(物.get("名", ""))
					名.custom_minimum_size = Vector2(140, 0)
					UITheme.apply_body_text(名)
					hb.add_child(名)
					var 价 := Label.new()
					价.text = "单价 %d 灵石（×2 价差）" % int(物.get("单价", 0))
					UITheme.apply_aux_text(价)
					价.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					hb.add_child(价)
					var 售 := Button.new()
					售.text = "出售"
					售.custom_minimum_size = Vector2(70, 0)
					售.pressed.connect(_on_黑市出售.bind(str(物.get("名", ""))))
					hb.add_child(售)
					vb.add_child(hb)

		# §11.15 优化#73：黑市双线——正道特许（非魔道可交易，与魔道黑市并列）
		var 正头 := Label.new()
		正头.text = "◆ 正道特许（非魔道可交易）"
		UITheme.apply_section_title(正头)
		vb.add_child(正头)
		if not Game.正道特许可交易():
			var 正提示 := Label.new()
			if Game.正邪路线 == "九幽邪道":
				正提示.text = "正道特许不向魔道势力开放"
			else:
				正提示.text = "正道特许暂无开放条件"
			UITheme.apply_aux_text(正提示)
			vb.add_child(正提示)
		else:
			var 正货 = Game.正道特许商品列表()
			if 正货.is_empty():
				var 空正 := Label.new()
				空正.text = "暂无正道特许商品"
				UITheme.apply_aux_text(空正)
				vb.add_child(空正)
			else:
				for 物 in 正货:
					var hb := HBoxContainer.new()
					hb.add_theme_constant_override("separation", UITheme.GRID)
					var 名 := Label.new()
					名.text = str(物.get("名", ""))
					名.custom_minimum_size = Vector2(140, 0)
					UITheme.apply_body_text(名)
					hb.add_child(名)
					var 价 := Label.new()
					价.text = "单价 %d 灵石（正道特许）" % int(物.get("单价", 0))
					UITheme.apply_aux_text(价)
					价.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					hb.add_child(价)
					var 售 := Button.new()
					售.text = "出售"
					售.custom_minimum_size = Vector2(70, 0)
					售.pressed.connect(_on_正道特许出售.bind(str(物.get("名", ""))))
					hb.add_child(售)
					vb.add_child(hb)

		# NPC 商队竞争（黄金商路）
		var 竞头 := Label.new()
		竞头.text = "◆ 商路竞争（黄金商路）"
		UITheme.apply_section_title(竞头)
		vb.add_child(竞头)
		var 黄金 = Game.黄金商路列表()
		if 黄金.is_empty():
			var 空4 := Label.new()
			空4.text = "暂无黄金商路竞争者"
			UITheme.apply_aux_text(空4)
			vb.add_child(空4)
		else:
			for 地区 in 黄金:
				var cid = str(地区.get("id", ""))
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", UITheme.GRID)
				var 名 := Label.new()
				名.text = 地区["名称"]
				名.custom_minimum_size = Vector2(100, 0)
				UITheme.apply_body_text(名)
				hb.add_child(名)
				var 状态 := Label.new()
				if Game.商队系统.商路竞争状态.has(cid):
					var s = Game.商队系统.商路竞争状态[cid]
					状态.text = "对手强度%d｜压价%.0f%%｜%s" % [int(s.get("强度", 0)), float(s.get("压价率", 0)) * 100, str(s.get("策略", ""))]
				else:
					状态.text = "暂无竞争者"
				UITheme.apply_aux_text(状态)
				状态.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hb.add_child(状态)
				vb.add_child(hb)
				if Game.商队系统.商路竞争状态.has(cid):
					var ahb := HBoxContainer.new()
					ahb.add_theme_constant_override("separation", UITheme.GRID)
					var b1 := Button.new(); b1.text = "价格战(2000)"; b1.custom_minimum_size = Vector2(110, 0); b1.pressed.connect(_on_商路价格战.bind(cid)); ahb.add_child(b1)
					var b2 := Button.new(); b2.text = "打压(5000)"; b2.custom_minimum_size = Vector2(100, 0); b2.pressed.connect(_on_商路打压.bind(cid)); ahb.add_child(b2)
					var b3 := Button.new(); b3.text = "协商(3000)"; b3.custom_minimum_size = Vector2(100, 0); b3.pressed.connect(_on_商路协商.bind(cid)); ahb.add_child(b3)
					vb.add_child(ahb)

	_content.add_child(card)

# §商道P1 行情一览（纯读取 Game.获取城市行情，不改结算）
func _build_行情一览(parent: Control) -> void:
	if not is_instance_valid(Game):
		return
	var 头 := Label.new()
	头.text = "◆ 行情一览"
	UITheme.apply_section_title(头)
	parent.add_child(头)
	var 提示 := Label.new()
	提示.text = "绿字低价可囤货，红字高价可抛售；行情随商路事件浮动"
	UITheme.apply_aux_text(提示)
	parent.add_child(提示)
	for 地区 in Game.商队系统.商队地区:
		var rid = str(地区.get("id", ""))
		if not Game.检查商路城市解锁(str(地区.get("unlock_condition", "")), rid):
			continue
		var 行情 = Game.获取城市行情(rid)
		if 行情.is_empty():
			continue
		var 行 := HBoxContainer.new()
		行.add_theme_constant_override("separation", 4)
		var 名 := Label.new()
		名.text = str(地区.get("名称", ""))
		名.custom_minimum_size = Vector2(84, 0)
		UITheme.apply_body_text(名)
		行.add_child(名)
		for q in 行情:
			var 标 := Label.new()
			var 状态 = str(q.get("状态", "平稳"))
			var 后缀 = "囤" if (状态 == "低迷" or 状态 == "偏低") else ("抛" if (状态 == "偏高" or 状态 == "暴涨") else "")
			标.text = "%s%s%s" % [str(q.get("类别", "")), _行情箭头(状态), 后缀]
			标.add_theme_color_override("font_color", _行情状态色(状态))
			UITheme.apply_aux_text(标)
			行.add_child(标)
		parent.add_child(行)

func _行情状态色(状态: String) -> Color:
	if 状态 == "低迷" or 状态 == "偏低":
		return UITheme.color_status_success()
	if 状态 == "偏高" or 状态 == "暴涨":
		return UITheme.color_status_danger()
	return UITheme.color_text_body_dim()

func _行情箭头(状态: String) -> String:
	match 状态:
		"低迷", "偏低":
			return "↓"
		"偏高", "暴涨":
			return "↑"
		_:
			return "→"

func _on_派遣商队(地区ID: String) -> void:
	if not is_instance_valid(Game):
		return
	_show_dispatch_panel(地区ID)

# ===== §11.15 阶段三：商队管理 tab 动作处理器 =====
func _on_建造灵舟坞() -> void:
	if not is_instance_valid(Game):
		return
	Game.建造灵舟坞()
	_populate()

func _on_炼制灵舟(ship_id: String) -> void:
	if not is_instance_valid(Game):
		return
	Game.炼制灵舟(ship_id)
	_populate()

func _on_拍卖购买灵舟(ship_id: String) -> void:
	if not is_instance_valid(Game):
		return
	Game.拍卖购买灵舟(ship_id)
	_populate()

func _on_拍卖出售灵舟(索引: int) -> void:
	if not is_instance_valid(Game):
		return
	if 索引 < 0 or 索引 >= Game.商队系统.灵舟库存.size():
		return
	var 舟 = Game.商队系统.灵舟库存[索引]
	var 基准 = int(Game.商队系统.宗门灵舟表.get(str(舟.get("ship_id", "")), {}).get("build_cost", 0))
	Game.拍卖出售灵舟(索引, int(基准 * 0.6))
	_populate()

func _on_刻录灵舟阵法(索引: int) -> void:
	if not is_instance_valid(Game):
		return
	if 索引 < 0 or 索引 >= Game.商队系统.灵舟库存.size():
		return
	_show_ship_formation_panel(索引)

func _on_补充灵舟核心(索引: int) -> void:
	if not is_instance_valid(Game):
		return
	var 结果 = Game.补充灵舟核心(索引)
	UIHint.show_hint(self, "灵舟核心", str(结果.get("消息", "")))
	_populate()

# §11.15 阶段三·灵舟：阵法效果文案
func _ship_formation_effect_text(fm: Dictionary) -> String:
	var dim = str(fm.get("effect_dim", ""))
	var val = float(fm.get("effect_val", 0.0))
	match dim:
		"speed":
			return "提速 +%.0f%%" % (val * 100)
		"risk":
			return "降险 +%.0f%%" % (val * 100)
		"durability":
			return "增耐久 +%d" % int(val)
		"war":
			return "增道行 +%d" % int(val)
		"regen":
			return "回灵聚气·核心自续"
		"void":
			return "虚空大阵·可破碎虚空瞬移（跨域即时·风险归零）"
		_:
			return str(fm.get("category", ""))

# §11.15 阶段三·灵舟：刻录阵法面板（展示可刻阵法 + 消耗 + 门槛）
func _show_ship_formation_panel(索引: int) -> void:
	if not is_instance_valid(Game):
		return
	if 索引 < 0 or 索引 >= Game.商队系统.灵舟库存.size():
		return
	for child in _content.get_children():
		child.queue_free()
	var 舟 = Game.商队系统.灵舟库存[索引]
	var 舟定义 = Game.商队系统.宗门灵舟表.get(str(舟.get("ship_id", "")), {})
	var 已刻 = 舟.get("阵法", [])
	var card: PanelContainer = _make_card("刻录阵法 · %s" % str(舟.get("名称", "")))
	var vb: VBoxContainer = card.find_child("VBox", true, false)

	var 概: Label = Label.new()
	概.text = "品阶 T%d｜阵法槽 %d/%d｜特性：%s" % [
		int(舟.get("tier", 0)), 已刻.size(), int(舟定义.get("formation_slots", 0)), str(舟定义.get("features", ""))
	]
	UITheme.apply_value_text(概)
	vb.add_child(概)

	var 阵法堂等级: int = 1
	if Game.司职列表.has("zhenfa"):
		var v = Game.司职列表["zhenfa"].get("等级", 1)
		阵法堂等级 = int(v) if v != null else 1
	var 堂注: Label = Label.new()
	堂注.text = "当前阵法堂司职品级：%d" % 阵法堂等级
	UITheme.apply_aux_text(堂注)
	vb.add_child(堂注)

	var 可刻列表: Array = []
	for fid in Game.商队系统.灵舟阵法表.keys():
		var fm = Game.商队系统.灵舟阵法表[fid]
		if 已刻.has(fid):
			continue
		if 已刻.size() >= int(舟定义.get("formation_slots", 0)):
			break
		if str(fm.get("category", "")) == "虚空" and not ("虚空" in str(舟定义.get("features", "")).split("|")):
			continue
		if 阵法堂等级 < int(fm.get("required_array_tier", 1)):
			continue
		可刻列表.append(fid)

	if 可刻列表.is_empty():
		var 空: Label = Label.new()
		if 已刻.size() >= int(舟定义.get("formation_slots", 0)):
			空.text = "阵法槽已满，无法继续刻录"
		else:
			空.text = "暂无可刻阵法（受阵法堂品级或灵舟特性限制）"
		UITheme.apply_aux_text(空)
		vb.add_child(空)
	else:
		for fid in 可刻列表:
			var fm = Game.商队系统.灵舟阵法表[fid]
			var 行: HBoxContainer = HBoxContainer.new()
			行.add_theme_constant_override("separation", UITheme.GRID)
			var 专属标: String = "·灵舟专属" if bool(fm.get("ship_only", false)) else ""
			var 信息: Label = Label.new()
			信息.text = "%s%s（%s·T%d）%s｜耗灵石%d＋灵材:%s｜需阵法堂%d级" % [
				str(fm.get("name", fid)), 专属标, str(fm.get("category", "")), int(fm.get("tier", 1)),
				_ship_formation_effect_text(fm), int(fm.get("cost_lingstone", 0)),
				str(fm.get("cost_material", "")), int(fm.get("required_array_tier", 1))
			]
			UITheme.apply_body_text(信息)
			信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			行.add_child(信息)
			var 刻: Button = Button.new()
			刻.text = "刻录"
			刻.custom_minimum_size = Vector2(70, 0)
			刻.pressed.connect(_on_确认刻录灵舟阵法.bind(索引, fid))
			行.add_child(刻)
			vb.add_child(行)

	var 返回: Button = Button.new()
	返回.text = "返回"
	UITheme.apply_button_label(返回, false)
	返回.pressed.connect(_on_刻录返回)
	vb.add_child(返回)
	_content.add_child(card)

func _on_确认刻录灵舟阵法(索引: int, formation_id: String) -> void:
	if not is_instance_valid(Game):
		return
	var 结果 = Game.刻录灵舟阵法(索引, formation_id)
	UIHint.show_hint(self, "灵舟刻阵", str(结果.get("消息", "")))
	if 结果.get("成功", false):
		_show_ship_formation_panel(索引)  # 刷新槽位/已刻
	else:
		_populate()

func _on_刻录返回() -> void:
	_populate()

# §11.15 阶段三·灵舟：命名入口（每名仅一次机会，随时可触发）
func _on_命名灵舟(索引: int) -> void:
	if not is_instance_valid(Game):
		return
	if 索引 < 0 or 索引 >= Game.商队系统.灵舟库存.size():
		return
	_show_ship_rename_panel(索引)

# §11.15 阶段三·灵舟：重命名面板（展示机会余量 + 输入新名）
func _show_ship_rename_panel(索引: int) -> void:
	if not is_instance_valid(Game):
		return
	if 索引 < 0 or 索引 >= Game.商队系统.灵舟库存.size():
		return
	for child in _content.get_children():
		child.queue_free()
	var 舟 = Game.商队系统.灵舟库存[索引]
	var 余 = int(舟.get("可命名次数", 1))
	var card: PanelContainer = _make_card("灵舟命名 · %s" % str(舟.get("名称", "")))
	var vb: VBoxContainer = card.find_child("VBox", true, false)
	var 注: Label = Label.new()
	if 余 > 0:
		注.text = "当前名：【%s】｜重命名机会剩余 %d 次（每舟仅可命名一次）" % [str(舟.get("名称", "")), 余]
	else:
		注.text = "【%s】已无重命名机会（每舟仅可命名一次）" % str(舟.get("名称", ""))
	UITheme.apply_value_text(注)
	vb.add_child(注)
	if 余 <= 0:
		var 返回: Button = Button.new()
		返回.text = "返回"
		UITheme.apply_button_label(返回, false)
		返回.pressed.connect(_on_刻录返回)
		vb.add_child(返回)
		_content.add_child(card)
		return
	var 输入: LineEdit = LineEdit.new()
	输入.placeholder_text = "请输入新灵舟名（限12字）"
	输入.max_length = 12
	输入.text = str(舟.get("名称", ""))
	vb.add_child(输入)
	var 确认: Button = Button.new()
	确认.text = "确认命名"
	UITheme.apply_button_label(确认, true)
	确认.pressed.connect(_on_确认命名灵舟.bind(索引, 输入))
	vb.add_child(确认)
	var 返回2: Button = Button.new()
	返回2.text = "返回"
	UITheme.apply_button_label(返回2, false)
	返回2.pressed.connect(_on_刻录返回)
	vb.add_child(返回2)
	_content.add_child(card)

func _on_确认命名灵舟(索引: int, 输入: LineEdit) -> void:
	if not is_instance_valid(Game) or not is_instance_valid(输入):
		return
	var 结果 = Game.重命名灵舟(索引, 输入.text)
	UIHint.show_hint(self, "灵舟命名", str(结果.get("消息", "")))
	_populate()

func _on_黑市出售(名: String) -> void:
	if not is_instance_valid(Game):
		return
	Game.黑市出售(名, 1)
	_populate()

# §11.15 优化#73：正道特许出售（黑市双线）
func _on_正道特许出售(名: String) -> void:
	if not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.正道特许出售(名, 1)
	UIHint.show_hint(self, "正道特许", str(结果.get("消息", "")))
	if 结果.get("成功", false):
		_populate()

func _on_商路价格战(城市id: String) -> void:
	if not is_instance_valid(Game):
		return
	Game.商路竞争价格战(城市id)
	_populate()

func _on_商路打压(城市id: String) -> void:
	if not is_instance_valid(Game):
		return
	Game.商路竞争打压(城市id)
	_populate()

func _on_商路协商(城市id: String) -> void:
	if not is_instance_valid(Game):
		return
	Game.商路竞争协商(城市id)
	_populate()

# S2 商路贸易：真实派遣配置面板（货物来自宗主背包 + 载具选择 + 人员编组）
func _show_dispatch_panel(地区ID: String) -> void:
	if not is_instance_valid(Game):
		return
	var 地区: Dictionary = {}
	for d in Game.商队系统.商队地区:
		if d["id"] == 地区ID:
			地区 = d
			break
	if 地区.is_empty():
		UIHint.show_hint(self, "商队派遣", "未知地区")
		return
	# 清空当前内容，切换到配置视图
	for child in _content.get_children():
		child.queue_free()
	_派遣地区 = 地区
	_货物勾选 = {}
	_派遣可用载具 = []
	_派遣可用灵舟 = []
	_派遣岗位选 = {}
	_应用上次编组 = false
	_派遣接商单 = ""

	var card: PanelContainer = _make_card("派遣商队 · %s" % 地区["名称"])
	var vb: VBoxContainer = card.find_child("VBox", true, false)

	# —— 市场情报（§11.20 BUG-D + UX：地区偏好 / 封顶 / 独占 / 风险一览，玩家一眼看清配货方向与上限）——
	var 城市id: String = str(地区.get("id", ""))
	var 偏好名: Array = []
	for c in 地区.get("偏好类别", []):
		偏好名.append(str(c))
	var 偏好拼接: String = "、".join(偏好名) if not 偏好名.is_empty() else "（无）"
	# 独占判定（与 game_state.gd:1007 同步：has 且 压价率=0 ⇒ 独占；无记录 ⇒ 默认独占；否则 ×-x%）
	var 独占文: String = "✓ 默认独占"
	if Game.商队系统.商路竞争状态.has(城市id):
		var 压: float = float(Game.商队系统.商路竞争状态[城市id].get("压价率", 0.0))
		if 压 > 0.0:
			独占文 = "NPC 压价 -%.0f%%" % (压 * 100.0)
		else:
			独占文 = "✓ 已独占（×1.2 红利）"
	# 毛收益封顶（与 game_state.gd:1677 同步：商队总声望→阶梯）
	var 封顶倍率: float = 1.8
	if Game != null and Game.has_method("_商队收益封顶倍率"):
		封顶倍率 = float(Game._商队收益封顶倍率())
	# 本城商路声望加成
	var 声望加成: float = float(Game._商路声望价差加成(城市id)) if Game != null and Game.has_method("_商路声望价差加成") else 0.0
	var 声望文: String = "（+%.0f%% 声望加成）" % (声望加成 * 100.0) if 声望加成 > 0.0 else ""
	var 情报: Label = Label.new()
	情报.text = "本城偏好：%s\n当前收购价 %.2fx  %s\n毛收益封顶 %.1fx 货值（总声望→阶梯）｜独占红利：%s\n本趟成本 = 货值 + 10%% 启动资金，配【偏好】货物溢价比 %.1fx" % [
		偏好拼接,
		float(地区.get("当前收购价", 地区["收购价"])),
		声望文,
		封顶倍率,
		独占文,
		float(地区.get("溢价倍率", 1.0))
	]
	UITheme.apply_value_text(情报)
	vb.add_child(情报)
	# §11.20 修复：货物真实出库提示（原实现装货不扣背包，玩家不知货物去向）
	var 出库提示: Label = Label.new()
	出库提示.text = "※ 确认派遣后货物即从宗主背包出库，商队返回时按当地行情结算货款（成本 = 货值 + 10%启动资金）"
	UITheme.apply_aux_text(出库提示)
	出库提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(出库提示)

	# —— 货物（宗主背包聚合为批） ——
	var 货头: Label = Label.new()
	货头.text = "◆ 装载货物（宗主背包，按品阶估价）"
	UITheme.apply_section_title(货头)
	vb.add_child(货头)
	# §11.15 优化#66：一键套用上次编组（重复派遣 QoL）
	if not _上次编组.is_empty():
		var 用上次行: HBoxContainer = HBoxContainer.new()
		用上次行.add_theme_constant_override("separation", UITheme.GRID)
		var 用上次: CheckButton = CheckButton.new()
		用上次.text = "套用上次编组"
		用上次.button_pressed = false
		用上次.toggled.connect(func(on: bool) -> void: _应用上次编组 = on; _应用上次编组到面板())
		UITheme.apply_body_text(用上次)
		用上次行.add_child(用上次)
		var 上次摘要: Label = Label.new()
		上次摘要.text = "上次：%s" % str(_上次编组.get("摘要", ""))
		UITheme.apply_aux_text(上次摘要)
		上次摘要.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		用上次行.add_child(上次摘要)
		vb.add_child(用上次行)

	var 宗主背包: Array = []
	if Game.弟子列表.size() > 0:
		宗主背包 = Game.弟子列表[0].背包
	if 宗主背包.is_empty():
		var 空: Label = Label.new()
		空.text = "宗主背包暂无可用货物"
		UITheme.apply_aux_text(空)
		vb.add_child(空)
	else:
		var 货scroll: ScrollContainer = ScrollContainer.new()
		货scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		货scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		货scroll.custom_minimum_size = Vector2(0, 320)
		var 货vb: VBoxContainer = VBoxContainer.new()
		货vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		货vb.add_theme_constant_override("separation", UITheme.GRID / 2)
		货scroll.add_child(货vb)
		# 聚合同名货物为一批
		var 批次: Dictionary = {}
		for 物 in 宗主背包:
			var 名: String = str(物.名称)
			if not 批次.has(名):
				批次[名] = {"item": 物, "count": 0}
			批次[名]["count"] = int(批次[名]["count"]) + 1
		for 名 in 批次.keys():
			var 批: Dictionary = 批次[名]
			var 单价: int = _估物品价(批["item"])
			var 行: HBoxContainer = HBoxContainer.new()
			行.add_theme_constant_override("separation", UITheme.GRID)
			var 勾: CheckBox = CheckBox.new()
			var 标签: Label = Label.new()
			var 偏好列表: Array = 地区.get("偏好类别", [])
			var 是偏好: bool = str(批["item"].类别) in 偏好列表
			var 偏好前缀: String = "★ " if 是偏好 else ""
			标签.text = "%s%s（%s·%s） 单价%d ×%d" % [偏好前缀, 名, 批["item"].品阶, 批["item"].类别, 单价, int(批["count"])]
			if 是偏好:
				UITheme.apply_value_text(标签)
			else:
				UITheme.apply_body_text(标签)
			标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var 数量: SpinBox = SpinBox.new()
			数量.min_value = 0
			数量.max_value = int(批["count"])
			数量.value = 0
			数量.step = 1
			数量.allow_greater = false
			数量.allow_lesser = false
			数量.custom_minimum_size = Vector2(90, 0)
			_货物勾选[名] = {"item": 批["item"], "勾": 勾, "数量": 数量, "单价": 单价, "最大": int(批["count"])}
			勾.toggled.connect(_刷新运力提示)
			数量.value_changed.connect(_刷新运力提示)
			行.add_child(勾)
			行.add_child(标签)
			行.add_child(数量)
			货vb.add_child(行)
		vb.add_child(货scroll)

	# —— 载具 ——
	var 载头: Label = Label.new()
	载头.text = "◆ 选择载具"
	UITheme.apply_section_title(载头)
	vb.add_child(载头)
	var 载具选: OptionButton = OptionButton.new()
	载具选.add_item("不携载具（仅脚夫运力）", 0)
	if Game.商队系统.商队载具表.size() > 0:
		for vid in Game.商队系统.商队载具表.keys():
			var 载: Dictionary = Game.商队系统.商队载具表[vid]
			var 条件: String = str(载.get("unlock_condition", ""))
			var 需等: int = 1
			if "sect_level=" in 条件:
				需等 = int(条件.split("=")[1])
			if 需等 <= int(Game.门派等级):
				载具选.add_item("%s（运力%d·速度+%.1f·减损%.0f%%）" % [载["vehicle_name"], int(载["base_carry"]), float(载["speed_bonus"]), float(载["loss_reduce"]) * 100], _派遣可用载具.size() + 1)
				_派遣可用载具.append(vid)
	载具选.item_selected.connect(_刷新运力提示)
	_派遣载具选 = 载具选
	vb.add_child(载具选)

	# —— 灵舟（§11.15 阶段三：指派灵舟出使，套用有效属性；枯竭不可驱；破虚神舰可虚空瞬移）——
	var 舟头: Label = Label.new()
	舟头.text = "◆ 指派灵舟（可选）"
	UITheme.apply_section_title(舟头)
	vb.add_child(舟头)
	var 舟选: OptionButton = OptionButton.new()
	舟选.add_item("不遣灵舟（仅载具/脚夫）", 0)
	if Game.商队系统.灵舟库存.size() > 0:
		for si in range(Game.商队系统.灵舟库存.size()):
			var s舟 = Game.商队系统.灵舟库存[si]
			var 核心状 = str(s舟.get("核心状态", "正常"))
			var 枯竭标 = "（枯竭!）" if 核心状 == "枯竭" else ""
			var 瞬标 = "【虚空】" if "sf07" in s舟.get("阵法", []) else ""
			if 核心状 != "枯竭":
				舟选.add_item("%s%s T%d｜降险%.0f%%｜提速%.0f%% %s" % [瞬标, str(s舟.get("名称", "")), int(s舟.get("tier", 0)), float(s舟.get("risk_reduce", 0)) * 100, float(s舟.get("speed_bonus", 0)) * 100, 枯竭标], _派遣可用灵舟.size() + 1)
				_派遣可用灵舟.append(si)
	舟选.item_selected.connect(_刷新运力提示)
	_派遣灵舟选 = 舟选
	vb.add_child(舟选)

	# §11.15 优化#69：虚空瞬移仙玉兜底提示（派遣前让玩家知晓瞬移成本）
	var 瞬移注: Label = Label.new()
	瞬移注.text = "【虚空】灵舟返航可催动虚空大阵瞬移：需 仙核×1+灵石5万，不足则自动抵扣 仙玉×%d；皆不足则不瞬移" % int(Game.虚空瞬移仙玉费 if is_instance_valid(Game) else 50)
	UITheme.apply_aux_text(瞬移注)
	瞬移注.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(瞬移注)

	# —— 人员编组 ——
	var 人: Label = Label.new()
	人.text = "◆ 人员编组（掌柜智谋→价差 / 护卫道行→抗风险 / 脚夫→运力）"
	UITheme.apply_section_title(人)
	vb.add_child(人)
	for pid in ["p001", "p002", "p003"]:
		if not Game.商队系统.商队岗位表.has(pid):
			continue
		var 岗: Dictionary = Game.商队系统.商队岗位表[pid]
		var 行: HBoxContainer = HBoxContainer.new()
		行.add_theme_constant_override("separation", UITheme.GRID)
		var 标签: Label = Label.new()
		标签.text = str(岗.get("post_name", pid))
		标签.custom_minimum_size = Vector2(90, 0)
		UITheme.apply_body_text(标签)
		var 选: OptionButton = OptionButton.new()
		选.add_item("（不委派）", 0)
		if Game.弟子列表.size() > 0:
			for d in Game.弟子列表:
				if d == null:
					continue
				选.add_item("%s（%s·道行%d·道心%d）" % [d.姓名, d.境界, int(d.战力), int(d.道心)], int(d.弟子ID))
		选.item_selected.connect(_刷新运力提示)
		_派遣岗位选[pid] = 选
		行.add_child(标签)
		行.add_child(选)
		vb.add_child(行)

	# —— 运力 / 货值提示 ——
	var 提示: Label = Label.new()
	UITheme.apply_aux_text(提示)
	_派遣运力提示 = 提示
	vb.add_child(提示)
	_刷新运力提示()

	# —— §11.15 优化#74：特殊商单（奖励物品化）——
	var 单头: Label = Label.new()
	单头.text = "◆ 特殊商单（奖励物品）"
	UITheme.apply_section_title(单头)
	vb.add_child(单头)
	var 本城单: Array = []
	if Game != null:
		for 单 in Game.特殊商单表:
			if str(单.get("city_id", "")) == str(地区.get("id", "")):
				本城单.append(单)
	if 本城单.is_empty():
		var 空单: Label = Label.new()
		空单.text = "本城暂无特殊商单"
		UITheme.apply_aux_text(空单)
		vb.add_child(空单)
	else:
		for 单 in 本城单:
			var 行: HBoxContainer = HBoxContainer.new()
			行.add_theme_constant_override("separation", UITheme.GRID)
			var 描: Label = Label.new()
			描.text = "运%s×%d → 奖%s×%d＋灵石%d" % [str(单.get("req_type", "")), int(单.get("req_count", 0)), str(单.get("reward_item", "")), int(单.get("reward_count", 1)), int(单.get("reward_lingstone", 0))]
			UITheme.apply_body_text(描)
			描.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			描.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			行.add_child(描)
			if _派遣接商单 == str(单.get("city_id", "")):
				var 已接: Label = Label.new()
				已接.text = "✓ 已接单"
				UITheme.apply_aux_text(已接)
				行.add_child(已接)
			else:
				var 接: Button = Button.new()
				接.text = "接单"
				接.custom_minimum_size = Vector2(70, 0)
				接.pressed.connect(_on_接特殊商单.bind(str(单.get("city_id", ""))))
				行.add_child(接)
			vb.add_child(行)

	# —— 操作按钮 ——
	var 操作行: HBoxContainer = HBoxContainer.new()
	操作行.add_theme_constant_override("separation", UITheme.GRID)
	var 返回: Button = Button.new()
	返回.text = "返回"
	UITheme.apply_button_label(返回, false)
	返回.pressed.connect(_on_派遣返回)
	var 确认: Button = Button.new()
	确认.text = "确认派遣"
	UITheme.apply_button_label(确认, true)
	确认.pressed.connect(_on_确认派遣.bind(地区["id"]))
	操作行.add_child(返回)
	操作行.add_child(确认)
	vb.add_child(操作行)

	# —— 神行符（缩短贸易现实耗时）——
	var 符行: HBoxContainer = HBoxContainer.new()
	符行.add_theme_constant_override("separation", UITheme.GRID)
	var 符勾: CheckBox = CheckBox.new()
	符勾.text = "使用神行符（背包有则 -30% 贸易耗时）"
	UITheme.apply_body_text(符勾)
	var 有符 = Game._库房灵材数量(Game.商队系统.神行符名) if (Game != null and Game.has_method("_库房灵材数量")) else 0
	if 有符 <= 0:
		符勾.disabled = true
		符勾.tooltip_text = "背包无神行符（坊市可购置）"
	else:
		符勾.tooltip_text = "当前背包神行符×%d，使用1张缩短本次贸易耗时" % 有符
	_派遣神行符勾选 = 符勾
	符行.add_child(符勾)
	vb.add_child(符行)

	_content.add_child(card)

# 实时刷新运力/货值提示
func _刷新运力提示(_v = null) -> void:
	if not is_instance_valid(Game) or not is_instance_valid(_派遣运力提示):
		return
	var 运力: int = 0
	# 人员岗位运力
	for pid in _派遣岗位选.keys():
		var 选: OptionButton = _派遣岗位选[pid]
		var did: int = 选.get_selected_id()
		if did != 0 and Game.商队系统.商队岗位表.has(pid):
			运力 += int(Game.商队系统.商队岗位表[pid].get("carry_capacity", 0))
	# 载具运力
	var vidx: int = 0
	if _派遣载具选 != null:
		vidx = _派遣载具选.get_selected_id()
	if vidx > 0 and (vidx - 1) < _派遣可用载具.size():
		var vid: String = _派遣可用载具[vidx - 1]
		if Game.商队系统.商队载具表.has(vid):
			运力 += int(Game.商队系统.商队载具表[vid].get("base_carry", 0))
	# 货值
	var 货值: int = 0
	for 名 in _货物勾选.keys():
		var 项: Dictionary = _货物勾选[名]
		var 勾: CheckBox = 项["勾"]
		var 数量: SpinBox = 项["数量"]
		if 勾.button_pressed and int(数量.value) > 0:
			货值 += int(项["单价"]) * int(数量.value)
	if 运力 <= 0:
		_派遣运力提示.text = "运力 %d ｜ 货值 %d ｜ 需至少1名脚夫或1辆载具" % [运力, 货值]
	elif 货值 > 运力:
		_派遣运力提示.text = "运力 %d ｜ 货值 %d ｜ ⚠ 运力不足！" % [运力, 货值]
	else:
		_派遣运力提示.text = "运力 %d ｜ 货值 %d ｜ 预估净利 %+d ｜ 可派遣" % [运力, 货值, _预估贸易收益(货值)]

# §11.20 修复：派遣前预估净利（预估毛收益 − 货值成本 − 10%启动资金），让「选城 / 配货」的决策差异可见
func _预估贸易收益(货值: int) -> int:
	if 货值 <= 0 or _派遣地区.is_empty() or not is_instance_valid(Game):
		return 0
	var 匹配价值: int = 0
	for 名 in _货物勾选.keys():
		var 项: Dictionary = _货物勾选[名]
		var 勾: CheckBox = 项["勾"]
		var 数量: SpinBox = 项["数量"]
		if 勾.button_pressed and int(数量.value) > 0:
			var 类别: String = str(项["item"].类别)
			if 类别 != "" and 类别 in _派遣地区.get("偏好类别", []):
				匹配价值 += int(项["单价"]) * int(数量.value)
	var 匹配占比: float = float(匹配价值) / float(货值)
	var 溢价: float = 匹配占比 * float(_派遣地区.get("溢价倍率", 1.0)) + (1.0 - 匹配占比) * 1.0
	var 声望加成: float = Game._商路声望价差加成(str(_派遣地区.get("id", "")))
	var 毛收益: float = float(货值) * float(_派遣地区.get("当前收购价", 1.0)) * (1.0 + 声望加成) * 溢价 * float(_派遣地区.get("供需系数", 1.0))
	return int(毛收益 - float(货值) - float(货值) * 0.1)

func _on_确认派遣(地区ID: String) -> void:
	if not is_instance_valid(Game):
		return
	# 收集货物
	var 货物: Array = []
	var 货值: int = 0
	for 名 in _货物勾选.keys():
		var 项: Dictionary = _货物勾选[名]
		var 勾: CheckBox = 项["勾"]
		var 数量: SpinBox = 项["数量"]
		var q: int = int(数量.value)
		if 勾.button_pressed and q > 0:
			var 价: int = int(项["单价"]) * q
			货物.append({"名称": 名, "价": 价, "数量": q, "类别": str(项["item"].类别)})
			货值 += 价
	# 收集载具
	var 载具ID: String = ""
	var vidx: int = 0
	if _派遣载具选 != null:
		vidx = _派遣载具选.get_selected_id()
	if vidx > 0 and (vidx - 1) < _派遣可用载具.size():
		载具ID = _派遣可用载具[vidx - 1]
	# 收集灵舟
	var 灵舟索引: int = -1
	var sidx: int = 0
	if _派遣灵舟选 != null:
		sidx = _派遣灵舟选.get_selected_id()
	if sidx > 0 and (sidx - 1) < _派遣可用灵舟.size():
		灵舟索引 = _派遣可用灵舟[sidx - 1]
	# 收集人员
	var 人员: Array = []
	for pid in _派遣岗位选.keys():
		var 选: OptionButton = _派遣岗位选[pid]
		var did: int = 选.get_selected_id()
		if did != 0:
			人员.append({"弟子ID": did, "post_id": pid})
	if 货物.is_empty():
		UIHint.show_hint(self, "商队派遣", "请至少装载一件货物")
		return
	if 人员.is_empty() and 载具ID == "":
		UIHint.show_hint(self, "商队派遣", "需至少1名脚夫或1辆载具提供运力")
		return
	var 宗主ID: int = -1
	if Game.弟子列表.size() > 0:
		宗主ID = int(Game.弟子列表[0].弟子ID)
	var 使用符 = (_派遣神行符勾选 != null and _派遣神行符勾选.button_pressed)
	var 结果: Dictionary = Game.派遣商队(地区ID, 货物, 宗主ID, 载具ID, 人员, 灵舟索引, 使用符, _派遣接商单)
	UIHint.show_hint(self, "商队派遣", str(结果.get("消息", "派遣成功")))
	if 结果.get("成功", false):
		_记录当前编组()
		refresh()

# §11.15 优化：仙玉即时完成贸易——消耗仙玉立即结算指定商队
func _on_仙玉即时完成(商队ID: int) -> void:
	if not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.仙玉即时完成贸易(商队ID)
	UIHint.show_hint(self, "仙玉催行", str(结果.get("消息", "")))
	if 结果.get("成功", false):
		refresh()

# §11.15 优化#74：接特殊商单（记录 city_id，返航结算时校验在途货物发放奖励）
func _on_接特殊商单(city_id: String) -> void:
	_派遣接商单 = city_id
	if is_instance_valid(Game):
		UIHint.show_hint(self, "特殊商单", "已接商单（运抵%s结算时发放奖励）" % city_id)

# §11.15 优化#66：一键套用上次编组到当前派遣面板
func _应用上次编组到面板() -> void:
	if not _应用上次编组 or _上次编组.is_empty():
		return
	# 货物勾选与数量
	var 货物记忆: Dictionary = _上次编组.get("货物", {})
	for 名 in _货物勾选.keys():
		var 记录: Dictionary = _货物勾选[名]
		var 勾: CheckBox = 记录["勾"]
		var 数量: SpinBox = 记录["数量"]
		if 货物记忆.has(名):
			勾.button_pressed = true
			数量.value = clampi(int(货物记忆[名]), 0, int(记录["最大"]))
		else:
			勾.button_pressed = false
			数量.value = 0
	# 载具
	var 载具索引: int = int(_上次编组.get("载具索引", 0))
	if _派遣载具选 != null and 载具索引 >= 0 and 载具索引 < _派遣载具选.item_count:
		_派遣载具选.selected = 载具索引
	# 灵舟
	var 灵舟索引: int = int(_上次编组.get("灵舟索引", 0))
	if _派遣灵舟选 != null and 灵舟索引 >= 0 and 灵舟索引 < _派遣灵舟选.item_count:
		_派遣灵舟选.selected = 灵舟索引
	# 人员岗位
	var 人员记忆: Array = _上次编组.get("人员", [])
	for 记录 in 人员记忆:
		var pid: String = str(记录.get("post_id", ""))
		var did: int = int(记录.get("弟子ID", 0))
		if _派遣岗位选.has(pid) and did > 0:
			var 选: OptionButton = _派遣岗位选[pid]
			for i in range(选.item_count):
				if 选.get_item_id(i) == did:
					选.selected = i
					break
	# 神行符
	if _派遣神行符勾选 != null:
		_派遣神行符勾选.button_pressed = bool(_上次编组.get("神行符", false))
	# 接商单
	_派遣接商单 = str(_上次编组.get("接商单", ""))
	_刷新运力提示()

# §11.15 优化#66：记录本次派遣编组到 _上次编组
func _记录当前编组() -> void:
	var 货物记忆: Dictionary = {}
	var 摘要件数: int = 0
	for 名 in _货物勾选.keys():
		var 记录: Dictionary = _货物勾选[名]
		if 记录["勾"].button_pressed and int(记录["数量"].value) > 0:
			货物记忆[名] = int(记录["数量"].value)
			摘要件数 += 1
	var 人员记忆: Array = []
	for pid in _派遣岗位选.keys():
		var 选: OptionButton = _派遣岗位选[pid]
		var did: int = 选.get_selected_id()
		if did != 0:
			人员记忆.append({"post_id": pid, "弟子ID": did})
	var 载具索引: int = 0
	if _派遣载具选 != null:
		载具索引 = _派遣载具选.selected
	var 灵舟索引: int = 0
	if _派遣灵舟选 != null:
		灵舟索引 = _派遣灵舟选.selected
	var 摘要: String = "%d种货/%d岗/%s" % [摘要件数, 人员记忆.size(), str(_派遣地区.get("名称", "?"))]
	_上次编组 = {
		"地区": str(_派遣地区.get("id", "")),
		"货物": 货物记忆,
		"载具索引": 载具索引,
		"灵舟索引": 灵舟索引,
		"人员": 人员记忆,
		"神行符": _派遣神行符勾选 != null and _派遣神行符勾选.button_pressed,
		"接商单": _派遣接商单,
		"摘要": 摘要,
	}

func _on_派遣返回() -> void:
	refresh()

# S2 商路贸易：按品阶估算单件货物价值（不改 Item 数据层，价与运力同单位）
func _估物品价(物品: Item) -> int:
	var 序: Array = ["凡阶", "灵阶", "宝阶", "王阶", "圣阶", "仙阶", "道阶"]
	var 价表: Array = [6, 12, 25, 55, 120, 260, 550]
	var idx: int = 序.find(物品.品阶)
	if idx < 0:
		idx = 0
	return int(价表[idx])

# ===== 阵营声望 =====
func _populate_faction() -> void:
	var card := _make_card("阵营声望")
	var vb := card.find_child("VBox", true, false)

	var desc := Label.new()
	desc.text = "与各大阵营建立关系，提升声望可获得专属权益。正道与魔道对立，提升一方会降低另一方。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	if is_instance_valid(Game):
		for 阵营 in Game.阵营列表:
			var 声望值 = Game.阵营声望系统.阵营声望.get(阵营, 0)
			var 等级 = Game.获取声望等级(阵营)
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", UITheme.GRID)
			var 名 := Label.new()
			名.text = 阵营
			名.custom_minimum_size = Vector2(100, 0)
			UITheme.apply_body_text(名)
			hb.add_child(名)
			var 等级标签 := Label.new()
			等级标签.text = "[%s]" % 等级
			等级标签.custom_minimum_size = Vector2(60, 0)
			UITheme.apply_value_text(等级标签)
			hb.add_child(等级标签)
			var 进度 := Label.new()
			进度.text = "声望: %d" % int(声望值)
			进度.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UITheme.apply_aux_text(进度)
			hb.add_child(进度)
			vb.add_child(hb)

	# 声望等级说明
	var 说明头 := Label.new()
	说明头.text = "◆ 声望阶位"
	UITheme.apply_section_title(说明头)
	vb.add_child(说明头)

	var 等级说明 := Label.new()
	等级说明.text = "冷淡(0) → 中立(100) → 友善(500) → 尊敬(2000) → 崇敬(5000)"
	UITheme.apply_aux_text(等级说明)
	等级说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(等级说明)

	_content.add_child(card)

## 宗门派系页面：显示派系列表、影响力、满意度、成员
func _populate_faction_power() -> void:
	# 派系总览卡片
	var card := _make_card("宗门派系")
	var vb := card.find_child("VBox", true, false)
	
	var desc := Label.new()
	desc.text = "宗门内部各方势力此消彼长，宗主需平衡各方，避免一家独大。洞察人心、平衡权力，方为宗主之道。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)
	
	if is_instance_valid(Game) and Game.has_method("获取派系列表"):
		var 派系列表 = Game.获取派系列表()
		
		if 派系列表.is_empty():
			var 空 := Label.new()
			空.text = "当前宗门尚无明显派系，弟子们和睦相处。"
			UITheme.apply_aux_text(空)
			vb.add_child(空)
		else:
			# 派系统计
			_add_info_row(vb, "派系数量", "%d个" % 派系列表.size())
			_add_info_row(vb, "涉及弟子", "%d人" % 派系列表.reduce(func(acc, f): return acc + int(f.get("成员数量", 0)), 0))
			
			var sep := HSeparator.new()
			vb.add_child(sep)
			
			# 每个派系详情
			for 派系 in 派系列表:
				var 派系名 = str(派系.get("名称", "未知"))
				var 派系类型 = str(派系.get("类型", "未知"))
				var 影响力 = float(派系.get("影响力", 0))
				var 满意度 = float(派系.get("满意度", 60))
				var 成员数量 = int(派系.get("成员数量", 0))
				var 领袖ID = str(派系.get("领袖ID", ""))
				var 领袖 = Game._按ID找弟子(领袖ID) if Game.has_method("_按ID找弟子") else null
				var 领袖名 = 领袖.姓名 if 领袖 != null else "未知"
				
				# 派系卡片
				var 派系卡 := PanelContainer.new()
				派系卡.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(true))
				var 派系vb := VBoxContainer.new()
				派系vb.add_theme_constant_override("margin_left", UITheme.GRID)
				派系vb.add_theme_constant_override("margin_right", UITheme.GRID)
				派系vb.add_theme_constant_override("margin_top", UITheme.GRID)
				派系vb.add_theme_constant_override("margin_bottom", UITheme.GRID)
				派系vb.add_theme_constant_override("separation", UITheme.GRID / 2)
				派系卡.add_child(派系vb)
				
				# 派系名称和类型
				var 名行 := HBoxContainer.new()
				名行.add_theme_constant_override("separation", UITheme.GRID)
				var 名标 := Label.new()
				名标.text = "◇ %s" % 派系名
				UITheme.apply_title_font(名标)
				名行.add_child(名标)
				var 型标 := Label.new()
				型标.text = "[%s]" % 派系类型
				UITheme.apply_value_text(型标)
				名行.add_child(型标)
				派系vb.add_child(名行)
				
				# 派系信息
				_add_info_row(派系vb, "领袖", 领袖名)
				_add_info_row(派系vb, "成员", "%d人" % 成员数量)
				_add_info_row(派系vb, "影响力", "%.0f" % 影响力)
				
				# 满意度进度条
				var 满意行 := HBoxContainer.new()
				满意行.add_theme_constant_override("separation", UITheme.GRID)
				var 满意标 := Label.new()
				满意标.text = "满意度："
				UITheme.apply_aux_text(满意标)
				满意标.custom_minimum_size = Vector2(100, 0)
				满意行.add_child(满意标)
				var 满意进度 := ProgressBar.new()
				满意进度.min_value = 0
				满意进度.max_value = 100
				满意进度.value = 满意度
				满意进度.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				满意进度.custom_minimum_size = Vector2(0, 20)
				if 满意度 >= 80:
					满意进度.modulate = Color(0.2, 0.8, 0.2)
				elif 满意度 >= 60:
					满意进度.modulate = Color(0.8, 0.8, 0.2)
				elif 满意度 >= 40:
					满意进度.modulate = Color(0.8, 0.5, 0.2)
				else:
					满意进度.modulate = Color(0.8, 0.2, 0.2)
				满意行.add_child(满意进度)
				var 满意值 := Label.new()
				满意值.text = "%.0f%%" % 满意度
				UITheme.apply_value_text(满意值)
				满意行.add_child(满意值)
				派系vb.add_child(满意行)
				
				# 满意度评价
				var 评价 := ""
				if 满意度 >= 80:
					评价 = "● 非常满意，全力支持宗主"
				elif 满意度 >= 60:
					评价 = "● 满意，正常执行差事"
				elif 满意度 >= 40:
					评价 = "● 一般，可能消极怠工"
				elif 满意度 >= 20:
					评价 = "● 不满，可能暗中抵制"
				else:
					评价 = "⚠ 非常不满，恐生肘腋之变！"
				var 评价标 := Label.new()
				评价标.text = 评价
				UITheme.apply_body_text(评价标)
				派系vb.add_child(评价标)
				
				vb.add_child(派系卡)
	
	# 宗门派系政策卡片
	var 政策卡 := _make_card("宗门派系政策")
	var 政策vb := 政策卡.find_child("VBox", true, false)
	
	var 政策desc := Label.new()
	政策desc.text = "宗主可对各派系采取不同政策，平衡各方势力。"
	UITheme.apply_body_text(政策desc)
	政策desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	政策vb.add_child(政策desc)
	
	_add_info_row(政策vb, "平衡政策", "默认，不偏不倚，各方均等")
	_add_info_row(政策vb, "扶持政策", "扶持某派系，满意度+10")
	_add_info_row(政策vb, "打压政策", "打压某派系，满意度-15")
	_add_info_row(政策vb, "分化政策", "分化某派系，满意度-5")
	
	_content.add_child(card)
	_content.add_child(政策卡)

func _on_back_pressed() -> void:
	返回主页.emit()

# ============ B2 方针面板 + §5.4 奏折决策中心（接入「宗主管理」Tab）============
func _取方针(默认, 路径: Array):
	if Game == null or not (Game.方针 is Dictionary):
		return 默认
	var cur = Game.方针
	for k in 路径:
		if cur is Dictionary and cur.has(k):
			cur = cur[k]
		else:
			return 默认
	return cur

func _设方针(值, 路径: Array) -> void:
	if Game == null or not (Game.方针 is Dictionary):
		return
	var cur = Game.方针
	for i in 路径.size() - 1:
		var k = 路径[i]
		if not (cur is Dictionary) or not cur.has(k):
			return
		cur = cur[k]
	if cur is Dictionary and cur.has(路径[-1]):
		cur[路径[-1]] = 值

func _方针开关(标签: String, 默认: bool, 回调: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var 勾 := CheckBox.new()
	勾.button_pressed = bool(默认)
	勾.toggled.connect(func(v): 回调.call(v))
	var 文 := Label.new()
	文.text = 标签
	UITheme.apply_body_text(文)
	文.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(勾)
	hb.add_child(文)
	return hb

func _方针滑条(标签: String, 最小: float, 最大: float, 步: float, 默认: float, 回调: Callable, 格式: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", UITheme.GRID / 2)
	var 行 := HBoxContainer.new()
	行.add_theme_constant_override("separation", UITheme.GRID)
	var 文 := Label.new()
	文.text = 标签
	UITheme.apply_body_text(文)
	文.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	行.add_child(文)
	var 值标 := Label.new()
	值标.text = 格式 % int(默认 * 100) if 格式 == "%d%%" else str(默认)
	UITheme.apply_value_text(值标)
	值标.add_theme_color_override("font_color", UITheme.获取金文字色())
	行.add_child(值标)
	vb.add_child(行)
	var 滑 := HSlider.new()
	滑.min_value = 最小
	滑.max_value = 最大
	滑.step = 步
	滑.value = 默认
	滑.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滑.value_changed.connect(func(v):
		值标.text = 格式 % int(v * 100) if 格式 == "%d%%" else str(v)
		回调.call(v)
	)
	vb.add_child(滑)
	return vb

func _方针数值(标签: String, 最小: int, 最大: int, 默认: int, 回调: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var 文 := Label.new()
	文.text = 标签
	UITheme.apply_body_text(文)
	文.custom_minimum_size = Vector2(140, 0)
	hb.add_child(文)
	var 框 := SpinBox.new()
	框.min_value = 最小
	框.max_value = 最大
	框.value = 默认
	框.step = 1
	框.allow_greater = false
	框.allow_lesser = false
	框.custom_minimum_size = Vector2(120, 0)
	框.value_changed.connect(func(v): 回调.call(int(v)))
	hb.add_child(框)
	return hb

func _方针选项(标签: String, 选项: Array, 当前: String, 回调: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var 文 := Label.new()
	文.text = 标签
	UITheme.apply_body_text(文)
	文.custom_minimum_size = Vector2(140, 0)
	hb.add_child(文)
	var 选 := OptionButton.new()
	for o in 选项:
		选.add_item(str(o), 选项.find(o))
	if 当前 in 选项:
		选.select(选项.find(当前))
	选.item_selected.connect(func(idx): 回调.call(选项[idx]))
	hb.add_child(选)
	return hb

func _populate_policy() -> void:
	var card := _make_card("宗门治理方针")
	var vb := card.find_child("VBox", true, false)
	
	var 说明 := Label.new()
	说明.text = "设定宗门治理总方针，推演月起由系统自动执行。修改即时生效。"
	UITheme.apply_body_text(说明)
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(说明)
	
	var 历练 := Label.new()
	历练.text = "◆ 历练"
	UITheme.apply_section_title(历练)
	vb.add_child(历练)
	vb.add_child(_方针开关("自动派遣弟子历练", bool(_取方针(false, ["历练","自动派遣"])), func(v): _设方针(v, ["历练","自动派遣"])))
	vb.add_child(_方针滑条("历练风险偏好", 0.0, 1.0, 0.05, float(_取方针(0.5, ["历练","风险偏好"])), func(v): _设方针(v, ["历练","风险偏好"]), "%d%%"))
	
	var 供给 := Label.new()
	供给.text = "◆ 供给"
	UITheme.apply_section_title(供给)
	vb.add_child(供给)
	vb.add_child(_方针开关("丹药自动炼制", bool(_取方针(false, ["供给","丹药自动炼制"])), func(v): _设方针(v, ["供给","丹药自动炼制"])))
	vb.add_child(_方针数值("丹药囤积线", 0, 200, int(_取方针(20, ["供给","丹药囤积线"])), func(v): _设方针(v, ["供给","丹药囤积线"])))
	vb.add_child(_方针开关("装备自动锻造", bool(_取方针(false, ["供给","装备自动锻造"])), func(v): _设方针(v, ["供给","装备自动锻造"])))
	vb.add_child(_方针数值("装备囤积线", 0, 100, int(_取方针(10, ["供给","装备囤积线"])), func(v): _设方针(v, ["供给","装备囤积线"])))
	
	var 建造 := Label.new()
	建造.text = "◆ 建造"
	UITheme.apply_section_title(建造)
	vb.add_child(建造)
	vb.add_child(_方针开关("殿阁自动升级", bool(_取方针(false, ["建造","自动升级"])), func(v): _设方针(v, ["建造","自动升级"])))
	
	var 修炼 := Label.new()
	修炼.text = "◆ 修炼"
	UITheme.apply_section_title(修炼)
	vb.add_child(修炼)
	vb.add_child(_方针选项("修炼风格", ["稳健", "均衡", "激进"], str(_取方针("均衡", ["修炼", "风格"])), func(v): _设方针(v, ["修炼", "风格"])))

	var 外交 := Label.new()
	外交.text = "◆ 外交"
	UITheme.apply_section_title(外交)
	vb.add_child(外交)
	vb.add_child(_方针选项("阵营姿态", ["正道", "魔道", "中立", "均衡"], str(_取方针("均衡", ["外交", "阵营姿态"])), func(v): _设方针(v, ["外交", "阵营姿态"])))

	var 奏折 := Label.new()
	奏折.text = "◆ 奏折敏感度"
	UITheme.apply_section_title(奏折)
	vb.add_child(奏折)
	var 档位 := ["仅存亡", "仅重大", "全弹"]
	vb.add_child(_方针选项("奏折呈报阈值", 档位, str(_取方针("仅重大", ["奏折敏感度"])), func(v): _设方针(v, ["奏折敏感度"])))
	
	_content.add_child(card)

func _populate_memorial() -> void:
	var card := _make_card("奏折决策中心")
	var vb := card.find_child("VBox", true, false)
	
	if Game == null or Game.待决奏折.size() == 0:
		var 空 := Label.new()
		空.text = "宗门清平，暂无待决奏折。"
		UITheme.apply_body_text(空)
		空.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(空)
		_content.add_child(card)
		return
	
	var 序: int = 0
	for 折 in Game.待决奏折:
		var 案 := PanelContainer.new()
		案.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
		var 内 := VBoxContainer.new()
		内.name = "VBox"
		内.add_theme_constant_override("margin_left", UITheme.GRID)
		内.add_theme_constant_override("margin_right", UITheme.GRID)
		内.add_theme_constant_override("margin_top", UITheme.GRID)
		内.add_theme_constant_override("margin_bottom", UITheme.GRID)
		内.add_theme_constant_override("separation", UITheme.GRID / 2)
		案.add_child(内)
		
		var 头 := HBoxContainer.new()
		头.add_theme_constant_override("separation", UITheme.GRID)
		var 重大 := str(折.get("重大性", "普通"))
		var 标签 := Label.new()
		标签.text = "【" + 重大 + "】"
		UITheme.apply_section_title(标签)
		var 色: Color = UITheme.获取金文字色()
		if 重大 == "存亡":
			色 = Color(0.9, 0.3, 0.3)
		标签.add_theme_color_override("font_color", 色)
		头.add_child(标签)
		var 提议 := Label.new()
		提议.text = str(折.get("提议人", ""))
		UITheme.apply_body_text(提议)
		提议.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		头.add_child(提议)
		内.add_child(头)
		
		var 事 := Label.new()
		事.text = str(折.get("事由", ""))
		UITheme.apply_body_text(事)
		事.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		内.add_child(事)
		
		for 选 in 折.get("选项", []):
			var 行 := HBoxContainer.new()
			行.add_theme_constant_override("separation", UITheme.GRID)
			var 文本 := str(选.get("文本", ""))
			var 推荐: bool = bool(选.get("推荐", false))
			var 预览 := str(选.get("后果预览", ""))
			var 钮 := Button.new()
			钮.text = 文本 + ("（推荐）" if 推荐 else "")
			if 推荐:
				UITheme.apply_button_label(钮, true)
			else:
				UITheme.apply_button_label(钮, false)
				钮.add_theme_color_override("font_color", UITheme.获取主文字色())
			var 本序: int = 序
			var 本文本: String = 文本
			钮.pressed.connect(func():
				if is_instance_valid(Game):
					Game.裁决奏折(本序, 本文本)
				refresh()
			)
			行.add_child(钮)
			if 预览 != "":
				var 预 := Label.new()
				预.text = "→ " + 预览
				UITheme.apply_aux_text(预)
				预.add_theme_color_override("font_color", UITheme.获取弱文字色())
				预.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				预.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				行.add_child(预)
			内.add_child(行)
		序 += 1
		
		vb.add_child(案)
	
	_content.add_child(card)

# ===== S27 宗门任务榜 =====
func _populate_bounty() -> void:
	if Game == null:
		return
	if _任务榜提示 != "":
		var 提示: Label = Label.new()
		提示.text = _任务榜提示
		UITheme.apply_aux_text(提示)
		提示.add_theme_color_override("font_color", UITheme.获取金文字色())
		提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(提示)
	_content.add_child(_构建请命卡())
	_content.add_child(_构建执行中卡())
	_content.add_child(_构建招募中卡())
	_content.add_child(_构建挂榜卡())


## 弟子主动请命：宗主准/驳，驳回则其志难伸、心境 -3
func _构建请命卡() -> Control:
	var card: PanelContainer = _make_card("弟子请命（待宗主定夺）")
	var vb: VBoxContainer = card.find_child("VBox", true, false)
	if Game.弟子请命列表.size() == 0:
		var 空: Label = Label.new()
		空.text = "门下安分，暂无请命。"
		UITheme.apply_body_text(空)
		vb.add_child(空)
		return card
	var 序: int = 0
	for q in Game.弟子请命列表:
		var 案: PanelContainer = PanelContainer.new()
		案.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
		var 内: VBoxContainer = VBoxContainer.new()
		内.add_theme_constant_override("margin_left", UITheme.GRID)
		内.add_theme_constant_override("margin_right", UITheme.GRID)
		内.add_theme_constant_override("margin_top", UITheme.GRID)
		内.add_theme_constant_override("margin_bottom", UITheme.GRID)
		内.add_theme_constant_override("separation", UITheme.GRID / 2)
		案.add_child(内)

		var 头: Label = Label.new()
		头.text = "%s 请办【%s】（%s·难度%d·意愿%d%%）" % [
			str(q.get("弟子名", "")), str(q.get("任务名", "")),
			SectBounty.类型名(str(q.get("类型", ""))), int(q.get("难度", 1)),
			int(round(float(q.get("意愿", 0.0)) * 100.0))]
		UITheme.apply_body_text(头)
		头.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		内.add_child(头)

		var 由: Label = Label.new()
		由.text = str(q.get("理由", ""))
		UITheme.apply_aux_text(由)
		由.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		内.add_child(由)

		var 行: HBoxContainer = HBoxContainer.new()
		行.add_theme_constant_override("separation", UITheme.GRID)
		var 本序: int = 序
		var 准: Button = Button.new()
		准.text = "准其所请"
		UITheme.apply_button_label(准, true)
		准.add_theme_color_override("font_color", UITheme.获取主文字色())
		准.pressed.connect(func(): _on_准请命(本序))
		行.add_child(准)
		var 驳: Button = Button.new()
		驳.text = "驳回（心境 -3）"
		UITheme.apply_button_label(驳, false)
		驳.add_theme_color_override("font_color", UITheme.获取主文字色())
		驳.pressed.connect(func(): _on_驳请命(本序))
		行.add_child(驳)
		内.add_child(行)

		vb.add_child(案)
		序 += 1
	return card


## 执行中：弟子已接取，到期由推演自动结算
func _构建执行中卡() -> Control:
	var card: PanelContainer = _make_card("执行中")
	var vb: VBoxContainer = card.find_child("VBox", true, false)
	var 列表: Array = Game.取宗门任务进行中()
	if 列表.size() == 0:
		var 空: Label = Label.new()
		空.text = "暂无弟子在外办差。"
		UITheme.apply_body_text(空)
		vb.add_child(空)
		return card
	for 实 in 列表:
		var 案: PanelContainer = PanelContainer.new()
		案.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
		var 内: VBoxContainer = VBoxContainer.new()
		内.add_theme_constant_override("margin_left", UITheme.GRID)
		内.add_theme_constant_override("margin_right", UITheme.GRID)
		内.add_theme_constant_override("margin_top", UITheme.GRID)
		内.add_theme_constant_override("margin_bottom", UITheme.GRID)
		内.add_theme_constant_override("separation", UITheme.GRID / 2)
		案.add_child(内)

		var 头: Label = Label.new()
		头.text = "%s · %s【%s】难度%d" % [
			str(实.get("弟子名", "—")), str(实.get("类型", "")),
			str(实.get("任务名", "")), int(实.get("难度", 1))]
		UITheme.apply_body_text(头)
		头.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		内.add_child(头)

		var 条: ProgressBar = ProgressBar.new()
		条.min_value = 0.0
		条.max_value = 1.0
		条.value = clamp(float(实.get("进度", 0.0)), 0.0, 1.0)
		条.show_percentage = false
		条.custom_minimum_size = Vector2(0, int(round(12.0 * UITheme.UI_SCALE)))
		条.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		内.add_child(条)

		var 尾: Label = Label.new()
		尾.text = "约 %d 日可归 · 酬以%s之物" % [
			int(实.get("剩余日", 0)), str(实.get("报酬品阶", ""))]
		UITheme.apply_aux_text(尾)
		内.add_child(尾)

		vb.add_child(案)
	return card


## 招募中：已挂榜、无人接取（或尚未到月度判定时刻）
func _构建招募中卡() -> Control:
	var card: PanelContainer = _make_card("差事榜 · 招募中")
	var vb: VBoxContainer = card.find_child("VBox", true, false)
	var 有: bool = false
	for tid in Game.宗门任务榜:
		var 任务: Dictionary = Game.宗门任务榜[tid]
		if str(任务.get("状态", "")) != "招募中":
			continue
		有 = true
		var 模板: Dictionary = SectBounty.取模板(str(任务.get("模板ID", "")))
		var 案: PanelContainer = PanelContainer.new()
		案.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
		var 内: VBoxContainer = VBoxContainer.new()
		内.add_theme_constant_override("margin_left", UITheme.GRID)
		内.add_theme_constant_override("margin_right", UITheme.GRID)
		内.add_theme_constant_override("margin_top", UITheme.GRID)
		内.add_theme_constant_override("margin_bottom", UITheme.GRID)
		内.add_theme_constant_override("separation", UITheme.GRID / 2)
		案.add_child(内)

		var 摘: Label = Label.new()
		摘.text = SectBounty.摘要(模板, str(任务.get("报酬品阶", "")))
		UITheme.apply_body_text(摘)
		摘.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		内.add_child(摘)

		var 挂: int = int(Game.累计游戏日) - int(任务.get("发布日", 0))
		var 冷: Label = Label.new()
		冷.text = "已挂 %d 日无人问津" % 挂 if 挂 > 0 else "方才挂出，静待弟子"
		UITheme.apply_aux_text(冷)
		内.add_child(冷)

		var 本ID: String = str(tid)
		var 撤: Button = Button.new()
		撤.text = "撤榜"
		UITheme.apply_button_label(撤, false)
		撤.add_theme_color_override("font_color", UITheme.获取主文字色())
		撤.pressed.connect(func(): _on_撤任务(本ID))
		内.add_child(撤)

		vb.add_child(案)
	if not 有:
		var 空: Label = Label.new()
		空.text = "榜上无差事。可于下方挂榜，弟子会依自身主目标自行接取。"
		UITheme.apply_body_text(空)
		空.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(空)
	return card


## 发布新任务：选模板 → 调报酬档位 → 挂榜（报酬由宗门库房拨付实物）
func _构建挂榜卡() -> Control:
	var card: PanelContainer = _make_card("发布新任务")
	var vb: VBoxContainer = card.find_child("VBox", true, false)
	var 全部: Array = SectBounty.全部模板()
	if 全部.size() == 0:
		var 空: Label = Label.new()
		空.text = "差事榜模板未载入。"
		UITheme.apply_body_text(空)
		vb.add_child(空)
		return card

	for 类型 in ["collect", "hunt", "diplomacy"]:
		var 组: Label = Label.new()
		组.text = "◆ " + SectBounty.类型名(str(类型))
		UITheme.apply_section_title(组)
		vb.add_child(组)
		for 模板 in 全部:
			if str(模板.get("bounty_type", "")) != str(类型):
				continue
			var 本ID: String = str(模板.get("bounty_id", ""))
			var 选中: bool = (本ID == _发布模板选)
			var 钮: Button = Button.new()
			钮.text = SectBounty.摘要(模板)
			UITheme.apply_button_label(钮, false)
			钮.add_theme_color_override("font_color", UITheme.获取金文字色() if 选中 else UITheme.获取主文字色())
			钮.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			钮.pressed.connect(func(): _on_选模板(本ID))
			vb.add_child(钮)

	if _发布模板选 == "":
		var 导: Label = Label.new()
		导.text = "点上方差事以选定，再调报酬档位，然后挂榜。"
		UITheme.apply_aux_text(导)
		导.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(导)
		return card

	var 选模板: Dictionary = SectBounty.取模板(_发布模板选)
	if 选模板.is_empty():
		_发布模板选 = ""
		return card

	var 档标: Label = Label.new()
	档标.text = "报酬档位（自宗门库房拨付实物，压档省钱但冷清，加档热门但割肉）"
	UITheme.apply_aux_text(档标)
	档标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(档标)

	var 档行: HBoxContainer = HBoxContainer.new()
	档行.add_theme_constant_override("separation", UITheme.GRID / 2)
	for 档 in [-2, -1, 0, 1, 2]:
		var 本档: int = int(档)
		var b: Button = Button.new()
		b.text = _档差名(本档)
		UITheme.apply_button_label(b, 本档 == _发布档差)
		b.add_theme_color_override("font_color", UITheme.获取金文字色() if 本档 == _发布档差 else UITheme.获取主文字色())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _on_设档差(本档))
		档行.add_child(b)
	vb.add_child(档行)

	var 实给: String = _实给报酬品阶(选模板)
	var 存: int = _库房同阶数(实给)
	var 说: Label = Label.new()
	说.text = "酬以 %s 之物，库房现存 %d 件" % [实给, 存]
	UITheme.apply_aux_text(说)
	vb.add_child(说)
	if 存 == 0:
		var 警: Label = Label.new()
		警.text = "库房无此阶之物，届时报酬落空，弟子恐生怨望。"
		UITheme.apply_aux_text(警)
		警.add_theme_color_override("font_color", UITheme.获取金文字色())
		警.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(警)

	var 挂: Button = Button.new()
	挂.text = "挂榜：【%s】" % str(选模板.get("bounty_name", ""))
	UITheme.apply_button_label(挂, true)
	挂.add_theme_color_override("font_color", UITheme.获取主文字色())
	挂.pressed.connect(func(): _on_挂榜())
	vb.add_child(挂)
	return card


func _档差名(档: int) -> String:
	match 档:
		-2:
			return "压两档"
		-1:
			return "压一档"
		0:
			return "标准"
		1:
			return "加一档"
		2:
			return "加两档"
	return "标准"


## 标准报酬品阶 ± 档差（用 Item.品阶序 夹取，避免越界）
func _实给报酬品阶(模板: Dictionary) -> String:
	var 标准: String = SectBounty.标准报酬品阶(模板)
	var i: int = Item.品阶序.find(标准)
	if i < 0:
		return 标准
	var j: int = clamp(i + _发布档差, 0, Item.品阶序.size() - 1)
	return str(Item.品阶序[j])


## 宗门库房内该品阶的件数（库房混有 Item 与 Dictionary，须 is Item 防御）
func _库房同阶数(品阶: String) -> int:
	var n: int = 0
	if Game == null:
		return 0
	for it in Game.宗门库房:
		if it == null or not (it is Item):
			continue
		if str(it.品阶) == 品阶:
			n += 1
	return n


func _on_选模板(模板ID: String) -> void:
	_发布模板选 = 模板ID
	_任务榜提示 = ""
	_populate()


func _on_设档差(档: int) -> void:
	_发布档差 = 档
	_populate()


func _on_挂榜() -> void:
	if Game == null or _发布模板选 == "":
		return
	var 模板: Dictionary = SectBounty.取模板(_发布模板选)
	if 模板.is_empty():
		return
	var 结: Dictionary = Game.发布宗门任务(_发布模板选, _实给报酬品阶(模板))
	if bool(结.get("成功", false)):
		_任务榜提示 = "已挂榜【%s】，静待弟子接取" % str(模板.get("bounty_name", ""))
	else:
		_任务榜提示 = "挂榜失败：%s" % str(结.get("原因", ""))
	_populate()


func _on_撤任务(任务ID: String) -> void:
	if Game == null:
		return
	var 结: Dictionary = Game.撤销宗门任务(任务ID)
	if bool(结.get("成功", false)):
		_任务榜提示 = "已撤下该榜文"
	else:
		_任务榜提示 = "撤榜失败：%s" % str(结.get("原因", ""))
	_populate()


func _on_准请命(索引: int) -> void:
	if Game == null:
		return
	var 名: String = ""
	if 索引 >= 0 and 索引 < Game.弟子请命列表.size():
		名 = str(Game.弟子请命列表[索引].get("弟子名", ""))
	var 结: Dictionary = Game.批准请命(索引)
	if bool(结.get("成功", false)):
		_任务榜提示 = "准【%s】所请，已遣其往办" % 名
	else:
		_任务榜提示 = "未能准请：%s" % str(结.get("原因", ""))
	_populate()


func _on_驳请命(索引: int) -> void:
	if Game == null:
		return
	var 名: String = ""
	if 索引 >= 0 and 索引 < Game.弟子请命列表.size():
		名 = str(Game.弟子请命列表[索引].get("弟子名", ""))
	var 结: Dictionary = Game.驳回请命(索引)
	if bool(结.get("成功", false)):
		_任务榜提示 = "驳【%s】所请，其志难伸（心境 -3）" % 名
	else:
		_任务榜提示 = "未能驳回：%s" % str(结.get("原因", ""))
	_populate()


# ============ S28 功勋堂：个人贡献账户 / 交宗返还 / 兑换出口 ============
# 交宗之物：七成记入弟子「个人功勋」，三成归入公中，实物入宗门库藏。
# 弟子可在功勋堂以功勋兑换库藏任意物品（按类别×品阶定价）或保命护身；
# 弟子亦会按月自主消费（每月至多一件，留存两成余额，库藏余量不足则不兑）。

func _populate_merit() -> void:
	if Game == null:
		return
	if _功勋提示 != "":
		var 提示: Label = Label.new()
		提示.text = _功勋提示
		UITheme.apply_aux_text(提示)
		提示.add_theme_color_override("font_color", UITheme.获取金文字色())
		提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(提示)
	_content.add_child(_构建功勋总览卡())
	_content.add_child(_构建功勋弟子卡())
	_content.add_child(_构建功勋兑换卡())


## 总览：公中 / 个人账户合计 / 规则说明 / 库藏定价格
func _构建功勋总览卡() -> Control:
	var card: PanelContainer = _make_card("功勋总览")
	var vb: VBoxContainer = card.find_child("VBox", true, false)

	var 合计: int = 0
	var 有余额: int = 0
	var 在宗数: int = 0
	for d in Game.弟子列表:
		if d == null:
			continue
		if d.状态 != "在宗":
			continue
		在宗数 += 1
		合计 += d.贡献账户
		if d.贡献账户 > 0:
			有余额 += 1
	_add_info_row(vb, "公中贡献点", str(Game.贡献点))
	_add_info_row(vb, "个人功勋合计", "%d（有余额者 %d / 在宗 %d）" % [合计, 有余额, 在宗数])

	var 规: Label = Label.new()
	规.text = "交宗之物：70%记入个人功勋，30%归入公中，实物入宗门库藏；功勋可在此兑库藏诸物。"
	UITheme.apply_aux_text(规)
	规.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(规)

	var 自: Label = Label.new()
	自.text = "弟子每月至多自兑一件，且须留存20%功勋、库藏该品阶余量充裕方兑。"
	UITheme.apply_aux_text(自)
	自.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(自)

	var 题: Label = Label.new()
	题.text = "库藏定价（功勋）"
	UITheme.apply_section_title(题)
	vb.add_child(题)
	for 行 in ContributionShop.定价表():
		var 价行: Label = Label.new()
		价行.text = "%s　灵材%s · 丹药%s · 法器%s · 神兵%s · 法宝%s" % [
			str(行.get("tier", "")), str(行.get("灵材", "-")), str(行.get("丹药", "-")),
			str(行.get("法器", "-")), str(行.get("神兵", "-")), str(行.get("法宝", "-"))]
		UITheme.apply_aux_text(价行)
		价行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(价行)
	return card


## 选择弟子：仅列有余额者，按余额降序（最多 12），选中描金
func _构建功勋弟子卡() -> Control:
	var card: PanelContainer = _make_card("选择弟子")
	var vb: VBoxContainer = card.find_child("VBox", true, false)

	var 名单: Array = []
	for d in Game.弟子列表:
		if d == null or d.状态 != "在宗":
			continue
		if d.贡献账户 <= 0:
			continue
		名单.append(d)
	# 选择排序：按个人功勋降序（n 很小，不引 sort_custom 的 API 风险）
	var i: int = 0
	while i < 名单.size():
		var j: int = i + 1
		while j < 名单.size():
			if 名单[j].贡献账户 > 名单[i].贡献账户:
				var 暂 = 名单[i]
				名单[i] = 名单[j]
				名单[j] = 暂
			j += 1
		i += 1

	if 名单.size() == 0:
		var 空: Label = Label.new()
		空.text = "尚无人有功勋在身——弟子交宗后即有功勋。"
		UITheme.apply_body_text(空)
		空.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(空)
		return card

	var 上限: int = min(12, 名单.size())
	for k in range(上限):
		var 弟子 = 名单[k]
		var 本ID: int = 弟子.弟子ID
		var 钮: Button = Button.new()
		钮.text = "%s（%s）功勋 %d" % [str(弟子.姓名), str(弟子.境界), 弟子.贡献账户]
		UITheme.apply_button_label(钮, false)
		if 本ID == _功勋弟子选:
			钮.add_theme_color_override("font_color", UITheme.获取金文字色())
		else:
			钮.add_theme_color_override("font_color", UITheme.获取主文字色())
		钮.pressed.connect(func(): _on_选功勋弟子(本ID))
		vb.add_child(钮)
	if 名单.size() > 上限:
		var 余: Label = Label.new()
		余.text = "（另有 %d 人有功勋在身，前列功勋最高者 %d 人）" % [名单.size() - 上限, 上限]
		UITheme.apply_aux_text(余)
		vb.add_child(余)
	return card


## 兑换清单：库藏全部可兑之物 + 保命护身
func _构建功勋兑换卡() -> Control:
	var card: PanelContainer = _make_card("兑换（宗主代兑）")
	var vb: VBoxContainer = card.find_child("VBox", true, false)
	if _功勋弟子选 < 0:
		var 空: Label = Label.new()
		空.text = "请先在上方的弟子中选择一人。"
		UITheme.apply_body_text(空)
		vb.add_child(空)
		return card

	var 选中 = null
	for d in Game.弟子列表:
		if d != null and d.弟子ID == _功勋弟子选:
			选中 = d
			break
	if 选中 == null:
		_功勋弟子选 = -1
		var 失: Label = Label.new()
		失.text = "该弟子已不在宗中。"
		UITheme.apply_body_text(失)
		vb.add_child(失)
		return card

	var 头: Label = Label.new()
	头.text = "%s · 个人功勋 %d · 保命护身 %d 枚" % [str(选中.姓名), 选中.贡献账户, 选中.保命护身]
	UITheme.apply_body_text(头)
	头.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(头)

	var 清单: Array = ContributionShop.完整清单(Game.宗门库房)
	if 清单.size() <= 1:
		var 空2: Label = Label.new()
		空2.text = "宗门库藏空空如也，仅余保命护身可兑——弟子交宗之物会入此库。"
		UITheme.apply_aux_text(空2)
		空2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(空2)

	var 本ID: int = _功勋弟子选
	for 项 in 清单:
		var 本项: Dictionary = 项
		var 价: int = int(本项.get("价格", 0))
		var 买得起: bool = 选中.贡献账户 >= 价

		var 案: PanelContainer = PanelContainer.new()
		案.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
		var 内: VBoxContainer = VBoxContainer.new()
		内.add_theme_constant_override("margin_left", UITheme.GRID)
		内.add_theme_constant_override("margin_right", UITheme.GRID)
		内.add_theme_constant_override("margin_top", UITheme.GRID)
		内.add_theme_constant_override("margin_bottom", UITheme.GRID)
		内.add_theme_constant_override("separation", UITheme.GRID / 2)
		案.add_child(内)

		var 摘: Label = Label.new()
		摘.text = ContributionShop.摘要(本项)
		UITheme.apply_body_text(摘)
		摘.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		内.add_child(摘)

		var 钮: Button = Button.new()
		if 买得起:
			钮.text = "兑（耗功勋 %d）" % 价
		else:
			钮.text = "功勋不足（需 %d）" % 价
		钮.disabled = not 买得起
		UITheme.apply_button_label(钮, 买得起)
		钮.add_theme_color_override("font_color", UITheme.获取主文字色())
		钮.pressed.connect(func(): _on_代兑(本ID, 本项))
		内.add_child(钮)

		vb.add_child(案)
	return card


func _on_选功勋弟子(弟子ID: int) -> void:
	_功勋弟子选 = 弟子ID
	_功勋提示 = ""
	_populate()


func _on_代兑(弟子ID: int, 条目: Dictionary) -> void:
	if Game == null:
		return
	var 结果: Dictionary = {}
	if str(条目.get("类别", "")) == "护身":
		结果 = Game.弟子兑换保命(弟子ID, 1)
	else:
		var 物 = 条目.get("物品", null)
		结果 = Game.弟子兑换(弟子ID, 物)
	if bool(结果.get("成功", false)):
		_功勋提示 = "已为%s兑下【%s】，耗功勋 %d，余 %d" % [
			str(结果.get("弟子", "")), str(结果.get("物品", "保命护身")),
			int(结果.get("消耗功勋", 0)), int(结果.get("余功勋", 0))]
	else:
		_功勋提示 = str(结果.get("原因", "兑换未成"))
	_populate()

# ── 护道人管理（P0新增）────────────────────────────────────────
func _populate_hudao() -> void:
	if Game == null:
		return

	# 标题
	var 标题 := Label.new()
	标题.text = "护道人管理"
	UITheme.apply_title_font(标题)
	_content.add_child(标题)

	# 统计信息
	var 所有护道人: Array = Game.获取所有护道人()
	var 统计label := Label.new()
	统计label.text = "当前护道人：%d名 | 护道玉符：%d | 护道续缘符：%d | 功德玉牌：%d | 气运符箓：%d | 替死玉符：%d" % [
		所有护道人.size(), Game.护道玉符, Game.护道续缘符, Game.功德玉牌, Game.气运符箓, Game.替死玉符
	]
	UITheme.apply_aux_font(统计label)
	_content.add_child(统计label)

	# 护道人列表
	if 所有护道人.is_empty():
		var 空label := Label.new()
		空label.text = "暂无护道人。超潜力弟子、宗主亲传、核心人员嫡系血脉会自动配备护道人。"
		空label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_content.add_child(空label)
	else:
		for 护道人 in 所有护道人:
			var 卡 := PanelContainer.new()
			卡.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var 卡样式 := StyleBoxFlat.new()
			卡样式.bg_color = Color(0.12, 0.10, 0.08, 0.8)
			卡样式.set_corner_radius_all(8)
			卡样式.set_border_width_all(1)
			卡样式.border_color = Color(0.5, 0.45, 0.3)
			卡样式.set_content_margin_all(12)
			卡.add_theme_stylebox_override("panel", 卡样式)

			var vbox := VBoxContainer.new()
			vbox.add_theme_constant_override("separation", 4)
			卡.add_child(vbox)

			# 第一行：弟子名 + 护道人名
			var 行1 := HBoxContainer.new()
			行1.add_theme_constant_override("separation", 12)
			vbox.add_child(行1)

			var 弟子名label := Label.new()
			弟子名label.text = "弟子：%s" % str(护道人.get("弟子姓名", ""))
			UITheme.apply_project_font(弟子名label, UITheme.FONT_H2, true)
			弟子名label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
			行1.add_child(弟子名label)

			var 护道人名label := Label.new()
			护道人名label.text = "护道人：%s（%s）" % [str(护道人.get("护道人姓名", "")), str(护道人.get("护道人等级", ""))]
			UITheme.apply_project_font(护道人名label, UITheme.FONT_H2, true)
			护道人名label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
			行1.add_child(护道人名label)

			# 第二行：功德 + 剩余天数
			var 行2 := HBoxContainer.new()
			行2.add_theme_constant_override("separation", 12)
			vbox.add_child(行2)

			var 功德label := Label.new()
			功德label.text = "功德：%d" % int(护道人.get("功德", 0))
			UITheme.apply_project_font(功德label, UITheme.FONT_BODY, false)
			功德label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
			行2.add_child(功德label)

			var 剩余label := Label.new()
			剩余label.text = "剩余：%d日" % int(护道人.get("剩余天数", 0))
			UITheme.apply_project_font(剩余label, UITheme.FONT_BODY, false)
			剩余label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
			行2.add_child(剩余label)

			var 替死label := Label.new()
			替死label.text = "替死玉符：%s" % ("已启" if bool(护道人.get("替死玉符", false)) else "未启")
			UITheme.apply_project_font(替死label, UITheme.FONT_BODY, false)
			替死label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3) if bool(护道人.get("替死玉符", false)) else Color(0.5, 0.5, 0.5))
			行2.add_child(替死label)

			# 第三行：操作按钮
			var 行3 := HBoxContainer.new()
			行3.add_theme_constant_override("separation", 8)
			vbox.add_child(行3)

			var 弟子ID: int = int(护道人.get("弟子ID", 0))

			var 续缘btn := Button.new()
			续缘btn.text = "续缘（%d符）" % Game.护道续缘符
			续缘btn.custom_minimum_size = Vector2(0, 28)
			UITheme.apply_project_font(续缘btn, UITheme.FONT_BODY, false)
			续缘btn.pressed.connect(_on_hudao_xuyuan.bind(弟子ID))
			行3.add_child(续缘btn)

			var 功德btn := Button.new()
			功德btn.text = "功德+200（%d牌）" % Game.功德玉牌
			功德btn.custom_minimum_size = Vector2(0, 28)
			UITheme.apply_project_font(功德btn, UITheme.FONT_BODY, false)
			功德btn.pressed.connect(_on_hudao_gongde.bind(弟子ID))
			行3.add_child(功德btn)

			var 气运btn := Button.new()
			气运btn.text = "气运加持（%d符）" % Game.气运符箓
			气运btn.custom_minimum_size = Vector2(0, 28)
			UITheme.apply_project_font(气运btn, UITheme.FONT_BODY, false)
			气运btn.pressed.connect(_on_hudao_qiyun.bind(弟子ID))
			行3.add_child(气运btn)

			var 替死btn := Button.new()
			替死btn.text = "替死玉符（%d符）" % Game.替死玉符
			替死btn.custom_minimum_size = Vector2(0, 28)
			UITheme.apply_project_font(替死btn, UITheme.FONT_BODY, false)
			替死btn.pressed.connect(_on_hudao_tisi.bind(弟子ID))
			行3.add_child(替死btn)

			_content.add_child(卡)

	# 待配备护道人列表
	var 待配备: Array = []
	for d in Game.弟子列表:
		if d is Disciple:
			var 需求: String = Game.检查护道人需求(d)
			if 需求 != "" and not Game.护道人列表.has(d.弟子ID):
				待配备.append({"弟子": d, "需求": 需求})

	if not 待配备.is_empty():
		var 待配备标题 := Label.new()
		待配备标题.text = "待配备护道人（%d名）" % 待配备.size()
		UITheme.apply_project_font(待配备标题, UITheme.FONT_H2, true)
		待配备标题.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
		_content.add_child(待配备标题)

		for 待 in 待配备:
			var d: Disciple = 待["弟子"]
			var 行 := HBoxContainer.new()
			行.add_theme_constant_override("separation", 12)
			_content.add_child(行)

			var 名label := Label.new()
			名label.text = "%s（%s）" % [d.姓名, 待["需求"]]
			UITheme.apply_project_font(名label, UITheme.FONT_BODY, false)
			名label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
			名label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			行.add_child(名label)

			var 配备btn := Button.new()
			配备btn.text = "自动配备"
			配备btn.custom_minimum_size = Vector2(80, 28)
			UITheme.apply_project_font(配备btn, UITheme.FONT_BODY, false)
			配备btn.pressed.connect(_on_hudao_peibei.bind(d.弟子ID))
			行.add_child(配备btn)

# 护道人操作回调
func _on_hudao_xuyuan(弟子ID: int) -> void:
	if Game == null:
		return
	var 结果: Dictionary = Game.使用护道续缘符(弟子ID)
	UIHint.show_hint(self, "护道续缘", str(结果.get("原因", "")))
	_populate()

func _on_hudao_gongde(弟子ID: int) -> void:
	if Game == null:
		return
	var 结果: Dictionary = Game.使用功德玉牌(弟子ID)
	UIHint.show_hint(self, "功德玉牌", str(结果.get("原因", "")))
	_populate()

func _on_hudao_qiyun(弟子ID: int) -> void:
	if Game == null:
		return
	var 结果: Dictionary = Game.使用气运符箓(弟子ID)
	UIHint.show_hint(self, "气运符箓", str(结果.get("原因", "")))
	_populate()

func _on_hudao_tisi(弟子ID: int) -> void:
	if Game == null:
		return
	var 结果: Dictionary = Game.使用替死玉符(弟子ID)
	UIHint.show_hint(self, "替死玉符", str(结果.get("原因", "")))
	_populate()

func _on_hudao_peibei(弟子ID: int) -> void:
	if Game == null:
		return
	var d: Disciple = Game._按ID找弟子(弟子ID)
	if d == null:
		return
	var 结果: Dictionary = Game.自动配备护道人(d)
	if bool(结果.get("成功", false)):
		UIHint.show_hint(self, "配备护道人", "为%s配备%s【%s】" % [d.姓名, 结果.get("护道人等级", ""), 结果.get("护道人姓名", "")])
	else:
		UIHint.show_hint(self, "配备失败", str(结果.get("原因", "")))
	_populate()

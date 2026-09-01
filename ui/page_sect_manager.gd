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
var _tab_btns: Dictionary = {}
var _管理器: SectManager = null

const TABS = ["概览", "发展路线", "殿阁任命", "弟子任职", "戒律裁决", "弟子请示", "宗主批阅", "核心弟子", "宗门科技", "对外关系", "议事会", "商队管理", "阵营声望", "宗门方针", "奏折决策"]

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
	var bar := HBoxContainer.new()
	bar.name = "HeaderBar"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	var back: Button = UITheme.make_back_button(_on_back_pressed)
	bar.add_child(back)
	var title := Label.new()
	title.text = "宗主管理"
	UITheme.apply_page_title(title)
	bar.add_child(title)
	parent.add_child(bar)

func _build_tabs(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
		"宗门方针":
			_populate_policy()
		"奏折决策":
			_populate_memorial()

func _populate_overview() -> void:
	# 宗门概览
	var card := _make_card("宗门概览")
	var vb := card.get_node("VBox")

	var 路线名 = _管理器.获取发展路线() if _管理器 != null else "均衡发展"
	_add_info_row(vb, "当前发展路线", 路线名)
	_add_info_row(vb, "待裁决违规", str(_管理器.获取待裁决违规().size()) if _管理器 != null else "0")
	_add_info_row(vb, "待回应请示", str(_管理器.获取待回应请示().size()) if _管理器 != null else "0")
	_add_info_row(vb, "待批阅事务", str(_管理器.获取待批阅事务().size()) if _管理器 != null else "0")
	_add_info_row(vb, "核心弟子数", str(_管理器.获取核心弟子列表().size()) if _管理器 != null else "0")
	_add_info_row(vb, "已研究科技", str(_管理器.获取已研究科技().size()) if _管理器 != null else "0")
	_add_info_row(vb, "待决奏折", str(Game.待决奏折.size()) if Game != null else "0")

	_content.add_child(card)

	# 快捷操作提示
	var tip := Label.new()
	tip.text = "提示：点击上方各Tab进入对应管理功能"
	UITheme.apply_aux_text(tip)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(tip)

func _populate_development_route() -> void:
	var card := _make_card("宗门发展路线")
	var vb := card.get_node("VBox")

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
	var vb := card.get_node("VBox")

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
	var vb := card.get_node("VBox")

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
	var vb := card.get_node("VBox")

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
			var 事件vb := 事件卡.get_node("VBox")

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
	var vb := card.get_node("VBox")

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
			var 事件vb := 事件卡.get_node("VBox")

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
	var vb := card.get_node("VBox")

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
			var 事件vb := 事件卡.get_node("VBox")

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
	var vb := card.get_node("VBox")

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
	var vb := card.get_node("VBox")

	var desc := Label.new()
	desc.text = "研究宗门科技，提升全宗实力。（当前为框架，具体科技内容待补充）"
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
	var vb := card.get_node("VBox")

	var desc := Label.new()
	desc.text = "管理与其他宗门的外交关系。（当前为框架，具体宗门待补充）"
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
	var vb := card.get_node("VBox")

	var desc := Label.new()
	desc.text = "召开宗门议事会，与长老们商议宗门大事。（当前为框架，具体议题待补充）"
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
	vb.add_theme_constant_override("margin", UITheme.GRID)
	vb.add_theme_constant_override("separation", UITheme.GRID / 2)
	card.add_child(vb)

	var title := Label.new()
	title.text = 标题
	UITheme.apply_title_font(title)
	vb.add_child(title)

	var sep := HSeparator.new()
	vb.add_child(sep)

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
	var vb := card.get_node("VBox")

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
		for v in Game.商路声望.values():
			总声望 += int(v)
		配额信息.text = "◆ 商队槽位 %d/6（总声望%d）｜今日派遣 %d/%d%s" % [
			Game.商队槽位数(), 总声望, Game.商队每日已派, Game.商队每日配额(), 卡增益
		]
		UITheme.apply_aux_text(配额信息)
		vb.add_child(配额信息)

	# 正在派遣的商队
	var 进行中头 := Label.new()
	进行中头.text = "◆ 进行中的商队"
	UITheme.apply_section_title(进行中头)
	vb.add_child(进行中头)

	if is_instance_valid(Game) and Game.商队列表.size() > 0:
		for 商队 in Game.商队列表:
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
			if li >= 0 and li < Game.灵舟库存.size():
				var 舟 = Game.灵舟库存[li]
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
			仙玉btn.text = "仙玉即时(%d)" % Game.仙玉即时完成费
			UITheme.apply_button_label(仙玉btn, false)
			仙玉btn.custom_minimum_size = Vector2(115, 0)
			仙玉btn.tooltip_text = "消耗%d仙玉立即结算本次贸易" % Game.仙玉即时完成费
			仙玉btn.pressed.connect(_on_仙玉即时完成.bind(int(商队["id"])))
			hb.add_child(仙玉btn)
			vb.add_child(hb)
	else:
		var 空 := Label.new()
		空.text = "尚无进行中的商队"
		UITheme.apply_aux_text(空)
		vb.add_child(空)

	# 可派遣地区
	var 地区头 := Label.new()
	地区头.text = "◆ 可派遣地区"
	UITheme.apply_section_title(地区头)
	vb.add_child(地区头)

	if is_instance_valid(Game):
		for 地区 in Game.商队地区:
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
		if is_instance_valid(Game) and Game.商路声望.size() > 0:
			for 地区 in Game.商队地区:
				var rid = str(地区.get("id", ""))
				var rep = int(Game.商路声望.get(rid, 0))
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

	if is_instance_valid(Game) and Game.商队历史.size() > 0:
		for i in range(min(5, Game.商队历史.size())):
			var 记录 = Game.商队历史[i]
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", UITheme.GRID)
			var 名 := Label.new()
			名.text = "商队#%d" % int(记录["id"])
			名.custom_minimum_size = Vector2(80, 0)
			UITheme.apply_body_text(名)
			hb.add_child(名)
			var 信息 := Label.new()
			信息.text = "%s | %s | 收益:%d灵石" % [
				记录["地区名"], 记录["事件"], int(记录["实际收益"])
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
	if is_instance_valid(Game) and Game.行情事件列表.size() > 0:
		for ev in Game.行情事件列表:
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
		if not Game.灵舟坞建造中.is_empty():
			var 建中 = Game.灵舟坞建造信息()
			var 剩余 = int(建中.get("完成日", 0)) - Game.累计游戏日
			坞信息.text = "建造中：%s（目标等级%d），预计剩余 %d 日" % [
				Game.灵舟坞表.get("sd%02d" % int(建中.get("目标档", 0)), {}).get("dock_name", ""),
				int(建中.get("目标档", 0)), max(0, 剩余)]
		elif Game.已建灵舟坞():
			坞信息.text = "已建成飞舟坞（等级%d），可跨域通商至紫府仙都/北海商港" % Game.灵舟坞等级
		else:
			var 建 = Game.灵舟坞建造信息()
			if 建.get("可建", false):
				var 材料txt = ""
				for m in 建.get("材料", []):
					材料txt += "%s ×%d（有%d）  " % [str(m.get("名", "")), int(m.get("需", 0)), int(m.get("有", 0))]
				坞信息.text = "可建：%s（Lv%d）｜需门派%d级｜工费灵石%d｜历时%d日\n灵材：%s" % [
					str(建.get("名称", "")), int(建.get("等级", 1)), int(建.get("需门派等级", 99)),
					int(建.get("工费", 0)), int(建.get("时日", 0)), 材料txt.strip_edges()]
			else:
				坞信息.text = "暂无可建飞舟坞"
		UITheme.apply_aux_text(坞信息)
		坞信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(坞信息)
		if Game.灵舟坞建造中.is_empty() and not Game.已建灵舟坞():
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
			var 坞 = Game.灵舟坞表.get("sd%02d" % Game.灵舟坞等级, {})
			var 容量 = int(坞.get("max_ship_count", 1))
			var 余量 = 容量 - Game.灵舟库存.size() - Game.灵舟建造队列.size()
			var 容info := Label.new()
			容info.text = "飞舟坞容量 %d／已持%d＋炼制中%d（余%d）" % [容量, Game.灵舟库存.size(), Game.灵舟建造队列.size(), max(0, 余量)]
			UITheme.apply_aux_text(容info)
			vb.add_child(容info)
			for sid in Game.宗门灵舟表.keys():
				var 舟 = Game.宗门灵舟表[sid]
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
					var 中文 = Game.灵材名称表.get(gid, gid)
					var 有 = 0
					for it in Game.仓库:
						if it != null and str(it.get("名称", "")) == 中文:
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
		if Game.灵舟库存.size() > 0:
			var 库头 := Label.new()
			库头.text = "◆ 灵舟库存"
			UITheme.apply_section_title(库头)
			vb.add_child(库头)
			if Game.虚空大阵冷却日 > Game.累计游戏日:
				var 虚注 := Label.new()
				虚注.text = "（破虚神舰·虚空大阵冷却中，剩余 %d 日）" % (Game.虚空大阵冷却日 - Game.累计游戏日)
				UITheme.apply_aux_text(虚注)
				vb.add_child(虚注)
			for i in range(Game.灵舟库存.size()):
				var 舟 = Game.灵舟库存[i]
				var eff = Game.灵舟有效属性(舟)
				var 阵法名: Array = []
				for fid in 舟.get("阵法", []):
					var fm = Game.灵舟阵法表.get(str(fid), null)
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
		elif Game.黑市禁闭日 > 0:
			var 禁 := Label.new()
			禁.text = "正道执法封禁中，剩余 %d 天" % Game.黑市禁闭日
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
				if Game.商路竞争状态.has(cid):
					var s = Game.商路竞争状态[cid]
					状态.text = "对手强度%d｜压价%.0f%%｜%s" % [int(s.get("强度", 0)), float(s.get("压价率", 0)) * 100, str(s.get("策略", ""))]
				else:
					状态.text = "暂无竞争者"
				UITheme.apply_aux_text(状态)
				状态.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hb.add_child(状态)
				vb.add_child(hb)
				if Game.商路竞争状态.has(cid):
					var ahb := HBoxContainer.new()
					ahb.add_theme_constant_override("separation", UITheme.GRID)
					var b1 := Button.new(); b1.text = "价格战(2000)"; b1.custom_minimum_size = Vector2(110, 0); b1.pressed.connect(_on_商路价格战.bind(cid)); ahb.add_child(b1)
					var b2 := Button.new(); b2.text = "打压(5000)"; b2.custom_minimum_size = Vector2(100, 0); b2.pressed.connect(_on_商路打压.bind(cid)); ahb.add_child(b2)
					var b3 := Button.new(); b3.text = "协商(3000)"; b3.custom_minimum_size = Vector2(100, 0); b3.pressed.connect(_on_商路协商.bind(cid)); ahb.add_child(b3)
					vb.add_child(ahb)

	_content.add_child(card)

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
	if 索引 < 0 or 索引 >= Game.灵舟库存.size():
		return
	var 舟 = Game.灵舟库存[索引]
	var 基准 = int(Game.宗门灵舟表.get(str(舟.get("ship_id", "")), {}).get("build_cost", 0))
	Game.拍卖出售灵舟(索引, int(基准 * 0.6))
	_populate()

func _on_刻录灵舟阵法(索引: int) -> void:
	if not is_instance_valid(Game):
		return
	if 索引 < 0 or 索引 >= Game.灵舟库存.size():
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
			return "增战力 +%d" % int(val)
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
	if 索引 < 0 or 索引 >= Game.灵舟库存.size():
		return
	for child in _content.get_children():
		child.queue_free()
	var 舟 = Game.灵舟库存[索引]
	var 舟定义 = Game.宗门灵舟表.get(str(舟.get("ship_id", "")), {})
	var 已刻 = 舟.get("阵法", [])
	var card: PanelContainer = _make_card("刻录阵法 · %s" % str(舟.get("名称", "")))
	var vb: VBoxContainer = card.get_node("VBox")

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
	堂注.text = "当前阵法堂司职等级：%d" % 阵法堂等级
	UITheme.apply_aux_text(堂注)
	vb.add_child(堂注)

	var 可刻列表: Array = []
	for fid in Game.灵舟阵法表.keys():
		var fm = Game.灵舟阵法表[fid]
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
			空.text = "暂无可刻阵法（受阵法堂等级或灵舟特性限制）"
		UITheme.apply_aux_text(空)
		vb.add_child(空)
	else:
		for fid in 可刻列表:
			var fm = Game.灵舟阵法表[fid]
			var 行: HBoxContainer = HBoxContainer.new()
			行.add_theme_constant_override("separation", UITheme.GRID)
			var 信息: Label = Label.new()
			信息.text = "%s（%s·T%d）%s｜耗灵石%d＋灵材:%s｜需阵法堂%d级" % [
				str(fm.get("name", fid)), str(fm.get("category", "")), int(fm.get("tier", 1)),
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
	if 索引 < 0 or 索引 >= Game.灵舟库存.size():
		return
	_show_ship_rename_panel(索引)

# §11.15 阶段三·灵舟：重命名面板（展示机会余量 + 输入新名）
func _show_ship_rename_panel(索引: int) -> void:
	if not is_instance_valid(Game):
		return
	if 索引 < 0 or 索引 >= Game.灵舟库存.size():
		return
	for child in _content.get_children():
		child.queue_free()
	var 舟 = Game.灵舟库存[索引]
	var 余 = int(舟.get("可命名次数", 1))
	var card: PanelContainer = _make_card("灵舟命名 · %s" % str(舟.get("名称", "")))
	var vb: VBoxContainer = card.get_node("VBox")
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
	for d in Game.商队地区:
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

	var card: PanelContainer = _make_card("派遣商队 · %s" % 地区["名称"])
	var vb: VBoxContainer = card.get_node("VBox")

	# —— 行情看板 ——
	var 行情: Label = Label.new()
	行情.text = "当前收购价 %.1fx ｜ 风险 %.0f%% ｜ 偏好品类：%s" % [
		float(地区.get("当前收购价", 地区["收购价"])),
		float(地区["风险"]) * 100,
		"、".join(地区.get("偏好类别", []))
	]
	UITheme.apply_value_text(行情)
	vb.add_child(行情)
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
			标签.text = "%s（%s·%s） 单价%d ×%d" % [名, 批["item"].品阶, 批["item"].类别, 单价, int(批["count"])]
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
	if Game.商队载具表.size() > 0:
		for vid in Game.商队载具表.keys():
			var 载: Dictionary = Game.商队载具表[vid]
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
	if Game.灵舟库存.size() > 0:
		for si in range(Game.灵舟库存.size()):
			var s舟 = Game.灵舟库存[si]
			var 核心状 = str(s舟.get("核心状态", "正常"))
			var 枯竭标 = "（枯竭!）" if 核心状 == "枯竭" else ""
			var 瞬标 = "【虚空】" if "sf07" in s舟.get("阵法", []) else ""
			if 核心状 != "枯竭":
				舟选.add_item("%s%s T%d｜降险%.0f%%｜提速%.0f%% %s" % [瞬标, str(s舟.get("名称", "")), int(s舟.get("tier", 0)), float(s舟.get("risk_reduce", 0)) * 100, float(s舟.get("speed_bonus", 0)) * 100, 枯竭标], _派遣可用灵舟.size() + 1)
				_派遣可用灵舟.append(si)
	舟选.item_selected.connect(_刷新运力提示)
	_派遣灵舟选 = 舟选
	vb.add_child(舟选)

	# —— 人员编组 ——
	var 人: Label = Label.new()
	人.text = "◆ 人员编组（掌柜智谋→价差 / 护卫战力→抗风险 / 脚夫→运力）"
	UITheme.apply_section_title(人)
	vb.add_child(人)
	for pid in ["p001", "p002", "p003"]:
		if not Game.商队岗位表.has(pid):
			continue
		var 岗: Dictionary = Game.商队岗位表[pid]
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
				选.add_item("%s（%s·战力%d·道心%d）" % [d.姓名, d.境界, int(d.战力), int(d.道心)], int(d.弟子ID))
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
	var 有符 = Game._仓库灵材数量(Game.神行符名) if (Game != null and Game.has_method("_仓库灵材数量")) else 0
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
		if did != 0 and Game.商队岗位表.has(pid):
			运力 += int(Game.商队岗位表[pid].get("carry_capacity", 0))
	# 载具运力
	var vidx: int = 0
	if _派遣载具选 != null:
		vidx = _派遣载具选.get_selected_id()
	if vidx > 0 and (vidx - 1) < _派遣可用载具.size():
		var vid: String = _派遣可用载具[vidx - 1]
		if Game.商队载具表.has(vid):
			运力 += int(Game.商队载具表[vid].get("base_carry", 0))
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
		_派遣运力提示.text = "运力 %d ｜ 货值 %d ｜ 可派遣" % [运力, 货值]

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
	var 结果: Dictionary = Game.派遣商队(地区ID, 货物, 宗主ID, 载具ID, 人员, 灵舟索引, 使用符)
	UIHint.show_hint(self, "商队派遣", str(结果.get("消息", "派遣成功")))
	if 结果.get("成功", false):
		refresh()

# §11.15 优化：仙玉即时完成贸易——消耗仙玉立即结算指定商队
func _on_仙玉即时完成(商队ID: int) -> void:
	if not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.仙玉即时完成贸易(商队ID)
	UIHint.show_hint(self, "仙玉催行", str(结果.get("消息", "")))
	if 结果.get("成功", false):
		refresh()

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
	var vb := card.get_node("VBox")

	var desc := Label.new()
	desc.text = "与各大阵营建立关系，提升声望可获得专属权益。正道与魔道对立，提升一方会降低另一方。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	if is_instance_valid(Game):
		for 阵营 in Game.阵营列表:
			var 声望值 = Game.阵营声望.get(阵营, 0)
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
	说明头.text = "◆ 声望等级"
	UITheme.apply_section_title(说明头)
	vb.add_child(说明头)

	var 等级说明 := Label.new()
	等级说明.text = "冷淡(0) → 中立(100) → 友善(500) → 尊敬(2000) → 崇敬(5000)"
	UITheme.apply_aux_text(等级说明)
	等级说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(等级说明)

	_content.add_child(card)

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
	值标.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
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
	var vb := card.get_node("VBox")
	
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
	var vb := card.get_node("VBox")
	
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
		内.add_theme_constant_override("margin", UITheme.GRID)
		内.add_theme_constant_override("separation", UITheme.GRID / 2)
		案.add_child(内)
		
		var 头 := HBoxContainer.new()
		头.add_theme_constant_override("separation", UITheme.GRID)
		var 重大 := str(折.get("重大性", "普通"))
		var 标签 := Label.new()
		标签.text = "【" + 重大 + "】"
		UITheme.apply_section_title(标签)
		var 色: Color = UITheme.C01_TEXT_GOLD
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
				钮.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
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
				预.text = "↳ " + 预览
				UITheme.apply_aux_text(预)
				预.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
				预.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				预.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				行.add_child(预)
			内.add_child(行)
		序 += 1
		
		vb.add_child(案)
	
	_content.add_child(card)

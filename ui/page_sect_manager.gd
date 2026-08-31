## 宗主管理系统页面
## 整合宗门的各种管理功能：发展路线、殿阁任命、弟子任职、戒律裁决、请示回应、批阅、科技、外交、议事会等

extends Control

signal 返回主页

const SectManager := preload("res://sect_manager.gd")

var _built: bool = false
var _current_tab: String = "概览"
var _body: VBoxContainer
var _content: VBoxContainer
var _tab_btns: Dictionary = {}
var _管理器: SectManager = null

const TABS = ["概览", "发展路线", "殿阁任命", "弟子任职", "戒律裁决", "弟子请示", "宗主批阅", "核心弟子", "宗门科技", "对外关系", "议事会", "商队管理", "阵营声望"]

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

	var desc := Label.new()
	desc.text = "派遣商队前往各地贸易，低买高卖赚取灵石。商队途中可能遭遇风险或偶遇高人。"
	UITheme.apply_body_text(desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

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
			信息.text = "%s | 出发:%d日 | 预计返回:%d日 | 货物价值:%d" % [
				商队["地区名"], int(商队["出发日"]), int(商队["预计返回日"]), int(商队["货物价值"])
			]
			UITheme.apply_aux_text(信息)
			信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(信息)
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
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", UITheme.GRID)
			var 名 := Label.new()
			名.text = 地区["名称"]
			名.custom_minimum_size = Vector2(100, 0)
			UITheme.apply_body_text(名)
			hb.add_child(名)
			var 信息 := Label.new()
			信息.text = "距离:%d日 | 收购价:%.1fx | 风险:%.0f%% | 特产:%s" % [
				int(地区["距离"]), float(地区["收购价"]), float(地区["风险"]) * 100, 地区["特产"]
			]
			UITheme.apply_aux_text(信息)
			信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(信息)
			var btn := Button.new()
			btn.text = "派遣"
			btn.custom_minimum_size = Vector2(80, 0)
			btn.pressed.connect(_on_派遣商队.bind(地区["id"]))
			hb.add_child(btn)
			vb.add_child(hb)

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

	_content.add_child(card)

func _on_派遣商队(地区ID: String) -> void:
	if not is_instance_valid(Game):
		return
	# 弹出货物选择对话框
	_弹出货物选择(地区ID)

func _弹出货物选择(地区ID: String) -> void:
	# 简化：使用几种预设的货物组合
	var 货物选项: Array = [
		{"名称": "小额贸易", "描述": "灵草×10，价值100灵石", "货物": [{"名称": "灵草", "价值": 100, "数量": 10}], "启动资金": 10},
		{"名称": "中额贸易", "描述": "灵草×50+矿石×30，价值800灵石", "货物": [{"名称": "灵草", "价值": 500, "数量": 50}, {"名称": "矿石", "价值": 300, "数量": 30}], "启动资金": 80},
		{"名称": "大额贸易", "描述": "矿石×100+法器×10，价值3000灵石", "货物": [{"名称": "矿石", "价值": 1000, "数量": 100}, {"名称": "法器", "价值": 2000, "数量": 10}], "启动资金": 300},
		{"名称": "巨额贸易", "描述": "法器×50+天材地宝×5，价值10000灵石", "货物": [{"名称": "法器", "价值": 5000, "数量": 50}, {"名称": "天材地宝", "价值": 5000, "数量": 5}], "启动资金": 1000},
	]
	# 简化：直接使用中额贸易
	var 选择 = 货物选项[1]
	if Game.灵石 < 选择["启动资金"]:
		UIHint.show_hint(self, "商队派遣", "灵石匮乏，需要启动资金%d灵石" % 选择["启动资金"])
		return
	var 结果 = Game.派遣商队(地区ID, 选择["货物"])
	UIHint.show_hint(self, "商队派遣", str(结果.get("消息", "派遣成功")))
	refresh()

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



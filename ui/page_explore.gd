extends Control

## 历练派遣页面（底部Tab「历练」）
## 关卡列表（日常/境界/秘境分类）、派遣界面、结算展示

signal 领取日常请求(序号: int)
signal 领取周常请求()
signal 返回请求()
signal 弟子详情请求(弟子ID: int)

var _built: bool = false
var _current_tab: String = "daily"
var _selected_stage: String = ""
var _selected_disciples: Array = []
var _current_preset: String = ""  # 当前选择的队伍预设名
var _selected_route: String = "稳妥"  # 当前选择的历练路线（稳妥/冒险/神秘）
var _preset_option: OptionButton = null  # 队伍预设下拉选择
var _stage_list_vbox: VBoxContainer = null
var _detail_content: VBoxContainer = null
var _disciple_selector: VBoxContainer = null

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
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(vbox)

	_build_header(vbox)
	_build_tabs(vbox)
	_build_main_area(vbox)

func _build_header(parent: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	parent.add_child(hb)

	var title := Label.new()
	title.text = "历练派遣"
	UITheme.apply_title_font(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(title)

	# P0修复：显示今日机缘
	var 机缘label := Label.new()
	机缘label.name = "JiyuanLabel"
	if is_instance_valid(Game):
		var 检查: Dictionary = Game.检查机缘("探秘境缘")
		var VIP等级: int = Game.当前VIP等级()
		机缘label.text = "机缘：%d/%d（VIP%d）" % [检查.get("剩余", 0), 检查.get("上限", 0), VIP等级]
	UITheme.apply_aux_font(机缘label)
	机缘label.custom_minimum_size = Vector2(200, 0)
	hb.add_child(机缘label)

	# S1-4 付费：仙玉购买历练额外次数
	var 历练btn := Button.new()
	历练btn.name = "PayExpeditionBtn"
	历练btn.text = "购买历练次数"
	if is_instance_valid(Game):
		历练btn.text = "购买历练次数（%d仙玉）" % Game.付费单价.get("历练额外", 15)
	历练btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	历练btn.pressed.connect(_on_付费_历练)
	hb.add_child(历练btn)

func _build_tabs(parent: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	parent.add_child(hb)

	var tabs = [
		{"key": "daily", "name": "日常历练"},
		{"key": "realm", "name": "境界关卡"},
		{"key": "secret", "name": "秘境探索"},
		{"key": "challenge", "name": "秘境挑战"},
		{"key": "investigate", "name": "调查任务"},
		{"key": "history", "name": "历练史册"},
	]
	for t in tabs:
		var btn := Button.new()
		btn.text = t["name"]
		btn.custom_minimum_size = Vector2(0, UITheme.GRID * 3)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key = t["key"]
		btn.pressed.connect(func(): _switch_tab(key))
		hb.add_child(btn)
		btn.name = "Tab_" + key

func _switch_tab(tab: String) -> void:
	_current_tab = tab
	_selected_stage = ""
	_selected_disciples.clear()
	_refresh_tab_highlight()
	if tab != "history":
		_refresh_stage_list()
	_refresh_detail()

func _refresh_tab_highlight() -> void:
	for child in get_children():
		if child is VBoxContainer:
			for c2 in child.get_children():
				if c2 is HBoxContainer:
					for btn in c2.get_children():
						if btn is Button and btn.name.begins_with("Tab_"):
							var key = btn.name.replace("Tab_", "")
							if key == _current_tab:
								btn.modulate = UITheme.C01_TEXT_JADE
							else:
								btn.modulate = Color(1, 1, 1)

func _build_main_area(parent: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(hb)

	# 左侧：关卡列表
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.custom_minimum_size = Vector2(UITheme.GRID * 18, 0)
	hb.add_child(left_panel)

	var left_vb := VBoxContainer.new()
	left_vb.add_theme_constant_override("margin", UITheme.GRID)
	left_vb.add_theme_constant_override("separation", UITheme.GRID)
	left_panel.add_child(left_vb)

	var list_title := Label.new()
	list_title.text = "关卡列表"
	list_title.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	list_title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	left_vb.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vb.add_child(scroll)

	_stage_list_vbox = VBoxContainer.new()
	_stage_list_vbox.add_theme_constant_override("separation", UITheme.GRID)
	_stage_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stage_list_vbox)

	# 右侧：关卡详情 + 派遣
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.custom_minimum_size = Vector2(UITheme.GRID * 22, 0)
	hb.add_child(right_panel)

	_detail_content = VBoxContainer.new()
	_detail_content.add_theme_constant_override("margin", UITheme.GRID)
	_detail_content.add_theme_constant_override("separation", UITheme.GRID)
	right_panel.add_child(_detail_content)

func _refresh_stage_list() -> void:
	if _stage_list_vbox == null:
		return
	for child in _stage_list_vbox.get_children():
		child.queue_free()

	if _current_tab == "challenge":
		_刷新秘境挑战列表()
		return

	if _current_tab == "investigate":
		_刷新调查列表()
		return

	var stages: Array = []
	match _current_tab:
		"daily": stages = ExpeditionSystem.获取日常关卡()
		"realm": stages = ExpeditionSystem.获取境界关卡()
		"secret": stages = ExpeditionSystem.获取秘境关卡()

	var 最高境界 = "练气"
	if Game != null:
		var 弟子列表1 = Game.get("弟子列表")
		if 弟子列表1 != null:
			for d in 弟子列表1:
				var 境界 = str(d.境界) if d != null else "练气"
				if _境界序(境界) > _境界序(最高境界):
					最高境界 = 境界

	for sid in stages:
		var 关卡 = ExpeditionSystem.获取关卡(sid)
		if 关卡.is_empty():
			continue
		if not ExpeditionSystem._境界达标(最高境界, 关卡["解锁境界"]):
			continue
		var btn := Button.new()
		btn.text = "%s\n推荐：%d | %d日 | %s" % [
			关卡["名称"], 关卡["推荐战力"], 关卡["预计时长"],
			"★".repeat(int(关卡["难度"]))
		]
		btn.custom_minimum_size = Vector2(0, UITheme.GRID * 5)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		var 已完成 = false
		if _current_tab == "daily" and ExpeditionSystem.已完成日常.has(sid):
			已完成 = true
		elif _current_tab == "secret" and ExpeditionSystem.已完成秘境.has(sid):
			已完成 = true
		if 已完成:
			btn.modulate = Color(0.6, 0.6, 0.6)
			btn.text += "\n（已完成）"
		var stage_id = sid
		btn.pressed.connect(func(): _select_stage(stage_id))
		_stage_list_vbox.add_child(btn)

func _境界序(境界: String) -> int:
	return Disciple.境界索引(境界)   # 唯一真源（2026-09-02）

func _select_stage(stage_id: String) -> void:
	_selected_stage = stage_id
	_selected_disciples.clear()
	_refresh_detail()

func _刷新调查列表() -> void:
	if _stage_list_vbox == null or _detail_content == null:
		return
	for child in _stage_list_vbox.get_children():
		child.queue_free()
	for child in _detail_content.get_children():
		child.queue_free()

	var 任务 = (ExpeditionSystem.获取调查任务列表() if ExpeditionSystem != null else {})
	# 左：任务列表
	if 任务.is_empty():
		var empty := Label.new()
		empty.text = "宗门安宁，暂无弟子失踪。"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		UITheme.apply_body_font(empty)
		_stage_list_vbox.add_child(empty)
	else:
		for tid in 任务.keys():
			_stage_list_vbox.add_child(_make_investigate_card(tid, 任务[tid]))

	# 右：进行中 + 说明
	var 进行中 = (ExpeditionSystem.获取调查进行中() if ExpeditionSystem != null else {})
	var title := Label.new()
	title.text = "调查进行中（%d）" % 进行中.size()
	title.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_detail_content.add_child(title)
	if 进行中.is_empty():
		var none := Label.new()
		none.text = "暂无进行中的调查。"
		UITheme.apply_aux_font(none)
		_detail_content.add_child(none)
	else:
		for iid in 进行中.keys():
			var inst = 进行中[iid]
			var 失踪名 = str(inst.get("任务", {}).get("失踪弟子名", "失踪弟子"))
			var lbl := Label.new()
			lbl.text = "· %s 的调查：%d 名高阶弟子前往（预计第 %d 日回禀）" % [失踪名, inst.get("接取弟子ID列表", []).size(), int(inst.get("预计结束游戏日", 0))]
			UITheme.apply_aux_font(lbl)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detail_content.add_child(lbl)

	var tip := Label.new()
	tip.text = "低阶弟子历练失败可能失踪，宗门自动下发调查任务；仅修为高于失踪者的弟子可接取。调查成功将按关卡难度判定生还或陨落（高风险常客死）。任务具因果联动：寻回后派生【追查真凶】、再派生【肃清秘境】；调查无果则升级【悬赏通缉】。弟子生死可于『弟子』页卡片的命魂灯，或详情页「命牌」查看。"
	tip.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(tip)

func _make_investigate_card(tid: String, t: Dictionary) -> Control:
	var panel := PanelContainer.new()
	UITheme.apply_panel_style(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	var 链名表 := {"失踪": "失踪调查", "追凶": "追查真凶", "通缉": "悬赏通缉", "肃清": "肃清秘境"}
	var 链 = str(t.get("链", "失踪"))
	name_lbl.text = "【%s】%s" % [链名表.get(链, "调查"), t.get("失踪弟子名", "")]
	UITheme.apply_body_font(name_lbl)
	vbox.add_child(name_lbl)

	var info := Label.new()
	var 链序 = int(t.get("链序", 1))
	var 前驱 = str(t.get("前驱任务ID", ""))
	var 链文本 = "｜链 %d/%d" % [链序, 3]
	if 前驱 != "":
		链文本 += "（源自 %s）" % 前驱
	info.text = "失踪于【%s】｜要求境界：%s（须更高阶）｜难度 %d%s" % [t.get("失踪关卡名", ""), t.get("失踪弟子境界", ""), int(t.get("难度", 1)), 链文本]
	UITheme.apply_aux_font(info)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var 可接取 = (ExpeditionSystem.获取可接取弟子(tid) if ExpeditionSystem != null else [])
	if 可接取.is_empty():
		var no := Label.new()
		no.text = "（暂无修为足够的高阶弟子可派）"
		UITheme.apply_aux_font(no)
		vbox.add_child(no)
		return panel

	var opt := OptionButton.new()
	opt.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
	opt.add_item("选择高阶弟子…", -1)
	for e in 可接取:
		opt.add_item("%s（%s·%d层）" % [e["姓名"], e["境界"], int(e["层数"])], e["id"])
	vbox.add_child(opt)

	var btn := Button.new()
	btn.text = "派出调查"
	btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	btn.pressed.connect(func():
		var did = opt.get_selected_id()
		if did < 0:
			return
		if ExpeditionSystem != null:
			ExpeditionSystem.开始调查(tid, [did])
		_刷新调查列表()
	)
	vbox.add_child(btn)
	return panel

func _refresh_detail() -> void:
	if _detail_content == null:
		return
	for child in _detail_content.get_children():
		child.queue_free()

	# 历练史册标签页
	if _current_tab == "history":
		_刷新历练史册()
		return

	if _selected_stage == "":
		var hint := Label.new()
		hint.text = "请从左侧择一关卡"
		hint.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		hint.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_detail_content.add_child(hint)
		return

	if _current_tab == "challenge":
		_刷新秘境挑战详情()
		return

	var 关卡 = ExpeditionSystem.获取关卡(_selected_stage)
	if 关卡.is_empty():
		return

	var name_lbl := Label.new()
	name_lbl.text = 关卡["名称"]
	name_lbl.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	name_lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_detail_content.add_child(name_lbl)

	var info := Label.new()
	info.text = "推荐战力：%d | 时长：%d日 | 难度：%s\n解锁：%s\n%s" % [
		关卡["推荐战力"], 关卡["预计时长"],
		"★".repeat(int(关卡["难度"])), 关卡["解锁境界"], 关卡["描述"]
	]
	info.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	info.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(info)

	var sep := HSeparator.new()
	_detail_content.add_child(sep)

	var select_hbox := HBoxContainer.new()
	select_hbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	_detail_content.add_child(select_hbox)

	var select_title := Label.new()
	select_title.text = "选择派遣弟子（1-3人，已选%d人）" % _selected_disciples.size()
	select_title.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	select_title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	select_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_hbox.add_child(select_title)

	var auto_btn := Button.new()
	auto_btn.text = "尽数派遣"
	auto_btn.custom_minimum_size = Vector2(UITheme.GRID * 4, 0)
	auto_btn.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	auto_btn.pressed.connect(_auto_select_disciples)
	select_hbox.add_child(auto_btn)

	# 队伍预设行（第二行，避免宽度溢出）
	var preset_hbox := HBoxContainer.new()
	preset_hbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	_detail_content.add_child(preset_hbox)

	var preset_label := Label.new()
	preset_label.text = "队伍预设："
	preset_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	preset_label.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	preset_hbox.add_child(preset_label)

	# 队伍预设下拉选择
	_preset_option = OptionButton.new()
	_preset_option.custom_minimum_size = Vector2(UITheme.GRID * 5, 0)
	_preset_option.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	_preset_option.add_item("选择预设", 0)
	if SectManager != null:
		var 预设列表 = SectManager.获取队伍预设列表()
		var idx = 1
		for 预设名 in 预设列表.keys():
			_preset_option.add_item(预设名, idx)
			idx += 1
	_preset_option.item_selected.connect(_on_preset_selected)
	preset_hbox.add_child(_preset_option)

	# 应用预设按钮
	var apply_btn := Button.new()
	apply_btn.text = "应用"
	apply_btn.custom_minimum_size = Vector2(UITheme.GRID * 2, 0)
	apply_btn.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	apply_btn.pressed.connect(_apply_current_preset)
	preset_hbox.add_child(apply_btn)

	# 保存预设按钮
	var save_btn := Button.new()
	save_btn.text = "录册"
	save_btn.custom_minimum_size = Vector2(UITheme.GRID * 2, 0)
	save_btn.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	save_btn.pressed.connect(_save_current_preset)
	preset_hbox.add_child(save_btn)

	var disciple_scroll := ScrollContainer.new()
	disciple_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	disciple_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_content.add_child(disciple_scroll)

	_disciple_selector = VBoxContainer.new()
	_disciple_selector.add_theme_constant_override("separation", UITheme.GRID / 2)
	_disciple_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	disciple_scroll.add_child(_disciple_selector)

	if Game != null:
		var 弟子列表2 = Game.get("弟子列表")
		if 弟子列表2 != null:
			for d in 弟子列表2:
				var did = int(d.弟子ID)
				if did < 0:
					continue
				var 在历练 = false
				for 实例ID in ExpeditionSystem.进行中历练.keys():
					var 实例 = ExpeditionSystem.进行中历练[实例ID]
					if 实例["弟子ID列表"].has(did):
						在历练 = true
						break
				var btn := Button.new()
				btn.text = "%s | %s | 战%d | 心%d | 道%d | 魔%d%s" % [
					str(d.姓名), str(d.境界),
					int(d.战力), int(d.心境),
					int(d.道心), int(d.心魔值),
					"（历练中）" if 在历练 else ""
				]
				btn.custom_minimum_size = Vector2(0, UITheme.GRID * 3)
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
				btn.disabled = 在历练
				if _selected_disciples.has(did):
					btn.modulate = UITheme.C01_TEXT_JADE
				var disciple_id = did
				btn.pressed.connect(func(): _toggle_disciple(disciple_id))
				_disciple_selector.add_child(btn)

	var sep2 := HSeparator.new()
	_detail_content.add_child(sep2)

	var 总战力 = 0
	for did in _selected_disciples:
		var d = _get_disciple(did)
		if d != null:
			总战力 += int(d.战力)
	var 战力比 = float(总战力) / float(关卡["推荐战力"]) if 关卡["推荐战力"] > 0 else 0
	var 预估成功率 = clamp(战力比 / float(关卡["难度"]), 0.05, 0.95) * 100

	var preview := Label.new()
	preview.text = "总战力：%d / 推荐：%d（%.0f%%）\n预估成功率：%.0f%%\n耗时：%d日" % [
		总战力, 关卡["推荐战力"], 战力比 * 100, 预估成功率, 关卡["预计时长"]
	]
	preview.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	preview.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	_detail_content.add_child(preview)

	# ===== 历练路线选择（P0-1新增）=====
	var route_sep := HSeparator.new()
	_detail_content.add_child(route_sep)

	var route_title := Label.new()
	route_title.text = "选择历练路线"
	route_title.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	route_title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_detail_content.add_child(route_title)

	var 可用路线: Array = ExpeditionSystem.获取关卡可用路线(_selected_stage)
	var route_hbox := HBoxContainer.new()
	route_hbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	_detail_content.add_child(route_hbox)

	for route_key in 可用路线:
		var 路线配置: Dictionary = ExpeditionSystem.历练路线配置.get(route_key, {})
		var route_btn := Button.new()
		var 成功率加成: float = float(路线配置.get("成功率加成", 0))
		var 奖励倍率: float = float(路线配置.get("奖励倍率", 1.0))
		var 奇遇概率: float = float(路线配置.get("奇遇概率", 0.05))
		route_btn.text = "%s\n成功率%+.0f%% | 奖励%.1fx | 奇遇%.0f%%" % [
			str(路线配置.get("名称", route_key)),
			成功率加成 * 100, 奖励倍率, 奇遇概率 * 100
		]
		route_btn.custom_minimum_size = Vector2(0, UITheme.GRID * 4)
		route_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		route_btn.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
		if _selected_route == route_key:
			route_btn.modulate = UITheme.C01_TEXT_JADE
		var rk = route_key
		route_btn.pressed.connect(func():
			_selected_route = rk
			_refresh_detail()
		)
		route_hbox.add_child(route_btn)

	var route_desc := Label.new()
	var 当前路线配置: Dictionary = ExpeditionSystem.历练路线配置.get(_selected_route, {})
	route_desc.text = str(当前路线配置.get("描述", ""))
	route_desc.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
	route_desc.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	route_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(route_desc)

	var dispatch_btn := Button.new()
	dispatch_btn.text = "开始历练（%s）" % str(当前路线配置.get("名称", _selected_route))
	dispatch_btn.custom_minimum_size = Vector2(0, UITheme.GRID * 4)
	dispatch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dispatch_btn.disabled = _selected_disciples.is_empty() or _selected_disciples.size() > 3
	dispatch_btn.pressed.connect(_on_dispatch_pressed)
	_detail_content.add_child(dispatch_btn)

	var 进行中 = ExpeditionSystem.获取进行中历练()
	if not 进行中.is_empty():
		var sep3 := HSeparator.new()
		_detail_content.add_child(sep3)
		var ongoing_title := Label.new()
		ongoing_title.text = "进行中（%d）" % 进行中.size()
		ongoing_title.add_theme_font_size_override("font_size", UITheme.FONT_H2)
		ongoing_title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
		_detail_content.add_child(ongoing_title)
		for 实例ID in 进行中.keys():
			var 实例 = 进行中[实例ID]
			var 关卡2 = ExpeditionSystem.获取关卡(实例["关卡ID"])
			# P0-1: 使用获取历练进度获取完整信息
			var 进度信息: Dictionary = ExpeditionSystem.获取历练进度(实例ID)
			var 进度: float = float(进度信息.get("进度", 0.0))
			var 路线: String = str(进度信息.get("路线", "稳妥"))
			var 路线名称: String = str(进度信息.get("路线名称", 路线))
			var 剩余: int = int(进度信息.get("剩余天数", 0))
			var 可决策: bool = bool(进度信息.get("可决策", false))
			var 奇遇记录: Array = 进度信息.get("奇遇记录", [])

			# 历练卡片
			var card_panel := PanelContainer.new()
			UITheme.apply_panel_style(card_panel)
			_detail_content.add_child(card_panel)
			var card_vb := VBoxContainer.new()
			card_vb.add_theme_constant_override("margin", UITheme.GRID)
			card_vb.add_theme_constant_override("separation", UITheme.GRID / 2)
			card_panel.add_child(card_vb)

			# 关卡名 + 路线
			var name_row := HBoxContainer.new()
			name_row.add_theme_constant_override("separation", UITheme.GRID)
			card_vb.add_child(name_row)
			var ongoing_name_lbl := Label.new()
			ongoing_name_lbl.text = "%s" % 关卡2.get("名称", "")
			ongoing_name_lbl.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			ongoing_name_lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
			ongoing_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_row.add_child(ongoing_name_lbl)
			var route_lbl := Label.new()
			route_lbl.text = "【%s】" % 路线名称
			route_lbl.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
			route_lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
			name_row.add_child(route_lbl)

			# 进度条
			var progress_bar := ProgressBar.new()
			progress_bar.max_value = 100
			progress_bar.value = 进度 * 100
			progress_bar.show_percentage = true
			progress_bar.custom_minimum_size = Vector2(0, UITheme.GRID * 1.5)
			progress_bar.tint_progress = UITheme.C01_TEXT_JADE
			card_vb.add_child(progress_bar)

			# 进度信息
			var info_lbl := Label.new()
			info_lbl.text = "进度：%.0f%% | 剩余%d日 | 奇遇%d次" % [进度 * 100, max(0, 剩余), 奇遇记录.size()]
			info_lbl.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
			info_lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_SECONDARY)
			card_vb.add_child(info_lbl)

			# 待处理奇遇提示
			var 待处理奇遇: Array = ExpeditionSystem.获取待处理奇遇(实例ID)
			if 待处理奇遇.size() > 0:
				var 待处理_btn := Button.new()
				var 待处理奇遇名: String = str(待处理奇遇[0].get("奇遇", {}).get("名称", "奇遇"))
				待处理_btn.text = "✦ 待处理奇遇：%s（点击处理）✦" % 待处理奇遇名
				待处理_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
				待处理_btn.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
				待处理_btn.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
				待处理_btn.modulate = UITheme.C01_TEXT_GOLD
				var iid3 = 实例ID
				待处理_btn.pressed.connect(func():
					_弹出奇遇弹窗(iid3, 0)
				)
				card_vb.add_child(待处理_btn)

			# 奇遇记录展示
			if 奇遇记录.size() > 0:
				var 奇遇_title := Label.new()
				奇遇_title.text = "  奇遇记录："
				奇遇_title.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
				奇遇_title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
				card_vb.add_child(奇遇_title)
				for 奇遇 in 奇遇记录:
					var 奇遇_lbl := Label.new()
					奇遇_lbl.text = "    · %s" % str(奇遇.get("纪事", ""))
					奇遇_lbl.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
					奇遇_lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
					奇遇_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					card_vb.add_child(奇遇_lbl)

			# 风险决策按钮（进度30%-100%时可选择）
			if 可决策 and not bool(实例.get("提前结束", false)) and not bool(实例.get("继续深入", false)):
				var decision_row := HBoxContainer.new()
				decision_row.add_theme_constant_override("separation", UITheme.GRID / 2)
				card_vb.add_child(decision_row)
				var 收功_btn := Button.new()
				收功_btn.text = "见好就收"
				收功_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
				收功_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				收功_btn.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
				var iid1 = 实例ID
				收功_btn.pressed.connect(func():
					var 结果 = ExpeditionSystem.历练风险决策(iid1, "见好就收")
					if UIHint != null and UIHint.has_method("show_hint"):
						UIHint.show_hint(null, "历练决策", str(结果.get("说明", "")))
					_refresh_detail()
				)
				decision_row.add_child(收功_btn)
				var 深入_btn := Button.new()
				深入_btn.text = "继续深入"
				深入_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
				深入_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				深入_btn.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
				var iid2 = 实例ID
				深入_btn.pressed.connect(func():
					var 结果 = ExpeditionSystem.历练风险决策(iid2, "继续深入")
					if UIHint != null and UIHint.has_method("show_hint"):
						UIHint.show_hint(null, "历练决策", str(结果.get("说明", "")))
					_refresh_detail()
				)
				decision_row.add_child(深入_btn)

			# 已决策状态显示
			if bool(实例.get("提前结束", false)):
				var 决策_lbl := Label.new()
				决策_lbl.text = "  已决策：见好就收（奖励倍率%.0f%%）" % (float(实例.get("提前结束倍率", 0.5)) * 100)
				决策_lbl.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
				决策_lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_JADE)
				card_vb.add_child(决策_lbl)
			elif bool(实例.get("继续深入", false)):
				var 决策_lbl := Label.new()
				决策_lbl.text = "  已决策：继续深入（风险增加%.0f%%）" % (float(实例.get("风险增加", 0.1)) * 100)
				决策_lbl.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
				决策_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_RED)
				card_vb.add_child(决策_lbl)

func _toggle_disciple(did: int) -> void:
	if _selected_disciples.has(did):
		_selected_disciples.erase(did)
	else:
		if _selected_disciples.size() >= 3:
			return
		_selected_disciples.append(did)
	_refresh_detail()

func _auto_select_disciples() -> void:
	# 尽数派遣：自动选择战力最高的1-3个可用弟子
	if Game == null:
		return
	var 弟子列表 = Game.get("弟子列表")
	if 弟子列表 == null:
		return
	# 收集可用弟子（不在历练中），按战力降序排序
	var 可用弟子: Array = []
	for d in 弟子列表:
		var did = int(d.弟子ID)
		if did < 0:
			continue
		# 检查是否在历练中
		var 在历练 = false
		for 实例ID in ExpeditionSystem.进行中历练.keys():
			var 实例 = ExpeditionSystem.进行中历练[实例ID]
			if 实例["弟子ID列表"].has(did):
				在历练 = true
				break
		if not 在历练:
			可用弟子.append({"id": did, "战力": int(d.战力)})
	# 按战力降序排序
	可用弟子.sort_custom(func(a, b): return a["战力"] > b["战力"])
	# 选择前3个
	_selected_disciples.clear()
	for i in range(min(3, 可用弟子.size())):
		_selected_disciples.append(可用弟子[i]["id"])
	_refresh_detail()

func _get_disciple(did: int):
	if Game == null:
		return null
	var 弟子列表3 = Game.get("弟子列表")
	if 弟子列表3 == null:
		return null
	for d in 弟子列表3:
		if int(d.弟子ID) == did:
			return d
	return null

func _on_dispatch_pressed() -> void:
	if _selected_stage == "" or _selected_disciples.is_empty():
		return
	# P0-1: 使用增强版开始历练，带路线选择
	var 结果 = ExpeditionSystem.开始历练增强(_selected_stage, _selected_disciples, _selected_route)
	if 结果.get("成功", false):
		if UIHint != null and UIHint.has_method("show_hint"):
			var 当前游戏日 = 0
			if Game != null:
				var vg = Game.get("累计游戏日")
				当前游戏日 = int(vg) if vg != null else 0
			var 剩余日 = int(结果.get("预计结束游戏日", 0)) - 当前游戏日
			UIHint.show_hint(null, "历练开始", "派遣成功，预计%d游戏日后完成" % 剩余日)
		_selected_disciples.clear()
		_refresh_stage_list()
		_refresh_detail()
	else:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "派遣受阻", str(结果.get("原因", "卦象错乱")))

func refresh() -> void:
	if not _built:
		return
	_refresh_tab_highlight()
	_refresh_stage_list()
	_refresh_detail()
	# P0修复：更新机缘显示
	var 机缘label = get_node_or_null("VBoxContainer/HBoxContainer/JiyuanLabel")
	if 机缘label != null and is_instance_valid(Game):
		var 检查: Dictionary = Game.检查机缘("探秘境缘")
		var VIP等级: int = Game.当前VIP等级()
		机缘label.text = "机缘：%d/%d（VIP%d）" % [检查.get("剩余", 0), 检查.get("上限", 0), VIP等级]
	# P0-1: 检查并弹出待处理奇遇
	检查并弹出奇遇()

## ========== 队伍预设功能 ==========
func _on_preset_selected(index: int) -> void:
	if _preset_option == null or index <= 0:
		_current_preset = ""
		return
	_current_preset = _preset_option.get_item_text(index)

func _apply_current_preset() -> void:
	if _current_preset == "" or SectManager == null:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "请先选择一个队伍预设")
		return
	var 预设弟子 = SectManager.应用队伍预设(_current_preset)
	if 预设弟子.is_empty():
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "预设【%s】为空，请先保存弟子" % _current_preset)
		return
	_selected_disciples.clear()
	for did in 预设弟子:
		if _selected_disciples.size() >= 3:
			break
		# 检查弟子是否在历练中
		var 在历练 = false
		for 实例ID in ExpeditionSystem.进行中历练.keys():
			var 实例 = ExpeditionSystem.进行中历练[实例ID]
			if 实例["弟子ID列表"].has(did):
				在历练 = true
				break
		if not 在历练:
			_selected_disciples.append(did)
	_refresh_detail()
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "应用圆满", "已应用预设【%s】，共选择%d名弟子" % [_current_preset, _selected_disciples.size()])

func _save_current_preset() -> void:
	if _current_preset == "" or SectManager == null:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "请先选择一个队伍预设")
		return
	if _selected_disciples.is_empty():
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "请先选择至少一名弟子")
		return
	SectManager.保存队伍预设(_current_preset, _selected_disciples)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "已录册", "已保存%d名弟子到预设【%s】" % [_selected_disciples.size(), _current_preset])

## ========== 秘境挑战（回合制战斗，S1-1 接入新 UI）==========
## 走 Game.挑战秘境 → BattleManager（纯后端结算），本页只做选关/选弟子/展示战报，不碰战斗数值红线。
func _刷新秘境挑战列表() -> void:
	if _stage_list_vbox == null or Game == null:
		return
	var stages: Array = StageDataLoader.get_all_stages()
	for 关卡 in stages:
		var sid: String = 关卡.get("stage_id", "")
		if sid == "":
			continue
		var 解锁: bool = StageDataLoader.is_unlocked(sid, Game.门派等级, Game.已通关秘境)
		var 首通: bool = Game.已通关秘境.has(sid)
		var 推荐: int = int(关卡.get("recommend_power", 0))
		var 类型: String = 关卡.get("node_type", "normal")
		var 体力耗: int = int(关卡.get("stamina_cost", 0))
		var btn := Button.new()
		btn.text = "%s\n推荐战力：%d | 气力%d%s%s" % [
			关卡.get("stage_name", sid), 推荐, 体力耗,
			(" | 精英" if 类型 == "elite" else ""),
			("（已通关）" if 首通 else "")
		]
		btn.custom_minimum_size = Vector2(0, UITheme.GRID * 5)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		if not 解锁:
			btn.disabled = true
			btn.text += "\n（未解锁：%s）" % 关卡.get("unlock_condition", "")
		else:
			var stage_id: String = sid
			btn.pressed.connect(func(): _select_stage(stage_id))
		_stage_list_vbox.add_child(btn)
	# P2 高级秘境区域
	var 高级秘境列表: Array = Game.获取所有高级秘境列表()
	if 高级秘境列表.size() > 0:
		_stage_list_vbox.add_child(HSeparator.new())
		var 高级标题: Label = Label.new()
		高级标题.text = "◆ 高级秘境（多层挑战·专属掉落）"
		高级标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
		高级标题.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
		_stage_list_vbox.add_child(高级标题)
		for 秘境 in 高级秘境列表:
			var 秘境ID: String = str(秘境.get("secret_id", ""))
			var 名称: String = str(秘境.get("名称", ""))
			var 层数: int = int(秘境.get("层数", 3))
			var BOSS: String = str(秘境.get("BOSS", ""))
			var 体力耗: int = int(秘境.get("体力消耗", 20))
			var 已解锁: bool = bool(秘境.get("已解锁", false))
			var 已通关: bool = bool(秘境.get("已通关", false))
			var 解锁提示: String = str(秘境.get("解锁提示", ""))
			var sbtn := Button.new()
			sbtn.text = "%s\n%d层秘境 | BOSS：%s | 气力%d%s" % [
				名称, 层数, BOSS, 体力耗,
				("（已通关）" if 已通关 else "")
			]
			sbtn.custom_minimum_size = Vector2(0, UITheme.GRID * 5)
			sbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			sbtn.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			sbtn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
			if not 已解锁:
				sbtn.disabled = true
				sbtn.text += "\n（未解锁：%s）" % 解锁提示
			else:
				var sid2: String = 秘境ID
				sbtn.pressed.connect(func(): _显示高级秘境详情(sid2))
			_stage_list_vbox.add_child(sbtn)

## 显示高级秘境详情
func _显示高级秘境详情(秘境ID: String) -> void:
	if _detail_content == null or Game == null:
		return
	for child in _detail_content.get_children():
		child.queue_free()
	_selected_stage = ""  # 清除普通秘境选中状态
	var 列表: Array = Game.获取所有高级秘境列表()
	var 配置: Dictionary = {}
	for item in 列表:
		if str(item.get("secret_id", "")) == 秘境ID:
			配置 = item
			break
	if 配置.is_empty():
		return
	var name_lbl := Label.new()
	name_lbl.text = "◆ %s" % str(配置.get("名称", ""))
	name_lbl.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	name_lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_detail_content.add_child(name_lbl)
	var info := Label.new()
	info.text = "层数：%d层 | 主属性：%s | 气力消耗：%d\n解锁条件：%s\nBOSS：%s" % [
		int(配置.get("层数", 3)), str(配置.get("主属性", "")),
		int(配置.get("体力消耗", 20)), str(配置.get("解锁条件", "")),
		str(配置.get("BOSS", ""))
	]
	info.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	info.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(info)
	_detail_content.add_child(HSeparator.new())
	var 掉落标题: Label = Label.new()
	掉落标题.text = "核心掉落"
	掉落标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	掉落标题.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_detail_content.add_child(掉落标题)
	var 掉落: Label = Label.new()
	掉落.text = str(配置.get("核心掉落", ""))
	掉落.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	掉落.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	掉落.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(掉落)
	var 事件标题: Label = Label.new()
	事件标题.text = "专属事件"
	事件标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	事件标题.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_detail_content.add_child(事件标题)
	var 事件: Label = Label.new()
	事件.text = str(配置.get("专属事件", ""))
	事件.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	事件.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	事件.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(事件)
	var 奖励标题: Label = Label.new()
	奖励标题.text = "通关保底奖励"
	奖励标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	奖励标题.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_detail_content.add_child(奖励标题)
	var 奖励: Label = Label.new()
	奖励.text = str(配置.get("通关奖励", ""))
	奖励.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	奖励.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	奖励.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(奖励)
	_detail_content.add_child(HSeparator.new())
	# P2 高级秘境多层战斗：出战弟子选择
	var 出战标题: Label = Label.new()
	出战标题.text = "⚔️ 选择出战弟子（最多3人）"
	出战标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	出战标题.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_detail_content.add_child(出战标题)
	# 出战弟子列表
	var 出战弟子列表: Array = Game.弟子列表 if Game != null else []
	var 已选弟子: Array = []
	var 弟子选择容器: VBoxContainer = VBoxContainer.new()
	弟子选择容器.add_theme_constant_override("separation", 4)
	_detail_content.add_child(弟子选择容器)
	# 显示前10个弟子（避免列表过长）
	var 显示数量: int = min(出战弟子列表.size(), 10)
	for i in range(显示数量):
		var d = 出战弟子列表[i]
		if d == null:
			continue
		var 弟子行: HBoxContainer = HBoxContainer.new()
		弟子行.add_theme_constant_override("separation", 8)
		弟子选择容器.add_child(弟子行)
		var 勾选: CheckBox = CheckBox.new()
		勾选.text = "%s（%s·战力%d）" % [str(d.get("姓名", "")), str(d.get("境界", "")), int(d.get("战力", 0))]
		勾选.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		勾选.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
		弟子行.add_child(勾选)
		# 限制最多选3人
		勾选.toggled.connect(func(选中: bool):
			if 选中:
				if 已选弟子.size() >= 3:
					勾选.button_pressed = false
					UIHint.show_hint(null, "提示", "最多选择3名出战弟子")
					return
				已选弟子.append(d)
			else:
				已选弟子.erase(d)
		)
	# 开始挑战按钮
	var 挑战按钮: Button = Button.new()
	挑战按钮.text = "⚔️ 开始挑战（消耗气力%d）" % int(配置.get("体力消耗", 20))
	挑战按钮.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
	挑战按钮.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_primary_button_style(挑战按钮)
	挑战按钮.pressed.connect(func():
		if 已选弟子.is_empty():
			UIHint.show_hint(null, "提示", "请至少选择1名出战弟子")
			return
		# 检查气力
		if Game.体力 < int(配置.get("体力消耗", 20)):
			UIHint.show_hint(null, "提示", "气力不足")
			return
		# 开始挑战
		var 结果: Dictionary = Game.挑战高级秘境(秘境ID, 已选弟子)
		# 显示战斗结果
		for child in _detail_content.get_children():
			child.queue_free()
		var 结果标题: Label = Label.new()
		if bool(结果.get("通关", false)):
			结果标题.text = "🎉 挑战成功！通关%s" % str(配置.get("名称", ""))
			结果标题.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			结果标题.text = "⚔️ 挑战结束，到达第%d/%d层" % [int(结果.get("到达层数", 0)), int(结果.get("总层数", 0))]
			结果标题.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		结果标题.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
		_detail_content.add_child(结果标题)
		_detail_content.add_child(HSeparator.new())
		# 奖励信息
		var 奖励信息: Label = Label.new()
		奖励信息.text = "获得奖励：\n💰 灵石：%d\n📖 悟道点：%d" % [int(结果.get("灵石奖励", 0)), int(结果.get("悟道点奖励", 0))]
		var 掉落列表: Array = 结果.get("掉落", [])
		if 掉落列表.size() > 0:
			奖励信息.text += "\n🎁 材料：" + ", ".join(掉落列表)
		奖励信息.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		奖励信息.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
		奖励信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_content.add_child(奖励信息)
		_detail_content.add_child(HSeparator.new())
		# 战斗日志
		var 日志标题: Label = Label.new()
		日志标题.text = "📜 战斗日志"
		日志标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
		日志标题.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
		_detail_content.add_child(日志标题)
		var 战报: Array = 结果.get("战报", [])
		for 日志 in 战报:
			var 日志行: Label = Label.new()
			日志行.text = str(日志)
			日志行.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			日志行.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
			日志行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detail_content.add_child(日志行)
		# 返回按钮
		_detail_content.add_child(HSeparator.new())
		var 返回按钮: Button = Button.new()
		返回按钮.text = "返回秘境列表"
		返回按钮.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
		返回按钮.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		返回按钮.pressed.connect(func():
			_刷新秘境挑战列表()
		)
		_detail_content.add_child(返回按钮)
	)
	_detail_content.add_child(挑战按钮)

func _刷新秘境挑战详情() -> void:
	if _detail_content == null or Game == null:
		return
	for child in _detail_content.get_children():
		child.queue_free()

	var 关卡 = StageDataLoader.get_stage(_selected_stage)
	if 关卡.is_empty():
		return

	if not StageDataLoader.is_unlocked(_selected_stage, Game.门派等级, Game.已通关秘境):
		var lock := Label.new()
		lock.text = "未解锁：%s" % 关卡.get("unlock_condition", "")
		lock.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		lock.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
		_detail_content.add_child(lock)
		return

	var name_lbl := Label.new()
	name_lbl.text = 关卡.get("stage_name", _selected_stage)
	name_lbl.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	name_lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_detail_content.add_child(name_lbl)

	var info := Label.new()
	info.text = "推荐战力：%d | 气力消耗：%d | 类型：%s\n解锁条件：%s" % [
		int(关卡.get("recommend_power", 0)), int(关卡.get("stamina_cost", 0)),
		关卡.get("node_type", "normal"), 关卡.get("unlock_condition", "")
	]
	info.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	info.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(info)

	_detail_content.add_child(HSeparator.new())

	var select_title := Label.new()
	select_title.text = "选择出战弟子（1-3人，已选%d人）" % _selected_disciples.size()
	select_title.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	select_title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_detail_content.add_child(select_title)

	var auto_btn := Button.new()
	auto_btn.text = "尽数派遣"
	auto_btn.custom_minimum_size = Vector2(UITheme.GRID * 4, 0)
	auto_btn.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	auto_btn.pressed.connect(_auto_select_disciples)
	_detail_content.add_child(auto_btn)

	var disciple_scroll := ScrollContainer.new()
	disciple_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	disciple_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_content.add_child(disciple_scroll)

	var sel := VBoxContainer.new()
	sel.add_theme_constant_override("separation", UITheme.GRID / 2)
	sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	disciple_scroll.add_child(sel)

	var 弟子列表 = Game.get("弟子列表")
	if 弟子列表 != null:
		for d in 弟子列表:
			var did: int = int(d.弟子ID)
			if did < 0:
				continue
			var btn := Button.new()
			btn.text = "%s | %s | 战%d" % [str(d.姓名), str(d.境界), int(d.战力)]
			btn.custom_minimum_size = Vector2(0, UITheme.GRID * 3)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			if _selected_disciples.has(did):
				btn.modulate = UITheme.C01_TEXT_JADE
			var disciple_id: int = did
			btn.pressed.connect(func(): _toggle_disciple(disciple_id))
			sel.add_child(btn)

	_detail_content.add_child(HSeparator.new())

	var 总战力: int = 0
	for did in _selected_disciples:
		var d = _get_disciple(did)
		if d != null:
			总战力 += int(d.战力)
	var 推荐: int = int(关卡.get("recommend_power", 0))
	var 战力比: float = float(总战力) / float(推荐) if 推荐 > 0 else 0.0
	var preview := Label.new()
	preview.text = "总战力：%d / 推荐：%d（%.0f%%）" % [总战力, 推荐, 战力比 * 100]
	preview.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	preview.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	_detail_content.add_child(preview)

	var dispatch_btn := Button.new()
	dispatch_btn.text = "开始挑战"
	dispatch_btn.custom_minimum_size = Vector2(0, UITheme.GRID * 4)
	dispatch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dispatch_btn.disabled = _selected_disciples.is_empty() or _selected_disciples.size() > 3
	dispatch_btn.pressed.connect(_on_challenge_pressed)
	_detail_content.add_child(dispatch_btn)

func _on_challenge_pressed() -> void:
	if _selected_stage == "" or _selected_disciples.is_empty() or Game == null:
		return
	var 出战: Array = []
	for did in _selected_disciples:
		var d = _get_disciple(did)
		if d != null:
			出战.append(d)
	if 出战.is_empty():
		return

	# P2接入：组装攻方快照（用于战斗场景立绘显示）
	var 攻方快照: Array = []
	for d in 出战:
		if d is Disciple:
			攻方快照.append(d.get_final_combat_attr())

	# P2接入：组装守方快照（怪物，用于战斗场景立绘显示）
	var 守方快照: Array = []
	守方快照 = StageDataLoader.build_monster_units(_selected_stage)

	# 先计算战报（保持原有逻辑）
	var 战报: Dictionary = Game.挑战秘境(_selected_stage, 出战)
	if 战报.get("error", "") != "":
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "挑战未开始", 战报["error"])
		return

	# P2接入：显示战斗场景播放动画
	if Game.主UI != null and Game.主UI.has_method("播放战报") and not 攻方快照.is_empty() and not 守方快照.is_empty():
		# 连接战斗结束信号（一次性）
		var 战斗结束信号 = Game.主UI._battle_scene.战斗结束 if Game.主UI._battle_scene != null else null
		if 战斗结束信号 != null:
			# 先显示战斗场景
			Game.主UI.播放战报(战报, 攻方快照, 守方快照, "秘境挑战")
			# 等待战斗结束
			await 战斗结束信号
			# 战斗结束后显示结算面板
			_展示战报(战报)
		else:
			_展示战报(战报)
	else:
		_展示战报(战报)

	_refresh_stage_list()
	_refresh_detail()

# S2 战斗过程演出：逐回合播放 battle_log，更新双方血条 + 伤害数字强调 + 暴击/克制浮标 + 淡入
func _播放战报(战报: Dictionary, 日志: VBoxContainer, 攻血条: ProgressBar, 守血条: ProgressBar, 攻满: int, 守满: int, 确: Button) -> void:
	var 列表: Array = 战报.get("battle_log", [])
	for e in 列表:
		攻血条.value = int(e.get("attacker_hp", 0))
		守血条.value = int(e.get("defender_hp", 0))
		var 伤害: int = int(e.get("damage", 0))
		var 标签: String = ""
		if e.get("is_crit", false):
			标签 += "【暴击】"
		if e.get("is_restrain", false):
			标签 += "【克制】"
		if e.get("log_type", "") == "reflect":
			标签 += "【反伤】"
		var l: Label = Label.new()
		l.text = "第%d回合 %s → %s 造成%d伤害 %s" % [int(e.get("round", 0)), str(e.get("actor", "")), str(e.get("target", "")), 伤害, 标签]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_body_font(l)
		if e.get("log_type", "") == "reflect":
			l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_RED)
		elif e.get("is_crit", false):
			l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
			l.add_theme_font_size_override("font_size", int(UITheme.FONT_VALUE * 2))
		elif 伤害 > 0:
			l.add_theme_color_override("font_color", UITheme.C01_TEXT_SECONDARY)
		else:
			l.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
		l.modulate.a = 0.0
		日志.add_child(l)
		var tw: Tween = create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.25)
		var sc: Node = 日志.get_parent()
		if sc is ScrollContainer:
			sc.scroll_vertical = 1000000
		await get_tree().create_timer(0.35).timeout
	确.visible = true


func _展示战报(战报: Dictionary) -> void:
	var 遮 := ColorRect.new()
	遮.color = Color(0, 0, 0, 0.82)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "战报遮罩"
	add_child(遮)
	var 大 := PanelContainer.new()
	大.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	大.offset_left = 16
	大.offset_right = -16
	大.offset_top = 40
	大.offset_bottom = -16
	遮.add_child(大)
	var 内容 := VBoxContainer.new()
	大.add_child(内容)

	var 胜: bool = 战报.get("is_win", false)
	var 头 := Label.new()
	头.text = "⚔ 秘境挑战：%s" % ("胜利" if 胜 else "失败")
	头.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	头.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD if 胜 else UITheme.C01_TEXT_SECONDARY)
	内容.add_child(头)

	var 回合 := Label.new()
	回合.text = "回合 %d ｜ 胜方剩余气血 %d" % [int(战报.get("round_count", 0)), int(战报.get("remaining_hp", 0))]
	回合.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	内容.add_child(回合)

	var 赏 := Label.new()
	var 摘要: String = 战报.get("赏赐摘要", "")
	赏.text = "赏赐：%s" % (摘要 if 摘要 != "" else "无")
	赏.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	赏.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	赏.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	内容.add_child(赏)

	# 双方血条（S2 战斗过程演出）
	var 攻满: int = 1
	var 守满: int = 1
	for e in 战报.get("battle_log", []):
		攻满 = max(攻满, int(e.get("attacker_hp", 0)))
		守满 = max(守满, int(e.get("defender_hp", 0)))
	var 血条行: HBoxContainer = HBoxContainer.new()
	内容.add_child(血条行)
	var 攻血条: ProgressBar = ProgressBar.new()
	攻血条.max_value = 攻满
	攻血条.value = 攻满
	攻血条.show_percentage = false
	攻血条.tint_progress = UITheme.COLOR_STATUS_SUCCESS
	攻血条.custom_minimum_size = Vector2(0, 22)
	攻血条.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	血条行.add_child(攻血条)
	var 守血条: ProgressBar = ProgressBar.new()
	守血条.max_value = 守满
	守血条.value = 守满
	守血条.show_percentage = false
	守血条.tint_progress = UITheme.COLOR_TEXT_RED
	守血条.custom_minimum_size = Vector2(0, 22)
	守血条.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	血条行.add_child(守血条)

	var 日志标 := Label.new()
	日志标.text = "—— 战斗过程 ——"
	日志标.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	内容.add_child(日志标)

	var 滚 := ScrollContainer.new()
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.custom_minimum_size = Vector2(0, 200)
	内容.add_child(滚)
	var 日志 := VBoxContainer.new()
	滚.add_child(日志)
	var 确 := Button.new()
	_播放战报(战报, 日志, 攻血条, 守血条, 攻满, 守满, 确)

	确.text = "可"
	确.pressed.connect(func(): 遮.queue_free())
	内容.add_child(确)




# S1-4 付费：仙玉购买历练额外次数（调用 Game._pay_reserved_历练购买）
func _on_付费_历练() -> void:
	if not is_instance_valid(Game):
		return
	var r: Dictionary = Game._pay_reserved_历练购买()
	if r.get("成功", false):
		UIHint.show_hint(self, "历练次数+1", "已获得 1 次额外历练（剩余 %d 次）" % int(r.get("剩余额外", 0)))
	else:
		UIHint.show_hint(self, "仙玉匮乏", str(r.get("原因", "")))
	refresh()


# ============ 奇遇事件弹窗UI（P0-1新增）============
# 展示奇遇描述和选项，玩家选择后显示结果

var _奇遇弹窗遮罩: ColorRect = null
var _当前奇遇实例ID: String = ""
var _当前奇遇索引: int = 0

# 检查并弹出待处理奇遇（页面刷新时调用）
func 检查并弹出奇遇() -> void:
	if ExpeditionSystem == null:
		return
	var 进行中 = ExpeditionSystem.获取进行中历练()
	for 实例ID in 进行中.keys():
		var 待处理 = ExpeditionSystem.获取待处理奇遇(实例ID)
		if 待处理.size() > 0:
			_弹出奇遇弹窗(实例ID, 0)
			return

# 弹出奇遇弹窗
func _弹出奇遇弹窗(实例ID: String, 奇遇索引: int) -> void:
	_当前奇遇实例ID = 实例ID
	_当前奇遇索引 = 奇遇索引
	var 待处理 = ExpeditionSystem.获取待处理奇遇(实例ID)
	if 奇遇索引 < 0 or 奇遇索引 >= 待处理.size():
		return
	var item = 待处理[奇遇索引]
	var 奇遇: Dictionary = item.get("奇遇", {})
	if 奇遇.is_empty():
		return

	# 遮罩层
	_奇遇弹窗遮罩 = ColorRect.new()
	_奇遇弹窗遮罩.color = Color(0, 0, 0, 0.85)
	_奇遇弹窗遮罩.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_奇遇弹窗遮罩.mouse_filter = Control.MOUSE_FILTER_STOP
	_奇遇弹窗遮罩.name = "奇遇弹窗遮罩"
	add_child(_奇遇弹窗遮罩)

	# 主面板
	var 大面板 := PanelContainer.new()
	大面板.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	大面板.offset_left = 24
	大面板.offset_right = -24
	大面板.offset_top = 80
	大面板.offset_bottom = -80
	UITheme.apply_panel_style(大面板)
	_奇遇弹窗遮罩.add_child(大面板)

	var 内容 := VBoxContainer.new()
	内容.add_theme_constant_override("margin", UITheme.GRID * 2)
	内容.add_theme_constant_override("separation", UITheme.GRID)
	大面板.add_child(内容)

	# 标题
	var 标题 := Label.new()
	标题.text = "✦ 历练奇遇 ✦"
	标题.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	标题.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	内容.add_child(标题)

	# 分隔线
	内容.add_child(HSeparator.new())

	# 奇遇名称
	var 奇遇名 := Label.new()
	奇遇名.text = str(奇遇.get("名称", "奇遇"))
	奇遇名.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	奇遇名.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	奇遇名.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	内容.add_child(奇遇名)

	# 奇遇描述
	var 奇遇描述 := Label.new()
	奇遇描述.text = str(奇遇.get("描述", ""))
	奇遇描述.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	奇遇描述.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	奇遇描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	内容.add_child(奇遇描述)

	# 分隔线
	内容.add_child(HSeparator.new())

	# 选项标题
	var 选项标题 := Label.new()
	选项标题.text = "—— 请做出选择 ——"
	选项标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	选项标题.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	选项标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	内容.add_child(选项标题)

	# 选项按钮
	var 选项列表: Array = 奇遇.get("选项", [])
	for i in range(选项列表.size()):
		var 选项: Dictionary = 选项列表[i]
		var 选项按钮 := Button.new()
		var 成功率: float = float(选项.get("成功率", 0.5))
		选项按钮.text = "%s\n%s\n（成功率%.0f%%）" % [
			str(选项.get("名称", "")),
			str(选项.get("描述", "")),
			成功率 * 100
		]
		选项按钮.custom_minimum_size = Vector2(0, UITheme.GRID * 5)
		选项按钮.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		选项按钮.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		选项按钮.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx = i
		选项按钮.pressed.connect(func(): _on_奇遇选项选择(idx))
		内容.add_child(选项按钮)

	# 提示
	var 提示 := Label.new()
	提示.text = "选择将影响历练结果，请谨慎决策"
	提示.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
	提示.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	内容.add_child(提示)

# 奇遇选项选择
func _on_奇遇选项选择(选项索引: int) -> void:
	if ExpeditionSystem == null or _当前奇遇实例ID == "":
		return
	var 结果: Dictionary = ExpeditionSystem.处理待处理奇遇(_当前奇遇实例ID, _当前奇遇索引, 选项索引)
	_显示奇遇结果(结果)

# 显示奇遇结果
func _显示奇遇结果(结果: Dictionary) -> void:
	if _奇遇弹窗遮罩 == null:
		return
	# 清空弹窗内容，显示结果
	for child in _奇遇弹窗遮罩.get_children():
		child.queue_free()

	var 大面板 := PanelContainer.new()
	大面板.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	大面板.offset_left = 24
	大面板.offset_right = -24
	大面板.offset_top = 120
	大面板.offset_bottom = -120
	UITheme.apply_panel_style(大面板)
	_奇遇弹窗遮罩.add_child(大面板)

	var 内容 := VBoxContainer.new()
	内容.add_theme_constant_override("margin", UITheme.GRID * 2)
	内容.add_theme_constant_override("separation", UITheme.GRID)
	大面板.add_child(内容)

	# 结果标题
	var 成功: bool = bool(结果.get("选择成功", false))
	var 标题 := Label.new()
	标题.text = "✦ 奇遇结果 ✦"
	标题.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	标题.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD if 成功 else UITheme.C01_TEXT_SECONDARY)
	标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	内容.add_child(标题)

	内容.add_child(HSeparator.new())

	# 奇遇名称和选项
	var 信息 := Label.new()
	信息.text = "奇遇：%s\n选择：%s\n结果：%s" % [
		str(结果.get("奇遇名称", "")),
		str(结果.get("选项名称", "")),
		"成功" if 成功 else "未能如愿"
	]
	信息.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	信息.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	内容.add_child(信息)

	内容.add_child(HSeparator.new())

	# 纪事
	var 纪事 := Label.new()
	纪事.text = str(结果.get("纪事", ""))
	纪事.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	纪事.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD if 成功 else UITheme.C01_TEXT_SECONDARY)
	纪事.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	内容.add_child(纪事)

	# 效果展示
	var 效果: Dictionary = 结果.get("效果", {})
	if not 效果.is_empty():
		内容.add_child(HSeparator.new())
		var 效果标题 := Label.new()
		效果标题.text = "—— 获得效果 ——"
		效果标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
		效果标题.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
		效果标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		内容.add_child(效果标题)
		for key in 效果.keys():
			var 效果_lbl := Label.new()
			效果_lbl.text = "· %s：%s" % [str(key), str(效果[key])]
			效果_lbl.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			效果_lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
			内容.add_child(效果_lbl)

	# 确认按钮
	var 确 := Button.new()
	确.text = "继续历练"
	确.custom_minimum_size = Vector2(0, UITheme.GRID * 4)
	确.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	确.pressed.connect(_关闭奇遇弹窗)
	内容.add_child(确)

# 关闭奇遇弹窗
func _关闭奇遇弹窗() -> void:
	if _奇遇弹窗遮罩 != null:
		_奇遇弹窗遮罩.queue_free()
		_奇遇弹窗遮罩 = null
	_当前奇遇实例ID = ""
	_当前奇遇索引 = 0
	_refresh_detail()
	# 检查是否还有其他待处理奇遇
	检查并弹出奇遇()

# ===== 历练史册（P0-1 UI集成：展示历练历史记录和统计）=====
func _刷新历练史册() -> void:
	if _detail_content == null:
		return

	# 标题
	var title := Label.new()
	title.text = "历练史册"
	title.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_detail_content.add_child(title)

	# 统计信息
	var 统计: Dictionary = ExpeditionSystem.获取历练统计() if ExpeditionSystem != null else {}
	var 总次数: int = int(统计.get("总次数", 0))
	var 成功次数: int = int(统计.get("成功次数", 0))
	var 失败次数: int = int(统计.get("失败次数", 0))
	var 成功率: float = float(统计.get("成功率", 0.0))
	var 完美次数: int = int(统计.get("完美次数", 0))
	var 大捷次数: int = int(统计.get("大捷次数", 0))
	var 奇遇总次数: int = int(统计.get("奇遇总次数", 0))

	var stat_label := Label.new()
	stat_label.text = "总历练：%d次 | 成功：%d次 | 失败：%d次 | 成功率：%.0f%%\n完美结局：%d次 | 大捷：%d次 | 奇遇总触发：%d次" % [
		总次数, 成功次数, 失败次数, 成功率 * 100, 完美次数, 大捷次数, 奇遇总次数
	]
	stat_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	stat_label.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(stat_label)

	var sep := HSeparator.new()
	_detail_content.add_child(sep)

	# 历史记录列表
	var history: Array = ExpeditionSystem.获取历练历史(0, 20) if ExpeditionSystem != null else []
	if history.is_empty():
		var hint := Label.new()
		hint.text = "暂无历练记录，派遣弟子外出历练后将在此记录"
		hint.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		hint.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_detail_content.add_child(hint)
		return

	var list_title := Label.new()
	list_title.text = "最近历练记录（显示最近20条）"
	list_title.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	list_title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_detail_content.add_child(list_title)

	# 滚动容器
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_content.add_child(scroll)

	var scroll_vb := VBoxContainer.new()
	scroll_vb.add_theme_constant_override("separation", UITheme.GRID / 2)
	scroll.add_child(scroll_vb)

	# 每条记录
	for 记录 in history:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(true))
		scroll_vb.add_child(panel)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", UITheme.GRID / 4)
		panel.add_child(vb)

		# 第一行：弟子名 + 关卡名 + 结局
		var row1 := HBoxContainer.new()
		row1.add_theme_constant_override("separation", UITheme.GRID)
		vb.add_child(row1)

		var 弟子ID列表: Array = 记录.get("弟子ID列表", [])
		var 关卡名: String = str(记录.get("关卡名称", "未知"))
		var 结局: String = str(记录.get("结局类型", "普通"))
		var 评级: String = str(记录.get("评级", "C"))

		# 从弟子ID列表获取弟子名（Disciple对象有弟子ID和姓名属性）
		var 弟子名: String = "未知"
		if 弟子ID列表.size() > 0 and Game != null:
			var did: int = int(弟子ID列表[0])
			for d in Game.弟子列表:
				if d.弟子ID == did:
					弟子名 = d.姓名
					break
		if 弟子ID列表.size() > 1:
			弟子名 += "等%d人" % 弟子ID列表.size()

		var name_label := Label.new()
		name_label.text = "%s · %s" % [弟子名, 关卡名]
		name_label.add_theme_font_size_override("font_size", UITheme.FONT_H2)
		name_label.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row1.add_child(name_label)

		var 结局颜色: Color = UITheme.C01_TEXT_TERTIARY
		match 结局:
			"完美": 结局颜色 = UITheme.C01_TEXT_GOLD
			"大捷": 结局颜色 = Color(1, 0.84, 0)
			"深入": 结局颜色 = Color(0.6, 0.8, 1)
			"稳妥": 结局颜色 = Color(0.6, 1, 0.6)
			"普通": 结局颜色 = UITheme.C01_TEXT_PRIMARY
			"险归": 结局颜色 = Color(1, 0.6, 0.4)
			"失败": 结局颜色 = Color(1, 0.4, 0.4)

		var result_label := Label.new()
		result_label.text = "[%s] 评级：%s" % [结局, 评级]
		result_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		result_label.add_theme_color_override("font_color", 结局颜色)
		row1.add_child(result_label)

		# 第二行：时间 + 奇遇次数
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", UITheme.GRID)
		vb.add_child(row2)

		var 时间: int = int(记录.get("结束日", 0))
		var 奇遇次数: int = int(记录.get("奇遇次数", 0))

		var time_label := Label.new()
		time_label.text = "第%d游戏日" % 时间
		time_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		time_label.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
		time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(time_label)

		if 奇遇次数 > 0:
			var adventure_label := Label.new()
			adventure_label.text = "触发奇遇：%d次" % 奇遇次数
			adventure_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			adventure_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1))
			row2.add_child(adventure_label)

		# 第三行：路线和奖励（如果有）
		var 路线: String = str(记录.get("路线", "稳妥"))
		var 奖励: Dictionary = 记录.get("奖励", {})
		var 奖励文本: String = ""
		if not 奖励.is_empty():
			var 奖励列表: Array = []
			for key in 奖励.keys():
				奖励列表.append("%s+%s" % [key, str(奖励[key])])
			奖励文本 = "，奖励：" + "、".join(奖励列表)
		var desc_label := Label.new()
		desc_label.text = "路线：%s%s" % [路线, 奖励文本]
		desc_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		desc_label.add_theme_color_override("font_color", UITheme.C01_TEXT_SECONDARY)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(desc_label)

		# P0-3 战斗快播：可回放的记录提供「观战」入口。
		#   设计意图：历练是异步结算（派出→数日后归来），玩家原本只看到一行文字战绩，
		#   对「词条/丹纹/装备/境界」这些战力投资的感知为零。补一个回放入口，
		#   让战力成长在结算时刻被"看见"，而不是只体现在数字上。
		#   存档侧仅最近 20 条保留 battle_log + 快照（见 expedition.gd 归档裁剪），
		#   更早的记录降级为纯文字战绩，此处给出明确文案而非静默隐藏按钮。
		var 原始战报: Dictionary = 记录.get("原始战报", {})
		var 攻方快照: Array = 记录.get("攻方快照", [])
		var 守方快照: Array = 记录.get("守方快照", [])
		if not 原始战报.is_empty() and not 攻方快照.is_empty() and not 守方快照.is_empty():
			var 观战btn := Button.new()
			观战btn.text = "观战回放"
			观战btn.custom_minimum_size = Vector2(0, UITheme.GRID * 4)
			观战btn.size_flags_horizontal = Control.SIZE_SHRINK_END
			观战btn.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			var 回放战报: Dictionary = 原始战报
			var 回放攻方: Array = 攻方快照
			var 回放守方: Array = 守方快照
			var 回放标题: String = 关卡名
			观战btn.pressed.connect(func():
				if Game != null and Game.主UI != null and Game.主UI.has_method("播放战报"):
					Game.主UI.播放战报(回放战报, 回放攻方, 回放守方, 回放标题)
			)
			vb.add_child(观战btn)
		else:
			var 归档label := Label.new()
			归档label.text = "（此战已归档，仅存战绩）"
			归档label.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
			归档label.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
			vb.add_child(归档label)

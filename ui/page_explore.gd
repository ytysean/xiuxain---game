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
	var 序 = ["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫", "道阶"]
	return 序.find(境界)

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
	tip.text = "低阶弟子历练失败可能失踪，宗门自动下发调查任务；仅修为高于失踪者的弟子可接取。调查成功将按关卡难度判定生还或陨落（高风险常客死）。弟子生死可于详情页「命牌」查看。"
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
	name_lbl.text = "调查·%s 失踪" % t.get("失踪弟子名", "")
	UITheme.apply_body_font(name_lbl)
	vbox.add_child(name_lbl)

	var info := Label.new()
	info.text = "失踪于【%s】｜要求境界：%s（须更高阶）｜难度 %d" % [t.get("失踪关卡名", ""), t.get("失踪弟子境界", ""), int(t.get("难度", 1))]
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

	var dispatch_btn := Button.new()
	dispatch_btn.text = "开始历练"
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
			var 当前日 = 0
			if Game != null:
				var vd = Game.get("累计游戏日")
				当前日 = int(vd) if vd != null else 0
			var 剩余 = int(实例["预计结束游戏日"]) - 当前日
			var lbl := Label.new()
			lbl.text = "%s | 剩余%d日" % [关卡2.get("名称", ""), max(0, 剩余)]
			lbl.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_SECONDARY)
			_detail_content.add_child(lbl)

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
	var 结果 = ExpeditionSystem.开始历练(_selected_stage, _selected_disciples)
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
	var 战报: Dictionary = Game.挑战秘境(_selected_stage, 出战)
	if 战报.get("error", "") != "":
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "挑战未开始", 战报["error"])
		return
	_展示战报(战报)
	_refresh_stage_list()
	_refresh_detail()

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

	var 日志标 := Label.new()
	日志标.text = "—— 战斗日志 ——"
	日志标.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	内容.add_child(日志标)

	var 滚 := ScrollContainer.new()
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.custom_minimum_size = Vector2(0, 200)
	内容.add_child(滚)
	var 日志 := VBoxContainer.new()
	滚.add_child(日志)
	for line in 战报.get("battle_log", []):
		var l := Label.new()
		l.text = str(line)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		l.add_theme_color_override("font_color", UITheme.C01_TEXT_SECONDARY)
		日志.add_child(l)

	var 确 := Button.new()
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




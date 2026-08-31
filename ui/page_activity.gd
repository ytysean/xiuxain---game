extends Control

## 活动中心页面（整合所有活动，统一展示）
## 活动分类：日常活动、周常活动、限时活动
## 活动卡片：大厂标准UI，带图标、名称、描述、状态、参与按钮

signal 返回请求()
signal 活动参与请求(活动ID: String)

var _built: bool = false
var _current_tab: String = "all"  # all/daily/weekly/limited
var _activity_list_vbox: VBoxContainer = null
var _activity_detail_panel: PanelContainer = null
var _activity_detail_vbox: VBoxContainer = null
var _selected_activity: Dictionary = {}

# 活动分类配置
const ACTIVITY_TABS: Array = [
	{"key": "all", "name": "全部活动", "icon": "📋"},
	{"key": "daily", "name": "日常活动", "icon": "📅"},
	{"key": "weekly", "name": "周常活动", "icon": "📆"},
	{"key": "limited", "name": "限时活动", "icon": "🔥"},
]

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

	var back_btn: Button = UITheme.make_back_button(_on_back_pressed)
	hb.add_child(back_btn)

	var title := Label.new()
	title.text = "机缘殿"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(title)

	# 占位，让标题居中
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(48, 0)
	hb.add_child(spacer)

func _build_tabs(parent: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	parent.add_child(hb)

	for t in ACTIVITY_TABS:
		var btn := Button.new()
		btn.text = "%s %s" % [t["icon"], t["name"]]
		btn.custom_minimum_size = Vector2(0, UITheme.GRID * 3)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key = t["key"]
		btn.pressed.connect(func(): _switch_tab(key))
		hb.add_child(btn)
		btn.name = "Tab_" + key

func _switch_tab(tab: String) -> void:
	_current_tab = tab
	_selected_activity = {}
	_refresh_tab_highlight()
	_refresh_activity_list()
	_hide_activity_detail()

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

	# 左侧：活动列表
	var left_panel := PanelContainer.new()
	left_panel.name = "ActivityListPanel"
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = UITheme.C01_FLOAT_BG
	left_style.set_corner_radius_all(int(round(10.0 * UITheme.UI_SCALE)))
	left_style.set_border_width_all(1)
	left_style.border_color = UITheme.C01_GOLD_LINE
	left_style.set_content_margin_all(UITheme.PAD_PANEL)
	left_panel.add_theme_stylebox_override("panel", left_style)
	hb.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.name = "ActivityListVBox"
	left_vbox.add_theme_constant_override("separation", UITheme.GRID)
	left_panel.add_child(left_vbox)

	var list_title := Label.new()
	list_title.text = "活动列表"
	list_title.add_theme_font_size_override("font_size", 16)
	list_title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	left_vbox.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.name = "ActivityListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll)

	_activity_list_vbox = VBoxContainer.new()
	_activity_list_vbox.name = "ActivityListVBox"
	_activity_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_activity_list_vbox.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_activity_list_vbox)

	# 右侧：活动详情
	_activity_detail_panel = PanelContainer.new()
	_activity_detail_panel.name = "ActivityDetailPanel"
	_activity_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_activity_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_activity_detail_panel.visible = false
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = UITheme.C01_FLOAT_BG
	detail_style.set_corner_radius_all(int(round(10.0 * UITheme.UI_SCALE)))
	detail_style.set_border_width_all(1)
	detail_style.border_color = UITheme.C01_GOLD_LINE
	detail_style.set_content_margin_all(UITheme.PAD_PANEL)
	_activity_detail_panel.add_theme_stylebox_override("panel", detail_style)
	hb.add_child(_activity_detail_panel)

	_activity_detail_vbox = VBoxContainer.new()
	_activity_detail_vbox.name = "ActivityDetailVBox"
	_activity_detail_vbox.add_theme_constant_override("separation", UITheme.GRID)
	_activity_detail_panel.add_child(_activity_detail_vbox)

func refresh() -> void:
	if not _built:
		_build()
	_refresh_tab_highlight()
	_refresh_activity_list()

func _refresh_activity_list() -> void:
	if _activity_list_vbox == null:
		return
	for child in _activity_list_vbox.get_children():
		_activity_list_vbox.remove_child(child)
		child.queue_free()

	if not is_instance_valid(Game) or not Game.has_method("获取所有活动列表"):
		_add_empty_label("活动数据加载中...")
		return

	var all_activities: Array = Game.获取所有活动列表()
	if all_activities.is_empty():
		_add_empty_label("尚无活动")
		return

	# 按分类筛选
	var filtered_activities: Array = []
	for activity in all_activities:
		var activity_type = str(activity.get("类型", ""))
		if _current_tab == "all":
			filtered_activities.append(activity)
		elif _current_tab == "daily" and activity_type == "日常":
			filtered_activities.append(activity)
		elif _current_tab == "weekly" and activity_type == "周常":
			filtered_activities.append(activity)
		elif _current_tab == "limited":
			# 限时活动暂时标记为有冷却日数>1的活动
			if int(activity.get("冷却日数", 1)) > 1:
				filtered_activities.append(activity)

	if filtered_activities.is_empty():
		_add_empty_label("该分类尚无活动")
		return

	for activity in filtered_activities:
		var activity_card = _make_activity_card(activity)
		_activity_list_vbox.add_child(activity_card)

func _make_activity_card(activity: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "ActivityCard_%s" % str(activity.get("活动ID", ""))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UITheme.C01_PANEL_BG
	card_style.set_corner_radius_all(int(round(8.0 * UITheme.UI_SCALE)))
	card_style.set_border_width_all(1)
	card_style.border_color = UITheme.C01_GOLD_LINE
	card_style.set_content_margin_all(UITheme.PAD_PANEL)
	card.add_theme_stylebox_override("panel", card_style)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	card.add_child(hb)

	# 活动图标
	var icon_label := Label.new()
	icon_label.text = _get_activity_icon(activity)
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.custom_minimum_size = Vector2(48, 48)
	hb.add_child(icon_label)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hb.add_child(info)

	# 活动名称
	var name_label := Label.new()
	name_label.text = str(activity.get("名称", "未知活动"))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	info.add_child(name_label)

	# 活动描述
	var desc_label := Label.new()
	desc_label.text = str(activity.get("描述", ""))
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_label)

	# 活动类型和冷却
	var meta_hb := HBoxContainer.new()
	meta_hb.add_theme_constant_override("separation", 8)
	info.add_child(meta_hb)

	var type_label := Label.new()
	var activity_type = str(activity.get("类型", ""))
	type_label.text = "[%s]" % activity_type
	type_label.add_theme_font_size_override("font_size", 12)
	if activity_type == "日常":
		type_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
	elif activity_type == "周常":
		type_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9, 1.0))
	else:
		type_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 1.0))
	meta_hb.add_child(type_label)

	var cooldown_label := Label.new()
	cooldown_label.text = "冷却：%d日" % int(activity.get("冷却日数", 1))
	cooldown_label.add_theme_font_size_override("font_size", 12)
	cooldown_label.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	meta_hb.add_child(cooldown_label)

	# 查看详情按钮
	var detail_btn := Button.new()
	detail_btn.text = "查看详情"
	detail_btn.custom_minimum_size = Vector2(80, 32)
	detail_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var activity_ref = activity
	detail_btn.pressed.connect(func(): _show_activity_detail(activity_ref))
	hb.add_child(detail_btn)

	return card

func _get_activity_icon(activity: Dictionary) -> String:
	var activity_id = str(activity.get("活动ID", ""))
	match activity_id:
		"daily_checkin":
			return "📅"
		"faction_activity":
			return "⚔️"
		"faction_trial":
			return "🏆"
		"caravan_raid":
			return "🗡️"
		"explore_event":
			return "🗺️"
		"disciple_cultivate":
			return "👨‍🎓"
		"alchemy_session":
			return "⚗️"
		"artifact_forge":
			return "🔨"
		"zongmen_battle":
			return "🏯"
		"faction_reputation":
			return "⭐"
		_:
			return "🎯"

func _show_activity_detail(activity: Dictionary) -> void:
	_selected_activity = activity
	if _activity_detail_panel == null or _activity_detail_vbox == null:
		return

	_activity_detail_panel.visible = true

	# 清空详情
	for child in _activity_detail_vbox.get_children():
		_activity_detail_vbox.remove_child(child)
		child.queue_free()

	# 活动标题
	var title_hb := HBoxContainer.new()
	title_hb.add_theme_constant_override("separation", UITheme.GRID)
	_activity_detail_vbox.add_child(title_hb)

	var icon_label := Label.new()
	icon_label.text = _get_activity_icon(activity)
	icon_label.add_theme_font_size_override("font_size", 40)
	title_hb.add_child(icon_label)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hb.add_child(title_vbox)

	var name_label := Label.new()
	name_label.text = str(activity.get("名称", "未知活动"))
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	title_vbox.add_child(name_label)

	var type_label := Label.new()
	type_label.text = "类型：%s | 冷却：%d日" % [str(activity.get("类型", "")), int(activity.get("冷却日数", 1))]
	type_label.add_theme_font_size_override("font_size", 14)
	type_label.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	title_vbox.add_child(type_label)

	# 分隔线
	var separator := HSeparator.new()
	_activity_detail_vbox.add_child(separator)

	# 活动描述
	var desc_title := Label.new()
	desc_title.text = "活动描述"
	desc_title.add_theme_font_size_override("font_size", 16)
	desc_title.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	_activity_detail_vbox.add_child(desc_title)

	var desc_label := Label.new()
	desc_label.text = str(activity.get("描述", "尚无描述"))
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", UITheme.C01_TEXT_SECONDARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_activity_detail_vbox.add_child(desc_label)

	# 活动状态
	var status_title := Label.new()
	status_title.text = "活动状态"
	status_title.add_theme_font_size_override("font_size", 16)
	status_title.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	_activity_detail_vbox.add_child(status_title)

	var can_participate = bool(activity.get("可参与", true))
	var status_label := Label.new()
	if can_participate:
		status_label.text = "机缘成熟，可入世"
		status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))
	else:
		status_label.text = "冷却期，机缘未至"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3, 1.0))
	status_label.add_theme_font_size_override("font_size", 14)
	_activity_detail_vbox.add_child(status_label)

	# 参与按钮
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_activity_detail_vbox.add_child(spacer)

	var participate_btn := Button.new()
	participate_btn.text = "即刻入世" if can_participate else "冷却期"
	participate_btn.custom_minimum_size = Vector2(0, 48)
	participate_btn.disabled = not can_participate
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = UITheme.C05_BTN_GRAD
	btn_style.border_color = UITheme.C05_BTN_GRAD_DK
	btn_style.set_corner_radius_all(int(round(13.0 * UITheme.UI_SCALE)))
	btn_style.set_border_width_all(1)
	btn_style.set_content_margin_all(UITheme.GRID)
	participate_btn.add_theme_stylebox_override("normal", btn_style)
	participate_btn.add_theme_color_override("font_color", UITheme.C01_TEXT_DARK)
	participate_btn.add_theme_font_size_override("font_size", 16)
	var activity_id = str(activity.get("活动ID", ""))
	participate_btn.pressed.connect(func(): _on_participate_activity(activity_id))
	_activity_detail_vbox.add_child(participate_btn)

func _hide_activity_detail() -> void:
	if _activity_detail_panel != null:
		_activity_detail_panel.visible = false

func _on_participate_activity(activity_id: String) -> void:
	活动参与请求.emit(activity_id)
	# 调用实际的活动参与函数
	if is_instance_valid(Game) and Game.has_method("参与活动"):
		var 结果 = Game.参与活动(activity_id)
		if 结果.get("成功", false):
			# 参与成功，显示提示
			var 消息 = str(结果.get("消息", "参与成功"))
			# 这里可以添加toast提示
			print("活动参与成功：%s" % 消息)
		else:
			# 参与失败，显示提示
			var 原因 = str(结果.get("原因", "未知原因"))
			print("活动参与失败：%s" % 原因)
	_refresh_activity_list()
	_hide_activity_detail()

func _add_empty_label(text: String) -> void:
	var empty_label := Label.new()
	empty_label.text = text
	empty_label.add_theme_font_size_override("font_size", 14)
	empty_label.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_activity_list_vbox.add_child(empty_label)

func _on_back_pressed() -> void:
	返回请求.emit()



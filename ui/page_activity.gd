extends Control

## 宗门时令页面（整合每日功课 / 周课 / 大典盛事，统一展示）
## 时令分类：每日功课、周课、大典盛事
## 时令卡片：带图标、名称、描述、状态、参与

signal 返回请求()
signal 活动参与请求(活动ID: String)

var _built: bool = false
var _current_tab: String = "all"  # all/daily/weekly/limited
var _activity_list_vbox: VBoxContainer = null
var _activity_detail_panel: PanelContainer = null
var _activity_detail_vbox: VBoxContainer = null
var _selected_activity: Dictionary = {}
var _daily_msg: String = ""             # 最近一次打理结果（页内反馈，X15 必有反馈）
var _daily_msg_lbl: Label = null

# 时令分类配置
const ACTIVITY_TABS: Array = [
	{"key": "all", "name": "时令一览", "icon": "emoji_offline_scroll"},
	{"key": "daily", "name": "每日功课", "icon": "emoji_activity_calendar"},
	{"key": "weekly", "name": "周课", "icon": "emoji_dynasty_news"},
	{"key": "limited", "name": "大典盛事", "icon": "emoji_activity_fire"},
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
	# PH6·M5c：统一刷新时刻口径文案（与 game_state 每日重置小时=8 一致）
	var 重置提示 := Label.new()
	重置提示.text = "每日 08:00 更替"
	重置提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_aux_font_sized(重置提示, UITheme.FONT_AUX)
	vbox.add_child(重置提示)
	# P2联动：显示当前时令名称（修真化描述）
	if Game != null and Game.has_method("获取当前活动名称"):
		var 当前活动: String = Game.获取当前活动名称()
		if 当前活动 != "平日（无加成）":
			var activity_lbl := Label.new()
			activity_lbl.text = "【当前时令】%s" % 当前活动
			UITheme.apply_aux_font_sized(activity_lbl, UITheme.FONT_H2)
			activity_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
			activity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(activity_lbl)
	_build_tabs(vbox)
	_build_main_area(vbox)

func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	parent.add_child(UITheme.建顶栏("宗门时令", _on_back_pressed, []))
func _build_tabs(parent: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	parent.add_child(hb)

	for t in ACTIVITY_TABS:
		var btn := Button.new()
		# 2026-09-14：emoji → 圆形金框图标（豆包资产 emoji_activity_*），无资产回退字符。
		var 图标tex: Texture2D = UITheme.emoji_icon_sized(str(t["icon"]), 28)
		if 图标tex != null:
			btn.icon = 图标tex
			btn.text = str(t["name"])
		else:
			# stem 是 ASCII 标识符，缺资产时不能当文案打给玩家
			btn.text = str(t["name"])
		btn.custom_minimum_size = Vector2(0, UITheme.GRID * 3)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key = t["key"]
		btn.pressed.connect(func(): _switch_tab(key))
		hb.add_child(btn)
		btn.modulate.a = 0.0
		btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)
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

	# 左侧：时令一览
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
	list_title.text = "时令一览"
	UITheme.apply_section_title(list_title)
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

	# 右侧：时令详情
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
		_add_empty_label("时令数据载入中…")
		return

	var all_activities: Array = Game.获取所有活动列表()
	if all_activities.is_empty():
		_add_empty_label("尚无时令")
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
			# 大典盛事暂标记为冷却日数>1的时令
			if int(activity.get("冷却日数", 1)) > 1:
				filtered_activities.append(activity)

	if filtered_activities.is_empty():
		_add_empty_label("该分类尚无时令")
		return

	# 顶部操作区域：一键参与 + 积分兑换
	_add_activity_action_bar()

	for activity in filtered_activities:
		var activity_card = _make_activity_card(activity)
		_activity_list_vbox.add_child(activity_card)
		activity_card.modulate.a = 0.0
		activity_card.create_tween().tween_property(activity_card, "modulate:a", 1.0, 0.25)

# 时令操作栏：日常方针 + 积分兑换
func _add_activity_action_bar() -> void:
	var bar := PanelContainer.new()
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = UITheme.C01_PANEL_B
	bar_style.set_corner_radius_all(int(round(8.0 * UITheme.UI_SCALE)))
	bar_style.set_border_width_all(1)
	bar_style.border_color = UITheme.C01_GOLD_LINE
	bar_style.set_content_margin_all(UITheme.PAD_PANEL)
	bar.add_theme_stylebox_override("panel", bar_style)
	_activity_list_vbox.add_child(bar)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", UITheme.GRID)
	bar.add_child(vb)

	# 第一行：日常方针 + 积分显示
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	vb.add_child(hb)

	# §2.0 唯一合法「一键」形态：一键执行**已定方针**，绝不替宗主做决策。
	# 宗主在此定日常方针（养士/充库/扬名），门下弟子照此打理日常诸事。
	var policy_btn := Button.new()
	policy_btn.text = "日常方针：%s" % _当前日常方针()
	policy_btn.tooltip_text = "轻触切换方针 · " + _日常方针说明(_当前日常方针())
	policy_btn.custom_minimum_size = Vector2(160, 40)
	policy_btn.pressed.connect(_on_切换日常方针)
	hb.add_child(policy_btn)

	# 当前积分显示
	var 积分: int = int(Game.活动积分) if Game != null and "活动积分" in Game else 0
	var points_lbl := Label.new()
	points_lbl.text = "时令积分：%d" % 积分
	UITheme.apply_project_font(points_lbl, UITheme.FONT_H2, true)
	points_lbl.add_theme_color_override("font_color", UITheme.获取金文字色())
	points_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(points_lbl)

	# 积分兑换按钮
	var exchange_btn := Button.new()
	exchange_btn.text = "积分兑换"
	exchange_btn.custom_minimum_size = Vector2(120, 40)
	exchange_btn.pressed.connect(_on_open_exchange)
	hb.add_child(exchange_btn)

	# 第二行：连续参与天数 + 催办（劳作由弟子完成，宗主只需下令）
	var hb2 := HBoxContainer.new()
	hb2.add_theme_constant_override("separation", UITheme.GRID)
	vb.add_child(hb2)

	var 连续天数: int = int(Game.连续参与天数) if Game != null and "连续参与天数" in Game else 0
	var streak_lbl := Label.new()
	streak_lbl.text = "连续参与：%d天（加成%.1f倍）" % [连续天数, Game.获取连续参与加成() if Game != null else 1.0]
	UITheme.apply_project_font(streak_lbl, UITheme.FONT_BODY, false)
	streak_lbl.add_theme_color_override("font_color", UITheme.获取弱文字色())
	streak_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb2.add_child(streak_lbl)

	var 催办按钮 := Button.new()
	催办按钮.text = "催办一次"
	催办按钮.custom_minimum_size = Vector2(120, 36)
	催办按钮.pressed.connect(_on_one_key_daily)
	hb2.add_child(催办按钮)

	# 反馈行：最近一次打理结果（X15 点击必有反馈）
	_daily_msg_lbl = Label.new()
	_daily_msg_lbl.text = _daily_msg
	UITheme.apply_project_font(_daily_msg_lbl, UITheme.FONT_BODY, false)
	_daily_msg_lbl.add_theme_color_override("font_color", UITheme.获取金文字色())
	_daily_msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_daily_msg_lbl)

# 催办：门下弟子按已定方针打理日常诸事（不是「一键收菜」，决策仍归宗主）
func _on_one_key_daily() -> void:
	if Game == null or not Game.has_method("一键参与日常活动"):
		return
	var 结果: Dictionary = Game.一键参与日常活动()
	_daily_msg = str(结果.get("消息", "已完成日常打理"))
	refresh()


# 切换日常方针（养士 → 充库 → 扬名 → 养士…）——决策留给宗主
func _on_切换日常方针() -> void:
	if Game == null or not Game.has_method("获取日常方针列表"):
		return
	var 列表: Array = Game.获取日常方针列表()
	if 列表.is_empty():
		return
	var i: int = int(列表.find(_当前日常方针()))
	var 下一: String = String(列表[(i + 1) % 列表.size()])
	var 结果: Dictionary = Game.设置日常方针(下一)
	if bool(结果.get("成功", false)):
		_daily_msg = str(结果.get("消息", "方针已设定"))
	else:
		_daily_msg = str(结果.get("原因", "设置失败"))
	refresh()


func _当前日常方针() -> String:
	if Game != null and "日常方针" in Game:
		return String(Game.日常方针)
	return "充库"


func _日常方针说明(方针: String) -> String:
	if Game != null and Game.has_method("获取日常方针说明"):
		return String(Game.获取日常方针说明(方针))
	return ""

# 打开积分兑换面板
func _on_open_exchange() -> void:
	if Game == null or not Game.has_method("获取活动积分兑换列表"):
		return
	var 兑换列表: Array = Game.获取活动积分兑换列表()
	if 兑换列表.is_empty():
		return
	# 在详情面板显示兑换列表
	_show_exchange_panel(兑换列表)

# 显示积分兑换面板
func _show_exchange_panel(兑换列表: Array) -> void:
	if _activity_detail_panel == null:
		return
	_activity_detail_panel.visible = true
	for child in _activity_detail_vbox.get_children():
		_activity_detail_vbox.remove_child(child)
		child.queue_free()

	var title := Label.new()
	title.text = "积分兑换阁"
	UITheme.apply_section_title(title)
	_activity_detail_vbox.add_child(title)

	var 积分: int = int(Game.活动积分) if Game != null and "活动积分" in Game else 0
	var points_lbl := Label.new()
	points_lbl.text = "当前积分：%d" % 积分
	UITheme.apply_project_font(points_lbl, UITheme.FONT_H2, true)
	points_lbl.add_theme_color_override("font_color", UITheme.获取主文字色())
	_activity_detail_vbox.add_child(points_lbl)

	for item in 兑换列表:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", UITheme.GRID)

		var name_lbl := Label.new()
		name_lbl.text = str(item.get("名称", ""))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_activity_detail_vbox.add_child(name_lbl)
		name_lbl.modulate.a = 0.0
		name_lbl.create_tween().tween_property(name_lbl, "modulate:a", 1.0, 0.25)

		var cost_lbl := Label.new()
		cost_lbl.text = "%d积分" % int(item.get("积分", 0))
		cost_lbl.custom_minimum_size = Vector2(80, 0)
		hb.add_child(cost_lbl)
		cost_lbl.modulate.a = 0.0
		cost_lbl.create_tween().tween_property(cost_lbl, "modulate:a", 1.0, 0.25)

		var btn := Button.new()
		btn.text = "兑换"
		btn.custom_minimum_size = Vector2(80, 32)
		var item_type = str(item.get("类型", ""))
		var item_rank = str(item.get("品阶", ""))
		btn.pressed.connect(func(): _on_exchange_item(item_type, item_rank))
		hb.add_child(btn)
		btn.modulate.a = 0.0
		btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)

		_activity_detail_vbox.add_child(hb)
		hb.modulate.a = 0.0
		hb.create_tween().tween_property(hb, "modulate:a", 1.0, 0.25)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_hide_activity_detail)
	_activity_detail_vbox.add_child(close_btn)

# 兑换物品
func _on_exchange_item(物品类型: String, 品阶: String) -> void:
	if Game == null or not Game.has_method("活动积分兑换"):
		return
	var 结果: Dictionary = Game.活动积分兑换(物品类型, 品阶)
	if bool(结果.get("成功", false)):
		refresh()
		# 刷新兑换面板
		_on_open_exchange()
	else:
		refresh()

func _make_activity_card(activity: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "ActivityCard_%s" % str(activity.get("活动ID", ""))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UITheme.C01_PANEL_A
	card_style.set_corner_radius_all(int(round(8.0 * UITheme.UI_SCALE)))
	card_style.set_border_width_all(1)
	card_style.border_color = UITheme.C01_GOLD_LINE
	card_style.set_content_margin_all(UITheme.PAD_PANEL)
	card.add_theme_stylebox_override("panel", card_style)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	card.add_child(hb)
	hb.modulate.a = 0.0
	hb.create_tween().tween_property(hb, "modulate:a", 1.0, 0.25)

	# 时令图标（2026-09-14：emoji → 圆形金框图标，无资产回退字符）
	var _fb1 := _make_activity_icon_node(activity, 48)
	hb.add_child(_fb1)
	_fb1.modulate.a = 0.0
	_fb1.create_tween().tween_property(_fb1, "modulate:a", 1.0, 0.25)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hb.add_child(info)
	info.modulate.a = 0.0
	info.create_tween().tween_property(info, "modulate:a", 1.0, 0.25)

	# 时令名称
	var name_label := Label.new()
	name_label.text = str(activity.get("名称", "未知时令"))
	UITheme.apply_project_font(name_label, UITheme.FONT_H2, true)
	name_label.add_theme_color_override("font_color", UITheme.获取主文字色())
	info.add_child(name_label)
	name_label.modulate.a = 0.0
	name_label.create_tween().tween_property(name_label, "modulate:a", 1.0, 0.25)

	# 时令描述
	var desc_label := Label.new()
	desc_label.text = str(activity.get("描述", ""))
	UITheme.apply_project_font(desc_label, UITheme.FONT_BODY, false)
	desc_label.add_theme_color_override("font_color", UITheme.获取弱文字色())
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_label)
	desc_label.modulate.a = 0.0
	desc_label.create_tween().tween_property(desc_label, "modulate:a", 1.0, 0.25)

	# 时令类型和冷却
	var meta_hb := HBoxContainer.new()
	meta_hb.add_theme_constant_override("separation", 8)
	info.add_child(meta_hb)
	meta_hb.modulate.a = 0.0
	meta_hb.create_tween().tween_property(meta_hb, "modulate:a", 1.0, 0.25)

	var type_label := Label.new()
	var activity_type = str(activity.get("类型", ""))
	type_label.text = "[%s]" % activity_type
	UITheme.apply_project_font(type_label, UITheme.FONT_BODY, false)
	if activity_type == "日常":
		type_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
	elif activity_type == "周常":
		type_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9, 1.0))
	else:
		type_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 1.0))
	meta_hb.add_child(type_label)
	type_label.modulate.a = 0.0
	type_label.create_tween().tween_property(type_label, "modulate:a", 1.0, 0.25)

	var cooldown_label := Label.new()
	cooldown_label.text = "冷却：%d日" % int(activity.get("冷却日数", 1))
	UITheme.apply_project_font(cooldown_label, UITheme.FONT_BODY, false)
	cooldown_label.add_theme_color_override("font_color", UITheme.获取弱文字色())
	meta_hb.add_child(cooldown_label)
	cooldown_label.modulate.a = 0.0
	cooldown_label.create_tween().tween_property(cooldown_label, "modulate:a", 1.0, 0.25)

	# 查看详情按钮
	var detail_btn := Button.new()
	detail_btn.text = "查看详情"
	detail_btn.custom_minimum_size = Vector2(80, 32)
	detail_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var activity_ref = activity
	detail_btn.pressed.connect(func(): _show_activity_detail(activity_ref))
	hb.add_child(detail_btn)
	detail_btn.modulate.a = 0.0
	detail_btn.create_tween().tween_property(detail_btn, "modulate:a", 1.0, 0.25)

	return card

## 活动图标节点：优先用豆包圆形金框图标（emoji_activity_*），缺资产回退 emoji 字符。
## 返回 Control（TextureRect 或 Label），调用方直接 add_child。
func _make_activity_icon_node(activity: Dictionary, px: int) -> Control:
	var 字符: String = _get_activity_icon(activity)
	var tex: Texture2D = UITheme.emoji_icon_sized(字符, px)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var lb := Label.new()
	lb.text = 字符
	UITheme.apply_project_font(lb, UITheme.FONT_DISPLAY, true)
	lb.custom_minimum_size = Vector2(px, px)
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lb

func _get_activity_icon(activity: Dictionary) -> String:
	var activity_id = str(activity.get("活动ID", ""))
	match activity_id:
		"daily_checkin":
			return "emoji_activity_calendar"
		"faction_activity":
			return "emoji_activity_battle"
		"faction_trial":
			return "emoji_activity_trophy"
		"caravan_raid":
			return "emoji_activity_sword"
		"explore_event":
			return "emoji_activity_map"
		"disciple_cultivate":
			return "emoji_disciple_person"
		"alchemy_session":
			return "emoji_general_alchemy"
		"artifact_forge":
			return "emoji_general_forge"
		"zongmen_battle":
			return "emoji_world_city"
		"faction_reputation":
			return "emoji_activity_star"
		_:
			return "emoji_dynasty_target"

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

	title_hb.add_child(_make_activity_icon_node(activity, 28))

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hb.add_child(title_vbox)

	var name_label := Label.new()
	name_label.text = str(activity.get("名称", "未知时令"))
	UITheme.apply_section_title(name_label)
	title_vbox.add_child(name_label)

	var type_label := Label.new()
	type_label.text = "类型：%s | 冷却：%d日" % [str(activity.get("类型", "")), int(activity.get("冷却日数", 1))]
	UITheme.apply_project_font(type_label, UITheme.FONT_H2, true)
	type_label.add_theme_color_override("font_color", UITheme.获取弱文字色())
	title_vbox.add_child(type_label)

	# 分隔线
	var separator := HSeparator.new()
	_activity_detail_vbox.add_child(separator)

	# 时令描述
	var desc_title := Label.new()
	desc_title.text = "活动描述"
	UITheme.apply_project_font(desc_title, UITheme.FONT_H2, true)
	desc_title.add_theme_color_override("font_color", UITheme.获取主文字色())
	_activity_detail_vbox.add_child(desc_title)

	var desc_label := Label.new()
	desc_label.text = str(activity.get("描述", "尚无描述"))
	UITheme.apply_project_font(desc_label, UITheme.FONT_H2, true)
	desc_label.add_theme_color_override("font_color", UITheme.获取次文字色())
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_activity_detail_vbox.add_child(desc_label)

	# 活动状态
	var status_title := Label.new()
	status_title.text = "活动状态"
	UITheme.apply_project_font(status_title, UITheme.FONT_H2, true)
	status_title.add_theme_color_override("font_color", UITheme.获取主文字色())
	_activity_detail_vbox.add_child(status_title)

	var can_participate = bool(activity.get("可参与", true))
	var status_label := Label.new()
	if can_participate:
		status_label.text = "机缘成熟，可入世"
		status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))
	else:
		status_label.text = "冷却期，机缘未至"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3, 1.0))
	UITheme.apply_project_font(status_label, UITheme.FONT_H2, true)
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
	participate_btn.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
	UITheme.apply_project_font(participate_btn, UITheme.FONT_H2, true)
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
			Game.添加提示("活动参与成功：%s" % 消息)
		else:
			# 参与失败，显示提示
			var 原因 = str(结果.get("原因", "未知原因"))
			Game.添加提示("活动参与失败：%s" % 原因)
	_refresh_activity_list()
	_hide_activity_detail()

func _add_empty_label(text: String) -> void:
	# ★ 2026-09-16（#009 逐页精修）：委托全项目统一空态组件（图标位 + 主文案 + 说明 + 淡入）。
	#   原先各页自写一份、都只有「一行小字」，实机观感等同「这页没做」。
	_activity_list_vbox.add_child(UITheme.建空态(text))

func _on_back_pressed() -> void:
	返回请求.emit()



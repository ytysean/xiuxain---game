extends Control

# 历练页（§5 · 玩法探索）：只读展示 历练派发面板 + 日常(≤3) + 周常(1) 卡。
# 奖励按 任务奖励系数() 缩放。Lv.3 / FTUE 灰锁：锁定时不隐藏卡片，仅置灰所有 领取 按钮（disabled + 🔒 + tooltip）。
# 零 GameState 写入；领取按钮仅 emit 占位信号。读数经 is_instance_valid(Game) + .get() 守卫。

signal 领取日常请求(序号: int)
signal 领取周常请求()

var _built: bool = false
var _progress_label: Label
var _lock_bar: PanelContainer
var _daily_vbox: VBoxContainer
var _weekly_vbox: VBoxContainer

func _ready() -> void:
	_build()
	refresh()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	_build_header(vbox)
	_build_lock_bar(vbox)
	_build_scroll(vbox)

func _build_header(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "Header"
	panel.custom_minimum_size = Vector2(0, UITheme.GRID * 7)
	UITheme.apply_panel_style(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(hb)

	var 图标 = UITheme.load_icon("历练")
	if 图标 != null:
		var tr := TextureRect.new()
		tr.texture = 图标
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.custom_minimum_size = Vector2(24, 24)
		hb.add_child(tr)

	var title := Label.new()
	title.text = "历练派发"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_title_font(title)
	hb.add_child(title)

	_progress_label = Label.new()
	_progress_label.text = "日常 0/0  周常 未领"
	UITheme.apply_aux_font(_progress_label)
	hb.add_child(_progress_label)
	parent.add_child(panel)

func _build_lock_bar(parent: Control) -> void:
	_lock_bar = PanelContainer.new()
	_lock_bar.name = "LockBar"
	_lock_bar.custom_minimum_size = Vector2(0, UITheme.GRID * 6)
	_lock_bar.visible = false
	UITheme.apply_panel_style(_lock_bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	_lock_bar.add_child(hb)
	var lbl := Label.new()
	lbl.text = "🔒 宗门 Lv.3 或完成引导后开启历练"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_aux_font(lbl)
	hb.add_child(lbl)
	parent.add_child(_lock_bar)

func _build_scroll(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", UITheme.GRID * 2)
	scroll.add_child(inner)

	var daily_panel := PanelContainer.new()
	daily_panel.name = "DailyPanel"
	UITheme.apply_panel_style(daily_panel)
	var daily_vbox := VBoxContainer.new()
	daily_vbox.add_theme_constant_override("separation", UITheme.GRID)
	daily_panel.add_child(daily_vbox)
	var daily_title := Label.new()
	daily_title.text = "日常历练"
	UITheme.apply_title_font(daily_title)
	daily_vbox.add_child(daily_title)
	_daily_vbox = VBoxContainer.new()
	_daily_vbox.name = "DailyCards"
	_daily_vbox.add_theme_constant_override("separation", 0)
	daily_vbox.add_child(_daily_vbox)
	inner.add_child(daily_panel)

	var weekly_panel := PanelContainer.new()
	weekly_panel.name = "WeeklyPanel"
	UITheme.apply_panel_style(weekly_panel)
	var weekly_vbox := VBoxContainer.new()
	weekly_vbox.add_theme_constant_override("separation", UITheme.GRID)
	weekly_panel.add_child(weekly_vbox)
	var weekly_title := Label.new()
	weekly_title.text = "周常历练"
	UITheme.apply_title_font(weekly_title)
	weekly_vbox.add_child(weekly_title)
	_weekly_vbox = VBoxContainer.new()
	_weekly_vbox.name = "WeeklyCards"
	_weekly_vbox.add_theme_constant_override("separation", 0)
	weekly_vbox.add_child(_weekly_vbox)
	inner.add_child(weekly_panel)

func refresh() -> void:
	if not _built:
		_build()
	_populate()

func _is_locked() -> bool:
	var 等级 := 1
	var 引导 := 0
	if is_instance_valid(Game):
		var 等级v = Game.get("门派等级")
		等级 = int(等级v) if 等级v != null else 1
		var 引导v = Game.get("引导阶段")
		引导 = int(引导v) if 引导v != null else 0
	return (等级 < 3 and 引导 < 6)

func _奖励系数() -> float:
	if is_instance_valid(Game) and Game.has_method("任务奖励系数"):
		return float(Game.任务奖励系数())
	return 1.0

func _progress_summary() -> String:
	var 日常总数 := 0
	var 日常已领数 := 0
	var 周常状态 := "未领"
	if is_instance_valid(Game):
		var 日常 = Game.get("当前日常")
		if 日常 is Array:
			日常总数 = 日常.size()
		var 已领 = Game.get("日常已领")
		if 已领 is Array:
			for b in 已领:
				if bool(b):
					日常已领数 += 1
		var 周常已领v = Game.get("周常已领")
		周常状态 = "已领" if bool(周常已领v) else "未领"
	return "日常 %d/%d  周常 %s" % [日常已领数, 日常总数, 周常状态]

func _populate() -> void:
	var locked = _is_locked()
	_lock_bar.visible = locked
	_progress_label.text = _progress_summary()

	for child in _daily_vbox.get_children():
		_daily_vbox.remove_child(child)
		child.queue_free()
	if is_instance_valid(Game):
		var 日常 = Game.get("当前日常")
		if 日常 is Array:
			for i in range(日常.size()):
				var q = 日常[i]
				if q is Dictionary:
					_add_daily_card(i, q, locked)

	for child in _weekly_vbox.get_children():
		_weekly_vbox.remove_child(child)
		child.queue_free()
	if is_instance_valid(Game):
		var 周常 = Game.get("当前周常")
		if 周常 is Dictionary and not 周常.is_empty():
			_add_weekly_card(周常, locked)
		else:
			var empty := Label.new()
			empty.text = "本周无周常"
			UITheme.apply_aux_font(empty)
			_weekly_vbox.add_child(empty)

func _add_daily_card(i: int, q: Dictionary, locked: bool) -> void:
	var card := PanelContainer.new()
	card.name = "Daily_%d" % i
	card.custom_minimum_size = Vector2(0, UITheme.GRID * 9)
	UITheme.apply_panel_style(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	card.add_child(vbox)

	var l1 := HBoxContainer.new()
	l1.add_theme_constant_override("separation", UITheme.GRID)
	var 名称 := Label.new()
	名称.text = str(q.get("quest_name", "—"))
	名称.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_body_font(名称)
	l1.add_child(名称)
	var 类型 := Label.new()
	类型.text = str(q.get("quest_type", "—"))
	UITheme.apply_aux_font(类型)
	l1.add_child(类型)
	var 难度 := Label.new()
	难度.text = str(q.get("difficulty", "—"))
	UITheme.apply_aux_font(难度)
	l1.add_child(难度)
	vbox.add_child(l1)

	var 目标文本 = str(q.get("target_desc", "—"))
	var 数量 = q.get("target_num", null)
	if 数量 != null and (typeof(数量) == TYPE_INT or typeof(数量) == TYPE_FLOAT):
		目标文本 = str(q.get("target_desc", "—")) + "×" + str(int(数量))
	var 目标 := Label.new()
	目标.text = 目标文本
	UITheme.apply_aux_font(目标)
	vbox.add_child(目标)

	var 系数 = _奖励系数()
	var 石 = q.get("reward_lingjing", null)
	var 气 = q.get("reward_lingqi", null)
	var 石文本 := "—"
	var 气文本 := "—"
	if 石 != null and (typeof(石) == TYPE_INT or typeof(石) == TYPE_FLOAT):
		石文本 = str(int(float(石) * 系数))
	if 气 != null and (typeof(气) == TYPE_INT or typeof(气) == TYPE_FLOAT):
		气文本 = str(int(float(气) * 系数))
	var 奖励 := Label.new()
	奖励.text = "灵石%s / 灵气%s" % [石文本, 气文本]
	UITheme.apply_value_font(奖励, false)
	vbox.add_child(奖励)

	var 领取 := Button.new()
	领取.name = "ClaimDaily_%d" % i
	领取.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	UITheme.apply_primary_button_style(领取)
	var 已领 := false
	if is_instance_valid(Game):
		var 已领列表 = Game.get("日常已领")
		if 已领列表 is Array and i < 已领列表.size():
			已领 = bool(已领列表[i])
	if 已领:
		领取.text = "已领"
		领取.disabled = true
	elif locked:
		领取.text = "🔒 领取"
		领取.disabled = true
		领取.tooltip_text = "宗门 Lv.3 或完成引导后开启历练"
	else:
		领取.text = "领取"
		领取.disabled = false
	领取.pressed.connect(_on_领取日常_pressed.bind(i))
	vbox.add_child(领取)

	_daily_vbox.add_child(card)
	_daily_vbox.add_child(UITheme.make_divider_control())

func _add_weekly_card(q: Dictionary, locked: bool) -> void:
	var card := PanelContainer.new()
	card.name = "Weekly"
	card.custom_minimum_size = Vector2(0, UITheme.GRID * 9)
	UITheme.apply_panel_style(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	card.add_child(vbox)

	var l1 := HBoxContainer.new()
	l1.add_theme_constant_override("separation", UITheme.GRID)
	var 名称 := Label.new()
	名称.text = str(q.get("quest_name", "—"))
	名称.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_body_font(名称)
	l1.add_child(名称)
	var 类型 := Label.new()
	类型.text = str(q.get("quest_type", "—"))
	UITheme.apply_aux_font(类型)
	l1.add_child(类型)
	var 难度 := Label.new()
	难度.text = str(q.get("difficulty", "—"))
	UITheme.apply_aux_font(难度)
	l1.add_child(难度)
	vbox.add_child(l1)

	var 目标文本 = str(q.get("target_desc", "—"))
	var 数量 = q.get("target_num", null)
	if 数量 != null and (typeof(数量) == TYPE_INT or typeof(数量) == TYPE_FLOAT):
		目标文本 = str(q.get("target_desc", "—")) + "×" + str(int(数量))
	var 目标 := Label.new()
	目标.text = 目标文本
	UITheme.apply_aux_font(目标)
	vbox.add_child(目标)

	var 系数 = _奖励系数()
	var 石 = q.get("reward_lingjing", null)
	var 气 = q.get("reward_lingqi", null)
	var 石文本 := "—"
	var 气文本 := "—"
	if 石 != null and (typeof(石) == TYPE_INT or typeof(石) == TYPE_FLOAT):
		石文本 = str(int(float(石) * 系数))
	if 气 != null and (typeof(气) == TYPE_INT or typeof(气) == TYPE_FLOAT):
		气文本 = str(int(float(气) * 系数))
	var 奖励 := Label.new()
	奖励.text = "灵石%s / 灵气%s" % [石文本, 气文本]
	UITheme.apply_value_font(奖励, false)
	vbox.add_child(奖励)

	var 领取 := Button.new()
	领取.name = "ClaimWeekly"
	领取.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	UITheme.apply_primary_button_style(领取)
	var 已领 := false
	if is_instance_valid(Game):
		已领 = bool(Game.get("周常已领"))
	if 已领:
		领取.text = "已领"
		领取.disabled = true
	elif locked:
		领取.text = "🔒 领取"
		领取.disabled = true
		领取.tooltip_text = "宗门 Lv.3 或完成引导后开启历练"
	else:
		领取.text = "领取"
		领取.disabled = false
	领取.pressed.connect(_on_领取周常_pressed)
	vbox.add_child(领取)

	_weekly_vbox.add_child(card)
	_weekly_vbox.add_child(UITheme.make_divider_control())

func _on_领取日常_pressed(i: int) -> void:
	领取日常请求.emit(i)

func _on_领取周常_pressed() -> void:
	领取周常请求.emit()

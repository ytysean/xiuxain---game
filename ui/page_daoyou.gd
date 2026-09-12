extends Control

# 道友页（07屏「社交 · 道友」实机落地）。
# 1:1 复刻 Ardot 2:61：顶部返回+添加、三 Tab（好友/宗门/聊天）、好友列表卡、最近消息、底部输入栏。
# 顶部标题按需求已移除，仅保留统一返回箭头（与其它子页一致）。
# S1 红线：纯展示 + 入口，讯息只读 Game Autoload；当前 Game 无道友/聊天讯息，用占位样本，待真讯息接入。

signal 返回主页

const CARD_W: float = 448.0
const CARD_H: float = 72.0
const LIST_X: float = 16.0
const LIST_Y: float = 102.0
const LIST_DY: float = 80.0

var _built: bool = false
var _current_tab: String = "好友"
var _tab_btns: Dictionary = {}
var _list_parent: Control = null
var _chat_parent: Control = null

# 占位样本（Game 无道友/聊天讯息时回落；读到即切真值，零侵入）
const SAMPLE_FRIENDS: Array = [
	{"name": "青岚子", "status": "在线 · 筑基初期", "sel": true},
	{"name": "玄机真人", "status": "离线 · 金丹圆满", "sel": false},
]
const SAMPLE_MSG: Dictionary = {"name": "青岚子", "text": "师兄今日可要论道？", "time": "10:23"}

func _ready() -> void:
	_build()
	_populate()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 二级页工业化背景（决策 4 升级：顶部氛围场景图 + 下方不透明纯色内容区）
	UITheme.make_scene_background(self)

	_build_top_bar()
	_build_tabs()
	_build_friend_list()
	_build_chat()
	_build_input_bar()

func _build_top_bar() -> void:
	var back: Button = UITheme.make_back_button(_on_back_pressed)
	_place(back, 16.0, 8.0, 40.0, 40.0)
	add_child(back)

	# 添加按钮（圆角18，暗金描边，金色 +）
	var add := Button.new()
	add.name = "AddBtn"
	add.flat = true
	add.text = ""
	_place(add, 428.0, 10.0, 36.0, 36.0)
	add.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb: StyleBox = UITheme.make_panel_stylebox_flat(UITheme.C01_AVATAR_BG, UITheme.C01_GOLD_LINE, 18, 1)
	add.add_theme_stylebox_override("normal", sb)
	add.add_theme_stylebox_override("pressed", sb)
	add.add_theme_stylebox_override("hover", sb)
	add.add_theme_stylebox_override("focus", sb)
	add.pressed.connect(_on_add_pressed)
	add_child(add)

	var plus := Label.new()
	plus.text = "+"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(plus, 0.0, 0.0, 36.0, 36.0)
	UITheme.apply_title_font_sized(plus, UITheme.FONT_TITLE)
	plus.add_theme_color_override("font_color", UITheme.C05_TEXT_GOLD)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add.add_child(plus)

func _build_tabs() -> void:
	var tabs: Array = [{"id": "好友", "x": 16.0}, {"id": "宗门", "x": 168.0}, {"id": "聊天", "x": 320.0}]
	for t in tabs:
		var b := Button.new()
		b.name = "Tab_" + t["id"]
		b.flat = true
		b.text = ""
		_place(b, float(t["x"]), 62.0, 144.0, 34.0)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pressed.connect(_on_tab_pressed.bind(t["id"]))
		add_child(b)
		_tab_btns[t["id"]] = b
		_mk_label(b, "TabLabel_" + t["id"], t["id"], 0.0, 0.0, 144.0, 34.0,
			13, UITheme.C05_TEXT_SECONDARY, false, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)
	_update_tab_styles()

func _update_tab_styles() -> void:
	for id in _tab_btns.keys():
		var b: Button = _tab_btns[id]
		if b == null:
			continue
		var active: bool = (id == _current_tab)
		var bg: Color = UITheme.C01_AVATAR_BG if active else Color(0, 0, 0, 0)
		var sb: StyleBox = UITheme.make_panel_stylebox_flat(bg, Color(0, 0, 0, 0), 8, 0)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("focus", sb)
		var lbl: Label = b.get_node_or_null("TabLabel_" + id)
		if lbl != null:
			if active:
				UITheme.apply_title_font_sized(lbl, UITheme.FONT_BODY)
				lbl.add_theme_color_override("font_color", UITheme.C05_TEXT_GOLD)
			else:
				UITheme.apply_body_font_sized(lbl, UITheme.FONT_BODY)
				lbl.add_theme_color_override("font_color", UITheme.C05_TEXT_SECONDARY)

func _build_friend_list() -> void:
	_list_parent = Control.new()
	_list_parent.name = "FriendList"
	_place(_list_parent, 0.0, LIST_Y, 480.0, 348.0)
	_list_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list_parent)

func _build_chat() -> void:
	_chat_parent = Control.new()
	_chat_parent.name = "ChatPreview"
	_place(_chat_parent, 0.0, 450.0, 480.0, 348.0)
	_chat_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chat_parent)

func _populate() -> void:
	if _list_parent == null or _chat_parent == null:
		return
	for child in _list_parent.get_children():
		_list_parent.remove_child(child)
		child.queue_free()
	for child in _chat_parent.get_children():
		_chat_parent.remove_child(child)
		child.queue_free()

	_refresh_tab()

func _refresh_tab() -> void:
	# 按当前 Tab 派发到不同讯息源
	match _current_tab:
		"好友":
			_populate_friends()
			_populate_msgs()
		"宗门":
			_populate_sect()
			_populate_msgs()
		"聊天":
			_populate_msgs_long()
		_:
			_populate_friends()

func _populate_friends() -> void:
	var friends: Array = _read_friends()
	var i: int = 0
	for f in friends:
		_make_friend_card(f, LIST_X, float(i) * LIST_DY + 10.0)
		i += 1

func _populate_msgs() -> void:
	_mk_label(_chat_parent, "ChatTitle", "最近消息", 16.0, 10.0, 448.0, 20.0,
		14, UITheme.C05_TEXT_PRIMARY, true, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, false)
	var msgs: Array = _read_msgs()
	if msgs.is_empty():
		_mk_label(_chat_parent, "ChatEmpty", "（尚无消息）", 16.0, 40.0, 448.0, 20.0,
			12, UITheme.C05_TEXT_TERTIARY, false, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, false)
		return
	# 最近 5 条
	for k in range(mini(5, msgs.size())):
		_make_msg_row(msgs[k], 36.0 + float(k) * 44.0)

func _populate_msgs_long() -> void:
	_mk_label(_chat_parent, "ChatTitle", "聊天 · 与道友往来", 16.0, 10.0, 448.0, 20.0,
		14, UITheme.C05_TEXT_PRIMARY, true, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, false)
	var msgs: Array = _read_msgs()
	if msgs.is_empty():
		_mk_label(_chat_parent, "ChatEmpty", "（尚无消息）", 16.0, 40.0, 448.0, 20.0,
			12, UITheme.C05_TEXT_TERTIARY, false, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, false)
		return
	# 全部消息
	for k in range(msgs.size()):
		_make_msg_row(msgs[k], 36.0 + float(k) * 44.0)

func _populate_sect() -> void:
	_mk_label(_list_parent, "SectTitle", "宗门 · 同门", 16.0, 10.0, 448.0, 20.0,
		14, UITheme.C05_TEXT_PRIMARY, true, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, false)
	if not is_instance_valid(Game):
		return
	var 列表 = Game.get("弟子列表")
	if not (列表 is Array) or 列表.is_empty():
		_mk_label(_list_parent, "SectEmpty", "（尚无弟子）", 16.0, 40.0, 448.0, 20.0,
			12, UITheme.C05_TEXT_TERTIARY, false, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, false)
		return
	var i: int = 0
	for d in 列表:
		if d == null:
			continue
		var 名: String = str(d.get("姓名", "—")) if d is Object else "—"
		var 境界: String = str(d.get("境界", "")) if d is Object else ""
		var 战力: int = int(d.get("战力", 0)) if d is Object and d.get("战力") != null else 0
		var f: Dictionary = {"name": 名, "status": ("%s · 战力 %d" % [境界, 战力]) if 境界 != "" else "· 战力 %d" % 战力, "sel": false}
		_make_friend_card(f, LIST_X, float(i) * LIST_DY + 40.0)
		i += 1

func _read_friends() -> Array:
	if is_instance_valid(Game) and Game.has_method("获取所有道友列表"):
		var raw = Game.获取所有道友列表()
		if raw is Array and not raw.is_empty():
			var out: Array = []
			for d in raw:
				if d is Dictionary:
					var 好感度: int = int(d.get("好感度", 50))
					out.append({
						"name": str(d.get("name", "")),
						"status": "%s · 好感%d" % [str(d.get("status", "")), 好感度],
						"sel": false,
					})
				else:
					out.append({"name": str(d), "status": "在线 · 同道", "sel": false})
			return out
	return SAMPLE_FRIENDS

func _read_msgs() -> Array:
	if is_instance_valid(Game) and Game.has_method("道友消息"):
		var raw = Game.道友消息()
		if raw is Array:
			return raw
	return []

func _make_friend_card(f: Dictionary, x: float, y: float) -> void:
	var card := Panel.new()
	card.name = "Friend_" + str(f.get("name", "?"))
	_place(card, x, y, CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox_flat(UITheme.C01_FLOAT_BG, Color(0, 0, 0, 0), 10, 0))
	_list_parent.add_child(card)

	# 头像（选中青描边 / 未选中暗青描边）
	var av := Panel.new()
	av.name = "Avatar"
	_place(av, 10.0, 14.0, 44.0, 44.0)
	var stroke: Color = UITheme.C05_FRIEND_CYAN if f.get("sel", false) else UITheme.C01_EYE_BORDER
	av.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox_flat(UITheme.C01_AVATAR_BG, stroke, 22, 1))
	card.add_child(av)

	_mk_label(card, "Name", str(f.get("name", "")), 64.0, 12.0, 270.0, 20.0,
		14, UITheme.C05_TEXT_PRIMARY, true, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, false)
	_mk_label(card, "Status", str(f.get("status", "")), 64.0, 36.0, 270.0, 16.0,
		11, UITheme.C05_TEXT_SECONDARY, false, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, false)

	# 右侧：互动按钮
	var act := Button.new()
	act.name = "Interact"
	act.text = "互动"
	act.flat = true
	_place(act, 344.0, 18.0, 94.0, 36.0)
	act.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb: StyleBox = UITheme.make_panel_stylebox_flat(Color(0, 0, 0, 0), UITheme.C01_GOLD_LINE, 8, 1)
	act.add_theme_stylebox_override("normal", sb)
	act.add_theme_stylebox_override("pressed", sb)
	act.add_theme_stylebox_override("hover", sb)
	act.add_theme_stylebox_override("focus", sb)
	UITheme.apply_body_font_sized(act, UITheme.FONT_AUX)
	act.add_theme_color_override("font_color", UITheme.C05_TEXT_GOLD)
	act.pressed.connect(_on_interact_pressed.bind(f.get("name", "")))
	card.add_child(act)

func _make_msg_row(m: Dictionary, y: float) -> void:
	var row := Panel.new()
	row.name = "Msg"
	_place(row, 16.0, y, 448.0, 36.0)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox_flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	_chat_parent.add_child(row)

	var av := Panel.new()
	av.name = "Avatar"
	_place(av, 0.0, 0.0, 36.0, 36.0)
	av.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox_flat(UITheme.C01_AVATAR_BG, Color(0, 0, 0, 0), 18, 0))
	row.add_child(av)

	_mk_label(row, "Who", str(m.get("name", "")), 44.0, 0.0, 80.0, 16.0,
		12, UITheme.C05_TEXT_PRIMARY, true, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, false)
	_mk_label(row, "Text", str(m.get("text", "")), 110.0, 1.0, 305.0, 16.0,
		12, UITheme.C05_TEXT_SECONDARY, false, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, false)
	_mk_label(row, "Time", str(m.get("time", "")), 423.0, 11.0, 25.0, 14.0,
		10, UITheme.C05_TEXT_TERTIARY, false, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, false)

func _build_input_bar() -> void:
	var bar := Control.new()
	bar.name = "InputBar"
	# 修复（实机验收抓出 · 2026-09-12）：本页按 480×854 设计画布硬坐标布局，×UI_SCALE(2.25)
	# 得画布高 1921.5；但二级页容器高 = 视口 1920 − 顶栏 158 = 1762 → 输入栏被算到 y=1795.5，
	# 整条「输入消息 / 发送」落在屏幕之外（用户既看不到也点不到）。改为贴父容器底部锚定。
	bar.anchor_left = 0.0
	bar.anchor_top = 1.0
	bar.anchor_right = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 0.0
	bar.offset_top = -56.0 * UITheme.UI_SCALE
	bar.offset_right = 0.0
	bar.offset_bottom = 0.0
	add_child(bar)

	var bg := ColorRect.new()
	bg.name = "BarBg"
	_place(bg, 0.0, 0.0, 480.0, 56.0)
	bg.color = UITheme.C01_TOPBAR_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg)

	var field := Panel.new()
	field.name = "InputField"
	_place(field, 16.0, 8.0, 376.0, 40.0)
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox_flat(UITheme.C05_PROG_TRACK, UITheme.C01_EYE_BORDER, 20, 1))
	bar.add_child(field)

	var edit := LineEdit.new()
	edit.name = "InputEdit"
	edit.placeholder_text = "输入消息..."
	edit.position = Vector2(14.0, 6.0)
	edit.size = Vector2(348.0, 28.0)
	edit.max_length = 80
	edit.caret_blink = true
	field.add_child(edit)

	var send := Button.new()
	send.name = "SendBtn"
	send.text = "发送"
	send.flat = true
	_place(send, 400.0, 8.0, 64.0, 40.0)
	send.mouse_filter = Control.MOUSE_FILTER_STOP
	var grad: StyleBox = UITheme.make_panel_stylebox_flat(UITheme.C05_BTN_GRAD, Color(0, 0, 0, 0), 20, 0)
	send.add_theme_stylebox_override("normal", grad)
	send.add_theme_stylebox_override("pressed", grad)
	send.add_theme_stylebox_override("hover", grad)
	send.add_theme_stylebox_override("focus", grad)
	UITheme.apply_button_label(send, true)
	send.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
	send.pressed.connect(_on_send_pressed)
	bar.add_child(send)

# ───────── helper ─────────
func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	var s: float = UITheme.UI_SCALE
	c.layout_mode = 0
	c.offset_left = x * s
	c.offset_top = y * s
	c.offset_right = (x + w) * s
	c.offset_bottom = (y + h) * s
	c.size = Vector2(w * s, h * s)

func _mk_label(parent: Control, nm: String, txt: String, x: float, y: float, w: float, h: float,
		font_size: int, color: Color, bold: bool, align_h: int, align_v: int, shadow: bool) -> Label:
	var lbl := Label.new()
	lbl.name = nm
	lbl.text = txt
	_place(lbl, x, y, w, h)
	lbl.horizontal_alignment = align_h
	lbl.vertical_alignment = align_v
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = true
	# 字号收口到统一阶梯（消除跨页尺寸漂移），保留 bold/regular 字重
	var fsz: int
	if font_size <= 12:
		fsz = UITheme.FONT_AUX
	elif font_size <= 14:
		fsz = UITheme.FONT_BODY
	elif font_size <= 17:
		fsz = UITheme.FONT_H2
	else:
		fsz = UITheme.FONT_TITLE
	if bold:
		UITheme.apply_title_font_sized(lbl, fsz)
	else:
		UITheme.apply_body_font_sized(lbl, fsz)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl

# ───────── 交互 ─────────
func _on_back_pressed() -> void:
	返回主页.emit()

func _on_tab_pressed(id: String) -> void:
	_current_tab = id
	_update_tab_styles()
	_refresh_tab()

func _on_add_pressed() -> void:
	# 弹出 LineEdit 模态：让玩家输入道友名 → 真追加到 Game.道友列表 + save_game
	if not is_instance_valid(Game):
		_toast("道友功法未接入")
		return
	if not Game.has_method("道友列表") or not Game.has_method("save_game"):
		_toast("道友功法功法未实现")
		return
	_弹输入框("添加道友", "输入道友名（例：清岚子）", "", func(name: String, dialog: Control):
		if name == "":
			_toast("道号不可为空")
			return
		var 果: Dictionary = Game.添加道友(name)
		if Game.has_method("记任务进度"):
			Game.记任务进度("add_friend")
		_toast(str(果.get("原因", "操作完成")))
		dialog.queue_free()
		_refresh_tab()
	)

func _on_interact_pressed(name: String) -> void:
	# 互动：给道友送礼（提升好感度）
	if not is_instance_valid(Game) or not Game.has_method("给道友送礼"):
		_toast("道友互动功能未接入")
		return
	var 果: Dictionary = Game.给道友送礼(name, 100)
	_toast(str(果.get("原因", "互动完成")))
	_refresh_tab()

func _on_send_pressed() -> void:
	# 发送：从 LineEdit 取文本 → 追加到 Game.道友消息 + save_game + 刷新聊天
	var edit: LineEdit = get_node_or_null("InputBar/InputField/InputEdit")
	if edit == null or edit.text.strip_edges() == "":
		_toast("请输入传讯内容")
		return
	if not is_instance_valid(Game) or not Game.has_method("道友消息"):
		_toast("聊天功法未接入")
		return
	var 时: Dictionary = Time.get_time_dict_from_system()
	var 时间: String = "%02d:%02d" % [int(时.get("hour", 0)), int(时.get("minute", 0))]
	var 名: String = "我"
	var f_list = Game.道友列表()
	if f_list is Array and not f_list.is_empty():
		名 = str(f_list[0])
	var 果: Dictionary = Game.发送道友消息(名, edit.text.strip_edges())
	edit.text = ""
	_toast(str(果.get("原因", "传讯已发出")))
	_refresh_tab()

# ───────── 模态输入框（复用：添加道友）─────────
func _弹输入框(title: String, placeholder: String, default_text: String, on_ok: Callable) -> void:
	var dim := ColorRect.new()
	dim.name = "ModalDim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var box := Panel.new()
	box.name = "ModalBox"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.size = Vector2(360.0, 160.0)
	box.offset_left = -180.0
	box.offset_right = 180.0
	box.offset_top = -80.0
	box.offset_bottom = 80.0
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox_flat(
		UITheme.C01_AVATAR_BG,
		UITheme.C01_GOLD_LINE, 12, 1))
	dim.add_child(box)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.position = Vector2(120.0, 12.0)
	title_lbl.size = Vector2(120.0, 24.0)
	UITheme.apply_title_font_sized(title_lbl, UITheme.FONT_TITLE)
	title_lbl.add_theme_color_override("font_color", UITheme.C05_TEXT_GOLD)
	box.add_child(title_lbl)

	var edit := LineEdit.new()
	edit.name = "InputEdit"
	edit.text = default_text
	edit.position = Vector2(20.0, 48.0)
	edit.size = Vector2(320.0, 36.0)
	edit.placeholder_text = placeholder
	box.add_child(edit)

	var ok := Button.new()
	ok.text = "应允"
	ok.position = Vector2(178.0, 100.0)
	ok.size = Vector2(72.0, 36.0)
	box.add_child(ok)
	ok.pressed.connect(func() -> void:
		on_ok.call(edit.text.strip_edges(), dim)
	)

	var cancel := Button.new()
	cancel.text = "作罢"
	cancel.position = Vector2(258.0, 100.0)
	cancel.size = Vector2(72.0, 36.0)
	cancel.pressed.connect(func() -> void:
		dim.queue_free()
	)
	box.add_child(cancel)

	edit.grab_focus()

func _toast(msg: String) -> void:
	if is_instance_valid(Game) and Game.has_method("toast"):
		Game.添加提示(msg)




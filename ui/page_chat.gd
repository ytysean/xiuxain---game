extends Control

# ===== S56-P1 心弦（原「宗门频道」）=====
# 修真世界观：门人以心念传音，宗主可插话。
# B7（UX §4.13）：聊天融入首页「宗门气象」带 + 抽屉，不做独立大页。
#   → 新增 嵌入模式：嵌入抽屉时只建「心念滚动区 + 传音输入区」，
#     不建全屏底与标题栏（避免与抽屉标题重复）。独立页调用方式不变（默认 false）。
# 红线（F3）：禁 emoji、禁硬编码色 —— 一律走 UITheme const / 样式方法。

## 嵌入模式：true 时不自建全屏底与标题栏（供首页「宗门气象」抽屉内嵌）。
var 嵌入模式: bool = false

var _content: VBoxContainer = null
var _输入框: LineEdit = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	if not 嵌入模式:
		# 独立页背景（嵌入时不建，由宿主抽屉提供底）
		var bg: ColorRect = ColorRect.new()
		bg.color = UITheme.COLOR_STATUSBAR_BG
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	# 主容器
	var main: VBoxContainer = VBoxContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 8)
	main.add_theme_constant_override("margin_left", UITheme.MARGIN)
	main.add_theme_constant_override("margin_right", UITheme.MARGIN)
	add_child(main)

	if not 嵌入模式:
		# 标题栏（嵌入时由宿主抽屉提供标题）
		var header: HBoxContainer = HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		main.add_child(header)

		var title: Label = Label.new()
		title.text = "心弦"
		UITheme.apply_project_font(title, UITheme.FONT_H1, true)
		title.add_theme_color_override("font_color", UITheme.获取主文字色())
		header.add_child(title)

		header.add_spacer(false)

		var close_btn: Button = Button.new()
		close_btn.text = "◇"
		close_btn.custom_minimum_size = Vector2(40, 36)
		UITheme.apply_secondary_button_style(close_btn)
		close_btn.pressed.connect(_on_close)
		header.add_child(close_btn)

	# 说明
	var tip: Label = Label.new()
	tip.text = "（门人心念所至，皆显于此）"
	UITheme.apply_project_font(tip, UITheme.FONT_BODY, false)
	tip.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_DIM)
	main.add_child(tip)

	# 心念记录滚动区
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)

	# 传音输入区
	var input_row: HBoxContainer = HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	main.add_child(input_row)

	_输入框 = LineEdit.new()
	_输入框.placeholder_text = "以心念传音…"
	_输入框.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_输入框.custom_minimum_size = Vector2(0, 36)
	input_row.add_child(_输入框)

	var send_btn: Button = Button.new()
	send_btn.text = "传音"
	send_btn.custom_minimum_size = Vector2(80, 36)
	UITheme.apply_primary_button_style(send_btn)
	send_btn.pressed.connect(_on_send)
	input_row.add_child(send_btn)

	_refresh()

func _refresh() -> void:
	if _content == null:
		return
	# 清空
	for child in _content.get_children():
		child.queue_free()

	var 心念记录: Array = Game.消息系统.获取宗门聊天(50)
	if 心念记录.is_empty():
		var 空: Label = Label.new()
		空.text = "（门人静默，暂无心念）"
		空.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		空.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_DIM)
		_content.add_child(空)
		return

	# 显示心念记录（倒序，最新在底部）
	for i in range(心念记录.size() - 1, -1, -1):
		var msg: Dictionary = 心念记录[i]
		_build心念卡片(msg)

func _build心念卡片(msg: Dictionary) -> void:
	var 是玩家: bool = bool(msg.get("是玩家", false))
	var 发送者: String = str(msg.get("发送者", ""))
	var 内容: String = str(msg.get("内容", ""))

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)

	# 发送者
	var 发送者标签: Label = Label.new()
	if 是玩家:
		发送者标签.text = "【宗主】"
		发送者标签.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	else:
		发送者标签.text = "%s：" % 发送者
		发送者标签.add_theme_color_override("font_color", UITheme.C01_TEXT_JADE)
	UITheme.apply_project_font(发送者标签, UITheme.FONT_BODY, false)
	发送者标签.custom_minimum_size = Vector2(100, 0)
	row.add_child(发送者标签)

	# 内容
	var 内容标签: Label = Label.new()
	内容标签.text = 内容
	内容标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_project_font(内容标签, UITheme.FONT_BODY, false)
	内容标签.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	内容标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(内容标签)

func _on_send() -> void:
	if _输入框 == null:
		return
	var 内容: String = _输入框.text.strip_edges()
	if 内容.is_empty():
		return
	Game.消息系统.发送宗门聊天("宗主", 内容, true)
	_输入框.text = ""
	_refresh()

func _on_close() -> void:
	# 独立页：向上找到 game_ui 并调用 _close_sub_page（嵌入驻主时不建此钮）
	var n: Node = get_parent()
	while n != null:
		if n.has_method("_close_sub_page"):
			n._close_sub_page()
			return
		n = n.get_parent()
	queue_free()

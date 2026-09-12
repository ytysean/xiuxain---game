extends Control

# 灵讯（邮件，GameUI 二级页）：邮件列表 + 全部已读 / 一键领取（本地状态，样例数据）。
# 当前无邮件数据接口（排期表 P1），暂用样例只读展示；接口就绪后改读 Game 邮件 API 即可。

signal 返回主页
signal 邮件领取完成

var _built: bool = false
var _列表: VBoxContainer
var _mails: Array = []
var _详情区域: PanelContainer = null
var _详情标题: Label = null
var _详情发件人: Label = null
var _详情时间: Label = null
var _详情内容: Label = null
var _详情附件: Label = null
var _详情领取按钮: Button = null
var _当前选中索引: int = -1

func _ready() -> void:
	_build()
	refresh()

func _build() -> void:
	if _built:
		return
	_built = true
	_mails = Game.取邮件列表()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content: Control = UITheme.make_scene_background(self)
	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(vbox)

	_build_header(vbox)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", UITheme.GRID)
	var 已读: Button = SecondaryButton.new()
	已读.text = "尽数阅之"
	已读.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	已读.custom_minimum_size = Vector2(0, 36)
	已读.pressed.connect(_on_全部已读)
	actions.add_child(已读)
	var 领取: Button = PrimaryButton.new()
	领取.text = "尽数收取"
	领取.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	领取.custom_minimum_size = Vector2(0, 36)
	领取.pressed.connect(_on_一键领取)
	actions.add_child(领取)
	vbox.add_child(actions)

	# 邮件详情区域（参考魔兽世界风格，点击邮件后显示）
	_详情区域 = PanelContainer.new()
	_详情区域.name = "DetailPanel"
	_详情区域.visible = false
	_详情区域.custom_minimum_size = Vector2(0, 180)
	var detail_sb: StyleBoxFlat = StyleBoxFlat.new()
	detail_sb.bg_color = Color(0.08, 0.12, 0.15)
	detail_sb.set_corner_radius_all(12)
	detail_sb.border_width_left = 2
	detail_sb.border_width_right = 2
	detail_sb.border_width_top = 2
	detail_sb.border_width_bottom = 2
	detail_sb.border_color = Color(0.3, 0.5, 0.6)
	_详情区域.add_theme_stylebox_override("panel", detail_sb)
	var detail_vb := VBoxContainer.new()
	detail_vb.add_theme_constant_override("margin_left", 16)
	detail_vb.add_theme_constant_override("margin_right", 16)
	detail_vb.add_theme_constant_override("margin_top", 12)
	detail_vb.add_theme_constant_override("margin_bottom", 12)
	detail_vb.add_theme_constant_override("separation", 8)
	_详情区域.add_child(detail_vb)
	
	# 详情标题行
	var detail_title_row := HBoxContainer.new()
	detail_title_row.add_theme_constant_override("separation", 8)
	_详情标题 = Label.new()
	_详情标题.name = "DetailTitle"
	UITheme.apply_title_font_sized(_详情标题, UITheme.FONT_TITLE)
	_详情标题.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_title_row.add_child(_详情标题)
	var 关闭详情按钮 := Button.new()
	关闭详情按钮.text = "✕"
	关闭详情按钮.custom_minimum_size = Vector2(32, 32)
	关闭详情按钮.pressed.connect(_on_关闭详情)
	detail_title_row.add_child(关闭详情按钮)
	detail_vb.add_child(detail_title_row)
	
	# 详情发件人和时间
	var detail_meta_row := HBoxContainer.new()
	detail_meta_row.add_theme_constant_override("separation", 16)
	_详情发件人 = Label.new()
	_详情发件人.name = "DetailSender"
	UITheme.apply_aux_font(_详情发件人)
	_详情发件人.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	detail_meta_row.add_child(_详情发件人)
	_详情时间 = Label.new()
	_详情时间.name = "DetailTime"
	UITheme.apply_aux_font(_详情时间)
	_详情时间.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	detail_meta_row.add_child(_详情时间)
	detail_vb.add_child(detail_meta_row)
	
	# 详情内容
	_详情内容 = Label.new()
	_详情内容.name = "DetailContent"
	_详情内容.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_font(_详情内容)
	_详情内容.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vb.add_child(_详情内容)
	
	# 详情附件和领取按钮
	var detail_action_row := HBoxContainer.new()
	detail_action_row.add_theme_constant_override("separation", 16)
	_详情附件 = Label.new()
	_详情附件.name = "DetailAttachment"
	UITheme.apply_aux_font(_详情附件)
	_详情附件.add_theme_color_override("font_color", UITheme.color_text_title1())
	_详情附件.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_action_row.add_child(_详情附件)
	_详情领取按钮 = Button.new()
	_详情领取按钮.name = "DetailClaimBtn"
	_详情领取按钮.text = "收取附件"
	_详情领取按钮.custom_minimum_size = Vector2(120, 36)
	UITheme.apply_primary_button_style(_详情领取按钮)
	_详情领取按钮.pressed.connect(_on_详情领取)
	detail_action_row.add_child(_详情领取按钮)
	detail_vb.add_child(detail_action_row)
	
	vbox.add_child(_详情区域)
	
	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_列表 = VBoxContainer.new()
	_列表.name = "List"
	_列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_列表.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_列表)

func _build_header(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.name = "HeaderBar"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	var back: Button = UITheme.make_back_button(_on_back_pressed)
	bar.add_child(back)
	var title := Label.new()
	title.name = "Title"
	title.text = "灵讯"
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			UIHint.show_hint(title, "灵讯", "接收系统消息、奖励发放、事件通知。\n带有附件的灵讯可领取道具奖励。"))
	UITheme.apply_page_title(title)
	bar.add_child(title)
	parent.add_child(bar)

func refresh() -> void:
	if not _built:
		_build()
	_populate()

func _populate() -> void:
	if _列表 == null:
		return
	_mails = Game.取邮件列表()   # 每次重读最新（领取后已领状态会变）
	for c in _列表.get_children():
		_列表.remove_child(c)
		c.queue_free()
	for i in range(_mails.size()):
		_列表.add_child(_建卡(i, _mails[i]))

func _建卡(idx: int, m: Dictionary) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.name = "Mail_%d" % idx
	card.custom_minimum_size = Vector2(0, 84)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.114, 0.141)
	sb.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("margin_left", 16)
	col.add_theme_constant_override("margin_right", 16)
	col.add_theme_constant_override("margin_top", 12)
	col.add_theme_constant_override("margin_bottom", 12)
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	if bool(m.get("未读", false)):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var dsb: StyleBoxFlat = StyleBoxFlat.new()
		dsb.bg_color = Color(0.784, 0.659, 0.416)
		dsb.set_corner_radius_all(5)
		dot.add_theme_stylebox_override("panel", dsb)
		r1.add_child(dot)
	var 发件人 := Label.new()
	发件人.text = str(m.get("发件人", ""))
	UITheme.apply_aux_text(发件人)
	发件人.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	r1.add_child(发件人)
	var 时间 := Label.new()
	时间.text = str(m.get("时间", ""))
	时间.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	时间.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.apply_aux_text(时间)
	时间.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	r1.add_child(时间)
	col.add_child(r1)
	var 标题 := Label.new()
	标题.text = str(m.get("标题", ""))
	UITheme.apply_body_text(标题)
	col.add_child(标题)
	var 附件数据: Dictionary = m.get("附件", {})
	if not 附件数据.is_empty():
		var 已领: bool = bool(m.get("已领", false))
		var 附件文本: String = "附件：" + _格式化附件(附件数据)
		if 已领:
			附件文本 += "（已受领）"
		var 附件标签 := Label.new()
		附件标签.text = 附件文本
		UITheme.apply_aux_text(附件标签)
		附件标签.add_theme_color_override("font_color", UITheme.color_text_title1())
		col.add_child(附件标签)
	card.gui_input.connect(_on_card_clicked.bind(idx))
	return card

func _格式化附件(附件: Dictionary) -> String:
	var 名表: Dictionary = {"灵石": "灵石", "灵气": "灵气", "灵草": "灵草", "矿石": "矿石", "声望": "声望", "绑定仙玉": "绑定仙玉", "皮肤": "外观"}
	var 段: Array = []
	for k in 附件.keys():
		var 名: String = str(名表.get(k, k))
		if k == "皮肤":
			段.append("%s·%s" % [名, str(附件[k])])
		else:
			段.append("%s×%s" % [名, str(附件[k])])
	return "、".join(段)

func _on_card_clicked(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# 先标记已读并显示详情，再延迟刷新列表，避免索引丢失
			Game.标记邮件已读(idx)
			_显示详情(idx)
			refresh.call_deferred()

func _on_全部已读() -> void:
	Game.邮件全部已读()
	refresh()
	# 红点通过Game.邮件变动信号自动刷新

func _on_一键领取() -> void:
	var 列表 = Game.取邮件列表()
	for i in range(列表.size()):
		var m = 列表[i]
		if not m.get("附件", {}).is_empty() and not bool(m.get("已领", false)):
			Game.领取邮件(i)
	refresh()
	邮件领取完成.emit()
	# 红点通过Game.邮件变动信号自动刷新

func _on_back_pressed() -> void:
	返回主页.emit()

# 显示邮件详情（页面内显示，参考魔兽世界风格）
func _显示详情(idx: int) -> void:
	var 邮件列表 = Game.取邮件列表()
	if idx < 0 or idx >= 邮件列表.size():
		return
	var m = 邮件列表[idx]
	_当前选中索引 = idx
	
	# 更新详情区域内容
	_详情标题.text = str(m.get("标题", ""))
	_详情发件人.text = "发件人：" + str(m.get("发件人", ""))
	_详情时间.text = str(m.get("时间", ""))
	_详情内容.text = str(m.get("内容", "此讯无内容"))
	
	# 更新附件显示和领取按钮
	var 附件: Dictionary = m.get("附件", {})
	if not 附件.is_empty():
		var 已领: bool = bool(m.get("已领", false))
		_详情附件.text = "附件：" + _格式化附件(附件) + ("（已受领）" if 已领 else "")
		_详情领取按钮.visible = not 已领
	else:
		_详情附件.text = ""
		_详情领取按钮.visible = false
	
	# 显示详情区域
	_详情区域.visible = true

# 关闭详情区域
func _on_关闭详情() -> void:
	_详情区域.visible = false
	_当前选中索引 = -1

# 详情区域领取按钮
func _on_详情领取() -> void:
	if _当前选中索引 < 0:
		return
	Game.领取邮件(_当前选中索引)
	refresh()
	# 刷新详情显示
	if _当前选中索引 >= 0 and _详情区域.visible:
		_显示详情(_当前选中索引)

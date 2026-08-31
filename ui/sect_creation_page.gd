extends Control

# 创建宗门页（头像选择 v1）：替换原三层捏脸系统。
# 玩法：性别切换 → 头像九宫格（initial 初始可选 + unlock 渠道解锁[锁]）→ 选中头像预览 → 确认创立。
# 头像数据来自 Game.宗主头像目录（catalog）：每条含 id/name/gender/tex/category/channel/unlocked。
# 选中后 emit 创建完成(宗门名, 宗主名, 性别, 头像id)。

signal 创建完成(宗门名: String, 宗主名: String, 性别: String, 头像id: String)

# ── 面板外框 ──
const 面板左: float = 20.0
const 面板右: float = 460.0
const 面板上: float = 14.0          # 稍微上移，给顶部更多空间
const 面板下: float = 840.0         # 距屏底(854)有 14px（面板边框内）
const 内边距: float = 14.0           # 内边距加大
const 内容左: float = 内边距
const 内容右: float = 面板右 - 面板左 - 内边距  # = 412
const 可用宽: float = 内容右 - 内容左              # = 398

# ── 头像网格常量 ──
const 网格列数: int = 3
const 格宽: float = 120.0
const 格高: float = 120.0
const 格间距: float = 10.0

var _性别: String = "男"
var _头像id: String = ""
var _面板: Panel
var _宗门名输入: LineEdit
var _宗主名输入: LineEdit
var _预览: TextureRect
var _预览框: Panel
var _选择标签: Label
var _提示: Label
var _性别按钮: Dictionary = {}
var _cell面板: Array = []
var _滚动容器: ScrollContainer
var _网格内容区: Control

func _ready() -> void:
	_build()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# ═══ 半透明背景遮罩 ═══
	var 遮 := ColorRect.new()
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.color = Color(0.06, 0.08, 0.075, 1.0)
	遮.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(遮)

	# ═══ 主面板 ═══
	_面板 = Panel.new()
	_面板.name = "面板"
	_面板.layout_mode = 0
	_面板.offset_left = 面板左
	_面板.offset_top = 面板上
	_面板.offset_right = 面板右
	_面板.offset_bottom = 面板下
	UITheme.apply_dynamics_panel_style(_面板, 0.92)
	add_child(_面板)

	# ═══ 布局常量（统一 8px 区块间距） ═══
	const 行高: float = 32.0        # 输入行高度（Label+LineEdit居中）
	const 区块间距: float = 8.0     # 统一区块间距离
	var y: float = 12.0             # 当前 Y 游标（从面板内 12px 开始）

	# ── 标题 ──
	var 标题 := Label.new()
	标题.layout_mode = 0
	标题.offset_left = 内容左
	标题.offset_top = y               # 12
	标题.offset_right = 内容右
	标题.offset_bottom = y + 26.0     # 38  (26px高)
	标题.text = "创建你的宗门"
	标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_title_font_sized(标题, _fsz(22.0))
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE2)
	_面板.add_child(标题)
	y += 26.0 + 区块间距              # → 46

	# ── 输入行 1：宗门名 ──
	var 行1 := Control.new()
	行1.layout_mode = 0
	行1.offset_left = 内容左
	行1.offset_top = y                # 46
	行1.offset_right = 内容右
	行1.offset_bottom = y + 行高      # 78
	var lbl名 := Label.new()
	lbl名.layout_mode = 0
	lbl名.offset_left = 0.0
	lbl名.offset_top = 3.0
	lbl名.offset_right = 52.0
	lbl名.offset_bottom = 29.0
	lbl名.text = "宗门名"
	lbl名.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.apply_body_font_sized(lbl名, _fsz(13.0))
	lbl名.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	行1.add_child(lbl名)
	_宗门名输入 = LineEdit.new()
	_宗门名输入.layout_mode = 0
	_宗门名输入.offset_left = 56.0
	_宗门名输入.offset_top = 3.0
	_宗门名输入.offset_right = 可用宽
	_宗门名输入.offset_bottom = 29.0
	_宗门名输入.placeholder_text = "如：太玄宗"
	_apply_input_style(_宗门名输入)
	行1.add_child(_宗门名输入)
	_面板.add_child(行1)
	y += 行高 + 区块间距             # → 86

	# ── 输入行 2：宗主名 ──
	var 行2 := Control.new()
	行2.layout_mode = 0
	行2.offset_left = 内容左
	行2.offset_top = y                # 86
	行2.offset_right = 内容右
	行2.offset_bottom = y + 行高      # 118
	var lbl主 := Label.new()
	lbl主.layout_mode = 0
	lbl主.offset_left = 0.0
	lbl主.offset_top = 3.0
	lbl主.offset_right = 52.0
	lbl主.offset_bottom = 29.0
	lbl主.text = "宗主名"
	lbl主.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.apply_body_font_sized(lbl主, _fsz(13.0))
	lbl主.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	行2.add_child(lbl主)
	_宗主名输入 = LineEdit.new()
	_宗主名输入.layout_mode = 0
	_宗主名输入.offset_left = 56.0
	_宗主名输入.offset_top = 3.0
	_宗主名输入.offset_right = 可用宽
	_宗主名输入.offset_bottom = 29.0
	_宗主名输入.placeholder_text = "如：太玄真君"
	_apply_input_style(_宗主名输入)
	行2.add_child(_宗主名输入)
	_面板.add_child(行2)
	y += 行高 + 区块间距             # → 126

	# ── 性别选择 ──
	var 性别行 := Control.new()
	性别行.layout_mode = 0
	性别行.offset_left = 内容左
	性别行.offset_top = y             # 126
	性别行.offset_right = 内容右
	性别行.offset_bottom = y + 34.0   # 160 (34px高)
	var lbl性 := Label.new()
	lbl性.layout_mode = 0
	lbl性.offset_left = 0.0
	lbl性.offset_top = 3.0
	lbl性.offset_right = 52.0
	lbl性.offset_bottom = 31.0
	lbl性.text = "性别"
	lbl性.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.apply_body_font_sized(lbl性, _fsz(13.0))
	lbl性.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	性别行.add_child(lbl性)
	var 标签区: float = 56.0
	var btn宽: float = (可用宽 - 标签区 - 10.0) / 2.0
	for g in Game.宗主性别预设:
		var b := Button.new()
		b.layout_mode = 0
		var gi: int = Game.宗主性别预设.find(g)
		b.offset_left = 标签区 + gi * (btn宽 + 10.0)
		b.offset_top = 3.0
		b.offset_right = b.offset_left + btn宽
		b.offset_bottom = 31.0
		b.text = g
		b.pressed.connect(_on_性别选择.bind(g))
		_性别按钮[g] = b
		性别行.add_child(b)
	_面板.add_child(性别行)
	_刷新性别按钮()
	y += 34.0 + 区块间距             # → 168

	# ═══ 选中头像预览框 ═══
	_预览框 = Panel.new()
	_预览框.name = "预览框"
	_预览框.layout_mode = 0
	_预览框.offset_left = 内容左
	_预览框.offset_top = y            # 168
	_预览框.offset_right = 内容右
	_预览框.offset_bottom = y + 144.0 # 312 (144px高，舒适预览)
	_预览框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 预览样式 := StyleBoxFlat.new()
	预览样式.bg_color = Color(0.05, 0.07, 0.06, 1.0)
	预览样式.border_color = UITheme.COLOR_BORDER_GOLD
	预览样式.set_corner_radius_all(8)
	预览样式.border_width_left = 1.5
	预览样式.border_width_top = 1.5
	预览样式.border_width_right = 1.5
	预览样式.border_width_bottom = 1.5
	_预览框.add_theme_stylebox_override("panel", 预览样式)
	_面板.add_child(_预览框)

	_预览 = TextureRect.new()
	_预览.name = "预览图"
	_预览.layout_mode = 0
	_预览.offset_left = 内容左 + 8.0
	_预览.offset_top = y + 8.0
	_预览.offset_right = 内容右 - 8.0
	_预览.offset_bottom = y + 136.0
	_预览.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_预览.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_预览.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_面板.add_child(_预览)
	y += 144.0 + 区块间距           # → 320

	# ── 选择标签 ──
	_选择标签 = Label.new()
	_选择标签.name = "选择标签"
	_选择标签.layout_mode = 0
	_选择标签.offset_left = 内容左
	_选择标签.offset_top = y          # 320
	_选择标签.offset_right = 内容右
	_选择标签.offset_bottom = y + 18.0  # 338
	_选择标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_body_font_sized(_选择标签, _fsz(13.0))
	_选择标签.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	_面板.add_child(_选择标签)
	y += 18.0 + 区块间距             # → 346

	# ── ScrollContainer + InnerContent + 头像网格 ──
	_滚动容器 = ScrollContainer.new()
	_滚动容器.name = "网格滚动区"
	_滚动容器.layout_mode = 0
	_滚动容器.offset_left = 内容左
	_滚动容器.offset_top = y          # 346
	_滚动容器.offset_right = 内容右
	_滚动容器.offset_bottom = 面板下 - 96.0  # 744
	_滚动容器.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# 触屏优先：滚动条自动隐藏（AUTO），玩家用手指拖；overflow 仍由 custom_minimum_size 驱动滚动生效。
	_滚动容器.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_滚动容器.mouse_filter = Control.MOUSE_FILTER_STOP
	_滚动容器.focus_mode = Control.FOCUS_CLICK    # Godot 4.7 枚举为 FOCUS_CLICK(值1)，非 FOCUS_CLICKABLE
	_面板.add_child(_滚动容器)

	_网格内容区 = Control.new()
	_网格内容区.name = "网格内容区"
	_网格内容区.layout_mode = 0
	_网格内容区.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_网格内容区.offset_left = 0.0
	_网格内容区.offset_top = 0.0
	_网格控制区高度计算()  # 同时设置 offset_right/bottom + custom_minimum_size，让 ScrollContainer 检测到 overflow
	_滚动容器.add_child(_网格内容区)

	_重建网格()

	# ── 错误提示（默认隐藏） ──
	_提示 = Label.new()
	_提示.layout_mode = 0
	_提示.offset_left = 内容左
	_提示.offset_top = 面板下 - 90.0    # 750
	_提示.offset_right = 内容右
	_提示.offset_bottom = 面板下 - 70.0  # 770
	_提示.text = ""
	_提示.visible = false
	_提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_body_font_sized(_提示, _fsz(13.0))
	_提示.add_theme_color_override("font_color", UITheme.COLOR_TEXT_RED)
	_面板.add_child(_提示)

	# ── 确认按钮 ──
	var 确认 := PrimaryButton.new()
	确认.layout_mode = 0
	确认.custom_minimum_size = Vector2(0, 36.0)
	确认.offset_left = 16.0
	确认.offset_top = 776.0
	确认.offset_right = 424.0
	确认.offset_bottom = 812.0
	确认.text = "创立宗门"
	确认.add_theme_font_size_override("font_size", _fsz(15.0))
	确认.pressed.connect(_on_确认)
	_面板.add_child(确认)

	# 默认选中该性别首个初始头像
	var def: Dictionary = Game.默认解锁头像(_性别)
	_头像id = def.get("id", "")
	_刷新预览()
	_刷新选择标签()

# 依据当前性别头像数量计算网格内容区尺寸（offset_right/bottom + custom_minimum_size，
# 共同驱动 ScrollContainer 检测 overflow 并显示滚动条）
func _网格控制区高度计算() -> void:
	var n: int = Game.宗主头像列表(_性别).size()
	var 行数: int = maxi(1, ceili(float(n) / float(网格列数)))
	var sc_内宽: float = 网格列数 * 格宽 + (网格列数 - 1) * 格间距
	var sc_内高: float = 行数 * 格高 + (行数 - 1) * 格间距
	_网格内容区.offset_right = sc_内宽
	_网格内容区.offset_bottom = sc_内高
	_网格内容区.custom_minimum_size = Vector2(sc_内宽, sc_内高)

func _重建网格() -> void:
	for p in _cell面板:
		if is_instance_valid(p):
			p.queue_free()
	_cell面板.clear()

	if _网格内容区 == null or not is_instance_valid(_网格内容区):
		return

	_网格控制区高度计算()

	var defs: Array = Game.宗主头像列表(_性别)
	var n: int = defs.size()
	for idx in range(n):
		var def: Dictionary = defs[idx]
		var 头像id: String = def.get("id", "")
		var 锁定: bool = not def.get("unlocked", false)

		var 面板格 := Panel.new()
		面板格.layout_mode = 0
		var col: int = idx % 网格列数
		var row_i: int = idx / 网格列数
		面板格.offset_left = float(col) * (格宽 + 格间距)
		面板格.offset_top = float(row_i) * (格高 + 格间距)
		面板格.offset_right = 面板格.offset_left + 格宽
		面板格.offset_bottom = 面板格.offset_top + 格高
		面板格.add_theme_stylebox_override("panel", _格子样式(头像id == _头像id))
		面板格.set_meta("头像id", 头像id)
		面板格.set_meta("锁定", 锁定)
		面板格.mouse_filter = Control.MOUSE_FILTER_STOP
		面板格.gui_input.connect(_on_格子点击.bind(头像id, 锁定))

		# 缩略图
		var tr := TextureRect.new()
		tr.layout_mode = 0
		tr.offset_left = 4.0
		tr.offset_top = 4.0
		tr.offset_right = 格宽 - 4.0
		tr.offset_bottom = 格高 - 20.0
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = Game.取宗主头像纹理(头像id)
		if 锁定:
			tr.modulate = Color(1, 1, 1, 0.28)
		面板格.add_child(tr)

		# 名称 / 锁标
		var tr_name := Label.new()
		tr_name.layout_mode = 0
		tr_name.offset_left = 2.0
		tr_name.offset_top = 格高 - 18.0
		tr_name.offset_right = 格宽 - 2.0
		tr_name.offset_bottom = 格高 - 2.0
		tr_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_body_font_sized(tr_name, _fsz(10.0))
		if 锁定:
			tr_name.text = "🔒 " + def.get("channel", "未解锁")
			tr_name.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
		else:
			tr_name.text = def.get("name", "")
			tr_name.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
		面板格.add_child(tr_name)

		_网格内容区.add_child(面板格)
		_cell面板.append(面板格)

func _on_格子点击(事件: InputEvent, 头像id: String, 锁定: bool) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if 锁定:
			var def: Dictionary = Game.取宗主头像定义(头像id)
			_提示.text = "该头像需通过【%s】解锁" % [def.get("channel", "未知渠道")]
			_提示.visible = true
			return
		_头像id = 头像id
		_提示.visible = false
		_刷新选中()
		_刷新预览()
		_刷新选择标签()

func _on_性别选择(g: String) -> void:
	if g == _性别:
		return
	_性别 = g
	var def: Dictionary = Game.默认解锁头像(_性别)
	_头像id = def.get("id", "")
	_提示.visible = false
	_刷新性别按钮()
	_重建网格()
	_刷新预览()
	_刷新选择标签()

func _刷新选中() -> void:
	for p in _cell面板:
		if not is_instance_valid(p):
			continue
		var id: String = p.get_meta("头像id", "")
		p.add_theme_stylebox_override("panel", _格子样式(id == _头像id))

func _刷新性别按钮() -> void:
	for k in _性别按钮.keys():
		var b: Button = _性别按钮[k]
		var sel: bool = (k == _性别)
		b.add_theme_stylebox_override("normal", _选项卡样式(sel))
		UITheme.apply_body_font_sized(b, _fsz(15.0))
		b.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE2 if sel else UITheme.COLOR_TEXT_BODY_GOLD)

func _刷新预览() -> void:
	if _预览 == null or Game == null or not is_instance_valid(Game):
		return
	var tex: Texture2D = Game.取宗主头像纹理(_头像id)
	if tex != null:
		_预览.texture = tex
		_预览.modulate = Color.WHITE
	else:
		_预览.texture = null
		_预览.modulate = Color(1, 1, 1, 0.3)

func _刷新选择标签() -> void:
	if _选择标签 == null or Game == null or not is_instance_valid(Game):
		return
	var def: Dictionary = Game.取宗主头像定义(_头像id)
	_选择标签.text = "已选头像：%s" % [def.get("name", "—")]

func _apply_input_style(le: LineEdit) -> void:
	le.add_theme_stylebox_override("normal", _input_style(false))
	le.add_theme_stylebox_override("focus", _input_style(true))
	le.add_theme_font_size_override("font_size", _fsz(13.0))

func _input_style(focused: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.COLOR_STATUSBAR_BG
	sb.border_color = UITheme.COLOR_BORDER_GOLD if focused else Color(UITheme.COLOR_BORDER_GOLD.r, UITheme.COLOR_BORDER_GOLD.g, UITheme.COLOR_BORDER_GOLD.b, 0.6)
	sb.set_corner_radius_all(6)
	sb.border_width_left = 1.5
	sb.border_width_top = 1.5
	sb.border_width_right = 1.5
	sb.border_width_bottom = 1.5
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb

func _格子样式(sel: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.COLOR_BG_CONTENT if sel else UITheme.COLOR_PANEL_BG
	sb.border_color = UITheme.COLOR_BORDER_GOLD
	sb.set_corner_radius_all(8)
	sb.border_width_left = 2 if sel else 1
	sb.border_width_top = 2 if sel else 1
	sb.border_width_right = 2 if sel else 1
	sb.border_width_bottom = 2 if sel else 1
	return sb

func _选项卡样式(sel: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.COLOR_BG_CONTENT if sel else UITheme.COLOR_PANEL_BG
	sb.border_color = UITheme.COLOR_BORDER_GOLD
	sb.set_corner_radius_all(6)
	sb.border_width_left = 1.5 if sel else 1
	sb.border_width_top = 1.5 if sel else 1
	sb.border_width_right = 1.5 if sel else 1
	sb.border_width_bottom = 1.5 if sel else 1
	return sb

# 设计稿字号 → 经 UI_SCALE 缩放后的实际字号
func _fsz(design_px: float) -> int:
	return max(6, int(round(design_px / UITheme.UI_SCALE)))

func _on_确认() -> void:
	var 宗: String = _宗门名输入.text.strip_edges()
	var 主: String = _宗主名输入.text.strip_edges()
	if 宗 == "" or 主 == "":
		_提示.text = "宗门名与宗主名均不可为空"
		_提示.visible = true
		return
	创建完成.emit(宗, 主, _性别, _头像id)

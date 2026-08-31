extends Control

# 宗主头像选择弹窗（全屏暗底模态）。
# 复用 UITheme token，零硬编码颜色；头像缩略图复用 avatar_circle_mask.gdshader 裁圆。
# 仅 UI 选择，确认时调用 Game.设置当前头像（内部已做未解锁校验，安全），零玩法/战斗触碰。
# 由 top_bar 以 Control.new() + set_script(load(...)) 实例化，故本文件自包含、无 .tscn 依赖。
# 注：头像框功能已于 2026-08-21 取消，本弹窗仅保留纯头像选择。

const AVATAR_MASK_SHADER: Shader = preload("res://ui/avatar_circle_mask.gdshader")

signal 应用并关闭

# ── 逻辑坐标（480×854）→ 物理（×UI_SCALE）；本弹窗根即满屏，子节点用 _place 物理定位 ──
const 边距: float = 20.0
const 顶栏高: float = 64.0
const 预览顶: float = 64.0
const 预览高: float = 276.0
const 网格顶: float = 388.0
const 底栏高: float = 44.0
const 屏宽: float = 480.0
const 屏高: float = 854.0
const 格间距: float = 10.0
const 格宽逻辑: float = 140.0
const 格高逻辑: float = 140.0

var _selected_avatar: String = ""
var _cells: Array = []
var _性别: String = "男"
var _built: bool = false
var _纹理智缓存: Dictionary = {}

var _shade: ColorRect = null
var _预览: TextureRect = null
var _头像名: Label = null
var _提示: Label = null
var _网格: GridContainer = null
var _格宽: float = 0.0
var _格高: float = 0.0

func _ready() -> void:
	_build()

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var s: float = UITheme.UI_SCALE
	_格宽 = 格宽逻辑 * s
	_格高 = 格高逻辑 * s

	if is_instance_valid(Game):
		_selected_avatar = Game.宗主头像
		_性别 = Game.宗主性别

	# 暗底遮罩（点遮罩关闭）
	_shade = ColorRect.new()
	_shade.name = "Shade"
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(UITheme.C01_SCENE_BASE, 1.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_on_cancel())
	add_child(_shade)

	# 主面板：独立框体（暗底 + 金描边 + 圆角），符合其他子页面规则
	var _主面板 := Panel.new()
	_主面板.name = "MainPanel"
	_place(_主面板, 0.0, 0.0, 屏宽, 屏高)
	_主面板.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 主面板样式 := StyleBoxFlat.new()
	主面板样式.bg_color = UITheme.C01_FLOAT_BG
	主面板样式.border_color = UITheme.C01_TEXT_GOLD
	主面板样式.set_corner_radius_all(int(round(8.0 * UITheme.UI_SCALE)))
	主面板样式.set_border_width_all(int(round(2.0 * UITheme.UI_SCALE)))
	主面板样式.set_content_margin_all(0)
	_主面板.add_theme_stylebox_override("panel", 主面板样式)
	add_child(_主面板)

	_build_header()
	_build_preview()
	_build_grid()
	_build_bottom()

func _build_header() -> void:
	var title := Label.new()
	title.name = "Title"
	_place(title, 0.0, 0.0, 屏宽, 顶栏高)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text = "选择头像"
	UITheme.apply_title_font_sized(title, int(round(22.0 * UITheme.UI_SCALE)))
	title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	add_child(title)

	var close := Button.new()
	close.name = "CloseBtn"
	close.flat = true
	close.text = "✕"
	_place(close, 屏宽 - 边距 - 36.0, 14.0, 36.0, 36.0)
	close.mouse_filter = Control.MOUSE_FILTER_STOP
	var 空样式 := StyleBoxEmpty.new()
	close.add_theme_stylebox_override("normal", 空样式)
	close.add_theme_stylebox_override("pressed", 空样式)
	close.add_theme_stylebox_override("hover", 空样式)
	close.add_theme_stylebox_override("focus", 空样式)
	UITheme.apply_title_font_sized(close, int(round(20.0 * UITheme.UI_SCALE)))
	close.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	close.pressed.connect(_on_cancel)
	add_child(close)

func _build_preview() -> void:
	var cx: float = 屏宽 * 0.5
	var cy: float = 预览顶 + 预览高 * 0.40
	var dia: float = 120.0
	var fdia: float = 175.0

	# 预览容器 Panel：fdia×fdia，全圆角 + 外阴影——让圆头像嵌在背景里。
	var 预览容器 := Panel.new()
	预览容器.name = "PreviewContainer"
	预览容器.custom_minimum_size = Vector2(fdia, fdia)
	_place(预览容器, cx - fdia * 0.5, cy - fdia * 0.5, fdia, fdia)
	预览容器.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prev_sb := StyleBoxFlat.new()
	prev_sb.bg_color = Color(0, 0, 0, 0)
	prev_sb.set_corner_radius_all(int(fdia * 0.5 * UITheme.UI_SCALE))
	prev_sb.shadow_size = 8
	prev_sb.shadow_color = Color(0, 0, 0, 0.30)
	prev_sb.shadow_offset = Vector2(0, 4)
	prev_sb.set_content_margin_all(0)
	预览容器.add_theme_stylebox_override("panel", prev_sb)
	add_child(预览容器)

	# 头像圆（圆形 mask 裁圆）
	_预览 = TextureRect.new()
	_预览.name = "PreviewAvatar"
	_预览.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_预览.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_预览.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_预览.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 头像材质 := ShaderMaterial.new()
	头像材质.shader = AVATAR_MASK_SHADER
	_预览.material = 头像材质
	预览容器.add_child(_预览)

	# 内阴影 vignette（中心透明→边缘 35% 黑，圆形 mask 限圆内）
	var prev_vign: TextureRect = _建渐变覆盖(fdia, fdia, [Color(0, 0, 0, 0), Color(0, 0, 0, 0.15)], GradientTexture2D.FILL_RADIAL)
	prev_vign.name = "PreviewVignette"
	prev_vign.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vign_mat := ShaderMaterial.new()
	vign_mat.shader = AVATAR_MASK_SHADER
	prev_vign.material = vign_mat
	预览容器.add_child(prev_vign)

	# 人物环境光（中心透明→边缘 25% 青绿，圆形 mask 限圆内）
	var prev_env: TextureRect = _建渐变覆盖(fdia, fdia, [Color(0, 0, 0, 0), Color(0.15, 0.25, 0.28, 0.12)], GradientTexture2D.FILL_RADIAL)
	prev_env.name = "PreviewEnvLight"
	prev_env.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var env_mat := ShaderMaterial.new()
	env_mat.shader = AVATAR_MASK_SHADER
	prev_env.material = env_mat
	预览容器.add_child(prev_env)

	_头像名 = Label.new()
	_头像名.name = "PreviewName"
	_place(_头像名, 0.0, cy + dia * 0.5 + 6.0, 屏宽, 22.0)
	_头像名.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_头像名.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.apply_title_font_sized(_头像名, int(round(16.0 * UITheme.UI_SCALE)))
	_头像名.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	add_child(_头像名)

	var hint := Label.new()
	hint.name = "PreviewHint"
	_place(hint, 0.0, 预览顶 + 预览高 - 20.0, 屏宽, 18.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.text = "点击下方网格选择头像"
	UITheme.apply_body_font_sized(hint, int(round(12.0 * UITheme.UI_SCALE)))
	hint.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	add_child(hint)

	# 锁定提示（默认隐藏，点击未解锁格时显示）
	_提示 = Label.new()
	_提示.name = "LockHint"
	_place(_提示, 边距, 296.0, 屏宽 - 边距 * 2.0, 20.0)
	_提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_提示.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_提示.visible = false
	UITheme.apply_body_font_sized(_提示, int(round(12.0 * UITheme.UI_SCALE)))
	_提示.add_theme_color_override("font_color", UITheme.COLOR_TEXT_RED)
	add_child(_提示)

	_刷新预览()
	_预热所有纹理()
	_built = true

func _build_grid() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "GridScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(scroll, 边距, 网格顶, 屏宽 - 边距 * 2.0, 屏高 - 边距 - 网格顶 - 底栏高)
	add_child(scroll)

	_网格 = GridContainer.new()
	_网格.name = "Grid"
	_网格.columns = 3
	_网格.add_theme_constant_override("h_separation", int(round(格间距 * UITheme.UI_SCALE)))
	_网格.add_theme_constant_override("v_separation", int(round(格间距 * UITheme.UI_SCALE)))
	_网格.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_网格.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(_网格)

	_重建网格()

func _build_bottom() -> void:
	var by: float = 屏高 - 边距 - 底栏高
	var bw: float = (屏宽 - 边距 * 3.0) * 0.5
	var bh: float = 底栏高

	var confirm := Button.new()
	confirm.name = "ConfirmBtn"
	confirm.text = "确认使用"
	_place(confirm, 边距, by, bw, bh)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	var c正常: StyleBoxFlat = UITheme.make_panel_stylebox_flat(UITheme.COLOR_BTN_PRIMARY, UITheme.COLOR_BTN_PRIMARY, 8, 2)
	var c按下: StyleBoxFlat = UITheme.make_panel_stylebox_flat(
		Color(UITheme.COLOR_BTN_PRIMARY.r * 0.8, UITheme.COLOR_BTN_PRIMARY.g * 0.8, UITheme.COLOR_BTN_PRIMARY.b * 0.8),
		UITheme.COLOR_BTN_PRIMARY, 8, 2)
	confirm.add_theme_stylebox_override("normal", c正常)
	confirm.add_theme_stylebox_override("pressed", c按下)
	confirm.add_theme_stylebox_override("hover", c正常)
	confirm.add_theme_stylebox_override("focus", c正常)
	UITheme.apply_title_font_sized(confirm, int(round(14.0 * UITheme.UI_SCALE)))
	confirm.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE2)
	confirm.pressed.connect(_on_confirm)
	add_child(confirm)

	var cancel := Button.new()
	cancel.name = "CancelBtn"
	cancel.text = "作罢"
	_place(cancel, 边距 * 2.0 + bw, by, bw, bh)
	cancel.mouse_filter = Control.MOUSE_FILTER_STOP
	var x正常: StyleBoxFlat = UITheme.make_panel_stylebox_flat(Color(UITheme.C01_SCENE_BASE, 1.0), UITheme.C01_TEXT_GOLD, 8, 2)
	var x按下: StyleBoxFlat = UITheme.make_panel_stylebox_flat(
		Color(UITheme.C01_SCENE_BASE.r * 0.8, UITheme.C01_SCENE_BASE.g * 0.8, UITheme.C01_SCENE_BASE.b * 0.8, 1.0),
		UITheme.C01_TEXT_GOLD, 8, 2)
	cancel.add_theme_stylebox_override("normal", x正常)
	cancel.add_theme_stylebox_override("pressed", x按下)
	cancel.add_theme_stylebox_override("hover", x正常)
	cancel.add_theme_stylebox_override("focus", x正常)
	UITheme.apply_title_font_sized(cancel, int(round(14.0 * UITheme.UI_SCALE)))
	cancel.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	cancel.pressed.connect(_on_cancel)
	add_child(cancel)

func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	var s: float = UITheme.UI_SCALE
	c.layout_mode = 0
	c.offset_left = x * s
	c.offset_top = y * s
	c.offset_right = (x + w) * s
	c.offset_bottom = (y + h) * s
	c.size = Vector2(w * s, h * s)

# 渐变覆盖层 helper：建一张 GradientTexture2D（按 w×h 像素）并包成 TextureRect 返回。
# 用于弹窗预览 3 层融合（vignette / 环境光）；FILL_RADIAL 中心→边缘径向，FILL_LINEAR 上下渐变。
func _建渐变覆盖(w: float, h: float, colors: Array, fill_mode: int = GradientTexture2D.FILL_RADIAL) -> TextureRect:
	var gradient := Gradient.new()
	for i in range(colors.size()):
		gradient.set_color(i, colors[i])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill = fill_mode
	if fill_mode == GradientTexture2D.FILL_RADIAL:
		grad_tex.fill_from = Vector2(0.5, 0.5)
		grad_tex.fill_to = Vector2(1.0, 0.5)
	else:  # FILL_LINEAR 上下渐变
		grad_tex.fill_from = Vector2(0.5, 0.0)
		grad_tex.fill_to = Vector2(0.5, 1.0)
	grad_tex.width = int(w)
	grad_tex.height = int(h)
	var rect := TextureRect.new()
	rect.texture = grad_tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _圆形化(原图: Texture2D) -> Texture2D:
	if 原图 == null or 原图.get_width() <= 0:
		return null
	var w: float = float(原图.get_width())
	var at := AtlasTexture.new()
	at.atlas = 原图
	at.region = Rect2(0.0, (原图.get_height() - w) * 0.5, w, w)
	at.filter_clip = true
	return at

func _刷新预览() -> void:
	if _预览 == null or not is_instance_valid(Game):
		return
	var av_tex: Texture2D = _取头像纹(_selected_avatar)
	_预览.texture = _圆形化(av_tex)
	if _头像名 != null:
		var av_def: Dictionary = Game.取宗主头像定义(_selected_avatar)
		_头像名.text = av_def.get("name", "宗主")

# 纹理缓存：避免每次重绘都回查 Game（热路径零重复加载）。
func _取头像纹(id: String) -> Texture2D:
	if _纹理智缓存.has(id):
		return _纹理智缓存[id]
	var tex: Texture2D = Game.取宗主头像纹理(id)
	_纹理智缓存[id] = tex
	return tex

# 预热当前头像纹理，消解首开弹窗的加载延迟。
func _预热所有纹理() -> void:
	if not is_instance_valid(Game):
		return
	if _selected_avatar != "":
		_取头像纹(_selected_avatar)

# 唤起 / 关闭：复用常驻实例，仅切换可见性，零重建。
func 唤起() -> void:
	if not _built:
		_build()
		_built = true
		_预热所有纹理()
	visible = true
	_刷新预览()
	_刷新格子选中()

func 关闭() -> void:
	visible = false

func _重建网格() -> void:
	for c in _cells:
		if is_instance_valid(c):
			c.queue_free()
	_cells.clear()
	if _网格 == null or not is_instance_valid(_网格) or not is_instance_valid(Game):
		return
	var items: Array = Game.宗主头像列表(_性别)
	for d in items:
		var id: String = d.get("id", "")
		var 锁定: bool = not Game.宗主头像是否已解锁(id)
		var cell: Control = _造格子(d, id, 锁定)
		_网格.add_child(cell)
		_cells.append(cell)
	_刷新格子选中()

func _造格子(def: Dictionary, id: String, 锁定: bool) -> Control:
	var cell := Panel.new()
	cell.name = "Cell_" + id
	cell.custom_minimum_size = Vector2(_格宽, _格高)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.set_meta("id", id)
	cell.add_theme_stylebox_override("panel", _格子样式(id == _当前选中id()))
	cell.gui_input.connect(_on_格子点击.bind(id, 锁定))

	var tr := TextureRect.new()
	tr.name = "Thumb"
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var s: float = UITheme.UI_SCALE
	var 边: float = min(_格宽 - 12.0 * s, _格高 - 28.0 * s)
	var tx: float = (_格宽 - 边) * 0.5
	var ty: float = 6.0 * s
	tr.layout_mode = 0
	tr.offset_left = tx
	tr.offset_top = ty
	tr.offset_right = tx + 边
	tr.offset_bottom = ty + 边
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = _圆形化(_取头像纹(id))
	var 头像材质 := ShaderMaterial.new()
	头像材质.shader = AVATAR_MASK_SHADER
	tr.material = 头像材质
	if 锁定:
		tr.modulate = Color(1, 1, 1, 0.28)
	cell.add_child(tr)

	var nm := Label.new()
	nm.name = "Name"
	nm.layout_mode = 0
	nm.offset_left = 2.0 * UITheme.UI_SCALE
	nm.offset_top = _格高 - 20.0 * UITheme.UI_SCALE
	nm.offset_right = _格宽 - 2.0 * UITheme.UI_SCALE
	nm.offset_bottom = _格高 - 2.0 * UITheme.UI_SCALE
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.apply_body_font_sized(nm, int(round(10.0 * UITheme.UI_SCALE)))
	if 锁定:
		nm.text = "🔒 " + def.get("channel", "未解锁")
		nm.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
	else:
		nm.text = def.get("name", "")
		nm.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	cell.add_child(nm)
	return cell

func _当前选中id() -> String:
	return _selected_avatar

func _格子样式(sel: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.COLOR_BG_CONTENT if sel else UITheme.COLOR_PANEL_BG
	sb.border_color = UITheme.C01_TEXT_GOLD
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2 if sel else 1)
	sb.set_content_margin_all(0)
	return sb

func _刷新格子选中() -> void:
	var sel_id: String = _当前选中id()
	for c in _cells:
		if not is_instance_valid(c):
			continue
		var id: String = c.get_meta("id", "")
		c.add_theme_stylebox_override("panel", _格子样式(id == sel_id))

func _on_格子点击(事件: InputEvent, id: String, 锁定: bool) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if 锁定:
			var def: Dictionary = Game.取宗主头像定义(id)
			_提示.text = "该%s需通过【%s】解锁" % ["头像", def.get("channel", "未知渠道")]
			_提示.visible = true
			return
		_selected_avatar = id
		_提示.visible = false
		_刷新预览()
		_刷新格子选中()

func _on_confirm() -> void:
	if is_instance_valid(Game):
		Game.设置当前头像(_selected_avatar)
		应用并关闭.emit()
	关闭()

func _on_cancel() -> void:
	关闭()


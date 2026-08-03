@tool
extends VBoxContainer
class_name PropertiesPanel

# =============================================================================
# 太玄UI编辑器 —— 右侧属性编辑面板
# =============================================================================
# 选中画布上的控件后，按控件类型动态生成可编辑行。
# 每次字段改动都会写入传入的数据字典，并调用 refresh 回调刷新画布。
# 资源路径（纹理/字体/图标/底板）通过 AssetPicker 轻量拾取器浏览选择（res:// 相对路径）。
# =============================================================================

var _data: Dictionary = {}
var _refresh: Callable = Callable()


# -----------------------------------------------------------------------------
# 外部接口
# -----------------------------------------------------------------------------
# 清空面板
func clear() -> void:
	for c in get_children():
		c.queue_free()
	_data = {}
	_refresh = Callable()


# 编辑某个控件的数据字典；refresh 在字段变动时被调用
func edit(data: Dictionary, refresh: Callable) -> void:
	clear()
	_data = data
	_refresh = refresh

	# ---- 基础属性 ----
	add_section("基础属性")
	_row_name()
	_row_readonly("类型 type", str(data.get("type", "")))
	_row_vec2("坐标 position", _data, "position")
	_row_vec2("尺寸 size", _data, "size")
	_row_vec2("最小尺寸 min_size", _data, "min_size")
	_row_int("Z层级 z_index", _data, "z_index")
	_row_int("锚点预设 anchor_preset", _data, "anchor_preset")

	# ---- 样式属性（按类型）----
	match data.get("type", ""):
		TaixuanUIData.TYPE_LABEL:   _style_label()
		TaixuanUIData.TYPE_TEXTURE: _style_texture()
		TaixuanUIData.TYPE_BUTTON:  _style_button()
		TaixuanUIData.TYPE_PANEL:   _style_panel()
		TaixuanUIData.TYPE_ANIMATED: _style_animated()
		TaixuanUIData.TYPE_SPRITESHEET: _style_spritesheet()


# -----------------------------------------------------------------------------
# 区块标题
# -----------------------------------------------------------------------------
func add_section(title: String) -> void:
	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	add_child(sp)
	var l: Label = Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.78, 0.85, 0.55, 1))
	add_child(l)


# -----------------------------------------------------------------------------
# 通用行构造
# -----------------------------------------------------------------------------
func _do_refresh() -> void:
	if _refresh.is_valid():
		_refresh.call()


func _row_readonly(lbl: String, value: String) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = lbl
	L.custom_minimum_size = Vector2(120, 0)
	L.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v: Label = Label.new()
	v.text = value
	v.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1))
	h.add_child(L)
	h.add_child(v)
	add_child(h)


func _row_name() -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = "名称 name"
	L.custom_minimum_size = Vector2(120, 0)
	var e: LineEdit = LineEdit.new()
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text = str(_data.get("name", ""))
	e.text_changed.connect(func(t):
		_data["name"] = t
		_do_refresh())
	h.add_child(L)
	h.add_child(e)
	add_child(h)


func _row_text(lbl: String, dict: Dictionary, key: String) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = lbl
	L.custom_minimum_size = Vector2(90, 0)
	L.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var e: LineEdit = LineEdit.new()
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text = str(dict.get(key, ""))
	e.text_changed.connect(func(t):
		dict[key] = t
		_do_refresh())
	h.add_child(L)
	h.add_child(e)
	add_child(h)


func _row_int(lbl: String, dict: Dictionary, key: String) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = lbl
	L.custom_minimum_size = Vector2(120, 0)
	var s: SpinBox = SpinBox.new()
	s.min_value = -9999
	s.max_value = 9999
	s.value = float(dict.get(key, 0))
	s.value_changed.connect(func(v):
		dict[key] = int(v)
		_do_refresh())
	h.add_child(L)
	h.add_child(s)
	add_child(h)


func _row_float(lbl: String, dict: Dictionary, key: String, minv: float, maxv: float) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = lbl
	L.custom_minimum_size = Vector2(120, 0)
	var s: SpinBox = SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = 0.01
	s.value = float(dict.get(key, 1.0))
	s.value_changed.connect(func(v):
		dict[key] = v
		_do_refresh())
	h.add_child(L)
	h.add_child(s)
	add_child(h)


func _row_vec2(lbl: String, dict: Dictionary, key: String) -> void:
	var arr: Array = dict.get(key, [0, 0])
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = lbl
	L.custom_minimum_size = Vector2(120, 0)
	var sx: SpinBox = SpinBox.new()
	sx.min_value = -99999
	sx.max_value = 99999
	sx.value = float(arr[0])
	var sy: SpinBox = SpinBox.new()
	sy.min_value = -99999
	sy.max_value = 99999
	sy.value = float(arr[1])
	sx.value_changed.connect(func(v):
		dict[key][0] = v
		_do_refresh())
	sy.value_changed.connect(func(v):
		dict[key][1] = v
		_do_refresh())
	h.add_child(L)
	h.add_child(sx)
	h.add_child(sy)
	add_child(h)


func _row_color(lbl: String, dict: Dictionary, key: String) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = lbl
	L.custom_minimum_size = Vector2(120, 0)
	var arr: Array = dict.get(key, [1, 1, 1, 1])
	var cp: ColorPickerButton = ColorPickerButton.new()
	cp.color = Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cp.color_changed.connect(func(c):
		dict[key] = [c.r, c.g, c.b, c.a]
		_do_refresh())
	h.add_child(L)
	h.add_child(cp)
	add_child(h)


func _row_align(lbl: String, dict: Dictionary, key: String) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = lbl
	L.custom_minimum_size = Vector2(90, 0)
	var o: OptionButton = OptionButton.new()
	o.add_item("左/上", 0)
	o.add_item("居中", 1)
	o.add_item("右/下", 2)
	o.selected = int(dict.get(key, 1))
	o.item_selected.connect(func(idx):
		dict[key] = idx
		_do_refresh())
	h.add_child(L)
	h.add_child(o)
	add_child(h)


func _row_stretch(lbl: String, dict: Dictionary, key: String) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = lbl
	L.custom_minimum_size = Vector2(120, 0)
	var o: OptionButton = OptionButton.new()
	# TextureRect.StretchMode 枚举值（Godot 4.7）
	o.add_item("缩放填充(0)", 0)   # STRETCH_SCALE_ON_EXPAND
	o.add_item("平铺(1)", 1)       # STRETCH_TILE
	o.add_item("保持原尺寸(2)", 2) # STRETCH_KEEP
	o.add_item("居中保持(3)", 3)   # STRETCH_KEEP_CENTERED
	o.add_item("保持比例(4)", 4)   # STRETCH_KEEP_ASPECT
	o.add_item("居中比例(5)", 5)   # STRETCH_KEEP_ASPECT_CENTERED
	o.add_item("覆盖比例(6)", 6)   # STRETCH_KEEP_ASPECT_COVERED
	o.selected = int(dict.get(key, 0))
	o.item_selected.connect(func(idx):
		dict[key] = idx
		_do_refresh())
	h.add_child(L)
	h.add_child(o)
	add_child(h)


# 九宫格缩放轴模式（StyleBoxTexture.AxisStretchMode）
func _row_axis(lbl: String, dict: Dictionary, key: String) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = lbl
	L.custom_minimum_size = Vector2(90, 0)
	var o: OptionButton = OptionButton.new()
	o.add_item("拉伸(0)", 0)    # AXIS_STRETCH_MODE_STRETCH
	o.add_item("平铺(1)", 1)    # AXIS_STRETCH_MODE_TILE
	o.add_item("平铺适配(2)", 2) # AXIS_STRETCH_MODE_TILE_FIT
	o.selected = int(dict.get(key, 0))
	o.item_selected.connect(func(idx):
		dict[key] = idx
		_do_refresh())
	h.add_child(L)
	h.add_child(o)
	add_child(h)


func _row_path(lbl: String, dict: Dictionary, key: String, filters: Array) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = lbl
	L.custom_minimum_size = Vector2(90, 0)
	var e: LineEdit = LineEdit.new()
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text = str(dict.get(key, ""))
	e.text_changed.connect(func(t):
		dict[key] = t
		_do_refresh())
	var b: Button = Button.new()
	b.text = "浏览"
	b.pressed.connect(func(): _browse(e, filters, dict, key))
	h.add_child(L)
	h.add_child(e)
	h.add_child(b)
	add_child(h)


# 打开资源浏览（轻量自定义拾取器，避免 EditorFileDialog 在自定义窗口下渲染不出来的坑）
# 选择后将路径写回字典（res:// 相对路径）
func _browse(line_edit: LineEdit, filters: Array, dict: Dictionary, key: String) -> void:
	var picker: AssetPicker = AssetPicker.new()
	picker.filters = filters
	picker.multi = false
	picker.root_dir = "res://"
	picker.callback = func(p: String):
		line_edit.text = p
		dict[key] = p
		_do_refresh()
	var win: Window = get_window()
	win.add_child(picker)
	picker.popup_centered(Vector2i(720, 560))


# -----------------------------------------------------------------------------
# 各类型样式区块
# -----------------------------------------------------------------------------
func _style_label() -> void:
	add_section("文字样式")
	_row_text("文字内容", _data["style"], "text")
	_row_int("字号 font_size", _data["style"], "font_size")
	_row_color("字色 color", _data["style"], "color")
	_row_align("水平对齐", _data["style"], "horizontal_alignment")
	_row_align("垂直对齐", _data["style"], "vertical_alignment")
	_row_path("字体文件 font_path", _data["style"], "font_path", ["*.ttf", "*.otf", "*.font"])


func _style_texture() -> void:
	add_section("图片样式")
	_row_path("纹理路径 texture_path", _data["style"], "texture_path", ["*.png", "*.jpg", "*.webp", "*.svg"])
	_row_float("透明度 modulate_alpha", _data["style"], "modulate_alpha", 0.0, 1.0)
	_row_stretch("缩放模式 stretch_mode", _data["style"], "stretch_mode")


func _style_button() -> void:
	add_section("按钮样式")
	_row_text("按钮文字", _data["style"], "button_text")
	_row_path("图标 icon_path", _data["style"], "icon_path", ["*.png", "*.jpg", "*.svg", "*.webp"])
	_row_path("底板图 bg_path", _data["style"], "bg_path", ["*.png", "*.jpg", "*.svg", "*.webp"])
	_row_int("字号 font_size", _data["style"], "font_size")
	_row_color("字色 color", _data["style"], "color")
	_row_path("字体文件 font_path", _data["style"], "font_path", ["*.ttf", "*.otf", "*.font"])
	_style_nine_patch(_data["style"])


func _style_panel() -> void:
	add_section("面板样式")
	_row_color("底色 bg_color", _data["style"], "bg_color")
	_row_color("描边色 border_color", _data["style"], "border_color")
	_row_int("描边宽 border_width", _data["style"], "border_width")
	_row_int("圆角 corner_radius", _data["style"], "corner_radius")
	_row_path("纹理底板 bg_path", _data["style"], "bg_path", ["*.png", "*.jpg", "*.svg", "*.webp"])
	_style_nine_patch(_data["style"])


# 九宫格（nine-patch）编辑：四边边距 + 横向/纵向缩放轴模式。
# 边距单位为像素，表示底板图四周“不动区”的厚度；中间区域随控件尺寸缩放/平铺。
# 仅当对应 bg_path 已设置时才生效（未设置时纯色面板/无底板，字段留空无副作用）。
func _style_nine_patch(s: Dictionary) -> void:
	add_section("九宫格(nine-patch)")
	_row_int("边距-左", s, "bg_margin_left")
	_row_int("边距-上", s, "bg_margin_top")
	_row_int("边距-右", s, "bg_margin_right")
	_row_int("边距-下", s, "bg_margin_bottom")
	_row_axis("横向模式", s, "bg_axis_h")
	_row_axis("纵向模式", s, "bg_axis_v")


func _style_animated() -> void:
	add_section("动画帧样式")
	_row_frames("帧序列 frames", _data["style"], "frames")
	_row_float("帧率 fps", _data["style"], "fps", 0.1, 60.0)
	_row_bool("循环 loop", _data["style"], "loop")
	_row_stretch("缩放模式 stretch_mode", _data["style"], "stretch_mode")
	_row_float("透明度 modulate_alpha", _data["style"], "modulate_alpha", 0.0, 1.0)


func _style_spritesheet() -> void:
	add_section("精灵表/图集样式")
	_row_path("图集路径 sheet_path", _data["style"], "sheet_path", ["*.png", "*.jpg", "*.webp", "*.svg"])
	_row_int("横向切片 hframes", _data["style"], "hframes")
	_row_int("纵向切片 vframes", _data["style"], "vframes")
	_row_int("实际帧数 frame_count(0=全格)", _data["style"], "frame_count")
	_row_float("帧率 fps", _data["style"], "fps", 0.1, 60.0)
	_row_bool("循环 loop", _data["style"], "loop")
	_row_stretch("缩放模式 stretch_mode", _data["style"], "stretch_mode")
	_row_float("透明度 modulate_alpha", _data["style"], "modulate_alpha", 0.0, 1.0)
	add_section("导出 SpriteFrames.tres")
	_row_export_sheet()


# 一键把当前精灵表导出为可直接挂到 AnimatedSprite2D 的 SpriteFrames 资源
func _row_export_sheet() -> void:
	var b: Button = Button.new()
	b.text = "导出 SpriteFrames.tres (AnimatedSprite2D 用)"
	b.pressed.connect(func():
		var s: Dictionary = _data.get("style", {})
		var sp: String = s.get("sheet_path", "")
		if sp == "":
			push_warning("太玄UI编辑器：请先设置图集路径")
			return
		var out: String = sp.get_basename() + ".frames.tres"
		var ok: bool = TaixuanUIData.export_spritesheet_tres(
			out, sp, int(s.get("hframes", 4)), int(s.get("vframes", 4)),
			float(s.get("fps", 8.0)), bool(s.get("loop", true)), int(s.get("frame_count", 0)))
		if ok:
			push_warning("太玄UI编辑器：已导出 %s" % out)
	)
	add_child(b)


# 多帧选择：打开 AssetPicker 多选文件，将 res:// 路径数组写入 dict[key]
func _row_frames(lbl: String, dict: Dictionary, key: String) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = lbl
	L.custom_minimum_size = Vector2(90, 0)
	var cnt: Label = Label.new()
	var arr: Array = dict.get(key, [])
	cnt.text = "(已选 %d 帧)" % arr.size()
	cnt.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	var b: Button = Button.new()
	b.text = "选择帧…"
	b.pressed.connect(func(): _browse_frames(dict, key, cnt))
	h.add_child(L)
	h.add_child(b)
	h.add_child(cnt)
	add_child(h)


func _browse_frames(dict: Dictionary, key: String, cnt_label: Label) -> void:
	var picker: AssetPicker = AssetPicker.new()
	picker.filters = ["png", "jpg", "webp", "svg"]
	picker.multi = true
	picker.root_dir = "res://"
	picker.callback = func(paths: PackedStringArray):
		dict[key] = paths
		cnt_label.text = "(已选 %d 帧)" % paths.size()
		_do_refresh()
	var win: Window = get_window()
	win.add_child(picker)
	picker.popup_centered(Vector2i(720, 560))


# 布尔勾选行（用于 loop 等开关）
func _row_bool(lbl: String, dict: Dictionary, key: String) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var L: Label = Label.new()
	L.text = lbl
	L.custom_minimum_size = Vector2(120, 0)
	var cb: CheckBox = CheckBox.new()
	cb.button_pressed = bool(dict.get(key, true))
	cb.toggled.connect(func(v):
		dict[key] = v
		_do_refresh())
	h.add_child(L)
	h.add_child(cb)
	add_child(h)

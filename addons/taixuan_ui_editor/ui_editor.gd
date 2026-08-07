@tool
extends Window

# =============================================================================
# 太玄UI编辑器 —— 编辑器主窗口（extends Window）
# =============================================================================
# 这是编辑器的核心脚本，负责：
#   1. 三栏布局：左工具箱 / 中画布 / 右属性面板
#   2. 画布：滚轮缩放、空格/中键平移、网格、对齐吸附
#   3. 基准图：导入 PNG 参考底图，调透明度/锁定/显隐/适配
#   4. 控件：选中、拖动、复制、删除、层级调整
#   5. 多选批量对齐
#   6. 撤销/重做、保存工程(.taixuan_ui)、导出规范 JSON
#
# 重要约束（来自需求）：
#   - 画布上所有被设计的控件使用“绝对 position/size”，不使用任何容器，
#     彻底规避 Godot 4.7 容器把子节点压缩成 0 像素的 bug。
#   - 所有控件默认设置 minimum_size，禁止文字/图标被裁剪。
#   - 本脚本运行于编辑器窗口上下文，使用 EditorInterface 单例获取编辑器根节点。
# =============================================================================

# ----------------------- 顶部可调常量（集中配置）-----------------------
const CANVAS_DEFAULT_W: int = 768
const CANVAS_DEFAULT_H: int = 1344
const ZOOM_MIN: float = 0.1
const ZOOM_MAX: float = 5.0
const ZOOM_STEP: float = 1.1
const GRID_DEFAULT: int = 32
const BG_DEFAULT: Color = Color(0.09, 0.11, 0.10, 1.0)
const SELECT_COLOR: Color = Color(0.78, 0.85, 0.55, 1.0)
const MARQUEE_FILL: Color = Color(0.55, 0.78, 0.70, 0.22)
const SNAP_DEFAULT: bool = true
const TEMPLATE_LIB_PATH: String = "res://addons/taixuan_ui_editor/template_library.gd"

# 默认工程 / 导出路径（编辑器内置固定目标，避免依赖易碎的 EditorFileDialog 子窗口）
const DEFAULT_PROJECT_PATH: String = "res://ui_editor_projects/home_page.taixuan_ui"
const DEFAULT_JSON_PATH: String = "res://ui_editor_projects/home_page.json"
const DEFAULT_TSCN_PATH: String = "res://art/auto_ui/scenes/main_menu.tscn"
const DEFAULT_FONT_PATH: String = "res://art/fonts/SourceHanSansCN-Regular.otf"
const DEFAULT_REF_PATH: String = "res://art/scene_pipeline/home_bg_seasons_preview.png"

# 子脚本（data_manager.gd 已 class_name TaixuanUIData；
#         toolbox_panel.gd 已 class_name ToolboxPanel；
#         properties_panel.gd 已 class_name PropertiesPanel）
# 三者均有 class_name，可直接用类名引用，无需 const preload 遮蔽全局名。


# ----------------------------- 编辑器状态 -----------------------------
var canvas_w: int = CANVAS_DEFAULT_W
var canvas_h: int = CANVAS_DEFAULT_H
var bg_color: Color = BG_DEFAULT
var ref_img: Dictionary = {}             # 在 _ready 中初始化，避免类体级引用 TaixuanUIData 导致插件加载时解析失败
var controls: Array = []                 # 控件数据字典列表（工程数据源）
var default_font: String = ""            # 项目默认字体（res:// 路径，空=Godot默认字体）

var zoom: float = 1.0
var grid_size: int = GRID_DEFAULT
var snap_enabled: bool = SNAP_DEFAULT

# 画布节点
var viewport: Control
var design_root: Control                   # 设计表面（随缩放/平移变换）
var grid_draw: Control                    # 网格 + 底色
var ref_node: TextureRect                 # 基准图
var overlay: Control                      # 选中框 / 框选矩形（屏幕空间）

# 面板
var toolbox: ToolboxPanel
var props: PropertiesPanel
var info_label: Label
var zoom_label: Label
var _grid_spin: SpinBox
var _font_label: Label                     # 工具栏显示当前默认字体名

# 基准图控件引用
var _ref_opacity: SpinBox
var _ref_visible: CheckBox
var _ref_lock: CheckBox
var _ref_fit: OptionButton

# 节点 <-> 数据 映射
var _nodes: Array = []                    # Control 节点列表（与 controls 平行）
var _node_data: Dictionary = {}           # node -> 数据字典
var selected: Array = []                  # 当前选中的 Control 节点

# 交互临时态
var _pan_active: bool = false
var _pan_start: Vector2 = Vector2.ZERO
var _pan_orig: Vector2 = Vector2.ZERO
var _marquee_active: bool = false
var _marquee_start: Vector2 = Vector2.ZERO
var _marquee_end: Vector2 = Vector2.ZERO
var _drag_active: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_orig: Dictionary = {}           # node -> 原始 position(Vector2)
var _dragged: bool = false

# 撤销 / 重做（快照指针法：history 存各历史状态，hist_idx 指向当前状态）
var history: Array = []
var hist_idx: int = 0


# =============================================================================
# 初始化
# =============================================================================
func _ready() -> void:
	title = "太玄UI编辑器"
	size = Vector2i(1180, 820)
	close_requested.connect(queue_free)

	# 主纵向布局
	var main: VBoxContainer = VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main)

	# 顶部工具栏
	main.add_child(_build_toolbar())

	# 信息条
	info_label = Label.new()
	info_label.text = "未选中控件"
	info_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.6, 1))
	main.add_child(info_label)

	# 三栏主体
	var hb: HBoxContainer = HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(hb)

	# 左：工具箱
	toolbox = ToolboxPanel.new()
	toolbox.size_flags_horizontal = Control.SIZE_FILL
	toolbox.custom_minimum_size = Vector2(170, 0)
	toolbox.request_add.connect(_on_request_add)
	hb.add_child(toolbox)

	# 中：画布视口
	viewport = Control.new()
	viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport.clip_contents = true
	viewport.gui_input.connect(_on_viewport_gui_input)
	hb.add_child(viewport)

	# 右：属性面板
	props = PropertiesPanel.new()
	props.size_flags_horizontal = Control.SIZE_FILL
	props.custom_minimum_size = Vector2(280, 0)
	hb.add_child(props)

	# 设计表面及子层
	design_root = Control.new()
	design_root.mouse_filter = Control.MOUSE_FILTER_PASS   # 空白处事件透传到 viewport
	design_root.position = Vector2(40, 40)
	viewport.add_child(design_root)

	grid_draw = Control.new()
	grid_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_draw.draw.connect(_on_grid_draw)
	design_root.add_child(grid_draw)

	ref_node = TextureRect.new()
	ref_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ref_node.z_index = -10
	design_root.add_child(ref_node)

	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_on_overlay_draw)
	viewport.add_child(overlay)

	# 类体级不能引用 TaixuanUIData（插件加载顺序问题），在此初始化
	ref_img = TaixuanUIData.default_reference()

	# 自动识别工程字体（若存在），让首次打开即对真实字体预览
	default_font = _auto_detect_font()
	_sync_font_label()
	_refresh_all()


# =============================================================================
# 工具栏
# =============================================================================
func _build_toolbar() -> ScrollContainer:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 44)
	var hb: HBoxContainer = HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(hb)

	# 项目
	hb.add_child(_mk_btn("新建", _new_project))
	hb.add_child(_mk_btn("打开", _open_project_dialog))
	hb.add_child(_mk_btn("保存", _save_dialog))
	hb.add_child(_mk_btn("导出JSON", _export_dialog))
	hb.add_child(_mk_btn("导出tscn", _export_tscn_dialog))
	hb.add_child(_mk_btn("模板库", _open_template_library))
	hb.add_child(_sep())
	# 历史
	hb.add_child(_mk_btn("撤销", _undo))
	hb.add_child(_mk_btn("重做", _redo))
	hb.add_child(_sep())
	# 编辑
	hb.add_child(_mk_btn("复制", _duplicate_selected))
	hb.add_child(_mk_btn("删除", _delete_selected))
	hb.add_child(_mk_btn("上移", _raise))
	hb.add_child(_mk_btn("下移", _lower))
	hb.add_child(_mk_btn("置顶", _to_top))
	hb.add_child(_mk_btn("置底", _to_bottom))
	hb.add_child(_sep())
	# 多选对齐
	hb.add_child(_mk_btn("左对齐", _do_align.bind("left")))
	hb.add_child(_mk_btn("右对齐", _do_align.bind("right")))
	hb.add_child(_mk_btn("水平居中", _do_align.bind("hcenter")))
	hb.add_child(_mk_btn("顶对齐", _do_align.bind("top")))
	hb.add_child(_mk_btn("底对齐", _do_align.bind("bottom")))
	hb.add_child(_mk_btn("垂直居中", _do_align.bind("vcenter")))
	hb.add_child(_mk_btn("等宽", _do_align.bind("eqw")))
	hb.add_child(_mk_btn("等高", _do_align.bind("eqh")))
	hb.add_child(_sep())
	# 网格 + 缩放
	var gl: Label = Label.new(); gl.text = "网格"; hb.add_child(gl)
	_grid_spin = SpinBox.new()
	_grid_spin.min_value = 4; _grid_spin.max_value = 256; _grid_spin.value = grid_size
	_grid_spin.value_changed.connect(_on_grid_changed)
	hb.add_child(_grid_spin)
	zoom_label = Label.new(); zoom_label.text = "缩放 100%"
	hb.add_child(zoom_label)
	hb.add_child(_sep())

	# 基准图（设计参考底图）
	var rl: Label = Label.new(); rl.text = "基准图"; hb.add_child(rl)
	hb.add_child(_mk_btn("导入", _import_reference))
	_ref_opacity = SpinBox.new()
	_ref_opacity.min_value = 0.0; _ref_opacity.max_value = 1.0; _ref_opacity.step = 0.05
	_ref_opacity.value = ref_img.get("opacity", 1.0)
	_ref_opacity.value_changed.connect(_on_ref_opacity_changed)
	hb.add_child(_ref_opacity)
	_ref_visible = CheckBox.new(); _ref_visible.text = "显示"
	_ref_visible.button_pressed = bool(ref_img.get("visible", true))
	_ref_visible.toggled.connect(_on_ref_visible_toggled)
	hb.add_child(_ref_visible)
	_ref_lock = CheckBox.new(); _ref_lock.text = "锁定"
	_ref_lock.button_pressed = bool(ref_img.get("locked", false))
	_ref_lock.toggled.connect(_on_ref_lock_toggled)
	hb.add_child(_ref_lock)
	_ref_fit = OptionButton.new()
	_ref_fit.add_item("适配-包含", 0)   # contain
	_ref_fit.add_item("适配-覆盖", 1)   # cover
	_ref_fit.add_item("原始尺寸", 2)    # origin
	_ref_fit.selected = 0
	_ref_fit.item_selected.connect(_on_ref_fit_selected)
	hb.add_child(_ref_fit)
	# 项目默认字体（真实字体预览：所有文字控件回退基准）
	hb.add_child(_sep())
	var fl: Label = Label.new(); fl.text = "字体"; hb.add_child(fl)
	_font_label = Label.new(); _font_label.text = "默认"; hb.add_child(_font_label)
	hb.add_child(_mk_btn("选择字体", _pick_default_font))
	hb.add_child(_mk_btn("清除", _clear_default_font))
	return sc


func _mk_btn(text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _sep() -> VSeparator:
	return VSeparator.new()


# 自动识别工程里的字体文件（用于真实字体预览的默认回退）
func _auto_detect_font() -> String:
	var dirs: Array = ["res://art/fonts"]
	for d in dirs:
		if DirAccess.dir_exists_absolute(d):
			var files: PackedStringArray = DirAccess.get_files_at(d)
			for f in files:
				var ext: String = f.get_extension().to_lower()
				if ext in ["ttf", "otf", "font"]:
					return d.path_join(f)
	return ""


# 同步工具栏字体名显示
func _sync_font_label() -> void:
	if _font_label == null:
		return
	if default_font == "":
		_font_label.text = "默认"
	else:
		_font_label.text = default_font.get_file()


# 选择项目默认字体
func _pick_default_font() -> void:
	default_font = DEFAULT_FONT_PATH
	_sync_font_label()
	_refresh_all()
	_commit()
	info_label.text = "已设置默认字体：%s" % DEFAULT_FONT_PATH.get_file()


func _on_font_selected(path: String) -> void:
	default_font = path
	_sync_font_label()
	_refresh_all()
	_commit()


func _clear_default_font() -> void:
	default_font = ""
	_sync_font_label()
	_refresh_all()
	_commit()


func _on_grid_changed(v: float) -> void:
	grid_size = int(v)
	grid_draw.queue_redraw()


# -----------------------------------------------------------------------------
# 基准图操作
# -----------------------------------------------------------------------------
func _import_reference() -> void:
	ref_img["path"] = DEFAULT_REF_PATH
	_apply_reference()
	_sync_reference_controls()
	_commit()
	info_label.text = "已导入基准图：%s" % DEFAULT_REF_PATH.get_file()


func _on_ref_selected(path: String) -> void:
	ref_img["path"] = path
	_apply_reference()
	_sync_reference_controls()
	_commit()


func _on_ref_opacity_changed(v: float) -> void:
	ref_img["opacity"] = v
	_apply_reference()
	_commit()


func _on_ref_visible_toggled(b: bool) -> void:
	ref_img["visible"] = b
	_apply_reference()
	_commit()


func _on_ref_lock_toggled(b: bool) -> void:
	ref_img["locked"] = b   # 锁定为属性标记（基准图不可选中，仅作状态记录）


func _on_ref_fit_selected(idx: int) -> void:
	match idx:
		1: ref_img["fit"] = "cover"
		2: ref_img["fit"] = "origin"
		_: ref_img["fit"] = "contain"
	_apply_reference()
	_commit()


# 同步基准图控件显示（打开工程 / 新建后调用）
func _sync_reference_controls() -> void:
	if _ref_opacity != null:
		_ref_opacity.value = float(ref_img.get("opacity", 1.0))
	if _ref_visible != null:
		_ref_visible.button_pressed = bool(ref_img.get("visible", true))
	if _ref_lock != null:
		_ref_lock.button_pressed = bool(ref_img.get("locked", false))
	if _ref_fit != null:
		match ref_img.get("fit", "contain"):
			"cover": _ref_fit.selected = 1
			"origin": _ref_fit.selected = 2
			_: _ref_fit.selected = 0


# =============================================================================
# 画布重建与刷新
# =============================================================================
# 依据 controls 重新创建画布上的控件节点
func _rebuild_canvas() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_node_data.clear()
	selected.clear()

	design_root.size = Vector2(canvas_w, canvas_h)
	for data in controls:
		var node: Control = TaixuanUIData.build_control(data, default_font)
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		node.gui_input.connect(_on_control_gui_input.bind(node))
		design_root.add_child(node)
		_nodes.append(node)
		_node_data[node] = data

	grid_draw.size = design_root.size
	grid_draw.queue_redraw()
	_apply_reference()
	overlay.queue_redraw()


# 应用基准图（contain / cover / origin 三种适配）
func _apply_reference() -> void:
	var path: String = ref_img.get("path", "")
	if path != "" and ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			ref_node.texture = tex
			ref_node.visible = bool(ref_img.get("visible", true))
			ref_node.modulate.a = float(ref_img.get("opacity", 1.0))
			ref_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ref_node.stretch_mode = TextureRect.STRETCH_SCALE
			var tw: float = tex.get_width()
			var th: float = tex.get_height()
			var fit: String = ref_img.get("fit", "contain")
			var s: float
			if fit == "cover":
				s = max(canvas_w / tw, canvas_h / th)
			elif fit == "origin":
				s = 1.0
			else:  # contain
				s = min(canvas_w / tw, canvas_h / th)
			ref_node.size = Vector2(tw * s, th * s)
			ref_node.position = Vector2((canvas_w - ref_node.size.x) / 2.0, (canvas_h - ref_node.size.y) / 2.0)
			return
	ref_node.texture = null
	ref_node.visible = false


# 网格 + 底色绘制（随 design_root 缩放，故天生对齐）
func _on_grid_draw() -> void:
	var sz: Vector2 = grid_draw.size
	grid_draw.draw_rect(Rect2(Vector2.ZERO, sz), bg_color, true)
	var col: Color = Color(1, 1, 1, 0.08)
	var step: int = grid_size
	var x: int = 0
	while x <= int(sz.x):
		grid_draw.draw_line(Vector2(x, 0), Vector2(x, sz.y), col, 1.0)
		x += step
	var y: int = 0
	while y <= int(sz.y):
		grid_draw.draw_line(Vector2(0, y), Vector2(sz.x, y), col, 1.0)
		y += step


# 选中框 / 框选矩形（屏幕空间）
func _on_overlay_draw() -> void:
	for n in selected:
		if not is_instance_valid(n):
			continue
		var p: Vector2 = design_root.position + n.position * zoom
		var s: Vector2 = n.size * zoom
		overlay.draw_rect(Rect2(p, s), SELECT_COLOR, false, 2.0)
	if _marquee_active:
		var a: Vector2 = design_root.position + _marquee_start * zoom
		var b: Vector2 = design_root.position + _marquee_end * zoom
		var r: Rect2 = Rect2(a, b - a).abs()
		overlay.draw_rect(r, MARQUEE_FILL, true)
		overlay.draw_rect(r, SELECT_COLOR, false, 1.0)


# 全量刷新
func _refresh_all() -> void:
	design_root.size = Vector2(canvas_w, canvas_h)
	_rebuild_canvas()
	overlay.queue_redraw()
	props.clear()
	_refresh_info()
	_sync_reference_controls()
	_reset_history()


# 刷新信息条 + 缩放显示
func _refresh_info() -> void:
	if selected.size() == 1:
		var d: Dictionary = _node_data[selected[0]]
		info_label.text = "选中: %s  位置[%d,%d]  尺寸[%d,%d]" % [
			d["name"], int(d["position"][0]), int(d["position"][1]),
			int(d["size"][0]), int(d["size"][1])]
	elif selected.size() > 1:
		info_label.text = "已选 %d 个控件（多选仅支持对齐）" % selected.size()
	else:
		info_label.text = "未选中控件"
	if zoom_label != null:
		zoom_label.text = "缩放 %d%%" % int(zoom * 100)


# 属性面板刷新回调：把数据写回节点并刷新选中框
func _refresh_selected() -> void:
	for n in selected:
		if _node_data.has(n):
			TaixuanUIData.apply_base(n, _node_data[n])
			TaixuanUIData.apply_style(n, _node_data[n])
	overlay.queue_redraw()
	_refresh_info()


# =============================================================================
# 坐标换算与视图变换
# =============================================================================
# 视口局部坐标 -> 设计坐标
func _to_design(local_pos: Vector2) -> Vector2:
	return (local_pos - design_root.position) / zoom


# 以鼠标点为锚进行缩放
func _zoom_at(e: InputEventMouseButton) -> void:
	var m: Vector2 = e.position
	var zoom0: float = zoom
	var before: Vector2 = _to_design(m)
	var factor: float = ZOOM_STEP if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP
	zoom = clamp(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	design_root.scale = Vector2(zoom, zoom)
	# 保持鼠标点对应的设计坐标不动
	design_root.position = design_root.position + before * (zoom0 - zoom)
	overlay.queue_redraw()
	_refresh_info()


# =============================================================================
# 视口输入：平移 / 缩放 / 框选
# =============================================================================
func _on_viewport_gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb: InputEventMouseButton = e
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_zoom_at(mb)
			get_viewport().set_input_as_handled()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_active = true
			_pan_start = mb.global_position
			_pan_orig = design_root.position
			get_viewport().set_input_as_handled()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.is_key_pressed(KEY_SPACE):
				_pan_active = true
				_pan_start = mb.global_position
				_pan_orig = design_root.position
				get_viewport().set_input_as_handled()
				return
			# 空白处按下 -> 框选
			_marquee_active = true
			_marquee_start = _to_design(mb.position)
			_marquee_end = _marquee_start
			get_viewport().set_input_as_handled()
			return
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_active = false
			get_viewport().set_input_as_handled()
			return
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _marquee_active:
			_marquee_active = false
			_select_marquee()
			overlay.queue_redraw()
			get_viewport().set_input_as_handled()
			return

	elif e is InputEventMouseMotion:
		var mm: InputEventMouseMotion = e
		if _pan_active:
			design_root.position = _pan_orig + (mm.global_position - _pan_start)
			overlay.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if _marquee_active:
			_marquee_end = _to_design(mm.position)
			overlay.queue_redraw()
			get_viewport().set_input_as_handled()
			return


# 框选：选中与框相交的所有控件
func _select_marquee() -> void:
	var r: Rect2 = Rect2(_marquee_start, _marquee_end - _marquee_start).abs()
	selected.clear()
	for n in _nodes:
		var dr: Rect2 = Rect2(n.position, n.size)
		if r.intersects(dr):
			selected.append(n)
	_after_selection_changed()


# =============================================================================
# 控件输入：选中 + 拖动
# =============================================================================
func _on_control_gui_input(e: InputEvent, node: Control) -> void:
	if e is InputEventMouseButton:
		var mb: InputEventMouseButton = e
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var additive: bool = Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL)
			_select(node, additive)
			_drag_active = true
			_dragged = false
			_drag_start = mb.global_position
			_drag_orig.clear()
			for n in selected:
				_drag_orig[n] = n.position
			get_viewport().set_input_as_handled()
			return
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _drag_active:
			_drag_active = false
			if _dragged:
				_commit()
			get_viewport().set_input_as_handled()
			return

	elif e is InputEventMouseMotion and _drag_active:
		var delta: Vector2 = (e.global_position - _drag_start) / zoom
		if snap_enabled and grid_size > 0:
			delta = _snap(delta)
		for n_v2 in selected:
			var d: Dictionary = _node_data[n_v2]
			var orig: Vector2 = _drag_orig[n_v2]
			var np: Vector2 = orig + delta
			if snap_enabled and grid_size > 0:
				np = _snap(np)
			d["position"] = [np.x, np.y]
			n_v2.position = np
		_dragged = true
		_refresh_info()
		overlay.queue_redraw()
		get_viewport().set_input_as_handled()
		return


# 对齐到网格
func _snap(v: Vector2) -> Vector2:
	return Vector2(
		round(v.x / grid_size) * grid_size,
		round(v.y / grid_size) * grid_size
	)


# =============================================================================
# 选择管理
# =============================================================================
func _is_selected(n: Control) -> bool:
	return selected.has(n)


func _select(node: Control, additive: bool) -> void:
	if not additive and not selected.has(node):
		selected.clear()
	if not selected.has(node):
		selected.append(node)
	_after_selection_changed()


func _clear_selection() -> void:
	selected.clear()
	_after_selection_changed()


func _after_selection_changed() -> void:
	overlay.queue_redraw()
	if selected.size() == 1:
		props.edit(_node_data[selected[0]], _refresh_selected)
	elif selected.size() == 0:
		props.clear()
	# 多选时不显示属性编辑，仅支持对齐
	_refresh_info()


# =============================================================================
# 添加 / 复制 / 删除 / 层级
# =============================================================================
func _on_request_add(type: String) -> void:
	var idx: int = controls.size() + 1
	var data: Dictionary = TaixuanUIData.create_default(type, idx)
	# 放到画布中心
	var c: Vector2 = Vector2(canvas_w / 2.0, canvas_h / 2.0)
	data["position"] = [c.x - data["size"][0] / 2.0, c.y - data["size"][1] / 2.0]
	controls.append(data)
	var node: Control = TaixuanUIData.build_control(data)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.gui_input.connect(_on_control_gui_input.bind(node))
	design_root.add_child(node)
	_nodes.append(node)
	_node_data[node] = data
	_select(node, false)
	_commit()


func _duplicate_selected() -> void:
	if selected.is_empty():
		return
	var new_sel: Array = []
	for n in selected:
		var data: Dictionary = _node_data[n].duplicate(true)
		data["name"] = _unique_name(data["name"])
		data["position"] = [data["position"][0] + 20, data["position"][1] + 20]
		controls.append(data)
		var node: Control = TaixuanUIData.build_control(data)
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		node.gui_input.connect(_on_control_gui_input.bind(node))
		design_root.add_child(node)
		_nodes.append(node)
		_node_data[node] = data
		new_sel.append(node)
	selected = new_sel
	_after_selection_changed()
	_commit()


func _delete_selected() -> void:
	if selected.is_empty():
		return
	for n in selected:
		if _node_data.has(n):
			controls.erase(_node_data[n])
		if is_instance_valid(n):
			n.queue_free()
		_nodes.erase(n)
		_node_data.erase(n)
	selected.clear()
	_after_selection_changed()
	_commit()


func _unique_name(base: String) -> String:
	var name: String = base + "_copy"
	var i: int = 1
	while _name_exists(name):
		i += 1
		name = "%s_copy%d" % [base, i]
	return name


func _name_exists(n: String) -> bool:
	for d in controls:
		if d["name"] == n:
			return true
	return false


func _raise() -> void:
	_shift_z(1, false)


func _lower() -> void:
	_shift_z(-1, false)


func _to_top() -> void:
	_shift_z(9999, true)


func _to_bottom() -> void:
	_shift_z(-9999, true)


func _shift_z(delta: int, absolute: bool) -> void:
	if selected.is_empty():
		return
	for n in selected:
		var d: Dictionary = _node_data[n]
		if absolute:
			d["z_index"] = delta
		else:
			d["z_index"] = int(d["z_index"]) + delta
		TaixuanUIData.apply_base(n, d)
	_refresh_info()
	_commit()


# =============================================================================
# 多选对齐
# =============================================================================
func _do_align(mode: String) -> void:
	if selected.size() < 2:
		return
	var minx: float = INF
	var miny: float = INF
	var max_right: float = -INF
	var max_bottom: float = -INF
	var maxw: float = -INF
	var maxh: float = -INF
	var d: Dictionary = {}
	for n in selected:
		d = _node_data[n]
		var x: float = float(d["position"][0])
		var y: float = float(d["position"][1])
		var w: float = float(d["size"][0])
		var h: float = float(d["size"][1])
		minx = min(minx, x)
		miny = min(miny, y)
		max_right = max(max_right, x + w)
		max_bottom = max(max_bottom, y + h)
		maxw = max(maxw, w)
		maxh = max(maxh, h)
	var rd: Dictionary = _node_data[selected[0]]
	var ref_cx: float = float(rd["position"][0]) + float(rd["size"][0]) / 2.0
	var ref_cy: float = float(rd["position"][1]) + float(rd["size"][1]) / 2.0

	for n_v2 in selected:
		d = _node_data[n_v2]
		match mode:
			"left":
				d["position"][0] = minx
			"right":
				d["position"][0] = max_right - float(d["size"][0])
			"hcenter":
				d["position"][0] = ref_cx - float(d["size"][0]) / 2.0
			"top":
				d["position"][1] = miny
			"bottom":
				d["position"][1] = max_bottom - float(d["size"][1])
			"vcenter":
				d["position"][1] = ref_cy - float(d["size"][1]) / 2.0
			"eqw":
				d["size"][0] = maxw
			"eqh":
				d["size"][1] = maxh
		TaixuanUIData.apply_base(n_v2, d)
	overlay.queue_redraw()
	_refresh_info()
	_commit()


# =============================================================================
# 撤销 / 重做
# =============================================================================
func _gather_doc() -> Dictionary:
	return TaixuanUIData.build_doc(canvas_w, canvas_h, bg_color, ref_img, controls, default_font)


# 提交一次变更：截断 redo 分支后追加当前状态快照并移动到末尾
func _commit() -> void:
	if hist_idx < history.size() - 1:
		history.resize(hist_idx + 1)
	history.append(JSON.stringify(_gather_doc()))
	if history.size() > 100:
		history.pop_front()
	hist_idx = history.size() - 1


# 重置历史基线（新建 / 打开工程后调用）
func _reset_history() -> void:
	history = [JSON.stringify(_gather_doc())]
	hist_idx = 0


func _undo() -> void:
	if hist_idx <= 0:
		return
	hist_idx -= 1
	_apply_doc(JSON.parse_string(history[hist_idx]))
	_refresh_all()


func _redo() -> void:
	if hist_idx >= history.size() - 1:
		return
	hist_idx += 1
	_apply_doc(JSON.parse_string(history[hist_idx]))
	_refresh_all()


# 应用文档（用于打开工程 / 撤销 / 重做）
func _apply_doc(doc: Dictionary) -> void:
	if typeof(doc) != TYPE_DICTIONARY or doc == null:
		return
	var cv: Dictionary = doc.get("canvas", {})
	canvas_w = int(cv.get("width", CANVAS_DEFAULT_W))
	canvas_h = int(cv.get("height", CANVAS_DEFAULT_H))
	var bc: Array = cv.get("background_color", [BG_DEFAULT.r, BG_DEFAULT.g, BG_DEFAULT.b, BG_DEFAULT.a])
	bg_color = Color(float(bc[0]), float(bc[1]), float(bc[2]), float(bc[3]))
	ref_img = (doc.get("reference_image", TaixuanUIData.default_reference())).duplicate(true)
	controls = (doc.get("controls", [])).duplicate(true)
	default_font = doc.get("default_font", "")
	_sync_font_label()


# =============================================================================
# 工程：新建 / 打开 / 保存 / 导出
# =============================================================================
func _new_project() -> void:
	canvas_w = CANVAS_DEFAULT_W
	canvas_h = CANVAS_DEFAULT_H
	bg_color = BG_DEFAULT
	ref_img = TaixuanUIData.default_reference()
	controls.clear()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_node_data.clear()
	selected.clear()
	zoom = 1.0
	design_root.scale = Vector2(1, 1)
	design_root.position = Vector2(40, 40)
	grid_size = GRID_DEFAULT
	if _grid_spin != null:
		_grid_spin.value = grid_size
	default_font = _auto_detect_font()
	_sync_font_label()
	_reset_history()
	_refresh_all()


func _open_project_dialog() -> void:
	if not FileAccess.file_exists(DEFAULT_PROJECT_PATH):
		info_label.text = "未找到首页工程：%s" % DEFAULT_PROJECT_PATH
		return
	_on_open_selected(DEFAULT_PROJECT_PATH)
	info_label.text = "已打开：%s" % DEFAULT_PROJECT_PATH.get_file()


func _on_open_selected(path: String) -> void:
	var res: Dictionary = TaixuanUIData.load_project(path)
	if res.is_empty():
		return
	_apply_doc(res.get("doc", {}))
	var ed: Dictionary = res.get("editor", {})
	if not ed.is_empty():
		grid_size = int(ed.get("grid_size", grid_size))
		zoom = float(ed.get("zoom", zoom))
		design_root.scale = Vector2(zoom, zoom)
		var pan: Array = ed.get("pan", [design_root.position.x, design_root.position.y])
		design_root.position = Vector2(float(pan[0]), float(pan[1]))
		if _grid_spin != null:
			_grid_spin.value = grid_size
	_reset_history()
	_refresh_all()


func _save_dialog() -> void:
	_on_save_selected(DEFAULT_PROJECT_PATH)
	info_label.text = "已保存：%s" % DEFAULT_PROJECT_PATH.get_file()


func _on_save_selected(path: String) -> void:
	if not path.ends_with(".taixuan_ui"):
		path += ".taixuan_ui"
	var editor_meta: Dictionary = {
		"grid_size": grid_size,
		"zoom": zoom,
		"pan": [design_root.position.x, design_root.position.y]
	}
	TaixuanUIData.save_project(path, _gather_doc(), editor_meta)


func _export_dialog() -> void:
	_on_export_selected(DEFAULT_JSON_PATH)
	info_label.text = "已导出 JSON：%s" % DEFAULT_JSON_PATH.get_file()


func _on_export_selected(path: String) -> void:
	if not path.ends_with(".json"):
		path += ".json"
	TaixuanUIData.export_json(path, _gather_doc())


# 导出 Godot 原生场景（.tscn）：直接生成可在 Godot 打开的布局场景
func _export_tscn_dialog() -> void:
	_on_export_tscn_selected(DEFAULT_TSCN_PATH)


func _on_export_tscn_selected(path: String) -> void:
	if not path.ends_with(".tscn"):
		path += ".tscn"
	var ok: bool = TaixuanUIData.export_tscn(path, _gather_doc())
	if ok:
		info_label.text = "已导出场景：%s" % path
	else:
		info_label.text = "导出失败，请检查路径与资源"


# =============================================================================
# 模板库（沉淀项目 UI 规范：样式模板 / 布局模板）
# =============================================================================
func _open_template_library() -> void:
	TaixuanUIData.ensure_builtin_samples()
	# 防重复打开
	for ch in self.get_children():
		if ch is TemplateLibrary:
			ch.popup_centered(Vector2i(560, 640))
			return
	var lib: TemplateLibrary = load(TEMPLATE_LIB_PATH).new()
	lib.set_host(self)
	self.add_child(lib)
	lib.transient = true
	lib.popup_centered(Vector2i(560, 640))


# 重建视图但不重置历史（应用模板时使用，保证可撤销）
func _rebuild_view() -> void:
	_rebuild_canvas()
	overlay.queue_redraw()
	props.clear()
	_refresh_info()
	_sync_reference_controls()


# ---- 模板库 host 回调 ----
func get_selected_control_data() -> Dictionary:
	if selected.size() != 1:
		return {}
	var d: Dictionary = _node_data.get(selected[0], {})
	return d.duplicate(true)


func get_page_controls_for_template() -> Array:
	return controls.duplicate(true)


func get_page_canvas_for_template() -> Dictionary:
	return {
		"width": canvas_w,
		"height": canvas_h,
		"background_color": [bg_color.r, bg_color.g, bg_color.b, bg_color.a]
	}


# 应用控件样式模板：选中控件类型须与模板一致
func apply_style_template(tpl: Dictionary) -> void:
	if selected.is_empty():
		info_label.text = "请先选中至少一个控件，再应用样式模板"
		return
	var tt: String = tpl.get("type", "")
	var style: Dictionary = tpl.get("style", {})
	var bad: int = 0
	for node in selected:
		var d: Dictionary = _node_data.get(node, {})
		if d.get("type", "") != tt:
			bad += 1
	if bad > 0:
		info_label.text = "样式模板[%s]类型(%s)与 %d 个选中控件不符" % [str(tpl.get("name", "")), tt, bad]
		return
	var cnt: int = selected.size()
	_commit()
	# 内容字段（文字/按钮文案）是每个实例的属性，样式模板只沉淀视觉规范，不覆盖
	var content_fields: Array = ["text", "button_text"]
	for nd in selected:
		var d: Dictionary = _node_data.get(nd, {})
		var cur: Dictionary = d.get("style", {})
		for k in style.keys():
			if k in content_fields:
				continue
			cur[k] = style[k]
		d["style"] = cur
	_rebuild_view()
	_commit()
	info_label.text = "已应用样式：%s（%d 个控件）" % [str(tpl.get("name", "")), cnt]


# 应用页面布局模板：replace=true 替换当前页，否则追加并防重叠
func apply_layout_template(tpl: Dictionary, replace: bool) -> void:
	var tcontrols: Array = tpl.get("controls", [])
	if tcontrols.is_empty():
		info_label.text = "布局模板[%s]没有控件" % str(tpl.get("name", ""))
		return
	_commit()
	if replace:
		var cv: Dictionary = tpl.get("canvas", {})
		if cv.size() > 0:
			canvas_w = int(cv.get("width", canvas_w))
			canvas_h = int(cv.get("height", canvas_h))
			var bc: Array = cv.get("background_color", [])
			if bc.size() >= 4:
				bg_color = Color(float(bc[0]), float(bc[1]), float(bc[2]), float(bc[3]))
		# 替换模式：直接用模板控件整体替换当前页，不偏移、不重复追加
		controls = tcontrols.duplicate(true)
	else:
		# 追加模式：计算当前页最大范围，将模板控件整体偏移防重叠后追加
		var max_x: int = 0
		var max_y: int = 0
		for d in controls:
			var p: Array = d.get("position", [0, 0])
			var s: Array = d.get("size", [0, 0])
			max_x = max(max_x, int(p[0]) + int(s[0]))
			max_y = max(max_y, int(p[1]) + int(s[1]))
		var off: int = 40
		var used_names: Array = []
		for dn in controls:
			used_names.append(dn.get("name", ""))
		for c in tcontrols:
			var nc: Dictionary = c.duplicate(true)
			var base_name: String = nc.get("name", "Control")
			var new_name: String = base_name
			var idx: int = 1
			while new_name in used_names:
				new_name = "%s_%d" % [base_name, idx]
				idx += 1
			nc["name"] = new_name
			used_names.append(new_name)
			var p: Array = nc.get("position", [0, 0])
			nc["position"] = [int(p[0]) + max_x + off, int(p[1]) + off]
			controls.append(nc)
	_rebuild_view()
	_commit()
	info_label.text = "已应用布局：%s（%s）" % [str(tpl.get("name", "")), "替换当前页" if replace else "追加到当前页"]


# =============================================================================
# 键盘快捷键（窗口级）
# =============================================================================
func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var ctrl: bool = e.ctrl_pressed or e.meta_pressed
		if ctrl and e.keycode == KEY_Z:
			if e.shift_pressed:
				_redo()
			else:
				_undo()
			get_viewport().set_input_as_handled()
		elif ctrl and e.keycode == KEY_Y:
			_redo()
			get_viewport().set_input_as_handled()
		elif ctrl and e.keycode == KEY_D:
			_duplicate_selected()
			get_viewport().set_input_as_handled()
		elif e.keycode == KEY_DELETE or e.keycode == KEY_BACKSPACE:
			_delete_selected()
			get_viewport().set_input_as_handled()

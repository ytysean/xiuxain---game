@tool
extends Window
class_name AssetPicker

# =============================================================================
# 太玄UI编辑器 —— 轻量资源拾取器（替代易碎的 EditorFileDialog 子窗口）
# =============================================================================
# 作为编辑器主窗口的子窗口弹出（与 TemplateLibrary 同机制，稳定可见），
# 递归扫描 res:// 下匹配扩展名的文件，单击选中（单模式）或勾选多文件（多模式），
# 通过 callback 把 res:// 路径回传，避免 EditorFileDialog 在自定义窗口下渲染不出来的坑。
# =============================================================================


var filters: Array = []            # 扩展名过滤，如 ["png","jpg","webp","svg","ttf","otf","font"]
var multi: bool = false
var callback: Callable
var root_dir: String = "res://"

var _list: VBoxContainer
var _checks: Dictionary = {}       # path -> CheckBox


func _ready() -> void:
	title = "选择资源"
	size = Vector2i(720, 560)
	close_requested.connect(_on_close_requested)
	_build()


func _on_close_requested() -> void:
	queue_free()


func _build() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var hint: Label = Label.new()
	var fstr: String = ", ".join(filters) if not filters.is_empty() else "全部"
	hint.text = "根目录：%s    过滤：%s" % [root_dir, fstr]
	root.add_child(hint)

	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	root.add_child(sc)

	_populate()

	if multi:
		var bottom: HBoxContainer = HBoxContainer.new()
		var ok: Button = Button.new()
		ok.text = "确认选择"
		ok.pressed.connect(_on_confirm)
		var cancel: Button = Button.new()
		cancel.text = "取消"
		cancel.pressed.connect(queue_free)
		bottom.add_child(ok)
		bottom.add_child(cancel)
		root.add_child(bottom)


func _populate() -> void:
	var files: PackedStringArray = _scan(root_dir, 0)
	files.sort()
	if files.size() > 3000:
		files = files.slice(0, 3000)
	if files.is_empty():
		var nl: Label = Label.new()
		nl.text = "（未找到匹配文件）"
		_list.add_child(nl)
		return
	for f in files:
		if multi:
			var hb: HBoxContainer = HBoxContainer.new()
			var cb: CheckBox = CheckBox.new()
			cb.text = f
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_checks[f] = cb
			hb.add_child(cb)
			_list.add_child(hb)
		else:
			var b: Button = Button.new()
			b.text = f
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func(): _pick(f))
			_list.add_child(b)


func _pick(p: String) -> void:
	if callback.is_valid():
		callback.call(p)
	queue_free()


func _on_confirm() -> void:
	var paths: PackedStringArray = []
	for k in _checks.keys():
		if _checks[k].button_pressed:
			paths.append(k)
	if callback.is_valid():
		callback.call(paths)
	queue_free()


func _scan(dir: String, depth: int) -> PackedStringArray:
	var out: PackedStringArray = []
	if depth > 6:
		return out
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		if da.current_is_dir():
			if name != "." and name != "..":
				out.append_array(_scan(dir.path_join(name), depth + 1))
		else:
			if _match_filter(name):
				out.append(dir.path_join(name))
		name = da.get_next()
	da.list_dir_end()
	return out


func _match_filter(fname: String) -> bool:
	if filters.is_empty():
		return true
	var ext: String = fname.get_extension().to_lower()
	for f in filters:
		var fe: String = f.strip_edges().to_lower().lstrip("*.").lstrip(".")
		if fe == "" or fe == ext:
			return true
	return false

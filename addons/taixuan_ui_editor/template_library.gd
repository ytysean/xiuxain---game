@tool
extends Window
class_name TemplateLibrary

# =============================================================================
# 太玄UI编辑器 —— 模板库面板（独立窗口）
# =============================================================================
# 沉淀项目 UI 规范：把常用控件样式、整页布局保存为可复用模板，一键应用。
# 两类模板：
#   - 控件样式模板（style）：应用到选中的同类控件
#   - 页面布局模板（layout）：追加或替换到当前页
#
# 交互：顶部输入名称 → 存为样式/布局模板；中部列表分组展示，每个可应用/删除。
# 业务回调转发给 host（ui_editor 实例）；模板文件读写走 TaixuanUIData 静态层。
# =============================================================================


var host = null                  # ui_editor 实例（由外部 set_host 赋值，Variant 以支持动态回调）
var _name_edit: LineEdit
var _replace_check: CheckBox
var _list: VBoxContainer
var info_label: Label


func _ready() -> void:
	title = "模板库"
	size = Vector2i(560, 640)
	close_requested.connect(_on_close_requested)
	_build_ui()
	_refresh_list()


# 点右上角 X 关闭窗口（Window 默认不会自动关闭，必须处理 close_requested）
func _on_close_requested() -> void:
	hide()


func set_host(h: Object) -> void:
	host = h


func _build_ui() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# 顶部：名称输入 + 两个保存按钮
	var top: HBoxContainer = HBoxContainer.new()
	var nl: Label = Label.new(); nl.text = "名称"
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "模板名（留空用默认）"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size = Vector2(140, 0)
	var sb_style: Button = Button.new(); sb_style.text = "存为样式模板"
	sb_style.pressed.connect(_on_save_style)
	var sb_layout: Button = Button.new(); sb_layout.text = "存为布局模板"
	sb_layout.pressed.connect(_on_save_layout)
	top.add_child(nl)
	top.add_child(_name_edit)
	top.add_child(sb_style)
	top.add_child(sb_layout)
	root.add_child(top)

	# 选项
	_replace_check = CheckBox.new()
	_replace_check.text = "应用布局模板时替换当前页（否则追加到当前页）"
	root.add_child(_replace_check)

	# 列表区
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	root.add_child(sc)

	# 底部
	var bottom: HBoxContainer = HBoxContainer.new()
	info_label = Label.new()
	info_label.text = "选中控件后可存样式模板；当前页有控件时可存布局模板"
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var refresh_btn: Button = Button.new(); refresh_btn.text = "刷新"
	refresh_btn.pressed.connect(_refresh_list)
	var close_btn: Button = Button.new(); close_btn.text = "关闭"
	close_btn.pressed.connect(queue_free)
	bottom.add_child(info_label)
	bottom.add_child(refresh_btn)
	bottom.add_child(close_btn)
	root.add_child(bottom)


func _toast(msg: String) -> void:
	if info_label != null:
		info_label.text = msg


func _safe_name(nm: String) -> String:
	nm = nm.strip_edges()
	if nm == "":
		nm = "模板"
	nm = nm.replace("/", "_").replace("\\", "_").replace(":", "_")
	return nm


# ----------------------- 保存 -----------------------
func _on_save_style() -> void:
	if host == null:
		_toast("未连接到编辑器")
		return
	var sel: Dictionary = host.get_selected_control_data()
	if sel.is_empty():
		_toast("请先选中一个控件再存样式模板")
		return
	var nm: String = _safe_name(_name_edit.text)
	TaixuanUIData.ensure_template_dir(TaixuanUIData.USER_TEMPLATE_DIR)
	var path: String = TaixuanUIData.USER_TEMPLATE_DIR.path_join(nm + ".tuit")
	TaixuanUIData.save_style_template(path, sel.get("type", ""), nm, sel.get("style", {}))
	_refresh_list()
	_toast("已保存样式模板：%s" % nm)


func _on_save_layout() -> void:
	if host == null:
		_toast("未连接到编辑器")
		return
	var ctrls: Array = host.get_page_controls_for_template()
	if ctrls.is_empty():
		_toast("当前页面没有控件可保存为布局模板")
		return
	var nm: String = _safe_name(_name_edit.text)
	var canvas: Dictionary = host.get_page_canvas_for_template()
	TaixuanUIData.ensure_template_dir(TaixuanUIData.USER_TEMPLATE_DIR)
	var path: String = TaixuanUIData.USER_TEMPLATE_DIR.path_join(nm + ".tuit")
	TaixuanUIData.save_layout_template(path, nm, canvas, ctrls)
	_refresh_list()
	_toast("已保存布局模板：%s" % nm)


# ----------------------- 应用 / 删除 -----------------------
func _apply(tpl: Dictionary) -> void:
	if host == null:
		_toast("未连接到编辑器")
		return
	if tpl.get("kind") == "layout":
		host.apply_layout_template(tpl, _replace_check.button_pressed)
	else:
		host.apply_style_template(tpl)


func _delete(tpl: Dictionary) -> void:
	if tpl.get("source") != "user":
		_toast("内置模板不可删除")
		return
	TaixuanUIData.delete_template(tpl.get("path", ""))
	_refresh_list()
	_toast("已删除：%s" % str(tpl.get("name", "")))


# ----------------------- 列表渲染 -----------------------
func _refresh_list() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	var tpls: Array = TaixuanUIData.list_templates()
	var styles: Array = []
	var layouts: Array = []
	for t in tpls:
		if t.get("kind") == "layout":
			layouts.append(t)
		else:
			styles.append(t)
	_append_group("控件样式模板", styles)
	_append_group("页面布局模板", layouts)


func _append_group(header: String, items: Array) -> void:
	if items.is_empty():
		return
	var hl: Label = Label.new()
	hl.text = header
	hl.add_theme_font_size_override("font_size", 18)
	_list.add_child(hl)
	for t in items:
		_list.add_child(_make_row(t))


func _make_row(t: Dictionary) -> Control:
	var hb: HBoxContainer = HBoxContainer.new()
	var kind: String = t.get("kind", "")
	var tag: String = "[页]" if kind == "layout" else "[%s]" % _type_tag(str(t.get("type", "")))
	var tl: Label = Label.new()
	tl.text = tag
	tl.custom_minimum_size = Vector2(64, 0)
	var nl: Label = Label.new()
	nl.text = str(t.get("name", ""))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sl: Label = Label.new()
	sl.text = "内置" if t.get("source") == "builtin" else "用户"
	var ab: Button = Button.new()
	ab.text = "应用"
	ab.pressed.connect(_apply.bind(t))
	hb.add_child(tl)
	hb.add_child(nl)
	hb.add_child(sl)
	hb.add_child(ab)
	if t.get("source") == "user":
		var db: Button = Button.new()
		db.text = "删除"
		db.pressed.connect(_delete.bind(t))
		hb.add_child(db)
	return hb


func _type_tag(type: String) -> String:
	match type:
		"Label": return "文字"
		"Button": return "按钮"
		"Panel": return "面板"
		"TextureRect": return "图片"
		"AnimatedTexture": return "动画"
		"SpriteSheet": return "图集"
	return type

@tool
extends EditorPlugin

# =============================================================================
# 太玄UI编辑器 —— 插件入口（EditorPlugin）
# =============================================================================
# 功能：
#   - 在 Godot 编辑器顶部工具栏 + “项目 -> 工具”子菜单注册“太玄UI编辑器”
#   - 点击后打开一个独立的可视化编辑窗口（ui_editor.gd）
#
# 说明：
#   - 使用 add_tool_menu_item / add_control_to_container，由引擎托管生命周期
#   - 不预加载（preload）任何依赖脚本，避免某一下游脚本解析失败导致
#     本插件入口脚本 itself 级联报错。窗口打开时 runtime load 实例化。
#   - 若打开窗口后仍报错，Godot 输出面板会明确给出具体脚本/行号。
# =============================================================================

const UI_SCRIPT_PATH: String = "res://addons/taixuan_ui_editor/ui_editor.gd"
const TOOL_MENU_ITEM: String = "太玄UI编辑器"

var _toolbar_button: Button = null


func _enter_tree() -> void:
	# 兜底入口：项目 -> 工具 子菜单
	add_tool_menu_item(TOOL_MENU_ITEM, _open_editor)
	# 醒目入口：顶部主工具栏按钮（延迟一帧，等编辑器容器初始化完成）
	call_deferred("_add_toolbar_button")


func _add_toolbar_button() -> void:
	if _toolbar_button != null and is_instance_valid(_toolbar_button):
		return
	_toolbar_button = Button.new()
	_toolbar_button.text = "太玄UI编辑器"
	_toolbar_button.tooltip_text = "打开太玄UI编辑器（可视化界面编辑器）"
	_toolbar_button.custom_minimum_size = Vector2(132, 30)
	_toolbar_button.pressed.connect(_open_editor)
	add_control_to_container(CONTAINER_TOOLBAR, _toolbar_button)
	var parent = _toolbar_button.get_parent()
	if parent == null:
		push_warning("太玄UI编辑器：工具栏按钮未挂到任何容器")
	else:
		print("太玄UI编辑器：工具栏按钮已注册，父节点 = ", parent.name)


func _exit_tree() -> void:
	remove_tool_menu_item(TOOL_MENU_ITEM)
	if _toolbar_button != null and is_instance_valid(_toolbar_button):
		remove_control_from_container(CONTAINER_TOOLBAR, _toolbar_button)
		_toolbar_button.queue_free()
		_toolbar_button = null


# -----------------------------------------------------------------------------
# 打开编辑器窗口
# -----------------------------------------------------------------------------
func _open_editor() -> void:
	var base = EditorInterface.get_base_control()
	if base == null:
		push_error("太玄UI编辑器：无法获取编辑器根控件")
		return
	# 防止重复打开多个窗口
	for child in base.get_children():
		if child.get_script() != null and child.get_script().resource_path == UI_SCRIPT_PATH:
			child.popup_centered(Vector2i(1180, 820))
			return
	# 运行时加载窗口脚本（依赖脚本的 class_name 由 Godot 自动注册）
	var scr: GDScript = load(UI_SCRIPT_PATH)
	if scr == null:
		push_error("太玄UI编辑器：load 返回 null，路径 %s" % UI_SCRIPT_PATH)
		return
	if not scr.can_instantiate():
		push_error("太玄UI编辑器：脚本无法实例化（通常因自身或依赖脚本存在 Parse Error）。路径 %s" % UI_SCRIPT_PATH)
		return
	var editor = scr.new()
	base.add_child(editor)
	editor.popup_centered(Vector2i(1180, 820))

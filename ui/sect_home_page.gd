extends Control

# 宗门主权展示页（首页 = 一级页「宗门」），截图还原版。
# 布局：
#   - 全屏山门背景（home_bg_sect_a.png）
#   - 左侧竖导航：「总览」（默认选中）/「功能」
#   - 底部折叠区：「近期动态」/「殿阁概况」（可展开收起）
# 红线条：仅展示 + 入口；所有数据只读 Game Autoload，绝不写 GameState / 玩法 / 战斗逻辑。

# 导航项点击信号（上行到 game_ui 别名路由）
signal nav_selected(nav_id: String)

# 折叠区状态
var _fold_dynamic: bool = false    # 近期动态：默认折叠
var _fold_halls: bool = false      # 殿阁概况：默认折叠

func _ready() -> void:
	_apply_theme()
	_wire_signals()

func _apply_theme() -> void:
	# 左侧导航按钮样式
	var nav_总览: Button = get_node_or_null("LeftNav/Nav_总览")
	if nav_总览 != null:
		_apply_nav_style(nav_总览, true)
	var nav_功能: Button = get_node_or_null("LeftNav/Nav_功能")
	if nav_功能 != null:
		_apply_nav_style(nav_功能, false)

	# 折叠区标题样式
	for section in ["FoldSection_动态", "FoldSection_殿阁"]:
		var title: Label = get_node_or_null(section + "/Title")
		if title != null:
			UITheme.apply_title_font_sized(title, 16)
			title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)
		var arrow: Label = get_node_or_null(section + "/Arrow")
		if arrow != null:
			UITheme.apply_body_font_sized(arrow, 16)
			arrow.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)

func _apply_nav_style(btn: Button, is_active: bool) -> void:
	UITheme.apply_title_font_sized(btn, 16)
	if is_active:
		btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	else:
		btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)

func _wire_signals() -> void:
	var nav_总览: Button = get_node_or_null("LeftNav/Nav_总览")
	if nav_总览 != null and not nav_总览.pressed.is_connected(_on_nav_pressed.bind("总览")):
		nav_总览.pressed.connect(_on_nav_pressed.bind("总览"))
	var nav_功能: Button = get_node_or_null("LeftNav/Nav_功能")
	if nav_功能 != null and not nav_功能.pressed.is_connected(_on_nav_pressed.bind("功能")):
		nav_功能.pressed.connect(_on_nav_pressed.bind("功能"))

	# 折叠区点击（整行可点）
	for section in ["FoldSection_动态", "FoldSection_殿阁"]:
		var bg: Panel = get_node_or_null(section + "/BG")
		if bg != null:
			bg.gui_input.connect(_on_fold_input.bind(section))

func _on_nav_pressed(nav_id: String) -> void:
	# 更新视觉激活态
	for nid in ["总览", "功能"]:
		var btn: Button = get_node_or_null("LeftNav/Nav_" + nid)
		if btn != null:
			if nid == nav_id:
				btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
			else:
				btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	nav_selected.emit(nav_id)

func _on_fold_input(event: InputEvent, section: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match section:
			"FoldSection_动态":
				_fold_dynamic = !_fold_dynamic
				_update_fold_arrow("FoldSection_动态", _fold_dynamic)
			"FoldSection_殿阁":
				_fold_halls = !_fold_halls
				_update_fold_arrow("FoldSection_殿阁", _fold_halls)

func _update_fold_arrow(section: String, expanded: bool) -> void:
	var arrow: Label = get_node_or_null(section + "/Arrow")
	if arrow != null:
		arrow.text = "∧" if expanded else "∨"

# 只读刷新（由 game_ui._refresh_all_pages 调用；推演 / 新游戏 / 读档后统一重拉）。
func refresh() -> void:
	# 截图版首页数据较轻量，主要靠顶栏展示核心数值
	# 未来展开折叠区时再填充动态数据
	pass

extends Control

# 《太玄宗门录》S1 根 UI 合成场景（GameUI）。
# 组合：TopBar（顶 48dp）+ 页面容器（中）+ BottomTabBar（底 64dp）。
# 本场景仅做 UI 合成与信号转发，绝不连玩法 / 写 GameState / 写任何数值逻辑（铁律红线）。
# 仅 宗门（SectHomePage）已建成；其余 Tab 显示轻量「建设中」占位，待后续真页面接入。
# 子节点在 _ready 内由代码构建（.tscn 仅含根节点 + 本脚本），保证场景可独立实例化。

const TopBarScene: PackedScene = preload("res://ui/top_bar.tscn")
const BottomTabBarScene: PackedScene = preload("res://ui/bottom_tab_bar.tscn")
const SectHomePageScene: PackedScene = preload("res://ui/sect_home_page.tscn")
const PageDiscipleScene: PackedScene = preload("res://ui/page_disciple.tscn")
const PageBuildingScene: PackedScene = preload("res://ui/page_building.tscn")
const PageExploreScene: PackedScene = preload("res://ui/page_explore.tscn")
const PageChronicleScene: PackedScene = preload("res://ui/page_chronicle.tscn")

# 与 BottomTabBar.TABS 保持一致（§7.1）；首位 宗门 为已建成页。
const PAGE_IDS: Array = ["宗门", "弟子", "建筑", "历练", "纪事"]

var _top_bar: Control
var _bottom_bar: Control
var _page_container: Control
var _pages: Dictionary = {}
var _current: Control

func _ready() -> void:
	_build()
	_wire()
	_select_initial()
	_apply_safe_defaults()

# ───────── 构建 ─────────
func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 中部页面容器：顶 48dp 与底 64dp 之间，挂载各一级页（子页自身管理内边距）。
	_page_container = Control.new()
	_page_container.name = "PageContainer"
	_page_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_container.anchor_top = 0.0
	_page_container.offset_top = UITheme.TOPBAR_H
	_page_container.anchor_bottom = 1.0
	_page_container.offset_bottom = -UITheme.TAB_H
	add_child(_page_container)

	# 顶部状态栏（自锚定 TOP_WIDE，高 48）
	_top_bar = TopBarScene.instantiate() as Control
	_top_bar.name = "TopBar"
	add_child(_top_bar)

	# 底部主导航（自锚定 BOTTOM_WIDE，高 64）
	_bottom_bar = BottomTabBarScene.instantiate() as Control
	_bottom_bar.name = "BottomTabBar"
	add_child(_bottom_bar)

	# 预建页面：宗门 为真实页；其余四页实例化真实只读页场景（接 建设中 占位）。
	for id in PAGE_IDS:
		match id:
			"宗门":
				_pages[id] = _make_real_page(SectHomePageScene, id)
			"弟子":
				_pages[id] = _make_real_page(PageDiscipleScene, id)
			"建筑":
				_pages[id] = _make_real_page(PageBuildingScene, id)
			"历练":
				_pages[id] = _make_real_page(PageExploreScene, id)
			"纪事":
				_pages[id] = _make_real_page(PageChronicleScene, id)

# 实例化真实页场景（仅占位 Control，子节点由各自脚本 _ready 内建）。
func _make_real_page(scene: PackedScene, id: String) -> Control:
	var page := scene.instantiate() as Control
	page.name = "Page_" + id
	return page

# ───────── 信号接线 ─────────
func _wire() -> void:
	_bottom_bar.tab_selected.connect(_on_tab_selected)
	_top_bar.time_advance_requested.connect(_on_time_advance_requested)

# ───────── 首屏安全默认值 + 概览刷新 ─────────
func _apply_safe_defaults() -> void:
	# 只读安全默认值（零/空），绝不读 Game / 改玩法。
	_top_bar.set_time("时辰")
	_top_bar.set_sect_level("宗门")
	_top_bar.set_level_progress(0.0)
	_top_bar.set_resource("灵石", "", false)
	_top_bar.set_resource("灵气", "", false)
	_top_bar.set_resource("弟子", "", false)
	# 首屏刷新：所有真实页统一 refresh()（宗门页提供 refresh_overview()，其余提供 refresh()）。
	# 全部只读 Game，内部已做 null 守卫；绝不写 GameState / 玩法。
	_refresh_all_pages()

func _select_initial() -> void:
	_show_page("宗门")

# ───────── 页面切换器（结构留白，便于真页面后续直接接入）─────────
func _show_page(tab_id: String) -> void:
	var page: Control = _pages.get(tab_id, null)
	if page == null:
		return
	if _current != null and _current != page:
		if _current.get_parent() == _page_container:
			_page_container.remove_child(_current)
	if page.get_parent() == null:
		_page_container.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_current = page

func _on_tab_selected(tab_id: String) -> void:
	_show_page(tab_id)

# 推演时日：时间推进待玩法侧接入；当前仅占位日志，不写任何玩法/战斗逻辑。
func _on_time_advance_requested() -> void:
	print("[GameUI] 推演时日 触发（时间推进待玩法侧接入，当前仅占位日志，未触碰玩法/战斗）")
	# 推演后重拉各只读页数据（read-only refresh，不写玩法）。
	_refresh_all_pages()

# 对所有真实页触发只读刷新（宗门→refresh_overview，其余→refresh）。
func _refresh_all_pages() -> void:
	for id in PAGE_IDS:
		var page: Control = _pages.get(id, null)
		if page == null:
			continue
		if page.has_method("refresh"):
			page.refresh()
		elif page.has_method("refresh_overview"):
			page.refresh_overview()

# 对外只读刷新入口：main.gd 在 弟子变动 / 读档 / 新游戏 后调用，重拉各只读页数据，零玩法/战斗触碰
func refresh_all() -> void:
	_refresh_all_pages()

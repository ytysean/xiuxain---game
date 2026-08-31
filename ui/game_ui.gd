extends Control

# 登出请求：设置页「退出登录」→ 本场景转发至 main 的账号系统登出流程（回到登录/选择面板）。
signal 登出请求

# 《太玄宗门录》S1 根 UI 合成场景（GameUI）。
# 组合：TopBar（顶 56dp）+ 页面容器（中）+ BottomTabBar（底 60dp）。
# 本场景仅做 UI 合成与信号转发，绝不连玩法 / 写 GameState / 写任何数值逻辑（铁律红线）。
# 仅 宗门（SectHomePage 展示型首页）已建成；其余 Tab 显示轻量「建设中」占位，待后续真页面接入。
# 子节点在 _ready 内由代码构建（.tscn 仅含根节点 + 本脚本），保证场景可独立实例化。

const TopBarScene: PackedScene = preload("res://ui/top_bar.tscn")
const BottomTabBarScene: PackedScene = preload("res://ui/bottom_tab_bar.tscn")
const SectHomePageScene: PackedScene = preload("res://ui/sect_home_page.tscn")
const PageDiscipleScene: PackedScene = preload("res://ui/page_disciple.tscn")
const PageBuildingScene: PackedScene = preload("res://ui/page_building.tscn")
const PageExploreScene: PackedScene = preload("res://ui/page_explore.tscn")
const PageChronicleScene: PackedScene = preload("res://ui/page_chronicle.tscn")

# 二级页（由 01 屏左右入口打开，盖在一级页之上，返回后回到原 Tab）
const PageQuestScene: PackedScene = preload("res://ui/page_quest.tscn")
const PageStorageScene: PackedScene = preload("res://ui/page_storage.tscn")
const PageBattlepassScene: PackedScene = preload("res://ui/page_battlepass.tscn")
const PagePlaceholderScene: PackedScene = preload("res://ui/page_placeholder.tscn")
const PageHuanxingScene: PackedScene = preload("res://ui/page_huanxing.tscn")
const PageDaoyouScene: PackedScene = preload("res://ui/page_daoyou.tscn")
const PageSectManagerScene: PackedScene = preload("res://ui/page_sect_manager.tscn")
const PagePremiumScene: PackedScene = preload("res://ui/page_premium.tscn")
const PageShopScene: PackedScene = preload("res://ui/page_shop.tscn")
const PageLeaderboardScene: PackedScene = preload("res://ui/page_leaderboard.tscn")
const PageMailScene: PackedScene = preload("res://ui/page_mail.tscn")
const PageSettingsScene: PackedScene = preload("res://ui/page_settings.tscn")
const PageRulesScene: PackedScene = preload("res://ui/page_rules.tscn")
const PageCodexScene: PackedScene = preload("res://ui/page_codex.tscn")
const PageMasterDetailScene: PackedScene = preload("res://ui/master_detail_page.tscn")
const PageDiscipleDetailScene: PackedScene = preload("res://ui/disciple_detail_page.tscn")
const PageSkinShopScene: PackedScene = preload("res://ui/skin_shop_page.tscn")
const PageMasterSkinShopScene: PackedScene = preload("res://ui/master_skin_shop_page.tscn")
const PageFactionScene: PackedScene = preload("res://ui/page_faction.tscn")
const PageZongmenBattleScene: PackedScene = preload("res://ui/page_zongmen_battle.tscn")
const PageFragmentChestScene: PackedScene = preload("res://ui/page_fragment_chest.tscn")
const PagePuppetScene: PackedScene = preload("res://ui/page_puppet.tscn")
const PageLibraryScene: PackedScene = preload("res://ui/page_library.tscn")
const PageHerbGardenScene: PackedScene = preload("res://ui/page_herb_garden.tscn")
const PagePillFormulaScene: PackedScene = preload("res://ui/page_pill_formula.tscn")
const PageEquipmentBlueprintScene: PackedScene = preload("res://ui/page_equipment_blueprint.tscn")
const PageActivityScene: PackedScene = preload("res://ui/page_activity.tscn")

# 与 BottomTabBar.TABS 保持一致（§7.1）；首位 宗门 为已建成展示型首页（SectHomePage）。
const PAGE_IDS: Array = ["宗门", "弟子", "殿阁", "历练", "纪事"]

# 宗门首页网格入口别名路由（纯 UI 跳转，不碰玩法/战斗红线）：
#   灵植 → 殿阁 Tab；秘境 → 历练 Tab。其余入口 id 与一级页同名，直跳。
#   注：坊市 / 库藏 已各自映射到真实二级页（坊市 / 库藏），不再走别名。
const ENTRY_ALIAS: Dictionary = {"灵植": "殿阁", "秘境": "历练"}

# 01 屏左右入口 → 二级页 scene 映射（id 与 sect_home_page.ENTRIES 中的 id 保持一致）
const ENTRY_SUB_PAGES: Dictionary = {
	"宗务": PageQuestScene,
	"坊市": PageShopScene,
	"库藏": PageStorageScene,
	"功勋": PageBattlepassScene,
	"灵讯": PageMailScene,
	"玄榜": PageLeaderboardScene,
	"幻形": PageHuanxingScene,
	"宗规": PageRulesScene,
	"道友": PageDaoyouScene,
	"日供": PagePremiumScene,
	"设置": PageSettingsScene,
	"图录": PageCodexScene,
	"宗主管理": PageSectManagerScene,
	"阵营声望": PageFactionScene,
	"宗门战": PageZongmenBattleScene,
	"碎片宝箱": PageFragmentChestScene,
	"傀儡": PagePuppetScene,
	"藏书阁": PageLibraryScene,
	"药园": PageHerbGardenScene,
	"丹方": PagePillFormulaScene,
	"装备图纸": PageEquipmentBlueprintScene,
	"活动中心": PageActivityScene,
}

var _top_bar: Control
var _bottom_bar: Control
var _page_container: Control
var _sub_page_container: Control
var _sub_bg: ColorRect = null
var _sub_top_bg: ColorRect = null
var _pages: Dictionary = {}
var _sub_pages: Dictionary = {}
var _current: Control
var _current_sub: Control = null
var _master_sub_open: bool = false    # 宗主详情 sub 打开标志（关闭时恢复顶栏）
var _last_tab_page: String = "宗门"
var _页_宗门: Control = null
var _edit_popup_instance: Control = null    # 宗主改名弹窗（CanvasLayer 复用实例）

func _ready() -> void:
	_build()
	_wire()
	_select_initial()
	_apply_safe_defaults()
	# 通用轻提示总线：Game.添加提示(文本) → 本页 toast（宗门战等二级页依赖此通道）
	if Game.has_signal("提示") and not Game.提示.is_connected(_toast):
		Game.提示.connect(_toast)

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

	# 二级页容器：与一级页同区域，但始终盖在最上层；用于 01 屏入口打开的二级页。
	_sub_page_container = Control.new()
	_sub_page_container.name = "SubPageContainer"
	_sub_page_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub_page_container.anchor_top = 0.0
	_sub_page_container.offset_top = UITheme.TOPBAR_H
	_sub_page_container.anchor_bottom = 1.0
	_sub_page_container.offset_bottom = -UITheme.TAB_H
	_sub_page_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub_page_container)

	# 二级页统一全屏内容底：默认隐藏，仅在二级页打开时显示，避免遮挡首页
	_sub_bg = ColorRect.new()
	_sub_bg.name = "SubPageBG"
	_sub_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub_bg.color = UITheme.SECONDARY_CONTENT_BG
	_sub_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_bg.visible = false
	_sub_page_container.add_child(_sub_bg)

	# 二级页顶部背景补片：覆盖 0~TOPBAR_H 区域，避免二级页打开时顶栏后方仍透出首页背景
	_sub_top_bg = ColorRect.new()
	_sub_top_bg.name = "SubPageTopBG"
	_sub_top_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_sub_top_bg.offset_top = 0.0
	_sub_top_bg.offset_bottom = UITheme.TOPBAR_H
	_sub_top_bg.color = UITheme.SECONDARY_CONTENT_BG
	_sub_top_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_top_bg.visible = false
	add_child(_sub_top_bg)

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
				var 宗门页: Control = _make_real_page(SectHomePageScene, id)
				_页_宗门 = 宗门页
				# 01 屏 1:1：8 入口上行 + 隐藏UI开关信号
				宗门页.entry_selected.connect(_on_首页入口)
				宗门页.hide_ui_requested.connect(_on_hide_ui_requested)
				_pages[id] = 宗门页
			"弟子":
				var 弟子页: Control = _make_real_page(PageDiscipleScene, id)
				if 弟子页.has_signal("弟子详情请求"):
					弟子页.弟子详情请求.connect(_open_disciple_detail)
				_pages[id] = 弟子页
			"殿阁":
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
	# 顶栏「宗门名 + Lv」→ 打开宗主详情页（全屏二级页，独立于左右入口二级页流程）
	if _top_bar != null and is_instance_valid(_top_bar) and _top_bar.has_signal("宗主详情请求"):
		_top_bar.宗主详情请求.connect(_open_master_detail)
	# 宗主改名弹窗预热（CanvasLayer 复用实例，常驻隐藏，唤起即显）
	_预热_编辑弹窗()

# 顶部栏右区扩展点（预留，当前无注入控件）。
func add_top_corner_control(control: Control) -> void:
	pass

# ───────── 首屏安全默认值 + 概览刷新 ─────────
func _apply_safe_defaults() -> void:
	# 顶部栏资源只读刷新（Game 已就绪；top_bar._ready 亦会刷一次，此处确保首屏安全值）。
	_top_bar.refresh_resources()
	# 首屏刷新：所有真实页统一 refresh()（首页与其余页均提供 refresh()，只读 Game，绝不写 GameState / 玩法）。
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
	_last_tab_page = tab_id
	# 切换一级页时，若二级页还开着则先收起。
	_close_sub_page()

func _on_tab_selected(tab_id: String) -> void:
	_show_page(tab_id)

# 首页网格入口（sect_home_page.entry_selected）：纯 UI 路由 → 一级页切页 或 二级页打开，不碰玩法/战斗红线
func _on_首页入口(entry_id: String) -> void:
	# 1) 山门：已在宗门页，直接回到宗门并刷新。
	if entry_id == "山门":
		_show_page("宗门")
		if _页_宗门 != null and _页_宗门.has_method("refresh"):
			_页_宗门.refresh()
		return

	# 2) 有真实二级页的入口：打开对应二级页。
	var sub_scene: PackedScene = ENTRY_SUB_PAGES.get(entry_id, null)
	if sub_scene != null:
		_show_sub_page(entry_id, sub_scene)
		return

	# 3) 与一级页同名的入口：直接切 Tab。
	var target: String = ENTRY_ALIAS.get(entry_id, entry_id)
	if target in PAGE_IDS:
		_show_page(target)
		return

	# 4) 其余入口：理论上已全部映射到真实/占位二级页，此处兜底提示。
	_toast("【%s】系统即将开放" % entry_id)

# 打开二级页（覆盖在一级页之上）。
func _show_sub_page(id: String, scene: PackedScene) -> void:
	if scene == null:
		push_warning("二级页 scene 为空：%s" % id)
		return
	_close_sub_page()
	# 二级/三级页全屏：隐藏底部 5Tab、扩展页面容器至底部，并隐藏 01 屏 chrome 避免入口遮挡
	if _bottom_bar != null and is_instance_valid(_bottom_bar):
		_bottom_bar.visible = false
		_bottom_bar.set_deferred("visible", false)
	if _页_宗门 != null and is_instance_valid(_页_宗门) and _页_宗门.has_method("set_chrome_visible"):
		_页_宗门.set_chrome_visible(false)
	_page_container.offset_bottom = 0.0
	_sub_page_container.offset_bottom = 0.0
	var page: Control = _sub_pages.get(id, null)
	if page == null or not is_instance_valid(page):
		page = scene.instantiate() as Control
		if page == null:
			push_error("二级页实例化失败：%s" % id)
			_bottom_bar.visible = true
			_page_container.offset_bottom = -UITheme.TAB_H
			_sub_page_container.offset_bottom = -UITheme.TAB_H
			return
		page.name = "SubPage_" + id
		_sub_pages[id] = page
		# 二级页统一返回信号 → 关闭二级页
		if page.has_signal("返回主页"):
			page.返回主页.connect(_on_二级页返回)
		# 设置页「退出登录」→ 转发至 main 账号系统登出流程
		if page.has_signal("登出请求"):
			page.登出请求.connect(_on_设置页登出)
		# 幻形页装备皮肤 → 实时刷新 01 屏背景（纯展示，零玩法触碰）
		if page.has_signal("皮肤已装备"):
			page.皮肤已装备.connect(_on_皮肤已装备)
		# 宗主详情页：7 权责按钮 + 编辑按钮（P0 实装，路由到对应系统页 / 改名弹窗）
		if page.has_signal("权责请求"):
			page.权责请求.connect(_on_权责请求)
		if page.has_signal("编辑请求"):
			page.编辑请求.connect(_on_编辑请求)
		# 坊市页面「仙衣阁」→ 打开皮肤商店页
		if page.has_signal("仙衣阁请求"):
			page.仙衣阁请求.connect(_open_skin_shop)
		# 坊市页面「宗主仙衣阁」→ 打开宗主皮肤商店页
		if page.has_signal("宗主仙衣阁请求"):
			page.宗主仙衣阁请求.connect(_open_master_skin_shop)
	if page.get_parent() == null:
		_sub_page_container.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.visible = true
	if _sub_bg != null:
		_sub_bg.visible = true
	if _sub_top_bg != null:
		_sub_top_bg.visible = true
	_current_sub = page
	_sub_page_container.mouse_filter = Control.MOUSE_FILTER_STOP
	# 占位页在显示前设置系统名
	if page.has_method("set_system_name"):
		page.set_system_name(id)
	if page.has_method("refresh"):
		page.refresh()

func _close_sub_page() -> void:
	if _current_sub != null and is_instance_valid(_current_sub):
		if _current_sub.get_parent() == _sub_page_container:
			_sub_page_container.remove_child(_current_sub)
	_current_sub = null
	if _sub_bg != null:
		_sub_bg.visible = false
	if _sub_top_bg != null:
		_sub_top_bg.visible = false
	_sub_page_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 恢复底部 5Tab、页面容器原始高度，并恢复 01 屏 chrome
	_bottom_bar.visible = true
	if _页_宗门 != null and is_instance_valid(_页_宗门) and _页_宗门.has_method("set_chrome_visible"):
		_页_宗门.set_chrome_visible(true)
	_page_container.offset_bottom = -UITheme.TAB_H
	_sub_page_container.offset_bottom = -UITheme.TAB_H
	# 恢复二级页容器顶部位置（宗主详情页打开时会设为 0）
	_sub_page_container.offset_top = UITheme.TOPBAR_H
	# 兜底：返回一级页时同步已装备皮肤背景（幻形换肤后确保 01 屏即时生效）
	if _页_宗门 != null and is_instance_valid(_页_宗门) and _页_宗门.has_method("_apply_equipped_skin"):
		_页_宗门._apply_equipped_skin()
	# 宗主详情特殊恢复：从顶栏进入时会额外藏顶栏，关闭时同步恢复。
	if _master_sub_open:
		_master_sub_open = false
		if _top_bar != null and is_instance_valid(_top_bar):
			_top_bar.visible = true
		# 顺便刷一次顶栏头像（玩家可能刚在弹窗改了头像）
		if _top_bar != null and is_instance_valid(_top_bar) and _top_bar.has_method("refresh_avatar"):
			_top_bar.refresh_avatar()

func _on_二级页返回() -> void:
	_close_sub_page()

# 设置页「退出登录」：转发至 main 账号系统登出流程（保存 → 释放本场景 → 回登录屏）
func _on_设置页登出() -> void:
	var m = get_parent()
	if m != null and m.has_method("_登出"):
		m._登出()

# 幻形页装备皮肤后，实时刷新 01 屏背景（纯展示，零玩法/战斗触碰）
func _on_皮肤已装备(skin_id: String) -> void:
	if _页_宗门 != null and is_instance_valid(_页_宗门) and _页_宗门.has_method("_apply_equipped_skin"):
		_页_宗门._apply_equipped_skin()

# 隐藏UI开关（sect_home_page.hide_ui_requested）：收起/恢复顶栏与底栏（纯展示，零玩法/战斗触碰）
func _on_hide_ui_requested(hidden: bool) -> void:
	if _top_bar != null and is_instance_valid(_top_bar):
		_top_bar.visible = not hidden
	if _bottom_bar != null and is_instance_valid(_bottom_bar):
		_bottom_bar.visible = not hidden

# 对所有真实页触发只读刷新（宗门→refresh_overview，其余→refresh）。
func _refresh_all_pages() -> void:
	# 顶部栏资源只读刷新（推演 / 新游戏 / 读档后统一重拉，零玩法/战斗触碰）。
	_top_bar.refresh_resources()
	# 顶部栏头像刷新：创建宗门页选定头像后/读档后，把玩家头像纹理套到顶栏徽记；缺省回落宗门徽记默认图标。
	_top_bar.refresh_avatar()
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

# 打开宗主详情页（全屏二级页 · 标准 sub_page 流程）：与 ENTRY_SUB_PAGES 共用 _show_sub_page 的 z 序 /
# preset / 信号链；额外多藏一个顶栏（从顶栏点入，顶栏挡住用户视线），关闭时由 _close_sub_page 恢复。
func _open_master_detail() -> void:
	print("[GameUI] _open_master_detail 被调用")
	_show_sub_page("宗主详情", PageMasterDetailScene)
	_master_sub_open = true
	if _top_bar != null and is_instance_valid(_top_bar):
		_top_bar.visible = false
	# 宗主详情页是立绘主导型，需要从屏幕顶部开始（不留顶栏位置）
	# 必须在 _show_sub_page 之后设置，因为 _show_sub_page 里的 _close_sub_page 会恢复 offset_top
	if _sub_page_container != null:
		_sub_page_container.offset_top = 0.0
		# 关键：offset_top 改变后，必须重新设置当前页面的锚点，否则页面位置不会更新
		if _current_sub != null and is_instance_valid(_current_sub):
			_current_sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 关键修复：_sub_top_bg 是 game_ui 的直接子节点，覆盖在 _sub_page_container 上方，
	# 会挡住顶部 0~TOPBAR_H 区域。宗主详情页需要全屏立绘，必须隐藏它。
	if _sub_top_bg != null:
		_sub_top_bg.visible = false
		print("[GameUI] 已隐藏 _sub_top_bg（宗主详情页全屏立绘需要）")
	# 连接宗主皮肤请求信号（换装按钮）
	if _current_sub != null and is_instance_valid(_current_sub) and _current_sub.has_signal("宗主皮肤请求"):
		_current_sub.宗主皮肤请求.connect(_open_master_skin_shop)
	print("[GameUI] 宗主详情页已打开，_current_sub = ", _current_sub)

# 弟子详情页（立绘主导型）：从弟子列表页点击卡片打开，全屏立绘+属性详情
func _open_disciple_detail(弟子对象: Disciple) -> void:
	print("[GameUI] _open_disciple_detail 被调用")
	_show_sub_page("弟子详情", PageDiscipleDetailScene)
	_master_sub_open = true  # 复用宗主详情的顶栏隐藏标记（关闭时恢复顶栏）
	if _top_bar != null and is_instance_valid(_top_bar):
		_top_bar.visible = false
	if _sub_page_container != null:
		_sub_page_container.offset_top = 0.0
		if _current_sub != null and is_instance_valid(_current_sub):
			_current_sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _sub_top_bg != null:
		_sub_top_bg.visible = false
	# 设置弟子数据
	if _current_sub != null and is_instance_valid(_current_sub) and _current_sub.has_method("set_disciple"):
		_current_sub.set_disciple(弟子对象)
	# 连接返回信号
	if _current_sub != null and is_instance_valid(_current_sub) and _current_sub.has_signal("返回列表"):
		_current_sub.返回列表.connect(_close_sub_page)
	# 连接仙衣阁请求信号（换装按钮）
	if _current_sub != null and is_instance_valid(_current_sub) and _current_sub.has_signal("仙衣阁请求"):
		_current_sub.仙衣阁请求.connect(_open_skin_shop)
	print("[GameUI] 弟子详情页已打开")

# 打开仙衣阁皮肤商店页（从弟子详情页换装按钮或宗门首页入口打开）
func _open_skin_shop() -> void:
	print("[GameUI] _open_skin_shop 被调用")
	_show_sub_page("仙衣阁", PageSkinShopScene)
	print("[GameUI] 仙衣阁皮肤商店页已打开")

# 打开宗主皮肤商店页（从宗主详情页换装按钮打开）
func _open_master_skin_shop() -> void:
	print("[GameUI] _open_master_skin_shop 被调用")
	_show_sub_page("宗主仙衣阁", PageMasterSkinShopScene)
	print("[GameUI] 宗主皮肤商店页已打开")

# 打开阵营任务和商店页面
func _open_faction_quest_shop() -> void:
	print("[GameUI] _open_faction_quest_shop 被调用")
	# 使用load动态加载脚本，不需要preload
	var 脚本 = load("res://ui/faction_quest_shop_page.gd")
	if 脚本 == null:
		push_error("faction_quest_shop_page.gd 加载失败")
		return
	_show_sub_page("阵营任务商店", 脚本)
	# 连接返回信号
	if _current_sub != null and is_instance_valid(_current_sub) and _current_sub.has_signal("返回主页"):
		_current_sub.返回主页.connect(_close_sub_page)
	print("[GameUI] 阵营任务和商店页面已打开")

# 轻量提示：暂无系统入口的反馈（当前用 print，后续可替换为顶层 Toast 控件）。
func _toast(text: String) -> void:
	print("[GameUI] %s" % text)

# ───────── 宗主详情页：P0 实装（7 权责路由 + 改名弹窗）─────────
# 7 权责按钮 → 路由到已有的对应系统页（让按钮真正有反应）；无后端的域诚实 toast。
# 映射：宗门规制→宗规二级页 / 职司任免→弟子Tab / 功勋赏罚→功勋二级页 /
#       宗门纪事→纪事Tab / 物资调配→库藏二级页 / 阵堂布置→殿阁Tab / 闭关设置→即将开放。
func _on_权责请求(分类: String) -> void:
	match 分类:
		"宗门规制":
			_show_sub_page("宗规", PageRulesScene)
		"职司任免":
			_show_page("弟子")
		"功勋赏罚":
			_show_sub_page("功勋", PageBattlepassScene)
		"闭关设置":
			_toast("【闭关设置】系统即将开放")
		"宗门纪事":
			_show_page("纪事")
		"物资调配":
			_show_sub_page("库藏", PageStorageScene)
		"阵堂布置":
			_show_page("殿阁")
		"阵营任务":
			_open_faction_quest_shop()
		_:
			_toast("【%s】系统即将开放" % 分类)

# 编辑按钮 → 唤起改名弹窗（复用常驻 CanvasLayer 实例）
func _on_编辑请求() -> void:
	if _edit_popup_instance != null and is_instance_valid(_edit_popup_instance) and _edit_popup_instance.has_method("唤起"):
		_edit_popup_instance.唤起()

# 改名确认 → 刷新当前打开的二级页（宗主详情）+ 顶栏资源，让新名即时可见
func _on_宗主名已改(新名: String) -> void:
	if _current_sub != null and is_instance_valid(_current_sub) and _current_sub.has_method("refresh"):
		_current_sub.refresh()
	if _top_bar != null and is_instance_valid(_top_bar):
		if _top_bar.has_method("refresh_resources"):
			_top_bar.refresh_resources()
		if _top_bar.has_method("refresh_avatar"):
			_top_bar.refresh_avatar()

# 预热宗主改名弹窗：load 脚本 → Control.new() → set_script → 挂 CanvasLayer(layer=101) 容器，
# 与 top_bar 的头像弹窗（layer=100）同范式，确保盖住所有默认 UI。
func _预热_编辑弹窗() -> void:
	var 脚本 = load("res://ui/master_edit_popup.gd")
	if 脚本 == null:
		push_error("master_edit_popup.gd 加载失败")
		return
	var popup层 := CanvasLayer.new()
	popup层.name = "MasterEditPopupLayer"
	popup层.layer = 101  # 高于头像弹窗(100)，确保改名弹窗在最上层
	var 容器 := Control.new()
	容器.name = "Container"
	容器.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	容器.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup层.add_child(容器)
	add_child(popup层)
	_edit_popup_instance = Control.new()
	_edit_popup_instance.set_script(脚本)
	_edit_popup_instance.visible = false
	容器.add_child(_edit_popup_instance)
	if _edit_popup_instance.has_signal("宗主名已改"):
		_edit_popup_instance.宗主名已改.connect(_on_宗主名已改)


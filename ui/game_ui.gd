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
const PageAchievementScene: PackedScene = preload("res://ui/page_achievement.tscn")
const PageAncestorScene: PackedScene = preload("res://ui/page_ancestor.tscn")
const PageAvatarScene: PackedScene = preload("res://ui/page_avatar.tscn")
const PageHuntScene: PackedScene = preload("res://ui/page_hunt.tscn")
const PageLeisureScene: PackedScene = preload("res://ui/page_leisure.tscn")
const PageChessScene: PackedScene = preload("res://ui/page_chess.tscn")
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
const PageSectQiScene: PackedScene = preload("res://ui/page_sect_qi.tscn")
const PageDynastyScene: PackedScene = preload("res://ui/page_dynasty.tscn")
const PageAuctionScene: PackedScene = preload("res://ui/page_auction.tscn")
const PageTeleportScene: PackedScene = preload("res://ui/page_teleport.tscn")
const PageFamilyScene: PackedScene = preload("res://ui/page_family.tscn")
const PageTreasureScene: PackedScene = preload("res://ui/page_treasure.tscn")
const PageTechScene: PackedScene = preload("res://ui/page_tech.tscn")
const PageBeastScene: PackedScene = preload("res://ui/page_beast.tscn")
const PageMasterScene: PackedScene = preload("res://ui/page_master.tscn")
# B4 无落点入口补齐（2026-09-12）：后端已备、UI 未接的 7 个系统，各补唯一二级页
const PagePoisonScene: PackedScene = preload("res://ui/page_poison.tscn")
const PageGuardianScene: PackedScene = preload("res://ui/page_guardian.tscn")
const PageOpportunityScene: PackedScene = preload("res://ui/page_opportunity.tscn")
const PageBrewScene: PackedScene = preload("res://ui/page_brew.tscn")
const PageMusicScene: PackedScene = preload("res://ui/page_music.tscn")
const PageFengshuiScene: PackedScene = preload("res://ui/page_fengshui.tscn")
const PageAscensionScene: PackedScene = preload("res://ui/page_ascension.tscn")
# C（B5 孤儿页归零，2026-09-12）：有后端有界面、但入口信号断线的 7 个系统各补唯一落点
const PageFishingScene: PackedScene = preload("res://ui/page_fishing.tscn")
const PageRelicScene: PackedScene = preload("res://ui/page_relic.tscn")
const PageBeastRaiseScene: PackedScene = preload("res://ui/page_beast_raise.tscn")
const PageDivineScene: PackedScene = preload("res://ui/page_divine.tscn")
const PageHerbScene: PackedScene = preload("res://ui/page_herb.tscn")
const PageMerchantScene: PackedScene = preload("res://ui/page_merchant.tscn")
const PageGlobalAuctionScene: PackedScene = preload("res://ui/page_global_auction.tscn")
# B8（2026-09-12）：宗门舆图 = 全法门功能索引页（UX 总纲 §4.8 F1/F2）
const PageAtlasScene: PackedScene = preload("res://ui/page_atlas.tscn")
const BattleSceneScript = preload("res://ui/battle_scene.gd")   # 战斗场景（代码构建，无需tscn）

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
	"宗门典藏": PageCodexScene,
	"功绩堂": PageAchievementScene,
	"祖师堂": PageAncestorScene,
	"身外化身": PageAvatarScene,
	"入山采撷": PageHuntScene,
	"闲情雅趣": PageLeisureScene,
	"论道棋弈": PageChessScene,
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
	"宗门气运": PageSectQiScene,
	"凡人王朝": PageDynastyScene,
	"拍卖行": PageAuctionScene,
	"传送阵": PageTeleportScene,
	"家族": PageFamilyScene,
	"法宝": PageTreasureScene,
	"科技": PageTechScene,
	"灵兽": PageBeastScene,
	"宗主": PageMasterScene,
	"毒道": PagePoisonScene,
	"护道人": PageGuardianScene,
	"机缘": PageOpportunityScene,
	"灵酿": PageBrewScene,
	"音律": PageMusicScene,
	"风水堪舆": PageFengshuiScene,
	"飞升": PageAscensionScene,
	# C（B5）：休闲总入口（闲情雅趣）直跳的 6 个玩法 + 商道 + 全服拍卖（拍卖行子页）
	"灵钓": PageFishingScene,
	"探遗迹": PageRelicScene,
	"饲灵育兽": PageBeastRaiseScene,
	"卜算星盘": PageDivineScene,
	"药圃经营": PageHerbScene,
	"商道": PageMerchantScene,
	"全服拍卖": PageGlobalAuctionScene,
	# B8：更多面板底部固定入口「宗门舆图」→ 功能索引页（未解锁系统也列出 + 写明条件）
	"宗门舆图": PageAtlasScene,
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
var _battle_scene: Control = null           # 战斗场景实例（全屏覆盖层）
# 实时传讯通知
var _传讯通知条: Control = null
var _传讯弹窗: Control = null
var _当前传讯: Dictionary = {}

# B7：宗门气象抽屉（首页气象带入口 → 待批传讯批复 + 内嵌心弦）
var _气象抽屉: Control = null

# B8：从舆图跳出的目标系统，返回时回到舆图（索引页作为落脚点，少走回头路）
var _舆图回跳: bool = false

func _ready() -> void:
	_build()
	_wire()
	_select_initial()
	_apply_safe_defaults()
	# 通用轻提示总线：Game.添加提示(文本) → 本页 toast（宗门战等二级页依赖此通道）
	if Game.has_signal("提示") and not Game.提示.is_connected(_toast):
		Game.提示.connect(_toast)
	# 实时传讯信号
	if Game.has_signal("新传讯到达") and not Game.新传讯到达.is_connected(_on新传讯):
		Game.新传讯到达.connect(_on新传讯)

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
	# P0-1 洋葱解锁：底部 Tab 纳入 gating（置灰保留、不留洞）
	_应用底部Tab解锁()

	# 预建页面：宗门 为真实页；其余四页实例化真实只读页场景（接 建设中 占位）。
	for id in PAGE_IDS:
		match id:
			"宗门":
				var 宗门页: Control = _make_real_page(SectHomePageScene, id)
				_页_宗门 = 宗门页
				# 01 屏 1:1：8 入口上行 + 隐藏UI开关信号
				宗门页.entry_selected.connect(_on_首页入口)
				宗门页.hide_ui_requested.connect(_on_hide_ui_requested)
				if 宗门页.has_signal("气象带请求"):
					宗门页.气象带请求.connect(_on_气象带请求)
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
	# 构建传讯通知条
	_构建传讯通知条()

# 实例化真实页场景（仅占位 Control，子节点由各自脚本 _ready 内建）。
func _make_real_page(scene: PackedScene, id: String) -> Control:
	var page := scene.instantiate() as Control
	page.name = "Page_" + id
	return page

# ───────── 实时传讯通知条 ─────────
func _构建传讯通知条() -> void:
	# 顶部通知条（默认隐藏）
	_传讯通知条 = Control.new()
	_传讯通知条.name = "传讯通知条"
	_传讯通知条.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_传讯通知条.offset_top = UITheme.TOPBAR_H + 4
	_传讯通知条.offset_bottom = UITheme.TOPBAR_H + 56
	_传讯通知条.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_传讯通知条.visible = false
	add_child(_传讯通知条)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 20
	panel.offset_right = -20
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.15, 0.12, 0.08, 0.95)
	psb.border_color = Color(0.85, 0.65, 0.30, 0.9)
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", psb)
	_传讯通知条.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.add_theme_constant_override("margin_left", 12)
	hb.add_theme_constant_override("margin_right", 12)
	hb.add_theme_constant_override("margin_top", 6)
	hb.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(hb)
	var icon := Label.new()
	icon.text = "✉"
	icon.add_theme_color_override("font_color", Color(0.95, 0.80, 0.40))
	icon.add_theme_font_size_override("font_size", UITheme.FONT_H1)
	hb.add_child(icon)
	var msg := Label.new()
	msg.name = "Msg"
	msg.text = "传讯符燃，千里传音..."
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	msg.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(msg)
	# 点击区域
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on点击传讯通知)
	_传讯通知条.add_child(btn)

func _on新传讯(传讯数据: Dictionary) -> void:
	if _传讯通知条 == null:
		_构建传讯通知条()
	_当前传讯 = 传讯数据
	var msg: Label = _传讯通知条.get_node("PanelContainer/HBoxContainer/Msg") as Label
	if msg != null:
		msg.text = "【%s】%s" % [str(传讯数据.get("发件人", "")), str(传讯数据.get("类型", ""))]
	_传讯通知条.visible = true
	# 5秒后自动隐藏（但传讯仍在待处理列表中）
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(func():
		if _传讯通知条 != null:
			_传讯通知条.visible = false
	)

func _on点击传讯通知() -> void:
	if _传讯通知条 != null:
		_传讯通知条.visible = false
	_显示传讯弹窗(_当前传讯)

func _显示传讯弹窗(传讯: Dictionary) -> void:
	if 传讯.is_empty():
		return
	# 使用UIHint风格的弹窗，但增加选项按钮
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.12, 0.15, 0.14, 0.98)
	psb.border_color = Color(0.78, 0.65, 0.34, 0.9)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(10)
	psb.content_margin_left = 24; psb.content_margin_right = 24
	psb.content_margin_top = 18; psb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", psb)
	shade.add_child(panel)
	panel.position = Vector2((get_viewport().size.x - 700) / 2, get_viewport().size.y * 0.3)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "【传讯】%s" % str(传讯.get("发件人", ""))
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	title.add_theme_font_size_override("font_size", UITheme.FONT_H1)
	vb.add_child(title)
	var content := Label.new()
	content.text = str(传讯.get("内容", ""))
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_color_override("font_color", Color(0.88, 0.90, 0.88))
	content.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	vb.add_child(content)
	# 选项按钮
	var 选项: Array = 传讯.get("选项", [])
	for i in range(选项.size()):
		var opt: Dictionary = 选项[i]
		var btn := Button.new()
		btn.text = str(opt.get("文本", ""))
		btn.custom_minimum_size = Vector2(0, 48)
		btn.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
		btn.pressed.connect(func(idx=i): _回复传讯(int(传讯.get("传讯ID", 0)), idx, shade))
		vb.add_child(btn)

func _回复传讯(传讯ID: int, 选项索引: int, shade: ColorRect) -> void:
	var 结果: Dictionary = Game.回复传讯(传讯ID, 选项索引)
	shade.queue_free()
	if 结果.get("成功", false):
		UIHint.show_hint(self, "传讯已回复", str(结果.get("结果", {}).get("消息", "已回复")))
	else:
		UIHint.show_hint(self, "回复失败", str(结果.get("原因", "未知错误")))

# ───────── B7：宗门气象抽屉（UX §4.13 · 首页气象带入口）─────────
## 抽屉 =「待批传讯（可批复）」+「心弦（内嵌 page_chat）」；不做独立大页。
## 写操作（回复传讯）留在交互层，首页气象带本身只读 → 分层干净。
func _on_气象带请求() -> void:
	_打开气象抽屉()

func _关闭气象抽屉() -> void:
	if _气象抽屉 != null and is_instance_valid(_气象抽屉):
		_气象抽屉.queue_free()
	_气象抽屉 = null

func _打开气象抽屉() -> void:
	# 已开 → 再次点击带子即收起
	if _气象抽屉 != null and is_instance_valid(_气象抽屉):
		_关闭气象抽屉()
		return
	var vp: Vector2 = get_viewport().size
	# 半透明遮罩（点击空白关闭）
	var shade := ColorRect.new()
	shade.name = "WeatherShade"
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_关闭气象抽屉())
	add_child(shade)
	_气象抽屉 = shade

	# 抽屉面板（自底部升起）
	var panel_w: float = vp.x - 108.0
	var panel_h: float = minf(vp.y * 0.74, 1420.0)
	var panel := Panel.new()
	panel.name = "WeatherDrawer"
	panel.position = Vector2(54.0, vp.y - panel_h - 54.0)
	panel.size = Vector2(panel_w, panel_h)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = UITheme.COLOR_PANEL_BG
	psb.set_corner_radius_all(24)
	psb.set_border_width_all(2)
	psb.border_color = UITheme.COLOR_BORDER_GOLD
	panel.add_theme_stylebox_override("panel", psb)
	shade.add_child(panel)

	# 标题行
	var title := Label.new()
	title.text = "宗门气象"
	title.position = Vector2(36.0, 24.0)
	title.add_theme_font_size_override("font_size", UITheme.FONT_DISPLAY)
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)
	panel.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(72, 72)
	close_btn.position = Vector2(panel_w - 108.0, 20.0)
	UITheme.apply_secondary_button_style(close_btn)
	close_btn.pressed.connect(_关闭气象抽屉)
	panel.add_child(close_btn)

	# 内容滚动区
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(36.0, 110.0)
	scroll.size = Vector2(panel_w - 72.0, panel_h - 140.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 14)
	scroll.add_child(vb)

	# 段 1：待批传讯（需决策层）
	_建抽屉段标题(vb, "待批传讯")
	var 待批 = Game.get("待处理传讯") if is_instance_valid(Game) else null
	if 待批 == null or not (待批 is Array) or (待批 as Array).is_empty():
		_建抽屉空态(vb, "（暂无门人来讯）")
	else:
		for 传讯 in (待批 as Array):
			_建传讯卡片(vb, 传讯)

	# 段 2：心弦（纯氛围层；内嵌 page_chat，嵌入模式 → 不自建全屏底/标题栏）
	_建抽屉段标题(vb, "心弦")
	var chat := Control.new()
	chat.name = "DrawerChat"
	chat.set_script(load("res://ui/page_chat.gd"))
	chat.set("嵌入模式", true)
	chat.custom_minimum_size = Vector2(0, 620.0)
	vb.add_child(chat)

## 抽屉分段小标题
func _建抽屉段标题(parent: Control, 文本: String) -> void:
	var lbl := Label.new()
	lbl.text = 文本
	lbl.add_theme_font_size_override("font_size", UITheme.FONT_DISPLAY)
	lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	parent.add_child(lbl)

## 抽屉空态
func _建抽屉空态(parent: Control, 文本: String) -> void:
	var lbl := Label.new()
	lbl.text = 文本
	lbl.add_theme_font_size_override("font_size", UITheme.FONT_H1)
	lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_DIM)
	parent.add_child(lbl)

## 待批传讯卡片：发件人 + 内容 + 选项批复按钮
func _建传讯卡片(parent: Control, 传讯: Variant) -> void:
	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = UITheme.COLOR_BG_CONTENT
	psb.set_corner_radius_all(12)
	psb.set_border_width_all(1)
	psb.border_color = UITheme.COLOR_HOME_DIVIDER
	psb.content_margin_left = 20.0; psb.content_margin_right = 20.0
	psb.content_margin_top = 14.0; psb.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", psb)
	parent.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var 头 := Label.new()
	头.text = "【%s】%s" % [str(传讯.get("发件人", "")), str(传讯.get("类型", ""))]
	头.add_theme_font_size_override("font_size", UITheme.FONT_DISPLAY)
	头.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE1)
	vb.add_child(头)

	var 内容 := Label.new()
	内容.text = str(传讯.get("内容", ""))
	内容.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	内容.add_theme_font_size_override("font_size", UITheme.FONT_H1)
	内容.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	vb.add_child(内容)

	var 选项: Array = 传讯.get("选项", [])
	for i in range(选项.size()):
		var opt: Dictionary = 选项[i]
		var btn := Button.new()
		btn.text = str(opt.get("文本", ""))
		btn.custom_minimum_size = Vector2(0, 64)
		btn.add_theme_font_size_override("font_size", UITheme.FONT_H1)
		UITheme.apply_secondary_button_style(btn)
		# 用 bind 传参：立即求值，避免闭包捕获循环变量
		btn.pressed.connect(_抽屉批复传讯.bind(int(传讯.get("传讯ID", 0)), i))
		vb.add_child(btn)

## 抽屉内批复传讯：调用 Game 公开 API，处理后重建抽屉刷新列表
func _抽屉批复传讯(传讯ID: int, 选项索引: int) -> void:
	var 结果: Dictionary = Game.回复传讯(传讯ID, 选项索引)
	if bool(结果.get("成功", false)):
		UIHint.show_hint(self, "传讯已回复", str(结果.get("结果", {}).get("消息", "已回复")))
	else:
		UIHint.show_hint(self, "回复失败", str(结果.get("原因", "未知错误")))
	_关闭气象抽屉()
	_打开气象抽屉()

# ───────── 信号接线 ─────────
func _wire() -> void:
	_bottom_bar.tab_selected.connect(_on_tab_selected)
	if _bottom_bar.has_signal("tab_blocked"):
		_bottom_bar.tab_blocked.connect(_on_tab_blocked)
	# 顶栏「宗门名 + Lv」→ 打开宗主详情页（全屏二级页，独立于左右入口二级页流程）
	if _top_bar != null and is_instance_valid(_top_bar) and _top_bar.has_signal("宗主详情请求"):
		_top_bar.宗主详情请求.connect(_open_master_detail)
	# S56：顶栏消息入口 → 打开消息中心
	if _top_bar != null and is_instance_valid(_top_bar) and _top_bar.has_signal("消息中心请求"):
		_top_bar.消息中心请求.connect(_open_message_center)
	# 宗主改名弹窗预热（CanvasLayer 复用实例，常驻隐藏，唤起即显）
	_预热_编辑弹窗()

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
	# P0-1 防御：未开启的 Tab 不切页（正常路径已被置灰按钮拦下）
	if not SystemUnlock.入口可显示(tab_id):
		_on_tab_blocked(tab_id)
		return
	_show_page(tab_id)

## 底部 Tab 解锁态回灌（gating 单一来源 = SystemUnlock / config/unlock_order.csv）。
## Tab 名与 CSV「首页入口id」同字（宗门/弟子/殿阁/历练/纪事），故可直接查询，无需映射表。
func _应用底部Tab解锁() -> void:
	if _bottom_bar == null or not is_instance_valid(_bottom_bar):
		return
	if not _bottom_bar.has_method("设置Tab可用"):
		return
	for tab_id in PAGE_IDS:
		_bottom_bar.设置Tab可用(String(tab_id), SystemUnlock.入口可显示(String(tab_id)))

## 点了未开启的置灰 Tab：只给可读条件提示，不切页（置灰不留洞 + X15 必有反馈）
func _on_tab_blocked(tab_id: String) -> void:
	var 条件: String = SystemUnlock.入口解锁提示(tab_id)
	if 条件 == "":
		条件 = "随宗门壮大自会显现"
	_toast("【%s】尚未开启，%s" % [tab_id, 条件])

# 首页网格入口（sect_home_page.entry_selected）：纯 UI 路由 → 一级页切页 或 二级页打开，不碰玩法/战斗红线
func _on_首页入口(entry_id: String) -> void:
	# 0) P0-1 洋葱式解锁：未开启的入口仅提示、不进入（fail-open 策略收敛在 SystemUnlock.入口可显示）
	if not SystemUnlock.入口可显示(entry_id):
		_toast("【%s】尚未开启，随宗门壮大自会显现" % entry_id)
		return

	# 1) 天下（原「山门」· B6 更名）：S58 打开世界大地图（X12 一义一名：入口名 = 玩法语义）
	if entry_id == "天下":
		_open_world_map_page()
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
		# 拍卖行页「全服钮」→ 全服拍卖大典（page_auction:37 早已 emit，此前无人 connect → 孤儿页成因）
		if page.has_signal("打开全服拍卖"):
			page.打开全服拍卖.connect(_open_全服拍卖)
		# 闲情雅趣目录页 → 按 id 打开对应休闲玩法二级页（总纲 §11 R3）
		if page.has_signal("雅趣请求"):
			page.雅趣请求.connect(_open_雅趣)
		# B8 宗门舆图 → 按 id 打开目标系统（返回时回到舆图；见 _on_二级页返回）
		if page.has_signal("打开请求"):
			page.打开请求.connect(_on_舆图请求)
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

# 打开全服拍卖大典（page_auction「全服钮」触发；S54 信号此前无人连接）。
func _open_全服拍卖() -> void:
	_舆图回跳 = false
	_show_sub_page("全服拍卖", PageGlobalAuctionScene)

# 闲情雅趣目录 → 按 id 打开对应休闲玩法二级页（R3：休闲总览收口，步数只减不增）。
# id 与 ENTRY_SUB_PAGES 键硬绑定；未登记则 toast 提示，不留点击无响应。
func _open_雅趣(id: String) -> void:
	var scene: PackedScene = ENTRY_SUB_PAGES.get(id, null) as PackedScene
	if scene == null:
		_toast("【%s】系统即将开放" % id)
		return
	_舆图回跳 = false
	_show_sub_page(id, scene)

# B8 宗门舆图 → 目标系统（纯 UI 路由 + gating 复用单一来源，零玩法/存档触碰）。
# 目标为一级 Tab → 切 Tab（返回即 Tab，不记回跳）；否则开二级页并记回跳（返回回舆图）。
func _on_舆图请求(id: String) -> void:
	if not SystemUnlock.入口可显示(id):
		var 缘由: String = SystemUnlock.入口解锁提示(id)
		if 缘由 == "":
			缘由 = "随宗门壮大自会显现"
		UIHint.show_hint(self, "尚未开启 · " + id, 缘由)
		return
	var 目标: String = String(ENTRY_ALIAS.get(id, id))
	_舆图回跳 = not (目标 in PAGE_IDS)
	_on_首页入口(id)

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
	# B8：从舆图跳出的目标系统，返回时先回到舆图（索引页落脚，少走回头路）
	if _舆图回跳:
		_舆图回跳 = false
		_show_sub_page("宗门舆图", PageAtlasScene)
		return
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

# S56：打开消息中心（纯代码页面）
func _open_message_center() -> void:
	print("[GameUI] _open_message_center 被调用")
	_close_sub_page()
	# 隐藏底部Tab和顶栏
	if _bottom_bar != null and is_instance_valid(_bottom_bar):
		_bottom_bar.visible = false
	if _top_bar != null and is_instance_valid(_top_bar):
		_top_bar.visible = false
	if _页_宗门 != null and is_instance_valid(_页_宗门) and _页_宗门.has_method("set_chrome_visible"):
		_页_宗门.set_chrome_visible(false)
	_page_container.offset_bottom = 0.0
	_sub_page_container.offset_bottom = 0.0
	_sub_page_container.offset_top = 0.0
	# 用代码创建消息中心页面
	var 脚本 = load("res://ui/page_message.gd")
	if 脚本 == null:
		push_error("page_message.gd 加载失败")
		return
	var page: Control = Control.new()
	page.set_script(脚本)
	page.name = "SubPage_消息中心"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub_page_container.add_child(page)
	_current_sub = page
	_master_sub_open = true
	print("[GameUI] 消息中心已打开")

# S56-P1：打开宗门频道聊天（纯代码页面）
func _open_chat_page() -> void:
	print("[GameUI] _open_chat_page 被调用")
	_close_sub_page()
	# 隐藏底部Tab和顶栏
	if _bottom_bar != null and is_instance_valid(_bottom_bar):
		_bottom_bar.visible = false
	if _top_bar != null and is_instance_valid(_top_bar):
		_top_bar.visible = false
	if _页_宗门 != null and is_instance_valid(_页_宗门) and _页_宗门.has_method("set_chrome_visible"):
		_页_宗门.set_chrome_visible(false)
	_page_container.offset_bottom = 0.0
	_sub_page_container.offset_bottom = 0.0
	_sub_page_container.offset_top = 0.0
	# 用代码创建聊天页面
	var 脚本 = load("res://ui/page_chat.gd")
	if 脚本 == null:
		push_error("page_chat.gd 加载失败")
		return
	var page: Control = Control.new()
	page.set_script(脚本)
	page.name = "SubPage_宗门频道"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub_page_container.add_child(page)
	_current_sub = page
	_master_sub_open = true
	print("[GameUI] 宗门频道已打开")

# S57：打开玩家交易页面（纯代码页面）
func _open_player_trade_page() -> void:
	print("[GameUI] _open_player_trade_page 被调用")
	_close_sub_page()
	# 隐藏底部Tab和顶栏
	if _bottom_bar != null and is_instance_valid(_bottom_bar):
		_bottom_bar.visible = false
	if _top_bar != null and is_instance_valid(_top_bar):
		_top_bar.visible = false
	if _页_宗门 != null and is_instance_valid(_页_宗门) and _页_宗门.has_method("set_chrome_visible"):
		_页_宗门.set_chrome_visible(false)
	_page_container.offset_bottom = 0.0
	_sub_page_container.offset_bottom = 0.0
	_sub_page_container.offset_top = 0.0
	# 用代码创建交易页面
	var 脚本 = load("res://ui/page_player_trade.gd")
	if 脚本 == null:
		push_error("page_player_trade.gd 加载失败")
		return
	var page: Control = Control.new()
	page.set_script(脚本)
	page.name = "SubPage_商队交易"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub_page_container.add_child(page)
	_current_sub = page
	_master_sub_open = true
	print("[GameUI] 商队交易已打开")

# S58：打开世界大地图（山门入口）- 可视化版本
func _open_world_map_page() -> void:
	print("[GameUI] _open_world_map_page 被调用")
	_close_sub_page()
	# 隐藏底部Tab和顶栏
	if _bottom_bar != null and is_instance_valid(_bottom_bar):
		_bottom_bar.visible = false
	if _top_bar != null and is_instance_valid(_top_bar):
		_top_bar.visible = false
	if _页_宗门 != null and is_instance_valid(_页_宗门) and _页_宗门.has_method("set_chrome_visible"):
		_页_宗门.set_chrome_visible(false)
	_page_container.offset_bottom = 0.0
	_sub_page_container.offset_bottom = 0.0
	_sub_page_container.offset_top = 0.0
	# 用代码创建可视化大地图页面
	var 脚本 = load("res://ui/page_world_map_visual.gd")
	if 脚本 == null:
		push_error("page_world_map_visual.gd 加载失败")
		return
	var page: Control = Control.new()
	page.set_script(脚本)
	page.name = "SubPage_世界大地图"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub_page_container.add_child(page)
	_current_sub = page
	_master_sub_open = true
	print("[GameUI] 世界大地图（可视化）已打开")

# S59：打开闭关嘱托页面
func _open_offline_manager_page() -> void:
	print("[GameUI] _open_offline_manager_page 被调用")
	_close_sub_page()
	# 隐藏底部Tab和顶栏
	if _bottom_bar != null and is_instance_valid(_bottom_bar):
		_bottom_bar.visible = false
	if _top_bar != null and is_instance_valid(_top_bar):
		_top_bar.visible = false
	if _页_宗门 != null and is_instance_valid(_页_宗门) and _页_宗门.has_method("set_chrome_visible"):
		_页_宗门.set_chrome_visible(false)
	_page_container.offset_bottom = 0.0
	_sub_page_container.offset_bottom = 0.0
	_sub_page_container.offset_top = 0.0
	# 用代码创建闭关嘱托页面
	var 脚本 = load("res://ui/page_offline_manager.gd")
	if 脚本 == null:
		push_error("page_offline_manager.gd 加载失败")
		return
	var page: Control = Control.new()
	page.set_script(脚本)
	page.name = "SubPage_闭关嘱托"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub_page_container.add_child(page)
	_current_sub = page
	_master_sub_open = true
	print("[GameUI] 闭关嘱托已打开")

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
		if not _current_sub.返回列表.is_connected(_close_sub_page):
			_current_sub.返回列表.connect(_close_sub_page)
	# 连接仙衣阁请求信号（换装按钮）
	if _current_sub != null and is_instance_valid(_current_sub) and _current_sub.has_signal("仙衣阁请求"):
		if not _current_sub.仙衣阁请求.is_connected(_open_skin_shop):
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

# ============ 战斗场景接入（P0） ============
# 公开方法：显示战斗场景，传入攻方/守方快照列表
# 调用示例：Game.UI.显示战斗(攻方列表, 守方列表, "宗门战")
func 显示战斗(攻方列表: Array, 守方列表: Array, 战斗标题: String = "战斗") -> void:
	if _battle_scene == null or not is_instance_valid(_battle_scene):
		_battle_scene = BattleSceneScript.new()
		_battle_scene.name = "BattleScene"
		_battle_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_battle_scene.战斗结束.connect(_on_battle_finished)
		add_child(_battle_scene)
	_battle_scene.visible = true
	_battle_scene.开始战斗(攻方列表, 守方列表, 战斗标题)

# 战斗结束回调：隐藏战斗场景，保留实例复用
func _on_battle_finished(战报: Dictionary) -> void:
	if _battle_scene and is_instance_valid(_battle_scene):
		_battle_scene.visible = false

# P2接入：播放已计算好的战报（用于接入现有战斗入口，不重新计算）
func 播放战报(战报: Dictionary, 攻方列表: Array, 守方列表: Array, 战斗标题: String = "战斗") -> void:
	if _battle_scene == null or not is_instance_valid(_battle_scene):
		_battle_scene = BattleSceneScript.new()
		_battle_scene.name = "BattleScene"
		_battle_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_battle_scene.战斗结束.connect(_on_battle_finished)
		add_child(_battle_scene)
	_battle_scene.visible = true
	_battle_scene.播放战报(战报, 攻方列表, 守方列表, 战斗标题)

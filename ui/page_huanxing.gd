extends Control

# 幻形 · 洞天换肤二级页（纯展示 + 背景切换，零玩法/战斗触碰）。
# 打开方式：01 屏右列「幻形」入口 → game_ui.ENTRY_SUB_PAGES["幻形"]。
# 交互：卡片选中（仅已拥有可选）→ 底部「穿戴」→ 写 Game.当前皮肤 + 存档 + 广播 皮肤已装备
#        → game_ui 实时刷新 01 屏背景。筛选：全部 / 已拥有 / 未拥有。
# 铁律：所有色值走 UITheme / UIThemeConfig 令牌，零裸色；坐标经 _place 乘 UI_SCALE，禁凭手感。

signal 返回主页
signal 皮肤已装备(skin_id: String)

# 皮肤讯息（内置 const，自包含；bg 缺图时回落 home_bg_sect_a.png）。
# tier：品阶 stem（ling/bao/wang/sheng/xian）→ UIThemeConfig.get_quality_color 取 canonical 品阶色。
# unlock.type：always 默认拥有 / sect_level 按门派等级 / days 按累计游戏日。
const SKINS: Array = [
	{"id": "taixu_yunhai", "name": "太虚云海",     "tier": "ling",  "tier_name": "灵", "bg": "res://art/backgrounds/home_bg_sect_a.png",        "unlock": {"type": "always"}},
	{"id": "chun_qinglan", "name": "春·青岚叠翠",  "tier": "ling",  "tier_name": "灵", "bg": "res://art/backgrounds/home_bg_season_spring.png",  "unlock": {"type": "sect_level", "value": 2}},
	{"id": "xia_bihe",     "name": "夏·碧荷听雨",  "tier": "bao",   "tier_name": "宝", "bg": "res://art/backgrounds/home_bg_season_summer.png",  "unlock": {"type": "sect_level", "value": 4}},
	{"id": "qiu_jinfeng",  "name": "秋·金枫染岳",  "tier": "wang",  "tier_name": "王", "bg": "res://art/backgrounds/home_bg_season_autumn.png",  "unlock": {"type": "sect_level", "value": 6}},
	{"id": "dong_xueji",   "name": "冬·雪霁寒山",  "tier": "sheng", "tier_name": "圣", "bg": "res://art/backgrounds/home_bg_season_winter.png",  "unlock": {"type": "sect_level", "value": 8}},
	{	"id": "xian_jiuqiao", "name": "仙·九霄琼阙",  "tier": "xian",  "tier_name": "仙", "bg": "res://art/backgrounds/home_bg_season_immortal.png","unlock": {"type": "days", "value": 120}},
]

# 布局常量（480×854 设计稿基准，经 UI_SCALE 映射到 1080×1920）
const CARD_W: float = 216.0
const CARD_H: float = 208.0
const CARD_X0: float = 16.0
const CARD_X1: float = 248.0
const GRID_TOP: float = 120.0          # 滚动区起始
# 底栏起始。2026-09-15 修：原 688（按「容器可视高 854-84=770，减去底栏 82」推出）
#   让底栏落在 688~770 = **屏幕最底边**，实测「穿戴」按钮在逻辑 y788~838、距屏底仅 16 逻辑
#   （≈36 物理），被 Windows 任务栏（约 32 逻辑 / 65 物理）整条吃掉 —— 玩家看不到按钮，
#   表现为老大报的「皮肤能点击但不能更换，以前有个穿戴按钮」。现上移到安全区。
const GRID_BOTTOM: float = 644.0       # 底栏 644~726；底部留 43 逻辑（≈65 窗口px）安全余量
const GRID_DY: float = 224.0           # CARD_H 208 + 间隙 16
const BOTTOM_H: float = 82.0

var _equipped_id: String = "taixu_yunhai"
var _selected_id: String = "taixu_yunhai"
var _filter: String = "all"            # all / owned / locked
var _cards: Dictionary = {}            # id -> {root, panel, tex, equip_tag, lock_overlay}
var _filter_labels: Dictionary = {}    # filter -> Label
var _filter_underlines: Dictionary = {}# filter -> Control
var _grid_scroll: ScrollContainer = null
var _grid_content: Control = null
var _thumb: TextureRect = null
var _bottom_name: Label = null
var _bottom_tier: Label = null
var _wear_btn: Button = null
var _wear_label: Label = null
var _owned_label: Label = null
var _lock_tex: Texture2D = null

func _ready() -> void:
	if is_instance_valid(Game):
		var eq = Game.get("当前皮肤")
		if eq != null and _skin_by_id(eq) != null:
			_equipped_id = eq
	_selected_id = _equipped_id
	_build()
	_refresh_all()

# ───────── 构建 ─────────
func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 页面底色（深色，让皮肤卡浮起；覆盖在 01 屏内容区之上）
	var base := ColorRect.new()
	base.name = "PageBase"
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.color = UITheme.C01_SCENE_BASE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	_build_top_bar()
	_build_filter()
	_build_grid()
	_build_bottom_bar()

func _build_top_bar() -> void:
	# 返回按钮（统一 40×40 金色箭头）
	var back: Button = UITheme.make_back_button(_on_back_pressed)
	_place(back, 16.0, 18.0, 40.0, 40.0)
	add_child(back)

	# 已拥有计数（顶部右侧）
	_owned_label = _mk_label(self, "OwnedCounter", "已拥有 0/0", 300.0, 24.0, 164.0, 20.0, 14,
		UITheme.获取弱文字色(), false, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_CENTER, false)

func _build_filter() -> void:
	# 三等分列：列中心 80 / 240 / 400，标签宽 80
	var defs: Array = [
		{"key": "all",   "label": "全部",   "x": 40.0},
		{"key": "owned", "label": "已拥有", "x": 200.0},
		{"key": "locked","label": "未拥有", "x": 360.0},
	]
	for d in defs:
		var key: String = d["key"]
		var lbl: Label = _mk_label(self, "Filter_" + key, d["label"], float(d["x"]), 60.0, 80.0, 28.0, 20,
			UITheme.获取弱文字色(), true, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)
		_filter_labels[key] = lbl
		var ul := Control.new()
		ul.name = "Underline_" + key
		_place(ul, float(d["x"]) + 20.0, 90.0, 40.0, 3.0)
		ul.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ul_sb: StyleBox = UITheme.make_panel_stylebox_flat(UITheme.COLOR_TEXT_GOLD, Color(0,0,0,0), 1, 0)
		ul.add_theme_stylebox_override("panel", ul_sb)
		add_child(ul)
		ul.modulate.a = 0.0
		ul.create_tween().tween_property(ul, "modulate:a", 1.0, 0.25)
		_filter_underlines[key] = ul
		var hit := Button.new()
		hit.name = "FilterHit_" + key
		hit.flat = true
		hit.text = ""
		_place(hit, float(d["x"]) - 5.0, 56.0, 90.0, 42.0)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		var hsb: StyleBox = UITheme.make_panel_stylebox_flat(Color(0,0,0,0), Color(0,0,0,0), 0, 0)
		hit.add_theme_stylebox_override("normal", hsb)
		hit.add_theme_stylebox_override("pressed", hsb)
		hit.add_theme_stylebox_override("hover", hsb)
		hit.add_theme_stylebox_override("focus", hsb)
		hit.pressed.connect(_on_filter_pressed.bind(key))
		add_child(hit)
		hit.modulate.a = 0.0
		hit.create_tween().tween_property(hit, "modulate:a", 1.0, 0.25)

func _build_grid() -> void:
	# 滚动容器：固定占用顶部与底栏之间的区域
	var s: float = UITheme.UI_SCALE
	var scroll := ScrollContainer.new()
	scroll.name = "GridScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	scroll.offset_left = 0.0
	scroll.offset_top = GRID_TOP * s
	scroll.offset_right = 480.0 * s
	scroll.offset_bottom = GRID_BOTTOM * s
	scroll.size = Vector2(480.0 * s, (GRID_BOTTOM - GRID_TOP) * s)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scroll)
	_grid_scroll = scroll

	var content := Control.new()
	content.name = "GridContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	content.position = Vector2.ZERO
	content.size = Vector2(480.0 * s, (GRID_BOTTOM - GRID_TOP) * s)
	content.custom_minimum_size = content.size
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(content)
	_grid_content = content

	var i: int = 0
	for skin in SKINS:
		var x: float = CARD_X0 if (i % 2 == 0) else CARD_X1
		var y: float = float(i / 2) * GRID_DY
		_make_card(skin, x, y)
		i += 1

	_update_content_size()

func _make_card(skin: Dictionary, x: float, y: float) -> void:
	var id: String = skin["id"]
	var root := Control.new()
	root.name = "Card_" + id
	_place(root, x, y, CARD_W, CARD_H)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid_content.add_child(root)
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.25)

	var panel := Panel.new()
	panel.name = "Panel"
	_place(panel, 0.0, 0.0, CARD_W, CARD_H)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)

	# 皮肤预览图（等比铺满，缺图回落默认）
	var tex := TextureRect.new()
	tex.name = "Preview"
	_place(tex, 0.0, 0.0, CARD_W, CARD_H)
	tex.texture = _load_skin_bg(skin)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tex)
	tex.modulate.a = 0.0
	tex.create_tween().tween_property(tex, "modulate:a", 1.0, 0.25)

	# 底部压暗渐变（让名称可读）
	var shade := Panel.new()
	shade.name = "Shade"
	_place(shade, 0.0, CARD_H - 54.0, CARD_W, 54.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_theme_stylebox_override("panel",
		UITheme.make_panel_stylebox_flat(Color(UITheme.C01_SCENE_BASE.r, UITheme.C01_SCENE_BASE.g, UITheme.C01_SCENE_BASE.b, 0.78), Color(0,0,0,0), 0, 0))
	panel.add_child(shade)
	shade.modulate.a = 0.0
	shade.create_tween().tween_property(shade, "modulate:a", 1.0, 0.25)
	var nm: Label = _mk_label(panel, "Name", skin["name"], 12.0, CARD_H - 30.0, CARD_W - 24.0, 20.0, 16,
		UITheme.获取主文字色(), true, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, true)

	# 品阶标签（canonical 品阶色）
	var badge := Panel.new()
	badge.name = "TierBadge"
	_place(badge, 10.0, 10.0, 42.0, 22.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tier_col: Color = UIThemeConfig.get_quality_color(skin["tier"])
	badge.add_theme_stylebox_override("panel",
		UITheme.make_panel_stylebox_flat(Color(tier_col.r, tier_col.g, tier_col.b, 0.92), Color(0,0,0,0), 11, 0))
	panel.add_child(badge)
	badge.modulate.a = 0.0
	badge.create_tween().tween_property(badge, "modulate:a", 1.0, 0.25)
	_mk_label(badge, "TierText", skin["tier_name"], 0.0, 1.0, 42.0, 20.0, 13,
		UITheme.获取主文字色(), true, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)

	# 装备中标签（仅装备时显示）
	var eq := Panel.new()
	eq.name = "EquipTag"
	_place(eq, CARD_W - 66.0, 10.0, 56.0, 24.0)
	eq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eq.add_theme_stylebox_override("panel",
		UITheme.make_panel_stylebox_flat(UITheme.COLOR_TEXT_GOLD, Color(0,0,0,0), 12, 0))
	panel.add_child(eq)
	eq.modulate.a = 0.0
	eq.create_tween().tween_property(eq, "modulate:a", 1.0, 0.25)
	_mk_label(eq, "EquipText", "装备中", 0.0, 2.0, 56.0, 20.0, 12,
		UITheme.C01_SCENE_BASE, true, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)

	# 未拥有遮罩（默认隐藏）
	var lock := Control.new()
	lock.name = "LockOverlay"
	_place(lock, 0.0, 0.0, CARD_W, CARD_H)
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.visible = false
	var lock_bg := Panel.new()
	lock_bg.name = "LockBg"
	_place(lock_bg, 0.0, 0.0, CARD_W, CARD_H)
	lock_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_bg.add_theme_stylebox_override("panel",
		UITheme.make_panel_stylebox_flat(Color(UITheme.C01_SCENE_BASE.r, UITheme.C01_SCENE_BASE.g, UITheme.C01_SCENE_BASE.b, 0.68), Color(0,0,0,0), 0, 0))
	lock.add_child(lock_bg)
	lock_bg.modulate.a = 0.0
	lock_bg.create_tween().tween_property(lock_bg, "modulate:a", 1.0, 0.25)
	var lic := TextureRect.new()
	lic.name = "LockIcon"
	_place(lic, (CARD_W - 36.0) / 2.0, 62.0, 36.0, 36.0)
	lic.texture = _lock_texture()
	lic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.add_child(lic)
	lic.modulate.a = 0.0
	lic.create_tween().tween_property(lic, "modulate:a", 1.0, 0.25)
	_mk_label(lock, "LockText", "未解锁", 0.0, 104.0, CARD_W, 20.0, 15,
		UITheme.获取次文字色(), true, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)
	_mk_label(lock, "CondText", "", 12.0, CARD_H - 26.0, CARD_W - 24.0, 16.0, 11,
		UITheme.获取弱文字色(), false, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)
	panel.add_child(lock)
	lock.modulate.a = 0.0
	lock.create_tween().tween_property(lock, "modulate:a", 1.0, 0.25)

	# 点击热区
	var hit := Button.new()
	hit.name = "Hit"
	hit.flat = true
	hit.text = ""
	_place(hit, 0.0, 0.0, CARD_W, CARD_H)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	var hsb: StyleBox = UITheme.make_panel_stylebox_flat(Color(0,0,0,0), Color(0,0,0,0), 0, 0)
	hit.add_theme_stylebox_override("normal", hsb)
	hit.add_theme_stylebox_override("pressed", hsb)
	hit.add_theme_stylebox_override("hover", hsb)
	hit.add_theme_stylebox_override("focus", hsb)
	hit.pressed.connect(_on_card_pressed.bind(id))
	root.add_child(hit)
	hit.modulate.a = 0.0
	hit.create_tween().tween_property(hit, "modulate:a", 1.0, 0.25)

	_cards[id] = {"root": root, "panel": panel, "tex": tex, "equip_tag": eq, "lock_overlay": lock, "name": nm}

func _build_bottom_bar() -> void:
	var bar := Control.new()
	bar.name = "BottomBar"
	_place(bar, 0.0, GRID_BOTTOM, 480.0, BOTTOM_H)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var bg := Panel.new()
	bg.name = "BarBg"
	_place(bg, 0.0, 0.0, 480.0, BOTTOM_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel",
		UITheme.make_panel_stylebox_flat(UITheme.C01_SCENE_BASE, Color(0,0,0,0), 0, 0))
	bar.add_child(bg)
	var div := Panel.new()
	div.name = "Divider"
	_place(div, 0.0, 0.0, 480.0, 1.0)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	div.add_theme_stylebox_override("panel",
		UITheme.make_panel_stylebox_flat(Color(UITheme.C01_GOLD_LINE.r, UITheme.C01_GOLD_LINE.g, UITheme.C01_GOLD_LINE.b, 0.3), Color(0,0,0,0), 0, 0))
	bar.add_child(div)

	_thumb = TextureRect.new()
	_thumb.name = "Thumb"
	_place(_thumb, 16.0, 13.0, 56.0, 56.0)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_thumb)

	_bottom_name = _mk_label(bar, "BottomName", "", 84.0, 14.0, 240.0, 22.0, 18,
		UITheme.获取主文字色(), true, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, false)
	_bottom_tier = _mk_label(bar, "BottomTier", "", 84.0, 42.0, 240.0, 16.0, 12,
		UITheme.获取次文字色(), false, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, false)

	_wear_btn = Button.new()
	_wear_btn.name = "WearBtn"
	# ★ 2026-09-15 修「穿戴按钮看不到」：原为 flat = true —— Godot 的 flat Button 在
	#   **normal 态不绘制 stylebox**（只在 hover/pressed 才画），于是「未装备」态的金色胶囊底
	#   整块消失，只剩 C01_SCENE_BASE（深绿）文字压在深绿底栏上 ⇒ 完全隐形。
	#   「已装备」态的「装备中」是次文字色（浅），所以那一态看得见 —— 这正是老大
	#   图5 能看到、图6 看不到的原因。
	_wear_btn.flat = false
	_wear_btn.text = ""
	_place(_wear_btn, 336.0, 16.0, 128.0, 50.0)
	_wear_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_wear_btn.pressed.connect(_on_wear_pressed)
	bar.add_child(_wear_btn)
	_wear_label = _mk_label(_wear_btn, "WearLabel", "穿戴", 0.0, 0.0, 128.0, 50.0, 16,
		UITheme.C01_SCENE_BASE, true, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, false)

# ───────── 刷新 ─────────
func _refresh_all() -> void:
	_refresh_owned_counter()
	_refresh_filter_styles()
	_refresh_cards_state()
	_refresh_bottom_bar()
	_apply_filter_visibility()

func _refresh_owned_counter() -> void:
	if _owned_label == null:
		return
	var owned: int = 0
	for skin in SKINS:
		if _is_owned(skin):
			owned += 1
	_owned_label.text = "已拥有 %d/%d" % [owned, SKINS.size()]

func _refresh_filter_styles() -> void:
	for key in _filter_labels:
		var lbl: Label = _filter_labels[key]
		var ul: Control = _filter_underlines[key]
		if key == _filter:
			lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
			UITheme.apply_title_font_sized(lbl, UITheme.FONT_TITLE)
			ul.visible = true
		else:
			lbl.add_theme_color_override("font_color", UITheme.获取弱文字色())
			UITheme.apply_title_font_sized(lbl, UITheme.FONT_H2)
			ul.visible = false

func _refresh_cards_state() -> void:
	for skin in SKINS:
		var id: String = skin["id"]
		var rec: Dictionary = _cards.get(id, {})
		if rec.is_empty():
			continue
		var panel: Panel = rec["panel"]
		var equip_tag: Panel = rec["equip_tag"]
		var lock_overlay: Control = rec["lock_overlay"]
		var owned: bool = _is_owned(skin)
		# 未拥有遮罩
		lock_overlay.visible = not owned
		if not owned:
			var cond_lbl: Label = lock_overlay.get_node_or_null("CondText") as Label
			if cond_lbl != null:
				cond_lbl.text = _unlock_desc(skin)
		# 装备中标签
		equip_tag.visible = (id == _equipped_id)
		# 描边：选中(亮金2) > 装备(暗金2) > 普通(暗金1)
		var border_col: Color = UITheme.C01_GOLD_LINE
		var border_w: int = 1
		if id == _selected_id:
			border_col = UITheme.COLOR_TEXT_GOLD
			border_w = 2
		elif id == _equipped_id:
			border_col = UITheme.C01_GOLD_LINE
			border_w = 2
		else:
			border_col = Color(UITheme.C01_GOLD_LINE.r, UITheme.C01_GOLD_LINE.g, UITheme.C01_GOLD_LINE.b, 0.35)
			border_w = 1
		panel.add_theme_stylebox_override("panel",
			UITheme.make_panel_stylebox_flat(UITheme.C01_SCENE_BASE, border_col, int(round(12.0 * UITheme.UI_SCALE)), border_w))

func _refresh_bottom_bar() -> void:
	var skin: Dictionary = _skin_by_id(_selected_id)
	if skin.is_empty():
		return
	if _thumb != null:
		_thumb.texture = _load_skin_bg(skin)
	if _bottom_name != null:
		_bottom_name.text = skin["name"]
	if _bottom_tier != null:
		var owned: bool = _is_owned(skin)
		var state: String = "已装备" if _selected_id == _equipped_id else ("已拥有" if owned else "未解锁")
		_bottom_tier.text = "%s阶 · %s" % [skin["tier_name"], state]
	if _wear_btn != null and _wear_label != null:
		var 已拥有: bool = _is_owned(skin)
		var sb: StyleBox
		if _selected_id == _equipped_id:
			sb = UITheme.make_panel_stylebox_flat(Color(UITheme.C01_GOLD_LINE.r, UITheme.C01_GOLD_LINE.g, UITheme.C01_GOLD_LINE.b, 0.45), Color(0,0,0,0), 25, 0)
			_wear_label.text = "装备中"
			_wear_label.add_theme_color_override("font_color", UITheme.获取次文字色())
			_wear_btn.disabled = true
		elif not 已拥有:
			# ★ 2026-09-16 修（真缺陷 · 点击静默）：旧实现只挡了「装备中」一档，
			#   选中**未拥有**的皮肤时按钮仍是可点的（disabled=false），
			#   而 _on_wear_pressed() 里 `if not _is_owned(skin): return` 直接静默返回
			#   ⇒ 玩家点「穿戴」毫无反应，以为卡死。
			#   改为同款置灰 + 「未解锁」文案：不可用的动作就该 disabled（大厂通行做法）。
			sb = UITheme.make_panel_stylebox_flat(Color(UITheme.C01_GOLD_LINE.r, UITheme.C01_GOLD_LINE.g, UITheme.C01_GOLD_LINE.b, 0.14), Color(0,0,0,0), 25, 0)
			_wear_label.text = "未解锁"
			_wear_label.add_theme_color_override("font_color", UITheme.获取弱文字色())
			_wear_btn.disabled = true
		else:
			sb = UITheme.make_panel_stylebox_flat(UITheme.COLOR_TEXT_GOLD, Color(0,0,0,0), 25, 0)
			_wear_label.text = "穿戴"
			_wear_label.add_theme_color_override("font_color", UITheme.C01_SCENE_BASE)
			_wear_btn.disabled = false
		_wear_btn.add_theme_stylebox_override("normal", sb)
		_wear_btn.add_theme_stylebox_override("pressed", sb)
		_wear_btn.add_theme_stylebox_override("hover", sb)
		_wear_btn.add_theme_stylebox_override("focus", sb)
		# disabled 必须一起套：旧实现漏了这一档，「装备中」时按钮按主题默认 disabled 样式
		# 渲染（无底色/半透明），视觉上像凭空消失，只剩旁边一行浅色文字。
		_wear_btn.add_theme_stylebox_override("disabled", sb)

func _apply_filter_visibility() -> void:
	var xs: Array = [CARD_X0, CARD_X1]
	var visible_idx: int = 0
	for skin in SKINS:
		var id: String = skin["id"]
		var rec: Dictionary = _cards.get(id, {})
		if rec.is_empty():
			continue
		var owned: bool = _is_owned(skin)
		var show: bool = true
		if _filter == "owned":
			show = owned
		elif _filter == "locked":
			show = not owned
		rec["root"].visible = show
		if show:
			var col: int = visible_idx % 2
			var row: int = visible_idx / 2
			_place(rec["root"], float(xs[col]), float(row) * GRID_DY, CARD_W, CARD_H)
			visible_idx += 1
	_update_content_size()

func _update_content_size() -> void:
	if _grid_content == null:
		return
	var visible_count: int = 0
	for skin in SKINS:
		var owned: bool = _is_owned(skin)
		var show: bool = true
		if _filter == "owned":
			show = owned
		elif _filter == "locked":
			show = not owned
		if show:
			visible_count += 1
	var rows: int = maxi(ceil(float(visible_count) / 2.0), 1)
	var content_h: float = float(rows) * GRID_DY
	var s: float = UITheme.UI_SCALE
	_grid_content.size = Vector2(480.0 * s, content_h * s)
	_grid_content.custom_minimum_size = _grid_content.size

# ───────── 交互 ─────────
func _on_back_pressed() -> void:
	返回主页.emit()

func _on_filter_pressed(key: String) -> void:
	_filter = key
	_refresh_filter_styles()
	_apply_filter_visibility()

func _on_card_pressed(id: String) -> void:
	var skin: Dictionary = _skin_by_id(id)
	if skin.is_empty():
		return
	if not _is_owned(skin):
		_toast("未解锁：" + _unlock_desc(skin))
		return
	_selected_id = id
	_refresh_cards_state()
	_refresh_bottom_bar()

func _on_wear_pressed() -> void:
	if _selected_id == _equipped_id:
		return
	var skin: Dictionary = _skin_by_id(_selected_id)
	if skin.is_empty() or not _is_owned(skin):
		return
	if is_instance_valid(Game):
		Game.当前皮肤 = _selected_id
		Game.save_game()
	皮肤已装备.emit(_selected_id)
	_equipped_id = _selected_id
	_refresh_cards_state()
	_refresh_bottom_bar()
	_refresh_owned_counter()

# ───────── helper ─────────
func _skin_by_id(id: String) -> Dictionary:
	for skin in SKINS:
		if skin["id"] == id:
			return skin
	return {}

func _is_owned(skin: Dictionary) -> bool:
	var u: Dictionary = skin["unlock"]
	match u.get("type", "always"):
		"always":
			return true
		"sect_level":
			var need: int = int(u.get("value", 999))
			var lv: int = 1
			if is_instance_valid(Game):
				lv = int(Game.门派等级)
			return lv >= need
		"days":
			var need: int = int(u.get("value", 999999))
			var d: int = 0
			if is_instance_valid(Game):
				d = int(Game.累计游戏日)
			return d >= need
		_:
			return true

func _unlock_desc(skin: Dictionary) -> String:
	var u: Dictionary = skin["unlock"]
	match u.get("type", "always"):
		"sect_level":
			return "宗门 %d 品 解锁" % int(u.get("value", 0))
		"days":
			return "累计登录 %d 日解锁" % int(u.get("value", 0))
		_:
			return ""

func _load_skin_bg(skin: Dictionary) -> Texture2D:
	var tex: Texture2D = load(skin["bg"]) as Texture2D
	if tex == null:
		tex = load("res://art/backgrounds/home_bg_sect_a.png") as Texture2D
	return tex

func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	var s: float = UITheme.UI_SCALE
	c.layout_mode = 0
	c.offset_left = x * s
	c.offset_top = y * s
	c.offset_right = (x + w) * s
	c.offset_bottom = (y + h) * s
	c.size = Vector2(w * s, h * s)

func _mk_label(parent: Control, nm: String, txt: String, x: float, y: float, w: float, h: float,
		font_size: int, color: Color, bold: bool, align_h: int, align_v: int, shadow: bool) -> Label:
	var lbl := Label.new()
	lbl.name = nm
	lbl.text = txt
	_place(lbl, x, y, w, h)
	lbl.horizontal_alignment = align_h
	lbl.vertical_alignment = align_v
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = true
	# 字号收口到统一阶梯（消除跨页尺寸漂移），保留 bold/regular 字重
	var fsz: int
	if font_size <= 12:
		fsz = UITheme.FONT_AUX
	elif font_size <= 14:
		fsz = UITheme.FONT_BODY
	elif font_size <= 17:
		fsz = UITheme.FONT_H2
	else:
		fsz = UITheme.FONT_TITLE
	if bold:
		UITheme.apply_title_font_sized(lbl, fsz)
	else:
		UITheme.apply_body_font_sized(lbl, fsz)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	if shadow:
		var sh := Label.new()
		sh.name = nm + "_shadow"
		sh.text = txt
		_place(sh, x + 1.0, y + 1.0, w, h)
		sh.horizontal_alignment = align_h
		sh.vertical_alignment = align_v
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.clip_text = true
		if bold:
			UITheme.apply_title_font_sized(sh, fsz)
		else:
			UITheme.apply_body_font_sized(sh, fsz)
		sh.add_theme_color_override("font_color", UITheme.C01_SHADOW)
		parent.add_child(sh)
		parent.move_child(lbl, parent.get_child_count() - 1)
	return lbl

func _lock_texture() -> Texture2D:
	if _lock_tex != null:
		return _lock_tex
	var svg: String = "<svg xmlns='http://www.w3.org/2000/svg' width='28' height='28' viewBox='0 0 24 24' fill='none'><path d='M7 10V7a5 5 0 0 1 10 0v3' stroke='#D6B16A' stroke-width='2' stroke-linecap='round'/><rect x='5' y='10' width='14' height='10' rx='2' stroke='#D6B16A' stroke-width='2'/><circle cx='12' cy='15' r='1.6' fill='#D6B16A'/></svg>"
	var img := Image.new()
	var err: int = img.load_svg_from_string(svg, 2.0)
	if err != OK:
		return null
	_lock_tex = ImageTexture.create_from_image(img)
	return _lock_tex

func _toast(text: String) -> void:
	print("[幻形] %s" % text)




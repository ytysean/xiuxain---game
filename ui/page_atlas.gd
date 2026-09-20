extends Control

# 宗门舆图（GameUI 二级页）—— 全法门功能索引 + 意图反查（UX 总纲 §4.8 F1 / F2 / F3）
#
# F1 功能索引页：全部系统按「四柱 → 主题组」列成一张可浏览目录（图标 + 名称 + 一句话 + 所属柱/组）。
#    已开启的可直入；**未开启的也列出**并写明缘由（SystemUnlock.入口解锁提示）——解决「不知道自己错过了什么」。
# F2 意图反查：顶部「我想……」静态意图标签 → 高亮命中的法门（静态映射表 config/atlas_intent.csv，不做智能推荐）。
# F3 归位预期：柱 / 组 / 组内顺序**严格按 CSV 行序**渲染 —— 新增法门只在组尾追加，绝不重排既有成员。
#
# 性质：**不是新系统**，是既有系统清单的可视化 —— 零玩法、零存档改动、零数值。
# gating 单一来源仍为 config/unlock_order.csv（经 SystemUnlock 只读查询），本页不重复定义任何解锁条件。
# 颜色一律走 UITheme 真实 const，禁硬编码（UI 三连）。

signal 返回主页
signal 打开请求(id: String)

const 索引表路径: String = "res://config/atlas_index.csv"
const 意图表路径: String = "res://config/atlas_intent.csv"

# 卡片尺寸：432 逻辑宽 = 480 − 2×MARGIN(24)；两列 + 12 间距 → 204×2+12 = 420 ≤ 432。
const CARD_W: float = 204.0
const CARD_H: float = 92.0

# 四柱释义（纯展示文案，与 config/atlas_index.csv 的「柱」列同字绑定）。
const 柱释义: Dictionary = {
	"门下（人柱）": "谁在修炼",
	"征伐（战柱）": "去哪打、打谁",
	"百工（产柱）": "把材料变成道行",
	"四方（世柱）": "宗门之外的世界",
}

var _built: bool = false
var _索引: Array = []
var _意图: Array = []
var _主体: VBoxContainer = null
var _滚动: ScrollContainer = null
var _卡片: Dictionary = {}
var _高亮: Array = []


func _ready() -> void:
	_索引 = _读索引表()
	_意图 = _读意图表()
	_build()
	refresh()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content: Control = UITheme.make_scene_background(self)
	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(vbox)

	_build_header(vbox)

	var scroll := ScrollContainer.new()
	scroll.name = "IndexScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_滚动 = scroll
	_主体 = VBoxContainer.new()
	_主体.name = "IndexBody"
	_主体.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_主体.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_主体)

	var 说明 := Label.new()
	说明.name = "Note"
	说明.text = "舆图按「四柱」列出宗门全部法门：已开启的直入，未开启的写明缘由。新增法门只在组尾追加，不扰旧位。"
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说明)
	说明.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(说明)


func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	parent.add_child(UITheme.建顶栏("宗门舆图", _on_back_pressed, [], "宗门舆图", "全宗门法门总目录（四柱 → 主题组）。\n「知其在何处」在此直入；「知其有何用」看顶部意图。\n未开启的法门亦列明缘由，免你错过。"))
func refresh() -> void:
	if not _built:
		return
	for c in _主体.get_children():
		c.queue_free()
	_卡片.clear()
	_建_意图区(_主体)
	_建_索引区(_主体)


# ───────── F2 意图反查（顶部静态标签）─────────

func _建_意图区(parent: VBoxContainer) -> void:
	if _意图.is_empty():
		return
	var 标 := Label.new()
	标.name = "IntentTitle"
	标.text = "我想……（点一按，高亮可用的法门）"
	UITheme.apply_section_title(标)
	标.add_theme_color_override("font_color", UITheme.获取金文字色())
	parent.add_child(标)
	标.modulate.a = 0.0
	标.create_tween().tween_property(标, "modulate:a", 1.0, 0.25)

	var grid := GridContainer.new()
	grid.name = "IntentGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", UITheme.GRID_SM)
	grid.add_theme_constant_override("v_separation", UITheme.GRID_SM)
	parent.add_child(grid)
	grid.modulate.a = 0.0
	grid.create_tween().tween_property(grid, "modulate:a", 1.0, 0.25)
	for cfg in _意图:
		var _fb1 := _make_intent_chip(cfg)
		grid.add_child(_fb1)
		_fb1.modulate.a = 0.0
		_fb1.create_tween().tween_property(_fb1, "modulate:a", 1.0, 0.25)


func _make_intent_chip(cfg: Dictionary) -> Control:
	var 意图: String = String(cfg.get("意图", ""))
	var 目标: Array = cfg.get("目标", [])
	var btn := Button.new()
	btn.name = "Intent_" + 意图
	btn.text = 意图
	btn.focus_mode = Control.FOCUS_NONE
	# ★ 2026-09-16 修（真缺陷 · 静默不可见）：原实现 clip_text=true + 默认 size_flags(FILL)
	#   在 GridContainer 里**双双致盲** ——
	#   ① Godot 4 的 Button 在 clip_text=true 时，最小宽度**不含文字宽**（微探针实测只剩
	#      content margin 24 逻辑）；
	#   ② GridContainer 列宽只按子项最小宽，且**只有子项带 EXPAND 才会被撑开**。
	#   两者叠加 ⇒ chip 实宽 24、文字宽 78，6 个意图标签的文字被整段裁掉，实机只见空框
	#   （静态闸门 + 布局扫描全绿，只有肉眼能看见）。
	#   修法：关掉 clip_text（最小宽重新含文字）+ 给 EXPAND_FILL 让 Grid 均分整行
	#   （微探针实测 32 → 198，文字放得下）。
	btn.clip_text = false
	btn.custom_minimum_size = Vector2(0.0, UITheme.SIZE_SM)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_project_font(btn, UITheme.FONT_AUX, true)
	UITheme.apply_secondary_button_style(btn)
	var 选中: bool = false
	for t in 目标:
		if _高亮.has(String(t)):
			选中 = true
			break
	if 选中:
		btn.add_theme_color_override("font_color", UITheme.获取金文字色())
	var tex: Texture2D = UITheme.load_hd_icon(String(cfg.get("图标", "")))
	if tex != null:
		btn.icon = tex
		btn.expand_icon = true
	btn.tooltip_text = _串(目标)
	btn.pressed.connect(_on_意图反查.bind(目标))
	return btn


# ───────── F1 功能索引（四柱 → 主题组 → 卡片）─────────

func _建_索引区(parent: VBoxContainer) -> void:
	var 当前柱: String = ""
	var 当前组: String = ""
	var grid: GridContainer = null
	for cfg in _索引:
		var 柱: String = String(cfg.get("柱", ""))
		var 组: String = String(cfg.get("组", ""))
		if 柱 != 当前柱:
			当前柱 = 柱
			当前组 = ""
			grid = null
			var _fb2 := _make_pillar_head(柱)
			parent.add_child(_fb2)
			_fb2.modulate.a = 0.0
			_fb2.create_tween().tween_property(_fb2, "modulate:a", 1.0, 0.25)
		if 组 != 当前组:
			当前组 = 组
			var _fb3 := _make_group_head(组)
			parent.add_child(_fb3)
			_fb3.modulate.a = 0.0
			_fb3.create_tween().tween_property(_fb3, "modulate:a", 1.0, 0.25)
			grid = GridContainer.new()
			grid.name = "Grid_" + 柱 + "_" + 组
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", UITheme.GRID_SM)
			grid.add_theme_constant_override("v_separation", UITheme.GRID_SM)
			parent.add_child(grid)
			grid.modulate.a = 0.0
			grid.create_tween().tween_property(grid, "modulate:a", 1.0, 0.25)
		if grid == null:
			continue
		var card: Control = _make_system_card(cfg)
		grid.add_child(card)
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.25)
		_卡片[String(cfg.get("入口id", ""))] = card


func _make_pillar_head(柱: String) -> Control:
	var 标 := Label.new()
	标.name = "Pillar_" + 柱
	标.text = "%s · %s" % [柱, String(柱释义.get(柱, ""))]
	标.custom_minimum_size = Vector2(0.0, UITheme.SIZE_SM)
	UITheme.apply_section_title(标)
	标.add_theme_color_override("font_color", UITheme.获取金文字色())
	return 标


func _make_group_head(组: String) -> Control:
	var 标 := Label.new()
	标.name = "Group_" + 组
	标.text = "— " + 组
	UITheme.apply_project_font(标, UITheme.FONT_BODY, false)
	标.add_theme_color_override("font_color", UITheme.获取次文字色())
	return 标


func _make_system_card(cfg: Dictionary) -> Control:
	var id: String = String(cfg.get("入口id", ""))
	var 已解锁: bool = SystemUnlock.入口可显示(id)

	var btn := Button.new()
	btn.name = "Atlas_" + id
	btn.text = ""
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.custom_minimum_size = Vector2(CARD_W, CARD_H)
	_样式卡片(btn, _高亮.has(id))
	btn.pressed.connect(_on_系统跳转.bind(id, 已解锁))
	if not 已解锁:
		btn.modulate = Color(1.0, 1.0, 1.0, 0.62)

	var tex: Texture2D = UITheme.load_hd_icon(String(cfg.get("图标", "")))
	if tex != null:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(icon, 10.0, 14.0, 40.0, 40.0)
		btn.add_child(icon)
		icon.modulate.a = 0.0
		icon.create_tween().tween_property(icon, "modulate:a", 1.0, 0.25)

	var 名标 := Label.new()
	名标.name = "Name"
	名标.text = String(cfg.get("系统名", ""))
	名标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_title_font_sized(名标, UITheme.FONT_BODY)
	名标.add_theme_color_override("font_color", UITheme.获取金文字色())
	_place(名标, 56.0, 12.0, CARD_W - 66.0, 20.0)
	btn.add_child(名标)
	名标.modulate.a = 0.0
	名标.create_tween().tween_property(名标, "modulate:a", 1.0, 0.25)

	var 述标 := Label.new()
	述标.name = "Desc"
	述标.text = String(cfg.get("一句话", ""))
	述标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	述标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_aux_font_sized(述标, UITheme.FONT_AUX)
	述标.add_theme_color_override("font_color", UITheme.获取次文字色())
	_place(述标, 56.0, 33.0, CARD_W - 66.0, 32.0)
	btn.add_child(述标)
	述标.modulate.a = 0.0
	述标.create_tween().tween_property(述标, "modulate:a", 1.0, 0.25)

	if not 已解锁:
		var 缘由: String = SystemUnlock.入口解锁提示(id)
		if 缘由 == "":
			缘由 = "随宗门壮大自会显现"
		var 态标 := Label.new()
		态标.name = "State"
		态标.text = "未启 · " + 缘由
		态标.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.apply_aux_font_sized(态标, UITheme.FONT_AUX)
		态标.add_theme_color_override("font_color", UITheme.获取金文字色())
		_place(态标, 10.0, 68.0, CARD_W - 20.0, 16.0)
		btn.add_child(态标)
		态标.modulate.a = 0.0
		态标.create_tween().tween_property(态标, "modulate:a", 1.0, 0.25)

	return btn


# 卡片蒙皮：命中（意图反查）时暗金双线高亮，常态为既有入口底 + 细暗金描边。
func _样式卡片(btn: Button, 命中: bool) -> void:
	var bg: Color = UITheme.C01_TAB_ACTIVE if 命中 else UITheme.C01_ENTRY_BG
	var bd: Color = UITheme.获取金文字色() if 命中 else UITheme.C01_GOLD_LINE
	var bw: int = 2 if 命中 else 1
	var 常态: StyleBox = UITheme.make_panel_stylebox_flat(bg, bd, 8, bw)
	var 悬停: StyleBox = UITheme.make_panel_stylebox_flat(bg, UITheme.获取金文字色(), 8, bw)
	btn.add_theme_stylebox_override("normal", 常态)
	btn.add_theme_stylebox_override("hover", 悬停)
	btn.add_theme_stylebox_override("pressed", 悬停)
	btn.add_theme_stylebox_override("focus", 悬停)


func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)


# ───────── 表读取（零玩法：纯静态映射）─────────

func _读索引表() -> Array:
	var 表: Array = []
	var f: FileAccess = FileAccess.open(索引表路径, FileAccess.READ)
	if f == null:
		push_warning("[宗门舆图] 未找到索引表 %s" % 索引表路径)
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p: PackedStringArray = f.get_csv_line()
		if p.size() < 6:
			continue
		var 系统名: String = _净(p[2])
		if 系统名 == "":
			continue
		表.append({
			"柱": _净(p[0]),
			"组": _净(p[1]),
			"系统名": 系统名,
			"图标": _净(p[3]),
			"一句话": _净(p[4]),
			"入口id": _净(p[5]),
		})
	f.close()
	return 表


func _读意图表() -> Array:
	var 表: Array = []
	var f: FileAccess = FileAccess.open(意图表路径, FileAccess.READ)
	if f == null:
		push_warning("[宗门舆图] 未找到意图表 %s" % 意图表路径)
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p: PackedStringArray = f.get_csv_line()
		if p.size() < 2:
			continue
		var 意图: String = _净(p[0])
		if 意图 == "":
			continue
		var 目标: Array = []
		for x in _净(p[1]).split("、", false):
			var t: String = x.strip_edges()
			if t != "":
				目标.append(t)
		var 图标: String = _净(p[2]) if p.size() >= 3 else ""
		表.append({"意图": 意图, "目标": 目标, "图标": 图标})
	f.close()
	return 表


func _净(v: String) -> String:
	return v.strip_edges().lstrip("\ufeff")


func _串(目标: Array) -> String:
	var s: String = ""
	for t in 目标:
		if s != "":
			s += "、"
		s += String(t)
	return s


# ───────── 信号出口 ─────────

func _on_back_pressed() -> void:
	返回主页.emit()


func _on_系统跳转(id: String, 已解锁: bool) -> void:
	if not 已解锁:
		var 缘由: String = SystemUnlock.入口解锁提示(id)
		if 缘由 == "":
			缘由 = "随宗门壮大自会显现"
		UIHint.show_hint(self, "尚未开启", 缘由)
		Game.添加提示("尚未开启")
		return
	打开请求.emit(id)


func _on_意图反查(目标: Array) -> void:
	_高亮.clear()
	for t in 目标:
		_高亮.append(String(t))
	refresh()
	if _滚动 == null:
		return
	for t in 目标:
		var c: Control = _卡片.get(String(t), null)
		if c != null:
			_滚动.ensure_control_visible(c)
			break

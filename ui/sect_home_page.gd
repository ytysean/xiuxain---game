extends Control

# 宗门主权展示页（01 屏画布 v5 1:1 复刻 · Ardot 2:55，1080×1920 实机基准）。
# 坐标唯一数据源 = compose_v5_framed.py 1080p 实测值，按 UI_SCALE=2.25 反推为逻辑单位。
# 本文件内魔法数字均来自 v5 定稿，禁凭手感改。
# S1 红线：仅展示 + 入口；所有数据只读 Game Autoload，绝不写 GameState / 玩法 / 战斗逻辑。

signal entry_selected(entry_id: String)
signal hide_ui_requested(hidden: bool)

const RedDotBadge := preload("res://ui/red_dot_badge.gd")

# ───────── v5 定稿：左右侧边入口（149px 金边图标 + 25px 白粗体标签）─────────
const ENTRIES_LEFT: Array = [
	{"id": "山门",     "icon": "entry_shanmen_36"},
	{"id": "宗务", "icon": "entry_zongmenyaowu_36"},
	{"id": "坊市",     "icon": "entry_fangshi_36"},
]
const ENTRIES_RIGHT: Array = [
	{"id": "玄榜",   "icon": "entry_fengyunbang_36"},
	{"id": "图录",     "icon": "entry_tujian_36"},
	{"id": "碎片宝箱",     "icon": "entry_fragment_chest_36"},
]
const COL_LEFT_X: float = 36.0        # 81 / 2.25
const COL_RIGHT_X: float = 444.0      # 999 / 2.25
const ENTRY_YS: Array = [150.0, 222.0, 294.0, 366.0]  # 间距72px，更紧凑
const ENTRY_SIZE: float = 66.222222   # 149 / 2.25
const ENTRY_ICON_SIZE: float = 66.222222
const ENTRY_FONT: int = 13            # 增大字体，更清晰
const ENTRY_LABEL_H: float = 12.0     # 增大标签高度

# 红点（v5 定稿）：宗务强红点 "2"，图录弱红点
const RED_DOT_LEFT: Dictionary = {"id": "宗务", "num": "2", "strong": true}
const RED_DOT_RIGHT: Dictionary = {"id": "图录", "num": "", "strong": false}

# 底部快捷栏红点配置
const QUICK_RED_DOTS: Array = [
	{"id": "库藏", "strong": false},
	{"id": "灵讯", "strong": true},
	{"id": "日供", "strong": false},
]

# ───────── v5 定稿：底部快捷栏（7 项，72px 图标，20px 白粗体标签）─────────
# 顺序 = 库藏 / 灵讯 / 日供 / 宗规 / 道友 / 设置 / 更多
# 「更多」按钮控制折叠：折叠态仅显示「更多」；展开态显示全部 7 项（默认展开，与 v5 设计稿一致）
const QUICK_ENTRIES: Array = [
	{"id": "库藏",     "icon": "entry_kucang_36"},
	{"id": "灵讯", "icon": "entry_feifuchuanxin_36"},
	{"id": "日供", "icon": "entry_qiandao_36"},
	{"id": "设置",     "icon": "entry_shezhi_36"},
	{"id": "更多",     "icon": "entry_more_36", "fold": true},
]
const QUICK_Y: float = 710.0          # 下移，配合底部导航栏收窄
const QUICK_XS: Array = [106.0, 173.0, 240.0, 307.0, 374.0]  # 5个按钮居中显示
const QUICK_BTN_W: float = 32.0  # 调整宽度以容纳9个
const QUICK_BTN_H: float = 44.0       # ~99 / 2.25
const QUICK_ICON_SIZE: float = 30.0   # 调整图标大小
const QUICK_FONT: int = 9             # 20 / 2.25 ≈ 8.9
const QUICK_LABEL_H: float = 9.0

# 更多弹窗入口（从首页和快捷栏移除的入口）
const MORE_ENTRIES: Array = [
	{"id": "宗主管理", "icon": "entry_zongzhuguanli_36"},
	{"id": "幻形", "icon": "entry_huanxing_36"},
	{"id": "功勋", "icon": "entry_gongxunbei_36"},
	{"id": "宗规", "icon": "entry_zongmenguizhi_36"},
	{"id": "道友", "icon": "entry_daoyou_36"},
	{"id": "阵营声望", "icon": "entry_fengyunbang_36"},
	{"id": "宗门战", "icon": "entry_zongmenyaowu_36"},
	{"id": "傀儡", "icon": "entry_puppet_36"},
	{"id": "藏书阁", "icon": "entry_library_36"},
	{"id": "药园", "icon": "entry_herb_garden_36"},
	{"id": "丹方", "icon": "entry_pill_formula_36"},
	{"id": "装备图纸", "icon": "entry_equipment_blueprint_36"},
	{"id": "活动中心", "icon": "entry_activity_36"},
]

# ───────── 幻形·洞天换肤：皮肤 id → 宗门首页背景图路径 ─────────
const SKIN_BG: Dictionary = {
	"taixu_yunhai": "res://art/backgrounds/home_bg_sect_a.png",
	"chun_qinglan": "res://art/backgrounds/home_bg_season_spring.png",
	"xia_bihe":     "res://art/backgrounds/home_bg_season_summer.png",
	"qiu_jinfeng":  "res://art/backgrounds/home_bg_season_autumn.png",
	"dong_xueji":   "res://art/backgrounds/home_bg_season_winter.png",
	"xian_jiuqiao": "res://art/backgrounds/home_bg_season_immortal.png",
}

# ───────── 节点引用 ─────────
var _scene_root: Control = null
var _chrome: Control = null
var _hidden_ui: bool = false

# 快捷栏折叠状态
var _quick_folded: bool = false
var _quick_buttons: Dictionary = {}   # id -> Button
var _quick_icons: Dictionary = {}     # id -> TextureRect（日供动态图标用）
var _quick_labels: Dictionary = {}    # id -> Label

var _bg: TextureRect = null
var _more_panel: Control = null

func _ready() -> void:
	_build()
	refresh()
	# 连接邮件变动信号，自动刷新灵讯红点
	if Game != null and Game.has_signal("邮件变动"):
		Game.邮件变动.connect(_refresh_red_dots, CONNECT_DEFERRED)

# ───────── 构建 ─────────
func _build() -> void:
	_scene_root = Control.new()
	_scene_root.name = "SceneRoot"
	_place(_scene_root, 0.0, -UITheme.TOPBAR_H / UITheme.UI_SCALE, 480.0, 854.0)
	_scene_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene_root)

	_build_base_and_bg()
	_build_chrome()
	_build_eye()

# 底色 + 山门主视觉背景图
func _build_base_and_bg() -> void:
	var base := ColorRect.new()
	base.name = "SceneBase"
	_place(base, 0.0, 0.0, 480.0, 854.0)
	base.color = UITheme.C01_SCENE_BASE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_root.add_child(base)

	var bg := TextureRect.new()
	bg.name = "BG"
	_place(bg, 0.0, 0.0, 480.0, 854.0)
	bg.texture = _load_bg_texture("res://art/backgrounds/home_bg_sect_a.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_root.add_child(bg)
	_bg = bg
	_apply_equipped_skin()

func _load_bg_texture(path: String) -> Texture2D:
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		return tex
	var img: Image = Image.load_from_file(path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

# 可隐藏浮层：左右入口 + 底部快捷栏
func _build_chrome() -> void:
	_chrome = Control.new()
	_chrome.name = "Chrome"
	_place(_chrome, 0.0, 0.0, 480.0, 854.0)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_root.add_child(_chrome)

	_build_entries()
	_build_quick_bar()

# v5 左右入口：图标 + 白字标签，无额外面板底
func _build_entries() -> void:
	for i in range(ENTRIES_LEFT.size()):
		var cfg: Dictionary = ENTRIES_LEFT[i]
		_make_entry(cfg, COL_LEFT_X, ENTRY_YS[i])
	for i in range(ENTRIES_RIGHT.size()):
		var cfg: Dictionary = ENTRIES_RIGHT[i]
		_make_entry(cfg, COL_RIGHT_X, ENTRY_YS[i])
	_make_red_dots()

func _make_entry(cfg: Dictionary, cx: float, cy: float) -> void:
	var id: String = cfg["id"]
	var x: float = cx - ENTRY_SIZE * 0.5
	var y: float = cy - ENTRY_SIZE * 0.5

	# 热区：覆盖 149px 图标圆
	var btn := Button.new()
	btn.name = "Entry_" + id
	btn.flat = true
	btn.text = ""
	_place(btn, x, y, ENTRY_SIZE, ENTRY_SIZE)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_entry_pressed.bind(id))
	_chrome.add_child(btn)

	# 金边图标：等比居中铺满热区
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = UITheme.load_hd_icon(cfg["icon"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(icon, 0.0, 0.0, ENTRY_ICON_SIZE, ENTRY_ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	# 标签：移到图标内部底部边缘（再向上收 6 逻辑单位，完全落入金边内暗色区），作为按钮子节点置顶显示
	var lbl: Label = _mk_label_in(btn, "Label_" + id, id,
		0.0, ENTRY_SIZE - ENTRY_LABEL_H - 6.0, ENTRY_SIZE, ENTRY_LABEL_H,
		ENTRY_FONT, UITheme.C01_TEXT_PRIMARY, true,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true)
	lbl.z_index = 10
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))

func _make_red_dots() -> void:
	_make_red_dot(RED_DOT_LEFT, COL_LEFT_X, false)
	_make_red_dot(RED_DOT_RIGHT, COL_RIGHT_X, true)
	# 初始化后刷新红点状态
	_refresh_red_dots()

## 创建底部快捷栏红点
func _make_quick_red_dots() -> void:
	for cfg in QUICK_RED_DOTS:
		var id: String = cfg["id"]
		var idx: int = -1
		for i in range(QUICK_ENTRIES.size()):
			if QUICK_ENTRIES[i]["id"] == id:
				idx = i
				break
		if idx < 0:
			continue

		# 红点位置：快捷栏按钮右上角
		var btn_x: float = QUICK_XS[idx]
		var btn_y: float = QUICK_Y
		var dot_offset_x: float = QUICK_BTN_W * 0.4
		var dot_offset_y: float = -QUICK_BTN_H * 0.3

		var dot: Panel
		if cfg["strong"]:
			dot = UITheme.make_red_dot_number(0, 16.0)
		else:
			dot = UITheme.make_red_dot(12.0)
		dot.name = "QuickRedDot_" + id
		var dot_size: Vector2 = dot.custom_minimum_size
		_place(dot, btn_x + dot_offset_x - dot_size.x / 2, btn_y + dot_offset_y - dot_size.y / 2, dot_size.x, dot_size.y)
		_chrome.add_child(dot)
		dot.visible = false

## 刷新红点状态（根据游戏数据动态显示/隐藏，带动画效果）
func _refresh_red_dots() -> void:
	# 宗务红点：新手目标有未完成项时显示
	var 宗务红点 = _chrome.get_node_or_null("RedDot_宗务")
	if 宗务红点 != null and Game != null and Game.has_method("新手_有红点"):
		var 应该显示: bool = bool(Game.新手_有红点())
		if 应该显示 and not 宗务红点.visible:
			UITheme.animate_red_dot_appear(宗务红点)
		elif not 应该显示 and 宗务红点.visible:
			UITheme.animate_red_dot_disappear(宗务红点)
	# 图录红点：暂时隐藏，等确认状态条件后再添加
	var 图录红点 = _chrome.get_node_or_null("RedDot_图录")
	if 图录红点 != null and 图录红点.visible:
		UITheme.animate_red_dot_disappear(图录红点)

	# 日供红点：今日可领取时显示
	var 日供红点 = _chrome.get_node_or_null("QuickRedDot_日供")
	if 日供红点 != null and Game != null and Game.has_method("日供_今日可领"):
		var 应该显示: bool = bool(Game.日供_今日可领())
		if 应该显示 and not 日供红点.visible:
			UITheme.animate_red_dot_appear(日供红点)
		elif not 应该显示 and 日供红点.visible:
			UITheme.animate_red_dot_disappear(日供红点)

	# 灵讯红点：有未读邮件时显示
	var 灵讯红点 = _chrome.get_node_or_null("QuickRedDot_灵讯")
	if 灵讯红点 != null and Game != null and "邮件列表" in Game:
		var 未读数: int = 0
		var 邮件列表 = Game.邮件列表
		if 邮件列表 != null:
			for 邮件 in 邮件列表:
				if 邮件 != null and 邮件.has("未读") and bool(邮件["未读"]):
					未读数 += 1
		var 应该显示: bool = 未读数 > 0
		if 应该显示 and not 灵讯红点.visible:
			UITheme.animate_red_dot_appear(灵讯红点)
		elif not 应该显示 and 灵讯红点.visible:
			UITheme.animate_red_dot_disappear(灵讯红点)

	# 库藏红点：暂时隐藏，等确认有新物品的判断条件后再添加
	var 库藏红点 = _chrome.get_node_or_null("QuickRedDot_库藏")
	if 库藏红点 != null and 库藏红点.visible:
		UITheme.animate_red_dot_disappear(库藏红点)

func _make_red_dot(cfg: Dictionary, col_x: float, _is_right: bool) -> void:
	var id: String = cfg["id"]
	var y_idx: int = -1
	for i in range(ENTRIES_LEFT.size()):
		if ENTRIES_LEFT[i]["id"] == id:
			y_idx = i
	for i in range(ENTRIES_RIGHT.size()):
		if ENTRIES_RIGHT[i]["id"] == id:
			y_idx = i
	if y_idx < 0:
		return

	# 红点统一压在图标右上角：中心相对图标中心偏移约 0.42 倍图标尺寸
	var cx: float = col_x
	var cy: float = ENTRY_YS[y_idx]
	var dot_offset: float = ENTRY_SIZE * 0.42
	var dot_cx: float = cx + dot_offset
	var dot_cy: float = cy - dot_offset

	# 使用统一红点样式：强红点显示数字，弱红点显示圆点
	var dot: Panel
	if cfg["strong"]:
		dot = UITheme.make_red_dot_number(int(cfg.get("num", "0")), 20.0)
	else:
		dot = UITheme.make_red_dot(14.0)
	dot.name = "RedDot_" + id
	var dot_size: Vector2 = dot.custom_minimum_size
	_place(dot, dot_cx - dot_size.x / 2, dot_cy - dot_size.y / 2, dot_size.x, dot_size.y)
	_chrome.add_child(dot)
	# 初始隐藏，由_refresh_red_dots控制显示
	dot.visible = false

# v5 底部快捷栏
func _build_quick_bar() -> void:
	for i in range(QUICK_ENTRIES.size()):
		var cfg: Dictionary = QUICK_ENTRIES[i]
		_make_quick_entry(cfg, i)
	_make_quick_red_dots()
	_refresh_quick_icons()
	_apply_quick_fold()

func _make_quick_entry(cfg: Dictionary, idx: int) -> void:
	var id: String = cfg["id"]
	var is_fold_btn: bool = cfg.get("fold", false)
	var x: float = QUICK_XS[idx] - QUICK_BTN_W * 0.5
	var y: float = QUICK_Y

	var btn := Button.new()
	btn.name = "Quick_" + id
	btn.flat = true
	btn.text = ""
	_place(btn, x, y, QUICK_BTN_W, QUICK_BTN_H)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_fold_btn:
		btn.pressed.connect(_on_quick_fold_toggle)
	else:
		btn.pressed.connect(_on_entry_pressed.bind(id))
	_chrome.add_child(btn)
	_quick_buttons[id] = btn

	var icon := TextureRect.new()
	icon.name = "Icon"
	var icon_x: float = (QUICK_BTN_W - QUICK_ICON_SIZE) * 0.5
	# 图标中心落在 qy+31 屏幕（即逻辑 QUICK_Y + 13.78）
	var icon_y: float = -2.222222
	_place(icon, icon_x, icon_y, QUICK_ICON_SIZE, QUICK_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	_quick_icons[id] = icon

	# 标签：移到图标内部底部边缘（再向上收 4 逻辑单位），作为按钮子节点置顶显示
	var label: Label = _mk_label_in(btn, "Label_" + id, id,
		0.0, QUICK_BTN_H - QUICK_LABEL_H - 4.0, QUICK_BTN_W, QUICK_LABEL_H,
		QUICK_FONT, UITheme.C01_TEXT_PRIMARY, true,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, true)
	label.z_index = 10
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_quick_labels[id] = label

func _on_quick_fold_toggle() -> void:
	if _more_panel == null:
		_build_more_panel()
	_more_panel.visible = not _more_panel.visible

func _apply_quick_fold() -> void:
	for i in range(QUICK_ENTRIES.size()):
		var cfg: Dictionary = QUICK_ENTRIES[i]
		var id: String = cfg["id"]
		var is_fold: bool = cfg.get("fold", false)
		var btn: Button = _quick_buttons.get(id, null)
		if btn == null:
			continue
		var visible: bool = is_fold if _quick_folded else true
		btn.visible = visible
		var lbl: Label = _quick_labels.get(id, null) as Label
		if lbl != null:
			lbl.visible = visible
	var more_icon: TextureRect = _quick_icons.get("更多", null) as TextureRect
	if more_icon != null:
		more_icon.flip_h = _quick_folded

# 构建更多弹窗
func _build_more_panel() -> void:
	# 半透明背景，点击后关闭弹窗
	var bg := ColorRect.new()
	bg.name = "MoreBG"
	_place(bg, 0.0, 0.0, 480.0, 854.0)
	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_more_bg_input)
	_scene_root.add_child(bg)

	# 弹窗面板
	var panel := Panel.new()
	panel.name = "MorePanel"
	var panel_w: float = 360.0
	var panel_h: float = 300.0
	var panel_x: float = (480.0 - panel_w) * 0.5
	var panel_y: float = (854.0 - panel_h) * 0.5
	_place(panel, panel_x, panel_y, panel_w, panel_h)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.add_child(panel)

	# 标题
	var title := Label.new()
	title.name = "Title"
	title.text = "更多功能"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(title, 0.0, 10.0, panel_w, 30.0)
	panel.add_child(title)

	# 入口按钮网格（3列）
	var cols: int = 3
	var btn_w: float = 100.0
	var btn_h: float = 80.0
	var gap_x: float = (panel_w - cols * btn_w) / (cols + 1)
	var gap_y: float = 15.0
	var start_y: float = 50.0

	for i in range(MORE_ENTRIES.size()):
		var cfg: Dictionary = MORE_ENTRIES[i]
		var id: String = cfg["id"]
		var row: int = i / cols
		var col: int = i % cols
		var btn_x: float = gap_x + col * (btn_w + gap_x)
		var btn_y: float = start_y + row * (btn_h + gap_y)

		var btn := Button.new()
		btn.name = "MoreBtn_" + id
		btn.flat = true
		btn.text = ""
		_place(btn, btn_x, btn_y, btn_w, btn_h)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_more_entry_pressed.bind(id))
		panel.add_child(btn)

		# 图标
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = UITheme.load_hd_icon(cfg["icon"])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_place(icon, (btn_w - 40.0) * 0.5, 5.0, 40.0, 40.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)

		# 标签
		var label := Label.new()
		label.name = "Label"
		label.text = id
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_place(label, 0.0, btn_h - 25.0, btn_w, 20.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(label)

	_more_panel = bg
	_more_panel.visible = false

func _on_more_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_more_panel.visible = false

func _on_more_entry_pressed(id: String) -> void:
	_more_panel.visible = false
	entry_selected.emit(id)

func _refresh_quick_icons() -> void:
	for cfg in QUICK_ENTRIES:
		var id: String = cfg["id"]
		var icon: TextureRect = _quick_icons.get(id, null) as TextureRect
		if icon == null:
			continue
		var stem: String = cfg["icon"]
		if id == "日供":
			var 可领: bool = true
			if is_instance_valid(Game) and Game.has_method("日供_今日可领"):
				可领 = bool(Game.日供_今日可领())
			stem = "entry_qiandao_36" if 可领 else "entry_qiandao_36_done"
		icon.texture = UITheme.load_hd_icon(stem)

# 隐藏UI开关：仅图标，无底框无文字，放在声望下方紧邻框体
func _build_eye() -> void:
	var sz: float = 22.0   # 按钮热区大小（稍大一点，更容易点击）
	var icon_sz: float = 18.0  # 图标视觉大小
	var cx: float = 440.0  # 对齐声望图标中心（440）
	var x: float = cx - sz * 0.5
	var btn := Button.new()
	btn.name = "HideUIBtn"
	btn.flat = true
	btn.text = ""
	_place(btn, x, 84.0, sz, sz)  # y=84，完全在资源栏下方（CONTAINER_H=84）
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.z_index = 1000  # 设置很高的z_index，确保在最上层可点击
	var empty_sb := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("pressed", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)
	btn.pressed.connect(_on_hide_ui_pressed)

	var eye_icon := TextureRect.new()
	eye_icon.name = "EyeIcon"
	eye_icon.texture = UITheme.load_hd_icon("ui_hide_36")
	eye_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	eye_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 图标居中显示在按钮内，比按钮稍小，视觉上更精致
	var icon_x: float = (sz - icon_sz) * 0.5
	var icon_y: float = (sz - icon_sz) * 0.5
	_place(eye_icon, icon_x, icon_y, icon_sz, icon_sz)
	eye_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(eye_icon)

	# 添加到 _scene_root 中（永远可见，不会被 _chrome 的隐藏影响）
	_scene_root.add_child(btn)

# ───────── helper ─────────
func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	var s: float = UITheme.UI_SCALE
	c.layout_mode = 0
	c.offset_left = x * s
	c.offset_top = y * s
	c.offset_right = (x + w) * s
	c.offset_bottom = (y + h) * s
	c.size = Vector2(w * s, h * s)

func _mk_label_in(parent: Control, nm: String, txt: String, x: float, y: float, w: float, h: float,
		font_size: int, color: Color, bold: bool,
		align_h: int, align_v: int, shadow: bool) -> Label:
	var lbl := Label.new()
	lbl.name = nm
	lbl.text = txt
	_place(lbl, x, y, w, h)
	lbl.horizontal_alignment = align_h
	lbl.vertical_alignment = align_v
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = true
	var fsz: int = int(round(float(font_size) * UITheme.UI_SCALE))
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

# ───────── 交互 ─────────
func _on_entry_pressed(entry_id: String) -> void:
	entry_selected.emit(entry_id)

func _on_hide_ui_pressed() -> void:
	_hidden_ui = !_hidden_ui
	if _chrome != null:
		_chrome.visible = !_hidden_ui
	hide_ui_requested.emit(_hidden_ui)

func set_chrome_visible(visible: bool) -> void:
	if _chrome != null and is_instance_valid(_chrome):
		_chrome.visible = visible

# ───────── 只读刷新 ─────────
func refresh() -> void:
	_apply_equipped_skin()
	_refresh_quick_icons()
	_refresh_red_dots()

func _apply_equipped_skin() -> void:
	if _bg == null:
		return
	var skin_id: String = "taixu_yunhai"
	if is_instance_valid(Game):
		var raw = Game.get("当前皮肤")
		if raw != null:
			skin_id = String(raw)
	var path: String = SKIN_BG.get(skin_id, "res://art/backgrounds/home_bg_sect_a.png")
	var tex: Texture2D = _load_bg_texture(path)
	if tex == null:
		tex = _load_bg_texture("res://art/backgrounds/home_bg_sect_a.png")
	if tex == null:
		return
	_bg.texture = tex
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

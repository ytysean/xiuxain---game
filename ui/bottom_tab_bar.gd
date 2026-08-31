extends Control

# 底部主导航（01 屏画布 v5 1:1 复刻 · Ardot 2:115~2:126，1080×1920 实机基准）。
# 坐标唯一数据源 = compose_v5_framed.py 1080p 实测值，按 UI_SCALE=2.25 反推为**本地坐标**。
# 本控件锚定于屏幕底部，高度 UITheme.TAB_H=215px；本地 y=0 对应屏幕 y=1705。
# 5 Tab 均分 460 逻辑宽；选中态 = 122×122 金环 + 底部金指示线 + 108px 图标不透明；
# 未选中 = 108px 图标 α0.5 + 暗青底；标签统一 25px 白粗体置底。

signal tab_selected(tab_id: String)

const TABS: Array = ["宗门", "弟子", "殿阁", "历练", "纪事"]

# Tab → 图标 stem（art/icons/hd/ 下金边高清图）
const TAB_ICON_STEM: Dictionary = {
	"宗门": "tab_sect",
	"弟子": "tab_disciple",
	"殿阁": "tab_building",
	"历练": "tab_explore",
	"纪事": "tab_chronicle",
}

# v5 定稿（进一步收窄高度）
const TAB_BAR_X: float = 20.0       # 左边距
const TAB_BAR_Y: float = 0.0            # 本地顶部
const TAB_BAR_W: float = 440.0          # 收窄宽度
const TAB_BAR_H: float = 80.0      # 进一步降低高度
const TAB_BAR_R: float = 16.0           # 36 / 2.25
const TAB_BAR_BORDER: float = 1.777778  # 4 / 2.25
const TAB_ITEM_W: float = 88.0          # 440 / 5

const ICON_DIA: float = 42.0            # 缩小图标
const ICON_CENTER_Y: float = 35.0  # 调整图标Y坐标
const SEL_RING_DIA: float = 48.0   # 缩小选中金环
const SEL_RING_W: float = 2.222222      # 5 / 2.25
const IND_Y: float = 62.0          # 调整指示线Y坐标
const IND_W: float = 17.777778          # 40 / 2.25
const IND_H: float = 3.111111           # 7 / 2.25
const LBL_CENTER_Y: float = 58.0   # 调整标签Y坐标
const LBL_H: float = 11.111111          # 25 / 2.25
const LBL_FONT: int = 10                # 稍微缩小字体

var _selected: String = "宗门"
var _tab_icons: Dictionary = {}        # id -> TextureRect
var _tab_rings: Dictionary = {}        # id -> Panel（选中金环）
var _tab_inds: Dictionary = {}         # id -> ColorRect（底部金指示线）
var _tab_labels: Dictionary = {}       # id -> Label

func _ready() -> void:
	var tab_h: float = UITheme.TAB_H
	# BOTTOM_WIDE 锚定：贴屏幕底部，高度由 UITheme.TAB_H 决定
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = -tab_h
	offset_right = 0.0
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(0, tab_h)

	_build()
	select(TABS[0])

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bg()
	for i in range(TABS.size()):
		_build_tab(TABS[i], i)

func _build_bg() -> void:
	var bg := Panel.new()
	bg.name = "TabBarBg"
	_place(bg, TAB_BAR_X, TAB_BAR_Y, TAB_BAR_W, TAB_BAR_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.C01_TAB_BAR_BG
	sb.border_color = UITheme.C01_TEXT_GOLD
	sb.set_corner_radius_all(int(round(TAB_BAR_R * UITheme.UI_SCALE)))
	sb.set_border_width_all(int(round(TAB_BAR_BORDER * UITheme.UI_SCALE)))
	sb.set_content_margin_all(0)
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)

func _build_tab(id: String, i: int) -> void:
	var x: float = TAB_BAR_X + float(i) * TAB_ITEM_W
	var cx: float = x + TAB_ITEM_W * 0.5
	var active: bool = (id == _selected)

	# 选中态金环（仅选中可见）
	var ring := Panel.new()
	ring.name = "Ring_" + id
	var ring_x: float = cx - SEL_RING_DIA * 0.5
	var ring_y: float = ICON_CENTER_Y - SEL_RING_DIA * 0.5
	_place(ring, ring_x, ring_y, SEL_RING_DIA, SEL_RING_DIA)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = active
	var ring_sb := StyleBoxFlat.new()
	ring_sb.bg_color = Color(0, 0, 0, 0)
	ring_sb.border_color = UITheme.C01_TEXT_GOLD
	ring_sb.set_corner_radius_all(int(round(SEL_RING_DIA * 0.5 * UITheme.UI_SCALE)))
	ring_sb.set_border_width_all(int(round(SEL_RING_W * UITheme.UI_SCALE)))
	ring_sb.set_content_margin_all(0)
	ring.add_theme_stylebox_override("panel", ring_sb)
	add_child(ring)
	_tab_rings[id] = ring

	# Tab 图标：108px 高清金边图，未选中半透明
	var icon := TextureRect.new()
	icon.name = "Icon_" + id
	var icon_x: float = cx - ICON_DIA * 0.5
	var icon_y: float = ICON_CENTER_Y - ICON_DIA * 0.5
	_place(icon, icon_x, icon_y, ICON_DIA, ICON_DIA)
	icon.texture = UITheme.load_hd_icon(TAB_ICON_STEM.get(id, "") + "_36")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1, 1, 1, 1.0 if active else 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	_tab_icons[id] = icon

	# 底部金指示线（仅选中态可见）
	var ind := ColorRect.new()
	ind.name = "Indicator_" + id
	var ind_x: float = cx - IND_W * 0.5
	_place(ind, ind_x, IND_Y, IND_W, IND_H)
	ind.color = UITheme.C01_TEXT_GOLD
	ind.visible = active
	ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ind)
	_tab_inds[id] = ind

	# 标签 25px 白粗体
	var lbl := Label.new()
	lbl.name = "Label_" + id
	var lbl_y: float = LBL_CENTER_Y - LBL_H * 0.5
	_place(lbl, x, lbl_y, TAB_ITEM_W, LBL_H)
	lbl.text = id
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_label_style(lbl, active)
	add_child(lbl)
	_tab_labels[id] = lbl

	# 透明点击热区
	var btn := Button.new()
	btn.name = "Hitbox_" + id
	btn.flat = true
	btn.text = ""
	_place(btn, x, TAB_BAR_Y, TAB_ITEM_W, TAB_BAR_H)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_tab_pressed.bind(id))
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	add_child(btn)

func _apply_label_style(lbl: Label, active: bool) -> void:
	var fsz: int = int(round(float(LBL_FONT) * UITheme.UI_SCALE))
	UITheme.apply_title_font_sized(lbl, fsz)
	lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)

func select(tab_id: String) -> void:
	if not (tab_id in TABS):
		return
	var prev: String = _selected
	_selected = tab_id
	if prev != tab_id:
		_apply_state(prev, false)
	_apply_state(tab_id, true)
	tab_selected.emit(tab_id)

func get_selected() -> String:
	return _selected

func _apply_state(id: String, active: bool) -> void:
	var ring: Panel = _tab_rings.get(id, null)
	if ring != null:
		ring.visible = active

	var icon: TextureRect = _tab_icons.get(id, null)
	if icon != null:
		icon.modulate = Color(1, 1, 1, 1.0 if active else 0.5)

	var ind: ColorRect = _tab_inds.get(id, null)
	if ind != null:
		ind.visible = active

	var lbl: Label = _tab_labels.get(id, null)
	if lbl != null:
		_apply_label_style(lbl, active)

func _on_tab_pressed(tab_id: String) -> void:
	select(tab_id)

func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	var s: float = UITheme.UI_SCALE
	c.layout_mode = 0
	c.offset_left = x * s
	c.offset_top = y * s
	c.offset_right = (x + w) * s
	c.offset_bottom = (y + h) * s
	c.size = Vector2(w * s, h * s)

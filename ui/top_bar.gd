extends Control

# 圆形头像遮罩 shader（顶栏宗主头像裁圆用）
const AVATAR_MASK_SHADER: Shader = preload("res://ui/avatar_circle_mask.gdshader")

# 点击「宗门名 + Lv」区域 → 唤起宗主详情页（全屏二级页）；纯 UI 入口，零玩法/战斗触碰。
signal 宗主详情请求
signal 消息中心请求

# 顶部资源栏（01 屏画布 v5 1:1 复刻 · Ardot 2:55/2:181，1080×1920 实机基准）。
# 坐标唯一数据源 = compose_v5_framed.py 中 1080p 实测值，本文件按 UI_SCALE=2.25 反推为逻辑单位。
# 全部色值走 UITheme.C01_* token，零裸色字面量。
# S1 红线：资源数值只读 Game Autoload，绝不写 GameState / 玩法 / 战斗逻辑。

const CONTAINER_H: float = 84.0   # 含 22px 顶边距：167 + 22 = 189 → /2.25

# v5 顶部资源栏面板：移到屏幕顶部边缘，收窄宽度
const PANEL_X: float = 12.0
const PANEL_Y: float = 0.0
const PANEL_W: float = 456.0
const PANEL_H: float = 70.0
const PANEL_R: float = 14.222222
const PANEL_BORDER: float = 0.888889

# 左身份区：宗门徽记 + 宗门名 + Lv（配合新框体位置调整）
const AVATAR_CX: float = 37.777778
const AVATAR_CY: float = 35.0
const AVATAR_DIA: float = 38.0
const AVATAR_RING_DIA: float = 52.0
const AVATAR_RING_BORDER: float = 2.222222
const SECT_NAME_X: float = 68.0
const SECT_NAME_Y: float = 16.0
const SECT_NAME_W: float = 160.0
const SECT_NAME_H: float = 19.0
const SECT_NAME_SIZE: int = 18
const LEVEL_Y: float = 40.0
const LEVEL_SIZE: int = 11
const FALLBACK_宗门名: String = "太玄宗"

# 中历匾额：配合新框体位置调整，缩小宽度避免与资源栏重叠
const CAL_X: float = 149.777778
const CAL_Y: float = 9.0
const CAL_W: float = 105.0
const CAL_H: float = 52.0
const CAL_R: float = 9.777778
const CAL_BORDER: float = 0.888889
const CAL_LINE1_Y: float = 25.0
const CAL_LINE1_SIZE: int = 12
const CAL_LINE2_Y: float = 43.0
const CAL_LINE2_SIZE: int = 8
const FALLBACK_CALENDAR1: String = "太玄 三年 · 五月"
const FALLBACK_CALENDAR2: String = "午时 · 宗门日程"

# 右资源区：4 卡竖排（图标-数值 2 层，均居中于卡）
# 调整位置避免图标和文字重叠
const RES_ICON_CENTER_Y: float = 28.0       # 图标居上
const RES_VAL_CENTER_Y: float = 48.0         # 数值居下
const RESOURCES: Array = [
	{"name": "灵石", "field": "灵石", "prod_key": ""},
	{"name": "灵气", "field": "灵气", "prod_key": "lingtian"},
	{"name": "灵植", "field": "灵草", "prod_key": "lingtian"},
	{"name": "香火", "field": "香火值", "prod_key": ""},
]
const RES_ICON_STEM: Dictionary = {
	"灵石": "res_lingshi",
	"灵气": "res_lingqi",
	"灵植": "res_lingzhi",
	"香火": "res_xianghuo",
}
const RES_CX: Array = [278.0, 320.0, 362.0, 404.0]  # 4个资源，间距42px，左移避免与时间框重叠，右移确保第4个图标完整显示
const RES_CY: float = 18.0  # 资源图标Y坐标（调整为与面板居中）
const RES_DIA: float = 22.0  # 图标直径
const RES_NAME_OFFSET: float = 14.0  # 文字中心在 cy+14
const RES_VAL_OFFSET: float = 28.0  # 数值中心在 cy+28
const RES_SLOT_W: float = 50.0   # 资源槽宽度
const RES_SLOT_H: float = 70.0
const RES_FONT: int = 10          # 数值字体大小

var _res_values: Dictionary = {}   # name -> 数值 Label
var _res_buttons: Dictionary = {}    # name -> 点击热区 Button
var _sect_name_lbl: Label = null
var _level_lbl: Label = null
var _calendar1_lbl: Label = null
var _calendar2_lbl: Label = null
var _detail_popup: Control = null    # 资源详情弹窗（懒加载）
var _avatar_icon: TextureRect = null   # 顶部宗徽图（创建宗门后由 refresh_avatar 替换为玩家选定的宗主头像）
var _popup_instance: Control = null    # 头像选择弹窗（预热常驻实例，零加载延迟）
var _消息按钮: Button = null          # S56 消息中心入口按钮
var _消息未读标签: Label = null       # S56 消息未读数标签

func _ready() -> void:
	# 顶栏容器：占屏幕顶部 189px 可视区（含 22px 上边距）
	var bar_h: float = CONTAINER_H * UITheme.UI_SCALE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = bar_h
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_END
	custom_minimum_size = Vector2(0, bar_h)

	_build()
	refresh()
	_预热弹窗()

# ───────── 构建 ─────────
func _build() -> void:
	_build_panel()
	_build_avatar()
	_build_calendar()
	_build_resources()
	_build_message_button()

func _build_panel() -> void:
	var bg := Panel.new()
	bg.name = "BG"
	_place(bg, PANEL_X, PANEL_Y, PANEL_W, PANEL_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.C01_PANEL_A
	sb.border_color = UITheme.C01_LINE_GOLD
	sb.set_corner_radius_all(int(round(PANEL_R * UITheme.UI_SCALE)))
	sb.set_border_width_all(int(round(PANEL_BORDER * UITheme.UI_SCALE)))
	sb.set_content_margin_all(0)
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)

func _build_avatar() -> void:
	# 头像金环：直径 104px/2.25，5px 金边，透明底
	var ring := Panel.new()
	ring.name = "AvatarRing"
	var ring_x: float = AVATAR_CX - AVATAR_RING_DIA * 0.5
	var ring_y: float = AVATAR_CY - AVATAR_RING_DIA * 0.5
	_place(ring, ring_x, ring_y, AVATAR_RING_DIA, AVATAR_RING_DIA)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = UITheme.C01_TEXT_GOLD
	sb.set_corner_radius_all(int(AVATAR_RING_DIA * UITheme.UI_SCALE / 2.0))
	sb.set_border_width_all(int(AVATAR_RING_BORDER * UITheme.UI_SCALE))
	sb.set_content_margin_all(0)
	ring.add_theme_stylebox_override("panel", sb)
	add_child(ring)

	# 宗门徽记：默认金边高清图标（创建宗门前/无存档头像时使用）；创建宗门后由 refresh_avatar 替换为玩家选定头像纹理。
	_avatar_icon = TextureRect.new()
	_avatar_icon.name = "AvatarIcon"
	_avatar_icon.texture = UITheme.load_hd_icon("avatar_sect_36")
	_avatar_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_x: float = AVATAR_CX - AVATAR_RING_DIA * 0.5
	var icon_y: float = AVATAR_CY - AVATAR_RING_DIA * 0.5
	_place(_avatar_icon, icon_x, icon_y, AVATAR_RING_DIA, AVATAR_RING_DIA)
	_avatar_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 圆形遮罩：裁四角成圆框（AtlasTexture 已取胸像居中段，shader 仅裁方形边缘）
	var 头像材质 := ShaderMaterial.new()
	头像材质.shader = AVATAR_MASK_SHADER
	_avatar_icon.material = 头像材质
	add_child(_avatar_icon)

	# 头像底层柔影盘：径向渐变阴影（中心 45% 黑 → 边缘透明），直径略大于头像圆、向下偏移 2 UI，
	# 制造「头像嵌在背景里」的柔光投影。比纯实心半透黑圆更自然，避免"贴了个黑盘"的违和感。
	var 阴影盘 := TextureRect.new()
	阴影盘.name = "AvatarShadow"
	var 阴影直径: float = AVATAR_RING_DIA + 4.0
	var 阴影x: float = AVATAR_CX - 阴影直径 * 0.5
	var 阴影y: float = AVATAR_CY - 阴影直径 * 0.5 + 2.0
	阴影盘.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	阴影盘.stretch_mode = TextureRect.STRETCH_SCALE
	阴影盘.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 阴影渐变 := Gradient.new()
	阴影渐变.set_color(0, Color(0, 0, 0, 0.45))
	阴影渐变.set_color(1, Color(0, 0, 0, 0))
	var 阴影贴图 := GradientTexture2D.new()
	阴影贴图.gradient = 阴影渐变
	阴影贴图.fill = GradientTexture2D.FILL_RADIAL
	阴影贴图.fill_from = Vector2(0.5, 0.5)
	阴影贴图.fill_to = Vector2(1.0, 0.5)
	阴影贴图.width = int(阴影直径 * UITheme.UI_SCALE)
	阴影贴图.height = int(阴影直径 * UITheme.UI_SCALE)
	阴影盘.texture = 阴影贴图
	_place(阴影盘, 阴影x, 阴影y, 阴影直径, 阴影直径)
	add_child(阴影盘)

	# 点击热区：覆盖头像，唤起头像选择弹窗
	var hit := Button.new()
	hit.name = "AvatarHit"
	hit.flat = true
	hit.text = ""
	var hx: float = AVATAR_CX - AVATAR_RING_DIA * 0.5
	var hy: float = AVATAR_CY - AVATAR_RING_DIA * 0.5
	_place(hit, hx, hy, AVATAR_RING_DIA, AVATAR_RING_DIA)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	var 空样式 := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", 空样式)
	hit.add_theme_stylebox_override("pressed", 空样式)
	hit.add_theme_stylebox_override("hover", 空样式)
	hit.add_theme_stylebox_override("focus", 空样式)
	hit.pressed.connect(_on_avatar_pressed)
	add_child(hit)

	# 宗门名
	_sect_name_lbl = _mk_label("SectName", SECT_NAME_X, SECT_NAME_Y, SECT_NAME_W, SECT_NAME_H,
		SECT_NAME_SIZE, UITheme.C01_TEXT_PRIMARY, true,
		HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	# Lv.等级（青绿）
	_level_lbl = _mk_label("SectLevel", SECT_NAME_X, LEVEL_Y, SECT_NAME_W, 14.0,
		LEVEL_SIZE, UITheme.C01_TEXT_JADE, true,
		HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)

	# 点击热区：覆盖宗门名 + Lv，唤起宗主详情页
	var name_hit := Button.new()
	name_hit.name = "NameHit"
	name_hit.flat = true
	name_hit.text = ""
	_place(name_hit, 66.0, 20.0, 180.0, 46.0)
	name_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	var 空样 := StyleBoxEmpty.new()
	name_hit.add_theme_stylebox_override("normal", 空样)
	name_hit.add_theme_stylebox_override("pressed", 空样)
	name_hit.add_theme_stylebox_override("hover", 空样)
	name_hit.add_theme_stylebox_override("focus", 空样)
	name_hit.pressed.connect(_on_sect_name_pressed)
	add_child(name_hit)

	# z-order 重排（2026-08-20）：确保 AvatarShadow 在最底层，让头像盖在柔影之上而不是反过来被柔影压暗。
	# 控制子节点顺序：[AvatarShadow, _avatar_icon, AvatarHit, ...]
	if 阴影盘 != null:
		move_child(阴影盘, 0)

func _build_calendar() -> void:
	var panel := Panel.new()
	panel.name = "Calendar"
	_place(panel, CAL_X, CAL_Y, CAL_W, CAL_H)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.C01_PANEL_LIGHT
	sb.border_color = UITheme.C01_TEXT_GOLD
	sb.set_corner_radius_all(int(round(CAL_R * UITheme.UI_SCALE)))
	sb.set_border_width_all(int(round(CAL_BORDER * UITheme.UI_SCALE)))
	sb.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	# 行高各占一半，保证两行均居中
	_calendar1_lbl = _mk_label_in(panel, "CalLine1", FALLBACK_CALENDAR1,
		0.0, 0.0, CAL_W, CAL_H * 0.5,
		CAL_LINE1_SIZE, UITheme.C01_TEXT_GOLD, true,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_calendar2_lbl = _mk_label_in(panel, "CalLine2", FALLBACK_CALENDAR2,
		0.0, CAL_H * 0.5, CAL_W, CAL_H * 0.5,
		CAL_LINE2_SIZE, UITheme.C01_TEXT_TERTIARY, false,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)

func _build_resources() -> void:
	for i in range(RESOURCES.size()):
		var cfg: Dictionary = RESOURCES[i]
		var nm: String = cfg["name"]
		var cx: float = RES_CX[i]
		var slot_x: float = cx - RES_SLOT_W * 0.5

		# 点击热区：覆盖整卡
		var entry := Button.new()
		entry.name = "EntryBtn_" + nm
		entry.flat = true
		entry.text = ""
		_place(entry, slot_x, PANEL_Y, RES_SLOT_W, RES_SLOT_H)
		entry.mouse_filter = Control.MOUSE_FILTER_STOP
		var empty_sb := StyleBoxEmpty.new()
		entry.add_theme_stylebox_override("normal", empty_sb)
		entry.add_theme_stylebox_override("pressed", empty_sb)
		entry.add_theme_stylebox_override("hover", empty_sb)
		entry.add_theme_stylebox_override("focus", empty_sb)
		entry.pressed.connect(_on_resource_pressed.bind(nm))
		add_child(entry)
		_res_buttons[nm] = entry

		# 图标（居上）
		var icon_stem: String = RES_ICON_STEM.get(nm, "")
		if icon_stem != "":
			var icon := TextureRect.new()
			icon.name = "Icon_" + nm
			icon.texture = UITheme.load_hd_icon(icon_stem + "_36")
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var ix: float = cx - RES_DIA * 0.5
			var iy: float = RES_ICON_CENTER_Y - RES_DIA * 0.5
			_place(icon, ix, iy, RES_DIA, RES_DIA)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(icon)

		# 数值（居下）：Label 宽度改为 RES_DIA+12（确保4位数显示，避免过宽导致重叠），
		# 基于 cx 水平居中对齐图标，避免整卡宽导致的视觉错位
		var label_w: float = RES_DIA + 12.0
		var label_x: float = cx - label_w * 0.5  # 基于cx居中，与图标对齐
		var val_lbl: Label = _mk_label("Val_" + nm,
			label_x, RES_VAL_CENTER_Y - 6.0, label_w, 12.0,
			RES_FONT, UITheme.C01_TEXT_TERTIARY, true,
			HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
		val_lbl.text = "0"
		val_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		val_lbl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		val_lbl.clip_text = false
		_res_values[nm] = val_lbl

# S56：消息中心入口按钮
func _build_message_button() -> void:
	# 消息按钮位置：资源栏右侧
	var btn_x: float = 440.0
	var btn_y: float = 10.0
	var btn_w: float = 36.0
	var btn_h: float = 50.0

	_消息按钮 = Button.new()
	_消息按钮.name = "MessageBtn"
	_消息按钮.flat = true
	_消息按钮.text = "📜"
	_消息按钮.add_theme_font_size_override("font_size", int(round(20.0 * UITheme.UI_SCALE)))
	_place(_消息按钮, btn_x, btn_y, btn_w, btn_h)
	_消息按钮.mouse_filter = Control.MOUSE_FILTER_STOP
	var 空样式 := StyleBoxEmpty.new()
	_消息按钮.add_theme_stylebox_override("normal", 空样式)
	_消息按钮.add_theme_stylebox_override("pressed", 空样式)
	_消息按钮.add_theme_stylebox_override("hover", 空样式)
	_消息按钮.add_theme_stylebox_override("focus", 空样式)
	_消息按钮.pressed.connect(_on_message_pressed)
	add_child(_消息按钮)

	# 未读消息数红点
	_消息未读标签 = Label.new()
	_消息未读标签.name = "MsgUnread"
	_消息未读标签.text = ""
	_消息未读标签.add_theme_font_size_override("font_size", int(round(10.0 * UITheme.UI_SCALE)))
	_消息未读标签.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_消息未读标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_消息未读标签.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_消息未读标签, btn_x + btn_w - 12, btn_y - 2, 16.0, 16.0)
	_消息未读标签.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_消息未读标签)

	# 刷新未读数
	_refresh_message_unread()

# 刷新消息未读数
func _refresh_message_unread() -> void:
	if _消息未读标签 == null:
		return
	if not is_instance_valid(Game):
		_消息未读标签.text = ""
		return
	var 未读数: int = Game.消息系统.获取总未读数()
	if 未读数 > 0:
		_消息未读标签.text = str(min(未读数, 99))
		# 红色背景
	else:
		_消息未读标签.text = ""

# 点击消息按钮
func _on_message_pressed() -> void:
	消息中心请求.emit()

# ───────── helper ─────────
func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	var s: float = UITheme.UI_SCALE
	c.layout_mode = 0
	c.offset_left = x * s
	c.offset_top = y * s
	c.offset_right = (x + w) * s
	c.offset_bottom = (y + h) * s
	c.size = Vector2(w * s, h * s)

func _mk_label(nm: String, x: float, y: float, w: float, h: float,
		font_size: int, color: Color, bold: bool,
		align_h: int = HORIZONTAL_ALIGNMENT_LEFT,
		align_v: int = VERTICAL_ALIGNMENT_CENTER) -> Label:
	return _mk_label_in(self, nm, "", x, y, w, h, font_size, color, bold, align_h, align_v)

func _mk_label_in(parent: Control, nm: String, txt: String, x: float, y: float, w: float, h: float,
		font_size: int, color: Color, bold: bool,
		align_h: int, align_v: int) -> Label:
	var lbl := Label.new()
	lbl.name = nm
	lbl.text = txt
	_place(lbl, x, y, w, h)
	lbl.horizontal_alignment = align_h
	lbl.vertical_alignment = align_v
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = false
	var fsz: int = int(round(float(font_size) * UITheme.UI_SCALE))
	if bold:
		UITheme.apply_title_font_sized(lbl, fsz)
	else:
		UITheme.apply_body_font_sized(lbl, fsz)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl

# ───────── 只读刷新 ─────────
func refresh() -> void:
	refresh_resources()
	_refresh_identity()
	_refresh_calendar()
	refresh_avatar()  # 创立宗门后/读档后，玩家头像纹理即刻同步到顶栏徽记
	_refresh_message_unread()  # S56 刷新消息未读数

# 顶栏头像刷新：按 Game.宗主头像 取玩家选定头像纹理；缺省回落宗门徽记默认金边图标。
# 仅展示，零玩法/战斗触碰——玩家档案更换头像时由 game_ui._refresh_all_pages 批量触发。

# 圆形头像纹理包装：AtlasTexture 取「顶 1:1 段」（头顶→腰部），保证圆框内胸像完整（不切喉/切脚），
# 再交由圆形 mask shader 裁四角。仅展示用途，零玩法/战斗触碰。
func _取圆框纹理(原图: Texture2D) -> Texture2D:
	if 原图 == null or 原图.get_width() <= 0:
		return UITheme.load_hd_icon("avatar_sect_36")
	var w: float = float(原图.get_width())
	var h: float = float(原图.get_height())
	var at := AtlasTexture.new()
	at.atlas = 原图
	# 居中裁 w×w 正方形（与 popup._圆形化 一致），避免顶部裁切导致圆框内胸像偏上
	var y0: float = (h - w) * 0.5
	y0 = max(0.0, y0)
	at.region = Rect2(0.0, y0, w, w)
	at.filter_clip = true
	return at

func refresh_avatar() -> void:
	if _avatar_icon == null:
		return
	var 原图: Texture2D = null
	if is_instance_valid(Game) and Game.has_method("取宗主头像纹理"):
		原图 = Game.取宗主头像纹理()  # 缺省参 = Game.宗主头像
	_avatar_icon.texture = _取圆框纹理(原图)

# 点击头像区 → 唤起头像选择弹窗（全屏暗底模态）。仅 UI 入口，零玩法/战斗触碰。
func _on_avatar_pressed() -> void:
	_open_frame_select()

# 点击宗门名 → 唤起宗主详情页（全屏二级页）；纯 UI 入口，零玩法/战斗触碰。
func _on_sect_name_pressed() -> void:
	宗主详情请求.emit()

func _open_frame_select() -> void:
	if not is_instance_valid(Game):
		return
	if not is_instance_valid(_popup_instance):
		_预热弹窗()
		if not is_instance_valid(_popup_instance):
			return
	if _popup_instance.visible:
		_popup_instance.关闭()
	else:
		_popup_instance.唤起()

# 预热常驻弹窗：load 脚本 → Control.new() → set_script → 挂 main root → 存 _popup_instance。
# 失败时 push_error 兜底，_open_frame_select 会感知 _popup_instance 无效并再次尝试。
func _预热弹窗() -> void:
	var 脚本 = load("res://ui/avatar_select_popup.gd")
	if 脚本 == null:
		push_error("avatar_select_popup.gd 加载失败")
		return
	# CanvasLayer 容器：永远在 Control 子树之上，彻底遮住所有 z_index<=0 的 UI
	var popup层 := CanvasLayer.new()
	popup层.name = "AvatarFramePopupLayer"
	popup层.layer = 100  # 高 layer 值，确保盖住所有默认 CanvasLayer
	# 容器 Control 占满 viewport（让 popup 内 _shade 满屏生效）
	var 容器 := Control.new()
	容器.name = "Container"
	容器.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	容器.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup层.add_child(容器)
	add_child(popup层)
	_popup_instance = Control.new()
	_popup_instance.set_script(脚本)
	_popup_instance.visible = false
	容器.add_child(_popup_instance)
	if _popup_instance.has_signal("应用并关闭"):
		_popup_instance.应用并关闭.connect(_on_frame_applied)
	# 内置信号兜底（关键）：自定义脚本信号在动态 set_script 后偶发连不上，
	# 改用 Control 内置 visibility_changed，弹窗由显示切到隐藏即刷新头像，彻底可靠。
	_popup_instance.visibility_changed.connect(_on_popup_visibility_changed)

# 弹窗确认（内部已调用 Game setter 写入当前头像）后刷新顶栏头像。
# 关键双保险：信号链 → 本节点 refresh_avatar；同时 call_deferred 沿父链触发 game_ui.refresh_all
# 解决 Godot 4.7 动态 set_script+connect 时序偶发的"弹窗关闭后主页头像仍是旧值"问题。
func _on_frame_applied() -> void:
	refresh_avatar()
	call_deferred("_兜底触发全局刷新")

# 沿父链向上找 game_ui（具有 refresh_all + _refresh_all_pages 方法的祖先节点）。
# 仅展示类刷新，零玩法/战斗触碰。
func _兜底触发全局刷新() -> void:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("refresh_all") and n.has_method("_refresh_all_pages"):
			n.refresh_all()
			return
		n = n.get_parent()

# 弹窗可见性变化（Control 内置 visibility_changed，不依赖脚本信号，100% 可靠）。
# 仅在弹窗由显示切到隐藏时刷新头像，杜绝"选完新头像主页不刷新"。
func _on_popup_visibility_changed() -> void:
	if not is_instance_valid(_popup_instance) or _popup_instance.visible:
		return
	call_deferred("refresh_avatar")

func _refresh_identity() -> void:
	if _sect_name_lbl != null:
		_sect_name_lbl.text = _read_text("宗门名", FALLBACK_宗门名)
	if _level_lbl != null:
		var lv: int = _read_level()
		_level_lbl.text = "Lv.%d" % lv

func _read_text(field: String, fallback: String) -> String:
	if not is_instance_valid(Game):
		return fallback
	var raw: Variant = Game.get(field)
	if raw == null:
		return fallback
	var s: String = str(raw).strip_edges()
	return fallback if s.is_empty() else s

func _read_level() -> int:
	if not is_instance_valid(Game):
		return 1
	var raw: Variant = Game.get("门派等级")
	if raw == null:
		return 1
	return max(1, int(raw))

func _refresh_calendar() -> void:
	if _calendar1_lbl == null or _calendar2_lbl == null:
		return
	var d: int = -1
	if is_instance_valid(Game):
		var raw = Game.get("累计游戏日")
		if raw != null:
			d = int(raw)
	if d < 0:
		_calendar1_lbl.text = FALLBACK_CALENDAR1
		_calendar2_lbl.text = FALLBACK_CALENDAR2
		return
	var y: int = int(d / 360) + 1
	var m: int = int((d % 360) / 30) + 1
	_calendar1_lbl.text = "太玄 %d年 · %d月" % [y, m]
	# 时辰：每 30 日分 12 时辰，每 2.5 日一时辰
	var 时辰表: Array = ["子时", "丑时", "寅时", "卯时", "辰时", "巳时", "午时", "未时", "申时", "酉时", "戌时", "亥时"]
	var hour_index: int = int((d % 30) / 2.5)
	hour_index = clampi(hour_index, 0, 11)
	_calendar2_lbl.text = "%s · 宗门日程" % 时辰表[hour_index]

func refresh_resources() -> void:
	if not is_instance_valid(Game):
		return
	for cfg in RESOURCES:
		var raw: Variant = Game.get(cfg["field"])
		var v: int = 0
		if raw != null:
			v = int(raw)
		var lbl: Label = _res_values.get(cfg["name"], null)
		if lbl != null:
			lbl.text = _format_value(v)

# 资源详情弹窗：点击资源槽后在其下方弹出小面板，仅显示月产。
func _on_resource_pressed(res_name: String) -> void:
	_show_resource_detail(res_name)

func _show_resource_detail(res_name: String) -> void:
	_close_resource_detail()

	var cfg: Dictionary = {}
	for c in RESOURCES:
		if c["name"] == res_name:
			cfg = c
			break
	if cfg.is_empty():
		return

	var prod_text: String = _production_text(res_name, cfg.get("prod_key", ""))

	# 透明遮罩：点击弹窗外关闭（几乎不可见）。
	var shade := ColorRect.new()
	shade.name = "DetailShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.01)
	shade.top_level = true
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	# 面板：140×44 逻辑尺寸，跟随点击资源槽正下方。
	var panel := Panel.new()
	panel.name = "DetailPanel"
	panel.top_level = true
	var pw: float = 140.0 * UITheme.UI_SCALE
	var ph: float = 44.0 * UITheme.UI_SCALE
	var btn: Button = _res_buttons.get(res_name, null)
	var px: float = 0.0
	var py: float = 0.0
	if btn != null and is_instance_valid(btn):
		var btn_pos: Vector2 = btn.global_position
		px = btn_pos.x + btn.size.x * 0.5 - pw * 0.5
		py = btn_pos.y + btn.size.y + 32.0 * UITheme.UI_SCALE  # 从4改为32，避开右上角隐藏UI图标
	else:
		var viewport: Vector2 = get_viewport_rect().size
		px = (viewport.x - pw) * 0.5
		py = viewport.y * 0.4
	var viewport: Vector2 = get_viewport_rect().size
	px = clampf(px, 8.0 * UITheme.UI_SCALE, viewport.x - pw - 8.0 * UITheme.UI_SCALE)
	py = clampf(py, PANEL_H * UITheme.UI_SCALE + 32.0 * UITheme.UI_SCALE, viewport.y - ph - 8.0 * UITheme.UI_SCALE)  # 最小值从4改为32，与y偏移一致
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	panel.add_theme_stylebox_override("panel",
		UITheme.make_panel_stylebox_flat(UITheme.COLOR_PANEL_BG, UITheme.COLOR_BORDER_GOLD, 8, 1))
	add_child(panel)

	var prod_lbl := Label.new()
	prod_lbl.name = "DetailProd"
	prod_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prod_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prod_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prod_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prod_lbl.text = prod_text
	UITheme.apply_body_font_sized(prod_lbl, int(round(12.0 * UITheme.UI_SCALE)))
	prod_lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	panel.add_child(prod_lbl)

	_detail_popup = panel
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_resource_detail()
	)

func _close_resource_detail() -> void:
	if _detail_popup != null and is_instance_valid(_detail_popup):
		var shade: Node = get_node_or_null("DetailShade")
		if shade != null and is_instance_valid(shade):
			shade.queue_free()
		_detail_popup.queue_free()
		_detail_popup = null

func _production_text(res_name: String, prod_key: String) -> String:
	if not is_instance_valid(Game) or prod_key == "":
		if res_name == "灵石":
			return "日产：由弟子供奉、坊市贸易与事件产出"
		return "日产：尚无对应产出统计"
	if not Game.has_method("预估殿阁产出"):
		return "日产：讯息未就绪"
	var v: int = Game.预估殿阁产出(prod_key)
	if res_name == "灵气":
		v = int(v * 0.5)
	return "日产：%s" % _format_value(v)

func _format_value(v: int) -> String:
	if v >= 10000:
		return "%0.1f万" % (float(v) / 10000.0)
	var s: String = str(abs(v))
	var out: String = ""
	var cnt: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if v < 0 else out

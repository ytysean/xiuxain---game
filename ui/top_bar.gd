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

# v5 顶部资源栏：P0-7 去面板化后「面板框」已退役（原 PANEL_X/W/R/BORDER），仅保留内容锚点。
const PANEL_Y: float = 0.0
const PANEL_H: float = 70.0

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
const FALLBACK_CALENDAR2: String = "午时 · 山门时课"

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

# 资源详情文案：点资源槽弹「是什么 + 怎么用 + 日产」。
const _RESOURCE_DESC: Dictionary = {
	"灵石": "宗门通用硬通货：延揽弟子、炼器炼丹、兴建殿阁、坊市贸易皆需。\n日产源于弟子供奉、坊市盈余与机缘事件。",
	"灵气": "天地灵气：弟子修炼、突破与布阵的根基。\n由灵田、聚灵阵持续产出，闭关时吸收更快。",
	"灵植": "灵田所产灵草灵药：炼丹与疗伤的核心材料。\n由司职弟子打理灵田自动收获。",
	"香火": "信众供奉之香火愿力：化为宗门气运与突破助力。\n道场宏扬、护佑苍生可增香火。",
}

var _res_values: Dictionary = {}   # name -> 数值 Label
var _res_buttons: Dictionary = {}    # name -> 点击热区 Button
var _sect_name_lbl: Label = null
var _level_lbl: Label = null
var _calendar1_lbl: Label = null
var _calendar2_lbl: Label = null
var _detail_popup: Control = null    # 资源详情弹窗（懒加载）
var _avatar_icon: TextureRect = null   # 顶部宗徽图（创建宗门后由 refresh_avatar 替换为玩家选定的宗主头像）
var _popup_instance: Control = null    # 头像选择弹窗（预热常驻实例，零加载延迟）
# 消息按钮几何（设计逻辑）。未读角标的宽度随位数变化，刷新时须按角标实际宽度重定位，
# 故提为类常量而不是 _build_message_button 的局部变量。
const MSG_BTN_X: float = 440.0
const MSG_BTN_Y: float = 10.0
const MSG_BTN_W: float = 36.0
const MSG_BTN_H: float = 50.0
# 图标显示直径（逻辑）。按钮本身只是热区，视觉主体是这枚图标。
# ★ 2026-09-16：直径 26 → 28、纵向中心由「按钮中心(35)」改为**对齐资源图标行(28)**。
#   实测（像素量化）：原落位比资源图标行低 7.7 逻辑，读起来像"沉在数值行里"；
#   资源块的整体中心虽是 35，但**图标行**在 28、数值行在 48，入口图标必须跟图标行成列。
const MSG_ICON_DIA: float = 28.0
const MSG_ICON_CX: float = MSG_BTN_X + MSG_BTN_W * 0.5
const MSG_ICON_CY: float = RES_ICON_CENTER_Y
# 未读角标：高 16 逻辑（≈12dp），落点 = 图标 45° 外沿再外扩 1 逻辑。
# 45° 处的径向分量 = R/√2 ≈ 0.707R ⇒ 角标**半压在图标右上角**，是大厂角标通用落点。
#
# ★ 右缘**固定**取按钮右缘（而非「图标 45° + 半宽」）：屏宽 480、按钮右缘 476，余量只有 4 逻辑；
#   若跟着图标直径漂，把图标调大一档就会把角标顶出屏幕。固定右缘后图标尺寸可自由调整。
#   取右缘而非圆心锚定，还兼顾「位数 1→2（9→99）时向左生长」——右缘不动才不会越界。
const MSG_DOT_SIZE: float = 16.0
const MSG_DOT_RIGHT: float = MSG_BTN_X + MSG_BTN_W - 2.0
const MSG_DOT_TOP: float = MSG_ICON_CY - MSG_ICON_DIA * 0.5 * 0.707 - MSG_DOT_SIZE * 0.5

var _消息按钮: Button = null          # S56 消息中心入口按钮
var _消息红点: Control = null          # S56 消息未读角标（数字红点：红胶囊 + 白字深描边）
var _消息红点呼吸: Tween = null        # 角标呼吸句柄（隐藏时必须 kill，否则循环叠加越闪越快）

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

	# ★ 2026-09-15 修（实机 bug：二级页「← 返回宗门」点了完全没反应）：
	#   本根节点原为默认 MOUSE_FILTER_STOP，而 CONTAINER_H(84 逻辑 = 189 物理) 比真实
	#   可见内容 (PANEL_H = 70 逻辑 = 157.5 物理) 高出 31.5px —— 这条**看不见的死带**
	#   把落在 y≈157~189 的所有点击全部吞掉。而二级页容器 offset_top = UITheme.TOPBAR_H(156)，
	#   各页自己的「返回」钮恰好贴在容器顶端 (y 156~222)，其中心 y≈189 正中这条死带
	#   ⇒ 实机表现 = 「返回点不动」。引擎拾取实测：点 (60,189) 的 hovered = TopBar(Control)。
	#   （52 个二级页审计中 20 页复现，直接 emit pressed 则全部正常关闭 ⇒ 信号链路无恙，
	#     纯粹是点击被根节点截胡。）
	#   本根节点是纯布局容器，自身不需要接收点击：真实热区 AvatarHit / NameHit /
	#   EntryBtn_* / 消息按钮 全部自带 MOUSE_FILTER_STOP，故根节点改 IGNORE 安全，
	#   多余高度不再吞事件。
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	# P0-7 去面板化：原「btn_frame 悬浮框」（描边 + 圆角 + 半透底 = 一块贴在场景上的深色板）
	#   → 「顶部 scrim 渐隐条」（无框、向下淡出，与背景自然融合）。
	#   依据：网易游戏学院《窗口界面设计规范》「避免场景很亮、底板很暗的尴尬」。
	var bg := TextureRect.new()
	bg.name = "BG"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gt := GradientTexture2D.new()
	gt.gradient = UITheme.建顶栏渐隐()
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	# 高度严格止于顶栏边界（PANEL_H×UI_SCALE ≈ 157px ≈ TOPBAR_H 156）—— 首页「宗门中枢」
	# 面板顶边在 168px，若 scrim 下探过深会把面板首行压暗（首版 PANEL_H+24 实测踩到）。
	_place(bg, 0.0, 0.0, 480.0, PANEL_H)
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
	sb.border_color = UITheme.获取金文字色()
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
	# 同一张宗主头像要服务两个显示档位（顶栏 117px / 弹窗预览 252~270px），
	# 单一 size_limit 无法同时匹配 ⇒ 交给 mipmap 按 LOD 自适应采样。
	# 纹理侧已开 mipmaps/generate=true；此处必须显式指定带 mipmap 的过滤，否则 mipmap 不生效。
	_avatar_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
		SECT_NAME_SIZE, UITheme.获取主文字色(), true,
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
	UITheme.应用九宫格(panel, "card_bg")  # P0-4：小卡材质（替代裸 StyleBoxFlat）
	add_child(panel)

	# 行高各占一半，保证两行均居中
	_calendar1_lbl = _mk_label_in(panel, "CalLine1", FALLBACK_CALENDAR1,
		0.0, 0.0, CAL_W, CAL_H * 0.5,
		CAL_LINE1_SIZE, UITheme.获取金文字色(), true,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_calendar2_lbl = _mk_label_in(panel, "CalLine2", FALLBACK_CALENDAR2,
		0.0, CAL_H * 0.5, CAL_W, CAL_H * 0.5,
		CAL_LINE2_SIZE, UITheme.获取弱文字色(), false,
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
			RES_FONT, UITheme.获取弱文字色(), true,
			HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
		val_lbl.text = "—"  # P0-6 续：占位统一「—」，刷新后按真实值覆盖
		val_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		val_lbl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		val_lbl.clip_text = false
		_res_values[nm] = val_lbl

# S56：消息中心入口按钮
func _build_message_button() -> void:
	_消息按钮 = Button.new()
	_消息按钮.name = "MessageBtn"
	_消息按钮.flat = true
	# ★ 2026-09-16：原为 `text = "◇"` 系统 emoji —— 灰白纸卷直接压在山水背景上，
	#   既无描边也无体积感，风格与全局金质图标体系脱节（emoji 随系统字体渲染，
	#   不同机型还各不相同）。改用项目已有的 `entry_feifuchuanxin_36`
	#   （「飞符传讯」入口图标，与传送讯中心同一语义、同一美术体系），零新资产。
	_消息按钮.text = ""
	_place(_消息按钮, MSG_BTN_X, MSG_BTN_Y, MSG_BTN_W, MSG_BTN_H)
	_消息按钮.mouse_filter = Control.MOUSE_FILTER_STOP
	var 空样式 := StyleBoxEmpty.new()
	_消息按钮.add_theme_stylebox_override("normal", 空样式)
	_消息按钮.add_theme_stylebox_override("pressed", 空样式)
	_消息按钮.add_theme_stylebox_override("hover", 空样式)
	_消息按钮.add_theme_stylebox_override("focus", 空样式)
	_消息按钮.pressed.connect(_on_message_pressed)
	add_child(_消息按钮)

	var icon := TextureRect.new()
	icon.name = "MsgIcon"
	icon.texture = UITheme.load_hd_icon("entry_feifuchuanxin_36")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(icon, MSG_ICON_CX - MSG_ICON_DIA * 0.5, MSG_ICON_CY - MSG_ICON_DIA * 0.5,
		MSG_ICON_DIA, MSG_ICON_DIA)
	add_child(icon)

	# 未读消息角标：走统一数字红点（红胶囊 + 白字深描边）。
	# ★ 旧实现是**纯白字 Label 且没有底色**（注释写着「红色背景」，但从未落地）⇒
	#   白字直接飘在亮色山水上，几乎读不出来，也不符合角标规范。
	_消息红点 = UITheme.make_red_dot_number(0, MSG_DOT_SIZE)
	_消息红点.name = "MsgUnread"
	_消息红点.visible = false
	_消息红点.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_消息红点)

	# 刷新未读数
	_refresh_message_unread()

# 刷新消息未读数（S56 角标 → 统一数字红点）
func _refresh_message_unread() -> void:
	if _消息红点 == null:
		return
	var 未读数: int = 0
	if is_instance_valid(Game) and Game.消息系统 != null:
		未读数 = int(Game.消息系统.获取总未读数())
	if 未读数 <= 0:
		_停呼吸消息角标()
		_消息红点.visible = false
		return
	# 先定量（位数变化会改胶囊宽度），再定落点，最后才播入场动画 ——
	# 动画需要以「最终尺寸」算轴心，顺序颠倒会让两位数角标从错误轴心弹出。
	UITheme.设置红点数量(_消息红点, 未读数)
	# 位数变化会改胶囊宽度（9 → 99 → 99+）⇒ 右缘锚定、向左生长，避免两位数时顶出屏幕右边界。
	_消息红点.position = Vector2(MSG_DOT_RIGHT * UITheme.UI_SCALE - _消息红点.size.x,
		MSG_DOT_TOP * UITheme.UI_SCALE)
	# 仅在「无 → 有」这一刻播入场动画：refresh() 每次全量刷新都会走到这里，
	# 无条件播动画会让角标随任意刷新反复弹跳。
	if not _消息红点.visible:
		_消息红点.visible = true
		UITheme.animate_red_dot_appear(_消息红点)
		# 有未读时角标轻微呼吸（1.0 ↔ 0.82）：数字角标是本作唯一的「持续提示」，
		# 只此一处，避免满屏红点一起闪。
		if _消息红点呼吸 == null or not _消息红点呼吸.is_valid():
			_消息红点呼吸 = UITheme.start_red_dot_breathe(_消息红点)

# 停呼吸并复位透明度：kill 后 Tween 会把 modulate.a 留在暗态，必须显式拉回 1.0。
func _停呼吸消息角标() -> void:
	if _消息红点呼吸 != null and _消息红点呼吸.is_valid():
		_消息红点呼吸.kill()
	_消息红点呼吸 = null
	if _消息红点 != null and is_instance_valid(_消息红点):
		_消息红点.modulate.a = 1.0

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

# 圆形头像纹理包装：AtlasTexture 取头部特写段，保证小尺寸圆框内也能看清人脸。
# 优先使用 game_state 的 per-avatar 裁切表（修正复杂头像脸中心偏移），未命中时回落默认。
# 再交由圆形 mask shader 裁四角。仅展示用途，零玩法/战斗触碰。
func _取圆框纹理(原图: Texture2D, 裁切: Dictionary = {}) -> Texture2D:
	if 原图 == null or 原图.get_width() <= 0:
		return UITheme.load_hd_icon("avatar_sect_36")
	var w: float = float(原图.get_width())
	var h: float = float(原图.get_height())
	var at := AtlasTexture.new()
	at.atlas = 原图
	# 2026-09-16：顶栏小头像改用头部特写裁切；
	# 优先使用 per-avatar 裁切表，未命中时回落 (0.5W, 0.325H, s=0.55W)。
	var cx: float = float(裁切.get("cx", 0.5))
	var cy: float = float(裁切.get("cy", 0.325))
	var s: float = float(裁切.get("s", 0.55))
	var 边长: float = w * s
	var x: float = w * cx - 边长 * 0.5
	var y: float = h * cy - 边长 * 0.5
	# 钳制在纹理边界内
	x = maxf(0.0, minf(x, w - 边长))
	y = maxf(0.0, minf(y, h - 边长))
	at.region = Rect2(x, y, 边长, 边长)
	at.filter_clip = true
	return at

func refresh_avatar() -> void:
	if _avatar_icon == null:
		return
	var 原图: Texture2D = null
	if is_instance_valid(Game) and Game.has_method("取宗主头像纹理"):
		原图 = Game.取宗主头像纹理()  # 缺省参 = Game.宗主头像
	var 裁切: Dictionary = {}
	if is_instance_valid(Game) and Game.has_method("取宗主头像裁切"):
		裁切 = Game.取宗主头像裁切()
	_avatar_icon.texture = _取圆框纹理(原图, 裁切)

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
		_level_lbl.text = "%d 品" % lv

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
	_calendar2_lbl.text = "%s · 山门时课" % 时辰表[hour_index]

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
			# P0-6 续：零值显示「—」而非「0」，避免首档无数据时"没做"的观感
			if v == 0:
				lbl.text = "—"
			else:
				# 数值滚动：只在数值真的变化时滚（UITween 内部对相等值直接返回）。
				# 首次从占位「—」滚上来，自带入场感；必须传 _format_value，
				# 否则滚动中段会在 "1,448" 与 "1449" 之间跳字。
				UITween.tween_number(lbl, v, 0.45, _format_value)

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

	var desc: String = _RESOURCE_DESC.get(res_name, "此乃宗门重要修行资粮。")
	var prod_text: String = _production_text(res_name, cfg.get("prod_key", ""))

	# 透明遮罩：点击弹窗外关闭
	var shade := ColorRect.new()
	shade.name = "DetailShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.01)
	shade.top_level = true
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	# 面板：跟随点击资源槽正下方（沿用既有安全区 clamp）
	var panel := Panel.new()
	panel.name = "DetailPanel"
	panel.top_level = true
	var pw: float = 280.0 * UITheme.UI_SCALE
	var ph: float = 160.0 * UITheme.UI_SCALE
	var btn: Button = _res_buttons.get(res_name, null)
	var px: float = 0.0
	var py: float = 0.0
	if btn != null and is_instance_valid(btn):
		var btn_pos: Vector2 = btn.global_position
		px = btn_pos.x + btn.size.x * 0.5 - pw * 0.5
		py = btn_pos.y + btn.size.y + 32.0 * UITheme.UI_SCALE
	else:
		var viewport0: Vector2 = get_viewport_rect().size
		px = (viewport0.x - pw) * 0.5
		py = viewport0.y * 0.4
	var viewport: Vector2 = get_viewport_rect().size
	px = clampf(px, 8.0 * UITheme.UI_SCALE, viewport.x - pw - 8.0 * UITheme.UI_SCALE)
	py = clampf(py, PANEL_H * UITheme.UI_SCALE + 32.0 * UITheme.UI_SCALE, viewport.y - ph - 8.0 * UITheme.UI_SCALE)
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	panel.add_theme_stylebox_override("panel",
		UITheme.make_panel_stylebox_flat(UITheme.获取面板底色(), UITheme.获取暗金边色(), UITheme.RADIUS_PANEL, 1))
	add_child(panel)

	# 内容：标题 + 说明 + 日产
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", int(round(8.0 * UITheme.UI_SCALE)))
	panel.add_child(vb)
	var tl := Label.new()
	tl.text = res_name
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_title_font_sized(tl, int(round(15.0 * UITheme.UI_SCALE)))
	tl.add_theme_color_override("font_color", UITheme.获取金文字色())
	vb.add_child(tl)
	var dl := Label.new()
	dl.text = desc
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_font_sized(dl, int(round(12.0 * UITheme.UI_SCALE)))
	dl.add_theme_color_override("font_color", UITheme.获取主文字色())
	vb.add_child(dl)
	var pl := Label.new()
	pl.text = prod_text
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_font_sized(pl, int(round(11.0 * UITheme.UI_SCALE)))
	pl.add_theme_color_override("font_color", UITheme.C01_TEXT_JADE)
	vb.add_child(pl)

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

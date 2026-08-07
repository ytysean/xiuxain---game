extends Control

# 宗门创建页（捏脸 v21）：三层叠放预览（robe底 + hair中 + feat脸顶）。
# v21 核心改进：① 图层数据分离——hair/features 存原始全图（九宫格），hair_t/features_t 存透明层（预览）
#               ② 图层重排序——feat脸层放最顶，才能盖住发层的脸区域，五官切换可见
#               ③ 九宫格缩略图自动变大（加载原始全图而非_t透明层）
# 预览区 = robe(完整立绘底) + hair_t(发型透明层中) + features_t(面部透明层顶) 三张TextureRect同位叠放。
#       默认视图：标题→双输入→性别→三Tab→预览区(三层合成)+放大提示→标签→九宫格→确认按钮。
#       点击放大 → 弹出组合预览弹窗（标题含三维编号）。

signal 创建完成(宗门名: String, 宗主名: String, 性别: String, 发型idx: int, 五官idx: int, 服饰idx: int)

# ── 面板外框 ──
const 面板左: float = 20.0
const 面板右: float = 460.0
const 面板上: float = 14.0          # v13: 稍微上移，给顶部更多空间
const 面板下: float = 840.0         # v13: 距屏底(854)有 14px（面板边框内）
const 内边距: float = 14.0           # v13: 内边距加大
const 内容左: float = 内边距
const 内容右: float = 面板右 - 面板左 - 内边距  # = 412
const 可用宽: float = 内容右 - 内容左              # = 398

# ── 九宫格常量 ──
const 维度序: Array = ["hair", "features", "robe"]
const 维度名: Dictionary = {"hair": "发型", "features": "五官", "robe": "服饰"}
const 每维显示数: int = 9
const 网格列数: int = 3
const 格宽: float = 120.0
const 格高: float = 106.0            # v13: 稍微缩小让3行更紧凑
const 格间距: float = 10.0

var _性别: String = "男"
var _维度: String = "hair"
var _idx: Dictionary = {"hair": 0, "features": 0, "robe": 0}
# v21: 三层叠放——预览 = robe(底) + hair_t(中) + features_t(顶)，五官最顶才能盖住发层的脸
var _面板: Panel
var _宗门名输入: LineEdit
var _宗主名输入: LineEdit
var _小预览: TextureRect          # 底层：robe 完整立绘
var _预览发层: TextureRect        # 中层：hair_t 发型透明层
var _预览脸层: TextureRect        # 顶层：features_t 面部透明层（v21: 移到最顶，五官可见）
var _小预览框: Panel
var _选择标签: Label
var _提示: Label
var _tab按钮: Dictionary = {}
var _cell面板: Dictionary = {}
var _性别按钮: Dictionary = {}
var _缩略图缓存: Dictionary = {}
var _滚动容器: ScrollContainer
var _网格内容区: Control

# ── 弹窗相关 ──
var _弹窗遮罩: ColorRect
var _弹窗面板: Panel
var _弹窗预览: TextureRect          # 底层：robe
var _弹窗发层: TextureRect          # 中层：hair_t 发型透明层
var _弹窗脸层: TextureRect          # 顶层：features_t 面部透明层
var _弹窗关闭: Button
var _弹窗标题: Label
var _弹窗开启: bool = false

func _ready() -> void:
	_build()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# ═══ 半透明背景遮罩 ═══
	var 遮 := ColorRect.new()
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.color = Color(0.06, 0.08, 0.075, 1.0)  # 局部微色·保留：全屏背景遮罩 #0F1413（scrim，非 token；注：偏墨绿 g>b，待 P1-C 裁定是否收口 COLOR_STATUSBAR_BG）
	遮.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(遮)

	# ═══ 主面板 ═══
	_面板 = Panel.new()
	_面板.name = "面板"
	_面板.layout_mode = 0
	_面板.offset_left = 面板左
	_面板.offset_top = 面板上
	_面板.offset_right = 面板右
	_面板.offset_bottom = 面板下
	UITheme.apply_dynamics_panel_style(_面板, 0.92)
	add_child(_面板)

	# ═══ v13 布局常量（统一 8px 区块间距） ═══
	const 行高: float = 32.0        # 输入行高度（Label+LineEdit居中）
	const 区块间距: float = 8.0     # 统一区块间距离
	var y: float = 12.0             # 当前 Y 游标（从面板内 12px 开始）

	# ── 标题 ──
	var 标题 := Label.new()
	标题.layout_mode = 0
	标题.offset_left = 内容左
	标题.offset_top = y               # 12
	标题.offset_right = 内容右
	标题.offset_bottom = y + 26.0     # 38  (26px高)
	标题.text = "创建你的宗门"
	标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_title_font_sized(标题, UITheme.FONT_H2)
	标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE2)
	_面板.add_child(标题)
	y += 26.0 + 区块间距              # → 46

	# ── 输入行 1：宗门名（v13: 32px行高，Label与Input垂直居中对齐） ──
	var 行1 := Control.new()
	行1.layout_mode = 0
	行1.offset_left = 内容左
	行1.offset_top = y                # 46
	行1.offset_right = 内容右
	行1.offset_bottom = y + 行高      # 78
	var lbl名 := Label.new()
	lbl名.layout_mode = 0
	lbl名.offset_left = 0.0
	lbl名.offset_top = 3.0            # v14: 与 LineEdit 同 top，确保基线对齐
	lbl名.offset_right = 52.0
	lbl名.offset_bottom = 23.0         # 20px文字区
	lbl名.text = "宗门名"
	UITheme.apply_body_font_sized(lbl名, UITheme.FONT_BODY)
	lbl名.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	行1.add_child(lbl名)
	_宗门名输入 = LineEdit.new()
	_宗门名输入.layout_mode = 0
	_宗门名输入.offset_left = 56.0
	_宗门名输入.offset_top = 3.0       # 与 Label 同 top
	_宗门名输入.offset_right = 可用宽 - 56.0 + 内容左
	_宗门名输入.offset_bottom = 29.0    # 26px高
	_宗门名输入.placeholder_text = "如：太玄宗"
	_apply_input_style(_宗门名输入)
	行1.add_child(_宗门名输入)
	_面板.add_child(行1)
	y += 行高 + 区块间距             # → 86

	# ── 输入行 2：宗主名（同上行高和对齐方式） ──
	var 行2 := Control.new()
	行2.layout_mode = 0
	行2.offset_left = 内容左
	行2.offset_top = y                # 86
	行2.offset_right = 内容右
	行2.offset_bottom = y + 行高      # 118
	var lbl主 := Label.new()
	lbl主.layout_mode = 0
	lbl主.offset_left = 0.0
	lbl主.offset_top = 3.0            # v14: 与 LineEdit 同 top
	lbl主.offset_right = 52.0
	lbl主.offset_bottom = 23.0
	lbl主.text = "宗主名"
	UITheme.apply_body_font_sized(lbl主, UITheme.FONT_BODY)
	lbl主.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	行2.add_child(lbl主)
	_宗主名输入 = LineEdit.new()
	_宗主名输入.layout_mode = 0
	_宗主名输入.offset_left = 56.0
	_宗主名输入.offset_top = 3.0       # v14: 与 Label 同 top
	_宗主名输入.offset_right = 可用宽 - 56.0 + 内容左
	_宗主名输入.offset_bottom = 29.0
	_宗主名输入.placeholder_text = "如：太玄真君"
	_apply_input_style(_宗主名输入)
	行2.add_child(_宗主名输入)
	_面板.add_child(行2)
	y += 行高 + 区块间距             # → 126

	# ── 性别选择 ──
	var 性别行 := Control.new()
	性别行.layout_mode = 0
	性别行.offset_left = 内容左
	性别行.offset_top = y             # 126
	性别行.offset_right = 内容右
	性别行.offset_bottom = y + 34.0   # 160 (34px高，比输入行略高)
	var lbl性 := Label.new()
	lbl性.layout_mode = 0
	lbl性.offset_left = 0.0
	lbl性.offset_top = 7.0            # (34-20)/2 ≈ 7
	lbl性.offset_right = 44.0
	lbl性.offset_bottom = 27.0
	lbl性.text = "性别"
	UITheme.apply_body_font_sized(lbl性, UITheme.FONT_BODY)
	lbl性.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	性别行.add_child(lbl性)
	var btn宽: float = (可用宽 - 50.0 - 10.0) / 2.0
	for g in Game.宗主性别预设:
		var b := Button.new()
		b.layout_mode = 0
		var gi: int = Game.宗主性别预设.find(g)
		b.offset_left = 48.0 + gi * (btn宽 + 10.0)
		b.offset_top = 3.0             # (34-28)/2 = 3 → 按钮居中
		b.offset_right = b.offset_left + btn宽
		b.offset_bottom = 31.0          # 28px高
		b.text = g
		b.pressed.connect(_on_性别选择.bind(g))
		_性别按钮[g] = b
		性别行.add_child(b)
	_面板.add_child(性别行)
	_刷新性别按钮()
	y += 34.0 + 区块间距             # → 168

	# ── 选项卡栏 ──
	var 选项卡 := Control.new()
	选项卡.layout_mode = 0
	选项卡.offset_left = 内容左
	选项卡.offset_top = y             # 168
	选项卡.offset_right = 内容右
	选项卡.offset_bottom = y + 34.0   # 202 (34px高)
	var tn: int = 维度序.size()
	var t间距: float = 8.0
	var t宽: float = (可用宽 - t间距 * (tn - 1)) / float(tn)
	for i in range(tn):
		var d: String = 维度序[i]
		var tb := Button.new()
		tb.layout_mode = 0
		tb.offset_left = i * (t宽 + t间距)
		tb.offset_top = 2.0            # (34-30)/2 = 2
		tb.offset_right = tb.offset_left + t宽
		tb.offset_bottom = 32.0         # 30px高
		tb.text = 维度名.get(d, d)
		tb.pressed.connect(_on_选项卡选择.bind(d))
		_tab按钮[d] = tb
		选项卡.add_child(tb)
	_面板.add_child(选项卡)
	_刷新选项卡()
	y += 34.0 + 区块间距             # → 210

	# ═══ 小预览缩略图（可点击弹出大窗口） ═══
	_小预览框 = Panel.new()
	_小预览框.name = "小预览框"
	_小预览框.layout_mode = 0
	_小预览框.offset_left = 内容左
	_小预览框.offset_top = y           # 210
	_小预览框.offset_right = 内容右
	_小预览框.offset_bottom = y + 144.0  # 354 (144px高，舒适预览)
	_小预览框.mouse_filter = Control.MOUSE_FILTER_STOP
	_小预览框.gui_input.connect(_on_小预览点击)
	var 小预览样式 := StyleBoxFlat.new()
	小预览样式.bg_color = Color(0.05, 0.07, 0.06, 1.0)  # 局部微色·保留：小预览暗底 #0D120F（组件专属，非 token；注：偏墨绿 g>b，待 P1-C 裁定）
	小预览样式.border_color = UITheme.COLOR_BORDER_GOLD
	小预览样式.set_corner_radius_all(8)
	小预览样式.border_width_left = 1.5
	小预览样式.border_width_top = 1.5
	小预览样式.border_width_right = 1.5
	小预览样式.border_width_bottom = 1.5
	_小预览框.add_theme_stylebox_override("panel", 小预览样式)
	_面板.add_child(_小预览框)

	_小预览 = TextureRect.new()
	_小预览.name = "小预览图"
	_小预览.layout_mode = 0
	_小预览.offset_left = 内容左 + 8.0
	_小预览.offset_top = y + 8.0       # 218
	_小预览.offset_right = 内容右 - 8.0
	_小预览.offset_bottom = y + 136.0  # 346 (128px内部图片区)
	_小预览.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_小预览.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_小预览.mouse_filter = Control.MOUSE_FILTER_IGNORE  # v13: 关键！穿透点击到下层Panel
	_面板.add_child(_小预览)

	# v21: 三层叠放——hair_t 发型透明层（中层）
	_预览发层 = TextureRect.new()
	_预览发层.name = "预览发层"
	_预览发层.layout_mode = 0
	_预览发层.offset_left = 内容左 + 8.0
	_预览发层.offset_top = y + 8.0
	_预览发层.offset_right = 内容右 - 8.0
	_预览发层.offset_bottom = y + 136.0
	_预览发层.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_预览发层.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_预览发层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_面板.add_child(_预览发层)

	# v21: 三层叠放——features_t 面部透明层（顶层！放最顶才能盖住发层的脸，五官切换才可见）
	_预览脸层 = TextureRect.new()
	_预览脸层.name = "预览脸层"
	_预览脸层.layout_mode = 0
	_预览脸层.offset_left = 内容左 + 8.0
	_预览脸层.offset_top = y + 8.0
	_预览脸层.offset_right = 内容右 - 8.0
	_预览脸层.offset_bottom = y + 136.0
	_预览脸层.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_预览脸层.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_预览脸层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_面板.add_child(_预览脸层)

	# 小预览上的"点击放大"提示
	var 放大提示 := Label.new()
	放大提示.name = "放大提示"
	放大提示.layout_mode = 0
	放大提示.offset_left = 内容右 - 90.0
	放大提示.offset_top = y + 124.0     # 334
	放大提示.offset_right = 内容右 - 4.0
	放大提示.offset_bottom = y + 142.0  # 352
	放大提示.text = "🔍 点击放大"
	放大提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.apply_body_font_sized(放大提示, UITheme.FONT_AUX)
	放大提示.add_theme_color_override("font_color", Color(0.75, 0.7, 0.5, 0.9))  # 局部微色·保留：放大提示淡金 #BFB280 @α0.9（组件专属，非 token）
	放大提示.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 穿透
	_面板.add_child(放大提示)
	y += 144.0 + 区块间距           # → 362

	# ── 选择标签 ──
	_选择标签 = Label.new()
	_选择标签.name = "选择标签"
	_选择标签.layout_mode = 0
	_选择标签.offset_left = 内容左
	_选择标签.offset_top = y          # 362
	_选择标签.offset_right = 内容右
	_选择标签.offset_bottom = y + 18.0  # 380 (18px高)
	_选择标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_body_font_sized(_选择标签, UITheme.FONT_AUX)
	_选择标签.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	_面板.add_child(_选择标签)
	y += 18.0 + 区块间距             # → 388

	# ── ScrollContainer + InnerContent + 九宫格 ──
	_滚动容器 = ScrollContainer.new()
	_滚动容器.name = "网格滚动区"
	_滚动容器.layout_mode = 0
	_滚动容器.offset_left = 内容左
	_滚动容器.offset_top = y          # 388
	_滚动容器.offset_right = 内容右
	_滚动容器.offset_bottom = 面板下 - 50.0  # 790 (402px高，容纳3行)
	_滚动容器.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_滚动容器.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_面板.add_child(_滚动容器)

	_网格内容区 = Control.new()
	_网格内容区.name = "网格内容区"
	_网格内容区.layout_mode = 0
	_网格内容区.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sc_行数: int = ceil(float(每维显示数) / float(网格列数))
	var sc_内宽: float = 网格列数 * 格宽 + (网格列数 - 1) * 格间距
	var sc_内高: float = sc_行数 * 格高 + (sc_行数 - 1) * 格间距
	_网格内容区.offset_left = 0.0
	_网格内容区.offset_top = 0.0
	_网格内容区.offset_right = sc_内宽
	_网格内容区.offset_bottom = sc_内高
	_滚动容器.add_child(_网格内容区)

	_重建网格()

	# ── 错误提示（默认隐藏） ──
	_提示 = Label.new()
	_提示.layout_mode = 0
	_提示.offset_left = 内容左
	_提示.offset_top = 面板下 - 44.0    # 796
	_提示.offset_right = 内容右
	_提示.offset_bottom = 面板下 - 26.0  # 814 (18px高)
	_提示.text = ""
	_提示.visible = false
	_提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_body_font_sized(_提示, UITheme.FONT_AUX)
	_提示.add_theme_color_override("font_color", UITheme.COLOR_TEXT_RED)
	_面板.add_child(_提示)

	# ── 确认按钮（v14: 距面板底 18px 安全边距） ──
	var 确认 := PrimaryButton.new()
	确认.layout_mode = 0
	确认.offset_left = 内容左
	确认.offset_top = 面板下 - 54.0    # 786
	确认.offset_right = 内容右
	确认.offset_bottom = 面板下 - 18.0  # 822 (36px高，距面板底18px安全边距)
	确认.text = "创立宗门"
	确认.pressed.connect(_on_确认)
	_面板.add_child(确认)

	# ═══ 构建弹窗（初始隐藏） ═══
	_构建弹窗()

	_刷新预览()

# ════════════════════════════════════════════
#  弹窗系统
# ════════════════════════════════════════════

func _构建弹窗() -> void:
	var 弹窗层 := CanvasLayer.new()
	弹窗层.name = "弹窗层"
	弹窗层.layer = 128
	add_child(弹窗层)

	_弹窗遮罩 = ColorRect.new()
	_弹窗遮罩.name = "弹窗遮罩"
	_弹窗遮罩.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_弹窗遮罩.color = Color(0.0, 0.0, 0.0, 0.75)  # 局部微色·保留：弹窗遮罩纯黑 @α0.75（scrim，非 token）
	_弹窗遮罩.mouse_filter = Control.MOUSE_FILTER_STOP
	_弹窗遮罩.gui_input.connect(_on_弹窗遮罩点击)
	_弹窗遮罩.visible = false
	弹窗层.add_child(_弹窗遮罩)

	var 弹窗宽: float = 340.0
	var 弹窗高: float = 560.0
	var 弹窗左: float = (480.0 - 弹窗宽) / 2.0
	var 弹窗顶: float = (854.0 - 弹窗高) / 2.0

	_弹窗面板 = Panel.new()
	_弹窗面板.name = "弹窗面板"
	_弹窗面板.layout_mode = 0
	_弹窗面板.offset_left = 弹窗左
	_弹窗面板.offset_top = 弹窗顶
	_弹窗面板.offset_right = 弹窗左 + 弹窗宽
	_弹窗面板.offset_bottom = 弹窗顶 + 弹窗高
	var 弹窗样式 := StyleBoxFlat.new()
	弹窗样式.bg_color = Color(0.08, 0.1, 0.09, 1.0)  # 局部微色·保留：弹窗面板暗底 #141A17（组件专属，非 token；注：偏墨绿 g>b，待 P1-C 裁定）
	弹窗样式.border_color = UITheme.COLOR_BORDER_GOLD
	弹窗样式.set_corner_radius_all(12)
	弹窗样式.border_width_left = 2
	弹窗样式.border_width_top = 2
	弹窗样式.border_width_right = 2
	弹窗样式.border_width_bottom = 2
	弹窗样式.shadow_color = Color(0.0, 0.0, 0.0, 0.6)  # 局部微色·保留：弹窗投影 @α0.6（shadow，非 token；刻意重于 make_panel_stylebox_flat 的 α0.22）
	弹窗样式.set_shadow_size(16)
	弹窗样式.set_shadow_offset(Vector2(0, 4))
	_弹窗面板.add_theme_stylebox_override("panel", 弹窗样式)
	_弹窗面板.visible = false
	弹窗层.add_child(_弹窗面板)

	var pad: float = 14.0

	_弹窗标题 = Label.new()
	_弹窗标题.name = "弹窗标题"
	_弹窗标题.layout_mode = 0
	_弹窗标题.offset_left = pad
	_弹窗标题.offset_top = 10.0
	_弹窗标题.offset_right = 弹窗宽 - pad
	_弹窗标题.offset_bottom = 32.0
	_弹窗标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_title_font_sized(_弹窗标题, UITheme.FONT_H2)
	_弹窗标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE2)
	_弹窗面板.add_child(_弹窗标题)

	_弹窗预览 = TextureRect.new()
	_弹窗预览.name = "弹窗预览图"
	_弹窗预览.layout_mode = 0
	_弹窗预览.offset_left = pad
	_弹窗预览.offset_top = 38.0
	_弹窗预览.offset_right = 弹窗宽 - pad
	_弹窗预览.offset_bottom = 弹窗高 - 50.0
	_弹窗预览.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_弹窗预览.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_弹窗面板.add_child(_弹窗预览)

	# v21: 弹窗中层——hair 发型透明层（同位叠放在 _弹窗预览 之上）
	_弹窗发层 = TextureRect.new()
	_弹窗发层.name = "弹窗发层"
	_弹窗发层.layout_mode = 0
	_弹窗发层.offset_left = pad
	_弹窗发层.offset_top = 38.0
	_弹窗发层.offset_right = 弹窗宽 - pad
	_弹窗发层.offset_bottom = 弹窗高 - 50.0
	_弹窗发层.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_弹窗发层.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_弹窗发层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_弹窗面板.add_child(_弹窗发层)

	# v21: 弹窗顶层——features 面部透明层（最顶，盖住 hair 层的脸部区域）
	_弹窗脸层 = TextureRect.new()
	_弹窗脸层.name = "弹窗脸层"
	_弹窗脸层.layout_mode = 0
	_弹窗脸层.offset_left = pad
	_弹窗脸层.offset_top = 38.0
	_弹窗脸层.offset_right = 弹窗宽 - pad
	_弹窗脸层.offset_bottom = 弹窗高 - 50.0
	_弹窗脸层.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_弹窗脸层.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_弹窗脸层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_弹窗面板.add_child(_弹窗脸层)

	var 按钮宽: float = 100.0
	_弹窗关闭 = Button.new()
	_弹窗关闭.name = "弹窗关闭"
	_弹窗关闭.layout_mode = 0
	_弹窗关闭.offset_left = (弹窗宽 - 按钮宽) / 2.0
	_弹窗关闭.offset_top = 弹窗高 - 38.0
	_弹窗关闭.offset_right = (弹窗宽 + 按钮宽) / 2.0
	_弹窗关闭.offset_bottom = 弹窗高 - 8.0
	_弹窗关闭.text = "关闭"
	_弹窗关闭.pressed.connect(_关闭弹窗)
	var 关闭样式 := StyleBoxFlat.new()
	关闭样式.bg_color = Color(0.15, 0.12, 0.08, 1.0)  # 局部微色·保留：关闭按钮暖褐底 #261F14（组件专属，非 token；非主按钮，不涉 §4.1 锁死色）
	关闭样式.border_color = UITheme.COLOR_BORDER_GOLD
	关闭样式.set_corner_radius_all(6)
	关闭样式.border_width_left = 1
	关闭样式.border_width_top = 1
	关闭样式.border_width_right = 1
	关闭样式.border_width_bottom = 1
	_弹窗关闭.add_theme_stylebox_override("normal", 关闭样式)
	_弹窗关闭.add_theme_stylebox_override("hover", 关闭样式)
	_弹窗关闭.add_theme_stylebox_override("pressed", 关闭样式)
	UITheme.apply_body_font_sized(_弹窗关闭, UITheme.FONT_BODY)
	_弹窗关闭.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	_弹窗面板.add_child(_弹窗关闭)

func _打开弹窗() -> void:
	if _弹窗开启:
		return
	_弹窗开启 = true
	_更新弹窗预览()
	_弹窗遮罩.visible = true
	_弹窗面板.visible = true

func _关闭弹窗() -> void:
	_弹窗开启 = false
	_弹窗遮罩.visible = false
	_弹窗面板.visible = false

func _更新弹窗预览() -> void:
	if _弹窗预览 == null or Game == null or not is_instance_valid(Game):
		return
	# v21: 弹窗三层叠放——robe(底) + hair_t(中) + features_t(顶)，与预览区一致
	var hi: int = _idx["hair"]
	var fi: int = _idx["features"]
	var ri: int = _idx["robe"]

	# 底层：robe 完整立绘
	var robe_tex: Texture2D = Game.取宗主头像纯袍纹理(_性别, ri)
	if robe_tex != null:
		_弹窗预览.texture = robe_tex
		_弹窗预览.modulate = Color.WHITE
	else:
		_弹窗预览.texture = null
		_弹窗预览.modulate = Color(1, 1, 1, 0.3)  # 局部微色·保留：缺图占位 modulate @α0.3（非 token）

	# 中层：hair 发型透明层
	var hair_tex: Texture2D = Game.取宗主单层纹理(_性别, "hair_t", hi)
	if hair_tex != null and _弹窗发层 != null:
		_弹窗发层.texture = hair_tex
		_弹窗发层.modulate = Color.WHITE
	elif _弹窗发层 != null:
		_弹窗发层.texture = null

	# 顶层：features 面部透明层
	var feat_tex: Texture2D = Game.取宗主单层纹理(_性别, "features_t", fi)
	if feat_tex != null and _弹窗脸层 != null:
		_弹窗脸层.texture = feat_tex
		_弹窗脸层.modulate = Color.WHITE
	elif _弹窗脸层 != null:
		_弹窗脸层.texture = null

	# 标题
	if _弹窗标题 != null:
		var h_name: String = str(hi + 1).pad_zeros(2)
		var f_name: String = str(fi + 1).pad_zeros(2)
		var r_name: String = str(ri + 1).pad_zeros(2)
		_弹窗标题.text = "组合预览 - 发型%s  五官%s  服饰%s" % [h_name, f_name, r_name]

func _on_小预览点击(事件: InputEvent) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_打开弹窗()

func _on_弹窗遮罩点击(事件: InputEvent) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_关闭弹窗()

# ════════════════════════════════════════════
#  九宫格 & 选择逻辑
# ════════════════════════════════════════════

func _重建网格() -> void:
	for d in _cell面板.keys():
		for p in _cell面板[d]:
			if is_instance_valid(p):
				p.queue_free()
	_cell面板.clear()

	if _网格内容区 == null or not is_instance_valid(_网格内容区):
		return

	for d in 维度序:
		var arr: Array = []
		var paths: Array = _维度路径(d)
		var 显示数: int = mini(每维显示数, paths.size())
		for idx in range(显示数):
			var 面板格 := Panel.new()
			面板格.layout_mode = 0
			var col: int = idx % 网格列数
			var row_i: int = idx / 网格列数
			面板格.offset_left = float(col) * (格宽 + 格间距)
			面板格.offset_top = float(row_i) * (格高 + 格间距)
			面板格.offset_right = 面板格.offset_left + 格宽
			面板格.offset_bottom = 面板格.offset_top + 格高
			面板格.add_theme_stylebox_override("panel", _格子样式(false))
			面板格.gui_input.connect(_on_格子点击.bind(d, idx))
			var tr := TextureRect.new()
			tr.layout_mode = 0
			tr.offset_left = 4.0
			tr.offset_top = 4.0
			tr.offset_right = 格宽 - 4.0
			tr.offset_bottom = 格高 - 4.0
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture = _取缩略图(d, idx)
			面板格.add_child(tr)
			面板格.visible = (d == _维度)
			_网格内容区.add_child(面板格)
			arr.append(面板格)
		_cell面板[d] = arr
	_刷新选中()

func _维度路径(d: String) -> Array:
	if Game == null or not is_instance_valid(Game):
		return []
	var 外观集: Dictionary = Game.宗主外观资产.get(_性别, {})
	if 外观集.is_empty():
		return []
	return 外观集.get(d, [])

func _取缩略图(d: String, idx: int) -> Texture2D:
	var key: String = _性别 + "/" + d + "/" + str(idx)
	if _缩略图缓存.has(key):
		return _缩略图缓存[key]
	var paths: Array = _维度路径(d)
	var tex: Texture2D = null
	if idx < paths.size():
		var p: String = paths[idx]
		if ResourceLoader.exists(p):
			tex = load(p)
		if tex == null:
			var img := Image.new()
			if img.load(p) == OK:
				tex = ImageTexture.create_from_image(img)
	_缩略图缓存[key] = tex
	return tex

func _on_格子点击(事件: InputEvent, 维度: String, idx: int) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_idx[维度] = idx
		_刷新选中()
		_刷新预览()
		if _弹窗开启:
			_更新弹窗预览()

func _on_选项卡选择(d: String) -> void:
	_维度 = d
	for dim in _cell面板.keys():
		for p in _cell面板[dim]:
			p.visible = (dim == _维度)
	_刷新选项卡()
	_刷新选中()

func _on_性别选择(g: String) -> void:
	if g == _性别:
		return
	_性别 = g
	_idx = {"hair": 0, "features": 0, "robe": 0}
	_缩略图缓存.clear()
	_刷新性别按钮()
	_重建网格()
	_刷新预览()
	if _弹窗开启:
		_更新弹窗预览()

func _刷新选中() -> void:
	for d in _cell面板.keys():
		var arr: Array = _cell面板[d]
		for i in range(arr.size()):
			var p: Panel = arr[i]
			var sel: bool = (d == _维度 and i == _idx[d])
			p.add_theme_stylebox_override("panel", _格子样式(sel))

func _刷新选项卡() -> void:
	for d in _tab按钮.keys():
		var b: Button = _tab按钮[d]
		var sel: bool = (d == _维度)
		b.add_theme_stylebox_override("normal", _选项卡样式(sel))
		UITheme.apply_body_font_sized(b, UITheme.FONT_BODY)
		b.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE2 if sel else UITheme.COLOR_TEXT_BODY_GOLD)

func _刷新性别按钮() -> void:
	for k in _性别按钮.keys():
		var b: Button = _性别按钮[k]
		var sel: bool = (k == _性别)
		b.add_theme_stylebox_override("normal", _选项卡样式(sel))
		UITheme.apply_body_font_sized(b, UITheme.FONT_BODY)
		b.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE2 if sel else UITheme.COLOR_TEXT_BODY_GOLD)

func _刷新预览() -> void:
	if _小预览 == null or Game == null or not is_instance_valid(Game):
		return
	# v21: 三层叠放——robe(底) + hair_t(中) + features_t(顶)
	var hi: int = _idx["hair"]
	var fi: int = _idx["features"]
	var ri: int = _idx["robe"]

	# 底层：robe 完整立绘
	var robe_tex: Texture2D = Game.取宗主头像纯袍纹理(_性别, ri)
	if robe_tex != null:
		_小预览.texture = robe_tex
		_小预览.modulate = Color.WHITE
	else:
		_小预览.texture = null
		_小预览.modulate = Color(1, 1, 1, 0.3)  # 局部微色·保留：缺图占位 modulate @α0.3（非 token）

	# 中层：hair_t 发型透明层（v21: 用 hair_t 键）
	var hair_tex: Texture2D = Game.取宗主单层纹理(_性别, "hair_t", hi)
	if hair_tex != null and _预览发层 != null:
		_预览发层.texture = hair_tex
		_预览发层.modulate = Color.WHITE
	elif _预览发层 != null:
		_预览发层.texture = null

	# 顶层：features_t 面部透明层（v21: 用 features_t 键，放最顶盖住发层的脸）
	var feat_tex: Texture2D = Game.取宗主单层纹理(_性别, "features_t", fi)
	if feat_tex != null and _预览脸层 != null:
		_预览脸层.texture = feat_tex
		_预览脸层.modulate = Color.WHITE
	elif _预览脸层 != null:
		_预览脸层.texture = null

	# 同步弹窗（如果开着）
	if _弹窗开启:
		_更新弹窗预览()
	# 更新选择标签文字
	if _选择标签 != null:
		var h_name: String = str(_idx["hair"] + 1).pad_zeros(2)
		var f_name: String = str(_idx["features"] + 1).pad_zeros(2)
		var r_name: String = str(_idx["robe"] + 1).pad_zeros(2)
		_选择标签.text = "发型:%s  |  五官:%s  |  服饰:%s" % [h_name, f_name, r_name]

func _apply_input_style(le: LineEdit) -> void:
	le.add_theme_stylebox_override("normal", _input_style(false))
	le.add_theme_stylebox_override("focus", _input_style(true))

func _input_style(focused: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.COLOR_PANEL_BG
	sb.border_color = UITheme.COLOR_BORDER_GOLD if focused else Color(UITheme.COLOR_BORDER_GOLD.r, UITheme.COLOR_BORDER_GOLD.g, UITheme.COLOR_BORDER_GOLD.b, 0.4)
	sb.set_corner_radius_all(6)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	return sb

func _格子样式(sel: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.COLOR_BG_CONTENT if sel else UITheme.COLOR_PANEL_BG
	sb.border_color = UITheme.COLOR_BORDER_GOLD
	sb.set_corner_radius_all(8)
	sb.border_width_left = 2 if sel else 1
	sb.border_width_top = 2 if sel else 1
	sb.border_width_right = 2 if sel else 1
	sb.border_width_bottom = 2 if sel else 1
	return sb

func _选项卡样式(sel: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.COLOR_BG_CONTENT if sel else UITheme.COLOR_PANEL_BG
	sb.border_color = UITheme.COLOR_BORDER_GOLD
	sb.set_corner_radius_all(6)
	sb.border_width_left = 1.5 if sel else 1
	sb.border_width_top = 1.5 if sel else 1
	sb.border_width_right = 1.5 if sel else 1
	sb.border_width_bottom = 1.5 if sel else 1
	return sb

func _on_确认() -> void:
	var 宗: String = _宗门名输入.text.strip_edges()
	var 主: String = _宗主名输入.text.strip_edges()
	if 宗 == "" or 主 == "":
		_提示.text = "宗门名与宗主名均不可为空"
		_提示.visible = true
		return
	创建完成.emit(宗, 主, _性别, _idx["hair"], _idx["features"], _idx["robe"])

extends Control

# 库藏页（宗门宝库）：只读展示 宗门库房（Item 实例数组）。
# 零 GameState 写入，遵守 S1 红线（不碰玩法/装备/战斗逻辑）。
# 布局 1:1 对齐 Ardot 03 屏「库藏 · 宗门宝库」：
#   480×854 设计坐标，经 UI_SCALE 映射到 720×1280；6 列 64×64 品阶色格子；底部左图右文详情面板。

signal 返回主页

const 品阶_TO_TIER := {
	"凡阶": "fan", "灵阶": "ling", "宝阶": "bao", "王阶": "wang",
	"圣阶": "sheng", "仙阶": "xian", "道阶": "dao"
}
const 品阶缩写 := {
	"凡阶": "凡", "灵阶": "灵", "宝阶": "宝", "王阶": "王",
	"圣阶": "圣", "仙阶": "仙", "道阶": "道"
}
const 分类列表: Array = ["全部", "装备", "丹药", "材料", "功法", "灵兽", "碎片", "宝箱"]
const 容量上限: int = 80
const 每行列数: int = 6
const 格尺寸: int = 64
const 格间距: int = 12
const 可见基础槽数: int = 24

# Ardot 03 屏精确色值（按画布 60:1 节点取色）
const C_BG_TOP: Color = Color(0.043, 0.086, 0.102)       # 背景渐变起点 #0B161A
const C_BG_BOT: Color = Color(0.059, 0.133, 0.161)       # 背景渐变终点 #0F2229
const C_TOPBAR_BG: Color = Color(0.039, 0.078, 0.094, 0.90)  # 60:2 顶部栏底
const C_CATBAR_BG: Color = Color(0.035, 0.071, 0.086)    # 60:11 分类栏底
const C_CELL_BG: Color = Color(0.051, 0.102, 0.125)       # 60:20 格子底 #0D1A20
const C_CELL_EMPTY_BG: Color = Color(0.039, 0.078, 0.094, 0.60)  # 60:38 空槽底
const C_CELL_EMPTY_STROKE: Color = Color(0.157, 0.290, 0.337)    # 60:38 空槽描边
const C_DETAIL_BG: Color = Color(0.047, 0.090, 0.102)   # 60:48 详情面板底
const C_DETAIL_STROKE: Color = Color(0.839, 0.694, 0.416, 0.25)  # 60:48 描边
const C_TOP_GOLD_LINE: Color = Color(0.910, 0.773, 0.447, 0.60)  # 60:49 顶金线
const C_SELECTED_FILL: Color = Color(0.910, 0.773, 0.447, 0.12) # 60:44 选中填充
const C_SELECTED_STROKE: Color = Color(0.910, 0.773, 0.447)      # 60:44 选中描边
const C_TIER_PILL_BG: Color = Color(0.839, 0.694, 0.416, 0.18)  # 60:53 品阶药丸底
const C_TIER_PILL_STROKE: Color = Color(0.839, 0.694, 0.416, 0.80)
const C_EQUIP_BTN_BG1: Color = Color(0.910, 0.773, 0.447)   # 60:59 装备按钮渐变亮
const C_EQUIP_BTN_BG2: Color = Color(0.839, 0.694, 0.416)   # 60:59 装备按钮渐变暗
const C_EQUIP_BTN_TEXT: Color = Color(0.086, 0.157, 0.173)  # 60:60 装备文字深色
const C_SELL_BTN_BG: Color = Color(0.078, 0.157, 0.180)     # 60:61 出售按钮底

var _built: bool = false
var _当前分类: String = "全部"
var _选中索引: int = -1
var _格子列表: Array = []          # [{btn, badge, it, index}]
var _槽位数: int = 可见基础槽数

var _bg: TextureRect
var _容量标签: Label
var _分类栏: Panel
var _分类下划线: Dictionary = {}   # cat -> Panel
var _网格: GridContainer
var _详情面板: Panel
var _详情图标: Panel
var _详情图标字: Label
var _详情名: Label
var _详情品阶: Label
var _详情类别: Label
var _详情描述: Label
var _详情属性: Label
var _装备按钮: Button
var _出售按钮: Button
var _合成按钮: Button
var _出售提示: Label

func _ready() -> void:
	_build()
	refresh()

func _enter_tree() -> void:
	if _built:
		refresh.call_deferred()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_bg(self)
	_build_top_bar(self)
	_build_categories(self)
	_build_grid(self)
	_build_detail(self)
	_build_actions(self)

# ───────── 全屏渐变底 ─────────
func _build_bg(parent: Control) -> void:
	# 决策 4 升级：工业化背景（顶部氛围场景图 + 下方不透明纯色内容区）
	UITheme.make_scene_background(parent)

# ───────── 顶部导航栏（高 64）─────────
func _build_top_bar(parent: Control) -> void:
	var bar := Panel.new()
	bar.name = "TopBar"
	_place(bar, 0.0, 0.0, 480.0, 64.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = C_TOPBAR_BG
	bsb.set_border_width_all(0)
	bar.add_theme_stylebox_override("panel", bsb)
	parent.add_child(bar)

	# 返回按钮（统一 40×40 金色箭头）
	var back: Button = UITheme.make_back_button(_on_back_pressed)
	_place(back, 16.0, 20.0, 40.0, 40.0)
	parent.add_child(back)

	# 标题已按需求移除（仅保留统一返回箭头）

	# "容量" @ (288,28) 13 Regular
	var cap_lbl := Label.new()
	cap_lbl.name = "CapLabelPrefix"
	cap_lbl.text = "容量"
	_place(cap_lbl, 288.0, 28.0, 30.0, 19.0)
	UITheme.apply_body_font_sized(cap_lbl, _fs(13))
	cap_lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	parent.add_child(cap_lbl)

	# 数值 "42 / 80" @ (326,26) 15 Bold
	_容量标签 = Label.new()
	_容量标签.name = "CapLabel"
	_容量标签.text = "0 / %d" % 容量上限
	_place(_容量标签, 326.0, 26.0, 60.0, 22.0)
	UITheme.apply_title_font_sized(_容量标签, _fs(15))
	_容量标签.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	parent.add_child(_容量标签)

	# 整理按钮 @ (400,18) 64×32
	var tidy := Button.new()
	tidy.name = "TidyBtn"
	tidy.flat = true
	tidy.text = "整理"
	_place(tidy, 400.0, 18.0, 64.0, 32.0)
	tidy.mouse_filter = Control.MOUSE_FILTER_STOP
	UITheme.apply_body_font_sized(tidy, _fs(14))
	tidy.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	var tbs := StyleBoxFlat.new()
	tbs.bg_color = Color(0.078, 0.157, 0.180)
	tbs.border_color = UITheme.COLOR_TEXT_GOLD
	tbs.set_corner_radius_all(_rc(16))
	tbs.set_border_width_all(_bw(1))
	tidy.add_theme_stylebox_override("normal", tbs)
	tidy.add_theme_stylebox_override("pressed", tbs)
	tidy.add_theme_stylebox_override("hover", tbs)
	tidy.add_theme_stylebox_override("focus", tbs)
	tidy.pressed.connect(_on_tidy_pressed)
	parent.add_child(tidy)

# ───────── 分类标签栏（高 48）─────────
func _build_categories(parent: Control) -> void:
	_分类栏 = Panel.new()
	_分类栏.name = "CategoryBar"
	_place(_分类栏, 0.0, 64.0, 480.0, 48.0)
	_分类栏.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = C_CATBAR_BG
	bsb.set_border_width_all(0)
	_分类栏.add_theme_stylebox_override("panel", bsb)
	parent.add_child(_分类栏)

	# 动态计算分类按钮的x坐标（适配8个分类）
	var 分类数: int = 分类列表.size()
	var 按钮宽度: float = 42.0
	var 总按钮宽度: float = 分类数 * 按钮宽度
	var 可用宽度: float = 480.0 - 20.0  # 左右各留10px边距
	var 间距: float = (可用宽度 - 总按钮宽度) / max(分类数 - 1, 1)
	var 起始x: float = 10.0
	for i in range(分类数):
		var cat: String = 分类列表[i]
		var x_pos: float = 起始x + i * (按钮宽度 + 间距)
		var b := Button.new()
		b.name = "Cat_" + cat
		b.flat = true
		b.text = cat
		_place(b, x_pos, 15.0, 按钮宽度, 22.0)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		_update_cat_style(b, cat == _当前分类)
		b.pressed.connect(_on_cat_pressed.bind(cat))
		_分类栏.add_child(b)

		var line := Panel.new()
		line.name = "CatLine_" + cat
		_place(line, x_pos - 2.0, 42.0, 按钮宽度 + 4.0, 3.0)
		line.visible = (cat == _当前分类)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lsb := StyleBoxFlat.new()
		lsb.bg_color = UITheme.C01_TEXT_GOLD
		lsb.set_corner_radius_all(_rc(1))
		lsb.set_border_width_all(0)
		line.add_theme_stylebox_override("panel", lsb)
		_分类栏.add_child(line)
		_分类下划线[cat] = line

func _update_cat_style(b: Button, sel: bool) -> void:
	if sel:
		UITheme.apply_title_font_sized(b, _fs(15))
		b.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	else:
		UITheme.apply_body_font_sized(b, _fs(15))
		b.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)

# ───────── 物品网格（6 列，16,112,448,308）─────────
func _build_grid(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "GridScroll"
	_place(scroll, 16.0, 112.0, 448.0, 308.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(scroll)

	_网格 = GridContainer.new()
	_网格.name = "Grid"
	_网格.columns = 每行列数
	_网格.add_theme_constant_override("h_separation", _ip(格间距))
	_网格.add_theme_constant_override("v_separation", _ip(格间距))
	_网格.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_网格.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_网格.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_网格)

# ───────── 选中详情面板（16,590,448,180）─────────
func _build_detail(parent: Control) -> void:
	_详情面板 = Panel.new()
	_详情面板.name = "DetailPanel"
	_place(_详情面板, 16.0, 590.0, 448.0, 180.0)
	_详情面板.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb := StyleBoxFlat.new()
	psb.bg_color = C_DETAIL_BG
	psb.border_color = C_DETAIL_STROKE
	psb.set_corner_radius_all(_rc(14))
	psb.set_border_width_all(_bw(1))
	_详情面板.add_theme_stylebox_override("panel", psb)
	parent.add_child(_详情面板)

	# 顶部金线
	var top_line := Panel.new()
	top_line.name = "DetailTopLine"
	_place(top_line, 0.0, 0.0, 448.0, 2.0)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tlsb := StyleBoxFlat.new()
	tlsb.bg_color = C_TOP_GOLD_LINE
	tlsb.set_border_width_all(0)
	top_line.add_theme_stylebox_override("panel", tlsb)
	_详情面板.add_child(top_line)

	# 选中图标 80×80 @ (20,24)
	_详情图标 = Panel.new()
	_详情图标.name = "DetailIcon"
	_place(_详情图标, 20.0, 24.0, 80.0, 80.0)
	_详情图标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var isb := StyleBoxFlat.new()
	isb.bg_color = C_CELL_BG
	isb.border_color = UITheme.C01_TEXT_GOLD
	isb.set_corner_radius_all(_rc(12))
	isb.set_border_width_all(_bw(1))
	_详情图标.add_theme_stylebox_override("panel", isb)
	_详情面板.add_child(_详情图标)

	_详情图标字 = Label.new()
	_详情图标字.name = "DetailIconText"
	_详情图标字.text = "王×1"
	_详情图标字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_详情图标字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_详情图标字, 0.0, 0.0, 80.0, 80.0)
	UITheme.apply_title_font_sized(_详情图标字, _fs(16))
	_详情图标字.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	_详情图标.add_child(_详情图标字)

	# 物品名 @ (116,24) 20 Bold
	_详情名 = Label.new()
	_详情名.name = "DetailName"
	_详情名.text = "—"
	_place(_详情名, 116.0, 24.0, 312.0, 29.0)
	UITheme.apply_title_font_sized(_详情名, _fs(20))
	_详情名.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	_详情面板.add_child(_详情名)

	# 品阶药丸 @ (116,58)
	var pill := Panel.new()
	pill.name = "DetailTierPill"
	_place(pill, 116.0, 58.0, 48.0, 22.0)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pisb := StyleBoxFlat.new()
	pisb.bg_color = C_TIER_PILL_BG
	pisb.border_color = C_TIER_PILL_STROKE
	pisb.set_corner_radius_all(_rc(11))
	pisb.set_border_width_all(_bw(1))
	pill.add_theme_stylebox_override("panel", pisb)
	_详情面板.add_child(pill)

	_详情品阶 = Label.new()
	_详情品阶.name = "DetailTier"
	_详情品阶.text = "王阶"
	_详情品阶.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_详情品阶.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_详情品阶, 116.0, 58.0, 48.0, 22.0)
	UITheme.apply_body_font_sized(_详情品阶, _fs(12))
	_详情品阶.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	_详情面板.add_child(_详情品阶)

	# 类别标签 "· 护甲" @ (174,61)
	_详情类别 = Label.new()
	_详情类别.name = "DetailCategory"
	_详情类别.text = "· 护甲"
	_place(_详情类别, 174.0, 61.0, 80.0, 17.0)
	UITheme.apply_body_font_sized(_详情类别, _fs(12))
	_详情类别.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	_详情面板.add_child(_详情类别)

	# 物品描述 @ (116,92) 宽 312
	_详情描述 = Label.new()
	_详情描述.name = "DetailDesc"
	_详情描述.text = "（点选上方物品查看详情）"
	_详情描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_详情描述, 116.0, 92.0, 312.0, 48.0)
	UITheme.apply_body_font_sized(_详情描述, _fs(13))
	_详情描述.add_theme_color_override("font_color", UITheme.C01_TEXT_SECONDARY)
	_详情面板.add_child(_详情描述)

	# 属性加成 @ (20,120) 13 Medium
	_详情属性 = Label.new()
	_详情属性.name = "DetailProps"
	_详情属性.text = ""
	_place(_详情属性, 20.0, 120.0, 408.0, 44.0)
	_详情属性.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_font_sized(_详情属性, _fs(13))
	_详情属性.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	_详情面板.add_child(_详情属性)

# ───────── 底部操作栏（16,776,448,70）─────────
func _build_actions(parent: Control) -> void:
	var bar := Control.new()
	bar.name = "ActionBar"
	_place(bar, 16.0, 776.0, 448.0, 70.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)

	# 装备按钮 268×46 金渐变
	_装备按钮 = Button.new()
	_装备按钮.name = "EquipBtn"
	_装备按钮.flat = true
	_装备按钮.text = "披挂"
	_place(_装备按钮, 0.0, 0.0, 268.0, 46.0)
	_装备按钮.mouse_filter = Control.MOUSE_FILTER_STOP
	UITheme.apply_title_font_sized(_装备按钮, _fs(16))
	_装备按钮.add_theme_color_override("font_color", C_EQUIP_BTN_TEXT)
	_装备按钮.add_theme_stylebox_override("normal", _make_equip_stylebox())
	_装备按钮.add_theme_stylebox_override("pressed", _make_equip_stylebox())
	_装备按钮.add_theme_stylebox_override("hover", _make_equip_stylebox())
	_装备按钮.add_theme_stylebox_override("focus", _make_equip_stylebox())
	_装备按钮.pressed.connect(_on_action_pressed.bind("装备"))
	bar.add_child(_装备按钮)

	# 出售按钮 156×46 深底金边
	_出售按钮 = Button.new()
	_出售按钮.name = "SellBtn"
	_出售按钮.flat = true
	_出售按钮.text = "售卖"
	_place(_出售按钮, 292.0, 0.0, 156.0, 46.0)
	_出售按钮.mouse_filter = Control.MOUSE_FILTER_STOP
	UITheme.apply_body_font_sized(_出售按钮, _fs(16))
	_出售按钮.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	var sbs := StyleBoxFlat.new()
	sbs.bg_color = C_SELL_BTN_BG
	sbs.border_color = UITheme.COLOR_TEXT_GOLD
	sbs.set_corner_radius_all(_rc(23))
	sbs.set_border_width_all(_bw(1))
	_出售按钮.add_theme_stylebox_override("normal", sbs)
	_出售按钮.add_theme_stylebox_override("pressed", sbs)
	_出售按钮.add_theme_stylebox_override("hover", sbs)
	_出售按钮.add_theme_stylebox_override("focus", sbs)
	_出售按钮.pressed.connect(_on_action_pressed.bind("出售"))
	bar.add_child(_出售按钮)

	# 合成/打开按钮 268×46 金渐变（碎片分类显示"合成"，宝箱分类显示"打开"）
	_合成按钮 = Button.new()
	_合成按钮.name = "CraftBtn"
	_合成按钮.flat = true
	_合成按钮.text = "炼化"
	_place(_合成按钮, 0.0, 0.0, 268.0, 46.0)
	_合成按钮.mouse_filter = Control.MOUSE_FILTER_STOP
	UITheme.apply_title_font_sized(_合成按钮, _fs(16))
	_合成按钮.add_theme_color_override("font_color", C_EQUIP_BTN_TEXT)
	_合成按钮.add_theme_stylebox_override("normal", _make_equip_stylebox())
	_合成按钮.add_theme_stylebox_override("pressed", _make_equip_stylebox())
	_合成按钮.add_theme_stylebox_override("hover", _make_equip_stylebox())
	_合成按钮.add_theme_stylebox_override("focus", _make_equip_stylebox())
	_合成按钮.pressed.connect(_on_action_pressed.bind("合成"))
	_合成按钮.visible = false
	bar.add_child(_合成按钮)

	# 出售渠道定位提示（按钮正下方空档，全宽不挡左侧「使用」键）
	# 双轨制固化：库藏全价渠道仅限 基础灵材(草药/矿石)/基础丹药；装备/碎片/特殊道具须走坊市回收
	_出售提示 = Label.new()
	_出售提示.name = "SellChannelHint"
	_出售提示.text = "仅灵材 / 丹药可售 · 全额结算"
	_place(_出售提示, 0.0, 48.0, 448.0, 20.0)
	UITheme.apply_aux_text(_出售提示)
	_出售提示.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	_出售提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_出售提示)

	# 按当前分类初始化底部按钮文案/可见性
	_刷新操作按钮(_当前分类)

# ───────── 只读刷新（零 GameState 写入）─────────
func refresh() -> void:
	if not _built:
		_build()
	_populate()

func _库房() -> Array:
	var 库房: Array = []
	if is_instance_valid(Game):
		var v = Game.get("宗门库房")
		if v is Array:
			库房 = v.duplicate()
		# 添加碎片物品
		if Game.has_method("获取碎片数量"):
			var 碎片库存 = Game.get("碎片库存")
			if 碎片库存 is Dictionary:
				for 碎片ID in 碎片库存.keys():
					var 数量: int = int(碎片库存[碎片ID])
					if 数量 > 0:
						# 从FragmentCraftSystem获取碎片信息
						var 配方: Dictionary = {}
						if FragmentCraftSystem.合成配方库.has(碎片ID):
							配方 = FragmentCraftSystem.合成配方库[碎片ID]
						库房.append({
							"名称": str(配方.get("名称", 碎片ID)),
							"类别": "碎片",
							"品阶": "凡品",
							"数量": 数量,
							"描述": str(配方.get("描述", "碎片物品")),
							"碎片ID": 碎片ID
						})
		# 添加宝箱物品
		if Game.has_method("获取宝箱数量"):
			var 宝箱库存 = Game.get("宝箱库存")
			if 宝箱库存 is Dictionary:
				for 宝箱ID in 宝箱库存.keys():
					var 数量: int = int(宝箱库存[宝箱ID])
					if 数量 > 0:
						# 从ChestSystem获取宝箱信息
						var 宝箱信息: Dictionary = {}
						if ChestSystem.宝箱掉落池.has(宝箱ID):
							宝箱信息 = ChestSystem.宝箱掉落池[宝箱ID]
						库房.append({
							"名称": str(宝箱信息.get("名称", 宝箱ID)),
							"类别": "宝箱",
							"品阶": "凡品",
							"数量": 数量,
							"描述": str(宝箱信息.get("描述", "宝箱物品")),
							"宝箱ID": 宝箱ID
						})
	return 库房

func _populate(items_override: Array = []) -> void:
	var all: Array = items_override if not items_override.is_empty() else _库房()
	if _容量标签 != null:
		_容量标签.text = "%d / %d" % [all.size(), 容量上限]
	if _网格 == null:
		return
	for child in _网格.get_children():
		_网格.remove_child(child)
		child.queue_free()
	_格子列表.clear()

	var items: Array = _筛选项(_当前分类, all)
	_槽位数 = mini(容量上限, maxi(可见基础槽数, items.size() + (每行列数 - items.size() % 每行列数) % 每行列数))

	var idx: int = 0
	for it in items:
		var cell: Button = _make_cell(it, idx)
		_网格.add_child(cell)
		_格子列表.append({"btn": cell, "badge": cell.get_node("CornerBadge"), "it": it, "index": idx})
		idx += 1
	while idx < _槽位数:
		var empty: Control = _make_empty_cell(idx)
		_网格.add_child(empty)
		idx += 1

	if items.size() > 0:
		_选中索引 = 0
	else:
		_选中索引 = -1
	_刷新格子样式()
	_刷新详情()

func _筛选项(cat: String, all: Array) -> Array:
	var res: Array = []
	for it in all:
		var 类别: String = ""
		if it is Object:
			类别 = it.get("类别")
		elif it is Dictionary:
			类别 = str(it.get("类别", ""))
		match cat:
			"全部":
				res.append(it)
			"装备":
				if 类别 in ["法器", "神兵", "法宝"]:
					res.append(it)
			"丹药":
				if 类别 == "丹药":
					res.append(it)
			"材料":
				if 类别 == "灵材":
					res.append(it)
			"功法", "灵兽":
				pass
			"碎片":
				if 类别 == "碎片":
					res.append(it)
			"宝箱":
				if 类别 == "宝箱":
					res.append(it)
	return res

func _make_cell(it: Variant, idx: int) -> Button:
	var btn := Button.new()
	btn.name = "Cell_%d" % idx
	btn.flat = true
	btn.text = ""
	btn.custom_minimum_size = Vector2(_ip(格尺寸), _ip(格尺寸))
	btn.size = Vector2(_ip(格尺寸), _ip(格尺寸))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_cell_pressed.bind(idx))

	var qc: Color = _品阶色(it)
	btn.add_theme_stylebox_override("normal", _make_cell_stylebox(qc, false))
	btn.add_theme_stylebox_override("hover", _make_cell_stylebox(qc, false))
	btn.add_theme_stylebox_override("focus", _make_cell_stylebox(qc, false))
	btn.add_theme_stylebox_override("pressed", _make_cell_stylebox(qc, false))

	var txt := Label.new()
	txt.name = "CellText"
	txt.text = _品阶缩写(it) + "×1"
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(txt, 0.0, 0.0, float(格尺寸), float(格尺寸))
	UITheme.apply_body_font_sized(txt, _fs(13))
	txt.add_theme_color_override("font_color", UITheme.C01_TEXT_SECONDARY)
	btn.add_child(txt)

	var badge := TextureRect.new()
	badge.name = "CornerBadge"
	badge.texture = _make_corner_badge_tex()
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(badge, 48.0, 0.0, 16.0, 16.0)
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)

	return btn

func _make_empty_cell(idx: int) -> Control:
	var p := Panel.new()
	p.name = "Empty_%d" % idx
	p.custom_minimum_size = Vector2(_ip(格尺寸), _ip(格尺寸))
	p.size = Vector2(_ip(格尺寸), _ip(格尺寸))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CELL_EMPTY_BG
	sb.border_color = C_CELL_EMPTY_STROKE
	sb.set_corner_radius_all(_rc(8))
	sb.set_border_width_all(_bw(1))
	p.add_theme_stylebox_override("panel", sb)

	var txt := Label.new()
	txt.name = "EmptyText"
	txt.text = "空"
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(txt, 0.0, 0.0, float(格尺寸), float(格尺寸))
	UITheme.apply_body_font_sized(txt, _fs(13))
	txt.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	p.add_child(txt)
	return p

func _make_cell_stylebox(border: Color, selected: bool) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_SELECTED_FILL if selected else C_CELL_BG
	sb.border_color = C_SELECTED_STROKE if selected else border
	sb.set_corner_radius_all(_rc(8))
	sb.set_border_width_all(_bw(2 if selected else 1))
	return sb

func _make_equip_stylebox() -> StyleBox:
	var grad: Gradient = Gradient.new()
	grad.set_color(0, C_EQUIP_BTN_BG1)
	grad.set_color(1, C_EQUIP_BTN_BG2)
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(1.0, 0.0)
	gt.width = _ip(268)
	gt.height = _ip(46)
	var st := StyleBoxTexture.new()
	st.texture = gt
	st.set_content_margin_all(0)
	return st

# ───────── 交互 ─────────
func _on_cell_pressed(idx: int) -> void:
	if idx < 0 or idx >= _格子列表.size():
		return
	_选中索引 = idx
	_刷新格子样式()
	_刷新详情()

func _on_cat_pressed(cat: String) -> void:
	_当前分类 = cat
	# 更新下划线可见性
	for c in _分类下划线.keys():
		var line: Panel = _分类下划线[c]
		line.visible = (c == cat)
	# 重找分类按钮更新样式（在分类栏容器内）
	var container: Node = _分类栏 if _分类栏 != null else self
	for child in container.get_children():
		if child is Button and child.name.begins_with("Cat_"):
			var cname: String = child.name.substr(4)
			_update_cat_style(child, cname == cat)
	# 按分类切换底部操作按钮（装备→装备/出售；丹药→使用/出售；材料→出售）
	_刷新操作按钮(cat)
	_populate()

func _on_back_pressed() -> void:
	返回主页.emit()

func _on_tidy_pressed() -> void:
	if not is_instance_valid(Game):
		return
	# 真接入：调 game_state.整理库房()（按 品阶倒序 + 类别字典序），save_game 持久化
	var sorted: Array = Game.整理库房() if Game.has_method("整理库房") else _本地整理()
	_populate(sorted)
	print("[库藏] 整理完成：%d 件" % sorted.size())

func _本地整理() -> Array:
	# Game 缺方法时的兜底（不写 GameState，纯本地排序）
	var sorted: Array = _库房().duplicate()
	sorted.sort_custom(_sort_by_tier)
	return sorted

func _sort_by_tier(a: Variant, b: Variant) -> bool:
	var oa: Array = ["道阶", "仙阶", "圣阶", "王阶", "宝阶", "灵阶", "凡阶"]
	return oa.find(_品阶(a)) < oa.find(_品阶(b))

func _刷新操作按钮(cat: String) -> void:
	# 按分类切换底部按钮的文案与可见性。
	# 装备：装备 | 出售（两者 S1 红线门控占位）
	# 丹药：使用 | 出售（使用门控 / 出售真发灵石）
	# 材料：—— | 出售（一个按钮，另一隐藏）
	# 碎片：合成（隐藏装备/出售，只显示合成）
	# 宝箱：打开（隐藏装备/出售，只显示打开）
	# 功法/灵兽/全部：所有按钮隐藏
	if _装备按钮 == null or _出售按钮 == null or _合成按钮 == null:
		return
	if _出售提示 != null:
		# 提示仅对应「库藏全价渠道可售品类」：丹药 / 材料(灵材)
		_出售提示.visible = (cat in ["丹药", "材料"])
	match cat:
		"装备":
			_装备按钮.visible = true
			_出售按钮.visible = true
			_合成按钮.visible = false
			_装备按钮.text = "披挂"
			_出售按钮.text = "售卖"
			_出售按钮.disabled = true
		"丹药":
			_装备按钮.visible = true
			_出售按钮.visible = true
			_合成按钮.visible = false
			_装备按钮.text = "服用"
			_出售按钮.text = "售卖"
			_出售按钮.disabled = false
		"材料":
			_装备按钮.visible = false
			_出售按钮.visible = true
			_合成按钮.visible = false
			_出售按钮.text = "售卖"
			_出售按钮.disabled = false
		"碎片":
			_装备按钮.visible = false
			_出售按钮.visible = false
			_合成按钮.visible = true
			_合成按钮.text = "炼化"
		"宝箱":
			_装备按钮.visible = false
			_出售按钮.visible = false
			_合成按钮.visible = true
			_合成按钮.text = "启封"
		_:
			_装备按钮.visible = false
			_出售按钮.visible = false
			_合成按钮.visible = false

func _on_action_pressed(kind: String) -> void:
	# 按当前分类分派；装备 Tab 完全 S1 红线门控；材料/丹药的出售真发灵石；丹药"使用" 暂门控。
	# 碎片：合成（调用Game.执行碎片合成）
	# 宝箱：打开（调用Game.打开宝箱）
	if _选中索引 < 0 or _选中索引 >= _格子列表.size():
		return
	var it: Variant = _格子列表[_选中索引].it
	if it == null:
		return
	var 类别: String = ""
	if it is Object:
		类别 = str(it.get("类别", ""))
	elif it is Dictionary:
		类别 = str(it.get("类别", ""))
	match _当前分类:
		"装备":
			print("[库藏] %s：装备系统 S1 红线门控（玩法系统接入后开放）" % kind)
		"丹药":
			if kind == "使用":
				print("[库藏] 丹药使用系统接入后开放")
			elif kind == "出售":
				_真出售(it, 类别)
		"材料":
			if kind == "出售":
				_真出售(it, 类别)
		"碎片":
			if kind == "合成":
				_合成碎片(it)
		"宝箱":
			if kind == "合成":
				_打开宝箱(it)
		_:
			print("[库藏] 未知分类操作：%s / %s" % [_当前分类, kind])

# 合成碎片
func _合成碎片(it: Dictionary) -> void:
	if not is_instance_valid(Game):
		return
	if not Game.has_method("执行碎片合成"):
		print("[库藏] 执行碎片合成 API 不存在")
		return
	var 碎片ID: String = str(it.get("碎片ID", ""))
	if 碎片ID == "":
		print("[库藏] 碎片ID为空")
		return
	var 结果: Dictionary = Game.执行碎片合成(碎片ID)
	if 结果.get("成功", false):
		print("[库藏] 合成成功：%s" % str(结果.get("原因", "")))
	else:
		print("[库藏] 合成失败：%s" % str(结果.get("原因", "")))
	_populate()

# 打开宝箱
func _打开宝箱(it: Dictionary) -> void:
	if not is_instance_valid(Game):
		return
	if not Game.has_method("打开宝箱"):
		print("[库藏] 打开宝箱 API 不存在")
		return
	var 宝箱ID: String = str(it.get("宝箱ID", ""))
	if 宝箱ID == "":
		print("[库藏] 宝箱ID为空")
		return
	var 结果: Dictionary = Game.打开宝箱(宝箱ID)
	if 结果.get("成功", false):
		var 掉落文本: String = ""
		for 掉落 in 结果.get("掉落列表", []):
			掉落文本 += "%s×%d " % [str(掉落.get("物品ID", "")), int(掉落.get("数量", 1))]
		print("[库藏] 打开成功：获得 %s" % 掉落文本)
	else:
		print("[库藏] 打开失败：%s" % str(结果.get("原因", "")))
	_populate()

func _真出售(it: Variant, 类别: String) -> void:
	if not is_instance_valid(Game):
		return
	if not Game.has_method("出售库房物品"):
		print("[库藏] 出售 API 不存在")
		return
	var 价: int = Game.出售库房物品(it)
	if 价 > 0:
		print("[库藏] 出售成功：%s 折算灵石 +%d" % [_名称(it), 价])
		_populate()
	else:
		print("[库藏] 出售失败：%s（库藏全价渠道仅 基础灵材[草药/矿石]/基础丹药 可售，不含任何碎片类衍生材料；装备、碎片、特殊道具请走坊市回收·市价60%）" % _名称(it))

# ───────── 视觉刷新 ─────────
func _刷新格子样式() -> void:
	for i in range(_格子列表.size()):
		var c: Dictionary = _格子列表[i]
		var btn: Button = c.btn
		var badge: TextureRect = c.badge
		var it: Variant = c.it
		var sel: bool = (i == _选中索引)
		var qc: Color = _品阶色(it)
		btn.add_theme_stylebox_override("normal", _make_cell_stylebox(qc, sel))
		btn.add_theme_stylebox_override("hover", _make_cell_stylebox(qc, sel))
		btn.add_theme_stylebox_override("focus", _make_cell_stylebox(qc, sel))
		btn.add_theme_stylebox_override("pressed", _make_cell_stylebox(qc, sel))
		badge.visible = sel
		var txt: Label = btn.get_node("CellText")
		if sel:
			UITheme.apply_title_font_sized(txt, _fs(13))
			txt.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
		else:
			UITheme.apply_body_font_sized(txt, _fs(13))
			txt.add_theme_color_override("font_color", UITheme.C01_TEXT_SECONDARY)

func _刷新详情() -> void:
	if _详情名 == null:
		return
	if _选中索引 < 0 or _选中索引 >= _格子列表.size():
		_详情名.text = "—"
		_详情品阶.text = "—"
		_详情类别.text = ""
		_详情描述.text = "（点选上方物品查看详情）"
		_详情属性.text = ""
		_详情图标字.text = ""
		return
	var it: Variant = _格子列表[_选中索引].it
	var tier: String = _品阶(it)
	var qc: Color = _品阶色(it)
	_详情名.text = _名称(it)
	_详情品阶.text = tier
	_详情图标字.text = 品阶缩写.get(tier, "凡") + "×1"

	var 类别: String = ""
	var 穿戴位: String = ""
	var 道途: String = ""
	var 战力: int = 0
	var 描: String = ""
	var 词缀列表 = null
	var 极品标记: bool = false
	var 数量: int = 1
	if it is Object:
		类别 = str(it.get("类别", ""))
		穿戴位 = str(it.get("穿戴位", ""))
		道途 = str(it.get("道途", ""))
		var zhanli = it.get("战力加成")
		if zhanli != null:
			战力 = int(zhanli)
		var d = it.get("描述")
		if d != null:
			描 = String(d)
		词缀列表 = it.get("词缀")
		极品标记 = it.get("极品") == true
	elif it is Dictionary:
		类别 = str(it.get("类别", ""))
		描 = str(it.get("描述", ""))
		数量 = int(it.get("数量", 1))

	# 详情图标字：品阶缩写×数量
	_详情图标字.text = 品阶缩写.get(tier, "凡") + "×" + str(数量)

	# 类别标签：装备 Tab 显示「· 穿戴位」，丹药/材料 Tab 显示「· 类别中文名」
	var cat_display: String = Item.类别中文名.get(类别, 类别)
	var slot_display: String = Item.槽显示.get(穿戴位, 穿戴位)
	if _当前分类 == "装备" and slot_display != "":
		_详情类别.text = "· " + slot_display
	elif cat_display != "":
		_详情类别.text = "· " + cat_display
	else:
		_详情类别.text = ""
	_详情描述.text = 描 if 描 != "" else "（尚无描述）"

	# 详情图标描边随物品品阶色
	var isb: StyleBoxFlat = _详情图标.get_theme_stylebox("panel")
	if isb != null:
		isb.border_color = qc
		_详情图标.add_theme_stylebox_override("panel", isb)

	var lines: Array = []
	# 仅装备 Tab 显示装备专属字段（战力/道途/词缀/极品），丹药/材料隐藏
	if _当前分类 == "装备":
		if 战力 != 0:
			lines.append("战力 +%d" % 战力)
		if 道途 != "":
			lines.append("道途：%s" % 道途)
		if 词缀列表 is Array and 词缀列表.size() > 0:
			var s: String = "词缀："
			for a in 词缀列表:
				var 名: String = Item.词缀中文名.get(a.get("名", ""), a.get("名", ""))
				var 档: String = Item.词缀档中文名.get(a.get("档", ""), a.get("档", ""))
				s += "%s %d(%s)  " % [名, int(a.get("数值", 0)), 档]
			lines.append(s)
		if 极品标记:
			lines.append("★ 极品特异")
	elif _当前分类 == "碎片":
		# 碎片 Tab 显示数量和合成提示
		lines.append("持有数量：%d" % 数量)
		lines.append("点击「合成」按钮进行合成")
	elif _当前分类 == "宝箱":
		# 宝箱 Tab 显示数量和打开提示
		lines.append("持有数量：%d" % 数量)
		lines.append("点击「开启」按钮开启宝箱")
	else:
		# 丹药/材料 Tab 显示购买参考价（按品阶折算灵石），给出售决策给个锚点
		lines.append("出售参考价：%d 灵石" % _品阶售价_本地(it))
	_详情属性.text = "    ".join(lines)

# ───────── 物品字段安全读取（RefCounted 守卫）─────────
func _名称(it: Variant) -> String:
	if it is Object:
		var v = it.get("名称")
		if v != null:
			return String(v)
	elif it is Dictionary:
		return str(it.get("名称", "—"))
	return "—"

func _品阶(it: Variant) -> String:
	if it is Object:
		var v = it.get("品阶")
		if v != null:
			return String(v)
	elif it is Dictionary:
		return str(it.get("品阶", "凡阶"))
	return "凡阶"

func _品阶色(it: Variant) -> Color:
	return UIThemeConfig.get_quality_color(品阶_TO_TIER.get(_品阶(it), "fan"))

func _品阶缩写(it: Variant) -> String:
	return 品阶缩写.get(_品阶(it), "凡")

# 本地只读的品阶售价映射（仅给 UI 详情面板展示参考价，不写 GameState）
# 与 game_state._品阶售价 同源（保持一致），避免 UI 与引擎显示脱节
func _品阶售价_本地(it: Variant) -> int:
	var 表: Dictionary = {"凡阶": 10, "灵阶": 30, "宝阶": 80, "王阶": 200, "圣阶": 500, "仙阶": 1200, "道阶": 3000}
	return int(表.get(_品阶(it), 10))

# ───────── 纹理 / 样式 helper ─────────
func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	var s: float = UITheme.UI_SCALE
	c.layout_mode = 0
	c.offset_left = x * s
	c.offset_top = y * s
	c.offset_right = (x + w) * s
	c.offset_bottom = (y + h) * s
	c.size = Vector2(w * s, h * s)

func _fs(design_px: int) -> int:
	# 字号收口到统一阶梯（消除跨页尺寸漂移）：design px → 标准渲染尺寸
	if design_px <= 12:
		return UITheme.FONT_AUX
	elif design_px <= 14:
		return UITheme.FONT_BODY
	elif design_px <= 17:
		return UITheme.FONT_H2
	return UITheme.FONT_TITLE

func _ip(design_px: int) -> int:
	return int(round(float(design_px) * UITheme.UI_SCALE))

func _rc(design_px: int) -> int:
	return int(round(float(design_px) * UITheme.UI_SCALE))

func _bw(design_px: int) -> int:
	return maxi(1, int(round(float(design_px) * UITheme.UI_SCALE)))

func _make_corner_badge_tex() -> Texture2D:
	var svg: String = "<svg width=\"16\" height=\"16\" viewBox=\"0 0 16 16\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M16 0 L16 16 L0 0 Z\" fill=\"#E8C572\"/></svg>"
	var img := Image.new()
	img.load_svg_from_string(svg, 2.0)
	return ImageTexture.create_from_image(img)

extends Control

# 装备图纸系统页面（增强版）
# 展示已解锁装备图纸列表和图纸商店，支持解锁图纸、锻造装备等操作
# ★ PH7-09 逐页精修（2026-09-18）：手搓 60 高顶栏 → 全站统一 建顶栏；手搓标签栏 → 建标签栏；
#   详情面板字号 16/13 → 27/21（FONT_BODY/FONT_AUX，对齐全站最小字号档）；11 处硬编码色 const → UITheme token。
#   几何仍走绝对定位（game_ui 不约束子页高度，VBox 流式会把页撑到视口外 ⇒ 详情面板掉出屏幕）。
# ★ PH7-10 逐页精修（2026-09-19）：修 B1 锻造失败静默/B2 解锁失败静默/B5 空态按钮可见却静默；
#   F1 数量硬编码20误当灵石消耗（白扣灵石只产1件）→ 数量选择×1/×10/×50/最大＋材料预检循环锻造；
#   D1 缺锻造氛围 → 炉火火星粒子；A3 列表行材料名过长截断。F2 锻造回执后端已写纪事，不动。

signal 返回主页

var _built: bool = false
var _当前标签: String = "已解锁"  # "已解锁" 或 "商店"
var _选中索引: int = -1
var _图纸列表: Array = []
var _商店列表: Array = []

# ★ PH7-10：锻造数量选择（<=0 表示「最大」＝按矿石上限实时算）
var _锻造数量: int = 1
var _数量按钮: Dictionary = {}
var _数量行: HBoxContainer = null
var _炉火: GPUParticles2D = null

# ★ PH7-10：与 game_state.gd:9107 锻造装备 品阶→矿石需求映射严格一致
const _品阶矿石需求: Dictionary = {
	"凡阶": 5, "灵阶": 8, "宝阶": 12, "王阶": 18,
	"圣阶": 25, "仙阶": 35, "道阶": 50,
}

# 根据图纸信息生成描述
func _生成图纸描述(图纸: Dictionary) -> String:
	var 名称 = 图纸.get("名称", "无名图纸")
	var 品阶 = 图纸.get("品阶", "凡阶")
	var 材料 = 图纸.get("材料", "未知材料")
	var 效果 = 图纸.get("效果", "未知效果")
	var 品阶描述 = {
		"凡阶": "入门级装备图纸，工艺简单，适合初入器道的弟子研习。",
		"灵阶": "精修级装备图纸，融入灵气回路，可锻造蕴含灵气的装备。",
		"宝阶": "珍本级装备图纸，宗门珍藏，非核心弟子不可传授。",
		"王阶": "秘典级装备图纸，历代器道宗师心血结晶，可锻造王者之器。",
		"圣阶": "圣级装备图纸，上古传承，蕴含器道至理，可锻造圣器。",
		"仙阶": "仙级装备图纸，仙界流传，凡人得之可锻造仙器。",
		"道阶": "道级装备图纸，大道所化，可锻造蕴含大道之力的道器。",
	}
	var 基础描述 = 品阶描述.get(品阶, "珍贵图纸，工艺精湛。")
	return "《%s》\n\n%s\n\n所需材料：%s\n锻造效果：%s\n\n解锁图纸后，可在器堂按照图纸锻造装备。品阶越高的图纸，所需材料越珍贵，锻造出的装备也越强。" % [名称, 基础描述, 材料, 效果]

var _bg: ColorRect
var _tab_btns: Dictionary = {}
var _列表: VBoxContainer
var _详情面板: Panel
var _详情名: Label
var _详情品阶: Label
var _详情材料: Label
var _详情效果: Label
var _详情状态: Label
var _详情价格: Label
var _锻造按钮: Button
var _解锁按钮: Button

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
	
	# 背景（统一页面底色，覆盖山门场景，保持工业化纯色底）
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = UITheme.获取页面底色()
	add_child(_bg)
	
	# ★ PH7-09 精修：手搓 60 高顶栏（Panel＋折返方钮＋标题）→ 全站统一 建顶栏
	#   （含返回环 + apply_page_title）。PRESET_TOP_WIDE 拉满宽度；custom_minimum_size.y=72
	#   作为高度下限（锚点 bottom=0 时高度归 0，靠 min 兜底）。
	var 顶栏: PanelContainer = UITheme.建顶栏("器谱阁", _on返回)
	顶栏.set_anchors_preset(Control.PRESET_TOP_WIDE)
	顶栏.custom_minimum_size = Vector2(0, 72)
	add_child(顶栏)
	
	# 标签栏：已习得 / 图谱坊市（收口到 建标签栏，最小宽 100 + EXPAND_FILL 均分）。
	var 标签栏: HBoxContainer = HBoxContainer.new()
	标签栏.set_anchors_preset(Control.PRESET_TOP_WIDE)
	标签栏.offset_top = 72
	标签栏.custom_minimum_size = Vector2(0, 40)
	add_child(标签栏)
	_tab_btns = UITheme.建标签栏(标签栏, ["已习得", "图谱坊市"], Callable(self, "_切换标签"), _当前标签)
	
	# 列表区域
	var 列表区域 = ScrollContainer.new()
	列表区域.set_anchors_preset(Control.PRESET_FULL_RECT)
	列表区域.offset_top = 112
	列表区域.offset_bottom = -314
	列表区域.offset_left = 10
	列表区域.offset_right = -10
	add_child(列表区域)
	
	_列表 = VBoxContainer.new()
	_列表.set_anchors_preset(Control.PRESET_FULL_RECT)
	_列表.add_theme_constant_override("separation", 8)
	列表区域.add_child(_列表)
	
	# 详情面板
	_详情面板 = Panel.new()
	# 修复（实机验收抓出 · 2026-09-12）：BOTTOM_WIDE 只改 anchors（top=bottom=1），
	# offsets 仍为 0 → 面板被算到父容器底边之下（屏幕外）；custom_minimum_size 只撑高度、
	# 不把位置拉回视口。对照 page_world_map_visual 的 legend（显式 offset_top=-52）补齐偏移。
	_详情面板.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_详情面板.custom_minimum_size = Vector2(0, 250)
	# ★ 2026-09-16 修（#009 逐页精修 · 老模板）：详情面板原 offset_bottom = 0 ⇒ 贴死屏幕
	#   下沿，面板内操作按钮触底。下移 MARGIN（24 逻辑 = 54 设计），与列表区 offset_bottom 同步。
	# ★ PH7-09 精修：原 190 高容不下 27/21 字号后的 6 行 + 按钮行，提到 250 并收紧内容间距。
	#   offset_top=-304 / offset_bottom=-54 ⇒ 高 250，顶边 y=1616、底边 y=1866（页高 1731，安全边距 54）。
	_详情面板.offset_top = -304
	_详情面板.offset_bottom = -54
	_详情面板.offset_left = 10
	_详情面板.offset_right = -10
	_详情面板.add_theme_stylebox_override("panel", create_stylebox(UITheme.获取面板底色(), UITheme.COLOR_BORDER_GOLD))
	add_child(_详情面板)
	
	# 详情内容
	var 详情内容 = VBoxContainer.new()
	详情内容.set_anchors_preset(Control.PRESET_FULL_RECT)
	详情内容.add_theme_constant_override("separation", 2)
	详情内容.offset_left = 15
	详情内容.offset_top = 10
	详情内容.offset_right = -15
	详情内容.offset_bottom = -10
	_详情面板.add_child(详情内容)
	
	_详情名 = create_label("名称：-", UITheme.FONT_BODY, UITheme.COLOR_TEXT_GOLD)
	详情内容.add_child(_详情名)
	
	_详情品阶 = create_label("品阶：-", UITheme.FONT_AUX)
	详情内容.add_child(_详情品阶)
	
	_详情材料 = create_label("材料：-", UITheme.FONT_AUX)
	详情内容.add_child(_详情材料)
	
	_详情效果 = create_label("效果：-", UITheme.FONT_AUX)
	详情内容.add_child(_详情效果)
	
	_详情状态 = create_label("状态：-", UITheme.FONT_AUX, UITheme.COLOR_STATUS_SUCCESS)
	详情内容.add_child(_详情状态)
	
	_详情价格 = create_label("", UITheme.FONT_AUX, UITheme.COLOR_TEXT_RED)
	详情内容.add_child(_详情价格)
	
	# ★ PH7-10：锻造数量选择行（×1 / ×10 / ×50 / 最大）。最大＝按矿石上限实时算。
	var 数量行 = HBoxContainer.new()
	数量行.add_theme_constant_override("separation", 6)
	详情内容.add_child(数量行)
	数量行.add_child(create_label("炼制：", UITheme.FONT_AUX, UITheme.COLOR_TEXT_BODY_GOLD))
	var 数量选项: Array = [
		{"标签": "×1", "值": 1},
		{"标签": "×10", "值": 10},
		{"标签": "×50", "值": 50},
		{"标签": "最大", "值": -1},
	]
	for 选项 in 数量选项:
		var 钮 = Button.new()
		钮.text = 选项["标签"]
		钮.custom_minimum_size = Vector2(54, 30)
		钮.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		UITheme.apply_project_font(钮, UITheme.FONT_AUX, false)
		var 值 = 选项["值"]
		钮.set_meta("值", 值)
		钮.pressed.connect(func(): _on选数量(值))
		数量行.add_child(钮)
		钮.modulate.a = 0.0
		钮.create_tween().tween_property(钮, "modulate:a", 1.0, 0.25)
		_数量按钮[选项["标签"]] = 钮
	_数量行 = 数量行
	_刷新数量按钮()
	
	# 按钮区域
	var 按钮区域 = HBoxContainer.new()
	按钮区域.add_theme_constant_override("separation", 10)
	详情内容.add_child(按钮区域)
	
	_锻造按钮 = Button.new()
	_锻造按钮.text = "炼器"
	UITheme.apply_project_font(_锻造按钮, UITheme.FONT_BODY, false)
	_锻造按钮.pressed.connect(_on锻造装备)
	按钮区域.add_child(_锻造按钮)
	
	_解锁按钮 = Button.new()
	_解锁按钮.text = "习得图谱"
	UITheme.apply_project_font(_解锁按钮, UITheme.FONT_BODY, false)
	_解锁按钮.pressed.connect(_on解锁图纸)
	按钮区域.add_child(_解锁按钮)
	
	# ★ PH7-10：锻造炉火氛围（暖橙火星，零美术依赖，对称丹烟）
	_build_炉火()

func create_label(text: String, size: int = 14, color: Color = Color.WHITE) -> Label:
	var 标签 = Label.new()
	标签.text = text
	UITheme.apply_project_font(标签, size, false)
	标签.add_theme_color_override("font_color", color)
	return 标签

func create_stylebox(bg_color: Color, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = bg_color
	if border_color != Color.TRANSPARENT:
		stylebox.border_color = border_color
		stylebox.set_border_width_all(1)
	return stylebox

func _切换标签(标签: String) -> void:
	_当前标签 = 标签
	_选中索引 = -1
	# ★ PH7-09 精修：手搓 stylebox 切换 → 统一 刷新标签高亮（选中全亮/未选压暗 0.6 全局口径）。
	UITheme.刷新标签高亮(_tab_btns, 标签)
	refresh()

func refresh() -> void:
	for _c in _列表.get_children():
		_c.queue_free()
	
	if _当前标签 == "已解锁":
		_图纸列表 = Game.获取已解锁装备图纸列表()
		if _图纸列表.is_empty():
			_列表.add_child(UITheme.建空态("尚未习得图谱，可往「图谱坊市」一观"))
			_更新详情()
			return
		for i in _图纸列表.size():
			var 图纸 = _图纸列表[i]
			var 材料文本 = 图纸.get("材料", "")
			if typeof(材料文本) == TYPE_STRING and 材料文本.length() > 10:
				材料文本 = 材料文本.substr(0, 10) + "…"
			var 行 = Button.new()
			行.text = "%s（%s）- 材料：%s" % [图纸.get("名称", ""), 图纸.get("品阶", ""), 材料文本]
			行.custom_minimum_size = Vector2(0, 45)
			UITheme.apply_project_font(行, UITheme.FONT_BODY, false)
			if i == _选中索引:
				行.add_theme_stylebox_override("normal", create_stylebox(Color(UITheme.COLOR_BORDER_GOLD, 0.35)))
			var 索引 = i
			行.pressed.connect(func(): _on选中图纸(索引))
			_列表.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	else:
		_商店列表 = Game.获取图纸商店列表()
		if _商店列表.is_empty():
			_列表.add_child(UITheme.建空态("坊市尚无此物"))
			_更新详情()
			return
		for i in _商店列表.size():
			var 商品 = _商店列表[i]
			var 状态文本 = "已解锁" if 商品.get("已解锁", false) else "%d灵石" % 商品.get("价格", 0)
			var 材料文本 = 商品.get("材料", "")
			if typeof(材料文本) == TYPE_STRING and 材料文本.length() > 10:
				材料文本 = 材料文本.substr(0, 10) + "…"
			var 行 = Button.new()
			行.text = "%s（%s）- %s" % [商品.get("名称", ""), 商品.get("品阶", ""), 状态文本]
			行.custom_minimum_size = Vector2(0, 45)
			UITheme.apply_project_font(行, UITheme.FONT_BODY, false)
			if 商品.get("已解锁", false):
				行.add_theme_color_override("font_color", UITheme.COLOR_STATUS_SUCCESS)
			if i == _选中索引:
				行.add_theme_stylebox_override("normal", create_stylebox(Color(UITheme.COLOR_BORDER_GOLD, 0.35)))
			var 索引 = i
			行.pressed.connect(func(): _on选中商品(索引))
			_列表.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	
	_更新详情()

func _更新详情() -> void:
	if _当前标签 == "已解锁":
		if _选中索引 < 0 or _选中索引 >= _图纸列表.size():
			_详情名.text = "名称：-"
			_详情品阶.text = "品阶：-"
			_详情材料.text = "材料：-"
			_详情效果.text = "效果：-"
			_详情状态.text = "状态：-"
			_详情价格.text = ""
			_锻造按钮.visible = true
			_解锁按钮.visible = false
			_数量行.visible = false
			return
		var 图纸 = _图纸列表[_选中索引]
		_详情名.text = "名称：%s" % 图纸.get("名称", "")
		_详情品阶.text = "品阶：%s" % 图纸.get("品阶", "")
		_详情材料.text = "材料：%s" % 图纸.get("材料", "")
		_详情效果.text = "效果：%s" % 图纸.get("效果", "")
		_详情状态.text = "状态：已解锁，可以锻造"
		_详情价格.text = _生成图纸描述(图纸)
		_锻造按钮.visible = true
		_解锁按钮.visible = false
		_数量行.visible = true
	else:
		if _选中索引 < 0 or _选中索引 >= _商店列表.size():
			_详情名.text = "名称：-"
			_详情品阶.text = "品阶：-"
			_详情材料.text = "材料：-"
			_详情效果.text = "效果：-"
			_详情状态.text = "状态：-"
			_详情价格.text = ""
			_锻造按钮.visible = false
			_解锁按钮.visible = true
			_数量行.visible = false
			return
		var 商品 = _商店列表[_选中索引]
		_详情名.text = "名称：%s" % 商品.get("名称", "")
		_详情品阶.text = "品阶：%s" % 商品.get("品阶", "")
		_详情材料.text = "材料：%s" % 商品.get("材料", "")
		_详情效果.text = "效果：%s" % 商品.get("效果", "")
		if 商品.get("已解锁", false):
			_详情状态.text = "状态：已解锁"
			_详情价格.text = ""
			_解锁按钮.text = "已解锁"
			_解锁按钮.disabled = true
		else:
			_详情状态.text = "状态：未解锁"
			_详情价格.text = "价格：%d灵石" % 商品.get("价格", 0)
			_解锁按钮.text = "解锁图纸"
			_解锁按钮.disabled = false
		_锻造按钮.visible = false
		_解锁按钮.visible = true
		_数量行.visible = false

func _on返回() -> void:
	返回主页.emit()

func _on选中图纸(索引: int) -> void:
	_选中索引 = 索引
	refresh()

func _on选中商品(索引: int) -> void:
	_选中索引 = 索引
	refresh()

func _on选数量(值: int) -> void:
	_锻造数量 = 值
	_刷新数量按钮()

func _刷新数量按钮() -> void:
	for 标签 in _数量按钮.keys():
		var 钮 = _数量按钮[标签]
		var 钮值 = 钮.get_meta("值", 0)
		var 选中 = (_锻造数量 <= 0 and 钮值 == -1) or (_锻造数量 > 0 and 钮值 == _锻造数量)
		if 选中:
			钮.add_theme_stylebox_override("normal", create_stylebox(Color(UITheme.COLOR_BORDER_GOLD, 0.35)))
		else:
			钮.remove_theme_stylebox_override("normal")

func _on锻造装备() -> void:
	if _选中索引 < 0 or _选中索引 >= _图纸列表.size():
		Game.添加提示("尚未择定图谱")
		return
	var 图纸 = _图纸列表[_选中索引]
	var 图纸ID = 图纸.get("图纸ID", "")
	var 品阶 = 图纸.get("品阶", "凡阶")
	var 需要矿石 = _品阶矿石需求.get(品阶, 5)
	# ★ PH7-10：材料预检（失败也扣矿，不能靠试错）
	if Game.矿石 < 需要矿石:
		Game.添加提示("矿石不足（需要%d）" % 需要矿石)
		return
	var 目标数 = _锻造数量 if _锻造数量 > 0 else int(Game.矿石 / 需要矿石)
	if 目标数 <= 0:
		Game.添加提示("矿石不足（需要%d）" % 需要矿石)
		return
	var 成功数: int = 0
	for _i in 目标数:
		if Game.矿石 < 需要矿石:
			break
		# ★ PH7-10：后端 锻造装备(图纸ID, 消耗灵石=0) 每次只锻 1 件，第二参是灵石不是数量
		var 结果 = Game.锻造装备(图纸ID)
		if 结果.get("成功", false):
			成功数 += 1
		else:
			Game.添加提示(结果.get("原因", "锻造失败"))
			break
	if 成功数 > 0:
		Game.添加提示("炼器 ×%d 完成" % 成功数)
		refresh()

func _on解锁图纸() -> void:
	# ★ 2026-09-16 修（死键扫描实测判 DEAD）：未择定图谱时静默 return ⇒ 可点但无声。
	if _选中索引 < 0 or _选中索引 >= _商店列表.size():
		Game.添加提示("尚未择定图谱")
		return
	var 商品 = _商店列表[_选中索引]
	if 商品.get("已解锁", false):
		return
	var 结果 = Game.商店解锁图纸(商品.get("图纸ID", ""))
	if 结果.get("成功", false):
		refresh()
	else:
		# ★ PH7-10：解锁失败静默无反馈 → 补提示
		Game.添加提示(结果.get("原因", "解锁失败"))

# ★ PH7-10：锻造炉火氛围（暖橙火星，零美术依赖）
func _build_炉火() -> void:
	_炉火 = GPUParticles2D.new()
	_炉火.amount = 14
	_炉火.lifetime = 1.1
	_炉火.emitting = true
	_炉火.z_index = 5
	_炉火.position = Vector2(958, 34)
	var 材质 := ParticleProcessMaterial.new()
	材质.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	材质.emission_box_extents = Vector3(26, 3, 0)
	材质.direction = Vector3(0, -1, 0)
	材质.spread = 16.0
	材质.initial_velocity_min = 16.0
	材质.initial_velocity_max = 40.0
	材质.gravity = Vector3(0, -10.0, 0)
	材质.angle_min = -8.0
	材质.angle_max = 8.0
	材质.color = Color(1.0, 0.62, 0.22, 1.0)
	材质.color_ramp = _生成炉火渐变()
	_炉火.material = 材质
	_炉火.texture = _生成柔点纹理()
	_详情面板.add_child(_炉火)

func _生成柔点纹理() -> Texture2D:
	var 尺寸: int = 32
	var 图 = Image.create(尺寸, 尺寸, false, Image.FORMAT_RGBA8)
	图.fill(Color(0, 0, 0, 0))
	var 中心 = Vector2(尺寸 / 2.0, 尺寸 / 2.0)
	for y in 尺寸:
		for x in 尺寸:
			var d = Vector2(float(x), float(y)).distance_to(中心)
			var a = clampf(1.0 - d / (尺寸 / 2.0), 0.0, 1.0)
			a = a * a
			图.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	var 纹理 = ImageTexture.create_from_image(图)
	return 纹理

func _生成炉火渐变() -> GradientTexture1D:
	# ★ color_ramp 收 Texture2D，Gradient 直接赋会 Parse Error ⇒ 包一层 GradientTexture1D
	var g = Gradient.new()
	g.add_point(0.0, Color(1.0, 0.85, 0.40, 1.0))
	g.add_point(0.5, Color(1.0, 0.55, 0.18, 0.90))
	g.add_point(1.0, Color(0.90, 0.25, 0.08, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	gt.width = 128
	return gt

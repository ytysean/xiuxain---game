extends Control

# 丹方系统页面（增强版）
# 展示已解锁丹方列表和丹方商店，支持解锁丹方、炼制丹药等操作
# ★ PH7-08 精修（2026-09-18）：手搓 60 高顶栏 → 全站统一 建顶栏；手搓标签栏 → 建标签栏；
#   详情面板字号 16/13 → 27/21（对齐全站最小字号档 FONT_AUX=21）；9 处硬编码色 → UITheme token。
#   几何仍走绝对定位（game_ui 不约束子页高度，VBox 流式会把页撑到视口外 ⇒ 详情面板掉出屏幕）。
# ★ PH7-09 逐页精修（2026-09-19）：B1 炼制失败 toast / B2 解锁失败 toast / B3 未择定提示 /
#   B4 列表入场淡入 / B5 空态重置详情 / A2 默认正文色 / A3 层级分隔+材料截断 /
#   D1 丹烟氛围粒子 / F1 数量选择(1/10/50/最大)+可炼上限预检（修正旧把 10 误当灵石消耗的潜伏 bug）/
#   F2 丹毒风险提示。F3 炼制成功纪事已由后端 炼制丹药 覆盖，不动。

signal 返回主页

var _built: bool = false
var _当前标签: String = "已解锁"  # "已解锁" 或 "商店"
var _选中索引: int = -1
var _丹方列表: Array = []
var _商店列表: Array = []

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
var _炼制按钮: Button
var _解锁按钮: Button

# ★ PH7-09 精修 F1：炼制数量选择
var _数量区域: HBoxContainer
var _数量提示: Label
var _数量钮: Dictionary = {}
var _炼制数量: int = 10
var _可炼上限: int = 0

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

	# ★ PH7-09 精修 D1：丹烟氛围粒子（取 UITheme 真实色，零美术依赖，置于背景之上、面板之下）
	_build_丹烟()

	# ★ PH7-08 精修：手搓 60 高顶栏 → 全站统一 建顶栏（含返回环 + apply_page_title）。
	#   PRESET_TOP_WIDE 拉满宽度；custom_minimum_size.y=72 作为高度下限（锚点 bottom=0 时高度归 0，靠 min 兜底）。
	var 顶栏: PanelContainer = UITheme.建顶栏("丹方系统", _on返回)
	顶栏.set_anchors_preset(Control.PRESET_TOP_WIDE)
	顶栏.custom_minimum_size = Vector2(0, 72)
	add_child(顶栏)

	# 标签栏：已解锁 / 丹方商店（收口到 建标签栏，最小宽 100 + EXPAND_FILL 均分）。
	var 标签栏: HBoxContainer = HBoxContainer.new()
	标签栏.set_anchors_preset(Control.PRESET_TOP_WIDE)
	标签栏.offset_top = 72
	标签栏.custom_minimum_size = Vector2(0, 40)
	add_child(标签栏)
	_tab_btns = UITheme.建标签栏(标签栏, ["已解锁", "丹方商店"], Callable(self, "_切换标签"), _当前标签)

	# 列表区域
	var 列表区域: ScrollContainer = ScrollContainer.new()
	列表区域.set_anchors_preset(Control.PRESET_FULL_RECT)
	列表区域.offset_top = 112
	列表区域.offset_bottom = -314
	列表区域.offset_left = 10
	列表区域.offset_right = -10
	add_child(列表区域)

	_列表 = VBoxContainer.new()
	_列表.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_列表.add_theme_constant_override("separation", 8)
	列表区域.add_child(_列表)

	# 详情面板（固定高度，贴底，与列表区留 10px 间隙）
	_详情面板 = Panel.new()
	_详情面板.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_详情面板.custom_minimum_size = Vector2(0, 250)
	# ★ PH7-08 精修：原 190 高容不下 27/21 字号后的 6 行 + 按钮行，提到 250 并收紧内容间距。
	#   offset_top=-304 / offset_bottom=-54 ⇒ 高 250，顶边 y=976、底边 y=1226（视口 1280，安全边距 54）。
	_详情面板.offset_top = -304
	_详情面板.offset_bottom = -54
	_详情面板.offset_left = 10
	_详情面板.offset_right = -10
	_详情面板.add_theme_stylebox_override("panel", create_stylebox(UITheme.获取面板底色(), UITheme.COLOR_BORDER_GOLD))
	add_child(_详情面板)

	# 详情内容
	var 详情内容: VBoxContainer = VBoxContainer.new()
	详情内容.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	详情内容.add_theme_constant_override("separation", 2)
	详情内容.offset_left = 15
	详情内容.offset_top = 10
	详情内容.offset_right = -15
	详情内容.offset_bottom = -10
	_详情面板.add_child(详情内容)

	_详情名 = create_label("名称：-", UITheme.FONT_BODY, UITheme.COLOR_TEXT_GOLD)
	详情内容.add_child(_详情名)

	_详情品阶 = create_label("品阶：-", UITheme.FONT_AUX, UITheme.COLOR_TEXT_BODY)
	详情内容.add_child(_详情品阶)

	# ★ PH7-09 精修 A3：基础信息（名称·品阶）与消耗/产出之间加分隔线
	var 基础分隔: HSeparator = HSeparator.new()
	基础分隔.add_theme_constant_override("separation", 2)
	基础分隔.add_theme_color_override("separator", UITheme.COLOR_BORDER_GOLD)
	详情内容.add_child(基础分隔)

	_详情材料 = create_label("材料：-", UITheme.FONT_AUX, UITheme.COLOR_TEXT_BODY)
	详情内容.add_child(_详情材料)

	_详情效果 = create_label("效果：-", UITheme.FONT_AUX, UITheme.COLOR_TEXT_BODY)
	详情内容.add_child(_详情效果)

	_详情状态 = create_label("状态：-", UITheme.FONT_AUX, UITheme.COLOR_STATUS_SUCCESS)
	详情内容.add_child(_详情状态)

	_详情价格 = create_label("", UITheme.FONT_AUX, UITheme.COLOR_TEXT_RED)
	详情内容.add_child(_详情价格)

	# ★ PH7-09 精修 F1：炼制数量选择行（1 / 10 / 50 / 最大）+ 可炼上限预检
	_数量区域 = HBoxContainer.new()
	_数量区域.add_theme_constant_override("separation", 6)
	详情内容.add_child(_数量区域)
	var 数量标: Label = create_label("炼制", UITheme.FONT_AUX, UITheme.COLOR_TEXT_AUX)
	_数量区域.add_child(数量标)
	_数量钮 = {}
	for 档 in ["1", "10", "50", "最大"]:
		var 数量钮: Button = Button.new()
		数量钮.text = "×%s" % 档
		数量钮.custom_minimum_size = Vector2(46, 32)
		UITheme.apply_project_font(数量钮, UITheme.FONT_AUX, false)
		UITheme.apply_secondary_button_style(数量钮)
		var 档名: String = 档
		数量钮.pressed.connect(_on选数量.bind(档名))
		_数量区域.add_child(数量钮)
		数量钮.modulate.a = 0.0
		数量钮.create_tween().tween_property(数量钮, "modulate:a", 1.0, 0.25)
		_数量钮[档] = 数量钮
	_数量提示 = create_label("", UITheme.FONT_AUX, UITheme.COLOR_TEXT_AUX)
	_数量区域.add_child(_数量提示)
	_数量区域.visible = false

	# 按钮区域
	var 按钮区域: HBoxContainer = HBoxContainer.new()
	按钮区域.add_theme_constant_override("separation", 10)
	详情内容.add_child(按钮区域)

	_炼制按钮 = Button.new()
	_炼制按钮.text = "炼制丹药"
	UITheme.apply_project_font(_炼制按钮, UITheme.FONT_BODY, false)
	_炼制按钮.pressed.connect(_on炼制丹药)
	按钮区域.add_child(_炼制按钮)

	_解锁按钮 = Button.new()
	_解锁按钮.text = "解锁丹方"
	UITheme.apply_project_font(_解锁按钮, UITheme.FONT_BODY, false)
	_解锁按钮.pressed.connect(_on解锁丹方)
	按钮区域.add_child(_解锁按钮)

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
	# ★ PH7-08 精修：手搓 stylebox 切换 → 统一 刷新标签高亮（选中全亮/未选压暗 0.6 全局口径）。
	UITheme.刷新标签高亮(_tab_btns, 标签)
	refresh()

func refresh() -> void:
	for _c in _列表.get_children():
		_c.queue_free()

	if _当前标签 == "已解锁":
		_丹方列表 = Game.获取已解锁丹方列表()
		if _丹方列表.is_empty():
			# ★ 2026-09-16（#009 逐页精修）：改用统一空态组件。
			_列表.add_child(UITheme.建空态("尚无已解锁丹方", "轻触「丹方商店」标签解锁"))
			# ★ PH7-09 精修 B5：空态也重置详情面板为占位「-」
			_更新详情()
			return
		for i in _丹方列表.size():
			var 丹方 = _丹方列表[i]
			var 行 = Button.new()
			# ★ PH7-09 精修 A3：材料名超长截断加「…」，避免一行挤爆
			var 名称: String = 丹方.get("名称", "")
			var 品阶: String = 丹方.get("品阶", "")
			var 材料文本: String = 丹方.get("材料", "")
			if 材料文本.length() > 12:
				材料文本 = 材料文本.substr(0, 12) + "…"
			行.text = "%s（%s）- 材料：%s" % [名称, 品阶, 材料文本]
			行.custom_minimum_size = Vector2(0, 45)
			UITheme.apply_project_font(行, UITheme.FONT_BODY, false)
			if i == _选中索引:
				行.add_theme_stylebox_override("normal", create_stylebox(Color(UITheme.COLOR_BORDER_GOLD, 0.35)))
			var 索引 = i
			行.pressed.connect(func(): _on选中丹方(索引))
			_列表.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	else:
		_商店列表 = Game.获取丹方商店列表()
		if _商店列表.is_empty():
			# ★ 2026-09-16（#009 逐页精修）：与「已解锁」分栏同源，改用统一空态组件
			_列表.add_child(UITheme.建空态("商店尚无商品"))
			# ★ PH7-09 精修 B5：空态也重置详情面板为占位「-」
			_更新详情()
			return
		for i in _商店列表.size():
			var 商品 = _商店列表[i]
			var 行 = Button.new()
			var 状态文本 = "已解锁" if 商品.get("已解锁", false) else "%d灵石" % 商品.get("价格", 0)
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
	# ★ PH7-09 精修 B4：列表条目依次淡入（间隔 ~50ms）
	_列表入场动画()

func _更新详情() -> void:
	if _当前标签 == "已解锁":
		if _选中索引 < 0 or _选中索引 >= _丹方列表.size():
			_详情名.text = "名称：-"
			_详情品阶.text = "品阶：-"
			_详情材料.text = "材料：-"
			_详情效果.text = "效果：-"
			_详情状态.text = "状态：-"
			_详情价格.text = ""
			_炼制按钮.visible = true
			_解锁按钮.visible = false
			# ★ PH7-09 精修 F1：无选中时隐藏数量选择行
			_数量区域.visible = false
			_数量提示.text = ""
			return
		var 丹方 = _丹方列表[_选中索引]
		var 品阶文本: String = 丹方.get("品阶", "")
		_详情名.text = "名称：%s" % 丹方.get("名称", "")
		_详情品阶.text = "品阶：%s" % 品阶文本
		_详情材料.text = "材料：%s" % 丹方.get("材料", "")
		# ★ PH7-09 精修 F2：丹毒风险按品阶提示（轻/中/重）
		var 丹毒级: String = _品阶丹毒(品阶文本)
		_详情效果.text = "效果：%s　丹毒：%s" % [丹方.get("效果", ""), 丹毒级]
		_详情状态.text = "状态：已解锁，可以炼制"
		_详情价格.text = ""
		_炼制按钮.visible = true
		_解锁按钮.visible = false
		# ★ PH7-09 精修 F1：数量选择 + 可炼上限预检
		_数量区域.visible = true
		var 需要: int = _品阶需要灵草(品阶文本)
		_可炼上限 = int(Game.灵石 / float(需要)) if 需要 > 0 else 0
		_数量提示.text = "可炼 %d" % _可炼上限
		_刷新数量高亮()
	else:
		if _选中索引 < 0 or _选中索引 >= _商店列表.size():
			_详情名.text = "名称：-"
			_详情品阶.text = "品阶：-"
			_详情材料.text = "材料：-"
			_详情效果.text = "效果：-"
			_详情状态.text = "状态：-"
			_详情价格.text = ""
			_炼制按钮.visible = false
			_解锁按钮.visible = true
			# ★ PH7-09 精修 F1：商店页隐藏数量选择行
			_数量区域.visible = false
			_数量提示.text = ""
			return
		var 商品 = _商店列表[_选中索引]
		_详情名.text = "名称：%s" % 商品.get("名称", "")
		_详情品阶.text = "品阶：%s" % 商品.get("品阶", "")
		_详情材料.text = "材料：%s" % 商品.get("材料", "")
		# ★ PH7-09 精修 F2：丹毒风险按品阶提示（轻/中/重）
		var 丹毒级: String = _品阶丹毒(商品.get("品阶", ""))
		_详情效果.text = "效果：%s　丹毒：%s" % [商品.get("效果", ""), 丹毒级]
		if 商品.get("已解锁", false):
			_详情状态.text = "状态：已解锁"
			_详情价格.text = ""
			_解锁按钮.text = "已解锁"
			_解锁按钮.disabled = true
		else:
			_详情状态.text = "状态：未解锁"
			_详情价格.text = "价格：%d灵石" % 商品.get("价格", 0)
			_解锁按钮.text = "解锁丹方"
			_解锁按钮.disabled = false
		_炼制按钮.visible = false
		_解锁按钮.visible = true
		# ★ PH7-09 精修 F1：商店页隐藏数量选择行
		_数量区域.visible = false
		_数量提示.text = ""

func _on返回() -> void:
	返回主页.emit()

func _on选中丹方(索引: int) -> void:
	_选中索引 = 索引
	refresh()

func _on选中商品(索引: int) -> void:
	_选中索引 = 索引
	refresh()

func _on炼制丹药() -> void:
	# ★ PH7-09 精修 B3：未择定也给出提示，与「解锁」按钮行为对齐
	if _选中索引 < 0 or _选中索引 >= _丹方列表.size():
		Game.添加提示("尚未择定丹方")
		return
	var 丹方 = _丹方列表[_选中索引]
	var 丹方ID: String = 丹方.get("丹方ID", "")
	var 成功数: int = 0
	var 失败原因: String = ""
	# ★ PH7-09 精修 F1：按选定数量循环炼制；消耗灵石默认 0（修正旧把 10 误当灵石消耗的潜伏 bug）
	for _轮 in range(_炼制数量):
		var 结果 = Game.炼制丹药(丹方ID)
		if 结果.get("成功", false):
			成功数 += 1
		else:
			失败原因 = str(结果.get("原因", "炼制失败"))
			# 材料耗尽后续必败，提前终止避免空耗
			if "灵草不足" in 失败原因:
				break
	if 成功数 > 0:
		Game.添加提示("炼制%s ×%d 成功" % [丹方.get("名称", ""), 成功数])
	else:
		# ★ PH7-09 精修 B1：失败分支给出明确原因，不再静默
		Game.添加提示(失败原因 if 失败原因 != "" else "炼制失败")
	refresh()

func _on解锁丹方() -> void:
	# ★ 2026-09-16 修（死键扫描实测判 DEAD）：未择定商品时静默 return ⇒ 按钮亮着却毫无反馈。
	#   铁则：凡不可用的动作，要么置灰、要么给出回应，绝不允许「可点但无声」。
	if _选中索引 < 0 or _选中索引 >= _商店列表.size():
		Game.添加提示("尚未择定丹方")
		return
	var 商品 = _商店列表[_选中索引]
	if 商品.get("已解锁", false):
		return
	var 结果 = Game.商店解锁丹方(商品.get("丹方ID", ""))
	if 结果.get("成功", false):
		refresh()
	else:
		# ★ PH7-09 精修 B2：解锁失败分支给出明确原因，不再静默
		Game.添加提示(str(结果.get("原因", "解锁失败")))

# ===================== PH7-09 精修 · 新增辅助 =====================

func _on选数量(档: String) -> void:
	if 档 == "最大":
		_炼制数量 = maxi(1, _可炼上限)
	else:
		_炼制数量 = int(档)
	_刷新数量高亮()

func _刷新数量高亮() -> void:
	for 档 in _数量钮.keys():
		var 数量钮: Button = _数量钮[档] as Button
		var 匹配: bool = false
		if 档 == "最大":
			匹配 = (_可炼上限 > 0 and _炼制数量 == _可炼上限)
		else:
			匹配 = (_炼制数量 == int(档))
		数量钮.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD if 匹配 else UITheme.COLOR_TEXT_AUX)

# 品阶 → 每次炼制所需灵草（与后端 炼制丹药 消耗表同源，仅用于 UI 预检显示）
func _品阶需要灵草(品阶: String) -> int:
	match 品阶:
		"凡品": return 3
		"灵品": return 5
		"宝品": return 8
		"王品": return 12
		"圣品": return 18
		"仙品": return 25
		_: return 5

# 品阶 → 丹毒风险等级（GDD-丹毒体系，UI 提示用）
func _品阶丹毒(品阶: String) -> String:
	match 品阶:
		"凡品", "灵品": return "轻"
		"宝品", "王品": return "中"
		"圣品", "仙品": return "重"
		_: return "轻"

# ★ PH7-09 精修 B4：列表条目依次淡入
func _列表入场动画() -> void:
	var 子 := _列表.get_children()
	if 子.is_empty():
		return
	var 动画 := create_tween()
	for k in range(子.size()):
		var 节点 := 子[k] as Control
		if 节点 == null:
			continue
		节点.modulate.a = 0.0
		动画.tween_property(节点, "modulate:a", 1.0, 0.18).set_delay(float(k) * 0.05)

# ★ PH7-09 精修 D1：丹烟氛围粒子（取 UITheme 真实色，零美术依赖）
func _build_丹烟() -> void:
	var 烟: GPUParticles2D = GPUParticles2D.new()
	烟.texture = _建柔点纹理()
	烟.amount = 14
	烟.lifetime = 2.6
	烟.emitting = true
	烟.position = Vector2(240, 1235)
	var 材质 := ParticleProcessMaterial.new()
	材质.direction = Vector3(0, -1, 0)
	材质.gravity = Vector3(0, -22, 0)
	材质.initial_velocity_min = 18.0
	材质.initial_velocity_max = 36.0
	材质.scale_min = 0.25
	材质.scale_max = 1.1
	材质.color = Color(0.82, 0.72, 0.52, 0.22)
	烟.process_material = 材质
	add_child(烟)

# 运行时生成柔光圆点贴图（避免依赖外部美术资源）
func _建柔点纹理() -> ImageTexture:
	var 尺寸 := 32
	var 图 := Image.new()
	图.create(尺寸, 尺寸, false, Image.FORMAT_RGBA8)
	for y in 尺寸:
		for x in 尺寸:
			var dx := float(x) - 尺寸 * 0.5 + 0.5
			var dy := float(y) - 尺寸 * 0.5 + 0.5
			var d := sqrt(dx * dx + dy * dy) / (尺寸 * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			图.set_pixel(x, y, Color(0.9, 0.82, 0.62, a * 0.5))
	var 纹理 := ImageTexture.new()
	纹理.create_from_image(图)
	return 纹理

extends Control

# 装备图纸系统页面（增强版）
# 展示已解锁装备图纸列表和图纸商店，支持解锁图纸、锻造装备等操作

signal 返回主页

const C_BG_TOP: Color = Color(0.043, 0.086, 0.102)
const C_BG_BOT: Color = Color(0.059, 0.133, 0.161)
const C_TOPBAR_BG: Color = Color(0.039, 0.078, 0.094, 0.90)
const C_TAB_BG: Color = Color(0.035, 0.071, 0.086)
const C_TAB_ACTIVE: Color = Color(0.910, 0.773, 0.447, 0.3)
const C_CELL_BG: Color = Color(0.051, 0.102, 0.125)
const C_DETAIL_BG: Color = Color(0.047, 0.090, 0.102)
const C_GOLD: Color = Color(0.910, 0.773, 0.447)
const C_GOLD_DIM: Color = Color(0.839, 0.694, 0.416, 0.60)
const C_GREEN: Color = Color(0.4, 0.8, 0.4)
const C_RED: Color = Color(0.8, 0.4, 0.4)

var _built: bool = false
var _当前标签: String = "已解锁"  # "已解锁" 或 "商店"
var _选中索引: int = -1
var _图纸列表: Array = []
var _商店列表: Array = []

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
var _标题标签: Label
var _返回按钮: Button
var _已解锁标签按钮: Button
var _商店标签按钮: Button
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
	
	# 背景
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = C_BG_TOP
	add_child(_bg)
	
	# 顶部栏
	var 顶部栏 = Panel.new()
	顶部栏.set_anchors_preset(Control.PRESET_TOP_WIDE)
	顶部栏.custom_minimum_size = Vector2(0, 60)
	顶部栏.add_theme_stylebox_override("panel", create_stylebox(C_TOPBAR_BG))
	add_child(顶部栏)
	
	# 返回按钮
	_返回按钮 = Button.new()
	_返回按钮.text = "折返"
	_返回按钮.position = Vector2(10, 15)
	_返回按钮.size = Vector2(60, 30)
	_返回按钮.pressed.connect(_on返回)
	顶部栏.add_child(_返回按钮)
	
	# 标题
	_标题标签 = Label.new()
	_标题标签.text = "器谱阁"
	_标题标签.position = Vector2(80, 18)
	_标题标签.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
	_标题标签.add_theme_color_override("font_color", C_GOLD)
	顶部栏.add_child(_标题标签)
	
	# 标签栏
	var 标签栏 = Panel.new()
	标签栏.set_anchors_preset(Control.PRESET_TOP_WIDE)
	标签栏.offset_top = 60
	标签栏.custom_minimum_size = Vector2(0, 40)
	标签栏.add_theme_stylebox_override("panel", create_stylebox(C_TAB_BG))
	add_child(标签栏)
	
	# 已解锁标签按钮
	_已解锁标签按钮 = Button.new()
	_已解锁标签按钮.text = "已习得"
	_已解锁标签按钮.position = Vector2(50, 5)
	_已解锁标签按钮.size = Vector2(100, 30)
	_已解锁标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE))
	_已解锁标签按钮.pressed.connect(func(): _切换标签("已解锁"))
	标签栏.add_child(_已解锁标签按钮)
	
	# 商店标签按钮
	_商店标签按钮 = Button.new()
	_商店标签按钮.text = "图谱坊市"
	_商店标签按钮.position = Vector2(170, 5)
	_商店标签按钮.size = Vector2(120, 30)
	_商店标签按钮.pressed.connect(func(): _切换标签("商店"))
	标签栏.add_child(_商店标签按钮)
	
	# 列表区域
	var 列表区域 = ScrollContainer.new()
	列表区域.set_anchors_preset(Control.PRESET_FULL_RECT)
	列表区域.offset_top = 110
	列表区域.offset_bottom = -200
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
	_详情面板.custom_minimum_size = Vector2(0, 190)
	_详情面板.offset_top = -190
	_详情面板.offset_bottom = 0
	_详情面板.offset_left = 10
	_详情面板.offset_right = -10
	_详情面板.add_theme_stylebox_override("panel", create_stylebox(C_DETAIL_BG, C_GOLD_DIM))
	add_child(_详情面板)
	
	# 详情内容
	var 详情内容 = VBoxContainer.new()
	详情内容.set_anchors_preset(Control.PRESET_FULL_RECT)
	详情内容.offset_left = 15
	详情内容.offset_top = 10
	详情内容.offset_right = -15
	详情内容.offset_bottom = -10
	_详情面板.add_child(详情内容)
	
	_详情名 = create_label("名称：-", 16, C_GOLD)
	详情内容.add_child(_详情名)
	
	_详情品阶 = create_label("品阶：-", 13)
	详情内容.add_child(_详情品阶)
	
	_详情材料 = create_label("材料：-", 13)
	详情内容.add_child(_详情材料)
	
	_详情效果 = create_label("效果：-", 13)
	详情内容.add_child(_详情效果)
	
	_详情状态 = create_label("状态：-", 13, C_GREEN)
	详情内容.add_child(_详情状态)
	
	_详情价格 = create_label("", 13, C_RED)
	详情内容.add_child(_详情价格)
	
	# 按钮区域
	var 按钮区域 = HBoxContainer.new()
	按钮区域.add_theme_constant_override("separation", 10)
	详情内容.add_child(按钮区域)
	
	_锻造按钮 = Button.new()
	_锻造按钮.text = "炼器"
	_锻造按钮.pressed.connect(_on锻造装备)
	按钮区域.add_child(_锻造按钮)
	
	_解锁按钮 = Button.new()
	_解锁按钮.text = "习得图谱"
	_解锁按钮.pressed.connect(_on解锁图纸)
	按钮区域.add_child(_解锁按钮)

func create_label(text: String, size: int = 14, color: Color = Color.WHITE) -> Label:
	var 标签 = Label.new()
	标签.text = text
	标签.add_theme_font_size_override("font_size", size)
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
	# 更新标签按钮样式
	if 标签 == "已解锁":
		_已解锁标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE))
		_商店标签按钮.add_theme_stylebox_override("normal", create_stylebox(Color.TRANSPARENT))
	else:
		_已解锁标签按钮.add_theme_stylebox_override("normal", create_stylebox(Color.TRANSPARENT))
		_商店标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE))
	refresh()

func refresh() -> void:
	for _c in _列表.get_children():
		_c.queue_free()
	
	if _当前标签 == "已解锁":
		_图纸列表 = Game.获取已解锁装备图纸列表()
		if _图纸列表.is_empty():
			var 空标签 = create_label("尚未习得图谱，可往「图谱坊市」一观", 14, Color.GRAY)
			_列表.add_child(空标签)
			return
		for i in _图纸列表.size():
			var 图纸 = _图纸列表[i]
			var 行 = Button.new()
			行.text = "%s（%s）- 材料：%s" % [图纸.get("名称", ""), 图纸.get("品阶", ""), 图纸.get("材料", "")]
			行.custom_minimum_size = Vector2(0, 45)
			行.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			if i == _选中索引:
				行.add_theme_stylebox_override("normal", create_stylebox(C_GOLD_DIM))
			var 索引 = i
			行.pressed.connect(func(): _on选中图纸(索引))
			_列表.add_child(行)
	else:
		_商店列表 = Game.获取图纸商店列表()
		if _商店列表.is_empty():
			var 空标签 = create_label("坊市尚无此物", 14, Color.GRAY)
			_列表.add_child(空标签)
			return
		for i in _商店列表.size():
			var 商品 = _商店列表[i]
			var 行 = Button.new()
			var 状态文本 = "已解锁" if 商品.get("已解锁", false) else "%d灵石" % 商品.get("价格", 0)
			行.text = "%s（%s）- %s" % [商品.get("名称", ""), 商品.get("品阶", ""), 状态文本]
			行.custom_minimum_size = Vector2(0, 45)
			行.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
			if 商品.get("已解锁", false):
				行.add_theme_color_override("font_color", C_GREEN)
			if i == _选中索引:
				行.add_theme_stylebox_override("normal", create_stylebox(C_GOLD_DIM))
			var 索引 = i
			行.pressed.connect(func(): _on选中商品(索引))
			_列表.add_child(行)
	
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

func _on返回() -> void:
	返回主页.emit()

func _on选中图纸(索引: int) -> void:
	_选中索引 = 索引
	refresh()

func _on选中商品(索引: int) -> void:
	_选中索引 = 索引
	refresh()

func _on锻造装备() -> void:
	if _选中索引 < 0 or _选中索引 >= _图纸列表.size():
		return
	var 图纸 = _图纸列表[_选中索引]
	var 结果 = Game.锻造装备(图纸.get("图纸ID", ""), 20)
	if 结果.get("成功", false):
		refresh()

func _on解锁图纸() -> void:
	if _选中索引 < 0 or _选中索引 >= _商店列表.size():
		return
	var 商品 = _商店列表[_选中索引]
	if 商品.get("已解锁", false):
		return
	var 结果 = Game.商店解锁图纸(商品.get("图纸ID", ""))
	if 结果.get("成功", false):
		refresh()




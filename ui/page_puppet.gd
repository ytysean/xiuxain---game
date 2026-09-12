extends Control

# 机关阁页面（增强版）
# 展示已炼制傀儡列表和傀儡类型，支持制作、升级、装备、卸下等操作

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

var _built: bool = false
var _当前标签: String = "已炼制"  # "已炼制" 或 "傀儡类型"
var _选中索引: int = -1
var _傀儡列表: Array = []
var _类型列表: Array = []

# 根据傀儡类型生成描述
func _生成傀儡描述(傀儡: Dictionary) -> String:
	var 类型 = 傀儡.get("类型", "劳作")
	var 品阶 = 傀儡.get("品阶", "凡品")
	var 名称 = 傀儡.get("名称", "无名傀儡")
	var 等级 = 傀儡.get("等级", 1)
	var 类型描述 = {
		"劳作": "此傀儡为劳作型，以精铁为骨，灵晶为心，可代弟子从事灵田耕种、矿场开采等繁重劳作。不知疲倦，任劳任怨，是宗门发展的坚实后盾。",
		"炼丹": "此傀儡为炼丹辅助型，内置丹火核心，可精准控制火候，辅助弟子炼丹。虽不能独立成丹，却能大幅提升炼丹成功率与品质，是丹堂的得力助手。",
		"炼器": "此傀儡为炼器辅助型，以锻打核心驱动，可千锤百炼而不倦。辅助弟子锻造装备，提升锻造速度与成品品质，是器堂不可或缺的助力。",
		"战斗": "此傀儡为战斗型，内嵌战斗核心，可在宗门战中协同弟子作战。铜皮铁骨，悍不畏死，是护宗卫道的重要战力。",
		"守护": "此傀儡为守护型，常驻山门要害，遇敌则自动激活防御。坚不可摧，稳如磐石，是护山大阵的重要补充。",
	}
	var 品阶描述 = {
		"凡阶": "入门级傀儡，工艺简单，功能基础，适合宗门初期使用。",
		"灵阶": "精修级傀儡，融入灵气回路，性能提升，是宗门中期的主力。",
		"宝阶": "珍本级傀儡，工艺精湛，功能强大，非大势力不可拥有。",
		"王阶": "秘典级傀儡，以珍稀材料炼制，性能卓越，可遇不可求。",
		"圣阶": "圣级傀儡，上古传承，蕴含大道至理，几乎有自主意识。",
	}
	var 基础描述 = 品阶描述.get(品阶, "珍贵傀儡，工艺精湛。")
	var 专业描述 = 类型描述.get(类型, "此傀儡功能多样，可胜任多种任务。")
	var 装备信息 = ""
	if 傀儡.get("装备名称", "无") != "无":
		装备信息 = "\n\n当前装备：%s，装备可进一步提升傀儡性能。" % 傀儡.get("装备名称", "无")
	return "%s（%s Lv.%d）\n\n%s\n\n%s%s\n\n傀儡需定期维护，消耗灵晶修复耐久。等级越高，性能越强，可装备的部件也越多。" % [名称, 品阶, 等级, 基础描述, 专业描述, 装备信息]

var _bg: ColorRect
var _标题标签: Label
var _返回按钮: Button
var _已炼制标签按钮: Button
var _类型标签按钮: Button
var _制作按钮: Button
var _列表: VBoxContainer
var _详情面板: Panel
var _详情名: Label
var _详情品阶: Label
var _详情类型: Label
var _详情等级: Label
var _详情效果: Label
var _详情装备: Label
var _详情描述: Label
var _升级按钮: Button
var _装备按钮: Button
var _卸下按钮: Button
var _制作类型按钮: Button

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
	_标题标签.text = "机关阁"
	_标题标签.position = Vector2(80, 18)
	_标题标签.add_theme_font_size_override("font_size", 20)
	_标题标签.add_theme_color_override("font_color", C_GOLD)
	顶部栏.add_child(_标题标签)
	
	# 制作按钮
	_制作按钮 = Button.new()
	_制作按钮.text = "炼制"
	_制作按钮.position = Vector2(380, 15)
	_制作按钮.size = Vector2(90, 30)
	_制作按钮.pressed.connect(_on炼制)
	顶部栏.add_child(_制作按钮)
	
	# 标签栏
	var 标签栏 = Panel.new()
	标签栏.set_anchors_preset(Control.PRESET_TOP_WIDE)
	标签栏.offset_top = 60
	标签栏.custom_minimum_size = Vector2(0, 40)
	标签栏.add_theme_stylebox_override("panel", create_stylebox(C_TAB_BG))
	add_child(标签栏)
	
	# 已炼制标签按钮
	_已炼制标签按钮 = Button.new()
	_已炼制标签按钮.text = "已炼制"
	_已炼制标签按钮.position = Vector2(50, 5)
	_已炼制标签按钮.size = Vector2(100, 30)
	_已炼制标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE))
	_已炼制标签按钮.pressed.connect(func(): _切换标签("已炼制"))
	标签栏.add_child(_已炼制标签按钮)
	
	# 傀儡类型标签按钮
	_类型标签按钮 = Button.new()
	_类型标签按钮.text = "傀儡类型"
	_类型标签按钮.position = Vector2(170, 5)
	_类型标签按钮.size = Vector2(120, 30)
	_类型标签按钮.pressed.connect(func(): _切换标签("傀儡类型"))
	标签栏.add_child(_类型标签按钮)
	
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
	
	_详情类型 = create_label("类型：-", 13)
	详情内容.add_child(_详情类型)
	
	_详情等级 = create_label("等级：-", 13)
	详情内容.add_child(_详情等级)
	
	_详情效果 = create_label("效果：-", 13)
	详情内容.add_child(_详情效果)
	
	_详情装备 = create_label("装备：-", 13)
	详情内容.add_child(_详情装备)
	
	_详情描述 = create_label("", 12, Color.GRAY)
	详情内容.add_child(_详情描述)
	
	# 按钮区域
	var 按钮区域 = HBoxContainer.new()
	按钮区域.add_theme_constant_override("separation", 10)
	详情内容.add_child(按钮区域)
	
	_升级按钮 = Button.new()
	_升级按钮.text = "精进"
	_升级按钮.pressed.connect(_on升级)
	按钮区域.add_child(_升级按钮)
	
	_装备按钮 = Button.new()
	_装备按钮.text = "披挂"
	_装备按钮.pressed.connect(_on装备)
	按钮区域.add_child(_装备按钮)
	
	_卸下按钮 = Button.new()
	_卸下按钮.text = "卸下"
	_卸下按钮.pressed.connect(_on卸下)
	按钮区域.add_child(_卸下按钮)
	
	_制作类型按钮 = Button.new()
	_制作类型按钮.text = "炼制此类"
	_制作类型按钮.pressed.connect(_on制作类型)
	按钮区域.add_child(_制作类型按钮)

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
	if 标签 == "已炼制":
		_已炼制标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE))
		_类型标签按钮.add_theme_stylebox_override("normal", create_stylebox(Color.TRANSPARENT))
	else:
		_已炼制标签按钮.add_theme_stylebox_override("normal", create_stylebox(Color.TRANSPARENT))
		_类型标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE))
	refresh()

func refresh() -> void:
	for _c in _列表.get_children():
		_c.queue_free()
	
	if _当前标签 == "已炼制":
		_傀儡列表 = Game.获取傀儡列表()
		if _傀儡列表.is_empty():
			var 空标签 = create_label("尚无傀儡，点击「炼制」按钮制作", 14, Color.GRAY)
			_列表.add_child(空标签)
			return
		for i in _傀儡列表.size():
			var 傀儡 = _傀儡列表[i]
			var 行 = Button.new()
			行.text = "%s（%s）- Lv.%d - %s" % [傀儡.get("名称", ""), 傀儡.get("品阶", ""), 傀儡.get("等级", 1), 傀儡.get("类型", "")]
			行.custom_minimum_size = Vector2(0, 45)
			行.add_theme_font_size_override("font_size", 13)
			if i == _选中索引:
				行.add_theme_stylebox_override("normal", create_stylebox(C_GOLD_DIM))
			var 索引 = i
			行.pressed.connect(func(): _on选中傀儡(索引))
			_列表.add_child(行)
	else:
		_类型列表 = Game.获取所有傀儡类型()
		if _类型列表.is_empty():
			var 空标签 = create_label("尚未分类", 14, Color.GRAY)
			_列表.add_child(空标签)
			return
		for i in _类型列表.size():
			var 类型 = _类型列表[i]
			var 行 = Button.new()
			行.text = "%s - %s" % [类型.get("类型", ""), 类型.get("描述", "")]
			行.custom_minimum_size = Vector2(0, 45)
			行.add_theme_font_size_override("font_size", 13)
			if i == _选中索引:
				行.add_theme_stylebox_override("normal", create_stylebox(C_GOLD_DIM))
			var 索引 = i
			行.pressed.connect(func(): _on选中类型(索引))
			_列表.add_child(行)
	
	_更新详情()

func _更新详情() -> void:
	if _当前标签 == "已炼制":
		if _选中索引 < 0 or _选中索引 >= _傀儡列表.size():
			_详情名.text = "名称：-"
			_详情品阶.text = "品阶：-"
			_详情类型.text = "类型：-"
			_详情等级.text = "等级：-"
			_详情效果.text = "效果：-"
			_详情装备.text = "装备：-"
			_详情描述.text = ""
			_升级按钮.visible = true
			_装备按钮.visible = true
			_卸下按钮.visible = true
			_制作类型按钮.visible = false
			return
		var 傀儡 = _傀儡列表[_选中索引]
		_详情名.text = "名称：%s" % 傀儡.get("名称", "")
		_详情品阶.text = "品阶：%s" % 傀儡.get("品阶", "")
		_详情类型.text = "类型：%s" % 傀儡.get("类型", "")
		_详情等级.text = "等级：%d" % 傀儡.get("等级", 1)
		_详情效果.text = "效果：修炼+%.0f%%，产出+%.0f%%，战力+%d" % [傀儡.get("修炼加成", 0.0) * 100, 傀儡.get("产出加成", 0.0) * 100, 傀儡.get("战力加成", 0)]
		_详情装备.text = "装备：%s" % 傀儡.get("装备名称", "无")
		_详情描述.text = _生成傀儡描述(傀儡)
		_升级按钮.visible = true
		_装备按钮.visible = true
		_卸下按钮.visible = true
		_制作类型按钮.visible = false
	else:
		if _选中索引 < 0 or _选中索引 >= _类型列表.size():
			_详情名.text = "类型：-"
			_详情品阶.text = ""
			_详情类型.text = ""
			_详情等级.text = ""
			_详情效果.text = ""
			_详情装备.text = ""
			_详情描述.text = ""
			_升级按钮.visible = false
			_装备按钮.visible = false
			_卸下按钮.visible = false
			_制作类型按钮.visible = true
			return
		var 类型 = _类型列表[_选中索引]
		_详情名.text = "类型：%s" % 类型.get("类型", "")
		_详情品阶.text = ""
		_详情类型.text = ""
		_详情等级.text = ""
		_详情效果.text = "效果：修炼+%.0f%%，产出+%.0f%%，战力+%d" % [类型.get("修炼加成", 0.0) * 100, 类型.get("产出加成", 0.0) * 100, 类型.get("战力加成", 0)]
		_详情装备.text = ""
		_详情描述.text = 类型.get("描述", "")
		_升级按钮.visible = false
		_装备按钮.visible = false
		_卸下按钮.visible = false
		_制作类型按钮.visible = true

func _on返回() -> void:
	返回主页.emit()

func _on选中傀儡(索引: int) -> void:
	_选中索引 = 索引
	refresh()

func _on选中类型(索引: int) -> void:
	_选中索引 = 索引
	refresh()

func _on炼制() -> void:
	var 结果 = Game.宗主制作傀儡("全能型傀儡", "凡品", "全能型")
	if 结果.get("成功", false):
		refresh()
	else:
		UIHint.show_hint(self, "炼制失败", str(结果.get("原因", "")))

func _on制作类型() -> void:
	if _选中索引 < 0 or _选中索引 >= _类型列表.size():
		return
	var 类型 = _类型列表[_选中索引]
	var 结果 = Game.宗主制作傀儡(类型.get("类型", "全能型") + "傀儡", "凡品", 类型.get("类型", "全能型"))
	if 结果.get("成功", false):
		_切换标签("已炼制")
	else:
		UIHint.show_hint(self, "炼制失败", str(结果.get("原因", "")))

func _on升级() -> void:
	if _选中索引 < 0 or _选中索引 >= _傀儡列表.size():
		return
	var 傀儡 = _傀儡列表[_选中索引]
	var 结果 = Game.升级傀儡(傀儡.get("ID", 0), 200)
	if 结果.get("成功", false):
		refresh()

func _on装备() -> void:
	if _选中索引 < 0 or _选中索引 >= _傀儡列表.size():
		return
	var 傀儡 = _傀儡列表[_选中索引]
	var 结果 = Game.傀儡装备(傀儡.get("ID", 0), "随机装备")
	if 结果.get("成功", false):
		refresh()

func _on卸下() -> void:
	if _选中索引 < 0 or _选中索引 >= _傀儡列表.size():
		return
	var 傀儡 = _傀儡列表[_选中索引]
	var 结果 = Game.傀儡卸下装备(傀儡.get("ID", 0))
	if 结果.get("成功", false):
		refresh()

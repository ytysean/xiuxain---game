extends Control

# 药园系统页面（增强版）
# 展示药园地块和作物类型，支持开辟灵田、种植、收获等操作

signal 返回主页

const C_BG_TOP: Color = Color(0.106, 0.153, 0.169)
const C_BG_BOT: Color = UITheme.获取面板底色()
const C_TOPBAR_BG: Color = Color(0.106, 0.153, 0.169, 0.90)
const C_TAB_BG: Color = Color(0.086, 0.125, 0.141)
const C_TAB_ACTIVE: Color = Color(0.910, 0.773, 0.447, 0.3)
const C_CELL_BG: Color = Color(0.122, 0.169, 0.192)
const C_CELL_EMPTY: Color = Color(0.106, 0.153, 0.169, 0.60)
const C_DETAIL_BG: Color = Color(0.110, 0.149, 0.173)
const C_GOLD: Color = Color(0.910, 0.773, 0.447)
const C_GOLD_DIM: Color = Color(0.839, 0.694, 0.416, 0.60)
const C_GREEN: Color = Color(0.4, 0.8, 0.4)
const C_RED: Color = Color(0.8, 0.4, 0.4)

var _built: bool = false
var _当前标签: String = "地块"  # "地块" 或 "作物类型"
var _选中索引: int = -1
var _地块列表: Array = []
var _作物列表: Array = []

# 作物详细描述字典
const 作物描述: Dictionary = {
	"灵草": "天地灵草，吸纳日月精华而生。成熟后可收获大量灵草，是炼丹的基础材料，用途广泛，宗门必备。",
	"灵谷": "灵气滋养的稻谷，颗粒饱满，蕴含纯净灵气。食用后可快速恢复灵气，是修士日常修炼的重要补给。",
	"灵花": "珍稀灵花，绽放时散发悟道清香。闻之可启迪智慧，收获后可转化为悟道点，助弟子参悟功法。",
	"灵果": "仙家灵果，吸天地灵气凝结而成。果味甘甜，食之可增加灵石，是宗门重要的经济来源。",
	"灵药": "珍贵灵药，生长条件苛刻，药效强劲。成熟后可收获高级炼丹材料，用于炼制高品质丹药。",
	"灵茶": "云雾灵茶，生长于高山之巅，吸收云雾精华。饮之可宁心静气，提升心境，降低心魔滋生的概率。",
	"灵米": "灵田稻米，粒粒晶莹，蕴含宗门气运。食用后可提升宗门声望，是招待贵客的上佳之选。",
	"百年灵参": "百年灵参，根须如龙，蕴含磅礴生机。服之可增加寿元，是突破境界、延续生命的稀世珍宝。",
	"百年赤心灵芝": "百年赤心灵芝，菌盖如伞，疗伤圣品。可治疗道伤，加速弟子伤势恢复，是宗门医堂的必备药材。",
	"灵桃": "蟠桃灵果，五百年一开花，五百年一结果。食之可增加突破成功率，是冲击境界的无上助力。",
	"灵莲": "九品灵莲，出淤泥而不染，濯清涟而不妖。可增强神识，提升弟子感知力与修炼悟性。",
	"灵竹": "紫竹灵竹，竹身坚韧，竹叶锋利。成熟后可收获大量炼器材料，用于锻造各种法器装备。",
	"灵菊": "解毒灵菊，花性寒凉，清热解毒。可解除各种毒素，是应对毒修、毒雾、毒丹的必备之物。",
	"灵梅": "寒梅灵花，傲雪凌霜，风骨傲然。可磨炼心境，提升弟子心性坚定度，减少走火入魔的风险。",
	"灵兰": "幽兰灵草，生于深谷，不以无人而不芳。可启迪悟道，收获后可转化为大量悟道点，助弟子精进。",
}

var _bg: ColorRect
var _标题标签: Label
var _返回按钮: Button
var _地块标签按钮: Button
var _作物标签按钮: Button
var _解锁按钮: Button
var _地块网格: GridContainer
var _作物列表容器: VBoxContainer
var _详情面板: Panel
var _详情地块: Label
var _详情状态: Label
var _详情种植: Label
var _详情成熟: Label
var _详情效果: Label
var _详情描述: Label
var _种植按钮: Button
var _收获按钮: Button
var _种植类型按钮: Button

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
	# ★ 2026-09-16（老模板页头升级）：换用全站标准返回钮外观（圆环 + 内嵌金色箭头，
	#   同 make_back_button / Ardot 01 屏页头）。**保留原热区 60×30 ⇒ 布局零变动**，
	#   图标按 KEEP_ASPECT_CENTERED 居中 ⇒ 视觉为 30 直径圆环。原为写死「折返」的方钮，
	#   与其余 60 个二级页的返回键不一致。
	UITheme.装饰为返回钮(_返回按钮)
	
	# 标题
	_标题标签 = Label.new()
	_标题标签.text = "药园"
	_标题标签.position = Vector2(80, 18)
	UITheme.apply_project_font(_标题标签, UITheme.FONT_TITLE, true)
	_标题标签.add_theme_color_override("font_color", C_GOLD)
	顶部栏.add_child(_标题标签)
	
	# 解锁按钮
	_解锁按钮 = Button.new()
	_解锁按钮.text = "开辟灵田"
	_解锁按钮.position = Vector2(380, 15)
	_解锁按钮.size = Vector2(90, 30)
	_解锁按钮.pressed.connect(_on开辟灵田)
	顶部栏.add_child(_解锁按钮)
	
	# 标签栏
	var 标签栏 = Panel.new()
	标签栏.set_anchors_preset(Control.PRESET_TOP_WIDE)
	标签栏.offset_top = 60
	标签栏.custom_minimum_size = Vector2(0, 40)
	标签栏.add_theme_stylebox_override("panel", create_stylebox(C_TAB_BG))
	add_child(标签栏)
	
	# 地块标签按钮
	_地块标签按钮 = Button.new()
	_地块标签按钮.text = "地块"
	_地块标签按钮.position = Vector2(50, 5)
	_地块标签按钮.size = Vector2(100, 30)
	_地块标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE))
	_地块标签按钮.pressed.connect(func(): _切换标签("地块"))
	标签栏.add_child(_地块标签按钮)
	
	# 作物类型标签按钮
	_作物标签按钮 = Button.new()
	_作物标签按钮.text = "作物类型"
	_作物标签按钮.position = Vector2(170, 5)
	_作物标签按钮.size = Vector2(120, 30)
	_作物标签按钮.pressed.connect(func(): _切换标签("作物类型"))
	标签栏.add_child(_作物标签按钮)
	
	# 地块网格区域
	var 网格区域 = ScrollContainer.new()
	网格区域.set_anchors_preset(Control.PRESET_FULL_RECT)
	网格区域.offset_top = 110
	网格区域.offset_bottom = -254
	网格区域.offset_left = 10
	网格区域.offset_right = -10
	add_child(网格区域)
	
	_地块网格 = GridContainer.new()
	_地块网格.set_anchors_preset(Control.PRESET_FULL_RECT)
	_地块网格.columns = 3
	_地块网格.add_theme_constant_override("h_separation", 15)
	_地块网格.add_theme_constant_override("v_separation", 15)
	网格区域.add_child(_地块网格)
	
	# 作物列表区域（初始隐藏）
	_作物列表容器 = VBoxContainer.new()
	_作物列表容器.set_anchors_preset(Control.PRESET_FULL_RECT)
	_作物列表容器.offset_top = 110
	_作物列表容器.offset_bottom = -254
	_作物列表容器.offset_left = 10
	_作物列表容器.offset_right = -10
	_作物列表容器.visible = false
	_作物列表容器.add_theme_constant_override("separation", 8)
	add_child(_作物列表容器)
	
	# 详情面板
	_详情面板 = Panel.new()
	# 修复（实机验收抓出 · 2026-09-12）：BOTTOM_WIDE 只改 anchors（top=bottom=1），
	# offsets 仍为 0 → 面板被算到父容器底边之下（屏幕外）；custom_minimum_size 只撑高度、
	# 不把位置拉回视口。对照 page_world_map_visual 的 legend（显式 offset_top=-52）补齐偏移。
	_详情面板.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_详情面板.custom_minimum_size = Vector2(0, 190)
	# ★ 2026-09-16 修（#009 逐页精修 · 老模板）：详情面板原 offset_bottom = 0 ⇒ 贴死屏幕
	#   下沿，面板内操作按钮触底。下移 MARGIN（24 逻辑 = 54 设计），与列表区 offset_bottom 同步。
	_详情面板.offset_top = -244
	_详情面板.offset_bottom = -54
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
	
	_详情地块 = create_label("地块：-", 16, C_GOLD)
	详情内容.add_child(_详情地块)
	
	_详情状态 = create_label("状态：-", 13)
	详情内容.add_child(_详情状态)
	
	_详情种植 = create_label("种植：-", 13)
	详情内容.add_child(_详情种植)
	
	_详情成熟 = create_label("成熟：-", 13)
	详情内容.add_child(_详情成熟)
	
	_详情效果 = create_label("效果：-", 13)
	详情内容.add_child(_详情效果)
	
	_详情描述 = create_label("", 12, UITheme.获取弱文字色())
	详情内容.add_child(_详情描述)
	
	# 按钮区域
	var 按钮区域 = HBoxContainer.new()
	按钮区域.add_theme_constant_override("separation", 10)
	详情内容.add_child(按钮区域)
	
	_种植按钮 = Button.new()
	_种植按钮.text = "种植"
	_种植按钮.pressed.connect(_on种植)
	按钮区域.add_child(_种植按钮)
	
	_收获按钮 = Button.new()
	_收获按钮.text = "收获"
	_收获按钮.pressed.connect(_on收获)
	按钮区域.add_child(_收获按钮)
	
	_种植类型按钮 = Button.new()
	_种植类型按钮.text = "播种此类"
	_种植类型按钮.pressed.connect(_on种植类型)
	按钮区域.add_child(_种植类型按钮)

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
	# 更新标签按钮样式
	if 标签 == "地块":
		_地块标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE))
		_作物标签按钮.add_theme_stylebox_override("normal", create_stylebox(Color.TRANSPARENT))
		_地块网格.visible = true
		_作物列表容器.visible = false
	else:
		_地块标签按钮.add_theme_stylebox_override("normal", create_stylebox(Color.TRANSPARENT))
		_作物标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE))
		_地块网格.visible = false
		_作物列表容器.visible = true
	refresh()

func refresh() -> void:
	for _c in _地块网格.get_children():
		_c.queue_free()
	for _c in _作物列表容器.get_children():
		_c.queue_free()
	
	if _当前标签 == "地块":
		_地块列表 = Game.获取药园地块列表()
		for i in _地块列表.size():
			var 地块 = _地块列表[i]
			var 地块按钮 = Button.new()
			地块按钮.custom_minimum_size = Vector2(140, 100)
			if 地块.get("已解锁", false):
				if 地块.get("种植物品", "") != "":
					地块按钮.text = "地块%d\n%s\n%d天后成熟" % [i + 1, 地块.get("种植物品", ""), max(0, 地块.get("成熟时间", 0) - Game.累计游戏日)]
					地块按钮.add_theme_color_override("font_color", C_GREEN)
				else:
					地块按钮.text = "地块%d\n（空）" % (i + 1)
			else:
				地块按钮.text = "地块%d\n（未解锁）" % (i + 1)
				地块按钮.add_theme_color_override("font_color", C_RED)
			if i == _选中索引:
				地块按钮.add_theme_stylebox_override("normal", create_stylebox(C_GOLD_DIM))
			var 索引 = i
			地块按钮.pressed.connect(func(): _on选中地块(索引))
			_地块网格.add_child(地块按钮)
			地块按钮.modulate.a = 0.0
			地块按钮.create_tween().tween_property(地块按钮, "modulate:a", 1.0, 0.25)
	else:
		_作物列表 = Game.获取可种植作物列表()
		for i in _作物列表.size():
			var 作物配置: Dictionary = _作物列表[i]
			var 作物名称: String = str(作物配置.get("名称", ""))
			var 行 = Button.new()
			行.text = "%s - 成熟%d日，收获%d个，类型：%s" % [作物名称, 作物配置.get("成熟天数", 3), 作物配置.get("收获数量", 1), 作物配置.get("收获类型", "材料")]
			行.custom_minimum_size = Vector2(0, 45)
			UITheme.apply_project_font(行, UITheme.FONT_BODY, false)
			if i == _选中索引:
				行.add_theme_stylebox_override("normal", create_stylebox(C_GOLD_DIM))
			var 索引 = i
			行.pressed.connect(func(): _on选中作物(索引))
			_作物列表容器.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	
	_更新详情()

func _更新详情() -> void:
	if _当前标签 == "地块":
		if _选中索引 < 0 or _选中索引 >= _地块列表.size():
			_详情地块.text = "地块：-"
			_详情状态.text = "状态：-"
			_详情种植.text = "种植：-"
			_详情成熟.text = "成熟：-"
			_详情效果.text = "效果：-"
			_详情描述.text = ""
			_种植按钮.visible = true
			_收获按钮.visible = true
			_种植类型按钮.visible = false
			return
		var 地块 = _地块列表[_选中索引]
		_详情地块.text = "地块：第%d块" % (_选中索引 + 1)
		if 地块.get("已解锁", false):
			_详情状态.text = "状态：已开垦"
			if 地块.get("种植物品", "") != "":
				_详情种植.text = "种植：%s" % 地块.get("种植物品", "")
				_详情成熟.text = "成熟：%d日后" % max(0, 地块.get("成熟时间", 0) - Game.累计游戏日)
				_详情效果.text = "效果：收获后获得对应资源"
				_详情描述.text = "此地已种植%s，耐心等待成熟后即可收获。成熟时日受灵田品级、灵脉品质等因素影响。" % 地块.get("种植物品", "")
			else:
				_详情种植.text = "种植：（空）"
				_详情成熟.text = "成熟：-"
				_详情效果.text = "效果：可以种植作物"
				_详情描述.text = "此地灵气充沛，土壤肥沃，是种植灵草灵药的上佳之地。轻触「播种」选择作物开始种植。"
		else:
			_详情状态.text = "状态：未开垦"
			_详情种植.text = "种植：-"
			_详情成熟.text = "成熟：-"
			_详情效果.text = "效果：轻触「开辟灵田」解锁"
			_详情描述.text = "此地尚未开垦，杂草丛生，灵气稀薄。需消耗灵石和人力开垦后方可种植。解锁更多地块可同时种植更多作物，提升宗门资源产出。"
		_种植按钮.visible = true
		_收获按钮.visible = true
		_种植类型按钮.visible = false
	else:
		if _选中索引 < 0 or _选中索引 >= _作物列表.size():
			_详情地块.text = "作物：-"
			_详情状态.text = ""
			_详情种植.text = ""
			_详情成熟.text = ""
			_详情效果.text = ""
			_详情描述.text = ""
			_种植按钮.visible = false
			_收获按钮.visible = false
			_种植类型按钮.visible = true
			return
		var 作物配置: Dictionary = _作物列表[_选中索引]
		var 作物名称: String = str(作物配置.get("名称", ""))
		_详情地块.text = "作物：%s" % 作物名称
		_详情状态.text = ""
		_详情种植.text = "成熟天数：%d日" % 作物配置.get("成熟天数", 3)
		_详情成熟.text = "收获数量：%d个" % 作物配置.get("收获数量", 1)
		_详情效果.text = "收获类型：%s" % 作物配置.get("收获类型", "材料")
		_详情描述.text = 作物描述.get(作物名称, "播种此类，成熟后收获对应资源")
		_种植按钮.visible = false
		_收获按钮.visible = false
		_种植类型按钮.visible = true

func _on返回() -> void:
	返回主页.emit()

func _on选中地块(索引: int) -> void:
	_选中索引 = 索引
	refresh()

func _on选中作物(索引: int) -> void:
	_选中索引 = 索引
	refresh()

func _on开辟灵田() -> void:
	var 结果 = Game.解锁药园地块(100)
	if 结果.get("成功", false):
		refresh()

func _on种植() -> void:
	if _选中索引 < 0 or _选中索引 >= _地块列表.size():
		return
	var 地块 = _地块列表[_选中索引]
	if not 地块.get("已解锁", false):
		return
	if 地块.get("种植物品", "") != "":
		return
	var 结果 = Game.种植药园(_选中索引, "灵草")
	if 结果.get("成功", false):
		refresh()

func _on种植类型() -> void:
	# ★ 2026-09-16 修（死键扫描实测判 DEAD）：未择定作物 / 无空闲地块 / 播种失败时全部静默
	#   ⇒ 按钮亮着却毫无反馈。改为：每个失败分支都给出明确回应。
	if _选中索引 < 0 or _选中索引 >= _作物列表.size():
		Game.添加提示("尚未择定作物")
		return
	var 作物名称: String = str(_作物列表[_选中索引].get("名称", ""))
	# 找到第一个空地块进行种植
	var 找到了地块: bool = false
	for i in _地块列表.size():
		var 地块 = _地块列表[i]
		if 地块.get("已解锁", false) and 地块.get("种植物品", "") == "":
			找到了地块 = true
			var 结果 = Game.种植药园(i, 作物名称)
			if 结果.get("成功", false):
				_切换标签("地块")
			else:
				Game.添加提示(str(结果.get("原因", "播种未成")))
			break
	if not 找到了地块:
		Game.添加提示("灵田已满，无空闲地块可播种")

func _on收获() -> void:
	if _选中索引 < 0 or _选中索引 >= _地块列表.size():
		return
	var 地块 = _地块列表[_选中索引]
	if not 地块.get("已解锁", false):
		return
	if 地块.get("种植物品", "") == "":
		return
	var 结果 = Game.收获药园(_选中索引)
	if 结果.get("成功", false):
		refresh()




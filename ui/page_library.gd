extends Control

# 藏书阁系统页面（增强版）
# 展示已入阁列表和典籍类型，支持收录、阅读、批注等操作

signal 返回主页

const C_BG_TOP: Color = Color(0.106, 0.153, 0.169)
const C_BG_BOT: Color = UITheme.获取面板底色()
const C_TOPBAR_BG: Color = Color(0.106, 0.153, 0.169, 0.90)
const C_TAB_BG: Color = Color(0.086, 0.125, 0.141)
const C_TAB_ACTIVE: Color = Color(0.910, 0.773, 0.447, 0.3)
const C_CELL_BG: Color = Color(0.122, 0.169, 0.192)
const C_DETAIL_BG: Color = Color(0.110, 0.149, 0.173)
const C_GOLD: Color = Color(0.910, 0.773, 0.447)
const C_GOLD_DIM: Color = Color(0.839, 0.694, 0.416, 0.60)
const C_GREEN: Color = Color(0.4, 0.8, 0.4)

var _built: bool = false
var _当前标签: String = "已入阁"  # "已入阁" 或 "典籍类型" 或 "技能"
var _选中索引: int = -1
var _典籍列表: Array = []
var _类型列表: Array = []
var _技能列表: Array = []
var _技能标签按钮: Button = null

# 根据典籍类型和品阶生成描述
func _生成典籍描述(典籍: Dictionary) -> String:
	var 类型 = 典籍.get("类型", "杂项类")
	var 品阶 = 典籍.get("品阶", "凡品")
	var 名称 = 典籍.get("名称", "无名典籍")
	var 品阶描述 = {
		"凡阶": "入门级典籍，内容浅显易懂，适合初入山门的弟子研读。",
		"灵阶": "精修级典籍，蕴含灵气精华，研读可小有心得。",
		"宝阶": "珍本级典籍，宗门珍藏，非核心弟子不可查阅。",
		"王阶": "秘典级典籍，历代宗主真传，蕴含大道至理。",
		"圣阶": "圣典级典籍，上古仙人遗留，参悟可脱胎换骨。",
		"仙阶": "仙籍级典籍，仙界流传，凡人得之可一步登仙。",
	}
	var 类型描述 = {
		"修炼类": "此书记载修炼功法，详细阐述灵气运行之法、经脉拓展之术。研读可启迪智慧，提升修炼速度，助弟子在修行路上突飞猛进。",
		"阵法类": "此书记载阵法布置，包含阵眼定位、灵力引导、攻防转换等核心要诀。研读可提升阵法造诣，布置出更强的护山大阵与杀阵。",
		"丹道类": "此书记载炼丹之术，从药材辨识、火候控制到丹方配比，无所不包。研读可提升炼丹成功率，炼制出更高品质的丹药。",
		"器道类": "此书记载炼器之法，涵盖材料处理、器胚锻造、符文铭刻等全套工艺。研读可提升炼器成功率，锻造出更强的法器法宝。",
		"杂项类": "此书内容驳杂，涵盖符箓、占卜、星象、地理等诸多杂学。研读虽无专攻之效，却可博闻强识，获得不少悟道点。",
		"历史类": "此书记载宗门历史，从开宗立派到历代兴衰，历历在目。研读可了解宗门传承，提升宗门声望与弟子归属感。",
	}
	var 基础描述 = 品阶描述.get(品阶, "珍贵典籍，内容博大精深。")
	var 专业描述 = 类型描述.get(类型, "此书记载修真杂学，开卷有益。")
	return "《%s》\n\n%s\n\n%s\n\n阅读可获得悟道点，并临时提升对应领域能力。每日限读一次，温故而知新。" % [名称, 基础描述, 专业描述]

var _bg: ColorRect
var _标题标签: Label
var _返回按钮: Button
var _已入阁标签按钮: Button
var _类型标签按钮: Button
var _收录按钮: Button
var _列表: VBoxContainer
var _详情面板: Panel
var _详情名: Label
var _详情品阶: Label
var _详情类型: Label
var _详情注释: Label
var _详情效果: Label
var _详情描述: Label
var _阅读按钮: Button
var _注释按钮: Button
var _收录类型按钮: Button
var _指派容器: HBoxContainer
var _指派说明: Label
var _当前技能ID: String = ""

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
	_标题标签.text = "藏书阁"
	_标题标签.position = Vector2(80, 18)
	UITheme.apply_project_font(_标题标签, UITheme.FONT_TITLE, true)
	_标题标签.add_theme_color_override("font_color", C_GOLD)
	顶部栏.add_child(_标题标签)
	
	# 收录按钮
	_收录按钮 = Button.new()
	_收录按钮.text = "入阁"
	_收录按钮.position = Vector2(380, 15)
	_收录按钮.size = Vector2(90, 30)
	_收录按钮.pressed.connect(_on入阁)
	顶部栏.add_child(_收录按钮)
	
	# 标签栏
	var 标签栏 = Panel.new()
	标签栏.set_anchors_preset(Control.PRESET_TOP_WIDE)
	标签栏.offset_top = 60
	标签栏.custom_minimum_size = Vector2(0, 40)
	标签栏.add_theme_stylebox_override("panel", create_stylebox(C_TAB_BG))
	add_child(标签栏)
	
	# 已入阁标签按钮
	_已入阁标签按钮 = Button.new()
	_已入阁标签按钮.text = "已入阁"
	_已入阁标签按钮.position = Vector2(50, 5)
	_已入阁标签按钮.size = Vector2(100, 30)
	_已入阁标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE))
	_已入阁标签按钮.pressed.connect(func(): _切换标签("已入阁"))
	标签栏.add_child(_已入阁标签按钮)
	
	# 典籍类型标签按钮
	_类型标签按钮 = Button.new()
	_类型标签按钮.text = "典籍类型"
	_类型标签按钮.position = Vector2(170, 5)
	_类型标签按钮.size = Vector2(120, 30)
	_类型标签按钮.pressed.connect(func(): _切换标签("典籍类型"))
	标签栏.add_child(_类型标签按钮)

	# 技能学习标签按钮
	_技能标签按钮 = Button.new()
	_技能标签按钮.text = "技能学习"
	_技能标签按钮.position = Vector2(300, 5)
	_技能标签按钮.size = Vector2(120, 30)
	_技能标签按钮.pressed.connect(func(): _切换标签("技能"))
	标签栏.add_child(_技能标签按钮)
	
	# 列表区域
	var 列表区域 = ScrollContainer.new()
	列表区域.set_anchors_preset(Control.PRESET_FULL_RECT)
	列表区域.offset_top = 110
	列表区域.offset_bottom = -254
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
	
	_详情名 = create_label("名称：-", 16, C_GOLD)
	详情内容.add_child(_详情名)
	
	_详情品阶 = create_label("品阶：-", 13)
	详情内容.add_child(_详情品阶)
	
	_详情类型 = create_label("类型：-", 13)
	详情内容.add_child(_详情类型)
	
	_详情注释 = create_label("注释：-", 13)
	详情内容.add_child(_详情注释)
	
	_详情效果 = create_label("效果：-", 13)
	详情内容.add_child(_详情效果)
	
	_详情描述 = create_label("", 12, UITheme.获取弱文字色())
	详情内容.add_child(_详情描述)
	
	# 按钮区域
	var 按钮区域 = HBoxContainer.new()
	按钮区域.add_theme_constant_override("separation", 10)
	详情内容.add_child(按钮区域)
	
	_阅读按钮 = Button.new()
	_阅读按钮.text = "研读"
	_阅读按钮.pressed.connect(_on研读)
	按钮区域.add_child(_阅读按钮)
	
	_注释按钮 = Button.new()
	_注释按钮.text = "批注"
	_注释按钮.pressed.connect(_on批注)
	按钮区域.add_child(_注释按钮)
	
	_收录类型按钮 = Button.new()
	_收录类型按钮.text = "收录此类"
	_收录类型按钮.pressed.connect(_on收录类型)
	按钮区域.add_child(_收录类型按钮)

	# 修习说明：弟子按自身目标/境界 AI 自动消耗宗门贡献前往藏经阁兑换，宗主无需手动指派
	_指派容器 = HBoxContainer.new()
	_指派容器.add_theme_constant_override("separation", 8)
	详情内容.add_child(_指派容器)

	_指派说明 = Label.new()
	_指派说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_指派说明.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_指派说明.text = "本门弟子会依自身目标与境界，自行前往藏经阁兑换功法（消耗宗门贡献）。"
	UITheme.apply_body_text(_指派说明)
	_指派容器.add_child(_指派说明)
	_指派容器.visible = false

## 填充「可修习此技能的弟子」下拉；无人可学时给出原因
## 刷新修习说明：展示当前技能的可修习弟子数与自动兑换规则（宗主无需手动指派）
func _填充指派弟子() -> void:
	if _指派容器 == null or _指派说明 == null or _当前技能ID == "":
		if _指派容器 != null:
			_指派容器.visible = false
		return
	var 可学数: int = 0
	for d in Game.弟子列表:
		if d == null or str(d.状态) != "在宗":
			continue
		for sk in Game.获取弟子可学技能(int(d.弟子ID)):
			if str(sk.get("skill_id", "")) == _当前技能ID:
				可学数 += 1
				break
	_指派说明.text = "本门弟子会依自身目标与境界，自行前往藏经阁兑换功法（消耗宗门贡献）。当前可修习此技者 %d 人。" % 可学数
	_指派容器.visible = true

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
	if _指派容器 != null:
		_指派容器.visible = false
	_当前技能ID = ""
	# 更新标签按钮样式
	_已入阁标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE if 标签 == "已入阁" else Color.TRANSPARENT))
	_类型标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE if 标签 == "典籍类型" else Color.TRANSPARENT))
	if _技能标签按钮:
		_技能标签按钮.add_theme_stylebox_override("normal", create_stylebox(C_TAB_ACTIVE if 标签 == "技能" else Color.TRANSPARENT))
	refresh()

func refresh() -> void:
	for _c in _列表.get_children():
		_c.queue_free()
	
	if _当前标签 == "已入阁":
		_典籍列表 = Game.获取藏书阁列表()
		if _典籍列表.is_empty():
			_列表.add_child(UITheme.建空态("尚无典籍，轻触「入阁」收录"))
			return
		for i in _典籍列表.size():
			var 典籍 = _典籍列表[i]
			var 行 = Button.new()
			行.text = "%s（%s）- %s - 注释 第 %d 重" % [典籍.get("名称", ""), 典籍.get("品阶", ""), 典籍.get("类型", ""), 典籍.get("注释等级", 0)]
			行.custom_minimum_size = Vector2(0, 45)
			UITheme.apply_project_font(行, UITheme.FONT_BODY, false)
			if i == _选中索引:
				行.add_theme_stylebox_override("normal", create_stylebox(C_GOLD_DIM))
			var 索引 = i
			行.pressed.connect(func(): _on选中典籍(索引))
			_列表.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	else:
		_类型列表 = Game.获取所有典籍类型()
		if _类型列表.is_empty():
			var 空标签 = create_label("尚未分类", 14, UITheme.获取弱文字色())
			_列表.add_child(空标签)
			return
		for i in _类型列表.size():
			var 类型 = _类型列表[i]
			var 行 = Button.new()
			行.text = "%s - %s" % [类型.get("类型", ""), 类型.get("描述", "")]
			行.custom_minimum_size = Vector2(0, 45)
			UITheme.apply_project_font(行, UITheme.FONT_BODY, false)
			if i == _选中索引:
				行.add_theme_stylebox_override("normal", create_stylebox(C_GOLD_DIM))
			var 索引 = i
			行.pressed.connect(func(): _on选中类型(索引))
			_列表.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)

	if _当前标签 == "技能":
		_技能列表 = Game.获取所有技能()
		if _技能列表.is_empty():
			var 空标签 = create_label("暂无技能配置", 14, UITheme.获取弱文字色())
			_列表.add_child(空标签)
		else:
			for i in _技能列表.size():
				var 技能 = _技能列表[i]
				var 行 = Button.new()
				行.text = "%s（%s）- %s - 消耗%d贡献" % [技能.get("skill_name", ""), 技能.get("grade", ""), 技能.get("skill_type", ""), int(技能.get("learn_cost", 0))]
				行.custom_minimum_size = Vector2(0, 45)
				UITheme.apply_project_font(行, UITheme.FONT_BODY, false)
				var 索引 = i
				行.pressed.connect(func(): _on学习技能(索引))
				_列表.add_child(行)
				行.modulate.a = 0.0
				行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	
	_更新详情()

func _更新详情() -> void:
	if _当前标签 == "已入阁":
		if _选中索引 < 0 or _选中索引 >= _典籍列表.size():
			_详情名.text = "名称：-"
			_详情品阶.text = "品阶：-"
			_详情类型.text = "类型：-"
			_详情注释.text = "注释：-"
			_详情效果.text = "效果：-"
			_详情描述.text = ""
			_阅读按钮.visible = true
			_注释按钮.visible = true
			_收录类型按钮.visible = false
			return
		var 典籍 = _典籍列表[_选中索引]
		_详情名.text = "名称：%s" % 典籍.get("名称", "")
		_详情品阶.text = "品阶：%s" % 典籍.get("品阶", "")
		_详情类型.text = "类型：%s" % 典籍.get("类型", "")
		_详情注释.text = "注释：第 %d 重（+%.0f%%阅读加成）" % [典籍.get("注释等级", 0), 典籍.get("注释等级", 0) * 2]
		_详情效果.text = "效果：阅读获得悟道点，临时修炼加成"
		_详情描述.text = _生成典籍描述(典籍)
		_阅读按钮.visible = true
		_注释按钮.visible = true
		_收录类型按钮.visible = false
	else:
		if _选中索引 < 0 or _选中索引 >= _类型列表.size():
			_详情名.text = "类型：-"
			_详情品阶.text = ""
			_详情类型.text = ""
			_详情注释.text = ""
			_详情效果.text = ""
			_详情描述.text = ""
			_阅读按钮.visible = false
			_注释按钮.visible = false
			_收录类型按钮.visible = true
			return
		var 类型 = _类型列表[_选中索引]
		_详情名.text = "类型：%s" % 类型.get("类型", "")
		_详情品阶.text = ""
		_详情类型.text = ""
		_详情注释.text = ""
		_详情效果.text = "效果：阅读加成+%.0f%%" % (类型.get("阅读加成", 0.0) * 100)
		_详情描述.text = 类型.get("描述", "")
		_阅读按钮.visible = false
		_注释按钮.visible = false
		_收录类型按钮.visible = true

func _on返回() -> void:
	返回主页.emit()

func _on选中典籍(索引: int) -> void:
	_选中索引 = 索引
	refresh()

func _on选中类型(索引: int) -> void:
	_选中索引 = 索引
	refresh()

func _on入阁() -> void:
	var 结果 = Game.收录典籍("随机典籍", "灵品", "修炼类")
	if 结果.get("成功", false):
		refresh()

func _on收录类型() -> void:
	# ★ 2026-09-16 修（死键扫描实测判 DEAD）：未择定类别时静默 return ⇒ 可点但无声。
	if _选中索引 < 0 or _选中索引 >= _类型列表.size():
		Game.添加提示("尚未择定典籍类别")
		return
	var 类型 = _类型列表[_选中索引]
	var 结果 = Game.收录典籍("随机典籍", "灵品", 类型.get("类型", "修炼类"))
	if 结果.get("成功", false):
		_切换标签("已入阁")

func _on研读() -> void:
	if _选中索引 < 0 or _选中索引 >= _典籍列表.size():
		return
	var 典籍 = _典籍列表[_选中索引]
	var 结果 = Game.阅读典籍(典籍.get("ID", 0))
	if 结果.get("成功", false):
		refresh()

func _on批注() -> void:
	if _选中索引 < 0 or _选中索引 >= _典籍列表.size():
		return
	var 典籍 = _典籍列表[_选中索引]
	var 结果 = Game.添加典籍注释(典籍.get("ID", 0), "这是一条注释")
	if 结果.get("成功", false):
		refresh()


func _on学习技能(索引: int) -> void:
	if 索引 < 0 or 索引 >= _技能列表.size():
		return
	var 技能 = _技能列表[索引]
	# 信息展示：功法详情 + 已学会弟子（弟子AI自动兑换，玩家不手动操作）
	_详情名.text = "【%s】%s" % [str(技能.get("grade", "")), str(技能.get("skill_name", ""))]
	_详情品阶.text = "类型：%s | 效果：%s | 兑换消耗：%d贡献" % [str(技能.get("skill_type", "")), str(技能.get("effect_value", "")), int(技能.get("learn_cost", 0))]
	_详情类型.text = "解锁境界：%s" % str(技能.get("unlock_realm", ""))
	_详情注释.text = "说明：弟子平日依自身目标与境界自行前往藏经阁兑换功法，宗主无需手动指派"
	_详情效果.text = ""
	_当前技能ID = str(技能.get("skill_id", ""))
	_填充指派弟子()

	# 显示已学会该技能的弟子
	var 已学会: String = ""
	var 计数: int = 0
	for d in Game.弟子列表:
		if d == null:
			continue
		var 弟子技能: Array = Game.获取弟子技能(int(d.弟子ID))
		for sk in 弟子技能:
			if str(sk.get("skill_id", "")) == str(技能.get("skill_id", "")):
				已学会 += "%s(第 %d 重/%s) " % [str(d.姓名), int(sk.get("level", 1)), str(sk.get("来源", ""))]
				计数 += 1
				break
	if 计数 > 0:
		_详情描述.text = "已习得弟子（%d人）：%s" % [计数, 已学会]
	else:
		_详情描述.text = "尚无弟子习得此功法"




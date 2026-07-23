# main.gd —— 主界面（M1.5 自动化养成 · 灰模布局/主题重构）
# 用代码生成全部 UI：新建 Control 节点作为根 -> 挂本脚本 -> 设为启动场景即可运行
# 本版：分区面板 + 主题配色 + 标签页（弟子/待抉择/御兽）+ 底部详情条；纯占位美术，结构清晰、竖屏友好。
# 美术接口已预留：测灵根过场/建筑面板/弟子卡均可后续替换为真实立绘与动画节点。
extends Control

const Disciple = preload("res://disciple.gd")
const Item = preload("res://item.gd")
const Beast = preload("res://beast.gd")
const BattleManager = preload("res://BattleManager.gd")
const Quest = preload("res://quest.gd")
const StageDataLoader = preload("res://StageDataLoader.gd")

# 主题色（玄洲·水墨古卷国风，低饱和东方古典）
const 宣纸 := Color(0.88, 0.83, 0.73)      # 做旧宣纸基底
const 宣纸亮 := Color(0.93, 0.89, 0.80)    # 面板纸（略亮）
const 墨黑 := Color(0.15, 0.13, 0.11)      # 墨色文字
const 次墨 := Color(0.42, 0.37, 0.31)      # 次级文字
const 暗金 := Color(0.64, 0.49, 0.22)      # 暗金高亮
const 青灰 := Color(0.40, 0.48, 0.47)      # 青灰次强调
const 木色 := Color(0.46, 0.36, 0.26)      # 木框
const 墨底 := Color(0.12, 0.11, 0.10)      # 深墨（弹窗遮罩/状态栏）

# 离山汇总稀有度颜色（对齐装备品阶体系）
const 颜色_良品 := Color(0.28, 0.65, 0.32)     # 绿色 - 良品/正向事件
const 颜色_上品 := Color(0.26, 0.48, 0.78)     # 蓝色 - 上品/重要事件
const 颜色_极品 := Color(0.58, 0.32, 0.68)     # 紫色 - 极品/重大事件
const 颜色_琐事 := Color(0.55, 0.50, 0.45)     # 浅灰 - 琐事/无效事件
# 物品七品阶标题染色（对齐 item.gd 品阶序；非奇遇四档稀有度）
const 品阶色: Dictionary = {
	"凡阶": Color(0.85, 0.85, 0.82),
	"灵阶": Color(0.40, 0.85, 0.45),
	"宝阶": Color(0.38, 0.68, 1.00),
	"王阶": Color(0.70, 0.52, 1.00),
	"圣阶": Color(1.00, 0.72, 0.32),
	"仙阶": Color(0.831, 0.686, 0.216),	# D4AF37 金（经典金，醒目，区别于圣橙与暗金）
	"道阶": Color(0.702, 0.259, 0.239),	# B3423D 朱砂红（对齐 v2.0 朱砂色）
}
# 全局品阶染色入口：物品/装备/功法/丹药等所有实体的品阶染色统一调用此函数，
# 避免各处硬编码颜色值，保证全游戏视觉统一（键为 item.gd 的 品阶 中文字符串）
const 建筑彩蛋映射 := {"dantang": "egg_click_dantang", "yushou": "egg_click_yushou", "lingtian": "egg_click_lingtian"}
const 建筑彩蛋阈值 := {"dantang": 5, "yushou": 5, "lingtian": 3}
var 建筑点击计数: Dictionary = {}
var 掌教点击计数: int = 0
var 纪事异闻仅看: bool = false

func get_rarity_color(品阶: String) -> Color:
	return 品阶色.get(品阶, 暗金)
# 符号图标映射（与 game_state.gd ET_* 枚举对应）
const 符号表 := {
	"breakthrough": "🔺", "appoint": "📜", "quest": "✅",
	"loot": "🎁", "resource": "💰", "sect": "📜", "info": "ℹ️",
}
const 符号失败 := "❌"   # trivial quest 用

# P0-BUILD-4：建筑总览 UI 分类 / 职能标签 / 类别辅助色（复用现有色值常量，不硬编码）
const 建筑类别序 := ["生产", "功能", "战略"]
const 建筑类别 := {
	"生产": ["lingtian", "kuangmai", "dantang", "qitang"],
	"功能": ["cangjing", "zhifa", "gongxun", "tanwei"],
	"战略": ["yuying", "yushou", "zhenfa", "xichi"],
}
# 建筑 key → 类别（反查，供卡片辅助色取用）
const 建筑_类别反查 := {
	"lingtian": "生产", "kuangmai": "生产", "dantang": "生产", "qitang": "生产",
	"cangjing": "功能", "zhifa": "功能", "gongxun": "功能", "tanwei": "功能",
	"yuying": "战略", "yushou": "战略", "zhenfa": "战略", "xichi": "战略",
}
# 职能标签（小字次要灰，按建筑取；复用任务示例词 核心生产/防御增益/人才入口）
const 建筑职能标签 := {
	"lingtian": "核心生产", "kuangmai": "核心生产", "dantang": "核心生产", "qitang": "核心生产",
	"cangjing": "功法中枢", "zhifa": "纪律中枢", "gongxun": "功绩中枢", "tanwei": "情报中枢",
	"yuying": "接引·道基培育", "yushou": "护宗灵兽", "zhenfa": "防御增益", "xichi": "重铸中枢",
}
# 类别辅助色：生产→良品绿 / 功能→上品蓝 / 战略→暗金（参考宗门等级金），均复用现有常量
const 建筑类别色 := {
	"生产": 颜色_良品,
	"功能": 颜色_上品,
	"战略": 暗金,
}
# 建筑 key → 负责人全局 buff 维度（对齐 汇总负责人全局buff 映射）
const 建筑全局维度 := {
	"qitang": "攻", "kuangmai": "防", "zhenfa": "防",
	"dantang": "血", "zhifa": "速", "tanwei": "速",
	"cangjing": "修炼", "lingtian": "产出", "yuying": "测灵",
}
const 维度显示 := {"攻": "攻击", "防": "防御", "血": "气血", "速": "速度", "修炼": "修炼", "产出": "产出", "测灵": "测灵"}

var 状态栏: Label
var 战报: Label
var 详情: Label
var 列表: VBoxContainer
# P0：弟子总览 总战力 + 排序（仅 UI 层，零底层改动）
var 弟子页头: Control
var 总战力标签: Label
var 上次总战力 := 0
var 弟子排序维度 := "默认"
var 弟子排序升序 := false
var 排序按钮组: Dictionary = {}   # 维度名 -> Button
var 抉择区: VBoxContainer
var 离山面板: PanelContainer          # 离山汇总外层面板
var 离山内容区: VBoxContainer           # 离山面板内层VBox（动态重建内容）
var _琐事已展开 := false                  # 琐事折叠状态（rebuild后恢复）
var _重大已展开 := true                   # 重大事件折叠状态，默认展开
var _战报筛选: String = ""                # 离山汇总事件筛选：""=全部；breakthrough/appoint/quest
var _attr_line_pool: Array = []           # S1 预埋：属性行控件对象池（详情复用优化用）
var _当前详情遮: Control = null            # 详情弹窗单实例守卫：开新窗前先释放旧窗，防快速连点层叠
var 御兽区: VBoxContainer
var 纪事区: VBoxContainer
var 当前选中: Disciple = null
var 装备面板节点: Control = null   # A5 装备面板当前实例，重建前先释放避免叠加
var 历练滚动列: VBoxContainer = null  # 历练关卡列表（战斗胜利后需刷新）
# 新手引导系统（A 包：单线性四步，纯灰模）：阶段 0未开始/1-4四步/5完成（Game.引导阶段 为事实源）
var 引导_建筑按钮: Button = null
var 引导_招收按钮: Button = null
var 引导_历练按钮: Button = null
var 引导_层: Control = null          # 引导覆盖层（暗化+高亮框+气泡），最后 add_child 置顶，mouse_filter 穿透
var 引导_跳过按钮: Button = null     # 右上角常驻「跳过引导」，阶段<5 时可见
var 引导_开场段: int = 0             # 开场叙事当前段序号
var _引导已收尾: bool = false         # 收尾弹窗一次性标记（播完不再重复）
var _坊市提示: String = ""
var _任务提示: String = ""
var 页控: Dictionary = {}
# Step 2 奇遇基础调度：signal 入队、逐个弹窗，避免推演期多奇遇堆叠
var 奇遇队列: Array = []
var 奇遇弹窗中: bool = false
const 页名 := ["弟子", "待抉择", "御兽", "纪事"]

func _ready():
	theme = 造主题()

	# 背景
	var bg := ColorRect.new()
	bg.color = 宣纸
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 根滚动容器（整页可滚，解决内容超屏无法下滑）
	var 外滚 := ScrollContainer.new()
	外滚.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(外滚)

	var 根 := VBoxContainer.new()
	根.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	根.add_theme_constant_override("separation", 6)
	根.add_theme_constant_override("margin_left", 8)
	根.add_theme_constant_override("margin_right", 8)
	根.add_theme_constant_override("margin_top", 8)
	根.add_theme_constant_override("margin_bottom", 8)
	外滚.add_child(根)

	# 顶部标题 + 状态面板
	var 掌教标题 := Button.new()
	掌教标题.text = "《太玄宗门录》· 掌教治宗"
	掌教标题.flat = true
	掌教标题.add_theme_font_size_override("font_size", 18)
	掌教标题.add_theme_color_override("font_color", 暗金)
	掌教标题.pressed.connect(_on_掌教点击彩蛋)
	根.add_child(掌教标题)
	var 别名 := Label.new()
	别名.text = "又名：开局接手太玄宗"
	别名.add_theme_font_size_override("font_size", 12)
	别名.add_theme_color_override("font_color", 次墨)
	根.add_child(别名)
	状态栏 = Label.new()
	状态栏.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var 状态面板: PanelContainer = 新面板("")
	状态面板.get_child(0).add_child(状态栏)
	状态面板.add_theme_stylebox_override("panel", _暗墨面板())
	状态栏.add_theme_color_override("font_color", 暗金)
	根.add_child(状态面板)

	# 按钮行（紧凑，竖屏 480 宽可分两行）
	var 行 := HBoxContainer.new()
	行.add_theme_constant_override("separation", 6)
	根.add_child(行)
	var 推演 := Button.new(); 推演.text = "推演汇总"; 行.add_child(推演); 推演.pressed.connect(_on_推演)
	var 招收 := Button.new(); 招收.text = "开启接引大典"; 行.add_child(招收); 招收.pressed.connect(_on_测灵根)
	引导_招收按钮 = 招收
	var 建筑 := Button.new(); 建筑.text = "建筑总览"; 行.add_child(建筑); 建筑.pressed.connect(_on_建筑总览)
	引导_建筑按钮 = 建筑
	var 行二 := HBoxContainer.new()
	行二.add_theme_constant_override("separation", 6)
	根.add_child(行二)
	var 快进 := Button.new(); 快进.text = "御兽快进"; 行二.add_child(快进); 快进.pressed.connect(_on_快进)
	var 存 := Button.new(); 存.text = "存档"; 行二.add_child(存); 存.pressed.connect(_on_存档)
	var 读 := Button.new(); 读.text = "读档"; 行二.add_child(读); 读.pressed.connect(_on_读档)
	# 调试行：灰模战斗入口 + 测试工具（ADR-003 D7 调试工具）
	var 行三 := HBoxContainer.new()
	行三.add_theme_constant_override("separation", 6)
	根.add_child(行三)
	var 调试 := Button.new(); 调试.text = "调试战斗"; 行三.add_child(调试); 调试.pressed.connect(_on_调试战斗)
	var 历练 := Button.new(); 历练.text = "历练征途"; 行三.add_child(历练); 历练.pressed.connect(_on_历练)
	引导_历练按钮 = 历练
	var 坊市 := Button.new(); 坊市.text = "坊市"; 行三.add_child(坊市); 坊市.pressed.connect(_on_坊市)
	var 任务 := Button.new(); 任务.text = "任务"; 行三.add_child(任务); 任务.pressed.connect(_on_任务)
	# 强制触发征伐奇遇：调试专用，release 导出自动隐藏（OS.is_debug_build 包裹 add_child，不留死代码）
	var 行四 := HBoxContainer.new()
	行四.add_theme_constant_override("separation", 6)
	根.add_child(行四)
	if OS.is_debug_build():
		var 强制征伐 := Button.new(); 强制征伐.text = "强制征伐"
		行四.add_child(强制征伐); 强制征伐.pressed.connect(_on_强制征伐)
		var 重置引导 := Button.new(); 重置引导.text = "重置引导"
		行四.add_child(重置引导); 重置引导.pressed.connect(_on_重置引导)
		var 推演7 := Button.new(); 推演7.text = "推演7天"
		行四.add_child(推演7); 推演7.pressed.connect(_on_推演七日)
		var 强制天品 := Button.new(); 强制天品.text = "强制天品"
		行四.add_child(强制天品); 强制天品.pressed.connect(_on_强制天品)
		var 强制聚气丹 := Button.new(); 强制聚气丹.text = "强制聚气丹"
		行四.add_child(强制聚气丹); 强制聚气丹.pressed.connect(_on_强制聚气丹)
	var 新游戏 := Button.new(); 新游戏.text = "新游戏"
	行四.add_child(新游戏); 新游戏.pressed.connect(_on_新游戏)
	var 快进年 := Button.new(); 快进年.text = "推演1年"
	行四.add_child(快进年); 快进年.pressed.connect(_on_推荐一年)

	# 战报面板（登录推演汇总 → 三层结构：总览/重大事件/琐事折叠）
	离山面板 = 新面板("✦ 离山汇总（你离开期间）")
	离山内容区 = 离山面板.get_child(0) as VBoxContainer  # 新面板返回的 VBox
	离山面板.custom_minimum_size = Vector2(0, 140)
	根.add_child(离山面板)
	# 战报 Label 保留作兼容降级显示（旧存档/无结构化数据时用）
	战报 = Label.new()
	战报.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	战报.visible = false   # 默认隐藏，新UI优先

	# 标签页
	var tb := TabBar.new()
	for n in 页名:
		tb.add_tab(n)
		tb.tab_changed.connect(_on_切页)
	根.add_child(tb)

	# 滚动内容区（三页仅一页可见；硬编码最小高度防嵌套ScrollContainer高度坍塌）
	var 滚动 := ScrollContainer.new()
	滚动.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚动.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚动.custom_minimum_size = Vector2(0, 450)
	根.add_child(滚动)
	列表 = VBoxContainer.new(); 列表.add_theme_constant_override("separation", 6); 列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL; 列表.size_flags_vertical = Control.SIZE_EXPAND_FILL
	抉择区 = VBoxContainer.new(); 抉择区.add_theme_constant_override("separation", 6); 抉择区.size_flags_horizontal = Control.SIZE_EXPAND_FILL; 抉择区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	御兽区 = VBoxContainer.new(); 御兽区.add_theme_constant_override("separation", 4); 御兽区.size_flags_horizontal = Control.SIZE_EXPAND_FILL; 御兽区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	纪事区 = VBoxContainer.new(); 纪事区.add_theme_constant_override("separation", 4); 纪事区.size_flags_horizontal = Control.SIZE_EXPAND_FILL; 纪事区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚动.add_child(列表); 滚动.add_child(抉择区); 滚动.add_child(御兽区); 滚动.add_child(纪事区)
	抉择区.visible = false; 御兽区.visible = false; 纪事区.visible = false
	页控 = {"弟子": 列表, "待抉择": 抉择区, "御兽": 御兽区, "纪事": 纪事区}

	# P0：弟子总览页头（宗门总战力 + 排序按钮），置于滚动区上方、仅弟子页可见
	弟子页头 = VBoxContainer.new()
	弟子页头.add_theme_constant_override("separation", 4)
	var 战力行 := HBoxContainer.new()
	总战力标签 = Label.new()
	总战力标签.text = "宗门总战力：0"
	总战力标签.add_theme_font_size_override("font_size", 16)
	总战力标签.add_theme_color_override("font_color", 暗金)
	战力行.add_child(总战力标签)
	弟子页头.add_child(战力行)
	var 排序行 := HBoxContainer.new()
	排序行.add_theme_constant_override("separation", 6)
	for 名 in ["默认", "战力", "境界", "资质"]:
		var 钮 := Button.new(); 钮.text = 名
		钮.add_theme_font_size_override("font_size", 12)
		钮.pressed.connect(_on_排序.bind(名))
		排序按钮组[名] = 钮
		排序行.add_child(钮)
	弟子页头.add_child(排序行)
	根.add_child(弟子页头)
	根.move_child(弟子页头, 根.get_children().find(滚动))
	弟子页头.visible = true
	_刷新排序按钮()

	# 详情面板（底部常驻）
	详情 = Label.new()
	详情.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var 详情面板: PanelContainer = 新面板("🔍 详情")
	详情面板.custom_minimum_size = Vector2(0, 110)
	详情面板.get_child(0).add_child(详情)
	根.add_child(详情面板)

	Game.弟子变动.connect(刷新)
	Game.战报更新.connect(_on_战报)
	Game.奇遇发生.connect(_on_奇遇发生)   # Step 2：奇遇三场景触发后展示调度

	# 自动推演：开门即按流逝现实时间推进（足球经理度假式汇总）
	var 报: String = Game.推演至现在()
	# 推演至现在() 内部 emit 战报更新 → _on_战报 已构建三层UI
	# 此处无需手动设置战报.text（信号已处理）
	刷新()

	# 新手引导系统（A 包：单线性四步，纯灰模，逻辑独立封装不侵入业务）
	_引导_初始化()

func _on_切页(i: int):
	var 名: String = 页名[i]
	for k in 页控:
		页控[k].visible = (k == 名)
	弟子页头.visible = (名 == "弟子")   # P0：总战力+排序页头仅弟子页显示

func _on_推演():
	战报.text = Game.推演至现在()
	详情.text = "已推演至现在。"

func _on_测灵根():
	_引导_推进("招收")
	var r: Dictionary = Game.举办测灵根()
	if r.has("冷却剩余"):
		详情.text = "接引大典尚在筹备中，接引筹备周期尚余 %d 天。" % r["冷却剩余"]
		return
	_过场弹窗(str(r["过场"]), int(r["人数"]))

func _on_建筑总览():
	_引导_推进("资源")
	_建筑总览弹窗()

func _on_快进():
	Game.推进孵化(30)
	详情.text = "（测试）御兽堂快进30日，查看孵化进度。"

func _on_存档():
	Game.save_game()
	详情.text = "已存档（user://save.json）"

func _on_读档():
	Game.load_game()
	详情.text = "已读档"
	_引导_刷新()   # 读档后续接引导气泡（或清场，视读取的引导阶段）

# 调试战斗入口（灰模）：用真实弟子最终属性快照触发 1v1 与 3v3 车轮战，
# 结构化战斗日志打印至控制台（ADR-003 D7）。属性全部取自 get_final_combat_attr()，无硬编码。
func _on_调试战斗():
	var 名册: Array = Game.弟子列表
	if 名册.size() < 1:
		详情.text = "（无弟子，无法调试战斗）"
		return
	# 1v1：攻方=首名弟子，守方=次名弟子（不足则新生成一名作试炼傀儡）
	var 攻: Dictionary = 名册[0].get_final_combat_attr()
	var 守源: Disciple = 名册[1] if 名册.size() > 1 else Disciple.new()
	var 守: Dictionary = 守源.get_final_combat_attr()
	守["名称"] = "试炼傀儡"
	var r1: Dictionary = BattleManager.发起1v1(攻, 守, "full", true)
	# 3v3 车轮：各取 3 名（不足按名册循环取，敌方不足则新生成），命名区分
	var 攻组 := []
	var 守组 := []
	for i in 3:
		var a: Dictionary = 名册[i % 名册.size()].get_final_combat_attr()
		a["名称"] = "攻%d" % (i + 1)
		攻组.append(a)
		var d源: Disciple = 名册[(i + 1) % 名册.size()] if 名册.size() > 1 else Disciple.new()
		var d: Dictionary = d源.get_final_combat_attr()
		d["名称"] = "守%d" % (i + 1)
		守组.append(d)
		var r3: Dictionary = BattleManager.发起3v3(攻组, 守组, "full", true)
		详情.text = ("调试战斗完成：1v1 %s（回合%d）｜ 3v3车轮 %s（回合%d）。详情见控制台战斗日志。" %
		["攻方胜" if r1["is_win"] else "守方胜", r1["round_count"],
			"攻方胜" if r3["is_win"] else "守方胜", r3["round_count"]])

# 强制触发征伐奇遇（调试专用）：从 config 读取一条 event_type=征伐 的测试事件，
# 对当前选中弟子调用 Game.结算征伐奇遇 走统一收尾（奖励/履历），并把胜负/回合/奖励摘要写入 详情。
# 仅 debug 构建可达（按钮由 OS.is_debug_build 包裹）。无选中弟子则提示。
func _on_强制征伐():
	if 当前选中 == null:
		详情.text = "（请先在左侧选择一名弟子，再强制触发征伐奇遇）"
		return
	var 征伐事件: Dictionary = Quest.取征伐测试事件("T_ZF_01")
	if 征伐事件.is_empty():
		详情.text = "（未找到 event_type=征伐 的测试事件：event_quest.csv 尚未补 T_ZF_01 行）"
		return
	# 先取战报用于展示（quick 模式确定性，与 Game 内部结算一致），再走统一收尾发奖励。
	var 战报: Dictionary = Quest.结算征伐(当前选中, 征伐事件)
	Game.结算征伐奇遇(当前选中, 征伐事件)
	# 补写宗门纪事（强制征伐绕过了 _尝试触发奇遇 的纪事写入路径）
	Game.宗门纪事.append({
		"日": Game.累计游戏日, "弟子": 当前选中.姓名,
		"稀有度": 征伐事件.get("稀有度", "普通"),
		"名称": 征伐事件.get("event_name", "强制征伐"),
		"文案": 征伐事件.get("文案", "") + " [调试]",
	})
	var 结果: String = "攻方胜" if 战报["is_win"] else "守方胜"
	# P0-4 轻量结算联动：灵兽贡献模块（双槽战力 + 主/副宠名）；灵兽实际参战待 S1 属性映射+战斗日志行动条目
	var 灵兽贡献: int = 当前选中.灵兽契约战力()
	var 灵兽文: String = "（无契约灵兽）"
	if 灵兽贡献 > 0:
		var 名段: String = ""
		if 当前选中.主宠灵兽 != null:
			名段 += "主宠[%s]" % 当前选中.主宠灵兽.种类名
		if 当前选中.副宠灵兽 != null:
			名段 += ("＋" if 名段 != "" else "") + "副宠[%s]" % 当前选中.副宠灵兽.种类名
		灵兽文 = "%s，贡献+%d 战力" % [名段, 灵兽贡献]
	详情.text = ("强制征伐奇遇【%s】\n结果：%s｜回合：%d｜胜方剩余气血：%d\n灵兽：%s\n（奖励/履历已记入该弟子，详见战报与履历）" %
	[征伐事件.get("event_name", "无名试炼"), 结果, 战报["round_count"], int(战报["remaining_hp"]), 灵兽文])

# 强制触发聚气丹奇遇（调试专用）：验证富文本点击联动 MVP。
# 仅 debug 构建可达（按钮由 OS.is_debug_build 包裹）。对选中/首名弟子发放 dan_low 奖励并写宗门纪事（带 [url] 链接），便于点击验证。
func _on_强制聚气丹():
	var d: Disciple
	if 当前选中 != null:
		d = 当前选中
	elif not Game.弟子列表.is_empty():
		d = Game.弟子列表[0]
	else:
		_toast("（无弟子可承载聚气丹奇遇）")
		return
	var 摘要: String = Game._解析并发放奇遇奖励(d, "dan_low:2")
	Game.宗门纪事.append({"日": Game.累计游戏日, "弟子": d.姓名, "稀有度": "普通", "名称": "调试·聚气丹", "文案": "获得奖励：%s" % 摘要.strip_edges()})
	if 页控.get("纪事", null) != null and 页控["纪事"].visible:
		刷新纪事()
	_toast("（已强制触发聚气丹奇遇，见「纪事」页签点击验证）")

# 重置新手引导（调试专用）：将引导阶段归零并存档，重放序章+四步引导。
# 仅 debug 构建可达（按钮由 OS.is_debug_build 包裹）。用于反复走查引导表现。
func _on_重置引导():
	Game.引导阶段 = 0
	Game.save_game()
	引导_跳过按钮.visible = true
	_引导_开场()

# 开始新游戏（调试专用）：删存档 + 重置所有状态 + 重新初始化
func _on_新游戏():
	Game.new_game()
	引导_跳过按钮.visible = true
	_引导已收尾 = false
	_引导_清除()
	刷新()

# 推演一年（调试专用）：快进365天，方便测试长期推演/奇遇/突破
func _on_推荐一年():
	Game.推演一月(365)
	Game.save_game()
	刷新()
	详情.text = "已推演1年（365天）。当前：%s" % Game.时间文本()
	_附气运状态()
	_附天品突破()

# 推演7天（调试专用）：小步推演，便于观察天品招募触发的全宗气运buff（7日窗口）
func _on_推演七日():
	Game.推演一月(7)
	Game.save_game()
	刷新()
	详情.text = "已推演7天。当前：%s" % Game.时间文本()
	_附气运状态()
	_附天品突破()

# 强制天品测灵（调试专用）：清冷却 + 保证批次含1名天品弟子，便于验证破格流程/专属文案/气运buff
func _on_强制天品():
	Game.上次测灵日 = -99999   # 调试：清冷却
	var r: Dictionary = Game.举办测灵根(true)
	_过场弹窗(str(r["过场"]), int(r["人数"]))

# 在详情区追加全宗气运 buff 状态（天品弟子护佑中提示）
func _附气运状态():
	if Game.气运到期日 >= Game.累计游戏日:
		详情.text += "\n［全宗气运］天品弟子护佑中：修炼+3%%、产出+2%%（剩余 %d 天）" % maxi(0, Game.气运到期日 - Game.累计游戏日)

# 结算后播报本次推演内的天品弟子突破（仪式感；不在推演循环中弹 modal，避免卡死模拟）
func _附天品突破():
	if Game.天品突破播报 != "":
		详情.text += "\n［天品突破·仪式］\n" + Game.天品突破播报.strip_edges()

func _on_战报(文本: String):
	# 优先用结构化数据构建三层UI；降级时回退到纯文本
	if not Game.离线汇总数据.is_empty():
		_构建离山内容(Game.离线汇总数据)
	else:
		# 降级：旧存档或无数据时显示纯文本
		for c in 离山内容区.get_children():
			c.queue_free()
		# 战报 Label 可能已被之前的 queue_free 释放，重建避免 previously freed
		if not is_instance_valid(战报):
			战报 = Label.new()
			战报.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		战报.text = 文本
		战报.visible = true
		离山内容区.add_child(战报)

# ============ 离山汇总三层UI构建 ============
# 根据 game_state.离线汇总数据（结构化聚合）构建三层面板
# 层级：总览(收菜爽感) → 重大事件(默认展开) → 琐事(默认折叠)
# P1：评级颜色（按档位）
func _评级色(评级: String) -> Color:
	match 评级:
		"SSS", "SS":
			return Color(0.85, 0.15, 0.15)
		"S", "A+":
			return Color(0.85, 0.55, 0.1)
		"A", "B":
			return Color(0.2, 0.6, 0.3)
		"C":
			return Color(0.45, 0.45, 0.55)
		_:
			return Color(0.5, 0.3, 0.3)

func _构建离山内容(数据: Dictionary):
	# 清空旧内容
	for c in 离山内容区.get_children():
		c.queue_free()
	# 战报 Label 若之前被 queue_free，直接访问会报 previously freed
	if is_instance_valid(战报):
		战报.visible = false

	var 摘要: Dictionary = 数据.get("summary", {})
	var 高优事件: Array = 数据.get("high_events", [])
	var 普通事件: Array = 数据.get("normal_events", [])
	var 琐事事件: Array = 数据.get("trivial_events", [])
	var 流失日: int = 摘要.get("offline_days", 0)
	var 灵石收益: int = 摘要.get("lingshi_earned", 0)

	# ── 第一层：总览栏 ──
	var 总览 := VBoxContainer.new()
	总览.add_theme_constant_override("separation", 4)
	总览.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 标题行：离开期间 + 时间
	var 标题行 := Label.new()
	标题行.text = "✦ 你离开了 %d 天" % 流失日 if 流失日 > 0 else "✦ 刚刚回归"
	标题行.add_theme_font_size_override("font_size", 17)
	标题行.add_theme_color_override("font_color", 暗金)
	总览.add_child(标题行)

	# 资源收益行
	if 灵石收益 > 0:
		var 资源行 := Label.new()
		资源行.text = "💰  灵石 +%d" % 灵石收益
		资源行.add_theme_font_size_override("font_size", 14)
		资源行.add_theme_color_override("font_color", 暗金)
		总览.add_child(资源行)

	# 统计行（有事件才显示）
	var 统计部分 := []
	if 摘要.get("breakthrough_count", 0) > 0:
		统计部分.append("🔺 %d人突破" % 摘要["breakthrough_count"])
	if 摘要.get("rare_loot_count", 0) > 0:
		统计部分.append("🎁 %d件稀有" % 摘要["rare_loot_count"])
	if 摘要.get("appoint_count", 0) > 0:
		统计部分.append("📜 %d人任职" % 摘要["appoint_count"])
	if 摘要.get("quest_success_count", 0) > 0:
		统计部分.append("✅ %d次奇遇" % 摘要["quest_success_count"])
	if not 统计部分.is_empty():
		var 统计行 := Label.new()
		统计行.text = "    ".join(统计部分)
		统计行.add_theme_font_size_override("font_size", 12)
		统计行.add_theme_color_override("font_color", 次墨)
		总览.add_child(统计行)

	# 筛选行：点击统计类型过滤事件（无对应类型不显示该按钮）
	var 筛选行 := HBoxContainer.new()
	筛选行.add_theme_constant_override("separation", 4)
	var 全部钮 := Button.new(); 全部钮.text = "全部"
	全部钮.add_theme_font_size_override("font_size", 11)
	全部钮.add_theme_color_override("font_color", 暗金 if _战报筛选 == "" else 次墨)
	全部钮.pressed.connect(func(): _设战报筛选(""))
	筛选行.add_child(全部钮)
	if 摘要.get("breakthrough_count", 0) > 0:
		var 突破钮 := Button.new(); 突破钮.text = "突破 %d" % 摘要["breakthrough_count"]
		突破钮.add_theme_font_size_override("font_size", 11)
		突破钮.add_theme_color_override("font_color", 暗金 if _战报筛选 == "breakthrough" else 次墨)
		突破钮.pressed.connect(func(): _设战报筛选("breakthrough"))
		筛选行.add_child(突破钮)
	if 摘要.get("appoint_count", 0) > 0:
		var 任职钮 := Button.new(); 任职钮.text = "任职 %d" % 摘要["appoint_count"]
		任职钮.add_theme_font_size_override("font_size", 11)
		任职钮.add_theme_color_override("font_color", 暗金 if _战报筛选 == "appoint" else 次墨)
		任职钮.pressed.connect(func(): _设战报筛选("appoint"))
		筛选行.add_child(任职钮)
	if 摘要.get("quest_success_count", 0) > 0:
		var 奇遇钮 := Button.new(); 奇遇钮.text = "奇遇 %d" % 摘要["quest_success_count"]
		奇遇钮.add_theme_font_size_override("font_size", 11)
		奇遇钮.add_theme_color_override("font_color", 暗金 if _战报筛选 == "quest" else 次墨)
		奇遇钮.pressed.connect(func(): _设战报筛选("quest"))
		筛选行.add_child(奇遇钮)
	总览.add_child(筛选行)

	# 一键领取按钮（展示型：确认已阅 + 收起）
	var 领取按钮 := Button.new()
	领取按钮.text = "  ✓ 一键领取  "
	领取按钮.add_theme_font_size_override("font_size", 13)
	# 按钮 Tween 动画（悬停/按下）— 见 _接按钮Tween 函数
	_接按钮动画(领取按钮)
	领取按钮.pressed.connect(_on_一键领取.bind(领取按钮))
	总览.add_child(领取按钮)

	# P1：周期评级卡片（年结后优先展示于离山汇总顶部）
	if not Game.最新周期评级卡.is_empty():
		var 卡: Dictionary = Game.最新周期评级卡
		var 评级卡 := VBoxContainer.new()
		评级卡.add_theme_constant_override("separation", 3)
		var 标题 := Label.new()
		标题.text = "🏆 第 %d 周期评定：%s（%d 分）" % [卡["周期"], 卡["评级"], 卡["总分"]]
		标题.add_theme_font_size_override("font_size", 16)
		标题.add_theme_color_override("font_color", _评级色(卡["评级"]))
		评级卡.add_child(标题)
		var 维 := Label.new()
		维.text = "经营 %d ｜ 收益 %d ｜ 弟子 %d" % [卡["分维度"]["经营"], 卡["分维度"]["收益"], 卡["分维度"]["弟子"]]
		维.add_theme_font_size_override("font_size", 12)
		维.add_theme_color_override("font_color", 次墨)
		评级卡.add_child(维)
		离山内容区.add_child(评级卡)
		var 分隔顶 := HSeparator.new(); 分隔顶.modulate.a = 0.35; 离山内容区.add_child(分隔顶)

	离山内容区.add_child(总览)

	# 分隔线
	var 分隔1 := HSeparator.new()
	分隔1.modulate.a = 0.35
	离山内容区.add_child(分隔1)

	# 也把普通事件的正向条目展示（非"无功而返"）
	var 显示普通: Array = []
	for 条目 in 普通事件:
		if "无功而返" not in 条目.get("text", ""):
			显示普通.append(条目)
	# 琐事事件汇总（普通事件中的"无功而返" + 琐事事件桶）
	var 全部琐事: Array = []
	for 条目 in 普通事件:
		if "无功而返" in 条目.get("text", ""):
			全部琐事.append(条目)
	for 条目 in 琐事事件:
		全部琐事.append(条目)

	# ── 事件区（受 _战报筛选 过滤；重大事件可折叠，默认展开）──
	# 预过滤（按事件类型）
	var 高优_可见: Array = []
	var 普通_可见: Array = []
	var 琐事_可见: Array = []
	for 条目 in 高优事件:
		if _战报筛选 == "" or 条目.get("event_type", "") == _战报筛选:
			高优_可见.append(条目)
	for 条目 in 显示普通:
		if _战报筛选 == "" or 条目.get("event_type", "") == _战报筛选:
			普通_可见.append(条目)
	for 条目 in 全部琐事:
		if _战报筛选 == "" or 条目.get("event_type", "") == _战报筛选:
			琐事_可见.append(条目)

	var 重大总数: int = 高优_可见.size() + 普通_可见.size()
	var 琐事总数: int = 琐事_可见.size()

	# 第二层：重大事件（可折叠，默认展开）
	if 重大总数 > 0:
		var 分隔_重大 := HSeparator.new()
		分隔_重大.modulate.a = 0.35
		离山内容区.add_child(分隔_重大)
		var 重大容器 := VBoxContainer.new()
		var 重大按钮 := Button.new()
		重大按钮.add_theme_font_size_override("font_size", 13)
		重大按钮.add_theme_color_override("font_color", 颜色_极品)
		重大按钮.text = ("▼ 收起重大事件" if _重大已展开 else "▶ 展开重大事件（%d条）") % 重大总数
		重大容器.add_child(重大按钮)
		var 重大列表 := VBoxContainer.new()
		重大列表.visible = _重大已展开
		for 条目 in 高优_可见:
			重大列表.add_child(_新事件行(条目, true))
		for 条目 in 普通_可见:
			重大列表.add_child(_新事件行(条目, false))
		重大容器.add_child(重大列表)
		重大按钮.pressed.connect(func():
			if not is_instance_valid(重大列表) or not is_instance_valid(重大按钮):
				return
			_重大已展开 = not _重大已展开
			重大列表.visible = _重大已展开
			重大按钮.text = ("▼ 收起重大事件" if _重大已展开 else "▶ 展开重大事件（%d条）") % 重大总数
		)
		离山内容区.add_child(重大容器)

	# 第三层：琐事（可折叠，默认折叠，沿用 _琐事已展开）
	if 琐事总数 > 0:
		var 分隔2 := HSeparator.new()
		分隔2.modulate.a = 0.25
		离山内容区.add_child(分隔2)
		var 折叠_container := VBoxContainer.new()
		var 折叠按钮 := Button.new()
		折叠按钮.add_theme_font_size_override("font_size", 11)
		折叠按钮.add_theme_color_override("font_color", 颜色_琐事)
		折叠按钮.text = ("▼ 收起琐事" if _琐事已展开 else "▶ 查看全部琐事（%d条）") % 琐事总数
		折叠_container.add_child(折叠按钮)
		var 理事列表 := VBoxContainer.new()
		理事列表.visible = _琐事已展开
		for 条目 in 琐事_可见:
			var 行 := Label.new()
			行.text = "  " + 符号失败 + " " + 条目.get("text", "")
			行.add_theme_font_size_override("font_size", 11)
			行.add_theme_color_override("font_color", 颜色_琐事)
			理事列表.add_child(行)
		折叠_container.add_child(理事列表)
		折叠按钮.pressed.connect(func():
			if not is_instance_valid(理事列表) or not is_instance_valid(折叠按钮):
				return
			_琐事已展开 = not _琐事已展开
			理事列表.visible = _琐事已展开
			折叠按钮.text = ("▼ 收起琐事" if _琐事已展开 else "▶ 查看全部琐事（%d条）") % 琐事总数
		)
		离山内容区.add_child(折叠_container)

	# 筛选空兜底
	if _战报筛选 != "" and 重大总数 == 0 and 琐事总数 == 0:
		var 空记 := Label.new()
		空记.text = "暂无相关记录"
		空记.add_theme_font_size_override("font_size", 12)
		空记.add_theme_color_override("font_color", 次墨)
		离山内容区.add_child(空记)


# 格式化单条事件为带符号+颜色的文本
func _格式事件行(条目: Dictionary, 是高优: bool) -> String:
	var 类型: String = 条目.get("event_type", "info")
	var 文本: String = 条目.get("text", "")
	var 符号: String = 符号表.get(类型, "•")
	# trivial quest 用失败符号
	if 类型 == "quest" and 条目.get("priority") == "trivial":
		符号 = 符号失败
	return "%s  %s" % [符号, 文本]

# 事件行控件（复用于折叠/筛选渲染）
func _新事件行(条目: Dictionary, 是高优: bool) -> Label:
	var 行: Label = Label.new()
	行.text = _格式事件行(条目, 是高优)
	行.add_theme_font_size_override("font_size", 12)
	行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return 行

# 离山汇总事件筛选（点击统计类型；重建面板保留折叠状态）
func _设战报筛选(类型: String) -> void:
	if _战报筛选 == 类型:
		return
	_战报筛选 = 类型
	# 等待完整一帧后再重建，确保按钮 pressed 信号、Tween、焦点切换全部结束，
	# 避免在信号活跃期间 queue_free 自己或其 lambda 捕获的节点。
	await get_tree().process_frame
	_构建离山内容(Game.离线汇总数据)


# 接入按钮 Tween 动画（悬停放大/按下缩小/松开回弹）
func _接按钮动画(btn: Button):
	btn.pivot_offset = btn.size / 2.0 if btn.size.x > 0 else Vector2(40, 16)
	var hover_scale: Vector2 = Vector2(1.05, 1.05)
	var press_scale: Vector2 = Vector2(0.96, 0.96)
	var normal_scale: Vector2 = Vector2(1.0, 1.0)
	var anim_dur: float = 0.10

	btn.mouse_entered.connect(func():
		if not is_instance_valid(btn) or btn.disabled:
			return
		var tw: Tween = btn.create_tween()
		tw.tween_property(btn, "scale", hover_scale, anim_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		if not is_instance_valid(btn):
			return
		var tw: Tween = btn.create_tween()
		tw.tween_property(btn, "scale", normal_scale, anim_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	btn.button_down.connect(func():
		if not is_instance_valid(btn) or btn.disabled:
			return
		var tw: Tween = btn.create_tween()
		tw.tween_property(btn, "scale", press_scale, anim_dur * 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(btn, "modulate", Color(0.9, 0.9, 0.9), anim_dur * 0.8)
	)
	btn.button_up.connect(func():
		if not is_instance_valid(btn):
			return
		var tw: Tween = btn.create_tween()
		tw.tween_property(btn, "scale", hover_scale, anim_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(btn, "modulate", Color.WHITE, anim_dur)
	)


# 一键领取回调（展示型：确认已阅 + 按钮变灰）
func _on_一键领取(btn: Button):
	btn.disabled = true
	btn.text = "  ✓ 已领取  "
	btn.modulate = Color(0.55, 0.52, 0.48)   # 置灰
	btn.scale = Vector2(1.0, 1.0)                # 重置缩放
	详情.text = "本次离线收益已知悉到账。宗门运转正常，弟子修炼不辍。"

func _on_交宗(条目: Dictionary):
	# 等待完整一帧后再处理，避免 pressed 信号活跃期间重建/queue_free 按钮造成 previously freed 或卡死
	await get_tree().process_frame
	Game.交宗(条目)
	详情.text = "已交宗。"

func _on_自留(条目: Dictionary):
	await get_tree().process_frame
	Game.自留(条目)
	详情.text = "弟子已自留。"

func _on_绑定(灵兽: Beast):
	await get_tree().process_frame
	_弹出灵兽绑定选择(灵兽)

# 弹出空闲弟子列表供玩家选择灵兽绑定对象（P0-3 双槽：可设主宠/副宠，按适配度排序+适配标记）
func _弹出灵兽绑定选择(灵兽: Beast):
	var 弹: Dictionary = _new_detail_popup("选择绑定弟子")
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, mini(340, int(get_viewport_rect().size.y * 0.7)))
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	弹["内容"].add_child(滚)
	var vb := VBoxContainer.new()
	滚.add_child(vb)

	var 说明 := Label.new()
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	说明.text = "为【%s】（%s·%s）选择绑定对象与槽位。\n低资质（凡俗/平庸）弟子仅能携带凡/灵阶灵兽；弟子境界不得低于灵兽品阶。" % [灵兽.种类名, Beast.类型中文.get(灵兽.beast_type, ""), 灵兽.品阶]
	vb.add_child(说明)

	var 候选: Array[Disciple] = []
	for d in Game.弟子列表:
		if d.主宠灵兽 != null and d.副宠灵兽 != null:
			continue   # 双槽已满，跳过
		# 门槛①：境界门槛（对齐 GDD-灵兽 7.2「弟子境界不得低于灵兽对应境界门槛」）
		#   灵兽品阶序必须 ≤ 弟子境界品阶序，否则无法携带出战（防低境界弟子绑高阶灵兽致战力崩坏）
		var 弟子品阶序: int = Item.品阶序key.find(Disciple.境界表[d.境界].get("品阶", "fan_jie"))
		var 兽品阶序: int = Item.品阶序key.find(灵兽.品阶)
		var 受境界限: bool = 兽品阶序 >= 0 and 弟子品阶序 >= 0 and 弟子品阶序 < 兽品阶序
		# 门槛②：低资质（凡俗/平庸）仅能携带凡/灵阶灵兽
		var 受限: bool = 受境界限 or ((d.资质 == "fan_su" or d.资质 == "pingyong") and not (灵兽.品阶 in ["fan_jie", "ling_jie"]))
		if not 受限:
			候选.append(d)
	# 按适配加成降序排列（高契合优先）
	候选.sort_custom(func(a, b): return a.calc_beast_bonus(灵兽, a) > b.calc_beast_bonus(灵兽, b))

	if 候选.is_empty():
		var 空 := Label.new()
		空.text = "暂无可绑定的空闲弟子。"
		vb.add_child(空)
	else:
		for d in 候选:
			var 加: float = d.calc_beast_bonus(灵兽, d)
			var 标记: String = ("✓ 适配 +%d%%" % int(加 * 100)) if 加 > 0 else "✗ 不契合"
			var 行 := HBoxContainer.new()
			行.add_theme_constant_override("separation", 6)
			var 信息 := Label.new()
			信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			信息.text = "%s · %s · 战力 %d · %s" % [d.姓名, d.境界, d.实时战力(), 标记]
			行.add_child(信息)
			var 主 := Button.new(); 主.text = "设主宠"
			主.disabled = (d.主宠灵兽 != null)
			主.pressed.connect(func():
				if not is_instance_valid(弹["遮"]):
					return
				详情.text = Game.绑定灵兽给指定弟子(灵兽, d, "主宠")
				刷新御兽()
				弹["遮"].queue_free()
			)
			行.add_child(主)
			var 副 := Button.new(); 副.text = "设副宠"
			副.disabled = (d.副宠灵兽 != null)
			副.pressed.connect(func():
				if not is_instance_valid(弹["遮"]):
					return
				详情.text = Game.绑定灵兽给指定弟子(灵兽, d, "副宠")
				刷新御兽()
				弹["遮"].queue_free()
			)
			行.add_child(副)
			vb.add_child(行)

	弹["内容"].add_child(弹["关"])

func _on_选弟子(d: Disciple):
	当前选中 = d
	详情.text = d.简介()
	# 引导步骤4：点开弟子详情后推进到完成（修复：之前误删导致卡死）
	if Game.引导阶段 == 4:
		_引导_推进("查看弟子")

func _on_命格(d: Disciple):
	_弹出弟子属性弹窗("命格", "【命格】%s" % d.命格详情(), d)

func _on_灵根(d: Disciple):
	_弹出弟子属性弹窗("灵根", "【灵根·%s】\n%s" % [d.灵根, d.灵根详情()], d)

func _on_性格(d: Disciple):
	_弹出弟子属性弹窗("性格", "【性格·%s】\n%s" % [d.性格, d.性格详情()], d)

func _on_职业(d: Disciple):
	var 职名: String = d.职业 if d.职业 != "" else "未入门"
	_弹出弟子属性弹窗("职业", "【职业·%s】\n%s" % [职名, d.职业详情()], d)

# 统一详情弹窗外壳：创建遮罩+面板+标题，返回 {遮, 内容, 关}
# 内置：点击蒙版关闭 / ESC关闭 / 0.15s淡入缩放动画 / 长内容滚动兜底
# 调用方往 内容 加滚动区/信息/关按钮。降级不崩：标题为空显示占位。
func _new_detail_popup(标题文本: String, 标题色: Color = 暗金) -> Dictionary:
	# 单实例守卫：快速连点时释放上一个遮罩，只保留最后一次（防层叠、降开销）
	if _当前详情遮 != null and is_instance_valid(_当前详情遮):
		_当前详情遮.queue_free()
	var 遮 := ColorRect.new()
	遮.color = 墨底
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.focus_mode = Control.FOCUS_ALL
	add_child(遮)
	# 蒙版点击关闭：透明全屏按钮置于面板之下，点面板外区域即关闭
	var 背板 := Button.new()
	背板.flat = true
	背板.modulate.a = 0.0
	背板.mouse_filter = Control.MOUSE_FILTER_STOP
	背板.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	背板.pressed.connect(func(): 遮.queue_free())
	遮.add_child(背板)
	var 大 := PanelContainer.new()
	大.anchor_left = 0.5; 大.anchor_top = 0.5; 大.anchor_right = 0.5; 大.anchor_bottom = 0.5
	大.offset_left = -190; 大.offset_top = -210; 大.offset_right = 190; 大.offset_bottom = 210
	大.pivot_offset = Vector2(190, 210)   # 缩放绕中心，避免移位
	遮.add_child(大)
	var 内容 := VBoxContainer.new()
	大.add_child(内容)
	var 标题 := Label.new()
	标题.text = "📜 " + (标题文本 if 标题文本 != "" else "详情")
	标题.add_theme_font_size_override("font_size", 17)
	标题.add_theme_color_override("font_color", 标题色)
	内容.add_child(标题)
	var 关 := Button.new(); 关.text = "知悉"
	关.pressed.connect(func(): 遮.queue_free())
	# ESC 全局关闭（遮罩获焦后接收键盘事件）
	遮.gui_input.connect(func(e: InputEvent):
		if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
			遮.queue_free())
	遮.grab_focus()
	# 入场动画：淡入 + 轻微缩放（绕中心）
	大.modulate.a = 0.0
	大.scale = Vector2(0.95, 0.95)
	var 动: Tween = create_tween()
	动.tween_property(大, "modulate:a", 1.0, 0.15)
	动.parallel().tween_property(大, "scale", Vector2.ONE, 0.15)
	_当前详情遮 = 遮
	return {"遮": 遮, "内容": 内容, "关": 关}

# 通用弟子属性弹窗（命格/灵根/性格/职业共用）
func _弹出弟子属性弹窗(类型: String, 内容文本: String, _d: Disciple):
	if _d == null:
		_toast("（暂无详情）")
		return
	var 标题文本: String = "%s · %s" % [类型, _d.姓名]
	var 弹: Dictionary = _new_detail_popup(标题文本)
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, mini(340, int(get_viewport_rect().size.y * 0.7)))
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	弹["内容"].add_child(滚)
	var 信息 := Label.new()
	信息.text = 内容文本
	滚.add_child(信息)
	弹["内容"].add_child(弹["关"])

func 刷新():
	var _升级: Dictionary = Game.距下一级信息()
	var _升级提示 := ""
	if _升级["已满"]:
		_升级提示 = "（已达当前上限）"
	else:
		_升级提示 = "（距 Lv%d 还差声望 %d）" % [_升级["下一级"], _升级["声望缺口"]]
	状态栏.text = ("时间：%s\n宗门 Lv%d · 声望 %d · 繁荣 %d ｜ 灵石 %d · 灵草 %d · 矿石 %d · 灵气 %d · 贡献 %d ｜ 弟子 %d%s" %
	[Game.时间文本(), Game.门派等级, Game.声望, Game.繁荣, Game.灵石, Game.灵草, Game.矿石, Game.灵气, Game.贡献点, Game.弟子列表.size(), _升级提示])
	for c in 列表.get_children():
		c.queue_free()
	# P0：按当前排序维度排序（不影响 弟子列表 原始招募序）
	var 序: Array = Game.弟子列表.duplicate()
	if 弟子排序维度 != "默认":
		序.sort_custom(_排序比较)
	for d in 序:
		列表.add_child(_弟子卡(d))
	# P0：宗门总战力（纯展示，不参与战斗结算）
	var 总战力 := 0
	for d in Game.弟子列表:
		总战力 += d.实时战力()
	总战力标签.text = "宗门总战力：%d" % 总战力
	if 总战力 != 上次总战力:
		上次总战力 = 总战力
		总战力标签.modulate.a = 0.35
		var 闪: Tween = create_tween()
		闪.tween_property(总战力标签, "modulate:a", 1.0, 0.5)
	# 子页签面板随弟子变动统一刷新（避免抉择/御兽/纪事面板 stale）
	刷新抉择()
	刷新御兽()
	刷新纪事()

# ===== P0：弟子总览 排序 =====
func _on_排序(维度: String):
	if 维度 == 弟子排序维度:
		弟子排序升序 = not 弟子排序升序
	else:
		弟子排序维度 = 维度
		弟子排序升序 = false
	_刷新排序按钮()
	刷新()

func _刷新排序按钮():
	for 名 in 排序按钮组:
		var b: Button = 排序按钮组[名]
		var 选中: bool = (名 == 弟子排序维度)
		b.text = 名 + (" ▼" if (选中 and not 弟子排序升序) else (" ▲" if (选中 and 弟子排序升序) else ""))
		b.modulate = 暗金 if 选中 else Color.WHITE

# sort_custom 比较器：返回 true 表示 a 应排在 b 前
func _排序比较(a: Disciple, b: Disciple) -> bool:
	var 降: bool = not 弟子排序升序
	match 弟子排序维度:
		"战力":
			var va: int = a.实时战力(); var vb: int = b.实时战力()
			return va > vb if 降 else va < vb
		"境界":
			var va: int = Disciple.境界序.find(a.境界); var vb: int = Disciple.境界序.find(b.境界)
			return va > vb if 降 else va < vb
		"资质":
			var va: int = Lore._灵根品阶值(a.灵根品阶); var vb: int = Lore._灵根品阶值(b.灵根品阶)
			return va > vb if 降 else va < vb
		_:
			return false

# S1 战斗生效·优先级3：随行灵兽徽标（头像旁轻量标识），仅列出已孵化出战的主/副宠
func _灵兽随行徽标(d: Disciple) -> String:
	var 段: String = ""
	if d.主宠灵兽 != null and not d.主宠灵兽.孵化中:
		段 += "主·%s" % d.主宠灵兽.种类名
	if d.副宠灵兽 != null and not d.副宠灵兽.孵化中:
		段 += ("  " if 段 != "" else "") + "副·%s" % d.副宠灵兽.种类名
	return 段

func _弟子卡(d: Disciple) -> Control:
	var pc: PanelContainer = 新面板("")
	var vb: Control = pc.get_child(0)
	var 头 := HBoxContainer.new()
	var 选 := Button.new(); 选.text = d.姓名; 选.pressed.connect(_on_选弟子.bind(d))
	头.add_child(选)
	# S1 战斗生效·优先级3：随行灵兽徽标（头像旁轻量标识，不抢弟子主体视觉重心）
	var 徽: String = _灵兽随行徽标(d)
	if 徽 != "":
		var 宠标 := Label.new()
		宠标.text = "随行：" + 徽
		宠标.add_theme_font_size_override("font_size", 13)
		宠标.add_theme_color_override("font_color", 暗金)
		头.add_child(宠标)
	vb.add_child(头)
	var 简 := Label.new()
	简.text = d.简介()
	简.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	简.custom_minimum_size = Vector2(0, 120)
	vb.add_child(简)
	var 详情行 := HBoxContainer.new()
	详情行.add_theme_constant_override("separation", 4)
	var 命格按钮 := Button.new(); 命格按钮.text = "命格"; 命格按钮.pressed.connect(_on_命格.bind(d))
	var 灵根按钮 := Button.new(); 灵根按钮.text = "灵根"; 灵根按钮.pressed.connect(_on_灵根.bind(d))
	var 性格按钮 := Button.new(); 性格按钮.text = "性格"; 性格按钮.pressed.connect(_on_性格.bind(d))
	var 职业按钮 := Button.new(); 职业按钮.text = "职业"; 职业按钮.pressed.connect(_on_职业.bind(d))
	var 装备按钮 := Button.new(); 装备按钮.text = "法宝"; 装备按钮.pressed.connect(_装备面板.bind(d))
	详情行.add_child(命格按钮); 详情行.add_child(灵根按钮); 详情行.add_child(性格按钮); 详情行.add_child(职业按钮); 详情行.add_child(装备按钮)
	vb.add_child(详情行)
	return pc

func 刷新抉择():
	for c in 抉择区.get_children():
		c.queue_free()
	if Game.待抉择.is_empty():
		var 空 := Label.new(); 空.text = "（暂无待抉择的极品/特殊道具）"; 抉择区.add_child(空)
		return
		抉择区.add_child(小标题("—— 极品/特殊道具抉择 ——", 15))
	for 条目 in Game.待抉择:
		var 弟子: Disciple = 条目["弟子"]
		var 物品: Item = 条目["物品"]
		var pc: PanelContainer = 新面板("")
		var vb: Control = pc.get_child(0)
		var 信息 := Label.new()
		信息.text = "【%s】获【%s】" % [弟子.姓名, 物品.简介()]
		信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(信息)
		var 行 := HBoxContainer.new()
		行.add_theme_constant_override("separation", 6)
		var 详 := Button.new(); 详.text = "物品详情"
		行.add_child(详); 详.pressed.connect(_弹出物品详情.bind(物品))
		var 交 := Button.new(); 交.text = "交宗换贡献"
		交.pressed.connect(_on_交宗.bind(条目))
		var 留 := Button.new(); 留.text = "弟子自留"
		留.pressed.connect(_on_自留.bind(条目))
		行.add_child(交); 行.add_child(留)
		vb.add_child(行)
		抉择区.add_child(pc)

func 刷新御兽():
	for c in 御兽区.get_children():
		c.queue_free()
	# 是否已有任意已契约灵兽（双槽）
	var 有契约: bool = false
	for d in Game.弟子列表:
		if d.主宠灵兽 != null or d.副宠灵兽 != null:
			有契约 = true
			break
	if Game.灵兽蛋列表.is_empty() and Game.灵兽库存.is_empty() and not 有契约:
		var 空 := Label.new(); 空.text = "（御兽堂暂无灵兽）"; 御兽区.add_child(空)
		return
	御兽区.add_child(小标题("—— 御兽堂 ——", 15))
	# 已契约灵兽（双槽）：遍历弟子主/副宠，可卸下
	for d in Game.弟子列表:
		for 槽 in ["主宠", "副宠"]:
			var 兽: Beast = d.主宠灵兽 if 槽 == "主宠" else d.副宠灵兽
			if 兽 == null:
				continue
			var pc: PanelContainer = 新面板("")
			var vb: Control = pc.get_child(0)
			var 信息 := Label.new()
			信息.text = "【%s】%s灵兽：%s" % [d.姓名, 槽, 兽.简介(兽.本体战力())]
			信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(信息)
			var 卸 := Button.new(); 卸.text = "卸下%s" % 槽
			卸.pressed.connect(_on_卸下.bind(d, 槽))
			vb.add_child(卸)
			御兽区.add_child(pc)
	# 灵兽蛋
	for 蛋 in Game.灵兽蛋列表:
		var lab := Label.new()
		lab.text = 蛋.简介()
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		御兽区.add_child(lab)
	# 库存未绑定灵兽
	for 灵兽 in Game.灵兽库存:
		var pc: PanelContainer = 新面板("")
		var vb: Control = pc.get_child(0)
		var 信息 := Label.new()
		信息.text = 灵兽.简介(灵兽.本体战力())
		信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(信息)
		var 绑 := Button.new()
		绑.text = "绑定给空闲弟子"
		绑.pressed.connect(_on_绑定.bind(灵兽))
		vb.add_child(绑)
		御兽区.add_child(pc)
	# T03 自动兑换队列管理区
	御兽区.add_child(小标题("—— 自动兑换（灵石） ——", 15))
	if Game.灵兽兑换队列.is_empty():
		var 空 := Label.new(); 空.text = "（未设置自动兑换，点击下方按钮添加）"; 御兽区.add_child(空)
	for i in Game.灵兽兑换队列.size():
		var 条目: Dictionary = Game.灵兽兑换队列[i]
		var pc2: PanelContainer = 新面板("")
		var vb2: Control = pc2.get_child(0)
		var 模式文本: String = "随机"
		var 偏好: Dictionary = 条目.get("偏好", {})
		if 偏好.get("品阶", "") != "":
			模式文本 = "指定品阶：" + Beast.品阶显示.get(偏好["品阶"], 偏好["品阶"])
		elif 偏好.get("类型", "") != "":
			模式文本 = "指定类型：" + Beast.类型中文.get(偏好["类型"], 偏好["类型"])
		var 信息 := Label.new()
		信息.text = "模式：%s | 消耗 %d 灵石 | %s" % [模式文本, 条目.get("cost", 0), ("启用" if 条目.get("启用", false) else "停用")]
		信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb2.add_child(信息)
		var 行 := HBoxContainer.new()
		行.add_theme_constant_override("separation", 6)
		var 启停 := Button.new(); 启停.text = "停用" if 条目.get("启用", false) else "启用"
		启停.pressed.connect(_on_兑换启停.bind(i))
		var 删 := Button.new(); 删.text = "删除"
		删.pressed.connect(_on_兑换删除.bind(i))
		行.add_child(启停); 行.add_child(删)
		vb2.add_child(行)
		御兽区.add_child(pc2)
	var 添加 := Button.new(); 添加.text = "＋ 新增自动兑换"
	添加.pressed.connect(_弹出兑换新增)
	御兽区.add_child(添加)

# 卸下灵兽（P0-3 双槽：解除主宠/副宠契约，灵兽返回御兽堂）
func _on_卸下(弟子: Disciple, 槽位: String):
	await get_tree().process_frame
	详情.text = Game.解绑灵兽(弟子, 槽位)
	刷新御兽()

# T03 自动兑换：新增弹窗（预设偏好+阶梯消耗，一键入队）
func _弹出兑换新增():
	var 弹: Dictionary = _new_detail_popup("新增自动兑换")
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, mini(360, int(get_viewport_rect().size.y * 0.7)))
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	弹["内容"].add_child(滚)
	var vb := VBoxContainer.new()
	滚.add_child(vb)
	var 说明 := Label.new()
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	说明.text = "选择兑换偏好与单次灵石消耗，加入自动兑换队列。周期结算时自动扣灵石生成灵兽蛋。"
	vb.add_child(说明)
	var 预设: Array = [
		{"标签": "随机(600)", "偏好": {}, "cost": 600},
		{"标签": "凡阶(200)", "偏好": {"品阶": "fan_jie"}, "cost": 200},
		{"标签": "灵阶(600)", "偏好": {"品阶": "ling_jie"}, "cost": 600},
		{"标签": "宝阶(1500)", "偏好": {"品阶": "bao_jie"}, "cost": 1500},
		{"标签": "王阶(4000)", "偏好": {"品阶": "wang_jie"}, "cost": 4000},
		{"标签": "圣阶(10000)", "偏好": {"品阶": "sheng_jie"}, "cost": 10000},
		{"标签": "仙阶(25000)", "偏好": {"品阶": "xian_jie"}, "cost": 25000},
		{"标签": "道阶(60000)", "偏好": {"品阶": "dao_jie"}, "cost": 60000},
		{"标签": "攻伐型(600)", "偏好": {"类型": "attack"}, "cost": 600},
		{"标签": "防御型(600)", "偏好": {"类型": "defense"}, "cost": 600},
		{"标签": "辅助型(600)", "偏好": {"类型": "support"}, "cost": 600},
	]
	for p in 预设:
		var b := Button.new(); b.text = p["标签"]
		b.pressed.connect(func():
			if not is_instance_valid(弹["遮"]):
				return
			Game.灵兽兑换队列.append({"偏好": p["偏好"], "cost": p["cost"], "启用": true})
			详情.text = "已添加自动兑换：" + p["标签"]
			弹["遮"].queue_free()
			刷新御兽()
		)
		vb.add_child(b)
	弹["内容"].add_child(弹["关"])

# T03 自动兑换：启停/删除条目
func _on_兑换启停(索引: int):
	if 索引 >= 0 and 索引 < Game.灵兽兑换队列.size():
		var 条目: Dictionary = Game.灵兽兑换队列[索引]
		条目["启用"] = not 条目.get("启用", false)
		刷新御兽()

func _on_兑换删除(索引: int):
	if 索引 >= 0 and 索引 < Game.灵兽兑换队列.size():
		Game.灵兽兑换队列.remove_at(索引)
		刷新御兽()

# ============ Step 2 奇遇基础调度（L2 弹窗 + 宗门纪事）============
# 奇遇发生 signal → 入队，逐个弹窗，避免推演期多奇遇堆叠。
func _on_奇遇发生(q: Dictionary, 弟子: Disciple):
	奇遇队列.append({"q": q, "弟子": 弟子})
	_显示下一奇遇()

func _显示下一奇遇():
	if 奇遇弹窗中 or 奇遇队列.is_empty():
		return
		奇遇弹窗中 = true
		var 项: Dictionary = 奇遇队列.pop_front()
		_奇遇弹窗(项["q"], 项["弟子"])

func _奇遇弹窗(q: Dictionary, 弟子: Disciple):
	# Step 2 奇遇调度（q-2 拍板）：灰模即对齐总览§15.5 形态——
	# 右下角 320×120 气泡 + 左上角稀有度角标(灰/蓝/紫/金)，点击展开详情；L3 直接全屏；L1 三秒无操作自动收起。
	var 稀有度: String = q.get("稀有度", "普通")
	var 层级: int = q.get("display_level", 2)
	var 大: bool = 层级 >= 3

	# 稀有度角标色（灰/蓝/紫/金，对齐 q-2 拍板；预留§10 四档映射）
	var 角标色: Color = Color(0.60, 0.63, 0.67)   # 普通 灰
	match 稀有度:
		"稀有": 角标色 = Color(0.23, 0.51, 0.96)   # 蓝
		"史诗": 角标色 = Color(0.55, 0.36, 0.96)   # 紫
		"传说": 角标色 = Color(0.96, 0.62, 0.04)   # 金

	if 大:
		_奇遇详情(q, 弟子, 角标色, true)
		return

	# L1/L2：右下角 320×120 气泡占位
	var 泡 := PanelContainer.new()
	泡.name = "奇遇气泡"
	泡.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	泡.offset_left = -332
	泡.offset_top = -132
	泡.offset_right = -12
	泡.offset_bottom = -12
	泡.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(泡)

	var 横 := HBoxContainer.new()
	泡.add_child(横)
	var 角 := ColorRect.new()
	角.custom_minimum_size = Vector2(16, 16)
	角.color = 角标色
	横.add_child(角)
	var 纵 := VBoxContainer.new()
	横.add_child(纵)
	var 题 := Label.new()
	题.text = "【%s】%s" % [稀有度, q.get("event_name", "无名奇遇")]
	纵.add_child(题)
	var 提 := Label.new()
	提.text = "点击查看详情"
	纵.add_child(提)

	var 已展开 := false
	var 计时: Timer = null
	if 层级 <= 1:
		计时 = Timer.new()
		计时.wait_time = 3.0
		计时.one_shot = true
		add_child(计时)
	计时.timeout.connect(func():
		if is_instance_valid(泡):
			泡.queue_free()
		奇遇弹窗中 = false
		_显示下一奇遇()
		)
	计时.start()

	泡.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and not 已展开:
			已展开 = true
			if 计时 != null and is_instance_valid(计时):
				计时.stop()
				计时.queue_free()
			泡.queue_free()
			_奇遇详情(q, 弟子, 角标色, false)
		)

func _奇遇详情(q: Dictionary, 弟子: Disciple, 角标色: Color, 全屏: bool):
	var 遮 := ColorRect.new()
	遮.color = Color(0.10, 0.09, 0.08, 0.60)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "奇遇详情"
	add_child(遮)
	var pc: PanelContainer = 新面板("【奇遇·%s】%s" % [q.get("稀有度", "普通"), q.get("event_name", "无名奇遇")])
	if 全屏:
		pc.anchor_left = 0.5; pc.anchor_top = 0.5; pc.anchor_right = 0.5; pc.anchor_bottom = 0.5
		pc.offset_left = -230; pc.offset_top = -280; pc.offset_right = 230; pc.offset_bottom = 280
	else:
		pc.anchor_left = 0.5; pc.anchor_top = 0.3; pc.anchor_right = 0.5; pc.anchor_bottom = 0.3
		pc.offset_left = -210; pc.offset_top = 0; pc.offset_right = 210; pc.offset_bottom = 0
	遮.add_child(pc)
	var 内容: Control = pc.get_child(0)
	var 角 := ColorRect.new()
	角.custom_minimum_size = Vector2(16, 16)
	角.color = 角标色
	内容.add_child(角)
	var 头 := Label.new()
	头.text = "【%s】遭遇此奇遇" % 弟子.姓名
	头.add_theme_color_override("font_color", 次墨)
	内容.add_child(头)
	var 文 := Label.new()
	文.text = q.get("文案", "")
	文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	内容.add_child(文)
	# opt1/2/3 作为风味文本展示（当前结算为自动判定，选项仅展示，干预 UI 待 S1）
	for 标签 in [["其一", q.get("opt1_desc", "")], ["其二", q.get("opt2_desc", "")], ["其三", q.get("opt3_desc", "")]]:
		var 描述: String = 标签[1] as String
		if 描述 != "":
			var l := Label.new()
			l.text = "· %s：%s" % [标签[0], 描述]
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			内容.add_child(l)
	var 关 := Button.new()
	关.text = "确定"
	关.pressed.connect(func():
		遮.queue_free()
		奇遇弹窗中 = false
		刷新()
		_显示下一奇遇()
		)
	内容.add_child(关)

func 刷新纪事():
	for c in 纪事区.get_children():
		c.queue_free()
	if Game.宗门纪事.is_empty():
		var 空 := Label.new(); 空.text = "（宗门纪事暂无记录，奇遇触发后于此回看）"; 纪事区.add_child(空)
		return
		纪事区.add_child(小标题("—— 宗门纪事 ——", 15))
	var 异闻数: int = 0
	for 记 in Game.宗门纪事:
		if 记.get("category", "") == "异闻":
			异闻数 += 1
	if 异闻数 > 0:
		var 切换 := Button.new()
		切换.text = ("✦ 异闻秘闻（%d）" % 异闻数) if not 纪事异闻仅看 else "· 显示全部纪事 ·"
		切换.flat = true
		切换.add_theme_font_size_override("font_size", 13)
		切换.add_theme_color_override("font_color", 暗金)
		切换.pressed.connect(func():
			纪事异闻仅看 = not 纪事异闻仅看
			刷新纪事()
		)
		纪事区.add_child(切换)
	for 记 in Game.宗门纪事:
		if 纪事异闻仅看 and 记.get("category", "") != "异闻":
			continue
		var pc: PanelContainer = 新面板("")
		var vb: Control = pc.get_child(0)
		var 文案: String = 记.get("文案", "")
		if 文案.contains("[url="):
			# S1 点击联动 MVP：含 bbcode 链接（奇遇奖励物品）的纪事用 RichTextLabel 渲染，
			# 复用战斗日志同款 meta_clicked → open_detail_by_url 接法；不含链接的保持原 Label 行为。
			var 链接: RichTextLabel = RichTextLabel.new()
			链接.bbcode_enabled = true
			链接.fit_content = true
			链接.meta_clicked.connect(func(meta): open_detail_by_url(str(meta)))
			链接.text = "历%d日·【%s】%s（%s）\n%s" % [
				记.get("日", 0), 记.get("弟子", "无名"), 记.get("名称", "无名奇遇"),
				记.get("稀有度", "普通"), 文案,
			]
			vb.add_child(链接)
		else:
			var 信息 := Label.new()
			信息.text = "历%d日·【%s】%s（%s）\n%s" % [
				记.get("日", 0), 记.get("弟子", "无名"), 记.get("名称", "无名奇遇"),
				记.get("稀有度", "普通"), 文案,
			]
			信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(信息)
		纪事区.add_child(pc)

# ============ 测灵根过场弹窗（文字占位，动画接口预留）============
func _过场弹窗(过场: String, 人数: int):
	var 遮 := ColorRect.new()
	遮.color = Color(0.10, 0.09, 0.08, 0.60)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "测灵根过场"
	add_child(遮)
	var pc: PanelContainer = 新面板("【接引大典】")
	# 手动居中：anchor 锁中 + offset 控半宽高
	pc.anchor_left = 0.5
	pc.anchor_top = 0.5
	pc.anchor_right = 0.5
	pc.anchor_bottom = 0.5
	pc.offset_left = -200
	pc.offset_top = -120
	pc.offset_right = 200
	pc.offset_bottom = 120
	pc.custom_minimum_size = Vector2(400, 240)
	遮.add_child(pc)
	var 内容: Control = pc.get_child(0)
	# 预留动画接口：此处可替换为御剑风行 / 灵光石柱动画节点
	var 文 := Label.new()
	文.text = 过场
	文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	内容.add_child(文)
	var 尾 := Label.new()
	尾.text = "本届接引大典收录外门弟子 %d 人（本期接引名额已用尽），潜心修行，他日或可证道。" % 人数
	尾.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	内容.add_child(尾)
	var 关 := Button.new(); 关.text = "收入外门"
	关.pressed.connect(func(): 遮.queue_free(); 详情.text = "接引大典完成，录入 %d 名新弟子。" % 人数; 刷新())
	内容.add_child(关)
	详情.text = "接引大典进行中……"

# ============ 建筑总览弹窗（原「堂口管理」；首发文案统一称建筑，居中面板）============
# ============ 历练征途（Day 3 灰模 UI：关卡选择→上阵→战斗结算→掉落）============
# 架构解耦：UI 仅调用 Game.挑战关卡（数据驱动逻辑层），不碰 BattleCalculator/Manager 结算核心。
# ============ 新手引导系统（A 包：单线性四步，纯灰模，逻辑独立封装不侵入业务）============
# 阶段：0=未开始(开场叙事) / 1=收资源 / 2=招弟子 / 3=历练战斗 / 4=看弟子详情 / 5=完成
# 事实源：Game.引导阶段（game_state 存档，老档默认=5 不强制弹）。零新增文案，复用 GDD-新手引导 既有设定。

# 四步引导文案（修仙化包装「宗门传承指引」）
var 引导_步骤文案: Dictionary = {
	1: "【宗门传承指引】先点「建筑总览」查看宗门产出，收取第一波资源。",
	2: "【宗门传承指引】点「开启接引大典」，广招门徒，录入第一名弟子。",
	3: "【宗门传承指引】点「历练征途」，遣弟子下山历练，完成首次战斗。",
	4: "【宗门传承指引】点开左侧任一弟子，查看其详情，了解境界/灵根/养成。",
}
# 开场叙事（复用 GDD §2.2 序章剧情 + §2.3 吴伯原句，零新增文案需求）
var 引导_开场文本: Array = [
	{"人":"【序章·继位】", "文":"老宗主已然仙去，临终托孤于你。太玄宗虽已式微，根基尚在——重振山门，在此一举。"},
	{"人":"苏清禾", "文":"掌门，妾身与吴伯会一路辅佐。当务之急，是先收取宗门产出、广招门徒、遣其历练。"},
	{"人":"吴伯", "文":"山下青峰山脚有妖兽作乱，正好可以让弟子前去历练，积攒经验还能捡回材料。"},
]

func _引导_初始化():
	# 覆盖层：全屏、不拦截点击（点击穿透到下层真实按钮，强引导仅高亮不阻挡）
	引导_层 = Control.new()
	引导_层.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	引导_层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	引导_层.visible = false
	add_child(引导_层)
	# 常驻「跳过引导」按钮（右上角）
	引导_跳过按钮 = Button.new()
	引导_跳过按钮.text = "跳过引导"
	引导_跳过按钮.add_theme_font_size_override("font_size", 12)
	引导_跳过按钮.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	引导_跳过按钮.offset_left = -84
	引导_跳过按钮.offset_top = 4
	引导_跳过按钮.offset_right = -8
	引导_跳过按钮.offset_bottom = 32
	引导_跳过按钮.visible = false
	引导_跳过按钮.pressed.connect(_引导_跳过)
	add_child(引导_跳过按钮)
	# 触发：新档开场 / 中途档续接 / 老档(=5)隐藏
	引导_跳过按钮.visible = (Game.引导阶段 < 5)
	if Game.引导阶段 == 0:
		_引导_开场()
	elif Game.引导阶段 >= 1 and Game.引导阶段 <= 4:
		_引导_刷新()

func _引导_开场():
	_引导_清除()
	引导_开场段 = 0
	_引导_开场渲染()

func _引导_开场渲染():
	_引导_清除()
	var 遮 := ColorRect.new()
	遮.color = Color(0.06, 0.06, 0.08, 0.80)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	引导_层.add_child(遮)
	var pc: PanelContainer = 新面板("—— 宗门传承指引 · 序章 ——")
	# 手动居中：anchor 锁中 + offset 控半宽高
	pc.anchor_left = 0.5
	pc.anchor_top = 0.5
	pc.anchor_right = 0.5
	pc.anchor_bottom = 0.5
	pc.offset_left = -210
	pc.offset_top = -148
	pc.offset_right = 210
	pc.offset_bottom = 148
	pc.custom_minimum_size = Vector2(420, 296)
	var 内容: Control = pc.get_child(0)
	var 段: Dictionary = 引导_开场文本[引导_开场段]
	var 说话 := Label.new(); 说话.text = 段["人"]; 说话.add_theme_font_size_override("font_size", 15); 说话.add_theme_color_override("font_color", 暗金)
	var 文 := Label.new(); 文.text = 段["文"]; 文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; 文.custom_minimum_size = Vector2(320, 80)
	内容.add_child(说话); 内容.add_child(文)
	var 末: bool = (引导_开场段 >= 引导_开场文本.size() - 1)
	var 钮 := Button.new(); 钮.text = "开始治宗" if 末 else "继续"
	钮.pressed.connect(func():
		if 末:
			遮.queue_free()
			Game.引导阶段 = 1
			Game.save_game()
			_引导_刷新()
		else:
			遮.queue_free()
			引导_开场段 += 1
			_引导_开场渲染()
		)
	内容.add_child(钮)
	引导_层.add_child(pc)
	引导_层.visible = true

func _引导_推进(动作: String):
	var 期望: Dictionary = {"资源": 1, "招收": 2, "历练战斗": 3, "查看弟子": 4}
	var 目标: int = 期望.get(动作, -1)
	if Game.引导阶段 == 目标:
		Game.引导阶段 += 1
		Game.save_game()
	if Game.引导阶段 == 5:
		_引导_收尾()
	else:
		_引导_刷新()

func _引导_刷新():
	_引导_清除()
	if Game.引导阶段 >= 1 and Game.引导阶段 <= 4:
		引导_跳过按钮.visible = true
	var 目标: Control = null
	match Game.引导阶段:
		1: 目标 = 引导_建筑按钮
		2: 目标 = 引导_招收按钮
		3: 目标 = 引导_历练按钮
		4: 目标 = 列表
	if 目标 != null and is_instance_valid(目标):
		var 文案: String = 引导_步骤文案.get(Game.引导阶段, "")
		if 文案.strip_edges() != "":   # 防护：空白文案不渲染气泡
			_引导_显示气泡(目标, 文案)
	elif Game.引导阶段 >= 5:
		引导_跳过按钮.visible = false

func _引导_显示气泡(目标: Control, 文案: String):
	if 文案.strip_edges() == "" or not is_instance_valid(目标):
		return   # 防护：空白文案或无效目标不渲染气泡（避免空白弹窗）
	var 遮 := ColorRect.new()
	遮.color = Color(0.06, 0.06, 0.08, 0.55)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_IGNORE
	引导_层.add_child(遮)
	# 高亮框（透明底 + 青霓边框圈住目标按钮）
	var 框 := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0.25, 0.82, 0.88, 1)
	sb.set_border_width_all(3)
	框.add_theme_stylebox_override("panel", sb)
	var gp: Vector2 = 目标.get_global_position()
	var lp: Vector2 = 引导_层.get_global_position()
	框.position = gp - lp
	框.size = 目标.size
	框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	引导_层.add_child(框)
	# 气泡（墨底圆角 + 青霓边）
	var 泡 := PanelContainer.new()
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = Color(0.12, 0.13, 0.16, 0.96)
	sb_style.border_color = Color(0.25, 0.82, 0.88, 1)
	sb_style.set_border_width_all(1)
	sb_style.set_corner_radius_all(6)
	泡.add_theme_stylebox_override("panel", sb_style)
	var 文 := Label.new(); 文.text = 文案; 文.add_theme_font_size_override("font_size", 14); 文.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1))
	泡.add_child(文)
	泡.custom_minimum_size = Vector2(300, 70)
	泡.position = Vector2(框.position.x, 框.position.y + 框.size.y + 6)
	if 泡.position.y + 80 > 854:
		泡.position.y = max(4.0, 框.position.y - 90.0)
	引导_层.add_child(泡)
	引导_层.visible = true

func _引导_收尾():
	if _引导已收尾:
		return   # 已播过，不再重复弹
	_引导已收尾 = true
	_引导_清除()
	var 遮 := ColorRect.new()
	遮.color = Color(0.06, 0.06, 0.08, 0.55)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_IGNORE
	引导_层.add_child(遮)
	var 泡 := PanelContainer.new()
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = Color(0.12, 0.13, 0.16, 0.96)
	sb_style.border_color = Color(0.25, 0.82, 0.88, 1)
	sb_style.set_border_width_all(1)
	sb_style.set_corner_radius_all(6)
	泡.add_theme_stylebox_override("panel", sb_style)
	泡.custom_minimum_size = Vector2(340, 120)
	var 文 := Label.new()
	文.text = "【苏清禾】掌门已初窥门径，宗门运转自此步入正轨。\n可点击弟子查看详情，后续自有典籍指引，可随时翻阅。"
	文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	文.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1))
	泡.add_child(文)
	var 关 := Button.new(); 关.text = "知道了"
	关.pressed.connect(func(): _引导_清除())
	泡.add_child(关)
	泡.position = Vector2(90, 360)
	引导_层.add_child(泡)
	引导_层.visible = true
	引导_跳过按钮.visible = false

func _引导_跳过():
	Game.引导阶段 = 5
	Game.save_game()
	_引导_清除()
	引导_跳过按钮.visible = false
	详情.text = "（已跳过新手引导）"

func _引导_清除():
	if 引导_层 == null:
		return
	for c in 引导_层.get_children():
		c.queue_free()
		引导_层.visible = false

func _on_历练():
	_引导_推进("历练战斗")
	if Game.引导阶段 <= 4:   # 引导未结束：临时隐藏引导层，避免暗化遮罩盖住历练面板
		引导_层.visible = false
	_历练面板()

# ============ A5 法宝 UI 面板（灰模：9 槽 + 储物袋点击穿戴/卸载）============
# 槽位 9 个（键见 item.gd 槽显示：wuqi/toukui/yipao/huzhi/yaodai/changku/xuezi/peishi/本命法宝）
# 数据层已就绪（disciple.装备/背包/穿戴/卸载/一键最优穿戴），此处仅做灰模呈现与交互。
func _卸下装备(d: Disciple, 槽: String):
	d.卸载(槽)
	_装备面板(d)

func _穿戴装备(d: Disciple, it: Item):
	d.穿戴(it.穿戴位, it)
	_装备面板(d)

func _最优穿戴(d: Disciple):
	d.一键最优穿戴()
	_装备面板(d)

func _装备面板(d: Disciple):
	if 装备面板节点 != null:
		装备面板节点.queue_free()
	var 遮 := ColorRect.new()
	遮.color = 墨底
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "装备面板"
	add_child(遮)
	装备面板节点 = 遮
	var 大 := PanelContainer.new()
	大.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	大.offset_left = 12
	大.offset_right = -12
	大.offset_top = 36
	大.offset_bottom = -12
	遮.add_child(大)
	var 内容 := VBoxContainer.new()
	大.add_child(内容)
	var 头 := Label.new()
	头.text = "⚔ 法宝 · %s" % d.姓名
	头.add_theme_font_size_override("font_size", 18)
	头.add_theme_color_override("font_color", 暗金)
	内容.add_child(头)
	var 战 := Label.new()
	战.text = "总战力：%d　境界：%s" % [d.实时战力(), d.境界]
	战.add_theme_color_override("font_color", 次墨)
	内容.add_child(战)
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, 420)
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	内容.add_child(滚)
	var 列 := VBoxContainer.new()
	列.add_theme_constant_override("separation", 4)
	滚.add_child(列)

	列.add_child(小标题("—— 弟子法宝 ——", 15))
	for 槽key in Item.槽显示.keys():
		var 行 := HBoxContainer.new()
		行.add_theme_constant_override("separation", 8)
		var 槽名Label := Label.new()
		var 显示槽名: String = Item.槽显示.get(槽key, 槽key)
		if 槽key == "本命法宝":
			槽名Label.text = "✦%s：" % 显示槽名
			槽名Label.add_theme_color_override("font_color", 暗金)
		else:
			槽名Label.text = "%s：" % 显示槽名
			槽名Label.add_theme_color_override("font_color", 青灰)
		槽名Label.custom_minimum_size.x = 50
		行.add_child(槽名Label)
		var 当前装备: Item = d.装备.get(槽key)
		var 装备标签 := RichTextLabel.new()
		装备标签.fit_content = true
		装备标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if 当前装备 != null:
			装备标签.append_text("[color=%s]%s[/color]［%s］" % [暗金.to_html(), 当前装备.名称, 当前装备.品阶])
			var 详 := Button.new(); 详.text = "详情"; 详.custom_minimum_size.x = 40
			行.add_child(详); 详.pressed.connect(_弹出物品详情.bind(当前装备))
		else:
			装备标签.append_text("[color=888888]— 空 —[/color]")
		行.add_child(装备标签)
		if 当前装备 != null:
			var 卸 := Button.new(); 卸.text = "卸下"
			行.add_child(卸); 卸.pressed.connect(_卸下装备.bind(d, 槽key))
		列.add_child(行)

	列.add_child(小标题("—— 储 物 袋 ——", 15))
	if d.背包.is_empty():
		var 空 := Label.new()
		空.text = "— 空 —"
		空.add_theme_color_override("font_color", 次墨)
		列.add_child(空)
	else:
		for it in d.背包:
			var 行 := HBoxContainer.new()
			行.add_theme_constant_override("separation", 6)
			var 信息 := RichTextLabel.new()
			信息.fit_content = true
			if it.可穿戴():
				信息.append_text("%s［%s］·%s·[color=green]+%d[/color]" % [it.名称, it.品阶, Item.槽显示.get(it.穿戴位, it.穿戴位), it.战力加成])
			else:
				信息.append_text("%s［%s］[color=888888]（不可穿戴）[/color]" % [it.名称, it.品阶])
			行.add_child(信息)
			if it.可穿戴():
				var 穿 := Button.new()
				穿.text = "穿戴"
				穿.pressed.connect(_穿戴装备.bind(d, it))
				行.add_child(穿)
			列.add_child(行)

	var 最优 := Button.new()
	最优.text = "一键最优穿戴"
	最优.pressed.connect(_最优穿戴.bind(d))
	内容.add_child(最优)
	var 关 := Button.new()
	关.text = "归藏"
	关.pressed.connect(func():
		if 装备面板节点 != null:
			装备面板节点.queue_free()
		装备面板节点 = null)
	内容.add_child(关)

# ============ S0 坊市（商店）：消耗灵石出口 ============
func _on_坊市():
	_坊市面板()

func _坊市面板():
	if Game.坊市上架集.is_empty():
		Game.刷新坊市上架()
	var 遮 := ColorRect.new()
	遮.color = Color(0.10, 0.09, 0.08, 0.55)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "坊市面板"
	add_child(遮)
	var pc: PanelContainer = 新面板("✦ 坊市（消耗灵石 · 周限购）")
	# 锚点居中：anchor 全 0.5 + offset 正负半宽高 = 精确居中，不受嵌套布局影响
	pc.anchor_left = 0.5; pc.anchor_top = 0.5; pc.anchor_right = 0.5; pc.anchor_bottom = 0.5
	pc.offset_left = -200; pc.offset_top = -260; pc.offset_right = 200; pc.offset_bottom = 260
	遮.add_child(pc)
	var 内容: Control = pc.get_child(0)
	var 结果 := Label.new(); 结果.text = _坊市提示; 内容.add_child(结果)
	var 滚 := ScrollContainer.new(); 滚.custom_minimum_size = Vector2(380, 400); 内容.add_child(滚)
	var 列 := VBoxContainer.new(); 滚.add_child(列)
	_刷新坊市列表(列, 结果, 遮)

func _刷新坊市列表(列: VBoxContainer, 结果: Label, 遮: ColorRect):
	for c in 列.get_children():
		c.queue_free()
	var 等级名: String = Game.声望等级名[clamp(Game.声望, 0, Game.声望等级名.size() - 1)]
	for r in Game._坊市表():
		if not (r.get("shop_id", "") in Game.坊市上架集):
			continue
		var 名: String = r.get("item_name", "")
		var 原价: int = int(r.get("price_lingjing", "0"))
		var 折后: int = Game.坊市实价(原价)
		var 折扣说明: String = "" if 折后 == 原价 else "（%s%d折）" % [等级名, int(Game.坊市折扣率() * 100)]
		var 限: String = "日%d/周%d" % [int(r.get("limit_daily", "0")), int(r.get("limit_weekly", "0"))]
		var 行 := HBoxContainer.new()
		var 原价文本: String = "" if 折后 == 原价 else "原价%d " % 原价
		var 标 := Label.new(); 标.text = "%s %s%d灵石 [%s]" % [名, 原价文本, 折后, 限]
		var 买 := Button.new(); 买.text = "购买"
		买.pressed.connect(func():
			var res: Dictionary = Game.购买坊市物品(r.get("shop_id", ""))
			结果.text = res.get("msg", "")
			_坊市提示 = res.get("msg", "")
			刷新()
			_刷新坊市列表(列, 结果, 遮)
		)
		行.add_child(标); 行.add_child(买)
		列.add_child(行)
	# —— 宗门库房分类展示（资源/装备/丹药/功法）——
	var 库头 := Label.new(); 库头.text = "── 宗门库房（%d件）──" % Game.宗门库房.size(); 列.add_child(库头)
	var 分组: Dictionary = {"资源": [], "装备": [], "丹药": [], "功法": []}
	for it in Game.宗门库房:
		var 类: String = it.类别
		if 类 == "法器":
			类 = "装备"
		if not 分组.has(类):
			分组[类] = []
		分组[类].append("%s·%s" % [it.名称, it.品阶])
	for 类 in ["资源", "装备", "丹药", "功法"]:
		if 分组[类].size() > 0:
			var 段 := HBoxContainer.new()
			var 类标 := Label.new(); 类标.text = "[%s] " % 类; 段.add_child(类标)
			for it in Game.宗门库房:
				var 它类: String = "装备" if it.类别 == "法器" else it.类别
				if 它类 != 类:
					continue
				var 钮 := Button.new(); 钮.text = "%s·%s" % [it.名称, it.品阶]
				钮.pressed.connect(_弹出物品详情.bind(it))
				段.add_child(钮)
			列.add_child(段)
	var 关 := Button.new(); 关.text = "归藏"
	关.pressed.connect(func(): _坊市提示 = ""; 遮.queue_free())
	列.add_child(关)

# ============ S0 任务中心：日常（3条）+ 周常（1条）============
func _on_任务():
	_任务面板()

func _任务面板():
	var 遮 := ColorRect.new()
	遮.color = Color(0.10, 0.09, 0.08, 0.55)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "任务面板"
	add_child(遮)
	var pc: PanelContainer = 新面板("✦ 任务中心")
	pc.anchor_left = 0.5; pc.anchor_top = 0.5; pc.anchor_right = 0.5; pc.anchor_bottom = 0.5
	pc.offset_left = -200; pc.offset_top = -260; pc.offset_right = 200; pc.offset_bottom = 260
	遮.add_child(pc)
	var 内容: Control = pc.get_child(0)
	var 结果 := Label.new(); 结果.text = _任务提示; 内容.add_child(结果)
	var 滚 := ScrollContainer.new(); 滚.custom_minimum_size = Vector2(380, 400); 内容.add_child(滚)
	var 列 := VBoxContainer.new(); 滚.add_child(列)
	# —— 日常任务 ——
	var 日常倒计: int = max(0, (Game.上次日常日 + 1) - Game.累计游戏日)
	var 日头 := Label.new(); 日头.text = "【日常】每日刷新(距%d日) 领灵石/灵气" % 日常倒计; 列.add_child(日头)
	for i in Game.当前日常.size():
		var q: Dictionary = Game.当前日常[i]
		var 已领: bool = Game.日常已领[i] if i < Game.日常已领.size() else false
		var 行 := HBoxContainer.new()
		var 标 := Label.new()
		标.text = "%s：%s（石+%s 气+%s）%s" % [q.get("quest_name", ""), q.get("target_desc", ""), q.get("reward_lingjing", "0"), q.get("reward_lingqi", "0"), "✅" if 已领 else ""]
		var 领 := Button.new(); 领.text = "领取" if not 已领 else "已领"
		领.disabled = 已领
		领.pressed.connect(func():
			var res: Dictionary = Game.领取日常(i)
			_任务提示 = res.get("msg", "")
			_任务面板_重建(遮)
		)
		行.add_child(标); 行.add_child(领)
		列.add_child(行)
	# —— 周常任务 ——
	var 周常倒计: int = max(0, (Game.上次周常日 + 7) - Game.累计游戏日)
	var 周头 := Label.new(); 周头.text = "【周常】每7日刷新(距%d日)" % 周常倒计; 列.add_child(周头)
	if Game.当前周常.is_empty():
		var 无 := Label.new(); 无.text = "（暂未解锁，提升门派等级后开启）"; 列.add_child(无)
	else:
		var qw: Dictionary = Game.当前周常
		var 行 := HBoxContainer.new()
		var 标 := Label.new()
		标.text = "%s：%s（石+%s 气+%s）%s" % [qw.get("quest_name", ""), qw.get("target_desc", ""), qw.get("reward_lingjing", "0"), qw.get("reward_lingqi", "0"), "✅" if Game.周常已领 else ""]
		var 领 := Button.new(); 领.text = "领取" if not Game.周常已领 else "已领"
		领.disabled = Game.周常已领
		领.pressed.connect(func():
			var res: Dictionary = Game.领取周常()
			_任务提示 = res.get("msg", "")
			_任务面板_重建(遮)
		)
		行.add_child(标); 行.add_child(领)
		列.add_child(行)
	var 一键 := Button.new(); 一键.text = "一键领取"
	一键.pressed.connect(func():
		var 领了: int = 0
		for i in Game.当前日常.size():
			if not Game.日常已领[i]:
				var r: Dictionary = Game.领取日常(i)
				if r.get("ok", false): 领了 += 1
		if not Game.当前周常.is_empty() and not Game.周常已领:
			var rw: Dictionary = Game.领取周常()
			if rw.get("ok", false): 领了 += 1
		_任务提示 = "已领取 %d 项" % 领了
		_任务面板_重建(遮)
	)
	列.add_child(一键)
	var 关 := Button.new(); 关.text = "归藏"; 关.pressed.connect(func(): _任务提示 = ""; 遮.queue_free()); 列.add_child(关)

# 任务面板局部重建（保留遮罩，刷新列表与提示）
func _任务面板_重建(遮: ColorRect):
	_任务提示 = _任务提示
	遮.queue_free()
	_任务面板()

func _历练面板():
	var 遮 := ColorRect.new()
	遮.color = 墨底
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "历练面板"
	add_child(遮)
	var 大 := PanelContainer.new()
	# 全屏锚点 + 边距内嵌（不用 PRESET_CENTER+minimum_size，后者在 GD4 中会被内容收缩）
	大.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	大.offset_left = 12
	大.offset_right = -12
	大.offset_top = 36
	大.offset_bottom = -12
	遮.add_child(大)
	var 内容 := VBoxContainer.new()
	大.add_child(内容)
	var 头 := Label.new()
	头.text = "⚔ 历练征途"
	头.add_theme_font_size_override("font_size", 18)
	头.add_theme_color_override("font_color", 暗金)
	内容.add_child(头)
	var 体力标 := Label.new()
	体力标.text = "气力：%d / %d" % [Game.体力, Game.体力上限()]
	体力标.add_theme_color_override("font_color", 次墨)
	内容.add_child(体力标)
	var 滚动 := ScrollContainer.new()
	滚动.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚动.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	内容.add_child(滚动)
	var 列 := VBoxContainer.new()
	列.add_theme_constant_override("separation", 4)
	滚动.add_child(列)
	历练滚动列 = 列   # 保存引用，战斗胜利后刷新用
	var 章名: Dictionary = {1: "第一章·后山秘境", 2: "第二章·青冥古道", 3: "第三章·玄雾峡谷"}
	for 章 in [1, 2, 3]:
		var 章标 := Label.new()
		章标.text = "【%s】" % 章名[章]
		章标.add_theme_color_override("font_color", 青灰)
		列.add_child(章标)
		for s in StageDataLoader.get_all_stages():
			if int(s.get("chapter", "0")) != 章:
				continue
			列.add_child(_历练关卡卡(s))
	var 关 := Button.new()
	关.text = "归藏"
	关.pressed.connect(func():
		遮.queue_free()
		if Game.引导阶段 <= 4:   # 引导进行中：关闭历练后恢复引导层并刷新步骤气泡
			引导_层.visible = true
			_引导_刷新()
	)
	内容.add_child(关)

func _历练关卡卡(s: Dictionary) -> Control:
	var pc: PanelContainer = 新面板("")
	var 内容 := VBoxContainer.new()
	pc.add_child(内容)
	var 类型名: String = {"normal": "普通", "elite": "精英", "treasure": "奇遇", "boss": "BOSS"}.get(s.get("node_type", ""), "?")
	var sid: String = s.get("stage_id", "")
	var 解锁: bool = StageDataLoader.is_unlocked(sid, Game.门派等级, Game.已通关关卡)
	var 已通: bool = Game.已通关关卡.has(sid)
	var 头 := Label.new()
	头.text = "%s %s%s" % [sid, s.get("stage_name", ""), "  ✓首通" if 已通 else ""]
	内容.add_child(头)
	var 副 := Label.new()
	副.text = "%s ｜ 气力%d ｜ 推荐战力%s%s" % [类型名, int(s.get("stamina_cost", "0")), str(StageDataLoader.get_recommend_power(s.get("stage_id", ""))), " ｜ 未解锁" if not 解锁 else ""]
	副.add_theme_color_override("font_color", 次墨)
	副.add_theme_font_size_override("font_size", 12)
	内容.add_child(副)
	if 解锁:
		var 攻 := Button.new()
		if s.get("node_type", "") == "treasure":
			攻.text = "探索（历练奇遇）"
			攻.pressed.connect(func(): _历练奇遇(s))
		else:
			攻.text = "挑战"
			攻.pressed.connect(func(): _开战弹窗(s))
		内容.add_child(攻)
	else:
		var 锁 := Label.new()
		锁.text = "（先满足条件解锁）"
		锁.add_theme_color_override("font_color", 次墨)
		内容.add_child(锁)
	return pc

# 重建历练关卡列表（战斗胜利后调用，刷新解锁状态/首通标记）
func _刷新历练关卡():
	if 历练滚动列 == null or not is_instance_valid(历练滚动列):
		return
	# 清空旧卡
	for c in 历练滚动列.get_children():
		c.queue_free()
	# 按章重建（与 _历历练面板 同构）
	var 章名: Dictionary = {1: "第一章·后山秘境", 2: "第二章·青冥古道", 3: "第三章·玄雾峡谷"}
	for 章 in [1, 2, 3]:
		var 章标 := Label.new()
		章标.text = "【%s】" % 章名[章]
		章标.add_theme_color_override("font_color", 青灰)
		历练滚动列.add_child(章标)
		for s in StageDataLoader.get_all_stages():
			if int(s.get("chapter", "0")) != 章:
				continue
			历练滚动列.add_child(_历练关卡卡(s))

func _开战弹窗(s: Dictionary):
	var 遮 := ColorRect.new()
	遮.color = 墨底
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "开战弹窗"
	add_child(遮)
	var 大 := PanelContainer.new()
	大.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	大.offset_left = 20
	大.offset_right = -20
	大.offset_top = 50
	大.offset_bottom = -20
	遮.add_child(大)
	var 内容 := VBoxContainer.new()
	大.add_child(内容)
	var 头 := Label.new()
	头.text = "出战布阵：%s" % s.get("stage_name", "")
	头.add_theme_font_size_override("font_size", 16)
	头.add_theme_color_override("font_color", 暗金)
	内容.add_child(头)
	var 副 := Label.new()
	副.text = "气力-%d ｜ 推荐战力%s ｜ 最多3名弟子" % [int(s.get("stamina_cost", "0")), str(StageDataLoader.get_recommend_power(s.get("stage_id", "")))]
	副.add_theme_color_override("font_color", 次墨)
	内容.add_child(副)
	var 选中: Array = []
	var 状态标 := Label.new()
	状态标.text = "已选：0 / 3"
	内容.add_child(状态标)
	var 滚动 := ScrollContainer.new()
	滚动.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚动.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	内容.add_child(滚动)
	var 列 := VBoxContainer.new()
	列.add_theme_constant_override("separation", 3)
	滚动.add_child(列)
	var 可选弟子: Array = Game.弟子列表.duplicate()
	可选弟子.sort_custom(func(a, b): return a.实时战力() > b.实时战力())
	for d in 可选弟子:
		var b := Button.new()
		b.text = "%s（战%d）" % [d.姓名, d.实时战力()]
		b.pressed.connect(func():
			if 选中.has(d):
				选中.erase(d)
				b.text = "%s（战%d）" % [d.姓名, d.实时战力()]
			elif 选中.size() < 3:
				选中.append(d)
				b.text = "✓ %s（战%d）" % [d.姓名, d.实时战力()]
			状态标.text = "已选：%d / 3" % 选中.size()
		)
		列.add_child(b)
	var 确 := Button.new()
	确.text = "出战！"
	确.pressed.connect(func():
		if 选中.is_empty():
			详情.text = "请至少选择一名出战弟子。"
			return
		遮.queue_free()
		_执行挑战(s.get("stage_id", ""), 选中)
		)
	内容.add_child(确)
	var 撤 := Button.new()
	撤.text = "返回"
	撤.pressed.connect(func(): 遮.queue_free())
	内容.add_child(撤)

func _执行挑战(stage_id: String, 出战: Array):
	var 战报: Dictionary = Game.挑战关卡(stage_id, 出战, "full")
	if 战报.get("error", "") != "":
		详情.text = "挑战未开始：" + 战报["error"]
		刷新()
		return
	_战斗结算面板(战报, stage_id)

func _战斗结算面板(战报: Dictionary, stage_id: String):
	var 胜: bool = 战报.get("is_win", false)
	# 引导推进/收尾移到"确定"按钮回调（结算遮罩销毁后再弹，避免被盖住）
	var 遮 := ColorRect.new()
	遮.color = 墨底
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "战斗结算"
	add_child(遮)
	var 大 := PanelContainer.new()
	大.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	大.offset_left = 16
	大.offset_right = -16
	大.offset_top = 40
	大.offset_bottom = -16
	遮.add_child(大)
	var 内容 := VBoxContainer.new()
	大.add_child(内容)
	# 标题强化（micro-opt 2）：浅灰背景条 + 字号加粗观感，与正文日志形成区块分隔
	var 标题底 := StyleBoxFlat.new()
	标题底.bg_color = Color(0.22, 0.21, 0.20, 1.0)
	标题底.set_content_margin_all(7)
	标题底.set_corner_radius_all(4)
	var 头 := Label.new()
	头.text = "⚔ %s：%s" % [stage_id, "胜 利" if 胜 else "失 败"]
	头.add_theme_font_size_override("font_size", 20)
	头.add_theme_color_override("font_color", 暗金 if 胜 else 次墨)
	头.add_theme_stylebox_override("normal", 标题底)
	内容.add_child(头)
	var 回合 := Label.new()
	回合.text = "回合 %d ｜ 胜方剩余气血 %d" % [int(战报.get("round_count", 0)), int(战报.get("remaining_hp", 0))]
	回合.add_theme_stylebox_override("normal", 标题底)
	内容.add_child(回合)
	var 奖励 := Label.new()
	奖励.text = "奖励：%s" % (战报.get("奖励摘要", "") if 战报.get("奖励摘要", "") != "" else "无")
	奖励.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	奖励.add_theme_stylebox_override("normal", 标题底)
	内容.add_child(奖励)
	var 日志标 := Label.new()
	日志标.text = "—— 战斗日志 ——"
	日志标.add_theme_color_override("font_color", 青灰)
	var 滚 := ScrollContainer.new()
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.custom_minimum_size = Vector2(0, 200)
	var 日志 := RichTextLabel.new()
	日志.bbcode_enabled = true
	日志.fit_content = true
	# S1 预埋：富文本链接点击联动（S0 不生成带 url 文本，不会触发；S1 填实 _解析实体 后直接生效）
	日志.meta_clicked.connect(func(meta): open_detail_by_url(str(meta)))
	# micro-opt 1：长日志自动折叠 + 展开/收起切换（交互闭环）
	var 全日志: Array = 战报.get("battle_log", [])
	var 展开全部 := false
	var 构建日志: Callable = func(展开: bool) -> void:
		var 文本 := ""
		# S1 点击联动 MVP：战斗双方名字包成 bbcode 链接，点击经 meta_clicked → open_detail_by_url 按姓名解析弟子
		var 链名: Callable = func(名: String) -> String:
			if 名 == "":
				return ""
			return "[url=disciple:%s]%s[/url]" % [名, 名]
		var 显示日志: Array = 全日志
		if not 展开 and 全日志.size() > 50:
			文本 += "[color=#adb5bd]（前 %d 条已折叠，仅显示最近 50 条）[/color]\n" % (全日志.size() - 50)
			显示日志 = 全日志.slice(全日志.size() - 50)
		for e in 显示日志:
			var 标签: Array = e.get("tags", [])
			if 标签.is_empty():
				if e.get("is_crit", false):
					标签.append("暴击")
				if e.get("is_restrain", false):
					标签.append("克制")
			var 标记 := ""
			for t in 标签:
				标记 += "[color=#ffd43b][b]【%s】[/b][/color] " % t
			var 回: String = "[color=#868e96]R%d[/color] " % int(e.get("round", 0))
			var 伤: int = int(e.get("damage", 0))
			if 标签.has("闪避"):
				文本 += "%s%s → %s %s\n" % [回, 链名.call(e.get("actor", "")), 链名.call(e.get("target", "")), 标记]
			else:
				文本 += "%s%s → %s 伤害 [color=#ff6b6b][b]%d[/b][/color] %s\n" % [回, 链名.call(e.get("actor", "")), 链名.call(e.get("target", "")), 伤, 标记]
		日志.text = 文本
	构建日志.call(展开全部)
	滚.add_child(日志)
	# 日志标题行 + 展开/收起按钮（仅长日志出现）
	var 日志头 := HBoxContainer.new()
	日志头.add_child(日志标)
	日志头.add_spacer(false)
	var 展开钮 := Button.new()
	展开钮.text = "展开全部"
	展开钮.add_theme_font_size_override("font_size", 12)
	展开钮.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
	展开钮.visible = 全日志.size() > 50
	展开钮.pressed.connect(func():
		展开全部 = not 展开全部
		构建日志.call(展开全部)
		展开钮.text = "收起部分" if 展开全部 else "展开全部"
	)
	日志头.add_child(展开钮)
	内容.add_child(日志头)
	内容.add_child(滚)
	var 确 := Button.new()
	确.text = "确定"
	确.pressed.connect(func():
		遮.queue_free()
		刷新()
		if 胜:
			_刷新历练关卡()  # 重建关卡卡，刷新解锁状态
		# 引导推进/收尾（结算遮罩已销毁，此时弹引导不会被盖住）
		if 胜 and Game.引导阶段 <= 4:
			# 历练战斗胜利 = 引导流程自然终点（建筑→招收→历练已完成）
			# 直接收尾，不在3→4之间卡一个额外交互断点
			if Game.引导阶段 < 5:
				Game.引导阶段 = 5
				Game.save_game()
				_引导_收尾()
	)
	内容.add_child(确)

# 历练奇遇节点（treasure）：不走战斗，保底触发历练类奇遇（trigger_scene=历练结算）
# 修复：原逻辑走概率+冷却且反馈写在被遮挡的 详情 标签，玩家感知"没反应"。
# 现改为保底触发（绕过概率/全局冷却，仍受每日上限+单条冷却约束）+ 体力扣减 + 可见 Toast 反馈。
func _历练奇遇(s: Dictionary):
	if Game.弟子列表.is_empty():
		_toast("（无弟子，无法探索）")
		return
	var 耗时: int = int(s.get("stamina_cost", 0))
	if Game.体力 < 耗时:
		_toast("（气力不足，需%d，余%d）" % [耗时, Game.体力])
		return
	Game.体力 = clamp(Game.体力 - 耗时, 0, Game.体力上限())
	var d: Disciple = Game.弟子列表[0]
	var 奇: Dictionary = Game._尝试触发奇遇(d, "历练结算", true)
	if 奇.is_empty():
		_toast("（本次探索一无所获，改日再来）")
	else:
		_toast("（探索有所得，奇遇已弹出）")
	刷新()   # 更新体力等显示

# 轻量 Toast 提示（顶部居中，自动消失），用于操作反馈（如历练探索结果）。
func _toast(文案: String):
	var t := PanelContainer.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.anchor_left = 0.0; t.anchor_top = 0.0; t.anchor_right = 0.0; t.anchor_bottom = 0.0
	t.position = Vector2(get_viewport().size.x / 2.0 - 130, 58)
	t.custom_minimum_size = Vector2(260, 38)
	t.add_theme_stylebox_override("panel", _toast底色())
	var lb := Label.new()
	lb.text = 文案
	lb.add_theme_font_size_override("font_size", 15)
	lb.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_child(lb)
	add_child(t)
	var tm := Timer.new()
	tm.wait_time = 1.8
	tm.one_shot = true
	add_child(tm)
	tm.timeout.connect(func():
		if is_instance_valid(t): t.queue_free()
		tm.queue_free()
	)
	tm.start()

func _toast底色() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.10, 0.92)
	sb.border_color = Color(0.72, 0.58, 0.20, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	return sb
func _建筑总览弹窗():
	var 遮 := ColorRect.new()
	遮.color = Color(0.10, 0.09, 0.08, 0.60)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "建筑总览"
	add_child(遮)
	var pc: PanelContainer = 新面板("—— 宗门建筑 ——")
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.offset_left = 20
	pc.offset_right = -20
	pc.offset_top = 50
	pc.offset_bottom = -20
	遮.add_child(pc)
	var 内容: Control = pc.get_child(0)
	内容.add_theme_constant_override("separation", 6)
	# 山门牌匾（彩蛋钩子）：点击查看宗门立基旧事
	var 牌匾 := Button.new()
	牌匾.text = "「太玄宗·山门」"
	牌匾.flat = true
	牌匾.add_theme_font_size_override("font_size", 16)
	牌匾.add_theme_color_override("font_color", 暗金)
	牌匾.pressed.connect(_on_山门牌匾)
	内容.add_child(牌匾)
	# 顶部全局汇总栏（固定一屏可见）
	内容.add_child(_建筑总览_汇总栏())
	# 分类标签导航（复用 TabBar 组件，参考离山汇总/主界面分页）
	var tb := TabBar.new()
	for 类别名 in 建筑类别序:
		tb.add_tab(类别名)
	内容.add_child(tb)
	# 滚动内容区（按类别切换，替代长列表滚动）
	var 滚动 := ScrollContainer.new()
	滚动.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚动.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	内容.add_child(滚动)
	var 列表列 := VBoxContainer.new()
	列表列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列表列.add_theme_constant_override("separation", 6)
	滚动.add_child(列表列)
	_建筑总览_填充(列表列, 建筑类别序[0])
	tb.tab_changed.connect(func(idx):
		_建筑总览_填充(列表列, 建筑类别序[idx])
	)
	# 关闭按钮（复用现有术语与交互）
	var 关 := Button.new(); 关.text = "归藏"
	关.pressed.connect(func(): 遮.queue_free(); 刷新())
	内容.add_child(关)

func _建筑点击彩蛋(key: String):
	var egg_id: String = 建筑彩蛋映射.get(key, "")
	if egg_id == "":
		return
	建筑点击计数[key] = 建筑点击计数.get(key, 0) + 1
	var 阈值: int = 建筑彩蛋阈值.get(key, 3)
	if 建筑点击计数[key] >= 阈值:
		建筑点击计数[key] = 0
		Game.触发点击彩蛋(egg_id)
		_toast("（异闻）%s" % Game._彩蛋配置(egg_id).get("name", ""))
		if 页控.get("纪事", null) != null and 页控["纪事"].visible:
			刷新纪事()

func _on_山门牌匾():
	Game.触发点击彩蛋("egg_click_shanmen")
	_toast("（异闻）山门旧事：宗门立基至今，已历 %d 载风雨。" % Game.累计游戏日)
	if 页控.get("纪事", null) != null and 页控["纪事"].visible:
		刷新纪事()

func _on_掌教点击彩蛋():
	掌教点击计数 += 1
	if 掌教点击计数 >= 10:
		掌教点击计数 = 0
		Game.触发点击彩蛋("egg_click_zhangjiao")
		_toast("（异闻）掌教自省")
		if 页控.get("纪事", null) != null and 页控["纪事"].visible:
			刷新纪事()

func _建筑总览_填充(列: VBoxContainer, 类别: String):
	for c in 列.get_children():
		c.queue_free()
	for key in 建筑类别.get(类别, []):
		列.add_child(_建筑块(key))

func _建筑总览_汇总栏() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _暗墨面板())
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	var 建筑数: int = Game.堂口列表.size()
	var 在岗: int = _在岗弟子数()
	var 产出: int = Game.预估月产出()
	var buff: Dictionary = Game.汇总负责人全局buff()
	var 经营: float = buff.get("产出", 0.0)
	var 修炼: float = buff.get("修炼", 0.0)
	var 经营文本: String = ("+%d%%" % int(经营 * 100)) if 经营 > 0 else "无"
	var 修炼文本: String = ("+%d%%" % int(修炼 * 100)) if 修炼 > 0 else "无"
	var l1 := Label.new()
	l1.text = "宗门建筑 %d 座 ｜ 在岗弟子 %d 人" % [建筑数, 在岗]
	l1.add_theme_font_size_override("font_size", 13)
	l1.add_theme_color_override("font_color", 暗金)
	var l2 := Label.new()
	l2.text = "预计月产出 %d 灵石" % 产出
	l2.add_theme_font_size_override("font_size", 14)
	l2.add_theme_color_override("font_color", 暗金)
	var l3 := Label.new()
	l3.text = "全局经营加成 %s ｜ 全局修炼加成 %s" % [经营文本, 修炼文本]
	l3.add_theme_font_size_override("font_size", 12)
	l3.add_theme_color_override("font_color", 暗金)
	vb.add_child(l1); vb.add_child(l2); vb.add_child(l3)
	return p

func _在岗弟子数() -> int:
	# 成员按堂口分区，互不重叠；此处按姓名去重计（≈ 全体弟子中已入堂者）
	var 集合: Dictionary = {}
	for key in Game.堂口列表.keys():
		for m in Game.堂口列表[key]["成员"]:
			var d: Disciple = m as Disciple
			集合[d.姓名] = true
	return 集合.size()

func _建筑卡片底色(类别: String) -> StyleBoxFlat:
	# 复用 造主题 面板形制（宣纸亮底/圆角/边宽），仅边框色按类别取现有色值常量
	var sb := StyleBoxFlat.new()
	sb.bg_color = 宣纸亮
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = 建筑类别色.get(类别, 暗金)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	return sb

func _建筑块(key: String) -> Control:
	var 堂: Dictionary = Game.堂口列表[key]
	var 块 := VBoxContainer.new()
	块.add_theme_constant_override("separation", 4)
	# 卡片：PanelContainer 包一层，按类别着辅助色边框
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _建筑卡片底色(建筑_类别反查.get(key, "战略")))
	var 内 := VBoxContainer.new()
	内.add_theme_constant_override("separation", 3)
	pc.add_child(内)
	块.add_child(pc)
	# 头部：大名称（金色修真标题字号，对齐 小标题）+ 职能标签（小字次要灰）
	var 头行 := HBoxContainer.new()
	var 头 := Label.new()
	头.text = 堂["名称"]
	头.add_theme_font_size_override("font_size", 17)
	头.add_theme_color_override("font_color", 暗金)
	头.mouse_filter = Control.MOUSE_FILTER_STOP
	头.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			建筑点击彩蛋(key)
	)
	头行.add_child(头)
	var 标签 := Label.new()
	标签.text = "  %s" % 建筑职能标签.get(key, "")
	标签.add_theme_font_size_override("font_size", 12)
	标签.add_theme_color_override("font_color", 次墨)
	头行.add_child(标签)
	内.add_child(头行)
	# 负责人行：负责人 XXX ＋ 锁图标（金色小锁）；经营加成 +X%；全局效果
	var 负责: Disciple = 堂["负责人"]
	var 负责名: String = "（空缺）" if 负责 == null else 负责.姓名
	var 锁定: bool = 堂.get("负责人锁定", false)
	var 负责行 := HBoxContainer.new()
	var 锁 := Label.new()
	锁.text = "🔒 " if 锁定 else ""
	锁.add_theme_font_size_override("font_size", 13)
	锁.add_theme_color_override("font_color", 暗金)
	负责行.add_child(锁)
	var 负责文本: String = "主事 %s" % 负责名
	if 负责 != null:
		负责文本 += "  经营加成 +%.0f" % 负责.加成评分(堂["加成维度"])
	负责行.add_child(_label(负责文本, 13, 墨黑))
	if 负责 != null and 建筑全局维度.has(key):
		var 维: String = 建筑全局维度[key]
		var 全局文本: String = "  全局效果：全宗%s +1%%" % 维度显示.get(维, 维)
		负责行.add_child(_label(全局文本, 12, 次墨))
	内.add_child(负责行)
	# 产出行：预计月产出 XX 灵石 ｜ 附带效果（从阶段2 被动逻辑读说明文字）
	var 产出行 := HBoxContainer.new()
	产出行.add_child(_label("预计月产出 %d 灵石" % Game.预估建筑产出(key), 13, 暗金))
	var 附带: String = 建筑附带效果(key)
	if 附带 != "":
		var 附带标签 := Label.new()
		附带标签.text = "  ｜ " + 附带
		附带标签.add_theme_font_size_override("font_size", 11)
		附带标签.add_theme_color_override("font_color", 次墨)
		附带标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		产出行.add_child(附带标签)
	内.add_child(产出行)
	# 成员折叠区（复用 琐事折叠 ▶/▼ 切换；默认折叠）
	var 成员: Array = 堂["成员"]
	var 折叠_container := VBoxContainer.new()
	var 折叠按钮 := Button.new()
	折叠按钮.text = "门人共 %d 人 ▸" % 成员.size()
	折叠按钮.add_theme_font_size_override("font_size", 12)
	折叠按钮.add_theme_color_override("font_color", 次墨)
	折叠_container.add_child(折叠按钮)
	var 成员列表 := VBoxContainer.new()
	成员列表.visible = false
	if 成员.is_empty():
		var 空 := Label.new(); 空.text = "  （暂无门人）"; 空.add_theme_font_size_override("font_size", 12); 空.add_theme_color_override("font_color", 次墨)
		成员列表.add_child(空)
	else:
		for m in 成员:
			var mm: Disciple = m as Disciple
			var 行 := HBoxContainer.new()
			var 名按钮 := Button.new(); 名按钮.text = mm.姓名; 名按钮.pressed.connect(_on_建筑成员_看详情.bind(mm))
			行.add_child(名按钮)
			var 任按钮 := Button.new()
			if 锁定:
				任按钮.text = "已锁定"; 任按钮.disabled = true
			else:
				任按钮.text = "任命"; 任按钮.pressed.connect(_on_任负责人.bind(key, mm))
			行.add_child(任按钮)
			成员列表.add_child(行)
	折叠_container.add_child(成员列表)
	var 已展开 := false
	折叠按钮.pressed.connect(func():
		已展开 = not 已展开
		成员列表.visible = 已展开
		折叠按钮.text = ("门人共 %d 人 ▾" if 已展开 else "门人共 %d 人 ▸") % 成员.size()
	)
	内.add_child(折叠_container)
	# 锁定/解锁 控制（复用 解除负责人锁定；锁定状态按钮文案变「解除锁定」）
	if 锁定:
		var 解锁按钮 := Button.new(); 解锁按钮.text = "解除锁定"; 解锁按钮.pressed.connect(_on_解除锁定.bind(key))
		内.add_child(解锁按钮)
	return 块

func _on_任负责人(key: String, m: Disciple):
	Game.任命负责人(key, m)
	详情.text = "已任命 %s 为%s主事。" % [m.姓名, Game.堂口列表[key]["名称"]]
	var 旧遮: Node = get_node_or_null("建筑总览")
	if 旧遮 != null:
		旧遮.queue_free()
		_建筑总览弹窗()

func _on_解除锁定(key: String):
	Game.解除负责人锁定(key)
	详情.text = "已解除%s主事锁定。" % Game.堂口列表[key]["名称"]
	var 旧遮: Node = get_node_or_null("建筑总览")
	if 旧遮 != null:
		旧遮.queue_free()
		_建筑总览弹窗()

func _on_建筑成员_看详情(d: Disciple):
	# 复用主界面弟子卡同款入口 _on_选弟子（写入底部详情栏）；关闭本弹窗以露出详情栏
	var 旧遮: Node = get_node_or_null("建筑总览")
	if 旧遮 != null:
		旧遮.queue_free()
	_on_选弟子(d)

func 建筑附带效果(key: String) -> String:
	# 说明文字从阶段2 建筑被动逻辑读取；dormant 标注「待实装」
	match key:
		"lingtian":
			return "灵草丰收概率+8%（当月灵石产出翻倍）"
		"kuangmai":
			return "富矿现世概率+7%（当月灵石产出翻倍）"
		"dantang":
			return "额外丹元概率+15%"
		"qitang":
			return "额外器魂概率+12%"
		"cangjing":
			return "悟道机缘概率+8% · 修炼速度+5%（常驻）"
		"tanwei":
			return "情报奇遇概率+10%（额外灵石） · 负面事件-5%（待实装）"
		"zhifa":
			return "负面事件-15%（待实装）"
		"gongxun":
			return "全局声望获取+10%（常驻）"
		"yuying":
			return "测灵高品质概率+2%（常驻） · 宗门声名远播则天资弟子慕名来投 · 外门弟子于此修习入门吐纳法、夯实道基（道基培育）"
		"yushou":
			return "御兽相助概率+10%（战斗）"
		"zhenfa":
			return "防御增益+1%（常驻） · 入侵事件-12%（待实装）"
		"xichi":
			return "重铸命格/性格/道心（无数值被动）"
	return ""

func _label(文本: String, 大小: int, 颜色: Color) -> Label:
	var l := Label.new()
	l.text = 文本
	l.add_theme_font_size_override("font_size", 大小)
	l.add_theme_color_override("font_color", 颜色)
	return l

# ============ 主题与组件助手 ============
func 造主题() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	# 面板：宣纸底 + 暗金细边（卷轴形制近似）
	var p := StyleBoxFlat.new()
	p.bg_color = 宣纸亮
	p.set_corner_radius_all(8)
	p.set_border_width_all(1)
	p.border_color = 暗金
	p.content_margin_left = 10; p.content_margin_right = 10
	p.content_margin_top = 8; p.content_margin_bottom = 8
	t.set_stylebox("panel", "PanelContainer", p)
	# 按钮：宣纸底 + 木框 + 暗金字
	var b := StyleBoxFlat.new()
	b.bg_color = 宣纸
	b.set_corner_radius_all(6)
	b.set_border_width_all(1)
	b.border_color = 木色
	b.content_margin_left = 10; b.content_margin_right = 10
	b.content_margin_top = 6; b.content_margin_bottom = 6
	t.set_stylebox("normal", "Button", b)
	var bh: StyleBoxFlat = b.duplicate(); bh.bg_color = Color(0.82, 0.75, 0.62); t.set_stylebox("hover", "Button", bh)
	var bp: StyleBoxFlat = b.duplicate(); bp.bg_color = 暗金; bp.border_color = 暗金; t.set_stylebox("pressed", "Button", bp)
	# 文字色：墨黑正文 + 暗金按钮字
	t.set_color("font_color", "Label", 墨黑)
	t.set_color("font_color", "Button", 暗金)
	return t

# 深墨半透明面板（状态栏专用，呼应"深墨色半透明基底 + 暗金数值"）
func _暗墨面板() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.11, 0.10, 0.92)
	s.set_corner_radius_all(8)
	s.set_border_width_all(1)
	s.border_color = 暗金
	s.content_margin_left = 10; s.content_margin_right = 10; s.content_margin_top = 8; s.content_margin_bottom = 8
	return s

# 弹出物品/装备完整详情（通用复用弹窗）
func _弹出物品详情(物品: Item):
	if 物品 == null:
		_toast("（暂无详情）")
		return
	var 名: String = 物品.名称
	if 名 == "":
		名 = "未知物品"
	var 色: Color = get_rarity_color(物品.品阶)
	var 弹: Dictionary = _new_detail_popup(名, 色)
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, mini(340, int(get_viewport_rect().size.y * 0.7)))
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	弹["内容"].add_child(滚)
	var 信息 := Label.new()
	信息.text = 物品.简介()
	滚.add_child(信息)
	if 物品.描述 != "":
		var 描述行 := Label.new()
		描述行.text = "\n📖 %s" % 物品.描述
		描述行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		描述行.add_theme_color_override("font_color", 次墨)
		滚.add_child(描述行)
	弹["内容"].add_child(弹["关"])

# ===== S1 预埋：统一详情分发入口（S0 不调用；S1 全场景复用，零返工） =====
# 类型 → 实体解析占位：S1 接入 ItemManager.get_item_data / Game.取弟子(id) 后填实。
func _解析实体(_type: String, _id: String) -> Variant:
	# S1 打通点击联动 MVP：按项目真实结构解析三类已有实体。
	# 设计铁律：解析失败一律返回 null，由 open_detail 的 toast 降级兜底（不崩、不报错）。
	match _type:
		"disciple":
			for d in Game.弟子列表:
				if d is Disciple and d.姓名 == _id:
					return d
		"item", "equip":
			var 定义: Variant = Game._物品定义表.get(_id)
			if 定义 is Array and (定义 as Array).size() >= 2:
				var 参: Array = 定义 as Array
				return Game._造低阶物品(参[0], 参[1])
		_:
			pass
	# 仅调试版本告警（开发期快速定位无效ID），正式发布不输出，玩家无感知
	if OS.is_debug_build():
		push_warning("详情实体解析缺失（S1）：type=%s id=%s" % [_type, _id])
	return null

# 类型+ID 统一分发（S1 富文本/图标点击直接调用此函数，调用方无需关心渲染细节）
func open_detail(type: String, id: String) -> void:
	match type:
		"item", "equip":
			var it: Variant = _解析实体(type, id)
			if it is Item:
				_弹出物品详情(it)
			else:
				_toast("（暂无详情）")
		"disciple":
			var dp: Variant = _解析实体(type, id)
			if dp is Disciple:
				_弹出弟子属性弹窗("弟子", dp.简介(), dp)
			else:
				_toast("（暂无详情）")
		_:
			_toast("（暂无详情）")

# S1 预埋：从富文本 url 解析并打开详情（战斗日志/奇遇文本/任务描述点击直接复用）
func open_detail_by_url(url_str: String) -> void:
	var parts: Array = url_str.split(":", false, 1)
	if parts.size() == 2:
		open_detail(parts[0], parts[1])

func 小标题(文本: String, 大小 := 16) -> Label:
	var l := Label.new()
	l.text = 文本
	l.add_theme_font_size_override("font_size", 大小)
	l.add_theme_color_override("font_color", 暗金)
	l.add_theme_constant_override("margin_bottom", 4)
	return l

# 返回一个带标题的 PanelContainer；内容添加到其首个子（VBoxContainer）
func 新面板(标题文本: String) -> PanelContainer:
	var pc := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_child(vb)
	if 标题文本 != "":
		vb.add_child(小标题(标题文本))
	return pc

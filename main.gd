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
const BattleCalculator = preload("res://BattleCalculator.gd")
const SkillCultivationLoader = preload("res://SkillCultivationLoader.gd")

# 主题色（写实修仙 v2.0 锁定调色板：青黛/宣纸米白/墨青/暗金/朱砂红/玉石绿）
const 宣纸 := Color(0.957, 0.937, 0.890)   # v2.0 宣纸米白（基底）
const 宣纸亮 := Color(0.965, 0.949, 0.918) # 面板纸（略亮）
const 墨黑 := Color(0.118, 0.169, 0.157)   # v2.0 墨青（正文墨字）
const 次墨 := Color(0.42, 0.37, 0.31)      # 次级文字
const 暗金 := Color(0.784, 0.659, 0.416)   # v2.0 暗金（高亮/描边）
const 青灰 := Color(0.40, 0.48, 0.47)      # 青灰次强调
const 木色 := Color(0.46, 0.36, 0.26)      # 木框
const 墨底 := Color(0.12, 0.11, 0.10)      # 深墨（弹窗遮罩/状态栏）
# v2.0 新增强调色
const 青黛 := Color(0.431, 0.561, 0.533)   # 青黛主调
const 玉石绿 := Color(0.561, 0.749, 0.624) # 玉石绿
const 朱砂 := Color(0.702, 0.259, 0.239)   # 朱砂红（危险/道阶）
const 青玉 := Color(0.561, 0.749, 0.624)   # 按钮底色（同玉石绿）
const 青玉亮 := Color(0.66, 0.82, 0.70)    # 按钮悬停亮色
const 墨底半透 := Color(0.118, 0.169, 0.157, 0.92) # 墨青半透（弹窗/遮罩）
const 面板底 := Color(0.133, 0.216, 0.204, 0.92)   # 暗青玉面板底（参考图主面板色，保证文字清晰）
const 按钮木 := Color(0.541, 0.404, 0.259)         # 暖木棕（主按钮常态）
const 按钮木悬 := Color(0.69, 0.52, 0.337)         # 暖木棕悬停提亮
const 按钮金按 := Color(0.502, 0.38, 0.20)         # 棕金按下态
const 按钮禁用 := Color(0.32, 0.30, 0.28)          # 灰褐禁用
# ---- 四类按钮精确 hex 常量 (UI 整改三收尾补丁, 终裁 7.1.1 / 绘图强制规范 3.2) ----
# 命名 BTN_主/次/标签/危险; 值严格锁死, 禁止在别处散写裸色或裸 Color(...)
const BTN_主底 := Color(0.173, 0.373, 0.322)   # 深青玉 2C5F52 (主按钮底)
const BTN_主边 := Color(0.722, 0.608, 0.353)   # 暗金 B89B5A (主按钮边)
const BTN_主字 := Color(0.941, 0.902, 0.824)   # 米白金 F0E6D2 (主按钮字)
const BTN_次底 := Color(0.290, 0.231, 0.165)   # 深原木 4A3B2A (次按钮底)
const BTN_次边 := Color(0.243, 0.420, 0.369)   # 暗青 3E6B5E (次按钮边)
const BTN_次字 := Color(0.910, 0.863, 0.784)   # 浅米黄 E8DCC8 (次按钮字)
const BTN_标签底 := Color(0.227, 0.435, 0.376, 0.502)  # 半透青玉 3A6F6080 (标签底)
const BTN_标签边 := Color(0.353, 0.545, 0.490)  # 5A8B7D (标签边)
const BTN_标签字 := Color(0.831, 0.898, 0.871)  # 青玉亮 D4E5DE (标签字)
const BTN_危险底 := Color(0.361, 0.200, 0.200)  # 暗红棕 5C3333 (危险底)
const BTN_危险边 := Color(0.545, 0.353, 0.353)  # 8B5A5A (危险边)
const BTN_危险字 := Color(0.910, 0.784, 0.784)  # E8C8C8 (危险字)
const 启用皮肤纹理: bool = false           # 一键回退：false→纯扁平 v2.0 风（不挂载 AI 方向稿纹理）

# ── UI 整改「三」参数层收敛（§2.2 背景 / §3.1·§3.4 字号 / §3.5 裸色转正）──
# 背景两层（§2.2）：远景 modulate alpha + 暗叠层颜色/alpha，统一收口
const BG_SCENE_ALPHA: float = 0.30
const BG_OVERLAY_COLOR: Color = Color(0.086, 0.133, 0.114)
const BG_OVERLAY_ALPHA: float = 0.50
# 字号唯一集合（§3.1·§3.4）：{22,17,18,16,15,13}，禁 <15、禁新增档
const FONT_TITLE: int = 22
const FONT_PANEL: int = 17
const FONT_PANEL_B: int = 18
const FONT_SUB: int = 16
const FONT_BODY: int = 15
const FONT_AUX: int = 13
# 评级色（§3.5，原 _评级色 裸 Color 收口）
const 评级_红 := Color(0.85, 0.15, 0.15)
const 评级_橙 := Color(0.85, 0.55, 0.1)
const 评级_绿 := Color(0.2, 0.6, 0.3)
const 评级_灰 := Color(0.45, 0.45, 0.55)
const 评级_默认 := Color(0.5, 0.3, 0.3)
# 奇遇角标色（§3.5，原 _奇遇弹窗 裸 Color 收口）
const 奇遇_灰 := Color(0.60, 0.63, 0.67)
const 奇遇_蓝 := Color(0.23, 0.51, 0.96)
const 奇遇_紫 := Color(0.55, 0.36, 0.96)
const 奇遇_金 := Color(0.96, 0.62, 0.04)
# 弹窗遮罩（§3.5，原内联 Color(0.10,0.09,0.08,0.55/0.60) 收口；alpha 归一 0.60）
const 弹窗遮罩 := Color(0.10, 0.09, 0.08, 0.60)
# 暗化叠层（§3.5，引导/收尾，原 Color(0.06,0.06,0.08,X) 收口）
const 暗化 := Color(0.06, 0.06, 0.08)
# 墨青底（§3.5，引导气泡/收尾气泡，原 Color(0.118,0.169,0.157,0.96) 收口）
const 墨青 := Color(0.118, 0.169, 0.157, 0.96)
# 战斗结算标题底（§3.5，原 Color(0.22,0.21,0.20,1.0) 收口）
const 标题底色 := Color(0.22, 0.21, 0.20, 1.0)
# 展开钮灰（§3.5，原 Color(0.68,0.68,0.68) 收口）
const 展开灰 := Color(0.68, 0.68, 0.68)
# Toast 底/边（§3.5，原内联收口）
const 弹窗底色 := Color(0.12, 0.11, 0.10, 0.92)
const 弹窗边色 := Color(0.72, 0.58, 0.20, 0.9)
# 通用强调亮灰 / 置灰（§3.5，原动画/禁用态裸 Color 收口）
const 强调亮灰 := Color(0.9, 0.9, 0.9)
const 置灰色 := Color(0.55, 0.52, 0.48)
# 皮肤纹理调制白（§3.5，_皮肤纹理装填 StyleBoxTexture modulate）
const 纹理白 := Color(1, 1, 1, 0.97)

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
var 纪事筛选分类: String = "全部"   # 纪事界面分类筛选（全部/宗门大事件/宗门岁纪/日常庶务/异闻）

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
var _详情回收站: Node = null
var _当前详情遮: Control = null            # 详情弹窗单实例守卫：开新窗前先释放旧窗，防快速连点层叠
var 御兽区: VBoxContainer
var 纪事区: VBoxContainer
var 当前选中: Disciple = null
var 装备面板节点: Control = null   # A5 装备面板当前实例，重建前先释放避免叠加
var 法阵面板节点: Control = null   # S1 批6-B 法阵面板当前实例，重建前先释放避免叠加
var 历练滚动列: VBoxContainer = null  # 历练关卡列表（战斗胜利后需刷新）
# 新手引导系统（A 包：单线性五步，纯灰模）：阶段 0序章/1-5五步/6完成（Game.引导阶段 为事实源）
var 引导_建筑按钮: Button = null
var 引导_招收按钮: Button = null
var 引导_历练按钮: Button = null
var 引导_层: Control = null          # 引导覆盖层（暗化+高亮框+气泡），最后 add_child 置顶，mouse_filter 穿透
var 引导_跳过按钮: Button = null     # 右上角常驻「跳过引导」，阶段<5 时可见
var 引导_开场段: int = 0             # 开场叙事当前段序号
var _引导已收尾: bool = false         # 收尾弹窗一次性标记（播完不再重复）
var _坊市提示: String = ""
var _任务提示: String = ""
# Step 2 奇遇基础调度：signal 入队、逐个弹窗，避免推演期多奇遇堆叠
var 奇遇队列: Array = []
var 奇遇弹窗中: bool = false
const 页名 := ["宗门", "弟子", "御兽", "历练", "纪事"]

# S0 FTUE 引导（五步）相关实例引用与状态（逻辑独立封装，不侵入业务）
var 引导_状态面板: PanelContainer = null
var 引导_推演按钮: Button = null
var 引导_坊市按钮: Button = null
var 引导_任务按钮: Button = null
var 标签栏: TabBar = null
var _导航切换中 := false   # 防递归守卫：设 current_tab 会经 tab_changed 重入本函数，需阻断
var 引导_目标条: PanelContainer = null
var 引导_目标条_文: Label = null
var 引导_弟子提示: Label = null
var 引导_标题层: Control = null
var _首推演已保底: bool = false
var _招徒后_弟子高亮中: bool = false
var _弟子详情_已自动展开: bool = false
var _灰锁原文本: Dictionary = {}
# 整页切换架构（UI整改「三」第二批）
var 内容区: Control = null            # 固定内容区锚点（顶栏下/底栏上），承载当前页容器
var 当前页容器: ScrollContainer = null  # 当前整页根（ScrollContainer+VBox），切换时 queue_free
var 当前页名: String = ""              # 当前核心 Tab 名（用于刷新/引导判定）
var 当前页持久节点: Array = []          # 当前页持有的持久 VBox（切换前先卸下，避免被 queue_free 误杀）
var _二级页: String = ""                # 当前二级页名（""=核心页；非空前主导航仍高亮宗门）
var _弟子二级tab: int = 0               # 弟子页二级 Tab：0=名录 / 1=接引（跨切换保留）
var 调试图标: Button = null             # 顶栏角落：推演中心（Debug 可见）
var 设置图标: Button = null             # 顶栏角落：设置（存读/新游戏）
var _宗门网格入口: Dictionary = {}      # 名 -> 快捷入口按钮（灰锁用）
var 任务列: VBoxContainer = null        # 任务二级页列表列（刷新用）

func _ready():
	theme = 造主题()

	# 写实宗门背景：独立 CanvasLayer(layer=-1) 承载，置于所有 UI 之下，避免被 UI 重排影响
	var 背景层 := CanvasLayer.new()
	背景层.layer = -1
	add_child(背景层)
	# 墨底兜底：防止 TextureRect 因 anchors 生效时机或图片比例出现未覆盖区域时透底
	var 背景底 := ColorRect.new()
	背景底.color = 墨底
	背景底.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	背景底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	背景层.add_child(背景底)
	var 景 := TextureRect.new()
	if ResourceLoader.exists("res://assets/ai_art/2026-07-22/仙山宗门远景_云雾半透明_古建木石_青黛色调_低饱和度_水墨_2026-07-22T15-19-56.png"):
		景.texture = load("res://assets/ai_art/2026-07-22/仙山宗门远景_云雾半透明_古建木石_青黛色调_低饱和度_水墨_2026-07-22T15-19-56.png")
	景.set_stretch_mode(TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	景.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	景.modulate = Color(1, 1, 1, BG_SCENE_ALPHA)
	景.mouse_filter = Control.MOUSE_FILTER_IGNORE
	背景层.add_child(景)
	var 暗罩 := ColorRect.new()
	暗罩.color = Color(BG_OVERLAY_COLOR.r, BG_OVERLAY_COLOR.g, BG_OVERLAY_COLOR.b, BG_OVERLAY_ALPHA)
	暗罩.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	暗罩.mouse_filter = Control.MOUSE_FILTER_IGNORE
	背景层.add_child(暗罩)

	# 主垂直布局：占满目标条以下、屏幕底部边距区域
	var 主布局 := VBoxContainer.new()
	主布局.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	主布局.offset_top = 48    # 顶部预留 48px 给常驻目标条（§5.1）
	主布局.offset_left = 8
	主布局.offset_right = -8
	主布局.offset_bottom = -8
	主布局.add_theme_constant_override("separation", 6)
	add_child(主布局)

	# 顶栏（固定，不随页面切换销毁）：掌教标题 + 状态带 + 角落图标
	var 顶栏 := VBoxContainer.new()
	顶栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	顶栏.add_theme_constant_override("separation", 4)
	主布局.add_child(顶栏)

	# 内容区锚点（固定）：顶栏下、底栏上，承载当前整页容器
	内容区 = VBoxContainer.new()
	内容区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	内容区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	内容区.mouse_filter = Control.MOUSE_FILTER_IGNORE
	主布局.add_child(内容区)

	# 底部固定栏：TabBar + 详情面板（不再随中部内容滚动）
	var 底部区 := VBoxContainer.new()
	底部区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	底部区.custom_minimum_size = Vector2(0, 180)
	主布局.add_child(底部区)

	# 顶栏：掌教标题 + 别名 + 状态带（固定不滚动）
	var 掌教标题 := Button.new()
	掌教标题.text = "《太玄宗门录》· 掌教治宗"
	掌教标题.flat = true
	掌教标题.add_theme_font_size_override("font_size", FONT_PANEL_B)
	掌教标题.add_theme_color_override("font_color", 暗金)
	掌教标题.pressed.connect(_on_掌教点击彩蛋)
	顶栏.add_child(掌教标题)
	var 别名 := Label.new()
	别名.text = "又名：开局接手太玄宗"
	别名.add_theme_font_size_override("font_size", FONT_AUX)
	别名.add_theme_color_override("font_color", 宣纸亮)
	顶栏.add_child(别名)
	状态栏 = Label.new()
	状态栏.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	状态栏.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 让点击穿透到状态面板，供引导步骤①Hook
	var 状态面板: PanelContainer = 新面板("")
	状态面板.get_child(0).add_child(状态栏)
	状态面板.add_theme_stylebox_override("panel", _暗墨面板())
	状态栏.add_theme_color_override("font_color", 暗金)
	顶栏.add_child(状态面板)
	引导_状态面板 = 状态面板

	# 顶栏角落图标：设置（存读/新游戏，常驻）+ 调试（推演中心，Debug 可见）
	var 顶栏角 := HBoxContainer.new()
	顶栏角.alignment = BoxContainer.ALIGNMENT_END
	顶栏角.add_theme_constant_override("separation", 6)
	顶栏.add_child(顶栏角)
	设置图标 = Button.new(); 设置图标.text = "⚙"
	设置图标.tooltip_text = "设置（存读 / 新游戏）"
	设置图标.pressed.connect(_弹_设置)
	顶栏角.add_child(设置图标)
	if OS.is_debug_build():
		调试图标 = Button.new(); 调试图标.text = "🐞"
		调试图标.tooltip_text = "推演中心（调试）"
		调试图标.pressed.connect(_弹_推演中心)
		顶栏角.add_child(调试图标)
		引导_推演按钮 = 调试图标

	# 离山汇总（离线收益简报）：建为独立弹窗，不内联首页（§1.2 B3）
	离山面板 = 新面板("✦ 离山汇总（你离开期间）")
	var 离山根: VBoxContainer = 离山面板.get_child(0)
	离山内容区 = VBoxContainer.new()
	离山内容区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	离山内容区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	离山根.add_child(离山内容区)
	离山面板.custom_minimum_size = Vector2(0, 140)
	离山面板.gui_input.connect(_on_离山面板_点击)
	var 离山关 := Button.new(); 离山关.text = "归藏"; 离山关.custom_minimum_size = Vector2(0, 44)
	离山关.pressed.connect(_关_离山简报)
	离山根.add_child(离山关)
	# 战报 Label 保留作兼容降级显示（旧存档/无结构化数据时用）
	战报 = Label.new()
	战报.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	战报.visible = false   # 默认隐藏，新UI优先

	# 底部主导航：复用 标签栏(TabBar)，5 核心 Tab 常驻、跨页不释放（§1.4）
	var tb := TabBar.new()
	for n in 页名:
		tb.add_tab(n)
	tb.tab_changed.connect(_on_主导航切换)
	底部区.add_child(tb)
	标签栏 = tb
	标签栏.custom_minimum_size = Vector2(0, 56)  # 底部主导航 tab 触摸高度>=44 (§1 ⑩ ACCESSIBILITY Standard)

	# 持久内容 VBox（跨页不销毁，仅随整页切换重挂载/卸载；刷新逻辑直接复用）
	列表 = VBoxContainer.new(); 列表.add_theme_constant_override("separation", 6); 列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL; 列表.size_flags_vertical = Control.SIZE_EXPAND_FILL
	抉择区 = VBoxContainer.new(); 抉择区.add_theme_constant_override("separation", 6); 抉择区.size_flags_horizontal = Control.SIZE_EXPAND_FILL; 抉择区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	御兽区 = VBoxContainer.new(); 御兽区.add_theme_constant_override("separation", 4); 御兽区.size_flags_horizontal = Control.SIZE_EXPAND_FILL; 御兽区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	纪事区 = VBoxContainer.new(); 纪事区.add_theme_constant_override("separation", 4); 纪事区.size_flags_horizontal = Control.SIZE_EXPAND_FILL; 纪事区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 弟子页头（总战力+排序+提示）持久，跨切换保留
	_建_弟子页头()

	# 弟子页头由 _建_弟子页头() 持久构建（见下方整页切换区块）

	# 详情面板（底部常驻，固定不滚动）
	详情 = Label.new()
	详情.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var 详情面板: PanelContainer = 新面板("🔍 详情")
	详情面板.custom_minimum_size = Vector2(0, 110)
	详情面板.get_child(0).add_child(详情)
	底部区.add_child(详情面板)

	Game.弟子变动.connect(刷新, CONNECT_DEFERRED)   # 延后到 idle 帧执行：避免招徒等 pressed 回调内同步刷新重建当前页→释放发射者节点崩溃
	Game.新手目标更新.connect(_刷新_新手UI, CONNECT_DEFERRED)   # P0 目标链：玉牌/Tab 红点/跳字刷新   # 延后到 idle 帧执行：避免招徒等 pressed 回调内同步刷新重建当前页→释放发射者节点崩溃
	Game.战报更新.connect(_on_战报)
	Game.奇遇发生.connect(_on_奇遇发生)   # Step 2：奇遇三场景触发后展示调度
	# 引导步骤①的点击 Hook：点状态栏→资源（离山面板 Hook 在离山面板创建处绑定）
	引导_状态面板.gui_input.connect(_on_状态面板_点击)

	# 构建默认首页（宗门），整页切换机制启动
	_on_主导航切换(0)

	# 标题屏拦截：自动推演延后到标题屏关闭（点或继续）之后，避免新档一开机空推一天
	_显示标题()

func _on_主导航切换(i: int):
	if _导航切换中:
		return   # 重入（current_tab 赋值触发的 tab_changed 再入本函数）：直接忽略，阻断无限递归卡死
	_导航切换中 = true
	var 名: String = 页名[i]
	标签栏.current_tab = i   # 手动/程序切页时同步视觉 tab（已加重入守卫，不会经 tab_changed 递归）
	_二级页 = ""
	_卸下当前页()
	match 名:
		"宗门": _建_宗门页()
		"弟子": _建_弟子页()
		"御兽": _建_御兽页()
		"历练": _建_历练页()
		"纪事": _建_纪事页()
	当前页名 = 名
	if 名 == "弟子" and Game.引导阶段 == 4:
		_自动展开首弟子()   # 首进弟子页自动展开首名弟子详情（不自动完成步④）
	_导航切换中 = false

func _卸下当前页():
	if 当前页容器 == null:
		return
	for n in 当前页持久节点:
		if is_instance_valid(n) and n.get_parent() != null:
			n.get_parent().remove_child(n)
	当前页容器.queue_free()
	当前页容器 = null
	当前页持久节点.clear()
	# 页面被释放后，其上的按钮引用也随之失效；清空引用池避免 dangling freed ref
	_宗门网格入口.clear()
	引导_坊市按钮 = null
	引导_任务按钮 = null
	引导_招收按钮 = null

func _新页容器() -> ScrollContainer:
	var 页 := ScrollContainer.new()
	页.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	页.size_flags_vertical = Control.SIZE_EXPAND_FILL
	页.custom_minimum_size = Vector2(0, 560)
	var 内容 := VBoxContainer.new()
	内容.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	内容.size_flags_vertical = Control.SIZE_EXPAND_FILL
	内容.add_theme_constant_override("separation", 6)
	页.add_child(内容)
	内容区.add_child(页)
	当前页容器 = 页
	return 页

func _建_宗门页():
	var 页: ScrollContainer = _新页容器()
	var 内容: Control = 页.get_child(0)
	# W3 宗门全景概要（简洁卡片，非明细列表）
	内容.add_child(_宗门全景卡())
	内容.add_child(_宗门香火面板())
	内容.add_child(_宗门谱系面板())
	内容.add_child(_宗门路线面板())   # S1 批5-C：正邪路线抉择面板（挂宗门页，不新开 Tab）
	内容.add_child(_建_玉牌())
	内容.add_child(_品级权益总览面板())   # WAVE-B #4：当前品级权益总览（读 门派等级→映射品级权益；复用本页，不新增按钮）
	# W4 快捷入口网格（受控，禁止滚动按钮墙）
	var 网格 := GridContainer.new()
	网格.columns = 3
	网格.add_theme_constant_override("h_separation", 8)
	网格.add_theme_constant_override("v_separation", 8)
	内容.add_child(网格)
	_宗门网格入口.clear()
	var 入口: Array = ["洞府", "修炼", "建筑", "坊市", "任务", "账册"]
	for 名 in 入口:
		var 钮 := Button.new()
		钮.text = 名
		钮.custom_minimum_size = Vector2(0, 56)
		钮.pressed.connect(_进_二级页.bind(名))
		网格.add_child(钮)
		_宗门网格入口[名] = 钮
	# 灰锁（坊市/任务 受锁：disabled+🔒+tooltip，点击不跳转）
	引导_坊市按钮 = _宗门网格入口.get("坊市", null)
	引导_任务按钮 = _宗门网格入口.get("任务", null)
	_刷新功能解锁()
	当前页持久节点 = []

func _宗门全景卡() -> PanelContainer:
	var 卡: PanelContainer = 新面板("—— 宗门全景 ——")
	卡.add_theme_stylebox_override("panel", _暗墨面板())
	var 文: VBoxContainer = 卡.get_child(0)
	var 行 := Label.new()
	行.text = "门派 Lv%d · 声望 %d · 繁荣 %d" % [Game.门派等级, Game.声望, Game.繁荣]
	行.add_theme_color_override("font_color", 暗金)
	文.add_child(行)
	var 行二 := Label.new()
	行二.text = "灵石 %d｜灵草 %d｜矿石 %d｜灵气 %d｜贡献 %d" % [Game.灵石, Game.灵草, Game.矿石, Game.灵气, Game.贡献点]
	行二.add_theme_color_override("font_color", 次墨)
	文.add_child(行二)
	var 行三 := Label.new()
	行三.text = "弟子 %d 人｜气力 %d/%d｜%s" % [Game.弟子列表.size(), Game.体力, Game.体力上限(), Game.时间文本()]
	行三.add_theme_color_override("font_color", 次墨)
	文.add_child(行三)
	# W3 资源产出概览（核心经营数据，引用既有 预估月产出 / 在岗弟子数，不新增字段）
	var 行四 := Label.new()
	行四.text = "月产出 +%d 灵石｜在岗弟子 %d 人" % [Game.预估月产出(), _在岗弟子数()]
	行四.add_theme_color_override("font_color", 玉石绿)
	文.add_child(行四)
	return 卡

# === S1 批5-A：宗门页香火面板（纯展示 · 数值 [PLACEHOLDER] 待真机校准）===
func _宗门香火面板() -> PanelContainer:
	var 卡: PanelContainer = 新面板("—— 宗门香火 ——")
	卡.add_theme_stylebox_override("panel", _暗墨面板())
	var 文: VBoxContainer = 卡.get_child(0)
	var 行一 := Label.new()
	行一.text = "香火值 %d ｜ 信徒 %d 人" % [Game.香火值, Game.信徒数]
	行一.add_theme_color_override("font_color", 次墨)
	行一.add_theme_font_size_override("font_size", FONT_BODY)
	文.add_child(行一)
	var 行二 := Label.new()
	行二.text = "凡世城镇 %d 座 ｜ 月产预估 +%d" % [Game.凡人城镇.size(), Game.香火月产预估]
	行二.add_theme_color_override("font_color", 次墨)
	行二.add_theme_font_size_override("font_size", FONT_BODY)
	文.add_child(行二)
	var 档 := Label.new()
	档.text = "信徒增益档：%s" % Game.信徒增益档
	档.add_theme_color_override("font_color", 玉石绿)
	档.add_theme_font_size_override("font_size", FONT_BODY)
	文.add_child(档)
	# 「凡世」入口钮（BTN_主 风格）；现有二级页机制无"凡世"分支，本批仅标端口，待实装
	var 钮 := Button.new()
	钮.text = "凡世 · 城镇经营"
	钮.custom_minimum_size = Vector2(0, 44)
	钮.add_theme_stylebox_override("normal", _主按钮样式())
	钮.add_theme_color_override("font_color", BTN_主字)
	钮.pressed.connect(_toast.bind("凡世交互待实装"))
	文.add_child(钮)
	return 卡

# === S1 批5-B：宗门页谱系 / 辈分礼制面板（纯展示 · 门规三档切换；数值 [PLACEHOLDER]）===
func _宗门谱系面板() -> PanelContainer:
	var 卡: PanelContainer = 新面板("—— 宗门谱系 · 辈分礼制 ——")
	卡.add_theme_stylebox_override("panel", _暗墨面板())
	var 文: VBoxContainer = 卡.get_child(0)
	# 字派序列（开山第1字=索引0）；手工循环拼接，避免依赖 String.join 在 Godot 4 的语义不确定性
	var 派 := Label.new()
	var 派文本: String = ""
	if not Game.辈分字派.is_empty():
		for k in range(Game.辈分字派.size()):
			派文本 += Game.辈分字派[k]
			if k < Game.辈分字派.size() - 1:
				派文本 += "·"
	else:
		派文本 = "（未定）"
	派.text = "字派：" + 派文本
	派.add_theme_color_override("font_color", 次墨)
	派.add_theme_font_size_override("font_size", FONT_BODY)
	文.add_child(派)
	# 门规严格度三档切换钮（BTN_标签 风格；当前档高亮暗金）
	var 规标 := Label.new()
	规标.text = "门规严格度（数值影响 [PLACEHOLDER]）"
	规标.add_theme_color_override("font_color", 次墨)
	规标.add_theme_font_size_override("font_size", FONT_BODY)
	文.add_child(规标)
	var 档行 := HBoxContainer.new()
	档行.add_theme_constant_override("separation", 8)
	var 档: Array[String] = ["宽松", "中庸", "严格"]
	for 名 in 档:
		var 钮 := Button.new()
		钮.text = 名
		钮.custom_minimum_size = Vector2(0, 40)
		钮.add_theme_stylebox_override("normal", _标签按钮样式())
		钮.add_theme_color_override("font_color", BTN_标签字)
		if Game.门规严格度 == 名:
			钮.add_theme_color_override("font_color", 暗金)
		钮.pressed.connect(_设门规_S1.bind(名))
		档行.add_child(钮)
	文.add_child(档行)
	return 卡

func _设门规_S1(档名: String) -> void:
	Game.门规严格度 = 档名
	_toast("门规已设为：%s" % 档名)

# === S1 批5-C：正邪路线抉择面板 + 二次确认流程（不可逆核心 · 纯 UI 层）===
# 颜色铁律（pre_f5 18）：玄门正道→暗金、逍遥中立→青玉、九幽邪道→朱砂；禁用紫色 / 裸 hex。

func _宗门路线面板() -> PanelContainer:
	var 卡: PanelContainer = 新面板("—— 宗门道统 · 正邪路线 ——")
	卡.add_theme_stylebox_override("panel", _暗墨面板())
	var 文: VBoxContainer = 卡.get_child(0)
	if Game.正邪路线 != "":
		# 已立誓：显当前路线徽记 + 不可重选
		var 徽 := Label.new()
		var 色: Color = 暗金
		if Game.正邪路线 == "玄门正道":
			色 = 暗金
		elif Game.正邪路线 == "逍遥中立":
			色 = 青玉
		else:
			色 = 朱砂
		徽.text = "道统：" + Game.正邪路线
		徽.add_theme_color_override("font_color", 色)
		徽.add_theme_font_size_override("font_size", FONT_PANEL_B)
		文.add_child(徽)
		var 注 := Label.new()
		注.text = "道统既定，终身不改"
		注.add_theme_color_override("font_color", 次墨)
		注.add_theme_font_size_override("font_size", FONT_BODY)
		文.add_child(注)
		return 卡
	if not Game._检查正邪解锁_S1():
		# 未达双条件：灰态提示，无入口
		var 锁 := Label.new()
		锁.text = "门派 Lv.3 且 七载大考后解锁"
		锁.add_theme_color_override("font_color", 次墨)
		锁.add_theme_font_size_override("font_size", FONT_BODY)
		锁.modulate.a = 0.5
		文.add_child(锁)
		return 卡
	# 已达双条件且未选：显「立定道统」入口钮（BTN_主 风格）
	var 钮 := Button.new()
	钮.text = "立定道统 · 抉择路线"
	钮.custom_minimum_size = Vector2(0, 44)
	钮.add_theme_stylebox_override("normal", _主按钮样式())
	钮.add_theme_color_override("font_color", BTN_主字)
	钮.pressed.connect(_打开正邪抉择)
	文.add_child(钮)
	return 卡

func _打开正邪抉择() -> void:
	# 三重保险：已选 / 未达双条件 直接返回（防误触）
	if Game.正邪路线 != "" or not Game._检查正邪解锁_S1():
		return
	var 弹: Dictionary = _new_detail_popup("立定道统 · 不可逆", 朱砂)
	var 盒: VBoxContainer = 弹["内容"]
	var 示 := Label.new()
	示.text = "道统选定，终身不可逆。请择一而从："
	示.add_theme_color_override("font_color", 次墨)
	示.add_theme_font_size_override("font_size", FONT_BODY)
	盒.add_child(示)
	var 路线: Array = ["玄门正道", "逍遥中立", "九幽邪道"]
	var 定位: Dictionary = {
		"玄门正道": "堂堂正正，声望经营",
		"逍遥中立": "自在随性，左右逢源",
		"九幽邪道": "狠厉果决，强取豪夺",
	}
	for 名 in 路线:
		var 行 := HBoxContainer.new()
		行.add_theme_constant_override("separation", 8)
		var 标 := Label.new()
		var 色: Color = 暗金
		if 名 == "玄门正道":
			色 = 暗金
		elif 名 == "逍遥中立":
			色 = 青玉
		else:
			色 = 朱砂
		标.text = 名 + "：" + 定位.get(名, "")
		标.add_theme_color_override("font_color", 色)
		标.add_theme_font_size_override("font_size", FONT_BODY)
		行.add_child(标)
		var 选 := Button.new()
		选.text = "择此道"
		选.custom_minimum_size = Vector2(0, 40)
		选.add_theme_stylebox_override("normal", _标签按钮样式())
		选.add_theme_color_override("font_color", BTN_标签字)
		选.pressed.connect(_确认正邪抉择.bind(名))
		行.add_child(选)
		盒.add_child(行)
	盒.add_child(弹["关"])   # 默认「知悉」关闭钮（安全退出口）

func _确认正邪抉择(名: String) -> void:
	# 二次确认：再弹朱砂警示窗，须二次点「确认立誓」方可写入
	var 弹: Dictionary = _new_detail_popup("确认立誓？", 朱砂)
	var 盒: VBoxContainer = 弹["内容"]
	var 警 := Label.new()
	警.text = "道统选定，终身不可逆"
	警.add_theme_color_override("font_color", 朱砂)
	警.add_theme_font_size_override("font_size", FONT_PANEL_B)
	盒.add_child(警)
	var 副 := Label.new()
	副.text = "一旦立誓入【%s】，永不可改（除非新游戏）。" % 名
	副.add_theme_color_override("font_color", 次墨)
	副.add_theme_font_size_override("font_size", FONT_BODY)
	盒.add_child(副)
	var 行 := HBoxContainer.new()
	行.add_theme_constant_override("separation", 8)
	var 立 := Button.new()
	立.text = "确认立誓"
	立.custom_minimum_size = Vector2(0, 44)
	立.add_theme_stylebox_override("normal", _主按钮样式())
	立.add_theme_color_override("font_color", BTN_主字)
	立.pressed.connect(_写入正邪路线.bind(名))
	行.add_child(立)
	var 思 := Button.new()
	思.text = "再思量"
	思.custom_minimum_size = Vector2(0, 44)
	思.add_theme_stylebox_override("normal", _危险按钮样式())
	思.add_theme_color_override("font_color", BTN_危险字)
	思.pressed.connect(_关闭详情.bind(弹["遮"]))
	行.add_child(思)
	盒.add_child(行)

func _写入正邪路线(名: String) -> void:
	# 不可逆写入 + 即时存档；选定后 UI 显徽记且不可重选（除非 new_game）
	Game.正邪路线 = 名
	# 宗门纪事（会话内展示；load 时清空，与现役 纪事 范式一致；旧档不持久）
	Game.宗门纪事.append({"日": Game.累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "正邪立誓",
		"文案": "宗门立誓入 %s 道，道统既定，终身不改。" % 名, "category": "宗门大事件"})
	Game.save_game()   # 即时存档（正邪路线 持久化）
	_关闭详情(_当前详情遮)   # 关闭二次确认弹窗
	_toast("道统已定：" + 名)

func _建_弟子页():
	var 页: ScrollContainer = _新页容器()
	var 内容: Control = 页.get_child(0)
	内容.add_child(弟子页头)   # 持久：总战力 + 排序 + 提示
	# 二级 Tab：名录 / 接引（待抉择并入接引）
	var 二级 := TabBar.new()
	二级.add_tab("名录"); 二级.add_tab("接引")
	二级.tab_changed.connect(_on_弟子二级切换)
	内容.add_child(二级)
	# 名录
	内容.add_child(列表)
	# 接引（待抉择 + 招收）
	var 接引框 := VBoxContainer.new()
	接引框.name = "弟子页接引框"
	接引框.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	接引框.add_theme_constant_override("separation", 6)
	接引框.add_child(抉择区)
	var 招 := Button.new(); 招.text = "开启接引大典"; 招.name = "Button_开启接引大典"; 招.custom_minimum_size = Vector2(0, 44)
	招.pressed.connect(_on_测灵根)
	接引框.add_child(招)
	引导_招收按钮 = 招
	内容.add_child(接引框)
	# 应用二级 Tab 选中态（跨切换保留）
	二级.current_tab = _弟子二级tab
	_应用_弟子二级tab()
	当前页持久节点 = [弟子页头, 列表, 抉择区]

func _on_弟子二级切换(i: int):
	_弟子二级tab = i
	_应用_弟子二级tab()

func _应用_弟子二级tab():
	var 名录: bool = (_弟子二级tab == 0)
	列表.visible = 名录
	# 优先用抉择区父节点定位接引框；若持久节点刚换页未挂载，fallback 用名称查找
	var 接引框: Node = 抉择区.get_parent()
	if 接引框 == null and 列表.get_parent() != null:
		接引框 = 列表.get_parent().get_node_or_null("弟子页接引框")
	if 接引框 != null:
		接引框.visible = not 名录

func _建_御兽页():
	var 页: ScrollContainer = _新页容器()
	var 内容: Control = 页.get_child(0)
	var 快进 := Button.new(); 快进.text = "御兽快进（孵化30日）"; 快进.custom_minimum_size = Vector2(0, 44)
	快进.pressed.connect(_on_快进)
	内容.add_child(快进)
	内容.add_child(御兽区)   # 持久
	当前页持久节点 = [御兽区]

func _建_历练页():
	var 页: ScrollContainer = _新页容器()
	var 内容: Control = 页.get_child(0)
	var 头 := Label.new()
	头.text = "⚔ 历练征途"
	头.add_theme_font_size_override("font_size", FONT_PANEL_B)
	头.add_theme_color_override("font_color", 暗金)
	内容.add_child(头)
	内容.add_child(_玄玉占位按钮())
	var 体力标 := Label.new()
	体力标.text = "气力：%d / %d" % [Game.体力, Game.体力上限()]
	体力标.add_theme_color_override("font_color", 次墨)
	内容.add_child(体力标)
	# §1.7 B5：禁止嵌套 ScrollContainer（整页已是 ScrollContainer，直接挂列到页 VBox）
	var 列 := VBoxContainer.new()
	列.add_theme_constant_override("separation", 4)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	内容.add_child(列)
	历练滚动列 = 列   # 持久引用，战斗胜利后刷新用
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
	当前页持久节点 = []

func _建_纪事页():
	var 页: ScrollContainer = _新页容器()
	var 内容: Control = 页.get_child(0)
	# WAVE-C #3：先贤祠入口（B2 二级下沉：不新增一级导航按钮，仅纪事页内跳转二级页）
	var 先贤入口 := Button.new(); 先贤入口.text = "先贤祠"
	先贤入口.custom_minimum_size = Vector2(0, 44)
	先贤入口.pressed.connect(func(): _进_二级页("先贤祠"))
	内容.add_child(先贤入口)
	内容.add_child(纪事区)   # 持久（刷新纪事在其内建分类 Tab）
	刷新纪事()
	当前页持久节点 = [纪事区]

func _进_二级页(名: String):
	_二级页 = 名
	_建_二级页(名)

func _建_二级页(名: String):
	_卸下当前页()
	var 页: ScrollContainer = _新页容器()
	var 内容: Control = 页.get_child(0)
	var 返回 := Button.new(); 返回.text = "← 返回宗门"; 返回.custom_minimum_size = Vector2(0, 44)
	返回.pressed.connect(_返回宗门)
	内容.add_child(返回)
	match 名:
		"坊市": _填_坊市页(内容)
		"任务": _填_任务页(内容)
		"建筑": _填_建筑页(内容)
		"账册": _填_账册页(内容)
		"洞府": _填_洞府页(内容)
		"修炼": _填_修炼页(内容)
		"先贤祠": _填_先贤祠页(内容)
	当前页名 = "宗门"   # 主导航仍高亮宗门
	当前页持久节点 = []

func _返回宗门():
	_on_主导航切换(0)

func _建_弟子页头():
	弟子页头 = VBoxContainer.new()
	弟子页头.add_theme_constant_override("separation", 4)
	var 战力行 := HBoxContainer.new()
	总战力标签 = Label.new()
	总战力标签.text = "宗门总战力：0"
	总战力标签.add_theme_font_size_override("font_size", FONT_SUB)
	总战力标签.add_theme_color_override("font_color", 暗金)
	战力行.add_child(总战力标签)
	弟子页头.add_child(战力行)
	var 排序行 := HBoxContainer.new()
	排序行.add_theme_constant_override("separation", 6)
	for 名 in ["默认", "战力", "境界", "资质"]:
		var 钮 := Button.new(); 钮.text = 名
		钮.add_theme_font_size_override("font_size", FONT_AUX)
		钮.pressed.connect(_on_排序.bind(名))
		排序按钮组[名] = 钮
		排序行.add_child(钮)
	# S1 批1：批量考核入口（弟子页顶部）
	var 批量考核钮 := Button.new(); 批量考核钮.text = "批量考核"
	批量考核钮.add_theme_font_size_override("font_size", FONT_AUX)
	批量考核钮.add_theme_color_override("font_color", 暗金)
	批量考核钮.pressed.connect(_弹出批量考核)
	排序行.add_child(批量考核钮)
	弟子页头.add_child(排序行)
	_刷新排序按钮()
	引导_弟子提示 = Label.new()
	引导_弟子提示.text = "可前往「弟子」页查看详情 →"
	引导_弟子提示.add_theme_font_size_override("font_size", FONT_AUX)
	引导_弟子提示.add_theme_color_override("font_color", 暗金)
	引导_弟子提示.visible = false
	弟子页头.add_child(引导_弟子提示)

func _弹_设置():
	var 遮 := ColorRect.new()
	遮.color = 弹窗遮罩
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "设置弹窗"
	add_child(遮)
	var pc: PanelContainer = 新面板("⚙ 设置")
	pc.anchor_left = 0.5; pc.anchor_top = 0.5; pc.anchor_right = 0.5; pc.anchor_bottom = 0.5
	pc.offset_left = -160; pc.offset_top = -120; pc.offset_right = 160; pc.offset_bottom = 120
	遮.add_child(pc)
	var 内容: Control = pc.get_child(0)
	var 存 := Button.new(); 存.text = "存档"; 存.custom_minimum_size = Vector2(0, 44); 存.pressed.connect(_on_存档); 内容.add_child(存)
	var 读 := Button.new(); 读.text = "读档"; 读.custom_minimum_size = Vector2(0, 44); 读.pressed.connect(_on_读档); 内容.add_child(读)
	var 新 := Button.new(); 新.text = "新游戏"; 新.custom_minimum_size = Vector2(0, 44); 新.pressed.connect(_on_新游戏); 内容.add_child(新)
	var 关 := Button.new(); 关.text = "关闭"; 关.custom_minimum_size = Vector2(0, 44); 关.pressed.connect(func(): 遮.queue_free()); 内容.add_child(关)

func _弹_推演中心():
	var 遮 := ColorRect.new()
	遮.color = 弹窗遮罩
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "推演中心"
	add_child(遮)
	var pc: PanelContainer = 新面板("🐞 推演中心（调试）")
	pc.anchor_left = 0.5; pc.anchor_top = 0.5; pc.anchor_right = 0.5; pc.anchor_bottom = 0.5
	pc.offset_left = -170; pc.offset_top = -200; pc.offset_right = 170; pc.offset_bottom = 200
	遮.add_child(pc)
	var 内容: Control = pc.get_child(0)
	var 推演 := Button.new(); 推演.text = "推演汇总"; 推演.custom_minimum_size = Vector2(0, 44); 推演.pressed.connect(_on_推演); 内容.add_child(推演)
	var 推演7 := Button.new(); 推演7.text = "推演7天"; 推演7.custom_minimum_size = Vector2(0, 44); 推演7.pressed.connect(_on_推演七日); 内容.add_child(推演7)
	var 快进年 := Button.new(); 快进年.text = "推演1年"; 快进年.custom_minimum_size = Vector2(0, 44); 快进年.pressed.connect(_on_推荐一年); 内容.add_child(快进年)
	var 调试 := Button.new(); 调试.text = "调试战斗"; 调试.custom_minimum_size = Vector2(0, 44); 调试.pressed.connect(_on_调试战斗); 内容.add_child(调试)
	if OS.is_debug_build():
		var 强制征伐 := Button.new(); 强制征伐.text = "强制征伐"; 强制征伐.custom_minimum_size = Vector2(0, 44); 强制征伐.pressed.connect(_on_强制征伐); 内容.add_child(强制征伐)
		var 重置 := Button.new(); 重置.text = "重置引导"; 重置.custom_minimum_size = Vector2(0, 44); 重置.pressed.connect(_on_重置引导); 内容.add_child(重置)
		var 天品 := Button.new(); 天品.text = "强制天品"; 天品.custom_minimum_size = Vector2(0, 44); 天品.pressed.connect(_on_强制天品); 内容.add_child(天品)
		var 聚气 := Button.new(); 聚气.text = "强制聚气丹"; 聚气.custom_minimum_size = Vector2(0, 44); 聚气.pressed.connect(_on_强制聚气丹); 内容.add_child(聚气)
	var 关 := Button.new(); 关.text = "关闭"; 关.custom_minimum_size = Vector2(0, 44); 关.pressed.connect(func(): 遮.queue_free()); 内容.add_child(关)

func _弹_离山简报():
	if 离山面板 == null or not is_instance_valid(离山面板):
		return
	if 离山内容区.get_child_count() == 0:
		return
	if get_node_or_null("离山简报遮") != null:
		return   # 已开
	var 遮 := ColorRect.new()
	遮.name = "离山简报遮"
	遮.color = 弹窗遮罩
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(遮)
	var 框 := PanelContainer.new()
	框.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	框.offset_left = 20; 框.offset_right = -20; 框.offset_top = 60; 框.offset_bottom = -20
	遮.add_child(框)
	框.add_child(离山面板)   # 重挂：离山面板 成为 框 子节点

func _关_离山简报():
	var 遮: Node = get_node_or_null("离山简报遮")
	if 遮 == null or not is_instance_valid(遮):
		return   # 弹窗未打开，不操作（避免把离山面板从 main 上误卸掉）
	if is_instance_valid(离山面板):
		var 父: Node = 离山面板.get_parent()
		if is_instance_valid(父):
			父.remove_child(离山面板)
	遮.queue_free()

func _填_洞府页(内容: Control):
	var 头 := Label.new(); 头.text = "⛰ 洞府经营总览"; 头.add_theme_font_size_override("font_size", FONT_PANEL_B); 头.add_theme_color_override("font_color", 暗金); 内容.add_child(头)
	if Game.堂口列表.is_empty():
		var 空 := Label.new(); 空.text = "（尚无堂口，招徒后自动建置）"; 内容.add_child(空)
		return
	for key in Game.堂口列表.keys():
		var 堂: Dictionary = Game.堂口列表[key]
		var 名: String = 堂.get("名称", key)
		var 成员数: int = (堂.get("成员", []) as Array).size()
		var 产: int = Game.预估建筑产出(key)
		var 卡: PanelContainer = 新面板(名)
		卡.add_theme_stylebox_override("panel", _暗墨面板())
		var 文: VBoxContainer = 卡.get_child(0)
		var l1 := Label.new(); l1.text = "成员 %d 人｜预估月产 +%d 灵石" % [成员数, 产]; l1.add_theme_color_override("font_color", 次墨); 文.add_child(l1)
		内容.add_child(卡)

func _填_修炼页(内容: Control):
	var 头 := Label.new(); 头.text = "🧘 修炼设施"; 头.add_theme_font_size_override("font_size", FONT_PANEL_B); 头.add_theme_color_override("font_color", 暗金); 内容.add_child(头)
	if Game.弟子列表.is_empty():
		var 空 := Label.new(); 空.text = "（尚无弟子，先去「弟子」页接引）"; 内容.add_child(空)
		return
	for d in Game.弟子列表:
		var 卡: PanelContainer = 新面板(d.姓名)
		卡.add_theme_stylebox_override("panel", _暗墨面板())
		var 文: VBoxContainer = 卡.get_child(0)
		var l1 := Label.new(); l1.text = "境界：%s" % d.境界; l1.add_theme_color_override("font_color", 次墨); 文.add_child(l1)
		var 进: int = int(d.修炼进度 * 100)
		var l2 := Label.new(); l2.text = "修炼进度：%d%%" % 进; l2.add_theme_color_override("font_color", 次墨); 文.add_child(l2)
		if d.突破冷却剩余 > 0:
			var l3 := Label.new(); l3.text = "突破冷却：%d 日" % int(d.突破冷却剩余); l3.add_theme_color_override("font_color", 朱砂); 文.add_child(l3)
		内容.add_child(卡)

func _填_账册页(内容: Control):
	var 头 := Label.new(); 头.text = "📒 宗门账册"; 头.add_theme_font_size_override("font_size", FONT_PANEL_B); 头.add_theme_color_override("font_color", 暗金); 内容.add_child(头)
	var 总产: int = Game.预估月产出()
	var 概 := Label.new(); 概.text = "预估月产出：+%d 灵石（含弟子修炼 %d）" % [总产, Game.弟子列表.size() * 2]; 概.add_theme_color_override("font_color", 暗金); 内容.add_child(概)
	var 资 := Label.new(); 资.text = "现储：灵石 %d｜灵草 %d｜矿石 %d｜灵气 %d｜贡献 %d" % [Game.灵石, Game.灵草, Game.矿石, Game.灵气, Game.贡献点]; 资.add_theme_color_override("font_color", 次墨); 内容.add_child(资)
	内容.add_child(小标题("—— 各堂口产出 ——", 15))
	for key in Game.堂口列表.keys():
		var 堂: Dictionary = Game.堂口列表[key]
		var 名: String = 堂.get("名称", key)
		var 产: int = Game.预估建筑产出(key)
		var l := Label.new(); l.text = "%s：+%d /月" % [名, 产]; l.add_theme_color_override("font_color", 次墨); 内容.add_child(l)

func _on_推演():
	_引导_推进("推演")
	战报.text = Game.推演至现在()
	详情.text = "已推演至现在。"

func _on_测灵根():
	# 关键修复：本函数会经 Game.举办测灵根()→弟子变动.emit()→刷新()、以及 _引导_推进 重建当前
	# 弟子页（含本按钮自身）。整包延迟到本帧 pressed 回调结束后执行，彻底避开"信号回调内释放
	# 发射者节点"→ "assign invalid previously freed instance" 崩溃。
	call_deferred("_测灵根_执行")

func _测灵根_执行():
	# 边缘恢复：理论上步④已招徒，若弟子列表仍空（异常），回落到步③招徒以免卡步
	if Game.引导阶段 == 4 and Game.弟子列表.is_empty():
		Game.引导阶段 = 3
	# 不在这里推进引导："收入外门"按钮才是步③的终点确认，点击后再推进到步④。
	# 否则弹窗还没关，步④气泡就会在遮罩后面指向弟子页，玩家无法交互。
	var r: Dictionary = Game.举办测灵根()
	if r.has("冷却剩余"):
		详情.text = "接引大典尚在筹备中，接引筹备周期尚余 %d 天。" % r["冷却剩余"]
		return
	_过场弹窗(str(r["过场"]), int(r["人数"]))
	# 弹窗打开后刷新引导：目标从「开启接引大典」切换为「收入外门」
	_引导_刷新()

func _on_建筑总览():
	_建_二级页("建筑")

func _on_快进():
	Game.推进孵化(30)
	详情.text = "（测试）御兽堂快进30日，查看孵化进度。"

func _on_存档():
	Game.save_game()
	详情.text = "已存档（user://save.json）"

func _on_读档():
	Game.load_game()
	详情.text = "已读档"
	刷新()
	_引导_初始化()   # 读档后续接引导（按引导阶段恢复气泡/目标条/灰锁，或清场）
	_弹_离山简报()   # 读档上线弹离线收益简报

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
		"日": Game.累计游戏日, "弟子": 当前选中.姓名, "弟子ID": 当前选中.弟子ID,
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
	Game.宗门纪事.append({"日": Game.累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": "普通", "名称": "调试·聚气丹", "文案": "获得奖励：%s" % 摘要.strip_edges()})
	if 当前页名 == "纪事":
		刷新纪事()
	_toast("（已强制触发聚气丹奇遇，见「纪事」页签点击验证）")

# 重置新手引导（调试专用）：将引导阶段归零并存档，重放序章+四步引导。
# 仅 debug 构建可达（按钮由 OS.is_debug_build 包裹）。用于反复走查引导表现。
func _on_重置引导():
	Game.引导阶段 = 0
	Game.save_game()
	_引导已收尾 = false
	_首推演已保底 = false
	_招徒后_弟子高亮中 = false
	_弟子详情_已自动展开 = false
	引导_跳过按钮.visible = true
	_引导_清除()
	_清除招徒高亮()
	_引导_初始化()   # 重新初始化（重放序章）

# 开始新游戏（调试专用）：删存档 + 重置所有状态 + 重新初始化
func _on_新游戏():
	Game.new_game()
	_引导已收尾 = false
	_首推演已保底 = false
	_招徒后_弟子高亮中 = false
	_弟子详情_已自动展开 = false
	引导_跳过按钮.visible = true
	_引导_清除()
	_清除招徒高亮()
	刷新()
	_引导_初始化()

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
			return 评级_红
		"S", "A+":
			return 评级_橙
		"A", "B":
			return 评级_绿
		"C":
			return 评级_灰
		_:
			return 评级_默认

# P1：七载大典仪式弹窗（双周期评级收口庆典，零数值，纯展示）
# WAVE-B #4：品级权益映射表（config/品级权益映射.csv）→ 等级→权益行（懒加载，缺表回退空）
var _品级权益缓存: Array = []
var _品级权益已加载: bool = false

func _品级权益表() -> Array:
	if _品级权益已加载:
		return _品级权益缓存
	_品级权益已加载 = true
	var file: FileAccess = FileAccess.open("res://config/品级权益映射.csv", FileAccess.READ)
	if file == null:
		return _品级权益缓存
	file.get_csv_line()  # 跳过 header
	while not file.eof_reached():
		var parts: PackedStringArray = file.get_csv_line()
		if parts.size() < 6:
			continue
		_品级权益缓存.append({
			"品级": parts[0].strip_edges(),
			"门派等级阈值": int(parts[1].strip_edges()),
			"编制上限": parts[2].strip_edges(),
			"解锁功能": parts[3].strip_edges(),
			"弹窗标题": parts[4].strip_edges(),
			"弹窗文案": parts[5].strip_edges(),
		})
	return _品级权益缓存

# WAVE-B #4：门派等级 → 权益行（取 门派等级阈值 <= 等级 的最高档；缺表回退空字典）
func _门派等级到品级权益(等级: int) -> Dictionary:
	var 表: Array = _品级权益表()
	var 命中: Dictionary = {}
	for r in 表:
		if r["门派等级阈值"] <= 等级:
			if 命中.is_empty() or r["门派等级阈值"] > 命中["门派等级阈值"]:
				命中 = r
	return 命中

# WAVE-B #4：宗门设置页——当前品级权益总览（读 门派等级→映射品级权益；纯展示，不新增按钮）
func _品级权益总览面板() -> PanelContainer:
	var 卡: PanelContainer = 新面板("—— 宗门品级权益 ——")
	卡.add_theme_stylebox_override("panel", _暗墨面板())
	var 文: VBoxContainer = 卡.get_child(0)
	var 当前: Dictionary = _门派等级到品级权益(Game.门派等级)
	var 当前品级名: String = 当前.get("品级", "九品") if not 当前.is_empty() else "九品"
	var 当前行 := Label.new()
	当前行.text = "当前品级：%s（门派 Lv%d）" % [当前品级名, Game.门派等级]
	当前行.add_theme_color_override("font_color", 暗金)
	文.add_child(当前行)
	for r in _品级权益表():
		var 已达: bool = r["门派等级阈值"] <= Game.门派等级
		var 行 := Label.new()
		行.text = "%s　编制上限 %s　解锁：%s%s" % [r["品级"], r["编制上限"], r["解锁功能"], ("" if 已达 else "（未达门槛）")]
		行.add_theme_color_override("font_color", 暗金 if 已达 else 次墨)
		文.add_child(行)
	return 卡

func _弹七载大典():
	var 弹: Dictionary = _new_detail_popup("太玄宗·七载宗门大考")
	var 内容: VBoxContainer = 弹["内容"]
	var 摘: Dictionary = Game.七载大典摘要
	var 评级: String = 摘.get("评级", Game.最新周期评级卡.get("评级", "C"))
	var 文: Dictionary = Game._七载大典文案(评级)
	var 序号: int = 摘.get("序号", 1)
	# 标题（按评级分档）
	var 贺 := Label.new()
	贺.text = "✦ " + 文["标题"]
	贺.add_theme_font_size_override("font_size", FONT_SUB)
	贺.add_theme_color_override("font_color", 暗金)
	内容.add_child(贺)
	# 开篇仪式文案（高评级盛事感 / 低评级柔化挫败感）
	var 开 := Label.new()
	开.text = 文["开篇"]
	开.add_theme_font_size_override("font_size", FONT_AUX)
	开.add_theme_color_override("font_color", 次墨)
	内容.add_child(开)
	# 模块包装：七年库府结余 / 宗门重宝颁赐 / 宗门品阶跃迁
	var 灵石: int = 摘.get("灵石", 0)
	var 法宝数: int = 摘.get("法宝数", 0)
	var 晋升至: int = 摘.get("晋升至", 0)
	if 灵石 > 0 or 法宝数 > 0 or 晋升至 > 0:
		var 块 := VBoxContainer.new()
		块.add_theme_constant_override("separation", 2)
		if 灵石 > 0:
			var l := Label.new(); l.text = "〔七年库府结余〕灵石 +%d" % 灵石
			l.add_theme_font_size_override("font_size", FONT_AUX); l.add_theme_color_override("font_color", 次墨); 块.add_child(l)
		if 法宝数 > 0:
			var l := Label.new(); l.text = "〔宗门重宝颁赐〕上品法宝 %d 件" % 法宝数
			l.add_theme_font_size_override("font_size", FONT_AUX); l.add_theme_color_override("font_color", 次墨); 块.add_child(l)
		if 晋升至 > 0:
			var l := Label.new(); l.text = "〔宗门品阶跃迁〕晋至 Lv.%d" % 晋升至
			l.add_theme_font_size_override("font_size", FONT_AUX); l.add_theme_color_override("font_color", 次墨); 块.add_child(l)
			# WAVE-B #4：本次解锁权益（按晋升至映射品级，查 品级权益映射.csv 取标题+文案；晋升至==0 不显示，无空块）
			var 权益: Dictionary = _门派等级到品级权益(晋升至)
			if not 权益.is_empty():
				var 标 := Label.new(); 标.text = "〔本次解锁权益〕" + 权益.get("弹窗标题", "")
				标.add_theme_font_size_override("font_size", FONT_AUX); 标.add_theme_color_override("font_color", 暗金); 块.add_child(标)
				var 案 := Label.new(); 案.text = 权益.get("弹窗文案", "")
				案.add_theme_font_size_override("font_size", FONT_AUX); 案.add_theme_color_override("font_color", 次墨); 块.add_child(案)
			else:
				# O3-D1 修复：权益映射缺失（CSV 缺行/无匹配）时补默认文案（GDD §4.8 EC-4）
				var 默 := Label.new(); 默.text = "宗门更上一层"
				默.add_theme_font_size_override("font_size", FONT_AUX); 默.add_theme_color_override("font_color", 次墨); 块.add_child(默)
			# O3-D1 修复：将 内容.add_child(块) 移出 权益 守卫，使「品阶跃迁」行在 晋升至>0 时恒显示（权益子块仍按非空条件渲染）
			内容.add_child(块)
	# 收尾纪年
	var 铭 := Label.new()
	铭.text = (文["收尾"] % 序号) + "\n—— 太玄宗·七载大典 ——"
	铭.add_theme_font_size_override("font_size", FONT_AUX)
	铭.add_theme_color_override("font_color", 次墨)
	内容.add_child(铭)

	# WAVE-A #5：七载盛事风物（按 触发周期=七载 过滤展示，纯氛围，零数值）
	var 七载风物: Array = Quest._取周期事件("七载")
	if not 七载风物.is_empty():
		var 盛块 := VBoxContainer.new()
		盛块.add_theme_constant_override("separation", 2)
		var 盛标 := Label.new()
		盛标.text = "〔七载盛事风物〕"
		盛标.add_theme_font_size_override("font_size", FONT_AUX)
		盛标.add_theme_color_override("font_color", 暗金)
		盛块.add_child(盛标)
		for e in 七载风物:
			var 盛名 := Label.new()
			盛名.text = "· " + e.get("event_name", "")
			盛名.add_theme_font_size_override("font_size", FONT_AUX)
			盛名.add_theme_color_override("font_color", 次墨)
			盛块.add_child(盛名)
		内容.add_child(盛块)

func _构建离山内容(数据: Dictionary):
	# 清空旧内容；关闭弹窗后异步重建可能遇到已释放节点，跳过无效实例
	for c in 离山内容区.get_children():
		if is_instance_valid(c):
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
	标题行.add_theme_font_size_override("font_size", FONT_PANEL)
	标题行.add_theme_color_override("font_color", 暗金)
	总览.add_child(标题行)

	# 资源收益行
	if 灵石收益 > 0:
		var 资源行 := Label.new()
		资源行.text = "💰  灵石 +%d" % 灵石收益
		资源行.add_theme_font_size_override("font_size", FONT_BODY)
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
		统计行.add_theme_font_size_override("font_size", FONT_AUX)
		统计行.add_theme_color_override("font_color", 次墨)
		总览.add_child(统计行)

	# 筛选行：点击统计类型过滤事件（无对应类型不显示该按钮）
	var 筛选行 := HBoxContainer.new()
	筛选行.add_theme_constant_override("separation", 4)
	var 全部钮 := Button.new(); 全部钮.text = "全部"
	全部钮.add_theme_font_size_override("font_size", FONT_AUX)
	全部钮.add_theme_color_override("font_color", 暗金 if _战报筛选 == "" else 次墨)
	全部钮.pressed.connect(func(): _设战报筛选(""))
	筛选行.add_child(全部钮)
	if 摘要.get("breakthrough_count", 0) > 0:
		var 突破钮 := Button.new(); 突破钮.text = "突破 %d" % 摘要["breakthrough_count"]
		突破钮.add_theme_font_size_override("font_size", FONT_AUX)
		突破钮.add_theme_color_override("font_color", 暗金 if _战报筛选 == "breakthrough" else 次墨)
		突破钮.pressed.connect(func(): _设战报筛选("breakthrough"))
		筛选行.add_child(突破钮)
	if 摘要.get("appoint_count", 0) > 0:
		var 任职钮 := Button.new(); 任职钮.text = "任职 %d" % 摘要["appoint_count"]
		任职钮.add_theme_font_size_override("font_size", FONT_AUX)
		任职钮.add_theme_color_override("font_color", 暗金 if _战报筛选 == "appoint" else 次墨)
		任职钮.pressed.connect(func(): _设战报筛选("appoint"))
		筛选行.add_child(任职钮)
	if 摘要.get("quest_success_count", 0) > 0:
		var 奇遇钮 := Button.new(); 奇遇钮.text = "奇遇 %d" % 摘要["quest_success_count"]
		奇遇钮.add_theme_font_size_override("font_size", FONT_AUX)
		奇遇钮.add_theme_color_override("font_color", 暗金 if _战报筛选 == "quest" else 次墨)
		奇遇钮.pressed.connect(func(): _设战报筛选("quest"))
		筛选行.add_child(奇遇钮)
	总览.add_child(筛选行)

	# 一键领取按钮（展示型：确认已阅 + 收起）
	var 领取按钮 := Button.new()
	领取按钮.text = "  ✓ 一键领取  "
	领取按钮.add_theme_font_size_override("font_size", FONT_AUX)
	# 按钮 Tween 动画（悬停/按下）— 见 _接按钮Tween 函数
	_接按钮动画(领取按钮)
	领取按钮.pressed.connect(_on_一键领取.bind(领取按钮))
	总览.add_child(领取按钮)

	# P1：太玄宗·岁末考评卡片（年结后优先展示于离山汇总顶部，三栏：评级 / 当年论功 / 七载积存）
	if not Game.最新周期评级卡.is_empty():
		var 卡: Dictionary = Game.最新周期评级卡
		var 评级卡 := VBoxContainer.new()
		评级卡.add_theme_constant_override("separation", 3)
		var 标题 := Label.new()
		标题.text = "🏆 太玄宗·岁末考评：%s（第 %d 周期 · %d 分）" % [卡["评级"], 卡["周期"], 卡["总分"]]
		标题.add_theme_font_size_override("font_size", FONT_SUB)
		标题.add_theme_color_override("font_color", _评级色(卡["评级"]))
		评级卡.add_child(标题)
		var 维 := Label.new()
		维.text = "经营 %d ｜ 收益 %d ｜ 弟子 %d" % [卡["分维度"]["经营"], 卡["分维度"]["收益"], 卡["分维度"]["弟子"]]
		维.add_theme_font_size_override("font_size", FONT_AUX)
		维.add_theme_color_override("font_color", 次墨)
		评级卡.add_child(维)
		# 三栏：当年论功（灵石）/ 七载积存 / 高阶法宝平移
		var 栏文: String = "当年论功 灵石+%d" % 卡.get("年度发", 0)
		if Game._校准开("双周期评级启用", true):
			栏文 += " ｜ 七载积存 %d" % Game.七载奖励池
			if 卡.get("平移法宝", false):
				栏文 += " ｜ 上品法宝留待七载大典"
		var 栏 := Label.new()
		栏.text = 栏文
		栏.add_theme_font_size_override("font_size", FONT_AUX)
		栏.add_theme_color_override("font_color", 暗金)
		评级卡.add_child(栏)
		# 双倒计时：距岁末 / 距七载大考
		var 距岁末: int = max(0, (Game.上次结算年 + 365) - Game.累计游戏日)
		var 倒文: String = "距岁末考评 %d 日" % 距岁末
		if Game._校准开("双周期评级启用", true):
			var 距七载: int = max(0, (Game.上次七载日 + Game._校准整("七载周期年", 7) * 365) - Game.累计游戏日)
			倒文 += " ｜ 距七载大考 %d 日" % 距七载
		var 倒 := Label.new()
		倒.text = 倒文
		倒.add_theme_font_size_override("font_size", FONT_AUX)
		倒.add_theme_color_override("font_color", 次墨)
		评级卡.add_child(倒)
		
		# WAVE-A #5：当年风物（按 触发周期=年度 过滤展示，纯氛围，零数值）
		var 当年风物: Array = Quest._取周期事件("年度")
		if not 当年风物.is_empty():
			var 风名: String = ""
			for e in 当年风物:
				风名 += ("、" if 风名 != "" else "") + e.get("event_name", "")
			var 风 := Label.new()
			风.text = "〔当年风物〕" + 风名
			风.add_theme_font_size_override("font_size", FONT_AUX)
			风.add_theme_color_override("font_color", 次墨)
			评级卡.add_child(风)
		离山内容区.add_child(评级卡)
		var 分隔顶 := HSeparator.new(); 分隔顶.modulate.a = 0.35; 离山内容区.add_child(分隔顶)

	离山内容区.add_child(总览)

	# 「你离开期间 · 宗门现状」概览（纯展示既有字段，确保离线简报永不为空）
	离山内容区.add_child(_离山现状块(摘要))

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
		重大按钮.add_theme_font_size_override("font_size", FONT_AUX)
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
		折叠按钮.add_theme_font_size_override("font_size", FONT_AUX)
		折叠按钮.add_theme_color_override("font_color", 颜色_琐事)
		折叠按钮.text = ("▼ 收起琐事" if _琐事已展开 else "▶ 查看全部琐事（%d条）") % 琐事总数
		折叠_container.add_child(折叠按钮)
		var 理事列表 := VBoxContainer.new()
		理事列表.visible = _琐事已展开
		for 条目 in 琐事_可见:
			var 行 := Label.new()
			行.text = "  " + 符号失败 + " " + 条目.get("text", "")
			行.add_theme_font_size_override("font_size", FONT_AUX)
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
		空记.add_theme_font_size_override("font_size", FONT_AUX)
		空记.add_theme_color_override("font_color", 次墨)
		离山内容区.add_child(空记)

	# 七载大典仪式弹窗（七载大考后于离山汇总展示一次，纯展示零数值）
	if Game.七载大典待展示:
		Game.七载大典待展示 = false
		_弹七载大典()

# 「你离开期间 · 宗门现状」概览块（纯展示既有字段，确保离线简报永不为空）
func _离山现状块(摘要: Dictionary) -> VBoxContainer:
	var 块 := VBoxContainer.new()
	块.add_theme_constant_override("separation", 2)
	块.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 题: Label = 小标题("—— 你离开期间 · 宗门现状 ——", FONT_AUX)
	块.add_child(题)
	# 资源产出（核心经营数据，既有 预估月产出）
	var l1 := Label.new()
	l1.text = "资源产出：+%d 灵石 / 月" % Game.预估月产出()
	l1.add_theme_font_size_override("font_size", FONT_AUX)
	l1.add_theme_color_override("font_color", 玉石绿)
	块.add_child(l1)
	# 弟子（在册 + 在岗）
	var 在岗: int = _在岗弟子数()
	var l2 := Label.new()
	l2.text = "弟子：%d 人在册（在岗 %d 人）" % [Game.弟子列表.size(), 在岗]
	l2.add_theme_font_size_override("font_size", FONT_AUX)
	l2.add_theme_color_override("font_color", 次墨)
	块.add_child(l2)
	# 修炼进展（在修弟子数，既有 修炼进度 字段）
	var 在修: int = 0
	for d in Game.弟子列表:
		if d.修炼进度 > 0:
			在修 += 1
	var l3 := Label.new()
	l3.text = "修炼进展：%d 人在修" % 在修
	l3.add_theme_font_size_override("font_size", FONT_AUX)
	l3.add_theme_color_override("font_color", 次墨)
	块.add_child(l3)
	# 事件数（来自结构化 summary，无事件时为 0）
	var 事件数: int = int(摘要.get("total_events", 0))
	var l4 := Label.new()
	l4.text = "累计事件：%d 条" % 事件数
	l4.add_theme_font_size_override("font_size", FONT_AUX)
	l4.add_theme_color_override("font_color", 次墨)
	块.add_child(l4)
	var l5 := Label.new()
	l5.text = "当前时日：%s" % Game.时间文本()
	l5.add_theme_font_size_override("font_size", FONT_AUX)
	l5.add_theme_color_override("font_color", 青灰)
	块.add_child(l5)
	return 块

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
	行.add_theme_font_size_override("font_size", FONT_AUX)
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
	# 若用户已关闭弹窗，离山面板不再挂载，取消重建避免访问已释放节点
	if not is_instance_valid(离山面板) or 离山面板.get_parent() == null:
		return
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
		tw.parallel().tween_property(btn, "modulate", 强调亮灰, anim_dur * 0.8)
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
	if not is_instance_valid(btn):
		return
	btn.disabled = true
	btn.text = "  ✓ 已领取  "
	btn.modulate = 置灰色   # 置灰
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
		_清除招徒高亮()   # 完成步④后清除招徒高亮与淡提示

func _on_命格(d: Disciple):
	_弹出弟子属性弹窗("命格", "【命格】%s" % d.命格详情(), d)

func _on_灵根(d: Disciple):
	_弹出弟子属性弹窗("灵根", "【灵根·%s】\n%s" % [d.灵根, d.灵根详情()], d)

func _on_性格(d: Disciple):
	_弹出弟子属性弹窗("性格", "【性格·%s】\n%s" % [d.性格, d.性格详情()], d)

func _on_职业(d: Disciple):
	var 职名: String = d.职业 if d.职业 != "" else "未入门"
	_弹出弟子属性弹窗("职业", "【职业·%s】\n%s" % [职名, d.职业详情()], d)

# ============ S1 批1：阶位轴操作（考核晋升 / 罢免阶位 / 批量考核）============
func _on_考核晋升(d: Disciple):
	if d == null:
		return
	if not d.可授阶():
		_toast("%s 身份不足，须内门及以上方可授阶" % d.姓名)
		return
	if d.考核冷却剩余 > 0:
		_toast("%s 考核冷却中（剩余 %d 日）" % [d.姓名, d.考核冷却剩余])
		return
	var 破格: bool = Game.满足破格条件(d)
	var 上限idx: int = d.阶位上限索引(破格)
	if d.阶位索引() >= 上限idx:
		_toast("%s 已达该身份可任最高阶位" % d.姓名)
		return
	var 目标阶位: String = d.阶位层级序[d.阶位索引() + 1]
	var 占用: int = Game.阶位名额占用(目标阶位)
	var 上限: int = Game.阶位名额上限(目标阶位)
	if 占用 >= 上限:
		_toast("%s 名额已满（%d/%d）" % [目标阶位, 占用, 上限])
		return
	var 弹: Dictionary = _new_detail_popup("考核晋升 · %s" % d.姓名)
	var 信息 := Label.new()
	信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	信息.text = "当前阶位：阶位·%s\n目标阶位：阶位·%s\n成功率：%d%%\n行政成本：贡献点 -%d（失败再 -%d）\n名额：%d/%d%s" % \
		[d.阶位 if d.阶位 != "无" else "无（未授阶）", 目标阶位, int(d.考核成功率() * 100),
		 Game.考核成本, Game.考核失败扣减, 占用, 上限, ("（破格 +1 阶）" if 破格 else "")]
	弹["内容"].add_child(信息)
	var 行 := HBoxContainer.new(); 行.add_theme_constant_override("separation", 6)
	var 确认 := Button.new(); 确认.text = "发起考核"
	确认.disabled = (Game.贡献点 < Game.考核成本)
	确认.pressed.connect(func():
		if not is_instance_valid(弹["遮"]):
			return
		弹["遮"].queue_free()
		_执行考核(d)
	)
	行.add_child(确认)
	var 取消 := Button.new(); 取消.text = "取消"
	取消.pressed.connect(func():
		if is_instance_valid(弹["遮"]):
			弹["遮"].queue_free()
	)
	行.add_child(取消)
	弹["内容"].add_child(行)
	弹["内容"].add_child(弹["关"])

func _执行考核(d: Disciple):
	var r: Dictionary = Game.发起考核(d)
	if r.get("成功"):
		_toast("【晋升】%s 晋阶为 阶位·%s！" % [d.姓名, d.阶位])
	else:
		_toast("考核结果：%s（%s）" % [("失利" if r.get("ok") else "未发起"), r.get("原因", "")])
	刷新()

func _on_罢免阶位(d: Disciple):
	if d == null or d.阶位 == "无":
		return
	var r: Dictionary = Game.罢免阶位(d)
	if r.get("ok"):
		_toast("【罢免】%s 被罢去阶位，现任 阶位·%s。" % [d.姓名, d.阶位])
	else:
		_toast("罢免失败：%s" % r.get("原因", ""))
	刷新()

func _弹出批量考核():
	var 候选: Array = []
	for d in Game.弟子列表:
		if d.可授阶() and d.考核冷却剩余 <= 0:
			候选.append(d)
	if 候选.is_empty():
		_toast("当前无可考核弟子（须内门及以上且不在冷却中）")
		return
	var 弹: Dictionary = _new_detail_popup("批量考核")
	var 说明 := Label.new()
	说明.text = "勾选参与本次考核的弟子（逐人独立掷骰，独立判定冷却与名额）："
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	弹["内容"].add_child(说明)
	var 勾列表: Array = []
	for d in 候选:
		var 行 := HBoxContainer.new(); 行.add_theme_constant_override("separation", 6)
		var 勾 := CheckBox.new(); 勾.text = "%s（阶位·%s）" % [d.姓名, d.阶位]
		勾.set_meta("弟子", d)
		勾列表.append(勾)
		行.add_child(勾)
		弹["内容"].add_child(行)
	var 确认 := Button.new(); 确认.text = "确认考核"
	确认.pressed.connect(func():
		if not is_instance_valid(弹["遮"]):
			return
		var 选: Array = []
		for 勾 in 勾列表:
			if 勾.button_pressed:
				选.append(勾.get_meta("弟子"))
		if 选.is_empty():
			_toast("未勾选任何弟子")
			return
		var 汇总: Dictionary = Game.批量考核(选)
		_toast("批量考核完成：成功 %d · 失败 %d · 跳过 %d · 贡献扣减 %d" % [汇总["成功"].size(), 汇总["失败"].size(), 汇总["跳过"].size(), 汇总["贡献扣减"]])
		刷新()
		if is_instance_valid(弹["遮"]):
			_关闭详情(弹["遮"])
	)
	弹["内容"].add_child(确认)
	弹["内容"].add_child(弹["关"])

# 统一详情弹窗外壳：创建遮罩+面板+标题，返回 {遮, 内容, 关}
# 内置：点击蒙版关闭 / ESC关闭 / 0.15s淡入缩放动画 / 长内容滚动兜底
# 调用方往 内容 加滚动区/信息/关按钮。降级不崩：标题为空显示占位。
func _new_detail_popup(标题文本: String, 标题色: Color = 暗金) -> Dictionary:
	# 单实例守卫：快速连点时释放上一个遮罩，只保留最后一次（防层叠、降开销）
	if _当前详情遮 != null and is_instance_valid(_当前详情遮):
		_关闭详情(_当前详情遮)
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
	背板.pressed.connect(func(): _关闭详情(遮))
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
	标题.add_theme_font_size_override("font_size", FONT_PANEL)
	标题.add_theme_color_override("font_color", 标题色)
	内容.add_child(标题)
	var 关 := Button.new(); 关.text = "知悉"
	关.pressed.connect(func(): _关闭详情(遮))
	# ESC 全局关闭（遮罩获焦后接收键盘事件）
	遮.gui_input.connect(func(e: InputEvent):
		if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
			_关闭详情(遮))
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
	var 盒 := VBoxContainer.new()
	滚.add_child(盒)
	var 信息 := Label.new()
	信息.text = 内容文本
	盒.add_child(信息)
	# === S1 批5-B：辈分 / 道号 行（复用批4 _属性行 范式，次墨）===
	盒.add_child(_属性行("辈分：%s" % (Game.辈分字派[_d.辈分序] if _d.辈分序 < Game.辈分字派.size() else "—"), 次墨))
	盒.add_child(_属性行("道号：%s" % (_d.道号 if _d.道号 != "" else "（未取）"), 次墨))
	弹["内容"].add_child(弹["关"])

# ===== S1 批4：详情弹窗扩展 + 富文本点击联动（纯 UI 层，不改动战斗结算代码） =====

# 属性行（复用对象池）：优先从 _attr_line_pool 取 Label，否则新建；标记 meta("pooled") 以便回收
# 防御性消费：池中可能残留失效条目（页面切换/异常时序下子节点被 free）。
# 必须先以无类型 pop 拿到 Variant，校验 alive + 类型正确，再赋给 typed Label l；
# 否则 typed-var assign 校验会抛 "Trying to assign invalid previously freed instance"。
func _属性行(文本: String, 色: Color) -> Label:
	var l: Label = null
	while not _attr_line_pool.is_empty():
		var obj = _attr_line_pool.pop_back()
		if is_instance_valid(obj) and obj is Label:
			l = obj
			break
		# 否则丢弃这条失效条目，继续消费池子
	if l == null:
		l = Label.new()
	l.text = 文本
	l.visible = true
	l.modulate = Color(1, 1, 1, 1)
	l.add_theme_color_override("font_color", 色)
	if not l.has_meta("pooled"):
		l.set_meta("pooled", true)
	return l

# 回收详情行：递归遍历遮罩子树，将 meta("pooled")==true 的 Label 移入回收站保活并归还对象池
func _回收详情行(遮: Control) -> void:
	if 遮 == null or not is_instance_valid(遮):
		return
	# 惰性创建回收站（GDD-详情弹窗扩展_S1批4 §规格）：纯 Node 保活池化 Label，不渲染
	if _详情回收站 == null:
		_详情回收站 = Node.new()
		add_child(_详情回收站)
	for c in 遮.get_children():
		# 防御式：迭代期间子节点可能被外部时序 free；失效引用/已脱离 遮 的子节点直接跳过，
		# 防止 add_child 抛 previously freed 或重复回收。
		if c == null or not is_instance_valid(c) or c.get_parent() != 遮:
			continue
		if c is Label and c.get_meta("pooled", false) == true:
			c.visible = false
			_详情回收站.add_child(c)
			_attr_line_pool.append(c)
		elif c is Control and c != 遮:
			_回收详情行(c)

# 统一关闭入口：回收池化 Label 后 queue_free（视觉生命周期不变，关闭即销毁）
func _关闭详情(遮: Control) -> void:
	if 遮 == null or not is_instance_valid(遮):
		return
	_回收详情行(遮)
	遮.queue_free()
	# 关闭的是当前单实例遮罩时同步清空守卫，避免单实例守卫误判已释放遮罩导致重复关闭/层叠
	if 遮 == _当前详情遮:
		_当前详情遮 = null

func _弹出功法详情(id: String) -> void:
	var g: Dictionary = SkillCultivationLoader.get_skill(id)
	if g.is_empty():
		_toast("（暂无详情）")
		return
	var 弹: Dictionary = _new_detail_popup(g.get("skill_name", "功法"), 暗金)
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, mini(340, int(get_viewport_rect().size.y * 0.7)))
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	弹["内容"].add_child(滚)
	var vb := VBoxContainer.new()
	滚.add_child(vb)
	vb.add_child(_属性行("功法ID：%s" % g.get("skill_id", ""), 墨黑))
	vb.add_child(_属性行("品阶·亚阶：%s" % (str(g.get("grade", "")) + "·" + str(g.get("sub_grade", ""))), 墨黑))
	vb.add_child(_属性行("适用职业：%s" % g.get("apply_class", "—"), 墨黑))
	vb.add_child(_属性行("功法类型：%s" % g.get("skill_type", "—"), 墨黑))
	vb.add_child(_属性行("效果数值：%s" % g.get("effect_value", "—"), 墨黑))
	vb.add_child(_属性行("最大参悟等级：%s" % g.get("max_level", "—"), 墨黑))
	vb.add_child(_属性行("解锁境界：%s" % g.get("unlock_realm", "—"), 墨黑))
	vb.add_child(_属性行("参悟消耗：%s" % g.get("learn_cost", "—"), 墨黑))
	vb.add_child(_属性行("描述：（暂无描述）", 墨黑))
	弹["内容"].add_child(弹["关"])

func _弹出Buff详情(id: String) -> void:
	var b: Dictionary = BattleCalculator._buff模板(id)
	if b.is_empty():
		_toast("（暂无详情）")
		return
	var 弹: Dictionary = _new_detail_popup(b.get("buff名", "Buff"), 朱砂)
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, mini(340, int(get_viewport_rect().size.y * 0.7)))
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	弹["内容"].add_child(滚)
	var vb := VBoxContainer.new()
	滚.add_child(vb)
	vb.add_child(_属性行("BuffID：%s" % b.get("buff_id", ""), 墨黑))
	var 类型色: Color = 次墨
	if b.get("类型", "") in ["dot", "控制", "减益"]:
		类型色 = 朱砂
	vb.add_child(_属性行("类型：%s" % b.get("类型", "—"), 类型色))
	vb.add_child(_属性行("作用属性：%s" % b.get("作用属性", "—"), 墨黑))
	var 数值类型: String = b.get("数值类型", "none")
	var 数值文本: String
	if 数值类型 == "percent":
		数值文本 = "%d%%（百分比）" % int(float(b.get("数值", 0)) * 100)
	elif 数值类型 == "flat":
		数值文本 = "%s（固定）" % str(b.get("数值", 0))
	else:
		数值文本 = "—"
	vb.add_child(_属性行("数值·类型：%s" % 数值文本, 墨黑))
	vb.add_child(_属性行("持续回合：%s" % b.get("持续回合", "—"), 墨黑))
	vb.add_child(_属性行("来源类型：%s" % b.get("来源类型", "—"), 墨黑))
	vb.add_child(_属性行("可叠加：%s" % ("是" if b.get("可叠加", false) else "否"), 墨黑))
	vb.add_child(_属性行("备注：%s" % b.get("备注", "（暂无备注）"), 墨黑))
	弹["内容"].add_child(弹["关"])

func _弹出建筑详情(key: String) -> void:
	var e: Variant = Game.堂口列表.get(key)
	if e == null or not (e is Dictionary):
		_toast("（暂无详情）")
		return
	var 弹: Dictionary = _new_detail_popup(e.get("名称", "建筑"), 青灰)
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, mini(340, int(get_viewport_rect().size.y * 0.7)))
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	弹["内容"].add_child(滚)
	var vb := VBoxContainer.new()
	滚.add_child(vb)
	vb.add_child(_属性行("堂口key：%s" % key, 墨黑))
	vb.add_child(_属性行("等级：%s" % e.get("等级", "—"), 墨黑))
	vb.add_child(_属性行("政绩：%s" % e.get("政绩", "—"), 墨黑))
	vb.add_child(_属性行("状态：%s" % e.get("状态", "—"), 墨黑))
	vb.add_child(_属性行("加成维度：%s" % e.get("加成维度", "—"), 墨黑))
	var 负责: Variant = e.get("负责人", null)
	vb.add_child(_属性行("负责人：%s" % (负责.姓名 if 负责 is Disciple else "—"), 墨黑))
	var 成员数: int = (e.get("成员", []) as Array).size()
	vb.add_child(_属性行("成员数：%d" % 成员数, 墨黑))
	弹["内容"].add_child(弹["关"])

func _弹出丹药详情(物品: Item) -> void:
	if 物品 == null or 物品.类别 != "dan_yao":
		_toast("（暂无详情）")
		return
	var 色: Color = get_rarity_color(物品.品阶)
	var 弹: Dictionary = _new_detail_popup(物品.名称, 色)
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, mini(340, int(get_viewport_rect().size.y * 0.7)))
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	弹["内容"].add_child(滚)
	var vb := VBoxContainer.new()
	滚.add_child(vb)
	vb.add_child(_属性行("品阶：%s" % 物品.品阶, 墨黑))
	vb.add_child(_属性行("品类标记：丹药", 墨黑))
	vb.add_child(_属性行("简介：%s" % 物品.简介(), 墨黑))
	vb.add_child(_属性行("描述：%s" % (物品.描述 if 物品.描述 != "" else "（暂无描述）"), 次墨))
	vb.add_child(_属性行("说明：丹药功效详见简介/描述", 墨黑))
	弹["内容"].add_child(弹["关"])

func _弹出灵兽详情(b: Beast) -> void:
	if b == null:
		_toast("（暂无详情）")
		return
	var 弹: Dictionary = _new_detail_popup(b.种类名, 暗金)
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, mini(340, int(get_viewport_rect().size.y * 0.7)))
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	弹["内容"].add_child(滚)
	var vb := VBoxContainer.new()
	滚.add_child(vb)
	vb.add_child(_属性行("品阶：%s" % b.品阶, 墨黑))
	vb.add_child(_属性行("等级：Lv.%d" % b.等级, 墨黑))
	vb.add_child(_属性行("等级上限：%d" % b.等级上限, 墨黑))
	vb.add_child(_属性行("类型：%s" % b.beast_type, 墨黑))
	vb.add_child(_属性行("忠诚度：%d" % b.忠诚度, 墨黑))
	vb.add_child(_属性行("简介：%s" % b.简介(), 墨黑))
	弹["内容"].add_child(弹["关"])

func _弹出纪事详情(记: Dictionary) -> void:
	if 记 == null or not (记 is Dictionary) or 记.is_empty():
		_toast("（暂无详情）")
		return
	var 弹: Dictionary = _new_detail_popup(记.get("名称", "纪事"), 暗金)
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, mini(340, int(get_viewport_rect().size.y * 0.7)))
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	弹["内容"].add_child(滚)
	var vb := VBoxContainer.new()
	滚.add_child(vb)
	vb.add_child(_属性行("日：%s" % 记.get("日", "—"), 墨黑))
	vb.add_child(_属性行("category：%s" % 记.get("category", "—"), 墨黑))
	vb.add_child(_属性行("稀有度：%s" % 记.get("稀有度", "—"), 墨黑))
	vb.add_child(_属性行("弟子：%s" % (记.get("弟子", "") if 记.get("弟子", "") != "" else "—"), 墨黑))
	vb.add_child(_属性行("文案：%s" % 记.get("文案", "—"), 墨黑))
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
	# 名录空占位（无弟子时给出引导，避免空白页）
	if Game.弟子列表.is_empty():
		var 空 := Label.new()
		空.text = "（尚无弟子在册，前往「接引」开启接引大典）"
		空.add_theme_color_override("font_color", 次墨)
		列表.add_child(空)
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
	_刷新功能解锁()   # 同步灰锁（坊市/任务/历练/御兽）状态

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
		# === S1 批5-B 端口：[PLACEHOLDER] 辈分礼制排序维度「辈分序→境界→入门序」待实装 ===
		# 接入方式：在 排序按钮组 增「辈分」钮(绑定 弟子排序维度="辈分")，并在此 match 增 case：
		#   "辈分":
		#       var va: int = a.辈分序; var vb: int = b.辈分序
		#       if va != vb: return va > vb if 降 else va < vb
		#       var ja: int = Disciple.境界序.find(a.境界); var jb: int = Disciple.境界序.find(b.境界)
		#       if ja != jb: return ja > jb if 降 else ja < jb
		#       return Game.弟子列表.find(a) < Game.弟子列表.find(b)   # 入门序=原始招募序（[PLACEHOLDER] 字段待定）
		# 当前仅标端口，不强行改排序；门规严格度/辈分间隔数值未定（GDD §⑨ [PLACEHOLDER]）。
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
	var 选 := Button.new(); 选.text = d.姓名; 选.name = "Button_选弟子"; 选.pressed.connect(_on_选弟子.bind(d))
	头.add_child(选)
	# S1 战斗生效·优先级3：随行灵兽徽标（头像旁轻量标识，不抢弟子主体视觉重心）
	var 徽: String = _灵兽随行徽标(d)
	if 徽 != "":
		var 宠标 := Label.new()
		宠标.text = "随行：" + 徽
		宠标.add_theme_font_size_override("font_size", FONT_AUX)
		宠标.add_theme_color_override("font_color", 暗金)
		头.add_child(宠标)
	# S1 批1：阶位· chip（双轴前缀消歧，暗金描边，type scale 13）
	if d.阶位 != "无":
		var 阶标 := Label.new()
		阶标.text = "阶位·" + d.阶位
		阶标.add_theme_font_size_override("font_size", FONT_AUX)
		阶标.add_theme_color_override("font_color", 暗金)
		头.add_child(阶标)
	vb.add_child(头)
	vb.add_child(_玄玉占位按钮())
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
	var 法阵按钮 := Button.new(); 法阵按钮.text = "法阵"; 法阵按钮.pressed.connect(_法阵面板.bind(d))
	详情行.add_child(命格按钮); 详情行.add_child(灵根按钮); 详情行.add_child(性格按钮); 详情行.add_child(职业按钮); 详情行.add_child(装备按钮); 详情行.add_child(法阵按钮)
	vb.add_child(详情行)
	# S1 批1：阶位操作入口（考核晋升 / 罢免阶位），仅在可授阶/有阶位时可用
	var 阶位行 := HBoxContainer.new()
	阶位行.add_theme_constant_override("separation", 4)
	var 考核钮 := Button.new(); 考核钮.text = "考核晋升"
	考核钮.add_theme_font_size_override("font_size", FONT_AUX)
	考核钮.disabled = (not d.可授阶()) or (d.考核冷却剩余 > 0) or (d.阶位索引() >= 3)
	考核钮.pressed.connect(_on_考核晋升.bind(d))
	阶位行.add_child(考核钮)
	var 罢免钮 := Button.new(); 罢免钮.text = "罢免阶位"
	罢免钮.add_theme_font_size_override("font_size", FONT_AUX)
	罢免钮.disabled = (d.阶位 == "无")
	罢免钮.pressed.connect(_on_罢免阶位.bind(d))
	阶位行.add_child(罢免钮)
	vb.add_child(阶位行)
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
	# T03 引育计划队列管理区
	御兽区.add_child(小标题("—— 引育计划队列（拨付经费） ——", 15))
	if Game.灵兽兑换队列.is_empty():
		var 空 := Label.new(); 空.text = "（未设置引育计划，点击下方按钮添加）"; 御兽区.add_child(空)
	for i in Game.灵兽兑换队列.size():
		var 条目: Dictionary = Game.灵兽兑换队列[i]
		var pc2: PanelContainer = 新面板("")
		var vb2: Control = pc2.get_child(0)
		var 模式文本: String = "泛性引育"
		var 偏好: Dictionary = 条目.get("偏好", {})
		if 偏好.get("品阶", "") != "":
			模式文本 = "定向品阶：" + Beast.品阶显示.get(偏好["品阶"], 偏好["品阶"])
		elif 偏好.get("类型", "") != "":
			模式文本 = "定向属性：" + Beast.类型中文.get(偏好["类型"], 偏好["类型"])
		var 信息 := Label.new()
		信息.text = "模式：%s | 拨付经费 %d 灵石 | %s" % [模式文本, 条目.get("cost", 0), ("启用" if 条目.get("启用", false) else "停用")]
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
	var 添加 := Button.new(); 添加.text = "＋ 新增引育计划"
	添加.pressed.connect(_弹出兑换新增)
	御兽区.add_child(添加)

# 卸下灵兽（P0-3 双槽：解除主宠/副宠契约，灵兽返回御兽堂）
func _on_卸下(弟子: Disciple, 槽位: String):
	await get_tree().process_frame
	详情.text = Game.解绑灵兽(弟子, 槽位)
	刷新御兽()

# T03 自动兑换：新增弹窗（预设偏好+阶梯消耗，一键入队）
func _弹出兑换新增():
	var 弹: Dictionary = _new_detail_popup("新增引育计划")
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, mini(360, int(get_viewport_rect().size.y * 0.7)))
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	弹["内容"].add_child(滚)
	var vb := VBoxContainer.new()
	滚.add_child(vb)
	var 说明 := Label.new()
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	说明.text = "选择引育偏好与单次拨付经费，加入引育计划队列。周期结算时自动拨付灵石，由御兽峰寻兽驯化生成兽卵。"
	vb.add_child(说明)
	var 预设: Array = [
		{"标签": "泛性引育(600)", "偏好": {}, "cost": 600},
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
			详情.text = "已添加引育计划：" + p["标签"]
			弹["遮"].queue_free()
			刷新御兽()
		)
		vb.add_child(b)
	弹["内容"].add_child(弹["关"])

# T03 引育计划：启停/删除条目
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
	var 角标色: Color = 奇遇_灰   # 普通 灰
	match 稀有度:
		"稀有": 角标色 = 奇遇_蓝   # 蓝
		"史诗": 角标色 = 奇遇_紫   # 紫
		"传说": 角标色 = 奇遇_金   # 金

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
	遮.color = 弹窗遮罩
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
	# 分类筛选标签栏（全部 / 宗门大事件 / 宗门岁纪 / 日常庶务 / 异闻 / 先贤缅怀 / 大典盛事；后二者为 WAVE-B #2 按需扩展，纯文案）
	var 分类表: Array = ["全部", "宗门大事件", "宗门岁纪", "日常庶务", "异闻", "先贤缅怀", "大典盛事"]
	var 计数: Dictionary = {}
	for 分类 in 分类表:
		计数[分类] = 0
	for 记 in Game.宗门纪事:
		var c: String = 记.get("category", "")
		计数["全部"] += 1
		if 计数.has(c):
			计数[c] += 1
	var 标签栏 := HBoxContainer.new()
	标签栏.add_theme_constant_override("separation", 4)
	for 分类 in 分类表:
		var 钮 := Button.new()
		var 选中: bool = (分类 == 纪事筛选分类)
		钮.text = "%s(%d)" % [分类, 计数.get(分类, 0)]
		钮.flat = not 选中
		钮.toggle_mode = true
		钮.button_pressed = 选中
		钮.add_theme_font_size_override("font_size", FONT_AUX)
		钮.add_theme_color_override("font_color", 暗金 if 选中 else 次墨)
		钮.pressed.connect(func():
			纪事筛选分类 = 分类
			刷新纪事()
		)
		标签栏.add_child(钮)
	纪事区.add_child(标签栏)
	var 分隔 := HSeparator.new(); 分隔.modulate.a = 0.3; 纪事区.add_child(分隔)
	for 记 in Game.宗门纪事:
		if 纪事筛选分类 != "全部" and 记.get("category", "") != 纪事筛选分类:
			continue
		var pc: PanelContainer = 新面板("")
		var vb: Control = pc.get_child(0)
		var 文案: String = 记.get("文案", "")
		var 标: String = 记.get("category", "")
		var 名: String = ("〔" + 标 + "〕" if 标 != "" else "") + 记.get("名称", "无名奇遇")
		var 弟子名: String = 记.get("弟子", "")
		var 弟子前缀: String = ("[url=disciple:%s]【%s】[/url]" % [弟子名, 弟子名] if 弟子名 != "" else "")
		if 文案.contains("[url=") or 弟子名 != "":
			# S1 点击联动 MVP：含 bbcode 链接（奇遇奖励物品）的纪事用 RichTextLabel 渲染，
			# 复用战斗日志同款 meta_clicked → open_detail_by_url 接法；不含链接的保持原 Label 行为。
			var 链接: RichTextLabel = RichTextLabel.new()
			链接.bbcode_enabled = true
			链接.fit_content = true
			链接.meta_clicked.connect(func(meta): open_detail_by_url(str(meta)))
			链接.text = "历%d日·%s%s（%s）\n%s" % [
				记.get("日", 0), 弟子前缀, 名,
				记.get("稀有度", "普通"), 文案,
			]
			vb.add_child(链接)
			纪事区.add_child(pc)
		else:
			var 信息 := Label.new()
			信息.text = "历%d日·%s%s（%s）\n%s" % [
				记.get("日", 0), 弟子前缀, 名,
				记.get("稀有度", "普通"), 文案,
			]
			信息.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(信息)
		纪事区.add_child(pc)

# ============ 测灵根过场弹窗（文字占位，动画接口预留）============
func _过场弹窗(过场: String, 人数: int):
	var 遮 := ColorRect.new()
	遮.color = 弹窗遮罩
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
	var 关 := Button.new(); 关.text = "收入外门"; 关.name = "Button_收入外门"
	关.pressed.connect(func(): _收入外门_关闭(遮, 人数))
	内容.add_child(关)
	详情.text = "接引大典进行中……"

func _收入外门_关闭(遮: Node, 人数: int):
	# 关闭弹窗与推进引导必须全部延迟：「收入外门」按钮自身是弹窗子节点，
	# 同步操作会在 pressed 回调内释放发射者/重建页面，导致 freed instance 或 UI 重叠。
	详情.text = "接引大典完成，录入 %d 名新弟子。" % 人数
	遮.call_deferred("queue_free")
	_引导_推进.call_deferred("招收")   # 推进到步④，由 _引导_刷新 统一刷新/重建页面

# ============ 建筑总览弹窗（原「堂口管理」；首发文案统一称建筑，居中面板）============
# ============ 历练征途（Day 3 灰模 UI：关卡选择→上阵→战斗结算→掉落）============
# 架构解耦：UI 仅调用 Game.挑战关卡（数据驱动逻辑层），不碰 BattleCalculator/Manager 结算核心。
# ============ S0 FTUE 引导系统（五步，纯灰模，逻辑独立封装不侵入业务）============
# 阶段语义：0=序章中 / 1=资源栏 / 2=推演 / 3=招收 / 4=查看弟子 / 5=考评 / 6=完成(或跳过)
# 事实源：Game.引导阶段（game_state 存档，老档默认=6 不强制弹）。复用 GDD-新手引导 既有设定。

# 五步引导文案（修仙化包装「宗门传承指引」；气泡与目标条共用，目标条去前缀显示）
var 引导_步骤文案: Dictionary = {
	1: "【宗门传承指引】先戳一下顶上的家底——灵石、灵草、矿石、灵气，皆是宗门命脉。",
	2: "【宗门传承指引】查看离线简报 / 等待时辰流转——宗门自会运转，堂口日积灵石灵草。",
	3: "【宗门传承指引】点「开启接引大典」，收录第一名弟子入门，宗门方有传人。",
	4: "【宗门传承指引】到「弟子」页点开一人，看看他的境界、灵根与养成去处。",
	5: "【宗门传承指引】这「离山汇总」记着你离山期间宗门变化。宗门每岁末考评、每七载大考，考得越好，灵石越多。",
}
# 序章三屏（复用 GDD-新手引导 苏清禾/吴伯 设定；仅复用台词，不新增人设字段）
var 引导_开场文本: Array = [
	{"人":"【序章·继位】", "文":"老宗主已然仙去，临终把这座破落山门托付于你。太玄宗虽已式微，根基尚在——重振山门，就在此一举。"},
	{"人":"苏清禾", "文":"掌门莫慌，妾身会一路帮衬。咱宗门的家底就那几样：灵石、灵草、矿石、灵气。先认清它们，日后才好经营。"},
	{"人":"吴伯", "文":"山下青峰一带妖兽作乱，正可遣弟子去历练长进。不过不急——掌门先推演几日、收点产出、再开接引大典广招门徒，宗门便转起来了。"},
]

func _引导_初始化():
	# 覆盖层：全屏、不拦截点击（点击穿透到下层真实按钮，强引导仅高亮不阻挡）
	if 引导_层 == null:
		引导_层 = Control.new()
		引导_层.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		引导_层.mouse_filter = Control.MOUSE_FILTER_IGNORE
		引导_层.visible = false
		add_child(引导_层)
		if 引导_跳过按钮 == null:
			引导_跳过按钮 = Button.new()
			引导_跳过按钮.text = "跳过引导"
			引导_跳过按钮.add_theme_font_size_override("font_size", FONT_AUX)
			引导_跳过按钮.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			引导_跳过按钮.offset_left = -84
			引导_跳过按钮.offset_top = 4
			引导_跳过按钮.offset_right = -8
			引导_跳过按钮.offset_bottom = 32
			引导_跳过按钮.visible = false
			引导_跳过按钮.pressed.connect(_引导_跳过)
			add_child(引导_跳过按钮)
	if 引导_目标条 == null:
		_新建目标条()
	引导_跳过按钮.visible = (Game.引导阶段 < 6)
	_刷新功能解锁()
	_刷新目标条()
	# 触发：新档开场(序章) / 中途档续接 / 完成(>=6)隐藏
	if Game.引导阶段 == 0:
		_引导_开场()
	elif Game.引导阶段 >= 1 and Game.引导阶段 <= 5:
		_引导_刷新()

func _引导_开场():
	_引导_清除()
	引导_开场段 = 0
	_引导_开场渲染()

func _引导_开场渲染():
	_引导_清除()
	var 遮 := ColorRect.new()
	遮.color = Color(暗化.r, 暗化.g, 暗化.b, 0.80)
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
	var 说话 := Label.new(); 说话.text = 段["人"]; 说话.add_theme_font_size_override("font_size", FONT_BODY); 说话.add_theme_color_override("font_color", 暗金)
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
	if Game.引导阶段 >= 6:
		return   # 已完成/跳过，不再推进
	var 期望: Dictionary = {"资源": 1, "推演": 2, "招收": 3, "查看弟子": 4, "考评": 5}
	var 目标: int = 期望.get(动作, -1)
	if 目标 == -1:
		return
	if Game.引导阶段 == 目标:
		Game.引导阶段 += 1
		Game.save_game()
	if Game.引导阶段 >= 6:
		_引导_收尾()
	else:
		_引导_刷新()

func _引导_刷新():
	_引导_清除()
	if Game.引导阶段 >= 1 and Game.引导阶段 <= 5:
		引导_跳过按钮.visible = true
	var 目标: Control = null
	var 确认动作: String = ""
	var 文案: String = 引导_步骤文案.get(Game.引导阶段, "")
	match Game.引导阶段:
		1: 目标 = 引导_状态面板
		2:
			目标 = 引导_状态面板   # 自动推演为信息步：无需点击按钮，附「知道了」确认推进
			确认动作 = "推演"
		3:
			var 过场遮: Node = get_node_or_null("测灵根过场")
			if 过场遮 != null and is_instance_valid(过场遮):
				# 弹窗已打开：步③目标变为弹窗内「收入外门」按钮
				目标 = 过场遮.find_child("Button_收入外门", true, false)
				文案 = "【宗门传承指引】点「收入外门」，将新收录弟子纳入山门。"
			else:
				# 弹窗未打开：指向弟子页·接引 Tab 的「开启接引大典」
				_弟子二级tab = 1
				_on_主导航切换(1)
				_应用_弟子二级tab()
				if not is_instance_valid(引导_招收按钮) and 当前页容器 != null:
					引导_招收按钮 = 当前页容器.find_child("Button_开启接引大典", true, false) as Button
				目标 = 引导_招收按钮
		4:
			_弟子二级tab = 0     # 先切到「名录」Tab，确保弟子卡片可见
			_on_主导航切换(1)   # 切到弟子页
			_应用_弟子二级tab()
			刷新()              # 重建弟子列表卡片（列表刚被新建，需要填充）
			if Game.弟子列表.is_empty():
				if not is_instance_valid(引导_招收按钮) and 当前页容器 != null:
					引导_招收按钮 = 当前页容器.find_child("Button_开启接引大典", true, false) as Button
				目标 = 引导_招收按钮
			else:
				var 首卡: Control = 列表.get_child(0)
				if 首卡 != null and is_instance_valid(首卡):
					目标 = 首卡.find_child("Button_选弟子", true, false)
					if 目标 == null:
						目标 = 首卡
				_自动展开首弟子()
				_招徒后高亮弟子入口()   # 招徒成功后高亮弟子入口 + 淡提示（此刻不在 pressed 回调，重建页安全）
		5:
			_弹_离山简报()       # 离线收益简报弹窗
			目标 = 离山面板
			确认动作 = "考评"
	if 目标 != null and is_instance_valid(目标):
		if 文案.strip_edges() != "":   # 防护：空白文案不渲染气泡
			_引导_显示气泡.call_deferred(目标, 文案, 确认动作)
	elif Game.引导阶段 >= 6:
		引导_跳过按钮.visible = false
	_刷新功能解锁()
	_刷新目标条()

func _引导_显示气泡(目标: Control, 文案: String, 确认动作: String = ""):
	if 文案.strip_edges() == "" or not is_instance_valid(目标):
		return   # 防护：空白文案或无效目标不渲染气泡（避免空白弹窗）
	if 引导_层 != null and 引导_层.get_parent() != null:
		引导_层.get_parent().move_child(引导_层, -1)   # 确保气泡层位于弹窗之上
	var 遮 := ColorRect.new()
	遮.color = Color(暗化.r, 暗化.g, 暗化.b, 0.35)   # 暗化 alpha 收敛到 0.35（更轻，减少被挡感）
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_IGNORE
	引导_层.add_child(遮)
	# 高亮框（透明底 + 暗金边框圈住目标，色收敛自赛博青霓）
	var 框 := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = 暗金
	sb.set_border_width_all(3)
	框.add_theme_stylebox_override("panel", sb)
	var gp: Vector2 = 目标.get_global_position()
	var lp: Vector2 = 引导_层.get_global_position()
	框.position = gp - lp
	框.size = 目标.size
	框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	引导_层.add_child(框)
	# 气泡（墨青底 + 暗金边，色收敛自赛博青霓）
	var 泡 := PanelContainer.new()
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = 墨青   # 墨青
	sb_style.border_color = 暗金
	sb_style.set_border_width_all(1)
	sb_style.set_corner_radius_all(6)
	泡.add_theme_stylebox_override("panel", sb_style)
	var 文 := Label.new(); 文.text = 文案; 文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; 文.add_theme_font_size_override("font_size", FONT_BODY); 文.add_theme_color_override("font_color", 宣纸亮)
	泡.add_child(文)
	泡.custom_minimum_size = Vector2(300, 70)
	泡.position = Vector2(框.position.x, 框.position.y + 框.size.y + 6)
	if 泡.position.y + 80 > 854:
		泡.position.y = max(4.0, 框.position.y - 90.0)
	# 信息步（步②自动推演 / 步⑤考评）：气泡附「知道了」按钮，点击即推进对应阶段
	if 确认动作 != "":
		var 知 := Button.new(); 知.text = "知道了"
		知.pressed.connect(func(): _引导_推进(确认动作))
		泡.add_child(知)
	引导_层.add_child(泡)
	引导_层.visible = true

# ===== P0 目标链系统 · 新手阶梯 UI（玉牌入口 / 宗门要务面板 / Tab 红点 / 跳转 / 数值跳字）=====
var _last_新手完成数: int = 0
var _宗门要务面板: Node = null
var _玉牌红点: Control = null

func _建_玉牌() -> Control:
	var 条 := HBoxContainer.new()
	var 牌 := Button.new()
	牌.text = "\u1F000 宗门要务"
	牌.custom_minimum_size = Vector2(0, 48)
	牌.add_theme_stylebox_override("normal", _主按钮样式())
	牌.add_theme_color_override("font_color", BTN_主字)
	牌.pressed.connect(_打开_宗门要务)
	条.add_child(牌)
	_玉牌红点 = ColorRect.new()
	_玉牌红点.color = 朱砂
	_玉牌红点.custom_minimum_size = Vector2(10, 10)
	_玉牌红点.mouse_filter = Control.MOUSE_FILTER_IGNORE
	条.add_child(_玉牌红点)
	_刷新_新手UI()
	return 条

func _打开_宗门要务():
	if _宗门要务面板 != null and is_instance_valid(_宗门要务面板):
		_宗门要务面板.queue_free()
	var 遮 := ColorRect.new()
	遮.color = 弹窗遮罩
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "宗门要务遮"
	add_child(遮)
	var 面板: PanelContainer = 新面板("宗门要务")
	面板.anchor_left = 0.5; 面板.anchor_top = 0.5; 面板.anchor_right = 0.5; 面板.anchor_bottom = 0.5
	面板.offset_left = -180; 面板.offset_top = -170; 面板.offset_right = 180; 面板.offset_bottom = 170
	遮.add_child(面板)
	var 内容: Control = 面板.get_child(0)
	_填_宗门要务(内容, 遮)
	_宗门要务面板 = 遮

func _填_宗门要务(内容: Control, 遮: Control):
	内容.add_theme_constant_override("separation", 8)
	var 进: Dictionary = Game.新手_当前进行()
	var 标题 := Label.new()
	if Game.新手_全部完成():
		标题.text = "宗门要务 · 已全部达成（%d/7）" % Game.新手_完成数()
	elif 进.is_empty():
		标题.text = "宗门要务 · 筹备中（%d/7）" % Game.新手_完成数()
	else:
		标题.text = "宗门要务 · 进行中（%d/7）" % Game.新手_完成数()
	标题.add_theme_color_override("font_color", 暗金)
	内容.add_child(标题)
	if not 进.is_empty():
		var 名 := Label.new()
		名.text = "\u25B8 %s" % 进.get("quest_name", "")
		名.add_theme_font_size_override("font_size", FONT_PANEL)
		名.add_theme_color_override("font_color", 玉石绿)
		内容.add_child(名)
		var 描 := Label.new()
		描.text = 进.get("target_desc", "")
		描.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		描.add_theme_color_override("font_color", 宣纸亮)
		内容.add_child(描)
		var 是主动: bool = (进.get("is_auto_trigger", "true") != "true")
		if 是主动 and not 进.get("jump_path", "").is_empty():
			var 往 := Button.new(); 往.text = "前往处理"
			往.add_theme_stylebox_override("normal", _主按钮样式())
			往.add_theme_color_override("font_color", BTN_主字)
			往.pressed.connect(func():
				var 路: String = 进.get("jump_path", "")
				if 遮 != null and is_instance_valid(遮):
					遮.queue_free()
				_跳转(路)
			)
			内容.add_child(往)
		else:
			var 态 := Label.new()
			态.text = "（自动达成中，静候机缘）"
			态.add_theme_color_override("font_color", 次墨)
			内容.add_child(态)
	var 完成 := Label.new()
	完成.text = "已完成：%s" % "、".join(Game.新手完成列表)
	完成.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	完成.add_theme_color_override("font_color", 次墨)
	内容.add_child(完成)
	var 关 := Button.new(); 关.text = "关闭"
	关.add_theme_stylebox_override("normal", _次按钮样式())
	关.add_theme_color_override("font_color", BTN_次字)
	关.pressed.connect(func():
		if 遮 != null and is_instance_valid(遮):
			遮.queue_free()
	)
	内容.add_child(关)

func _刷新_新手UI():
	if _玉牌红点 != null and is_instance_valid(_玉牌红点):
		_玉牌红点.visible = Game.新手_有红点()
	if 标签栏 != null and is_instance_valid(标签栏):
		var 点 := 标签栏.get_node_or_null("新手红点")
		if 点 == null:
			点 = ColorRect.new()
			点.name = "新手红点"
			点.color = 朱砂
			点.custom_minimum_size = Vector2(10, 10)
			点.mouse_filter = Control.MOUSE_FILTER_IGNORE
			标签栏.add_child(点)
		var 有: bool = Game.新手_有红点() or _有未领日常()
		点.visible = 有
		if 有 and 标签栏.get_tab_count() > 0:
			var 矩: Rect2 = 标签栏.get_tab_rect(0)
			点.position = Vector2(矩.position.x + 矩.size.x - 14, 矩.position.y + 6)
	if Game.新手_完成数() > _last_新手完成数:
		if Game.新手_完成数() > 0:
			_数值跳字(self, "宗门要务 第%d项达成" % Game.新手_完成数(), 玉石绿)
		_last_新手完成数 = Game.新手_完成数()
	if _宗门要务面板 != null and is_instance_valid(_宗门要务面板):
		var pn: Node = _宗门要务面板.get_child(0)
		if pn != null and is_instance_valid(pn):
			for c in pn.get_children():
				c.queue_free()
			_填_宗门要务(pn, _宗门要务面板)

func _有未领日常() -> bool:
	for i in Game.当前日常.size():
		if i < Game.日常已领.size() and not Game.日常已领[i]:
			return true
	return false

func _跳转(路: String):
	if 路.is_empty():
		return
	var 段: PackedStringArray = 路.split("/")
	var 页: String = 段[0]
	match 页:
		"宗门":
			_on_主导航切换(0)
			if 段.size() > 1 and 段[1] == "收益栏":
				_进_二级页("账册")
		"弟子":
			if 段.size() > 1:
				match 段[1]:
					"接引": _弟子二级tab = 1
					"名录": _弟子二级tab = 0
					"详情": _弟子二级tab = 0
			_on_主导航切换(1)
		"历练": _on_主导航切换(3)
		"纪事": _on_主导航切换(4)
		"御兽": _on_主导航切换(2)
		_: _on_主导航切换(0)

func _数值跳字(父: Control, 文本: String, 色: Color):
	if 父 == null or not is_instance_valid(父):
		return
	var 跳 := Label.new()
	跳.text = 文本
	跳.add_theme_font_size_override("font_size", FONT_PANEL_B)
	跳.add_theme_color_override("font_color", 色)
	跳.mouse_filter = Control.MOUSE_FILTER_IGNORE
	父.add_child(跳)
	跳.position = Vector2(max(8, 父.size.x / 2 - 70), 40)
	var t: Tween = create_tween()
	t.tween_property(跳, "position", Vector2(跳.position.x, 跳.position.y - 60), 1.2)
	t.parallel().tween_property(跳, "modulate:a", 0.0, 1.2)
	t.tween_callback(跳.queue_free)

func _引导_收尾():
	if _引导已收尾:
		return   # 已播过，不再重复弹
	_引导已收尾 = true
	_引导_清除()
	var 弹窗遮: Node = get_node_or_null("离山简报遮")
	if 弹窗遮 != null and is_instance_valid(弹窗遮):
		_关_离山简报()
	var 遮 := ColorRect.new()
	遮.color = Color(暗化.r, 暗化.g, 暗化.b, 0.35)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_IGNORE
	引导_层.add_child(遮)
	var 泡 := PanelContainer.new()
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = 墨青   # 墨青
	sb_style.border_color = 暗金
	sb_style.set_border_width_all(1)
	sb_style.set_corner_radius_all(6)
	泡.add_theme_stylebox_override("panel", sb_style)
	泡.custom_minimum_size = Vector2(340, 120)
	var 文 := Label.new()
	文.text = "【宗门初立指南】掌门既已立足，宗门初立，诸事待举。谨奉三策：\n一、开坛接引，广纳门人；\n二、稽核收益，开源节流；\n三、遣徒历练，访道寻机。\n愿掌门循序渐进，早壮玄门。"
	文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	文.add_theme_color_override("font_color", 宣纸亮)
	泡.add_child(文)
	var 跳行 := HBoxContainer.new()
	var 跳1 := Button.new(); 跳1.text = "前往·接引弟子"
	跳1.add_theme_stylebox_override("normal", _主按钮样式())
	跳1.add_theme_color_override("font_color", BTN_主字)
	跳1.pressed.connect(func(): _引导_清除(); _跳转("弟子/接引"))
	var 跳2 := Button.new(); 跳2.text = "查看·宗门收益"
	跳2.add_theme_stylebox_override("normal", _主按钮样式())
	跳2.add_theme_color_override("font_color", BTN_主字)
	跳2.pressed.connect(func(): _引导_清除(); _跳转("宗门/收益栏"))
	var 跳3 := Button.new(); 跳3.text = "开启·历练"
	跳3.add_theme_stylebox_override("normal", _主按钮样式())
	跳3.add_theme_color_override("font_color", BTN_主字)
	跳3.pressed.connect(func(): _引导_清除(); _跳转("历练/秘境"))
	跳行.add_child(跳1); 跳行.add_child(跳2); 跳行.add_child(跳3)
	泡.add_child(跳行)
	var 关 := Button.new(); 关.text = "知道了"
	关.add_theme_stylebox_override("normal", _次按钮样式())
	关.add_theme_color_override("font_color", BTN_次字)
	关.pressed.connect(func(): _引导_清除())
	泡.add_child(关)
	泡.position = Vector2(90, 360)
	引导_层.add_child(泡)
	引导_层.visible = true
	引导_跳过按钮.visible = false
	Game.引导阶段 = 6
	Game.激活新手目标链()
	Game.save_game()
	_刷新功能解锁()   # 点亮灰锁按钮（坊市/任务/历练/御兽）
	_刷新目标条()      # 隐藏常驻目标条
	_清除招徒高亮()

func _引导_跳过():
	Game.引导阶段 = 6
	Game.激活新手目标链()
	Game.save_game()
	_引导_清除()
	var 遮: Node = get_node_or_null("离山简报遮")
	if 遮 != null and is_instance_valid(遮):
		_关_离山简报()
	if 引导_跳过按钮 != null and is_instance_valid(引导_跳过按钮):
		引导_跳过按钮.visible = false
	_刷新功能解锁()
	_刷新目标条()
	_清除招徒高亮()
	if 详情 != null and is_instance_valid(详情):
		详情.text = "（已跳过新手引导）"

func _引导_清除():
	if 引导_层 == null:
		return
	for c in 引导_层.get_children():
		c.queue_free()
	引导_层.visible = false

# —— 标题屏（在 _ready 最前拦截）——
func _显示标题():
	引导_标题层 = Control.new()
	引导_标题层.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	引导_标题层.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(引导_标题层)
	var 遮 := ColorRect.new()
	遮.color = 墨底半透   # 墨青半透
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_IGNORE
	引导_标题层.add_child(遮)
	var pc: PanelContainer = 新面板("")
	pc.anchor_left = 0.5; pc.anchor_top = 0.5; pc.anchor_right = 0.5; pc.anchor_bottom = 0.5
	pc.offset_left = -200; pc.offset_top = -150; pc.offset_right = 200; pc.offset_bottom = 150
	pc.custom_minimum_size = Vector2(400, 300)
	pc.add_theme_stylebox_override("panel", _暗墨面板())
	var 内容: Control = pc.get_child(0)
	var 名 := Label.new()
	名.text = "太玄宗"
	名.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	名.add_theme_font_size_override("font_size", FONT_TITLE)
	名.add_theme_color_override("font_color", 暗金)
	var 标语 := Label.new()
	标语.text = "执掌太玄宗——从一座破落山门，重振仙宗。"
	标语.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	标语.add_theme_font_size_override("font_size", FONT_BODY)
	标语.add_theme_color_override("font_color", 次墨)
	var 角注 := Label.new()
	角注.text = "又名：开局接手太玄宗"
	角注.add_theme_font_size_override("font_size", FONT_AUX)
	角注.add_theme_color_override("font_color", 次墨)
	内容.add_child(名); 内容.add_child(标语); 内容.add_child(角注)
	var 有档: bool = FileAccess.file_exists("user://save.json")
	var 开新 := Button.new()
	开新.text = "开新宗门"
	开新.add_theme_stylebox_override("normal", _主按钮样式())
	开新.add_theme_color_override("font_color", BTN_主字)
	开新.pressed.connect(_标题_开新宗门)
	var 继续 := Button.new()
	继续.text = "继续"
	继续.visible = 有档
	继续.add_theme_stylebox_override("normal", _次按钮样式())
	继续.add_theme_color_override("font_color", BTN_次字)
	继续.pressed.connect(_标题_继续)
	内容.add_child(开新); 内容.add_child(继续)
	引导_标题层.add_child(pc)

func _标题_继续():
	Game.load_game()
	_标题_关闭()
	_进入主界面()

func _标题_开新宗门():
	_标题_确认弹窗()

func _标题_确认弹窗():
	var 遮 := ColorRect.new()
	遮.color = Color(暗化.r, 暗化.g, 暗化.b, 0.6)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "确认重开"
	引导_标题层.add_child(遮)
	var pc: PanelContainer = 新面板("确定重开宗门？")
	pc.anchor_left = 0.5; pc.anchor_top = 0.5; pc.anchor_right = 0.5; pc.anchor_bottom = 0.5
	pc.offset_left = -160; pc.offset_top = -90; pc.offset_right = 160; pc.offset_bottom = 90
	pc.custom_minimum_size = Vector2(320, 180)
	var 内容: Control = pc.get_child(0)
	var 提示 := Label.new()
	提示.text = "当前进度将清空，确定重开？"
	提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	内容.add_child(提示)
	var 行 := HBoxContainer.new()
	var 确 := Button.new(); 确.text = "确定重开"; 确.add_theme_stylebox_override("normal", _危险按钮样式()); 确.add_theme_color_override("font_color", BTN_危险字)
	确.pressed.connect(func():
		pc.queue_free(); 遮.queue_free(); Game.new_game(); _标题_关闭(); _进入主界面())
	var 取 := Button.new(); 取.text = "取消"
	取.pressed.connect(func(): pc.queue_free(); 遮.queue_free())
	行.add_child(确); 行.add_child(取)
	内容.add_child(行)
	引导_标题层.add_child(pc)

func _标题_关闭():
	if 引导_标题层 != null and is_instance_valid(引导_标题层):
		引导_标题层.queue_free()
		引导_标题层 = null

func _进入主界面():
	var 报: String = Game.推演至现在()   # 自动推演：加载时推进到当前时刻
	# FTUE 保底：新档真实流逝≈0，保底推进 1 游戏日，确保离线简报有内容、引导有正反馈
	if Game.引导阶段 >= 1 and Game.引导阶段 <= 5 and Game.累计游戏日 == 0:
		Game.推演一月(1)
	刷新()
	_引导_初始化()
	# 离线简报：仅正式版/老档（引导已完成）进游戏即弹。FTUE 进行中（引导阶段<6）不在此弹，
	# 留给步⑤「离山汇总」统一呈现，避免弹窗遮罩挡住引导交互（自动推演保底使新档累计游戏日=1）
	if Game.累计游戏日 > 0 and Game.引导阶段 >= 6:
		_弹_离山简报()

func _on_状态面板_点击(e: InputEvent):
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		_引导_推进("资源")

func _on_离山面板_点击(e: InputEvent):
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		_引导_推进("考评")

# 解锁主条件：FTUE 完成（引导阶段>=6）或 门派 Lv>=3（兜底防卡死）
# 梯度（主理人裁定）：坊市 FTUE 后立开；任务 Lv>=2；历练/御兽 主条件
func _功能解锁(名: String) -> bool:
	match 名:
		"坊市": return Game.引导阶段 >= 6 or Game.门派等级 >= 3
		"任务": return Game.门派等级 >= 2 or Game.引导阶段 >= 6
		"历练", "御兽": return Game.引导阶段 >= 6 or Game.门派等级 >= 3
		_: return Game.引导阶段 >= 6 or Game.门派等级 >= 3

func _灰锁提示(名: String) -> String:
	match 名:
		"坊市": return "完成新手引导后开启坊市"
		"任务": return "宗门 Lv.2 后开启师门事务"
		"历练": return "宗门 Lv.3 或完成引导后开启历练"
		"御兽": return "御兽堂 Lv.3 开启"
		_: return "后续开启"

func _刷新功能解锁():
	# 二级页受锁入口（坊市/任务）：disabled+🔒+tooltip，点击不跳转
	# 关键修复：页面切换时（如 FTUE 切到弟子页）宗门网格按钮会被释放，引导_坊市按钮/任务按钮
	# 会变成 dangling freed ref；直接强类型 var b: Button = 规则[名] 会触发"assign invalid previously freed instance"。
	# 改用条件构建+无类型变量，只操作仍存活的实例。
	var 规则: Dictionary = {}
	if is_instance_valid(引导_坊市按钮):
		规则["坊市"] = 引导_坊市按钮
	if is_instance_valid(引导_任务按钮):
		规则["任务"] = 引导_任务按钮
	for 名 in 规则:
		var b = 规则[名]   # 不声明为 Button：字典 value 若变质不阻塞，后续 is_instance_valid 再过滤
		if b == null or not is_instance_valid(b):
			continue
		if not _灰锁原文本.has(名):
			_灰锁原文本[名] = b.text
		var 开: bool = _功能解锁(名)
		b.disabled = not 开
		if 开:
			b.text = _灰锁原文本[名]
			b.tooltip_text = ""
			b.modulate.a = 1.0
		else:
			b.text = "🔒 " + _灰锁原文本[名]
			b.tooltip_text = _灰锁提示(名)
			b.modulate.a = 0.5
	# 受锁核心 Tab（御兽/历练）：disabled + 🔒 文字 + tooltip，置灰可显（§1.5）
	if 标签栏 != null:
		for 名 in ["御兽", "历练"]:
			var idx: int = 页名.find(名)
			if idx < 0:
				continue
			var 锁: bool = not _功能解锁(名)
			标签栏.set_tab_disabled(idx, 锁)
			if 锁:
				标签栏.set_tab_title(idx, "🔒 " + 名)
			else:
				标签栏.set_tab_title(idx, 名)

func _刷新目标条():
	if 引导_目标条 == null:
		return
	if Game.引导阶段 < 1 or Game.引导阶段 > 5:
		引导_目标条.visible = false
		return
	引导_目标条.visible = true
	var 步: int = Game.引导阶段
	var 文案: String = 引导_步骤文案.get(步, "")
	if 文案.begins_with("【宗门传承指引】"):
		文案 = 文案.trim_prefix("【宗门传承指引】")   # 目标条文案去前缀
	引导_目标条_文.text = "当前目标 · 第 %d/5 步：%s" % [步, 文案]

func _新建目标条():
	引导_目标条 = PanelContainer.new()
	引导_目标条.anchor_left = 0.0
	引导_目标条.anchor_top = 0.0
	引导_目标条.anchor_right = 1.0
	引导_目标条.anchor_bottom = 0.0
	引导_目标条.offset_left = 8
	引导_目标条.offset_top = 4
	引导_目标条.offset_right = -92
	引导_目标条.offset_bottom = 48
	引导_目标条.custom_minimum_size = Vector2(0, 44)   # 点击区≥44px
	var sb := StyleBoxFlat.new()
	sb.bg_color = 墨底半透
	sb.border_color = 暗金
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	引导_目标条.add_theme_stylebox_override("panel", sb)
	var 内 := VBoxContainer.new()
	引导_目标条_文 = Label.new()
	引导_目标条_文.add_theme_font_size_override("font_size", FONT_BODY)
	引导_目标条_文.add_theme_color_override("font_color", 宣纸亮)
	引导_目标条_文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	内.add_child(引导_目标条_文)
	引导_目标条.add_child(内)
	引导_目标条.visible = false
	add_child(引导_目标条)

func _招徒后高亮弟子入口():
	_招徒后_弟子高亮中 = true
	# 仅当当前不在弟子页时才切页（避免引导刷新已切页后重复重建，也隔绝 pressed 回调内重建风险）
	if 当前页名 != "弟子":
		_on_主导航切换(1)
	if 弟子页头 != null and is_instance_valid(弟子页头):
		弟子页头.modulate = 暗金   # 高亮弟子页头
	if 引导_弟子提示 != null and is_instance_valid(引导_弟子提示):
		引导_弟子提示.visible = true   # 淡提示「可前往查看弟子详情」

func _自动展开首弟子():
	if _弟子详情_已自动展开:
		return
	if Game.弟子列表.size() > 0:
		_弟子详情_已自动展开 = true
		当前选中 = Game.弟子列表[0]
		详情.text = Game.弟子列表[0].简介()   # 自动展开首名弟子详情（不自动完成步④）

func _清除招徒高亮():
	_招徒后_弟子高亮中 = false
	if 引导_弟子提示 != null:
		引导_弟子提示.visible = false
	if 弟子页头 != null:
		弟子页头.modulate = Color.WHITE

func _主按钮样式() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BTN_主底
	s.border_color = BTN_主边
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	return s

func _次按钮样式() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BTN_次底
	s.border_color = BTN_次边
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	return s

func _标签按钮样式() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BTN_标签底
	s.border_color = BTN_标签边
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	return s

func _危险按钮样式() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BTN_危险底
	s.border_color = BTN_危险边
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	return s

func _on_历练():
	_on_主导航切换(3)

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
	头.add_theme_font_size_override("font_size", FONT_PANEL_B)
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
			装备标签.append_text("[color=#%s]— 空 —[/color]" % 次墨.to_html(false))
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
				信息.append_text("%s［%s］·%s·[color=#%s]+%d[/color]" % [it.名称, it.品阶, Item.槽显示.get(it.穿戴位, it.穿戴位), 颜色_良品.to_html(false), it.战力加成])
			elif _是阵图物品(it):
				信息.append_text("%s［%s］[color=#%s]（阵图·可使用）[/color]" % [it.名称, it.品阶, 次墨.to_html(false)])
			else:
				信息.append_text("%s［%s］[color=#%s]（不可穿戴）[/color]" % [it.名称, it.品阶, 次墨.to_html(false)])
			行.add_child(信息)
			if it.可穿戴():
				var 穿 := Button.new()
				穿.text = "穿戴"
				穿.pressed.connect(_穿戴装备.bind(d, it))
				行.add_child(穿)
				列.add_child(行)
			elif _是阵图物品(it):
				var 用 := Button.new()
				用.text = "使用"
				用.pressed.connect(_使用阵图.bind(d, it))
				行.add_child(用)
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

# ============ S1 批6-B：单人法阵面板（Layer2 常驻属性；独立字段 当前法阵，不入 装备 Dictionary）============
func _法阵面板(d: Disciple):
	if 法阵面板节点 != null:
		法阵面板节点.queue_free()
	var 遮 := ColorRect.new()
	遮.color = 墨底
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	遮.name = "法阵面板"
	add_child(遮)
	法阵面板节点 = 遮
	var 大 := PanelContainer.new()
	大.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	大.offset_left = 12; 大.offset_right = -12; 大.offset_top = 36; 大.offset_bottom = -12
	大.add_theme_stylebox_override("panel", _暗墨面板())
	遮.add_child(大)
	var 内容 := VBoxContainer.new()
	大.add_child(内容)
	var 头 := Label.new()
	头.text = "☯ 法阵 · %s" % d.姓名
	头.add_theme_font_size_override("font_size", FONT_PANEL_B)
	头.add_theme_color_override("font_color", 暗金)
	内容.add_child(头)
	# 当前装备法阵
	var 当前id: String = d.当前法阵.get("array_id", "")
	if 当前id != "":
		var 当前cfg: Dictionary = Game.阵法配置表.get(当前id, {})
		var 当前级: int = int(d.当前法阵.get("等级", 1))
		var 行 := Label.new()
		行.text = "当前：%s · %d级\n%s" % [当前cfg.get("array_name", 当前id), 当前级, _法阵效果文案(当前cfg, 当前级, d)]
		行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		行.add_theme_color_override("font_color", 玉石绿)
		内容.add_child(行)
	else:
		var 空 := Label.new()
		空.text = "— 未布阵 —"
		空.add_theme_color_override("font_color", 次墨)
		内容.add_child(空)
	var 滚 := ScrollContainer.new()
	滚.custom_minimum_size = Vector2(0, 420)
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	内容.add_child(滚)
	var 列 := VBoxContainer.new()
	列.add_theme_constant_override("separation", 4)
	滚.add_child(列)
	列.add_child(小标题("—— 可布法阵（按身份阶别） ——", 15))
	# 遍历阵法配置表 person 行（身份阶别锁：外门禁 / 内门·核心凡阶 / 亲传灵阶+ / 长老无限制，D6）
	for aid in Game.阵法配置表.keys():
		var row: Dictionary = Game.阵法配置表[aid]
		if row.get("array_type", "") != "person":
			continue
		var 阶: String = row.get("rank", "")
		var 可装备: bool = _法阵可装备身份(d.身份, 阶)
		var 行2 := HBoxContainer.new()
		行2.add_theme_constant_override("separation", 6)
		var 名 := Label.new()
		名.text = "%s［%s］" % [row.get("array_name", aid), 阶]
		名.custom_minimum_size.x = 130
		名.add_theme_color_override("font_color", 青灰 if 可装备 else 按钮禁用)
		行2.add_child(名)
		var 效 := Label.new()
		效.text = _法阵效果文案(row, 1, d)
		效.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		效.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		效.add_theme_color_override("font_color", 青灰 if 可装备 else 按钮禁用)
		行2.add_child(效)
		if 可装备:
			if aid == 当前id:
				var 升级钮 := Button.new(); 升级钮.text = "升级"
				升级钮.pressed.connect(_法阵升级.bind(d, aid))
				行2.add_child(升级钮)
				var 拆解钮 := Button.new(); 拆解钮.text = "拆解"
				拆解钮.pressed.connect(_法阵拆解.bind(d, aid))
				行2.add_child(拆解钮)
			else:
				if Game._弟子已解锁法阵(d.姓名, aid):
					var 装备钮 := Button.new(); 装备钮.text = "装备"
					装备钮.pressed.connect(_法阵装备.bind(d, aid))
					行2.add_child(装备钮)
				else:
					var 需解 := Label.new()
					需解.text = "（需使用%s解锁）" % Game.阵法_按阵法.get(aid, "对应阵图")
					需解.add_theme_color_override("font_color", 按钮禁用)
					行2.add_child(需解)
		else:
			var 需求 := Label.new()
			需求.text = "（%s）" % _法阵需求身份(阶)
			需求.add_theme_color_override("font_color", 按钮禁用)
			行2.add_child(需求)
		列.add_child(行2)
	var 关 := Button.new()
	关.text = "归藏"
	关.pressed.connect(func():
		if 法阵面板节点 != null:
			法阵面板节点.queue_free()
		法阵面板节点 = null)
	内容.add_child(关)

# 身份阶别锁（D6，对齐真实 5 级 身份层级序）：common→内门弟子(idx1) / spirit→亲传弟子(idx3) / treasure→无限制
func _法阵可装备身份(身份: String, 阶: String) -> bool:
	var idx: int = Disciple.身份层级序.find(身份)
	if idx < 0:
		return false
	if 阶 == "common":
		return idx >= 1         # 外门禁；内门弟子/核心弟子=凡阶
	if 阶 == "spirit":
		return idx >= 3         # 亲传弟子及以上（核心弟子与内门同档，仅凡阶）
	return true                # treasure → 长老无限制

func _法阵需求身份(阶: String) -> String:
	if 阶 == "common":
		return "需内门弟子+"
	if 阶 == "spirit":
		return "需亲传弟子+"
	return "需长老"

# 法阵效果文案（百分比加成 + 灵根契合标识）；基数取自 arm 等级，[PLACEHOLDER] 真机校准
# S2 占位标记：战后触发类（回血/回蓝）S1 属性等效或纯占位，面板须明示未激活，避免玩家预期落差（R1 文案铺垫）
func _法阵效果文案(row: Dictionary, 级: int, d: Disciple) -> String:
	var dim: String = row.get("eff_dim", "")
	var trigger: String = row.get("trigger", "")
	var base: float = float(row.get("eff_val_base", "0")) * (1.0 + (级 - 1) * float(row.get("level_growth_coef", "0")))
	base = clamp(base, 0.0, 0.15)
	var 匹配: String = ""
	if d._灵根匹配法阵(row):
		匹配 = "（灵根契合+5%）"
	# 战后触发类：S1 未接线，文案明示 S2 开放，不显示虚假加成（回血 S1 数值=0）
	if trigger == "post_battle":
		if dim == "血":
			return "（战后回血·S2开放）%s" % 匹配
		return "%s上限 %+.1f%%（战后恢复·S2开放）%s" % [dim, base * 100.0, 匹配]
	return "%s %+.1f%%%s" % [dim, base * 100.0, 匹配]

func _法阵装备(d: Disciple, aid: String):
	if not Game._弟子已解锁法阵(d.姓名, aid):
		_toast("需先使用对应阵图解锁后方可布阵")
		return
	d.当前法阵 = {"array_id": aid, "等级": 1}
	_toast("%s 已布阵" % Game.阵法配置表.get(aid, {}).get("array_name", aid))
	_法阵面板(d)   # 重建刷新

func _法阵升级(d: Disciple, aid: String):
	if d.当前法阵.get("array_id", "") != aid:
		return
	var 当前级: int = int(d.当前法阵.get("等级", 1))
	var cfg: Dictionary = Game.阵法配置表.get(aid, {})
	var 上限: int = int(cfg.get("max_level", 10))
	if 当前级 >= 上限:
		_toast("%s 已达法阵上限" % cfg.get("array_name", aid))
		return
	var 消耗: int = Game._阵法升级消耗(aid, 当前级)
	var 现有: int = Game._统计阵纹碎片(d)
	if 现有 < 消耗:
		_toast("阵纹碎片不足：升级至 %d 级需 %d，现有 %d" % [当前级 + 1, 消耗, 现有])
		return
	Game._扣除阵纹碎片(d, 消耗)
	d.当前法阵["等级"] = 当前级 + 1
	_toast("%s 升至 %d 级（消耗阵纹碎片 %d）" % [cfg.get("array_name", aid), d.当前法阵["等级"], 消耗])
	_法阵面板(d)

func _法阵拆解(d: Disciple, aid: String):
	if d.当前法阵.get("array_id", "") != aid:
		return
	var 当前级: int = int(d.当前法阵.get("等级", 1))
	if 当前级 < 2:
		_toast("一级法阵无需拆解")
		return
	var 返: int = Game._阵法拆解返还数(aid, 当前级)
	Game._发放阵纹碎片(d, 返)
	d.当前法阵 = {}
	_toast("%s 已拆解，返还阵纹碎片×%d" % [Game.阵法配置表.get(aid, {}).get("array_name", aid), 返])
	_法阵面板(d)

# ============ S1 批6-D5：阵图使用流（D5 闭环入口）============
# 背包内 Item 仅携带 名称，故按 名称 命中 阵法物品名表 识别阵图类（use_type=unlock_array）
func _是阵图物品(it: Item) -> bool:
	if it == null:
		return false
	var row: Dictionary = Game.阵法物品名表.get(it.名称, {})
	return not row.is_empty() and row.get("use_type", "") == "unlock_array"

# 阵图使用：校验 unlock_array_id ↔ array_config；未解锁→消耗并解锁；已解锁→折算碎片返还
func _使用阵图(d: Disciple, it: Item):
	if it == null:
		return
	var row: Dictionary = Game.阵法物品名表.get(it.名称, {})
	if row.is_empty() or row.get("use_type", "") != "unlock_array":
		_toast("该物品暂不可使用")
		return
	var aid: String = row.get("unlock_array_id", "")
	if aid == "" or not Game.阵法配置表.has(aid):
		_toast("阵图数据异常：未找到对应阵法")
		return
	var cfg: Dictionary = Game.阵法配置表[aid]
	var atype: String = cfg.get("array_type", "")
	# 宗门大阵（品级解锁）/ 组队结阵（S2 开放）阵图：不直接解锁，折算为阵纹碎片返还
	if atype != "person":
		var 级: int = 1
		if d.当前法阵.get("array_id", "") == aid:
			级 = int(d.当前法阵.get("等级", 1))
		var 返: int = Game._阵法拆解返还数(aid, 级)
		d.背包.erase(it)
		Game._发放阵纹碎片(d, 返)
		if atype == "sect":
			_toast("%s 由宗门品级解锁，阵图折算为阵纹碎片×%d" % [cfg.get("array_name", aid), 返])
		else:
			_toast("%s（组队结阵 S2 开放）阵图折算为阵纹碎片×%d" % [cfg.get("array_name", aid), 返])
		_装备面板(d)
		return
	# 单人法阵：已解锁→折算碎片（不重复解锁）；未解锁→消耗阵图并解锁
	if Game._弟子已解锁法阵(d.姓名, aid):
		var 级: int = 1
		if d.当前法阵.get("array_id", "") == aid:
			级 = int(d.当前法阵.get("等级", 1))
		var 返: int = Game._阵法拆解返还数(aid, 级)
		d.背包.erase(it)
		Game._发放阵纹碎片(d, 返)
		_toast("%s 已解锁，阵图折算为阵纹碎片×%d" % [cfg.get("array_name", aid), 返])
		_装备面板(d)
		return
	# 未解锁：消耗阵图，加入已解锁集合
	d.背包.erase(it)
	Game._解锁弟子法阵(d.姓名, aid)
	_toast("已解锁单人法阵：%s（可前往法阵面板布阵）" % cfg.get("array_name", aid))
	_装备面板(d)

# ============ S0 坊市（商店）：消耗灵石出口 ============
func _on_坊市():
	_建_二级页("坊市")

# 玄玉加速占位按钮（S0 stub：置灰，不生效，S1 接付费）
func _玄玉占位按钮() -> Button:
	var b := Button.new()
	b.text = "玄玉加速（敬请期待）"
	b.disabled = true
	b.tooltip_text = "付费便利功能，后续版本开放"
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.modulate.a = 0.6
	return b

# WAVE-C #3：先贤祠二级页（纯展示，读取 Game.先贤堂；零数值，传承 deferred；B2 二级下沉，无新一级按钮）
func _填_先贤祠页(内容: Control):
	var 头 := Label.new()
	头.text = "先贤祠"
	头.add_theme_font_size_override("font_size", FONT_PANEL_B)
	头.add_theme_color_override("font_color", 暗金)
	内容.add_child(头)
	var 概 := Label.new()
	概.text = "魂归山门，英名长存——坐化弟子于此留名（纯展示，不触发任何数值）。"
	概.add_theme_color_override("font_color", 次墨)
	内容.add_child(概)
	if Game.先贤堂.is_empty():
		var 空 := Label.new(); 空.text = "（尚无先贤入册）"
		空.add_theme_color_override("font_color", 青灰)
		内容.add_child(空)
		return
	var 列 := VBoxContainer.new()
	列.add_theme_constant_override("separation", 6)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	内容.add_child(列)
	for 贤 in Game.先贤堂:
		var 卡 := PanelContainer.new()
		卡.add_theme_stylebox_override("panel", _暗墨面板())
		var 文: VBoxContainer = 卡.get_child(0)
		var 名: String = 贤.get("姓名", "无名")
		var 境: String = 贤.get("境界", "")
		var 日: int = int(贤.get("坐化日", 0))
		var 摘: String = 贤.get("事迹摘要", "")
		var 标题 := Label.new()
		标题.text = "〔先贤〕%s（%s）· 坐化于第%d日" % [名, 境, 日]
		标题.add_theme_color_override("font_color", 暗金)
		文.add_child(标题)
		var 摘要 := Label.new()
		摘要.text = 摘
		摘要.add_theme_color_override("font_color", 次墨)
		摘要.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		文.add_child(摘要)
		# 点击查看该先贤的宗门纪事时间线（复用 #2 取弟子纪事）
		var 查 := Button.new(); 查.text = "查看%s的纪事" % 名
		查.custom_minimum_size = Vector2(0, 36)
		var ID: int = int(贤.get("弟子ID", 0))
		查.pressed.connect(func():
			var 纪: Array = Game.取弟子纪事(ID, 名)
			_弹_先贤纪事(名, 纪)
		)
		文.add_child(查)
		列.add_child(卡)

# WAVE-C #3：先贤纪事时间线弹窗（复用 _new_detail_popup；纯展示）
func _弹_先贤纪事(姓名: String, 纪: Array):
	var 弹: Dictionary = _new_detail_popup("先贤·%s 的纪事" % 姓名)
	var 内容: VBoxContainer = 弹["内容"]
	if 纪.is_empty():
		var 空 := Label.new(); 空.text = "（暂无该先贤的纪事）"
		空.add_theme_color_override("font_color", 青灰)
		内容.add_child(空)
		return
	for 记 in 纪:
		var 行 := Label.new()
		var 日: int = int(记.get("日", 0))
		var 文: String = 记.get("文案", "")
		var 类: String = 记.get("category", "")
		var 标: String = ("〔%s〕" % 类) if 类 != "" else ""
		行.text = "· 第%d日 %s%s" % [日, 标, 文]
		行.add_theme_color_override("font_color", 次墨)
		行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		内容.add_child(行)

func _填_坊市页(内容: Control):
	# WAVE-C #7：集市状态一致性——若当前窗口状态与已上架标记不符，强制刷新（仅刷新规则，零经济）
	if Game.宗门集市_激活中() != Game.坊市上架_集市标记:
		Game.刷新坊市上架()
	if Game.坊市上架集.is_empty():
		Game.刷新坊市上架()
	# WAVE-C #7：宗门集市状态面板（叠加展示，不新增一级按钮；手续费/声望为显示态，价格/限购通道不变）
	if Game.宗门集市_激活中():
		var 配: Dictionary = Game.宗门集市_配置()
		var 状态 := PanelContainer.new()
		状态.add_theme_stylebox_override("panel", _暗墨面板())
		var 状文: VBoxContainer = 状态.get_child(0)
		var 状标 := Label.new(); 状标.text = "宗门集市·开启中（每月 %d-%d 日）" % [int(配.get("激活日", 15)), int(配.get("激活日", 15)) + int(配.get("持续天数", 3)) - 1]
		状标.add_theme_color_override("font_color", 暗金)
		状文.add_child(状标)
		var 状描 := Label.new()
		状描.text = "商品数量×%s；稀有商队入驻；手续费系数 %s、声望系数 %s（集市特惠·显示态）" % [配.get("商品倍率", 2.0), 配.get("手续费系数", 0.9), 配.get("声望系数", 1.2)]
		状描.add_theme_color_override("font_color", 次墨)
		状描.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		状文.add_child(状描)
		内容.add_child(状态)
	var 结果 := Label.new(); 结果.text = _坊市提示; 内容.add_child(结果)
	var 滚 := ScrollContainer.new(); 滚.custom_minimum_size = Vector2(380, 400); 内容.add_child(滚)
	var 列 := VBoxContainer.new(); 滚.add_child(列)
	_刷新坊市列表(列, 结果)
	# 玄玉专区占位（S0 stub：置灰，敬请期待）
	var 玄玉分隔 := HSeparator.new(); 玄玉分隔.modulate.a = 0.4; 内容.add_child(玄玉分隔)
	var 玄玉标题 := Label.new(); 玄玉标题.text = "—— 玄玉专区（后续版本开放） ——"; 玄玉标题.modulate.a = 0.5; 内容.add_child(玄玉标题)
	for r in Game._玄玉表():
		var b := Button.new()
		b.text = "%s（%d 玄玉）" % [r.get("name", ""), int(r.get("price_xuanyu", "0"))]
		b.disabled = true
		b.tooltip_text = "付费功能，后续版本开放"
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		内容.add_child(b)

func _刷新坊市列表(列: VBoxContainer, 结果: Label):
	for c in 列.get_children():
		c.queue_free()
	var 等级名: String = Game.声望等级名[clamp(Game.声望, 0, Game.声望等级名.size() - 1)]
	for r in Game._坊市表():
		if not (r.get("shop_id", "") in Game.坊市上架集):
			continue
		var 名: String = r.get("item_name", "")
		var 稀有: bool = Game.坊市稀有标记.get(r.get("shop_id", ""), false)
		var 名显: String = ("〔稀有商队〕" + 名) if 稀有 else 名
		var 原价: int = int(r.get("price_lingjing", "0"))
		var 折后: int = Game.坊市实价(原价)
		var 折扣说明: String = "" if 折后 == 原价 else "（%s%d折）" % [等级名, int(Game.坊市折扣率() * 100)]
		var 限: String = "日%d/周%d" % [int(r.get("limit_daily", "0")), int(r.get("limit_weekly", "0"))]
		var 行 := HBoxContainer.new()
		var 原价文本: String = "" if 折后 == 原价 else "原价%d " % 原价
		var 标 := Label.new(); 标.text = "%s %s%d灵石 [%s]" % [名显, 原价文本, 折后, 限]
		var 买 := Button.new(); 买.text = "购买"
		买.pressed.connect(func():
			var res: Dictionary = Game.购买坊市物品(r.get("shop_id", ""))
			结果.text = res.get("msg", "")
			_坊市提示 = res.get("msg", "")
			刷新()
			_刷新坊市列表(列, 结果)
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

# ============ S0 任务中心：日常（3条）+ 周常（1条）============
func _on_任务():
	_建_二级页("任务")

func _填_任务页(内容: Control):
	var 结果 := Label.new(); 结果.text = _任务提示; 内容.add_child(结果)
	var 滚 := ScrollContainer.new(); 滚.custom_minimum_size = Vector2(380, 400); 内容.add_child(滚)
	任务列 = VBoxContainer.new(); 滚.add_child(任务列)
	_刷新_任务页(结果)

func _刷新_任务页(结果: Label):
	if 任务列 == null or not is_instance_valid(任务列):
		return
	for c in 任务列.get_children():
		c.queue_free()
	# —— 日常任务 ——
	var 日常倒计: int = max(0, (Game.上次日常日 + 1) - Game.累计游戏日)
	var 日头 := Label.new(); 日头.text = "【日常】每日刷新(距%d日) 领灵石/灵气" % 日常倒计; 任务列.add_child(日头)
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
			if res.get("ok", false):
				var qq: Dictionary = Game.当前日常[i]
				var 灵: int = int(float(qq.get("reward_lingjing", "0")) * Game.任务奖励系数())
				var 气: int = int(float(qq.get("reward_lingqi", "0")) * Game.任务奖励系数())
				_数值跳字(任务列, "灵石+%d 灵气+%d" % [灵, 气], 玉石绿)
			_刷新_任务页(结果)
		)
		行.add_child(标); 行.add_child(领)
		if not 已领 and q.get("jump_path", "") != "":
			var 往 := Button.new(); 往.text = "前往"
			往.add_theme_stylebox_override("normal", _次按钮样式())
			往.add_theme_color_override("font_color", BTN_次字)
			往.pressed.connect(_跳转.bind(q.get("jump_path", "")))
			行.add_child(往)
		任务列.add_child(行)
	# —— 周常任务 ——
	var 周常倒计: int = max(0, (Game.上次周常日 + 7) - Game.累计游戏日)
	var 周头 := Label.new(); 周头.text = "【周常】每7日刷新(距%d日)" % 周常倒计; 任务列.add_child(周头)
	if Game.当前周常.is_empty():
		var 无 := Label.new(); 无.text = "（暂未解锁，提升门派等级后开启）"; 任务列.add_child(无)
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
			_刷新_任务页(结果)
		)
		行.add_child(标); 行.add_child(领)
		任务列.add_child(行)
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
		_刷新_任务页(结果)
	)
	任务列.add_child(一键)


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
	副.add_theme_font_size_override("font_size", FONT_AUX)
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
	头.add_theme_font_size_override("font_size", FONT_SUB)
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
	标题底.bg_color = 标题底色
	标题底.set_content_margin_all(7)
	标题底.set_corner_radius_all(4)
	var 头 := Label.new()
	头.text = "⚔ %s：%s" % [stage_id, "胜 利" if 胜 else "失 败"]
	头.add_theme_font_size_override("font_size", FONT_PANEL_B)
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
			文本 += "[color=#%s]（前 %d 条已折叠，仅显示最近 50 条）[/color]\n" % [青灰.to_html(false), 全日志.size() - 50]
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
				标记 += "[color=#%s][b]【%s】[/b][/color] " % [暗金.to_html(false), t]
			var 回: String = "[color=#%s]R%d[/color] " % [次墨.to_html(false), int(e.get("round", 0))]
			var 伤: int = int(e.get("damage", 0))
			if 标签.has("闪避"):
				文本 += "%s%s → %s %s\n" % [回, 链名.call(e.get("actor", "")), 链名.call(e.get("target", "")), 标记]
			else:
				文本 += "%s%s → %s 伤害 [color=#%s][b]%d[/b][/color] %s\n" % [回, 链名.call(e.get("actor", "")), 链名.call(e.get("target", "")), 朱砂.to_html(false), 伤, 标记]
			if e.get("ref_type", "") != "" and e.get("ref_name", "") != "":
				文本 += " [url=%s:%s]%s[/url]" % [e.get("ref_type", ""), e.get("ref_id", ""), e.get("ref_name", "")]
		日志.text = 文本
	构建日志.call(展开全部)
	滚.add_child(日志)
	# 日志标题行 + 展开/收起按钮（仅长日志出现）
	var 日志头 := HBoxContainer.new()
	日志头.add_child(日志标)
	日志头.add_spacer(false)
	var 展开钮 := Button.new()
	展开钮.text = "展开全部"
	展开钮.add_theme_font_size_override("font_size", FONT_AUX)
	展开钮.add_theme_color_override("font_color", 展开灰)
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
	lb.add_theme_font_size_override("font_size", FONT_BODY)
	lb.add_theme_color_override("font_color", BTN_主字)
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
	sb.bg_color = 弹窗底色
	sb.border_color = 弹窗边色
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	return sb
func _填_建筑页(内容: Control):
	内容.add_theme_constant_override("separation", 6)
	内容.add_child(_玄玉占位按钮())
	# 山门牌匾（彩蛋钩子）：点击查看宗门立基旧事
	var 牌匾 := Button.new()
	牌匾.text = "「太玄宗·山门」"
	牌匾.flat = true
	牌匾.add_theme_font_size_override("font_size", FONT_SUB)
	牌匾.add_theme_color_override("font_color", 暗金)
	牌匾.pressed.connect(_on_山门牌匾)
	内容.add_child(牌匾)
	# 顶部全局汇总栏（固定一屏可见）
	内容.add_child(_建筑总览_汇总栏())
	# 分类标签导航（复用 TabBar 组件，参考离山汇总/主界面分页）
	var tb := TabBar.new()
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	刷新()
	内容.add_child(_宗门大阵面板())   # S1 批6-A：宗门大阵面板挂建筑二级页

# === S1 批6-A：宗门大阵面板（挂「建筑」二级页，纯经营展示 · 零战斗触碰）===
func _宗门大阵面板() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _暗墨面板())
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)
	var 标题 := Label.new()
	标题.text = "宗门大阵"
	标题.add_theme_font_size_override("font_size", FONT_PANEL)
	标题.add_theme_color_override("font_color", 暗金)
	vb.add_child(标题)
	var 主阵: String = Game.宗门大阵.get("当前主阵", "")
	var 主阵名: String = "（未启用）"
	if 主阵 != "":
		主阵名 = str(Game.阵法配置表.get(主阵, {}).get("array_name", 主阵))
	var 当前 := Label.new()
	当前.text = "当前主阵：%s" % 主阵名
	当前.add_theme_font_size_override("font_size", FONT_BODY)
	当前.add_theme_color_override("font_color", 次墨)
	vb.add_child(当前)
	# 三阵预览（护山/聚灵/镇煞：arr_s_001/002/003）
	for aid in ["arr_s_001", "arr_s_002", "arr_s_003"]:
		var 配置: Dictionary = Game.阵法配置表.get(aid, {})
		var 名: String = str(配置.get("array_name", aid))
		var 等级: int = int(Game.宗门大阵.get("等级", {}).get(aid, 0))
		var 耐久: int = int(Game.宗门大阵.get("耐久", {}).get(aid, 0))
		var 行 := Label.new()
		行.text = "%s  Lv.%d  耐久 %d" % [名, 等级, 耐久]
		行.add_theme_font_size_override("font_size", FONT_AUX)
		行.add_theme_color_override("font_color", 玉石绿)
		vb.add_child(行)
	# 启用/切换主阵钮（BTN_主* 风格）
	var 切换 := Button.new()
	切换.text = "切换主阵（循环）"
	切换.add_theme_stylebox_override("normal", _主按钮样式())
	切换.add_theme_color_override("font_color", BTN_主字)
	切换.pressed.connect(_on_切换宗门大阵)
	vb.add_child(切换)
	return p

# 切换宗门大阵主阵（循环：护山→聚灵→镇煞→玄空→关闭）
func _on_切换宗门大阵():
	var 序: Array = ["arr_s_001", "arr_s_002", "arr_s_003", "arr_s_004", ""]
	var 现: String = Game.宗门大阵.get("当前主阵", "")
	var i: int = 序.find(现)
	i = (i + 1) % 序.size()
	var 新: String = 序[i]
	Game.宗门大阵["当前主阵"] = 新
	if 新 == "":
		_toast("宗门大阵已关闭")
	else:
		var 名: String = str(Game.阵法配置表.get(新, {}).get("array_name", 新))
		_toast("已启用主阵：%s" % 名)
	刷新()

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
		if 当前页名 == "纪事":
			刷新纪事()

func _on_山门牌匾():
	Game.触发点击彩蛋("egg_click_shanmen")
	_toast("（异闻）山门旧事：宗门立基至今，已历 %d 载风雨。" % Game.累计游戏日)
	if 当前页名 == "纪事":
		刷新纪事()

func _on_掌教点击彩蛋():
	掌教点击计数 += 1
	if 掌教点击计数 >= 10:
		掌教点击计数 = 0
		Game.触发点击彩蛋("egg_click_zhangjiao")
		_toast("（异闻）掌教自省")
		if 当前页名 == "纪事":
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
	l1.add_theme_font_size_override("font_size", FONT_AUX)
	l1.add_theme_color_override("font_color", 暗金)
	var l2 := Label.new()
	l2.text = "预计月产出 %d 灵石" % 产出
	l2.add_theme_font_size_override("font_size", FONT_BODY)
	l2.add_theme_color_override("font_color", 暗金)
	var l3 := Label.new()
	l3.text = "全局经营加成 %s ｜ 全局修炼加成 %s" % [经营文本, 修炼文本]
	l3.add_theme_font_size_override("font_size", FONT_AUX)
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
	var 等级: int = int(堂.get("等级", 1))
	var 政绩: int = int(堂.get("政绩", 0))
	var 块 := VBoxContainer.new()
	块.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	块.add_theme_constant_override("separation", 4)
	# 卡片：PanelContainer 包一层，按类别着辅助色边框
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", _建筑卡片底色(建筑_类别反查.get(key, "战略")))
	var 内 := VBoxContainer.new()
	内.add_theme_constant_override("separation", 3)
	pc.add_child(内)
	块.add_child(pc)
	# 头部：大名称（金色修真标题字号，对齐 小标题）+ 职能标签（小字次要灰）
	var 头行 := HBoxContainer.new()
	头行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 头 := Label.new()
	头.text = 堂["名称"]
	头.add_theme_font_size_override("font_size", FONT_PANEL)
	头.add_theme_color_override("font_color", 暗金)
	头.mouse_filter = Control.MOUSE_FILTER_STOP
	头.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_建筑点击彩蛋(key)
	)
	头.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	头行.add_child(头)
	# S1 批2：建筑等级芯片
	var 等级芯片 := Label.new()
	等级芯片.text = "Lv.%d" % 等级
	等级芯片.add_theme_font_size_override("font_size", FONT_AUX)
	等级芯片.add_theme_color_override("font_color", 暗金)
	头行.add_child(等级芯片)
	var 标签 := Label.new()
	标签.text = "  %s" % 建筑职能标签.get(key, "")
	标签.add_theme_font_size_override("font_size", FONT_AUX)
	标签.add_theme_color_override("font_color", 次墨)
	头行.add_child(标签)
	内.add_child(头行)
	# 负责人行：负责人 XXX ＋ 锁图标（金色小锁）；经营加成 +X%；全局效果
	var 负责: Disciple = 堂["负责人"]
	var 负责名: String = "（空缺）" if 负责 == null else 负责.姓名
	var 锁定: bool = 堂.get("负责人锁定", false)
	var 负责行 := HBoxContainer.new()
	负责行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 锁 := Label.new()
	锁.text = "🔒 " if 锁定 else ""
	锁.add_theme_font_size_override("font_size", FONT_AUX)
	锁.add_theme_color_override("font_color", 暗金)
	负责行.add_child(锁)
	var 负责文本: String = "主事 %s" % 负责名
	if 负责 != null:
		负责文本 += "  经营加成 +%.0f" % 负责.加成评分(堂["加成维度"])
	var 负责标签: Label = _label(负责文本, 13, 墨黑)
	负责标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	负责行.add_child(负责标签)
	if 负责 != null and 建筑全局维度.has(key):
		var 维: String = 建筑全局维度[key]
		var 全局文本: String = "  全局效果：全宗%s +1%%" % 维度显示.get(维, 维)
		var 全局标签: Label = _label(全局文本, 13, 次墨)
		全局标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		负责行.add_child(全局标签)
	内.add_child(负责行)
	# S1 批2：任期政绩行（高政绩主事以朱砂提示）
	var 政绩色: Color = 次墨
	if 政绩 > 0:
		政绩色 = 朱砂
	var 政绩徽: String = ""
	if 政绩 >= 36:
		政绩徽 = " · 声誉卓著"
	elif 政绩 >= 12:
		政绩徽 = " · 已达里程碑"
	var 政绩行 := HBoxContainer.new()
	政绩行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 政绩标签: Label = _label("任期政绩 %d%s" % [政绩, 政绩徽], 13, 政绩色)
	政绩标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	政绩行.add_child(政绩标签)
	内.add_child(政绩行)
	# 产出行：预计月产出 XX 灵石 ｜ 附带效果（从阶段2 被动逻辑读说明文字）
	var 产出行 := HBoxContainer.new()
	产出行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 产出标签: Label = _label("预计月产出 %d 灵石" % Game.预估建筑产出(key), 13, 暗金)
	产出标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	产出行.add_child(产出标签)
	var 附带: String = 建筑附带效果(key)
	if 附带 != "":
		var 附带标签 := Label.new()
		附带标签.text = "  ｜ " + 附带
		附带标签.add_theme_font_size_override("font_size", FONT_AUX)
		附带标签.add_theme_color_override("font_color", 次墨)
		附带标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		附带标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		产出行.add_child(附带标签)
	内.add_child(产出行)
	# 成员折叠区（复用 琐事折叠 ▶/▼ 切换；默认折叠）
	var 成员: Array = 堂["成员"]
	var 折叠_container := VBoxContainer.new()
	var 折叠按钮 := Button.new()
	折叠按钮.text = "门人共 %d 人 ▸" % 成员.size()
	折叠按钮.add_theme_font_size_override("font_size", FONT_AUX)
	折叠按钮.add_theme_color_override("font_color", 次墨)
	折叠_container.add_child(折叠按钮)
	var 成员列表 := VBoxContainer.new()
	成员列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	成员列表.visible = false
	if 成员.is_empty():
		var 空 := Label.new(); 空.text = "  （暂无门人）"; 空.add_theme_font_size_override("font_size", FONT_AUX); 空.add_theme_color_override("font_color", 次墨)
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
	# S1 批2：建筑升级入口（展示目标等级/消耗 + 升级按钮，点击展开详情确认）
	var 提示: Dictionary = _建筑_升级提示(key)
	var 目标等级: int = int(提示["等级"]) + 1
	var 升级文本: String = "升级 → Lv.%d · 灵石 -%d" % [目标等级, int(提示["耗"])]
	if bool(提示["可升"]):
		升级文本 += " · 可升级"
	else:
		升级文本 += " · " + str(提示["原因"])
	var 升级行 := HBoxContainer.new()
	升级行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 升级标签: Label = _label(升级文本, 13, 暗金)
	升级标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	升级行.add_child(升级标签)
	var 升按钮 := Button.new()
	升按钮.text = "升级 ▸"
	升按钮.disabled = (int(提示["等级"]) >= int(提示["上限"])) or (Game.门派等级 < 2)
	升按钮.pressed.connect(func(): _打开建筑详情(key))
	升级行.add_child(升按钮)
	内.add_child(升级行)
	if 锁定:
		var 解锁按钮 := Button.new(); 解锁按钮.text = "解除锁定"; 解锁按钮.pressed.connect(_on_解除锁定.bind(key))
		内.add_child(解锁按钮)
	return 块

func _on_任负责人(key: String, m: Disciple):
	var 旧主事: Variant = Game.堂口列表[key].get("负责人", null)
	if 旧主事 != null and 旧主事 != m and int(Game.堂口列表[key].get("政绩", 0)) >= 12:
		_弹出高政绩撤换确认(key, m)
		return
	Game.任命负责人(key, m)
	详情.text = "已任命 %s 为%s主事。" % [m.姓名, Game.堂口列表[key]["名称"]]
	_建_二级页("建筑")

func _on_解除锁定(key: String):
	Game.解除负责人锁定(key)
	详情.text = "已解除%s主事锁定。" % Game.堂口列表[key]["名称"]
	_建_二级页("建筑")

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

# ============ S1 批2：建筑升级 + 任期政绩 UI（§二 / §三）============

# 升级可用性与原因（供总览卡片与详情弹窗共用，避免逻辑重复）
func _建筑_升级提示(key: String) -> Dictionary:
	var 等级: int = int(Game.堂口列表[key].get("等级", 1))
	var 上限: int = Game._建筑等级上限()
	var 耗: int = Game._升级消耗_灵石(等级)
	var 可升: bool = (等级 < 上限) and (Game.门派等级 >= 2) and (Game.灵石 >= 耗)
	var 原因: String = ""
	if 等级 >= 上限:
		原因 = "已达宗门品级上限（Lv.%d）" % 上限
	elif Game.门派等级 < 2:
		原因 = "需灵阶及以上宗门方可升级"
	elif Game.灵石 < 耗:
		原因 = "灵石不足（需 %d，余 %d）" % [耗, Game.灵石]
	return {"可升": 可升, "原因": 原因, "等级": 等级, "上限": 上限, "耗": 耗}

# 执行升级：调用 Game.升级建筑，toast 反馈；成功则关弹窗并重建建筑页
func _执行建筑升级(key: String) -> void:
	var 结果: Dictionary = Game.升级建筑(key)
	_toast(str(结果.get("msg", "升级完成")))
	if bool(结果.get("ok", false)):
		# 走 _关闭详情 统一入口（先回收 _属性行 池化 Label 到 _详情回收站，再 queue_free，最后清空单实例守卫）；
		# 避免直接 queue_free 释放含池化 Label 的弹窗导致池子持有将来指向 freed instance 的悬挂引用（typed-var assign 校验会抛）。
		if _当前详情遮 != null and is_instance_valid(_当前详情遮):
			_关闭详情(_当前详情遮)
		_建_二级页("建筑")

# 建筑详情弹窗：等级/上限、任期政绩、当前产出、升级按钮（含消耗与禁用原因）
func _打开建筑详情(key: String) -> void:
	var 堂: Dictionary = Game.堂口列表[key]
	var 等级: int = int(堂.get("等级", 1))
	var 上限: int = Game._建筑等级上限()
	var 政绩: int = int(堂.get("政绩", 0))
	var 提示: Dictionary = _建筑_升级提示(key)
	var 弹: Dictionary = _new_detail_popup("%s · Lv.%d" % [堂["名称"], 等级], 暗金)
	var 内容: VBoxContainer = 弹["内容"] as VBoxContainer
	内容.add_child(_label("建筑等级 Lv.%d / 上限 Lv.%d（由宗门品级驱动）" % [等级, 上限], FONT_AUX, 次墨))
	var 政绩色: Color = 次墨
	if 政绩 > 0:
		政绩色 = 朱砂
	var 政绩徽: String = ""
	if 政绩 >= 36:
		政绩徽 = " · 声誉卓著"
	elif 政绩 >= 12:
		政绩徽 = " · 已达里程碑"
	内容.add_child(_label("任期政绩 %d%s" % [政绩, 政绩徽], FONT_AUX, 政绩色))
	内容.add_child(_label("当前预计月产出 %d 灵石" % Game.预估建筑产出(key), FONT_AUX, 暗金))
	if bool(提示["可升"]):
		内容.add_child(_label("升级至 Lv.%d 需 灵石 -%d（产出 +2%%）" % [等级 + 1, int(提示["耗"])], FONT_BODY, 玉石绿))
	else:
		内容.add_child(_label("升级至 Lv.%d 需 灵石 -%d" % [等级 + 1, int(提示["耗"])], FONT_BODY, 次墨))
	var 升按钮 := Button.new()
	升按钮.text = "升级至 Lv.%d（灵石 -%d）" % [等级 + 1, int(提示["耗"])]
	升按钮.disabled = not bool(提示["可升"])
	升按钮.pressed.connect(func(): _执行建筑升级(key))
	内容.add_child(升按钮)
	if not bool(提示["可升"]) and str(提示["原因"]) != "":
		内容.add_child(_label(str(提示["原因"]), FONT_AUX, 朱砂))
	内容.add_child(弹["关"])

# 撤换高政绩主事确认（D10：政绩≥12 撤换将清零其政绩，开启新任期）
func _弹出高政绩撤换确认(key: String, m: Disciple) -> void:
	var 旧政绩: int = int(Game.堂口列表[key].get("政绩", 0))
	var 弹: Dictionary = _new_detail_popup("撤换主事确认", 朱砂)
	var 内容: VBoxContainer = 弹["内容"] as VBoxContainer
	内容.add_child(_label("%s 现任主事任期内政绩已达 %d，撤换将清零其政绩、开启新任期。" % [Game.堂口列表[key]["名称"], 旧政绩], FONT_BODY, 墨黑))
	内容.add_child(_label("确认撤换为 %s？" % m.姓名, FONT_BODY, 墨黑))
	var 确认 := Button.new(); 确认.text = "确认撤换"
	确认.pressed.connect(func():
		Game.任命负责人(key, m)
		详情.text = "已任命 %s 为%s主事（前任政绩清零）。" % [m.姓名, Game.堂口列表[key]["名称"]]
		if is_instance_valid(弹["遮"]):
			弹["遮"].queue_free()
		_建_二级页("建筑")
	)
	内容.add_child(确认)
	内容.add_child(弹["关"])

# ============ 主题与组件助手 ============
func 造主题() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY
	# 面板：暗青玉半透底 + 暗金描边（参考写实宗门经营 UI）
	var p := StyleBoxFlat.new()
	p.bg_color = 面板底
	p.set_corner_radius_all(8)
	p.set_border_width_all(1)
	p.border_color = 暗金
	p.content_margin_left = 10; p.content_margin_right = 10
	p.content_margin_top = 8; p.content_margin_bottom = 8
	t.set_stylebox("panel", "PanelContainer", p)
	# 通用 Panel（状态栏/底框由 _暗墨面板 局部覆盖，此处仅定义默认）
	var pp := p.duplicate(); pp.bg_color = 面板底; pp.border_color = 暗金
	t.set_stylebox("panel", "Panel", pp)
	# 按钮：暖木棕底 + 暗金框 + 宣纸亮字（高对比、有材质感）
	var b := StyleBoxFlat.new()
	b.bg_color = 按钮木
	b.set_corner_radius_all(8)
	b.set_border_width_all(2)
	b.border_color = 暗金
	b.content_margin_left = 12; b.content_margin_right = 12
	b.content_margin_top = 6; b.content_margin_bottom = 6
	t.set_stylebox("normal", "Button", b)
	var bh: StyleBoxFlat = b.duplicate(); bh.bg_color = 按钮木悬; t.set_stylebox("hover", "Button", bh)
	var bp: StyleBoxFlat = b.duplicate(); bp.bg_color = 按钮金按; bp.border_color = 按钮金按; t.set_stylebox("pressed", "Button", bp)
	var bd: StyleBoxFlat = b.duplicate(); bd.bg_color = 按钮禁用; bd.border_color = 按钮禁用; t.set_stylebox("disabled", "Button", bd)
	# 文字色：统一浅色确保在暗底上可读
	t.set_color("font_color", "Label", 宣纸亮)
	t.set_color("font_color", "Button", 宣纸亮)
	t.set_color("font_color", "RichTextLabel", 宣纸亮)
	# 分隔线（清单/卡片间）
	var hs := StyleBoxFlat.new(); hs.bg_color = 暗金; hs.set_corner_radius_all(0)
	t.set_stylebox("separator", "HSeparator", hs)
	t.set_stylebox("separator", "VSeparator", hs.duplicate())
	# 滚动条（低调暗金抓柄）
	var sb := StyleBoxFlat.new(); sb.bg_color = 暗金; sb.set_corner_radius_all(3)
	sb.content_margin_left = 2; sb.content_margin_right = 2; sb.content_margin_top = 2; sb.content_margin_bottom = 2
	t.set_stylebox("grabber", "ScrollBar", sb)
	t.set_stylebox("grabber_highlight", "ScrollBar", sb.duplicate())
	# 标签页（主界面 弟子/待抉择/御兽/纪事）：未选暗青玉，选中暗金
	var tb := StyleBoxFlat.new(); tb.bg_color = 面板底; tb.set_corner_radius_all(6); tb.set_border_width_all(1); tb.border_color = 暗金
	t.set_stylebox("tab_unselected", "TabBar", tb)
	var tbs := tb.duplicate(); tbs.bg_color = 暗金
	t.set_stylebox("tab_selected", "TabBar", tbs)
	t.set_color("font_color", "TabBar", 宣纸亮)
	t.set_color("font_color_selected", "TabBar", 墨黑)
	# 现实皮肤纹理层（沿用 AI 生成方向稿；缺资源静默回退扁平风，见 启用皮肤纹理）
	_皮肤纹理装填(t)
	return t

# 现实皮肤纹理层：将 AI 生成方向稿作 9 宫格切片挂载到面板/按钮。
# 全部以 ResourceLoader.exists 守护——资源缺失或想回退纯扁平风时，置 启用皮肤纹理=false 即零成本切回。
func _皮肤纹理装填(t: Theme):
	if not 启用皮肤纹理:
		return
	var 面板路 := "res://assets/ai_art/2026-07-22/游戏UI弹窗面板_玉石半透明质感_宣纸纤维纹理_旧金描边_轻_2026-07-22T15-19-56.png"
	var 按钮路 := "res://assets/ai_art/2026-07-22/游戏UI按钮_暗金边框_青玉底色_轻微浮雕_古风器物感_鎏金_2026-07-22T15-19-56.png"
	if ResourceLoader.exists(面板路):
		var tex := load(面板路) as Texture2D
		var s := StyleBoxTexture.new()
		s.texture = tex
		s.region_rect = Rect2(0, 0, 832, 1216)
		s.expand_margin_left = 48; s.expand_margin_top = 48; s.expand_margin_right = 48; s.expand_margin_bottom = 48
		s.modulate_color = 纹理白
		t.set_stylebox("panel", "PanelContainer", s)
	if ResourceLoader.exists(按钮路):
		var tex := load(按钮路) as Texture2D
		var s := StyleBoxTexture.new()
		s.texture = tex
		s.region_rect = Rect2(0, 0, 1024, 1024)
		s.expand_margin_left = 80; s.expand_margin_top = 80; s.expand_margin_right = 80; s.expand_margin_bottom = 80
		t.set_stylebox("normal", "Button", s)
		var sh := s.duplicate(); t.set_stylebox("hover", "Button", sh)
		var sp := s.duplicate(); t.set_stylebox("pressed", "Button", sp)

# 深墨半透明面板（状态栏专用，呼应"深墨色半透明基底 + 暗金数值"）
func _暗墨面板() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = 面板底
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
			var 定义甲: Variant = Game._物品定义表.get(_id)
			if 定义甲 is Array and (定义甲 as Array).size() >= 2:
				var 参甲: Array = 定义甲 as Array
				return Game._造低阶物品(参甲[0], 参甲[1])
		"gongfa":
			var gs: Dictionary = SkillCultivationLoader.get_skill(_id)
			if not gs.is_empty():
				return gs
		"buff":
			var bf: Dictionary = BattleCalculator._buff模板(_id)
			if not bf.is_empty():
				return bf
		"building":
			var bd: Variant = Game.堂口列表.get(_id)
			if bd is Dictionary:
				return bd
		"beast":
			for 灵 in Game.灵兽库存:
				if 灵 is Beast and 灵.种类名 == _id:
					return 灵
		"encounter":
			for 记 in Game.宗门纪事:
				if 记.get("名称", "") == _id:
					return 记
		"chronicle":
			if _id.contains(":"):
				var 部分: Array = _id.split(":", false, 1)
				var 日: String = 部分[0]
				var 名: String = 部分[1]
				for 纪 in Game.宗门纪事:
					if String(纪.get("日", "")) == 日 and 纪.get("名称", "") == 名:
						return 纪
			else:
				var idx: int = int(_id)
				if idx >= 0 and idx < Game.宗门纪事.size():
					return Game.宗门纪事[idx]
		"dan_yao":
			var 定义乙: Variant = Game._物品定义表.get(_id)
			if 定义乙 is Array and (定义乙 as Array).size() >= 2:
				var 参乙: Array = 定义乙 as Array
				return Game._造低阶物品(参乙[0], 参乙[1])
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
		"gongfa":
			var gs: Variant = _解析实体("gongfa", id)
			if gs is Dictionary and not (gs as Dictionary).is_empty():
				_弹出功法详情(id)
			else:
				_toast("（暂无详情）")
		"buff":
			var bf: Variant = _解析实体("buff", id)
			if bf is Dictionary and not (bf as Dictionary).is_empty():
				_弹出Buff详情(id)
			else:
				_toast("（暂无详情）")
		"building":
			var bd: Variant = _解析实体("building", id)
			if bd is Dictionary:
				_弹出建筑详情(id)
			else:
				_toast("（暂无详情）")
		"beast":
			var bv: Variant = _解析实体("beast", id)
			if bv is Beast:
				_弹出灵兽详情(bv)
			else:
				_toast("（暂无详情）")
		"encounter":
			var en: Variant = _解析实体(type, id)
			if en is Dictionary:
				_弹出纪事详情(en)
			else:
				_toast("（暂无详情）")
		"chronicle":
			var ch: Variant = _解析实体(type, id)
			if ch is Dictionary:
				_弹出纪事详情(ch)
			else:
				_toast("（暂无详情）")
		"dan_yao":
			var dy: Variant = _解析实体("dan_yao", id)
			if dy is Item:
				_弹出丹药详情(dy)
			else:
				_toast("（暂无详情）")
		"skill":
			_弹出功法详情(id)
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
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_child(vb)
	if 标题文本 != "":
		vb.add_child(小标题(标题文本))
	return pc

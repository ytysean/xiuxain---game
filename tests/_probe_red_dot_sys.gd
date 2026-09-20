extends Node
## 红点体系端到端探针（headless 可跑）——验证「状态算得出」到「角标看得见」整条链。
## 用法：<godot> --headless --path . --scene res://tests/_probe_red_dot_sys.tscn
##
## 本探针诞生于一次体系级审计，当时定位到四个**静默失效**（全部零报错，靠肉眼发现不了）：
##   ① RedDotManager._刷新节点显示 里「写 visible / 收集存活节点」两行被误缩进到 `continue`
##      之后 ⇒ 永不执行。后果：圆点显隐完全失效；且「存活」恒空数组，每刷新一次就把注册
##      表清空 ⇒ 红点注册一次后永久失效。
##   ② 底部 5 Tab 从未建过红点节点，而 red_dot_init 却为它们算了状态与父子聚合
##      ⇒ 状态算完无人承接（微信最核心的 Tab 角标本作完全没有）。
##   ③ red_dot_init.红点ID 的 Tab 名与真实底栏**身份错位**：多了不存在的「坊市」「更多」，
##      少了真实存在的「殿阁」「纪事」。
##   ④ 角标配色走「深玄描边 + 暗色外发光」：暗色 shadow 在亮色山水背景上呈一圈脏灰，
##      在深色玻璃面板上则完全隐形；深描边又把高饱和红压暗 —— 与「一眼看见」正好相反。
##
## 断言语义：
##   A 管理器显隐真的生效 + 失效节点被剔除（①）；
##   B 底栏 5 Tab 各有圆点/数字角标、层级在热区之上、点击可穿透（②）；
##   C 角标形态按数据分档（有数量→数字 / 仅状态→圆点）与「右贴角」定位锚点；
##   D 视觉规格 = 微信 / 原生桌面档（纯色实心、无描边、无发光、正圆、默认静止）；
##   E UITheme 红点状态源包装（含未注入时的安全兜底）；
##   F red_dot_init 的 Tab ID 与 bottom_tab_bar.TABS 逐字对齐（③）；
##   G ★ 红点判据铁则：弟子 AI 内驱项（装备/突破）不得进红点表，只留「须宗主落笔」的请示。
##     依据：本项目弟子全员内驱（自穿装备 / 自服丹药 / 自行突破），宗主只被请示 —— 见 G 段长注释。

var 失败: int = 0
var 断言: int = 0
var 宿主: Control = null
var _栏: Control = null

const 栏脚本: String = "res://ui/bottom_tab_bar.gd"
const 管理器脚本: String = "res://red_dot_manager.gd"
const 初始化脚本: String = "res://red_dot_init.gd"

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		DisplayServer.window_set_size(Vector2i(1080, 1920))
	宿主 = Control.new()
	宿主.name = "DotHost"
	宿主.size = Vector2(1080, 1920)
	add_child(宿主)
	await _帧(2)

	await _测管理器显隐()
	await _测底栏角标()
	await _测行为分档()
	await _测视觉规格()
	await _测状态源()
	_测ID对齐()
	await _测内驱铁则()
	_报告()

# ───────── A 管理器显隐（①）─────────
func _测管理器显隐() -> void:
	var 管: Node = (load(管理器脚本) as GDScript).new()
	管.name = "ProbeMgr"
	add_child(管)
	var 点: Panel = UITheme.make_red_dot(12.0)
	点.name = "MgrDot"
	点.visible = false
	宿主.add_child(点)
	await _帧(2)

	管.call("注册红点", "探针_A", 点)
	管.call("设置红点", "探针_A", true)
	await _帧(2)
	_ok(点.visible, "A1 设置红点(true) → 节点真可见（旧实现恒 false：那行写在 continue 之后）")

	var 表: Dictionary = 管.get("_红点节点")
	var 列: Array = 表.get("探针_A", [])
	_ok(列.size() == 1, "A2 注册表未被清空（实得 %d 项；旧实现每次刷新都赋成空数组 ⇒ 注册即失效）" % 列.size())

	管.call("设置红点", "探针_A", false)
	await _帧(2)
	_ok(not 点.visible, "A3 设置红点(false) → 节点真隐藏（显隐双向生效）")

	管.call("刷新所有")
	var 表2: Dictionary = 管.get("_红点节点")
	var 列2: Array = 表2.get("探针_A", [])
	_ok(列2.size() == 1, "A4 有效节点不被误剔除（表长仍为 %d）" % 列2.size())

	点.queue_free()
	await _帧(3)
	管.call("刷新所有")
	var 表3: Dictionary = 管.get("_红点节点")
	var 列3: Array = 表3.get("探针_A", [])
	_ok(列3.is_empty(), "A5 失效节点被剔除（切页不导致注册表无限增长）")
	管.queue_free()

# ───────── B 底栏角标存在性 / 层级 / 穿透（②）─────────
func _测底栏角标() -> void:
	_栏 = (load(栏脚本) as GDScript).new()
	_栏.name = "ProbeTabBar"
	宿主.add_child(_栏)
	await _帧(3)

	var tabs: Array = _tab名()
	var 缺圆: Array = []
	var 缺数: Array = []
	for t in tabs:
		if _栏.get_node_or_null("TabDot_" + str(t)) == null:
			缺圆.append(str(t))
		if _栏.get_node_or_null("TabNum_" + str(t)) == null:
			缺数.append(str(t))
	_ok(缺圆.is_empty(), "B1 5 个 Tab 都有圆点角标（缺 %s；旧实现一个都没有 ⇒ 状态无人承接）" % str(缺圆))
	_ok(缺数.is_empty(), "B2 5 个 Tab 都有数字角标（缺 %s）" % str(缺数))

	var 透: bool = true
	for t in tabs:
		for 名 in ["TabDot_", "TabNum_"]:
			var n: Panel = _栏.get_node_or_null(名 + str(t))
			if n != null and n.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				透 = false
	_ok(透, "B3 角标 mouse_filter = IGNORE ⇒ 点击穿透到 Tab 热区（「很好点」的关键：角标只是标记）")

	var 序: Dictionary = {}
	for i in range(_栏.get_child_count()):
		序[_栏.get_child(i).name] = i
	var 层安: bool = true
	for t in tabs:
		var iHit: int = int(序.get("Hitbox_" + str(t), -1))
		var iDot: int = int(序.get("TabDot_" + str(t), -1))
		if iDot < iHit:
			层安 = false
	_ok(层安, "B4 5 个 Tab 的角标均在热区之上（Godot 后 add 者在上 ⇒ 不被遮挡）")

# ───────── C 形态分档与定位锚点 ─────────
func _测行为分档() -> void:
	var 圆: Panel = _栏.get_node("TabDot_弟子")
	var 数: Panel = _栏.get_node("TabNum_弟子")
	var 标: Label = 数.get_node("Num")

	_栏.call("设置Tab红点", "弟子", true, 0)
	await _帧(2)
	_ok(圆.visible and not 数.visible, "C1 仅有状态（数量 0）→ 圆点角标，不显示「0」")

	_栏.call("设置Tab红点", "弟子", true, 3)
	await _帧(2)
	_ok(数.visible and not 圆.visible, "C2 携带数量 → 数字角标（圆点让位，同一时刻只有一个）")
	_ok(标.text == "3", "C3 数字角标文本 = %s" % 标.text)

	_ok(absf(数.offset_right - 圆.offset_right) < 0.6,
		"C4 数字右缘 = 圆点右缘（右贴角锚点一致：%.1f vs %.1f）" % [数.offset_right, 圆.offset_right])

	var 宽单: float = 数.custom_minimum_size.x
	_栏.call("设置Tab红点", "弟子", true, 12)
	await _帧(2)
	_ok(标.text == "12", "C5 两位数文本 = %s" % 标.text)
	_ok(数.custom_minimum_size.x > 宽单, "C6 多位数向左扩（宽 %.1f > 单位数 %.1f）" % [数.custom_minimum_size.x, 宽单])

	_栏.call("设置Tab红点", "弟子", true, 128)
	await _帧(2)
	_ok(标.text == "99+", "C7 超 99 截断 = %s" % 标.text)

	_栏.call("设置Tab红点", "弟子", false, 0)
	await _帧(2)
	_ok(not 圆.visible and not 数.visible, "C8 无红点 → 两者都隐藏")

# ───────── D 视觉规格（微信 / 原生档）─────────
func _测视觉规格() -> void:
	_ok(UITheme.RED_DOT_BORDER.is_equal_approx(UITheme.RED_DOT_COLOR),
		"D1 描边色 == 主红 ⇒ 实为 0 宽描边（旧版近黑描边把饱和红压暗）")
	_ok(UITheme.RED_DOT_GLOW.a <= 0.001,
		"D2 外发光 alpha=%.3f = 0（旧值 0.45 的暗色 shadow：亮底呈脏灰、深底隐形）" % UITheme.RED_DOT_GLOW.a)
	# 判据直接比对微信红 #FA5151 的 RGB：HSV 阈值不好使 —— 微信红本身 S≈0.676、
	# V≈0.980，正是「高饱和高明度」的观感，但它 S 并不接近 1（纯红才 S=1，反而不像微信）。
	var 微信红: Color = Color(250.0 / 255.0, 81.0 / 255.0, 81.0 / 255.0)
	var 距: float = absf(UITheme.RED_DOT_COLOR.r - 微信红.r) + absf(UITheme.RED_DOT_COLOR.g - 微信红.g) + absf(UITheme.RED_DOT_COLOR.b - 微信红.b)
	_ok(距 < 0.06, "D3 主红与微信 #FA5151 三通道差 %.4f < 0.06（同档色，非暗红/砖红）" % 距)
	_ok(UITheme.红点_呼吸幅度 <= 1.0,
		"D4 呼吸默认关闭（幅度 %.2f；微信 Tab 与 iOS 桌面角标为静止）" % UITheme.红点_呼吸幅度)

	var 点: Panel = UITheme.make_red_dot(12.0)
	点.size = Vector2(27, 27)
	宿主.add_child(点)
	await _帧(2)
	var sb: StyleBoxFlat = 点.get_theme_stylebox("panel") as StyleBoxFlat
	_ok(sb != null and sb.border_width_left == 0 and sb.border_width_top == 0,
		"D5 圆点 stylebox 描边宽 = 0（纯色实心）")
	_ok(sb != null and sb.shadow_size == 0, "D6 圆点 stylebox 阴影尺寸 = 0")
	_ok(sb != null and absf(float(sb.corner_radius_top_left) - 点.size.x * 0.5) <= 1.0,
		"D7 圆角 %d ≈ 半径（正圆，非圆角方块）" % (sb.corner_radius_top_left if sb != null else -1))
	点.queue_free()

	var 数点: Panel = UITheme.make_red_dot_number(3, 16.0)
	数点.size = Vector2(36, 36)
	宿主.add_child(数点)
	await _帧(2)
	var sb2: StyleBoxFlat = 数点.get_theme_stylebox("panel") as StyleBoxFlat
	_ok(sb2 != null and sb2.shadow_size == 0 and sb2.border_width_left == 0,
		"D8 数字角标同样无描边、无发光")
	var 标2: Label = 数点.get_node_or_null("Num") as Label
	_ok(标2 != null and 标2.get_theme_font_size("font_size") >= int(数点.size.y * 0.5),
		"D9 数字字号 %d ≥ 半高（去描边后靠字号撑可读性）" % (标2.get_theme_font_size("font_size") if 标2 != null else -1))
	数点.queue_free()

# ───────── E 状态源包装 ─────────
func _测状态源() -> void:
	var 旧: Object = UITheme.红点源
	UITheme.红点源 = null
	_ok(UITheme.红点可见("TAB_弟子") == false and UITheme.红点数值("TAB_弟子") == 0,
		"E1 状态源为空时安全兜底（返回 false / 0，不抛错、不假阳性）")

	var 管: Node = (load(管理器脚本) as GDScript).new()
	add_child(管)
	UITheme.红点源 = 管
	# ★ 用探针专用 ID：若给 TAB_弟子 直接设 count，父级「自身 count > 0」会短路子级汇总，
	#   把后面的 E6 聚合断言污染成 4（首轮实测正是如此）—— 短路本身是正确行为，错的是断言选点。
	管.call("设置红点数量", "探针_数", 4)
	_ok(UITheme.红点可见("探针_数") and UITheme.红点数值("探针_数") == 4,
		"E2 经 UITheme 读到数量 %d（包装层通路正确）" % UITheme.红点数值("探针_数"))

	管.call("设置红点", "TAB_殿阁", true)
	_ok(UITheme.红点可见("TAB_殿阁") and UITheme.红点数值("TAB_殿阁") == 0,
		"E3 仅状态的红点：可见 = true 且数值 = 0（角标据此选圆点形态）")

	# 父级聚合：父自身 count 为 0，但子级点亮 ⇒ 父可见
	管.call("注册父子", "TAB_纪事", "纪事_未读")
	管.call("设置红点", "纪事_未读", true)
	_ok(UITheme.红点可见("TAB_纪事") and UITheme.红点数值("TAB_纪事") == 0,
		"E4 父子聚合有效：子级点亮使父级可见（纪事 Tab 无需自带数量）")

	# 数量聚合：父级自身 count 恒 0，必须向上汇总子级，否则 Tab 数字角标永不可达
	#   （实机截图实证：不汇总时 5 个 Tab 全显示圆点，TabNum_* 从不现身）。
	管.call("设置红点数量", "纪事_未读", 6)
	_ok(UITheme.红点数值("TAB_纪事") == 6,
		"E5 父级数量向子级汇总 = %d（不汇总 ⇒ 数字角标形同死代码）" % UITheme.红点数值("TAB_纪事"))

	# 弱信号隔离：`参与计数=false` 的子级只贡献有无、不参与数字（防红点虚高失去可信度）。
	# ★ 用探针专用 ID：生产代码当前**已无**此用法 —— 唯一实例 `弟子_装备` 已按
	#   「弟子 AI 内驱」铁则整条删除（见 _测内驱铁则）。这里只验聚合口径本身仍正确。
	管.call("注册父子", "TAB_弟子", "探针_数型", true)
	管.call("注册父子", "TAB_弟子", "探针_弱信号", false)
	管.call("设置红点数量", "探针_数型", 2)
	管.call("设置红点数量", "探针_弱信号", 9)
	_ok(UITheme.红点数值("TAB_弟子") == 2,
		"E6 弱信号不参与计数：弟子 Tab 数值 = %d（只计数型 2，弱信号 9 被隔离）" % UITheme.红点数值("TAB_弟子"))
	_ok(UITheme.红点可见("TAB_弟子"), "E7 弱信号仍贡献「有无」（可见 = true，退化为圆点仍提示）")

	# 全为弱信号时：可见但数量为 0 ⇒ 角标降级为圆点（与微信 Tab 语义一致）
	管.call("设置红点数量", "探针_数型", 0)
	_ok(UITheme.红点可见("TAB_弟子") and UITheme.红点数值("TAB_弟子") == 0,
		"E8 无数量型待办时数量归 0 ⇒ 角标自动降级为圆点")

	UITheme.红点源 = 旧
	管.queue_free()

# ───────── F ID 对齐（③）─────────
func _测ID对齐() -> void:
	var ids: Dictionary = _常量表(初始化脚本, "红点ID")
	var tabs: Array = _tab名()
	var 缺: Array = []
	for t in tabs:
		if not ids.has("TAB_" + str(t)):
			缺.append(str(t))
	_ok(缺.is_empty(), "F1 red_dot_init 覆盖全部 5 个真实 Tab（缺 %s）" % str(缺))
	_ok(not ids.has("TAB_坊市") and not ids.has("TAB_更多"),
		"F2 已剔除与真实底栏不符的历史 ID（TAB_坊市 / TAB_更多 —— 底栏从来没有这两项）")

# ───────── G 红点判据铁则：弟子 AI 内驱项不得进红点表 ─────────
# 本项目最核心的差异点：门下弟子**全员内驱** —— 自穿装备（disciple.自动穿戴 / 私库自动用度）、
#   自服丹药（AI主动准备突破 直接从宗门库房取）、自行突破（AI决定是否突破 按性格阈值自决）、
#   自寻机缘。宗主只在被「请示」时批复（护法 / 洞府 / 请誓 / 待抉择）。
# ⇒ 任何形如「弟子该做某事」的红点都是**错误设计**：它在催宗主去做弟子自己就会做的事。
#   正确通道是「纪事 / 传讯」告知，而不是红点催办（催办会钝化玩家对整个红点体系的敏感度）。
func _测内驱铁则() -> void:
	var ids: Dictionary = _常量表(初始化脚本, "红点ID")
	var 禁表: Array = ["弟子_装备", "弟子_突破", "历练_结算", "宗门_图录", "快捷_库藏"]
	var 残留: Array = []
	for k in 禁表:
		if ids.has(k):
			残留.append(k)
	_ok(残留.is_empty(),
		"G1 已剔除「弟子 AI 内驱项(装备/突破) + 自动结算(历练) + 恒false死配置(图录/库藏)」（残留 %s）" % str(残留))
	_ok(ids.has("弟子_请示"),
		"G2 弟子 Tab 唯一红点源 = 弟子_请示（待抉择 + 请誓待批，两者都必须宗主落笔）")
	_ok(ids.has("历练_奇遇"),
		"G3 历练 Tab 红点源 = 历练_奇遇（途中奇遇待抉择，而非恒不成立的「到期可领取」）")

	# G4 端到端：真实红点源初始化 + 刷新后，弟子 Tab 数值必须与「待抉择 + 请誓待批」1:1。
	#   单验字典有没有键是不够的 —— 键在而判据写错（如旧版读弟子装备槽）同样会虚高。
	var 旧源: Object = UITheme.红点源
	var 系统: Node = (load(初始化脚本) as GDScript).new()
	add_child(系统)
	await _帧(2)
	系统.call("刷新所有红点")
	var 待裁: int = 0
	var 请誓: int = 0
	if "待抉择" in Game and Game.待抉择 is Array:
		待裁 = (Game.待抉择 as Array).size()
	if "誓约待批" in Game and Game.誓约待批 is Array:
		请誓 = (Game.誓约待批 as Array).size()
	_ok(UITheme.红点数值("TAB_弟子") == 待裁 + 请誓,
		"G4 弟子 Tab 数值 %d == 待抉择(%d) + 请誓待批(%d)（红点与弟子录落点 1:1，无虚高）"
			% [UITheme.红点数值("TAB_弟子"), 待裁, 请誓])
	_ok(UITheme.红点源 == 系统.get("_管理器"),
		"G5 初始化即自注册 UITheme.红点源（子页面只读拉取的唯一通路）")
	# G6 结构断言：弟子 Tab 的计数子级必须**只有** 弟子_请示。
	#   防的是"删了判据却忘了删父子注册"——那会让 Tab 继续被已删项聚合（静默保留旧语义）。
	var 管: Object = 系统.get("_管理器")
	var 状: Dictionary = {}
	if 管 != null:
		状 = (管.get("_红点状态") as Dictionary).get("TAB_弟子", {})
	_ok(str(状.get("count_children", [])) == "[\"弟子_请示\"]",
		"G6 TAB_弟子 的计数子级 = %s（应恰为 [弟子_请示]，已删项不得残留聚合）" % str(状.get("count_children", [])))
	系统.queue_free()
	UITheme.红点源 = 旧源

# ───────── 工具 ─────────
func _tab名() -> Array:
	return _常量表(栏脚本, "TABS")

func _常量表(路径: String, 键: String) -> Variant:
	var gds: GDScript = load(路径) as GDScript
	if gds == null:
		return {}
	return gds.get_script_constant_map().get(键, {})

func _ok(条件: bool, 文: String) -> void:
	断言 += 1
	if 条件:
		prints(">>>  [OK] %s" % 文)
	else:
		失败 += 1
		prints(">>>  [XX] %s" % 文)

func _报告() -> void:
	prints(">>> 断言 %d 条 / 失败 %d 条" % [断言, 失败])
	prints(">>>PROBE_RED_DOT_SYS_%s" % ("FAIL" if 失败 > 0 else "PASS"))
	get_tree().quit(1 if 失败 > 0 else 0)

func _帧(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

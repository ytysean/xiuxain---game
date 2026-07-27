# quest.gd —— 奇遇引擎（Epic B / ADR-002 / GDD-奇遇）
#
# 仿 lore.gd 叶子结构：class_name + static func，无 preload 其它业务脚本、不依赖 Game 单例。
# 输入 Disciple（取其 性格/境界/命格），输出 Dictionary（文案/稀有度/需干预/奖励）。
# 数据源：核心池 config/event_quest.csv（ADR-002 §6.2，200则/四类/三档权重归一化）；
#        CSV 缺失时回退到 Lore.取奇遇 兜底。
#
# 命名约定：本文件函数名/返回契约与 game_state.gd 调用方保持一致；
#          核心池到位即切换，无需改调用方（ADR-002 D2）。
class_name Quest
extends RefCounted

const Lore = preload("res://lore.gd")
const Disciple = preload("res://disciple.gd")
# 纯数值结算器（ADR-003 D1/D4）：同为纯逻辑 RefCounted，无 UI / 无 Game 单例依赖，与 Lore/Disciple 同属叶子预载。
# 奇遇叶子仅调 BattleCalculator 纯数值结算（quick 模式），不预载入战斗编排层、
# 不打开战斗场景、不播放战斗流程。
const BattleCalculator = preload("res://BattleCalculator.gd")

# ============ 性格四维表（ADR-002 §6.1，已裁决）============
# 12 标准性格 → {激进度,利他度,聪慧度,贪欲度} 固定分值（0-100）。
# [DESIGN_BASELINE] 待 奇遇系统配置表及性格判定.docx 录入校准（来源 §2.2/§6.6/§10 第2863–2864行）。
# ⚠️ 与「五性格」区分：本表映射 12 标准性格（§6.6），不混用 personality_config.csv 的五性格行为标签。
const 性格四维表 := {
	"沉稳守道": {"激进度": 15, "利他度": 80, "聪慧度": 55, "贪欲度": 15},
	"仁心济世": {"激进度": 20, "利他度": 90, "聪慧度": 50, "贪欲度": 10},
	"守礼尊师": {"激进度": 10, "利他度": 75, "聪慧度": 60, "贪欲度": 10},
	"恬淡悟道": {"激进度": 10, "利他度": 65, "聪慧度": 75, "贪欲度": 5},
	"锐意争先": {"激进度": 70, "利他度": 45, "聪慧度": 60, "贪欲度": 50},
	"谨慎多疑": {"激进度": 30, "利他度": 50, "聪慧度": 65, "贪欲度": 40},
	"豪迈仗义": {"激进度": 55, "利他度": 70, "聪慧度": 45, "贪欲度": 35},
	"孤僻清修": {"激进度": 25, "利他度": 35, "聪慧度": 70, "贪欲度": 25},
	"桀骜不羁": {"激进度": 85, "利他度": 15, "聪慧度": 50, "贪欲度": 60},
	"杀伐果断": {"激进度": 90, "利他度": 20, "聪慧度": 60, "贪欲度": 55},
	"贪心逐缘": {"激进度": 70, "利他度": 10, "聪慧度": 45, "贪欲度": 95},
	"狂傲绝世": {"激进度": 95, "利他度": 10, "聪慧度": 70, "贪欲度": 70},
}

# 未知性格给中性基准（查表容错，便于单测与未来扩展）
const _中性四维 := {"激进度": 50, "利他度": 50, "聪慧度": 50, "贪欲度": 50}

# ============ 稀有度 / 干预 ============
const 稀有度序 := ["普通", "优秀", "稀有", "传说"]   # 四档（P0 拍板：普通/优秀/稀有/传说）

# 兜底期占位权重：CSV 不可用时回退，仅启用 普通/稀有 两档。
const _兜底稀有度权重 := {"普通": 70.0, "稀有": 30.0}   # [PLACEHOLDER]

# 紫+ 干预三档选项（ADR-002 D4 / GDD-奇遇 三.2）；UI 灰模由 art-lead 后续出。
const 干预选项 := [
	{"键": "放任自流", "消耗": "无",            "效果": "保持原性格自动判定"},
	{"键": "暗中相助", "消耗": "宗门贡献/灵石", "效果": "成功概率+15%，奖励品质+1档"},
	{"键": "亲自出手", "消耗": "高阶道具/声望", "效果": "强制最优分支，奖励拉满，额外道心值"},
]

# 境界序（用于过滤匹配）
const _境界序 := ["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体"]

# ============ CSV 事件池（懒加载）============
static var _csv事件池: Array = []          # 从 config/event_quest.csv 加载
static var _csv已加载 := false              # 懒加载标记
static var _csv加载失败 := false             # 文件不存在/异常 → 回退兜底

# Sprint-02b：权重衰减计数器（event_id → 触发次数）
static var _已触发计数: Dictionary = {}

# 从 config/event_quest.csv 加载事件池（ADR-002 R1，200则完全替换）
static func _确保csv加载() -> void:
	if _csv已加载:
		return
	_csv已加载 = true
	
	var file: FileAccess = FileAccess.open("res://config/event_quest.csv", FileAccess.READ)
	if file == null:
		_csv加载失败 = true
		push_warning("Quest: event_quest.csv 未找到，回退到 Lore.取奇遇 兜底")
		return
	
	# 跳过 header
	file.get_csv_line()
	
	while not file.eof_reached():
		var parts: PackedStringArray = file.get_csv_line()
		if parts.size() < 18:   # 最少 20 列，18 = opt3 全空的情况
			continue
		var eid: String = parts[0].strip_edges()
		if eid.is_empty():
			continue
		
		# opt3 可能为空（无第三个选项），安全取数
		var opt3_desc: String = "" if parts.size() < 15 else (parts[14].strip_edges() if parts[14] != null else "")
		var opt3_reward: String = "" if parts.size() < 16 else (parts[15].strip_edges() if parts[15] != null else "")
		var opt3_punish: String = "" if parts.size() < 17 else (parts[16].strip_edges() if parts[16] != null else "")
		
		# Sprint-02b：新 6 列（宗门等级缩放 + 展示层级 + 权重衰减）
		var base_value := 0.0
		var level_factor := 0.15
		var min_value := 0.0
		var max_value := 999.0
		var display_level := 2
		var weight_decay := 0.7
		if parts.size() >= 21:
			base_value = float(parts[20]) if parts[20].strip_edges().is_valid_float() else 0.0
		if parts.size() >= 22:
			level_factor = float(parts[21]) if parts[21].strip_edges().is_valid_float() else 0.15
		if parts.size() >= 23:
			min_value = float(parts[22]) if parts[22].strip_edges().is_valid_float() else 0.0
		if parts.size() >= 24:
			max_value = float(parts[23]) if parts[23].strip_edges().is_valid_float() else 999.0
		if parts.size() >= 25:
			display_level = int(parts[24]) if parts[24].strip_edges().is_valid_int() else 2
		if parts.size() >= 26:
			weight_decay = float(parts[25]) if parts[25].strip_edges().is_valid_float() else 0.7
		
		var evt: Dictionary = {
			"event_id": eid,
			"event_name": parts[1].strip_edges(),
			"event_type": parts[2].strip_edges(),
			"rarity": parts[3].strip_edges(),
			"trigger_scene": parts[4].strip_edges(),
			"unlock_sect_level": int(parts[5]) if parts[5].strip_edges().is_valid_int() else 1,
			"unlock_realm": parts[6].strip_edges(),
			"event_content": parts[7].strip_edges(),
			"opt1_desc": parts[8].strip_edges(),
			"opt1_reward": parts[9].strip_edges(),
			"opt1_punish": parts[10].strip_edges(),
			"opt2_desc": parts[11].strip_edges(),
			"opt2_reward": parts[12].strip_edges(),
			"opt2_punish": parts[13].strip_edges(),
			"opt3_desc": opt3_desc,
			"opt3_reward": opt3_reward,
			"opt3_punish": opt3_punish,
			"weight": int(parts[17]) if parts[17].strip_edges().is_valid_int() else 0,
			"cooldown_hour": int(parts[18]) if parts.size() >= 20 and parts[18].strip_edges().is_valid_int() else 0,
			"base_value": base_value,
			"level_factor": level_factor,
			"min_value": min_value,
			"max_value": max_value,
			"display_level": display_level,
			"weight_decay": weight_decay,
			"触发周期": parts[27].strip_edges() if (parts.size() >= 28 and parts[27] != null) else "",
		}
		_csv事件池.append(evt)
	
	if _csv事件池.is_empty():
		_csv加载失败 = true
		push_warning("Quest: event_quest.csv 无有效数据，回退到 Lore.取奇遇 兜底")

# ============ 接口函数 ============

# 性格 → 四维查表（派生，不新增 disciple 字段；ADR-002 D3）。
static func 性格四维(性格: String) -> Dictionary:
	return 性格四维表.get(性格, _中性四维.duplicate())

# 是否需掌门干预：S0 仅「传说」触发（干预 UI 待 S1；稀有/优秀/普通直接结算，避免奖励因 UI 未建而静默丢失）。
# S1 建干预 UI 后改回 ["稀有", "传说"]（高两档均需抉择）。
static func 是否需干预(稀有度: String) -> bool:
	return 稀有度 in ["传说"]

# 从 CSV 按境界过滤 + 权重抽取一条（Sprint-02b：加入权重衰减）
static func _抽csv事件(d: Disciple, scene: String = "") -> Dictionary:
	_确保csv加载()
	if _csv事件池.is_empty():
		return {}
	
	# 找弟子境界索引
	var d_idx: int = _境界序.find(d.境界)
	if d_idx < 0:
		d_idx = 0
	
	# 筛选 unlock_realm ≤ 弟子境界
	var 候选: Array = []
	var 总权重 := 0
	for evt in _csv事件池:
		# WAVE-A #5：触发周期 分级；年度/七载 事件不进日常随机池
		# （由岁末考评/七载大典钩子按 触发周期 过滤展示；日常/空 仍照常进池）
		var 周期_过滤: String = evt.get("触发周期", "")
		if 周期_过滤 != "" and 周期_过滤 != "日常":
			continue
		var e_idx: int = _境界序.find(evt["unlock_realm"])
		if e_idx >= 0 and e_idx <= d_idx:
			# 按场景路由过滤（Step 1 三场景接入）：scene 非空时仅取匹配 trigger_scene 的事件
			if scene != "" and evt["trigger_scene"] != scene:
				continue
			# Sprint-02b：权重衰减（衰减后权重 = 原始权重 × weight_decay^触发次数，保留至少 1）
			var 衰减后权重 := evt["weight"] as int
			if _已触发计数.has(evt["event_id"]):
				var n := _已触发计数[evt["event_id"]] as int
				var decay := evt["weight_decay"] as float
				var 因子: float = pow(decay, n)
				衰减后权重 = max(1, int(round(evt["weight"] * 因子)))
			evt["_衰减后权重"] = 衰减后权重
			候选.append(evt)
			总权重 += 衰减后权重
	
	if 候选.is_empty() or 总权重 <= 0:
		return {}
	
	# 按衰减后权重随机抽取
	var 抽: int = randi() % 总权重
	for evt in 候选:
		抽 -= evt["_衰减后权重"]
		if 抽 < 0:
			return evt
	return 候选[0]

# WAVE-A #5：按 触发周期 取事件（岁末考评/七载大典钩子展示用；纯查询，零数值）。
# 周期 ∈ {"日常","年度","七载"}；返回匹配的事件字典数组（可能为空）。
static func _取周期事件(周期: String) -> Array:
	_确保csv加载()
	var 结果: Array = []
	for evt in _csv事件池:
		if evt.get("触发周期", "") == 周期:
			结果.append(evt)
	return 结果

# 奇遇抽取（ADR-002 D2）。
# 数据源切换：CSV 200则到位后走 CSV 按境界过滤+权重抽取；
#            CSV 加载失败时回退到 Lore.取奇遇 兜底。
# 返回契约 Dictionary：{文案, 稀有度, 需干预, 奖励, event_name, opt1_*, opt2_*}
#   · 文案    ：CSV 模式 = event_content；兜底 = Lore.取奇遇()
#   · 稀有度  ：来自 CSV rarity 字段 / 兜底期占位随机
#   · 需干预  ：S0 仅「传说」为 true（干预 UI 待 S1；S1 扩为 稀有/传说）
#   · 奖励    ：兜底期 null（game_state 走随机小奖励）
static func 抽取(d: Disciple, scene: String = "") -> Dictionary:
	_确保csv加载()
	
	# CSV 模式：按境界过滤 + 权重抽取
	if not _csv事件池.is_empty():
		var evt: Dictionary = _抽csv事件(d, scene)
		if not evt.is_empty():
			# Sprint-02b：记录触发次数（供权重衰减）
			var eid := evt["event_id"] as String
			_已触发计数[eid] = _已触发计数.get(eid, 0) + 1
			return {
				"文案": evt["event_content"],
				"稀有度": evt["rarity"],
				"需干预": 是否需干预(evt["rarity"]),
				"奖励": null,
				"event_name": evt["event_name"],
				"event_type": evt["event_type"],
				"trigger_scene": evt["trigger_scene"],
				"opt1_desc": evt["opt1_desc"],
				"opt1_reward": evt["opt1_reward"],
				"opt1_punish": evt["opt1_punish"],
				"opt2_desc": evt["opt2_desc"],
				"opt2_reward": evt["opt2_reward"],
				"opt2_punish": evt["opt2_punish"],
				"opt3_desc": evt["opt3_desc"],
				"opt3_reward": evt["opt3_reward"],
				"opt3_punish": evt["opt3_punish"],
				# Sprint-02b：新字段透传
				"display_level": evt.get("display_level", 2),
				"base_value": evt.get("base_value", 0.0),
				"level_factor": evt.get("level_factor", 0.15),
				"min_value": evt.get("min_value", 0.0),
				"max_value": evt.get("max_value", 999.0),
				"weight_decay": evt.get("weight_decay", 0.7),
				"cooldown_hour": evt.get("cooldown_hour", 0),
			}
	
	# 回退：Lore 兜底
	var 文案: String = Lore.取奇遇(d.境界)
	var 稀有度: String = _加权抽(_兜底稀有度权重)
	return {
		"文案": 文案,
		"稀有度": 稀有度,
		"需干预": 是否需干预(稀有度),
		"奖励": null,
	}

# 加权随机（复用 disciple/item 的同款算法）
static func _加权抽(权重: Dictionary) -> String:
	var 总 := 0.0
	for k in 权重:
		总 += 权重[k]
	var 抽: float = randf() * 总
	for k in 权重:
		抽 -= 权重[k]
		if 抽 <= 0:
			return k
	return 权重.keys()[0]

# Sprint-02b：宗门等级缩放（纯函数，供 game_state.gd 结算调用）
# 公式：clamp(base × (1 + 门派等级 × factor), min_v, max_v)
static func _缩放入参(base: float, factor: float, min_v: float, max_v: float) -> float:
	return clamp(base * (1.0 + Game.门派等级 * factor), min_v, max_v)

# ============ 奇遇·征伐类 战斗接入（ADR-003 D6① / ADR-002 hook）============
# 征伐类奇遇 = 触发即开战。本文件作为「奇遇引擎叶子」只做两件事：
#   ① 由征伐事件确定性派生敌方 CombatantData 快照（不写死测试值，随玩家境界缩放）；
#   ② 调用 BattleCalculator 纯数值结算（quick 模式），把统一 BattleResult 回传「奇遇管理器」（game_state）。
# 奇遇叶子仅调 BattleCalculator 纯数值结算（quick 模式）：不预载入战斗编排层、
# 不打开战斗场景、不播放战斗流程。
# 不在此处发放奖励/记 履历——那属奇遇管理器收尾职责（见 game_state.结算征伐奇遇）。

# 由征伐事件派生敌方战斗快照列表（P0 占位确定性生成，数值待 design 校准）。
# 字段严格对齐 BattleCalculator 消费的 CombatantData 契约：
#   战力/属性{攻防血速}/职业/灵根{主,纯度}/灵兽战力/极品特效/通用增益/道心增益/暴击率/闪避率/名称
static func 征伐敌方快照(事件: Dictionary, 玩家境界: String) -> Array:
	var 数量: int = int(事件.get("征伐数量", 1))
	数量 = clamp(数量, 1, 3)   # P0 征伐规模：单体或三人小队
	# 敌方属性基准随玩家境界缩放（复用 disciple.境界表 战力基线；数值为 [PLACEHOLDER]，非硬编码测试值）
	var 基线 := Disciple.境界表.get(玩家境界, Disciple.境界表["练气"])["战力"] as float
	var 总属性: int = int(clamp(基线 * 0.5, 40, 2000))   # 占位：敌方总属性量级≈玩家境界战力一半
	var 职业池: Array = ["道修", "体修", "法修"]
	var 灵根池: Array = ["金", "木", "水", "火", "土"]
	var 快照列表 := []
	for i in 数量:
		var 职业: String = 职业池[i % 职业池.size()]
		var 灵根: String = 灵根池[(i * 2) % 灵根池.size()]
		# 占位属性分布（按职业侧重近似，数值待 design 录入）
		var 属性: Dictionary = {
			"攻": int(总属性 * 0.30), "防": int(总属性 * 0.25),
			"血": int(总属性 * 0.35), "速": int(总属性 * 0.10),
		}
		# 暴击/闪避率：与 disciple.get_final_combat_attr() 同源推导口径（非硬编码）
		var 暴击率: float = clamp(float(属性["速"]) * 0.004, 0.0, 1.0)
		if 灵根 in ["雷", "金"]:
			暴击率 += 0.05
		var 闪避率: float = clamp(float(属性["速"]) * 0.003, 0.0, 1.0)
		if 灵根 in ["风", "水"]:
			闪避率 += 0.05
		快照列表.append({
			"战力": 总属性,
			"属性": 属性,
			"职业": 职业,
			"灵根": {"主": 灵根, "纯度": "单"},
			"灵兽战力": 0,
			"极品特效": [],
			"通用增益": 0.0,
			"道心增益": 0.0,
			"暴击率": 暴击率,
			"闪避率": 闪避率,
			"名称": "征伐妖·%d" % (i + 1),
		})
	return 快照列表

# 征伐类奇遇战斗结算（ADR-003 D6①）：攻方=弟子战斗快照，守方=征伐事件派生的敌方列表。
# 单体 → 结算_1v1；小队 → 结算_3v3 车轮（攻方单弟子 vs 敌方列表，气血继承）。
# 仅走 BattleCalculator 纯数值结算（quick 模式，纯数值口径，无 UI / 无战斗流程副作用）。
# 返回统一 BattleResult 给奇遇管理器收尾（奖励/履历在 game_state.结算征伐奇遇 处理，字段不变）。
static func 结算征伐(d: Disciple, 事件: Dictionary) -> Dictionary:
	var 攻: Dictionary = d.get_final_combat_attr()          # 取自弟子最终属性接口（AC6，无硬编码）
	var 守列表: Array = 征伐敌方快照(事件, d.境界)
	if 守列表.is_empty():
		守列表 = 征伐敌方快照({"征伐数量": 1}, d.境界)   # 防御：保证至少 1 名敌方
	var 战报: Dictionary
	if 守列表.size() == 1:
		战报 = BattleCalculator.结算_1v1(攻, 守列表[0], "quick")
	else:
		# 1vN 车轮：攻方列表仅含该弟子，守方列表为敌方小队（气血继承）
		战报 = BattleCalculator.结算_3v3([攻], 守列表, "quick")
	return 战报

# 调试/强制触发用：从已加载的 CSV 事件池取一条 event_type=征伐 的测试事件。
# 优先按 event_id 精确匹配；未命中则回退到池中第一条 征伐 事件；仍无则返回 {}。
# 不污染正式随机池（trigger_weight=0 的行本就不参与 _抽csv事件 加权抽取）。
static func 取征伐测试事件(event_id: String = "T_ZF_01") -> Dictionary:
	_确保csv加载()
	if _csv事件池.is_empty():
		return {}
	var 回退 := {}
	for evt in _csv事件池:
		if evt["event_type"] == "征伐":
			if evt["event_id"] == event_id:
				return evt
			if 回退.is_empty():
				回退 = evt
	return 回退

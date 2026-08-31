extends RefCounted
class_name FactionSystem

## 阵营声望系统（GDD §2.1 五大阵营声望体系）
## 设计依据：太玄宗门录_核心设定总览 v2.67 §2.1-2.2
## 核心原则：数据驱动、玩法阈值解锁、性格映射复用、正魔此消彼长

# ============ 五大阵营定义（§2.1）============
# 1. 正道宗门 - 稳健低风险，弟子道心成长快、心魔低、突破平稳
# 2. 魔道邪宗 - 高攻高风险，弟子修炼快、攻击高，但心魔增长快、易走火入魔
# 3. 中立散修 - 灵活均衡，弟子基数大、易出特殊命格
# 4. 上古妖兽族群 - 灵兽与秘境载体，高阶灵兽契约/繁育权限解锁
# 5. 远古遗泽 - 后期核心机缘，圣品以上突破、道品锻造的核心素材
const FACTION_LIST: Array = ["正道宗门", "魔道邪宗", "中立散修", "上古妖兽", "远古遗泽"]

# 阵营简称（用于UI显示）
const FACTION_SHORT: Dictionary = {
	"正道宗门": "正道",
	"魔道邪宗": "魔道",
	"中立散修": "散修",
	"上古妖兽": "妖兽",
	"远古遗泽": "遗泽",
}

# 阵营主色（用于UI显示）
const FACTION_COLOR: Dictionary = {
	"正道宗门": Color(0.3, 0.7, 1.0),  # 蓝色
	"魔道邪宗": Color(0.9, 0.2, 0.3),  # 红色
	"中立散修": Color(0.6, 0.6, 0.6),  # 灰色
	"上古妖兽": Color(0.2, 0.8, 0.4),  # 绿色
	"远古遗泽": Color(0.9, 0.7, 0.2),  # 金色
}

# ============ 声望等级定义（§2.1.2）============
# 5级声望：冷淡→中立→友善→尊敬→崇敬
const REPUTATION_LEVELS: Array = ["冷淡", "中立", "友善", "尊敬", "崇敬"]
const REPUTATION_THRESHOLDS: Array = [0, 100, 500, 2000, 5000]  # 各等级所需声望值

# ============ 阵营对立关系（§2.1.3 正魔此消彼长）============
# 正道与魔道对立：增加一方声望，另一方降低30%
const OPPOSITE_FACTIONS: Dictionary = {
	"正道宗门": "魔道邪宗",
	"魔道邪宗": "正道宗门",
}
const OPPOSITE_DECAY_RATE: float = 0.3  # 对立阵营衰减比例

# ============ 弟子阵营倾向映射（§2.1.4 十二性格映射复用）============
# 弟子性格→阵营倾向权重（无需新增字段，复用十二性格）
const PERSONALITY_FACTION_BIAS: Dictionary = {
	"正直": {"正道宗门": 2.0, "魔道邪宗": 0.3, "中立散修": 1.0, "上古妖兽": 0.8, "远古遗泽": 1.0},
	"善良": {"正道宗门": 1.8, "魔道邪宗": 0.4, "中立散修": 1.2, "上古妖兽": 1.0, "远古遗泽": 1.0},
	"邪恶": {"正道宗门": 0.3, "魔道邪宗": 2.0, "中立散修": 1.0, "上古妖兽": 1.2, "远古遗泽": 0.8},
	"狡诈": {"正道宗门": 0.5, "魔道邪宗": 1.8, "中立散修": 1.5, "上古妖兽": 1.0, "远古遗泽": 1.2},
	"勇敢": {"正道宗门": 1.5, "魔道邪宗": 1.5, "中立散修": 1.0, "上古妖兽": 1.2, "远古遗泽": 1.0},
	"怯懦": {"正道宗门": 1.0, "魔道邪宗": 0.8, "中立散修": 1.5, "上古妖兽": 0.8, "远古遗泽": 1.0},
	"聪慧": {"正道宗门": 1.2, "魔道邪宗": 1.2, "中立散修": 1.2, "上古妖兽": 1.0, "远古遗泽": 1.5},
	"愚钝": {"正道宗门": 1.0, "魔道邪宗": 1.0, "中立散修": 1.2, "上古妖兽": 1.0, "远古遗泽": 0.8},
	"沉稳": {"正道宗门": 1.5, "魔道邪宗": 0.8, "中立散修": 1.2, "上古妖兽": 1.0, "远古遗泽": 1.2},
	"浮躁": {"正道宗门": 0.8, "魔道邪宗": 1.5, "中立散修": 1.2, "上古妖兽": 1.0, "远古遗泽": 0.8},
	"孤僻": {"正道宗门": 0.8, "魔道邪宗": 1.0, "中立散修": 1.8, "上古妖兽": 1.5, "远古遗泽": 1.2},
	"合群": {"正道宗门": 1.2, "魔道邪宗": 1.0, "中立散修": 1.5, "上古妖兽": 1.0, "远古遗泽": 1.0},
}

# ============ 玩法阈值解锁（§2.1.5）============
# 各阵营声望等级解锁的玩法
const FACTION_UNLOCKS: Dictionary = {
	"正道宗门": {
		"中立": ["正道商店基础商品"],
		"友善": ["正道任务", "正道弟子招募加成"],
		"尊敬": ["正道高阶功法", "正道问责事件"],
		"崇敬": ["正道专属皮肤", "正道秘境"],
	},
	"魔道邪宗": {
		"中立": ["魔道商店基础商品"],
		"友善": ["魔道任务", "魔道弟子招募加成"],
		"尊敬": ["魔道高阶功法", "黑市交易"],
		"崇敬": ["魔道专属皮肤", "魔道秘境"],
	},
	"中立散修": {
		"中立": ["散修商店基础商品"],
		"友善": ["散修任务", "散修弟子招募加成"],
		"尊敬": ["散修高阶功法", "竞猜玩法"],
		"崇敬": ["散修专属皮肤", "散修秘境"],
	},
	"上古妖兽": {
		"中立": ["灵兽商店基础商品"],
		"友善": ["灵兽任务", "高阶灵兽契约权限"],
		"尊敬": ["灵兽繁育权限", "灵兽秘境"],
		"崇敬": ["灵兽专属皮肤", "上古灵兽契约"],
	},
	"远古遗泽": {
		"中立": ["遗泽商店基础商品"],
		"友善": ["遗泽任务", "圣品突破素材"],
		"尊敬": ["道品锻造素材", "遗泽秘境"],
		"崇敬": ["遗泽专属皮肤", "远古传承"],
	},
}

# ============ 阵营权益（§2.1.6）============
# 各声望等级的权益
const FACTION_BENEFITS: Dictionary = {
	"冷淡": {"商店折扣": 1.0, "任务奖励加成": 1.0, "特殊商品解锁": false, "专属任务解锁": false},
	"中立": {"商店折扣": 1.0, "任务奖励加成": 1.0, "特殊商品解锁": false, "专属任务解锁": false},
	"友善": {"商店折扣": 0.95, "任务奖励加成": 1.05, "特殊商品解锁": false, "专属任务解锁": false},
	"尊敬": {"商店折扣": 0.90, "任务奖励加成": 1.10, "特殊商品解锁": true, "专属任务解锁": false},
	"崇敬": {"商店折扣": 0.85, "任务奖励加成": 1.15, "特殊商品解锁": true, "专属任务解锁": true},
}

# ============ 招贤阁刷新加权抽取（§2.2.4）============
# 基础权重池 + 声望修正系数 + 正魔此消彼长交叉抑制 + P_min最低概率红线
const BASE_RECRUIT_WEIGHTS: Dictionary = {
	"正道宗门": 1.0,
	"魔道邪宗": 1.0,
	"中立散修": 1.5,  # 散修基础权重更高（基数大）
	"上古妖兽": 0.5,  # 妖兽基础权重低（稀有）
	"远古遗泽": 0.3,  # 遗泽基础权重最低（极稀有）
}
const REPUTATION_MODIFIER_COEF: float = 0.001  # 每1点声望增加0.1%权重
const P_MIN_RECRUIT: float = 0.05  # 最低概率红线（5%）

# ============ 静态方法：获取声望等级 ============
static func get_reputation_level(reputation_value: int) -> String:
	for i in range(REPUTATION_THRESHOLDS.size()):
		if reputation_value < REPUTATION_THRESHOLDS[i]:
			return REPUTATION_LEVELS[max(0, i - 1)]
	return REPUTATION_LEVELS[-1]

# ============ 静态方法：获取阵营权益 ============
static func get_faction_benefits(reputation_level: String) -> Dictionary:
	return FACTION_BENEFITS.get(reputation_level, FACTION_BENEFITS["冷淡"]).duplicate()

# ============ 静态方法：获取阵营解锁玩法 ============
static func get_faction_unlocks(faction: String, reputation_level: String) -> Array:
	var faction_unlocks: Dictionary = FACTION_UNLOCKS.get(faction, {})
	return faction_unlocks.get(reputation_level, [])

# ============ 静态方法：检查玩法是否解锁 ============
static func is_feature_unlocked(faction: String, reputation_value: int, feature_name: String) -> bool:
	var level: String = get_reputation_level(reputation_value)
	var unlocks: Array = get_faction_unlocks(faction, level)
	# 检查当前等级及以下所有等级的解锁
	var level_idx: int = REPUTATION_LEVELS.find(level)
	for i in range(level_idx + 1):
		var lvl: String = REPUTATION_LEVELS[i]
		var lvl_unlocks: Array = get_faction_unlocks(faction, lvl)
		if feature_name in lvl_unlocks:
			return true
	return false

# ============ 静态方法：弟子性格→阵营倾向权重 ============
static func get_personality_faction_bias(personality: String) -> Dictionary:
	return PERSONALITY_FACTION_BIAS.get(personality, {
		"正道宗门": 1.0, "魔道邪宗": 1.0, "中立散修": 1.0, "上古妖兽": 1.0, "远古遗泽": 1.0
	}).duplicate()

# ============ 静态方法：招贤阁刷新加权抽取 ============
## 参数：
##   faction_reputations: 各阵营声望字典 {阵营: 声望值}
##   personality: 弟子性格（可选，用于性格倾向修正）
## 返回：加权随机选择的阵营
static func weighted_recruit_faction(faction_reputations: Dictionary, personality: String = "") -> String:
	var weights: Dictionary = {}
	var total_weight: float = 0.0
	# 计算各阵营权重
	for faction in FACTION_LIST:
		var base_weight: float = BASE_RECRUIT_WEIGHTS.get(faction, 1.0)
		var reputation: int = int(faction_reputations.get(faction, 0))
		var reputation_modifier: float = 1.0 + reputation * REPUTATION_MODIFIER_COEF
		var personality_bias: float = 1.0
		if personality != "":
			var bias_dict: Dictionary = get_personality_faction_bias(personality)
			personality_bias = bias_dict.get(faction, 1.0)
		var final_weight: float = base_weight * reputation_modifier * personality_bias
		weights[faction] = final_weight
		total_weight += final_weight
	# 正魔此消彼长交叉抑制（正道高则魔道权重降低，反之亦然）
	var zhengdao_rep: int = int(faction_reputations.get("正道宗门", 0))
	var modao_rep: int = int(faction_reputations.get("魔道邪宗", 0))
	if zhengdao_rep > modao_rep * 2:
		weights["魔道邪宗"] *= 0.7  # 正道远高于魔道，魔道权重降低30%
	elif modao_rep > zhengdao_rep * 2:
		weights["正道宗门"] *= 0.7  # 魔道远高于正道，正道权重降低30%
	# P_min最低概率红线：每个阵营至少5%概率
	var min_weight: float = total_weight * P_MIN_RECRUIT
	for faction in FACTION_LIST:
		if weights[faction] < min_weight:
			weights[faction] = min_weight
	# 重新计算总权重
	total_weight = 0.0
	for faction in FACTION_LIST:
		total_weight += weights[faction]
	# 加权随机选择
	var random_value: float = randf() * total_weight
	var cumulative: float = 0.0
	for faction in FACTION_LIST:
		cumulative += weights[faction]
		if random_value <= cumulative:
			return faction
	return FACTION_LIST[2]  # 默认返回中立散修

# ============ 静态方法：增加阵营声望（含对立阵营衰减）============
## 参数：
##   faction_reputations: 各阵营声望字典（会被修改）
##   faction: 要增加的阵营
##   value: 增加的声望值
## 返回：修改后的声望字典
static func add_faction_reputation(faction_reputations: Dictionary, faction: String, value: int) -> Dictionary:
	if not faction_reputations.has(faction):
		faction_reputations[faction] = 0
	faction_reputations[faction] = max(0, faction_reputations[faction] + value)
	# 对立阵营衰减
	if OPPOSITE_FACTIONS.has(faction):
		var opposite: String = OPPOSITE_FACTIONS[faction]
		if not faction_reputations.has(opposite):
			faction_reputations[opposite] = 0
		faction_reputations[opposite] = max(0, faction_reputations[opposite] - int(value * OPPOSITE_DECAY_RATE))
	return faction_reputations

# ============ 静态方法：获取综合阵营权益（取最高值）============
static func get_comprehensive_benefits(faction_reputations: Dictionary) -> Dictionary:
	var comprehensive: Dictionary = {
		"最高商店折扣": 1.0,
		"最高任务奖励加成": 1.0,
		"解锁特殊商品": false,
		"解锁专属任务": false,
	}
	for faction in FACTION_LIST:
		var reputation: int = int(faction_reputations.get(faction, 0))
		var level: String = get_reputation_level(reputation)
		var benefits: Dictionary = get_faction_benefits(level)
		comprehensive["最高商店折扣"] = min(comprehensive["最高商店折扣"], benefits["商店折扣"])
		comprehensive["最高任务奖励加成"] = max(comprehensive["最高任务奖励加成"], benefits["任务奖励加成"])
		if benefits["特殊商品解锁"]:
			comprehensive["解锁特殊商品"] = true
		if benefits["专属任务解锁"]:
			comprehensive["解锁专属任务"] = true
	return comprehensive

# ============ 静态方法：获取阵营描述（用于UI Tooltip）============
static func get_faction_description(faction: String) -> String:
	match faction:
		"正道宗门":
			return "稳健低风险，弟子道心成长快、心魔低、突破平稳。适合追求稳定发展的宗主。"
		"魔道邪宗":
			return "高攻高风险，弟子修炼快、攻击高，但心魔增长快、易走火入魔。适合追求极致战力的宗主。"
		"中立散修":
			return "灵活均衡，弟子基数大、易出特殊命格。适合追求多样性的宗主。"
		"上古妖兽":
			return "灵兽与秘境载体，高阶灵兽契约/繁育权限解锁。适合重视灵兽培养的宗主。"
		"远古遗泽":
			return "后期核心机缘，圣品以上突破、道品锻造的核心素材。适合追求后期上限的宗主。"
		_:
			return ""

# ============ 静态方法：初始化阵营声望字典 ============
static func init_faction_reputations() -> Dictionary:
	var reputations: Dictionary = {}
	for faction in FACTION_LIST:
		reputations[faction] = 0
	return reputations

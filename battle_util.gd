extends RefCounted
class_name BattleUtil

## 战斗工具类（防御属性溢出治理统一函数）
## 设计依据：GDD §4.4 防御属性溢出治理红线 + §9.4 防御属性溢出治理
## 核心原则：自动卡上限，禁止各自计算；统一入口，跨系统复用

# ============ 防御属性硬上限（§4.4 红线 + §9.4.5 等效战力折算）============
# 闪避率硬上限：40%（AC7②，BattleCalculator 已有，此处统一收口）
const EVASION_RATE_CAP: float = 0.40
# 暴击率硬上限：70%（AC7②，BattleCalculator 已有，此处统一收口）
const CRIT_RATE_CAP: float = 0.70
# 伤害减免硬上限：75%（§4.4 常驻全减伤独立层，护山大阵上限70%+其他5%）
const DMG_REDUCTION_CAP: float = 0.75
# 抗性硬上限：80%（§9.4 机制层减伤·规避，独立硬上限）
const RESIST_CAP: float = 0.80
# 防御等效战力占比硬上限：25%（§9.4.5 生存时间等价法，面板等效战力25%封顶）
const DEFENSE_POWER_RATIO_CAP: float = 0.25
# 境界压制穿透率：20%（§9.4.7 境界压制独立处理，高境界对低境界20%穿透命中）
const REALM_SUPPRESS_PENETRATION: float = 0.20

# ============ 防御乘区划分（§9.4.6 四层防御独立乘区）============
# 乘区1：基础防御（属性"防" → 减伤率 = 防/(防+基准)，封顶75%）
const BASE_DEFENSE_REFERENCE: float = 200.0  # 防御减伤基准（BattleCalculator 防御减伤基准）
# 乘区2：技能/功法防御（被动技能、功法提供的减伤，独立乘区）
# 乘区3：装备/套装防御（装备词缀、套装效果提供的减伤，独立乘区）
# 乘区4：大阵/特殊防御（护山大阵、聚灵阵、特殊buff提供的减伤，独立乘区）

# ============ 统一函数1：闪避率计算（自动卡上限）============
## 计算最终闪避率，自动卡40%上限
## 参数：
##   base_evasion: 基础闪避率（由速度+灵根推导，0~1）
##   skill_evasion: 技能/功法闪避加成（0~1）
##   equip_evasion: 装备/套装闪避加成（0~1）
##   array_evasion: 大阵/特殊闪避加成（0~1）
## 返回：最终闪避率（0~0.40）
static func calc_evasion_rate(base_evasion: float = 0.0, skill_evasion: float = 0.0, equip_evasion: float = 0.0, array_evasion: float = 0.0) -> float:
	# 四层乘区连乘（独立乘区，非叠加）
	var final_evasion: float = 1.0
	final_evasion *= (1.0 - clamp(base_evasion, 0.0, 1.0))
	final_evasion *= (1.0 - clamp(skill_evasion, 0.0, 1.0))
	final_evasion *= (1.0 - clamp(equip_evasion, 0.0, 1.0))
	final_evasion *= (1.0 - clamp(array_evasion, 0.0, 1.0))
	# 转换为闪避率（1 - 被命中率）
	var evasion_rate: float = 1.0 - final_evasion
	# 自动卡40%上限
	return clamp(evasion_rate, 0.0, EVASION_RATE_CAP)

# ============ 统一函数2：伤害减免计算（自动卡上限）============
## 计算最终伤害减免率，自动卡75%上限
## 参数：
##   defense: 基础防御值（属性"防"）
##   skill_reduction: 技能/功法减伤加成（0~1）
##   equip_reduction: 装备/套装减伤加成（0~1）
##   array_reduction: 大阵/特殊减伤加成（0~1）
## 返回：最终伤害减免率（0~0.75）
static func calc_dmg_reduction(defense: int = 0, skill_reduction: float = 0.0, equip_reduction: float = 0.0, array_reduction: float = 0.0) -> float:
	# 乘区1：基础防御减伤率 = 防/(防+基准)，封顶75%
	var base_reduction: float = float(defense) / (float(defense) + BASE_DEFENSE_REFERENCE)
	base_reduction = clamp(base_reduction, 0.0, DMG_REDUCTION_CAP)
	# 四层乘区连乘（独立乘区，非叠加）
	var final_survival: float = 1.0
	final_survival *= (1.0 - base_reduction)
	final_survival *= (1.0 - clamp(skill_reduction, 0.0, 1.0))
	final_survival *= (1.0 - clamp(equip_reduction, 0.0, 1.0))
	final_survival *= (1.0 - clamp(array_reduction, 0.0, 1.0))
	# 转换为减伤率（1 - 受伤率）
	var reduction_rate: float = 1.0 - final_survival
	# 自动卡75%上限
	return clamp(reduction_rate, 0.0, DMG_REDUCTION_CAP)

# ============ 统一函数3：抗性计算（自动卡上限）============
## 计算最终抗性率（元素/异常状态抗性），自动卡80%上限
## 参数：
##   base_resist: 基础抗性（0~1）
##   skill_resist: 技能/功法抗性加成（0~1）
##   equip_resist: 装备/套装抗性加成（0~1）
##   array_resist: 大阵/特殊抗性加成（0~1）
## 返回：最终抗性率（0~0.80）
static func calc_resist(base_resist: float = 0.0, skill_resist: float = 0.0, equip_resist: float = 0.0, array_resist: float = 0.0) -> float:
	# 四层乘区连乘（独立乘区，非叠加）
	var final_vulnerability: float = 1.0
	final_vulnerability *= (1.0 - clamp(base_resist, 0.0, 1.0))
	final_vulnerability *= (1.0 - clamp(skill_resist, 0.0, 1.0))
	final_vulnerability *= (1.0 - clamp(equip_resist, 0.0, 1.0))
	final_vulnerability *= (1.0 - clamp(array_resist, 0.0, 1.0))
	# 转换为抗性率（1 - 易伤率）
	var resist_rate: float = 1.0 - final_vulnerability
	# 自动卡80%上限
	return clamp(resist_rate, 0.0, RESIST_CAP)

# ============ 统一函数4：暴击率计算（自动卡上限）============
## 计算最终暴击率，自动卡70%上限
## 参数：
##   base_crit: 基础暴击率（由速度+灵根推导，0~1）
##   skill_crit: 技能/功法暴击加成（0~1）
##   equip_crit: 装备/套装暴击加成（0~1）
##   array_crit: 大阵/特殊暴击加成（0~1）
## 返回：最终暴击率（0~0.70）
static func calc_crit_rate(base_crit: float = 0.0, skill_crit: float = 0.0, equip_crit: float = 0.0, array_crit: float = 0.0) -> float:
	# 暴击率采用叠加方式（非独立乘区，因为暴击是攻击方属性）
	var final_crit: float = base_crit + skill_crit + equip_crit + array_crit
	# 自动卡70%上限
	return clamp(final_crit, 0.0, CRIT_RATE_CAP)

# ============ 统一函数5：防御等效战力折算（§9.4.5 生存时间等价法）============
## 计算防御等效战力（面板等效战力，25%封顶）
## 参数：
##   base_power: 基础战力（攻击+气血等进攻性战力）
##   defense: 防御值
##   evasion_rate: 闪避率（0~1）
##   reduction_rate: 减伤率（0~1）
## 返回：防御等效战力（不超过基础战力的25%）
static func calc_defense_power(base_power: int, defense: int = 0, evasion_rate: float = 0.0, reduction_rate: float = 0.0) -> int:
	# 生存时间等价法：生存时间 = 1 / ((1-闪避率) × (1-减伤率))
	var survival_multiplier: float = 1.0
	survival_multiplier /= max(0.01, (1.0 - clamp(evasion_rate, 0.0, 1.0)) * (1.0 - clamp(reduction_rate, 0.0, 1.0)))
	# 防御等效战力 = 基础战力 × (生存倍率 - 1)
	var defense_power: float = float(base_power) * (survival_multiplier - 1.0)
	# 自动卡25%上限
	var max_defense_power: float = float(base_power) * DEFENSE_POWER_RATIO_CAP
	return int(clamp(defense_power, 0.0, max_defense_power))

# ============ 统一函数6：境界压制（§9.4.7 独立处理）============
## 计算境界压制效果（高境界对低境界20%穿透命中）
## 参数：
##   attacker_realm: 攻击者境界（如"练气"、"筑基"等）
##   defender_realm: 防御者境界
##   realm_order: 境界顺序数组（从低到高）
## 返回：境界压制效果字典 {has_suppress: bool, penetration: float, damage_multiplier: float}
static func realm_suppress(attacker_realm: String, defender_realm: String, realm_order: Array = []) -> Dictionary:
	if realm_order.is_empty():
		realm_order = ["练气", "筑基", "金丹", "元婴", "化神", "仙阶", "道阶"]
	var attacker_idx: int = realm_order.find(attacker_realm)
	var defender_idx: int = realm_order.find(defender_realm)
	if attacker_idx < 0 or defender_idx < 0:
		return {"has_suppress": false, "penetration": 0.0, "damage_multiplier": 1.0}
	var realm_diff: int = attacker_idx - defender_idx
	if realm_diff <= 0:
		# 攻击者境界不高于防御者，无压制
		return {"has_suppress": false, "penetration": 0.0, "damage_multiplier": 1.0}
	# 境界压制：每差1阶，穿透+5%，伤害+10%，上限20%穿透/50%伤害
	var penetration: float = clamp(float(realm_diff) * 0.05, 0.0, REALM_SUPPRESS_PENETRATION)
	var damage_multiplier: float = 1.0 + clamp(float(realm_diff) * 0.10, 0.0, 0.50)
	return {"has_suppress": true, "penetration": penetration, "damage_multiplier": damage_multiplier, "realm_diff": realm_diff}

# ============ 统一函数7：最终伤害计算（整合所有防御乘区）============
## 计算最终伤害（整合攻击、防御、闪避、暴击、境界压制）
## 参数：
##   base_damage: 基础伤害
##   attacker: 攻击者战斗属性字典 {攻, 防, 血, 速, 暴击率, 闪避率, 境界, 职业, 灵根}
##   defender: 防御者战斗属性字典
## 返回：最终伤害字典 {damage: int, is_crit: bool, is_evade: bool, has_suppress: bool}
static func calc_final_damage(base_damage: int, attacker: Dictionary, defender: Dictionary) -> Dictionary:
	# 1. 闪避判定
	var defender_evasion: float = float(defender.get("闪避率", 0.0))
	if randf() < defender_evasion:
		return {"damage": 0, "is_crit": false, "is_evade": true, "has_suppress": false}
	# 2. 暴击判定
	var attacker_crit: float = float(attacker.get("暴击率", 0.0))
	var is_crit: bool = randf() < attacker_crit
	var crit_multiplier: float = 1.5 if is_crit else 1.0  # 暴击系数1.5（BattleCalculator 暴击系数）
	# 3. 境界压制
	var suppress_result: Dictionary = realm_suppress(str(attacker.get("境界", "")), str(defender.get("境界", "")))
	var suppress_penetration: float = suppress_result.get("penetration", 0.0)
	var suppress_multiplier: float = suppress_result.get("damage_multiplier", 1.0)
	# 4. 防御减伤（穿透无视部分防御）
	var defender_defense: int = int(defender.get("属性", {}).get("防", 0))
	var effective_defense: int = int(float(defender_defense) * (1.0 - suppress_penetration))
	var reduction_rate: float = calc_dmg_reduction(effective_defense)
	# 5. 最终伤害计算
	var final_damage: float = float(base_damage) * crit_multiplier * suppress_multiplier * (1.0 - reduction_rate)
	# 6. 伤害下限（高防兜底，最低造成1点）
	final_damage = max(1.0, final_damage)
	return {"damage": int(final_damage), "is_crit": is_crit, "is_evade": false, "has_suppress": suppress_result.get("has_suppress", false), "reduction_rate": reduction_rate}

# ============ 工具函数：战斗属性快照转换 ============
## 从Disciple对象转换为战斗属性快照（供BattleCalculator使用）
static func disciple_to_combat_snapshot(disciple: Node) -> Dictionary:
	if disciple == null or not disciple.has_method("get_final_combat_attr"):
		return {}
	return disciple.get_final_combat_attr()

# ============ 工具函数：战力对比评估 ============
## 评估双方战力对比，返回胜负概率
## 参数：attacker_power, defender_power
## 返回：胜率（0~1）
static func calc_win_probability(attacker_power: int, defender_power: int) -> float:
	if defender_power <= 0:
		return 1.0
	var power_ratio: float = float(attacker_power) / float(defender_power)
	# S型曲线：战力比1时胜率50%，战力比2时胜率80%，战力比0.5时胜率20%
	var win_rate: float = 0.5 + 0.3 * (power_ratio - 1.0) / (power_ratio + 1.0)
	return clamp(win_rate, 0.05, 0.95)

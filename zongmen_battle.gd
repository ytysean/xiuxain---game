extends RefCounted
class_name ZongmenBattle

## 宗门战战斗系统（GDD §11.4 宗门战）
## 设计依据：太玄宗门录_核心设定总览 v2.67 §11.4
## 核心原则：全自动放置推演、队伍编制、车轮战、护山大阵耐久、战报结算
## 零战斗触碰铁律：玩家不直接操作战斗，仅做战前策略配置

# ============ 宗门战类型（§11.4.1 四类差异化玩法）============
const BATTLE_TYPES: Dictionary = {
	"宗门攻防战": {"描述": "宗门之间的攻防战，攻方需攻破护山大阵", "回合上限": 20, "大阵耐久": true},
	"秘境争夺战": {"描述": "争夺秘境资源的战斗", "回合上限": 15, "大阵耐久": false},
	"妖兽围剿战": {"描述": "围剿妖兽族群的战斗", "回合上限": 20, "大阵耐久": false, "妖兽援军": true},
	"阵营围剿战": {"描述": "阵营之间的围剿战斗", "回合上限": 25, "大阵耐久": true},
}

# ============ 队伍编制（§11.4.2）============
# 每队最多5人，分前排（2人）、中排（2人）、后排（1人）
const MAX_TEAM_SIZE: int = 5
const FRONT_ROW_SIZE: int = 2
const MIDDLE_ROW_SIZE: int = 2
const BACK_ROW_SIZE: int = 1

# ============ 车轮战规则（§11.4.3）============
# 每方最多3队，一队全灭后下一队接续
const MAX_TEAMS_PER_SIDE: int = 3

# ============ 护山大阵（§11.4.4）============
# 护山大阵耐久：根据宗门等级和阵法等级决定
# 大阵被攻破后，防守方弟子受到额外伤害
const BASE_ARRAY_DURABILITY: int = 1000  # 基础大阵耐久
const ARRAY_DAMAGE_REDUCTION: float = 0.3  # 大阵存在时减伤30%
const ARRAY_BROKEN_PENALTY: float = 0.2  # 大阵被破后防守方受到额外20%伤害

# ============ 战前增益（§11.4.5）============
# 玩家可配置的战前增益（消耗资源）
const PRE_BATTLE_BUFFS: Dictionary = {
	"聚灵阵加持": {"攻击加成": 0.10, "防御加成": 0.10, "消耗灵石": 500, "持续回合": 5},
	"战鼓激励": {"攻击加成": 0.15, "消耗灵石": 300, "持续回合": 3},
	"护盾结界": {"防御加成": 0.20, "消耗灵石": 400, "持续回合": 4},
	"丹药补给": {"生命加成": 0.15, "消耗丹药": 5, "持续回合": 99},
}

# ============ 妖兽援军（§11.4.6 v2.8修订）============
# 妖兽援军改为自身3回合属性buff（通用增益乘区）
const BEAST_BUFF: Dictionary = {
	"攻击加成": 0.20,
	"防御加成": 0.10,
	"持续回合": 3,
	"触发条件": "血量低于50%时触发",
}

# ============ 战斗结果枚举 ============
enum BattleResult {
	ONGOING,  # 进行中
	ATTACKER_WIN,  # 攻方胜利
	DEFENDER_WIN,  # 守方胜利
	DRAW,  # 平局（超时按战力占比判）
}

# ============ 战斗状态数据结构 ============
# 战斗状态字典
# 大阵耐久基准（可选，>0 时取代 BASE_ARRAY_DURABILITY）：
#   固定 1000 的耐久与战力规模脱钩 —— 低战力时打不破（全程吃 30% 减伤），
#   高战力时首回合即破（数值形同虚设）。调用方应按守方总战力量级传入，
#   建议值 = 守方总战力 × 0.2（约 4 回合破阵）。不传则退回 1000 的旧常量。
static func create_battle_state(battle_type: String, attacker_teams: Array, defender_teams: Array, defender_array_level: int = 1, 大阵耐久基准: int = 0) -> Dictionary:
	var type_config: Dictionary = BATTLE_TYPES.get(battle_type, BATTLE_TYPES["宗门攻防战"])
	var 耐久: int = 0
	if type_config.get("大阵耐久", false):
		耐久 = (大阵耐久基准 if 大阵耐久基准 > 0 else BASE_ARRAY_DURABILITY) * max(1, defender_array_level)
	return {
		"战斗类型": battle_type,
		"回合上限": type_config.get("回合上限", 20),
		"当前回合": 1,
		"攻方队伍": attacker_teams.duplicate(),
		"守方队伍": defender_teams.duplicate(),
		"攻方当前队索引": 0,
		"守方当前队索引": 0,
		"大阵耐久": 耐久,
		"大阵等级": defender_array_level,
		"大阵已破": false,
		"攻方增益": [],
		"守方增益": [],
		"战斗日志": [],
		"战斗结果": BattleResult.ONGOING,
		"妖兽援军已触发": false,
	}

# ============ 队伍数据结构 ============
# 每队包含：队员列表（Disciple对象或快照）、队伍名称
static func create_team(team_name: String, members: Array) -> Dictionary:
	return {
		"队伍名称": team_name,
		"队员": members.duplicate(),
		"已全灭": false,
	}

# ============ 单场战斗推演（全自动）============
## 推演整场宗门战，返回战斗结果和战报
static func simulate_battle(battle_state: Dictionary) -> Dictionary:
	var max_rounds: int = int(battle_state.get("回合上限", 20))
	# 逐回合推演
	for round in range(1, max_rounds + 1):
		battle_state["当前回合"] = round
		# 检查是否已有队伍全灭，需要接续下一队
		_check_team_wipe(battle_state)
		# 检查战斗是否结束
		if _check_battle_end(battle_state):
			break
		# 执行单回合战斗
		_simulate_round(battle_state)
		# 处理增益持续回合
		_process_buffs(battle_state)
	# 如果超时未分胜负，按双方剩余总战力占比判定
	if battle_state["战斗结果"] == BattleResult.ONGOING:
		_resolve_timeout(battle_state)
	return battle_state

# ============ 单回合战斗推演 ============
static func _simulate_round(battle_state: Dictionary) -> void:
	var attacker_team: Dictionary = _get_current_team(battle_state, "攻方")
	var defender_team: Dictionary = _get_current_team(battle_state, "守方")
	if attacker_team == null or defender_team == null:
		return
	# 攻方攻击守方
	for attacker in attacker_team.get("队员", []):
		if _is_member_alive(attacker):
			var target = _select_target(defender_team)
			if target != null:
				_execute_attack(battle_state, attacker, target, "攻方")
	# 守方反击攻方
	for defender in defender_team.get("队员", []):
		if _is_member_alive(defender):
			var target = _select_target(attacker_team)
			if target != null:
				_execute_attack(battle_state, defender, target, "守方")
	# 记录回合日志
	battle_state["战斗日志"].append("第%d回合结束" % battle_state["当前回合"])

# ============ 宗门战专用减伤（S1-3 修复：战斗节奏与战力规模解耦）============
# 背景（实测）：原用 BattleUtil.calc_dmg_reduction(防)，其基准 BASE_DEFENSE_REFERENCE=200
#   是 BattleCalculator 的低数值口径。宗门战四维随战力线性放大，战力 1500+ 时
#   减伤率 → 97.8%，实测均回合 19.8（贴着 20 回合上限，结果全靠「超时按剩余战力」判定），
#   战力再高则永远打不完 —— 战斗失去意义。
# 修法：减伤基准改为随「攻方战力」缩放，使同战力互击约 6 次致死，节奏与战力规模无关。
#   推导：单次伤害 = 0.1P×(1-r)，血 = 0.45P（Disciple.算属性 中性权重口径）
#        次数 = 0.45P / (0.1P×(1-r)) = 4.5/(1-r)；取 6 次 → r=0.25 → 基准 = 3×防 = 1.35P
# 影响面：仅宗门战内部伤害结算，不触碰 BattleCalculator / BattleManager（72 条红线）。
const 减伤基准系数: float = 1.35
const 减伤基准下限: float = 200.0
const 减伤率上限: float = 0.75
static func _宗门战减伤率(防: int, 攻方战力: int) -> float:
	var 基准: float = max(减伤基准下限, float(攻方战力) * 减伤基准系数)
	if 基准 <= 0.0:
		return 0.0
	return clamp(float(防) / (float(防) + 基准), 0.0, 减伤率上限)

# ============ 执行单次攻击 ============
static func _execute_attack(battle_state: Dictionary, attacker: Dictionary, target: Dictionary, attacker_side: String) -> void:
	# 获取攻击者属性
	var atk_attr: Dictionary = attacker.get("战斗属性", {})
	var atk_power: int = int(atk_attr.get("战力", 100))
	var atk_crit: float = float(atk_attr.get("暴击率", 0.0))
	# 获取防御者属性
	var def_attr: Dictionary = target.get("战斗属性", {})
	var def_evasion: float = float(def_attr.get("闪避率", 0.0))
	var def_defense: int = int(def_attr.get("属性", {}).get("防", 0))
	# 闪避判定
	if randf() < def_evasion:
		battle_state["战斗日志"].append("%s闪避了%s的攻击" % [target.get("名称", "?"), attacker.get("名称", "?")])
		return
	# 暴击判定
	var is_crit: bool = randf() < atk_crit
	var crit_multiplier: float = 1.5 if is_crit else 1.0
	# 基础伤害计算
	var base_damage: int = int(atk_power * 0.1)  # 基础伤害为战力的10%
	# 防御减伤（S1-3：改用宗门战专用口径，详见 _宗门战减伤率 注释）
	var reduction_rate: float = _宗门战减伤率(def_defense, atk_power)
	# 大阵减伤（如果守方且大阵未破）
	if attacker_side == "攻方" and not battle_state.get("大阵已破", false) and battle_state.get("大阵耐久", 0) > 0:
		reduction_rate = min(0.75, reduction_rate + ARRAY_DAMAGE_REDUCTION)
		# 攻击大阵耐久
		battle_state["大阵耐久"] = max(0, battle_state["大阵耐久"] - int(base_damage * 0.5))
		if battle_state["大阵耐久"] <= 0:
			battle_state["大阵已破"] = true
			battle_state["战斗日志"].append("护山大阵被攻破！")
	# 大阵被破后守方额外受伤
	if attacker_side == "攻方" and battle_state.get("大阵已破", false):
		reduction_rate = max(0.0, reduction_rate - ARRAY_BROKEN_PENALTY)
	# 妖兽援军buff（如果是妖兽围剿战且血量低于50%）
	if battle_state.get("战斗类型", "") == "妖兽围剿战" and not battle_state.get("妖兽援军已触发", false):
		var defender_team: Dictionary = _get_current_team(battle_state, "守方")
		if defender_team != null:
			var total_hp: int = 0
			var current_hp: int = 0
			for member in defender_team.get("队员", []):
				total_hp += int(member.get("最大生命", 100))
				current_hp += int(member.get("当前生命", 100))
			if total_hp > 0 and float(current_hp) / float(total_hp) < 0.5:
				battle_state["妖兽援军已触发"] = true
				battle_state["守方增益"].append(BEAST_BUFF.duplicate())
				battle_state["战斗日志"].append("妖兽援军触发！守方获得3回合属性加成")
	# 应用增益
	var side_buffs: Array = battle_state.get(attacker_side + "增益", [])
	var buff_atk_multiplier: float = 1.0
	for buff in side_buffs:
		buff_atk_multiplier += buff.get("攻击加成", 0.0)
	# 最终伤害
	var final_damage: int = int(base_damage * crit_multiplier * buff_atk_multiplier * (1.0 - reduction_rate))
	final_damage = max(1, final_damage)
	# 扣血
	target["当前生命"] = max(0, int(target.get("当前生命", 100)) - final_damage)
	# 记录日志
	var crit_text: String = "（暴击！）" if is_crit else ""
	battle_state["战斗日志"].append("%s对%s造成%d点伤害%s" % [attacker.get("名称", "?"), target.get("名称", "?"), final_damage, crit_text])
	# 检查是否死亡
	if target["当前生命"] <= 0:
		battle_state["战斗日志"].append("%s阵亡！" % target.get("名称", "?"))

# ============ 选择攻击目标 ============
static func _select_target(team: Dictionary) -> Variant:
	var alive_members: Array = []
	for member in team.get("队员", []):
		if _is_member_alive(member):
			alive_members.append(member)
	if alive_members.is_empty():
		return null
	# 优先攻击前排，然后中排，最后后排（简化：随机选择存活成员）
	return alive_members[randi() % alive_members.size()]

# ============ 检查成员是否存活 ============
static func _is_member_alive(member: Dictionary) -> bool:
	return int(member.get("当前生命", 0)) > 0

# ============ 获取当前队伍 ============
static func _get_current_team(battle_state: Dictionary, side: String) -> Variant:
	var team_index: int = int(battle_state.get(side + "当前队索引", 0))
	var teams: Array = battle_state.get(side + "队伍", [])
	if team_index < teams.size():
		return teams[team_index]
	return null

# ============ 检查队伍全灭并接续 ============
static func _check_team_wipe(battle_state: Dictionary) -> void:
	for side in ["攻方", "守方"]:
		var current_team: Dictionary = _get_current_team(battle_state, side)
		if current_team == null:
			continue
		var all_dead: bool = true
		for member in current_team.get("队员", []):
			if _is_member_alive(member):
				all_dead = false
				break
		if all_dead:
			current_team["已全灭"] = true
			battle_state[side + "当前队索引"] = int(battle_state[side + "当前队索引"]) + 1
			battle_state["战斗日志"].append("%s第%d队全灭，接续下一队" % [side, int(battle_state[side + "当前队索引"])])

# ============ 检查战斗是否结束 ============
static func _check_battle_end(battle_state: Dictionary) -> bool:
	var attacker_team: Dictionary = _get_current_team(battle_state, "攻方")
	var defender_team: Dictionary = _get_current_team(battle_state, "守方")
	# 攻方所有队伍全灭
	if attacker_team == null:
		battle_state["战斗结果"] = BattleResult.DEFENDER_WIN
		battle_state["战斗日志"].append("攻方所有队伍全灭，守方胜利！")
		return true
	# 守方所有队伍全灭
	if defender_team == null:
		battle_state["战斗结果"] = BattleResult.ATTACKER_WIN
		battle_state["战斗日志"].append("守方所有队伍全灭，攻方胜利！")
		return true
	return false

# ============ 超时结算（按双方剩余总战力占比）============
static func _resolve_timeout(battle_state: Dictionary) -> void:
	var attacker_power: int = _calculate_remaining_power(battle_state, "攻方")
	var defender_power: int = _calculate_remaining_power(battle_state, "守方")
	var total_power: int = attacker_power + defender_power
	if total_power <= 0:
		battle_state["战斗结果"] = BattleResult.DRAW
		battle_state["战斗日志"].append("超时，双方均无战力，平局！")
		return
	var attacker_ratio: float = float(attacker_power) / float(total_power)
	if attacker_ratio > 0.6:
		battle_state["战斗结果"] = BattleResult.ATTACKER_WIN
		battle_state["战斗日志"].append("超时，攻方剩余战力占比%.0f%%，攻方胜利！" % (attacker_ratio * 100))
	elif attacker_ratio < 0.4:
		battle_state["战斗结果"] = BattleResult.DEFENDER_WIN
		battle_state["战斗日志"].append("超时，守方剩余战力占比%.0f%%，守方胜利！" % ((1.0 - attacker_ratio) * 100))
	else:
		battle_state["战斗结果"] = BattleResult.DRAW
		battle_state["战斗日志"].append("超时，双方战力接近（攻方%.0f%%），平局！" % (attacker_ratio * 100))

# ============ 计算剩余总战力 ============
static func _calculate_remaining_power(battle_state: Dictionary, side: String) -> int:
	var total_power: int = 0
	var teams: Array = battle_state.get(side + "队伍", [])
	for team in teams:
		for member in team.get("队员", []):
			if _is_member_alive(member):
				var hp_ratio: float = float(member.get("当前生命", 0)) / float(member.get("最大生命", 100))
				total_power += int(member.get("战斗属性", {}).get("战力", 0) * hp_ratio)
	return total_power

# ============ 处理增益持续回合 ============
static func _process_buffs(battle_state: Dictionary) -> void:
	for side in ["攻方", "守方"]:
		var buffs: Array = battle_state.get(side + "增益", [])
		var remaining_buffs: Array = []
		for buff in buffs:
			var duration: int = int(buff.get("持续回合", 1))
			duration -= 1
			if duration > 0:
				buff["持续回合"] = duration
				remaining_buffs.append(buff)
		battle_state[side + "增益"] = remaining_buffs

# ============ 生成战报摘要 ============
static func generate_battle_report(battle_state: Dictionary) -> Dictionary:
	var result_text: String = ""
	match int(battle_state.get("战斗结果", BattleResult.ONGOING)):
		BattleResult.ATTACKER_WIN:
			result_text = "攻方胜利"
		BattleResult.DEFENDER_WIN:
			result_text = "守方胜利"
		BattleResult.DRAW:
			result_text = "平局"
		_:
			result_text = "进行中"
	return {
		"战斗类型": battle_state.get("战斗类型", ""),
		"战斗结果": result_text,
		"总回合数": battle_state.get("当前回合", 0),
		"大阵是否被破": battle_state.get("大阵已破", false),
		"攻方剩余队伍数": _count_remaining_teams(battle_state, "攻方"),
		"守方剩余队伍数": _count_remaining_teams(battle_state, "守方"),
		"攻方剩余战力": _calculate_remaining_power(battle_state, "攻方"),
		"守方剩余战力": _calculate_remaining_power(battle_state, "守方"),
		"战斗日志": battle_state.get("战斗日志", []),
	}

# ============ 统计剩余队伍数 ============
static func _count_remaining_teams(battle_state: Dictionary, side: String) -> int:
	var count: int = 0
	var teams: Array = battle_state.get(side + "队伍", [])
	for team in teams:
		if not team.get("已全灭", false):
			count += 1
	return count

# ============ 从Disciple对象创建战斗成员快照 ============
static func create_member_from_disciple(disciple: Node) -> Dictionary:
	if disciple == null or not disciple.has_method("get_final_combat_attr"):
		return {}
	var combat_attr: Dictionary = disciple.get_final_combat_attr()
	var max_hp: int = int(combat_attr.get("属性", {}).get("血", 100))
	return {
		"名称": disciple.姓名 if "姓名" in disciple else "无名",
		"弟子ID": disciple.弟子ID if "弟子ID" in disciple else "",
		"境界": disciple.境界 if "境界" in disciple else "练气",
		"最大生命": max_hp,
		"当前生命": max_hp,
		"战斗属性": combat_attr,
	}

# ============ 从弟子列表创建队伍 ============
static func create_team_from_disciple_list(team_name: String, disciple_list: Array) -> Dictionary:
	var members: Array = []
	for disciple in disciple_list:
		if disciple != null:
			members.append(create_member_from_disciple(disciple))
	return create_team(team_name, members)

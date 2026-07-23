# BattleManager.gd —— 战斗编排层（ADR-003，P0 范围）
#
# 定位：在 BattleCalculator（纯结算）之上的「编排」，负责状态机、行动队列、车轮战、
#       结构化日志打印。仍不持有 Disciple/Item/Beast 实例——只接收 CombatantData 快照数组
#       （由 disciple.get_final_combat_attr() / game_state 关卡 / 奇遇组装后传入）。
# 状态机：战前准备 → 回合执行 → 结算收尾（见 状态 枚举）。
# 车轮战：按速排序行动；一方单位战败→该方下一位以满血上场；胜者保留当前气血（气血继承）。
# 强制结构化战斗日志（每回合：行动单位/伤害值/是否暴击/是否克制/双方剩余血量）→ 控制台打印。
extends RefCounted
class_name BattleManager

const BattleCalculator = preload("res://BattleCalculator.gd")

# 状态机枚举
enum 状态 { 战前准备, 回合执行, 结算收尾 }

# ============ 1v1 单场 ============
# 攻方 / 守方：各一个 CombatantData 快照。
# mode：结算模式（"full" 完整 / "quick" 速算）。
# 打印日志：是否在控制台打印结构化战斗日志（D7 调试工具）。
static func 发起1v1(攻方: Dictionary, 守方: Dictionary, mode: String = "full", 打印日志: bool = true) -> Dictionary:
	var 战报: Dictionary = BattleCalculator.结算_1v1(攻方, 守方, mode)
	if 打印日志:
		_注入灵兽日志(战报["battle_log"], 战报, 攻方, 守方)
		打印战斗(战报, "1v1")
	return 战报

# ============ 3v3 车轮战 ============
# 攻方列表 / 守方列表：各 3 个 CombatantData 快照（按上场顺序）。
# 车轮规则：
#   · 当前双方「未阵亡首位」对决；
#   · 一方单位战败 → 该方下一位以满血上场；
#   · 胜者保留当前气血（气血继承），带入下一场。
# 任一方全员阵亡 → 另一方胜。返回统一 BattleResult（合并日志）。
static func 发起3v3(攻方列表: Array, 守方列表: Array, mode: String = "full", 打印日志: bool = true) -> Dictionary:
	var 攻: Array = _实例化(攻方列表)
	var 守: Array = _实例化(守方列表)
	var a_idx := 0
	var d_idx := 0
	var 总日志 := []
	var 总回合 := 0
	var 当前状态: 状态 = 状态.回合执行

	while a_idx < 攻.size() and d_idx < 守.size():
		var 攻单位: Dictionary = 攻[a_idx]
		var 守单位: Dictionary = 守[d_idx]
		var 局: Dictionary = BattleCalculator.结算_1v1(攻单位, 守单位, mode)
		总回合 += 局["round_count"]
		for e in 局["battle_log"]:
			总日志.append(e)
		# S1 战斗生效·优先级2：灵兽行动日志（主宠高频/副宠低频关键），编排层注入，不碰核心计算
		_注入灵兽日志(总日志, 局, 攻单位, 守单位)
		# 气血继承：把本局终态写回当前单位（胜者保留剩余气血，败者记为 0）
		if not 局["battle_log"].is_empty():
			var 末: Dictionary = 局["battle_log"][-1]
			攻[a_idx]["属性"]["血"] = 末["attacker_hp"]
			守[d_idx]["属性"]["血"] = 末["defender_hp"]
		# 战败方下一位上场
		if 局["is_win"]:
			d_idx += 1      # 守方当前单位阵亡 → 守方下一位（满血）上场
		else:
			a_idx += 1      # 攻方当前单位阵亡 → 攻方下一位（满血）上场

	当前状态 = 状态.结算收尾
	var 攻胜: bool = a_idx < 攻.size()
	var 剩余 := 0
	if 攻胜:
		for i in range(a_idx, 攻.size()):
			剩余 += max(0, int(攻[i]["属性"].get("血", 0)))
	else:
		for i in range(d_idx, 守.size()):
			剩余 += max(0, int(守[i]["属性"].get("血", 0)))

	var 结果: Dictionary = {
		"is_win": 攻胜,
		"round_count": 总回合,
		"remaining_hp": 剩余,
		"drop_reward": [],
		"battle_log": 总日志,
	}
	if 打印日志:
		打印战斗(结果, "3v3车轮")
	return 结果

# 深拷贝快照数组（避免改动外部传入的字典；车轮下一位以满血上场由副本保证）
static func _实例化(列表: Array) -> Array:
	var out := []
	for u in 列表:
		out.append(u.duplicate(true))
	return out

# ============ 结构化战斗日志打印（D7）============
# S1 战斗生效·优先级2：灵兽行动日志注入（编排层，不改动 结算_1v1 核心计算）
# 规则：主宠每局一条（高频可见）；副宠仅本局出现暴击时一条（低频关键，避免刷屏）。
# 复用现有日志键（round/actor/target/damage/is_crit/is_restrain/attacker_hp/defender_hp），格式与现有日志统一。
static func _注入灵兽日志(总日志: Array, 局: Dictionary, 攻单位: Dictionary, 守单位: Dictionary):
	if (局["battle_log"] as Array).is_empty():
		return
	var 日志: Array = 局["battle_log"]
	var 首: Dictionary = 日志[0]
	var 局有暴击: bool = false
	for e in 日志:
		if e.get("is_crit", false):
			局有暴击 = true
			break
	_注入单侧灵兽(总日志, 攻单位, 守单位, 首, true, 局有暴击)
	_注入单侧灵兽(总日志, 守单位, 攻单位, 首, false, 局有暴击)

static func _注入单侧灵兽(总日志: Array, 本方: Dictionary, 对方: Dictionary, 首: Dictionary, 本方是攻: bool, 局有暴击: bool):
	for p in 本方.get("灵兽", []):
		var 主副: String = p.get("主副", "")
		if 主副 == "副" and not 局有暴击:
			continue   # 副宠仅关键触发（本局暴击）低频可见
		var 本方_hp: int = 首.get("attacker_hp", 0) if 本方是攻 else 首.get("defender_hp", 0)
		var 对方_hp: int = 首.get("defender_hp", 0) if 本方是攻 else 首.get("attacker_hp", 0)
		总日志.append({
			"round": 首.get("round", 0),
			"actor": "%s·%s[%s]" % [本方.get("名称", ""), p.get("名", ""), p.get("类型", "")],
			"target": 对方.get("名称", ""),
			"damage": 0,
			"is_crit": false,
			"is_restrain": false,
			"attacker_hp": 本方_hp,
			"defender_hp": 对方_hp,
			"pet_action": true,
			"主副": 主副,
		})

static func 打印战斗(战报: Dictionary, 标题: String):
	print("═══ 战斗日志 %s ═══" % 标题)
	print("结果：%s ｜ 回合：%d ｜ 胜方剩余气血：%d ｜ 日志条数：%d" % \
		["攻方胜" if 战报["is_win"] else "守方胜", 战报["round_count"],
		 int(战报["remaining_hp"]), (战报["battle_log"] as Array).size()])
	for e in 战报["battle_log"]:
		var 标记 := ""
		if e.get("is_crit", false):
			标记 += "【暴击】"
		if e.get("is_restrain", false):
			标记 += "【克制】"
		print("  R%d  %s → %s  伤害%d%s  (攻方血%d / 守方血%d)" % \
			[e.get("round", 0), e.get("actor", ""), e.get("target", ""), e.get("damage", 0), 标记,
			 int(e.get("attacker_hp", 0)), int(e.get("defender_hp", 0))])

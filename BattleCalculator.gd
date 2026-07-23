# BattleCalculator.gd —— 纯逻辑战斗结算器（ADR-003 D1 / D4，P0 范围）
#
# 设计边界（ADR-003）：
#  · 无 UI、无 Game 依赖、不 preload game_state / disciple / item / beast。
#  · 只消费「战斗快照」CombatantData（由 disciple.get_final_combat_attr() 或
#    关卡/奇遇组装的 Dictionary），返回统一 BattleResult。
#  · 全部为纯函数 + 单场结算，可在无引擎下以 Python 断言验证（TEST_STRATEGY LOGIC 层）。
#  · 双模式：完整回合制结算("full") + 离线/跳过快速结算("quick")，两者胜负偏差≤10%。
#
# 统一 BattleResult = { is_win, round_count, remaining_hp, drop_reward, battle_log }
#   · is_win        : 攻方（玩家侧）是否获胜
#   · round_count   : 总回合数（含超时）
#   · remaining_hp  : 胜方剩余总气血（攻方胜=攻方剩余；守方胜=守方剩余）
#   · drop_reward   : Array，P0 占位（掉落系统属 S1，暂不发放）
#   · battle_log    : Array[Dictionary]，每回合结构化日志（见 _log_entry）
class_name BattleCalculator
extends RefCounted

# ============ 常量（§9.6 / D4，设计基线，数值待 design 校准标注）============
# 五行克制链（§9.6.1）：金→木→土→水→火→金
const 五行序 := ["金", "木", "土", "水", "火"]
# 职业克制闭环（D2 拍板，显式映射，不解析文案）：道修克法修、体修克道修、法修克体修
const 职业克制 := {
	"道修": "法修",
	"体修": "道修",
	"法修": "体修",
}

# 五行纯度档 → 克制/被克 乘率（§9.6.2）
#  单灵根: 克制1.25 / 被克0.82（=边界 max/min）
#  双灵根: 1.0 / 1.0 ；三灵根: 0.75 / 0.67 ；四+: 0.5 / 0.33
const 纯度克制 := {"单": 1.25, "双": 1.0, "三": 0.75, "四+": 0.5}
const 纯度被克 := {"单": 0.82, "双": 1.0, "三": 0.67, "四+": 0.33}
# 五行乘率边界（§9.6.3）
const 五行上限 := 1.25
const 五行下限 := 0.82

# 职业克制乘率（D2 闭环）：克制 ×1.20 / 被克 ×0.85 / 中性 ×1.0
const 职业克制乘率 := 1.20
const 职业被克乘率 := 0.85

# 防御减伤：减伤率 = 防 / (防 + 基准)，封顶（P0 占位常数，待 design 校准）
const 防御减伤基准 := 200.0
const 防御减伤上限 := 0.75

# 暴击 / 闪避 封顶（AC7②）
const 暴击率上限 := 0.70
const 闪避率上限 := 0.40
# 暴击系数（P0 占位，待 design 校准）
const 暴击系数 := 1.5

# 浮动伤害区间（AC7③）：×[0.9, 1.1]
const 浮动下限 := 0.9
const 浮动上限 := 1.1

# 伤害下限（高防兜底，AC7①）：最低造成 1 点
const 伤害下限 := 1

# 回合上限（AC1）：满 20 回合超时判守方胜
const 回合上限 := 20

# ============ 纯函数：五行乘率（AC2 / D3）============
# atk_attr / def_attr 取自主灵根（金木水火土）。
# root_purity：攻击者纯度档（"单"/"双"/"三"/"四+"）。
# is_true_damage=true → 真实/固定伤害，恒 1.0。
# 无主灵根 / 非五行（天灵根、变异） / 同属 → 1.0（中性）。
static func wuxing_multiplier(atk_attr: String, def_attr: String, root_purity: String, is_true_damage: bool = false) -> float:
	if is_true_damage:
		return 1.0
	if atk_attr == "" or def_attr == "" or atk_attr == def_attr:
		return 1.0
	if atk_attr not in 五行序 or def_attr not in 五行序:
		return 1.0   # 天灵根/变异等非五行主灵根 → 无五行克制关系，中性
	# 克制判定：五行序中 atk 的下一个元素 = 被其克制者
	var 克制目标: String = 五行序[(五行序.find(atk_attr) + 1) % 五行序.size()]
	var mult := 1.0
	if 克制目标 == def_attr:
		mult = 纯度克制.get(root_purity, 1.0)
	elif 五行序[(五行序.find(def_attr) + 1) % 五行序.size()] == atk_attr:
		mult = 纯度被克.get(root_purity, 1.0)
	# 纯度表已含 §9.6.2 全部档位乘率；单灵根极端值=边界 max1.25/min0.82（§9.6.3），
	# 多灵根档（三/四+）可低至 0.33，故不做全局下限夹取以免破坏纯度表。
	return mult

# ============ 纯函数：职业克制乘率（AC3 / D2）============
static func profession_multiplier(atk_prof: String, def_prof: String) -> float:
	if atk_prof == "" or def_prof == "":
		return 1.0
	if 职业克制.get(atk_prof, "") == def_prof:
		return 职业克制乘率
	if 职业克制.get(def_prof, "") == atk_prof:
		return 职业被克乘率
	return 1.0

# ============ 比率封顶（AC7② 边界）============
static func 封顶暴击率(率: float) -> float:
	return clamp(率, 0.0, 暴击率上限)

static func 封顶闪避率(率: float) -> float:
	return clamp(率, 0.0, 闪避率上限)

# ============ 纯函数：单段伤害（ADR-003 D4）============
# 公式：攻击 × 职业倍率 ×(1+通用增益)×(1+道心) × wuxing ×(1-防御减伤率) × 暴击系数 × 浮动
# 参数显式传入，便于单测与「完整/速算」双模式共用：
#   float_factor : 浮动系数（完整∈[0.9,1.1]，速算=1.0）
#   crit_mult    : 暴击系数（完整随机取 暴击系数/1.0，速算取期望值 1+暴击率*(暴击系数-1)）
#   dodge_mult   : 闪避系数（完整随机取 0/1，速算取期望值 1-闪避率）
#   is_true      : 真实/固定伤害（wuxing 恒 1.0）
# 边界（AC7①）：攻击=0 不出负伤（返回 0）；防御极高时伤害下限夹 1。
static func calc_hit_damage(atk: Dictionary, def: Dictionary, float_factor: float, crit_mult: float, dodge_mult: float, is_true: bool = false) -> int:
	if dodge_mult <= 0.0:
		return 0
	var 攻击: float = float(atk.get("属性", {}).get("攻", 0))
	if 攻击 <= 0:
		return 0   # 攻击=0 不出负伤
	var 防御: float = float(def.get("属性", {}).get("防", 0))
	var 减伤率: float = clamp(防御 / (防御 + 防御减伤基准), 0.0, 防御减伤上限)
	var wux: float = wuxing_multiplier(
		atk.get("灵根", {}).get("主", ""),
		def.get("灵根", {}).get("主", ""),
		atk.get("灵根", {}).get("纯度", "单"),
		is_true
	)
	var 职业倍率: float = profession_multiplier(atk.get("职业", ""), def.get("职业", ""))
	var 通用增益: float = 1.0 + float(atk.get("通用增益", 0.0))
	var 道心增益: float = 1.0 + float(atk.get("道心增益", 0.0))
	var 防御系数: float = 1.0 - 减伤率
	var dmg: float = 攻击 * 职业倍率 * 通用增益 * 道心增益 * wux * 防御系数 * crit_mult
	dmg *= float_factor
	return int(max(伤害下限, round(dmg)))

# ============ 单场 1v1 结算（双模式）============
# atk / def 各传入单个单位快照（Dictionary）。
# mode = "full"（完整回合制，含随机浮动/暴击/闪避）或 "quick"（速算，取期望值）。
# 返回统一 BattleResult。
static func 结算_1v1(atk: Dictionary, def: Dictionary, mode: String = "full") -> Dictionary:
	var a_hp: int = int(atk.get("属性", {}).get("血", 1))
	var d_hp: int = int(def.get("属性", {}).get("血", 1))
	var a_spd: float = float(atk.get("属性", {}).get("速", 0))
	var d_spd: float = float(def.get("属性", {}).get("速", 0))
	var a_crit: float = 封顶暴击率(float(atk.get("暴击率", 0.0)))
	var d_crit: float = 封顶暴击率(float(def.get("暴击率", 0.0)))
	var a_dodge: float = 封顶闪避率(float(atk.get("闪避率", 0.0)))
	var d_dodge: float = 封顶闪避率(float(def.get("闪避率", 0.0)))
	var a_name: String = atk.get("名称", "攻方")
	var d_name: String = def.get("名称", "守方")

	var 回合 := 0
	var 日志 := []
	var 攻先手: bool = a_spd >= d_spd

	while true:
		回合 += 1
		if 回合 > 回合上限:
			break   # 超时 → 守方胜
		# 出手顺序：速高者先手（同速攻方先手）
		var 出手序: Array = []
		if 攻先手:
			出手序 = [{"actor": atk, "target": def}, {"actor": def, "target": atk}]
		else:
			出手序 = [{"actor": def, "target": atk}, {"actor": atk, "target": def}]

		for 步 in 出手序:
			if a_hp <= 0 or d_hp <= 0:
				break
			var actor: Dictionary = 步["actor"]
			var target: Dictionary = 步["target"]
			var actor_crit: float = a_crit if actor == atk else d_crit
			var target_dodge: float = d_dodge if target == def else a_dodge
			var actor_label: String = a_name if actor == atk else d_name
			var target_label: String = d_name if target == def else a_name
			# 派生本击参数（完整随机 / 速算期望值）
			var float_factor: float = 0.0
			var crit_mult: float = 0.0
			var dodge_mult: float = 0.0
			if mode == "quick":
				float_factor = 1.0
				crit_mult = 1.0 + actor_crit * (暴击系数 - 1.0)
				dodge_mult = 1.0 - target_dodge
			else:
				float_factor = randf_range(浮动下限, 浮动上限)
				crit_mult = 暴击系数 if randf() < actor_crit else 1.0
				dodge_mult = 0.0 if randf() < target_dodge else 1.0
			var 伤害: int = calc_hit_damage(actor, target, float_factor, crit_mult, dodge_mult, false)
			if target == def:
				d_hp -= 伤害
			else:
				a_hp -= 伤害
			# D7 强制结构化日志：每回合双方出手均记录（行动单位/伤害/暴击/克制/双方剩余血量）
			日志.append(_log_entry(回合, actor_label, target_label, 伤害, crit_mult > 1.0,
				profession_multiplier(actor.get("职业", ""), target.get("职业", "")) > 1.0,
				a_hp, d_hp))
		if a_hp <= 0 or d_hp <= 0:
			break

	# 胜负判定：守方先死→攻方胜；攻方先死或超时→守方胜
	var is_win := false
	if d_hp <= 0 and a_hp > 0:
		is_win = true
	elif a_hp <= 0 and d_hp > 0:
		is_win = false
	else:
		is_win = false   # 双亡 / 超时 → 守方胜
	var remaining: int = a_hp if is_win else d_hp
	return {
		"is_win": is_win,
		"round_count": 回合,
		"remaining_hp": remaining,
		"drop_reward": [],
		"battle_log": 日志,
	}

# ============ 车轮战 3v3 结算（双模式，纯函数）============
# atk_list / def_list：攻方/守方单位快照列表（各为 Dictionary 数组；按上场顺序）。
# 车轮规则（与 BattleManager.发起3v3 语义对齐）：双方各取当前「未阵亡首位」对决；
#   败者下位满血上场，胜者保留当前气血（气血继承）带入下一场，直到一方全灭。
# 内部复用 结算_1v1 做单场交换（同约束：无 UI / 无 Game / 不 preload 业务脚本）。
# 返回统一 BattleResult；is_win = 攻方是否全灭守方列表。
# mode："full"（完整回合制随机）/ "quick"（期望值速算，与 结算_1v1 一致）；两者胜负偏差≤10%（AC7④）。
static func 结算_3v3(atk_list: Array, def_list: Array, mode: String = "quick") -> Dictionary:
	var 攻 := []
	for u in atk_list:
		攻.append(u.duplicate(true))   # 深拷贝，避免改动外部传入字典（车轮下位满血由副本保证）
	var 守 := []
	for u in def_list:
		守.append(u.duplicate(true))
	var a_idx := 0
	var d_idx := 0
	var 总日志 := []
	var 总回合 := 0

	while a_idx < 攻.size() and d_idx < 守.size():
		var 攻单位: Dictionary = 攻[a_idx]
		var 守单位: Dictionary = 守[d_idx]
		var 局: Dictionary = 结算_1v1(攻单位, 守单位, mode)
		总回合 += 局["round_count"]
		for e in 局["battle_log"]:
			总日志.append(e)
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

	var 攻胜: bool = a_idx < 攻.size()
	var 剩余 := 0
	if 攻胜:
		for i in range(a_idx, 攻.size()):
			剩余 += max(0, int(攻[i]["属性"].get("血", 0)))
	else:
		for i in range(d_idx, 守.size()):
			剩余 += max(0, int(守[i]["属性"].get("血", 0)))

	return {
		"is_win": 攻胜,
		"round_count": 总回合,
		"remaining_hp": 剩余,
		"drop_reward": [],
		"battle_log": 总日志,
	}

# 结构化战斗日志单条（D7：行动单位/伤害值/是否暴击/是否克制/双方剩余血量）
# S0 扩展：log_type/tags/extra + S1预埋 ref_type/ref_id/ref_name；
# tags 自动映射 暴击/克制/闪避(伤害0)/击败(守方血<=0)，渲染层据此做视觉分层。存量战斗逻辑不变。
static func _log_entry(回合: int, actor: String, target: String, 伤害: int, 暴击: bool, 克制: bool, 攻方血: int, 守方血: int) -> Dictionary:
	var 标签: Array = []
	if 暴击:
		标签.append("暴击")
	if 克制:
		标签.append("克制")
	if 伤害 == 0:
		标签.append("闪避")
	if 守方血 <= 0:
		标签.append("击败")
	return {
		"round": 回合,
		"actor": actor,
		"target": target,
		"damage": 伤害,
		"is_crit": 暴击,
		"is_restrain": 克制,
		"attacker_hp": 攻方血,
		"defender_hp": 守方血,
		"log_type": "damage",
		"tags": 标签,
		"extra": "",
		"ref_type": "",
		"ref_id": "",
		"ref_name": "",
	}

# ============ 统一战力度量（玩家与怪物同公式；推荐战力/界面战力共用口径）============
# 把攻防血速 + 暴击/闪避 折算为单一战力值。玩家单位(get_final_combat_attr)与
# 怪物单位(_monster_to_unit) 格式一致(含 属性dict/暴击率/闪避率)，可直接通吃。
# 权重为设计基线([DESIGN_BASELINE] 待实测校准)：攻1.0/防0.5/血0.4/速0.3/暴击60/闪避40
static func 战力度量(unit: Dictionary) -> int:
	var a: Dictionary = unit.get("属性", {})
	var 攻: float = float(a.get("攻", 0))
	var 防: float = float(a.get("防", 0))
	var 血: float = float(a.get("血", 0))
	var 速: float = float(a.get("速", 0))
	var 暴击: float = float(unit.get("暴击率", 0.0))
	var 闪避: float = float(unit.get("闪避率", 0.0))
	return int(攻 * 1.0 + 防 * 0.5 + 血 * 0.4 + 速 * 0.3 + 暴击 * 60.0 + 闪避 * 40.0)
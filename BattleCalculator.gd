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

# 功法流派克制环（S2：独立于道途克制的第二克制维度；默认中性 1.0 不破坏现役数学）
# 四象环：攻伐→守御→奇诡→化生→攻伐（由弟子主修功法 skill_type 驱动；空→"无"→中性）
const 功法克制环 := {
	"攻伐": "守御",
	"守御": "奇诡",
	"奇诡": "化生",
	"化生": "攻伐",
}
const 功法克制乘率 := 1.18
const 功法被克乘率 := 0.86

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

# 灵力（mp）资源（§9.7.1 / D4：回复=10 已定；初始/上限 [PLACEHOLDER] 待实测）
const 灵力回复 := 10.0      # §9.7.1 每回合回复 10 点基础灵力（D4 已定）
const 灵力初始 := 30.0      # [PLACEHOLDER] D4：mp 初始值，待战斗基线实测校准
const 灵力上限 := 60.0      # [PLACEHOLDER] D4：mp 上限，须 ≥ 最大 mp_cost(40)
const 常驻回合 := 999       # 被动天赋常驻增益持续回合（整场战斗不消散；<回合上限故不触发消散）

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

# ============ 纯函数：功法流派克制乘率（S2，独立于道途克制的第二维度）============
# 攻伐/守御/奇诡/化生 四象环；空流派（"无"）或同流派 → 中性 1.0。
# 现役快照无「功法」字段 → 恒 1.0 → 原版/空技能增强数学不变 → 72 断言红线不破。
static func method_multiplier(atk_m: String, def_m: String) -> float:
	if atk_m == "" or def_m == "":
		return 1.0
	if 功法克制环.get(atk_m, "") == def_m:
		return 功法克制乘率
	if 功法克制环.get(def_m, "") == atk_m:
		return 功法被克乘率
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
static func calc_hit_damage(atk: Dictionary, def: Dictionary, float_factor: float, crit_mult: float, dodge_mult: float, is_true: bool = false, 穿透率: float = 0.0) -> int:
	if dodge_mult <= 0.0:
		return 0
	var 攻击: float = float(atk.get("属性", {}).get("攻", 0))
	if 攻击 <= 0:
		return 0   # 攻击=0 不出负伤
	var 防御: float = float(def.get("属性", {}).get("防", 0))
	var 减伤率: float = clamp(防御 / (防御 + 防御减伤基准), 0.0, 防御减伤上限)
	# S2 套装·穿透：按攻方穿透率无视部分减伤（默认 0.0 → 原数学不变，72 断言不破）
	减伤率 = clamp(减伤率 * (1.0 - clamp(穿透率, 0.0, 1.0)), 0.0, 防御减伤上限)
	# S2 套装·额外减伤：守方自身减伤率无视部分减伤（默认 0.0 → 原数学不变）
	var 守方减伤: float = clamp(float(def.get("减伤率", 0.0)), 0.0, 0.9)
	减伤率 = clamp(减伤率 * (1.0 - 守方减伤), 0.0, 防御减伤上限)
	var wux: float = wuxing_multiplier(
		atk.get("灵根", {}).get("主", ""),
		def.get("灵根", {}).get("主", ""),
		atk.get("灵根", {}).get("纯度", "单"),
		is_true
	)
	var 职业倍率: float = profession_multiplier(atk.get("职业", ""), def.get("职业", ""))
	var 功法倍率: float = method_multiplier(atk.get("功法", ""), def.get("功法", ""))
	var 通用增益: float = 1.0 + float(atk.get("通用增益", 0.0))
	var 道心增益: float = 1.0 + float(atk.get("道心增益", 0.0))
	var 防御系数: float = 1.0 - 减伤率
	var dmg: float = 攻击 * 职业倍率 * 功法倍率 * 通用增益 * 道心增益 * wux * 防御系数 * crit_mult
	dmg *= float_factor
	return int(max(伤害下限, round(dmg)))

# ============ 单场 1v1 结算（双模式）============
# atk / def 各传入单个单位快照（Dictionary）。
# mode = "full"（完整回合制，含随机浮动/暴击/闪避）或 "quick"（速算，取期望值）。
# 返回统一 BattleResult。
# S1 批3：快照无 技能（现役默认）时走 _结算_1v1_原版（与批3前逐字节一致，72 断言硬门槛）；
#         含 技能 时走 _结算_1v1_增强（单位工作态 + Buff 生命周期 + 技能释放/冷却）。
static func 结算_1v1(atk: Dictionary, def: Dictionary, mode: String = "full") -> Dictionary:
	if not _带技能(atk) and not _带技能(def):
		return _结算_1v1_原版(atk, def, mode)
	return _结算_1v1_增强(atk, def, mode)

static func _带技能(u: Dictionary) -> bool:
	return u.get("技能", []).size() > 0

# ============ S1 批3：单位工作态 / Buff / 技能 辅助（纯函数，无 Game 依赖）============
static func _build_unit_state(snap: Dictionary) -> Dictionary:
	var base: Dictionary = {}
	var cur: Dictionary = {}
	var src: Dictionary = snap.get("属性", {})
	for k in ["攻", "防", "血", "速", "灵力"]:
		var v: float = float(src.get(k, 0))
		base[k] = v
		cur[k] = v
	var st: Dictionary = {
		"snapshot": snap,
		"base属性": base,
		"cur属性": cur,
		"active_buffs": [],
		"cooldowns": {},
		"mp": 灵力初始,
		"mp_max": 灵力上限,
		"base闪避": 封顶闪避率(float(snap.get("闪避率", 0.0))),
		"base暴击": 封顶暴击率(float(snap.get("暴击率", 0.0))),
		"cur闪避": 封顶闪避率(float(snap.get("闪避率", 0.0))),
		"cur暴击": 封顶暴击率(float(snap.get("暴击率", 0.0))),
	}
	# 进场被动天赋 → 常驻自增益（§3.2.5；本批 技能恒为[]故不触发，批4 接管）
	for sk in snap.get("技能", []):
		if typeof(sk) != TYPE_DICTIONARY:
			continue
		if sk.get("skill_type", "") == "被动天赋":
			var pb: Dictionary = _被动_to_buff(sk)
			if not pb.is_empty():
				_apply_buff(st, pb, "passive")
	# S2 增强·3v3 全队光环：快照携带 初始buff（常驻）在进场即生效，覆盖整场（bf_aura 全队光环等）
	for bid in snap.get("初始buff", []):
		if typeof(bid) != TYPE_STRING:
			continue
		var tpl: Dictionary = _buff模板(bid)
		if not tpl.is_empty():
			_apply_buff(st, tpl, "aura")
			st["active_buffs"][st["active_buffs"].size() - 1]["常驻"] = true
			# S2 增强·全属性类常驻 buff（bf_aura）的最大生命加成：血属损耗池，不进 _recompute_attr
			# 的每回合重置逻辑，故在进场一次性作用于 base/cur 血，避免「全属性+15%」漏血、也避免每回合
			# 重算把已损耗的血拉回满值。攻防速仍由 _recompute_attr 基于 base 重算（base 未动，不重复加成）。
			if tpl.get("作用属性", "") == "全":
				var mult: float = 1.0 + float(tpl.get("数值", 0.0))
				st["base属性"]["血"] = float(st["base属性"]["血"]) * mult
				st["cur属性"]["血"] = float(st["cur属性"]["血"]) * mult
	return st

# S2 增强·3v3 全队光环兜底：原版路径（无技能）也消费 初始buff；仅 bf_aura 影响四维属性。
# 注意：3v3 传入的是深拷贝，此处就地修改 属性 不会污染外部调用方。
static func _应用初始buff(snap: Dictionary) -> void:
	if not snap.has("初始buff"):
		return
	for bid in snap["初始buff"]:
		if str(bid) == "bf_aura":
			var a: Dictionary = snap.get("属性", {})
			for k in ["攻", "防", "血", "速"]:
				if a.has(k):
					a[k] = float(a[k]) * 1.15
			break

static func _recompute_attr(st: Dictionary) -> void:
	var base: Dictionary = st["base属性"]
	var cur: Dictionary = st["cur属性"]
	for k in ["攻", "防", "速"]:
		var v: float = float(base[k])
		for b in st["active_buffs"]:
			if b["类型"] == "控制":
				continue
			if b["作用属性"] != "全" and b["作用属性"] != k:
				continue
			var sign: float = 1.0 if b["类型"] == "增益" else -1.0
			if b["数值类型"] == "percent":
				v += float(base[k]) * float(b["数值"]) * sign
			elif b["数值类型"] == "flat":
				v += float(b["数值"]) * sign
		cur[k] = max(0.0, v)
	# 速变动 → 重算 闪避率/暴击率（按 base 比例代理，[PLACEHOLDER] 待校准）
	var base速: float = float(base["速"])
	if base速 > 0:
		var ratio: float = float(cur["速"]) / base速
		st["cur闪避"] = clamp(st["base闪避"] * ratio, 0.0, 闪避率上限)
		st["cur暴击"] = clamp(st["base暴击"] * ratio, 0.0, 暴击率上限)
	else:
		st["cur闪避"] = st["base闪避"]
		st["cur暴击"] = st["base暴击"]

static func _tick_buffs(st: Dictionary, other_st: Dictionary, side_is_atk: bool, 回合: int, 日志: Array) -> void:
	# ① 持续伤害 dot（每回合损失当前气血比例/flat，伤害下限兜底）
	for b in st["active_buffs"]:
		if b["类型"] != "dot":
			continue
		var 损: int = 0
		if b["buff_id"] == "bf_true_dmg":
			损 = int(st["base属性"]["血"] * float(b["数值"]))   # 真实伤害：按最大生命%
		elif b["数值类型"] == "percent":
			损 = int(st["cur属性"]["血"] * float(b["数值"]))
		else:
			损 = int(float(b["数值"]))
		st["cur属性"]["血"] = float(st["cur属性"]["血"]) - max(1, 损)
		日志.append(_log_entry(回合, st["snapshot"].get("名称", "?"), st["snapshot"].get("名称", "?"), 0, false, false,
			int(st["cur属性"]["血"]) if side_is_atk else int(other_st["cur属性"]["血"]),
			int(other_st["cur属性"]["血"]) if side_is_atk else int(st["cur属性"]["血"]),
			"buff_tick", "", "buff", b["buff_id"], b["buff名"]))
	# ② 控制：仅标记（行动阶段跳过），此处不处理
	# ③ 增益/减益 → 重算 cur属性（含 速，触发 闪避/暴击重算）
	_recompute_attr(st)
	# ④ 灵力回复
	st["mp"] = min(float(st["mp_max"]), float(st["mp"]) + 灵力回复)
	# ⑤ 消散：剩余回合 -=1，<=0 移除并写 buff_expire
	var keep: Array = []
	for b in st["active_buffs"]:
		if b.get("常驻", false):
			keep.append(b)
			continue
		b["剩余回合"] = int(b["剩余回合"]) - 1
		if b["剩余回合"] > 0:
			keep.append(b)
		else:
			日志.append(_log_entry(回合, st["snapshot"].get("名称", "?"), st["snapshot"].get("名称", "?"), 0, false, false,
				int(st["cur属性"]["血"]) if side_is_atk else int(other_st["cur属性"]["血"]),
				int(other_st["cur属性"]["血"]) if side_is_atk else int(st["cur属性"]["血"]),
				"buff_expire", "", "buff", b["buff_id"], b["buff名"]))
	st["active_buffs"] = keep

static func _has_control(st: Dictionary) -> bool:
	for b in st["active_buffs"]:
		if b["类型"] == "控制":
			return true
	return false

static func _try_revive(st: Dictionary, 回合: int, 日志: Array) -> void:
	# S2 毕业·复活：致命伤恢复 base属性["血"]*数值 一次（bf_revive 消耗后失效）
	if st["cur属性"]["血"] > 0:
		return
	var idx: int = -1
	for i in st["active_buffs"].size():
		if st["active_buffs"][i]["buff_id"] == "bf_revive":
			idx = i
			break
	if idx < 0:
		return
	var b: Dictionary = st["active_buffs"][idx]
	var frac: float = float(b.get("数值", 0.0))
	st["cur属性"]["血"] = float(int(float(st["base属性"]["血"]) * frac))
	st["active_buffs"].remove_at(idx)
	日志.append(_log_entry(回合, st["snapshot"].get("名称", "?"), st["snapshot"].get("名称", "?"), 0, false, false,
		int(st["cur属性"]["血"]), int(st["cur属性"]["血"]),
		"revive", "", "buff", "bf_revive", "复活"))

static func _apply_buff(st: Dictionary, template: Dictionary, source: String) -> void:
	var b: Dictionary = template.duplicate(true)
	b["剩余回合"] = int(b.get("持续回合", 1))
	b["来源"] = source
	b["层数"] = 1
	b["常驻"] = false
	# 不可叠加：同 buff_id 先移除旧层
	if not b.get("可叠加", false):
		var keep: Array = []
		for old in st["active_buffs"]:
			if old["buff_id"] != b["buff_id"]:
				keep.append(old)
		st["active_buffs"] = keep
	st["active_buffs"].append(b)
	# 作用属性 == 血：增益即时折算到 HP 池（dot 由 tick 处理；护盾/回春近似即时治疗，[PLACEHOLDER]）
	if b["作用属性"] == "血" and b["类型"] == "增益":
		var heal: int = max(1, int(float(st["base属性"]["血"]) * float(b["数值"])))
		st["cur属性"]["血"] = float(st["cur属性"]["血"]) + heal

static func _被动_to_buff(sk: Dictionary) -> Dictionary:
	# 被动天赋 → 常驻自增益模板（§3.2.5；本批不触发）。减伤→防、增伤→攻；暴伤暂无模板→空（跳过）
	var et: String = sk.get("effect_type", "")
	var ev: float = float(sk.get("effect_value", 0))
	if et == "减伤":
		return {"buff_id": sk.get("skill_id", ""), "buff名": sk.get("skill_name", "被动"), "类型": "增益", "作用属性": "防", "数值": ev, "数值类型": "percent", "持续回合": 常驻回合, "来源类型": "passive", "可叠加": false}
	if et == "增伤":
		return {"buff_id": sk.get("skill_id", ""), "buff名": sk.get("skill_name", "被动"), "类型": "增益", "作用属性": "攻", "数值": ev, "数值类型": "percent", "持续回合": 常驻回合, "来源类型": "passive", "可叠加": false}
	return {}

static func _buff模板(buff_id: String) -> Dictionary:
	# 运行时 buff 模板（镜像 battle_buff.csv；为保持纯函数/无 FileAccess/可 Python 断言，内联且与
	# battle_buff.csv 数值保持一致；[PLACEHOLDER] 数值待战斗基线实测回填）。
	if buff_id == "bf_burn":
		return {"buff_id": "bf_burn", "buff名": "灼烧", "类型": "dot", "作用属性": "血", "数值": 0.05, "数值类型": "percent", "持续回合": 2, "来源类型": "skill", "可叠加": false}
	if buff_id == "bf_freeze":
		return {"buff_id": "bf_freeze", "buff名": "冰冻", "类型": "控制", "作用属性": "全", "数值": 0.0, "数值类型": "none", "持续回合": 1, "来源类型": "skill", "可叠加": false}
	if buff_id == "bf_stun":
		return {"buff_id": "bf_stun", "buff名": "眩晕", "类型": "控制", "作用属性": "全", "数值": 0.0, "数值类型": "none", "持续回合": 1, "来源类型": "skill", "可叠加": false}
	if buff_id == "bf_shield":
		return {"buff_id": "bf_shield", "buff名": "护盾", "类型": "增益", "作用属性": "血", "数值": 0.15, "数值类型": "flat", "持续回合": 3, "来源类型": "skill", "可叠加": false}
	if buff_id == "bf_atkup":
		return {"buff_id": "bf_atkup", "buff名": "攻击增益", "类型": "增益", "作用属性": "攻", "数值": 0.10, "数值类型": "percent", "持续回合": 3, "来源类型": "skill", "可叠加": true}
	if buff_id == "bf_defdown":
		return {"buff_id": "bf_defdown", "buff名": "破甲", "类型": "减益", "作用属性": "防", "数值": 0.20, "数值类型": "percent", "持续回合": 2, "来源类型": "skill", "可叠加": false}
	if buff_id == "bf_defup":
		return {"buff_id": "bf_defup", "buff名": "防御增益", "类型": "增益", "作用属性": "防", "数值": 0.15, "数值类型": "percent", "持续回合": 3, "来源类型": "passive", "可叠加": false}
	if buff_id == "bf_spdup":
		return {"buff_id": "bf_spdup", "buff名": "疾行", "类型": "增益", "作用属性": "速", "数值": 0.15, "数值类型": "percent", "持续回合": 3, "来源类型": "passive", "可叠加": false}
	if buff_id == "bf_regen":
		return {"buff_id": "bf_regen", "buff名": "回春", "类型": "增益", "作用属性": "血", "数值": 0.08, "数值类型": "percent", "持续回合": 3, "来源类型": "item", "可叠加": false}
	# S2 毕业·神器/无上功法/奇物 专属 buff（纯增量，零红线）
	if buff_id == "bf_true_dmg":
		return {"buff_id": "bf_true_dmg", "buff名": "真实伤害", "类型": "dot", "作用属性": "血", "数值": 0.05, "数值类型": "percent", "持续回合": 2, "来源类型": "skill", "可叠加": false}
	if buff_id == "bf_revive":
		return {"buff_id": "bf_revive", "buff名": "复活", "类型": "增益", "作用属性": "无", "数值": 0.30, "数值类型": "percent", "持续回合": 9999, "来源类型": "item", "可叠加": false}
	if buff_id == "bf_aura":
		return {"buff_id": "bf_aura", "buff名": "灵光护佑", "类型": "增益", "作用属性": "全", "数值": 0.15, "数值类型": "percent", "持续回合": 3, "来源类型": "skill", "可叠加": false}
	return {}

static func _skill_buff映射(skill: Dictionary) -> Array:
	# skill.csv effect_type/effect_value → battle_buff.csv 模板（代码查表，不改 skill.csv；§3.2.5）
	# 返回 [{buff: buff_id, 目标: "self"/"enemy"}]
	var sid: String = skill.get("skill_id", "")
	if sid == "sk_ti_02":
		return [{"buff": "bf_shield", "目标": "self"}]
	if sid == "sk_ti_05":
		return [{"buff": "bf_stun", "目标": "enemy"}]
	if sid == "sk_dao_02":
		return [{"buff": "bf_defdown", "目标": "enemy"}]
	if sid == "sk_fa_02":
		return [{"buff": "bf_burn", "目标": "enemy"}]
	if sid == "sk_fa_03":
		return [{"buff": "bf_freeze", "目标": "enemy"}]
	if sid == "sk_fa_05":
		return [{"buff": "bf_burn", "目标": "enemy"}]
	# S2 套装·特效族：set_xxx → 增强引擎 buff 模板（控制/灼烧/眩晕/护盾/回春/破甲/增益/疾行）
	if sid == "set_freeze":
		return [{"buff": "bf_freeze", "目标": "enemy"}]
	if sid == "set_stun":
		return [{"buff": "bf_stun", "目标": "enemy"}]
	if sid == "set_burn":
		return [{"buff": "bf_burn", "目标": "enemy"}]
	if sid == "set_defdown":
		return [{"buff": "bf_defdown", "目标": "enemy"}]
	if sid == "set_shield":
		return [{"buff": "bf_shield", "目标": "self"}]
	if sid == "set_regen":
		return [{"buff": "bf_regen", "目标": "self"}]
	if sid == "set_atkup":
		return [{"buff": "bf_atkup", "目标": "self"}]
	if sid == "set_defup":
		return [{"buff": "bf_defup", "目标": "self"}]
	if sid == "set_spdup":
		return [{"buff": "bf_spdup", "目标": "self"}]
	# S2 毕业·神器/无上功法/奇物 专属特效
	if sid == "set_true_dmg":
		return [{"buff": "bf_true_dmg", "目标": "enemy"}]
	if sid == "set_revive":
		return [{"buff": "bf_revive", "目标": "self"}]
	if sid == "set_aura":
		return [{"buff": "bf_aura", "目标": "self"}]
	return []

static func _select_skill(actor_st: Dictionary, target_st: Dictionary) -> Dictionary:
	var cands: Array = []
	for sk in actor_st["snapshot"].get("技能", []):
		if typeof(sk) != TYPE_DICTIONARY:
			continue
		if sk.get("skill_type", "") == "被动天赋":
			continue
		var sid: String = sk.get("skill_id", "")
		var cd: int = int(actor_st["cooldowns"].get(sid, 0))
		var cost: float = float(sk.get("mp_cost", 0))
		if cd == 0 and float(actor_st["mp"]) >= cost:
			cands.append(sk)
	if cands.is_empty():
		return {}
	# §9.8.5：体修残血优先护盾/防御技；法修多目标优先群体（1v1 退化为高伤优先）
	var prof: String = actor_st["snapshot"].get("职业", "")
	var hp_pct: float = float(actor_st["cur属性"]["血"]) / max(1.0, float(actor_st["base属性"]["血"]))
	if prof == "体修" and hp_pct < 0.5:
		for sk in cands:
			if sk.get("effect_type", "") in ["护盾", "减伤", "伤害+控制"]:
				return sk
	# 高伤优先：按 damage_rate 降序取最高
	var best: Dictionary = {}
	var best_rate: float = -1.0
	for sk in cands:
		var r: float = float(sk.get("damage_rate", 0))
		if r > best_rate:
			best_rate = r
			best = sk
	return best

static func _build_actor_view(st: Dictionary) -> Dictionary:
	var view: Dictionary = st["snapshot"].duplicate(true)
	view["属性"] = st["cur属性"]   # cur属性 含 攻/防/血/速/灵力（与快照键名一致）
	return view

static func _cast_skill(actor_st: Dictionary, target_st: Dictionary, skill: Dictionary, 回合: int, 日志: Array) -> void:
	var actor_view: Dictionary = _build_actor_view(actor_st)
	var target_view: Dictionary = _build_actor_view(target_st)
	var rate: float = float(skill.get("damage_rate", 1.0))
	# 技能伤害 = calc_hit_damage(actor_view × damage_rate, target)；攻 × damage_rate
	actor_view["属性"] = actor_st["cur属性"].duplicate(true)
	actor_view["属性"]["攻"] = float(actor_st["cur属性"]["攻"]) * rate
	var float_factor: float = randf_range(浮动下限, 浮动上限)
	var crit_mult: float = 暴击系数 if randf() < float(actor_st["cur暴击"]) else 1.0
	var dodge_mult: float = 0.0 if randf() < float(target_st["cur闪避"]) else 1.0
	var 穿透率: float = float(actor_st["snapshot"].get("穿透率", 0.0))
	var 伤害: int = calc_hit_damage(actor_view, target_view, float_factor, crit_mult, dodge_mult, false, 穿透率)
	target_st["cur属性"]["血"] = float(target_st["cur属性"]["血"]) - 伤害
	# S2 套装·反伤：受击方按攻方反伤率反弹部分伤害（不递归触发）
	var 反弹率: float = float(actor_st["snapshot"].get("反伤率", 0.0))
	if 反弹率 > 0.0:
		var 反弹伤: int = int(float(伤害) * 反弹率)
		if 反弹伤 > 0:
			actor_st["cur属性"]["血"] = float(actor_st["cur属性"]["血"]) - 反弹伤
	# S2 套装·吸血（技能命中）
	var 吸血v3: float = float(actor_st["snapshot"].get("吸血率", 0.0))
	if 吸血v3 > 0.0 and 伤害 > 0:
		var h3: int = int(float(伤害) * 吸血v3)
		if h3 > 0:
			actor_st["cur属性"]["血"] = min(float(actor_st["base属性"]["血"]), float(actor_st["cur属性"]["血"]) + h3)
	# 施加 buff（按 §3.2.5 映射：self/enemy）+ 写 buff_apply 日志（§3.3）
	for m in _skill_buff映射(skill):
		var buff_id: String = m["buff"]
		var tgt: Dictionary = target_st if m["目标"] == "enemy" else actor_st
		var tpl: Dictionary = _buff模板(buff_id)
		if not tpl.is_empty():
			_apply_buff(tgt, tpl, "skill")
			日志.append(_log_entry(回合, actor_st["snapshot"].get("名称", "攻方"), target_st["snapshot"].get("名称", "守方"), 0, false, false,
				int(actor_st["cur属性"]["血"]), int(target_st["cur属性"]["血"]),
				"buff_apply", "", "buff", buff_id, tpl["buff名"]))
	# cast_skill 日志（带 ref）
	日志.append(_log_entry(回合, actor_st["snapshot"].get("名称", "攻方"), target_st["snapshot"].get("名称", "守方"), 伤害,
		crit_mult > 1.0,
		profession_multiplier(actor_view.get("职业", ""), target_view.get("职业", "")) > 1.0,
		int(actor_st["cur属性"]["血"]), int(target_st["cur属性"]["血"]),
		"cast_skill", "", "skill", skill.get("skill_id", ""), skill.get("skill_name", "")))
	# 冷却 + 灵力
	actor_st["cooldowns"][skill.get("skill_id", "")] = int(skill.get("cooldown", 0))
	actor_st["mp"] = float(actor_st["mp"]) - float(skill.get("mp_cost", 0))

static func _tick_cooldowns(st: Dictionary) -> void:
	for k in st["cooldowns"].keys():
		st["cooldowns"][k] = max(0, int(st["cooldowns"][k]) - 1)

static func _结算_1v1_原版(atk: Dictionary, def: Dictionary, mode: String = "full") -> Dictionary:
	# S2 增强·3v3 全队光环兜底：原版路径（无技能）消费 初始buff（bf_aura 直接加成属性）；
	# 须在读取 a_hp/a_spd 等派生量之前执行，否则加成不生效。
	_应用初始buff(atk)
	_应用初始buff(def)
	var a_hp: int = int(atk.get("属性", {}).get("血", 1))
	var d_hp: int = int(def.get("属性", {}).get("血", 1))
	var a_hp_max: int = a_hp
	var d_hp_max: int = d_hp
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
			var 穿透率: float = float(actor.get("穿透率", 0.0))
			var 伤害: int = calc_hit_damage(actor, target, float_factor, crit_mult, dodge_mult, false, 穿透率)
			if target == def:
				d_hp -= 伤害
			else:
				a_hp -= 伤害
			# S2 套装·反伤：受击方按攻方反伤率反弹部分伤害（不递归触发）
			var 反弹率: float = float(actor.get("反伤率", 0.0))
			if 反弹率 > 0.0:
				var 反弹伤: int = int(float(伤害) * 反弹率)
				if 反弹伤 > 0:
					if target == def:
						a_hp -= 反弹伤
					else:
						d_hp -= 反弹伤
						日志.append(_log_entry(回合, target_label, actor_label, 反弹伤, false, false, a_hp, d_hp, "reflect"))
			# S2 套装·吸血：攻方按自身吸血率回复部分伤害（默认 0.0 → 不变；夹在初始血量内防过量）
			var 吸血v: float = float(actor.get("吸血率", 0.0))
			if 吸血v > 0.0 and 伤害 > 0:
				var 吸伤: int = int(float(伤害) * 吸血v)
				if 吸伤 > 0:
					if actor == atk:
						a_hp = min(a_hp_max, a_hp + 吸伤)
					else:
						d_hp = min(d_hp_max, d_hp + 吸伤)
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

# —— 增强版（S1 批3：单位工作态 + Buff 生命周期 + 技能释放/冷却；ADR-003 纯函数）——
# 单位工作态为函数局部变量（base/cur 属性 split、active_buffs、cooldowns、mp），
# 不 mutate 调用方 atk/def。cur属性 与快照键名一致，仅喂给 calc_hit_damage（签名不改）。
static func _结算_1v1_增强(atk: Dictionary, def: Dictionary, mode: String = "full") -> Dictionary:
	var a_state: Dictionary = _build_unit_state(atk)
	var d_state: Dictionary = _build_unit_state(def)
	var a_name: String = atk.get("名称", "攻方")
	var d_name: String = def.get("名称", "守方")

	var 回合 := 0
	var 日志 := []
	var 攻先手: bool = a_state["cur属性"]["速"] >= d_state["cur属性"]["速"]

	while true:
		回合 += 1
		if 回合 > 回合上限:
			break   # 超时 → 守方胜
		# §9.7.2 回合开始 tick（出手序之前）：dot→控制标记→重算→灵力回复→消散
		_tick_buffs(a_state, d_state, true, 回合, 日志)
		_tick_buffs(d_state, a_state, false, 回合, 日志)
		# 速变动 → 重算先手（休眠路径 速不变 → 与今日一致）
		攻先手 = a_state["cur属性"]["速"] >= d_state["cur属性"]["速"]
		var 出手序: Array = []
		if 攻先手:
			出手序 = [{"atk": true}, {"atk": false}]
		else:
			出手序 = [{"atk": false}, {"atk": true}]

		for 步 in 出手序:
			if a_state["cur属性"]["血"] <= 0 or d_state["cur属性"]["血"] <= 0:
				break
			var is_atk: bool = 步["atk"]
			var actor_st: Dictionary = a_state if is_atk else d_state
			var target_st: Dictionary = d_state if is_atk else a_state
			var actor_label: String = a_name if is_atk else d_name
			var target_label: String = d_name if is_atk else a_name

			# ③ 控制跳过行动（§3.1.6）：含 控制 buff → 跳过本次行动，写 control_skip
			if _has_control(actor_st):
				日志.append(_log_entry(回合, actor_label, target_label, 0, false, false,
					int(a_state["cur属性"]["血"]), int(d_state["cur属性"]["血"]),
					"control_skip", "", "buff", "", "控制"))
				continue

			# ② 技能释放（§9.8.5 自动 AI）：就绪则释放并跳过普攻
			var chosen: Dictionary = _select_skill(actor_st, target_st)
			if not chosen.is_empty():
				_cast_skill(actor_st, target_st, chosen, 回合, 日志)
				continue

			# ① 普攻（与今日数学一致：calc_hit_damage 签名不改，仅喂 cur属性 视图）
			var actor_view: Dictionary = _build_actor_view(actor_st)
			var target_view: Dictionary = _build_actor_view(target_st)
			var actor_crit: float = actor_st["cur暴击"]
			var target_dodge: float = target_st["cur闪避"]
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
			var 伤害: int = calc_hit_damage(actor_view, target_view, float_factor, crit_mult, dodge_mult, false)
			if is_atk:
				d_state["cur属性"]["血"] = float(d_state["cur属性"]["血"]) - 伤害
			else:
				a_state["cur属性"]["血"] = float(a_state["cur属性"]["血"]) - 伤害
			# S2 套装·吸血（增强普攻）：攻方(actor_st)按自身吸血率回复部分伤害
			var 吸血v2: float = float(actor_st["snapshot"].get("吸血率", 0.0))
			if 吸血v2 > 0.0 and 伤害 > 0:
				var h2: int = int(float(伤害) * 吸血v2)
				if h2 > 0:
					actor_st["cur属性"]["血"] = min(float(actor_st["base属性"]["血"]), float(actor_st["cur属性"]["血"]) + h2)
			# D7 强制结构化日志：每次普攻均记录（行动单位/伤害/暴击/克制/双方剩余血量）
			日志.append(_log_entry(回合, actor_label, target_label, 伤害, crit_mult > 1.0,
			profession_multiplier(actor_view.get("职业", ""), target_view.get("职业", "")) > 1.0,
			int(a_state["cur属性"]["血"]), int(d_state["cur属性"]["血"])))

		# 回合末冷却 tick
		_tick_cooldowns(a_state)
		_tick_cooldowns(d_state)
		# S2 毕业·复活：致命伤恢复一次（回合末死亡判定前）
		_try_revive(a_state, 回合, 日志)
		_try_revive(d_state, 回合, 日志)
		if a_state["cur属性"]["血"] <= 0 or d_state["cur属性"]["血"] <= 0:
			break

	# 胜负判定：守方先死→攻方胜；攻方先死或超时→守方胜
	var is_win := false
	if d_state["cur属性"]["血"] <= 0 and a_state["cur属性"]["血"] > 0:
		is_win = true
	elif a_state["cur属性"]["血"] <= 0 and d_state["cur属性"]["血"] > 0:
		is_win = false
	else:
		is_win = false   # 双亡 / 超时 → 守方胜
	var remaining: int = int(a_state["cur属性"]["血"]) if is_win else int(d_state["cur属性"]["血"])
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
	# S2 增强·3v3 全队光环传播：任一队员持 set_aura → 全队获得常驻 bf_aura（覆盖整场），
	# 并移除个人 set_aura 技能，避免子战重复释放（全队光环已由初始buff承担）
	for 侧 in [攻, 守]:
		var 有光环 := false
		for u in 侧:
			for sk in u.get("技能", []):
				if typeof(sk) == TYPE_DICTIONARY and sk.get("skill_id", "") == "set_aura":
					有光环 = true
					break
			if 有光环:
				break
		if 有光环:
			for u in 侧:
				if not u.has("初始buff"):
					u["初始buff"] = []
				if "bf_aura" not in u["初始buff"]:
					u["初始buff"].append("bf_aura")
				var 新技能 := []
				for sk in u.get("技能", []):
					if typeof(sk) == TYPE_DICTIONARY and sk.get("skill_id", "") != "set_aura":
						新技能.append(sk)
				u["技能"] = 新技能
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
static func _log_entry(回合: int, actor: String, target: String, 伤害: int, 暴击: bool, 克制: bool, 攻方血: int, 守方血: int, log_type: String = "damage", extra: String = "", ref_type: String = "", ref_id: String = "", ref_name: String = "") -> Dictionary:
	var 标签: Array = []
	if 暴击:
		标签.append("暴击")
	if 克制:
		标签.append("克制")
	if 伤害 == 0 and log_type == "damage":
		标签.append("闪避")
	if 守方血 <= 0 and log_type == "damage":
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
		"log_type": log_type,
		"tags": 标签,
		"extra": extra,
		"ref_type": ref_type,
		"ref_id": ref_id,
		"ref_name": ref_name,
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
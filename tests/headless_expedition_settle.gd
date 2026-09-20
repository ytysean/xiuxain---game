extends Node

## 历练端到端结算断言（A3 · headless · 2026-09-16）
##
## 目的：为 B1/B3（`expedition.gd:501-620` 快照补齐 / 放开技能）先立一道**端到端安全网** ——
##   断言「技能 / 护身符 / 套装」这些输入真的走到了**真实战斗结算入口**，
##   而不是在别处算完却被快照丢弃（这正是"条件漂移/无效计算"的典型形态）。
##
## 覆盖：
##   [1] 敌方快照     `_构造敌方快照(关卡ID)` 返回合法战斗快照（四维属性 + 战力>0 + 技能/功法被动字段在）
##   [2] 快照聚合幂等  `_聚合队伍快照([单人])` 的属性/极品特效/功法被动 与 `get_final_combat_attr` 一致
##   [3] 端到端结算    `BattleManager.发起1v1(攻方,守方,"quick",false)` 真正产出 battle_log（战斗真跑了）
##   [4] 技能通道现状  两个快照构造器当前 `技能==[]`（S3 未放开）——> 只在运行时打印，B3 落地后应翻
##
## 红线：不进 `tests/combat/`；不改任何业务代码（只读真实 Game 状态 + 只调用既有函数）。
## 运行：MSYS_NO_PATHCONV=1 <godot> --headless --path <proj> --scene res://tests/headless_expedition_settle.tscn
## 判据：末行 >>>A3_DONE fail=0，且 exit=0。

var _ok: int = 0
var _fail: int = 0


func _ready() -> void:
	prints("=== A3 历练端到端结算断言启动 ===")
	if Game == null:
		printerr(">>>FAIL Game 单例缺失")
		get_tree().quit(1)
		return
	if Game.弟子列表.is_empty():
		Game.初始建宗()
	if Game.弟子列表.is_empty():
		printerr(">>>FAIL 初始建宗后仍无弟子，无法断言")
		get_tree().quit(1)
		return

	# ---------- [1] 敌方快照 ----------
	var foe: Dictionary = ExpeditionSystem._构造敌方快照("daily_lingcai")
	_check("敌方快照非空", not foe.is_empty())
	var fa: Dictionary = foe.get("属性", {})
	_check("敌方属性四维齐（攻/防/血/速）", fa.has("攻") and fa.has("防") and fa.has("血") and fa.has("速"))
	_check("敌方战力 > 0", int(foe.get("战力", 0)) > 0)
	_check("敌方 技能 字段为 Array", (foe.get("技能", null) as Variant) is Array)
	_check("敌方 功法被动 字段为 Array", (foe.get("功法被动", null) as Variant) is Array)

	# ---------- [2] 队伍快照聚合（单人 ⇒ 应与该弟子最终战斗属性一致）----------
	var d: Object = Game.弟子列表[0]
	var final: Dictionary = d.get_final_combat_attr()
	prints(">>>A3_ATTR_KEYS 弟子最终属性键=", final.keys())
	prints(">>>A3_CHANNELS 极品特效=", final.get("极品特效", []), " 功法被动=", final.get("功法被动", []))
	var team: Dictionary = ExpeditionSystem._聚合队伍快照([int(d.弟子ID)])
	_check("队伍快照非空", not team.is_empty())
	var ta: Dictionary = team.get("属性", {})
	var fa2: Dictionary = final.get("属性", {})
	_check("队伍属性 攻 == 弟子最终属性 攻", int(ta.get("攻", -1)) == int(fa2.get("攻", -2)))
	_check("队伍属性 血 == 弟子最终属性 血", int(ta.get("血", -1)) == int(fa2.get("血", -2)))
	_check("极品特效透传（套装/法宝通道）",
		str(team.get("极品特效", [])) == str(final.get("极品特效", [])))
	_check("功法被动透传（护身符/功法通道）",
		str(team.get("功法被动", [])) == str(final.get("功法被动", [])))
	_check("队伍 技能 字段为 Array", (team.get("技能", null) as Variant) is Array)

	# ---------- [3] 端到端真实战斗结算 ----------
	if not team.is_empty():
		var rep: Dictionary = BattleManager.发起1v1(team, foe, "quick", false)
		_check("战报含 is_win", rep.has("is_win"))
		_check("战报 battle_log 为 Array", (rep.get("battle_log", null) as Variant) is Array)
		_check("战斗真跑了（battle_log 非空）", (rep.get("battle_log", []) as Array).size() > 0)
		prints(">>>A3_BATTLE is_win=", rep.get("is_win", "—"),
			" 日志条数=", (rep.get("battle_log", []) as Array).size())
	else:
		_check("队伍快照可用（否则无法发起战斗）", false)

	# ---------- [4] 技能通道现状（运行时报告，不阻断）----------
	var foe_skill_empty: bool = (foe.get("技能", []) as Array).is_empty()
	var team_skill_empty: bool = (team.get("技能", []) as Array).is_empty()
	prints(">>>A3_SKILL_CHANNEL foe_skill_empty=%s team_skill_empty=%s（true=S3 未放开技能，B3 应翻）"
		% [str(foe_skill_empty), str(team_skill_empty)])

	prints(">>>A3_DONE ok=%d fail=%d" % [_ok, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check(标签: String, 条件: bool) -> void:
	if 条件:
		_ok += 1
		prints("  [PASS] ", 标签)
	else:
		_fail += 1
		printerr("  [FAIL] ", 标签)

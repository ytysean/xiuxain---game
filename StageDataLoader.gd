# StageDataLoader.gd —— 秘境/怪物/掉落 数据层（Day 2）
#
# 定位：纯数据读取层，不依赖 Game / UI / 战斗结算器。
# 所有方法为 static（与 BattleCalculator / BattleManager 一致）；
# 每次调用重读 CSV（数据量小：30 关 + 12 怪 + 27 掉落行，毫秒级，无性能负担）。
# 数据契约（来自 Day 1 生成的 config/*.csv，字段对齐代码枚举口径）：
#   stage_main.csv : stage_id,chapter,stage_name,node_type,unlock_condition,
#                    recommend_power,monster_ids,stamina_cost,daily_limit,
#                    first_reward_type,first_reward_id,first_reward_num,
#                    repeat_drop_pool,difficulty_factor,fail_reduce_enable,designer_note
#   monster_main.csv: monster_id,monster_name,realm,element,base_hp,base_atk,
#                    base_def,base_spd,base_crit,base_dodge,skill_id,
#                    drop_item_ids,drop_weights,is_boss,description
#   drop_pool.csv   : pool_id,item_id,item_name,weight,min_count,max_count,quality
class_name StageDataLoader
extends RefCounted

const 秘境路径 := "res://config/stage_main.csv"
const 怪物路径 := "res://config/monster_main.csv"
const 掉落路径 := "res://config/drop_pool.csv"
# 怪物境界战斗倍率（与 disciple.境界战斗倍率 对称；怪物实战四维随境界放大，消除后期碾压）
const 怪物境界倍率: Dictionary = {"练气":1.0, "筑基":2.0, "金丹":4.0, "元婴":8.0, "化神":15.0, "仙阶":25.0, "道阶":40.0}
# 秘境难度系数（推荐战力 = 怪物队伍战力度量 × 难度系数）
const 难度系数表: Dictionary = {"normal":0.85, "elite":1.0, "boss":1.2, "treasure":0.0}

# ============ CSV 读取（Godot 内置 get_csv_line，自动处理引号字段）============
static func _read_csv(path: String) -> Array:
	var rows: Array = []
	if not FileAccess.file_exists(path):
		push_warning("StageDataLoader: 缺失配置 %s" % path)
		return rows
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not f:
		return rows
	var header: PackedStringArray = f.get_csv_line()
	while not f.eof_reached():
		var line: PackedStringArray = f.get_csv_line()
		if line.is_empty() or line[0] == "":
			continue
		var d: Dictionary = {}
		for i in header.size():
			var key: String = header[i]
			var val: String = line[i] if i < line.size() else ""
			d[key] = val
		rows.append(d)
	f.close()
	return rows

# ============ 秘境查询 ============
static func get_stage(id: String) -> Dictionary:
	for s in _read_csv(秘境路径):
		if s.get("stage_id", "") == id:
			return s
	return {}

static func get_all_stages() -> Array:
	return _read_csv(秘境路径)

# 解锁判定：解析 unlock_condition（格式 "sect_level>=N;pre_stage=X"）
static func is_unlocked(id: String, 宗门等级: int, 已通: Dictionary) -> bool:
	var s: Dictionary = get_stage(id)
	if s.is_empty():
		return false
	var cond: String = s.get("unlock_condition", "")
	for part in cond.split(";"):
		part = part.strip_edges()
		if part == "":
			continue
		if part.begins_with("sect_level>="):
			var need: int = int(part.replace("sect_level>=", "").strip_edges())
			if 宗门等级 < need:
				return false
		elif part.begins_with("pre_stage="):
			var pre: String = part.replace("pre_stage=", "").strip_edges()
			if not 已通.has(pre):
				return false
	return true

# ============ 怪物组装（→ BattleCalculator 单位快照）============
static func build_monster_units(id: String) -> Array:
	var s: Dictionary = get_stage(id)
	if s.is_empty():
		return []
	var ids: String = s.get("monster_ids", "")
	if ids == "":
		return []
	var units: Array = []
	for mid in ids.split(","):
		mid = mid.strip_edges()
		if mid == "":
			continue
		var m: Dictionary = _get_monster(mid)
		if not m.is_empty():
			units.append(_monster_to_unit(m))
	return units

static func _get_monster(mid: String) -> Dictionary:
	for m in _read_csv(怪物路径):
		if m.get("monster_id", "") == mid:
			return m
	return {}

# 怪物 → BattleCalculator 战斗快照（属性嵌套 + 灵根 + 暴击/闪避；道途留空=不触发道途克制）
static func _monster_to_unit(m: Dictionary) -> Dictionary:
	var 倍: float = 怪物境界倍率.get(m.get("realm", "练气"), 1.0)
	return {
		"属性": {
			"攻": int(float(m.get("base_atk", 0)) * 倍),
			"防": int(float(m.get("base_def", 0)) * 倍),
			"血": int(float(m.get("base_hp", 0)) * 倍),
			"速": int(float(m.get("base_spd", 0)) * 倍),
		},
		"道途": "",
		"灵根": {"主": m.get("element", "金"), "纯度": "单"},
		"暴击率": float(m.get("base_crit", 0.0)),
		"闪避率": float(m.get("base_dodge", 0.0)),
		"名称": m.get("monster_name", "妖兽"),
	}

# ============ 掉落 roll ============
static func roll_drop(stage_id: String) -> Array:
	var s: Dictionary = get_stage(stage_id)
	if s.is_empty():
		return []
	var pool_id: String = s.get("repeat_drop_pool", "")
	if pool_id == "":
		return []
	var rows: Array = []
	for p in _read_csv(掉落路径):
		if p.get("pool_id", "") == pool_id:
			rows.append(p)
	if rows.is_empty():
		return []
	var total: float = 0.0
	for r in rows:
		total += float(r.get("weight", 0))
	if total <= 0:
		return []
	var roll: float = randf() * total
	var acc: float = 0.0
	for r in rows:
		acc += float(r.get("weight", 0))
		if roll <= acc:
			var cnt: int = randi_range(int(r.get("min_count", 1)), int(r.get("max_count", 1)))
			return [{
				"item_id": r.get("item_id", ""),
				"item_name": r.get("item_name", ""),
				"count": cnt,
				"quality": r.get("quality", ""),
			}]
	return []

# ============ 推荐战力（动态：随怪物数据自动对齐，替代 CSV 手填 recommend_power）============
# 怪物队伍战力度量 × 难度系数。与弟子 实时战力() 同公式口径，玩家可直接对比判断难度。
static func get_recommend_power(id: String) -> int:
	var s: Dictionary = get_stage(id)
	if s.is_empty():
		return 0
	var ntype: String = s.get("node_type", "normal")
	var diff: float = 难度系数表.get(ntype, 1.0)
	if ntype == "treasure":
		return 0
	var units: Array = build_monster_units(id)
	var total: int = 0
	for u in units:
		total += BattleCalculator.战力度量(u)
	return int(total * diff)
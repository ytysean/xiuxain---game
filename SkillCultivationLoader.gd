# SkillCultivationLoader.gd —— 功法数据层（S1 批3）
#
# 定位：纯数据读取层，不依赖 Game / UI / 弟子实例。
# 所有方法为 static（与 DestinyDataLoader / BattleCalculator 一致）；
# 每次调用重读 CSV（数据量小：39 行，毫秒级，无性能负担）。
# 复用 config/skill_cultivation.csv（D1 决策：不新建 gongfa.csv）。
# 数据契约（来自 config/skill_cultivation.csv）：
#   skill_id, skill_name, grade, sub_grade, apply_class, skill_type, effect_value, max_level, unlock_realm, learn_cost
#   skill_type 枚举：攻击/控制/辅助防御/通用
class_name SkillCultivationLoader
extends RefCounted

const 功法路径 := "res://config/skill_cultivation.csv"

# ============ CSV 读取（Godot 内置 get_csv_line，自动处理引号字段）============
static func _read_csv(path: String) -> Array:
	var rows: Array = []
	if not FileAccess.file_exists(path):
		push_warning("SkillCultivationLoader: 缺失配置 %s" % path)
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

# ============ 查询 ============
static func get_skill(id: String) -> Dictionary:
	for r in _read_csv(功法路径):
		if r.get("skill_id", "") == id:
			return r
	return {}

# ============ 功法被动 → 四维增量（战力映射铁律入口，禁止只堆总战力）============
# 单条功法 → 四维增量。
# [PLACEHOLDER] 映射待批4 战斗基线实测校准（D5：单功法/全功法聚合上限 ≤ 通用增益硬上限 30% 同量级）。
# 当前占位实现：把 effect_value(%) 按其 skill_type 映射到对应维度，作为 flat 增量；
# 真实口径应为「属性 × pct」（见批4 校准）。已修功法默认 [] → 本函数簇不会被调用，现役战斗零变化。
static func _功法四维加成(g: Dictionary) -> Dictionary:
	var r: Dictionary = {"攻": 0, "防": 0, "血": 0, "速": 0}
	var raw: String = str(g.get("effect_value", "0")).replace("%", "").strip_edges()
	var pct: float = 0.0
	if raw.is_valid_float():
		pct = raw.to_float()
	var t: String = g.get("skill_type", "")
	match t:
		"攻击":
			r["攻"] = pct
		"辅助防御":
			r["防"] = pct
		"控制":
			r["速"] = pct
		"通用":
			r["攻"] = pct * 0.25
			r["防"] = pct * 0.25
			r["血"] = pct * 0.25
			r["速"] = pct * 0.25
		_:
			pass
	return r

# 已修功法列表（skill_cultivation.skill_id）→ 四维增量聚合（仅功法部分）
# 空列表 → 全 0，现役战斗零变化。
static func 功法被动加成(已修功法) -> Dictionary:
	var 聚合: Dictionary = {"攻": 0, "防": 0, "血": 0, "速": 0}
	for gid in 已修功法:
		var g: Dictionary = get_skill(gid)
		if g.is_empty():
			continue
		var 加成: Dictionary = _功法四维加成(g)
		for _st in ["攻", "防", "血", "速"]:
			聚合[_st] += int(加成.get(_st, 0))
	return 聚合

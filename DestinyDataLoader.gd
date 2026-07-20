# DestinyDataLoader.gd —— 命格数据层（命格系统重构）
#
# 定位：纯数据读取层，不依赖 Game / UI / 弟子实例。
# 所有方法为 static（与 BattleCalculator / StageDataLoader 一致）；
# 每次调用重读 CSV（数据量小：20 行，毫秒级，无性能负担）。
# 数据契约（来自 config/destiny_main.csv）：
#   destiny_id, 名称, 品级, 类型, 效果参数, 描述
#   品级枚举：凡品/良品/上品/极品/天品（天品首发不投放）
#   类型枚举：修行/经营/战斗/奇遇（奇遇型首发仅占位不生效）
#   效果参数：维度:数值（维度∈{攻,防,血,速,修炼,产出,奇遇}；数值为整数百分比）
class_name DestinyDataLoader
extends RefCounted

const 命格路径 := "res://config/destiny_main.csv"

const 品级枚举 := ["凡品", "良品", "上品", "极品", "天品"]
const 类型枚举 := ["修行", "经营", "战斗", "奇遇"]

# ============ CSV 读取（Godot 内置 get_csv_line，自动处理引号字段）============
static func _read_csv(path: String) -> Array:
	var rows: Array = []
	if not FileAccess.file_exists(path):
		push_warning("DestinyDataLoader: 缺失配置 %s" % path)
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

# ============ 解析：把「维度:数值」拆成结构化字段 ============
static func _解析(r: Dictionary) -> Dictionary:
	var 维度: String = ""
	var 数值: int = 0
	var ep: String = r.get("效果参数", "")
	if ":" in ep:
		var parts: PackedStringArray = ep.split(":")
		维度 = parts[0]
		数值 = int(parts[1])
	return {
		"destiny_id": r.get("destiny_id", ""),
		"名称": r.get("名称", ""),
		"品级": r.get("品级", ""),
		"类型": r.get("类型", ""),
		"维度": 维度,
		"数值": 数值,
		"描述": r.get("描述", ""),
	}

# ============ 查询 ============
static func get_destiny(id: String) -> Dictionary:
	for r in _read_csv(命格路径):
		if r.get("destiny_id", "") == id:
			return _解析(r)
	return {}

static func get_all() -> Array:
	var out: Array = []
	for r in _read_csv(命格路径):
		out.append(_解析(r))
	return out

# 按品级分组返回 {品级: [destiny_id,...]}，供弟子生成时按品级权重抽取
static func ids_by_grade() -> Dictionary:
	var m: Dictionary = {}
	for d in get_all():
		var g: String = d.get("品级", "")
		if not m.has(g):
			m[g] = []
		(m[g] as Array).append(d.get("destiny_id", ""))
	return m

# SkinManager.gd —— 皮肤系统管理器（仙衣阁）
# 负责：加载皮肤配置、获取皮肤信息、仙缘夺宝抽奖、皮肤商店数据
class_name SkinManager
extends Node

# 皮肤配置缓存
static var _皮肤配置缓存: Dictionary = {}
static var _已加载配置: bool = false

# 仙缘夺宝抽奖配置
const 抽奖单次价格: int = 200       # 单次抽奖消耗仙玉
const 抽奖十连价格: int = 1800      # 十连抽奖消耗仙玉（9折）
const 保底次数: int = 80              # 保底次数（80次必出神品）
const 神品概率: float = 0.012         # 神品基础概率1.2%
const 仙品概率: float = 0.08          # 仙品概率8%
const 宝品概率: float = 0.30          # 宝品概率30%
const 灵品概率: float = 0.608         # 灵品概率60.8%

# 抽奖奖励池（按品级分类）
static var _奖池: Dictionary = {
	"神品": [],
	"仙品": [],
	"宝品": [],
	"灵品": []
}

# 玩家抽奖数据（运行时，由Game持久化）
static var 累计抽奖次数: int = 0
static var 距保底剩余次数: int = 保底次数

# 加载皮肤配置CSV
static func 加载皮肤配置() -> Dictionary:
	if _已加载配置:
		return _皮肤配置缓存
	_已加载配置 = true
	var 配置路径: String = "res://config/skin_config.csv"
	if not FileAccess.file_exists(配置路径):
		push_warning("皮肤配置文件不存在: " + 配置路径)
		return {}
	var 文件: FileAccess = FileAccess.open(配置路径, FileAccess.READ)
	if 文件 == null:
		push_warning("无法打开皮肤配置文件")
		return {}
	# 读取表头
	var 表头: Array = 文件.get_csv_line()
	# 读取数据行
	while not 文件.eof_reached():
		var 行: Array = 文件.get_csv_line()
		if 行.size() < 2 or 行[0] == "":
			continue
		var 皮肤: Dictionary = {}
		for i in range(表头.size()):
			if i < 行.size():
				皮肤[表头[i]] = 行[i]
		var 皮肤ID: String = 皮肤.get("skin_id", "")
		if 皮肤ID != "":
			_皮肤配置缓存[皮肤ID] = 皮肤
			# 加入奖池
			var 品级: String = 皮肤.get("rarity", "灵品")
			if _奖池.has(品级):
				_奖池[品级].append(皮肤ID)
	文件.close()
	return _皮肤配置缓存

# 获取单个皮肤配置
static func 获取皮肤配置(皮肤ID: String) -> Dictionary:
	if not _已加载配置:
		加载皮肤配置()
	return _皮肤配置缓存.get(皮肤ID, {})

# 获取所有皮肤配置
static func 获取所有皮肤() -> Dictionary:
	if not _已加载配置:
		加载皮肤配置()
	return _皮肤配置缓存

# 按品级获取皮肤列表
static func 按品级获取皮肤(品级: String) -> Array:
	if not _已加载配置:
		加载皮肤配置()
	var 列表: Array = []
	for 皮肤ID in _皮肤配置缓存.keys():
		var 皮肤: Dictionary = _皮肤配置缓存[皮肤ID]
		if 皮肤.get("rarity", "") == 品级:
			列表.append(皮肤ID)
	return 列表

# ============ 仙缘夺宝抽奖系统 ============
# 单次抽奖
static func 单次抽奖() -> Dictionary:
	if Game == null or not Game.has_method("消耗仙玉_付费"):
		return {"success": false, "msg": "系统未就绪"}
	if not Game.消耗仙玉_付费(抽奖单次价格):
		return {"success": false, "msg": "非绑定仙玉不足（抽奖仅支持付费仙玉）"}
	return _执行抽奖()

# 十连抽奖
static func 十连抽奖() -> Dictionary:
	if Game == null or not Game.has_method("消耗仙玉_付费"):
		return {"success": false, "msg": "系统未就绪"}
	if not Game.消耗仙玉_付费(抽奖十连价格):
		return {"success": false, "msg": "非绑定仙玉不足（抽奖仅支持付费仙玉）"}
	var 结果: Array = []
	for i in range(10):
		var 单次: Dictionary = _执行抽奖()
		结果.append(单次)
	return {"success": true, "results": 结果}

# 执行单次抽奖逻辑（内部）
static func _执行抽奖() -> Dictionary:
	累计抽奖次数 += 1
	距保底剩余次数 -= 1
	# 保底机制：距保底剩余次数=0时必出神品
	var 品级: String = ""
	if 距保底剩余次数 <= 0:
		品级 = "神品"
		距保底剩余次数 = 保底次数
	else:
		# 概率抽取
		var r: float = randf()
		if r < 神品概率:
			品级 = "神品"
			距保底剩余次数 = 保底次数
		elif r < 神品概率 + 仙品概率:
			品级 = "仙品"
		elif r < 神品概率 + 仙品概率 + 宝品概率:
			品级 = "宝品"
		else:
			品级 = "灵品"
	# 从对应品级奖池随机选一个皮肤
	var 奖池列表: Array = _奖池.get(品级, [])
	var 皮肤ID: String = ""
	if not 奖池列表.is_empty():
		皮肤ID = 奖池列表.pick_random()
	else:
		# 该品级无皮肤，降级到灵品
		奖池列表 = _奖池.get("灵品", [])
		if not 奖池列表.is_empty():
			皮肤ID = 奖池列表.pick_random()
			品级 = "灵品"
	return {
		"success": true,
		"skin_id": 皮肤ID,
		"rarity": 品级,
		"is_guaranteed": (距保底剩余次数 == 保底次数 and 品级 == "神品")
	}

# 获取抽奖状态信息
static func 获取抽奖状态() -> Dictionary:
	return {
		"累计次数": 累计抽奖次数,
		"距保底剩余": 距保底剩余次数,
		"单次价格": 抽奖单次价格,
		"十连价格": 抽奖十连价格,
		"保底次数": 保底次数
	}

# 重置抽奖状态（读档时调用）
static func 重置抽奖状态(累计: int, 距保底: int):
	累计抽奖次数 = 累计
	距保底剩余次数 = 距保底

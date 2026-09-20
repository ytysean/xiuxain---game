# sect_bounty.gd —— 宗门任务榜数据层（S27）
#
# 定位：§4.0「弟子自主层」的主动行为出口。
#   此前所有任务（历练/调查/势力）都是**玩家指派**，弟子从不主动做事。
#   本层让弟子依据自身人生目标，自主决定「接不接、接哪个、主动请什么」。
#
# 双轨：
#   1. 玩家挂榜 → 弟子自主接取（接取意愿 评分排序 + 阈值 + 概率）
#   2. 弟子请命 → 玩家批准/驳回（榜上无合意任务时，据主目标主动申请）
#
# 红线（与 goal.gd 一致）：
#   - 只产出「意愿/评分/概率」，绝不注入属性乘区，绝不碰 突破成功率修正()
#   - 不修改任何弟子字段（写字段由 game_state 的结算函数负责）
#   - 复用 goal_config 八维，不在本表重新标定目标倾向
#
# 报酬（方案 A 库房拨付）：不新建货币。完成任务后从 宗门库房 按品阶拨一件
#   进弟子 背包，高难度额外给 保命护身。报酬档位由玩家在发榜时压/加，
#   直接影响接取意愿——「给少了没人来」是这套系统的核心博弈。

class_name SectBounty
extends RefCounted

const Disciple = preload("res://disciple.gd")
const Item = preload("res://item.gd")
const Goal = preload("res://goal.gd")
const DestinyDataLoader = preload("res://DestinyDataLoader.gd")

const 配置路径: String = "res://config/sect_bounty_config.csv"

# 弟子终究有修炼/历练本职，接任务不是生活的全部
const 接取意愿上限: float = 0.90
# 意愿低于此值视为「无人问津」——玩家必须加报酬或换人
const 接取意愿阈值: float = 0.30

const 类型显示: Dictionary = {"collect": "征缴", "hunt": "清剿", "diplomacy": "寻访"}

# 报酬档差 → 意愿倍率（负=玩家压档，正=加档）
const 报酬档差倍率: Dictionary = {-2: 0.30, -1: 0.60, 0: 1.00, 1: 1.40, 2: 1.70}

static var _表: Array = []
static var _已加载: bool = false

# ==================== 装载 ====================

static func _加载() -> void:
	if _已加载:
		return
	_表 = DestinyDataLoader._read_csv(配置路径)
	_已加载 = true


## 供测试/热重载使用：清空缓存强制重新读表
static func 重载() -> void:
	_已加载 = false
	_表 = []
	_加载()


static func 全部模板() -> Array:
	_加载()
	return _表


static func 取模板(模板ID: String) -> Dictionary:
	_加载()
	for r in _表:
		if str(r.get("bounty_id", "")) == 模板ID:
			return r
	return {}


static func 有此模板(模板ID: String) -> bool:
	return not 取模板(模板ID).is_empty()


static func 类型名(类型: String) -> String:
	return str(类型显示.get(类型, 类型))


# ==================== 数值读取 ====================

static func _取整(配置: Dictionary, 列: String, 默认: int) -> int:
	var 原: String = str(配置.get(列, "")).strip_edges()
	if 原 == "":
		return 默认
	if not 原.is_valid_int():
		return 默认
	return int(原)


static func _取浮(配置: Dictionary, 列: String, 默认: float) -> float:
	var 原: String = str(配置.get(列, "")).strip_edges()
	if 原 == "":
		return 默认
	if not 原.is_valid_float():
		return 默认
	return float(原)


static func 难度(模板: Dictionary) -> int:
	return _取整(模板, "difficulty", 1)


static func 要求战力(模板: Dictionary) -> int:
	return _取整(模板, "require_power", 100)


static func 要求数量(模板: Dictionary) -> int:
	return _取整(模板, "require_count", 1)


static func 耗时(模板: Dictionary) -> int:
	return _取整(模板, "duration_days", 3)


static func 标准报酬品阶(模板: Dictionary) -> String:
	return str(模板.get("reward_tier", "凡阶"))


static func 基础吸引力(模板: Dictionary) -> float:
	return clamp(_取浮(模板, "base_will", 0.5), 0.0, 1.0)


# ==================== 硬门槛 ====================

## 境界达标（用 Disciple.境界序 索引比较，禁字符串字典序）
static func 境界达标(弟子境界: String, 要求境界: String) -> bool:
	if 要求境界 == "":
		return true
	var 序: Array = Disciple.境界序
	var a: int = 序.find(弟子境界)
	var b: int = 序.find(要求境界)
	if a < 0 or b < 0:
		return false
	return a >= b


## 可否接取（硬门槛，不含意愿）。返回 "" 表示可接，否则为不可接原因。
static func 接取障碍(d: Object, 模板: Dictionary) -> String:
	if d == null or 模板.is_empty():
		return "无效"
	if not ("状态" in d):
		return "无效"
	var 状态: String = str(d.状态)
	if 状态 != "在宗":
		return "%s 非在宗（%s）" % [str(d.姓名), 状态]
	if ("受伤剩余" in d) and int(d.受伤剩余) > 0:
		return "%s 正在养伤" % str(d.姓名)
	var 弟子境界: String = str(d.境界) if ("境界" in d) else "练气"
	var 需境界: String = str(模板.get("require_realm", ""))
	if not 境界达标(弟子境界, 需境界):
		return "%s 境界不足（需 %s）" % [str(d.姓名), 需境界]
	return ""


# ==================== 接取意愿（核心）====================

## 弟子对某条任务的接取意愿（0 ~ 接取意愿上限）
##
## 这是「评分」不是「概率」：调用方先按分排序、再过阈值，最后才掷骰。
## 三段式设计让玩家可以通过加报酬把一条冷门任务变热——这就是发榜的博弈。
##
## 构成：基础吸引力 × 目标维度 × 能力匹配 × 报酬吸引力 × 性格 × 状态
static func 接取意愿(d: Object, 模板: Dictionary, 报酬品阶: String = "") -> float:
	if d == null or 模板.is_empty():
		return 0.0
	if 接取障碍(d, 模板) != "":
		return 0.0

	var 类型: String = str(模板.get("bounty_type", "collect"))
	var 目标: String = Goal.弟子目标(d)
	var 意愿: float = 基础吸引力(模板)

	# ---- 1. 目标维度：不同任务类型吃不同的八维 ----
	match 类型:
		"hunt":
			# 清剿 = 想出门历练 × 敢不敢冒险
			意愿 *= Goal.历练意愿(目标) * (0.4 + Goal.风险偏好(目标))
		"collect":
			# 征缴 = 想出门 × (私藏倾向高者偏爱，因为经手物资可截留)
			意愿 *= Goal.历练意愿(目标) * (0.5 + Goal.私藏倾向(目标))
		"diplomacy":
			意愿 *= Goal.社交意愿(目标)
		_:
			意愿 *= Goal.历练意愿(目标)

	# ---- 2. 能力匹配：战力 vs 要求战力 ----
	var 战力: int = int(d.战力) if ("战力" in d) else 0
	var 需战力: int = 要求战力(模板)
	var 比: float = float(战力) / float(max(需战力, 1))
	if 比 < 0.6:
		意愿 *= 0.20   # 明知打不过，不敢去
	elif 比 < 1.0:
		意愿 *= 0.60   # 勉强够格，底气不足
	elif 比 <= 3.0:
		意愿 *= 1.00   # 正合适
	else:
		意愿 *= 0.50   # 杀鸡焉用牛刀，不屑去

	# ---- 3. 报酬吸引力：玩家压档则冷清，加档则趋之若鹜 ----
	var 实给: String = 报酬品阶 if 报酬品阶 != "" else 标准报酬品阶(模板)
	意愿 *= float(报酬档差倍率.get(_报酬档差(实给, 标准报酬品阶(模板)), 1.0))

	# ---- 4. 性格修正 ----
	意愿 *= _性格倍率(d, 类型, 比, _报酬档差(实给, 标准报酬品阶(模板)))

	# ---- 5. 状态修正 ----
	if ("心境" in d) and int(d.心境) <= 30:
		意愿 *= 0.60   # 心灰意冷，无心外务
	if ("心魔值" in d) and int(d.心魔值) >= 60:
		意愿 *= 1.30   # 心魔躁动，反嗜冒险
	if ("道心" in d) and int(d.道心) >= 80:
		意愿 *= 1.10   # 道心通明，行事笃定

	return clamp(意愿, 0.0, 接取意愿上限)


## 玩家给定的报酬品阶相对标准档的档差（-2 ~ +2，越界则按最近端计）
static func _报酬档差(实给: String, 标准: String) -> int:
	var 序: Array = Item.品阶序
	var a: int = 序.find(实给)
	var b: int = 序.find(标准)
	if a < 0 or b < 0:
		return 0
	return clamp(a - b, -2, 2)


static func _性格倍率(d: Object, 类型: String, 战力比: float, 档差: int) -> float:
	var 性格: String = str(d.性格) if ("性格" in d) else ""
	var m: float = 1.0
	match 性格:
		"桀骜不羁":
			# 偏爱硬骨头，看不上跑腿
			m *= 1.30 if 类型 == "hunt" else 0.80
		"狂傲绝世":
			m *= 1.25 if 类型 == "hunt" else 0.75
		"谨慎多疑":
			# 没有十足把握不出手
			m *= 1.20 if 战力比 >= 1.5 else 0.50
		"贪心逐缘":
			# 一切向报酬看齐
			m *= 1.00 + 0.35 * float(max(档差, 0)) - 0.30 * float(max(-档差, 0))
		"锐意争先":
			m *= 1.20   # 抢着立功
		"杀伐果断":
			m *= 1.20 if 类型 == "hunt" else 0.90
		"豪迈仗义":
			m *= 1.10 if 类型 == "hunt" else 1.00
		"仁心济世":
			m *= 1.20 if 类型 == "collect" else 0.90
		"守礼尊师":
			m *= 1.10   # 宗门所命，欣然从之
		"沉稳守道":
			m *= 0.90
		"恬淡悟道":
			m *= 0.60   # 清静无为
		"孤僻清修":
			m *= 0.40   # 几乎不问世事
	return clamp(m, 0.10, 2.00)


# ==================== 请命（弟子主动申请）====================

## 主目标 → 偏好的任务类型
## 与 接取意愿() 用同一组公式（去掉任务侧 base_will），保证「偏好」与「意愿」自洽：
## 若用 if 优先级链，情劫（社交 1.60 全场最高）会因风险偏好 0.85 先命中而被误判为 hunt。
static func 偏好类型(目标名: String) -> String:
	var 征: float = Goal.历练意愿(目标名) * (0.5 + Goal.私藏倾向(目标名))
	var 剿: float = Goal.历练意愿(目标名) * (0.4 + Goal.风险偏好(目标名))
	var 访: float = Goal.社交意愿(目标名)
	if 访 >= 剿 and 访 >= 征:
		return "diplomacy"
	if 征 > 剿:
		return "collect"
	return "hunt"


## 弟子主动请命：据主目标挑一条自己够格且最合意的任务模板
## 返回 {模板ID, 任务名, 类型, 难度, 理由, 意愿}；无合意任务返回 {}
static func 请命建议(d: Object) -> Dictionary:
	if d == null:
		return {}
	if not ("状态" in d):
		return {}
	if str(d.状态) != "在宗":
		return {}
	if ("受伤剩余" in d) and int(d.受伤剩余) > 0:
		return {}
	_加载()
	var 目标: String = Goal.弟子目标(d)
	var 偏好: String = 偏好类型(目标)
	var 最佳: Dictionary = {}
	var 最佳分: float = 0.0
	for 模板 in _表:
		if 接取障碍(d, 模板) != "":
			continue
		var 分: float = 接取意愿(d, 模板)
		if str(模板.get("bounty_type", "")) == 偏好:
			分 *= 1.25   # 对口的目标加成
		if 分 > 最佳分:
			最佳分 = 分
			最佳 = 模板
	if 最佳.is_empty() or 最佳分 < 接取意愿阈值:
		return {}
	return {
		"模板ID": str(最佳.get("bounty_id", "")),
		"任务名": str(最佳.get("bounty_name", "")),
		"类型": str(最佳.get("bounty_type", "")),
		"难度": 难度(最佳),
		"意愿": 最佳分,
		"理由": _请命理据(目标, str(最佳.get("bounty_type", ""))),
	}


static func _请命理据(目标名: String, 类型: String) -> String:
	match 类型:
		"hunt":
			return "%s 之心未酬，愿请战功以证此身" % 目标名
		"collect":
			return "%s 需资粮在手，愿为宗门奔走筹措" % 目标名
		"diplomacy":
			return "%s 欲广结外缘，愿为使节通好四方" % 目标名
	return "%s 心有所求，愿效力于宗门" % 目标名


# ==================== 展示 ====================

## 任务摘要（供 UI / 纪事复用，避免各处自己拼字符串）
static func 摘要(模板: Dictionary, 报酬品阶: String = "") -> String:
	if 模板.is_empty():
		return ""
	var 报酬: String = 报酬品阶 if 报酬品阶 != "" else 标准报酬品阶(模板)
	return "%s【%s】难度%d 需%s·%d 酬%s 期%d日" % [
		类型名(str(模板.get("bounty_type", ""))),
		str(模板.get("bounty_name", "")),
		难度(模板),
		str(模板.get("require_realm", "")),
		要求数量(模板),
		报酬,
		耗时(模板),
	]

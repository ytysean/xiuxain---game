# contribution_shop.gd —— 宗门功勋堂数据层（S28）
#
# 定位：修好「交宗 = 白送」这个根本逻辑洞。
#   旧行为：弟子把宝物交给宗门 -> 贡献点进「宗门级」池子 -> 弟子本人得 0，
#           而「自留」零惩罚。交宗是严格劣势选项，只有玩家吃错了才会点。
#   新行为：交宗 -> 记入弟子「个人账户」七成、公中（宗门池）三成；
#           个人账户可在功勋堂兑换宗门库藏的任意物品（按类别×品阶定价），
#           也可兑换保命护身；弟子按月自主消费，玩家亦可代兑。
#
# 红线（与 goal.gd / sect_bounty.gd 一致）：
#   - 只产出「价格/意愿/评分」，绝不注入属性乘区，绝不碰 突破成功率修正()
#   - 不修改任何弟子字段（写字段由 game_state 的结算函数负责）
#   - 复用 goal_config 八维，不在本表重新标定目标倾向
#
# 定价锚：交宗基准价（凡10/灵20/宝40/王80/圣150/仙300/道600）
#   灵材 ×0.67（消耗品大宗） / 丹药 ×1.5（锚） / 法器 ×2 / 神兵 ×2.5 / 法宝 ×3
#   ——「交公七成、领用有折损」，宗门从中赚差价，交宗才不是等价交换。

class_name ContributionShop
extends RefCounted

const Disciple = preload("res://disciple.gd")
const Item = preload("res://item.gd")
const Goal = preload("res://goal.gd")
const DestinyDataLoader = preload("res://DestinyDataLoader.gd")

const 配置路径: String = "res://config/contribution_shop.csv"

# 交宗分成：个人账户七成，公中（宗门池）三成（公中至少 1，见 交宗()）
const 交宗个人占比: float = 0.70

# 保命护身：一条命，非库藏物品，价格沿用宗门兑换原校准价
const 保命护身价: int = 5000

# 弟子终究要留些余积，不会为一件物事掏空账户
const 自主兑换余额留存: float = 0.80
# 该品阶库存超过此数，弟子才敢自主兑换（玩家的收藏不被搬空，玩家代兑不受此限）
const 自主兑换库存下限: int = 3

const 兑换意愿上限: float = 0.85
# 意愿低于此值视为「看不上」——弟子宁可攒着
const 兑换意愿阈值: float = 0.25

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


static func 定价表() -> Array:
	_加载()
	return _表


# ==================== 定价 ====================

## Item.类别 混存中英文（"dan_yao" 与 "丹药" 皆有）→ 统一为中文口径
static func 归一类别(类别: String) -> String:
	if 类别 == "":
		return ""
	return Item.类别中文名.get(类别, 类别)


## 返回该物品兑换所需贡献点；-1 = 无定价（不入兑换清单）
static func 兑换价(类别: String, 品阶: String) -> int:
	_加载()
	var 中文: String = 归一类别(类别)
	for 行 in _表:
		if str(行.get("tier", "")) != 品阶:
			continue
		var v = 行.get(中文, null)
		if v == null:
			return -1
		var 价: int = int(v)
		if 价 <= 0:
			return -1
		return 价
	return -1


static func 保命价() -> int:
	return 保命护身价


static func 保命条目() -> Dictionary:
	var 项: Dictionary = {}
	项["索引"] = -1
	项["物品"] = null
	项["名称"] = "保命护身"
	项["类别"] = "护身"
	项["品阶"] = "无"
	项["价格"] = 保命护身价
	项["战力加成"] = 0
	项["库存"] = 999
	return 项


# ==================== 清单 ====================

## 扫描宗门库房生成可兑换清单（库房混存 Item 与 Dictionary → 逐个防御）
static func 可兑换清单(库房: Array) -> Array[Dictionary]:
	var 出: Array[Dictionary] = []
	if 库房 == null:
		return 出
	var 品阶计数: Dictionary = {}
	for i in range(库房.size()):
		var 它 = 库房[i]
		if not (它 is Item):
			continue
		var 阶: String = str(它.品阶)
		品阶计数[阶] = int(品阶计数.get(阶, 0)) + 1
	for i in range(库房.size()):
		var 物 = 库房[i]
		if not (物 is Item):
			continue
		var 价: int = 兑换价(物.类别, 物.品阶)
		if 价 <= 0:
			continue
		var 项: Dictionary = {}
		项["索引"] = i
		项["物品"] = 物
		项["名称"] = 物.名称
		项["类别"] = 归一类别(物.类别)
		项["品阶"] = 物.品阶
		项["价格"] = 价
		项["战力加成"] = 物.战力加成
		项["库存"] = int(品阶计数.get(str(物.品阶), 0))
		出.append(项)
	return 出


## 库藏清单 + 保命护身（保命置顶，UI 与自主兑换共用）
static func 完整清单(库房: Array) -> Array[Dictionary]:
	var 出: Array[Dictionary] = 可兑换清单(库房)
	出.insert(0, 保命条目())
	return 出


static func 摘要(条目: Dictionary) -> String:
	if 条目.is_empty():
		return ""
	if str(条目.get("类别", "")) == "护身":
		return "保命护身 · 危难替死 · %d 贡献" % 保命护身价
	return "%s · %s·%s · 道行+%d · %d 贡献" % [
		str(条目.get("名称", "")), str(条目.get("类别", "")), str(条目.get("品阶", "")),
		int(条目.get("战力加成", 0)), int(条目.get("价格", 0))]


# ==================== 意愿（§4.0 目标驱动） ====================

## 该物品换上后，相对现有同槽位装备的战力提升（不可穿戴记 0）
static func _装备提升(d: Disciple, 物) -> int:
	if not (物 is Item):
		return 0
	if not 物.可穿戴():
		return 0
	var 现 = d.装备.get(物.穿戴位) if d.装备 is Dictionary else null
	var 现值: int = 0
	if 现 is Item:
		现值 = 现.战力加成
	return 物.战力加成 - 现值


## 弟子对该条目的兑换意愿（0 = 不要；已含买不起判定）
static func 兑换意愿(d: Disciple, 条目: Dictionary) -> float:
	if d == null or 条目.is_empty():
		return 0.0
	if d.状态 != "在宗" or d.状态 == "陨落":
		return 0.0
	var 价: int = int(条目.get("价格", 0))
	if 价 <= 0 or d.贡献账户 < 价:
		return 0.0
	var 物 = 条目.get("物品", null)
	var 目标: String = Goal.弟子目标(d)
	var 类别: String = str(条目.get("类别", ""))
	var 意愿: float = 0.0
	if 类别 == "护身":
		if d.保命护身 > 0:
			意愿 = 0.15
		else:
			意愿 = (0.25 + Goal.风险偏好(目标)) * (1.0 + float(d.心魔值) / 100.0)
	elif 类别 == "法器" or 类别 == "神兵" or 类别 == "法宝":
		var 提升: int = _装备提升(d, 物)
		if 提升 <= 0:
			return 0.0
		var 比: float = clamp(float(提升) / float(max(1, d.战力)), 0.0, 1.0)
		意愿 = Goal.历练意愿(目标) * (0.35 + 比)
	elif 类别 == "丹药":
		# 基础值须让低私藏倾向的目标（如 修成大道 0.10）也过得了阈值，
		# 否则功勋永远花不出去，兑换出口形同虚设
		意愿 = 0.35 + Goal.私藏倾向(目标) * 0.30
	elif 类别 == "灵材":
		意愿 = 0.25 + Goal.私藏倾向(目标) * 0.40
	else:
		return 0.0
	if d.心境 <= 30:
		意愿 *= 0.60
	if d.心魔值 >= 60:
		意愿 *= 1.30
	if d.道心 >= 80:
		意愿 *= 0.90
	return clamp(意愿, 0.0, 兑换意愿上限)


## 弟子自主兑换候选：买得起、留得住余额、库存不被掏空、意愿过线
## 只取意愿最高的那一条（每月至多兑一件，避免一夜搬空库房）
static func 自主候选(d: Disciple, 库房: Array) -> Array[Dictionary]:
	var 出: Array[Dictionary] = []
	if d == null or d.状态 != "在宗":
		return 出
	# 刚需优先：身无保命又买得起 —— 一条命压过一切外物。
	# 若不显式前置，保命与顶级装备会同时顶格 0.85，靠「先到先得」把装备永远压在身后。
	if d.保命护身 <= 0 and d.贡献账户 >= 保命护身价:
		var 保: Dictionary = 保命条目()
		if 兑换意愿(d, 保) >= 兑换意愿阈值:
			出.append(保)
			return 出
	var 上限: int = int(float(d.贡献账户) * 自主兑换余额留存)
	var 全部: Array[Dictionary] = 完整清单(库房)
	var 最佳: Dictionary = {}
	var 最佳分: float = 0.0
	for 项 in 全部:
		var 价: int = int(项.get("价格", 0))
		if 价 <= 0 or 价 > 上限:
			continue
		if str(项.get("类别", "")) != "护身" and int(项.get("库存", 0)) <= 自主兑换库存下限:
			continue
		var 分: float = 兑换意愿(d, 项)
		if 分 < 兑换意愿阈值:
			continue
		if 分 > 最佳分:
			最佳分 = 分
			最佳 = 项
	if not 最佳.is_empty():
		出.append(最佳)
	return 出

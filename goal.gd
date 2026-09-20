extends RefCounted
class_name Goal

## 目标驱动行为模型（数据层，全静态，无副作用，零战斗触碰）
##
## 数据来源：config/goal_config.csv（9 类人生目标 × 7 维行为向量）
##
## 背景：此前「目标栈」全仓 9 处命中全是写入/存档/初始化，无一处读来做行为决策；
##       `主目标` 仅影响 `_弟子自动服用丹药` 的丹药选词一处，9 类目标中 `情劫` 0 命中，
##       `复仇/守护/证明自己/权力野心` 只能由世界事件被动写入、自身无触发源。
##       本层把「目标→行为」的映射抽为可配置数据，供推演/历练/突破/叛离各处接线。
##
## 设计要点：
##   1. 主键 = goal_name（中文），与 Disciple.主目标 存的字符串完全一致，
##      避免再引入一层 id 映射导致新旧档不一致。
##   2. 八维行为向量（对应规格「目标决定修炼策略/历练偏好/资源投入/社交倾向/
##      风险承担/对宗门贡献/叛离可能」）：
##        cultivate_eff     修炼投入   → 推演一月推进修炼乘区
##        expedition_will   历练意愿   → 方针自动派遣的参与概率
##        risk_appetite     风险偏好   → 方针自动派遣的战力比门槛
##        social_will       社交意愿   → 结道侣/自主社交概率
##        defect_rate       叛离倾向   → 叛离月概率基数
##        breakthrough_urge 突破激进度 → 瓶颈打磨门槛（越激进越提前冲关）
##        pill_keywords     丹药偏好   → 自主嗑药的选词顺序
##        hoard_tendency    私藏倾向   → 所得瞒报私藏的基准概率（弟子自主层）
##   3. 红线：cultivate_eff 最高 1.20（+20%），守住 §4.1「通用增益 ≤25%」；
##        **目标只改行为概率/时机，绝不注入属性乘区、绝不碰 突破成功率修正()**。

const 目标路径: String = "res://config/goal_config.csv"

## §4.1 通用增益红线：修炼投入封顶 +25%（当前表内最高 1.20，留有余量）
const 修炼增益上限: float = 1.25
## 叛离月概率硬上限：即便魔道 + 心魔爆表，单月也不超过 10%，避免宗门一夜空巢
const 月度叛离率上限: float = 0.10
## 叛离概率总系数：把 defect_rate（0.02~0.60）缩放到月度合理区间
const 叛离概率系数: float = 0.05
## 私藏率硬上限：弟子终究要向宗门交大部分产出，私藏是「截留」不是「断供」
const 私藏率上限: float = 0.85

static var _目标表: Array = []
static var _已加载: bool = false


# ============ 加载 ============

static func _加载() -> void:
	if _已加载:
		return
	_目标表 = DestinyDataLoader._read_csv(目标路径)
	_已加载 = true


## 供测试/热重载使用：清空缓存强制重新读表
static func 重载() -> void:
	_已加载 = false
	_目标表 = []
	_加载()


# ============ 查询 ============

## 全部目标配置（按 CSV 行序）
static func 全部目标() -> Array:
	_加载()
	return _目标表


## 目标名列表（UI/校验用）
static func 目标名列表() -> Array:
	_加载()
	var 名单: Array = []
	for r in _目标表:
		名单.append(str(r.get("goal_name", "")))
	return 名单


## 按中文目标名取配置；未收录返回空字典
static func 取配置(目标名: String) -> Dictionary:
	_加载()
	for r in _目标表:
		if str(r.get("goal_name", "")) == 目标名:
			return r
	return {}


## 该目标名是否在配置表内（未收录目标一律按「修成大道」兜底）
static func 有此目标(目标名: String) -> bool:
	return not 取配置(目标名).is_empty()


## 取数值列；缺失或非法时返回默认值
static func _取数(配置: Dictionary, 列: String, 默认: float) -> float:
	if 配置.is_empty() or not 配置.has(列):
		return 默认
	var v = 配置[列]
	if v == null:
		return 默认
	var f: float = float(v)
	if f != f:   # NaN 保护
		return 默认
	return f


## 取弟子当前主目标（缺字段/未收录 → 修成大道兜底）
static func 弟子目标(d: Object) -> String:
	if d == null:
		return "修成大道"
	var 名: String = str(d.主目标) if ("主目标" in d) else "修成大道"
	if 名 == "" or not 有此目标(名):
		return "修成大道"
	return 名


# ---------- 七维行为向量 ----------

## 修炼投入：推演一月推进修炼乘区（守 ≤25% 增益红线）
static func 修炼投入(目标名: String) -> float:
	return clamp(_取数(取配置(目标名), "cultivate_eff", 1.0), 0.5, 修炼增益上限)


## 历练意愿：方针自动派遣的参与概率（>1 亦可，作为概率调制后 clamp）
static func 历练意愿(目标名: String) -> float:
	return clamp(_取数(取配置(目标名), "expedition_will", 1.0), 0.0, 2.0)


## 风险偏好：越高越敢挑战推荐战力更高的关卡
static func 风险偏好(目标名: String) -> float:
	return clamp(_取数(取配置(目标名), "risk_appetite", 0.5), 0.0, 1.5)


## 社交意愿：结道侣/自主社交的概率调制
static func 社交意愿(目标名: String) -> float:
	return clamp(_取数(取配置(目标名), "social_will", 1.0), 0.0, 2.0)


## 叛离倾向：叛离月概率基数（0=不会叛离）
static func 叛离倾向(目标名: String) -> float:
	return clamp(_取数(取配置(目标名), "defect_rate", 0.0), 0.0, 1.0)


## 私藏倾向：历练/奇遇所得是上报宗门还是瞒报私藏的基准概率
static func 私藏倾向(目标名: String) -> float:
	return clamp(_取数(取配置(目标名), "hoard_tendency", 0.0), 0.0, 1.0)


## 突破激进度：>1 提前冲关（激进），<1 打磨更久才冲（保守）
static func 突破激进度(目标名: String) -> float:
	return clamp(_取数(取配置(目标名), "breakthrough_urge", 1.0), 0.3, 2.0)


## 瓶颈打磨门槛：激进度越高，所需打磨值越低 → 越早尝试突破
##   修成大道 1.00 → 门槛 1.00（与旧行为一致，零回归）
##   复仇     1.30 → 门槛 0.77（提前冲关，失败冷却为代价）
##   问道     0.60 → 门槛 1.67（厚积薄发）
static func 突破打磨门槛(目标名: String) -> float:
	var 激进: float = 突破激进度(目标名)
	if 激进 <= 0.0:
		return 1.0
	return 1.0 / 激进


## 丹药关键词（自主嗑药的选词顺序）
static func 丹药关键词(目标名: String) -> Array:
	var 配置: Dictionary = 取配置(目标名)
	if 配置.is_empty():
		return []
	var 原: String = str(配置.get("pill_keywords", ""))
	if 原 == "":
		return []
	return 原.split("|", false)


## 是否正道目标（魔道/避世/权力野心/复仇 记 0）
static func 是正道(目标名: String) -> bool:
	return int(_取数(取配置(目标名), "is_orthodox", 1)) == 1


## 目标描述（UI 展示）
static func 取描述(目标名: String) -> String:
	return str(取配置(目标名).get("description", ""))


## 行为摘要（UI 展示：把七维向量翻译成一句人话）
static func 行为摘要(目标名: String) -> String:
	if 取配置(目标名).is_empty():
		return ""
	var 段: Array = []
	段.append("修炼%s" % _偏词(修炼投入(目标名), 1.0, "勤勉", "懈怠"))
	段.append("历练%s" % _偏词(历练意愿(目标名), 1.0, "积极", "消极"))
	段.append("行事%s" % _偏词(风险偏好(目标名), 0.7, "冒进", "谨慎"))
	段.append("%s社交" % _偏词(社交意愿(目标名), 1.0, "热衷", "疏于"))
	if 叛离倾向(目标名) >= 0.30:
		段.append("易生反心")
	elif 叛离倾向(目标名) <= 0.05:
		段.append("忠贞不二")
	return "，".join(段)


## 三档定性词：高/中/低
static func _偏词(值: float, 基准: float, 高词: String, 低词: String) -> String:
	if 值 > 基准 * 1.08:
		return 高词
	if 值 < 基准 * 0.92:
		return 低词
	return "如常"


# ============ 弟子自主层：所得归属 ============

## 弟子私藏率：私藏倾向 × 心性调制，封顶 私藏率上限
##   心魔 ≥60 ×1.6、心境 ≤30 ×1.5、道心 ≤10 ×1.3
##   性格：贪心逐缘 ×1.5 / 桀骜不羁 ×1.3 / 杀伐果断·狂傲绝世 ×1.2 / 谨慎多疑 ×1.15
##         仁心济世·守礼尊师 ×0.5 / 沉稳守道 ×0.6 / 恬淡悟道·豪迈仗义 ×0.7
##   标定：修成大道+沉稳守道 ≈6%；魔道标准 70%；魔道+贪心逐缘+心魔爆表 → 触顶 85%
static func 弟子私藏率(d: Object) -> float:
	if d == null:
		return 0.0
	var 率: float = 私藏倾向(弟子目标(d))
	if 率 <= 0.0:
		return 0.0
	if ("心魔值" in d) and int(d.心魔值) >= 60:
		率 *= 1.6
	if ("心境" in d) and int(d.心境) <= 30:
		率 *= 1.5
	if ("道心" in d) and int(d.道心) <= 10:
		率 *= 1.3
	var 性格: String = str(d.性格) if ("性格" in d) else ""
	match 性格:
		"贪心逐缘":
			率 *= 1.5
		"桀骜不羁":
			率 *= 1.3
		"杀伐果断", "狂傲绝世":
			率 *= 1.2
		"谨慎多疑":
			率 *= 1.15
		"仁心济世", "守礼尊师":
			率 *= 0.5
		"沉稳守道":
			率 *= 0.6
		"恬淡悟道", "豪迈仗义":
			率 *= 0.7
	return clamp(率, 0.0, 私藏率上限)


# ============ 叛离判定 ============

## 目标驱动的月度叛离概率（0=不会叛离）
## 调制：心魔≥60 ×2、心境≤30 ×1.8、道心≤10 ×1.5、魔道 ×1.5、守护/修成大道 ×0.5
static func 叛离月概率(d: Object) -> float:
	if d == null:
		return 0.0
	var 目标名: String = 弟子目标(d)
	var 基础: float = 叛离倾向(目标名)
	if 基础 <= 0.0:
		return 0.0
	var 调制: float = 1.0
	if ("心魔值" in d) and int(d.心魔值) >= 60:
		调制 *= 2.0
	if ("心境" in d) and int(d.心境) <= 30:
		调制 *= 1.8
	if ("道心" in d) and int(d.道心) <= 10:
		调制 *= 1.5
	# S30 忠诚因子：欠俸/受罚致忠诚低落，二心渐生（与 心境/道心 同列）
	if ("忠诚" in d) and int(d.忠诚) <= 20:
		调制 *= 2.0
	elif ("忠诚" in d) and int(d.忠诚) <= 40:
		调制 *= 1.4
	if 目标名 == "魔道":
		调制 *= 1.5
	elif 目标名 in ["守护", "修成大道"]:
		调制 *= 0.5
	# §4.0 弟子自主层：私藏既久，二心渐生（有跑路的资本，也有见不得光的把柄）
	if ("私藏次数" in d) and int(d.私藏次数) >= 6:
		调制 *= 1.5
	elif ("私藏次数" in d) and int(d.私藏次数) >= 3:
		调制 *= 1.25
	# 查抄积怨：撕破脸的代价。1 次 ×1.6、2 次 ×2.2、3 次 ×2.8；每月自然 -1（见 _检查叛离）
	if ("查抄积怨" in d) and int(d.查抄积怨) > 0:
		调制 *= 1.0 + 0.6 * float(d.查抄积怨)
	return clamp(基础 * 调制 * 叛离概率系数, 0.0, 月度叛离率上限)


## 叛离倾向定性（UI 预警：让玩家的流失不是突发事件）
static func 叛离预警(d: Object) -> String:
	if d == null:
		return ""
	var p: float = 叛离月概率(d)
	if p <= 0.0:
		return "心志坚定"
	if p >= 0.05:
		return "去意已决"
	if p >= 0.02:
		return "心生去意"
	return "略有动摇"

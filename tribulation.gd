extends RefCounted
class_name Tribulation

## 天劫渡劫系统（数据层，全静态，无副作用）
##
## 数据来源：
##   config/tribulation_config.csv  天劫本体（§11.16 既有 19 列，裁决：代码侧绝不覆盖）
##   config/tribulation_item.csv    渡劫道具（§11.26，灵石直购，非宗门库房物品）
##   config/inner_demon.csv         心魔关（§11.26，按性格触发，渡劫前置关卡）
##
## 设计要点：
##   1. target_realm 是「渡此劫后达成的境界」在 Disciple.境界序 中的索引。
##      CSV 取值 4~9 恰好对应 化神/炼虚/合体/大乘/渡劫/仙阶（11 阶序下自洽），
##      即 元婴→化神 起 至 渡劫→仙阶 止，共 6 道天劫；练气→元婴 无天劫（凡境顺渡）。
##   2. 承伤模型：评分 = 承伤池 / (天劫强度 × (1 - 总抗性))
##      - 天劫强度 = 渡劫者当前境界基准战力 × 强度倍数 × 劫云随机波动
##      - 承伤池   = 弟子战力 × 状态修正（道心/心境/心魔/稳固期）
##      - 总抗性   = 自身 + 护阵 + 道具 + 护法，各受 CSV 分档封顶，总封顶 0.85
##   3. 强度倍数（本文件唯一校准表）的标定目标：
##      裸渡（无准备、标准状态）评分 ≈ 该天劫 success_threshold + 0.05 → 惊险过线；
##      完美渡劫（≥ perfect_threshold）必须投入外力（丹药/护阵/护法）方可达成。
##      之所以需要此表：CSV 的 base_total_damage 是设计稿量纲（300→30000，跨 100 倍），
##      与境界战力轴（6000→72000，仅 12 倍）不成比例，直接相除会导致
##      低阶天劫裸渡即完美、高阶天劫满准备仍必死。本表把二者桥接到同一量纲。

const 天劫路径: String = "res://config/tribulation_config.csv"
const 道具路径: String = "res://config/tribulation_item.csv"
const 心魔路径: String = "res://config/inner_demon.csv"

## 天劫强度倍数：按 target_realm 升序（4→9）依次分配给 t001→t006。
## 标定公式：倍数 = 标准承伤修正 / ((success_threshold + 0.05) × (1 - 标准自身抗性))
##   标准弟子口径：道心20 / 心境60 / 心魔0
##     → 承伤修正 = 1 + 20/200 + 60/300        = 1.30
##     → 自身抗性 = self_resist_base + 20/500 + 60/1000 = self_resist_base + 0.10
## 标定后裸渡评分（标准弟子、无准备、劫云1.0）精确 = success_threshold + 0.05：
##   0.650 / 0.600 / 0.550 / 0.500 / 0.450 / 0.400（沿序严格递减 → 越往后越险）
## 完美渡劫（≥ perfect_threshold）必须叠加外力（护阵 + 丹药 + 护法）；
## 最高天劫 t006 还需弟子道心/心境养成方可完美 —— 属终局追求。
const 强度倍数: Array = [2.857, 3.333, 3.939, 4.727, 5.778, 7.222]

## 总抗性硬上限：留 15% 必吃伤害，杜绝「无伤渡劫」破坏紧张感
const 抗性总上限: float = 0.85
## 劫云强度随机波动区间
const 劫云下限: float = 0.85
const 劫云上限: float = 1.20
## 心魔关未渡过 → 承伤大幅削弱（走火入魔）
const 心魔失败承伤系数: float = 0.70

static var _天劫表: Array = []
static var _道具表: Array = []
static var _心魔表: Array = []
static var _已加载: bool = false


# ============ 加载 ============

static func _加载() -> void:
	if _已加载:
		return
	_天劫表 = DestinyDataLoader._read_csv(天劫路径)
	_道具表 = DestinyDataLoader._read_csv(道具路径)
	_心魔表 = DestinyDataLoader._read_csv(心魔路径)
	# 按 target_realm 升序排列，供 强度倍数 顺序分配（CSV 行序不保证）
	_天劫表.sort_custom(func(a, b): return int(a.get("target_realm", "0")) < int(b.get("target_realm", "0")))
	_已加载 = true


## 供测试/热重载使用：清空缓存强制重新读表
static func 重载() -> void:
	_已加载 = false
	_天劫表 = []
	_道具表 = []
	_心魔表 = []
	_加载()


# ============ 查询 ============

## 下一境界（顶阶返回空串）
static func 下一境(境: String) -> String:
	var i: int = Disciple.境界序.find(境)
	if i < 0 or i >= Disciple.境界序.size() - 1:
		return ""
	return Disciple.境界序[i + 1]


## 取某目标境界的天劫配置；无天劫返回空字典
static func 取天劫配置(目标境: String) -> Dictionary:
	_加载()
	var idx: int = Disciple.境界序.find(目标境)
	if idx < 0:
		return {}
	for r in _天劫表:
		if int(r.get("target_realm", "-1")) == idx:
			return r
	return {}


## 突破到目标境是否需要渡天劫
static func 需渡劫(目标境: String) -> bool:
	return not 取天劫配置(目标境).is_empty()


## 全部天劫配置（按 target_realm 升序）
static func 全部天劫() -> Array:
	_加载()
	return _天劫表.duplicate(true)


## 全部渡劫道具
static func 全部道具() -> Array:
	_加载()
	return _道具表.duplicate(true)


## 按 item_id 取渡劫道具
static func 取道具(item_id: String) -> Dictionary:
	_加载()
	for r in _道具表:
		if str(r.get("item_id", "")) == item_id:
			return r
	return {}


# ============ 强度与抗性 ============

## 目标境对应天劫的强度倍数（未收录则回落 1.0，视为无额外强度）
static func 取强度倍数(目标境: String) -> float:
	_加载()
	var idx: int = Disciple.境界序.find(目标境)
	if idx < 0:
		return 1.0
	var k: int = 0
	for r in _天劫表:
		if int(r.get("target_realm", "-1")) == idx:
			if k < 强度倍数.size():
				return float(强度倍数[k])
			return 1.0
		k += 1
	return 1.0


## 弟子自身抗性增量（在 CSV self_resist_base 之上）；道心/心境为正，心魔为负
static func 自身抗性加成(d) -> float:
	var r: float = 0.0
	r += float(d.道心) / 500.0
	r += float(d.心境) / 1000.0
	r -= float(d.心魔值) / 500.0
	return clamp(r, -0.20, 0.25)


## 承伤池状态修正：道心/心境加成，心魔削减，稳固期内削弱
static func 状态修正(d) -> float:
	var m: float = 1.0 + float(d.道心) / 200.0 + float(d.心境) / 300.0 - float(d.心魔值) / 300.0
	if float(d.稳固期剩余) > 0.0:
		m *= 0.9
	return clamp(m, 0.30, 2.0)


# ============ 心魔关 ============

## 按性格抽取心魔（渡劫前置关卡）；未命中返回空字典。
## 命中判定：对「性格匹配」的行按 trigger_prob 依次累加判定（可多行并存）。
static func 抽取心魔(性格: String, 随机值: float = -1.0) -> Dictionary:
	_加载()
	var 池: Array = []
	for r in _心魔表:
		if str(r.get("match_personality", "")) == 性格:
			池.append(r)
	if 池.is_empty():
		return {}
	var 总: float = 0.0
	for r in 池:
		总 += float(r.get("trigger_prob", "0"))
	if 总 <= 0.0:
		return {}
	var x: float = randf() * 总 if 随机值 < 0.0 else 随机值 * 总
	for r in 池:
		var p: float = float(r.get("trigger_prob", "0"))
		if x < p:
			return r
		x -= p
	return 池[池.size() - 1]


## 心魔关二选一结算；选项 = 1 或 2
static func 结算心魔选项(心魔: Dictionary, 选项: int, 随机值: float = -1.0) -> Dictionary:
	if 心魔.is_empty():
		return {}
	var 率: float = float(心魔.get("opt%d_success_rate" % 选项, "0"))
	var 成: bool = (randf() if 随机值 < 0.0 else 随机值) < 率
	var 奖惩文本: String = str(心魔.get("opt%d_%s" % [选项, "success_reward" if 成 else "fail_punish"], ""))
	return {
		"成功": 成,
		"选项": 选项,
		"描述": str(心魔.get("opt%d_desc" % 选项, "")),
		"奖惩": _解析奖惩(奖惩文本),
		"奖惩原文": 奖惩文本,
	}


## 解析「道心+5」「损失灵石100」「走火入魔风险+8」「无」等中文奖惩串
## 返回 {} 或 {"维度":..., "值":...} 或 {"特殊": 文本}
static func _解析奖惩(文本: String) -> Dictionary:
	var t: String = 文本.strip_edges()
	if t == "" or t == "无":
		return {}
	var re: RegEx = RegEx.new()
	re.compile("([+-]?\\d+)")
	var m: RegExMatch = re.search(t)
	var v: int = 0
	if m:
		v = int(m.get_string(1))
	# 语义前缀：损失 / 风险 一律按负向处理
	if t.begins_with("损失") or t.find("风险") >= 0:
		v = -abs(v)
	# 注意顺序：走火入魔 必须排在 心魔 之前，否则被误判为心魔维度
	var 维度表: Array = ["走火入魔", "道心", "心魔", "心境", "修为", "灵石", "仇家", "忠诚", "气血"]
	for k in 维度表:
		if t.find(k) >= 0:
			return {"维度": k, "值": v}
	return {"特殊": t}


# ============ 渡劫结算（纯计算，不修改弟子/不扣资源） ============

## 计算一次渡劫的完整结果。
## 准备（可全缺省）字段：
##   "护阵抗性": float  护山大阵提供的抗性（受 array_resist_max 封顶）
##   "道具减伤": float  渡劫道具合计减伤（受 item_resist_max 封顶）
##   "护法抗性": float  长老护法提供的抗性（受 guard_resist_max 封顶）
##   "承伤倍率": float  额外承伤倍率（如护身法宝），默认 1.0
##   "心魔": Dictionary 已结算的心魔结果（影响承伤，缺省则现场抽取）
##   "劫云": float      劫云强度系数（缺省随机 0.85~1.15；测试可注入）

## 修真味·因果天劫倍率：杀业缠身天劫加难，功德圆满天降甘霖
## 业力：每 10 点 +1% 天劫强度（帽 +30%）；功德：每 10 点 -1%（帽 -20%）
## 安全性：业力=功德=0 → 返回 1.0（原数学完全不变，既有渡劫标定不受影响）
static func 因果天劫倍率(d) -> float:
	var 业力值: int = 0
	var 功德值: int = 0
	if d.get("业力") != null:
		业力值 = int(d.get("业力"))
	if d.get("功德") != null:
		功德值 = int(d.get("功德"))
	var 业力加成: float = clamp(float(业力值) * 0.001, 0.0, 0.30)
	var 功德减免: float = clamp(float(功德值) * 0.001, 0.0, 0.20)
	return clamp(1.0 + 业力加成 - 功德减免, 0.80, 1.30)

static func 计算渡劫结果(d, 准备: Dictionary = {}) -> Dictionary:
	_加载()
	var 目标境: String = 下一境(d.境界)
	var cfg: Dictionary = 取天劫配置(目标境)
	if cfg.is_empty():
		return {"需渡劫": false, "目标境": 目标境, "结果": "无天劫"}

	# --- 心魔关（先渡心魔，再渡天雷）---
	var 心魔结: Dictionary = 准备.get("心魔", {})
	if 心魔结.is_empty():
		var 心魔: Dictionary = 抽取心魔(d.性格)
		if not 心魔.is_empty():
			心魔结 = 结算心魔选项(心魔, 1 if randf() < 0.5 else 2)
			心魔结["心魔名"] = str(心魔.get("demon_name", ""))
	# 心魔未渡过 → 承伤大幅削弱（走火入魔）
	var 心魔削弱: float = 1.0
	if not 心魔结.is_empty() and not bool(心魔结.get("成功", true)):
		心魔削弱 = 心魔失败承伤系数

	# --- 天劫强度 ---
	var 基准战力: float = float(Disciple.境界表.get(d.境界, {}).get("战力", 100))
	var 劫云: float = float(准备.get("劫云", randf_range(劫云下限, 劫云上限)))
	var 强度: float = 基准战力 * 取强度倍数(目标境) * 劫云
	# 修真味·因果业力：杀业缠身天劫加难，功德圆满天降甘霖（业力=功德=0 → ×1.0，原数学不变）
	var 因果倍率: float = 因果天劫倍率(d)
	强度 *= 因果倍率
	# 业力不灭：历史杀业在渡劫时翻账（不额外加难，只入叙事，避免数值失控）
	var 旧业文本: String = Karma.翻旧账(d)

	# --- 抗性 ---
	var 自身: float = float(cfg.get("self_resist_base", "0")) + 自身抗性加成(d)
	var 护阵: float = min(float(准备.get("护阵抗性", 0.0)), float(cfg.get("array_resist_max", "0")))
	var 道具: float = min(float(准备.get("道具减伤", 0.0)), float(cfg.get("item_resist_max", "0")))
	var 护法: float = min(float(准备.get("护法抗性", 0.0)), float(cfg.get("guard_resist_max", "0")))
	var 总抗: float = min(自身 + 护阵 + 道具 + 护法, 抗性总上限)

	# --- 承伤池 ---
	var 承伤: float = float(d.战力) * 状态修正(d) * float(准备.get("承伤倍率", 1.0)) * 心魔削弱

	# --- 评分与判定 ---
	var 评分: float = 承伤 / max(1.0, 强度 * (1.0 - 总抗))
	var 完美阈: float = float(cfg.get("perfect_threshold", "1.0"))
	var 成功阈: float = float(cfg.get("success_threshold", "0.5"))
	var 死亡阈: float = float(cfg.get("death_threshold", "0.2"))
	var 结果: String = "陨落"
	if 评分 >= 完美阈:
		结果 = "完美"
	elif 评分 >= 成功阈:
		结果 = "成功"
	elif 评分 >= 死亡阈:
		结果 = "重伤"

	return {
		"需渡劫": true,
		"目标境": 目标境,
		"天劫ID": str(cfg.get("tribulation_id", "")),
		"天劫名": str(cfg.get("tribulation_name", "")),
		"雷数": int(cfg.get("thunder_count", "0")),
		"结果": 结果,
		"评分": 评分,
		"天劫强度": 强度,
		"承伤池": 承伤,
		"劫云": 劫云,
		"抗性": {"自身": 自身, "护阵": 护阵, "道具": 道具, "护法": 护法, "总": 总抗},
		"阈值": {"完美": 完美阈, "成功": 成功阈, "陨落": 死亡阈},
		"跌落层数": int(cfg.get("fail_realm_drop", "1")),
		"受伤天数": int(cfg.get("injury_days", "0")),
		"声望": int(cfg.get("reputation_bonus", "0")),
		"完美奖励": str(cfg.get("perfect_buff_id", "")),
		"心魔": 心魔结,
		"因果倍率": 因果倍率, "旧业翻账": (旧业文本 != ""), "旧业文本": 旧业文本,
	}


## 汇总若干渡劫道具的抗性贡献（供 UI 预览与实际结算共用）
## 道具ID列表 → {"成功率加成":float, "减伤":float, "灵石":int, "明细":Array}
static func 汇总道具(道具ID列表: Array) -> Dictionary:
	_加载()
	var 率: float = 0.0
	var 减: float = 0.0
	var 石: int = 0
	var 明细: Array = []
	for pid in 道具ID列表:
		var it: Dictionary = 取道具(str(pid))
		if it.is_empty():
			continue
		率 += float(it.get("success_rate_bonus", "0"))
		减 += float(it.get("damage_reduce", "0"))
		石 += int(it.get("consume_cost", "0"))
		明细.append({
			"item_id": str(it.get("item_id", "")),
			"名称": str(it.get("item_name", "")),
			"类型": str(it.get("item_type", "")),
			"灵石": int(it.get("consume_cost", "0")),
		})
	return {"成功率加成": 率, "减伤": 减, "灵石": 石, "明细": 明细}


# ============ 渡劫系统增强层（P0-2：从"能算"到"有沉浸感"）============
# 设计原则：
# 1. 符合修真世界观：雷劫过程/心魔考验/天地异象
# 2. 符合玩家操作习惯：叙事清晰，结果明确
# 3. 不止能玩而是好玩：过程沉浸感/突发事件/成就记录

# ===== 渡劫过程叙事生成 =====
# 根据渡劫结果生成详细的过程描述（逐道雷+心魔+结局）
static func 生成渡劫叙事(结果: Dictionary) -> Array:
	var 叙事: Array = []
	if 结果.is_empty() or not bool(结果.get("需渡劫", false)):
		return 叙事
	var 天劫名: String = str(结果.get("天劫名", "天劫"))
	var 雷数: int = int(结果.get("雷数", 0))
	var 结: String = str(结果.get("结果", "成功"))
	var 评分: float = float(结果.get("评分", 0.0))
	var 劫云: float = float(结果.get("劫云", 1.0))
	var 抗: Dictionary = 结果.get("抗性", {})
	var 总抗: float = float(抗.get("总", 0.0))
	var 心魔: Dictionary = 结果.get("心魔", {})

	# 开篇
	叙事.append("【劫云汇聚】天地色变，%s劫云于天际凝聚，威压笼罩四方。" % 天劫名)
	# 修真味·因果 L4：不给倍率数字，只给天象
	var 因果倍率: float = float(结果.get("因果倍率", 1.0))
	if 因果倍率 != 1.0:
		叙事.append("  " + Karma.天象描述(因果倍率))
	if bool(结果.get("旧业翻账", false)):
		叙事.append("  " + str(结果.get("旧业文本", "")))
	if 劫云 >= 1.1:
		叙事.append("  劫云异常浓厚，天雷之力远超寻常，此劫凶险万分！")
	elif 劫云 <= 0.9:
		叙事.append("  劫云略显稀薄，似是天道留情，此劫或有转机。")

	# 心魔关
	if not 心魔.is_empty():
		var 心魔名: String = str(心魔.get("心魔名", "心魔"))
		var 心魔成功: bool = bool(心魔.get("成功", true))
		叙事.append("")
		叙事.append("【心魔考验】心魔%s趁虚而入，于识海中显现幻象。" % 心魔名)
		if 心魔成功:
			叙事.append("  弟子道心坚定，识破幻象，心魔退散，道心更进一层！")
		else:
			叙事.append("  弟子心神失守，被心魔所乘，承伤之力大减……")
		var 奖惩原文: String = str(心魔.get("奖惩原文", ""))
		if 奖惩原文 != "" and 奖惩原文 != "无":
			叙事.append("  心魔影响：%s" % 奖惩原文)

	# 逐道天雷
	叙事.append("")
	叙事.append("【天雷降临】%d道天雷依次劈落，弟子运转灵力硬抗。" % 雷数)
	var 抗描述: String = ""
	if 总抗 >= 0.6:
		抗描述 = "凭借深厚修为与外力护持，天雷之力被大幅削弱"
	elif 总抗 >= 0.3:
		抗描述 = "虽有护持，但天雷之力仍不容小觑"
	else:
		抗描述 = "护持微薄，天雷之力几乎毫无阻滞"
	叙事.append("  %s。" % 抗描述)

	# 雷劫过程细节
	if 雷数 >= 9:
		叙事.append("  前六道天雷尚可支撑，第七道起天雷威力陡增，弟子灵力消耗剧烈。")
		叙事.append("  第八、九道天雷如同灭世之威，弟子咬牙苦撑……")
	elif 雷数 >= 6:
		叙事.append("  前三道天雷势如破竹，中间三道天雷威力渐增，弟子渐感不支。")
		叙事.append("  最后几道天雷更是凶险万分……")
	else:
		叙事.append("  天雷一道接一道劈落，弟子以肉身硬抗，灵力飞速消耗。")

	# 结局
	叙事.append("")
	match 结:
		"完美":
			叙事.append("【完美渡劫】最后一道天雷劈落，弟子不仅毫发无伤，更借天雷之力淬炼肉身！")
			叙事.append("  天地异象显现，似是天道认可，此子前途不可限量！")
			叙事.append("  渡劫评分：%.3f（完美）" % 评分)
		"成功":
			叙事.append("【渡劫成功】最后一道天雷劈落，弟子虽有损伤，但终究撑了过来！")
			叙事.append("  劫云散去，天地灵气涌入体内，境界突破！")
			叙事.append("  渡劫评分：%.3f（成功）" % 评分)
		"重伤":
			叙事.append("【渡劫重伤】天雷之力太过强横，弟子未能完全抵挡，身受重伤！")
			叙事.append("  境界跌落，需好生休养，待日后再渡此劫。")
			叙事.append("  渡劫评分：%.3f（重伤）" % 评分)
		_:
			叙事.append("【形神俱灭】最后一道天雷劈落，弟子再也支撑不住……")
			叙事.append("  形神俱灭，陨落于天劫之下，道消身殒。")
			叙事.append("  渡劫评分：%.3f（陨落）" % 评分)

	return 叙事

# ===== 渡劫中突发事件系统 =====
# 渡劫过程中随机触发突发事件，玩家可做选择（增加沉浸感和策略性）
const 渡劫突发事件池: Array = [
	{
		"ID": "雷劫变异",
		"名称": "雷劫变异",
		"描述": "天劫之中忽然夹杂着紫色神雷，威力远超寻常天雷！",
		"触发条件": "评分 >= 0.5",
		"选项": [
			{"名称": "硬抗神雷", "描述": "运转全部灵力，硬抗这道变异神雷。", "成功率": 0.4, "成功效果": {"承伤倍率": 1.3, "道心": 5}, "失败效果": {"承伤倍率": 0.6, "状态": "重伤"}},
			{"名称": "闪避卸力", "描述": "施展身法，闪避神雷主力，以余波淬炼肉身。", "成功率": 0.7, "成功效果": {"承伤倍率": 1.1}, "失败效果": {"承伤倍率": 0.8}}
		]
	},
	{
		"ID": "心魔突袭",
		"名称": "心魔突袭",
		"描述": "渡劫关键时刻，心魔忽然暴涨，幻象丛生，干扰心神！",
		"触发条件": "心魔值 > 10",
		"选项": [
			{"名称": "镇压心魔", "描述": "集中精神，以道心镇压心魔。", "成功率": 0.5, "成功效果": {"道心": 3, "心魔": -5}, "失败效果": {"承伤倍率": 0.7, "心魔": 10}},
			{"名称": "炼化心魔", "描述": "不镇压，反而将心魔之力炼化为己用。", "成功率": 0.3, "成功效果": {"承伤倍率": 1.5, "道心": 5}, "失败效果": {"承伤倍率": 0.5, "状态": "走火入魔"}}
		]
	},
	{
		"ID": "天地异象",
		"名称": "天地异象",
		"描述": "渡劫之时，天际忽然显现七彩祥云，似是天道降下福泽！",
		"触发条件": "道心 >= 30",
		"选项": [
			{"名称": "接引福泽", "描述": "盘膝而坐，接引天地福泽。", "成功率": 0.9, "成功效果": {"承伤倍率": 1.2, "道心": 3, "心境": 5}, "失败效果": {}},
			{"名称": "以福泽抗雷", "描述": "将福泽之力转化为护盾，抵挡天雷。", "成功率": 0.8, "成功效果": {"承伤倍率": 1.4}, "失败效果": {"承伤倍率": 1.0}}
		]
	},
	{
		"ID": "灵兽护主",
		"名称": "灵兽护主",
		"描述": "渡劫关键时刻，绑定灵兽忽然冲出，以自身之力替主人挡下一道天雷！",
		"触发条件": "有绑定灵兽",
		"选项": [
			{"名称": "接受护主", "描述": "让灵兽替自己挡下这道天雷。", "成功率": 1.0, "成功效果": {"承伤倍率": 1.3, "灵兽受伤": true}, "失败效果": {}},
			{"名称": "拒绝护主", "描述": "不愿灵兽受伤，喝退灵兽，独自硬抗。", "成功率": 0.6, "成功效果": {"道心": 5, "灵兽好感": 10}, "失败效果": {"承伤倍率": 0.8}}
		]
	}
]

# 检查是否触发突发事件
static func 检查渡劫突发事件(d, 结果: Dictionary) -> Dictionary:
	var 评分: float = float(结果.get("评分", 0.0))
	var 道心: int = int(d.道心) if d != null else 0
	var 心魔值: int = int(d.心魔值) if d != null else 0
	var 有灵兽: bool = (d != null and (d.主宠灵兽 != null or d.副宠灵兽 != null))
	for 事件 in 渡劫突发事件池:
		var 条件: String = str(事件.get("触发条件", ""))
		var 触发: bool = false
		match 条件:
			"评分 >= 0.5":
				触发 = 评分 >= 0.5 and randf() < 0.15
			"心魔值 > 10":
				触发 = 心魔值 > 10 and randf() < 0.2
			"道心 >= 30":
				触发 = 道心 >= 30 and randf() < 0.1
			"有绑定灵兽":
				触发 = 有灵兽 and randf() < 0.15
		if 触发:
			return 事件.duplicate()
	return {}

# ===== 渡劫记录系统 =====
# 记录每次渡劫的结果，供成就和历史查询
static var 渡劫记录列表: Array = []

# 添加渡劫记录
static func 添加渡劫记录(弟子ID: int, 弟子名: String, 结果: Dictionary) -> void:
	var 记录: Dictionary = {
		"弟子ID": 弟子ID,
		"弟子名": 弟子名,
		"天劫名": str(结果.get("天劫名", "")),
		"目标境": str(结果.get("目标境", "")),
		"结果": str(结果.get("结果", "")),
		"评分": float(结果.get("评分", 0.0)),
		"劫云": float(结果.get("劫云", 1.0)),
		"时间": (int(Game.get("累计游戏日")) if Game != null else 0),
		"叙事": 生成渡劫叙事(结果)
	}
	# 倒序插入（最新的在最前），最多保留100条
	渡劫记录列表.insert(0, 记录)
	if 渡劫记录列表.size() > 100:
		渡劫记录列表.resize(100)

# 获取弟子渡劫记录
static func 获取弟子渡劫记录(弟子ID: int) -> Array:
	var 结果: Array = []
	for 记录 in 渡劫记录列表:
		if int(记录.get("弟子ID", -1)) == 弟子ID:
			结果.append(记录)
	return 结果

# 获取全部渡劫记录
static func 获取全部渡劫记录() -> Array:
	return 渡劫记录列表.duplicate()

# 统计渡劫成就
static func 统计渡劫成就() -> Dictionary:
	var 统计: Dictionary = {
		"总渡劫次数": 渡劫记录列表.size(),
		"成功次数": 0,
		"完美次数": 0,
		"重伤次数": 0,
		"陨落次数": 0,
		"最高评分": 0.0
	}
	for 记录 in 渡劫记录列表:
		var 结: String = str(记录.get("结果", ""))
		var 评: float = float(记录.get("评分", 0.0))
		if 结 == "完美":
			统计["完美次数"] = int(统计["完美次数"]) + 1
			统计["成功次数"] = int(统计["成功次数"]) + 1
		elif 结 == "成功":
			统计["成功次数"] = int(统计["成功次数"]) + 1
		elif 结 == "重伤":
			统计["重伤次数"] = int(统计["重伤次数"]) + 1
		else:
			统计["陨落次数"] = int(统计["陨落次数"]) + 1
		if 评 > float(统计["最高评分"]):
			统计["最高评分"] = 评
	return 统计

# 获取渡劫统计（统一接口名，与历练/炼丹一致）
static func 获取渡劫统计() -> Dictionary:
	return 统计渡劫成就()

# 清除渡劫记录
static func 清除渡劫记录() -> void:
	渡劫记录列表.clear()

# ===== 存档系统（P0-2完善：保存渡劫记录，防止重新加载后丢失）=====
static func to_dict() -> Dictionary:
	return {
		"渡劫记录列表": 渡劫记录列表.duplicate(),
	}

static func from_dict(d: Dictionary) -> void:
	渡劫记录列表 = d.get("渡劫记录列表", [])
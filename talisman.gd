extends Node

## 符箓系统数据层（Autoload单例，镜像 forge.gd 的 ForgeSystem）
## 符箓配置由 game_state 从 config/item_talisman.csv 读入后传入（CSV 为唯一真源，杜绝手抄）

# grade(品) -> 品阶序词表归一（凡品→凡阶，避免 Item.算战力 的 基础战力表[品阶] 索引越界崩溃）
const 品阶归一表 := {
	"凡品": "凡阶", "灵品": "灵阶", "宝品": "宝阶", "王品": "王阶",
	"圣品": "圣阶", "仙品": "仙阶", "道品": "道阶"
}

## 解析材料串 "符纸×2,灵墨×4" -> [{名, 数量}]（支持 × 与 * 两种分隔）
static func 解析材料(串: String) -> Array:
	var out: Array = []
	for seg in str(串).split(","):
		seg = seg.strip_edges()
		if seg == "":
			continue
		var parts: Array = seg.split("×") if seg.contains("×") else seg.split("*")
		var 名: String = str(parts[0]).strip_edges()
		var 数: int = 1
		if parts.size() > 1:
			数 = int(str(parts[1]).strip_edges())
		if 名 != "":
			out.append({"名": 名, "数量": 数})
	return out

## 符箓 grade 归一为 Item.品阶 词表
static func 归一品阶(品: String) -> String:
	return 品阶归一表.get(str(品).strip_edges(), "凡阶")

## ============ S45-6 绘符经验/等级（委托 game_state 读 CSV，禁手抄常量）============
## 按经验取绘符等级
static func 获取绘符等级(经验值: int) -> int:
	if Game != null and Game.has_method("绘符等级按经验"):
		return int(Game.绘符等级按经验(经验值))
	return 1

## 按经验取绘符加成 {等级, 成功率加成, 高品质加成}
static func 获取绘符加成(经验值: int) -> Dictionary:
	if Game != null and Game.has_method("绘符加成按经验"):
		return Game.绘符加成按经验(经验值) as Dictionary
	return {"等级": 1, "成功率加成": 0.0, "高品质加成": 0.0}

## 计算单次绘符经验（品阶 + 成功与否；失败得一半）
static func 计算绘符经验(品阶: String, 成功: bool) -> int:
	if Game != null and Game.has_method("计算绘符经验"):
		return int(Game.计算绘符经验(品阶, 成功))
	return 10 if 成功 else 5

## 执行绘符（支持符师心境影响；符纹/S45-4、符词条/S45-5、绘符经验等级/S45-6 后续接入）
## 返回：{成功, 产出(Item/null), 消耗, 原因}
static func 炼符(cfg: Dictionary, 背包: Array, 符堂等级: int = 1, 符师弟子 = null, 因子: Variant = null, 产出品级: String = "中品", 产出数量: int = 1) -> Dictionary:
	if cfg.is_empty():
		return {"成功": false, "产出": null, "消耗": [], "原因": "符箓配置为空"}
	var 因子2: Dictionary = {}
	if 因子 != null and typeof(因子) == TYPE_DICTIONARY:
		因子2 = 因子 as Dictionary
	# 材料检查（从 宗门库房 按物品名真实消耗，镜像炼器；符纸/朱砂等来源见 S45-7/S45-8）
	# S45-4 符纸省材率：材料需求 × (1-省材率)，最少 1（经 因子 由 执行炼符 传入，空纸=0 零影响）
	var 省材: float = clamp(float(因子2.get("省材率", 0.0)), 0.0, 0.5)
	var 材料列表: Array = 解析材料(str(cfg.get("craft_material", "")))
	for mat in 材料列表:
		var 需求名: String = str(mat["名"])
		var 需求数: int = max(1, int(ceil(float(mat["数量"]) * (1.0 - 省材))))
		var 拥有数: int = 0
		for item in 背包:
			if item != null and typeof(item) == TYPE_OBJECT and "名称" in item and str(item.名称) == 需求名:
				拥有数 += 1
		if 拥有数 < 需求数:
			return {"成功": false, "产出": null, "消耗": [], "原因": "材料不足：%s（%d/%d）" % [需求名, 拥有数, 需求数], "缺失": 需求名}
	# 成功率：基础(base_rate) + 符堂等级(+2%/级) + 符箓因子网络成率 + 符师心境
	# 注：因子.成率 为分数（0.18=18%，镜像 forge 因子 CSV 单位），×100 转真实百分比；
	#      forge.gd 炼器 直接加分数（0.03→+0.03%）属潜在单位 bug，符箓侧按设计意图修正为真实生效。
	var 基础: float = float(cfg.get("base_rate", 60))
	var 率: float = 基础 + float(max(0, 符堂等级 - 1)) * 2.0 + float(因子2.get("成率", 0.0)) * 100.0
	if 符师弟子 != null and typeof(符师弟子) == TYPE_OBJECT:
		var 心境: String = ""
		if "心境" in 符师弟子:
			心境 = str(符师弟子.心境)
		if 心境 == "专注":
			率 += 5.0
		elif 心境 == "浮躁":
			率 -= 5.0
	率 = clampf(率, 5.0, 95.0)
	# 消耗材料
	var 消耗列表: Array = []
	for mat in 材料列表:
		var 需求名: String = str(mat["名"])
		var 需求数: int = max(1, int(ceil(float(mat["数量"]) * (1.0 - 省材))))
		var 已消耗: int = 0
		for i in range(背包.size() - 1, -1, -1):
			if 已消耗 >= 需求数:
				break
			var item = 背包[i]
			if item != null and typeof(item) == TYPE_OBJECT and "名称" in item and str(item.名称) == 需求名:
				消耗列表.append(item)
				背包.remove_at(i)
				已消耗 += 1
	# 成功率判定
	if randf() * 100.0 > 率:
		return {"成功": false, "产出": null, "消耗": 消耗列表, "原因": "绘符失败，材料已消耗（成功率%.0f%%）" % 率,
			"获得经验": 计算绘符经验(归一品阶(str(cfg.get("grade", "凡品"))), false)}
	# 成功：产出 产出数量 张符箓，全部为 产出品级（S45-3 品级×数量产出模型）
	var 产列表: Array = []
	for _i in range(max(1, 产出数量)):
		var it = Item.new()
		it.类别 = "fu_lu"
		it.品阶 = 归一品阶(str(cfg.get("grade", "凡品")))
		it.品级 = 产出品级
		it.符类型 = str(cfg.get("talisman_type", ""))
		it.名称 = str(cfg.get("talisman_name", ""))
		it.功效 = "%s %s" % [str(cfg.get("use_effect", "")), str(cfg.get("effect_value", ""))]
		it.描述 = "%s符箓" % str(cfg.get("talisman_type", ""))
		it.战力加成 = 0
		# S45-5 符词条：绘符产出具名词条（战力烘焙进战力加成；修炼/突破在佩戴护身符/突破时聚合）
		if Game != null and Game.has_method("符词条池"):
			it.滚符词条(it.品阶)
			it.战力加成 += int(Game.符词条聚合(it.符词条).get("战力", 0.0))
		it.算战力()
		产列表.append(it)
		背包.append(it)
	return {"成功": true, "产出": 产列表[0], "产出列表": 产列表, "数量": 产列表.size(),
		"消耗": 消耗列表, "原因": "绘符成功！获得%s×%d（%s，成功率%.0f%%）" % [产列表[0].名称, 产列表.size(), 产出品级, 率],
		"获得经验": 计算绘符经验(归一品阶(str(cfg.get("grade", "凡品"))), true)}

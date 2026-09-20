class_name BreakthroughSystem extends RefCounted

# ===== 弟子突破系统（无独立状态变量，全部引用Game.xxx）=====

# 弟子突破
func 弟子突破(弟子ID: int) -> Dictionary:
	var 目标弟子 = null
	for 弟子 in Game.弟子列表:
		if 弟子 != null and 弟子.弟子ID == 弟子ID:
			目标弟子 = 弟子
			break
	if 目标弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 当前境界 = str(目标弟子.境界)
	if 当前境界 not in Game.弟子突破配置:
		return {"成功": false, "原因": "该境界无法突破或已达最高境界"}
	var 配置 = Game.弟子突破配置[当前境界]
	var 消耗灵石 = int(配置.get("消耗灵石", 0))
	var 消耗悟道点 = int(配置.get("消耗悟道点", 0))
	var 成功率 = clamp(float(配置.get("成功率", 0)) + Game.获取气运突破加成(), 0.05, 0.98)
	成功率 = clamp(成功率 + GongFaSystem.功法词条突破加成(目标弟子), 0.05, 0.98)
	成功率 = clamp(成功率 + Game.装备词条突破加成(目标弟子), 0.05, 0.98)
	成功率 = clamp(成功率 + Game.护身符突破加成(目标弟子), 0.05, 0.98)
	if Game.灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
	if Game.悟道点 < 消耗悟道点:
		return {"成功": false, "原因": "悟道点不足（需%d悟道点）" % 消耗悟道点}
	Game.灵石 -= 消耗灵石
	Game.悟道点 -= 消耗悟道点
	var 随机值 = randf()
	if 随机值 < 成功率:
		var 新境界 = str(配置.get("下一期", ""))
		目标弟子.境界 = 新境界
		if 新境界 in ["元婴", "化神", "炼虚", "合体", "大乘", "渡劫", "仙阶", "道阶"] and 目标弟子.保命护身 <= 0:
			Game.赐予保命护身(目标弟子.弟子ID, 1, "师尊")
		var 属性提升 = 配置.get("属性提升", {})
		目标弟子.修炼速度 = float(目标弟子.修炼速度) + float(属性提升.get("修炼速度", 0))
		目标弟子.战力 = int(目标弟子.战力) + int(属性提升.get("战力", 0))
		目标弟子.心境 = int(目标弟子.心境) + int(属性提升.get("心境", 0))
		Game.累计弟子突破次数 += 1
		Game._复检成就()
		Game.添加纪事("庶务", "弟子突破", "%s突破到%s" % [目标弟子.姓名, 新境界], 1)
		return {"成功": true, "弟子": 目标弟子, "新境界": 新境界, "消耗灵石": 消耗灵石, "消耗悟道点": 消耗悟道点, "消息": "%s突破成功" % 目标弟子.姓名}
	else:
		Game.添加纪事("庶务", "弟子突破", "%s突破失败" % 目标弟子.姓名, 1)
		return {"成功": false, "原因": "突破失败", "消耗灵石": 消耗灵石, "消耗悟道点": 消耗悟道点, "消息": "%s突破失败" % 目标弟子.姓名}

# 获取弟子突破消耗
func 获取弟子突破消耗(弟子ID: int) -> Dictionary:
	var 目标弟子 = null
	for 弟子 in Game.弟子列表:
		if 弟子 != null and 弟子.弟子ID == 弟子ID:
			目标弟子 = 弟子
			break
	if 目标弟子 == null:
		return {}
	var 当前境界 = str(目标弟子.境界)
	if 当前境界 not in Game.弟子突破配置:
		return {"当前境界": 当前境界, "是否可突破": false, "原因": "该境界无法突破或已达最高境界"}
	var 配置 = Game.弟子突破配置[当前境界]
	return {
		"当前境界": 当前境界,
		"下一期": 配置.get("下一期", ""),
		"成功率": float(配置.get("成功率", 0)),
		"消耗灵石": int(配置.get("消耗灵石", 0)),
		"消耗悟道点": int(配置.get("消耗悟道点", 0)),
		"属性提升": 配置.get("属性提升", {}),
		"是否可突破": true,
	}

# ===== 保命环节 =====

func 发放保命道具(弟子ID: int, 数量: int = 1) -> Dictionary:
	var 目标 = null
	for 弟子 in Game.弟子列表:
		if 弟子 != null and 弟子.弟子ID == 弟子ID:
			目标 = 弟子
			break
	if 目标 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if 目标.状态 == "陨落":
		return {"成功": false, "原因": "%s 已陨落，无需保命道具" % 目标.姓名}
	var 费灵石 = 5000 * 数量
	var 费贡献 = 500 * 数量
	if Game.灵石 < 费灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 费灵石}
	if Game.贡献点 < 费贡献:
		return {"成功": false, "原因": "贡献点不足（需%d贡献点）" % 费贡献}
	Game.灵石 -= 费灵石
	Game.贡献点 -= 费贡献
	var 实发 = 数量
	目标.保命护身 += 实发
	Game.添加纪事("庶务", "发放保命", "宗门赐%s保命护身%d枚（耗灵石%d、贡献点%d）" % [目标.姓名, 实发, 费灵石, 费贡献], 1)
	return {"成功": true, "弟子": 目标.姓名, "发放": 实发, "当前保命护身": 目标.保命护身, "消耗灵石": 费灵石, "消耗贡献点": 费贡献}

func 赐予保命护身(弟子ID: int, 数量: int = 1, 来源: String = "宗门") -> Dictionary:
	var 目标 = null
	for 弟子 in Game.弟子列表:
		if 弟子 != null and 弟子.弟子ID == 弟子ID:
			目标 = 弟子
			break
	if 目标 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if 目标.状态 == "陨落":
		return {"成功": false, "原因": "%s 已陨落，无需保命道具" % 目标.姓名}
	var 实发 = 数量
	目标.保命护身 += 实发
	Game.添加纪事("保命", 来源, "%s 获赐保命护身%d枚（来源：%s），危难时可替死" % [目标.姓名, 实发, 来源], 1)
	return {"成功": true, "弟子": 目标.姓名, "发放": 实发, "来源": 来源, "当前保命护身": 目标.保命护身}

func 宗门兑换保命道具(弟子ID: int, 数量: int = 1) -> Dictionary:
	var 目标 = null
	for 弟子 in Game.弟子列表:
		if 弟子 != null and 弟子.弟子ID == 弟子ID:
			目标 = 弟子
			break
	if 目标 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if 目标.状态 == "陨落":
		return {"成功": false, "原因": "%s 已陨落，无需保命道具" % 目标.姓名}
	var 费功勋: int = ContributionShop.保命价() * 数量
	if 目标.贡献账户 < 费功勋:
		return {"成功": false, "原因": "个人功勋不足（现有%d，需%d）" % [目标.贡献账户, 费功勋]}
	目标.贡献账户 -= 费功勋
	var 实发 = 数量
	目标.保命护身 += 实发
	Game.添加纪事("功勋", "兑换保命", "%s 以个人功勋%d兑下保命护身%d枚" % [目标.姓名, 费功勋, 实发], 1)
	return {"成功": true, "弟子": 目标.姓名, "发放": 实发, "消耗功勋": 费功勋, "当前保命护身": 目标.保命护身, "余功勋": 目标.贡献账户}

func 构造保命道具(名称: String, 品阶: String = "宝阶", 类别: String = "fabao", 功效: String = "", 描述: String = "") -> Item:
	var it: Item = Item.new()
	it.类别 = 类别
	it.品阶 = 品阶
	it.名称 = 名称
	it.功效 = 功效 if 功效 != "" else "危难时替弟子挡下致命一劫，护其生还"
	it.描述 = 描述 if 描述 != "" else "护身之宝，命悬一线时自发护主。"
	it.穿戴位 = ""
	it.词缀 = []
	it.极品 = false
	it.特殊 = false
	it.极品属性 = null
	it.保命 = true
	it.算战力()
	return it

# 序列化（无状态变量，空实现）
func to_dict() -> Dictionary:
	return {}

# 反序列化（无状态变量，空实现）
func from_dict(data: Dictionary) -> void:
	pass

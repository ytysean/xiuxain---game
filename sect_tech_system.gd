class_name SectTechSystem extends RefCounted

# ===== 宗门科技系统状态变量 =====
var 已研究宗门科技: Array = []

# 研究宗门科技
func 研究宗门科技(科技名称: String) -> Dictionary:
	if 科技名称 not in Game.宗门科技树配置:
		return {"成功": false, "原因": "科技不存在"}
	if 科技名称 in 已研究宗门科技:
		return {"成功": false, "原因": "该科技已研究"}
	var 配置 = Game.宗门科技树配置[科技名称]
	# 检查前置科技
	var 前置科技 = 配置.get("前置科技", [])
	for 前置 in 前置科技:
		if 前置 not in 已研究宗门科技:
			return {"成功": false, "原因": "需要先研究前置科技：%s" % 前置}
	var 消耗灵石 = int(配置.get("消耗灵石", 0))
	var 消耗悟道点 = int(配置.get("消耗悟道点", 0))
	if Game.灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
	if Game.悟道点 < 消耗悟道点:
		return {"成功": false, "原因": "悟道点不足（需%d悟道点）" % 消耗悟道点}
	Game.灵石 -= 消耗灵石
	Game.悟道点 -= 消耗悟道点
	已研究宗门科技.append(科技名称)
	Game.添加纪事("庶务", "研究科技", "研究宗门科技：%s" % 科技名称, 1)
	return {"成功": true, "科技名称": 科技名称, "配置": 配置, "消耗灵石": 消耗灵石, "消耗悟道点": 消耗悟道点, "消息": "研究%s成功" % 科技名称}

# 获取所有宗门科技列表
func 获取所有宗门科技列表() -> Array:
	var 列表 = []
	for 科技名称 in Game.宗门科技树配置.keys():
		var 配置 = Game.宗门科技树配置[科技名称]
		var 前置科技 = 配置.get("前置科技", [])
		var 前置已研究 = true
		for 前置 in 前置科技:
			if 前置 not in 已研究宗门科技:
				前置已研究 = false
				break
		列表.append({
			"科技名称": 科技名称,
			"描述": 配置.get("描述", ""),
			"效果": 配置.get("效果", {}),
			"消耗灵石": int(配置.get("消耗灵石", 0)),
			"消耗悟道点": int(配置.get("消耗悟道点", 0)),
			"前置科技": 前置科技,
			"等级": int(配置.get("等级", 1)),
			"已研究": 科技名称 in 已研究宗门科技,
			"可研究": 前置已研究 and 科技名称 not in 已研究宗门科技,
		})
	return 列表

# 计算宗门科技总效果
func 计算宗门科技总效果() -> Dictionary:
	var 总效果 = {
		"修炼速度加成": 0.0,
		"战力加成": 0.0,
		"产出加成": 0.0,
		"阵法加成": 0.0,
		"丹药加成": 0.0,
	}
	for 科技名称 in 已研究宗门科技:
		if 科技名称 in Game.宗门科技树配置:
			var 配置 = Game.宗门科技树配置[科技名称]
			var 效果 = 配置.get("效果", {})
			总效果["修炼速度加成"] += float(效果.get("修炼速度加成", 0))
			总效果["战力加成"] += float(效果.get("战力加成", 0))
			总效果["产出加成"] += float(效果.get("产出加成", 0))
			总效果["阵法加成"] += float(效果.get("阵法加成", 0))
			总效果["丹药加成"] += float(效果.get("丹药加成", 0))
	return 总效果

# 序列化
func to_dict() -> Dictionary:
	return {
		"已研究宗门科技": 已研究宗门科技,
	}

# 反序列化
func from_dict(data: Dictionary) -> void:
	已研究宗门科技 = data.get("已研究宗门科技", [])

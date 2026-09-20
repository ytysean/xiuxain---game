class_name GongFaManagementSystem extends RefCounted

# ===== 功法系统状态变量 =====
var 功法熟练度: Dictionary = {}  # 功法ID -> 熟练度

# 功法升级配置
const 功法升级配置: Dictionary = {
	1: {"成功率": 0.9, "消耗悟道点": 100, "效果提升": 0.1},
	2: {"成功率": 0.8, "消耗悟道点": 300, "效果提升": 0.15},
	3: {"成功率": 0.7, "消耗悟道点": 800, "效果提升": 0.2},
	4: {"成功率": 0.6, "消耗悟道点": 2000, "效果提升": 0.25},
	5: {"成功率": 0.5, "消耗悟道点": 5000, "效果提升": 0.3},
	6: {"成功率": 0.4, "消耗悟道点": 12000, "效果提升": 0.35},
	7: {"成功率": 0.3, "消耗悟道点": 30000, "效果提升": 0.4},
	8: {"成功率": 0.2, "消耗悟道点": 80000, "效果提升": 0.45},
	9: {"成功率": 0.1, "消耗悟道点": 200000, "效果提升": 0.5},
	10: {"成功率": 0.05, "消耗悟道点": 500000, "效果提升": 0.6},
}

# 学习功法（自动消耗悟道点）
func 学习功法(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 结果: Dictionary = GongFaSystem.学习功法(弟子, 功法ID, Game.悟道点)
	if 结果.get("成功", false):
		var 消耗: int = int(结果.get("消耗", 0))
		Game.悟道点 -= 消耗
		Game._复检成就()
		var 已学功法总数: int = 0
		for d in Game.弟子列表:
			if d != null:
				var 弟子功法 = d.get("已学功法") if "已学功法" in d else []
				if 弟子功法 != null:
					已学功法总数 += 弟子功法.size()
		if 已学功法总数 == 1:
			Game._传承事件("首次学习功法")
		Game.更新阵营任务进度("正道宗门", "weekly", 1)
	return 结果

# 遗忘功法（返还悟道点）
func 遗忘功法(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 结果: Dictionary = GongFaSystem.遗忘功法(弟子, 功法ID)
	if 结果.get("成功", false):
		var 返还: int = int(结果.get("返还", 0))
		Game.悟道点 += 返还
	return 结果

# 升级功法
func 升级功法(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 已学功法 = 弟子.get("已学功法", [])
	if 已学功法 == null or not 功法ID in 已学功法:
		return {"成功": false, "原因": "弟子未学习该功法"}
	var 功法等级: int = 1
	if "功法等级" in 弟子 and typeof(弟子.功法等级) == TYPE_DICTIONARY:
		功法等级 = int(弟子.功法等级.get(功法ID, 1))
	if 功法等级 >= 10:
		return {"成功": false, "原因": "功法已达最高重数"}
	var 配置 = 功法升级配置.get(功法等级 + 1, {})
	var 消耗悟道点 = int(配置.get("消耗悟道点", 0))
	var 成功率 = float(配置.get("成功率", 0))
	if Game.悟道点 < 消耗悟道点:
		return {"成功": false, "原因": "悟道点不足（需%d悟道点）" % 消耗悟道点}
	Game.悟道点 -= 消耗悟道点
	var 随机值 = randf()
	if 随机值 < 成功率:
		if not "功法等级" in 弟子 or typeof(弟子.功法等级) != TYPE_DICTIONARY:
			弟子["功法等级"] = {}
		弟子.功法等级[功法ID] = 功法等级 + 1
		Game.添加纪事("庶务", "升级功法", "%s的%s升级到%d级" % [弟子.姓名, 功法ID, 功法等级 + 1], 1)
		return {"成功": true, "弟子": 弟子, "功法ID": 功法ID, "新等级": 功法等级 + 1, "消耗悟道点": 消耗悟道点, "消息": "%s升级成功" % 功法ID}
	else:
		Game.添加纪事("庶务", "升级功法", "%s的%s升级失败" % [弟子.姓名, 功法ID], 1)
		return {"成功": false, "原因": "升级失败", "消耗悟道点": 消耗悟道点, "消息": "%s升级失败" % 功法ID}

# 获取功法升级消耗
func 获取功法升级消耗(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {}
	var 已学功法 = 弟子.get("已学功法", [])
	if 已学功法 == null or not 功法ID in 已学功法:
		return {"已学习": false, "原因": "弟子未学习该功法"}
	var 功法等级: int = 1
	if "功法等级" in 弟子 and typeof(弟子.功法等级) == TYPE_DICTIONARY:
		功法等级 = int(弟子.功法等级.get(功法ID, 1))
	if 功法等级 >= 10:
		return {"已学习": true, "当前等级": 功法等级, "最大等级": 10, "是否可升级": false, "原因": "功法已达最高重数"}
	var 配置 = 功法升级配置.get(功法等级 + 1, {})
	return {
		"已学习": true,
		"当前等级": 功法等级,
		"下一级等级": 功法等级 + 1,
		"最大等级": 10,
		"成功率": float(配置.get("成功率", 0)),
		"消耗悟道点": int(配置.get("消耗悟道点", 0)),
		"效果提升": float(配置.get("效果提升", 0)),
		"是否可升级": true,
	}

# 增加功法熟练度
func 增加功法熟练度(功法ID: String, 熟练度: int = 1) -> void:
	if 功法ID in 功法熟练度:
		功法熟练度[功法ID] += 熟练度
	else:
		功法熟练度[功法ID] = 熟练度

# 获取功法熟练度
func 获取功法熟练度(功法ID: String) -> int:
	return int(功法熟练度.get(功法ID, 0))

# 获取功法熟练度排行榜
func 获取功法熟练度排行榜(限制数量: int = 10) -> Array:
	var 排行榜 = []
	for 功法ID in 功法熟练度.keys():
		排行榜.append({
			"功法ID": 功法ID,
			"熟练度": 功法熟练度[功法ID],
		})
	排行榜.sort_custom(func(a, b): return a["熟练度"] > b["熟练度"])
	return 排行榜.slice(0, min(限制数量, 排行榜.size()))

# 序列化
func to_dict() -> Dictionary:
	return {
		"功法熟练度": 功法熟练度,
	}

# 反序列化
func from_dict(data: Dictionary) -> void:
	功法熟练度 = data.get("功法熟练度", {})

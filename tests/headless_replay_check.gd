extends Node

# P0-3 战斗快播 · 数据层实机验证
# 验证点：
#   1. 历练历史记录确实写入 攻方快照/守方快照/原始战报
#   2. 超过 回放保留条数(20) 的旧记录被剥离回放数据（存档体积闸门生效）
#   3. 文字战绩（关卡名/评级/奖励）在裁剪后仍然保留
#   4. 获取历练历史 / 获取历练统计 在含回放数据的情况下不崩

func _ready() -> void:
	if Game == null:
		printerr("FATAL: Game 单例缺失")
		get_tree().quit()
		return

	var 系统 = ExpeditionSystem
	if 系统 == null:
		printerr("FATAL: ExpeditionSystem 缺失")
		get_tree().quit()
		return

	prints("[回放验证] 回放保留条数 =", 系统.回放保留条数)

	var 假快照: Array = [{"姓名": "测试弟子", "境界": "筑基", "战力": 1000}]
	var 假战报: Dictionary = {
		"is_win": true,
		"battle_log": [
			{"round": 1, "actor": "测试弟子", "target": "妖兽", "damage": 120, "is_crit": false},
			{"round": 2, "actor": "妖兽", "target": "测试弟子", "damage": 60, "is_crit": false},
		],
	}

	# 写入 25 条，验证第 21 条起被裁剪
	var 写入条数: int = 25
	for i in range(写入条数):
		系统.添加历练记录({
			"历练ID": "test_%d" % i,
			"关卡名称": "测试秘境%d" % i,
			"路线": "稳妥",
			"开始日": i,
			"成功": true,
			"评级": "A",
			"结局类型": "普通",
			"奇遇次数": 0,
			"奖励": {"灵石": 100},
			"弟子ID列表": [1],
			"攻方快照": 假快照,
			"守方快照": 假快照,
			"原始战报": 假战报,
		})

	var 历史: Array = 系统.获取历练历史(0, 30)
	prints("[回放验证] 写入", 写入条数, "条，取回", 历史.size(), "条")

	var 可回放数: int = 0
	var 已裁剪数: int = 0
	for 记录 in 历史:
		if 记录.has("原始战报") and not Dictionary(记录.get("原始战报", {})).is_empty():
			可回放数 += 1
		else:
			已裁剪数 += 1
	prints("[回放验证] 可回放 =", 可回放数, " 已裁剪 =", 已裁剪数)

	var 裁剪正确: bool = (可回放数 == 系统.回放保留条数)
	prints("[回放验证] 裁剪闸门正确（可回放数应等于", 系统.回放保留条数, "）->", 裁剪正确)

	# 裁剪后文字战绩是否仍保留
	var 末条: Dictionary = 历史[历史.size() - 1] if 历史.size() > 0 else {}
	var 文字保住: bool = (str(末条.get("关卡名称", "")) != "" and str(末条.get("评级", "")) != "")
	prints("[回放验证] 最旧一条文字战绩保留 ->", 文字保住,
		"（关卡=", 末条.get("关卡名称", "—"), " 评级=", 末条.get("评级", "—"),
		" 有战报=", 末条.has("原始战报"), "）")

	# 统计接口不崩
	var 统计: Dictionary = 系统.获取历练统计()
	prints("[回放验证] 获取历练统计 -> 总次数 =", 统计.get("总次数", -1))

	if 裁剪正确 and 文字保住:
		prints("\n=== 回放数据层验证 通过 ===")
	else:
		printerr("\n=== 回放数据层验证 失败 ===")
	get_tree().quit()

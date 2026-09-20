class_name TalismanManagementSystem extends RefCounted

# ===== 符箓系统封装（无独立状态变量，全部引用Game.xxx）=====

# 执行炼符（封装TalismanSystem.炼符，自动更新宗门库房和统计）
func 执行炼符(符箓ID: String, 符堂等级: int = 1) -> Dictionary:
	var cfg = Game.符箓配置(符箓ID)
	if cfg.is_empty():
		return {"成功": false, "原因": "符箓不存在"}
	# S45-6 绘符等级门槛
	var 需绘符等级: int = int(cfg.get("need_draw_level", 0))
	var 现绘符等级: int = Game.获取绘符等级()
	if 需绘符等级 > 0 and 现绘符等级 < 需绘符等级:
		return {"成功": false, "原因": "绘符品级不足：%s符需绘符品级%d（当前%d）" % [
			str(cfg.get("grade", "凡品")), 需绘符等级, 现绘符等级]}
	var 符师 = Game.符堂负责人()
	var 背包: Array = Game.宗门库房.duplicate()
	var 因子: Dictionary = Game.符箓因子明细(符师, 符堂等级)
	# S45-4 符纹图谱里程碑 → 绘符成功率加成
	因子["成率"] = float(因子.get("成率", 0.0)) + Game.符纹图谱成功率加成()
	# S45-4 符纸省材率
	因子["省材率"] = clamp(float(Game.当前符纸配置().get("省材率", 0.0)), 0.0, 0.5)
	# S45-6 绘符等级 → 成功率加成
	var 绘符加成: Dictionary = Game.获取绘符加成()
	因子["成率"] = float(因子.get("成率", 0.0)) + float(绘符加成.get("成功率加成", 0.0)) / 100.0
	# 品级分
	var 分: float = float(符堂等级) * 1.5 + float(因子.get("成率", 0.0)) * 100.0 * 0.3
	分 += Game.符箓熟练加成(符箓ID)["品级分"]
	分 += float(绘符加成.get("高品质加成", 0.0)) * 100.0
	分 += float(Game.当前符纸配置().get("品级分", 0.0))
	var 阶: String = str(cfg.get("grade", "凡品"))
	分 += max(0.0, float(Game.符师压制(符师, Game.符箓需求境界序(阶)))) * 1.0
	var 品级配置: Dictionary = Game.掷符品级(分)
	var 品级名: String = str(品级配置.get("grade_name", "中品"))
	var 数量: int = Game.符箓产出数量(符箓ID, 符师, 符堂等级, 品级名)
	var 结果: Dictionary = TalismanSystem.炼符(cfg, 背包, 符堂等级, 符师, 因子, 品级名, 数量)
	Game.宗门库房 = 背包
	# S45-6 绘符经验累计
	var 获得绘符经验: int = int(结果.get("获得经验", 0))
	if 获得绘符经验 > 0:
		Game.增加绘符经验(获得绘符经验)
	if 结果.get("成功", false):
		# S45-4 符纹：逐张掷纹
		var 上限: int = Game.符纹上限(阶, 品级名)
		var 级系数: float = float(品级配置.get("mark_rate_scale", 1.0))
		var 额外: float = float(Game.当前符纸配置().get("出纹", 0.0))
		var 首纹: int = 0
		var 产列表: Array = 结果.get("产出列表", [])
		for i in range(产列表.size()):
			var it = 产列表[i]
			if it == null or not (it is Object):
				continue
			var 纹2: int = Game.掷符纹(阶, 符堂等级, 额外, 级系数, 上限)
			it.符纹 = 纹2
			if i == 0:
				首纹 = 纹2
			Game.符纹图谱入谱(it, 纹2, 阶)
		结果["纹"] = 首纹
		# 熟练度累计
		Game.符箓熟练度[符箓ID] = int(Game.符箓熟练度.get(符箓ID, 0)) + 1
		var 旧数: int = Game.累计炼符数
		Game.累计炼符数 += int(结果.get("数量", 1))
		Game._复检成就()
		if 旧数 == 0:
			Game._传承事件("首次炼制符箓")
			Game.更新阵营任务进度("正道宗门", "daily", 1)
	return 结果

# 序列化（无状态变量，空实现）
func to_dict() -> Dictionary:
	return {}

# 反序列化（无状态变量，空实现）
func from_dict(data: Dictionary) -> void:
	pass

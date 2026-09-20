class_name AlchemyForgeSystem extends RefCounted

# ===== 炼丹炼器封装系统状态变量 =====
var 炼器经验值: int = 0

# ===== 炼丹系统 =====

# 执行炼丹（封装AlchemySystem.炼丹，自动更新宗门库房和统计）
# P0联动：增加炼丹弟子参数，弟子炼丹等级影响成功率
func 执行炼丹(丹方ID: String, 丹堂等级: int = 1, 炼丹弟子 = null) -> Dictionary:
	# 计算弟子炼丹等级加成
	var 弟子炼丹加成: float = 0.0
	if 炼丹弟子 != null and typeof(炼丹弟子) == TYPE_OBJECT and "炼丹等级" in 炼丹弟子:
		弟子炼丹加成 = float(int(炼丹弟子.炼丹等级)) * 0.02  # 每级+2%成功率
	# S39：优先走统一丹方表；未收录则回落旧硬编码丹方
	if not Game.丹方配置(丹方ID).is_empty():
		var r39: Dictionary = Game.炼制丹方(丹方ID, 丹堂等级)
		if bool(r39.get("成功", false)):
			var 旧数: int = Game.累计炼制丹药数
			Game.累计炼制丹药数 += int(r39.get("数量", 1))
			Game._复检成就()
			if 旧数 == 0:
				Game._传承事件("首次炼制丹药")
			Game.更新阵营任务进度("魔道邪宗", "daily", 1)
		return r39
	var 背包: Array = Game.宗门库房.duplicate()
	var 结果: Dictionary = AlchemySystem.炼丹(丹方ID, 背包, 丹堂等级, Game.炼丹成率加成(丹堂等级) + 弟子炼丹加成)
	Game.宗门库房 = 背包
	# S37 丹纹：炼制产出掷纹并入谱
	if 结果.get("成功", false) and 结果.get("产出", null) != null:
		Game.赋予丹纹(结果["产出"], str((AlchemySystem.丹方库.get(丹方ID, {}) as Dictionary).get("品阶", "凡阶")), 丹堂等级)
	# 更新成就统计
	if 结果.get("成功", false):
		var 旧炼丹数: int = Game.累计炼制丹药数
		Game.累计炼制丹药数 += 1
		Game._复检成就()
		if 旧炼丹数 == 0:
			Game._传承事件("首次炼制丹药")
		Game.更新阵营任务进度("魔道邪宗", "daily", 1)
	return 结果

# ===== 炼器系统 =====

# 获取炼器等级
func 获取炼器等级() -> int:
	return ForgeSystem.获取炼器等级(炼器经验值)

# 获取炼器加成
func 获取炼器加成() -> Dictionary:
	return ForgeSystem.获取炼器加成(炼器经验值)

# 增加炼器经验
func 增加炼器经验(数量: int) -> void:
	if 数量 <= 0:
		return
	var 旧等级: int = 获取炼器等级()
	炼器经验值 += 数量
	var 新等级: int = 获取炼器等级()
	if 新等级 > 旧等级:
		print("[炼器] 炼器等级提升：%d → %d" % [旧等级, 新等级])

# 执行炼器（封装ForgeSystem.炼器，自动传递炼器经验值并更新）
func 执行炼器(配方ID: String, 器堂等级: int = 1, 炼器弟子 = null) -> Dictionary:
	var 背包: Array = Game.宗门库房.duplicate()
	var 因子: Dictionary = Game.锻造因子明细(炼器弟子, 器堂等级)
	var 结果: Dictionary = ForgeSystem.炼器(配方ID, 背包, 器堂等级, 炼器弟子, 炼器经验值, 因子)
	Game.宗门库房 = 背包
	# S43 装备词条：配方路径产出同样掷具名词条
	if 结果.get("成功", false) and 结果.has("产出") and 结果["产出"] != null:
		var 产 = 结果["产出"]
		产.滚装备词条(产.品阶)
		产.战力加成 += int(Game.装备词条聚合(产.装备词条).get("战力", 0.0))
	# 更新炼器经验
	var 获得经验: int = int(结果.get("获得经验", 0))
	if 获得经验 > 0:
		增加炼器经验(获得经验)
	# 更新成就统计
	if 结果.get("成功", false):
		var 旧锻造数: int = Game.累计锻造装备数
		Game.累计锻造装备数 += 1
		# S46 炼器领悟
		var 领悟结果: Dictionary = Game._炼器成功触发领悟(配方ID, 器堂等级)
		if bool(领悟结果.get("反推领悟", false)) or bool(领悟结果.get("顿悟领悟", false)):
			var 新配方名: String = str((ForgeSystem.配方库.get(str(领悟结果.get("领悟配方", "")), {}) as Dictionary).get("名称", ""))
			if 新配方名 != "":
				Game.添加纪事("庶务", "器道领悟", "于锻造中触类旁通，领悟了【%s】锻造之法！" % 新配方名, 2)
		Game._复检成就()
		if 旧锻造数 == 0:
			Game._传承事件("首次锻造装备")
		Game.更新阵营任务进度("正道宗门", "daily", 1)
	return 结果

# 序列化
func to_dict() -> Dictionary:
	return {
		"炼器经验值": 炼器经验值,
	}

# 反序列化
func from_dict(data: Dictionary) -> void:
	炼器经验值 = data.get("炼器经验值", 0)

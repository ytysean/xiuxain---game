extends Node

# 无界面实测节点：普通 --scene 运行（autoload 全局名 Game 正常注册）。
# 直接驱动真实 Game/Disciple/Karma 代码，测量 S46 观礼与 S47 异闻分区，并验证两个 bug 修复。
# 运行：MSYS_NO_PATHCONV=1 E:/Godot..._console.exe --headless --path E:/Xiuxian/taixuanzongmenlu --scene res://tests/headless_boot.tscn

func _ready() -> void:
	prints("=== 无界面实测启动 ===")
	if Game == null:
		printerr("FATAL: Game 单例缺失")
		get_tree().quit()
		return

	# 1) 确保有合法宗门态（_ready 已建宗则跳过）
	if Game.弟子列表.is_empty():
		Game.初始建宗()
	for d in Game.弟子列表:
		d.状态 = "在宗"
		d.业力 = randi_range(50, 280)
		d.功德 = randi_range(50, 280)
	prints("初始弟子数:", Game.弟子列表.size(), " 宗主:", Game.宗主.姓名, Game.宗主.境界)

	# ---------- S46 TEST 1：观礼感悟（渡劫成功） ----------
	var 渡劫者 = Game.弟子列表[1]
	Game.大能渡劫观礼前置(渡劫者)
	var 名单 = Game.当前观礼名单.duplicate()
	var 观礼者 = []
	for id in 名单:
		var o = Game._取弟子(int(id))
		if o != null and o != 渡劫者:
			观礼者.append(o)
	var 道心前 = {}
	for o in 观礼者:
		道心前[o.弟子ID] = o.道心
	Game.大能渡劫观礼后置(渡劫者, {"结果": "成功", "天劫名": "九霄神雷"})
	prints("\n=== S46-1 观礼感悟(成功) 观礼人数:", 观礼者.size(), " ===")
	for o in 观礼者:
		prints("  ", o.姓名, "道心", 道心前[o.弟子ID], "->", o.道心,
			"| 感悟剩余", o.观礼感悟剩余, "| 倍率", snapped(o.观礼感悟倍率, 0.001))

	# ---------- S46 TEST 2：雷劫余波（渡劫重伤） ----------
	var 渡劫者2 = Game.弟子列表[2]
	渡劫者2.渡劫详情 = {"天劫名": "九霄神雷"}
	Game.大能渡劫观礼前置(渡劫者2)
	var 余波名单 = Game.当前观礼名单.duplicate()
	var 余波者 = []
	for id in 余波名单:
		var o = Game._取弟子(int(id))
		if o != null and o != 渡劫者2:
			余波者.append(o)
	var 心魔前 = {}
	var 伤前 = {}
	for o in 余波者:
		心魔前[o.弟子ID] = o.心魔值
		伤前[o.弟子ID] = o.受伤剩余
	Game.大能渡劫观礼后置(渡劫者2, {"结果": "重伤", "天劫名": "九霄神雷"})
	prints("\n=== S46-2 雷劫余波(重伤) 余波人数:", 余波者.size(), " ===")
	for o in 余波者:
		prints("  ", o.姓名, "心魔", 心魔前[o.弟子ID], "->", o.心魔值,
			"| 轻伤剩余", 伤前[o.弟子ID], "->", o.受伤剩余)

	# ---------- S46 TEST 3：修炼加速 A/B（同弟子，隔离其它乘区） ----------
	var T = Game.弟子列表[3]
	Game.灵气 = 999999
	T.稳固期剩余 = 0.0
	T.受伤剩余 = 0
	T.丹毒 = 0.0
	T.突破冷却剩余 = 0.0
	T.层数 = 0
	T.观礼感悟剩余 = 30.0
	T.观礼感悟倍率 = 0.10
	T.修炼进度 = 0.0
	T.推进修炼(2.0, 1.0)
	var 有buff = T.修炼进度
	T.观礼感悟剩余 = 0.0
	T.观礼感悟倍率 = 0.0
	T.修炼进度 = 0.0
	T.推进修炼(2.0, 1.0)
	var 无buff = T.修炼进度
	prints("\n=== S46-3 修炼加速 A/B（同弟子·2游戏日） ===")
	prints("  有buff(倍率0.10) 修炼进度:", snapped(有buff, 0.001),
		"  无buff 修炼进度:", snapped(无buff, 0.001),
		"  实测倍率比:", snapped(有buff / max(0.0001, 无buff), 0.001),
		"（理论应≈1.10；若≈0.55 表示 效率=0.5 误置 bug 仍在）")
	T.观礼感悟剩余 = 30.0
	T.观礼感悟倍率 = 0.10
	T.修炼进度 = 0.0
	T.推进修炼(30.0, 1.0)
	prints("  30游戏日(有buff) 修炼进度累计:", snapped(T.修炼进度, 0.001),
		" 残余感悟剩余:", snapped(T.观礼感悟剩余, 0.001), " 倍率:", snapped(T.观礼感悟倍率, 0.001))

	# ---------- S47 TEST：异闻按境界分区 ----------
	while Game.弟子列表.size() < 35:
		var nd = Disciple.new()
		nd.状态 = "在宗"
		nd.业力 = randi_range(50, 300)
		nd.功德 = randi_range(50, 300)
		Game.弟子列表.append(nd)
	var 境界池 = ["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫", "道阶"]
	for i in range(Game.弟子列表.size()):
		Game.弟子列表[i].境界 = 境界池[i % 境界池.size()]
	Game.宗门纪事.clear()
	Game.异闻分区已播.clear()
	Game.异闻分区月上限 = 6
	Game.异闻分区阈值 = 30
	Game._记录异闻_S45()
	var 异闻条数 = 0
	for r in Game.宗门纪事:
		if str(r.get("分类", "")) == "异闻":
			异闻条数 += 1
			prints("  [纪事]", r.get("标题", ""), "||", str(r.get("正文", "")).left(24))
	prints("\n=== S47 异闻分区（宗门规模:", Game.弟子列表.size(), "）===")
	prints("  当月异闻纪事条数:", 异闻条数, "（应>1且<=月上限6，标题带【境界】前缀）")
	prints("  异闻分区已播.size():", Game.异闻分区已播.size(), "（修复后应>0；旧bug下恒为0）")
	var 分区 = Karma.宗门异闻分区(Game.弟子列表)
	prints("  宗门异闻分区() 返回条数:", 分区.size())
	var 按境计数 = {}
	for x in 分区:
		var 境 = x["境界"]
		按境计数[境] = int(按境计数.get(境, 0)) + 1
	prints("  分区覆盖境界数:", 按境计数.keys().size(), " 各境条数:", 按境计数)
	var 前 = Game.宗门纪事.size()
	Game._记录异闻_S45()
	var 后增 = Game.宗门纪事.size() - 前
	prints("  二次调用(已播未清) 新增纪事:", 后增, "（应=0，证明去重键生效；旧bug下仍为>0）")

	prints("\n=== 实测完成 ===")
	get_tree().quit()

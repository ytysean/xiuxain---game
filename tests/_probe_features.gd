extends Node

## 阶段一 · 核心功能实操探针（headless · 驱动真实数据链 · 2026-09-16）
## 覆盖：炼丹 / 炼器 / 坊市购买 / 每日特惠 / 殿阁升级 / 药园种植收获 / 散修招募 /
##       历练开始+结算 / 灵钓开始 / 宗门科技。
## 每项打印 >>>FEAT 行（含真实返回原因）；判据末行 >>>FEATS_DONE FAIL=n。
## 用法：<godot> --headless --path <proj> --scene res://tests/_probe_features.tscn

var _fail := 0


func _ready() -> void:
	var t := Timer.new()
	t.wait_time = 120.0
	t.one_shot = true
	t.timeout.connect(func() -> void:
		printerr(">>>FEATS TIMEOUT")
		get_tree().quit())
	add_child(t)
	t.start()
	if Game == null:
		printerr(">>>FAIL Game 单例缺失")
		get_tree().quit()
		return
	if Game.弟子列表.is_empty():
		Game.初始建宗()
	print(">>>FEATS 初始 弟子=%d 灵石=%d" % [Game.弟子列表.size(), Game.灵石])

	# 1) 炼丹（顺带验证 S39 统一丹方表覆盖）
	var 丹方ID: String = ""
	if AlchemySystem != null and "丹方库" in AlchemySystem and not AlchemySystem.丹方库.is_empty():
		丹方ID = str(AlchemySystem.丹方库.keys()[0])
	var 丹表覆盖: bool = not Game.丹方配置(丹方ID).is_empty()
	_fe("炼丹", Game.执行炼丹(丹方ID, 1), "丹方=%s S39表覆盖=%s" % [丹方ID, 丹表覆盖])

	# 2) 炼器
	var 器方ID: String = ""
	if ForgeSystem != null and "配方库" in ForgeSystem and not ForgeSystem.配方库.is_empty():
		器方ID = str(ForgeSystem.配方库.keys()[0])
	_fe("炼器", Game.执行炼器(器方ID, 1, null), "配方=%s" % 器方ID)

	# 3) 坊市购买 + 每日特惠
	Game.刷新坊市上架()
	var shop_id: String = ""
	if not Game.坊市上架集.is_empty():
		shop_id = str(Game.坊市上架集[0])
	_fe("坊市购买", Game.购买坊市物品(shop_id), "shop_id=%s 上架数=%d" % [shop_id, Game.坊市上架集.size()])
	Game.刷新坊市每日特惠()
	print(">>>FEAT 每日特惠 数量=%d（0=空壳复现）" % Game.坊市每日特惠.size())

	# 4) 殿阁升级
	var 殿key: String = ""
	if not Game.司职列表.is_empty():
		殿key = str(Game.司职列表.keys()[0])
	var 殿res: Dictionary = Game.升级殿阁(殿key)
	print(">>>FEAT 殿阁升级 ok=%s 原因=%s key=%s 门派等级=%d" % [
		str(殿res.get("ok", 殿res.get("成功", "?"))), str(殿res.get("msg", 殿res.get("原因", ""))), 殿key, Game.门派等级])

	# 5) 药园种植→收获
	# 新档默认只解锁 1 块地（ID=0）
	var 种: Dictionary = Game.种植药园(0, "灵草")
	var 收: Dictionary = Game.收获药园(0)
	print(">>>FEAT 药园 种植=%s 收获=%s" % [str(种), str(收)])

	# 6) 散修招募
	print(">>>FEAT 散修 来访数=%d" % Game.获取来访散修().size())
	if Game.获取来访散修().is_empty():
		_fail += 1
		print(">>>FEAT_FAIL 散修招募 无来访散修可招募（候选池为空）")
	else:
		var sname: String = str(Game.来访散修[0].get("名称", ""))
		_fe("散修招募", Game.招募散修(sname), "目标=%s" % sname)

	# 7) 历练：选关 → 开始 → 结算
	var 关卡们: Array = ExpeditionSystem.获取可用关卡("练气")
	if 关卡们.is_empty():
		_fail += 1
		print(">>>FEAT_FAIL 历练 练气期无可用关卡")
	else:
		var 关ID: String = str(关卡们[0])
		var ids: Array = []
		for i in range(mini(2, Game.弟子列表.size())):
			ids.append(Game.弟子列表[i].弟子ID)
		var 开始: Dictionary = ExpeditionSystem.开始历练(关ID, ids)
		print(">>>FEAT 历练开始 ok=%s 详情=%s 关卡=%s" % [str(开始.get("成功", 开始.get("ok", "?"))), str(开始), 关ID])
		# 推进到预计结束日之后，触发到期结算
		Game.累计游戏日 += 2
		var 结算: Array = ExpeditionSystem.检查并结算历练()
		print(">>>FEAT 历练结算 条数=%d 首条=%s" % [结算.size(), str(结算[0]) if not 结算.is_empty() else "无"])

	# 8) 灵钓
	var 渊表: Array = Game.灵钓系统.灵渊表
	if 渊表.is_empty():
		_fail += 1
		print(">>>FEAT_FAIL 灵钓 灵渊表为空")
	else:
		var 渊id: int = int(渊表[0].get("id", 0))
		var 钓: Dictionary = Game.灵钓系统.开始灵钓(渊id)
		print(">>>FEAT 灵钓 ok=%s 渊=%d 张力参数键=%d" % [str(钓.get("成功", "?")), 渊id, 钓.size()])

	# 9) 宗门科技
	_fe("宗门科技", Game.研究宗门科技("修炼加速I"), "")

	print(">>>FEATS_DONE FAIL=%d" % _fail)
	get_tree().quit()


func _fe(名称: String, res: Dictionary, 附注: String) -> void:
	var ok: bool = bool(res.get("成功", res.get("ok", false)))
	if not ok:
		_fail += 1
	print(">>>FEAT %s ok=%s 原因=%s %s" % [名称, str(ok), str(res.get("原因", res.get("msg", ""))), 附注])

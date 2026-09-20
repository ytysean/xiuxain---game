class_name AchievementSystem extends RefCounted

# ===== 成就系统状态变量 =====
var 成就_已达成: Array = []
var 已领取成就奖励: Array = []

# 成就分类配置
const 成就分类配置: Dictionary = {
	"经营": {"描述": "宗门经营相关成就", "图标": "◇"},
	"成长": {"描述": "弟子成长相关成就", "图标": "▲"},
	"战斗": {"描述": "战斗历练相关成就", "图标": "◆"},
	"收集": {"描述": "收集图鉴相关成就", "图标": "■"},
	"社交": {"描述": "社交互动相关成就", "图标": "◇"},
	"探索": {"描述": "探索秘境相关成就", "图标": "◇"},
	"特殊": {"描述": "特殊隐藏成就", "图标": "◆"},
}

# ===== 成就查询 =====

func 获取所有成就列表() -> Array:
	Game._加载成就配置()
	var 成就列表 = []
	for 成就 in Game.成就配置:
		成就列表.append({
			"achievement_id": 成就.get("achievement_id", ""),
			"名称": 成就.get("名称", ""),
			"描述": 成就.get("描述", ""),
			"稀有度": 成就.get("稀有度", "普通"),
			"condition_type": 成就.get("condition_type", ""),
			"condition_param": 成就.get("condition_param", 0),
			"已达成": 成就.get("已达成", false),
			"奖励灵石": 成就.get("奖励灵石", 0),
			"奖励灵气": 成就.get("奖励灵气", 0),
			"奖励声望": 成就.get("奖励声望", 0),
		})
	return 成就列表

func 获取成就统计() -> Dictionary:
	var 已达成数 = 0
	var 总数 = Game.成就配置.size()
	var 总奖励灵石 = 0
	var 总奖励灵气 = 0
	var 总奖励声望 = 0
	for 成就 in Game.成就配置:
		if 成就.get("已达成", false):
			已达成数 += 1
		总奖励灵石 += int(成就.get("奖励灵石", 0))
		总奖励灵气 += int(成就.get("奖励灵气", 0))
		总奖励声望 += int(成就.get("奖励声望", 0))
	return {
		"已达成数": 已达成数, "总数": 总数,
		"完成率": float(已达成数) / float(max(1, 总数)),
		"总奖励灵石": 总奖励灵石, "总奖励灵气": 总奖励灵气, "总奖励声望": 总奖励声望,
	}

func 按稀有度筛选成就(稀有度: String) -> Array:
	var 筛选列表 = []
	for 成就 in Game.成就配置:
		if 成就.get("稀有度", "") == 稀有度:
			筛选列表.append(成就)
	return 筛选列表

func 按分类筛选成就(分类: String) -> Array:
	var 筛选列表 = []
	for 成就 in Game.成就配置:
		if 成就.get("分类", "") == 分类:
			筛选列表.append(成就)
	return 筛选列表

func 获取成就分类统计() -> Dictionary:
	var 分类统计 = {}
	for 分类 in 成就分类配置.keys():
		分类统计[分类] = {"总数": 0, "已达成数": 0, "完成率": 0.0}
	for 成就 in Game.成就配置:
		var 分类 = str(成就.get("分类", "特殊"))
		if 分类 not in 分类统计:
			分类统计[分类] = {"总数": 0, "已达成数": 0, "完成率": 0.0}
		分类统计[分类]["总数"] += 1
		if 成就.get("已达成", false):
			分类统计[分类]["已达成数"] += 1
	for 分类 in 分类统计.keys():
		var 统计 = 分类统计[分类]
		统计["完成率"] = float(统计["已达成数"]) / float(max(1, 统计["总数"]))
	return 分类统计

func 获取成就进度(成就ID: String) -> Dictionary:
	var 目标成就 = null
	for 成就 in Game.成就配置:
		if 成就.get("achievement_id", "") == 成就ID:
			目标成就 = 成就
			break
	if 目标成就 == null:
		return {"成功": false, "原因": "成就不存在"}
	if 目标成就.get("已达成", false):
		return {"成功": true, "已达成": true, "进度": 1.0, "当前值": 目标成就.get("condition_param", 0), "目标值": 目标成就.get("condition_param", 0)}
	var 条件类型 = str(目标成就.get("condition_type", ""))
	var 目标值 = float(目标成就.get("condition_param", 0))
	var 当前值 = 0.0
	match 条件类型:
		"弟子数量": 当前值 = float(Game.弟子列表.size())
		"门派等级": 当前值 = float(Game.门派等级)
		"声望": 当前值 = float(Game.声望)
		"累计灵石": 当前值 = float(Game.累计灵石收入)
		"累计丹药": 当前值 = float(Game.累计炼制丹药数)
		"累计装备": 当前值 = float(Game.累计锻造装备数)
		"灵兽数量": 当前值 = float(Game.灵兽管理系统.灵兽库存.size())
		"秘境通关": 当前值 = float(Game.已通关秘境.size())
		"阵法数量": 当前值 = float(Game.已解锁单人法阵.size())
		"功法数量":
			var 已学功法集合 = {}
			for d in Game.弟子列表:
				if d != null:
					var 弟子功法 = d.get("已学功法") if "已学功法" in d else []
					if 弟子功法 != null:
						for 功法 in 弟子功法:
							已学功法集合[功法.get("功法ID", "")] = true
			当前值 = float(已学功法集合.size())
		"trade_count": 当前值 = float(Game.商队系统.累计贸易次数)
		"trade_income": 当前值 = float(Game.商队系统.累计贸易收益)
		"world_regions": 当前值 = float(Game.世界地图系统.已探索区域数())
		"world_resource_collect": 当前值 = float(Game.世界地图系统.累计采集次数)
		"world_event": 当前值 = float(Game.世界地图系统.事件历史.size())
		"total_fish_caught": 当前值 = float(Game.灵钓系统.累计钓获次数)
		_: 当前值 = 0.0
	var 进度 = 0.0
	if 目标值 > 0:
		进度 = min(1.0, 当前值 / 目标值)
	return {"成功": true, "已达成": false, "成就ID": 成就ID, "名称": 目标成就.get("名称", ""),
		"条件类型": 条件类型, "当前值": 当前值, "目标值": 目标值, "进度": 进度, "剩余": max(0, 目标值 - 当前值)}

func 获取所有未达成成就进度() -> Array:
	var 进度列表 = []
	for 成就 in Game.成就配置:
		if not 成就.get("已达成", false):
			var 进度 = 获取成就进度(成就.get("achievement_id", ""))
			if 进度.get("成功", false):
				进度列表.append(进度)
	进度列表.sort_custom(func(a, b): return (a.get("进度") if "进度" in a else 0) > (b.get("进度") if "进度" in b else 0))
	return 进度列表

func 领取成就奖励(成就ID: String) -> Dictionary:
	var 目标成就 = null
	for 成就 in Game.成就配置:
		if 成就.get("achievement_id", "") == 成就ID:
			目标成就 = 成就
			break
	if 目标成就 == null:
		return {"成功": false, "原因": "成就不存在"}
	if not 目标成就.get("已达成", false):
		return {"成功": false, "原因": "成就未达成"}
	if 成就ID in 已领取成就奖励:
		return {"成功": false, "原因": "奖励已领取"}
	var 奖励灵石 = int(目标成就.get("奖励灵石", 0))
	var 奖励灵气 = int(目标成就.get("奖励灵气", 0))
	var 奖励声望 = int(目标成就.get("奖励声望", 0))
	Game.灵石 += 奖励灵石
	Game.灵气 += 奖励灵气
	if 奖励声望 > 0:
		Game._加声望(奖励声望)
	已领取成就奖励.append(成就ID)
	Game.添加纪事("成就", "领取奖励", "领取成就【%s】奖励：灵石+%d，灵气+%d，声望+%d" % [目标成就.get("名称", ""), 奖励灵石, 奖励灵气, 奖励声望], 1)
	return {"成功": true, "成就": 目标成就, "奖励灵石": 奖励灵石, "奖励灵气": 奖励灵气, "奖励声望": 奖励声望, "消息": "领取奖励成功"}

# ===== 成就核心逻辑 =====

func _复检成就():
	for a in Game.成就配置:
		if a.get("已达成") if "已达成" in a else false:
			continue
		var t: String = a.get("condition_type") if "condition_type" in a else "placeholder"
		if t == "placeholder":
			continue
		var p: int = int(a.get("condition_param") if "condition_param" in a else 0)
		var extra: String = a.get("condition_extra") if "condition_extra" in a else ""
		var 达成 := false
		match t:
			"sect_level": 达成 = Game.门派等级 >= p
			"disciple_count": 达成 = Game.弟子列表.size() >= p
			"disciple_realm_count":
				var cnt: int = 0
				for d in Game.弟子列表:
					if d != null and d.境界 == extra: cnt += 1
				达成 = cnt >= p
			"disciple_all_realm":
				if Game.弟子列表.size() > 0:
					var 境界顺序: Array = Disciple.境界序
					var 目标值: int = 境界顺序.find(extra)
					if 目标值 >= 0:
						var 全达成:= true
						for d in Game.弟子列表:
							if d == null or 境界顺序.find(d.境界) < 目标值:
								全达成= false; break
						达成 = 全达成
			"disciple_linggen":
				var cnt2: int = 0
				for d in Game.弟子列表:
					if d != null and d.灵根品阶 == extra: cnt2 += 1
				达成 = cnt2 >= p
			"master_realm": 达成 = Game.玄榜系统._宗主境界() >= p
			"beast_count": 达成 = Game.灵兽管理系统.灵兽库存.size() >= p
			"building_level":
				var lv: int = int(Game.司职列表.get(extra, {}).get("等级", 1))
				达成 = lv >= p
			"building_any_level":
				var any_ok := false
				for k in Game.司职列表.keys():
					if int(Game.司职列表[k].get("等级", 1)) >= p: any_ok = true; break
				达成 = any_ok
			"building_total_level":
				var total: int = 0
				for k in Game.司职列表.keys(): total += int(Game.司职列表[k].get("等级", 1))
				达成 = total >= p
			"reputation": 达成 = Game.声望 >= p
			"prosperity": 达成 = Game.繁荣 >= p
			"zhenfa_count":
				var 已解锁阵法: Dictionary = Game.宗门大阵.get("已解锁", {})
				达成 = 已解锁阵法.size() >= p
			"zhenfa_level":
				var 阵法等级表: Dictionary = Game.宗门大阵.get("等级", {})
				var 某阵法等级: int = int(阵法等级表.get(extra, 0))
				达成 = 某阵法等级 >= p
			"daily_checkin_streak": 达成 = Game.连续理事天数 >= p
			"daily_checkin_total": 达成 = Game.日供_总领取次数 >= p
			"achievement_count": 达成 = 成就_已达成.size() >= p
			"game_days": 达成 = Game.累计游戏日 >= p
			"total_pill_refined": 达成 = Game.累计炼制丹药数 >= p
			"total_equipment_forged": 达成 = Game.累计锻造装备数 >= p
			"total_lingjing_income": 达成 = Game.累计灵石收入 >= p
			"total_disciple_recruited": 达成 = Game.累计招募弟子数 >= p
			"total_breakthrough_count": 达成 = Game.累计弟子突破次数 >= p
			"total_market_trades": 达成 = Game.累计坊市交易次数 >= p
			"trade_count": 达成 = Game.商队系统.累计贸易次数 >= p
			"trade_income": 达成 = Game.商队系统.累计贸易收益 >= p
			"gongfa_collected":
				var 已学功法集合: Dictionary = {}
				for d in Game.弟子列表:
					if d != null:
						var 弟子功法 = d.get("已学功法") if "已学功法" in d else []
						if 弟子功法 != null:
							for gid in 弟子功法: 已学功法集合[gid] = true
				达成 = 已学功法集合.size() >= p
			"forge_level": 达成 = Game.炼丹炼器系统.获取炼器等级() >= p
			"total_lingtian_output": 达成 = Game.累计灵田产出 >= p
			"total_kuangchang_output": 达成 = Game.累计矿场产出 >= p
			"total_linggen_upgrade": 达成 = Game.累计提升灵根次数 >= p
			"total_xinjing_upgrade": 达成 = Game.累计提升心境次数 >= p
			"total_shouyuan_extend": 达成 = Game.累计延长寿元次数 >= p
			"total_daoshang_repair": 达成 = Game.累计修复道伤次数 >= p
			"disciple_max_xinjing":
				var 最高心境: int = 0
				for d in Game.弟子列表:
					if d != null:
						var 心境值: int = int(d.get("心境") if "心境" in d else 0)
						if 心境值 > 最高心境: 最高心境 = 心境值
				达成 = 最高心境 >= p
			"disciple_tixiu_count":
				var 体修数: int = 0
				for d in Game.弟子列表:
					if d != null and (d.get("修炼方向") if "修炼方向" in d else "") == "体修": 体修数 += 1
				达成 = 体修数 >= p
			"disciple_faxiu_count":
				var 法修数: int = 0
				for d in Game.弟子列表:
					if d != null and (d.get("修炼方向") if "修炼方向" in d else "") == "法修": 法修数 += 1
				达成 = 法修数 >= p
			"disciple_daoxiu_count":
				var 道修数: int = 0
				for d in Game.弟子列表:
					if d != null and (d.get("修炼方向") if "修炼方向" in d else "") == "道修": 道修数 += 1
				达成 = 道修数 >= p
			"disciple_three_cultivation":
				var 有体修: bool = false
				var 有法修: bool = false
				var 有道修: bool = false
				var 境界顺序: Array = Disciple.境界序
				var 目标境界索引: int = 1
				for d in Game.弟子列表:
					if d != null:
						var 方向: String = str(d.get("修炼方向") if "修炼方向" in d else "")
						var 境界索引: int = 境界顺序.find(d.境界)
						if 境界索引 >= 目标境界索引:
							if 方向 == "体修": 有体修 = true
							elif 方向 == "法修": 有法修 = true
							elif 方向 == "道修": 有道修 = true
				达成 = 有体修 and 有法修 and 有道修
			"disciple_max_realm":
				var 最高境界索引: int = -1
				var 境界顺序2: Array = Disciple.境界序
				for d in Game.弟子列表:
					if d != null:
						var idx: int = 境界顺序2.find(d.境界)
						if idx > 最高境界索引: 最高境界索引 = idx
				达成 = 最高境界索引 >= p
			"disciple_dajingjie_count":
				var 大境界数: int = 0
				var 境界顺序3: Array = Disciple.境界序
				for d in Game.弟子列表:
					if d != null:
						var idx: int = 境界顺序3.find(d.境界)
						if idx >= 1: 大境界数 += 1
				达成 = 大境界数 >= p
			"total_puppet_made": 达成 = Game.傀儡系统.累计制作傀儡数 >= p
			"total_salary_paid": 达成 = Game.累计发放俸禄次数 >= p
			"library_book_count": 达成 = Game.藏书阁系统.藏书阁收录数 >= p
			"medicine_garden_plots": 达成 = Game.药园系统.药园已解锁地块 >= p
			"unlocked_pill_formula_count": 达成 = Game.已解锁丹方数 >= p
			"unlocked_equipment_blueprint_count": 达成 = Game.已解锁装备图纸数 >= p
			"all_factions_worship":
				var 全部崇拜: bool = true
				for 阵营 in Game.阵营列表:
					var 声望值: int = int(Game.阵营声望系统.阵营声望.get(阵营, 0))
					if 声望值 < 5000: 全部崇拜 = false; break
				达成 = 全部崇拜
			"pill_and_equipment_all":
				达成 = (Game.已解锁丹方数 >= p) and (Game.已解锁装备图纸数 >= p)
			"world_regions": 达成 = Game.世界地图系统.已探索区域数() >= p
			"world_resource_collect": 达成 = Game.世界地图系统.累计采集次数 >= p
			"world_event": 达成 = Game.世界地图系统.事件历史.size() >= p
			"total_fish_caught": 达成 = Game.灵钓系统.累计钓获次数 >= p
			_: 达成 = false
		if 达成:
			_达成成就(a)

func _达成成就(a: Dictionary):
	a["已达成"] = true
	Game.记任务进度("achievement_unlock")
	var id: String = a.get("achievement_id") if "achievement_id" in a else ""
	if id != "" and not 成就_已达成.has(id):
		成就_已达成.append(id)
	var rls: int = int(a.get("reward_lingshi") if "reward_lingshi" in a else 0)
	var rlq: int = int(a.get("reward_lingqi") if "reward_lingqi" in a else 0)
	var rsw: int = int(a.get("reward_shengwang") if "reward_shengwang" in a else 0)
	if rls > 0: Game.灵石 += rls
	if rlq > 0: Game.灵气 += rlq
	if rsw > 0: Game._加声望(rsw)
	var rid: String = a.get("reward_id") if "reward_id" in a else ""
	if rid != "" and rls == 0 and rlq == 0 and rsw == 0:
		print("[成就] 悬空奖励跳过: id=%s reward_type=%s reward_id=%s S2 待启用" % [id, a.get("reward_type") if "reward_type" in a else "", rid])
	var grade: String = a.get("grade") if "grade" in a else ""
	if grade == "稀有":
		Game.碎片宝箱系统.添加宝箱("chest_common", 1)
		Game.碎片宝箱系统.添加碎片("frag_equip_common", 3)
	elif grade == "史诗":
		Game.碎片宝箱系统.添加宝箱("chest_rare", 1)
		Game.碎片宝箱系统.添加碎片("frag_equip_rare", 3)
	elif grade == "传说":
		Game.碎片宝箱系统.添加宝箱("chest_epic", 1)
		Game.碎片宝箱系统.添加碎片("frag_equip_epic", 3)
		Game.碎片宝箱系统.添加碎片("frag_gongfa_rare", 2)
	if grade == "稀有" or grade == "史诗" or grade == "传说":
		Game.宗门纪事.append({"日期": Game.累计游戏日, "弟子": "", "稀有度": grade, "名称": a.get("ach_name") if "ach_name" in grade else "",
			"文案": "宗门达成%s】，道统更进一步" % a.get("ach_name") if "ach_name" in grade else "",
			"category": "宗门大事件"})
	Game.成就更新.emit()
	# S55：Steam风格成就弹窗
	var ach_name: String = str(a.get("ach_name") if "ach_name" in a else "")
	var ach_desc: String = str(a.get("ach_desc") if "ach_desc" in a else "")
	var 图标色: Color = Color(0.9, 0.7, 0.2)  # 默认金色
	match grade:
		"普通":
			图标色 = Color(0.6, 0.6, 0.6)  # 灰色
		"稀有":
			图标色 = Color(0.2, 0.6, 0.9)  # 蓝色
		"史诗":
			图标色 = Color(0.7, 0.3, 0.9)  # 紫色
		"传说":
			图标色 = Color(0.95, 0.6, 0.1)  # 橙色
	AchievementPopup.show_achievement("功绩堂", ach_name, ach_desc, 图标色)

func _里程碑奖励描述(m: Dictionary) -> String:
	var t: String = str(m.get("赏赐增益类型") if "赏赐增益类型" in m else "")
	var v: float = float(m.get("赏赐增益值") if "赏赐增益值" in m else 0)
	if t == "声望": return "声望+%d" % int(v)
	elif t == "产出": return "产出：%d%%" % int(v * 100)
	return "宗门增益"

func _存在已筑基弟子() -> bool:
	for d in Game.弟子列表:
		if d.境界 != "练气": return true
	return false

func _存在长老() -> bool:
	for d in Game.弟子列表:
		if d.身份 == "长老": return true
	return false

func _存在长寿弟子() -> bool:
	for d in Game.弟子列表:
		if d.年龄 >= 100: return true
	return false

# 序列化
func to_dict() -> Dictionary:
	return {
		"成就_已达成": 成就_已达成,
		"已领取成就奖励": 已领取成就奖励,
	}

# 反序列化
func from_dict(data: Dictionary) -> void:
	成就_已达成 = data.get("成就_已达成", [])
	已领取成就奖励 = data.get("已领取成就奖励", [])

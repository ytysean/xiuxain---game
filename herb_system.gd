class_name HerbSystem
extends RefCounted

# 药圃经营系统 - 休闲玩法（灵植种植子玩法）S50-P0/P1/P2/P3
# 后端：放置型产出，产丹材入库房反哺炼丹，零触碰战斗核心
# 四分层：灵植产出 / 杂草枯苗 / 灵植异种 / 万年灵根
# P1：灵植境界（5重）成长线，加成异种/灵根概率 + 年份升档
# P2：灵肥（年份档+1）/引灵露（提异种率）构成消耗品 sink 闭环
# P3：灵植博览周常（评比排行·威望奖励）+ 灵植志图录
# 数值全部 [PLACEHOLDER·待实机调]，不升 SAVE_VERSION

const Item = preload("res://item.gd")

const 年份档表: Array = ["一年生", "十年生", "百年", "千年", "万年", "十万年"]

const 灵植境界表: Array = [
	{"名": "药农学徒", "经验": 0, "加成": 0.0, "解锁": "基础灵植"},
	{"名": "药农", "经验": 300, "加成": 0.10, "解锁": "中级/灵田扩建"},
	{"名": "大药农", "经验": 1000, "加成": 0.25, "解锁": "高级/异种培育"},
	{"名": "灵植宗师", "经验": 3000, "加成": 0.40, "解锁": "传说/万年灵根"},
	{"名": "药道仙师", "经验": 8000, "加成": 0.60, "解锁": "仙草/九转灵根"},
]

const 周常规则表: Array = [
	{"名称": "年份之最", "描述": "一周种植年份登顶", "奖励威望": 15},
	{"名称": "品类齐全", "描述": "集齐当周灵植品类", "奖励威望": 20},
	{"名称": "异种大观", "描述": "异种探得数登顶", "奖励威望": 30},
	{"名称": "灵根秘藏", "描述": "万年灵根探得数登顶", "奖励威望": 35},
	{"名称": "灵韵累计", "描述": "灵韵累计排行", "奖励威望": 22},
]

var 产出表: Array = []
var 消耗品表: Array = []
var 累计种植次数: int = 0
var 灵植境界: int = 0
var 灵植经验: int = 0
var 本周观博参与: int = 0
var 上周观博周序: int = -1
var 本周异种数: int = 0
var 本周灵根数: int = 0
var 本周种植次数: int = 0

func _init() -> void:
	加载配置()

func 加载配置() -> void:
	if 产出表.is_empty():
		产出表 = DestinyDataLoader._read_csv("res://config/herb_plant.csv")
	if 消耗品表.is_empty():
		消耗品表 = DestinyDataLoader._read_csv("res://config/herb_consumable.csv")

func 灵植加成() -> float:
	if 灵植境界 < 0 or 灵植境界 >= 灵植境界表.size():
		return 0.0
	return float(灵植境界表[灵植境界].get("加成", 0.0))

func 灵植境界名() -> String:
	if 灵植境界 < 0 or 灵植境界 >= 灵植境界表.size():
		return ""
	return 灵植境界表[灵植境界].get("名", "")

func 灵植进度() -> Dictionary:
	if 灵植境界 >= 灵植境界表.size() - 1:
		return {"已得": 灵植经验, "需": 灵植经验, "满": true}
	var 需: int = int(灵植境界表[灵植境界 + 1].get("经验", 0))
	return {"已得": 灵植经验, "需": 需, "满": false}

func 增加灵植经验(增: int) -> bool:
	if 增 <= 0:
		return false
	灵植经验 += 增
	var 突破: bool = false
	while 灵植境界 < 灵植境界表.size() - 1 and 灵植经验 >= int(灵植境界表[灵植境界 + 1].get("经验", 0)):
		灵植境界 += 1
		突破 = true
		if Game != null:
			Game.添加纪事("灵植突破", "药圃修为精进至【%s】，可育更深灵植。" % 灵植境界表[灵植境界].get("名", ""))
	return 突破

func 消耗品配置(名: String) -> Dictionary:
	for c in 消耗品表:
		if c.get("名", "") == 名:
			return c
	return {}

func 库房计数(名: String) -> int:
	var n: int = 0
	if Game != null:
		for it in Game.宗门库房:
			if it.名称 == 名:
				n += 1
	return n

func _扣库房(名: String, 数: int) -> bool:
	var 剩: int = 数
	if Game != null:
		for i in range(Game.宗门库房.size() - 1, -1, -1):
			if Game.宗门库房[i].名称 == 名 and 剩 > 0:
				Game.宗门库房.remove_at(i)
				剩 -= 1
	return 剩 == 0

func 求购消耗品(名: String) -> Dictionary:
	var c: Dictionary = 消耗品配置(名)
	if c.is_empty():
		return {"成功": false, "原因": "无此消耗品"}
	var 价: int = int(c.get("价格", 0))
	if Game == null or Game.灵石 < 价:
		return {"成功": false, "原因": "灵石不足（需 %d）" % 价}
	Game.灵石 -= 价
	var it: Item = Item.new()
	it.类别 = "消耗品"
	it.名称 = 名
	it.品阶 = "凡阶"
	it.描述 = c.get("效果", "")
	it.功效 = "药圃经营辅助"
	if Game != null:
		Game.宗门库房.append(it)
	return {"成功": true, "名称": 名, "价": 价}

func 观博周序() -> int:
	if Game == null:
		return 0
	return int(Game.累计游戏日 / 7) % 周常规则表.size()

func 获取本周观博周() -> Dictionary:
	return 周常规则表[观博周序()]

func 参与观博周() -> Dictionary:
	var 周: int = 观博周序()
	if 周 != 上周观博周序:
		上周观博周序 = 周
		本周观博参与 = 0
	if 本周观博参与 >= 3:
		return {"成功": false, "原因": "本周已参与（上限3，防通胀）"}
	var 规: Dictionary = 获取本周观博周()
	var 威望: int = int(规.get("奖励威望", 10))
	if Game != null:
		Game.宗主威望 += 威望
	本周观博参与 += 1
	if Game != null:
		Game.添加纪事("灵植博览", "周赛", "参与本周灵植博览【%s】，获宗主威望 %d。" % [规.get("名称", ""), 威望], 1)
	return {"成功": true, "规则": 规.get("名称"), "威望": 威望, "参与": 本周观博参与}

func 结算种植(用灵肥: bool = false, 用引灵露: bool = false) -> Dictionary:
	if 产出表.is_empty():
		return {"成功": false, "原因": "产出表未加载"}
	var 加成: float = 灵植加成()
	if 用引灵露 and 库房计数("引灵露") > 0:
		加成 += float(消耗品配置("引灵露").get("数值", 0.0))
		_扣库房("引灵露", 1)
	var crop: Dictionary = _抽作物(加成)
	var 名: String = crop.get("产出名", "未知")
	var 分层: String = crop.get("分层", "灵植产出")
	var 品阶: String = crop.get("品阶", "凡阶")
	var 描: String = crop.get("描述", "")
	var 用: String = crop.get("用途", "")
	# 年份档：基础 + 灵肥 + 灵植境界小概率升档
	var 档: int = int(crop.get("年份档", 0))
	if 用灵肥 and 库房计数("灵肥") > 0:
		档 += 1
		_扣库房("灵肥", 1)
	if randf() < 灵植加成() * 0.5:
		档 += 1
	档 = mini(档, 年份档表.size() - 1)
	var 年名: String = 年份档表[档]
	if Game != null:
		Game._记录图录(名, "灵植")
	var it: Item = Item.new()
	it.类别 = "ling_cai"
	it.品阶 = 品阶
	it.名称 = 名
	it.描述 = "%s%s，%s" % [年名, 名, 描]
	it.功效 = 用
	if Game != null:
		Game.宗门库房.append(it)
	累计种植次数 += 1
	本周种植次数 += 1
	var 异: bool = (分层 == "灵植异种")
	if 异:
		本周异种数 += 1
	var 根: bool = (分层 == "万年灵根")
	if 根:
		本周灵根数 += 1
	var 增经验: int = 12
	if 异:
		增经验 += 20
	if 根:
		增经验 += 40
	if 分层 == "杂草枯苗":
		增经验 = 3
	var 突破: bool = 增加灵植经验(增经验)
	return {"成功": true, "名称": 名, "分层": 分层, "品阶": 品阶, "年份": 年名, "描述": 描, "用途": 用, "异种": 异, "灵根": 根, "经验": 增经验, "境界突破": 突破, "提示": ""}

func _抽作物(加成: float = 0.0) -> Dictionary:
	if 产出表.is_empty():
		return {"产出名": "未知", "分层": "灵植产出", "品阶": "凡阶", "描述": "", "用途": "", "年份档": 0, "掉落权重": 1}
	var 加权: Array = []
	var total: float = 0.0
	for r in 产出表:
		var w: float = float(r.get("掉落权重", 1.0))
		var 层: String = r.get("分层", "")
		if 层 == "灵植异种" or 层 == "万年灵根":
			w *= (1.0 + 加成)
			加权.append({"r": r, "w": w})
			total += w
		else:
			加权.append({"r": r, "w": w})
			total += w
	if 加权.is_empty():
		return 产出表[0]
	var roll: float = randf() * total
	var pick: Dictionary = 加权[0]["r"]
	for e in 加权:
		roll -= e["w"]
		if roll <= 0.0:
			pick = e["r"]
			break
	return pick

func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["累计种植次数"] = 累计种植次数
	data["灵植境界"] = 灵植境界
	data["灵植经验"] = 灵植经验
	data["本周观博参与"] = 本周观博参与
	data["上周观博周序"] = 上周观博周序
	data["本周异种数"] = 本周异种数
	data["本周灵根数"] = 本周灵根数
	data["本周种植次数"] = 本周种植次数
	return data

func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	累计种植次数 = int(data.get("累计种植次数", 0))
	灵植境界 = int(data.get("灵植境界", 0))
	灵植经验 = int(data.get("灵植经验", 0))
	本周观博参与 = int(data.get("本周观博参与", 0))
	上周观博周序 = int(data.get("上周观博周序", -1))
	本周异种数 = int(data.get("本周异种数", 0))
	本周灵根数 = int(data.get("本周灵根数", 0))
	本周种植次数 = int(data.get("本周种植次数", 0))

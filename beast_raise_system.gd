class_name BeastRaiseSystem
extends RefCounted

# 饲灵育兽系统 - 休闲玩法（灵兽养成子玩法）S48-P0/P1/P2/P3
# 后端：纯产出型，接灵兽/育兽 sink，零触碰战斗核心
# 四分层：灵兽产出 / 幼兽变异 / 兽魂 / 灵兽奇遇蛋
# P1：御兽境界（5重）成长线，加成稀有分层概率
# P2：嗜好食（提稀有率）/驯养鞭（提兽魂率）构成消耗品 sink 闭环
# P3：灵兽斗周常（擂台零死亡·威望奖励）+ 受控奇遇
# 数值全部 [PLACEHOLDER·待实机调]，不升 SAVE_VERSION

const Item = preload("res://item.gd")

const 御兽境界表: Array = [
	{"名": "御兽学徒", "经验": 0, "加成": 0.0, "解锁": "基础灵兽"},
	{"名": "兽师", "经验": 300, "加成": 0.10, "解锁": "中级灵兽/灵兽斗"},
	{"名": "大兽师", "经验": 1000, "加成": 0.25, "解锁": "高级/变异种"},
	{"名": "御兽宗师", "经验": 3000, "加成": 0.40, "解锁": "传说灵兽/化形"},
	{"名": "万兽仙尊", "经验": 8000, "加成": 0.60, "解锁": "仙兽/神兽苗"},
]

const 周常规则表: Array = [
	{"名称": "灵兽竞美", "描述": "一周内饲育所得灵兽产出登顶", "奖励威望": 15},
	{"名称": "最古血脉", "描述": "探得最古血脉排行", "奖励威望": 18},
	{"名称": "品类齐全", "描述": "集齐当周灵兽品类", "奖励威望": 20},
	{"名称": "兽魂汇聚", "描述": "汇聚兽魂数登顶", "奖励威望": 30},
	{"名称": "驯养积分", "描述": "驯养积分累计", "奖励威望": 22},
]

var 饲灵产出表: Array = []
var 消耗品表: Array = []
var 累计饲灵次数: int = 0
var 御兽境界: int = 0
var 御兽经验: int = 0
var 本周探兽参与: int = 0
var 上周探兽周序: int = -1
var 本周变异数: int = 0
var 本周饲灵次数: int = 0

func _init() -> void:
	加载配置()

func 加载配置() -> void:
	if 饲灵产出表.is_empty():
		饲灵产出表 = DestinyDataLoader._read_csv("res://config/beast_raise.csv")
	if 消耗品表.is_empty():
		消耗品表 = DestinyDataLoader._read_csv("res://config/beast_raise_consumable.csv")

func 御兽加成() -> float:
	if 御兽境界 < 0 or 御兽境界 >= 御兽境界表.size():
		return 0.0
	return float(御兽境界表[御兽境界].get("加成", 0.0))

func 御兽境界名() -> String:
	if 御兽境界 < 0 or 御兽境界 >= 御兽境界表.size():
		return ""
	return 御兽境界表[御兽境界].get("名", "")

func 御兽进度() -> Dictionary:
	if 御兽境界 >= 御兽境界表.size() - 1:
		return {"已得": 御兽经验, "需": 御兽经验, "满": true}
	var 需: int = int(御兽境界表[御兽境界 + 1].get("经验", 0))
	return {"已得": 御兽经验, "需": 需, "满": false}

func 增加御兽经验(增: int) -> bool:
	if 增 <= 0:
		return false
	御兽经验 += 增
	var 突破: bool = false
	while 御兽境界 < 御兽境界表.size() - 1 and 御兽经验 >= int(御兽境界表[御兽境界 + 1].get("经验", 0)):
		御兽境界 += 1
		突破 = true
		if Game != null:
			Game.添加纪事("御兽突破", "御兽修为精进至【%s】，可驯更深灵兽。" % 御兽境界表[御兽境界].get("名", ""))
	return 突破

func 开始饲灵(动作: String = "饲灵") -> Dictionary:
	# [PLACEHOLDER·待实机调] 动作影响（喂食/抚摸/驯养）
	return {"动作": 动作, "提示": "灵兽亲昵"}

# ---- P2 消耗品 ----
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
	it.功效 = "饲灵育兽辅助"
	if Game != null:
		Game.宗门库房.append(it)
	return {"成功": true, "名称": 名, "价": 价}

# ---- P3 周常灵兽斗 ----
func 探兽周序() -> int:
	if Game == null:
		return 0
	return int(Game.累计游戏日 / 7) % 周常规则表.size()

func 获取本周探兽周() -> Dictionary:
	return 周常规则表[探兽周序()]

func 参与探兽周() -> Dictionary:
	var 周: int = 探兽周序()
	if 周 != 上周探兽周序:
		上周探兽周序 = 周
		本周探兽参与 = 0
	if 本周探兽参与 >= 3:
		return {"成功": false, "原因": "本周已参与（上限3，防通胀）"}
	var 规: Dictionary = 获取本周探兽周()
	var 威望: int = int(规.get("奖励威望", 10))
	if Game != null:
		Game.宗主威望 += 威望
	本周探兽参与 += 1
	if Game != null:
		Game.添加纪事("灵兽斗周赛", "周赛", "参与本周灵兽斗周赛【%s】，获宗主威望 %d。" % [规.get("名称", ""), 威望], 1)
	return {"成功": true, "规则": 规.get("名称"), "威望": 威望, "参与": 本周探兽参与}

func 结算饲灵(动作: String = "饲灵", 用嗜好食: bool = false, 用驯养鞭: bool = false) -> Dictionary:
	if 饲灵产出表.is_empty():
		return {"成功": false, "原因": "饲灵产出表未加载"}
	var 变异加成: float = 御兽加成()
	var 兽魂加成: float = 御兽加成()
	if 用嗜好食 and 库房计数("嗜好食") > 0:
		变异加成 += float(消耗品配置("嗜好食").get("数值", 0.0))
		_扣库房("嗜好食", 1)
	if 用驯养鞭 and 库房计数("驯养鞭") > 0:
		兽魂加成 += float(消耗品配置("驯养鞭").get("数值", 0.0))
		_扣库房("驯养鞭", 1)
	var pick: Dictionary = _抽产出(变异加成, 兽魂加成)
	var 名称: String = pick.get("名称", "未知")
	var 分层: String = pick.get("分层", "灵兽产出")
	var 品阶: String = pick.get("品阶", "凡阶")
	var 描述: String = pick.get("描述", "")
	var 用途: String = pick.get("用途", "")
	if Game != null:
		Game._记录图录(名称, "灵兽")
	var it: Item = Item.new()
	it.类别 = "ling_cai"
	it.品阶 = 品阶
	it.名称 = 名称
	it.描述 = 描述
	it.功效 = 用途
	if Game != null:
		Game.宗门库房.append(it)
	累计饲灵次数 += 1
	本周饲灵次数 += 1
	var 变异: bool = (分层 == "幼兽变异")
	if 变异:
		本周变异数 += 1
	var 增经验: int = 15
	if 变异:
		增经验 += 25
	if 分层 == "兽魂":
		增经验 += 20
	if 分层 == "灵兽奇遇蛋":
		增经验 += 40
	var 突破: bool = 增加御兽经验(增经验)
	# 受控奇遇（禁自建池）[PLACEHOLDER 触发率 0.03]
	if randf() < 0.03:
		if Game != null:
			Game._尝试触发奇遇(Game.宗主, "饲灵育兽")
	return {"成功": true, "名称": 名称, "分层": 分层, "品阶": 品阶, "描述": 描述, "用途": 用途, "变异": 变异, "经验": 增经验, "境界突破": 突破, "提示": ""}

func _抽产出(变异加成: float = 0.0, 兽魂加成: float = 0.0) -> Dictionary:
	if 饲灵产出表.is_empty():
		return {"名称": "未知", "分层": "灵兽产出", "品阶": "凡阶", "描述": "", "用途": ""}
	var 加权: Array = []
	var total: float = 0.0
	for r in 饲灵产出表:
		var w: float = float(r.get("掉落权重", 1.0))
		var 层: String = r.get("分层", "")
		if 层 == "幼兽变异":
			w *= (1.0 + 变异加成)
			加权.append({"r": r, "w": w})
			total += w
		elif 层 == "兽魂":
			w *= (1.0 + 兽魂加成)
			加权.append({"r": r, "w": w})
			total += w
		elif 层 == "灵兽奇遇蛋":
			w *= (1.0 + max(变异加成, 兽魂加成) * 0.5)
			加权.append({"r": r, "w": w})
			total += w
		else:
			加权.append({"r": r, "w": w})
			total += w
	return _抽自(加权, total)

func _抽自(加权: Array, total: float) -> Dictionary:
	if 加权.is_empty():
		return {"名称": "未知", "分层": "灵兽产出", "品阶": "凡阶", "描述": "", "用途": ""}
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
	data["累计饲灵次数"] = 累计饲灵次数
	data["御兽境界"] = 御兽境界
	data["御兽经验"] = 御兽经验
	data["本周探兽参与"] = 本周探兽参与
	data["上周探兽周序"] = 上周探兽周序
	data["本周变异数"] = 本周变异数
	data["本周饲灵次数"] = 本周饲灵次数
	return data

func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	累计饲灵次数 = int(data.get("累计饲灵次数", 0))
	御兽境界 = int(data.get("御兽境界", 0))
	御兽经验 = int(data.get("御兽经验", 0))
	本周探兽参与 = int(data.get("本周探兽参与", 0))
	上周探兽周序 = int(data.get("上周探兽周序", -1))
	本周变异数 = int(data.get("本周变异数", 0))
	本周饲灵次数 = int(data.get("本周饲灵次数", 0))

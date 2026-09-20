class_name RelicSystem
extends RefCounted

# 探遗迹系统 - 休闲玩法（探秘型子玩法）S47-P0/P1/P2/P3
# 后端：纯产出型，接主链（天材地宝->炼器/炼丹 sink），零触碰战斗核心
# 交互：破阵参悟——择遗迹/参悟阵法（单指点按），按难度+阵道加成算成功率，失败零惩罚
# P2：破阵符（降难度·灵石求购）/引灵香（提秘藏率）构成消耗品 sink 闭环
# P3：周常探秘周（周序轮换·奖励威望·禁暴灵石·每周上限节流）+ 受控奇遇
# 数值全部 [PLACEHOLDER·待实机调]，不升 SAVE_VERSION

const Item = preload("res://item.gd")

const 阵道境界表: Array = [
	{"名": "阵道学徒", "经验": 0, "加成": 0.0, "解锁": "基础遗迹"},
	{"名": "阵师", "经验": 300, "加成": 0.10, "解锁": "中级遗迹"},
	{"名": "大阵师", "经验": 1000, "加成": 0.25, "解锁": "高级/上古遗迹"},
	{"名": "阵道宗师", "经验": 3000, "加成": 0.40, "解锁": "传说遗迹"},
	{"名": "阵道仙师", "经验": 8000, "加成": 0.60, "解锁": "仙迹/上古仙阵"},
]

const 周常规则表: Array = [
	{"名称": "集齐残卷", "描述": "一周内探秘所得残阵残卷登顶", "奖励威望": 15},
	{"名称": "最古遗存", "描述": "探得最古遗存排行", "奖励威望": 18},
	{"名称": "品类齐全", "描述": "集齐当周遗迹品类", "奖励威望": 20},
	{"名称": "秘藏开启", "描述": "开启秘藏数登顶", "奖励威望": 30},
	{"名称": "阵法难度积分", "描述": "阵法难度积分累计", "奖励威望": 22},
]

var 探秘产出表: Array = []
var 遗迹表: Array = []
var 消耗品表: Array = []
var 累计探秘次数: int = 0
var 阵道境界: int = 0
var 阵道经验: int = 0
var 本周探秘参与: int = 0
var 上周探秘周序: int = -1
var 本周秘藏数: int = 0
var 本周探秘次数: int = 0

func _init() -> void:
	加载探秘配置()

func 加载探秘配置() -> void:
	if 探秘产出表.is_empty():
		探秘产出表 = DestinyDataLoader._read_csv("res://config/relic_expedition.csv")
	if 遗迹表.is_empty():
		遗迹表 = DestinyDataLoader._read_csv("res://config/relic_site.csv")
	if 消耗品表.is_empty():
		消耗品表 = DestinyDataLoader._read_csv("res://config/relic_consumable.csv")

func 阵道加成() -> float:
	if 阵道境界 < 0 or 阵道境界 >= 阵道境界表.size():
		return 0.0
	return float(阵道境界表[阵道境界].get("加成", 0.0))

func 阵道境界名() -> String:
	if 阵道境界 < 0 or 阵道境界 >= 阵道境界表.size():
		return ""
	return 阵道境界表[阵道境界].get("名", "")

func 阵道进度() -> Dictionary:
	if 阵道境界 >= 阵道境界表.size() - 1:
		return {"已得": 阵道经验, "需": 阵道经验, "满": true}
	var 需: int = int(阵道境界表[阵道境界 + 1].get("经验", 0))
	return {"已得": 阵道经验, "需": 需, "满": false}

func 增加阵道经验(增: int) -> bool:
	if 增 <= 0:
		return false
	阵道经验 += 增
	var 突破: bool = false
	while 阵道境界 < 阵道境界表.size() - 1 and 阵道经验 >= int(阵道境界表[阵道境界 + 1].get("经验", 0)):
		阵道境界 += 1
		突破 = true
		if Game != null:
			Game.添加纪事("阵道突破", "阵道修为精进至【%s】，可探更深遗迹。" % 阵道境界表[阵道境界].get("名", ""))
	return 突破

func 遗迹数() -> int:
	return 遗迹表.size()

func 可探遗迹(索引: int) -> Dictionary:
	if 索引 < 0 or 索引 >= 遗迹表.size():
		return {"可探": false, "原因": "无此遗迹"}
	var s: Dictionary = 遗迹表[索引]
	var 需求: int = int(s.get("需求阵道境界", 0))
	var 可探: bool = 阵道境界 >= 需求
	var 成功率: float = _算成功率(s)
	return {
		"可探": 可探,
		"名称": s.get("遗迹名", ""),
		"类型": s.get("类型", ""),
		"阵法": s.get("阵法", ""),
		"难度星": int(s.get("难度星", 1)),
		"需求境界": 需求,
		"需求境界名": 阵道境界表[需求].get("名", "") if 需求 < 阵道境界表.size() else "",
		"秘藏数": int(s.get("秘藏数", 0)),
		"成功率": 成功率,
		"原因": ("阵道境界不足，需【%s】" % 阵道境界表[需求].get("名", "")) if not 可探 else "",
	}

func _算成功率(s: Dictionary) -> float:
	# [PLACEHOLDER·待实机调] 难度星越高成功率越低，阵道加成提升
	var 难度: int = int(s.get("难度星", 1))
	var 基础: float = 0.92 - (难度 - 1) * 0.08
	var 率: float = 基础 + 阵道加成()
	return clamp(率, 0.10, 0.95)

func 开始探秘(索引: int) -> Dictionary:
	return 可探遗迹(索引)

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
	it.功效 = "探遗迹辅助"
	if Game != null:
		Game.宗门库房.append(it)
	return {"成功": true, "名称": 名, "价": 价}

func 配制破阵符(用: bool) -> Dictionary:
	if not 用:
		return {"成功": true, "用": false}
	if 库房计数("破阵符") <= 0:
		return {"成功": false, "原因": "未持破阵符，可求购"}
	return {"成功": true, "用": true}

func 配制引灵香(用: bool) -> Dictionary:
	if not 用:
		return {"成功": true, "用": false}
	if 库房计数("引灵香") <= 0:
		return {"成功": false, "原因": "未持引灵香，可求购"}
	return {"成功": true, "用": true}

# ---- P3 周常探秘周 ----
func 探秘周序() -> int:
	if Game == null:
		return 0
	return int(Game.累计游戏日 / 7) % 周常规则表.size()

func 获取本周探秘周() -> Dictionary:
	return 周常规则表[探秘周序()]

func 参与探秘周() -> Dictionary:
	var 周: int = 探秘周序()
	if 周 != 上周探秘周序:
		上周探秘周序 = 周
		本周探秘参与 = 0
	if 本周探秘参与 >= 3:
		return {"成功": false, "原因": "本周已参与（上限3，防通胀）"}
	var 规: Dictionary = 获取本周探秘周()
	var 威望: int = int(规.get("奖励威望", 10))
	if Game != null:
		Game.宗主威望 += 威望
	本周探秘参与 += 1
	if Game != null:
		Game.添加纪事("探秘周赛", "周赛", "参与本周探秘周赛【%s】，获宗主威望 %d。" % [规.get("名称", ""), 威望], 1)
	return {"成功": true, "规则": 规.get("名称"), "威望": 威望, "参与": 本周探秘参与}

func 结算探秘(索引: int, 用符: bool = false, 用香: bool = false) -> Dictionary:
	var 信息: Dictionary = 可探遗迹(索引)
	if not 信息.get("可探", false):
		return {"成功": false, "原因": 信息.get("原因", "不可探")}
	var 成功率: float = float(信息.get("成功率", 0.5))
	if 用符 and 库房计数("破阵符") > 0:
		成功率 += float(消耗品配置("破阵符").get("数值", 0.0))
		_扣库房("破阵符", 1)
	var 秘藏率: float = float(遗迹表[索引].get("秘藏率", 0.0))
	if 用香 and 库房计数("引灵香") > 0:
		秘藏率 += float(消耗品配置("引灵香").get("数值", 0.0))
		_扣库房("引灵香", 1)
	成功率 = clamp(成功率, 0.10, 0.97)
	if randf() > 成功率:
		return {"成功": true, "破阵": false, "名称": "", "分层": "", "品阶": "", "描述": "", "用途": "", "秘藏": false, "秘藏名": "", "传承": false, "经验": 0, "境界突破": false, "提示": "阵法紊乱，参悟未成，然无损伤。"}
	var pick: Dictionary = _抽产出()
	var 名称: String = pick.get("名称", "未知遗珍")
	var 分层: String = pick.get("分层", "天材")
	var 品阶: String = pick.get("品阶", "凡阶")
	var 描述: String = pick.get("描述", "")
	var 用途: String = pick.get("用途", "")
	if Game != null:
		Game._记录图录(名称, "探遗迹")
	var it: Item = Item.new()
	it.类别 = "ling_cai"
	it.品阶 = 品阶
	it.名称 = 名称
	it.描述 = 描述
	it.功效 = 用途
	if Game != null:
		Game.宗门库房.append(it)
	累计探秘次数 += 1
	本周探秘次数 += 1
	var 秘藏: bool = false
	var 秘藏名: String = ""
	var 传承: bool = false
	var s: Dictionary = 遗迹表[索引]
	if randf() < 秘藏率:
		秘藏 = true
		本周秘藏数 += 1
		秘藏名 = _抽秘藏()
		if 秘藏名 != "":
			var 秘item: Item = Item.new()
			秘item.类别 = "ling_cai"
			秘item.品阶 = "仙阶"
			秘item.名称 = 秘藏名
			秘item.描述 = "遗迹秘藏所得"
			秘item.功效 = "开启得天材地宝"
			if Game != null:
				Game.宗门库房.append(秘item)
			if Game != null:
				Game._记录图录(秘藏名, "探遗迹")
		if randf() < float(s.get("传承率", 0.0)):
			传承 = true
			if Game != null:
				Game.添加纪事("上古传承", "于【%s】深处窥得上古传承残篇，机缘难得！" % s.get("遗迹名", ""))
	var 增经验: int = 20
	if 秘藏:
		增经验 += 30
	if 传承:
		增经验 += 80
	var 突破: bool = 增加阵道经验(增经验)
	# 受控奇遇（禁自建池）[PLACEHOLDER 触发率 0.03]
	if randf() < 0.03:
		if Game != null:
			Game._尝试触发奇遇(Game.宗主, "探遗迹")
	return {"成功": true, "破阵": true, "名称": 名称, "分层": 分层, "品阶": 品阶, "描述": 描述, "用途": 用途, "秘藏": 秘藏, "秘藏名": 秘藏名, "传承": 传承, "经验": 增经验, "境界突破": 突破, "提示": ""}

func _抽产出() -> Dictionary:
	if 探秘产出表.is_empty():
		return {"名称": "未知遗珍", "分层": "天材", "品阶": "凡阶", "描述": "", "用途": ""}
	var total: float = 0.0
	for r in 探秘产出表:
		total += float(r.get("掉落权重", 1.0))
	var roll: float = randf() * total
	var pick: Dictionary = 探秘产出表[0]
	for r in 探秘产出表:
		roll -= float(r.get("掉落权重", 1.0))
		if roll <= 0.0:
			pick = r
			break
	return pick

func _抽秘藏() -> String:
	var 候选: Array = []
	for r in 探秘产出表:
		if r.get("分层", "") in ["奇景", "秘藏"]:
			候选.append(r)
	if 候选.is_empty():
		return ""
	var roll: int = randi() % 候选.size()
	return 候选[roll].get("名称", "")

func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["累计探秘次数"] = 累计探秘次数
	data["阵道境界"] = 阵道境界
	data["阵道经验"] = 阵道经验
	data["本周探秘参与"] = 本周探秘参与
	data["上周探秘周序"] = 上周探秘周序
	data["本周秘藏数"] = 本周秘藏数
	data["本周探秘次数"] = 本周探秘次数
	return data

func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	累计探秘次数 = int(data.get("累计探秘次数", 0))
	阵道境界 = int(data.get("阵道境界", 0))
	阵道经验 = int(data.get("阵道经验", 0))
	本周探秘参与 = int(data.get("本周探秘参与", 0))
	上周探秘周序 = int(data.get("上周探秘周序", -1))
	本周秘藏数 = int(data.get("本周秘藏数", 0))
	本周探秘次数 = int(data.get("本周探秘次数", 0))

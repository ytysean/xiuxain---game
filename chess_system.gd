class_name ChessSystem
extends RefCounted

# 论道棋弈系统 - 休闲玩法（轻对抗智力子玩法）S51-P0/P1/P2/P3
# 后端：纯产出型，零触碰战斗核心（红线：72 战斗断言）
# 四分层：悟道（道韵增益·主产）/ 棋谱残局（棋谱录·收集）/ 论道机锋（机锋语·0实用）/ 无上棋道（棋道秘匣·[PLACEHOLDER]）
# P1：棋道境界（5重）成长线，加成胜率
# P2：棋谱（提胜率/解锁高难）/ 悟道茶（提悟性幅度）构成消耗品 sink 闭环
# P3：论道大会周常（棋力排行·威望奖励）+ 受控奇遇
# 数值全部 [PLACEHOLDER·待实机调]，不升 SAVE_VERSION
# 悟性增益修炼速度的实机接入见 [PLACEHOLDER]（本轮不碰 Disciple 红线 d.总修炼速度倍率）

const Item = preload("res://item.gd")

const 棋道境界表: Array = [
	{"名": "棋道学徒", "经验": 0, "加成": 0.0, "解锁": "基础对手"},
	{"名": "棋师", "经验": 300, "加成": 0.05, "解锁": "中级/棋谱"},
	{"名": "大棋师", "经验": 1000, "加成": 0.15, "解锁": "高级/残局"},
	{"名": "棋道宗师", "经验": 3000, "加成": 0.30, "解锁": "传说/棋道感悟"},
	{"名": "棋道仙师", "经验": 8000, "加成": 0.50, "解锁": "仙人/大道感悟"},
]

const 周常规则表: Array = [
	{"名称": "棋力新秀", "描述": "一周内论道胜场登顶", "奖励威望": 15},
	{"名称": "连胜棋圣", "描述": "连胜棋局排行", "奖励威望": 20},
	{"名称": "棋谱大成", "描述": "集齐当周棋谱", "奖励威望": 18},
	{"名称": "道韵通玄", "描述": "道韵积分登顶", "奖励威望": 30},
	{"名称": "机锋妙语", "描述": "机锋语收录数", "奖励威望": 16},
]

var 棋类表: Array = []
var 消耗品表: Array = []
var 累计论道次数: int = 0
var 棋道境界: int = 0
var 棋道经验: int = 0
var 道韵: int = 0
var 悟性增益剩余日: int = 0
var 悟性增益幅度: float = 0.0
var 累计机锋数: int = 0
var 本周论道参与: int = 0
var 上周论道周序: int = -1
var 本周论道次数: int = 0
var 本周机锋数: int = 0

func _init() -> void:
	加载配置()

func 加载配置() -> void:
	if 棋类表.is_empty():
		棋类表 = DestinyDataLoader._read_csv("res://config/chess_type.csv")
	if 消耗品表.is_empty():
		消耗品表 = DestinyDataLoader._read_csv("res://config/chess_consumable.csv")

func 棋道加成() -> float:
	if 棋道境界 < 0 or 棋道境界 >= 棋道境界表.size():
		return 0.0
	return float(棋道境界表[棋道境界].get("加成", 0.0))

func 棋道境界名() -> String:
	if 棋道境界 < 0 or 棋道境界 >= 棋道境界表.size():
		return ""
	return 棋道境界表[棋道境界].get("名", "")

func 棋道进度() -> Dictionary:
	if 棋道境界 >= 棋道境界表.size() - 1:
		return {"已得": 棋道经验, "需": 棋道经验, "满": true}
	var 需: int = int(棋道境界表[棋道境界 + 1].get("经验", 0))
	return {"已得": 棋道经验, "需": 需, "满": false}

func 增加棋道经验(增: int) -> bool:
	if 增 <= 0:
		return false
	棋道经验 += 增
	var 突破: bool = false
	while 棋道境界 < 棋道境界表.size() - 1 and 棋道经验 >= int(棋道境界表[棋道境界 + 1].get("经验", 0)):
		棋道境界 += 1
		突破 = true
		if Game != null:
			Game.添加纪事("棋道突破", "棋道修为精进至【%s】，落子更合天道。" % 棋道境界表[棋道境界].get("名", ""))
	return 突破

func 当前悟性增益() -> Dictionary:
	return {"剩余日": 悟性增益剩余日, "幅度": 悟性增益幅度}

# ---- 棋类配置 ----
func 棋类配置(棋类id: String) -> Dictionary:
	for c in 棋类表:
		if c.get("棋类id", "") == 棋类id:
			return c
	return {}

func 可论道(棋类id: String) -> Dictionary:
	var c: Dictionary = 棋类配置(棋类id)
	if c.is_empty():
		return {"可": false, "原因": "无此棋类"}
	var 需境: int = int(c.get("需求棋道境界", 0))
	if 棋道境界 < 需境:
		return {"可": false, "原因": "棋道境界不足，需【%s】" % 棋道境界表[需境].get("名", "")}
	return {"可": true}

func 基础胜率(棋类id: String) -> float:
	var c: Dictionary = 棋类配置(棋类id)
	if c.is_empty():
		return 0.10
	var 难度: int = int(c.get("难度星", 1))
	return clamp(0.85 - (难度 - 1) * 0.10 + 棋道加成(), 0.10, 0.95)

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
	it.功效 = "论道棋弈辅助"
	if Game != null:
		Game.宗门库房.append(it)
	return {"成功": true, "名称": 名, "价": 价}

# ---- P3 周常论道大会 ----
func 论道周序() -> int:
	if Game == null:
		return 0
	return int(Game.累计游戏日 / 7) % 周常规则表.size()

func 获取本周论道周() -> Dictionary:
	return 周常规则表[论道周序()]

func 参与论道大会() -> Dictionary:
	var 周: int = 论道周序()
	if 周 != 上周论道周序:
		上周论道周序 = 周
		本周论道参与 = 0
	if 本周论道参与 >= 3:
		return {"成功": false, "原因": "本周已参与（上限3，防通胀）"}
	var 规: Dictionary = 获取本周论道周()
	var 威望: int = int(规.get("奖励威望", 10))
	if Game != null:
		Game.宗主威望 += 威望
	本周论道参与 += 1
	if Game != null:
		Game.添加纪事("论道大会", "周赛", "参与本周论道大会【%s】，获宗主威望 %d。" % [规.get("名称", ""), 威望], 1)
	return {"成功": true, "规则": 规.get("名称"), "威望": 威望, "参与": 本周论道参与}

func 结算论道(棋类id: String, 用棋谱: bool = false, 用悟道茶: bool = false) -> Dictionary:
	var c: Dictionary = 棋类配置(棋类id)
	if c.is_empty():
		return {"成功": false, "原因": "无此棋类"}
	var 门: Dictionary = 可论道(棋类id)
	if not 门.可:
		return {"成功": false, "原因": 门.原因}
	var 难度: int = int(c.get("难度星", 1))
	var 对手: String = c.get("对手", "")
	var 棋谱名: String = c.get("棋谱名", "")
	var 胜率: float = 基础胜率(棋类id)
	var 棋谱加成: float = 0.0
	if 用棋谱 and 库房计数("棋谱") > 0:
		棋谱加成 = float(消耗品配置("棋谱").get("数值", 0.0))
		_扣库房("棋谱", 1)
	胜率 = clamp(胜率 + 棋谱加成, 0.10, 0.97)
	var 悟茶加成: float = 0.0
	if 用悟道茶 and 库房计数("悟道茶") > 0:
		悟茶加成 = float(消耗品配置("悟道茶").get("数值", 0.0))
		_扣库房("悟道茶", 1)
	var 胜: bool = randf() < 胜率
	累计论道次数 += 1
	本周论道次数 += 1
	var 结果: Dictionary = {"成功": true, "棋类": c.get("棋类名", ""), "对手": 对手, "胜": 胜, "胜率": 胜率}
	if 胜:
		var 得韵: int = 难度 * 12
		道韵 += 得韵
		var 日: int = randi_range(1, 7)
		var 幅: float = 0.05 + 悟茶加成
		悟性增益剩余日 = min(悟性增益剩余日 + 日, 30)
		悟性增益幅度 = min(悟性增益幅度 + 幅, 0.30)
		var 增经验: int = 难度 * 15 + 10
		var 收谱: bool = false
		if 棋谱名 != "" and randf() < 0.25:
			if Game != null:
				Game._记录图录(棋谱名, "棋谱录")
			收谱 = true
		var 机锋: bool = false
		if randf() < 0.08:
			累计机锋数 += 1
			本周机锋数 += 1
			机锋 = true
		var 秘匣: bool = false
		if randf() < 0.02:
			秘匣 = true
			if Game != null:
				Game.添加纪事("棋道秘匣", "论道", "对弈间偶得棋道秘匣，似有大机缘隐于其中。", 1)
		var 突破: bool = 增加棋道经验(增经验)
		if randf() < 0.03:
			if Game != null:
				Game._尝试触发奇遇(Game.宗主, "论道棋弈")
		结果.merge({"道韵": 得韵, "悟性增益日": 日, "悟性增益幅": 幅, "经验": 增经验, "收谱": 收谱, "机锋": 机锋, "秘匣": 秘匣, "境界突破": 突破})
	else:
		var 增经验: int = 5
		var 突破: bool = 增加棋道经验(增经验)
		结果.merge({"道韵": 0, "经验": 增经验, "境界突破": 突破})
	return 结果

func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["累计论道次数"] = 累计论道次数
	data["棋道境界"] = 棋道境界
	data["棋道经验"] = 棋道经验
	data["道韵"] = 道韵
	data["悟性增益剩余日"] = 悟性增益剩余日
	data["悟性增益幅度"] = 悟性增益幅度
	data["累计机锋数"] = 累计机锋数
	data["本周论道参与"] = 本周论道参与
	data["上周论道周序"] = 上周论道周序
	data["本周论道次数"] = 本周论道次数
	data["本周机锋数"] = 本周机锋数
	return data

func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	累计论道次数 = int(data.get("累计论道次数", 0))
	棋道境界 = int(data.get("棋道境界", 0))
	棋道经验 = int(data.get("棋道经验", 0))
	道韵 = int(data.get("道韵", 0))
	悟性增益剩余日 = int(data.get("悟性增益剩余日", 0))
	悟性增益幅度 = float(data.get("悟性增益幅度", 0.0))
	累计机锋数 = int(data.get("累计机锋数", 0))
	本周论道参与 = int(data.get("本周论道参与", 0))
	上周论道周序 = int(data.get("上周论道周序", -1))
	本周论道次数 = int(data.get("本周论道次数", 0))
	本周机锋数 = int(data.get("本周机锋数", 0))

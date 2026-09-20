class_name DivineSystem
extends RefCounted

# 卜算星盘系统 - 休闲玩法（天机卜算子玩法）S49-P0/P1/P2/P3
# 后端：纯运势型，接奇遇受控通道，零触碰战斗核心
# 四分层：吉兆 / 平兆 / 凶兆 / 天机秘示
# P1：天机境界（5重）成长线，加成应验率（吉兆/天机秘示权重）
# P2：星盘玉（提应验率）/卦资（每次灵石消耗）构成 sink 闭环
# P3：观星大会周常（积分排行·威望奖励）+ 受控奇遇 + 天机录图录
# 数值全部 [PLACEHOLDER·待实机调]，不升 SAVE_VERSION

const Item = preload("res://item.gd")

const 天机境界表: Array = [
	{"名": "卜算学徒", "经验": 0, "加成": 0.0, "解锁": "基础卜算"},
	{"名": "卜师", "经验": 300, "加成": 0.10, "解锁": "中级/观星"},
	{"名": "大卜师", "经验": 1000, "加成": 0.25, "解锁": "高级/天机秘示"},
	{"名": "天机宗师", "经验": 3000, "加成": 0.40, "解锁": "传说/改命"},
	{"名": "天机仙师", "经验": 8000, "加成": 0.60, "解锁": "仙机/逆天改命"},
]

const 周常规则表: Array = [
	{"名称": "吉兆临门", "描述": "一周卜算吉兆数登顶", "奖励威望": 15},
	{"名称": "天机洞明", "描述": "天机秘示探得数登顶", "奖励威望": 30},
	{"名称": "应验如神", "描述": "应验率累计登顶", "奖励威望": 22},
	{"名称": "星象大观", "描述": "观星积分累计", "奖励威望": 18},
	{"名称": "秘示寻踪", "描述": "本周长效秘示收录", "奖励威望": 25},
]

const 四分层表: Array = [
	{"分层": "吉兆", "权重": 0.42, "经验": 20, "记录名": "吉兆", "受控率": 0.12},
	{"分层": "平兆", "权重": 0.33, "经验": 8, "记录名": "平兆", "受控率": 0.0},
	{"分层": "凶兆", "权重": 0.20, "经验": 5, "记录名": "凶兆", "受控率": 0.0},
	{"分层": "天机秘示", "权重": 0.05, "经验": 60, "记录名": "天机秘示", "受控率": 0.50},
]

var 卜算类型表: Array = []
var 消耗品表: Array = []
var 累计卜算次数: int = 0
var 天机境界: int = 0
var 天机经验: int = 0
var 宗门运势: int = 50
var 本周观星参与: int = 0
var 上周观星周序: int = -1
var 本周吉兆数: int = 0
var 本周秘示数: int = 0
var 本周卜算次数: int = 0
var 本周观星积分: int = 0

func _init() -> void:
	加载配置()

func 加载配置() -> void:
	if 卜算类型表.is_empty():
		卜算类型表 = DestinyDataLoader._read_csv("res://config/divine_type.csv")
	if 消耗品表.is_empty():
		消耗品表 = DestinyDataLoader._read_csv("res://config/divine_consumable.csv")

func 天机加成() -> float:
	if 天机境界 < 0 or 天机境界 >= 天机境界表.size():
		return 0.0
	return float(天机境界表[天机境界].get("加成", 0.0))

func 天机境界名() -> String:
	if 天机境界 < 0 or 天机境界 >= 天机境界表.size():
		return ""
	return 天机境界表[天机境界].get("名", "")

func 天机进度() -> Dictionary:
	if 天机境界 >= 天机境界表.size() - 1:
		return {"已得": 天机经验, "需": 天机经验, "满": true}
	var 需: int = int(天机境界表[天机境界 + 1].get("经验", 0))
	return {"已得": 天机经验, "需": 需, "满": false}

func 增加天机经验(增: int) -> bool:
	if 增 <= 0:
		return false
	天机经验 += 增
	var 突破: bool = false
	while 天机境界 < 天机境界表.size() - 1 and 天机经验 >= int(天机境界表[天机境界 + 1].get("经验", 0)):
		天机境界 += 1
		突破 = true
		if Game != null:
			Game.添加纪事("天机突破", "卜算修为精进至【%s】，可窥更深天机。" % 天机境界表[天机境界].get("名", ""))
	return 突破

func 类型配置(类型: String) -> Dictionary:
	for t in 卜算类型表:
		if t.get("类型", "") == 类型:
			return t
	return {}

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
	it.功效 = "卜算星盘辅助"
	if Game != null:
		Game.宗门库房.append(it)
	return {"成功": true, "名称": 名, "价": 价}

func 观星周序() -> int:
	if Game == null:
		return 0
	return int(Game.累计游戏日 / 7) % 周常规则表.size()

func 获取本周观星周() -> Dictionary:
	return 周常规则表[观星周序()]

func 参与观星周() -> Dictionary:
	var 周: int = 观星周序()
	if 周 != 上周观星周序:
		上周观星周序 = 周
		本周观星参与 = 0
	if 本周观星参与 >= 3:
		return {"成功": false, "原因": "本周已参与（上限3，防通胀）"}
	var 规: Dictionary = 获取本周观星周()
	var 威望: int = int(规.get("奖励威望", 10))
	if Game != null:
		Game.宗主威望 += 威望
	本周观星参与 += 1
	# 观星大会特殊星象（天机录收录）[PLACEHOLDER 触发率 0.3]
	if randf() < 0.3:
		var 星象表: Array = ["紫微高照", "扫把星", "流星"]
		var 象: String = 星象表[randi() % 星象表.size()]
		if Game != null:
			Game._记录图录(象, "天机")
	if Game != null:
		Game.添加纪事("观星大会", "周赛", "参与本周观星大会【%s】，获宗主威望 %d。" % [规.get("名称", ""), 威望], 1)
	return {"成功": true, "规则": 规.get("名称"), "威望": 威望, "参与": 本周观星参与}

func 结算卜算(类型: String = "日常吉凶", 用星盘玉: bool = false) -> Dictionary:
	var 配: Dictionary = 类型配置(类型)
	if 配.is_empty():
		return {"成功": false, "原因": "无此卜算类型"}
	var 卦资: int = int(配.get("卦资", 0))
	if Game == null or Game.灵石 < 卦资:
		return {"成功": false, "原因": "卦资不足（需 %d 灵石）" % 卦资}
	Game.灵石 -= 卦资
	var 应验加成: float = 天机加成()
	if 用星盘玉 and 库房计数("星盘玉") > 0:
		应验加成 += float(消耗品配置("星盘玉").get("数值", 0.0))
		_扣库房("星盘玉", 1)
	var pick: Dictionary = _抽分层(应验加成)
	var 分层: String = pick.get("分层", "平兆")
	var 记录名: String = pick.get("记录名", 分层)
	var 受控率: float = float(pick.get("受控率", 0.0))
	var 增经验: int = int(pick.get("经验", 5))
	# 天机录图录（按匹配名归类，不产库房物）
	if Game != null:
		Game._记录图录(记录名, "天机")
	# 运势影响（本系统内部，不碰 Disciple/战斗红线）
	if 分层 == "吉兆":
		宗门运势 = min(宗门运势 + 5, 100)
	elif 分层 == "凶兆":
		宗门运势 = max(宗门运势 - 5, 0)
	# 受控奇遇（禁自建池）
	if 受控率 > 0.0 and randf() < 受控率:
		if Game != null:
			Game._尝试触发奇遇(Game.宗主, "卜算星盘")
	累计卜算次数 += 1
	本周卜算次数 += 1
	if 分层 == "吉兆":
		本周吉兆数 += 1
	if 分层 == "天机秘示":
		本周秘示数 += 1
	var 积分: int = int(应验加成 * 100) + (20 if 分层 == "天机秘示" else 0)
	本周观星积分 += 积分
	var 突破: bool = 增加天机经验(增经验)
	return {"成功": true, "分层": 分层, "类型": 类型, "卦资": 卦资, "记录名": 记录名, "经验": 增经验, "运势": 宗门运势, "积分": 积分, "境界突破": 突破, "提示": ""}

func _抽分层(应验加成: float = 0.0) -> Dictionary:
	var 加权: Array = []
	var total: float = 0.0
	for r in 四分层表:
		var w: float = float(r.get("权重", 0.1))
		var 层: String = r.get("分层", "")
		if 层 == "吉兆" or 层 == "天机秘示":
			w *= (1.0 + 应验加成)
			加权.append({"r": r, "w": w})
			total += w
		else:
			加权.append({"r": r, "w": w})
			total += w
	if 加权.is_empty():
		return 四分层表[1]
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
	data["累计卜算次数"] = 累计卜算次数
	data["天机境界"] = 天机境界
	data["天机经验"] = 天机经验
	data["宗门运势"] = 宗门运势
	data["本周观星参与"] = 本周观星参与
	data["上周观星周序"] = 上周观星周序
	data["本周吉兆数"] = 本周吉兆数
	data["本周秘示数"] = 本周秘示数
	data["本周卜算次数"] = 本周卜算次数
	data["本周观星积分"] = 本周观星积分
	return data

func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	累计卜算次数 = int(data.get("累计卜算次数", 0))
	天机境界 = int(data.get("天机境界", 0))
	天机经验 = int(data.get("天机经验", 0))
	宗门运势 = int(data.get("宗门运势", 50))
	本周观星参与 = int(data.get("本周观星参与", 0))
	上周观星周序 = int(data.get("上周观星周序", -1))
	本周吉兆数 = int(data.get("本周吉兆数", 0))
	本周秘示数 = int(data.get("本周秘示数", 0))
	本周卜算次数 = int(data.get("本周卜算次数", 0))
	本周观星积分 = int(data.get("本周观星积分", 0))

class_name FriendSystem extends RefCounted

# ===== 道友系统状态变量 =====
var _道友列表: Array = []                  # 本地道友（{name, status, sel}），无服务端，纯本地
var _道友消息: Array = []                  # 本地聊天记录（{name, text, time}）
var 结义道友列表: Array = []
var 道友拜访冷却: Dictionary = {}  # 道友名字 -> 冷却结束日
var 道友切磋冷却: Dictionary = {}  # 道友名字 -> 冷却结束日

func 道友列表() -> Array:

	return _道友列表
func 道友消息() -> Array:

	return _道友消息
# 添加道友
func 添加道友(名字: String, 境界: String = "筑基初期", 在线: bool = true) -> Dictionary:

	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			return {"成功": false, "原因": "道友已存在"}
	_道友列表.append({"name": 名字, "status": "%s · %s" % ["在线" if 在线 else "离线", 境界], "sel": false, "好感度": 50, "论道次数": 0, "送礼次数": 0})
	if has_method("save_game"):
		Game.save_game()
	return {"成功": true, "原因": "添加道友成功：%s" % 名字}
# 删除道友
func 删除道友(名字: String) -> Dictionary:

	for i in range(_道友列表.size()):
		if str(_道友列表[i].get("name", "")) == 名字:
			_道友列表.remove_at(i)
			if has_method("save_game"):
				Game.save_game()
			return {"成功": true, "原因": "删除道友成功：%s" % 名字}
	return {"成功": false, "原因": "道友不存在"}
# 发送消：
func 发送道友消息(名字: String, 内容: String) -> Dictionary:

	var 时间 = "%02d-%02d %02d:%02d" % [8, Game.累计游戏日% 28 + 1, randi() % 24, randi() % 60]
	_道友消息.append({"name": 名字, "text": 内容, "time": 时间, "自己": true})
	if _道友消息.size() > 100:
		_道友消息.remove_at(0)
	if has_method("save_game"):
		Game.save_game()
	return {"成功": true, "原因": "消息已发送"}
# 获取所有道友列表（包含详细信息）
func 获取所有道友列表() -> Array:
	var 道友列表 = []
	for 道友 in _道友列表:
		道友列表.append({
			"name": 道友.get("name", ""),
			"status": 道友.get("status", ""),
			"好感度": 道友.get("好感度", 50),
			"论道次数": 道友.get("论道次数", 0),
			"送礼次数": 道友.get("送礼次数", 0),
		})
	return 道友列表

# 给道友送礼（提升好感度）
func 给道友送礼(名字: String, 礼物价值: int = 100) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	if Game.灵石 < 礼物价值:
		return {"成功": false, "原因": "灵石不足（需要%d）" % 礼物价值}
	Game.灵石 -= 礼物价值
	# 提升好感度（根据礼物价值）
	var 好感度提升 = int(礼物价值 / 10)
	道友["好感度"] = int(道友.get("好感度", 50)) + 好感度提升
	道友["送礼次数"] = int(道友.get("送礼次数", 0)) + 1
	# 好感度上限100
	if int(道友["好感度"]) > 100:
		道友["好感度"] = 100
	Game.添加纪事("社交", "道友送礼", "给%s送礼，花费%d灵石，好感度+%d" % [名字, 礼物价值, 好感度提升], 1)
	return {"成功": true, "道友": 道友, "好感度提升": 好感度提升, "消息": "给%s送礼成功" % 名字}

# 道友好感度等级配置
const 道友好感度等级配置: Dictionary = {
	1: {"名称": "陌生人", "最低好感度": 0, "效果": "无特殊效果"},
	2: {"名称": "相识", "最低好感度": 20, "效果": "可以发送消息"},
	3: {"名称": "朋友", "最低好感度": 40, "效果": "可以送礼"},
	4: {"名称": "好友", "最低好感度": 60, "效果": "可以拜访"},
	5: {"名称": "挚友", "最低好感度": 80, "效果": "可以切磋"},
	6: {"名称": "生死之交", "最低好感度": 100, "效果": "可以结义"},
}

# 获取道友好感度等级
func 获取道友好感度等级(好感度: int) -> int:
	var 当前等级 = 1
	for 等级 in 道友好感度等级配置.keys():
		var 配置 = 道友好感度等级配置[等级]
		if 好感度 >= int(配置.get("最低好感度", 0)):
			当前等级 = 等级
	return 当前等级

# ===== P3联动：社交 × 弟子 =====
# 道友拜访（消耗灵石，获得弟子修炼加成和资源）
func 道友拜访(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	# 检查好感度等级（需要好友以上才能拜访）
	var 好感度: int = int(道友.get("好感度", 50))
	var 好感度等级: int = 获取道友好感度等级(好感度)
	if 好感度等级 < 4:
		return {"成功": false, "原因": "好感度不足（需好友以上才能拜访）"}
	# 检查冷却
	var 冷却结束日: int = int(道友拜访冷却.get(名字, 0))
	if Game.累计游戏日 < 冷却结束日:
		return {"成功": false, "原因": "拜访冷却中（还需%d日）" % (冷却结束日 - Game.累计游戏日)}
	# 消耗灵石
	var 拜访消耗: int = 200
	if Game.灵石 < 拜访消耗:
		return {"成功": false, "原因": "灵石不足（需要%d）" % 拜访消耗}
	Game.灵石 -= 拜访消耗
	# 设置冷却（7天）
	道友拜访冷却[名字] = Game.累计游戏日 + 7
	# 获得修炼加成（根据好感度等级）
	var 修炼加成: float = float(好感度等级) * 0.02  # 每级+2%，上限12%
	# 获得资源（根据好感度等级）
	var 灵气奖励: int = 好感度等级 * 20
	Game.灵气 += 灵气奖励
	# 添加纪事
	Game.添加纪事("社交", "道友拜访", "拜访%s，花费%d灵石，获得灵气+%d，全宗修炼+%d%%持续7天" % [名字, 拜访消耗, 灵气奖励, int(修炼加成 * 100)], 1)
	Game._加推演条目("【社交】拜访%s，道友交流心得，全宗弟子修炼精进" % 名字, "社交", "中")
	return {"成功": true, "修炼加成": 修炼加成, "灵气奖励": 灵气奖励, "持续天数": 7}

# 获取道友拜访修炼加成（所有道友拜访加成的总和，上限20%）
func 获取道友拜访修炼加成() -> float:
	var 总加成: float = 0.0
	for 名字 in 道友拜访冷却.keys():
		var 冷却结束日: int = int(道友拜访冷却[名字])
		if Game.累计游戏日 < 冷却结束日:
			# 找到该道友的好感度
			for d in _道友列表:
				if str(d.get("name") if "name" in d else "") == 名字:
					var 好感度: int = int(d.get("好感度", 50))
					var 好感度等级: int = 获取道友好感度等级(好感度)
					总加成 += float(好感度等级) * 0.02
					break
	return min(0.20, 总加成)  # 上限20%

# 结义道友列表

# 道友拜访冷却

# 道友切磋冷却

# 道友结义
func 道友结义(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	var 好感度 = int(道友.get("好感度", 50))
	if 好感度 < 100:
		return {"成功": false, "原因": "好感度不足（需100，当前%d）" % 好感度}
	if 名字 in 结义道友列表:
		return {"成功": false, "原因": "已经是结义兄弟"}
	# 消耗灵石
	var 消耗灵石 = 10000
	if Game.灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
	Game.灵石 -= 消耗灵石
	结义道友列表.append(名字)
	Game.添加纪事("社交", "道友结义", "与%s结为生死之交，消耗%d灵石" % [名字, 消耗灵石], 1)
	# P3 保命环节：结义兄弟赠予保命法宝（来源：道友）——以实物道具入背包，非直接计数
	if Game.弟子列表.size() > 0 and Game.弟子列表[0] != null:
		var 宗主 = Game.弟子列表[0]
		var 道具 = Game.构造保命道具("义气同心符", "宝阶", "fabao",
			"结义之谊凝成的护身法宝，致命劫数下替弟子挡下一劫", "义薄云天，同心断金，危难时自发护主。")
		宗主.获得物品(道具)
		Game.添加纪事("保命", "道友", "%s 获结义兄弟赠予【义气同心符】（法宝·保命），纳入背包" % 宗主.姓名, 1)
	return {"成功": true, "道友": 道友, "消耗灵石": 消耗灵石, "消息": "与%s结义成功" % 名字}

# P3 保命环节：缔结道侣（双修伴侣赠予保命护身，来源：道侣）
# P3 保命环节：缔结道侣（双修伴侣赠予保命护身，来源：道侣）
# §12.1：改传弟子ID互链——双向设 道侣ID + 道侣名，双方各得保命道具。
func 缔结道侣(弟子IDA: int, 弟子IDB: int) -> Dictionary:
	var 甲 = Game._取弟子(弟子IDA)
	var 乙 = Game._取弟子(弟子IDB)
	if 甲 == null or 乙 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if 甲.弟子ID == 乙.弟子ID:
		return {"成功": false, "原因": "不能与自身结为道侣"}
	甲.道侣 = 乙.姓名
	甲.道侣ID = 乙.弟子ID
	乙.道侣 = 甲.姓名
	乙.道侣ID = 甲.弟子ID
	# S30 性格相冲：道侣性格相冲 → 双方心魔涨（强度×4）
	var 侣相冲: int = Disciple.性格相冲度(str(甲.性格), str(乙.性格))
	if 侣相冲 > 0:
		甲.增加心魔(侣相冲 * 4)
		乙.增加心魔(侣相冲 * 4)
	var 道具甲 = Game.构造保命道具("同心铃", "宝阶", "fabao",
		"道侣情深所系护身法宝，危难时替弟子避劫", "铃响同心，情牵一线，命悬一线时护主周全。")
	甲.获得物品(道具甲)
	var 道具乙 = Game.构造保命道具("同心铃", "宝阶", "fabao",
		"道侣情深所系护身法宝，危难时替弟子避劫", "铃响同心，情牵一线，命悬一线时护主周全。")
	乙.获得物品(道具乙)
	Game.添加纪事("保命", "道侣", "%s 与%s结为道侣，互赠【同心铃】（法宝·保命）" % [甲.姓名, 乙.姓名], 1)
	return {"成功": true, "甲": 甲.姓名, "乙": 乙.姓名, "消息": "%s 与%s结为道侣" % [甲.姓名, 乙.姓名]}

# 道友切磋
func 道友切磋(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	var 好感度 = int(道友.get("好感度", 50))
	if 好感度 < 80:
		return {"成功": false, "原因": "好感度不足（需80，当前%d）" % 好感度}
	# 检查冷却
	if 名字 in 道友切磋冷却:
		var 冷却结束日 = int(道友切磋冷却[名字])
		if Game.累计游戏日 < 冷却结束日:
			return {"成功": false, "原因": "切磋冷却中（还需%d天）" % (冷却结束日 - Game.累计游戏日)}
	# 消耗体力
	var 消耗体力 = 20
	if Game.体力 < 消耗体力:
		return {"成功": false, "原因": "体力不足（需%d体力）" % 消耗体力}
	Game.体力 -= 消耗体力
	# 切磋结果：随机胜负
	var 随机值 = randf()
	var 胜利 = 随机值 < 0.5
	var 奖励 = {}
	var 消息 = ""
	if 胜利:
		奖励 = {"悟道点": 20, "Game.灵石": 100}
		消息 = "与%s切磋，获胜！获得悟道点20，灵石100" % 名字
		道友["好感度"] = min(100, 好感度 + 3)
	else:
		奖励 = {"悟道点": 10}
		消息 = "与%s切磋，惜败。获得悟道点10" % 名字
		道友["好感度"] = min(100, 好感度 + 1)
	# 设置冷却（2天）
	道友切磋冷却[名字] = Game.累计游戏日 + 2
	Game.添加纪事("社交", "道友切磋", 消息, 1)
	return {"成功": true, "道友": 道友, "胜利": 胜利, "奖励": 奖励, "消息": 消息}

# 获取社交统计
func 获取社交统计() -> Dictionary:
	var 道友总数 = _道友列表.size()
	var 结义数 = 结义道友列表.size()
	var 平均好感度 = 0
	var 总好感度 = 0
	var 最高好感度 = 0
	var 总论道次数 = 0
	var 总送礼次数 = 0
	for 道友 in _道友列表:
		var 好感度 = int(道友.get("好感度", 50))
		总好感度 += 好感度
		最高好感度 = max(最高好感度, 好感度)
		总论道次数 += int(道友.get("论道次数", 0))
		总送礼次数 += int(道友.get("送礼次数", 0))
	if 道友总数 > 0:
		平均好感度 = int(总好感度 / 道友总数)
	return {
		"道友总数": 道友总数,
		"结义数": 结义数,
		"平均好感度": 平均好感度,
		"最高好感度": 最高好感度,
		"总好感度": 总好感度,
		"总论道次数": 总论道次数,
		"总送礼次数": 总送礼次数,
	}

# 一键给所有道友送礼
func 一键给所有道友送礼(礼物价值: int = 100) -> Dictionary:
	var 成功数量 = 0
	var 失败数量 = 0
	var 送礼列表 = []
	for 道友 in _道友列表:
		var 名字 = str(道友.get("name", ""))
		var 结果 = 给道友送礼(名字, 礼物价值)
		送礼列表.append(结果)
		if 结果.get("成功", false):
			成功数量 += 1
		else:
			失败数量 += 1
	return {"成功": 成功数量 > 0, "成功数量": 成功数量, "失败数量": 失败数量, "送礼列表": 送礼列表, "消息": "一键送礼完成，成功%d人，失败%d人" % [成功数量, 失败数量]}

# 与道友论道（获得悟道点）
func 与道友论道(名字: String) -> Dictionary:

	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	var 好感度 = int(道友.get("好感度", 50))
	if 好感度 < 30:
		return {"成功": false, "原因": "好感度不足，道友不愿论道"}
	var 论道次数 = int(道友.get("论道次数", 0))
	if 论道次数 >= 3:
		return {"成功": false, "原因": "今日论道次数已用完（每日3次）"}
	var 悟道点获得 = 5 + randi() % 10 + int(好感度 / 10)
	Game.悟道点 += 悟道点获得
	道友["论道次数"] = 论道次数 + 1
	道友["好感度"] = min(100, 好感度 + 2)
	if has_method("save_game"):
		Game.save_game()
	return {"成功": true, "原因": "%s论道成功，获得悟道点%d，好感度+2" % [名字, 悟道点获得]}
# 拜访道友（获得灵石、灵气，提升好感度）
func 拜访道友(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	# 检查冷却
	var 冷却日: int = int(道友拜访冷却.get(名字, 0))
	if Game.累计游戏日 < 冷却日:
		return {"成功": false, "原因": "拜访冷却中（还需%d天）" % (冷却日 - Game.累计游戏日)}
	道友拜访冷却[名字] = Game.累计游戏日 + 1
	# 拜访奖励
	var 好感度: int = int(道友.get("好感度", 50))
	var 灵石奖励: int = 50 + randi() % 100 + int(好感度 / 2)
	var 灵气奖励: int = 20 + randi() % 50 + int(好感度 / 5)
	Game.灵石 += 灵石奖励
	Game.灵气 += 灵气奖励
	道友["好感度"] = min(100, 好感度 + 3)
	# 随机事件
	var 事件文本: String = ""
	var 随机值: float = randf()
	if 随机值 < 0.1:
		# 10%概率道友赠送额外礼物
		var 额外灵石: int = randi_range(100, 300)
		Game.灵石 += 额外灵石
		事件文本 = "，道友心情大好，额外赠送%d灵石" % 额外灵石
	elif 随机值 < 0.2:
		# 10%概率获得悟道点
		Game.悟道点 += 5
		事件文本 = "，与道友畅谈，悟道点+5"
	Game.添加纪事("庶务", "拜访道友", "拜访道友%s，获得%d灵石、%d灵气，好感度+3%s" % [名字, 灵石奖励, 灵气奖励, 事件文本], 1)
	if has_method("save_game"):
		Game.save_game()
	return {"成功": true, "Game.灵石": 灵石奖励, "灵气": 灵气奖励, "事件": 事件文本}

# 与道友切磋（获得修炼经验，可能受伤）
func 与道友切磋(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	# 检查冷却
	var 冷却日: int = int(道友切磋冷却.get(名字, 0))
	if Game.累计游戏日 < 冷却日:
		return {"成功": false, "原因": "切磋冷却中（还需%d天）" % (冷却日 - Game.累计游戏日)}
	# 检查体力
	if Game.体力 < 15:
		return {"成功": false, "原因": "体力不足（需15点）"}
	Game.体力 -= 15
	道友切磋冷却[名字] = Game.累计游戏日 + 2
	# 切磋结果
	var 好感度: int = int(道友.get("好感度", 50))
	var 胜利概率: float = 0.4 + float(好感度) / 200.0  # 40%-90%
	var 胜利: bool = randf() < 胜利概率
	if 胜利:
		var 修炼经验: int = 50 + randi() % 100
		Game.修炼进度 += float(修炼经验) / 1000.0
		道友["好感度"] = min(100, 好感度 + 5)
		Game.添加纪事("庶务", "道友切磋", "与道友%s切磋得胜，修炼修为+%d，好感+5" % [名字, 修炼经验], 1)
		if has_method("save_game"):
			Game.save_game()
		return {"成功": true, "胜利": true, "修炼经验": 修炼经验}
	else:
		# 失败可能受伤
		var 受伤: bool = randf() < 0.3
		if 受伤:
			Game.体力 = max(0, Game.体力 - 10)
			Game.添加纪事("庶务", "道友切磋", "与道友%s切磋失败，受伤了，体力-10" % 名字, 1)
		else:
			道友["好感度"] = min(100, 好感度 + 2)
			Game.添加纪事("庶务", "道友切磋", "与道友%s切磋失败，但有所收获，好感度+2" % 名字, 1)
		if has_method("save_game"):
			Game.save_game()
		return {"成功": true, "胜利": false, "受伤": 受伤}

# 与道友结义（好感度100时可结义，获得永久加成）
func 与道友结义(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	# 检查好感度
	var 好感度: int = int(道友.get("好感度", 50))
	if 好感度 < 100:
		return {"成功": false, "原因": "好感度不足（需100，当前%d）" % 好感度}
	# 检查是否已结义
	if 名字 in 结义道友列表:
		return {"成功": false, "原因": "已与此道友结义"}
	# 结义消耗
	if Game.灵石 < 1000:
		return {"成功": false, "原因": "灵石不足（需1000灵石用于结义仪式）"}
	Game.灵石 -= 1000
	# 结义成功
	结义道友列表.append(名字)
	# 永久加成：所有结义道友提供修炼速度+1%（最多5%）
	var 结义加成: float = min(0.05, float(结义道友列表.size()) * 0.01)
	Game.添加纪事("庶务", "道友结义", "与道友%s结义为兄弟，修炼速度+%.0f%%（当前总加成%.0f%%）" % [名字, 结义加成 * 100, 结义加成 * 100], 1)
	if has_method("save_game"):
		Game.save_game()
	return {"成功": true, "结义加成": 结义加成, "结义人数": 结义道友列表.size()}

# 获取结义加成
func 获取结义加成() -> float:
	return min(0.05, float(结义道友列表.size()) * 0.01)

# 重置每日道友互动次数
func 重置道友每日次数() -> void:
	for d in _道友列表:
		d["论道次数"] = 0
		d["送礼次数"] = 0
# ===== 序列化/反序列化（用于存档）=====
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["_道友列表"] = _道友列表
	data["_道友消息"] = _道友消息
	data["结义道友列表"] = 结义道友列表
	data["道友拜访冷却"] = 道友拜访冷却
	data["道友切磋冷却"] = 道友切磋冷却
	return data

func from_dict(data: Dictionary) -> void:
	if "_道友列表" in data: _道友列表 = data["_道友列表"]
	if "_道友消息" in data: _道友消息 = data["_道友消息"]
	if "结义道友列表" in data: 结义道友列表 = data["结义道友列表"]
	if "道友拜访冷却" in data: 道友拜访冷却 = data["道友拜访冷却"]
	if "道友切磋冷却" in data: 道友切磋冷却 = data["道友切磋冷却"]

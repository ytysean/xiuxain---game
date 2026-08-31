# -*- coding: utf-8 -*-
"""
完善道友互动系统和探索事件分支选择系统
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 在道友互动系统之后添加新功能
old_code = '''# 给道友送礼（提升好感度：
func 给道友送礼(名字: String, 礼物: String = "灵茶") -> Dictionary:'''

new_code = '''# 拜访道友（获得灵石、灵气，提升好感度）
var 道友拜访冷却: Dictionary = {}  # 道友名字 -> 冷却结束日
func 拜访道友(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name", "")) == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	# 检查冷却
	var 冷却日: int = int(道友拜访冷却.get(名字, 0))
	if 累计游戏日 < 冷却日:
		return {"成功": false, "原因": "拜访冷却中（还需%d天）" % (冷却日 - 累计游戏日)}
	道友拜访冷却[名字] = 累计游戏日 + 1
	# 拜访奖励
	var 好感度: int = int(道友.get("好感度", 50))
	var 灵石奖励: int = 50 + randi() % 100 + int(好感度 / 2)
	var 灵气奖励: int = 20 + randi() % 50 + int(好感度 / 5)
	灵石 += 灵石奖励
	灵气 += 灵气奖励
	道友["好感度"] = min(100, 好感度 + 3)
	# 随机事件
	var 事件文本: String = ""
	var 随机值: float = randf()
	if 随机值 < 0.1:
		# 10%概率道友赠送额外礼物
		var 额外灵石: int = randi_range(100, 300)
		灵石 += 额外灵石
		事件文本 = "，道友心情大好，额外赠送%d灵石" % 额外灵石
	elif 随机值 < 0.2:
		# 10%概率获得悟道点
		悟道点 += 5
		事件文本 = "，与道友畅谈，悟道点+5"
	添加纪事("庶务", "拜访道友", "拜访道友%s，获得%d灵石、%d灵气，好感度+3%s" % [名字, 灵石奖励, 灵气奖励, 事件文本], 1)
	if has_method("save_game"):
		save_game()
	return {"成功": true, "灵石": 灵石奖励, "灵气": 灵气奖励, "事件": 事件文本}

# 与道友切磋（获得修炼经验，可能受伤）
var 道友切磋冷却: Dictionary = {}  # 道友名字 -> 冷却结束日
func 与道友切磋(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name", "")) == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	# 检查冷却
	var 冷却日: int = int(道友切磋冷却.get(名字, 0))
	if 累计游戏日 < 冷却日:
		return {"成功": false, "原因": "切磋冷却中（还需%d天）" % (冷却日 - 累计游戏日)}
	# 检查体力
	if 体力 < 15:
		return {"成功": false, "原因": "体力不足（需15点）"}
	体力 -= 15
	道友切磋冷却[名字] = 累计游戏日 + 2
	# 切磋结果
	var 好感度: int = int(道友.get("好感度", 50))
	var 胜利概率: float = 0.4 + float(好感度) / 200.0  # 40%-90%
	var 胜利: bool = randf() < 胜利概率
	if 胜利:
		var 修炼经验: int = 50 + randi() % 100
		修炼进度 += float(修炼经验) / 1000.0
		道友["好感度"] = min(100, 好感度 + 5)
		添加纪事("庶务", "道友切磋", "与道友%s切磋胜利，修炼经验+%d，好感度+5" % [名字, 修炼经验], 1)
		if has_method("save_game"):
			save_game()
		return {"成功": true, "胜利": true, "修炼经验": 修炼经验}
	else:
		# 失败可能受伤
		var 受伤: bool = randf() < 0.3
		if 受伤:
			体力 = max(0, 体力 - 10)
			添加纪事("庶务", "道友切磋", "与道友%s切磋失败，受伤了，体力-10" % 名字, 1)
		else:
			道友["好感度"] = min(100, 好感度 + 2)
			添加纪事("庶务", "道友切磋", "与道友%s切磋失败，但有所收获，好感度+2" % 名字, 1)
		if has_method("save_game"):
			save_game()
		return {"成功": true, "胜利": false, "受伤": 受伤}

# 与道友结义（好感度100时可结义，获得永久加成）
var 结义道友列表: Array = []  # 已结义的道友名字列表
func 与道友结义(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name", "")) == 名字:
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
	if 灵石 < 1000:
		return {"成功": false, "原因": "灵石不足（需1000灵石用于结义仪式）"}
	灵石 -= 1000
	# 结义成功
	结义道友列表.append(名字)
	# 永久加成：所有结义道友提供修炼速度+1%（最多5%）
	var 结义加成: float = min(0.05, float(结义道友列表.size()) * 0.01)
	添加纪事("庶务", "道友结义", "与道友%s结义为兄弟，修炼速度+%.0f%%（当前总加成%.0f%%）" % [名字, 结义加成 * 100, 结义加成 * 100], 1)
	if has_method("save_game"):
		save_game()
	return {"成功": true, "结义加成": 结义加成, "结义人数": 结义道友列表.size()}

# 获取结义加成
func 获取结义加成() -> float:
	return min(0.05, float(结义道友列表.size()) * 0.01)

# 给道友送礼（提升好感度：
func 给道友送礼(名字: String, 礼物: String = "灵茶") -> Dictionary:'''

if old_code in content:
    content = content.replace(old_code, new_code)
    print("✅ 道友互动系统完善成功")
else:
    print("❌ 未找到道友互动系统插入位置")

# ============ 探索事件分支选择系统 ============
print("\n步骤2：添加探索事件分支选择系统...")

old_explore = '''# ===== 新系统实现（基本框架和核心功能）====='''

new_explore = '''# ===== 探索事件分支选择系统 =====
# 探索事件：在历练、秘境探索等场景中触发，玩家选择不同分支获得不同结果
var 探索事件配置: Array = []  # 探索事件配置列表
var 探索事件冷却: Dictionary = {}  # 事件ID -> 冷却结束日

# 加载探索事件配置
func _加载探索事件配置() -> void:
	if not 探索事件配置.is_empty():
		return
	# 内置探索事件配置（后续可移至CSV）
	探索事件配置 = [
		{
			"event_id": "explore_001",
			"name": "神秘洞穴",
			"description": "你在探索中发现了一个神秘洞穴，洞口散发着微弱的光芒。",
			"branches": [
				{"choice": "进入洞穴探索", "result": "risk", "success_rate": 0.6, "success_reward": {"灵石": 500, "悟道点": 20}, "fail_penalty": {"体力": -20}},
				{"choice": "在洞口查看", "result": "safe", "reward": {"灵石": 100, "灵气": 50}},
				{"choice": "离开", "result": "none", "reward": {}}
			]
		},
		{
			"event_id": "explore_002",
			"name": "受伤的旅人",
			"description": "你遇到了一个受伤的旅人，他看起来需要帮助。",
			"branches": [
				{"choice": "救助旅人", "result": "good", "reward": {"好感度": 10, "灵石": 200}, "special": "可能添加道友"},
				{"choice": "询问情况", "result": "info", "reward": {"悟道点": 5}},
				{"choice": "无视离开", "result": "none", "reward": {}}
			]
		},
		{
			"event_id": "explore_003",
			"name": "古老遗迹",
			"description": "你发现了一处古老遗迹，里面似乎藏有宝物。",
			"branches": [
				{"choice": "深入探索", "result": "risk", "success_rate": 0.5, "success_reward": {"灵石": 1000, "悟道点": 50, "灵气": 200}, "fail_penalty": {"体力": -30}},
				{"choice": "在外围搜索", "result": "safe", "reward": {"灵石": 300, "灵气": 100}},
				{"choice": "记录位置离开", "result": "none", "reward": {"悟道点": 10}}
			]
		},
		{
			"event_id": "explore_004",
			"name": "商队遭遇",
			"description": "你遇到了一支商队，他们正在招募护卫。",
			"branches": [
				{"choice": "接受护卫任务", "result": "task", "reward": {"灵石": 500}, "special": "需要体力"},
				{"choice": "与商人交易", "result": "trade", "reward": {"灵石": -200, "物品": "随机物品"}},
				{"choice": "离开", "result": "none", "reward": {}}
			]
		},
		{
			"event_id": "explore_005",
			"name": "灵泉发现",
			"description": "你发现了一处散发着灵气的泉水。",
			"branches": [
				{"choice": "饮用灵泉", "result": "good", "reward": {"灵气": 300, "体力": 20}},
				{"choice": "收集灵泉水", "result": "safe", "reward": {"灵气": 100}},
				{"choice": "在此修炼", "result": "cultivate", "reward": {"修炼进度": 0.1, "悟道点": 15}}
			]
		}
	]

# 触发随机探索事件
func 触发探索事件() -> Dictionary:
	_加载探索事件配置()
	# 过滤冷却中的事件
	var 可用事件: Array = []
	for 事件 in 探索事件配置:
		var 事件ID: String = str(事件.get("event_id", ""))
		var 冷却日: int = int(探索事件冷却.get(事件ID, 0))
		if 累计游戏日 >= 冷却日:
			可用事件.append(事件)
	if 可用事件.is_empty():
		return {"成功": false, "原因": "暂无可用探索事件"}
	# 随机选择一个事件
	var 事件 = 可用事件[randi() % 可用事件.size()]
	return {"成功": true, "事件": 事件}

# 选择探索事件分支
func 选择探索事件分支(事件ID: String, 分支索引: int) -> Dictionary:
	_加载探索事件配置()
	# 找到事件
	var 事件配置: Dictionary = {}
	for 事件 in 探索事件配置:
		if str(事件.get("event_id", "")) == 事件ID:
			事件配置 = 事件
			break
	if 事件配置.is_empty():
		return {"成功": false, "原因": "事件不存在"}
	# 检查分支索引
	var 分支列表: Array = 事件配置.get("branches", [])
	if 分支索引 < 0 or 分支索引 >= 分支列表.size():
		return {"成功": false, "原因": "分支索引无效"}
	var 分支 = 分支列表[分支索引]
	# 设置冷却
	探索事件冷却[事件ID] = 累计游戏日 + 3
	# 处理结果
	var 结果类型: String = str(分支.get("result", "none"))
	var 奖励: Dictionary = 分支.get("reward", {})
	var 结果文本: String = ""
	match 结果类型:
		"risk":
			# 风险型：成功或失败
			var 成功率: float = float(分支.get("success_rate", 0.5))
			var 成功: bool = randf() < 成功率
			if 成功:
				奖励 = 分支.get("success_reward", {})
				结果文本 = "探索成功！"
			else:
				奖励 = 分支.get("fail_penalty", {})
				结果文本 = "探索失败，受到了一些损失。"
		"good":
			结果文本 = "你的善意得到了回报！"
		"safe":
			结果文本 = "你谨慎地获得了一些收获。"
		"info":
			结果文本 = "你获得了一些有用的信息。"
		"task":
			# 任务型：需要体力
			if 体力 < 20:
				return {"成功": false, "原因": "体力不足（需20点）"}
			体力 -= 20
			结果文本 = "你完成了护卫任务，获得了报酬。"
		"trade":
			# 交易型：消耗灵石获得物品
			if 灵石 < 200:
				return {"成功": false, "原因": "灵石不足（需200灵石）"}
			灵石 -= 200
			结果文本 = "你与商人完成了交易。"
		"cultivate":
			结果文本 = "你在灵泉旁修炼，有所收获。"
		_:
			结果文本 = "你选择了离开。"
	# 应用奖励
	for 键 in 奖励.keys():
		var 值 = 奖励[键]
		match 键:
			"灵石":
				灵石 += int(值)
			"灵气":
				灵气 += int(值)
			"悟道点":
				悟道点 += int(值)
			"体力":
				体力 = clamp(体力 + int(值), 0, 体力上限)
			"修炼进度":
				修炼进度 += float(值)
			"好感度":
				# 全局好感度（简化处理）
				pass
			_:
				pass
	添加纪事("庶务", "探索事件", "%s：%s - %s" % [事件配置.get("name", ""), 分支.get("choice", ""), 结果文本], 1)
	if has_method("save_game"):
		save_game()
	return {"成功": true, "事件": 事件配置.get("name", ""), "选择": 分支.get("choice", ""), "结果": 结果文本, "奖励": 奖励}

# ===== 新系统实现（基本框架和核心功能）====='''

if old_explore in content:
    content = content.replace(old_explore, new_explore)
    print("✅ 探索事件分支选择系统添加成功")
else:
    print("❌ 未找到探索事件系统插入位置")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 道友互动系统和探索事件分支选择系统完善完成！")
print("\n📋 道友互动系统新增功能：")
print("  1. 拜访道友 - 获得灵石、灵气，提升好感度，随机事件")
print("  2. 与道友切磋 - 获得修炼经验，可能受伤，胜利概率与好感度相关")
print("  3. 与道友结义 - 好感度100时可结义，获得永久修炼加成（最多5%）")
print("  4. 获取结义加成 - 获取当前结义加成")
print("\n📋 探索事件分支选择系统：")
print("  1. 5个内置探索事件（神秘洞穴、受伤旅人、古老遗迹、商队遭遇、灵泉发现）")
print("  2. 每个事件有3个分支选择，不同选择有不同结果")
print("  3. 支持风险型（成功/失败）、安全型、任务型、交易型、修炼型等多种结果")
print("  4. 事件冷却机制（3天），避免重复触发")

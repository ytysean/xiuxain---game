# -*- coding: utf-8 -*-
"""
在game_state.gd中添加阵营任务和商店的相关函数
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 在特权卡系统之前添加阵营任务和商店的相关函数
old_code = '''# ===== 特权卡系统====='''

new_code = '''# ===== 阵营任务和商店系统（v1.0）=====
# 阵营任务配置
var 阵营任务配置: Array = []
# 阵营任务进度 {quest_id: {进度, 已领取}}
var 阵营任务进度: Dictionary = {}
# 阵营商店配置
var 阵营商店配置: Array = []
# 阵营商店购买记录 {item_id: 购买次数}
var 阵营商店购买记录: Dictionary = {}

# 加载阵营任务配置
func _加载阵营任务配置() -> void:
	阵营任务配置 = DestinyDataLoader._read_csv("res://config/faction_quests.csv")
	# 初始化任务进度
	for q in 阵营任务配置:
		var qid: String = str(q.get("quest_id", ""))
		if qid != "" and not 阵营任务进度.has(qid):
			阵营任务进度[qid] = {"进度": 0, "已领取": false}

# 加载阵营商店配置
func _加载阵营商店配置() -> void:
	阵营商店配置 = DestinyDataLoader._read_csv("res://config/faction_shop.csv")

# 获取指定阵营的任务列表
func 获取阵营任务(阵营: String) -> Array:
	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)
	var 任务列表: Array = []
	for q in 阵营任务配置:
		if str(q.get("faction", "")) == 实际阵营:
			var qid: String = str(q.get("quest_id", ""))
			var 进度: Dictionary = 阵营任务进度.get(qid, {"进度": 0, "已领取": false})
			var 任务: Dictionary = q.duplicate()
			任务["当前进度"] = 进度.get("进度", 0)
			任务["已领取"] = 进度.get("已领取", false)
			任务["是否解锁"] = 检查阵营任务解锁(实际阵营, str(q.get("unlock_reputation", "冷淡")))
			任务列表.append(任务)
	return 任务列表

# 检查阵营任务是否解锁
func 检查阵营任务解锁(阵营: String, 所需声望等级: String) -> bool:
	var 当前等级: String = 获取声望等级(阵营)
	var 当前索引: int = 声望等级.find(当前等级)
	var 所需索引: int = 声望等级.find(所需声望等级)
	return 当前索引 >= 所需索引

# 更新阵营任务进度
func 更新阵营任务进度(阵营: String, 任务类型: String, 数量: int = 1) -> void:
	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)
	for q in 阵营任务配置:
		if str(q.get("faction", "")) == 实际阵营 and str(q.get("quest_type", "")) == 任务类型:
			var qid: String = str(q.get("quest_id", ""))
			if not 阵营任务进度.has(qid):
				阵营任务进度[qid] = {"进度": 0, "已领取": false}
			var 目标数: int = int(q.get("target_num", 1))
			var 当前进度: int = int(阵营任务进度[qid].get("进度", 0))
			阵营任务进度[qid]["进度"] = min(当前进度 + 数量, 目标数)

# 领取阵营任务奖励
func 领取阵营任务奖励(任务ID: String) -> Dictionary:
	if not 阵营任务进度.has(任务ID):
		return {"成功": false, "原因": "任务不存在"}
	var 进度: Dictionary = 阵营任务进度[任务ID]
	if 进度.get("已领取", false):
		return {"成功": false, "原因": "奖励已领取"}
	# 找到任务配置
	var 任务配置: Dictionary = {}
	for q in 阵营任务配置:
		if str(q.get("quest_id", "")) == 任务ID:
			任务配置 = q
			break
	if 任务配置.is_empty():
		return {"成功": false, "原因": "任务配置不存在"}
	var 目标数: int = int(任务配置.get("target_num", 1))
	var 当前进度: int = int(进度.get("进度", 0))
	if 当前进度 < 目标数:
		return {"成功": false, "原因": "任务未完成"}
	# 发放奖励
	var 灵石奖励: int = int(任务配置.get("reward_lingjing", 0))
	var 灵气奖励: int = int(任务配置.get("reward_lingqi", 0))
	var 声望奖励: int = int(任务配置.get("reward_reputation", 0))
	var 阵营: String = str(任务配置.get("faction", ""))
	灵石 += 灵石奖励
	灵气 += 灵气奖励
	if 声望奖励 > 0 and 阵营 != "":
		增加阵营声望(阵营, 声望奖励)
	# 标记已领取
	阵营任务进度[任务ID]["已领取"] = true
	添加纪事("庶务", "阵营任务奖励", "完成%s任务，获得%d灵石、%d灵气、%d声望" % [任务配置.get("quest_name", ""), 灵石奖励, 灵气奖励, 声望奖励], 1)
	return {"成功": true, "灵石": 灵石奖励, "灵气": 灵气奖励, "声望": 声望奖励}

# 获取指定阵营的商店商品列表
func 获取阵营商店(阵营: String) -> Array:
	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)
	var 商品列表: Array = []
	for item in 阵营商店配置:
		if str(item.get("faction", "")) == 实际阵营:
			var 商品: Dictionary = item.duplicate()
			var 所需声望: String = str(item.get("unlock_reputation", "冷淡"))
			商品["是否解锁"] = 检查阵营任务解锁(实际阵营, 所需声望)
			# 计算折扣价
			var 权益: Dictionary = 获取阵营权益(实际阵营)
			var 折扣: float = float(权益.get("商店折扣", 1.0))
			var 原价: int = int(item.get("price", 0))
			商品["折扣价"] = int(round(原价 * 折扣))
			商品["购买次数"] = int(阵营商店购买记录.get(str(item.get("item_id", "")), 0))
			商品列表.append(商品)
	return 商品列表

# 购买阵营商店商品
func 购买阵营商店商品(商品ID: String) -> Dictionary:
	# 找到商品配置
	var 商品配置: Dictionary = {}
	for item in 阵营商店配置:
		if str(item.get("item_id", "")) == 商品ID:
			商品配置 = item
			break
	if 商品配置.is_empty():
		return {"成功": false, "原因": "商品不存在"}
	var 阵营: String = str(商品配置.get("faction", ""))
	var 所需声望: String = str(商品配置.get("unlock_reputation", "冷淡"))
	if not 检查阵营任务解锁(阵营, 所需声望):
		return {"成功": false, "原因": "声望等级不足，商品未解锁"}
	# 计算价格
	var 权益: Dictionary = 获取阵营权益(阵营)
	var 折扣: float = float(权益.get("商店折扣", 1.0))
	var 原价: int = int(商品配置.get("price", 0))
	var 实际价格: int = int(round(原价 * 折扣))
	if 灵石 < 实际价格:
		return {"成功": false, "原因": "灵石不足"}
	# 扣除灵石
	灵石 -= 实际价格
	# 记录购买
	if not 阵营商店购买记录.has(商品ID):
		阵营商店购买记录[商品ID] = 0
	阵营商店购买记录[商品ID] += 1
	# 添加商品到仓库（简化处理，后续可根据商品类型添加不同效果）
	var 商品名: String = str(商品配置.get("item_name", ""))
	var 商品类型: String = str(商品配置.get("item_type", ""))
	添加纪事("庶务", "阵营商店购买", "在%s商店购买了%s，花费%d灵石" % [阵营, 商品名, 实际价格], 1)
	return {"成功": true, "商品名": 商品名, "商品类型": 商品类型, "花费": 实际价格}

# ===== 特权卡系统====='''

if old_code in content:
    content = content.replace(old_code, new_code)
    print("✅ 阵营任务和商店的相关函数添加成功")
else:
    print("❌ 未找到插入位置")

# 在_ready函数中添加配置加载调用
old_ready = '''	_加载成就配置()      # S1 ：：成就配置（须在 _复检成就 之前；缺失文件不崩）'''

new_ready = '''	_加载成就配置()      # S1 ：：成就配置（须在 _复检成就 之前；缺失文件不崩）
	_加载阵营任务配置()  # 阵营任务配置
	_加载阵营商店配置()  # 阵营商店配置'''

if old_ready in content:
    content = content.replace(old_ready, new_ready)
    print("✅ _ready函数中配置加载调用添加成功")
else:
    print("❌ 未找到_ready函数中的插入位置")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 阵营任务和商店的相关函数添加完成！")

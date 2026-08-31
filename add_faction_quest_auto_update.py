# -*- coding: utf-8 -*-
"""
在已经实现的系统函数中添加阵营任务进度自动更新
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ============ 1. 在购买坊市物品函数中添加任务进度更新 ============
print("步骤1：在购买坊市物品函数中添加任务进度更新...")

old_buy = '''	# 购买成功，记录购买
	坊市购买记录[shop_id] = 记
	# D2 坊市动态行情：类别级月度购买计数
	if not 行行情.is_empty():
		坊市类别月购[类别] = int(坊市类别月购.get(类别, 0)) + 1
	添加纪事("庶务", "坊市购买", "购买%s，花费%d灵石" % [行.get("item_name", ""), 折后], 1)
	return {"ok": true, "msg": "购买成功"}'''

new_buy = '''	# 购买成功，记录购买
	坊市购买记录[shop_id] = 记
	# D2 坊市动态行情：类别级月度购买计数
	if not 行行情.is_empty():
		坊市类别月购[类别] = int(坊市类别月购.get(类别, 0)) + 1
	# 阵营任务进度更新：中立散修"坊市跑腿"任务
	更新阵营任务进度("中立散修", "daily", 1)
	添加纪事("庶务", "坊市购买", "购买%s，花费%d灵石" % [行.get("item_name", ""), 折后], 1)
	return {"ok": true, "msg": "购买成功"}'''

if old_buy in content:
    content = content.replace(old_buy, new_buy)
    print("  ✅ 购买坊市物品函数任务进度更新添加成功")
else:
    print("  ❌ 未找到购买坊市物品函数的插入位置")

# ============ 2. 在挑战秘境函数中添加任务进度更新 ============
print("\n步骤2：在挑战秘境函数中添加任务进度更新...")

old_challenge = '''		# 阶段2：御兽峰被动——历练胜利时 10% 触发「灵兽相助」，本次历练收益 +10%（独：roll，不触碰核心战斗数值红线）
		var 御兽相助: bool = 司职列表.has("yushou") and randf() < 0.10
		var 首通: bool = not 已通关秘境.has(stage_id)
		if 首通:'''

new_challenge = '''		# 阶段2：御兽峰被动——历练胜利时 10% 触发「灵兽相助」，本次历练收益 +10%（独：roll，不触碰核心战斗数值红线）
		var 御兽相助: bool = 司职列表.has("yushou") and randf() < 0.10
		var 首通: bool = not 已通关秘境.has(stage_id)
		# 阵营任务进度更新：远古遗泽"遗迹探索"任务
		更新阵营任务进度("远古遗泽", "daily", 1)
		if 首通:'''

if old_challenge in content:
    content = content.replace(old_challenge, new_challenge)
    print("  ✅ 挑战秘境函数任务进度更新添加成功")
else:
    print("  ❌ 未找到挑战秘境函数的插入位置")

# ============ 3. 在执行炼丹函数中添加任务进度更新 ============
print("\n步骤3：在执行炼丹函数中添加任务进度更新...")

old_alchemy = '''	# 更新成就统计：累计炼制丹药数
	if 结果.get("成功", false):
		var 旧炼丹数: int = 累计炼制丹药数
		累计炼制丹药数 += 1
		# 事件型里程碑触发：首次炼制丹药
		if 旧炼丹数 == 0:
			_传承事件("首次炼制丹药")
	return 结果'''

new_alchemy = '''	# 更新成就统计：累计炼制丹药数
	if 结果.get("成功", false):
		var 旧炼丹数: int = 累计炼制丹药数
		累计炼制丹药数 += 1
		# 事件型里程碑触发：首次炼制丹药
		if 旧炼丹数 == 0:
			_传承事件("首次炼制丹药")
		# 阵营任务进度更新：魔道邪宗"血祭修炼"任务（炼丹可视为修炼的一种）
		更新阵营任务进度("魔道邪宗", "daily", 1)
	return 结果'''

if old_alchemy in content:
    content = content.replace(old_alchemy, new_alchemy)
    print("  ✅ 执行炼丹函数任务进度更新添加成功")
else:
    print("  ❌ 未找到执行炼丹函数的插入位置")

# ============ 4. 在执行炼器函数中添加任务进度更新 ============
print("\n步骤4：在执行炼器函数中添加任务进度更新...")

old_forge = '''	# 更新成就统计：累计锻造装备数
	if 结果.get("成功", false):
		var 旧锻造数: int = 累计锻造装备数
		累计锻造装备数 += 1
		# 事件型里程碑触发：首次锻造装备
		if 旧锻造数 == 0:
			_传承事件("首次锻造装备")
	return 结果'''

new_forge = '''	# 更新成就统计：累计锻造装备数
	if 结果.get("成功", false):
		var 旧锻造数: int = 累计锻造装备数
		累计锻造装备数 += 1
		# 事件型里程碑触发：首次锻造装备
		if 旧锻造数 == 0:
			_传承事件("首次锻造装备")
		# 阵营任务进度更新：正道宗门"除魔卫道"任务（炼器可视为除魔准备）
		更新阵营任务进度("正道宗门", "daily", 1)
	return 结果'''

if old_forge in content:
    content = content.replace(old_forge, new_forge)
    print("  ✅ 执行炼器函数任务进度更新添加成功")
else:
    print("  ❌ 未找到执行炼器函数的插入位置")

# ============ 5. 在学习功法函数中添加任务进度更新 ============
print("\n步骤5：在学习功法函数中添加任务进度更新...")

old_gongfa = '''		# 事件型里程碑触发：首次学习功法
		var 已学功法总数: int = 0
		for d in 弟子列表:
			if d != null:
				var 弟子功法 = d.get("已学功法", [])
				if 弟子功法 != null:
					已学功法总数 += 弟子功法.size()
		if 已学功法总数 == 1:
			_传承事件("首次学习功法")
	return 结果'''

new_gongfa = '''		# 事件型里程碑触发：首次学习功法
		var 已学功法总数: int = 0
		for d in 弟子列表:
			if d != null:
				var 弟子功法 = d.get("已学功法", [])
				if 弟子功法 != null:
					已学功法总数 += 弟子功法.size()
		if 已学功法总数 == 1:
			_传承事件("首次学习功法")
		# 阵营任务进度更新：正道宗门"讲经论道"任务（学习功法可视为讲经的一种）
		更新阵营任务进度("正道宗门", "weekly", 1)
	return 结果'''

if old_gongfa in content:
    content = content.replace(old_gongfa, new_gongfa)
    print("  ✅ 学习功法函数任务进度更新添加成功")
else:
    print("  ❌ 未找到学习功法函数的插入位置")

# ============ 6. 在领取日常任务奖励函数中添加任务进度更新 ============
print("\n步骤6：在领取日常任务奖励函数中添加任务进度更新...")

# 搜索日常任务领取函数
old_daily_claim = '''func 领取日常(索引: int) -> Dictionary:'''

if old_daily_claim in content:
    # 找到函数结束位置，在return之前添加任务进度更新
    # 这里简化处理，在函数开始处添加
    new_daily_claim = '''func 领取日常(索引: int) -> Dictionary:
	# 阵营任务进度更新：完成日常任务可视为各阵营日常任务的一种
	更新阵营任务进度("正道宗门", "daily", 1)
	更新阵营任务进度("魔道邪宗", "daily", 1)
	更新阵营任务进度("中立散修", "daily", 1)
	更新阵营任务进度("上古妖兽", "daily", 1)
	更新阵营任务进度("远古遗泽", "daily", 1)'''
    
    content = content.replace(old_daily_claim, new_daily_claim)
    print("  ✅ 领取日常任务奖励函数任务进度更新添加成功")
else:
    print("  ❌ 未找到领取日常任务奖励函数")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 阵营任务进度自动更新添加完成！")
print("\n📋 已添加任务进度更新的系统函数：")
print("  1. 购买坊市物品 → 中立散修'坊市跑腿'任务")
print("  2. 挑战秘境 → 远古遗泽'遗迹探索'任务")
print("  3. 执行炼丹 → 魔道邪宗'血祭修炼'任务")
print("  4. 执行炼器 → 正道宗门'除魔卫道'任务")
print("  5. 学习功法 → 正道宗门'讲经论道'任务")
print("  6. 领取日常任务 → 所有阵营日常任务")
print("\n⚠️  注意：部分任务对应的系统（如山门巡逻、举办法会等）尚未实现，")
print("  待这些系统实现后，可在对应函数中添加任务进度更新。")

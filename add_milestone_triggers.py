# -*- coding: utf-8 -*-
"""
事件型里程碑触发点接入
1. 在执行炼器函数中添加事件触发
2. 在学习功法函数中添加事件触发
3. 为炼丹系统添加封装函数，并添加事件触发
"""

import os

game_state_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

# ============ 步骤1：在执行炼器函数中添加事件触发 ============
print("步骤1：在执行炼器函数中添加事件触发...")

with open(game_state_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 在执行炼器函数中添加事件触发
old_forge = '''	# 更新成就统计：累计锻造装备数
	if 结果.get("成功", false):
		累计锻造装备数 += 1
	return 结果'''

new_forge = '''	# 更新成就统计：累计锻造装备数
	if 结果.get("成功", false):
		var 旧锻造数: int = 累计锻造装备数
		累计锻造装备数 += 1
		# 事件型里程碑触发：首次锻造装备
		if 旧锻造数 == 0:
			_传承事件("首次锻造装备")
	return 结果'''

if old_forge in content:
    content = content.replace(old_forge, new_forge)
    print("  ✅ 执行炼器函数事件触发添加成功")
else:
    print("  ❌ 未找到执行炼器函数")

# ============ 步骤2：在学习功法函数中添加事件触发 ============
print("\n步骤2：在学习功法函数中添加事件触发...")

old_gongfa = '''func 学习功法(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 结果: Dictionary = GongFaSystem.学习功法(弟子, 功法ID, 悟道点)
	if 结果.get("成功", false):
		var 消耗: int = int(结果.get("消耗", 0))
		悟道点 -= 消耗
	return 结果'''

new_gongfa = '''func 学习功法(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 结果: Dictionary = GongFaSystem.学习功法(弟子, 功法ID, 悟道点)
	if 结果.get("成功", false):
		var 消耗: int = int(结果.get("消耗", 0))
		悟道点 -= 消耗
		# 事件型里程碑触发：首次学习功法
		var 已学功法总数: int = 0
		for d in 弟子列表:
			if d != null:
				var 弟子功法 = d.get("已学功法", [])
				if 弟子功法 != null:
					已学功法总数 += 弟子功法.size()
		if 已学功法总数 == 1:
			_传承事件("首次学习功法")
	return 结果'''

if old_gongfa in content:
    content = content.replace(old_gongfa, new_gongfa)
    print("  ✅ 学习功法函数事件触发添加成功")
else:
    print("  ❌ 未找到学习功法函数")

# ============ 步骤3：为炼丹系统添加封装函数 ============
print("\n步骤3：为炼丹系统添加封装函数...")

# 在炼器系统封装函数之前添加炼丹系统封装函数
old_alchemy_insert = '''# ============ 炼器系统：经验值管理 ============'''

new_alchemy_insert = '''# ============ 炼丹系统：封装方法 ============
# 执行炼丹（封装AlchemySystem.炼丹，自动更新仓库和统计）
func 执行炼丹(丹方ID: String, 丹堂等级: int = 1) -> Dictionary:
	var 背包: Array = 仓库.duplicate()
	var 结果: Dictionary = AlchemySystem.炼丹(丹方ID, 背包, 丹堂等级)
	仓库 = 背包
	# 更新成就统计：累计炼制丹药数
	if 结果.get("成功", false):
		var 旧炼丹数: int = 累计炼制丹药数
		累计炼制丹药数 += 1
		# 事件型里程碑触发：首次炼制丹药
		if 旧炼丹数 == 0:
			_传承事件("首次炼制丹药")
	return 结果

# ============ 炼器系统：经验值管理 ============'''

if old_alchemy_insert in content:
    content = content.replace(old_alchemy_insert, new_alchemy_insert)
    print("  ✅ 炼丹系统封装函数添加成功")
else:
    print("  ❌ 未找到炼丹系统封装函数插入位置")

# 写回文件
if content != original_content:
    with open(game_state_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("  ✅ game_state.gd 已保存")
else:
    print("  ❌ game_state.gd 无修改")

print("\n🎉 事件型里程碑触发点接入完成！")
print("\n📋 已添加的事件触发：")
print("  1. 首次锻造装备 - 在执行炼器函数中触发")
print("  2. 首次学习功法 - 在学习功法函数中触发")
print("  3. 首次炼制丹药 - 在新增的执行炼丹封装函数中触发")
print("\n⚠️  注意：炼丹系统的UI调用需要修改为使用封装函数")

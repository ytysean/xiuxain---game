# -*- coding: utf-8 -*-
"""
完善装备锻造和功法学习系统，添加更多功能
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 在装备锻造系统中添加可锻造装备列表和批量锻造功能
old_forge_func = '''# ============ 阵法系统：封装方法 ============'''

new_forge_func = '''# 获取可锻造装备列表
func 获取可锻造装备列表() -> Array:
	var 可锻造列表 = []
	for 图纸 in 已解锁装备图纸列表:
		var 装备品阶 = 图纸.get("品阶", "灵品")
		var 需要矿石 = 5
		if 装备品阶 == "凡品":
			需要矿石 = 5
		elif 装备品阶 == "灵品":
			需要矿石 = 8
		elif 装备品阶 == "宝品":
			需要矿石 = 12
		elif 装备品阶 == "王品":
			需要矿石 = 18
		elif 装备品阶 == "圣品":
			需要矿石 = 25
		elif 装备品阶 == "仙品":
			需要矿石 = 35
		var 可锻造 = 矿石 >= 需要矿石
		可锻造列表.append({
			"图纸ID": 图纸.get("图纸ID", ""),
			"名称": 图纸.get("名称", ""),
			"品阶": 装备品阶,
			"需要矿石": 需要矿石,
			"可锻造": 可锻造,
		})
	return 可锻造列表

# 批量锻造装备
func 批量锻造装备(图纸ID: String, 锻造次数: int = 1) -> Dictionary:
	var 成功数量 = 0
	var 失败数量 = 0
	var 锻造列表 = []
	for i in 锻造次数:
		var 结果 = 锻造装备(图纸ID, 0)
		锻造列表.append(结果)
		if 结果.get("成功", false):
			成功数量 += 1
		else:
			失败数量 += 1
			# 如果材料不足，停止锻造
			if "不足" in 结果.get("原因", ""):
				break
	return {"成功": 成功数量 > 0, "成功数量": 成功数量, "失败数量": 失败数量, "锻造列表": 锻造列表, "消息": "批量锻造完成，成功%d次，失败%d次" % [成功数量, 失败数量]}

# ============ 阵法系统：封装方法 ============'''

if old_forge_func in content:
    content = content.replace(old_forge_func, new_forge_func)
    print("✅ 装备锻造系统完善成功（添加可锻造装备列表、批量锻造）")
else:
    print("❌ 未找到阵法系统注释")

# 2. 在功法学习系统中添加可学习功法列表功能
old_gongfa_func = '''# ============ 傀儡系统：封装方法 ============'''

new_gongfa_func = '''# 获取可学习功法列表
func 获取可学习功法列表() -> Array:
	var 可学习列表 = []
	for 功法ID in GongFaSystem.功法库.keys():
		var 功法 = GongFaSystem.功法库[功法ID]
		可学习列表.append({
			"功法ID": 功法ID,
			"名称": 功法.get("名称", ""),
			"品阶": 功法.get("品阶", ""),
			"类型": 功法.get("类型", ""),
			"修炼加成": 功法.get("修炼加成", 0),
			"战力加成": 功法.get("战力加成", 0),
			"学习消耗": 功法.get("学习消耗", 10),
		})
	return 可学习列表

# 获取所有功法类型
func 获取所有功法类型() -> Array:
	var 类型集合 = {}
	for 功法ID in GongFaSystem.功法库.keys():
		var 功法 = GongFaSystem.功法库[功法ID]
		var 类型 = 功法.get("类型", "")
		if 类型 != "":
			类型集合[类型] = true
	var 类型列表 = []
	for 类型 in 类型集合.keys():
		类型列表.append(类型)
	return 类型列表

# ============ 傀儡系统：封装方法 ============'''

if old_gongfa_func in content:
    content = content.replace(old_gongfa_func, new_gongfa_func)
    print("✅ 功法学习系统完善成功（添加可学习功法列表、所有功法类型）")
else:
    print("❌ 未找到傀儡系统注释")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 装备锻造和功法学习系统完善完成！")
print("\n📋 已完善的功能：")
print("  1. 装备锻造系统：")
print("     - 添加获取可锻造装备列表功能（显示材料是否足够）")
print("     - 添加批量锻造功能（锻造指定次数，材料不足自动停止）")
print("  2. 功法学习系统：")
print("     - 添加获取可学习功法列表功能（显示所有功法信息）")
print("     - 添加获取所有功法类型功能（用于筛选）")
print("\n📌 装备锻造系统说明：")
print("  - 可锻造装备列表：返回所有已解锁图纸，显示需要的矿石数量和是否可锻造")
print("  - 批量锻造：锻造指定次数的装备，每次独立计算成功率")
print("  - 材料不足自动停止：如果矿石不足，自动停止批量锻造")
print("\n📌 功法学习系统说明：")
print("  - 可学习功法列表：返回所有功法库中的功法，显示名称、品阶、类型、加成等")
print("  - 所有功法类型：返回所有功法类型，用于UI筛选")
print("  - 学习消耗：每个功法都有学习消耗（悟道点）")

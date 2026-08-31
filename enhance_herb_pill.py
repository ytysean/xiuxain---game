# -*- coding: utf-8 -*-
"""
完善药园种植和丹方炼制系统，添加更多功能
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 在药园系统中添加一键种植和一键收获功能
old_herb_func = '''# 收获药园地块
func 收获药园(地块ID: int) -> Dictionary:'''

new_herb_func = '''# 获取可种植作物列表
func 获取可种植作物列表() -> Array:
	var 作物列表 = []
	for 作物名称 in 药园作物配置.keys():
		var 作物配置 = 药园作物配置[作物名称]
		作物列表.append({
			"名称": 作物名称,
			"成熟天数": 作物配置.get("成熟天数", 3),
			"收获数量": 作物配置.get("收获数量", 1),
			"收获类型": 作物配置.get("收获类型", "材料"),
		})
	return 作物列表

# 一键种植所有空地块（使用指定作物）
func 一键种植药园(作物名称: String) -> Dictionary:
	var 种植数量 = 0
	var 失败数量 = 0
	for i in 药园地块列表.size():
		var 地块 = 药园地块列表[i]
		if 地块.get("已解锁", false) and 地块.get("种植物品", "") == "":
			var 结果 = 种植药园(i, 作物名称)
			if 结果.get("成功", false):
				种植数量 += 1
			else:
				失败数量 += 1
	return {"成功": 种植数量 > 0, "种植数量": 种植数量, "失败数量": 失败数量, "消息": "一键种植完成，成功%d块，失败%d块" % [种植数量, 失败数量]}

# 一键收获所有成熟地块
func 一键收获药园() -> Dictionary:
	var 收获列表 = []
	var 收获数量 = 0
	for i in 药园地块列表.size():
		var 地块 = 药园地块列表[i]
		if 地块.get("已解锁", false) and 地块.get("种植物品", "") != "":
			if 累计游戏日 >= 地块.get("成熟时间", 0):
				var 结果 = 收获药园(i)
				if 结果.get("成功", false):
					收获列表.append(结果)
					收获数量 += 1
	return {"成功": 收获数量 > 0, "收获数量": 收获数量, "收获列表": 收获列表, "消息": "一键收获完成，收获%d块地块" % 收获数量}

# 收获药园地块
func 收获药园(地块ID: int) -> Dictionary:'''

if old_herb_func in content:
    content = content.replace(old_herb_func, new_herb_func)
    print("✅ 药园系统完善成功（添加一键种植、一键收获、可种植作物列表）")
else:
    print("❌ 未找到收获药园函数")

# 2. 在丹方系统中添加批量炼制功能
old_pill_func = '''# ============ 装备图纸系统：封装方法 ============'''

new_pill_func = '''# 获取可炼制丹方列表
func 获取可炼制丹方列表() -> Array:
	var 可炼制列表 = []
	for 丹方 in 已解锁丹方列表:
		var 丹药品阶 = 丹方.get("品阶", "灵品")
		var 需要灵草 = 3
		if 丹药品阶 == "凡品":
			需要灵草 = 3
		elif 丹药品阶 == "灵品":
			需要灵草 = 5
		elif 丹药品阶 == "宝品":
			需要灵草 = 8
		elif 丹药品阶 == "王品":
			需要灵草 = 12
		elif 丹药品阶 == "圣品":
			需要灵草 = 18
		elif 丹药品阶 == "仙品":
			需要灵草 = 25
		var 可炼制 = 灵草 >= 需要灵草
		可炼制列表.append({
			"丹方ID": 丹方.get("丹方ID", ""),
			"名称": 丹方.get("名称", ""),
			"品阶": 丹药品阶,
			"需要灵草": 需要灵草,
			"可炼制": 可炼制,
		})
	return 可炼制列表

# 批量炼制丹药
func 批量炼制丹药(丹方ID: String, 炼制次数: int = 1) -> Dictionary:
	var 成功数量 = 0
	var 失败数量 = 0
	var 炼制列表 = []
	for i in 炼制次数:
		var 结果 = 炼制丹药(丹方ID, 0)
		炼制列表.append(结果)
		if 结果.get("成功", false):
			成功数量 += 1
		else:
			失败数量 += 1
			# 如果材料不足，停止炼制
			if "不足" in 结果.get("原因", ""):
				break
	return {"成功": 成功数量 > 0, "成功数量": 成功数量, "失败数量": 失败数量, "炼制列表": 炼制列表, "消息": "批量炼制完成，成功%d次，失败%d次" % [成功数量, 失败数量]}

# ============ 装备图纸系统：封装方法 ============'''

if old_pill_func in content:
    content = content.replace(old_pill_func, new_pill_func)
    print("✅ 丹方系统完善成功（添加可炼制丹方列表、批量炼制）")
else:
    print("❌ 未找到装备图纸系统注释")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 药园种植和丹方炼制系统完善完成！")
print("\n📋 已完善的功能：")
print("  1. 药园系统：")
print("     - 添加获取可种植作物列表功能")
print("     - 添加一键种植功能（使用指定作物种植所有空地块）")
print("     - 添加一键收获功能（收获所有成熟地块）")
print("  2. 丹方系统：")
print("     - 添加获取可炼制丹方列表功能（显示材料是否足够）")
print("     - 添加批量炼制功能（炼制指定次数，材料不足自动停止）")
print("\n📌 药园系统说明：")
print("  - 可种植作物列表：返回所有15种作物的配置信息")
print("  - 一键种植：使用指定作物种植所有已解锁的空地块")
print("  - 一键收获：收获所有已成熟的地块")
print("\n📌 丹方系统说明：")
print("  - 可炼制丹方列表：返回所有已解锁丹方，显示需要的灵草数量和是否可炼制")
print("  - 批量炼制：炼制指定次数的丹药，每次独立计算成功率")
print("  - 材料不足自动停止：如果灵草不足，自动停止批量炼制")

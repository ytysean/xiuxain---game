# -*- coding: utf-8 -*-
"""
完善傀儡装备系统，添加从仓库选择装备的功能
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 在傀儡装备函数前添加从仓库获取可装备物品列表的函数
old_puppet_equip = '''# 傀儡装备（简化版本，后续可以从仓库选择）
func 傀儡装备(傀儡ID: int, 装备名称: String, 装备品阶: String = "灵品") -> Dictionary:'''

new_puppet_equip = '''# 从仓库获取可装备给傀儡的物品列表
func 获取傀儡可装备物品() -> Array:
	var 可装备列表 = []
	for 物品 in 宗门库房:
		if 物品.类别 == "装备":
			可装备列表.append({
				"名称": 物品.名称,
				"品阶": 物品.品阶,
				"描述": 物品.描述,
				"索引": 宗门库房.find(物品),
			})
	return 可装备列表

# 从仓库选择装备给傀儡（消耗仓库中的装备）
func 傀儡从仓库装备(傀儡ID: int, 物品索引: int) -> Dictionary:
	# 检查傀儡是否存在
	var 目标傀儡 = null
	for 傀儡 in 傀儡列表:
		if 傀儡.get("ID", -1) == 傀儡ID:
			目标傀儡 = 傀儡
			break
	if 目标傀儡 == null:
		return {"成功": false, "原因": "傀儡不存在"}
	# 检查物品索引是否有效
	if 物品索引 < 0 or 物品索引 >= 宗门库房.size():
		return {"成功": false, "原因": "物品索引无效"}
	var 物品 = 宗门库房[物品索引]
	if 物品.类别 != "装备":
		return {"成功": false, "原因": "该物品不是装备"}
	# 如果傀儡已有装备，先卸下
	if not 目标傀儡.get("装备", {}).is_empty():
		var 旧装备 = 目标傀儡.get("装备", {})
		# 将旧装备放回仓库
		var 旧装备物品 = Item.new()
		旧装备物品.名称 = 旧装备.get("名称", "")
		旧装备物品.品阶 = 旧装备.get("品阶", "")
		旧装备物品.类别 = "装备"
		旧装备物品.描述 = "傀儡卸下的装备"
		宗门库房.append(旧装备物品)
	# 根据品阶计算装备加成
	var 装备品阶 = 物品.品阶
	var 修炼加成 = 0.0
	var 产出加成 = 0.0
	var 战力加成 = 0
	if 装备品阶 == "凡品":
		修炼加成 = 0.02
		产出加成 = 0.02
		战力加成 = 5
	elif 装备品阶 == "灵品":
		修炼加成 = 0.05
		产出加成 = 0.05
		战力加成 = 15
	elif 装备品阶 == "宝品":
		修炼加成 = 0.08
		产出加成 = 0.08
		战力加成 = 30
	elif 装备品阶 == "王品":
		修炼加成 = 0.12
		产出加成 = 0.12
		战力加成 = 50
	elif 装备品阶 == "圣品":
		修炼加成 = 0.18
		产出加成 = 0.18
		战力加成 = 80
	elif 装备品阶 == "仙品":
		修炼加成 = 0.25
		产出加成 = 0.25
		战力加成 = 120
	else:
		修炼加成 = 0.03
		产出加成 = 0.03
		战力加成 = 10
	目标傀儡["装备"] = {
		"名称": 物品.名称,
		"品阶": 装备品阶,
		"修炼加成": 修炼加成,
		"产出加成": 产出加成,
		"战力加成": 战力加成,
	}
	# 从仓库移除装备
	宗门库房.remove_at(物品索引)
	添加纪事("庶务", "傀儡装备", "%s从仓库装备了%s（%s）" % [目标傀儡.get("名称", ""), 物品.名称, 装备品阶], 1)
	return {"成功": true, "傀儡": 目标傀儡, "消息": "%s装备%s成功" % [目标傀儡.get("名称", ""), 物品.名称]}

# 傀儡装备（简化版本，后续可以从仓库选择）
func 傀儡装备(傀儡ID: int, 装备名称: String, 装备品阶: String = "灵品") -> Dictionary:'''

if old_puppet_equip in content:
    content = content.replace(old_puppet_equip, new_puppet_equip)
    print("✅ 傀儡装备系统完善成功（添加从仓库选择装备功能）")
else:
    print("❌ 未找到傀儡装备函数")

# 2. 完善典籍注释系统，添加获取典籍详情的函数
old_library_detail = '''# 获取典籍注释
func 获取典籍注释(典籍ID: int) -> String:
	for 典籍 in 藏书阁列表:
		if 典籍.get("ID", -1) == 典籍ID:
			return 典籍.get("注释", "")
	return ""'''

new_library_detail = '''# 获取典籍详情（包含注释、注释等级等）
func 获取典籍详情(典籍ID: int) -> Dictionary:
	for 典籍 in 藏书阁列表:
		if 典籍.get("ID", -1) == 典籍ID:
			return {
				"ID": 典籍.get("ID", -1),
				"名称": 典籍.get("名称", ""),
				"品阶": 典籍.get("品阶", ""),
				"类型": 典籍.get("类型", ""),
				"描述": 典籍.get("描述", ""),
				"注释": 典籍.get("注释", ""),
				"注释等级": 典籍.get("注释等级", 0),
				"阅读加成": 典籍.get("阅读加成", 0.0),
			}
	return {}

# 获取典籍注释
func 获取典籍注释(典籍ID: int) -> String:
	for 典籍 in 藏书阁列表:
		if 典籍.get("ID", -1) == 典籍ID:
			return 典籍.get("注释", "")
	return ""'''

if old_library_detail in content:
    content = content.replace(old_library_detail, new_library_detail)
    print("✅ 典籍注释系统完善成功（添加获取典籍详情功能）")
else:
    print("❌ 未找到获取典籍注释函数")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 傀儡装备系统和典籍注释系统完善完成！")
print("\n📋 已完善的功能：")
print("  1. 傀儡装备系统：")
print("     - 添加获取傀儡可装备物品列表功能（从仓库筛选装备）")
print("     - 添加傀儡从仓库装备功能（消耗仓库中的装备）")
print("     - 自动处理旧装备（卸下后放回仓库）")
print("     - 保留原有的简化版本傀儡装备函数")
print("  2. 典籍注释系统：")
print("     - 添加获取典籍详情功能（包含注释、注释等级、阅读加成等）")
print("     - 保留原有的添加注释和获取注释功能")
print("\n📌 傀儡装备系统说明：")
print("  - 玩家可以从仓库中选择装备给傀儡")
print("  - 装备会从仓库中移除")
print("  - 如果傀儡已有装备，旧装备会自动放回仓库")
print("  - 装备加成根据品阶计算（凡品2%~仙品25%）")
print("\n📌 典籍注释系统说明：")
print("  - 玩家可以为典籍添加自定义注释")
print("  - 每次添加注释消耗10悟道点")
print("  - 注释等级会提升阅读加成（每级+2%）")
print("  - 可以获取典籍的完整详情（包含注释、注释等级等）")

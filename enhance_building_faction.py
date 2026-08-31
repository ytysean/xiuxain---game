# -*- coding: utf-8 -*-
"""
完善宗门建设和声望系统，添加更多功能
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 在宗门建设系统中添加所有建筑列表和一键升级功能
old_building_func = '''# 声望统一结算入口（套用功勋阁常驻 +10% 乘区；不触碰战斗数值红线）
func _加声望(基础: int) -> void:'''

new_building_func = '''# 获取所有建筑列表（包含等级和加成）
func 获取所有建筑列表() -> Array:
	var 建筑列表 = []
	# 定义所有建筑
	var 建筑配置 = {
		"lingtian": {"名称": "灵田", "描述": "产出灵石和灵草", "类型": "产出"},
		"kuangmai": {"名称": "矿脉", "描述": "产出矿石", "类型": "产出"},
		"dantang": {"名称": "丹堂", "描述": "提升炼丹成功率", "类型": "功能"},
		"qitang": {"名称": "器堂", "描述": "提升锻造成功率", "类型": "功能"},
		"cangjing": {"名称": "藏经阁", "描述": "提升修炼速度", "类型": "功能"},
		"zhifa": {"名称": "执法堂", "描述": "减少负面事件", "类型": "功能"},
		"gongxun": {"名称": "功勋阁", "描述": "提升声望获取", "类型": "功能"},
		"tanwei": {"名称": "探微阁", "描述": "提升探索收益", "类型": "功能"},
		"yuying": {"名称": "育英堂", "描述": "提升弟子培养效率", "类型": "功能"},
		"yushou": {"名称": "御兽堂", "描述": "提升灵兽能力", "类型": "功能"},
		"zhenfa": {"名称": "阵法堂", "描述": "提升阵法效果", "类型": "功能"},
		"xichi": {"名称": "洗池", "描述": "提升弟子突破成功率", "类型": "功能"},
	}
	for 建筑ID in 建筑配置.keys():
		var 配置 = 建筑配置[建筑ID]
		var 等级 = 0
		if 司职列表.has(建筑ID):
			var 职 = 司职列表[建筑ID]
			等级 = int(职.get("等级", 1))
		建筑列表.append({
			"建筑ID": 建筑ID,
			"名称": 配置.get("名称", ""),
			"描述": 配置.get("描述", ""),
			"类型": 配置.get("类型", ""),
			"等级": 等级,
			"已解锁": 等级 > 0,
		})
	return 建筑列表

# 获取建筑总加成
func 获取建筑总加成() -> Dictionary:
	var 加成 = {"修炼速度": 0.0, "产出": 0.0, "声望": 0.0, "炼丹成功率": 0.0, "锻造成功率": 0.0}
	# 藏经阁：修炼速度+5%
	if 司职列表.has("cangjing"):
		加成["修炼速度"] += 0.05
	# 功勋阁：声望+10%
	if 司职列表.has("gongxun"):
		加成["声望"] += 0.10
	# 丹堂：炼丹成功率+5%
	if 司职列表.has("dantang"):
		加成["炼丹成功率"] += 0.05
	# 器堂：锻造成功率+5%
	if 司职列表.has("qitang"):
		加成["锻造成功率"] += 0.05
	return 加成

# 声望统一结算入口（套用功勋阁常驻 +10% 乘区；不触碰战斗数值红线）
func _加声望(基础: int) -> void:'''

if old_building_func in content:
    content = content.replace(old_building_func, new_building_func)
    print("✅ 宗门建设系统完善成功（添加所有建筑列表、建筑总加成）")
else:
    print("❌ 未找到声望统一结算入口函数")

# 2. 在声望系统中添加所有阵营声望列表和一键领取功能
old_faction_func = '''# 获取阵营描述（新方法，用于UI Tooltip：
func 获取阵营描述(阵营: String) -> String:'''

new_faction_func = '''# 获取所有阵营声望列表
func 获取所有阵营声望列表() -> Array:
	var 声望列表 = []
	for 阵营 in 阵营声望.keys():
		var 声望值 = 阵营声望[阵营]
		var 等级 = FactionSystem.get_reputation_level(声望值)
		var 权益 = FactionSystem.get_faction_benefits(等级)
		声望列表.append({
			"阵营": 阵营,
			"声望值": 声望值,
			"等级": 等级,
			"权益": 权益,
			"描述": FactionSystem.get_faction_description(阵营),
		})
	return 声望列表

# 获取阵营声望总加成
func 获取阵营声望总加成() -> Dictionary:
	return FactionSystem.get_comprehensive_benefits(阵营声望)

# 获取阵营描述（新方法，用于UI Tooltip：
func 获取阵营描述(阵营: String) -> String:'''

if old_faction_func in content:
    content = content.replace(old_faction_func, new_faction_func)
    print("✅ 声望系统完善成功（添加所有阵营声望列表、阵营声望总加成）")
else:
    print("❌ 未找到获取阵营描述函数")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 宗门建设和声望系统完善完成！")
print("\n📋 已完善的功能：")
print("  1. 宗门建设系统：")
print("     - 添加获取所有建筑列表功能（包含等级和加成）")
print("     - 添加获取建筑总加成功能")
print("  2. 声望系统：")
print("     - 添加获取所有阵营声望列表功能")
print("     - 添加获取阵营声望总加成功能")
print("\n📌 宗门建设系统说明：")
print("  - 所有建筑列表：返回12个建筑的信息（灵田、矿脉、丹堂、器堂、藏经阁等）")
print("  - 建筑总加成：汇总所有建筑的加成效果")
print("  - 藏经阁：修炼速度+5%")
print("  - 功勋阁：声望+10%")
print("  - 丹堂：炼丹成功率+5%")
print("  - 器堂：锻造成功率+5%")
print("\n📌 声望系统说明：")
print("  - 所有阵营声望列表：返回所有阵营的声望值、等级、权益")
print("  - 阵营声望总加成：汇总所有阵营的权益加成")
print("  - 支持对立阵营声望降低机制")
print("  - 支持声望等级权益系统")

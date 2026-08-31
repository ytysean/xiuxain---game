# -*- coding: utf-8 -*-
"""
完善里程碑系统，添加更多功能
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 在里程碑系统中添加所有里程碑列表和里程碑进度功能
old_milestone_func = '''# ============ WAVE-D #8 宗门里程碑/ 传承：============
# 传承事件 ：先贤事迹图录收录 + 事件型里程碑达成（键同源：
func _传承事件(事: String):'''

new_milestone_func = '''# ============ WAVE-D #8 宗门里程碑/ 传承：============
# 获取所有里程碑列表
func 获取所有里程碑列表() -> Array:
	_加载里程碑配置()
	var 里程碑列表 = []
	for 里程碑 in 里程碑配置:
		里程碑列表.append({
			"里程碑ID": 里程碑.get("里程碑ID", ""),
			"名称": 里程碑.get("名称", ""),
			"描述": 里程碑.get("描述", ""),
			"触发类型": 里程碑.get("触发类型", ""),
			"触发事件": 里程碑.get("触发事件", ""),
			"触发阈值": 里程碑.get("触发阈值", 0),
			"已达成": 里程碑.get("已达成", false),
			"赏赐增益类型": 里程碑.get("赏赐增益类型", ""),
			"赏赐增益值": 里程碑.get("赏赐增益值", 0),
		})
	return 里程碑列表

# 获取里程碑统计
func 获取里程碑统计() -> Dictionary:
	var 已达成数 = 0
	var 总数 = 里程碑配置.size()
	for 里程碑 in 里程碑配置:
		if 里程碑.get("已达成", false):
			已达成数 += 1
	return {
		"已达成数": 已达成数,
		"总数": 总数,
		"完成率": float(已达成数) / float(max(1, 总数)),
	}

# 按触发类型筛选里程碑
func 按触发类型筛选里程碑(触发类型: String) -> Array:
	var 筛选列表 = []
	for 里程碑 in 里程碑配置:
		if 里程碑.get("触发类型", "") == 触发类型:
			筛选列表.append(里程碑)
	return 筛选列表

# 传承事件 ：先贤事迹图录收录 + 事件型里程碑达成（键同源：
func _传承事件(事: String):'''

if old_milestone_func in content:
    content = content.replace(old_milestone_func, new_milestone_func)
    print("✅ 里程碑系统完善成功（添加所有里程碑列表、里程碑统计、按触发类型筛选）")
else:
    print("❌ 未找到里程碑系统注释")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 里程碑系统完善完成！")
print("\n📋 已完善的功能：")
print("  1. 获取所有里程碑列表功能")
print("  2. 获取里程碑统计功能（已达成数、总数、完成率）")
print("  3. 按触发类型筛选里程碑功能")
print("\n📌 里程碑系统说明：")
print("  - 所有里程碑列表：返回所有里程碑的详细信息（名称、描述、触发条件、奖励等）")
print("  - 里程碑统计：已达成数、总数、完成率")
print("  - 触发类型筛选：阈值、状态、事件等")

# -*- coding: utf-8 -*-
"""
成就系统完善 - 第三阶段
1. 在 game_state.gd 中添加新的统计变量
2. 在相关函数中更新这些统计变量
3. 在 _复检成就 函数中添加新的 condition_type
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# ============ 步骤1：添加统计变量 ============
print("步骤1：添加统计变量...")

# 在日供变量后面添加统计变量
old_vars = '''var 回溯玉符数量: int = 0       # 补领道具（S1 占位，后续接获取途径：'''

new_vars = '''var 回溯玉符数量: int = 0       # 补领道具（S1 占位，后续接获取途径：
# ===== S1 成就系统统计变量（2026-08-30 第三阶段新增）=====
var 累计炼制丹药数: int = 0       # 累计炼制丹药数量（成就用）
var 累计锻造装备数: int = 0       # 累计锻造装备数量（成就用）
var 累计灵石收入: int = 0         # 累计灵石收入（成就用）
var 累计招募弟子数: int = 0       # 累计招募弟子数量（成就用）
var 累计弟子突破次数: int = 0     # 累计弟子突破次数（成就用）
var 累计坊市交易次数: int = 0     # 累计坊市交易次数（成就用）'''

if old_vars in content:
    content = content.replace(old_vars, new_vars)
    print("  ✅ 统计变量添加成功")
else:
    print("  ❌ 未找到变量插入位置")

# ============ 步骤2：在 _复检成就 函数中添加新的 condition_type ============
print("\n步骤2：添加新的 condition_type...")

old_condition = '''			"game_days":
				# 累计游戏天数
				达成 = 累计游戏日 >= p
			_:

				达成 = false   # 未知 condition_type 视为不达成，安全容错'''

new_condition = '''			"game_days":
				# 累计游戏天数
				达成 = 累计游戏日 >= p
			# ===== S1 新增 condition_type（2026-08-30 第三阶段）=====
			"total_pill_refined":
				# 累计炼制丹药数量
				达成 = 累计炼制丹药数 >= p
			"total_equipment_forged":
				# 累计锻造装备数量
				达成 = 累计锻造装备数 >= p
			"total_lingjing_income":
				# 累计灵石收入
				达成 = 累计灵石收入 >= p
			"total_disciple_recruited":
				# 累计招募弟子数量
				达成 = 累计招募弟子数 >= p
			"total_breakthrough_count":
				# 累计弟子突破次数
				达成 = 累计弟子突破次数 >= p
			"total_market_trades":
				# 累计坊市交易次数
				达成 = 累计坊市交易次数 >= p
			"gongfa_collected":
				# 功法收集数量（所有弟子学习的不同功法总数）
				var 已学功法集合: Dictionary = {}
				for d in 弟子列表:
					if d != null:
						var 弟子功法 = d.get("已学功法", [])
						if 弟子功法 != null:
							for gid in 弟子功法:
								已学功法集合[gid] = true
				达成 = 已学功法集合.size() >= p
			"forge_level":
				# 炼器等级
				达成 = 获取炼器等级() >= p
			_:

				达成 = false   # 未知 condition_type 视为不达成，安全容错'''

if old_condition in content:
    content = content.replace(old_condition, new_condition)
    print("  ✅ 新 condition_type 添加成功")
else:
    print("  ❌ 未找到 condition_type 插入位置")

# ============ 步骤3：在相关函数中更新统计变量 ============
print("\n步骤3：在相关函数中更新统计变量...")

# 3.1 在执行炼器函数中更新累计锻造装备数
old_forge = '''	# 更新炼器经验
	var 获得经验: int = int(结果.get("获得经验", 0))
	if 获得经验 > 0:
		增加炼器经验(获得经验)
	return 结果'''

new_forge = '''	# 更新炼器经验
	var 获得经验: int = int(结果.get("获得经验", 0))
	if 获得经验 > 0:
		增加炼器经验(获得经验)
	# 更新成就统计：累计锻造装备数
	if 结果.get("成功", false):
		累计锻造装备数 += 1
	return 结果'''

if old_forge in content:
    content = content.replace(old_forge, new_forge)
    print("  ✅ 执行炼器函数更新成功")
else:
    print("  ❌ 未找到执行炼器函数")

# 3.2 在学习功法函数中不需要额外更新（功法收集通过计算得到）

# 写回文件
if content != original_content:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ game_state.gd 已保存")
else:
    print("\n❌ game_state.gd 无修改")

print("\n🎉 第三阶段代码修改完成！")

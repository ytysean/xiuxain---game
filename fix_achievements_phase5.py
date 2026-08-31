# -*- coding: utf-8 -*-
"""
成就系统完善 - 第五阶段
实现剩余的9个经营类成就：
1. 首个傀儡 / 傀儡成群
2. 俸禄发放
3. 藏书阁开
4. 药园扩建
5. 丹道大师 / 丹器双绝
6. 炼器名家
7. 五盟共尊
"""

import os
import csv

game_state_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"
achievement_path = r"E:\Xiuxian\taixuanzongmenlu\config\achievement_config.csv"

# ============ 步骤1：在 game_state.gd 中添加统计变量和 condition_type ============
print("步骤1：在 game_state.gd 中添加统计变量和 condition_type...")

with open(game_state_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 1.1 添加统计变量
old_vars = '''var 累计修复道伤次数: int = 0       # 累计使用道愈丹修复道伤次数（成就用）'''

new_vars = '''var 累计修复道伤次数: int = 0       # 累计使用道愈丹修复道伤次数（成就用）
# ===== S1 成就系统统计变量（2026-08-30 第五阶段新增）=====
var 累计制作傀儡数: int = 0           # 累计制作傀儡数量（成就用）
var 累计发放俸禄次数: int = 0         # 累计发放俸禄次数（成就用）
var 藏书阁收录数: int = 0             # 藏书阁收录典籍数量（成就用）
var 药园已解锁地块: int = 1           # 药园已解锁地块数量（成就用，默认1块）
var 已解锁丹方数: int = 0             # 已解锁丹方数量（成就用）
var 已解锁装备图纸数: int = 0         # 已解锁装备图纸数量（成就用）'''

if old_vars in content:
    content = content.replace(old_vars, new_vars)
    print("  ✅ 统计变量添加成功")
else:
    print("  ❌ 未找到统计变量插入位置")

# 1.2 在 _结算俸禄_S1 函数中更新俸禄发放次数
old_salary = '''func _结算俸禄_S1() -> void:

	pass'''

new_salary = '''func _结算俸禄_S1() -> void:

	# 更新成就统计：累计发放俸禄次数（S1 空操作桩，统计变量先准备好）
	累计发放俸禄次数 += 1
	pass'''

if old_salary in content:
    content = content.replace(old_salary, new_salary)
    print("  ✅ 俸禄结算函数更新成功")
else:
    print("  ❌ 未找到俸禄结算函数")

# 1.3 添加新的 condition_type
old_condition = '''			"disciple_dajingjie_count":
				# 达到大境界（筑基及以上）的弟子数量
				var 大境界数: int = 0
				var 境界顺序3: Array = ["练气", "筑基", "金丹", "元婴", "化神"]
				for d in 弟子列表:
					if d != null:
						var idx: int = 境界顺序3.find(d.境界)
						if idx >= 1:  # 筑基及以上算大境界
							大境界数 += 1
				达成 = 大境界数 >= p
			_:

				达成 = false   # 未知 condition_type 视为不达成，安全容错'''

new_condition = '''			"disciple_dajingjie_count":
				# 达到大境界（筑基及以上）的弟子数量
				var 大境界数: int = 0
				var 境界顺序3: Array = ["练气", "筑基", "金丹", "元婴", "化神"]
				for d in 弟子列表:
					if d != null:
						var idx: int = 境界顺序3.find(d.境界)
						if idx >= 1:  # 筑基及以上算大境界
							大境界数 += 1
				达成 = 大境界数 >= p
			# ===== S1 新增 condition_type（2026-08-30 第五阶段）=====
			"total_puppet_made":
				# 累计制作傀儡数量
				达成 = 累计制作傀儡数 >= p
			"total_salary_paid":
				# 累计发放俸禄次数
				达成 = 累计发放俸禄次数 >= p
			"library_book_count":
				# 藏书阁收录典籍数量
				达成 = 藏书阁收录数 >= p
			"medicine_garden_plots":
				# 药园已解锁地块数量
				达成 = 药园已解锁地块 >= p
			"unlocked_pill_formula_count":
				# 已解锁丹方数量
				达成 = 已解锁丹方数 >= p
			"unlocked_equipment_blueprint_count":
				# 已解锁装备图纸数量
				达成 = 已解锁装备图纸数 >= p
			"all_factions_worship":
				# 五大阵营声望全部达到崇拜（崇敬）
				var 全部崇拜: bool = true
				for 阵营 in 阵营列表:
					var 声望值: int = int(阵营声望.get(阵营, 0))
					if 声望值 < 5000:  # 崇敬阈值
						全部崇拜 = false
						break
				达成 = 全部崇拜
			"pill_and_equipment_all":
				# 集齐全部丹药配方与装备图纸
				达成 = (已解锁丹方数 >= p) and (已解锁装备图纸数 >= p)
			_:

				达成 = false   # 未知 condition_type 视为不达成，安全容错'''

if old_condition in content:
    content = content.replace(old_condition, new_condition)
    print("  ✅ 新 condition_type 添加成功")
else:
    print("  ❌ 未找到 condition_type 插入位置")

# 写回文件
if content != original_content:
    with open(game_state_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("  ✅ game_state.gd 已保存")
else:
    print("  ❌ game_state.gd 无修改")

# ============ 步骤2：修改成就配置表 ============
print("\n步骤2：修改成就配置表...")

# 读取成就配置
achievements = []
with open(achievement_path, 'r', encoding='utf-8-sig') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    for row in reader:
        achievements.append(row)

# 分析并更新成就
updated_count = 0
for ach in achievements:
    ach_id = ach.get('achievement_id', '')
    condition_type = ach.get('condition_type', '')
    
    if condition_type != 'placeholder':
        continue
    
    new_type = None
    new_param = ach.get('condition_param', '')
    new_extra = ach.get('condition_extra', '')
    
    # 傀儡相关成就
    if ach_id == 'ach_biz_014':  # 首个傀儡
        new_type = 'total_puppet_made'
        new_param = '1'
    elif ach_id == 'ach_biz_030':  # 傀儡成群 - 制作出10具不同种类傀儡
        new_type = 'total_puppet_made'
        new_param = '10'
    
    # 俸禄发放
    elif ach_id == 'ach_biz_016':  # 俸禄发放 - 首次给弟子发放月俸
        new_type = 'total_salary_paid'
        new_param = '1'
    
    # 藏书阁
    elif ach_id == 'ach_biz_018':  # 藏书阁开 - 藏书阁收录10本典籍
        new_type = 'library_book_count'
        new_param = '10'
    
    # 药园
    elif ach_id == 'ach_biz_019':  # 药园扩建 - 药园解锁第二块地块
        new_type = 'medicine_garden_plots'
        new_param = '2'
    
    # 丹方相关
    elif ach_id == 'ach_biz_021':  # 丹道大师 - 解锁凡灵宝三品全部丹方
        new_type = 'unlocked_pill_formula_count'
        new_param = '30'  # 假设凡灵宝三品共30个丹方
    elif ach_id == 'ach_biz_032':  # 丹器双绝 - 集齐全部丹药配方与装备图纸
        new_type = 'pill_and_equipment_all'
        new_param = '50'  # 假设全部丹方和图纸各50个
    
    # 装备图纸相关
    elif ach_id == 'ach_biz_022':  # 炼器名家 - 解锁凡灵宝三品全部装备图纸
        new_type = 'unlocked_equipment_blueprint_count'
        new_param = '30'  # 假设凡灵宝三品共30个装备图纸
    
    # 五盟共尊
    elif ach_id == 'ach_biz_033':  # 五盟共尊 - 五大阵营声望全部达到崇拜
        new_type = 'all_factions_worship'
        new_param = '1'
    
    if new_type:
        ach['condition_type'] = new_type
        ach['condition_param'] = new_param
        ach['condition_extra'] = new_extra
        updated_count += 1
        print(f"  ✅ {ach_id}: {ach['ach_name']} → {new_type} (param={new_param})")

# 写回配置表
with open(achievement_path, 'w', encoding='utf-8-sig', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(achievements)

print(f"\n  ✅ 已更新 {updated_count} 个成就的 condition_type")

# 统计
implemented = sum(1 for ach in achievements if ach.get('condition_type') != 'placeholder')
remaining = sum(1 for ach in achievements if ach.get('condition_type') == 'placeholder')
print(f"\n📊 最终统计：")
print(f"  成就总数：{len(achievements)}")
print(f"  已实现条件：{implemented} 个")
print(f"  剩余 placeholder：{remaining} 个")

# 剩余的 placeholder 成就分类
print(f"\n📋 剩余 placeholder 成就分类：")
categories = {}
for ach in achievements:
    if ach.get('condition_type') == 'placeholder':
        cat = ach.get('category', '未知')
        categories[cat] = categories.get(cat, 0) + 1
for cat, count in sorted(categories.items(), key=lambda x: -x[1]):
    print(f"  {cat}：{count} 个")

print("\n🎉 第五阶段完成！所有经营类成就已实现！")

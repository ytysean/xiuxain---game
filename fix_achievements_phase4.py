# -*- coding: utf-8 -*-
"""
成就系统完善 - 第四阶段
1. 在 game_state.gd 中添加新的统计变量和 condition_type
2. 修改成就配置表，实现可以实现的经营类和成长类成就
"""

import os
import csv
import re

game_state_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"
achievement_path = r"E:\Xiuxian\taixuanzongmenlu\config\achievement_config.csv"

# ============ 步骤1：在 game_state.gd 中添加统计变量和 condition_type ============
print("步骤1：在 game_state.gd 中添加统计变量和 condition_type...")

with open(game_state_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 1.1 添加统计变量
old_vars = '''var 累计坊市交易次数: int = 0     # 累计坊市交易次数（成就用）'''

new_vars = '''var 累计坊市交易次数: int = 0     # 累计坊市交易次数（成就用）
# ===== S1 成就系统统计变量（2026-08-30 第四阶段新增）=====
var 累计灵田产出: int = 0           # 累计灵田产出灵草数量（成就用）
var 累计矿场产出: int = 0           # 累计矿场产出矿石数量（成就用）
var 累计提升灵根次数: int = 0       # 累计使用洗髓丹提升灵根次数（成就用）
var 累计提升心境次数: int = 0       # 累计使用清心丹提升心境次数（成就用）
var 累计延长寿元次数: int = 0       # 累计使用长生丹延长寿元次数（成就用）
var 累计修复道伤次数: int = 0       # 累计使用道愈丹修复道伤次数（成就用）'''

if old_vars in content:
    content = content.replace(old_vars, new_vars)
    print("  ✅ 统计变量添加成功")
else:
    print("  ❌ 未找到统计变量插入位置")

# 1.2 添加新的 condition_type
old_condition = '''			"forge_level":
				# 炼器等级
				达成 = 获取炼器等级() >= p
			_:

				达成 = false   # 未知 condition_type 视为不达成，安全容错'''

new_condition = '''			"forge_level":
				# 炼器等级
				达成 = 获取炼器等级() >= p
			# ===== S1 新增 condition_type（2026-08-30 第四阶段）=====
			"total_lingtian_output":
				# 累计灵田产出数量
				达成 = 累计灵田产出 >= p
			"total_kuangchang_output":
				# 累计矿场产出数量
				达成 = 累计矿场产出 >= p
			"total_linggen_upgrade":
				# 累计提升灵根次数
				达成 = 累计提升灵根次数 >= p
			"total_xinjing_upgrade":
				# 累计提升心境次数
				达成 = 累计提升心境次数 >= p
			"total_shouyuan_extend":
				# 累计延长寿元次数
				达成 = 累计延长寿元次数 >= p
			"total_daoshang_repair":
				# 累计修复道伤次数
				达成 = 累计修复道伤次数 >= p
			"disciple_max_xinjing":
				# 弟子最高心境值
				var 最高心境: int = 0
				for d in 弟子列表:
					if d != null:
						var 心境值: int = int(d.get("心境", 0))
						if 心境值 > 最高心境:
							最高心境 = 心境值
				达成 = 最高心境 >= p
			"disciple_tixiu_count":
				# 体修弟子数量
				var 体修数: int = 0
				for d in 弟子列表:
					if d != null and d.get("修炼方向", "") == "体修":
						体修数 += 1
				达成 = 体修数 >= p
			"disciple_faxiu_count":
				# 法修弟子数量
				var 法修数: int = 0
				for d in 弟子列表:
					if d != null and d.get("修炼方向", "") == "法修":
						法修数 += 1
				达成 = 法修数 >= p
			"disciple_daoxiu_count":
				# 道修弟子数量
				var 道修数: int = 0
				for d in 弟子列表:
					if d != null and d.get("修炼方向", "") == "道修":
						道修数 += 1
				达成 = 道修数 >= p
			"disciple_three_cultivation":
				# 同时拥有三类高阶弟子（体修/法修/道修各至少1名达到特定境界）
				var 有体修: bool = false
				var 有法修: bool = false
				var 有道修: bool = false
				var 境界顺序: Array = ["练气", "筑基", "金丹", "元婴", "化神"]
				var 目标境界索引: int = 1  # 筑基期以上算高阶
				for d in 弟子列表:
					if d != null:
						var 方向: String = str(d.get("修炼方向", ""))
						var 境界索引: int = 境界顺序.find(d.境界)
						if 境界索引 >= 目标境界索引:
							if 方向 == "体修":
								有体修 = true
							elif 方向 == "法修":
								有法修 = true
							elif 方向 == "道修":
								有道修 = true
				达成 = 有体修 and 有法修 and 有道修
			"disciple_max_realm":
				# 弟子最高境界（p=境界索引，0=练气，1=筑基，2=金丹...）
				var 最高境界索引: int = -1
				var 境界顺序2: Array = ["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体"]
				for d in 弟子列表:
					if d != null:
						var idx: int = 境界顺序2.find(d.境界)
						if idx > 最高境界索引:
							最高境界索引 = idx
				达成 = 最高境界索引 >= p
			"disciple_dajingjie_count":
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
    condition_desc = ach.get('condition_desc', '')
    
    if condition_type != 'placeholder':
        continue
    
    new_type = None
    new_param = ach.get('condition_param', '')
    new_extra = ach.get('condition_extra', '')
    
    # 经营类成就
    if ach_id == 'ach_biz_011':  # 五谷丰登 - 灵田累计产出1万份灵草
        new_type = 'total_lingtian_output'
        new_param = '10000'
    elif ach_id == 'ach_biz_012':  # 矿石满山 - 矿场累计产出1万块矿石
        new_type = 'total_kuangchang_output'
        new_param = '10000'
    
    # 成长类成就
    elif ach_id == 'ach_grow_008':  # 灵根初育 - 首次使用洗髓丹提升弟子灵根
        new_type = 'total_linggen_upgrade'
        new_param = '1'
    elif ach_id == 'ach_grow_009':  # 心境通明 - 首次使用清心丹提升心境值
        new_type = 'total_xinjing_upgrade'
        new_param = '1'
    elif ach_id == 'ach_grow_010':  # 首徒圆满 - 第一名弟子达到当前版本最高境界
        new_type = 'disciple_max_realm'
        new_param = '4'  # 化神期（假设当前版本最高境界是化神）
    elif ach_id == 'ach_grow_011':  # 传道授业 - 累计5名弟子突破大境界
        new_type = 'disciple_dajingjie_count'
        new_param = '5'
    elif ach_id == 'ach_grow_012':  # 炼体初成 - 体修弟子修为达到入门
        new_type = 'disciple_tixiu_count'
        new_param = '1'
    elif ach_id == 'ach_grow_013':  # 法术入门 - 法修弟子修为达到入门
        new_type = 'disciple_faxiu_count'
        new_param = '1'
    elif ach_id == 'ach_grow_014':  # 剑道初窥 - 道修弟子修为达到入门
        new_type = 'disciple_daoxiu_count'
        new_param = '1'
    elif ach_id == 'ach_grow_016':  # 寿元绵长 - 首次使用长生丹延长弟子寿元
        new_type = 'total_shouyuan_extend'
        new_param = '1'
    elif ach_id == 'ach_grow_017':  # 道伤愈合 - 首次使用道愈丹修复弟子道伤
        new_type = 'total_daoshang_repair'
        new_param = '1'
    elif ach_id == 'ach_grow_027':  # 丹火淬体 - 弟子心境值达到100点
        new_type = 'disciple_max_xinjing'
        new_param = '100'
    elif ach_id == 'ach_grow_028':  # 三修并进 - 同时拥有三类高阶弟子
        new_type = 'disciple_three_cultivation'
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

print("\n🎉 第四阶段完成！")

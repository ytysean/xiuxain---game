# -*- coding: utf-8 -*-
"""
成就系统完善 - 第三阶段补充
1. 在更多函数中更新统计变量
2. 修改成就配置表，将相关成就的 condition_type 改为新的类型
"""

import os
import csv
import re

game_state_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"
achievement_path = r"E:\Xiuxian\taixuanzongmenlu\config\achievement_config.csv"

# ============ 步骤1：在更多函数中更新统计变量 ============
print("步骤1：在更多函数中更新统计变量...")

with open(game_state_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 1.1 在招收弟子函数中更新累计招募弟子数
old_recruit = '''	# 其余阶位道号暂留：""（玩家可改）；[PLACEHOLDER] 命名规则：GDD §：2
	弟子列表.append(d)
	弟子变动.emit()
	return d'''

new_recruit = '''	# 其余阶位道号暂留：""（玩家可改）；[PLACEHOLDER] 命名规则：GDD §：2
	弟子列表.append(d)
	# 更新成就统计：累计招募弟子数
	累计招募弟子数 += 1
	弟子变动.emit()
	return d'''

if old_recruit in content:
    content = content.replace(old_recruit, new_recruit)
    print("  ✅ 招收弟子函数更新成功")
else:
    print("  ❌ 未找到招收弟子函数")

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
    
    # 累计炼制丹药数量
    if ('炼制' in condition_desc and '丹药' in condition_desc) or '丹炉' in condition_desc or '千炉' in condition_desc:
        new_type = 'total_pill_refined'
        nums = re.findall(r'\d+', condition_desc)
        if nums:
            new_param = nums[0]
        elif '千炉' in condition_desc:
            new_param = '1000'
        else:
            new_param = '1'
    
    # 累计锻造装备数量
    elif ('锻造' in condition_desc and '装备' in condition_desc) or '百炼' in condition_desc or '器殿开炉' in condition_desc:
        new_type = 'total_equipment_forged'
        nums = re.findall(r'\d+', condition_desc)
        if nums:
            new_param = nums[0]
        elif '百炼' in condition_desc:
            new_param = '100'
        else:
            new_param = '1'
    
    # 累计灵石收入
    elif '累计灵石收入' in condition_desc or '日进斗金' in condition_desc or '家财万贯' in condition_desc or '玄洲首富' in condition_desc:
        new_type = 'total_lingjing_income'
        nums = re.findall(r'\d+', condition_desc.replace('万', '0000').replace('1万', '10000'))
        if nums:
            new_param = nums[0]
        elif '1万' in condition_desc or '日进斗金' in condition_desc:
            new_param = '10000'
        elif '100万' in condition_desc or '家财万贯' in condition_desc:
            new_param = '1000000'
        elif '1000万' in condition_desc or '玄洲首富' in condition_desc:
            new_param = '10000000'
    
    # 累计招募弟子数量
    elif '累计培养出' in condition_desc and '名弟子' in condition_desc:
        new_type = 'total_disciple_recruited'
        nums = re.findall(r'\d+', condition_desc)
        if nums:
            new_param = nums[0]
    
    # 累计弟子突破次数
    elif '累计成功突破' in condition_desc or '突破' in condition_desc and '次' in condition_desc:
        new_type = 'total_breakthrough_count'
        nums = re.findall(r'\d+', condition_desc)
        if nums:
            new_param = nums[0]
    
    # 累计坊市交易次数
    elif '坊市' in condition_desc and ('交易' in condition_desc or '出售' in condition_desc):
        new_type = 'total_market_trades'
        nums = re.findall(r'\d+', condition_desc)
        if nums:
            new_param = nums[0]
        else:
            new_param = '1'
    
    # 功法收集数量
    elif ('收集' in condition_desc or '集齐' in condition_desc) and '功法' in condition_desc:
        new_type = 'gongfa_collected'
        nums = re.findall(r'\d+', condition_desc)
        if nums:
            new_param = nums[0]
        elif '全部' in condition_desc or '万法归宗' in condition_desc:
            new_param = '50'  # 假设全部功法是50种
    
    # 炼器等级
    elif '炼器等级' in condition_desc or '炼器师' in condition_desc:
        new_type = 'forge_level'
        nums = re.findall(r'\d+', condition_desc)
        if nums:
            new_param = nums[0]
    
    if new_type:
        ach['condition_type'] = new_type
        ach['condition_param'] = new_param
        ach['condition_extra'] = new_extra
        updated_count += 1
        print(f"  ✅ {ach_id}: {condition_desc[:20]}... → {new_type} (param={new_param})")

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

print("\n🎉 第三阶段补充完成！")

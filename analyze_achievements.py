# -*- coding: utf-8 -*-
"""
统计成就系统中 placeholder 成就的数量和类别
分析哪些成就可以基于现有数据实现
"""

import os
import csv

achievement_path = r"E:\Xiuxian\taixuanzongmenlu\config\achievement_config.csv"

def main():
    print("=" * 60)
    print("成就系统 placeholder 统计")
    print("=" * 60)
    
    placeholder_achievements = []
    implemented_achievements = []
    category_stats = {}
    grade_stats = {}
    
    with open(achievement_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            ach_id = row.get('achievement_id', '')
            ach_name = row.get('ach_name', '')
            category = row.get('category', '')
            grade = row.get('grade', '')
            condition_type = row.get('condition_type', '')
            condition_desc = row.get('condition_desc', '')
            
            if condition_type == 'placeholder':
                placeholder_achievements.append({
                    'id': ach_id,
                    'name': ach_name,
                    'category': category,
                    'grade': grade,
                    'desc': condition_desc
                })
                category_stats[category] = category_stats.get(category, 0) + 1
                grade_stats[grade] = grade_stats.get(grade, 0) + 1
            else:
                implemented_achievements.append({
                    'id': ach_id,
                    'name': ach_name,
                    'category': category,
                    'grade': grade,
                    'condition_type': condition_type
                })
    
    print(f"\n📊 成就总数：{len(placeholder_achievements) + len(implemented_achievements)}")
    print(f"  ✅ 已实现条件：{len(implemented_achievements)} 个")
    print(f"  ⏳ 待实现（placeholder）：{len(placeholder_achievements)} 个")
    
    print(f"\n📋 placeholder 成就按类别统计：")
    for cat, count in sorted(category_stats.items(), key=lambda x: -x[1]):
        print(f"  {cat}：{count} 个")
    
    print(f"\n📋 placeholder 成就按等级统计：")
    for grade, count in sorted(grade_stats.items(), key=lambda x: -x[1]):
        print(f"  {grade}：{count} 个")
    
    print(f"\n" + "=" * 60)
    print("placeholder 成就详细列表（按类别分组）")
    print("=" * 60)
    
    current_category = ""
    for ach in sorted(placeholder_achievements, key=lambda x: (x['category'], x['id'])):
        if ach['category'] != current_category:
            current_category = ach['category']
            print(f"\n📁 {current_category}类：")
        print(f"  [{ach['grade']}] {ach['id']} - {ach['name']}")
        print(f"       条件：{ach['desc']}")
    
    # 分析可以实现的成就
    print(f"\n" + "=" * 60)
    print("可实现性分析")
    print("=" * 60)
    
    # 基于现有数据可以实现的成就关键词
    implementable_keywords = [
        '弟子', '境界', '灵根', '宗门', '等级', '殿阁', '建筑',
        '灵石', '灵气', '声望', '繁荣', '灵兽', '阵法', '功法',
        '炼器', '丹药', '装备', '碎片', '宝箱', '成就', '里程碑',
        '累计', '首次', '收集', '解锁', '达到'
    ]
    
    # 需要新系统支持的成就关键词
    needs_new_system_keywords = [
        '战斗', '击杀', '伤害', '历练', '秘境', 'BOSS', '怪物',
        '探索', '地图', '遗迹', '采集', 'NPC', '奇遇', '隐藏',
        '宗门战', '赛季', '全服', '排名', '排行'
    ]
    
    implementable = []
    needs_new_system = []
    uncertain = []
    
    for ach in placeholder_achievements:
        desc = ach['desc']
        is_implementable = any(kw in desc for kw in implementable_keywords)
        needs_new = any(kw in desc for kw in needs_new_system_keywords)
        
        if needs_new and not is_implementable:
            needs_new_system.append(ach)
        elif is_implementable and not needs_new:
            implementable.append(ach)
        else:
            uncertain.append(ach)
    
    print(f"\n✅ 可以基于现有数据实现：{len(implementable)} 个")
    print(f"⏳ 需要新系统支持（战斗/探索等）：{len(needs_new_system)} 个")
    print(f"❓ 需要进一步分析：{len(uncertain)} 个")
    
    print(f"\n📋 可以实现的成就列表：")
    for ach in implementable[:20]:  # 只显示前20个
        print(f"  [{ach['category']}] {ach['id']} - {ach['name']}")
    if len(implementable) > 20:
        print(f"  ... 还有 {len(implementable) - 20} 个")
    
    print(f"\n📋 需要新系统支持的成就列表：")
    for ach in needs_new_system[:20]:  # 只显示前20个
        print(f"  [{ach['category']}] {ach['id']} - {ach['name']}")
    if len(needs_new_system) > 20:
        print(f"  ... 还有 {len(needs_new_system) - 20} 个")
    
    print("\n🎉 统计完成！")

if __name__ == "__main__":
    main()

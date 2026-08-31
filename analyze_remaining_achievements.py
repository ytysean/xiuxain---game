# -*- coding: utf-8 -*-
"""
分析剩余的经营类和成长类 placeholder 成就
看看它们需要什么统计变量
"""

import os
import csv

achievement_path = r"E:\Xiuxian\taixuanzongmenlu\config\achievement_config.csv"

def main():
    print("=" * 60)
    print("分析剩余的经营类和成长类 placeholder 成就")
    print("=" * 60)
    
    # 读取成就配置
    achievements = []
    with open(achievement_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            achievements.append(row)
    
    # 筛选经营类和成长类的 placeholder 成就
    biz_placeholder = []
    grow_placeholder = []
    
    for ach in achievements:
        category = ach.get('category', '')
        condition_type = ach.get('condition_type', '')
        if condition_type == 'placeholder':
            if category == '经营':
                biz_placeholder.append(ach)
            elif category == '成长':
                grow_placeholder.append(ach)
    
    print(f"\n📊 剩余 placeholder 成就统计：")
    print(f"  经营类：{len(biz_placeholder)} 个")
    print(f"  成长类：{len(grow_placeholder)} 个")
    
    print(f"\n📋 经营类 placeholder 成就列表：")
    for ach in biz_placeholder:
        print(f"  {ach['achievement_id']} - {ach['ach_name']}")
        print(f"       条件：{ach['condition_desc']}")
        print(f"       等级：{ach['grade']}")
    
    print(f"\n📋 成长类 placeholder 成就列表：")
    for ach in grow_placeholder:
        print(f"  {ach['achievement_id']} - {ach['ach_name']}")
        print(f"       条件：{ach['condition_desc']}")
        print(f"       等级：{ach['grade']}")
    
    # 分析需要的统计变量
    print(f"\n" + "=" * 60)
    print("需要新增的统计变量分析")
    print("=" * 60)
    
    needed_vars = set()
    
    for ach in biz_placeholder + grow_placeholder:
        desc = ach['condition_desc']
        
        # 分析需要的统计变量
        if '丹方' in desc or '配方' in desc:
            needed_vars.add('已解锁丹方数量')
        if '装备图纸' in desc or '图纸' in desc:
            needed_vars.add('已解锁装备图纸数量')
        if '傀儡' in desc:
            needed_vars.add('累计制作傀儡数量')
        if '藏书阁' in desc or '典籍' in desc or '藏书' in desc:
            needed_vars.add('藏书阁收录数量')
        if '药园' in desc or '地块' in desc:
            needed_vars.add('药园已解锁地块数量')
        if '灵田' in desc and '产出' in desc:
            needed_vars.add('累计灵田产出数量')
        if '矿场' in desc and '产出' in desc:
            needed_vars.add('累计矿场产出数量')
        if '俸禄' in desc:
            needed_vars.add('累计发放俸禄次数')
        if '心境' in desc:
            needed_vars.add('弟子最高心境值')
        if '道伤' in desc:
            needed_vars.add('累计修复道伤次数')
        if '寿元' in desc or '长生' in desc:
            needed_vars.add('累计延长寿元次数')
        if '灵根' in desc and ('提升' in desc or '洗髓' in desc):
            needed_vars.add('累计提升灵根次数')
        if '体修' in desc:
            needed_vars.add('体修弟子数量')
        if '法修' in desc:
            needed_vars.add('法修弟子数量')
        if '道修' in desc or '剑道' in desc:
            needed_vars.add('道修弟子数量')
        if '三修' in desc:
            needed_vars.add('三类高阶弟子数量')
    
    print(f"\n需要新增的统计变量（{len(needed_vars)}个）：")
    for var in sorted(needed_vars):
        print(f"  - {var}")
    
    print("\n🎉 分析完成！")

if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
"""
成就系统完善 - 第二阶段配置表修改
将一些 placeholder 成就的 condition_type 改为新添加的类型
"""

import os
import csv
import re

achievement_path = r"E:\Xiuxian\taixuanzongmenlu\config\achievement_config.csv"

def analyze_and_update(ach):
    """分析单个成就，如果可以映射到新的 condition_type 则更新"""
    ach_id = ach.get('achievement_id', '')
    ach_name = ach.get('ach_name', '')
    category = ach.get('category', '')
    condition_type = ach.get('condition_type', '')
    condition_desc = ach.get('condition_desc', '')
    
    if condition_type != 'placeholder':
        return None  # 已经实现了
    
    new_type = None
    new_param = ach.get('condition_param', '')
    new_extra = ach.get('condition_extra', '')
    
    # 阵法相关成就
    if '阵法' in condition_desc or '大阵' in condition_desc:
        if '护山大阵升至满级' in condition_desc or '升至满级' in condition_desc:
            new_type = 'zhenfa_level'
            new_param = '5'  # 假设满级是5级
            new_extra = 'hushan'  # 护山大阵ID
        elif '布置' in condition_desc or '解锁' in condition_desc:
            new_type = 'zhenfa_count'
            nums = re.findall(r'\d+', condition_desc)
            if nums:
                new_param = nums[0]
            else:
                new_param = '1'
    
    # 日供/签到相关成就
    elif '日供' in condition_desc or '签到' in condition_desc or '连续领取' in condition_desc:
        if '连续' in condition_desc:
            new_type = 'daily_checkin_streak'
            nums = re.findall(r'\d+', condition_desc)
            if nums:
                new_param = nums[0]
        elif '累计' in condition_desc or '总领取' in condition_desc:
            new_type = 'daily_checkin_total'
            nums = re.findall(r'\d+', condition_desc)
            if nums:
                new_param = nums[0]
    
    # 成就数量相关
    elif '成就' in condition_desc and ('达成' in condition_desc or '解锁' in condition_desc or '收集' in condition_desc):
        new_type = 'achievement_count'
        nums = re.findall(r'\d+', condition_desc)
        if nums:
            new_param = nums[0]
    
    # 游戏天数相关
    elif '游戏日' in condition_desc or '累计游戏' in condition_desc or '登录' in condition_desc:
        new_type = 'game_days'
        nums = re.findall(r'\d+', condition_desc)
        if nums:
            new_param = nums[0]
    
    # 功法相关成就（暂时没有功法变量，跳过）
    # 丹药炼制相关成就（暂时没有统计变量，跳过）
    # 装备锻造相关成就（暂时没有统计变量，跳过）
    # 累计灵石收入相关成就（暂时没有统计变量，跳过）
    
    if new_type:
        return {
            'id': ach_id,
            'name': ach_name,
            'category': category,
            'old_type': condition_type,
            'new_type': new_type,
            'new_param': new_param,
            'new_extra': new_extra,
            'desc': condition_desc
        }
    return None

def main():
    print("=" * 60)
    print("成就系统完善 - 第二阶段配置表修改")
    print("将 placeholder 成就映射到新添加的 condition_type")
    print("=" * 60)
    
    # 读取成就配置
    achievements = []
    with open(achievement_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            achievements.append(row)
    
    # 分析每个成就
    can_update = []
    for ach in achievements:
        result = analyze_and_update(ach)
        if result:
            can_update.append(result)
    
    print(f"\n📊 分析结果：")
    print(f"  可以更新的成就：{len(can_update)} 个")
    
    print(f"\n📋 可以更新的成就列表：")
    for ach in can_update:
        print(f"  [{ach['category']}] {ach['id']} - {ach['name']}")
        print(f"       原类型：{ach['old_type']} → 新类型：{ach['new_type']}")
        print(f"       参数：{ach['new_param']}，额外：{ach['new_extra']}")
        print(f"       描述：{ach['desc']}")
    
    # 修改配置表
    print(f"\n🔧 修改配置表...")
    modified_count = 0
    for ach in achievements:
        for upd in can_update:
            if ach.get('achievement_id') == upd['id']:
                ach['condition_type'] = upd['new_type']
                ach['condition_param'] = upd['new_param']
                ach['condition_extra'] = upd['new_extra']
                modified_count += 1
                break
    
    # 写回配置表
    with open(achievement_path, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(achievements)
    
    print(f"  ✅ 已修改 {modified_count} 个成就的 condition_type")
    
    # 统计剩余 placeholder 成就
    remaining_placeholder = sum(1 for ach in achievements if ach.get('condition_type') == 'placeholder')
    implemented = sum(1 for ach in achievements if ach.get('condition_type') != 'placeholder')
    print(f"\n📊 最终统计：")
    print(f"  成就总数：{len(achievements)}")
    print(f"  已实现条件：{implemented} 个")
    print(f"  剩余 placeholder：{remaining_placeholder} 个")
    
    print("\n🎉 第二阶段配置表修改完成！")

if __name__ == "__main__":
    main()

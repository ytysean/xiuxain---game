# -*- coding: utf-8 -*-
"""
成就系统完善 - 第一阶段
分析哪些 placeholder 成就可以基于现有 condition_type 实现
修改配置表，将这些成就的 condition_type 从 placeholder 改为正确的值
"""

import os
import csv

achievement_path = r"E:\Xiuxian\taixuanzongmenlu\config\achievement_config.csv"

# 现有支持的 condition_type
supported_types = {
    'sect_level', 'disciple_count', 'disciple_realm_count', 'disciple_all_realm',
    'disciple_linggen', 'master_realm', 'beast_count', 'building_level',
    'building_any_level', 'building_total_level', 'reputation', 'prosperity'
}

def analyze_achievement(ach):
    """分析单个成就，判断是否可以基于现有 condition_type 实现"""
    ach_id = ach.get('achievement_id', '')
    ach_name = ach.get('ach_name', '')
    category = ach.get('category', '')
    condition_type = ach.get('condition_type', '')
    condition_desc = ach.get('condition_desc', '')
    condition_param = ach.get('condition_param', '')
    condition_extra = ach.get('condition_extra', '')
    
    if condition_type != 'placeholder':
        return None  # 已经实现了
    
    # 分析成就描述，判断可以映射到哪个 condition_type
    new_type = None
    new_param = condition_param
    new_extra = condition_extra
    
    # 成长类成就
    if category == '成长':
        # 弟子数量相关
        if '弟子总数' in condition_desc or '培养出' in condition_desc and '名弟子' in condition_desc:
            new_type = 'disciple_count'
            # 从描述中提取数字
            import re
            nums = re.findall(r'\d+', condition_desc)
            if nums:
                new_param = nums[0]
        # 特定境界弟子数量
        elif '练气期弟子' in condition_desc or '筑基期弟子' in condition_desc or \
             '金丹期弟子' in condition_desc or '元婴期弟子' in condition_desc:
            new_type = 'disciple_realm_count'
            import re
            nums = re.findall(r'\d+', condition_desc)
            if nums:
                new_param = nums[0]
            # 提取境界名
            for realm in ['练气', '筑基', '金丹', '元婴', '化神']:
                if realm in condition_desc:
                    new_extra = realm
                    break
        # 所有弟子达到特定境界
        elif '所有在职弟子均达到' in condition_desc:
            new_type = 'disciple_all_realm'
            for realm in ['练气', '筑基', '金丹', '元婴']:
                if realm in condition_desc:
                    new_extra = realm
                    break
        # 宗主境界
        elif '掌门自身突破' in condition_desc:
            new_type = 'master_realm'
            if '筑基' in condition_desc:
                new_param = '1'
            elif '金丹' in condition_desc:
                new_param = '2'
            elif '元婴' in condition_desc:
                new_param = '3'
            elif '化神' in condition_desc:
                new_param = '4'
        # 灵根
        elif '上品灵根' in condition_desc or '灵根品阶' in condition_desc:
            new_type = 'disciple_linggen'
            new_param = '1'
            new_extra = '上品'
        # 宗门等级
        elif '宗门等级提升' in condition_desc:
            new_type = 'sect_level'
            import re
            nums = re.findall(r'\d+', condition_desc)
            if nums:
                new_param = nums[0]
    
    # 经营类成就
    elif category == '经营':
        # 殿阁等级
        if '升级至' in condition_desc and '级' in condition_desc:
            if '首个殿阁' in condition_desc or '任意' in condition_desc:
                new_type = 'building_any_level'
            else:
                new_type = 'building_level'
                # 提取殿阁名
                for building in ['灵田', '矿场', '丹殿', '器殿', '阵阁', '藏书阁', '药园']:
                    if building in condition_desc:
                        new_extra = building
                        break
            import re
            nums = re.findall(r'\d+', condition_desc)
            if nums:
                new_param = nums[0]
        # 所有殿阁满级
        elif '所有基础殿阁升至' in condition_desc:
            new_type = 'building_total_level'
            new_param = '50'  # 假设10个殿阁，每个5级
        # 声望
        elif '声望达到' in condition_desc or '正道盟声望' in condition_desc or \
             '散修盟声望' in condition_desc or '丹器师公会声望' in condition_desc:
            new_type = 'reputation'
            if '友善' in condition_desc:
                new_param = '1000'
            elif '尊敬' in condition_desc:
                new_param = '5000'
            elif '崇拜' in condition_desc:
                new_param = '20000'
        # 灵兽
        elif '灵兽' in condition_desc and ('只' in condition_desc or '种' in condition_desc):
            new_type = 'beast_count'
            import re
            nums = re.findall(r'\d+', condition_desc)
            if nums:
                new_param = nums[0]
        # 繁荣
        elif '繁荣' in condition_desc:
            new_type = 'prosperity'
            import re
            nums = re.findall(r'\d+', condition_desc)
            if nums:
                new_param = nums[0]
    
    # 战斗类成就 - 大部分需要新系统，暂时跳过
    # 探索类成就 - 大部分需要新系统，暂时跳过
    # 社交类成就 - 大部分需要新系统，暂时跳过
    
    if new_type and new_type in supported_types:
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
    print("成就系统完善 - 第一阶段")
    print("分析可以基于现有 condition_type 实现的 placeholder 成就")
    print("=" * 60)
    
    # 读取成就配置
    achievements = []
    with open(achievement_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            achievements.append(row)
    
    # 分析每个成就
    can_implement = []
    for ach in achievements:
        result = analyze_achievement(ach)
        if result:
            can_implement.append(result)
    
    print(f"\n📊 分析结果：")
    print(f"  成就总数：{len(achievements)}")
    print(f"  可以基于现有 condition_type 实现：{len(can_implement)} 个")
    
    print(f"\n📋 可以实现的成就列表：")
    for ach in can_implement:
        print(f"  [{ach['category']}] {ach['id']} - {ach['name']}")
        print(f"       原类型：{ach['old_type']} → 新类型：{ach['new_type']}")
        print(f"       参数：{ach['new_param']}，额外：{ach['new_extra']}")
        print(f"       描述：{ach['desc']}")
    
    # 修改配置表
    print(f"\n🔧 修改配置表...")
    modified_count = 0
    for ach in achievements:
        for impl in can_implement:
            if ach.get('achievement_id') == impl['id']:
                ach['condition_type'] = impl['new_type']
                ach['condition_param'] = impl['new_param']
                ach['condition_extra'] = impl['new_extra']
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
    print(f"\n📊 剩余 placeholder 成就：{remaining_placeholder} 个")
    print(f"  这些成就需要新增 condition_type 支持，将在第二阶段实现")
    
    print("\n🎉 第一阶段完成！")

if __name__ == "__main__":
    main()

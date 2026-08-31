# -*- coding: utf-8 -*-
"""
扩展日常/周常任务
增加更多任务类型和内容，丰富玩家每天的游戏体验
"""

import os
import csv

# 日常任务配置文件路径
daily_path = r"E:\Xiuxian\taixuanzongmenlu\config\quest_daily.csv"
# 周常任务配置文件路径
weekly_path = r"E:\Xiuxian\taixuanzongmenlu\config\quest_weekly.csv"

# ============ 新增日常任务 ============
# 字段：quest_id,quest_name,quest_type,unlock_sect_level,difficulty,target_desc,target_num,reward_lingjing,reward_lingqi,reward_pool_id,active_point,daily_limit,is_auto_complete,jump_path,condition_type,is_newbie,prev_quest_id,is_auto_trigger

new_daily_tasks = [
    # 炼器类任务（宗门等级2解锁）
    ["daily_017", "炼制凡品装备", "炼器", 2, "难度Ⅱ", "在器殿炼制1件凡品装备", 1, 100, 40, "pool_daily_2", 10, 1, "true", "", "forge_equipment", "false", "", "true"],
    ["daily_018", "装备强化", "炼器", 2, "难度Ⅱ", "强化任意1件装备1次", 1, 80, 50, "pool_daily_2", 10, 1, "true", "", "enhance_equipment", "false", "", "true"],
    ["daily_019", "装备分解", "炼器", 3, "难度Ⅲ", "分解任意3件装备", 3, 120, 30, "pool_daily_3", 10, 1, "true", "", "decompose_equipment", "false", "", "true"],
    
    # 功法类任务（宗门等级2解锁）
    ["daily_020", "学习新功法", "功法", 2, "难度Ⅱ", "学习任意1本新功法", 1, 150, 60, "pool_daily_2", 10, 1, "true", "", "learn_gongfa", "false", "", "true"],
    ["daily_021", "功法参悟", "功法", 3, "难度Ⅲ", "参悟任意1本功法1次", 1, 100, 80, "pool_daily_3", 10, 1, "true", "", "comprehend_gongfa", "false", "", "true"],
    ["daily_022", "功法升级", "功法", 3, "难度Ⅲ", "升级任意1本功法1级", 1, 200, 100, "pool_daily_3", 10, 1, "true", "", "upgrade_gongfa", "false", "", "true"],
    
    # 阵法类任务（宗门等级3解锁）
    ["daily_023", "布置阵法", "阵法", 3, "难度Ⅲ", "布置任意1个阵法", 1, 180, 70, "pool_daily_3", 10, 1, "true", "", "deploy_zhenfa", "false", "", "true"],
    ["daily_024", "阵法升级", "阵法", 4, "难度Ⅳ", "升级任意1个阵法1级", 1, 300, 150, "pool_daily_4", 10, 1, "true", "", "upgrade_zhenfa", "false", "", "true"],
    ["daily_025", "阵法修复", "阵法", 4, "难度Ⅳ", "修复任意1个受损阵法", 1, 250, 120, "pool_daily_4", 10, 1, "true", "", "repair_zhenfa", "false", "", "true"],
    
    # 灵兽类任务（宗门等级2解锁）
    ["daily_026", "灵兽喂养", "灵兽", 2, "难度Ⅱ", "喂养任意1只灵兽1次", 1, 60, 30, "pool_daily_2", 10, 1, "true", "", "feed_beast", "false", "", "true"],
    ["daily_027", "灵兽训练", "灵兽", 3, "难度Ⅲ", "训练任意1只灵兽1次", 1, 100, 50, "pool_daily_3", 10, 1, "true", "", "train_beast", "false", "", "true"],
    ["daily_028", "灵兽出战", "灵兽", 3, "难度Ⅲ", "派遣任意1只灵兽出战1次", 1, 120, 40, "pool_daily_3", 10, 1, "true", "", "beast_battle", "false", "", "true"],
    
    # 社交类任务（宗门等级2解锁）
    ["daily_029", "添加道友", "社交", 2, "难度Ⅱ", "添加1名新道友", 1, 80, 20, "pool_daily_2", 10, 1, "true", "", "add_friend", "false", "", "true"],
    ["daily_030", "赠送礼物", "社交", 3, "难度Ⅲ", "给道友赠送1次礼物", 1, 100, 30, "pool_daily_3", 10, 1, "true", "", "send_gift", "false", "", "true"],
    ["daily_031", "道友互动", "社交", 3, "难度Ⅲ", "与任意3名道友互动", 3, 70, 25, "pool_daily_3", 10, 1, "true", "", "friend_interact", "false", "", "true"],
    
    # 探索类任务（宗门等级2解锁）
    ["daily_032", "地图探索", "探索", 2, "难度Ⅱ", "探索任意1张新区域", 1, 150, 50, "pool_daily_2", 10, 1, "true", "", "explore_map", "false", "", "true"],
    ["daily_033", "资源采集", "探索", 2, "难度Ⅱ", "采集任意5份资源", 5, 80, 20, "pool_daily_2", 10, 1, "true", "", "collect_resource", "false", "", "true"],
    ["daily_034", "遗迹发现", "探索", 4, "难度Ⅳ", "发现任意1处上古遗迹", 1, 400, 150, "pool_daily_4", 10, 1, "true", "", "discover_ruins", "false", "", "true"],
    
    # 成就类任务（宗门等级3解锁）
    ["daily_035", "成就达成", "成就", 3, "难度Ⅲ", "达成任意1个新成就", 1, 200, 80, "pool_daily_3", 10, 1, "true", "", "achievement_unlock", "false", "", "true"],
    ["daily_036", "里程碑达成", "成就", 4, "难度Ⅳ", "达成任意1个宗门里程碑", 1, 350, 120, "pool_daily_4", 10, 1, "true", "", "milestone_unlock", "false", "", "true"],
]

# ============ 新增周常任务 ============
# 字段：quest_id,quest_name,quest_type,unlock_sect_level,difficulty,target_desc,target_num,reward_lingjing,reward_lingqi,reward_pool_id,reward_chest_id,weekly_active_point,weekly_limit,is_auto_complete

new_weekly_tasks = [
    # 炼器类周常（宗门等级3解锁）
    ["weekly_011", "炼器大师", "炼器", 3, "难度Ⅲ", "累计炼制10件凡品以上装备", 10, 600, 300, "pool_weekly_2", "chest_weekly", 5, 1, "true"],
    ["weekly_012", "神兵初成", "炼器", 4, "难度Ⅳ", "炼制出1件灵品装备", 1, 800, 400, "pool_weekly_3", "chest_weekly", 5, 1, "true"],
    ["weekly_013", "强化达人", "炼器", 3, "难度Ⅲ", "累计强化装备20次", 20, 550, 280, "pool_weekly_2", "chest_weekly", 5, 1, "true"],
    
    # 功法类周常（宗门等级3解锁）
    ["weekly_014", "功法收藏家", "功法", 3, "难度Ⅲ", "累计收集10本不同功法", 10, 700, 350, "pool_weekly_2", "chest_weekly", 5, 1, "true"],
    ["weekly_015", "功法大成", "功法", 4, "难度Ⅳ", "将任意1本功法升至满级", 1, 900, 450, "pool_weekly_3", "chest_weekly", 5, 1, "true"],
    ["weekly_016", "参悟玄机", "功法", 3, "难度Ⅲ", "累计参悟功法15次", 15, 650, 320, "pool_weekly_2", "chest_weekly", 5, 1, "true"],
    
    # 阵法类周常（宗门等级4解锁）
    ["weekly_017", "阵道宗师", "阵法", 4, "难度Ⅳ", "累计布置5个不同阵法", 5, 850, 400, "pool_weekly_3", "chest_weekly", 5, 1, "true"],
    ["weekly_018", "大阵圆满", "阵法", 4, "难度Ⅳ", "将任意1个阵法升至满级", 1, 1000, 500, "pool_weekly_3", "chest_weekly", 5, 1, "true"],
    
    # 灵兽类周常（宗门等级3解锁）
    ["weekly_019", "灵兽驯养师", "灵兽", 3, "难度Ⅲ", "累计培养5只不同灵兽", 5, 600, 300, "pool_weekly_2", "chest_weekly", 5, 1, "true"],
    ["weekly_020", "灵兽进化", "灵兽", 4, "难度Ⅳ", "完成1次灵兽进化", 1, 900, 450, "pool_weekly_3", "chest_weekly", 5, 1, "true"],
    
    # 社交类周常（宗门等级3解锁）
    ["weekly_021", "广结善缘", "社交", 3, "难度Ⅲ", "累计添加10名道友", 10, 500, 250, "pool_weekly_2", "chest_weekly", 5, 1, "true"],
    ["weekly_022", "情谊深厚", "社交", 4, "难度Ⅳ", "与任意5名道友达到挚友关系", 5, 750, 380, "pool_weekly_3", "chest_weekly", 5, 1, "true"],
    
    # 探索类周常（宗门等级3解锁）
    ["weekly_023", "探险家", "探索", 3, "难度Ⅲ", "累计探索5张不同地图", 5, 700, 350, "pool_weekly_2", "chest_weekly", 5, 1, "true"],
    ["weekly_024", "遗迹猎人", "探索", 4, "难度Ⅳ", "累计发现3处上古遗迹", 3, 950, 480, "pool_weekly_3", "chest_weekly", 5, 1, "true"],
]

def append_tasks_to_csv(file_path, new_tasks, task_type_name):
    """向CSV文件追加新任务"""
    # 读取现有任务ID
    existing_ids = set()
    if os.path.exists(file_path):
        with open(file_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.reader(f)
            header = next(reader, None)
            for row in reader:
                if row and len(row) > 0:
                    existing_ids.add(row[0].strip())
    
    # 过滤掉已存在的任务
    tasks_to_add = []
    for task in new_tasks:
        if task[0] not in existing_ids:
            tasks_to_add.append(task)
        else:
            print(f"  ⚠️  {task_type_name} 任务 {task[0]} ({task[1]}) 已存在，跳过")
    
    if not tasks_to_add:
        print(f"  ℹ️  {task_type_name} 没有新任务需要添加")
        return 0
    
    # 追加新任务
    with open(file_path, 'a', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        for task in tasks_to_add:
            writer.writerow(task)
    
    print(f"  ✅ 已添加 {len(tasks_to_add)} 个{task_type_name}任务")
    return len(tasks_to_add)

def main():
    print("=" * 60)
    print("扩展日常/周常任务")
    print("=" * 60)
    
    # 添加日常任务
    print("\n📋 添加日常任务...")
    daily_added = append_tasks_to_csv(daily_path, new_daily_tasks, "日常")
    
    # 添加周常任务
    print("\n📋 添加周常任务...")
    weekly_added = append_tasks_to_csv(weekly_path, new_weekly_tasks, "周常")
    
    # 统计
    print("\n" + "=" * 60)
    print("📊 扩展完成统计")
    print("=" * 60)
    print(f"  日常任务新增：{daily_added} 个")
    print(f"  周常任务新增：{weekly_added} 个")
    print(f"  总计新增：{daily_added + weekly_added} 个任务")
    
    # 统计现有任务数量
    daily_count = 0
    weekly_count = 0
    if os.path.exists(daily_path):
        with open(daily_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.reader(f)
            next(reader, None)
            daily_count = sum(1 for row in reader if row and row[0].strip())
    if os.path.exists(weekly_path):
        with open(weekly_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.reader(f)
            next(reader, None)
            weekly_count = sum(1 for row in reader if row and row[0].strip())
    
    print(f"\n  当前日常任务总数：{daily_count} 个")
    print(f"  当前周常任务总数：{weekly_count} 个")
    
    # 新增任务类型统计
    daily_types = set(task[2] for task in new_daily_tasks)
    weekly_types = set(task[2] for task in new_weekly_tasks)
    
    print(f"\n  新增日常任务类型：{', '.join(sorted(daily_types))}")
    print(f"  新增周常任务类型：{', '.join(sorted(weekly_types))}")
    
    print("\n🎉 日常/周常任务扩展完成！")

if __name__ == "__main__":
    main()

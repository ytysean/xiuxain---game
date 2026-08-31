# -*- coding: utf-8 -*-
"""
任务奖励平衡分析
1. 分析日常任务、周常任务、主线任务的奖励数值
2. 分析经济系统的产出和消耗
3. 找出不平衡的地方
"""

import os
import csv

config_dir = r"E:\Xiuxian\taixuanzongmenlu\config"

def read_csv(file_path):
    """读取CSV文件"""
    if not os.path.exists(file_path):
        return []
    with open(file_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        return list(reader)

def main():
    print("=" * 60)
    print("任务奖励平衡分析")
    print("=" * 60)

    # ============ 1. 日常任务奖励分析 ============
    print("\n📋 1. 日常任务奖励分析")
    print("-" * 60)
    
    daily_tasks = read_csv(os.path.join(config_dir, "quest_daily.csv"))
    daily_lingjing_total = 0
    daily_lingqi_total = 0
    daily_by_difficulty = {}
    
    for task in daily_tasks:
        if task.get('is_newbie', '') == 'true':
            continue  # 跳过新手任务
        lingjing = int(task.get('reward_lingjing', 0))
        lingqi = int(task.get('reward_lingqi', 0))
        difficulty = task.get('difficulty', '未知')
        unlock_level = task.get('unlock_sect_level', '1')
        
        daily_lingjing_total += lingjing
        daily_lingqi_total += lingqi
        
        if difficulty not in daily_by_difficulty:
            daily_by_difficulty[difficulty] = {'count': 0, 'lingjing': 0, 'lingqi': 0}
        daily_by_difficulty[difficulty]['count'] += 1
        daily_by_difficulty[difficulty]['lingjing'] += lingjing
        daily_by_difficulty[difficulty]['lingqi'] += lingqi
    
    print(f"  日常任务总数（不含新手）：{len([t for t in daily_tasks if t.get('is_newbie') != 'true'])} 个")
    print(f"  每日随机抽取：3 个")
    print(f"  所有日常任务灵石总和：{daily_lingjing_total}")
    print(f"  所有日常任务灵气总和：{daily_lingqi_total}")
    print(f"  平均每日灵石奖励（3个随机）：约 {daily_lingjing_total // max(1, len([t for t in daily_tasks if t.get('is_newbie') != 'true'])) * 3}")
    print(f"  平均每日灵气奖励（3个随机）：约 {daily_lingqi_total // max(1, len([t for t in daily_tasks if t.get('is_newbie') != 'true'])) * 3}")
    
    print(f"\n  按难度统计：")
    for diff, data in sorted(daily_by_difficulty.items()):
        avg_lj = data['lingjing'] // max(1, data['count'])
        avg_lq = data['lingqi'] // max(1, data['count'])
        print(f"    {diff}：{data['count']}个，平均灵石{avg_lj}，平均灵气{avg_lq}")

    # ============ 2. 周常任务奖励分析 ============
    print("\n📋 2. 周常任务奖励分析")
    print("-" * 60)
    
    weekly_tasks = read_csv(os.path.join(config_dir, "quest_weekly.csv"))
    weekly_lingjing_total = 0
    weekly_lingqi_total = 0
    
    for task in weekly_tasks:
        lingjing = int(task.get('reward_lingjing', 0))
        lingqi = int(task.get('reward_lingqi', 0))
        weekly_lingjing_total += lingjing
        weekly_lingqi_total += lingqi
    
    print(f"  周常任务总数：{len(weekly_tasks)} 个")
    print(f"  每周随机抽取：1 个")
    print(f"  所有周常任务灵石总和：{weekly_lingjing_total}")
    print(f"  所有周常任务灵气总和：{weekly_lingqi_total}")
    print(f"  平均每周灵石奖励：约 {weekly_lingjing_total // max(1, len(weekly_tasks))}")
    print(f"  平均每周灵气奖励：约 {weekly_lingqi_total // max(1, len(weekly_tasks))}")

    # ============ 3. 主线任务奖励分析 ============
    print("\n📋 3. 主线任务奖励分析")
    print("-" * 60)
    
    main_tasks = read_csv(os.path.join(config_dir, "quest_main.csv"))
    main_lingjing_total = 0
    main_lingqi_total = 0
    main_shengwang_total = 0
    
    for task in main_tasks:
        lingjing = int(task.get('reward_lingjing', 0))
        lingqi = int(task.get('reward_lingqi', 0))
        shengwang = int(task.get('reward_shengwang', 0))
        main_lingjing_total += lingjing
        main_lingqi_total += lingqi
        main_shengwang_total += shengwang
    
    print(f"  主线任务总数：{len(main_tasks)} 个")
    print(f"  所有主线任务灵石总和：{main_lingjing_total}")
    print(f"  所有主线任务灵气总和：{main_lingqi_total}")
    print(f"  所有主线任务声望总和：{main_shengwang_total}")

    # ============ 4. 经济系统产出分析 ============
    print("\n📋 4. 经济系统月度产出估算")
    print("-" * 60)
    
    # 假设每月30天
    days_per_month = 30
    
    # 日常任务产出
    daily_avg_lj = daily_lingjing_total // max(1, len([t for t in daily_tasks if t.get('is_newbie') != 'true'])) * 3
    daily_avg_lq = daily_lingqi_total // max(1, len([t for t in daily_tasks if t.get('is_newbie') != 'true'])) * 3
    monthly_daily_lj = daily_avg_lj * days_per_month
    monthly_daily_lq = daily_avg_lq * days_per_month
    
    # 周常任务产出
    weekly_avg_lj = weekly_lingjing_total // max(1, len(weekly_tasks))
    weekly_avg_lq = weekly_lingqi_total // max(1, len(weekly_tasks))
    monthly_weekly_lj = weekly_avg_lj * 4  # 每月4周
    monthly_weekly_lq = weekly_avg_lq * 4
    
    # 总产出
    monthly_total_lj = monthly_daily_lj + monthly_weekly_lj
    monthly_total_lq = monthly_daily_lq + monthly_weekly_lq
    
    print(f"  假设每月 {days_per_month} 天")
    print(f"\n  日常任务月度产出：")
    print(f"    灵石：约 {monthly_daily_lj:,}")
    print(f"    灵气：约 {monthly_daily_lq:,}")
    print(f"\n  周常任务月度产出（每月4周）：")
    print(f"    灵石：约 {monthly_weekly_lj:,}")
    print(f"    灵气：约 {monthly_weekly_lq:,}")
    print(f"\n  任务系统月度总产出：")
    print(f"    灵石：约 {monthly_total_lj:,}")
    print(f"    灵气：约 {monthly_total_lq:,}")

    # ============ 5. 奖励平衡分析 ============
    print("\n📋 5. 奖励平衡分析")
    print("-" * 60)
    
    # 分析日常任务不同难度的奖励比例
    print("  日常任务难度奖励比例分析：")
    diffs = sorted(daily_by_difficulty.keys())
    if len(diffs) >= 2:
        base_diff = diffs[0]
        base_lj = daily_by_difficulty[base_diff]['lingjing'] // max(1, daily_by_difficulty[base_diff]['count'])
        for diff in diffs:
            avg_lj = daily_by_difficulty[diff]['lingjing'] // max(1, daily_by_difficulty[diff]['count'])
            ratio = avg_lj / max(1, base_lj)
            print(f"    {diff}：平均灵石{avg_lj}，是{base_diff}的{ratio:.1f}倍")
    
    # 分析日常和周常的奖励比例
    print(f"\n  日常与周常奖励比例：")
    print(f"    单个日常平均灵石：{daily_avg_lj // 3}")
    print(f"    单个周常平均灵石：{weekly_avg_lj}")
    print(f"    周常/日常比例：{weekly_avg_lj / max(1, daily_avg_lj // 3):.1f}倍")
    print(f"    （合理范围：周常应该是日常的5-10倍）")

    print("\n🎉 分析完成！")

if __name__ == "__main__":
    main()

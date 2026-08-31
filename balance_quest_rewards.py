# -*- coding: utf-8 -*-
"""
任务奖励平衡调整
1. 调整日常任务不同难度的奖励比例
2. 提高周常任务奖励，使其达到日常的5-10倍
3. 确保经济系统稳定
"""

import os
import csv

config_dir = r"E:\Xiuxian\taixuanzongmenlu\config"

def read_csv(file_path):
    """读取CSV文件"""
    if not os.path.exists(file_path):
        return [], []
    with open(file_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        return list(reader), reader.fieldnames

def write_csv(file_path, data, fieldnames):
    """写入CSV文件"""
    with open(file_path, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)

def main():
    print("=" * 60)
    print("任务奖励平衡调整")
    print("=" * 60)

    # ============ 1. 调整日常任务奖励 ============
    print("\n📋 1. 调整日常任务奖励")
    print("-" * 60)
    
    daily_tasks, daily_fields = read_csv(os.path.join(config_dir, "quest_daily.csv"))
    
    # 目标奖励比例（相对于难度Ⅰ）
    # 难度Ⅰ：1.0倍
    # 难度Ⅱ：2.0倍
    # 难度Ⅲ：3.5倍
    # 难度Ⅳ：6.0倍（从11.9倍降低）
    
    target_ratios = {
        "难度Ⅰ": 1.0,
        "难度Ⅱ": 2.0,
        "难度Ⅲ": 3.5,
        "难度Ⅳ": 6.0,
    }
    
    # 基准奖励（难度Ⅰ）
    base_lingjing = 50
    base_lingqi = 20
    
    daily_adjusted = 0
    for task in daily_tasks:
        if task.get('is_newbie', '') == 'true':
            continue  # 跳过新手任务
        
        difficulty = task.get('difficulty', '难度Ⅰ')
        ratio = target_ratios.get(difficulty, 1.0)
        
        target_lj = int(base_lingjing * ratio)
        target_lq = int(base_lingqi * ratio)
        
        current_lj = int(task.get('reward_lingjing', 0))
        current_lq = int(task.get('reward_lingqi', 0))
        
        if current_lj != target_lj or current_lq != target_lq:
            print(f"  调整 {task['quest_id']} - {task['quest_name']} ({difficulty}):")
            print(f"    灵石：{current_lj} → {target_lj}")
            print(f"    灵气：{current_lq} → {target_lq}")
            task['reward_lingjing'] = str(target_lj)
            task['reward_lingqi'] = str(target_lq)
            daily_adjusted += 1
    
    write_csv(os.path.join(config_dir, "quest_daily.csv"), daily_tasks, daily_fields)
    print(f"\n  ✅ 已调整 {daily_adjusted} 个日常任务的奖励")

    # ============ 2. 调整周常任务奖励 ============
    print("\n📋 2. 调整周常任务奖励")
    print("-" * 60)
    
    weekly_tasks, weekly_fields = read_csv(os.path.join(config_dir, "quest_weekly.csv"))
    
    # 周常任务应该是日常的5-10倍
    # 单个日常平均灵石：约220（调整后）
    # 周常目标：日常的7倍左右 = 约1500灵石
    
    weekly_base_lj = 1500
    weekly_base_lq = 600
    
    # 周常任务难度比例
    weekly_ratios = {
        "难度Ⅰ": 0.8,
        "难度Ⅱ": 1.0,
        "难度Ⅲ": 1.3,
        "难度Ⅳ": 1.8,
    }
    
    weekly_adjusted = 0
    for task in weekly_tasks:
        difficulty = task.get('difficulty', '难度Ⅱ')
        ratio = weekly_ratios.get(difficulty, 1.0)
        
        target_lj = int(weekly_base_lj * ratio)
        target_lq = int(weekly_base_lq * ratio)
        
        current_lj = int(task.get('reward_lingjing', 0))
        current_lq = int(task.get('reward_lingqi', 0))
        
        if current_lj != target_lj or current_lq != target_lq:
            print(f"  调整 {task['quest_id']} - {task['quest_name']} ({difficulty}):")
            print(f"    灵石：{current_lj} → {target_lj}")
            print(f"    灵气：{current_lq} → {target_lq}")
            task['reward_lingjing'] = str(target_lj)
            task['reward_lingqi'] = str(target_lq)
            weekly_adjusted += 1
    
    write_csv(os.path.join(config_dir, "quest_weekly.csv"), weekly_tasks, weekly_fields)
    print(f"\n  ✅ 已调整 {weekly_adjusted} 个周常任务的奖励")

    # ============ 3. 调整后验证 ============
    print("\n📋 3. 调整后验证")
    print("-" * 60)
    
    # 重新计算日常任务平均奖励
    daily_lj_total = 0
    daily_lq_total = 0
    daily_count = 0
    for task in daily_tasks:
        if task.get('is_newbie', '') == 'true':
            continue
        daily_lj_total += int(task.get('reward_lingjing', 0))
        daily_lq_total += int(task.get('reward_lingqi', 0))
        daily_count += 1
    
    daily_avg_lj = daily_lj_total // max(1, daily_count)
    daily_avg_lq = daily_lq_total // max(1, daily_count)
    
    # 重新计算周常任务平均奖励
    weekly_lj_total = 0
    weekly_lq_total = 0
    weekly_count = 0
    for task in weekly_tasks:
        weekly_lj_total += int(task.get('reward_lingjing', 0))
        weekly_lq_total += int(task.get('reward_lingqi', 0))
        weekly_count += 1
    
    weekly_avg_lj = weekly_lj_total // max(1, weekly_count)
    weekly_avg_lq = weekly_lq_total // max(1, weekly_count)
    
    print(f"  调整后日常任务平均奖励：")
    print(f"    单个日常平均灵石：{daily_avg_lj}")
    print(f"    单个日常平均灵气：{daily_avg_lq}")
    print(f"    每日3个随机任务灵石：约 {daily_avg_lj * 3}")
    print(f"    每日3个随机任务灵气：约 {daily_avg_lq * 3}")
    
    print(f"\n  调整后周常任务平均奖励：")
    print(f"    单个周常平均灵石：{weekly_avg_lj}")
    print(f"    单个周常平均灵气：{weekly_avg_lq}")
    
    print(f"\n  周常/日常比例：")
    print(f"    灵石比例：{weekly_avg_lj / max(1, daily_avg_lj):.1f}倍")
    print(f"    灵气比例：{weekly_avg_lq / max(1, daily_avg_lq):.1f}倍")
    print(f"    （目标范围：5-10倍）")
    
    # 月度产出估算
    days_per_month = 30
    monthly_daily_lj = daily_avg_lj * 3 * days_per_month
    monthly_weekly_lj = weekly_avg_lj * 4
    monthly_total_lj = monthly_daily_lj + monthly_weekly_lj
    
    print(f"\n  调整后月度产出估算：")
    print(f"    日常任务月度灵石：约 {monthly_daily_lj:,}")
    print(f"    周常任务月度灵石：约 {monthly_weekly_lj:,}")
    print(f"    任务系统月度总灵石：约 {monthly_total_lj:,}")

    print("\n🎉 任务奖励平衡调整完成！")

if __name__ == "__main__":
    main()

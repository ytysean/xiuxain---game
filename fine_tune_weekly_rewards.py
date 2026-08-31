# -*- coding: utf-8 -*-
"""
任务奖励平衡微调
微调周常任务奖励，使其降到约8倍左右
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
    print("任务奖励平衡微调")
    print("=" * 60)

    # 调整周常任务奖励
    weekly_tasks, weekly_fields = read_csv(os.path.join(config_dir, "quest_weekly.csv"))
    
    # 目标：周常是日常的8倍左右
    # 单个日常平均灵石：165
    # 目标周常平均灵石：165 * 8 = 1320
    
    weekly_base_lj = 1200
    weekly_base_lq = 480
    
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
            print(f"  微调 {task['quest_id']} - {task['quest_name']} ({difficulty}):")
            print(f"    灵石：{current_lj} → {target_lj}")
            print(f"    灵气：{current_lq} → {target_lq}")
            task['reward_lingjing'] = str(target_lj)
            task['reward_lingqi'] = str(target_lq)
            weekly_adjusted += 1
    
    write_csv(os.path.join(config_dir, "quest_weekly.csv"), weekly_tasks, weekly_fields)
    print(f"\n  ✅ 已微调 {weekly_adjusted} 个周常任务的奖励")

    # 验证
    print("\n📋 调整后验证")
    print("-" * 60)
    
    # 日常任务平均奖励
    daily_tasks, _ = read_csv(os.path.join(config_dir, "quest_daily.csv"))
    daily_lj_total = 0
    daily_count = 0
    for task in daily_tasks:
        if task.get('is_newbie', '') == 'true':
            continue
        daily_lj_total += int(task.get('reward_lingjing', 0))
        daily_count += 1
    daily_avg_lj = daily_lj_total // max(1, daily_count)
    
    # 周常任务平均奖励
    weekly_lj_total = 0
    weekly_count = 0
    for task in weekly_tasks:
        weekly_lj_total += int(task.get('reward_lingjing', 0))
        weekly_count += 1
    weekly_avg_lj = weekly_lj_total // max(1, weekly_count)
    
    print(f"  单个日常平均灵石：{daily_avg_lj}")
    print(f"  单个周常平均灵石：{weekly_avg_lj}")
    print(f"  周常/日常比例：{weekly_avg_lj / max(1, daily_avg_lj):.1f}倍")
    print(f"  （目标范围：5-10倍）")
    
    # 月度产出估算
    days_per_month = 30
    monthly_daily_lj = daily_avg_lj * 3 * days_per_month
    monthly_weekly_lj = weekly_avg_lj * 4
    monthly_total_lj = monthly_daily_lj + monthly_weekly_lj
    
    print(f"\n  月度产出估算：")
    print(f"    日常任务月度灵石：约 {monthly_daily_lj:,}")
    print(f"    周常任务月度灵石：约 {monthly_weekly_lj:,}")
    print(f"    任务系统月度总灵石：约 {monthly_total_lj:,}")

    print("\n🎉 任务奖励平衡微调完成！")

if __name__ == "__main__":
    main()

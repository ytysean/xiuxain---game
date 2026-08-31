# -*- coding: utf-8 -*-
"""
成就系统完善 - 第二阶段
在 game_state.gd 的 _复检成就 函数中添加新的 condition_type
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 要查找的旧字符串（包含足够的上下文确保唯一）
old_string = '''			"prosperity":

				达成 = 繁荣 >= p
			_:

				达成 = false   # 未知 condition_type 视为不达成，安全容错'''

# 新字符串（添加新的 condition_type）
new_string = '''			"prosperity":

				达成 = 繁荣 >= p
			# ===== S1 新增 condition_type（2026-08-30 成就系统完善第二阶段）=====
			"zhenfa_count":
				# 已解锁阵法数量
				var 已解锁阵法: Dictionary = 宗门大阵.get("已解锁", {})
				达成 = 已解锁阵法.size() >= p
			"zhenfa_level":
				# 特定阵法等级（extra=阵法ID）
				var 阵法等级表: Dictionary = 宗门大阵.get("等级", {})
				var 某阵法等级: int = int(阵法等级表.get(extra, 0))
				达成 = 某阵法等级 >= p
			"daily_checkin_streak":
				# 连续领取日供天数
				达成 = 连续理事天数 >= p
			"daily_checkin_total":
				# 累计领取日供次数
				达成 = 日供_总领取次数 >= p
			"achievement_count":
				# 已达成成就数量
				达成 = 成就_已达成.size() >= p
			"game_days":
				# 累计游戏天数
				达成 = 累计游戏日 >= p
			_:

				达成 = false   # 未知 condition_type 视为不达成，安全容错'''

if old_string in content:
    content = content.replace(old_string, new_string)
    print("✅ 成功添加新的 condition_type")
else:
    print("❌ 未找到目标字符串")
    # 尝试查找部分匹配
    if '"prosperity"' in content:
        print("ℹ️  找到 'prosperity'，但完整字符串不匹配")
    if '未知 condition_type 视为不达成' in content:
        print("ℹ️  找到 '未知 condition_type 视为不达成'")

# 写回文件
if content != original_content:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ game_state.gd 已保存")
else:
    print("❌ game_state.gd 无修改")

print("\n🎉 第二阶段代码修改完成！")

# -*- coding: utf-8 -*-
"""
修复game_state.gd中的重复键问题：
删除重复的邮件列表保存代码
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 删除重复的邮件列表保存代码
old_code = """		# 历练派遣系统（不升SAVE_VERSION，旧档缺键→默认零回归）
		"历练系统": ExpeditionSystem.to_dict() if ExpeditionSystem != null else {},
		# 灵讯（邮件）系统（不升SAVE_VERSION，旧档缺键→默认空数组）
		"邮件列表": 邮件列表,
	}"""

new_code = """		# 历练派遣系统（不升SAVE_VERSION，旧档缺键→默认零回归）
		"历练系统": ExpeditionSystem.to_dict() if ExpeditionSystem != null else {},
	}"""

if old_code in content:
    content = content.replace(old_code, new_code)
    print("✅ 重复的邮件列表保存代码已删除")
else:
    print("❌ 未找到重复的代码")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

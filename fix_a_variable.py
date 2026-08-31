# -*- coding: utf-8 -*-
"""
修复game_state.gd中a变量错误
将所有的 in a else 改为 in data else
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 统计修改数量
count = content.count(' in a else')

# 将所有的 in a else 改为 in data else
content = content.replace(' in a else', ' in data else')

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"✅ 总共修复了 {count} 个a变量错误")

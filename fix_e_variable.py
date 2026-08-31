# -*- coding: utf-8 -*-
"""
修复game_state.gd中e变量错误
将所有的 in e else 改为 in stage else
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 统计修改数量
count = content.count(' in e else')

# 将所有的 in e else 改为 in stage else
content = content.replace(' in e else', ' in stage else')

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"✅ 总共修复了 {count} 个e变量错误")

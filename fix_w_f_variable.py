# -*- coding: utf-8 -*-
"""
修复game_state.gd中w和f变量错误
- 将所有的 in w else 改为 in row else
- 将所有的 in f else 改为 in buff else
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 统计修改数量
count_w = content.count(' in w else')
count_f = content.count(' in f else')

# 将所有的 in w else 改为 in row else
content = content.replace(' in w else', ' in row else')

# 将所有的 in f else 改为 in buff else
content = content.replace(' in f else', ' in buff else')

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"✅ 总共修复了 {count_w} 个w变量错误")
print(f"✅ 总共修复了 {count_f} 个f变量错误")

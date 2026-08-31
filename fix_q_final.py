# -*- coding: utf-8 -*-
"""
修复game_state.gd中第7269-7290行的q变量错误
将in q else改为in cfg else
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 统计修改数量
count = 0

# 修复第7269-7290行的q变量错误（索引从0开始，所以是7268-7289）
for i in range(7268, 7290):
    if i < len(lines):
        if ' in q else' in lines[i]:
            lines[i] = lines[i].replace(' in q else', ' in cfg else')
            count += 1
            print(f"第{i+1}行: q -> cfg")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\n✅ 总共修复了 {count} 个q变量错误")

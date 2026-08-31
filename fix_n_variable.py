# -*- coding: utf-8 -*-
"""
修复game_state.gd中n变量错误
- 第12255-12257行：将n改为djson
- 第12259-12261行：将n改为wjson
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 统计修改数量
count = 0

# 修复第12255-12257行的n变量（改为djson）
for i in [12254, 12255, 12256]:  # 索引从0开始
    if i < len(lines):
        old_line = lines[i]
        lines[i] = lines[i].replace(' in n else', ' in djson else')
        if old_line != lines[i]:
            count += 1
            print(f"已修复第{i+1}行的n变量（改为djson）")

# 修复第12259-12261行的n变量（改为wjson）
for i in [12258, 12259, 12260]:  # 索引从0开始
    if i < len(lines):
        old_line = lines[i]
        lines[i] = lines[i].replace(' in n else', ' in wjson else')
        if old_line != lines[i]:
            count += 1
            print(f"已修复第{i+1}行的n变量（改为wjson）")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\n✅ 总共修复了 {count} 个n变量错误")

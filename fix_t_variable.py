# -*- coding: utf-8 -*-
"""
修复game_state.gd中t变量错误
- 第3513、3517、3539、4232-4234行：将t改为it
- 第8748-8797行：将t改为evt
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 统计修改数量
count = 0

# 修复第3513、3517、3539、4232-4234行的t变量（改为it）
for i in [3512, 3516, 3538, 4231, 4232, 4233]:  # 索引从0开始
    if i < len(lines):
        old_line = lines[i]
        lines[i] = lines[i].replace(' in t else', ' in it else')
        if old_line != lines[i]:
            count += 1
            print(f"已修复第{i+1}行的t变量（改为it）")

# 修复第8748-8797行的t变量（改为evt）
for i in range(8747, 8797):  # 索引从0开始
    if i < len(lines):
        old_line = lines[i]
        lines[i] = lines[i].replace(' in t else', ' in evt else')
        if old_line != lines[i]:
            count += 1
            print(f"已修复第{i+1}行的t变量（改为evt）")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\n✅ 总共修复了 {count} 个t变量错误")

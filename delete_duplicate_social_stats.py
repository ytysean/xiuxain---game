# -*- coding: utf-8 -*-
"""
删除game_state.gd中第二个重复的获取社交统计函数定义（第4006-4022行）
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第4004-4025行的内容
print("=== 删除前（第4004-4025行）===")
for i in range(4003, 4025):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

# 删除第4006-4022行（索引4005-4021）
# 第4006行是 func 获取社交统计() -> Dictionary:
# 第4022行是空行
del lines[4005:4022]

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n=== 删除后（第4004-4015行）===")
for i in range(4003, 4015):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

print("\n✅ 第二个重复的获取社交统计函数定义已删除！")

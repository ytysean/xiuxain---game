# -*- coding: utf-8 -*-
"""
删除game_state.gd中第4117行重复的结义道友列表变量定义
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第4115-4120行的内容
print("=== 删除前（第4115-4120行）===")
for i in range(4114, 4120):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

# 删除第4117行（索引4116）
del lines[4116]

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n=== 删除后（第4115-4120行）===")
for i in range(4114, 4120):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

print("\n✅ 第4117行重复的结义道友列表变量定义已删除！")

# -*- coding: utf-8 -*-
"""
修复game_state.gd第7900-7902行的缩进问题
将第7900-7902行的缩进从3个tab改为2个tab
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第7895-7910行的内容
print("=== 修复前（第7895-7910行）===")
for i in range(7894, 7910):
    if i < len(lines):
        line = lines[i]
        indent = len(line) - len(line.lstrip())
        print(f"{i+1} (缩进{indent}): {line.rstrip()}")

# 修复第7900-7902行（索引7899-7901）的缩进
# 将3个tab改为2个tab
for i in range(7899, 7902):
    if i < len(lines) and lines[i].startswith("\t\t\t"):
        lines[i] = lines[i][1:]  # 去掉一个tab
        print(f"\n已修复第{i+1}行的缩进")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n=== 修复后（第7895-7910行）===")
for i in range(7894, 7910):
    if i < len(lines):
        line = lines[i]
        indent = len(line) - len(line.lstrip())
        print(f"{i+1} (缩进{indent}): {line.rstrip()}")

print("\n✅ 第7900-7902行的缩进问题已修复！")

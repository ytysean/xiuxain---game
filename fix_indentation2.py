# -*- coding: utf-8 -*-
"""
修复game_state.gd第4381行的缩进问题
将第4381行的缩进从1个tab改为2个tab
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第4378-4388行的内容
print("=== 修复前（第4378-4388行）===")
for i in range(4377, 4388):
    if i < len(lines):
        line = lines[i]
        indent = len(line) - len(line.lstrip())
        print(f"{i+1} (缩进{indent}): {line.rstrip()}")

# 修复第4381行（索引4380）的缩进
# 将1个tab改为2个tab
if lines[4380].startswith("\t"):
    lines[4380] = "\t" + lines[4380]
    print(f"\n已修复第4381行的缩进")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n=== 修复后（第4378-4388行）===")
for i in range(4377, 4388):
    if i < len(lines):
        line = lines[i]
        indent = len(line) - len(line.lstrip())
        print(f"{i+1} (缩进{indent}): {line.rstrip()}")

print("\n✅ 第4381行的缩进问题已修复！")

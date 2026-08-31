# -*- coding: utf-8 -*-
"""
修复game_state.gd第4341行的缩进问题
将第4341行的缩进从1个tab改为2个tab
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第4338-4348行的内容
print("=== 修复前（第4338-4348行）===")
for i in range(4337, 4348):
    if i < len(lines):
        # 显示缩进
        line = lines[i]
        indent = len(line) - len(line.lstrip())
        print(f"{i+1} (缩进{indent}): {line.rstrip()}")

# 修复第4341行（索引4340）的缩进
# 将1个tab改为2个tab
if lines[4340].startswith("\t"):
    lines[4340] = "\t" + lines[4340]
    print(f"\n已修复第4341行的缩进")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n=== 修复后（第4338-4348行）===")
for i in range(4337, 4348):
    if i < len(lines):
        line = lines[i]
        indent = len(line) - len(line.lstrip())
        print(f"{i+1} (缩进{indent}): {line.rstrip()}")

print("\n✅ 第4341行的缩进问题已修复！")

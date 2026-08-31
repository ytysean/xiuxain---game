# -*- coding: utf-8 -*-
"""
删除game_state.gd中重复的选择探索事件分支函数定义（第1105-1182行）
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 第1105行是注释（索引1104），第1182行是函数结束（索引1181）
# 删除第1105行到第1183行（包含空行）
start_index = 1104  # 第1105行
end_index = 1183    # 第1184行（不包含）

print(f"要删除的行数：{end_index - start_index}")
print(f"开始行：{start_index + 1}")
print(f"结束行：{end_index}")

# 显示要删除的内容的前几行和后几行
print("\n=== 要删除的内容（前5行）===")
for i in range(start_index, min(start_index + 5, end_index)):
    print(f"{i+1}: {lines[i].rstrip()}")

print("\n=== 要删除的内容（后5行）===")
for i in range(max(start_index, end_index - 5), end_index):
    print(f"{i+1}: {lines[i].rstrip()}")

# 删除重复的函数定义
del lines[start_index:end_index]

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n✅ 重复的选择探索事件分支函数定义已删除！")

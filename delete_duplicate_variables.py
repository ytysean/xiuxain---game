# -*- coding: utf-8 -*-
"""
删除game_state.gd中重复的变量定义
删除第4036、4075、4119行的重复变量定义
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 需要删除的行号（重复变量定义）
# 第4036行：var 道友拜访冷却: Dictionary = {}
# 第4075行：var 道友切磋冷却: Dictionary = {}
# 第4119行：var 结义道友列表: Array = []

# 由于行号可能会因为前面的删除而变化，我们使用内容匹配来删除
lines_to_delete = []

for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped == "var 道友拜访冷却: Dictionary = {}  # 道友名字 -> 冷却结束日":
        # 检查是否是第二个定义（在第4000行之后）
        if i > 4000:
            lines_to_delete.append(i)
            print(f"第{i+1}行：找到重复的道友拜访冷却定义")
    elif stripped == "var 道友切磋冷却: Dictionary = {}  # 道友名字 -> 冷却结束日":
        if i > 4000:
            lines_to_delete.append(i)
            print(f"第{i+1}行：找到重复的道友切磋冷却定义")
    elif stripped == "var 结义道友列表: Array = []":
        if i > 4000:
            lines_to_delete.append(i)
            print(f"第{i+1}行：找到重复的结义道友列表定义")

# 从后往前删除，避免行号变化
for i in sorted(lines_to_delete, reverse=True):
    del lines[i]
    print(f"已删除第{i+1}行的重复变量定义")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\n✅ 总共删除了 {len(lines_to_delete)} 个重复变量定义")

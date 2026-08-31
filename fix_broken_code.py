# -*- coding: utf-8 -*-
"""
修复game_state.gd第2492-2499行被破坏的代码
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第2485-2505行的内容
print("=== 修复前（第2485-2505行）===")
for i in range(2484, 2505):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

# 修复第2490-2499行（索引2489-2498）
# 正确的代码应该是：
# elif 字段 == "灵草":
#     灵草 += 数量
#     累计灵田产出 += 数量
#     _复检成就()
# elif 字段 == "矿石":
#     矿石 += 数量
#     累计矿场产出 += 数量
#     _复检成就()

# 替换第2490-2499行（索引2489-2498）
new_lines = [
    '\t\telif 字段 == "灵草":\n',
    '\n',
    '\t\t\t灵草 += 数量\n',
    '\t\t\t累计灵田产出 += 数量\n',
    '\t\t\t_复检成就()\n',
    '\t\telif 字段 == "矿石":\n',
    '\n',
    '\t\t\t矿石 += 数量\n',
    '\t\t\t累计矿场产出 += 数量\n',
    '\t\t\t_复检成就()\n',
]

# 替换第2490-2499行（索引2489-2498）
lines[2489:2499] = new_lines

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n=== 修复后（第2485-2510行）===")
for i in range(2484, 2510):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

print("\n✅ game_state.gd第2492-2499行被破坏的代码已修复！")

# -*- coding: utf-8 -*-
"""
修复game_state.gd第8230行的语法错误
将 "门派等级 = " 改为 "门派等级 = 门派等级目标"
并删除第8231行注释后面的 "门派等级目标"
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第8228-8235行的内容
print("=== 修复前（第8228-8235行）===")
for i in range(8227, 8235):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

# 修复第8230行（索引8229）
# 将 "门派等级 = " 改为 "门派等级 = 门派等级目标"
lines[8229] = lines[8229].replace("门派等级 = ", "门派等级 = 门派等级目标")

# 修复第8231行（索引8230）
# 删除注释后面的 "门派等级目标"
lines[8230] = lines[8230].replace("# 成就检测：宗门等级相关成就门派等级目标", "# 成就检测：宗门等级相关成就")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n=== 修复后（第8228-8235行）===")
for i in range(8227, 8235):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

print("\n✅ 第8230行的语法错误已修复！")

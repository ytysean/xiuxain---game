# -*- coding: utf-8 -*-
"""
修复game_state.gd中第598、600、605、607、616行的m变量错误
将m改为item
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第596-618行的内容
print("=== 修复前（第596-618行）===")
for i in range(595, 618):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

# 修复第598、600、605、607、616行的m变量
# 将 "faction" in m 改为 "faction" in item
# 将 "unlock_reputation" in m 改为 "unlock_reputation" in item
# 将 "price" in m 改为 "price" in item
# 将 "item_id" in m 改为 "item_id" in item
for i in [597, 599, 604, 606, 615]:  # 索引从0开始
    if i < len(lines):
        lines[i] = lines[i].replace('"faction" in m', '"faction" in item')
        lines[i] = lines[i].replace('"unlock_reputation" in m', '"unlock_reputation" in item')
        lines[i] = lines[i].replace('"price" in m', '"price" in item')
        lines[i] = lines[i].replace('"item_id" in m', '"item_id" in item')
        print(f"\n已修复第{i+1}行的m变量")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n=== 修复后（第596-618行）===")
for i in range(595, 618):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

print("\n✅ 第598、600、605、607、616行的m变量错误已修复！")

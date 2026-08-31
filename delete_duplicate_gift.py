# -*- coding: utf-8 -*-
"""
删除game_state.gd中第4150行重复的给道友送礼函数定义
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第4148-4175行的内容
print("=== 删除前（第4148-4175行）===")
for i in range(4147, 4175):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

# 删除第4149-4172行（索引4148-4171）
# 第4149行是注释：# 给道友送礼（提升好感度：
# 第4150行是函数定义：func 给道友送礼(名字: String, 礼物: String = "灵茶") -> Dictionary:
# 第4172行是函数结束：return {"成功": true, "原因": "送给%s%s，好感度+%d" % [名字, 礼物, 好感度提升]}
del lines[4148:4172]

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n=== 删除后（第4148-4160行）===")
for i in range(4147, 4160):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

print("\n✅ 第4150行重复的给道友送礼函数定义已删除！")

# -*- coding: utf-8 -*-
"""
修复page_herb_garden.gd中的变量引用错误
将一些错误地替换为_作物列表容器的引用改回_作物列表（Array类型）
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_herb_garden.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 需要改回_作物列表的行号（Array类型的引用）
# 第260、261、262、311、322、363、365行（索引259、260、261、310、321、362、364）
lines_to_fix = [259, 260, 261, 310, 321, 362, 364]

fix_count = 0

for line_num in lines_to_fix:
    if line_num < len(lines):
        old_line = lines[line_num]
        if "_作物列表容器" in old_line:
            new_line = old_line.replace("_作物列表容器", "_作物列表")
            lines[line_num] = new_line
            fix_count += 1
            print(f"第{line_num+1}行：修复成功")
            print(f"  原：{old_line.rstrip()}")
            print(f"  新：{new_line.rstrip()}")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\n✅ 总共修复了 {fix_count} 处变量引用错误")

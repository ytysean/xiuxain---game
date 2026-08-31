# -*- coding: utf-8 -*-
"""
修复page_herb_garden.gd中的变量重复定义错误
将所有VBoxContainer类型的 _作物列表 引用替换为 _作物列表容器
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_herb_garden.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 需要替换的行号（VBoxContainer类型的引用）
# 第138-146行（索引137-145）
# 第227、232、237、260-262、272行（索引226、231、236、259-261、271）
# 第311、322、363、365行（索引310、321、362、364）

lines_to_replace = [137, 138, 139, 140, 141, 142, 143, 144, 145,  # 第138-146行
                    226, 231, 236, 259, 260, 261, 271,  # 第227、232、237、260-262、272行
                    310, 321, 362, 364]  # 第311、322、363、365行

replacement_count = 0

for line_num in lines_to_replace:
    if line_num < len(lines):
        old_line = lines[line_num]
        if "_作物列表" in old_line and "_作物列表容器" not in old_line:
            new_line = old_line.replace("_作物列表", "_作物列表容器")
            lines[line_num] = new_line
            replacement_count += 1
            print(f"第{line_num+1}行：替换成功")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\n✅ 总共替换了 {replacement_count} 处 VBoxContainer 类型的 _作物列表 引用")

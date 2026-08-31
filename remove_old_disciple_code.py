# -*- coding: utf-8 -*-
"""
删除弟子卡片中残留的旧代码（第2行的道心、心魔、命格、灵根、性格标签）
这些已经被新的3行标签布局替代了
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_disciple.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

original_lines = lines.copy()

# 找到需要删除的代码范围
# 从 "道心lbl.add_theme_font_size_override" 开始
# 到 "row2.add_child(性格lbl)" 结束
start_idx = None
end_idx = None

for i, line in enumerate(lines):
    if "道心lbl.add_theme_font_size_override" in line and start_idx is None:
        start_idx = i
    if "row2.add_child(性格lbl)" in line and start_idx is not None:
        end_idx = i
        break

if start_idx is not None and end_idx is not None:
    print("✅ 找到需要删除的代码范围：第%d行 - 第%d行" % (start_idx + 1, end_idx + 1))
    print("删除内容：")
    for i in range(start_idx, end_idx + 1):
        print("  第%d行: %s" % (i + 1, lines[i].rstrip()))
    
    # 删除这些行
    del lines[start_idx:end_idx + 1]
    print("\n✅ 已删除 %d 行旧代码" % (end_idx - start_idx + 1))
else:
    print("❌ 未找到需要删除的代码范围")
    if start_idx is None:
        print("  未找到起始行：道心lbl.add_theme_font_size_override")
    if end_idx is None:
        print("  未找到结束行：row2.add_child(性格lbl)")

# 保存文件
if lines != original_lines:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print("\n✅ 文件已保存")
else:
    print("\n❌ 没有任何修改")

# 验证修改
print("\n" + "=" * 60)
print("验证修改结果")
print("=" * 60)

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

if "道心lbl.add_theme_font_size_override" not in content:
    print("✅ 已删除道心lbl旧代码")
else:
    print("❌ 仍存在道心lbl旧代码")

if "row2.add_child(性格lbl)" not in content:
    print("✅ 已删除性格lbl旧代码")
else:
    print("❌ 仍存在性格lbl旧代码")

if "row3.add_child(心魔lbl)" in content:
    print("✅ 新的状态标签代码保留")
else:
    print("❌ 新的状态标签代码丢失")

if "箭头lbl" in content:
    print("✅ 箭头指示代码保留")
else:
    print("❌ 箭头指示代码丢失")

print("\n🎉 旧代码删除完成！")

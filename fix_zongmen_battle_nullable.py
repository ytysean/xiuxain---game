# -*- coding: utf-8 -*-
"""
修复 zongmen_battle.gd 中的可空类型语法错误：
Dictionary? → Dictionary（GDScript中Dictionary本身就可以为null）
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\zongmen_battle.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 修复：Dictionary? → Dictionary
content = content.replace("-> Dictionary?:", "-> Dictionary:")

# 检查是否有修改
if content != original_content:
    # 保存文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ 修复完成：Dictionary? → Dictionary")
else:
    print("ℹ️  无需修复")

# 验证修改
print("\n" + "=" * 60)
print("验证修改结果")
print("=" * 60)

with open(file_path, 'r', encoding='utf-8') as f:
    verify_content = f.read()

if "-> Dictionary?:" not in verify_content:
    print("✅ 可空类型语法已修复")
else:
    print("❌ 可空类型语法未修复")

if "-> Dictionary:" in verify_content:
    print("✅ 函数返回类型为 Dictionary")
else:
    print("❌ 未找到 Dictionary 返回类型")

print("\n🎉 zongmen_battle.gd 修复完成！")

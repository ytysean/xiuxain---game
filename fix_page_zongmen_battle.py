# -*- coding: utf-8 -*-
"""
修复 page_zongmen_battle.gd 中的问题：
1. d.实时战力() 改为 d.总战力()
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_zongmen_battle.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 修复：d.实时战力() 改为 d.总战力()
old_code = "total_power += d.实时战力()"
new_code = "total_power += d.总战力()"

if old_code in content:
    content = content.replace(old_code, new_code)
    print("✅ 修复: d.实时战力() 改为 d.总战力()")
else:
    print("❌ 未找到 d.实时战力() 调用")

# 检查是否有修改
if content != original_content:
    # 保存文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ 修复已保存到 page_zongmen_battle.gd")
else:
    print("\n❌ 没有任何修改")

# 验证修改
print("\n" + "=" * 60)
print("验证修改结果")
print("=" * 60)

with open(file_path, 'r', encoding='utf-8') as f:
    verify_content = f.read()

if "d.总战力()" in verify_content:
    print("✅ 战力方法调用已修复")
else:
    print("❌ 战力方法调用未修复")

print("\n🎉 page_zongmen_battle.gd 修复完成！")

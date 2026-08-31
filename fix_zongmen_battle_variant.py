# -*- coding: utf-8 -*-
"""
修复 zongmen_battle.gd 中的返回null错误：
将返回类型从 Dictionary 改为 Variant，这样可以返回null
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\zongmen_battle.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 修复1：_select_target 函数返回类型改为 Variant
old_func1 = "static func _select_target(team: Dictionary) -> Dictionary:"
new_func1 = "static func _select_target(team: Dictionary) -> Variant:"
if old_func1 in content:
    content = content.replace(old_func1, new_func1)
    print("✅ 修复1: _select_target 函数返回类型改为 Variant")
else:
    print("❌ 未找到 _select_target 函数定义")

# 修复2：_get_current_team 函数返回类型改为 Variant
old_func2 = "static func _get_current_team(battle_state: Dictionary, side: String) -> Dictionary:"
new_func2 = "static func _get_current_team(battle_state: Dictionary, side: String) -> Variant:"
if old_func2 in content:
    content = content.replace(old_func2, new_func2)
    print("✅ 修复2: _get_current_team 函数返回类型改为 Variant")
else:
    print("❌ 未找到 _get_current_team 函数定义")

# 检查是否有修改
if content != original_content:
    # 保存文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ 修复已保存到 zongmen_battle.gd")
else:
    print("\n❌ 没有任何修改")

# 验证修改
print("\n" + "=" * 60)
print("验证修改结果")
print("=" * 60)

with open(file_path, 'r', encoding='utf-8') as f:
    verify_content = f.read()

if "-> Variant:" in verify_content:
    print("✅ 函数返回类型已改为 Variant")
else:
    print("❌ 函数返回类型未修改")

print("\n🎉 zongmen_battle.gd 修复完成！")

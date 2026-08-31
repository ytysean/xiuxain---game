# -*- coding: utf-8 -*-
"""
修复 zongmen_battle.gd 中的解析错误：
1. 第203行和第217行：函数返回类型是Dictionary，但返回了null
2. 第335-337行：Node对象的get()方法不支持默认值参数
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\zongmen_battle.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# ========== 修复1：_select_target 函数返回类型改为可空 ==========
old_func1 = "static func _select_target(team: Dictionary) -> Dictionary:"
new_func1 = "static func _select_target(team: Dictionary) -> Dictionary?:"
if old_func1 in content:
    content = content.replace(old_func1, new_func1)
    print("✅ 修复1a: _select_target 函数返回类型改为 Dictionary?")
else:
    print("❌ 未找到 _select_target 函数定义")

# ========== 修复2：_get_current_team 函数返回类型改为可空 ==========
old_func2 = "static func _get_current_team(battle_state: Dictionary, side: String) -> Dictionary:"
new_func2 = "static func _get_current_team(battle_state: Dictionary, side: String) -> Dictionary?:"
if old_func2 in content:
    content = content.replace(old_func2, new_func2)
    print("✅ 修复2a: _get_current_team 函数返回类型改为 Dictionary?")
else:
    print("❌ 未找到 _get_current_team 函数定义")

# ========== 修复3：create_member_from_disciple 函数中的 get() 调用 ==========
old_get1 = '''	return {
		"名称": disciple.get("姓名", "无名"),
		"弟子ID": disciple.get("弟子ID", ""),
		"境界": disciple.get("境界", "练气"),'''

new_get1 = '''	return {
		"名称": disciple.姓名 if "姓名" in disciple else "无名",
		"弟子ID": disciple.弟子ID if "弟子ID" in disciple else "",
		"境界": disciple.境界 if "境界" in disciple else "练气",'''

if old_get1 in content:
    content = content.replace(old_get1, new_get1)
    print("✅ 修复3: create_member_from_disciple 函数中的 get() 调用")
else:
    print("❌ 未找到 create_member_from_disciple 函数中的 get() 调用")
    # 尝试另一种格式
    old_get1_v2 = '''        "名称": disciple.get("姓名", "无名"),
        "弟子ID": disciple.get("弟子ID", ""),
        "境界": disciple.get("境界", "练气"),'''
    new_get1_v2 = '''        "名称": disciple.姓名 if "姓名" in disciple else "无名",
        "弟子ID": disciple.弟子ID if "弟子ID" in disciple else "",
        "境界": disciple.境界 if "境界" in disciple else "练气",'''
    if old_get1_v2 in content:
        content = content.replace(old_get1_v2, new_get1_v2)
        print("✅ 修复3v2: create_member_from_disciple 函数中的 get() 调用")

# 检查是否有修改
if content != original_content:
    # 保存文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ 所有修复已保存到 zongmen_battle.gd")
else:
    print("\n❌ 没有任何修改")

# 验证修改
print("\n" + "=" * 60)
print("验证修改结果")
print("=" * 60)

with open(file_path, 'r', encoding='utf-8') as f:
    verify_content = f.read()

if "-> Dictionary?:" in verify_content:
    print("✅ 函数返回类型已改为可空类型")
else:
    print("❌ 函数返回类型未修改")

if 'disciple.姓名 if "姓名" in disciple else "无名"' in verify_content:
    print("✅ get() 调用已修复")
else:
    print("❌ get() 调用未修复")

print("\n🎉 zongmen_battle.gd 修复完成！")

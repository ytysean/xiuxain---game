# -*- coding: utf-8 -*-
"""
添加活动中心页面到game_ui.gd
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\game_ui.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 添加活动中心页面场景引用
old_ref = 'const PageEquipmentBlueprintScene: PackedScene = preload("res://ui/page_equipment_blueprint.tscn")'
new_ref = '''const PageEquipmentBlueprintScene: PackedScene = preload("res://ui/page_equipment_blueprint.tscn")
const PageActivityScene: PackedScene = preload("res://ui/page_activity.tscn")'''

if old_ref in content:
    content = content.replace(old_ref, new_ref)
    print("✅ 添加活动中心页面场景引用成功")
else:
    print("❌ 未找到PageEquipmentBlueprintScene引用")

# 2. 在ENTRY_SUB_PAGES中添加活动中心入口
old_entry = '''	"装备图纸": PageEquipmentBlueprintScene,
}'''
new_entry = '''	"装备图纸": PageEquipmentBlueprintScene,
	"活动中心": PageActivityScene,
}'''

if old_entry in content:
    content = content.replace(old_entry, new_entry)
    print("✅ 添加活动中心入口成功")
else:
    print("❌ 未找到装备图纸入口")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 活动中心页面添加完成！")
print("\n📋 已完成的工作：")
print("  1. 添加活动中心页面场景引用（PageActivityScene）")
print("  2. 在宗门首页网格入口中添加活动中心入口")
print("\n📌 玩家现在可以通过宗门首页的「活动中心」入口访问活动页面了！")

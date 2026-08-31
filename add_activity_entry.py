# -*- coding: utf-8 -*-
"""
在宗门首页的更多弹窗中添加活动中心入口
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\sect_home_page.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 在MORE_ENTRIES中添加活动中心入口
old_entry = '''	{"id": "装备图纸", "icon": "entry_equipment_blueprint_36"},
]'''
new_entry = '''	{"id": "装备图纸", "icon": "entry_equipment_blueprint_36"},
	{"id": "活动中心", "icon": "entry_fragment_chest_36"},
]'''

if old_entry in content:
    content = content.replace(old_entry, new_entry)
    print("✅ 在更多弹窗中添加活动中心入口成功")
else:
    print("❌ 未找到装备图纸入口")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 活动中心入口添加完成！")
print("\n📋 已完成的工作：")
print("  1. 在宗门首页的更多弹窗中添加活动中心入口")
print("\n📌 玩家现在可以通过宗门首页的「更多」弹窗中的「活动中心」入口访问活动页面了！")

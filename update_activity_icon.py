# -*- coding: utf-8 -*-
"""
更新活动中心入口图标
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\sect_home_page.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 更新活动中心入口图标
old_text = '{"id": "活动中心", "icon": "entry_fragment_chest_36"}'
new_text = '{"id": "活动中心", "icon": "entry_activity_36"}'

if old_text in content:
    content = content.replace(old_text, new_text)
    print("✅ 更新活动中心入口图标成功")
else:
    print("❌ 未找到活动中心入口")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 活动中心入口图标更新完成！")
print("\n📋 已完成的工作：")
print("  1. 生成活动中心专属图标（entry_activity_36.png）")
print("  2. 更新活动中心入口图标为专属图标")

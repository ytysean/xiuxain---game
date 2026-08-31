# -*- coding: utf-8 -*-
"""
在sect_home_page.gd中添加新系统的入口按钮
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\sect_home_page.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 在MORE_ENTRIES中添加新系统的入口
old_more_entries = '''const MORE_ENTRIES: Array = [
	{"id": "宗主管理", "icon": "entry_zongzhuguanli_36"},
	{"id": "幻形", "icon": "entry_huanxing_36"},
	{"id": "功勋", "icon": "entry_gongxunbei_36"},
	{"id": "宗规", "icon": "entry_zongmenguizhi_36"},
	{"id": "道友", "icon": "entry_daoyou_36"},
	{"id": "阵营声望", "icon": "entry_fengyunbang_36"},
	{"id": "宗门战", "icon": "entry_zongmenyaowu_36"},
]'''

new_more_entries = '''const MORE_ENTRIES: Array = [
	{"id": "宗主管理", "icon": "entry_zongzhuguanli_36"},
	{"id": "幻形", "icon": "entry_huanxing_36"},
	{"id": "功勋", "icon": "entry_gongxunbei_36"},
	{"id": "宗规", "icon": "entry_zongmenguizhi_36"},
	{"id": "道友", "icon": "entry_daoyou_36"},
	{"id": "阵营声望", "icon": "entry_fengyunbang_36"},
	{"id": "宗门战", "icon": "entry_zongmenyaowu_36"},
	{"id": "傀儡", "icon": "entry_kucang_36"},
	{"id": "藏书阁", "icon": "entry_tujian_36"},
	{"id": "药园", "icon": "entry_lingtian_36"},
	{"id": "丹方", "icon": "entry_lianjie_36"},
	{"id": "装备图纸", "icon": "entry_lianjie_36"},
]'''

if old_more_entries in content:
    content = content.replace(old_more_entries, new_more_entries)
    print("✅ 新系统入口添加成功")
else:
    print("❌ 未找到MORE_ENTRIES位置")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 宗门首页入口按钮添加完成！")
print("\n📋 已添加的新系统入口：")
print("  1. 傀儡系统")
print("  2. 藏书阁系统")
print("  3. 药园系统")
print("  4. 丹方系统")
print("  5. 装备图纸系统")
print("\n📌 访问方式：")
print("  点击宗门首页底部快捷栏的「更多」按钮，即可看到新系统的入口。")
print("  注意：新系统使用了现有的图标作为占位，后续可以生成专属图标。")

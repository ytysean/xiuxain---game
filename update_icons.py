# -*- coding: utf-8 -*-
"""
更新sect_home_page.gd文件，将新系统的入口图标替换为专属图标
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\sect_home_page.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 更新MORE_ENTRIES中的图标
old_more_entries = '''const MORE_ENTRIES: Array = [
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

new_more_entries = '''const MORE_ENTRIES: Array = [
	{"id": "宗主管理", "icon": "entry_zongzhuguanli_36"},
	{"id": "幻形", "icon": "entry_huanxing_36"},
	{"id": "功勋", "icon": "entry_gongxunbei_36"},
	{"id": "宗规", "icon": "entry_zongmenguizhi_36"},
	{"id": "道友", "icon": "entry_daoyou_36"},
	{"id": "阵营声望", "icon": "entry_fengyunbang_36"},
	{"id": "宗门战", "icon": "entry_zongmenyaowu_36"},
	{"id": "傀儡", "icon": "entry_puppet_36"},
	{"id": "藏书阁", "icon": "entry_library_36"},
	{"id": "药园", "icon": "entry_herb_garden_36"},
	{"id": "丹方", "icon": "entry_pill_formula_36"},
	{"id": "装备图纸", "icon": "entry_equipment_blueprint_36"},
]'''

if old_more_entries in content:
    content = content.replace(old_more_entries, new_more_entries)
    print("✅ 新系统入口图标更新成功")
else:
    print("❌ 未找到MORE_ENTRIES位置")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 宗门首页入口图标更新完成！")
print("\n📋 已更新的图标：")
print("  1. 傀儡系统：entry_kucang_36 → entry_puppet_36")
print("  2. 藏书阁系统：entry_tujian_36 → entry_library_36")
print("  3. 药园系统：entry_lingtian_36 → entry_herb_garden_36")
print("  4. 丹方系统：entry_lianjie_36 → entry_pill_formula_36")
print("  5. 装备图纸系统：entry_lianjie_36 → entry_equipment_blueprint_36")
print("\n📌 图标文件位置：")
print("  E:\\Xiuxian\\taixuanzongmenlu\\art\\icons\\hd\\")
print("\n📌 图标风格：")
print("  中国风圆形图标，金色边框，顶部菱形装饰，底部云纹装饰，山水画风格")

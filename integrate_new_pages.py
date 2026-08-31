# -*- coding: utf-8 -*-
"""
在game_ui.gd中添加新页面的preload和映射
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\game_ui.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 添加新页面的preload
old_preload = '''const PageFragmentChestScene: PackedScene = preload("res://ui/page_fragment_chest.tscn")

# 与 BottomTabBar.TABS 保持一致'''

new_preload = '''const PageFragmentChestScene: PackedScene = preload("res://ui/page_fragment_chest.tscn")
const PagePuppetScene: PackedScene = preload("res://ui/page_puppet.tscn")
const PageLibraryScene: PackedScene = preload("res://ui/page_library.tscn")
const PageHerbGardenScene: PackedScene = preload("res://ui/page_herb_garden.tscn")
const PagePillFormulaScene: PackedScene = preload("res://ui/page_pill_formula.tscn")
const PageEquipmentBlueprintScene: PackedScene = preload("res://ui/page_equipment_blueprint.tscn")

# 与 BottomTabBar.TABS 保持一致'''

if old_preload in content:
    content = content.replace(old_preload, new_preload)
    print("✅ 新页面preload添加成功")
else:
    print("❌ 未找到preload位置")

# 2. 在ENTRY_SUB_PAGES中添加新页面的映射
old_sub_pages = '''	"碎片宝箱": PageFragmentChestScene,
}'''

new_sub_pages = '''	"碎片宝箱": PageFragmentChestScene,
	"傀儡": PagePuppetScene,
	"藏书阁": PageLibraryScene,
	"药园": PageHerbGardenScene,
	"丹方": PagePillFormulaScene,
	"装备图纸": PageEquipmentBlueprintScene,
}'''

if old_sub_pages in content:
    content = content.replace(old_sub_pages, new_sub_pages)
    print("✅ 新页面映射添加成功")
else:
    print("❌ 未找到ENTRY_SUB_PAGES位置")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 新页面集成完成！")
print("\n📋 已集成的新页面：")
print("  1. 傀儡系统 (page_puppet.tscn)")
print("  2. 藏书阁系统 (page_library.tscn)")
print("  3. 药园系统 (page_herb_garden.tscn)")
print("  4. 丹方系统 (page_pill_formula.tscn)")
print("  5. 装备图纸系统 (page_equipment_blueprint.tscn)")
print("\n📌 访问方式：")
print("  这些页面已添加到ENTRY_SUB_PAGES中，可以通过宗门首页的入口访问。")
print("  如果宗门首页没有对应的入口按钮，需要在sect_home_page.gd中添加对应的入口。")

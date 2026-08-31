# -*- coding: utf-8 -*-
"""
在game_ui.gd中添加阵营任务和商店页面的入口
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\game_ui.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 在页面脚本加载区域添加阵营任务和商店页面的脚本加载
old_load = '''const PageSkinShopScene = preload("res://ui/skin_shop_page.gd")'''

new_load = '''const PageSkinShopScene = preload("res://ui/skin_shop_page.gd")
const PageFactionQuestShopScene = preload("res://ui/faction_quest_shop_page.gd")'''

if old_load in content:
    content = content.replace(old_load, new_load)
    print("✅ 阵营任务和商店页面脚本加载添加成功")
else:
    print("❌ 未找到页面脚本加载区域")

# 2. 在打开宗主皮肤商店页函数之后添加打开阵营任务和商店页面的函数
old_func = '''# 打开宗主皮肤商店页（从宗主详情页换装按钮打开）
func _open_master_skin_shop() -> void:
	print("[GameUI] _open_master_skin_shop 被调用")
	_show_sub_page("宗主仙衣阁", PageMasterSkinShopScene)
	print("[GameUI] 宗主皮肤商店页已打开")'''

new_func = '''# 打开宗主皮肤商店页（从宗主详情页换装按钮打开）
func _open_master_skin_shop() -> void:
	print("[GameUI] _open_master_skin_shop 被调用")
	_show_sub_page("宗主仙衣阁", PageMasterSkinShopScene)
	print("[GameUI] 宗主皮肤商店页已打开")

# 打开阵营任务和商店页面
func _open_faction_quest_shop() -> void:
	print("[GameUI] _open_faction_quest_shop 被调用")
	_show_sub_page("阵营任务商店", PageFactionQuestShopScene)
	# 连接返回信号
	if _current_sub != null and is_instance_valid(_current_sub) and _current_sub.has_signal("返回主页"):
		_current_sub.返回主页.connect(_close_sub_page)
	print("[GameUI] 阵营任务和商店页面已打开")'''

if old_func in content:
    content = content.replace(old_func, new_func)
    print("✅ 打开阵营任务和商店页面函数添加成功")
else:
    print("❌ 未找到打开宗主皮肤商店页函数")

# 3. 在权责请求函数中添加阵营任务和商店的入口
old_rights = '''		"阵堂布置":
			_show_page("殿阁")
		_:
			_toast("【%s】系统即将开放" % 分类)'''

new_rights = '''		"阵堂布置":
			_show_page("殿阁")
		"阵营任务":
			_open_faction_quest_shop()
		_:
			_toast("【%s】系统即将开放" % 分类)'''

if old_rights in content:
    content = content.replace(old_rights, new_rights)
    print("✅ 权责请求中阵营任务入口添加成功")
else:
    print("❌ 未找到权责请求函数")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 阵营任务和商店页面入口添加完成！")
print("\n📋 使用方法：")
print("  1. 在宗主详情页的权责按钮中，点击\"阵营任务\"即可打开阵营任务和商店页面")
print("  2. 也可以在其他UI中调用 GameUI._open_faction_quest_shop() 来打开")

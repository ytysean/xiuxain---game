# -*- coding: utf-8 -*-
"""
修复阵营任务和商店页面的脚本加载方式，使用load代替preload
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\game_ui.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 修改打开阵营任务和商店页面的函数，使用load加载脚本
old_func = '''# 打开阵营任务和商店页面
func _open_faction_quest_shop() -> void:
	print("[GameUI] _open_faction_quest_shop 被调用")
	_show_sub_page("阵营任务商店", PageFactionQuestShopScene)
	# 连接返回信号
	if _current_sub != null and is_instance_valid(_current_sub) and _current_sub.has_signal("返回主页"):
		_current_sub.返回主页.connect(_close_sub_page)
	print("[GameUI] 阵营任务和商店页面已打开")'''

new_func = '''# 打开阵营任务和商店页面
func _open_faction_quest_shop() -> void:
	print("[GameUI] _open_faction_quest_shop 被调用")
	# 使用load动态加载脚本，不需要preload
	var 脚本 = load("res://ui/faction_quest_shop_page.gd")
	if 脚本 == null:
		push_error("faction_quest_shop_page.gd 加载失败")
		return
	_show_sub_page("阵营任务商店", 脚本)
	# 连接返回信号
	if _current_sub != null and is_instance_valid(_current_sub) and _current_sub.has_signal("返回主页"):
		_current_sub.返回主页.connect(_close_sub_page)
	print("[GameUI] 阵营任务和商店页面已打开")'''

if old_func in content:
    content = content.replace(old_func, new_func)
    print("✅ 阵营任务和商店页面脚本加载方式修复成功")
else:
    print("❌ 未找到打开阵营任务和商店页面函数")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 阵营任务和商店页面脚本加载方式修复完成！")

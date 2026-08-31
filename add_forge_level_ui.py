# -*- coding: utf-8 -*-
"""
修改page_building.gd，添加炼器等级显示：
1. 在配方列表之前添加炼器等级显示
2. 修改炼器按钮的调用，使用Game.执行炼器方法
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_building.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 1. 在配方列表之前添加炼器等级显示 ==========
old_forge_ui = """	# 配方列表
	var 配方区: VBoxContainer = _add_section("炼器秘录")"""

new_forge_ui = """	# 炼器等级显示
	var 炼器等级区: VBoxContainer = _add_section("炼器等级")
	var 炼器加成: Dictionary = Game.获取炼器加成() if Game != null and Game.has_method("获取炼器加成") else {"等级": 1, "成功率加成": 0, "高品质加成": 0}
	var 炼器等级label := Label.new()
	炼器等级label.text = "当前等级：Lv.%d  成功率加成：+%.0f%%  高品质加成：+%.0f%%" % [int(炼器加成["等级"]), float(炼器加成["成功率加成"]), float(炼器加成["高品质加成"]) * 100]
	UITheme.apply_body_font(炼器等级label)
	炼器等级区.add_child(炼器等级label)
	if Game != null and "炼器经验值" in Game:
		var 炼器经验label := Label.new()
		炼器经验label.text = "炼器经验：%d" % int(Game.炼器经验值)
		UITheme.apply_aux_font(炼器经验label)
		炼器等级区.add_child(炼器经验label)
	# 配方列表
	var 配方区: VBoxContainer = _add_section("炼器秘录")"""

if old_forge_ui in content:
    content = content.replace(old_forge_ui, new_forge_ui)
    print("✅ 炼器等级显示添加成功")
else:
    print("❌ 未找到炼器UI的目标代码")

# ========== 2. 修改炼器按钮的调用，使用Game.执行炼器方法 ==========
old_forge_pressed = """func _on_炼器_pressed(fid: String, 器堂等级: int) -> void:
	var 背包: Array = Game.仓库
	var 结果 = ForgeSystem.炼器(fid, 背包, 器堂等级)
	Game.仓库 = 背包
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "炼器", str(结果.get("原因","")))
	_show_detail.call_deferred("qitang")"""

new_forge_pressed = """func _on_炼器_pressed(fid: String, 器堂等级: int) -> void:
	# 使用Game.执行炼器方法，自动管理炼器经验
	var 结果 = Game.执行炼器(fid, 器堂等级) if Game != null and Game.has_method("执行炼器") else ForgeSystem.炼器(fid, Game.仓库, 器堂等级)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "炼器", str(结果.get("原因","")))
	_show_detail.call_deferred("qitang")"""

if old_forge_pressed in content:
    content = content.replace(old_forge_pressed, new_forge_pressed)
    print("✅ 炼器按钮调用修改成功")
else:
    print("❌ 未找到炼器按钮调用的目标代码")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

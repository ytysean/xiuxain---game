# -*- coding: utf-8 -*-
"""
修改page_building.gd，完善阵法堂UI：
1. 添加阵法耐久度显示（文字显示）
2. 添加阵法修复按钮
3. 修改升级阵法方法，使用Game.升级阵法封装方法
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_building.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 1. 在效果显示之后添加耐久度显示和修复按钮 ==========
old_effect = """			# 效果
			if 当前等级 > 0:
				var effect_lbl := Label.new()
				var 防御 = int(阵法.get("基础防御",0)) + (当前等级-1)*int(阵法.get("每级防御",0))
				var 修炼 = int(阵法.get("基础修炼",0)) + (当前等级-1)*int(阵法.get("每级修炼",0))
				var 产出 = int(阵法.get("基础产出",0)) + (当前等级-1)*int(阵法.get("每级产出",0))
				var effect_text = "效果："
				if 防御 > 0: effect_text += "防御+%d " % 防御
				if 修炼 > 0: effect_text += "修炼+%d%% " % 修炼
				if 产出 > 0: effect_text += "产出+%d%% " % 产出
				effect_lbl.text = effect_text
				effect_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
				effect_lbl.add_theme_font_size_override("font_size", 16)
				card_vb.add_child(effect_lbl)
			# 升级按钮"""

new_effect = """			# 效果
			if 当前等级 > 0:
				var effect_lbl := Label.new()
				var 防御 = int(阵法.get("基础防御",0)) + (当前等级-1)*int(阵法.get("每级防御",0))
				var 修炼 = int(阵法.get("基础修炼",0)) + (当前等级-1)*int(阵法.get("每级修炼",0))
				var 产出 = int(阵法.get("基础产出",0)) + (当前等级-1)*int(阵法.get("每级产出",0))
				var effect_text = "效果："
				if 防御 > 0: effect_text += "防御+%d " % 防御
				if 修炼 > 0: effect_text += "修炼+%d%% " % 修炼
				if 产出 > 0: effect_text += "产出+%d%% " % 产出
				effect_lbl.text = effect_text
				effect_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
				effect_lbl.add_theme_font_size_override("font_size", 16)
				card_vb.add_child(effect_lbl)
				# 耐久度显示
				var 最大耐久度: int = ZhenFaSystem.计算最大耐久度(当前等级)
				var 当前耐久度: int = int(Game.阵法耐久度.get(阵法ID, 最大耐久度)) if Game != null else 最大耐久度
				var dur_lbl := Label.new()
				var 耐久度颜色 = Color(0.6, 0.8, 0.6) if 当前耐久度 > 最大耐久度 * 0.5 else (Color(0.9, 0.7, 0.3) if 当前耐久度 > 最大耐久度 * 0.2 else Color(0.9, 0.4, 0.4))
				dur_lbl.text = "耐久度：%d/%d（%.0f%%）" % [当前耐久度, 最大耐久度, float(当前耐久度) / float(max(1, 最大耐久度)) * 100]
				dur_lbl.add_theme_color_override("font_color", 耐久度颜色)
				dur_lbl.add_theme_font_size_override("font_size", 16)
				card_vb.add_child(dur_lbl)
				# 修复按钮（耐久度不满时显示）
				if 当前耐久度 < 最大耐久度:
					var 修复消耗: int = ZhenFaSystem.计算修复消耗(当前耐久度, 最大耐久度)
					var repair_btn := Button.new()
					repair_btn.text = "修复阵法（消耗%d灵石）" % 修复消耗
					repair_btn.custom_minimum_size = Vector2(0, 36)
					repair_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					UITheme.apply_secondary_button_style(repair_btn)
					repair_btn.pressed.connect(_on_修复阵法.bind(阵法ID))
					card_vb.add_child(repair_btn)
			# 升级按钮"""

if old_effect in content:
    content = content.replace(old_effect, new_effect)
    print("✅ 阵法耐久度显示和修复按钮添加成功")
else:
    print("❌ 未找到效果显示的目标代码")

# ========== 2. 修改升级阵法方法，使用Game.升级阵法封装方法 ==========
old_upgrade = """func _on_升级阵法(阵法ID: String, 当前等级: int, 阵法堂等级: int) -> void:
	var 结果 = ZhenFaSystem.升级阵法(阵法ID, 当前等级, 阵法堂等级)
	if 结果.get("成功", false):
		Game.阵法等级[阵法ID] = int(结果.get("新等级", 当前等级))
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "阵法升级", str(结果.get("原因","")))
	_show_detail.call_deferred("zhenfa")"""

new_upgrade = """func _on_升级阵法(阵法ID: String, 当前等级: int, 阵法堂等级: int) -> void:
	# 使用Game.升级阵法封装方法，自动更新等级和耐久度
	var 结果 = Game.升级阵法(阵法ID, 阵法堂等级) if Game != null and Game.has_method("升级阵法") else ZhenFaSystem.升级阵法(阵法ID, 当前等级, 阵法堂等级)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "阵法升级", str(结果.get("原因","")))
	_show_detail.call_deferred("zhenfa")

func _on_修复阵法(阵法ID: String) -> void:
	# 使用Game.修复阵法封装方法，自动更新耐久度
	var 结果 = Game.修复阵法(阵法ID) if Game != null and Game.has_method("修复阵法") else {"成功": false, "原因": "修复方法不存在"}
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "阵法修复", str(结果.get("原因","")))
	_show_detail.call_deferred("zhenfa")"""

if old_upgrade in content:
    content = content.replace(old_upgrade, new_upgrade)
    print("✅ 升级阵法方法修改成功")
else:
    print("❌ 未找到升级阵法方法的目标代码")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

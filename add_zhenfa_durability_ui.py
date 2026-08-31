# -*- coding: utf-8 -*-
"""
修改page_building.gd，完善阵法堂UI：
添加阵法耐久度显示和修复按钮
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_building.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 在效果显示之后添加耐久度显示和修复按钮 ==========
old_effect = """			card_vb.add_child(effect_lbl)
		# 升级按钮"""

new_effect = """			card_vb.add_child(effect_lbl)
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

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

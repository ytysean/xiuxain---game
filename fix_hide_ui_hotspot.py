# -*- coding: utf-8 -*-
"""
修复隐藏UI按钮热区和图标区域不匹配的问题：
1. 将眼睛图标的 stretch_mode 改为 STRETCH_SCALE，让图标填满整个按钮区域
2. 调整按钮大小和位置，确保热区刚好在图标区域
3. 确保按钮和图标的位置、大小完全一致
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\sect_home_page.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 修复隐藏UI按钮：调整图标stretch_mode，确保热区和图标匹配
old_eye = """# 隐藏UI开关：仅图标，无底框无文字，放在声望下方紧邻框体
func _build_eye() -> void:
	var sz: float = 20.0   # 按钮大小（稍大一点，更容易点击）
	var cx: float = 440.0  # 对齐声望图标中心（440）
	var x: float = cx - sz * 0.5
	var btn := Button.new()
	btn.name = "HideUIBtn"
	btn.flat = true
	btn.text = ""
	_place(btn, x, 71.0, sz, sz)  # y=71，紧邻框体底部（PANEL_H=70）
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.z_index = 100  # 设置较高的z_index，确保在最上层可点击
	var empty_sb := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("pressed", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)
	btn.pressed.connect(_on_hide_ui_pressed)

	var eye_icon := TextureRect.new()
	eye_icon.name = "EyeIcon"
	eye_icon.texture = UITheme.load_hd_icon("ui_hide_36")
	eye_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	eye_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(eye_icon, 0.0, 0.0, sz, sz)
	eye_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(eye_icon)

	# 添加到 _scene_root 中（永远可见，不会被 _chrome 的隐藏影响）
	# 设置高z_index确保在最上层可点击
	_scene_root.add_child(btn)"""

new_eye = """# 隐藏UI开关：仅图标，无底框无文字，放在声望下方紧邻框体
func _build_eye() -> void:
	var sz: float = 18.0   # 按钮大小（与图标视觉大小匹配）
	var cx: float = 440.0  # 对齐声望图标中心（440）
	var x: float = cx - sz * 0.5
	var btn := Button.new()
	btn.name = "HideUIBtn"
	btn.flat = true
	btn.text = ""
	_place(btn, x, 71.5, sz, sz)  # y=71.5，紧邻框体底部（PANEL_H=70）
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.z_index = 100  # 设置较高的z_index，确保在最上层可点击
	var empty_sb := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("pressed", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)
	btn.pressed.connect(_on_hide_ui_pressed)

	var eye_icon := TextureRect.new()
	eye_icon.name = "EyeIcon"
	eye_icon.texture = UITheme.load_hd_icon("ui_hide_36")
	eye_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	eye_icon.stretch_mode = TextureRect.STRETCH_SCALE  # 图标填满整个按钮区域，确保热区和图标匹配
	eye_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # 图标填满整个按钮
	eye_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(eye_icon)

	# 添加到 _scene_root 中（永远可见，不会被 _chrome 的隐藏影响）
	_scene_root.add_child(btn)"""

if old_eye in content:
    content = content.replace(old_eye, new_eye)
    print("✅ 修复隐藏UI按钮热区：图标改为STRETCH_SCALE填满按钮，热区和图标完全匹配")
else:
    print("❌ 未找到隐藏UI按钮代码")
    if "_build_eye" in content:
        print("ℹ️  找到 _build_eye 函数，但格式不匹配")

if content != original_content:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ sect_home_page.gd 已保存")
else:
    print("❌ sect_home_page.gd 无修改")

print("\n🎉 隐藏UI按钮热区问题修复完成！")

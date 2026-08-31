# -*- coding: utf-8 -*-
"""
修复隐藏UI按钮点击位置不对的问题：
1. 将按钮从 _scene_root 移到 _chrome 容器中（可隐藏浮层，在最上层）
2. 设置较高的z_index，确保按钮在最上层可点击
3. 确保按钮的mouse_filter设置正确
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\sect_home_page.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 修复隐藏UI按钮：添加到_chrome容器，设置z_index，确保可点击
old_eye = """# 隐藏UI开关：仅图标，无底框无文字，放在声望下方紧邻框体
func _build_eye() -> void:
	var sz: float = 18.0   # 按钮大小
	var cx: float = 440.0  # 对齐声望图标中心（440）
	var x: float = cx - sz * 0.5
	var btn := Button.new()
	btn.name = "HideUIBtn"
	btn.flat = true
	btn.text = ""
	_place(btn, x, 72.0, sz, sz)  # y=72，紧邻框体底部（PANEL_H=70）
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
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

	_scene_root.add_child(btn)"""

new_eye = """# 隐藏UI开关：仅图标，无底框无文字，放在声望下方紧邻框体
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

	# 添加到 _chrome 容器中（可隐藏浮层，在最上层），如果 _chrome 不存在则添加到 _scene_root
	if _chrome != null and is_instance_valid(_chrome):
		_chrome.add_child(btn)
	else:
		_scene_root.add_child(btn)"""

if old_eye in content:
    content = content.replace(old_eye, new_eye)
    print("✅ 修复隐藏UI按钮：移到_chrome容器，设置z_index=100，增大按钮到20px")
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

print("\n🎉 隐藏UI按钮点击问题修复完成！")

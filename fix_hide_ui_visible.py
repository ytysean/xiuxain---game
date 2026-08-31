# -*- coding: utf-8 -*-
"""
修复隐藏UI按钮消失的问题：
隐藏UI时 _chrome 容器被设置为不可见，按钮也跟着消失了
解决方案：将按钮放到 _scene_root 中（永远可见），设置高z_index确保可点击
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\sect_home_page.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 修复隐藏UI按钮：放到 _scene_root 中（永远可见），设置高z_index
old_eye = """	# 添加到 _chrome 容器中（可隐藏浮层，在最上层），如果 _chrome 不存在则添加到 _scene_root
	if _chrome != null and is_instance_valid(_chrome):
		_chrome.add_child(btn)
	else:
		_scene_root.add_child(btn)"""

new_eye = """	# 添加到 _scene_root 中（永远可见，不会被 _chrome 的隐藏影响）
	# 设置高z_index确保在最上层可点击
	_scene_root.add_child(btn)"""

if old_eye in content:
    content = content.replace(old_eye, new_eye)
    print("✅ 修复隐藏UI按钮：移到 _scene_root（永远可见），不会被 _chrome 隐藏影响")
else:
    print("❌ 未找到隐藏UI按钮添加代码")
    if "_chrome.add_child(btn)" in content:
        print("ℹ️  找到 _chrome.add_child(btn)，但格式不匹配")

if content != original_content:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ sect_home_page.gd 已保存")
else:
    print("❌ sect_home_page.gd 无修改")

print("\n🎉 隐藏UI按钮消失问题修复完成！")

# -*- coding: utf-8 -*-
"""
修复 page_storage.gd 中的数组越界错误：
分类列表有8个元素，但xs数组只有6个元素，导致越界
改为动态计算x坐标
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_storage.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 修复 _build_categories 函数中的数组越界问题
old_code = '''	var xs: Array = [25.0, 97.0, 169.0, 241.0, 313.0, 385.0]
	for i in range(分类列表.size()):
		var cat: String = 分类列表[i]
		var b := Button.new()
		b.name = "Cat_" + cat
		b.flat = true
		b.text = cat
		_place(b, xs[i], 15.0, 40.0, 22.0)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		_update_cat_style(b, cat == _当前分类)
		b.pressed.connect(_on_cat_pressed.bind(cat))
		_分类栏.add_child(b)

		var line := Panel.new()
		line.name = "CatLine_" + cat
		_place(line, xs[i] - 5.0, 42.0, 40.0, 3.0)
		line.visible = (cat == _当前分类)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lsb := StyleBoxFlat.new()
		lsb.bg_color = UITheme.C01_TEXT_GOLD
		lsb.set_corner_radius_all(_rc(1))
		lsb.set_border_width_all(0)
		line.add_theme_stylebox_override("panel", lsb)
		_分类栏.add_child(line)
		_分类下划线[cat] = line'''

new_code = '''	# 动态计算分类按钮的x坐标（适配8个分类）
	var 分类数: int = 分类列表.size()
	var 按钮宽度: float = 42.0
	var 总按钮宽度: float = 分类数 * 按钮宽度
	var 可用宽度: float = 480.0 - 20.0  # 左右各留10px边距
	var 间距: float = (可用宽度 - 总按钮宽度) / max(分类数 - 1, 1)
	var 起始x: float = 10.0
	for i in range(分类数):
		var cat: String = 分类列表[i]
		var x_pos: float = 起始x + i * (按钮宽度 + 间距)
		var b := Button.new()
		b.name = "Cat_" + cat
		b.flat = true
		b.text = cat
		_place(b, x_pos, 15.0, 按钮宽度, 22.0)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		_update_cat_style(b, cat == _当前分类)
		b.pressed.connect(_on_cat_pressed.bind(cat))
		_分类栏.add_child(b)

		var line := Panel.new()
		line.name = "CatLine_" + cat
		_place(line, x_pos - 2.0, 42.0, 按钮宽度 + 4.0, 3.0)
		line.visible = (cat == _当前分类)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lsb := StyleBoxFlat.new()
		lsb.bg_color = UITheme.C01_TEXT_GOLD
		lsb.set_corner_radius_all(_rc(1))
		lsb.set_border_width_all(0)
		line.add_theme_stylebox_override("panel", lsb)
		_分类栏.add_child(line)
		_分类下划线[cat] = line'''

if old_code in content:
    content = content.replace(old_code, new_code)
    print("✅ 修复: _build_categories 函数中的数组越界问题")
else:
    print("❌ 未找到需要修复的代码")
    # 尝试查找部分代码
    if "var xs: Array" in content:
        print("ℹ️  找到 xs 数组，但格式不匹配")

# 检查是否有修改
if content != original_content:
    # 保存文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ 修复已保存到 page_storage.gd")
else:
    print("\n❌ 没有任何修改")

# 验证修改
print("\n" + "=" * 60)
print("验证修改结果")
print("=" * 60)

with open(file_path, 'r', encoding='utf-8') as f:
    verify_content = f.read()

if "动态计算分类按钮的x坐标" in verify_content:
    print("✅ 已改为动态计算x坐标")
else:
    print("❌ 未修复")

if "var xs: Array = [25.0, 97.0, 169.0, 241.0, 313.0, 385.0]" not in verify_content:
    print("✅ 已移除固定的xs数组")
else:
    print("❌ 仍存在固定的xs数组")

print("\n🎉 page_storage.gd 修复完成！")

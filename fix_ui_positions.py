# -*- coding: utf-8 -*-
"""
修复两个UI问题：
1. 资源栏详情弹窗位置不对（clampf最小y值太大）
2. 隐藏UI按钮位置不对（应该放在声望下方，紧邻框体）
"""

import os

# ========== 修复1：资源栏详情弹窗位置 ==========
top_bar_path = r"E:\Xiuxian\taixuanzongmenlu\ui\top_bar.gd"

with open(top_bar_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 修复clampf的最小y值，从 CONTAINER_H * UI_SCALE + 4 改为 PANEL_H * UI_SCALE + 4
old_clamp = """	var viewport: Vector2 = get_viewport_rect().size
	px = clampf(px, 8.0 * UITheme.UI_SCALE, viewport.x - pw - 8.0 * UITheme.UI_SCALE)
	py = clampf(py, CONTAINER_H * UITheme.UI_SCALE + 4.0 * UITheme.UI_SCALE, viewport.y - ph - 8.0 * UITheme.UI_SCALE)"""

new_clamp = """	var viewport: Vector2 = get_viewport_rect().size
	px = clampf(px, 8.0 * UITheme.UI_SCALE, viewport.x - pw - 8.0 * UITheme.UI_SCALE)
	py = clampf(py, PANEL_H * UITheme.UI_SCALE + 4.0 * UITheme.UI_SCALE, viewport.y - ph - 8.0 * UITheme.UI_SCALE)"""

if old_clamp in content:
    content = content.replace(old_clamp, new_clamp)
    print("✅ 修复资源栏详情弹窗位置（clampf最小y值从CONTAINER_H改为PANEL_H）")
else:
    print("❌ 未找到clampf代码")

if content != original_content:
    with open(top_bar_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ top_bar.gd 已保存")
else:
    print("❌ top_bar.gd 无修改")

# ========== 修复2：隐藏UI按钮位置 ==========
home_page_path = r"E:\Xiuxian\taixuanzongmenlu\ui\sect_home_page.gd"

with open(home_page_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 修复隐藏UI按钮位置，从右上角改为声望下方紧邻框体
# 声望图标x=440.0，框体高度PANEL_H=70.0，所以按钮放在x=440附近，y=70+边框位置
old_eye = """# 隐藏UI开关：仅图标，无底框无文字，放大并右对齐顶栏（中心约 1025 屏幕，48px）
func _build_eye() -> void:
	var sz: float = 21.333333   # 48 / 2.25
	var cx: float = 469.333     # 按钮右边缘对齐屏幕右边缘480
	var x: float = cx - sz * 0.5
	var btn := Button.new()
	btn.name = "HideUIBtn"
	btn.flat = true
	btn.text = ""
	_place(btn, x, 163.0, sz, sz)"""

new_eye = """# 隐藏UI开关：仅图标，无底框无文字，放在声望下方紧邻框体
func _build_eye() -> void:
	var sz: float = 18.0   # 按钮大小
	var cx: float = 440.0  # 对齐声望图标中心（440）
	var x: float = cx - sz * 0.5
	var btn := Button.new()
	btn.name = "HideUIBtn"
	btn.flat = true
	btn.text = ""
	_place(btn, x, 72.0, sz, sz)  # y=72，紧邻框体底部（PANEL_H=70）"""

if old_eye in content:
    content = content.replace(old_eye, new_eye)
    print("✅ 修复隐藏UI按钮位置（从右上角改为声望下方紧邻框体）")
else:
    print("❌ 未找到隐藏UI按钮代码")
    # 尝试查找部分代码
    if "_build_eye" in content:
        print("ℹ️  找到 _build_eye 函数，但格式不匹配")

if content != original_content:
    with open(home_page_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ sect_home_page.gd 已保存")
else:
    print("❌ sect_home_page.gd 无修改")

print("\n🎉 两个UI问题修复完成！")

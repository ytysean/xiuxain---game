# -*- coding: utf-8 -*-
"""
弟子系统优化 - 第二部分：弟子标签UI分层完善
1. 核心标签：境界、资质（突出显示）
2. 次要标签：道途、身份、灵根品阶（中等显示）
3. 状态标签：突破中、稳固期、心魔高、道心低等（小字体，状态色）
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_disciple.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# ========== 1. 增加卡片高度，从70px增加到90px ==========
old_height = """	# 紧凑列表式卡片，高度约70px
	var 卡片 := PanelContainer.new()
	卡片.name = "Card_%d" % 索引
	卡片.custom_minimum_size = Vector2(0, int(round(70 * UITheme.UI_SCALE)))"""

new_height = """	# 紧凑列表式卡片，高度约90px（增加状态标签行）
	var 卡片 := PanelContainer.new()
	卡片.name = "Card_%d" % 索引
	卡片.custom_minimum_size = Vector2(0, int(round(90 * UITheme.UI_SCALE)))"""

if old_height in content:
    content = content.replace(old_height, new_height)
    print("✅ 增加卡片高度到90px")
else:
    print("❌ 未找到卡片高度定义")

# ========== 2. 修改第1行，只保留名字和核心标签 ==========
old_row1 = """	# 第1行：名字+品质+境界+身份+年龄
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", int(round(8 * UITheme.UI_SCALE)))
	信息vb.add_child(row1)

	var 名字lbl := Label.new()
	名字lbl.text = str(_safe_get(d, "姓名", "—"))
	名字lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	名字lbl.add_theme_font_size_override("font_size", int(round(18 * UITheme.UI_SCALE)))
	row1.add_child(名字lbl)

	var 资质名: String = _资质显示.get(资质, "凡俗")
	# 资质标签用pill样式，带背景框，增强视觉区别
	var 资质pill = _make_pill(资质名, 品质色, 4)
	资质pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	资质pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(资质pill)

	var 境界lbl := Label.new()
	境界lbl.text = 境界
	境界lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	境界lbl.add_theme_font_size_override("font_size", int(round(14 * UITheme.UI_SCALE)))
	row1.add_child(境界lbl)

	var 身份lbl := Label.new()
	身份lbl.text = 身份
	身份lbl.add_theme_font_size_override("font_size", int(round(14 * UITheme.UI_SCALE)))
	身份lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	row1.add_child(身份lbl)

	var 年龄lbl := Label.new()
	年龄lbl.text = "%d岁" % int(年龄)
	年龄lbl.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
	年龄lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	row1.add_child(年龄lbl)"""

new_row1 = """	# 第1行：名字 + 核心标签（境界、资质）
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", int(round(8 * UITheme.UI_SCALE)))
	信息vb.add_child(row1)

	var 名字lbl := Label.new()
	名字lbl.text = str(_safe_get(d, "姓名", "—"))
	名字lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	名字lbl.add_theme_font_size_override("font_size", int(round(18 * UITheme.UI_SCALE)))
	row1.add_child(名字lbl)

	var 资质名: String = _资质显示.get(资质, "凡俗")
	# 核心标签1：资质（pill样式，突出显示）
	var 资质pill = _make_pill(资质名, 品质色, 4)
	资质pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	资质pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(资质pill)

	# 核心标签2：境界（pill样式，境界色）
	var 境界色 = UIThemeConfig.get_realm_color(境界)
	var 境界pill = _make_pill(境界, 境界色, 4)
	境界pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	境界pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(境界pill)"""

if old_row1 in content:
    content = content.replace(old_row1, new_row1)
    print("✅ 修改第1行，只保留名字和核心标签")
else:
    print("❌ 未找到第1行定义")

# ========== 3. 修改第2行，显示次要标签 ==========
old_row2 = """	# 第2行：战力+心境+道心+心魔+命格+灵根+性格
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", int(round(10 * UITheme.UI_SCALE)))
	信息vb.add_child(row2)

	var 战力lbl := Label.new()
	战力lbl.text = "⚔%s" % 战力文本
	战力lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	战力lbl.add_theme_font_size_override("font_size", int(round(14 * UITheme.UI_SCALE)))
	row2.add_child(战力lbl)

	var 心境lbl := Label.new()
	心境lbl.text = "心%d" % int(心境)
	心境lbl.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
	心境lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.75))
	row2.add_child(心境lbl)

	var 道心lbl := Label.new()
	道心lbl.text = "道%d" % int(道心)"""

new_row2 = """	# 第2行：次要标签（道途、身份、灵根品阶、年龄）+ 战力
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", int(round(8 * UITheme.UI_SCALE)))
	信息vb.add_child(row2)

	# 次要标签：道途
	if 道途 != "" and 道途 != "无":
		var 道途lbl := Label.new()
		道途lbl.text = 道途
		道途lbl.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
		道途lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		row2.add_child(道途lbl)

	# 次要标签：身份
	var 身份lbl := Label.new()
	身份lbl.text = 身份
	身份lbl.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
	身份lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	row2.add_child(身份lbl)

	# 次要标签：灵根品阶
	var 灵根品阶 = str(_safe_get(d, "灵根品阶", "凡品"))
	var 灵根品阶lbl := Label.new()
	灵根品阶lbl.text = 灵根品阶 + "灵根"
	灵根品阶lbl.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
	灵根品阶lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	row2.add_child(灵根品阶lbl)

	# 次要标签：年龄
	var 年龄lbl := Label.new()
	年龄lbl.text = "%d岁" % int(年龄)
	年龄lbl.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
	年龄lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	row2.add_child(年龄lbl)

	# 战力（突出显示）
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(spacer)

	var 战力lbl := Label.new()
	战力lbl.text = "⚔%s" % 战力文本
	战力lbl.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	战力lbl.add_theme_font_size_override("font_size", int(round(14 * UITheme.UI_SCALE)))
	row2.add_child(战力lbl)

	# 第3行：状态标签（突破中、稳固期、心魔高、道心低等）
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", int(round(6 * UITheme.UI_SCALE)))
	信息vb.add_child(row3)

	# 状态标签：突破状态
	var 突破状态 = str(_safe_get(d, "突破状态", ""))
	if 突破状态 != "" and 突破状态 != "无":
		var 突破pill = _make_pill(突破状态, Color(1.0, 0.6, 0.2), 3)
		突破pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row3.add_child(突破pill)

	# 状态标签：稳固期
	var 稳固期 = _safe_get(d, "稳固期", 0)
	if 稳固期 > 0:
		var 稳固pill = _make_pill("稳固期", Color(0.5, 0.8, 0.5), 3)
		稳固pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row3.add_child(稳固pill)

	# 状态标签：心魔高（心魔值 > 50）
	if 心魔值 > 50:
		var 心魔pill = _make_pill("心魔高", Color(0.9, 0.3, 0.3), 3)
		心魔pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row3.add_child(心魔pill)

	# 状态标签：道心低（道心 < 30）
	if 道心 < 30:
		var 道心低pill = _make_pill("道心低", Color(0.7, 0.5, 0.9), 3)
		道心低pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row3.add_child(道心低pill)

	# 状态标签：司职
	var 司职 = str(_safe_get(d, "司职", ""))
	if 司职 != "" and 司职 != "无":
		var 司职pill = _make_pill(司职, Color(0.4, 0.7, 0.9), 3)
		司职pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row3.add_child(司职pill)

	# 如果没有状态标签，显示心境/道心/心魔数值
	if row3.get_child_count() == 0:
		var 心境lbl := Label.new()
		心境lbl.text = "心%d" % int(心境)
		心境lbl.add_theme_font_size_override("font_size", int(round(11 * UITheme.UI_SCALE)))
		心境lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.75))
		row3.add_child(心境lbl)

		var 道心lbl2 := Label.new()
		道心lbl2.text = "道%d" % int(道心)
		道心lbl2.add_theme_font_size_override("font_size", int(round(11 * UITheme.UI_SCALE)))
		道心lbl2.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
		row3.add_child(道心lbl2)

		var 心魔lbl := Label.new()
		心魔lbl.text = "魔%d" % int(心魔值)
		心魔lbl.add_theme_font_size_override("font_size", int(round(11 * UITheme.UI_SCALE)))
		心魔lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5) if 心魔值 > 50 else Color(0.7, 0.6, 0.6))
		row3.add_child(心魔lbl)"""

if old_row2 in content:
    content = content.replace(old_row2, new_row2)
    print("✅ 修改第2行，显示次要标签，并增加第3行状态标签")
else:
    print("❌ 未找到第2行定义")

# 检查是否有修改
if content != original_content:
    # 保存文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ 所有修改已保存到 page_disciple.gd")
else:
    print("\n❌ 没有任何修改")

print("\n🎉 弟子标签UI分层完善完成！")

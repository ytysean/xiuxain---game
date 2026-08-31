# -*- coding: utf-8 -*-
"""
修改page_building.gd，完善藏经阁UI：
1. 添加已学功法列表区域（显示弟子已学的功法，包含等级和熟练度）
2. 添加功法遗忘按钮
3. 显示功法等级加成
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_building.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 1. 在参悟学习按钮之后添加已学功法列表 ==========
old_forge_ui = """		# 参悟学习按钮
		var 学btn := Button.new()
		学btn.text = "参悟学习（消耗%d悟道点）" % int(功法.get("所需悟道点",10))
		学btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
		学btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_primary_button_style(学btn)
		学btn.pressed.connect(_on_参悟学习.bind(_选中功法))
		详情区.add_child(学btn)"""

new_forge_ui = """		# 参悟学习按钮
		var 学btn := Button.new()
		学btn.text = "参悟学习（消耗%d悟道点）" % int(功法.get("所需悟道点",10))
		学btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_PRIMARY)
		学btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_primary_button_style(学btn)
		学btn.pressed.connect(_on_参悟学习.bind(_选中功法))
		详情区.add_child(学btn)
	# 已学功法列表
	var 已学区: VBoxContainer = _add_section("弟子已学功法")
	var 弟子列表 = Game.get("弟子列表") if Game != null else null
	if 弟子列表 != null and 弟子列表.size() > 0:
		# 显示第一个弟子的已学功法（简化版本，后续可以添加弟子选择）
		var 目标弟子 = 弟子列表[0]
		if 目标弟子 != null:
			var 已学功法 = 目标弟子.get("已学功法", [])
			if 已学功法 == null or 已学功法.size() == 0:
				var empty := Label.new()
				empty.text = "暂无已学功法"
				UITheme.apply_aux_font(empty)
				已学区.add_child(empty)
			else:
				for 功法ID in 已学功法:
					var 已学功法信息 = GongFaSystem.功法库.get(功法ID, {})
					if 已学功法信息.is_empty():
						continue
					var 等级: int = GongFaSystem.获取功法等级(目标弟子, 功法ID)
					var 熟练度: int = GongFaSystem.获取功法熟练度(目标弟子, 功法ID)
					var 所需熟练度: int = 0
					if 等级 < GongFaSystem.功法升级熟练度.size():
						所需熟练度 = GongFaSystem.功法升级熟练度[等级]
					var 功法btn := Button.new()
					功法btn.text = "%s Lv.%d\n熟练度：%d/%d" % [str(已学功法信息.get("名称","")), 等级, 熟练度, 所需熟练度 if 等级 < GongFaSystem.功法等级上限 else "已满级"]
					功法btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SECONDARY * 1.3)
					功法btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					UITheme.apply_secondary_button_style(功法btn)
					功法btn.pressed.connect(_on_遗忘功法.bind(功法ID))
					已学区.add_child(功法btn)
				# 提示
				var hint := Label.new()
				hint.text = "点击功法可遗忘（返还50%+悟道点）"
				UITheme.apply_aux_font(hint)
				hint.add_theme_color_override("font_color", UITheme.color_text_body_dim())
				已学区.add_child(hint)
	else:
		var empty := Label.new()
		empty.text = "暂无弟子"
		UITheme.apply_aux_font(empty)
		已学区.add_child(empty)"""

if old_forge_ui in content:
    content = content.replace(old_forge_ui, new_forge_ui)
    print("✅ 已学功法列表添加成功")
else:
    print("❌ 未找到参悟学习按钮的目标代码")

# ========== 2. 添加功法遗忘方法 ==========
old_method = """func _on_参悟学习(功法ID: String) -> void:"""

new_method = """func _on_遗忘功法(功法ID: String) -> void:
	# 查找第一个学习了此功法的弟子
	var 弟子列表 = Game.get("弟子列表") if Game != null else null
	if 弟子列表 == null or 弟子列表.size() == 0:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "提示", "暂无弟子")
		return
	var 目标弟子 = null
	for 弟子 in 弟子列表:
		if 弟子 == null:
			continue
		var 已学功法 = 弟子.get("已学功法", [])
		if 已学功法 != null and 已学功法.has(功法ID):
			目标弟子 = 弟子
			break
	if 目标弟子 == null:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "提示", "没有弟子学习此功法")
		return
	# 遗忘功法
	var 结果 = Game.遗忘功法(目标弟子, 功法ID) if Game != null and Game.has_method("遗忘功法") else GongFaSystem.遗忘功法(目标弟子, 功法ID)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "遗忘", str(结果.get("原因","")))
	_show_detail.call_deferred("cangjing")

func _on_参悟学习(功法ID: String) -> void:"""

if old_method in content:
    content = content.replace(old_method, new_method)
    print("✅ 功法遗忘方法添加成功")
else:
    print("❌ 未找到参悟学习方法的目标代码")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

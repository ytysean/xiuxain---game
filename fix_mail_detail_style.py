# -*- coding: utf-8 -*-
"""
修改page_mail.gd：
1. 将邮件详情从弹窗改为页面内显示（参考魔兽世界风格）
2. 点击邮件后在列表上方显示详情区域
3. 详情区域显示邮件内容、附件和领取按钮
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_mail.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 1. 添加详情区域变量 ==========
old_vars = """var _built: bool = false
var _列表: VBoxContainer
var _mails: Array = []"""

new_vars = """var _built: bool = false
var _列表: VBoxContainer
var _mails: Array = []
var _详情区域: PanelContainer = null
var _详情标题: Label = null
var _详情发件人: Label = null
var _详情时间: Label = null
var _详情内容: Label = null
var _详情附件: Label = null
var _详情领取按钮: Button = null
var _当前选中索引: int = -1"""

if old_vars in content:
    content = content.replace(old_vars, new_vars)
    print("✅ 详情区域变量添加成功")
else:
    print("❌ 未找到变量定义位置")

# ========== 2. 在_build方法中添加详情区域 ==========
old_build = """	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_列表 = VBoxContainer.new()
	_列表.name = "List"
	_列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_列表.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_列表)"""

new_build = """	# 邮件详情区域（参考魔兽世界风格，点击邮件后显示）
	_详情区域 = PanelContainer.new()
	_详情区域.name = "DetailPanel"
	_详情区域.visible = false
	_详情区域.custom_minimum_size = Vector2(0, 180)
	var detail_sb: StyleBoxFlat = StyleBoxFlat.new()
	detail_sb.bg_color = Color(0.08, 0.12, 0.15)
	detail_sb.set_corner_radius_all(12)
	detail_sb.border_width_left = 2
	detail_sb.border_width_right = 2
	detail_sb.border_width_top = 2
	detail_sb.border_width_bottom = 2
	detail_sb.border_color = Color(0.3, 0.5, 0.6)
	_详情区域.add_theme_stylebox_override("panel", detail_sb)
	var detail_vb := VBoxContainer.new()
	detail_vb.add_theme_constant_override("margin_left", 16)
	detail_vb.add_theme_constant_override("margin_right", 16)
	detail_vb.add_theme_constant_override("margin_top", 12)
	detail_vb.add_theme_constant_override("margin_bottom", 12)
	detail_vb.add_theme_constant_override("separation", 8)
	_详情区域.add_child(detail_vb)
	
	# 详情标题行
	var detail_title_row := HBoxContainer.new()
	detail_title_row.add_theme_constant_override("separation", 8)
	_详情标题 = Label.new()
	_详情标题.name = "DetailTitle"
	UITheme.apply_title_font_sized(_详情标题, 20)
	_详情标题.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_title_row.add_child(_详情标题)
	var 关闭详情按钮 := Button.new()
	关闭详情按钮.text = "✕"
	关闭详情按钮.custom_minimum_size = Vector2(32, 32)
	关闭详情按钮.pressed.connect(_on_关闭详情)
	detail_title_row.add_child(关闭详情按钮)
	detail_vb.add_child(detail_title_row)
	
	# 详情发件人和时间
	var detail_meta_row := HBoxContainer.new()
	detail_meta_row.add_theme_constant_override("separation", 16)
	_详情发件人 = Label.new()
	_详情发件人.name = "DetailSender"
	UITheme.apply_aux_font(_详情发件人)
	_详情发件人.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	detail_meta_row.add_child(_详情发件人)
	_详情时间 = Label.new()
	_详情时间.name = "DetailTime"
	UITheme.apply_aux_font(_详情时间)
	_详情时间.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	detail_meta_row.add_child(_详情时间)
	detail_vb.add_child(detail_meta_row)
	
	# 详情内容
	_详情内容 = Label.new()
	_详情内容.name = "DetailContent"
	_详情内容.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_font(_详情内容)
	_详情内容.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vb.add_child(_详情内容)
	
	# 详情附件和领取按钮
	var detail_action_row := HBoxContainer.new()
	detail_action_row.add_theme_constant_override("separation", 16)
	_详情附件 = Label.new()
	_详情附件.name = "DetailAttachment"
	UITheme.apply_aux_font(_详情附件)
	_详情附件.add_theme_color_override("font_color", UITheme.color_text_title1())
	_详情附件.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_action_row.add_child(_详情附件)
	_详情领取按钮 = Button.new()
	_详情领取按钮.name = "DetailClaimBtn"
	_详情领取按钮.text = "领取附件"
	_详情领取按钮.custom_minimum_size = Vector2(120, 36)
	UITheme.apply_primary_button_style(_详情领取按钮)
	_详情领取按钮.pressed.connect(_on_详情领取)
	detail_action_row.add_child(_详情领取按钮)
	detail_vb.add_child(detail_action_row)
	
	vbox.add_child(_详情区域)
	
	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_列表 = VBoxContainer.new()
	_列表.name = "List"
	_列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_列表.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_列表)"""

if old_build in content:
    content = content.replace(old_build, new_build)
    print("✅ 详情区域UI添加成功")
else:
    print("❌ 未找到_build方法中的scroll位置")

# ========== 3. 修改_on_card_clicked方法，显示详情而不是弹窗 ==========
old_card_clicked = """func _on_card_clicked(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			Game.标记邮件已读(idx)
			refresh()
			# 显示邮件详情（红点通过Game.邮件变动信号自动刷新）
			_show_mail_detail(idx)"""

new_card_clicked = """func _on_card_clicked(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			Game.标记邮件已读(idx)
			refresh()
			# 显示邮件详情（页面内显示，参考魔兽世界风格）
			_显示详情(idx)"""

if old_card_clicked in content:
    content = content.replace(old_card_clicked, new_card_clicked)
    print("✅ _on_card_clicked方法修改成功")
else:
    print("❌ 未找到_on_card_clicked方法")

# ========== 4. 替换_show_mail_detail方法为_显示详情方法 ==========
old_show_detail = """# 显示邮件详情弹窗
func _show_mail_detail(idx: int) -> void:
	var 邮件列表 = Game.取邮件列表()
	if idx < 0 or idx >= 邮件列表.size():
		return
	var m = 邮件列表[idx]
	
	# 创建详情弹窗
	var dialog := AcceptDialog.new()
	dialog.title = str(m.get("标题", "邮件详情"))
	dialog.dialog_text = "发件人：%s\\n时间：%s\\n\\n%s" % [
		str(m.get("发件人", "")),
		str(m.get("时间", "")),
		str(m.get("内容", "暂无内容"))
	]
	dialog.ok_button_text = "关闭"
	
	# 如果有附件且未领取，添加领取按钮
	var 附件: Dictionary = m.get("附件", {})
	if not 附件.is_empty() and not bool(m.get("已领", false)):
		var 领取按钮 := Button.new()
		领取按钮.text = "领取附件"
		领取按钮.pressed.connect(func():
			Game.领取邮件(idx)
			refresh()
			# 红点通过Game.邮件变动信号自动刷新
			dialog.queue_free()
		)
		dialog.add_child(领取按钮)
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()"""

new_show_detail = """# 显示邮件详情（页面内显示，参考魔兽世界风格）
func _显示详情(idx: int) -> void:
	var 邮件列表 = Game.取邮件列表()
	if idx < 0 or idx >= 邮件列表.size():
		return
	var m = 邮件列表[idx]
	_当前选中索引 = idx
	
	# 更新详情区域内容
	_详情标题.text = str(m.get("标题", ""))
	_详情发件人.text = "发件人：" + str(m.get("发件人", ""))
	_详情时间.text = str(m.get("时间", ""))
	_详情内容.text = str(m.get("内容", "暂无内容"))
	
	# 更新附件显示和领取按钮
	var 附件: Dictionary = m.get("附件", {})
	if not 附件.is_empty():
		var 已领: bool = bool(m.get("已领", false))
		_详情附件.text = "附件：" + _格式化附件(附件) + ("（已领取）" if 已领 else "")
		_详情领取按钮.visible = not 已领
	else:
		_详情附件.text = ""
		_详情领取按钮.visible = false
	
	# 显示详情区域
	_详情区域.visible = true

# 关闭详情区域
func _on_关闭详情() -> void:
	_详情区域.visible = false
	_当前选中索引 = -1

# 详情区域领取按钮
func _on_详情领取() -> void:
	if _当前选中索引 < 0:
		return
	Game.领取邮件(_当前选中索引)
	refresh()
	# 刷新详情显示
	if _当前选中索引 >= 0 and _详情区域.visible:
		_显示详情(_当前选中索引)"""

if old_show_detail in content:
    content = content.replace(old_show_detail, new_show_detail)
    print("✅ _显示详情方法替换成功")
else:
    print("❌ 未找到_show_mail_detail方法")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n✅ page_mail.gd修改完成！")

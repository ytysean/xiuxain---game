# -*- coding: utf-8 -*-
"""
修复page_mail.gd中的两个问题：
1. 添加邮件详情显示功能（点击消息后显示详情弹窗）
2. 在全部已读、标记已读、领取邮件后调用红点刷新
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_mail.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 1. 修改_on_card_clicked方法，添加邮件详情显示 ==========
old_card_clicked = """func _on_card_clicked(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			Game.标记邮件已读(idx)
			refresh()"""

new_card_clicked = """func _on_card_clicked(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			Game.标记邮件已读(idx)
			refresh()
			# 刷新红点
			if RedDotManager != null and RedDotManager.has_method("刷新所有红点"):
				RedDotManager.刷新所有红点()
			# 显示邮件详情
			_show_mail_detail(idx)"""

if old_card_clicked in content:
    content = content.replace(old_card_clicked, new_card_clicked)
    print("✅ _on_card_clicked方法修改成功")
else:
    print("❌ 未找到_on_card_clicked方法")

# ========== 2. 修改_on_全部已读方法，添加红点刷新 ==========
old_all_read = """func _on_全部已读() -> void:
	Game.邮件全部已读()
	refresh()"""

new_all_read = """func _on_全部已读() -> void:
	Game.邮件全部已读()
	refresh()
	# 刷新红点
	if RedDotManager != null and RedDotManager.has_method("刷新所有红点"):
		RedDotManager.刷新所有红点()"""

if old_all_read in content:
    content = content.replace(old_all_read, new_all_read)
    print("✅ _on_全部已读方法修改成功")
else:
    print("❌ 未找到_on_全部已读方法")

# ========== 3. 修改_on_一键领取方法，添加红点刷新 ==========
old_claim_all = """func _on_一键领取() -> void:
	var 列表 = Game.取邮件列表()
	for i in range(列表.size()):
		var m = 列表[i]
		if not m.get("附件", {}).is_empty() and not bool(m.get("已领", false)):
			Game.领取邮件(i)
	refresh()
	邮件领取完成.emit()"""

new_claim_all = """func _on_一键领取() -> void:
	var 列表 = Game.取邮件列表()
	for i in range(列表.size()):
		var m = 列表[i]
		if not m.get("附件", {}).is_empty() and not bool(m.get("已领", false)):
			Game.领取邮件(i)
	refresh()
	邮件领取完成.emit()
	# 刷新红点
	if RedDotManager != null and RedDotManager.has_method("刷新所有红点"):
		RedDotManager.刷新所有红点()"""

if old_claim_all in content:
    content = content.replace(old_claim_all, new_claim_all)
    print("✅ _on_一键领取方法修改成功")
else:
    print("❌ 未找到_on_一键领取方法")

# ========== 4. 添加邮件详情显示方法 ==========
old_back = """func _on_back_pressed() -> void:
	返回主页.emit()"""

new_back = """func _on_back_pressed() -> void:
	返回主页.emit()

# 显示邮件详情弹窗
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
			if RedDotManager != null and RedDotManager.has_method("刷新所有红点"):
				RedDotManager.刷新所有红点()
			dialog.queue_free()
		)
		dialog.add_child(领取按钮)
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()"""

if old_back in content:
    content = content.replace(old_back, new_back)
    print("✅ 邮件详情显示方法添加成功")
else:
    print("❌ 未找到_on_back_pressed方法")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n✅ page_mail.gd修复完成！")

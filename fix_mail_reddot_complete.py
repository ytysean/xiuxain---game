# -*- coding: utf-8 -*-
"""
完整修复邮件系统的红点问题：
1. 在game_state.gd中添加邮件变动信号
2. 在邮件相关方法中发出信号
3. 在main.gd中连接信号来刷新红点
4. 修改page_mail.gd，移除对RedDotManager的错误引用
"""

import os

# ========== 1. 在game_state.gd中添加邮件变动信号 ==========
file_path1 = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"
with open(file_path1, 'r', encoding='utf-8') as f:
    content1 = f.read()

# 在成就更新信号后添加邮件变动信号
old_signal = """signal 成就更新
# ============ 殿阁被动·常驻乘区（阶：：占位殿阁被动功能）============"""

new_signal = """signal 成就更新
signal 邮件变动
# ============ 殿阁被动·常驻乘区（阶：：占位殿阁被动功能）============"""

if old_signal in content1:
    content1 = content1.replace(old_signal, new_signal)
    print("✅ 邮件变动信号添加成功")
else:
    print("❌ 未找到信号定义位置")

# 在标记邮件已读方法中发出信号
old_mark_read = """func 标记邮件已读(idx: int) -> void:

	if idx >= 0 and idx < 邮件列表.size():

		邮件列表[idx]["未读"] = false"""

new_mark_read = """func 标记邮件已读(idx: int) -> void:

	if idx >= 0 and idx < 邮件列表.size():

		邮件列表[idx]["未读"] = false
		邮件变动.emit()"""

if old_mark_read in content1:
    content1 = content1.replace(old_mark_read, new_mark_read)
    print("✅ 标记邮件已读方法中添加信号成功")
else:
    print("❌ 未找到标记邮件已读方法")

# 在邮件全部已读方法中发出信号
old_all_read = """func 邮件全部已读() -> void:

	for m in 邮件列表:

		m["未读"] = false"""

new_all_read = """func 邮件全部已读() -> void:

	for m in 邮件列表:

		m["未读"] = false
		邮件变动.emit()"""

if old_all_read in content1:
    content1 = content1.replace(old_all_read, new_all_read)
    print("✅ 邮件全部已读方法中添加信号成功")
else:
    print("❌ 未找到邮件全部已读方法")

# 在领取邮件方法中发出信号（在m["已领"] = true之后）
old_claim = """	m["已领"] = true
	m["未读"] = false
	return {"ok": true, "msg": "%s 附件：%s" % [str(m.get("标题", "")), "·".join(明细)], "明细": 明细}"""

new_claim = """	m["已领"] = true
	m["未读"] = false
	邮件变动.emit()
	return {"ok": true, "msg": "%s 附件：%s" % [str(m.get("标题", "")), "·".join(明细)], "明细": 明细}"""

if old_claim in content1:
    content1 = content1.replace(old_claim, new_claim)
    print("✅ 领取邮件方法中添加信号成功")
else:
    print("❌ 未找到领取邮件方法")

# 保存game_state.gd
with open(file_path1, 'w', encoding='utf-8') as f:
    f.write(content1)
print("✅ game_state.gd保存成功")

# ========== 2. 在main.gd中连接邮件变动信号 ==========
file_path2 = r"E:\Xiuxian\taixuanzongmenlu\main.gd"
with open(file_path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

# 在_初始化红点系统方法中添加邮件变动信号连接
old_connect = """		Game.弟子变动.connect(_刷新红点, CONNECT_DEFERRED)
		Game.新手目标更新.connect(_刷新红点, CONNECT_DEFERRED)
		Game.战报更新.connect(_刷新红点, CONNECT_DEFERRED)"""

new_connect = """		Game.弟子变动.connect(_刷新红点, CONNECT_DEFERRED)
		Game.新手目标更新.connect(_刷新红点, CONNECT_DEFERRED)
		Game.战报更新.connect(_刷新红点, CONNECT_DEFERRED)
		Game.邮件变动.connect(_刷新红点, CONNECT_DEFERRED)"""

if old_connect in content2:
    content2 = content2.replace(old_connect, new_connect)
    print("✅ main.gd中添加邮件变动信号连接成功")
else:
    print("❌ 未找到信号连接位置")

# 保存main.gd
with open(file_path2, 'w', encoding='utf-8') as f:
    f.write(content2)
print("✅ main.gd保存成功")

# ========== 3. 修改page_mail.gd，移除对RedDotManager的错误引用 ==========
file_path3 = r"E:\Xiuxian\taixuanzongmenlu\ui\page_mail.gd"
with open(file_path3, 'r', encoding='utf-8') as f:
    content3 = f.read()

# 移除_on_card_clicked中的红点刷新（因为现在通过信号自动刷新）
old_card_clicked = """func _on_card_clicked(event: InputEvent, idx: int) -> void:
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

new_card_clicked = """func _on_card_clicked(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			Game.标记邮件已读(idx)
			refresh()
			# 显示邮件详情（红点通过Game.邮件变动信号自动刷新）
			_show_mail_detail(idx)"""

if old_card_clicked in content3:
    content3 = content3.replace(old_card_clicked, new_card_clicked)
    print("✅ _on_card_clicked中移除红点刷新成功")
else:
    print("❌ 未找到_on_card_clicked方法")

# 移除_on_全部已读中的红点刷新
old_all_read_ui = """func _on_全部已读() -> void:
	Game.邮件全部已读()
	refresh()
	# 刷新红点
	if RedDotManager != null and RedDotManager.has_method("刷新所有红点"):
		RedDotManager.刷新所有红点()"""

new_all_read_ui = """func _on_全部已读() -> void:
	Game.邮件全部已读()
	refresh()
	# 红点通过Game.邮件变动信号自动刷新"""

if old_all_read_ui in content3:
    content3 = content3.replace(old_all_read_ui, new_all_read_ui)
    print("✅ _on_全部已读中移除红点刷新成功")
else:
    print("❌ 未找到_on_全部已读方法")

# 移除_on_一键领取中的红点刷新
old_claim_all_ui = """func _on_一键领取() -> void:
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

new_claim_all_ui = """func _on_一键领取() -> void:
	var 列表 = Game.取邮件列表()
	for i in range(列表.size()):
		var m = 列表[i]
		if not m.get("附件", {}).is_empty() and not bool(m.get("已领", false)):
			Game.领取邮件(i)
	refresh()
	邮件领取完成.emit()
	# 红点通过Game.邮件变动信号自动刷新"""

if old_claim_all_ui in content3:
    content3 = content3.replace(old_claim_all_ui, new_claim_all_ui)
    print("✅ _on_一键领取中移除红点刷新成功")
else:
    print("❌ 未找到_on_一键领取方法")

# 移除_show_mail_detail中的红点刷新
old_detail_claim = """		领取按钮.pressed.connect(func():
			Game.领取邮件(idx)
			refresh()
			if RedDotManager != null and RedDotManager.has_method("刷新所有红点"):
				RedDotManager.刷新所有红点()
			dialog.queue_free()
		)"""

new_detail_claim = """		领取按钮.pressed.connect(func():
			Game.领取邮件(idx)
			refresh()
			# 红点通过Game.邮件变动信号自动刷新
			dialog.queue_free()
		)"""

if old_detail_claim in content3:
    content3 = content3.replace(old_detail_claim, new_detail_claim)
    print("✅ _show_mail_detail中移除红点刷新成功")
else:
    print("❌ 未找到_show_mail_detail中的领取按钮")

# 保存page_mail.gd
with open(file_path3, 'w', encoding='utf-8') as f:
    f.write(content3)
print("✅ page_mail.gd保存成功")

print("\n🎉 邮件系统红点问题完整修复完成！")

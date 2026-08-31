# -*- coding: utf-8 -*-
"""
修复灵讯系统的三个问题：
1. 不管点哪一条灵讯消息，详情始终显示第一排
2. 再次登录又出现未读和未领取（存档问题）
3. 碎片宝箱图标还是没有显示
"""

import os

# ========== 1. 修复page_mail.gd中的详情显示问题 ==========
file_path1 = r"E:\Xiuxian\taixuanzongmenlu\ui\page_mail.gd"
with open(file_path1, 'r', encoding='utf-8') as f:
    content1 = f.read()

# 修改_on_card_clicked方法，先显示详情，再延迟刷新
old_card_clicked = """func _on_card_clicked(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			Game.标记邮件已读(idx)
			refresh()
			# 显示邮件详情（页面内显示，参考魔兽世界风格）
			_显示详情(idx)"""

new_card_clicked = """func _on_card_clicked(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# 先标记已读并显示详情，再延迟刷新列表，避免索引丢失
			Game.标记邮件已读(idx)
			_显示详情(idx)
			refresh.call_deferred()"""

if old_card_clicked in content1:
    content1 = content1.replace(old_card_clicked, new_card_clicked)
    print("✅ _on_card_clicked方法修改成功")
else:
    print("❌ 未找到_on_card_clicked方法")

# 保存page_mail.gd
with open(file_path1, 'w', encoding='utf-8') as f:
    f.write(content1)
print("✅ page_mail.gd保存成功")

# ========== 2. 检查game_state.gd中的存档保存和加载 ==========
file_path2 = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"
with open(file_path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

# 检查邮件列表是否在存档保存和加载中
if '邮件列表' in content2:
    print("✅ game_state.gd中包含邮件列表变量")
else:
    print("❌ game_state.gd中不包含邮件列表变量")

# 搜索存档保存相关代码
import re
save_matches = re.findall(r'邮件列表.*=.*', content2)
print(f"找到 {len(save_matches)} 处邮件列表赋值")
for m in save_matches[:5]:
    print(f"  - {m[:80]}")

print("\n✅ 检查完成")

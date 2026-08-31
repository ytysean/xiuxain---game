# -*- coding: utf-8 -*-
"""
修改sect_home_page.gd：
在_ready方法中添加邮件变动信号连接，自动刷新灵讯红点
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\sect_home_page.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 修改_ready方法
old_ready = """func _ready() -> void:
	_build()
	refresh()"""

new_ready = """func _ready() -> void:
	_build()
	refresh()
	# 连接邮件变动信号，自动刷新灵讯红点
	if Game != null and Game.has_signal("邮件变动"):
		Game.邮件变动.connect(_refresh_red_dots, CONNECT_DEFERRED)"""

if old_ready in content:
    content = content.replace(old_ready, new_ready)
    print("✅ _ready方法修改成功，已添加邮件变动信号连接")
else:
    print("❌ 未找到_ready方法")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

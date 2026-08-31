# -*- coding: utf-8 -*-
"""
修复game_state.gd中的邮件存档问题：
在标记已读、全部已读、领取邮件方法中添加save_game()调用
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 在标记邮件已读方法中添加save_game()
old_mark_read = """func 标记邮件已读(idx: int) -> void:

	if idx >= 0 and idx < 邮件列表.size():

		邮件列表[idx]["未读"] = false
		邮件变动.emit()"""

new_mark_read = """func 标记邮件已读(idx: int) -> void:

	if idx >= 0 and idx < 邮件列表.size():

		邮件列表[idx]["未读"] = false
		邮件变动.emit()
		if has_method("save_game"):
			save_game()"""

if old_mark_read in content:
    content = content.replace(old_mark_read, new_mark_read)
    print("✅ 标记邮件已读方法中添加save_game()成功")
else:
    print("❌ 未找到标记邮件已读方法")

# 2. 在邮件全部已读方法中添加save_game()
old_all_read = """func 邮件全部已读() -> void:

	for m in 邮件列表:

		m["未读"] = false
		邮件变动.emit()"""

new_all_read = """func 邮件全部已读() -> void:

	for m in 邮件列表:

		m["未读"] = false
	邮件变动.emit()
	if has_method("save_game"):
		save_game()"""

if old_all_read in content:
    content = content.replace(old_all_read, new_all_read)
    print("✅ 邮件全部已读方法中添加save_game()成功")
else:
    print("❌ 未找到邮件全部已读方法")

# 3. 在领取邮件方法中添加save_game()（在return之前）
old_claim = """	m["已领"] = true
	m["未读"] = false
	邮件变动.emit()
	return {"ok": true, "msg": "%s 附件：%s" % [str(m.get("标题", "")), "·".join(明细)], "明细": 明细}"""

new_claim = """	m["已领"] = true
	m["未读"] = false
	邮件变动.emit()
	if has_method("save_game"):
		save_game()
	return {"ok": true, "msg": "%s 附件：%s" % [str(m.get("标题", "")), "·".join(明细)], "明细": 明细}"""

if old_claim in content:
    content = content.replace(old_claim, new_claim)
    print("✅ 领取邮件方法中添加save_game()成功")
else:
    print("❌ 未找到领取邮件方法")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n✅ game_state.gd修复完成！")

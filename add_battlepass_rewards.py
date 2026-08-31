# -*- coding: utf-8 -*-
"""
修改game_state.gd的战令系统，添加碎片和宝箱的奖励
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 修改战令系统奖励发放 ==========
# 找到皮肤奖励之后，已领.append(等级)之前的位置，添加碎片和宝箱奖励
old_battlepass = """	if 奖.has("皮肤"):

		var skin_id: String = str(奖["皮肤"])
		当前皮肤 = skin_id
		明细.append("外观·%s" % skin_id)
	已领.append(等级)
	return {"ok": true, "msg": "%s Lv.%d 奖励：%s" % [轨道, 等级, "·".join(明细)]}"""

new_battlepass = """	if 奖.has("皮肤"):

		var skin_id: String = str(奖["皮肤"])
		当前皮肤 = skin_id
		明细.append("外观·%s" % skin_id)
	# 碎片奖励（frag_开头的键）
	for key in 奖.keys():
		if str(key).begins_with("frag_"):
			var frag_id: String = str(key)
			var frag_count: int = int(奖[key])
			if frag_count > 0:
				添加碎片(frag_id, frag_count)
				明细.append("%s+%d" % [frag_id, frag_count])
	# 宝箱奖励（chest_开头的键）
	for key in 奖.keys():
		if str(key).begins_with("chest_"):
			var chest_id: String = str(key)
			var chest_count: int = int(奖[key])
			if chest_count > 0:
				添加宝箱(chest_id, chest_count)
				明细.append("%s+%d" % [chest_id, chest_count])
	已领.append(等级)
	return {"ok": true, "msg": "%s Lv.%d 奖励：%s" % [轨道, 等级, "·".join(明细)]}"""

if old_battlepass in content:
    content = content.replace(old_battlepass, new_battlepass)
    print("✅ 战令系统修改成功")
else:
    print("❌ 未找到战令系统的目标代码")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

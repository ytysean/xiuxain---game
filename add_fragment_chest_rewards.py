# -*- coding: utf-8 -*-
"""
修改game_state.gd，添加碎片和宝箱的奖励获取途径：
1. 签到系统（日供）：日常签到随机奖励 + 连续签到特殊节点奖励
2. 成就系统：稀有及以上成就额外奖励
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 1. 修改签到系统（日供）==========
# 找到纪事联动部分，添加碎片和宝箱奖励
old_daily = """	# 纪事联动
	if 连续理事天数 == 7:

		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "小周天赐福", "文案": 文案表["chronicle_seven_day_blessing"]})
	elif 连续理事天数 == 30:

		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "月度道统厚礼", "文案": 文案表["chronicle_monthly_tao"]})
	else:

		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "庶务", "名称": "受领日供", "文案": 文案表["chronicle_daily_tribute"]})
	return {"ok": true, "msg": msg}"""

new_daily = """	# 纪事联动
	if 连续理事天数 == 7:
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "小周天赐福", "文案": 文案表["chronicle_seven_day_blessing"]})
		# 连续签到7天奖励：稀有宝箱×1 + 灵品装备碎片×3
		添加宝箱("chest_rare", 1)
		添加碎片("frag_equip_rare", 3)
		msg += "，连续7天奖励：稀有宝箱+1，灵品装备碎片+3"
	elif 连续理事天数 == 30:
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "月度道统厚礼", "文案": 文案表["chronicle_monthly_tao"]})
		# 连续签到30天奖励：史诗宝箱×1 + 宝品装备碎片×5 + 灵品功法碎片×3
		添加宝箱("chest_epic", 1)
		添加碎片("frag_equip_epic", 5)
		添加碎片("frag_gongfa_rare", 3)
		msg += "，连续30天奖励：史诗宝箱+1，宝品装备碎片+5，灵品功法碎片+3"
	elif 连续理事天数 == 100:
		# 连续签到100天奖励：传说宝箱×1 + 王品装备碎片×5
		添加宝箱("chest_legendary", 1)
		添加碎片("frag_equip_legendary", 5)
		msg += "，连续100天奖励：传说宝箱+1，王品装备碎片+5"
	else:
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "庶务", "名称": "受领日供", "文案": 文案表["chronicle_daily_tribute"]})
		# 日常签到随机奖励：10%概率获得凡品装备碎片，5%概率获得普通宝箱
		if randf() < 0.10:
			添加碎片("frag_equip_common", 1)
			msg += "，凡品装备碎片+1"
		if randf() < 0.05:
			添加宝箱("chest_common", 1)
			msg += "，普通宝箱+1"
	return {"ok": true, "msg": msg}"""

if old_daily in content:
    content = content.replace(old_daily, new_daily)
    print("✅ 签到系统修改成功")
else:
    print("❌ 未找到签到系统的目标代码")

# ========== 2. 修改成就系统 ==========
# 找到稀有及以上成就的纪事联动部分，添加碎片和宝箱奖励
old_achievement = """	# 稀有及以上：宗门纪事 category="宗门大事件（拍板结论：与里程碑联动同构：
	var grade: String = a.get("grade", "")
	if grade == "稀有" or grade == "史诗" or grade == "传说":

		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": grade, "名称": a.get("ach_name", ""),
			"文案": "宗门达成%s】，道统更进一步" % a.get("ach_name", ""),
			"category": "宗门大事件"})
	成就更新.emit()"""

new_achievement = """	# 稀有及以上成就额外奖励：碎片和宝箱
	var grade: String = a.get("grade", "")
	if grade == "稀有":
		# 稀有成就：普通宝箱×1 + 凡品装备碎片×3
		添加宝箱("chest_common", 1)
		添加碎片("frag_equip_common", 3)
	elif grade == "史诗":
		# 史诗成就：稀有宝箱×1 + 灵品装备碎片×3
		添加宝箱("chest_rare", 1)
		添加碎片("frag_equip_rare", 3)
	elif grade == "传说":
		# 传说成就：史诗宝箱×1 + 宝品装备碎片×3 + 灵品功法碎片×2
		添加宝箱("chest_epic", 1)
		添加碎片("frag_equip_epic", 3)
		添加碎片("frag_gongfa_rare", 2)
	# 稀有及以上：宗门纪事 category="宗门大事件（拍板结论：与里程碑联动同构：
	if grade == "稀有" or grade == "史诗" or grade == "传说":
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": grade, "名称": a.get("ach_name", ""),
			"文案": "宗门达成%s】，道统更进一步" % a.get("ach_name", ""),
			"category": "宗门大事件"})
	成就更新.emit()"""

if old_achievement in content:
    content = content.replace(old_achievement, new_achievement)
    print("✅ 成就系统修改成功")
else:
    print("❌ 未找到成就系统的目标代码")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

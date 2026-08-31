# -*- coding: utf-8 -*-
"""
完善探索系统和社交系统，添加更多功能
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 在探索系统中添加所有探索事件列表和一键探索功能
old_explore_func = '''# 触发随机探索事件
func 触发探索事件() -> Dictionary:'''

new_explore_func = '''# 获取所有探索事件列表
func 获取所有探索事件列表() -> Array:
	_加载探索事件配置()
	var 事件列表 = []
	for 事件 in 探索事件配置:
		事件列表.append({
			"event_id": 事件.get("event_id", ""),
			"name": 事件.get("name", ""),
			"description": 事件.get("description", ""),
			"branches_count": 事件.get("branches", []).size(),
		})
	return 事件列表

# 一键探索（自动触发探索事件并选择第一个选项）
func 一键探索() -> Dictionary:
	var 结果 = 触发探索事件()
	if not 结果.get("成功", false):
		return 结果
	var 事件 = 结果.get("事件", {})
	var 分支 = 事件.get("branches", [])
	if 分支.is_empty():
		return {"成功": false, "原因": "事件没有分支选项"}
	# 自动选择第一个安全选项
	var 选择 = 分支[0]
	for b in 分支:
		if b.get("result", "") == "safe":
			选择 = b
			break
	# 处理选择结果
	var 奖励 = 选择.get("reward", {})
	if 选择.get("result", "") == "risk":
		var 成功率 = 选择.get("success_rate", 0.5)
		if randf() < 成功率:
			奖励 = 选择.get("success_reward", {})
		else:
			奖励 = 选择.get("fail_penalty", {})
	# 应用奖励
	for key in 奖励.keys():
		var 值 = 奖励[key]
		if key == "灵石":
			灵石 += int(值)
		elif key == "悟道点":
			悟道点 += int(值)
		elif key == "灵气":
			灵气 += int(值)
		elif key == "体力":
			pass  # 体力系统暂未实现
	# 成就统计：累计探索次数自增
	累计探索次数 += 1
	_复检成就()
	添加纪事("探索", "一键探索", "探索了%s，选择了%s" % [事件.get("name", ""), 选择.get("choice", "")], 1)
	return {"成功": true, "事件": 事件, "选择": 选择, "奖励": 奖励, "消息": "探索%s成功" % 事件.get("name", "")}

# 获取探索统计
func 获取探索统计() -> Dictionary:
	return {
		"累计探索次数": 累计探索次数,
		"探索事件总数": 探索事件配置.size(),
	}

# 触发随机探索事件
func 触发探索事件() -> Dictionary:'''

if old_explore_func in content:
    content = content.replace(old_explore_func, new_explore_func)
    print("✅ 探索系统完善成功（添加所有探索事件列表、一键探索、探索统计）")
else:
    print("❌ 未找到触发探索事件函数")

# 2. 在社交系统中添加所有道友列表和一键送礼功能
old_social_func = '''# 与道友论道（获得悟道点）
func 与道友论道(名字: String) -> Dictionary:'''

new_social_func = '''# 获取所有道友列表（包含详细信息）
func 获取所有道友列表() -> Array:
	var 道友列表 = []
	for 道友 in _道友列表:
		道友列表.append({
			"name": 道友.get("name", ""),
			"status": 道友.get("status", ""),
			"好感度": 道友.get("好感度", 50),
			"论道次数": 道友.get("论道次数", 0),
			"送礼次数": 道友.get("送礼次数", 0),
		})
	return 道友列表

# 给道友送礼（提升好感度）
func 给道友送礼(名字: String, 礼物价值: int = 100) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name", "")) == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	if 灵石 < 礼物价值:
		return {"成功": false, "原因": "灵石不足（需要%d）" % 礼物价值}
	灵石 -= 礼物价值
	# 提升好感度（根据礼物价值）
	var 好感度提升 = int(礼物价值 / 10)
	道友["好感度"] = int(道友.get("好感度", 50)) + 好感度提升
	道友["送礼次数"] = int(道友.get("送礼次数", 0)) + 1
	# 好感度上限100
	if int(道友["好感度"]) > 100:
		道友["好感度"] = 100
	添加纪事("社交", "道友送礼", "给%s送礼，花费%d灵石，好感度+%d" % [名字, 礼物价值, 好感度提升], 1)
	return {"成功": true, "道友": 道友, "好感度提升": 好感度提升, "消息": "给%s送礼成功" % 名字}

# 一键给所有道友送礼
func 一键给所有道友送礼(礼物价值: int = 100) -> Dictionary:
	var 成功数量 = 0
	var 失败数量 = 0
	var 送礼列表 = []
	for 道友 in _道友列表:
		var 名字 = str(道友.get("name", ""))
		var 结果 = 给道友送礼(名字, 礼物价值)
		送礼列表.append(结果)
		if 结果.get("成功", false):
			成功数量 += 1
		else:
			失败数量 += 1
	return {"成功": 成功数量 > 0, "成功数量": 成功数量, "失败数量": 失败数量, "送礼列表": 送礼列表, "消息": "一键送礼完成，成功%d人，失败%d人" % [成功数量, 失败数量]}

# 获取社交统计
func 获取社交统计() -> Dictionary:
	var 总论道次数 = 0
	var 总送礼次数 = 0
	var 平均好感度 = 0
	for 道友 in _道友列表:
		总论道次数 += int(道友.get("论道次数", 0))
		总送礼次数 += int(道友.get("送礼次数", 0))
		平均好感度 += int(道友.get("好感度", 50))
	if _道友列表.size() > 0:
		平均好感度 = int(平均好感度 / _道友列表.size())
	return {
		"道友总数": _道友列表.size(),
		"总论道次数": 总论道次数,
		"总送礼次数": 总送礼次数,
		"平均好感度": 平均好感度,
	}

# 与道友论道（获得悟道点）
func 与道友论道(名字: String) -> Dictionary:'''

if old_social_func in content:
    content = content.replace(old_social_func, new_social_func)
    print("✅ 社交系统完善成功（添加所有道友列表、给道友送礼、一键送礼、社交统计）")
else:
    print("❌ 未找到与道友论道函数")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 探索系统和社交系统完善完成！")
print("\n📋 已完善的功能：")
print("  1. 探索系统：")
print("     - 添加获取所有探索事件列表功能")
print("     - 添加一键探索功能（自动触发事件并选择安全选项）")
print("     - 添加获取探索统计功能")
print("  2. 社交系统：")
print("     - 添加获取所有道友列表功能（包含详细信息）")
print("     - 添加给道友送礼功能（提升好感度）")
print("     - 添加一键给所有道友送礼功能")
print("     - 添加获取社交统计功能")
print("\n📌 探索系统说明：")
print("  - 所有探索事件列表：返回5个内置探索事件的信息")
print("  - 一键探索：自动触发探索事件，优先选择安全选项")
print("  - 探索统计：累计探索次数、探索事件总数")
print("\n📌 社交系统说明：")
print("  - 所有道友列表：返回所有道友的详细信息（好感度、论道次数、送礼次数）")
print("  - 给道友送礼：花费灵石提升好感度（每10灵石+1好感度）")
print("  - 一键送礼：给所有道友送礼")
print("  - 社交统计：道友总数、总论道次数、总送礼次数、平均好感度")
print("  - 好感度上限：100")

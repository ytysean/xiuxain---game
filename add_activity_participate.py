# -*- coding: utf-8 -*-
"""
在game_state.gd中添加参与活动函数
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 在获取所有活动冷却状态函数后面添加参与活动函数
old_text = '''# 获取所有活动冷却状态
func 获取所有活动冷却状态() -> Array:
	var 冷却状态列表 = []
	var 活动列表 = 获取所有活动列表()
	for 活动 in 活动列表:
		var 冷却状态 = 获取活动冷却状态(活动.get("活动ID", ""))
		冷却状态列表.append(冷却状态)
	return 冷却状态列表

# 一键参与所有可参与活动'''

new_text = '''# 获取所有活动冷却状态
func 获取所有活动冷却状态() -> Array:
	var 冷却状态列表 = []
	var 活动列表 = 获取所有活动列表()
	for 活动 in 活动列表:
		var 冷却状态 = 获取活动冷却状态(活动.get("活动ID", ""))
		冷却状态列表.append(冷却状态)
	return 冷却状态列表

# 参与单个活动（活动中心页面对接）
func 参与活动(活动ID: String) -> Dictionary:
	var 冷却状态 = 获取活动冷却状态(活动ID)
	if not 冷却状态.get("可参与", false):
		return {"成功": false, "原因": "活动冷却中，暂不可参与"}
	# 根据活动ID执行对应操作
	match 活动ID:
		"daily_checkin":
			# 每日朝贡
			if 日供_今日可领():
				var 结果 = 领取日供()
				if 结果.get("ok", false):
					return {"成功": true, "活动": "每日朝贡", "消息": "朝贡成功，获得奖励"}
				else:
					return {"成功": false, "原因": "朝贡失败：%s" % 结果.get("原因", "未知")}
			else:
				return {"成功": false, "原因": "今日已朝贡"}
		"explore_event":
			# 云游四方
			var 结果 = 一键探索()
			if 结果.get("成功", false):
				return {"成功": true, "活动": "云游四方", "消息": "探索成功，获得机缘"}
			else:
				return {"成功": false, "原因": "探索失败：%s" % 结果.get("原因", "未知")}
		"faction_activity":
			# 宗门历练（简化：显示提示）
			return {"成功": true, "活动": "宗门历练", "消息": "请前往历练页面参与"}
		"faction_trial":
			# 秘境试炼（简化：显示提示）
			return {"成功": true, "活动": "秘境试炼", "消息": "请前往历练页面参与"}
		"alchemy_session":
			# 丹道大会（简化：显示提示）
			return {"成功": true, "活动": "丹道大会", "消息": "请前往丹方页面参与"}
		"artifact_forge":
			# 器道争锋（简化：显示提示）
			return {"成功": true, "活动": "器道争锋", "消息": "请前往装备图纸页面参与"}
		"zongmen_battle":
			# 宗门大战（简化：显示提示）
			return {"成功": true, "活动": "宗门大战", "消息": "请前往宗门战页面参与"}
		"faction_reputation":
			# 声望任务（简化：显示提示）
			return {"成功": true, "活动": "声望任务", "消息": "请前往阵营声望页面参与"}
		_:
			return {"成功": false, "原因": "未知活动：%s" % 活动ID}

# 一键参与所有可参与活动'''

if old_text in content:
    content = content.replace(old_text, new_text)
    print("✅ 添加参与活动函数成功")
else:
    print("❌ 未找到目标位置")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 参与活动函数添加完成！")

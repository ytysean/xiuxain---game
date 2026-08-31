# -*- coding: utf-8 -*-
"""
完善VIP系统和月卡系统，添加更多功能
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 在VIP系统中添加所有VIP等级列表和VIP统计功能
old_vip_func = '''# ===== 付费礼包系统 =====
var 已购买礼包: Dictionary = {}  # 礼包ID -> 购买时间'''

new_vip_func = '''# 获取所有VIP等级列表
func 获取所有VIP等级列表() -> Array:
	var 等级列表 = []
	for i in range(VIP_MAX_LEVEL + 1):
		var 所需经验 = VIP_EXP_THRESHOLDS[i] if i < VIP_EXP_THRESHOLDS.size() else -1
		var 权益 = []
		if i >= 1:
			权益.append("背包扩容")
			权益.append("战斗2倍率")
		if i >= 2:
			权益.append("招募额外次数")
		if i >= 3:
			权益.append("每日免费礼包")
			权益.append("跳过战斗")
		if i >= 4:
			权益.append("专属头像框")
		if i >= 5:
			权益.append("战斗3倍率")
			权益.append("离线24小时")
		if i >= 6:
			权益.append("专属皮肤")
		等级列表.append({
			"等级": i,
			"所需经验": 所需经验,
			"权益": 权益,
			"已达成": vip_level >= i,
		})
	return 等级列表

# 获取VIP统计
func 获取VIP统计() -> Dictionary:
	var 下一级经验 = VIP_EXP_THRESHOLDS[min(vip_level + 1, VIP_MAX_LEVEL)] if vip_level < VIP_MAX_LEVEL else -1
	var 升级进度 = 0.0
	if 下一级经验 > 0:
		var 当前级经验 = VIP_EXP_THRESHOLDS[vip_level] if vip_level < VIP_EXP_THRESHOLDS.size() else 0
		升级进度 = float(vip_exp - 当前级经验) / float(下一级经验 - 当前级经验)
	return {
		"当前等级": vip_level,
		"当前经验": vip_exp,
		"下一级经验": 下一级经验,
		"升级进度": 升级进度,
		"最高等级": VIP_MAX_LEVEL,
		"战斗倍率": get_battle_speed_multiplier(),
		"已解锁权益数": get_vip_benefits().get("unlocked_features", []).size(),
	}

# 获取VIP每日奖励
func 获取VIP每日奖励() -> Dictionary:
	var 奖励 = {"灵石": 0, "灵气": 0, "悟道点": 0}
	if vip_level >= 1:
		奖励["灵石"] += 100
	if vip_level >= 2:
		奖励["灵气"] += 50
	if vip_level >= 3:
		奖励["悟道点"] += 10
	if vip_level >= 5:
		奖励["灵石"] += 200
	if vip_level >= 8:
		奖励["灵气"] += 100
	return 奖励

# 领取VIP每日奖励
func 领取VIP每日奖励() -> Dictionary:
	var 最后领取日 = vip_daily_reward_day if "vip_daily_reward_day" in self else -1
	if 最后领取日 == 累计游戏日:
		return {"成功": false, "原因": "今日已领取"}
	var 奖励 = 获取VIP每日奖励()
	灵石 += 奖励.get("灵石", 0)
	灵气 += 奖励.get("灵气", 0)
	悟道点 += 奖励.get("悟道点", 0)
	vip_daily_reward_day = 累计游戏日
	添加纪事("庶务", "VIP每日奖励", "领取VIP%d每日奖励：灵石+%d，灵气+%d，悟道点+%d" % [vip_level, 奖励.get("灵石", 0), 奖励.get("灵气", 0), 奖励.get("悟道点", 0)], 1)
	return {"成功": true, "奖励": 奖励, "消息": "领取VIP每日奖励成功"}

# ===== 付费礼包系统 =====
var 已购买礼包: Dictionary = {}  # 礼包ID -> 购买时间
var vip_daily_reward_day: int = -1  # VIP每日奖励最后领取日'''

if old_vip_func in content:
    content = content.replace(old_vip_func, new_vip_func)
    print("✅ VIP系统完善成功（添加所有VIP等级列表、VIP统计、VIP每日奖励）")
else:
    print("❌ 未找到付费礼包系统注释")

# 2. 在月卡系统中添加所有卡类型列表和卡状态统计功能
old_card_func = '''# 获取特权加成
func 获取特权加成() -> Dictionary:'''

new_card_func = '''# 获取所有卡类型列表
func 获取所有卡类型列表() -> Array:
	return [
		{
			"卡类型": "月卡",
			"名称": "清修卡",
			"价格": 30,
			"天数": 30,
			"描述": "每日仙玉+离线+20%+历练+1+一键收取",
			"权益": ["离线收益加成20%", "额外历练次数+1", "一键收取", "每日仙玉奖励"],
			"是否有效": 月卡有效(),
			"到期日": 月卡到期日,
			"剩余天数": max(0, 月卡到期日 - 累计游戏日) if 月卡到期日 >= 0 else 0,
		},
		{
			"卡类型": "季卡",
			"名称": "悟道卡",
			"价格": 98,
			"天数": 90,
			"描述": "月卡权益+炼制加成30%+商队收益+15%+专属头像框",
			"权益": ["月卡全部权益", "炼制加成30%", "商队收益加成15%", "专属头像框"],
			"是否有效": 季卡有效(),
			"到期日": 季卡到期日,
			"剩余天数": max(0, 季卡到期日 - 累计游戏日) if 季卡到期日 >= 0 else 0,
		},
		{
			"卡类型": "永久卡",
			"名称": "道统卡",
			"价格": 298,
			"天数": -1,
			"描述": "季卡权益+永久皮肤+终身日供翻倍+离线上限24小时",
			"权益": ["季卡全部权益", "永久皮肤", "终身日供翻倍", "离线上限24小时"],
			"是否有效": 永久卡有效(),
			"到期日": -1,
			"剩余天数": -1,
		},
	]

# 获取卡状态统计
func 获取卡状态统计() -> Dictionary:
	return {
		"月卡有效": 月卡有效(),
		"季卡有效": 季卡有效(),
		"永久卡有效": 永久卡有效(),
		"月卡剩余天数": max(0, 月卡到期日 - 累计游戏日) if 月卡到期日 >= 0 else 0,
		"季卡剩余天数": max(0, 季卡到期日 - 累计游戏日) if 季卡到期日 >= 0 else 0,
		"最高特权": "永久卡" if 永久卡有效() else ("季卡" if 季卡有效() else ("月卡" if 月卡有效() else "无")),
	}

# 获取每日卡奖励
func 获取每日卡奖励() -> Dictionary:
	var 奖励 = {"仙玉_绑定": 0, "灵石": 0, "灵气": 0}
	if 月卡有效():
		奖励["仙玉_绑定"] += 30
		奖励["灵石"] += 200
	if 季卡有效():
		奖励["仙玉_绑定"] += 50
		奖励["灵气"] += 100
	if 永久卡有效():
		奖励["仙玉_绑定"] += 100
		奖励["灵石"] += 500
	return 奖励

# 领取每日卡奖励
func 领取每日卡奖励() -> Dictionary:
	var 最后领取日 = card_daily_reward_day if "card_daily_reward_day" in self else -1
	if 最后领取日 == 累计游戏日:
		return {"成功": false, "原因": "今日已领取"}
	if not 月卡有效() and not 季卡有效() and not 永久卡有效():
		return {"成功": false, "原因": "没有有效的卡"}
	var 奖励 = 获取每日卡奖励()
	仙玉_绑定 += 奖励.get("仙玉_绑定", 0)
	灵石 += 奖励.get("灵石", 0)
	灵气 += 奖励.get("灵气", 0)
	card_daily_reward_day = 累计游戏日
	添加纪事("庶务", "每日卡奖励", "领取每日卡奖励：仙玉+%d，灵石+%d，灵气+%d" % [奖励.get("仙玉_绑定", 0), 奖励.get("灵石", 0), 奖励.get("灵气", 0)], 1)
	return {"成功": true, "奖励": 奖励, "消息": "领取每日卡奖励成功"}

var card_daily_reward_day: int = -1  # 每日卡奖励最后领取日

# 获取特权加成
func 获取特权加成() -> Dictionary:'''

if old_card_func in content:
    content = content.replace(old_card_func, new_card_func)
    print("✅ 月卡系统完善成功（添加所有卡类型列表、卡状态统计、每日卡奖励）")
else:
    print("❌ 未找到获取特权加成函数")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 VIP系统和月卡系统完善完成！")
print("\n📋 已完善的功能：")
print("  1. VIP系统：")
print("     - 添加获取所有VIP等级列表功能（0-10级，包含权益）")
print("     - 添加获取VIP统计功能（当前等级、经验、升级进度）")
print("     - 添加获取VIP每日奖励功能")
print("     - 添加领取VIP每日奖励功能")
print("  2. 月卡系统：")
print("     - 添加获取所有卡类型列表功能（月卡、季卡、永久卡）")
print("     - 添加获取卡状态统计功能")
print("     - 添加获取每日卡奖励功能")
print("     - 添加领取每日卡奖励功能")
print("\n📌 VIP系统说明：")
print("  - VIP等级：0-10级")
print("  - VIP经验阈值：0, 100, 300, 600, 1000, 2000, 3500, 5000, 8000, 12000")
print("  - VIP权益：背包扩容、招募额外次数、每日免费礼包、战斗2/3倍率、跳过战斗、专属头像框、专属皮肤、离线24小时")
print("  - VIP每日奖励：根据等级发放灵石、灵气、悟道点")
print("\n📌 月卡系统说明：")
print("  - 月卡（清修卡）：30元，30天，离线收益+20%，额外历练+1，一键收取")
print("  - 季卡（悟道卡）：98元，90天，月卡权益+炼制+30%+商队收益+15%+专属头像框")
print("  - 永久卡（道统卡）：298元，永久，季卡权益+永久皮肤+日供翻倍+离线24小时")
print("  - 每日卡奖励：根据卡类型发放仙玉、灵石、灵气")

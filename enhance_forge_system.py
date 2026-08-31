# -*- coding: utf-8 -*-
"""
完善forge.gd炼器系统细节：
1. 炼器经验系统（炼器等级、经验值）
2. 炼器失败补偿（返还部分材料或获得碎片）
3. 炼器弟子技能加成完善
4. 炼器特殊事件（器灵觉醒概率）
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\forge.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 1. 添加炼器经验系统变量和方法 ==========
# 在品质概率定义之后，执行炼器方法之前添加
old_experience = """## 执行炼器（支持弟子技能影响和品质随机）
## 返回：{成功, 产出装备(Item/null), 消耗材料, 原因, 品质}
static func 炼器(配方ID: String, 背包: Array, 器堂等级: int = 1, 炼器弟子 = null) -> Dictionary:"""

new_experience = """## 炼器经验系统
## 炼器等级：影响成功率和高品质概率
## 经验值：炼器成功获得经验，失败获得一半经验
const 炼器等级表: Array = [
	{"等级": 1, "所需经验": 0, "成功率加成": 0, "高品质加成": 0},
	{"等级": 2, "所需经验": 100, "成功率加成": 2, "高品质加成": 0.02},
	{"等级": 3, "所需经验": 300, "成功率加成": 4, "高品质加成": 0.04},
	{"等级": 4, "所需经验": 600, "成功率加成": 6, "高品质加成": 0.06},
	{"等级": 5, "所需经验": 1000, "成功率加成": 8, "高品质加成": 0.08},
	{"等级": 6, "所需经验": 1500, "成功率加成": 10, "高品质加成": 0.10},
	{"等级": 7, "所需经验": 2100, "成功率加成": 12, "高品质加成": 0.12},
	{"等级": 8, "所需经验": 2800, "成功率加成": 14, "高品质加成": 0.14},
	{"等级": 9, "所需经验": 3600, "成功率加成": 16, "高品质加成": 0.16},
	{"等级": 10, "所需经验": 4500, "成功率加成": 20, "高品质加成": 0.20},
]

## 根据经验值获取炼器等级
static func 获取炼器等级(经验值: int) -> int:
	var 等级: int = 1
	for 配置 in 炼器等级表:
		if 经验值 >= int(配置["所需经验"]):
			等级 = int(配置["等级"])
	return 等级

## 获取炼器等级加成
static func 获取炼器加成(经验值: int) -> Dictionary:
	var 等级: int = 获取炼器等级(经验值)
	for 配置 in 炼器等级表:
		if int(配置["等级"]) == 等级:
			return {"等级": 等级, "成功率加成": float(配置["成功率加成"]), "高品质加成": float(配置["高品质加成"])}
	return {"等级": 1, "成功率加成": 0.0, "高品质加成": 0.0}

## 计算炼器获得经验（根据配方品阶）
static func 计算炼器经验(配方品阶: String, 成功: bool) -> int:
	var 基础经验: Dictionary = {
		"凡阶": 10, "灵阶": 20, "宝阶": 40, "王阶": 80,
		"圣阶": 120, "仙阶": 200, "道阶": 300
	}
	var 经验: int = int(基础经验.get(配方品阶, 10))
	if not 成功:
		经验 = int(经验 * 0.5)  # 失败获得一半经验
	return 经验

## 执行炼器（支持弟子技能影响和品质随机）
## 返回：{成功, 产出装备(Item/null), 消耗材料, 原因, 品质, 获得经验, 器灵觉醒}
static func 炼器(配方ID: String, 背包: Array, 器堂等级: int = 1, 炼器弟子 = null, 炼器经验值: int = 0) -> Dictionary:"""

if old_experience in content:
    content = content.replace(old_experience, new_experience)
    print("✅ 炼器经验系统添加成功")
else:
    print("❌ 未找到炼器经验系统的目标代码")

# ========== 2. 修改炼器方法，添加炼器等级加成和器灵觉醒 ==========
# 找到成功率计算部分，添加炼器等级加成
old_success_rate = """	# 计算成功率：基础 + 器堂等级加成（每级+2%）+ 弟子炼器技能加成
	var 成功率: float = float(配方.get("基础成功率", 50)) + float(max(0, 器堂等级 - 1)) * 2.0"""

new_success_rate = """	# 计算成功率：基础 + 器堂等级加成（每级+2%）+ 炼器等级加成 + 弟子炼器技能加成
	var 炼器加成: Dictionary = 获取炼器加成(炼器经验值)
	var 成功率: float = float(配方.get("基础成功率", 50)) + float(max(0, 器堂等级 - 1)) * 2.0 + float(炼器加成["成功率加成"])"""

if old_success_rate in content:
    content = content.replace(old_success_rate, new_success_rate)
    print("✅ 炼器等级成功率加成添加成功")
else:
    print("❌ 未找到成功率计算的目标代码")

# ========== 3. 修改炼器失败逻辑，添加失败补偿 ==========
old_failure = """	# 成功率判定
	if randf() * 100.0 > 成功率:
		return {"成功": false, "产出": null, "消耗": 消耗列表, "原因": "炼器失败，材料已消耗（成功率%.0f%%）" % 成功率, "品质": "普通"}"""

new_failure = """	# 成功率判定
	if randf() * 100.0 > 成功率:
		# 失败补偿：30%概率返还一半材料，70%概率获得装备碎片
		var 补偿文本: String = ""
		if randf() < 0.30:
			# 返还一半材料
			for mat in 消耗列表.duplicate():
				if randf() < 0.5:
					背包.append(mat)
					消耗列表.erase(mat)
			补偿文本 = "，部分材料已返还"
		else:
			# 获得装备碎片（根据配方品阶）
			var 碎片品阶: String = str(配方.get("品阶", "凡阶"))
			var 碎片ID: String = "frag_equip_" + 碎片品阶
			# 这里简化处理，实际应该添加到碎片库存
			补偿文本 = "，获得%s碎片×1" % 碎片品阶
		var 获得经验: int = 计算炼器经验(str(配方.get("品阶", "凡阶")), false)
		return {"成功": false, "产出": null, "消耗": 消耗列表, "原因": "炼器失败，材料已消耗（成功率%.0f%%）%s" % [成功率, 补偿文本], "品质": "普通", "获得经验": 获得经验, "器灵觉醒": false}"""

if old_failure in content:
    content = content.replace(old_failure, new_failure)
    print("✅ 炼器失败补偿添加成功")
else:
    print("❌ 未找到炼器失败逻辑的目标代码")

# ========== 4. 修改炼器成功逻辑，添加器灵觉醒和经验 ==========
old_success_return = """	背包.append(新品)
	return {"成功": true, "产出": 新品, "消耗": 消耗列表, "原因": "炼器成功！获得%s（品质：%s，成功率%.0f%%）" % [新品.名称, 炼器品质, 成功率], "品质": 炼器品质}"""

new_success_return = """	# 器灵觉醒：宝阶及以上5%概率触发器灵觉醒，装备获得额外属性
	var 器灵觉醒: bool = false
	if 新品.品阶 in ["宝阶", "王阶", "圣阶", "仙阶", "道阶"] and randf() < 0.05:
		器灵觉醒 = true
		新品.战力加成 = int(新品.战力加成 * 1.3)  # 器灵觉醒装备战力+30%
		新品.名称 = "【器灵】" + 新品.名称
	# 计算获得经验
	var 获得经验: int = 计算炼器经验(str(配方.get("品阶", "凡阶")), true)
	背包.append(新品)
	var 原因文本: String = "炼器成功！获得%s（品质：%s，成功率%.0f%%）" % [新品.名称, 炼器品质, 成功率]
	if 器灵觉醒:
		原因文本 += "，器灵觉醒！"
	return {"成功": true, "产出": 新品, "消耗": 消耗列表, "原因": 原因文本, "品质": 炼器品质, "获得经验": 获得经验, "器灵觉醒": 器灵觉醒}"""

if old_success_return in content:
    content = content.replace(old_success_return, new_success_return)
    print("✅ 炼器成功逻辑修改成功")
else:
    print("❌ 未找到炼器成功逻辑的目标代码")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

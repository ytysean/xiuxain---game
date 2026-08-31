# -*- coding: utf-8 -*-
"""
完善gongfa.gd功法系统细节：
1. 功法升级机制（1-10级，每级提升效果）
2. 功法熟练度系统（使用提升熟练度，满后可升级）
3. 功法遗忘功能（返还部分悟道点）
4. 功法效果计算（根据等级计算加成）
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\gongfa.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 1. 添加功法等级和熟练度相关常量 ==========
# 在五行相生定义之后，计算相克加成方法之前添加
old_const = """## 计算功法相克加成
## 攻击方功法属性克制防御方时，伤害+30%；被克制时，伤害-20%
static func 计算相克加成(攻击功法属性: String, 防御功法属性: String) -> float:"""

new_const = """## 功法等级定义（1-10级）
## 每级提升：修炼加成+10%，战力加成+15%，技能伤害+5%
const 功法等级上限: int = 10
const 功法升级熟练度: Array = [
	0, 100, 250, 500, 800, 1200, 1800, 2500, 3500, 5000
]

## 根据功法等级计算效果倍率
static func 计算等级倍率(等级: int) -> Dictionary:
	var 实际等级: int = clamp(等级, 1, 功法等级上限)
	var 修炼倍率: float = 1.0 + float(实际等级 - 1) * 0.10  # 每级+10%
	var 战力倍率: float = 1.0 + float(实际等级 - 1) * 0.15  # 每级+15%
	var 技能倍率: float = 1.0 + float(实际等级 - 1) * 0.05  # 每级+5%
	return {
		"等级": 实际等级,
		"修炼倍率": 修炼倍率,
		"战力倍率": 战力倍率,
		"技能倍率": 技能倍率
	}

## 获取弟子功法等级
static func 获取功法等级(弟子, 功法ID: String) -> int:
	if 弟子 == null:
		return 1
	var 功法等级表 = 弟子.get("功法等级", {})
	if 功法等级表 == null or typeof(功法等级表) != TYPE_DICTIONARY:
		return 1
	return int(功法等级表.get(功法ID, 1))

## 获取弟子功法熟练度
static func 获取功法熟练度(弟子, 功法ID: String) -> int:
	if 弟子 == null:
		return 0
	var 功法熟练度表 = 弟子.get("功法熟练度", {})
	if 功法熟练度表 == null or typeof(功法熟练度表) != TYPE_DICTIONARY:
		return 0
	return int(功法熟练度表.get(功法ID, 0))

## 增加功法熟练度
static func 增加熟练度(弟子, 功法ID: String, 数量: int) -> Dictionary:
	if 弟子 == null or 数量 <= 0:
		return {"升级": false, "原因": "参数错误"}
	var 当前等级: int = 获取功法等级(弟子, 功法ID)
	if 当前等级 >= 功法等级上限:
		return {"升级": false, "原因": "已达最高等级"}
	# 初始化熟练度表
	if not 弟子.has("功法熟练度") or 弟子.功法熟练度 == null or typeof(弟子.功法熟练度) != TYPE_DICTIONARY:
		弟子["功法熟练度"] = {}
	var 当前熟练度: int = int(弟子.功法熟练度.get(功法ID, 0))
	当前熟练度 += 数量
	弟子.功法熟练度[功法ID] = 当前熟练度
	# 检查是否可以升级
	var 所需熟练度: int = 功法升级熟练度[当前等级] if 当前等级 < 功法升级熟练度.size() else 99999
	if 当前熟练度 >= 所需熟练度:
		# 升级
		if not 弟子.has("功法等级") or 弟子.功法等级 == null or typeof(弟子.功法等级) != TYPE_DICTIONARY:
			弟子["功法等级"] = {}
		弟子.功法等级[功法ID] = 当前等级 + 1
		弟子.功法熟练度[功法ID] = 0  # 重置熟练度
		return {"升级": true, "原因": "功法升级至Lv.%d！" % (当前等级 + 1), "新等级": 当前等级 + 1}
	return {"升级": false, "原因": "熟练度+%d（%d/%d）" % [数量, 当前熟练度, 所需熟练度]}

## 遗忘功法（返还50%悟道点）
static func 遗忘功法(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 已学功法 = 弟子.get("已学功法", [])
	if 已学功法 == null or not 已学功法.has(功法ID):
		return {"成功": false, "原因": "未学习此功法"}
	var 功法 = 功法库.get(功法ID, {})
	if 功法.is_empty():
		return {"成功": false, "原因": "功法不存在"}
	# 计算返还悟道点（基础50% + 每级额外5%）
	var 功法等级: int = 获取功法等级(弟子, 功法ID)
	var 基础点: int = int(功法.get("所需悟道点", 10))
	var 返还比例: float = 0.50 + float(功法等级 - 1) * 0.05
	var 返还点: int = int(基础点 * 返还比例)
	# 移除功法
	已学功法.erase(功法ID)
	弟子.已学功法 = 已学功法
	# 移除等级和熟练度
	if 弟子.has("功法等级") and typeof(弟子.功法等级) == TYPE_DICTIONARY:
		弟子.功法等级.erase(功法ID)
	if 弟子.has("功法熟练度") and typeof(弟子.功法熟练度) == TYPE_DICTIONARY:
		弟子.功法熟练度.erase(功法ID)
	# 移除加成（简化处理：重新计算所有功法加成）
	var 修炼加成 = float(功法.get("修炼加成", 0))
	var 战力加成 = int(功法.get("战力加成", 0))
	var 等级倍率 = 计算等级倍率(功法等级)
	弟子.修炼速度 = float(弟子.get("修炼速度", 1.0)) / (1.0 + 修炼加成 * 等级倍率["修炼倍率"])
	弟子.战力 = int(弟子.get("战力", 100)) - int(战力加成 * 等级倍率["战力倍率"])
	return {"成功": true, "原因": "遗忘%s成功，返还悟道点%d" % [str(功法.get("名称","")), 返还点], "返还": 返还点}

## 计算功法相克加成
## 攻击方功法属性克制防御方时，伤害+30%；被克制时，伤害-20%
static func 计算相克加成(攻击功法属性: String, 防御功法属性: String) -> float:"""

if old_const in content:
    content = content.replace(old_const, new_const)
    print("✅ 功法等级和熟练度系统添加成功")
else:
    print("❌ 未找到功法相克加成的目标代码")

# ========== 2. 修改学习功法方法，初始化功法等级 ==========
old_learn = """	# 记录已学功法
	if not 弟子.has("已学功法") or 弟子.已学功法 == null:
		弟子["已学功法"] = []
	弟子.已学功法.append(功法ID)
	return {"成功": true, "原因": "学习%s成功！修炼速度+%.0f%%，战力+%d" % [str(功法.get("名称","")), 修炼加成*100, 战力加成], "消耗": 所需点}"""

new_learn = """	# 记录已学功法
	if not 弟子.has("已学功法") or 弟子.已学功法 == null:
		弟子["已学功法"] = []
	弟子.已学功法.append(功法ID)
	# 初始化功法等级和熟练度
	if not 弟子.has("功法等级") or 弟子.功法等级 == null or typeof(弟子.功法等级) != TYPE_DICTIONARY:
		弟子["功法等级"] = {}
	弟子.功法等级[功法ID] = 1  # 初始1级
	if not 弟子.has("功法熟练度") or 弟子.功法熟练度 == null or typeof(弟子.功法熟练度) != TYPE_DICTIONARY:
		弟子["功法熟练度"] = {}
	弟子.功法熟练度[功法ID] = 0  # 初始0熟练度
	return {"成功": true, "原因": "学习%s成功！修炼速度+%.0f%%，战力+%d" % [str(功法.get("名称","")), 修炼加成*100, 战力加成], "消耗": 所需点}"""

if old_learn in content:
    content = content.replace(old_learn, new_learn)
    print("✅ 学习功法方法修改成功")
else:
    print("❌ 未找到学习功法方法的目标代码")

# ========== 3. 修改获取战斗技能方法，添加等级倍率 ==========
old_skill = """## 获取功法战斗技能效果
static func 获取战斗技能(功法ID: String) -> Dictionary:
	var 功法 = 功法库.get(功法ID, {})
	if 功法.is_empty():
		return {}
	return {
		"技能名": str(功法.get("技能名", 功法.get("名称", ""))),
		"技能类型": str(功法.get("技能类型", "主动")),
		"伤害倍率": float(功法.get("伤害倍率", 1.0)),
		"冷却回合": int(功法.get("冷却回合", 3)),
		"特殊效果": str(功法.get("特殊效果", "")),
	}"""

new_skill = """## 获取功法战斗技能效果（支持功法等级加成）
static func 获取战斗技能(功法ID: String, 功法等级: int = 1) -> Dictionary:
	var 功法 = 功法库.get(功法ID, {})
	if 功法.is_empty():
		return {}
	var 等级倍率 = 计算等级倍率(功法等级)
	return {
		"技能名": str(功法.get("技能名", 功法.get("名称", ""))),
		"技能类型": str(功法.get("技能类型", "主动")),
		"伤害倍率": float(功法.get("伤害倍率", 1.0)) * float(等级倍率["技能倍率"]),
		"冷却回合": int(功法.get("冷却回合", 3)),
		"特殊效果": str(功法.get("特殊效果", "")),
		"功法等级": 功法等级,
	}"""

if old_skill in content:
    content = content.replace(old_skill, new_skill)
    print("✅ 获取战斗技能方法修改成功")
else:
    print("❌ 未找到获取战斗技能方法的目标代码")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

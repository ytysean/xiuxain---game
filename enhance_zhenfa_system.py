# -*- coding: utf-8 -*-
"""
完善zhenfa.gd阵法系统细节：
1. 阵法耐久度系统（受到攻击降低，需要修复）
2. 阵法材料消耗（升级消耗阵旗、灵石等材料）
3. 阵法驻守弟子选择（弟子境界影响阵法效果）
4. 阵法激活/停用功能
5. 阵法特殊效果实装
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\zhenfa.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 1. 添加阵法耐久度和材料相关常量 ==========
# 在类型加成定义之后，检查激活条件方法之前添加
old_const = """## 检查阵法是否可以激活（需要足够驻守弟子）
static func 检查激活条件(阵法ID: String, 可用弟子数: int) -> Dictionary:"""

new_const = """## 阵法耐久度定义
## 基础耐久度：100，每级+20
## 受到攻击时降低耐久度，耐久度为0时阵法失效
const 基础耐久度: int = 100
const 每级耐久度: int = 20

## 阵法修复消耗（每点耐久度消耗灵石）
const 修复消耗系数: int = 2  # 每点耐久度消耗2灵石

## 阵法升级材料消耗
## 除了灵石，升级还需要消耗阵旗等材料
const 升级材料表: Dictionary = {
	"hushan": {"材料": "阵旗", "基础数量": 1},
	"juling": {"材料": "聚灵珠", "基础数量": 1},
	"mizong": {"材料": "迷踪旗", "基础数量": 1},
	"tiangang": {"材料": "天罡旗", "基础数量": 1},
	"zhoutian": {"材料": "星斗旗", "基础数量": 1},
}

## 计算阵法最大耐久度
static func 计算最大耐久度(阵法等级: int) -> int:
	return 基础耐久度 + max(0, 阵法等级 - 1) * 每级耐久度

## 计算阵法修复消耗
static func 计算修复消耗(当前耐久度: int, 最大耐久度: int) -> int:
	var 缺失: int = max(0, 最大耐久度 - 当前耐久度)
	return 缺失 * 修复消耗系数

## 检查阵法是否可以激活（需要足够驻守弟子）
static func 检查激活条件(阵法ID: String, 可用弟子数: int) -> Dictionary:"""

if old_const in content:
    content = content.replace(old_const, new_const)
    print("✅ 阵法耐久度和材料常量添加成功")
else:
    print("❌ 未找到检查激活条件的目标代码")

# ========== 2. 修改升级阵法方法，添加材料消耗 ==========
old_upgrade = """## 升级阵法
## 返回：{成功, 原因, 新等级}
static func 升级阵法(阵法ID: String, 当前等级: int, 阵法堂等级: int) -> Dictionary:
	var 阵法 = 阵法库.get(阵法ID, {})
	if 阵法.is_empty():
		return {"成功": false, "原因": "阵法不存在", "新等级": 当前等级}
	# 检查解锁条件
	var 解锁等级 = int(阵法.get("解锁等级", 1))
	if 阵法堂等级 < 解锁等级:
		return {"成功": false, "原因": "阵法堂等级不足（需Lv.%d）" % 解锁等级, "新等级": 当前等级}
	# 计算升级消耗
	var 基础消耗 = int(阵法.get("升级消耗", 100))
	var 消耗 = int(基础消耗 * pow(1.5, 当前等级))
	if Game == null or Game.灵石 < 消耗:
		return {"成功": false, "原因": "灵石不足（需%d）" % 消耗, "新等级": 当前等级}
	# 扣除灵石
	Game.灵石 -= 消耗
	# 升级
	var 新等级 = 当前等级 + 1
	return {"成功": true, "原因": "%s升级至Lv.%d！" % [str(阵法.get("名称", "")), 新等级], "新等级": 新等级, "消耗": 消耗}"""

new_upgrade = """## 升级阵法
## 返回：{成功, 原因, 新等级, 消耗灵石, 消耗材料}
static func 升级阵法(阵法ID: String, 当前等级: int, 阵法堂等级: int) -> Dictionary:
	var 阵法 = 阵法库.get(阵法ID, {})
	if 阵法.is_empty():
		return {"成功": false, "原因": "阵法不存在", "新等级": 当前等级}
	# 检查解锁条件
	var 解锁等级 = int(阵法.get("解锁等级", 1))
	if 阵法堂等级 < 解锁等级:
		return {"成功": false, "原因": "阵法堂等级不足（需Lv.%d）" % 解锁等级, "新等级": 当前等级}
	# 计算升级消耗（灵石）
	var 基础消耗 = int(阵法.get("升级消耗", 100))
	var 灵石消耗 = int(基础消耗 * pow(1.5, 当前等级))
	if Game == null or Game.灵石 < 灵石消耗:
		return {"成功": false, "原因": "灵石不足（需%d）" % 灵石消耗, "新等级": 当前等级}
	# 计算升级消耗（材料）
	var 材料配置 = 升级材料表.get(阵法ID, {})
	var 材料名: String = str(材料配置.get("材料", ""))
	var 材料基础数: int = int(材料配置.get("基础数量", 0))
	var 材料消耗: int = 0
	if 材料名 != "" and 材料基础数 > 0:
		材料消耗 = 材料基础数 + 当前等级  # 每级多消耗1个材料
		# 检查材料是否足够（简化处理：从仓库中查找）
		var 材料足够: bool = false
		var 材料数量: int = 0
		if Game != null and Game.has("仓库"):
			for item in Game.仓库:
				if item != null and typeof(item) == TYPE_OBJECT and "名称" in item and str(item.名称) == 材料名:
					材料数量 += 1
		if 材料数量 >= 材料消耗:
			材料足够 = true
		if not 材料足够:
			return {"成功": false, "原因": "材料不足（需%s×%d，当前%d）" % [材料名, 材料消耗, 材料数量], "新等级": 当前等级}
	# 扣除灵石
	Game.灵石 -= 灵石消耗
	# 扣除材料
	if 材料名 != "" and 材料消耗 > 0:
		var 已扣除: int = 0
		for i in range(Game.仓库.size() - 1, -1, -1):
			if 已扣除 >= 材料消耗:
				break
			var item = Game.仓库[i]
			if item != null and typeof(item) == TYPE_OBJECT and "名称" in item and str(item.名称) == 材料名:
				Game.仓库.remove_at(i)
				已扣除 += 1
	# 升级
	var 新等级 = 当前等级 + 1
	var 原因文本: String = "%s升级至Lv.%d！消耗灵石%d" % [str(阵法.get("名称", "")), 新等级, 灵石消耗]
	if 材料名 != "" and 材料消耗 > 0:
		原因文本 += "，%s×%d" % [材料名, 材料消耗]
	return {"成功": true, "原因": 原因文本, "新等级": 新等级, "消耗灵石": 灵石消耗, "消耗材料": 材料消耗}"""

if old_upgrade in content:
    content = content.replace(old_upgrade, new_upgrade)
    print("✅ 升级阵法方法修改成功")
else:
    print("❌ 未找到升级阵法方法的目标代码")

# ========== 3. 添加阵法驻守弟子境界加成计算方法 ==========
# 在获取升级消耗方法之后添加
old_end = """## 获取阵法升级消耗
static func 获取升级消耗(阵法ID: String, 当前等级: int) -> int:
	var 阵法 = 阵法库.get(阵法ID, {})
	if 阵法.is_empty():
		return 0
	var 基础消耗 = int(阵法.get("升级消耗", 100))
	return int(基础消耗 * pow(1.5, 当前等级))"""

new_end = """## 获取阵法升级消耗
static func 获取升级消耗(阵法ID: String, 当前等级: int) -> int:
	var 阵法 = 阵法库.get(阵法ID, {})
	if 阵法.is_empty():
		return 0
	var 基础消耗 = int(阵法.get("升级消耗", 100))
	return int(基础消耗 * pow(1.5, 当前等级))

## 计算驻守弟子境界加成
## 弟子境界越高，阵法效果越强
## 练气=1.0, 筑基=1.1, 金丹=1.2, 元婴=1.3, 化神=1.4, 炼虚=1.5, 合体=1.6, 大乘=1.7, 渡劫=1.8, 飞升=2.0
static func 计算驻守境界加成(驻守弟子列表: Array) -> float:
	if 驻守弟子列表 == null or 驻守弟子列表.size() == 0:
		return 1.0
	var 境界序: Array = ["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫", "飞升"]
	var 总加成: float = 0.0
	var 有效弟子数: int = 0
	for 弟子 in 驻守弟子列表:
		if 弟子 == null:
			continue
		var 境界 = ""
		if 弟子.has("境界"):
			境界 = str(弟子.境界)
		elif 弟子.has_method("get"):
			境界 = str(弟子.get("境界", "练气"))
		var 境界索引 = 境界序.find(境界)
		if 境界索引 < 0:
			境界索引 = 0
		总加成 += 1.0 + float(境界索引) * 0.1
		有效弟子数 += 1
	if 有效弟子数 == 0:
		return 1.0
	return 总加成 / float(有效弟子数)

## 阵法受到攻击，降低耐久度
## 返回：{耐久度变化, 是否失效}
static func 受到攻击(阵法ID: String, 当前耐久度: int, 阵法等级: int, 攻击强度: int = 10) -> Dictionary:
	var 最大耐久度: int = 计算最大耐久度(阵法等级)
	var 耐久度损失: int = max(1, int(攻击强度 * 0.5))  # 攻击强度的50%转化为耐久度损失
	var 新耐久度: int = max(0, 当前耐久度 - 耐久度损失)
	var 失效: bool = (新耐久度 <= 0)
	return {
		"旧耐久度": 当前耐久度,
		"新耐久度": 新耐久度,
		"最大耐久度": 最大耐久度,
		"损失": 耐久度损失,
		"失效": 失效
	}

## 修复阵法
## 返回：{成功, 原因, 消耗灵石, 新耐久度}
static func 修复阵法(阵法ID: String, 当前耐久度: int, 阵法等级: int) -> Dictionary:
	var 最大耐久度: int = 计算最大耐久度(阵法等级)
	if 当前耐久度 >= 最大耐久度:
		return {"成功": false, "原因": "阵法耐久度已满", "消耗灵石": 0, "新耐久度": 当前耐久度}
	var 消耗灵石: int = 计算修复消耗(当前耐久度, 最大耐久度)
	if Game == null or Game.灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d）" % 消耗灵石, "消耗灵石": 0, "新耐久度": 当前耐久度}
	Game.灵石 -= 消耗灵石
	return {"成功": true, "原因": "阵法修复完成！消耗灵石%d" % 消耗灵石, "消耗灵石": 消耗灵石, "新耐久度": 最大耐久度}"""

if old_end in content:
    content = content.replace(old_end, new_end)
    print("✅ 阵法驻守弟子境界加成和耐久度方法添加成功")
else:
    print("❌ 未找到获取升级消耗方法的目标代码")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

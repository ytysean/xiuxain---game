# -*- coding: utf-8 -*-
"""
修改game_state.gd，添加功法系统的封装方法：
1. 学习功法（封装GongfaSystem.学习功法，自动管理悟道点）
2. 遗忘功法（封装GongfaSystem.遗忘功法，返还悟道点）
3. 增加功法熟练度
4. 获取弟子功法列表
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 添加功法系统封装方法 ==========
# 在炼器系统封装方法之后，碎片合成系统之前添加
old_method = """# ============ 碎片合成系统：库存管理 + 合成逻辑 ============"""

new_method = """# ============ 功法系统：封装方法 ============
# 学习功法（自动消耗悟道点）
func 学习功法(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 结果: Dictionary = GongfaSystem.学习功法(弟子, 功法ID, 悟道点)
	if 结果.get("成功", false):
		var 消耗: int = int(结果.get("消耗", 0))
		悟道点 -= 消耗
	return 结果

# 遗忘功法（返还悟道点）
func 遗忘功法(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 结果: Dictionary = GongfaSystem.遗忘功法(弟子, 功法ID)
	if 结果.get("成功", false):
		var 返还: int = int(结果.get("返还", 0))
		悟道点 += 返还
	return 结果

# 增加功法熟练度
func 增加功法熟练度(弟子, 功法ID: String, 数量: int) -> Dictionary:
	if 弟子 == null:
		return {"升级": false, "原因": "弟子不存在"}
	return GongfaSystem.增加熟练度(弟子, 功法ID, 数量)

# 获取弟子功法列表（包含等级和熟练度）
func 获取弟子功法列表(弟子) -> Array:
	if 弟子 == null:
		return []
	var 已学功法 = 弟子.get("已学功法", [])
	if 已学功法 == null:
		return []
	var 列表: Array = []
	for 功法ID in 已学功法:
		var 功法 = GongfaSystem.功法库.get(功法ID, {})
		if 功法.is_empty():
			continue
		var 等级: int = GongfaSystem.获取功法等级(弟子, 功法ID)
		var 熟练度: int = GongfaSystem.获取功法熟练度(弟子, 功法ID)
		列表.append({
			"功法ID": 功法ID,
			"名称": str(功法.get("名称", "")),
			"品阶": str(功法.get("品阶", "")),
			"类型": str(功法.get("类型", "")),
			"等级": 等级,
			"熟练度": 熟练度,
			"修炼加成": float(功法.get("修炼加成", 0)),
			"战力加成": int(功法.get("战力加成", 0)),
		})
	return 列表

# ============ 碎片合成系统：库存管理 + 合成逻辑 ============"""

if old_method in content:
    content = content.replace(old_method, new_method)
    print("✅ 功法系统封装方法添加成功")
else:
    print("❌ 未找到碎片合成系统的目标代码")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

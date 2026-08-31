# -*- coding: utf-8 -*-
"""
修改game_state.gd，添加阵法系统的封装方法：
1. 添加阵法耐久度存储
2. 添加阵法升级封装方法
3. 添加阵法修复封装方法
4. 添加阵法驻守弟子管理
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 1. 添加阵法耐久度变量 ==========
# 在阵法等级变量之后添加阵法耐久度变量
old_var = """var 阵法等级: Dictionary = {}  # 阵法堂：阵法ID→等级"""

new_var = """var 阵法等级: Dictionary = {}  # 阵法堂：阵法ID→等级
var 阵法耐久度: Dictionary = {}  # 阵法堂：阵法ID→当前耐久度（旧档缺键→默认满耐久）
var 阵法驻守弟子: Dictionary = {}  # 阵法堂：阵法ID→驻守弟子ID列表"""

if old_var in content:
    content = content.replace(old_var, new_var)
    print("✅ 阵法耐久度变量添加成功")
else:
    print("❌ 未找到阵法等级变量的目标代码")

# ========== 2. 添加阵法系统封装方法 ==========
# 在功法系统封装方法之后，碎片合成系统之前添加
old_method = """# ============ 碎片合成系统：库存管理 + 合成逻辑 ============"""

new_method = """# ============ 阵法系统：封装方法 ============
# 初始化阵法耐久度（旧档兼容）
func _初始化阵法耐久度() -> void:
	for 阵法ID in 阵法等级.keys():
		if not 阵法耐久度.has(阵法ID):
			var 等级: int = int(阵法等级[阵法ID])
			阵法耐久度[阵法ID] = ZhenfaSystem.计算最大耐久度(等级)

# 升级阵法（封装ZhenfaSystem.升级阵法，自动更新等级和耐久度）
func 升级阵法(阵法ID: String, 阵法堂等级: int) -> Dictionary:
	var 当前等级: int = int(阵法等级.get(阵法ID, 0))
	var 结果: Dictionary = ZhenfaSystem.升级阵法(阵法ID, 当前等级, 阵法堂等级)
	if 结果.get("成功", false):
		var 新等级: int = int(结果.get("新等级", 当前等级 + 1))
		阵法等级[阵法ID] = 新等级
		# 升级后耐久度恢复满
		阵法耐久度[阵法ID] = ZhenfaSystem.计算最大耐久度(新等级)
	return 结果

# 修复阵法（封装ZhenfaSystem.修复阵法，自动更新耐久度）
func 修复阵法(阵法ID: String) -> Dictionary:
	var 当前等级: int = int(阵法等级.get(阵法ID, 0))
	var 当前耐久度: int = int(阵法耐久度.get(阵法ID, ZhenfaSystem.计算最大耐久度(当前等级)))
	var 结果: Dictionary = ZhenfaSystem.修复阵法(阵法ID, 当前耐久度, 当前等级)
	if 结果.get("成功", false):
		阵法耐久度[阵法ID] = int(结果.get("新耐久度", 当前耐久度))
	return 结果

# 获取阵法信息（包含等级、耐久度、驻守弟子）
func 获取阵法信息(阵法ID: String) -> Dictionary:
	var 阵法 = ZhenfaSystem.阵法库.get(阵法ID, {})
	if 阵法.is_empty():
		return {}
	var 等级: int = int(阵法等级.get(阵法ID, 0))
	var 最大耐久度: int = ZhenfaSystem.计算最大耐久度(等级)
	var 当前耐久度: int = int(阵法耐久度.get(阵法ID, 最大耐久度))
	var 驻守弟子列表: Array = 阵法驻守弟子.get(阵法ID, [])
	return {
		"阵法ID": 阵法ID,
		"名称": str(阵法.get("名称", "")),
		"类型": str(阵法.get("类型", "")),
		"等级": 等级,
		"当前耐久度": 当前耐久度,
		"最大耐久度": 最大耐久度,
		"耐久度比例": float(当前耐久度) / float(max(1, 最大耐久度)),
		"驻守弟子数": 驻守弟子列表.size() if 驻守弟子列表 != null else 0,
		"驻守需求": int(阵法.get("驻守需求", 1)),
		"布置位置": str(阵法.get("布置位置", "")),
		"特殊效果": str(阵法.get("特殊效果", "")),
		"描述": str(阵法.get("描述", "")),
	}

# 获取所有已激活阵法列表
func 获取已激活阵法列表() -> Array:
	var 列表: Array = []
	for 阵法ID in 阵法等级.keys():
		var 等级: int = int(阵法等级[阵法ID])
		if 等级 > 0:
			列表.append(获取阵法信息(阵法ID))
	return 列表

# 计算阵法总效果（封装ZhenfaSystem.计算效果，考虑驻守弟子境界加成）
func 计算阵法总效果() -> Dictionary:
	# 计算驻守弟子境界加成
	var 总加成: float = 1.0
	var 所有驻守弟子: Array = []
	for 阵法ID in 阵法驻守弟子.keys():
		var 弟子ID列表 = 阵法驻守弟子[阵法ID]
		if 弟子ID列表 != null:
			for 弟子ID in 弟子ID列表:
				for 弟子 in 弟子列表:
					if 弟子 != null and str(弟子.弟子ID) == str(弟子ID):
						所有驻守弟子.append(弟子)
	if 所有驻守弟子.size() > 0:
		总加成 = ZhenfaSystem.计算驻守境界加成(所有驻守弟子)
	return ZhenfaSystem.计算效果(阵法等级, 总加成)

# ============ 碎片合成系统：库存管理 + 合成逻辑 ============"""

if old_method in content:
    content = content.replace(old_method, new_method)
    print("✅ 阵法系统封装方法添加成功")
else:
    print("❌ 未找到碎片合成系统的目标代码")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

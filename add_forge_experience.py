# -*- coding: utf-8 -*-
"""
修改game_state.gd，添加炼器经验值的存储和管理：
1. 添加炼器经验值变量
2. 修改炼器调用，传递炼器经验值
3. 在炼器结果中更新炼器经验值
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ========== 1. 添加炼器经验值变量 ==========
# 在仓库变量之后添加炼器经验值变量
old_var = """var 仓库: Array = []  # 宗门公共物品仓库（丹药/灵材/装备等Item对象）"""

new_var = """var 仓库: Array = []  # 宗门公共物品仓库（丹药/灵材/装备等Item对象）
var 炼器经验值: int = 0  # 炼器系统经验值，用于提升炼器等级（不升SAVE_VERSION，旧档默认0）"""

if old_var in content:
    content = content.replace(old_var, new_var)
    print("✅ 炼器经验值变量添加成功")
else:
    print("❌ 未找到仓库变量的目标代码")

# ========== 2. 添加炼器经验值管理方法 ==========
# 在碎片合成系统之前添加炼器经验值管理方法
old_method = """# ============ 碎片合成系统：库存管理 + 合成逻辑 ============"""

new_method = """# ============ 炼器系统：经验值管理 ============
# 获取炼器等级
func 获取炼器等级() -> int:
	return ForgeSystem.获取炼器等级(炼器经验值)

# 获取炼器加成
func 获取炼器加成() -> Dictionary:
	return ForgeSystem.获取炼器加成(炼器经验值)

# 增加炼器经验
func 增加炼器经验(数量: int) -> void:
	if 数量 <= 0:
		return
	var 旧等级: int = 获取炼器等级()
	炼器经验值 += 数量
	var 新等级: int = 获取炼器等级()
	if 新等级 > 旧等级:
		print("[炼器] 炼器等级提升：%d → %d" % [旧等级, 新等级])

# 执行炼器（封装ForgeSystem.炼器，自动传递炼器经验值并更新）
func 执行炼器(配方ID: String, 器堂等级: int = 1, 炼器弟子 = null) -> Dictionary:
	var 背包: Array = 仓库.duplicate()
	var 结果: Dictionary = ForgeSystem.炼器(配方ID, 背包, 器堂等级, 炼器弟子, 炼器经验值)
	仓库 = 背包
	# 更新炼器经验
	var 获得经验: int = int(结果.get("获得经验", 0))
	if 获得经验 > 0:
		增加炼器经验(获得经验)
	return 结果

# ============ 碎片合成系统：库存管理 + 合成逻辑 ============"""

if old_method in content:
    content = content.replace(old_method, new_method)
    print("✅ 炼器经验值管理方法添加成功")
else:
    print("❌ 未找到碎片合成系统的目标代码")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

# -*- coding: utf-8 -*-
"""
删除重复添加的法宝和时装系统，完善现有的仙衣阁（皮肤系统）和本命法宝系统
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 删除刚才重复添加的法宝系统和时装系统
# 找到法宝系统开始的位置
treasure_start = "# ============ 法宝系统（新增） ============"
# 找到碎片合成系统开始的位置
fragment_start = "# ============ 碎片合成系统：库存管理 + 合成逻辑 ============"

if treasure_start in content and fragment_start in content:
    # 找到法宝系统开始的索引
    start_idx = content.find(treasure_start)
    # 找到碎片合成系统开始的索引
    end_idx = content.find(fragment_start)
    # 删除法宝系统和时装系统（从法宝系统开始到碎片合成系统开始之前）
    content = content[:start_idx] + content[end_idx:]
    print("✅ 已删除重复添加的法宝系统和时装系统")
else:
    print("❌ 未找到法宝系统或碎片合成系统")

# 2. 完善现有的皮肤系统（仙衣阁）
# 在取宗主皮肤全宗加成函数后面添加更多功能
old_skin_func = '''# 返回当前装备宗主皮肤的全宗加：{修为: float, 灵石: float, 全属: float}
func 取宗主皮肤全宗加成() -> Dictionary:'''

new_skin_func = '''# 获取所有宗主皮肤列表
func 获取所有宗主皮肤列表() -> Array:
	var 皮肤列表 = []
	var 路径: String = "res://config/master_skin_config.csv"
	if not FileAccess.file_exists(路径):
		return 皮肤列表
	var 文件: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		return 皮肤列表
	var 表头: Array = 文件.get_csv_line()
	while not 文件.eof_reached():
		var 行: Array = 文件.get_csv_line()
		if 行.size() < 2:
			continue
		var 皮肤ID = str(行[0])
		var 皮肤名称 = str(行[1]) if 行.size() > 1 else 皮肤ID
		皮肤列表.append({
			"皮肤ID": 皮肤ID,
			"名称": 皮肤名称,
			"已拥有": 已拥有宗主皮肤.has(皮肤ID),
			"当前装备": 当前宗主皮肤 == 皮肤ID,
		})
	文件.close()
	return 皮肤列表

# 获取所有弟子皮肤列表
func 获取所有弟子皮肤列表() -> Array:
	var 皮肤列表 = []
	var 路径: String = "res://config/disciple_skin_config.csv"
	if not FileAccess.file_exists(路径):
		return 皮肤列表
	var 文件: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		return 皮肤列表
	var 表头: Array = 文件.get_csv_line()
	while not 文件.eof_reached():
		var 行: Array = 文件.get_csv_line()
		if 行.size() < 2:
			continue
		var 皮肤ID = str(行[0])
		var 皮肤名称 = str(行[1]) if 行.size() > 1 else 皮肤ID
		皮肤列表.append({
			"皮肤ID": 皮肤ID,
			"名称": 皮肤名称,
			"已拥有": 已拥有弟子皮肤.has(皮肤ID),
		})
	文件.close()
	return 皮肤列表

# 获取皮肤统计
func 获取皮肤统计() -> Dictionary:
	return {
		"宗主皮肤总数": 获取所有宗主皮肤列表().size(),
		"宗主皮肤已拥有": 已拥有宗主皮肤.size(),
		"当前宗主皮肤": 当前宗主皮肤,
		"弟子皮肤总数": 获取所有弟子皮肤列表().size(),
		"弟子皮肤已拥有": 已拥有弟子皮肤.size(),
	}

# 返回当前装备宗主皮肤的全宗加：{修为: float, 灵石: float, 全属: float}
func 取宗主皮肤全宗加成() -> Dictionary:'''

if old_skin_func in content:
    content = content.replace(old_skin_func, new_skin_func)
    print("✅ 仙衣阁（皮肤系统）完善成功（添加所有宗主皮肤列表、所有弟子皮肤列表、皮肤统计）")
else:
    print("❌ 未找到取宗主皮肤全宗加成函数")

# 3. 完善现有的本命法宝系统
# 在_造低阶物品函数后面添加本命法宝相关功能
old_treasure_func = '''# 造一枚指定类：品阶的物品（殿阁被动掉落用；仅填模板+算战力，不污染战斗数值红线）
func _造低阶物品(类别: String, 品阶: String) -> Item:'''

new_treasure_func = '''# 获取所有本命法宝列表（从弟子背包中筛选）
func 获取所有本命法宝列表() -> Array:
	var 法宝列表 = []
	for d in 弟子列表:
		if d == null:
			continue
		for 物品 in d.背包:
			if 物品 != null and 物品.穿戴位 == "本命法宝":
				法宝列表.append({
					"名称": 物品.名称,
					"品阶": 物品.品阶,
					"类别": 物品.类别,
					"战力": 物品.战力,
					"所属弟子": d.姓名,
					"已装备": 物品.已装备,
				})
	return 法宝列表

# 获取本命法宝统计
func 获取本命法宝统计() -> Dictionary:
	var 法宝列表 = 获取所有本命法宝列表()
	var 已装备数 = 0
	var 总战力 = 0
	for 法宝 in 法宝列表:
		if 法宝.get("已装备", false):
			已装备数 += 1
		总战力 += int(法宝.get("战力", 0))
	return {
		"总数": 法宝列表.size(),
		"已装备数": 已装备数,
		"总战力": 总战力,
		"平均战力": int(总战力 / 法宝列表.size()) if 法宝列表.size() > 0 else 0,
	}

# 获取弟子当前装备的本命法宝
func 获取弟子本命法宝(弟子ID: String) -> Dictionary:
	for d in 弟子列表:
		if d != null and d.弟子ID == 弟子ID:
			for 物品 in d.背包:
				if 物品 != null and 物品.穿戴位 == "本命法宝" and 物品.已装备:
					return {
						"名称": 物品.名称,
						"品阶": 物品.品阶,
						"类别": 物品.类别,
						"战力": 物品.战力,
						"所属弟子": d.姓名,
					}
	return {}

# 造一枚指定类：品阶的物品（殿阁被动掉落用；仅填模板+算战力，不污染战斗数值红线）
func _造低阶物品(类别: String, 品阶: String) -> Item:'''

if old_treasure_func in content:
    content = content.replace(old_treasure_func, new_treasure_func)
    print("✅ 本命法宝系统完善成功（添加所有本命法宝列表、本命法宝统计、获取弟子本命法宝）")
else:
    print("❌ 未找到_造低阶物品函数")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 仙衣阁和本命法宝系统完善完成！")
print("\n📋 已完善的功能：")
print("  1. 仙衣阁（皮肤系统）：")
print("     - 添加获取所有宗主皮肤列表功能")
print("     - 添加获取所有弟子皮肤列表功能")
print("     - 添加获取皮肤统计功能")
print("  2. 本命法宝系统：")
print("     - 添加获取所有本命法宝列表功能（从弟子背包中筛选）")
print("     - 添加获取本命法宝统计功能")
print("     - 添加获取弟子当前装备的本命法宝功能")
print("\n📌 仙衣阁说明：")
print("  - 宗主皮肤：从master_skin_config.csv读取，支持装备、卸下、获取全宗加成")
print("  - 弟子皮肤：从disciple_skin_config.csv读取，支持拥有记录")
print("  - 皮肤统计：宗主皮肤总数/已拥有/当前装备，弟子皮肤总数/已拥有")
print("\n📌 本命法宝说明：")
print("  - 本命法宝：作为物品的穿戴位（\"本命法宝\"），存储在弟子背包中")
print("  - 本命法宝列表：从所有弟子背包中筛选穿戴位为\"本命法宝\"的物品")
print("  - 本命法宝统计：总数、已装备数、总战力、平均战力")
print("  - 弟子本命法宝：获取指定弟子当前装备的本命法宝")

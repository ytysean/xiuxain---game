# -*- coding: utf-8 -*-
"""
修复学习功法函数缩进错误，实现傀儡系统和藏书阁系统基本功能
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 修复学习功法函数中的缩进错误
old_indent = '''		# 事件型里程碑触发：首次学习功法
	_复检成就()  # 成就检测：功法收集相关成就
		var 已学功法总数: int = 0'''

new_indent = '''		# 事件型里程碑触发：首次学习功法
		_复检成就()  # 成就检测：功法收集相关成就
		var 已学功法总数: int = 0'''

if old_indent in content:
    content = content.replace(old_indent, new_indent)
    print("✅ 学习功法函数缩进错误修复成功")
else:
    print("❌ 未找到学习功法函数缩进错误")

# 2. 在统计变量定义后添加傀儡系统和藏书阁系统的变量定义
old_vars = '''var 已解锁装备图纸数: int = 0         # 已解锁装备图纸数量（成就用）
# 日供公共 API（供 UI 调用；只：轻量写，不触碰核心数值）'''

new_vars = '''var 已解锁装备图纸数: int = 0         # 已解锁装备图纸数量（成就用）
# ===== S1 傀儡系统和藏书阁系统（2026-08-30 新增）=====
var 傀儡列表: Array = []                # 傀儡列表（{ID, 名称, 品阶, 类型, 等级, 效果}）
var 傀儡ID计数器: int = 0               # 傀儡ID计数器
var 藏书阁列表: Array = []              # 藏书阁收录典籍列表（{ID, 名称, 品阶, 类型, 描述}）
var 藏书阁ID计数器: int = 0             # 藏书阁ID计数器
# 日供公共 API（供 UI 调用；只：轻量写，不触碰核心数值）'''

if old_vars in content:
    content = content.replace(old_vars, new_vars)
    print("✅ 傀儡系统和藏书阁系统变量定义添加成功")
else:
    print("❌ 未找到统计变量定义位置")

# 3. 在功法系统封装方法后添加傀儡系统和藏书阁系统的函数
old_func_end = '''	return 列表

# ============ 阵法系统：封装方法 ============'''

new_funcs = '''	return 列表

# ============ 傀儡系统：封装方法 ============
# 制作傀儡（消耗材料，生成傀儡）
func 制作傀儡(傀儡名称: String, 傀儡品阶: String, 傀儡类型: String, 消耗灵石: int = 0) -> Dictionary:
	if 消耗灵石 > 0 and 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足"}
	if 消耗灵石 > 0:
		灵石 -= 消耗灵石
	var 新傀儡 = {
		"ID": 傀儡ID计数器,
		"名称": 傀儡名称,
		"品阶": 傀儡品阶,
		"类型": 傀儡类型,
		"等级": 1,
		"效果": "待实现",
	}
	傀儡ID计数器 += 1
	傀儡列表.append(新傀儡)
	# 成就统计：累计制作傀儡数自增
	累计制作傀儡数 += 1
	_复检成就()
	添加纪事("庶务", "制作傀儡", "制作了%s（%s）" % [傀儡名称, 傀儡品阶], 1)
	return {"成功": true, "傀儡": 新傀儡, "消息": "制作%s成功" % 傀儡名称}

# 获取傀儡列表
func 获取傀儡列表() -> Array:
	return 傀儡列表

# ============ 藏书阁系统：封装方法 ============
# 收录典籍到藏书阁
func 收录典籍(典籍名称: String, 典籍品阶: String, 典籍类型: String, 典籍描述: String = "") -> Dictionary:
	# 检查是否已收录
	for 典籍 in 藏书阁列表:
		if 典籍.get("名称", "") == 典籍名称:
			return {"成功": false, "原因": "该典籍已收录"}
	var 新典籍 = {
		"ID": 藏书阁ID计数器,
		"名称": 典籍名称,
		"品阶": 典籍品阶,
		"类型": 典籍类型,
		"描述": 典籍描述,
	}
	藏书阁ID计数器 += 1
	藏书阁列表.append(新典籍)
	# 成就统计：藏书阁收录数自增
	藏书阁收录数 += 1
	_复检成就()
	添加纪事("庶务", "收录典籍", "藏书阁收录了%s（%s）" % [典籍名称, 典籍品阶], 1)
	return {"成功": true, "典籍": 新典籍, "消息": "收录%s成功" % 典籍名称}

# 获取藏书阁列表
func 获取藏书阁列表() -> Array:
	return 藏书阁列表

# ============ 阵法系统：封装方法 ============'''

if old_func_end in content:
    content = content.replace(old_func_end, new_funcs)
    print("✅ 傀儡系统和藏书阁系统函数添加成功")
else:
    print("❌ 未找到功法系统函数结束位置")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 傀儡系统和藏书阁系统基本功能实现完成！")
print("\n📋 已实现的功能：")
print("  1. 修复学习功法函数缩进错误")
print("  2. 傀儡系统：")
print("     - 傀儡列表变量定义")
print("     - 傀儡ID计数器")
print("     - 制作傀儡函数（消耗灵石，生成傀儡）")
print("     - 获取傀儡列表函数")
print("     - 累计制作傀儡数自增和成就检测")
print("  3. 藏书阁系统：")
print("     - 藏书阁列表变量定义")
print("     - 藏书阁ID计数器")
print("     - 收录典籍函数（检查重复，收录典籍）")
print("     - 获取藏书阁列表函数")
print("     - 藏书阁收录数自增和成就检测")
print("\n⚠️  注意：这是简化版实现，傀儡的实际效果（如战斗加成、生产加成等）")
print("  和藏书阁的实际功能（如阅读典籍获得加成等）需要根据游戏设计进一步完善。")

# -*- coding: utf-8 -*-
"""
修复page_building.gd中的编译错误
1. entry.get()只接受1个参数，移除默认值
2. 第723行使用殿阁等级而不是等级
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_building.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 修复编译错误
old_code = """	# 判断殿阁是否可升级
	var 可升级: bool = false
	if is_instance_valid(Game) and Game.has_method("升级殿阁"):
		var 殿阁等级: int = int(entry.get("等级", 1))
		var 上限: int = 10
		if Game.has_method("_殿阁等级上限"):
			上限 = int(Game._殿阁等级上限())
		var 门派等级: int = int(Game.get("门派等级", 1))
		if 殿阁等级 < 上限 and 门派等级 >= 2:
			var 费: int = 0
			if Game.has_method("_升级消耗_灵石"):
				费 = int(Game._升级消耗_灵石(等级))
			var 灵石: int = int(Game.get("灵石", 0))
			可升级 = 灵石 >= 费"""

new_code = """	# 判断殿阁是否可升级
	var 可升级: bool = false
	if is_instance_valid(Game) and Game.has_method("升级殿阁"):
		var 殿阁等级: int = int(entry.get("等级"))
		var 上限: int = 10
		if Game.has_method("_殿阁等级上限"):
			上限 = int(Game._殿阁等级上限())
		var 门派等级: int = int(Game.get("门派等级"))
		if 殿阁等级 < 上限 and 门派等级 >= 2:
			var 费: int = 0
			if Game.has_method("_升级消耗_灵石"):
				费 = int(Game._升级消耗_灵石(殿阁等级))
			var 灵石: int = int(Game.get("灵石"))
			可升级 = 灵石 >= 费"""

if old_code in content:
    content = content.replace(old_code, new_code)
    print("✅ 编译错误修复成功")
else:
    print("❌ 未找到目标代码，尝试逐行修复...")
    # 逐行修复
    content = content.replace('var 殿阁等级: int = int(entry.get("等级", 1))', 'var 殿阁等级: int = int(entry.get("等级"))')
    content = content.replace('var 门派等级: int = int(Game.get("门派等级", 1))', 'var 门派等级: int = int(Game.get("门派等级"))')
    content = content.replace('费 = int(Game._升级消耗_灵石(等级))', '费 = int(Game._升级消耗_灵石(殿阁等级))')
    content = content.replace('var 灵石: int = int(Game.get("灵石", 0))', 'var 灵石: int = int(Game.get("灵石"))')
    print("✅ 逐行修复完成")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")

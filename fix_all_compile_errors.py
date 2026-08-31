# -*- coding: utf-8 -*-
"""
彻底修复game_state.gd和page_building.gd中的编译错误
1. 检查并修复GongfaSystem/GongFaSystem名称
2. 检查并修复ZhenfaSystem/ZhenFaSystem名称
3. 修复page_building.gd中变量重复声明的问题
"""

import os

# 修复game_state.gd
file_path1 = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"
with open(file_path1, 'r', encoding='utf-8') as f:
    content1 = f.read()

# 检查是否有错误的名称
if 'GongfaSystem' in content1:
    print("发现GongfaSystem，正在替换...")
    content1 = content1.replace('GongfaSystem', 'GongFaSystem')
else:
    print("未发现GongfaSystem")

if 'ZhenfaSystem' in content1:
    print("发现ZhenfaSystem，正在替换...")
    content1 = content1.replace('ZhenfaSystem', 'ZhenFaSystem')
else:
    print("未发现ZhenfaSystem")

# 保存文件
with open(file_path1, 'w', encoding='utf-8') as f:
    f.write(content1)
print("game_state.gd修复完成")

# 修复page_building.gd
file_path2 = r"E:\Xiuxian\taixuanzongmenlu\ui\page_building.gd"
with open(file_path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

# 检查是否有错误的名称
if 'ZhenfaSystem' in content2:
    print("发现ZhenfaSystem，正在替换...")
    content2 = content2.replace('ZhenfaSystem', 'ZhenFaSystem')
else:
    print("未发现ZhenfaSystem")

# 修复变量重复声明的问题
# 找到第715行附近的代码，将var 等级改为var 殿阁等级
old_code = """	# 判断殿阁是否可升级
	var 可升级: bool = false
	if is_instance_valid(Game) and Game.has_method("升级殿阁"):
		var 等级: int = int(entry.get("等级", 1))
		var 上限: int = 10
		if Game.has_method("_殿阁等级上限"):
			上限 = int(Game._殿阁等级上限())
		var 门派等级: int = int(Game.get("门派等级", 1))
		if 等级 < 上限 and 门派等级 >= 2:
			var 费: int = 0
			if Game.has_method("_升级消耗_灵石"):
				费 = int(Game._升级消耗_灵石(等级))
			var 灵石: int = int(Game.get("灵石", 0))
			可升级 = 灵石 >= 费"""

new_code = """	# 判断殿阁是否可升级
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
				费 = int(Game._升级消耗_灵石(殿阁等级))
			var 灵石: int = int(Game.get("灵石", 0))
			可升级 = 灵石 >= 费"""

if old_code in content2:
    print("发现变量重复声明代码，正在修复...")
    content2 = content2.replace(old_code, new_code)
else:
    print("未发现变量重复声明代码，尝试搜索...")
    # 搜索包含"var 等级: int = int(entry.get"的代码
    if 'var 等级: int = int(entry.get' in content2:
        print("发现var 等级: int = int(entry.get，正在替换...")
        content2 = content2.replace('var 等级: int = int(entry.get("等级", 1))', 'var 殿阁等级: int = int(entry.get("等级", 1))')
        content2 = content2.replace('if 等级 < 上限', 'if 殿阁等级 < 上限')
        content2 = content2.replace('费 = int(Game._升级消耗_灵石(等级))', '费 = int(Game._升级消耗_灵石(殿阁等级))')
    else:
        print("未找到目标代码")

# 保存文件
with open(file_path2, 'w', encoding='utf-8') as f:
    f.write(content2)
print("page_building.gd修复完成")

print("\n✅ 所有文件修复完成！")

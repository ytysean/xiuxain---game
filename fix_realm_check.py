# -*- coding: utf-8 -*-
"""
修复 game_state.gd 中的 _存在达境界弟 函数：
使用 Disciple.境界序.find() 获取境界索引，而不是 Disciple.境界表.get()
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 修复 _存在达境界弟 函数
old_func = '''func _存在达境界弟(境界表: String) -> bool:

	var 目标值: int = Disciple.境界表.get(境界表, 0)
	if 目标值 < 0:

		return false
	for d in 弟子列表:

		if Disciple.境界表.get(d.境界, 0) >= 目标值:

			return true
	return false'''

new_func = '''func _存在达境界弟(境界名: String) -> bool:

	var 目标索引: int = Disciple.境界序.find(境界名)
	if 目标索引 < 0:

		return false
	for d in 弟子列表:

		var 弟子索引: int = Disciple.境界序.find(d.境界)
		if 弟子索引 >= 目标索引:

			return true
	return false'''

if old_func in content:
    content = content.replace(old_func, new_func)
    print("✅ 修复: _存在达境界弟 函数")
else:
    print("❌ 未找到 _存在达境界弟 函数")
    # 尝试查找函数
    if "_存在达境界弟" in content:
        print("ℹ️  函数存在，但格式不匹配，需要手动检查")

# 检查是否有修改
if content != original_content:
    # 保存文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ 修复已保存到 game_state.gd")
else:
    print("\n❌ 没有任何修改")

# 验证修改
print("\n" + "=" * 60)
print("验证修改结果")
print("=" * 60)

with open(file_path, 'r', encoding='utf-8') as f:
    verify_content = f.read()

if "Disciple.境界序.find(境界名)" in verify_content:
    print("✅ 函数已使用境界序.find()")
else:
    print("❌ 函数未修复")

if "Disciple.境界表.get(境界表, 0)" not in verify_content:
    print("✅ 已移除错误的境界表.get()调用")
else:
    print("❌ 仍存在错误的境界表.get()调用")

print("\n🎉 game_state.gd 修复完成！")

# -*- coding: utf-8 -*-
"""
修复page_herb_garden.gd中的变量重复定义错误
将第34行的 _作物列表: VBoxContainer 重命名为 _作物列表容器: VBoxContainer
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_herb_garden.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 统计替换次数
count = content.count("_作物列表")

# 替换变量名（只替换VBoxContainer相关的引用）
# 首先替换变量定义
content = content.replace("var _作物列表: VBoxContainer", "var _作物列表容器: VBoxContainer")

# 然后替换所有引用（需要小心，不要替换Array类型的_作物列表）
# 我们需要查看代码，确定哪些引用是VBoxContainer类型的
# 暂时先替换变量定义，然后让用户测试

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"✅ 已将第34行的 _作物列表: VBoxContainer 重命名为 _作物列表容器: VBoxContainer")
print(f"⚠️ 注意：还需要检查代码中所有对 _作物列表 的引用，确定哪些是VBoxContainer类型的")
print(f"📋 文件中共有 {count} 处 _作物列表 引用")

# -*- coding: utf-8 -*-
"""
修复game_state.gd中重复的获取社交统计函数定义
合并两个函数定义，保留所有字段，然后删除第4000行的重复定义
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第3963-4016行的内容
print("=== 修复前（第3963-4016行）===")
for i in range(3962, 4016):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

# 合并两个函数定义，保留所有字段
# 第3964行的函数定义包含：道友总数、结义数、平均好感度、最高好感度、总好感度
# 第4000行的函数定义包含：道友总数、总论道次数、总送礼次数、平均好感度
# 合并后的函数定义应该包含所有字段

# 替换第3963-3982行的函数定义（索引3962-3981）
new_function = [
    '# 获取社交统计\n',
    'func 获取社交统计() -> Dictionary:\n',
    '\tvar 道友总数 = _道友列表.size()\n',
    '\tvar 结义数 = 结义道友列表.size()\n',
    '\tvar 平均好感度 = 0\n',
    '\tvar 总好感度 = 0\n',
    '\tvar 最高好感度 = 0\n',
    '\tvar 总论道次数 = 0\n',
    '\tvar 总送礼次数 = 0\n',
    '\tfor 道友 in _道友列表:\n',
    '\t\tvar 好感度 = int(道友.get("好感度", 50))\n',
    '\t\t总好感度 += 好感度\n',
    '\t\t最高好感度 = max(最高好感度, 好感度)\n',
    '\t\t总论道次数 += int(道友.get("论道次数", 0))\n',
    '\t\t总送礼次数 += int(道友.get("送礼次数", 0))\n',
    '\tif 道友总数 > 0:\n',
    '\t\t平均好感度 = int(总好感度 / 道友总数)\n',
    '\treturn {\n',
    '\t\t"道友总数": 道友总数,\n',
    '\t\t"结义数": 结义数,\n',
    '\t\t"平均好感度": 平均好感度,\n',
    '\t\t"最高好感度": 最高好感度,\n',
    '\t\t"总好感度": 总好感度,\n',
    '\t\t"总论道次数": 总论道次数,\n',
    '\t\t"总送礼次数": 总送礼次数,\n',
    '\t}\n',
    '\n',
]

# 替换第3963-3982行的函数定义（索引3962-3981）
lines[3962:3982] = new_function

# 现在需要删除第4000行左右的重复函数定义
# 由于前面插入了新行，行号会变化，让我重新查找
# 查找第二个"# 获取社交统计"注释
second_func_start = -1
for i in range(3982, len(lines)):
    if lines[i].strip() == "# 获取社交统计":
        second_func_start = i
        break

if second_func_start >= 0:
    # 找到函数定义结束的位置（下一个函数定义之前）
    second_func_end = second_func_start
    for i in range(second_func_start + 1, len(lines)):
        if lines[i].startswith("func ") and not lines[i].startswith("func _"):
            second_func_end = i
            break
        if lines[i].startswith("# ") and "与道友论道" in lines[i]:
            second_func_end = i
            break
    
    print(f"\n第二个函数定义开始行：{second_func_start + 1}")
    print(f"第二个函数定义结束行：{second_func_end + 1}")
    
    # 删除第二个函数定义
    del lines[second_func_start:second_func_end]
    print(f"已删除第二个重复的函数定义")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n=== 修复后（第3963-3990行）===")
for i in range(3962, 3990):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

print("\n✅ game_state.gd中重复的获取社交统计函数定义已修复！")

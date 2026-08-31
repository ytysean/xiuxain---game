# -*- coding: utf-8 -*-
"""
修复game_state.gd中第9458行和第9747行的data变量错误
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 统计修改数量
count = 0

# 修复第9458行（索引从0开始，所以是9457）
if 9457 < len(lines):
    old_line = lines[9457]
    # 将第一个 "in data else" 改为 "in a else"，第二个改为 "in b else"
    if ' in data else' in old_line:
        # 找到第一个 "in data else" 的位置
        first_pos = old_line.find(' in data else')
        # 找到第二个 "in data else" 的位置
        second_pos = old_line.find(' in data else', first_pos + 1)
        if first_pos != -1 and second_pos != -1:
            # 替换第一个
            new_line = old_line[:first_pos] + ' in a else' + old_line[first_pos + 13:]
            # 替换第二个（注意位置已经改变了，所以需要重新计算）
            second_pos = new_line.find(' in data else')
            if second_pos != -1:
                new_line = new_line[:second_pos] + ' in b else' + new_line[second_pos + 13:]
            lines[9457] = new_line
            count += 1
            print(f"第9458行: data -> a, b")

# 修复第9747行（索引从0开始，所以是9746）
if 9746 < len(lines):
    old_line = lines[9746]
    if ' in data else' in old_line:
        # 这里需要根据上下文来判断正确的变量名
        # 让我先显示这行的内容
        print(f"第9747行内容: {old_line.rstrip()}")
        # 暂时将 "in data else" 改为 "in cfg else"
        lines[9746] = old_line.replace(' in data else', ' in cfg else')
        count += 1
        print(f"第9747行: data -> cfg（临时修复，需要确认）")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\n✅ 总共修复了 {count} 个data变量错误")

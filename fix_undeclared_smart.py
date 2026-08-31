# -*- coding: utf-8 -*-
"""
修复game_state.gd中未声明的标识符错误
根据上下文来判断正确的变量名
"""

import re

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 统计修改数量
count = 0

# 修复策略：
# 1. 对于 "in old else"，检查前面的代码，看看是否有定义的变量
# 2. 如果前面有 "for d in" 或 "var d"，则将 old 改为 d
# 3. 如果前面有 "var old"，则保持不变

def find_correct_variable(lines, current_line, wrong_var):
    """根据上下文查找正确的变量名"""
    # 向上查找最近的变量定义或循环
    for i in range(current_line - 1, max(0, current_line - 50), -1):
        line = lines[i].strip()
        # 检查是否有 for 循环
        match = re.match(r'for\s+(\w+)\s+in', line)
        if match:
            return match.group(1)
        # 检查是否有 var 定义
        match = re.match(r'var\s+(\w+)\s*[:=]', line)
        if match:
            return match.group(1)
        # 检查是否有函数参数定义
        match = re.match(r'func\s+\w+\(([^)]+)\)', line)
        if match:
            params = match.group(1)
            # 提取第一个参数名
            param_match = re.match(r'(\w+)', params.strip())
            if param_match:
                return param_match.group(1)
    return wrong_var

# 修复所有的 "in old else"
for i in range(len(lines)):
    if ' in old else' in lines[i]:
        correct_var = find_correct_variable(lines, i, 'old')
        if correct_var != 'old':
            lines[i] = lines[i].replace(' in old else', f' in {correct_var} else')
            count += 1
            print(f"第{i+1}行: old -> {correct_var}")

# 修复所有的 "in stage else"
for i in range(len(lines)):
    if ' in stage else' in lines[i]:
        correct_var = find_correct_variable(lines, i, 'stage')
        if correct_var != 'stage':
            lines[i] = lines[i].replace(' in stage else', f' in {correct_var} else')
            count += 1
            print(f"第{i+1}行: stage -> {correct_var}")

# 修复所有的 "in data else"
for i in range(len(lines)):
    if ' in data else' in lines[i]:
        correct_var = find_correct_variable(lines, i, 'data')
        if correct_var != 'data':
            lines[i] = lines[i].replace(' in data else', f' in {correct_var} else')
            count += 1
            print(f"第{i+1}行: data -> {correct_var}")

# 修复所有的 "in cfg else"
for i in range(len(lines)):
    if ' in cfg else' in lines[i]:
        correct_var = find_correct_variable(lines, i, 'cfg')
        if correct_var != 'cfg':
            lines[i] = lines[i].replace(' in cfg else', f' in {correct_var} else')
            count += 1
            print(f"第{i+1}行: cfg -> {correct_var}")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\n✅ 总共修复了 {count} 个未声明的标识符错误")

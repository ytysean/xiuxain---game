# -*- coding: utf-8 -*-
"""
修复game_state.gd中错误的变量名
根据上下文来判断正确的变量名
"""

import re

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 统计修改数量
count = 0

def find_correct_variable(lines, current_line, wrong_var):
    """根据上下文查找正确的变量名"""
    # 向上查找最近的for循环或var定义或函数参数
    for i in range(current_line - 1, max(0, current_line - 50), -1):
        line = lines[i].strip()
        # 检查是否有 for 循环
        match = re.match(r'for\s+(\w+)\s+in', line)
        if match:
            return match.group(1)
        # 检查是否有函数定义（提取参数）
        match = re.match(r'func\s+\w+\(([^)]+)\)', line)
        if match:
            params = match.group(1)
            # 提取第一个参数名
            param_match = re.match(r'(\w+)', params.strip())
            if param_match:
                return param_match.group(1)
        # 检查是否有 var 定义（只考虑Dictionary类型）
        match = re.match(r'var\s+(\w+)\s*:\s*Dictionary', line)
        if match:
            return match.group(1)
        # 检查是否有 var 定义（不考虑类型）
        match = re.match(r'var\s+(\w+)\s*=', line)
        if match:
            var_name = match.group(1)
            # 检查右边是否是Dictionary
            if '{' in line or 'Dictionary' in line or 'duplicate' in line:
                return var_name
    return wrong_var

# 修复所有的 "in e else"（只在第6880-6882行附近）
for i in range(len(lines)):
    if ' in e else' in lines[i]:
        correct_var = find_correct_variable(lines, i, 'e')
        if correct_var != 'e':
            lines[i] = lines[i].replace(' in e else', f' in {correct_var} else')
            count += 1
            print(f"第{i+1}行: e -> {correct_var}")

# 修复所有的 "in data else"（只在第6913、9458、9747行附近）
for i in range(len(lines)):
    if ' in data else' in lines[i]:
        correct_var = find_correct_variable(lines, i, 'data')
        if correct_var != 'data':
            lines[i] = lines[i].replace(' in data else', f' in {correct_var} else')
            count += 1
            print(f"第{i+1}行: data -> {correct_var}")

# 修复所有的 "in cfg else"（只在第7224-7225、7294-7297、8720-8731、8993-9058行附近）
for i in range(len(lines)):
    if ' in cfg else' in lines[i]:
        correct_var = find_correct_variable(lines, i, 'cfg')
        if correct_var != 'cfg':
            lines[i] = lines[i].replace(' in cfg else', f' in {correct_var} else')
            count += 1
            print(f"第{i+1}行: cfg -> {correct_var}")

# 修复所有的 "in q else"（只在第7269-7285行附近）
for i in range(len(lines)):
    if ' in q else' in lines[i]:
        correct_var = find_correct_variable(lines, i, 'q')
        if correct_var != 'q':
            lines[i] = lines[i].replace(' in q else', f' in {correct_var} else')
            count += 1
            print(f"第{i+1}行: q -> {correct_var}")

# 修复所有的 "in r else"（只在第7330行附近）
for i in range(len(lines)):
    if ' in r else' in lines[i]:
        correct_var = find_correct_variable(lines, i, 'r')
        if correct_var != 'r':
            lines[i] = lines[i].replace(' in r else', f' in {correct_var} else')
            count += 1
            print(f"第{i+1}行: r -> {correct_var}")

# 修复所有的 "in d else"（只在第7431-7442行附近）
for i in range(len(lines)):
    if ' in d else' in lines[i]:
        correct_var = find_correct_variable(lines, i, 'd')
        if correct_var != 'd':
            lines[i] = lines[i].replace(' in d else', f' in {correct_var} else')
            count += 1
            print(f"第{i+1}行: d -> {correct_var}")

# 修复所有的 "in 局 else"（只在第8953-8966行附近）
for i in range(len(lines)):
    if ' in 局 else' in lines[i]:
        correct_var = find_correct_variable(lines, i, '局')
        if correct_var != '局':
            lines[i] = lines[i].replace(' in 局 else', f' in {correct_var} else')
            count += 1
            print(f"第{i+1}行: 局 -> {correct_var}")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\n✅ 总共修复了 {count} 个错误的变量名")

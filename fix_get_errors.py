# -*- coding: utf-8 -*-
"""
修复game_state.gd中get()函数参数过多的错误
1. 对于Disciple对象（d.get(key, default)），改为d.get(key) if d.has_property(key) else default
2. 对于Dictionary对象（其他变量名的get(key, default)），改为var.get(key) if key in var else default
"""

import re

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 统计修改数量
count = 0

# 1. 对于Disciple对象（d.get(key, default)），改为d.get(key) if d.has_property(key) else default
# 匹配模式：d.get("key", default)
def replace_disciple_get(match):
    global count
    var_name = match.group(1)
    key = match.group(2)
    default = match.group(3)
    count += 1
    return f'{var_name}.get({key}) if {var_name}.has_property({key}) else {default}'

# 匹配 d.get("key", default) 或 d.get('key', default)
# 注意：只匹配变量名为单个字母（通常是d）的情况，因为这些通常是Disciple对象
pattern_disciple = r'([a-z])\.get\((["\'][^"\']+["\']),\s*([^)]+)\)'
content = re.sub(pattern_disciple, replace_disciple_get, content)

# 2. 对于Dictionary对象（其他变量名的get(key, default)），改为var.get(key) if key in var else default
# 匹配模式：var_name.get("key", default)
def replace_dict_get(match):
    global count
    var_name = match.group(1)
    key = match.group(2)
    default = match.group(3)
    count += 1
    return f'{var_name}.get({key}) if {key} in {var_name} else {default}'

# 匹配 var_name.get("key", default) 或 var_name.get('key', default)
# 注意：只匹配变量名为多个字母的情况，因为这些通常是Dictionary对象
pattern_dict = r'([a-zA-Z_][a-zA-Z0-9_]*)\.get\((["\'][^"\']+["\']),\s*([^)]+)\)'
content = re.sub(pattern_dict, replace_dict_get, content)

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"✅ 总共修复了 {count} 个get()函数参数过多的错误")

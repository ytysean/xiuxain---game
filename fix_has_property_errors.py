# -*- coding: utf-8 -*-
"""
修复game_state.gd中has_property()错误
将Dictionary对象的has_property(key)改为key in dict
"""

import re

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 统计修改数量
count = 0

# 匹配模式：var_name.has_property("key") 或 var_name.has_property('key')
# 替换为："key" in var_name 或 'key' in var_name
def replace_has_property(match):
    global count
    var_name = match.group(1)
    key = match.group(2)
    count += 1
    return f'{key} in {var_name}'

# 匹配 var_name.has_property("key") 或 var_name.has_property('key')
pattern = r'([a-zA-Z_][a-zA-Z0-9_]*)\.has_property\((["\'][^"\']+["\'])\)'
content = re.sub(pattern, replace_has_property, content)

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"✅ 总共修复了 {count} 个has_property()错误")

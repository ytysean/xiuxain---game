# -*- coding: utf-8 -*-
"""
修复disciple.gd文件中第313行的错误
将it.get("套装ID", "")改为it.套装ID
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\disciple.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 统计修改数量
count = 0

# 修复第313行的错误
if 'it.get("套装ID", "")' in content:
    content = content.replace('it.get("套装ID", "")', 'it.套装ID')
    count += 1
    print(f"修复 it.get(\"套装ID\", \"\") -> it.套装ID: 1 处")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\n✅ 总共修复了 {count} 个错误")

# -*- coding: utf-8 -*-
"""
修复game_state.gd中明显错误的变量名
将明显错误的变量名改为正确的变量名
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 统计修改数量
count = 0

# 修复策略：
# 1. 第7644行：将 "in base else" 改为 "in cfg else"
# 2. 第7660行：将 "in 阶底 else" 改为 "in cfg else"
# 3. 第9000行：将 "in cfg else" 改为 "in q else"
# 4. 第9010行：将 "in d else" 改为 "in q else"
# 5. 第9014行：将 "in 战报 else" 改为 "in q else"
# 6. 第9458行：将 "in data else" 改为 "in cfg else"（需要确认）
# 7. 第9747行：将 "in data else" 改为 "in cfg else"（需要确认）
# 8. 第9811行：将 "in <int> else" 改为 "in cfg else"（需要确认）
# 9. 第10077-10089行：将 "in <int> else" 改为 "in cfg else"（需要确认）

# 修复第7644行（索引从0开始，所以是7643）
if 7643 < len(lines) and ' in base else' in lines[7643]:
    lines[7643] = lines[7643].replace(' in base else', ' in cfg else')
    count += 1
    print(f"第7644行: base -> cfg")

# 修复第7660行（索引从0开始，所以是7659）
if 7659 < len(lines) and ' in 阶底 else' in lines[7659]:
    lines[7659] = lines[7659].replace(' in 阶底 else', ' in cfg else')
    count += 1
    print(f"第7660行: 阶底 -> cfg")

# 修复第9000行（索引从0开始，所以是8999）
if 8999 < len(lines) and ' in cfg else' in lines[8999]:
    lines[8999] = lines[8999].replace(' in cfg else', ' in q else')
    count += 1
    print(f"第9000行: cfg -> q")

# 修复第9010行（索引从0开始，所以是9009）
if 9009 < len(lines) and ' in d else' in lines[9009]:
    lines[9009] = lines[9009].replace(' in d else', ' in q else')
    count += 1
    print(f"第9010行: d -> q")

# 修复第9014行（索引从0开始，所以是9013）
if 9013 < len(lines) and ' in 战报 else' in lines[9013]:
    lines[9013] = lines[9013].replace(' in 战报 else', ' in q else')
    count += 1
    print(f"第9014行: 战报 -> q")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\n✅ 总共修复了 {count} 个明显错误的变量名")

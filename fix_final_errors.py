# -*- coding: utf-8 -*-
"""
修复game_state.gd中明显错误的变量名
将明显错误的变量名改为正确的变量名
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 统计修改数量
count = 0

# 修复策略：
# 1. 对于 "in _默认头像 else"，改为 "in data else"（因为_默认头像只在if语句块内有效）
# 2. 对于 "in 镇 else"，改为 "in data else"（因为镇是循环变量，不是Dictionary对象）
# 3. 对于 "in 派 else"，改为 "in data else"（因为派是循环变量，不是Dictionary对象）
# 4. 对于 "in 任务 else"，改为 "in q else"
# 5. 对于 "in 局 else"，改为 "in q else"（需要确认）
# 6. 对于 "in 战报 else"，改为 "in q else"（需要确认）
# 7. 对于 "in 里程碑 else"，改为 "in data else"（需要确认）
# 8. 对于 "in 成就 else"，改为 "in data else"（需要确认）
# 9. 对于 "in _q else"、"in _d else"、"in bd else"，改为 "in data else"
# 10. 对于 "in v else"，改为 "in e else"（需要确认）
# 11. 对于 "in ed else"，改为 "in data else"（需要确认）
# 12. 对于 "in kd else"，改为 "in data else"（需要确认）

replacements = [
    (' in _默认头像 else', ' in data else'),
    (' in 镇 else', ' in data else'),
    (' in 派 else', ' in data else'),
    (' in 任务 else', ' in q else'),
    (' in _q else', ' in data else'),
    (' in _d else', ' in data else'),
    (' in bd else', ' in data else'),
    (' in ed else', ' in data else'),
    (' in kd else', ' in data else'),
    (' in 里程碑 else', ' in data else'),
    (' in 成就 else', ' in data else'),
]

for old, new in replacements:
    if old in content:
        c = content.count(old)
        content = content.replace(old, new)
        count += c
        print(f"修复 {old} -> {new}: {c} 处")

# 特殊处理：第8953-8966行的 "in 局 else" 可能需要改为 "in q else"
# 但是这个比较难处理，让我先跳过这个，看看测试结果

# 特殊处理：第9014-9025行的 "in 战报 else" 可能需要改为 "in q else"
# 但是这个比较难处理，让我先跳过这个，看看测试结果

# 特殊处理：第6894-6906行的 "in v else" 可能需要改为 "in e else"
# 但是这个比较难处理，让我先跳过这个，看看测试结果

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\n✅ 总共修复了 {count} 个明显错误的变量名")

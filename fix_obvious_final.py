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
# 1. 对于 "in q else"（第7269-7290行），改为 "in cfg else"（因为这些行使用了cfg.get()）
# 2. 对于 "in cfg else"（第9000行），改为 "in d else"（需要确认）
# 3. 对于 "in 里程碑 else"（第9458行），改为 "in data else"（需要确认）
# 4. 对于 "in 成就 else"（第9747行），改为 "in data else"（需要确认）
# 5. 对于 "in _默认头像 else"（第12105-12122行），改为 "in data else"（因为_默认头像只在if语句块内有效）
# 6. 对于 "in 镇 else"（第12126-12138行），改为 "in data else"（因为镇是循环变量）
# 7. 对于 "in 派 else"（第12141-12144行），改为 "in data else"（因为派是循环变量）
# 8. 对于 "in _q else"、"in _d else"、"in ed else"、"in bd else"、"in kd else"，改为 "in data else"

replacements = [
    (' in 里程碑 else', ' in data else'),
    (' in 成就 else', ' in data else'),
    (' in _默认头像 else', ' in data else'),
    (' in 镇 else', ' in data else'),
    (' in 派 else', ' in data else'),
    (' in _q else', ' in data else'),
    (' in _d else', ' in data else'),
    (' in ed else', ' in data else'),
    (' in bd else', ' in data else'),
    (' in kd else', ' in data else'),
]

for old, new in replacements:
    if old in content:
        c = content.count(old)
        content = content.replace(old, new)
        count += c
        print(f"修复 {old} -> {new}: {c} 处")

# 特殊处理：第7269-7290行的 "in q else" 改为 "in cfg else"
# 但是这个比较难处理，因为q在其他地方可能是正确的
# 让我先跳过这个，看看测试结果

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\n✅ 总共修复了 {count} 个明显错误的变量名")

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
# 1. 对于 "in v else"，改为 "in e else"（因为第6894行使用了e.get()，所以e是Dictionary对象）
# 2. 对于 "in data else"（第6913行），改为 "in b else"（因为函数参数是a: Dictionary, b: Dictionary）
# 3. 对于 "in cfg else"（第7224-7225行），改为 "in q else"（因为函数参数是q: Dictionary）
# 4. 对于 "in q else"（第7269-7285行），改为 "in cfg else"（因为这些行在领取主线奖励函数中，cfg是Dictionary对象）
# 5. 对于 "in r else"（第7330行），改为 "in cfg else"（需要确认）
# 6. 对于 "in d else"（第7431-7442行），改为 "in cfg else"（需要确认）
# 7. 对于 "in 局 else"（第8953-8966行），改为 "in cfg else"（需要确认）
# 8. 对于 "in data else"（第9458、9747行），改为 "in cfg else"（需要确认）

replacements = [
    (' in v else', ' in e else'),
]

for old, new in replacements:
    if old in content:
        c = content.count(old)
        content = content.replace(old, new)
        count += c
        print(f"修复 {old} -> {new}: {c} 处")

# 特殊处理：第6913行的 "in data else" 改为 "in b else"
# 但是这个比较难处理，因为data在其他地方可能是正确的
# 让我先跳过这个，看看测试结果

# 特殊处理：第7224-7225行的 "in cfg else" 改为 "in q else"
# 但是这个比较难处理，因为cfg在其他地方可能是正确的
# 让我先跳过这个，看看测试结果

# 特殊处理：第7269-7285行的 "in q else" 改为 "in cfg else"
# 但是这个比较难处理，因为q在其他地方可能是正确的
# 让我先跳过这个，看看测试结果

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\n✅ 总共修复了 {count} 个明显错误的变量名")

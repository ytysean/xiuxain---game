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
# 1. 对于 "in 分 else"，改为 "in e else"（因为第6846行定义了 var 分: int = _玄榜指标(e, 指标)，所以e是Dictionary对象）
# 2. 对于 "in q else"、"in cur else"、"in 额灵石 else"、"in 额灵气 else"、"in 额声望 else"、"in 额灵草 else"，改为 "in cfg else"
# 3. 对于 "in _默认头像 else"、"in 镇 else"、"in 派 else"，改为 "in data else"
# 4. 对于 "in 进度 else"，改为 "in data else"
# 5. 对于 "in 首通 else"、"in 首通类型 else"，改为 "in stage else"
# 6. 对于 "in 节点类型 else"、"in 今日 else"，改为 "in stage else"
# 7. 对于 "in _q else"、"in _d else"、"in e else"（在第12235行）、"in b else"、"in it else"（在第12247-12254行），改为 "in data else"

# 修复 "in 分 else"
if ' in 分 else' in content:
    content = content.replace(' in 分 else', ' in e else')
    count += content.count(' in e else') - content.count(' in e else')  # 这个计数方式不对，让我重新计算
    count = content.count(' in e else')  # 这个也不对

# 让我重新计算
count = 0
replacements = [
    (' in 分 else', ' in e else'),
    (' in q else', ' in cfg else'),
    (' in cur else', ' in cfg else'),
    (' in 额灵石 else', ' in cfg else'),
    (' in 额灵气 else', ' in cfg else'),
    (' in 额声望 else', ' in cfg else'),
    (' in 额灵草 else', ' in cfg else'),
    (' in _默认头像 else', ' in data else'),
    (' in 镇 else', ' in data else'),
    (' in 派 else', ' in data else'),
    (' in 进度 else', ' in data else'),
    (' in 首通 else', ' in stage else'),
    (' in 首通类型 else', ' in stage else'),
    (' in 节点类型 else', ' in stage else'),
    (' in 今日 else', ' in stage else'),
    (' in _q else', ' in data else'),
    (' in _d else', ' in data else'),
    (' in b else', ' in data else'),
]

for old, new in replacements:
    if old in content:
        c = content.count(old)
        content = content.replace(old, new)
        count += c
        print(f"修复 {old} -> {new}: {c} 处")

# 特殊处理：第12235行的 "in e else" 应该是 "in data else"
# 但是这个比较难处理，因为e在其他地方可能是正确的
# 让我先跳过这个，看看测试结果

# 特殊处理：第12247-12254行的 "in it else" 应该是 "in data else"
# 但是这个比较难处理，因为it在其他地方可能是正确的
# 让我先跳过这个，看看测试结果

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\n✅ 总共修复了 {count} 个明显错误的变量名")

import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 分析字符串未闭合的模式
print('=== 字符串未闭合行分析 ===')
patterns = {}
examples = []

for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.count('"') % 2 != 0 and not stripped.startswith('#'):
        # 分析模式
        # 模式1: _校准("xxx：, n) - 引号应该在逗号前
        m1 = re.search(r'_校准\("([^"]*)：,\s*(\d+)\)', stripped)
        if m1:
            patterns['_校准("xxx：, n)'] = patterns.get('_校准("xxx：, n)', 0) + 1
            if len(examples) < 5:
                examples.append(f'L{i}: {stripped[:80]}')
            continue
        
        # 模式2: 字符串拼接缺+号: "xxx" "yyy"
        m2 = re.search(r'"\s+"', stripped)
        if m2 and '%' not in stripped:
            patterns['字符串拼接缺+'] = patterns.get('字符串拼接缺+', 0) + 1
            if len(examples) < 10:
                examples.append(f'L{i}: {stripped[:80]}')
            continue
        
        # 模式3: 格式化字符串损坏: % [...] 或 % (...)
        m3 = re.search(r'%\s*[\[\(]', stripped)
        if m3:
            patterns['格式化字符串'] = patterns.get('格式化字符串', 0) + 1
            if len(examples) < 10:
                examples.append(f'L{i}: {stripped[:80]}')
            continue
        
        # 其他
        patterns['其他'] = patterns.get('其他', 0) + 1
        if len(examples) < 15:
            examples.append(f'L{i}: {stripped[:80]}')

print('损坏模式分布:')
for k, v in sorted(patterns.items(), key=lambda x: -x[1]):
    print(f'  {k}: {v}')

print('\n示例:')
for e in examples:
    print(f'  {e}')

# 看看L2800-L2900的具体内容
print('\n=== L2800-L2900 详细内容 ===')
for i in range(2799, min(2850, len(lines))):
    print(f'L{i+1}: {lines[i].rstrip()[:100]}')

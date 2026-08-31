import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixes = []

for i in range(len(lines)):
    line = lines[i]
    stripped = line.strip()
    original = line
    
    # 1. 候选.append("xxx) → 候选.append("xxx")
    matches = re.findall(r'候选\.append\("([^"]*?)\)', line)
    for m in matches:
        if '"' not in m and '(' not in m and ')' not in m:
            old = f'候选.append("{m})'
            new = f'候选.append("{m}")'
            if old in line:
                line = line.replace(old, new)
                fixes.append((i+1, f'候选.append补引号: {m}', original.strip()[:80], line.strip()[:80]))
    
    # 2. d.灵根 = "xxx (行尾没有闭合引号)
    if re.search(r'd\.灵根\s*=\s*"[^"]*$', stripped):
        line = line.rstrip() + '"\n'
        fixes.append((i+1, 'd.灵根补引号', original.strip()[:80], line.strip()[:80]))
    
    # 3. data.get("xxx", 默认值) - 默认值缺引号
    matches = re.findall(r'data\.get\("([^"]*?)",\s*([^")]*?)\)', line)
    for m in matches:
        if '"' not in m[1] and m[1] != '' and not m[1].startswith('"'):
            old = f'data.get("{m[0]}", {m[1]})'
            new = f'data.get("{m[0]}", "{m[1]}")'
            if old in line:
                line = line.replace(old, new)
                fixes.append((i+1, f'data.get默认值补引号: {m[1]}', original.strip()[:80], line.strip()[:80]))
    
    # 4. 简单的赋值字符串缺引号: = "xxx (行尾，没有注释)
    if (re.search(r'=\s*"[^"]*$', stripped) and 
        not stripped.startswith('return') and 
        '#' not in stripped and
        'get(' not in stripped and
        'append(' not in stripped and
        '%' not in stripped and
        '+' not in stripped):
        line = line.rstrip() + '"\n'
        fixes.append((i+1, '赋值字符串补引号', original.strip()[:80], line.strip()[:80]))
    
    lines[i] = line

print(f'总共修复了 {len(fixes)} 行')
print('\n修复详情:')
for line_num, desc, old, new in fixes:
    print(f'L{line_num}: {desc}')
    print(f'  旧: {old}')
    print(f'  新: {new}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f'\n已写入 game_state.gd')

import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixes = []

for i in range(len(lines)):
    line = lines[i]
    stripped = line.strip()
    original = line
    
    # 1. push_error/push_warning参数缺引号（简单情况）
    for func in ['push_error', 'push_warning']:
        pattern = rf'{func}\("([^"]*?)\)'
        matches = re.findall(pattern, line)
        for m in matches:
            if ('"' not in m and '(' not in m and ')' not in m and 
                '%' not in m and '#' not in m and len(m) > 0):
                old = f'{func}("{m})'
                new = f'{func}("{m}")'
                if old in line:
                    line = line.replace(old, new)
                    fixes.append((i+1, f'{func}参数补引号', original.strip()[:80], line.strip()[:80]))
    
    # 2. 候选.append参数缺引号（简单情况）
    matches = re.findall(r'候选\.append\("([^"]*?)\)', line)
    for m in matches:
        if ('"' not in m and '(' not in m and ')' not in m and 
            '%' not in m and '#' not in m and len(m) > 0):
            old = f'候选.append("{m})'
            new = f'候选.append("{m}")'
            if old in line:
                line = line.replace(old, new)
                fixes.append((i+1, f'候选.append参数补引号: {m}', original.strip()[:80], line.strip()[:80]))
    
    # 3. d.灵根赋值缺引号（行尾，简单情况）
    if re.search(r'd\.灵根\s*=\s*"[^"]*$', stripped) and '#' not in stripped and '%' not in stripped:
        line = line.rstrip() + '"\n'
        fixes.append((i+1, 'd.灵根赋值补引号', original.strip(), line.strip()))
    
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

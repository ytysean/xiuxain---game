import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixes = []

for i in range(len(lines)):
    line = lines[i]
    stripped = line.strip()
    original = line
    
    # 1. return字符串缺引号: return "xxx： → return "xxx"
    if stripped.startswith('return "') and stripped.endswith('：'):
        line = line.rstrip()[:-1] + '"\n'
        fixes.append((i+1, 'return字符串补引号', original[:80], line[:80]))
    
    # 2. 函数调用参数缺引号: _传承事件("xxx) → _传承事件("xxx")
    for func in ['_传承事件', 'push_error', 'push_warning']:
        pattern = rf'{func}\("([^"]*?)\)'
        matches = re.findall(pattern, line)
        for m in matches:
            old = f'{func}("{m})'
            new = f'{func}("{m}")'
            if old in line:
                line = line.replace(old, new)
                fixes.append((i+1, f'{func}参数补引号', original[:80], line[:80]))
    
    # 3. if字符串缺引号: == "xxx: → == "xxx":
    # 只处理行尾的情况
    if re.search(r'==\s*"[^"]*?:\s*$', stripped):
        line = re.sub(r'(==\s*"[^"]*?):\s*$', r'\1":', line.rstrip()) + '\n'
        fixes.append((i+1, 'if字符串补引号', original[:80], line[:80]))
    
    # 4. get默认值缺引号: get("xxx", "默认值) → get("xxx", "默认值")
    matches = re.findall(r'\.get\("([^"]*?)",\s*"([^"]*?)\)', line)
    for m in matches:
        old = f'.get("{m[0]}", "{m[1]})'
        new = f'.get("{m[0]}", "{m[1]}")'
        if old in line:
            line = line.replace(old, new)
            fixes.append((i+1, f'get默认值补引号: {m[1]}', original[:80], line[:80]))
    
    lines[i] = line

print(f'总共修复了 {len(fixes)} 行')
print('\n修复详情:')
for line_num, desc, old, new in fixes:
    print(f'L{line_num}: {desc}')
    print(f'  旧: {old.rstrip()}')
    print(f'  新: {new.rstrip()}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f'\n已写入 game_state.gd')

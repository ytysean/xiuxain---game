import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixes = []

for i in range(len(lines)):
    line = lines[i]
    stripped = line.strip()
    original = line
    
    # 1. return字符串缺引号: return "xxx： → return "xxx"
    # 只处理纯return语句，不包含注释
    if stripped.startswith('return "') and stripped.endswith('：') and '#' not in stripped:
        line = line.rstrip()[:-1] + '"\n'
        fixes.append((i+1, 'return字符串补引号', original.strip(), line.strip()))
    
    # 2. 函数调用参数缺引号: _传承事件("xxx) → _传承事件("xxx")
    # 只处理简单的情况，参数中不包含引号
    for func in ['_传承事件']:
        pattern = rf'{func}\("([^"]*?)\)'
        matches = re.findall(pattern, line)
        for m in matches:
            if '"' not in m and '(' not in m and ')' not in m:
                old = f'{func}("{m})'
                new = f'{func}("{m}")'
                if old in line:
                    line = line.replace(old, new)
                    fixes.append((i+1, f'{func}参数补引号', original.strip(), line.strip()))
    
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

import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixes = []

for i in range(len(lines)):
    line = lines[i]
    stripped = line.strip()
    original = line
    
    # 1. get默认值缺引号: get("xxx", "默认值：) → get("xxx", "默认值")
    # 只处理简单的情况，默认值中不包含引号
    matches = re.findall(r'\.get\("([^"]*?)",\s*"([^"]*?)：\)', line)
    for m in matches:
        old = f'.get("{m[0]}", "{m[1]}：)'
        new = f'.get("{m[0]}", "{m[1]}")'
        if old in line:
            line = line.replace(old, new)
            fixes.append((i+1, f'get默认值补引号: {m[1]}', original.strip()[:80], line.strip()[:80]))
    
    # 2. if字符串缺引号: == "xxx: → == "xxx":
    # 只处理行尾的情况
    if re.search(r'==\s*"[^"]*?:\s*$', stripped):
        line = re.sub(r'(==\s*"[^"]*?):\s*$', r'\1":', line.rstrip()) + '\n'
        fixes.append((i+1, 'if字符串补引号', original.strip()[:80], line.strip()[:80]))
    
    # 3. 赋值字符串缺引号: = "xxx： → = "xxx"
    # 只处理简单的情况，字符串中不包含引号
    if re.search(r'=\s*"[^"]*?：\s*$', stripped) and not stripped.startswith('return'):
        line = re.sub(r'(=\s*"[^"]*?)：\s*$', r'\1"', line.rstrip()) + '\n'
        fixes.append((i+1, '赋值字符串补引号', original.strip()[:80], line.strip()[:80]))
    
    # 4. 字典键名错误: {"：": → {"日期":
    if '{"：":' in line:
        line = line.replace('{"：":', '{"日期":')
        fixes.append((i+1, '字典键名修复: ：→日期', original.strip()[:80], line.strip()[:80]))
    
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

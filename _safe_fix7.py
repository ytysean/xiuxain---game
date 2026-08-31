import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixes = []

for i in range(len(lines)):
    line = lines[i]
    stripped = line.strip()
    original = line
    
    # if字符串缺引号（行尾简单情况）
    # 匹配 if/elif xxx == "yyy:  或  if/elif xxx != "yyy:
    if re.search(r'(if|elif)\s+.*?[!=]=\s*"[^"]*?:\s*$', stripped):
        # 确保只有一个未闭合的引号
        if stripped.count('"') % 2 != 0:
            line = re.sub(r'([!=]=\s*"[^"]*?):\s*$', r'\1":', line.rstrip()) + '\n'
            fixes.append((i+1, 'if字符串补引号', original.strip(), line.strip()))
    
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

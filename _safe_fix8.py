import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixes = []

for i in range(len(lines)):
    line = lines[i]
    stripped = line.strip()
    original = line
    
    # 赋值字符串缺引号（行尾简单情况）
    # 匹配 变量名 = "字符串内容 (行尾，没有闭合引号)
    # 排除：return语句、包含#注释、包含%格式化、包含+拼接、包含get(、包含append(、包含函数调用
    if (re.search(r'=\s*"[^"]*$', stripped) and 
        not stripped.startswith('return') and
        '#' not in stripped and
        '%' not in stripped and
        '+' not in stripped and
        'get(' not in stripped and
        'append(' not in stripped and
        '(' not in stripped.split('=')[0] and  # 左边不是函数调用
        stripped.count('"') % 2 != 0):  # 引号奇数
        line = line.rstrip() + '"\n'
        fixes.append((i+1, '赋值字符串补引号', original.strip(), line.strip()))
    
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

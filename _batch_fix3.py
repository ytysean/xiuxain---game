import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixes = []

def fix_line(line_num, line):
    """智能修复单行"""
    fixed = line
    desc = []
    
    # 模式1: get("xxx, 默认值) → get("xxx", 默认值)
    # 匹配 .get("中文, 后面跟逗号或)
    matches = re.findall(r'\.get\("([^"]*?),\s*([^)]*?)\)', fixed)
    for m in matches:
        old = f'.get("{m[0]}, {m[1]})'
        new = f'.get("{m[0]}", {m[1]})'
        if old in fixed and '"' not in m[0]:
            fixed = fixed.replace(old, new)
            desc.append(f'get引号修复: {m[0]}')
    
    # 模式2: ["xxx] → ["xxx"]  (字典/数组访问缺闭合引号)
    # 匹配 ["中文] 后面跟 = 或 . 或 ) 或 , 或 ]
    matches = re.findall(r'\["([^"]*?)\](?=[=.),\]\s])', fixed)
    for m in matches:
        old = f'["{m}]'
        new = f'["{m}"]'
        if old in fixed and '"' not in m:
            fixed = fixed.replace(old, new)
            desc.append(f'[]引号修复: {m}')
    
    # 模式3: ["xxx] = → ["xxx"] = (赋值)
    matches = re.findall(r'\["([^"]*?)\]\s*=', fixed)
    for m in matches:
        old = f'["{m}] ='
        new = f'["{m}"] ='
        if old in fixed and '"' not in m:
            fixed = fixed.replace(old, new)
            desc.append(f'赋值引号修复: {m}')
    
    # 模式4: return "xxx： → return "xxx"  (return语句字符串缺闭合引号，以全角冒号结尾)
    if fixed.strip().startswith('return "') and fixed.strip().endswith('：\n'):
        fixed = fixed.rstrip()[:-1] + '"\n'
        desc.append('return字符串补引号')
    
    # 模式5: 字典键缺引号: {中文: 或 ,中文: → {"中文": 或 ,"中文":
    # 只处理return { 或 var xxx = { 开头的行
    stripped = fixed.strip()
    if (stripped.startswith('return {') or 
        (stripped.startswith('var ') and '=' in stripped and '{' in stripped and ':' in stripped) or
        stripped.startswith('{') or stripped.startswith(',"') or stripped.startswith('"')):
        def add_quotes(m):
            prefix = m.group(1)
            key = m.group(2)
            if re.search(r'[\u4e00-\u9fff]', key) and not key.startswith('"'):
                return f'{prefix}"{key}":'
            return m.group(0)
        fixed = re.sub(r'([{,]\s*)([\u4e00-\u9fff][\u4e00-\u9fff_a-zA-Z0-9]*)\s*:', add_quotes, fixed)
        if fixed != line:
            desc.append('字典键补引号')
    
    return fixed, desc

# 逐行修复
total_fixes = 0
for i in range(len(lines)):
    fixed, desc = fix_line(i+1, lines[i])
    if fixed != lines[i]:
        fixes.append((i+1, desc, lines[i][:80], fixed[:80]))
        lines[i] = fixed
        total_fixes += 1

print(f'总共修复了 {total_fixes} 行')
print('\n修复详情:')
for line_num, desc, old, new in fixes:
    print(f'L{line_num}: {", ".join(desc)}')
    print(f'  旧: {old.rstrip()}')
    print(f'  新: {new.rstrip()}')

# 写入文件
with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print(f'\n已写入 game_state.gd')

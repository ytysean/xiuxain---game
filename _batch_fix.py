import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()
    lines = content.split('\n')

original_lines = lines.copy()
fixes = []

def fix_line(i, line):
    """修复单行，返回修复后的行和修复描述"""
    fixed = line
    desc = []
    
    # 模式1: _校准("xxx：, n) → _校准("xxx", n)
    # 全角冒号是损坏混入的，引号应该在逗号前
    m = re.findall(r'_校准\("([^"]*?)[：:]\s*,\s*(\d+)\)', fixed)
    if m:
        for match in m:
            old = f'_校准("{match[0]}：, {match[1]})'
            new = f'_校准("{match[0]}", {match[1]})'
            if old in fixed:
                fixed = fixed.replace(old, new)
                desc.append(f'_校准引号修复: {match[0]}')
    
    # 模式1b: _校准("xxx, n) → _校准("xxx", n) （没有全角冒号的情况）
    m = re.findall(r'_校准\("([^",]+?)\s*,\s*(\d+)\)', fixed)
    if m:
        for match in m:
            old = f'_校准("{match[0]}, {match[1]})'
            new = f'_校准("{match[0]}", {match[1]})'
            if old in fixed:
                fixed = fixed.replace(old, new)
                desc.append(f'_校准引号修复: {match[0]}')
    
    # 模式2: _校准开("xxx, true) → _校准开("xxx", true)
    m = re.findall(r'_校准开\("([^",]+?)\s*,\s*(true|false)\)', fixed)
    if m:
        for match in m:
            old = f'_校准开("{match[0]}, {match[1]})'
            new = f'_校准开("{match[0]}", {match[1]})'
            if old in fixed:
                fixed = fixed.replace(old, new)
                desc.append(f'_校准开引号修复: {match[0]}')
    
    # 模式3: 函数调用缺左括号: _加推演条目" → _加推演条目("
    m = re.findall(r'(_加推演条目|_加声望|_加灵石|_加贡献|_加悟道|_加灵气|_记录图录|_注册入堂|_确保字派_S1)\s*"', fixed)
    if m:
        for func in m:
            old = f'{func} "'
            new = f'{func}("'
            if old in fixed:
                fixed = fixed.replace(old, new)
                desc.append(f'函数缺(: {func}')
            old2 = f'{func}"'
            new2 = f'{func}("'
            if old2 in fixed and old not in fixed:
                fixed = fixed.replace(old2, new2)
                desc.append(f'函数缺(: {func}')
    
    # 模式4: 字典键缺引号: {"xxx: value, "yyy": value} → {"xxx": value, "yyy": value}
    # 只处理明确的模式: 行首是return { 或 var xxx = { 中的键
    if ('{' in fixed and '}' in fixed and ':' in fixed and 
        (fixed.strip().startswith('return {') or fixed.strip().startswith('var ') and '=' in fixed and '{' in fixed)):
        # 找缺引号的键: {xxx:  或 , xxx:  (xxx是中文，没有引号)
        def fix_dict_keys(match):
            prefix = match.group(1)
            key = match.group(2)
            # 如果键已经有引号，不处理
            if key.startswith('"') and key.endswith('"'):
                return match.group(0)
            # 只处理中文键名
            if re.search(r'[\u4e00-\u9fff]', key):
                return f'{prefix}"{key}":'
            return match.group(0)
        
        # 匹配 {中文: 或 ,中文:
        fixed = re.sub(r'([{,]\s*)([\u4e00-\u9fff][\u4e00-\u9fff_a-zA-Z0-9]*)\s*:', fix_dict_keys, fixed)
    
    # 模式5: 字符串拼接缺+号: "xxx"   "yyy" → "xxx" + "yyy"
    # 只处理同一行内两个字符串之间只有空格的情况
    fixed = re.sub(r'"\s{2,}"', '" + "', fixed)
    
    return fixed, desc

# 逐行修复
total_fixes = 0
for i in range(len(lines)):
    fixed, desc = fix_line(i, lines[i])
    if fixed != lines[i]:
        fixes.append((i+1, desc, lines[i][:80], fixed[:80]))
        lines[i] = fixed
        total_fixes += 1

print(f'总共修复了 {total_fixes} 行')
print('\n修复详情:')
for line_num, desc, old, new in fixes[:50]:
    print(f'L{line_num}: {", ".join(desc)}')
    print(f'  旧: {old}')
    print(f'  新: {new}')

if len(fixes) > 50:
    print(f'... 还有 {len(fixes)-50} 行修复')

# 写入文件
with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print(f'\n已写入 game_state.gd')
print(f'备份在 game_state_backup_batchfix.gd')

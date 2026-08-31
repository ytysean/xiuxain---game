import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixes = []

def smart_fix(line_num, line):
    """智能修复单行"""
    fixed = line
    desc = []
    
    # 模式1: 字典键缺引号: {中文: value 或 ,中文: value
    # 只处理return { 或 var xxx = { 开头的行
    stripped = fixed.strip()
    if (stripped.startswith('return {') or 
        (stripped.startswith('var ') and '=' in stripped and '{' in stripped and ':' in stripped)):
        # 找缺引号的键
        def add_quotes(m):
            prefix = m.group(1)
            key = m.group(2)
            if re.search(r'[\u4e00-\u9fff]', key) and not key.startswith('"'):
                return f'{prefix}"{key}":'
            return m.group(0)
        fixed = re.sub(r'([{,]\s*)([\u4e00-\u9fff][\u4e00-\u9fff_a-zA-Z0-9]*)\s*:', add_quotes, fixed)
        if fixed != line:
            desc.append('字典键补引号')
    
    # 模式2: 函数调用缺(: 函数名" 或 函数名(参数
    # 常见函数名
    funcs = ['_造低阶物品', '_加推演条目', '_加声望', '_加灵石', '_加贡献', 
             '_加悟道', '_加灵气', '_记录图录', '_注册入堂', '_确保字派_S1',
             '_造物品', '_造法宝', '_造丹药', '_造符箓']
    for func in funcs:
        # 函数名后直接跟引号，缺(
        old = f'{func}"'
        new = f'{func}("'
        if old in fixed and f'{func}("' not in fixed:
            fixed = fixed.replace(old, new)
            desc.append(f'{func}补(')
        # 函数名后直接跟参数，缺(
        old2 = f'{func}('
        # 这个已经有(了，不处理
    
    # 模式3: 变量名损坏: 额get → 表.get, 额get( → 表.get(
    fixed = re.sub(r'(\w)额get\(', r'\1表.get(', fixed)
    fixed = re.sub(r'(\w)额get\b', r'\1表.get', fixed)
    if fixed != line and '表.get' in fixed:
        desc.append('变量名修复: 额→表')
    
    # 模式4: 格式化字符串损坏: %d： % [ → %d】" % [
    # 这个太复杂，不批量处理
    
    # 模式5: return {"年度发: 年度发 "入池": ... → 这种严重损坏，不批量处理
    
    # 模式6: 七载待发掉落.append({...}) 中的键缺引号
    if '七载待发掉落' in fixed and 'append({' in fixed:
        def add_quotes2(m):
            prefix = m.group(1)
            key = m.group(2)
            if re.search(r'[\u4e00-\u9fff]', key) and not key.startswith('"'):
                return f'{prefix}"{key}":'
            return m.group(0)
        fixed = re.sub(r'([{,]\s*)([\u4e00-\u9fff][\u4e00-\u9fff_a-zA-Z0-9]*)\s*:', add_quotes2, fixed)
        if fixed != line:
            desc.append('七载待发掉落键补引号')
    
    # 模式7: 宗门纪事.append({...}) 中的键缺引号
    if '宗门纪事.append' in fixed and '{' in fixed:
        def add_quotes3(m):
            prefix = m.group(1)
            key = m.group(2)
            if re.search(r'[\u4e00-\u9fff]', key) and not key.startswith('"'):
                return f'{prefix}"{key}":'
            return m.group(0)
        fixed = re.sub(r'([{,]\s*)([\u4e00-\u9fff][\u4e00-\u9fff_a-zA-Z0-9]*)\s*:', add_quotes3, fixed)
        if fixed != line:
            desc.append('宗门纪事键补引号')
    
    return fixed, desc

# 逐行修复
total_fixes = 0
for i in range(len(lines)):
    fixed, desc = smart_fix(i+1, lines[i])
    if fixed != lines[i]:
        fixes.append((i+1, desc, lines[i][:80], fixed[:80]))
        lines[i] = fixed
        total_fixes += 1

print(f'总共修复了 {total_fixes} 行')
print('\n修复详情:')
for line_num, desc, old, new in fixes:
    print(f'L{line_num}: {", ".join(desc)}')
    print(f'  旧: {old}')
    print(f'  新: {new}')

# 写入文件
with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print(f'\n已写入 game_state.gd')

import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixes = []

def fix_line(line_num, line):
    """智能修复单行"""
    fixed = line
    desc = []
    
    # 模式1: 数组中字符串缺闭合引号: ["稀有, "上品" → ["稀有", "上品"
    # 匹配 "中文, " 后面跟另一个字符串
    fixed_new = re.sub(r'"([\u4e00-\u9fff]+),\s*"', r'"\1", "', fixed)
    if fixed_new != fixed:
        fixed = fixed_new
        desc.append('数组字符串补引号')
    
    # 模式2: get("xxx", "默认值) → get("xxx", "默认值")
    matches = re.findall(r'\.get\("([^"]*?)",\s*"([^"]*?)\)', fixed)
    for m in matches:
        old = f'.get("{m[0]}", "{m[1]})'
        new = f'.get("{m[0]}", "{m[1]}")'
        if old in fixed:
            fixed = fixed.replace(old, new)
            desc.append(f'get默认值补引号: {m[1]}')
    
    # 模式3: if t == "xxx: → if t == "xxx":
    fixed_new = re.sub(r'(==\s*"[^"]*?):\s*$', r'\1":', fixed.rstrip()) + '\n'
    if fixed_new != fixed and fixed_new.strip().startswith('if ') and ':' in fixed_new:
        fixed = fixed_new
        desc.append('if字符串补引号')
    
    # 模式4: return "xxx： → return "xxx"
    if fixed.strip().startswith('return "') and fixed.strip().endswith('：'):
        fixed = fixed.rstrip()[:-1] + '"\n'
        desc.append('return字符串补引号')
    
    # 模式5: 字典键缺引号: {中文: 或 ,中文: → {"中文": 或 ,"中文":
    stripped = fixed.strip()
    if (stripped.startswith('return {') or 
        (stripped.startswith('var ') and '=' in stripped and '{' in stripped and ':' in stripped) or
        stripped.startswith('{') or stripped.startswith(',"') or stripped.startswith('"') or
        stripped.startswith('"category"') or stripped.startswith('"daily"') or stripped.startswith('"weekly"')):
        def add_quotes(m):
            prefix = m.group(1)
            key = m.group(2)
            if re.search(r'[\u4e00-\u9fff]', key) and not key.startswith('"'):
                return f'{prefix}"{key}":'
            return m.group(0)
        fixed = re.sub(r'([{,]\s*)([\u4e00-\u9fff][\u4e00-\u9fff_a-zA-Z0-9]*)\s*:', add_quotes, fixed)
        if fixed != line:
            desc.append('字典键补引号')
    
    # 模式6: _传承事件("xxx) → _传承事件("xxx")
    matches = re.findall(r'_传承事件\("([^"]*?)\)', fixed)
    for m in matches:
        old = f'_传承事件("{m})'
        new = f'_传承事件("{m}")'
        if old in fixed:
            fixed = fixed.replace(old, new)
            desc.append(f'_传承事件补引号: {m}')
    
    # 模式7: push_error("xxx) → push_error("xxx")
    matches = re.findall(r'push_error\("([^"]*?)\)', fixed)
    for m in matches:
        old = f'push_error("{m})'
        new = f'push_error("{m}")'
        if old in fixed:
            fixed = fixed.replace(old, new)
            desc.append(f'push_error补引号: {m}')
    
    # 模式8: 候选.append("xxx) → 候选.append("xxx")
    matches = re.findall(r'候选\.append\("([^"]*?)\)', fixed)
    for m in matches:
        old = f'候选.append("{m})'
        new = f'候选.append("{m}")'
        if old in fixed:
            fixed = fixed.replace(old, new)
            desc.append(f'候选.append补引号: {m}')
    
    # 模式9: d.灵根 = "xxx → d.灵根 = "xxx"
    if 'd.灵根 = "' in fixed and not fixed.rstrip().endswith('"'):
        fixed = fixed.rstrip() + '"\n'
        desc.append('d.灵根补引号')
    
    # 模式10: 宗门名 = "xxx： → 宗门名 = "xxx"
    if '宗门名 = "' in fixed and fixed.rstrip().endswith('：'):
        fixed = fixed.rstrip()[:-1] + '"\n'
        desc.append('宗门名补引号')
    
    # 模式11: 宗主性别 = "： → 宗主性别 = ""
    if '宗主性别 = "：' in fixed:
        fixed = fixed.replace('宗主性别 = "：', '宗主性别 = ""')
        desc.append('宗主性别补引号')
    
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

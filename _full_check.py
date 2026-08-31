import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f'总行数: {len(lines)}')
print('\n=== 全面检查 ===\n')

# 1. 引号奇数行
print('1. 引号奇数行:')
quote_issues = []
for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.startswith('#') or stripped == '':
        continue
    if stripped.count('"') % 2 != 0:
        quote_issues.append(i)
        if len(quote_issues) <= 30:
            print(f'  L{i}: {stripped[:100]}')
if len(quote_issues) > 30:
    print(f'  ... 还有 {len(quote_issues)-30} 行')
print(f'  总计: {len(quote_issues)} 行\n')

# 2. 括号不匹配
print('2. 括号不匹配行:')
paren_issues = []
for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.startswith('#') or stripped == '':
        continue
    # 简单检查：( 和 ) 数量是否相等，[ 和 ] 数量是否相等，{ 和 } 数量是否相等
    if stripped.count('(') != stripped.count(')'):
        paren_issues.append((i, '()', stripped.count('('), stripped.count(')')))
    if stripped.count('[') != stripped.count(']'):
        paren_issues.append((i, '[]', stripped.count('['), stripped.count(']')))
    if stripped.count('{') != stripped.count('}'):
        paren_issues.append((i, '{}', stripped.count('{'), stripped.count('}')))
for item in paren_issues[:30]:
    i, t, l, r = item
    print(f'  L{i}: {t} 左{l} 右{r} - {lines[i-1].strip()[:80]}')
if len(paren_issues) > 30:
    print(f'  ... 还有 {len(paren_issues)-30} 行')
print(f'  总计: {len(paren_issues)} 行\n')

# 3. 字典键缺引号
print('3. 字典键可能缺引号:')
dict_issues = []
for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.startswith('#') or stripped == '':
        continue
    # 匹配 {中文: 或 ,中文:
    matches = re.findall(r'[{,]\s*([\u4e00-\u9fff][\u4e00-\u9fff_a-zA-Z0-9]*)\s*:', stripped)
    for m in matches:
        # 检查这个键是否已经有引号
        pattern = rf'["\']{re.escape(m)}["\']\s*:'
        if not re.search(pattern, stripped):
            dict_issues.append((i, m))
            if len(dict_issues) <= 20:
                print(f'  L{i}: 键"{m}"缺引号 - {stripped[:80]}')
if len(dict_issues) > 20:
    print(f'  ... 还有 {len(dict_issues)-20} 处')
print(f'  总计: {len(dict_issues)} 处\n')

# 4. 函数调用缺(
print('4. 函数调用缺(:')
func_issues = []
common_funcs = ['_加推演条目', '_加声望', '_加灵石', '_加贡献', '_加悟道', 
                 '_加灵气', '_记录图录', '_造低阶物品', '_造物品', '_造法宝',
                 '_造丹药', '_造符箓', '_确保字派_S1', '_注册入堂']
for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.startswith('#') or stripped == '':
        continue
    for func in common_funcs:
        if func + '"' in stripped and func + '("' not in stripped:
            func_issues.append((i, func))
            if len(func_issues) <= 20:
                print(f'  L{i}: {func}缺( - {stripped[:80]}')
if len(func_issues) > 20:
    print(f'  ... 还有 {len(func_issues)-20} 处')
print(f'  总计: {len(func_issues)} 处\n')

# 5. 格式化字符串损坏: % 后面没有 [ 或 (
print('5. 格式化字符串可能损坏:')
format_issues = []
for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.startswith('#') or stripped == '':
        continue
    if '%' in stripped and '%%' not in stripped:
        # 检查 % 后面是否有 [ 或 (
        if not re.search(r'%\s*[\[\(]', stripped):
            format_issues.append(i)
            if len(format_issues) <= 20:
                print(f'  L{i}: {stripped[:100]}')
if len(format_issues) > 20:
    print(f'  ... 还有 {len(format_issues)-20} 行')
print(f'  总计: {len(format_issues)} 行\n')

print('=== 检查完成 ===')

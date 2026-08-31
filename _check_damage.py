import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f'总行数: {len(lines)}')

# 统计常见损坏模式
missing_func_paren = 0
missing_type_colon = 0
unclosed_string = 0
missing_plus = 0
missing_dot = 0

for i, line in enumerate(lines, 1):
    stripped = line.strip()
    # 函数定义缺左括号: func 名称) -> 或 func 名称):
    if re.match(r'func\s+\S+\)', stripped) and '(' not in stripped.split(')')[0]:
        missing_func_paren += 1
    # 类型注解缺冒号: var 名称 类型 = 或 var 名称 类型\n
    if re.match(r'var\s+\S+\s+[A-Z]', stripped) and ':' not in stripped.split('=')[0] and 'func' not in stripped:
        missing_type_colon += 1
    # 字符串未闭合（奇数个引号）
    if stripped.count('"') % 2 != 0 and not stripped.startswith('#'):
        unclosed_string += 1
    # 缺+号（字符串拼接）
    if '%' in stripped and '+' not in stripped and stripped.count('"') >= 2:
        # 可能是格式化字符串，不一定是缺+
        pass

print(f'函数定义缺左括号: {missing_func_paren}')
print(f'类型注解缺冒号: {missing_type_colon}')
print(f'字符串未闭合行: {unclosed_string}')

# 看看L2700-L2900之间的损坏模式
print('\n=== L2700-L2900 损坏行示例 ===')
count = 0
for i in range(2699, min(2900, len(lines))):
    line = lines[i]
    stripped = line.strip()
    # 检测可能的损坏
    if re.match(r'func\s+\S+\)', stripped) and '(' not in stripped.split(')')[0]:
        print(f'L{i+1} [缺(]: {stripped[:80]}')
        count += 1
    elif re.match(r'var\s+\S+\s+[A-Z]', stripped) and ':' not in stripped.split('=')[0]:
        print(f'L{i+1} [缺:]: {stripped[:80]}')
        count += 1
    elif stripped.count('"') % 2 != 0 and not stripped.startswith('#'):
        print(f'L{i+1} [引号奇数]: {stripped[:80]}')
        count += 1
    if count >= 20:
        break

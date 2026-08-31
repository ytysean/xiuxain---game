import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 统计剩余损坏
unclosed_quote = 0
missing_paren = 0
dict_key_missing = 0
func_missing_paren = 0

for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.startswith('#'):
        continue
    # 引号奇数
    if stripped.count('"') % 2 != 0:
        unclosed_quote += 1
    # 函数定义缺(
    if re.match(r'func\s+\S+\)', stripped) and '(' not in stripped.split(')')[0]:
        missing_paren += 1
    # 字典键缺引号: {中文: 或 ,中文:
    if re.search(r'[{,]\s*[\u4e00-\u9fff][\u4e00-\u9fff_a-zA-Z0-9]*\s*:', stripped):
        dict_key_missing += 1

print(f'剩余损坏统计:')
print(f'  引号奇数行: {unclosed_quote}')
print(f'  函数定义缺(: {missing_paren}')
print(f'  字典键可能缺引号: {dict_key_missing}')

# 看看L2930-L2960的具体损坏
print('\n=== L2934-L2962 具体内容 ===')
for i in range(2933, min(2962, len(lines))):
    print(f'L{i+1}: {lines[i].rstrip()[:120]}')

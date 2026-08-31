import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 列出所有引号奇数行（排除注释和空行）
print('=== 剩余引号奇数行 ===\n')
quote_issues = []
for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.startswith('#') or stripped == '':
        continue
    if stripped.count('"') % 2 != 0:
        quote_issues.append(i)
        print(f'L{i}: {stripped[:120]}')

print(f'\n总计: {len(quote_issues)} 行')

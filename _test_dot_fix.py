import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 匹配模式：中文字符后面直接跟着英文字母（方法名），然后是(
# 例如：待结算append() -> 待结算.append()
pattern = r'([\u4e00-\u9fa5])([a-zA-Z_][a-zA-Z0-9_]*\()'

matches = re.findall(pattern, content)
print(f'找到 {len(matches)} 个匹配')

# 显示前20个匹配
for i, (ch, func) in enumerate(matches[:20]):
    print(f'{i+1}. {ch}{func}')

# 检查是否有func定义的误匹配
func_pattern = r'func\s+[\u4e00-\u9fa5]+[a-zA-Z_]'
func_matches = re.findall(func_pattern, content)
print(f'\n可能误匹配的func定义: {len(func_matches)}')
for m in func_matches[:10]:
    print(f'  {m}')

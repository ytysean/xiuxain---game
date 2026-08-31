import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 分析L2900-L3100的损坏模式
print('=== L2900-L3100 损坏行详细分析 ===')
for i in range(2899, min(3100, len(lines))):
    line = lines[i].rstrip()
    stripped = line.strip()
    # 检测可能的损坏
    issues = []
    if stripped.count('"') % 2 != 0 and not stripped.startswith('#'):
        issues.append('引号奇数')
    # 字典键缺引号: {中文: 或 ,中文:
    if re.search(r'[{,]\s*[\u4e00-\u9fff][\u4e00-\u9fff_a-zA-Z0-9]*\s*:', stripped):
        issues.append('字典键可能缺引号')
    # 格式化字符串损坏: % 后面没有 [ 或 (
    if '%' in stripped and not re.search(r'%\s*[\[\(]', stripped) and '%%' not in stripped:
        issues.append('格式化字符串可能损坏')
    # 函数调用缺(
    if re.search(r'[\u4e00-\u9fff]\s*"', stripped) and not stripped.startswith('#'):
        # 可能是函数调用缺(，但也可能是字符串
        pass
    
    if issues:
        print(f'L{i+1} [{",".join(issues)}]: {stripped[:100]}')

# 看看L2930-L2960的具体内容
print('\n=== L2930-L2960 具体内容 ===')
for i in range(2929, min(2960, len(lines))):
    print(f'L{i+1}: {lines[i].rstrip()[:120]}')

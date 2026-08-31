import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 分类统计
categories = {
    'get默认值缺引号': [],
    '数组字符串缺引号': [],
    'return字符串缺引号': [],
    '字典键名错误': [],
    'if字符串缺引号': [],
    '函数调用参数缺引号': [],
    '赋值字符串缺引号': [],
    '格式化字符串损坏': [],
    '其他': []
}

for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.startswith('#') or stripped == '':
        continue
    if stripped.count('"') % 2 != 0:
        # 分类
        if re.search(r'\.get\("[^"]*?",\s*"[^"]*?\)', stripped):
            categories['get默认值缺引号'].append((i, stripped[:100]))
        elif re.search(r'\[".*?",\s*"', stripped) and stripped.count('"') % 2 != 0:
            categories['数组字符串缺引号'].append((i, stripped[:100]))
        elif stripped.startswith('return "') and stripped.endswith('：'):
            categories['return字符串缺引号'].append((i, stripped[:100]))
        elif '{"：":' in stripped or '{"：": ' in stripped:
            categories['字典键名错误'].append((i, stripped[:100]))
        elif re.search(r'==\s*"[^"]*?:\s*$', stripped):
            categories['if字符串缺引号'].append((i, stripped[:100]))
        elif re.search(r'(_传承事件|push_error|push_warning|候选\.append)\("', stripped):
            categories['函数调用参数缺引号'].append((i, stripped[:100]))
        elif re.search(r'=\s*"[^"]*?$', stripped) and not stripped.startswith('return'):
            categories['赋值字符串缺引号'].append((i, stripped[:100]))
        elif '%' in stripped and re.search(r'%\s*[a-zA-Z]', stripped):
            categories['格式化字符串损坏'].append((i, stripped[:100]))
        else:
            categories['其他'].append((i, stripped[:100]))

print('=== 损坏分类统计 ===\n')
for cat, items in categories.items():
    print(f'{cat}: {len(items)} 行')
    if len(items) <= 5:
        for item in items:
            print(f'  L{item[0]}: {item[1]}')
    else:
        for item in items[:3]:
            print(f'  L{item[0]}: {item[1]}')
        print(f'  ... 还有 {len(items)-3} 行')
    print()

total = sum(len(items) for items in categories.values())
print(f'总计: {total} 行')

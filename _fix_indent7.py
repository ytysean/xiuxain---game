with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L9114-L9120的缩进问题
fixes = [
    (9114, '\tfor 新弟子 in 新徒:\n'),
    (9116, '\t\tif 新弟子.灵根品阶 == "天品":\n'),
    (9118, '\t\t\t有天品 = true\n'),
    (9120, '\t\t\tbreak\n'),
]

for line_num, new_content in fixes:
    print(f'L{line_num}原始: {repr(lines[line_num-1])}')
    lines[line_num-1] = new_content
    print(f'L{line_num}修复后: {repr(lines[line_num-1])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

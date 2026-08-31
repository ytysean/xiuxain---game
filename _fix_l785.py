with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L785: 数值 -> 数量
print(f'L785原始: {repr(lines[784])}')
lines[784] = lines[784].replace('数值', '数量')
print(f'L785修复后: {repr(lines[784])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

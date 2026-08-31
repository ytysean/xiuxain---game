with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L1539: 堂 -> 项
print(f'L1539原始: {repr(lines[1538])}')
lines[1538] = lines[1538].replace('(堂["负责"]', '(项["负责"]')
print(f'L1539修复后: {repr(lines[1538])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L6455 - 应该是空字符串
print(f'L6455原始: {repr(lines[6454])}')
lines[6454] = '\t\tif pt == "" or pv <= 0:\n'
print(f'L6455修复后: {repr(lines[6454])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

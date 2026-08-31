with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L2744: 价 -> 额
print(f'L2744原始: {repr(lines[2743])}')
lines[2743] = lines[2743].replace(', 价]}', ', 额]}')
print(f'L2744修复后: {repr(lines[2743])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

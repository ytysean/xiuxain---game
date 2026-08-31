with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L2534: 表 -> 行
print(f'L2534原始: {repr(lines[2533])}')
lines[2533] = lines[2533].replace('var 表: Dictionary = {}', 'var 行: Dictionary = {}')
print(f'L2534修复后: {repr(lines[2533])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

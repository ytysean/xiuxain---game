with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L2806: 表 -> 行
print(f'L2806原始: {repr(lines[2805])}')
lines[2805] = lines[2805].replace('var 表: Dictionary = {}', 'var 行: Dictionary = {}')
print(f'L2806修复后: {repr(lines[2805])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

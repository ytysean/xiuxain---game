with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L3898: 列表.is_empty -> 表.is_empty
print(f'L3898原始: {repr(lines[3897])}')
lines[3897] = lines[3897].replace('列表.is_empty()', '表.is_empty()')
print(f'L3898修复后: {repr(lines[3897])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L2566: 行 -> 记
print(f'L2566原始: {repr(lines[2565])}')
lines[2565] = lines[2565].replace('var 行: Dictionary = 坊市购买记录', 'var 记: Dictionary = 坊市购买记录')
print(f'L2566修复后: {repr(lines[2565])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

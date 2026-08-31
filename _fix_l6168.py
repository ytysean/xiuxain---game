with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L6168: Lore.取历(d.境界) -> Lore.取历练(d.境界)
print(f'L6168原始: {repr(lines[6167])}')
lines[6167] = lines[6167].replace('Lore.取历(d.境界)', 'Lore.取历练(d.境界)')
print(f'L6168修复后: {repr(lines[6167])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

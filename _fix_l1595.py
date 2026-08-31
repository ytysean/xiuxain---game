with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L1595: 数值 -> 数量
print(f'L1595原始: {repr(lines[1594])}')
lines[1594] = lines[1594].replace('数值', '数量')
print(f'L1595修复后: {repr(lines[1594])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L4974: 招募冷却剩余 - 天 -> 招募冷却剩余 - 1
print(f'L4974原始: {repr(lines[4973])}')
lines[4973] = lines[4973].replace('招募冷却剩余 - 天)', '招募冷却剩余 - 1)')
print(f'L4974修复后: {repr(lines[4973])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L2728: 价 -> 额
print(f'L2728原始: {repr(lines[2727])}')
lines[2727] = lines[2727].replace('% 价}', '% 额}')
print(f'L2728修复后: {repr(lines[2727])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

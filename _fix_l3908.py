with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L3908: 池[0] -> 表[0]
print(f'L3908原始: {repr(lines[3907])}')
lines[3907] = lines[3907].replace('当前周常 = 池[0]', '当前周常 = 表[0]')
print(f'L3908修复后: {repr(lines[3907])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L2884: 战令_已购付费 -> 战令_已购付费轨
print(f'L2884原始: {repr(lines[2883])}')
lines[2883] = lines[2883].replace('战令_已购付费,', '战令_已购付费轨,')
print(f'L2884修复后: {repr(lines[2883])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

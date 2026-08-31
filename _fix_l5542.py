with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5542: 表["C"] -> 局["C"]
print(f'L5542原始: {repr(lines[5541])}')
lines[5541] = lines[5541].replace('return 局.get(评级, 表["C"])', 'return 局.get(评级, 局["C"])')
print(f'L5542修复后: {repr(lines[5541])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

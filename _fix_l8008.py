with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L8008: 悟道值推进修炼(3, 1.05) -> 悟道值.推进修炼(3, 1.05)
print(f'L8008原始: {repr(lines[8007])}')
lines[8007] = lines[8007].replace('悟道值推进修炼(3, 1.05)', '悟道值.推进修炼(3, 1.05)')
print(f'L8008修复后: {repr(lines[8007])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

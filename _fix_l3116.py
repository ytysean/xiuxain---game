with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L3116: 悟道值 -> 悟道点
print(f'L3116原始: {repr(lines[3115])}')
lines[3115] = lines[3115].replace('悟道值+=', '悟道点 +=')
print(f'L3116修复后: {repr(lines[3115])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L2942: 表 -> 奖
print(f'L2942原始: {repr(lines[2941])}')
lines[2941] = lines[2941].replace('var 表: Dictionary = {}', 'var 奖: Dictionary = {}')
print(f'L2942修复后: {repr(lines[2941])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

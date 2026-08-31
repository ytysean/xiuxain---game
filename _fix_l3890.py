with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L3890: var 列表: Array = [] -> var 表: Array = []
print(f'L3890原始: {repr(lines[3889])}')
lines[3889] = lines[3889].replace('var 列表: Array = []', 'var 表: Array = []')
print(f'L3890修复后: {repr(lines[3889])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

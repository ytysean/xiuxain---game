with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L4156: var 列表: Array = [] -> var 表: Array = []
print(f'L4156原始: {repr(lines[4155])}')
lines[4155] = lines[4155].replace('var 列表: Array = []', 'var 表: Array = []')
print(f'L4156修复后: {repr(lines[4155])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

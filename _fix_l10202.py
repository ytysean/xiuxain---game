with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L10202: var data: Dictionary = _读存档路径() -> var data: Dictionary = _读存档(路径)
print(f'L10202原始: {repr(lines[10201])}')
lines[10201] = lines[10201].replace('var data: Dictionary = _读存档路径()', 'var data: Dictionary = _读存档(路径)')
print(f'L10202修复后: {repr(lines[10201])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

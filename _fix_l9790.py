with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L9790: var d: Dictionary = _读存档账号注册表路径 -> var d: Dictionary = _读存档(账号注册表路径)
print(f'L9790原始: {repr(lines[9789])}')
lines[9789] = lines[9789].replace('var d: Dictionary = _读存档账号注册表路径', 'var d: Dictionary = _读存档(账号注册表路径)')
print(f'L9790修复后: {repr(lines[9789])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L1171: get(资源, null) -> get(资源)
print(f'L1171原始: {repr(lines[1170])}')
lines[1170] = lines[1170].replace('get(资源, null) != null', 'get(资源) != null')
print(f'L1171修复后: {repr(lines[1170])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

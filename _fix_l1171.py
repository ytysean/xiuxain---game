with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L1171: has_property(资源) -> get(资源, null) != null
print(f'L1171原始: {repr(lines[1170])}')
lines[1170] = lines[1170].replace('has_property(资源)', 'get(资源, null) != null')
print(f'L1171修复后: {repr(lines[1170])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

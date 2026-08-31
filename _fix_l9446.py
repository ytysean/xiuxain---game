with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L9446: _引育纪事文案(纪) -> _引育纪事文案(兽)
print(f'L9446原始: {repr(lines[9445])}')
lines[9445] = lines[9445].replace('_引育纪事文案(纪)', '_引育纪事文案(兽)')
print(f'L9446修复后: {repr(lines[9445])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

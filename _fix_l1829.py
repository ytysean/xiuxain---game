with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L1829: _功勋阁声望乘区 -> _功勋阁声望乘区()
print(f'L1829原始: {repr(lines[1828])}')
lines[1828] = lines[1828].replace('_功勋阁声望乘区)', '_功勋阁声望乘区())')
print(f'L1829修复后: {repr(lines[1828])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

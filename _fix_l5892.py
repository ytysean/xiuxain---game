with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5892: _加载负面开关._S1() -> _加载负面开关_S1()
print(f'L5892原始: {repr(lines[5891])}')
lines[5891] = lines[5891].replace('_加载负面开关._S1()', '_加载负面开关_S1()')
print(f'L5892修复后: {repr(lines[5891])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

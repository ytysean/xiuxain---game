with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L9210: if 额> 0: -> if 缺> 0:
print(f'L9210原始: {repr(lines[9209])}')
lines[9209] = lines[9209].replace('if 额> 0:', 'if 缺> 0:')
print(f'L9210修复后: {repr(lines[9209])}')

# 修复L9212: 缺口 = int(ceil(额* 500.0)) -> 缺口 = int(ceil(缺* 500.0))
print(f'L9212原始: {repr(lines[9211])}')
lines[9211] = lines[9211].replace('缺口 = int(ceil(额* 500.0))', '缺口 = int(ceil(缺* 500.0))')
print(f'L9212修复后: {repr(lines[9211])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

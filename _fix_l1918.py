with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L1918和L1920: d -> 新
for i in [1917, 1919]:
    print(f'L{i+1}原始: {repr(lines[i])}')
    lines[i] = lines[i].replace('d.', '新.').replace('append(d)', 'append(新)')
    print(f'L{i+1}修复后: {repr(lines[i])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

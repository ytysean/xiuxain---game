with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5028: d.推进修炼(d * 修炼乘区 * 护法乘区) -> d.推进修炼(修炼乘区 * 护法乘区)
print(f'L5028原始: {repr(lines[5027])}')
lines[5027] = lines[5027].replace('d.推进修炼(d * 修炼乘区 * 护法乘区)', 'd.推进修炼(修炼乘区 * 护法乘区)')
print(f'L5028修复后: {repr(lines[5027])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

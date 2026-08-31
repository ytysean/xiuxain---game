with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L6676: return 名.get(bid, bid) -> return 表.get(bid, bid)
print(f'L6676原始: {repr(lines[6675])}')
lines[6675] = lines[6675].replace('return 名.get(bid, bid)', 'return 表.get(bid, bid)')
print(f'L6676修复后: {repr(lines[6675])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

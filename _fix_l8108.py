with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L8108: if not _器殿赠宝.is_empty(): -> if not _器殿赠宝表.is_empty():
print(f'L8108原始: {repr(lines[8107])}')
lines[8107] = lines[8107].replace('if not _器殿赠宝.is_empty():', 'if not _器殿赠宝表.is_empty():')
print(f'L8108修复后: {repr(lines[8107])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

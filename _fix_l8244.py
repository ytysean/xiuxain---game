with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L8244: Disciple.身份层级表.find(d.身份) -> Disciple.身份层级序.find(d.身份)
print(f'L8244原始: {repr(lines[8243])}')
lines[8243] = lines[8243].replace('Disciple.身份层级表.find(d.身份)', 'Disciple.身份层级序.find(d.身份)')
print(f'L8244修复后: {repr(lines[8243])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

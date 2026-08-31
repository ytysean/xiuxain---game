with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L4030: 主线_境界表.find(境界值) -> Disciple.境界表.get(境界表, 0)
print(f'L4030原始: {repr(lines[4029])}')
lines[4029] = lines[4029].replace('主线_境界表.find(境界值)', 'Disciple.境界表.get(境界表, 0)')
print(f'L4030修复后: {repr(lines[4029])}')

# 修复L4038: 主线_境界表.find(d.境界) -> Disciple.境界表.get(d.境界, 0)
print(f'L4038原始: {repr(lines[4037])}')
lines[4037] = lines[4037].replace('主线_境界表.find(d.境界)', 'Disciple.境界表.get(d.境界, 0)')
print(f'L4038修复后: {repr(lines[4037])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

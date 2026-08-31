with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L9106: if d.灵根品阶 == "天品": -> if 徒.灵根品阶 == "天品":
print(f'L9106原始: {repr(lines[9105])}')
lines[9105] = lines[9105].replace('if d.灵根品阶 == "天品":', 'if 徒.灵根品阶 == "天品":')
print(f'L9106修复后: {repr(lines[9105])}')

# 修复L9108: 存姓名 -> 徒.姓名, 存弟子ID -> 徒.弟子ID
print(f'L9108原始: {repr(lines[9107])}')
lines[9107] = lines[9107].replace('"弟子": 存姓名, "弟子ID": 存弟子ID,', '"弟子": 徒.姓名, "弟子ID": 徒.弟子ID,')
lines[9107] = lines[9107].replace('% [存姓名]', '% [徒.姓名]')
print(f'L9108修复后: {repr(lines[9107])}')

# 修复L9112: 立大功标记[存姓名] = true -> 立大功标记[徒.姓名] = true
print(f'L9112原始: {repr(lines[9111])}')
lines[9111] = lines[9111].replace('立大功标记[存姓名] = true', '立大功标记[徒.姓名] = true')
print(f'L9112修复后: {repr(lines[9111])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L4652-L4663的缩进
# L4652: var 境界顺序: Array = ... -> 5个tab缩进
print(f'L4652原始: {repr(lines[4651])}')
lines[4651] = '\t\t\t\t\tvar 境界顺序: Array = ["练气", "筑基", "金丹", "元婴", "化神", "仙阶", "道阶"]\n'
print(f'L4652修复后: {repr(lines[4651])}')

# L4653: var 目标值: int = 境界顺序.find(extra) -> 5个tab缩进
print(f'L4653原始: {repr(lines[4652])}')
lines[4652] = '\t\t\t\t\tvar 目标值: int = 境界顺序.find(extra)\n'
print(f'L4653修复后: {repr(lines[4652])}')

# L4654: if 目标值>= 0: -> 5个tab缩进
print(f'L4654原始: {repr(lines[4653])}')
lines[4653] = '\t\t\t\t\tif 目标值>= 0:\n'
print(f'L4654修复后: {repr(lines[4653])}')

# L4656: var 全达成:= true -> 6个tab缩进
print(f'L4656原始: {repr(lines[4655])}')
lines[4655] = '\t\t\t\t\t\tvar 全达成:= true\n'
print(f'L4656修复后: {repr(lines[4655])}')

# L4657: for d in 弟子列表: -> 6个tab缩进
print(f'L4657原始: {repr(lines[4656])}')
lines[4656] = '\t\t\t\t\t\tfor d in 弟子列表:\n'
print(f'L4657修复后: {repr(lines[4656])}')

# L4659: if d == null or 境界顺序.find(d.境界) < 目标值: -> 7个tab缩进
print(f'L4659原始: {repr(lines[4658])}')
lines[4658] = '\t\t\t\t\t\t\tif d == null or 境界顺序.find(d.境界) < 目标值:\n'
print(f'L4659修复后: {repr(lines[4658])}')

# L4661: 全达成= false -> 8个tab缩进
print(f'L4661原始: {repr(lines[4660])}')
lines[4660] = '\t\t\t\t\t\t\t\t全达成= false\n'
print(f'L4661修复后: {repr(lines[4660])}')

# L4662: break -> 8个tab缩进
print(f'L4662原始: {repr(lines[4661])}')
lines[4661] = '\t\t\t\t\t\t\t\tbreak\n'
print(f'L4662修复后: {repr(lines[4661])}')

# L4663: 达成 = 全达成 -> 6个tab缩进
print(f'L4663原始: {repr(lines[4662])}')
lines[4662] = '\t\t\t\t\t\t达成 = 全达成\n'
print(f'L4663修复后: {repr(lines[4662])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L4652: var 目标值: int = Disciple.境界表.get(extra) -> var 境界顺序: Array = ["练气", "筑基", "金丹", "元婴", "化神", "仙阶", "道阶"]\n\t\t\t\t\t\tvar 目标值: int = 境界顺序.find(extra)
print(f'L4652原始: {repr(lines[4651])}')
lines[4651] = '\t\t\t\t\t\tvar 境界顺序: Array = ["练气", "筑基", "金丹", "元婴", "化神", "仙阶", "道阶"]\n\t\t\t\t\t\tvar 目标值: int = 境界顺序.find(extra)\n'
print(f'L4652修复后: {repr(lines[4651])}')

# 修复L4658: if d == null or Disciple.境界表.get(d.境界) < 目标值: -> if d == null or 境界顺序.find(d.境界) < 目标值:
# 注意：行号因为插入了一行，所以原来的L4658现在是L4659
print(f'L4659原始: {repr(lines[4658])}')
lines[4658] = lines[4658].replace('Disciple.境界表.get(d.境界) < 目标值', '境界顺序.find(d.境界) < 目标值')
print(f'L4659修复后: {repr(lines[4658])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

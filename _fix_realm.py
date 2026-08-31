with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复_宗主境界函数，使用境界顺序数组来获取索引
# L2234: var idx: int = Disciple.境界表.get(d.境界) -> var 境界顺序: Array = ["练气", "筑基", "金丹", "元婴", "化神", "仙阶", "道阶"]\n\t\t\t\tvar idx: int = 境界顺序.find(d.境界)
print(f'L2234原始: {repr(lines[2233])}')
lines[2233] = '\t\t\t\tvar 境界顺序: Array = ["练气", "筑基", "金丹", "元婴", "化神", "仙阶", "道阶"]\n\t\t\t\tvar idx: int = 境界顺序.find(d.境界)\n'
print(f'L2234修复后: {repr(lines[2233])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复_宗主境界函数的缩进
# L2234-L2235应该是3个tab缩进
print(f'L2234原始: {repr(lines[2233])}')
lines[2233] = '\t\t\tvar 境界顺序: Array = ["练气", "筑基", "金丹", "元婴", "化神", "仙阶", "道阶"]\n'
print(f'L2234修复后: {repr(lines[2233])}')

print(f'L2235原始: {repr(lines[2234])}')
lines[2234] = '\t\t\tvar idx: int = 境界顺序.find(d.境界)\n'
print(f'L2235修复后: {repr(lines[2234])}')

# L2236应该是3个tab缩进
print(f'L2236原始: {repr(lines[2235])}')
lines[2235] = '\t\t\tif idx > mx:\n'
print(f'L2236修复后: {repr(lines[2235])}')

# L2238应该是4个tab缩进
print(f'L2238原始: {repr(lines[2237])}')
lines[2237] = '\t\t\t\tmx = idx\n'
print(f'L2238修复后: {repr(lines[2237])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

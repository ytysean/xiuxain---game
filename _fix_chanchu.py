with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 在if块外面声明产出值变量（L7713之前）
print(f'L7713原始: {repr(lines[7712])}')
# 在L7713之前插入一行声明产出值
lines.insert(7712, '\t\tvar 产出值: int = 0\n')
print(f'已在L7713之前插入 var 产出值: int = 0')

# 把if块里面的 var 产出值: int = 改成 产出值 =
# 现在行号偏移了1，原来的L7726现在是L7727
print(f'L7727原始: {repr(lines[7726])}')
lines[7726] = lines[7726].replace('var 产出值: int = int(', '产出值 = int(')
print(f'L7727修复后: {repr(lines[7726])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

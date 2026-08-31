with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 删除L4750-L4758的int版本_校准函数
# L4750是func定义，L4758是return int(float(s))，L4759是空行
print('删除前:')
for i in range(4748, 4762):
    print(f'L{i+1}: {repr(lines[i])}')

# 删除L4750-L4759（包括函数定义和后面的空行）
del lines[4749:4759]

print('\n删除后:')
for i in range(4745, 4755):
    print(f'L{i+1}: {repr(lines[i])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print(f'\n修复完成，当前总行数: {len(lines)}')

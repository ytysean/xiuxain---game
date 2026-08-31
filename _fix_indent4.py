with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L6512-L6594的缩进问题：加上2个tab
# 这些代码都应该在for循环内
for i in range(6511, 6595):  # L6512-L6595
    line = lines[i]
    if line.strip() != '':  # 非空行
        lines[i] = '\t\t' + line  # 加上2个tab
        print(f'L{i+1}: 加上2个tab')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

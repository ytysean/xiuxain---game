with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L9114 - for循环迭代器名改成"新弟子"
print(f'L9114原始: {repr(lines[9113])}')
lines[9113] = '\t\tfor 新弟子 in 新徒:\n'
print(f'L9114修复后: {repr(lines[9113])}')

# 修复L9116 - 变量名改成"新弟子"
print(f'L9116原始: {repr(lines[9115])}')
lines[9115] = '\t\t\tif 新弟子.灵根品阶 == "天品":\n'
print(f'L9116修复后: {repr(lines[9115])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L9635
print(f'L9635原始: {repr(lines[9634])}')
lines[9634] = '\t\t\tif d.灵根 != "天灵根" and d.灵根 != "先天五行全灵根":\n'
print(f'L9635修复后: {repr(lines[9634])}')

# 修复L9645
print(f'L9645原始: {repr(lines[9644])}')
lines[9644] = '\t\t\tif d.灵根 in Disciple.灵根变异 or d.灵根 == "天灵根" or d.灵根 == "先天五行全灵根":\n'
print(f'L9645修复后: {repr(lines[9644])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

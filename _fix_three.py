with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L6519 - 应该是空字符串
print(f'L6519原始: {repr(lines[6518])}')
lines[6518] = '\tvar 候选: Array = 弟子列表.filter(func(d): return d.阶位 != "")\n'
print(f'L6519修复后: {repr(lines[6518])}')

# 修复L11669 - 应该是"太玄宗"
print(f'L11669原始: {repr(lines[11668])}')
lines[11668] = '\t宗门名 = "太玄宗"\n'
print(f'L11669修复后: {repr(lines[11668])}')

# 修复L11673 - 应该是空字符串
print(f'L11673原始: {repr(lines[11672])}')
lines[11672] = '\t宗主性别 = ""\n'
print(f'L11673修复后: {repr(lines[11672])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

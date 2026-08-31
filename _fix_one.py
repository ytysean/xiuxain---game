with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L7365
print(f'L7365原始: {repr(lines[7364])}')
lines[7364] = '\t\t\t摘要 += " 大捷"\n'
print(f'L7365修复后: {repr(lines[7364])}')

# 修复L7409
print(f'L7409原始: {repr(lines[7408])}')
lines[7408] = '\t\t\tvar 失败原因: Array[String] = ["不敌对手，险象环生后撤退", "陷入苦战，消耗过大无功而返", "情报有误，扑了个空", "天时不利，草草收兵"]\n'
print(f'L7409修复后: {repr(lines[7408])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

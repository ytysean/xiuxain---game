with open('game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复误修复：函数名中的._S1() 应该是 _S1()
fixes = [
    ('_加载阵法配置._S1()', '_加载阵法配置_S1()'),
    ('_加载阵法物品._S1()', '_加载阵法物品_S1()'),
    ('_确保字派._S1()', '_确保字派_S1()'),
]

for old, new in fixes:
    count = content.count(old)
    content = content.replace(old, new)
    print(f'修复 {old} -> {new}: {count} 处')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print('修复完成')

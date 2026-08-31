with open('game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复误修复：函数定义中的 汇总负责人全局buff()buff() -> 汇总负责人全局buff()
old = 'func 汇总负责人全局buff()buff()'
new = 'func 汇总负责人全局buff()'
count = content.count(old)
content = content.replace(old, new)
print(f'修复函数定义 {old} -> {new}: {count} 处')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print('修复完成')

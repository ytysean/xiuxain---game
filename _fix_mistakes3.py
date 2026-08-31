with open('game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复误修复：函数定义中的 设置气运buff(buff( -> 设置气运buff(
old = 'func 设置气运buff(buff('
new = 'func 设置气运buff('
count = content.count(old)
content = content.replace(old, new)
print(f'修复函数定义 {old} -> {new}: {count} 处')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print('修复完成')

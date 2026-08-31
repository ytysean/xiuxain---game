with open('game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复 eget( -> 行.get(
old = 'eget('
new = '行.get('
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print('修复完成')

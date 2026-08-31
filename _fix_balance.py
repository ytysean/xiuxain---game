with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复 _平衡器平衡( -> _平衡器.平衡(
old = '_平衡器平衡('
new = '_平衡器.平衡('
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('修复完成')

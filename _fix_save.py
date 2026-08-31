with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复 "宗门": 宗门, -> "宗门": 宗门名,
old = '"宗门": 宗门,'
new = '"宗门": 宗门名,'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

# 修复 "战令_已购付费": 战令_已购付费, -> "战令_已购付费": 战令_已购付费轨,
old = '"战令_已购付费": 战令_已购付费,'
new = '"战令_已购付费": 战令_已购付费轨,'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('修复完成')

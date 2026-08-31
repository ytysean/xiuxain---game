with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5418: 名称 -> 物.名称
print(f'L5418原始: {repr(lines[5417])}')
lines[5417] = lines[5417].replace('赐掌门上品法宝：%s】" % [评级, 名称]', '赐掌门上品法宝：%s】" % [评级, 物.名称]')
print(f'L5418修复后: {repr(lines[5417])}')

# 修复L5424: 年 -> 额
print(f'L5424原始: {repr(lines[5423])}')
lines[5423] = lines[5423].replace('var 年度发: int = int(年*', 'var 年度发: int = int(额*')
print(f'L5424修复后: {repr(lines[5423])}')

# 修复L5426: 年 -> 额
print(f'L5426原始: {repr(lines[5425])}')
lines[5425] = lines[5425].replace('var 入池: int = 年-', 'var 入池: int = 额-')
print(f'L5426修复后: {repr(lines[5425])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

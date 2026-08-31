with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复_七载大典文案函数，把配置[评级]强制转换为Dictionary
# L3413: return 配置[评级] -> return 配置[评级] as Dictionary
print(f'L3413原始: {repr(lines[3412])}')
lines[3412] = lines[3412].replace('return 配置[评级]', 'return 配置[评级] as Dictionary')
print(f'L3413修复后: {repr(lines[3412])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

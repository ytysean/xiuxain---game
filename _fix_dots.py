import re

with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fix_count = 0

for i in range(len(lines)):
    line = lines[i]
    original = line
    
    # 跳过func定义行
    if line.strip().startswith('func '):
        continue
    
    # 修复点号丢失：中文字符后面直接跟着英文字母（方法名），然后是(
    # 例如：待结算append() -> 待结算.append()
    # 使用负向断言，排除func后面的情况
    new_line = re.sub(r'(?<!func )([\u4e00-\u9fa5])([a-zA-Z_][a-zA-Z0-9_]*\()', r'\1.\2', line)
    
    # 修复变量名文字错误：皮像 -> 皮肤
    new_line = new_line.replace('宗主皮像', '宗主皮肤')
    new_line = new_line.replace('弟子皮像', '弟子皮肤')
    
    if new_line != original:
        lines[i] = new_line
        fix_count += 1
        if fix_count <= 20:
            print(f'L{i+1}:')
            print(f'  旧: {original.strip()}')
            print(f'  新: {new_line.strip()}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f'\n总共修复了 {fix_count} 行')

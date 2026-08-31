with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L7720 - 变量名改成"产出值"
print(f'L7720原始: {repr(lines[7719])}')
lines[7719] = '\t\t\tvar 产出值: int = int(n * base * (1.0 + 经营加成) * 气运乘 * (1.0 + 产出buff + 彩蛋产出加成() + 产出池加成 * 等级乘区 * 宗主灵石系数 * _殿阁等级_乘区(key)))\n'
print(f'L7720修复后: {repr(lines[7719])}')

# 修复L7722 - 变量名改成"产出值"
print(f'L7722原始: {repr(lines[7721])}')
lines[7721] = '\t\t\t灵石 += 产出值\n'
print(f'L7722修复后: {repr(lines[7721])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

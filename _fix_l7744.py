with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L7744: _本月灵田产出 = 额 -> _本月灵田产出 = 产出值
print(f'L7744原始: {repr(lines[7743])}')
lines[7743] = lines[7743].replace('_本月灵田产出 = 额', '_本月灵田产出 = 产出值')
print(f'L7744修复后: {repr(lines[7743])}')

# 修复L7746: 灵草 += 额 -> 灵草 += 产出值
print(f'L7746原始: {repr(lines[7745])}')
lines[7745] = lines[7745].replace('灵草 += 额', '灵草 += 产出值')
print(f'L7746修复后: {repr(lines[7745])}')

# 修复L7748: 灵气 += int(ceil(额* 0.5)) -> 灵气 += int(ceil(产出值* 0.5))
print(f'L7748原始: {repr(lines[7747])}')
lines[7747] = lines[7747].replace('灵气 += int(ceil(额* 0.5))', '灵气 += int(ceil(产出值* 0.5))')
print(f'L7748修复后: {repr(lines[7747])}')

# 修复L7752: _本月矿脉产出 = 产 -> _本月矿脉产出 = 产出值
print(f'L7752原始: {repr(lines[7751])}')
lines[7751] = lines[7751].replace('_本月矿脉产出 = 产', '_本月矿脉产出 = 产出值')
print(f'L7752修复后: {repr(lines[7751])}')

# 修复L7754: 矿石 += 产 -> 矿石 += 产出值
print(f'L7754原始: {repr(lines[7753])}')
lines[7753] = lines[7753].replace('矿石 += 产', '矿石 += 产出值')
print(f'L7754修复后: {repr(lines[7753])}')

# 修复L7756: _本月丹堂产出 = 产 -> _本月丹堂产出 = 产出值
print(f'L7756原始: {repr(lines[7755])}')
lines[7755] = lines[7755].replace('_本月丹堂产出 = 产', '_本月丹堂产出 = 产出值')
print(f'L7756修复后: {repr(lines[7755])}')

# 修复L7758: _本月器殿产出 = 产 -> _本月器殿产出 = 产出值
print(f'L7758原始: {repr(lines[7757])}')
lines[7757] = lines[7757].replace('_本月器殿产出 = 产', '_本月器殿产出 = 产出值')
print(f'L7758修复后: {repr(lines[7757])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5346: 卡["评级"] -> 局["评级"]
print(f'L5346原始: {repr(lines[5345])}')
lines[5345] = lines[5345].replace('var 评级级: String = 卡["评级"]', 'var 评级级: String = 局["评级"]')
print(f'L5346修复后: {repr(lines[5345])}')

# 修复L5350: 卡["年度发"] = 发["年度发"] -> 局["年度发"] = 评级["年度发"]
print(f'L5350原始: {repr(lines[5349])}')
lines[5349] = lines[5349].replace('卡["年度发"] = 发["年度发"]', '局["年度发"] = 评级["年度发"]')
print(f'L5350修复后: {repr(lines[5349])}')

# 修复L5352: 卡["入池"] = 发["入池"] -> 局["入池"] = 评级["入池"]
print(f'L5352原始: {repr(lines[5351])}')
lines[5351] = lines[5351].replace('卡["入池"] = 发["入池"]', '局["入池"] = 评级["入池"]')
print(f'L5352修复后: {repr(lines[5351])}')

# 修复L5354: 卡["平移法宝"] = 发["平移法宝"] -> 局["平移法宝"] = 评级["平移法宝"]
print(f'L5354原始: {repr(lines[5353])}')
lines[5353] = lines[5353].replace('卡["平移法宝"] = 发["平移法宝"]', '局["平移法宝"] = 评级["平移法宝"]')
print(f'L5354修复后: {repr(lines[5353])}')

# 修复L5356: 最新周期评级卡 = 级 -> 最新周期评级卡 = 局
print(f'L5356原始: {repr(lines[5355])}')
lines[5355] = lines[5355].replace('最新周期评级卡 = 级', '最新周期评级卡 = 局')
print(f'L5356修复后: {repr(lines[5355])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

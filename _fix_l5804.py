with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5804: _CSV去.BOM("res://config/经济阀：csv") -> DestinyDataLoader._read_csv("res://config/经济阀：csv")
print(f'L5804原始: {repr(lines[5803])}')
lines[5803] = lines[5803].replace(
    'for r in _CSV去.BOM("res://config/经济阀：csv"):',
    'for r in DestinyDataLoader._read_csv("res://config/经济阀：csv"):'
)
print(f'L5804修复后: {repr(lines[5803])}')

# 修复L5810: _经济阀门缓存[名] -> _经济阀门缓存[行]
print(f'L5810原始: {repr(lines[5809])}')
lines[5809] = lines[5809].replace('_经济阀门缓存[名] = r', '_经济阀门缓存[行] = r')
print(f'L5810修复后: {repr(lines[5809])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

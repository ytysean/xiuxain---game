with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5820: _CSV去.BOM("res://config/negative_event.csv") -> DestinyDataLoader._read_csv("res://config/negative_event.csv")
print(f'L5820原始: {repr(lines[5819])}')
lines[5819] = lines[5819].replace(
    '_负面事件缓存 = _CSV去.BOM("res://config/negative_event.csv")',
    '_负面事件缓存 = DestinyDataLoader._read_csv("res://config/negative_event.csv")'
)
print(f'L5820修复后: {repr(lines[5819])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

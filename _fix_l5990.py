with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5990: var eid: String = e.get("event_id", "") -> var eid: String = 行.get("event_id", "")
print(f'L5990原始: {repr(lines[5989])}')
lines[5989] = lines[5989].replace('var eid: String = e.get("event_id", "")', 'var eid: String = 行.get("event_id", "")')
print(f'L5990修复后: {repr(lines[5989])}')

# 修复L5996: e.get("event_name", eid) -> 行.get("event_name", eid)
print(f'L5996原始: {repr(lines[5995])}')
lines[5995] = lines[5995].replace('e.get("event_name", eid)', '行.get("event_name", eid)')
print(f'L5996修复后: {repr(lines[5995])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L727: 文案表["activity_debate_desc"] -> "与弟子论道切磋，提升心境与修炼进度"
print(f'L727原始: {repr(lines[726])}')
lines[726] = lines[726].replace('文案表["activity_debate_desc"]', '"与弟子论道切磋，提升心境与修炼进度"')
print(f'L727修复后: {repr(lines[726])}')

# 修复L728: 文案表["activity_co_comprehend_desc"] -> "共参功法，消耗悟道点，提升道心与修炼进度"
print(f'L728原始: {repr(lines[727])}')
lines[727] = lines[727].replace('文案表["activity_co_comprehend_desc"]', '"共参功法，消耗悟道点，提升道心与修炼进度"')
print(f'L728修复后: {repr(lines[727])}')

# 修复L729: 文案表["activity_instruct_desc"] -> "指点弟子修行，降低心魔，提升修炼进度"
print(f'L729原始: {repr(lines[728])}')
lines[728] = lines[728].replace('文案表["activity_instruct_desc"]', '"指点弟子修行，降低心魔，提升修炼进度"')
print(f'L729修复后: {repr(lines[728])}')

# 修复L730: 文案表["activity_wall_thought_desc"] -> "罚弟子面壁思过，降低心境与心魔"
print(f'L730原始: {repr(lines[729])}')
lines[729] = lines[729].replace('文案表["activity_wall_thought_desc"]', '"罚弟子面壁思过，降低心境与心魔"')
print(f'L730修复后: {repr(lines[729])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

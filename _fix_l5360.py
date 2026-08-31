with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5360: var 岁末评语: String = _七载大典文案(评级级.get("评语", ""))
# -> var 岁末评语: String = _七载大典文案(评级级).get("评语", "")
print(f'L5360原始: {repr(lines[5359])}')
lines[5359] = lines[5359].replace(
    'var 岁末评语: String = _七载大典文案(评级级.get("评语", ""))',
    'var 岁末评语: String = _七载大典文案(评级级).get("评语", "")'
)
print(f'L5360修复后: {repr(lines[5359])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

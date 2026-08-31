with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L8679: 堂["政绩"] = -> 职["政绩"] =
print(f'L8679原始: {repr(lines[8678])}')
lines[8678] = lines[8678].replace('堂["政绩"] =', '职["政绩"] =')
print(f'L8679修复后: {repr(lines[8678])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

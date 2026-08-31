with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 在L7578之后添加 _存在长寿弟子() 函数
print(f'L7578原始: {repr(lines[7577])}')
new_func = '''
func _存在长寿弟子() -> bool:
	for d in 弟子列表:
		if d.年龄 >= 100:
			return true
	return false
'''
lines.insert(7578, new_func)
print(f'已在L7578之后添加 _存在长寿弟子() 函数')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')

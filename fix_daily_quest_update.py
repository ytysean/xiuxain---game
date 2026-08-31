# -*- coding: utf-8 -*-
"""
添加领取日常任务函数的任务进度更新
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_daily = '''func 领取日常(序号: int) -> Dictionary:

	if 序号 < 0 or 序号 >= 当前日常.size():'''

new_daily = '''func 领取日常(序号: int) -> Dictionary:

	# 阵营任务进度更新：完成日常任务可视为各阵营日常任务的一种
	更新阵营任务进度("正道宗门", "daily", 1)
	更新阵营任务进度("魔道邪宗", "daily", 1)
	更新阵营任务进度("中立散修", "daily", 1)
	更新阵营任务进度("上古妖兽", "daily", 1)
	更新阵营任务进度("远古遗泽", "daily", 1)
	if 序号 < 0 or 序号 >= 当前日常.size():'''

if old_daily in content:
    content = content.replace(old_daily, new_daily)
    print("✅ 领取日常任务函数任务进度更新添加成功")
else:
    print("❌ 未找到领取日常任务函数")
    # 尝试搜索其他形式
    if "func 领取日常" in content:
        print("找到 'func 领取日常'，但内容不匹配")
        # 打印附近内容
        idx = content.find("func 领取日常")
        if idx >= 0:
            print("附近内容：")
            print(repr(content[idx:idx+200]))

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 领取日常任务函数任务进度更新添加完成！")

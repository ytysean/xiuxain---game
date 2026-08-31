# -*- coding: utf-8 -*-
"""
手动添加购买坊市物品函数和领取日常任务函数的任务进度更新
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ============ 1. 在购买坊市物品函数中添加任务进度更新 ============
print("步骤1：在购买坊市物品函数中添加任务进度更新...")

old_buy = '''	坊市购买记录[shop_id] = 记
	坊市类别月购[类别] = int(坊市类别月购.get(类别, 0)) + 1   # D2：月度限购计：+1
	var 折扣说明: String = ""'''

new_buy = '''	坊市购买记录[shop_id] = 记
	坊市类别月购[类别] = int(坊市类别月购.get(类别, 0)) + 1   # D2：月度限购计：+1
	# 阵营任务进度更新：中立散修"坊市跑腿"任务
	更新阵营任务进度("中立散修", "daily", 1)
	var 折扣说明: String = ""'''

if old_buy in content:
    content = content.replace(old_buy, new_buy)
    print("  ✅ 购买坊市物品函数任务进度更新添加成功")
else:
    print("  ❌ 未找到购买坊市物品函数的插入位置")

# ============ 2. 在领取日常任务函数中添加任务进度更新 ============
print("\n步骤2：在领取日常任务函数中添加任务进度更新...")

# 搜索日常任务领取函数
old_daily = '''func 领取日常(索引: int) -> Dictionary:
	if 索引 < 0 or 索引 >= 日常任务.size():'''

new_daily = '''func 领取日常(索引: int) -> Dictionary:
	# 阵营任务进度更新：完成日常任务可视为各阵营日常任务的一种
	更新阵营任务进度("正道宗门", "daily", 1)
	更新阵营任务进度("魔道邪宗", "daily", 1)
	更新阵营任务进度("中立散修", "daily", 1)
	更新阵营任务进度("上古妖兽", "daily", 1)
	更新阵营任务进度("远古遗泽", "daily", 1)
	if 索引 < 0 or 索引 >= 日常任务.size():'''

if old_daily in content:
    content = content.replace(old_daily, new_daily)
    print("  ✅ 领取日常任务函数任务进度更新添加成功")
else:
    print("  ❌ 未找到领取日常任务函数")
    # 尝试搜索其他形式
    if "func 领取日常" in content:
        print("  找到 'func 领取日常'，但内容不匹配")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 手动添加任务进度更新完成！")

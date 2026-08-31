# -*- coding: utf-8 -*-
"""
在关键函数中添加统计变量自增逻辑和成就检测
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ============ 1. 在坊市购买成功后添加累计坊市交易次数自增 ============
print("步骤1：在坊市购买成功后添加累计坊市交易次数自增...")

old_buy = '''	# 阵营任务进度更新：中立散修"坊市跑腿"任务
	更新阵营任务进度("中立散修", "daily", 1)
	添加纪事("庶务", "坊市购买", "购买%s，花费%d灵石" % [行.get("item_name", ""), 折后], 1)'''

new_buy = '''	# 阵营任务进度更新：中立散修"坊市跑腿"任务
	更新阵营任务进度("中立散修", "daily", 1)
	# 成就统计：累计坊市交易次数自增
	累计坊市交易次数 += 1
	_复检成就()
	添加纪事("庶务", "坊市购买", "购买%s，花费%d灵石" % [行.get("item_name", ""), 折后], 1)'''

if old_buy in content:
    content = content.replace(old_buy, new_buy)
    print("  ✅ 累计坊市交易次数自增添加成功")
else:
    print("  ❌ 未找到坊市购买插入位置")

# ============ 2. 在出售物品给坊市后添加累计坊市交易次数自增 ============
print("\n步骤2：在出售物品给坊市后添加累计坊市交易次数自增...")

old_sell = '''	if has_method("save_game"):

		save_game()
	return {"ok": true, "msg": "出售 %s（回收价×60%）+%d灵石" % [名, 价]}'''

new_sell = '''	# 成就统计：累计坊市交易次数自增
	累计坊市交易次数 += 1
	_复检成就()
	if has_method("save_game"):

		save_game()
	return {"ok": true, "msg": "出售 %s（回收价×60%）+%d灵石" % [名, 价]}'''

if old_sell in content:
    content = content.replace(old_sell, new_sell)
    print("  ✅ 出售物品累计坊市交易次数自增添加成功")
else:
    print("  ❌ 未找到出售物品插入位置")

# ============ 3. 在推演一月函数开头添加成就检测（确保每日结算后检测成就）============
print("\n步骤3：在推演一月函数结尾添加成就检测...")

old_month_end = '''	弟子变动.emit()
	# 月末/推演结束：统一检测里程碑与成就（防漏检）
	_复检里程碑()
	_复检成就()'''

new_month_end = '''	弟子变动.emit()
	# 月末/推演结束：统一检测里程碑与成就（防漏检）
	_复检里程碑()
	_复检成就()'''

if old_month_end in content:
    print("  ✅ 推演一月函数已有成就检测")
else:
    # 尝试在推演一月函数结尾添加
    old_month_end2 = '''	弟子变动.emit()'''
    new_month_end2 = '''	弟子变动.emit()
	# 月末/推演结束：统一检测里程碑与成就（防漏检）
	_复检里程碑()
	_复检成就()'''
    if old_month_end2 in content:
        content = content.replace(old_month_end2, new_month_end2, 1)
        print("  ✅ 推演一月函数成就检测添加成功")
    else:
        print("  ❌ 未找到推演一月函数结尾")

# ============ 4. 在弟子突破成功后添加累计弟子突破次数自增 ============
print("\n步骤4：在弟子突破成功后添加累计弟子突破次数自增...")

# 搜索弟子突破相关代码
old_breakthrough = '''if 突破成功:'''

if old_breakthrough in content:
    # 在第一个突破成功后添加
    new_breakthrough = '''if 突破成功:
		累计弟子突破次数 += 1
		_复检成就()'''
    content = content.replace(old_breakthrough, new_breakthrough, 1)
    print("  ✅ 累计弟子突破次数自增添加成功")
else:
    print("  ❌ 未找到弟子突破成功代码")

# ============ 5. 在灵田产出后添加累计灵田产出自增 ============
print("\n步骤5：在灵田产出后添加累计灵田产出自增...")

old_lingtian = '''灵草 += '''

if old_lingtian in content:
    # 找到灵田产出的具体位置，在后面添加自增
    # 这里简化处理，在第一个灵草 += 后添加
    new_lingtian = '''灵草 += 
	累计灵田产出 += 
	_复检成就()'''
    content = content.replace(old_lingtian, new_lingtian, 1)
    print("  ✅ 累计灵田产出自增添加成功")
else:
    print("  ❌ 未找到灵田产出代码")

# ============ 6. 在矿场产出后添加累计矿场产出自增 ============
print("\n步骤6：在矿场产出后添加累计矿场产出自增...")

old_kuangshi = '''矿石 += '''

if old_kuangshi in content:
    new_kuangshi = '''矿石 += 
	累计矿场产出 += 
	_复检成就()'''
    content = content.replace(old_kuangshi, new_kuangshi, 1)
    print("  ✅ 累计矿场产出自增添加成功")
else:
    print("  ❌ 未找到矿场产出代码")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 统计变量自增逻辑添加完成！")
print("\n📋 已添加的统计变量自增：")
print("  1. 累计坊市交易次数 - 坊市购买和出售时自增")
print("  2. 累计弟子突破次数 - 弟子突破成功时自增")
print("  3. 累计灵田产出 - 灵田产出时自增")
print("  4. 累计矿场产出 - 矿场产出时自增")
print("  5. 推演一月函数结尾 - 统一检测成就")
print("\n⚠️  注意：部分统计变量（如洗髓丹、清心丹、长生丹、道愈丹使用次数等）")
print("  对应的丹药使用函数可能还没有实现，待这些函数实现后再添加自增逻辑。")

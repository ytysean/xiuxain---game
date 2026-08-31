# -*- coding: utf-8 -*-
"""
完善商城系统和礼包系统，添加更多功能
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 在商城系统中添加所有商城商品列表和商城统计功能
old_shop_func = '''# S2 商队高价梯度预留（出：回收侧三档：库藏全价 ：坊市×60% ：商队高价：
# 当前坊市×60% 已启用；商队高价回收通道本期限接通（玩家向商队出售按此系数，无找回池）：
const 商队回收系数: float = 0.8   # 商队高价回收系数：当：80%：坊市×60%，体现「商队高价回收」）；S2 实装后按经济平衡校准'''

new_shop_func = '''# 获取所有商城商品列表
func 获取所有商城商品列表() -> Array:
	var 商品列表 = []
	for 商品 in _坊市表():
		var shop_id = 商品.get("shop_id", "")
		商品列表.append({
			"shop_id": shop_id,
			"item_name": 商品.get("item_name", ""),
			"item_grade": 商品.get("item_grade", "凡品"),
			"price_lingjing": 商品.get("price_lingjing", 0),
			"unlock_reputation": 商品.get("unlock_reputation", 0),
			"limit_daily": 商品.get("limit_daily", 0),
			"limit_weekly": 商品.get("limit_weekly", 0),
			"已上架": 坊市上架集.has(shop_id),
			"当前价格": 坊市物品现价(shop_id),
		})
	return 商品列表

# 获取商城统计
func 获取商城统计() -> Dictionary:
	var 商品总数 = _坊市表().size()
	var 已上架数 = 坊市上架集.size()
	var 总购买次数 = 0
	for 记录 in 坊市购买记录.values():
		总购买次数 += int(记录.get("weekly", 0))
	return {
		"商品总数": 商品总数,
		"已上架数": 已上架数,
		"总购买次数": 总购买次数,
		"当前声望折扣": int(坊市折扣率() * 100),
	}

# 获取商城分类列表
func 获取商城分类列表() -> Array:
	var 分类集合 = {}
	for 商品 in _坊市表():
		var 类别 = _坊市商品类别(商品)
		if 类别 != "":
			分类集合[类别] = true
	var 分类列表 = []
	for 类别 in 分类集合.keys():
		分类列表.append(类别)
	return 分类列表

# S2 商队高价梯度预留（出：回收侧三档：库藏全价 ：坊市×60% ：商队高价：
# 当前坊市×60% 已启用；商队高价回收通道本期限接通（玩家向商队出售按此系数，无找回池）：
const 商队回收系数: float = 0.8   # 商队高价回收系数：当：80%：坊市×60%，体现「商队高价回收」）；S2 实装后按经济平衡校准'''

if old_shop_func in content:
    content = content.replace(old_shop_func, new_shop_func)
    print("✅ 商城系统完善成功（添加所有商城商品列表、商城统计、商城分类列表）")
else:
    print("❌ 未找到商队高价梯度预留注释")

# 2. 在礼包系统中添加所有礼包列表和礼包统计功能
old_gift_func = '''# ===== 设置：/ 本地道友系统：026-08-21 收尾；不升SAVE_VERSION，旧档缺键→默认零回归）====='''

new_gift_func = '''# 获取所有礼包列表
func 获取所有礼包列表() -> Array:
	var 礼包列表 = []
	for 礼包 in 礼包配置:
		var 礼包ID = 礼包.get("id", "")
		var 已购次数 = 已购买礼包.get(礼包ID, 0)
		var 可购买 = true
		if 礼包.get("每日重置", false):
			可购买 = 每日礼包购买日 != 累计游戏日 or 已购次数 < 礼包.get("限购", 1)
		else:
			可购买 = 已购次数 < 礼包.get("限购", 1)
		礼包列表.append({
			"id": 礼包ID,
			"名称": 礼包.get("名称", ""),
			"价格": 礼包.get("价格", 0),
			"描述": 礼包.get("描述", ""),
			"内容": 礼包.get("内容", {}),
			"限购": 礼包.get("限购", 1),
			"每日重置": 礼包.get("每日重置", false),
			"已购次数": 已购次数,
			"可购买": 可购买,
		})
	return 礼包列表

# 获取礼包统计
func 获取礼包统计() -> Dictionary:
	var 礼包总数 = 礼包配置.size()
	var 已购买总数 = 0
	var 每日礼包可领 = false
	for 礼包 in 礼包配置:
		var 礼包ID = 礼包.get("id", "")
		var 已购次数 = 已购买礼包.get(礼包ID, 0)
		if 礼包.get("每日重置", false):
			if 每日礼包购买日 != 累计游戏日 or 已购次数 < 礼包.get("限购", 1):
				每日礼包可领 = true
		else:
			if 已购次数 >= 礼包.get("限购", 1):
				已购买总数 += 1
	return {
		"礼包总数": 礼包总数,
		"已购买总数": 已购买总数,
		"每日礼包可领": 每日礼包可领,
	}

# 一键购买所有可购买的免费礼包（简化版本）
func 一键购买免费礼包() -> Dictionary:
	var 购买数量 = 0
	var 结果列表 = []
	for 礼包 in 礼包配置:
		var 价格 = int(礼包.get("价格", 0))
		if 价格 <= 0:  # 免费礼包
			var 结果 = 购买礼包(礼包.get("id", ""))
			结果列表.append({"礼包": 礼包.get("名称", ""), "结果": 结果})
			if 结果.get("成功", false):
				购买数量 += 1
	return {"成功": 购买数量 > 0, "购买数量": 购买数量, "结果列表": 结果列表, "消息": "一键购买完成，购买%d个礼包" % 购买数量}

# ===== 设置：/ 本地道友系统：026-08-21 收尾；不升SAVE_VERSION，旧档缺键→默认零回归）====='''

if old_gift_func in content:
    content = content.replace(old_gift_func, new_gift_func)
    print("✅ 礼包系统完善成功（添加所有礼包列表、礼包统计、一键购买免费礼包）")
else:
    print("❌ 未找到设置/本地道友系统注释")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 商城系统和礼包系统完善完成！")
print("\n📋 已完善的功能：")
print("  1. 商城系统：")
print("     - 添加获取所有商城商品列表功能")
print("     - 添加获取商城统计功能（商品总数、已上架数、总购买次数、当前声望折扣）")
print("     - 添加获取商城分类列表功能")
print("  2. 礼包系统：")
print("     - 添加获取所有礼包列表功能（包含已购次数和可购买状态）")
print("     - 添加获取礼包统计功能（礼包总数、已购买总数、每日礼包可领）")
print("     - 添加一键购买免费礼包功能")
print("\n📌 商城系统说明：")
print("  - 所有商城商品列表：返回所有商品的详细信息（名称、品阶、价格、声望要求、限购等）")
print("  - 商城统计：商品总数、已上架数、总购买次数、当前声望折扣")
print("  - 商城分类列表：返回所有商品分类（材料、丹药、装备、功法等）")
print("\n📌 礼包系统说明：")
print("  - 所有礼包列表：返回所有礼包的详细信息（名称、价格、描述、内容、限购、已购次数、可购买状态）")
print("  - 礼包统计：礼包总数、已购买总数、每日礼包可领")
print("  - 一键购买免费礼包：自动购买所有价格为0的礼包")

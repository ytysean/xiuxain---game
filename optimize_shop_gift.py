# -*- coding: utf-8 -*-
"""
优化现有的商城系统和礼包系统，添加更多功能而不是重复添加
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 优化商城系统 - 添加商品分类筛选、搜索、排序、购买历史、每日特惠功能
# 在获取商城分类列表函数后面添加更多功能
old_shop_func = '''# 获取商城分类列表
func 获取商城分类列表() -> Array:
	var 分类集合 = {}
	for 商品 in _坊市表():
		var 类别 = _坊市商品类别(商品)
		if 类别 != "":
			分类集合[类别] = true
	var 分类列表 = []
	for 类别 in 分类集合.keys():
		分类列表.append(类别)
	return 分类列表'''

new_shop_func = '''# 获取商城分类列表
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

# 按分类筛选商城商品
func 按分类筛选商城商品(分类: String) -> Array:
	var 筛选列表 = []
	var 商品列表 = 获取商城商品列表()
	for 商品 in 商品列表:
		var 商品分类 = _坊市商品类别(商品)
		if 商品分类 == 分类:
			筛选列表.append(商品)
	return 筛选列表

# 搜索商城商品
func 搜索商城商品(关键词: String) -> Array:
	var 搜索结果 = []
	var 商品列表 = 获取商城商品列表()
	for 商品 in 商品列表:
		var 商品名称 = str(商品.get("item_name", ""))
		var 商品品阶 = str(商品.get("item_grade", ""))
		if 关键词 in 商品名称 or 关键词 in 商品品阶:
			搜索结果.append(商品)
	return 搜索结果

# 商城商品排序方式
const 商城排序方式: Dictionary = {
	"价格升序": {"描述": "按价格从低到高排序", "字段": "price_lingjing", "升序": true},
	"价格降序": {"描述": "按价格从高到低排序", "字段": "price_lingjing", "升序": false},
	"品阶升序": {"描述": "按品阶从低到高排序", "字段": "item_grade", "升序": true},
	"品阶降序": {"描述": "按品阶从高到低排序", "字段": "item_grade", "升序": false},
	"名称升序": {"描述": "按名称字母顺序排序", "字段": "item_name", "升序": true},
}

# 排序商城商品
func 排序商城商品(商品列表: Array, 排序方式: String) -> Array:
	var 排序配置 = 商城排序方式.get(排序方式, {})
	if 排序配置.is_empty():
		return 商品列表
	var 字段 = str(排序配置.get("字段", ""))
	var 升序 = bool(排序配置.get("升序", true))
	var 排序后列表 = 商品列表.duplicate()
	if 字段 == "price_lingjing":
		if 升序:
			排序后列表.sort_custom(func(a, b): return float(a.get(字段, 0)) < float(b.get(字段, 0)))
		else:
			排序后列表.sort_custom(func(a, b): return float(a.get(字段, 0)) > float(b.get(字段, 0)))
	elif 字段 == "item_grade":
		var 品阶顺序 = {"凡品": 1, "灵品": 2, "宝品": 3, "王品": 4, "仙品": 5, "神品": 6}
		if 升序:
			排序后列表.sort_custom(func(a, b): return 品阶顺序.get(str(a.get(字段, "凡品")), 0) < 品阶顺序.get(str(b.get(字段, "凡品")), 0))
		else:
			排序后列表.sort_custom(func(a, b): return 品阶顺序.get(str(a.get(字段, "凡品")), 0) > 品阶顺序.get(str(b.get(字段, "凡品")), 0))
	elif 字段 == "item_name":
		if 升序:
			排序后列表.sort_custom(func(a, b): return str(a.get(字段, "")) < str(b.get(字段, "")))
		else:
			排序后列表.sort_custom(func(a, b): return str(a.get(字段, "")) > str(b.get(字段, "")))
	return 排序后列表

# 商城购买历史记录
var 商城购买历史: Array = []

# 记录商城购买
func _记录商城购买(商品ID: String, 商品名称: String, 价格: int, 数量: int = 1) -> void:
	商城购买历史.append({
		"商品ID": 商品ID,
		"商品名称": 商品名称,
		"价格": 价格,
		"数量": 数量,
		"总价格": 价格 * 数量,
		"购买日期": 累计游戏日,
	})
	# 限制历史记录数量
	if 商城购买历史.size() > 100:
		商城购买历史.remove_at(0)

# 获取商城购买历史
func 获取商城购买历史(限制数量: int = 20) -> Array:
	var 历史 = 商城购买历史.duplicate()
	历史.reverse()
	return 历史.slice(0, min(限制数量, 历史.size()))

# 获取商城购买统计
func 获取商城购买统计() -> Dictionary:
	var 总购买次数 = 0
	var 总消费灵石 = 0
	var 商品购买统计 = {}
	for 记录 in 商城购买历史:
		总购买次数 += int(记录.get("数量", 1))
		总消费灵石 += int(记录.get("总价格", 0))
		var 商品名称 = str(记录.get("商品名称", ""))
		if 商品名称 not in 商品购买统计:
			商品购买统计[商品名称] = {"购买次数": 0, "总消费": 0}
		商品购买统计[商品名称]["购买次数"] += int(记录.get("数量", 1))
		商品购买统计[商品名称]["总消费"] += int(记录.get("总价格", 0))
	return {
		"总购买次数": 总购买次数,
		"总消费灵石": 总消费灵石,
		"商品购买统计": 商品购买统计,
	}

# 商城每日特惠商品
var 商城每日特惠: Array = []
var 商城每日特惠日期: int = 0

# 生成商城每日特惠
func 生成商城每日特惠() -> Array:
	if 商城每日特惠日期 == 累计游戏日 and 商城每日特惠.size() > 0:
		return 商城每日特惠
	商城每日特惠日期 = 累计游戏日
	商城每日特惠.clear()
	var 商品列表 = 获取商城商品列表()
	if 商品列表.size() == 0:
		return 商城每日特惠
	# 随机选择3-5个商品作为每日特惠
	var 特惠数量 = min(5, max(3, 商品列表.size() / 10))
	var 已选商品 = {}
	for i in range(特惠数量):
		if 商品列表.size() == 0:
			break
		var 随机索引 = randi() % 商品列表.size()
		var 商品 = 商品列表[随机索引]
		var 商品ID = str(商品.get("shop_id", ""))
		if 商品ID in 已选商品:
			continue
		已选商品[商品ID] = true
		var 折扣率 = 0.7 + float(randi() % 20) / 100.0  # 70%-90%折扣
		var 原价 = int(商品.get("price_lingjing", 0))
		var 特惠价 = int(round(原价 * 折扣率))
		商城每日特惠.append({
			"商品": 商品,
			"原价": 原价,
			"特惠价": 特惠价,
			"折扣率": 折扣率,
			"折扣百分比": int((1 - 折扣率) * 100),
		})
	return 商城每日特惠

# 获取商城每日特惠
func 获取商城每日特惠() -> Array:
	return 生成商城每日特惠()'''

if old_shop_func in content:
    content = content.replace(old_shop_func, new_shop_func)
    print("✅ 商城系统优化成功（添加按分类筛选商城商品、搜索商城商品、排序商城商品、商城购买历史记录、获取商城购买历史、获取商城购买统计、生成商城每日特惠、获取商城每日特惠）")
else:
    print("❌ 未找到获取商城分类列表函数")

# 2. 优化礼包系统 - 添加礼包分类、详情、购买历史、限时活动功能
# 在获取礼包统计函数后面添加更多功能
old_gift_func = '''# 获取礼包统计
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
	}'''

new_gift_func = '''# 获取礼包统计
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

# 礼包分类配置
const 礼包分类配置: Dictionary = {
	"新手礼包": {"描述": "新手专属礼包", "图标": "🎁"},
	"每日礼包": {"描述": "每日可购买礼包", "图标": "📅"},
	"每周礼包": {"描述": "每周可购买礼包", "图标": "📆"},
	"节日礼包": {"描述": "节日限定礼包", "图标": "🎉"},
	"成长礼包": {"描述": "成长助力礼包", "图标": "📈"},
	"战力礼包": {"描述": "战力提升礼包", "图标": "⚔️"},
	"资源礼包": {"描述": "资源补给礼包", "图标": "💎"},
	"特殊礼包": {"描述": "特殊限定礼包", "图标": "✨"},
}

# 按分类筛选礼包
func 按分类筛选礼包(分类: String) -> Array:
	var 筛选列表 = []
	var 礼包列表 = 获取所有礼包列表()
	for 礼包 in 礼包列表:
		if 礼包.get("分类", "") == 分类:
			筛选列表.append(礼包)
	return 筛选列表

# 获取礼包详情
func 获取礼包详情(礼包ID: String) -> Dictionary:
	var 礼包列表 = 获取所有礼包列表()
	for 礼包 in 礼包列表:
		if 礼包.get("id", "") == 礼包ID:
			var 详情 = 礼包.duplicate()
			# 计算礼包总价值
			var 总价值 = 0
			var 内容 = 礼包.get("内容", {})
			for 资源 in 内容.keys():
				var 数量 = int(内容[资源])
				# 简化：每种资源按1灵石计算
				总价值 += 数量
			详情["总价值"] = 总价值
			详情["性价比"] = float(总价值) / float(max(1, int(礼包.get("价格", 1))))
			return 详情
	return {"成功": false, "原因": "礼包不存在"}

# 礼包购买历史记录
var 礼包购买历史: Array = []

# 记录礼包购买
func _记录礼包购买(礼包ID: String, 礼包名称: String, 价格: int) -> void:
	礼包购买历史.append({
		"礼包ID": 礼包ID,
		"礼包名称": 礼包名称,
		"价格": 价格,
		"购买日期": 累计游戏日,
	})
	# 限制历史记录数量
	if 礼包购买历史.size() > 100:
		礼包购买历史.remove_at(0)

# 获取礼包购买历史
func 获取礼包购买历史(限制数量: int = 20) -> Array:
	var 历史 = 礼包购买历史.duplicate()
	历史.reverse()
	return 历史.slice(0, min(限制数量, 历史.size()))

# 获取礼包购买统计
func 获取礼包购买统计() -> Dictionary:
	var 总购买次数 = 0
	var 总消费灵石 = 0
	var 礼包购买统计 = {}
	for 记录 in 礼包购买历史:
		总购买次数 += 1
		总消费灵石 += int(记录.get("价格", 0))
		var 礼包名称 = str(记录.get("礼包名称", ""))
		if 礼包名称 not in 礼包购买统计:
			礼包购买统计[礼包名称] = {"购买次数": 0, "总消费": 0}
		礼包购买统计[礼包名称]["购买次数"] += 1
		礼包购买统计[礼包名称]["总消费"] += int(记录.get("价格", 0))
	return {
		"总购买次数": 总购买次数,
		"总消费灵石": 总消费灵石,
		"礼包购买统计": 礼包购买统计,
	}

# 限时礼包活动
var 限时礼包活动: Array = []
var 限时礼包活动日期: int = 0

# 生成限时礼包活动
func 生成限时礼包活动() -> Array:
	if 限时礼包活动日期 == 累计游戏日 and 限时礼包活动.size() > 0:
		return 限时礼包活动
	限时礼包活动日期 = 累计游戏日
	限时礼包活动.clear()
	var 礼包列表 = 获取所有礼包列表()
	if 礼包列表.size() == 0:
		return 限时礼包活动
	# 随机选择1-2个礼包作为限时活动
	var 活动数量 = min(2, max(1, 礼包列表.size() / 10))
	var 已选礼包 = {}
	for i in range(活动数量):
		if 礼包列表.size() == 0:
			break
		var 随机索引 = randi() % 礼包列表.size()
		var 礼包 = 礼包列表[随机索引]
		var 礼包ID = str(礼包.get("id", ""))
		if 礼包ID in 已选礼包:
			continue
		已选礼包[礼包ID] = true
		var 折扣率 = 0.5 + float(randi() % 30) / 100.0  # 50%-80%折扣
		var 原价 = int(礼包.get("价格", 0))
		var 活动价 = int(round(原价 * 折扣率))
		var 剩余天数 = 1 + randi() % 3  # 1-3天
		限时礼包活动.append({
			"礼包": 礼包,
			"原价": 原价,
			"活动价": 活动价,
			"折扣率": 折扣率,
			"折扣百分比": int((1 - 折扣率) * 100),
			"剩余天数": 剩余天数,
			"活动名称": "限时特惠",
		})
	return 限时礼包活动

# 获取限时礼包活动
func 获取限时礼包活动() -> Array:
	return 生成限时礼包活动()'''

if old_gift_func in content:
    content = content.replace(old_gift_func, new_gift_func)
    print("✅ 礼包系统优化成功（添加礼包分类配置、按分类筛选礼包、获取礼包详情、礼包购买历史记录、获取礼包购买历史、获取礼包购买统计、生成限时礼包活动、获取限时礼包活动）")
else:
    print("❌ 未找到获取礼包统计函数")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 商城系统和礼包系统优化完成！")
print("\n📋 已优化的功能：")
print("  1. 商城系统优化：")
print("     - 添加按分类筛选商城商品功能")
print("     - 添加搜索商城商品功能")
print("     - 添加商城商品排序功能（价格升序/降序、品阶升序/降序、名称升序）")
print("     - 添加商城购买历史记录功能")
print("     - 添加获取商城购买历史功能")
print("     - 添加获取商城购买统计功能")
print("     - 添加生成商城每日特惠功能（随机3-5个商品，70%-90%折扣）")
print("     - 添加获取商城每日特惠功能")
print("  2. 礼包系统优化：")
print("     - 添加礼包分类配置（新手礼包、每日礼包、每周礼包、节日礼包、成长礼包、战力礼包、资源礼包、特殊礼包）")
print("     - 添加按分类筛选礼包功能")
print("     - 添加获取礼包详情功能（包含总价值、性价比计算）")
print("     - 添加礼包购买历史记录功能")
print("     - 添加获取礼包购买历史功能")
print("     - 添加获取礼包购买统计功能")
print("     - 添加生成限时礼包活动功能（随机1-2个礼包，50%-80%折扣，1-3天有效期）")
print("     - 添加获取限时礼包活动功能")
print("\n📌 商城系统优化说明：")
print("  - 商品排序：支持价格升序/降序、品阶升序/降序、名称升序")
print("  - 品阶顺序：凡品(1) → 灵品(2) → 宝品(3) → 王品(4) → 仙品(5) → 神品(6)")
print("  - 购买历史：记录最近100次购买")
print("  - 每日特惠：每天随机3-5个商品，70%-90%折扣")
print("\n📌 礼包系统优化说明：")
print("  - 礼包分类：新手礼包、每日礼包、每周礼包、节日礼包、成长礼包、战力礼包、资源礼包、特殊礼包")
print("  - 礼包详情：包含总价值、性价比计算")
print("  - 购买历史：记录最近100次购买")
print("  - 限时活动：每天随机1-2个礼包，50%-80%折扣，1-3天有效期")

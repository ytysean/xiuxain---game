class_name FragmentChestSystem extends RefCounted

# ===== 碎片与宝箱系统状态变量 =====
var 碎片库存: Dictionary = {}
var 宝箱库存: Dictionary = {}

# ===== 碎片合成系统 =====

# 添加碎片
func 添加碎片(碎片ID: String, 数量: int) -> void:
	if 数量 <= 0:
		return
	碎片库存[碎片ID] = int(碎片库存.get(碎片ID, 0)) + 数量

# 移除碎片
func 移除碎片(碎片ID: String, 数量: int) -> bool:
	var 当前数量: int = int(碎片库存.get(碎片ID, 0))
	if 当前数量 < 数量:
		return false
	碎片库存[碎片ID] = 当前数量 - 数量
	if 碎片库存[碎片ID] <= 0:
		碎片库存.erase(碎片ID)
	return true

# 获取碎片数量
func 获取碎片数量(碎片ID: String) -> int:
	return int(碎片库存.get(碎片ID, 0))

# 执行碎片合成
func 执行碎片合成(碎片ID: String) -> Dictionary:
	var 数量: int = 获取碎片数量(碎片ID)
	var 结果: Dictionary = FragmentCraftSystem.执行合成(碎片ID, 数量, Game.灵石)
	if not 结果.get("成功", false):
		return 结果
	# 消耗碎片和灵石
	移除碎片(碎片ID, int(结果.get("消耗碎片数", 0)))
	Game.灵石 -= int(结果.get("消耗灵石", 0))
	# 产出物品（简化版本：根据产出类型添加到对应库存）
	var 产出ID: String = str(结果.get("产出ID", ""))
	var 产出类型: String = str(结果.get("产出类型", ""))
	match 产出类型:
		"碎片":
			添加碎片(产出ID, 1)
		"资源":
			# 资源类型直接添加到对应变量（简化版本）
			pass
		_:
			# 其他类型添加到宗门库房（简化版本）
			pass
	Game.添加纪事("大事件", "碎片合成", "合成%s成功" % str(结果.get("原因", "")), 2)
	return 结果

# ===== 宝箱系统 =====

# 添加宝箱
func 添加宝箱(宝箱ID: String, 数量: int) -> void:
	if 数量 <= 0:
		return
	宝箱库存[宝箱ID] = int(宝箱库存.get(宝箱ID, 0)) + 数量

# 移除宝箱
func 移除宝箱(宝箱ID: String, 数量: int) -> bool:
	var 当前数量: int = int(宝箱库存.get(宝箱ID, 0))
	if 当前数量 < 数量:
		return false
	宝箱库存[宝箱ID] = 当前数量 - 数量
	if 宝箱库存[宝箱ID] <= 0:
		宝箱库存.erase(宝箱ID)
	return true

# 获取宝箱数量
func 获取宝箱数量(宝箱ID: String) -> int:
	return int(宝箱库存.get(宝箱ID, 0))

# 打开宝箱
func 打开宝箱(宝箱ID: String) -> Dictionary:
	if 获取宝箱数量(宝箱ID) <= 0:
		return {"成功": false, "掉落列表": [], "原因": "宝箱数量不足"}
	var 结果: Dictionary = ChestSystem.打开宝箱(宝箱ID)
	if not 结果.get("成功", false):
		return 结果
	# 消耗宝箱
	移除宝箱(宝箱ID, 1)
	# 发放掉落物品（简化版本：根据物品类型添加到对应库存）
	for 掉落 in 结果.get("掉落列表", []):
		var 物品ID: String = str(掉落.get("物品ID", ""))
		var 物品类型: String = str(掉落.get("物品类型", ""))
		var 数量: int = int(掉落.get("数量", 1))
		match 物品类型:
			"资源":
				match 物品ID:
					"灵石": Game.灵石 += 数量
					"灵草": Game.灵草 += 数量
					"矿石": Game.矿石 += 数量
					"灵气": Game.灵气 += 数量
					"悟道点": Game.悟道点 += 数量
					"声望": Game.声望 += 数量
			"碎片":
				添加碎片(物品ID, 数量)
			"宝箱":
				添加宝箱(物品ID, 数量)
			_:
				# 其他类型添加到宗门库房（简化版本）
				pass
	Game.添加纪事("大事件", "宝箱开启", str(结果.get("原因", "")), 2)
	return 结果

# 序列化
func to_dict() -> Dictionary:
	return {
		"碎片库存": 碎片库存,
		"宝箱库存": 宝箱库存,
	}

# 反序列化
func from_dict(data: Dictionary) -> void:
	碎片库存 = data.get("碎片库存", {})
	宝箱库存 = data.get("宝箱库存", {})

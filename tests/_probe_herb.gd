extends Node

## P1-1 药园回归探针（headless · 驱动真实数据链 · 2026-09-16）
## 验证：地块自愈（新档/旧档列表为空时重建）→ 种植 → 成熟 → 收获 → 资源到账
## 判据末行 >>>HERB_DONE FAIL=n
## 用法：<godot> --headless --path <proj> --scene res://tests/_probe_herb.tscn

var _fail := 0


func _ck(名称: String, 条件: bool, 详情: String = "") -> void:
	if 条件:
		print(">>>HERB PASS %s %s" % [名称, 详情])
	else:
		_fail += 1
		printerr(">>>HERB_FAIL %s %s" % [名称, 详情])


func _ready() -> void:
	var t := Timer.new()
	t.wait_time = 90.0
	t.one_shot = true
	t.timeout.connect(func() -> void:
		printerr(">>>HERB TIMEOUT")
		get_tree().quit())
	add_child(t)
	t.start()
	if Game == null:
		printerr(">>>HERB_FAIL Game 单例缺失")
		get_tree().quit()
		return
	if Game.弟子列表.is_empty():
		Game.初始建宗()

	var 园 = Game.药园系统

	# 0) 作物配置键不应被 "Game." 前缀污染（历史笔误回归）
	var 作物: Array = Game.获取可种植作物列表()
	var 名集: Array = []
	for c in 作物:
		名集.append(str(c.get("名称", "")))
	_ck("作物键无Game前缀", not (名集.has("Game.灵草") or 名集.has("Game.灵石")), str(名集.slice(0, 3)))
	_ck("灵草在作物表", 名集.has("灵草"), "作物数=%d" % 名集.size())

	# 1) 模拟旧档/未初始化：清空列表后读取应自愈
	园.药园地块列表 = []
	园.药园地块数量 = 1
	var 列表: Array = Game.获取药园地块列表()
	_ck("空列表自愈", 列表.size() == 1, "size=%d" % 列表.size())

	# 2) 种植（ID 0 起）
	var 种: Dictionary = Game.种植药园(0, "灵草")
	_ck("种植灵草成功", bool(种.get("成功", false)), str(种.get("原因", 种.get("消息", ""))))
	var 越界: Dictionary = Game.种植药园(99, "灵草")
	_ck("越界地块被拒", not bool(越界.get("成功", true)), str(越界.get("原因", "")))

	# 3) 推进到成熟后收获
	var 草前: int = Game.灵草
	Game.累计游戏日 += 10
	var 收: Dictionary = Game.收获药园(0)
	_ck("收获成功", bool(收.get("成功", false)), str(收.get("原因", 收.get("收获", ""))))
	_ck("灵草到账8", Game.灵草 == 草前 + 8, "前=%d 后=%d" % [草前, Game.灵草])

	# 4) 解锁新地块（自愈后 ID 应连续，不出现数量漂移）
	var 解: Dictionary = Game.解锁药园地块(0)
	_ck("解锁地块成功", bool(解.get("成功", false)), str(解.get("地块ID", 解.get("原因", ""))))
	_ck("地块数与列表一致", 园.药园地块数量 == Game.获取药园地块列表().size(),
		"数量=%d 列表=%d" % [园.药园地块数量, Game.获取药园地块列表().size()])

	# 5) 一键种植/收获（空转不应报错）
	var 一键: Dictionary = Game.一键种植药园("灵谷")
	_ck("一键种植有结果", 一键.has("种植数量"), str(一键.get("消息", "")))

	print(">>>HERB_DONE FAIL=%d" % _fail)
	get_tree().quit()

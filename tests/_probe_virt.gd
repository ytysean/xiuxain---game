extends Node

## P1-2 超重页分批渲染回归探针（headless · 2026-09-16）
## 验证功绩堂：首屏只建 每批 条卡片、数据总量保留、可续建、切 Tab 能重置
## 判据末行 >>>VIRT_DONE FAIL=n

var _fail := 0


func _ck(名称: String, 条件: bool, 详情: String = "") -> void:
	if 条件:
		print(">>>VIRT PASS %s %s" % [名称, 详情])
	else:
		_fail += 1
		printerr(">>>VIRT_FAIL %s %s" % [名称, 详情])


func _ready() -> void:
	var t := Timer.new()
	t.wait_time = 90.0
	t.one_shot = true
	t.timeout.connect(func() -> void:
		printerr(">>>VIRT TIMEOUT")
		get_tree().quit())
	add_child(t)
	t.start()
	if Game == null:
		printerr(">>>VIRT_FAIL Game 单例缺失")
		get_tree().quit()
		return
	if Game.弟子列表.is_empty():
		Game.初始建宗()

	var 页 = preload("res://ui/page_achievement.gd").new()
	add_child(页)
	页.refresh()
	await get_tree().process_frame
	await get_tree().process_frame

	var 总成就: int = Game.成就配置.size()
	var 首屏: int = 页._列表.get_child_count()
	print(">>>VIRT 成就总数=%d 首屏卡片=%d 待渲染=%d" % [总成就, 首屏, 页._待渲染.size()])
	_ck("首屏不超批次上限", 首屏 <= 页.每批, "首屏=%d 上限=%d" % [首屏, 页.每批])
	_ck("首屏非空", 首屏 > 0, "首屏=%d" % 首屏)
	_ck("待渲染保留全量", 页._待渲染.size() == 总成就,
		"待渲染=%d 总数=%d" % [页._待渲染.size(), 总成就])

	# 续建一批
	页._追加一批()
	await get_tree().process_frame
	var 续后: int = 页._列表.get_child_count()
	_ck("可续建下一批", 续后 > 首屏, "首屏=%d 续后=%d" % [首屏, 续后])

	# 切 Tab（传承）后应重置游标并重新分批
	页._on_tab_pressed("宗门传承")
	await get_tree().process_frame
	var 传承首屏: int = 页._列表.get_child_count()
	var 传承总量: int = Game.获取所有里程碑列表().size()
	_ck("切Tab后重置分批", 传承首屏 <= 页.每批, "传承首屏=%d 总量=%d" % [传承首屏, 传承总量])
	_ck("切Tab模式正确", 页._渲染模式 == "传承", str(页._渲染模式))

	# 全量建完后游标应等于总量，且不再增长
	while 页._渲染游标 < 页._待渲染.size():
		页._追加一批()
	await get_tree().process_frame
	_ck("全量建完游标对齐", 页._渲染游标 == 页._待渲染.size(),
		"游标=%d 总量=%d" % [页._渲染游标, 页._待渲染.size()])
	var 满: int = 页._列表.get_child_count()
	页._追加一批()
	_ck("建完后不再增长", 页._列表.get_child_count() == 满, "节点=%d" % 满)

	print(">>>VIRT_DONE FAIL=%d" % _fail)
	get_tree().quit()

extends Node

# 阵营声望页条目规模探针（headless · 2026-09-16）
# 目的：page_faction 打开耗时 545ms，需确认是条目数量还是布局成本。

var _fail: int = 0

func _ok(名: String, 条件: bool, 备注: String = "") -> void:
	if 条件:
		print(">>>FAC ok %s %s" % [名, 备注])
	else:
		_fail += 1
		print(">>>FAC_FAIL %s %s" % [名, 备注])

func _ready() -> void:
	var t := Timer.new()
	t.wait_time = 20.0
	t.one_shot = true
	t.timeout.connect(func(): get_tree().quit(1))
	add_child(t)
	t.start()
	_跑.call_deferred()

func _跑() -> void:
	var 总NPC: int = 0
	if Game.has_method("获取所有阵营NPC列表"):
		var 全: Dictionary = Game.获取所有阵营NPC列表()
		for k in 全.keys():
			总NPC += (全[k] as Array).size()
		print(">>>FAC 阵营NPC 阵营数=%d 总数=%d" % [全.keys().size(), 总NPC])
	else:
		print(">>>FAC 无 获取所有阵营NPC列表")

	if Game.has_method("获取可交互NPC列表"):
		var 交: Array = Game.获取可交互NPC列表()
		print(">>>FAC 可交互NPC 数=%d" % 交.size())
	else:
		print(">>>FAC 无 获取可交互NPC列表")

	if Game.has_method("获取所有敌对NPC"):
		var 敌: Array = Game.获取所有敌对NPC()
		print(">>>FAC 敌对NPC 数=%d" % 敌.size())
	else:
		print(">>>FAC 无 获取所有敌对NPC")

	if Game.has_method("获取阵营战役列表"):
		var 战: Array = Game.获取阵营战役列表()
		print(">>>FAC 阵营战役 数=%d" % 战.size())

	# 分段计时：整页构建 + refresh
	var 路径: String = "res://ui/page_faction.gd"
	if ResourceLoader.exists(路径):
		var sc: Script = load(路径)
		var t0 := Time.get_ticks_msec()
		var p: Control = sc.new()
		add_child(p)
		var t1 := Time.get_ticks_msec()
		p.refresh()
		var t2 := Time.get_ticks_msec()
		print(">>>FAC 构建ms=%d refreshms=%d 节点数=%d" % [t1 - t0, t2 - t1, _数节点(p)])
		_ok("构建+refresh 无异常", true)
	else:
		_ok("page_faction.gd 存在", false)

	print(">>>FAC_ALL_DONE FAIL=%d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)

func _数节点(n: Node) -> int:
	var c: int = 1
	for ch in n.get_children():
		c += _数节点(ch)
	return c

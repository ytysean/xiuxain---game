extends Node

## P1-3 孤儿节点归因探针（真实渲染 · 窗口移出屏幕 · 2026-09-16）
## headless 下实测各页 orphan 增量恒为 0，故必须在真实渲染路径下归因。
## 逐个实例化重页 → 关闭 → 统计孤儿节点增量，定位「创建后不入树/不释放」的元凶页面。
## 判据末行 >>>ORPHAN_DONE（增量明细见 >>>ORPHAN 增量 行）

const 页面表: Array = [
	"achievement", "chronicle", "codex", "faction", "disciple",
	"shop", "treasure", "sect_manager", "library", "quest",
	"activity", "leaderboard", "atlas", "building", "storage",
	"disciple_detail_page", "herb_garden", "fishing", "world_map", "premium",
]

var _fail := 0


func _孤儿数() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func _ready() -> void:
	# 真实渲染但窗口移出屏幕：headless 的 dummy 渲染不走 UI 真实构建路径，测不出 orphan
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)
	var t := Timer.new()
	t.wait_time = 180.0
	t.one_shot = true
	t.timeout.connect(func() -> void:
		printerr(">>>ORPHAN TIMEOUT")
		get_tree().quit())
	add_child(t)
	t.start()
	if Game == null:
		printerr(">>>ORPHAN_FAIL Game 单例缺失")
		get_tree().quit()
		return
	if Game.弟子列表.is_empty():
		Game.初始建宗()

	var 基线: int = _孤儿数()
	print(">>>ORPHAN 基线=%d" % 基线)

	for nm in 页面表:
		var 路径: String = "res://ui/page_%s.gd" % nm
		if not ResourceLoader.exists(路径):
			路径 = "res://ui/%s.gd" % nm
		if not ResourceLoader.exists(路径):
			print(">>>ORPHAN 跳过 %s（脚本不存在）" % nm)
			continue
		var 前: int = _孤儿数()
		var 脚本: Script = load(路径)
		var 页: Node = 脚本.new()
		add_child(页)
		await get_tree().process_frame
		await get_tree().process_frame
		var 开后: int = _孤儿数()
		remove_child(页)
		页.free()
		await get_tree().process_frame
		var 关后: int = _孤儿数()
		print(">>>ORPHAN 增量 %s 开=%+d 净=%+d" % [nm, 开后 - 前, 关后 - 前])
		# 关闭后仍不回落的，说明该页留下了未释放的节点
		if 关后 - 前 > 5:
			_fail += 1

	print(">>>ORPHAN 结束=%d 基线=%d" % [_孤儿数(), 基线])
	print(">>>ORPHAN_DONE FAIL=%d" % _fail)
	get_tree().quit()

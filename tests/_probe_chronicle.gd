extends Node

# 纪事数据源验证：名称字段是否真的丢了「里」字
func _ready() -> void:
	var t := Timer.new()
	t.wait_time = 15.0
	t.one_shot = true
	t.timeout.connect(func(): get_tree().quit(1))
	add_child(t)
	t.start()
	_跑.call_deferred()

func _跑() -> void:
	var n: int = 0
	for e in Game.宗门纪事:
		var 名: String = str(e.get("名称", ""))
		if "碑" in 名 or "里程" in 名:
			print(">>>CHR 名称=[%s] 稀有度=[%s] 文案=[%s]" % [名, str(e.get("稀有度", "")), str(e.get("文案", "")).left(40)])
			n += 1
			if n >= 5:
				break
	# 顺带检查里程碑配置的名称
	for m in Game.里程碑配置:
		print(">>>CHR 里程碑配置 名称=[%s]" % str(m.get("名称", "")))
		break
	print(">>>CHR_ALL_DONE")
	get_tree().quit(0)

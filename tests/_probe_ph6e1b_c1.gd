extends Node
## PH6-E1 · B4+C1 探针（headless）：符箓「战力」词条 flat→比率并入 聚合通用增益()，单源子帽 ≤8%（裁决 A-各自）
##
## 运行：<godot> --headless --path <proj> --scene res://tests/_probe_ph6e1b_c1.tscn
## 判据：末行出现 >>>C1_PROBE_DONE，且全程无 SCRIPT ERROR / FATAL。
## 目的：①证明符箓已从 base 迁入比率池；②证明 8% 子帽在超帽例生效；③给出 UI:1648 显示值 vs 实际生效值。
## 说明：Disciple.new() 走 随机生成()，本探针覆盖 境界 后挂/卸 护身符，Δ = 有符−无符 即「符箓净贡献」。

func _ready() -> void:
	prints("=== PH6-E1 C1/B4 探针启动 ===")
	if Game == null:
		printerr("FATAL: Game 单例缺失")
		get_tree().quit()
		return
	Game.符词条池()   # 确保符词条真源（config/talisman_affix_config.csv）已载

	# 用例：(标签, 境界, 符词条战力 flat) —— 配置实测 flat 档位 6/18/48/120/210/360/720
	_用例("无符基线·练气", "练气", 0.0)
	_用例("有符未超帽·元婴", "元婴", 120.0)     # 0.08*6000=480 > 120
	_用例("有符未超帽·道阶", "道阶", 720.0)     # 0.08*200000=16000 > 720
	_用例("有符超帽·练气", "练气", 18.0)       # 0.08*100=8 < 18
	_用例("有符超帽·金丹", "金丹", 720.0)      # 0.08*1500=120 < 720

	prints(">>>C1_PROBE_DONE")
	get_tree().quit()


func _用例(标签: String, 境: String, 符战力: float) -> void:
	var d: Disciple = Disciple.new()
	d.境界 = 境

	# 无符基线
	d.护身符 = null
	var 战力无符: int = d.计算战力()
	var 池无符: float = d.聚合通用增益()

	# 构符（flat「战力」类词条，模拟 talisman_affix_config 的 战力 档）
	var 符: Item = Item.new()
	符.类别 = "fu_lu"
	符.品阶 = 境
	符.名称 = "[探针]符_" + 境
	if 符战力 > 0.0:
		符.符词条 = [{"key": "probe_zhan", "中文名": "探针符", "类型": "战力", "数值": 符战力}]
	d.护身符 = 符

	# 有符
	var 战力有符: int = d.计算战力()
	var 池有符: float = d.聚合通用增益()

	var 境基础: float = float(d.境界表[境]["战力"])
	var 归一: float = 0.0
	if 境基础 > 0.0:
		归一 = 符战力 / 境基础
	var 子帽: float = clamp(归一, 0.0, 0.08)
	var ui显示: int = int(Game.护身符战力加成(d))
	var 有效贡献比: float = 池有符 - 池无符

	prints(">>>CASE", 标签,
		"| 境", 境, "境基础", 境基础,
		"| 符flat", 符战力, "归一", 归一, "子帽", 子帽,
		"| 池 无→有", 池无符, "→", 池有符, "Δ池", 有效贡献比,
		"| 战力 无→有", 战力无符, "→", 战力有符, "Δ实际", 战力有符 - 战力无符,
		"| UI:1648显示", ui显示,
		"| UI==Δ实际?", str(ui显示 == (战力有符 - 战力无符)))

extends Node

# 全系统 headless 冒烟：驱动真实 Game 主循环 + 各系统动作函数 + 存档读档。
# 注意：lambda 必须 `return` 调用结果，否则 GDScript 单表达式 lambda 只执行副作用、返回 null。
# 运行：MSYS_NO_PATHCONV=1 E:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path E:/Xiuxuanzongmenlu --scene res://tests/headless_smoke.tscn

func _ready() -> void:
	prints("=== 全系统 headless 冒烟启动 ===")
	if Game == null:
		printerr("FATAL: Game 单例缺失")
		get_tree().quit()
		return

	if Game.弟子列表.is_empty():
		Game.初始建宗()
	for d in Game.弟子列表:
		d.状态 = "在宗"
	prints("初始弟子数:", Game.弟子列表.size(), " 宗主:", Game.宗主.姓名, Game.宗主.境界,
		" 累计游戏日:", Game.累计游戏日)
	prints("系统挂载检查: 灵钓=", Game.灵钓系统 != null, " 探秘=", Game.探秘系统 != null,
		" 饲灵=", Game.饲灵系统 != null, " 卜算=", Game.卜算系统 != null,
		" 药圃=", Game.药圃系统 != null, " 论道=", Game.论道系统 != null, " 商队=", Game.商队系统 != null)

	# ---------- 阶段1：主循环时间推进（整链集成，跨季界触发全部 _需月度结算 钩子）----------
	prints("\n[阶段1] 推演一月×100（跨季界，触发全部月度钩子含 S48/S49/S51 自动调用）")
	for i in range(100):
		prints("  -- 第", i + 1, "月 累计", Game.累计游戏日)
		Game.推演一月(1)
	prints("[阶段1] 时间推进完成，无异常中止")

	# ---------- 阶段2：各系统动作函数（成功路径，调用前打标记）----------
	prints("\n[阶段2] 各系统动作函数调用（成功路径）")
	_try("S8 商道 刷新商队行情", func(): return Game.刷新商队行情())
	_try("S8 商道 获取商道境界加成", func(): return Game.商队系统.获取商道境界加成())
	_try("S46 灵钓 开始灵钓(0)", func(): return Game.灵钓系统.开始灵钓(0))
	_try("S46 灵钓 结算钓获(0.5,0)", func(): return Game.灵钓系统.结算钓获(0.5, 0))
	_try("S47 探秘 开始探秘(0)", func(): return Game.探秘系统.开始探秘(0))
	_try("S47 探秘 结算探秘(0)", func(): return Game.探秘系统.结算探秘(0))
	_try("S48 饲灵 结算饲灵", func(): return Game.饲灵系统.结算饲灵("饲灵", false, false))
	_try("S49 卜算 结算卜算(日常吉凶)", func(): return Game.卜算系统.结算卜算("日常吉凶", false))
	_try("S49 卜算 参与观星周", func(): return Game.卜算系统.参与观星周())
	_try("S50 药圃 结算种植", func(): return Game.药圃系统.结算种植(false, false))
	_try("S50 药圃 参与观博周", func(): return Game.药圃系统.参与观博周())
	_try("S51 论道 获取本周论道周", func(): return Game.论道系统.获取本周论道周())
	_try("S51 论道 结算论道(weiqi)", func(): return Game.论道系统.结算论道("weiqi", false, false))
	_try("S51 论道 参与论道大会", func(): return Game.论道系统.参与论道大会())
	# 豆包休闲后端（未挂载，仅验证后端函数不崩；返回成功/失败 dict 均算不崩）
	_try("豆包 宗主狩猎", func(): return Game.宗主狩猎("示例猎区"))
	_try("豆包 宗主采药", func(): return Game.宗主采药("示例药区"))
	_try("豆包 开始酿造灵酿", func(): return Game.开始酿造灵酿("示例配方"))
	_try("豆包 堪舆地脉", func(): return Game.堪舆地脉())
	_try("豆包 宗主抚琴(清心谱)", func(): return Game.宗主抚琴("清心谱"))

	# ---------- 阶段3：存档 / 读档 round-trip（真实持久化，验证全部 to_dict/from_dict 不崩）----------
	prints("\n[阶段3] save_game / load_game round-trip")
	Game.save_game()
	prints("  save_game 完成")
	Game.load_game("")
	prints("  load_game 完成，无异常")

	# ---------- 阶段4：强制覆盖曾崩的死亡/转世路径（概率不必然触发，直接调用保证覆盖）----------
	prints("\n[阶段4] 强制调用死亡/转世路径（原 `.has()` 对象误用崩溃点）")
	var 样本: Object = null
	if not Game.弟子列表.is_empty():
		样本 = Game.弟子列表[0]
	elif Game.宗主 != null:
		样本 = Game.宗主
	if 样本 != null:
		_try("死亡路径 _道心不稳离去判定", func(): Game._道心不稳离去判定(样本))
		_try("死亡路径 _执行兵解成鬼仙", func(): Game._执行兵解成鬼仙(样本))
		_try("死亡路径 _执行飞升", func(): Game._执行飞升(样本))
		_try("死亡路径 _转世判定(返回bool)", func(): return Game._转世判定(样本))
	else:
		prints("  （无可用弟子样本，跳过强制死亡路径）")

	prints("\n=== 冒烟完成（如上方无 SCRIPT ERROR / 崩溃，则全部通过）===")
	get_tree().quit()


func _try(标签: String, 动作: Callable) -> void:
	prints("  >>", 标签)
	var 结果 = 动作.call()
	if 结果 is Dictionary:
		var 成功 = 结果.get("成功", "—")
		prints("     -> 成功=", 成功, " 键:", 结果.keys())
	elif 结果 == null:
		prints("     -> (void/null)")
	else:
		prints("     -> 类型", typeof(结果), "值", 结果)

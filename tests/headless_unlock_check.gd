extends Node

## P0-1 洋葱式系统解锁 引擎自检（headless 实机）
## 验证：表加载 / 四类条件判定 / 入口与页面查询 / fail-open / 强制全解锁开关

func _ready() -> void:
	prints("=== P0-1 洋葱式解锁 引擎自检 ===")
	if Game == null:
		printerr("FATAL: Game 单例缺失")
		get_tree().quit()
		return
	var U: SystemUnlock = Game.系统解锁
	if U == null:
		printerr("FATAL: Game.系统解锁 未挂载")
		get_tree().quit()
		return

	prints("[1] 引擎装载快照: ", U.调试快照())
	prints("    基准态 门派等级=", Game.门派等级, " 累计突破=", Game.累计弟子突破次数, " 辈分序=", Game.当前辈分序)

	prints("[2] 开局系统（应全 true）: ",
		U.已解锁("disciple_recruit"), " ", U.已解锁("hall_assign"), " ", U.已解锁("cultivate_breakthrough"))
	prints("[3] 首次突破后系统 storage（基准应 false）: ", U.已解锁("storage"))
	prints("[4] 门派等级2系统 alchemy（基准应 false）: ", U.已解锁("alchemy"))
	prints("[5] 门派等级4系统 auction（基准应 false）: ", U.已解锁("auction"))
	prints("[6] 未知系统（fail-open 应 true）: ", U.已解锁("不存在的系统__x"))

	prints("[7] 入口 弟子（开局，应 true）: ", U.入口已解锁("弟子"))
	prints("[8] 入口 殿阁（开局，应 true）: ", U.入口已解锁("殿阁"))
	prints("[9] 入口 库藏（突破后，基准应 false）: ", U.入口已解锁("库藏"))
	prints("[10] 入口 拍卖行（等级4，基准应 false）: ", U.入口已解锁("拍卖行"))
	prints("[11] 入口 天下（原「山门」·B6 更名，开局，应 true）: ", U.入口已解锁("天下"))
	prints("[12] 页面 page_auction（基准应 false）: ", U.页面已解锁("page_auction"))
	prints("[13] 页面 page_disciple（开局，应 true）: ", U.页面已解锁("page_disciple"))

	# ── 模拟宗门壮大：等级→6，突破→1 ──
	var 旧等级: int = Game.门派等级
	var 旧突破: int = Game.累计弟子突破次数
	var 旧辈分: int = Game.当前辈分序
	Game.门派等级 = 6
	Game.累计弟子突破次数 = 1
	prints("[14] 成长后（等级6/突破1）库藏:", U.入口已解锁("库藏"),
		" 丹方:", U.入口已解锁("丹方"),
		" 拍卖行:", U.入口已解锁("拍卖行"),
		" 宗门战:", U.入口已解锁("宗门战"))

	Game.当前辈分序 = 2
	prints("[15] 辈分序=2（第二代）祖师堂（应 true）:", U.入口已解锁("祖师堂"))
	Game.当前辈分序 = 1
	prints("[16] 辈分序=1（第一代）祖师堂（应 false）:", U.入口已解锁("祖师堂"))

	# ── 强制全解锁开关 ──
	Game.门派等级 = 1
	Game.累计弟子突破次数 = 0
	U.强制全解锁 = true
	prints("[17] 强制全解锁后 拍卖行/库藏（应全 true）:", U.入口已解锁("拍卖行"), " ", U.入口已解锁("库藏"))
	U.强制全解锁 = false
	prints("[18] 复原后 库藏（应 false）:", U.入口已解锁("库藏"))

	# ── 还原 ──
	Game.门派等级 = 旧等级
	Game.累计弟子突破次数 = 旧突破
	Game.当前辈分序 = 旧辈分
	prints("[19] 已还原 门派等级=", Game.门派等级, " 累计突破=", Game.累计弟子突破次数, " 辈分序=", Game.当前辈分序)
	prints("[20] 已解锁系统数（基准态）: ", U.已解锁系统列表().size())

	prints("=== 自检结束（无 SCRIPT ERROR 即通过）===")
	get_tree().quit()

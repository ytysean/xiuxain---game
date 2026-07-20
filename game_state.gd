# game_state.gd —— 宗门全局状态（Autoload 单例，名称设为 "Game"）
# M1.5：时间推演（自动养成）/ 12 堂口 / 测灵根招收 / 门派等级声望 / 汇总报告
# 移除手动「结算一日」「派遣历练」，改由登录时自动推演 elapsed 现实时间。
extends Node

const Disciple = preload("res://disciple.gd")
const Item = preload("res://item.gd")
const Beast = preload("res://beast.gd")
const Lore = preload("res://lore.gd")
const Quest = preload("res://quest.gd")
const BattleManager = preload("res://BattleManager.gd")   # ADR-003 D1/D6：战斗编排层（纯逻辑，无 Game 依赖）
const StageDataLoader = preload("res://StageDataLoader.gd")   # Day 2 关卡数据层（纯数据，无 Game 依赖）
const DestinyDataLoader = preload("res://DestinyDataLoader.gd")   # 命格数据层（纯数据，无 Game 依赖）

# 时间流速：240 现实秒 = 1 游戏日（1 现实天 ≈ 1 游戏年）
# === S1 端口：时辰历法换算层 ===
# 调用位置：所有周期玩法（刷新/结算/突破冷却）读取「游戏日」处，应在读取前经此层换算为「时辰→日→月→年」。
# 入参：游戏日(int) | 返回值：Dict{时辰, 日, 月, 年} 或统一游戏内时间戳（S1 定）
# 状态：当前未建，仅标记；现役仍用 累计游戏日 裸整数。依赖：时间换算层（见 §四 时间体系修真化）。
const 现实秒每游戏日 := 240.0
const 现实秒每游戏日 := 240.0
const 单次推演上限日 := 3650
const SAVE_VERSION := 1   # 存档结构版本号：损坏检测与跨版本兼容用

var 灵石 := 1000
var 贡献点 := 0
var 弟子列表: Array[Disciple] = []   # 强类型数组（需 disciple.gd 已注册 class_name）

# 御兽堂：孵化中的灵兽蛋 + 已孵化待绑定的灵兽库存
var 灵兽蛋列表: Array[Beast] = []
var 灵兽库存: Array[Beast] = []

# 待抉择队列：弟子获得的极品/特殊道具，等待玩家决定“交宗换贡献”或“弟子自留”
var 待抉择: Array[Dictionary] = []

# 奇遇待抉择队列（ADR-002 D4）：紫+ 奇遇需掌门干预；结构 {弟子, 奇遇包, 选项}；会话瞬时，load 时清空
var 奇遇待抉择: Array[Dictionary] = []
# 宗门纪事（最简版）：本次会话已触发的奇遇历史，供 main.gd「纪事」标签回看；会话瞬时，load 时清空
var 宗门纪事: Array = [] 
# 全宗气运 buff（天品灵根弟子招募触发）：修炼+3% / 产出+2%，持续 7 游戏日
var 气运修炼加成: float = 0.0
var 气运产出加成: float = 0.0
var 气运到期日: int = 0
var 天品突破播报: String = ""   # 单次推演内天品弟子突破播报，结算后由 main.gd 弹出；不存档

# Sprint-02b：奇遇冷却/限流
var _上次奇遇时刻 := 0                    # 上次触发奇遇的真实时刻（ms），用于全局冷却
var _今日奇遇次数 := 0                    # 当日已触发奇遇次数
var _奇遇日标记 := -1                     # 记录 _今日奇遇次数 对应的游戏日
var _单条冷却记录: Dictionary = {}         # event_id → 触发时的累计游戏日

# 时间 / 门派
var 累计游戏日 := 0
var 最后登录 := 0
var 门派等级 := 1
var 声望 := 0
var 繁荣 := 50
var 引导阶段: int = 0   # 新手引导：0未开始/1-4四步/5完成（老档兼容见 load_game 默认5）
var 上次测灵日 := 0        # 测灵根冷却：上次举办时的游戏日（1年一度=365游戏日）

# 堂口系统：{key: {key,名称,职能,产出,加成维度,负责人:Disciple,成员:Array}}
var 堂口列表: Dictionary = {}
var 堂口负责人存档: Dictionary = {}

# ============ 建筑被动（阶段2：占位建筑被动功能）============
# 资源翻倍类：本月各资源建筑实际产出额（供 _建筑被动结算 概率翻倍时直接加回，避免重复计算 经营/气运/产出 乘区）
var _本月灵田产出: int = 0
var _本月矿脉产出: int = 0
var _本月丹堂产出: int = 0
var _本月器堂产出: int = 0
# [DORMANT] 负面事件减免聚合（zhifa/tanwei/zhenfa）：当前无负面/入侵事件系统，仅暂存不消费
var 建筑被动_负面事件减免: float = 0.0

# 推演日志（本次登录汇总，结构化条目供 UI 分层展示）
# 每条: {event_type:String, priority:String, text:String, data:Dictionary}
# event_type 枚举: breakthrough / appoint / quest / loot / resource / sect / info
# priority 枚举: high / normal / trivial
var 推演日志: Array[Dictionary] = []

# 推演事件类型常量（与 UI 符号图标映射）
const ET_BREAKTHROUGH := "breakthrough"   # 🔺 境界突破
const ET_APPOINT     := "appoint"         # 📜 岗位任职
const ET_QUEST       := "quest"           # ✅/❌ 奇遇/探索事件
const ET_LOOT        := "loot"            # 🎁 获得物品
const ET_RESOURCE    := "resource"        # 💰 资源产出
const ET_SECT        := "sect"            # 📜 宗门事件
const ET_INFO        := "info"            # ℹ️ 系统信息

# 推演优先级常量
const PRIO_HIGH   := "high"     # 重大事件（突破/稀有道具）
const PRIO_NORMAL := "normal"   # 普通（任职/正向奇遇）
const PRIO_TRIVIAL:= "trivial"  # 琐事（无功而返/无奖励）

# 战斗/历练系统（Day 2 数据驱动）
var 体力 := 50
var 已通关关卡: Dictionary = {}      # stage_id -> true（首通标记，解锁下一关用）
var 精英每日次数: Dictionary = {}     # "%d" % 累计游戏日 -> {stage_id: 已挑战次数}

signal 弟子变动()
signal 战报更新(文本: String)
# Step 1 奇遇三场景接入：任一触发点命中奇遇后 emit，供 main.gd（Step 2）做 L1 气泡 / L2 弹窗 / L3 全屏 调度。
signal 奇遇发生(q: Dictionary, 弟子: Disciple)

# ============ 建筑被动·常驻乘区（阶段2：占位建筑被动功能）============
# 12 堂口始终存在于 堂口列表（重建堂口 全量创建），故以下「建筑存在即生效」的常驻效果恒生效。
# 全部作用于既有计算链路的对应乘区，绝不污染奇遇池（event_quest / quest.gd / 奇遇发生 signal）。

# 接引堂：接引大典高品质弟子概率 +2%（与阶段1 负责人测灵+1% 叠加，最多+3%）
func _接引堂测灵加() -> float:
	return 0.02 if 堂口列表.has("yuying") else 0.0

# 功勋阁：全局声望获取 +10% → 所有 声望 += 处乘此系数
func _功勋阁声望乘区() -> float:
	return 1.10 if 堂口列表.has("gongxun") else 1.0

# 藏经阁：全宗弟子 修炼速度 +5%（乘入 推演一月 修炼buff）
func _藏经阁修炼乘区() -> float:
	return 1.05 if 堂口列表.has("cangjing") else 1.0

# [DORMANT] 负面事件减免聚合：zhifa -15% / tanwei -5% / zhenfa -12%，叠加封顶 -30%
# 当前宗门事件（Lore.取宗门事件）均为正面 flavor，无负面/入侵事件系统 → 本值暂存不消费；
# 未来接入负面事件判定点时，于该判定处乘 (1.0 + 本值) 即可生效。
func _负面事件减免() -> float:
	var v: float = 0.0
	if 堂口列表.has("zhifa"):
		v -= 0.15
	if 堂口列表.has("tanwei"):
		v -= 0.05
	if 堂口列表.has("zhenfa"):
		v -= 0.12
	return max(v, -0.30)

# 声望统一结算入口（套用功勋阁常驻 +10% 乘区；不触碰战斗数值红线）
func _加声望(基础: int) -> void:
	声望 += int(round(基础 * _功勋阁声望乘区()))

func _ready():
	load_game()
	if 弟子列表.is_empty():
		初始建宗()
	重建堂口()
	弟子变动.emit()

# 初始建宗（首次运行）：若干练气弟子 + 一位已入门长老作示范
func 初始建宗():
	for i in 5:
		弟子列表.append(Disciple.new())
	# 一位创始人：直接筑基入门，展示职业/堂口
	var 祖 := Disciple.new()
	祖.突破()           # 练气→筑基，触发 判定职业 + 入堂
	弟子列表.append(祖)

# 招收一名弟子（内部/自动用）
func 招收弟子() -> Disciple:
	var d := Disciple.new()
	弟子列表.append(d)
	弟子变动.emit()
	return d

# ============ 时间推演核心 ============
func 推演至现在() -> String:
	推演日志 = []
	# 资源快照（用于总览展示"本次收益"，展示型领取不二次发资源）
	var 灵石快照 := 灵石
	# 解锁职业池随门派等级更新（供筑基判定职业使用）
	Disciple.解锁职业池 = 已解锁职业()
	var 现在: int = int(Time.get_unix_time_from_system())
	if 最后登录 <= 0:
		最后登录 = 现在
	var 流逝秒: int = 现在 - 最后登录
	var 流失日: int = int(流逝秒 / 现实秒每游戏日)
	流失日 = clamp(流失日, 0, 单次推演上限日)
	var 剩余 := 流失日
	while 剩余 > 0:
		var 步: int = min(30, 剩余)
		推演一月(步)
		剩余 -= 步
	最后登录 = 现在
	if 流失日 == 0:
		_加推演条目("（本次登录无时间流逝，直接进入。）", ET_INFO, PRIO_TRIVIAL)
	弟子变动.emit()
	var 报: String = 生成结构化汇总(流失日, 灵石 - 灵石快照)
	战报更新.emit(报)
	return 报

# 设置全宗气运 buff（天品测灵 / 天品突破共用）
# 规则1：同类取最高值生效，不叠加数值（强 buff 不被弱 buff 覆盖）
# 规则2：同强度刷新持续时长，不累加时间（以当前日期为基准取更晚到期，避免弱 buff 缩短强 buff 时长）
func 设置气运buff(修炼加: float, 产出加: float, 天数: int):
	气运修炼加成 = max(气运修炼加成, 修炼加)
	气运产出加成 = max(气运产出加成, 产出加)
	气运到期日 = max(气运到期日, 累计游戏日 + 天数)

func 推演一月(日: int):
	天品突破播报 = ""
	# 全宗气运 buff 到期清除
	if 气运到期日 > 0 and 累计游戏日 >= 气运到期日:
		气运修炼加成 = 0.0
		气运产出加成 = 0.0
		气运到期日 = 0
	var 灵脉buff: float = 1.0 + min(门派等级, 10) * 0.02
	if 累计游戏日 < 气运到期日:
		灵脉buff *= (1.0 + 气运修炼加成)
	# P0-BUILD-2：藏经阁负责人 → 全员修炼速度 +1%（乘入灵脉buff 一起作用于推进修炼）
	# P0-BUILD-2：藏经阁负责人 → 全员修炼速度 +1%（乘入灵脉buff 一起作用于推进修炼）
	# 阶段2：藏经阁常驻再 ×1.05（与负责人叠加，复用同一乘区位置）
	var 修炼buff: float = (1.0 + 汇总负责人全局buff().get("修炼", 0.0)) * _藏经阁修炼乘区()
	# 1. 弟子修炼 / 升层 / 突破 / 月度事件（10层体系双轨播报）
	for d in 弟子列表:
		var 旧境界: String = d.境界
		var 旧层数: int = d.层数
		d.推进修炼(日, 灵脉buff * 修炼buff)
		var 新层数: int = d.层数

		# 突破播报（境界变化 = 大事，高优先级）
		if d.境界 != 旧境界:
			_加推演条目("【%s】道心通明，突破至 %s！" % [d.姓名, d.境界], ET_BREAKTHROUGH, PRIO_HIGH, {"弟子": d.姓名, "境界": d.境界})
			# 天品灵根弟子突破 → 仪式感
			if d.灵根品阶 == "天品":
				宗门纪事.append({"日": 累计游戏日, "弟子": d.姓名, "稀有度": "天品", "名称": "天品突破", "文案": "天品灵根弟子【%s】突破至%s，道行精进，全宗灵机涌动。" % [d.姓名, d.境界]})
				设置气运buff(0.02, 0.01, 3)
				天品突破播报 += "【%s】突破至%s\n" % [d.姓名, d.境界]
			if d.堂口 != "":
				_注册入堂(d)
				if d.职业 != "":
					_加推演条目("【%s】入门%s，任%s。" % [d.姓名, Lore.取堂口(d.堂口)["名称"], d.职业], ET_APPOINT, PRIO_NORMAL, {"弟子": d.姓名, "堂口": d.堂口, "职业": d.职业})
		# 升层播报（仅境界未变时；大圆满或每5层节点，避免刷屏）
		elif 新层数 > 旧层数 and d.境界 == 旧境界:
			if 新层数 >= 10 and 旧层数 < 10:
				_加推演条目("【%s】修为精进至%s·大圆满，可尝试突破。" % [d.姓名, d.境界], ET_BREAKTHROUGH, PRIO_NORMAL, {"弟子": d.姓名, "境界": d.境界})
			elif 新层数 % 5 == 0 or (新层数 >= 7 and 旧层数 < 7):
				_加推演条目("【%s】修为精进，升至%s%d层。" % [d.姓名, d.境界, 新层数], ET_BREAKTHROUGH, PRIO_TRIVIAL, {"弟子": d.姓名})

		var 事件: String = _弟子月度事件(d)
		if 事件 != "":
			# 智能分类：无功而返→trivial / 得稀有道具→high / 其他→normal
			var 优先级 := PRIO_NORMAL
			var 类型 := ET_QUEST
			if "无功而返" in 事件:
				优先级 = PRIO_TRIVIAL
			elif "得【" in 事件 and ("极品" in 事件 or "特殊" in 事件):
				优先级 = PRIO_HIGH
				类型 = ET_LOOT
			elif "大有所获" in 事件:
				类型 = ET_QUEST
			_加推演条目(事件, 类型, 优先级, {"弟子": d.姓名})
	# 2. 资源建筑产出
	_资源建筑产出()
	# 2.5 建筑被动结算（阶段2：每月概率事件；资源产出之后、推演条目汇总之前）
	_建筑被动结算()
	# 3. 宗门事件（约每月一次）
	if randf() < 0.5:
		_加推演条目("【宗门】" + Lore.取宗门事件(), ET_SECT, PRIO_NORMAL)
		_加声望(5)
	# 4. 育英堂常驻自动招收（练气候补）
	if randf() < 0.3:
		var n: int = 1 + (1 if randf() < 0.3 else 0)
		for i in n:
			var nd := Disciple.new()
			nd.堂口 = "yuying"   # 育英堂候补
			弟子列表.append(nd)
	# 5. 御兽堂推进孵化
	推进孵化(日)
	# 6. 更新门派
	更新门派()
	# === S1 扩展端口（当前空操作，S1 赛季实现；见 S1-S2功能储备与扩展端口清单.md）===
	_结算俸禄_S1()            # 俸禄/福利按月发放，扣公库
	_可能触发特殊登门_S1()    # 声望阈值→特殊弟子主动投奔
	累计游戏日 += 日

# === S1 端口：俸禄/福利按月结算（当前空操作桩）===
# 调用位置：推演一月 月循环（紧接 _可能触发特殊登门_S1 之前）。
# 入参：无（读取全局 灵石 / 弟子列表 / 宗门贡献）
# 返回值：void；S1 实装后副作用：公库扣款 + 按身份/阶位发放俸禄 + 欠薪→忠诚↓→叛逃
# 依赖：货币/贡献系统（见 §二 俸禄福利）。状态：空操作，零副作用，八道闸门安全。
func _结算俸禄_S1() -> void:
	pass

# === S1 端口：声望阈值触发特殊弟子主动投奔（当前空操作桩）===
# 调用位置：推演一月 月循环（紧接 _结算俸禄_S1 之后）。
# 入参：无（读取全局 声望 / 弟子列表 / 命格池）
# 返回值：void；S1 实装后：若 声望 >= 阈值 且 randf() 命中，生成带专属命格/特殊灵根的特殊弟子并 append 入 弟子列表 + 写纪事
# 依赖：声望系统、命格池（见 §三 特殊登门事件）。状态：空操作，零副作用。
func _可能触发特殊登门_S1() -> void:
	pass

# 单个弟子月度事件（历练/奇遇，结果按综合实力判定）
func _弟子月度事件(d: Disciple) -> String:
	var 概率 := 0.5
	if d.性格 == "孤僻清修":
		概率 -= 0.2
	if randf() >= 概率:
		return ""
	var 文本: String = "【%s】" % d.姓名 + Lore.取历练(d.境界, d.性格)
	if _判定成败(d):
		文本 += "（大有所获）"
		if randf() < 0.15:
			var it := Item.new()
			d.获得物品(it)        # 入背包 + 自动穿戴（更优则替换，受 品阶≤境界 限制）
			文本 += " 得【%s】" % it.简介()
			if it.极品 or it.特殊:
				待抉择.append({"弟子": d, "物品": it, "文本": 文本})
		if randf() < 0.05:
			var 蛋 := Beast.new()
			灵兽蛋列表.append(蛋)
			文本 += " 寻得灵兽蛋一枚"
	else:
		var 原因池: Array[String] = ["寻宝未获，空手而归", "遭遇迷障，不得不撤", "探寻无果，徒劳往返", "山路崎岖，半途折返"]
		文本 += "（无功而返：%s）" % 原因池[randi() % 原因池.size()]
	# ===== 奇遇分支（Step 1：宗门内场景路由；与历练并列、独立概率）=====
	# 原内联冷却/抽取/分流逻辑抽至 _尝试触发奇遇 复用（资源产出、历练通关共用）。
	var 奇: Dictionary = _尝试触发奇遇(d, "宗门内")
	if not 奇.is_empty():
		文本 += "\n" + 奇.文案
	return 文本

# 奇遇触发概率（ADR-002 D1）：仿 _弟子月度事件 命格/性格修正，独立基础概率。
func 奇遇触发概率(d: Disciple) -> float:
	var p := 0.15   # [PLACEHOLDER] 基础触发概率，待平衡
	if d.性格 == "孤僻清修":
		p -= 0.1
	return clamp(p, 0.0, 1.0)

# 通用奇遇触发（Step 1 三场景全量接入）：在指定 scene 下按概率 + 全局冷却 + 每日上限 + 单条冷却
# 尝试触发一条奇遇；命中后按 需干预/征伐 分流收尾，并 emit 奇遇发生 signal 供 UI 调度（Step 2）。
# 返回触发的奇遇包（未触发返回 {}），供调用方决定是否将 文案 并入推演日志。
func _尝试触发奇遇(d: Disciple, scene: String, 保底: bool = false) -> Dictionary:
	var 结果: Dictionary = {}
	# Sprint-02b：全局冷却（30秒现实时间）；保底模式（历练探索节点）豁免
	var 可出奇遇 := true
	if not 保底 and Time.get_ticks_msec() - _上次奇遇时刻 < 30000:
		可出奇遇 = false
	# 每日上限（按累计游戏日重置）
	if _奇遇日标记 != 累计游戏日:
		_奇遇日标记 = 累计游戏日
		_今日奇遇次数 = 0
	if _今日奇遇次数 >= 5:
		可出奇遇 = false
	if not 可出奇遇 or (not 保底 and randf() >= 奇遇触发概率(d)):
		return 结果
	# 按 scene 路由抽一条（Step 1：scene 非空时仅取匹配 trigger_scene 的事件）
	var q: Dictionary = Quest.抽取(d, scene)
	if q.is_empty() or q.get("event_id", "") == "":
		return 结果
	# Sprint-02b：单条冷却检查（cooldown_hour 转游戏日比较）
	var eid := q.get("event_id", "") as String
	var cd_hour := q.get("cooldown_hour", 0) as int
	if cd_hour > 0 and _单条冷却记录.has(eid):
		var 上次触发日 := _单条冷却记录[eid] as int
		if 累计游戏日 - 上次触发日 < ceil(cd_hour / 24.0):
			return 结果
	_今日奇遇次数 += 1
	_单条冷却记录[eid] = 累计游戏日
	# 声望：稀有及以上品质奇遇（配套规则 +10~20）
	if q.get("稀有度", "普通") != "普通":
		_加声望(randi_range(10, 20))
	# 分流收尾（ADR-002 / ADR-003）
	if q.需干预:
		# 紫+ 进干预队列（UI 灰模由 art-lead 后续出）；兜底期恒不触发
		奇遇待抉择.append({"弟子": d, "奇遇包": q, "选项": Quest.干预选项})
	else:
		if q.get("event_type", "") == "征伐":
			结算征伐奇遇(d, q)
		else:
			结算奇遇奖励(d, q)
	# emit signal 供 main.gd（Step 2）做 L1 气泡 / L2 弹窗 / L3 全屏 调度
	奇遇发生.emit(q, d)
	# 宗门纪事（最简版）：追加本次触发记录
	宗门纪事.append({
		"日": 累计游戏日, "弟子": d.姓名, "稀有度": q.get("稀有度", "普通"),
		"名称": q.get("event_name", "无名奇遇"), "文案": q.get("文案", ""),
	})
	return q

# 奇遇奖励结算（ADR-002 D5）：兜底期 q.奖励==null → 随机小奖励；csv 到位后按奖励结构结算。
# Sprint-02b：记录冷却时刻 + 宗门等级缩放接入
func 结算奇遇奖励(d: Disciple, q: Dictionary):
	_上次奇遇时刻 = Time.get_ticks_msec()
	var 摘要: String = "奇遇·" + str(q.get("稀有度", "普通"))

	# Sprint-02b：宗门等级缩放奖励（当 q 有缩放字段时）
	var base := q.get("base_value", 0.0) as float
	var 灵石奖励 := 0
	if base > 0.0:
		var factor := q.get("level_factor", 0.15) as float
		var min_v := q.get("min_value", 0.0) as float
		var max_v := q.get("max_value", 999.0) as float
		var 缩放值: float = Quest._缩放入参(base, factor, min_v, max_v)
		灵石奖励 = int(round(缩放值))
		if 灵石奖励 > 0:
			灵石 += 灵石奖励
			摘要 += " 灵石+%d（宗门等级缩放）" % 灵石奖励
	else:
		# 兜底随机小奖励 [PLACEHOLDER 数值，待平衡]
		灵石奖励 = randi_range(10, 50)
		灵石 += 灵石奖励
		摘要 += " 灵石+%d" % 灵石奖励
	
	if not (base > 0.0):
		if randf() < 0.3:
			var c: int = randi_range(1, 5)
			贡献点 += c
			摘要 += " 贡献+%d" % c
		if randf() < 0.15:
			var it := Item.new()
			it.奇遇版 = true        # ADR-002 D5：奇遇版标记（增幅曲线待 design 录入，本 Sprint 仅置位）
			d.获得物品(it)          # 入背包 + 自动穿戴（经 ADR-001 自动进战力）
			摘要 += " 得【%s·奇遇版】" % it.名称
	# 道心值：待道心系统；本 Sprint 先记 履历（ADR-002 D5）。
	d.履历.append(摘要)

# ============ 奇遇·征伐类 战斗收尾（ADR-003 D6① / ADR-002 hook）============
# 由 Quest.结算征伐 发起战斗（BattleManager 调用 BattleCalculator 纯逻辑）返回统一 BattleResult；
# 本函数按胜负发放奖励/记 履历，完成「奇遇管理器」收尾（ADR-003 D6：战斗影响 履历/声望）。
func 结算征伐奇遇(d: Disciple, q: Dictionary):
	_上次奇遇时刻 = Time.get_ticks_msec()
	var 战报: Dictionary = Quest.结算征伐(d, q)
	var 摘要: String = "奇遇·征伐·" + str(q.get("event_name", "无名试炼"))
	if 战报["is_win"]:
		摘要 += " 大捷！"
		# 胜利奖励（宗门等级缩放灵石 + 潜在物品，数值待 design 校准）
		var base := q.get("base_value", 30.0) as float
		var 灵石奖励 := 0
		if base > 0.0:
			var factor := q.get("level_factor", 0.15) as float
			var min_v := q.get("min_value", 10.0) as float
			var max_v := q.get("max_value", 999.0) as float
			灵石奖励 = int(round(Quest._缩放入参(base, factor, min_v, max_v)))
			if 灵石奖励 > 0:
				灵石 += 灵石奖励
				摘要 += " 灵石+%d" % 灵石奖励
		else:
			灵石奖励 = randi_range(20, 60)
			灵石 += 灵石奖励
			摘要 += " 灵石+%d" % 灵石奖励
		if randf() < 0.2:
			var it := Item.new()
			it.奇遇版 = true
			d.获得物品(it)
			摘要 += " 得【%s·奇遇版】" % it.名称
	else:
		var 失败原因: Array[String] = ["不敌对手，险象环生后撤退", "陷入苦战，消耗过大无功而返", "情报有误，扑了个空", "天时不利，草草收兵"]
		摘要 += " 失利（%s）" % 失败原因[randi() % 失败原因.size()]
	d.履历.append(摘要)
	# 征伐奇遇也写宗门纪事（_尝试触发奇遇的L227可能被冷却/概率拦住）
	宗门纪事.append({
		"日": 累计游戏日, "弟子": d.姓名,
		"稀有度": q.get("稀有度", "普通"), "名称": "征伐·%s" % q.get("event_name", "无名"),
		"文案": "%s（回合%d）" % ["大捷" if 战报["is_win"] else "失利", 战报.get("round_count", 0)],
	})

# ============ 历练关卡对接接口（ADR-003 D6 / Sprint-03 T3，stub）============
# 关卡ID → 怪物列表(CombatantData 快照) → BattleManager 结算通路。
# P0 仅预留接口与数据契约；关卡配置表 config/level.csv 待 design 录入（S1 接敌表）。
# 出战/怪物快照由调用方组装（如来自 disciple.get_final_combat_attr()）；
# 本函数负责通路编排，返回统一 BattleResult（无数据时返回 stub 标记占位）。
# ============ 历练关卡：数据驱动挑战接口（Day 2 取代原 stub）============
# 主入口：挑战关卡(stage_id, 出战弟子列表) → 解锁校验 → 体力 → 组怪 → 结算 → 奖励/首通/解锁
# 返回扩展 BattleResult：{is_win, round_count, remaining_hp, drop_reward, battle_log, 奖励摘要, stub, 关卡ID, error}
func 挑战关卡(stage_id: String, 出战弟子: Array = [], mode: String = "full") -> Dictionary:
	var 结果: Dictionary = {"is_win": false, "round_count": 0, "remaining_hp": 0, "drop_reward": [],
		"battle_log": [], "奖励摘要": "", "stub": false, "关卡ID": stage_id, "error": ""}
	var stage: Dictionary = StageDataLoader.get_stage(stage_id)
	if stage.is_empty():
		结果["error"] = "关卡不存在: %s" % stage_id
		return 结果
	if not StageDataLoader.is_unlocked(stage_id, 门派等级, 已通关关卡):
		结果["error"] = "关卡未解锁"
		return 结果
	if 出战弟子.is_empty():
		结果["error"] = "未选择出战弟子"
		return 结果
	var 节点类型: String = stage.get("node_type", "normal")
	# 体力校验
	var 耗时: int = int(stage.get("stamina_cost", 0))
	if 体力 < 耗时:
		结果["error"] = "体力不足（需%d，余%d）" % [耗时, 体力]
		return 结果
	# 精英每日次数校验
	if 节点类型 == "elite":
		var 今日: String = "%d" % 累计游戏日
		if not 精英每日次数.has(今日):
			精英每日次数[今日] = {}
		var 上限: int = int(stage.get("daily_limit", 0))
		if 上限 > 0 and 精英每日次数[今日].get(stage_id, 0) >= 上限:
			结果["error"] = "今日精英挑战次数已用完"
			return 结果
	# 扣体力
	体力 = clamp(体力 - 耗时, 0, 体力上限())
	# 组装敌方（CSV 驱动）
	var 怪物: Array = StageDataLoader.build_monster_units(stage_id)
	if 怪物.is_empty():
		体力 = clamp(体力 + 耗时, 0, 体力上限())   # 回退
		结果["error"] = "关卡无怪物配置"
		return 结果
	# 组装我方快照（弟子 → 战斗属性聚合，唯一入口 get_final_combat_attr）
	var 我方: Array = []
	for d in 出战弟子:
		if d is Disciple:
			我方.append(d.get_final_combat_attr())
	if 我方.is_empty():
		体力 = clamp(体力 + 耗时, 0, 体力上限())
		结果["error"] = "出战弟子属性无效"
		return 结果
	# 结算（车轮战编排，纯逻辑）
	var 战报: Dictionary
	if 我方.size() == 1 and 怪物.size() == 1:
		战报 = BattleManager.发起1v1(我方[0], 怪物[0], mode, false)
	else:
		战报 = BattleManager.发起3v3(我方, 怪物, mode, false)
	结果["is_win"] = 战报.get("is_win", false)
	结果["round_count"] = 战报.get("round_count", 0)
	结果["remaining_hp"] = 战报.get("remaining_hp", 0)
	结果["battle_log"] = 战报.get("battle_log", [])
	# 胜后处理：首通 / 精英次数 / 掉落 / 历练奇遇
	if 结果["is_win"]:
		# 阶段2：御兽峰被动——历练胜利时 10% 触发「灵兽相助」，本次历练收益 +10%（独立 roll，不触碰核心战斗数值红线）
		var 御兽相助: bool = 堂口列表.has("yushou") and randf() < 0.10
		var 首通: bool = not 已通关关卡.has(stage_id)
		if 首通:
			已通关关卡[stage_id] = true
			var 首通类型: String = stage.get("first_reward_type", "")
			var 首通数: int = int(stage.get("first_reward_num", 0))
			if 首通类型 == "res" and 首通数 > 0:
				var 实得: int = int(round(首通数 * (1.10 if 御兽相助 else 1.0)))
				灵石 += 实得
				结果["奖励摘要"] += " 首通灵石+%d" % 实得
			# 声望里程碑（配套规则）：普通首通+5 / 精英首通+15
			if 节点类型 == "elite":
				_加声望(15)
				结果["奖励摘要"] += " 声望+15"
			else:
				_加声望(5)
				结果["奖励摘要"] += " 声望+5"
			if 节点类型 == "elite":
				var 今日: String = "%d" % 累计游戏日
				if not 精英每日次数.has(今日):
					精英每日次数[今日] = {}
				精英每日次数[今日][stage_id] = 精英每日次数[今日].get(stage_id, 0) + 1
			# 重复掉落
			var drops: Array = StageDataLoader.roll_drop(stage_id)
			结果["drop_reward"] = drops
			for drop in drops:
				var it: Item = _掉落转物品(drop)
				it.名称 = drop.get("item_name", "掉落物")
				_应用掉落品质(it, drop.get("quality", ""))
				var 得主: Disciple = 出战弟子[0] if (出战弟子.size() > 0 and 出战弟子[0] is Disciple) else null
				if 得主 != null:
					var 额外件数: int = 0
					if 御兽相助:
						额外件数 = max(1, int(round(drop.get("count", 1) * 0.10)))
						for _k in 额外件数:
							var 额外: Item = _掉落转物品(drop)
							额外.名称 = drop.get("item_name", "掉落物")
							_应用掉落品质(额外, drop.get("quality", ""))
							得主.获得物品(额外)
					得主.获得物品(it)
					结果["奖励摘要"] += " 得【%s×%d】" % [drop.get("item_name", ""), drop.get("count", 1) + 额外件数]
			# 阶段2：御兽峰「灵兽相助」文案（收益+10% 已结算，不触碰核心战斗数值）
			if 御兽相助:
				结果["奖励摘要"] += "（灵兽相助·收益+10%）"
			# 历练通关（战斗胜利场景）奇遇触发，用首名出战弟子承载
			var 承载: Disciple = 出战弟子[0] if (出战弟子.size() > 0 and 出战弟子[0] is Disciple) else null
			if 承载 != null:
				_尝试触发奇遇(承载, "战斗胜利")
	# 弟子履历
	for d in 出战弟子:
		if d is Disciple:
			d.履历.append("历练·%s：%s%s" % [stage.get("stage_name", stage_id),
				"胜" if 结果["is_win"] else "败", 结果["奖励摘要"]])
	弟子变动.emit()
	return 结果
func 历练结算(关卡ID: String, 出战: Array = [], 怪物列表: Array = [], mode: String = "full") -> Dictionary:
	return 挑战关卡(关卡ID, 出战, mode)

# 掉落品质映射：drop_pool.csv 用「凡品/良品/上品/极品」4 档，item.gd 实例品阶为 7 档中文显示名
func _应用掉落品质(it: Item, quality: String):
	var 映射: Dictionary = {"凡品": "凡阶", "良品": "灵阶", "上品": "宝阶", "极品": "王阶"}
	it.品阶 = 映射.get(quality, "凡阶")

# 掉落表行 → Item；修复「碎片误带穿戴位」bug（§碎片为材料，不可穿戴）
# 根因：Item.new() 随机生成类别/穿戴位，掉落仅覆写 名称+品阶，碎片偶发 roll 到 fa_qi 即带装备槽被穿上。
func _掉落转物品(drop: Dictionary) -> Item:
	var it: Item = Item.new()
	it.名称 = drop.get("item_name", "掉落物")
	_应用掉落品质(it, drop.get("quality", ""))
	if "碎片" in it.名称:
		it.穿戴位 = ""        # 清空→可穿戴()=false，自动/手动/一键最优三路均封死
		it.类别 = "ling_cai"  # 归为灵材，内部一致
	return it

# 体力上限：初始 50，门派每升 1 级 +5
func 体力上限() -> int:
	return 50 + (门派等级 - 1) * 5

# 综合能力判定（资质/修为/装备/属性/性格/命格）
func _判定成败(d: Disciple) -> bool:
	var 分: float = d.修炼速度 * 0.3 + (d.总战力() / 1000.0) * 0.3
	分 += d.属性["攻"] * 0.001 + d.属性["速"] * 0.001
	# 奇遇型命格首发不生效（S1 接入）；此处不再按命格名硬编码加成
	if d.性格 == "谨慎多疑" or d.性格 == "贪心逐缘":
		分 += 0.1
	return randf() < clamp(分, 0.1, 0.95)

# 资源建筑产出（原「堂口产出」；首发文案统一称资源建筑，底层堂口数据保留）
func _资源建筑产出():
	# 阶段2：清零本月各资源建筑产出额记录（供建筑被动概率翻倍时直接加回）
	_本月灵田产出 = 0
	_本月矿脉产出 = 0
	_本月丹堂产出 = 0
	_本月器堂产出 = 0
	var 经营基数: Dictionary = {"lingtian": 5, "kuangmai": 4, "dantang": 3, "qitang": 3, "cangjing": 2, "zhifa": 2, "gongxun": 2, "tanwei": 2, "yuying": 1, "yushou": 1, "zhenfa": 1, "xichi": 1}
	# P0-BUILD-2：灵田负责人 → 全建筑灵石产出 +1%
	var 产出buff: float = 汇总负责人全局buff().get("产出", 0.0)
	for key in 堂口列表.keys():
		var 堂: Dictionary = 堂口列表[key]
		var 成员 := 堂["成员"] as Array
		var n: int = 成员.size()
		if n == 0:
			continue
		# 经营型命格：弟子驻守建筑时生效，乘性加成产出
		var 经营加成: float = 0.0
		for m in 成员:
			var 弟子 := m as Disciple
			var 命格数据: Dictionary = DestinyDataLoader.get_destiny(弟子.destiny_id)
			if 命格数据.get("类型", "") == "经营" and 命格数据.get("维度", "") == "产出":
				经营加成 += float(命格数据.get("数值", 0)) / 100.0
		var base: int = 经营基数.get(key, 1)
		var 气运乘: float = (1.0 + 气运产出加成) if (累计游戏日 < 气运到期日) else 1.0
		# P0-BUILD-4：宗门等级 → 建筑产出乘区（1级无加成，10级 +18%，数值克制）
		var 等级乘区: float = 1.0 + 0.02 * max(0, 门派等级 - 1)
		var 产: int = int(n * base * (1.0 + 经营加成) * 气运乘 * (1.0 + 产出buff) * 等级乘区)
		灵石 += 产
		# 阶段2：记录各资源建筑本月实际产出额，供 _建筑被动结算 概率翻倍（灵草丰收/富矿/额外丹元/器魂）时直接加回
		match key:
			"lingtian": _本月灵田产出 = 产
			"kuangmai": _本月矿脉产出 = 产
			"dantang":  _本月丹堂产出 = 产
			"qitang":   _本月器堂产出 = 产
	灵石 += 弟子列表.size() * 2
	# Step 1 三场景接入：资源产出为「宗门内」奇遇触发点之一（与弟子修炼共用宗门内池，
	# 受全局冷却约束，单次推演至多触发一条）。
	for d in 弟子列表:
		_尝试触发奇遇(d, "宗门内")

# ============ 建筑产出预览（P0-BUILD-4：纯计算，不实际发资源）============
# 供建筑总览 UI 顶部「预计月产出」与单建筑卡片预览使用；与 _资源建筑产出 计算逻辑一致，
# 额外乘入「宗门等级乘区」(1.0 + 0.02 * max(0, 门派等级 - 1))。不修改任何状态。
func 预估建筑产出(key: String) -> int:
	if not 堂口列表.has(key):
		return 0
	var 堂: Dictionary = 堂口列表[key]
	var 成员: Array = 堂["成员"]
	var n: int = 成员.size()
	if n == 0:
		return 0
	# 经营基数 与 _资源建筑产出 保持一致（占位建筑统一口径）
	var 经营基数: Dictionary = {"lingtian": 5, "kuangmai": 4, "dantang": 3, "qitang": 3, "cangjing": 2, "zhifa": 2, "gongxun": 2, "tanwei": 2, "yuying": 1, "yushou": 1, "zhenfa": 1, "xichi": 1}
	var 产出buff: float = 汇总负责人全局buff().get("产出", 0.0)
	var 等级乘区: float = 1.0 + 0.02 * max(0, 门派等级 - 1)
	var 气运乘: float = (1.0 + 气运产出加成) if (累计游戏日 < 气运到期日) else 1.0
	var 经营加成: float = 0.0
	for m in 成员:
		var 弟子: Disciple = m as Disciple
		var 命格数据: Dictionary = DestinyDataLoader.get_destiny(弟子.destiny_id)
		if 命格数据.get("类型", "") == "经营" and 命格数据.get("维度", "") == "产出":
			经营加成 += float(命格数据.get("数值", 0)) / 100.0
	var base: int = 经营基数.get(key, 1)
	return int(n * base * (1.0 + 经营加成) * 气运乘 * (1.0 + 产出buff) * 等级乘区)

func 预估月产出() -> int:
	var 总: int = 0
	for key in 堂口列表.keys():
		总 += 预估建筑产出(key)
	总 += 弟子列表.size() * 2
	return 总

# ============ 建筑被动结算（阶段2：占位建筑被动功能）============
# 在 推演一月「资源产出之后、推演条目汇总之前」调用。
# 各建筑独立 roll，互不影响；绝不污染奇遇池（不使用 奇遇发生 signal / event_quest / quest.gd）。
# 资源翻倍类（灵田/矿脉/丹堂/器堂）的翻倍额已在 _资源建筑产出 记录于 _本月XX产出，
#   此处直接加回（避免重复计算 经营/气运/产出 乘区），命中即写推演条目。
func _建筑被动结算():
	# [DORMANT] 聚合负面事件减免（暂存，当前无负面/入侵事件系统消费；未来接入即可生效）
	建筑被动_负面事件减免 = _负面事件减免()

	# 灵田 8%：灵草丰收，当月灵石产出翻倍
	if _本月灵田产出 > 0 and randf() < 0.08:
		灵石 += _本月灵田产出
		_加推演条目("【灵田】灵草大丰收，灵石产出翻倍！", ET_RESOURCE, PRIO_NORMAL, {"建筑": "lingtian"})
	# 矿脉 7%：富矿现世，当月灵石产出翻倍
	if _本月矿脉产出 > 0 and randf() < 0.07:
		灵石 += _本月矿脉产出
		_加推演条目("【矿脉】富矿现世，灵石产出翻倍！", ET_RESOURCE, PRIO_NORMAL, {"建筑": "kuangmai"})

	# 丹堂 15%：额外丹元（灵石翻倍计入）+ 子概率 30% 生成随机低阶丹药入弟子储物袋
	if _本月丹堂产出 > 0 and randf() < 0.15:
		灵石 += _本月丹堂产出
		_加推演条目("【丹堂】丹火纯青，额外丹元折算灵石。", ET_RESOURCE, PRIO_NORMAL, {"建筑": "dantang"})
		if not 弟子列表.is_empty() and randf() < 0.30:
			var 得主: Disciple = 弟子列表[randi() % 弟子列表.size()]
			var 丹: Item = _造低阶物品("dan_yao", "凡阶")
			得主.背包.append(丹)
			宗门纪事.append({"日": 累计游戏日, "弟子": 得主.姓名, "稀有度": "建筑被动", "名称": "丹堂赠丹", "文案": "丹堂额外炼制一枚【%s】，赐予【%s】。" % [丹.名称, 得主.姓名]})
			_加推演条目("【丹堂】额外炼出一枚【%s】，赐予弟子。" % 丹.名称, ET_LOOT, PRIO_NORMAL, {"建筑": "dantang"})

	# 器堂 12%：额外器魂（灵石翻倍计入）+ 掉 1 件随机低阶法宝入弟子储物袋
	if _本月器堂产出 > 0 and randf() < 0.12:
		灵石 += _本月器堂产出
		_加推演条目("【器堂】巧匠精进，额外器魂折算灵石。", ET_RESOURCE, PRIO_NORMAL, {"建筑": "qitang"})
		if not 弟子列表.is_empty():
			var 得主: Disciple = 弟子列表[randi() % 弟子列表.size()]
			var 器: Item = _造低阶物品("fabao", "凡阶")
			得主.背包.append(器)
			宗门纪事.append({"日": 累计游戏日, "弟子": 得主.姓名, "稀有度": "建筑被动", "名称": "器堂赠宝", "文案": "器堂额外锻造一件【%s】，赐予【%s】。" % [器.名称, 得主.姓名]})
			_加推演条目("【器堂】额外锻造一件【%s】，赐予弟子。" % 器.名称, ET_LOOT, PRIO_NORMAL, {"建筑": "qitang"})

	# 藏经阁 8%：悟道机缘，随机 1 名弟子小幅修为/境界进度加成
	if 堂口列表.has("cangjing") and not 弟子列表.is_empty() and randf() < 0.08:
		var 悟道者: Disciple = 弟子列表[randi() % 弟子列表.size()]
		悟道者.推进修炼(3, 1.05)   # 小量天数 + 轻微加成
		_加推演条目("【藏经阁】悟道机缘，【%s】修为精进。" % 悟道者.姓名, ET_SECT, PRIO_NORMAL, {"建筑": "cangjing"})

	# 探微阁 10%：情报奇遇，额外灵石 + 推演条目
	if 堂口列表.has("tanwei") and randf() < 0.10:
		灵石 += randi_range(30, 80)
		_加推演条目("【探微阁】探得秘境线索，宗门得益。（额外灵石）", ET_INFO, PRIO_NORMAL, {"建筑": "tanwei"})

	# 接引堂 5%：慕名来投，额外生成 1 名随机弟子加入宗门（复用现有随机弟子创建）
	if 堂口列表.has("yuying") and randf() < 0.05:
		var 新徒: Disciple = Disciple.new()
		新徒.堂口 = "yuying"
		弟子列表.append(新徒)
		弟子变动.emit()
		_加推演条目("【接引堂】有散修慕名来投，拜入宗门。", ET_APPOINT, PRIO_NORMAL, {"建筑": "yuying"})

	# 洗髓池 1%：洗髓机缘（随机 1 名弟子 提升命格品质 OR 清除负面性格，二选一随机）
	if 堂口列表.has("xichi") and not 弟子列表.is_empty() and randf() < 0.01:
		_洗髓机缘()

# 造一枚指定类别/品阶的物品（建筑被动掉落用；仅填模板+算战力，不污染战斗数值红线）
func _造低阶物品(类别: String, 品阶: String) -> Item:
	var it: Item = Item.new()
	it.类别 = 类别
	it.品阶 = 品阶
	it.穿戴位 = ""
	it.职业 = ""
	if 类别 == "dan_yao" and it.基础库.has("dan_yao") and it.基础库["dan_yao"].has(品阶):
		it._填模板(it.基础库["dan_yao"][品阶][0])
	elif 类别 == "fabao" and it.基础库.has("fabao") and it.基础库["fabao"].has(品阶):
		it.穿戴位 = "本命法宝"
		it._填模板(it.基础库["fabao"][品阶][0])
	it.滚词缀()
	it.滚极品()
	it.算战力()
	return it

# 洗髓池机缘：随机 1 名弟子 提升命格品质 OR 清除负面性格（二选一随机）
func _洗髓机缘():
	var d: Disciple = 弟子列表[randi() % 弟子列表.size()]
	var 当前品级: String = DestinyDataLoader.get_destiny(d.destiny_id).get("品级", "凡品")
	var 序: Array = DestinyDataLoader.品级枚举
	var idx: int = 序.find(当前品级)
	var 高品级池: Array = []
	if idx >= 0 and idx + 1 < 序.size():
		var 高档: String = 序[idx + 1]
		高品级池 = DestinyDataLoader.ids_by_grade().get(高档, [])
	var 做了: bool = false
	if not 高品级池.is_empty() and randf() < 0.5:
		var 高档名: String = 序[idx + 1]
		d.destiny_id = 高品级池[randi() % 高品级池.size()]
		d._应用命格养成加成()
		宗门纪事.append({"日": 累计游戏日, "弟子": d.姓名, "稀有度": "建筑被动", "名称": "命格重塑", "文案": "洗髓池机缘，【%s】命格品质提升（%s→%s）。" % [d.姓名, 当前品级, 高档名]})
		_加推演条目("【洗髓池】天道垂青，【%s】命格品质提升。" % d.姓名, ET_SECT, PRIO_NORMAL, {"建筑": "xichi"})
		做了 = true
	else:
		var 负面: Array = ["孤僻清修", "狂傲绝世"]
		if d.性格 in 负面:
			var 中性: Array = ["沉稳守道", "恬淡悟道", "仁心济世", "守礼尊师"]
			var 新性格: String = 中性[randi() % 中性.size()]
			宗门纪事.append({"日": 累计游戏日, "弟子": d.姓名, "稀有度": "建筑被动", "名称": "性格洗练", "文案": "洗髓池机缘，【%s】洗去「%s」心障，转「%s」。" % [d.姓名, d.性格, 新性格]})
			d.性格 = 新性格
			_加推演条目("【洗髓池】天道垂青，【%s】洗去心障，心性转善。" % d.姓名, ET_SECT, PRIO_NORMAL, {"建筑": "xichi"})
			做了 = true
		elif not 高品级池.is_empty():
			var 高档名: String = 序[idx + 1]
			d.destiny_id = 高品级池[randi() % 高品级池.size()]
			d._应用命格养成加成()
			宗门纪事.append({"日": 累计游戏日, "弟子": d.姓名, "稀有度": "建筑被动", "名称": "命格重塑", "文案": "洗髓池机缘，【%s】命格品质提升（%s→%s）。" % [d.姓名, 当前品级, 高档名]})
			_加推演条目("【洗髓池】天道垂青，【%s】命格品质提升。" % d.姓名, ET_SECT, PRIO_NORMAL, {"建筑": "xichi"})
			做了 = true
	# 注：若弟子已为投放最高品级(极品，天品未投放)且性格非负面，则本次机缘无实质收益（极罕见，不写条目）

# ============ 堂口系统 ============
func 重建堂口():
	堂口列表 = {}
	for key in Lore.堂口定义.keys():
		var def: Dictionary = Lore.堂口定义[key]
		堂口列表[key] = {
			"key": key, "名称": def["名称"], "职能": def["职能"],
			"产出": def["产出"], "加成维度": def["加成维度"],
		"负责人": null, "成员": [], "负责人锁定": false,
		# === S1 端口：建筑等级/任期政绩字段（当前恒为默认，S1 接入升级/政绩累计）===
		# 字段："等级":1（建筑等级，S1 升级后>1，乘区桩 _建筑等级_乘区 随之生效） | "政绩":0（主事任期政绩累积，dormant）
		# 重建语义：重建自 Lore，不持久化（每次启动重算；S1 须改为持久化或独立存档）
		# 依赖：建筑等级体系（§一）+ 负责人锁定机制（§一 任期政绩）
		"等级": 1, "政绩": 0,
	}
	for d in 弟子列表:
		if d.堂口 != "":
			_注册入堂(d)
	应用负责人存档()

func _在堂口(key: String, d: Disciple) -> bool:
	var 成员 := 堂口列表[key]["成员"] as Array
	for m in 成员:
		if (m as Disciple) == d:
			return true
	return false

func _注册入堂(d: Disciple):
	if d.堂口 == "" or not 堂口列表.has(d.堂口):
		return
	if _在堂口(d.堂口, d):
		return
	(堂口列表[d.堂口]["成员"] as Array).append(d)
	# 负责人按加成高者优先自动任命：为空取最高分；新成员更高则替换（含掌门手定后被超越的情况）
	# P0-BUILD-2：已锁定的岗位不参与自动顶替（手动任命/解除见 任命负责人 / 解除负责人锁定）
	var 维度: String = 堂口列表[d.堂口]["加成维度"]
	var 现负责: Disciple = 堂口列表[d.堂口]["负责人"]
	var 现分 := -1.0
	if 现负责 != null:
		现分 = 现负责.加成评分(维度)
	var 已锁定: bool = 堂口列表[d.堂口].get("负责人锁定", false)
	if not 已锁定 and (现负责 == null or d.加成评分(维度) > 现分):
		var 旧负责 := 现负责
		_设负责人(d.堂口, d)
		if 旧负责 != null:
			宗门纪事.append({"日": 累计游戏日, "弟子": 旧负责.姓名, "稀有度": "宗门", "名称": "人事变动", "文案": "【人事】%s主事由 %s 接替 %s" % [堂口列表[d.堂口]["名称"], d.姓名, 旧负责.姓名]})

func _设负责人(key: String, d: Disciple):
	堂口列表[key]["负责人"] = d
	堂口负责人存档[key] = d.姓名

# 掌门任命负责人（UI 调用）
func 任命负责人(key: String, d: Disciple):
	if not 堂口列表.has(key):
		return
	_设负责人(key, d)
	堂口列表[key]["负责人锁定"] = true
	宗门纪事.append({"日": 累计游戏日, "弟子": d.姓名, "稀有度": "宗门", "名称": "人事任命", "文案": "【人事】%s 被任命为%s主事" % [d.姓名, 堂口列表[key]["名称"]]})
	_加推演条目("【人事】%s 任%s主事。" % [d.姓名, 堂口列表[key]["名称"]], ET_APPOINT, PRIO_NORMAL, {"弟子": d.姓名, "堂口": key})
	弟子变动.emit()

func 应用负责人存档():
	for key in 堂口负责人存档.keys():
		var 名: String = 堂口负责人存档[key]
		var d: Disciple = _按姓名找(名)
		if d != null and 堂口列表.has(key):
			堂口列表[key]["负责人"] = d

# P0-BUILD-2：汇总所有「有负责人的建筑」的全局微量 buff（每座 +1%，按 加成维度→全局buff 映射累加）。
# 返回字典（数值为小数，表示百分比）：攻/防/血/速/修炼/产出/测灵。
# 无负责人 → 全 0 → 各应用点乘区 = 1.0，不改变任何数值（保证 test_combat 等数值红线不被触碰）。
func 汇总负责人全局buff() -> Dictionary:
	var buff: Dictionary = {"攻": 0.0, "防": 0.0, "血": 0.0, "速": 0.0, "修炼": 0.0, "产出": 0.0, "测灵": 0.0}
	# 建筑 key → 全局 buff 维度 映射（功勋阁/御兽峰/洗髓池 本项无负责人 buff，属阶段2）
	var 映射: Dictionary = {
		"qitang": "攻", "kuangmai": "防", "zhenfa": "防",
		"dantang": "血", "zhifa": "速", "tanwei": "速",
		"cangjing": "修炼", "lingtian": "产出", "yuying": "测灵",
	}
	for key in 堂口列表.keys():
		var 堂: Dictionary = 堂口列表[key]
		var 负责: Variant = 堂.get("负责人", null)
		if 负责 == null:
			continue
		var 维: String = 映射.get(key, "")
		if 维 != "":
			buff[维] = float(buff.get(维, 0.0)) + 0.01
	# 阶段2：阵法阁常驻防御 +1%（与「负责人1%」叠加，阵法阁防御贡献 = 负责人1% + 常驻1% = 最多2%）
	if 堂口列表.has("zhenfa"):
		buff["防"] = float(buff.get("防", 0.0)) + 0.01
	return buff

# P0-BUILD-2：解除负责人锁定（供阶段3 UI 调用；本次不接 UI）。runtime-only，不写入存档。
func 解除负责人锁定(key: String):
	if not 堂口列表.has(key):
		return
	堂口列表[key]["负责人锁定"] = false
	宗门纪事.append({"日": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "人事解锁", "文案": "【人事】解除%s主事锁定" % 堂口列表[key]["名称"]})

func _按姓名找(名: String) -> Disciple:
	for d in 弟子列表:
		if d.姓名 == 名:
			return d
	return null

# ============ 测灵根招收仪式 ============
const 测灵根冷却日 := 365   # 1年一度（对应现实世界1天）

# P0-BUILD-2：测灵高品质 buff 触发时，将弟子灵根品阶提升一档（同步灵根类型以维持一致性）
func _提升灵根品阶一档(d: Disciple):
	var 阶序: Array = ["凡品", "良品", "上品", "极品", "天品"]
	var i: int = 阶序.find(d.灵根品阶)
	if i < 0 or i >= 阶序.size() - 1:
		return
	var 新阶: String = 阶序[i + 1]
	d.灵根品阶 = 新阶
	match 新阶:
		"极品":
			if d.灵根 != "天灵根" and d.灵根 != "先天五行全灵根":
				d.灵根 = 灵根变异.pick_random()
		"天品":
			d.灵根 = "天灵根"
		_:
			if d.灵根 in 灵根变异 or d.灵根 == "天灵根" or d.灵根 == "先天五行全灵根":
				d.灵根 = 灵根五行.pick_random()
	d.算属性()
	d._应用命格养成加成()

func 举办测灵根(强制天品: bool = false) -> Dictionary:
	# 冷却检查
	var 距上次: int = 累计游戏日 - 上次测灵日
	if 上次测灵日 > 0 and 距上次 < 测灵根冷却日:
		var 剩余: int = 测灵根冷却日 - 距上次
		return {"人数": 0, "过场": "", "新徒": [], "冷却剩余": 剩余}
	# 正式举办
	Disciple.解锁职业池 = 已解锁职业()
	var N: int = 5 + int(门派等级 / 2) + int(声望 / 500)
	N = clamp(N, 5, 20)
	var 新徒: Array[Disciple] = []
	var 已强制天品: bool = false
	# P0-BUILD-2：外门接引堂负责人 → 测灵高品质概率 +1%；阶段2：接引堂常驻再 +2%（最多+3%）
	var 测灵buff: float = 汇总负责人全局buff().get("测灵", 0.0) + _接引堂测灵加()
	for i in N:
		var d := Disciple.new()
		d.堂口 = "yuying"   # 外门接引堂候补，筑基后转入职能堂
		d.来源 = Disciple.弟子来源池.pick_random()   # 接引来源标签（纯展示）
		# 调试：强制天品（保证批次含1名天品弟子，便于验证破格流程）
		if 强制天品 and not 已强制天品:
			d.灵根 = "天灵根"; d.灵根品阶 = "天品"; d.身份 = "核心弟子"
			已强制天品 = true
		# 身份破格：天品→核心弟子 / 极品→内门弟子（仅标记，不改堂口流水线）
		elif d.灵根品阶 == "天品":
			d.身份 = "核心弟子"
		elif d.灵根品阶 == "极品":
			d.身份 = "内门弟子"
		# P0-BUILD-2：外门接引堂负责人 → 测灵高品质概率 +1%（触发时灵根品阶升一档，已为天品则跳过）
		if 测灵buff > 0.0 and d.灵根品阶 != "天品" and randf() < 测灵buff:
			_提升灵根品阶一档(d)
		弟子列表.append(d)
		新徒.append(d)
	# === S1 端口：新弟子制式装备/入职包发放 ===
	# 调用位置：举办测灵根() 弟子创建循环末尾（d 已 append 入 弟子列表/新徒 之后）。
	# 入参（S1 实装时）：d: Disciple（新弟子）
	# 副作用（S1 实装后）：d.背包.append(制式法宝一套 + 基础修炼功法 + 初级制式储物袋)，可按 身份/阶位 分档配发
	# 依赖：最轻量，可独立于建筑/资源体系先行（见 §二 新弟子入职包）。状态：仅注释标记，未调用任何函数。
	_加声望(N)
	上次测灵日 = 累计游戏日   # 更新冷却时间戳
	# 天品灵根弟子 → 破格：写宗门纪事 + 触发全宗气运 buff（7日 修炼+3%/产出+2%）
	for d in 新徒:
		if d.灵根品阶 == "天品":
			宗门纪事.append({"日": 累计游戏日, "弟子": d.姓名, "稀有度": "天品", "名称": "天品灵根弟子", "文案": "接引大典检出天品灵根弟子【%s】，全宗士气大振。" % d.姓名})
			设置气运buff(0.03, 0.02, 7)
			break
	_注册全部()
	var 有天品: bool = false
	for d in 新徒:
		if d.灵根品阶 == "天品":
			有天品 = true
			break
	var 过场: String = Lore.取测灵根过场(N, 新徒, 有天品)
	弟子变动.emit()
	return {"人数": N, "过场": 过场, "新徒": 新徒}

func _注册全部():
	for d in 弟子列表:
		if d.堂口 != "":
			_注册入堂(d)

# ============ 门派等级 / 声望 / 繁荣 ============
const 门派等级上限: int = 10   # P0 锁 10 级（S1 赛季接入建筑等级体系后可上调）
func 更新门派():
	var 总战力 := 0
	for d in 弟子列表:
		总战力 += d.总战力()
	# P0 等效公式（复用现有字段，零新增底层）：弟子基础 > 战力核心 > 关卡进度 > 声望补充
	var 新等级: int = 1 + int(弟子列表.size() / 12) + int(总战力 / 20000) + int(已通关关卡.size() / 10) + int(声望 / 500)
	新等级 = clamp(新等级, 1, 门派等级上限)
	if 新等级 > 门派等级:
		# 升级仪式：永久写入宗门纪事 + 推演高优播报（不强制弹窗，不打断推演）
		宗门纪事.append({"日": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "宗门晋升",
			"文案": "太玄宗历经沉淀，宗门品级晋升至 Lv.%d，灵脉愈发醇厚，全宗上下欢欣。" % 新等级})
		_加推演条目("【宗门】太玄宗晋升至 Lv.%d！灵脉修炼速度 +%d%%" % [新等级, 新等级 * 2], ET_SECT, PRIO_HIGH, {"宗门等级": 新等级})
	门派等级 = 新等级
	繁荣 = 50 + 弟子列表.size() * 2 + int(灵石 / 100)

# 距下一级信息（主界面展示用）：基于已存储门派等级，计算单靠声望补齐时的缺口
func 距下一级信息() -> Dictionary:
	var 总战力 := 0
	for d in 弟子列表:
		总战力 += d.总战力()
	var s: float = 弟子列表.size() / 12.0 + 总战力 / 20000.0 + 已通关关卡.size() / 10.0 + float(声望) / 500.0
	var 等级 := 门派等级
	var 已满: bool = 等级 >= 门派等级上限
	var 缺口 := 0
	if not 已满:
		var 差: float = float(等级) - s   # 升到下一级需 raw 分数 >= 当前等级
		if 差 > 0:
			缺口 = int(ceil(差 * 500.0))
	return {"等级": 等级, "下一级": 等级 + 1, "声望缺口": max(缺口, 0), "已满": 已满}

func 已解锁职业() -> Array:
	var 候选: Array = ["道修", "体修", "法修"]
	if 门派等级 >= 3:
		候选.append("御兽师")
	if 门派等级 >= 4:
		候选.append("符箓师")
	if 门派等级 >= 5:
		候选.append("毒师")
	if 门派等级 >= 6:
		候选.append("傀儡师")
	return 候选

# ============ 推演日志辅助 ============
# 统一入口：所有推演事件必须通过此函数写入，自动打标
func _加推演条目(text: String, event_type: String, priority: String, data: Dictionary = {}) -> void:
	推演日志.append({
		"event_type": event_type,
		"priority": priority,
		"text": text,
		"data": data,
	})

# 从品阶字符串判断是否为稀有（上品及以上=稀有）
static func _是稀有品阶(品阶: String) -> bool:
	return 品阶 in ["宝阶", "王阶", "圣阶", "仙阶", "道阶"]

# ============ 时间文本 ============
func 时间文本() -> String:
	var d := 累计游戏日
	var 年: int = d / 360
	var 月: int = int((d % 360) / 30)
	var 日: int = d % 30
	return "第%d年%d月%d日" % [年, 月, 日]

# 结构化汇总（供 UI 三层展示使用）
# 返回值同时兼容旧接口（String）和 新 UI（结构化数据存 离线汇总数据）
var 离线汇总数据: Dictionary = {}   # 新UI读取此字段构建三层面板
func 生成结构化汇总(流失日数: int, 灵石收益: int) -> String:
	# 按优先级分桶
	var 高优事件 := []
	var 普通事件 := []
	var 琐事事件 := []
	# 统计计数
	var 突破数 := 0
	var 稀有物品数 := 0
	var 任职数 := 0
	var 奇遇成功数 := 0
	for 条目 in 推演日志:
		match 条目.get("priority", PRIO_NORMAL):
			PRIO_HIGH:
				高优事件.append(条目)
			PRIO_NORMAL:
				普通事件.append(条目)
			PRIO_TRIVIAL:
				琐事事件.append(条目)
		# 统计
		if 条目.get("event_type") == ET_BREAKTHROUGH:
			突破数 += 1
		if 条目.get("event_type") in [ET_LOOT, ET_QUEST]:
			if "得【" in 条目.get("text", "") and ("极品" in 条目.get("text", "") or "特殊" in 条目.get("text", "")):
				稀有物品数 += 1
		if 条目.get("event_type") == ET_APPOINT:
			任职数 += 1
		if 条目.get("event_type") == ET_QUEST and "无功而返" not in 条目.get("text", ""):
			奇遇成功数 += 1

	# 存储结构化数据供新 UI 使用
	离线汇总数据 = {
		"summary": {
			"offline_days": 流失日数,
			"lingshi_earned": 灵石收益,
			"breakthrough_count": 突破数,
			"rare_loot_count": 稀有物品数,
			"appoint_count": 任职数,
			"quest_success_count": 奇遇成功数,
			"total_events": 推演日志.size(),
			"high_count": 高优事件.size(),
			"trivial_count": 琐事事件.size(),
		},
		"high_events": 高优事件,
		"normal_events": 普通事件,
		"trivial_events": 琐事事件,
	}

	# 兼容旧 UI：返回纯文本（降级显示）
	if 推演日志.is_empty():
		return "（暂无新事件）"
	var 文本行 := []
	for 条目 in 推演日志:
		文本行.append(条目.get("text", ""))
	return "═══ 你离开期间（%s）═══\n" % 时间文本() + "\n".join(文本行)

# 旧接口别名（保持向后兼容）
func 生成汇总报告() -> String:
	return 生成结构化汇总(0, 0)

# ============ 御兽堂 ============
func 推进孵化(日数: int):
	var 已孵: Array = []
	for e in 灵兽蛋列表:
		e.剩余天数 -= 日数
		if e.剩余天数 <= 0:
			e.孵化()
			已孵.append(e)
	for e in 已孵:
		灵兽蛋列表.erase(e)
		灵兽库存.append(e)
	if 已孵.size() > 0:
		战报更新.emit("御兽堂有 %d 枚灵兽蛋孵化完成，可前往绑定！" % 已孵.size())

func 绑定灵兽给首只合格(灵兽: Beast) -> String:
	for d in 弟子列表:
		if d.灵兽 != null:
			continue
		if (d.资质 == "fan_su" or d.资质 == "pingyong") and not (灵兽.品阶 in ["fan_jie", "ling_jie"]):
			continue
		d.灵兽 = 灵兽
		灵兽库存.erase(灵兽)
		弟子变动.emit()
		return "【%s】已绑定灵兽【%s】。" % [d.姓名, 灵兽.种类名]
	return "无符合条件的空闲弟子可绑定（低资质仅能携凡/灵阶灵兽）。"

# ============ 交宗 / 自留 ============
func 交宗(条目: Dictionary):
	var 弟子: Disciple = 条目["弟子"]
	var 物品: Item = 条目["物品"]
	var 贡献: int = {"凡阶": 10, "灵阶": 20, "宝阶": 40, "王阶": 80, "圣阶": 150, "仙阶": 300, "道阶": 600}.get(物品.品阶, 10)
	if 弟子.背包.has(物品):
		弟子.背包.erase(物品)
		贡献点 += 贡献
	elif 弟子.装备.has(物品.穿戴位) and 弟子.装备[物品.穿戴位] == 物品:
		弟子.装备.erase(物品.穿戴位)
		贡献点 += 贡献
	移除待抉择(条目)
	弟子变动.emit()
	战报更新.emit("【%s】将【%s】交予宗门，换得贡献点 +%d。" % [弟子.姓名, 物品.名称, 贡献])

func 自留(条目: Dictionary):
	var 弟子: Disciple = 条目["弟子"]
	var 物品: Item = 条目["物品"]
	移除待抉择(条目)
	弟子变动.emit()
	战报更新.emit("【%s】将【%s】收入囊中，自行留用。" % [弟子.姓名, 物品.名称])

func 移除待抉择(条目: Dictionary):
	for i in range(待抉择.size()):
		if 待抉择[i] == 条目:
			待抉择.remove_at(i)
			return

# ============ 存档 / 读档 ============
func save_game():
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"lingshi": 灵石, "gongxian": 贡献点, "dizi": [], "lingshou_dan": [], "lingshou_kucun": [],
		"累计游戏日": 累计游戏日, "最后登录": 最后登录, "门派等级": 门派等级, "声望": 声望, "繁荣": 繁荣,
		"堂口负责人": 堂口负责人存档, "引导阶段": 引导阶段,
		"体力": 体力, "已通关关卡": 已通关关卡, "精英每日次数": 精英每日次数,
		"气运修炼加成": 气运修炼加成, "气运产出加成": 气运产出加成, "气运到期日": 气运到期日,
	}
	for d in 弟子列表:
		data["dizi"].append(d.to_dict())
	for e in 灵兽蛋列表:
		data["lingshou_dan"].append(e.to_dict())
	for b in 灵兽库存:
		data["lingshou_kucun"].append(b.to_dict())
	# 存档安全：先写临时文件，校验后原子替换；写前滚动备份
	_滚动备份()
	var tmp: String = "user://save.tmp.json"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if not f:
		push_error("存档失败：临时文件无法打开")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	var da: DirAccess = DirAccess.open("user://")
	var err: int = OK
	if da:
		err = da.rename(tmp, "save.json")
	if err != OK:
		push_error("存档失败：原子替换错误 %d" % err)

func load_game():
	if not FileAccess.file_exists("user://save.json"):
		return
	var data: Dictionary = _读存档("user://save.json")
	if data.is_empty():
		# 主档损坏，尝试从历史备份恢复
		push_error("主存档解析失败，尝试从历史备份恢复")
		data = _恢复最新备份()
	if data.is_empty():
		return
	if data.get("version", 0) != SAVE_VERSION:
		push_warning("存档版本不一致(%d)，尝试兼容读取" % data.get("version", 0))
	灵石 = data.get("lingshi", 0)
	贡献点 = data.get("gongxian", 0)
	累计游戏日 = data.get("累计游戏日", 0)
	最后登录 = data.get("最后登录", 0)
	门派等级 = clamp(data.get("门派等级", 1), 1, 门派等级上限)
	声望 = data.get("声望", 0)
	繁荣 = data.get("繁荣", 50)
	堂口负责人存档 = data.get("堂口负责人", {})
	引导阶段 = data.get("引导阶段", 5)   # 老档无此字段 → 默认5（已完成，不强制弹引导）
	气运修炼加成 = data.get("气运修炼加成", 0.0)
	气运产出加成 = data.get("气运产出加成", 0.0)
	气运到期日 = data.get("气运到期日", 0)
	体力 = data.get("体力", 50)
	已通关关卡 = data.get("已通关关卡", {})
	精英每日次数 = data.get("精英每日次数", {})
	弟子列表.clear()
	待抉择.clear()
	奇遇待抉择.clear()      # 会话瞬时队列，load 时清空（ADR-002 D6）
	宗门纪事.clear()        # 会话瞬时历史，load 时清空
	灵兽蛋列表.clear()
	灵兽库存.clear()
	for dd in data.get("dizi", []):
		var d := Disciple.new()
		d.from_dict(dd)
		弟子列表.append(d)
	for ed in data.get("lingshou_dan", []):
		var e := Beast.new()
		e.from_dict(ed)
		灵兽蛋列表.append(e)
	for bd in data.get("lingshou_kucun", []):
		var b := Beast.new()
		b.from_dict(bd)
		灵兽库存.append(b)

# ---- 存档安全辅助函数 ----
func _读存档(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var txt: String = f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data

func _滚动备份():
	# 仅在主档存在时滚动：bak2 <- bak1 <- save.json（copy 前先删目标，避免已存在冲突）
	if not FileAccess.file_exists("user://save.json"):
		return
	var da: DirAccess = DirAccess.open("user://")
	if not da:
		return
	if FileAccess.file_exists("user://save.bak2.json"):
		da.remove("save.bak2.json")
	if FileAccess.file_exists("user://save.bak1.json"):
		da.copy("save.bak1.json", "save.bak2.json")
	if FileAccess.file_exists("user://save.bak1.json"):
		da.remove("save.bak1.json")
	da.copy("save.json", "save.bak1.json")

func _恢复最新备份() -> Dictionary:
	for bak in ["user://save.bak1.json", "user://save.bak2.json"]:
		if FileAccess.file_exists(bak):
			var d: Dictionary = _读存档(bak)
			if not d.is_empty():
				push_warning("已从备份恢复：%s" % bak)
				return d
	return {}

# 开始新游戏：删除存档 + 重置所有状态到初始值 + 重新初始化
# 由 main.gd 调试按钮触发（OS.is_debug_build 包裹）
func new_game():
	# 1. 删除存档文件及备份
	var da: DirAccess = DirAccess.open("user://")
	if da:
		for f in ["save.json", "save.tmp.json", "save.bak1.json", "save.bak2.json"]:
			if FileAccess.file_exists("user://" + f):
				da.remove(f)
	# 2. 重置所有状态到声明默认值
	灵石 = 1000
	贡献点 = 0
	弟子列表.clear()
	灵兽蛋列表.clear()
	灵兽库存.clear()
	待抉择.clear()
	奇遇待抉择.clear()
	宗门纪事.clear()
	_上次奇遇时刻 = 0
	_今日奇遇次数 = 0
	_奇遇日标记 = -1
	_单条冷却记录.clear()
	累计游戏日 = 0
	最后登录 = 0
	门派等级 = 1
	声望 = 0
	繁荣 = 50
	引导阶段 = 0
	堂口列表.clear()
	堂口负责人存档.clear()
	推演日志.clear()
	体力 = 50
	已通关关卡.clear()
	精英每日次数.clear()
	# 3. 重新初始化
	初始建宗()
	重建堂口()
	弟子变动.emit()

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
const PeriodSettlementScript = preload("res://period_settlement.gd")   # P1：周期结算评分模块

# 时间流速：240 现实秒 = 1 游戏日（1 现实天 ≈ 1 游戏年）
# === S1 端口：时辰历法换算层 ===
# 调用位置：所有周期玩法（刷新/结算/突破冷却）读取「游戏日」处，应在读取前经此层换算为「时辰→日→月→年」。
# 入参：游戏日(int) | 返回值：Dict{时辰, 日, 月, 年} 或统一游戏内时间戳（S1 定）
# 状态：当前未建，仅标记；现役仍用 累计游戏日 裸整数。依赖：时间换算层（见 §四 时间体系修真化）。
const 现实秒每游戏日 := 240.0
const 单次推演上限日 := 3650
const SAVE_VERSION := 1   # 存档结构版本号：损坏检测与跨版本兼容用

var 灵石 := 1000
var 灵草 := 0
var 矿石 := 0
var 灵气 := 0
var 贡献点 := 0
# === S1 批1：阶位轴考核经济参数（全部 [PLACEHOLDER]，待数值 GDD/CSV 校准，不影响 F5）===
const 考核成本: int = 50          # 发起单次考核行政成本（贡献点）
const 考核失败扣减: int = 50      # 失败额外扣减（叠加行政成本，单次失败共 -100）
const 考核贡献阈值: int = 300     # 贡献点 → 成功率加成满值门槛
const 破格声望阈值: int = 5000    # D5：声望≥此值且立大功方可破格升一阶
const 考核冷却日: int = 7         # 失败冷却（游戏日）
# 堂口阶位门槛映射（阶位索引：0=执事,1=堂主,2=长老阶位,3=供奉；-1=不可任）。
# 对齐实际 Lore.堂口定义（现役 12 堂口）；GDD §7.2 所列 shanzhen/hushan/baoku/yanwu/xixi/wudao
# 在现役 Lore 中不存在，已按实际 key 对齐。供奉档无对应堂口（供奉阶位仍可经考核取得）。
const 堂口阶位门槛: Dictionary = {
	"yuying": 0, "lingtian": 0, "kuangmai": 0,        # 基础资源/接引：执事起
	"dantang": 1, "qitang": 1, "cangjing": 1, "zhifa": 1, "tanwei": 1, "gongxun": 1,  # 功能堂口：堂主起
	"yushou": 2, "zhenfa": 2, "xichi": 2,             # 核心堂口：长老阶位起
}
# S1 批1：立大功标记（运行时态，不持久化；D5 破格条件3：声望≥阈值且刚立大功）
var 立大功标记: Dictionary = {}
var 玄玉 := 0                      # 付费便利货币（S0 stub：仅占位，真实充值/广告后端归S1）
var 弟子列表: Array[Disciple] = []   # 强类型数组（需 disciple.gd 已注册 class_name）

# 御兽堂：孵化中的灵兽蛋 + 已孵化待绑定的灵兽库存
var 灵兽蛋列表: Array[Beast] = []
var 灵兽库存: Array[Beast] = []
var 灵兽兑换队列: Array[Dictionary] = []   # T03：引育计划队列（{偏好,cost,启用}），周期结算执行

# 待抉择队列：弟子获得的极品/特殊道具，等待玩家决定“交宗换贡献”或“弟子自留”
var 待抉择: Array[Dictionary] = []

# 奇遇待抉择队列（ADR-002 D4）：紫+ 奇遇需掌门干预；结构 {弟子, 奇遇包, 选项}；会话瞬时，load 时清空
var 奇遇待抉择: Array[Dictionary] = []
# 宗门纪事（最简版）：本次会话已触发的奇遇历史，供 main.gd「纪事」标签回看；会话瞬时，load 时清空
var 宗门纪事: Array = [] 

# ============ 彩蛋系统（第一批·真零成本子集 + 轻量底座）============
# 全局开关：一键关闭所有彩蛋数值加成（仅保留文案/交互），兜底平衡风险
var 彩蛋启用: bool = true
# 单ID屏蔽集：egg_id -> true 表示屏蔽该彩蛋（出问题精准止损，无需回滚）
var 彩蛋屏蔽集: Dictionary = {}
# 配置表（由 _加载彩蛋配置 从 config/easter_egg_config.csv 读入）
var 彩蛋配置表: Array = []
# 节奏校准配置表（双周期评级配套系统：招徒/随机事件/奇遇/稳固期/瓶颈打磨，由 _加载节奏校准 从 config/节奏校准.csv 读入）
var 节奏校准: Dictionary = {}
# 临时增益（当日生效）：dim -> {"pct":float, "到期日":int}；接入产出/修炼加法管线
var 彩蛋临时增益: Dictionary = {}
# 数值红线常量（与 pre_f5 断言双保险）：单彩蛋≤5%、永久全局≤3%
const 彩蛋单上限: float = 0.05
const 彩蛋永久总上限: float = 0.03
# ===== 增益数值红线（全游戏统一，所有buff遵守；与 pre_f5 断言双保险）=====
# 单位：百分比整数（与 config/*.csv 的 buff_pct 列一致，0-5 即 0%~5%）
const 增益单条上限: float = 5.0       # 任意类型单条buff≤5%（彩蛋/付费/活动/建筑，永久限时统一）
const 增益永久全局上限: float = 3.0  # 永久类全局总增益≤3%（与彩蛋永久红线对齐）
const 增益限时全局上限: float = 8.0  # 限时类全局总增益≤8%（全局总和上限，非单条）
# 通用增益(战斗)软25%/硬30% 见 disciple.gd _clamp_soft(...,0.25,0.30,0.2)，付费buff并入同池共享封顶

# ===== 付费预留接入点（S0 stub：全部置灰，当前不生效，S1 接真实支付/广告后端）=====
# 统一前缀 _pay_reserved_，全局可检索；每个对应一个未来付费功能入口。
func _pay_reserved_修炼加速():
	# S1 付费：消耗玄玉立即完成 N 天修炼进度 / 瓶颈加速。当前不生效。
	pass

func _pay_reserved_灵兽加速():
	# S1 付费：消耗玄玉立即孵化灵兽 / 灵兽+1级。当前不生效。
	pass

func _pay_reserved_坊市购买():
	# S1 付费：玄玉购买坊市商品 / 手动刷新坊市。当前不生效。
	pass

func _pay_reserved_历练购买():
	# S1 付费：玄玉购买历练额外次数 / 重置次数。当前不生效。
	pass

func _pay_reserved_建筑加速():
	# S1 付费：玄玉立即领取建筑产出 / 建筑升级加速。当前不生效。
	pass

func _pay_reserved_全局增益():
	# S1 付费：付费buff统一接入入口，并入 disciple.聚合通用增益() 共享 25%/30% 封顶。当前不生效。
	pass

# 玄玉专区配置读取（S0 stub：仅供 UI 占位展示，不接真实购买）
func _玄玉表() -> Array:
	var 表: Array = []
	for r in DestinyDataLoader._read_csv("res://config/xuanyu_shop.csv"):
		表.append(r)
	return 表

# 引育纪事配置读取（S1：按 品阶×类型 匹配差异化纪事文案，圣/仙/道标异闻；纯配置驱动，零数值）
func _引育纪事表() -> Array:
	var 表: Array = []
	for r in DestinyDataLoader._read_csv("res://config/引育纪事.csv"):
		表.append(r)
	return 表

# 按灵兽蛋的 品阶 + beast_type 查表生成引育纪事文案；优先级：
# (品阶,类型) > (品阶,通用) > (通用,类型) > (通用,通用)；均无匹配则兜底文本。
func _引育纪事文案(蛋: Beast) -> Dictionary:
	var 阶: String = 蛋.品阶
	var 型: String = 蛋.beast_type
	var 表: Array = _引育纪事表()
	for r in 表:
		if r.get("品阶", "") == 阶 and r.get("类型", "") == 型:
			return {"文案": r.get("文案", "").replace("{种类}", 蛋.种类名), "category": r.get("category", "")}
	for r in 表:
		if r.get("品阶", "") == 阶 and r.get("类型", "") == "通用":
			return {"文案": r.get("文案", "").replace("{种类}", 蛋.种类名), "category": r.get("category", "")}
	for r in 表:
		if r.get("品阶", "") == "通用" and r.get("类型", "") == 型:
			return {"文案": r.get("文案", "").replace("{种类}", 蛋.种类名), "category": r.get("category", "")}
	for r in 表:
		if r.get("品阶", "") == "通用" and r.get("类型", "") == "通用":
			return {"文案": r.get("文案", "").replace("{种类}", 蛋.种类名), "category": r.get("category", "")}
	return {"文案": "御兽峰按月引育，收得兽卵一枚（%s），已入温养池。" % 蛋.种类名, "category": ""}

# ===== S0 任务/商店系统状态（2026-07-21 新增；不升 SAVE_VERSION，load 用 .get 默认向后兼容）=====
var 宗门库房: Array = []                 # 坊市购买所得物品（Item 实例）
var 坊市上架集: Array = []               # 本周上架 shop_id 列表（周刷新随机抽8-12件）
var 坊市购买记录: Dictionary = {}         # shop_id -> {daily, weekly, week_start}
var 坊市类别月购: Dictionary = {}         # D2：类别 -> 本月已购数量（月度限购）
var 坊市月购窗口起始日: int = 0           # D2：类别月度限购 30 天窗口起始日
var 当前日常: Array = []                  # 当日日常任务（quest_daily 行字典，最多3条）
var 日常已领: Array = []                  # 与 当前日常 等长，true=已领取
var 上次日常日: int = 0
var 当前周常: Dictionary = {}             # 当周周常任务（quest_weekly 行字典）
var 周常已领: bool = true
var 上次周常日: int = 0
var 随机事件冷却: Dictionary = {}          # quest_id -> 上次触发累计游戏日
var 随机事件类型冷却: Dictionary = {}     # quest_type -> 上次触发累计游戏日（同类型1月冷却）

# ===== P0 目标链系统 · 新手阶梯状态（2026-07-25 新增；不升 SAVE_VERSION，load 用 .get 默认兼容老档）=====
var 新手目标链激活: bool = false          # FTUE 收尾后解锁（激活 newbie_001）
var 新手完成列表: Array = []              # 已完成 newbie quest_id 列表（靠 prev_quest_id 推导解锁链）
signal 新手目标更新()                      # UI 玉牌红点 / 宗门要务面板刷新


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
var quest_cooldown: Dictionary = {}         # event_id → 冷却到期月份（防重复3个月）

# 时间 / 门派
var 累计游戏日 := 0
var 最后登录 := 0
var 门派等级 := 1
const 声望折扣表: Array = [1.0, 0.95, 0.9, 0.85, 0.8]   # 声望等级0-4对应折扣（中立/友善/尊敬/崇敬/崇拜）
const 声望等级名: Array = ["中立", "友善", "尊敬", "崇敬", "崇拜"]
var 声望 := 0
var 繁荣 := 50
# === S1 批5-A：凡人香火体系（纯经营层 · 空桩逻辑 · 数值 [PLACEHOLDER] 待真机校准）===
var 香火值 := 0
var 信徒数 := 0
var 凡人城镇: Array = []
var 香火月产预估 := 0
var 信徒增益档: String = "未启"
# === S1 批5-B：辈分礼制体系（纯经营层 · 字派序列 / 门规严格度）===
# 旧档 辈分字派 空 → 首次推演月/首次招徒自动生成并持久化（见 _确保字派_S1）；不升 SAVE_VERSION。
var 辈分字派: Array = []
var 门规严格度: String = "中庸"
# === S1 批5-C：正邪路线抉择（纯经营/叙事层 · 不可逆标记 · 数值 [PLACEHOLDER] 待真机校准）===
var 正邪路线: String = ""     # 空=未选；取值 {玄门正道, 逍遥中立, 九幽邪道}（D7 已拍板）

# === S1 批6-A：宗门大阵（纯经营系统 · 数据层 · 数值 [PLACEHOLDER] 待真机校准 · 不升 SAVE_VERSION）===
# 结构：当前主阵(String)/等级(Dict array_id→int)/耐久(Dict array_id→int)/已解锁(Dict array_id→bool)
var 宗门大阵: Dictionary = {"当前主阵":"", "等级":{}, "耐久":{}, "已解锁":{}}
# 阵法配置表缓存（由 _加载阵法配置_S1 从 config/array_config.csv 读入，键=array_id）
var 阵法配置表: Dictionary = {}
# 阵法物品表（D5 阵图解锁闭环）：由 _加载阵法物品_S1 从 config/array_items.csv 读入
# 阵法物品表: item_id → 行；阵法物品名表: 名称 → 行（背包 Item 仅携名称，按名检索）；阵法_按阵法: array_id → 图书名
var 阵法物品表: Dictionary = {}
var 阵法物品名表: Dictionary = {}
var 阵法_按阵法: Dictionary = {}
# 弟子已解锁单人法阵集合（D5）：姓名 → Array[String]（宗门大阵另走 宗门大阵.已解锁）
var 已解锁单人法阵: Dictionary = {}

# P1：周期结算评分（年结：游戏年 = 365 日）
var 周期评分: PeriodSettlement = PeriodSettlementScript.new()
var 上次结算年 := 0            # 上次年结时的累计游戏日，用于跨 365 日边界检测
# ===== 双周期评级（1年小考 + 7年大考）状态 =====
var 双周期评级启用: bool = true   # 全局回退开关（true=七载双周期；false=回退纯年度实时，读 config/评级节奏.csv）
var 七载奖励池: int = 0          # 年度评定 deferred 的 30% 灵石累积池
var 七载待发掉落: Array = []     # 年度评定 deferred 的 S 级以上高阶法宝（按评级记录）
var 门派等级目标: int = 1        # 七载模式下「成长值中间量」，七载大考才生效
var 上次七载日: int = 0          # 上次七载大考时的累计游戏日，用于跨 2555 日边界检测
var 七载大典待展示: bool = false   # 七载大考触发的瞬时展示标记（不存档），main._构建离山内容 读取后置 false
var 七载大典摘要: Dictionary = {}  # 七载大典待展示时承载的展示数据（灵石/法宝数/晋升至），不存档
var 年始灵石 := 0             # 本年起始灵石（结算时算增量）
var 年始总战力 := 0           # 本年起始宗门总战力（结算时算增量）
var 最新周期评级卡: Dictionary = {}   # 最近一次结算评级卡，供离山汇总展示
var 历史周期评级: Array = []       # 近 12 周期评级（与 周期评分.历史 同步）
var 引导阶段: int = 0   # 新手引导：0序章/1-5五步/6完成（老档兼容见 load_game 默认6）
var 上次测灵日 := 0        # 测灵根冷却：上次举办时的游戏日（1年一度=365游戏日）

# 堂口系统：{key: {key,名称,职能,产出,加成维度,负责人:Disciple,成员:Array}}
var 堂口列表: Dictionary = {}
var 堂口负责人存档: Dictionary = {}
var 堂口状态存档: Dictionary = {}   # S1 批2：堂口等级/政绩持久化（仿 堂口负责人存档 范式）

# ============ 建筑被动（阶段2：占位建筑被动功能）============
# 资源翻倍类：本月各资源建筑实际产出额（供 _建筑被动结算 概率翻倍时直接加回，避免重复计算 经营/气运/产出 乘区）
var _本月灵田产出: int = 0
var _本月矿脉产出: int = 0
var _本月丹堂产出: int = 0
var _本月器堂产出: int = 0
# 器堂赠宝 P1 状态（轻量；序列化持久化，不升 SAVE_VERSION，旧档缺键→默认零回归）
var _上次出战弟子: Array = []          # 最近出战阵容（存弟子姓名；挑战关卡 写入；save/load 持久化）
var _器堂赠宝未中上阵连计: int = 0     # 保底计数器：连续未把赠宝发给上阵弟子的次数（≥3 下月强制上阵档）
var _器堂赠宝表: Array = []            # craft_hall_reward.csv 缓存（懒加载，_读器堂赠宝行 首次触发）
# S1 批2 D7：Lv.2+ 保底津贴基数（每月 等级×基数 灵石，[PLACEHOLDER] 待数值 GDD 校准）
const 建筑保底津贴: int = 5
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

# 藏经阁：全宗弟子 修炼速度 +5%（并入 推演一月 宗门加成pct，加法叠加封顶 +100%）
func _藏经阁修炼乘区() -> float:
	return 1.05 if 堂口列表.has("cangjing") else 1.0

# S1 批6-A：宗门大阵·聚灵大阵（arr_s_002）修炼乘区（仿 _藏经阁修炼乘区）。
# 仅当前主阵为聚灵大阵时提供修炼速度增益；其余阵（护山/镇煞/玄空）不作用于修炼乘区。
# 数值 [PLACEHOLDER]：eff_val_base/level_growth_coef 取自 array_config.csv（本批用投稿值）。
func _宗门大阵修炼乘区() -> float:
	var 主阵: String = 宗门大阵.get("当前主阵", "")
	if 主阵 == "":
		return 1.0
	if 主阵 != "arr_s_002":   # 仅聚灵大阵（arr_s_002）对全宗修炼速度生效
		return 1.0
	var 配置: Dictionary = 阵法配置表.get(主阵, {})
	var 等级: int = int(宗门大阵.get("等级", {}).get(主阵, 1))
	var 基准: float = float(配置.get("eff_val_base", "0"))
	var 系数: float = float(配置.get("level_growth_coef", "0"))
	var 增益: float = 基准 * (1.0 + (等级 - 1) * 系数)
	return 1.0 + 增益

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
	_加载彩蛋配置()
	_加载节奏校准()
	_加载阵法配置_S1()
	_加载阵法物品_S1()
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
	# === S1 批5-B：新弟子道号简化生成（[PLACEHOLDER] 简化版：外门=辈分字派[0]+单字）===
	_确保字派_S1()
	d.辈分序 = 0   # 默认开山第1字
	if d.身份 == "外门" and not 辈分字派.is_empty():
		d.道号 = 辈分字派[0] + (d.姓名.left(1) if d.姓名.length() > 0 else "尘")
	# 其余阶位道号暂留空 ""（玩家可改）；[PLACEHOLDER] 命名规则见 GDD §⑤.2
	弟子列表.append(d)
	弟子变动.emit()
	return d

# ============ 时间推演核心 ============
# ============ S0 商店（坊市）：经济消耗出口 ============
var _坊市缓存: Array = []
func _坊市表() -> Array:
	if _坊市缓存.is_empty():
		for r in DestinyDataLoader._read_csv("res://config/faction_shop.csv"):
			_坊市缓存.append(r)
	return _坊市缓存

# D2 坊市动态行情：懒加载 坊市行情.csv（类别 -> 行）；文件缺失返回空 dict（No-op 安全）
var 坊市行情表缓存: Dictionary = {}
func _坊市行情表() -> Dictionary:
	if 坊市行情表缓存.is_empty():
		for r in DestinyDataLoader._read_csv("res://config/坊市行情.csv"):
			坊市行情表缓存[r.get("类别", "")] = r
	return 坊市行情表缓存

# 坊市周刷新：从总商品池随机抽 8-12 件上架（S0 P0：保留日/周限购）
func 刷新坊市上架():
	var 全部: Array = _坊市表()
	全部.shuffle()
	var n: int = mini(randi_range(8, 12), 全部.size())
	坊市上架集 = []
	for i in n:
		坊市上架集.append(全部[i].get("shop_id", ""))

# 声望折扣率（索引=声望等级，clamp 防越界）
func 坊市折扣率() -> float:
	return 声望折扣表[clamp(声望, 0, 声望折扣表.size() - 1)]

# 商品实际价格（声望折扣后叠加坊市行情浮动；D2 坊市动态行情）
func 坊市实价(原价: int, 类别: String = "") -> int:
	var 价 = ceil(原价 * 坊市折扣率())            # 现有声望折扣
	var 行 = _坊市行情表().get(类别, {})
	var 下限 = float(行.get("浮动下限", 0.90))
	var 上限 = float(行.get("浮动上限", 1.10))
	var 浮动 = randf_range(下限, 上限)             # 行情价格乘数摆动（±10%）
	价 = int(round(价 * 浮动))
	价 = int(round(价 * _坊市负面卖价下限))
	return 价

# 库房分类：按商品名关键词推断类别（CSV 无类别列，零字段改动）
func _坊市商品类别(行: Dictionary) -> String:
	var 名: String = 行.get("item_name", "")
	if 名.contains("丹") or 名.contains("药"):
		return "丹药"
	if 名.contains("剑") or 名.contains("刀") or 名.contains("枪") or 名.contains("甲") or 名.contains("袍") or 名.contains("冠") or 名.contains("靴") or 名.contains("佩") or 名.contains("环") or 名.contains("法宝") or 名.contains("兵"):
		return "装备"
	if 名.contains("诀") or 名.contains("经") or 名.contains("功") or 名.contains("法") or 名.contains("术") or 名.contains("卷"):
		return "功法"
	return "资源"

# 购买坊市物品：校验声望/上架/限购/灵石，扣费入宗门库房，返回 {ok, msg}
func 购买坊市物品(shop_id: String) -> Dictionary:
	var 行: Dictionary = {}
	for r in _坊市表():
		if r.get("shop_id", "") == shop_id:
			行 = r
			break
	if 行.is_empty():
		return {"ok": false, "msg": "无此商品"}
	if not 坊市上架集.has(shop_id):
		return {"ok": false, "msg": "本周未上架"}
	if int(行.get("unlock_reputation", "0")) > 声望:
		return {"ok": false, "msg": "声望不足（需 %d）" % int(行.get("unlock_reputation", "0"))}
	var 原价: int = int(行.get("price_lingjing", "0"))
	var 类别: String = _坊市商品类别(行)          # D2：提前算类别，供折后行情浮动 + 月度限购共用
	var 折后: int = 坊市实价(原价, 类别)
	var 日限: int = int(行.get("limit_daily", "0"))
	var 周限: int = int(行.get("limit_weekly", "0"))
	var 记: Dictionary = 坊市购买记录.get(shop_id, {"daily": 0, "weekly": 0, "week_start": 累计游戏日})
	if 累计游戏日 - int(记.get("week_start", 累计游戏日)) >= 7:
		记 = {"daily": 0, "weekly": 0, "week_start": 累计游戏日}
	# D2 坊市动态行情：类别级月度限购（30 天窗口重置，参考 week_start 逻辑）
	if 累计游戏日 - 坊市月购窗口起始日 >= 30:
		坊市类别月购.clear()
		坊市月购窗口起始日 = 累计游戏日
	var 行行情: Dictionary = _坊市行情表().get(类别, {})
	if not 行行情.is_empty():
		var 限额: int = int(行行情.get("限购数量", 0))
		if 限额 > 0 and int(坊市类别月购.get(类别, 0)) + 1 > 限额:
			return {"ok": false, "msg": "该类别本月限购已用完"}
	if 日限 > 0 and int(记.get("daily", 0)) >= 日限:
		return {"ok": false, "msg": "今日限购已用完"}
	if 周限 > 0 and int(记.get("weekly", 0)) >= 周限:
		return {"ok": false, "msg": "本周限购已用完"}
	if 灵石 < 折后:
		return {"ok": false, "msg": "灵石不足（需 %d，%s%d折）" % [折后, 声望等级名[clamp(声望,0,声望等级名.size()-1)], int(坊市折扣率()*100)]}
	灵石 -= 折后
	var it: Item = Item.new()
	it.名称 = 行.get("item_name", "未知物品")
	it.品阶 = 行.get("item_grade", "凡品")
	it.类别 = 类别
	宗门库房.append(it)
	记["daily"] = int(记.get("daily", 0)) + 1
	记["weekly"] = int(记.get("weekly", 0)) + 1
	坊市购买记录[shop_id] = 记
	坊市类别月购[类别] = int(坊市类别月购.get(类别, 0)) + 1   # D2：月度限购计数 +1
	var 折扣说明: String = "" if 折后 == 原价 else "（%s%d折）" % [声望等级名[clamp(声望,0,声望等级名.size()-1)], int(坊市折扣率()*100)]
	return {"ok": true, "msg": "购入 %s（-%d灵石%s）" % [行.get("item_name", ""), 折后, 折扣说明]}

# ============ S0 日常任务（极简版：固定3条/日）============
func 刷新日常任务():
	var 池: Array = []
	for r in DestinyDataLoader._read_csv("res://config/quest_daily.csv"):
		if int(r.get("unlock_sect_level", "1")) <= 门派等级:
			池.append(r)
		if r.get("is_newbie", "") == "true":
			continue
	池.shuffle()
	当前日常 = 池.slice(0, min(3, 池.size()))
	日常已领 = []
	for i in 当前日常.size():
		日常已领.append(false)
	上次日常日 = 累计游戏日

func 领取日常(序号: int) -> Dictionary:
	if 序号 < 0 or 序号 >= 当前日常.size():
		return {"ok": false, "msg": "任务不存在"}
	if 日常已领[序号]:
		return {"ok": false, "msg": "已领取"}
	var q: Dictionary = 当前日常[序号]
	var 灵: int = int(float(q.get("reward_lingjing", "0")) * 任务奖励系数())
	var 气: int = int(float(q.get("reward_lingqi", "0")) * 任务奖励系数())
	灵石 += 灵
	灵气 += 气
	日常已领[序号] = true
	_新手_检测("collect_income")
	return {"ok": true, "msg": "日常「%s」完成：灵石+%d 灵气+%d" % [q.get("quest_name", ""), 灵, 气]}

# ============ S0 周常（轻量：每7日1条）============
func 刷新周常():
	var 池: Array = []
	for r in DestinyDataLoader._read_csv("res://config/quest_weekly.csv"):
		if int(r.get("unlock_sect_level", "1")) <= 门派等级:
			池.append(r)
	if 池.is_empty():
		当前周常 = {}
		周常已领 = true
		return
	池.shuffle()
	当前周常 = 池[0]
	周常已领 = false
	上次周常日 = 累计游戏日
	刷新坊市上架()   # 周刷新同步更新坊市上架（每7日）

func 领取周常() -> Dictionary:
	if 当前周常.is_empty():
		return {"ok": false, "msg": "本周无周常"}
	if 周常已领:
		return {"ok": false, "msg": "已领取"}
	var 灵: int = int(float(当前周常.get("reward_lingjing", "0")) * 任务奖励系数())
	var 气: int = int(float(当前周常.get("reward_lingqi", "0")) * 任务奖励系数())
	灵石 += 灵
	灵气 += 气
	周常已领 = true
	return {"ok": true, "msg": "周常「%s」完成：灵石+%d 灵气+%d" % [当前周常.get("quest_name", ""), 灵, 气]}

# 任务奖励随门派等级线性缩放（每级+10%，上限3倍），避免后期奖励形同虚设
func 任务奖励系数() -> float:
	return clamp(1.0 + (门派等级 - 1) * 0.1, 1.0, 3.0)

# ============ P0 目标链系统 · 新手阶梯（混合主动/自动，上一条完成才解锁下一条）============
# 配置来源：quest_daily.csv 中 is_newbie==true 的 7 行（newbie_001..007）
# 事件型条件（recruit_count / realm_first_enter / collect_income / event_first_trigger）由 5 处业务钩子
#   调用 _新手_检测(条件) 触发完成；状态型条件（recruit_count_5 / disciple_realm_3 / disciple_realm_5）
#   由 _新手_评估后续() 依据当前状态预判，避免“死目标”。
func 激活新手目标链():
	if 新手目标链激活:
		return
	新手目标链激活 = true
	_新手_评估后续()   # 解锁 newbie_001 并预检状态型条件是否已满足

func _新手_配置() -> Array:
	var 链: Array = []
	for r in DestinyDataLoader._read_csv("res://config/quest_daily.csv"):
		if r.get("is_newbie", "") == "true":
			链.append(r)
	return 链

func _新手_已解锁(q: Dictionary) -> bool:
	var prev: String = q.get("prev_quest_id", "")
	if prev == "" or prev == null:
		return true
	return 新手完成列表.has(prev)

func 新手_当前进行() -> Dictionary:
	# 首个未完成且已解锁的 newbie（供 UI 展示）；未激活/全完成返回 {}
	if not 新手目标链激活:
		return {}
	for q in _新手_配置():
		if 新手完成列表.has(q.get("quest_id", "")):
			continue
		if _新手_已解锁(q):
			return q
	return {}

func 新手_完成数() -> int:
	return 新手完成列表.size()

func 新手_全部完成() -> bool:
	if not 新手目标链激活:
		return false
	return 新手完成列表.size() >= _新手_配置().size()

func 新手_有红点() -> bool:
	if not 新手目标链激活 or 新手_全部完成():
		return false
	return not 新手_当前进行().is_empty()

func _新手_检测(条件: String):
	# 事件型钩子入口：满足 条件 且已解锁&未完成的 newbie 立即完成（钩子本身即证据）
	if not 新手目标链激活:
		return
	for q in _新手_配置():
		var qid: String = q.get("quest_id", "")
		if 新手完成列表.has(qid):
			continue
		if not _新手_已解锁(q):
			continue
		if q.get("condition_type", "") != 条件:
			continue
		_新手_完成(q)
		return

func _新手_评估后续():
	# 状态型条件预检 + 链推进（解锁后/每次完成后调用；可连续解锁多条）
	if not 新手目标链激活:
		return
	for q in _新手_配置():
		var qid: String = q.get("quest_id", "")
		if 新手完成列表.has(qid):
			continue
		if not _新手_已解锁(q):
			continue
		if _新手_条件满足(q):
			_新手_完成(q)
			return

func _新手_条件满足(q: Dictionary) -> bool:
	var 条件: String = q.get("condition_type", "")
	match 条件:
		"recruit_count_5":
			return 弟子列表.size() >= 5
		"disciple_realm_3":
			for d in 弟子列表:
				if d.境界 == "练气" and d.层数 >= 3:
					return true
			return false
		"disciple_realm_5":
			for d in 弟子列表:
				if d.境界 == "练气" and d.层数 >= 5:
					return true
			return false
	return false   # 事件型条件不在状态预检中自动满足，交由对应钩子触发

func _新手_完成(q: Dictionary):
	var qid: String = q.get("quest_id", "")
	if 新手完成列表.has(qid):
		return
	新手完成列表.append(qid)
	var 灵: int = int(float(q.get("reward_lingjing", "0")) * 任务奖励系数())
	var 气: int = int(float(q.get("reward_lingqi", "0")) * 任务奖励系数())
	灵石 += 灵
	灵气 += 气
	_新手_抽池(q.get("reward_pool_id", ""))
	宗门纪事.append({"日": 累计游戏日, "稀有度": "琐事", "名称": "新手目标",
		"文案": "【新手目标】%s 达成，获灵石+%d 灵气+%d。" % [q.get("quest_name", ""), 灵, 气]})
	新手目标更新.emit()
	_新手_评估后续()   # 推进链（可能连续解锁多条状态型）

func _新手_抽池(pool_id: String):
	# P0 范围：仅结算可量化部分（灵石/气运）；材料/丹药按 +灵石 折算，
	# 避免向 宗门库房（Item 实例数组）写入非 Item 字典，破坏 save/load。
	if pool_id == "" or pool_id == null:
		return
	var 行: Array = []
	for r in DestinyDataLoader._read_csv("res://config/quest_reward_pool.csv"):
		if r.get("pool_id", "") == pool_id:
			行.append(r)
	if 行.is_empty():
		return
	var 总: float = 0.0
	for r in 行:
		总 += float(r.get("weight", "0"))
	if 总 <= 0:
		return
	var 抽: float = randf() * 总
	var 中: Dictionary = 行[0]
	for r in 行:
		抽 -= float(r.get("weight", "0"))
		if 抽 <= 0:
			中 = r
			break
	var 名: String = 中.get("item_name", "")
	if "气运" in 名:
		玄玉 += 1
	else:
		灵石 += 20

# ============ S0 随机事件（轻量挂载：月度推演概率触发）============
func _尝试随机事件():
	# S0 P0：月度从候选池按品阶权重抽1条（普通70/优秀20/稀有8/传说2），同类型+单事件双冷却
	var 候选: Array = []
	for r in DestinyDataLoader._read_csv("res://config/quest_random.csv"):
		if int(r.get("unlock_sect_level", "1")) > 门派等级:
			continue
		var qid: String = r.get("quest_id", "")
		var 类型: String = r.get("quest_type", "")
		if 累计游戏日 - int(随机事件冷却.get(qid, -999)) < int(r.get("valid_time", "24")):
			continue
		if 累计游戏日 - int(随机事件类型冷却.get(类型, -999)) < 30:
			continue
		候选.append(r)
	if 候选.is_empty():
		return
	var 总权重: int = 0
	for r in 候选:
		总权重 += _随机事件权重(r.get("rarity", "普通"))
	var 抽: int = randi() % 总权重
	var 选中: Dictionary = 候选[0]
	for r in 候选:
		抽 -= _随机事件权重(r.get("rarity", "普通"))
		if 抽 < 0:
			选中 = r
			break
	var 事件系数: float = _校准浮("随机事件奖励系数", 1.8)
	var 奖灵石: int = int(int(选中.get("reward_lingjing", "0")) * 事件系数)
	var 奖灵气: int = int(int(选中.get("reward_lingqi", "0")) * 事件系数)
	灵石 += 奖灵石
	灵气 += 奖灵气
	随机事件冷却[选中.get("quest_id", "")] = 累计游戏日
	随机事件类型冷却[选中.get("quest_type", "")] = 累计游戏日
	宗门纪事.append({"日": 累计游戏日, "稀有度": 选中.get("rarity", "普通"), "名称": 选中.get("quest_name", ""),
		"文案": "【随机事件】%s，门派获灵石+%d 灵气+%d。" % [选中.get("quest_name", ""), 奖灵石, 奖灵气]})
	_新手_检测("event_first_trigger")

# 随机事件品阶权重（S0 P0：普通70/优秀20/稀有8/传说2，对齐奇遇梯度）
func _随机事件权重(稀有度: String) -> int:
	var 表: Dictionary = {"普通": 70, "优秀": 20, "稀有": 8, "传说": 2}
	return 表.get(稀有度, 20)

# ============ S0 任务系统日推进（挂于 推演一月 累计游戏日 += 日 之后）============
func _推进任务系统(日: int):
	# 清理过期的奇遇防重复冷却（月份维度）
	var 月: int = _当前月()
	for k in quest_cooldown.keys():
		if 月 >= quest_cooldown[k]:
			quest_cooldown.erase(k)
	if 当前日常.is_empty() or (累计游戏日 - 上次日常日 >= 1):
		刷新日常任务()
	if 当前周常.is_empty() or (累计游戏日 - 上次周常日 >= 7):
		刷新周常()
	_尝试彩蛋奇遇("宗门内")
	_尝试彩蛋奇遇("历练")

# ============ 彩蛋系统（第一批）============
func _加载彩蛋配置():
	彩蛋配置表 = DestinyDataLoader._read_csv("res://config/easter_egg_config.csv")

# ============ 节奏校准（双周期评级配套：招徒/随机事件/奇遇/稳固期/瓶颈打磨）============
# 全配置化：参数集中在 config/节奏校准.csv；缺失文件或缺失行时回落到各调用点的默认值，绝不崩。
func _加载节奏校准():
	if 节奏校准.size() > 0:
		return
	节奏校准 = {}
	for 路径 in ["res://config/节奏校准.csv", "res://config/评级节奏.csv"]:
		for r in DestinyDataLoader._read_csv(路径):
			节奏校准[r.get("参数", "")] = r.get("值", "")

# ============ S1 批6-A：宗门大阵配置表（array_config.csv）============
# 范式：复用 DestinyDataLoader._read_csv（与 _加载彩蛋配置/_加载节奏校准 同款）。
# 解析为 阵法配置表[array_id] = {各列}，供 _宗门大阵修炼乘区 / 防御等效 / UI 读取。
# 缺失文件/缺行不崩（_read_csv 内部 push_warning 并返回空），随 CSV 热更重读。
func _加载阵法配置_S1():
	阵法配置表.clear()
	for r in DestinyDataLoader._read_csv("res://config/array_config.csv"):
		var id: String = r.get("array_id", "")
		if id != "":
			阵法配置表[id] = r

# ============ S1 批6-D5：阵法物品表（array_items.csv）============
# 与 _加载阵法配置_S1 同款范式；背包 Item 仅携带 名称（_掉落转物品 不写 item_id），
# 故同时建 名称→行 索引；阵法_按阵法 供面板提示「需使用 X 阵图解锁」。缺失文件不崩。
func _加载阵法物品_S1():
	阵法物品表.clear()
	阵法物品名表.clear()
	阵法_按阵法.clear()
	for r in DestinyDataLoader._read_csv("res://config/array_items.csv"):
		var id: String = r.get("item_id", "")
		if id != "":
			阵法物品表[id] = r
			var nm: String = r.get("item_name", "")
			if nm != "":
				阵法物品名表[nm] = r
			var ua: String = r.get("unlock_array_id", "")
			if ua != "":
				阵法_按阵法[ua] = nm

# ============ S1 批6-D5：阵图解锁闭环 helper（背包扣减/获得 + 数值计算）============
# 纯经营/配置读取，零触碰战斗核心（BattleCalculator/BattleManager 未引用本组函数）。

# 弟子是否已解锁某单人法阵（按 姓名 索引；新弟子缺键 → 默认未解锁，零回归）
func _弟子已解锁法阵(姓名: String, aid: String) -> bool:
	return 已解锁单人法阵.get(姓名, []).has(aid)

# 解锁某弟子单人法阵（幂等）
func _解锁弟子法阵(姓名: String, aid: String):
	if not 已解锁单人法阵.has(姓名):
		已解锁单人法阵[姓名] = []
	if not 已解锁单人法阵[姓名].has(aid):
		已解锁单人法阵[姓名].append(aid)

# 升到下一级所需阵纹碎片：cost_base × cost_growth^(当前级-1)，向上取整，下限 1
func _阵法升级消耗(aid: String, 当前级: int) -> int:
	var cfg: Dictionary = 阵法配置表.get(aid, {})
	var base: float = float(cfg.get("cost_base", 5))
	var growth: float = float(cfg.get("cost_growth", 1.3))
	return max(1, int(ceil(base * pow(growth, 当前级 - 1))))

# 从 1 级升到 至级 的累计消耗（拆解返还按此测算）
func _阵法升级总耗(aid: String, 至级: int) -> int:
	var 总: int = 0
	for lv in range(1, max(1, 至级)):
		总 += _阵法升级消耗(aid, lv)
	return 总

# 拆解返还阵纹碎片数（按阵阶梯度：凡阶40%/灵阶50%/宝阶60% + 阶别保底；数值平衡待 design-strategist 确认）
func _阵法拆解返还数(aid: String, 当前级: int) -> int:
	var cfg: Dictionary = 阵法配置表.get(aid, {})
	var 比值: float = 0.40
	var 阶底: int = 3
	match cfg.get("rank", "common"):
		"spirit":
			比值 = 0.50
			阶底 = 6
		"treasure":
			比值 = 0.60
			阶底 = 8
		_:
			比值 = 0.40
			阶底 = 3
	var 投入: int = _阵法升级总耗(aid, 当前级)
	if 当前级 < 1 or 投入 <= 0:
		return 0
	return int(floor(投入 * 比值)) + 阶底

# 统计弟子背包内阵纹碎片（item_015，名称=阵纹碎片）数量
func _统计阵纹碎片(d: Disciple) -> int:
	var n: int = 0
	for it in d.背包:
		if it != null and it.名称 == "阵纹碎片":
			n += 1
	return n

# 扣除弟子背包内阵纹碎片 n 个；不足返回 false（不扣）
func _扣除阵纹碎片(d: Disciple, n: int) -> bool:
	if n <= 0:
		return true
	if _统计阵纹碎片(d) < n:
		return false
	var 剩: int = n
	for i in range(d.背包.size() - 1, -1, -1):
		var it = d.背包[i]
		if it != null and it.名称 == "阵纹碎片":
			d.背包.remove_at(i)
			剩 -= 1
			if 剩 <= 0:
				break
	return true

# 发放 n 个阵纹碎片到弟子背包（经统一掉落工厂，保类别/穿戴位一致）
func _发放阵纹碎片(d: Disciple, n: int):
	for _k in range(n):
		var it: Item = _掉落转物品({"item_id": "item_015", "item_name": "阵纹碎片", "quality": "凡品"})
		d.背包.append(it)

# 类型化读取（CSV 存为字符串，按调用点需要解析）：缺失/空值回落默认，保证安全
func _校准浮(参数: String, 默认: float) -> float:
	var s: String = 节奏校准.get(参数, "")
	if s == "":
		return 默认
	return float(s)

func _校准整(参数: String, 默认: int) -> int:
	var s: String = 节奏校准.get(参数, "")
	if s == "":
		return 默认
	return int(float(s))

func _校准开(参数: String, 默认: bool) -> bool:
	var s: String = 节奏校准.get(参数, "")
	if s == "":
		return 默认
	return s in ["1", "true", "True", "TRUE", "是", "yes", "YES"]

func _彩蛋配置(egg_id: String) -> Dictionary:
	for r in 彩蛋配置表:
		if r.get("egg_id", "") == egg_id:
			return r
	return {}

func 彩蛋启用否(egg_id: String) -> bool:
	if not 彩蛋启用:
		return false
	if 彩蛋屏蔽集.has(egg_id):
		return false
	var c: Dictionary = _彩蛋配置(egg_id)
	if c.is_empty() or c.get("enabled", "true") != "true":
		return false
	return true

# 统一发放彩蛋奖励（仅宗门资源，不依赖弟子对象；零破坏核心）
func _发放彩蛋奖励(reward: String, 数量: int):
	match reward:
		"lingshi": 灵石 += 数量
		"lingcao": 灵草 += 数量
		"kuangshi": 矿石 += 数量
		"lingqi": 灵气 += 数量
		_: pass

# 触发点击类彩蛋（main.gd UI 钩子调用）：写异闻纪事 + 发奖励 + 置临时增益
func 触发点击彩蛋(egg_id: String):
	if not 彩蛋启用否(egg_id):
		return
	var c: Dictionary = _彩蛋配置(egg_id)
	var 名称: String = c.get("name", "无名彩蛋")
	var 文案: String = c.get("text", "")
	宗门纪事.append({"日": 累计游戏日, "稀有度": "异闻", "名称": 名称, "文案": 文案, "category": "异闻"})
	var rw: String = c.get("reward", "none")
	var rn: int = int(c.get("reward_num", "0"))
	if rw != "none" and rn > 0:
		_发放彩蛋奖励(rw, rn)
	_置彩蛋临时增益(c)

# 奇遇类彩蛋（独立于 event_quest.csv，仅复用纪事写入+奖励helper，杜绝污染奇遇池）
func _尝试彩蛋奇遇(scene: String):
	if 彩蛋配置表.is_empty():
		return
	var 候选: Array = []
	for r in 彩蛋配置表:
		if r.get("type", "") != "quest":
			continue
		if r.get("trigger_param", "") != scene:
			continue
		if not 彩蛋启用否(r.get("egg_id", "")):
			continue
		候选.append(r)
	if 候选.is_empty():
		return
	if randf() >= 0.03:
		return
	var 选中: Dictionary = 候选[randi() % 候选.size()]
	触发点击彩蛋(选中.get("egg_id", ""))

# 置临时增益（当日生效；dim=无 则无数值）
func _置彩蛋临时增益(c: Dictionary):
	var dim: String = c.get("buff_dim", "无")
	var pct: float = float(c.get("buff_pct", "0")) / 100.0
	if dim == "无" or pct <= 0:
		return
	彩蛋临时增益[dim] = {"pct": pct, "到期日": 累计游戏日 + 1}

# 运行时加法管线（接入产出/修炼计算，封顶单上限兜底）
func 彩蛋产出加成() -> float:
	var g: Dictionary = 彩蛋临时增益.get("产出", {})
	if g.is_empty() or g.get("到期日", 0) < 累计游戏日:
		return 0.0
	return min(g.get("pct", 0.0), 彩蛋单上限)

func 彩蛋修炼加成() -> float:
	var g: Dictionary = 彩蛋临时增益.get("修炼", {})
	if g.is_empty() or g.get("到期日", 0) < 累计游戏日:
		return 0.0
	return min(g.get("pct", 0.0), 彩蛋单上限)

func 推演至现在() -> String:
	推演日志.clear()
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
	# P1：宗门加成统一加法叠加，总上限 +100%（×2），杜绝乘性无限叠加（境界膨胀根因）
	var 灵脉加成pct: float = min(门派等级, 10) * 0.02
	if 累计游戏日 < 气运到期日:
		灵脉加成pct += 气运修炼加成
	var 负责人修炼pct: float = 汇总负责人全局buff().get("修炼", 0.0)
	var 藏经阁pct: float = max(0.0, _藏经阁修炼乘区() - 1.0)
	var 大阵pct: float = max(0.0, _宗门大阵修炼乘区() - 1.0)
	var 宗门加成pct: float = clamp(灵脉加成pct + 负责人修炼pct + 藏经阁pct + 彩蛋修炼加成() + 大阵pct, 0.0, 1.0)
	var 修炼乘区: float = 1.0 + 宗门加成pct
	# 1. 弟子修炼 / 升层 / 突破 / 月度事件（10层体系双轨播报）
	var 待坐化: Array[Disciple] = []
	for d in 弟子列表:
		var 旧境界: String = d.境界
		var 旧层数: int = d.层数
		d.推进修炼(日, 修炼乘区)
		var 新层数: int = d.层数

		# 突破播报（境界变化 = 大事，高优先级）
		if d.境界 != 旧境界:
			周期评分.记突破()   # P1：突破计入周期评分
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
		# D5④ 机缘钩子：月度推演独立滚动（绕开 _今日奇遇次数 日配额），得奖励则并入推演日志
		var 机缘文案: String = _尝试机缘(d)
		if 机缘文案 != "":
			_加推演条目(机缘文案, ET_QUEST, PRIO_NORMAL, {"弟子": d.姓名, "机缘": true})
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
		# 终局机制 P0：寿元坐化——年龄达当前境界寿元上限则标记，循环后统一处理（移除+归还+纪事）
		if d.年龄 >= d.寿元:
			待坐化.append(d)
	_新手_评估后续()   # 状态型 newbie（弟子层数达标）月内预判
	# 2. 资源建筑产出
	处理坐化(待坐化)   # P0 终局：寿元耗尽弟子离场（灵兽/装备归还宗门、纪事入册）
	_资源建筑产出()
	# S1 批2：任期政绩月度累积（须在主事在任、资源产出之后）
	_累计任期政绩()
	# 2.5 建筑被动结算（阶段2：每月概率事件；资源产出之后、推演条目汇总之前）
	_建筑被动结算()
	# 3. 宗门事件（约每月一次）
	# S1 批5-A 端口：凡人事件池 config/凡人事件.csv 待建（权重接入本区；本批仅标端口，不写事件逻辑）
	if randf() < 0.5:
		_加推演条目("【宗门】" + Lore.取宗门事件(), ET_SECT, PRIO_NORMAL)
		_加声望(5)
	# 4. 育英堂常驻自动招收（练气候补）：由原「月度 30%」改为「季度触发」，基础概率 + 门派等级缩放
	#   按本次推演跨越的月份逐月判定，兼容 日=30/365/7 等不同粒度（度假式快进不漏触发）
	var 招徒周期: int = _校准整("招徒周期月", 3)
	var 招徒起月: int = int(累计游戏日 / 30)
	var 招徒止月: int = int((累计游戏日 + 日) / 30)
	for 招徒月 in range(招徒起月, 招徒止月):
		if 招徒月 % 招徒周期 != 0:
			continue
		var 招徒概率: float = _校准浮("招徒基础概率", 0.75) + (门派等级 - 1) * _校准浮("招徒等级缩放", 0.02)
		招徒概率 = clamp(招徒概率, 0.0, _校准浮("招徒概率上限", 0.95))
		if randf() < 招徒概率:
			var n: int = 1 + (1 if randf() < 0.3 else 0)
			for i in n:
				var nd := Disciple.new()
				nd.堂口 = "yuying"   # 育英堂候补
				弟子列表.append(nd)
	# 4.5 随机事件（半年触发，单次奖励放大 系数 倍；原月度触发已移至此，按跨越月份逐月判定）
	var 事件周期: int = _校准整("随机事件周期月", 6)
	var 事件累计快照: int = 累计游戏日
	for 事件月 in range(招徒起月, 招徒止月):
		if 事件月 % 事件周期 != 0:
			continue
		累计游戏日 = 事件累计快照 + 事件月 * 30   # 让冷却/纪事落在对应月份，避免同刻冷却互相抵消
		_尝试随机事件()
	累计游戏日 = 事件累计快照
	# 5. 御兽堂推进孵化
	推进孵化(日)
	处理兑换队列()        # T03：自动兑换队列周期执行
	出战灵兽月度养成()    # T13+T14：出战灵兽每月+1级/+2忠诚，库存-1忠诚
	# 6. 更新门派
	更新门派()
	# === S1 扩展端口（当前空操作，S1 赛季实现；见 S1-S2功能储备与扩展端口清单.md）===
	_结算俸禄_S1()            # 俸禄/福利按月发放，扣公库
	_结算运维成本_S1()        # D1 宗门运维成本（刚性耗），接线 global_cost_rate 阀门
	_结算负面事件_S1()        # D3 负面影响经济侧（S1-P0 批次三）：negative_event.csv + 经济阀门.csv neg_*
	_可能触发特殊登门_S1()    # 声望阈值→特殊弟子主动投奔
	_结算香火_S1()            # 凡人香火月度结算（当前空桩，S1 批5-A）
	_确保字派_S1()            # S1 批5-B：旧档首次进入自动生成字派序列并持久化
	_检查正邪解锁_S1()         # S1 批5-C：正邪路线解锁检测（空桩，当前仅读门派等级+七载大考标记）
	_结算大阵耐久_S1()    # S1 批6-A：宗门大阵耐久月度结算（当前空桩，[PLACEHOLDER]）
	累计游戏日 += 日
	_推进任务系统(日)        # S0：每日刷日常 / 每7日刷周常 / 月度随机概率事件
	# P1：年结周期评分（游戏年 = 365 日）；支持单次大跨度推演结算多年
	while 累计游戏日 - 上次结算年 >= 365:
		上次结算年 += 365
		_年结评分()

# P1：年结评分（由 推演一月 跨 365 日边界触发）
func _年结评分():
	var 当前总战力: int = 0
	for d in 弟子列表:
		当前总战力 += d.实时战力()
	var 卡: Dictionary = 周期评分.结算(门派等级, {
		"资源产能": 预估月产出(),
		"灵石增量": 灵石 - 年始灵石,
		"总战力增量": 当前总战力 - 年始总战力,
	})
	var 评级名: String = 卡["评级"]
	var 发: Dictionary = _发放周期奖励(评级名)
	卡["年度发"] = 发["年度发"]
	卡["入池"] = 发["入池"]
	卡["平移法宝"] = 发["平移法宝"]
	最新周期评级卡 = 卡
	# 岁末考评轻量纪事（归入「日常庶务」分类，保证每年成长可回溯）
	var 岁末评语: String = _七载大典文案(评级名).get("评语", "")
	宗门纪事.append({"日": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "岁末考评",
		"文案": "岁末考评裁定 %s：%s" % [评级名, 岁末评语], "category": "日常庶务"})
	年始灵石 = 灵石
	年始总战力 = 当前总战力
	# 七载双周期：跨 2555 日（7×365）边界触发七载大考集中结算
	if _校准开("双周期评级启用", true):
		var 七载周期日: int = _校准整("七载周期年", 7) * 365
		if 累计游戏日 - 上次七载日 >= 七载周期日:
			上次七载日 = 累计游戏日
			_七载大考()

# P1：周期评定奖励（梯度灵石 + S 级及以上追加上品法宝赐掌门）
# 双周期评级启用（默认）：年度发放 70%，剩余 30% 平移入「七载奖励池」于七载大典集中结算；
#   S 级及以上高阶法宝留待七载大典一次性赐下。全程零新增资源（7 年总量 = 7 × 原年度）。
# 双周期评级关闭（回退）：维持原年度实时全额发放，行为与原版完全一致。
# 返回值供 UI 展示：{年度发, 入池, 平移法宝}
func _发放周期奖励(评级: String) -> Dictionary:
	var 灵石奖励表: Dictionary = {"D": 0, "C": 200, "B": 500, "A": 1000, "A+": 1800, "S": 3000, "SS": 5000, "SSS": 8000}
	var 奖: int = int(灵石奖励表.get(评级, 0))
	if 奖 <= 0:
		return {"年度发": 0, "入池": 0, "平移法宝": false}
	var 等级平移: bool = 评级 in ["S", "SS", "SSS"]
	if not _校准开("双周期评级启用", true):
		# 回退：原年度实时全额发放
		灵石 += 奖
		_加推演条目("【宗门】周期评定 %s，论功行赏，灵石+%d。" % [评级, 奖], ET_SECT, PRIO_NORMAL, {})
		if 等级平移 and not 弟子列表.is_empty():
			var 宝: Item = _造低阶物品("fabao", "上品")
			弟子列表[0].背包.append(宝)
			_加推演条目("【宗门】评定 %s，赐掌门上品法宝【%s】。" % [评级, 宝.名称], ET_LOOT, PRIO_HIGH, {})
		return {"年度发": 奖, "入池": 0, "平移法宝": 等级平移}
	# 双周期模式：年度 70% 即时 + 30% 入池；高阶法宝平移七载
	var 年度发: int = int(奖 * _校准浮("年度奖励占比", 0.70))
	var 入池: int = 奖 - 年度发
	灵石 += 年度发
	_加推演条目("【宗门】岁末考评 %s，论功行赏，灵石+%d（余 %d 并入七载大典）。" % [评级, 年度发, 入池], ET_SECT, PRIO_NORMAL, {})
	if 入池 > 0:
		七载奖励池 += 入池
	if 等级平移 and not 弟子列表.is_empty():
		var 宝: Item = _造低阶物品("fabao", "上品")
		七载待发掉落.append({"类型": 宝.类别, "品阶": 宝.品阶, "名称": 宝.名称})
		_加推演条目("【宗门】评定 %s，上品法宝【%s】留待七载大典赐下。" % [评级, 宝.名称], ET_LOOT, PRIO_HIGH, {})
	return {"年度发": 年度发, "入池": 入池, "平移法宝": 等级平移}

# P1：七载大典集中结算（双周期评级核心）
# 一次性发放 7 年累积的「七载奖励池」（=7×30% 年度灵石）+ 历年平移的高阶法宝，
# 并将「门派等级目标」正式生效为门派等级。全程零新增资源。
# 七载大典 / 岁末考评 仪式文案（纯展示，零数值）。按评级分 8 档差异化包装。
func _七载大典文案(评级: String) -> Dictionary:
	# WAVE-A #1：优先查 config/七载大典文案.csv（按评级匹配）；命中返回配置文案。
	# 缺档/缺文件回退硬编码默认文案（不报错、不崩溃）。
	var 配置: Dictionary = _七载大典文案表()
	if 配置.has(评级):
		return 配置[评级]
	return _七载大典文案_默认(评级)

# 懒加载 七载大典文案.csv → {评级: {标题,开篇,收尾,评语}}（缺文件/缺档不报错）
var _七载大典文案缓存: Dictionary = {}
var _七载大典文案已加载: bool = false
func _七载大典文案表() -> Dictionary:
	if _七载大典文案已加载:
		return _七载大典文案缓存
	_七载大典文案已加载 = true
	var file: FileAccess = FileAccess.open("res://config/七载大典文案.csv", FileAccess.READ)
	if file == null:
		return _七载大典文案缓存
	file.get_csv_line()  # 跳过 header
	while not file.eof_reached():
		var parts: PackedStringArray = file.get_csv_line()
		if parts.size() < 5:
			continue
		var k: String = parts[0].strip_edges()
		if k.is_empty():
			continue
		_七载大典文案缓存[k] = {
			"标题": parts[1].strip_edges(),
			"开篇": parts[2].strip_edges(),
			"收尾": parts[3].strip_edges(),
			"评语": parts[4].strip_edges(),
		}
	return _七载大典文案缓存

# 硬编码默认文案（与七载大典文案.csv 内容一致，作为回退；零数值）
func _七载大典文案_默认(评级: String) -> Dictionary:
	var 表: Dictionary = {
		"D":   {"标题": "七载考评·守拙", "开篇": "根基尚浅，然守拙归真，来日方长。", "收尾": "第%d七载，宗门稳守本心，来年期可待。", "评语": "岁末考评守拙，根基虽浅，来日方长。"},
		"C":   {"标题": "七载考评·筑基", "开篇": "百事初立，稳中有进，假以时日可期大成。", "收尾": "第%d七载，宗门筑基渐稳，来年再图进取。", "评语": "岁末考评筑基，稳中有进，来年可期。"},
		"B":   {"标题": "七载考评·兴业", "开篇": "产业渐丰，弟子用命，宗门气象一新。", "收尾": "第%d七载，宗门兴业有成，道途愈宽。", "评语": "岁末考评兴业，基业渐丰，气象一新。"},
		"A":   {"标题": "七载考评·昌盛", "开篇": "七载经营，宗门昌盛，灵脉日盛。", "收尾": "第%d七载，宗门昌盛绵延，声望渐起。", "评语": "岁末考评昌盛，灵脉日盛，声望渐起。"},
		"A+":   {"标题": "七载考评·隆盛", "开篇": "贤才云集，基业隆盛，已具大宗气象。", "收尾": "第%d七载，宗门隆盛日彰，名动一方。", "评语": "岁末考评隆盛，贤才云集，名动一方。"},
		"S":   {"标题": "七载大考·宗门鼎盛", "开篇": "七载积淀，道基再固，宗门鼎盛，四海仰止。", "收尾": "第%d七载，宗门鼎盛，道途至此再进一步。", "评语": "七载大考鼎盛，道基再固，四海仰止。"},
		"SS":   {"标题": "七载大考·威震一方", "开篇": "七载砥砺，威震一方，诸宗来朝，灵脉通玄。", "收尾": "第%d七载，宗门威名远播，基业永固。", "评语": "七载大考威震一方，诸宗来朝，基业永固。"},
		"SSS":   {"标题": "七载大考·道途无双", "开篇": "七载问道，道途无双，太玄宗之名，响彻修真界。", "收尾": "第%d七载，太玄宗立不朽之基，万世流芳。", "评语": "七载大考道途无双，太玄之名响彻修真界。"},
	}
	return 表.get(评级, 表["C"])
func _七载大考():
	var 晋升: int = 门派等级目标 if 门派等级目标 > 门派等级 else 0
	var 大典灵石: int = 七载奖励池
	var 大典法宝: int = 七载待发掉落.size()
	var 序号: int = int(累计游戏日 / (_校准整("七载周期年", 7) * 365))
	var 评级: String = 最新周期评级卡.get("评级", "C")
	var 文: Dictionary = _七载大典文案(评级)
	# 基础纪事：每次七载必生成 1 条；S 级以上归「宗门大事件」，其余归「宗门岁纪」
	var 七载分类: String = "宗门大事件" if 评级 in ["S", "SS", "SSS"] else "宗门岁纪"
	宗门纪事.append({"日": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "七载大考",
		"文案": "第%d七载宗门大考礼成（本年评定 %s），论功行赏、重宝颁赐，宗门至此再进一步。" % [序号, 评级],
		"category": 七载分类})
	if 晋升 > 0:
		宗门纪事.append({"日": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "宗门晋升",
			"文案": "太玄宗于第 %d 年七载大典正式晋为 Lv.%d 宗门，辖地扩张，弟子云集。" % [int(累计游戏日 / 365), 门派等级目标],
			"category": "宗门大事件"})
		_加推演条目("【宗门】七载大典！太玄宗晋升至 Lv.%d！灵脉修炼速度 +%d%%" % [门派等级目标, 门派等级目标 * 2], ET_SECT, PRIO_HIGH, {"宗门等级": 门派等级目标})
		门派等级 = 门派等级目标
	if 大典灵石 > 0:
		灵石 += 大典灵石
		_加推演条目("【宗门】七载大典论功行赏，灵石+%d（历年岁末之积）。" % 大典灵石, ET_SECT, PRIO_HIGH, {})
		七载奖励池 = 0
	if 大典法宝 > 0 and not 弟子列表.is_empty():
		for 掉落 in 七载待发掉落:
			var 宝: Item = _造低阶物品(掉落.get("类型", "fabao"), 掉落.get("品阶", "上品"))
			弟子列表[0].背包.append(宝)
			_加推演条目("【宗门】七载大典赐掌门上品法宝【%s】。" % 宝.名称, ET_LOOT, PRIO_HIGH, {})
		七载待发掉落 = []
	七载大典摘要 = {"灵石": 大典灵石, "法宝数": 大典法宝, "晋升至": 晋升, "序号": 序号, "评级": 评级}
	七载大典待展示 = true
	_加推演条目("【宗门】七载宗门大考礼成，万象更新。", ET_SECT, PRIO_NORMAL, {})

# === S1 端口：俸禄/福利按月结算（当前空操作桩）===
# 调用位置：推演一月 月循环（紧接 _可能触发特殊登门_S1 之前）。
# 入参：无（读取全局 灵石 / 弟子列表 / 宗门贡献）
# 返回值：void；S1 实装后副作用：公库扣款 + 按身份/阶位发放俸禄 + 欠薪→忠诚↓→叛逃
# 依赖：货币/贡献系统（见 §二 俸禄福利）。状态：空操作，零副作用，八道闸门安全。
func _结算俸禄_S1() -> void:
	pass

var _经济基线缓存: Dictionary = {}   # D1：经济基线.csv 缓存（clamp 边界来源，R5 非硬编码）

# ============ D3 负面影响经济侧（S1-P0 批次三 · 数据对齐版）============
# 轻量管理器状态（运行时瞬时，不持久化；规格 design/08-功能提案/12-D3实现规格_数据对齐版.md §8）
var _经济阀门缓存: Dictionary = {}      # 经济阀门.csv → {阀门: {系数,开关,说明}}（懒加载）
var _负面事件缓存: Array = []           # negative_event.csv 行缓存（懒加载）
var _本月负面已触发: Dictionary = {}     # 本月各 event_id 触发次数（月度重置）
var _本月灵石冲击: float = 0.0          # 本月负面事件灵石冲击累计（月末截断至 62）
var _弟子负面属性累计: Dictionary = {}   # 纯属性惩罚累计（零副作用占位；键=弟子姓名）
var _坊市负面卖价下限: float = 1.0       # 声望外部类浅联动下限（P0 neg_reputation=0，默认不触发）
# D3 开关缓存（由 _加载负面开关_S1 从 经济阀门.csv 读取；默认值对齐规格 §6 默认安全态）
var _neg_global: bool = false
var _neg_res_build: bool = false
var _neg_disciple: bool = false
var _neg_reputation: bool = false
var _neg_grade_perm: bool = false

# === S1 批6-D1：宗门运维成本（刚性耗；ECON-02 §2.2 校准，标准局≈305）===
# 接线 global_cost_rate 阀门：对 -刚性耗 单独调 EconomyBalance.平衡()（per-delta 施加，
# 全场景生效，不只赤字局；与 period_settlement.gd 末次 final 平衡() 双调用，正常配置下均恒等）。
# R5：下限/上限从 config/经济基线.csv 读（非硬编码 293/318）。
# 欠俸/忠诚链路：本阶段留 stub（引用 GDD-宗门经营 §五.1），不强制实现。
func _结算运维成本_S1() -> void:
	var 基线: Dictionary = _读经济基线()
	var 下限: float = float(基线.get("标准局月耗_下限", "293"))
	var 上限: float = float(基线.get("标准局月耗_上限", "318"))
	var c4: float = 0.0
	for d in 弟子列表:
		c4 += 4.5 * _身份俸禄倍率(d.身份)   # 普通1.0 / 执事1.5 / 长老2.0
	var c5: float = 3.0 * 堂口列表.size()
	var c6: float = 0.73 * 弟子列表.size()
	var c7: float = 0.375 * 弟子列表.size()
	var 刚性耗: float = c4 + c5 + c6 + c7          # 标准局≈305
	# R5：clamp 到 [下限, 上限]（读 CSV，非硬编码）
	刚性耗 = clamp(刚性耗, 下限, 上限)
	# R2 per-delta：对 -刚性耗 单独调 平衡()（raw<0 → ×全局消耗系数，±15% 钳制）
	var _平衡器 := EconomyBalance.new()
	var 实付: float = _平衡器.平衡(-刚性耗)             # 实付为负
	灵石 -= int(round(-实付))                      # 取绝对值扣公库

# D1 运维成本：弟子身份→俸禄倍率（普通1.0 / 执事1.5 / 长老2.0）
func _身份俸禄倍率(身份: String) -> float:
	match 身份:
		"长老":
			return 2.0
		"执事":
			return 1.5
		_:
			return 1.0   # 普通 / 外门 / 内门弟子 / 核心弟子 / 亲传弟子 / 堂主 / 供奉 → 1.0

# 读取 config/经济基线.csv 为 {锚点: 数值}（D1 运维成本 clamp 边界来源，R5 非硬编码）
func _读经济基线() -> Dictionary:
	if not _经济基线缓存.is_empty():
		return _经济基线缓存
	var 路径 := "res://config/经济基线.csv"
	if not FileAccess.file_exists(路径):
		return {}
	var f: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if f == null:
		return {}
	f.get_line()   # 跳表头（含可能的 BOM，数据行不含）
	while not f.eof_reached():
		var 行: String = f.get_line().strip_edges()
		if 行 == "":
			continue
		var 列: PackedStringArray = 行.split(",")
		if 列.size() >= 2:
			_经济基线缓存[列[0].strip_edges()] = 列[1].strip_edges()
	f.close()
	return _经济基线缓存

# ============ D3 负面影响经济侧（S1-P0 批次三）运行时管理器 ============
# 消费 config/negative_event.csv（_读负面事件表）+ config/经济阀门.csv（neg_* 开关簇 + event_damage_rate）
# 激活 DORMANT：建筑被动_负面事件减免（L247，仅 res_build 灵石扣除处乘 (1+本值)）
# 灵石流向：与 _结算运维成本_S1 一致（经 EconomyBalance.平衡() 后扣公库；平衡() 消费 event_damage_rate=1.0）
# 规格锚：design/08-功能提案/12-D3实现规格_数据对齐版.md §8 伪代码落地

# —— UTF-8 BOM 容错（DestinyDataLoader._read_csv 用 get_csv_line，首列键/值可能带 \ufeff）——
func _CSV去BOM(路径: String) -> Array:
	var out: Array = []
	for r in DestinyDataLoader._read_csv(路径):
		var d: Dictionary = {}
		for k in r.keys():
			var nk: String = str(k).replace("\ufeff", "")
			var v = r[k]
			if v is String:
				v = v.replace("\ufeff", "")
			d[nk] = v
		out.append(d)
	return out

# —— 配置懒加载（复用项目现有 CSV 解析惯例；_坊市表() 风格）——
func _读经济阀门表() -> Dictionary:
	if not _经济阀门缓存.is_empty():
		return _经济阀门缓存
	for r in _CSV去BOM("res://config/经济阀门.csv"):
		var 名: String = r.get("阀门", "")
		if 名 != "":
			_经济阀门缓存[名] = r
	return _经济阀门缓存

func _读负面事件表() -> Array:
	if not _负面事件缓存.is_empty():
		return _负面事件缓存
	_负面事件缓存 = _CSV去BOM("res://config/negative_event.csv")
	return _负面事件缓存

func _阀门开关(表: Dictionary, 键: String, 默认: int) -> bool:
	var r: Dictionary = 表.get(键, {})
	return int(r.get("开关", 默认)) != 0

# —— 总闸优先判定（neg_global 一键回退纯正向，即便分闸=1）——
func _负面类别生效(类别: String) -> bool:
	if not _neg_global:
		return false
	match 类别:
		"资源建筑":
			return _neg_res_build
		"弟子人员":
			return _neg_disciple
		"声望外部":
			return _neg_reputation
		"品级权限":
			return _neg_grade_perm
	return false

# —— punish_type → 四分类（兜底归类；规格 §1/§8）——
func _punish类别(pt: String) -> String:
	match pt:
		"矿石", "灵草", "丹材":
			return "资源建筑"
		"心魔", "修为", "忠诚", "心境", "道心", "气血":
			return "弟子人员"
		"卖价":
			return "声望外部"
		"权益回收":
			return "品级权限"
		"灵石":
			return "弟子人员"   # 货币载体，默认归弟子类
		_:
			return ""

# —— 月度结算接入点（推演一月 S1 区，紧接 _结算运维成本_S1 之后）——
func _结算负面事件_S1() -> void:
	_加载负面开关_S1()
	_坊市负面卖价下限 = 1.0
	if not _neg_global:
		return
	_本月负面已触发.clear()
	_本月灵石冲击 = 0.0
	for 行 in _读负面事件表():
		var 概率: float = float(行.get("base_prob", "0"))
		if randf() >= 概率:
			continue
		var eid: String = 行.get("event_id", "")
		var 上限次: int = int(行.get("monthly_limit", "1"))
		if _本月负面已触发.get(eid, 0) >= 上限次:
			continue
		_负面事件结算(行)
	_负面总冲击卡位()

# —— 单事件结算（双槽 punish_type/punish_value）——
func _负面事件结算(行: Dictionary) -> void:
	var 后果: Array = []
	var 属资源建筑: bool = (行.get("punish_type_1", "") in ["矿石", "灵草", "丹材"]) or (行.get("punish_type_2", "") in ["矿石", "灵草", "丹材"])
	for slot in ["1", "2"]:
		var 类别: String = _punish类别(行.get("punish_type_" + slot, ""))
		if not _负面类别生效(类别):
			continue
		var pt: String = 行.get("punish_type_" + slot, "")
		var pv: float = float(行.get("punish_value_" + slot, "0"))
		if pt == "无" or pv <= 0:
			continue
		match pt:
			"灵石":
				var 扣: float = pv
				if 属资源建筑:   # 激活 DORMANT 建筑被动_负面事件减免（资源建筑类事件，含其灵石机会成本）
					扣 = max(0.0, 扣 * (1.0 + 建筑被动_负面事件减免))
				_本月灵石冲击 += 扣
				后果.append("灵石-%d" % int(round(扣)))
			"矿石":
				矿石 = max(0, 矿石 - int(pv))
				后果.append("矿石-%d" % int(pv))
			"灵草":
				灵草 = max(0, 灵草 - int(pv))
				后果.append("灵草-%d" % int(pv))
			"卖价":
				if _neg_reputation:   # 仅开启时浅联动（P0 默认 0，跳过；D3 不深联动）
					_坊市负面卖价下限 = min(_坊市负面卖价下限, pv)
			"权益回收":
				if _neg_grade_perm:
					_权益回收惩处(pv, 后果)   # pv = 治理失序罚金（20）
			"心魔", "修为", "忠诚", "心境", "道心", "气血":
				_施加弟子属性惩罚(pt, int(pv))   # 纯属性，无经济副作用
	var eid: String = 行.get("event_id", "")
	_本月负面已触发[eid] = _本月负面已触发.get(eid, 0) + 1
	if not 后果.is_empty():
		_加推演条目("【负面】%s：%s" % [行.get("event_name", eid), "、".join(后果)], ET_SECT, PRIO_NORMAL, {"事件": eid})

# —— 品级权限类惩处（D4 本批：权益回收 = 罢免阶位 + 治理失序罚金）——
func _权益回收惩处(罚金: float, 后果: Array) -> void:
	_本月灵石冲击 += 罚金                       # 经 _负面总冲击卡位() 卡位后扣公库
	后果.append("治理失序罚金-%d" % int(round(罚金)))
	var 候选: Array = 弟子列表.filter(func(d): return d.阶位 != "无")
	if not 候选.is_empty():
		var 目标: Disciple = 候选[randi() % 候选.size()]
		罢免阶位(目标)                          # 既有 setter（L2676）：降阶位一级 + 纪事

# —— 月度总冲击卡位（硬卡 Σ≤62，不转负盈余）——
func _负面总冲击卡位() -> void:
	# 62 = 经济基线.csv 冲击上限_灵石 = floor(17%×366)（ECON-02 §2.4；镜像 pre_f5 Layer B3/D）
	var 上限: float = 62.0
	_本月灵石冲击 = min(_本月灵石冲击, 上限)
	if _本月灵石冲击 <= 0.0:
		return
	# 灵石流向与 _结算运维成本_S1 一致：经 EconomyBalance.平衡()（消费 event_damage_rate=1.0）后扣公库
	var _平衡器 := EconomyBalance.new()
	var 实付: float = _平衡器.平衡(-_本月灵石冲击)
	灵石 -= int(round(-实付))

# —— 纯属性惩罚：无经济副作用；记入 Game 级按弟子累计字典（零副作用占位，规格 §8）——
# 当前 Disciple 未建模 心魔/忠诚/心境/道心/气血 独立字段，故以累计字典承载，不影响经济/存档结构。
func _施加弟子属性惩罚(pt: String, pv: int) -> void:
	if 弟子列表.is_empty() or pv <= 0:
		return
	var 目标: Disciple = 弟子列表[randi() % 弟子列表.size()]
	var 名: String = ""
	if 目标.姓名 != "":
		名 = 目标.姓名
	else:
		名 = str(目标.get_instance_id())
	if not _弟子负面属性累计.has(名):
		_弟子负面属性累计[名] = {}
	_弟子负面属性累计[名][pt] = int(_弟子负面属性累计[名].get(pt, 0)) - pv

# —— 从 经济阀门.csv 加载 D3 开关簇（neg_*；event_damage_rate 由平衡() 读取，本处不重复）——
func _加载负面开关_S1() -> void:
	var 表: Dictionary = _读经济阀门表()
	_neg_global     = _阀门开关(表, "neg_global", 0)
	_neg_res_build  = _阀门开关(表, "neg_res_build", 1)
	_neg_disciple   = _阀门开关(表, "neg_disciple", 1)
	_neg_reputation = _阀门开关(表, "neg_reputation", 0)
	_neg_grade_perm = _阀门开关(表, "neg_grade_perm", 0)

# === S1 端口：声望阈值触发特殊弟子主动投奔（当前空操作桩）===
# 调用位置：推演一月 月循环（紧接 _结算俸禄_S1 之后）。
# 入参：无（读取全局 声望 / 弟子列表 / 命格池）
# 返回值：void；S1 实装后：若 声望 >= 阈值 且 randf() 命中，生成带专属命格/特殊灵根的特殊弟子并 append 入 弟子列表 + 写纪事
# 依赖：声望系统、命格池（见 §三 特殊登门事件）。状态：空操作，零副作用。
func _可能触发特殊登门_S1() -> void:
	pass

# === S1 批5-A：凡人香火月度结算（当前空操作桩）===
# 调用位置：推演一月 月循环（紧接 _可能触发特殊登门_S1 之后）。
# 入参：无（读取全局 香火值 / 信徒数 / 凡人城镇）。
# 返回值：void；S1 实装后：按月累加香火/信徒、重算月产预估与增益档、产出计入 §11.9 财政。
# 依赖：数值 [PLACEHOLDER]，真机校准。状态：空操作，零副作用。
func _结算香火_S1() -> void:
	pass

# === S1 批5-B：字派序列生成（旧档缺字派 → 首次进入生成并持久化）===
# 调用位置：推演一月 月循环 S1 区（紧接 _结算香火_S1 之后）；新弟子创建（举办测灵根 / 招收弟子）前置调用。
# 规则：从候选池随机取 5–10 字生成 辈分字派；辈分间隔/顺延规则 [PLACEHOLDER]（GDD §⑨），本批仅落字段+生成。
func _确保字派_S1() -> void:
	if not 辈分字派.is_empty():
		return
	var 候选池: Array = ["玄", "清", "道", "明", "悟", "真", "常", "寂", "虚", "静", "渊", "徽"]
	候选池.shuffle()
	var n: int = randi_range(5, 10)
	辈分字派.clear()
	for i in n:
		辈分字派.append(候选池[i])

# === S1 批5-C：正邪路线解锁检测（双重条件）===
# 调用位置：推演一月 月循环 S1 区（紧接 _确保字派_S1 之后）。
# 解锁 = 门派等级 >= 3 且 已完成首次七载大考（用 上次七载日 > 0 近似：七载大典首次结算后该字段非零）。
# 当前空桩，仅读标记；路线增益/事件权重/专属内容 [PLACEHOLDER]（GDD §⑨）。
func _检查正邪解锁_S1() -> bool:
	return 门派等级 >= 3 and 上次七载日 > 0

# === S1 批6-A：宗门大阵耐久月度结算（纯经营桩，挂 推演一月 S1 区）===
# 当前主阵每日扣耐久（灵石/灵草，[PLACEHOLDER] 数值待真机校准）；耗尽→全域效果×0.5（批6-B L1146 接入时判）。
# 当前为空操作桩：仅预留调用端口，八道闸门安全，不触碰战斗。
func _结算大阵耐久_S1() -> void:
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
		var 原因池: Array[String] = [
			"寻宝未获，空手而归",
			"遭遇迷障，不得不撤",
			"探寻无果，徒劳往返",
			"灵气稀薄，无功而返",
			"妖兽出没，被迫绕行",
			"天候骤变，折返避祸",
			"路径生疏，迷失林间",
			"所获之物品相不佳，弃之而归",
		]
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
# 当前月份（30游戏日=1月），用于奇遇防重复冷却
func _当前月() -> int:
	return int(累计游戏日 / 30)

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
	if _今日奇遇次数 >= _校准整("奇遇日上限", 5):
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
	# S0 P0：奇遇防重复冷却（月份维度，3个月）
	if quest_cooldown.has(eid) and _当前月() < quest_cooldown[eid]:
		return 结果
	_今日奇遇次数 += 1
	_单条冷却记录[eid] = 累计游戏日
	quest_cooldown[eid] = _当前月() + 3
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

# ============ D5④ 机缘钩子（B1 拍板：经营层零战斗，≈20行）============
# 挂在月度推演（_弟子月度事件 之后），绕开 _今日奇遇次数 日配额。
# 从事件池筛 trigger_scene=机缘 + 门派等级/境界门槛 + 冷却，对每条事件
# 独立 roll：randf() < trigger_weight/100，精确达成 碎片×3=15% / 阵图×1=5%
#（两条独立判定，可同时触发；命中调 结算奇遇奖励，并按 event_id 打月份+单条冷却防同日双发）。
func _尝试机缘(d: Disciple) -> String:
	if d == null:
		return ""
	Quest._确保csv加载()
	var 摘要: String = ""
	for evt in Quest._csv事件池:
		if evt.get("trigger_scene", "") != "机缘":
			continue
		if int(evt.get("unlock_sect_level", 1)) > 门派等级:
			continue
		var d_idx: int = Quest._境界序.find(d.境界)
		var e_idx: int = Quest._境界序.find(evt.get("unlock_realm", "练气"))
		if e_idx < 0 or d_idx < 0 or e_idx > d_idx:
			continue
		var eid: String = evt.get("event_id", "")
		if quest_cooldown.has(eid) and _当前月() < quest_cooldown[eid]:
			continue
		var cd_hour: int = int(evt.get("cooldown_hour", 0))
		if cd_hour > 0 and _单条冷却记录.has(eid):
			if 累计游戏日 - _单条冷却记录[eid] < ceil(cd_hour / 24.0):
				continue
		var tw: float = float(evt.get("weight", 0))
		if tw <= 0 or randf() >= tw / 100.0:
			continue
		var q: Dictionary = {
			"文案": evt.get("event_content", ""),
			"稀有度": evt.get("rarity", "普通"),
			"需干预": false,
			"奖励": null,
			"event_name": evt.get("event_name", ""),
			"event_type": evt.get("event_type", ""),
			"trigger_scene": evt.get("trigger_scene", ""),
			"opt1_desc": evt.get("opt1_desc", ""),
			"opt1_reward": evt.get("opt1_reward", ""),
			"opt1_punish": evt.get("opt1_punish", ""),
			"opt2_desc": evt.get("opt2_desc", ""),
			"opt2_reward": evt.get("opt2_reward", ""),
			"opt2_punish": evt.get("opt2_punish", ""),
			"opt3_desc": evt.get("opt3_desc", ""),
			"opt3_reward": evt.get("opt3_reward", ""),
			"opt3_punish": evt.get("opt3_punish", ""),
			"base_value": float(evt.get("base_value", 0.0)),
			"level_factor": float(evt.get("level_factor", 0.15)),
			"min_value": float(evt.get("min_value", 0.0)),
			"max_value": float(evt.get("max_value", 999.0)),
			"weight_decay": float(evt.get("weight_decay", 0.7)),
			"cooldown_hour": cd_hour,
		}
		if evt.get("rarity", "普通") != "普通":
			_加声望(randi_range(10, 20))
		quest_cooldown[eid] = _当前月() + 3
		_单条冷却记录[eid] = 累计游戏日
		结算奇遇奖励(d, q)
		if not d.履历.is_empty():
			摘要 += d.履历.back()
	return 摘要

# ============ 奇遇奖励结构化解析（偏差#3 / B 部分，极简版）============
# 输入格式：物品key:数量，多奖励用 | 分隔。例："lingshi:200|lingcao:25"
# 支持 key：lingshi(灵石) / lingcao(灵草) / kuangshi(矿石) / dan_low(低阶丹药入背包)
# 设计铁律：解析失败降级为纯文本（并入摘要），不报错、不崩溃、不阻塞主流程。
# 返回：发放动作的中文摘要串（空串表示无有效发放）。
func _解析并发放奇遇奖励(d: Disciple, 文本: String) -> String:
	var 摘要 := ""
	if 文本.strip_edges() == "":
		return 摘要
	for 段 in 文本.split("|"):
		var 单: String = 段.strip_edges()
		if 单 == "":
			continue
		if not 单.contains(":"):
			摘要 += " " + 单
			continue
		var 部件: Array = 单.split(":", false)
		var key: String = 部件[0].strip_edges()
		if key in ["exp", "favor", "buff", "multi"]:
			摘要 += " " + _奇遇增益_中文描述(部件)
			continue
		if key == "item":
			var item_id: String = 部件[1].strip_edges() if 部件.size() > 1 else ""
			var cnt: int = 部件[2].strip_edges().to_int() if 部件.size() > 2 else 1
			if item_id == "" or cnt <= 0:
				摘要 += " " + 单
				continue
			var 名称: String = ""
			for _k in cnt:
				var it: Item = _按id造(item_id)
				if 名称 == "":
					名称 = it.名称
				d.获得物品(it)
			if 名称 != "":
				摘要 += " [url=item:%s]%s[/url]×%d" % [item_id, 名称, cnt]
			continue
		var 数量: int = 部件[1].strip_edges().to_int()
		if 数量 <= 0:
			摘要 += " " + 单
			continue
		match key:
			"lingshi":
				灵石 += 数量
				摘要 += " 灵石+%d" % 数量
			"lingcao":
				灵草 += 数量
				摘要 += " 灵草+%d" % 数量
			"kuangshi":
				矿石 += 数量
				摘要 += " 矿石+%d" % 数量
			"lingqi":
				灵气 += 数量
				摘要 += " 灵气+%d" % 数量
			"dan_low":
				for _i in 数量:
					d.获得物品(_造低阶物品("dan_yao", "凡阶"))
				摘要 += " [url=item:dan_low]聚气丹[/url]×%d" % 数量
			_:
				摘要 += " " + 单
	return 摘要

# ---- 第1项拍板：奇遇增益结构化语法预埋（S0 降级中文 / S1 按 effect_type 分发实际逻辑）----
# 标准格式（与 物品key:数量 对齐）：
#   exp:弟子范围:数值 / favor:弟子范围:数值 / buff:buff_id:数值 / multi:资源类型:倍率:时长
# S0 行为：识别后仅生成中文描述（剧情风味文本），不执行实际数值，保证不报错不崩档。
# S1 扩展：在 _应用奇遇增益 按类型分发真实逻辑，存量奇遇数据无需任何返工即可生效。
func _奇遇增益_中文描述(部件: Array) -> String:
	if 部件.size() < 2:
		return "(增益格式异常)"
	var 类型: String = 部件[0]
	match 类型:
		"exp":
			var 范围: String = _弟子范围文本(部件[1])
			var 值: int = 部件[2].to_int() if 部件.size() > 2 else 0
			return "(%s修为+%d)" % [范围, 值]
		"favor":
			var 范围: String = _弟子范围文本(部件[1])
			var 值: int = 部件[2].to_int() if 部件.size() > 2 else 0
			return "(%s好感+%d)" % [范围, 值]
		"buff":
			var bid: String = 部件[1]
			var 值: float = 部件[2].to_float() if 部件.size() > 2 else 0.0
			return "(全宗门%s提升%s)" % [_buff文本(bid), _百分比文本(值)]
		"multi":
			var 资源: String = _资源名词(部件[1])
			var 倍: float = 部件[2].to_float() if 部件.size() > 2 else 1.0
			var 时: int = 部件[3].to_int() if 部件.size() > 3 else 0
			return "(%s产出%.1f倍，持续%d个月)" % [资源, 倍, 时]
		_:
			return "(未知增益:%s)" % 部件[1]

func _弟子范围文本(范围: String) -> String:
	match 范围:
		"random_one": return "随机一名弟子"
		"all": return "全体弟子"
		_: return "指定弟子"

func _buff文本(bid: String) -> String:
	var 表: Dictionary = {
		"cultivate_speed": "修炼速度", "output": "产出", "exp_gain": "修为获取",
		"combat_power": "战力", "loot_rate": "掉落率", "sect_reputation": "宗门声望"
	}
	return 表.get(bid, bid)

func _资源名词(键: String) -> String:
	var 表: Dictionary = {
		"lingshi": "灵石", "lingcao": "灵草", "kuangshi": "矿石", "lingqi": "灵气"
	}
	return 表.get(键, 键)

func _百分比文本(值: float) -> String:
	return "%d%%" % int(round(值 * 100))

# 奇遇奖励结算（ADR-002 D5）：兜底期 q.奖励==null → 随机小奖励；csv 到位后按奖励结构结算。
# Sprint-02b：记录冷却时刻 + 宗门等级缩放接入
func 结算奇遇奖励(d: Disciple, q: Dictionary):
	_上次奇遇时刻 = Time.get_ticks_msec()
	var 摘要: String = "奇遇·" + str(q.get("稀有度", "普通"))
	if q.get("稀有度", "普通") in ["上品", "极品", "天品"]:   # P1：高稀有度奇遇计入周期评分
		周期评分.记稀有道具()

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
	# B 部分：结构化奖励（opt1_reward 字段，格式 物品key:数量）
	var 奖励文本: String = q.get("opt1_reward", "")
	if 奖励文本.strip_edges() != "":
		var 解析摘要: String = _解析并发放奇遇奖励(d, 奖励文本)
		if 解析摘要 != "":
			摘要 += 解析摘要
			宗门纪事.append({"日": 累计游戏日, "弟子": d.姓名, "稀有度": q.get("稀有度", "普通"), "名称": q.get("event_name", "奇遇奖励"), "文案": "获得奖励：%s" % 解析摘要.strip_edges()})
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
	# B 部分：结构化奖励（opt1_reward 字段）
	var 征伐奖励文本: String = q.get("opt1_reward", "")
	if 征伐奖励文本.strip_edges() != "":
		var 征伐解析: String = _解析并发放奇遇奖励(d, 征伐奖励文本)
		if 征伐解析 != "":
			摘要 += 征伐解析
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
	# S1 器堂赠宝：缓存最近出战阵容（供 P1 权重判定；存姓名，可序列化，save/load 持久化）
	if 出战弟子.size() > 0:
		_上次出战弟子 = 出战弟子.filter(func(d): return d is Disciple).map(func(d): return d.姓名)
	var 节点类型: String = stage.get("node_type", "normal")
	# 体力校验
	var 耗时: int = int(stage.get("stamina_cost", 0))
	if 体力 < 耗时:
		结果["error"] = "气力不足（需%d，余%d）" % [耗时, 体力]
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
			周期评分.记首通()   # P1：首通计入周期评分
			已通关关卡[stage_id] = true
			_新手_检测("realm_first_enter")
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

# 掉落表行 → Item；修复「材料/碎片误带穿戴位」bug
# 根因：Item.new() 在 _init 里随机生成类别/穿戴位，掉落仅覆写 名称+品阶。
#       草药/灵材/碎片等掉落偶发 roll 到 fa_qi 即带装备槽被自动穿上。
# 对策：drop_pool 里只有 eq_whole_* 是整装装备，其余掉落全部清空穿戴位并归为灵材。
func _掉落转物品(drop: Dictionary) -> Item:
	var it: Item = Item.new()
	it.名称 = drop.get("item_name", "掉落物")
	_应用掉落品质(it, drop.get("quality", ""))
	var item_id: String = drop.get("item_id", "")
	if not item_id.begins_with("eq_whole_"):
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
	var 经营加成_total: float = 0.0   # F3：全建筑经营加成汇总池封顶 0.30（产出效率池 §4.1）
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
		经营加成 = clamp(经营加成, 0.0, 0.20)   # F3 单建筑经营加成封顶（产出效率池 §4.1，独立 clamp 不接 economy_balance）
		经营加成_total += 经营加成
		经营加成_total = clamp(经营加成_total, 0.0, 0.30)   # F3 全建筑汇总封顶
		var base: int = 经营基数.get(key, 1)
		var 气运乘: float = (1.0 + 气运产出加成) if (累计游戏日 < 气运到期日) else 1.0
		# P0-BUILD-4：宗门等级 → 建筑产出乘区（1级无加成，10级 +18%，数值克制）
		var 等级乘区: float = 1.0 + 0.02 * max(0, 门派等级 - 1)
		var 产: int = int(n * base * (1.0 + 经营加成) * 气运乘 * (1.0 + 产出buff + 彩蛋产出加成()) * 等级乘区 * _建筑等级_乘区(key))
		灵石 += 产
		# S1 批2 D7 解锁①：Lv.2+ 保底津贴（与成员产出叠加，结构性产出）
		if int(堂.get("等级", 1)) >= 2:
			灵石 += int(堂.get("等级", 1)) * 建筑保底津贴
		# 阶段2：记录各资源建筑本月实际产出额，供 _建筑被动结算 概率翻倍（灵草丰收/富矿/额外丹元/器魂）时直接加回
		# 资源系统补全（偏差#3）：灵田/矿脉除普适灵石外，额外产出专属材料，供 S1 丹器消耗
		match key:
			"lingtian":
				_本月灵田产出 = 产
				灵草 += 产
				灵气 += int(ceil(产 * 0.5))   # 灵气减半产出（老大拍板 2026-07-21）：初期不溢出，核心产出仍以灵草为主
			"kuangmai":
				_本月矿脉产出 = 产
				矿石 += 产
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
	经营加成 = clamp(经营加成, 0.0, 0.20)   # F3 预览单建筑封顶（与结算一致，独立 clamp 不接 economy_balance）
	var base: int = 经营基数.get(key, 1)
	var 保底: int = int(堂.get("等级", 1)) * 建筑保底津贴 if int(堂.get("等级", 1)) >= 2 else 0
	return int(n * base * (1.0 + 经营加成) * 气运乘 * (1.0 + 产出buff) * 等级乘区 * _建筑等级_乘区(key)) + 保底

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

	# 器堂赠宝（P0 配置驱动梯度池 + P1 分配权重/保底/冗余 + P2 轻量堂主加成）
	if _本月器堂产出 > 0:
		# --- P2 轻量堂主加成：仅 1 层判断（匠心命格负责人）---
		var 触发率: float = 0.12
		var 稀有概率: float = 0.10
		var 器堂主: Variant = 堂口列表.get("qitang", {}).get("负责人", null)
		if 器堂主 != null and 器堂主.destiny_id == "D_JIANGXIN":
			触发率 = 0.15
			稀有概率 = 0.15
		if randf() < 触发率:
			灵石 += _本月器堂产出
			_加推演条目("【器堂】巧匠精进，额外器魂折算灵石。", ET_RESOURCE, PRIO_NORMAL, {"建筑": "qitang"})
			# --- P0 读配置梯度池 ---
			var 器堂等级: int = int(堂口列表.get("qitang", {}).get("等级", 1))
			var 配置行: Array = _读器堂赠宝行(器堂等级)
			var 普通行: Array = []
			var 稀有行: Array = []
			for 行 in 配置行:
				if 行.get("pool_type", "") == "rare":
					稀有行.append(行)
				else:
					普通行.append(行)
			if 普通行.is_empty() and 稀有行.is_empty():
				# 配置缺失兜底：沿用老体验（残破铜镜），保证零回归
				if not 弟子列表.is_empty():
					var 兜底得主: Disciple = _选器堂赠宝得主()
					if 兜底得主 != null:
						var 兜底器: Item = _造低阶物品("fabao", "凡阶")
						兜底得主.背包.append(兜底器)
						宗门纪事.append({"日": 累计游戏日, "弟子": 兜底得主.姓名, "稀有度": "建筑被动", "名称": "器堂赠宝", "文案": "器堂额外锻造一件【%s】，赐予【%s】。" % [兜底器.名称, 兜底得主.姓名]})
						_加推演条目("【器堂】额外锻造一件【%s】，赐予弟子。" % 兜底器.名称, ET_LOOT, PRIO_NORMAL, {"建筑": "qitang"})
						_器堂赠宝_记录上阵(兜底得主)
			else:
				var 选池: Array = 普通行
				if not 稀有行.is_empty() and randf() < 稀有概率:
					选池 = 稀有行
				if 选池.is_empty():
					if not 普通行.is_empty():
						选池 = 普通行
					else:
						选池 = 稀有行
				var 命中行: Dictionary = _加权抽配置行(选池)
				var 数量: int = randi_range(int(命中行.get("count_min", 1)), int(命中行.get("count_max", 1)))
				var 得主: Disciple = _选器堂赠宝得主()
				if 得主 != null:
					var 样器: Item = _造器堂赠宝物(命中行)   # 仅用于冗余判定（品类/品阶）
					var 冗余: bool = (样器.类别 == "fabao") and 得主.装备.has("本命法宝") and _品阶不小于(得主.装备["本命法宝"].品阶, 样器.品阶)
					if 冗余:
						# P1 冗余：法宝同品阶及以上已持有 → 拆解折算阵纹碎片入背包（不建仓库）
						_发放阵纹碎片(得主, 数量)
						宗门纪事.append({"日": 累计游戏日, "弟子": 得主.姓名, "稀有度": "建筑被动", "名称": "器堂赠宝·拆解", "文案": "【%s】已执同阶法宝，赠宝拆解折算阵纹碎片×%d。" % [得主.姓名, 数量]})
						_加推演条目("【器堂】赠宝与同阶法宝重叠，拆解折算阵纹碎片×%d。" % 数量, ET_LOOT, PRIO_NORMAL, {"建筑": "qitang"})
					else:
						for _i in range(数量):
							得主.背包.append(_造器堂赠宝物(命中行))
						宗门纪事.append({"日": 累计游戏日, "弟子": 得主.姓名, "稀有度": "建筑被动", "名称": "器堂赠宝", "文案": "器堂赐下【%s】×%d，予【%s】。" % [命中行.get("item_name", ""), 数量, 得主.姓名]})
						_加推演条目("【器堂】赐下【%s】×%d。" % [命中行.get("item_name", ""), 数量], ET_LOOT, PRIO_NORMAL, {"建筑": "qitang"})
					_器堂赠宝_记录上阵(得主)

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

# S1 点击联动 MVP：物品 key → 造物参数（类别, 品阶），供 main.gd::_解析实体 按 key 重建展示模板 Item。
# 与 _解析并发放奇遇奖励 的 key 口径对齐；资源类 key（lingshi/lingcao/kuangshi/lingqi）不入表（详情不适用）。
# MVP 仅收录已落地的 dan_low；后续实体系统落地后在此增量扩展即可。
var _物品定义表: Dictionary = {
	"dan_low": ["dan_yao", "凡阶"],
}
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

# ============ 器堂赠宝（Task #28：P0 配置梯度池 + P1 分配权重/保底/冗余 + P2 堂主加成）============
# 以下 helper 仅供 _建筑被动结算 的器堂分支调用，零触碰战斗核心（BattleCalculator/BattleManager 未引用）。

# 品阶秩（凡阶→道阶），用于冗余判定「同品阶及以上」。独立于 item.gd 内部序，避免跨文件耦合。
var _品阶秩: Dictionary = {"凡阶": 0, "灵阶": 1, "宝阶": 2, "王阶": 3, "圣阶": 4, "仙阶": 5, "道阶": 6}
func _品阶不小于(a: String, b: String) -> bool:
	var ia: int = _品阶秩.get(a, -1)
	var ib: int = _品阶秩.get(b, -1)
	if ia < 0 or ib < 0:
		return false
	return ia >= ib

# 懒加载 craft_hall_reward.csv（路径与 _加载阵法物品_S1 同款范式）
func _加载器堂赠宝表():
	if not _器堂赠宝表.is_empty():
		return
	_器堂赠宝表 = DestinyDataLoader._read_csv("res://config/craft_hall_reward.csv")

# 按器堂等级筛出命中的配置行（落入 [level_min, level_max]）
func _读器堂赠宝行(等级: int) -> Array:
	_加载器堂赠宝表()
	var 命中: Array = []
	for r in _器堂赠宝表:
		var lo: int = int(r.get("level_min", 1))
		var hi: int = int(r.get("level_max", 1))
		if 等级 >= lo and 等级 <= hi:
			命中.append(r)
	return 命中

# 加权抽一行（按 weight 列归一化；weight 为 CSV 字符串，转 float）
func _加权抽配置行(行列表: Array) -> Dictionary:
	var 总: float = 0.0
	for r in 行列表:
		总 += float(r.get("weight", 0))
	if 总 <= 0:
		return 行列表[0] if 行列表.size() > 0 else {}
	var 抽: float = randf() * 总
	for r in 行列表:
		抽 -= float(r.get("weight", 0))
		if 抽 <= 0:
			return r
	return 行列表[行列表.size() - 1]

# P0：按 item_id 实例化（复用 阵法物品表 + 通用掉落转换 _掉落转物品，保证 name 命中阵法闭环）。
# 不复用 main.gd::_解析实体：其 item/equip 分支仅认 _物品定义表(dan_low)，不处理 array_items 的 item_id。
func _按id造(item_id: String) -> Item:
	if 阵法物品表.is_empty():
		_加载阵法物品_S1()
	var row: Dictionary = 阵法物品表.get(item_id, {})
	if row.is_empty():
		var 兜底: Item = Item.new()
		兜底.名称 = item_id
		return 兜底
	return _掉落转物品({"item_id": item_id, "item_name": row.get("item_name", item_id), "quality": row.get("item_grade", "")})

# 统一实例化一行赠宝（gen→_造低阶物品 / id→_按id造）
func _造器堂赠宝物(行: Dictionary) -> Item:
	if 行.get("ref_type", "gen") == "id":
		return _按id造(行.get("item_ref", ""))
	return _造低阶物品(行.get("item_ref", "fabao"), 行.get("grade", "凡阶"))

# P1：按权重档选得主（T1 匠心+上阵 > T2 上阵 > T3 内门及以上 > T4 外门）。
# 保底：_器堂赠宝未中上阵连计≥3 时强制只从上阵档(T1/T2)选，并重置计数器。
func _选器堂赠宝得主() -> Disciple:
	if 弟子列表.is_empty():
		return null
	var 强制上阵: bool = _器堂赠宝未中上阵连计 >= 3
	if 强制上阵:
		_器堂赠宝未中上阵连计 = 0   # 强制档已消耗，重置（防连续强制）
	var 上阵名: Array = _上次出战弟子
	var T1: Array = []
	var T2: Array = []
	var T3: Array = []
	var T4: Array = []
	for d in 弟子列表:
		var 是上阵: bool = d.姓名 in 上阵名
		var 有匠心: bool = (d.destiny_id == "D_JIANGXIN")
		if 强制上阵:
			if 有匠心 and 是上阵:
				T1.append(d)
			elif 是上阵:
				T2.append(d)
			continue   # 强制档只取上阵者；非上阵者本档跳过
		if 有匠心 and 是上阵:
			T1.append(d)
		elif 是上阵:
			T2.append(d)
		elif Disciple.身份层级序.find(d.身份) >= 1:   # 内门及以上（内门弟子/核心弟子/亲传弟子/长老）
			T3.append(d)
		else:
			T4.append(d)
	var 档: Array = []
	if not T1.is_empty():
		档 = T1
	elif not T2.is_empty():
		档 = T2
	elif not T3.is_empty():
		档 = T3
	elif not T4.is_empty():
		档 = T4
	else:
		档 = 弟子列表   # 极端兜底（不应发生）
	return 档[randi() % 档.size()]

# P1：保底计数器更新（得主∈上阵→归零，否则+1）
func _器堂赠宝_记录上阵(得主: Disciple):
	if 得主 == null:
		return
	if 得主.姓名 in _上次出战弟子:
		_器堂赠宝未中上阵连计 = 0
	else:
		_器堂赠宝未中上阵连计 += 1

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
# === S1 批2：建筑等级乘区 + 上限 + 升级消耗（清单公式；清单误称"已落"，实际须创建）===
func _建筑等级_乘区(key: String) -> float:
	var 等级: int = int(堂口列表.get(key, {}).get("等级", 1))
	return 1.0 + 0.02 * max(0, 等级 - 1)     # 等级=1 → 1.0（零回归）；每级 +2%

func _建筑等级上限() -> int:
	return min(门派等级, 7)                   # 门派等级 1~10 封顶 7；凡阶(1)→上限1（不可升）

func _升级消耗_灵石(当前等级: int) -> int:
	return int(ceil(200.0 * pow(1.5, float(当前等级 - 1))))   # [PLACEHOLDER] 待数值 GDD

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
	应用堂口状态存档()   # S1 批2：回填 等级/政绩（load/新游戏后还原，防重启清零）

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
	# S1 批2：仅当主事实际变更（旧主事存在且非同一人）→ 政绩清零 + 里程碑/事件标记重置（新任期）。
	# 初始任命(旧=null)/应用负责人存档(读档)/解除锁定 不触发清零（EC-P2~P4）。
	var 旧主事: Variant = 堂口列表[key].get("负责人", null)
	堂口列表[key]["负责人"] = d
	堂口负责人存档[key] = d.姓名
	if 旧主事 != null and 旧主事 != d:
		堂口列表[key]["政绩"] = 0
		var _st: Dictionary = 堂口状态存档.get(key, {})
		_st["里程碑"] = 0
		_st["高政绩事件"] = false
		堂口状态存档[key] = _st

# 掌门任命负责人（UI 调用）
func 任命负责人(key: String, d: Disciple):
	if not 堂口列表.has(key):
		return
	# S1 批1：阶位门槛闸（additive；legacy 阶位已按身份给到对应阶位，veteran 不被误拦，§7.2）
	if d.阶位索引() < int(堂口阶位门槛.get(key, 0)):
		return false
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
			buff[维] = float(buff.get(维, 0.0)) + (0.02 if int(堂.get("等级", 1)) >= 4 else 0.01)
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

# ============ S1 批2：建筑升级 + 任期政绩（§二 / §三）============

func 升级建筑(key: String) -> Dictionary:
	if not 堂口列表.has(key):
		return {"ok": false, "msg": "建筑不存在"}
	var 等级: int = int(堂口列表[key].get("等级", 1))
	var 上限: int = _建筑等级上限()
	if 等级 >= 上限:
		return {"ok": false, "msg": "已达等级上限（需更高宗门品级）"}
	if 门派等级 < 2:
		return {"ok": false, "msg": "需灵阶及以上宗门解锁建筑升级"}
	var 耗: int = _升级消耗_灵石(等级)
	if 灵石 < 耗:
		return {"ok": false, "msg": "灵石不足（需 %d）" % 耗}
	灵石 -= 耗
	堂口列表[key]["等级"] = 等级 + 1
	_存堂口状态(key)
	宗门纪事.append({"日": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "建筑升级",
		"文案": "【营建】%s 修缮至 Lv.%d，产出增益。" % [堂口列表[key]["名称"], 等级 + 1]})
	_加推演条目("【营建】%s 升至 Lv.%d。" % [堂口列表[key]["名称"], 等级 + 1], ET_SECT, PRIO_NORMAL, {"建筑": key})
	return {"ok": true, "msg": "%s 升至 Lv.%d（-%d灵石）" % [堂口列表[key]["名称"], 等级 + 1, 耗]}

func _存堂口状态(key: String) -> void:
	var s: Dictionary = 堂口状态存档.get(key, {})
	s["等级"] = int(堂口列表[key].get("等级", 1))
	s["政绩"] = int(堂口列表[key].get("政绩", 0))
	s["里程碑"] = int(s.get("里程碑", 0))
	s["高政绩事件"] = bool(s.get("高政绩事件", false))
	堂口状态存档[key] = s

func 应用堂口状态存档() -> void:
	for key in 堂口状态存档.keys():
		if 堂口列表.has(key):
			var s: Dictionary = 堂口状态存档.get(key, {})
			堂口列表[key]["等级"] = int(s.get("等级", 1))
			堂口列表[key]["政绩"] = int(s.get("政绩", 0))

# S1 批2：任期政绩月度累积（仅在主事在任时；续任保留手动，不自动到期）
func _累计任期政绩() -> void:
	var 政绩基数: Dictionary = {
		"lingtian": 1, "kuangmai": 1, "yuying": 1,
		"cangjing": 2, "dantang": 2, "qitang": 2, "zhifa": 2, "gongxun": 2, "tanwei": 2,
		"zhenfa": 3, "yushou": 3, "xichi": 3, "wudao": 3,
	}
	for key in 堂口列表.keys():
		var 堂: Dictionary = 堂口列表[key]
		var 负责: Variant = 堂.get("负责人", null)
		if 负责 == null:
			continue                              # 无主事 → 不累积（任期空窗）
		var 月增: int = int(政绩基数.get(key, 1))
		堂["政绩"] = int(堂.get("政绩", 0)) + 月增
		_累计政绩奖励(key)
		_存堂口状态(key)

# S1 批2：政绩里程碑 + 高政绩事件（仅产出/声望，零战力）
func _累计政绩奖励(key: String) -> void:
	var 政绩: int = int(堂口列表[key].get("政绩", 0))
	var s: Dictionary = 堂口状态存档.get(key, {})
	var 里程碑: int = int(s.get("里程碑", 0))
	var 阈值: int = 12                              # [PLACEHOLDER]
	while 政绩 >= (里程碑 + 1) * 阈值 and 里程碑 < 100:
		里程碑 += 1
		设置气运buff(0.0, 0.01, 3)                  # 产出+1% ×3日（复用 L774 气运管线）
		_加推演条目("【政绩】%s 主事治业有成，全宗产出微增。" % 堂口列表[key]["名称"], ET_SECT, PRIO_TRIVIAL, {"建筑": key})
	s["里程碑"] = 里程碑
	# 高政绩特殊事件（一次性，防重启刷奖须持久化标记）
	if not bool(s.get("高政绩事件", false)) and 政绩 >= 36:   # 高阈值 [PLACEHOLDER]
		s["高政绩事件"] = true
		声望 += 50                                  # [PLACEHOLDER]
		宗门纪事.append({"日": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "政绩卓著",
			"文案": "【政绩】%s 主事任期政绩卓著，宗门上下称颂（声望+%d）。" % [堂口列表[key]["名称"], 50]})
		_加推演条目("【政绩】%s 主事政绩卓著，誉满宗门！" % 堂口列表[key]["名称"], ET_SECT, PRIO_HIGH, {"建筑": key})
	堂口状态存档[key] = s

# ============ S1 批1：阶位轴晋升考核（§四）============
# 判断某弟子是否满足破格晋升条件（D5）：极品/天品灵根 · 经营命格 · 声望≥阈值且立大功
func 满足破格条件(d: Disciple) -> bool:
	if d.灵根品阶 in ["极品", "天品"]:
		return true
	if d.有特殊命格():
		return true
	if 声望 >= 破格声望阈值 and 立大功标记.has(d.姓名):
		return true
	return false

# 某阶位当前占用数（遍历 弟子列表 统计）
func 阶位名额占用(阶位名: String) -> int:
	var n: int = 0
	for x in 弟子列表:
		if x.阶位 == 阶位名:
			n += 1
	return n

# 某阶位名额上限（门派等级 L 驱动，§4.4；全部 [PLACEHOLDER]）
func 阶位名额上限(阶位名: String) -> int:
	var L: int = 门派等级
	match 阶位名:
		"执事": return 2 + L
		"堂主": return 1 + int(L / 2)
		"长老": return int(L / 3)
		"供奉": return int(L / 5)
		_: return 0

# 发起单次考核（玩家手动）。成功/失败走掷骰，二次校验名额/冷却/贡献。返回结果 Dict。
func 发起考核(d: Disciple) -> Dictionary:
	var 结果: Dictionary = {"ok": false, "成功": false, "原因": "", "贡献扣减": 0}
	if not d.可授阶():
		结果["原因"] = "该弟子身份不足（须内门及以上）"
		return 结果
	if d.考核冷却剩余 > 0:
		结果["原因"] = "考核冷却中（剩余 %d 日）" % d.考核冷却剩余
		return 结果
	var 破格: bool = 满足破格条件(d)
	var 上限idx: int = d.阶位上限索引(破格)
	if d.阶位索引() >= 上限idx:
		结果["原因"] = "已达该身份可任最高阶位"
		return 结果
	var 目标idx: int = d.阶位索引() + 1
	var 目标阶位: String = d.阶位层级序[目标idx]
	if 阶位名额占用(目标阶位) >= 阶位名额上限(目标阶位):
		结果["原因"] = "%s 名额已满" % 目标阶位
		return 结果
	if 贡献点 < 考核成本:
		结果["原因"] = "贡献点不足（需 %d）" % 考核成本
		return 结果
	贡献点 -= 考核成本
	结果["贡献扣减"] += 考核成本
	if randf() < d.考核成功率():
		d.阶位 = 目标阶位
		d.考核心得 = false
		结果["ok"] = true
		结果["成功"] = true
		_晋升仪式感(d)
	else:
		d.考核冷却剩余 = 考核冷却日
		d.考核心得 = true
		贡献点 -= 考核失败扣减
		结果["贡献扣减"] += 考核失败扣减
		宗门纪事.append({"日": 累计游戏日, "弟子": d.姓名, "稀有度": "宗门", "名称": "阶位考核", "文案": "【考核】%s 晋阶%s失利，需再磨砺。" % [d.姓名, 目标阶位]})
	结果["阶位"] = d.阶位
	return 结果

# 晋升仪式感：纪事永录 + 推演条目 + 全宗士气临时加成（复用 设置气运buff，§4.7）
func _晋升仪式感(d: Disciple):
	宗门纪事.append({"日": 累计游戏日, "弟子": d.姓名, "稀有度": "宗门", "名称": "阶位晋升", "文案": "【晋升】%s 晋升为 阶位·%s" % [d.姓名, d.阶位]})
	_加推演条目("【晋升】%s 任 阶位·%s。" % [d.姓名, d.阶位], ET_APPOINT, PRIO_NORMAL, {"弟子": d.姓名, "阶位": d.阶位})
	match d.阶位:
		"堂主", "长老": 设置气运buff(0.02, 0.01, 3)
		"供奉": 设置气运buff(0.03, 0.02, 7)

# 批量考核：逐人独立掷骰，独立判定冷却/名额/贡献（§4.5）
func 批量考核(list: Array) -> Dictionary:
	var 汇总: Dictionary = {"成功": [], "失败": [], "跳过": [], "贡献扣减": 0}
	for d in list:
		if not (d is Disciple):
			continue
		var r: Dictionary = 发起考核(d)
		汇总["贡献扣减"] += int(r.get("贡献扣减", 0))
		if r.get("成功"):
			汇总["成功"].append(d.姓名)
		elif r.get("ok"):
			汇总["失败"].append(d.姓名)
		else:
			汇总["跳过"].append({"弟子": d.姓名, "原因": r.get("原因", "")})
	return 汇总

# 罢免阶位（降级一级，不走掷骰、不耗贡献，§4.6）
func 罢免阶位(d: Disciple) -> Dictionary:
	var 结果: Dictionary = {"ok": false, "原因": ""}
	if d.阶位 == "无":
		结果["原因"] = "该弟子本无阶位"
		return 结果
	var idx: int = d.阶位索引()
	var 新idx: int = idx - 1
	d.阶位 = ("无" if 新idx < 0 else d.阶位层级序[新idx])
	结果["ok"] = true
	宗门纪事.append({"日": 累计游戏日, "弟子": d.姓名, "稀有度": "宗门", "名称": "罢免阶位", "文案": "【罢免】%s 被罢去阶位，现任 阶位·%s。" % [d.姓名, d.阶位]})
	return 结果

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
				d.灵根 = Disciple.灵根变异.pick_random()
		"天品":
			d.灵根 = "天灵根"
		_:
			if d.灵根 in Disciple.灵根变异 or d.灵根 == "天灵根" or d.灵根 == "先天五行全灵根":
				d.灵根 = Disciple.灵根五行.pick_random()
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
	# === S1 批5-B：首次确保字派序列已生成（旧档空 → 本次生成并持久化），供新弟子道号取字 ===
	_确保字派_S1()
	# P0-BUILD-2：外门接引堂负责人 → 测灵高品质概率 +1%；阶段2：接引堂常驻再 +2%（最多+3%）
	var 测灵buff: float = 汇总负责人全局buff().get("测灵", 0.0) + _接引堂测灵加()
	var d: Disciple
	for i in N:
		d = Disciple.new()
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
		# D7：全局前 3 名新徒默认内门（防卡进度；仅改创建时初始值，不动身份轴逻辑/存档）
		if 弟子列表.size() + i < 3 and d.身份 == "外门":
			d.身份 = "内门弟子"
		# P0-BUILD-2：外门接引堂负责人 → 测灵高品质概率 +1%（触发时灵根品阶升一档，已为天品则跳过）
		if 测灵buff > 0.0 and d.灵根品阶 != "天品" and randf() < 测灵buff:
			_提升灵根品阶一档(d)
	if d.灵根品阶 in ["天品", "极品", "上品"]:   # P1：高品质新弟子计入周期评分
		周期评分.记高品质新弟子()
	# === S1 批5-B：新弟子道号简化生成（[PLACEHOLDER] 简化版：外门=辈分字派[0]+单字）===
	d.辈分序 = 0   # 默认开山第1字
	if d.身份 == "外门" and not 辈分字派.is_empty():
		d.道号 = 辈分字派[0] + (d.姓名.left(1) if d.姓名.length() > 0 else "尘")
	# 其余阶位道号暂留空 ""（玩家可改）；[PLACEHOLDER] 命名规则见 GDD §⑤.2
	弟子列表.append(d)
	新徒.append(d)
	# P0 目标链：弟子招收 → recruit_count（newbie_001 主动）/ recruit_count_5（newbie_007 状态）
	_新手_检测("recruit_count")
	_新手_评估后续()
	# === S1 端口：新弟子制式装备/入职包发放 ===
	# 调用位置：举办测灵根() 弟子创建循环末尾（d 已 append 入 弟子列表/新徒 之后）。
	# 入参（S1 实装时）：d: Disciple（新弟子）
	# 副作用（S1 实装后）：d.背包.append(制式法宝一套 + 基础修炼功法 + 初级制式储物袋)，可按 身份/阶位 分档配发
	# 依赖：最轻量，可独立于建筑/资源体系先行（见 §二 新弟子入职包）。状态：仅注释标记，未调用任何函数。
	_加声望(N)
	上次测灵日 = 累计游戏日   # 更新冷却时间戳
	# 天品灵根弟子 → 破格：写宗门纪事 + 触发全宗气运 buff（7日 修炼+3%/产出+2%）
	for 徒 in 新徒:
		if 徒.灵根品阶 == "天品":
			宗门纪事.append({"日": 累计游戏日, "弟子": 徒.姓名, "稀有度": "天品", "名称": "天品灵根弟子", "文案": "接引大典检出天品灵根弟子【%s】，全宗士气大振。" % 徒.姓名})
			设置气运buff(0.03, 0.02, 7)
			立大功标记[徒.姓名] = true   # D5：天品接引 = 立大功（运行时态标记，支持声望破格）
			break
	_注册全部()
	var 有天品: bool = false
	for 徒 in 新徒:
		if 徒.灵根品阶 == "天品":
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
	if not _校准开("双周期评级启用", true):
		# 回退：原年度实时立即晋升
		if 新等级 > 门派等级:
			宗门纪事.append({"日": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "宗门晋升",
				"文案": "太玄宗历经沉淀，宗门品级晋升至 Lv.%d，灵脉愈发醇厚，全宗上下欢欣。" % 新等级})
			_加推演条目("【宗门】太玄宗晋升至 Lv.%d！灵脉修炼速度 +%d%%" % [新等级, 新等级 * 2], ET_SECT, PRIO_HIGH, {"宗门等级": 新等级})
		门派等级 = 新等级
	else:
		# 双周期：仅记录「成长目标」，待七载大考才生效（零新增，仅改调用时机）
		if 新等级 > 门派等级目标:
			门派等级目标 = 新等级
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

# T03 引育计划队列：周期结算遍历启用条目，灵石足够则拨付经费+按偏好生成兽卵入孵化列表
func 处理兑换队列():
	for 条目 in 灵兽兑换队列:
		if not 条目.get("启用", false):
			continue
		var 消耗: int = 条目.get("cost", 0)
		if 灵石 < 消耗:
			continue
		灵石 -= 消耗
		var 偏好: Dictionary = 条目.get("偏好", {})
		var 蛋: Beast = Beast.new()
		蛋.随机成蛋(偏好.get("品阶", ""), 偏好.get("类型", ""))
		灵兽蛋列表.append(蛋)
		var 引纪: Dictionary = _引育纪事文案(蛋)
		战报更新.emit(引纪["文案"])
		宗门纪事.append({"日": 累计游戏日, "稀有度": ("异闻" if 引纪.get("category", "") == "异闻" else "宗门"), "名称": "引育成果", "文案": 引纪["文案"], "category": 引纪.get("category", "")})

# T13+T14 出战灵兽月度养成：出战(主/副宠)+1级(封顶上限)、忠诚+2(封顶100)；库存灵兽忠诚-1(地板0)
func 出战灵兽月度养成():
	for d in 弟子列表:
		for 兽 in [d.主宠灵兽, d.副宠灵兽]:
			if 兽 == null or 兽.孵化中:
				continue
			兽.等级 = min(兽.等级 + 1, 兽.等级上限)
			兽.忠诚度 = min(兽.忠诚度 + 2, 100)
	for 兽 in 灵兽库存:
		if 兽.孵化中:
			continue
		兽.忠诚度 = max(兽.忠诚度 - 1, 0)

func 绑定灵兽给首只合格(灵兽: Beast) -> String:
	for d in 弟子列表:
		if d.主宠灵兽 != null:
			continue
		if (d.资质 == "fan_su" or d.资质 == "pingyong") and not (灵兽.品阶 in ["fan_jie", "ling_jie"]):
			continue
		return 绑定灵兽给指定弟子(灵兽, d)
	return "无符合条件的空闲弟子可绑定（低资质仅能携凡/灵阶灵兽）。"

func 绑定灵兽给指定弟子(灵兽: Beast, 弟子: Disciple, 槽位: String = "主宠") -> String:
	if 槽位 == "副宠" and 弟子.副宠灵兽 != null:
		return "【%s】已绑定副宠灵兽。" % 弟子.姓名
	if 槽位 != "副宠" and 弟子.主宠灵兽 != null:
		return "【%s】已绑定主宠灵兽。" % 弟子.姓名
	if (弟子.资质 == "fan_su" or 弟子.资质 == "pingyong") and not (灵兽.品阶 in ["fan_jie", "ling_jie"]):
		return "【%s】资质过低，仅能携带凡/灵阶灵兽。" % 弟子.姓名
	if 槽位 == "副宠":
		弟子.副宠灵兽 = 灵兽
		灵兽.设为副宠()
	else:
		弟子.主宠灵兽 = 灵兽
		灵兽.设为主宠()
	灵兽库存.erase(灵兽)
	弟子变动.emit()
	return "【%s】已绑定灵兽【%s】（%s）。" % [弟子.姓名, 灵兽.种类名, Beast.类型中文.get(灵兽.beast_type, "")]

# 解绑灵兽（P0-3 双槽：卸下主宠/副宠，灵兽返回御兽堂库存，可重新绑定）
func 解绑灵兽(弟子: Disciple, 槽位: String) -> String:
	var 兽: Beast = null
	if 槽位 == "副宠":
		兽 = 弟子.副宠灵兽
		弟子.副宠灵兽 = null
	else:
		兽 = 弟子.主宠灵兽
		弟子.主宠灵兽 = null
	if 兽 != null:
		兽.取消出战()
		if not 灵兽库存.has(兽):
			灵兽库存.append(兽)
	弟子变动.emit()
	return "【%s】已解除%s灵兽契约，灵兽返回御兽堂。" % [弟子.姓名, ("副宠" if 槽位 == "副宠" else "主宠")]

# ============ 终局机制 P0：寿元坐化 ============
# 寿元耗尽弟子离场：灵兽解绑归御兽堂、装备/背包归宗门库房、按身份分档写纪事、从现役移除。
# P0 不含延寿/丹毒/传承（留 P1/P2）；单月坐化数量兜底，避免界面/数据洪峰。
func 处理坐化(名单: Array[Disciple]):
	if 名单.is_empty():
		return
	var 上限 := 5
	var 计数 := 0
	for d in 名单:
		计数 += 1
		if 计数 > 上限:
			break
		# 灵兽解绑归还御兽堂
		if d.主宠灵兽 != null:
			var 兽: Beast = d.主宠灵兽
			d.主宠灵兽 = null
			兽.取消出战()
			if not 灵兽库存.has(兽):
				灵兽库存.append(兽)
		if d.副宠灵兽 != null:
			var 兽: Beast = d.副宠灵兽
			d.副宠灵兽 = null
			兽.取消出战()
			if not 灵兽库存.has(兽):
				灵兽库存.append(兽)
		# 装备/背包归还宗门库房
		for it in d.装备.values():
			宗门库房.append(it)
		d.装备.clear()
		for it in d.背包:
			宗门库房.append(it)
		d.背包.clear()
		# 纪事入册（按身份分档）
		宗门纪事.append({"日": 累计游戏日, "弟子": d.姓名, "名称": "坐化", "文案": _坐化纪事文案(d)})
		_加推演条目("【%s】寿元耗尽，坐化于山门。" % d.姓名, ET_SECT, PRIO_NORMAL, {"弟子": d.姓名})
		弟子列表.erase(d)

# 坐化纪事文案（史官视角，按身份/境界分档；变量全部取自真实属性，禁止写死）
func _坐化纪事文案(d: Disciple) -> String:
	var 年: int = int(累计游戏日 / 360.0)
	var 寿终: int = int(d.年龄)
	var 偏科注 := ""
	if (d.资质 in ["fan_su", "pingyong"]) and (d.灵根品阶 in ["极品", "天品"]):
		偏科注 = "身怀异禀灵根，惜根骨所限，终未完全雕琢，令人叹惋。"
	if d.身份 == "长老" or d.境界 in ["化神", "仙阶", "道阶"]:
		var 堂名: String = "宗门" if d.堂口 == "" else Lore.取堂口(d.堂口)["名称"]
		return "%s%s，寿元耗尽，于第%d年端坐而化。执掌%s多年，兢兢业业，为宗门立下汗马功劳，众弟子皆感念其恩。享寿%d岁。%s" % [d.身份, d.姓名, 年, 堂名, 寿终, 偏科注]
	elif d.身份 in ["核心弟子", "亲传弟子"] or d.境界 in ["金丹", "元婴"]:
		return "核心弟子%s（%s），于第%d年坐化。在职期间恪尽职守，宗门记其功绩。享寿%d岁。%s" % [d.姓名, d.境界, 年, 寿终, 偏科注]
	else:
		return "%s，于第%d年寿元耗尽，坐化于山门。一生勤恳，虽无大功，亦守宗门本分。享寿%d岁。%s" % [d.姓名, 年, 寿终, 偏科注]

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
		"lingshi": 灵石, "lingcao": 灵草, "kuangshi": 矿石, "lingqi": 灵气, "gongxian": 贡献点, "xuanyu": 玄玉, "dizi": [], "lingshou_dan": [], "lingshou_kucun": [], "lingshou_duilie": 灵兽兑换队列,
		"累计游戏日": 累计游戏日, "最后登录": 最后登录, "门派等级": 门派等级, "声望": 声望, "繁荣": 繁荣,
		"香火值": 香火值, "信徒数": 信徒数, "凡人城镇": 凡人城镇, "香火月产预估": 香火月产预估, "信徒增益档": 信徒增益档,
		"辈分字派": 辈分字派, "门规严格度": 门规严格度, "正邪路线": 正邪路线, "宗门大阵": 宗门大阵,
		"堂口负责人": 堂口负责人存档, "堂口状态": 堂口状态存档, "引导阶段": 引导阶段,
		"上次出战弟子": _上次出战弟子, "器堂赠宝连计": _器堂赠宝未中上阵连计,   # 器堂赠宝 P1 状态（不升 SAVE_VERSION，旧档缺键→默认零回归）
		"体力": 体力, "已通关关卡": 已通关关卡, "精英每日次数": 精英每日次数,
		"气运修炼加成": 气运修炼加成, "气运产出加成": 气运产出加成, "气运到期日": 气运到期日,
		"历史周期评级": 周期评分.历史, "上次结算年": 上次结算年, "年始灵石": 年始灵石, "年始总战力": 年始总战力,
		"七载奖励池": 七载奖励池, "七载待发掉落": 七载待发掉落, "门派等级目标": 门派等级目标, "上次七载日": 上次七载日,
		# S0 任务/商店系统（不升 SAVE_VERSION：load 用 .get 默认兼容老档）
		"kucun": [], "fangshi": 坊市购买记录, "fs_list": 坊市上架集,
		"fangshi_leibie": 坊市类别月购, "fangshi_month_start": 坊市月购窗口起始日,
		"daily": {"当前": 当前日常, "已领": 日常已领, "日": 上次日常日},
		"weekly": {"当前": 当前周常, "已领": 周常已领, "日": 上次周常日},
		"randcd": 随机事件冷却, "rtypecd": 随机事件类型冷却, "qcd": quest_cooldown,
		"newbie_active": 新手目标链激活, "newbie_done": 新手完成列表,
	}
	for it in 宗门库房:
		data["kucun"].append(it.to_dict())
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
		_版本升级备份(data.get("version", 0))
	灵石 = data.get("lingshi", 0)
	灵草 = data.get("lingcao", 0)
	矿石 = data.get("kuangshi", 0)
	灵气 = data.get("lingqi", 0)
	贡献点 = data.get("gongxian", 0)
	玄玉 = data.get("xuanyu", 0)
	累计游戏日 = data.get("累计游戏日", 0)
	最后登录 = data.get("最后登录", 0)
	门派等级 = clamp(data.get("门派等级", 1), 1, 门派等级上限)
	声望 = data.get("声望", 0)
	繁荣 = data.get("繁荣", 50)
	香火值 = data.get("香火值", 0)
	信徒数 = data.get("信徒数", 0)
	凡人城镇.clear()
	for 镇 in data.get("凡人城镇", []):
		凡人城镇.append(镇)
	香火月产预估 = data.get("香火月产预估", 0)
	信徒增益档 = data.get("信徒增益档", "未启")
	辈分字派.clear()
	for 字 in data.get("辈分字派", []):
		辈分字派.append(字)
	门规严格度 = data.get("门规严格度", "中庸")
	正邪路线 = data.get("正邪路线", "")
	宗门大阵 = data.get("宗门大阵", {})   # 旧档缺键→默认空 Dict，零回归（不升 SAVE_VERSION）
	已解锁单人法阵 = data.get("已解锁单人法阵", {})   # D5：弟子已解锁单人法阵集合（旧档缺键→默认空 Dict）
	堂口负责人存档 = data.get("堂口负责人", {})
	堂口状态存档 = data.get("堂口状态", {})   # S1 批2：等级/政绩持久化（旧档缺键→默认空，零回归）
	引导阶段 = data.get("引导阶段", 6)   # 老档无此字段 → 默认6（已完成，不强制弹引导；阶段语义见 §5.2）
	_上次出战弟子 = data.get("上次出战弟子", [])   # 器堂赠宝 P1 缓存（旧档缺键→默认空，零回归）— 注意：赋值给模块变量 _上次出战弟子（带下划线），与声明/保存一致
	_器堂赠宝未中上阵连计 = data.get("器堂赠宝连计", 0)   # 保底计数器（旧档缺键→默认 0）— 同上，须写回 _器堂赠宝未中上阵连计
	气运修炼加成 = data.get("气运修炼加成", 0.0)
	气运产出加成 = data.get("气运产出加成", 0.0)
	气运到期日 = data.get("气运到期日", 0)
	体力 = data.get("体力", 50)
	已通关关卡 = data.get("已通关关卡", {})
	精英每日次数 = data.get("精英每日次数", {})
	# 老档兼容：加载后数值合法性校验与兜底修正（防坏档崩溃 / 异常数据自动修正）
	灵石 = _修正负值(灵石, "灵石")
	灵草 = _修正负值(灵草, "灵草")
	矿石 = _修正负值(矿石, "矿石")
	灵气 = _修正负值(灵气, "灵气")
	贡献点 = _修正负值(贡献点, "贡献点")
	玄玉 = _修正负值(玄玉, "玄玉")
	声望 = _修正负值(声望, "声望")
	繁荣 = _修正区间(繁荣, 0, 100, "繁荣")
	体力 = _修正区间(体力, 0, 体力上限(), "体力")
	累计游戏日 = _修正负值(累计游戏日, "累计游戏日")
	# P1：周期评分存档（计数器不持久化，读档后重置；历史与年界/年始快照恢复）
	历史周期评级 = data.get("历史周期评级", [])
	周期评分.历史 = 历史周期评级
	周期评分.计数 = {"灵石获取": 0, "稀有道具": 0, "突破": 0, "高品质新弟子": 0, "首通": 0}
	上次结算年 = data.get("上次结算年", 0)
	年始灵石 = data.get("年始灵石", 灵石)
	年始总战力 = data.get("年始总战力", 0)
	七载奖励池 = data.get("七载奖励池", 0)
	七载待发掉落 = data.get("七载待发掉落", [])
	门派等级目标 = data.get("门派等级目标", 门派等级)
	上次七载日 = data.get("上次七载日", 0)
	最新周期评级卡 = {}
	弟子列表.clear()
	待抉择.clear()
	奇遇待抉择.clear()      # 会话瞬时队列，load 时清空（ADR-002 D6）
	宗门纪事.clear()        # 会话瞬时历史，load 时清空
	灵兽蛋列表.clear()
	灵兽库存.clear()
	灵兽兑换队列.clear()
	for _q in data.get("lingshou_duilie", []):
		if _q is Dictionary:
			灵兽兑换队列.append(_q)
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
	# S0 任务/商店系统（.get 默认兼容无此字段的老档）
	宗门库房.clear()
	for kd in data.get("kucun", []):
		var it := Item.new()
		it.from_dict(kd)
		宗门库房.append(it)
	坊市购买记录 = data.get("fangshi", {})
	坊市上架集 = data.get("fs_list", [])
	坊市类别月购 = data.get("fangshi_leibie", {})
	坊市月购窗口起始日 = int(data.get("fangshi_month_start", 0))
	var djson: Dictionary = data.get("daily", {})
	当前日常 = djson.get("当前", [])
	日常已领 = djson.get("已领", [])
	上次日常日 = int(djson.get("日", 0))
	var wjson: Dictionary = data.get("weekly", {})
	当前周常 = wjson.get("当前", {})
	周常已领 = wjson.get("已领", true)
	上次周常日 = int(wjson.get("日", 0))
	随机事件冷却 = data.get("randcd", {})
	随机事件类型冷却 = data.get("rtypecd", {})
	quest_cooldown = data.get("qcd", {})
	# P0 目标链：新手阶梯状态（老档默认 false/[]，向后兼容）
	新手目标链激活 = data.get("newbie_active", false)
	新手完成列表 = data.get("newbie_done", [])
	# 老档或空任务：补刷一次，保证面板非空
	if 当前日常.is_empty():
		刷新日常任务()
	if 当前周常.is_empty():
		刷新周常()

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

# 存档数值合法性兜底：负值修正为 0（防坏档负数崩溃）
func _修正负值(v: int, 名: String) -> int:
	if v < 0:
		push_warning("存档校验：%s 为负(%d)，已兜底修正为 0" % [名, v])
		return 0
	return v

# 存档数值合法性兜底：区间夹取（越界则 clamp 并告警）
func _修正区间(v: int, lo: int, hi: int, 名: String) -> int:
	if v < lo or v > hi:
		push_warning("存档校验：%s=%d 越界[%d,%d]，已夹取修正" % [名, v, lo, hi])
		return clampi(v, lo, hi)
	return v

# 版本升级备份：新版本首次加载旧档时，保留一份升级前存档（时间戳命名，避免覆盖）
func _版本升级备份(旧版本: int):
	var da: DirAccess = DirAccess.open("user://")
	if not da:
		return
	if not FileAccess.file_exists("user://save.json"):
		return
	var ts: int = int(Time.get_unix_time_from_system())
	var 目标: String = "save_backup_v%d_%d.json" % [旧版本, ts]
	da.copy("save.json", 目标)
	push_warning("检测到存档升级 v%d→v%d，已备份旧档至 user://%s" % [旧版本, SAVE_VERSION, 目标])

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
	灵草 = 0
	矿石 = 0
	灵气 = 0
	贡献点 = 0
	玄玉 = 0
	弟子列表.clear()
	灵兽蛋列表.clear()
	灵兽库存.clear()
	灵兽兑换队列.clear()
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
	堂口状态存档.clear()
	推演日志.clear()
	体力 = 50
	已通关关卡.clear()
	精英每日次数.clear()
	# P1：周期评分状态复位
	上次结算年 = 0
	年始灵石 = 灵石
	年始总战力 = 0
	最新周期评级卡 = {}
	历史周期评级 = []
	周期评分.历史 = []
	周期评分.计数 = {"灵石获取": 0, "稀有道具": 0, "突破": 0, "高品质新弟子": 0, "首通": 0}
	# S0 任务/商店系统复位
	宗门库房.clear()
	坊市购买记录.clear()
	坊市上架集 = []
	坊市类别月购.clear()
	坊市月购窗口起始日 = 0
	随机事件类型冷却 = {}
	quest_cooldown = {}
	# P0 目标链：新手阶梯复位
	新手目标链激活 = false
	新手完成列表 = []
	当前日常.clear()
	日常已领.clear()
	当前周常.clear()
	周常已领 = true
	随机事件冷却.clear()
	# 3. 重新初始化
	初始建宗()
	刷新日常任务()
	刷新周常()
	重建堂口()
	弟子变动.emit()

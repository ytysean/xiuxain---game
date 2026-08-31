# game_state.gd —— 宗门全局状态（Autoload 单例，名称设为"Game"）
# M1.5：时间推演（自动养成 / 12 司职 / 测灵根招徒 / 门派等级声望 / 汇总报表）
# 移除手动「结算一日」「派遣历练」，改由登录时自动推演 elapsed 现实时间。
extends Node
const Disciple = preload("res://disciple.gd")
const Item = preload("res://item.gd")
const Beast = preload("res://beast.gd")
const Lore = preload("res://lore.gd")
const Quest = preload("res://quest.gd")
const BattleManager = preload("res://BattleManager.gd")   # ADR-003 D1/D6：战斗编排层（纯逻辑，无 Game 依赖）
const StageDataLoader = preload("res://StageDataLoader.gd")   # Day 2 秘境数据层（纯数据，无 Game 依赖）
const DestinyDataLoader = preload("res://DestinyDataLoader.gd")   # 命格数据层（纯数据，无 Game 依赖）
const PeriodSettlementScript = preload("res://period_settlement.gd")   # P1：周期结算评分模块
# 时间流速：240 现实秒 = 1 游戏日；按 360 日/游戏年折算，1 现实天 ≈ 1 游戏年
# === S1 端口：时辰历法换算层 ===
# 调用位置：所有周期玩法（刷新/结算/突破冷却）读取「游戏日」处，应在读取前经此层换算为「时辰→日→月→年」。
# 入参：游戏日(int) | 返回值：Dict{时辰, 日, 月, 年} 或统一游戏内时间戳（S1 定）
# 状态：当前未建，仅标记；现役仍用累计游戏日裸整数。依赖：时间换算层（见 §时间体系修真化）。
const 现实秒每游戏日 := 240.0
const 单次推演上限日 := 3650
const SAVE_VERSION := 4   # 存档结构版本号：损坏检测与跨版本兼容用。v4：品质名称统一（品→阶），傀儡/藏书阁/宝箱/碎片系统品质已统一为阶；v3：新增阵营任务/商店、道友互动（拜访/切磋/结义）、探索事件分支选择系统；旧档载入时版本不符将自动备份并迁移
# 多账号系统（v1）：当前登录账号 id 与注册表路径；不改 SAVE_VERSION，存档结构不变，仅按 id 寻址
var 当前账号id: String = ""
const 账号注册表路径: String = "user://profiles/index.json"
var 灵石 := 1000
var 灵草 := 0
var 矿石 := 0
var 灵气 := 0
var 仓库: Array = []  # 宗门公共物品仓库（丹药/灵材/装备等Item对象）
var 炼器经验值: int = 0  # 炼器系统经验值，用于提升炼器等级（不升SAVE_VERSION，旧档默认0）
var 灵田地块: Array = []  # 灵田种植数据
var 矿脉矿点: Array = []  # 矿脉开采数据
var 悟道点: int = 0  # 藏经阁产出，用于学习功法
var 招募冷却剩余: int = 0  # 接引殿招募冷却（游戏日）
var 阵法等级: Dictionary = {}  # 阵法堂：阵法ID→等级
var 阵法耐久度: Dictionary = {}  # 阵法堂：阵法ID→当前耐久度（旧档缺键→默认满耐久）
var 阵法驻守弟子: Dictionary = {}  # 阵法堂：阵法ID→驻守弟子ID列表
var 贡献点 := 0
# === 灵讯（邮件）系统：全新域，纯新增不改动既有数据层逻辑 ===
# 邮件列表：Array[Dictionary]，元素键：发件人/标题/内容/时间/附件(Dict 资源：/未读/已领
var 邮件列表: Array = []
var 玄榜虚拟宗门: Array = []   # 玄榜（排行榜）：种子化虚拟对手宗门，单机填榜（不升SAVE_VERSION）
# 战斗模式设置："full"完整结算 / "quick"速算（加速战斗，使用期望值计算，不影响最终结果分布）
var 战斗模式: String = "full"   # 默认完整结算，玩家可在设置中切换为速算
# 碎片合成系统：碎片库存（碎片ID → 数量）
var 碎片库存: Dictionary = {}   # 旧档缺键→默认空Dict，零回归（不升SAVE_VERSION）
# 宝箱系统：宝箱库存（宝箱ID → 数量）
var 宝箱库存: Dictionary = {}   # 旧档缺键→默认空Dict，零回归（不升SAVE_VERSION）
# === S1 ：：阶位轴试炼经济参数（全：[PLACEHOLDER]，待数：GDD/CSV 校准，不影响 F5：==
const 试炼成本: int = 50          # 发起单次试炼行政成本（贡献点：
const 试炼失败扣减: int = 50      # 失败额外扣减（叠加行政成本，单次失败：-1000
const 试炼贡献阈值: int = 300     # 贡献点→成功率加成满值门槛
const 破格声望阈值: int = 5000    # D5：声望≥此值且立大功方可破格升一阶
const 试炼冷却日: int = 7         # 失败冷却（游戏日）
# 司职阶位门槛映射（阶位索引：0=执事,1=堂主,2=长老阶：3=供奉：1=不可任）：
# 对齐实际 Lore.司职定义（现：12 司职）；GDD §7.2 所：shanzhen/hushan/baoku/yanwu/xixi/wudao
# 在现：Lore 中不存在，已按实：key 对齐。供奉档无对应司职（供奉阶位仍可经试炼取得）：
const 司职阶位门槛: Dictionary = {
	"yuying": 0, "lingtian": 0, "kuangmai": 0,        # 基础资源/接引：执事起
	"dantang": 1, "qitang": 1, "cangjing": 1, "zhifa": 1, "tanwei": 1, "gongxun": 1,  # 功能司职：堂主起
	"yushou": 2, "zhenfa": 2, "xichi": 2,             # 核心司职：长老阶位起
}
# S1 ：：立大功标记（运行时态，不持久化；D5 破格条件3：声望≥阈值且刚立大功：
var 立大功标记: Dictionary = {}
# 仙玉体系（绑：非绑定）：S0 起唯一氪金货币（可充值可游戏内产出）；玄玉已合并废弃
var 仙玉_绑定: int = 0
var 仙玉_非绑定: int = 0
var 付费增益值: float = 0.0             # S1-4 付费buff战斗通用增益(%)，并入 disciple.聚合通用增益 共享25/30封顶
var 历练额外次数: int = 0              # S1-4 付费购买的历练额外次数（突破今日/本周已完成限制）
# 改名卡：宗主详情页改名消耗品，可用仙玉购买（S1 新增：
var 改名卡数量: int = 0
const 改名卡仙玉价格: int = 100  # 单张改名卡售价（仙玉，优先扣绑定）
var 弟子列表: Array[Disciple] = []   # 强类型数组（需 disciple.gd 已注册class_name：
# 御兽堂：孵化中的灵兽：+ 已孵化待绑定的灵兽库：
var 灵兽蛋列表: Array[Beast] = []
var 灵兽库存: Array[Beast] = []
var 灵兽兑换队列: Array[Dictionary] = []   # T03：引育计划队列（{偏好,cost,启用}），周期结算执行
# === 创建宗门页（开宗捏脸）数据：===
# 玩家自定义：宗门：/ 宗主名/ 宗主性别 / 宗主头像（头像选择系统，替代旧三层捏脸 idx：
# 说明：此前铁律「数据层只读不可动」，本次经用户授权为闭合开宗链路补写底层字段（2026-08-14）：
const 宗主性别预设: Array = ["男", "女"]            # 性别枚举（对应sect_master 资源 male/female 文件夹）
var 宗门名: String = "太玄宗"                       # 与top_bar FALLBACK_宗门名一致；旧档缺键→默认回退
var 宗主名: String = "太虚道君"
var 宗主性别: String = "男"
var 宗主头像: String = ""          # 创建宗门·选中头像 id（头像选择系统，替代旧三层捏脸：
var 当前宗主皮肤: String = ""       # 当前装备的宗主皮肤ID："=无皮肤，使用基础立绘：
var 已拥有宗主皮肤: Array = []      # 已拥有的宗主皮肤ID列表
# 头像框功能已取消：026-08-21）：原头像框变量：catalog 一并移除；下方计数器与累充仅用：VIP 玉牌品阶派生：
var 奇遇完成总数: int = 0          # 计数器②：完成「奇遇总数」次数（全稀有度：
var 高级奇遇完成数: int = 0        # 计数器①：完成「高级奇遇」次数（稀有/上品/极品/天品）
var 已首充: bool = false           # 首充标记（任意金额首次充值即为true）
var 累充额: int = 0                # 累充金额（元/RMB，只增不减；派生 VIP 等级，仅外观判定用）
var 已解锁头像: Array = []         # 已解锁头像id 列表（一渠道双解锁：渠道可同时解锁头像）
# 宗主头像目录：创建宗门页可选头：catalog（initial=初始可选/ unlock=渠道解锁占位：
# 每条：id | name | gender ：：| tex 全立绘路：详情页用) | avatar 圆头像素描路：顶栏/弹窗/创建页用) | category initial/unlock | channel 解锁渠道标签(仅unlock) | unlocked 是否解锁
const 宗主头像目录: Array = [
	# —：初始可选（复用已有 master 成品图占位，后续替换 tex 为正式头像美术）—：
	{"id":"m_daopao", "name":"青袍宗主", "gender":"男", "tex":"res://art/characters/masters/master_male_daopao.png", "category":"initial", "channel":"", "unlocked":true, "avatar":"res://art/characters/masters_circle/master_male_daopao.png"},
	{"id":"m_zhanjia", "name":"金甲宗主", "gender":"男", "tex":"res://art/characters/masters/master_male_zhanjia.png", "category":"initial", "channel":"", "unlocked":true, "avatar":"res://art/characters/masters_circle/master_male_zhanjia.png"},
	{"id":"m_suyi", "name":"素衣宗主", "gender":"男", "tex":"res://art/characters/masters/master_male_suyi.png", "category":"initial", "channel":"", "unlocked":true, "avatar":"res://art/characters/masters_circle/master_male_suyi.png"},
	{"id":"f_daopao", "name":"青袍宗主", "gender":"女", "tex":"res://art/characters/masters/master_female_daopao.png", "category":"initial", "channel":"", "unlocked":true, "avatar":"res://art/characters/masters_circle/master_female_daopao.png"},
	{"id":"f_zhanjia", "name":"金甲宗主", "gender":"女", "tex":"res://art/characters/masters/master_female_zhanjia.png", "category":"initial", "channel":"", "unlocked":true, "avatar":"res://art/characters/masters_circle/master_female_zhanjia.png"},
	{"id":"f_suyi", "name":"素衣宗主", "gender":"女", "tex":"res://art/characters/masters/master_female_suyi.png", "category":"initial", "channel":"", "unlocked":true, "avatar":"res://art/characters/masters_circle/master_female_suyi.png"},
	{"id":"m_ruyi", "name":"儒衫文士", "gender":"男", "tex":"res://art/characters/masters/master_male_ruyi.png", "category":"initial", "channel":"", "unlocked":true, "avatar":"res://art/characters/masters_circle/master_male_ruyi.png"},
	{"id":"m_jinyi", "name":"锦衣贵胄", "gender":"男", "tex":"res://art/characters/masters/master_male_jinyi.png", "category":"initial", "channel":"", "unlocked":true, "avatar":"res://art/characters/masters_circle/master_male_jinyi.png"},
	{"id":"m_yexing", "name":"夜行暗影", "gender":"男", "tex":"res://art/characters/masters/master_male_yexing.png", "category":"initial", "channel":"", "unlocked":true, "avatar":"res://art/characters/masters_circle/master_male_yexing.png"},
	{"id":"f_nichang", "name":"霓裳仙姝", "gender":"女", "tex":"res://art/characters/masters/master_female_nichang.png", "category":"initial", "channel":"", "unlocked":true, "avatar":"res://art/characters/masters_circle/master_female_nichang.png"},
	{"id":"f_rongzhuang", "name":"戎装巾帼", "gender":"女", "tex":"res://art/characters/masters/master_female_rongzhuang.png", "category":"initial", "channel":"", "unlocked":true, "avatar":"res://art/characters/masters_circle/master_female_rongzhuang.png"},
	{"id":"f_susha", "name":"素纱清修", "gender":"女", "tex":"res://art/characters/masters/master_female_susha.png", "category":"initial", "channel":"", "unlocked":true, "avatar":"res://art/characters/masters_circle/master_female_susha.png"},
	# —：渠道解锁：秘境探索（古剑：灵兽：星陨：幽冥：丹霞：寒玉冰渊 × 男女各一套）—：
	{"id":"m_secret_jianzhong", "name":"幽冢剑客", "gender":"男", "tex":"res://art/characters/masters/master_male_secret_jianzhong.png", "category":"unlock", "channel":"秘境探索", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_male_secret_jianzhong.png"},
	{"id":"m_secret_lingshou", "name":"驭兽灵修", "gender":"男", "tex":"res://art/characters/masters/master_male_secret_lingshou.png", "category":"unlock", "channel":"秘境探索", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_male_secret_lingshou.png"},
	{"id":"m_secret_xingyun", "name":"星陨道君", "gender":"男", "tex":"res://art/characters/masters/master_male_secret_xingyun.png", "category":"unlock", "channel":"秘境探索", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_male_secret_xingyun.png"},
	{"id":"m_secret_youming", "name":"幽冥修士", "gender":"男", "tex":"res://art/characters/masters/master_male_secret_youming.png", "category":"unlock", "channel":"秘境探索", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_male_secret_youming.png"},
	{"id":"m_secret_danxia", "name":"丹霞道君", "gender":"男", "tex":"res://art/characters/masters/master_male_secret_danxia.png", "category":"unlock", "channel":"秘境探索", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_male_secret_danxia.png"},
	{"id":"m_secret_hanyu", "name":"寒玉真君", "gender":"男", "tex":"res://art/characters/masters/master_male_secret_hanyu.png", "category":"unlock", "channel":"秘境探索", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_male_secret_hanyu.png"},
	{"id":"f_secret_jianzhong", "name":"幽冢仙子", "gender":"女", "tex":"res://art/characters/masters/master_female_secret_jianzhong.png", "category":"unlock", "channel":"秘境探索", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_female_secret_jianzhong.png"},
	{"id":"f_secret_lingshou", "name":"驭灵仙姬", "gender":"女", "tex":"res://art/characters/masters/master_female_secret_lingshou.png", "category":"unlock", "channel":"秘境探索", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_female_secret_lingshou.png"},
	{"id":"f_secret_xingyun", "name":"星陨灵姬", "gender":"女", "tex":"res://art/characters/masters/master_female_secret_xingyun.png", "category":"unlock", "channel":"秘境探索", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_female_secret_xingyun.png"},
	{"id":"f_secret_youming", "name":"幽冥玄女", "gender":"女", "tex":"res://art/characters/masters/master_female_secret_youming.png", "category":"unlock", "channel":"秘境探索", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_female_secret_youming.png"},
	{"id":"f_secret_danxia", "name":"丹霞仙姬", "gender":"女", "tex":"res://art/characters/masters/master_female_secret_danxia.png", "category":"unlock", "channel":"秘境探索", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_female_secret_danxia.png"},
	{"id":"f_secret_hanyu", "name":"寒玉冰仙", "gender":"女", "tex":"res://art/characters/masters/master_female_secret_hanyu.png", "category":"unlock", "channel":"秘境探索", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_female_secret_hanyu.png"},
	# ——渠道解锁：宗门晋升（宗主/太上长老/护法神将/丹道尊/剑阁之主/符箓天师 × 男女各一套）——
	{"id":"m_rank_zongzhu", "name":"太宗主尊", "gender":"男", "tex":"res://art/characters/masters/master_male_rank_zongzhu.png", "category":"unlock", "channel":"宗门晋升", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_male_rank_zongzhu.png"},
	{"id":"m_rank_taishang", "name":"太上玄翁", "gender":"男", "tex":"res://art/characters/masters/master_male_rank_taishang.png", "category":"unlock", "channel":"宗门晋升", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_male_rank_taishang.png"},
	{"id":"m_rank_hufa", "name":"护法神将", "gender":"男", "tex":"res://art/characters/masters/master_male_rank_hufa.png", "category":"unlock", "channel":"宗门晋升", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_male_rank_hufa.png"},
	{"id":"m_rank_dandao", "name":"丹道尊", "gender":"男", "tex":"res://art/characters/masters/master_male_rank_dandao.png", "category":"unlock", "channel":"宗门晋升", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_male_rank_dandao.png"},
	{"id":"m_rank_jiange", "name":"剑阁之主", "gender":"男", "tex":"res://art/characters/masters/master_male_rank_jiange.png", "category":"unlock", "channel":"宗门晋升", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_male_rank_jiange.png"},
	{"id":"m_rank_fulu", "name":"符箓天师", "gender":"男", "tex":"res://art/characters/masters/master_male_rank_fulu.png", "category":"unlock", "channel":"宗门晋升", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_male_rank_fulu.png"},
	{"id":"f_rank_zongzhu", "name":"宗主凤尊", "gender":"女", "tex":"res://art/characters/masters/master_female_rank_zongzhu.png", "category":"unlock", "channel":"宗门晋升", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_female_rank_zongzhu.png"},
	{"id":"f_rank_taishang", "name":"太上玄姬", "gender":"女", "tex":"res://art/characters/masters/master_female_rank_taishang.png", "category":"unlock", "channel":"宗门晋升", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_female_rank_taishang.png"},
	{"id":"f_rank_hufa", "name":"护法神将", "gender":"女", "tex":"res://art/characters/masters/master_female_rank_hufa.png", "category":"unlock", "channel":"宗门晋升", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_female_rank_hufa.png"},
	{"id":"f_rank_dandao", "name":"丹道尊", "gender":"女", "tex":"res://art/characters/masters/master_female_rank_dandao.png", "category":"unlock", "channel":"宗门晋升", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_female_rank_dandao.png"},
	{"id":"f_rank_jiange", "name":"剑阁之主", "gender":"女", "tex":"res://art/characters/masters/master_female_rank_jiange.png", "category":"unlock", "channel":"宗门晋升", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_female_rank_jiange.png"},
	{"id":"f_rank_fulu", "name":"符箓天师", "gender":"女", "tex":"res://art/characters/masters/master_female_rank_fulu.png", "category":"unlock", "channel":"宗门晋升", "unlocked":false, "avatar":"res://art/characters/masters_circle/master_female_rank_fulu.png"},
]
# 待抉择队列：弟子获得的极：特殊道具，等待玩家决定“交宗换贡献”或“弟子自留：
var 待抉择: Array[Dictionary] = []
# 奇遇待抉择队列（ADR-002 D4）：： 奇遇需掌门干预；结：{弟子, 奇遇： 选项}；会话瞬时，load 时清空
var 奇遇待抉择: Array[Dictionary] = []
# 宗门纪事（完善版）：分类记录宗门大事，持久化存储
# 分类：大事件（宗门里程碑）、岁纪（年度总结）、庶务（日常运营）、异闻（稀有奇遇）
var 宗门纪事: Array = []
const 纪事分类 = ["大事件", "岁纪", "庶务", "异闻"]
var 最后查看纪事时间: float = 0.0  # 最后查看纪事的时间戳，用于判断未读纪事
## 判断是否有未读纪事
func 有未读纪事() -> bool:
	if 宗门纪事.is_empty():
		return false
	var 最新纪事 = 宗门纪事[0]
	var 时间戳: float = float(最新纪事.get("时间戳", 0.0))
	return 时间戳 > 最后查看纪事时间
## 标记纪事为已读
func 标记纪事已读() -> void:
	最后查看纪事时间 = Time.get_unix_time_from_system()
# 添加纪事记录
func 添加纪事(分类: String, 标题: String, 内容: String = "", 重要度: int = 1) -> void:

	if not 纪事分类.has(分类):
		分类 = "庶务"
	var 记录 = {
		"分类": 分类,
		"标题": 标题,
		"内容": 内容,
		"重要度": 重要度,  # 1-普通，2-重要度-重大
		"游戏日": 累计游戏日,
		"时间戳": Time.get_unix_time_from_system(),
	}
	宗门纪事.insert(0, 记录)  # 倒序插入，最新的在最前面
	# 限制纪事数量，最多保：00：
	if 宗门纪事.size() > 500:
		宗门纪事.resize(500)
# 按分类获取纪：
func 获取纪事(分类: String = "全部", 数量: int = 50) -> Array:

	if 分类 == "全部":
		return 宗门纪事.slice(0, min(数量, 宗门纪事.size()))
	var 结果: Array = []
	for 记录 in 宗门纪事:
		if 记录.get("分类", "") == 分类:
			结果.append(记录)
			if 结果.size() >= 数量:
				break
	return 结果
# WAVE-C #3：先贤祠（坐化弟子静态档案，持久化于存档；纯展示，零数值，传承+5% deferred；不持有 Disciple 引用，防悬空：
var 先贤堂: Array = []
# WAVE-D #6 宗门收藏图录 + #8 宗门里程：传承：
# 红线约束：6 裁决 §：/ pre_f5 ：闸）：增益只走「产出池轴」或「声望轴」，严禁写入永久全局 buff：
# 产出池轴全宗累加 ：0%（运行时 clamp 兜底）。零经济改动（不新增 灵石/产出/消：节点）：
var 收藏图录_已收集: Dictionary = {}   # 类别 -> Array[匹配名]（已收录：
var 产出池加成: float = 0.0            # 产出池轴累加器（图录集齐 + 里程碑产出池赏赐），clamp 0..0.30
var 图录配置: Array = []
var 里程碑配置: Array = []
var 里程碑_已达成: Array = []          # 已达成里程碑ID（持久化：
# S1 ：：成就系统（核心骨架+安全子集；CSV 驱动：9 条接线+ 145 ：placeholder 容错跳过；不升SAVE_VERSION）
var 成就配置: Array = []
var 成就_已达成: Array= []            # 已达成成就ID（持久化；旧档缺键→load ：.get 默认空数组，零回归）
var 捐赠记录: Dictionary = {}          # 图录ID -> true（稀有藏品已捐藏宝库：
var 传承史册: Array = []               # 持久化史册（图录集齐 + 里程碑，复用 #2 纪事结构；独立于会话瞬时 宗门纪事：
# ============ 彩蛋系统（第一批·真零成本子：+ 轻量底座：===========
# 全局开关：一键关闭所有彩蛋数值加成（仅保留文：交互），兜底平衡风险
var 彩蛋启用: bool = true
# 单ID屏蔽集：egg_id -> true 表示屏蔽该彩蛋（出问题精准止损，无需回滚：
var 彩蛋屏蔽表: Dictionary = {}
# 配置表（：_加载彩蛋配置 ：config/easter_egg_config.csv 读入：
var 彩蛋配置表: Array = []
# 节奏校准配置表（双周期评级配套系统：招徒/随机事件/奇遇/稳固：瓶颈打磨，由 _加载节奏校准 ：config/节奏校准.csv 读入：
var 节奏校准: Dictionary = {}
# 临时增益（当日生效）：dim -> {"pct":float, "到期日:int}；接入产：修炼加法管线
var 彩蛋临时增益: Dictionary = {}
# 数值红线常量（：pre_f5 断言双保险）：单彩蛋：%、永久全局：%
const 彩蛋单上限: float = 0.05
const 彩蛋永久总上限: float = 0.03
# ===== 增益数值红线（全游戏统一，所有buff遵守；与 pre_f5 断言双保险）=====
# 单位：百分比整数（与 config/*.csv ：buff_pct 列一致，0-5 ：0%~5%：
const 增益单条上限: float = 5.0       # 任意类型单条buff：%（彩：付费/活动/殿阁，永久限时统一：
const 增益永久全局上限: float = 3.0  # 永久类全局总增益≤3%（与彩蛋永久红线对齐：
const 增益限时全局上限: float = 8.0  # 限时类全局总增益≤8%（全局总和上限，非单条：
# 通用增益(战斗)：5%/：0% ：disciple.gd _clamp_soft(...,0.25,0.30,0.2)，付费buff并入同池共享封顶
# ===== 付费预留接入点（S0 stub：全部置灰，当前不生效，S1 接真实支：广告后端：====
const 付费单价: Dictionary = {
	"修炼加速": 20,   # 全体弟子推进7游戏日修炼
	"灵兽孵化": 30,   # 立即完成所有孵化中灵兽
	"坊市刷新": 5,    # 手动刷新坊市上架
	"历练额外": 15,   # +1次历练（突破今日/本周限制）
	"殿阁产出": 25,   # 立即发放预估月产出(灵石)
	"全局增益": 50,   # +5%战斗通用增益(共享封顶)
}
# 统一前缀 _pay_reserved_，全局可检索；每个对应一个未来付费功能入口：
func _pay_reserved_修炼加成() -> Dictionary:

	# S1 付费：消耗仙玉立即完成N天修炼进度（全体弟子）
	var 价: int = 付费单价.get("修炼加速", 20)
	if not 消耗仙玉_付费(价):
		return {"成功": false, "原因": "仙玉不足"}
	var 天数: float = 7.0
	for d in 弟子列表:
		if d != null and d.has_method("推进修炼"):
			d.推进修炼(天数)
	记任务进度("pay_accelerate_cultivate")
	return {"成功": true, "天数": 天数, "弟子数": 弟子列表.size()}
func _pay_reserved_灵兽加成() -> Dictionary:

	# S1 付费：消耗仙玉立即完成孵化中灵兽（兼容 Beast 实例与字典两种形态）
	var 价: int = 付费单价.get("灵兽孵化", 30)
	if not 消耗仙玉_付费(价):
		return {"成功": false, "原因": "仙玉不足"}
	var 完成数: int = 0
	for 兽 in 灵兽蛋列表:
		if 兽 == null:
			continue
		var 孵化中: bool = false
		if 兽 is Beast:
			孵化中 = 兽.孵化中
		elif 兽 is Dictionary:
			孵化中 = bool(兽.get("孵化中", false))
		if not 孵化中:
			continue
		if 兽 is Beast:
			兽.孵化()
		elif 兽 is Dictionary:
			兽["孵化中"] = false
			兽["剩余天数"] = 0
		完成数 += 1
	记任务进度("pay_hatch_beast")
	return {"成功": true, "完成数": 完成数}
func _pay_reserved_坊市购买() -> Dictionary:

	# S1 付费：仙玉手动刷新坊市上架
	var 价: int = 付费单价.get("坊市刷新", 5)
	if not 消耗仙玉_付费(价):
		return {"成功": false, "原因": "仙玉不足"}
	刷新坊市上架()
	记任务进度("pay_refresh_market")
	return {"成功": true}
func _pay_reserved_历练购买() -> Dictionary:

	# S1 付费：仙玉购买历练额外次数（突破今日/本周已完成限制）
	var 价: int = 付费单价.get("历练额外", 15)
	if not 消耗仙玉_付费(价):
		return {"成功": false, "原因": "仙玉不足"}
	历练额外次数 += 1
	记任务进度("pay_expedition_extra")
	return {"成功": true, "剩余额外": 历练额外次数}
func _pay_reserved_殿阁加成() -> Dictionary:

	# S1 付费：仙玉立即领取殿阁产出（发放预估月产出灵石，不与月底月度结算重复）
	var 价: int = 付费单价.get("殿阁产出", 25)
	if not 消耗仙玉_付费(价):
		return {"成功": false, "原因": "仙玉不足"}
	var 额: int = 预估月产出()
	灵石 += 额
	记任务进度("pay_collect_hall")
	return {"成功": true, "额": 额}
func _pay_reserved_全局增益() -> Dictionary:

	# S1 付费：付费buff统一入口，累加战斗通用增益(%)；并入 disciple.聚合通用增益() 共享25/30%封顶
	var 价: int = 付费单价.get("全局增益", 50)
	if not 消耗仙玉_付费(价):
		return {"成功": false, "原因": "仙玉不足"}
	付费增益值 += 0.05   # +5%
	记任务进度("pay_global_buff")
	return {"成功": true, "当前增益": 付费增益值}
# 引育纪事配置读取（S1：按 品阶×类型 匹配差异化纪事文案，：：道标异闻；纯配置驱动，零数值）
func _引育纪事表() -> Array:

	var 结果: Array = []
	for r in DestinyDataLoader._read_csv("res://config/引育纪事.csv"):
		结果.append(r)
	return 结果
func _引育纪事文案(兽: Beast) -> Dictionary:

	var 兽种类名: String = 兽.种类名
	var 兽种类: String = 兽.品阶
	var 兽类型: String = 兽.beast_type
	var 表: Array = _引育纪事表()
	for r in 表:
		if r.get("品阶") if "品阶" in r else "" == 兽种类 and r.get("类型") if "类型" in r else "" == 兽类型:
			return {"文案": r.get("文案") if "文案" in r else "".replace("{种类}", 兽种类名), "category": r.get("category") if "category" in r else ""}
	for r in 表:
		if r.get("品阶") if "品阶" in r else "" == 兽种类 and r.get("类型") if "类型" in r else "" == "通用":
			return {"文案": r.get("文案") if "文案" in r else "".replace("{种类}", 兽种类名), "category": r.get("category") if "category" in r else ""}
	for r in 表:
		if r.get("品阶") if "品阶" in r else "" == "通用" and r.get("类型") if "类型" in r else "" == 兽类型:
			return {"文案": r.get("文案") if "文案" in r else "".replace("{种类}", 兽种类名), "category": r.get("category") if "category" in r else ""}
	for r in 表:
		if r.get("品阶") if "品阶" in r else "" == "通用" and r.get("类型") if "类型" in r else "" == "通用":
			return {"文案": r.get("文案") if "文案" in r else "".replace("{种类}", 兽种类名), "category": r.get("category") if "category" in r else ""}
	return {"文案": 文案表["breed_egg_got"] % 兽种类名, "category": ""}
# ===== S0 差事/商店系统状态（2026-07-21 新增；不升SAVE_VERSION，load ：.get 默认向后兼容：====
var 宗门库房: Array = []                 # 坊市购买所得物品（Item 实例化
var 坊市上架集: Array = []               # 本周上架 shop_id 列表（周刷新随机数-12件）
var 坊市购买记录: Dictionary = {}         # shop_id -> {daily, weekly, week_start}
var 坊市类别月购: Dictionary = {}         # D2：类：-> 本月已购数量（月度限购）
var 坊市月购窗口起始日: int = 0           # D2：类别月度限购30 天窗口起始日
# WAVE-C #7：宗门集市（每月 15-17 日定时刷新消费者；仅刷新规则，零经济）
var 坊市稀有标记: Dictionary = {}         # shop_id -> true：集市期间「稀有商队」展示标记（纯展示，零经济）
var 坊市上架_集市标记: bool = false       # 当前 坊市上架集是否按集市规则生成（用于页面一致性校验）
var 坊市回购列表: Array = []              # 坊市误售找回池（{名称,品阶,类别,：快照}），上限 5
var 坊市每日特惠: Array = []              # 每日特惠：[{shop_id, 倍率}]：-9折），按累计游戏日轮换
var 坊市特惠卡: int = -1                  # 每日特惠最后刷新日（按累计游戏日，跨日自动轮换：
var 宗门集市配置缓存: Dictionary = {}     # 懒加：config/宗门集市配置.csv；缺失→常量回退（No-op 安全：
# ===== 商队派遣系统 =====
var 商队列表: Array = []  # 正在派遣的商队列：[{id, 地区, 出发日 预计返回日 货物, 弟子ID, 状态}]
var 商队历史: Array = []  # 商队历史记录
const 商队地区: Array = [
	{"id": "附近城镇", "名称": "附近城镇", "距离": 1, "特产": "灵草", "收购价": 1.2, "风险": 0.05},
	{"id": "修真集市", "名称": "修真集市", "距离": 3, "特产": "矿石", "收购价": 1.5, "风险": 0.10},
	{"id": "仙城坊市", "名称": "仙城坊市", "距离": 7, "特产": "法器", "收购价": 2.0, "风险": 0.15},
	{"id": "秘境边境", "名称": "秘境边境", "距离": 15, "特产": "天材地宝", "收购价": 3.0, "风险": 0.25},
]
var 商队ID计数器: int= 0
# 派遣商队
func 派遣商队(地区ID: String, 货物列表: Array, 弟子ID: int = -1) -> Dictionary:

	var 地区 = null
	for d in 商队地区:
		if d["id"] == 地区ID:
			地区 = d
			break
	if 地区 == null:
		return {"成功": false, "消息": "未知地区"}
	# 检查货：
	var 货物总价值= 0
	for 货物 in 货物列表:
		货物总价值+= int(货物.get("价", 0))
	if 货物总价值<= 0:
		return {"成功": false, "消息": "货物为空"}
	# 检查灵石（商队启动资金：
	var 启动资金 = int(货物总价值* 0.1)
	if 灵石 < 启动资金:
		return {"成功": false, "消息": "灵石不足，需要启动资金%d" % 启动资金}
	灵石 -= 启动资金
	# 创建商队
	商队ID计数器+= 1
	var 商队 = {
		"id": 商队ID计数器,
		"地区": 地区ID,
		"地区名": 地区["名称"],
		"出发日": 累计游戏日,
		"预计返回日": 累计游戏日+ 地区["距离"] * 2,
		"货物": 货物列表,
		"货物价值": 货物总价值,
		"弟子ID": 弟子ID,
		"状态": "派遣中",
	}
	商队列表.append(商队)
	添加纪事("庶务", "商队出发", "商队前往%s贸易，货物价值%d灵石" % [地区["名称"], 货物总价值], 1)
	return {"成功": true, "消息": "商队已出发，预计%d日后返回" % (地区["距离"] * 2), "商队ID": 商队ID计数器}
# 结算返回的商：
func 结算商队(商队: Dictionary) -> Dictionary:

	var 地区 = null
	for d in 商队地区:
		if d["id"] == 商队["地区"]:
			地区 = d
			break
	if 地区 == null:
		return {"成功": false, "消息": "未知地区"}
	# 计算收益
	var 基础收益 = int(商队["货物价值"] * 地区["收购价"])
	# 风险判定
	var 随机值= randf()
	var 实际收益 = 基础收益
	var 事件 = "顺利贸易"
	if 随机值< 地区["风险"]:
		# 遭遇风险
		var 风险类型 = randf()
		if 风险类型 < 0.4:
			实际收益 = int(基础收益 * 0.5)
			事件 = "遭遇山贼，损失一半货："
		elif 风险类型 < 0.7:
			实际收益 = int(基础收益 * 0.8)
			事件 = "路途颠簸，部分货物损坏"
		else:
			实际收益 = 0
			事件 = "商队失踪，全部货物损："
	elif 随机值> 1.0 - 0.1:  # 10%概率偶遇高人
		实际收益 = int(基础收益 * 1.5)
		事件 = "偶遇高人指点，贸易大获成："
	elif 随机值> 1.0 - 0.15:  # 5%概率发现宝藏
		实际收益 = int(基础收益 * 1.3)
		灵石 += 500  # 额外发现宝藏
		事件 = "途中发现古代宝藏，额外获：00灵石"
	elif 随机值> 1.0 - 0.2:  # 5%概率遇到同行
		实际收益 = int(基础收益 * 1.1)
		增加阵营声望("散修联盟", 10)
		事件 = 文案表["friendly_caravan_event"]
	# 结算
	灵石 += 实际收益
	商队["状态"] = "已返回"
	商队["实际收益"] = 实际收益
	商队["事件"] = 事件
	商队历史.insert(0, 商队)
	if 商队历史.size() > 100:
		商队历史.resize(100)
	添加纪事("庶务", "商队返回", "商队：s返回：s，获：d灵石" % [商队["地区名"], 事件, 实际收益], 1)
	return {"成功": true, "消息": "商队返回：s，获：d灵石" % [事件, 实际收益], "收益": 实际收益}
# 每日更新商队状态
func 更新商队状态() -> void:

	var 待结算: Array = []
	for 商队 in 商队列表:
		if 商队["状态"] == "派遣中" and 累计游戏日>= 商队["预计返回日"]:
			待结算.append(商队)
	for 商队 in 待结算:
		结算商队(商队)
		商队列表.erase(商队)
# ===== 阵营声望系统（v2.0 五大阵营体系：====
# 5大阵营：正道宗门、魔道邪宗、中立散修、上古妖兽、远古遗泽
# 5级声望：冷淡→中立→友善→尊敬→崇敬
# 设计依据：GDD §2.1 五大阵营声望体系
const 阵营列表: Array = ["正道宗门", "魔道邪宗", "中立散修", "上古妖兽", "远古遗泽"]
const 声望等级: Array = ["冷淡", "中立", "友善", "尊敬", "崇敬"]
const 声望阈值: Array = [0, 100, 500, 2000, 5000]  # 各等级所需声望值
var 阵营声望: Dictionary = {
	"正道宗门": 0,
	"魔道邪宗": 0,
	"中立散修": 0,
	"上古妖兽": 0,
	"远古遗泽": 0,
}
# 旧阵营名称映射（向后兼容：旧档的4大阵营自动映射到：大阵营）
const 旧阵营映射: Dictionary = {
	"正道联盟": "正道宗门",
	"魔道势力": "魔道邪宗",
	"散修联盟": "中立散修",
	"皇室官方": "中立散修",  # 皇室官方映射到中立散：
}
# 获取阵营声望等级
func 获取声望等级(阵营: String) -> String:

	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)  # 旧阵营名称自动映：
	var 声望值= 阵营声望.get(实际阵营, 0)
	return FactionSystem.get_reputation_level(声望值)
# 增加阵营声望（对立阵营会降低：
func 增加阵营声望(阵营: String, 数量: int) -> void:

	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)  # 旧阵营名称自动映：
	if not 阵营声望.has(实际阵营):
		return
	阵营声望 = FactionSystem.add_faction_reputation(阵营声望, 实际阵营, 数量)
	添加纪事("庶务", "阵营声望变化", "%s声望+%d" % [实际阵营, 数量], 1)
# 获取阵营声望权益
func 获取阵营权益(阵营: String) -> Dictionary:

	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)
	var 声望值= 阵营声望.get(实际阵营, 0)
	var 等级 = FactionSystem.get_reputation_level(声望值)
	return FactionSystem.get_faction_benefits(等级)
# 获取所有阵营的综合权益（取最高值）
func 获取综合阵营权益() -> Dictionary:

	return FactionSystem.get_comprehensive_benefits(阵营声望)
# 检查玩法是否解锁（新方法）
func 检查玩法解锁(阵营: String, 玩法锁: String) -> bool:

	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)
	var 声望值= 阵营声望.get(实际阵营, 0)
	return FactionSystem.is_feature_unlocked(实际阵营, 声望值, 玩法锁)
# 招贤阁刷新加权抽取（新方法）
func 加权抽取阵营(性格: String = "") -> String:

	return FactionSystem.weighted_recruit_faction(阵营声望, 性格)
# 获取所有阵营声望列表
func 获取所有阵营声望列表() -> Array:
	var 声望列表 = []
	for 阵营 in 阵营声望.keys():
		var 声望值 = 阵营声望[阵营]
		var 等级 = FactionSystem.get_reputation_level(声望值)
		var 权益 = FactionSystem.get_faction_benefits(等级)
		声望列表.append({
			"阵营": 阵营,
			"声望值": 声望值,
			"等级": 等级,
			"权益": 权益,
			"描述": FactionSystem.get_faction_description(阵营),
		})
	return 声望列表

# 获取阵营声望总加成
func 获取阵营声望总加成() -> Dictionary:
	return FactionSystem.get_comprehensive_benefits(阵营声望)

# 获取阵营描述（新方法，用于UI Tooltip：
func 获取阵营描述(阵营: String) -> String:

	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)
	return FactionSystem.get_faction_description(实际阵营)
# ===== 阵营任务和商店系统（v1.0）=====
# 阵营任务配置
var 阵营任务配置: Array = []
# 阵营任务进度 {quest_id: {进度, 已领取}}
var 阵营任务进度: Dictionary = {}
# 阵营商店配置
var 阵营商店配置: Array = []
# 阵营商店购买记录 {item_id: 购买次数}
var 阵营商店购买记录: Dictionary = {}

# 加载阵营任务配置
func _加载阵营任务配置() -> void:
	阵营任务配置 = DestinyDataLoader._read_csv("res://config/faction_quests.csv")
	# 初始化任务进度
	for q in 阵营任务配置:
		var qid: String = str(q.get("quest_id") if "quest_id" in q else "")
		if qid != "" and not 阵营任务进度.has(qid):
			阵营任务进度[qid] = {"进度": 0, "已领取": false}

# 加载阵营商店配置
func _加载阵营商店配置() -> void:
	阵营商店配置 = DestinyDataLoader._read_csv("res://config/faction_shop.csv")

# 获取指定阵营的任务列表
func 获取阵营任务(阵营: String) -> Array:
	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)
	var 任务列表: Array = []
	for q in 阵营任务配置:
		if str(q.get("faction") if "faction" in q else "") == 实际阵营:
			var qid: String = str(q.get("quest_id") if "quest_id" in q else "")
			var 进度: Dictionary = 阵营任务进度.get(qid, {"进度": 0, "已领取": false})
			var 任务: Dictionary = q.duplicate()
			任务["当前进度"] = 进度.get("进度", 0)
			任务["已领取"] = 进度.get("已领取", false)
			任务["是否解锁"] = 检查阵营任务解锁(实际阵营, str(q.get("unlock_reputation") if "unlock_reputation" in 任务 else "冷淡"))
			任务列表.append(任务)
	return 任务列表

# 检查阵营任务是否解锁
func 检查阵营任务解锁(阵营: String, 所需声望等级: String) -> bool:
	var 当前等级: String = 获取声望等级(阵营)
	var 当前索引: int = 声望等级.find(当前等级)
	var 所需索引: int = 声望等级.find(所需声望等级)
	return 当前索引 >= 所需索引

# 更新阵营任务进度
func 更新阵营任务进度(阵营: String, 任务类型: String, 数量: int = 1) -> void:
	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)
	for q in 阵营任务配置:
		if str(q.get("faction") if "faction" in q else "") == 实际阵营 and str(q.get("quest_type") if "quest_type" in q else "") == 任务类型:
			var qid: String = str(q.get("quest_id") if "quest_id" in q else "")
			if not 阵营任务进度.has(qid):
				阵营任务进度[qid] = {"进度": 0, "已领取": false}
			var 目标数: int = int(q.get("target_num") if "target_num" in q else 1)
			var 当前进度: int = int(阵营任务进度[qid].get("进度", 0))
			阵营任务进度[qid]["进度"] = min(当前进度 + 数量, 目标数)

# 领取阵营任务奖励
func 领取阵营任务奖励(任务ID: String) -> Dictionary:
	if not 阵营任务进度.has(任务ID):
		return {"成功": false, "原因": "任务不存在"}
	var 进度: Dictionary = 阵营任务进度[任务ID]
	if 进度.get("已领取", false):
		return {"成功": false, "原因": "奖励已领取"}
	# 找到任务配置
	var 任务配置: Dictionary = {}
	for q in 阵营任务配置:
		if str(q.get("quest_id") if "quest_id" in q else "") == 任务ID:
			任务配置 = q
			break
	if 任务配置.is_empty():
		return {"成功": false, "原因": "任务配置不存在"}
	var 目标数: int = int(任务配置.get("target_num", 1))
	var 当前进度: int = int(进度.get("进度", 0))
	if 当前进度 < 目标数:
		return {"成功": false, "原因": "任务未完成"}
	# 发放奖励
	var 灵石奖励: int = int(任务配置.get("reward_lingjing", 0))
	var 灵气奖励: int = int(任务配置.get("reward_lingqi", 0))
	var 声望奖励: int = int(任务配置.get("reward_reputation", 0))
	var 阵营: String = str(任务配置.get("faction", ""))
	灵石 += 灵石奖励
	灵气 += 灵气奖励
	if 声望奖励 > 0 and 阵营 != "":
		增加阵营声望(阵营, 声望奖励)
	# 标记已领取
	阵营任务进度[任务ID]["已领取"] = true
	添加纪事("庶务", "阵营任务奖励", "完成%s任务，获得%d灵石、%d灵气、%d声望" % [任务配置.get("quest_name", ""), 灵石奖励, 灵气奖励, 声望奖励], 1)
	return {"成功": true, "灵石": 灵石奖励, "灵气": 灵气奖励, "声望": 声望奖励}

# 获取指定阵营的商店商品列表
func 获取阵营商店(阵营: String) -> Array:
	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)
	var 商品列表: Array = []
	for item in 阵营商店配置:
		if str(item.get("faction") if "faction" in item else "") == 实际阵营:
			var 商品: Dictionary = item.duplicate()
			var 所需声望: String = str(item.get("unlock_reputation") if "unlock_reputation" in item else "冷淡")
			商品["是否解锁"] = 检查阵营任务解锁(实际阵营, 所需声望)
			# 计算折扣价
			var 权益: Dictionary = 获取阵营权益(实际阵营)
			var 折扣: float = float(权益.get("商店折扣", 1.0))
			var 原价: int = int(item.get("price") if "price" in item else 0)
			商品["折扣价"] = int(round(原价 * 折扣))
			商品["购买次数"] = int(阵营商店购买记录.get(str(item.get("item_id") if "item_id" in item else ""), 0))
			商品列表.append(商品)
	return 商品列表

# 购买阵营商店商品
func 购买阵营商店商品(商品ID: String) -> Dictionary:
	# 找到商品配置
	var 商品配置: Dictionary = {}
	for item in 阵营商店配置:
		if str(item.get("item_id") if "item_id" in item else "") == 商品ID:
			商品配置 = item
			break
	if 商品配置.is_empty():
		return {"成功": false, "原因": "商品不存在"}
	var 阵营: String = str(商品配置.get("faction", ""))
	var 所需声望: String = str(商品配置.get("unlock_reputation", "冷淡"))
	if not 检查阵营任务解锁(阵营, 所需声望):
		return {"成功": false, "原因": "声望等级不足，商品未解锁"}
	# 计算价格
	var 权益: Dictionary = 获取阵营权益(阵营)
	var 折扣: float = float(权益.get("商店折扣", 1.0))
	var 原价: int = int(商品配置.get("price", 0))
	var 实际价格: int = int(round(原价 * 折扣))
	if 灵石 < 实际价格:
		return {"成功": false, "原因": "灵石不足"}
	# 扣除灵石
	灵石 -= 实际价格
	# 记录购买
	if not 阵营商店购买记录.has(商品ID):
		阵营商店购买记录[商品ID] = 0
	阵营商店购买记录[商品ID] += 1
	# 根据商品类型添加不同效果
	var 商品名: String = str(商品配置.get("item_name", ""))
	var 商品类型: String = str(商品配置.get("item_type", ""))
	var 效果文本: String = ""
	match 商品类型:
		"功法":
			# 功法类：学习功法，获得悟道点
			var 悟道点奖励: int = 20
			悟道点 += 悟道点奖励
			效果文本 = "，学习%s，悟道点+%d" % [商品名, 悟道点奖励]
		"丹药":
			# 丹药类：根据具体丹药添加不同效果
			if 商品名 == "清心丹":
				# 清心丹：清除心魔，提升道心
				道心 += 5
				效果文本 = "，服用清心丹，道心+5"
			elif 商品名 == "嗜血丹":
				# 嗜血丹：短期大幅提升攻击力（简化为永久攻击+10）
				攻击 += 10
				效果文本 = "，服用嗜血丹，攻击+10"
			elif 商品名 == "辟谷丹":
				# 辟谷丹：恢复体力
				体力 = min(体力 + 30, 体力上限())
				效果文本 = "，服用辟谷丹，体力+30"
			elif 商品名 == "时光丹":
				# 时光丹：恢复灵气和悟道点
				灵气 += 200
				悟道点 += 10
				效果文本 = "，服用时光丹，灵气+200，悟道点+10"
			else:
				# 其他丹药：默认恢复体力
				体力 = min(体力 + 20, 体力上限())
				效果文本 = "，服用%s，体力+20" % 商品名
		"装备":
			# 装备类：添加到仓库
			var 新装备 = Item.new()
			新装备.名称 = 商品名
			新装备.品阶 = "宝品"
			新装备.类别 = "装备"
			新装备.描述 = str(商品配置.get("description", ""))
			宗门库房.append(新装备)
			效果文本 = "，获得装备%s（已放入仓库）" % 商品名
		"材料":
			# 材料类：添加到仓库或用于其他系统
			if 商品名 == "灵兽食粮":
				# 灵兽食粮：提升所有灵兽亲密度
				for 兽 in 灵兽库存:
					if 兽 != null and "亲密度" in 兽:
						兽["亲密度"] = int(兽.get("亲密度") if "亲密度" in 兽 else 0) + 5
				效果文本 = "，使用灵兽食粮，所有灵兽亲密度+5"
			elif 商品名 == "远古符文":
				# 远古符文：获得悟道点
				悟道点 += 15
				效果文本 = "，参悟远古符文，悟道点+15"
			elif 商品名 == "远古神器碎片":
				# 远古神器碎片：添加到仓库
				var 新碎片 = Item.new()
				新碎片.名称 = 商品名
				新碎片.品阶 = "仙品"
				新碎片.类别 = "材料"
				新碎片.描述 = str(商品配置.get("description", ""))
				宗门库房.append(新碎片)
				效果文本 = "，获得%s（已放入仓库）" % 商品名
			else:
				# 其他材料：添加到仓库
				var 新材料 = Item.new()
				新材料.名称 = 商品名
				新材料.品阶 = "灵品"
				新材料.类别 = "材料"
				新材料.描述 = str(商品配置.get("description", ""))
				宗门库房.append(新材料)
				效果文本 = "，获得材料%s（已放入仓库）" % 商品名
		"丹药":
			# 丹药类：根据具体丹药添加不同效果
			if "洗髓丹" in 商品名:
				# 洗髓丹：随机提升一名弟子的灵根品阶
				if not 弟子列表.is_empty():
					var 随机弟子 = 弟子列表[randi() % 弟子列表.size()]
					if 随机弟子 != null:
						# 简化处理：提升灵根品阶（实际需要根据灵根系统实现）
						效果文本 = "，使用%s，%s的灵根得到提升" % [商品名, 随机弟子.姓名]
						# 成就统计：累计提升灵根次数自增
						累计提升灵根次数 += 1
						_复检成就()
				else:
					效果文本 = "，使用%s，但没有弟子可以提升" % 商品名
			elif "清心丹" in 商品名:
				# 清心丹：随机提升一名弟子的心境
				if not 弟子列表.is_empty():
					var 随机弟子 = 弟子列表[randi() % 弟子列表.size()]
					if 随机弟子 != null:
						效果文本 = "，使用%s，%s的心境得到提升" % [商品名, 随机弟子.姓名]
						# 成就统计：累计提升心境次数自增
						累计提升心境次数 += 1
						_复检成就()
				else:
					效果文本 = "，使用%s，但没有弟子可以提升" % 商品名
			elif "长生丹" in 商品名 or "延寿丹" in 商品名:
				# 长生丹/延寿丹：随机延长一名弟子的寿元
				if not 弟子列表.is_empty():
					var 随机弟子 = 弟子列表[randi() % 弟子列表.size()]
					if 随机弟子 != null:
						效果文本 = "，使用%s，%s的寿元得到延长" % [商品名, 随机弟子.姓名]
						# 成就统计：累计延长寿元次数自增
						累计延长寿元次数 += 1
						_复检成就()
				else:
					效果文本 = "，使用%s，但没有弟子可以延长寿元" % 商品名
			elif "道愈丹" in 商品名:
				# 道愈丹：随机修复一名弟子的道伤
				if not 弟子列表.is_empty():
					var 随机弟子 = 弟子列表[randi() % 弟子列表.size()]
					if 随机弟子 != null:
						效果文本 = "，使用%s，%s的道伤得到修复" % [商品名, 随机弟子.姓名]
						# 成就统计：累计修复道伤次数自增
						累计修复道伤次数 += 1
						_复检成就()
				else:
					效果文本 = "，使用%s，但没有弟子可以修复道伤" % 商品名
			else:
				# 其他丹药：添加到仓库
				var 新丹药 = Item.new()
				新丹药.名称 = 商品名
				新丹药.品阶 = "灵品"
				新丹药.类别 = "丹药"
				新丹药.描述 = str(商品配置.get("description", ""))
				宗门库房.append(新丹药)
				效果文本 = "，获得丹药%s（已放入仓库）" % 商品名
		"特殊":
			# 特殊类：根据具体商品添加不同效果
			if "传承玉简" in 商品名:
				# 传承玉简：获得大量悟道点和灵气
				var 悟道奖励: int = 100
				var 灵气奖励: int = 500
				悟道点 += 悟道奖励
				灵气 += 灵气奖励
				效果文本 = "，参悟%s，悟道点+%d，灵气+%d" % [商品名, 悟道奖励, 灵气奖励]
			elif 商品名 == "灵兽契约书":
				# 灵兽契约书：获得一只随机灵兽
				var 新灵兽 = {
					"ID": randi(),
					"名称": "随机灵兽",
					"等级": 1,
					"亲密度": 30,
					"经验": 0
				}
				灵兽库存.append(新灵兽)
				_复检成就()  # 成就检测：灵兽数量相关成就
				效果文本 = "，使用灵兽契约书，获得一只随机灵兽"
			elif 商品名 == "上古灵兽蛋":
				# 上古灵兽蛋：获得一只稀有上古灵兽
				var 上古灵兽 = {
					"ID": randi(),
					"名称": "上古灵兽",
					"等级": 1,
					"亲密度": 50,
					"经验": 0,
					"品质": "稀有"
				}
				灵兽库存.append(上古灵兽)
				效果文本 = "，孵化上古灵兽蛋，获得一只稀有上古灵兽"
			else:
				# 其他特殊物品：添加到仓库
				var 新特殊 = Item.new()
				新特殊.名称 = 商品名
				新特殊.品阶 = "仙品"
				新特殊.类别 = "特殊"
				新特殊.描述 = str(商品配置.get("description", ""))
				宗门库房.append(新特殊)
				效果文本 = "，获得特殊物品%s（已放入仓库）" % 商品名
		_:
			# 其他类型：添加到仓库
			var 新物品 = Item.new()
			新物品.名称 = 商品名
			新物品.品阶 = "灵品"
			新物品.类别 = 商品类型
			新物品.描述 = str(商品配置.get("description", ""))
			宗门库房.append(新物品)
			效果文本 = "，获得%s（已放入仓库）" % 商品名
	添加纪事("庶务", "阵营商店购买", "在%s商店购买了%s，花费%d灵石%s" % [阵营, 商品名, 实际价格, 效果文本], 1)
	return {"成功": true, "商品名": 商品名, "商品类型": 商品类型, "花费": 实际价格, "效果": 效果文本}

# ===== 探索事件分支选择系统 =====
# 探索事件：在历练、秘境探索等场景中触发，玩家选择不同分支获得不同结果
var 探索事件配置: Array = []  # 探索事件配置列表
var 探索事件冷却: Dictionary = {}  # 事件ID -> 冷却结束日

# 加载探索事件配置
func _加载探索事件配置() -> void:
	if not 探索事件配置.is_empty():
		return
	# 内置探索事件配置（后续可移至CSV）
	探索事件配置 = [
		{
			"event_id": "explore_001",
			"name": "神秘洞穴",
			"description": "你在探索中发现了一个神秘洞穴，洞口散发着微弱的光芒。",
			"branches": [
				{"choice": "进入洞穴探索", "result": "risk", "success_rate": 0.6, "success_reward": {"灵石": 500, "悟道点": 20}, "fail_penalty": {"体力": -20}},
				{"choice": "在洞口查看", "result": "safe", "reward": {"灵石": 100, "灵气": 50}},
				{"choice": "离开", "result": "none", "reward": {}}
			]
		},
		{
			"event_id": "explore_002",
			"name": "受伤的旅人",
			"description": "你遇到了一个受伤的旅人，他看起来需要帮助。",
			"branches": [
				{"choice": "救助旅人", "result": "good", "reward": {"好感度": 10, "灵石": 200}, "special": "可能添加道友"},
				{"choice": "询问情况", "result": "info", "reward": {"悟道点": 5}},
				{"choice": "无视离开", "result": "none", "reward": {}}
			]
		},
		{
			"event_id": "explore_003",
			"name": "古老遗迹",
			"description": "你发现了一处古老遗迹，里面似乎藏有宝物。",
			"branches": [
				{"choice": "深入探索", "result": "risk", "success_rate": 0.5, "success_reward": {"灵石": 1000, "悟道点": 50, "灵气": 200}, "fail_penalty": {"体力": -30}},
				{"choice": "在外围搜索", "result": "safe", "reward": {"灵石": 300, "灵气": 100}},
				{"choice": "记录位置离开", "result": "none", "reward": {"悟道点": 10}}
			]
		},
		{
			"event_id": "explore_004",
			"name": "商队遭遇",
			"description": "你遇到了一支商队，他们正在招募护卫。",
			"branches": [
				{"choice": "接受护卫任务", "result": "task", "reward": {"灵石": 500}, "special": "需要体力"},
				{"choice": "与商人交易", "result": "trade", "reward": {"灵石": -200, "物品": "随机物品"}},
				{"choice": "离开", "result": "none", "reward": {}}
			]
		},
		{
			"event_id": "explore_005",
			"name": "灵泉发现",
			"description": "你发现了一处散发着灵气的泉水。",
			"branches": [
				{"choice": "饮用灵泉", "result": "good", "reward": {"灵气": 300, "体力": 20}},
				{"choice": "收集灵泉水", "result": "safe", "reward": {"灵气": 100}},
				{"choice": "在此修炼", "result": "cultivate", "reward": {"修炼进度": 0.1, "悟道点": 15}}
			]
		}
	]

# 获取所有探索事件列表
func 获取所有探索事件列表() -> Array:
	_加载探索事件配置()
	var 事件列表 = []
	for 事件 in 探索事件配置:
		事件列表.append({
			"event_id": 事件.get("event_id", ""),
			"name": 事件.get("name", ""),
			"description": 事件.get("description", ""),
			"branches_count": 事件.get("branches", []).size(),
		})
	return 事件列表

# 探索事件历史记录
var 探索事件历史: Array = []  # 探索事件历史记录

# 选择探索事件分支
func 选择探索事件分支(事件ID: String, 分支索引: int) -> Dictionary:
	_加载探索事件配置()
	# 查找事件
	var 目标事件 = null
	for 事件 in 探索事件配置:
		if 事件.get("event_id", "") == 事件ID:
			目标事件 = 事件
			break
	if 目标事件 == null:
		return {"成功": false, "原因": "探索事件不存在"}
	# 检查冷却
	if 事件ID in 探索事件冷却:
		var 冷却结束日 = int(探索事件冷却[事件ID])
		if 累计游戏日 < 冷却结束日:
			return {"成功": false, "原因": "事件冷却中（还需%d天）" % (冷却结束日 - 累计游戏日)}
	# 检查分支索引
	var 分支列表 = 目标事件.get("branches", [])
	if 分支索引 < 0 or 分支索引 >= 分支列表.size():
		return {"成功": false, "原因": "分支索引无效"}
	var 分支 = 分支列表[分支索引]
	var 结果类型 = str(分支.get("result", "none"))
	var 奖励 = {}
	var 惩罚 = {}
	var 消息 = ""
	# 根据结果类型处理
	if 结果类型 == "risk":
		# 风险型：有成功率
		var 成功率 = float(分支.get("success_rate", 0.5))
		var 随机值 = randf()
		if 随机值 < 成功率:
			奖励 = 分支.get("success_reward", {})
			消息 = "探索成功，获得奖励"
		else:
			惩罚 = 分支.get("fail_penalty", {})
			消息 = "探索失败，受到惩罚"
	elif 结果类型 == "safe":
		# 安全型：直接获得奖励
		奖励 = 分支.get("reward", {})
		消息 = "安全探索，获得奖励"
	elif 结果类型 == "good":
		# 善良型：获得奖励和特殊效果
		奖励 = 分支.get("reward", {})
		消息 = "善良之举，获得奖励"
		# 特殊效果：可能添加道友
		if "special" in 分支 and "可能添加道友" in str(分支["special"]):
			if randf() < 0.3:
				var 随机名字 = "旅人%d" % randi() % 1000
				添加道友(随机名字)
				消息 += "，并结识了新道友%s" % 随机名字
	elif 结果类型 == "info":
		# 信息型：获得悟道点
		奖励 = 分支.get("reward", {})
		消息 = "获得信息，悟道点增加"
	elif 结果类型 == "task":
		# 任务型：获得奖励但消耗体力
		奖励 = 分支.get("reward", {})
		惩罚 = {"体力": -10}
		消息 = "完成任务，获得奖励"
	elif 结果类型 == "trade":
		# 交易型：消耗灵石获得物品
		奖励 = 分支.get("reward", {})
		消息 = "完成交易"
	elif 结果类型 == "cultivate":
		# 修炼型：获得修炼进度
		奖励 = 分支.get("reward", {})
		消息 = "在此修炼，获得修炼进度"
	else:
		# 无结果：直接离开
		消息 = "选择离开"
	# 应用奖励
	if "灵石" in 奖励:
		灵石 += int(奖励["灵石"])
	if "悟道点" in 奖励:
		悟道点 += int(奖励["悟道点"])
	if "灵气" in 奖励:
		灵气 += int(奖励["灵气"])
	if "体力" in 奖励:
		体力 = min(体力 + int(奖励["体力"]), 体力上限())
	if "好感度" in 奖励:
		# 好感度奖励暂时记录
		pass
	# 应用惩罚
	if "体力" in 惩罚:
		体力 = max(0, 体力 + int(惩罚["体力"]))
	# 设置冷却（3天）
	探索事件冷却[事件ID] = 累计游戏日 + 3
	# 记录历史
	探索事件历史.append({
		"事件ID": 事件ID,
		"事件名称": 目标事件.get("name", ""),
		"分支选择": 分支.get("choice", ""),
		"结果类型": 结果类型,
		"奖励": 奖励,
		"惩罚": 惩罚,
		"消息": 消息,
		"日期": 累计游戏日,
	})
	# 限制历史记录数量
	if 探索事件历史.size() > 100:
		探索事件历史.remove_at(0)
	添加纪事("探索", "探索事件", "%s：%s" % [目标事件.get("name", ""), 消息], 1)
	return {"成功": true, "事件": 目标事件, "分支": 分支, "奖励": 奖励, "惩罚": 惩罚, "消息": 消息}

# 获取探索事件历史
func 获取探索事件历史(限制数量: int = 20) -> Array:
	var 历史 = 探索事件历史.duplicate()
	历史.reverse()
	return 历史.slice(0, min(限制数量, 历史.size()))

# 获取探索事件统计
func 获取探索事件统计() -> Dictionary:
	var 总探索次数 = 探索事件历史.size()
	var 成功次数 = 0
	var 失败次数 = 0
	var 获得灵石总数 = 0
	var 获得悟道点总数 = 0
	var 获得灵气总数 = 0
	for 记录 in 探索事件历史:
		var 结果类型 = str(记录.get("结果类型", ""))
		if 结果类型 == "risk":
			# 风险型：根据是否有惩罚判断成功失败
			var 惩罚 = 记录.get("惩罚", {})
			if 惩罚.is_empty():
				成功次数 += 1
			else:
				失败次数 += 1
		else:
			成功次数 += 1
		var 奖励 = 记录.get("奖励", {})
		获得灵石总数 += int(奖励.get("灵石", 0))
		获得悟道点总数 += int(奖励.get("悟道点", 0))
		获得灵气总数 += int(奖励.get("灵气", 0))
	return {
		"总探索次数": 总探索次数,
		"成功次数": 成功次数,
		"失败次数": 失败次数,
		"成功率": float(成功次数) / float(max(1, 总探索次数)),
		"获得灵石总数": 获得灵石总数,
		"获得悟道点总数": 获得悟道点总数,
		"获得灵气总数": 获得灵气总数,
	}

# 一键探索（自动触发探索事件并选择第一个选项）
func 一键探索() -> Dictionary:
	var 结果 = 触发探索事件()
	if not 结果.get("成功", false):
		return 结果
	var 事件 = 结果.get("事件", {})
	var 分支 = 事件.get("branches", [])
	if 分支.is_empty():
		return {"成功": false, "原因": "事件没有分支选项"}
	# 自动选择第一个安全选项
	var 选择 = 分支[0]
	for b in 分支:
		if b.get("result") if "result" in b else "" == "safe":
			选择 = b
			break
	# 处理选择结果
	var 奖励 = 选择.get("reward", {})
	if 选择.get("result", "") == "risk":
		var 成功率 = 选择.get("success_rate", 0.5)
		if randf() < 成功率:
			奖励 = 选择.get("success_reward", {})
		else:
			奖励 = 选择.get("fail_penalty", {})
	# 应用奖励
	for key in 奖励.keys():
		var 值 = 奖励[key]
		if key == "灵石":
			灵石 += int(值)
		elif key == "悟道点":
			悟道点 += int(值)
		elif key == "灵气":
			灵气 += int(值)
		elif key == "体力":
			pass  # 体力系统暂未实现
	# 成就统计：累计探索次数自增
	累计探索次数 += 1
	_复检成就()
	添加纪事("探索", "一键探索", "探索了%s，选择了%s" % [事件.get("name", ""), 选择.get("choice", "")], 1)
	return {"成功": true, "事件": 事件, "选择": 选择, "奖励": 奖励, "消息": "探索%s成功" % 事件.get("name", "")}

# 获取探索统计
func 获取探索统计() -> Dictionary:
	return {
		"累计探索次数": 累计探索次数,
		"探索事件总数": 探索事件配置.size(),
	}

# 触发随机探索事件
func 触发探索事件() -> Dictionary:
	_加载探索事件配置()
	# 过滤冷却中的事件
	var 可用事件: Array = []
	for 事件 in 探索事件配置:
		var 事件ID: String = str(事件.get("event_id", ""))
		var 冷却日: int = int(探索事件冷却.get(事件ID, 0))
		if 累计游戏日 >= 冷却日:
			可用事件.append(事件)
	if 可用事件.is_empty():
		return {"成功": false, "原因": "暂无可用探索事件"}
	# 随机选择一个事件
	var 事件 = 可用事件[randi() % 可用事件.size()]
	return {"成功": true, "事件": 事件}

# ===== 新系统实现（基本框架和核心功能）=====

# ============ 1. 山门巡逻系统 ============
# 山门巡逻：消耗体力，获得灵石、灵气、声望，随机事件
var 山门巡逻冷却: int = 0  # 冷却结束日
func 山门巡逻() -> Dictionary:
	if 累计游戏日 < 山门巡逻冷却:
		return {"成功": false, "原因": "巡逻冷却中（还需%d天）" % (山门巡逻冷却 - 累计游戏日)}
	if 体力 < 10:
		return {"成功": false, "原因": "体力不足（需10点）"}
	体力 -= 10
	山门巡逻冷却 = 累计游戏日 + 1
	# 基础奖励
	var 灵石奖励: int = randi_range(50, 150)
	var 灵气奖励: int = randi_range(20, 60)
	灵石 += 灵石奖励
	灵气 += 灵气奖励
	# 随机事件
	var 事件文本: String = ""
	var 随机值: float = randf()
	if 随机值 < 0.1:
		# 10%概率发现入侵者，额外声望
		增加阵营声望("正道宗门", 15)
		事件文本 = "，发现并驱逐了入侵者，正道声望+15"
	elif 随机值 < 0.2:
		# 10%概率发现宝藏，额外灵石
		var 额外灵石: int = randi_range(100, 300)
		灵石 += 额外灵石
		事件文本 = "，在角落发现隐藏宝藏，额外获得%d灵石" % 额外灵石
	# 阵营任务进度更新：正道宗门"正道巡山"任务
	更新阵营任务进度("正道宗门", "daily", 1)
	添加纪事("庶务", "山门巡逻", "完成山门巡逻，获得%d灵石、%d灵气%s" % [灵石奖励, 灵气奖励, 事件文本], 1)
	return {"成功": true, "灵石": 灵石奖励, "灵气": 灵气奖励, "事件": 事件文本}

# ============ 2. 游历系统 ============
# 游历天下：消耗体力和时间，获得灵石、灵气、见识、随机奇遇
var 游历冷却: int = 0
func 游历天下() -> Dictionary:
	if 累计游戏日 < 游历冷却:
		return {"成功": false, "原因": "游历冷却中（还需%d天）" % (游历冷却 - 累计游戏日)}
	if 体力 < 20:
		return {"成功": false, "原因": "体力不足（需20点）"}
	体力 -= 20
	游历冷却 = 累计游戏日 + 2
	# 基础奖励
	var 灵石奖励: int = randi_range(100, 300)
	var 灵气奖励: int = randi_range(50, 150)
	灵石 += 灵石奖励
	灵气 += 灵气奖励
	# 随机奇遇
	var 奇遇文本: String = ""
	var 随机值: float = randf()
	if 随机值 < 0.15:
		# 15%概率遇到散修高人，获得功法心得
		悟道点 += 5
		奇遇文本 = "，遇到散修高人指点，悟道点+5"
	elif 随机值 < 0.25:
		# 10%概率发现古代遗迹，获得额外奖励
		var 额外灵石: int = randi_range(200, 500)
		灵石 += 额外灵石
		奇遇文本 = "，发现古代遗迹，额外获得%d灵石" % 额外灵石
	# 阵营任务进度更新：中立散修"游历天下"任务
	更新阵营任务进度("中立散修", "daily", 1)
	添加纪事("庶务", "游历天下", "完成游历，获得%d灵石、%d灵气%s" % [灵石奖励, 灵气奖励, 奇遇文本], 1)
	return {"成功": true, "灵石": 灵石奖励, "灵气": 灵气奖励, "奇遇": 奇遇文本}

# ============ 3. 灵兽喂养系统 ============
# 灵兽喂养：消耗食材，提升灵兽亲密度和经验
var 灵兽喂养冷却: Dictionary = {}  # 灵兽ID -> 冷却结束日
func 喂养灵兽(灵兽ID: int) -> Dictionary:
	var 灵兽 = _获取灵兽(灵兽ID)
	if 灵兽 == null:
		return {"成功": false, "原因": "灵兽不存在"}
	var 冷却日: int = int(灵兽喂养冷却.get(灵兽ID, 0))
	if 累计游戏日 < 冷却日:
		return {"成功": false, "原因": "喂养冷却中（还需%d天）" % (冷却日 - 累计游戏日)}
	# 检查食材（简化：消耗灵石购买食材）
	if 灵石 < 50:
		return {"成功": false, "原因": "灵石不足（需50灵石购买食材）"}
	灵石 -= 50
	灵兽喂养冷却[灵兽ID] = 累计游戏日 + 1
	# 提升亲密度和经验
	if "亲密度" in 灵兽:
		灵兽["亲密度"] = int(灵兽.get("亲密度", 0)) + 10
	if "经验" in 灵兽:
		灵兽["经验"] = int(灵兽.get("经验", 0)) + 20
	# 阵营任务进度更新：上古妖兽"灵兽喂养"任务
	更新阵营任务进度("上古妖兽", "daily", 1)
	添加纪事("庶务", "灵兽喂养", "喂养灵兽%s，亲密度+10，经验+20" % str(灵兽.get("名称", "")), 1)
	return {"成功": true, "亲密度": 10, "经验": 20}

# ============ 4. 宝物鉴定系统 ============
# 宝物鉴定：消耗灵石，鉴定未鉴定物品，可能获得稀有属性
var 鉴定冷却: int = 0
func 鉴定宝物(物品索引: int) -> Dictionary:
	if 累计游戏日 < 鉴定冷却:
		return {"成功": false, "原因": "鉴定冷却中（还需%d天）" % (鉴定冷却 - 累计游戏日)}
	if 物品索引 < 0 or 物品索引 >= 宗门库房.size():
		return {"成功": false, "原因": "物品不存在"}
	var 物品 = 宗门库房[物品索引]
	if 物品 == null:
		return {"成功": false, "原因": "物品不存在"}
	# 检查是否已鉴定
	if "已鉴定" in 物品 and 物品["已鉴定"]:
		return {"成功": false, "原因": "物品已鉴定"}
	# 消耗灵石
	var 鉴定费用: int = 100
	if 灵石 < 鉴定费用:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 鉴定费用}
	灵石 -= 鉴定费用
	鉴定冷却 = 累计游戏日 + 1
	# 鉴定结果
	物品["已鉴定"] = true
	var 品质提升: String = ""
	var 随机值: float = randf()
	if 随机值 < 0.2:
		# 20%概率品质提升
		if "品阶" in 物品:
			var 当前品阶: String = str(物品["品阶"])
			var 品阶列表: Array = ["凡品", "灵品", "宝品", "仙品", "神品"]
			var 当前索引: int = 品阶列表.find(当前品阶)
			if 当前索引 >= 0 and 当前索引 < 品阶列表.size() - 1:
				物品["品阶"] = 品阶列表[当前索引 + 1]
				品质提升 = "，品质提升至%s" % 品阶列表[当前索引 + 1]
	# 阵营任务进度更新：远古遗泽"宝物鉴定"任务
	更新阵营任务进度("远古遗泽", "daily", 1)
	添加纪事("庶务", "宝物鉴定", "鉴定宝物%s%s" % [str(物品.get("名称", "")), 品质提升], 1)
	return {"成功": true, "品质提升": 品质提升}

# ============ 5. 阵营活动系统 ============
# 阵营活动：定期举办的阵营活动，获得大量声望和奖励
var 阵营活动记录: Dictionary = {}  # 活动ID -> 参与记录
func 举办阵营活动(阵营: String, 活动类型: String) -> Dictionary:
	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)
	if 实际阵营 not in 阵营列表:
		return {"成功": false, "原因": "阵营不存在"}
	# 检查声望等级
	var 声望等级: String = 获取声望等级(实际阵营)
	var 声望索引: int = 声望等级.find(声望等级)
	if 声望索引 < 3:  # 需要尊敬以上
		return {"成功": false, "原因": "声望等级不足（需尊敬以上）"}
	# 检查冷却
	var 活动ID: String = "%s_%s" % [实际阵营, 活动类型]
	var 上次参与: int = int(阵营活动记录.get(活动ID, 0))
	if 累计游戏日 - 上次参与 < 7:
		return {"成功": false, "原因": "活动冷却中（7天一次）"}
	阵营活动记录[活动ID] = 累计游戏日
	# 活动奖励
	var 声望奖励: int = 50
	var 灵石奖励: int = 500
	var 灵气奖励: int = 200
	增加阵营声望(实际阵营, 声望奖励)
	灵石 += 灵石奖励
	灵气 += 灵气奖励
	# 阵营任务进度更新：对应阵营的周常活动任务
	更新阵营任务进度(实际阵营, "weekly", 1)
	添加纪事("庶务", "阵营活动", "举办%s阵营%s活动，获得%d声望、%d灵石、%d灵气" % [实际阵营, 活动类型, 声望奖励, 灵石奖励, 灵气奖励], 1)
	return {"成功": true, "声望": 声望奖励, "灵石": 灵石奖励, "灵气": 灵气奖励}

# 获取所有活动列表（修真界命名）
func 获取所有活动列表() -> Array:
	var 活动列表 = []
	# 内置活动配置（修真界命名）
	var 活动配置 = [
		{"活动ID": "daily_checkin", "名称": "每日朝贡", "类型": "日常", "描述": "每日朝贡宗门，领取修行资源", "冷却天数": 1, "修真界名称": "日供"},
		{"活动ID": "faction_activity", "名称": "宗门历练", "类型": "周常", "描述": "参与宗门历练，获得声望和资源", "冷却天数": 7, "修真界名称": "历练"},
		{"活动ID": "faction_trial", "名称": "秘境试炼", "类型": "周常", "描述": "挑战秘境试炼，获得稀有奖励", "冷却天数": 3, "修真界名称": "试炼"},
		{"活动ID": "caravan_raid", "名称": "截杀商队", "类型": "周常", "描述": "魔道专属，截杀商队获得资源", "冷却天数": 2, "修真界名称": "截杀"},
		{"活动ID": "explore_event", "名称": "云游四方", "类型": "日常", "描述": "云游四方，触发随机机缘事件", "冷却天数": 1, "修真界名称": "云游"},
		{"活动ID": "disciple_cultivate", "名称": "传道授业", "类型": "日常", "描述": "传道授业，培养弟子提升属性", "冷却天数": 1, "修真界名称": "传道"},
		{"活动ID": "alchemy_session", "名称": "丹道大会", "类型": "周常", "描述": "参与丹道大会，比拼炼丹技艺", "冷却天数": 7, "修真界名称": "丹会"},
		{"活动ID": "artifact_forge", "名称": "器道争锋", "类型": "周常", "描述": "参与器道争锋，比拼锻造技艺", "冷却天数": 7, "修真界名称": "器会"},
		{"活动ID": "zongmen_battle", "名称": "宗门大战", "类型": "周常", "描述": "参与宗门大战，争夺资源和地盘", "冷却天数": 7, "修真界名称": "宗战"},
		{"活动ID": "faction_reputation", "名称": "声望任务", "类型": "日常", "描述": "完成声望任务，提升阵营声望", "冷却天数": 1, "修真界名称": "声望"},
	]
	for 活动 in 活动配置:
		var 活动ID = 活动.get("活动ID", "")
		var 上次参与 = 0
		if 活动ID == "faction_activity":
			# 阵营活动记录在阵营活动记录中
			pass
		elif 活动ID == "faction_trial":
			# 阵营试炼记录在阵营试炼记录中
			pass
		活动列表.append({
			"活动ID": 活动ID,
			"名称": 活动.get("名称", ""),
			"类型": 活动.get("类型", ""),
			"描述": 活动.get("描述", ""),
			"冷却天数": 活动.get("冷却天数", 1),
			"可参与": true,  # 简化：默认都可参与
		})
	return 活动列表

# 获取活动统计
func 获取活动统计() -> Dictionary:
	var 活动列表 = 获取所有活动列表()
	var 日常活动数 = 0
	var 周常活动数 = 0
	for 活动 in 活动列表:
		if 活动.get("类型", "") == "日常":
			日常活动数 += 1
		elif 活动.get("类型", "") == "周常":
			周常活动数 += 1
	return {
		"活动总数": 活动列表.size(),
		"日常活动数": 日常活动数,
		"周常活动数": 周常活动数,
	}

# 按类型筛选活动
func 按类型筛选活动(活动类型: String) -> Array:
	var 筛选列表 = []
	var 活动列表 = 获取所有活动列表()
	for 活动 in 活动列表:
		if 活动.get("类型", "") == 活动类型:
			筛选列表.append(活动)
	return 筛选列表

# 获取活动冷却状态
func 获取活动冷却状态(活动ID: String) -> Dictionary:
	var 活动列表 = 获取所有活动列表()
	for 活动 in 活动列表:
		if 活动.get("活动ID", "") == 活动ID:
			var 冷却天数 = int(活动.get("冷却天数", 1))
			# 简化：默认都可参与
			return {
				"活动ID": 活动ID,
				"名称": 活动.get("名称", ""),
				"冷却天数": 冷却天数,
				"剩余冷却天数": 0,
				"可参与": true,
			}
	return {"成功": false, "原因": "活动不存在"}

# 获取所有活动冷却状态
func 获取所有活动冷却状态() -> Array:
	var 冷却状态列表 = []
	var 活动列表 = 获取所有活动列表()
	for 活动 in 活动列表:
		var 冷却状态 = 获取活动冷却状态(活动.get("活动ID", ""))
		冷却状态列表.append(冷却状态)
	return 冷却状态列表

# 参与单个活动（活动中心页面对接）
func 参与活动(活动ID: String) -> Dictionary:
	var 冷却状态 = 获取活动冷却状态(活动ID)
	if not 冷却状态.get("可参与", false):
		return {"成功": false, "原因": "活动冷却中，暂不可参与"}
	# 根据活动ID执行对应操作
	match 活动ID:
		"daily_checkin":
			# 每日朝贡
			if 日供_今日可领():
				var 结果 = 领取日供()
				if 结果.get("ok", false):
					return {"成功": true, "活动": "每日朝贡", "消息": "朝贡成功，获得奖励"}
				else:
					return {"成功": false, "原因": "朝贡失败：%s" % 结果.get("原因", "未知")}
			else:
				return {"成功": false, "原因": "今日已朝贡"}
		"explore_event":
			# 云游四方
			var 结果 = 一键探索()
			if 结果.get("成功", false):
				return {"成功": true, "活动": "云游四方", "消息": "探索成功，获得机缘"}
			else:
				return {"成功": false, "原因": "探索失败：%s" % 结果.get("原因", "未知")}
		"faction_activity":
			# 宗门历练（简化：显示提示）
			return {"成功": true, "活动": "宗门历练", "消息": "请前往历练页面参与"}
		"faction_trial":
			# 秘境试炼（简化：显示提示）
			return {"成功": true, "活动": "秘境试炼", "消息": "请前往历练页面参与"}
		"alchemy_session":
			# 丹道大会（简化：显示提示）
			return {"成功": true, "活动": "丹道大会", "消息": "请前往丹方页面参与"}
		"artifact_forge":
			# 器道争锋（简化：显示提示）
			return {"成功": true, "活动": "器道争锋", "消息": "请前往装备图纸页面参与"}
		"zongmen_battle":
			# 宗门大战（简化：显示提示）
			return {"成功": true, "活动": "宗门大战", "消息": "请前往宗门战页面参与"}
		"faction_reputation":
			# 声望任务（简化：显示提示）
			return {"成功": true, "活动": "声望任务", "消息": "请前往阵营声望页面参与"}
		_:
			return {"成功": false, "原因": "未知活动：%s" % 活动ID}

# 一键参与所有可参与活动
func 一键参与所有可参与活动() -> Dictionary:
	var 参与数量 = 0
	var 结果列表 = []
	var 活动列表 = 获取所有活动列表()
	for 活动 in 活动列表:
		var 活动ID = 活动.get("活动ID", "")
		var 冷却状态 = 获取活动冷却状态(活动ID)
		if 冷却状态.get("可参与", false):
			# 根据活动ID执行对应操作
			var 结果 = {"活动": 活动.get("名称", ""), "成功": false, "原因": "暂未实现"}
			if 活动ID == "daily_checkin":
				if 日供_今日可领():
					结果 = {"活动": "每日朝贡", "结果": 领取日供()}
					if 结果.get("结果", {}).get("ok", false):
						参与数量 += 1
			elif 活动ID == "explore_event":
				结果 = {"活动": "云游四方", "结果": 一键探索()}
				if 结果.get("结果", {}).get("成功", false):
					参与数量 += 1
			结果列表.append(结果)
	return {"成功": 参与数量 > 0, "参与数量": 参与数量, "结果列表": 结果列表, "消息": "一键参与完成，参与%d个活动" % 参与数量}

# 一键参与所有日常活动
func 一键参与日常活动() -> Dictionary:
	var 参与数量 = 0
	var 结果列表 = []
	# 每日签到
	if 日供_今日可领():
		var 结果 = 领取日供()
		结果列表.append({"活动": "每日签到", "结果": 结果})
		if 结果.get("ok", false):
			参与数量 += 1
	# 探索事件
	var 探索结果 = 一键探索()
	结果列表.append({"活动": "探索事件", "结果": 探索结果})
	if 探索结果.get("成功", false):
		参与数量 += 1
	return {"成功": 参与数量 > 0, "参与数量": 参与数量, "结果列表": 结果列表, "消息": "一键参与完成，参与%d个活动" % 参与数量}

# ============ 6. 阵营试炼系统 ============
# 阵营试炼：高阶挑战，获得稀有奖励
var 阵营试炼记录: Dictionary = {}  # 试炼ID -> 通关记录
func 挑战阵营试炼(阵营: String, 试炼难度: String = "普通") -> Dictionary:
	var 实际阵营 = 旧阵营映射.get(阵营, 阵营)
	if 实际阵营 not in 阵营列表:
		return {"成功": false, "原因": "阵营不存在"}
	# 检查声望等级
	var 声望等级: String = 获取声望等级(实际阵营)
	var 声望索引: int = 声望等级.find(声望等级)
	if 声望索引 < 4:  # 需要崇敬以上
		return {"成功": false, "原因": "声望等级不足（需崇敬以上）"}
	# 检查冷却
	var 试炼ID: String = "%s_%s" % [实际阵营, 试炼难度]
	var 上次挑战: int = int(阵营试炼记录.get(试炼ID, 0))
	if 累计游戏日 - 上次挑战 < 3:
		return {"成功": false, "原因": "试炼冷却中（3天一次）"}
	阵营试炼记录[试炼ID] = 累计游戏日
	# 消耗体力
	if 体力 < 30:
		return {"成功": false, "原因": "体力不足（需30点）"}
	体力 -= 30
	# 试炼结果（简化：随机胜负）
	var 胜利概率: float = 0.5 + float(声望索引) * 0.1
	var 胜利: bool = randf() < 胜利概率
	if 胜利:
		var 声望奖励: int = 100
		var 灵石奖励: int = 1000
		var 灵气奖励: int = 500
		增加阵营声望(实际阵营, 声望奖励)
		灵石 += 灵石奖励
		灵气 += 灵气奖励
		# 阵营任务进度更新：对应阵营的试炼任务
		更新阵营任务进度(实际阵营, "weekly", 1)
		添加纪事("庶务", "阵营试炼", "通过%s阵营%s试炼，获得%d声望、%d灵石、%d灵气" % [实际阵营, 试炼难度, 声望奖励, 灵石奖励, 灵气奖励], 1)
		return {"成功": true, "胜利": true, "声望": 声望奖励, "灵石": 灵石奖励, "灵气": 灵气奖励}
	else:
		添加纪事("庶务", "阵营试炼", "挑战%s阵营%s试炼失败" % [实际阵营, 试炼难度], 1)
		return {"成功": true, "胜利": false, "原因": "试炼失败"}

# ============ 7. 商队掠夺系统 ============
# 商队掠夺：魔道专属，掠夺商队获得资源，但降低正道声望
var 商队掠夺冷却: int = 0
func 掠夺商队() -> Dictionary:
	if 累计游戏日 < 商队掠夺冷却:
		return {"成功": false, "原因": "掠夺冷却中（还需%d天）" % (商队掠夺冷却 - 累计游戏日)}
	if 体力 < 20:
		return {"成功": false, "原因": "体力不足（需20点）"}
	体力 -= 20
	商队掠夺冷却 = 累计游戏日 + 2
	# 掠夺结果
	var 灵石奖励: int = randi_range(200, 500)
	var 灵气奖励: int = randi_range(50, 150)
	灵石 += 灵石奖励
	灵气 += 灵气奖励
	# 魔道声望增加，正道声望降低
	增加阵营声望("魔道邪宗", 20)
	增加阵营声望("正道宗门", -10)
	# 阵营任务进度更新：魔道邪宗"掠夺资源"任务
	更新阵营任务进度("魔道邪宗", "daily", 1)
	添加纪事("庶务", "商队掠夺", "掠夺商队成功，获得%d灵石、%d灵气，魔道声望+20，正道声望-10" % [灵石奖励, 灵气奖励], 1)
	return {"成功": true, "灵石": 灵石奖励, "灵气": 灵气奖励}

# ============ 8. 灵兽契约系统 ============
# 灵兽契约：与灵兽建立契约，获得战斗加成
var 灵兽契约记录: Dictionary = {}  # 灵兽ID -> 契约等级
func 建立灵兽契约(灵兽ID: int) -> Dictionary:
	var 灵兽 = _获取灵兽(灵兽ID)
	if 灵兽 == null:
		return {"成功": false, "原因": "灵兽不存在"}
	# 检查亲密度
	var 亲密度: int = int(灵兽.get("亲密度", 0))
	if 亲密度 < 50:
		return {"成功": false, "原因": "亲密度不足（需50以上）"}
	# 检查是否已契约
	if 灵兽ID in 灵兽契约记录:
		return {"成功": false, "原因": "已建立契约"}
	# 消耗灵石
	var 契约费用: int = 500
	if 灵石 < 契约费用:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 契约费用}
	灵石 -= 契约费用
	# 建立契约
	灵兽契约记录[灵兽ID] = 1
	# 阵营任务进度更新：上古妖兽"妖兽契约"任务
	更新阵营任务进度("上古妖兽", "daily", 1)
	添加纪事("庶务", "灵兽契约", "与灵兽%s建立契约" % str(灵兽.get("名称", "")), 1)
	return {"成功": true, "契约等级": 1}

# ============ 9. 传承参悟系统 ============
# 传承参悟：参悟远古传承，获得悟道点和特殊能力
var 传承参悟记录: Dictionary = {}  # 传承ID -> 参悟进度
func 参悟传承(传承ID: String = "远古传承") -> Dictionary:
	# 检查远古遗泽声望
	var 声望等级: String = 获取声望等级("远古遗泽")
	var 声望索引: int = 声望等级.find(声望等级)
	if 声望索引 < 3:  # 需要尊敬以上
		return {"成功": false, "原因": "远古遗泽声望等级不足（需尊敬以上）"}
	# 检查冷却
	var 上次参悟: int = int(传承参悟记录.get(传承ID, 0))
	if 累计游戏日 - 上次参悟 < 3:
		return {"成功": false, "原因": "参悟冷却中（3天一次）"}
	传承参悟记录[传承ID] = 累计游戏日
	# 消耗悟道点
	if 悟道点 < 10:
		return {"成功": false, "原因": "悟道点不足（需10点）"}
	悟道点 -= 10
	# 参悟结果
	var 悟道点奖励: int = randi_range(15, 30)
	var 灵气奖励: int = randi_range(100, 300)
	悟道点 += 悟道点奖励
	灵气 += 灵气奖励
	# 阵营任务进度更新：远古遗泽"远古传承"任务
	更新阵营任务进度("远古遗泽", "weekly", 1)
	添加纪事("庶务", "传承参悟", "参悟%s，获得%d悟道点、%d灵气" % [传承ID, 悟道点奖励, 灵气奖励], 1)
	return {"成功": true, "悟道点": 悟道点奖励, "灵气": 灵气奖励}

# 辅助函数：获取灵兽
func _获取灵兽(灵兽ID: int):
	for 兽 in 灵兽库存:
		if 兽 != null and "ID" in 兽 and 兽["ID"] == 灵兽ID:
			return 兽
	return null

# ===== 特权卡系统=====
# 月卡（清修卡）：30天，每日仙玉+离线+20%+历练+1+一键收取
# 季卡（悟道卡）：90天，月卡权益+炼制加：0%+商队+15%+专属头像：
# 永久卡（道统卡）：永久，季卡权益+永久皮肤+终身日供翻：离线上限24小时
var 月卡到期日: int = -1  # 累计游戏日，-1=未激活
var 季卡到期日: int = -1
var 永久卡激活: bool = false
# 检查月卡是否有：
func 月卡有效() -> bool:

	return 永久卡激活 or (月卡到期日>= 0 and 累计游戏日<= 月卡到期日)
# 检查季卡是否有：
func 季卡有效() -> bool:

	return 永久卡激活 or (季卡到期日>= 0 and 累计游戏日<= 季卡到期日)
# 检查永久卡是否有效
func 永久卡有效() -> bool:

	return 永久卡激活
# 激活月卡
func 激活月卡(天数: int = 30) -> void:

	if 月卡到期日 < 累计游戏日:
		月卡到期日= 累计游戏日+ 天数
	else:
		月卡到期日+= 天数
	添加纪事("大事件", "激活清修卡", "激活月卡，有效%d天" % 天数, 2)
# 激活季卡
func 激活季卡(天数: int = 90) -> void:

	if 季卡到期日 < 累计游戏日:
		季卡到期日= 累计游戏日+ 天数
	else:
		季卡到期日+= 天数
	添加纪事("大事件", "激活悟道卡", "激活季卡，有效%d天" % 天数, 2)
# 激活永久卡
func 激活永久卡() -> void:

	永久卡激活= true
	添加纪事("大事件", "激活道统卡", "激活永久卡，终身享受所有权益", 3)
# 获取所有卡类型列表
func 获取所有卡类型列表() -> Array:
	return [
		{
			"卡类型": "月卡",
			"名称": "清修卡",
			"价格": 30,
			"天数": 30,
			"描述": "每日仙玉+离线+20%+历练+1+一键收取",
			"权益": ["离线收益加成20%", "额外历练次数+1", "一键收取", "每日仙玉奖励"],
			"是否有效": 月卡有效(),
			"到期日": 月卡到期日,
			"剩余天数": max(0, 月卡到期日 - 累计游戏日) if 月卡到期日 >= 0 else 0,
		},
		{
			"卡类型": "季卡",
			"名称": "悟道卡",
			"价格": 98,
			"天数": 90,
			"描述": "月卡权益+炼制加成30%+商队收益+15%+专属头像框",
			"权益": ["月卡全部权益", "炼制加成30%", "商队收益加成15%", "专属头像框"],
			"是否有效": 季卡有效(),
			"到期日": 季卡到期日,
			"剩余天数": max(0, 季卡到期日 - 累计游戏日) if 季卡到期日 >= 0 else 0,
		},
		{
			"卡类型": "永久卡",
			"名称": "道统卡",
			"价格": 298,
			"天数": -1,
			"描述": "季卡权益+永久皮肤+终身日供翻倍+离线上限24小时",
			"权益": ["季卡全部权益", "永久皮肤", "终身日供翻倍", "离线上限24小时"],
			"是否有效": 永久卡有效(),
			"到期日": -1,
			"剩余天数": -1,
		},
	]

# 获取卡状态统计
func 获取卡状态统计() -> Dictionary:
	return {
		"月卡有效": 月卡有效(),
		"季卡有效": 季卡有效(),
		"永久卡有效": 永久卡有效(),
		"月卡剩余天数": max(0, 月卡到期日 - 累计游戏日) if 月卡到期日 >= 0 else 0,
		"季卡剩余天数": max(0, 季卡到期日 - 累计游戏日) if 季卡到期日 >= 0 else 0,
		"最高特权": "永久卡" if 永久卡有效() else ("季卡" if 季卡有效() else ("月卡" if 月卡有效() else "无")),
	}

# 获取每日卡奖励
func 获取每日卡奖励() -> Dictionary:
	var 奖励 = {"仙玉_绑定": 0, "灵石": 0, "灵气": 0}
	if 月卡有效():
		奖励["仙玉_绑定"] += 30
		奖励["灵石"] += 200
	if 季卡有效():
		奖励["仙玉_绑定"] += 50
		奖励["灵气"] += 100
	if 永久卡有效():
		奖励["仙玉_绑定"] += 100
		奖励["灵石"] += 500
	return 奖励

# 领取每日卡奖励
func 领取每日卡奖励() -> Dictionary:
	var 最后领取日 = card_daily_reward_day if "card_daily_reward_day" in self else -1
	if 最后领取日 == 累计游戏日:
		return {"成功": false, "原因": "今日已领取"}
	if not 月卡有效() and not 季卡有效() and not 永久卡有效():
		return {"成功": false, "原因": "没有有效的卡"}
	var 奖励 = 获取每日卡奖励()
	仙玉_绑定 += 奖励.get("仙玉_绑定", 0)
	灵石 += 奖励.get("灵石", 0)
	灵气 += 奖励.get("灵气", 0)
	card_daily_reward_day = 累计游戏日
	添加纪事("庶务", "每日卡奖励", "领取每日卡奖励：仙玉+%d，灵石+%d，灵气+%d" % [奖励.get("仙玉_绑定", 0), 奖励.get("灵石", 0), 奖励.get("灵气", 0)], 1)
	return {"成功": true, "奖励": 奖励, "消息": "领取每日卡奖励成功"}

var card_daily_reward_day: int = -1  # 每日卡奖励最后领取日

# 获取特权加成
func 获取特权加成() -> Dictionary:

	return {
		"离线收益加成": 1.2 if 月卡有效() else 1.0,
		"炼制加成": 1.3 if 季卡有效() else 1.0,
		"商队收益加成": 1.15 if 季卡有效() else 1.0,
		"日供翻倍": 永久卡有效(),
		"离线上限小时": 24 if 永久卡有效() else 8,
		"额外历练次数": 1 if 月卡有效() else 0,
		"一键收取": 月卡有效(),
	}
# ===== VIP系统接口预留（第一阶段：仅接口预留，[PLACEHOLDER]待实测）=====
# 设计依据：GDD §12 VIP与加速系：
# 第一阶段：game_state.gd加vip_level/vip_exp字段+is_vip_unlock()权限接口+战斗speed_multiplier参数占位
# 第二阶段：加速战斗全：VIP基础框架（便利类权益，不升5%/10%数值红线）
# 第三阶段：数据驱动补高阶权益+TapTap内购SDK
var vip_level: int = 0  # VIP等级：=非VIP：-10=VIP等级：
var vip_exp: int = 0    # VIP经验值（累计充：消费获得：
const VIP_MAX_LEVEL: int = 10  # VIP最高等：
const VIP_EXP_THRESHOLDS: Array = [0, 100, 300, 600, 1000, 2000, 3500, 5000, 8000, 12000]  # 各等级所需经验
# VIP权限接口（第一阶段预留，返回bool判断是否解锁特定功能：
func is_vip_unlock(feature: String) -> bool:

	match feature:
		"背包扩容":
			return vip_level >= 1
		"招募额外次数":
			return vip_level >= 2
		"每日免费礼包":
			return vip_level >= 3
		"战斗2倍率":
			return vip_level >= 1 or 月卡有效()  # 月卡也解：倍率
		"战斗3倍率":
			return vip_level >= 5
		"跳过战斗":
			return vip_level >= 3
		"专属头像框":
			return vip_level >= 4 or 季卡有效()
		"专属皮肤":
			return vip_level >= 6 or 永久卡有效()
		"离线24小时":
			return vip_level >= 5 or 永久卡有效()
		_:
			return false
# 获取VIP等级（根据经验自动计算）
func get_vip_level() -> int:

	for i in range(VIP_EXP_THRESHOLDS.size()):
		if vip_exp < VIP_EXP_THRESHOLDS[i]:
			return max(0, i - 1)
	return VIP_MAX_LEVEL
# 增加VIP经验（充：消费时调用）
func add_vip_exp(exp: int) -> void:

	vip_exp += exp
	var new_level: int = get_vip_level()
	if new_level > vip_level:
		vip_level = new_level
		添加纪事("大事件", "VIP升级", "VIP等级提升%d天" % vip_level, 2)
# 战斗倍速参数占位（第一阶段仅返回倍率，实际战斗逻辑第二阶段接入：
func get_battle_speed_multiplier() -> float:

	if is_vip_unlock("战斗3倍率"):
		return 3.0
	elif is_vip_unlock("战斗2倍率"):
		return 2.0
	return 1.0
# 获取VIP权益汇总（供UI展示：
func get_vip_benefits() -> Dictionary:

	return {
		"vip_level": vip_level,
		"vip_exp": vip_exp,
		"next_level_exp": VIP_EXP_THRESHOLDS[min(vip_level + 1, VIP_MAX_LEVEL)] if vip_level < VIP_MAX_LEVEL else -1,
		"battle_speed": get_battle_speed_multiplier(),
		"unlocked_features": [
			"背包扩容" if is_vip_unlock("背包扩容") else "",
			"招募额外次数" if is_vip_unlock("招募额外次数") else "",
			"每日免费礼包" if is_vip_unlock("每日免费礼包") else "",
			"战斗2倍率" if is_vip_unlock("战斗2倍率") else "",
			"战斗3倍率" if is_vip_unlock("战斗3倍率") else "",
			"跳过战斗" if is_vip_unlock("跳过战斗") else "",
		].filter(func(x): return x != ""),
	}
# 获取所有VIP等级列表
func 获取所有VIP等级列表() -> Array:
	var 等级列表 = []
	for i in range(VIP_MAX_LEVEL + 1):
		var 所需经验 = VIP_EXP_THRESHOLDS[i] if i < VIP_EXP_THRESHOLDS.size() else -1
		var 权益 = []
		if i >= 1:
			权益.append("背包扩容")
			权益.append("战斗2倍率")
		if i >= 2:
			权益.append("招募额外次数")
		if i >= 3:
			权益.append("每日免费礼包")
			权益.append("跳过战斗")
		if i >= 4:
			权益.append("专属头像框")
		if i >= 5:
			权益.append("战斗3倍率")
			权益.append("离线24小时")
		if i >= 6:
			权益.append("专属皮肤")
		等级列表.append({
			"等级": i,
			"所需经验": 所需经验,
			"权益": 权益,
			"已达成": vip_level >= i,
		})
	return 等级列表

# 获取VIP统计
func 获取VIP统计() -> Dictionary:
	var 下一级经验 = VIP_EXP_THRESHOLDS[min(vip_level + 1, VIP_MAX_LEVEL)] if vip_level < VIP_MAX_LEVEL else -1
	var 升级进度 = 0.0
	if 下一级经验 > 0:
		var 当前级经验 = VIP_EXP_THRESHOLDS[vip_level] if vip_level < VIP_EXP_THRESHOLDS.size() else 0
		升级进度 = float(vip_exp - 当前级经验) / float(下一级经验 - 当前级经验)
	return {
		"当前等级": vip_level,
		"当前经验": vip_exp,
		"下一级经验": 下一级经验,
		"升级进度": 升级进度,
		"最高等级": VIP_MAX_LEVEL,
		"战斗倍率": get_battle_speed_multiplier(),
		"已解锁权益数": get_vip_benefits().get("unlocked_features", []).size(),
	}

# 获取VIP每日奖励
func 获取VIP每日奖励() -> Dictionary:
	var 奖励 = {"灵石": 0, "灵气": 0, "悟道点": 0}
	if vip_level >= 1:
		奖励["灵石"] += 100
	if vip_level >= 2:
		奖励["灵气"] += 50
	if vip_level >= 3:
		奖励["悟道点"] += 10
	if vip_level >= 5:
		奖励["灵石"] += 200
	if vip_level >= 8:
		奖励["灵气"] += 100
	return 奖励

# 领取VIP每日奖励
func 领取VIP每日奖励() -> Dictionary:
	var 最后领取日 = vip_daily_reward_day if "vip_daily_reward_day" in self else -1
	if 最后领取日 == 累计游戏日:
		return {"成功": false, "原因": "今日已领取"}
	var 奖励 = 获取VIP每日奖励()
	灵石 += 奖励.get("灵石", 0)
	灵气 += 奖励.get("灵气", 0)
	悟道点 += 奖励.get("悟道点", 0)
	vip_daily_reward_day = 累计游戏日
	添加纪事("庶务", "VIP每日奖励", "领取VIP%d每日奖励：灵石+%d，灵气+%d，悟道点+%d" % [vip_level, 奖励.get("灵石", 0), 奖励.get("灵气", 0), 奖励.get("悟道点", 0)], 1)
	return {"成功": true, "奖励": 奖励, "消息": "领取VIP每日奖励成功"}

# ===== 付费礼包系统 =====
var 已购买礼包: Dictionary = {}  # 礼包ID -> 购买时间
var vip_daily_reward_day: int = -1  # VIP每日奖励最后领取日
var 礼包配置: Array = [
	{
		"id": "新手礼包",
		"名称": "新手礼包",
		"价格": 6,
		"描述": "新手专属，含灵石×1000、灵草：00、矿石：00",
		"内容": {"灵石": 1000, "灵草": 100, "矿石": 100},
		"限购": 1,
	},
	{
		"id": "成长礼包",
		"名称": "成长礼包",
		"价格": 30,
		"描述": "成长助力，含灵石×5000、悟道×100",
		"内容": {"灵石": 5000, "悟道": 100},
		"限购": 1,
	},
	{
		"id": "至尊礼包",
		"名称": "至尊礼包",
		"价格": 98,
		"描述": "至尊尊享，含灵石×20000、绑定仙玉×1000",
		"内容": {"灵石": 20000, "仙玉_绑定": 1000},
		"限购": 1,
	},
	{
		"id": "每日礼包",
		"名称": "每日礼包",
		"价格": 1,
		"描述": "每日特惠，含灵石×500、灵草：0",
		"内容": {"灵石": 500, "灵草": 50},
		"限购": 1,
		"每日重置": true,
	},
]
var 每日礼包购买日: int = -1
# 购买礼包
func 购买礼包(礼包ID: String) -> Dictionary:

	var 礼包 = null
	for g in 礼包配置:
		if g["id"] == 礼包ID:
			礼包 = g
			break
	if 礼包 == null:
		return {"成功": false, "消息": "未知礼包"}
	# 检查限：
	var 已购次数 = 已购买礼包.get(礼包ID, 0)
	if 礼包.get("每日重置", false):
		if 每日礼包购买日 == 累计游戏日 and 已购次数 >= 礼包["限购"]:
			return {"成功": false, "消息": "今日已购"}
	else:
		if 已购次数 >= 礼包["限购"]:
			return {"成功": false, "消息": "已达购买上限"}
	# 发放奖励
	var 内容 = 礼包["内容"]
	for 资源 in 内容.keys():
		if get(资源) != null:
			set(资源, get(资源) + 内容[资源])
	# 记录购买
	if 礼包.get("每日重置", false):
		if 每日礼包购买日 != 累计游戏日:
			每日礼包购买日= 累计游戏日
			已购买礼包[礼包ID] = 0
	已购买礼包[礼包ID] = 已购买礼包.get(礼包ID, 0) + 1
	添加纪事("大事件", "购买礼包", "购买%s，获得丰厚奖励" % 礼包["名称"], 2)
	return {"成功": true, "消息": "购买成功，奖励已发放"}
# 获取所有礼包列表
func 获取所有礼包列表() -> Array:
	var 礼包列表 = []
	for 礼包 in 礼包配置:
		var 礼包ID = 礼包.get("id", "")
		var 已购次数 = 已购买礼包.get(礼包ID, 0)
		var 可购买 = true
		if 礼包.get("每日重置", false):
			可购买 = 每日礼包购买日 != 累计游戏日 or 已购次数 < 礼包.get("限购", 1)
		else:
			可购买 = 已购次数 < 礼包.get("限购", 1)
		礼包列表.append({
			"id": 礼包ID,
			"名称": 礼包.get("名称", ""),
			"价格": 礼包.get("价格", 0),
			"描述": 礼包.get("描述", ""),
			"内容": 礼包.get("内容", {}),
			"限购": 礼包.get("限购", 1),
			"每日重置": 礼包.get("每日重置", false),
			"已购次数": 已购次数,
			"可购买": 可购买,
		})
	return 礼包列表

# 获取礼包统计
func 获取礼包统计() -> Dictionary:
	var 礼包总数 = 礼包配置.size()
	var 已购买总数 = 0
	var 每日礼包可领 = false
	for 礼包 in 礼包配置:
		var 礼包ID = 礼包.get("id", "")
		var 已购次数 = 已购买礼包.get(礼包ID, 0)
		if 礼包.get("每日重置", false):
			if 每日礼包购买日 != 累计游戏日 or 已购次数 < 礼包.get("限购", 1):
				每日礼包可领 = true
		else:
			if 已购次数 >= 礼包.get("限购", 1):
				已购买总数 += 1
	return {
		"礼包总数": 礼包总数,
		"已购买总数": 已购买总数,
		"每日礼包可领": 每日礼包可领,
	}

# 礼包分类配置
const 礼包分类配置: Dictionary = {
	"新手礼包": {"描述": "新手专属礼包", "图标": "🎁"},
	"每日礼包": {"描述": "每日可购买礼包", "图标": "📅"},
	"每周礼包": {"描述": "每周可购买礼包", "图标": "📆"},
	"节日礼包": {"描述": "节日限定礼包", "图标": "🎉"},
	"成长礼包": {"描述": "成长助力礼包", "图标": "📈"},
	"战力礼包": {"描述": "战力提升礼包", "图标": "⚔️"},
	"资源礼包": {"描述": "资源补给礼包", "图标": "💎"},
	"特殊礼包": {"描述": "特殊限定礼包", "图标": "✨"},
}

# 按分类筛选礼包
func 按分类筛选礼包(分类: String) -> Array:
	var 筛选列表 = []
	var 礼包列表 = 获取所有礼包列表()
	for 礼包 in 礼包列表:
		if 礼包.get("分类", "") == 分类:
			筛选列表.append(礼包)
	return 筛选列表

# 获取礼包详情
func 获取礼包详情(礼包ID: String) -> Dictionary:
	var 礼包列表 = 获取所有礼包列表()
	for 礼包 in 礼包列表:
		if 礼包.get("id", "") == 礼包ID:
			var 详情 = 礼包.duplicate()
			# 计算礼包总价值
			var 总价值 = 0
			var 内容 = 礼包.get("内容", {})
			for 资源 in 内容.keys():
				var 数量 = int(内容[资源])
				# 简化：每种资源按1灵石计算
				总价值 += 数量
			详情["总价值"] = 总价值
			详情["性价比"] = float(总价值) / float(max(1, int(礼包.get("价格", 1))))
			return 详情
	return {"成功": false, "原因": "礼包不存在"}

# 礼包购买历史记录
var 礼包购买历史: Array = []

# 记录礼包购买
func _记录礼包购买(礼包ID: String, 礼包名称: String, 价格: int) -> void:
	礼包购买历史.append({
		"礼包ID": 礼包ID,
		"礼包名称": 礼包名称,
		"价格": 价格,
		"购买日期": 累计游戏日,
	})
	# 限制历史记录数量
	if 礼包购买历史.size() > 100:
		礼包购买历史.remove_at(0)

# 获取礼包购买历史
func 获取礼包购买历史(限制数量: int = 20) -> Array:
	var 历史 = 礼包购买历史.duplicate()
	历史.reverse()
	return 历史.slice(0, min(限制数量, 历史.size()))

# 获取礼包购买统计
func 获取礼包购买统计() -> Dictionary:
	var 总购买次数 = 0
	var 总消费灵石 = 0
	var 礼包购买统计 = {}
	for 记录 in 礼包购买历史:
		总购买次数 += 1
		总消费灵石 += int(记录.get("价格", 0))
		var 礼包名称 = str(记录.get("礼包名称", ""))
		if 礼包名称 not in 礼包购买统计:
			礼包购买统计[礼包名称] = {"购买次数": 0, "总消费": 0}
		礼包购买统计[礼包名称]["购买次数"] += 1
		礼包购买统计[礼包名称]["总消费"] += int(记录.get("价格", 0))
	return {
		"总购买次数": 总购买次数,
		"总消费灵石": 总消费灵石,
		"礼包购买统计": 礼包购买统计,
	}

# 限时礼包活动
var 限时礼包活动: Array = []
var 限时礼包活动日期: int = 0

# 生成限时礼包活动
func 生成限时礼包活动() -> Array:
	if 限时礼包活动日期 == 累计游戏日 and 限时礼包活动.size() > 0:
		return 限时礼包活动
	限时礼包活动日期 = 累计游戏日
	限时礼包活动.clear()
	var 礼包列表 = 获取所有礼包列表()
	if 礼包列表.size() == 0:
		return 限时礼包活动
	# 随机选择1-2个礼包作为限时活动
	var 活动数量 = min(2, max(1, 礼包列表.size() / 10))
	var 已选礼包 = {}
	for i in range(活动数量):
		if 礼包列表.size() == 0:
			break
		var 随机索引 = randi() % 礼包列表.size()
		var 礼包 = 礼包列表[随机索引]
		var 礼包ID = str(礼包.get("id", ""))
		if 礼包ID in 已选礼包:
			continue
		已选礼包[礼包ID] = true
		var 折扣率 = 0.5 + float(randi() % 30) / 100.0  # 50%-80%折扣
		var 原价 = int(礼包.get("价格", 0))
		var 活动价 = int(round(原价 * 折扣率))
		var 剩余天数 = 1 + randi() % 3  # 1-3天
		限时礼包活动.append({
			"礼包": 礼包,
			"原价": 原价,
			"活动价": 活动价,
			"折扣率": 折扣率,
			"折扣百分比": int((1 - 折扣率) * 100),
			"剩余天数": 剩余天数,
			"活动名称": "限时特惠",
		})
	return 限时礼包活动

# 获取限时礼包活动
func 获取限时礼包活动() -> Array:
	return 生成限时礼包活动()

# 一键购买所有可购买的免费礼包（简化版本）
func 一键购买免费礼包() -> Dictionary:
	var 购买数量 = 0
	var 结果列表 = []
	for 礼包 in 礼包配置:
		var 价格 = int(礼包.get("价格", 0))
		if 价格 <= 0:  # 免费礼包
			var 结果 = 购买礼包(礼包.get("id", ""))
			结果列表.append({"礼包": 礼包.get("名称", ""), "结果": 结果})
			if 结果.get("成功", false):
				购买数量 += 1
	return {"成功": 购买数量 > 0, "购买数量": 购买数量, "结果列表": 结果列表, "消息": "一键购买完成，购买%d个礼包" % 购买数量}

# ===== 设置：/ 本地道友系统：026-08-21 收尾；不升SAVE_VERSION，旧档缺键→默认零回归）=====
var 设置项: Dictionary = {}                # 设置：UI 偏好持久化（音频/画面/通知/推演等）
var _道友列表: Array = []                  # 本地道友（{name, status, sel}），无服务端，纯本地
var _道友消息: Array = []                  # 本地聊天记录（{name, text, time}：
var 当前日常: Array = []                  # 当日日常差事（quest_daily 行字典，最：条）
var 日常已领: Array = []                  # ：当前日常 等长，true=已领：
var 上次日常日: int = 0
# 解耦：日常/周常刷新锚点改为「真实时钟」（现实秒），与游戏日脱钩。
#   游戏日按 240 现实秒=1 天飞快流逝，若仍按游戏日刷新，1 真实天会被刷新约 360 次、counter 永归零。
#   改按真实每天 86400s / 每周 604800s 刷新，玩家感知与常规手游一致。
var 上次日常真实秒: int = 0
# S1-2 任务完成判定：条件计数器。
#   key = condition_type 或 "condition_type:param"（param 区分同类条件的不同口径，
#   如 refine_pill 与 refine_pill:宝品）。埋点统一走 记任务进度()，禁止各处自加。
var 日常计数: Dictionary = {}
var 周常计数: Dictionary = {}
var 当前周常: Dictionary = {}             # 当周周常差事（quest_weekly 行字典）
var 周常已领: bool = true
var 上次周常日: int = 0
var 上次周常真实秒: int = 0
var 主线已完成: Array = []              # 已领取奖励的主线 quest_id 列表（持久化：
var 随机事件冷却: Dictionary = {}          # quest_id -> 上次触发累计游戏日
var 随机事件类型冷却: Dictionary = {}     # quest_type -> 上次触发累计游戏日（同类：月冷却）
# ===== P0 目标链系统· 新手阶梯状态（2026-07-25 新增；不升SAVE_VERSION，load ：.get 默认兼容老档：====
var 新手目标链激活: bool = false          # FTUE 收尾后解锁（激：newbie_001：
var 新手完成列表: Array = []              # 已完：newbie quest_id 列表（靠 prev_quest_id 推导解锁链）
signal 新手目标更新()                      # UI 玉牌红点 / 宗门要务面板刷新
# 全宗气运 buff（天品灵根弟子招募触发）：修：3% / 产出+2%，持：7 游戏日
var 气运修炼加成: float = 0.0
var 气运产出加成: float = 0.0
var 气运到期日: int = 0
var 天品突破播报: String = ""   # 单次推演内天品弟子突破播报，结算后由 main.gd 弹出；不存档
# Sprint-02b：奇遇冷：限流
var _上次奇遇时刻 := 0                    # 上次触发奇遇的真实时刻（ms），用于全局冷却
var _今日奇遇次数 := 0                    # 当日已触发奇遇次：
var _奇遇日标记:= -1                     # 记录 _今日奇遇次数 对应的游戏日
var _单条冷却记录: Dictionary = {}         # event_id ：触发时的累计游戏：
var quest_cooldown: Dictionary = {}         # event_id ：冷却到期月份（防重复3个月：
var _上次奇遇游戏日: int = 0            # P2-13：奇遇保底窗口锚点（距上次奇遇≥阈值则豁免概率，防长期无奇遇死锁）
# ===== 第三阶段：互动培养系：=====
var 互动冷却记录: Dictionary = {}  # 弟子ID -> {互动类型 -> 上次使用累计游戏日}
var 互动今日次数: Dictionary = {}  # 弟子ID -> {互动类型 -> 今日使用次数}
var 互动日标标: int = -1  # 记录互动次数对应的游戏日，跨日重置
# 互动配置：
var 互动配置: Dictionary = {
	"论道切磋": {"消耗灵": 50, "心境": 3, "修炼进度": 0.05, "每日次数": 1, "描述": "与弟子论道切磋，提升心境与修炼进度"},
	"共参功法": {"消耗悟道点": 20, "道心": 2, "修炼进度": 0.08, "每日次数": 1, "描述": "共参功法，消耗悟道点，提升道心与修炼进度"},
	"指点修行": {"心境": 0, "心魔": -2, "修炼进度": 0.03, "每日次数": 2, "描述": "指点弟子修行，降低心魔，提升修炼进度"},
	"罚面壁思过": {"心境": -5, "心魔": -10, "每日次数": 999, "描述": "罚弟子面壁思过，降低心境与心魔"},
}
# 重置互动每日次数（跨日调用）
func 重置互动每日次数() -> void:

	互动今日次数.clear()
	互动日标标= 累计游戏日
# 获取弟子今日剩余互动次数
func 获取互动剩余次数(弟子ID: int, 互动类型: String) -> int:

	# 跨日重置
	if 互动日标标 != 累计游戏日:
		重置互动每日次数()
	var 配置 = 互动配置.get(互动类型, {})
	var 每日次数 = 配置.get("每日次数", 1)
	var 弟子记录 = 互动今日次数.get(弟子ID, {})
	var 已用次数 = 弟子记录.get(互动类型, 0)
	return max(0, 每日次数 - 已用次数)
# 执行互动
func 执行互动(弟子ID: int, 互动类型: String) -> Dictionary:

	# 跨日重置
	if 互动日标标 != 累计游戏日:
		重置互动每日次数()
	var 结果 = {"成功": false, "消息": ""}
	var 配置 = 互动配置.get(互动类型, {})
	if 配置.is_empty():
		结果["消息"] = "未知互动类型"
		return 结果
	# 检查每日次：
	var 剩余次数 = 获取互动剩余次数(弟子ID, 互动类型)
	if 剩余次数 <= 0:
		结果["消息"] = "今日互动次数已用："
		return 结果
	# 查找弟子
	var 弟子 = null
	for d in 弟子列表:
		if int(d.弟子ID) == 弟子ID:
			弟子 = d
			break
	if 弟子 == null:
		结果["消息"] = "弟子不存在"
		return 结果
	# 检查消：
	if 配置.has("消耗灵"):
		var 消耗 = 配置["消耗灵"]
		if 灵气 < 消耗:
			结果["消息"] = "灵气不足"
			return 结果
		灵气 -= 消耗
	if 配置.has("消耗悟道点"):
		var 消耗= 配置["消耗悟道点"]
		if 悟道点< 消耗:
			结果["消息"] = "悟道点不足"
			return 结果
		悟道点-= 消耗
	# 应用效果
	if 配置.has("心境"):
		弟子.心境 = clamp(int(弟子.心境) + 配置["心境"], 0, 100)
	if 配置.has("道心"):
		弟子.道心 = clamp(int(弟子.道心) + 配置["道心"], 0, 100)
	if 配置.has("心魔"):
		弟子.心魔值 = clamp(int(弟子.心魔值) + 配置["心魔"], 0, 100)
	if 配置.has("修炼进度"):
		弟子.修炼进度 = clamp(float(弟子.修炼进度) + 配置["修炼进度"], 0.0, 1.0)
	# 记录次数
	if not 互动今日次数.has(弟子ID):
		互动今日次数[弟子ID] = {}
	互动今日次数[弟子ID][互动类型] = 互动今日次数[弟子ID].get(互动类型, 0) + 1
	记任务进度("disciple_interact")   # S1-2：与弟子互动（玩家决策，日常 daily_004）
	结果["成功"] = true
	结果["消息"] = "互动成功"
	结果["弟子"] = 弟子
	return 结果
# 时间 / 门派
var 累计游戏日:= 0
var 最后登录:= 0
var 门派等级 := 1
var 当前皮肤: String = "taixu_yunhai"   # 幻形·洞天换肤：已装备的宗门首页背景皮：id（纯展示态，零玩法触碰）
const 声望折扣表: Array = [1.0, 0.95, 0.9, 0.85, 0.8]   # 声望等级0-4对应折扣（中：友善/尊敬/崇敬/崇拜：
const 声望等级名: Array = ["中立", "友善", "尊敬", "崇敬", "崇拜"]
var 声望 := 0
var 繁荣 := 50
var 繁荣经营值: int = 0   # P1-2：繁荣可经营增量（供奉香火等玩家行为持久累积，避免被 更新门派() 派生覆盖抹平）
# === S1 ：-A：凡人香火体系（纯经营层 · 空桩逻辑 · 数：[PLACEHOLDER] 待真机校准）===
var 香火值:= 0
var 信徒数:= 0
var 凡人城镇: Array = []
var 香火月产预估 := 0
var 信徒增益档: String = "未启"
# === S2-3：香火/信徒增益链（补消耗出口，2026-08-31）===
const 信徒增益链: Array = ["未启", "香火初兴", "香火渐隆", "香火鼎盛", "万灵朝宗"]
const 信徒增益花费: Dictionary = {"香火初兴": 50, "香火渐隆": 200, "香火鼎盛": 500, "万灵朝宗": 1000}
# === S1 ：-B：辈分礼制体系（纯经营层 · 字派序列 / 门规严格度）===
# 旧档 辈分字派 ：：首次推演：首次招徒自动生成并持久化（见 _确保字派_S1）；不升 SAVE_VERSION）
var 辈分字派: Array = []
var 门规严格度: String = "中庸"
# === S1 ：-C：正邪路线抉择（纯经：叙事：· 不可逆标：· 数：[PLACEHOLDER] 待真机校准）===
var 正邪路线: String = ""     # ：未选；取：{玄门正道, 逍遥中立, 九幽邪道}（D7 已拍板）
# === P3：功德/业力（支撑正邪路线） + 愿力（香火→修为升华链路）===
#   功德：正行累积（供奉香火等），选「玄门正道」需≥正道功德门槛。
#   业力：邪行累积（祭炼/九幽邪道链等），选「九幽邪道」需≥邪道业力门槛。
#   愿力：香火升华所得软货币，可转为悟道点+灵气（修为升华）。
var 功德 := 0
var 业力 := 0
var 愿力 := 0
const 正道功德门槛: int = 100   # P3：择 玄门正道 所需最小功德（[PLACEHOLDER] 待真机校准）
const 邪道业力门槛: int = 100   # P3：择 九幽邪道 所需最小业力（[PLACEHOLDER] 待真机校准）
const 正道每步功德: int = 25   # P3：正道链每步累计功德（4 步满链恰达门槛100，[PLACEHOLDER] 待校准）
const 邪道每步业力: int = 25   # P3：邪道链每步累计业力（4 步满链恰达门槛100，[PLACEHOLDER] 待校准）
# 连锁进度： chain_id -> {"done": int (已完成步数), "完成": bool}；驱动 正道/邪道链 累积 功德/业力
var 连锁进度: Dictionary = {}
# === S1 赛季战令（功：/ 宗门：/ 对外包装「宗门季度法旨」）：UI 已落地，数据层补全；不升 SAVE_VERSION，旧档缺键→默认零回归===
#     战令_经验 对外称「功绩值」，与弟子晋升「功勋」严格区分（白皮书世界观统一铁律）：
#     TODO S2 重构：本区块战令业务逻辑迁移：BattlePassManager 单例（game_state 纯数据只读铁律）：
var 战令_赛季: int = 1
var 战令_等级: int = 0
var 战令_经验: int = 0
var 战令_已购付费轨: bool= false
var 战令_已领免费: Array = []
var 战令_已领付费: Array = []
# === S1 ：-A：宗门大阵（纯经营系：· 数据：· 数：[PLACEHOLDER] 待真机校准· 不升 SAVE_VERSION）==
# 结构：当前主：String)/等级(Dict array_id→int)/耐久(Dict array_id→int)/已解：Dict array_id→bool)
var 宗门大阵: Dictionary = {"当前主阵":"", "等级":{}, "耐久":{}, "已解": {}}
# 阵法配置表缓存（：_加载阵法配置_S1 ：config/array_config.csv 读入，键=array_id：
var 阵法配置表: Dictionary = {}
# 阵法物品表（D5 阵图解锁闭环）：：_加载阵法物品_S1 ：config/array_items.csv 读入
# 阵法物品表 item_id ：行；阵法物品名表: 名称 ：行（背包 Item 仅携名称，按名检索）；阵法_按阵法 array_id ：图书：
var 阵法物品表: Dictionary = {}
var 阵法物品名表: Dictionary = {}
var 阵法_按阵法: Dictionary= {}
# === S1 ：：日供（原签到系统修真化包装；轻量数据层，零核心数值改动）===
var 日供_最后领取日: int = 0     # 上次领取日供时的累计游戏日（0=从未领取：
var 连续理事天数: int = 0       # 连续领取日供天数（中断则：：
var 日供_总领取次数: int= 0    # 累计领取次数（成：纪事用）
var 回溯玉符数量: int = 0       # 补领道具（S1 占位，后续接获取途径：
# ===== S1 成就系统统计变量（2026-08-30 第三阶段新增）=====
var 累计炼制丹药数: int = 0       # 累计炼制丹药数量（成就用）
var 累计锻造装备数: int = 0       # 累计锻造装备数量（成就用）
var 累计灵石收入: int = 0         # 累计灵石收入（成就用）
var 累计招募弟子数: int = 0       # 累计招募弟子数量（成就用）
var 累计弟子突破次数: int = 0     # 累计弟子突破次数（成就用）
var 累计坊市交易次数: int = 0     # 累计坊市交易次数（成就用）
# ===== S1 成就系统统计变量（2026-08-30 第四阶段新增）=====
var 累计灵田产出: int = 0           # 累计灵田产出灵草数量（成就用）
var 累计矿场产出: int = 0           # 累计矿场产出矿石数量（成就用）
var 累计提升灵根次数: int = 0       # 累计使用洗髓丹提升灵根次数（成就用）
var 累计提升心境次数: int = 0       # 累计使用清心丹提升心境次数（成就用）
var 累计延长寿元次数: int = 0       # 累计使用长生丹延长寿元次数（成就用）
var 累计修复道伤次数: int = 0       # 累计使用道愈丹修复道伤次数（成就用）
# ===== S1 成就系统统计变量（2026-08-30 第五阶段新增）=====
var 累计制作傀儡数: int = 0           # 累计制作傀儡数量（成就用）
var 累计发放俸禄次数: int = 0         # 累计发放俸禄次数（成就用）
var 藏书阁收录数: int = 0             # 藏书阁收录典籍数量（成就用）
var 药园已解锁地块: int = 1           # 药园已解锁地块数量（成就用，默认1块）
var 已解锁丹方数: int = 0             # 已解锁丹方数量（成就用）
var 已解锁装备图纸数: int = 0         # 已解锁装备图纸数量（成就用）
# ===== S1 傀儡系统和藏书阁系统（2026-08-30 新增）=====
var 傀儡列表: Array = []                # 傀儡列表（{ID, 名称, 品阶, 类型, 等级, 效果}）
var 傀儡ID计数器: int = 0               # 傀儡ID计数器
var 藏书阁列表: Array = []              # 藏书阁收录典籍列表（{ID, 名称, 品阶, 类型, 描述}）
var 藏书阁ID计数器: int = 0             # 藏书阁ID计数器
var 藏书阁临时加成: float = 0.0           # 藏书阁阅读临时修炼加成
var 藏书阁加成到期日: int = 0              # 藏书阁加成到期日
# ===== S1 药园系统、丹方系统、装备图纸系统（2026-08-30 新增）=====
var 药园地块列表: Array = []               # 药园地块列表（{ID, 已解锁, 种植物品, 成熟时间}）
var 药园地块数量: int = 1                  # 药园已解锁地块数量（默认1块）
var 已解锁丹方列表: Array = []             # 已解锁丹方列表（{丹方ID, 名称, 品阶, 材料}）
var 已解锁装备图纸列表: Array = []         # 已解锁装备图纸列表（{图纸ID, 名称, 品阶, 材料}）
# 获取签到日历（显示最近30天签到情况）
func 获取签到日历() -> Array:
	var 日历 = []
	for i in range(30):
		var 日期 = 累计游戏日 - 29 + i
		var 已签到 = 日期 <= 日供_最后领取日 and 日期 > 0
		日历.append({
			"日期": 日期,
			"已签到": 已签到,
			"是今天": 日期 == 累计游戏日,
		})
	return 日历

# 获取连续签到奖励列表
func 获取连续签到奖励列表() -> Array:
	return [
		{"天数": 7, "奖励": "稀有宝箱×1 + 灵品装备碎片×3", "已达成": 连续理事天数 >= 7},
		{"天数": 30, "奖励": "史诗宝箱×1 + 宝品装备碎片×5 + 灵品功法碎片×3", "已达成": 连续理事天数 >= 30},
		{"天数": 100, "奖励": "传说宝箱×1 + 王品装备碎片×5", "已达成": 连续理事天数 >= 100},
		{"天数": 365, "奖励": "专属称号 + 仙品装备碎片×10", "已达成": 连续理事天数 >= 365},
	]

# 获取签到统计
func 获取签到统计() -> Dictionary:
	return {
		"连续天数": 连续理事天数,
		"总领取次数": 日供_总领取次数,
		"今日可领": 日供_今日可领(),
		"回溯玉符数量": 回溯玉符数量,
	}

# 日贡奖励配置（符合修真界命名）
const 日贡奖励配置: Dictionary = {
	1: {"灵石": 100, "灵气": 20, "悟道点": 5, "描述": "初入道门，微薄供奉"},
	2: {"灵石": 120, "灵气": 25, "悟道点": 6, "描述": "心诚则灵，供奉渐增"},
	3: {"灵石": 150, "灵气": 30, "悟道点": 8, "描述": "道心坚定，赏赐有加"},
	4: {"灵石": 180, "灵气": 35, "悟道点": 10, "描述": "修行有成，宗门嘉奖"},
	5: {"灵石": 200, "灵气": 40, "悟道点": 12, "描述": "五朝元老，礼遇有加"},
	6: {"灵石": 250, "灵气": 50, "悟道点": 15, "描述": "六根清净，境界提升"},
	7: {"灵石": 300, "灵气": 60, "悟道点": 20, "描述": "七日圆满，稀有宝箱×1"},
	14: {"灵石": 500, "灵气": 100, "悟道点": 30, "描述": "半月虔诚，史诗宝箱×1"},
	30: {"灵石": 1000, "灵气": 200, "悟道点": 50, "描述": "一月苦修，传说宝箱×1"},
	100: {"灵石": 3000, "灵气": 500, "悟道点": 100, "描述": "百日筑基，专属称号"},
	365: {"灵石": 10000, "灵气": 2000, "悟道点": 300, "描述": "一年修行，仙品装备碎片×10"},
}

# 获取今日日贡奖励
func 获取今日日贡奖励() -> Dictionary:
	var 连续天数 = 连续理事天数 + 1  # 今天签到后的连续天数
	var 奖励配置 = 日贡奖励配置.get(1, {})
	# 查找最接近的连续天数奖励
	for 天数 in 日贡奖励配置.keys():
		if 连续天数 >= 天数:
			奖励配置 = 日贡奖励配置[天数]
	return {
		"连续天数": 连续天数,
		"灵石": int(奖励配置.get("灵石", 100)),
		"灵气": int(奖励配置.get("灵气", 20)),
		"悟道点": int(奖励配置.get("悟道点", 5)),
		"描述": str(奖励配置.get("描述", "")),
	}

# 获取累计签到奖励列表
func 获取累计签到奖励列表() -> Array:
	var 奖励列表 = []
	for 天数 in 日贡奖励配置.keys():
		var 配置 = 日贡奖励配置[天数]
		奖励列表.append({
			"天数": 天数,
			"灵石": int(配置.get("灵石", 0)),
			"灵气": int(配置.get("灵气", 0)),
			"悟道点": int(配置.get("悟道点", 0)),
			"描述": str(配置.get("描述", "")),
			"已达成": 日供_总领取次数 >= 天数,
		})
	# 按天数排序
	奖励列表.sort_custom(func(a, b): return a["天数"] < b["天数"])
	return 奖励列表

# 获取日贡详细统计
func 获取日贡详细统计() -> Dictionary:
	var 今日奖励 = 获取今日日贡奖励()
	var 累计奖励 = 获取累计签到奖励列表()
	var 已达成累计奖励数 = 0
	for 奖励 in 累计奖励:
		if 奖励.get("已达成", false):
			已达成累计奖励数 += 1
	return {
		"连续天数": 连续理事天数,
		"总领取次数": 日供_总领取次数,
		"今日可领": 日供_今日可领(),
		"回溯玉符数量": 回溯玉符数量,
		"今日奖励": 今日奖励,
		"累计奖励总数": 累计奖励.size(),
		"已达成累计奖励数": 已达成累计奖励数,
		"累计奖励完成率": float(已达成累计奖励数) / float(max(1, 累计奖励.size())),
	}

# 补签（使用回溯玉符补签昨天）
func 补签昨天() -> Dictionary:
	if 回溯玉符数量 <= 0:
		return {"成功": false, "原因": "回溯玉符不足"}
	if 日供_最后领取日 == 累计游戏日 - 1:
		return {"成功": false, "原因": "昨天已签到，无需补签"}
	if 日供_最后领取日 >= 累计游戏日:
		return {"成功": false, "原因": "今天已签到"}
	回溯玉符数量 -= 1
	日供_最后领取日 = 累计游戏日 - 1
	连续理事天数 += 1
	日供_总领取次数 += 1
	添加纪事("庶务", "补签", "使用回溯玉符补签昨天，连续签到%d天" % 连续理事天数, 1)
	return {"成功": true, "连续天数": 连续理事天数, "消息": "补签成功"}

# 日供公共 API（供 UI 调用；只：轻量写，不触碰核心数值）
func 日供_今日可领() -> bool:

	return 日供_最后领取日 != 累计游戏日
func 日供状态() -> Dictionary:

	return {
		"今日可领": 日供_今日可领(),
		"连续天数": 连续理事天数,
		"总次数": 日供_总领取次数,
		"加成": 日供职司加成(),
	}
func 日供职司加成() -> Array[Dictionary]:

	var out: Array[Dictionary] = []
	var mapping: Dictionary = {
		"lingtian": {"资源": "灵草", "字段": "灵草", "描述": "灵植堂主在任，草药供：5%"},
		"kuangmai": {"资源": "矿石", "字段": "矿石", "描述": "矿务堂主在任，矿石供：5%"},
		"zhenfa":   {"资源": "灵气", "字段": "灵气", "描述": "阵堂堂主在任，灵气供：5%"},
		"yuying":   {"资源": "灵石", "字段": "灵石", "描述": "商务堂主在任，灵石供：5%"},
	}
	for key in mapping.keys():
		var 项: Dictionary = 司职列表.get(key, {})
		if 项.get("负责", null) != null:
			var item: Dictionary = mapping[key].duplicate()
			item["堂主"] = (项["负责"] as Disciple).姓名
			out.append(item)
	return out
func 领取日供() -> Dictionary:

	if not 日供_今日可领():
		return {"ok": false, "msg": "今日供奉已受领"}
	# 连续天数计算
	if 日供_最后领取日 == 累计游戏日- 1:
		连续理事天数 += 1
	else:
		连续理事天数 = 1
	# P2-12：未领日供累积（最多补领3天，缓解「忘领即损失」挫败感）
	var 缺领: int = max(0, 累计游戏日 - 日供_最后领取日 - 1)
	var 倍: int = 1 + min(缺领, 3)
	日供_最后领取日 = 累计游戏日
	日供_总领取次数+= 1
	# 基础供奉：10 绑定仙玉（S2-数值平衡：原30/日导致98元礼包仅值2.3小时免费产出，现降至10/日使付费价值感提升3倍）
	仙玉_绑定 += 10 * 倍
	var msg: String = "受领日供，绑定仙玉+%d" % (10 * 倍)
	if 缺领 > 0:
		msg += "（补领%d天）" % 缺领
	# 职司加成（轻：+1 对应资源，不破坏经济：
	for b in 日供职司加成():
		var 字段: String = b["字段"]
		var 数量: int = 1 * 倍
		if 字段 == "灵石":
			灵石 += 数量
		elif 字段 == "灵草":
			灵草 += 数量
			累计灵田产出 += 数量
			_复检成就()
		elif 字段 == "矿石":
			矿石 += 数量
			累计矿场产出 += 数量
			_复检成就()
		elif 字段 == "灵气":
			灵气 += 数量
		msg += "：s+%d" % [b["资源"], 数量]
	# 纪事联动
	if 连续理事天数 == 7:
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "小周天赐福", "文案": 文案表["chronicle_seven_day_blessing"]})
		# 连续签到7天奖励：稀有宝箱×1 + 灵品装备碎片×3
		添加宝箱("chest_rare", 1)
		添加碎片("frag_equip_rare", 3)
		msg += "，连续7天奖励：稀有宝箱+1，灵品装备碎片+3"
	elif 连续理事天数 == 30:
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "月度道统厚礼", "文案": 文案表["chronicle_monthly_tao"]})
		# 连续签到30天奖励：史诗宝箱×1 + 宝品装备碎片×5 + 灵品功法碎片×3
		添加宝箱("chest_epic", 1)
		添加碎片("frag_equip_epic", 5)
		添加碎片("frag_gongfa_rare", 3)
		msg += "，连续30天奖励：史诗宝箱+1，宝品装备碎片+5，灵品功法碎片+3"
	elif 连续理事天数 == 100:
		# 连续签到100天奖励：传说宝箱×1 + 王品装备碎片×5
		添加宝箱("chest_legendary", 1)
		添加碎片("frag_equip_legendary", 5)
		msg += "，连续100天奖励：传说宝箱+1，王品装备碎片+5"
	else:
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "庶务", "名称": "受领日供", "文案": 文案表["chronicle_daily_tribute"]})
		# 日常签到随机奖励：10%概率获得凡品装备碎片，5%概率获得普通宝箱
		if randf() < 0.10:
			添加碎片("frag_equip_common", 1)
			msg += "，凡品装备碎片+1"
		if randf() < 0.05:
			添加宝箱("chest_common", 1)
			msg += "，普通宝箱+1"
	return {"ok": true, "msg": msg}
# 弟子已解锁单人法阵集合（D5）：姓名 ：Array[String]（宗门大阵另：宗门大阵.已解锁）
var 已解锁单人法阵: Dictionary = {}
# P1：周期结算评分（年结：游戏年 = 365 日）
var 周期评分: PeriodSettlement = PeriodSettlementScript.new()
var 上次结算年:= 0            # 上次年结时的累计游戏日，用于：365 日边界检：
# ===== 双周期评级（1年小：+ 7年大考）状：=====
var 双周期评级启用: bool = true   # 全局回退开关（true=七载双周期；false=回退纯年度实时，：config/评级节奏.csv：
var 七载赏赐池: int = 0          # 年度评定 deferred ：30% 灵石累积：
var 七载待发掉落: Array = []     # 年度评定 deferred ：S 级以上高阶法宝（按评级记录）
var 门派等级目标: int = 1        # 七载模式下「成长值中间量」，七载大考才生效
var 上次七载日: int = 0          # 上次七载大考时的累计游戏日，用于跨 2555 日边界检：
var 七载大典待展示: bool = false   # 七载大考触发的瞬时展示标记（不存档），main._构建离山内容 读取后置 false
var 七载大典摘要: Dictionary = {}  # 七载大典待展示时承载的展示数据（灵石/法宝：晋升至），不存档
var 年始灵石 := 0             # 本年起始灵石（结算时算增量）
var 年始总战力:= 0           # 本年起始宗门总战力（结算时算增量：
var 最新周期评级卡: Dictionary = {}   # 最近一次结算评级卡，供离山汇总展：
var 历史周期评级: Array = []       # ：12 周期评级（与 周期评分.历史 同步：
var 引导阶段: int = 0   # 新手入门指引：序章/1-5五步/6完成（老档兼容：load_game 默认6：
var 上次测灵日:= 0        # 测灵根冷却：上次举办时的游戏日（1年一：365游戏日）
# 司职系统：{key: {key,名称,职能,产出,加成维度,负责：Disciple,成员:Array}}
var 司职列表: Dictionary = {}
var 司职负责人存档: Dictionary = {}
var 司职状态存档: Dictionary = {}   # S1 ：：司职等：政绩持久化（：司职负责人存：范式：
# ============ 殿阁被动（阶：：占位殿阁被动功能）============
# 资源翻倍类：本月各资源殿阁实际产出额（：_殿阁被动结算 概率翻倍时直接加回，避免重复计：经营/气运/产出 乘区：
var _本月灵田产出: int = 0
var _本月矿脉产出: int = 0
var _本月丹堂产出: int = 0
var _本月器殿产出: int = 0
# 器殿赠宝 P1 状态（轻量；序列化持久化，不升 SAVE_VERSION，旧档缺键→默认零回归）
var _上次出战弟子: Array = []          # 最近出战阵容（存弟子姓名；挑战秘境 写入；save/load 持久化）
var _器殿赠宝未中上阵连计: int = 0     # 保底计数器：连续未把赠宝发给上阵弟子的次数（： 下月强制上阵档）
var _器殿赠宝表: Array= []            # craft_hall_reward.csv 缓存（懒加载，_读器殿赠宝行 首次触发：
# S1 ： D7：Lv.2+ 保底津贴基数（每：等级×基数 灵石，[PLACEHOLDER] 待数：GDD 校准：
const 殿阁保底津贴: int = 5
# [DORMANT] 负面事件减免聚合（zhifa/tanwei/zhenfa）：当前无负：入侵事件系统，仅暂存不消：
var 殿阁被动_负面事件减免: float = 0.0
# 推演日志（本次登录汇总，结构化条目供 UI 分层展示：
# 每条: {event_type:String, priority:String, text:String, data:Dictionary}
# event_type 枚举: breakthrough / appoint / quest / loot / resource / sect / info
# priority 枚举: high / normal / trivial
var 推演日志: Array[Dictionary] = []
# 推演事件类型常量（与 UI 符号图标映射：
const ET_BREAKTHROUGH := "breakthrough"   # 🔺 境界突破
const ET_APPOINT     := "appoint"         # 📜 岗位任职
const ET_QUEST       := "quest"           # ：：奇遇/探索事件
const ET_LOOT        := "loot"            # 🎁 获得物品
const ET_RESOURCE    := "resource"        # 💰 资源产出
const ET_SECT        := "sect"            # 📜 宗门事件
const ET_INFO        := "info"            # ℹ️ 系统信息
# 推演优先级常：
const PRIO_HIGH   := "high"     # 重大事件（突：稀有道具）
const PRIO_NORMAL := "normal"   # 普通（任职/正向奇遇：
const PRIO_TRIVIAL:= "trivial"  # 琐事（无功而返/无赏赐）
# 战斗/历练系统（Day 2 数据驱动：
var 体力 := 50
var 累计探索次数 := 0  # 累计探索次数
var 修炼进度 := 0.0  # 修炼进度（0-1）
var 累计培养弟子数 := 0  # 累计培养弟子数
var 灵晶 := 0  # 灵晶数量
var 道心 := 50  # 道心值，影响修炼效率
var 攻击 := 10  # 攻击力，影响战斗输出
var 已通关秘境: Dictionary = {}      # stage_id -> true（首通标记，解锁下一关用：
var 精英每日次数: Dictionary = {}     # "%d" % 累计游戏日-> {stage_id: 已挑战次数}
signal 弟子变动()
signal 战报更新(文本: String)
# Step 1 奇遇三场景接入：任一触发点命中奇遇后 emit，供 main.gd（Step 2）做 L1 气泡 / L2 弹窗 / L3 全屏 调度：
signal 奇遇发生(q: Dictionary, 弟子: Disciple)
# WAVE-D #6/#8：图：里程碑变：：main.gd 刷新二级页（B2 次页，不新增 Tab：
signal 图录更新
signal 里程碑更新
# S1 ：：成就变：：main.gd 刷新 page_quest 成就 Tab（红：列表/点数：
signal 成就更新
signal 邮件变动
# 通用轻提示：二级页/系统页调 Game.添加提示(文本) 反馈，由 GameUI 连接 提示 信号转 toast。
# 无监听时静默降级为 print，杜绝「调用不存在的提示函数」导致的运行时崩溃。
signal 提示(文本: String)
func 添加提示(文本: String) -> void:
	if 提示.get_connections().is_empty():
		print("[提示] %s" % 文本)
		return
	提示.emit(文本)
# ============ 殿阁被动·常驻乘区（阶：：占位殿阁被动功能）============
# 12 司职始终存在：司职列表（重建司：全量创建），故以下「殿阁存在即生效」的常驻效果恒生效：
# 全部作用于既有计算链路的对应乘区，绝不污染奇遇池（event_quest / quest.gd / 奇遇发生 signal）：
# 执事殿：接引大典高品质弟子概：+2%（与阶段1 负责人测：1% 叠加，最高3%：
func _执事殿测灵加() -> float:

	return 0.02 if 司职列表.has("yuying") else 0.0
# 功勋阁：全局声望获取 +10% ：所：声望 += 处乘此系：
func _功勋阁声望乘区() -> float:

	return 1.10 if 司职列表.has("gongxun") else 1.0
# 藏经阁：全宗弟子 修炼速度 +5%（并：推演一：宗门加成pct，加法叠加封顶+100%：
func _藏经阁修炼乘区() -> float:

	return 1.05 if 司职列表.has("cangjing") else 1.0
# S1 ：-A：宗门大阵·聚灵大阵（arr_s_002）修炼乘区（：_藏经阁修炼乘区）：
# 仅当前主阵为聚灵大阵时提供修炼速度增益；其余阵（护：镇煞/玄空）不作用于修炼乘区：
# 数：[PLACEHOLDER]：eff_val_base/level_growth_coef 取自 array_config.csv（本批用投稿值）：
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
# [DORMANT] 负面事件减免聚合：zhifa -15% / tanwei -5% / zhenfa -12%，叠加封：-30%
# 当前宗门事件（Lore.取宗门事件）均为正面 flavor，无负面/入侵事件系统 ：本值暂存不消费：
# 未来接入负面事件判定点时，于该判定处：(1.0 + 本： 即可生效：
func _负面事件减免() -> float:

	var v: float = 0.0
	if 司职列表.has("zhifa"):
		v -= 0.15
	if 司职列表.has("tanwei"):
		v -= 0.05
	if 司职列表.has("zhenfa"):
		v -= 0.12
	return max(v, -0.30)
# 获取所有建筑列表（包含等级和加成）
func 获取所有建筑列表() -> Array:
	var 建筑列表 = []
	# 定义所有建筑
	var 建筑配置 = {
		"lingtian": {"名称": "灵田", "描述": "产出灵石和灵草", "类型": "产出"},
		"kuangmai": {"名称": "矿脉", "描述": "产出矿石", "类型": "产出"},
		"dantang": {"名称": "丹堂", "描述": "提升炼丹成功率", "类型": "功能"},
		"qitang": {"名称": "器堂", "描述": "提升锻造成功率", "类型": "功能"},
		"cangjing": {"名称": "藏经阁", "描述": "提升修炼速度", "类型": "功能"},
		"zhifa": {"名称": "执法堂", "描述": "减少负面事件", "类型": "功能"},
		"gongxun": {"名称": "功勋阁", "描述": "提升声望获取", "类型": "功能"},
		"tanwei": {"名称": "探微阁", "描述": "提升探索收益", "类型": "功能"},
		"yuying": {"名称": "育英堂", "描述": "提升弟子培养效率", "类型": "功能"},
		"yushou": {"名称": "御兽堂", "描述": "提升灵兽能力", "类型": "功能"},
		"zhenfa": {"名称": "阵法堂", "描述": "提升阵法效果", "类型": "功能"},
		"xichi": {"名称": "洗池", "描述": "提升弟子突破成功率", "类型": "功能"},
	}
	for 建筑ID in 建筑配置.keys():
		var 配置 = 建筑配置[建筑ID]
		var 等级 = 0
		if 司职列表.has(建筑ID):
			var 职 = 司职列表[建筑ID]
			等级 = int(职.get("等级", 1))
		建筑列表.append({
			"建筑ID": 建筑ID,
			"名称": 配置.get("名称", ""),
			"描述": 配置.get("描述", ""),
			"类型": 配置.get("类型", ""),
			"等级": 等级,
			"已解锁": 等级 > 0,
		})
	return 建筑列表

# 获取建筑总加成
func 获取建筑总加成() -> Dictionary:
	var 加成 = {"修炼速度": 0.0, "产出": 0.0, "声望": 0.0, "炼丹成功率": 0.0, "锻造成功率": 0.0}
	# 藏经阁：修炼速度+5%
	if 司职列表.has("cangjing"):
		加成["修炼速度"] += 0.05
	# 功勋阁：声望+10%
	if 司职列表.has("gongxun"):
		加成["声望"] += 0.10
	# 丹堂：炼丹成功率+5%
	if 司职列表.has("dantang"):
		加成["炼丹成功率"] += 0.05
	# 器堂：锻造成功率+5%
	if 司职列表.has("qitang"):
		加成["锻造成功率"] += 0.05
	return 加成

# 声望统一结算入口（套用功勋阁常驻 +10% 乘区；不触碰战斗数值红线）
func _加声望(基础: int) -> void:

	声望 += int(round(基础 * _功勋阁声望乘区()))
var 文案表: Dictionary = {}
func _载入文案表() -> void:
	var f = FileAccess.open("res://config/lore_narrative.csv", FileAccess.READ)
	if f == null:
		push_warning("lore_narrative.csv 缺失，文案表为空")
		return
	f.get_csv_line()  # 跳过 header
	while not f.eof_reached():
		var parts = f.get_csv_line()
		if parts.size() < 2:
			continue
		var k = parts[0].strip_edges()
		if k.is_empty():
			continue
		文案表[k] = parts[1]
	f.close()
func _ready():
	_载入文案表()
	迁移旧单档()          # 多账：v1：首启把遗留单档迁移为第一个账号，避免本地进度丢失
	_加载图录配置()      # WAVE-D #6（须：_记录图录/_传承事件 之前：
	_加载里程碑配置()    # WAVE-D #8（须：_传承事件/_复检里程：之前：
	_加载成就配置()      # S1 ：：成就配置（须在 _复检成就 之前；缺失文件不崩）
	_加载阵营任务配置()  # 阵营任务配置
	_加载阵营商店配置()  # 阵营商店配置
	if 当前账号id != "" and 弟子列表.is_empty():
		初始建宗()
		_传承事件("开宗立派")   # WAVE-D #8：新游戏即达成「开宗立派」里程碑 + 先贤事迹图录
		save_game()              # 首次建宗后自动存档，确保下次启动出现「继续游戏：
	重建司职()
	_加载彩蛋配置()
	_加载节奏校准()
	_加载阵法配置_S1()
	_加载阵法物品_S1()
	_复检里程碑()            # WAVE-D #8：load/新局后按当前状态补达成阈：状态里程碑
	_复检成就()              # S1 ：：load/新局后按当前状态补达成阈值成就（与里程碑同步：
	弟子变动.emit()
	# 月末/推演结束：统一检测里程碑与成就（防漏检）
	_复检里程碑()
	_复检成就()
# WAVE-B #2：取弟子纪事（按 弟子ID 过滤；旧：entry ：弟子ID 时回退 弟子==姓名，兼容旧档）
func 取弟子纪事(目标ID: int, 姓名: String = "") -> Array:

	var 结果: Array = []
	for 条 in 宗门纪事:
		var 记ID: int = int(条.get("弟子ID", 0))
		if 记ID != 0:
			if 记ID == 目标ID:
				结果.append(条)
		elif 姓名 != "" and 条.get("弟子", "") == 姓名:
			结果.append(条)
	return 结果
# 初始建宗（首次运行）：若干练气弟：+ 一位已入门长老作示范
func 初始建宗():

	for i in 5:
		弟子列表.append(Disciple.new())
	# 一位创始人：直接筑基入门，展示道：司职
	var 新:= Disciple.new()
	新.突破()           # 练气→筑基，触发 判定道途+ 入堂
	弟子列表.append(新)
# 头像是否解锁（一渠道双解锁：渠道可独立解锁头像）
func 是否已解锁头像(头像id: String) -> bool:

	return 已解锁头像.has(头像id)
# 初始可选头像（catalog.unlocked=true）种子化：已解锁头像：弹窗：catalog.unlocked 判定可点：
# ：设置当前头像 守卫：已解锁头：has(id)，若未种子化则选中后静默丢弃、头像永不更新：
func _种子化默认解锁头像() -> void:

	for d in 宗主头像目录:
		if d.get("unlocked") if "unlocked" in d else false:
			var 头像id: String = d.get("id") if "id" in d else ""
			if not 头像id.is_empty():
				解锁头像(头像id)
# 解锁头像（一渠道双解锁：渠道同时解锁头像：
func 解锁头像(头像id: String) -> void:

	if not 已解锁头像.has(头像id):
		已解锁头像.append(头像id)
# 取可解锁头像列表（返回已解锁头像 id 对应的定义；可按 channel 过滤后
func 取可解锁头像列表(渠道: String = "") -> Array:

	var out: Array = []
	for aid in 已解锁头像:
		var d: Dictionary = 取宗主头像定义(aid)
		if not d.is_empty() and (渠道 == "" or d.get("channel") if "channel" in d else "" == 渠道):
			out.append(d)
	return out
# 设置当前头像（校验已解锁，否则忽略）
func 设置当前头像(头像id: String) -> void:

	if 头像id == "" or 已解锁头像.has(头像id):
		宗主头像 = 头像id
# 当前 VIP 等级（仅由累充元派生，只读；不含任何 VIP 权益，仅玉牌材质品阶判定用）
# 注意：原 `VIP累充阈值表` const 数组已于 2026-08-21 随头像框系统取消：
# 当时误将「VIP 累充档位阈值」与「头像框用的奇遇/图录阈值表」一并删除，但此表是 VIP 等级
# （→玉牌材质）派生的必备数据。本函数改用内联档位近似（业内常：6/30/68/128/298/648/
# 1000/2000/3000/5000/8888/12888 阈值），不引入对外可见：const，避免重复命名冲突；
# 后续若商店数值定型后可微调具体金额：
func 当前VIP等级() -> int:

	var lv: int = 0
	var 累充档位: Dictionary = {
		1: 6, 2: 30, 3: 68, 4: 128, 5: 298,
		6: 648, 7: 1000, 8: 2000, 9: 3000, 10: 5000,
		11: 8888, 12: 12888,
	}
	for k in range(12, 0, -1):
		if 累充额>= int(累充档位[k]):
			lv = k
			break
	return lv
# 充值记录钩子（供支：SDK 接入调用；S0 暂无实际调用点）
# 仙玉_非绑：的增量由商店层负责；本函数追：累充额+ 首充标记（头像框外观解锁评估已于 2026-08-21 取消）：
func 记录充值(元额: int) -> void:

	if 元额 <= 0:
		return
	累充额+= 元额
	if not 已首充:
		已首充= true
# ============ 创建宗门·宗主头像选择系统 ============
# 头像数据见上：const 宗主头像目录。创建页通过 取宗主头像纹理/ 取宗主头像定义/
# 宗主头像是否已解锁/ 宗主头像列表 / 默认解锁头像 消费本数据：
# 旧三层捏脸系统（取宗主单层纹：/ 取宗主发型纹：/ 取宗主头像纯袍纹：/ 宗主外观资产）已废弃移除：
# 统一加载：优：res 资源（带 .import），缺失则回退直接：PNG 原图（ImageTexture：
func _加载宗主纹理(p: String) -> Texture2D:

	if p == "" or not ResourceLoader.exists(p):
		return null
	var tex: Texture2D = load(p)
	if tex == null:
		var img := Image.new()
		if img.load(p) == OK:
			tex = ImageTexture.create_from_image(img)
	return tex
# ：id 取头像定：
func 取宗主头像定义(头像id: String) -> Dictionary:
	for d in 宗主头像目录:
		var 头像id值 = d.get("id", "")
		if 头像id值 == 头像id:
			return d
	return {}
# 头像是否解锁（锁定头像不可选）
func 宗主头像是否已解锁(头像id: String) -> bool:

	var d: Dictionary = 取宗主头像定义(头像id)
	if d.is_empty():
		return false
	# 初始可选头像默认解锁
	if d.get("category", "") == "initial":
		return true
	# 渠道解锁头像需要检查已解锁头像列表
	return 已解锁头像.has(头像id)
# 取头像纹理（缺省返回当前选中头像：
func 取宗主头像纹理(头像id: String = "") -> Texture2D:

	var id: String = 头像id
	if id == "":
		id = 宗主头像
	var d: Dictionary = 取宗主头像定义(id)
	if d.is_empty():
		return null
	var tex_path: String = d.get("avatar") if "avatar" in d else ""
	if tex_path.is_empty():
		tex_path = d.get("tex") if "tex" in tex_path else ""
	return _加载宗主纹理(tex_path)
# ============ 宗主详情页只读取数（S1 新增，纯读，零玩：平衡触碰：===========
# 取全身立绘纹理（详情页用）：返回当前选中头像：tex 全立绘路径（竖图 832×1216）：
# 宗主皮肤系统：如果当前装备了宗主皮肤，优先使用皮肤立绘：
func 取宗主立绘纹理(头像id: String = "") -> Texture2D:

	# 宗主皮肤优先
	if 当前宗主皮肤 != "":
		var 皮肤路径: String = "res://art/characters/masters/skins/" + 当前宗主皮肤 + "/stand.png"
		var 皮肤纹理: Texture2D = _加载宗主纹理(皮肤路径)
		if 皮肤纹理 != null:
			return 皮肤纹理
	var id: String = 头像id
	if id == "":
		id = 宗主头像
	var d: Dictionary = 取宗主头像定义(id)
	if d.is_empty():
		return null
	var tex_path: String = d.get("tex") if "tex" in d else ""
	if tex_path.is_empty():
		tex_path = d.get("avatar") if "avatar" in tex_path else ""
	return _加载宗主纹理(tex_path)
# ============ 宗主皮肤系统（仙衣阁·宗主名===========
# 装备宗主皮肤（需要先拥有：
func 装备宗主皮肤(皮肤ID: String) -> bool:

	if 皮肤ID == "":
		当前宗主皮肤 = ""
		return true
	if not 已拥有宗主皮肤.has(皮肤ID):
		return false
	当前宗主皮肤 = 皮肤ID
	return true
# 卸下宗主皮肤（恢复基础立绘：
func 卸下宗主皮肤():

	当前宗主皮肤 = ""
# 检查是否拥有某宗主皮肤
func 是否拥有宗主皮肤(皮肤ID: String) -> bool:

	return 已拥有宗主皮肤.has(皮肤ID)
# 获得宗主皮肤（购：抽奖/活动奖励后调用）
func 获得宗主皮肤(皮肤ID: String):

	if not 已拥有宗主皮肤.has(皮肤ID):
		已拥有宗主皮肤.append(皮肤ID)
# 取当前宗主皮肤ID
func 取当前宗主皮肤() -> String:

	return 当前宗主皮肤
# ============ 弟子皮肤全局拥有记录 ============
var 已拥有弟子皮肤: Array = []
func 是否拥有皮肤(皮肤ID: String) -> bool:

	return 已拥有弟子皮肤.has(皮肤ID)
func 获得弟子皮肤(皮肤ID: String):

	if not 已拥有弟子皮肤.has(皮肤ID):
		已拥有弟子皮肤.append(皮肤ID)
# ============ 宗主皮肤全宗加成 ============
# 获取所有宗主皮肤列表
func 获取所有宗主皮肤列表() -> Array:
	var 皮肤列表 = []
	var 路径: String = "res://config/master_skin_config.csv"
	if not FileAccess.file_exists(路径):
		return 皮肤列表
	var 文件: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		return 皮肤列表
	var 表头: Array = 文件.get_csv_line()
	while not 文件.eof_reached():
		var 行: Array = 文件.get_csv_line()
		if 行.size() < 2:
			continue
		var 皮肤ID = str(行[0])
		var 皮肤名称 = str(行[1]) if 行.size() > 1 else 皮肤ID
		皮肤列表.append({
			"皮肤ID": 皮肤ID,
			"名称": 皮肤名称,
			"已拥有": 已拥有宗主皮肤.has(皮肤ID),
			"当前装备": 当前宗主皮肤 == 皮肤ID,
		})
	文件.close()
	return 皮肤列表

# 获取所有弟子皮肤列表
func 获取所有弟子皮肤列表() -> Array:
	var 皮肤列表 = []
	var 路径: String = "res://config/disciple_skin_config.csv"
	if not FileAccess.file_exists(路径):
		return 皮肤列表
	var 文件: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		return 皮肤列表
	var 表头: Array = 文件.get_csv_line()
	while not 文件.eof_reached():
		var 行: Array = 文件.get_csv_line()
		if 行.size() < 2:
			continue
		var 皮肤ID = str(行[0])
		var 皮肤名称 = str(行[1]) if 行.size() > 1 else 皮肤ID
		皮肤列表.append({
			"皮肤ID": 皮肤ID,
			"名称": 皮肤名称,
			"已拥有": 已拥有弟子皮肤.has(皮肤ID),
		})
	文件.close()
	return 皮肤列表

# 获取皮肤统计
func 获取皮肤统计() -> Dictionary:
	return {
		"宗主皮肤总数": 获取所有宗主皮肤列表().size(),
		"宗主皮肤已拥有": 已拥有宗主皮肤.size(),
		"当前宗主皮肤": 当前宗主皮肤,
		"弟子皮肤总数": 获取所有弟子皮肤列表().size(),
		"弟子皮肤已拥有": 已拥有弟子皮肤.size(),
	}

# 返回当前装备宗主皮肤的全宗加：{修为: float, 灵石: float, 全属: float}
func 取宗主皮肤全宗加成() -> Dictionary:

	var 加成 := {"修为": 0.0, "灵石": 0.0, "全属": 0.0}
	if 当前宗主皮肤 == "":
		return 加成
	var 路径: String = "res://config/master_skin_config.csv"
	if not FileAccess.file_exists(路径):
		return 加成
	var 文件: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		return 加成
	var 表头: Array = 文件.get_csv_line()
	while not 文件.eof_reached():
		var 行: Array = 文件.get_csv_line()
		if 行.size() < 2 or 行[0] == "":
			continue
		if 行[0] == 当前宗主皮肤:
			var 皮肤: Dictionary = {}
			for i in range(表头.size()):
				if i < 行.size():
					皮肤[表头[i]] = 行[i]
			加成["修为"] = float(皮肤.get("bonus_cultivation", 0))
			加成["灵石"] = float(皮肤.get("bonus_lingshi", 0))
			加成["全属"] = float(皮肤.get("bonus_all_attr", 0))
			break
	文件.close()
	return 加成
# 当前玉牌品阶（仅外观展示）：由累充派：VIP 等级 ：对应玉牌材质名（：GDD §12.5.1）：
# 头像框功能已取消：026-08-21），玉牌材质独立：VIP 等级映射，不再依赖头像框 catalog：
const 玉牌材质表: Array = ["", "青玉", "白玉", "翠玉", "碧玉", "墨玉", "玄玉", "紫玉", "奇玉", "星髓", "月华", "日耀", "太初"]
func 取当前玉牌信息() -> Dictionary:

	var lv: int = 当前VIP等级()
	if lv <= 0 or lv >= 玉牌材质表.size():
		return {"等级": 0, "材质": "未琢玉牌"}
	return {"等级": lv, "材质": 玉牌材质表[lv]}
# 按性别取头像列表（不传性别=全部：
func 宗主头像列表(性别: String = "") -> Array:

	var out: Array = []
	for d in 宗主头像目录:
		if 性别 == "" or d.get("gender") if "gender" in d else "" == 性别:
			out.append(d)
	return out
# 取某性别首个解锁的初始头像（创建页默认选中 / 旧档兼容：
func 默认解锁头像(性别: String) -> Dictionary:

	for d in 宗主头像目录:
		if d.get("gender") if "gender" in d else "" == 性别 and d.get("category") if "category" in d else "" == "initial" and d.get("unlocked") if "unlocked" in d else false:
			return d
	return {}
# 招收一名弟子（内部/自动用）
func 招收弟子() -> Disciple:

	var d := Disciple.new()
	# === S1 ：-B：新弟子道号简化生成（[PLACEHOLDER] 简化版：外：辈分字派[0]+单字：==
	_确保字派_S1()
	d.辈分序= 0   # 默认开山第1：
	if d.身份 == "外门" and not 辈分字派.is_empty():
		d.道号 = 辈分字派[0] + (d.姓名.left(1) if d.姓名.length() > 0 else "")
	# 其余阶位道号暂留：""（玩家可改）；[PLACEHOLDER] 命名规则：GDD §：2
	# 初始化弟子战力（根据境界、资质、灵根、道途等因素动态计算）
	d.战力 = d.计算战力()
	弟子列表.append(d)
	# 更新成就统计：累计招募弟子数
	累计招募弟子数 += 1
	_复检成就()  # 成就检测：弟子数量相关成就
	弟子变动.emit()
	return d
# ============ 时间推演核心 ============
# ============ S0 商店（坊市）：经济消耗出：============
var _坊市缓存: Array = []
func _坊市表() -> Array:

	if _坊市缓存.is_empty():
		for r in DestinyDataLoader._read_csv("res://config/faction_shop.csv"):
			_坊市缓存.append(r)
	return _坊市缓存
# D2 坊市动态行情：懒加：坊市行情.csv（类：-> 行）；文件缺失返回空 dict（No-op 安全：
var 坊市行情表缓存: Dictionary = {}
func _坊市行情表() -> Dictionary:

	if 坊市行情表缓存.is_empty():
		for r in DestinyDataLoader._read_csv("res://config/坊市行情.csv"):
			坊市行情表缓存[r.get("类别") if "类别" in r else ""] = r
	return 坊市行情表缓存
# 坊市周刷新：从总商品池随机：8-12 件上架（S0 P0：保留日/周限购）
# WAVE-C #7：集市激活时数量翻倍（商品倍率： 稀有商队标记（稀有权重）；仅刷新规则，零经济（价：限购通道不变：
func 刷新坊市上架():

	var 全部: Array = _坊市表()
	坊市稀有标记.clear()
	var 激活: bool = 宗门集市_激活中()
	var 配: Dictionary = 宗门集市_配置()
	var 倍率: float = float(配.get("商品倍率", 2.0)) if 激活 else 1.0
	var 基础值: int = randi_range(8, 12)
	var n: int = mini(int(round(基础值* 倍率)), 全部.size())
	坊市上架集= []
	全部.shuffle()
	for i in n:
		坊市上架集.append(全部[i].get("shop_id", ""))
	# 稀有商队：集市期间从已上架中随机挑若干打「稀有商队」标记（纯展示，零经济）
	if 激活 and 坊市上架集.size() > 0:
		# 稀有商队数量随稀有权重提升（仅展示标记数量，零经济）
		var 标数: int = mini(int(round(float(配.get("稀有权重", 3.0)))), 坊市上架集.size())
		var 表: Array = 坊市上架集.duplicate()
		表.shuffle()
		for i in 标数:
			坊市稀有标记[表[i]] = true
	坊市上架_集市标记 = 激活
# WAVE-C #7：宗门集市——配置懒加载 / 激活判：/ 日推进钩子（仅刷新规则，零经济）
func 宗门集市_配置() -> Dictionary:

	if not 宗门集市配置缓存.is_empty():
		return 宗门集市配置缓存
	# 默认（与 GDD §7.4 一致；：CSV / 解析失败→常量回退，No-op 安全：
	var 默认: Dictionary = {
		"激活日": 15, "持续天数": 3, "商品倍率": 2.0, "稀有权重": 3.0, "手续费系数": 0.9, "声望系数": 1.2
	}
	var 行: Dictionary = {}
	for r in DestinyDataLoader._read_csv("res://config/宗门集市配置.csv"):
		行= r   # 取首行（配置单行：
		if not 行.is_empty():
			break
	if not 行.is_empty():
		默认["激活日"] = int(行.get("激活日", 默认["激活日"]))
		默认["持续天数"] = int(行.get("持续天数", 默认["持续天数"]))
		默认["商品倍率"] = float(默认.get("商品倍率", 默认["商品倍率"]))
		默认["稀有权重"] = float(行.get("稀有权重", 默认["稀有权重"]))
		默认["手续费系数"] = float(行.get("手续费系数", 默认["手续费系数"]))
		默认["声望系数"] = float(默认.get("声望系数", 默认["声望系数"]))
	宗门集市配置缓存 = 默认
	return 宗门集市配置缓存
# WAVE-C #7：宗门集市是否激活（基准日默：当前累计游戏日；月内：= ：% 30，窗：[激活日, 激活日+持续)：
func 宗门集市_激活中(基准日: int = -1) -> bool:

	var 日: int = 基准日 if 基准日 >= 0 else 累计游戏日
	var 配: Dictionary = 宗门集市_配置()
	var 月内日: int = ((日% 30) + 30) % 30
	var 激活日: int = int(配.get("激活日", 15))
	var 持续: int = int(配.get("持续天数", 3))
	var 相对: int = 月内日- 激活日
	if 相对 < 0:
		相对 += 30
	return 相对 < 持续
# WAVE-C #7：日推进钩子——进：退出窗口时强制刷新坊市上架（仅刷新规则；刷新为替换语义，不会双倍上架，与周刷新天然去重：
func _宗门集市_日推进(日: int):

	var 前激活: bool = 宗门集市_激活中(累计游戏日 - 日)
	var 后激活: bool = 宗门集市_激活中(累计游戏日)
	if 后激活 and not 前激活:
		刷新坊市上架()   # 进入窗口：刷新为集市商品（数量翻：稀有商队）
	elif not 后激活 and 前激活:
		刷新坊市上架()   # 退出窗口：恢复常规上架
# 声望折扣率（索引=声望等级，clamp 防越界）
func 坊市折扣率() -> float:

	return 声望折扣表[clamp(声望, 0, 声望折扣表.size() - 1)]
# 商品实际价格（声望折扣后叠加坊市行情浮动；D2 坊市动态行情）
func 坊市实价(原价: int, 类别: String = "") -> int:

	var 折后 = ceil(原价 * 坊市折扣率())            # 现有声望折扣
	var 行情 = _坊市行情表().get(类别, {})
	var 下限 = float(行情.get("浮动下限", 0.90))
	var 上限 = float(行情.get("浮动上限", 1.10))
	var 浮动 = randf_range(下限, 上限)             # 行情价格乘数摆动
	var 价 = int(round(折后 * 浮动))
	价 = int(round(折后 * _坊市负面卖价下限))
	return 价
# 库房分类：按商品名关键词推断类别（CSV 无类别列，零字段改动：
func _坊市商品类别(行: Dictionary) -> String:

	var it: String = 行.get("item_name", "")
	if it.contains("丹"):
		return "丹药"
	if it.contains("刀") or it.contains("剑") or it.contains("甲") or it.contains("铠") or it.contains("法宝") or it.contains("符"):
		return "装备"
	if it.contains("诀") or it.contains("功") or it.contains("法"):
		return "功法"
	return "资源"
# 购买坊市物品：校验声：上架/限购/灵石，扣费入宗门库房，返：{ok, msg}
func 购买坊市物品(shop_id: String) -> Dictionary:

	var 行: Dictionary = {}
	for r in _坊市表():
		if r.get("shop_id") if "shop_id" in r else "" == shop_id:
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
	var 折后: int = 坊市物品现价(shop_id)
	var 日限: int = int(行.get("limit_daily", "0"))
	var 周限: int = int(行.get("limit_weekly", "0"))
	var 记: Dictionary = 坊市购买记录.get(shop_id, {"daily": 0, "weekly": 0, "week_start": 累计游戏日})
	if 累计游戏日 - int(记.get("week_start", 累计游戏日)) >= 7:
		记= {"daily": 0, "weekly": 0, "week_start": 累计游戏日}
	# D2 坊市动态行情：类别级月度限购（30 天窗口重置，参：week_start 逻辑宽
	if 累计游戏日- 坊市月购窗口起始日>= 30:
		坊市类别月购.clear()
		坊市月购窗口起始日= 累计游戏日
	var 行行情: Dictionary = _坊市行情表().get(类别, {})
	if not 行行情.is_empty():
		var 限额: int = int(行行情.get("限购数量", 0))
		if 限额 > 0 and int(坊市类别月购.get(类别, 0)) + 1 > 限额:
			return {"ok": false, "msg": "该类别本月限购已用完"}
	if 日限 > 0 and int(行.get("daily", 0)) >= 日限:
		return {"ok": false, "msg": "今日限购已用完"}
	if 周限 > 0 and int(记.get("weekly", 0)) >= 周限:
		return {"ok": false, "msg": "本周限购已用完"}
	if 灵石 < 折后:
		return {"ok": false, "msg": "灵石不足（需 %d 灵石，%s 声望等级，%d折）" % [折后, 声望等级名[clamp(声望, 0, 声望等级名.size() - 1)], int(坊市折扣率()) * 100]}
	灵石 -= 折后
	var it: Item = Item.new()
	it.名称 = 行.get("item_name", "未知物品")
	it.品阶 = 行.get("item_grade", "凡品")
	it.类别 = 类别
	宗门库房.append(it)
	记["daily"] = int(行.get("daily", 0)) + 1
	记["weekly"] = int(记.get("weekly", 0)) + 1
	坊市购买记录[shop_id] = 记
	坊市类别月购[类别] = int(坊市类别月购.get(类别, 0)) + 1   # D2：月度限购计：+1
	# 阵营任务进度更新：中立散修"坊市跑腿"任务
	更新阵营任务进度("中立散修", "daily", 1)
	# 成就统计：累计坊市交易次数自增
	累计坊市交易次数 += 1
	_复检成就()
	var 折扣说明: String = ""
	if 折后 != 原价:
		var 声望值: int = int(坊市折扣率()) * 100
		var 特惠倍: float = 坊市特惠倍率(shop_id)
		if 特惠倍 != 1.0:
			折扣说明 = "%s%d折·特惠%d折" % [声望等级名[clamp(声望, 0, 声望等级名.size() - 1)], 声望值, int(特惠倍 * 100)]
		else:
			折扣说明 = "%s%d折" % [声望等级名[clamp(声望, 0, 声望等级名.size() - 1)], 声望值]
	记任务进度("market_trade")   # S1-2：坊市购买（玩家决策，日常 daily_012）
	return {"ok": true, "msg": "购入 %s·%d灵石%s" % [行.get("item_name", ""), 折后, 折扣说明]}
# 获取所有商城商品列表
func 获取所有商城商品列表() -> Array:
	var 商品列表 = []
	for 商品 in _坊市表():
		var shop_id = 商品.get("shop_id", "")
		商品列表.append({
			"shop_id": shop_id,
			"item_name": 商品.get("item_name", ""),
			"item_grade": 商品.get("item_grade", "凡品"),
			"price_lingjing": 商品.get("price_lingjing", 0),
			"unlock_reputation": 商品.get("unlock_reputation", 0),
			"limit_daily": 商品.get("limit_daily", 0),
			"limit_weekly": 商品.get("limit_weekly", 0),
			"已上架": 坊市上架集.has(shop_id),
			"当前价格": 坊市物品现价(shop_id),
		})
	return 商品列表

# 获取商城商品列表（简化版本，直接调用获取所有商城商品列表）
func 获取商城商品列表() -> Array:
	return 获取所有商城商品列表()
# 获取商城统计
func 获取商城统计() -> Dictionary:
	var 商品总数 = _坊市表().size()
	var 已上架数 = 坊市上架集.size()
	var 总购买次数 = 0
	for 记录 in 坊市购买记录.values():
		总购买次数 += int(记录.get("weekly", 0))
	return {
		"商品总数": 商品总数,
		"已上架数": 已上架数,
		"总购买次数": 总购买次数,
		"当前声望折扣": int(坊市折扣率() * 100),
	}

# 获取商城分类列表
func 获取商城分类列表() -> Array:
	var 分类集合 = {}
	for 商品 in _坊市表():
		var 类别 = _坊市商品类别(商品)
		if 类别 != "":
			分类集合[类别] = true
	var 分类列表 = []
	for 类别 in 分类集合.keys():
		分类列表.append(类别)
	return 分类列表

# 按分类筛选商城商品
func 按分类筛选商城商品(分类: String) -> Array:
	var 筛选列表 = []
	var 商品列表 = 获取商城商品列表()
	for 商品 in 商品列表:
		var 商品分类 = _坊市商品类别(商品)
		if 商品分类 == 分类:
			筛选列表.append(商品)
	return 筛选列表

# 搜索商城商品
func 搜索商城商品(关键词: String) -> Array:
	var 搜索结果 = []
	var 商品列表 = 获取商城商品列表()
	for 商品 in 商品列表:
		var 商品名称 = str(商品.get("item_name", ""))
		var 商品品阶 = str(商品.get("item_grade", ""))
		if 关键词 in 商品名称 or 关键词 in 商品品阶:
			搜索结果.append(商品)
	return 搜索结果

# 商城商品排序方式
const 商城排序方式: Dictionary = {
	"价格升序": {"描述": "按价格从低到高排序", "字段": "price_lingjing", "升序": true},
	"价格降序": {"描述": "按价格从高到低排序", "字段": "price_lingjing", "升序": false},
	"品阶升序": {"描述": "按品阶从低到高排序", "字段": "item_grade", "升序": true},
	"品阶降序": {"描述": "按品阶从高到低排序", "字段": "item_grade", "升序": false},
	"名称升序": {"描述": "按名称字母顺序排序", "字段": "item_name", "升序": true},
}

# 排序商城商品
func 排序商城商品(商品列表: Array, 排序方式: String) -> Array:
	var 排序配置 = 商城排序方式.get(排序方式, {})
	if 排序配置.is_empty():
		return 商品列表
	var 字段 = str(排序配置.get("字段", ""))
	var 升序 = bool(排序配置.get("升序", true))
	var 排序后列表 = 商品列表.duplicate()
	if 字段 == "price_lingjing":
		if 升序:
			排序后列表.sort_custom(func(a, b): return float(a.get(字段, 0)) < float(b.get(字段, 0)))
		else:
			排序后列表.sort_custom(func(a, b): return float(a.get(字段, 0)) > float(b.get(字段, 0)))
	elif 字段 == "item_grade":
		var 品阶顺序 = {"凡品": 1, "灵品": 2, "宝品": 3, "王品": 4, "仙品": 5, "神品": 6}
		if 升序:
			排序后列表.sort_custom(func(a, b): return 品阶顺序.get(str(a.get(字段, "凡品")), 0) < 品阶顺序.get(str(b.get(字段, "凡品")), 0))
		else:
			排序后列表.sort_custom(func(a, b): return 品阶顺序.get(str(a.get(字段, "凡品")), 0) > 品阶顺序.get(str(b.get(字段, "凡品")), 0))
	elif 字段 == "item_name":
		if 升序:
			排序后列表.sort_custom(func(a, b): return str(a.get(字段, "")) < str(b.get(字段, "")))
		else:
			排序后列表.sort_custom(func(a, b): return str(a.get(字段, "")) > str(b.get(字段, "")))
	return 排序后列表

# 商城购买历史记录
var 商城购买历史: Array = []

# 记录商城购买
func _记录商城购买(商品ID: String, 商品名称: String, 价格: int, 数量: int = 1) -> void:
	商城购买历史.append({
		"商品ID": 商品ID,
		"商品名称": 商品名称,
		"价格": 价格,
		"数量": 数量,
		"总价格": 价格 * 数量,
		"购买日期": 累计游戏日,
	})
	# 限制历史记录数量
	if 商城购买历史.size() > 100:
		商城购买历史.remove_at(0)

# 获取商城购买历史
func 获取商城购买历史(限制数量: int = 20) -> Array:
	var 历史 = 商城购买历史.duplicate()
	历史.reverse()
	return 历史.slice(0, min(限制数量, 历史.size()))

# 获取商城购买统计
func 获取商城购买统计() -> Dictionary:
	var 总购买次数 = 0
	var 总消费灵石 = 0
	var 商品购买统计 = {}
	for 记录 in 商城购买历史:
		总购买次数 += int(记录.get("数量", 1))
		总消费灵石 += int(记录.get("总价格", 0))
		var 商品名称 = str(记录.get("商品名称", ""))
		if 商品名称 not in 商品购买统计:
			商品购买统计[商品名称] = {"购买次数": 0, "总消费": 0}
		商品购买统计[商品名称]["购买次数"] += int(记录.get("数量", 1))
		商品购买统计[商品名称]["总消费"] += int(记录.get("总价格", 0))
	return {
		"总购买次数": 总购买次数,
		"总消费灵石": 总消费灵石,
		"商品购买统计": 商品购买统计,
	}

# 商城每日特惠商品
var 商城每日特惠: Array = []
var 商城每日特惠日期: int = 0

# 生成商城每日特惠
func 生成商城每日特惠() -> Array:
	if 商城每日特惠日期 == 累计游戏日 and 商城每日特惠.size() > 0:
		return 商城每日特惠
	商城每日特惠日期 = 累计游戏日
	商城每日特惠.clear()
	var 商品列表 = 获取商城商品列表()
	if 商品列表.size() == 0:
		return 商城每日特惠
	# 随机选择3-5个商品作为每日特惠
	var 特惠数量 = min(5, max(3, 商品列表.size() / 10))
	var 已选商品 = {}
	for i in range(特惠数量):
		if 商品列表.size() == 0:
			break
		var 随机索引 = randi() % 商品列表.size()
		var 商品 = 商品列表[随机索引]
		var 商品ID = str(商品.get("shop_id", ""))
		if 商品ID in 已选商品:
			continue
		已选商品[商品ID] = true
		var 折扣率 = 0.7 + float(randi() % 20) / 100.0  # 70%-90%折扣
		var 原价 = int(商品.get("price_lingjing", 0))
		var 特惠价 = int(round(原价 * 折扣率))
		商城每日特惠.append({
			"商品": 商品,
			"原价": 原价,
			"特惠价": 特惠价,
			"折扣率": 折扣率,
			"折扣百分比": int((1 - 折扣率) * 100),
		})
	return 商城每日特惠

# 获取商城每日特惠
func 获取商城每日特惠() -> Array:
	return 生成商城每日特惠()

# S2 商队高价梯度预留（出：回收侧三档：库藏全价 ：坊市×60% ：商队高价：
# 当前坊市×60% 已启用；商队高价回收通道本期限接通（玩家向商队出售按此系数，无找回池）：
const 商队回收系数: float = 0.8   # 商队高价回收系数：当：80%：坊市×60%，体现「商队高价回收」）；S2 实装后按经济平衡校准
# ============ 坊市经营深化：出：/ 回购 / 每日特惠 ============
# 玩家向坊市出售闲置道具：回收价= 基准售价 ×60%（对：GDD §：1「系统按基准售价×60%统一回收」）：
# 灵石入袋，物品快照入「误售找回池」供原价买回。纯经济写入，不触碰战斗/装备红线：
func 出售物品给坊市(it: Variant) -> Dictionary:

	if it == null:
		return {"ok": false, "msg": "无物品"}
	var idx: int = 宗门库房.find(it)
	if idx < 0:
		return {"ok": false, "msg": "该物品不在库房"}
	var 名: String = str(it.get("名称") if "名称" in it else "未知物品")
	var 价: int = int(round(float(_品阶售价(it)) * 0.6))   # GDD：回收价 = 基准×60%
	灵石 += 价
	宗门库房.remove_at(idx)
	坊市回购列表.append({"名称": 名, "品阶": str(it.get("品阶") if "品阶" in it else "凡阶"), "类别": str(it.get("类别") if "类别" in it else ""), "价": 价, "快照": it.to_dict()})
	if 坊市回购列表.size() > 5:
		坊市回购列表.pop_front()
	# 成就统计：累计坊市交易次数自增
	累计坊市交易次数 += 1
	记任务进度("market_trade")   # S1-2：坊市出售（玩家决策，日常 daily_012）
	_复检成就()
	if has_method("save_game"):
		save_game()
	return {"ok": true, "msg": "出售 %s（回收价×60%）+%d灵石" % [名, 价]}
# 商队高价回收：玩家向来访商队出售闲置道具，回收价 = 基准售价 × 商队回收系数（当：80%，高于坊市：0%），
# 灵石入袋，物品被商队带走（不入找回池，不可原价买回）。纯经济写入，不触碰战斗/装备红线：
func 出售物品给商队(it: Variant) -> Dictionary:

	if it == null:
		return {"ok": false, "msg": "无物品"}
	var idx: int = 宗门库房.find(it)
	if idx < 0:
		return {"ok": false, "msg": "该物品不在库房"}
	var 物品名: String = str(it.get("名称") if "名称" in it else "未知物品")
	var 价: int = int(round(float(_品阶售价(it)) * 商队回收系数))   # 商队高价回收（系：> 坊市 0.6：
	灵石 += 价
	宗门库房.remove_at(idx)
	if has_method("save_game"):
		save_game()
	return {"ok": true, "msg": "售予商队 %s（高价回收%d%%）+%d灵石" % [物品名, int(商队回收系数 * 100), 价]}
# 误售找回：从回购池买回（原价，无额外损耗，降低误操作成本，对齐 GDD §七（一： 回购栏）
func 买回坊市物品(idx: int) -> Dictionary:

	if idx < 0 or idx >= 坊市回购列表.size():
		return {"ok": false, "msg": "无此找回项"}
	var e: Dictionary = 坊市回购列表[idx]
	var 额: int = int(e.get("价") if "价" in e else 0)
	if 灵石 < 额:
		return {"ok": false, "msg": "灵石不足（需 %d）" % 额}
	灵石 -= 额
	var it: Item = Item.new()
	it.from_dict(e.get("快照") if "快照" in e else {})
	宗门库房.append(it)
	坊市回购列表.remove_at(idx)
	if has_method("save_game"):
		save_game()
	return {"ok": true, "msg": "找回 %s·%d灵石" % [str(e.get("名称") if "名称" in e else ""), 额]}
func 取坊市回购列表() -> Array:

	return 坊市回购列表
# 每日特惠：每日从在架坊市商品：3 件打 7-9 折；按累计游戏日轮换，零额外经济投放（仅折扣展示 + 购买价联动）
func 刷新坊市每日特惠() -> void:

	坊市每日特惠 = []
	var 列表: Array = 坊市上架集.duplicate()
	if 列表.is_empty():
		for r in _坊市表():
			列表.append(r.get("shop_id") if "shop_id" in r else "")
	列表.shuffle()
	var n: int = mini(3, 列表.size())
	for i in n:
		var sid: String = 列表[i]
		var 倍率: float = snapped(randf_range(0.7, 0.9), 0.01)
		坊市每日特惠.append({"shop_id": sid, "倍率": 倍率})
	坊市特惠卡 = 累计游戏日
# 取每日特惠列表（懒刷新：跨日自动轮换：
func 取坊市每日特惠() -> Array:

	if 坊市特惠卡 != 累计游戏日:
		刷新坊市每日特惠()
	return 坊市每日特惠
# 单件坊市商品特惠倍率（不在特惠池 ：1.0：
func 坊市特惠倍率(shop_id: String) -> float:

	for t in 坊市每日特惠:
		if t.get("shop_id") if "shop_id" in t else "" == shop_id:
			return float(t.get("倍率") if "倍率" in t else 1.0)
	return 1.0
# 坊市商品现价（声望折扣+ 行情浮动 + 每日特惠，三折叠加）：
# 同时：UI 展示：购买坊市物品 扣费，杜绝「显示价 ：实扣价」漂移：
func 坊市物品现价(shop_id: String) -> int:

	var 行: Dictionary = {}
	for r in _坊市表():
		if r.get("shop_id") if "shop_id" in r else "" == shop_id:
			行 = r
			break
	if 行.is_empty():
		return 0
	var 原价: int = int(行.get("price_lingjing", "0"))
	var 类别: String = _坊市商品类别(行)
	var 基础: int = 坊市实价(原价, 类别)
	return int(round(float(基础) * 坊市特惠倍率(shop_id)))
# ============ S1 赛季战令（功：/ 宗门：/ 对外「宗门季度法旨」）数据：API ============
# 命名：战令升级货币对外称「功绩值」，与弟子晋升「功勋」严格区分（白皮书世界观统一铁律）：
# 赛季结算兜底规则：赛季切换时，溢出功绩值按 1:1 兑换为弟子晋升「功勋」（避免清空引发不满）；
#   S1 仅文案占位，完整逻辑：S2 BattlePassManager 一并实现：
# TODO S2 重构：下：4 个方法（战令信息 / 增加战令经验 / 领战令奖励/ 购战令付费轨）迁移至 BattlePassManager：
#   game_state 仅保留纯数据存储；当：S1 为最小验证闭环暂存，不再新增任何写入 game_state 的战令业务逻辑：
# 取战令等级表最后一行的等级作为当前赛季最大等：
func _战令最大等() -> int:

	if BattlePass.等级表.is_empty():
		return 0
	var 末行: Dictionary = BattlePass.等级表[BattlePass.等级表.size() - 1]
	return int(末行.get("等级", 0))
# 取指定等级的所需经验；等：0 为起始级，经验阈值为 0：
func _战令本级所需(等级: int) -> int:

	for r in BattlePass.等级表:
		if int(r.get("等级") if "等级" in r else -1) == 等级:
			return int(r.get("所需经验") if "所需经验" in r else 0)
	return 0
# 战令面板读数接口（page_battlepass.gd 消费的
# TODO S2 重构：迁移至 BattlePassManager.战令信息()
func 战令信息() -> Dictionary:

	var 最大: int = _战令最大等()
	return {
		"赛季": 战令_赛季,
		"等级": clamp(战令_等级, 0, maxi(最大, 1)),
		"经验": 战令_经验,
		"本级所需": maxi(_战令本级所需(战令_等级), 1),
		"最大等级": 最大,
		"已购付费轨": 战令_已购付费轨,
		"已领免费": 战令_已领免费.duplicate(),
		"已领付费": 战令_已领付费.duplicate(),
	}
# 增加战令经验（对外「功绩值」）并尝试升级；供日：周常/推演等系统调：
# TODO S2 重构：迁移至 BattlePassManager.增加功绩：)
func 增加战令经验(增量: int) -> void:

	if 增量 <= 0:
		return
	战令_经验 += 增量
	var 最大: int = _战令最大等()
	while 战令_等级 < 最大:
		var 所需: int = _战令本级所需(战令_等级)
		if 所需 <= 0 or 战令_经验 < 所需:
			break
		战令_经验 -= 所需
		战令_等级 += 1
# 领取指定轨道、指定等级奖励（page_battlepass.gd 按钮回调：
# TODO S2 重构：迁移至 BattlePassManager.领奖：)
func 领战令奖励(轨道: String, 等级: int) -> Dictionary:

	if 轨道 != "免费" and 轨道 != "付费":
		return {"ok": false, "msg": "轨道参数错误"}
	if 等级 < 1 or 等级 > 战令_等级:
		return {"ok": false, "msg": "战令等级不足（当前 Lv.%d）" % 战令_等级}
	if 轨道 == "付费" and not 战令_已购付费轨:
		return {"ok": false, "msg": "尚未解锁付费轨"}
	var 已领: Array = 战令_已领免费 if 轨道 == "免费" else 战令_已领付费
	if 等级 in 已领:
		return {"ok": false, "msg": "该奖励已领取"}
	var 奖: Dictionary = {}
	for r in BattlePass.等级表:
		if int(r.get("等级") if "等级" in r else -1) == 等级:
			奖 = r.get(轨道 + "奖励", {})
			break
	if 奖.is_empty():
		return {"ok": false, "msg": "该等级无奖励"}
	# 发放奖励
	var 明细: Array = []
	if 奖.has("灵石"):
		var v: int = int(奖["灵石"])
		灵石 += v
		明细.append("灵石+%d" % v)
	if 奖.has("灵气"):
		var v: int = int(奖["灵气"])
		灵气 += v
		明细.append("灵气+%d" % v)
	if 奖.has("灵草"):
		var v: int = int(奖["灵草"])
		灵草 += v
		明细.append("灵草+%d" % v)
	if 奖.has("矿石"):
		var v: int = int(奖["矿石"])
		矿石 += v
		明细.append("矿石+%d" % v)
	if 奖.has("声望"):
		var v: int = int(奖["声望"])
		声望 += v
		明细.append("声望+%d" % v)
	if 奖.has("绑定仙玉"):
		var v: int = int(奖["绑定仙玉"])
		仙玉_绑定 += v
		明细.append("绑定仙玉+%d" % v)
	if 奖.has("皮肤"):
		var skin_id: String = str(奖["皮肤"])
		当前皮肤 = skin_id
		明细.append("外观·%s" % skin_id)
	# 碎片奖励（frag_开头的键）
	for key in 奖.keys():
		if str(key).begins_with("frag_"):
			var frag_id: String = str(key)
			var frag_count: int = int(奖[key])
			if frag_count > 0:
				添加碎片(frag_id, frag_count)
				明细.append("%s+%d" % [frag_id, frag_count])
	# 宝箱奖励（chest_开头的键）
	for key in 奖.keys():
		if str(key).begins_with("chest_"):
			var chest_id: String = str(key)
			var chest_count: int = int(奖[key])
			if chest_count > 0:
				添加宝箱(chest_id, chest_count)
				明细.append("%s+%d" % [chest_id, chest_count])
	已领.append(等级)
	return {"ok": true, "msg": "%s Lv.%d 奖励：%s" % [轨道, 等级, "·".join(明细)]}
# === 本地道友系统：026-08-21 收尾；纯本地，无服务端）===
func 道友列表() -> Array:

	return _道友列表
func 道友消息() -> Array:

	return _道友消息
# 添加道友
func 添加道友(名字: String, 境界: String = "筑基初期", 在线: bool = true) -> Dictionary:

	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			return {"成功": false, "原因": "道友已存在"}
	_道友列表.append({"name": 名字, "status": "%s · %s" % ["在线" if 在线 else "离线", 境界], "sel": false, "好感度": 50, "论道次数": 0, "送礼次数": 0})
	if has_method("save_game"):
		save_game()
	return {"成功": true, "原因": "添加道友成功：%s" % 名字}
# 删除道友
func 删除道友(名字: String) -> Dictionary:

	for i in range(_道友列表.size()):
		if str(_道友列表[i].get("name", "")) == 名字:
			_道友列表.remove_at(i)
			if has_method("save_game"):
				save_game()
			return {"成功": true, "原因": "删除道友成功：%s" % 名字}
	return {"成功": false, "原因": "道友不存在"}
# 发送消：
func 发送道友消息(名字: String, 内容: String) -> Dictionary:

	var 时间 = "%02d-%02d %02d:%02d" % [8, 累计游戏日% 28 + 1, randi() % 24, randi() % 60]
	_道友消息.append({"name": 名字, "text": 内容, "time": 时间, "自己": true})
	if _道友消息.size() > 100:
		_道友消息.remove_at(0)
	if has_method("save_game"):
		save_game()
	return {"成功": true, "原因": "消息已发送"}
# 获取所有道友列表（包含详细信息）
func 获取所有道友列表() -> Array:
	var 道友列表 = []
	for 道友 in _道友列表:
		道友列表.append({
			"name": 道友.get("name", ""),
			"status": 道友.get("status", ""),
			"好感度": 道友.get("好感度", 50),
			"论道次数": 道友.get("论道次数", 0),
			"送礼次数": 道友.get("送礼次数", 0),
		})
	return 道友列表

# 给道友送礼（提升好感度）
func 给道友送礼(名字: String, 礼物价值: int = 100) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	if 灵石 < 礼物价值:
		return {"成功": false, "原因": "灵石不足（需要%d）" % 礼物价值}
	灵石 -= 礼物价值
	# 提升好感度（根据礼物价值）
	var 好感度提升 = int(礼物价值 / 10)
	道友["好感度"] = int(道友.get("好感度", 50)) + 好感度提升
	道友["送礼次数"] = int(道友.get("送礼次数", 0)) + 1
	# 好感度上限100
	if int(道友["好感度"]) > 100:
		道友["好感度"] = 100
	添加纪事("社交", "道友送礼", "给%s送礼，花费%d灵石，好感度+%d" % [名字, 礼物价值, 好感度提升], 1)
	return {"成功": true, "道友": 道友, "好感度提升": 好感度提升, "消息": "给%s送礼成功" % 名字}

# 道友好感度等级配置
const 道友好感度等级配置: Dictionary = {
	1: {"名称": "陌生人", "最低好感度": 0, "效果": "无特殊效果"},
	2: {"名称": "相识", "最低好感度": 20, "效果": "可以发送消息"},
	3: {"名称": "朋友", "最低好感度": 40, "效果": "可以送礼"},
	4: {"名称": "好友", "最低好感度": 60, "效果": "可以拜访"},
	5: {"名称": "挚友", "最低好感度": 80, "效果": "可以切磋"},
	6: {"名称": "生死之交", "最低好感度": 100, "效果": "可以结义"},
}

# 获取道友好感度等级
func 获取道友好感度等级(好感度: int) -> int:
	var 当前等级 = 1
	for 等级 in 道友好感度等级配置.keys():
		var 配置 = 道友好感度等级配置[等级]
		if 好感度 >= int(配置.get("最低好感度", 0)):
			当前等级 = 等级
	return 当前等级

# 结义道友列表
var 结义道友列表: Array = []

# 道友拜访冷却
var 道友拜访冷却: Dictionary = {}  # 道友名字 -> 冷却结束日

# 道友切磋冷却
var 道友切磋冷却: Dictionary = {}  # 道友名字 -> 冷却结束日

# 道友结义
func 道友结义(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	var 好感度 = int(道友.get("好感度", 50))
	if 好感度 < 100:
		return {"成功": false, "原因": "好感度不足（需100，当前%d）" % 好感度}
	if 名字 in 结义道友列表:
		return {"成功": false, "原因": "已经是结义兄弟"}
	# 消耗灵石
	var 消耗灵石 = 10000
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
	灵石 -= 消耗灵石
	结义道友列表.append(名字)
	添加纪事("社交", "道友结义", "与%s结为生死之交，消耗%d灵石" % [名字, 消耗灵石], 1)
	return {"成功": true, "道友": 道友, "消耗灵石": 消耗灵石, "消息": "与%s结义成功" % 名字}

# 道友拜访
func 道友拜访(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	var 好感度 = int(道友.get("好感度", 50))
	if 好感度 < 60:
		return {"成功": false, "原因": "好感度不足（需60，当前%d）" % 好感度}
	# 检查冷却
	if 名字 in 道友拜访冷却:
		var 冷却结束日 = int(道友拜访冷却[名字])
		if 累计游戏日 < 冷却结束日:
			return {"成功": false, "原因": "拜访冷却中（还需%d天）" % (冷却结束日 - 累计游戏日)}
	# 消耗体力
	var 消耗体力 = 10
	if 体力 < 消耗体力:
		return {"成功": false, "原因": "体力不足（需%d体力）" % 消耗体力}
	体力 -= 消耗体力
	# 拜访结果：随机获得奖励
	var 随机值 = randf()
	var 奖励 = {}
	var 消息 = ""
	if 随机值 < 0.3:
		奖励 = {"灵石": 200, "悟道点": 10}
		消息 = "拜访%s，获得灵石200，悟道点10" % 名字
	elif 随机值 < 0.6:
		奖励 = {"灵气": 100, "体力": 5}
		消息 = "拜访%s，获得灵气100，体力5" % 名字
	elif 随机值 < 0.8:
		奖励 = {"好感度": 5}
		道友["好感度"] = min(100, 好感度 + 5)
		消息 = "拜访%s，好感度+5" % 名字
	else:
		消息 = "拜访%s，相谈甚欢" % 名字
	# 设置冷却（1天）
	道友拜访冷却[名字] = 累计游戏日 + 1
	添加纪事("社交", "道友拜访", 消息, 1)
	return {"成功": true, "道友": 道友, "奖励": 奖励, "消息": 消息}

# 道友切磋
func 道友切磋(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	var 好感度 = int(道友.get("好感度", 50))
	if 好感度 < 80:
		return {"成功": false, "原因": "好感度不足（需80，当前%d）" % 好感度}
	# 检查冷却
	if 名字 in 道友切磋冷却:
		var 冷却结束日 = int(道友切磋冷却[名字])
		if 累计游戏日 < 冷却结束日:
			return {"成功": false, "原因": "切磋冷却中（还需%d天）" % (冷却结束日 - 累计游戏日)}
	# 消耗体力
	var 消耗体力 = 20
	if 体力 < 消耗体力:
		return {"成功": false, "原因": "体力不足（需%d体力）" % 消耗体力}
	体力 -= 消耗体力
	# 切磋结果：随机胜负
	var 随机值 = randf()
	var 胜利 = 随机值 < 0.5
	var 奖励 = {}
	var 消息 = ""
	if 胜利:
		奖励 = {"悟道点": 20, "灵石": 100}
		消息 = "与%s切磋，获胜！获得悟道点20，灵石100" % 名字
		道友["好感度"] = min(100, 好感度 + 3)
	else:
		奖励 = {"悟道点": 10}
		消息 = "与%s切磋，惜败。获得悟道点10" % 名字
		道友["好感度"] = min(100, 好感度 + 1)
	# 设置冷却（2天）
	道友切磋冷却[名字] = 累计游戏日 + 2
	添加纪事("社交", "道友切磋", 消息, 1)
	return {"成功": true, "道友": 道友, "胜利": 胜利, "奖励": 奖励, "消息": 消息}

# 获取社交统计
func 获取社交统计() -> Dictionary:
	var 道友总数 = _道友列表.size()
	var 结义数 = 结义道友列表.size()
	var 平均好感度 = 0
	var 总好感度 = 0
	var 最高好感度 = 0
	var 总论道次数 = 0
	var 总送礼次数 = 0
	for 道友 in _道友列表:
		var 好感度 = int(道友.get("好感度", 50))
		总好感度 += 好感度
		最高好感度 = max(最高好感度, 好感度)
		总论道次数 += int(道友.get("论道次数", 0))
		总送礼次数 += int(道友.get("送礼次数", 0))
	if 道友总数 > 0:
		平均好感度 = int(总好感度 / 道友总数)
	return {
		"道友总数": 道友总数,
		"结义数": 结义数,
		"平均好感度": 平均好感度,
		"最高好感度": 最高好感度,
		"总好感度": 总好感度,
		"总论道次数": 总论道次数,
		"总送礼次数": 总送礼次数,
	}

# 一键给所有道友送礼
func 一键给所有道友送礼(礼物价值: int = 100) -> Dictionary:
	var 成功数量 = 0
	var 失败数量 = 0
	var 送礼列表 = []
	for 道友 in _道友列表:
		var 名字 = str(道友.get("name", ""))
		var 结果 = 给道友送礼(名字, 礼物价值)
		送礼列表.append(结果)
		if 结果.get("成功", false):
			成功数量 += 1
		else:
			失败数量 += 1
	return {"成功": 成功数量 > 0, "成功数量": 成功数量, "失败数量": 失败数量, "送礼列表": 送礼列表, "消息": "一键送礼完成，成功%d人，失败%d人" % [成功数量, 失败数量]}

# 与道友论道（获得悟道点）
func 与道友论道(名字: String) -> Dictionary:

	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	var 好感度 = int(道友.get("好感度", 50))
	if 好感度 < 30:
		return {"成功": false, "原因": "好感度不足，道友不愿论道"}
	var 论道次数 = int(道友.get("论道次数", 0))
	if 论道次数 >= 3:
		return {"成功": false, "原因": "今日论道次数已用完（每日3次）"}
	var 悟道点获得 = 5 + randi() % 10 + int(好感度 / 10)
	悟道点 += 悟道点获得
	道友["论道次数"] = 论道次数 + 1
	道友["好感度"] = min(100, 好感度 + 2)
	if has_method("save_game"):
		save_game()
	return {"成功": true, "原因": "%s论道成功，获得悟道点%d，好感度+2" % [名字, 悟道点获得]}
# 拜访道友（获得灵石、灵气，提升好感度）
func 拜访道友(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	# 检查冷却
	var 冷却日: int = int(道友拜访冷却.get(名字, 0))
	if 累计游戏日 < 冷却日:
		return {"成功": false, "原因": "拜访冷却中（还需%d天）" % (冷却日 - 累计游戏日)}
	道友拜访冷却[名字] = 累计游戏日 + 1
	# 拜访奖励
	var 好感度: int = int(道友.get("好感度", 50))
	var 灵石奖励: int = 50 + randi() % 100 + int(好感度 / 2)
	var 灵气奖励: int = 20 + randi() % 50 + int(好感度 / 5)
	灵石 += 灵石奖励
	灵气 += 灵气奖励
	道友["好感度"] = min(100, 好感度 + 3)
	# 随机事件
	var 事件文本: String = ""
	var 随机值: float = randf()
	if 随机值 < 0.1:
		# 10%概率道友赠送额外礼物
		var 额外灵石: int = randi_range(100, 300)
		灵石 += 额外灵石
		事件文本 = "，道友心情大好，额外赠送%d灵石" % 额外灵石
	elif 随机值 < 0.2:
		# 10%概率获得悟道点
		悟道点 += 5
		事件文本 = "，与道友畅谈，悟道点+5"
	添加纪事("庶务", "拜访道友", "拜访道友%s，获得%d灵石、%d灵气，好感度+3%s" % [名字, 灵石奖励, 灵气奖励, 事件文本], 1)
	if has_method("save_game"):
		save_game()
	return {"成功": true, "灵石": 灵石奖励, "灵气": 灵气奖励, "事件": 事件文本}

# 与道友切磋（获得修炼经验，可能受伤）
func 与道友切磋(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	# 检查冷却
	var 冷却日: int = int(道友切磋冷却.get(名字, 0))
	if 累计游戏日 < 冷却日:
		return {"成功": false, "原因": "切磋冷却中（还需%d天）" % (冷却日 - 累计游戏日)}
	# 检查体力
	if 体力 < 15:
		return {"成功": false, "原因": "体力不足（需15点）"}
	体力 -= 15
	道友切磋冷却[名字] = 累计游戏日 + 2
	# 切磋结果
	var 好感度: int = int(道友.get("好感度", 50))
	var 胜利概率: float = 0.4 + float(好感度) / 200.0  # 40%-90%
	var 胜利: bool = randf() < 胜利概率
	if 胜利:
		var 修炼经验: int = 50 + randi() % 100
		修炼进度 += float(修炼经验) / 1000.0
		道友["好感度"] = min(100, 好感度 + 5)
		添加纪事("庶务", "道友切磋", "与道友%s切磋胜利，修炼经验+%d，好感度+5" % [名字, 修炼经验], 1)
		if has_method("save_game"):
			save_game()
		return {"成功": true, "胜利": true, "修炼经验": 修炼经验}
	else:
		# 失败可能受伤
		var 受伤: bool = randf() < 0.3
		if 受伤:
			体力 = max(0, 体力 - 10)
			添加纪事("庶务", "道友切磋", "与道友%s切磋失败，受伤了，体力-10" % 名字, 1)
		else:
			道友["好感度"] = min(100, 好感度 + 2)
			添加纪事("庶务", "道友切磋", "与道友%s切磋失败，但有所收获，好感度+2" % 名字, 1)
		if has_method("save_game"):
			save_game()
		return {"成功": true, "胜利": false, "受伤": 受伤}

# 与道友结义（好感度100时可结义，获得永久加成）
func 与道友结义(名字: String) -> Dictionary:
	var 道友 = null
	for d in _道友列表:
		if str(d.get("name") if "name" in d else "") == 名字:
			道友 = d
			break
	if 道友 == null:
		return {"成功": false, "原因": "道友不存在"}
	# 检查好感度
	var 好感度: int = int(道友.get("好感度", 50))
	if 好感度 < 100:
		return {"成功": false, "原因": "好感度不足（需100，当前%d）" % 好感度}
	# 检查是否已结义
	if 名字 in 结义道友列表:
		return {"成功": false, "原因": "已与此道友结义"}
	# 结义消耗
	if 灵石 < 1000:
		return {"成功": false, "原因": "灵石不足（需1000灵石用于结义仪式）"}
	灵石 -= 1000
	# 结义成功
	结义道友列表.append(名字)
	# 永久加成：所有结义道友提供修炼速度+1%（最多5%）
	var 结义加成: float = min(0.05, float(结义道友列表.size()) * 0.01)
	添加纪事("庶务", "道友结义", "与道友%s结义为兄弟，修炼速度+%.0f%%（当前总加成%.0f%%）" % [名字, 结义加成 * 100, 结义加成 * 100], 1)
	if has_method("save_game"):
		save_game()
	return {"成功": true, "结义加成": 结义加成, "结义人数": 结义道友列表.size()}

# 获取结义加成
func 获取结义加成() -> float:
	return min(0.05, float(结义道友列表.size()) * 0.01)

# 重置每日道友互动次数
func 重置道友每日次数() -> void:

	for d in _道友列表:
		d["论道次数"] = 0
		d["送礼次数"] = 0
# === 库藏整理（仅经济/收藏顺序，零战斗触碰：==
# ：品阶倒序（高→低： 类别字典：排序，save_game 持久化：
const _整理品阶表: Array= ["道阶", "仙阶", "圣阶", "王阶", "宝阶", "灵阶", "凡阶"]
func 整理库房() -> Array:

	var 排序: Array = []
	for it in 宗门库房:
		排序.append(it)
	排序.sort_custom(_整理比较)
	宗门库房 = 排序
	if has_method("save_game"):
		save_game()
	return 排序
func _整理比较(a: Variant, b: Variant) -> bool:

	var 阶A: String = "凡阶"
	var 阶B: String = "凡阶"
	if a is Object:
		var va = a.get("品阶")
		if va != null:
			阶A = str(va)
	if b is Object:
		var vb = b.get("品阶")
		if vb != null:
			阶B = str(vb)
	var ia: int = _整理品阶表.find(阶A)
	var ib: int = _整理品阶表.find(阶B)
	if ia < 0: ia = _整理品阶表.size()
	if ib < 0: ib = _整理品阶表.size()
	if ia != ib:
		return ia < ib
	var 类别A: String = ""
	var 类别B: String = ""
	if a is Object:
		var ca = a.get("类别")
		if ca != null:
			类别A = str(ca)
	if b is Object:
		var cb = b.get("类别")
		if cb != null:
			类别B = str(cb)
	return 类别A < 类别B
# === 库藏出售（经济写入，非战：装备平衡：==
# 从宗门库房移：Item 实例，按品阶折算灵石；仅允许 材料/丹药 类：
# 装备/功法/灵兽 由装备系统处理（S1 红线门控，本函数返回 0）：
func 出售库房物品(it: Variant) -> int:

	if it == null:
		return 0
	var 类别: String = ""
	var 特殊类: bool = false
	var 名含碎片: bool = false
	if it is Object:
		类别 = str(it.get("类别") if "类别" in it else "")
		特殊类 = it.get("特殊") if "特殊" in it else false
		if "碎片" in str(it.get("名称") if "名称" in it else ""):
			名含碎片 = true
	# 双轨制品类边界：库藏全价渠道仅收 基础灵材(草药/矿石)/基础丹药：
	# 特殊道具（命格碎片等 flagged 特殊）与所有「名称含碎片」的衍生材料（装备碎片等：
	# 不开放全价，须走坊市回收（：0%）—：双保险卡口，即使碎片被误归类也强制走坊市
	if 类别 in ["灵材", "丹药"] and not 特殊类 and not 名含碎片:
		var idx: int = 宗门库房.find(it)
		if idx >= 0:
			宗门库房.remove_at(idx)
		var 价: int = _品阶售价(it)
		灵石 += 价
		if has_method("save_game"):
			save_game()
		return 价
	return 0
func _品阶售价(it: Variant) -> int:

	var 表: Dictionary = {"凡阶": 10, "灵阶": 30, "宝阶": 80, "王阶": 200, "圣阶": 500, "仙阶": 1200, "道阶": 3000}
	var 阶: String = "凡阶"
	if it is Object:
		var v = it.get("品阶")
		if v != null:
			阶 = str(v)
	return int(表.get(阶, 10))
# === 灵讯（邮件）系统：读：/ 已读 / 领取后端 ===
# 邮件数据结构（Dictionary）：发件人/ 标题 / 内容 / 时间 / 附件(Dict 资源： / 未读 / 已领
# MVP 仅支持资源类附件（灵：灵气/灵草/矿石/声望/绑定仙玉/皮肤），装备类附件后续迭代：
func 取邮件列表() -> Array:

	return 邮件列表
func 标记邮件已读(idx: int) -> void:

	if idx >= 0 and idx < 邮件列表.size():
		邮件列表[idx]["未读"] = false
		邮件变动.emit()
		if has_method("save_game"):
			save_game()
func 邮件全部已读() -> void:

	for m in 邮件列表:
		m["未读"] = false
	邮件变动.emit()
	if has_method("save_game"):
		save_game()
# 领取指定邮件附件：真发放资源并标记已领（照搬 领战令奖：资源发放范式：
func 领取邮件(idx: int) -> Dictionary:

	if idx < 0 or idx >= 邮件列表.size():
		return {"ok": false, "msg": "邮件不存在"}
	var m: Dictionary = 邮件列表[idx]
	if m.get("已领") if "已领" in m else false:
		return {"ok": false, "msg": "该邮件已领取"}
	var 附件: Dictionary = m.get("附件") if "附件" in m else {}
	if 附件.is_empty():
		return {"ok": false, "msg": "该邮件无附件"}
	var 明细: Array = []
	if 附件.has("灵石"):
		var v: int = int(附件["灵石"]); 灵石 += v; 明细.append("灵石+%d" % v)
	if 附件.has("灵气"):
		var v: int = int(附件["灵气"]); 灵气 += v; 明细.append("灵气+%d" % v)
	if 附件.has("灵草"):
		var v: int = int(附件["灵草"]); 灵草 += v; 明细.append("灵草+%d" % v)
	if 附件.has("矿石"):
		var v: int = int(附件["矿石"]); 矿石 += v; 明细.append("矿石+%d" % v)
	if 附件.has("声望"):
		var v: int = int(附件["声望"]); 声望 += v; 明细.append("声望+%d" % v)
	if 附件.has("绑定仙玉"):
		var v: int = int(附件["绑定仙玉"]); 仙玉_绑定 += v; 明细.append("绑定仙玉+%d" % v)
	if 附件.has("皮肤"):
		var skin_id: String = str(附件["皮肤"]); 当前皮肤 = skin_id; 明细.append("外观·%s" % skin_id)
	m["已领"] = true
	m["未读"] = false
	邮件变动.emit()
	if has_method("save_game"):
		save_game()
	return {"ok": true, "msg": "%s 附件：%s" % [str(m.get("标题") if "标题" in m else ""), "·".join(明细)], "明细": 明细}
# 种子化初始邮件（读档后/ 新档各调用一次；已有邮件则不重复种子：
func _种子化初始邮() -> void:

	if not 邮件列表.is_empty():
		return
	邮件列表 = [
		{"发件人": "宗门长老", "标题": "宗门大比公告", "内容": 文案表["mail_sect_contest"], "时间": "08-09 09:24", "附件": {"灵石": 200}, "未读": true, "已领": false},
		{"发件人": "游方道人", "标题": "论道邀约", "内容": 文案表["mail_daoist_invite"], "时间": "08-08 21:10", "附件": {}, "未读": true, "已领": false},
		{"发件人": "丹器师公会", "标题": "材料淬炼返还", "内容": 文案表["mail_forge_return"], "时间": "08-08 18:02", "附件": {"灵草": 30}, "未读": false, "已领": false},
		{"发件人": "系统", "标题": "每日补给已发放", "内容": 文案表["mail_daily_supply"], "时间": "08-08 00:05", "附件": {"绑定仙玉": 20}, "未读": false, "已领": false},
	]

# ============ 炼丹系统：封装方法 ============
# 执行炼丹（封装AlchemySystem.炼丹，自动更新仓库和统计）
func 执行炼丹(丹方ID: String, 丹堂等级: int = 1) -> Dictionary:
	var 背包: Array = 仓库.duplicate()
	var 结果: Dictionary = AlchemySystem.炼丹(丹方ID, 背包, 丹堂等级)
	仓库 = 背包
	# 更新成就统计：累计炼制丹药数
	if 结果.get("成功", false):
		var 旧炼丹数: int = 累计炼制丹药数
		累计炼制丹药数 += 1
		_复检成就()  # 成就检测：炼丹数量相关成就
		# 事件型里程碑触发：首次炼制丹药
		if 旧炼丹数 == 0:
			_传承事件("首次炼制丹药")
		# 阵营任务进度更新：魔道邪宗"血祭修炼"任务（炼丹可视为修炼的一种）
		更新阵营任务进度("魔道邪宗", "daily", 1)
	return 结果

# ============ 炼器系统：经验值管理 ============
# 获取炼器等级
func 获取炼器等级() -> int:
	return ForgeSystem.获取炼器等级(炼器经验值)

# 获取炼器加成
func 获取炼器加成() -> Dictionary:
	return ForgeSystem.获取炼器加成(炼器经验值)

# 增加炼器经验
func 增加炼器经验(数量: int) -> void:
	if 数量 <= 0:
		return
	var 旧等级: int = 获取炼器等级()
	炼器经验值 += 数量
	var 新等级: int = 获取炼器等级()
	if 新等级 > 旧等级:
		print("[炼器] 炼器等级提升：%d → %d" % [旧等级, 新等级])

# 执行炼器（封装ForgeSystem.炼器，自动传递炼器经验值并更新）
func 执行炼器(配方ID: String, 器堂等级: int = 1, 炼器弟子 = null) -> Dictionary:
	var 背包: Array = 仓库.duplicate()
	var 结果: Dictionary = ForgeSystem.炼器(配方ID, 背包, 器堂等级, 炼器弟子, 炼器经验值)
	仓库 = 背包
	# 更新炼器经验
	var 获得经验: int = int(结果.get("获得经验", 0))
	if 获得经验 > 0:
		增加炼器经验(获得经验)
	# 更新成就统计：累计锻造装备数
	if 结果.get("成功", false):
		var 旧锻造数: int = 累计锻造装备数
		累计锻造装备数 += 1
		_复检成就()  # 成就检测：炼器数量相关成就
		# 事件型里程碑触发：首次锻造装备
		if 旧锻造数 == 0:
			_传承事件("首次锻造装备")
		# 阵营任务进度更新：正道宗门"除魔卫道"任务（炼器可视为除魔准备）
		更新阵营任务进度("正道宗门", "daily", 1)
	return 结果

# 宗门科技树配置
const 宗门科技树配置: Dictionary = {
	"修炼加速I": {"描述": "所有弟子修炼速度+5%", "效果": {"修炼速度加成": 0.05}, "消耗灵石": 10000, "消耗悟道点": 1000, "前置科技": [], "等级": 1},
	"修炼加速II": {"描述": "所有弟子修炼速度+10%", "效果": {"修炼速度加成": 0.1}, "消耗灵石": 30000, "消耗悟道点": 3000, "前置科技": ["修炼加速I"], "等级": 2},
	"修炼加速III": {"描述": "所有弟子修炼速度+15%", "效果": {"修炼速度加成": 0.15}, "消耗灵石": 80000, "消耗悟道点": 8000, "前置科技": ["修炼加速II"], "等级": 3},
	"战力强化I": {"描述": "所有弟子战力+10%", "效果": {"战力加成": 0.1}, "消耗灵石": 10000, "消耗悟道点": 1000, "前置科技": [], "等级": 1},
	"战力强化II": {"描述": "所有弟子战力+20%", "效果": {"战力加成": 0.2}, "消耗灵石": 30000, "消耗悟道点": 3000, "前置科技": ["战力强化I"], "等级": 2},
	"战力强化III": {"描述": "所有弟子战力+30%", "效果": {"战力加成": 0.3}, "消耗灵石": 80000, "消耗悟道点": 8000, "前置科技": ["战力强化II"], "等级": 3},
	"资源增产I": {"描述": "所有资源产出+10%", "效果": {"产出加成": 0.1}, "消耗灵石": 10000, "消耗悟道点": 1000, "前置科技": [], "等级": 1},
	"资源增产II": {"描述": "所有资源产出+20%", "效果": {"产出加成": 0.2}, "消耗灵石": 30000, "消耗悟道点": 3000, "前置科技": ["资源增产I"], "等级": 2},
	"资源增产III": {"描述": "所有资源产出+30%", "效果": {"产出加成": 0.3}, "消耗灵石": 80000, "消耗悟道点": 8000, "前置科技": ["资源增产II"], "等级": 3},
	"阵法强化I": {"描述": "所有阵法效果+10%", "效果": {"阵法加成": 0.1}, "消耗灵石": 15000, "消耗悟道点": 1500, "前置科技": [], "等级": 1},
	"阵法强化II": {"描述": "所有阵法效果+20%", "效果": {"阵法加成": 0.2}, "消耗灵石": 45000, "消耗悟道点": 4500, "前置科技": ["阵法强化I"], "等级": 2},
	"丹药强化I": {"描述": "所有丹药效果+10%", "效果": {"丹药加成": 0.1}, "消耗灵石": 15000, "消耗悟道点": 1500, "前置科技": [], "等级": 1},
	"丹药强化II": {"描述": "所有丹药效果+20%", "效果": {"丹药加成": 0.2}, "消耗灵石": 45000, "消耗悟道点": 4500, "前置科技": ["丹药强化I"], "等级": 2},
}

# 已研究的宗门科技
var 已研究宗门科技: Array = []

# 研究宗门科技
func 研究宗门科技(科技名称: String) -> Dictionary:
	if 科技名称 not in 宗门科技树配置:
		return {"成功": false, "原因": "科技不存在"}
	if 科技名称 in 已研究宗门科技:
		return {"成功": false, "原因": "该科技已研究"}
	var 配置 = 宗门科技树配置[科技名称]
	# 检查前置科技
	var 前置科技 = 配置.get("前置科技", [])
	for 前置 in 前置科技:
		if 前置 not in 已研究宗门科技:
			return {"成功": false, "原因": "需要先研究前置科技：%s" % 前置}
	var 消耗灵石 = int(配置.get("消耗灵石", 0))
	var 消耗悟道点 = int(配置.get("消耗悟道点", 0))
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
	if 悟道点 < 消耗悟道点:
		return {"成功": false, "原因": "悟道点不足（需%d悟道点）" % 消耗悟道点}
	灵石 -= 消耗灵石
	悟道点 -= 消耗悟道点
	已研究宗门科技.append(科技名称)
	添加纪事("庶务", "研究科技", "研究宗门科技：%s" % 科技名称, 1)
	return {"成功": true, "科技名称": 科技名称, "配置": 配置, "消耗灵石": 消耗灵石, "消耗悟道点": 消耗悟道点, "消息": "研究%s成功" % 科技名称}

# 获取所有宗门科技列表
func 获取所有宗门科技列表() -> Array:
	var 列表 = []
	for 科技名称 in 宗门科技树配置.keys():
		var 配置 = 宗门科技树配置[科技名称]
		var 前置科技 = 配置.get("前置科技", [])
		var 前置已研究 = true
		for 前置 in 前置科技:
			if 前置 not in 已研究宗门科技:
				前置已研究 = false
				break
		列表.append({
			"科技名称": 科技名称,
			"描述": 配置.get("描述", ""),
			"效果": 配置.get("效果", {}),
			"消耗灵石": int(配置.get("消耗灵石", 0)),
			"消耗悟道点": int(配置.get("消耗悟道点", 0)),
			"前置科技": 前置科技,
			"等级": int(配置.get("等级", 1)),
			"已研究": 科技名称 in 已研究宗门科技,
			"可研究": 前置已研究 and 科技名称 not in 已研究宗门科技,
		})
	return 列表

# 计算宗门科技总效果
func 计算宗门科技总效果() -> Dictionary:
	var 总效果 = {
		"修炼速度加成": 0.0,
		"战力加成": 0.0,
		"产出加成": 0.0,
		"阵法加成": 0.0,
		"丹药加成": 0.0,
	}
	for 科技名称 in 已研究宗门科技:
		if 科技名称 in 宗门科技树配置:
			var 配置 = 宗门科技树配置[科技名称]
			var 效果 = 配置.get("效果", {})
			总效果["修炼速度加成"] += float(效果.get("修炼速度加成", 0))
			总效果["战力加成"] += float(效果.get("战力加成", 0))
			总效果["产出加成"] += float(效果.get("产出加成", 0))
			总效果["阵法加成"] += float(效果.get("阵法加成", 0))
			总效果["丹药加成"] += float(效果.get("丹药加成", 0))
	return 总效果

# ============ 功法系统：封装方法 ============
# 学习功法（自动消耗悟道点）
func 学习功法(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 结果: Dictionary = GongFaSystem.学习功法(弟子, 功法ID, 悟道点)
	if 结果.get("成功", false):
		var 消耗: int = int(结果.get("消耗", 0))
		悟道点 -= 消耗
		# 事件型里程碑触发：首次学习功法
		_复检成就()  # 成就检测：功法收集相关成就
		var 已学功法总数: int = 0
		for d in 弟子列表:
			if d != null:
				var 弟子功法 = d.get("已学功法") if "已学功法" in d else []
				if 弟子功法 != null:
					已学功法总数 += 弟子功法.size()
		if 已学功法总数 == 1:
			_传承事件("首次学习功法")
		# 阵营任务进度更新：正道宗门"讲经论道"任务（学习功法可视为讲经的一种）
		更新阵营任务进度("正道宗门", "weekly", 1)
	return 结果

# 遗忘功法（返还悟道点）
func 遗忘功法(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 结果: Dictionary = GongFaSystem.遗忘功法(弟子, 功法ID)
	if 结果.get("成功", false):
		var 返还: int = int(结果.get("返还", 0))
		悟道点 += 返还
	return 结果

# 功法熟练度统计
var 功法熟练度: Dictionary = {}  # 功法ID -> 熟练度

# 功法升级配置
const 功法升级配置: Dictionary = {
	1: {"成功率": 0.9, "消耗悟道点": 100, "效果提升": 0.1},
	2: {"成功率": 0.8, "消耗悟道点": 300, "效果提升": 0.15},
	3: {"成功率": 0.7, "消耗悟道点": 800, "效果提升": 0.2},
	4: {"成功率": 0.6, "消耗悟道点": 2000, "效果提升": 0.25},
	5: {"成功率": 0.5, "消耗悟道点": 5000, "效果提升": 0.3},
	6: {"成功率": 0.4, "消耗悟道点": 12000, "效果提升": 0.35},
	7: {"成功率": 0.3, "消耗悟道点": 30000, "效果提升": 0.4},
	8: {"成功率": 0.2, "消耗悟道点": 80000, "效果提升": 0.45},
	9: {"成功率": 0.1, "消耗悟道点": 200000, "效果提升": 0.5},
	10: {"成功率": 0.05, "消耗悟道点": 500000, "效果提升": 0.6},
}

# 升级功法
func 升级功法(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	# 检查弟子是否已学习该功法
	var 已学功法 = 弟子.get("已学功法", [])
	var 已学习 = false
	var 功法等级 = 1
	for 功法 in 已学功法:
		if 功法.get("功法ID", "") == 功法ID:
			已学习 = true
			功法等级 = int(功法.get("等级", 1))
			break
	if not 已学习:
		return {"成功": false, "原因": "弟子未学习该功法"}
	if 功法等级 >= 10:
		return {"成功": false, "原因": "功法已达最高等级"}
	var 配置 = 功法升级配置.get(功法等级 + 1, {})
	var 消耗悟道点 = int(配置.get("消耗悟道点", 0))
	var 成功率 = float(配置.get("成功率", 0))
	if 悟道点 < 消耗悟道点:
		return {"成功": false, "原因": "悟道点不足（需%d悟道点）" % 消耗悟道点}
	悟道点 -= 消耗悟道点
	var 随机值 = randf()
	if 随机值 < 成功率:
		# 更新功法等级
		for 功法 in 已学功法:
			if 功法.get("功法ID", "") == 功法ID:
				功法["等级"] = 功法等级 + 1
				break
		添加纪事("庶务", "升级功法", "%s的%s升级到%d级" % [弟子.姓名, 功法ID, 功法等级 + 1], 1)
		return {"成功": true, "弟子": 弟子, "功法ID": 功法ID, "新等级": 功法等级 + 1, "消耗悟道点": 消耗悟道点, "消息": "%s升级成功" % 功法ID}
	else:
		添加纪事("庶务", "升级功法", "%s的%s升级失败" % [弟子.姓名, 功法ID], 1)
		return {"成功": false, "原因": "升级失败", "消耗悟道点": 消耗悟道点, "消息": "%s升级失败" % 功法ID}

# 获取功法升级消耗
func 获取功法升级消耗(弟子, 功法ID: String) -> Dictionary:
	if 弟子 == null:
		return {}
	var 已学功法 = 弟子.get("已学功法", [])
	var 功法等级 = 1
	var 已学习 = false
	for 功法 in 已学功法:
		if 功法.get("功法ID", "") == 功法ID:
			已学习 = true
			功法等级 = int(功法.get("等级", 1))
			break
	if not 已学习:
		return {"已学习": false, "原因": "弟子未学习该功法"}
	if 功法等级 >= 10:
		return {"已学习": true, "当前等级": 功法等级, "最大等级": 10, "是否可升级": false, "原因": "功法已达最高等级"}
	var 配置 = 功法升级配置.get(功法等级 + 1, {})
	return {
		"已学习": true,
		"当前等级": 功法等级,
		"下一级等级": 功法等级 + 1,
		"最大等级": 10,
		"成功率": float(配置.get("成功率", 0)),
		"消耗悟道点": int(配置.get("消耗悟道点", 0)),
		"效果提升": float(配置.get("效果提升", 0)),
		"是否可升级": true,
	}

# 增加功法熟练度
func 增加功法熟练度(功法ID: String, 熟练度: int = 1) -> void:
	if 功法ID in 功法熟练度:
		功法熟练度[功法ID] += 熟练度
	else:
		功法熟练度[功法ID] = 熟练度

# 获取功法熟练度
func 获取功法熟练度(功法ID: String) -> int:
	return int(功法熟练度.get(功法ID, 0))

# 获取功法熟练度排行榜
func 获取功法熟练度排行榜(限制数量: int = 10) -> Array:
	var 排行榜 = []
	for 功法ID in 功法熟练度.keys():
		排行榜.append({
			"功法ID": 功法ID,
			"熟练度": 功法熟练度[功法ID],
		})
	排行榜.sort_custom(func(a, b): return a["熟练度"] > b["熟练度"])
	return 排行榜.slice(0, min(限制数量, 排行榜.size()))

# 弟子突破配置
const 弟子突破配置: Dictionary = {
	"炼气期": {"下一期": "筑基期", "成功率": 0.8, "消耗灵石": 1000, "消耗悟道点": 100, "属性提升": {"修炼速度": 0.05, "战力": 20, "心境": 5}},
	"筑基期": {"下一期": "金丹期", "成功率": 0.7, "消耗灵石": 3000, "消耗悟道点": 300, "属性提升": {"修炼速度": 0.08, "战力": 50, "心境": 10}},
	"金丹期": {"下一期": "元婴期", "成功率": 0.6, "消耗灵石": 8000, "消耗悟道点": 800, "属性提升": {"修炼速度": 0.12, "战力": 100, "心境": 15}},
	"元婴期": {"下一期": "化神期", "成功率": 0.5, "消耗灵石": 20000, "消耗悟道点": 2000, "属性提升": {"修炼速度": 0.18, "战力": 200, "心境": 25}},
	"化神期": {"下一期": "炼虚期", "成功率": 0.4, "消耗灵石": 50000, "消耗悟道点": 5000, "属性提升": {"修炼速度": 0.25, "战力": 350, "心境": 35}},
	"炼虚期": {"下一期": "合体期", "成功率": 0.3, "消耗灵石": 120000, "消耗悟道点": 12000, "属性提升": {"修炼速度": 0.35, "战力": 550, "心境": 50}},
	"合体期": {"下一期": "大乘期", "成功率": 0.2, "消耗灵石": 300000, "消耗悟道点": 30000, "属性提升": {"修炼速度": 0.5, "战力": 800, "心境": 70}},
	"大乘期": {"下一期": "渡劫期", "成功率": 0.1, "消耗灵石": 800000, "消耗悟道点": 80000, "属性提升": {"修炼速度": 0.7, "战力": 1200, "心境": 100}},
}

# 弟子突破
func 弟子突破(弟子ID: int) -> Dictionary:
	# 查找弟子
	var 目标弟子 = null
	for 弟子 in 弟子列表:
		if 弟子 != null and 弟子.弟子ID == 弟子ID:
			目标弟子 = 弟子
			break
	if 目标弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 当前境界 = str(目标弟子.境界)
	if 当前境界 not in 弟子突破配置:
		return {"成功": false, "原因": "该境界无法突破或已达最高境界"}
	var 配置 = 弟子突破配置[当前境界]
	var 消耗灵石 = int(配置.get("消耗灵石", 0))
	var 消耗悟道点 = int(配置.get("消耗悟道点", 0))
	var 成功率 = clamp(float(配置.get("成功率", 0)) + 获取气运突破加成(), 0.05, 0.98)	# P3 气运：突破成功率随气运±15%
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
	if 悟道点 < 消耗悟道点:
		return {"成功": false, "原因": "悟道点不足（需%d悟道点）" % 消耗悟道点}
	灵石 -= 消耗灵石
	悟道点 -= 消耗悟道点
	var 随机值 = randf()
	if 随机值 < 成功率:
		var 新境界 = str(配置.get("下一期", ""))
		目标弟子.境界 = 新境界
		# 提升属性
		var 属性提升 = 配置.get("属性提升", {})
		目标弟子.修炼速度 = float(目标弟子.修炼速度) + float(属性提升.get("修炼速度", 0))
		目标弟子.战力 = int(目标弟子.战力) + int(属性提升.get("战力", 0))
		目标弟子.心境 = int(目标弟子.心境) + int(属性提升.get("心境", 0))
		# 成就统计：累计弟子突破次数自增
		累计弟子突破次数 += 1
		_复检成就()
		添加纪事("庶务", "弟子突破", "%s突破到%s" % [目标弟子.姓名, 新境界], 1)
		return {"成功": true, "弟子": 目标弟子, "新境界": 新境界, "消耗灵石": 消耗灵石, "消耗悟道点": 消耗悟道点, "消息": "%s突破成功" % 目标弟子.姓名}
	else:
		添加纪事("庶务", "弟子突破", "%s突破失败" % 目标弟子.姓名, 1)
		return {"成功": false, "原因": "突破失败", "消耗灵石": 消耗灵石, "消耗悟道点": 消耗悟道点, "消息": "%s突破失败" % 目标弟子.姓名}

# 获取弟子突破消耗
func 获取弟子突破消耗(弟子ID: int) -> Dictionary:
	var 目标弟子 = null
	for 弟子 in 弟子列表:
		if 弟子 != null and 弟子.弟子ID == 弟子ID:
			目标弟子 = 弟子
			break
	if 目标弟子 == null:
		return {}
	var 当前境界 = str(目标弟子.境界)
	if 当前境界 not in 弟子突破配置:
		return {"当前境界": 当前境界, "是否可突破": false, "原因": "该境界无法突破或已达最高境界"}
	var 配置 = 弟子突破配置[当前境界]
	return {
		"当前境界": 当前境界,
		"下一期": 配置.get("下一期", ""),
		"成功率": float(配置.get("成功率", 0)),
		"消耗灵石": int(配置.get("消耗灵石", 0)),
		"消耗悟道点": int(配置.get("消耗悟道点", 0)),
		"属性提升": 配置.get("属性提升", {}),
		"是否可突破": true,
	}

# 弟子传承（将一名弟子的经验传承给另一名弟子）
func 弟子传承(传承者ID: int, 接受者ID: int) -> Dictionary:
	# 查找弟子
	var 传承者 = null
	var 接受者 = null
	for 弟子 in 弟子列表:
		if 弟子 != null:
			if 弟子.弟子ID == 传承者ID:
				传承者 = 弟子
			if 弟子.弟子ID == 接受者ID:
				接受者 = 弟子
	if 传承者 == null:
		return {"成功": false, "原因": "传承者不存在"}
	if 接受者 == null:
		return {"成功": false, "原因": "接受者不存在"}
	if 传承者ID == 接受者ID:
		return {"成功": false, "原因": "传承者和接受者不能是同一人"}
	# 消耗灵石
	var 消耗灵石 = 5000
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
	灵石 -= 消耗灵石
	# 传承效果：接受者获得传承者50%的修炼速度和战力加成
	var 传承修炼速度 = float(传承者.修炼速度) * 0.5
	var 传承战力 = int(传承者.战力) * 0.5
	var 传承心境 = int(传承者.心境) * 0.5
	接受者.修炼速度 = float(接受者.修炼速度) + 传承修炼速度
	接受者.战力 = int(接受者.战力) + int(传承战力)
	接受者.心境 = int(接受者.心境) + int(传承心境)
	# 传承者境界降低一级（简化处理）
	添加纪事("庶务", "弟子传承", "%s将修为传承给%s，接受者获得修炼速度+%.2f，战力+%d，心境+%d" % [传承者.姓名, 接受者.姓名, 传承修炼速度, int(传承战力), int(传承心境)], 1)
	return {"成功": true, "传承者": 传承者, "接受者": 接受者, "传承修炼速度": 传承修炼速度, "传承战力": int(传承战力), "传承心境": int(传承心境), "消耗灵石": 消耗灵石, "消息": "传承成功"}

# 弟子培养（消耗资源提升弟子属性）
func 培养弟子(弟子ID: int, 培养类型: String = "全面") -> Dictionary:
	# 查找弟子
	var 目标弟子 = null
	for 弟子 in 弟子列表:
		if 弟子 != null and 弟子.弟子ID == 弟子ID:
			目标弟子 = 弟子
			break
	if 目标弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	# 根据培养类型计算消耗和效果
	var 消耗灵石 = 100
	var 消耗悟道点 = 10
	var 属性提升 = {}
	if 培养类型 == "全面":
		消耗灵石 = 200
		消耗悟道点 = 20
		属性提升 = {"修炼速度": 0.01, "战力": 5, "心境": 1}
	elif 培养类型 == "修炼":
		消耗灵石 = 100
		消耗悟道点 = 15
		属性提升 = {"修炼速度": 0.02}
	elif 培养类型 == "战斗":
		消耗灵石 = 150
		消耗悟道点 = 10
		属性提升 = {"战力": 10}
	elif 培养类型 == "心境":
		消耗灵石 = 80
		消耗悟道点 = 25
		属性提升 = {"心境": 3}
	else:
		消耗灵石 = 100
		消耗悟道点 = 10
		属性提升 = {"修炼速度": 0.01, "战力": 5}
	# 检查资源
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需要%d）" % 消耗灵石}
	if 悟道点 < 消耗悟道点:
		return {"成功": false, "原因": "悟道点不足（需要%d）" % 消耗悟道点}
	# 消耗资源
	灵石 -= 消耗灵石
	悟道点 -= 消耗悟道点
	# 提升属性（简化版本，实际应该修改弟子属性）
	目标弟子.修炼速度 = float(目标弟子.修炼速度) + 属性提升.get("修炼速度", 0.0)
	目标弟子.战力 = int(目标弟子.战力) + 属性提升.get("战力", 0)
	目标弟子.心境 = int(目标弟子.心境) + 属性提升.get("心境", 0)
	# 成就统计：累计培养弟子数自增
	累计培养弟子数 += 1
	_复检成就()
	添加纪事("庶务", "弟子培养", "培养了%s（%s），消耗%d灵石%d悟道点" % [目标弟子.姓名, 培养类型, 消耗灵石, 消耗悟道点], 1)
	return {"成功": true, "弟子": 目标弟子, "属性提升": 属性提升, "消耗": {"灵石": 消耗灵石, "悟道点": 消耗悟道点}, "消息": "培养%s成功" % 目标弟子.姓名}

# 获取可培养弟子列表
func 获取可培养弟子列表() -> Array:
	var 可培养列表 = []
	for 弟子 in 弟子列表:
		if 弟子 != null:
			可培养列表.append({
				"弟子ID": 弟子.弟子ID,
				"姓名": 弟子.姓名,
				"境界": 弟子.境界,
				"修炼速度": 弟子.修炼速度,
				"战力": 弟子.战力,
				"心境": 弟子.心境,
			})
	return 可培养列表

# 批量培养弟子
func 批量培养弟子(弟子ID列表: Array, 培养类型: String = "全面") -> Dictionary:
	var 成功数量 = 0
	var 失败数量 = 0
	var 培养列表 = []
	for 弟子ID in 弟子ID列表:
		var 结果 = 培养弟子(弟子ID, 培养类型)
		培养列表.append(结果)
		if 结果.get("成功", false):
			成功数量 += 1
		else:
			失败数量 += 1
	return {"成功": 成功数量 > 0, "成功数量": 成功数量, "失败数量": 失败数量, "培养列表": 培养列表, "消息": "批量培养完成，成功%d人，失败%d人" % [成功数量, 失败数量]}

# 增加弟子功法熟练度
func 增加弟子功法熟练度(弟子, 功法ID: String, 数量: int) -> Dictionary:
	if 弟子 == null:
		return {"升级": false, "原因": "弟子不存在"}
	return GongFaSystem.增加熟练度(弟子, 功法ID, 数量)

# 获取弟子功法列表（包含等级和熟练度）
func 获取弟子功法列表(弟子) -> Array:
	if 弟子 == null:
		return []
	var 已学功法 = 弟子.get("已学功法", [])
	if 已学功法 == null:
		return []
	var 列表: Array = []
	for 功法ID in 已学功法:
		var 功法 = GongFaSystem.功法库.get(功法ID, {})
		if 功法.is_empty():
			continue
		var 等级: int = GongFaSystem.获取功法等级(弟子, 功法ID)
		var 熟练度: int = GongFaSystem.获取功法熟练度(弟子, 功法ID)
		列表.append({
			"功法ID": 功法ID,
			"名称": str(功法.get("名称", "")),
			"品阶": str(功法.get("品阶", "")),
			"类型": str(功法.get("类型", "")),
			"等级": 等级,
			"熟练度": 熟练度,
			"修炼加成": float(功法.get("修炼加成", 0)),
			"战力加成": int(功法.get("战力加成", 0)),
		})
	return 列表

# 获取可学习功法列表
func 获取可学习功法列表() -> Array:
	var 可学习列表 = []
	for 功法ID in GongFaSystem.功法库.keys():
		var 功法 = GongFaSystem.功法库[功法ID]
		可学习列表.append({
			"功法ID": 功法ID,
			"名称": 功法.get("名称", ""),
			"品阶": 功法.get("品阶", ""),
			"类型": 功法.get("类型", ""),
			"修炼加成": 功法.get("修炼加成", 0),
			"战力加成": 功法.get("战力加成", 0),
			"学习消耗": 功法.get("学习消耗", 10),
		})
	return 可学习列表

# 获取所有功法类型
func 获取所有功法类型() -> Array:
	var 类型集合 = {}
	for 功法ID in GongFaSystem.功法库.keys():
		var 功法 = GongFaSystem.功法库[功法ID]
		var 类型 = 功法.get("类型", "")
		if 类型 != "":
			类型集合[类型] = true
	var 类型列表 = []
	for 类型 in 类型集合.keys():
		类型列表.append(类型)
	return 类型列表

# ============ 傀儡系统：封装方法 ============
# 制作傀儡（消耗材料，生成傀儡）
func 制作傀儡(傀儡名称: String, 傀儡品阶: String, 傀儡类型: String, 消耗灵石: int = 0) -> Dictionary:
	if 消耗灵石 > 0 and 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足"}
	if 消耗灵石 > 0:
		灵石 -= 消耗灵石
	var 新傀儡 = {
		"ID": 傀儡ID计数器,
		"名称": 傀儡名称,
		"品阶": 傀儡品阶,
		"类型": 傀儡类型,
		"等级": 1,
		"效果": "待实现",
	}
	傀儡ID计数器 += 1
	傀儡列表.append(新傀儡)
	# 成就统计：累计制作傀儡数自增
	累计制作傀儡数 += 1
	_复检成就()
	添加纪事("庶务", "制作傀儡", "制作了%s（%s）" % [傀儡名称, 傀儡品阶], 1)
	return {"成功": true, "傀儡": 新傀儡, "消息": "制作%s成功" % 傀儡名称}

# 获取傀儡列表
func 获取傀儡列表() -> Array:
	return 傀儡列表

# 升级傀儡（消耗灵石，提升傀儡等级和效果）
func 升级傀儡(傀儡ID: int, 消耗灵石: int = 0) -> Dictionary:
	var 目标傀儡 = null
	for 傀儡 in 傀儡列表:
		if 傀儡.get("ID", -1) == 傀儡ID:
			目标傀儡 = 傀儡
			break
	if 目标傀儡 == null:
		return {"成功": false, "原因": "傀儡不存在"}
	# 等级上限检查
	var 当前等级 = int(目标傀儡.get("等级", 1))
	var 最大等级 = 100
	if 当前等级 >= 最大等级:
		return {"成功": false, "原因": "已达到最大等级%d级" % 最大等级}
	# 根据等级计算升级消耗
	var 升级消耗 = 100 * 当前等级
	if 消耗灵石 > 0:
		升级消耗 = 消耗灵石
	if 灵石 < 升级消耗:
		return {"成功": false, "原因": "灵石不足（需要%d）" % 升级消耗}
	灵石 -= 升级消耗
	目标傀儡["等级"] = 当前等级 + 1
	# 根据傀儡类型计算效果
	var 等级 = int(目标傀儡.get("等级", 1))
	var 类型 = 目标傀儡.get("类型", "")
	if 类型 == "修炼型":
		目标傀儡["效果"] = "修炼速度+%d%%" % (等级 * 5)
	elif 类型 == "生产型":
		目标傀儡["效果"] = "产出+%d%%" % (等级 * 5)
	elif 类型 == "战斗型":
		目标傀儡["效果"] = "战力+%d" % (等级 * 10)
	elif 类型 == "防御型":
		目标傀儡["效果"] = "防御+%d" % (等级 * 8)
	elif 类型 == "辅助型":
		目标傀儡["效果"] = "心境+%d" % (等级 * 5)
	else:
		目标傀儡["效果"] = "全属性+%d%%" % (等级 * 3)
	添加纪事("庶务", "升级傀儡", "%s升级到%d级，消耗%d灵石" % [目标傀儡.get("名称", ""), 等级, 升级消耗], 1)
	return {"成功": true, "傀儡": 目标傀儡, "消耗": 升级消耗, "消息": "%s升级成功" % 目标傀儡.get("名称", "")}

# 傀儡类型配置（类型 -> {描述, 基础加成}）
const 傀儡类型配置: Dictionary = {
	"修炼型": {"描述": "专注修炼，提升弟子修炼速度", "修炼加成": 0.08, "产出加成": 0.0, "战力加成": 0},
	"生产型": {"描述": "专注生产，提升宗门产出", "修炼加成": 0.0, "产出加成": 0.08, "战力加成": 0},
	"战斗型": {"描述": "专注战斗，提升宗门战力", "修炼加成": 0.0, "产出加成": 0.0, "战力加成": 15},
	"全能型": {"描述": "均衡发展，全属性小幅提升", "修炼加成": 0.05, "产出加成": 0.05, "战力加成": 8},
	"防御型": {"描述": "专注防御，提升宗门防御", "修炼加成": 0.0, "产出加成": 0.03, "战力加成": 12},
	"辅助型": {"描述": "专注辅助，提升弟子心境", "修炼加成": 0.06, "产出加成": 0.02, "战力加成": 5},
}

# 获取所有傀儡类型
func 获取所有傀儡类型() -> Array:
	var 类型列表 = []
	for 类型 in 傀儡类型配置.keys():
		var 配置 = 傀儡类型配置[类型]
		类型列表.append({
			"类型": 类型,
			"描述": 配置.get("描述", ""),
			"修炼加成": 配置.get("修炼加成", 0.0),
			"产出加成": 配置.get("产出加成", 0.0),
			"战力加成": 配置.get("战力加成", 0),
		})
	return 类型列表

# 获取傀儡总加成（供其他系统调用）
func 获取傀儡总加成() -> Dictionary:
	var 加成 = {"修炼速度": 0.0, "产出": 0.0, "战力": 0}
	for 傀儡 in 傀儡列表:
		var 等级 = int(傀儡.get("等级", 1))
		var 类型 = 傀儡.get("类型", "")
		if 类型 == "修炼型":
			加成["修炼速度"] += 等级 * 0.05
		elif 类型 == "生产型":
			加成["产出"] += 等级 * 0.05
		elif 类型 == "战斗型":
			加成["战力"] += 等级 * 10
		else:
			加成["修炼速度"] += 等级 * 0.03
			加成["产出"] += 等级 * 0.03
		# 傀儡装备加成
		var 装备 = 傀儡.get("装备", {})
		if not 装备.is_empty():
			加成["修炼速度"] += float(装备.get("修炼加成", 0))
			加成["产出"] += float(装备.get("产出加成", 0))
			加成["战力"] += int(装备.get("战力加成", 0))
	return 加成

# 从仓库获取可装备给傀儡的物品列表
func 获取傀儡可装备物品() -> Array:
	var 可装备列表 = []
	for i in 宗门库房.size():
		var 物品 = 宗门库房[i]
		if 物品.类别 == "装备":
			可装备列表.append({
				"名称": 物品.名称,
				"品阶": 物品.品阶,
				"描述": 物品.描述,
				"索引": i,
			})
	return 可装备列表

# 从仓库选择装备给傀儡（消耗仓库中的装备）
func 傀儡从仓库装备(傀儡ID: int, 物品索引: int) -> Dictionary:
	# 检查傀儡是否存在
	var 目标傀儡 = null
	for 傀儡 in 傀儡列表:
		if 傀儡.get("ID", -1) == 傀儡ID:
			目标傀儡 = 傀儡
			break
	if 目标傀儡 == null:
		return {"成功": false, "原因": "傀儡不存在"}
	# 检查物品索引是否有效
	if 物品索引 < 0 or 物品索引 >= 宗门库房.size():
		return {"成功": false, "原因": "物品索引无效"}
	var 物品 = 宗门库房[物品索引]
	if 物品.类别 != "装备":
		return {"成功": false, "原因": "该物品不是装备"}
	# 如果傀儡已有装备，先卸下
	if not 目标傀儡.get("装备", {}).is_empty():
		var 旧装备 = 目标傀儡.get("装备", {})
		# 将旧装备放回仓库
		var 旧装备物品 = Item.new()
		旧装备物品.名称 = 旧装备.get("名称", "")
		旧装备物品.品阶 = 旧装备.get("品阶", "")
		旧装备物品.类别 = "装备"
		旧装备物品.描述 = "傀儡卸下的装备"
		宗门库房.append(旧装备物品)
	# 根据品阶计算装备加成
	var 装备品阶 = 物品.品阶
	var 修炼加成 = 0.0
	var 产出加成 = 0.0
	var 战力加成 = 0
	if 装备品阶 == "凡品":
		修炼加成 = 0.02
		产出加成 = 0.02
		战力加成 = 5
	elif 装备品阶 == "灵品":
		修炼加成 = 0.05
		产出加成 = 0.05
		战力加成 = 15
	elif 装备品阶 == "宝品":
		修炼加成 = 0.08
		产出加成 = 0.08
		战力加成 = 30
	elif 装备品阶 == "王品":
		修炼加成 = 0.12
		产出加成 = 0.12
		战力加成 = 50
	elif 装备品阶 == "圣品":
		修炼加成 = 0.18
		产出加成 = 0.18
		战力加成 = 80
	elif 装备品阶 == "仙品":
		修炼加成 = 0.25
		产出加成 = 0.25
		战力加成 = 120
	else:
		修炼加成 = 0.03
		产出加成 = 0.03
		战力加成 = 10
	目标傀儡["装备"] = {
		"名称": 物品.名称,
		"品阶": 装备品阶,
		"修炼加成": 修炼加成,
		"产出加成": 产出加成,
		"战力加成": 战力加成,
	}
	# 从仓库移除装备
	宗门库房.remove_at(物品索引)
	添加纪事("庶务", "傀儡装备", "%s从仓库装备了%s（%s）" % [目标傀儡.get("名称", ""), 物品.名称, 装备品阶], 1)
	return {"成功": true, "傀儡": 目标傀儡, "消息": "%s装备%s成功" % [目标傀儡.get("名称", ""), 物品.名称]}

# 为傀儡装备物品
func 傀儡装备(傀儡ID: int, 装备名称: String, 装备品阶: String = "灵品") -> Dictionary:
	var 目标傀儡 = null
	for 傀儡 in 傀儡列表:
		if 傀儡.get("ID", -1) == 傀儡ID:
			目标傀儡 = 傀儡
			break
	if 目标傀儡 == null:
		return {"成功": false, "原因": "傀儡不存在"}
	# 根据品阶计算装备加成
	var 修炼加成 = 0.0
	var 产出加成 = 0.0
	var 战力加成 = 0
	if 装备品阶 == "凡品":
		修炼加成 = 0.02
		产出加成 = 0.02
		战力加成 = 5
	elif 装备品阶 == "灵品":
		修炼加成 = 0.05
		产出加成 = 0.05
		战力加成 = 15
	elif 装备品阶 == "宝品":
		修炼加成 = 0.08
		产出加成 = 0.08
		战力加成 = 30
	elif 装备品阶 == "王品":
		修炼加成 = 0.12
		产出加成 = 0.12
		战力加成 = 50
	elif 装备品阶 == "圣品":
		修炼加成 = 0.18
		产出加成 = 0.18
		战力加成 = 80
	elif 装备品阶 == "仙品":
		修炼加成 = 0.25
		产出加成 = 0.25
		战力加成 = 120
	else:
		修炼加成 = 0.03
		产出加成 = 0.03
		战力加成 = 10
	目标傀儡["装备"] = {
		"名称": 装备名称,
		"品阶": 装备品阶,
		"修炼加成": 修炼加成,
		"产出加成": 产出加成,
		"战力加成": 战力加成,
	}
	添加纪事("庶务", "傀儡装备", "%s装备了%s（%s）" % [目标傀儡.get("名称", ""), 装备名称, 装备品阶], 1)
	return {"成功": true, "傀儡": 目标傀儡, "消息": "%s装备%s成功" % [目标傀儡.get("名称", ""), 装备名称]}

# 卸下傀儡装备
func 傀儡卸下装备(傀儡ID: int) -> Dictionary:
	var 目标傀儡 = null
	for 傀儡 in 傀儡列表:
		if 傀儡.get("ID", -1) == 傀儡ID:
			目标傀儡 = 傀儡
			break
	if 目标傀儡 == null:
		return {"成功": false, "原因": "傀儡不存在"}
	if 目标傀儡.get("装备", {}).is_empty():
		return {"成功": false, "原因": "傀儡未装备物品"}
	var 卸下装备 = 目标傀儡.get("装备", {})
	目标傀儡["装备"] = {}
	添加纪事("庶务", "傀儡卸下装备", "%s卸下了%s" % [目标傀儡.get("名称", ""), 卸下装备.get("名称", "")], 1)
	return {"成功": true, "卸下装备": 卸下装备, "消息": "%s卸下装备成功" % 目标傀儡.get("名称", "")}

# ============ 藏书阁系统：封装方法 ============
# 收录典籍到藏书阁
func 收录典籍(典籍名称: String, 典籍品阶: String, 典籍类型: String, 典籍描述: String = "") -> Dictionary:
	# 检查是否已收录
	for 典籍 in 藏书阁列表:
		if 典籍.get("名称", "") == 典籍名称:
			return {"成功": false, "原因": "该典籍已收录"}
	var 新典籍 = {
		"ID": 藏书阁ID计数器,
		"名称": 典籍名称,
		"品阶": 典籍品阶,
		"类型": 典籍类型,
		"描述": 典籍描述,
	}
	藏书阁ID计数器 += 1
	藏书阁列表.append(新典籍)
	# 成就统计：藏书阁收录数自增
	藏书阁收录数 += 1
	_复检成就()
	添加纪事("庶务", "收录典籍", "藏书阁收录了%s（%s）" % [典籍名称, 典籍品阶], 1)
	return {"成功": true, "典籍": 新典籍, "消息": "收录%s成功" % 典籍名称}

# 获取藏书阁列表
func 获取藏书阁列表() -> Array:
	return 藏书阁列表

# 典籍类型配置（类型 -> {描述, 阅读加成}）
const 典籍类型配置: Dictionary = {
	"修炼类": {"描述": "修炼功法典籍，阅读提升修炼速度", "阅读加成": 0.08},
	"阵法类": {"描述": "阵法布置典籍，阅读提升阵法效果", "阅读加成": 0.05},
	"丹道类": {"描述": "炼丹典籍，阅读提升炼丹成功率", "阅读加成": 0.06},
	"器道类": {"描述": "炼器典籍，阅读提升炼器成功率", "阅读加成": 0.06},
	"杂项类": {"描述": "杂项典籍，阅读获得悟道点", "阅读加成": 0.04},
	"历史类": {"描述": "宗门历史典籍，阅读获得声望", "阅读加成": 0.03},
}

# 获取所有典籍类型
func 获取所有典籍类型() -> Array:
	var 类型列表 = []
	for 类型 in 典籍类型配置.keys():
		var 配置 = 典籍类型配置[类型]
		类型列表.append({
			"类型": 类型,
			"描述": 配置.get("描述", ""),
			"阅读加成": 配置.get("阅读加成", 0.0),
		})
	return 类型列表

# 按类型筛选藏书阁典籍
func 按类型筛选藏书阁(典籍类型: String) -> Array:
	var 结果 = []
	for 典籍 in 藏书阁列表:
		if 典籍.get("类型", "") == 典籍类型:
			结果.append(典籍)
	return 结果

# 阅读典籍（获得悟道点和临时加成）
func 阅读典籍(典籍ID: int) -> Dictionary:
	var 目标典籍 = null
	for 典籍 in 藏书阁列表:
		if 典籍.get("ID", -1) == 典籍ID:
			目标典籍 = 典籍
			break
	if 目标典籍 == null:
		return {"成功": false, "原因": "典籍不存在"}
	# 阅读次数限制检查（每天只能阅读一次）
	var 今日阅读日期 = 目标典籍.get("今日阅读日期", -1)
	if 今日阅读日期 == 累计游戏日:
		return {"成功": false, "原因": "今天已经阅读过这本典籍了"}
	# 根据品阶计算基础奖励
	var 品阶 = 目标典籍.get("品阶", "")
	var 悟道点奖励 = 0
	var 修炼加成 = 0.0
	if 品阶 == "凡品":
		悟道点奖励 = 5
		修炼加成 = 0.02
	elif 品阶 == "灵品":
		悟道点奖励 = 15
		修炼加成 = 0.05
	elif 品阶 == "宝品":
		悟道点奖励 = 30
		修炼加成 = 0.08
	elif 品阶 == "王品":
		悟道点奖励 = 50
		修炼加成 = 0.12
	elif 品阶 == "圣品":
		悟道点奖励 = 80
		修炼加成 = 0.18
	elif 品阶 == "仙品":
		悟道点奖励 = 120
		修炼加成 = 0.25
	else:
		悟道点奖励 = 10
		修炼加成 = 0.03
	# 根据注释等级提升奖励
	var 注释等级 = int(目标典籍.get("注释等级", 0))
	var 注释加成 = 1.0 + 注释等级 * 0.1
	悟道点奖励 = int(悟道点奖励 * 注释加成)
	修炼加成 = 修炼加成 * 注释加成
	# 根据典籍类型调整奖励
	var 典籍类型 = 目标典籍.get("类型", "")
	if 典籍类型 == "丹道类":
		# 丹道类典籍额外提升炼丹成功率（临时）
		pass
	elif 典籍类型 == "器道类":
		# 器道类典籍额外提升锻造成功率（临时）
		pass
	悟道点 += 悟道点奖励
	# 设置临时修炼加成（持续1天）
	藏书阁临时加成 = 修炼加成
	藏书阁加成到期日 = 累计游戏日 + 1
	# 记录今日阅读日期
	目标典籍["今日阅读日期"] = 累计游戏日
	添加纪事("庶务", "阅读典籍", "阅读%s，获得%d悟道点，修炼速度+%d%%（持续1天），注释等级%d" % [目标典籍.get("名称", ""), 悟道点奖励, int(修炼加成 * 100), 注释等级], 1)
	return {"成功": true, "典籍": 目标典籍, "悟道点奖励": 悟道点奖励, "修炼加成": 修炼加成, "注释等级": 注释等级, "消息": "阅读%s成功" % 目标典籍.get("名称", "")}

# 获取藏书阁临时加成（供修炼系统调用）
func 获取藏书阁加成() -> float:
	if 藏书阁加成到期日 > 0 and 累计游戏日 < 藏书阁加成到期日:
		return 藏书阁临时加成
	return 0.0

# 为典籍添加注释（提升典籍效果）
func 添加典籍注释(典籍ID: int, 注释内容: String, 消耗悟道点: int = 10) -> Dictionary:
	var 目标典籍 = null
	for 典籍 in 藏书阁列表:
		if 典籍.get("ID", -1) == 典籍ID:
			目标典籍 = 典籍
			break
	if 目标典籍 == null:
		return {"成功": false, "原因": "典籍不存在"}
	if 悟道点 < 消耗悟道点:
		return {"成功": false, "原因": "悟道点不足"}
	悟道点 -= 消耗悟道点
	# 添加注释，提升典籍效果
	var 现有注释 = 目标典籍.get("注释", "")
	if 现有注释 != "":
		现有注释 += "\n"
	现有注释 += 注释内容
	目标典籍["注释"] = 现有注释
	目标典籍["注释等级"] = int(目标典籍.get("注释等级", 0)) + 1
	# 根据注释等级提升阅读奖励
	var 注释等级 = int(目标典籍.get("注释等级", 0))
	目标典籍["阅读加成"] = 0.02 * 注释等级
	添加纪事("庶务", "典籍注释", "为%s添加注释（等级%d）" % [目标典籍.get("名称", ""), 注释等级], 1)
	return {"成功": true, "典籍": 目标典籍, "消息": "为%s添加注释成功" % 目标典籍.get("名称", "")}

# 获取典籍详情（包含注释、注释等级等）
func 获取典籍详情(典籍ID: int) -> Dictionary:
	for 典籍 in 藏书阁列表:
		if 典籍.get("ID", -1) == 典籍ID:
			return {
				"ID": 典籍.get("ID", -1),
				"名称": 典籍.get("名称", ""),
				"品阶": 典籍.get("品阶", ""),
				"类型": 典籍.get("类型", ""),
				"描述": 典籍.get("描述", ""),
				"注释": 典籍.get("注释", ""),
				"注释等级": 典籍.get("注释等级", 0),
				"阅读加成": 典籍.get("阅读加成", 0.0),
			}
	return {}

# 获取典籍注释
func 获取典籍注释(典籍ID: int) -> String:
	for 典籍 in 藏书阁列表:
		if 典籍.get("ID", -1) == 典籍ID:
			return 典籍.get("注释", "")
	return ""

# ============ 药园系统：封装方法 ============
# 初始化药园地块（新游戏时调用）
func 初始化药园地块() -> void:
	药园地块列表 = []
	for i in 药园地块数量:
		药园地块列表.append({
			"ID": i,
			"已解锁": true,
			"种植物品": "",
			"成熟时间": 0,
		})

# 解锁药园地块（消耗灵石）
func 解锁药园地块(消耗灵石: int = 0) -> Dictionary:
	if 消耗灵石 > 0 and 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足"}
	if 消耗灵石 > 0:
		灵石 -= 消耗灵石
	var 新地块ID = 药园地块列表.size()
	药园地块列表.append({
		"ID": 新地块ID,
		"已解锁": true,
		"种植物品": "",
		"成熟时间": 0,
	})
	药园地块数量 += 1
	# 成就统计：药园已解锁地块自增
	药园已解锁地块 = 药园地块数量
	_复检成就()
	添加纪事("庶务", "解锁药园地块", "解锁第%d块药园地块" % 药园地块数量, 1)
	return {"成功": true, "地块ID": 新地块ID, "消息": "解锁药园地块成功"}

# 药园作物配置（名称 -> {成熟天数, 收获数量, 收获类型}）
const 药园作物配置: Dictionary = {
	"灵草": {"成熟天数": 2, "收获数量": 8, "收获类型": "灵草"},
	"灵谷": {"成熟天数": 3, "收获数量": 5, "收获类型": "灵气"},
	"灵花": {"成熟天数": 4, "收获数量": 3, "收获类型": "悟道点"},
	"灵果": {"成熟天数": 5, "收获数量": 2, "收获类型": "灵石"},
	"灵药": {"成熟天数": 6, "收获数量": 3, "收获类型": "材料"},
	"灵茶": {"成熟天数": 3, "收获数量": 4, "收获类型": "心境"},
	"灵米": {"成熟天数": 4, "收获数量": 5, "收获类型": "声望"},
	"灵参": {"成熟天数": 7, "收获数量": 1, "收获类型": "寿元"},
	"灵芝": {"成熟天数": 5, "收获数量": 2, "收获类型": "道伤"},
	"灵桃": {"成熟天数": 6, "收获数量": 2, "收获类型": "突破"},
	"灵莲": {"成熟天数": 4, "收获数量": 3, "收获类型": "神识"},
	"灵竹": {"成熟天数": 3, "收获数量": 6, "收获类型": "材料"},
	"灵菊": {"成熟天数": 2, "收获数量": 8, "收获类型": "解毒"},
	"灵梅": {"成熟天数": 5, "收获数量": 3, "收获类型": "心境"},
	"灵兰": {"成熟天数": 4, "收获数量": 4, "收获类型": "悟道点"},
}

# 种植物品到药园地块
func 种植药园(地块ID: int, 物品名称: String, 成熟天数: int = -1) -> Dictionary:
	if 地块ID < 0 or 地块ID >= 药园地块列表.size():
		return {"成功": false, "原因": "地块不存在"}
	var 地块 = 药园地块列表[地块ID]
	if not 地块.get("已解锁", false):
		return {"成功": false, "原因": "地块未解锁"}
	if 地块.get("种植物品", "") != "":
		return {"成功": false, "原因": "地块已种植"}
	# 根据作物配置获取成熟天数
	var 实际成熟天数 = 成熟天数
	if 实际成熟天数 <= 0:
		var 作物配置 = 药园作物配置.get(物品名称, {})
		if not 作物配置.is_empty():
			实际成熟天数 = int(作物配置.get("成熟天数", 3))
		else:
			实际成熟天数 = 3
	地块["种植物品"] = 物品名称
	地块["成熟时间"] = 累计游戏日 + 实际成熟天数
	添加纪事("庶务", "药园种植", "在第%d块地块种植%s，%d天后成熟" % [地块ID + 1, 物品名称, 实际成熟天数], 1)
	return {"成功": true, "地块": 地块, "消息": "种植%s成功" % 物品名称}

# 获取可种植作物列表
func 获取可种植作物列表() -> Array:
	var 作物列表 = []
	for 作物名称 in 药园作物配置.keys():
		var 作物配置 = 药园作物配置[作物名称]
		作物列表.append({
			"名称": 作物名称,
			"成熟天数": 作物配置.get("成熟天数", 3),
			"收获数量": 作物配置.get("收获数量", 1),
			"收获类型": 作物配置.get("收获类型", "材料"),
		})
	return 作物列表

# 一键种植所有空地块（使用指定作物）
func 一键种植药园(作物名称: String) -> Dictionary:
	var 种植数量 = 0
	var 失败数量 = 0
	for i in 药园地块列表.size():
		var 地块 = 药园地块列表[i]
		if 地块.get("已解锁", false) and 地块.get("种植物品", "") == "":
			var 结果 = 种植药园(i, 作物名称)
			if 结果.get("成功", false):
				种植数量 += 1
			else:
				失败数量 += 1
	return {"成功": 种植数量 > 0, "种植数量": 种植数量, "失败数量": 失败数量, "消息": "一键种植完成，成功%d块，失败%d块" % [种植数量, 失败数量]}

# 一键收获所有成熟地块
func 一键收获药园() -> Dictionary:
	var 收获列表 = []
	var 收获数量 = 0
	for i in 药园地块列表.size():
		var 地块 = 药园地块列表[i]
		if 地块.get("已解锁", false) and 地块.get("种植物品", "") != "":
			if 累计游戏日 >= 地块.get("成熟时间", 0):
				var 结果 = 收获药园(i)
				if 结果.get("成功", false):
					收获列表.append(结果)
					收获数量 += 1
	return {"成功": 收获数量 > 0, "收获数量": 收获数量, "收获列表": 收获列表, "消息": "一键收获完成，收获%d块地块" % 收获数量}

# 收获药园地块
func 收获药园(地块ID: int) -> Dictionary:
	if 地块ID < 0 or 地块ID >= 药园地块列表.size():
		return {"成功": false, "原因": "地块不存在"}
	var 地块 = 药园地块列表[地块ID]
	if 地块.get("种植物品", "") == "":
		return {"成功": false, "原因": "地块未种植"}
	if 累计游戏日 < 地块.get("成熟时间", 0):
		return {"成功": false, "原因": "尚未成熟"}
	var 物品名称 = 地块.get("种植物品", "")
	地块["种植物品"] = ""
	地块["成熟时间"] = 0
	# 根据作物配置获取收获
	var 作物配置 = 药园作物配置.get(物品名称, {})
	var 收获数量 = int(作物配置.get("收获数量", 1))
	var 收获类型 = 作物配置.get("收获类型", "材料")
	var 收获消息 = ""
	if 收获类型 == "灵草":
		灵草 += 收获数量
		收获消息 = "灵草+%d" % 收获数量
	elif 收获类型 == "灵气":
		灵气 += 收获数量 * 5
		收获消息 = "灵气+%d" % (收获数量 * 5)
	elif 收获类型 == "悟道点":
		悟道点 += 收获数量 * 3
		收获消息 = "悟道点+%d" % (收获数量 * 3)
	elif 收获类型 == "灵石":
		灵石 += 收获数量 * 20
		收获消息 = "灵石+%d" % (收获数量 * 20)
	else:
		# 其他物品添加到仓库
		for i in 收获数量:
			var 新物品 = Item.new()
			新物品.名称 = 物品名称
			新物品.品阶 = "灵品"
			新物品.类别 = "材料"
			新物品.描述 = "药园种植收获"
			宗门库房.append(新物品)
		收获消息 = "%s+%d" % [物品名称, 收获数量]
	添加纪事("庶务", "药园收获", "收获第%d块地块的%s，%s" % [地块ID + 1, 物品名称, 收获消息], 1)
	return {"成功": true, "物品": 物品名称, "收获": 收获消息, "消息": "收获%s成功" % 物品名称}

# ============ 丹方系统：封装方法 ============
# 解锁丹方（消耗灵石或悟道点）
func 解锁丹方(丹方ID: String, 丹方名称: String, 丹方品阶: String, 材料: String, 消耗灵石: int = 0, 消耗悟道点: int = 0) -> Dictionary:
	# 检查是否已解锁
	for 丹方 in 已解锁丹方列表:
		if 丹方.get("丹方ID", "") == 丹方ID:
			return {"成功": false, "原因": "该丹方已解锁"}
	if 消耗灵石 > 0 and 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足"}
	if 消耗悟道点 > 0 and 悟道点 < 消耗悟道点:
		return {"成功": false, "原因": "悟道点不足"}
	if 消耗灵石 > 0:
		灵石 -= 消耗灵石
	if 消耗悟道点 > 0:
		悟道点 -= 消耗悟道点
	var 新丹方 = {
		"丹方ID": 丹方ID,
		"名称": 丹方名称,
		"品阶": 丹方品阶,
		"材料": 材料,
	}
	已解锁丹方列表.append(新丹方)
	# 成就统计：已解锁丹方数自增
	已解锁丹方数 = 已解锁丹方列表.size()
	_复检成就()
	添加纪事("庶务", "解锁丹方", "解锁丹方%s（%s）" % [丹方名称, 丹方品阶], 1)
	return {"成功": true, "丹方": 新丹方, "消息": "解锁丹方%s成功" % 丹方名称}

# 丹药配方库（所有可解锁的丹方）
const 丹药配方库: Array = [
	{"丹方ID": "pill_001", "名称": "聚气丹", "品阶": "凡品", "材料": "灵草×5", "效果": "修炼速度+8%"},
	{"丹方ID": "pill_002", "名称": "养元丹", "品阶": "凡品", "材料": "灵草×6", "效果": "灵气恢复+15%"},
	{"丹方ID": "pill_003", "名称": "筑基丹", "品阶": "灵品", "材料": "灵草×8+灵晶×1", "效果": "突破成功率+12%"},
	{"丹方ID": "pill_004", "名称": "金丹丹", "品阶": "宝品", "材料": "灵晶×4", "效果": "修炼速度+20%"},
	{"丹方ID": "pill_005", "名称": "元婴丹", "品阶": "王品", "材料": "灵晶×6+天材地宝×1", "效果": "突破成功率+20%"},
	{"丹方ID": "pill_006", "名称": "化神丹", "品阶": "圣品", "材料": "天材地宝×4", "效果": "修炼速度+40%"},
	{"丹方ID": "pill_007", "名称": "炼虚丹", "品阶": "圣品", "材料": "天材地宝×5+灵晶×3", "效果": "突破成功率+30%"},
	{"丹方ID": "pill_008", "名称": "合体丹", "品阶": "仙品", "材料": "天材地宝×6+灵晶×4", "效果": "修炼速度+60%"},
	{"丹方ID": "pill_009", "名称": "大乘丹", "品阶": "仙品", "材料": "天材地宝×7+灵晶×5", "效果": "突破成功率+45%"},
	{"丹方ID": "pill_010", "名称": "渡劫丹", "品阶": "仙品", "材料": "天材地宝×10+灵晶×6", "效果": "渡劫成功率+60%"},
	{"丹方ID": "pill_011", "名称": "洗髓丹", "品阶": "王品", "材料": "灵草×12+灵晶×3", "效果": "提升灵根品阶"},
	{"丹方ID": "pill_012", "名称": "清心丹", "品阶": "宝品", "材料": "灵草×10+灵晶×2", "效果": "提升心境"},
	{"丹方ID": "pill_013", "名称": "长生丹", "品阶": "圣品", "材料": "天材地宝×3+灵晶×4", "效果": "延长寿元"},
	{"丹方ID": "pill_014", "名称": "道愈丹", "品阶": "仙品", "材料": "天材地宝×6", "效果": "修复道伤"},
	{"丹方ID": "pill_015", "名称": "回春丹", "品阶": "灵品", "材料": "灵草×8", "效果": "气血恢复+25%"},
	{"丹方ID": "pill_016", "名称": "凝神丹", "品阶": "宝品", "材料": "灵草×9+灵晶×2", "效果": "神识+20%"},
	{"丹方ID": "pill_017", "名称": "破障丹", "品阶": "王品", "材料": "灵晶×5+天材地宝×2", "效果": "突破瓶颈+25%"},
	{"丹方ID": "pill_018", "名称": "固元丹", "品阶": "圣品", "材料": "天材地宝×4+灵晶×3", "效果": "根基稳固+40%"},
	{"丹方ID": "pill_019", "名称": "辟毒丹", "品阶": "灵品", "材料": "灵草×10+灵晶×2", "效果": "免疫毒素+50%"},
	{"丹方ID": "pill_020", "名称": "隐身丹", "品阶": "宝品", "材料": "灵草×15+灵晶×3", "效果": "隐身效果持续30分钟"},
	{"丹方ID": "pill_021", "名称": "飞行丹", "品阶": "王品", "材料": "灵晶×6+天材地宝×2", "效果": "飞行能力持续1小时"},
	{"丹方ID": "pill_022", "名称": "传讯丹", "品阶": "宝品", "材料": "灵草×12+灵晶×3", "效果": "远程传讯三次"},
	{"丹方ID": "pill_023", "名称": "易容丹", "品阶": "王品", "材料": "灵晶×7+天材地宝×2", "效果": "改变容貌持续3小时"},
	{"丹方ID": "pill_024", "名称": "辟谷丹", "品阶": "凡品", "材料": "灵草×6", "效果": "无需进食持续7天"},
	{"丹方ID": "pill_025", "名称": "解毒丹", "品阶": "灵品", "材料": "灵草×8+灵晶×2", "效果": "解除所有毒素"},
]

# 获取所有丹药配方（用于丹方商店展示）
func 获取所有丹药配方() -> Array:
	return 丹药配方库

# 获取丹方商店列表（包含解锁状态和价格）
func 获取丹方商店列表() -> Array:
	var 商店列表 = []
	for 配方 in 丹药配方库:
		var 已解锁 = false
		for 已解锁丹方 in 已解锁丹方列表:
			if 已解锁丹方.get("丹方ID", "") == 配方.get("丹方ID", ""):
				已解锁 = true
				break
		# 根据品阶计算价格
		var 品阶 = 配方.get("品阶", "凡品")
		var 价格 = 200
		if 品阶 == "凡品":
			价格 = 200
		elif 品阶 == "灵品":
			价格 = 500
		elif 品阶 == "宝品":
			价格 = 1200
		elif 品阶 == "王品":
			价格 = 3000
		elif 品阶 == "圣品":
			价格 = 8000
		elif 品阶 == "仙品":
			价格 = 25000
		商店列表.append({
			"丹方ID": 配方.get("丹方ID", ""),
			"名称": 配方.get("名称", ""),
			"品阶": 品阶,
			"材料": 配方.get("材料", ""),
			"效果": 配方.get("效果", ""),
			"已解锁": 已解锁,
			"价格": 价格,
		})
	return 商店列表

# 从商店解锁丹方
func 商店解锁丹方(丹方ID: String) -> Dictionary:
	# 查找配方
	var 目标配方 = null
	for 配方 in 丹药配方库:
		if 配方.get("丹方ID", "") == 丹方ID:
			目标配方 = 配方
			break
	if 目标配方 == null:
		return {"成功": false, "原因": "丹方不存在"}
	# 检查是否已解锁
	for 已解锁丹方 in 已解锁丹方列表:
		if 已解锁丹方.get("丹方ID", "") == 丹方ID:
			return {"成功": false, "原因": "该丹方已解锁"}
	# 计算价格
	var 品阶 = 目标配方.get("品阶", "凡品")
	var 价格 = 100
	if 品阶 == "凡品":
		价格 = 100
	elif 品阶 == "灵品":
		价格 = 300
	elif 品阶 == "宝品":
		价格 = 800
	elif 品阶 == "王品":
		价格 = 2000
	elif 品阶 == "圣品":
		价格 = 5000
	elif 品阶 == "仙品":
		价格 = 15000
	# 检查灵石
	if 灵石 < 价格:
		return {"成功": false, "原因": "灵石不足（需要%d）" % 价格}
	# 扣除灵石并解锁
	灵石 -= 价格
	var 新丹方 = {
		"丹方ID": 丹方ID,
		"名称": 目标配方.get("名称", ""),
		"品阶": 品阶,
		"材料": 目标配方.get("材料", ""),
	}
	已解锁丹方列表.append(新丹方)
	已解锁丹方数 = 已解锁丹方列表.size()
	_复检成就()
	添加纪事("庶务", "解锁丹方", "从商店解锁丹方%s（%s），花费%d灵石" % [目标配方.get("名称", ""), 品阶, 价格], 1)
	return {"成功": true, "丹方": 新丹方, "花费": 价格, "消息": "解锁%s成功" % 目标配方.get("名称", "")}

# 获取已解锁丹方列表
func 获取已解锁丹方列表() -> Array:
	return 已解锁丹方列表

# 实际炼丹（消耗材料，生成丹药）
func 炼制丹药(丹方ID: String, 消耗灵石: int = 0) -> Dictionary:
	# 查找丹方
	var 目标丹方 = null
	for 丹方 in 已解锁丹方列表:
		if 丹方.get("丹方ID", "") == 丹方ID:
			目标丹方 = 丹方
			break
	if 目标丹方 == null:
		return {"成功": false, "原因": "丹方未解锁"}
	if 消耗灵石 > 0 and 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足"}
	if 消耗灵石 > 0:
		灵石 -= 消耗灵石
	# 根据品阶计算材料消耗和成功率
	var 丹药名称 = 目标丹方.get("名称", "未知丹药")
	var 丹药品阶 = 目标丹方.get("品阶", "灵品")
	# 根据品阶计算需要的灵草数量
	var 需要灵草 = 3
	if 丹药品阶 == "凡品":
		需要灵草 = 3
	elif 丹药品阶 == "灵品":
		需要灵草 = 5
	elif 丹药品阶 == "宝品":
		需要灵草 = 8
	elif 丹药品阶 == "王品":
		需要灵草 = 12
	elif 丹药品阶 == "圣品":
		需要灵草 = 18
	elif 丹药品阶 == "仙品":
		需要灵草 = 25
	# 根据品阶计算基础成功率
	var 基础成功率 = 0.8
	if 丹药品阶 == "凡品":
		基础成功率 = 0.95
	elif 丹药品阶 == "灵品":
		基础成功率 = 0.85
	elif 丹药品阶 == "宝品":
		基础成功率 = 0.70
	elif 丹药品阶 == "王品":
		基础成功率 = 0.55
	elif 丹药品阶 == "圣品":
		基础成功率 = 0.40
	elif 丹药品阶 == "仙品":
		基础成功率 = 0.25
	# 检查材料
	if 灵草 < 需要灵草:
		return {"成功": false, "原因": "灵草不足（需要%d）" % 需要灵草}
	灵草 -= 需要灵草
	# 计算实际成功率（可以受其他因素影响，如丹道类典籍加成）
	var 实际成功率 = clamp(基础成功率 + 获取气运炼丹加成(), 0.05, 0.99)	# P3 气运：炼丹成功率随气运±10%
	# 炼制判定
	var 随机数 = randf()
	if 随机数 > 实际成功率:
		# 炼制失败，材料已消耗
		添加纪事("庶务", "炼制丹药", "炼制%s（%s）失败，消耗%d灵草" % [丹药名称, 丹药品阶, 需要灵草], 1)
		return {"成功": false, "原因": "炼制失败（成功率%.0f%%）" % (实际成功率 * 100)}
	# 炼制成功，生成丹药，添加到仓库
	var 新丹药 = Item.new()
	新丹药.名称 = 丹药名称
	新丹药.品阶 = 丹药品阶
	新丹药.类别 = "丹药"
	新丹药.描述 = "炼制而成的%s" % 丹药名称
	宗门库房.append(新丹药)
	# S1-2：炼制丹药（玩家决策，日常 daily_005 / daily_013 宝品 / 周常 weekly_009）
	记任务进度("refine_pill", 丹药品阶)
	# 成就统计：累计炼制丹药数自增
	累计炼制丹药数 += 1
	_复检成就()
	添加纪事("庶务", "炼制丹药", "炼制了%s（%s），消耗%d灵草，成功率%.0f%%" % [丹药名称, 丹药品阶, 需要灵草, 实际成功率 * 100], 1)
	return {"成功": true, "丹药": 新丹药, "成功率": 实际成功率, "消息": "炼制%s成功" % 丹药名称}

# 获取可炼制丹方列表
func 获取可炼制丹方列表() -> Array:
	var 可炼制列表 = []
	for 丹方 in 已解锁丹方列表:
		var 丹药品阶 = 丹方.get("品阶", "灵品")
		var 需要灵草 = 3
		if 丹药品阶 == "凡品":
			需要灵草 = 3
		elif 丹药品阶 == "灵品":
			需要灵草 = 5
		elif 丹药品阶 == "宝品":
			需要灵草 = 8
		elif 丹药品阶 == "王品":
			需要灵草 = 12
		elif 丹药品阶 == "圣品":
			需要灵草 = 18
		elif 丹药品阶 == "仙品":
			需要灵草 = 25
		var 可炼制 = 灵草 >= 需要灵草
		可炼制列表.append({
			"丹方ID": 丹方.get("丹方ID", ""),
			"名称": 丹方.get("名称", ""),
			"品阶": 丹药品阶,
			"需要灵草": 需要灵草,
			"可炼制": 可炼制,
		})
	return 可炼制列表

# 批量炼制丹药
func 批量炼制丹药(丹方ID: String, 炼制次数: int = 1) -> Dictionary:
	var 成功数量 = 0
	var 失败数量 = 0
	var 炼制列表 = []
	for i in 炼制次数:
		var 结果 = 炼制丹药(丹方ID, 0)
		炼制列表.append(结果)
		if 结果.get("成功", false):
			成功数量 += 1
		else:
			失败数量 += 1
			# 如果材料不足，停止炼制
			if "不足" in 结果.get("原因", ""):
				break
	return {"成功": 成功数量 > 0, "成功数量": 成功数量, "失败数量": 失败数量, "炼制列表": 炼制列表, "消息": "批量炼制完成，成功%d次，失败%d次" % [成功数量, 失败数量]}

# 丹药使用统计
var 丹药使用统计: Dictionary = {}  # 丹药名称 -> 使用次数

# 记录丹药使用
func _记录丹药使用(丹药名称: String) -> void:
	if 丹药名称 in 丹药使用统计:
		丹药使用统计[丹药名称] += 1
	else:
		丹药使用统计[丹药名称] = 1

# 获取丹药使用统计
func 获取丹药使用统计() -> Dictionary:
	return 丹药使用统计

# 获取丹药使用排行榜
func 获取丹药使用排行榜(限制数量: int = 10) -> Array:
	var 排行榜 = []
	for 丹药名称 in 丹药使用统计.keys():
		排行榜.append({
			"丹药名称": 丹药名称,
			"使用次数": 丹药使用统计[丹药名称],
		})
	排行榜.sort_custom(func(a, b): return a["使用次数"] > b["使用次数"])
	return 排行榜.slice(0, min(限制数量, 排行榜.size()))

# 丹药品质提升配置
const 丹药品质提升配置: Dictionary = {
	"凡品": {"下一品阶": "灵品", "成功率": 0.3, "消耗灵石": 1000, "消耗灵草": 50},
	"灵品": {"下一品阶": "宝品", "成功率": 0.25, "消耗灵石": 3000, "消耗灵草": 100},
	"宝品": {"下一品阶": "王品", "成功率": 0.2, "消耗灵石": 8000, "消耗灵草": 200},
	"王品": {"下一品阶": "圣品", "成功率": 0.15, "消耗灵石": 20000, "消耗灵草": 400},
	"圣品": {"下一品阶": "仙品", "成功率": 0.1, "消耗灵石": 50000, "消耗灵草": 800},
}

# 提升丹药品质
func 提升丹药品质(丹药索引: int) -> Dictionary:
	if 丹药索引 < 0 or 丹药索引 >= 宗门库房.size():
		return {"成功": false, "原因": "丹药不存在"}
	var 丹药 = 宗门库房[丹药索引]
	if 丹药 == null or 丹药.类别 != "丹药":
		return {"成功": false, "原因": "该物品不是丹药"}
	var 当前品阶 = 丹药.品阶
	if 当前品阶 not in 丹药品质提升配置:
		return {"成功": false, "原因": "该品阶丹药无法提升"}
	var 配置 = 丹药品质提升配置[当前品阶]
	var 消耗灵石 = int(配置.get("消耗灵石", 0))
	var 消耗灵草 = int(配置.get("消耗灵草", 0))
	var 成功率 = float(配置.get("成功率", 0))
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
	if 灵草 < 消耗灵草:
		return {"成功": false, "原因": "灵草不足（需%d灵草）" % 消耗灵草}
	灵石 -= 消耗灵石
	灵草 -= 消耗灵草
	var 随机值 = randf()
	if 随机值 < 成功率:
		var 新品阶 = str(配置.get("下一品阶", ""))
		丹药.品阶 = 新品阶
		添加纪事("庶务", "提升丹药品质", "%s品质提升为%s" % [丹药.名称, 新品阶], 1)
		return {"成功": true, "丹药": 丹药, "新品阶": 新品阶, "消耗灵石": 消耗灵石, "消耗灵草": 消耗灵草, "消息": "%s品质提升成功" % 丹药.名称}
	else:
		添加纪事("庶务", "提升丹药品质", "%s品质提升失败" % 丹药.名称, 1)
		return {"成功": false, "原因": "品质提升失败", "消耗灵石": 消耗灵石, "消耗灵草": 消耗灵草, "消息": "%s品质提升失败" % 丹药.名称}

# 获取丹药品质提升消耗
func 获取丹药品质提升消耗(丹药索引: int) -> Dictionary:
	if 丹药索引 < 0 or 丹药索引 >= 宗门库房.size():
		return {}
	var 丹药 = 宗门库房[丹药索引]
	if 丹药 == null or 丹药.类别 != "丹药":
		return {}
	var 当前品阶 = 丹药.品阶
	if 当前品阶 not in 丹药品质提升配置:
		return {"当前品阶": 当前品阶, "是否可提升": false, "原因": "该品阶丹药无法提升"}
	var 配置 = 丹药品质提升配置[当前品阶]
	return {
		"当前品阶": 当前品阶,
		"下一品阶": 配置.get("下一品阶", ""),
		"成功率": float(配置.get("成功率", 0)),
		"消耗灵石": int(配置.get("消耗灵石", 0)),
		"消耗灵草": int(配置.get("消耗灵草", 0)),
		"是否可提升": true,
	}

# ============ 装备图纸系统：封装方法 ============
# 解锁装备图纸（消耗灵石或悟道点）
func 解锁装备图纸(图纸ID: String, 图纸名称: String, 图纸品阶: String, 材料: String, 消耗灵石: int = 0, 消耗悟道点: int = 0) -> Dictionary:
	# 检查是否已解锁
	for 图纸 in 已解锁装备图纸列表:
		if 图纸.get("图纸ID", "") == 图纸ID:
			return {"成功": false, "原因": "该图纸已解锁"}
	if 消耗灵石 > 0 and 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足"}
	if 消耗悟道点 > 0 and 悟道点 < 消耗悟道点:
		return {"成功": false, "原因": "悟道点不足"}
	if 消耗灵石 > 0:
		灵石 -= 消耗灵石
	if 消耗悟道点 > 0:
		悟道点 -= 消耗悟道点
	var 新图纸 = {
		"图纸ID": 图纸ID,
		"名称": 图纸名称,
		"品阶": 图纸品阶,
		"材料": 材料,
	}
	已解锁装备图纸列表.append(新图纸)
	# 成就统计：已解锁装备图纸数自增
	已解锁装备图纸数 = 已解锁装备图纸列表.size()
	_复检成就()
	添加纪事("庶务", "解锁图纸", "解锁装备图纸%s（%s）" % [图纸名称, 图纸品阶], 1)
	return {"成功": true, "图纸": 新图纸, "消息": "解锁图纸%s成功" % 图纸名称}

# 装备强化配置
const 装备强化配置: Dictionary = {
	1: {"成功率": 0.9, "消耗灵石": 100, "攻击加成": 5, "防御加成": 3, "速度加成": 2},
	2: {"成功率": 0.8, "消耗灵石": 300, "攻击加成": 10, "防御加成": 6, "速度加成": 4},
	3: {"成功率": 0.7, "消耗灵石": 800, "攻击加成": 20, "防御加成": 12, "速度加成": 8},
	4: {"成功率": 0.6, "消耗灵石": 2000, "攻击加成": 35, "防御加成": 20, "速度加成": 14},
	5: {"成功率": 0.5, "消耗灵石": 5000, "攻击加成": 55, "防御加成": 32, "速度加成": 22},
	6: {"成功率": 0.4, "消耗灵石": 12000, "攻击加成": 80, "防御加成": 48, "速度加成": 32},
	7: {"成功率": 0.3, "消耗灵石": 30000, "攻击加成": 110, "防御加成": 66, "速度加成": 44},
	8: {"成功率": 0.2, "消耗灵石": 80000, "攻击加成": 145, "防御加成": 87, "速度加成": 58},
	9: {"成功率": 0.1, "消耗灵石": 200000, "攻击加成": 185, "防御加成": 111, "速度加成": 74},
	10: {"成功率": 0.05, "消耗灵石": 500000, "攻击加成": 230, "防御加成": 138, "速度加成": 92},
}

# 强化装备
func 强化装备(装备索引: int) -> Dictionary:
	if 装备索引 < 0 or 装备索引 >= 宗门库房.size():
		return {"成功": false, "原因": "装备不存在"}
	var 装备 = 宗门库房[装备索引]
	if 装备 == null or 装备.类别 != "装备":
		return {"成功": false, "原因": "该物品不是装备"}
	var 当前强化等级 = int(装备.get("强化等级", 0))
	if 当前强化等级 >= 10:
		return {"成功": false, "原因": "装备已达最高强化等级"}
	var 配置 = 装备强化配置.get(当前强化等级 + 1, {})
	var 消耗灵石 = int(配置.get("消耗灵石", 0))
	var 成功率 = float(配置.get("成功率", 0))
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
	灵石 -= 消耗灵石
	var 随机值 = randf()
	if 随机值 < 成功率:
		装备["强化等级"] = 当前强化等级 + 1
		# 提升装备属性
		var 攻击加成 = int(配置.get("攻击加成", 0))
		var 防御加成 = int(配置.get("防御加成", 0))
		var 速度加成 = int(配置.get("速度加成", 0))
		装备.攻击 += 攻击加成
		装备.防御 += 防御加成
		装备.速度 += 速度加成
		添加纪事("庶务", "强化装备", "%s强化到+%d级" % [装备.名称, 当前强化等级 + 1], 1)
		return {"成功": true, "装备": 装备, "新强化等级": 当前强化等级 + 1, "消耗灵石": 消耗灵石, "攻击加成": 攻击加成, "防御加成": 防御加成, "速度加成": 速度加成, "消息": "%s强化成功" % 装备.名称}
	else:
		添加纪事("庶务", "强化装备", "%s强化失败" % 装备.名称, 1)
		return {"成功": false, "原因": "强化失败", "消耗灵石": 消耗灵石, "消息": "%s强化失败" % 装备.名称}

# 获取装备强化消耗
func 获取装备强化消耗(装备索引: int) -> Dictionary:
	if 装备索引 < 0 or 装备索引 >= 宗门库房.size():
		return {}
	var 装备 = 宗门库房[装备索引]
	if 装备 == null or 装备.类别 != "装备":
		return {}
	var 当前强化等级 = int(装备.get("强化等级", 0))
	if 当前强化等级 >= 10:
		return {"当前强化等级": 当前强化等级, "最大强化等级": 10, "是否可强化": false, "原因": "装备已达最高强化等级"}
	var 配置 = 装备强化配置.get(当前强化等级 + 1, {})
	return {
		"当前强化等级": 当前强化等级,
		"下一级强化等级": 当前强化等级 + 1,
		"最大强化等级": 10,
		"成功率": float(配置.get("成功率", 0)),
		"消耗灵石": int(配置.get("消耗灵石", 0)),
		"攻击加成": int(配置.get("攻击加成", 0)),
		"防御加成": int(配置.get("防御加成", 0)),
		"速度加成": int(配置.get("速度加成", 0)),
		"是否可强化": true,
	}

# 分解装备（获得灵石和材料）
func 分解装备(装备索引: int) -> Dictionary:
	if 装备索引 < 0 or 装备索引 >= 宗门库房.size():
		return {"成功": false, "原因": "装备不存在"}
	var 装备 = 宗门库房[装备索引]
	if 装备 == null or 装备.类别 != "装备":
		return {"成功": false, "原因": "该物品不是装备"}
	# 根据品阶计算分解收益
	var 品阶 = 装备.品阶
	var 返还灵石 = 100
	var 返还矿石 = 10
	if 品阶 == "凡品":
		返还灵石 = 100
		返还矿石 = 10
	elif 品阶 == "灵品":
		返还灵石 = 300
		返还矿石 = 30
	elif 品阶 == "宝品":
		返还灵石 = 800
		返还矿石 = 80
	elif 品阶 == "王品":
		返还灵石 = 2000
		返还矿石 = 200
	elif 品阶 == "圣品":
		返还灵石 = 5000
		返还矿石 = 500
	elif 品阶 == "仙品":
		返还灵石 = 15000
		返还矿石 = 1500
	# 考虑强化等级的额外收益
	var 强化等级 = int(装备.get("强化等级", 0))
	if 强化等级 > 0:
		返还灵石 += 强化等级 * 50
		返还矿石 += 强化等级 * 5
	灵石 += 返还灵石
	矿石 += 返还矿石
	宗门库房.remove_at(装备索引)
	添加纪事("庶务", "分解装备", "分解%s，获得%d灵石和%d矿石" % [装备.名称, 返还灵石, 返还矿石], 1)
	return {"成功": true, "返还灵石": 返还灵石, "返还矿石": 返还矿石, "消息": "分解%s成功，获得%d灵石和%d矿石" % [装备.名称, 返还灵石, 返还矿石]}

# 获取装备分解收益
func 获取装备分解收益(装备索引: int) -> Dictionary:
	if 装备索引 < 0 or 装备索引 >= 宗门库房.size():
		return {}
	var 装备 = 宗门库房[装备索引]
	if 装备 == null or 装备.类别 != "装备":
		return {}
	var 品阶 = 装备.品阶
	var 返还灵石 = 100
	var 返还矿石 = 10
	if 品阶 == "凡品":
		返还灵石 = 100
		返还矿石 = 10
	elif 品阶 == "灵品":
		返还灵石 = 300
		返还矿石 = 30
	elif 品阶 == "宝品":
		返还灵石 = 800
		返还矿石 = 80
	elif 品阶 == "王品":
		返还灵石 = 2000
		返还矿石 = 200
	elif 品阶 == "圣品":
		返还灵石 = 5000
		返还矿石 = 500
	elif 品阶 == "仙品":
		返还灵石 = 15000
		返还矿石 = 1500
	var 强化等级 = int(装备.get("强化等级", 0))
	if 强化等级 > 0:
		返还灵石 += 强化等级 * 50
		返还矿石 += 强化等级 * 5
	return {
		"装备名称": 装备.名称,
		"品阶": 品阶,
		"强化等级": 强化等级,
		"返还灵石": 返还灵石,
		"返还矿石": 返还矿石,
	}

# 装备图纸库（所有可解锁的图纸）
const 装备图纸库: Array = [
	{"图纸ID": "equip_001", "名称": "铁剑", "品阶": "凡品", "材料": "矿石×8", "效果": "攻击+15"},
	{"图纸ID": "equip_002", "名称": "铜甲", "品阶": "凡品", "材料": "矿石×10", "效果": "防御+20"},
	{"图纸ID": "equip_003", "名称": "铁靴", "品阶": "凡品", "材料": "矿石×6", "效果": "速度+8"},
	{"图纸ID": "equip_004", "名称": "银盔", "品阶": "灵品", "材料": "矿石×12+灵晶×2", "效果": "防御+35"},
	{"图纸ID": "equip_005", "名称": "金靴", "品阶": "灵品", "材料": "矿石×10+灵晶×2", "效果": "速度+25"},
	{"图纸ID": "equip_006", "名称": "灵品法剑", "品阶": "灵品", "材料": "灵晶×3+矿石×10", "效果": "攻击+40"},
	{"图纸ID": "equip_007", "名称": "宝品法剑", "品阶": "宝品", "材料": "灵晶×4+矿石×12", "效果": "攻击+70"},
	{"图纸ID": "equip_008", "名称": "宝品护甲", "品阶": "宝品", "材料": "灵晶×4+矿石×15", "效果": "防御+80"},
	{"图纸ID": "equip_009", "名称": "宝品法冠", "品阶": "宝品", "材料": "灵晶×3+矿石×10", "效果": "神识+50"},
	{"图纸ID": "equip_010", "名称": "王品战甲", "品阶": "王品", "材料": "灵晶×6+天材地宝×2", "效果": "防御+120"},
	{"图纸ID": "equip_011", "名称": "王品飞剑", "品阶": "王品", "材料": "灵晶×5+天材地宝×2", "效果": "攻击+150"},
	{"图纸ID": "equip_012", "名称": "王品法袍", "品阶": "王品", "材料": "灵晶×5+天材地宝×2", "效果": "全属性+70"},
	{"图纸ID": "equip_013", "名称": "圣品法宝", "品阶": "圣品", "材料": "天材地宝×4", "效果": "全属性+50"},
	{"图纸ID": "equip_014", "名称": "圣品仙剑", "品阶": "圣品", "材料": "天材地宝×5+灵晶×3", "效果": "攻击+300"},
	{"图纸ID": "equip_015", "名称": "圣品神甲", "品阶": "圣品", "材料": "天材地宝×5+灵晶×3", "效果": "防御+250"},
	{"图纸ID": "equip_016", "名称": "仙品神器", "品阶": "仙品", "材料": "天材地宝×6+灵晶×6", "效果": "全属性+150"},
	{"图纸ID": "equip_017", "名称": "仙品诛仙剑", "品阶": "仙品", "材料": "天材地宝×8+灵晶×8", "效果": "攻击+800"},
	{"图纸ID": "equip_018", "名称": "仙品玄天宝甲", "品阶": "仙品", "材料": "天材地宝×8+灵晶×8", "效果": "防御+600"},
	{"图纸ID": "equip_019", "名称": "储物袋", "品阶": "凡品", "材料": "矿石×8+灵草×5", "效果": "背包容量+20"},
	{"图纸ID": "equip_020", "名称": "飞行法器", "品阶": "灵品", "材料": "灵晶×3+矿石×12", "效果": "飞行速度+35%"},
	{"图纸ID": "equip_021", "名称": "传讯玉简", "品阶": "宝品", "材料": "灵晶×4+矿石×15", "效果": "远程传讯功能（无限次）"},
	{"图纸ID": "equip_022", "名称": "隐身披风", "品阶": "王品", "材料": "灵晶×7+天材地宝×2", "效果": "隐身能力（主动触发）"},
	{"图纸ID": "equip_023", "名称": "防御护盾", "品阶": "圣品", "材料": "天材地宝×4+灵晶×5", "效果": "自动防御+80%"},
	{"图纸ID": "equip_024", "名称": "空间戒指", "品阶": "仙品", "材料": "天材地宝×6+灵晶×7", "效果": "背包容量+200"},
	{"图纸ID": "equip_025", "名称": "时光沙漏", "品阶": "仙品", "材料": "天材地宝×8+灵晶×8", "效果": "时间减缓能力（主动触发）"},
]

# 获取所有装备图纸（用于图纸商店展示）
func 获取所有装备图纸() -> Array:
	return 装备图纸库

# 获取图纸商店列表（包含解锁状态和价格）
func 获取图纸商店列表() -> Array:
	var 商店列表 = []
	for 图纸 in 装备图纸库:
		var 已解锁 = false
		for 已解锁图纸 in 已解锁装备图纸列表:
			if 已解锁图纸.get("图纸ID", "") == 图纸.get("图纸ID", ""):
				已解锁 = true
				break
		# 根据品阶计算价格
		var 品阶 = 图纸.get("品阶", "凡品")
		var 价格 = 300
		if 品阶 == "凡品":
			价格 = 300
		elif 品阶 == "灵品":
			价格 = 700
		elif 品阶 == "宝品":
			价格 = 1800
		elif 品阶 == "王品":
			价格 = 4500
		elif 品阶 == "圣品":
			价格 = 12000
		elif 品阶 == "仙品":
			价格 = 35000
		商店列表.append({
			"图纸ID": 图纸.get("图纸ID", ""),
			"名称": 图纸.get("名称", ""),
			"品阶": 品阶,
			"材料": 图纸.get("材料", ""),
			"效果": 图纸.get("效果", ""),
			"已解锁": 已解锁,
			"价格": 价格,
		})
	return 商店列表

# 从商店解锁图纸
func 商店解锁图纸(图纸ID: String) -> Dictionary:
	# 查找图纸
	var 目标图纸 = null
	for 图纸 in 装备图纸库:
		if 图纸.get("图纸ID", "") == 图纸ID:
			目标图纸 = 图纸
			break
	if 目标图纸 == null:
		return {"成功": false, "原因": "图纸不存在"}
	# 检查是否已解锁
	for 已解锁图纸 in 已解锁装备图纸列表:
		if 已解锁图纸.get("图纸ID", "") == 图纸ID:
			return {"成功": false, "原因": "该图纸已解锁"}
	# 计算价格
	var 品阶 = 目标图纸.get("品阶", "凡品")
	var 价格 = 150
	if 品阶 == "凡品":
		价格 = 150
	elif 品阶 == "灵品":
		价格 = 400
	elif 品阶 == "宝品":
		价格 = 1000
	elif 品阶 == "王品":
		价格 = 2500
	elif 品阶 == "圣品":
		价格 = 6000
	elif 品阶 == "仙品":
		价格 = 20000
	# 检查灵石
	if 灵石 < 价格:
		return {"成功": false, "原因": "灵石不足（需要%d）" % 价格}
	# 扣除灵石并解锁
	灵石 -= 价格
	var 新图纸 = {
		"图纸ID": 图纸ID,
		"名称": 目标图纸.get("名称", ""),
		"品阶": 品阶,
		"材料": 目标图纸.get("材料", ""),
	}
	已解锁装备图纸列表.append(新图纸)
	已解锁装备图纸数 = 已解锁装备图纸列表.size()
	_复检成就()
	添加纪事("庶务", "解锁图纸", "从商店解锁装备图纸%s（%s），花费%d灵石" % [目标图纸.get("名称", ""), 品阶, 价格], 1)
	return {"成功": true, "图纸": 新图纸, "花费": 价格, "消息": "解锁%s成功" % 目标图纸.get("名称", "")}

# 获取已解锁装备图纸列表
func 获取已解锁装备图纸列表() -> Array:
	return 已解锁装备图纸列表

# 实际锻造装备（消耗材料，生成装备）
func 锻造装备(图纸ID: String, 消耗灵石: int = 0) -> Dictionary:
	# 查找图纸
	var 目标图纸 = null
	for 图纸 in 已解锁装备图纸列表:
		if 图纸.get("图纸ID", "") == 图纸ID:
			目标图纸 = 图纸
			break
	if 目标图纸 == null:
		return {"成功": false, "原因": "图纸未解锁"}
	if 消耗灵石 > 0 and 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足"}
	if 消耗灵石 > 0:
		灵石 -= 消耗灵石
	# 根据品阶计算材料消耗和成功率
	var 装备名称 = 目标图纸.get("名称", "未知装备")
	var 装备品阶 = 目标图纸.get("品阶", "灵品")
	# 根据品阶计算需要的矿石数量
	var 需要矿石 = 5
	if 装备品阶 == "凡品":
		需要矿石 = 5
	elif 装备品阶 == "灵品":
		需要矿石 = 8
	elif 装备品阶 == "宝品":
		需要矿石 = 12
	elif 装备品阶 == "王品":
		需要矿石 = 18
	elif 装备品阶 == "圣品":
		需要矿石 = 25
	elif 装备品阶 == "仙品":
		需要矿石 = 35
	# 根据品阶计算基础成功率
	var 基础成功率 = 0.8
	if 装备品阶 == "凡品":
		基础成功率 = 0.95
	elif 装备品阶 == "灵品":
		基础成功率 = 0.85
	elif 装备品阶 == "宝品":
		基础成功率 = 0.70
	elif 装备品阶 == "王品":
		基础成功率 = 0.55
	elif 装备品阶 == "圣品":
		基础成功率 = 0.40
	elif 装备品阶 == "仙品":
		基础成功率 = 0.25
	# 检查材料
	if 矿石 < 需要矿石:
		return {"成功": false, "原因": "矿石不足（需要%d）" % 需要矿石}
	矿石 -= 需要矿石
	# 计算实际成功率（可以受其他因素影响，如器道类典籍加成）
	var 实际成功率 = clamp(基础成功率 + 获取气运炼丹加成(), 0.05, 0.99)	# P3 气运：炼器成功率随气运±10%（复用炼丹加成）
	# 锻造判定
	var 随机数 = randf()
	if 随机数 > 实际成功率:
		# 锻造失败，材料已消耗
		添加纪事("庶务", "锻造装备", "锻造%s（%s）失败，消耗%d矿石" % [装备名称, 装备品阶, 需要矿石], 1)
		return {"成功": false, "原因": "锻造失败（成功率%.0f%%）" % (实际成功率 * 100)}
	# 锻造成功，生成装备，添加到仓库
	var 新装备 = Item.new()
	新装备.名称 = 装备名称
	新装备.品阶 = 装备品阶
	新装备.类别 = "装备"
	新装备.描述 = "锻造而成的%s" % 装备名称
	宗门库房.append(新装备)
	# 成就统计：累计锻造装备数自增
	累计锻造装备数 += 1
	# S1-2：锻造装备（玩家决策，周常 weekly_011 / weekly_012 灵品）
	记任务进度("forge_equipment", 装备品阶)
	_复检成就()
	添加纪事("庶务", "锻造装备", "锻造了%s（%s），消耗%d矿石，成功率%.0f%%" % [装备名称, 装备品阶, 需要矿石, 实际成功率 * 100], 1)
	return {"成功": true, "装备": 新装备, "成功率": 实际成功率, "消息": "锻造%s成功" % 装备名称}

# 获取可锻造装备列表
func 获取可锻造装备列表() -> Array:
	var 可锻造列表 = []
	for 图纸 in 已解锁装备图纸列表:
		var 装备品阶 = 图纸.get("品阶", "灵品")
		var 需要矿石 = 5
		if 装备品阶 == "凡品":
			需要矿石 = 5
		elif 装备品阶 == "灵品":
			需要矿石 = 8
		elif 装备品阶 == "宝品":
			需要矿石 = 12
		elif 装备品阶 == "王品":
			需要矿石 = 18
		elif 装备品阶 == "圣品":
			需要矿石 = 25
		elif 装备品阶 == "仙品":
			需要矿石 = 35
		var 可锻造 = 矿石 >= 需要矿石
		可锻造列表.append({
			"图纸ID": 图纸.get("图纸ID", ""),
			"名称": 图纸.get("名称", ""),
			"品阶": 装备品阶,
			"需要矿石": 需要矿石,
			"可锻造": 可锻造,
		})
	return 可锻造列表

# 批量锻造装备
func 批量锻造装备(图纸ID: String, 锻造次数: int = 1) -> Dictionary:
	var 成功数量 = 0
	var 失败数量 = 0
	var 锻造列表 = []
	for i in 锻造次数:
		var 结果 = 锻造装备(图纸ID, 0)
		锻造列表.append(结果)
		if 结果.get("成功", false):
			成功数量 += 1
		else:
			失败数量 += 1
			# 如果材料不足，停止锻造
			if "不足" in 结果.get("原因", ""):
				break
	return {"成功": 成功数量 > 0, "成功数量": 成功数量, "失败数量": 失败数量, "锻造列表": 锻造列表, "消息": "批量锻造完成，成功%d次，失败%d次" % [成功数量, 失败数量]}

# ============ 阵法系统：封装方法 ============
# 初始化阵法耐久度（旧档兼容）
func _初始化阵法耐久度() -> void:
	for 阵法ID in 阵法等级.keys():
		if not 阵法耐久度.has(阵法ID):
			var 等级: int = int(阵法等级[阵法ID])
			阵法耐久度[阵法ID] = ZhenFaSystem.计算最大耐久度(等级)

# 升级阵法（封装ZhenFaSystem.升级阵法，自动更新等级和耐久度）
func 升级阵法(阵法ID: String, 阵法堂等级: int) -> Dictionary:
	var 当前等级: int = int(阵法等级.get(阵法ID, 0))
	var 结果: Dictionary = ZhenFaSystem.升级阵法(阵法ID, 当前等级, 阵法堂等级)
	if 结果.get("成功", false):
		var 新等级: int = int(结果.get("新等级", 当前等级 + 1))
		阵法等级[阵法ID] = 新等级
		# 升级后耐久度恢复满
		阵法耐久度[阵法ID] = ZhenFaSystem.计算最大耐久度(新等级)
		# S1-2：阵法由 0 级升到 1 级即「布置」（日常 daily_023）；再往上为「升级」（日常 daily_024）
		记任务进度("deploy_zhenfa" if 当前等级 == 0 else "upgrade_zhenfa")
	return 结果

# 修复阵法（封装ZhenFaSystem.修复阵法，自动更新耐久度）
func 修复阵法(阵法ID: String) -> Dictionary:
	var 当前等级: int = int(阵法等级.get(阵法ID, 0))
	var 当前耐久度: int = int(阵法耐久度.get(阵法ID, ZhenFaSystem.计算最大耐久度(当前等级)))
	var 结果: Dictionary = ZhenFaSystem.修复阵法(阵法ID, 当前耐久度, 当前等级)
	if 结果.get("成功", false):
		阵法耐久度[阵法ID] = int(结果.get("新耐久度", 当前耐久度))
		记任务进度("repair_zhenfa")   # S1-2：修复受损阵法（玩家决策，日常 daily_025）
	return 结果

# 获取阵法信息（包含等级、耐久度、驻守弟子）
func 获取阵法信息(阵法ID: String) -> Dictionary:
	var 阵法 = ZhenFaSystem.阵法库.get(阵法ID, {})
	if 阵法.is_empty():
		return {}
	var 等级: int = int(阵法等级.get(阵法ID, 0))
	var 最大耐久度: int = ZhenFaSystem.计算最大耐久度(等级)
	var 当前耐久度: int = int(阵法耐久度.get(阵法ID, 最大耐久度))
	var 驻守弟子列表: Array = 阵法驻守弟子.get(阵法ID, [])
	return {
		"阵法ID": 阵法ID,
		"名称": str(阵法.get("名称", "")),
		"类型": str(阵法.get("类型", "")),
		"等级": 等级,
		"当前耐久度": 当前耐久度,
		"最大耐久度": 最大耐久度,
		"耐久度比例": float(当前耐久度) / float(max(1, 最大耐久度)),
		"驻守弟子数": 驻守弟子列表.size() if 驻守弟子列表 != null else 0,
		"驻守需求": int(阵法.get("驻守需求", 1)),
		"布置位置": str(阵法.get("布置位置", "")),
		"特殊效果": str(阵法.get("特殊效果", "")),
		"描述": str(阵法.get("描述", "")),
	}

# 获取所有已激活阵法列表
func 获取已激活阵法列表() -> Array:
	var 列表: Array = []
	for 阵法ID in 阵法等级.keys():
		var 等级: int = int(阵法等级[阵法ID])
		if 等级 > 0:
			列表.append(获取阵法信息(阵法ID))
	return 列表

# 计算阵法总效果（封装ZhenFaSystem.计算效果，考虑驻守弟子境界加成）
func 计算阵法总效果() -> Dictionary:
	# 计算驻守弟子境界加成
	var 总加成: float = 1.0
	var 所有驻守弟子: Array = []
	for 阵法ID in 阵法驻守弟子.keys():
		var 弟子ID列表 = 阵法驻守弟子[阵法ID]
		if 弟子ID列表 != null:
			for 弟子ID in 弟子ID列表:
				for 弟子 in 弟子列表:
					if 弟子 != null and str(弟子.弟子ID) == str(弟子ID):
						所有驻守弟子.append(弟子)
	if 所有驻守弟子.size() > 0:
		总加成 = ZhenFaSystem.计算驻守境界加成(所有驻守弟子)
	return ZhenFaSystem.计算效果(阵法等级, 总加成)

# 阵法强化配置
const 阵法强化配置: Dictionary = {
	1: {"成功率": 0.9, "消耗灵石": 500, "消耗灵晶": 10, "效果提升": 0.1},
	2: {"成功率": 0.8, "消耗灵石": 1500, "消耗灵晶": 30, "效果提升": 0.15},
	3: {"成功率": 0.7, "消耗灵石": 4000, "消耗灵晶": 80, "效果提升": 0.2},
	4: {"成功率": 0.6, "消耗灵石": 10000, "消耗灵晶": 200, "效果提升": 0.25},
	5: {"成功率": 0.5, "消耗灵石": 25000, "消耗灵晶": 500, "效果提升": 0.3},
	6: {"成功率": 0.4, "消耗灵石": 60000, "消耗灵晶": 1200, "效果提升": 0.35},
	7: {"成功率": 0.3, "消耗灵石": 150000, "消耗灵晶": 3000, "效果提升": 0.4},
	8: {"成功率": 0.2, "消耗灵石": 400000, "消耗灵晶": 8000, "效果提升": 0.45},
	9: {"成功率": 0.1, "消耗灵石": 1000000, "消耗灵晶": 20000, "效果提升": 0.5},
	10: {"成功率": 0.05, "消耗灵石": 2500000, "消耗灵晶": 50000, "效果提升": 0.6},
}

# 阵法强化等级
var 阵法强化等级: Dictionary = {}  # 阵法ID -> 强化等级

# 强化阵法
func 强化阵法(阵法ID: String) -> Dictionary:
	var 当前等级 = int(阵法等级.get(阵法ID, 0))
	if 当前等级 <= 0:
		return {"成功": false, "原因": "阵法未激活"}
	var 当前强化等级 = int(阵法强化等级.get(阵法ID, 0))
	if 当前强化等级 >= 10:
		return {"成功": false, "原因": "阵法已达最高强化等级"}
	var 配置 = 阵法强化配置.get(当前强化等级 + 1, {})
	var 消耗灵石 = int(配置.get("消耗灵石", 0))
	var 消耗灵晶 = int(配置.get("消耗灵晶", 0))
	var 成功率 = float(配置.get("成功率", 0))
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
	if 灵晶 < 消耗灵晶:
		return {"成功": false, "原因": "灵晶不足（需%d灵晶）" % 消耗灵晶}
	灵石 -= 消耗灵石
	灵晶 -= 消耗灵晶
	var 随机值 = randf()
	if 随机值 < 成功率:
		阵法强化等级[阵法ID] = 当前强化等级 + 1
		添加纪事("庶务", "强化阵法", "%s强化到+%d级" % [阵法ID, 当前强化等级 + 1], 1)
		return {"成功": true, "阵法ID": 阵法ID, "新强化等级": 当前强化等级 + 1, "消耗灵石": 消耗灵石, "消耗灵晶": 消耗灵晶, "消息": "%s强化成功" % 阵法ID}
	else:
		添加纪事("庶务", "强化阵法", "%s强化失败" % 阵法ID, 1)
		return {"成功": false, "原因": "强化失败", "消耗灵石": 消耗灵石, "消耗灵晶": 消耗灵晶, "消息": "%s强化失败" % 阵法ID}

# 获取阵法强化消耗
func 获取阵法强化消耗(阵法ID: String) -> Dictionary:
	var 当前等级 = int(阵法等级.get(阵法ID, 0))
	if 当前等级 <= 0:
		return {"已激活": false, "原因": "阵法未激活"}
	var 当前强化等级 = int(阵法强化等级.get(阵法ID, 0))
	if 当前强化等级 >= 10:
		return {"已激活": true, "当前强化等级": 当前强化等级, "最大强化等级": 10, "是否可强化": false, "原因": "阵法已达最高强化等级"}
	var 配置 = 阵法强化配置.get(当前强化等级 + 1, {})
	return {
		"已激活": true,
		"当前强化等级": 当前强化等级,
		"下一级强化等级": 当前强化等级 + 1,
		"最大强化等级": 10,
		"成功率": float(配置.get("成功率", 0)),
		"消耗灵石": int(配置.get("消耗灵石", 0)),
		"消耗灵晶": int(配置.get("消耗灵晶", 0)),
		"效果提升": float(配置.get("效果提升", 0)),
		"是否可强化": true,
	}

# 阵法组合效果配置
const 阵法组合效果配置: Dictionary = {
	"攻防一体": {"阵法": ["攻击阵", "防御阵"], "效果": "攻击+10%，防御+10%", "攻击加成": 0.1, "防御加成": 0.1},
	"三才归元": {"阵法": ["天阵", "地阵", "人阵"], "效果": "全属性+15%", "全属性加成": 0.15},
	"四象守护": {"阵法": ["青龙阵", "白虎阵", "朱雀阵", "玄武阵"], "效果": "防御+25%，耐久度+20%", "防御加成": 0.25, "耐久加成": 0.2},
	"五行相生": {"阵法": ["金阵", "木阵", "水阵", "火阵", "土阵"], "效果": "修炼速度+20%，产出+20%", "修炼加成": 0.2, "产出加成": 0.2},
}

# 计算阵法组合效果
func 计算阵法组合效果() -> Dictionary:
	var 已激活阵法 = 获取已激活阵法列表()
	var 已激活阵法ID = []
	for 阵法 in 已激活阵法:
		已激活阵法ID.append(阵法.get("阵法ID", ""))
	var 组合效果 = {
		"攻击加成": 0.0,
		"防御加成": 0.0,
		"全属性加成": 0.0,
		"耐久加成": 0.0,
		"修炼加成": 0.0,
		"产出加成": 0.0,
		"已激活组合": [],
	}
	for 组合名称 in 阵法组合效果配置.keys():
		var 配置 = 阵法组合效果配置[组合名称]
		var 需要阵法 = 配置.get("阵法", [])
		var 全部激活 = true
		for 阵法ID in 需要阵法:
			if 阵法ID not in 已激活阵法ID:
				全部激活 = false
				break
		if 全部激活:
			组合效果["已激活组合"].append({
				"组合名称": 组合名称,
				"效果": 配置.get("效果", ""),
			})
			组合效果["攻击加成"] += float(配置.get("攻击加成", 0))
			组合效果["防御加成"] += float(配置.get("防御加成", 0))
			组合效果["全属性加成"] += float(配置.get("全属性加成", 0))
			组合效果["耐久加成"] += float(配置.get("耐久加成", 0))
			组合效果["修炼加成"] += float(配置.get("修炼加成", 0))
			组合效果["产出加成"] += float(配置.get("产出加成", 0))
	return 组合效果

# 获取所有阵法组合列表
func 获取所有阵法组合列表() -> Array:
	var 列表 = []
	var 已激活阵法 = 获取已激活阵法列表()
	var 已激活阵法ID = []
	for 阵法 in 已激活阵法:
		已激活阵法ID.append(阵法.get("阵法ID", ""))
	for 组合名称 in 阵法组合效果配置.keys():
		var 配置 = 阵法组合效果配置[组合名称]
		var 需要阵法 = 配置.get("阵法", [])
		var 已激活数量 = 0
		for 阵法ID in 需要阵法:
			if 阵法ID in 已激活阵法ID:
				已激活数量 += 1
		列表.append({
			"组合名称": 组合名称,
			"需要阵法": 需要阵法,
			"效果": 配置.get("效果", ""),
			"已激活数量": 已激活数量,
			"总数量": 需要阵法.size(),
			"是否全部激活": 已激活数量 == 需要阵法.size(),
		})
	return 列表

# 获取所有阵法列表（包含未激活的）
func 获取所有阵法列表() -> Array:
	var 列表: Array = []
	for 阵法ID in ZhenFaSystem.阵法库.keys():
		var 阵法 = ZhenFaSystem.阵法库[阵法ID]
		var 等级: int = int(阵法等级.get(阵法ID, 0))
		var 最大耐久度: int = ZhenFaSystem.计算最大耐久度(等级)
		var 当前耐久度: int = int(阵法耐久度.get(阵法ID, 最大耐久度))
		var 驻守弟子列表: Array = 阵法驻守弟子.get(阵法ID, [])
		列表.append({
			"阵法ID": 阵法ID,
			"名称": str(阵法.get("名称", "")),
			"类型": str(阵法.get("类型", "")),
			"等级": 等级,
			"已激活": 等级 > 0,
			"当前耐久度": 当前耐久度,
			"最大耐久度": 最大耐久度,
			"驻守弟子数": 驻守弟子列表.size() if 驻守弟子列表 != null else 0,
			"驻守需求": int(阵法.get("驻守需求", 1)),
			"布置位置": str(阵法.get("布置位置", "")),
			"特殊效果": str(阵法.get("特殊效果", "")),
			"描述": str(阵法.get("描述", "")),
		})
	return 列表

# 一键修复所有阵法
func 一键修复所有阵法() -> Dictionary:
	var 修复数量 = 0
	var 修复列表 = []
	for 阵法ID in 阵法等级.keys():
		var 等级: int = int(阵法等级[阵法ID])
		if 等级 > 0:
			var 最大耐久度: int = ZhenFaSystem.计算最大耐久度(等级)
			var 当前耐久度: int = int(阵法耐久度.get(阵法ID, 最大耐久度))
			if 当前耐久度 < 最大耐久度:
				var 结果 = 修复阵法(阵法ID)
				if 结果.get("成功", false):
					修复数量 += 1
					修复列表.append(结果)
	return {"成功": 修复数量 > 0, "修复数量": 修复数量, "修复列表": 修复列表, "消息": "一键修复完成，修复%d个阵法" % 修复数量}

# ============ 坐骑系统（新增） ============
# 坐骑列表（{id, 名称, 品阶, 类型, 速度加成, 战力加成, 已激活, 当前使用}）
var 坐骑列表: Array = []
var 当前坐骑: String = ""  # 当前使用的坐骑ID
var 坐骑ID计数器: int = 0

# 坐骑类型配置
const 坐骑类型配置: Dictionary = {
	"飞行": {"描述": "飞行坐骑，移动速度快", "速度加成": 0.20},
	"陆地": {"描述": "陆地坐骑，稳定可靠", "速度加成": 0.10},
	"水中": {"描述": "水中坐骑，水中移动快", "速度加成": 0.15},
	"神兽": {"描述": "神兽坐骑，全属性加成", "速度加成": 0.30},
}

# 初始化默认坐骑
func _初始化默认坐骑() -> void:
	if 坐骑列表.is_empty():
		坐骑列表.append({
			"id": "mount_default",
			"名称": "青牛",
			"品阶": "凡品",
			"类型": "陆地",
			"速度加成": 0.05,
			"战力加成": 10,
			"已激活": true,
			"当前使用": true,
		})
		当前坐骑 = "mount_default"
		坐骑ID计数器 = 1

# 获取所有坐骑列表
func 获取所有坐骑列表() -> Array:
	_初始化默认坐骑()
	var 列表 = []
	for 坐骑 in 坐骑列表:
		列表.append({
			"id": 坐骑.get("id", ""),
			"名称": 坐骑.get("名称", ""),
			"品阶": 坐骑.get("品阶", ""),
			"类型": 坐骑.get("类型", ""),
			"速度加成": 坐骑.get("速度加成", 0),
			"战力加成": 坐骑.get("战力加成", 0),
			"已激活": 坐骑.get("已激活", false),
			"当前使用": 坐骑.get("id", "") == 当前坐骑,
		})
	return 列表

# 获取坐骑统计
func 获取坐骑统计() -> Dictionary:
	_初始化默认坐骑()
	var 已激活数 = 0
	var 总速度加成 = 0.0
	var 总战力加成 = 0
	for 坐骑 in 坐骑列表:
		if 坐骑.get("已激活", false):
			已激活数 += 1
			总速度加成 += float(坐骑.get("速度加成", 0))
			总战力加成 += int(坐骑.get("战力加成", 0))
	return {
		"总数": 坐骑列表.size(),
		"已激活数": 已激活数,
		"当前坐骑": 当前坐骑,
		"总速度加成": 总速度加成,
		"总战力加成": 总战力加成,
	}

# 激活坐骑
func 激活坐骑(坐骑ID: String) -> Dictionary:
	_初始化默认坐骑()
	for 坐骑 in 坐骑列表:
		if 坐骑.get("id", "") == 坐骑ID:
			if 坐骑.get("已激活", false):
				return {"成功": false, "原因": "坐骑已激活"}
			坐骑["已激活"] = true
			添加纪事("庶务", "激活坐骑", "激活了%s（%s）" % [坐骑.get("名称", ""), 坐骑.get("品阶", "")], 1)
			return {"成功": true, "坐骑": 坐骑, "消息": "激活%s成功" % 坐骑.get("名称", "")}
	return {"成功": false, "原因": "坐骑不存在"}

# 切换坐骑
func 切换坐骑(坐骑ID: String) -> Dictionary:
	_初始化默认坐骑()
	for 坐骑 in 坐骑列表:
		if 坐骑.get("id", "") == 坐骑ID:
			if not 坐骑.get("已激活", false):
				return {"成功": false, "原因": "坐骑未激活"}
			# 取消当前坐骑的使用状态
			for m in 坐骑列表:
				m["当前使用"] = false
			坐骑["当前使用"] = true
			当前坐骑 = 坐骑ID
			添加纪事("庶务", "切换坐骑", "切换到%s" % 坐骑.get("名称", ""), 1)
			return {"成功": true, "坐骑": 坐骑, "消息": "切换到%s成功" % 坐骑.get("名称", "")}
	return {"成功": false, "原因": "坐骑不存在"}

# 获取当前坐骑加成
func 获取当前坐骑加成() -> Dictionary:
	_初始化默认坐骑()
	for 坐骑 in 坐骑列表:
		if 坐骑.get("id", "") == 当前坐骑:
			return {
				"速度加成": float(坐骑.get("速度加成", 0)),
				"战力加成": int(坐骑.get("战力加成", 0)),
				"名称": 坐骑.get("名称", ""),
			}
	return {"速度加成": 0.0, "战力加成": 0, "名称": "无"}

# 升级坐骑（提升速度加成和战力加成）
func 升级坐骑(坐骑ID: String) -> Dictionary:
	_初始化默认坐骑()
	for 坐骑 in 坐骑列表:
		if 坐骑.get("id", "") == 坐骑ID:
			if not 坐骑.get("已激活", false):
				return {"成功": false, "原因": "坐骑未激活"}
			var 当前等级 = int(坐骑.get("等级", 1))
			var 最大等级 = 10
			if 当前等级 >= 最大等级:
				return {"成功": false, "原因": "坐骑已达最高等级"}
			var 消耗灵石 = 1000 * 当前等级
			if 灵石 < 消耗灵石:
				return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
			灵石 -= 消耗灵石
			坐骑["等级"] = 当前等级 + 1
			# 提升加成
			var 原速度加成 = float(坐骑.get("速度加成", 0))
			var 原战力加成 = int(坐骑.get("战力加成", 0))
			坐骑["速度加成"] = 原速度加成 + 0.01
			坐骑["战力加成"] = 原战力加成 + 10
			添加纪事("庶务", "升级坐骑", "%s升级到%d级，速度加成+1%%，战力加成+10" % [坐骑.get("名称", ""), 当前等级 + 1], 1)
			return {"成功": true, "坐骑": 坐骑, "消耗灵石": 消耗灵石, "消息": "%s升级成功" % 坐骑.get("名称", "")}
	return {"成功": false, "原因": "坐骑不存在"}

# 培养坐骑（提升经验，经验满后自动升级）
func 培养坐骑(坐骑ID: String, 培养次数: int = 1) -> Dictionary:
	_初始化默认坐骑()
	for 坐骑 in 坐骑列表:
		if 坐骑.get("id", "") == 坐骑ID:
			if not 坐骑.get("已激活", false):
				return {"成功": false, "原因": "坐骑未激活"}
			var 消耗灵石 = 100 * 培养次数
			if 灵石 < 消耗灵石:
				return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
			灵石 -= 消耗灵石
			var 当前经验 = int(坐骑.get("经验", 0))
			var 升级所需经验 = 100 * int(坐骑.get("等级", 1))
			var 获得经验 = 50 * 培养次数
			当前经验 += 获得经验
			var 升级次数 = 0
			while 当前经验 >= 升级所需经验 and int(坐骑.get("等级", 1)) < 10:
				当前经验 -= 升级所需经验
				坐骑["等级"] = int(坐骑.get("等级", 1)) + 1
				升级次数 += 1
				# 提升加成
				var 原速度加成 = float(坐骑.get("速度加成", 0))
				var 原战力加成 = int(坐骑.get("战力加成", 0))
				坐骑["速度加成"] = 原速度加成 + 0.01
				坐骑["战力加成"] = 原战力加成 + 10
				升级所需经验 = 100 * int(坐骑.get("等级", 1))
			坐骑["经验"] = 当前经验
			if 升级次数 > 0:
				添加纪事("庶务", "培养坐骑", "%s培养后升级%d次" % [坐骑.get("名称", ""), 升级次数], 1)
			return {"成功": true, "坐骑": 坐骑, "获得经验": 获得经验, "升级次数": 升级次数, "消耗灵石": 消耗灵石, "消息": "培养%s成功，获得%d经验" % [坐骑.get("名称", ""), 获得经验]}
	return {"成功": false, "原因": "坐骑不存在"}

# 获取坐骑升级消耗
func 获取坐骑升级消耗(坐骑ID: String) -> Dictionary:
	_初始化默认坐骑()
	for 坐骑 in 坐骑列表:
		if 坐骑.get("id", "") == 坐骑ID:
			var 当前等级 = int(坐骑.get("等级", 1))
			return {
				"当前等级": 当前等级,
				"最大等级": 10,
				"升级消耗灵石": 1000 * 当前等级,
				"培养消耗灵石": 100,
				"培养获得经验": 50,
				"升级所需经验": 100 * 当前等级,
				"当前经验": int(坐骑.get("经验", 0)),
			}
	return {}

# ============ 碎片合成系统：库存管理 + 合成逻辑 ============
# 添加碎片
func 添加碎片(碎片ID: String, 数量: int) -> void:
	if 数量 <= 0:
		return
	碎片库存[碎片ID] = int(碎片库存.get(碎片ID, 0)) + 数量

# 移除碎片
func 移除碎片(碎片ID: String, 数量: int) -> bool:
	var 当前数量: int = int(碎片库存.get(碎片ID, 0))
	if 当前数量 < 数量:
		return false
	碎片库存[碎片ID] = 当前数量 - 数量
	if 碎片库存[碎片ID] <= 0:
		碎片库存.erase(碎片ID)
	return true

# 获取碎片数量
func 获取碎片数量(碎片ID: String) -> int:
	return int(碎片库存.get(碎片ID, 0))

# 执行碎片合成
func 执行碎片合成(碎片ID: String) -> Dictionary:
	var 数量: int = 获取碎片数量(碎片ID)
	var 结果: Dictionary = FragmentCraftSystem.执行合成(碎片ID, 数量, 灵石)
	if not 结果.get("成功", false):
		return 结果
	# 消耗碎片和灵石
	移除碎片(碎片ID, int(结果.get("消耗碎片数", 0)))
	灵石 -= int(结果.get("消耗灵石", 0))
	# 产出物品（简化版本：根据产出类型添加到对应库存）
	var 产出ID: String = str(结果.get("产出ID", ""))
	var 产出类型: String = str(结果.get("产出类型", ""))
	match 产出类型:
		"碎片":
			添加碎片(产出ID, 1)
		"资源":
			# 资源类型直接添加到对应变量（简化版本）
			pass
		_:
			# 其他类型添加到宗门库房（简化版本）
			pass
	添加纪事("大事件", "碎片合成", "合成%s成功" % str(结果.get("原因", "")), 2)
	return 结果

# ============ 宝箱系统：库存管理 + 打开逻辑 ============
# 添加宝箱
func 添加宝箱(宝箱ID: String, 数量: int) -> void:
	if 数量 <= 0:
		return
	宝箱库存[宝箱ID] = int(宝箱库存.get(宝箱ID, 0)) + 数量

# 移除宝箱
func 移除宝箱(宝箱ID: String, 数量: int) -> bool:
	var 当前数量: int = int(宝箱库存.get(宝箱ID, 0))
	if 当前数量 < 数量:
		return false
	宝箱库存[宝箱ID] = 当前数量 - 数量
	if 宝箱库存[宝箱ID] <= 0:
		宝箱库存.erase(宝箱ID)
	return true

# 获取宝箱数量
func 获取宝箱数量(宝箱ID: String) -> int:
	return int(宝箱库存.get(宝箱ID, 0))

# 打开宝箱
func 打开宝箱(宝箱ID: String) -> Dictionary:
	if 获取宝箱数量(宝箱ID) <= 0:
		return {"成功": false, "掉落列表": [], "原因": "宝箱数量不足"}
	var 结果: Dictionary = ChestSystem.打开宝箱(宝箱ID)
	if not 结果.get("成功", false):
		return 结果
	# 消耗宝箱
	移除宝箱(宝箱ID, 1)
	# 发放掉落物品（简化版本：根据物品类型添加到对应库存）
	for 掉落 in 结果.get("掉落列表", []):
		var 物品ID: String = str(掉落.get("物品ID", ""))
		var 物品类型: String = str(掉落.get("物品类型", ""))
		var 数量: int = int(掉落.get("数量", 1))
		match 物品类型:
			"资源":
				match 物品ID:
					"灵石": 灵石 += 数量
					"灵草": 灵草 += 数量
					"矿石": 矿石 += 数量
					"灵气": 灵气 += 数量
					"悟道点": 悟道点 += 数量
					"声望": 声望 += 数量
			"碎片":
				添加碎片(物品ID, 数量)
			"宝箱":
				添加宝箱(物品ID, 数量)
			_:
				# 其他类型添加到宗门库房（简化版本）
				pass
	添加纪事("大事件", "宝箱开启", str(结果.get("原因", "")), 2)
	return 结果

# ============ 玄榜（排行榜）系统：单机种子化虚拟对：+ 真实本宗数据 ============
# 玄榜是跨服多人榜，单机存档无「他人」数据；以种子化虚拟对手宗门 + 真实本宗数据插位，MVP 接入（不升SAVE_VERSION）：
func _种子化玄() -> void:

	if not 玄榜虚拟宗门.is_empty():
		return
	# 12 个虚拟宗门：{： 战力, 境界： 功勋, 探索, 商道, 名望, 称号}
	玄榜虚拟宗门 = [
		{"名": "玄幽魔宗", "战力": 912300, "境界值": 7, "功勋": 84200, "探索": 61000, "商道": 55000, "名望": 72000, "称号": "魔道巨擘"},
		{"名": "丹器师公会", "战力": 876500, "境界值": 6, "功勋": 71000, "探索": 48000, "商道": 92000, "名望": 65000, "称号": "百工之宗"},
		{"名": "万灵古族", "战力": 712000, "境界值": 6, "功勋": 58000, "探索": 87000, "商道": 33000, "名望": 54000, "称号": "寻幽探秘"},
		{"名": "散修同盟会", "战力": 543000, "境界值": 5, "功勋": 46000, "探索": 52000, "商道": 41000, "名望": 38000, "称号": "逍遥盟主"},
		{"名": "正道盟", "战力": 498000, "境界值": 5, "功勋": 67000, "探索": 39000, "商道": 36000, "名望": 61000, "称号": "正道魁首"},
		{"名": "东海商盟", "战力": 376000, "境界值": 5, "功勋": 30000, "探索": 28000, "商道": 88000, "名望": 29000, "称号": "富甲一方"},
		{"名": "北冥剑宗", "战力": 631000, "境界值": 6, "功勋": 52000, "探索": 44000, "商道": 30000, "名望": 47000, "称号": "剑脉祖庭"},
		{"名": "焚天谷", "战力": 689000, "境界值": 6, "功勋": 49000, "探索": 33000, "商道": 27000, "名望": 44000, "称号": "离火传承"},
		{"名": "太虚观", "战力": 412000, "境界值": 5, "功勋": 55000, "探索": 61000, "商道": 24000, "名望": 50000, "称号": "观星望气"},
		{"名": "百草门", "战力": 358000, "境界值": 4, "功勋": 33000, "探索": 41000, "商道": 39000, "名望": 31000, "称号": "丹道世家"},
		{"名": "天机阁", "战力": 521000, "境界值": 5, "功勋": 60000, "探索": 47000, "商道": 46000, "名望": 56000, "称号": "推演无双"},
		{"名": "九霄雷府", "战力": 764000, "境界值": 7, "功勋": 51000, "探索": 35000, "商道": 29000, "名望": 53000, "称号": "雷霆法脉"},
	]
# 取玄榜：类型("个人"/"宗门")、指：战力/境界/功勋/探索/商道/名望)、范：本服/赛区/全服)
# 返回降序 Array[{： ： 称号, 自己}]
func 取玄榜(类型: String, 指标: String, 范围: String) -> Array:

	var 榜: Array = []
	if 类型 == "个人":
		榜= _取个人榜数据()
	else:
		榜= _取宗门榜数据()
	var 带榜: Array = []
	for e in 榜:
		var 分: int = _玄榜指标(e, 指标)
		带榜.append({"名": e.get("名") if "名" in e else "", "称号": e.get("称号") if "称号" in e else "", "自己": e.get("自己") if "自己" in e else false})
	带榜.sort_custom(_玄榜_按值降)
	if 范围 == "本服":
		带榜 = _裁剪到范(带榜, 5)
	elif 范围 == "赛区":
		带榜 = _裁剪到范(带榜, 8)
	return 带榜
func _取个人榜数据() -> Array:

	var 榜: Array = []
	for d in 弟子列表:
		if d == null:
			continue
		var 名: String = ""
		if d.姓名 != "":
			名 = "%s·%s" % [宗门名, d.姓名]
		else:
				名 = "%s·%s" % [宗门名, d.道号]
		榜.append({"名": 名, "战力": int(d.战力), "境界值": Disciple.境界表.get(d.境界), "自己": false})
	var 掌门战力: int = _宗主战力()
	榜.append({"名": "%s·%s（你方）" % [宗门名, 宗主名], "战力": 掌门战力, "境界值": _宗主境界, "自己": true})
	return 榜
func _取宗门榜数据() -> Array:

	var 榜: Array = []
	for v in 玄榜虚拟宗门:
		榜.append({"名": v.get("名") if "名" in v else "", "战力": int(v.get("战力") if "战力" in v else 0), "境界值": int(v.get("境界值") if "境界值" in v else 0),
			"功勋": int(v.get("功勋") if "功勋" in v else 0), "探索": int(v.get("探索") if "探索" in v else 0), "商道": int(v.get("商道") if "商道" in v else 0),
			"名望": int(v.get("名望") if "名望" in v else 0), "称号": v.get("称号") if "称号" in v else "", "自己": false})
	var 自己战力: int = _宗门总战()
	榜.append({"名": "%s（你方）" % 宗门名, "战力": 自己战力, "境界值": _宗主境界,
		"功勋": 门派等级 * 8000, "探索": 门派等级 * 6000, "商道": 门派等级 * 5000, "名望": 门派等级 * 7000,
		"称号": "正道魁首", "自己": true})
	return 榜
func _玄榜指标(e: Dictionary, 指标: String) -> int:

	match 指标:
		"战力":
			return int(e.get("战力") if "战力" in e else 0)
		"境界":
			return int(e.get("境界值") if "境界值" in e else 0)
		"功勋":
			return int(e.get("功勋") if "功勋" in e else 0)
		"探索":
			return int(e.get("探索") if "探索" in e else 0)
		"商道":
			return int(e.get("商道") if "商道" in e else 0)
		"名望":
			return int(e.get("名望") if "名望" in e else 0)
	return int(e.get("战力") if "战力" in e else 0)
func _玄榜_按值降(a: Dictionary, b: Dictionary) -> bool:

	return int(a.get("值") if "值" in a else 0) > int(b.get("值") if "值" in b else 0)
func _裁剪到范(带榜: Array, n: int) -> Array:

	if 带榜.size() <= n:
		return 带榜
	var 自己或: Dictionary = {}
	var 含自己: bool = false
	for e in 带榜:
		if e.get("自己") if "自己" in e else false:
			自己或= e
			含自己= true
			break
	var 裁剪: Array = 带榜.slice(0, n)
	if 含自己 and not 裁剪.has(自己或):
		裁剪.append(自己或)
	return 裁剪
func _宗门总战() -> int:

	var s: int = 0
	for d in 弟子列表:
		if d != null:
			s += int(d.战力)
	return s
func _宗主境界() -> int:

	var mx: int = 0
	for d in 弟子列表:
		if d != null:
			var 境界顺序: Array = ["练气", "筑基", "金丹", "元婴", "化神", "仙阶", "道阶"]
			var idx: int = 境界顺序.find(d.境界)
			if idx > mx:
				mx = idx
	return mx
func _宗主战力() -> int:

	var mx: int = 0
	for d in 弟子列表:
		if d != null:
			if int(d.战力) > mx:
				mx = int(d.战力)
	return mx + 门派等级 * 500
func 取玄榜_self(类型: String, 指标: String, 范围: String) -> Dictionary:

	var 榜: Array = 取玄榜(类型, 指标, 范围)
	var rank: int = 0
	var val: int = 0
	for i in range(榜.size()):
		if 榜[i].get("自己", false):
			rank = i + 1
			val = int(榜[i].get("境界值", 0))
			break
	var gap: int = 0
	if rank > 1 and 榜.size() >= rank:
		gap = int(榜[rank - 2].get("境界值", 0)) - val
	var name: String = "%s（你方）" % 宗门名
	if 类型 == "个人":
		name = "%s·%s（你方）" % [宗门名, 宗主名]
	return {"rank": rank, "name": name, "val": val, "gap": gap}
# 解锁付费轨（对外「法旨特赏轨」）：扣非绑定仙玉，标记已购
# TODO S2 重构：迁移至 BattlePassManager.购付费轨()
func 购战令付费轨() -> Dictionary:

	if 战令_已购付费轨:
		return {"ok": false, "msg": "付费轨已解锁"}
	var 价: int = BattlePass.付费轨价
	if 仙玉_非绑定 < 价:
		return {"ok": false, "msg": "非绑定仙玉不足（需 %d）" % 价}
	仙玉_非绑定 -= 价
	战令_已购付费轨 = true
	return {"ok": true, "msg": "付费轨已解锁：%d 仙玉" % 价}
# 购买仙玉商店商品：6 屏坊市）：扣非绑定仙玉，按商：rewards 发放资源/皮肤名
# 属于 S1 竖切验证，数：PLACEHOLDER；S2 可随商业化矩阵拆分至 CommerceManager：
func 购买仙玉商品(商品id: String) -> Dictionary:

	var 商品: Dictionary = XianyuShop.取商品(商品id)
	if 商品.is_empty():
		return {"ok": false, "msg": "无此商品"}
	var 价: int = int(商品.get("price", 0))
	if 仙玉_非绑定 < 价:
		return {"ok": false, "msg": "仙玉不足（需 %d）" % 价}
	仙玉_非绑定 -= 价
	var 明细: Array = []
	var 奖: Dictionary = 商品.get("rewards", {})
	if 奖.has("灵石"):
		var v: int = int(奖["灵石"])
		灵石 += v
		明细.append("灵石+%d" % v)
	if 奖.has("灵气"):
		var v: int = int(奖["灵气"])
		灵气 += v
		明细.append("灵气+%d" % v)
	if 奖.has("灵草"):
		var v: int = int(奖["灵草"])
		灵草 += v
		明细.append("灵草+%d" % v)
	if 奖.has("矿石"):
		var v: int = int(奖["矿石"])
		矿石 += v
		明细.append("矿石+%d" % v)
	if 奖.has("声望"):
		var v: int = int(奖["声望"])
		声望 += v
		明细.append("声望+%d" % v)
	if 奖.has("绑定仙玉"):
		var v: int = int(奖["绑定仙玉"])
		仙玉_绑定 += v
		明细.append("绑定仙玉+%d" % v)
	if 奖.has("皮肤"):
		var skin_id: String = str(奖["皮肤"])
		当前皮肤 = skin_id
		明细.append("外观·%s" % skin_id)
	# 碎片奖励：以"frag_"开头的键
	for 键 in 奖.keys():
		if str(键).begins_with("frag_"):
			var v: int = int(奖[键])
			添加碎片(str(键), v)
			明细.append("%s+%d" % [str(键), v])
	# 宝箱奖励：以"chest_"开头的键
	for 键 in 奖.keys():
		if str(键).begins_with("chest_"):
			var v: int = int(奖[键])
			添加宝箱(str(键), v)
			明细.append("%s+%d" % [str(键), v])
	if 明细.is_empty():
		明细.append("已购：%s" % 商品.get("name", ""))
	return {"ok": true, "msg": "购入 %s：消耗 %d 仙玉，获得 %s" % [商品.get("name", ""), 价, "·".join(明细)]}
# ============ 仙玉通用接口（供皮肤商店/抽奖等系统调用）============
func 取仙玉() -> int:

	return 仙玉_绑定 + 仙玉_非绑定
# 消耗仙玉：优先扣绑定仙玉，不足部分扣非绑定；返回是否成功
func 消耗仙玉(数量: int) -> bool:

	if 数量 <= 0:
		return true
	var 总额: int = 仙玉_绑定 + 仙玉_非绑定
	if 总额 < 数量:
		return false
	var 剩余: int = 数量
	# 优先扣绑定
	var 扣绑玉: int = min(仙玉_绑定, 剩余)
	仙玉_绑定 -= 扣绑玉
	剩余 -= 扣绑玉
	# 不足扣非绑定
	if 剩余 > 0:
		仙玉_非绑定-= 剩余
	return true
# 消耗仙玉_付费：仅扣非绑定仙玉（付费专用，隔离免费绑定币）；不足返回 false
func 消耗仙玉_付费(数量: int) -> bool:
	if 数量 <= 0:
		return true
	if 仙玉_非绑定 < 数量:
		return false
	仙玉_非绑定 -= 数量
	return true
# ============ S0 日常差事（极简版：固定3：日）============
# ============ S1-2 任务条件计数器 ============
# 埋点唯一入口：所有可计数行为都调这里，禁止在业务处直接改 日常计数/周常计数。
# 参数：类型 = condition_type；参数 = condition_param（可空）；增量 = 累加值
func 记任务进度(类型: String, 参数: String = "", 增量: int = 1) -> void:
	if 类型 == "":
		return
	日常计数[类型] = int(日常计数.get(类型, 0)) + 增量
	周常计数[类型] = int(周常计数.get(类型, 0)) + 增量
	if 参数 != "":
		var 带参键: String = "%s:%s" % [类型, 参数]
		日常计数[带参键] = int(日常计数.get(带参键, 0)) + 增量
		周常计数[带参键] = int(周常计数.get(带参键, 0)) + 增量

# 取某条任务在指定计数器下的当前进度
func _任务当前进(q: Dictionary, 计数: Dictionary) -> int:
	var 类型: String = str(q.get("condition_type") if "condition_type" in q else "")
	if 类型 == "":
		return 0
	var 参数: String = str(q.get("condition_param") if "condition_param" in q else "")
	var 键: String = "%s:%s" % [类型, 参数] if 参数 != "" else 类型
	return int(计数.get(键, 0))

# 日常任务列表（带三态：进行中 in_progress / 可领取 claimable / 已领取 done）
func 取日常任务列表() -> Array:
	var out: Array = []
	for i in 当前日常.size():
		var q: Dictionary = 当前日常[i]
		var 目标: int = int(float(q.get("target_num") if "target_num" in q else 1))
		var 当前: int = _任务当前进(q, 日常计数)
		var 已领: bool = bool(日常已领[i]) if i < 日常已领.size() else false
		out.append({"id": str(q.get("quest_id") if "quest_id" in q else ""),
			"name": str(q.get("quest_name") if "quest_name" in q else ""),
			"desc": str(q.get("target_desc") if "target_desc" in q else ""),
			"target": 目标, "current": 当前, "index": i, "state": _任务状态(已领, 当前, 目标)})
	return out

# 周常任务（当前仅 1 条，故返回单体字典；state 语义同日常）
func 取周常任务() -> Dictionary:
	if 当前周常.is_empty():
		return {}
	var 目标: int = int(float(当前周常.get("target_num") if "target_num" in 当前周常 else 1))
	var 当前: int = _任务当前进(当前周常, 周常计数)
	return {"id": str(当前周常.get("quest_id") if "quest_id" in 当前周常 else ""),
		"name": str(当前周常.get("quest_name") if "quest_name" in 当前周常 else ""),
		"desc": str(当前周常.get("target_desc") if "target_desc" in 当前周常 else ""),
		"target": 目标, "current": 当前, "state": _任务状态(周常已领, 当前, 目标)}

func _任务状态(已领: bool, 当前: int, 目标: int) -> String:
	if 已领:
		return "done"
	return "claimable" if 当前 >= 目标 else "in_progress"

func 刷新日常差事():

	日常计数 = {}
	var 表: Array = []
	for r in DestinyDataLoader._read_csv("res://config/quest_daily.csv"):
		if int(r.get("unlock_sect_level") if "unlock_sect_level" in r else "1") <= 门派等级:
			表.append(r)
		if r.get("is_newbie") if "is_newbie" in r else "" == "true":
			continue
	表.shuffle()
	当前日常 = 表.slice(0, min(3, 表.size()))
	日常已领 = []
	for i in 当前日常.size():
		日常已领.append(false)
	上次日常真实秒 = int(Time.get_unix_time_from_system())
func 领取日常(序号: int) -> Dictionary:

	if 序号 < 0 or 序号 >= 当前日常.size():
		return {"ok": false, "msg": "差事不存在"}
	if 日常已领[序号]:
		return {"ok": false, "msg": "已领取"}
	var q: Dictionary = 当前日常[序号]
	# S1-2 完成判定：未达成 target_num 不可领取（此前点击即发奖）
	var 目标: int = int(float(q.get("target_num") if "target_num" in q else 1))
	var 当前: int = _任务当前进(q, 日常计数)
	if 当前 < 目标:
		return {"ok": false, "msg": "尚未达成（%d/%d）" % [当前, 目标]}
	# 阵营任务进度更新：完成日常任务可视为各阵营日常任务的一种
	# （S1-2：由函数入口移至「判定通过后」，避免领取失败仍推进阵营进度）
	更新阵营任务进度("正道宗门", "daily", 1)
	更新阵营任务进度("魔道邪宗", "daily", 1)
	更新阵营任务进度("中立散修", "daily", 1)
	更新阵营任务进度("上古妖兽", "daily", 1)
	更新阵营任务进度("远古遗泽", "daily", 1)
	var 奖: int = int(float(q.get("reward_lingjing") if "reward_lingjing" in q else "0") * 差事赏赐系数())
	var 额: int = int(float(q.get("reward_lingqi") if "reward_lingqi" in q else "0") * 差事赏赐系数())
	灵石 += 奖
	灵气 += 额
	日常已领[序号] = true
	增加战令经验(10)   # 功绩值+10（每日完成全部日常合计）
	_新手_检查条件("collect_income")
	# 日常任务额外奖励：10%概率获得凡品装备碎片，5%概率获得普通宝箱
	var 额外奖励文本: String = ""
	if randf() < 0.10:
		添加碎片("frag_equip_common", 1)
		额外奖励文本 += " 凡品装备碎片+1"
	if randf() < 0.05:
		添加宝箱("chest_common", 1)
		额外奖励文本 += " 普通宝箱+1"
	return {"ok": true, "msg": "日常「%s」完成：灵石+%d 灵气+%d%s" % [q.get("quest_name") if "quest_name" in q else "", 奖, 额, 额外奖励文本]}
# ============ S0 周常（轻量：：：条）============
func 刷新周常():

	周常计数 = {}
	var 表: Array = []
	for r in DestinyDataLoader._read_csv("res://config/quest_weekly.csv"):
		if int(r.get("unlock_sect_level") if "unlock_sect_level" in r else "1") <= 门派等级:
			表.append(r)
	if 表.is_empty():
		当前周常 = {}
		周常已领 = true
		return
	表.shuffle()
	当前周常 = 表[0]
	周常已领 = false
	上次周常真实秒 = int(Time.get_unix_time_from_system())
	刷新坊市上架()   # 周刷新同步更新坊市上架（：日）
func 领取周常() -> Dictionary:

	if 当前周常.is_empty():
		return {"ok": false, "msg": "本周无周常"}
	if 周常已领:
		return {"ok": false, "msg": "已领取"}
	# S1-2 完成判定：未达成 target_num 不可领取
	var 目标: int = int(float(当前周常.get("target_num") if "target_num" in 当前周常 else 1))
	var 当前: int = _任务当前进(当前周常, 周常计数)
	if 当前 < 目标:
		return {"ok": false, "msg": "尚未达成（%d/%d）" % [当前, 目标]}
	var 奖: int = int(float(当前周常.get("reward_lingjing", "0")) * 差事赏赐系数())
	var 额: int = int(float(当前周常.get("reward_lingqi", "0")) * 差事赏赐系数())
	灵石 += 奖
	灵气 += 额
	周常已领 = true
	增加战令经验(30)   # 功绩值+30（每周完成全部周常合计）
	# 周常任务额外奖励：30%概率获得灵品装备碎片，20%概率获得稀有宝箱，10%概率获得宝品功法碎片
	var 额外奖励文本: String = ""
	if randf() < 0.30:
		添加碎片("frag_equip_rare", 1)
		额外奖励文本 += " 灵品装备碎片+1"
	if randf() < 0.20:
		添加宝箱("chest_rare", 1)
		额外奖励文本 += " 稀有宝箱+1"
	if randf() < 0.10:
		添加碎片("frag_gongfa_rare", 1)
		额外奖励文本 += " 灵品功法碎片+1"
	return {"ok": true, "msg": "周常「%s」完成：灵石+%d 灵气+%d%s" % [当前周常.get("quest_name", ""), 奖, 额, 额外奖励文本]}
# ============ 主线任务（条件达成型：后端集中判：+ 线性解锁，前端只读状态）============
const 主线_境界序: Array= ["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体"]
# 主线任务列表（实时计算当前进度与状态，前端只读；判定全部收敛后端）
func 取主线任务列表() -> Array:

	var out: Array = []
	for q in DestinyDataLoader._read_csv("res://config/quest_main.csv"):
		if int(q.get("unlock_sect_level") if "unlock_sect_level" in q else "1") > 门派等级:
			continue
		var qid: String = str(q.get("quest_id") if "quest_id" in q else "")
		if not _主线已解锁(q):
			continue
		var target: int = int(float(q.get("target_num") if "target_num" in q else 1))
		var cur: int = _主线当前进(q)
		var done: bool = 主线已完成.has(qid)
		var claimable: bool = (not done) and (cur >= target)
		var state: String = "done" if done else ("claimable" if claimable else "in_progress")
		out.append({"id": qid, "name": str(q.get("quest_name") if "quest_name" in q else ""), "type": str(q.get("quest_type") if "quest_type" in q else ""),
			"desc": str(q.get("target_desc") if "target_desc" in q else ""), "target": target, "current": cur,
			"reward_lingjing": int(float(q.get("reward_lingjing") if "reward_lingjing" in q else "0")),
			"reward_lingqi": int(float(q.get("reward_lingqi") if "reward_lingqi" in q else "0")),
			"reward_shengwang": int(float(q.get("reward_shengwang") if "reward_shengwang" in q else "0")),
			"reward_caoyao": int(float(q.get("reward_caoyao") if "reward_caoyao" in q else "0")),
			"state": state, "is_key": str(q.get("is_key") if "is_key" in q else "false") == "true",
			"jump_path": str(q.get("jump_path") if "jump_path" in q else "")})
	return out
func _主线已解锁(q: Dictionary) -> bool:

	var prev: String = str(q.get("prev_quest_id") if "prev_quest_id" in q else "")
	if prev == "":
		return true
	return 主线已完成.has(prev)
func _主线当前进(q: Dictionary) -> int:

	var t: String = str(q.get("condition_type") if "condition_type" in q else "")
	var param: String = str(q.get("condition_param") if "condition_param" in q else "")
	match t:
		"sect_established": return 1
		"disciple_count": return 弟子列表.size()
		"realm_reach": return 1 if _存在达境界弟(param) else 0
		"shengwang": return int(声望)
		"sect_level": return int(门派等级)
		"array_count": return 已解锁单人法阵.size()
		"beast_count": return 灵兽库存.size()
		"secret_count": return 已通关秘境.size()
		"prosperity": return int(繁荣)
		_: return 0
func _存在达境界弟(境界名: String) -> bool:

	var 目标索引: int = Disciple.境界序.find(境界名)
	if 目标索引 < 0:
		return false
	for d in 弟子列表:
		var 弟子索引: int = Disciple.境界序.find(d.境界)
		if 弟子索引 >= 目标索引:
			return true
	return false
func 领取主线(quest_id: String) -> Dictionary:

	if 主线已完成.has(quest_id):
		return {"ok": false, "msg": "已完成"}
	var cfg: Dictionary = {}
	for q in DestinyDataLoader._read_csv("res://config/quest_main.csv"):
		if str(q.get("quest_id") if "quest_id" in q else "") == quest_id:
			cfg = q
			break
	if cfg.is_empty():
		return {"ok": false, "msg": "任务不存在"}
	if not _主线已解锁(cfg):
		return {"ok": false, "msg": "尚未解锁"}
	var target: int = int(float(cfg.get("target_num") if "target_num" in cfg else 1))
	var cur: int = _主线当前进(cfg)
	if cur < target:
		return {"ok": false, "msg": "条件未达成"}
	var 额灵石: int = int(float(cfg.get("reward_lingjing") if "reward_lingjing" in cfg else "0"))
	var 额灵气: int = int(float(cfg.get("reward_lingqi") if "reward_lingqi" in cfg else "0"))
	var 额声望: int = int(float(cfg.get("reward_shengwang") if "reward_shengwang" in cfg else "0"))
	var 额灵草: int = int(float(cfg.get("reward_caoyao") if "reward_caoyao" in cfg else "0"))
	灵石 += 额灵石
	灵气 += 额灵气
	_加声望(额声望)
	if 额声望 > 0:
		灵草 += 额灵草
	主线已完成.append(quest_id)
	if str(cfg.get("is_key") if "is_key" in cfg else "false") == "true":
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "主线达成",
			"文案": "宗门达成主线「%s」：%s，道途更进一层" % [cfg.get("quest_name") if "quest_name" in cfg else "", _主线奖励描述(cfg)],
			"category": "宗门大事件"})
	return {"ok": true, "msg": "主线「%s」完成：%s" % [cfg.get("quest_name") if "quest_name" in cfg else "", _主线奖励描述(cfg)]}
func _主线奖励描述(q: Dictionary) -> String:

	var parts: Array = []
	var 额灵石: int = int(float(q.get("reward_lingjing") if "reward_lingjing" in q else "0"))
	var 额灵气: int = int(float(q.get("reward_lingqi") if "reward_lingqi" in q else "0"))
	var 额声望: int = int(float(q.get("reward_shengwang") if "reward_shengwang" in q else "0"))
	var 额灵草: int = int(float(q.get("reward_caoyao") if "reward_caoyao" in q else "0"))
	if 额灵石 > 0: parts.append("灵石+%d" % 额灵石)
	if 额灵气 > 0: parts.append("灵气+%d" % 额灵气)
	if 额声望 > 0: parts.append("声望+%d" % 额声望)
	if 额灵草 > 0: parts.append("灵草+%d" % 额灵草)
	return "·".join(parts) if not parts.is_empty() else "宗门增益"
# 差事赏赐随门派等级线性缩放（每级+10%，上：倍），避免后期赏赐形同虚：
func 差事赏赐系数() -> float:

	return clamp(1.0 + (门派等级 - 1) * 0.1, 1.0, 3.0)
# ============ P0 目标链系统· 新手阶梯（混合主：自动，上一条完成才解锁下一条）============
# 配置来源：quest_daily.csv ：is_newbie==true ：7 行（newbie_001..007：
# 事件型条件（recruit_count / realm_first_enter / collect_income / event_first_trigger）由 5 处业务钩：
#   调用 _新手_检：条件) 触发完成；状态型条件（recruit_count_5 / disciple_realm_3 / disciple_realm_5：
#   ：_新手_评估后续() 依据当前状态预判，避免“死目标”：
func 激活新手目标链():

	if 新手目标链激活:
		return
	新手目标链激活= true
	_新手_评估后续()   # 解锁 newbie_001 并预检状态型条件是否已满：
func _新手_配置() -> Array:

	var 表: Array = []
	for r in DestinyDataLoader._read_csv("res://config/quest_daily.csv"):
		if r.get("is_newbie") if "is_newbie" in r else "" == "true":
			表.append(r)
	return 表
func _新手_已解锁(q: Dictionary) -> bool:

	var prev: String = q.get("prev_quest_id") if "prev_quest_id" in q else ""
	if prev == "" or prev == null:
		return true
	return 新手完成列表.has(prev)
func 新手_当前进行() -> Dictionary:

	# 首个未完成且已解锁的 newbie（供 UI 展示）；未激：全完成返：{}
	if not 新手目标链激活:
		return {}
	for q in _新手_配置():
		if 新手完成列表.has(q.get("quest_id") if "quest_id" in q else ""):
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
func _新手_检查条件(条件: String):

	# 事件型钩子入口：满足 条件 且已解锁&未完成的 newbie 立即完成（钩子本身即证据：
	if not 新手目标链激活:
		return
	for q in _新手_配置():
		var qid: String = q.get("quest_id") if "quest_id" in q else ""
		if 新手完成列表.has(qid):
			continue
		if not _新手_已解锁(q):
			continue
		if q.get("condition_type") if "condition_type" in q else "" != 条件:
			continue
		_新手_完成(q)
		return
func _新手_评估后续():

	# 状态型条件预检 + 链推进（解锁：每次完成后调用；可连续解锁多条）
	if not 新手目标链激活:
		return
	for q in _新手_配置():
		var qid: String = q.get("quest_id") if "quest_id" in q else ""
		if 新手完成列表.has(qid):
			continue
		if not _新手_已解锁(q):
			continue
		if _新手_条件满足(q):
			_新手_完成(q)
			return
func _新手_条件满足(q: Dictionary) -> bool:

	var 条件: String = q.get("condition_type") if "condition_type" in q else ""
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

	var qid: String = q.get("quest_id") if "quest_id" in q else ""
	if 新手完成列表.has(qid):
		return
	新手完成列表.append(qid)
	var 额灵石: int = int(float(q.get("reward_lingjing") if "reward_lingjing" in q else "0") * 差事赏赐系数())
	var 额灵气: int = int(float(q.get("reward_lingqi") if "reward_lingqi" in q else "0") * 差事赏赐系数())
	灵石 += 额灵石
	灵气 += 额灵气
	_新手_抽池(q.get("reward_pool_id") if "reward_pool_id" in q else "")
	宗门纪事.append({"日期": 累计游戏日, "稀有度": "琐事", "名称": "新手目标",
		"文案": 文案表["quest_newbie_done"] % [q.get("quest_name") if "quest_name" in q else "", 额灵石, 额灵气]})
	新手目标更新.emit()
	_新手_评估后续()   # 推进链（可能连续解锁多条状态型：
func _新手_抽池(pool_id: String):

	# P0 范围：仅结算可量化部分（灵石/气运）；材料/丹药：+灵石 折算为
	# 避免：宗门库房（Item 实例数组）写入非 Item 字典，破：save/load：
	if pool_id == "" or pool_id == null:
		return
	var 列表: Array = []
	for r in DestinyDataLoader._read_csv("res://config/quest_reward_pool.csv"):
		if r.get("pool_id") if "pool_id" in r else "" == pool_id:
			列表.append(r)
	if 列表.is_empty():
		return
	var 总权: float = 0.0
	for r in 列表:
		总权 += float(r.get("weight") if "weight" in r else "0")
	if 总权 <= 0:
		return
	var 抽值: float = randf() * 总权
	var 选中: Dictionary = {}
	for r in 列表:
		抽值 -= float(r.get("weight") if "weight" in r else "0")
		if 抽值 <= 0:
			选中 = r
			break
	var 名: String = 选中.get("item_name", "")
	灵石 += 20
# ============ S0 随机事件（轻量挂载：月度推演概率触发：===========
func _尝试随机事件():

	# S0 P0：月度从候选池按品阶权重抽1条（普：0/优秀20/稀有/传说2），同类：单事件双冷却
	var 候选: Array = []
	for r in DestinyDataLoader._read_csv("res://config/quest_random.csv"):
		if int(r.get("unlock_sect_level") if "unlock_sect_level" in r else "1") > 门派等级:
			continue
		var qid: String = r.get("quest_id") if "quest_id" in r else ""
		var 类型: String = r.get("quest_type") if "quest_type" in r else ""
		if 累计游戏日 - int(随机事件冷却.get(qid, -999)) < int(r.get("valid_time") if "valid_time" in r else "24"):
			continue
		if 累计游戏日 - int(随机事件类型冷却.get(类型, -999)) < 30:
			continue
		候选.append(r)
	if 候选.is_empty():
		return
	var 总权重: int = 0
	for r in 候选:
		总权重 += _随机事件权重(r.get("rarity") if "rarity" in r else "普")
	var 权: int = randi() % 总权重
	var 选中: Dictionary = 候选[0]
	for r in 候选:
		权 -= _随机事件权重(r.get("rarity") if "rarity" in r else "普")
		if 权 < 0:
			选中 = r
			break
	var 事件系数: float = _校准("随机事件赏赐系数", 1.8)
	var 奖灵石: int = int(int(选中.get("reward_lingjing", "0")) * 事件系数)
	var 奖灵气: int = int(int(选中.get("reward_lingqi", "0")) * 事件系数)
	灵石 += 奖灵石
	灵气 += 奖灵气
	随机事件冷却[选中.get("quest_id", "")] = 累计游戏日
	随机事件类型冷却[选中.get("quest_type", "")] = 累计游戏日
	宗门纪事.append({"日期": 累计游戏日, "稀有度": 选中.get("rarity", "普通"), "名称": 选中.get("quest_name", ""),
		"文案": 文案表["quest_random_done"] % [选中.get("quest_name", ""), 奖灵石, 奖灵气]})
	_新手_检查条件("event_first_trigger")
# 随机事件品阶权重（S0 P0：普：0/优秀20/稀有/传说2，对齐奇遇梯度）
func _随机事件权重(稀有度: String) -> int:

	var 日: Dictionary = {"普": 70, "优秀": 20, "稀有": 8, "传说": 2}
	var w: int = 日.get(稀有度, 20)
	# P3 气运：气运高→更好(优秀以上)事件权重提升，气运低→降低（普保持基线，确保总有事件）
	if 稀有度 != "普":
		w = int(w * (1.0 + 获取气运事件加成()))
	return max(1, w)
# ============ S0 差事系统日推进（挂于 推演一：累计游戏日+= ：之后：===========
func _推进差事系统():

	# 清理过期的奇遇防重复冷却（月份维度）
	var 月: int = _当前月()
	for k in quest_cooldown.keys():
		if 月 >= quest_cooldown[k]:
			quest_cooldown.erase(k)
	# 解耦：刷新判定改用真实时钟（现实秒），不再随游戏日飞快重置。
	#   86400s = 1 真实天；604800s = 1 真实周。当前日常/周常为空仍强制补刷（新档/损坏保护）。
	var 现在真实秒 := int(Time.get_unix_time_from_system())
	if 当前日常.is_empty() or (现在真实秒 - 上次日常真实秒 >= 86400):
		刷新日常差事()
	if 当前周常.is_empty() or (现在真实秒 - 上次周常真实秒 >= 604800):
		刷新周常()
	_尝试彩蛋奇遇("宗门")
	_尝试彩蛋奇遇("历练")
# ============ 彩蛋系统（第一批）============
func _加载彩蛋配置():

	彩蛋配置表= DestinyDataLoader._read_csv("res://config/easter_egg_config.csv")
# WAVE-D #6：加：收藏图录分类.csv（plain UTF-8 ：BOM；DestinyDataLoader 不剥 BOM，故：BOM：
func _加载图录配置():

	图录配置 = DestinyDataLoader._read_csv("res://config/收藏图录分类.csv")
	for r in 图录配置:
		var 类别: String = r.get("类别") if "类别" in r else ""
		if 类别 != "" and not 收藏图录_已收集.has(类别):
			收藏图录_已收集[类别] = []
# WAVE-D #8：加：宗门里程：csv（触发类型 事件/阈：状态）
func _加载里程碑配置():

	里程碑配置 = DestinyDataLoader._read_csv("res://config/宗门里程碑.csv")
	for m in 里程碑配置:
		m["已达成"] = 里程碑_已达成.has(m.get("里程碑ID") if "里程碑ID" in m else "")
# S1 ：：加：成就配置.csv（condition_type 13 枚举 + condition_param ：int 阈值+ condition_extra 复合条件：
# 范式：_加载里程碑配：完全一致；缺失文件不崩（_read_csv 内部 push_warning 并返回空：
func _加载成就配置():

	成就配置 = DestinyDataLoader._read_csv("res://config/achievement_config.csv")
	for a in 成就配置:
		a["已达成"] = 成就_已达成.has(a.get("achievement_id") if "achievement_id" in a else "")
# ============ 节奏校准（双周期评级配套：招：随机事件/奇遇/稳固：瓶颈打磨：===========
# 全配置化：参数集中在 config/节奏校准.csv；缺失文件或缺失行时回落到各调用点的默认值，绝不崩：
func _加载节奏校准():

	if 节奏校准.size() > 0:
		return
	节奏校准 = {}
	for 路径 in ["res://config/节奏校准.csv", "res://config/评级节奏.csv"]:
		for r in DestinyDataLoader._read_csv(路径):
			节奏校准[r.get("参数") if "参数" in r else ""] = r.get("值") if "值" in r else ""
# ============ S1 ：-A：宗门大阵配置表（array_config.csv：===========
# 范式：复：DestinyDataLoader._read_csv（与 _加载彩蛋配置/_加载节奏校准 同款）：
# 解析：阵法配置表[array_id] = {各列}，供 _宗门大阵修炼乘区 / 防御等效 / UI 读取：
# 缺失文件/缺行不崩（_read_csv 内部 push_warning 并返回空），：CSV 热更重读：
func _加载阵法配置_S1():

	阵法配置表.clear()
	for r in DestinyDataLoader._read_csv("res://config/array_config.csv"):
		var id: String = r.get("array_id") if "array_id" in r else ""
		if id != "":
			阵法配置表[id] = r
# ============ S1 ：-D5：阵法物品表（array_items.csv：===========
# ：_加载阵法配置_S1 同款范式；背：Item 仅携：名称（_掉落转物：不写 item_id），
# 故同时建 名称→行 索引；阵法_按阵：供面板提示「需使用 X 阵图解锁」。缺失文件不崩：
func _加载阵法物品_S1():

	阵法物品表.clear()
	阵法物品名表.clear()
	阵法_按阵法.clear()
	for r in DestinyDataLoader._read_csv("res://config/array_items.csv"):
		var id: String = r.get("item_id") if "item_id" in r else ""
		if id != "":
			阵法物品表[id] = r
			var nm: String = r.get("item_name") if "item_name" in r else ""
			if nm != "":
				阵法物品名表[nm] = r
			var ua: String = r.get("unlock_array_id") if "unlock_array_id" in r else ""
			if ua != "":
				阵法_按阵法[ua] = nm
# ============ S1 ：-D5：阵图解锁闭：helper（背包扣：获得 + 数值计算）============
# 纯经：配置读取，零触碰战斗核心（BattleCalculator/BattleManager 未引用本组函数）：
# 弟子是否已解锁某单人法阵（按 姓名 索引；新弟子缺键 ：默认未解锁，零回归）
func _弟子已解锁法阵(姓名: String, aid: String) -> bool:

	return 已解锁单人法阵.get(姓名, []).has(aid)
# 解锁某弟子单人法阵（幂等：
func _解锁弟子法阵(姓名: String, aid: String):

	if not 已解锁单人法阵.has(姓名):
		已解锁单人法阵[姓名] = []
	if not 已解锁单人法阵[姓名].has(aid):
		已解锁单人法阵[姓名].append(aid)
# 升到下一级所需阵纹碎片：cost_base × cost_growth^(当前：1)，向上取整，下限 1
func _阵法升级消耗(aid: String, 当前等级: int) -> int:

	var cfg: Dictionary = 阵法配置表.get(aid, {})
	var base: float = float(cfg.get("cost_base") if "cost_base" in cfg else 5)
	var growth: float = float(cfg.get("cost_growth") if "cost_growth" in cfg else 1.3)
	return max(1, int(ceil(base * pow(growth, 当前等级- 1))))
# ：1 级升：至级 的累计消耗（拆解返还按此测算：
func _阵法升级总耗(aid: String, 至级: int) -> int:

	var 费: int = 0
	for lv in range(1, max(1, 至级)):
		费 += _阵法升级消耗(aid, lv)
	return 费
# 拆解返还阵纹碎片数（按阵阶梯度：凡阶40%/灵阶50%/宝阶60% + 阶别保底；数值平衡待 design-strategist 确认：
func _阵法拆解返还数(aid: String, 当前等级: int) -> int:

	var cfg: Dictionary = 阵法配置表.get(aid, {})
	var 比例: float = 0.40
	var 阶底: int = 3
	match cfg.get("rank") if "rank" in cfg else "common":
		"spirit":
			比例= 0.50
			阶底 = 6
		"treasure":
			比例= 0.60
			阶底 = 8
		_:
			比例= 0.40
			阶底 = 3
	var 投入: int = _阵法升级总耗(aid, 当前等级)
	if 当前等级< 1 or 投入 <= 0:
		return 0
	return int(floor(投入 * 比例)) + 阶底
# 统计弟子背包内阵纹碎片（item_015，名：阵纹碎片）数：
func _统计阵纹碎片(d: Disciple) -> int:

	var n: int = 0
	for it in d.背包:
		if it != null and it.名称 == "阵纹碎片":
			n += 1
	return n
# 扣除弟子背包内阵纹碎：n 个；不足返回 false（不扣）
func _扣除阵纹碎片(d: Disciple, n: int) -> bool:

	if n <= 0:
		return true
	if _统计阵纹碎片(d) < n:
		return false
	var 余: int = n
	for i in range(d.背包.size() - 1, -1, -1):
		var it = d.背包[i]
		if it != null and it.名称 == "阵纹碎片":
			d.背包.remove_at(i)
			余-= 1
			if 余<= 0:
				break
	return true
# 发放 n 个阵纹碎片到弟子背包（经统一掉落工厂，保类别/穿戴位一致）
func _发放阵纹碎片(d: Disciple, n: int):

	for _k in range(n):
		var it: Item = _掉落转物品({"item_id": "item_015", "item_name": "阵纹碎片", "quality": "凡品"})
		d.背包.append(it)
# 类型化读取（CSV 存为字符串，按调用点需要解析）：缺：空值回落默认，保证安全
func _校准(参数: String, 默认: float) -> float:

	var s: String = 节奏校准.get(参数, "")
	if s == "":
		return 默认
	return float(s)
func _校准开(参数: String, 默认: bool) -> bool:

	var s: String = 节奏校准.get(参数, "")
	if s == "":
		return 默认
	return s in ["1", "true", "True", "TRUE", "yes", "YES"]
func _彩蛋配置(egg_id: String) -> Dictionary:

	for r in 彩蛋配置表:
		if r.get("egg_id") if "egg_id" in r else "" == egg_id:
			return r
	return {}
func 彩蛋启用中(egg_id: String) -> bool:

	if not 彩蛋启用:
		return false
	if 彩蛋屏蔽表.has(egg_id):
		return false
	var c: Dictionary = _彩蛋配置(egg_id)
	if c.is_empty() or c.get("enabled") if "enabled" in c else "true" != "true":
		return false
	return true
# 统一发放彩蛋赏赐（仅宗门资源，不依赖弟子对象；零破坏核心：
func _发放彩蛋赏赐(reward: String, 数量: int):

	match reward:
		"lingshi": 灵石 += 数量
		"lingcao": 灵草 += 数量
		"kuangshi": 矿石 += 数量
		"lingqi": 灵气 += 数量
		_: pass
# 触发点击类彩蛋（main.gd UI 钩子调用）：写异闻纪：+ 发赏：+ 置临时增益
func 触发点击彩蛋(egg_id: String):

	if not 彩蛋启用中(egg_id):
		return
	var c: Dictionary = _彩蛋配置(egg_id)
	var 名称: String = c.get("name") if "name" in c else "无名彩蛋"
	var 文案: String = c.get("text") if "text" in c else ""
	宗门纪事.append({"日期": 累计游戏日, "稀有度": "异闻", "名称": 名称, "文案": 文案, "category": "异闻"})
	var rw: String = c.get("reward") if "reward" in c else "none"
	var rn: int = int(c.get("reward_num") if "reward_num" in c else "0")
	if rw != "none" and rn > 0:
		_发放彩蛋赏赐(rw, rn)
	_置彩蛋临时增益(c)
# 奇遇类彩蛋（独立：event_quest.csv，仅复用纪事写入+赏赐helper，杜绝污染奇遇池：
func _尝试彩蛋奇遇(scene: String):

	if 彩蛋配置表.is_empty():
		return
	var 候选: Array = []
	for r in 彩蛋配置表:
		if r.get("type") if "type" in r else "" != "quest":
			continue
		if r.get("trigger_param") if "trigger_param" in r else "" != scene:
			continue
		if not 彩蛋启用中(r.get("egg_id") if "egg_id" in r else ""):
			continue
		候选.append(r)
	if 候选.is_empty():
		return
	if randf() >= 0.03:
		return
	var 选中: Dictionary = 候选[randi() % 候选.size()]
	触发点击彩蛋(选中.get("egg_id", ""))
# 置临时增益（当日生效；dim=：则无数值）
func _置彩蛋临时增益(c: Dictionary):

	var dim: String = c.get("buff_dim") if "buff_dim" in c else ""
	var pct: float = float(c.get("buff_pct") if "buff_pct" in c else "0") / 100.0
	if dim == "" or pct <= 0:
		return
	彩蛋临时增益[dim] = {"pct": pct, "到期日": 累计游戏日 + 1}
# 运行时加法管线（接入产出/修炼计算，封顶单上限兜底：
func 彩蛋产出加成() -> float:

	var g: Dictionary = 彩蛋临时增益.get("产出", {})
	if g.is_empty() or g.get("到期日") if "到期日" in g else 0 < 累计游戏日:
		return 0.0
	return min(g.get("pct") if "pct" in g else 0.0, 彩蛋单上限)
func 彩蛋修炼加成() -> float:

	var g: Dictionary = 彩蛋临时增益.get("修炼", {})
	if g.is_empty() or g.get("到期日") if "到期日" in g else 0 < 累计游戏日:
		return 0.0
	return min(g.get("pct") if "pct" in g else 0.0, 彩蛋单上限)
func 推演至现在() -> String:

	推演日志.clear()
	# 资源快照（用于总览展示"本次收益"，展示型领取不二次发资源：
	var 灵石快照 := 灵石
	# 解锁道途池随门派等级更新（供筑基判定道途使用）
	Disciple.解锁道途池 = 已解锁道途()
	var 现在: int = int(Time.get_unix_time_from_system())
	if 最后登录<= 0:
		最后登录= 现在
	var 流逝秒: int = 现在 - 最后登录
	var 流失日: int = int(流逝秒 / 现实秒每游戏日)
	流失日 = clamp(流失日, 0, 单次推演上限日)
	var 剩余 := 流失日
	while 剩余 > 0:
		var 数: int = min(30, 剩余)
		推演一月(数)
		剩余 -= 数
	最后登录= 现在
	if 流失日 == 0:
		_加推演条目("（本次登录无时间流逝，直接进入。）", ET_INFO, PRIO_TRIVIAL)
	弟子变动.emit()
	var 报: String = 生成结构化汇报(流失日, 灵石 - 灵石快照)
	战报更新.emit(报)
	return 报
# 设置全宗气运 buff（天品测：/ 天品突破共用：
# 规则1：同类取最高值生效，不叠加数值（：buff 不被：buff 覆盖：
# 规则2：同强度刷新持续时长，不累加时间（以当前日期为基准取更晚到期，避免弱 buff 缩短：buff 时长：
func 设置气运buff(修炼值: float, 产出值: float, 天数: int):

	气运修炼加成 = max(气运修炼加成, 修炼值)
	气运产出加成 = max(气运产出加成, 产出值)
	气运到期日 = max(气运到期日, 累计游戏日 + 天数)
func 推演一月(月: int):

	天品突破播报 = ""
	# S2-3：香火/信徒月结产出（原 _结算香火_S1 空桩已实装）
	_结算香火_S1()
	# P1-3：体力部分恢复（原 S2-3 每月回满→约束失效；现每日回 60% 上限、封顶，成为有效行动闸门）
	体力 = min(体力上限(), 体力 + int(体力上限() * 0.6))
	# 招募冷却每日递减
	if 招募冷却剩余 > 0:
		招募冷却剩余 = max(0, 招募冷却剩余 - 1)
	# 全宗气运 buff 到期清除
	if 气运到期日 > 0 and 累计游戏日 >= 气运到期日:
		气运修炼加成 = 0.0
		气运产出加成 = 0.0
		气运到期日= 0
	# P1：宗门加成统一加法叠加，总上限+100%（：），杜绝乘性无限叠加（境界膨胀根因：
	var 灵脉加成pct: float = min(门派等级, 10) * 0.02
	if 累计游戏日< 气运到期日:
		灵脉加成pct += 气运修炼加成
	var 负责人修炼pct: float = 汇总负责人全局buff().get("修炼", 0.0)
	var 藏经阁pct: float = max(0.0, _藏经阁修炼乘区() - 1.0)
	var 大阵pct: float = max(0.0, _宗门大阵修炼乘区() - 1.0)
	var 宗门加成pct: float = clamp(灵脉加成pct + 负责人修炼pct + 藏经阁pct + 彩蛋修炼加成() + 大阵pct, 0.0, 1.0)
	var 修炼乘区: float = 1.0 + 宗门加成pct
	# 1. 弟子修炼 / 升层 / 突破 / 月度事件：0层体系双轨播报）
	var 待坐化: Array[Disciple] = []
	for d in 弟子列表:
		var 旧境界: String = d.境界
		var 旧层数: int = d.层数
		# 宗主管理系统：突破护法加成（金丹及以上境界突破时：
		var 护法乘区: float = 1.0
		if SectManager != null and d.境界 in ["筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫"]:
			var 护法加成 = SectManager.获取护法成功率加成(int(d.弟子ID))
			if 护法加成 > 0:
				护法乘区 = 1.0 + 护法加成
				SectManager.标记护法已处理(int(d.弟子ID))
		d.推进修炼(修炼乘区 * 护法乘区)
		var 新层数: int = d.层数
		# 突破播报（境界变化= 大事，高优先级）
		if d.境界 != 旧境界:
			周期评分.记突破()   # P1：突破计入周期评：
			# 成就统计：累计弟子突破次数自增
			累计弟子突破次数 += 1
			记任务进度("breakthrough")   # S1-2：弟子突破（自动产出，周常 weekly_001）
			_复检成就()
			_加推演条目("【%s】道心通明，突破至 %s" % [d.姓名, d.境界], ET_BREAKTHROUGH, PRIO_HIGH, {"弟子": d.姓名, "境界": d.境界})
			# 宗主管理系统：突破大境界时触发护法事件记录（金丹及以上）
			if d.境界 in ["金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫"] and SectManager != null:
				SectManager.请求突破护法(int(d.弟子ID), d.境界)
			# 天品灵根弟子突破 ：仪式感
			if d.灵根品阶 == "天品":
				宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": "天品", "名称": "天品突破", "文案": 文案表["chronicle_tianpin_breakthrough"] % [d.姓名, d.境界]})
				设置气运buff(0.02, 0.01, 3)
				天品突破播报 += "：s】突破至%s\n" % [d.姓名, d.境界]
			if d.司职 != "":
				_注册入堂(d)
				if d.道途!= "":
					_加推演条目("【%s】入【%s】，任%s" % [d.姓名, Lore.取司职(d.司职)["名称"], d.道途], ET_APPOINT, PRIO_NORMAL, {"弟子": d.姓名, "司职": d.司职, "道途": d.道途})
		# 升层播报（仅境界未变时；大圆满或：层节点，避免刷屏：
		elif 新层数 > 旧层数 and d.境界 == 旧境界:
			if 新层数>= 10 and 旧层数< 10:
				_加推演条目(文案表["deduce_cultivation_great"] % [d.姓名, d.境界], ET_BREAKTHROUGH, PRIO_NORMAL, {"弟子": d.姓名, "境界": d.境界})
			elif 新层数% 5 == 0 or (新层数>= 7 and 旧层数< 7):
				_加推演条目("【%s】修为精进，升至%s%d层" % [d.姓名, d.境界, 新层数], ET_BREAKTHROUGH, PRIO_TRIVIAL, {"弟子": d.姓名})
		var 事件: String = _弟子月度事件(d)
		# D5：机缘钩子：月度推演独立滚动（绕开 _今日奇遇次数 日配额），得赏赐则并入推演日：
		var 机缘文案: String = _尝试机缘(d)
		if 机缘文案 != "":
			_加推演条目(机缘文案, ET_QUEST, PRIO_NORMAL, {"弟子": d.姓名, "机缘": true})
		if 事件 != "":
			# 智能分类：无功而返→trivial / 得稀有道具→high / 其他→normal
			var 优先级:= PRIO_NORMAL
			var 类型 := ET_QUEST
			if "无功而返" in 事件:
				优先级= PRIO_TRIVIAL
			elif "得" in 事件 and ("极品" in 事件 or "特殊" in 事件):
				优先级= PRIO_HIGH
				类型 = ET_LOOT
			elif "大有所获" in 事件:
				类型 = ET_QUEST
			_加推演条目(事件, 类型, 优先级, {"弟子": d.姓名})
		# 宗主管理系统：随机触发戒律违规和弟子请示事件（每月约5%概率表
		if SectManager != null and randf() < 0.05 and not 弟子列表.is_empty():
			var 随机弟子 = 弟子列表[randi() % 弟子列表.size()]
			if 随机弟子 != null:
				var 违规类型列表 = SectManager.违规类型.keys()
				var 随机违规 = 违规类型列表[randi() % 违规类型列表.size()]
				SectManager.上报违规(int(随机弟子.弟子ID), 随机违规, "弟子" + str(随机弟子.姓名) + "被发现违反宗门戒律：" + 随机违规)
				_加推演条目("【%s】违反宗门戒律：%s，待宗主裁决" % [随机弟子.姓名, 随机违规], ET_INFO, PRIO_NORMAL, {"弟子": 随机弟子.姓名})
		if SectManager != null and randf() < 0.08 and not 弟子列表.is_empty():
			var 随机弟子 = 弟子列表[randi() % 弟子列表.size()]
			if 随机弟子 != null:
				var 请示类型列表 = SectManager.请示类型.keys()
				var 随机请示 = 请示类型列表[randi() % 请示类型列表.size()]
				SectManager.发起请示(int(随机弟子.弟子ID), 随机请示, {"内容": "弟子" + str(随机弟子.姓名) + "前来请示：" + 随机请示})
				_加推演条目("【%s】前来请示宗主：%s" % [随机弟子.姓名, 随机请示], ET_INFO, PRIO_NORMAL, {"弟子": 随机弟子.姓名})
		# 终局机制 P0：寿元坐化——年龄达当前境界寿元上限则标记，循环后统一处理（移：归还+纪事：
		if d.年龄 >= d.寿元:
			待坐化.append(d)
	_新手_评估后续()   # 状态型 newbie（弟子层数达标）月内预判
	# 2. 资源殿阁产出
	处理坐化(待坐化)   # P0 终局：寿元耗尽弟子离场（灵：装备归还宗门、纪事入册）
	_资源殿阁产出()
	# P2-12：殿阁产出感知（缓解「产出感知弱」；把本周期殿阁真实产出写入纪事，玩家回看推演日志可见 +N）
	if _本月灵田产出 > 0 or _本月矿脉产出 > 0 or _本月丹堂产出 > 0 or _本月器殿产出 > 0:
		添加纪事("庶务", "殿阁产出", "灵田+%d 灵草｜矿脉+%d 矿石｜丹堂+%d｜器殿+%d" % [_本月灵田产出, _本月矿脉产出, _本月丹堂产出, _本月器殿产出], 0)
	# 藏经阁月度悟道点产出
	var 藏经阁等级: int = 1
	if 司职列表.has("cangjing"):
		藏经阁等级= int(司职列表["cangjing"].get("等级", 1))
	var 月产出 = GongFaSystem.计算月产出(藏经阁等级)
	悟道点 += 月产出
	# 灵气月度产出（基于宗门等：灵脉：
	var 灵气月产值= 50 + max(0, 门派等级 - 1) * 20
	灵气 += 灵气月产值
	_复检里程碑()   # WAVE-D #8：月度复检阈：状态里程碑（声：繁荣/弟子/灵兽/秘境增长：
	_复检成就()       # S1 ：：月度复检阈值成就（与里程碑同步触发：
	# S1 ：：任期政绩月度累积（须在主事在任、资源产出之后）
	_累计任期政绩()
	# 2.5 殿阁被动结算（阶：：每月概率事件；资源产出之后、推演条目汇总之前）
	_殿阁被动结算()
	# 3. 宗门事件（约每月一次）
	# S1 ：-A 端口：凡人事件池 config/凡人事件.csv 待建（权重接入本区；本批仅标端口，不写事件逻辑：
	# 宗主管理系统：随机触发宗门事务批阅（每月：0%概率表
	if SectManager != null and randf() < 0.1:
		var 事务类型列表 = ["弟子晋升申请", "资源调拨申请", "对外交涉文件", "殿阁扩建申请", "宗门庆典筹备"]
		var 随机事务 = 事务类型列表[randi() % 事务类型列表.size()]
		SectManager.提交事务批阅(随机事务, 随机事务, {"内容": "宗门事务：" + 随机事务 + "，待宗主批阅中"})
		_加推演条目("【宗门事务%s，待宗主批阅】" % 随机事务, ET_INFO, PRIO_NORMAL, {})
	if randf() < 0.5:
		记任务进度("event_first_trigger")   # S1-2：宗门事件自动发生（新手 newbie_004）
		_加推演条目("【宗门" + Lore.取宗门事件(), ET_SECT, PRIO_NORMAL)
		_加声望(5)
	# 4. 育英堂常驻自动招收（练气候补）：由原「月：30%」改为「季度触发」，基础概率 + 门派等级缩放
	#   按本次推演跨越的月份逐月判定，兼容：30/365/7 等不同粒度（度假式快进不漏触发）
	var 招徒周期: int = _校准("招徒周期", 3)
	var 招徒起月: int = int(累计游戏日/ 30)
	var 招徒止月: int = int((累计游戏日 + 月) / 30)
	for 招徒月 in range(招徒起月, 招徒止月):
		if 招徒月% 招徒周期 != 0:
			continue
		var 招徒概率: float = _校准("招徒基础概率", 0.75) + (门派等级 - 1) * _校准("招徒等级缩放", 0.02)
		招徒概率 = clamp(招徒概率, 0.0, _校准("招徒概率上限", 0.95))
		if randf() < 招徒概率:
			var n: int = 1 + (1 if randf() < 0.3 else 0)
			for i in n:
				var nd := Disciple.new()
				nd.司职 = "yuying"   # 育英堂候补
				弟子列表.append(nd)
	# 4.5 随机事件（半年触发，单次赏赐放大 系数 倍；原月度触发已移至此，按跨越月份逐月判定：
	var 事件周期: int = _校准("随机事件周期", 6)
	var 事件累计快照: int = 累计游戏日
	for 事件i in range(招徒起月, 招徒止月):
		if 事件i% 事件周期 != 0:
			continue
		累计游戏日 = 事件累计快照 + 事件i * 30   # 让冷：纪事落在对应月份，避免同刻冷却互相抵：
		_尝试随机事件()
	累计游戏日= 事件累计快照
	# 5. 御兽堂推进孵：
	推进孵化(月)
	处理兑换队列()        # T03：自动兑换队列周期执：
	出战灵兽月度养成()    # T13+T14：出战灵兽每：1：+2忠诚，库：1忠诚
	# 6. 更新门派
	更新门派()
	# === S1 扩展端口（当前空操作，S1 赛季实现；见 S1-S2功能储备与扩展端口清：md：==
	_结算俸禄_S1()            # 俸禄/福利按月发放，扣公库
	_结算运维成本_S1()        # D1 宗门运维成本（刚性耗），接：global_cost_rate 阀门
	_结算负面事件_S1()        # D3 负面影响经济侧（S1-P0 批次三）：negative_event.csv + 经济阀：csv neg_*
	_可能触发特殊登门_S1()    # 声望阈值→特殊弟子主动投奔
	_确保字派_S1()            # S1 ：-B：旧档首次进入自动生成字派序列并持久：
	_检查正邪解锁_S1()         # S1 ：-C：正邪路线解锁检测（空桩，当前仅读门派等：七载大考标记）
	_结算大阵耐久_S1()    # S1 ：-A：宗门大阵耐久月度结算（当前空桩，[PLACEHOLDER]：
	累计游戏日+= 1
	# 商队系统：每日更新商队状态，结算返回的商：
	更新商队状态()
	# 历练系统：检查并结算到期历练，每日重置日常，：日重置秘：
	if ExpeditionSystem != null:
		var 结算列表 = ExpeditionSystem.检查并结算历练()
		for 结果 in 结算列表:
			if 结果.get("成功", false):
				# S1-2 自动产出型埋点：历练由系统自动结算，玩家只做「派遣」配置
				var 关卡类型: String = str(结果.get("类型", ""))
				if 关卡类型 == "secret":
					记任务进度("clear_stage", "完整")     # 秘境通关·完整（周常 weekly_005 · condition_param=完整）
					记任务进度("clear_stage")            # 秘境通关（日常 daily_011 · 无参键）
				else:
					记任务进度("expedition")              # 野外/境界历练（日常 daily_003）
				_加推演条目("【历练：s 完成，评：s" % [结果.get("关卡名称",""), 结果.get("评级","")], ET_LOOT, PRIO_NORMAL)
			else:
				_加推演条目("【历练：s 失败" % 结果.get("关卡名称",""), ET_INFO, PRIO_TRIVIAL)
		ExpeditionSystem.每日重置()
		if 累计游戏日% 7 == 0:
			ExpeditionSystem.每周重置()
	_宗门集市_日推进(1)     # WAVE-C #7：宗门集市窗口进：退出刷新（仅刷新规则，零经济）
	_推进差事系统()        # S0：每日刷日常 / ：日刷周常 / 月度随机概率事件
	# P1：年结周期评分（游戏日= 365 日）；支持单次大跨度推演结算多年
	while (累计游戏日- 上次结算年>= 365):
		上次结算年+= 365
		_年结评分()
# P1：年结评分（：推演一月：365 日边界触发）
func _年结评分():

	var 当前总战力: int = 0
	for d in 弟子列表:
		当前总战力+= d.实时战力()
	var 局: Dictionary = 周期评分.结算(门派等级, {
		"资源产能": 预估月产出,
		"灵石增量": 灵石 - 年始灵石,
		"总战力增量": 当前总战力 - 年始总战力,
	})
	var 评级级: String = 局["评级"]
	var 评级: Dictionary = _发放周期赏赐(评级级)
	局["年度发"] = 评级["年度发"]
	局["入池"] = 评级["入池"]
	局["平移法宝"] = 评级["平移法宝"]
	最新周期评级卡 = 局
	# 岁末考评轻量纪事（归入「日常庶务」分类，保证每年成长可回溯）
	var 岁末评语: String = _七载大典文案(评级级).get("评语", "")
	宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "岁末考评",
		"文案": "岁末考评裁定 %sbs" % [评级级, 岁末评语], "category": "日常庶务"})
	年始灵石 = 灵石
	年始总战力= 当前总战力
	# 七载双周期：：2555 日（7×365）边界触发七载大考集中结：
	if _校准开("双周期评级启用", true):
		var 七载周期年: int = _校准("七载周期年", 7) * 365
		if 累计游戏日- 上次七载日>= 七载周期年:
			上次七载日= 累计游戏日
			_七载大考()
# P1：周期评定赏赐（梯度灵石 + S 级及以上追加上品法宝赐掌门）
# 双周期评级启用（默认）：年度发放 70%，剩：30% 平移入「七载赏赐池」于七载大典集中结算：
#   S 级及以上高阶法宝留待七载大典一次性赐下。全程零新增资源： 年总量 = 7 × 原年度）：
# 双周期评级关闭（回退）：维持原年度实时全额发放，行为与原版完全一致：
# 返回值供 UI 展示：{年度发 入池, 平移法宝}
func _发放周期赏赐(评级: String) -> Dictionary:

	var 灵石赏赐表: Dictionary = {"D": 0, "C": 200, "B": 500, "A": 1000, "A+": 1800, "S": 3000, "SS": 5000, "SSS": 8000}
	var 额: int = int(灵石赏赐表.get(评级, 0))
	if 额<= 0:
		return {"年度发": 0, "入池": 0, "平移法宝": false}
	var 等级平移: bool = 评级 in ["S", "SS", "SSS"]
	if not _校准开("双周期评级启用", true):
		# 回退：原年度实时全额发放
		灵石 += 额
		_加推演条目("【宗门】周期评：%s，论功行赏，灵石+%d： %s" % [评级, 额], ET_SECT, PRIO_NORMAL, {})
		if 等级平移 and not 弟子列表.is_empty():
			var 物: Item = _造低阶物品("fabao", "上品")
			弟子列表[0].背包.append(物)
			_加推演条目("【宗门】评：%s，赐掌门上品法宝：%s】" % [评级, 物.名称], ET_LOOT, PRIO_HIGH, {})
		return {"年度发": 0, "入池": 0, "平移法宝": 等级平移}
	# 双周期模式：年度 70% 即时 + 30% 入池；高阶法宝平移七：
	var 年度发: int = int(额* _校准("年度赏赐占比", 0.70))
	var 入池: int = 额- 年度发
	灵石 += 年度发
	_加推演条目(文案表["deduce_year_end_eval"] % [评级, 年度发, 入池], ET_SECT, PRIO_NORMAL, {})
	if 入池 > 0:
		七载赏赐池+= 入池
	if 等级平移 and not 弟子列表.is_empty():
		var 物: Item = _造低阶物品("fabao", "上品")
		七载待发掉落.append({"类型": 物.类别, "品阶": 物.品阶, "名称": 物.名称})
		_加推演条目("【宗门】评：%s，上品法宝：%s】" % [评级, 物.名称], ET_LOOT, PRIO_HIGH, {})
	return {"年度发": 年度发, "入池": 入池, "平移法宝": 等级平移}
# P1：七载大典集中结算（双周期评级核心）
# 一次性发：7 年累积的「七载赏赐池」（=7×30% 年度灵石： 历年平移的高阶法宝，
# 并将「门派等级目标」正式生效为门派等级。全程零新增资源：
# 七载大典 / 岁末考评 仪式文案（纯展示，零数值）。按评级：8 档差异化包装：
func _七载大典文案(评级: String) -> Dictionary:

	# WAVE-A #1：优先查 config/七载大典文案.csv（按评级匹配）；命中返回配置文案：
	# 缺档/缺文件回退硬编码默认文案（不报错、不崩溃）：
	var 配置: Dictionary = _七载大典文案表()
	if 配置.has(评级):
		return 配置[评级] as Dictionary
	return _七载大典文案_默认(评级)
# 懒加：七载大典文案.csv ：{评级: {标题,开：收尾,评语}}（缺文件/缺档不报错）
var _七载大典文案缓存: Dictionary = {}
var _七载大典文案已加载: bool= false
func _七载大典文案表() -> Dictionary:

	if _七载大典文案已加载:
		return _七载大典文案缓存
	_七载大典文案已加载= true
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
			"开：": parts[2].strip_edges(),
			"收尾": parts[3].strip_edges(),
			"评语": parts[4].strip_edges(),
		}
	return _七载大典文案缓存
# 硬编码默认文案（与七载大典文：csv 内容一致，作为回退；零数值）
func _七载大典文案_默认(评级: String) -> Dictionary:

	var 局: Dictionary = {
		"D":   {"标题": "七载考评·守拙", "开：": "根基尚浅，然守拙归真，来日方长", "收尾": "%d七载，宗门稳守本心，来年期可待", "评语": "岁末考评守拙，根基虽浅，来日方长"},
		"C":   {"标题": "七载考评·筑基", "开：": "百事初立，稳中有进，假以时日可期大成", "收尾": "%d七载，宗门筑基渐稳，来年再图进取", "评语": "岁末考评筑基，稳中有进，来年可期"},
		"B":   {"标题": "七载考评·兴业", "开：": "产业渐丰，弟子用命，宗门气象一新", "收尾": "%d七载，宗门兴业有成，道途愈宽", "评语": "岁末考评兴业，基业渐丰，气象一新"},
		"A":   {"标题": "七载考评·昌盛", "开：": "七载经营，宗门昌盛，灵脉日盛", "收尾": "%d七载，宗门昌盛绵延，声望渐起", "评语": "岁末考评昌盛，灵脉日盛，声望渐起"},
		"A+":   {"标题": "七载考评·隆盛", "开：": "贤才云集，基业隆盛，已具大宗气象", "收尾": "%d七载，宗门隆盛日彰，名动一方", "评语": "岁末考评隆盛，贤才云集，名动一方"},
		"S":   {"标题": "七载大考·宗门鼎盛", "开篇": "七载积淀，道基再固，宗门鼎盛，四海仰止", "收尾": "%d七载，宗门鼎盛，道途至此再进一步", "评语": "七载大考鼎盛，道基再固，四海仰止"},
		"SS":   {"标题": "七载大考·威震一方", "开篇": "七载砥砺，威震一方，诸宗来朝，灵脉通玄", "收尾": "%d七载，宗门威名远播，基业永固", "评语": "七载大考威震一方，诸宗来朝，基业永固"},
		"SSS":   {"标题": "七载大考·道途无双", "开篇": "七载问道，道途无双，太玄宗之名，响彻修真界", "收尾": "%d七载，太玄宗立不朽之基，万世流芳", "评语": "七载大考道途无双，太玄之名响彻修真界"},
	}
	return 局.get(评级, 局["C"])
func _七载大考():

	var 晋升: int = 门派等级目标 if 门派等级目标 > 门派等级 else 0
	var 大典灵石: int = 七载赏赐池
	var 大典法宝: int = 七载待发掉落.size()
	var 序号: int = int(累计游戏日/ (_校准("七载周期年", 7) * 365))
	var 评级: String = 最新周期评级卡.get("评级", "C")
	var 局: Dictionary = _七载大典文案(评级)
	# 基础纪事：每次七载必生成 1 条；S 级以上归「宗门大事件」，其余归「宗门岁纪：
	var 七载分类: String = "宗门大事件" if 评级 in ["S", "SS", "SSS"] else "宗门岁纪"
	宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "七载大考",
		"文案": 文案表["seven_year_ceremony_done"] % [序号, 评级],
		"category": 七载分类})
	# WAVE-C #3 R1：大典盛事专属纪事（填充「大典盛事」Tab，与 七载分类 纪事并存；纯文案，零数值）
	宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "七载大典",
		"文案": 文案表["seven_year_grand_ceremony"] % [序号],
		"category": "大典盛事"})
	if 晋升 > 0:
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "宗门晋升",
			"文案": 文案表["sect_promote_seven_year"] % [int(累计游戏日/ 365), 门派等级目标],
			"category": "宗门大事件"})
		_加推演条目(文案表["sect_promote_notice"] % [门派等级目标, 门派等级目标 * 2], ET_SECT, PRIO_HIGH, {"宗门等级": 门派等级目标})
		门派等级 = 门派等级目标
	_复检成就()  # 成就检测：宗门等级相关成就
	if 大典灵石 > 0:
		灵石 += 大典灵石
		_加推演条目(文案表["sect_ceremony_reward"] % [大典灵石], ET_SECT, PRIO_HIGH, {})
		七载赏赐池= 0
	if 大典法宝 > 0 and not 弟子列表.is_empty():
		for 掉落 in 七载待发掉落:
			var 物: Item = _造低阶物品(掉落.get("类型", "fabao"), 掉落.get("品阶", "上品"))
			弟子列表[0].背包.append(物)
			_加推演条目(文案表["sect_ceremony_bestow"] % [物.名称], ET_LOOT, PRIO_HIGH, {})
		七载待发掉落 = []
	七载大典摘要 = {"灵石": 大典灵石, "法宝": 大典法宝, "晋升至": 晋升, "序号": 序号, "评级": 评级}
	七载大典待展示= true
	_加推演条目(文案表["sect_exam_done"], ET_SECT, PRIO_NORMAL, {})
# === S1 端口：俸：福利按月结算（当前空操作桩）===
# 调用位置：推演一：月循环（紧接 _可能触发特殊登门_S1 之前）：
# 入参：无（读取全局 灵石 / 弟子列表 / 宗门贡献：
# 返回值：void；S1 实装后副作用：公库扣：+ 按身：阶位发放俸禄 + 欠薪→忠诚↓→叛逃
# 依赖：货：贡献系统（见 §：俸禄福利）。状态：空操作，零副作用，八道闸门安全：
func _结算俸禄_S1() -> void:

	# 更新成就统计：累计发放俸禄次数（S1 空操作桩，统计变量先准备好）
	累计发放俸禄次数 += 1
	_复检成就()  # 成就检测：俸禄发放相关成就
	pass
var _经济基线缓存: Dictionary = {}   # D1：经济基：csv 缓存（clamp 边界来源，R5 非硬编码：
# ============ D3 负面影响经济侧（S1-P0 批次三· 数据对齐版）============
# 轻量管理器状态（运行时瞬时，不持久化；规：design/08-功能提案/12-D3实现规格_数据对齐：md §8：
var _经济阀门缓存: Dictionary= {}      # 经济阀：csv ：{阀门 {系数,开：说明}}（懒加载：
var _负面事件缓存: Array = []           # negative_event.csv 行缓存（懒加载）
var _本月负面已触发: Dictionary= {}     # 本月：event_id 触发次数（月度重置）
var _本月灵石冲击: float = 0.0          # 本月负面事件灵石冲击累计（月末截断至 62：
var _弟子负面属性累计: Dictionary= {}   # 纯属性惩罚累计（零副作用占位；键=弟子姓名：
var _坊市负面卖价下限: float = 1.0       # 声望外部类浅联动下限（P0 neg_reputation=0，默认不触发：
# D3 开关缓存（：_加载负面开关_S1 ：经济阀：csv 读取；默认值对齐规：§6 默认安全态）
var _neg_global: bool = false
var _neg_res_build: bool = false
var _neg_disciple: bool = false
var _neg_reputation: bool = false
var _neg_grade_perm: bool = false
# === S1 ：-D1：宗门运维成本（刚性耗；ECON-02 §2.2 校准，标准局：05：==
# 接线 global_cost_rate 阀门：：-刚性：单独：EconomyBalance.平衡()（per-delta 施加：
# 全场景生效，不只赤字局；与 period_settlement.gd 末次 final 平衡() 双调用，正常配置下均恒等）：
# R5：下：上限：config/经济基线.csv 读（非硬编码 293/318）：
# 欠俸/忠诚链路：本阶段：stub（引：GDD-宗门经营 §：1），不强制实现：
func _结算运维成本_S1() -> void:

	var 基线: Dictionary = _读经济基线()
	var 下限: float = float(基线.get("标准局月耗_下限", "293"))
	var 上限: float = float(基线.get("标准局月耗_上限", "318"))
	var c4: float = 0.0
	for d in 弟子列表:
		c4 += 4.5 * _身份俸禄倍率(d.身份)   # 普：.0 / 执事1.5 / 长：.0
	var c5: float = 3.0 * 司职列表.size()
	var c6: float = 0.73 * 弟子列表.size()
	var c7: float = 0.375 * 弟子列表.size()
	var 刚性耗: float = c4 + c5 + c6 + c7          # 标准局：05
	# R5：clamp ：[下限, 上限]（读 CSV，非硬编码）
	刚性耗 = clamp(刚性耗, 下限, 上限)
	# R2 per-delta：对 -刚性：单独：平衡()（raw<0 ：×全局消耗系数，±15% 钳制：
	var _平衡器: EconomyBalance = EconomyBalance.new()
	var 实付: float = _平衡器.平衡(-刚性耗)             # 实付为负
	灵石 -= int(round(-实付))                      # 取绝对值扣公库
# D1 运维成本：弟子身份→俸禄倍率（普：.0 / 执事1.5 / 长：.0：
func _身份俸禄倍率(身份: String) -> float:

	match 身份:
		"长老":
			return 2.0
		"执事":
			return 1.5
		_:
			return 1.0   # 普：/ 外门 / 内门弟子 / 核心弟子 / 亲传弟子 / 堂主 / 供奉 ：1.0
# 读取 config/经济基线.csv ：{锚点: 数值}（D1 运维成本 clamp 边界来源，R5 非硬编码：
func _读经济基线() -> Dictionary:

	if not _经济基线缓存.is_empty():
		return _经济基线缓存
	var 路径 := "res://config/经济基线.csv"
	if not FileAccess.file_exists(路径):
		return {}
	var f: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if f == null:
		return {}
	f.get_line()   # 跳表头（含可能的 BOM，数据行不含：
	while not f.eof_reached():
		var 行: String = f.get_line().strip_edges()
		if 行== "":
			continue
			var 列: PackedStringArray = 行.split(",")
			if 列.size() >= 2:
				_经济基线缓存[列[0].strip_edges()] = 列[1].strip_edges()
	f.close()
	return _经济基线缓存
# ============ D3 负面影响经济侧（S1-P0 批次三）运行时管理器 ============
# 消费 config/negative_event.csv（_读负面事件表： config/经济阀：csv（neg_* 开关簇 + event_damage_rate：
# 激：DORMANT：殿阁被动_负面事件减免（L247，仅 res_build 灵石扣除处乘 (1+本：：
# 灵石流向：与 _结算运维成本_S1 一致（：EconomyBalance.平衡() 后扣公库；平：) 消费 event_damage_rate=1.0：
# 规格锚：design/08-功能提案/12-D3实现规格_数据对齐：md §8 伪代码落：
# —：UTF-8 BOM 容错（DestinyDataLoader._read_csv ：get_csv_line，首列键/值可能带 \ufeff）—：
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
# —：配置懒加载（复用项目现有 CSV 解析惯例；_坊市表) 风格）—：
func _读经济阀门表() -> Dictionary:

	if not _经济阀门缓存.is_empty():
		return _经济阀门缓存
	for r in DestinyDataLoader._read_csv("res://config/经济阀：csv"):
		var 行: String = r.get("阀门") if "阀门" in r else ""
		if 行!= "":
			_经济阀门缓存[行] = r
	return _经济阀门缓存
func _读负面事件表() -> Array:

	if not _负面事件缓存.is_empty():
		return _负面事件缓存
	_负面事件缓存 = DestinyDataLoader._read_csv("res://config/negative_event.csv")
	return _负面事件缓存
func _阀门开关(表: Dictionary, 键: String, 默认: int) -> bool:

	var r: Dictionary = 表.get(键, {})
	return int(r.get("开关") if "开关" in r else 默认) != 0
# —：总闸优先判定（neg_global 一键回退纯正向，即便分闸=1）—：
func _负面类别生效(类别: String) -> bool:

	if not _neg_global:
		return false
	match 类别:
		"资源殿阁":
			return _neg_res_build
		"弟子人员":
			return _neg_disciple
		"声望外部":
			return _neg_reputation
		"品级权限":
			return _neg_grade_perm
	return false
# —：punish_type ：四分类（兜底归类；规：§1/§8）—：
func _punish类别(pt: String) -> String:

	match pt:
		"矿石", "灵草", "丹材":
			return "资源殿阁"
		"心魔", "修为", "忠诚", "心境", "道心", "气血":
			return "弟子人员"
		"卖价":
			return "声望外部"
		"权益回收":
			return "品级权限"
		"灵石":
			return "弟子人员"   # 货币载体，默认归弟子：
		_:
			return ""
# —：月度结算接入点（推演一：S1 区，紧接 _结算运维成本_S1 之后）—：
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
		var 上限境: int = int(行.get("monthly_limit", "1"))
		if _本月负面已触发.get(eid, 0) >= 上限境:
			continue
		_负面事件结算(行)
	_负面总冲击卡位()
# —：单事件结算（双槽 punish_type/punish_value）—：
func _负面事件结算(行: Dictionary) -> void:

	var 后果: Array = []
	var 属资源殿阁: bool = (行.get("punish_type_1", "") in ["矿石", "灵草", "丹材"]) or (行.get("punish_type_2", "") in ["矿石", "灵草", "丹材"])
	for slot in ["1", "2"]:
		var 类别: String = _punish类别(行.get("punish_type_" + slot, ""))
		if not _负面类别生效(类别):
			continue
		var pt: String = 行.get("punish_type_" + slot, "")
		var pv: float = float(行.get("punish_value_" + slot, "0"))
		if pt == "" or pv <= 0:
			continue
		match pt:
			"灵石":
				var 额: float = pv
				if 属资源殿阁:   # 激：DORMANT 殿阁被动_负面事件减免（资源殿阁类事件，含其灵石机会成本）
					额= max(0.0, 额* (1.0 + 殿阁被动_负面事件减免))
				_本月灵石冲击 += 额
				后果.append("灵石-%d" % int(round(额)))
			"矿石":
				矿石 = max(0, 矿石 - int(pv))
				后果.append("矿石-%d" % int(pv))
			"灵草":
				灵草 = max(0, 灵草 - int(pv))
				后果.append("灵草-%d" % int(pv))
			"卖价":
				if _neg_reputation:   # 仅开启时浅联动（P0 默认 0，跳过；D3 不深联动：
					_坊市负面卖价下限 = min(_坊市负面卖价下限, pv)
			"权益回收":
				if _neg_grade_perm:
					_权益回收惩处(pv, 后果)   # pv = 治理失序罚金：0：
			"心魔", "修为", "忠诚", "心境", "道心", "气血":
				_施加弟子属性惩罚(pt, int(pv))   # 纯属性，无经济副作用
	var eid: String = 行.get("event_id", "")
	_本月负面已触发[eid] = _本月负面已触发.get(eid, 0) + 1
	if not 后果.is_empty():
		_加推演条目("【负面" % [行.get("event_name", eid), "".join(后果)], ET_SECT, PRIO_NORMAL, {"事件": eid})
# —：品级权限类惩处（D4 本批：权益回收= 罢免阶位 + 治理失序罚金）—：
func _权益回收惩处(罚金: float, 后果: Array) -> void:

	_本月灵石冲击 += 罚金                       # ：_负面总冲击卡：) 卡位后扣公库
	后果.append("治理失序罚金-%d" % int(round(罚金)))
	var 候选: Array = 弟子列表.filter(func(d): return d.阶位 != "")
	if not 候选.is_empty():
		var 目标: Disciple = 候选[randi() % 候选.size()]
		罢免阶位(目标)                          # 既有 setter（L2676）：降阶位一：+ 纪事
# —：月度总冲击卡位（硬卡 Σ：2，不转负盈余）—：
func _负面总冲击卡位() -> void:

	# 62 = 经济基线.csv 冲击上限_灵石 = floor(17%×366)（ECON-02 §2.4；镜：pre_f5 Layer B3/D：
	var 上限: float = 62.0
	_本月灵石冲击 = min(_本月灵石冲击, 上限)
	if _本月灵石冲击 <= 0.0:
		return
	# 灵石流向：_结算运维成本_S1 一致：：EconomyBalance.平衡()（消：event_damage_rate=1.0）后扣公库
	var _平衡器: EconomyBalance = EconomyBalance.new()
	var 实付: float = _平衡器.平衡(-_本月灵石冲击)
	灵石 -= int(round(-实付))
# —：纯属性惩罚：无经济副作用；记：Game 级按弟子累计字典（零副作用占位，规格 §8）—：
# 当前 Disciple 未建：心魔/忠诚/心境/道心/气血 独立字段，故以累计字典承载，不影响经：存档结构：
func _施加弟子属性惩罚(pt: String, pv: int) -> void:

	if 弟子列表.is_empty() or pv <= 0:
		return
	var 目标: Disciple = 弟子列表[randi() % 弟子列表.size()]
	var 名: String = ""
	if 目标.姓名 != "":
		名= 目标.姓名
	else:
		名= str(目标.get_instance_id())
	if not _弟子负面属性累计.has(名):
		_弟子负面属性累计[名] = {}
	_弟子负面属性累计[名][pt] = int(_弟子负面属性累计[名].get(pt, 0)) - pv
# —：：经济阀：csv 加载 D3 开关簇（neg_*；event_damage_rate 由平：) 读取，本处不重复）—：
func _加载负面开关_S1() -> void:

	var 阀: Dictionary = _读经济阀门表()
	_neg_global     = _阀门开关(阀, "neg_global", 0)
	_neg_res_build  = _阀门开关(阀, "neg_res_build", 1)
	_neg_disciple   = _阀门开关(阀, "neg_disciple", 1)
	_neg_reputation = _阀门开关(阀, "neg_reputation", 0)
	_neg_grade_perm = _阀门开关(阀, "neg_grade_perm", 0)
# === S1 端口：声望阈值触发特殊弟子主动投奔（当前空操作桩：==
# 调用位置：推演一：月循环（紧接 _结算俸禄_S1 之后）：
# 入参：无（读取全局 声望 / 弟子列表 / 命格池）
# 返回值：void；S1 实装后：：声望 >= 阈值：randf() 命中，生成带专属命格/特殊灵根的特殊弟子并 append ：弟子列表 + 写纪：
# 依赖：声望系统、命格池（见 §：特殊登门事件）。状态：空操作，零副作用：
func _可能触发特殊登门_S1() -> void:

	pass
# === S1 ：-A：凡人香火月度结算（当前空操作桩：==
# 调用位置：推演一：月循环（紧接 _可能触发特殊登门_S1 之后）：
# 入参：无（读取全局 香火值/ 信徒数/ 凡人城镇）：
# 返回值：void；S1 实装后：按月累加香火/信徒、重算月产预估与增益档、产出计：§11.9 财政：
# 依赖：数：[PLACEHOLDER]，真机校准。状态：空操作，零副作用：
func _结算香火_S1() -> void:
	# S2-3：补香火/信徒产出出口（原为空桩：空操作零副作用）
	if 门派等级 <= 0:
		门派等级 = 1
	var 月产: int = 门派等级 * 8 + 弟子列表.size() * 2
	香火值 = max(0, 香火值 + 月产)
	香火月产预估 = 月产
	# 信徒随宗门规模独立累积（供晋阶消耗；不随香火绝对值回退，避免覆盖已花费的信徒）
	信徒数 += 门派等级 + 弟子列表.size()
	添加纪事("庶务", "香火月结", "本月香火+%d，累计%d，信徒%d人（增益：%s）" % [月产, 香火值, 信徒数, 信徒增益档], 0)

# S2-3：信徒增益进阶（消耗信徒数解锁更高增益档——信徒的真实消耗出口）
func 晋阶信徒增益() -> Dictionary:
	var idx: int = 信徒增益链.find(信徒增益档)
	if idx < 0 or idx >= 信徒增益链.size() - 1:
		return {"成功": false, "原因": "信徒增益已至顶（%s）" % 信徒增益档}
	var 下一: String = 信徒增益链[idx + 1]
	var 花费: int = int(信徒增益花费.get(下一, 0))
	if 信徒数 < 花费:
		return {"成功": false, "原因": "信徒不足（需%d，余%d）" % [花费, 信徒数]}
	信徒数 -= 花费
	信徒增益档 = 下一
	添加纪事("庶务", "信徒增益", "消耗%d信徒，晋阶信徒增益至%s" % [花费, 下一], 1)
	return {"成功": true, "新增益档": 下一, "消耗信徒": 花费, "消息": "信徒增益晋阶至%s" % 下一}

# S2-3：香火供奉（消耗香火转化为宗门繁荣与声望——香火的真实经营收益出口）
func 供奉香火(数量: int) -> Dictionary:
	数量 = int(数量)
	if 数量 <= 0:
		return {"成功": false, "原因": "供奉数量须为正"}
	if 香火值 < 数量:
		return {"成功": false, "原因": "香火不足（需%d）" % 数量}
	香火值 -= 数量
	繁荣经营值 += int(数量 / 5)   # P1-2：供奉加到经营增量，避免被 更新门派() 派生覆盖抹平（最终繁荣=基础+经营值，被 clamp 到 100）
	声望 = 声望 + int(数量 / 20)
	功德 = max(0, 功德 + int(数量 / 10))   # P3：供奉为善行，累积功德（供奉越多越近正道）
	添加纪事("庶务", "供奉香火", "供奉香火%d，繁荣+%d、声望+%d、功德+%d" % [数量, int(数量 / 5), int(数量 / 20), int(数量 / 10)], 1)
	return {"成功": true, "消耗香火": 数量, "繁荣": 繁荣, "声望": 声望, "功德": 功德, "消息": "供奉香火%d，宗门繁荣与声望提升、功德+%d" % [数量, int(数量 / 10)]}

# P1-1：声望真实消耗出口（治理声望单向通胀——声望→悟道点+灵气，按固定比例兑换；声望同时作为坊市折扣/门派等级/特殊登门槛，消耗后相应门槛下降，形成权衡）
func 声望换修为(花费: int) -> Dictionary:
	花费 = int(花费)
	if 花费 <= 0:
		return {"成功": false, "原因": "兑换声望须为正"}
	if 声望 < 花费:
		return {"成功": false, "原因": "声望不足（需%d）" % 花费}
	声望 -= 花费
	var 得悟: int = int(花费 / 10)
	var 得气: int = int(花费 / 5)
	悟道点 += 得悟
	灵气 += 得气
	添加纪事("庶务", "声望化修为", "耗%d声望，换悟道点+%d、灵气+%d" % [花费, 得悟, 得气], 1)
	return {"成功": true, "消耗声望": 花费, "悟道点": 得悟, "灵气": 得气, "消息": "声望化修为：悟道点+%d、灵气+%d" % [得悟, 得气]}

# === P3：功德/业力/愿力 系统（支撑正邪路线 + 香火→修为升华链路）===
# 正/邪行记录：供连锁奇遇（正道链/邪道链）、祭炼等调用；UI 落地后续接入。
func 记录功德(量: int) -> void:
	功德 = max(0, 功德 + int(量))

func 记录业力(量: int) -> void:
	业力 = max(0, 业力 + int(量))

# 正邪路线抉择：门槛 + 不可逆（贴合 GDD-凡人香火 §1.3 / 路线图二.3 正邪承接）。
func 选择正邪路线(route: String) -> Dictionary:
	var 可选: Array = ["玄门正道", "逍遥中立", "九幽邪道"]
	if route not in 可选:
		return {"成功": false, "原因": "未知路线：%s" % route}
	if 正邪路线 != "":
		return {"成功": false, "原因": "正邪路线已选定（不可逆）：%s" % 正邪路线}
	if route == "玄门正道" and 功德 < 正道功德门槛:
		return {"成功": false, "原因": "功德不足（需%d，当前%d）" % [正道功德门槛, 功德]}
	if route == "九幽邪道" and 业力 < 邪道业力门槛:
		return {"成功": false, "原因": "业力不足（需%d，当前%d）" % [邪道业力门槛, 业力]}
	正邪路线 = route
	# 选定即定调：正道再积功德，邪道再积业力（不可回退）
	if route == "玄门正道":
		功德 += 10
	else:
		业力 += 10
	添加纪事("纪事", "正邪抉择", "宗门择定路线：%s（不可逆）" % route, 1)
	return {"成功": true, "路线": route, "功德": 功德, "业力": 业力, "消息": "已择定%s（不可逆）" % route}

# 香火 → 愿力（升华第一步：凝聚凡人祈愿为愿力）
func 香火化愿力(数量: int) -> Dictionary:
	数量 = int(数量)
	if 数量 <= 0:
		return {"成功": false, "原因": "转化数量须为正"}
	if 香火值 < 数量:
		return {"成功": false, "原因": "香火不足（需%d）" % 数量}
	香火值 -= 数量
	愿力 += 数量
	添加纪事("庶务", "香火化愿力", "耗香火%d，凝愿力+%d" % [数量, 数量], 0)
	return {"成功": true, "消耗香火": 数量, "愿力": 愿力, "消息": "香火凝为愿力%d" % 数量}

# 愿力 → 悟道点 + 灵气（修为升华；复用 声望换修为 固定比例：悟道点=量/10，灵气=量/5）
func 愿力升华修为(数量: int) -> Dictionary:
	数量 = int(数量)
	if 数量 <= 0:
		return {"成功": false, "原因": "升华数量须为正"}
	if 愿力 < 数量:
		return {"成功": false, "原因": "愿力不足（需%d）" % 数量}
	愿力 -= 数量
	var 得悟: int = int(数量 / 10)
	var 得气: int = int(数量 / 5)
	悟道点 += 得悟
	灵气 += 得气
	添加纪事("庶务", "愿力升华", "耗愿力%d，换悟道点+%d、灵气+%d" % [数量, 得悟, 得气], 1)
	return {"成功": true, "消耗愿力": 数量, "悟道点": 得悟, "灵气": 得气, "消息": "愿力升华：悟道点+%d、灵气+%d" % [得悟, 得气]}

# 连锁奇遇推进：完成链下一未做步，发放奖励；按 route 累计 功德/业力。
# 设计取舍：连锁链 在完成前即可推进（用于累积 功德/业力 解锁 正邪路线），
#           故不强制要求 正邪路线 已匹配；route 字段仅决定本链累计哪种业/功德。
func 推进连锁(chain_id: String) -> Dictionary:
	var chain = null
	for c in ChainLibrary.连锁链库:
		if c["id"] == chain_id:
			chain = c
			break
	if chain == null:
		return {"成功": false, "原因": "连锁链不存在：%s" % chain_id}
	var prog: Dictionary = 连锁进度.get(chain_id, {"done": 0, "完成": false})
	if prog.get("完成", false):
		return {"成功": false, "原因": "连锁链已完成：%s" % chain_id}
	var steps: Array = chain["steps"]
	var idx: int = int(prog.get("done", 0))
	if idx >= steps.size():
		return {"成功": false, "原因": "连锁链已完成（步序越界）"}
	var step: Dictionary = steps[idx]
	var 奖励: Dictionary = step.get("奖励", {})
	# 发放奖励（声望可为负）
	灵石 += int(奖励.get("灵石", 0))
	贡献点 += int(奖励.get("贡献点", 0))
	声望 += int(奖励.get("声望", 0))
	灵草 += int(奖励.get("灵草", 0))
	矿石 += int(奖励.get("矿石", 0))
	# 正/邪行累计：玄门正道→功德，九幽邪道→业力（其余路线链不累计）
	var 路线标签: String = chain.get("route", "")
	var 累计量: int = 0
	if 路线标签 == "玄门正道":
		累计量 = 正道每步功德
		记录功德(累计量)
	elif 路线标签 == "九幽邪道":
		累计量 = 邪道每步业力
		记录业力(累计量)
	# 纪事（含 履历 文案）
	var 履历: String = step.get("履历", "")
	var 内容: String = "%s：%s" % [step["name"], step.get("文案", "")]
	if not 履历.is_empty():
		内容 += "（%s）" % 履历
	添加纪事("奇遇", chain["name"], 内容, 1)
	# 进度推进
	prog["done"] = idx + 1
	var 完成链: bool = prog["done"] >= steps.size()
	if 完成链:
		prog["完成"] = true
		添加纪事("大典盛事", chain["name"], chain["终章文案"], 1)
	连锁进度[chain_id] = prog
	return {
		"成功": true,
		"链": chain_id,
		"步": step["name"],
		"步序": prog["done"],
		"完成链": 完成链,
		"灵石": int(奖励.get("灵石", 0)),
		"声望": int(奖励.get("声望", 0)),
		"累计类型": 路线标签,
		"累计量": 累计量,
		"消息": ("完成连锁步「%s」" % step["name"]) + ("；整链功成" if 完成链 else "")
	}

# === 气运系统：综合香火产出速率/愿力/功德/业力，影响突破/炼丹/产出/事件/招募/历练 ===
# 气运公式（产出速率+存量模型）：
#   气运基础 = 香火月产预估×2.0 + 愿力×0.1 + 功德×0.5 - 业力×0.5
#   归一化：(基础+500)/1500*100，clamp到0-100
# 设计要点：
#   1. 香火用月产速率（不是存量）→ 消耗香火供奉不影响气运（解决模型倒置）
#   2. 产出速率有上限（门派等级+弟子数限制）→ 后期不会溢出恒锁昌隆（解决归一化溢出）
#   3. 功德/业力权重高（0.5）→ 正邪路线真正决定气运走向
#   4. 愿力权重低（0.1）→ 愿力升华修为不显著影响气运
# 气运等级：昌隆(≥80)/旺盛(≥60)/平稳(≥40)/低迷(≥20)/衰败(<20)
# 加成系数：昌隆+20%/旺盛+10%/平稳0%/低迷-10%/衰败-20%

func 获取气运值() -> int:
	# 产出速率+存量模型
	var 香火速率: float = float(香火月产预估) * 2.0   # 香火月产速率（上限约280×2=560）
	var 愿力存量: float = float(愿力) * 0.1              # 愿力存量（低权重）
	var 功德存量: float = float(功德) * 0.5               # 功德存量（高权重，正邪正向）
	var 业力存量: float = float(业力) * 0.5               # 业力存量（高权重，正邪负向）
	var 基础气运: float = 香火速率 + 愿力存量 + 功德存量 - 业力存量
	# 归一化到0-100（基础范围约-500到+1000）
	var 归一化: float = (基础气运 + 500.0) / 1500.0 * 100.0
	归一化 = clamp(归一化, 0.0, 100.0)
	return int(归一化)

func 获取气运等级() -> String:
	var 气运值: int = 获取气运值()
	if 气运值 >= 80:
		return "气运昌隆"
	elif 气运值 >= 60:
		return "气运旺盛"
	elif 气运值 >= 40:
		return "气运平稳"
	elif 气运值 >= 20:
		return "气运低迷"
	else:
		return "气运衰败"

func 获取气运加成系数() -> float:
	var 气运值: int = 获取气运值()
	if 气运值 >= 80:
		return 0.2   # 昌隆+20%
	elif 气运值 >= 60:
		return 0.1   # 旺盛+10%
	elif 气运值 >= 40:
		return 0.0   # 平稳0%
	elif 气运值 >= 20:
		return -0.1  # 低迷-10%
	else:
		return -0.2  # 衰败-20%

func 获取气运突破加成() -> float:
	# 气运对突破成功率的加成（直接加百分比，上限+15%，下限-15%）
	var 系数: float = 获取气运加成系数()
	return clamp(系数 * 0.75, -0.15, 0.15)

func 获取气运炼丹加成() -> float:
	# 气运对炼丹/炼器成功率的加成
	var 系数: float = 获取气运加成系数()
	return clamp(系数 * 0.5, -0.10, 0.10)

func 获取气运产出加成() -> float:
	# 气运对资源产出的加成（与现有气运buff叠加）
	var 系数: float = 获取气运加成系数()
	return clamp(系数 * 0.5, -0.10, 0.10)

func 获取气运事件加成() -> float:
	# 气运对好事件触发概率的加成
	var 系数: float = 获取气运加成系数()
	return clamp(系数 * 0.5, -0.10, 0.10)

func 获取气运招募加成() -> float:
	# 气运对招募高品质弟子概率的加成
	var 系数: float = 获取气运加成系数()
	return clamp(系数 * 0.5, -0.10, 0.10)

func 获取气运历练加成() -> float:
	# 气运对历练收益的加成
	var 系数: float = 获取气运加成系数()
	return clamp(系数 * 0.5, -0.10, 0.10)

func 获取气运详情() -> Dictionary:
	return {
		"气运值": 获取气运值(),
		"气运等级": 获取气运等级(),
		"加成系数": 获取气运加成系数(),
		"突破加成": 获取气运突破加成(),
		"炼丹加成": 获取气运炼丹加成(),
		"产出加成": 获取气运产出加成(),
		"事件加成": 获取气运事件加成(),
		"招募加成": 获取气运招募加成(),
		"历练加成": 获取气运历练加成(),
		"香火": 香火值,
		"愿力": 愿力,
		"功德": 功德,
		"业力": 业力,
	}

# === P2-9：灵气消耗汇出（原 20+ 产点仅 1 耗点：2210，严重通胀；现玩家可主动将灵气温养为悟道点/灵石，形成消耗闸口）===
func 灵气凝修(花费: int = 50) -> Dictionary:
	花费 = int(花费)
	if 花费 <= 0:
		return {"成功": false, "原因": "凝修灵气须为正"}
	if 灵气 < 花费:
		return {"成功": false, "原因": "灵气不足（需%d）" % 花费}
	灵气 -= 花费
	var 得悟: int = int(花费 * 0.3)
	var 得石: int = int(花费 * 0.2)
	悟道点 += 得悟
	灵石 += 得石
	添加纪事("庶务", "灵气温养", "耗灵气%d，化悟道点+%d、灵石+%d" % [花费, 得悟, 得石], 0)
	return {"成功": true, "消耗灵气": 花费, "悟道点": 得悟, "灵石": 得石, "消息": "灵气温养：悟道点+%d、灵石+%d" % [得悟, 得石]}

# === S1 ：-B：字派序列生成（旧档缺字：：首次进入生成并持久化：==
# 调用位置：推演一：月循：S1 区（紧接 _结算香火_S1 之后）；新弟子创建（举办测灵根/ 招收弟子）前置调用：
# 规则：从候选池随机：5：0 字生：辈分字派；辈分间：顺延规则 [PLACEHOLDER]（GDD §⑨），本批仅落字：生成：
func _确保字派_S1() -> void:

	if not 辈分字派.is_empty():
		return
	var 候选池: Array = ["甲", "乙", "丙", "丁", "戊", "己", "庚"]
	候选池.shuffle()
	var n: int = randi_range(5, 10)
	辈分字派.clear()
	for i in n:
		辈分字派.append(候选池[i])
# === S1 ：-C：正邪路线解锁检测（双重条件：==
# 调用位置：推演一：月循：S1 区（紧接 _确保字派_S1 之后）：
# 解锁 = 门派等级 >= 3 ：已完成首次七载大考（：上次七载日> 0 近似：七载大典首次结算后该字段非零）：
# 当前空桩，仅读标记；路线增益/事件权重/专属内容 [PLACEHOLDER]（GDD §⑨）：
func _检查正邪解锁_S1() -> bool:

	return 门派等级 >= 3 and 上次七载日> 0
# === S1 ：-A：宗门大阵耐久月度结算（纯经营桩，：推演一：S1 区）===
# 当前主阵每日扣耐久（灵：灵草，[PLACEHOLDER] 数值待真机校准）；耗尽→全域效果：.5（批6-B L1146 接入时判）：
# 当前为空操作桩：仅预留调用端口，八道闸门安全，不触碰战斗：
func _结算大阵耐久_S1() -> void:

	pass
# 单个弟子月度事件（历练奇遇，结果按综合实力判定：
func _弟子月度事件(d: Disciple) -> String:

	var 概率 := 0.5
	if d.性格 == "孤僻清修":
		概率 -= 0.2
	if randf() >= 概率:
		return ""
	var 文本: String = "%s：%s（%s）" % [d.姓名, Lore.取历练(d.境界), d.性格]
	if _判定成败(d):
		文本 += "（大有所获）"
		if randf() < 0.15:
			var it := Item.new()
			d.获得物品(it)        # 入背：+ 自动穿戴（更优则替换，受 品阶≤境：限制：
			文本 += " 得：%s" % it.简称
			if it.极品 or it.特殊:
				待抉择.append({"弟子": d, "物品": it, "文本": 文本})
		if randf() < 0.05:
			var 兽: Beast = Beast.new()
			灵兽蛋列表.append(兽)
			文本 += " 寻得灵兽蛋一："
	else:
		var 原因池: Array[String] = [
			"寻宝未获，空手而归",
			"遭遇迷障，不得不",
			"探寻无果，徒劳往",
			"灵气稀薄，无功而返",
			"妖兽出没，被迫绕",
			"天候骤变，折返避祸",
			"路径生疏，迷失林",
			"所获之物品相不佳，弃之而归",
		]
		文本 += "（无功而返：%s）" % 原因池[randi() % 原因池.size()]
	# ===== 奇遇分支（Step 1：宗门内场景路由；与历练并列、独立概率）=====
	# 原内联冷：抽取/分流逻辑抽至 _尝试触发奇遇 复用（资源产出、历练通关共用）：
	var 事: Dictionary = _尝试触发奇遇(d, "宗门")
	if not 事.is_empty():
		文本 += "\n" + 事.get("文案", "")
	return 文本
# 奇遇触发概率（ADR-002 D1）：：_弟子月度事件 命格/性格修正，独立基础概率：
func 奇遇触发概率(d: Disciple) -> float:

	var p := 0.15   # [PLACEHOLDER] 基础触发概率，待平衡
	if d.性格 == "孤僻清修":
		p -= 0.1
	return clamp(p, 0.0, 1.0)
# 通用奇遇触发（Step 1 三场景全量接入）：在指定 scene 下按概率 + 全局冷却 + 每日上限 + 单条冷却
# 尝试触发一条奇遇；命中后按 需干预/征伐 分流收尾，并 emit 奇遇发生 signal ：UI 调度（Step 2）：
# 返回触发的奇遇包（未触发返回 {}），供调用方决定是否：文案 并入推演日志：
# 当前月份：0游戏：1月），用于奇遇防重复冷却
func _当前月() -> int:

	return int(累计游戏日/ 30)
func _尝试触发奇遇(d: Disciple, scene: String, 保底: bool = false) -> Dictionary:

	var 结果: Dictionary = {}
	# Sprint-02b：全局冷却：0秒现实时间）；保底模式（历练探索节点）豁免
	var 可出奇遇 := true
	if not 保底 and Time.get_ticks_msec() - _上次奇遇时刻 < 30000:
		可出奇遇 = false
	# 每日上限（按累计游戏日重置）
	if _奇遇日标记!= 累计游戏日:
		_奇遇日标记= 累计游戏日
		_今日奇遇次数 = 0
	if _今日奇遇次数 >= _校准("奇遇日上", 5):
		可出奇遇 = false
	if not 可出奇遇 or (not 保底 and not _奇遇保底生效() and randf() >= 奇遇触发概率(d)):
		return 结果
	# ：scene 路由抽一条（Step 1：scene 非空时仅取匹：trigger_scene 的事件）
	var q: Dictionary = Quest.抽取(d, scene)
	if q.is_empty() or q.get("event_id") if "event_id" in q else "" == "":
		return 结果
	# Sprint-02b：单条冷却检查（cooldown_hour 转游戏日比较：
	var eid := q.get("event_id") if "event_id" in q else "" as String
	var cd_hour := q.get("cooldown_hour") if "cooldown_hour" in q else 0 as int
	if cd_hour > 0 and _单条冷却记录.has(eid):
		var 上次触发日:= _单条冷却记录[eid] as int
		if 累计游戏日- 上次触发日< ceil(cd_hour / 24.0):
			return 结果
	# S0 P0：奇遇防重复冷却（月份维度，3个月：
	if quest_cooldown.has(eid) and _当前月 < quest_cooldown[eid]:
		return 结果
	_今日奇遇次数 += 1
	_单条冷却记录[eid] = 累计游戏日
	quest_cooldown[eid] = _当前月() + 3
	# 声望：稀有及以上品质奇遇（配套规则+10~20：
	if q.get("稀有度") if "稀有度" in q else "普通" != "普通":
		_加声望(randi_range(10, 20))
	# 分流收尾（ADR-002 / ADR-003：
	if q.需干预:
		# ： 进干预队列（UI 灰模：art-lead 后续出）；兜底期恒不触发
		奇遇待抉择.append({"弟子": d, "奇遇": q, "选项": Quest.干预选项})
	else:
		if q.get("event_type") if "event_type" in q else "" == "征伐":
			结算征伐奇遇(d, q)
		else:
			结算奇遇赏赐(d, q)
	# emit signal ：main.gd（Step 2）做 L1 气泡 / L2 弹窗 / L3 全屏 调度
	奇遇发生.emit(q, d)
	_上次奇遇游戏日 = 累计游戏日   # P2-13：奇遇保底窗口锚点（命中即刷新，长期无奇遇则豁免概率）
	# 宗门纪事（最简版）：追加本次触发记：
	宗门纪事.append({
		"时间": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": q.get("稀有度") if "稀有度" in q else "普通",
		"名称": q.get("event_name") if "event_name" in q else "无名奇遇", "文案": q.get("文案") if "文案" in q else "",
	})
	return q

# P2-13：奇遇保底窗口——距上次奇遇超阈值则豁免概率判定（仍受日上限/单条/月度冷却约束）：
#   直接回应「玩家上线晚、长期没遇到奇遇」的死锁担忧；正常触发节奏不受影响。
func _奇遇保底生效() -> bool:
	return 累计游戏日 - _上次奇遇游戏日 >= _校准("奇遇保底日", 7)

# ============ D5：机缘钩子（B1 拍板：经营层零战斗，：0行）============
# 挂在月度推演（_弟子月度事件 之后），绕开 _今日奇遇次数 日配额：
# 从事件池：trigger_scene=机缘 + 门派等级/境界门槛 + 冷却，对每条事件
# 独立 roll：randf() < trigger_weight/100，精确达：碎片×3=15% / 阵图×1=5%
#（两条独立判定，可同时触发；命中：结算奇遇赏赐，并：event_id 打月：单条冷却防同日双发）：
func _尝试机缘(d: Disciple) -> String:

	if d == null:
		return ""
	Quest._确保csv加载()
	var 摘要: String = ""
	for evt in Quest._csv事件池:
		if evt.get("trigger_scene") if "trigger_scene" in evt else "" != "机缘":
			continue
		if int(evt.get("unlock_sect_level") if "unlock_sect_level" in evt else 1) > 门派等级:
			continue
		var d_idx: int = Disciple.境界表.get(d.境界)
		var e_idx: int = Disciple.境界表.get(evt.get("unlock_realm") if "unlock_realm" in evt else "练气")
		if e_idx < 0 or d_idx < 0 or e_idx > d_idx:
			continue
		var eid: String = evt.get("event_id") if "event_id" in evt else ""
		if quest_cooldown.has(eid) and _当前月 < quest_cooldown[eid]:
			continue
		var cd_hour: int = int(evt.get("cooldown_hour") if "cooldown_hour" in evt else 0)
		if cd_hour > 0 and _单条冷却记录.has(eid):
			if 累计游戏日- _单条冷却记录[eid] < ceil(cd_hour / 24.0):
				continue
		var tw: float = float(evt.get("weight") if "weight" in evt else 0)
		if tw <= 0 or (not _奇遇保底生效() and randf() >= tw / 100.0):
			continue
		var q: Dictionary = {
			"文案": evt.get("event_content") if "event_content" in evt else "",
			"稀有度": evt.get("rarity") if "rarity" in evt else "普通",
			"需干预": false,
			"赏赐": null,
			"event_name": evt.get("event_name") if "event_name" in evt else "",
			"event_type": evt.get("event_type") if "event_type" in evt else "",
			"trigger_scene": evt.get("trigger_scene") if "trigger_scene" in evt else "",
			"opt1_desc": evt.get("opt1_desc") if "opt1_desc" in evt else "",
			"opt1_reward": evt.get("opt1_reward") if "opt1_reward" in evt else "",
			"opt1_punish": evt.get("opt1_punish") if "opt1_punish" in evt else "",
			"opt2_desc": evt.get("opt2_desc") if "opt2_desc" in evt else "",
			"opt2_reward": evt.get("opt2_reward") if "opt2_reward" in evt else "",
			"opt2_punish": evt.get("opt2_punish") if "opt2_punish" in evt else "",
			"opt3_desc": evt.get("opt3_desc") if "opt3_desc" in evt else "",
			"opt3_reward": evt.get("opt3_reward") if "opt3_reward" in evt else "",
			"opt3_punish": evt.get("opt3_punish") if "opt3_punish" in evt else "",
			"base_value": float(evt.get("base_value") if "base_value" in evt else 0.0),
			"level_factor": float(evt.get("level_factor") if "level_factor" in evt else 0.15),
			"min_value": float(evt.get("min_value") if "min_value" in evt else 0.0),
			"max_value": float(evt.get("max_value") if "max_value" in evt else 999.0),
			"weight_decay": float(evt.get("weight_decay") if "weight_decay" in evt else 0.7),
			"cooldown_hour": cd_hour,
		}
		if evt.get("rarity") if "rarity" in evt else "普通" != "普通":
			_加声望(randi_range(10, 20))
		quest_cooldown[eid] = _当前月() + 3
		_单条冷却记录[eid] = 累计游戏日
		结算奇遇赏赐(d, q)
		if not d.履历.is_empty():
			摘要 += d.履历.back()
	return 摘要
# ============ 奇遇赏赐结构化解析（偏差#3 / B 部分，极简版）============
# 输入格式：物品key:数量，多赏赐：| 分隔。例：lingshi:200|lingcao:25"
# 支持 key：lingshi(灵石) / lingcao(灵草) / kuangshi(矿石) / dan_low(低阶丹药入背：
# 设计铁律：解析失败降级为纯文本（并入摘要），不报错、不崩溃、不阻塞主流程：
# 返回：发放动作的中文摘要串（空串表示无有效发放）：
func _解析并发放奇遇赏赐(d: Disciple, 文本: String) -> String:

	var 摘要 := ""
	if 文本.strip_edges() == "":
		return 摘要
	for 段 in 文本.split("|"):
		var 段文本: String = 段.strip_edges()
		if 段文本 == "":
			continue
		if not 段文本.contains(":"):
			摘要 += " " + 段文本
			continue
		var 部件: Array = 段文本.split(":", false)
		var key: String = 部件[0].strip_edges()
		if key in ["exp", "favor", "buff", "multi"]:
			摘要 += " " + _奇遇增益_中文描述(部件)
			continue
		if key == "item":
			var item_id: String = 部件[1].strip_edges() if 部件.size() > 1 else ""
			var cnt: int = 部件[2].strip_edges().to_int() if 部件.size() > 2 else 1
			if item_id == "" or cnt <= 0:
				摘要 += " " + 段
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
			摘要 += " " + 段
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
				摘要 += " " + 段
	return 摘要
# ---- ：项拍板：奇遇增益结构化语法预埋（S0 降级中文 / S1 ：effect_type 分发实际逻辑：---
# 标准格式（与 物品key:数量 对齐）：
#   exp:弟子范围:数：/ favor:弟子范围:数：/ buff:buff_id:数：/ multi:资源类型:倍率:时长
# S0 行为：识别后仅生成中文描述（剧情风味文本），不执行实际数值，保证不报错不崩档：
# S1 扩展：在 _应用奇遇增益 按类型分发真实逻辑，存量奇遇数据无需任何返工即可生效：
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
			return "(全宗%s提升%s)" % [_buff文本(bid), _百分比文本]
		"multi":
			var 资源: String = _资源名词(部件[1])
			var 倍: float = 部件[2].to_float() if 部件.size() > 2 else 1.0
			var 权: int = 部件[3].to_int() if 部件.size() > 3 else 0
			return "(%s产出%.1f倍，持续%d个月)" % [资源, 倍, 部件[4].to_int() if 部件.size() > 4 else 1]
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
		"combat_power": "战力", "loot_rate": "掉落率", "sect_reputation": "声望"
	}
	return 表.get(bid, bid)
func _资源名词(名: String) -> String:

	var 局: Dictionary = {
		"lingshi": "灵石", "lingcao": "灵草", "kuangshi": "矿石", "lingqi": "灵气"
	}
	return 局.get(名)
func _百分比文本(权: float) -> String:

	return "%d%%" % int(round(权* 100))
# 奇遇赏赐结算（ADR-002 D5）：兜底：q.赏赐==null ：随机小赏赐；csv 到位后按赏赐结构结算：
# Sprint-02b：记录冷却时：+ 宗门等级缩放接入
func 结算奇遇赏赐(d: Disciple, q: Dictionary):

	_上次奇遇时刻 = Time.get_ticks_msec()
	奇遇完成总数 += 1
	if q.get("稀有度") if "稀有度" in d else "普" in ["稀有", "上品", "极品", "天品"]:
		高级奇遇完成数+= 1
	var 摘要: String = "奇遇·" + str(q.get("稀有度") if "稀有度" in d else "普")
	if q.get("稀有度") if "稀有度" in d else "普" in ["上品", "极品", "天品"]:   # P1：高稀有度奇遇计入周期评分
		周期评分.记稀有道具()
	# Sprint-02b：宗门等级缩放赏赐（：q 有缩放字段时：
	var base := q.get("base_value") if "base_value" in d else 0.0 as float
	var 灵石赏赐 := 0
	if base > 0.0:
		var factor := q.get("level_factor") if "level_factor" in d else 0.15 as float
		var min_v := q.get("min_value") if "min_value" in d else 0.0 as float
		var max_v := q.get("max_value") if "max_value" in d else 999.0 as float
		var 缩放值: float = Quest._缩放入参(base, factor, min_v, max_v)
		灵石赏赐 = int(round(缩放值))
		if 灵石赏赐 > 0:
			灵石 += 灵石赏赐
			摘要 += " 灵石+%d（宗门等级缩放）" % 灵石赏赐
	else:
		# 兜底随机小赏：[PLACEHOLDER 数值，待平衡]
		灵石赏赐 = randi_range(10, 50)
		灵石 += 灵石赏赐
		摘要 += " 灵石+%d" % 灵石赏赐
	if not (base > 0.0):
		if randf() < 0.3:
			var c: int = randi_range(1, 5)
			贡献点+= c
			摘要 += " 贡献+%d" % c
		if randf() < 0.15:
			var it := Item.new()
			it.奇遇版= true        # ADR-002 D5：奇遇版标记（增幅曲线待 design 录入，本 Sprint 仅置位）
			d.获得物品(it)          # 入背：+ 自动穿戴（经 ADR-001 自动进战力）
			摘要 += " 得%s·奇遇版：%s" % [it.简称, it.名称]
	# B 部分：结构化赏赐（opt1_reward 字段，格：物品key:数量翻
	var 赏赐文本: String = q.get("opt1_reward") if "opt1_reward" in d else ""
	if 赏赐文本.strip_edges() != "":
		var 解析摘要: String = _解析并发放奇遇赏赐(d, 赏赐文本)
		if 解析摘要 != "":
			摘要 += 解析摘要
			宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": q.get("稀有度") if "稀有度" in q else "普通", "名称": q.get("event_name") if "event_name" in q else "奇遇赏赐", "文案": "获得赏赐：%s" % 解析摘要.strip_edges()})
	# 道心值：待道心系统；：Sprint 先记 履历（ADR-002 D5）：
	d.履历.append(摘要)
# ============ 奇遇·征伐：战斗收尾（ADR-003 D6：/ ADR-002 hook：===========
# ：Quest.结算征伐 发起战斗（BattleManager 调用 BattleCalculator 纯逻辑）返回统一 BattleResult：
# 本函数按胜负发放赏赐/：履历，完成「奇遇管理器」收尾（ADR-003 D6：战斗影：履历/声望）：
func 结算征伐奇遇(d: Disciple, q: Dictionary):

	_上次奇遇时刻 = Time.get_ticks_msec()
	奇遇完成总数 += 1
	if q.get("稀有度") if "稀有度" in q else "普" in ["稀有", "上品", "极品", "天品"]:
		高级奇遇完成数+= 1
	var 战报: Dictionary = Quest.结算征伐(d, q)
	var 摘要: String = "奇遇·征伐·" + str(q.get("event_name") if "event_name" in q else "无名试炼")
	if 战报["is_win"]:
		摘要 += " 大捷"
		# 胜利赏赐（宗门等级缩放灵：+ 潜在物品，数值待 design 校准：
		var base := q.get("base_value") if "base_value" in 战报 else 30.0 as float
		var 灵石赏赐 := 0
		if base > 0.0:
			var factor := q.get("level_factor") if "level_factor" in 战报 else 0.15 as float
			var min_v := q.get("min_value") if "min_value" in 战报 else 10.0 as float
			var max_v := q.get("max_value") if "max_value" in 战报 else 999.0 as float
			灵石赏赐 = int(round(Quest._缩放入参(base, factor, min_v, max_v)))
			if 灵石赏赐 > 0:
				灵石 += 灵石赏赐
				摘要 += " 灵石+%d" % 灵石赏赐
		else:
			灵石赏赐 = randi_range(20, 60)
			灵石 += 灵石赏赐
			摘要 += " 灵石+%d" % 灵石赏赐
		if randf() < 0.2:
			var it := Item.new()
			it.奇遇版= true
			d.获得物品(it)
			摘要 += " 得%s·奇遇版：%s" % [it.简称, it.名称]
	else:
		var 失败原因: Array[String] = ["不敌对手，险象环生后撤退", "陷入苦战，消耗过大无功而返", "情报有误，扑了个空", "天时不利，草草收兵"]
		摘要 += " 失利：%s" % 失败原因[randi() % 失败原因.size()]
	# B 部分：结构化赏赐（opt1_reward 字段与
	var 征伐赏赐文本: String = q.get("opt1_reward") if "opt1_reward" in 战报 else ""
	if 征伐赏赐文本.strip_edges() != "":
		var 征伐解析: String = _解析并发放奇遇赏赐(d, 征伐赏赐文本)
		if 征伐解析 != "":
			摘要 += 征伐解析
	d.履历.append(摘要)
	# 征伐奇遇也写宗门纪事（_尝试触发奇遇的L227可能被冷：概率拦住：
	宗门纪事.append({
		"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID,
		"稀有度": q.get("稀有度") if "稀有度" in 战报 else "普", "名称": "征伐·%s" % q.get("event_name") if "event_name" in 战报 else "无名",
		"文案": "%s（回合%d）" % ["大捷" if 战报["is_win"] else "失利", 战报.get("round_count", 0)],
	})
# ============ 历练秘境对接接口（ADR-003 D6 / Sprint-03 T3，stub：===========
# 秘境ID ：怪物列表(CombatantData 快照) ：BattleManager 结算通路：
# P0 仅预留接口与数据契约；秘境配置表 config/level.csv ：design 录入（S1 接敌表）：
# 出战/怪物快照由调用方组装（如来自 disciple.get_final_combat_attr()）；
# 本函数负责通路编排，返回统一 BattleResult（无数据时返：stub 标记占位）：
# ============ 历练秘境：数据驱动挑战接口（Day 2 取代：stub：===========
# 主入口：挑战秘境(stage_id, 出战弟子列表) ：解锁校验 ：体力 ：组：：结算 ：赏赐/首：解锁
# 返回扩展 BattleResult：{is_win, round_count, remaining_hp, drop_reward, battle_log, 赏赐摘要, stub, 秘境ID, error}
func 挑战秘境(stage_id: String, 出战弟子: Array = [], mode: String = "") -> Dictionary:
	# 如果未指定模式，使用全局设置的战斗模式
	if mode == "":
		mode = 战斗模式
	var 结果: Dictionary = {"is_win": false, "round_count": 0, "remaining_hp": 0, "drop_reward": [],
		"battle_log": [], "赏赐摘要": "", "stub": false, "秘境ID": stage_id, "error": ""}
	var stage: Dictionary = StageDataLoader.get_stage(stage_id)
	if stage.is_empty():
		结果["error"] = "秘境不存： %s" % stage_id
		return 结果
	if not StageDataLoader.is_unlocked(stage_id, 门派等级, 已通关秘境):
		结果["error"] = "秘境未解："
		return 结果
	if 出战弟子.is_empty():
		结果["error"] = "未选择出战弟子"
		return 结果
	# S1 器殿赠宝：缓存最近出战阵容（：P1 权重判定；存姓名，可序列化，save/load 持久化）
	if 出战弟子.size() > 0:
		_上次出战弟子 = 出战弟子.filter(func(d): return d is Disciple).map(func(d): return d.姓名)
	var 节点类型: String = stage.get("node_type") if "node_type" in stage else "normal"
	# 体力校验
	var 耗时: int = int(stage.get("stamina_cost") if "stamina_cost" in stage else 0)
	if 体力 < 耗时:
		结果["error"] = "气力不足（需%d，余%d： % [耗时, 体力]"
		return 结果
	# 精英每日次数校验
	if 节点类型 == "elite":
		var 今日: String = "%d" % 累计游戏日
		if not 精英每日次数.has(今日):
			精英每日次数[今日] = {}
		var 上限: int = int(stage.get("daily_limit") if "daily_limit" in stage else 0)
		if 上限 > 0 and 精英每日次数[今日].get(stage_id, 0) >= 上限:
			结果["error"] = "今日精英挑战次数已用："
			return 结果
	# 扣体：
	体力 = clamp(体力 - 耗时, 0, 体力上限())
	# 组装敌方（CSV 驱动：
	var 怪物: Array = StageDataLoader.build_monster_units(stage_id)
	if 怪物.is_empty():
		体力 = clamp(体力 + 耗时, 0, 体力上限())   # 回退
		结果["error"] = "秘境无怪物配置"
		return 结果
	# 组装我方快照（弟子：战斗属性聚合，唯一入口 get_final_combat_attr：
	var 我方: Array = []
	for d in 出战弟子:
		if d is Disciple:
			我方.append(d.get_final_combat_attr())
	if 我方.is_empty():
		体力 = clamp(体力 + 耗时, 0, 体力上限())
		结果["error"] = "出战弟子属性无："
		return 结果
	# 结算（车轮战编排，纯逻辑：
	var 战报: Dictionary
	if 我方.size() == 1 and 怪物.size() == 1:
		战报 = BattleManager.发起1v1(我方[0], 怪物[0], mode, false)
	else:
		战报 = BattleManager.发起3v3(我方, 怪物, mode, false)
	结果["is_win"] = 战报.get("is_win", false)
	结果["round_count"] = 战报.get("round_count", 0)
	结果["remaining_hp"] = 战报.get("remaining_hp", 0)
	结果["battle_log"] = 战报.get("battle_log", [])
	# 胜后处理：首：/ 精英次数 / 掉落 / 历练奇遇
	if 结果["is_win"]:
		# 阶段2：御兽峰被动——历练胜利时 10% 触发「灵兽相助」，本次历练收益 +10%（独：roll，不触碰核心战斗数值红线）
		var 御兽相助: bool = 司职列表.has("yushou") and randf() < 0.10
		var 气运历练乘: float = 1.0 + 获取气运历练加成()	# P3 气运：历练收益随气运±10%
		var 首通: bool = not 已通关秘境.has(stage_id)
		# 阵营任务进度更新：远古遗泽"遗迹探索"任务
		更新阵营任务进度("远古遗泽", "daily", 1)
		if 首通:
			周期评分.记首通()   # P1：首通计入周期评：
			已通关秘境[stage_id] = true
			_传承事件("首次攻破秘境")   # WAVE-D #8：首通秘：：先贤事迹图录 + 事件型里程碑
			_复检里程碑()                  # WAVE-D #8：秘境数阈值（秘境大成：
			_复检成就()                          # S1 ：：秘境首通后按弟：灵兽等指标补达成成就
			_新手_检查条件("realm_first_enter")
			var 首通类型: String = stage.get("first_reward_type") if "first_reward_type" in stage else ""
			var 首通数: int = int(stage.get("first_reward_num") if "first_reward_num" in stage else 0)
			if 首通类型== "res" and 首通数 > 0:
				var 实得: int = int(round(首通数 * (1.10 if 御兽相助 else 1.0) * 气运历练乘))
				灵石 += 实得
				结果["赏赐摘要"] += " 首通灵：%d" % 实得
			# 声望里程碑（配套规则）：普通首：5 / 精英首：15
			if 节点类型 == "elite":
				_加声望(15)
				结果["赏赐摘要"] += " 声望+15"
			else:
				_加声望(5)
				结果["赏赐摘要"] += " 声望+5"
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
				it.名称 = drop.get("item_name") if "item_name" in drop else "掉落"
				_应用掉落品质(it, drop.get("quality") if "quality" in drop else "")
				var 得主: Disciple = 出战弟子[0] if (出战弟子.size() > 0 and 出战弟子[0] is Disciple) else null
				if 得主 != null:
					var 额外件数: int = 0
					if 御兽相助:
						额外件数 = max(1, int(round(drop.get("count") if "count" in drop else 1 * 0.10 * 气运历练乘)))
						for _k in 额外件数:
							var 额外: Item = _掉落转物品(drop)
							额外.名称 = drop.get("item_name") if "item_name" in drop else "掉落"
							_应用掉落品质(额外, drop.get("quality") if "quality" in drop else "")
							得主.获得物品(额外)
					得主.获得物品(it)
					结果["赏赐摘要"] += " 得%s×%d" % [drop.get("item_name") if "item_name" in drop else "", drop.get("count") if "count" in drop else 1 + 额外件数]
			# 阶段2：御兽峰「灵兽相助」文案（收益+10% 已结算，不触碰核心战斗数值）
			if 御兽相助:
				结果["赏赐摘要"] += "（灵兽相助·收益+10%）"
			# 历练通关（战斗胜利场景）奇遇触发，用首名出战弟子承载
			var 承载: Disciple = 出战弟子[0] if (出战弟子.size() > 0 and 出战弟子[0] is Disciple) else null
			if 承载 != null:
				_尝试触发奇遇(承载, "战斗胜利")
	# 弟子履历
	for d in 出战弟子:
		if d is Disciple:
			d.履历.append("历练·%s%s" % [stage.get("stage_name") if "stage_name" in d else stage_id,
				("胜" if 结果["is_win"] else "败") + 结果["赏赐摘要"]])
	弟子变动.emit()
	return 结果
func 历练结算(秘境ID: String, 出战: Array = [], 怪物列表: Array = [], mode: String = "full") -> Dictionary:

	return 挑战秘境(秘境ID, 出战, mode)
# ============ 宗门战（S1-3 接线）============
# 架构对齐 挑战秘境：UI 只调本函数，不碰 ZongmenBattle 结算核心（ADR-003 分层）。
# 入参：
#   战斗类型：宗门攻防战 / 秘境争夺战 / 妖兽围剿战 / 阵营围剿战
#   出战队伍：Array[Array[Disciple]]，每队最多 5 人、最多 3 队
#   增益：Dictionary{增益名: bool}，灵石/丹药由 UI 侧扣除，此处只负责把数值代入战斗状态
# 返回：{ok, error, 战报, 奖励文本}；战报 = ZongmenBattle.generate_battle_report 口径
# 系数 = 敌方单人战力 / 我方单人战力。经 .scratch_backup/_S13_calib.py 3000 场×4 类型标定：
#   目标胜率梯度 宗门攻防 0.77 → 秘境争夺 0.70 → 妖兽围剿 0.60 → 阵营围剿 0.43（实测值）。
#   胜负对系数极敏感（兰彻斯特平方律：±2% 战力 ≈ ±20% 胜率），故叠加 ±0.03 随机浮动，
#   既平滑极端胜率（避免"必胜/必败"），也让每次遭遇的敌方强度有变化。
const 宗门战难度系数: Dictionary = {"宗门攻防战": 0.93, "秘境争夺战": 1.00, "妖兽围剿战": 1.01, "阵营围剿战": 0.97}
const 宗门战难度浮动: float = 0.03
const 宗门战敌方名池: Array = ["玄清宗", "百草门", "天机阁", "九霄雷府", "青冥剑派", "赤炎魔宗", "寒渊谷", "万妖殿"]
func 发起宗门战(战斗类型: String, 出战队伍: Array, 增益: Dictionary = {}) -> Dictionary:
	var 结果: Dictionary = {"ok": false, "error": "", "战报": {}, "奖励文本": ""}
	if not 战斗类型 in ZongmenBattle.BATTLE_TYPES:
		结果["error"] = "未知战斗类型：%s" % 战斗类型
		return 结果
	# 1 组装我方队伍（跳过空队/非弟子）
	var 我方队伍: Array = []
	for 队 in 出战队伍:
		var 成员: Array = []
		for d in 队:
			if d is Disciple:
				成员.append(d)
		if 成员.size() > 0:
			我方队伍.append(成员)
	if 我方队伍.is_empty():
		结果["error"] = "未编制任何出战队伍"
		return 结果
	# 2 我方总战力 + 最高境界（敌方据此等比生成，保证对抗强度随玩家成长）
	var 我方战力: int = 0
	var 最高境界序: int = 0
	for 队 in 我方队伍:
		for d in 队:
			if d is Disciple:
				我方战力 += int(d.总战力())
				var 序: int = Disciple.境界序.find(d.境界)
				if 序 > 最高境界序:
					最高境界序 = 序
	var 敌方境界: String = Disciple.境界序[最高境界序] if 最高境界序 >= 0 else "练气"
	# 3 生成敌方队伍：队数/每队人数与我方对称，总战力 = 我方 × 类型难度系数
	var 系数: float = float(宗门战难度系数.get(战斗类型, 1.0)) + randf_range(-宗门战难度浮动, 宗门战难度浮动)
	var 敌方名: String = 宗门战敌方名池[randi() % 宗门战敌方名池.size()]
	var 敌方总数: int = 0
	for 队 in 我方队伍:
		敌方总数 += 队.size()
	var 敌方单人战力: int = max(50, int(float(我方战力) * 系数 / float(max(1, 敌方总数))))
	var 敌方队伍: Array = []
	for i in 我方队伍.size():
		var 队人数: int = (我方队伍[i] as Array).size()
		var 敌成员: Array = []
		for j in 队人数:
			敌成员.append(_造敌方成员("%s·%s" % [敌方名, _宗门战位名(j)], 敌方境界, 敌方单人战力))
		敌方队伍.append(ZongmenBattle.create_team("%s第%d队" % [敌方名, i + 1], 敌成员))
	# 4 我方队伍转战斗快照
	var 我方快照队伍: Array = []
	for i in 我方队伍.size():
		我方快照队伍.append(ZongmenBattle.create_team_from_disciple_list("我方第%d队" % (i + 1), 我方队伍[i]))
	# 5 大阵等级（我方为攻方时读敌方大阵配置；此处按宗门大阵主阵等级给定）
	var 主阵: String = str(宗门大阵.get("当前主阵", ""))
	var 大阵等级: int = int(宗门大阵.get("等级", {}).get(主阵, 1))
	if 大阵等级 < 1:
		大阵等级 = 1
	# 大阵耐久随守方总战力缩放（约 4 回合可破），避免固定 1000 与战力规模脱钩
	var 敌方总战力: int = 敌方单人战力 * 敌方总数
	var 状态: Dictionary = ZongmenBattle.create_battle_state(战斗类型, 我方快照队伍, 敌方队伍, 大阵等级, int(float(敌方总战力) * 0.2))
	# 6 战前增益代入（PRE_BATTLE_BUFFS 常量为准，UI 侧已完成资源扣除）
	for 名 in ZongmenBattle.PRE_BATTLE_BUFFS:
		if bool(增益.get(名, false)):
			状态["攻方增益"].append((ZongmenBattle.PRE_BATTLE_BUFFS[名] as Dictionary).duplicate())
	# 7 推演 + 战报
	ZongmenBattle.simulate_battle(状态)
	var 战报: Dictionary = ZongmenBattle.generate_battle_report(状态)
	结果["战报"] = 战报
	结果["ok"] = true
	# S1-2：参与宗门战（玩家只做「编制+开战」决策，战斗本身全自动推演）
	记任务进度("zongmen_battle")
	if 战报.get("战斗结果", "") == "攻方胜利":
		记任务进度("zongmen_battle_win")   # 预留：宗门战胜利（未来周常可用）
	# 8 结算奖励（类型系数越高，胜赏越厚）
	var 胜: bool = 战报.get("战斗结果", "") == "攻方胜利"
	var 平: bool = 战报.get("战斗结果", "") == "平局"
	var 倍: float = float(宗门战难度系数.get(战斗类型, 1.0))
	var 灵石赏: int = int(round((500 + 门派等级 * 200) * 倍)) if 胜 else (int(round((60 + 门派等级 * 60) * 倍)) if 平 else int(round(20 + 门派等级 * 20)))
	var 声望赏: int = 20 if 胜 else (5 if 平 else 2)
	灵石 += 灵石赏
	if 声望赏 > 0:
		_加声望(声望赏)
	var 额外: String = ""
	if 胜:
		贡献点 += 50
		if randf() < 0.30:
			添加碎片("frag_equip_rare", 1)
			额外 = " 灵品装备碎片+1"
	结果["奖励文本"] = "灵石+%d 声望+%d%s%s" % [灵石赏, 声望赏, " 贡献+50" if 胜 else "", 额外]
	# 9 纪事 + 弟子履历
	var 文案: String = "%s（%s，%d回合）" % ["克敌" if 胜 else ("战平" if 平 else "失利"), 战斗类型, int(战报.get("总回合数", 0))]
	宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "宗门战·%s" % 敌方名, "文案": 文案})
	for 队 in 我方队伍:
		for d in 队:
			d.履历.append("宗门战·%s %s" % [战斗类型, "胜" if 胜 else ("平" if 平 else "败")])
	弟子变动.emit()
	return 结果
# 敌方成员快照（仅宗门战使用；字段对齐 ZongmenBattle._execute_attack 消费口径：
#   战力 / 暴击率 / 闪避率 / 属性{攻,防,血,速}，不触碰 BattleCalculator 72 条红线）
# 四维口径对齐 Disciple.算属性()：练气基准「战力100 / 属性总量≈180」，中性道途权重各 25%
#   → 单项 ≈ 战力 × 1.8 × 0.25 = 战力 × 0.45。禁止臆造比例导致敌我强度错位。
const 敌方属性总量系数: float = 1.8
const 敌方单项权重: float = 0.25
func _造敌方成员(名称: String, 境界: String, 战力: int) -> Dictionary:
	var 总量: int = max(40, int(float(战力) * 敌方属性总量系数))
	var 单项: int = max(10, int(float(总量) * 敌方单项权重))
	return {
		"名称": 名称,
		"弟子ID": "",
		"境界": 境界,
		"最大生命": 单项,
		"当前生命": 单项,
		"战斗属性": {"战力": 战力, "暴击率": 0.05, "闪避率": 0.03,
			"属性": {"攻": 单项, "防": 单项, "血": 单项, "速": 单项}},
	}
func _宗门战位名(序: int) -> String:
	var 位: Array = ["前锋", "前锋", "中坚", "中坚", "后阵"]
	return 位[序] if 序 >= 0 and 序 < 位.size() else "弟子"
# 掉落品质映射：drop_pool.csv 用「凡：良品/上品/极品： 档，item.gd 实例品阶：7 档中文显示名
func _应用掉落品质(it: Item, quality: String):

	var 映射: Dictionary = {"凡品": "凡阶", "良品": "灵阶", "上品": "宝阶", "极品": "王阶"}
	it.品阶 = 映射.get(quality, "凡阶")
# 掉落表行 ：Item；修复「材：碎片误带穿戴位」bug
# 根因：Item.new() ：_init 里随机生成类：穿戴位，掉落仅覆：名称+品阶：
#       灵植/灵材/碎片等掉落偶：roll ：fa_qi 即带装备槽被自动穿上：
# 对策：drop_pool 里只：eq_whole_* 是整装装备，其余掉落全部清空穿戴位并归为灵材：
func _掉落转物品(drop: Dictionary) -> Item:

	var it: Item = Item.new()
	it.名称 = drop.get("item_name") if "item_name" in drop else "掉落"
	_应用掉落品质(it, drop.get("quality") if "quality" in drop else "")
	var item_id: String = drop.get("item_id") if "item_id" in drop else ""
	if not item_id.begins_with("eq_whole_"):
		it.穿戴位 = ""        # 清空→可穿戴()=false，自：手动/一键最优三路均封死
		it.类别 = "ling_cai"  # 归为灵材，内部一：
	_记录图录(it.名称, "掉落")   # WAVE-D #6：掉落即收录图录（阵：天材/灵草 匹配名= 物品名）
	return it
# ============ WAVE-D #6 宗门收藏图录 ============
# 首次获得即收录（来源：掉落物：/ 御兽孵化 / 传承事件）。匹配名 = 物品名/ 灵兽种类名/ 事件键：
# 零经济改动：只读 图录配置 ：收藏图录_已收集：
func _记录图录(匹配名: String, 来源 := "") -> bool:

	if 匹配名== "":
		return false
	var 新收录:= false
	for r in 图录配置:
		if r.get("匹配名") if "匹配名" in r else "" == 匹配名:
			var 类别: String = r.get("类别") if "类别" in r else ""
			if not 收藏图录_已收集.has(类别):
				收藏图录_已收集[类别] = []
			if not 收藏图录_已收集[类别].has(匹配名):
				收藏图录_已收集[类别].append(匹配名)
				新收录= true
				_检查图录类别集(类别)
	if 新收录:
		图录更新.emit()
	return 新收录
# 某类别全：匹配：是否已收录；集齐则解：产出池轴 增益（单：：%，全：：0% via clamp 兜底期
func _检查图录类别集(类别: String):

	var 全部: Array = []
	var 增益值: float = 0.0
	for r in 图录配置:
		if r.get("类别") if "类别" in r else "" == 类别:
			全部.append(r.get("匹配名") if "匹配名" in r else "")
			if 增益值<= 0.0:
				增益值 = float(r.get("增益值") if "增益值" in r else 0.0)
	var 已收: Array = 收藏图录_已收集.get(类别, [])
	for n in 全部:
		if not 已收.has(n):
			return
	if 增益值<= 0.0:
		return
	产出池加成 = clamp(产出池加成 + 增益值, 0.0, 0.30)
	传承史册.append({"日期": 累计游戏日, "弟子": "", "名称": "图录集齐", "文案": 文案表["heritage_codex_complete"] % [类别, int(增益值* 100)], "category": "传承"})
	里程碑更新.emit()
# ============ WAVE-D #8 宗门里程碑/ 传承：============
# 获取所有里程碑列表
func 获取所有里程碑列表() -> Array:
	_加载里程碑配置()
	var 里程碑列表 = []
	for 里程碑 in 里程碑配置:
		里程碑列表.append({
			"里程碑ID": 里程碑.get("里程碑ID", ""),
			"名称": 里程碑.get("名称", ""),
			"描述": 里程碑.get("描述", ""),
			"触发类型": 里程碑.get("触发类型", ""),
			"触发事件": 里程碑.get("触发事件", ""),
			"触发阈值": 里程碑.get("触发阈值", 0),
			"已达成": 里程碑.get("已达成", false),
			"赏赐增益类型": 里程碑.get("赏赐增益类型", ""),
			"赏赐增益值": 里程碑.get("赏赐增益值", 0),
		})
	return 里程碑列表

# 获取里程碑统计
func 获取里程碑统计() -> Dictionary:
	var 已达成数 = 0
	var 总数 = 里程碑配置.size()
	for 里程碑 in 里程碑配置:
		if 里程碑.get("已达成", false):
			已达成数 += 1
	return {
		"已达成数": 已达成数,
		"总数": 总数,
		"完成率": float(已达成数) / float(max(1, 总数)),
	}

# 按触发类型筛选里程碑
func 按触发类型筛选里程碑(触发类型: String) -> Array:
	var 筛选列表 = []
	for 里程碑 in 里程碑配置:
		if 里程碑.get("触发类型", "") == 触发类型:
			筛选列表.append(里程碑)
	return 筛选列表

# 里程碑分类配置
const 里程碑分类配置: Dictionary = {
	"宗门建设": {"描述": "宗门建设相关里程碑", "图标": "🏛️"},
	"弟子培养": {"描述": "弟子培养相关里程碑", "图标": "👨‍🎓"},
	"实力提升": {"描述": "实力提升相关里程碑", "图标": "💪"},
	"财富积累": {"描述": "财富积累相关里程碑", "图标": "💰"},
	"探索发现": {"描述": "探索发现相关里程碑", "图标": "🔍"},
	"特殊事件": {"描述": "特殊事件相关里程碑", "图标": "🎯"},
}

# 按分类筛选里程碑
func 按分类筛选里程碑(分类: String) -> Array:
	var 筛选列表 = []
	for 里程碑 in 里程碑配置:
		if 里程碑.get("分类", "") == 分类:
			筛选列表.append(里程碑)
	return 筛选列表

# 获取里程碑分类统计
func 获取里程碑分类统计() -> Dictionary:
	var 分类统计 = {}
	for 分类 in 里程碑分类配置.keys():
		分类统计[分类] = {
			"总数": 0,
			"已达成数": 0,
			"完成率": 0.0,
		}
	for 里程碑 in 里程碑配置:
		var 分类 = str(里程碑.get("分类", "特殊事件"))
		if 分类 not in 分类统计:
			分类统计[分类] = {"总数": 0, "已达成数": 0, "完成率": 0.0}
		分类统计[分类]["总数"] += 1
		if 里程碑.get("已达成", false):
			分类统计[分类]["已达成数"] += 1
	for 分类 in 分类统计.keys():
		var 统计 = 分类统计[分类]
		统计["完成率"] = float(统计["已达成数"]) / float(max(1, 统计["总数"]))
	return 分类统计

# 里程碑达成历史记录
var 里程碑达成历史: Array = []

# 记录里程碑达成
func _记录里程碑达成(里程碑: Dictionary) -> void:
	里程碑达成历史.append({
		"里程碑ID": 里程碑.get("里程碑ID", ""),
		"名称": 里程碑.get("名称", ""),
		"描述": 里程碑.get("描述", ""),
		"触发类型": 里程碑.get("触发类型", ""),
		"达成日期": 累计游戏日,
		"赏赐增益类型": 里程碑.get("赏赐增益类型", ""),
		"赏赐增益值": 里程碑.get("赏赐增益值", 0),
	})
	# 限制历史记录数量
	if 里程碑达成历史.size() > 100:
		里程碑达成历史.remove_at(0)

# 获取里程碑达成历史
func 获取里程碑达成历史(限制数量: int = 20) -> Array:
	var 历史 = 里程碑达成历史.duplicate()
	历史.reverse()
	return 历史.slice(0, min(限制数量, 历史.size()))

# 获取里程碑进度（未达成里程碑的当前进度）
func 获取里程碑进度(里程碑ID: String) -> Dictionary:
	var 目标里程碑 = null
	for 里程碑 in 里程碑配置:
		if 里程碑.get("里程碑ID", "") == 里程碑ID:
			目标里程碑 = 里程碑
			break
	if 目标里程碑 == null:
		return {"成功": false, "原因": "里程碑不存在"}
	if 目标里程碑.get("已达成", false):
		return {"成功": true, "已达成": true, "进度": 1.0, "当前值": 目标里程碑.get("触发阈值", 0), "目标值": 目标里程碑.get("触发阈值", 0)}
	# 根据触发类型计算当前进度
	var 触发类型 = str(目标里程碑.get("触发类型", ""))
	var 触发事件 = str(目标里程碑.get("触发事件", ""))
	var 目标值 = float(目标里程碑.get("触发阈值", 0))
	var 当前值 = 0.0
	if 触发类型 == "阈值":
		match 触发事件:
			"声望": 当前值 = float(声望)
			"弟子": 当前值 = float(弟子列表.size())
			"门派等级": 当前值 = float(门派等级)
			"阵法": 当前值 = float(已解锁单人法阵.size())
			"灵兽": 当前值 = float(灵兽库存.size())
			"秘境": 当前值 = float(已通关秘境.size())
			"繁荣": 当前值 = float(繁荣)
			"香火": 当前值 = float(香火值)
			"功德": 当前值 = float(功德)
			"业力": 当前值 = float(业力)
			"愿力": 当前值 = float(愿力)
			"累计灵石": 当前值 = float(累计灵石收入)
			"累计丹药": 当前值 = float(累计炼制丹药数)
			"累计装备": 当前值 = float(累计锻造装备数)
			_: 当前值 = 0.0
	var 进度 = 0.0
	if 目标值 > 0:
		进度 = min(1.0, 当前值 / 目标值)
	return {
		"成功": true,
		"已达成": false,
		"里程碑ID": 里程碑ID,
		"名称": 目标里程碑.get("名称", ""),
		"触发类型": 触发类型,
		"触发事件": 触发事件,
		"当前值": 当前值,
		"目标值": 目标值,
		"进度": 进度,
		"剩余": max(0, 目标值 - 当前值),
	}

# 获取所有未达成里程碑的进度
func 获取所有未达成里程碑进度() -> Array:
	var 进度列表 = []
	for 里程碑 in 里程碑配置:
		if not 里程碑.get("已达成", false):
			var 进度 = 获取里程碑进度(里程碑.get("里程碑ID", ""))
			if 进度.get("成功", false):
				进度列表.append(进度)
	# 按进度从高到低排序
	进度列表.sort_custom(func(a, b): return (a.get("进度") if "进度" in a else 0) > (b.get("进度") if "进度" in b else 0))
	return 进度列表

# 传承事件 ：先贤事迹图录收录 + 事件型里程碑达成（键同源：
func _传承事件(事: String):

	_记录图录(事, "事件")
	for m in 里程碑配置:
		if not m.get("已达成") if "已达成" in m else false and m.get("触发类型") if "触发类型" in m else "" == "事件" and m.get("触发事件") if "触发事件" in m else "" == 事:
			_达成里程碑(m)
# 按当前状态复检 阈：状：型里程碑（不调用 _加声望，避免声望里程碑递归：
func _复检里程碑():

	for m in 里程碑配置:
		if m.get("已达成") if "已达成" in m else false:
			continue
		var t: String = m.get("触发类型") if "触发类型" in m else ""
		var k: String = m.get("触发事件") if "触发事件" in m else ""
		var v: float = float(m.get("触发阈值") if "触发阈值" in m else 0)
		var 达成 := false
		if t == "阈值":
			match k:
				"声望": 达成 = 声望 >= v
				"弟子": 达成 = 弟子列表.size() >= v
				"门派等级": 达成 = 门派等级 >= v
				"阵法": 达成 = 已解锁单人法阵.size() >= v
				"灵兽": 达成 = 灵兽库存.size() >= v
				"秘境": 达成 = 已通关秘境.size() >= v
				"繁荣": 达成 = 繁荣 >= v
				"香火": 达成 = 香火值>= v
				"累计灵石": 达成 = 累计灵石收入 >= v
				"累计丹药": 达成 = 累计炼制丹药数 >= v
				"累计装备": 达成 = 累计锻造装备数 >= v
				"功法数量":
					var 已学功法集合: Dictionary = {}
					for d in 弟子列表:
						if d != null:
							var 弟子功法 = d.get("已学功法") if "已学功法" in d else []
							if 弟子功法 != null:
								for gid in 弟子功法:
									已学功法集合[gid] = true
					达成 = 已学功法集合.size() >= v
				"成就数量": 达成 = 成就_已达成.size() >= v
				"里程碑数量": 达成 = 里程碑_已达成.size() >= v
				"体修弟子":
					var 体修数: int = 0
					for d in 弟子列表:
						if d != null and d.get("修炼方向") if "修炼方向" in d else "" == "体修":
							体修数 += 1
					达成 = 体修数 >= v
				"法修弟子":
					var 法修数: int = 0
					for d in 弟子列表:
						if d != null and d.get("修炼方向") if "修炼方向" in d else "" == "法修":
							法修数 += 1
					达成 = 法修数 >= v
				"道修弟子":
					var 道修数: int = 0
					for d in 弟子列表:
						if d != null and d.get("修炼方向") if "修炼方向" in d else "" == "道修":
							道修数 += 1
					达成 = 道修数 >= v
		elif t == "状态":
			match k:
				"筑基": 达成 = _存在已筑基弟子()
				"长寿": 达成 = _存在长寿弟子()
				"长老": 达成 = _存在长老()
				"金丹":
					var 有金丹: bool = false
					for d in 弟子列表:
						if d != null and d.境界 == "金丹":
							有金丹 = true
							break
					达成 = 有金丹
				"元婴":
					var 有元婴: bool = false
					for d in 弟子列表:
						if d != null and d.境界 == "元婴":
							有元婴 = true
							break
					达成 = 有元婴
				"三修并进":
					var 有体修: bool = false
					var 有法修: bool = false
					var 有道修: bool = false
					var 境界顺序: Array = ["练气", "筑基", "金丹", "元婴", "化神"]
					for d in 弟子列表:
						if d != null:
							var 方向: String = str(d.get("修炼方向") if "修炼方向" in d else "")
							var 境界索引: int = 境界顺序.find(d.境界)
							if 境界索引 >= 1:  # 筑基期以上算高阶
								if 方向 == "体修":
									有体修 = true
								elif 方向 == "法修":
									有法修 = true
								elif 方向 == "道修":
									有道修 = true
					达成 = 有体修 and 有法修 and 有道修
		if 达成:
			_达成里程碑(m)
func _达成里程碑(m: Dictionary):

	m["已达成"] = true
	记任务进度("milestone_unlock")   # S1-2：达成宗门里程碑（自动产出，日常 daily_036）
	var id: String = m.get("里程碑ID") if "里程碑ID" in m else ""
	if not 里程碑_已达成.has(id):
		里程碑_已达成.append(id)
	var 类型: String = m.get("赏赐增益类型") if "赏赐增益类型" in m else ""
	var 值: float = float(m.get("赏赐增益值") if "赏赐增益值" in m else 0)
	if 类型 == "产出":
		产出池加成 = clamp(产出池加成 + 值, 0.0, 0.30)
	elif 类型 == "声望":
		_加声望(int(声望))   # 复用现有 声望 变量与乘区；绝不：凝聚力（16 审计 ：零运行时：
	_记录图录(m.get("名称") if "名称" in m else "")   # WAVE-D D-2/F1：里程碑 名称 与先贤事迹图：匹配：同构，达成时一并收录，使六类图录全可达
	传承史册.append({"日期": 累计游戏日, "弟子": "", "名称": "里程碑", "文案": m.get("史册文案") if "史册文案" in m else "", "category": "传承"})
	# 联动纪事大事件（拍板结论2）：达成时同步写入「宗门大事件」分类，与传承史册并：
	宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "里程碑达成",
		"文案": 文案表["milestone_reached"] % [m.get("名称") if "名称" in m else "", _里程碑奖励描述(m)],
		"category": "宗门大事件"})
	里程碑更新.emit()
# 获取所有成就列表
func 获取所有成就列表() -> Array:
	_加载成就配置()
	var 成就列表 = []
	for 成就 in 成就配置:
		成就列表.append({
			"achievement_id": 成就.get("achievement_id", ""),
			"名称": 成就.get("名称", ""),
			"描述": 成就.get("描述", ""),
			"稀有度": 成就.get("稀有度", "普通"),
			"condition_type": 成就.get("condition_type", ""),
			"condition_param": 成就.get("condition_param", 0),
			"已达成": 成就.get("已达成", false),
			"奖励灵石": 成就.get("奖励灵石", 0),
			"奖励灵气": 成就.get("奖励灵气", 0),
			"奖励声望": 成就.get("奖励声望", 0),
		})
	return 成就列表

# 获取成就统计
func 获取成就统计() -> Dictionary:
	var 已达成数 = 0
	var 总数 = 成就配置.size()
	var 总奖励灵石 = 0
	var 总奖励灵气 = 0
	var 总奖励声望 = 0
	for 成就 in 成就配置:
		if 成就.get("已达成", false):
			已达成数 += 1
		总奖励灵石 += int(成就.get("奖励灵石", 0))
		总奖励灵气 += int(成就.get("奖励灵气", 0))
		总奖励声望 += int(成就.get("奖励声望", 0))
	return {
		"已达成数": 已达成数,
		"总数": 总数,
		"完成率": float(已达成数) / float(max(1, 总数)),
		"总奖励灵石": 总奖励灵石,
		"总奖励灵气": 总奖励灵气,
		"总奖励声望": 总奖励声望,
	}

# 按稀有度筛选成就
func 按稀有度筛选成就(稀有度: String) -> Array:
	var 筛选列表 = []
	for 成就 in 成就配置:
		if 成就.get("稀有度", "") == 稀有度:
			筛选列表.append(成就)
	return 筛选列表

# 成就分类配置
const 成就分类配置: Dictionary = {
	"经营": {"描述": "宗门经营相关成就", "图标": "🏪"},
	"成长": {"描述": "弟子成长相关成就", "图标": "📈"},
	"战斗": {"描述": "战斗历练相关成就", "图标": "⚔️"},
	"收集": {"描述": "收集图鉴相关成就", "图标": "📚"},
	"社交": {"描述": "社交互动相关成就", "图标": "👥"},
	"探索": {"描述": "探索秘境相关成就", "图标": "🗺️"},
	"特殊": {"描述": "特殊隐藏成就", "图标": "✨"},
}

# 按分类筛选成就
func 按分类筛选成就(分类: String) -> Array:
	var 筛选列表 = []
	for 成就 in 成就配置:
		if 成就.get("分类", "") == 分类:
			筛选列表.append(成就)
	return 筛选列表

# 获取成就分类统计
func 获取成就分类统计() -> Dictionary:
	var 分类统计 = {}
	for 分类 in 成就分类配置.keys():
		分类统计[分类] = {
			"总数": 0,
			"已达成数": 0,
			"完成率": 0.0,
		}
	for 成就 in 成就配置:
		var 分类 = str(成就.get("分类", "特殊"))
		if 分类 not in 分类统计:
			分类统计[分类] = {"总数": 0, "已达成数": 0, "完成率": 0.0}
		分类统计[分类]["总数"] += 1
		if 成就.get("已达成", false):
			分类统计[分类]["已达成数"] += 1
	for 分类 in 分类统计.keys():
		var 统计 = 分类统计[分类]
		统计["完成率"] = float(统计["已达成数"]) / float(max(1, 统计["总数"]))
	return 分类统计

# 获取成就进度（未达成成就的当前进度）
func 获取成就进度(成就ID: String) -> Dictionary:
	var 目标成就 = null
	for 成就 in 成就配置:
		if 成就.get("achievement_id", "") == 成就ID:
			目标成就 = 成就
			break
	if 目标成就 == null:
		return {"成功": false, "原因": "成就不存在"}
	if 目标成就.get("已达成", false):
		return {"成功": true, "已达成": true, "进度": 1.0, "当前值": 目标成就.get("condition_param", 0), "目标值": 目标成就.get("condition_param", 0)}
	# 根据条件类型计算当前进度
	var 条件类型 = str(目标成就.get("condition_type", ""))
	var 目标值 = float(目标成就.get("condition_param", 0))
	var 当前值 = 0.0
	match 条件类型:
		"弟子数量":
			当前值 = float(弟子列表.size())
		"门派等级":
			当前值 = float(门派等级)
		"声望":
			当前值 = float(声望)
		"累计灵石":
			当前值 = float(累计灵石收入)
		"累计丹药":
			当前值 = float(累计炼制丹药数)
		"累计装备":
			当前值 = float(累计锻造装备数)
		"灵兽数量":
			当前值 = float(灵兽库存.size())
		"秘境通关":
			当前值 = float(已通关秘境.size())
		"阵法数量":
			当前值 = float(已解锁单人法阵.size())
		"功法数量":
			var 已学功法集合 = {}
			for d in 弟子列表:
				if d != null:
					var 弟子功法 = d.get("已学功法") if "已学功法" in d else []
					if 弟子功法 != null:
						for 功法 in 弟子功法:
							已学功法集合[功法.get("功法ID", "")] = true
			当前值 = float(已学功法集合.size())
		_:
			当前值 = 0.0
	var 进度 = 0.0
	if 目标值 > 0:
		进度 = min(1.0, 当前值 / 目标值)
	return {
		"成功": true,
		"已达成": false,
		"成就ID": 成就ID,
		"名称": 目标成就.get("名称", ""),
		"条件类型": 条件类型,
		"当前值": 当前值,
		"目标值": 目标值,
		"进度": 进度,
		"剩余": max(0, 目标值 - 当前值),
	}

# 获取所有未达成成就的进度
func 获取所有未达成成就进度() -> Array:
	var 进度列表 = []
	for 成就 in 成就配置:
		if not 成就.get("已达成", false):
			var 进度 = 获取成就进度(成就.get("achievement_id", ""))
			if 进度.get("成功", false):
				进度列表.append(进度)
	# 按进度从高到低排序
	进度列表.sort_custom(func(a, b): return (a.get("进度") if "进度" in a else 0) > (b.get("进度") if "进度" in b else 0))
	return 进度列表

# 领取成就奖励
func 领取成就奖励(成就ID: String) -> Dictionary:
	var 目标成就 = null
	for 成就 in 成就配置:
		if 成就.get("achievement_id", "") == 成就ID:
			目标成就 = 成就
			break
	if 目标成就 == null:
		return {"成功": false, "原因": "成就不存在"}
	if not 目标成就.get("已达成", false):
		return {"成功": false, "原因": "成就未达成"}
	# 检查是否已领取奖励
	var 已领取成就奖励 = 已领取成就奖励 if "已领取成就奖励" in self else []
	if 成就ID in 已领取成就奖励:
		return {"成功": false, "原因": "奖励已领取"}
	# 发放奖励
	var 奖励灵石 = int(目标成就.get("奖励灵石", 0))
	var 奖励灵气 = int(目标成就.get("奖励灵气", 0))
	var 奖励声望 = int(目标成就.get("奖励声望", 0))
	灵石 += 奖励灵石
	灵气 += 奖励灵气
	if 奖励声望 > 0:
		_加声望(奖励声望)
	# 记录已领取
	if "已领取成就奖励" not in self:
		self.已领取成就奖励 = []
	已领取成就奖励.append(成就ID)
	添加纪事("成就", "领取奖励", "领取成就【%s】奖励：灵石+%d，灵气+%d，声望+%d" % [目标成就.get("名称", ""), 奖励灵石, 奖励灵气, 奖励声望], 1)
	return {"成功": true, "成就": 目标成就, "奖励灵石": 奖励灵石, "奖励灵气": 奖励灵气, "奖励声望": 奖励声望, "消息": "领取奖励成功"}

# 已领取成就奖励列表
var 已领取成就奖励: Array = []

# 里程碑奖励描述（文案拼接，不新增文案字段）：声望+30 / 产出：2%
func _里程碑奖励描述(m: Dictionary) -> String:

	var t: String = str(m.get("赏赐增益类型") if "赏赐增益类型" in m else "")
	var v: float = float(m.get("赏赐增益值") if "赏赐增益值" in m else 0)
	if t == "声望":
		return "声望+%d" % int(v)
	elif t == "产出":
		return "产出：%d%%" % int(v * 100)
	return "宗门增益"
# ============ S1 ： 成就系统（核心骨：安全子集：===========
# 13 condition_type ：int 阈值；19 ：S1 接线（成：经营： 145 ：placeholder 容错跳过
# 奖励：优先读 3 个标准资源字段（灵石/灵气/声望），：reward_id 发奖逻辑 S1 注释掉（S2 待启用）
# 稀有及以上：宗门纪事 category="宗门大事件（与里程碑范式同构）
func _复检成就():

	for a in 成就配置:
		if a.get("已达成") if "已达成" in a else false:
			continue
		var t: String = a.get("condition_type") if "condition_type" in a else "placeholder"
		if t == "placeholder":
			continue   # S2 待回填，命中即跳：
		var p: int = int(a.get("condition_param") if "condition_param" in a else 0)
		var extra: String = a.get("condition_extra") if "condition_extra" in a else ""
		var 达成 := false
		match t:
			"sect_level":
				达成 = 门派等级 >= p
			"disciple_count":
				达成 = 弟子列表.size() >= p
			"disciple_realm_count":
				var cnt: int = 0
				for d in 弟子列表:
					if d != null and d.境界 == extra:
						cnt += 1
				达成 = cnt >= p
			"disciple_all_realm":
				# 全宗弟子境界：：extra（境界序复用 主线_境界序）
				if 弟子列表.size() > 0:
					var 境界顺序: Array = ["练气", "筑基", "金丹", "元婴", "化神", "仙阶", "道阶"]
					var 目标值: int = 境界顺序.find(extra)
					if 目标值>= 0:
						var 全达成:= true
						for d in 弟子列表:
							if d == null or 境界顺序.find(d.境界) < 目标值:
								全达成= false
								break
						达成 = 全达成
			"disciple_linggen":
				var cnt2: int = 0
				for d in 弟子列表:
					if d != null and d.灵根品阶 == extra:
						cnt2 += 1
				达成 = cnt2 >= p
			"master_realm":
				达成 = _宗主境界() >= p
			"beast_count":
				达成 = 灵兽库存.size() >= p
			"building_level":
				var lv: int = int(司职列表.get(extra, {}).get("等级", 1))
				达成 = lv >= p
			"building_any_level":
				var any_ok := false
				for k in 司职列表.keys():
					if int(司职列表[k].get("等级", 1)) >= p:
						any_ok = true
						break
				达成 = any_ok
			"building_total_level":
				var total: int = 0
				for k in 司职列表.keys():
					total += int(司职列表[k].get("等级", 1))
				达成 = total >= p
			"reputation":
				达成 = 声望 >= p
			"prosperity":
				达成 = 繁荣 >= p
			# ===== S1 新增 condition_type（2026-08-30 成就系统完善第二阶段）=====
			"zhenfa_count":
				# 已解锁阵法数量
				var 已解锁阵法: Dictionary = 宗门大阵.get("已解锁", {})
				达成 = 已解锁阵法.size() >= p
			"zhenfa_level":
				# 特定阵法等级（extra=阵法ID）
				var 阵法等级表: Dictionary = 宗门大阵.get("等级", {})
				var 某阵法等级: int = int(阵法等级表.get(extra, 0))
				达成 = 某阵法等级 >= p
			"daily_checkin_streak":
				# 连续领取日供天数
				达成 = 连续理事天数 >= p
			"daily_checkin_total":
				# 累计领取日供次数
				达成 = 日供_总领取次数 >= p
			"achievement_count":
				# 已达成成就数量
				达成 = 成就_已达成.size() >= p
			"game_days":
				# 累计游戏天数
				达成 = 累计游戏日 >= p
			# ===== S1 新增 condition_type（2026-08-30 第三阶段）=====
			"total_pill_refined":
				# 累计炼制丹药数量
				达成 = 累计炼制丹药数 >= p
			"total_equipment_forged":
				# 累计锻造装备数量
				达成 = 累计锻造装备数 >= p
			"total_lingjing_income":
				# 累计灵石收入
				达成 = 累计灵石收入 >= p
			"total_disciple_recruited":
				# 累计招募弟子数量
				达成 = 累计招募弟子数 >= p
			"total_breakthrough_count":
				# 累计弟子突破次数
				达成 = 累计弟子突破次数 >= p
			"total_market_trades":
				# 累计坊市交易次数
				达成 = 累计坊市交易次数 >= p
			"gongfa_collected":
				# 功法收集数量（所有弟子学习的不同功法总数）
				var 已学功法集合: Dictionary = {}
				for d in 弟子列表:
					if d != null:
						var 弟子功法 = d.get("已学功法") if "已学功法" in d else []
						if 弟子功法 != null:
							for gid in 弟子功法:
								已学功法集合[gid] = true
				达成 = 已学功法集合.size() >= p
			"forge_level":
				# 炼器等级
				达成 = 获取炼器等级() >= p
			# ===== S1 新增 condition_type（2026-08-30 第四阶段）=====
			"total_lingtian_output":
				# 累计灵田产出数量
				达成 = 累计灵田产出 >= p
			"total_kuangchang_output":
				# 累计矿场产出数量
				达成 = 累计矿场产出 >= p
			"total_linggen_upgrade":
				# 累计提升灵根次数
				达成 = 累计提升灵根次数 >= p
			"total_xinjing_upgrade":
				# 累计提升心境次数
				达成 = 累计提升心境次数 >= p
			"total_shouyuan_extend":
				# 累计延长寿元次数
				达成 = 累计延长寿元次数 >= p
			"total_daoshang_repair":
				# 累计修复道伤次数
				达成 = 累计修复道伤次数 >= p
			"disciple_max_xinjing":
				# 弟子最高心境值
				var 最高心境: int = 0
				for d in 弟子列表:
					if d != null:
						var 心境值: int = int(d.get("心境") if "心境" in d else 0)
						if 心境值 > 最高心境:
							最高心境 = 心境值
				达成 = 最高心境 >= p
			"disciple_tixiu_count":
				# 体修弟子数量
				var 体修数: int = 0
				for d in 弟子列表:
					if d != null and d.get("修炼方向") if "修炼方向" in d else "" == "体修":
						体修数 += 1
				达成 = 体修数 >= p
			"disciple_faxiu_count":
				# 法修弟子数量
				var 法修数: int = 0
				for d in 弟子列表:
					if d != null and d.get("修炼方向") if "修炼方向" in d else "" == "法修":
						法修数 += 1
				达成 = 法修数 >= p
			"disciple_daoxiu_count":
				# 道修弟子数量
				var 道修数: int = 0
				for d in 弟子列表:
					if d != null and d.get("修炼方向") if "修炼方向" in d else "" == "道修":
						道修数 += 1
				达成 = 道修数 >= p
			"disciple_three_cultivation":
				# 同时拥有三类高阶弟子（体修/法修/道修各至少1名达到特定境界）
				var 有体修: bool = false
				var 有法修: bool = false
				var 有道修: bool = false
				var 境界顺序: Array = ["练气", "筑基", "金丹", "元婴", "化神"]
				var 目标境界索引: int = 1  # 筑基期以上算高阶
				for d in 弟子列表:
					if d != null:
						var 方向: String = str(d.get("修炼方向") if "修炼方向" in d else "")
						var 境界索引: int = 境界顺序.find(d.境界)
						if 境界索引 >= 目标境界索引:
							if 方向 == "体修":
								有体修 = true
							elif 方向 == "法修":
								有法修 = true
							elif 方向 == "道修":
								有道修 = true
				达成 = 有体修 and 有法修 and 有道修
			"disciple_max_realm":
				# 弟子最高境界（p=境界索引，0=练气，1=筑基，2=金丹...）
				var 最高境界索引: int = -1
				var 境界顺序2: Array = ["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体"]
				for d in 弟子列表:
					if d != null:
						var idx: int = 境界顺序2.find(d.境界)
						if idx > 最高境界索引:
							最高境界索引 = idx
				达成 = 最高境界索引 >= p
			"disciple_dajingjie_count":
				# 达到大境界（筑基及以上）的弟子数量
				var 大境界数: int = 0
				var 境界顺序3: Array = ["练气", "筑基", "金丹", "元婴", "化神"]
				for d in 弟子列表:
					if d != null:
						var idx: int = 境界顺序3.find(d.境界)
						if idx >= 1:  # 筑基及以上算大境界
							大境界数 += 1
				达成 = 大境界数 >= p
			# ===== S1 新增 condition_type（2026-08-30 第五阶段）=====
			"total_puppet_made":
				# 累计制作傀儡数量
				达成 = 累计制作傀儡数 >= p
			"total_salary_paid":
				# 累计发放俸禄次数
				达成 = 累计发放俸禄次数 >= p
			"library_book_count":
				# 藏书阁收录典籍数量
				达成 = 藏书阁收录数 >= p
			"medicine_garden_plots":
				# 药园已解锁地块数量
				达成 = 药园已解锁地块 >= p
			"unlocked_pill_formula_count":
				# 已解锁丹方数量
				达成 = 已解锁丹方数 >= p
			"unlocked_equipment_blueprint_count":
				# 已解锁装备图纸数量
				达成 = 已解锁装备图纸数 >= p
			"all_factions_worship":
				# 五大阵营声望全部达到崇拜（崇敬）
				var 全部崇拜: bool = true
				for 阵营 in 阵营列表:
					var 声望值: int = int(阵营声望.get(阵营, 0))
					if 声望值 < 5000:  # 崇敬阈值
						全部崇拜 = false
						break
				达成 = 全部崇拜
			"pill_and_equipment_all":
				# 集齐全部丹药配方与装备图纸
				达成 = (已解锁丹方数 >= p) and (已解锁装备图纸数 >= p)
			_:
				达成 = false   # 未知 condition_type 视为不达成，安全容错
		if 达成:
			_达成成就(a)
func _达成成就(a: Dictionary):

	a["已达成"] = true
	记任务进度("achievement_unlock")   # S1-2：达成成就（自动产出，日常 daily_035）
	var id: String = a.get("achievement_id") if "achievement_id" in a else ""
	if id != "" and not 成就_已达成.has(id):
		成就_已达成.append(id)
	# 奖励：优先读 3 个标准资源字段（q-1 拍板：灵：灵气/声望；功勋非标准资源，不发）
	var rls: int = int(a.get("reward_lingshi") if "reward_lingshi" in a else 0)
	var rlq: int = int(a.get("reward_lingqi") if "reward_lingqi" in a else 0)
	var rsw: int = int(a.get("reward_shengwang") if "reward_shengwang" in a else 0)
	if rls > 0:
		灵石 += rls
	if rlq > 0:
		灵气 += rlq
	if rsw > 0:
		_加声望(rsw)   # 复用现有 声望 变量与乘区（_功勋阁声望乘区）
	# ：reward_id 发奖逻辑 S1 注释掉（q-1 拍板：S2 待启用；130 悬空 reward_id 容错跳过：
	var rid: String = a.get("reward_id") if "reward_id" in a else ""
	if rid != "" and rls == 0 and rlq == 0 and rsw == 0:
		print("[成就] 悬空奖励跳过: id=%s reward_type=%s reward_id=%s S2 待启用" % [id, a.get("reward_type") if "reward_type" in a else "", rid])
	# 稀有及以上成就额外奖励：碎片和宝箱
	var grade: String = a.get("grade") if "grade" in a else ""
	if grade == "稀有":
		# 稀有成就：普通宝箱×1 + 凡品装备碎片×3
		添加宝箱("chest_common", 1)
		添加碎片("frag_equip_common", 3)
	elif grade == "史诗":
		# 史诗成就：稀有宝箱×1 + 灵品装备碎片×3
		添加宝箱("chest_rare", 1)
		添加碎片("frag_equip_rare", 3)
	elif grade == "传说":
		# 传说成就：史诗宝箱×1 + 宝品装备碎片×3 + 灵品功法碎片×2
		添加宝箱("chest_epic", 1)
		添加碎片("frag_equip_epic", 3)
		添加碎片("frag_gongfa_rare", 2)
	# 稀有及以上：宗门纪事 category="宗门大事件（拍板结论：与里程碑联动同构：
	if grade == "稀有" or grade == "史诗" or grade == "传说":
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": grade, "名称": a.get("ach_name") if "ach_name" in grade else "",
			"文案": "宗门达成%s】，道统更进一步" % a.get("ach_name") if "ach_name" in grade else "",
			"category": "宗门大事件"})
	成就更新.emit()
func _存在已筑基弟子() -> bool:

	for d in 弟子列表:
		if d.境界 != "练气":
			return true
	return false
func _存在长老() -> bool:

	for d in 弟子列表:
		if d.身份 == "长老":
			return true
	return false
func _存在长寿弟子() -> bool:
	for d in 弟子列表:
		if d.年龄 >= 100:
			return true
	return false
# WAVE-D #6：稀有藏品捐赠藏宝库 ：声望（复用现：声望，不落凝聚力：
func 捐赠图录(图录ID: String) -> Dictionary:

	var res: Dictionary = {"ok": false, "msg": ""}
	if 捐赠记录.has(图录ID):
		res["msg"] = "该藏品已捐赠"
		return res
	for r in 图录配置:
		if r.get("图录ID") if "图录ID" in r else "" == 图录ID:
			if r.get("是否稀有") if "是否稀有" in r else "否" != "是":
				res["msg"] = "非稀有藏品，不可捐赠"
				return res
			var 声望值: int = int(r.get("捐赠声望") if "捐赠声望" in r else 0)
			if 声望值> 0:
				_加声望(声望值)
				捐赠记录[图录ID] = true
			res["ok"] = true
			res["msg"] = "捐赠成功，声望+%d" % 声望值
			图录更新.emit()
			return res
	res["msg"] = "未找到该藏品"
	return res
# 体力上限：初：50，门派每：1 ：+5
func 体力上限() -> int:

	return 50 + (门派等级 - 1) * 5
# 综合能力判定（资：修为/装备/属：性格/命格：
func _判定成败(d: Disciple) -> bool:

	var 率: float = d.修炼速度 * 0.3 + (d.总战力() / 1000.0) * 0.3
	率 += d.属性["悟性"] * 0.001 + d.属性["根骨"] * 0.001
	# 奇遇型命格首发不生效（S1 接入）；此处不再按命格名硬编码加：
	if d.性格 == "谨慎多疑" or d.性格 == "贪心逐缘":
		率+= 0.1
	return randf() < clamp(率, 0.1, 0.95)
# 资源殿阁产出（原「司职产出」；首发文案统一称资源殿阁，底层司职数据保留：
func _资源殿阁产出():

	# 阶段2：清零本月各资源殿阁产出额记录（供殿阁被动概率翻倍时直接加回：
	_本月灵田产出 = 0
	_本月矿脉产出 = 0
	_本月丹堂产出 = 0
	_本月器殿产出 = 0
	var 经营基数: Dictionary = {"lingtian": 5, "kuangmai": 4, "dantang": 3, "qitang": 3, "cangjing": 2, "zhifa": 2, "gongxun": 2, "tanwei": 2, "yuying": 1, "yushou": 1, "zhenfa": 1, "xichi": 1}
	# P0-BUILD-2：灵田负责人 ：全殿阁灵石产：+1%
	var 产出buff: float = 汇总负责人全局buff().get("产出", 0.0)
	var 经营加成_total: float = 0.0   # F3：全殿阁经营加成汇总池封顶 0.30（产出效率池 §4.1：
	for key in 司职列表.keys():
		var 职: Dictionary = 司职列表[key]
		var 成员 := 职["成员"] as Array
		var n: int = 成员.size()
		if n == 0:
			continue
		# 经营型命格：弟子驻守殿阁时生效，乘性加成产：
		var 经营加成: float = 0.0
		for m in 成员:
			var 弟子 := m as Disciple
			var 命格数据: Dictionary = DestinyDataLoader.get_destiny(弟子.destiny_id)
			if 命格数据.get("类型", "") == "经营" and 命格数据.get("维度", "") == "产出":
				经营加成 += float(命格数据.get("数量:", 0)) / 100.0
		经营加成 = clamp(经营加成, 0.0, 0.20)   # F3 单殿阁经营加成封顶（产出效率池§4.1，独：clamp 不接 economy_balance：
		经营加成_total += 经营加成
		经营加成_total = clamp(经营加成_total, 0.0, 0.30)   # F3 全殿阁汇总封：
		var base: int = 经营基数.get(key, 1)
		var 气运乘: float = (1.0 + 气运产出加成) if (累计游戏日 < 气运到期日) else 1.0
		# P0-BUILD-4：宗门等级：殿阁产出乘区：级无加成：0：+18%，数值克制）
		var 等级乘区: float = 1.0 + 0.02 * max(0, 门派等级 - 1)
		# 宗主皮肤全宗灵石加成
		var 产出值: int = 0
		var 宗主灵石系数: float = 1.0
		if has_method("取宗主皮肤全宗加成"):
			var _宗主加成: Dictionary = 取宗主皮肤全宗加成()
			var _灵石加成: float = float(_宗主加成.get("灵石", 0))
			if _灵石加成 > 0:
				宗主灵石系数= (1.0 + _灵石加成 / 100.0)
			# 气运乘区说明：
			#   气运乘 = 老气运buff（限时祥瑞类，天品灵根/突破触发，修炼+3%/产出+2%，持7日）
			#   (1+获取气运产出加成()) = 新气运系统（综合香火速率/愿力/功德/业力，持续生效，±10%）
			# 两个乘区来源不同、叠加生效：限时祥瑞是短期爆发，新气运是长期状态
			产出值 = int(n * base * (1.0 + 经营加成) * 气运乘 * (1.0 + 获取气运产出加成()) * (1.0 + 产出buff + 彩蛋产出加成() + 产出池加成 * 等级乘区 * 宗主灵石系数 * _殿阁等级_乘区(key)))
			灵石 += 产出值
		# S1 ： D7 解锁①：Lv.2+ 保底津贴（与成员产出叠加，结构性产出）
		if int(职.get("等级", 1)) >= 2:
			灵石 += int(职.get("等级", 1)) * 殿阁保底津贴
		# 阶段2：记录各资源殿阁本月实际产出额，：_殿阁被动结算 概率翻倍（灵草丰收/富矿/额外丹元/器魂）时直接加回
		# 资源系统补全（偏：3）：灵田/矿脉除普适灵石外，额外产出专属材料，：S1 丹器消：
		match key:
			"lingtian":
				_本月灵田产出 = 产出值
				灵草 += 产出值
				灵气 += int(ceil(产出值* 0.5))   # 灵气减半产出（老大拍板 2026-07-21）：初期不溢出，核心产出仍以灵草为主
			"kuangmai":
				_本月矿脉产出 = 产出值
				矿石 += 产出值
				灵晶 += int(产出值 * 0.5)   # P0-3：灵晶产出（原恒0致装备强化必失败）；随矿脉开采凝结
			"dantang":
				_本月丹堂产出 = 产出值
			"qitang":
				_本月器殿产出 = 产出值
	灵石 += 弟子列表.size() * 2
	# Step 1 三场景接入：资源产出为「宗门内」奇遇触发点之一（与弟子修炼共用宗门内池：
	# 受全局冷却约束，单次推演至多触发一条）：
	for d in 弟子列表:
		_尝试触发奇遇(d, "宗门")
# ============ 殿阁产出预览（P0-BUILD-4：纯计算，不实际发资源）============
# 供殿阁总览 UI 顶部「预计月产出」与单殿阁卡片预览使用；：_资源殿阁产出 计算逻辑一致，
# 额外乘入「宗门等级乘区：1.0 + 0.02 * max(0, 门派等级 - 1))。不修改任何状态：
func 预估殿阁产出(key: String) -> int:

	if not 司职列表.has(key):
		return 0
	var 职: Dictionary = 司职列表[key]
	var 成员: Array = 职["成员"]
	var n: int = 成员.size()
	if n == 0:
		return 0
	# 经营基数 ：_资源殿阁产出 保持一致（占位殿阁统一口径：
	var 经营基数: Dictionary = {"lingtian": 5, "kuangmai": 4, "dantang": 3, "qitang": 3, "cangjing": 2, "zhifa": 2, "gongxun": 2, "tanwei": 2, "yuying": 1, "yushou": 1, "zhenfa": 1, "xichi": 1}
	var 产出buff: float = 汇总负责人全局buff().get("产出", 0.0)
	var 等级乘区: float = 1.0 + 0.02 * max(0, 门派等级 - 1)
	var 气运乘: float = (1.0 + 气运产出加成) if (累计游戏日 < 气运到期日) else 1.0
	var 经营加成: float = 0.0
	for m in 成员:
		var 弟子: Disciple = m as Disciple
		var 命格数据: Dictionary = DestinyDataLoader.get_destiny(弟子.destiny_id)
		if 命格数据.get("类型", "") == "经营" and 命格数据.get("维度", "") == "产出":
			经营加成 += float(命格数据.get("数量", 0)) / 100.0
	经营加成 = clamp(经营加成, 0.0, 0.20)   # F3 预览单殿阁封顶（与结算一致，独立 clamp 不接 economy_balance：
	var base: int = 经营基数.get(key, 1)
	var 保底: int = int(职.get("等级", 1)) * 殿阁保底津贴 if int(职.get("等级", 1)) >= 2 else 0
	return int(n * base * (1.0 + 经营加成) * 气运乘 * (1.0 + 产出buff + 产出池加成 * 等级乘区 * _殿阁等级_乘区(key)) + 保底)
func 预估月产出() -> int:

	var 额: int = 0
	for key in 司职列表.keys():
		额+= 预估殿阁产出(key)
	额+= 弟子列表.size() * 2
	return 额
# ============ 殿阁被动结算（阶：：占位殿阁被动功能）============
# ：推演一月「资源产出之后、推演条目汇总之前」调用：
# 各殿阁独：roll，互不影响；绝不污染奇遇池（不使：奇遇发生 signal / event_quest / quest.gd）：
# 资源翻倍类（灵：矿脉/丹堂/器殿）的翻倍额已在 _资源殿阁产出 记录：_本月XX产出：
#   此处直接加回（避免重复计：经营/气运/产出 乘区），命中即写推演条目：
func _殿阁被动结算():

	# [DORMANT] 聚合负面事件减免（暂存，当前无负：入侵事件系统消费；未来接入即可生效）
	殿阁被动_负面事件减免 = _负面事件减免()
	# 灵田 8%：灵草丰收，当月灵石产出翻倍
	if _本月灵田产出 > 0 and randf() < 0.08:
		灵石 += _本月灵田产出
		_加推演条目(文案表["hall_lingtian_harvest"], ET_RESOURCE, PRIO_NORMAL, {"殿阁": "lingtian"})
	# 矿脉 7%：富矿现世，当月灵石产出翻倍
	if _本月矿脉产出 > 0 and randf() < 0.07:
		灵石 += _本月矿脉产出
		_加推演条目("【矿脉】富矿现世，灵石产出翻倍！", ET_RESOURCE, PRIO_NORMAL, {"殿阁": "kuangmai"})
	# 丹堂 15%：额外丹元（灵石翻倍计入）+ 子概：30% 生成随机低阶丹药入弟子储物袋
	if _本月丹堂产出 > 0 and randf() < 0.15:
		灵石 += _本月丹堂产出
		_加推演条目(文案表["hall_dantang_refine"], ET_RESOURCE, PRIO_NORMAL, {"殿阁": "dantang"})
		if not 弟子列表.is_empty() and randf() < 0.30:
			var 得主: Disciple = 弟子列表[randi() % 弟子列表.size()]
			var 物: Item = _造低阶物品("dan_yao", "凡阶")
			得主.背包.append(物)
			宗门纪事.append({"日期": 累计游戏日, "弟子": 得主.姓名, "弟子ID": 得主.弟子ID, "稀有度": "殿阁被动", "名称": "丹堂赠丹", "文案": 文案表["hall_dantang_gift"] % [得主.名称, 得主.姓名]})
			_加推演条目(文案表["hall_dantang_extra"] % [得主.名称, 得主.姓名], ET_LOOT, PRIO_NORMAL, {"殿阁": "dantang"})
	# 器殿赠宝（P0 配置驱动梯度：+ P1 分配权重/保底/冗余 + P2 轻量堂主加成：
	if _本月器殿产出 > 0:
		# --- P2 轻量堂主加成：仅 1 层判断（匠心命格负责人）---
		var 触发率: float = 0.12
		var 稀有概率: float = 0.10
		var 器殿主: Variant = 司职列表.get("qitang", {}).get("负责：", null)
		if 器殿主!= null and 器殿主.destiny_id == "D_JIANGXIN":
			触发率= 0.15
			稀有概率= 0.15
		if randf() < 触发率:
			灵石 += _本月器殿产出
			_加推演条目(文案表["hall_qidian_craft"], ET_RESOURCE, PRIO_NORMAL, {"殿阁": "qitang"})
			# --- P0 读配置梯度池 ---
			var 器殿等级: int = int(司职列表.get("qitang", {}).get("等级", 1))
			var 配置行: Array = _读器殿赠宝行(器殿等级)
			var 普通行: Array = []
			var 稀有行: Array = []
			for 行 in 配置行:
				if 行.get("pool_type", "") == "rare":
					稀有行.append(行)
				else:
					普通行.append(行)
			if 普通行.is_empty() and 稀有行.is_empty():
				# 配置缺失兜底：沿用老体验（残破铜镜），保证零回：
				if not 弟子列表.is_empty():
					var 兜底得主: Disciple = _选器殿赠宝得主()
					if 兜底得主 != null:
						var 兜底期: Item = _造低阶物品("fabao", "凡阶")
						兜底得主.背包.append(兜底期)
						宗门纪事.append({"日期": 累计游戏日, "弟子": 兜底得主.姓名, "弟子ID": 兜底得主.弟子ID, "稀有度": "殿阁被动", "名称": "器殿赠宝", "文案": 文案表["hall_qidian_forge"] % [兜底得主.名称, 兜底得主.姓名]})
						_加推演条目(文案表["hall_qidian_extra"] % [兜底得主.名称, 兜底得主.姓名], ET_LOOT, PRIO_NORMAL, {"殿阁": "qitang"})
						_器殿赠宝_记录上阵(兜底得主)
			else:
				var 选池: Array = 普通行
				if not 稀有行.is_empty() and randf() < 稀有概率:
					选池 = 稀有行
				if 选池.is_empty():
					if not 普通行.is_empty():
						选池 = 普通行
					else:
						选池 = 稀有行
				var 命中: Dictionary = _加权抽配置行(选池)
				var 数量: int = randi_range(int(命中.get("count_min", 1)), int(命中.get("count_max", 1)))
				var 得主: Disciple = _选器殿赠宝得主()
				if 得主 != null:
					var 样器: Item = _造器殿赠宝物(命中)   # 仅用于冗余判定（品类/品阶：
					var 冗余: bool = (样器.类别 == "fabao") and 得主.装备.has("本命法宝") and _品阶不小于(得主.装备["本命法宝"].品阶, 样器.品阶)
					if 冗余:
						# P1 冗余：法宝同品阶及以上已持有 ：拆解折算阵纹碎片入背包（不建仓库：
						_发放阵纹碎片(得主, 数量)
						宗门纪事.append({"日期": 累计游戏日, "弟子": 得主.姓名, "弟子ID": 得主.弟子ID, "稀有度": "殿阁被动", "名称": "器殿赠宝·拆解", "文案": 文案表["hall_gift_overlap"] % [得主.姓名, 数量]})
						_加推演条目(文案表["hall_qidian_overlap"] % [数量], ET_LOOT, PRIO_NORMAL, {"殿阁": "qitang"})
					else:
						for _i in range(数量):
							得主.背包.append(_造器殿赠宝物(命中))
						宗门纪事.append({"日期": 累计游戏日, "弟子": 得主.姓名, "弟子ID": 得主.弟子ID, "稀有度": "殿阁被动", "名称": "器殿赠宝", "文案": "器殿赐下【%s】（%d份），赐予%s" % [命中.get("item_name", ""), 数量, 得主.姓名]})
						_加推演条目("【器殿】赐下%s】（%d份），赐予%s" % [命中.get("item_name", ""), 数量, 得主.姓名], ET_LOOT, PRIO_NORMAL, {"殿阁": "qitang"})
					_器殿赠宝_记录上阵(得主)
	# 藏经：8%：悟道机缘，随机 1 名弟子小幅修：境界进度加成
	if 司职列表.has("cangjing") and not 弟子列表.is_empty() and randf() < 0.08:
		var 悟道值: Disciple = 弟子列表[randi() % 弟子列表.size()]
		悟道值.推进修炼(3, 1.05)   # 小量天数 + 轻微加成
		_加推演条目(文案表["hall_cangjing_insight"] % [悟道值.姓名, 悟道值.境界], ET_SECT, PRIO_NORMAL, {"殿阁": "cangjing"})
	# 探微：10%：情报奇遇，额外灵石 + 推演条目
	if 司职列表.has("tanwei") and randf() < 0.10:
		灵石 += randi_range(30, 80)
		_加推演条目(文案表["hall_tanwei_clue"], ET_INFO, PRIO_NORMAL, {"殿阁": "tanwei"})
	# 执事：5%：慕名来投，额外生成 1 名随机弟子加入宗门（复用现有随机弟子创建：
	if 司职列表.has("yuying") and randf() < 0.05:
		var 新徒: Disciple = Disciple.new()
		新徒.司职 = "yuying"
		弟子列表.append(新徒)
		弟子变动.emit()
		_加推演条目(文案表["hall_zhishi_join"], ET_APPOINT, PRIO_NORMAL, {"殿阁": "yuying"})
	# 洗髓：1%：洗髓机缘（随机 1 名弟：提升命格品质 OR 清除负面性格，二选一随机：
	if 司职列表.has("xichi") and not 弟子列表.is_empty() and randf() < 0.01:
		_洗髓机缘()
# S1 点击联动 MVP：物品key ：造物参数（类： 品阶），：main.gd::_解析实体 ：key 重建展示模板 Item：
# ：_解析并发放奇遇赏：：key 口径对齐；资源类 key（lingshi/lingcao/kuangshi/lingqi）不入表（详情不适用）：
# MVP 仅收录已落地：dan_low；后续实体系统落地后在此增量扩展即可：
var _物品定义表: Dictionary= {
	"dan_low": ["dan_yao", "凡阶"],
}
# 获取所有本命法宝列表（从弟子背包中筛选）
func 获取所有本命法宝列表() -> Array:
	var 法宝列表 = []
	for d in 弟子列表:
		if d == null:
			continue
		for 物品 in d.背包:
			if 物品 != null and 物品.穿戴位 == "本命法宝":
				法宝列表.append({
					"名称": 物品.名称,
					"品阶": 物品.品阶,
					"类别": 物品.类别,
					"战力": 物品.战力,
					"所属弟子": d.姓名,
					"已装备": 物品.已装备,
				})
	return 法宝列表

# 获取本命法宝统计
func 获取本命法宝统计() -> Dictionary:
	var 法宝列表 = 获取所有本命法宝列表()
	var 已装备数 = 0
	var 总战力 = 0
	for 法宝 in 法宝列表:
		if 法宝.get("已装备", false):
			已装备数 += 1
		总战力 += int(法宝.get("战力", 0))
	return {
		"总数": 法宝列表.size(),
		"已装备数": 已装备数,
		"总战力": 总战力,
		"平均战力": int(总战力 / 法宝列表.size()) if 法宝列表.size() > 0 else 0,
	}

# 获取弟子当前装备的本命法宝
func 获取弟子本命法宝(弟子ID: int) -> Dictionary:
	for d in 弟子列表:
		if d != null and d.弟子ID == 弟子ID:
			for 物品 in d.背包:
				if 物品 != null and 物品.穿戴位 == "本命法宝" and 物品.已装备:
					return {
						"名称": 物品.名称,
						"品阶": 物品.品阶,
						"类别": 物品.类别,
						"战力": 物品.战力,
						"所属弟子": d.姓名,
					}
	return {}

# 造一枚指定类：品阶的物品（殿阁被动掉落用；仅填模板+算战力，不污染战斗数值红线）
func _造低阶物品(类别: String, 品阶: String) -> Item:

	var it: Item = Item.new()
	it.类别 = 类别
	it.品阶 = 品阶
	it.穿戴位 = ""
	it.道途 = ""
	if 类别 == "dan_yao" and it.基础库.has("dan_yao") and it.基础库["dan_yao"].has(品阶):
		it._填模板(it.基础库["dan_yao"][品阶][0])
	elif 类别 == "fabao" and it.基础库.has("fabao") and it.基础库["fabao"].has(品阶):
		it.穿戴位= "本命法宝"
		it._填模板(it.基础库["fabao"][品阶][0])
	it.滚词缀()
	it.滚极品()
	it.算战力()
	return it
# ============ 器殿赠宝（Task #28：P0 配置梯度：+ P1 分配权重/保底/冗余 + P2 堂主加成：===========
# 以下 helper 仅供 _殿阁被动结算 的器殿分支调用，零触碰战斗核心（BattleCalculator/BattleManager 未引用）：
# 品阶秩（凡阶→道阶），用于冗余判定「同品阶及以上」。独立于 item.gd 内部序，避免跨文件耦合：
var _品阶: Dictionary = {"凡阶": 0, "灵阶": 1, "宝阶": 2, "王阶": 3, "圣阶": 4, "仙阶": 5, "道阶": 6}
func _品阶不小于(a: String, b: String) -> bool:

	var ia: int = _品阶.get(a, -1)
	var ib: int = _品阶.get(b, -1)
	if ia < 0 or ib < 0:
		return false
	return ia >= ib
# 懒加：craft_hall_reward.csv（路径与 _加载阵法物品_S1 同款范式：
func _加载器殿赠宝表() -> void:

	if not _器殿赠宝表.is_empty():
		return
	_器殿赠宝表= DestinyDataLoader._read_csv("res://config/craft_hall_reward.csv")
# 按器殿等级筛出命中的配置行（落入 [level_min, level_max]：
func _读器殿赠宝行(等级: int) -> Array:

	_加载器殿赠宝表()
	var 命中: Array = []
	for r in _器殿赠宝表:
		var lo: int = int(r.get("level_min") if "level_min" in r else 1)
		var hi: int = int(r.get("level_max") if "level_max" in r else 1)
		if 等级 >= lo and 等级 <= hi:
			命中.append(r)
	return 命中
# 加权抽一行（：weight 列归一化；weight ：CSV 字符串，：float：
func _加权抽配置行(行列表: Array) -> Dictionary:

	var 总权: float = 0.0
	for r in 行列表:
		总权+= float(r.get("weight") if "weight" in r else 0)
	if 总权<= 0:
		return 行列表[0] if 行列表.size() > 0 else {}
	var 权: float = randf() * 总权
	for r in 行列表:
		权-= float(r.get("weight") if "weight" in r else 0)
		if 权<= 0:
			return r
	return 行列表[行列表.size() - 1]
# P0：按 item_id 实例化（复用 阵法物品表+ 通用掉落转换 _掉落转物品，保证 name 命中阵法闭环）：
# 不复：main.gd::_解析实体：其 item/equip 分支仅认 _物品定义：dan_low)，不处理 array_items ：item_id：
func _按id造(item_id: String) -> Item:

	if 阵法物品表.is_empty():
		_加载阵法物品_S1()
	var row: Dictionary = 阵法物品表.get(item_id, {})
	if row.is_empty():
		var 兜底: Item = Item.new()
		兜底.名称 = item_id
		return 兜底
	return _掉落转物品({"item_id": item_id, "item_name": row.get("item_name") if "item_name" in row else item_id, "quality": row.get("item_grade") if "item_grade" in row else ""})
# 统一实例化一行赠宝（gen→_造低阶物品/ id→_按id造）
func _造器殿赠宝物(物: Dictionary) -> Item:

	if 物.get("ref_type", "gen") == "id":
		return _按id造(物.get("item_ref", ""))
	return _造低阶物品(物.get("item_ref", "fabao"), 物.get("grade", "凡阶"))
# P1：按权重档选得主（T1 匠心+上阵 > T2 上阵 > T3 内门及以上> T4 外门）：
# 保底：_器殿赠宝未中上阵连计： 时强制只从上阵档(T1/T2)选，并重置计数器：
func _选器殿赠宝得主() -> Disciple:

	if 弟子列表.is_empty():
		return null
	var 强制上阵: bool = _器殿赠宝未中上阵连计 >= 3
	if 强制上阵:
		_器殿赠宝未中上阵连计 = 0   # 强制档已消耗，重置（防连续强制：
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
			continue   # 强制档只取上阵者；非上阵者本档跳：
		if 有匠心 and 是上阵:
			T1.append(d)
		elif 是上阵:
			T2.append(d)
		elif Disciple.身份层级序.find(d.身份) >= 1:   # 内门及以上（内门弟子/核心弟子/亲传弟子/长老）
			T3.append(d)
		else:
			T4.append(d)
	var 候选: Array = []
	if not T1.is_empty():
		候选= T1
	elif not T2.is_empty():
		候选= T2
	elif not T3.is_empty():
		候选= T3
	elif not T4.is_empty():
		候选= T4
	else:
		候选= 弟子列表   # 极端兜底（不应发生）
	return 候选[randi() % 候选.size()]
# P1：保底计数器更新（得主∈上阵→归零，否则+1：
func _器殿赠宝_记录上阵(得主: Disciple):

	if 得主 == null:
		return
	if 得主.姓名 in _上次出战弟子:
		_器殿赠宝未中上阵连计 = 0
	else:
		_器殿赠宝未中上阵连计 += 1
# 洗髓池机缘：随机 1 名弟：提升命格品质 OR 清除负面性格（二选一随机：
func _洗髓机缘():

	var d: Disciple = 弟子列表[randi() % 弟子列表.size()]
	var 当前品级: String = DestinyDataLoader.get_destiny(d.destiny_id).get("品级", "凡品")
	var 阶: Array = DestinyDataLoader.品级枚举
	var idx: int = 阶.find(当前品级)
	var 高品级池: Array = []
	if idx >= 0 and idx + 1 < 阶.size():
		var 高档: String = 阶[idx + 1]
		高品级池 = DestinyDataLoader.ids_by_grade().get(高档, [])
	var 做了: bool = false
	if not 高品级池.is_empty() and randf() < 0.5:
		var 高档名: String = 阶[idx + 1]
		d.destiny_id = 高品级池[randi() % 高品级池.size()]
		d._应用命格养成加成()
		宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": "殿阁被动", "名称": "命格重塑", "文案": "洗髓池机缘，【%s】命格品质提升（%s→%s）。" % [d.姓名, 当前品级, 高档名]})
		_加推演条目(文案表["hall_xichi_uplift"] % [d.姓名], ET_SECT, PRIO_NORMAL, {"殿阁": "xichi"})
		做了 = true
	else:
		var 负面: Array = ["孤僻清修", "狂傲绝世"]
		if d.性格 in 负面:
			var 中性: Array = ["沉稳守道", "恬淡悟道", "仁心济世", "守礼尊师"]
			var 新性格: String = 中性[randi() % 中性.size()]
			宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": "殿阁被动", "名称": "性格洗练", "文案": 文案表["hall_xichi_cleanse"] % [d.姓名, d.性格, 新性格]})
			d.性格 = 新性格
			_加推演条目(文案表["hall_xichi_purify"] % [d.姓名], ET_SECT, PRIO_NORMAL, {"殿阁": "xichi"})
			做了 = true
		elif not 高品级池.is_empty():
			var 高档名: String = 阶[idx + 1]
			d.destiny_id = 高品级池[randi() % 高品级池.size()]
			d._应用命格养成加成()
			宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": "殿阁被动", "名称": "命格重塑", "文案": "洗髓池机缘，【%s】命格品质提升（%s→%s）。" % [d.姓名, 当前品级, 高档名]})
			_加推演条目(文案表["hall_xichi_uplift"] % [d.姓名], ET_SECT, PRIO_NORMAL, {"殿阁": "xichi"})
			做了 = true
	# 注：若弟子已为投放最高品：极品，天品未投放)且性格非负面，则本次机缘无实质收益（极罕见，不写条目）
# ============ 司职系统 ============
# === S1 ：：殿阁等级乘：+ 上限 + 升级消耗（清单公式；清单误：已落"，实际须创建：==
func _殿阁等级_乘区(key: String) -> float:

	var 等级: int = int(司职列表.get(key, {}).get("等级", 1))
	return 1.0 + 0.02 * max(0, 等级 - 1)     # 等级=1 ：1.0（零回归）；每级 +2%
func _殿阁等级上限() -> int:

	return min(门派等级, 7)                   # 门派等级 1~10 封顶 7；凡：1)→上：（不可升：
func _升级消耗_灵石(当前等级: int) -> int:

	return int(ceil(120.0 * pow(1.3, float(当前等级 - 1))))   # S2-1 调平：原 200×1.5^(L-1) 指数导致 L3→4 回本≈83月；现 120×1.3^(L-1) 使各级回本趋近 ≤12月（可按经济实测再调）
func 重建司职():

	司职列表 = {}
	for key in Lore.司职定义.keys():
		var def: Dictionary = Lore.司职定义[key]
		司职列表[key] = {
			"key": key, "名称": def["名称"], "职能": def["职能"],
			"产出": def["产出"], "加成维度": def["加成维度"],
			"负责人": null, "成员": [], "负责人锁定": false,
		# === S1 端口：殿阁等：任期政绩字段（当前恒为默认，S1 接入升级/政绩累计：==
		# 字段：等级":1（殿阁等级，S1 升级：1，乘区桩 _殿阁等级_乘区 随之生效：| "政绩":0（主事任期政绩累积，dormant：
		# 重建语义：重建自 Lore，不持久化（每次启动重算；S1 须改为持久化或独立存档）
		# 依赖：殿阁等级体系（§一： 负责人锁定机制（§一 任期政绩行
			"等级": 1, "政绩": 0,
		}
	for d in 弟子列表:
		if d.司职 != "":
			_注册入堂(d)
	应用负责人存档()
	应用司职状态存档()   # S1 ：：回：等级/政绩（load/新游戏后还原，防重启清零：
func _在司职(key: String, d: Disciple) -> bool:

	var 成员 := 司职列表[key]["成员"] as Array
	for m in 成员:
		if (m as Disciple) == d:
			return true
	return false
func _注册入堂(d: Disciple):

	if d.司职 == "" or not 司职列表.has(d.司职):
		return
	if _在司职(d.司职, d):
		return
	(司职列表[d.司职]["成员"] as Array).append(d)
	# 负责人按加成高者优先自动任命：为空取最高分；新成员更高则替换（含掌门手定后被超越的情况：
	# P0-BUILD-2：已锁定的岗位不参与自动顶替（手动任：解除：任命负责人/ 解除负责人锁定）
	var 维度: String = 司职列表[d.司职]["加成维度"]
	var 现负责: Disciple = 司职列表[d.司职]["负责人"]
	var 现分 := -1.0
	if 现负责!= null:
		现分 = 现负责.加成评分(维度)
	var 已锁定: bool = 司职列表[d.司职].get("负责人锁定", false)
	if not 已锁定 and (现负责== null or d.加成评分(维度) > 现分):
		var 旧负责 = 现负责
		_设负责人(d.司职, d)
		if 旧负责 != null:
			宗门纪事.append({"日期": 累计游戏日, "弟子": 旧负责.姓名, "弟子ID": 旧负责.弟子ID, "稀有度": "宗门", "名称": "人事变动", "文案": "【人事%s】主事由%s接替%s" % [司职列表[d.司职]["名称"], d.姓名, 旧负责.姓名]})
func _设负责人(key: String, d: Disciple):

	# S1 ：：仅当主事实际变更（旧主事存在且非同一人）：政绩清零 + 里程：事件标记重置（新任期）：
	# 初始任命(：null)/应用负责人存：读档)/解除锁定 不触发清零（EC-P2~P4）：
	var 旧主事: Variant = 司职列表[key].get("负责人", null)
	司职列表[key]["负责人"] = d
	司职负责人存档[key] = d.姓名
	if 旧主事 != null and 旧主事 != d:
		司职列表[key]["政绩"] = 0
		var _st: Dictionary = 司职状态存档.get(key, {})
		_st["里程碑"] = 0
		_st["高政绩事件"] = false
		司职状态存档[key] = _st
# 掌门任命负责人（UI 调用：
func 任命负责人(key: String, d: Disciple):

	if not 司职列表.has(key):
		return
	# S1 ：：阶位门槛闸（additive；legacy 阶位已按身份给到对应阶位，veteran 不被误拦，：.2：
	if d.阶位索引() < int(司职阶位门槛.get(key, 0)):
		return false
	_设负责人(key, d)
	司职列表[key]["负责人锁定"] = true
	宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": "宗门", "名称": "人事任命", "文案": "【人事%s】被任命为%s主事" % [d.姓名, 司职列表[key]["名称"]]})
	_加推演条目("【人事%s】被任命为【%s】主事" % [d.姓名, 司职列表[key]["名称"]], ET_APPOINT, PRIO_NORMAL, {"弟子": d.姓名, "司职": key})
	弟子变动.emit()
func 应用负责人存档():

	for key in 司职负责人存档.keys():
		var 负: String = 司职负责人存档[key]
		var d: Disciple = _按姓名找(负)
		if d != null and 司职列表.has(key):
			司职列表[key]["负责人"] = d
# P0-BUILD-2：汇总所有「有负责人的殿阁」的全局微量 buff（每：+1%，按 加成维度→全局buff 映射累加）：
# 返回字典（数值为小数，表示百分比）：：：血/：修炼/产出/测灵根
# 无负责人 ：：0 ：各应用点乘区 = 1.0，不改变任何数值（保证 test_combat 等数值红线不被触碰）：
func 汇总负责人全局buff() -> Dictionary:

	var buff: Dictionary = {"：": 0.0, "职": 0.0, "血": 0.0, "zh": 0.0, "修炼": 0.0, "产出": 0.0, "测灵": 0.0}
	# 殿阁 key ：全局 buff 维度 映射（功勋阁/御兽：洗髓：本项无负责人 buff，属阶段2：
	var 映射: Dictionary = {
		"qitang": "：", "kuangmai": "zh", "zhenfa": "：",
		"dantang": "血", "zhifa": "：", "tanwei": "职",
		"cangjing": "修炼", "lingtian": "产出", "yuying": "测灵",
	}
	for key in 司职列表.keys():
		var 维: Dictionary = 司职列表[key]
		var 负责: Variant = 维.get("负责人", null)
		if 负责 == null:
			continue
		var 维度: String = 映射.get(key, "")
		if 维度 != "":
			buff[维度] = float(buff.get(维度, 0.0)) + (0.02 if int(维.get("等级", 1)) >= 4 else 0.01)
	# 阶段2：阵殿常驻防：+1%（与「负责人1%」叠加，阵殿防御贡献 = 负责：% + 常驻1% = 最：%：
	if 司职列表.has("zhenfa"):
		buff["："] = float(buff.get("：") if "：" in buff else 0.0) + 0.01
	return buff
# P0-BUILD-2：解除负责人锁定（供阶段3 UI 调用；本次不：UI）。runtime-only，不写入存档：
func 解除负责人锁定(key: String):

	if not 司职列表.has(key):
		return
	司职列表[key]["负责人锁定"] = false
	宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "人事解锁", "文案": "【人事】解锁%s主事锁定" % 司职列表[key]["名称"]})
# ============ S1 ：：殿阁升级+ 任期政绩（§二 / §三）============
func 升级殿阁(key: String) -> Dictionary:

	if not 司职列表.has(key):
		return {"ok": false, "msg": "殿阁不存在"}
	var 等级: int = int(司职列表[key].get("等级", 1))
	var 上限: int = _殿阁等级上限()
	if 等级 >= 上限:
		return {"ok": false, "msg": "已达等级上限（需更高宗门品级）"}
	if 门派等级 < 2:
		return {"ok": false, "msg": "需灵阶及以上宗门解锁殿阁升阶"}
	var 费: int = _升级消耗_灵石(等级)
	if 灵石 < 费:
		return {"ok": false, "msg": "灵石不足（需 %d灵石）" % [费]}
	灵石 -= 费
	司职列表[key]["等级"] = 等级 + 1
	_存司职状态(key)
	宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "殿阁升级",
		"文案": "【营建%s】修缮至 Lv.%d，产出增益" % [司职列表[key]["名称"], 等级 + 1]})
	_加推演条目("【营建%s】升至 Lv.%d" % [司职列表[key]["名称"], 等级 + 1], ET_SECT, PRIO_NORMAL, {"殿阁": key})
	记任务进度("upgrade_building")   # S1-2：升级产业殿阁（玩家决策，日常 daily_009 / 周常 weekly_008）
	return {"ok": true, "msg": "%s 升至 Lv.%d，消耗%d灵石" % [司职列表[key]["名称"], 等级 + 1, 费]}
## 判断是否有可升级的殿阁
func 有可升级殿阁() -> bool:
	if 门派等级 < 2:
		return false
	var 上限: int = _殿阁等级上限()
	for key in 司职列表.keys():
		var 职: Dictionary = 司职列表[key]
		var 等级: int = int(职.get("等级", 1))
		if 等级 >= 上限:
			continue
		var 费: int = _升级消耗_灵石(等级)
		if 灵石 >= 费:
			return true
	return false
func _存司职状态(key: String) -> void:

	var s: Dictionary = 司职状态存档.get(key, {})
	s["等级"] = int(司职列表[key].get("等级", 1))
	s["政绩"] = int(司职列表[key].get("政绩", 0))
	s["里程碑"] = int(s.get("里程碑") if "里程碑" in s else 0)
	s["高政绩事件"] = bool(s.get("高政绩事件") if "高政绩事件" in s else false)
	司职状态存档[key] = s
func 应用司职状态存档() -> void:

	for key in 司职状态存档.keys():
		if 司职列表.has(key):
			var s: Dictionary = 司职状态存档.get(key, {})
			司职列表[key]["等级"] = int(s.get("等级") if "等级" in s else 1)
			司职列表[key]["政绩"] = int(s.get("政绩") if "政绩" in s else 0)
# S1 ：：任期政绩月度累积（仅在主事在任时；续任保留手动，不自动到期：
func _累计任期政绩() -> void:

	var 政绩基数: Dictionary = {
		"lingtian": 1, "kuangmai": 1, "yuying": 1,
		"cangjing": 2, "dantang": 2, "qitang": 2, "zhifa": 2, "gongxun": 2, "tanwei": 2,
		"zhenfa": 3, "yushou": 3, "xichi": 3, "wudao": 3,
	}
	for key in 司职列表.keys():
		var 职: Dictionary = 司职列表[key]
		var 负责: Variant = 职.get("负责人", null)
		if 负责 == null:
			continue                              # 无主：：不累积（任期空窗：
		var 月增: int = int(政绩基数.get(key, 1))
		职["政绩"] = int(职.get("政绩", 0)) + 月增
		_累计政绩赏赐(key)
		_存司职状态(key)
# S1 ：：政绩里程碑 + 高政绩事件（仅产：声望，零战力：
func _累计政绩赏赐(key: String) -> void:

	var 政绩: int = int(司职列表[key].get("政绩", 0))
	var s: Dictionary = 司职状态存档.get(key, {})
	var 里程碑: int = int(s.get("里程碑") if "里程碑" in s else 0)
	var 阈值: int = 12                              # [PLACEHOLDER]
	while 政绩 >= (里程碑+ 1) * 阈值 and 里程碑< 100:
		里程碑+= 1
		设置气运buff(0.0, 0.01, 3)                  # 产出+1% ×3日（复用 L774 气运管线：
		_加推演条目(文案表["hall_achievement_good"] % [司职列表[key]["名称"]], ET_SECT, PRIO_TRIVIAL, {"殿阁": key})
	s["里程碑"] = 里程碑
	# 高政绩特殊事件（一次性，防重启刷奖须持久化标记）
	if not bool(s.get("高政绩事件") if "高政绩事件" in s else false) and 政绩 >= 36:   # 高阈：[PLACEHOLDER]
		s["高政绩事件"] = true
		声望 += 50                                  # [PLACEHOLDER]
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "政绩卓著",
			"文案": 文案表["hall_achievement_great"] % [司职列表[key]["名称"], 50]})
		_加推演条目("【政绩%s】主事政绩卓著，誉满宗门！" % 司职列表[key]["名称"], ET_SECT, PRIO_HIGH, {"殿阁": key})
	司职状态存档[key] = s
# ============ S1 ：：阶位轴晋升试炼（§四：===========
# 判断某弟子是否满足破格晋升条件（D5）：极品/天品灵根 · 经营命格 · 声望≥阈值且立大：
func 满足破格条件(d: Disciple) -> bool:

	if d.灵根品阶 in ["极品", "天品"]:
		return true
	if d.有特殊命格():
		return true
	if 声望 >= 破格声望阈值 and 立大功标记.has(d.姓名):
		return true
	return false
# 某阶位当前占用数（遍：弟子列表 统计行
func 阶位名额占用(阶位名: String) -> int:

	var n: int = 0
	for x in 弟子列表:
		if x.阶位 == 阶位名:
			n += 1
	return n
# 某阶位名额上限（门派等级 L 驱动，：.4；全：[PLACEHOLDER]：
func 阶位名额上限(阶位名: String) -> int:

	var L: int = 门派等级
	match 阶位名:
		"执事": return 2 + L
		"堂主": return 1 + int(L / 2)
		"长老": return int(L / 3)
		"供奉": return int(L / 5)
		_: return 0
# 发起单次试炼（玩家手动）。成：失败走掷骰，二次校验名额/冷却/贡献。返回结：Dict：
func 发起试炼(d: Disciple) -> Dictionary:

	var 结果: Dictionary = {"ok": false, "成功": false, "原因": "", "贡献扣减": 0}
	if not d.可授阶():
		结果["原因"] = "该弟子身份不足（须内门及以上）"
		return 结果
	if d.试炼冷却剩余 > 0:
		结果["原因"] = "试炼冷却中（剩余 %d 日）" % d.试炼冷却剩余
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
	if 贡献点< 试炼成本:
		结果["原因"] = "贡献点不足（需 %d 贡献点）" % [试炼成本]
		return 结果
	贡献点-= 试炼成本
	结果["贡献扣减"] += 试炼成本
	if randf() < d.试炼成功率():
		d.阶位 = 目标阶位
		d.试炼心得 = false
		结果["ok"] = true
		结果["成功"] = true
		_晋升仪式感(d)
	else:
		d.试炼冷却剩余 = 试炼冷却日
		d.试炼心得 = true
		贡献点-= 试炼失败扣减
		结果["贡献扣减"] += 试炼失败扣减
		宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": "宗门", "名称": "阶位试炼", "文案": "【试炼者%s】晋阶%s失利，需再磨砺" % [d.姓名, 目标阶位]})
	结果["阶位"] = d.阶位
	return 结果
# 晋升仪式感：纪事永录 + 推演条目 + 全宗士气临时加成（复：设置气运buff(buff，：.7：
func _晋升仪式感(d: Disciple):

	宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": "宗门", "名称": "阶位晋升", "文案": "【晋升者%s】晋升者阶位·%s" % [d.姓名, d.阶位]})
	_加推演条目("【晋升%s】阶位·%s" % [d.姓名, d.阶位], ET_APPOINT, PRIO_NORMAL, {"弟子": d.姓名, "阶位": d.阶位})
	match d.阶位:
		"堂主", "长老": 设置气运buff(0.02, 0.01, 3)
		"供奉": 设置气运buff(0.03, 0.02, 7)
# 批量试炼：逐人独立掷骰，独立判定冷：名额/贡献（：.5：
func 批量试炼(list: Array) -> Dictionary:

	var 汇总: Dictionary = {"成功": [], "失败": [], "跳过": [], "贡献扣减": 0}
	for d in list:
		if not (d is Disciple):
			continue
		var r: Dictionary = 发起试炼(d)
		汇总["贡献扣减"] += int(r.get("贡献扣减") if "贡献扣减" in r else 0)
		if r.get("成功"):
			汇总["成功"].append(d.姓名)
		elif r.get("ok"):
			汇总["失败"].append(d.姓名)
		else:
			汇总["跳过"].append({"弟子": d.姓名, "原因": r.get("原因") if "原因" in r else ""})
	return 汇总
# 罢免阶位（降级一级，不走掷骰、不耗贡献，§4.6：
func 罢免阶位(d: Disciple) -> Dictionary:

	var 结果: Dictionary = {"ok": false, "原因": ""}
	if d.阶位 == "：":
		结果["原因"] = "该弟子本无阶位"
		return 结果
	var idx: int = d.阶位索引()
	var 新idx: int = idx - 1
	d.阶位 = ("外门" if 新idx < 0 else d.阶位层级序[新idx])
	结果["ok"] = true
	宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": "宗门", "名称": "罢免阶位", "文案": "【罢免者%s】被罢去阶位，现任阶位·%s" % [d.姓名, d.阶位]})
	return 结果
func _按姓名找(名: String) -> Disciple:

	for d in 弟子列表:
		if d.姓名 == 名:
			return d
	return null
# ============ 测灵根招收仪：============
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

	# 冷却检：
	var 距上次: int = 累计游戏日- 上次测灵日
	if 上次测灵日> 0 and 距上次< 测灵根冷却日:
		var 剩余: int = 测灵根冷却日 - 距上次
		return {"人数": 0, "过场": "", "新徒": [], "冷却剩余": 剩余}
	# 正式举办
	Disciple.解锁道途池 = 已解锁道途()
	var N: int = 5 + int(门派等级 / 2) + int(声望 / 500)
	N = clamp(N, 5, 20)
	var 新徒: Array[Disciple] = []
	var 已强制天品: bool = false
	# === S1 ：-B：首次确保字派序列已生成（旧档空 ：本次生成并持久化），供新弟子道号取字 ===
	_确保字派_S1()
	# P0-BUILD-2：执事殿负责：：测灵高品质概率+1%；阶：：执事殿常驻：+2%（最高3%：
	var 测灵buff: float = 汇总负责人全局buff().get("测灵", 0.0) + _执事殿测灵加()
	var d: Disciple
	for i in N:
		d = Disciple.new()
		d.司职 = "yuying"   # 执事殿候补，筑基后转入职能：
		d.来源 = Disciple.弟子来源池.pick_random()
		var 抽取阵营: String = 加权抽取阵营("")
		if 抽取阵营 == "正道宗门" and randf() < 0.4:
			d.性格 = ["正直", "善良", "沉稳"].pick_random()
		elif 抽取阵营 == "魔道邪宗" and randf() < 0.4:
			d.性格 = ["邪恶", "狡诈", "浮躁"].pick_random()
		elif 抽取阵营 == "中立散修" and randf() < 0.3:
			d.性格 = ["孤僻", "合群", "愚钝"].pick_random()
		elif 抽取阵营 == "上古妖兽" and randf() < 0.3:
			d.性格 = ["勇敢", "怯懦"].pick_random()
		elif 抽取阵营 == "远古遗泽" and randf() < 0.3:
			d.性格 = ["聪慧", "沉稳"].pick_random()
		# 调试：强制天品（保证批次：名天品弟子，便于验证破格流程：
		if 强制天品 and not 已强制天品:
			d.灵根 = "天灵根"; d.灵根品阶 = "天品"; d.身份 = "核心弟子"
			已强制天品 = true
		# 身份破格：天品→核心弟子 / 极品→内门弟子（仅标记，不改司职流水线）
		elif d.灵根品阶 == "天品":
			d.身份 = "核心弟子"
		elif d.灵根品阶 == "极品":
			d.身份 = "内门弟子"
		# D7：全局：3 名新徒默认内门（防卡进度；仅改创建时初始值，不动身份轴逻辑/存档：
		if 弟子列表.size() + i < 3 and d.身份 == "外门":
			d.身份 = "内门弟子"
		# P0-BUILD-2：执事殿负责：：测灵高品质概率+1%（触发时灵根品阶升一档，已为天品则跳过）
		if 测灵buff > 0.0 and d.灵根品阶 != "天品" and randf() < 测灵buff:
			_提升灵根品阶一档(d)
		# P3 气运：招募高品质概率随气运增减（昌隆+10%升一档；衰败则仅无加成，不动降档以免引入未定义函数）
		var 气运招募: float = 获取气运招募加成()
		if 气运招募 > 0.0 and d.灵根品阶 != "天品" and randf() < 气运招募:
			_提升灵根品阶一档(d)
	if d.灵根品阶 in ["天品", "极品", "上品"]:   # P1：高品质新弟子计入周期评：
		周期评分.记高品质新弟子()
	# === S1 ：-B：新弟子道号简化生成（[PLACEHOLDER] 简化版：外：辈分字派[0]+单字：==
	d.辈分序= 0   # 默认开山第1：
	if d.身份 == "外门" and not 辈分字派.is_empty():
		d.道号 = 辈分字派[0] + (d.姓名.left(1) if d.姓名.length() > 0 else "")
	# 其余阶位道号暂留：""（玩家可改）；[PLACEHOLDER] 命名规则：GDD §：2
	弟子列表.append(d)
	新徒.append(d)
	# P0 目标链：弟子招收 ：recruit_count（newbie_001 主动： recruit_count_5（newbie_007 状态）
	_新手_检查条件("recruit_count")
	_新手_评估后续()
	# === S1 端口：新弟子制式装备/入职包发：===
	# 调用位置：举办测灵根() 弟子创建循环末尾（d ：append ：弟子列表/新徒 之后）：
	# 入参（S1 实装时）：d: Disciple（新弟子：
	# 副作用（S1 实装后）：d.背包.append(制式法宝一：+ 基础修炼功法 + 初级制式储物：，可：身份/阶位 分档配发
	# 依赖：最轻量，可独立于殿：资源体系先行（见 §：新弟子入职包）。状态：仅注释标记，未调用任何函数：
	_加声望(N)
	上次测灵日= 累计游戏日  # 更新冷却时间：
	# 天品灵根弟子 ：破格：写宗门纪事 + 触发全宗气运 buff：：修炼+3%/产出+2%：
	for 徒 in 新徒:
		if 徒.灵根品阶 == "天品":
			宗门纪事.append({"日期": 累计游戏日, "弟子": 徒.姓名, "弟子ID": 徒.弟子ID, "稀有度": "天品", "名称": "天品灵根弟子", "文案": 文案表["recruit_tianpin_found"] % [徒.姓名]})
			设置气运buff(0.03, 0.02, 7)
			立大功标记[徒.姓名] = true   # D5：天品接：= 立大功（运行时态标记，支持声望破格：
			break
	_注册全部()
	var 有天品: bool = false
	for 新弟子 in 新徒:
		if 新弟子.灵根品阶 == "天品":
			有天品 = true
			break
	var 过场: String = Lore.取测灵根过场(N, 新徒, 有天品)
	弟子变动.emit()
	return {"人数": N, "过场": 过场, "新徒": 新徒}
func _注册全部():

	for d in 弟子列表:
		if d.司职 != "":
			_注册入堂(d)
# ============ 门派等级 / 声望 / 繁荣 ============
const 门派等级上限: int = 10   # P0 ：10 级（S1 赛季接入殿阁等级体系后可上调：
func 更新门派():

	var 总战力:= 0
	for d in 弟子列表:
		总战力+= d.总战力()
	# P0 等效公式（复用现有字段，零新增底层）：弟子基础 > 战力核心 > 秘境进度 > 声望补充
	var 新等级: int = 1 + int(弟子列表.size() / 12) + int(总战力/ 20000) + int(已通关秘境.size() / 10) + int(声望 / 500)
	新等级 = clamp(新等级, 1, 门派等级上限)
	if not _校准开("双周期评级启用", true):
		# 回退：原年度实时立即晋升
		if 新等级> 门派等级:
			宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "宗门晋升",
				"文案": 文案表["sect_grade_promote"] % [新等级]})
			_加推演条目(文案表["sect_grade_promote_notice"] % [新等级, 新等级 * 2], ET_SECT, PRIO_HIGH, {"宗门等级": 新等级})
		门派等级 = 新等级
		_复检里程碑()   # WAVE-D #8：门派等级阈值（晋升八品/三品： 繁荣
		_复检成就()       # S1 ：：门派晋升后按等：繁荣补达成成：
	else:
		# 双周期：仅记录「成长目标」，待七载大考才生效（零新增，仅改调用时机）
		if 新等级> 门派等级目标:
			门派等级目标 = 新等级
	繁荣 = clamp(50 + 弟子列表.size() * 2 + int(灵石 / 100) + 繁荣经营值, 0, 100)   # P1-2：基础派生 + 经营增量（可经营）
	# P2-10：凡人城镇接业务（原恒空 Array 死资源；现派生自信徒数，随信徒增长而增，不再恒0）
	凡人城镇.clear()
	var 城镇数: int = clamp(int(信徒数 / 10) + 1, 0, 99)
	for i in 城镇数:
		凡人城镇.append({"名": "信众镇%d" % (i + 1), "人口": 100 + i * 50})
# 距下一级信息（主界面展示用）：基于已存储门派等级，计算单靠声望补齐时的缺口
func 距下一级信息() -> Dictionary:

	var 总战力:= 0
	for d in 弟子列表:
		总战力+= d.总战力()
	var s: float = 弟子列表.size() / 12.0 + 总战力/ 20000.0 + 已通关秘境.size() / 10.0 + float(声望) / 500.0
	var 等级 := 门派等级
	var 已满: bool = 等级 >= 门派等级上限
	var 缺口 := 0
	if not 已满:
		var 缺: float = float(等级) - s   # 升到下一级需 raw 分数 >= 当前等级
		if 缺> 0:
			缺口 = int(ceil(缺* 500.0))
	return {"等级": 等级, "下一级": 等级 + 1, "声望缺口": max(缺口, 0), "已满": 已满}
func 已解锁道途() -> Array:

	var 候选: Array = ["道修", "体修", "法修"]
	if 门派等级 >= 3:
		候选.append("御兽")
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
# 从品阶字符串判断是否为稀有（上品及以：稀有）
static func _是稀有品阶(品阶: String) -> bool:

	return 品阶 in ["宝阶", "王阶", "圣阶", "仙阶", "道阶"]
# ============ 时间文本 ============
func 时间文本() -> String:

	var d := 累计游戏日
	var 日: int = d / 360
	var y: int = int((d % 360) / 30)
	var m: int = d % 30
	return "%d年%d月%d日" % [日, y, m]
# 结构化汇总（：UI 三层展示使用：
# 返回值同时兼容旧接口（String）和 ：UI（结构化数据：离线汇总数据）
var 离线汇总数据: Dictionary = {}   # 新UI读取此字段构建三层面：
func 生成结构化汇报(流失日数: int, 灵石收益: int) -> String:

	# 按优先级分桶
	var 高优事件 := []
	var 普通事件:= []
	var 琐事事件 := []
	# 统计计数
	var 突破数:= 0
	var 稀有物品数 := 0
	var 任职数:= 0
	var 奇遇成功数:= 0
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
			突破数+= 1
		if 条目.get("event_type") in [ET_LOOT, ET_QUEST]:
			if "得" in 条目.get("text", "") and ("极品" in 条目.get("text", "") or "特殊" in 条目.get("text", "")):
				稀有物品数 += 1
		if 条目.get("event_type") == ET_APPOINT:
			任职数+= 1
		if 条目.get("event_type") == ET_QUEST and "无功而返" not in 条目.get("text", ""):
			奇遇成功数+= 1
	# 存储结构化数据供：UI 使用
	离线汇总数据= {
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
	# 兼容：UI：返回纯文本（降级显示）
	if 推演日志.is_empty():
		return "（暂无新事件）"
	var 文本行:= []
	for 条目 in 推演日志:
		文本行.append(条目.get("text", ""))
	return "═══你离开期间%s═══\n" % 时间文本() + "\n".join(文本行)
# 旧接口别名（保持向后兼容：
func 生成汇总报告() -> String:

	return 生成结构化汇报(0, 0)
# ============ 御兽：============
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
		_记录图录(e.种类名, "御兽")   # WAVE-D #6：孵化即收录妖兽图录（匹配名 = 灵兽种类名）
	if 已孵.size() > 0:
		战报更新.emit(文案表["beast_eggs_hatched"] % [已孵.size()])
# T03 引育计划队列：周期结算遍历启用条目，灵石足够则拨付经：按偏好生成兽卵入孵化列表
func 处理兑换队列():

	for 条目 in 灵兽兑换队列:
		if not 条目.get("启用", false):
			continue
		var 消耗: int = 条目.get("cost", 0)
		if 灵石 < 消耗:
			continue
		灵石 -= 消耗
		var 偏好: Dictionary = 条目.get("偏好", {})
		var 兽: Beast = Beast.new()
		兽.随机成蛋(偏好.get("品阶", ""), 偏好.get("类型", ""))
		灵兽蛋列表.append(兽)
		var 引纪: Dictionary = _引育纪事文案(兽)
		战报更新.emit(引纪["文案"])
		宗门纪事.append({"日期": 累计游戏日, "稀有度": ("异闻" if 引纪.get("category", "") == "异闻" else "宗门"), "名称": "引育成果", "文案": 引纪["文案"], "category": 引纪.get("category", "")})
# ── T03 引育计划队列 · 数据：mutation（S1 ENG-S1-YUSHOU-WIRE）──
# 背景：队列的 ：：启停 原先只以内联形式散落：main.gd（_弹出兑换新增 / _on_兑换启停 / _on_兑换删除
#   直接读写 Game.灵兽兑换队列）。御兽堂迁入 ui/page_building.gd 后需要一个与具体 UI 无关的数据层入口：
#   故在此收敛为 3 ：typed + 带守卫的方法。返回值统一为「可直接展示的中文结果文案」，
#   与同区既有的 绑定灵兽给指定弟子) / 解绑灵兽() 返回 String 的约定保持一致：
# 边界：main.gd ：R8 复用端口保持原样不动、不改写为调用本组方法；两条路径写的是同一：
#   灵兽兑换队列，条目结构同：{偏好: Dictionary, cost: int, 启用: bool}，语义完全一致：
func 灵兽兑换_新增(偏好: Dictionary, 经费: int) -> String:

	if 经费 <= 0:
		return "引育计划拨付经费须为正数"
	# 偏好可能来自调用方的 const 表（Godot 4 常量为只读），必须深拷贝后再入队：
	# 否则后续存档/读档 ：条目改写会撞：read-only Dictionary：
	灵兽兑换队列.append({"偏好": 偏好.duplicate(true), "cost": 经费, "启用": true})
	return "已添加引育计划（单次拨付 %d 灵石）" % [经费]
func 灵兽兑换_启停(序号: int) -> String:

	if 序号 < 0 or 序号 >= 灵兽兑换队列.size():
		return "引育计划序号越界，操作已忽略"
	var 条目: Dictionary = 灵兽兑换队列[序号]
	var 新增: bool = not bool(条目.get("启用", false))
	条目["启用"] = 新增
	return "引育计划%s" % ("启用" if 新增 else "停用")
func 灵兽兑换_删除(序号: int) -> String:

	if 序号 < 0 or 序号 >= 灵兽兑换队列.size():
		return "引育计划序号越界，操作已忽略"
	灵兽兑换队列.remove_at(序号)
	return "已删除该引育计划"
# 获取所有灵兽列表（包含库存和出战）
func 获取所有灵兽列表() -> Array:
	var 灵兽列表 = []
	# 库存灵兽
	for 兽 in 灵兽库存:
		if 兽 != null and not 兽.孵化中:
			灵兽列表.append({
				"种类名": 兽.种类名,
				"品阶": 兽.品阶,
				"类型": 兽.类型,
				"等级": 兽.等级,
				"等级上限": 兽.等级上限,
				"忠诚": 兽.忠诚,
				"状态": "库存",
				"战力": 兽.战力,
			})
	# 出战灵兽（主宠和副宠）
	for d in 弟子列表:
		if d != null:
			if d.主宠灵兽 != null and not d.主宠灵兽.孵化中:
				灵兽列表.append({
					"种类名": d.主宠灵兽.种类名,
					"品阶": d.主宠灵兽.品阶,
					"类型": d.主宠灵兽.类型,
					"等级": d.主宠灵兽.等级,
					"等级上限": d.主宠灵兽.等级上限,
					"忠诚": d.主宠灵兽.忠诚,
					"状态": "主宠（%s）" % d.姓名,
					"战力": d.主宠灵兽.战力,
				})
			if d.副宠灵兽 != null and not d.副宠灵兽.孵化中:
				灵兽列表.append({
					"种类名": d.副宠灵兽.种类名,
					"品阶": d.副宠灵兽.品阶,
					"类型": d.副宠灵兽.类型,
					"等级": d.副宠灵兽.等级,
					"等级上限": d.副宠灵兽.等级上限,
					"忠诚": d.副宠灵兽.忠诚,
					"状态": "副宠（%s）" % d.姓名,
					"战力": d.副宠灵兽.战力,
				})
	return 灵兽列表

# 获取灵兽统计
func 获取灵兽统计() -> Dictionary:
	var 库存数 = 灵兽库存.size()
	var 孵化中数 = 灵兽蛋列表.size()
	var 出战数 = 0
	var 总战力 = 0
	var 平均等级 = 0
	var 等级总和 = 0
	for 兽 in 灵兽库存:
		if 兽 != null and not 兽.孵化中:
			总战力 += 兽.战力
			等级总和 += 兽.等级
	for d in 弟子列表:
		if d != null:
			if d.主宠灵兽 != null and not d.主宠灵兽.孵化中:
				出战数 += 1
				总战力 += d.主宠灵兽.战力
				等级总和 += d.主宠灵兽.等级
			if d.副宠灵兽 != null and not d.副宠灵兽.孵化中:
				出战数 += 1
				总战力 += d.副宠灵兽.战力
				等级总和 += d.副宠灵兽.等级
	var 总数 = 库存数 + 出战数
	if 总数 > 0:
		平均等级 = int(等级总和 / 总数)
	return {
		"库存数": 库存数,
		"孵化中数": 孵化中数,
		"出战数": 出战数,
		"总数": 总数,
		"总战力": 总战力,
		"平均等级": 平均等级,
	}

# 一键培养所有库存灵兽（提升等级和忠诚）
func 一键培养灵兽() -> Dictionary:
	var 培养数量 = 0
	var 消耗灵石 = 0
	for 兽 in 灵兽库存:
		if 兽 != null and not 兽.孵化中:
			if 兽.等级 < 兽.等级上限:
				var 消耗 = 100 * 兽.等级
				if 灵石 >= 消耗:
					灵石 -= 消耗
					兽.等级 = min(兽.等级 + 1, 兽.等级上限)
					兽.忠诚 = min(兽.忠诚 + 5, 100)
					消耗灵石 += 消耗
					培养数量 += 1
	添加纪事("庶务", "一键培养灵兽", "培养了%d只灵兽，消耗%d灵石" % [培养数量, 消耗灵石], 1)
	return {"成功": 培养数量 > 0, "培养数量": 培养数量, "消耗灵石": 消耗灵石, "消息": "一键培养完成，培养了%d只灵兽" % 培养数量}

# 灵兽技能配置
const 灵兽技能配置: Dictionary = {
	"攻击": [
		{"技能名": "撕咬", "描述": "对敌人造成150%攻击伤害", "解锁等级": 1},
		{"技能名": "猛扑", "描述": "对敌人造成200%攻击伤害，有30%概率眩晕", "解锁等级": 5},
		{"技能名": "狂暴", "描述": "进入狂暴状态，攻击力提升50%，持续3回合", "解锁等级": 10},
	],
	"防御": [
		{"技能名": "硬壳", "描述": "受到的伤害减少20%", "解锁等级": 1},
		{"技能名": "反击", "描述": "受到攻击时有30%概率反击", "解锁等级": 5},
		{"技能名": "铁壁", "描述": "进入防御姿态，受到的伤害减少50%，持续2回合", "解锁等级": 10},
	],
	"辅助": [
		{"技能名": "治愈", "描述": "恢复主人10%生命值", "解锁等级": 1},
		{"技能名": "净化", "描述": "清除主人身上的负面状态", "解锁等级": 5},
		{"技能名": "祝福", "描述": "提升主人全属性10%，持续3回合", "解锁等级": 10},
	],
	"速度": [
		{"技能名": "迅捷", "描述": "提升主人速度10%", "解锁等级": 1},
		{"技能名": "闪避", "描述": "主人有20%概率闪避攻击", "解锁等级": 5},
		{"技能名": "疾风", "描述": "主人速度提升30%，持续2回合", "解锁等级": 10},
	],
}

# 获取灵兽可学习的技能列表
func 获取灵兽技能列表(灵兽类型: String, 灵兽等级: int) -> Array:
	var 技能列表 = []
	var 类型技能 = 灵兽技能配置.get(灵兽类型, [])
	for 技能 in 类型技能:
		if 灵兽等级 >= int(技能.get("解锁等级", 1)):
			技能列表.append({
				"技能名": 技能.get("技能名", ""),
				"描述": 技能.get("描述", ""),
				"解锁等级": 技能.get("解锁等级", 1),
				"已解锁": true,
			})
		else:
			技能列表.append({
				"技能名": 技能.get("技能名", ""),
				"描述": 技能.get("描述", ""),
				"解锁等级": 技能.get("解锁等级", 1),
				"已解锁": false,
			})
	return 技能列表

# 灵兽进化（提升品阶）
func 灵兽进化(灵兽索引: int) -> Dictionary:
	if 灵兽索引 < 0 or 灵兽索引 >= 灵兽库存.size():
		return {"成功": false, "原因": "灵兽不存在"}
	var 兽 = 灵兽库存[灵兽索引]
	if 兽 == null or 兽.孵化中:
		return {"成功": false, "原因": "灵兽未孵化"}
	var 品阶列表 = ["凡品", "灵品", "宝品", "仙品", "神品"]
	var 当前品阶索引 = 品阶列表.find(兽.品阶)
	if 当前品阶索引 < 0 or 当前品阶索引 >= 品阶列表.size() - 1:
		return {"成功": false, "原因": "灵兽已达最高品阶"}
	if 兽.等级 < 兽.等级上限:
		return {"成功": false, "原因": "灵兽等级未达上限（需%d级）" % 兽.等级上限}
	var 消耗灵石 = 5000 * (当前品阶索引 + 1)
	var 消耗灵草 = 100 * (当前品阶索引 + 1)
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
	if 灵草 < 消耗灵草:
		return {"成功": false, "原因": "灵草不足（需%d灵草）" % 消耗灵草}
	灵石 -= 消耗灵石
	灵草 -= 消耗灵草
	var 新品阶 = 品阶列表[当前品阶索引 + 1]
	兽.品阶 = 新品阶
	兽.等级上限 = min(兽.等级上限 + 5, 50)
	兽.等级 = 1
	添加纪事("庶务", "灵兽进化", "%s进化为%s，等级上限提升到%d" % [兽.种类名, 新品阶, 兽.等级上限], 1)
	return {"成功": true, "灵兽": 兽, "新品阶": 新品阶, "消耗灵石": 消耗灵石, "消耗灵草": 消耗灵草, "消息": "%s进化成功" % 兽.种类名}

# 获取灵兽进化消耗
func 获取灵兽进化消耗(灵兽索引: int) -> Dictionary:
	if 灵兽索引 < 0 or 灵兽索引 >= 灵兽库存.size():
		return {}
	var 兽 = 灵兽库存[灵兽索引]
	if 兽 == null:
		return {}
	var 品阶列表 = ["凡品", "灵品", "宝品", "仙品", "神品"]
	var 当前品阶索引 = 品阶列表.find(兽.品阶)
	return {
		"当前品阶": 兽.品阶,
		"当前等级": 兽.等级,
		"等级上限": 兽.等级上限,
		"是否可进化": 兽.等级 >= 兽.等级上限 and 当前品阶索引 >= 0 and 当前品阶索引 < 品阶列表.size() - 1,
		"进化消耗灵石": 5000 * (当前品阶索引 + 1) if 当前品阶索引 >= 0 else 0,
		"进化消耗灵草": 100 * (当前品阶索引 + 1) if 当前品阶索引 >= 0 else 0,
		"进化后品阶": 品阶列表[当前品阶索引 + 1] if 当前品阶索引 >= 0 and 当前品阶索引 < 品阶列表.size() - 1 else "最高品阶",
		"进化后等级上限": min(兽.等级上限 + 5, 50),
	}

# T13+T14 出战灵兽月度养成：出：：副宠)+1：封顶上限)、忠：2(封顶100)；库存灵兽忠：1(地板0)
func 出战灵兽月度养成():

	for d in 弟子列表:
		for 兽 in [d.主宠灵兽, d.副宠灵兽]:
			if 兽== null or 兽.孵化中:
				continue
			兽.等级 = min(兽.等级 + 1, 兽.等级上限)
			兽.忠诚 = min(兽.忠诚 + 2, 100)
	for 兽 in 灵兽库存:
		if 兽.孵化中:
			continue
		兽.忠诚 = max(兽.忠诚 - 1, 0)
func 绑定灵兽给首只合体(灵兽: Beast) -> String:

	for d in 弟子列表:
		if d.主宠灵兽 != null:
			continue
		if (d.资质 == "fan_su" or d.资质 == "pingyong") and not (灵兽.品阶 in ["fan_jie", "ling_jie"]):
			continue
		return 绑定灵兽给指定弟子(灵兽, d)
	return 文案表["beast_no_bindable"]
func 绑定灵兽给指定弟子(灵兽: Beast, 弟子: Disciple, 槽位: String = "主宠") -> String:

	if 槽位 == "副宠" and 弟子.副宠灵兽 != null:
		return "%s】已绑定副宠灵兽" % [弟子.姓名]
	if 槽位 != "副宠" and 弟子.主宠灵兽 != null:
		return "%s】已绑定主宠灵兽" % [弟子.姓名]
	if (弟子.资质 == "fan_su" or 弟子.资质 == "pingyong") and not (灵兽.品阶 in ["fan_jie", "ling_jie"]):
		return "%s】资质过低，仅能携带灵阶灵兽" % [弟子.姓名]
	if 槽位 == "副宠":
		弟子.副宠灵兽 = 灵兽
		灵兽.设为副宠()
	else:
		弟子.主宠灵兽 = 灵兽
		灵兽.设为主宠()
	灵兽库存.erase(灵兽)
	弟子变动.emit()
	return "%s】已绑定灵兽%s】（%s）" % [弟子.姓名, 灵兽.种类名, Beast.类型中文.get(灵兽.beast_type, "")]
# 解绑灵兽（P0-3 双槽：卸下主：副宠，灵兽返回御兽堂库存，可重新绑定：
func 解绑灵兽(弟子: Disciple, 槽位: String) -> String:

	var 兽: Beast = null
	if 槽位 == "副宠":
		兽= 弟子.副宠灵兽
		弟子.副宠灵兽 = null
	else:
		兽= 弟子.主宠灵兽
		弟子.主宠灵兽 = null
	if 兽!= null:
		兽.取消出战()
		if not 灵兽库存.has(兽):
			灵兽库存.append(兽)
	弟子变动.emit()
	return 文案表["beast_contract_released"] % [弟子.姓名, ("副宠" if 槽位 == "副宠" else "主宠")]
# ============ 终局机制 P0：寿元坐化============
# 寿元耗尽弟子离场：灵兽解绑归御兽堂、装：背包归宗门库房、按身份分档写纪事、从现役移除：
# P0 不含延寿/丹毒/传承（留 P1/P2）；单月坐化数量兜底，避免界：数据洪峰：
func 处理坐化(名单: Array[Disciple]):

	if 名单.is_empty():
		return
	var 上限 := 5
	var 计数 := 0
	for d in 名单:
		计数 += 1
		if 计数 > 上限:
			break
		# 灵兽解绑归还御兽：
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
		# 先贤祠入册（坐化弟子静态档案：复制字段，不持有 Disciple 引用，防悬空；EC-2/EC-4：
		先贤堂.append({
			"弟子ID": d.弟子ID, "姓名": d.姓名, "境界": d.境界,
			"坐化日": 累计游戏日, "事迹摘要": _坐化纪事文案(d)
		})
		# 纪事入册（按身份分档： 先贤缅怀分类（R1：填充「先贤缅怀」Tab：
		宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "名称": "坐化", "文案": _坐化纪事文案(d), "category": "先贤缅怀"})
		_加推演条目("%s】寿元耗尽，坐化于山门" % [d.姓名], ET_SECT, PRIO_NORMAL, {"弟子": d.姓名})
		if d.身份 == "长老":
			_传承事件("首位长老飞升")   # WAVE-D #8：长老坐：：先贤事迹图录 + 事件型里程碑
		_复检里程碑()                      # WAVE-D #8：弟：长老状态变化复检
		_复检成就()                              # S1 ：：弟：长老变化后按境：灵根/掌门境界补达成成：
		弟子列表.erase(d)
# 坐化纪事文案（史官视角，按身：境界分档；变量全部取自真实属性，禁止写死：
func _坐化纪事文案(d: Disciple) -> String:

	var 年: int = int(累计游戏日/ 360.0)
	var 寿终: int = int(d.年龄)
	var 偏科注:= ""
	if (d.资质 in ["fan_su", "pingyong"]) and (d.灵根品阶 in ["极品", "天品"]):
		偏科注= 文案表["disciple_uneven_talent"]
	if d.身份 == "长老" or d.境界 in ["化神", "仙阶", "道阶"]:
		var 堂名: String = "宗门" if d.司职 == "" else Lore.取司职(d.司职)["名称"]
		return 文案表["disciple_demise_elder"] % [d.身份, d.姓名, 年, 堂名, 寿终, 偏科注]
	elif d.身份 in ["核心弟子", "亲传弟子"] or d.境界 in ["金丹", "元婴"]:
		return 文案表["disciple_demise_core"] % [d.姓名, d.境界, 寿终, 寿终, 偏科注]
	else:
		return 文案表["disciple_demise_plain"] % [d.姓名, 寿终, 寿终, 偏科注]
# ============ 交宗 / 自留 ============
func 交宗(条目: Dictionary):

	var 弟子: Disciple = 条目["弟子"]
	var 物品: Item = 条目["物品"]
	var 贡献: int = {"凡阶": 10, "灵阶": 20, "宝阶": 40, "王阶": 80, "圣阶": 150, "仙阶": 300, "道阶": 600}.get(物品.品阶, 10)
	if 弟子.背包.has(物品):
		弟子.背包.erase(物品)
		贡献点+= 贡献
	elif 弟子.装备.has(物品.穿戴位) and 弟子.装备[物品.穿戴位] == 物品:
		弟子.装备.erase(物品.穿戴位)
		贡献点+= 贡献
	移除待抉择条目(条目)
	弟子变动.emit()
	战报更新.emit("%s】将%s】交予宗门，换得贡献点+%d" % [弟子.姓名, 物品.名称, 贡献])
func 自留(条目: Dictionary):

	var 弟子: Disciple = 条目["弟子"]
	var 物品: Item = 条目["物品"]
	移除待抉择条目(条目)
	弟子变动.emit()
	战报更新.emit("%s】将%s】收入囊中，自行留用" % [弟子.姓名, 物品.名称])
func 移除待抉择条目(条目: Dictionary):

	for i in range(待抉择.size()):
		if 待抉择[i] == 条目:
			待抉择.remove_at(i)
			return
# ============ 存档 / 读档 ============
# ============ 多账号系统（v1：本地多存档分身 + 登录/选择/增删：===========
# 不升 SAVE_VERSION；存档结构不变，仅改寻址为按账号 id（user://profiles/<id>/save.json）：
func 账号存档路径(id: String) -> String:

	return "user://profiles/%s/save.json" % id
func 取账号列表() -> Array:

	if not FileAccess.file_exists(账号注册表路径):
		return []
	var d: Dictionary = _读存档(账号注册表路径)
	if typeof(d) != TYPE_DICTIONARY or not d.has("accounts"):
		return []
	return d["accounts"]
func _写账号注册表(list: Array) -> void:

	var da: DirAccess = DirAccess.open("user://")
	if da and not da.dir_exists("profiles"):
		da.make_dir("profiles")
	var f: FileAccess = FileAccess.open(账号注册表路径, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"accounts": list}))
		f.close()
func 取账号(id: String) -> Dictionary:

	for a in 取账号列表():
		if a.get("id") if "id" in a else "" == id:
			return a
	return {}
func 新建账号(名称: String) -> Dictionary:

	var id: String = "acc_%d" % int(Time.get_unix_time_from_system())
	var acc: Dictionary = {
		"id": id, "名称": 名称, "创建时间": int(Time.get_unix_time_from_system()),
		"最后登录": 0, "门派等级": 1, "宗主名": "", "宗主头像": ""
	}
	var list: Array = 取账号列表()
	list.append(acc)
	_写账号注册表(list)
	var da: DirAccess = DirAccess.open("user://")
	if da and not da.dir_exists("profiles/%s" % id):
		da.make_dir_recursive("profiles/%s" % id)
	return acc
func 删除账号(id: String) -> void:

	if id == "":
		return
	var root: String = "user://profiles/%s" % id
	if not OS.move_to_trash(root):
		_删目录递归(root)   # 无回收站环境（如无头）强制删
	var list: Array = 取账号列表()
	var nl: Array = []
	for a in list:
		if a.get("id") if "id" in a else "" != id:
			nl.append(a)
	_写账号注册表(nl)
	if 当前账号id == id:
		当前账号id = ""
func _删目录递归(root: String) -> void:

	var da: DirAccess = DirAccess.open(root)
	if da == null:
		return
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		if name == "." or name == "..":
			name = da.get_next()
			continue
		var child: String = root.path_join(name)
		if da.current_is_dir():
			_删目录递归(child)
		else:
			da.remove(name)
		name = da.get_next()
	da.list_dir_end()
	da.remove(root)
func 更新账号摘要(id: String) -> void:

	if id == "":
		return
	var list: Array = 取账号列表()
	for i in list.size():
		if list[i].get("id", "") == id:
			list[i]["最后登录"] = int(Time.get_unix_time_from_system())
			list[i]["门派等级"] = 门派等级
			list[i]["宗主名"] = 宗主名
			list[i]["宗主头像"] = 宗主头像
			_写账号注册表(list)
			return
func 迁移旧单档() -> void:

	# 多账号系统首启：把遗：user://save.json 迁移为第一个账号，避免本地进度丢失
	if not FileAccess.file_exists("user://save.json"):
		return
	if not 取账号列表().is_empty():
		return   # 已迁移过（注册表非空），不再重复
	var old: Dictionary = _读存档("user://save.json")
	var id: String = "acc_%d" % int(Time.get_unix_time_from_system())
	var da: DirAccess = DirAccess.open("user://")
	if da == null:
		return
	if not da.dir_exists("profiles"):
		da.make_dir("profiles")
	if not da.dir_exists("profiles/%s" % id):
		da.make_dir_recursive("profiles/%s" % id)
	da.copy("user://save.json", "user://profiles/%s/save.json" % id)
	if FileAccess.file_exists("user://save.bak1.json"):
		da.copy("user://save.bak1.json", "user://profiles/%s/save.bak1.json" % id)
	if FileAccess.file_exists("user://save.bak2.json"):
		da.copy("user://save.bak2.json", "user://profiles/%s/save.bak2.json" % id)
	var 宗门名: String = old.get("宗门名") if "宗门名" in old else "太玄宗"
	var 宗主名: String = old.get("宗主名") if "宗主名" in old else ""
	var acc: Dictionary = {
		"id": id, "名称": 宗门名, "创建时间": int(Time.get_unix_time_from_system()),
		"最后登录": int(old.get("最后登录") if "最后登录" in old else 0), "门派等级": int(old.get("门派等级") if "门派等级" in old else 1),
		"宗主名": old.get("宗主名") if "宗主名" in old else "", "宗主头像": old.get("宗主头像") if "宗主头像" in old else ""
	}
	var list: Array = [acc]
	_写账号注册表(list)
	# 旧根档改名保留作备份，避免重复迁移（迁移成功后不再读 user://save.json：
	if FileAccess.file_exists("user://save.json"):
		da.rename("user://save.json", "user://save_legacy_backup.json")
func save_game():

	var data: Dictionary = {
		"version": SAVE_VERSION,
		"lingshi": 灵石, "lingcao": 灵草, "kuangshi": 矿石, "lingqi": 灵气, "lingjing": 灵晶, "gongxian": 贡献点,
		"仙玉_绑定": 仙玉_绑定, "仙玉_非绑定": 仙玉_非绑定,
		"付费增益值": 付费增益值, "历练额外次数": 历练额外次数,  # S1-4 付费状态持久化（旧档缺键→默认0）
		"改名卡数量": 改名卡数量,  # S1 新增：宗主改名消耗品（不升SAVE_VERSION，旧档缺键→默认0：
		"dizi": [], "lingshou_dan": [], "lingshou_kucun": [], "lingshou_duilie": 灵兽兑换队列,
		"累计游戏日": 累计游戏日, "最后登录": 最后登录, "门派等级": 门派等级, "声望": 声望, "繁荣": 繁荣, "繁荣经营值": 繁荣经营值, "当前皮肤": 当前皮肤,
		"香火值": 香火值, "信徒数": 信徒数, "凡人城镇": 凡人城镇, "香火月产预估": 香火月产预估, "信徒增益档": 信徒增益档,
		# 开宗捏脸（不升 SAVE_VERSION，旧档缺键→默认零回归）
		"宗门": 宗门名, "宗主名": 宗主名, "宗主性别": 宗主性别, "宗主头像": 宗主头像,
		# 头像选择系统 + 三类渠道计数：充值状态（不升 SAVE_VERSION，旧档缺键→默认零回归；头像框系统已：2026-08-21 取消：
		"已解锁头像": 已解锁头像,
		"奇遇完成总数": 奇遇完成总数, "高级奇遇完成数": 高级奇遇完成数, "已首充": 已首充, "累充额": 累充额,
		"邮件列表": 邮件列表,   # 灵讯（邮件）系统（不升SAVE_VERSION，旧档缺键→默认[]，零回归：
		"玄榜虚拟宗门": 玄榜虚拟宗门,   # 玄榜（排行榜）：虚拟对手宗门（不升SAVE_VERSION，旧档缺键→默认[]，零回归：
		"碎片库存": 碎片库存,   # 碎片合成系统（不升SAVE_VERSION，旧档缺键→默认{}，零回归：
		"宝箱库存": 宝箱库存,   # 宝箱系统（不升SAVE_VERSION，旧档缺键→默认{}，零回归：
		"辈分字派": 辈分字派, "门规严格度": 门规严格度, "正邪路线": 正邪路线, "宗门大阵": 宗门大阵,
		"功德": 功德, "业力": 业力, "愿力": 愿力,
		"连锁进度": 连锁进度,   # P3：连锁链进度（旧档缺键→默认空 dict 回归）
		"设置": 设置项, "道友列表": _道友列表, "道友消息": _道友消息,   # 设置/本地道友（不升SAVE_VERSION，旧档缺键→默认零回归）
		# S1 ：：日供（不升 SAVE_VERSION，旧档缺键→默认零回归）
		"日供最后领取日": 日供_最后领取日, "连续理事天数": 连续理事天数,
		"日供总领取次": 日供_总领取次数, "回溯玉符数量": 回溯玉符数量,
		"司职负责人存档": 司职负责人存档, "司职状态存档": 司职状态存档, "引导阶段": 引导阶段,
		"上次出战弟子": _上次出战弟子, "器殿赠宝连计": _器殿赠宝未中上阵连计,   # 器殿赠宝 P1 状态（不升 SAVE_VERSION，旧档缺键→默认零回归）
		"体力": 体力, "已通关秘境": 已通关秘境, "精英每日次数": 精英每日次数,
		"气运修炼加成": 气运修炼加成, "气运产出加成": 气运产出加成, "气运到期日": 气运到期日,
		"历史周期评级": 周期评分.历史, "上次结算年": 上次结算年, "年始灵石": 年始灵石, "年始总战力": 年始总战力,
		"七载赏赐池": 七载赏赐池, "七载待发掉落": 七载待发掉落, "门派等级目标": 门派等级目标, "上次七载日": 上次七载日,
		# S0 差事/商店系统（不升SAVE_VERSION：load ：.get 默认兼容老档：
		"先贤堂": 先贤堂,   # WAVE-C #3：先贤祠静态档案（不升 SAVE_VERSION，旧档缺键→默认[]：
		# S1 赛季战令（功：/ 宗门令；不升 SAVE_VERSION，旧档缺键→默认零回归）
		"战令_赛季": 战令_赛季, "战令_等级": 战令_等级, "战令_经验": 战令_经验,
		"战令_已购付费": 战令_已购付费轨, "战令_已领免费": 战令_已领免费, "战令_已领付费": 战令_已领付费,
		# WAVE-D #6/#8：图：里程：传承史册（不升SAVE_VERSION：load ：.get 默认兼容老档：
		"图录_已收集": 收藏图录_已收集, "产出池加成": 产出池加成,
		"里程碑_已达成": 里程碑_已达成, "捐赠记录": 捐赠记录, "传承史册": 传承史册,
		# S1 ：：成就系统（不升 SAVE_VERSION：load ：.get 默认空数组，老档零回归）
		"成就_已达成": 成就_已达成,
		"kucun": [], "fangshi": 坊市购买记录, "fs_list": 坊市上架集,
		"fangshi_leibie": 坊市类别月购, "fangshi_month_start": 坊市月购窗口起始日,
		"fangshi_buyback": 坊市回购列表, "fangshi_tehui": 坊市每日特惠, "fangshi_tehui_day": 坊市特惠卡,
		"daily": {"当前": 当前日常, "已领": 日常已领, "上次日常日": 上次日常日, "上次日常真实秒": 上次日常真实秒, "计数": 日常计数},
		"weekly": {"当前": 当前周常, "已领": 周常已领, "上次周常日": 上次周常日, "上次周常真实秒": 上次周常真实秒, "计数": 周常计数},
		"main_done": 主线已完成,
		"randcd": 随机事件冷却, "rtypecd": 随机事件类型冷却, "qcd": quest_cooldown,
		"newbie_active": 新手目标链激活, "newbie_done": 新手完成列表,
		# 皮肤系统（不升SAVE_VERSION，旧档缺键→默认零回归）
		"当前宗主皮肤": 当前宗主皮肤, "已拥有宗主皮肤": 已拥有宗主皮肤,
		"已拥有弟子皮肤": 已拥有弟子皮肤,
		# 历练派遣系统（不升SAVE_VERSION，旧档缺键→默认零回归）
		"历练系统": ExpeditionSystem.to_dict() if ExpeditionSystem != null else {},
		# v3 新增：阵营任务和商店系统（旧档缺键→默认零回归）
		"阵营任务进度": 阵营任务进度,
		"阵营商店购买记录": 阵营商店购买记录,
		# v3 新增：道友互动系统（旧档缺键→默认零回归）
		"结义道友列表": 结义道友列表,
		"道友拜访冷却": 道友拜访冷却,
		"道友切磋冷却": 道友切磋冷却,
		# v3 新增：探索事件分支选择系统（旧档缺键→默认零回归）
		"探索事件冷却": 探索事件冷却,
	}
	for it in 宗门库房:
		data["kucun"].append(it.to_dict())
	for d in 弟子列表:
		data["dizi"].append(d.to_dict())
	for e in 灵兽蛋列表:
		data["lingshou_dan"].append(e.to_dict())
	for b in 灵兽库存:
		data["lingshou_kucun"].append(b.to_dict())
	# 存档安全：先写临时文件，校验后原子替换；写前滚动备份（按当前账号路径：
	if 当前账号id == "":
		push_warning("save_game: 当前账号id 为空，跳过存：")
		return
	var 账号目录: String = "user://profiles/%s" % 当前账号id
	var da0: DirAccess = DirAccess.open("user://")
	if da0 and not da0.dir_exists("profiles/%s" % 当前账号id):
		da0.make_dir_recursive("profiles/%s" % 当前账号id)
	_滚动备份()
	var 路径: String = 账号存档路径(当前账号id)
	var tmp: String = 路径 + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if not f:
		push_error("存档失败：临时文件无法打开")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	var da: DirAccess = DirAccess.open("user://")
	var err: int = OK
	if da:
		err = da.rename(tmp, 路径)
	if err != OK:
		push_error("存档失败：原子替换错：%d" % err)
	更新账号摘要(当前账号id)
func load_game(账号id: String = "") -> void:

	if 账号id != "":
		当前账号id = 账号id
	if 当前账号id == "":
		return
	var 路径: String = 账号存档路径(当前账号id)
	if not FileAccess.file_exists(路径):
		# 全新账号：直接初始建宗（首次进入该账号）
		初始建宗()
		_传承事件("开宗立派")
		更新账号摘要(当前账号id)
		save_game()
		重建司职()
		_复检里程碑()
		_复检成就()   # S1 ：：新账号首登按当前状态补达成成就
		弟子变动.emit()
		return
	var data: Dictionary = _读存档(路径)
	if data.is_empty():
		# 主档损坏，尝试从历史备份恢复
		push_error("主存档解析失败，尝试从历史备份恢复")
		data = _恢复最新备份()
	if data.is_empty():
		# 损坏且无备份：新建兜底，避免空状态卡：
		初始建宗()
		_传承事件("开宗立派")
		更新账号摘要(当前账号id)
		save_game()
		重建司职()
		_复检里程碑()
		_复检成就()   # S1 ：：损坏兜底按当前状态补达成成就
		弟子变动.emit()
		return
	if data.get("version") if "version" in data else 0 != SAVE_VERSION:
		push_warning("存档版本不一（%d），尝试兼容读取" % [data.get("version") if "version" in data else 0])
		_版本升级备份(data.get("version") if "version" in data else 0)
		# 存档迁移：处理旧版本的键名重命名和结构变更
		data = _迁移存档(data, data.get("version") if "version" in data else 0)
	灵石 = data.get("lingshi") if "lingshi" in data else 0
	灵草 = data.get("lingcao") if "lingcao" in data else 0
	矿石 = data.get("kuangshi") if "kuangshi" in data else 0
	灵晶 = data.get("lingjing") if "lingjing" in data else 0   # P0-3：灵晶持久化（旧档缺键→默认0）
	灵气 = data.get("lingqi") if "lingqi" in data else 0
	贡献点= data.get("gongxian") if "gongxian" in data else 0
	仙玉_绑定 = data.get("仙玉_绑定") if "仙玉_绑定" in data else 0
	仙玉_非绑定= data.get("仙玉_非绑定") if "仙玉_非绑定" in data else 0
	付费增益值 = float(data.get("付费增益值") if "付费增益值" in data else 0.0)  # S1-4 付费buff
	历练额外次数 = int(data.get("历练额外次数") if "历练额外次数" in data else 0)  # S1-4 付费额外历练
	改名卡数量= data.get("改名卡数量") if "改名卡数量" in data else 0  # S1 新增：旧档缺键→默认0
	累计游戏日= data.get("累计游戏日") if "累计游戏日" in data else 0
	最后登录= data.get("最后登录") if "最后登录" in data else 0
	门派等级 = clamp(data.get("门派等级") if "门派等级" in data else 1, 1, 门派等级上限)
	当前皮肤 = data.get("当前皮肤") if "当前皮肤" in data else "taixu_yunhai"   # 旧档缺键→默认太虚云海（零回归）
	# 皮肤系统（旧档缺键→默认零回归，不升 SAVE_VERSION）
	当前宗主皮肤 = data.get("当前宗主皮肤") if "当前宗主皮肤" in data else ""
	已拥有宗主皮肤= data.get("已拥有宗主皮肤") if "已拥有宗主皮肤" in data else []
	已拥有弟子皮肤= data.get("已拥有弟子皮：") if "已拥有弟子皮：" in data else []
	# 历练派遣系统（旧档缺键→默认零回归，不升 SAVE_VERSION）
	if ExpeditionSystem != null:
		ExpeditionSystem.from_dict(data.get("历练系统") if "历练系统" in data else {})
	# 开宗捏脸（旧档缺键→默认零回归，不升SAVE_VERSION）
	宗门名 = data.get("宗门名") if "宗门名" in data else "太玄宗"
	宗主名= data.get("宗主名") if "宗主名" in data else "太虚道君"
	宗主性别 = data.get("宗主性别") if "宗主性别" in data else ""
	宗主头像 = data.get("宗主头像") if "宗主头像" in data else ""
	if 宗主头像 == "":
		var _默认头像: Dictionary = 默认解锁头像(宗主性别)
		宗主头像 = _默认头像.get("id", "")
	# 头像选择系统（旧档缺键→默认零回归，不升 SAVE_VERSION；头像框系统已于 2026-08-21 取消，相关键忽略：
	已解锁头像= data.get("已解锁头像") if "已解锁头像" in data else []
	邮件列表 = data.get("邮件列表") if "邮件列表" in data else []   # 灵讯（邮件）系统：旧档缺键→默认[]，零回归（不升SAVE_VERSION）
	玄榜虚拟宗门 = data.get("玄榜虚拟宗门") if "玄榜虚拟宗门" in data else []   # 玄榜（排行榜）：旧档缺键→默认[]，零回归（不升SAVE_VERSION）
	碎片库存 = data.get("碎片库存") if "碎片库存" in data else {}   # 碎片合成系统：旧档缺键→默认{}，零回归（不升SAVE_VERSION）
	宝箱库存 = data.get("宝箱库存") if "宝箱库存" in data else {}   # 宝箱系统：旧档缺键→默认{}，零回归（不升SAVE_VERSION）
	_种子化默认解锁头像()  # 读档后补种子（初始头像默认解锁），否则弹窗选了写不：
	_种子化初始邮()      # 读档后补种子（全新档/旧档无邮件→给初始几封；已有邮件则不重复种子：
	_种子化玄()          # 读档后补种子（全新档/旧档无虚拟宗门→种子；已有则不重复）
	奇遇完成总数 = data.get("奇遇完成总数") if "奇遇完成总数" in data else 0
	高级奇遇完成数= data.get("高级奇遇完成数") if "高级奇遇完成数" in data else 0
	已首充= data.get("已首充") if "已首充" in data else false
	累充额= data.get("累充额") if "累充额" in data else 0
	声望 = data.get("声望") if "声望" in data else 0
	繁荣 = data.get("繁荣") if "繁荣" in data else 50
	繁荣经营值 = data.get("繁荣经营值") if "繁荣经营值" in data else 0   # P1-2：经营增量持久化（旧档缺键→0）
	香火值= data.get("香火值") if "香火值" in data else 0
	信徒数= data.get("信徒数") if "信徒数" in data else 0
	凡人城镇.clear()
	for 镇 in data.get("凡人城镇") if "凡人城镇" in data else []:
		凡人城镇.append(镇)
	# WAVE-C #3：先贤祠静态档案（旧档缺键→默认[]，零回归：
	先贤堂= data.get("先贤堂") if "先贤堂" in data else []
	# WAVE-D #6/#8：图：里程：传承史册（旧档缺键→默认零回归）
	收藏图录_已收集= data.get("图录_已收：") if "图录_已收：" in data else {}
	产出池加成= data.get("产出池加成") if "产出池加成" in data else 0.0
	里程碑_已达成= data.get("里程碑_已达成") if "里程碑_已达成" in data else []
	# S1 ：：成就系统（旧档缺键→默认空数组，零回归：
	成就_已达成= data.get("成就_已达成") if "成就_已达成" in data else []
	捐赠记录 = data.get("捐赠记录") if "捐赠记录" in data else {}
	传承史册 = data.get("传承史册") if "传承史册" in data else []
	香火月产预估 = data.get("香火月产预估") if "香火月产预估" in data else 0
	信徒增益档= data.get("信徒增益档") if "信徒增益档" in data else "未启"
	辈分字派.clear()
	for 派 in data.get("辈分字派") if "辈分字派" in data else []:
		辈分字派.append(派)
	门规严格度= data.get("门规严格度") if "门规严格度" in data else "中庸"
	正邪路线 = data.get("正邪路线") if "正邪路线" in data else ""
	功德 = data.get("功德") if "功德" in data else 0
	业力 = data.get("业力") if "业力" in data else 0
	愿力 = data.get("愿力") if "愿力" in data else 0
	连锁进度 = data.get("连锁进度") if "连锁进度" in data else {}   # 旧档缺键→默认空 Dict，零回归
	宗门大阵 = data.get("宗门大阵") if "宗门大阵" in data else {}   # 旧档缺键→默认空 Dict，零回归（不升SAVE_VERSION）
	设置项= data.get("设置：") if "设置：" in data else {}
	# 战斗模式同步：从设置项中读取战斗模式（完整结算→full，加速结算→quick）
	var 设置战斗模式: String = str(设置项.get("战斗模式", "完整结算"))
	战斗模式 = "full" if 设置战斗模式 == "完整结算" else "quick"
	_道友列表 = data.get("道友列表") if "道友列表" in 设置战斗模式 else []
	_道友消息 = data.get("道友消息") if "道友消息" in 设置战斗模式 else []
	# S1 赛季战令（功：/ 宗门令；旧档缺键→默认零回归，不升SAVE_VERSION）
	战令_赛季 = data.get("战令_赛季") if "战令_赛季" in 设置战斗模式 else 1
	战令_等级 = data.get("战令_等级") if "战令_等级" in 设置战斗模式 else 0
	战令_经验 = data.get("战令_经验") if "战令_经验" in 设置战斗模式 else 0
	战令_已购付费轨= bool(data.get("战令_已购付费：") if "战令_已购付费：" in 设置战斗模式 else false)
	战令_已领免费 = data.get("战令_已领免费") if "战令_已领免费" in 设置战斗模式 else []
	战令_已领付费 = data.get("战令_已领付费") if "战令_已领付费" in 设置战斗模式 else []
	# S1 ：：日供（旧档缺键→默认零回归，不升SAVE_VERSION）
	日供_最后领取日 = data.get("日供最后领取日") if "日供最后领取日" in 设置战斗模式 else 0
	连续理事天数 = data.get("连续理事天数") if "连续理事天数" in 设置战斗模式 else 0
	日供_总领取次数= data.get("日供总领取次：") if "日供总领取次：" in 设置战斗模式 else 0
	回溯玉符数量 = data.get("回溯玉符数量") if "回溯玉符数量" in 设置战斗模式 else 0
	已解锁单人法阵= data.get("已解锁单人法阵") if "已解锁单人法阵" in 设置战斗模式 else {}   # D5：弟子已解锁单人法阵集合（旧档缺键→默认：Dict：
	司职负责人存档= data.get("司职负责：") if "司职负责：" in 设置战斗模式 else {}
	司职状态存档= data.get("司职状：") if "司职状：" in 设置战斗模式 else {}   # S1 ：：等：政绩持久化（旧档缺键→默认空，零回归：
	引导阶段 = data.get("引导阶段") if "引导阶段" in 设置战斗模式 else 6   # 老档无此字段 ：默认6（已完成，不强制弹入门指引；阶段语义：§5.2：
	_上次出战弟子 = data.get("上次出战弟子") if "上次出战弟子" in 设置战斗模式 else []   # 器殿赠宝 P1 缓存（旧档缺键→默认空，零回归）：注意：赋值给模块变量 _上次出战弟子（带下划线），与声明/保存一：
	_器殿赠宝未中上阵连计 = data.get("器殿赠宝连计") if "器殿赠宝连计" in 设置战斗模式 else 0   # 保底计数器（旧档缺键→默认0）：同上，须写回 _器殿赠宝未中上阵连计
	气运修炼加成 = data.get("气运修炼加成") if "气运修炼加成" in 设置战斗模式 else 0.0
	气运产出加成 = data.get("气运产出加成") if "气运产出加成" in 设置战斗模式 else 0.0
	气运到期日= data.get("气运到期日") if "气运到期日" in 设置战斗模式 else 0
	体力 = data.get("体力") if "体力" in 设置战斗模式 else 50
	已通关秘境 = data.get("已通关秘境") if "已通关秘境" in 设置战斗模式 else {}
	精英每日次数 = data.get("精英每日次数") if "精英每日次数" in 设置战斗模式 else {}
	# v3 新增：阵营任务和商店系统（旧档缺键→默认零回归）
	阵营任务进度 = data.get("阵营任务进度") if "阵营任务进度" in 设置战斗模式 else {}
	阵营商店购买记录 = data.get("阵营商店购买记录") if "阵营商店购买记录" in 设置战斗模式 else {}
	# v3 新增：道友互动系统（旧档缺键→默认零回归）
	结义道友列表 = data.get("结义道友列表") if "结义道友列表" in 设置战斗模式 else []
	道友拜访冷却 = data.get("道友拜访冷却") if "道友拜访冷却" in 设置战斗模式 else {}
	道友切磋冷却 = data.get("道友切磋冷却") if "道友切磋冷却" in 设置战斗模式 else {}
	# v3 新增：探索事件分支选择系统（旧档缺键→默认零回归）
	探索事件冷却 = data.get("探索事件冷却") if "探索事件冷却" in 设置战斗模式 else {}
	# 老档兼容：加载后数值合法性校验与兜底修正（防坏档崩溃 / 异常数据自动修正：
	灵石 = _修正负值(灵石, "灵石")
	灵草 = _修正负值(灵草, "灵草")
	矿石 = _修正负值(矿石, "矿石")
	灵晶 = _修正负值(灵晶, "灵晶")   # P0-3：防存档损坏致负
	灵气 = _修正负值(灵气, "灵气")
	贡献点 = _修正负值(贡献点, "贡献点")
	声望 = _修正负值(声望, "声望")
	繁荣 = _修正区间(繁荣, 0, 100, "繁荣")
	繁荣经营值 = _修正区间(繁荣经营值, 0, 50, "繁荣经营值")   # P1-2：经营增量钳制
	体力 = _修正区间(体力, 0, 体力上限(), "体力")
	累计游戏日 = _修正负值(累计游戏日, "累计游戏日")
	# P1：周期评分存档（计数器不持久化，读档后重置；历史与年：年始快照恢复：
	历史周期评级 = data.get("历史周期评级") if "历史周期评级" in 设置战斗模式 else []
	周期评分.历史 = 历史周期评级
	周期评分.计数 = {"灵石获取": 0, "稀有道具": 0, "突破": 0, "高品质新弟子": 0, "首通": 0}
	上次结算年= data.get("上次结算年") if "上次结算年" in data else 0
	年始灵石 = data.get("年始灵石") if "年始灵石" in data else 灵石
	年始总战力= data.get("年始总战力") if "年始总战力" in data else 0
	七载赏赐池= data.get("七载赏赐池") if "七载赏赐池" in data else 0
	七载待发掉落 = data.get("七载待发掉落") if "七载待发掉落" in data else []
	门派等级目标 = data.get("门派等级目标") if "门派等级目标" in data else 门派等级
	上次七载日= data.get("上次七载日") if "上次七载日" in data else 0
	最新周期评级卡 = {}
	弟子列表.clear()
	待抉择.clear()
	奇遇待抉择.clear()      # 会话瞬时队列，load 时清空（ADR-002 D6：
	宗门纪事.clear()        # 会话瞬时历史，load 时清空
	灵兽蛋列表.clear()
	灵兽库存.clear()
	灵兽兑换队列.clear()
	for _q in data.get("lingshou_duilie") if "lingshou_duilie" in data else []:
		if _q is Dictionary:
			灵兽兑换队列.append(_q)
	for dd in data.get("dizi") if "dizi" in data else []:
		var d := Disciple.new()
		d.from_dict(dd)
		弟子列表.append(d)
	# WAVE-B #2：载入后重置ID分配器，避免后续新建弟子与已载入弟子ID冲突（取现有最大ID+1：
	var _max弟子ID := 0
	for _d in 弟子列表:
		if _d.弟子ID > _max弟子ID:
			_max弟子ID = _d.弟子ID
	Disciple.下一弟子ID = max(Disciple.下一弟子ID, _max弟子ID + 1)
	for ed in data.get("lingshou_dan") if "lingshou_dan" in data else []:
		var e := Beast.new()
		e.from_dict(ed)
		灵兽蛋列表.append(e)
	for bd in data.get("lingshou_kucun") if "lingshou_kucun" in data else []:
		var b := Beast.new()
		b.from_dict(bd)
		灵兽库存.append(b)
	# S0 差事/商店系统：get 默认兼容无此字段的老档：
	宗门库房.clear()
	for kd in data.get("kucun") if "kucun" in data else []:
		var it := Item.new()
		it.from_dict(kd)
		宗门库房.append(it)
	坊市购买记录 = data.get("fangshi") if "fangshi" in data else {}
	坊市上架集= data.get("fs_list") if "fs_list" in data else []
	坊市类别月购 = data.get("fangshi_leibie") if "fangshi_leibie" in data else {}
	坊市月购窗口起始日= int(data.get("fangshi_month_start") if "fangshi_month_start" in data else 0)
	坊市回购列表 = data.get("fangshi_buyback") if "fangshi_buyback" in data else []
	坊市每日特惠 = data.get("fangshi_tehui") if "fangshi_tehui" in data else []
	坊市特惠卡= int(data.get("fangshi_tehui_day") if "fangshi_tehui_day" in data else -1)
	var djson: Dictionary = data.get("daily") if "daily" in data else {}
	当前日常 = djson.get("当前") if "当前" in djson else []
	日常已领 = djson.get("已领") if "已领" in djson else []
	日常计数 = djson.get("计数") if "计数" in djson else {}
	# S1-2 修复：原读键写作全角「：」，与 save 写入的「上次日常日」不一致 → 读档恒为 0
	#   → 每次进游戏都满足「累计游戏日 - 上次日常日 >= 1」，日常任务被反复刷新。
	上次日常日= int(djson.get("上次日常日") if "上次日常日" in djson else 0)
	上次日常真实秒 = int(djson.get("上次日常真实秒") if "上次日常真实秒" in djson else 0)
	var wjson: Dictionary = data.get("weekly") if "weekly" in data else {}
	当前周常 = wjson.get("当前") if "当前" in wjson else {}
	周常已领 = wjson.get("已领") if "已领" in wjson else true
	周常计数 = wjson.get("计数") if "计数" in wjson else {}
	上次周常日= int(wjson.get("上次周常日") if "上次周常日" in wjson else 0)
	上次周常真实秒 = int(wjson.get("上次周常真实秒") if "上次周常真实秒" in wjson else 0)
	主线已完成= data.get("main_done") if "main_done" in wjson else []
	随机事件冷却 = data.get("randcd") if "randcd" in wjson else {}
	随机事件类型冷却 = data.get("rtypecd") if "rtypecd" in wjson else {}
	quest_cooldown = data.get("qcd") if "qcd" in wjson else {}
	# P0 目标链：新手阶梯状态（老档默认 false/[]，向后兼容）
	新手目标链激活= data.get("newbie_active") if "newbie_active" in wjson else false
	新手完成列表 = data.get("newbie_done") if "newbie_done" in wjson else []
	# 老档或空差事：补刷一次，保证面板非空
	if 当前日常.is_empty():
		刷新日常差事()
	if 当前周常.is_empty():
		刷新周常()
	# 多账号系统：载入后补全运行期初始化（原在 _ready 内，现随登录载入执行：
	重建司职()
	_复检里程碑()
	_复检成就()   # S1 ：：多账号载入后按当前状态补达成成就
	更新账号摘要(当前账号id)
	弟子变动.emit()
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

	# 多账号：按当前账号路径滚动备：bak2 <- bak1 <- save.json（copy 前先删目标，避免已存在冲突）
	if 当前账号id == "":
		return
	var 账号目录: String = "user://profiles/%s" % 当前账号id
	var 主档: String = 账号存档路径(当前账号id)
	if not FileAccess.file_exists(主档):
		return
	var da: DirAccess = DirAccess.open(账号目录)
	if not da:
		return
	if FileAccess.file_exists(账号目录 + "/save.bak2.json"):
		da.remove("save.bak2.json")
	if FileAccess.file_exists(账号目录 + "/save.bak1.json"):
		da.copy("save.bak1.json", "save.bak2.json")
	if FileAccess.file_exists(账号目录 + "/save.bak1.json"):
		da.remove("save.bak1.json")
	da.copy("save.json", "save.bak1.json")
func _恢复最新备份() -> Dictionary:

	if 当前账号id == "":
		return {}
	var 账号目录: String = "user://profiles/%s" % 当前账号id
	for bak in [账号目录 + "/save.bak1.json", 账号目录 + "/save.bak2.json"]:
		if FileAccess.file_exists(bak):
			var d: Dictionary = _读存档(bak)
			if not d.is_empty():
				push_warning("已从备份恢复%s" % bak)
				return d
	return {}
# 存档数值合法性兜底：负值修正为 0（防坏档负数崩溃：
func _修正负值(v: int, 值: String) -> int:

	if v < 0:
		push_warning("存档校验%s 为负(%d)，已兜底修正0" % [v, v])
		return 0
	return v
# 存档数值合法性兜底：区间夹取（越界则 clamp 并告警）
func _修正区间(v: int, lo: int, hi: int, 名: String) -> int:

	if v < lo or v > hi:
		push_warning("存档校验%s=%d 越界[%d,%d]，已夹取修正" % [v, v, lo, hi])
		return clampi(v, lo, hi)
	return v
# 版本升级备份：新版本首次加载旧档时，保留一份升级前存档（时间戳命名，避免覆盖）
func _版本升级备份(旧版本: int):

	if 当前账号id == "":
		return
	var 账号目录: String = "user://profiles/%s" % 当前账号id
	var da: DirAccess = DirAccess.open(账号目录)
	if not da:
		return
	if not FileAccess.file_exists(账号目录 + "/save.json"):
		return
	var ts: int = int(Time.get_unix_time_from_system())
	var 目标: String = "save_backup_v%d_%d.json" % [旧版本, ts]
	da.copy("save.json", 目标)
	push_warning("检测到存档升级 v%d→v%d，已备份旧档%s/%s" % [旧版本, SAVE_VERSION, 账号目录, 目标])

# ==================== 品质名称转换函数（确保旧存档兼容性）====================
# 注意：灵根品阶（凡品/良品/上品/极品/天品）和命格品质不转换
# 只转换装备/傀儡/藏书阁/宝箱/碎片合成等系统的品质名称
const 品质转换表: Dictionary = {
	"灵品": "灵阶",
	"宝品": "宝阶",
	"王品": "王阶",
	"圣品": "圣阶",
	"仙品": "仙阶",
	"道品": "道阶",
}

# 转换单个品质名称（灵根和命格品质不转换）
static func 转换品质名称(旧品质: String) -> String:
	if 旧品质 in 品质转换表:
		return 品质转换表[旧品质]
	return 旧品质

# 递归转换字典中的品质名称（跳过灵根和命格相关字段）
static func _递归转换品质(数据, 字段名: String = ""):
	if typeof(数据) == TYPE_DICTIONARY:
		for key in 数据.keys():
			var 值 = 数据[key]
			# 跳过灵根和命格相关字段
			if key in ["灵根品阶", "命格品质", "灵根品质", "命格品阶"]:
				continue
			# 如果值是字符串且是品质名称，转换它
			if typeof(值) == TYPE_STRING and 值 in 品质转换表:
				数据[key] = 品质转换表[值]
			else:
				_递归转换品质(值, key)
	elif typeof(数据) == TYPE_ARRAY:
		for i in range(数据.size()):
			_递归转换品质(数据[i], 字段名)

# 转换存档中所有系统的品质名称
static func 转换存档品质名称(存档数据: Dictionary) -> Dictionary:
	var 转换后: Dictionary = 存档数据.duplicate(true)
	# 转换傀儡列表
	if 转换后.has("傀儡列表"):
		for 傀儡 in 转换后["傀儡列表"]:
			if typeof(傀儡) == TYPE_DICTIONARY and 傀儡.has("品阶"):
				傀儡["品阶"] = 转换品质名称(傀儡["品阶"])
	# 转换藏书阁列表
	if 转换后.has("藏书阁列表"):
		for 典籍 in 转换后["藏书阁列表"]:
			if typeof(典籍) == TYPE_DICTIONARY and 典籍.has("品阶"):
				典籍["品阶"] = 转换品质名称(典籍["品阶"])
	# 转换宝箱库存
	if 转换后.has("宝箱库存"):
		for 宝箱ID in 转换后["宝箱库存"].keys():
			var 宝箱 = 转换后["宝箱库存"][宝箱ID]
			if typeof(宝箱) == TYPE_DICTIONARY and 宝箱.has("品阶"):
				宝箱["品阶"] = 转换品质名称(宝箱["品阶"])
	# 转换碎片库存（碎片名称中包含品质名称）
	if 转换后.has("碎片库存"):
		for 碎片ID in 转换后["碎片库存"].keys():
			var 新ID: String = 碎片ID
			for 旧品质 in 品质转换表.keys():
				if 新ID.contains(旧品质):
					新ID = 新ID.replace(旧品质, 品质转换表[旧品质])
			if 新ID != 碎片ID:
				转换后["碎片库存"][新ID] = 转换后["碎片库存"][碎片ID]
				转换后["碎片库存"].erase(碎片ID)
	push_warning("存档品质名称转换完成：傀儡/藏书阁/宝箱/碎片系统品质已统一为阶")
	return 转换后

# 存档迁移：处理旧版本的键名重命名和结构变更
# v1→v2：图鉴系统标识符重命名（图鉴* → 图录*）
func _迁移存档(data: Dictionary, 旧版本: int) -> Dictionary:
	if 旧版本 >= SAVE_VERSION:
		return data
	var 迁移后: Dictionary = data.duplicate(true)
	# v1→v2：图鉴系统标识符重命名
	if 旧版本 < 2:
		# 图鉴_已收集 → 图录_已收集
		if 迁移后.has("图鉴_已收集") and not 迁移后.has("图录_已收集"):
			迁移后["图录_已收集"] = 迁移后["图鉴_已收集"]
			push_warning("存档迁移 v1→v2：图鉴_已收集 → 图录_已收集")
		# 其他图鉴相关键名重命名（如有）
		var 图鉴键映射: Dictionary = {
			"图鉴配置": "图录配置",
			"图鉴更新": "图录更新",
			"图鉴ID": "图录ID",
		}
		for 旧键 in 图鉴键映射.keys():
			var 新键: String = 图鉴键映射[旧键]
			if 迁移后.has(旧键) and not 迁移后.has(新键):
				迁移后[新键] = 迁移后[旧键]
				push_warning("存档迁移 v1→v2：%s → %s" % [旧键, 新键])
		# v2→v3：新增阵营任务/商店、道友互动、探索事件分支选择系统
		if 旧版本 < 3:
			# 新增字段默认零回归（确保键存在，load时也会用.get默认值处理）
			if not 迁移后.has("阵营任务进度"):
				迁移后["阵营任务进度"] = {}
			if not 迁移后.has("阵营商店购买记录"):
				迁移后["阵营商店购买记录"] = {}
			if not 迁移后.has("结义道友列表"):
				迁移后["结义道友列表"] = []
			if not 迁移后.has("道友拜访冷却"):
				迁移后["道友拜访冷却"] = {}
			if not 迁移后.has("道友切磋冷却"):
				迁移后["道友切磋冷却"] = {}
			if not 迁移后.has("探索事件冷却"):
				迁移后["探索事件冷却"] = {}
			push_warning("存档迁移 v2→v3：新增阵营任务/商店、道友互动、探索事件系统字段")
	# 更新版本号
	迁移后["version"] = SAVE_VERSION
	return 迁移后
# 开始新游戏：删除存：+ 重置所有状态到初始：+ 重新初始化
# ：main.gd 调试按钮触发（OS.is_debug_build 包裹：
func new_game():

	if 当前账号id == "":
		push_warning("new_game: 当前账号id 为空，跳：")
		return
	# 1. 删除当前账号存档文件及备：
	var 账号目录: String = "user://profiles/%s" % 当前账号id
	var da: DirAccess = DirAccess.open(账号目录)
	if da:
		for f in ["save.json", "save.tmp.json", "save.bak1.json", "save.bak2.json"]:
			if FileAccess.file_exists(账号目录 + "/" + f):
				da.remove(f)
	# 2. 重置所有状态到声明默认：
	灵石 = 1000
	灵草 = 0
	矿石 = 0
	灵气 = 0
	贡献点= 0
	弟子列表.clear()
	灵兽蛋列表.clear()
	灵兽库存.clear()
	灵兽兑换队列.clear()
	待抉择.clear()
	奇遇待抉择.clear()
	宗门纪事.clear()
	_上次奇遇时刻 = 0
	_今日奇遇次数 = 0
	_奇遇日标记= -1
	_上次奇遇游戏日 = 0
	_单条冷却记录.clear()
	累计游戏日= 0
	最后登录= 0
	门派等级 = 1
	声望 = 0
	繁荣 = 50
	引导阶段 = 0
	司职列表.clear()
	司职负责人存档.clear()
	司职状态存档.clear()
	推演日志.clear()
	体力 = 50
	已通关秘境.clear()
	精英每日次数.clear()
	# P1：周期评分状态复：
	上次结算年= 0
	年始灵石 = 灵石
	年始总战力= 0
	最新周期评级卡 = {}
	历史周期评级 = []
	周期评分.历史 = []
	周期评分.计数 = {"灵石获取": 0, "稀有道具": 0, "突破": 0, "高品质新弟子": 0, "首通": 0}
	# S0 差事/商店系统复位
	宗门库房.clear()
	坊市购买记录.clear()
	坊市上架集= []
	坊市类别月购.clear()
	坊市月购窗口起始日= 0
	坊市回购列表 = []
	坊市每日特惠 = []
	坊市特惠卡= -1
	随机事件类型冷却 = {}
	quest_cooldown = {}
	# P0 目标链：新手阶梯复位
	新手目标链激活= false
	新手完成列表 = []
	当前日常.clear()
	日常已领.clear()
	当前周常.clear()
	周常已领 = true
	主线已完成= []
	随机事件冷却.clear()
	# S1 ：：成就系统复位（新档从零开始；里程碑_已达：沿用历史不重置的既有行为：
	成就_已达成= []
	# S1 赛季战令复位
	战令_赛季 = 1
	战令_等级 = 0
	战令_经验 = 0
	战令_已购付费轨= false
	战令_已领免费.clear()
	战令_已领付费.clear()
	# 开宗捏脸：重开时复位为默认（创建页将覆盖玩家自定义值）
	宗门名 = "太玄宗"
	宗主名= "太虚道君"
	宗主性别 = ""
	宗主头像 = ""
	已解锁头像= []
	_种子化默认解锁头像()  # 新档：初始头像默认解锁，保证可选即能装：
	_种子化初始邮()      # 新档：初始邮件种子（4 封资源类，接真后端）
	_种子化玄()          # 新档：虚拟对手宗门种子（单机填榜：
	奇遇完成总数 = 0
	高级奇遇完成数= 0
	已首充= false
	累充额= 0
	# 3. 重新初始化
	初始建宗()
	刷新日常差事()
	刷新周常()
	重建司职()
	更新账号摘要(当前账号id)
	save_game()
	弟子变动.emit()


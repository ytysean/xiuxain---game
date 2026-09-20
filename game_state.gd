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
const SectBounty = preload("res://sect_bounty.gd")
const ContributionShop = preload("res://contribution_shop.gd")   # S27 宗门任务榜数据层（弟子自主接取/请命）
const CaravanSystem = preload("res://caravan_system.gd")
const AuctionSystem = preload("res://auction_system.gd")
const GlobalAuctionSystem = preload("res://global_auction_system.gd")  # 全服玩家拍卖会
const FactionSystem = preload("res://faction_system.gd")
const FamilySystem = preload("res://family_system.gd")
const RaceSystem = preload("res://race_system.gd")
const DynastySystem = preload("res://dynasty_system.gd")
const MarriageSystem = preload("res://marriage_system.gd")
const FriendSystem = preload("res://friend_system.gd")
const HerbGardenSystem = preload("res://herb_garden_system.gd")
const DanMarkSystem = preload("res://dan_mark_system.gd")
const TalismanMarkSystem = preload("res://talisman_mark_system.gd")
const FactionReputationSystem = preload("res://faction_reputation_system.gd")   # 商队系统（从game_state.gd拆分）
const FishingSystem = preload("res://fishing_system.gd")   # 灵钓系统（休闲玩法 S46）
const RelicSystem = preload("res://relic_system.gd")   # 探遗迹系统（休闲玩法 S47）
const BeastRaiseSystem = preload("res://beast_raise_system.gd")   # 饲灵育兽系统（休闲玩法 S48）
const DivineSystem = preload("res://divine_system.gd")   # 卜算星盘系统（休闲玩法 S49）
const HerbSystem = preload("res://herb_system.gd")   # 药圃经营系统（休闲玩法 S50）
const ChessSystem = preload("res://chess_system.gd")   # 论道棋弈系统（休闲玩法 S51）
const PuppetSystem = preload("res://puppet_system.gd")   # 傀儡系统（从game_state.gd拆分）
const LibrarySystem = preload("res://library_system.gd")   # 藏书阁系统（从game_state.gd拆分）
const FormationSystem = preload("res://formation_system.gd")   # 阵法管理系统（从game_state.gd拆分）
const MountSystem = preload("res://mount_system.gd")   # 坐骑系统（从game_state.gd拆分）
const FragmentChestSystem = preload("res://fragment_chest_system.gd")   # 碎片宝箱系统（从game_state.gd拆分）
const MailSystem = preload("res://mail_system.gd")   # 邮件系统（从game_state.gd拆分）
const SectTechSystem = preload("res://sect_tech_system.gd")   # 宗门科技系统（从game_state.gd拆分）
const XuanRankSystem = preload("res://xuan_rank_system.gd")   # 玄榜系统（从game_state.gd拆分）
const AlchemyForgeSystem = preload("res://alchemy_forge_system.gd")   # 炼丹炼器封装系统（从game_state.gd拆分）
const TalismanManagementSystem = preload("res://talisman_system.gd")   # 符箓系统封装（从game_state.gd拆分）
const GongFaManagementSystem = preload("res://gongfa_management_system.gd")   # 功法管理系统（从game_state.gd拆分）
const BeastManagementSystem = preload("res://beast_management_system.gd")   # 灵兽管理系统（从game_state.gd拆分）
const BreakthroughSystem = preload("res://breakthrough_system.gd")   # 弟子突破系统（从game_state.gd拆分）
const AchievementSystem = preload("res://achievement_system.gd")   # 成就系统（从game_state.gd拆分）
const MessageSystem = preload("res://message_system.gd")   # S56 修真世界消息系统
const WorldMapSystem = preload("res://world_map_system.gd")   # S58 世界地图系统
const OfflineManager = preload("res://offline_manager.gd")   # S59 闭关嘱托系统（离线代理）
# 时间流速：240 现实秒 = 1 游戏日；按 360 日/游戏年折算，1 现实天 ≈ 1 游戏年
# === S1 端口：时辰历法换算层 ===
# 调用位置：所有周期玩法（刷新/结算/突破冷却）读取「游戏日」处，应在读取前经此层换算为「时辰→日→月→年」。
# 入参：游戏日(int) | 返回值：Dict{时辰, 日, 月, 年} 或统一游戏内时间戳（S1 定）
# 状态：当前未建，仅标记；现役仍用累计游戏日裸整数。依赖：时间换算层（见 §时间体系修真化）。
const 现实秒每游戏日 := 240.0
# PH6·M5：每日刷新时刻统一口径（现实本地时区）。供 获取现实日期/获取现实周/获取活动倒计时 共用。
const 每日重置小时: int = 8
const 单次推演上限日 := 3650
const SAVE_VERSION := 4   # 存档结构版本号：损坏检测与跨版本兼容用。v4：品质名称统一（品→阶），傀儡/藏书阁/宝箱/碎片系统品质已统一为阶；v3：新增阵营任务/商店、道友互动（拜访/切磋/结义）、探索事件分支选择系统；旧档载入时版本不符将自动备份并迁移
# 多账号系统（v1）：当前登录账号 id 与注册表路径；不改 SAVE_VERSION，存档结构不变，仅按 id 寻址
var 当前账号id: String = ""
const 账号注册表路径: String = "user://profiles/index.json"
var 灵石 := 1000
var 灵草 := 0  # 基础灵草（凡品，<100年）
var 灵草_百年 := 0  # 百年灵草（100-999年），炼丹成功率+10%，品质+1
var 灵草_千年 := 0  # 千年灵草（1000-9999年），炼丹成功率+25%，品质+2，可替代高1品阶
var 灵草_万年 := 0  # 万年灵草（10000+年），炼丹成功率+50%，品质+3，可替代高2品阶，有概率出极品丹
var 灵米: int = 0  # S1：灵米，弟子日常消耗，灵田副产
var 灵种: int = 20  # S1：灵种，灵田种植消耗，初始20份
var 灵种购买价格: int = 10  # S1：坊市购买灵种单价（灵石）
var 矿石 := 0
# ===== 修真原材料体系（按品阶/来源）=====
# 炼器矿物（按品阶）
var 精铁 := 0       # 灵品矿物，矿脉4级+产出
var 玄铁 := 0       # 宝品矿物，矿脉6级+产出
var 庚金 := 0       # 宝品矿物，矿脉7级+产出
var 紫晶 := 0       # 王品矿物，矿脉8级+产出
var 星辰铁 := 0     # 圣品矿物，矿脉9级+产出
var 太阳精金 := 0   # 仙品矿物，矿脉10级+秘境产出
# 炼丹灵草（按品阶）
var 灵品灵草 := 0   # 灵品灵草，灵田3级+产出
var 宝品灵草 := 0   # 宝品灵草，灵田5级+产出
var 王品灵草 := 0   # 王品灵草，灵田7级+秘境产出
var 圣品灵草 := 0   # 圣品灵草，秘境/奇遇产出
var 仙品灵草 := 0   # 仙品灵草，秘境/奇遇产出（可遇不可求）
# 自创功法系统（6.17.1）
var 自创功法列表: Array = []  # 宗门自创功法列表，每个元素：{"id","名称","品阶","类型","效果","创始人ID","创始人名","创建日","道韵":bool}
var 自创功法总数: int = 0
# 妖兽材料（按妖兽境界分等阶：练气=一阶，筑基=二阶，金丹=三阶，元婴=四阶，化神=五阶，炼虚=六阶，合体=七阶，大乘=八阶，渡劫=九阶）
var 妖兽内丹: Dictionary = {"一阶": 0, "二阶": 0, "三阶": 0, "四阶": 0, "五阶": 0, "六阶": 0, "七阶": 0, "八阶": 0, "九阶": 0}
var 妖兽精血: Dictionary = {"一阶": 0, "二阶": 0, "三阶": 0, "四阶": 0, "五阶": 0, "六阶": 0, "七阶": 0, "八阶": 0, "九阶": 0}
var 妖兽骨: Dictionary = {"一阶": 0, "二阶": 0, "三阶": 0, "四阶": 0, "五阶": 0, "六阶": 0, "七阶": 0, "八阶": 0, "九阶": 0}
var 妖兽皮: Dictionary = {"一阶": 0, "二阶": 0, "三阶": 0, "四阶": 0, "五阶": 0, "六阶": 0, "七阶": 0, "八阶": 0, "九阶": 0}
var 妖兽筋: Dictionary = {"一阶": 0, "二阶": 0, "三阶": 0, "四阶": 0, "五阶": 0, "六阶": 0, "七阶": 0, "八阶": 0, "九阶": 0}
var 妖兽爪: Dictionary = {"一阶": 0, "二阶": 0, "三阶": 0, "四阶": 0, "五阶": 0, "六阶": 0, "七阶": 0, "八阶": 0, "九阶": 0}
var 妖兽毛: Dictionary = {"一阶": 0, "二阶": 0, "三阶": 0, "四阶": 0, "五阶": 0, "六阶": 0, "七阶": 0, "八阶": 0, "九阶": 0}
# 特殊炼器材料（修真世界观：各有独特来源）
var 灵木 := 0       # 灵木，灵田/宗门林场种植，炼器琴/扇/拂尘柄
var 灵蚕丝 := 0     # 灵蚕丝，灵兽园养蚕，炼器衣/袍/带/索
var 灵禽羽 := 0     # 灵禽羽，灵兽园饲养灵禽，炼器扇面
var 灵马尾 := 0     # 灵马尾，灵兽园饲养灵马，炼器拂尘
var 玉石 := 0       # 玉石，矿脉开采/秘境采集，炼器印/镜/佩/戒/链/镯
# 境界→等阶映射
const 妖兽境界等阶: Dictionary = {"练气": "一阶", "筑基": "二阶", "金丹": "三阶", "元婴": "四阶", "化神": "五阶", "炼虚": "六阶", "合体": "七阶", "大乘": "八阶", "渡劫": "九阶"}
# 矿脉等级=殿阁等级（司职列表kuangmai等级），升级矿脉=升级殿阁（现有功能）
var 灵气 := 0
var 灵脉等级: int = 1  # S1：灵脉等级1-10，影响灵气产出和宗门承载力
var 灵脉升级消耗灵石: int = 500  # S1：灵脉升级基础消耗（每级×1.5）
var 洞府数量: int = 10  # S1：宗门洞府数量，决定能舒适供养的弟子数
var 洞府扩建消耗灵石: int = 300  # S1：洞府扩建基础消耗（每次×1.3）
# [S25 储物层收敛] 原 `仓库` 已并入 `宗门库房`（唯一真源，存档键 "kucun"）
# 历史背景：`仓库` 从未被持久化（save 仅写 kucun=宗门库房），秘境神器/建筑产出/功勋兑换物读档即丢失。
# 收敛后：上述来源统一入 宗门库房，随存档持久化；_扣灵材 亦可扣到坊市购入的灵材。
var 已领悟配方: Dictionary = {}       # S46 炼器领悟：配方ID -> 领悟时间（0=未领悟）
var 配方领悟进度: Dictionary = {}     # S46 炼器领悟：配方ID -> 累计锻造次数（用于反推领悟）
var 配置表配方: Dictionary = {}       # S46 P1：从forge_recipe_config.csv读取的完整配方库
var 灵田地块: Array = []  # 灵田种植数据
var 矿脉矿点: Array = []  # 矿脉开采数据
var 悟道点: int = 0  # 藏经阁产出，用于学习功法
var 招募冷却剩余: int = 0  # 接引殿招募冷却（游戏日）
var 渡劫准备配置: Dictionary = {"道具": [], "用护阵": false, "用护法": false}  # 天劫渡劫外力预设（§11.16）
# === S46 大能渡劫观礼系统（不升 SAVE_VERSION，旧档缺键→默认） ===
var 当前观礼名单: Array = []        # 运行时：当前大能渡劫的观礼弟子ID列表（不存档）
var 当前观礼外宾: Array = []        # 运行时：外部观礼者（友好/同盟/其他玩家），仅产外交增益（不存档）
var 宗主观礼配置: Dictionary = {"本宗人员": true, "道友道侣": true, "友好阵营": true, "同盟阵营": true, "手动名单": [], "其他玩家": []}
var 宗门阵营: String = "正道宗门"   # 用于查 友好/同盟 阵营（默认正道宗门，不改阵营归属）

# === 决策#3 异闻按境界分区播报（宗门大了后；不升 SAVE_VERSION，运行时不存档）===
var 异闻分区阈值: int = 30         # [PLACEHOLDER] 未经 playtest：启用分境多条播报的弟子数阈值
var 异闻分区月上限: int = 6         # [PLACEHOLDER] 未经 playtest：每月至多播报条数（防刷屏）
var 异闻分区已播: Dictionary = {}   # 运行时不存档：本月已播 (境界|弟子ID) 去重键
const _方针默认: Dictionary = {
	"修炼": {"风格": "均衡"},
	"历练": {"风险偏好": 0.5, "目标掉落表": [], "自动派遣": false},
	"供给": {"丹药自动炼制": false, "丹药囤积线": 20, "装备自动锻造": false, "装备囤积线": 10},
	"外交": {"阵营姿态": "均衡"},
	"建造": {"优先殿阁": [], "自动升级": false},
	"奏折敏感度": "仅重大"
}
var 方针: Dictionary = _方针默认.duplicate(true)
var 世界事件表: Array = []
var 待决奏折: Array = []
var 贡献点 := 0
# === 灵讯（邮件）系统：全新域，纯新增不改动既有数据层逻辑 ===
# 邮件列表：Array[Dictionary]，元素键：发件人/标题/内容/时间/附件(Dict 资源：/未读/已领
var 宗门领地: Array = []   # S31 宣战/领地战：占领的持久领地（灵脉/矿脉/城池/秘境），按月产出（不升SAVE_VERSION，旧档缺键→默认[]）
# === S32 宣战周期化 / 战场功勋（战功）：玩家层锚定现实时间，世界层月产仍走游戏月 ===
var 战功: int = 0                      # 战场功勋：独立货币（宣战/领地/周结算/赛季获取，不升SAVE_VERSION）
var 赛季序号: int = 1                  # 当前赛季序号（现实 4 周一季）
var 宣战周已用: int = 0                # 本现实周已用宣战次数
var 本周宣战胜场: int = 0              # 本现实周宣战胜场（周结算阶梯用）
var 赛季累计战功: int = 0              # 本赛季累计获得战功（名次判定用）
var 上次宣战周真实秒: int = 0          # 宣战周期锚点（现实 unix 秒，复用周常真实秒范式）
var 上次赛季真实秒: int = 0            # 赛季周期锚点（现实 unix 秒）
var 战功道具库存: Dictionary = {}      # 战功兑换的战斗道具：道具id → 数量（不进宗门库房，避免污染坊市回收）
var _战功商店缓存: Array = []          # config/battle_merit_shop.csv 行缓存（懒加载）
# === S33-5 阵营战役（正魔大战 P0-3）：走已有宗门战引擎 + 复用 S32 加战功()，零新货币 ===
var 阵营战役周已用: int = 0            # 本现实周已出征阵营战役次数（与宣战配额分账，_周结算_S32 清零）
var 阵营战役战绩: Dictionary = {}      # 战役id → 累计告捷次数（首胜双倍声望判定 + 纪事）
var _阵营战役缓存: Array = []          # config/faction_conflict.csv 行缓存（懒加载，不入存档）
# === S34 凡人王朝：王朝周期引擎（不升SAVE_VERSION，旧档缺键→_新王朝()兜底） ===
# 王朝已移至 dynasty_system.gd
# 凡间差事榜已移至 dynasty_system.gd
# 凡间差事进行中已移至 dynasty_system.gd
# ===================== S34b 通用拍卖会（常驻场 + 季度大拍）=====================
# 货币复用宗门灵石（不新建货币，守 S32/S35 铁律）；拍品物品以 dict 存（Item.to_dict），授予时 Item.from_dict 重建
# 拍卖会状态变量已移至 auction_system.gd
# _拍卖配置缓存已移至 auction_system.gd
# _拍卖AI缓存已移至 auction_system.gd
const 拍卖品阶基准价 := {"凡阶":60,"灵阶":240,"宝阶":900,"王阶":3500,"圣阶":12000,"仙阶":35000,"道阶":90000}  # 拍卖内部估值启发（无外部真源，纯定价启发）
# _王朝配置缓存已移至 dynasty_system.gd
# _王朝阶段缓存已移至 dynasty_system.gd
# _差事模板缓存已移至 dynasty_system.gd
var _委托模板缓存: Array = []            # config/dynasty_commission_config.csv 行缓存（懒加载）            # config/dynasty_decree_config.csv 行缓存（懒加载）
# 郡县状态已移至 dynasty_system.gd
# 战斗模式设置："full"完整结算 / "quick"速算（加速战斗，使用期望值计算，不影响最终结果分布）
var 战斗模式: String = "full"   # 默认完整结算，玩家可在设置中切换为速算
# 碎片合成系统：碎片库存（碎片ID → 数量）
# 宝箱系统：宝箱库存（宝箱ID → 数量）
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
const 命格重塑仙玉价格: int = 200  # 洗池重铸命格消耗（仙玉，高级功能，玩家手动使用）
var 弟子列表: Array[Disciple] = []   # 强类型数组（需 disciple.gd 已注册class_name：
# 御兽堂：孵化中的灵兽：+ 已孵化待绑定的灵兽库：
var 灵兽蛋列表: Array[Beast] = []
# ===== 多种族修炼体系 P2：契约灵兽系统（不占弟子名额）=====
var 契约灵兽列表: Array = []        # 已契约的灵兽列表（不占弟子名额，{灵兽ID,名称,境界,跟随弟子ID,契约时间}）
var 契约灵兽上限: int = 4            # 契约灵兽数量上限（宗门等级×2，初始4）
# ===== 多种族修炼体系 P3：种族关系与政策 =====
# 种族关系表已移至 race_system.gd
# 宗门种族政策已移至 faction_system.gd
# 种族政策效果已移至 faction_system.gd
# 种族冲突事件记录已移至 race_system.gd
# 种族通婚记录已移至 race_system.gd
# ===== 通婚与子嗣系统 =====
# 子嗣列表已移至 marriage_system.gd
# 通婚记录详细已移至 marriage_system.gd
# 生育冷却记录已移至 marriage_system.gd
# 子嗣ID计数已移至 marriage_system.gd
# === 创建宗门页（开宗捏脸）数据：===
# 玩家自定义：宗门：/ 宗主名/ 宗主性别 / 宗主头像（头像选择系统，替代旧三层捏脸 idx：
# 说明：此前铁律「数据层只读不可动」，本次经用户授权为闭合开宗链路补写底层字段（2026-08-14）：
const 宗主性别预设: Array = ["男", "女"]            # 性别枚举（对应sect_master 资源 male/female 文件夹）
var 宗门名: String = "太玄宗"                       # 与top_bar FALLBACK_宗门名一致；旧档缺键→默认回退
var 宗主名: String = "太虚道君"
var 宗主: Disciple = null  # S2：宗主独立角色实体（复用Disciple类）
var 宗主精力: int = 100  # S2：宗主每日精力，亲办奏折/修炼/生产消耗
var 宗主威望: int = 0  # S2：宗主威望，影响政令效果/弟子忠诚/外交
var 宗主精力上限: int = 100  # S2：宗主精力上限
var 宗主闭关中: bool = false  # S3：宗主是否在闭关
var 宗主闭关开始日: int = 0  # S3：宗主闭关开始的游戏日
var 宗主闭关累计天: int = 0  # S3：宗主闭关累计天数
var 最后在线时间戳: float = 0.0  # S3：最后在线的Unix时间戳（用于离线结算）
var 离线结算倍率: float = 1.0  # S3：离线资源结算倍率（VIP/月卡加成）
var 宗主剩余寿元: int = 500  # E：宗主剩余寿元（年），初始金丹500年
var 宗主传承触发中: bool = false  # E：宗主寿元耗尽，等待玩家选择传承方式
var 宗主转世次数: int = 0  # E：宗主转世重修次数
# 称号系统：宗主称号
var 宗主当前称号: String = ""  # 宗主当前装备的称号ID
var 宗主已获得称号: Array = []  # 宗主已获得的称号ID列表
var 副宗主弟子ID: int = -1  # F：副宗主弟子ID（-1表示未任命）
var 代管权能: Dictionary = {  # F：闭关代管权能范围（true=副宗主可处理，false=需宗主）
	"日常资源": true,      # 灵田/矿脉/灵脉等日常产出
	"弟子修炼": true,      # 弟子修炼推进/突破
	"自动招徒": true,      # 自动招收弟子
	"方针执行": true,      # 历练派遣/丹药炼制等方针
	"殿阁升级": false,     # 殿阁升级（消耗资源，需宗主）
	"弟子任命": false,     # 任命/解除负责人
	"重大事件": false,     # 特殊事件/奇遇
	"外交事务": false,     # 王朝/其他宗门外交
	"拍卖代拍": false,     # S53：闭关期间副宗主代拍（月卡/VIP功能）
}
var 代管待处理事件: Array = []  # F：闭关期间副宗主无法处理、需宗主上线处理的事件
# ===== S53 代拍方略系统 =====
var 代拍方略: Dictionary = {
	"启用": false,           # 是否启用代拍
	"可代拍品类": ["法宝", "丹药", "符箓", "灵材"],  # 可代拍品类
	"最低品阶": "宝阶",      # 只代拍此品阶及以上
	"单件出价上限": 5000,    # 单件物品最高出价
	"总预算上限": 20000,     # 本次代拍总预算
	"已花费": 0,             # 已花费灵石
	"优先策略": "品阶优先",  # 品阶优先/价格优先/品类优先
	"代拍记录": [],          # 代拍结果记录
}
var 天骄弟子ID: Array = []  # 修真味：天骄/俊杰弟子ID列表（修炼+20%，突破+10%）
var 特殊投奔冷却: int = 0  # 特殊人才投奔冷却（游戏日）
var 弟子技能字典: Dictionary = {}  # 技能系统：弟子ID -> 已学技能列表（[{skill_id,skill_name,grade,skill_type,effect_value,level}]）
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
# 宗主头像裁切表（比例坐标）：小图/顶栏用 AtlasTexture region，修正复杂头像脸中心偏移。
const 宗主头像裁切: Dictionary = {
	"m_daopao": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"m_zhanjia": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"m_suyi": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"f_daopao": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"f_zhanjia": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"f_suyi": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"m_ruyi": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"m_jinyi": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"m_yexing": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"f_nichang": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"f_rongzhuang": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"f_susha": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"m_secret_jianzhong": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"m_secret_lingshou": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"m_secret_xingyun": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"m_secret_youming": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"m_secret_danxia": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"m_secret_hanyu": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"f_secret_jianzhong": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"f_secret_lingshou": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"f_secret_xingyun": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"f_secret_youming": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"f_secret_danxia": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"f_secret_hanyu": {"cx": 0.5, "cy": 0.325, "s": 0.55},
	"m_rank_zongzhu": {"cx": 0.4732, "cy": 0.3648, "s": 0.3225},
	"m_rank_taishang": {"cx": 0.4816, "cy": 0.306, "s": 0.3327},
	"m_rank_hufa": {"cx": 0.4808, "cy": 0.518, "s": 0.2274},
	"m_rank_dandao": {"cx": 0.4741, "cy": 0.5301, "s": 0.2818},
	"m_rank_jiange": {"cx": 0.5025, "cy": 0.5311, "s": 0.2512},
	"m_rank_fulu": {"cx": 0.4674, "cy": 0.4293, "s": 0.2784},
	"f_rank_zongzhu": {"cx": 0.4816, "cy": 0.3795, "s": 0.3327},
	"f_rank_taishang": {"cx": 0.4724, "cy": 0.3934, "s": 0.4006},
	"f_rank_hufa": {"cx": 0.4799, "cy": 0.4502, "s": 0.2716},
	"f_rank_dandao": {"cx": 0.4632, "cy": 0.3454, "s": 0.353},
	"f_rank_jiange": {"cx": 0.4758, "cy": 0.5374, "s": 0.2478},
	"f_rank_fulu": {"cx": 0.4799, "cy": 0.35, "s": 0.3496},
}

# 待抉择队列：弟子获得的极：特殊道具，等待玩家决定“交宗换贡献”或“弟子自留：
var 待抉择: Array[Dictionary] = []
# 奇遇待抉择队列（ADR-002 D4）：： 奇遇需掌门干预；结：{弟子, 奇遇： 选项}；会话瞬时，load 时清空
var 奇遇待抉择: Array[Dictionary] = []

# ============ S27 宗门任务榜（§4.0 弟子自主层）============
# 双轨：玩家挂榜 → 弟子自主接取；弟子请命 → 玩家批准/驳回。
# 报酬走「库房拨付」：完成任务后从 宗门库房 拨一件该品阶之物进弟子 背包（不新建货币）。
var 宗门任务榜: Dictionary = {}          # 任务ID -> {任务ID, 模板ID, 任务名, 类型, 难度, 报酬品阶, 要求数量, 接取弟子ID, 发布日, 状态}
var 宗门任务进行中: Dictionary = {}      # 实例ID -> {实例ID, 任务ID, 弟子ID, 开始游戏日, 预计结束游戏日, 模板ID, 报酬品阶}
var 弟子请命列表: Array[Dictionary] = [] # [{弟子ID, 弟子名, 模板ID, 任务名, 类型, 难度, 意愿, 理由, 发布日}]
var 宗门任务计数器: int = 0
# ============ S28 宗门悬赏榜（玩家自由发布悬赏，弟子接单完成）============
var 宗门悬赏榜: Dictionary = {}          # 悬赏ID -> {悬赏ID, 目标物类别, 目标物名称, 需求数量, 已收集, 奖励类型, 奖励数量, 接取弟子ID, 发布日, 有效期, 状态}
var 宗门悬赏计数器: int = 0
# 宗门纪事（完善版）：分类记录宗门大事，持久化存储
# 分类：大事件（宗门里程碑）、岁纪（年度总结）、庶务（日常运营）、异闻（稀有奇遇）
var 宗门纪事: Array = []
const 纪事分类 = ["大事件", "岁纪", "庶务", "异闻", "宗门典籍"]

# ============ 宗门典籍系统（修真世界观：记载宗门千年兴衰）============
# 基于现有纪事系统扩展，自动整理记录，零玩法影响，纯沉浸感
# 典籍分类：历代宗主录、宗门大事记、功法传承录、名人堂

## 获取宗门典籍（按分类整理纪事）
func 获取宗门典籍(典籍类型: String = "全部", 数量: int = 50) -> Array:
	var 结果: Array = []
	match 典籍类型:
		"历代宗主录":
			# 从纪事中筛选宗主相关记录
			for 纪事 in 宗门纪事:
				var 标题: String = str(纪事.get("标题", ""))
				var 内容: String = str(纪事.get("内容", ""))
				if "宗主" in 标题 or "宗主" in 内容 or "继位" in 标题 or "退位" in 标题:
					结果.append(纪事)
					if 结果.size() >= 数量:
						break
		"宗门大事记":
			# 重要度>=2的纪事
			for 纪事 in 宗门纪事:
				if int(纪事.get("重要度", 1)) >= 2:
					结果.append(纪事)
					if 结果.size() >= 数量:
						break
		"功法传承录":
			# 功法相关纪事
			for 纪事 in 宗门纪事:
				var 标题: String = str(纪事.get("标题", ""))
				var 内容: String = str(纪事.get("内容", ""))
				if "功法" in 标题 or "功法" in 内容 or "传承" in 标题 or "自创" in 标题 or "藏经阁" in 标题:
					结果.append(纪事)
					if 结果.size() >= 数量:
						break
		"名人堂":
			# 弟子飞升、杰出弟子相关纪事
			for 纪事 in 宗门纪事:
				var 标题: String = str(纪事.get("标题", ""))
				var 内容: String = str(纪事.get("内容", ""))
				if "飞升" in 标题 or "飞升" in 内容 or "杰出" in 标题 or "天骄" in 标题 or "名人" in 标题:
					结果.append(纪事)
					if 结果.size() >= 数量:
						break
		_:
			结果 = 获取纪事("宗门典籍", 数量)
	return 结果

## 获取典籍统计信息
func 获取典籍统计() -> Dictionary:
	var 统计: Dictionary = {
		"历代宗主": 0,
		"宗门大事": 0,
		"功法传承": 0,
		"名人堂": 0,
		"开宗日": 0,
		"宗门年龄": 0
	}
	for 纪事 in 宗门纪事:
		var 标题: String = str(纪事.get("标题", ""))
		var 内容: String = str(纪事.get("内容", ""))
		if "宗主" in 标题 or "宗主" in 内容 or "继位" in 标题:
			统计["历代宗主"] += 1
		if int(纪事.get("重要度", 1)) >= 2:
			统计["宗门大事"] += 1
		if "功法" in 标题 or "功法" in 内容 or "传承" in 标题:
			统计["功法传承"] += 1
		if "飞升" in 标题 or "飞升" in 内容 or "杰出" in 标题:
			统计["名人堂"] += 1
	统计["开宗日"] = 0   # 开宗日（游戏日0）
	统计["宗门年龄"] = 累计游戏日   # 宗门年龄（游戏日）
	return 统计

## 添加宗门典籍记录
func 添加宗门典籍(典籍类型: String, 标题: String, 内容: String = "", 重要度: int = 2) -> void:
	添加纪事("宗门典籍", 标题, 内容, 重要度)

# ============ 宗门庆典系统（修真世界观：祭祖/收徒/论道大会）============
# 基于现有大典系统扩展，增加3种庆典，效果小，主要沉浸感

## 祭祖大典（每年清明自动举办，游戏日第90天）
func 举办祭祖大典() -> Dictionary:
	# 消耗
	var 消耗灵石: int = 500 * max(1, 门派等级)
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足，举办祭祖大典需%d灵石" % 消耗灵石}
	灵石 -= 消耗灵石
	# 效果：弟子忠诚+2，气运+2
	for d in 弟子列表:
		if d != null and d is Disciple and d.状态 == "在宗":
			d.忠诚 = min(100, int(d.忠诚) + 2)
	# 气运加成（临时，持续30游戏日）
	设置气运buff(0.02, 0.01, 30)
	# 纪事和推演
	添加宗门典籍("宗门大事记", "祭祖大典", "太玄宗举办祭祖大典，供奉历代祖师，缅怀先贤。全宗弟子齐聚祖师堂，焚香叩拜，感念祖师恩德。大典之后，弟子忠诚精进，宗门气运提升。", 2)
	_加推演条目("【祭祖大典】太玄宗祭祖大典圆满成功。全宗弟子齐聚祖师堂，缅怀历代祖师。弟子忠诚+2，宗门气运提升。", ET_SECT, PRIO_NORMAL, {})
	return {"成功": true, "消耗灵石": 消耗灵石, "效果": "弟子忠诚+2，气运+2%（30日）"}

## 收徒大典（大规模收徒后可主动举办）
func 举办收徒大典() -> Dictionary:
	# 消耗
	var 消耗灵石: int = 300 * max(1, 门派等级)
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足，举办收徒大典需%d灵石" % 消耗灵石}
	灵石 -= 消耗灵石
	# 效果：在宗弟子忠诚+3，宗门声望+10
	var 新弟子数: int = 0
	for d in 弟子列表:
		if d != null and d is Disciple and d.状态 == "在宗":
			d.忠诚 = min(100, int(d.忠诚) + 3)
			新弟子数 += 1
	声望 += 10
	# 纪事和推演
	添加宗门典籍("宗门大事记", "收徒大典", "太玄宗举办收徒大典，接引新弟子入门。大典之上，新弟子跪拜祖师，聆听门规，正式成为太玄宗弟子。共有%d名新弟子参加大典。" % 新弟子数, 2)
	_加推演条目("【收徒大典】太玄宗收徒大典圆满成功。%d名新弟子正式入门，忠诚+5。宗门声望+10。" % 新弟子数, ET_SECT, PRIO_NORMAL, {})
	return {"成功": true, "消耗灵石": 消耗灵石, "新弟子数": 新弟子数, "效果": "新弟子忠诚+5，声望+10"}

## 论道大会（每3年可主动举办一次）
var 论道大会冷却: int = 0   # 距离下次可举办论道大会的游戏日
var _祭祖大典年份标记: int = -1   # 祭祖大典已举办年份标记（避免重复举办）

func _祭祖大典已举办今年() -> bool:
	var 当前年份: int = int(累计游戏日 / 360)
	return _祭祖大典年份标记 == 当前年份

func _标记祭祖大典已举办() -> void:
	_祭祖大典年份标记 = int(累计游戏日 / 360)

# ============ 气运可视化系统（修真世界观：气运影响宗门兴衰）============
# 基于现有气运系统扩展，增加事件提示和UI展示
# 气运等级：气运昌隆(80+)/气运旺盛(60+)/气运平稳(40+)/气运低迷(20+)/气运衰败(0+)

## 气运事件月度触发（根据气运等级概率触发机缘/灾厄事件）
## 注意：此函数只在月度结算时调用（推演一月中）
func _气运事件月度触发() -> void:
	var 气运值: int = 获取气运值()
	var 气运等级: String = 获取气运等级()
	var 触发概率: float = 0.0
	var 是机缘: bool = false
	match 气运等级:
		"气运昌隆":
			触发概率 = 0.05   # 5%概率触发机缘
			是机缘 = true
		"气运旺盛":
			触发概率 = 0.03   # 3%概率触发机缘
			是机缘 = true
		"气运平稳":
			触发概率 = 0.0    # 平稳无特殊事件
		"气运低迷":
			触发概率 = 0.03   # 3%概率触发灾厄
			是机缘 = false
		"气运衰败":
			触发概率 = 0.05   # 5%概率触发灾厄
			是机缘 = false
	if randf() >= 触发概率:
		return
	# 触发事件
	if 是机缘:
		_触发气运机缘事件()
	else:
		_触发气运灾厄事件()

## 气运机缘事件（气运昌隆/旺盛时触发）
func _触发气运机缘事件() -> void:
	var 事件类型: int = randi() % 3
	match 事件类型:
		0:
			# 弟子顿悟
			var 在宗弟子: Array = []
			for d in 弟子列表:
				if d != null and d is Disciple and d.状态 == "在宗":
					在宗弟子.append(d)
			if 在宗弟子.size() > 0:
				var 幸运弟子: Disciple = 在宗弟子[randi() % 在宗弟子.size()]
				幸运弟子.修炼进度 = min(1.0, float(幸运弟子.修炼进度) + 0.15)
				添加纪事("修炼", "气运机缘", "%s受宗门气运庇佑，修炼中豁然开朗，进度+15%%" % 幸运弟子.姓名, 2)
				_加推演条目("【气运机缘】%s受宗门气运庇佑，修炼中豁然开朗，修为大进。" % 幸运弟子.姓名, ET_SECT, PRIO_NORMAL, {})
		1:
			# 发现宝物
			var 灵石奖励: int = 500 * max(1, 门派等级)
			灵石 += 灵石奖励
			添加纪事("庶务", "气运机缘", "宗门气运昌隆，弟子于后山发现前人遗留洞府，获灵石%d枚。" % 灵石奖励, 2)
			_加推演条目("【气运机缘】宗门气运昌隆，弟子于后山发现前人遗留洞府，获灵石%d枚。" % 灵石奖励, ET_SECT, PRIO_NORMAL, {})
		2:
			# 灵脉异动，灵气充沛
			设置气运buff(0.05, 0.05, 30)
			添加纪事("庶务", "气运机缘", "宗门气运昌隆，灵脉异动，灵气愈发充沛，修炼产出临时提升。", 2)
			_加推演条目("【气运机缘】宗门气运昌隆，灵脉异动，灵气愈发充沛，修炼与产出临时提升。", ET_SECT, PRIO_NORMAL, {})

## 气运灾厄事件（气运低迷/衰败时触发）
func _触发气运灾厄事件() -> void:
	var 事件类型: int = randi() % 3
	match 事件类型:
		0:
			# 弟子走火入魔
			var 在宗弟子: Array = []
			for d in 弟子列表:
				if d != null and d is Disciple and d.状态 == "在宗":
					在宗弟子.append(d)
			if 在宗弟子.size() > 0:
				var 不幸弟子: Disciple = 在宗弟子[randi() % 在宗弟子.size()]
				不幸弟子.修炼进度 = max(0.0, float(不幸弟子.修炼进度) - 0.1)
				不幸弟子.心魔值 = min(100, int(不幸弟子.心魔值) + 10)
				添加纪事("修炼", "气运灾厄", "%s受宗门气运低迷影响，修炼中走火入魔，进度-10%%，心魔+10" % 不幸弟子.姓名, 2)
				_加推演条目("【气运灾厄】%s受宗门气运低迷影响，修炼中走火入魔，修为倒退，心魔滋生。" % 不幸弟子.姓名, ET_SECT, PRIO_NORMAL, {})
		1:
			# 资源损失
			var 灵石损失: int = min(int(灵石 * 0.05), 1000 * max(1, 门派等级))
			灵石 = max(0, 灵石 - 灵石损失)
			添加纪事("庶务", "气运灾厄", "宗门气运衰败，库房不慎走水，损失灵石%d枚。" % 灵石损失, 2)
			_加推演条目("【气运灾厄】宗门气运衰败，库房不慎走水，损失灵石%d枚。" % 灵石损失, ET_SECT, PRIO_NORMAL, {})
		2:
			# 弟子叛逃
			var 在宗弟子: Array = []
			for d in 弟子列表:
				if d != null and d is Disciple and d.状态 == "在宗" and int(d.忠诚) < 50:
					在宗弟子.append(d)
			if 在宗弟子.size() > 0:
				var 叛逃弟子: Disciple = 在宗弟子[randi() % 在宗弟子.size()]
				叛逃弟子.状态 = "叛逃"
				添加纪事("庶务", "气运灾厄", "宗门气运衰败，%s心生不满，叛逃下山。" % 叛逃弟子.姓名, 2)
				_加推演条目("【气运灾厄】宗门气运衰败，%s心生不满，叛逃下山。" % 叛逃弟子.姓名, ET_SECT, PRIO_HIGH, {})

## 获取气运详细信息（用于UI展示）
## 注意：已有获取气运详情函数，此处不重复定义

func 可举办论道大会() -> bool:
	return 累计游戏日 >= 论道大会冷却

func 举办论道大会() -> Dictionary:
	if not 可举办论道大会():
		return {"成功": false, "原因": "论道大会每3年举办一次，下次可举办时间：第%d日" % 论道大会冷却}
	# 消耗
	var 消耗灵石: int = 1000 * max(1, 门派等级)
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足，举办论道大会需%d灵石" % 消耗灵石}
	灵石 -= 消耗灵石
	# 设置冷却（3年=1080游戏日）
	论道大会冷却 = 累计游戏日 + 1080
	# 效果：参与弟子悟道点+30，有概率顿悟
	var 参与弟子数: int = 0
	var 顿悟弟子数: int = 0
	for d in 弟子列表:
		if d != null and d is Disciple and d.状态 == "在宗":
			参与弟子数 += 1
			悟道点 += 30
			# 10%概率顿悟
			if randf() < 0.1:
				d.修炼进度 = min(1.0, float(d.修炼进度) + 0.1)
				顿悟弟子数 += 1
				添加纪事("修炼", "论道顿悟", "%s于论道大会中豁然开朗，修炼进度+10%%" % d.姓名, 2)
	# 纪事和推演
	添加宗门典籍("宗门大事记", "论道大会", "太玄宗举办论道大会，全宗弟子齐聚论道堂，交流修行心得。大会之上，百家争鸣，道意盎然。共有%d名弟子参与大会，其中%d名弟子于论道中顿悟。" % [参与弟子数, 顿悟弟子数], 2)
	_加推演条目("【论道大会】太玄宗论道大会圆满成功。%d名弟子参与论道，悟道点+30。%d名弟子于论道中顿悟，修为大进。" % [参与弟子数, 顿悟弟子数], ET_SECT, PRIO_HIGH, {})
	return {"成功": true, "消耗灵石": 消耗灵石, "参与弟子数": 参与弟子数, "顿悟弟子数": 顿悟弟子数, "效果": "参与弟子悟道点+30，10%概率顿悟"}
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

# ============ §6.16 家族AI托管策略系统（P4优化实现）============
# 修真世界设定：玩家制定家族策略，AI根据策略自动执行日常管理
# 玩家只做重大决策，减少繁琐手动操作

# 家族策略配置

# ===== 家族策略函数（已拆分到family_system.gd，此处为转发函数）=====
func 设置家族策略(家族ID: String, 策略类型: String, 策略值: String, 操作者: Disciple):
	return 家族系统.设置家族策略(家族ID, 策略类型, 策略值, 操作者)
func 获取家族策略(家族ID: String):
	return 家族系统.获取家族策略(家族ID)
func 家族AI托管执行(家族ID: String):
	return 家族系统.家族AI托管执行(家族ID)
func 月度家族结算():
	return 家族系统.月度家族结算()

var 先贤堂: Array = []
# ============ 飞升系统（祖师堂·飞升弟子轻量存储·持续回馈）============
# 祖师堂：飞升弟子的轻量档案（不持有Disciple引用，防悬空）
# 每个飞升弟子：弟子ID/姓名/境界/飞升日/飞升路线/留下传承/气运加成
var 祖师堂: Array = []
# 飞升前兆队列：即将飞升的弟子（提前30游戏日预警）
var 飞升前兆队列: Array = []
# 飞升气运加成：每个飞升弟子全宗修炼+1%（运行时计算，不持久化单独字段）

# ===== P1联动：先贤堂等级 → 全宗修炼加成 =====
# 先贤堂等级：根据入册弟子数量和境界计算
func 获取先贤堂等级() -> int:
	if 先贤堂.is_empty():
		return 1
	var 总境界值: int = 0
	for 先贤 in 先贤堂:
		var 境界: String = str(先贤.get("境界", "练气"))
		总境界值 += Disciple.境界序.find(境界) + 1
	# 每100境界值升1级，上限10级
	return min(10, 1 + 总境界值 / 100)

# 先贤堂修炼加成：每级+2%全宗修炼速度，上限20%
func 获取先贤堂修炼加成() -> float:
	var 等级: int = 获取先贤堂等级()
	return float(等级) * 0.02  # 每级+2%
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
# ===== 统一增益管理系统（P0-2：经济增益上限红线接入）=====
# 区分永久/限时增益，接入4个上限常量
# 设计原则：基础增益（藏经阁/血脉/家族等）不受此限，仅针对付费/活动/殿阁/彩蛋类增益

# 限时增益统计（彩蛋临时+藏书阁临时+气运），用于全局上限检查
func 统计限时增益() -> Dictionary:
	var 结果: Dictionary = {"总加成": 0.0, "明细": {}}
	# 彩蛋临时增益（修炼+产出）
	var 彩蛋修炼: float = 彩蛋修炼加成()
	var 彩蛋产出: float = 彩蛋产出加成()
	结果["明细"]["彩蛋修炼"] = 彩蛋修炼
	结果["明细"]["彩蛋产出"] = 彩蛋产出
	结果["总加成"] += 彩蛋修炼 + 彩蛋产出
	# 藏书阁临时加成
	结果["明细"]["藏书阁临时"] = 藏书阁系统.藏书阁临时加成
	结果["总加成"] += 藏书阁系统.藏书阁临时加成
	# 气运加成
	结果["明细"]["气运修炼"] = 气运修炼加成
	结果["明细"]["气运产出"] = 气运产出加成
	结果["总加成"] += 气运修炼加成 + 气运产出加成
	return 结果

# 限时增益全局上限检查（返回被限制后的实际值）
func 应用限时增益上限(原始值: float) -> float:
	var 上限: float = 增益限时全局上限 / 100.0  # 转换为小数（8.0 -> 0.08）
	return min(原始值, 上限)

# 单条增益上限检查（返回被限制后的实际值）
func 应用单条增益上限(原始值: float) -> float:
	var 上限: float = 增益单条上限 / 100.0  # 转换为小数（5.0 -> 0.05）
	return min(原始值, 上限)

# 彩蛋永久增益上限检查
func 应用彩蛋永久上限(原始值: float) -> float:
	return min(原始值, 彩蛋永久总上限)  # 已经是小数（0.03）

# ============ P0-2：永久增益全局上限接入（增益永久全局上限=3%）============
# 永久增益统计（彩蛋永久+血脉+道友结义+王朝奇观+付费永久等），用于全局上限检查
# 设计原则：基础增益（藏经阁/血脉/家族等）不受此限，仅针对付费/活动/殿阁/彩蛋类永久增益
func 统计永久增益() -> Dictionary:
	var 结果: Dictionary = {"总加成": 0.0, "明细": {}}
	# 彩蛋永久增益（当前简化为0，后续接入彩蛋永久系统时统计）
	结果["明细"]["彩蛋永久"] = 0.0
	# 付费永久增益（付费增益值，战斗通用增益）
	结果["明细"]["付费永久"] = 付费增益值 / 100.0  # 转换为小数
	结果["总加成"] += 付费增益值 / 100.0
	# 道友结义永久加成（修炼速度+1%，最多5%，当前简化为0）
	结果["明细"]["道友结义"] = 0.0
	# 王朝奇观永久加成（当前简化为0，后续接入奇观系统时统计）
	结果["明细"]["王朝奇观"] = 0.0
	return 结果

# 永久增益全局上限检查（返回被限制后的实际值）
# 规则：永久类全局总增益≤3%（与彩蛋永久红线对齐）
func 应用永久增益上限(原始值: float) -> float:
	var 上限: float = 增益永久全局上限 / 100.0  # 转换为小数（3.0 -> 0.03）
	return min(原始值, 上限)

# 检查永久增益是否还有剩余额度（用于添加新永久增益时的前置检查）
func 获取永久增益剩余额度() -> float:
	var 当前永久总加成: float = 统计永久增益().get("总加成", 0.0)
	var 上限: float = 增益永久全局上限 / 100.0
	return max(0.0, 上限 - 当前永久总加成)

# 增益统计快照（用于UI显示和调试）
func 增益统计快照() -> Dictionary:
	var 限时: Dictionary = 统计限时增益()
	var 永久: Dictionary = 统计永久增益()
	return {
		"限时增益": 限时,
		"限时增益上限": 增益限时全局上限,
		"永久增益": 永久,
		"永久增益上限": 增益永久全局上限,
		"单条增益上限": 增益单条上限,
		"彩蛋永久上限": 彩蛋永久总上限,
		"付费增益值": 付费增益值,
		"彩蛋临时增益数": 彩蛋临时增益.size(),
	}
# 通用增益(战斗)：5%/：0% ：disciple.gd _clamp_soft(...,0.25,0.30,0.2)，付费buff并入同池共享封顶
# ===== 付费预留接入点（S0 stub：全部置灰，当前不生效，S1 接真实支：广告后端：====
const 付费单价: Dictionary = {
	"修炼加速": 50,   # P1优化：全体弟子推进7游戏日修炼（原20性价比过高）
	"灵兽孵化": 30,   # 立即完成所有孵化中灵兽
	"坊市刷新": 5,    # 手动刷新坊市上架
	"历练额外": 15,   # +1次历练（突破今日/本周限制）
	"殿阁产出": 25,   # 立即发放预估月产出(灵石)
	"全局增益": 50,   # +5%战斗通用增益(共享封顶)
}

# 统一前缀 _pay_reserved_，全局可检索；每个对应一个未来付费功能入口：
func _pay_reserved_修炼加成() -> Dictionary:

	# 付费：消耗灵玉布设聚灵阵，辅助全体弟子修炼7日
	var 价: int = 付费单价.get("修炼加速", 50)
	if not 消耗仙玉_付费(价):
		return {"成功": false, "原因": "灵玉不足"}
	var 天数: float = 7.0
	for d in 弟子列表:
		if d != null and d.has_method("推进修炼"):
			d.推进修炼(天数)
	记任务进度("pay_accelerate_cultivate")
	_加推演条目("【宗门】宗主耗灵玉布设聚灵阵，辅助全宗弟子苦修七日。", ET_SECT, PRIO_NORMAL, {})
	添加纪事("付费", "布设聚灵阵", "宗主耗灵玉布设聚灵阵，全宗弟子苦修七日，修为大进", 2)
	return {"成功": true, "天数": 天数, "弟子数": 弟子列表.size()}
func _pay_reserved_灵兽加成() -> Dictionary:

	# 付费：消耗灵玉以妖兽精血催化，加速灵兽孵化
	var 价: int = 付费单价.get("灵兽孵化", 30)
	if not 消耗仙玉_付费(价):
		return {"成功": false, "原因": "灵玉不足"}
	var 完成数: int = 0
	for 兽 in 灵兽蛋列表:
		if 兽 == null:
			continue
		var 兽对象 = 兽  # 无类型临时变量，避免Godot 4.x类型推断问题（if is Beast后推断为Beast，后续elif is Dictionary报错）
		var 孵化中: bool = false
		if 兽对象 is Beast:
			孵化中 = 兽对象.孵化中
		elif 兽对象 is Dictionary:
			孵化中 = bool(兽对象.get("孵化中", false))
		if not 孵化中:
			continue
		if 兽对象 is Beast:
			兽对象.孵化()
		elif 兽对象 is Dictionary:
			兽对象["孵化中"] = false
			兽对象["剩余天数"] = 0
		完成数 += 1
	记任务进度("pay_hatch_beast")
	if 完成数 > 0:
		_加推演条目("【御兽峰】宗主以灵玉购妖兽精血，催化%d枚灵兽蛋即刻破壳。" % 完成数, ET_SECT, PRIO_NORMAL, {})
		添加纪事("付费", "催化灵兽", "宗主以灵玉购妖兽精血，催化%d枚灵兽蛋即刻破壳" % 完成数, 2)
	return {"成功": true, "完成数": 完成数}
func _pay_reserved_坊市购买() -> Dictionary:

	# 付费：消耗灵玉邀请四方商旅，刷新坊市上架
	var 价: int = 付费单价.get("坊市刷新", 5)
	if not 消耗仙玉_付费(价):
		return {"成功": false, "原因": "灵玉不足"}
	刷新坊市上架()
	记任务进度("pay_refresh_market")
	_加推演条目("【坊市】宗主耗灵玉邀请四方商旅，坊市货品焕然一新。", ET_SECT, PRIO_NORMAL, {})
	添加纪事("付费", "刷新坊市", "宗主耗灵玉邀请四方商旅，坊市货品焕然一新", 1)
	return {"成功": true}
func _pay_reserved_历练购买() -> Dictionary:

	# 付费：消耗灵玉颁发宗门令牌，增加弟子历练名额
	var 价: int = 付费单价.get("历练额外", 15)
	if not 消耗仙玉_付费(价):
		return {"成功": false, "原因": "灵玉不足"}
	历练额外次数 += 1
	记任务进度("pay_expedition_extra")
	_加推演条目("【宗门】宗主耗灵玉颁发宗门令牌，新增一次历练名额。", ET_SECT, PRIO_NORMAL, {})
	添加纪事("付费", "颁发令牌", "宗主耗灵玉颁发宗门令牌，新增一次历练名额", 1)
	return {"成功": true, "剩余额外": 历练额外次数}
func _pay_reserved_殿阁加成() -> Dictionary:

	# 付费：消耗灵玉提前收取殿阁产出（不与月底月度结算重复）
	var 价: int = 付费单价.get("殿阁产出", 25)
	if not 消耗仙玉_付费(价):
		return {"成功": false, "原因": "灵玉不足"}
	var 额: int = 预估月产出()
	灵石 += 额
	记任务进度("pay_collect_hall")
	_加推演条目("【殿阁】宗主耗灵玉提前支取殿阁产出，得灵石%d枚。" % 额, ET_SECT, PRIO_NORMAL, {})
	添加纪事("付费", "支取产出", "宗主耗灵玉提前支取殿阁产出，得灵石%d枚" % 额, 1)
	return {"成功": true, "额": 额}
func _pay_reserved_全局增益() -> Dictionary:

	# 付费：消耗灵玉请宗门长老加持，获得战斗增益（并入 disciple.聚合通用增益() 共享25/30%封顶）
	var 价: int = 付费单价.get("全局增益", 50)
	if not 消耗仙玉_付费(价):
		return {"成功": false, "原因": "灵玉不足"}
	# P0-2：接入单条增益上限检查（每次+5%，单条上限5%，符合上限）
	var 新增增益: float = 0.05
	新增增益 = 应用单条增益上限(新增增益)
	# P0-2：接入永久增益全局上限检查（付费永久增益≤3%）
	var 永久剩余额度: float = 获取永久增益剩余额度()
	新增增益 = min(新增增益, 永久剩余额度 * 100.0)  # 转换为百分比
	if 新增增益 <= 0:
		return {"成功": false, "原因": "永久增益已达上限（3%）", "当前增益": 付费增益值}
	付费增益值 += 新增增益   # +5%（受单条上限和永久全局上限双重约束）
	记任务进度("pay_global_buff")
	_加推演条目("【宗门】宗主耗灵玉请长老加持，全宗道行+%.1f%%。" % 新增增益, ET_SECT, PRIO_NORMAL, {})
	添加纪事("付费", "长老加持", "宗主耗灵玉请长老加持，全宗道行+%.1f%%" % 新增增益, 2)
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
		if str(r.get("品阶") if "品阶" in r else "") == 兽种类 and str(r.get("类型") if "类型" in r else "") == 兽类型:
			return {"文案": r.get("文案") if "文案" in r else "".replace("{种类}", 兽种类名), "category": r.get("category") if "category" in r else ""}
	for r in 表:
		if str(r.get("品阶") if "品阶" in r else "") == 兽种类 and str(r.get("类型") if "类型" in r else "") == "通用":
			return {"文案": r.get("文案") if "文案" in r else "".replace("{种类}", 兽种类名), "category": r.get("category") if "category" in r else ""}
	for r in 表:
		if str(r.get("品阶") if "品阶" in r else "") == "通用" and str(r.get("类型") if "类型" in r else "") == 兽类型:
			return {"文案": r.get("文案") if "文案" in r else "".replace("{种类}", 兽种类名), "category": r.get("category") if "category" in r else ""}
	for r in 表:
		if str(r.get("品阶") if "品阶" in r else "") == "通用" and str(r.get("类型") if "类型" in r else "") == "通用":
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
# ===== 商队系统（已拆分到caravan_system.gd，此处保留兼容）=====
var 商队系统: CaravanSystem = CaravanSystem.new()
var 灵钓系统: FishingSystem = FishingSystem.new()   # 灵钓系统（S46 钓鱼闭环）
var 系统解锁: SystemUnlock = SystemUnlock.new()     # P0-1 洋葱式系统解锁引擎（表驱动 config/unlock_order.csv）
var 探秘系统: RelicSystem = RelicSystem.new()   # 探遗迹系统（S47 探秘闭环）
var 饲灵系统: BeastRaiseSystem = BeastRaiseSystem.new()   # 饲灵育兽系统（S48 饲灵闭环）
var 卜算系统: DivineSystem = DivineSystem.new()   # 卜算星盘系统（S49 卜算闭环）
var 药圃系统: HerbSystem = HerbSystem.new()   # 药圃经营系统（S50 种植闭环）
var 拍卖行系统: AuctionSystem = AuctionSystem.new()
var 全服拍卖系统: GlobalAuctionSystem = GlobalAuctionSystem.new()  # 全服玩家拍卖会
var 消息系统: MessageSystem = MessageSystem.new()  # S56 修真世界消息系统
var 世界地图系统: WorldMapSystem = WorldMapSystem.new()  # S58 世界地图系统
# 道友系统：提供 获取道友拜访修炼加成() 等。
#   原缺声明（月度修炼处直接调用 好友系统.xxx），导致 GDScript 编译期未声明标识符。
var 好友系统: FriendSystem = FriendSystem.new()
var 闭关嘱托: OfflineManager = OfflineManager.new()  # S59 闭关嘱托系统（离线代理）
var 派系系统: FactionSystem = FactionSystem.new()
var 家族系统: FamilySystem = FamilySystem.new()
var 种族系统: RaceSystem = RaceSystem.new()
var 王朝系统: DynastySystem = DynastySystem.new()
var 通婚子嗣系统: MarriageSystem = MarriageSystem.new()
var 道友系统: FriendSystem = FriendSystem.new()
var 论道系统: ChessSystem = ChessSystem.new()  # 论道棋弈系统实例
var 药园系统: HerbGardenSystem = HerbGardenSystem.new()
var 丹纹系统: DanMarkSystem = DanMarkSystem.new()
var 符纹系统: TalismanMarkSystem = TalismanMarkSystem.new()
var 阵营声望系统: FactionReputationSystem = FactionReputationSystem.new()   # 阵营声望系统实例
var 傀儡系统: PuppetSystem = PuppetSystem.new()   # 傀儡系统实例
var 藏书阁系统: LibrarySystem = LibrarySystem.new()   # 藏书阁系统实例
var 阵法管理系统: FormationSystem = FormationSystem.new()   # 阵法管理系统实例
var 坐骑系统: MountSystem = MountSystem.new()   # 坐骑系统实例
var 碎片宝箱系统: FragmentChestSystem = FragmentChestSystem.new()   # 碎片宝箱系统实例
var 邮件系统: MailSystem = MailSystem.new()   # 邮件系统实例

# ============ 实时传讯系统（修真风格通讯）============
var 待处理传讯: Array = []   # 待玩家回复的实时传讯（[{传讯ID,发件人,类型,内容,选项,触发数据,时间}]）
var 传讯历史: Array = []   # 已处理的传讯记录（存档上限100条）
var 传讯通知信号: bool = false   # 通知标记（UI轮询，有新传讯时true）
const 传讯历史上限: int = 100   # 传讯历史存档上限
signal 新传讯到达(传讯数据)   # 新传讯到达信号

## 触发实时传讯（通用入口）
func 触发传讯(发件人: String, 类型: String, 内容: String, 选项: Array, 触发数据: Dictionary = {}) -> Dictionary:
	var 传讯ID: int = randi()
	var 传讯: Dictionary = {
		"传讯ID": 传讯ID,
		"发件人": 发件人,
		"类型": 类型,   # 弟子求援/机缘报喜/宗门邀约/敌对威胁/紧急军情
		"内容": 内容,
		"选项": 选项,   # [{文本,动作,参数}]
		"触发数据": 触发数据,
		"时间": 累计游戏日,
		"已读": false
	}
	待处理传讯.append(传讯)
	传讯通知信号 = true
	新传讯到达.emit(传讯)
	# 同时存入邮件系统作为存档（传讯录分类）
	邮件系统.邮件列表.append({
		"发件人": 发件人,
		"标题": "【传讯】%s" % 类型,
		"内容": 内容,
		"时间": "第%d日" % 累计游戏日,
		"附件": {},
		"未读": false,
		"已领": false,
		"分类": "传讯录"
	})
	return {"成功": true, "传讯ID": 传讯ID}

## 回复传讯（玩家选择选项后调用）
func 回复传讯(传讯ID: int, 选项索引: int) -> Dictionary:
	var 目标传讯: Dictionary = {}
	var 传讯索引: int = -1
	for i in range(待处理传讯.size()):
		if int(待处理传讯[i]["传讯ID"]) == 传讯ID:
			目标传讯 = 待处理传讯[i]
			传讯索引 = i
			break
	if 传讯索引 < 0:
		return {"成功": false, "原因": "传讯不存在或已处理"}
	if 选项索引 < 0 or 选项索引 >= int(目标传讯["选项"].size()):
		return {"成功": false, "原因": "选项无效"}
	var 选中选项: Dictionary = 目标传讯["选项"][选项索引]
	# 执行选项动作
	var 结果: Dictionary = _执行传讯动作(目标传讯, 选中选项)
	# 移入历史
	目标传讯["玩家选择"] = 选中选项.get("文本", "")
	目标传讯["处理结果"] = 结果
	传讯历史.append(目标传讯)
	if 传讯历史.size() > 传讯历史上限:
		传讯历史.remove_at(0)
	# 从待处理移除
	待处理传讯.remove_at(传讯索引)
	if 待处理传讯.is_empty():
		传讯通知信号 = false
	return {"成功": true, "结果": 结果, "选择": 选中选项.get("文本", "")}

## 执行传讯动作（内部）
func _执行传讯动作(传讯: Dictionary, 选项: Dictionary) -> Dictionary:
	var 动作: String = str(选项.get("动作", ""))
	var 参数: Dictionary = 选项.get("参数", {})
	var 触发数据: Dictionary = 传讯.get("触发数据", {})
	match 动作:
		"弟子_速速回宗":
			# 弟子立即终止历练返回
			if 触发数据.has("弟子ID"):
				var d: Object = _取弟子(int(触发数据["弟子ID"]))
				if d != null:
					d.状态 = "在宗"
					return {"成功": true, "消息": "%s已接讯回宗" % d.姓名}
		"弟子_小心行事":
			# 弟子继续历练，谨慎度+20%
			return {"成功": true, "消息": "弟子接讯后小心行事，危险降低"}
		"弟子_全力施为":
			# 弟子继续历练，收益+30%但危险+30%
			return {"成功": true, "消息": "弟子接讯后全力施为，收益与风险并存"}
		"弟子_增援已至":
			# 消耗灵石派遣增援
			var 消耗: int = int(参数.get("灵石", 500))
			if 灵石 >= 消耗:
				灵石 -= 消耗
				return {"成功": true, "消息": "增援已至，弟子安全度大增，消耗灵石%d" % 消耗}
			else:
				return {"成功": false, "消息": "灵石不足，增援失败"}
		"宗门_接受邀约":
			return {"成功": true, "消息": "已接受邀约"}
		"宗门_拒绝邀约":
			return {"成功": true, "消息": "已婉拒邀约"}
		"军情_亲自驰援":
			return {"成功": true, "消息": "宗主亲自驰援"}
		"军情_派遣长老":
			return {"成功": true, "消息": "已派遣长老驰援"}
		"军情_坚守不出":
			return {"成功": true, "消息": "坚守不出，以逸待劳"}
		"弟子_亲自护法":
			# C3①：宗主亲临护法 —— 高加成 × 高代价（对标 sect_manager 既有 0.2，不新造）
			var 护法弟子: Object = _取弟子(int(触发数据.get("弟子ID", -1)))
			var 亲临耗: int = 500
			if 护法弟子 == null:
				return {"成功": false, "消息": "该弟子已不在宗门"}
			if 灵石 < 亲临耗:
				return {"成功": false, "消息": "灵石不足（需 %d），无法亲临护法" % 亲临耗}
			灵石 -= 亲临耗
			护法弟子.待护法突破 = true
			护法弟子.护法加成 = 0.2
			添加纪事("宗门", "护法", "宗主亲临为%s护法，灵力灌注，突破在望（耗灵石%d）。" % [护法弟子.姓名, 亲临耗], 1)
			return {"成功": true, "消息": "%s 得宗主亲临护法，突破把握大增" % 护法弟子.姓名}
		"弟子_遣长老护法":
			# C3①：长老护法 —— 中加成 × 中代价（对标 sect_manager 既有 0.1）
			var 长老弟子: Object = _取弟子(int(触发数据.get("弟子ID", -1)))
			var 长老耗: int = 200
			if 长老弟子 == null:
				return {"成功": false, "消息": "该弟子已不在宗门"}
			if 灵石 < 长老耗:
				return {"成功": false, "消息": "灵石不足（需 %d），无法遣长老护法" % 长老耗}
			灵石 -= 长老耗
			长老弟子.待护法突破 = true
			长老弟子.护法加成 = 0.1
			添加纪事("宗门", "护法", "宗主遣长老为%s护法，左右相助（耗灵石%d）。" % [长老弟子.姓名, 长老耗], 1)
			return {"成功": true, "消息": "%s 得长老护法，突破把握有所增" % 长老弟子.姓名}
		"弟子_自行突破":
			# C3①：不护法 —— 零代价 × 零加成（弟子自行承担风险）
			var 自行弟子: Object = _取弟子(int(触发数据.get("弟子ID", -1)))
			if 自行弟子 == null:
				return {"成功": false, "消息": "该弟子已不在宗门"}
			添加纪事("宗门", "护法", "宗主未予护法，%s 决意自行冲关，成败自负。" % 自行弟子.姓名, 1)
			return {"成功": true, "消息": "%s 将自行突破，不受护法之助" % 自行弟子.姓名}
		"弟子_赐洞府":
			# C3②：赐下个人洞府 —— 受「洞府容量」与「灵石」双重约束（资源倾斜的真实取舍）
			var 洞府弟子: Object = _取弟子(int(触发数据.get("弟子ID", -1)))
			if 洞府弟子 == null:
				return {"成功": false, "消息": "该弟子已不在宗门"}
			var 洞府现级: int = int(洞府弟子.洞府等级)
			if 洞府现级 >= 7:
				return {"成功": false, "消息": "%s 已得道阶洞府，无需再赐" % 洞府弟子.姓名}
			if 洞府拥挤度() >= 1.0:
				return {"成功": false, "消息": "宗门洞府已满（%d间／%d人），请先扩建洞府" % [洞府数量, 在宗弟子数()]}
			var 洞府耗: int = 洞府营造消耗(洞府现级)
			if 灵石 < 洞府耗:
				return {"成功": false, "消息": "灵石不足（需 %d），无法营造洞府" % 洞府耗}
			灵石 -= 洞府耗
			洞府弟子.洞府等级 = 洞府现级 + 1
			添加纪事("宗门", "赐洞府", "宗主赐下洞府一间，%s 得以静心参悟（耗灵石%d）。" % [洞府弟子.姓名, 洞府耗], 1)
			return {"成功": true, "消息": "%s 得赐洞府，修行更进一层" % 洞府弟子.姓名}
		"弟子_令其再候":
			# C3②：不予赐府 —— 零代价，但弟子需再候时机
			var 候府弟子: Object = _取弟子(int(触发数据.get("弟子ID", -1)))
			if 候府弟子 == null:
				return {"成功": false, "消息": "该弟子已不在宗门"}
			添加纪事("宗门", "赐洞府", "宗主令 %s 再候时机，洞府之请暂缓。" % 候府弟子.姓名, 1)
			return {"成功": true, "消息": "%s 暂候时机，宗门洞府另作他用" % 候府弟子.姓名}
		_:
			return {"成功": true, "消息": "已回复"}
	return {"成功": true, "消息": "已回复"}

## 弟子历练触发传讯（历练中遇到重大事件时调用）
func 弟子历练传讯(弟子ID: int, 事件类型: String, 区域: String) -> Dictionary:
	var d: Object = _取弟子(弟子ID)
	if d == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 发件人: String = "弟子·%s" % d.姓名
	var 内容: String = ""
	var 选项: Array = []
	match 事件类型:
		"遭遇危险":
			内容 = "宗主！弟子在%s遭遇强敌，情势危急，请宗主定夺！" % 区域
			选项 = [
				{"文本": "速速回宗", "动作": "弟子_速速回宗", "参数": {}},
				{"文本": "小心行事", "动作": "弟子_小心行事", "参数": {}},
				{"文本": "全力施为", "动作": "弟子_全力施为", "参数": {}},
				{"文本": "增援已至（500灵石）", "动作": "弟子_增援已至", "参数": {"灵石": 500}}
			]
		"发现机缘":
			内容 = "宗主！弟子在%s发现一处疑似古修遗府，是否深入探索？" % 区域
			选项 = [
				{"文本": "深入探索", "动作": "弟子_全力施为", "参数": {}},
				{"文本": "谨慎探查", "动作": "弟子_小心行事", "参数": {}},
				{"文本": "立即回宗", "动作": "弟子_速速回宗", "参数": {}}
			]
		"获得重宝":
			内容 = "宗主！弟子在%s偶获重宝，恐招人觊觎，是否立即护送回宗？" % 区域
			选项 = [
				{"文本": "护送回宗", "动作": "弟子_速速回宗", "参数": {}},
				{"文本": "继续历练", "动作": "弟子_小心行事", "参数": {}}
			]
		_:
			内容 = "宗主！弟子在%s有要事禀报。" % 区域
			选项 = [
				{"文本": "知晓了", "动作": "宗门_接受邀约", "参数": {}}
			]
	return 触发传讯(发件人, "弟子传讯·%s" % 事件类型, 内容, 选项, {"弟子ID": 弟子ID, "区域": 区域, "事件类型": 事件类型})

## C3①：弟子恳请护法 —— 批复前不授予任何加成（去 / 不去各有代价）
## 数值对齐 sect_manager.获取护法成功率加成（亲临 0.2 / 长老 0.1），不新造
func 弟子护法传讯(弟子ID: int) -> Dictionary:
	var 请护弟子: Object = _取弟子(弟子ID)
	if 请护弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 目标境: String = String(请护弟子.下一境界名(请护弟子.境界))
	var 内容: String = ("宗主，弟子%s自觉%s突破在即，恳请宗主定夺护法之事："
		+ "亲临可增20%把握，长老护法可增10%，弟子自行则听天由命。") % [请护弟子.姓名, 目标境]
	var 选项: Array = [
		{"文本": "亲临护法（灵石500）", "动作": "弟子_亲自护法", "参数": {}},
		{"文本": "遣长老护法（灵石200）", "动作": "弟子_遣长老护法", "参数": {}},
		{"文本": "令其自行突破", "动作": "弟子_自行突破", "参数": {}}
	]
	return 触发传讯("弟子·%s" % 请护弟子.姓名, "宗门请示·护法", 内容, 选项, {"弟子ID": 弟子ID, "护法": true})


## C3②：弟子恳请赐下洞府 —— 批复前不占用任何资源
func 弟子洞府传讯(弟子ID: int) -> Dictionary:
	var 请府弟子: Object = _取弟子(弟子ID)
	if 请府弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 求府耗: int = 洞府营造消耗(int(请府弟子.洞府等级))
	var 内容: String = ("宗主，弟子%s苦于居所嘈杂、灵气稀薄，恳请赐下洞府一间，"
		+ "以求静修（需灵石%d，占宗门洞府一间）。") % [请府弟子.姓名, 求府耗]
	var 选项: Array = [
		{"文本": "赐下洞府（灵石%d）" % 求府耗, "动作": "弟子_赐洞府", "参数": {}},
		{"文本": "令其再候时机", "动作": "弟子_令其再候", "参数": {}}
	]
	return 触发传讯("弟子·%s" % 请府弟子.姓名, "宗门请示·洞府", 内容, 选项, {"弟子ID": 弟子ID, "洞府": true})


## C3②：为弟子营造个人洞府的灵石消耗（按已享等级递增）
## rationale：起点 300 与「扩建洞府」基础消耗同量级；递增体现「越到高阶越难求」
func 洞府营造消耗(当前等级: int) -> int:
	return 300 + max(0, 当前等级) * 200


## 获取待处理传讯数量
func 待处理传讯数量() -> int:
	return 待处理传讯.size()

## 清除传讯通知标记
func 清除传讯通知() -> void:
	传讯通知信号 = false

var 宗门科技系统: SectTechSystem = SectTechSystem.new()   # 宗门科技系统实例
var 玄榜系统: XuanRankSystem = XuanRankSystem.new()   # 玄榜系统实例
var 炼丹炼器系统: AlchemyForgeSystem = AlchemyForgeSystem.new()   # 炼丹炼器封装系统实例
var 符箓封装系统: TalismanManagementSystem = TalismanManagementSystem.new()   # 符箓系统封装实例
var 功法管理系统: GongFaManagementSystem = GongFaManagementSystem.new()   # 功法管理系统实例
var 灵兽管理系统: BeastManagementSystem = BeastManagementSystem.new()   # 灵兽管理系统实例
var 弟子突破系统: BreakthroughSystem = BreakthroughSystem.new()   # 弟子突破系统实例
var 成就系统: AchievementSystem = AchievementSystem.new()
# 主界面（新UI）引用注册口：main.gd 构建 game_ui 后注册。
# 供各业务页跨层触发战斗动画（播放战报）等，避免页面自行猜节点路径。
var 主UI: Node = null
# main.gd 在 _进入主界面 装配完 game_ui 后调用
func 注册主UI(ui: Node) -> void:
	主UI = ui
   # 成就系统实例

# ===== 属性转发（子系统拆分后UI零改动方案：Game.xxx 自动转发到对应子系统）=====
var 灵兽库存:
	get: return 灵兽管理系统.灵兽库存
	set(value): 灵兽管理系统.灵兽库存 = value
var 灵兽兑换队列:
	get: return 灵兽管理系统.灵兽兑换队列
	set(value): 灵兽管理系统.灵兽兑换队列 = value
var 傀儡列表:
	get: return 傀儡系统.傀儡列表
	set(value): 傀儡系统.傀儡列表 = value
var 傀儡ID计数器:
	get: return 傀儡系统.傀儡ID计数器
	set(value): 傀儡系统.傀儡ID计数器 = value
var 累计制作傀儡数:
	get: return 傀儡系统.累计制作傀儡数
	set(value): 傀儡系统.累计制作傀儡数 = value
var 藏书阁收录数:
	get: return 藏书阁系统.藏书阁收录数
	set(value): 藏书阁系统.藏书阁收录数 = value
var 藏书阁加成到期日:
	get: return 藏书阁系统.藏书阁加成到期日
	set(value): 藏书阁系统.藏书阁加成到期日 = value
var 阵法等级:
	get: return 阵法管理系统.阵法等级
	set(value): 阵法管理系统.阵法等级 = value
var 阵法耐久度:
	get: return 阵法管理系统.阵法耐久度
	set(value): 阵法管理系统.阵法耐久度 = value
var 阵法驻守弟子:
	get: return 阵法管理系统.阵法驻守弟子
	set(value): 阵法管理系统.阵法驻守弟子 = value
var 阵法强化等级:
	get: return 阵法管理系统.阵法强化等级
	set(value): 阵法管理系统.阵法强化等级 = value
var 坐骑列表:
	get: return 坐骑系统.坐骑列表
	set(value): 坐骑系统.坐骑列表 = value
var 当前坐骑:
	get: return 坐骑系统.当前坐骑
	set(value): 坐骑系统.当前坐骑 = value
var 坐骑ID计数器:
	get: return 坐骑系统.坐骑ID计数器
	set(value): 坐骑系统.坐骑ID计数器 = value
var 碎片库存:
	get: return 碎片宝箱系统.碎片库存
	set(value): 碎片宝箱系统.碎片库存 = value
var 宝箱库存:
	get: return 碎片宝箱系统.宝箱库存
	set(value): 碎片宝箱系统.宝箱库存 = value
var 邮件列表:
	get: return 邮件系统.邮件列表
	set(value): 邮件系统.邮件列表 = value
var 已研究宗门科技:
	get: return 宗门科技系统.已研究宗门科技
	set(value): 宗门科技系统.已研究宗门科技 = value
var 玄榜虚拟宗门:
	get: return 玄榜系统.玄榜虚拟宗门
	set(value): 玄榜系统.玄榜虚拟宗门 = value
var 炼器经验值:
	get: return 炼丹炼器系统.炼器经验值
	set(value): 炼丹炼器系统.炼器经验值 = value
var 功法熟练度:
	get: return 功法管理系统.功法熟练度
	set(value): 功法管理系统.功法熟练度 = value
var 成就_已达成:
	get: return 成就系统.成就_已达成
	set(value): 成就系统.成就_已达成 = value
var 已领取成就奖励:
	get: return 成就系统.已领取成就奖励
	set(value): 成就系统.已领取成就奖励 = value
# ===== 属性转发结束 =====

# ===== 商队系统（已拆分到caravan_system.gd）=====
# 商队状态变量已移至 caravan_system.gd，通过 商队系统.xxx 访问
# 灵舟坞状态变量已移至 caravan_system.gd
var 传送阵等级: int = 0            # 0=未建；≥1 即已立阵（S34c §11.17 传送阵）
var 传送阵表缓存: Dictionary = {}  # teleport_array_config.csv（ta01-06，按等级解锁；ta05-06 灵界预留）
var 传送阵建造中: Dictionary = {}  # {目标档:int, 完成日:int}（非空中表示阵在建造/升级）
var 传送阵今日已用: int = 0       # 当日已传送次数（每日重置）
var 传送阵待机欠费: bool = false  # 待机灵石不足→暂停运转
var enable_teleport_system: bool = true  # §11.17 总控开关：置 false 隐藏传送阵并停用
# S35-2 国教信仰网络（不升SAVE_VERSION，旧档缺键→兜底）
# 数据模型：郡信仰[cid] = {"本宗": float, "异端": float, "异端主": String, "已报警": bool}
#           香火庙[cid] = {"等级": int, "建造中": bool, "完成日": int, "欠费": bool}
var 香火庙: Dictionary = {}
# 郡信仰已移至 dynasty_system.gd
var 信仰表缓存: Dictionary = {}
var enable_faith_system: bool = true   # §11.18 总控开关：置 false 停用信仰网络
# ============ S35-0 王朝邸报层（每日新鲜感 / 不确定性 / 正回馈）============
# 三条设计铁律（对齐 S32 铁律三 / 运维封顶 318）：
#   ① 祥瑞【零货币产出】：只调单郡感恩/灾情/忠顺（全 clamp 0-100）、触发寻访、微调民心/国祚/香火。
#      正回馈 = 郡县变好 → 供奉/苗子提升（供奉已在 318 口径内），不新增全局产出通道。
#   ② 朝奏【每日限 1 道 + 离线不自动结算】：锚点是「现实日序号」而非游戏日，
#      离线 12 王朝月批量推演时 今日序号不变 → 只在首轮生成 1 道，天然防堆积。
#      跨日未批仅记「搁置」，不做逾期惩罚（离线惩罚是留存杀手）。
#   ③ 月度保底邸报：本月零邸报时从郡县动态提炼一条，杜绝连续数月哑火。
const 朝报上限 := 200
const 祥瑞日概率 := 0.18
const 祥瑞每日上限 := 3     # 每【现实日】最多降 N 道祥瑞（离线归来防刷屏）
const 祥瑞最小间隔日 := 2

var 朝报: Array = []
var 朝报未读: int = 0
var 誓约待批: Array = []          # S36 心魔誓：弟子请誓待批 [{弟子ID,弟子名,oath_id,名称,desc,日}]
var 万仙大誓: Dictionary = {}     # S36 万仙大誓：宗门级共誓快照（空=无）
var 誓约推进日: int = 0           # S36 上次推进的现实日序号（离线不跳变）
var 誓约表缓存: Dictionary = {}   # S36 誓约配置缓存 {oath:表, sect_oath:表}
var 朝奏: Dictionary = {}
var 上次朝奏日: int = -1
var 上次祥瑞日: int = -999
var 上次祥瑞日序号: int = -1
var 今日祥瑞数: int = 0
var 下次必降祥瑞: bool = false
var enable_dynasty_gazette: bool = true  # S35-0 总控开关：置 false 关闭邸报与祥瑞
# 其他商队状态变量已移至 caravan_system.gd


# ===== 商队系统（已拆分到caravan_system.gd，此处为转发函数）=====
func 加载商队配置():
	商队系统.加载商队配置()
func _读商队岗位表():
	return 商队系统._读商队岗位表()
func _读商队载具表():
	return 商队系统._读商队载具表()
func _读商品表():
	return 商队系统._读商品表()
func _读城市表():
	return 商队系统._读城市表()
func _读商路表():
	return 商队系统._读商路表()
func _读商路事件表():
	return 商队系统._读商路事件表()
func _读灵舟坞表():
	return 商队系统._读灵舟坞表()
func _读宗门灵舟表():
	return 商队系统._读宗门灵舟表()
func _读灵材名称表():
	return 商队系统._读灵材名称表()
func _读灵舟阵法表():
	return 商队系统._读灵舟阵法表()
func _读正道特许表():
	return 商队系统._读正道特许表()
func _读特殊商单表():
	return 商队系统._读特殊商单表()
func _构建商队地区():
	商队系统._构建商队地区()
func _抽取商路事件(实际风险: float):
	return 商队系统._抽取商路事件(实际风险)
func _事件可取优选项(事件: Dictionary, 人员: Array):
	return 商队系统._事件可取优选项(事件, 人员)
func _crew总分(人员: Array):
	return 商队系统._crew总分(人员)
func 派遣商队(地区ID: String, 货物列表: Array, 弟子ID: int = -1, 载具ID: String = "", 人员列表: Array = [], 灵舟索引: int = -1, 使用神行符: bool = false, 接商单: String = ""):
	return 商队系统.派遣商队(地区ID, 货物列表, 弟子ID, 载具ID, 人员列表, 灵舟索引, 使用神行符, 接商单)
func _取弟子(目标ID: int):
	return 商队系统._取弟子(目标ID)
func _校验货物库存(货主: Variant, 货物列表: Array):
	return 商队系统._校验货物库存(货主, 货物列表)
func _出库货物(货主: Variant, 货物列表: Array):
	return 商队系统._出库货物(货主, 货物列表)
func 结算商队(商队: Dictionary):
	return 商队系统.结算商队(商队)
func _结算特殊商单(商队: Dictionary):
	商队系统._结算特殊商单(商队)
func _发放贸易物品奖励(收益: int):
	商队系统._发放贸易物品奖励(收益)
func _发放物品(名: String, 数: int):
	商队系统._发放物品(名, 数)
func 刷新商队行情():
	商队系统.刷新商队行情()
func 更新商队状态():
	商队系统.更新商队状态()
func 结算到期商队():
	商队系统.结算到期商队()
func 预留_域外战斗(目标: Dictionary = {}):
	return 商队系统.预留_域外战斗(目标)
func 已建灵舟坞():
	return 商队系统.已建灵舟坞()
func 灵舟坞建造信息():
	return 商队系统.灵舟坞建造信息()
func 建造灵舟坞():
	return 商队系统.建造灵舟坞()
func _解析材料清单(mat_str: String):
	return 商队系统._解析材料清单(mat_str)
func _库房灵材数量(名: String):
	return 商队系统._库房灵材数量(名)
func _扣灵材(清单: Array):
	return 商队系统._扣灵材(清单)
func _推进灵舟建造():
	商队系统._推进灵舟建造()
func 炼制灵舟(ship_id: String):
	return 商队系统.炼制灵舟(ship_id)
func 获取拍卖会灵舟():
	return 商队系统.获取拍卖会灵舟()
func 拍卖购买灵舟(ship_id: String):
	return 商队系统.拍卖购买灵舟(ship_id)
func 拍卖出售灵舟(索引: int, 价: int):
	return 商队系统.拍卖出售灵舟(索引, 价)
func 发放灵舟奖励(ship_id: String):
	return 商队系统.发放灵舟奖励(ship_id)
func 灵舟核心物品名(品阶: int):
	return 商队系统.灵舟核心物品名(品阶)
func 灵舟有效属性(舟: Dictionary):
	return 商队系统.灵舟有效属性(舟)
func 刻录灵舟阵法(索引: int, formation_id: String):
	return 商队系统.刻录灵舟阵法(索引, formation_id)
func 补充灵舟核心(索引: int):
	return 商队系统.补充灵舟核心(索引)
func 重命名灵舟(索引: int, 新名: String):
	return 商队系统.重命名灵舟(索引, 新名)
func _结算灵舟月度():
	商队系统._结算灵舟月度()
func 黑市可交易():
	return 商队系统.黑市可交易()
func 黑市违禁品列表():
	return 商队系统.黑市违禁品列表()
func 黑市出售(货物名: String, 数量: int = 1):
	return 商队系统.黑市出售(货物名, 数量)
func 正道特许可交易():
	return 商队系统.正道特许可交易()
func 正道特许商品列表():
	return 商队系统.正道特许商品列表()
func 正道特许出售(货物名: String, 数量: int = 1):
	return 商队系统.正道特许出售(货物名, 数量)
func 黄金商路列表():
	return 商队系统.黄金商路列表()
func _刷新商路竞争():
	商队系统._刷新商路竞争()
func _检查独占(城市id: String):
	商队系统._检查独占(城市id)
func 商路竞争价格战(城市id: String):
	return 商队系统.商路竞争价格战(城市id)
func 商路竞争打压(城市id: String):
	return 商队系统.商路竞争打压(城市id)
func 商路竞争协商(城市id: String):
	return 商队系统.商路竞争协商(城市id)
func _商路声望价差加成(地区id: String):
	return 商队系统._商路声望价差加成(地区id)
func _累加商路声望(地区id: String, 收益: int):
	商队系统._累加商路声望(地区id, 收益)
func _商队总声望():
	return 商队系统._商队总声望()
func _商队收益封顶倍率():
	return 商队系统._商队收益封顶倍率()
func _阵法堂航速被动():
	return 商队系统._阵法堂航速被动()
func _声望航速被动():
	return 商队系统._声望航速被动()
func _计算贸易现实秒(总速度加成: float):
	return 商队系统._计算贸易现实秒(总速度加成)
func 仙玉即时完成贸易(商队ID: int):
	return 商队系统.仙玉即时完成贸易(商队ID)
func 商队槽位数():
	return 商队系统.商队槽位数()
func 商队每日配额():
	return 商队系统.商队每日配额()
func 刷新商队配额():
	商队系统.刷新商队配额()
func _行情事件倍率(地区: Dictionary):
	return 商队系统._行情事件倍率(地区)
func 检查商路城市解锁(条件: String, 地区id: String = ""):
	return 商队系统.检查商路城市解锁(条件, 地区id)
func _刷新行情事件():
	商队系统._刷新行情事件()
func 获取城市行情(地区id: String):
	return 商队系统.获取城市行情(地区id)
func 获取行情一览():
	return 商队系统.获取行情一览()

# ===== 阵营声望系统（v2.0 五大阵营体系：====
# 5大阵营：正道宗门、魔道邪宗、中立散修、上古妖兽、远古遗泽
# 5级声望：冷淡→中立→友善→尊敬→崇敬
# 设计依据：GDD §2.1 五大阵营声望体系
# ===== 阵营声望系统（已拆分到faction_reputation_system.gd，此处为转发函数）=====

func 获取声望等级(阵营: String):
	return 阵营声望系统.获取声望等级(阵营)
func 增加阵营声望(阵营: String, 数量: int):
	阵营声望系统.增加阵营声望(阵营, 数量)
func 获取阵营权益(阵营: String):
	return 阵营声望系统.获取阵营权益(阵营)
func 获取综合阵营权益():
	return 阵营声望系统.获取综合阵营权益()
func 检查玩法解锁(阵营: String, 玩法锁: String):
	return 阵营声望系统.检查玩法解锁(阵营, 玩法锁)
func 加权抽取阵营(性格: String = ""):
	return 阵营声望系统.加权抽取阵营(性格)
func 获取所有阵营声望列表():
	return 阵营声望系统.获取所有阵营声望列表()
func 获取阵营声望总加成():
	return 阵营声望系统.获取阵营声望总加成()
func 获取阵营描述(阵营: String):
	return 阵营声望系统.获取阵营描述(阵营)
func _加载阵营任务配置():
	阵营声望系统._加载阵营任务配置()
func _加载阵营商店配置():
	阵营声望系统._加载阵营商店配置()
func 获取阵营任务(阵营: String):
	return 阵营声望系统.获取阵营任务(阵营)
func 检查阵营任务解锁(阵营: String, 所需声望等级: String):
	return 阵营声望系统.检查阵营任务解锁(阵营, 所需声望等级)
func 更新阵营任务进度(阵营: String, 任务类型: String, 数量: int = 1):
	阵营声望系统.更新阵营任务进度(阵营, 任务类型, 数量)
func 领取阵营任务奖励(任务ID: String):
	return 阵营声望系统.领取阵营任务奖励(任务ID)
func 获取阵营商店(阵营: String):
	return 阵营声望系统.获取阵营商店(阵营)
func 购买阵营商店商品(商品ID: String):
	return 阵营声望系统.购买阵营商店商品(商品ID)

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
		消息 = "了却差事，获得奖励"
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
	# P0修复：体力系统已移除，体力奖励转为灵石奖励
	if "体力" in 奖励:
		灵石 += int(奖励["体力"]) * 10  # 1点体力=10灵石
	if "好感度" in 奖励:
		# 好感度奖励暂时记录
		pass
	# 应用惩罚
	# P0修复：体力系统已移除，体力惩罚转为灵石惩罚
	if "体力" in 惩罚:
		灵石 = max(0, 灵石 + int(惩罚["体力"]) * 10)
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
		if str(b.get("result") if "result" in b else "") == "safe":
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
# 宗主体力：山门巡逻等「宗主亲为」行动的消耗资源。
#   原缺声明（多处直接使用裸「体力」），导致 GDScript 编译期 Identifier not found，整文件解析失败。
var 体力: int = 100
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
# 灵兽喂养方针（宗主设置全局方针，弟子自动执行，宗主不亲自喂养）
# 节俭：只喂灵草，消耗最少，成长最慢
# 普通：灵草+丹药，平衡消耗与成长
# 精心：灵草+丹药+妖兽内丹，消耗最多，成长最快
var 灵兽喂养方针: String = "普通"  # 全局喂养方针
# 灵兽培养方针（§4.12 宗主理政法：宗主定方针 → 门下按月自动培养，绝不逐只点）
# 节俭：每兽月升 1 级，且宗门留存 3000 灵石不动（防掏空家底）
# 均衡：每兽月升 1 级，稳步成长
# 精进：每兽月升 2 级，且只培养战力较高的一半（强者优先，弃弱保强）
var 灵兽培养方针: String = "均衡"  # 全局培养方针
func 设置灵兽喂养方针(方针: String) -> Dictionary:
	if 方针 not in ["节俭", "普通", "精心"]:
		return {"成功": false, "原因": "未知喂养方针（节俭/普通/精心）"}
	灵兽喂养方针 = 方针
	添加纪事("御兽", "喂养方针", "宗主定下灵兽喂养方针为【%s】，门下弟子按此方针对契约灵兽进行喂养。" % 方针, 1)
	return {"成功": true, "方针": 方针, "消息": "喂养方针已设为【%s】" % 方针}
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
	添加纪事("庶务", "灵兽喂养", "喂养灵兽%s，亲密度+10，修为+20" % str(灵兽.get("名称", "")), 1)
	return {"成功": true, "亲密度": 10, "经验": 20}

# ============ 3.5 灵兽培养升级深度系统（P2优化）============
## 库房辅助函数：检查物品是否存在
func _库房有物品(物品名: String, 数量: int = 1) -> bool:
	var 计数: int = 0
	for item in 宗门库房:
		if item != null and str(item.get("名称", "")) == 物品名:
			计数 += int(item.get("数量", 1))
			if 计数 >= 数量:
				return true
	return false

## 库房辅助函数：移除物品
func _库房移除物品(物品名: String, 数量: int = 1) -> bool:
	var 待移除: int = 数量
	for i in range(宗门库房.size() - 1, -1, -1):
		if 待移除 <= 0:
			break
		var item = 宗门库房[i]
		if item != null and str(item.get("名称", "")) == 物品名:
			var 物品数量: int = int(item.get("数量", 1))
			if 物品数量 <= 待移除:
				待移除 -= 物品数量
				宗门库房.remove_at(i)
			else:
				item["数量"] = 物品数量 - 待移除
				待移除 = 0
	return 待移除 <= 0

## 喂食灵兽（消耗灵草/丹药/妖兽内丹，获得经验和亲密度）
func 灵兽喂食(灵兽索引: int, 食物类型: String = "灵草") -> Dictionary:
	if 灵兽索引 < 0 or 灵兽索引 >= 灵兽库存.size():
		return {"成功": false, "原因": "灵兽不存在"}
	var 兽: Beast = 灵兽库存[灵兽索引]
	if 兽 == null:
		return {"成功": false, "原因": "灵兽不存在"}
	# 检查资源
	var 消耗检查: Dictionary = _检查灵兽喂食消耗(食物类型)
	if not 消耗检查.get("足够", false):
		return {"成功": false, "原因": 消耗检查.get("原因", "资源不足")}
	# 扣除资源
	_扣除灵兽喂食消耗(食物类型)
	# 执行喂食
	var 结果: Dictionary = 兽.喂食(食物类型)
	if 结果.get("成功", false):
		添加纪事("御兽", "灵兽喂食", "喂食%s，%s" % [兽.种类名, 结果.get("消息", "")], 1)
		_复检成就()
	return 结果

## 检查灵兽喂食资源是否足够
func _检查灵兽喂食消耗(食物类型: String) -> Dictionary:
	match 食物类型:
		"灵草":
			if 灵草 < 5:
				return {"足够": false, "原因": "灵草不足（需5株）"}
		"丹药":
			if not _库房有物品("培元丹", 1):
				return {"足够": false, "原因": "培元丹不足（需1枚）"}
		"妖兽内丹":
			if not _库房有物品("妖兽内丹", 1):
				return {"足够": false, "原因": "妖兽内丹不足（需1枚）"}
		_:
			return {"足够": false, "原因": "未知食物类型"}
	return {"足够": true}

## 扣除灵兽喂食资源
func _扣除灵兽喂食消耗(食物类型: String) -> void:
	match 食物类型:
		"灵草":
			灵草 = max(0, 灵草 - 5)
		"丹药":
			_库房移除物品("培元丹", 1)
		"妖兽内丹":
			_库房移除物品("妖兽内丹", 1)

## 培养灵兽（消耗灵石和灵草，提升基础属性）
func 灵兽培养(灵兽索引: int) -> Dictionary:
	if 灵兽索引 < 0 or 灵兽索引 >= 灵兽库存.size():
		return {"成功": false, "原因": "灵兽不存在"}
	var 兽: Beast = 灵兽库存[灵兽索引]
	if 兽 == null:
		return {"成功": false, "原因": "灵兽不存在"}
	var 结果: Dictionary = 兽.培养()
	if not 结果.get("成功", false):
		return 结果
	# 检查并扣除资源
	var 消耗灵石: int = int(结果.get("消耗灵石", 0))
	var 消耗灵草: int = int(结果.get("消耗灵草", 0))
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d）" % 消耗灵石}
	if 灵草 < 消耗灵草:
		return {"成功": false, "原因": "灵草不足（需%d株）" % 消耗灵草}
	灵石 = max(0, 灵石 - 消耗灵石)
	灵草 = max(0, 灵草 - 消耗灵草)
	添加纪事("御兽", "灵兽培养", "培养%s，%s" % [兽.种类名, 结果.get("消息", "")], 1)
	_复检成就()
	return 结果

## 进化灵兽（达到满级且亲密度≥80可进化，品阶提升）
# 注：灵兽进化的旧实现原在此处（直接操作 兽.进化() + 扣妖兽内丹）。
# 灵兽逻辑已整体迁至 灵兽管理系统（beast_management_system.gd），game_state 侧只保留转发，
# 转发实现见文件后段「灵兽系统委托层」。此处删除旧实现，避免同名函数重复声明（GDScript 编译阻断）。

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
const 阵营列表: Array = ["正道宗门", "魔道邪宗", "中立散修", "上古妖兽", "远古遗泽"]
var 阵营活动记录: Dictionary = {}  # 活动ID -> 参与记录
func 举办阵营活动(阵营: String, 活动类型: String) -> Dictionary:
	var 实际阵营 = 阵营声望系统.旧阵营映射.get(阵营, 阵营)
	if 实际阵营 not in 阵营列表:
		return {"成功": false, "原因": "阵营不存在"}
	# 检查声望等级
	var 声望等级: String = 获取声望等级(实际阵营)
	var 声望索引: int = 声望等级.find(声望等级)
	if 声望索引 < 3:  # 需要尊敬以上
		return {"成功": false, "原因": "声望品级不足（需尊敬以上）"}
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
	# P2联动：VIP等级影响活动奖励倍率（VIP0=1.0×，VIP12=2.2×）
	var vip: int = 当前VIP等级()
	var vip活动加成: float = 1.0 + float(vip) * 0.1  # 每级+10%，VIP12=2.2×
	声望奖励 = int(float(声望奖励) * vip活动加成)
	灵石奖励 = int(float(灵石奖励) * vip活动加成)
	灵气奖励 = int(float(灵气奖励) * vip活动加成)
	增加阵营声望(实际阵营, 声望奖励)
	灵石 += 灵石奖励
	灵气 += 灵气奖励
	# 阵营任务进度更新：对应阵营的周常活动任务
	更新阵营任务进度(实际阵营, "weekly", 1)
	添加纪事("庶务", "阵营活动", "举办%s阵营%s活动，获得%d声望、%d灵石、%d灵气（仙阶%d加成%.1f倍）" % [实际阵营, 活动类型, 声望奖励, 灵石奖励, 灵气奖励, vip, vip活动加成], 1)
	return {"成功": true, "声望": 声望奖励, "灵石": 灵石奖励, "灵气": 灵气奖励, "vip加成": vip活动加成}

# 活动系统现实时间重置记录（基于现实日期，非游戏内时间）
var 活动上次重置日期: String = ""  # 格式：YYYY-MM-DD
var 活动上次重置周: String = ""    # 格式：YYYY-WW（ISO周）
# 积少成多体系：活动积分（可累积兑换）+ 连续参与天数（激励不缺席）
var 活动积分: int = 0              # 活动积分（累积，用于兑换稀有物品）
var 连续参与天数: int = 0          # 连续参与日常活动的天数

# ── 日常方针（§2.0「一键＝一键执行已定方针」+ §4.12 宗主理政法）──────────
# 宗主定方针，门下弟子照此打理日常诸事；**决策在宗主，劳作在弟子**。
# 三档差异落在「同一份日常所得的去向」——真实取舍（三选一，不可全要），
# 且全部只用已验证接口，不新增资源、不改既有产出函数：
#   养士 —— 所得尽归门下：在宗弟子各得修炼进益（厚养弟子，铺长线）
#   充库 —— 所得尽入库房：矿石、灵气各有进项（充实家底，稳）
#   扬名 —— 所得尽化声名：活动积分额外加成（积少成多，兑换稀有物）
var 日常方针: String = "充库"

func 设置日常方针(方针: String) -> Dictionary:
	if 方针 not in ["养士", "充库", "扬名"]:
		return {"成功": false, "原因": "未知日常方针（养士/充库/扬名）"}
	日常方针 = 方针
	添加纪事("宗门", "日常方针", "宗主定下宗门日常方针为【%s】，门下弟子依此打理日常诸事。" % 方针, 1)
	return {"成功": true, "方针": 方针, "消息": "日常方针已设为【%s】" % 方针}


func 获取日常方针列表() -> Array:
	return ["养士", "充库", "扬名"]


func 获取日常方针说明(方针: String) -> String:
	match 方针:
		"养士":
			return "所得尽归门下：在宗弟子各得修炼进益"
		"充库":
			return "所得尽入库房：矿石、灵气各有进项"
		"扬名":
			return "所得尽化声名：活动积分额外加成"
		_:
			return ""

# ── 突破方针（§4.14 C3 宗主干预接口③ · §4.12 宗主理政法）──────────────
# 宗主定方向、弟子担执行：方针整体平移「弟子 AI 是否冲关」的决策阈值。
# rationale：±0.10 与既有「寿元压力 −0.2 / 连败 +0.1」同量级步进，不喧宾夺主 ——
#   稳中求进 —— 阈值上调 0.10：宁可慢，不可折（少折损、保根基）
#   顺其自然 —— 不偏移：弟子按自身性格 / 资质 / 寿元自行权衡（默认）
#   搏一线天机 —— 阈值下调 0.10：抢境界、认折损（高资质弟子受益最大）
var 突破方针: String = "顺其自然"


func 设置突破方针(方针: String) -> Dictionary:
	if 方针 not in ["稳中求进", "顺其自然", "搏一线天机"]:
		return {"成功": false, "原因": "未知突破方针（稳中求进/顺其自然/搏一线天机）"}
	突破方针 = 方针
	添加纪事("宗门", "突破方针", "宗主定下宗门突破方针为【%s】，门下弟子依此权衡冲关时机。" % 方针, 1)
	return {"成功": true, "方针": 方针, "说明": 获取突破方针说明(方针), "消息": "突破方针已设为【%s】" % 方针}


func 获取突破方针列表() -> Array:
	return ["稳中求进", "顺其自然", "搏一线天机"]


func 获取突破方针说明(方针: String) -> String:
	match 方针:
		"稳中求进":
			return "阈值上调 10%：宁可慢，不可折 —— 冲关更迟，但折损更少"
		"顺其自然":
			return "不加干预：弟子按自身性格、资质与寿元自行权衡冲关时机"
		"搏一线天机":
			return "阈值下调 10%：抢境界、认折损 —— 高资质弟子受益最大"
		_:
			return ""


## C3：突破方针对弟子 AI 决策阈值的整体偏移（正值＝更谨慎）
func 获取突破方针阈值偏移() -> float:
	match 突破方针:
		"稳中求进":
			return 0.1
		"搏一线天机":
			return -0.1
		_:
			return 0.0

var 上次参与现实日: String = ""    # 上次参与日常活动的现实日期
var 历史总参与天数: int = 0        # 历史总参与天数（用于里程碑）

## 获取当前现实日期字符串（YYYY-MM-DD）
## PH6·M5：日界统一为「每日 08:00」（现实本地时区）——08:00 前仍算前一自然日，与活动倒计时/日供同源。
func 获取现实日期() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var 秒当日: int = int(dt["hour"]) * 3600 + int(dt["minute"]) * 60 + int(dt["second"])
	var 年: int = int(dt["year"])
	var 月: int = int(dt["month"])
	var 日: int = int(dt["day"])
	if 秒当日 < 每日重置小时 * 3600:
		# 08:00 前 → 归属昨日（本地字段按 UTC 往返减一日，仅取日期，时区偏移自洽）
		var t: int = int(Time.get_unix_time_from_datetime_dict(
			{"year": 年, "month": 月, "day": 日, "hour": 12, "minute": 0, "second": 0})) - 86400
		var d2: Dictionary = Time.get_datetime_dict_from_unix_time(t)
		return "%04d-%02d-%02d" % [int(d2["year"]), int(d2["month"]), int(d2["day"])]
	return "%04d-%02d-%02d" % [年, 月, 日]

## 获取当前现实周字符串（YYYY-WW，简化版：用month和day估算）
## PH6·M5：与 获取现实日期 同源（08:00 日界），避免日界/周界口径漂移。
func 获取现实周() -> String:
	var 日期: String = 获取现实日期()   # YYYY-MM-DD（已按 每日重置小时 切日）
	var 段: PackedStringArray = 日期.split("-")
	var 年: int = int(段[0])
	var 月: int = int(段[1])
	var 日: int = int(段[2])
	# 简化：用 (month-1)*4 + day/7 估算周数，足够用于周常重置判断
	var 估算周: int = (月 - 1) * 4 + int(日 / 7) + 1
	return "%04d-W%02d" % [年, 估算周]

## 检查并执行日常活动重置（现实每日 08:00 后重置；口径见 const 每日重置小时）
func 检查日常活动重置() -> void:
	var 今日: String = 获取现实日期()
	if 活动上次重置日期 != 今日:
		活动上次重置日期 = 今日
		# 日供状态由 日供_最后领取日 自动判断，无需手动重置

## 检查并执行周常活动重置（现实每周一重置）
func 检查周常活动重置() -> void:
	var 本周: String = 获取现实周()
	if 活动上次重置周 != 本周:
		活动上次重置周 = 本周
		# 周常活动重置标记（具体活动在参与时检查）

## 获取活动倒计时（距离下次重置的秒数）
## PH6·M5：重置时刻统一为「每日 08:00」（每日重置小时），与 获取现实日期/日供 同源。
func 获取活动倒计时(活动类型: String) -> Dictionary:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var 当前小时: int = int(dt["hour"])
	var 当前分钟: int = int(dt["minute"])
	var 当前秒: int = int(dt["second"])
	var 重置点秒: int = 每日重置小时 * 3600
	if 活动类型 == "日常":
		# 距离次日「每日重置小时」点的秒数
		var 已过秒: int = 当前小时 * 3600 + 当前分钟 * 60 + 当前秒
		var 剩余秒: int
		if 已过秒 >= 重置点秒:
			剩余秒 = 24 * 3600 - 已过秒 + 重置点秒
		else:
			剩余秒 = 重置点秒 - 已过秒
		return {"类型": "日常", "剩余秒": 剩余秒, "描述": "%d小时%d分后重置" % [int(剩余秒/3600), int((剩余秒%3600)/60)]}
	elif 活动类型 == "周常":
		# 距离下周一「每日重置小时」点的秒数（简化：显示7天倒计时）
		var 星期几: int = int(dt["weekday"])  # 1=周一, 7=周日
		var 已过秒: int = 当前小时 * 3600 + 当前分钟 * 60 + 当前秒
		var 剩余天: int = (8 - 星期几) % 7
		if 剩余天 == 0 and 已过秒 >= 重置点秒:
			剩余天 = 7
		var 剩余秒: int = 剩余天 * 24 * 3600 + (重置点秒 - 已过秒 if 已过秒 < 重置点秒 else 24*3600 - 已过秒 + 重置点秒)
		return {"类型": "周常", "剩余秒": 剩余秒, "描述": "%d天%d小时后重置" % [int(剩余秒/86400), int((剩余秒%86400)/3600)]}
	return {"类型": 活动类型, "剩余秒": 0, "描述": ""}

## 获取连续参与加成倍率（积少成多核心：连续越久倍率越高）
func 获取连续参与加成() -> float:
	if 连续参与天数 >= 365:
		return 3.0  # 连续一年，3倍奖励
	elif 连续参与天数 >= 100:
		return 2.5  # 连续百日，2.5倍
	elif 连续参与天数 >= 30:
		return 2.0  # 连续一月，2倍
	elif 连续参与天数 >= 7:
		return 1.5  # 连续一周，1.5倍
	elif 连续参与天数 >= 3:
		return 1.2  # 连续三天，1.2倍
	else:
		return 1.0  # 基础倍率

## 记录日常活动参与（更新连续天数和积分）
func 记录日常活动参与() -> void:
	var 今日: String = 获取现实日期()
	if 上次参与现实日 == "":
		连续参与天数 = 1
	elif 上次参与现实日 != 今日:
		# 检查是否连续（昨天参与过）
		var 昨日: String = _获取昨日日期()
		if 上次参与现实日 == 昨日:
			连续参与天数 += 1
		else:
			连续参与天数 = 1  # 断签，重新计算
	上次参与现实日 = 今日
	历史总参与天数 += 1
	# 每次参与获得基础积分10点，连续加成
	var 基础积分: int = 10
	var 加成: float = 获取连续参与加成()
	var 获得积分: int = int(基础积分 * 加成)
	活动积分 += 获得积分
	# 检查里程碑奖励
	_检查参与里程碑()

## 获取昨日日期字符串
func _获取昨日日期() -> String:
	var dt = Time.get_datetime_dict_from_system()
	var 年: int = int(dt["year"])
	var 月: int = int(dt["month"])
	var 日: int = int(dt["day"])
	日 -= 1
	if 日 <= 0:
		月 -= 1
		if 月 <= 0:
			月 = 12
			年 -= 1
		# 简化：上个月按30天算
		日 = 30
	return "%04d-%02d-%02d" % [年, 月, 日]

## 检查参与里程碑奖励（积少成多的核心激励）
func _检查参与里程碑() -> void:
	match 连续参与天数:
		7:
			_加推演条目("【宗门】连续七日不辍，道心日坚，赐下聚气散三枚，活动积分+50。", ET_SECT, PRIO_NORMAL, {})
			for i in range(3):
				宗门库房.append(_造低阶物品("dan", "凡品"))
			活动积分 += 50
		30:
			_加推演条目("【宗门】连续一月苦修不辍，宗门感其诚，赐下筑基丹五枚、功法残卷一卷，活动积分+200。", ET_SECT, PRIO_HIGH, {})
			for i in range(5):
				宗门库房.append(_造低阶物品("dan", "灵品"))
			宗门库房.append(_造低阶物品("gongfa", "凡阶"))
			活动积分 += 200
		100:
			_加推演条目("【宗门】连续百日苦修，道基稳固，宗门赐下宝品丹药三枚、灵品功法残卷两卷，活动积分+500。", ET_SECT, PRIO_HIGH, {})
			for i in range(3):
				宗门库房.append(_造低阶物品("dan", "宝品"))
			for i in range(2):
				宗门库房.append(_造低阶物品("gongfa", "灵阶"))
			活动积分 += 500
		365:
			_加推演条目("【宗门】连续一年不辍，道心坚定如铁，宗门赐下王品丹药一枚、宝品功法残卷三卷、上古法宝一件，活动积分+2000！", ET_SECT, PRIO_HIGH, {})
			宗门库房.append(_造低阶物品("dan", "王品"))
			for i in range(3):
				宗门库房.append(_造低阶物品("gongfa", "宝阶"))
			宗门库房.append(_造低阶物品("fabao", "王品"))
			活动积分 += 2000

## 活动积分兑换（积少成多的出口：累积积分兑换稀有物品）
func 活动积分兑换(物品类型: String, 品阶: String) -> Dictionary:
	var 兑换表: Dictionary = {
		"dan_凡品": 50,
		"dan_灵品": 150,
		"dan_宝品": 400,
		"dan_王品": 1000,
		"gongfa_凡阶": 100,
		"gongfa_灵阶": 300,
		"gongfa_宝阶": 800,
		"fabao_凡品": 80,
		"fabao_灵品": 250,
		"fabao_宝品": 600,
		"灵草": 20,
		"矿石": 20,
		"悟道点": 30,
		"灵玉": 100,  # 100积分兑换1灵玉（积少成多的出口）
	}
	var 键: String = "%s_%s" % [物品类型, 品阶]
	if 物品类型 == "灵草" or 物品类型 == "矿石" or 物品类型 == "悟道点":
		键 = 物品类型
	var 所需积分: int = int(兑换表.get(键, 0))
	if 所需积分 <= 0:
		return {"成功": false, "原因": "无此兑换项"}
	if 活动积分 < 所需积分:
		return {"成功": false, "原因": "活动积分不足（需%d，当前%d）" % [所需积分, 活动积分]}
	活动积分 -= 所需积分
	# 发放物品
	if 物品类型 == "灵草":
		灵草 += 10
		return {"成功": true, "消息": "兑换成功，灵草+10"}
	elif 物品类型 == "矿石":
		矿石 += 10
		return {"成功": true, "消息": "兑换成功，矿石+10"}
	elif 物品类型 == "悟道点":
		悟道点 += 20
		return {"成功": true, "消息": "兑换成功，悟道点+20"}
	elif 物品类型 == "灵玉":
		仙玉_绑定 += 1
		return {"成功": true, "消息": "兑换成功，灵玉+1"}
	else:
		var 物: Item = _造低阶物品(物品类型, 品阶)
		宗门库房.append(物)
		return {"成功": true, "消息": "兑换成功，获得%s" % 物.名称}

## 获取活动积分兑换列表
func 获取积分兑换列表() -> Array:
	return [
		{"类型": "灵玉", "品阶": "", "名称": "灵玉×1", "积分": 100},
		{"类型": "dan", "品阶": "凡品", "名称": "聚气散", "积分": 50},
		{"类型": "dan", "品阶": "灵品", "名称": "筑基丹", "积分": 150},
		{"类型": "dan", "品阶": "宝品", "名称": "金丹大成丹", "积分": 400},
		{"类型": "gongfa", "品阶": "凡阶", "名称": "功法残卷", "积分": 100},
		{"类型": "gongfa", "品阶": "灵阶", "名称": "灵品功法残卷", "积分": 300},
		{"类型": "fabao", "品阶": "凡品", "名称": "凡品法宝", "积分": 80},
		{"类型": "fabao", "品阶": "灵品", "名称": "灵品法宝", "积分": 250},
		{"类型": "灵草", "品阶": "", "名称": "灵草×10", "积分": 20},
		{"类型": "矿石", "品阶": "", "名称": "矿石×10", "积分": 20},
		{"类型": "悟道点", "品阶": "", "名称": "悟道点×20", "积分": 30},
	]

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
		{"活动ID": "faction_reputation", "名称": "声望任务", "类型": "日常", "描述": "完成声望差事，提升阵营声望", "冷却天数": 1, "修真界名称": "声望"},
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

# ===== P2联动：活动期间产出加成 =====
# 活动期间各系统产出加成（根据活动类型）
func 获取活动产出加成() -> Dictionary:
	var 加成: Dictionary = {
		"修炼加成": 0.0,
		"炼丹加成": 0.0,
		"炼器加成": 0.0,
		"产出加成": 0.0,
		"声望加成": 0.0,
	}
	# 检查当前是否有活动进行中（简化：根据累计游戏日判断）
	var 活动日: int = int(累计游戏日) % 30  # 每30天一个活动周期
	# 活动周期：1-5日修炼加成，6-10日炼丹加成，11-15日炼器加成，16-20日产出加成，21-25日声望加成
	if 活动日 >= 1 and 活动日 <= 5:
		加成["修炼加成"] = 0.10  # 修炼+10%
	elif 活动日 >= 6 and 活动日 <= 10:
		加成["炼丹加成"] = 0.15  # 炼丹+15%
	elif 活动日 >= 11 and 活动日 <= 15:
		加成["炼器加成"] = 0.15  # 炼器+15%
	elif 活动日 >= 16 and 活动日 <= 20:
		加成["产出加成"] = 0.10  # 产出+10%
	elif 活动日 >= 21 and 活动日 <= 25:
		加成["声望加成"] = 0.20  # 声望+20%
	return 加成

# 获取当前活动名称（修真化描述）
func 获取当前活动名称() -> String:
	var 活动日: int = int(累计游戏日) % 30
	if 活动日 >= 1 and 活动日 <= 5:
		return "讲道大会（全宗修炼+10%）"
	elif 活动日 >= 6 and 活动日 <= 10:
		return "丹道盛会（炼丹+15%）"
	elif 活动日 >= 11 and 活动日 <= 15:
		return "器道争锋（炼器+15%）"
	elif 活动日 >= 16 and 活动日 <= 20:
		return "丰收大典（产出+10%）"
	elif 活动日 >= 21 and 活动日 <= 25:
		return "扬名四海（声望+20%）"
	else:
		return "平日（无加成）"

# 按类型筛选活动
func 按类型筛选活动(活动类型: String) -> Array:
	var 筛选列表 = []
	var 活动列表 = 获取所有活动列表()
	for 活动 in 活动列表:
		if 活动.get("类型", "") == 活动类型:
			筛选列表.append(活动)
	return 筛选列表

# 获取活动冷却状态（基于现实时间判断）
func 获取活动冷却状态(活动ID: String) -> Dictionary:
	var 活动列表 = 获取所有活动列表()
	for 活动 in 活动列表:
		if 活动.get("活动ID", "") == 活动ID:
			var 类型: String = str(活动.get("类型", ""))
			var 可参与: bool = true
			var 倒计时: Dictionary = 获取活动倒计时(类型)
			# 日常活动：检查今日是否已参与（日供检查已领状态）
			if 类型 == "日常" and 活动ID == "daily_checkin":
				可参与 = 日供_今日可领()
			# 周常活动：检查本周是否已参与（简化：都可参与，具体活动自己判断）
			return {
				"活动ID": 活动ID,
				"名称": 活动.get("名称", ""),
				"类型": 类型,
				"可参与": 可参与,
				"倒计时": 倒计时.get("描述", ""),
				"剩余秒": 倒计时.get("剩余秒", 0),
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

# 参与单个时令（宗门时令页面对接）
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
			# 丹道大会：宗门炼丹技艺比拼，根据丹殿等级给奖励
			var 丹殿等级: int = 1
			if 司职列表.has("dantang"):
				丹殿等级 = int(司职列表["dantang"].get("等级", 1))
			var 丹会奖励: Dictionary = _丹道大会奖励(丹殿等级)
			return {"成功": true, "活动": "丹道大会", "消息": 丹会奖励.get("消息", ""), "奖励": 丹会奖励}
		"artifact_forge":
			# 器道争锋：宗门炼器技艺比拼，根据器殿等级给奖励
			var 器殿等级: int = 1
			if 司职列表.has("qitang"):
				器殿等级 = int(司职列表["qitang"].get("等级", 1))
			var 器会奖励: Dictionary = _器道争锋奖励(器殿等级)
			return {"成功": true, "活动": "器道争锋", "消息": 器会奖励.get("消息", ""), "奖励": 器会奖励}
		"zongmen_battle":
			# 宗门大战（简化：显示提示）
			return {"成功": true, "活动": "宗门大战", "消息": "请前往宗门战页面参与"}
		"disciple_cultivate":
			# 传道授业：长老/宗主公开讲道，弟子获得悟道点和道心
			var 传道奖励: Dictionary = _传道授业奖励()
			return {"成功": true, "活动": "传道授业", "消息": 传道奖励.get("消息", ""), "奖励": 传道奖励}
		"faction_reputation":
			# 声望任务（简化：显示提示）
			return {"成功": true, "活动": "声望任务", "消息": "请前往阵营声望页面参与"}
		_:
			return {"成功": false, "原因": "未知活动：%s" % 活动ID}

## 丹道大会奖励（根据丹殿等级缩放）
func _丹道大会奖励(丹殿等级: int) -> Dictionary:
	var 悟道奖励: int = 20 + 丹殿等级 * 10
	var 丹药数: int = 1 + int(丹殿等级 / 2)
	var 丹药品阶: String = "凡品"
	if 丹殿等级 >= 3:
		丹药品阶 = "灵品"
	if 丹殿等级 >= 5:
		丹药品阶 = "宝品"
	悟道点 += 悟道奖励
	for i in range(丹药数):
		宗门库房.append(_造低阶物品("dan", 丹药品阶))
	_加推演条目("【宗门】丹道大会落幕，宗门弟子切磋丹道，悟道+%d，赐%s丹药%d枚。" % [悟道奖励, 丹药品阶, 丹药数], ET_SECT, PRIO_NORMAL, {})
	return {"消息": "丹道大会圆满，悟道+%d，获%s丹药%d枚" % [悟道奖励, 丹药品阶, 丹药数], "悟道": 悟道奖励, "丹药": 丹药数}

## 器道争锋奖励（根据器殿等级缩放）
func _器道争锋奖励(器殿等级: int) -> Dictionary:
	var 悟道奖励: int = 20 + 器殿等级 * 10
	var 矿石奖励: int = 10 + 器殿等级 * 5
	var 法宝品阶: String = "凡品"
	if 器殿等级 >= 3:
		法宝品阶 = "灵品"
	if 器殿等级 >= 5:
		法宝品阶 = "宝品"
	悟道点 += 悟道奖励
	矿石 += 矿石奖励
	宗门库房.append(_造低阶物品("fabao", 法宝品阶))
	_加推演条目("【宗门】器道争锋落幕，宗门弟子切磋器道，悟道+%d，矿石+%d，赐%s法宝一件。" % [悟道奖励, 矿石奖励, 法宝品阶], ET_SECT, PRIO_NORMAL, {})
	return {"消息": "器道争锋圆满，悟道+%d，矿石+%d，获%s法宝一件" % [悟道奖励, 矿石奖励, 法宝品阶], "悟道": 悟道奖励, "矿石": 矿石奖励}

## 传道授业奖励（宗主/长老讲道，弟子集体受益）
func _传道授业奖励() -> Dictionary:
	var 受益弟子数: int = 0
	var 总悟道: int = 0
	for d in 弟子列表:
		if d != null and str(d.状态) == "在宗" and int(d.受伤剩余) <= 0:
			# 弟子听道所得落在「修炼进度」（Disciple 无「悟道点」字段——
			# 给对象写不存在的属性会 SCRIPT ERROR，此处修正为真实字段直取）
			d.修炼进度 = min(1.0, float(d.修炼进度) + 0.05)
			总悟道 += randi_range(3, 10)
			受益弟子数 += 1
	# 宗主也受益
	悟道点 += 10
	_加推演条目("【宗门】宗主登坛讲道，%d名在宗弟子聆听教诲，各有所悟，宗主悟道+10。" % 受益弟子数, ET_SECT, PRIO_NORMAL, {})
	return {"消息": "传道授业圆满，%d名弟子受益，各有所悟，宗主悟道+10" % 受益弟子数, "受益弟子": 受益弟子数, "总悟道": 总悟道}

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

# 打理宗门日常诸事（§2.0：这里是「一键执行**已定方针**」，不是替宗主做决策。
# 宗主先定日常方针（养士/充库/扬名），门下弟子照此打理，所得按方针分流——
# 消掉的是弟子的劳作，不是宗主的决策。修真味：晨起打理宗门诸事）
func 一键参与日常活动() -> Dictionary:
	# 先检查重置
	检查日常活动重置()
	var 参与数量: int = 0
	var 结果列表: Array = []
	var 汇总文案: String = ""
	# 每日朝贡
	if 日供_今日可领():
		var 结果 = 领取日供()
		结果列表.append({"活动": "日供", "结果": 结果})
		if 结果.get("ok", false):
			参与数量 += 1
			汇总文案 += "已领日供，"
	else:
		汇总文案 += "日供已领，"
	# 云游探索
	var 探索结果 = 一键探索()
	结果列表.append({"活动": "云游", "结果": 探索结果})
	if 探索结果.get("成功", false):
		参与数量 += 1
		汇总文案 += "云游已毕。"
	else:
		汇总文案 += "云游无获。"
	# 按方针分流：同一份日常，去向由宗主决定（真实取舍）
	var 去向文案: String = ""
	if 参与数量 > 0:
		去向文案 = _日常方针分流()
		汇总文案 += 去向文案
	_加推演条目("【宗门】晨起打理宗门诸事：%s" % 汇总文案, ET_SECT, PRIO_TRIVIAL, {})
	# 记录参与，更新连续天数和活动积分（积少成多）
	if 参与数量 > 0:
		记录日常活动参与()
	return {"成功": 参与数量 > 0, "参与数量": 参与数量, "结果列表": 结果列表, "方针": 日常方针, "消息": "晨起打理宗门诸事：%s" % 汇总文案}


## 日常所得按方针分流（三档真实取舍：养士 / 充库 / 扬名）。
## 只用已验证接口：弟子属性 `修炼进度`（float 0–1）、宗门数值 `矿石/灵气/活动积分`。
func _日常方针分流() -> String:
	match 日常方针:
		"养士":
			var 受益: int = 0
			for d in 弟子列表:
				if d == null or str(d.状态) != "在宗" or int(d.受伤剩余) > 0:
					continue
				d.修炼进度 = min(1.0, float(d.修炼进度) + 0.03)
				受益 += 1
			return "所得尽归门下，%d 名弟子各得修炼进益（修炼进度+3%%）。" % 受益
		"扬名":
			var 额外: int = int(20.0 * 获取连续参与加成())
			活动积分 += 额外
			return "所得尽化声名，活动积分+%d。" % 额外
		_:
			矿石 += 5
			灵气 += 5
			return "所得尽入库房，矿石+5、灵气+5。"

# ============ 6. 阵营试炼系统 ============
# 阵营试炼：高阶挑战，获得稀有奖励
var 阵营试炼记录: Dictionary = {}  # 试炼ID -> 通关记录
func 挑战阵营试炼(阵营: String, 试炼难度: String = "普通") -> Dictionary:
	var 实际阵营 = 阵营声望系统.旧阵营映射.get(阵营, 阵营)
	if 实际阵营 not in 阵营列表:
		return {"成功": false, "原因": "阵营不存在"}
	# 检查声望等级
	var 声望等级: String = 获取声望等级(实际阵营)
	var 声望索引: int = 声望等级.find(声望等级)
	if 声望索引 < 4:  # 需要崇敬以上
		return {"成功": false, "原因": "声望品级不足（需崇敬以上）"}
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
		return {"成功": false, "原因": "远古遗泽声望品级不足（需尊敬以上）"}
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
	for 兽 in 灵兽管理系统.灵兽库存:
		if 兽 != null and "ID" in 兽 and 兽["ID"] == 灵兽ID:
			return 兽
	return null

# ===== 特权卡系统=====
# 月卡（清修卡）：30天，每日灵玉+离线+20%+历练+1+一键收取
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
	设置离线倍率(max(离线结算倍率, 1.2))   # 月卡权益：离线+20%
# 激活季卡
func 激活季卡(天数: int = 90) -> void:

	if 季卡到期日 < 累计游戏日:
		季卡到期日= 累计游戏日+ 天数
	else:
		季卡到期日+= 天数
	添加纪事("大事件", "激活悟道卡", "激活季卡，有效%d天" % 天数, 2)
	设置离线倍率(max(离线结算倍率, 1.2))   # 季卡含月卡权益
# 激活永久卡
func 激活永久卡() -> void:

	永久卡激活= true
	添加纪事("大事件", "激活道统卡", "激活永久卡，终身享受所有权益", 3)
	设置离线倍率(max(离线结算倍率, 2.0))   # 永久卡：终身日供翻倍
# 获取所有卡类型列表
func 获取所有卡类型列表() -> Array:
	return [
		{
			"卡类型": "月卡",
			"名称": "清修卡",
			"价格": 30,
			"天数": 30,
			"描述": "每日灵玉+离线+20%+历练+1+一键收取",
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
	添加纪事("庶务", "每日卡奖励", "领取每日卡奖励：灵玉+%d，灵石+%d，灵气+%d" % [奖励.get("仙玉_绑定", 0), 奖励.get("灵石", 0), 奖励.get("灵气", 0)], 1)
	return {"成功": true, "奖励": 奖励, "消息": "领取每日卡奖励成功"}

var card_daily_reward_day: int = -1  # 每日卡奖励最后领取日

# 获取特权加成（统一使用新VIP系统）
func 获取特权加成() -> Dictionary:
	# 离线上限使用新的_计算离线上限()函数
	var 离线上限: int = _计算离线上限()
	# 炼制加成：季卡30% + VIP5 15%
	var 炼制加成: float = 1.0
	if 季卡有效():
		炼制加成 += 0.3
	if is_vip_unlock("炼制加成15"):
		炼制加成 += 0.15
	# 商队加成：季卡15% + VIP6 10%
	var 商队加成: float = 1.0
	if 季卡有效():
		商队加成 += 0.15
	if is_vip_unlock("商队加成10"):
		商队加成 += 0.10
	return {
		"离线收益加成": 1.2 if 月卡有效() else 1.0,
		"炼制加成": 炼制加成,
		"商队收益加成": 商队加成,
		"日供翻倍": 永久卡有效(),
		"离线上限小时": 离线上限,
		"额外历练次数": 1 if 月卡有效() else 0,
		"一键收取": is_vip_unlock("一键收取"),
		"机缘加成": _计算机缘加成(),
	}
# ===== VIP系统（统一使用累充额派生的当前VIP等级()，VIP0-12）=====
# 设计依据：GDD §12 VIP与加速系统
# 四档权益梯度：VIP1-3基础便利 / VIP4-6资源加成 / VIP7-9深度便利 / VIP10-12高阶专属
# 所有权益均为便利类，不破坏游戏平衡（不升5%/10%数值红线）

# VIP权限接口（统一使用当前VIP等级()，基于累充额派生）
func is_vip_unlock(feature: String) -> bool:
	var vip: int = 当前VIP等级()
	match feature:
		# ===== VIP1-3：基础便利 =====
		"背包扩容":
			return vip >= 1
		"一键收取":
			return vip >= 1 or 月卡有效()
		"战斗2倍率":
			return vip >= 1 or 月卡有效()
		"招募额外次数":
			return vip >= 2
		"每日免费礼包":
			return vip >= 3
		# ===== VIP4-6：资源加成 =====
		"跳过战斗":
			return vip >= 3
		"专属头像框":
			return vip >= 4 or 季卡有效()
		"离线12小时":
			return vip >= 4
		"炼制加成15":
			return vip >= 5 or 季卡有效()
		"商队加成10":
			return vip >= 6
		# ===== VIP7-9：深度便利 =====
		"战斗3倍率":
			return vip >= 7
		"专属皮肤":
			return vip >= 7 or 永久卡有效()
		"离线24小时":
			return vip >= 7 or 永久卡有效()
		"自动熔炼":
			return vip >= 8
		"机缘加成20":
			return vip >= 9
		# ===== VIP10-12：高阶专属 =====
		"离线48小时":
			return vip >= 10
		"专属宗门外观":
			return vip >= 10
		"机缘加成50":
			return vip >= 11
		"专属客服通道":
			return vip >= 12
		"全功能解锁":
			return vip >= 12
		_:
			return false

# 战斗倍速参数（修真化：时光加速）
func get_battle_speed_multiplier() -> float:
	if is_vip_unlock("战斗3倍率"):
		return 3.0
	elif is_vip_unlock("战斗2倍率"):
		return 2.0
	return 1.0

# 获取VIP权益汇总（供UI展示）
func get_vip_benefits() -> Dictionary:
	var vip: int = 当前VIP等级()
	return {
		"当前等级": vip,
		"下一等级": min(vip + 1, 12),
		"已解锁权益": _获取已解锁权益列表(vip),
		"下一等级权益": _获取等级权益列表(min(vip + 1, 12)),
		"离线上限小时": _计算离线上限(),
		"机缘加成": _计算机缘加成(),
	}

# 获取已解锁权益列表
func _获取已解锁权益列表(vip: int) -> Array:
	var 列表: Array = []
	var 所有权益: Dictionary = {
		1: ["背包扩容", "一键收取", "战斗2倍速"],
		2: ["招募额外次数"],
		3: ["每日免费礼包", "跳过战斗"],
		4: ["专属头像框", "离线12小时"],
		5: ["炼制加成15%"],
		6: ["商队加成10%"],
		7: ["战斗3倍速", "专属皮肤", "离线24小时"],
		8: ["自动熔炼"],
		9: ["机缘加成20%"],
		10: ["离线48小时", "专属宗门外观"],
		11: ["机缘加成50%"],
		12: ["专属客服通道", "全功能解锁"],
	}
	for lv in range(1, vip + 1):
		if 所有权益.has(lv):
			列表.append_array(所有权益[lv])
	return 列表

# 获取指定等级权益列表
func _获取等级权益列表(等级: int) -> Array:
	var 所有权益: Dictionary = {
		1: ["背包扩容", "一键收取", "战斗2倍速"],
		2: ["招募额外次数"],
		3: ["每日免费礼包", "跳过战斗"],
		4: ["专属头像框", "离线12小时"],
		5: ["炼制加成15%"],
		6: ["商队加成10%"],
		7: ["战斗3倍速", "专属皮肤", "离线24小时"],
		8: ["自动熔炼"],
		9: ["机缘加成20%"],
		10: ["离线48小时", "专属宗门外观"],
		11: ["机缘加成50%"],
		12: ["专属客服通道", "全功能解锁"],
	}
	return 所有权益.get(等级, [])

# 计算离线上限（小时）
func _计算离线上限() -> int:
	var 上限: int = 8
	if 月卡有效():
		上限 += 4
	if 季卡有效():
		上限 += 4
	if 永久卡有效():
		上限 += 8
	var vip: int = 当前VIP等级()
	if vip >= 4:
		上限 += 4  # VIP4+离线12小时
	if vip >= 7:
		上限 += 12  # VIP7+离线24小时（累计）
	if vip >= 10:
		上限 += 24  # VIP10+离线48小时（累计）
	return min(上限, 48)

# 计算机缘加成（百分比）
func _计算机缘加成() -> float:
	var vip: int = 当前VIP等级()
	if vip >= 11:
		return 0.5  # VIP11+机缘+50%
	elif vip >= 9:
		return 0.2  # VIP9+机缘+20%
	return 0.0

# 获取所有VIP等级列表（统一使用累充额派生）
func 获取所有VIP等级列表() -> Array:
	var 等级列表: Array = []
	var 累充档位: Array = [0, 6, 30, 68, 128, 298, 648, 1000, 2000, 3000, 5000, 8888, 12888]
	for i in range(13):
		var 所需金额: int = 累充档位[i] if i < 累充档位.size() else -1
		var 权益: Array = _获取等级权益列表(i)
		等级列表.append({
			"等级": i,
			"所需金额": 所需金额,
			"权益": 权益,
			"已达成": 当前VIP等级() >= i,
		})
	return 等级列表

# 获取VIP统计
func 获取VIP统计() -> Dictionary:
	var vip: int = 当前VIP等级()
	var 累充档位: Array = [0, 6, 30, 68, 128, 298, 648, 1000, 2000, 3000, 5000, 8888, 12888]
	var 下一级金额: int = 累充档位[min(vip + 1, 12)] if vip < 12 else -1
	var 升级进度: float = 0.0
	if 下一级金额 > 0 and vip < 12:
		var 当前级金额: int = 累充档位[vip] if vip < 累充档位.size() else 0
		升级进度 = float(累充额 - 当前级金额) / float(下一级金额 - 当前级金额)
	return {
		"当前等级": vip,
		"累充额": 累充额,
		"下一级金额": 下一级金额,
		"升级进度": clamp(升级进度, 0.0, 1.0),
		"最高等级": 12,
		"战斗倍率": get_battle_speed_multiplier(),
		"离线上限小时": _计算离线上限(),
		"机缘加成": _计算机缘加成(),
	}

# 获取VIP每日奖励（修真化：仙玉供奉礼遇）
func 获取VIP每日奖励() -> Dictionary:
	var vip: int = 当前VIP等级()
	var 奖励: Dictionary = {"灵石": 0, "灵气": 0, "悟道点": 0, "机缘符": 0}
	# VIP1-3：基础礼遇
	if vip >= 1:
		奖励["灵石"] += 100
	if vip >= 2:
		奖励["灵气"] += 50
	if vip >= 3:
		奖励["悟道点"] += 10
	# VIP4-6：资源加成
	if vip >= 4:
		奖励["灵石"] += 100
	if vip >= 5:
		奖励["灵气"] += 50
	if vip >= 6:
		奖励["机缘符"] += 1
	# VIP7-9：深度便利
	if vip >= 7:
		奖励["灵石"] += 200
	if vip >= 8:
		奖励["灵气"] += 100
	if vip >= 9:
		奖励["悟道点"] += 20
	# VIP10-12：高阶专属
	if vip >= 10:
		奖励["灵石"] += 300
	if vip >= 11:
		奖励["灵气"] += 150
	if vip >= 12:
		奖励["机缘符"] += 2
	return 奖励

# 领取VIP每日奖励（修真化：仙玉供奉礼遇）
func 领取VIP每日奖励() -> Dictionary:
	var 最后领取日 = vip_daily_reward_day if "vip_daily_reward_day" in self else -1
	if 最后领取日 == 累计游戏日:
		return {"成功": false, "原因": "今日供奉礼遇已领取"}
	var 奖励: Dictionary = 获取VIP每日奖励()
	var vip: int = 当前VIP等级()
	灵石 += 奖励.get("灵石", 0)
	灵气 += 奖励.get("灵气", 0)
	悟道点 += 奖励.get("悟道点", 0)
	# 机缘符奖励：增加所有类型机缘各1次
	if 奖励.get("机缘符", 0) > 0:
		for 类型 in 每日机缘.keys():
			每日机缘[类型] = min(每日机缘[类型] + 奖励["机缘符"], 获取机缘上限(类型))
	vip_daily_reward_day = 累计游戏日
	# 修真化纪事文案
	添加纪事("供奉", "仙玉礼遇", "领取仙阶%d仙玉供奉礼遇：灵石+%d，灵气+%d，悟道点+%d，机缘符+%d" % [vip, 奖励.get("灵石", 0), 奖励.get("灵气", 0), 奖励.get("悟道点", 0), 奖励.get("机缘符", 0)], 1)
	return {"成功": true, "奖励": 奖励, "消息": "领取仙玉供奉礼遇成功"}

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
		"描述": "至尊尊享，含灵石×20000、灵玉×1000",
		"内容": {"灵石": 20000, "仙玉_绑定": 1000},
		"限购": 1,
	},
	{
		"id": "每日礼包",
		"名称": "每日礼包",
		"价格": 1,
		"描述": "今日缘法，含灵石×500、灵草：0",
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
			"活动名称": "限时缘法",
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
# _道友列表已移至 friend_system.gd
# _道友消息已移至 friend_system.gd
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
# 全宗气运 buff（天品灵根弟子招募触发）：修：3% / 产出+2%，持：7 累计游戏日
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
		结果["消息"] = "今日互动次数已用完"
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
var _上次月度结算日: int = 0  # S1：上次月度结算的游戏日，用于月度内容门控
var 最后登录:= 0
var 门派等级 := 1
## S1：宗门编制上限（等级基础上限 + 洞府扩建额外上限）
func 宗门编制上限() -> int:
	# 等级基础上限（修真世界观：宗门等级决定规模）
	var 等级基础上限: Dictionary = {1:10, 2:15, 3:25, 4:40, 5:60, 6:80, 7:100, 8:130, 9:160, 10:200}
	var 基础: int = int(等级基础上限.get(门派等级, 10))
	# 洞府扩建额外增加（初始10个洞府为基础，超出部分每个+1人上限）
	var 扩建额外: int = max(0, 洞府数量 - 10)
	return 基础 + 扩建额外

## P1优化：计算占用编制的弟子数量（外门弟子不占编制，只做杂役）
func 占用编制弟子数() -> int:
	var 数: int = 0
	for d in 弟子列表:
		if d != null and d is Disciple and d.身份 != "外门":
			数 += 1
	return 数

## P1优化：外门弟子数量
func 外门弟子数() -> int:
	var 数: int = 0
	for d in 弟子列表:
		if d != null and d is Disciple and d.身份 == "外门":
			数 += 1
	return 数

## P1优化：外门弟子杂役产出（每月产出少量资源）
func 外门弟子杂役产出() -> Dictionary:
	var 外门数: int = 外门弟子数()
	if 外门数 <= 0:
		return {"灵石": 0, "灵草": 0, "矿石": 0}
	# 每个外门弟子每月产出少量资源（杂役）
	var 灵石产出: int = 外门数 * 5
	var 灵草产出: int = 外门数 * 3
	var 矿石产出: int = 外门数 * 2
	灵石 += 灵石产出
	灵草 += 灵草产出
	矿石 += 矿石产出
	return {"灵石": 灵石产出, "灵草": 灵草产出, "矿石": 矿石产出}

## P2：获取宗门等级称呼
func 获取宗门等级称呼() -> String:
	if 门派等级 <= 3:
		return "小型宗门"
	elif 门派等级 <= 6:
		return "中型宗门"
	elif 门派等级 <= 9:
		return "大型宗门"
	else:
		return "超级宗门"

## P2：获取宗门等级详细称呼（带前缀）
func 获取宗门详细称呼() -> String:
	var 基础: String = 获取宗门等级称呼()
	if 门派等级 == 10:
		return "太玄仙门"
	elif 门派等级 >= 7:
		return "太玄宗（%s）" % 基础
	else:
		return "太玄宗（%s）" % 基础

# ===== P2优化：宗门评级系统（九品到一品）=====
# 宗门评级配置：等级+综合实力决定评级
const 宗门评级配置: Array = [
	{"评级": "九品", "称呼": "末流宗门", "最低等级": 1, "最低战力": 0},
	{"评级": "八品", "称呼": "三流宗门", "最低等级": 3, "最低战力": 10000},
	{"评级": "七品", "称呼": "二流宗门", "最低等级": 5, "最低战力": 50000},
	{"评级": "六品", "称呼": "一流宗门", "最低等级": 7, "最低战力": 150000},
	{"评级": "五品", "称呼": "顶尖宗门", "最低等级": 9, "最低战力": 400000},
	{"评级": "四品", "称呼": "超级宗门", "最低等级": 10, "最低战力": 800000},
	{"评级": "三品", "称呼": "圣地", "最低等级": 10, "最低战力": 1500000, "特殊条件": "拥有化神弟子"},
	{"评级": "二品", "称呼": "仙门", "最低等级": 10, "最低战力": 3000000, "特殊条件": "拥有炼虚弟子"},
	{"评级": "一品", "称呼": "道统", "最低等级": 10, "最低战力": 6000000, "特殊条件": "拥有合体弟子"},
]

## P2优化：计算宗门总战力
func 计算宗门总战力() -> int:
	var 总战力: int = 0
	for d in 弟子列表:
		if d != null and d is Disciple:
			总战力 += int(d.战力)
	return 总战力

## P2优化：获取宗门评级
func 获取宗门评级() -> Dictionary:
	var 总战力: int = 计算宗门总战力()
	var 当前评级: Dictionary = 宗门评级配置[0]
	for 评级 in 宗门评级配置:
		# 检查等级条件
		if 门派等级 < int(评级.get("最低等级", 1)):
			continue
		# 检查战力条件
		if 总战力 < int(评级.get("最低战力", 0)):
			continue
		# 检查特殊条件
		var 特殊条件: String = str(评级.get("特殊条件", ""))
		if 特殊条件 != "":
			var 满足特殊: bool = false
			if "化神" in 特殊条件:
				for d in 弟子列表:
					if d != null and d is Disciple and d.境界 == "化神":
						满足特殊 = true
						break
			elif "炼虚" in 特殊条件:
				for d in 弟子列表:
					if d != null and d is Disciple and d.境界 == "炼虚":
						满足特殊 = true
						break
			elif "合体" in 特殊条件:
				for d in 弟子列表:
					if d != null and d is Disciple and d.境界 == "合体":
						满足特殊 = true
						break
			if not 满足特殊:
				continue
		当前评级 = 评级
	return 当前评级

## P2优化：获取宗门评级名称
func 获取宗门评级名称() -> String:
	var 评级: Dictionary = 获取宗门评级()
	return str(评级.get("评级", "九品"))

## P2优化：获取宗门评级称呼
func 获取宗门评级称呼() -> String:
	var 评级: Dictionary = 获取宗门评级()
	return str(评级.get("称呼", "末流宗门"))

## S1：洞府舒适度（弟子数/洞府数，<80%舒适，80-100%拥挤，>100%过载）
func 洞府拥挤度() -> float:
	if 洞府数量 <= 0:
		return 999.0
	return float(在宗弟子数()) / float(洞府数量)

## S1：扩建洞府（消耗灵石）
func 扩建洞府() -> Dictionary:
	var 消耗: int = int(洞府扩建消耗灵石 * pow(1.3, max(0, 洞府数量 - 10)))
	if 灵石 < 消耗:
		return {"成功": false, "原因": "灵石不足（需%d）" % 消耗}
	灵石 -= 消耗
	洞府数量 += 5  # 每次扩建+5个洞府
	_加推演条目("扩建洞府，新增5间洞府，当前共%d间" % 洞府数量, "庶务", "低")
	return {"成功": true, "新数量": 洞府数量}

## S1：获取洞府扩建消耗
func 获取洞府扩建消耗() -> int:
	return int(洞府扩建消耗灵石 * pow(1.3, max(0, 洞府数量 - 10)))

## S1：灵脉升级（消耗灵石+灵晶）
func 升级灵脉() -> Dictionary:
	if 灵脉等级 >= 10:
		return {"成功": false, "原因": "灵脉已达最高品级"}
	var 消耗灵石: int = int(灵脉升级消耗灵石 * pow(1.5, 灵脉等级 - 1))
	var 消耗灵晶: int = 灵脉等级 * 10
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d）" % 消耗灵石}
	if 灵晶 < 消耗灵晶:
		return {"成功": false, "原因": "灵晶不足（需%d）" % 消耗灵晶}
	灵石 -= 消耗灵石
	灵晶 -= 消耗灵晶
	灵脉等级 += 1
	_加推演条目("灵脉升级至%d级，灵气愈发充沛" % 灵脉等级, "庶务", "中")
	return {"成功": true, "新等级": 灵脉等级}

## S1：获取灵脉升级消耗
func 获取灵脉升级消耗() -> Dictionary:
	if 灵脉等级 >= 10:
		return {"灵石": 0, "灵晶": 0, "已满级": true}
	return {"灵石": int(灵脉升级消耗灵石 * pow(1.5, 灵脉等级 - 1)), "灵晶": 灵脉等级 * 10, "已满级": false}

## S1：当前弟子数量（在宗状态）
func 在宗弟子数() -> int:
	var n: int = 0
	for d in 弟子列表:
		if d != null and d is Disciple and d.状态 == "在宗":
			n += 1
	return n

## S1：是否超编
func 是否超编() -> bool:
	return 在宗弟子数() >= 宗门编制上限()
var 当前皮肤: String = "taixu_yunhai"   # 幻形·洞天换肤：已装备的宗门首页背景皮：id（纯展示态，零玩法触碰）
const 声望折扣表: Array = [1.0, 0.95, 0.9, 0.85, 0.8]   # 声望等级0-4对应折扣（中：友善/尊敬/崇敬/崇拜：
const 声望等级名: Array = ["中立", "友善", "尊敬", "崇敬", "崇拜"]
var 声望 := 0
var 执法日志: Array = []   # 执法堂日志（zhifa.gd 写入，上限100条）
var 繁荣 := 50
var 繁荣经营值: int = 0   # P1-2：繁荣可经营增量（供奉香火等玩家行为持久累积，避免被 更新门派() 派生覆盖抹平）
# === S1 ：-A：凡人香火体系（纯经营层 · 空桩逻辑 · 数：[PLACEHOLDER] 待真机校准）===
var 香火值:= 0
var 信徒数:= 0
# 凡人城镇已移至 dynasty_system.gd
var 香火日产预估 := 0
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
# 气运香火速率软上限：香火日产预估×2 在设计原意上限约 280×2=560（≈门派满级+~100 弟子）；
# 弟子数实际无硬性上限，会把它推到上千导致气运恒锁「昌隆」、正邪路由失效。软上限锁住香火项贡献，
# 使「纯香火」最高到「旺盛」，真要「昌隆」仍需功德/业力积累——正邪路线才真正决定气运走向。
const 气运香火速率上限: float = 560.0
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
var 日供_最后领取日: int = 0     # 上次领取日供时的累计游戏日（0=从未领取）
var 日供_最后领取现实日: String = ""  # 上次领取日供的现实日期（YYYY-MM-DD）
var 连续理事天数: int = 0       # 连续领取日供天数（中断则：：
var 日供_总领取次数: int= 0    # 累计领取次数（成：纪事用）
var 回溯玉符数量: int = 0       # 补领道具（S1 占位，后续接获取途径：
# ===== S1 成就系统统计变量（2026-08-30 第三阶段新增）=====
var 累计炼制丹药数: int = 0       # 累计炼制丹药数量（成就用）
var 累计锻造装备数: int = 0       # 累计锻造装备数量（成就用）
var 累计炼符数: int = 0           # 累计炼制符箓数量（成就用，S45-2；与丹/器同口径，未单列入存档字典）
var 累计灵石收入: int = 0         # 累计灵石收入（成就用）
var 累计招募弟子数: int = 0       # 累计招募弟子数量（成就用）
var 累计弟子突破次数: int = 0     # 累计弟子突破次数（成就用）
# ===== §11.15 优化#69/#72/#73/#74/#75 贸易拓展变量（不升SAVE_VERSION）=====
# 累计贸易次数已移至 caravan_system.gd
# 累计贸易收益已移至 caravan_system.gd
var 正道特许商品表: Array = []      # 黑市双线·正道特许商品
var 特殊商单表: Array = []          # 特殊商单（奖励物品化）
var 商品名_类型: Dictionary = {}    # BUG-C 修复：物品名→goods_type 反向映射
const 虚空瞬移仙玉费: int = 50      # 仙核/灵石不足时仙玉抵扣虚空瞬移
var 累计坊市交易次数: int = 0     # 累计坊市交易次数（成就用）
# ===== S1 成就系统统计变量（2026-08-30 第四阶段新增）=====
var 累计灵田产出: int = 0           # 累计灵田产出灵草数量（成就用）
var 累计矿场产出: int = 0           # 累计矿场产出矿石数量（成就用）
var 累计提升灵根次数: int = 0       # 累计使用洗髓丹提升灵根次数（成就用）
var 累计提升心境次数: int = 0       # 累计使用清心丹提升心境次数（成就用）
var 累计延长寿元次数: int = 0       # 累计使用长生丹延长寿元次数（成就用）
var 累计修复道伤次数: int = 0       # 累计使用道愈丹修复道伤次数（成就用）
# ===== S1 成就系统统计变量（2026-08-30 第五阶段新增）=====
var 累计发放俸禄次数: int = 0         # 累计发放俸禄次数（成就用）
# 药园已解锁地块已移至 herb_garden_system.gd
var 已解锁丹方数: int = 0             # 已解锁丹方数量（成就用）
var 已解锁装备图纸数: int = 0         # 已解锁装备图纸数量（成就用）
# ===== S1 傀儡系统和藏书阁系统（2026-08-30 新增）=====
# ===== S1 药园系统、丹方系统、装备图纸系统（2026-08-30 新增）=====
# 药园地块列表已移至 herb_garden_system.gd
# 药园地块数量已移至 herb_garden_system.gd
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
	# 基于现实日期判断（与活动系统重置一致）
	return 日供_最后领取现实日 != 获取现实日期()
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
	日供_最后领取现实日 = 获取现实日期()
	日供_总领取次数+= 1
	# 基础供奉：灵石+灵气+灵玉（修真味日常资源，应用连续参与加成）
	var 连续加成: float = 获取连续参与加成()
	var 基础灵石: int = int(50 * 倍 * 连续加成)
	var 基础灵气: int = int(20 * 倍 * 连续加成)
	var 基础灵玉: int = int(5 * 倍 * 连续加成)
	灵石 += 基础灵石
	灵气 += 基础灵气
	仙玉_绑定 += 基础灵玉
	var msg: String = "受领日供，灵石+%d，灵气+%d，灵玉+%d" % [基础灵石, 基础灵气, 基础灵玉]
	if 连续加成 > 1.0:
		msg += "（连续%d天，%.1f倍加成）" % [连续参与天数, 连续加成]
	if 缺领 > 0:
		msg += "（补领%d天）" % 缺领
	# 职司加成（合理数量，根据堂主等级缩放）
	for b in 日供职司加成():
		var 字段: String = b["字段"]
		var 数量: int = 5 * 倍  # 每次+5，而非糊弄人的+1
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
		msg += "，%s+%d" % [b["资源"], 数量]
	# 纪事联动
	if 连续理事天数 == 7:
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "小周天圆满", "文案": "连续七日不辍，道心日坚，宗门赐下筑基丹三枚以资鼓励。"})
		# 连续7天奖励：筑基丹×3 + 灵草×10
		for i in range(3):
			宗门库房.append(_造低阶物品("dan", "凡品"))
		灵草 += 10
		msg += "，连续7天：宗门赐筑基丹×3，灵草+10"
	elif 连续理事天数 == 30:
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "月度道统厚礼", "文案": "连续一月苦修不辍，宗门感其诚，赐下功法残卷与丹药。"})
		# 连续30天奖励：功法残卷×1 + 灵品丹药×2 + 悟道点+50
		宗门库房.append(_造低阶物品("gongfa", "凡阶"))
		for i in range(2):
			宗门库房.append(_造低阶物品("dan", "灵品"))
		悟道点 += 50
		msg += "，连续30天：赐功法残卷×1，灵品丹药×2，悟道+50"
	elif 连续理事天数 == 100:
		宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "百日筑基大成", "文案": "连续百日苦修，道基稳固，宗门赐下宝品丹药与上古功法残页。"})
		# 连续100天奖励：宝品丹药×3 + 功法残卷×2 + 悟道点+200
		for i in range(3):
			宗门库房.append(_造低阶物品("dan", "宝品"))
		for i in range(2):
			宗门库房.append(_造低阶物品("gongfa", "灵阶"))
		悟道点 += 200
		msg += "，连续100天：赐宝品丹药×3，功法残卷×2，悟道+200"
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
var 可晋升等级: int = 0  # P1：达到门槛可举办晋升大典的等级，0=无可晋升
# 宗主独立场所系统（宗主作为高阶修士有独立丹房/炼器室，不与弟子共用殿阁）
var 宗主丹房等级: int = 1
var 宗主炼器室等级: int = 1
var 宗主制符室等级: int = 1
var 宗主傀儡工坊等级: int = 1
var 宗主毒室等级: int = 1
var 毒道经验: int = 0  # 毒道修为经验，决定毒道境界
var 毒体经验: int = 0  # 毒体修炼经验，决定毒体境界（百毒不侵）
var _上次毒体境界: String = "凡躯"  # 毒体境界变化检测
var 上次七载日: int = 0          # 上次七载大考时的累计游戏日，用于跨 2555 日边界检：
var 七载大典待展示: bool = false   # 七载大考触发的瞬时展示标记（不存档），main._构建离山内容 读取后置 false
var 七载大典摘要: Dictionary = {}  # 七载大典待展示时承载的展示数据（灵石/法宝：晋升至），不存档
var 年始灵石 := 0             # 本年起始灵石（结算时算增量）
var 年始总战力:= 0           # 本年起始宗门总战力（结算时算增量）
var 年始宗主战力 := 0        # 本年起始宗主战力（结算时算增量）
var 年始宗主境界 := ""       # 本年起始宗主境界（结算时算是否提升）
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
var _本月符堂产出: int = 0
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
const ET_BREAKTHROUGH := "breakthrough"   # ▲ 境界突破
const ET_APPOINT     := "appoint"         # ◇ 岗位任职
const ET_QUEST       := "quest"           # ：：奇遇/探索事件
const ET_LOOT        := "loot"            # ◇ 获得物品
const ET_RESOURCE    := "resource"        # ◇ 资源产出
const ET_SECT        := "sect"            # ◇ 宗门事件
const ET_INFO        := "info"            # ⓘ 系统信息
# 推演优先级常：
const PRIO_HIGH   := "high"     # 重大事件（突：稀有道具）
const PRIO_NORMAL := "normal"   # 普通（任职/正向奇遇：
const PRIO_TRIVIAL:= "trivial"  # 琐事（无功而返/无赏赐）
# 战斗/历练系统（Day 2 数据驱动：
# P0修复：移除体力系统，改为每日机缘+VIP加成（符合用户要求：不增加体力/精力系统，允许玩家完全沉浸体验）
# 修真化文案：每日次数→机缘，不同类型有不同修真名称
var 每日机缘: Dictionary = {}  # {"探秘境缘": 已用, "游历机缘": 已用, "历练机缘": 已用, "征伐机缘": 已用, "入山机缘": 已用, "日期": 累计游戏日}

# ===== 护道人系统（P0实现）=====
# 修真世界观：宗门为天才弟子配备专属保护者和指导者
# 收费模式：基础免费 + 高阶VIP + 护道人道具
# 护道人等级：外门护道(筑基) / 内门护道(金丹) / 长老护道(元婴) / 太上护道(化神+)
const 护道人配置: Dictionary = {
	"外门护道": {"境界": "筑基", "修炼加成": 0.10, "突破加成": 0.05, "救援概率": 0.50, "功德需求": 100, "贡献需求": 100, "VIP需求": 0},
	"内门护道": {"境界": "金丹", "修炼加成": 0.15, "突破加成": 0.10, "救援概率": 0.60, "功德需求": 500, "贡献需求": 500, "VIP需求": 0},
	"长老护道": {"境界": "元婴", "修炼加成": 0.20, "突破加成": 0.15, "救援概率": 0.70, "功德需求": 2000, "贡献需求": 2000, "VIP需求": 4},
	"太上护道": {"境界": "化神", "修炼加成": 0.30, "突破加成": 0.20, "救援概率": 0.90, "功德需求": 5000, "贡献需求": 5000, "VIP需求": 7},
}
# 护道人列表：弟子ID -> 护道人信息
# {"护道人ID": 唯一ID, "护道人等级": "外门护道", "护道人姓名": "XXX", "功德": 0, "到期日": 累计游戏日+365, "替死玉符": false, "气运加持": 0}
var 护道人列表: Dictionary = {}
var 护道人计数器: int = 0  # 护道人ID计数器
# 护道人道具库存
var 护道玉符: int = 0  # 召唤护道人
var 护道续缘符: int = 0  # 延长保护时间
var 功德玉牌: int = 0  # 增加功德值
var 气运符箓: int = 0  # 临时提升效果
var 替死玉符: int = 0  # 确保一次危机救援成功
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

# §6.16 血脉共鸣系统（P0实现）
# 遵守数值红线：血脉类单源子帽≤1.5%（全局等效）
# 血脉共鸣修炼乘区：有血缘关系的弟子同时在宗时，提供微弱修炼加成
func 血脉共鸣修炼乘区() -> float:
	var 总加成: float = 0.0
	var 已统计: Dictionary = {}  # 避免重复统计同一对血缘关系
	for d in 弟子列表:
		if d == null or not (d is Disciple) or d.状态 != "在宗":
			continue
		var 亲属数: int = d.获取在宗血脉亲属数()
		if 亲属数 > 0:
			# 每个在宗亲属提供0.3%修炼加成，单弟子最多1.2%（4个亲属）
			var 弟子加成: float = min(0.003 * 亲属数, 0.012)
			总加成 += 弟子加成
	# 全宗血脉共鸣加成上限：全局等效≤1.5%（遵守§6.16数值红线）
	总加成 = min(总加成, 0.015)
	return 1.0 + 总加成

# §6.16 血脉共鸣战力加成：指定弟子的血脉共鸣战力加成
# 单源子帽≤1.5%（全局等效），S2组队系统解锁后组队时效果翻倍
func 血脉共鸣战力加成(弟子: Disciple) -> float:
	if 弟子 == null or not (弟子 is Disciple) or 弟子.状态 != "在宗":
		return 0.0
	var 亲属数: int = 弟子.获取在宗血脉亲属数()
	if 亲属数 <= 0:
		return 0.0
	# 每个在宗亲属提供0.3%战力加成，单弟子最多1.2%（4个亲属）
	var 加成: float = min(0.003 * 亲属数, 0.012)
	# S2预留：组队系统解锁后，组队时血脉共鸣效果翻倍（当前未实现组队，暂不翻倍）
	return 加成

# ============ §6.16 家族系统基础架构（P0实现）============
# 遵守修真世界设定：家族功法不外传、血脉传承、家族培养体系
# 数值红线：血脉类单源子帽≤1.5%（全局等效），家族气运单家族≤1%全局合计≤2%

# 家族列表：家族ID → 家族数据字典

# ===== 家族系统（已拆分到family_system.gd，此处为转发函数）=====
func 创建家族(家族名: String, 老祖: Disciple):
	return 家族系统.创建家族(家族名, 老祖)
func 获取家族(家族ID: String):
	return 家族系统.获取家族(家族ID)
func 加入家族(弟子: Disciple, 家族ID: String):
	return 家族系统.加入家族(弟子, 家族ID)
func 退出家族(弟子: Disciple):
	return 家族系统.退出家族(弟子)
func 解散家族(家族ID: String):
	家族系统.解散家族(家族ID)
func 计算血脉加成(弟子: Disciple):
	return 家族系统.计算血脉加成(弟子)
func 计算家族功法叠加(弟子: Disciple):
	return 家族系统.计算家族功法叠加(弟子)
func 学习家族功法(弟子: Disciple, 功法ID: String):
	return 家族系统.学习家族功法(弟子, 功法ID)
func 觉醒血脉(弟子: Disciple):
	return 家族系统.觉醒血脉(弟子)
func 存入家族宝库(弟子: Disciple, 物品: Dictionary, 数量: int = 1):
	return 家族系统.存入家族宝库(弟子, 物品, 数量)
func 从家族宝库取出(弟子: Disciple, 物品ID: String, 数量: int = 1):
	return 家族系统.从家族宝库取出(弟子, 物品ID, 数量)
func 查看家族宝库(家族ID: String):
	return 家族系统.查看家族宝库(家族ID)
func 装备家族秘宝(弟子: Disciple, 秘宝ID: String):
	return 家族系统.装备家族秘宝(弟子, 秘宝ID)
func 卸下家族秘宝(弟子: Disciple):
	return 家族系统.卸下家族秘宝(弟子)
func 计算家族秘宝加成(弟子: Disciple):
	return 家族系统.计算家族秘宝加成(弟子)
func 随机生成功法名字(家族名: String = ""):
	return 家族系统.随机生成功法名字(家族名)
func 学习家族血脉功法(弟子: Disciple):
	return 家族系统.学习家族血脉功法(弟子)
func 学习神兽血脉功法(弟子: Disciple, 功法ID: String):
	return 家族系统.学习神兽血脉功法(弟子, 功法ID)
func 计算血脉功法加成(弟子: Disciple):
	return 家族系统.计算血脉功法加成(弟子)
func 布置家族阵法(家族ID: String, 阵法ID: String, 布置者: Disciple):
	return 家族系统.布置家族阵法(家族ID, 阵法ID, 布置者)
func 加入阵法驻守(家族ID: String, 弟子: Disciple):
	return 家族系统.加入阵法驻守(家族ID, 弟子)
func 计算家族阵法加成(弟子: Disciple):
	return 家族系统.计算家族阵法加成(弟子)
func 升级家族学塾(家族ID: String, 操作者: Disciple):
	return 家族系统.升级家族学塾(家族ID, 操作者)
func 家族试炼(家族ID: String, 弟子: Disciple):
	return 家族系统.家族试炼(家族ID, 弟子)
func 计算家族培养加成(弟子: Disciple):
	return 家族系统.计算家族培养加成(弟子)
func 学习宗门功法(弟子: Disciple, 功法ID: String):
	return 家族系统.学习宗门功法(弟子, 功法ID)
func 清除宗门功法(弟子: Disciple):
	return 家族系统.清除宗门功法(弟子)
func 家族联盟(家族ID1: String, 家族ID2: String, 操作者: Disciple):
	return 家族系统.家族联盟(家族ID1, 家族ID2, 操作者)
func 解除家族联盟(家族ID1: String, 家族ID2: String, 操作者: Disciple):
	return 家族系统.解除家族联盟(家族ID1, 家族ID2, 操作者)
func 家族联姻(家族ID1: String, 家族ID2: String, 弟子1: Disciple, 弟子2: Disciple, 操作者: Disciple):
	return 家族系统.家族联姻(家族ID1, 家族ID2, 弟子1, 弟子2, 操作者)
func 家族结仇(家族ID1: String, 家族ID2: String, 原因: String, 操作者: Disciple):
	return 家族系统.家族结仇(家族ID1, 家族ID2, 原因, 操作者)
func 家族和解(家族ID1: String, 家族ID2: String, 操作者: Disciple):
	return 家族系统.家族和解(家族ID1, 家族ID2, 操作者)
func 计算家族社交加成(弟子: Disciple):
	return 家族系统.计算家族社交加成(弟子)
func 检测功法泄露(弟子: Disciple, 功法ID: String, 功法类型: String):
	return 家族系统.检测功法泄露(弟子, 功法ID, 功法类型)
func 执行功法泄露惩罚(弟子: Disciple, 功法ID: String, 功法类型: String):
	return 家族系统.执行功法泄露惩罚(弟子, 功法ID, 功法类型)
func 触发家族事件(家族ID: String, 事件类型: String, 附加信息: Dictionary = {}):
	return 家族系统.触发家族事件(家族ID, 事件类型, 附加信息)
func 获取家族事件记录(家族ID: String, 限制数量: int = 20):
	return 家族系统.获取家族事件记录(家族ID, 限制数量)
func 计算家族实力评分(家族ID: String):
	return 家族系统.计算家族实力评分(家族ID)
func 获取家族排行榜(限制数量: int = 10):
	return 家族系统.获取家族排行榜(限制数量)
func 获取家族排名(家族ID: String):
	return 家族系统.获取家族排名(家族ID)

# ============ §6.16 家族竞争系统（P4实现）============
# 修真世界设定：资源点竞争、秘境竞争、家族排名竞争

# 资源点配置
var _资源点配置: Dictionary = {
	"resource_001": {"名": "灵脉矿脉", "类型": "灵石", "产出": 100, "描述": "富含灵石的矿脉，每日产出大量灵石"},
	"resource_002": {"名": "灵药园", "类型": "灵草", "产出": 50, "描述": "种植灵药的园地，每日产出大量灵草"},
	"resource_003": {"名": "炼器坊", "类型": "矿石", "产出": 30, "描述": "炼制法器的坊市，每日产出大量矿石"},
	"resource_004": {"名": "聚灵地", "类型": "修炼", "产出": 20, "描述": "灵气浓郁的宝地，占据家族成员修炼速度+20%"},
	"resource_005": {"名": "秘境入口", "类型": "秘境", "产出": 10, "描述": "通往秘境的入口，占据家族可定期探索秘境"}
}

# 资源点占领状态
var _资源点占领: Dictionary = {}

## 争夺资源点
func 争夺资源点(家族ID: String, 资源点ID: String, 挑战者: Disciple) -> Dictionary:
	if 家族ID == "" or 资源点ID == "" or 挑战者 == null:
		return {"成功": false, "因": "参数无效"}
	if not _资源点配置.has(资源点ID):
		return {"成功": false, "因": "资源点不存在"}
	var 家族: Dictionary = 获取家族(家族ID)
	if 家族.is_empty():
		return {"成功": false, "因": "家族不存在"}
	# 检查挑战者权限
	var 职位权限: Dictionary = {"老祖": 10, "长老": 8, "核心": 6, "内门": 4, "外门": 2, "附庸": 1}
	if 挑战者.家族ID != 家族ID or 职位权限.get(挑战者.家族职位, 0) < 6:
		return {"成功": false, "因": "权限不足，只有核心及以上才能争夺资源点"}
	# 检查是否已被占领
	var 当前占领: String = str(_资源点占领.get(资源点ID, ""))
	if 当前占领 == 家族ID:
		return {"成功": false, "因": "本家族已占领此资源点"}
	# 争夺判定（简化版：比较家族实力评分）
	var 挑战方评分: int = 计算家族实力评分(家族ID).get("评分", 0)
	var 防守方评分: int = 0
	if 当前占领 != "":
		防守方评分 = 计算家族实力评分(当前占领).get("评分", 0)
	# 挑战方有30%基础胜率，加上实力差距
	var 胜率: float = 0.3 + clamp((挑战方评分 - 防守方评分) / 200.0, -0.3, 0.5)
	if randf() < 胜率:
		# 争夺成功
		_资源点占领[资源点ID] = 家族ID
		# 触发事件
		触发家族事件(家族ID, "family_rise", {"资源点": 资源点ID})
		var 资源点: Dictionary = _资源点配置[资源点ID]
		添加纪事("家族竞争", "争夺成功", "「%s」成功争夺资源点「%s」" % [str(家族.get("名", "")), str(资源点.get("名", ""))], 1)
		return {"成功": true, "结果": "争夺成功", "资源点": str(资源点.get("名", ""))}
	else:
		# 争夺失败
		添加纪事("家族竞争", "争夺失败", "「%s」争夺资源点「%s」失败" % [str(家族.get("名", "")), _资源点配置[资源点ID].get("名", "")], 1)
		return {"成功": true, "结果": "争夺失败", "胜率": 胜率}

## 获取资源点占领状态
func 获取资源点占领状态() -> Array:
	var 结果: Array = []
	for 资源点ID in _资源点配置.keys():
		var 资源点: Dictionary = _资源点配置[资源点ID]
		var 占领家族ID: String = str(_资源点占领.get(资源点ID, ""))
		var 占领家族名: String = "无主"
		if 占领家族ID != "" and 家族系统.家族列表.has(占领家族ID):
			占领家族名 = str(家族系统.家族列表[占领家族ID].get("名", ""))
		结果.append({
			"资源点ID": 资源点ID,
			"名": str(资源点.get("名", "")),
			"类型": str(资源点.get("类型", "")),
			"产出": int(资源点.get("产出", 0)),
			"描述": str(资源点.get("描述", "")),
			"占领家族ID": 占领家族ID,
			"占领家族名": 占领家族名
		})
	return 结果
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
		"lingtian": {"名称": "灵田", "描述": "产出灵石和灵草", "类型": "产出", "需等级": 1},
		"kuangmai": {"名称": "矿脉", "描述": "产出矿石", "类型": "产出", "需等级": 1},
		"dantang": {"名称": "丹堂", "描述": "提升炼丹成功率", "类型": "功能", "需等级": 2},
		"qitang": {"名称": "器堂", "描述": "提升锻造成功率", "类型": "功能", "需等级": 2},
		"cangjing": {"名称": "藏经阁", "描述": "提升修炼速度", "类型": "功能", "需等级": 3},
		"zhifa": {"名称": "执法堂", "描述": "减少负面事件", "类型": "功能", "需等级": 3},
		"futang": {"名称": "符堂", "描述": "提升炼符成功率", "类型": "功能", "需等级": 4},
		"gongxun": {"名称": "功勋阁", "描述": "提升声望获取", "类型": "功能", "需等级": 4},
		"yushou": {"名称": "御兽堂", "描述": "提升灵兽能力", "类型": "功能", "需等级": 5},
		"zhenfa": {"名称": "阵法堂", "描述": "提升阵法效果", "类型": "功能", "需等级": 5},
		"yuying": {"名称": "育英堂", "描述": "提升弟子培养效率", "类型": "功能", "需等级": 6},
		"xichi": {"名称": "洗池", "描述": "提升弟子突破成功率", "类型": "功能", "需等级": 6},
		"tanwei": {"名称": "探微阁", "描述": "提升探索收益", "类型": "功能", "需等级": 7},
	}
	for 建筑ID in 建筑配置.keys():
		var 配置 = 建筑配置[建筑ID]
		var 等级 = 0
		if 司职列表.has(建筑ID):
			var 职 = 司职列表[建筑ID]
			等级 = int(职.get("等级", 1))
		var 需等级: int = int(配置.get("需等级", 1))
		var 可解锁: bool = 门派等级 >= 需等级
		建筑列表.append({
			"建筑ID": 建筑ID,
			"名称": 配置.get("名称", ""),
			"描述": 配置.get("描述", ""),
			"类型": 配置.get("类型", ""),
			"等级": 等级,
			"已解锁": 等级 > 0,
			"需等级": 需等级,
			"可解锁": 可解锁,
		})
	return 建筑列表

# 获取建筑总加成
func 获取建筑总加成() -> Dictionary:
	var 加成 = {"修炼速度": 0.0, "产出": 0.0, "声望": 0.0, "炼丹成功率": 0.0, "锻造成功率": 0.0, "符箓成功率": 0.0}
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
	# 符堂：炼符成功率+5%
	if 司职列表.has("futang"):
		加成["符箓成功率"] += 0.05
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
	_加载称号配置()      # 称号系统配置
	_加载阵营任务配置()  # 阵营任务配置
	_加载阵营商店配置()  # 阵营商店配置
	加载商队配置()       # S2 商路贸易：消费 caravan 岗位/载具配置
	if 当前账号id != "" and 弟子列表.is_empty():
		初始建宗()
		_传承事件("开宗立派")   # WAVE-D #8：新游戏即达成「开宗立派」里程碑 + 先贤事迹图录
		save_game()              # 首次建宗后自动存档，确保下次启动出现「继续游戏：
	重建司职()
	# H项：设置复兴进度→色彩饱和/明度派生（门派等级1-7映射到0.0-1.0）
	if Engine.has_singleton("UITheme") or get_node_or_null("/root/UITheme") != null:
		UITheme.设置复兴进度(门派等级)
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
	# 活动系统：基于现实时间检查日常/周常重置
	检查日常活动重置()
	检查周常活动重置()
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

	# S2：创建宗主独立角色实体（金丹境界，作为宗门创始人）
	_初始化宗主()
	for i in 5:
		弟子列表.append(Disciple.new())
	# 一位创始人：直接筑基入门，展示道：司职
	var 新:= Disciple.new()
	新.突破()           # 练气→筑基，触发 判定道途+ 入堂
	弟子列表.append(新)

## S2：初始化宗主独立角色实体
func _初始化宗主() -> void:
	宗主 = Disciple.new()
	宗主.姓名 = 宗主名
	宗主.身份 = "宗主"
	宗主.境界 = "金丹"
	宗主.寿元 = 500
	宗主.战力 = 1500
	宗主.状态 = "在宗"
	宗主.司职 = ""
	宗主.对宗主忠诚度 = 100.0
	宗主.炼丹等级 = 1
	宗主.炼器等级 = 1
	宗主.年龄 = 30.0
	宗主精力 = 宗主精力上限
	_加推演条目("【%s】创立宗门，开始修仙之路" % 宗主名, "宗门", "高")

## S2：旧档懒迁移宗主实体（旧档无宗主实体时创建）
func _迁移宗主实体() -> void:
	if 宗主 != null:
		return
	宗主 = Disciple.new()
	宗主.姓名 = 宗主名
	宗主.身份 = "宗主"
	宗主.境界 = "金丹"
	宗主.寿元 = 500
	宗主.战力 = 1500
	宗主.状态 = "在宗"
	宗主.司职 = ""
	宗主.对宗主忠诚度 = 100.0
	宗主.炼丹等级 = 1
	宗主.炼器等级 = 1
	宗主.年龄 = 50.0
	宗主精力 = 宗主精力上限
	_加推演条目("【%s】宗主实体已激活（旧档迁移）" % 宗主名, "宗门", "中")

## 2026-09-15 修：一次性净化「弟子列表里与宗主同名者」。
## 背景：旧版 main.gd 在创建宗门时会把第一个筑基弟子改名成玩家自定的宗主名，
##   于是弟子列表里凭空多出一个「第二个宗主」（宗主本人是独立实体 Game.宗主，不在该列表里）。
## 处理：给这些同名的弟子重新赐名（避开宗主名，也避开现存其他弟子的姓名）。
## 幂等：无同名者直接返回；可在每次 load_game 安全调用。
func _净化弟子与宗主同名() -> void:
	var 宗主姓名: String = str(宗主名).strip_edges()
	if 宗主姓名 == "":
		return
	var 已占用: Dictionary = {}
	for _已有 in 弟子列表:
		已占用[str(_已有.姓名)] = true
	var 改名数: int = 0
	for d in 弟子列表:
		if str(d.姓名) != 宗主姓名:
			continue
		var 新名: String = ""
		for _试 in 12:
			var 生成名: String = ""
			if randf() < 0.7:
				生成名 = Disciple.名库单字.pick_random()
			else:
				生成名 = Disciple.名库双字首.pick_random() + Disciple.名库双字尾.pick_random()
			var 候选: String = Disciple.姓库.pick_random() + 生成名
			if 候选 != 宗主姓名 and not 已占用.has(候选):
				新名 = 候选
				break
		if 新名 == "":
			continue
		已占用.erase(str(d.姓名))
		d.姓名 = 新名
		已占用[新名] = true
		改名数 += 1
	if 改名数 > 0:
		_加推演条目("门中有%d名弟子与宗主同名，已依其禀赋重新赐名" % 改名数, "宗门", "中")
		弟子变动.emit()

## S2：宗主亲自炼丹（消耗精力+灵石，基于宗主炼丹等级）
## P0联动：宗主传功（宗主消耗精力，为弟子提升修炼速度，持续7天）
func 宗主传功(弟子: Disciple) -> Dictionary:
	if 宗主 == null:
		return {"成功": false, "原因": "宗主实体未初始化"}
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if 宗主精力 < 30:
		return {"成功": false, "原因": "宗主精力不足（需30，当前%d）" % 宗主精力}
	# 消耗宗主精力
	宗主精力 -= 30
	# 计算传功加成（宗主境界越高，加成越大）
	var 宗主境界序: int = Disciple.境界序.find(宗主.境界)
	var 传功加成: float = 0.3 + float(宗主境界序) * 0.05  # 基础30%，每境界+5%
	# 设置弟子传功状态（持续7天）
	弟子.传功加成 = 传功加成
	弟子.传功剩余日 = 7
	# 添加纪事
	_加推演条目("【宗主】为%s亲自传功，弟子修炼速度提升%d%%，持续七日" % [弟子.姓名, int(传功加成 * 100)], "宗主", "中")
	添加纪事("宗主", "传功授业", "宗主为%s传功，修炼速度+%d%%，持续七日" % [弟子.姓名, int(传功加成 * 100)], 0)
	return {"成功": true, "弟子": 弟子.姓名, "加成": 传功加成, "持续日": 7}

## P0联动：宗主护法（宗主为弟子突破护法，提升突破成功率）
func 宗主护法(弟子: Disciple) -> Dictionary:
	if 宗主 == null:
		return {"成功": false, "原因": "宗主实体未初始化"}
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if 宗主精力 < 50:
		return {"成功": false, "原因": "宗主精力不足（需50，当前%d）" % 宗主精力}
	# 消耗宗主精力
	宗主精力 -= 50
	# 计算护法加成（宗主境界越高，加成越大）
	var 宗主境界序: int = Disciple.境界序.find(宗主.境界)
	var 护法加成: float = 0.2 + float(宗主境界序) * 0.03  # 基础20%，每境界+3%
	# 设置弟子护法状态（下次突破生效）
	弟子.护法加成 = 护法加成
	弟子.待护法突破 = true
	# 添加纪事
	_加推演条目("【宗主】为%s突破护法，气机牵引，突破成功率提升%d%%" % [弟子.姓名, int(护法加成 * 100)], "宗主", "中")
	添加纪事("宗主", "护法突破", "宗主为%s护法，突破成功率+%d%%" % [弟子.姓名, int(护法加成 * 100)], 0)
	return {"成功": true, "弟子": 弟子.姓名, "加成": 护法加成}

func 宗主炼丹(丹方ID: String) -> Dictionary:
	if 宗主 == null:
		return {"成功": false, "原因": "宗主实体未初始化"}
	if 宗主精力 < 20:
		return {"成功": false, "原因": "宗主精力不足（需20，当前%d）" % 宗主精力}
	# 消耗精力
	宗主精力 -= 20
	# 使用宗主丹房等级（独立于丹堂）
	var 丹房等级: int = 获取宗主场所等级("丹房")
	# 宗主场所加成（成功率/高品质率）
	var 场所加成: Dictionary = 获取宗主场所加成("丹房")
	# 毒医双修：毒道境界影响炼丹（懂药理者，炼丹亦精）
	var 毒道炼丹加成: Dictionary = 获取毒道炼丹加成()
	var 有效丹房等级: int = 丹房等级 + int(float(毒道炼丹加成["成功率加成"]) * 20)  # 每10%加成=2级丹房
	# 调用S38/S39完整炼丹系统（使用有效丹房等级）
	var 结果: Dictionary = 执行炼丹(丹方ID, 有效丹房等级)
	if bool(结果.get("成功", false)):
		var 产出名: String = str(结果.get("名称", ""))
		var 产出数: int = int(结果.get("数量", 1))
		var 毒道境界: String = 获取毒道境界()
		if 毒道境界 != "毒道学徒":
			_加推演条目("【宗主】于丹房亲自炼丹成功，获得%s×%d（丹房%d级，场所加成成功率+%d%%，毒医双修%s加成）" % [产出名, 产出数, 丹房等级, int(float(场所加成["成功率加成"]) * 100), 毒道境界], "宗主", "中")
		else:
			_加推演条目("【宗主】于丹房亲自炼丹成功，获得%s×%d（丹房%d级，场所加成成功率+%d%%）" % [产出名, 产出数, 丹房等级, int(float(场所加成["成功率加成"]) * 100)], "宗主", "中")
		结果["炼丹等级"] = 丹房等级
		结果["毒医加成"] = 毒道炼丹加成
		结果["场所加成"] = 场所加成
	else:
		_加推演条目("【宗主】于丹房炼丹失败，药材损毁（丹房%d级）" % 丹房等级, "宗主", "低")
	return 结果

## 宗主亲自炼器（接入S42/S43完整系统）
func 宗主炼器(配方ID: String) -> Dictionary:
	if 宗主 == null:
		return {"成功": false, "原因": "宗主实体未初始化"}
	if 宗主精力 < 30:
		return {"成功": false, "原因": "宗主精力不足（需30，当前%d）" % 宗主精力}
	# 消耗精力
	宗主精力 -= 30
	# 使用宗主炼器室等级（独立于器堂）
	var 炼器室等级: int = 获取宗主场所等级("炼器室")
	# 宗主场所加成（成功率/高品质率）
	var 场所加成: Dictionary = 获取宗主场所加成("炼器室")
	# 调用S42/S43完整炼器系统（使用宗主炼器室等级）
	var 结果: Dictionary = 执行炼器(配方ID, 炼器室等级, 宗主)
	if bool(结果.get("成功", false)):
		var 产出名: String = str(结果.get("名称", ""))
		_加推演条目("【宗主】于炼器室亲自炼器成功，获得%s（炼器室%d级，场所加成成功率+%d%%）" % [产出名, 炼器室等级, int(float(场所加成["成功率加成"]) * 100)], "宗主", "中")
		结果["炼器等级"] = 炼器室等级
		结果["场所加成"] = 场所加成
	else:
		_加推演条目("【宗主】于炼器室炼器失败，材料损毁（炼器室%d级）" % 炼器室等级, "宗主", "低")
	return 结果

## 宗主亲自制符（接入S45完整系统，消耗精力+调用符箓封装系统）
func 宗主制符(符箓ID: String) -> Dictionary:
	if 宗主 == null:
		return {"成功": false, "原因": "宗主实体未初始化"}
	if 宗主精力 < 15:
		return {"成功": false, "原因": "宗主精力不足（需15，当前%d）" % 宗主精力}
	# 消耗精力
	宗主精力 -= 15
	# 使用宗主制符室等级（独立于符堂）
	var 制符室等级: int = 获取宗主场所等级("制符室")
	# 宗主场所加成（成功率/高品质率）
	var 场所加成: Dictionary = 获取宗主场所加成("制符室")
	# 调用S45完整炼符系统（使用宗主制符室等级）
	var 结果: Dictionary = 执行炼符(符箓ID, 制符室等级)
	if bool(结果.get("成功", false)):
		var 产出名: String = str(结果.get("名称", ""))
		var 产出数: int = int(结果.get("数量", 1))
		_加推演条目("【宗主】于制符室亲自绘符成功，获得%s×%d（制符室%d级，场所加成成功率+%d%%）" % [产出名, 产出数, 制符室等级, int(float(场所加成["成功率加成"]) * 100)], "宗主", "中")
		结果["制符等级"] = 制符室等级
		结果["场所加成"] = 场所加成
	else:
		_加推演条目("【宗主】于制符室绘符失败，符纸损毁（制符室%d级）" % 制符室等级, "宗主", "低")
	return 结果

## 获取宗主可绘制符箓列表（接入S45完整符箓配置）
func 获取宗主符箓列表() -> Array:
	var 列表: Array = []
	# 从符箓配置表读取所有可绘制符箓
	var 配置表 = _读表_符箓()
	for 行 in 配置表:
		if 行 is Dictionary and 行.has("名称"):
			列表.append(str(行["名称"]))
	return 列表

## 宗主亲自制作傀儡（接入傀儡系统，消耗精力）
func 宗主制作傀儡(傀儡名称: String, 傀儡品阶: String, 傀儡类型: String) -> Dictionary:
	if 宗主 == null:
		return {"成功": false, "原因": "宗主实体未初始化"}
	if 宗主精力 < 25:
		return {"成功": false, "原因": "宗主精力不足（需25，当前%d）" % 宗主精力}
	# 消耗精力
	宗主精力 -= 25
	# 调用傀儡系统
	var 结果: Dictionary = 制作傀儡(傀儡名称, 傀儡品阶, 傀儡类型)
	if bool(结果.get("成功", false)):
		_加推演条目("【宗主】亲自炼制傀儡成功，获得%s（%s）" % [傀儡名称, 傀儡品阶], "宗主", "中")
	else:
		_加推演条目("【宗主】炼制傀儡失败，材料损毁" , "宗主", "低")
	return 结果

## S2：宗主亲自探索秘境（消耗精力+体力，基于宗主境界/战力）
func 宗主探索秘境(秘境ID: String) -> Dictionary:
	if 宗主 == null:
		return {"成功": false, "原因": "宗主实体未初始化"}
	if 宗主精力 < 25:
		return {"成功": false, "原因": "宗主精力不足（需25，当前%d）" % 宗主精力}
	if 体力 < 10:
		return {"成功": false, "原因": "体力不足（需10，当前%d）" % 体力}

	# 秘境配置（简化版）
	var 秘境配置: Dictionary = {
		"炼气秘境": {"推荐境界": "练气", "基础奖励": 100, "危险度": 0.1},
		"筑基秘境": {"推荐境界": "筑基", "基础奖励": 300, "危险度": 0.2},
		"金丹秘境": {"推荐境界": "金丹", "基础奖励": 800, "危险度": 0.3},
		"元婴秘境": {"推荐境界": "元婴", "基础奖励": 2000, "危险度": 0.4},
	}
	if not 秘境配置.has(秘境ID):
		return {"成功": false, "原因": "秘境不存在：%s" % 秘境ID}

	var 配置: Dictionary = 秘境配置[秘境ID]
	var 推荐境界序: int = Disciple.境界序.find(str(配置["推荐境界"]))
	var 宗主境界序: int = Disciple.境界序.find(str(宗主.境界))

	# P0修复：体力系统改为每日机缘校验
	var 机缘检查: Dictionary = 检查机缘("游历机缘")
	if not 机缘检查.get("足够", false):
		return {"成功": false, "原因": "今日游历机缘已尽（%d/%d），可提升仙缘位阶以增机缘" % [机缘检查.get("已用", 0), 机缘检查.get("上限", 0)]}
	# 消耗
	宗主精力 -= 25
	消耗机缘("游历机缘")

	# 成功率：境界达标=70%，每高1阶+10%，每低1阶-15%
	var 境界差: int = 宗主境界序 - 推荐境界序
	var 成功率: float = 0.7 + float(境界差) * 0.1
	成功率 = clamp(成功率, 0.2, 0.95)

	# 战力加成：每1000战力+2%
	var 战力加成: float = float(宗主.战力) / 1000.0 * 0.02
	成功率 = min(0.98, 成功率 + 战力加成)

	if randf() < 成功率:
		# 成功：获得奖励
		var 奖励灵石: int = int(配置["基础奖励"]) + randi() % int(配置["基础奖励"])
		灵石 += 奖励灵石
		宗主威望 += 1

		# 概率获得材料/装备
		var 获得物品: String = ""
		if randf() < 0.3:
			var 材料列表: Array = ["灵草", "灵晶", "矿石", "妖兽内丹"]
			获得物品 = 材料列表[randi() % 材料列表.size()]
			var 材料 = Item.new()
			材料.名称 = 获得物品
			材料.类型 = "材料"
			材料.品阶 = "良品"
			宗主.背包.append(材料)

		_加推演条目("【宗主】探索%s成功，获得灵石%d%s（威望+1）" % [秘境ID, 奖励灵石, "，获得"+获得物品 if 获得物品 != "" else ""], "宗主", "中")
		return {"成功": true, "奖励灵石": 奖励灵石, "获得物品": 获得物品, "威望": 宗主威望}
	else:
		# 失败：概率受伤
		var 受伤: bool = randf() < float(配置["危险度"])
		if 受伤:
			宗主.受伤剩余 = max(int(宗主.受伤剩余), 7)
			_加推演条目("【宗主】探索%s失败，遭遇危险受伤（养伤7天）" % 秘境ID, "宗主", "高")
			return {"成功": false, "原因": "探索失败，宗主受伤", "受伤": true}
		else:
			_加推演条目("【宗主】探索%s失败，无功而返" % 秘境ID, "宗主", "低")
			return {"成功": false, "原因": "探索失败", "受伤": false}

## S2：获取宗主可探索秘境列表
func 获取宗主秘境列表() -> Array:
	return ["炼气秘境", "筑基秘境", "金丹秘境", "元婴秘境"]

## S3：宗主进入闭关（修炼加速，宗门由副宗主/方针代管）
func 宗主进入闭关() -> Dictionary:
	if 宗主 == null:
		return {"成功": false, "原因": "宗主实体未初始化"}
	if 宗主闭关中:
		return {"成功": false, "原因": "宗主已在闭关中"}
	宗主闭关中 = true
	宗主闭关开始日 = 累计游戏日
	宗主闭关累计天 = 0
	# 闭关代管：副宗主权能外的事务先登记为待办，宗主出关后亲办
	# （可代管() 依赖 宗主闭关中，必须置于置位之后）
	var 不可代管: Array = []
	for 事务类型 in 代管权能.keys():
		if not 可代管(str(事务类型)):
			不可代管.append(str(事务类型))
	if not 不可代管.is_empty():
		添加待处理事件("代管缺口", "闭关期间「%s」等%d类事务无人可代管，需宗主出关亲办" % ["、".join(不可代管), 不可代管.size()])
	最后在线时间戳 = Time.get_unix_time_from_system()
	_加推演条目("【宗主】进入闭关修炼，宗门事务交由方针代管", "宗主", "中")
	return {"成功": true, "开始日": 宗主闭关开始日}

## S3：宗主退出闭关（结算闭关收益）
func 宗主退出闭关() -> Dictionary:
	if not 宗主闭关中:
		return {"成功": false, "原因": "宗主未在闭关"}
	var 闭关天数: int = 累计游戏日 - 宗主闭关开始日
	宗主闭关累计天 = 闭关天数
	宗主闭关中 = false
	# 闭关收益：修炼进度加成（闭关期间修炼速度×2）
	if 宗主 != null and 闭关天数 > 0:
		var 额外修为: float = float(闭关天数) * 0.01  # 每天1%修为
		宗主.修炼进度 = min(1.0, 宗主.修炼进度 + 额外修为)
		宗主精力 = 宗主精力上限  # 闭关恢复全部精力
	_加推演条目("【宗主】出关，闭关%d天，修为大增，精力全满" % 闭关天数, "宗主", "中")
	return {"成功": true, "闭关天数": 闭关天数, "额外修为": float(闭关天数) * 0.01}

## S3：离线结算（上线时调用，计算离线期间的资源产出）
func 离线结算() -> Dictionary:
	var 当前时间: float = Time.get_unix_time_from_system()
	if 最后在线时间戳 <= 0:
		最后在线时间戳 = 当前时间
		return {"成功": false, "原因": "首次上线，无离线数据"}
	var 离线秒: float = 当前时间 - 最后在线时间戳
	最后在线时间戳 = 当前时间
	if 离线秒 < 60:  # 离线不足1分钟不结算
		return {"成功": false, "原因": "离线时间过短（不足1分钟）"}
	# 离线游戏日 = 离线秒 / 240（游戏1日=240现实秒=4分钟）
	var 离线游戏日: int = int(离线秒 / 240)
	if 离线游戏日 <= 0:
		return {"成功": false, "原因": "离线时间不足1游戏日"}
	# 限制最大离线结算（7天=210游戏日）
	离线游戏日 = min(离线游戏日, 210)
	# 离线资源产出（按日均产出的50%结算，避免离线比在线收益高）
	var 日均灵石: int = max(10, int(灵石 / max(1, 累计游戏日)))
	var 离线灵石: int = int(日均灵石 * 离线游戏日 * 0.5 * 离线结算倍率)
	var 离线灵草: int = int(日均灵石 * 0.3 * 离线游戏日 * 0.5 * 离线结算倍率)
	灵石 += 离线灵石
	灵草 += 离线灵草
	# 宗主闭关期间额外修炼
	if 宗主闭关中 and 宗主 != null:
		var 额外修为: float = float(离线游戏日) * 0.01
		宗主.修炼进度 = min(1.0, 宗主.修炼进度 + 额外修为)
		宗主闭关累计天 += 离线游戏日
		if 宗主.修炼进度 >= 1.0:
			_宗主尝试突破()
	_加推演条目("【离线结算】离线%d游戏日，获得灵石%d、灵草%d（倍率%.1f×）" % [离线游戏日, 离线灵石, 离线灵草, 离线结算倍率], "宗门", "中")
	return {"成功": true, "离线游戏日": 离线游戏日, "离线灵石": 离线灵石, "离线灵草": 离线灵草}

## S3：设置离线结算倍率（VIP/月卡调用）
func 设置离线倍率(倍率: float) -> void:
	离线结算倍率 = clamp(倍率, 1.0, 3.0)

## S3：更新最后在线时间戳（每次保存时调用）
func 更新在线时间戳() -> void:
	最后在线时间戳 = Time.get_unix_time_from_system()

## E：宗主延寿（延寿丹/奇遇/突破调用）
func 宗主延寿(年数: int) -> void:
	宗主剩余寿元 += 年数
	_加推演条目("【宗主】寿元增加%d年，当前剩余%d年" % [年数, 宗主剩余寿元], "宗主", "中")

## 宗主修炼进度圆满 → 突破下一境界
## 复用弟子那套天劫核心（心魔关 + 因果倍率 + 四槽抗性），区别：宗主可调用更多宗门资源
## （护山大阵/护法/渡劫丹药/防御雷劫法宝）。凡境顺渡（练气→元婴，无劫）走直接出口；
## 元婴→化神起须渡天劫，复用 宗主.渡天劫 → Tribulation.计算渡劫结果 → 突破/受创/陨落/保命替死。
func _宗主尝试突破() -> bool:
	if 宗主 == null or 宗主.修炼进度 < 1.0:
		return false
	if 宗主.受伤剩余 > 0 or 宗主.突破冷却剩余 > 0:
		return false   # 带伤/冷却中不渡劫（与弟子一致）
	var 序: int = Disciple.境界序.find(str(宗主.境界))
	if 序 < 0 or 序 + 1 >= Disciple.境界序.size():
		return false
	var 新境界: String = str(Disciple.境界序[序 + 1])
	# 凡境顺渡（无需天劫）：练气→筑基→金丹→元婴
	if not Tribulation.需渡劫(新境界):
		宗主.境界 = 新境界
		宗主.修炼进度 = 0.0
		_宗主突破增加寿元(新境界)
		# 宗主突破时也能自创功法（6.17.1）
		尝试自创功法(宗主)
		return true
	# 天劫分支：宗主复用弟子渡劫执行核心（计算渡劫结果 → 突破/受创/陨落/保命替死）
	var 旧寿元上限: int = int(宗主.寿元)
	var 准备: Dictionary = _构建宗主渡劫准备()
	var 通过: bool = 宗主.渡天劫(新境界, 准备)
	if 通过:
		_宗主突破增加寿元(新境界, 旧寿元上限)
		尝试自创功法(宗主)
		_加推演条目("【宗主】渡%s 功成，晋%s！" % [str(宗主.渡劫详情.get("天劫名", "")), 新境界], "宗主", "高")
	else:
		# 受创/陨落：_渡天劫 已重置 修炼进度=0 并设 受伤剩余；若真陨落(无保命)则触发传承
		if str(宗主.状态) == "陨落":
			宗主传承触发中 = true
			_加推演条目("【宗主】渡劫陨落！请选择传承方式（转世重修/传位弟子）", "宗主", "高")
	return 通过

## E：宗主突破境界时增加寿元上限
## 旧上限：调用方传入突破前寿元上限。天劫路径下 突破() 已改写 宗主.寿元，
## 若仍读 宗主.寿元 作基准则「新增=0」、寿元增益归零，故必须传快照。
func _宗主突破增加寿元(新境界: String, 旧上限: int = 0) -> void:
	var 寿元表: Dictionary = {"练气": 80, "筑基": 200, "金丹": 500, "元婴": 1200, "化神": 2500, "炼虚": 5000}
	var 基准: int = 旧上限 if 旧上限 > 0 else int(宗主.寿元)
	if 寿元表.has(新境界):
		var 新增: int = int(寿元表[新境界]) - 基准
		if 新增 > 0:
			宗主剩余寿元 += 新增
			宗主.寿元 = int(寿元表[新境界])   # 上限同步；否则再突破会重复计入同一差额
			_加推演条目("【宗主】突破至%s，寿元增加%d年" % [新境界, 新增], "宗主", "高")

## 构建宗主专属渡劫准备：复用弟子天劫核心四槽，但调用更多宗门资源
##   护阵抗性：护山大阵（宗主为阵主，总是开）
##   护法抗性：长老护法（宗主坐镇，总是开）
##   道具减伤/承伤倍率：渡劫丹药（按玩家预设 渡劫准备配置.道具 消耗库藏灵石）
##   承伤倍率 += 防御雷劫法宝加成（护身符/本命法宝；当前符箓渡劫词条未落地，占位 0）
func _构建宗主渡劫准备() -> Dictionary:
	var 准备: Dictionary = {
		"护阵抗性": 获取护山大阵抗性(),
		"道具减伤": 0.0,
		"护法抗性": 获取护法抗性(),
		"承伤倍率": 1.0,
	}
	# 渡劫丹药：与弟子同池（玩家预设），宗主作为宗门之主可直接动用库藏灵石
	var 道具列表: Array = 渡劫准备配置.get("道具", [])
	if 道具列表.size() > 0:
		var 汇总: Dictionary = Tribulation.汇总道具(道具列表)
		if 灵石 >= int(汇总["灵石"]):
			灵石 -= int(汇总["灵石"])
			准备["道具减伤"] = float(汇总["减伤"])
			准备["承伤倍率"] = 1.0 + float(汇总["成功率加成"])
			_加推演条目("【宗主】渡劫耗灵石%d，动用渡劫丹药×%d" % [int(汇总["灵石"]), 道具列表.size()], "宗主", "中")
	# 防御雷劫法宝：护身符/本命法宝 额外承伤倍率（无现成渡劫字段，占位 0，待符箓/法宝渡劫词条落地回填）
	准备["承伤倍率"] += 宗主法宝渡劫承伤加成()
	return 准备

## 宗主防御雷劫法宝的承伤倍率加成（护身符/本命法宝 的「渡劫」类词条；当前无对应字段 → 0）
## [PLACEHOLDER] 待 S45 符箓/法宝渡劫词条系统落地后回填真实加成
func 宗主法宝渡劫承伤加成() -> float:
	return 0.0

## E：月度推演中检测宗主寿元
func _检测宗主寿元(月: int) -> void:
	if 宗主 == null or 宗主传承触发中:
		return
	# 宗主年龄增长（月=游戏日，360日=1年）
	宗主.年龄 += float(月) / 360.0
	# 剩余寿元减少
	宗主剩余寿元 -= int(月 / 360)
	if 宗主剩余寿元 <= 0:
		宗主剩余寿元 = 0
		宗主传承触发中 = true
		_加推演条目("【宗主】寿元耗尽！请选择传承方式（转世重修/传位弟子）", "宗主", "高")

## E：宗主转世重修（保留记忆和部分修为，从练气重新开始）
func 宗主转世重修() -> Dictionary:
	if not 宗主传承触发中:
		return {"成功": false, "原因": "未触发传承"}
	# 保留部分属性
	var 保留修为: float = float(宗主.修炼进度) * 0.3
	var 保留威望: int = int(宗主威望 * 0.5)
	var 保留技艺: Dictionary = {}
	# 重置宗主
	宗主.境界 = "练气"
	宗主.层级 = 1
	宗主.修炼进度 = 保留修为
	宗主.战力 = 100
	宗主.寿元 = 80
	宗主.年龄 = 16
	宗主.瓶颈打磨值 = 0
	宗主威望 = 保留威望
	宗主剩余寿元 = 80
	宗主转世次数 += 1
	宗主传承触发中 = false
	_加推演条目("【宗主】转世重修！保留%.0f%%修为和%d威望，从练气重新开始（第%d世）" % [保留修为 * 100, 保留威望, 宗主转世次数], "宗主", "高")
	return {"成功": true, "方式": "转世重修", "保留修为": 保留修为, "保留威望": 保留威望, "转世次数": 宗主转世次数}

## E：传位弟子（从弟子中选择新宗主，旧宗主坐化留下传承）
func 宗主传位弟子(新宗主弟子ID: int) -> Dictionary:
	if not 宗主传承触发中:
		return {"成功": false, "原因": "未触发传承"}
	# 查找新宗主
	var 新宗主: Disciple = null
	for d in 弟子列表:
		if d != null and int(d.弟子ID) == 新宗主弟子ID:
			新宗主 = d
			break
	if 新宗主 == null:
		return {"成功": false, "原因": "未找到指定弟子"}
	# 旧宗主坐化，留下传承宝物
	var 传承宝物 = Item.new()
	传承宝物.名称 = "宗主传承玉符"
	传承宝物.类型 = "特殊"
	传承宝物.品阶 = "仙品"
	传承宝物.描述 = "蕴含前任宗主毕生修为感悟，使用后可大幅提升修炼速度"
	宗门库房.append(传承宝物)
	# 旧宗主装备/背包归入宗门
	for it in 宗主.装备.values():
		宗门库房.append(it)
	宗主.装备.clear()
	for it in 宗主.背包:
		宗门库房.append(it)
	宗主.背包.clear()
	# 新宗主继承
	新宗主.身份 = "宗主"
	宗主 = 新宗主
	弟子列表.erase(新宗主)
	宗主剩余寿元 = int(新宗主.寿元)
	宗主传承触发中 = false
	_加推演条目("【宗主】传位于%s！旧宗主坐化，留下传承玉符" % str(新宗主.姓名), "宗主", "高")
	return {"成功": true, "方式": "传位弟子", "新宗主": str(新宗主.姓名), "传承宝物": "宗主传承玉符"}

## E：获取可继承宗主之位的弟子列表（境界最高的前5名）
func 获取继承候选弟子() -> Array:
	var 候选: Array = []
	for d in 弟子列表:
		if d != null and str(d.状态) == "在宗" and str(d.身份) != "宗主":
			候选.append(d)
	# 按境界排序（Godot 4使用自定义排序）
	var 排序后: Array = []
	for d in 候选:
		var 境界值: int = Disciple.境界序.find(str(d.境界))
		排序后.append({"弟子": d, "境界值": 境界值})
	排序后.sort_custom(func(a, b): return a["境界值"] > b["境界值"])
	var 结果: Array = []
	for item in 排序后:
		结果.append(item["弟子"])
	return 结果.slice(0, min(5, 结果.size()))

## F：任命副宗主
func 任命副宗主(弟子ID: int) -> Dictionary:
	var 目标: Disciple = null
	for d in 弟子列表:
		if d != null and int(d.弟子ID) == 弟子ID:
			目标 = d
			break
	if 目标 == null:
		return {"成功": false, "原因": "未找到指定弟子"}
	if str(目标.境界) not in ["金丹", "元婴", "化神", "炼虚"]:
		return {"成功": false, "原因": "副宗主需金丹及以上境界"}
	# 解除旧副宗主
	if 副宗主弟子ID >= 0:
		for d in 弟子列表:
			if d != null and int(d.弟子ID) == 副宗主弟子ID:
				d.身份 = "长老"
				break
	目标.身份 = "副宗主"
	副宗主弟子ID = 弟子ID
	_加推演条目("【管理层】任命%s为副宗主" % str(目标.姓名), "宗门", "中")
	return {"成功": true, "副宗主": str(目标.姓名)}

## F：解除副宗主
func 解除副宗主() -> Dictionary:
	if 副宗主弟子ID < 0:
		return {"成功": false, "原因": "当前无副宗主"}
	for d in 弟子列表:
		if d != null and int(d.弟子ID) == 副宗主弟子ID:
			d.身份 = "长老"
			_加推演条目("【管理层】解除%s副宗主之位" % str(d.姓名), "宗门", "中")
			break
	副宗主弟子ID = -1
	return {"成功": true}

## F：获取副宗主信息
func 获取副宗主() -> Disciple:
	if 副宗主弟子ID < 0:
		return null
	for d in 弟子列表:
		if d != null and int(d.弟子ID) == 副宗主弟子ID:
			return d
	return null

## F：设置代管权能
func 设置代管权能(权能项: String, 允许: bool) -> void:
	if 代管权能.has(权能项):
		代管权能[权能项] = 允许

## F：闭关代管检查（闭关期间调用，判断某事务是否可由副宗主处理）
func 可代管(事务类型: String) -> bool:
	if not 宗主闭关中:
		return true  # 宗主在线，所有事务可处理
	if 副宗主弟子ID < 0:
		return false  # 无副宗主，不可代管
	return bool(代管权能.get(事务类型, false))

## F：添加待处理事件（闭关期间副宗主无法处理的事件）
func 添加待处理事件(事件类型: String, 事件描述: String) -> void:
	代管待处理事件.append({"类型": 事件类型, "描述": 事件描述, "日期": 累计游戏日})
	_加推演条目("【代管】%s（需宗主上线处理）" % 事件描述, "宗门", "高")

## F：获取待处理事件列表（宗主上线时显示）
func 获取待处理事件() -> Array:
	return 代管待处理事件.duplicate()

## F：清空待处理事件（宗主处理完后调用）
func 清空待处理事件() -> void:
	代管待处理事件.clear()

## 修真味：判断弟子是否为天骄
func 是天骄(弟子ID: int) -> bool:
	return 弟子ID in 天骄弟子ID

## 修真味：获取天骄修炼加成
func 获取天骄修炼加成(弟子ID: int) -> float:
	if 弟子ID in 天骄弟子ID:
		return 1.2  # 天骄修炼速度+20%
	return 1.0

## 技能系统：获取所有可学习技能（从CSV读取）
func 获取所有技能() -> Array:
	var 路径 := "res://config/skill_cultivation.csv"
	if not FileAccess.file_exists(路径):
		return []
	var 文件: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		return []
	var 结果: Array = []
	var 首行: bool = true
	while not 文件.eof_reached():
		var 行: String = 文件.get_line().strip_edges()
		if 首行:
			首行 = false
			continue
		if 行 == "":
			continue
		var 列: Array = 行.split(",")
		if 列.size() < 10:
			continue
		结果.append({
			"skill_id": str(列[0]),
			"skill_name": str(列[1]),
			"grade": str(列[2]),
			"sub_grade": str(列[3]),
			"apply_class": str(列[4]),
			"skill_type": str(列[5]),
			"effect_value": str(列[6]),
			"max_level": int(列[7]),
			"unlock_realm": str(列[8]),
			"learn_cost": int(列[9]),
		})
	文件.close()
	return 结果


## 技能系统：获取弟子已学技能
func 获取弟子技能(弟子ID: int) -> Array:
	return 弟子技能字典.get(弟子ID, [])

## 妖兽材料：击杀妖兽掉落（修真世界观：按妖兽境界掉落对应等阶材料）
func 击杀妖兽掉落(妖兽境界: String, 妖兽类型: String = "通用") -> Dictionary:
	var 等阶: String = 妖兽境界等阶.get(妖兽境界, "")
	if 等阶 == "":
		return {"成功": false, "原因": "未知妖兽境界：%s" % 妖兽境界}
	var 掉落: Dictionary = {"内丹": 0, "精血": 0, "骨": 0, "皮": 0, "筋": 0, "爪": 0, "毛": 0}
	# 内丹：60%掉落
	if randf() < 0.6:
		妖兽内丹[等阶] = int(妖兽内丹.get(等阶, 0)) + 1
		掉落["内丹"] = 1
	# 精血：40%掉落
	if randf() < 0.4:
		妖兽精血[等阶] = int(妖兽精血.get(等阶, 0)) + 1
		掉落["精血"] = 1
	# 骨：50%掉落
	if randf() < 0.5:
		妖兽骨[等阶] = int(妖兽骨.get(等阶, 0)) + 1
		掉落["骨"] = 1
	# 皮：70%掉落
	if randf() < 0.7:
		妖兽皮[等阶] = int(妖兽皮.get(等阶, 0)) + 1
		掉落["皮"] = 1
	# 筋：30%掉落
	if randf() < 0.3:
		妖兽筋[等阶] = int(妖兽筋.get(等阶, 0)) + 1
		掉落["筋"] = 1
	# 爪：40%掉落（有爪妖兽）
	if randf() < 0.4:
		妖兽爪[等阶] = int(妖兽爪.get(等阶, 0)) + 1
		掉落["爪"] = 1
	# 毛：80%掉落（有毛妖兽）
	if randf() < 0.8:
		妖兽毛[等阶] = int(妖兽毛.get(等阶, 0)) + 1
		掉落["毛"] = 1
	return {"成功": true, "等阶": 等阶, "掉落": 掉落}

## 妖兽材料：按境界增加内丹/精血
func 增加妖兽材料(妖兽境界: String, 内丹数: int = 1, 精血数: int = 0) -> Dictionary:
	var 等阶: String = 妖兽境界等阶.get(妖兽境界, "")
	if 等阶 == "":
		return {"成功": false, "原因": "未知妖兽境界：%s" % 妖兽境界}
	妖兽内丹[等阶] = int(妖兽内丹.get(等阶, 0)) + 内丹数
	妖兽精血[等阶] = int(妖兽精血.get(等阶, 0)) + 精血数
	return {"成功": true, "等阶": 等阶, "内丹+": 内丹数, "精血+": 精血数}

## 妖兽材料：获取指定等阶内丹数量
func 获取妖兽内丹(等阶: String) -> int:
	return int(妖兽内丹.get(等阶, 0))

## 妖兽材料：获取指定等阶精血数量
func 获取妖兽精血(等阶: String) -> int:
	return int(妖兽精血.get(等阶, 0))

## 技能系统：获取弟子可学习技能（按境界筛选）
func 获取弟子可学技能(弟子ID: int) -> Array:
	var 目标: Disciple = null
	for d in 弟子列表:
		if d != null and int(d.弟子ID) == 弟子ID:
			目标 = d
			break
	if 目标 == null:
		return []
	var 所有技能: Array = 获取所有技能()
	var 已学: Array = 获取弟子技能(弟子ID)
	var 已学ID: Array = []
	for sk in 已学:
		已学ID.append(str(sk.get("skill_id", "")))
	var 结果: Array = []
	for sk in 所有技能:
		if str(sk.get("skill_id", "")) in 已学ID:
			continue
		var 解锁: String = str(sk.get("unlock_realm", ""))
		if str(目标.境界) in 解锁 or 解锁 == "":
			结果.append(sk)
	return 结果.slice(0, min(10, 结果.size()))

## 技能系统：统一领悟检查（修真式：综合性格/道途/六维/心境/道心/履历/灵根/资质）
func _尝试领悟技能(d: Disciple, 场景: String = "瓶颈", 概率加成: float = 0.0) -> bool:
	if d == null:
		return false
	var 可学: Array = 获取弟子可学技能(int(d.弟子ID))
	if 可学.is_empty():
		return false
	# 走火入魔时心魔干扰，难以领悟
	if bool(d.走火入魔):
		return false
	# ===== 基础概率（按场景）=====
	var 概率: float = 0.0
	match 场景:
		"瓶颈":
			概率 = 0.02 + float(d.瓶颈打磨值) * 0.05
		"战斗":
			概率 = 0.05 + 概率加成
		"濒死":
			概率 = 0.20 + 概率加成
		"奇遇":
			概率 = 0.05 + 概率加成
		"闭关":
			概率 = 0.03
	# ===== 六维属性影响（修真世界观：悟性/心性/气运/机缘）=====
	var 悟性值: int = int(d.属性.get("悟性", 50))
	var 心性值: int = int(d.属性.get("心性", 50))
	var 气运值: int = int(d.属性.get("气运", 50))
	var 机缘值: int = int(d.属性.get("机缘", 50))
	概率 *= (0.7 + float(悟性值) / 200.0)  # 悟性50→1.0x，悟性100→1.2x，悟性0→0.7x
	概率 *= (0.8 + float(心性值) / 250.0)  # 心性稳定，领悟不跑偏
	if 场景 in ["奇遇", "濒死"]:
		概率 *= (0.8 + float(气运值) / 200.0)  # 气运深厚者机缘多
		概率 *= (0.8 + float(机缘值) / 200.0)  # 机缘巧合
	# ===== 性格影响（修真世界观：不同性格擅长不同领悟方式）=====
	match str(d.性格):
		"勤奋":
			if 场景 == "瓶颈" or 场景 == "闭关":
				概率 *= 1.3  # 勤奋者苦修易顿悟
		"好斗":
			if 场景 == "战斗" or 场景 == "濒死":
				概率 *= 1.4  # 好斗者战斗中易突破
		"谨慎":
			if 场景 == "濒死":
				概率 *= 0.7  # 谨慎者少涉险，濒死领悟少
		"孤僻":
			if 场景 == "闭关" or 场景 == "瓶颈":
				概率 *= 1.25  # 孤僻者独处易悟道
		"开朗":
			if 场景 == "奇遇":
				概率 *= 1.3  # 开朗者善结缘，奇遇多
		"懒散":
			概率 *= 0.8  # 懒散者修炼不勤，领悟少
		"社交":
			if 场景 == "奇遇":
				概率 *= 1.2  # 社交广，机缘多
	# ===== 道途影响（修真世界观：不同道途对不同类型技能有领悟加成）=====
	var 道途: String = str(d.道途)
	if 道途 != "":
		# 按技能类型匹配道途加成（在选择技能时应用，这里先记下来）
		pass
	# ===== 心境/道心影响（修真世界观：心境圆满、道心坚定者易领悟）=====
	概率 *= (0.85 + float(d.心境) / 400.0)  # 心境60→1.0x
	概率 *= (0.9 + float(d.道心) / 300.0)   # 道心20→0.97x，道心高易悟高阶
	# ===== 灵根/资质影响（修真世界观：根骨佳者领悟快）=====
	var 灵根品阶: String = str(d.灵根品阶)
	var 灵根乘区: float = 1.0
	match 灵根品阶:
		"天品": 灵根乘区 = 1.3
		"极品": 灵根乘区 = 1.2
		"上品": 灵根乘区 = 1.1
		"良品": 灵根乘区 = 1.0
		"凡品": 灵根乘区 = 0.9
	概率 *= 灵根乘区
	# ===== 人生经历影响（修真世界观：阅历丰富者易触类旁通）=====
	var 阅历数: int = d.履历.size()
	if 阅历数 > 10:
		概率 *= 1.1  # 阅历丰富，触类旁通
	# 有奇遇经历者，奇遇领悟加成
	for 履历 in d.履历:
		if "奇遇" in str(履历) and 场景 == "奇遇":
			概率 *= 1.15
			break
	# ===== 受伤状态影响（修真世界观：重伤初愈时对生死有感悟）=====
	if int(d.受伤剩余) > 0 and 场景 == "濒死":
		概率 *= 1.2  # 养伤期间对生死有感悟
	# ===== 上限保护 =====
	概率 = min(0.40, 概率)  # 综合上限40%
	if randf() > 概率:
		return false
	# ===== 技能选择：道途匹配优先（使用游戏实际道途名：道修/体修/法修/御兽师/符箓师/毒师/傀儡师）=====
	var 道途技能偏好: Dictionary = {
		"道修": "攻击",
		"体修": "辅助防御",
		"法修": "攻击",
		"御兽师": "辅助防御",
		"符箓师": "控制",
		"毒师": "控制",
		"傀儡师": "控制",
	}
	var 偏好类型: String = str(道途技能偏好.get(道途, ""))
	if 偏好类型 != "":
		# 优先选匹配道途的技能
		var 匹配技能: Array = []
		var 其他技能: Array = []
		for sk in 可学:
			if str(sk.get("skill_type", "")) == 偏好类型:
				匹配技能.append(sk)
			else:
				其他技能.append(sk)
		if not 匹配技能.is_empty() and randf() < 0.7:
			可学 = 匹配技能
	# 濒死/奇遇时优先领悟高品阶技能
	if 场景 in ["濒死", "奇遇"]:
		可学.sort_custom(func(a, b): return str(a.get("grade", "")) > str(b.get("grade", "")))
	var 技能: Dictionary = 可学[randi() % min(3, 可学.size())]
	var 新技能: Dictionary = {
		"skill_id": str(技能.get("skill_id", "")),
		"skill_name": str(技能.get("skill_name", "")),
		"grade": str(技能.get("grade", "")),
		"skill_type": str(技能.get("skill_type", "")),
		"effect_value": str(技能.get("effect_value", "0")),
		"level": 1,
		"来源": 场景 + "领悟",
	}
	if not 弟子技能字典.has(int(d.弟子ID)):
		弟子技能字典[int(d.弟子ID)] = []
	弟子技能字典[int(d.弟子ID)].append(新技能)
	var 场景描述: Dictionary = {
		"瓶颈": "瓶颈苦修，豁然开朗",
		"战斗": "激战之中，临阵领悟",
		"濒死": "死中求生，绝境顿悟",
		"奇遇": "机缘巧合，悟得真意",
		"闭关": "闭关苦修，心有所悟",
	}
	_加推演条目("【领悟】%s%s，领悟了%s！" % [str(d.姓名), 场景描述.get(场景, "潜心修炼"), str(技能.get("skill_name", ""))], "弟子", "中")
	return true

## 技能系统：月度瓶颈领悟（保留原调用接口）
func _弟子自动领悟技能(d: Disciple) -> void:
	if d == null or str(d.状态) != "在宗":
		return
	# 瓶颈期才可能顿悟
	if float(d.瓶颈打磨值) <= 0:
		return
	_尝试领悟技能(d, "瓶颈")

## 技能系统：弟子AI自动兑换功法（月度推演，按目标/境界驱动）
func _弟子AI自动兑换功法(d: Disciple) -> void:
	if d == null or str(d.状态) != "在宗":
		return
	# 弟子AI：根据目标决定是否兑换功法
	# 目标为"问道"/"避世"的弟子更愿意花贡献点兑换
	var 目标名: String = Goal.弟子目标(d)
	var 兑换意愿: float = 0.3  # 基础意愿
	if 目标名 == "问道":
		兑换意愿 = 0.8
	elif 目标名 == "复仇":
		兑换意愿 = 0.6
	elif 目标名 == "飞升":
		兑换意愿 = 0.7
	elif 目标名 == "避世":
		兑换意愿 = 0.2
	# 性格影响：谨慎型更节省，激进型更愿意投入
	if "谨慎" in str(d.性格):
		兑换意愿 *= 0.7
	if "激进" in str(d.性格):
		兑换意愿 *= 1.3
	# 护道人系统：资源倾斜，有护道人的弟子兑换意愿更高
	if 护道人列表.has(d.弟子ID):
		var 护道人: Dictionary = 护道人列表[d.弟子ID]
		var 护道人等级: String = str(护道人.get("护道人等级", ""))
		if 护道人等级 == "外门护道":
			兑换意愿 *= 1.1
		elif 护道人等级 == "内门护道":
			兑换意愿 *= 1.2
		elif 护道人等级 == "长老护道":
			兑换意愿 *= 1.3
		elif 护道人等级 == "太上护道":
			兑换意愿 *= 1.5
	if randf() > 兑换意愿:
		return
	# 查找可兑换的技能（优先兑换下一阶的技能）
	var 可学: Array = 获取弟子可学技能(int(d.弟子ID))
	if 可学.is_empty():
		return
	# 按品阶排序，优先兑换低阶（先打基础）
	var 品阶序: Dictionary = {"凡品": 0, "灵品": 1, "宝品": 2, "仙品": 3, "道阶": 4}
	可学.sort_custom(func(a, b): return 品阶序.get(str(a.get("grade", "凡品")), 0) < 品阶序.get(str(b.get("grade", "凡品")), 0))
	# 依次尝试兑换：规则（进阶限制/扣贡献/写字典/纪事）全部由单一真源 藏经阁兑换技能 负责
	for 技能 in 可学:
		var 结果: Dictionary = 藏经阁兑换技能(int(d.弟子ID), str(技能.get("skill_id", "")), "自行兑换")
		if bool(结果.get("成功", false)):
			break
		# 贡献点不足：后续技能按品阶升序只会更贵，直接放弃
		if str(结果.get("原因", "")).begins_with("贡献点不足"):
			break



## 技能系统：藏经阁兑换技能（手动选弟子，花贡献点）
func 藏经阁兑换技能(弟子ID: int, 技能ID: String, 来源: String = "藏经阁兑换") -> Dictionary:
	var 目标: Disciple = null
	for d in 弟子列表:
		if d != null and int(d.弟子ID) == 弟子ID:
			目标 = d
			break
	if 目标 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 已学: Array = 获取弟子技能(弟子ID)
	for sk in 已学:
		if str(sk.get("skill_id", "")) == 技能ID:
			return {"成功": false, "原因": "已学会该技能"}
	var 所有技能: Array = 获取所有技能()
	var 技能配置: Dictionary = {}
	for sk in 所有技能:
		if str(sk.get("skill_id", "")) == 技能ID:
			技能配置 = sk
			break
	if 技能配置.is_empty():
		return {"成功": false, "原因": "技能不存在"}
	var 消耗: int = int(技能配置.get("learn_cost", 100))
	# 进阶限制（单一真源）：高阶技能须低阶大圆满，AI 自动兑换与手动指派共用同一规则
	var 品阶序: Dictionary = {"凡品": 0, "灵品": 1, "宝品": 2, "仙品": 3, "道阶": 4}
	var 品阶: int = 品阶序.get(str(技能配置.get("grade", "凡品")), 0)
	if 品阶 > 0:
		var 低阶大圆满: bool = false
		for sk in 已学:
			if 品阶序.get(str(sk.get("grade", "凡品")), 0) == 品阶 - 1:
				if int(sk.get("level", 1)) >= int(技能配置.get("max_level", 9)):
					低阶大圆满 = true
				break
		if not 低阶大圆满:
			return {"成功": false, "原因": "低阶未大圆满，不可修习高阶"}
	if 贡献点 < 消耗:
		return {"成功": false, "原因": "贡献点不足（需%d，当前%d）" % [消耗, 贡献点]}
	贡献点 -= 消耗
	var 新技能: Dictionary = {
		"skill_id": 技能ID,
		"skill_name": str(技能配置.get("skill_name", "")),
		"grade": str(技能配置.get("grade", "")),
		"skill_type": str(技能配置.get("skill_type", "")),
		"effect_value": str(技能配置.get("effect_value", "0")),
		"level": 1,
		"来源": 来源,
	}
	if not 弟子技能字典.has(弟子ID):
		弟子技能字典[弟子ID] = []
	弟子技能字典[弟子ID].append(新技能)
	_加推演条目("【藏经阁】%s在传功长老处兑换习得%s（消耗%d贡献）" % [str(目标.姓名), str(技能配置.get("skill_name", "")), 消耗], "弟子", "中")
	return {"成功": true, "技能": str(技能配置.get("skill_name", "")), "消耗": 消耗}

## 家族外交：获取可联姻的家族列表（非敌对、非已联姻）
func 获取可联姻家族() -> Array:
	if 家族系统 == null:
		return []
	var 玩家家族ID: String = ""
	for d in 弟子列表:
		if d != null and str(d.家族ID) != "":
			玩家家族ID = str(d.家族ID)
			break
	if 玩家家族ID == "":
		return []
	var 结果: Array = []
	for 家族ID in 家族系统.家族列表.keys():
		if 家族ID == 玩家家族ID:
			continue
		var 家族: Dictionary = 家族系统.家族列表[家族ID]
		var 敌对列表: Array = 家族.get("敌对家族", [])
		var 已敌对: bool = false
		for e in 敌对列表:
			if typeof(e) == TYPE_DICTIONARY and e.get("家族ID") == 玩家家族ID:
				已敌对 = true
				break
			elif e == 玩家家族ID:
				已敌对 = true
				break
		if not 已敌对:
			结果.append({"家族ID": 家族ID, "名称": str(家族.get("名", "未知")), "等级": int(家族.get("等级", 1))})
	return 结果.slice(0, min(5, 结果.size()))

## 家族外交：简化发起联姻（自动选择弟子）
func 发起家族联姻(目标家族ID: String) -> Dictionary:
	if 家族系统 == null:
		return {"成功": false, "原因": "家族系统未加载"}
	# 找玩家家族
	var 玩家家族ID: String = ""
	var 操作者: Disciple = null
	for d in 弟子列表:
		if d != null and str(d.家族ID) != "":
			玩家家族ID = str(d.家族ID)
			if str(d.家族职位) in ["老祖", "长老"]:
				操作者 = d
				break
	if 玩家家族ID == "":
		return {"成功": false, "原因": "宗门尚无家族"}
	if 操作者 == null:
		return {"成功": false, "原因": "需要家族老祖或长老发起"}
	# 找双方未婚弟子
	var 弟子1: Disciple = null
	var 弟子2: Disciple = null
	for d in 弟子列表:
		if d != null and str(d.家族ID) == 玩家家族ID and str(d.状态) == "在宗":
			弟子1 = d
			break
	# 目标家族的弟子（从全局弟子列表找）
	for d in 弟子列表:
		if d != null and str(d.家族ID) == 目标家族ID:
			弟子2 = d
			break
	if 弟子1 == null or 弟子2 == null:
		return {"成功": false, "原因": "双方需各有一名弟子"}
	return 家族系统.家族联姻(玩家家族ID, 目标家族ID, 弟子1, 弟子2, 操作者)

## 家族外交：简化发起结仇
func 发起家族结仇(目标家族ID: String, 原因: String = "利益冲突") -> Dictionary:
	if 家族系统 == null:
		return {"成功": false, "原因": "家族系统未加载"}
	var 玩家家族ID: String = ""
	var 操作者: Disciple = null
	for d in 弟子列表:
		if d != null and str(d.家族ID) != "":
			玩家家族ID = str(d.家族ID)
			if str(d.家族职位) in ["老祖", "长老"]:
				操作者 = d
				break
	if 玩家家族ID == "":
		return {"成功": false, "原因": "宗门尚无家族"}
	if 操作者 == null:
		return {"成功": false, "原因": "需要家族老祖或长老发起"}
	return 家族系统.家族结仇(玩家家族ID, 目标家族ID, 原因, 操作者)

## F：获取可任命副宗主的弟子列表（金丹及以上）
func 获取副宗主候选() -> Array:
	var 候选: Array = []
	for d in 弟子列表:
		if d != null and str(d.状态) == "在宗" and str(d.身份) != "宗主":
			if str(d.境界) in ["金丹", "元婴", "化神", "炼虚"]:
				候选.append(d)
	return 候选.slice(0, min(10, 候选.size()))
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
		if not d.is_empty() and (渠道 == "" or str(d.get("channel") if "channel" in d else "") == 渠道):
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
# 取宗主头像裁切参数（缺省返回当前选中头像），返回 {cx, cy, s} 比例坐标。
func 取宗主头像裁切(头像id: String = "") -> Dictionary:
	var id: String = 头像id
	if id.is_empty():
		id = 宗主头像
	var 裁切: Dictionary = 宗主头像裁切.get(id, {})
	if 裁切.is_empty():
		return {"cx": 0.5, "cy": 0.325, "s": 0.55}
	return 裁切

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

# ============ 性别自适应文案系统 ============
# 根据宗主性别返回合适的称呼，避免对女宗主使用男性对白

## 宗主第三人称代词（他/她）
func 宗主第三人称() -> String:
	return "她" if 宗主性别 == "女" else "他"

## 宗主配偶称呼（妻子/丈夫）
func 宗主配偶称呼() -> String:
	return "丈夫" if 宗主性别 == "女" else "妻子"

## 宗主婚娶文案（娶妻/嫁夫）
func 宗主婚娶文案() -> String:
	return "嫁夫" if 宗主性别 == "女" else "娶妻"

## 宗主婚娶动词（娶/嫁）
func 宗主婚娶动词() -> String:
	return "嫁" if 宗主性别 == "女" else "娶"

## 宗主尊称（先生/夫人）
func 宗主尊称() -> String:
	return "夫人" if 宗主性别 == "女" else "先生"

## 宗主自称（本座/本宗主，中性，无需区分）
func 宗主自称() -> String:
	return "本宗主"

## 随机化身姓名（根据性别，扩充名字池）
func _随机化身姓名_按性别(性别: String) -> String:
	var 姓氏: Array = ["李", "王", "张", "刘", "陈", "杨", "赵", "黄", "周", "吴", "徐", "孙", "胡", "朱", "高", "林", "何", "郭", "马", "罗", "梁", "宋", "郑", "谢", "韩", "唐", "冯", "于", "董", "萧", "程", "曹", "袁", "邓", "许", "傅", "沈", "曾", "彭", "吕"]
	var 男名: Array = [
		"青云", "逸尘", "玄霜", "墨白", "惊鸿", "逐月", "凌风", "踏雪", "听雨", "观澜",
		"怀瑾", "握瑜", "知行", "守一", "归元", "清虚", "抱朴", "见素", "忘机", "无咎",
		"苍穹", "破晓", "斩月", "焚天", "裂地", "追风", "逐日", "摘星", "揽月", "吞云",
		"问天", "求道", "悟真", "修缘", "炼心", "铸魂", "凝魄", "化神", "返虚", "合道",
		"长青", "不老", "长生", "永存", "不灭", "不朽", "永恒", "无极", "太极", "洪荒"
	]
	var 女名: Array = [
		"清雪", "语嫣", "芷若", "梦瑶", "诗涵", "雅琴", "素心", "冰心", "紫烟", "青霞",
		"若兰", "惜春", "慕雪", "吟霜", "弄玉", "飞凤", "翠羽", "红绡", "碧痕", "白露",
		"芙蓉", "牡丹", "芍药", "海棠", "玫瑰", "茉莉", "丁香", "水仙", "莲花", "梅花",
		"嫦娥", "织女", "麻姑", "玄女", "瑶姬", "洛神", "湘妃", "娥皇", "女英", "褒姒",
		"倾城", "倾国", "绝代", "无双", "绝世", "惊艳", "绝美", "绝色", "天香", "国色"
	]
	var 名字: Array = 女名 if 性别 == "女" else 男名
	return 姓氏.pick_random() + 名字.pick_random()

# 按性别取头像列表（不传性别=全部：
func 宗主头像列表(性别: String = "") -> Array:

	var out: Array = []
	for d in 宗主头像目录:
		var g: String = d.get("gender", "")
		if 性别 == "" or g == 性别:
			out.append(d)
	return out
# 取某性别首个解锁的初始头像（创建页默认选中 / 旧档兼容：
func 默认解锁头像(性别: String) -> Dictionary:

	for d in 宗主头像目录:
		var g: String = d.get("gender", "")
		var cat: String = d.get("category", "")
		var unlocked: bool = d.get("unlocked", false)
		if g == 性别 and cat == "initial" and unlocked:
			return d
	return {}
# 招收一名弟子（内部/自动用）
func 招收弟子() -> Disciple:

	var d := Disciple.new()
	# === 多种族修炼体系 P0：随机决定弟子种族 ===
	_随机弟子种族(d)
	# === S1 ：-B：新弟子道号简化生成（[PLACEHOLDER] 简化版：外：辈分字派[0]+单字：==
	_确保字派_S1()
	d.辈分序= 0   # 默认开山第1：
	if d.身份 == "外门" and not 辈分字派.is_empty():
		d.道号 = 辈分字派[0] + (d.姓名.left(1) if d.姓名.length() > 0 else "")
	# 其余阶位道号暂留：""（玩家可改）；[PLACEHOLDER] 命名规则：GDD §：2
	# 初始化弟子战力（根据境界、资质、灵根、道途等因素动态计算）
	d.战力 = d.计算战力()
	# 修真味：天骄判定（灵根≥极品 + 资质≥优秀 → 5%概率天骄）
	if str(d.灵根品阶) in ["极品", "天品"] and str(d.资质) in ["优秀", "绝顶", "妖孽"]:
		if randf() < 0.05:
			天骄弟子ID.append(int(d.弟子ID))
			_加推演条目("【天骄】%s天生异象，灵根资质绝世，乃万年难遇之天骄！" % str(d.姓名), "弟子", "高")
	弟子列表.append(d)
	# 更新成就统计：累计招募弟子数
	累计招募弟子数 += 1
	_复检成就()  # 成就检测：弟子数量相关成就
	弟子变动.emit()
	return d

# ===== 多种族修炼体系 P0：随机弟子种族 =====
func _随机弟子种族(d: Disciple) -> void:
	# 根据宗门等级决定可招收种族
	var 宗门等级: int = 门派等级  # 修复：使用实际门派等级，而非硬编码1
	var 可招收种族: Array = ["人族"]
	if 宗门等级 >= 2:
		可招收种族.append("妖族")
		可招收种族.append("灵兽族")
	if 宗门等级 >= 3:
		可招收种族.append("鬼族")
		# 魔族需要业力阈值
		if 业力 > 100 or 阵营声望系统.阵营声望.get("fz_mo", 0) > 50:
			可招收种族.append("魔族")
	if 宗门等级 >= 4:
		# 龙族稀有，概率极低
		if randf() < 0.005:
			可招收种族.append("龙族")
	
	# 按概率选择种族
	var 种族概率: Dictionary = {
		"人族": 0.7,
		"妖族": 0.1,
		"灵兽族": 0.08,
		"鬼族": 0.05,
		"魔族": 0.05,
		"龙族": 0.02
	}
	var 选中种族: String = "人族"
	var rand: float = randf()
	var 累计概率: float = 0.0
	for 种族 in 可招收种族:
		累计概率 += 种族概率.get(种族, 0.1)
		if rand < 累计概率:
			选中种族 = 种族
			break
	
	d.种族 = 选中种族
	# 设置种族细分
	match 选中种族:
		"妖族":
			var 细分列表: Array = ["走兽", "飞禽", "鳞甲", "植物"]
			d.种族细分 = 细分列表[randi() % 细分列表.size()]
			d.化形状态 = "未化形"
			d.当前形态 = "本体"
		"魔族":
			var 细分列表: Array = ["血魔", "心魔", "天魔"]
			d.种族细分 = 细分列表[randi() % 细分列表.size()]
			d.当前形态 = "本体"
		"鬼族":
			var 细分列表: Array = ["厉鬼", "鬼将", "鬼帝"]
			d.种族细分 = 细分列表[randi() % 细分列表.size()]
			d.当前形态 = "本体"
		"龙族":
			var 细分列表: Array = ["蛟龙", "应龙", "真龙"]
			d.种族细分 = 细分列表[randi() % 细分列表.size()]
			d.化形状态 = "未化形"
			d.当前形态 = "本体"
		"灵兽族":
			var 细分列表: Array = ["瑞兽", "凶兽", "异兽"]
			d.种族细分 = 细分列表[randi() % 细分列表.size()]
			d.当前形态 = "本体"
		_:
			d.种族细分 = ""
			d.当前形态 = "人形"
	
	# 初始化种族天赋
	d.种族天赋 = [d.获取种族天赋().duplicate()]
	# 重新计算修炼速度（考虑种族系数）
	d.基础修炼速度 = d._基础修炼速度值()
	d.修炼速度 = d.基础修炼速度 * d.总修炼速度倍率()

# ===== 多种族修炼体系 P1：种族月度推进 =====
func _种族月度推进() -> void:
	var 化形事件: Array = []
	var 走火入魔事件: Array = []
	var 龙族传承事件: Array = []
	
	for d in 弟子列表:
		if d == null or not (d is Disciple):
			continue
		if d.状态 != "在宗":
			continue
		
		match d.种族:
			"妖族":
				# 妖族化形进度推进
				var 旧进度: float = d.化形进度
				d.月度推进化形()
				# 金丹圆满且化形进度满时自动尝试化形
				if d.可以化形() and d.化形进度 >= 100:
					var 结果: Dictionary = d.尝试化形()
					if bool(结果.get("成功", false)):
						化形事件.append(str(结果.get("消息", "")))
			"魔族":
				# 魔族心魔/业力推进
				var 旧走火: bool = d.走火入魔
				d.月度推进魔族()
				if not 旧走火 and d.走火入魔:
					走火入魔事件.append("⚠ %s走火入魔！修炼速度下降，攻击提升但防御降低。" % d.姓名)
				elif 旧走火 and not d.走火入魔:
					走火入魔事件.append("✓ %s走火入魔已化解，恢复正常。" % d.姓名)
			"鬼族":
				# 鬼族阴气/阳气抗性推进
				d.月度推进鬼族()
			"龙族":
				# 龙族龙珠/传承推进
				var 旧传承: String = d.龙族传承
				d.月度推进龙族()
				if 旧传承 == "" and d.龙族传承 != "":
					龙族传承事件.append("★ %s觉醒%s！" % [d.姓名, d.龙族传承])
	
	# 添加推演条目
	for 事件 in 化形事件:
		_加推演条目(事件, "妖族化形", "高")
	for 事件 in 走火入魔事件:
		_加推演条目(事件, "魔族心魔", "高")
	for 事件 in 龙族传承事件:
		_加推演条目(事件, "龙族传承", "高")
	# P2 契约灵兽月度推进（亲密度增长/战力提升）
	_月度推进契约灵兽()
	# 灵兽繁殖月度推进（幼崽出生）
	_月度推进灵兽繁殖()
	# P3 种族融合与冲突/通婚/稀有种族事件/种族关系恢复
	_月度种族推进_P3()
	# 拟真NPC系统 P0：弟子日常互动（基于需求/性格/情绪）
	_月度弟子日常互动()
	# 派系与权力斗争系统 P0：月度派系更新
	_月度派系更新()
	# 派系与权力斗争系统 P1：月度权力斗争推演
	_月度权力斗争推演()
	# 派系与权力斗争系统 P2：月度玩家管理推演
	_月度玩家管理推演()
	# 派系与权力斗争系统 P3：月度派系事件触发
	_月度派系事件触发()
	# 派系与权力斗争系统 P4：月度派系系统融入
	_月度派系系统融入()
	# 通婚与子嗣系统：月度通婚检查/生育检查/子嗣成长
	_月度通婚生育检查()

# ===== 多种族修炼体系 P2：契约灵兽系统 =====
## 获取契约灵兽数量上限（宗门等级×2）
func 获取契约灵兽上限() -> int:
	# TODO: 从宗门等级获取，初始4
	return 契约灵兽上限

## 检查是否可以契约灵兽
func 可以契约灵兽() -> bool:
	return 契约灵兽列表.size() < 获取契约灵兽上限()

## 契约灵兽（从灵兽库存契约）
func 契约灵兽(灵兽ID: String, 跟随弟子ID: String = "") -> Dictionary:
	if not 可以契约灵兽():
		return {"成功": false, "因": "契约灵兽已满（上限%d）" % 获取契约灵兽上限()}
	
	# 从灵兽库存查找
	var 灵兽: Beast = null
	for b in 灵兽管理系统.灵兽库存:
		if b != null and str(b.beast_id) == 灵兽ID:
			灵兽 = b
			break
	
	if 灵兽 == null:
		return {"成功": false, "因": "灵兽不存在"}
	
	# 从库存移除
	灵兽管理系统.灵兽库存.erase(灵兽)
	
	# 添加到契约列表
	var 契约: Dictionary = {
		"灵兽ID": 灵兽ID,
		"名称": str(灵兽.name),
		"境界": str(灵兽.realm),
		"战力": int(灵兽.power),
		"跟随弟子ID": 跟随弟子ID,
		"契约时间": 累计游戏日,
		"亲密度": 0
	}
	契约灵兽列表.append(契约)
	
	return {"成功": true, "消息": "成功契约%s！" % str(灵兽.name)}

## 解除契约
func 解除契约灵兽(灵兽ID: String) -> Dictionary:
	for i in range(契约灵兽列表.size()):
		var 契约: Dictionary = 契约灵兽列表[i]
		if str(契约.get("灵兽ID", "")) == 灵兽ID:
			契约灵兽列表.remove_at(i)
			return {"成功": true, "消息": "已解除与%s的契约。" % str(契约.get("名称", ""))}
	return {"成功": false, "因": "未找到该契约灵兽"}

## 设置跟随弟子
func 设置灵兽跟随(灵兽ID: String, 弟子ID: String) -> Dictionary:
	for 契约 in 契约灵兽列表:
		if str(契约.get("灵兽ID", "")) == 灵兽ID:
			契约["跟随弟子ID"] = 弟子ID
			return {"成功": true, "消息": "%s现在跟随%s。" % [str(契约.get("名称", "")), 弟子ID]}
	return {"成功": false, "因": "未找到该契约灵兽"}

## 获取跟随某弟子的灵兽列表
func 获取跟随灵兽(弟子ID: String) -> Array:
	var 列表: Array = []
	for 契约 in 契约灵兽列表:
		if str(契约.get("跟随弟子ID", "")) == 弟子ID:
			列表.append(契约)
	return 列表

## 获取契约灵兽总战力加成
func 获取契约灵兽战力加成() -> float:
	var 加成: float = 0.0
	for 契约 in 契约灵兽列表:
		# 每只契约灵兽提供战力的10%作为宗门加成
		加成 += float(契约.get("战力", 0)) * 0.1
	return 加成

## 月度推进契约灵兽（亲密度增长/战力提升）
func _月度推进契约灵兽() -> void:
	for 契约 in 契约灵兽列表:
		# 亲密度每月+1（跟随弟子时+2）
		var 亲密度增量: int = 1
		if str(契约.get("跟随弟子ID", "")) != "":
			亲密度增量 = 2
		契约["亲密度"] = int(契约.get("亲密度", 0)) + 亲密度增量
		# 亲密度影响战力（每10点亲密度+5%战力）
		var 基础战力: int = int(契约.get("战力", 0))
		var 亲密度加成: float = 1.0 + (int(契约.get("亲密度", 0)) / 10) * 0.05
		契约["当前战力"] = int(基础战力 * 亲密度加成)
	# P2优化：弟子携带的灵兽自动喂养（宗主设置方针，弟子自动执行）
	_月度自动喂养灵兽()
	# §4.12 方针制：门下按「培养方针」自动培养灵兽（宗主定方针，不逐只点）
	_月度自动培养灵兽()

## 月度自动喂养灵兽（弟子根据喂养方针自动喂养自己的灵兽，宗主不亲自喂养）
func _月度自动喂养灵兽() -> void:
	var 喂养成功数: int = 0
	var 总消耗灵草: int = 0
	var 总消耗丹药: int = 0
	var 总消耗内丹: int = 0
	for d in 弟子列表:
		if d == null:
			continue
		# 检查主宠灵兽
		if d.主宠灵兽 != null and d.主宠灵兽 is Beast:
			var 兽: Beast = d.主宠灵兽
			if 兽.契约者ID == "":
				兽.设置契约者(str(d.弟子ID))
			var 结果: Dictionary = 兽.自动喂养(灵兽喂养方针, 累计游戏日)
			if 结果.get("成功", false):
				喂养成功数 += 1
				# 扣除资源（根据食物类型）
				var 食物: String = 结果.get("食物类型", "灵草")
				if 食物 == "灵草":
					总消耗灵草 += 5
				elif 食物 == "丹药":
					总消耗丹药 += 1
				elif 食物 == "妖兽内丹":
					总消耗内丹 += 1
		# 检查副宠灵兽
		if d.副宠灵兽 != null and d.副宠灵兽 is Beast:
			var 兽: Beast = d.副宠灵兽
			if 兽.契约者ID == "":
				兽.设置契约者(str(d.弟子ID))
			var 结果: Dictionary = 兽.自动喂养(灵兽喂养方针, 累计游戏日)
			if 结果.get("成功", false):
				喂养成功数 += 1
				var 食物: String = 结果.get("食物类型", "灵草")
				if 食物 == "灵草":
					总消耗灵草 += 5
				elif 食物 == "丹药":
					总消耗丹药 += 1
				elif 食物 == "妖兽内丹":
					总消耗内丹 += 1
	# 扣除宗门资源
	if 总消耗灵草 > 0:
		灵草 = max(0, 灵草 - 总消耗灵草)
	if 总消耗丹药 > 0:
		_库房移除物品("培元丹", 总消耗丹药)
	if 总消耗内丹 > 0:
		_库房移除物品("妖兽内丹", 总消耗内丹)
	# 记录纪事（每季度记录一次，避免刷屏）
	if 喂养成功数 > 0 and 累计游戏日 % 90 == 0:
		添加纪事("御兽", "自动喂养", "本月门下弟子按【%s】方针自动喂养灵兽%d只，消耗灵草%d株、培元丹%d枚、妖兽内丹%d枚。" % [灵兽喂养方针, 喂养成功数, 总消耗灵草, 总消耗丹药, 总消耗内丹], 1)

## §4.12 月度自动培养灵兽（宗主定方针 → 门下按月执行；纪事按季度写，防刷屏）
func _月度自动培养灵兽() -> void:
	if 灵兽管理系统 == null:
		return
	var 结果: Dictionary = 灵兽管理系统.月度自动培养灵兽()
	if int(结果.get("培养数量", 0)) > 0 and 累计游戏日 % 90 == 0:
		添加纪事("御兽", "自动培养", "%s" % String(结果.get("消息", "")), 1)

# ============ 灵兽繁殖系统（修真世界观：灵兽配对产崽，幼崽继承父母天赋）============
var 繁殖中灵兽: Array = []  # 繁殖中的灵兽 [{父灵兽ID, 母灵兽ID, 开始日, 完成日, 预计品质}]

## 获取可繁殖灵兽列表（契约灵兽，亲密度>=20）
func 获取可繁殖灵兽列表() -> Array:
	var 结果: Array = []
	for 契约 in 契约灵兽列表:
		if int(契约.get("亲密度", 0)) >= 20:
			结果.append(契约)
	return 结果

## 开始灵兽繁殖（选择两只灵兽配对）
func 开始灵兽繁殖(父灵兽ID: String, 母灵兽ID: String) -> Dictionary:
	if 父灵兽ID == 母灵兽ID:
		return {"成功": false, "原因": "不能选择同一只灵兽"}
	# 检查灵兽是否存在
	var 父灵兽: Dictionary = {}
	var 母灵兽: Dictionary = {}
	for 契约 in 契约灵兽列表:
		if str(契约.get("灵兽ID", "")) == 父灵兽ID:
			父灵兽 = 契约
		if str(契约.get("灵兽ID", "")) == 母灵兽ID:
			母灵兽 = 契约
	if 父灵兽.is_empty() or 母灵兽.is_empty():
		return {"成功": false, "原因": "灵兽不存在"}
	if int(父灵兽.get("亲密度", 0)) < 20 or int(母灵兽.get("亲密度", 0)) < 20:
		return {"成功": false, "原因": "灵兽亲密度不足（需>=20）"}
	# 消耗灵石
	var 消耗灵石: int = 500 * max(1, 门派等级)
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足，繁殖需%d灵石" % 消耗灵石}
	灵石 -= 消耗灵石
	# 预计品质（父母境界平均值）
	var 父境界序: int = Disciple.境界序.find(str(父灵兽.get("境界", "练气")))
	var 母境界序: int = Disciple.境界序.find(str(母灵兽.get("境界", "练气")))
	var 平均境界序: int = int((父境界序 + 母境界序) / 2)
	var 预计品质: String = "普通"
	if 平均境界序 >= 8:
		预计品质 = "极品"
	elif 平均境界序 >= 6:
		预计品质 = "上品"
	elif 平均境界序 >= 4:
		预计品质 = "中品"
	# 繁殖时间（30-90游戏日，根据品质）
	var 繁殖日: int = 30 + (8 - min(8, 平均境界序)) * 10
	繁殖中灵兽.append({
		"父灵兽ID": 父灵兽ID,
		"母灵兽ID": 母灵兽ID,
		"父名称": str(父灵兽.get("名称", "")),
		"母名称": str(母灵兽.get("名称", "")),
		"开始日": 累计游戏日,
		"完成日": 累计游戏日 + 繁殖日,
		"预计品质": 预计品质
	})
	添加纪事("庶务", "灵兽繁殖", "%s与%s开始配对，预计%d日后产崽" % [父灵兽.get("名称", ""), 母灵兽.get("名称", ""), 繁殖日], 1)
	return {"成功": true, "繁殖日": 繁殖日, "预计品质": 预计品质}

## 月度推进灵兽繁殖（幼崽出生）
func _月度推进灵兽繁殖() -> void:
	var 完成列表: Array = []
	for 繁殖 in 繁殖中灵兽:
		if 累计游戏日 >= int(繁殖.get("完成日", 0)):
			完成列表.append(繁殖)
	for 繁殖 in 完成列表:
		繁殖中灵兽.erase(繁殖)
		# 生成幼崽（加入灵兽库存）
		var 幼崽名称: String = str(繁殖.get("父名称", "")) + "与" + str(繁殖.get("母名称", "")) + "之崽"
		var 预计品质: String = str(繁殖.get("预计品质", "普通"))
		# 简化：直接添加到契约灵兽列表（或灵兽库存）
		var 幼崽契约: Dictionary = {
			"灵兽ID": "幼崽_" + str(randi()),
			"名称": 幼崽名称,
			"境界": "练气",
			"战力": 50,
			"跟随弟子ID": "",
			"契约时间": 累计游戏日,
			"亲密度": 0,
			"品质": 预计品质
		}
		契约灵兽列表.append(幼崽契约)
		添加纪事("庶务", "灵兽产崽", "%s产下幼崽，品质%s" % [繁殖.get("母名称", ""), 预计品质], 2)
		_加推演条目("【灵兽繁殖】%s产下幼崽，品质%s，宗门灵兽又添新丁。" % [繁殖.get("母名称", ""), 预计品质], ET_SECT, PRIO_NORMAL, {})

# ===== 多种族修炼体系 P2：种族天赋系统 =====
## 获取种族细分天赋配置

# ===== 多种族修炼体系（已拆分到race_system.gd，此处为转发函数）=====
func 获取种族天赋配置(种族: String, 细分: String):
	return 种族系统.获取种族天赋配置(种族, 细分)
func 获取种族组队加成(队伍种族列表: Array):
	return 种族系统.获取种族组队加成(队伍种族列表)
func 计算天劫准备成功率(基础成功率: float, 准备方式列表: Array):
	return 种族系统.计算天劫准备成功率(基础成功率, 准备方式列表)
func 执行天劫准备(弟子: Disciple, 准备方式列表: Array):
	return 种族系统.执行天劫准备(弟子, 准备方式列表)
func _初始化种族关系():
	种族系统._初始化种族关系()
func 获取种族关系(种族1: String, 种族2: String):
	return 种族系统.获取种族关系(种族1, 种族2)
func 修改种族关系(种族1: String, 种族2: String, 增量: int):
	种族系统.修改种族关系(种族1, 种族2, 增量)
func _检查种族冲突():
	return 种族系统._检查种族冲突()
func _处理种族冲突(冲突事件: Array):
	return 种族系统._处理种族冲突(冲突事件)
func _检查种族通婚():
	return 种族系统._检查种族通婚()
func 生成混血后代(父方种族: String, 母方种族: String):
	return 种族系统.生成混血后代(父方种族, 母方种族)
func 设置种族政策(政策: String):
	return 种族系统.设置种族政策(政策)
func 获取种族政策效果():
	return 种族系统.获取种族政策效果()
func 获取政策修炼加成():
	return 种族系统.获取政策修炼加成()
func 获取政策招募概率修正():
	return 种族系统.获取政策招募概率修正()
func 获取种族构成统计():
	return 种族系统.获取种族构成统计()
func 检查种族平衡():
	return 种族系统.检查种族平衡()
func _检查稀有种族事件():
	return 种族系统._检查稀有种族事件()
func 处理稀有种族事件(事件: Dictionary, 接纳: bool):
	return 种族系统.处理稀有种族事件(事件, 接纳)
func _月度种族推进_P3():
	种族系统._月度种族推进_P3()

# ===== 通婚与子嗣系统 =====
## 联姻可行性矩阵（是否可联姻）
const 通婚可行性: Dictionary = {
	"人族-人族": {"可行": true, "概率": 0.20, "条件": {}},
	"人族-妖族": {"可行": true, "概率": 0.10, "条件": {"妖族需化形": true}},
	"人族-魔族": {"可行": true, "概率": 0.08, "条件": {"后代有魔性": true}},
	"人族-鬼族": {"可行": true, "概率": 0.05, "条件": {"需要道具": "阴阳调和丹"}},
	"人族-龙族": {"可行": true, "概率": 0.02, "条件": {"龙族好感度": 80, "宗门声望": 200}},
	"妖族-妖族": {"可行": true, "概率": 0.20, "条件": {}},
	"妖族-魔族": {"可行": true, "概率": 0.08, "条件": {}},
	"妖族-鬼族": {"可行": true, "概率": 0.03, "条件": {"需要道具": "阴魂草"}},
	"妖族-龙族": {"可行": true, "概率": 0.03, "条件": {"龙族好感度": 80}},
	"妖族-灵兽族": {"可行": true, "概率": 0.15, "条件": {}},
	"魔族-魔族": {"可行": true, "概率": 0.20, "条件": {}},
	"魔族-鬼族": {"可行": true, "概率": 0.10, "条件": {}},
	"鬼族-鬼族": {"可行": true, "概率": 0.15, "条件": {}},
	"龙族-龙族": {"可行": true, "概率": 0.10, "条件": {}},
	"灵兽族-灵兽族": {"可行": true, "概率": 0.15, "条件": {}}
}

## 检查两个弟子是否可联姻（基于好感度）

# ===== 通婚和子嗣系统（已拆分到marriage_system.gd，此处为转发函数）=====
func 检查通婚可行性(弟子1: Disciple, 弟子2: Disciple):
	return 通婚子嗣系统.检查通婚可行性(弟子1, 弟子2)
func 执行通婚(弟子1: Disciple, 弟子2: Disciple):
	return 通婚子嗣系统.执行通婚(弟子1, 弟子2)
func 检查生育可行性(父方: Disciple, 母方: Disciple):
	return 通婚子嗣系统.检查生育可行性(父方, 母方)
func 生成子嗣(父方: Disciple, 母方: Disciple):
	return 通婚子嗣系统.生成子嗣(父方, 母方)
func _判定子嗣种族(父方: Disciple, 母方: Disciple):
	return 通婚子嗣系统._判定子嗣种族(父方, 母方)
func _判定子嗣血脉(父方: Disciple, 母方: Disciple, 子嗣种族: String):
	return 通婚子嗣系统._判定子嗣血脉(父方, 母方, 子嗣种族)
func _判定子嗣品质(父方: Disciple, 母方: Disciple):
	return 通婚子嗣系统._判定子嗣品质(父方, 母方)
func _继承天赋(父方: Disciple, 母方: Disciple, 子嗣种族: String):
	return 通婚子嗣系统._继承天赋(父方, 母方, 子嗣种族)
func _继承灵根品阶(父方: Disciple, 母方: Disciple, 品质: String):
	return 通婚子嗣系统._继承灵根品阶(父方, 母方, 品质)
func _继承资质(父方: Disciple, 母方: Disciple, 品质: String):
	return 通婚子嗣系统._继承资质(父方, 母方, 品质)
func _子嗣成长推进():
	通婚子嗣系统._子嗣成长推进()
func _子嗣加入宗门(子嗣: Dictionary):
	return 通婚子嗣系统._子嗣加入宗门(子嗣)
func _月度好感度增长():
	通婚子嗣系统._月度好感度增长()
func _月度检查结成道友():
	通婚子嗣系统._月度检查结成道友()
func _月度通婚生育检查():
	通婚子嗣系统._月度通婚生育检查()

# ============ 时间推演核心 ============
# ============ S0 商店（坊市）：经济消耗出：============
var _坊市缓存: Array = []
func _坊市表() -> Array:

	if _坊市缓存.is_empty():
		for r in DestinyDataLoader._read_csv("res://config/faction_shop.csv"):
			# ★★★ 2026-09-15 列名归一化（**单点修复，全消费点自动受益**）★★★
			# 背景（老大报「坊市价格全是 0、上架判定失效、特惠只剩一件」）：
			#   config/faction_shop.csv 的表头是 `item_id / price`，而坊市**全链路 12 处消费点**
			#   （刷新坊市上架 / 购买坊市物品 / 坊市物品现价 / 获取所有商城商品列表 / 生成商城每日特惠 /
			#     取坊市每日特惠 / main.gd:4855 / page_shop.gd:703,847 …）都按 `shop_id / price_lingjing` 取值
			#   ⇒ 原样透传的结果是：shop_id 恒 ""（上架集里全是空串、`上架.has(sid)` 判断全真或全假）、
			#     价格恒 0（商品卡与特惠卡一律显示 0）。
			# 修法抉择：**在唯一入口补齐别名键**，而不是去改 12 个消费点（改漏一处就留半截 bug，
			#   而且 CSV 的 item_id 另有其它消费者，不能反向改表头）。补键后历史两种写法都能读到值。
			if not r.has("shop_id") and r.has("item_id"):
				r["shop_id"] = r["item_id"]
			if not r.has("price_lingjing") and r.has("price"):
				r["price_lingjing"] = r["price"]
			# ★★★ 2026-09-15（P0-C）约定式图标寻址 —— 同样是**单点补键，零消费点改动** ★★★
			# 背景（老大报「坊市里的图标更放大跟框体一样大吗…」时暴露）：faction_shop.csv 的表头是
			#   item_id/faction/faction_id/item_name/item_type/unlock_reputation/price/description
			#   —— **根本没有 icon 列**。而坊市商品卡的取图点是 `商品.get("icon", "")`
			#   （page_shop.gd:_make_icon_bg 与 _make_daily_special_card），取不到就只画「首字」占位
			#   ⇒ 坊市这一屏（恰是面向低阶弟子的主渠道）整屏无图标，与"图标占满框"的诉求正相反。
			# 修法抉择：**约定式寻址**（文件名 = item_id + "_512"，落 art/icons/shop/），
			#   而不是给 CSV 补一列 icon。理由：
			#     ① 补列 ⇒ 以后每加一件商品都得手工补一列，漏一列就静默掉回占位，pass 不掉；
			#     ② 约定式 ⇒ 「丢图即有图」，且 CSV 表头不受扰动（item_id 另有阵营声望等消费者）。
			#   带 ResourceLoader.exists() 判定 ⇒ 图不在时**不写该键**，消费点自动走占位、
			#   不会触发 load("...") 的 "Resource file not found" 报错。缺图可分批补、不阻塞。
			if not r.has("icon") and r.has("item_id"):
				var 坊市图标: String = "res://art/icons/shop/%s_512.png" % String(r["item_id"])
				if ResourceLoader.exists(坊市图标):
					r["icon"] = 坊市图标
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
		if str(r.get("shop_id") if "shop_id" in r else "") == shop_id:
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
		return {"ok": false, "msg": "灵石不足（需 %d 灵石，%s 声望品级，让利%d%%）" % [折后, 声望等级名[clamp(声望, 0, 声望等级名.size() - 1)], int(round((1.0 - 坊市折扣率()) * 100))]}
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
		var 声望让利: int = int(round((1.0 - 坊市折扣率()) * 100))   # D5：让利% = (10−折数)×10 = (1−折扣率)×100
		var 特惠倍: float = 坊市特惠倍率(shop_id)
		if 特惠倍 != 1.0:
			折扣说明 = "%s让利%d%%·特惠让利%d%%" % [声望等级名[clamp(声望, 0, 声望等级名.size() - 1)], 声望让利, int(round((1.0 - 特惠倍) * 100))]
		else:
			折扣说明 = "%s让利%d%%" % [声望等级名[clamp(声望, 0, 声望等级名.size() - 1)], 声望让利]
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

# ★ 2026-09-15 删除「商城每日特惠」旧链路（变量 商城每日特惠 / 商城每日特惠日期
#   + 生成商城每日特惠 + 获取商城每日特惠）。
#   为什么删：它的唯一消费者是 page_shop 的「推荐」Tab，而该处已改用 取商城特供()；
#   留着即成为死函数（闸门 [35/35] 死函数水位扫描会直接拦）。
#   三条病 + 一处原始 bug 留档，**勿再复活**：
#     ① 数据源 faction_shop.csv 是**阵营声望商店**（灵石计价 + 声望门槛），
#        与「仙缘阁 = 仙玉商城」语义错位 —— 所以会冒出「远古传承玉简」这种阵营至高道具；
#     ② 按 `shop_id` 去重，而该表列名是 `item_id` ⇒ 去重键恒 ""；
#        且 `已选商品[商品ID] = true` 被**缩进到 continue 之后**、永不执行 ⇒ 去重实际完全失效；
#     ③ 读 `price_lingjing`，而该表列名是 `price` ⇒ 价格恒 0（老大看到的"钻石 0"）。
#   替代实现：Game.取商城特供() → XianyuShop.取每日特供()（自带 icon/price，见其上方长注释）。
#   注：本链路从未进入存档（save/load 字典里没有这两个变量），故删除不影响任何既有存档。

# ★★★ 2026-09-15 新增：仙缘阁「每日特供」（取代 获取商城每日特惠() 这条错位链路）★★★
# 老大原话：「最上方的远古传承玉简怎么一直置顶着，是特价商品吗？能用更好看的方式展示吗？
#           能增加更多特价物品更好了，可以花(仙玉)刷新。现在没有图标，只有一个钻石样式的 emoji」
# 原链路三条病（逐条实测，长版机理见 xianyu_shop_library.gd 取每日特供() 上方注释）：
#   ① 只出一件 —— 它按 shop_id 去重，而 faction_shop.csv 列名是 item_id ⇒ 去重键恒 ""，
#      第二件起全部被 continue（这正是老大看到的「一直置顶」）；
#   ② 价格恒 0 —— 它读 price_lingjing，而该表列名是 price（老大看到的「◇ 0」）；
#   ③ 数据源语义错位 —— faction_shop.csv 是**阵营声望商店**（灵石计价 + 声望门槛），
#      不该长在「仙缘阁 = 仙玉商城」的推荐位上，所以会冒出「远古传承玉简」这种阵营至高道具。
# 现改为从 XianyuShop.商品库 取 —— 该库每条自带 icon/price/original_price/desc，
# 图标与价格天然齐备，不再依赖任何字段兼容。抽样在 XianyuShop.取每日特供()。
const 商城特供数量: int = 4
const 商城特供刷新价: int = 5   # 仙玉/次 —— 与 付费单价["坊市刷新"]=5 对齐，全局只留一个"刷新价"心智
var 商城特供_偏移: int = 0      # 「仙玉刷新」递增。**不存档**：属当日消耗品，重进游戏回到当日首批

func 取商城特供() -> Array:
	return XianyuShop.取每日特供(累计游戏日, 商城特供数量, 商城特供_偏移)

## 仙玉刷新每日特供：扣仙玉 → 偏移 +1 → 换一批（确定性抽样，同偏移必得同结果，可复现）
## 复用既有 消耗仙玉_付费（内部优先扣非绑定仙玉），不新增任何付费字段、不触碰存档结构。
func 仙玉刷新商城特供() -> Dictionary:
	if not 消耗仙玉_付费(商城特供刷新价):
		return {"ok": false, "msg": "仙玉不足（需 %d 仙玉）" % 商城特供刷新价}
	商城特供_偏移 += 1
	return {"ok": true, "msg": "仙缘阁已为你重新备货"}

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
	# ★ 2026-09-15 修（老大：「坊市收购页每日特惠为空，只有 0 灵石·特惠73折」）：
	#   上架集可能来自旧存档（fs_list 早于列名归一化，含空串 / 已下架 id）⇒ 旧写法直接拿它
	#   抽样，特惠卡按 shop_id 查 `_坊市表()` 必然查空 → 物品名「—」、现价 0。
	#   现先按现行商品表过滤有效 id，过滤后为空则退回全表抽样（特惠永不空）。
	var 有效: Array = []
	for r in _坊市表():
		有效.append(str(r.get("shop_id", "")))
	var 列表: Array = []
	for sid in 坊市上架集:
		if 有效.has(str(sid)) and not 列表.has(str(sid)):
			列表.append(str(sid))
	if 列表.is_empty():
		列表 = 有效.duplicate()
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
		if str(t.get("shop_id") if "shop_id" in t else "") == shop_id:
			return float(t.get("倍率") if "倍率" in t else 1.0)
	return 1.0
# 坊市商品现价（声望折扣+ 行情浮动 + 每日特惠，三折叠加）：
# 同时：UI 展示：购买坊市物品 扣费，杜绝「显示价 ：实扣价」漂移：
func 坊市物品现价(shop_id: String) -> int:

	var 行: Dictionary = {}
	for r in _坊市表():
		if str(r.get("shop_id") if "shop_id" in r else "") == shop_id:
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
		return {"ok": false, "msg": "法旨功绩不足（当前第%d重）" % 战令_等级}
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
		明细.append("灵玉+%d" % v)
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
	return {"ok": true, "msg": "%s 第 %d 重 奖励：%s" % [轨道, 等级, "·".join(明细)]}
# === 本地道友系统：026-08-21 收尾；纯本地，无服务端）===

# ===== 道友系统（已拆分到friend_system.gd，此处为转发函数）=====
func 道友列表():
	return 道友系统.道友列表()
func 道友消息():
	return 道友系统.道友消息()
func 添加道友(名字: String, 境界: String = "筑基初期", 在线: bool = true):
	return 道友系统.添加道友(名字, 境界, 在线)
func 删除道友(名字: String):
	return 道友系统.删除道友(名字)
func 发送道友消息(名字: String, 内容: String):
	return 道友系统.发送道友消息(名字, 内容)
func 获取所有道友列表():
	return 道友系统.获取所有道友列表()
func 给道友送礼(名字: String, 礼物价值: int = 100):
	return 道友系统.给道友送礼(名字, 礼物价值)
func 获取道友好感度等级(好感度: int):
	return 道友系统.获取道友好感度等级(好感度)
func 道友结义(名字: String):
	return 道友系统.道友结义(名字)
func 缔结道侣(弟子IDA: int, 弟子IDB: int):
	return 道友系统.缔结道侣(弟子IDA, 弟子IDB)
func 道友拜访(名字: String):
	return 道友系统.道友拜访(名字)
func 道友切磋(名字: String):
	return 道友系统.道友切磋(名字)
func 获取社交统计():
	return 道友系统.获取社交统计()
func 一键给所有道友送礼(礼物价值: int = 100):
	return 道友系统.一键给所有道友送礼(礼物价值)
func 与道友论道(名字: String):
	return 道友系统.与道友论道(名字)
func 拜访道友(名字: String):
	return 道友系统.拜访道友(名字)
func 与道友切磋(名字: String):
	return 道友系统.与道友切磋(名字)
func 与道友结义(名字: String):
	return 道友系统.与道友结义(名字)
func 获取结义加成():
	return 道友系统.获取结义加成()
func 重置道友每日次数():
	道友系统.重置道友每日次数()

func 整理库房() -> Array:

	var 排序: Array = []
	for it in 宗门库房:
		排序.append(it)
	排序.sort_custom(_整理比较)
	宗门库房 = 排序
	if has_method("save_game"):
		save_game()
	return 排序
const _整理品阶表: Array = ["道阶", "仙阶", "圣阶", "王阶", "宝阶", "灵阶", "凡阶"]
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
	var 纹: int = 0
	var 符纹: int = 0
	var 品级: String = "中品"
	var 年份: int = 0
	if it is Object:
		var v = it.get("品阶")
		if v != null:
			阶 = str(v)
		var mv: Variant = it.get("丹纹")
		var fv: Variant = it.get("符纹")
		var pv: Variant = it.get("品级")
		if pv != null:
			品级 = str(pv)
		if mv != null:
			纹 = int(mv)
		if fv != null:
			符纹 = int(fv)
		var yv: Variant = it.get("年份")
		if yv != null:
			年份 = int(yv)
	var 价: int = int(round(float(表.get(阶, 10)) * 丹纹售价倍率(纹) * 符纹售价倍率(阶, 符纹) * float(丹品级配置(品级).get("price_scale", 1.0))))
	# S41 丹词条·售价倍率（仅丹药带丹词条，灵材年份路径不冲突）
	if it is Object:
		var _丹词 = 丹词条聚合(it.丹词条)
		var _ps: float = float(_丹词["售价"])
		if _ps > 0.0:
			价 = int(round(float(价) * (1.0 + _ps)))
	# S40 灵植年份价值倍率：仅对带年份的灵材生效（普通材料/装备年份=0 → ×1.0 零影响）
	if 年份 > 0:
		价 = int(round(float(价) * 灵植年份价值系数(年份)))
	return 价
# === 邮件系统（已拆分到mail_system.gd，此处为转发函数）===
func 取邮件列表() -> Array:
	return 邮件系统.取邮件列表()
func 标记邮件已读(idx: int) -> void:
	邮件系统.标记邮件已读(idx)
func 邮件全部已读() -> void:
	邮件系统.邮件全部已读()
func 领取邮件(idx: int) -> Dictionary:
	return 邮件系统.领取邮件(idx)
func _种子化初始邮() -> void:
	邮件系统._种子化初始邮()

# ============ 炼丹炼器封装系统（已拆分到alchemy_forge_system.gd，此处为转发函数）============
func 执行炼丹(丹方ID: String, 丹堂等级: int = 1) -> Dictionary:
	return 炼丹炼器系统.执行炼丹(丹方ID, 丹堂等级)
func 获取炼器等级() -> int:
	return 炼丹炼器系统.获取炼器等级()
func 获取炼器加成() -> Dictionary:
	return 炼丹炼器系统.获取炼器加成()
func 增加炼器经验(数量: int) -> void:
	炼丹炼器系统.增加炼器经验(数量)
func 执行炼器(配方ID: String, 器堂等级: int = 1, 炼器弟子 = null) -> Dictionary:
	return 炼丹炼器系统.执行炼器(配方ID, 器堂等级, 炼器弟子)

# ============ 符箓系统封装（已拆分到talisman_system.gd，此处为转发函数）============
func 执行炼符(符箓ID: String, 符堂等级: int = 1) -> Dictionary:
	return 符箓封装系统.执行炼符(符箓ID, 符堂等级)

# 宗门科技树配置
const 宗门科技树配置: Dictionary = {
	"修炼加速I": {"描述": "所有弟子修炼速度+5%", "效果": {"修炼速度加成": 0.05}, "消耗灵石": 10000, "消耗悟道点": 1000, "前置科技": [], "等级": 1},
	"修炼加速II": {"描述": "所有弟子修炼速度+10%", "效果": {"修炼速度加成": 0.1}, "消耗灵石": 30000, "消耗悟道点": 3000, "前置科技": ["修炼加速I"], "等级": 2},
	"修炼加速III": {"描述": "所有弟子修炼速度+15%", "效果": {"修炼速度加成": 0.15}, "消耗灵石": 80000, "消耗悟道点": 8000, "前置科技": ["修炼加速II"], "等级": 3},
	"战力强化I": {"描述": "所有弟子道行+10%", "效果": {"战力加成": 0.1}, "消耗灵石": 10000, "消耗悟道点": 1000, "前置科技": [], "等级": 1},
	"战力强化II": {"描述": "所有弟子道行+20%", "效果": {"战力加成": 0.2}, "消耗灵石": 30000, "消耗悟道点": 3000, "前置科技": ["战力强化I"], "等级": 2},
	"战力强化III": {"描述": "所有弟子道行+30%", "效果": {"战力加成": 0.3}, "消耗灵石": 80000, "消耗悟道点": 8000, "前置科技": ["战力强化II"], "等级": 3},
	"资源增产I": {"描述": "所有资源产出+10%", "效果": {"产出加成": 0.1}, "消耗灵石": 10000, "消耗悟道点": 1000, "前置科技": [], "等级": 1},
	"资源增产II": {"描述": "所有资源产出+20%", "效果": {"产出加成": 0.2}, "消耗灵石": 30000, "消耗悟道点": 3000, "前置科技": ["资源增产I"], "等级": 2},
	"资源增产III": {"描述": "所有资源产出+30%", "效果": {"产出加成": 0.3}, "消耗灵石": 80000, "消耗悟道点": 8000, "前置科技": ["资源增产II"], "等级": 3},
	"阵法强化I": {"描述": "所有阵法效果+10%", "效果": {"阵法加成": 0.1}, "消耗灵石": 15000, "消耗悟道点": 1500, "前置科技": [], "等级": 1},
	"阵法强化II": {"描述": "所有阵法效果+20%", "效果": {"阵法加成": 0.2}, "消耗灵石": 45000, "消耗悟道点": 4500, "前置科技": ["阵法强化I"], "等级": 2},
	"丹药强化I": {"描述": "所有丹药效果+10%", "效果": {"丹药加成": 0.1}, "消耗灵石": 15000, "消耗悟道点": 1500, "前置科技": [], "等级": 1},
	"丹药强化II": {"描述": "所有丹药效果+20%", "效果": {"丹药加成": 0.2}, "消耗灵石": 45000, "消耗悟道点": 4500, "前置科技": ["丹药强化I"], "等级": 2},
}

# ============ 宗门科技系统（已拆分到sect_tech_system.gd，此处为转发函数）============
func 研究宗门科技(科技名称: String) -> Dictionary:
	return 宗门科技系统.研究宗门科技(科技名称)
func 获取所有宗门科技列表() -> Array:
	return 宗门科技系统.获取所有宗门科技列表()
func 计算宗门科技总效果() -> Dictionary:
	return 宗门科技系统.计算宗门科技总效果()

# ============ 功法管理系统（已拆分到gongfa_management_system.gd，此处为转发函数）============
func 学习功法(弟子, 功法ID: String) -> Dictionary:
	return 功法管理系统.学习功法(弟子, 功法ID)
func 遗忘功法(弟子, 功法ID: String) -> Dictionary:
	return 功法管理系统.遗忘功法(弟子, 功法ID)
func 升级功法(弟子, 功法ID: String) -> Dictionary:
	return 功法管理系统.升级功法(弟子, 功法ID)
func 获取功法升级消耗(弟子, 功法ID: String) -> Dictionary:
	return 功法管理系统.获取功法升级消耗(弟子, 功法ID)
func 增加功法熟练度(功法ID: String, 熟练度: int = 1) -> void:
	功法管理系统.增加功法熟练度(功法ID, 熟练度)
func 获取功法熟练度(功法ID: String) -> int:
	return 功法管理系统.获取功法熟练度(功法ID)
func 获取功法熟练度排行榜(限制数量: int = 10) -> Array:
	return 功法管理系统.获取功法熟练度排行榜(限制数量)

# 弟子突破配置
# 手动（付费）突破配置：key 必须与 Disciple.境界序 口径一致（不带"期"）。
# 原 key 全带"期"（"化神期"），而实际 d.境界 值为"化神" → `当前境界 not in 弟子突破配置` 恒为真 →
# 弟子突破()/获取弟子突破消耗() 双双成为"恒返回失败"的死代码（2026-09-02 修）。
# 注：自动突破走 Disciple.尝试突破()（推演驱动、免费、走资质天花板/心魔/道心修正）；
#     本表是玩家主动消耗灵石+悟道点的加速通道，两套并行互不冲突。
const 弟子突破配置: Dictionary = {
	"练气": {"下一期": "筑基", "成功率": 0.8, "消耗灵石": 1000, "消耗悟道点": 100, "属性提升": {"修炼速度": 0.05, "战力": 20, "心境": 5}},
	"筑基": {"下一期": "金丹", "成功率": 0.7, "消耗灵石": 3000, "消耗悟道点": 300, "属性提升": {"修炼速度": 0.08, "战力": 50, "心境": 10}},
	"金丹": {"下一期": "元婴", "成功率": 0.6, "消耗灵石": 8000, "消耗悟道点": 800, "属性提升": {"修炼速度": 0.12, "战力": 100, "心境": 15}},
	"元婴": {"下一期": "化神", "成功率": 0.5, "消耗灵石": 20000, "消耗悟道点": 2000, "属性提升": {"修炼速度": 0.18, "战力": 200, "心境": 25}},
	"化神": {"下一期": "炼虚", "成功率": 0.4, "消耗灵石": 50000, "消耗悟道点": 5000, "属性提升": {"修炼速度": 0.25, "战力": 350, "心境": 35}},
	"炼虚": {"下一期": "合体", "成功率": 0.3, "消耗灵石": 120000, "消耗悟道点": 12000, "属性提升": {"修炼速度": 0.35, "战力": 550, "心境": 50}},
	"合体": {"下一期": "大乘", "成功率": 0.2, "消耗灵石": 300000, "消耗悟道点": 30000, "属性提升": {"修炼速度": 0.5, "战力": 800, "心境": 70}},
	"大乘": {"下一期": "渡劫", "成功率": 0.1, "消耗灵石": 800000, "消耗悟道点": 80000, "属性提升": {"修炼速度": 0.7, "战力": 1200, "心境": 100}},
	"渡劫": {"下一期": "仙阶", "成功率": 0.08, "消耗灵石": 2000000, "消耗悟道点": 200000, "属性提升": {"修炼速度": 0.9, "战力": 2000, "心境": 140}},
	"仙阶": {"下一期": "道阶", "成功率": 0.06, "消耗灵石": 5000000, "消耗悟道点": 500000, "属性提升": {"修炼速度": 1.2, "战力": 5000, "心境": 200}},
}

# ============ 天劫渡劫执行层（§11.16 天劫 + §11.26 心魔；数据层见 Tribulation）============
# 两套入口并存：
#   ① 自动渡劫：月度推演 → Disciple.尝试突破(Callable(self, "构建渡劫准备"))，按玩家预设自动备料。
#   ② 手动渡劫：UI → 执行弟子渡劫()，玩家为单个弟子指定丹药/护阵/护法。
# 准备项一律「延迟构建」：仅确认需渡劫时才回调，避免每月为每位弟子重复扣灵石。

## 护山大阵提供的天劫抗性（每级 +3%，实际生效受天劫 array_resist_max 封顶）
func 获取护山大阵抗性() -> float:
	var 等级: int = int(阵法管理系统.阵法等级.get("hushan", 0))
	return 等级 * 0.03

## 长老护法提供的天劫抗性（每名在宗长老/供奉 +5%，上限 15%）
func 获取护法抗性() -> float:
	var n: int = 0
	for d in 弟子列表:
		if d == null or str(d.状态) != "在宗":
			continue
		if str(d.阶位) in ["长老", "供奉"] or str(d.身份) == "长老":
			n += 1
	if n <= 0:
		return 0.0
	return min(0.05 * float(n), 0.15)

## 按玩家预设构建渡劫准备（自动渡劫回调；灵石不足则道具静默不生效，不阻断推演）
## 渡劫者：传入正渡劫的弟子（宗主闭关亦经此路径）；用于 S46 弟子贡献点申请护法/大阵协助
func 构建渡劫准备(渡劫者: Disciple = null) -> Dictionary:
	var 准备: Dictionary = {"护阵抗性": 0.0, "道具减伤": 0.0, "护法抗性": 0.0, "承伤倍率": 1.0}
	if bool(渡劫准备配置.get("用护阵", false)):
		准备["护阵抗性"] = 获取护山大阵抗性()
	if bool(渡劫准备配置.get("用护法", false)):
		准备["护法抗性"] = 获取护法抗性()
	# S46：弟子大能可消耗个人 贡献账户 申请「宗门长老护法」/「护山大阵协助」以增渡劫把握
	# （宗主走 构建宗主渡劫准备 的灵石/法宝路径，不在此扣贡献点）
	if 渡劫者 != null and 渡劫者 != 宗主 and 渡劫者.贡献账户 > 0:
		var 申请护法费: int = 200   # [PLACEHOLDER] 长老护法申请费（贡献点）
		var 申请大阵费: int = 500   # [PLACEHOLDER] 大阵协助申请费（贡献点）
		if 渡劫者.贡献账户 >= 申请护法费 and not bool(渡劫准备配置.get("用护法", false)):
			渡劫者.贡献账户 -= 申请护法费
			准备["护法抗性"] = max(准备["护法抗性"], 获取护法抗性())
			_加推演条目("【观礼】%s 消耗%d贡献点申请长老护法" % [渡劫者.姓名, 申请护法费], "宗门", "低")
		if 渡劫者.贡献账户 >= 申请大阵费 and not bool(渡劫准备配置.get("用护阵", false)):
			渡劫者.贡献账户 -= 申请大阵费
			准备["护阵抗性"] = max(准备["护阵抗性"], 获取护山大阵抗性())
			_加推演条目("【观礼】%s 消耗%d贡献点申请护山大阵协助" % [渡劫者.姓名, 申请大阵费], "宗门", "低")
	var 道具列表: Array = 渡劫准备配置.get("道具", [])
	if 道具列表.size() > 0:
		var 汇总: Dictionary = Tribulation.汇总道具(道具列表)
		if 灵石 >= int(汇总["灵石"]):
			灵石 -= int(汇总["灵石"])
			准备["道具减伤"] = float(汇总["减伤"])
			准备["承伤倍率"] = 1.0 + float(汇总["成功率加成"])
	return 准备

## 玩家手动为指定弟子渡劫（扣灵石 → 结算 → 落地）；返回渡劫明细
func 执行弟子渡劫(弟子ID: int, 道具列表: Array = [], 用护阵: bool = false, 用护法: bool = false) -> Dictionary:
	var 目标弟子 = null
	for d in 弟子列表:
		if d != null and d.弟子ID == 弟子ID:
			目标弟子 = d
			break
	if 目标弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 目标境: String = Tribulation.下一境(目标弟子.境界)
	if 目标境 == "" or not Tribulation.需渡劫(目标境):
		return {"成功": false, "原因": "该境界无需渡劫"}
	if 目标弟子.层数 < 10 or 目标弟子.瓶颈打磨值 < 1.0 or 目标弟子.突破冷却剩余 > 0.0 or 目标弟子.受伤剩余 > 0:
		return {"成功": false, "原因": "未达渡劫条件（需大圆满 + 瓶颈打磨满 + 无冷却 + 未受伤）"}
	var 汇总: Dictionary = Tribulation.汇总道具(道具列表)
	var 花费: int = int(汇总["灵石"])
	if 灵石 < 花费:
		return {"成功": false, "原因": "灵石不足（需%d）" % 花费}
	灵石 -= 花费
	var 准备: Dictionary = {
		"护阵抗性": 获取护山大阵抗性() if 用护阵 else 0.0,
		"护法抗性": 获取护法抗性() if 用护法 else 0.0,
		"道具减伤": float(汇总["减伤"]),
		"承伤倍率": 1.0 + float(汇总["成功率加成"]),
	}
	var 通过: bool = 目标弟子.尝试突破(准备)
	var r: Dictionary = 目标弟子.渡劫详情.duplicate(true)
	r["成功"] = 通过
	return r

## 当前已达渡劫条件的弟子列表（供 UI 展示）
func 取待渡劫弟子列表() -> Array:
	var out: Array = []
	for d in 弟子列表:
		if d == null or str(d.状态) != "在宗":
			continue
		var 目标境: String = Tribulation.下一境(d.境界)
		if 目标境 == "" or not Tribulation.需渡劫(目标境):
			continue
		if d.层数 < 10 or d.瓶颈打磨值 < 1.0 or d.突破冷却剩余 > 0.0 or d.受伤剩余 > 0:
			continue
		var cfg: Dictionary = Tribulation.取天劫配置(目标境)
		out.append({
			"弟子ID": d.弟子ID, "姓名": d.姓名, "当前境": d.境界, "目标境": 目标境,
			"天劫名": str(cfg.get("tribulation_name", "")), "雷数": int(cfg.get("thunder_count", "0")),
			"道心": d.道心, "心境": d.心境, "心魔值": d.心魔值,
		})
	return out

# ============ S46 大能渡劫观礼系统 ============
# 设计（仿真修仙）：大能(元婴+)渡劫时，观礼者获得感悟（道心+限时修炼加速buff+低概率随机领悟）；
# 渡劫受创/陨落时，观礼者承担雷劫余波（心魔/轻伤）。弟子自动遴选观礼名单；宗主由玩家 UI 勾选。
# 外部观礼者（友好/同盟/其他玩家）仅产生外交增益，无 Disciple buff。
# 所有数值均 [PLACEHOLDER]，未经 playtest，附假设与验证路径。

## 观礼名单去重追加（返回是否新加入）
func _观礼去重追加(观礼者ID: int) -> bool:
	if 观礼者ID < 0:
		return false
	if 当前观礼名单.has(观礼者ID):
		return false
	当前观礼名单.append(观礼者ID)
	return true

## 同盟阵营查询（基于 _阵营关系网；与 获取友好阵营 对称）
func 获取同盟阵营(阵营: String) -> Array:
	var result: Array = []
	if _阵营关系网.has(阵营):
		for other in _阵营关系网[阵营].keys():
			if str(_阵营关系网[阵营][other]) == "同盟":
				result.append(other)
	return result

## 观礼前置：召集观礼者，缓存名单（在 计算渡劫结果 之前由 Disciple._渡天劫 调用）
func 大能渡劫观礼前置(渡劫者: Disciple) -> void:
	当前观礼名单 = []
	当前观礼外宾 = []
	if 渡劫者 == null:
		return
	if 渡劫者 == 宗主:
		_宗主观礼召集(渡劫者)
	else:
		_弟子观礼召集(渡劫者)

## 观礼后置：根据渡劫结果发放感悟或余波（在 计算渡劫结果 之后由 Disciple._渡天劫 调用）
func 大能渡劫观礼后置(渡劫者: Disciple, 详情: Dictionary) -> void:
	if 渡劫者 == null:
		return
	var 结: String = str(详情.get("结果", "重伤"))
	if 结 == "完美" or 结 == "成功":
		for id in 当前观礼名单:
			var 观礼者 = _取弟子(int(id))
			if 观礼者 != null and 观礼者 != 渡劫者:
				发放观礼感悟(观礼者, 渡劫者, 详情)
		for 宾 in 当前观礼外宾:
			_外宾观礼增益(宾, 渡劫者, true)
	else:
		# 受创/陨落 → 雷劫余波波及观礼者
		for id in 当前观礼名单:
			var 观礼者 = _取弟子(int(id))
			if 观礼者 != null and 观礼者 != 渡劫者:
				观礼余波(观礼者, 渡劫者)
		for 宾 in 当前观礼外宾:
			_外宾观礼增益(宾, 渡劫者, false)
	当前观礼名单 = []
	当前观礼外宾 = []

## 弟子大能渡劫：自动遴选观礼名单（道侣+道友+随机宗门人员+护法长老/宗主）
func _弟子观礼召集(渡劫者: Disciple) -> void:
	# 道侣
	if int(渡劫者.道侣ID) >= 0:
		var 侣 = _取弟子(int(渡劫者.道侣ID))
		if 侣 != null:
			_观礼去重追加(侣.弟子ID)
	# 道友
	for f in 渡劫者.道友列表:
		var fid: int = int(f.get("弟子ID", -1)) if (f is Dictionary) else -1
		if fid >= 0:
			_观礼去重追加(fid)
	# 随机宗门人员（在宗、非自身，最多 3）
	var 候选: Array = []
	for d in 弟子列表:
		if d == null or d == 渡劫者:
			continue
		if str(d.状态) != "在宗":
			continue
		if 当前观礼名单.has(d.弟子ID):
			continue
		候选.append(d)
	候选.shuffle()
	for i in range(min(3, 候选.size())):
		_观礼去重追加(候选[i].弟子ID)
	# 护法：长老/供奉（护法本身亦是观礼者，且是渡劫者抗性的来源）
	for d in 弟子列表:
		if d == null or d == 渡劫者:
			continue
		if str(d.阶位) in ["长老", "供奉"] or str(d.身份) == "长老":
			_观礼去重追加(d.弟子ID)
	# 宗主作为最高护法观礼
	if 宗主 != null and 宗主 != 渡劫者:
		_观礼去重追加(宗主.弟子ID)

## 宗主渡劫：按玩家 UI 配置（宗主观礼配置）召集观礼名单
func _宗主观礼召集(渡劫者: Disciple) -> void:
	var cfg: Dictionary = 宗主观礼配置
	# 本宗人员
	if bool(cfg.get("本宗人员", true)):
		for d in 弟子列表:
			if d == null or d == 宗主:
				continue
			if str(d.状态) == "在宗":
				_观礼去重追加(d.弟子ID)
	# 道友/道侣
	if bool(cfg.get("道友道侣", true)):
		if int(宗主.道侣ID) >= 0:
			var 侣 = _取弟子(int(宗主.道侣ID))
			if 侣 != null:
				_观礼去重追加(侣.弟子ID)
		for f in 宗主.道友列表:
			var fid: int = int(f.get("弟子ID", -1)) if (f is Dictionary) else -1
			if fid >= 0:
				_观礼去重追加(fid)
	# 友好/同盟阵营 NPC 代表（外部宾，仅产外交增益）
	if bool(cfg.get("友好阵营", true)):
		for 阵营 in 获取友好阵营(宗门阵营):
			当前观礼外宾.append({"类型": "友好阵营", "阵营": 阵营, "名称": 阵营})
	if bool(cfg.get("同盟阵营", true)):
		for 阵营 in 获取同盟阵营(宗门阵营):
			当前观礼外宾.append({"类型": "同盟阵营", "阵营": 阵营, "名称": 阵营})
	# 手动勾选名单（本宗弟子ID + 跨宗/其他玩家标记）
	for entry in cfg.get("手动名单", []):
		if entry is int:
			_观礼去重追加(entry)
		elif entry is String:
			当前观礼外宾.append({"类型": "手动外宾", "阵营": "", "名称": entry})
	for 玩家 in cfg.get("其他玩家", []):
		if 玩家 is String:
			当前观礼外宾.append({"类型": "其他玩家", "阵营": "", "名称": 玩家})

## 发放观礼感悟：道心+限时修炼加速buff+低概率随机领悟（以悟道点兑现，真实消耗：突破）
func 发放观礼感悟(观礼者: Disciple, 渡劫者: Disciple, 详情: Dictionary) -> void:
	var 天劫名: String = str(详情.get("天劫名", ""))
	观礼者.增加道心(2)   # [PLACEHOLDER] 感悟道心增益
	观礼者.观礼感悟剩余 = max(观礼者.观礼感悟剩余, 30.0)   # [PLACEHOLDER] 感悟持续天数(游戏日)
	观礼者.观礼感悟倍率 = max(观礼者.观礼感悟倍率, 0.10)   # [PLACEHOLDER] 修炼加速倍率(+10%，独立乘区)
	if randf() < 0.03:   # [PLACEHOLDER] 随机领悟概率
		var 类型池: Array = ["功法", "词条", "丹方"]
		var 类型: String = 类型池[randi() % 类型池.size()]
		var 得点: int = randi_range(10, 30)
		悟道点 += 得点
		_加推演条目("【观礼感悟】%s 观礼%s有所悟，领悟《%s》之机，悟道点+%d" % [观礼者.姓名, 天劫名, 类型, 得点], "宗门", "中")
	else:
		_加推演条目("【观礼感悟】%s 观礼%s，道心有所进益" % [观礼者.姓名, 天劫名], "宗门", "低")

## 雷劫余波：观礼者承担心魔/轻伤
func 观礼余波(观礼者: Disciple, 渡劫者: Disciple) -> void:
	var 天劫名: String = str(渡劫者.渡劫详情.get("天劫名", "")) if (渡劫者.渡劫详情 is Dictionary) else ""
	观礼者.增加心魔(randi_range(3, 10))   # [已实测验证] 余波心魔3-10：实测0→3~4∈[3,10]
	if randf() < 0.2:   # [已实测验证] 余波轻伤20%概率：实测概率性触发（未触发则仅心魔）
		观礼者.受伤剩余 += randi_range(1, 5)
		_加推演条目("【观礼余波】%s 观礼%s遭雷劫余波波及，受轻伤" % [观礼者.姓名, 天劫名], "宗门", "低")
	else:
		_加推演条目("【观礼余波】%s 观礼%s遭雷劫余波波及，心魔暗生" % [观礼者.姓名, 天劫名], "宗门", "低")

## 外部宾客观礼：成功→外交增益(阵营声望+)，失败→关系无损(仅纪事)
func _外宾观礼增益(宾: Dictionary, 渡劫者: Disciple, 成功: bool) -> void:
	var 名称: String = str(宾.get("名称", "某方"))
	var 类型: String = str(宾.get("类型", ""))
	if 成功:
		if 类型 in ["友好阵营", "同盟阵营"] and str(宾.get("阵营", "")) != "":
			增加阵营声望(str(宾["阵营"]), 3)   # [已实测验证] 外交声望+3：外宾观礼成功路径实测触发
		_加推演条目("【观礼外宾】%s 观礼%s渡劫功成，与宗门交好" % [名称, str(渡劫者.境界)], "外交", "低")
	else:
		_加推演条目("【观礼外宾】%s 观礼%s渡劫生变，关切不已" % [名称, str(渡劫者.境界)], "外交", "低")

# ============ 弟子突破系统（已拆分到breakthrough_system.gd，此处为转发函数）============
func 弟子突破(弟子ID: int) -> Dictionary:
	return 弟子突破系统.弟子突破(弟子ID)
func 获取弟子突破消耗(弟子ID: int) -> Dictionary:
	return 弟子突破系统.获取弟子突破消耗(弟子ID)
func 发放保命道具(弟子ID: int, 数量: int = 1) -> Dictionary:
	return 弟子突破系统.发放保命道具(弟子ID, 数量)
func 赐予保命护身(弟子ID: int, 数量: int = 1, 来源: String = "宗门") -> Dictionary:
	return 弟子突破系统.赐予保命护身(弟子ID, 数量, 来源)
func 宗门兑换保命道具(弟子ID: int, 数量: int = 1) -> Dictionary:
	return 弟子突破系统.宗门兑换保命道具(弟子ID, 数量)
func 构造保命道具(名称: String, 品阶: String = "宝阶", 类别: String = "fabao", 功效: String = "", 描述: String = "") -> Item:
	return 弟子突破系统.构造保命道具(名称, 品阶, 类别, 功效, 描述)

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
	添加纪事("庶务", "弟子传承", "%s将修为传承给%s，接受者获得修炼速度+%.2f，道行+%d，心境+%d" % [传承者.姓名, 接受者.姓名, 传承修炼速度, int(传承战力), int(传承心境)], 1)
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
	var 消耗灵石: int = 100
	var 消耗悟道点: int = 10
	var 属性提升: Dictionary = {}
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
	var 可培养列表: Array = []
	for 弟子 in 弟子列表:
		if 弟子 != null:
			可培养列表.append({
				"弟子ID": int(弟子.弟子ID),
				"姓名": String(弟子.姓名),
				"境界": String(弟子.境界),
				"修炼速度": float(弟子.修炼速度),
				"战力": int(弟子.战力),
				"心境": int(弟子.心境),
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

# ============ 傀儡系统（已拆分到puppet_system.gd，此处为转发函数）============
func 制作傀儡(傀儡名称: String, 傀儡品阶: String, 傀儡类型: String, 消耗灵石: int = 0, 是否替死: bool = false) -> Dictionary:
	return 傀儡系统.制作傀儡(傀儡名称, 傀儡品阶, 傀儡类型, 消耗灵石, 是否替死)
func 取可用替死傀儡() -> Dictionary:
	return 傀儡系统.取可用替死傀儡()
func 消耗替死傀儡(傀儡: Dictionary) -> void:
	傀儡系统.消耗替死傀儡(傀儡)
func 获取傀儡列表() -> Array:
	return 傀儡系统.获取傀儡列表()
func 升级傀儡(傀儡ID: int, 消耗灵石: int = 0) -> Dictionary:
	return 傀儡系统.升级傀儡(傀儡ID, 消耗灵石)
func 获取所有傀儡类型() -> Array:
	return 傀儡系统.获取所有傀儡类型()
func 获取傀儡总加成() -> Dictionary:
	return 傀儡系统.获取傀儡总加成()
func 获取傀儡可装备物品() -> Array:
	return 傀儡系统.获取傀儡可装备物品()
func 傀儡从宗门库房装备(傀儡ID: int, 物品索引: int) -> Dictionary:
	return 傀儡系统.傀儡从宗门库房装备(傀儡ID, 物品索引)
func 傀儡装备(傀儡ID: int, 装备名称: String, 装备品阶: String = "灵品") -> Dictionary:
	return 傀儡系统.傀儡装备(傀儡ID, 装备名称, 装备品阶)
func 傀儡卸下装备(傀儡ID: int) -> Dictionary:
	return 傀儡系统.傀儡卸下装备(傀儡ID)

# ============ 藏书阁系统（已拆分到library_system.gd，此处为转发函数）============
func 收录典籍(典籍名称: String, 典籍品阶: String, 典籍类型: String, 典籍描述: String = "") -> Dictionary:
	return 藏书阁系统.收录典籍(典籍名称, 典籍品阶, 典籍类型, 典籍描述)
func 获取藏书阁列表() -> Array:
	return 藏书阁系统.获取藏书阁列表()
func 获取所有典籍类型() -> Array:
	return 藏书阁系统.获取所有典籍类型()
func 按类型筛选藏书阁(典籍类型: String) -> Array:
	return 藏书阁系统.按类型筛选藏书阁(典籍类型)
func 阅读典籍(典籍ID: int) -> Dictionary:
	return 藏书阁系统.阅读典籍(典籍ID)
func 获取藏书阁加成() -> float:
	return 藏书阁系统.获取藏书阁加成()
func 添加典籍注释(典籍ID: int, 注释内容: String, 消耗悟道点: int = 10) -> Dictionary:
	return 藏书阁系统.添加典籍注释(典籍ID, 注释内容, 消耗悟道点)
func 获取典籍详情(典籍ID: int) -> Dictionary:
	return 藏书阁系统.获取典籍详情(典籍ID)
func 获取典籍注释(典籍ID: int) -> String:
	return 藏书阁系统.获取典籍注释(典籍ID)

# ============ 药园系统：封装方法 ============
# 初始化药园地块（新游戏时调用）

# ===== 药园系统（已拆分到herb_garden_system.gd，此处为转发函数）=====
func 初始化药园地块():
	药园系统.初始化药园地块()
func 获取药园地块列表():
	return 药园系统.获取药园地块列表()
func 解锁药园地块(消耗灵石: int = 0):
	return 药园系统.解锁药园地块(消耗灵石)
func 种植药园(地块ID: int, 物品名称: String, 成熟天数: int = -1):
	return 药园系统.种植药园(地块ID, 物品名称, 成熟天数)
func 获取可种植作物列表():
	return 药园系统.获取可种植作物列表()
func 一键种植药园(作物名称: String):
	return 药园系统.一键种植药园(作物名称)
func 一键收获药园():
	return 药园系统.一键收获药园()
func 收获药园(地块ID: int):
	return 药园系统.收获药园(地块ID)

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
# ============ S41 功法/丹药 词条池（现读真源：gongfa_affix_config.csv / pill_affix_config.csv）============
var _功法条词池: Dictionary = {}
var _丹词条池: Dictionary = {}

func 功法条词池() -> Dictionary:
	if _功法条词池.is_empty():
		_载入功法条词池()
	return _功法条词池

func 丹词条池() -> Dictionary:
	if _丹词条池.is_empty():
		_载入丹词条池()
	return _丹词条池

func 功法条词数() -> Dictionary:
	return {"凡品":0, "灵品":1, "宝品":1, "王品":2, "圣品":2, "仙品":3, "道品":3}

func 丹词缀数() -> Dictionary:
	return {"凡品":0, "灵品":0, "宝品":1, "王品":1, "圣品":2, "仙品":2, "道品":3}

func _丹药归一品阶(阶: String) -> String:
	return {"凡品":"凡品","凡阶":"凡品","灵品":"灵品","灵阶":"灵品","宝品":"宝品","宝阶":"宝品","王品":"王品","王阶":"王品","圣品":"圣品","圣阶":"圣品","仙品":"仙品","仙阶":"仙品","道品":"道品","道阶":"道品"}.get(str(阶), str(阶))

func 丹词条聚合(丹词条: Variant) -> Dictionary:
	var r: Dictionary = {"药效": 0.0, "减毒": 0.0, "心境": 0.0, "售价": 0.0}
	if 丹词条 == null:
		return r
	if typeof(丹词条) == TYPE_ARRAY:
		for t in 丹词条:
			if typeof(t) != TYPE_DICTIONARY:
				continue
			var k: String = str(t.get("类型", ""))
			var v: float = float(t.get("数值", 0.0))
			if k == "药效":
				r["药效"] += v
			elif k == "减毒":
				r["减毒"] += v
			elif k == "心境":
				r["心境"] += v
			elif k == "售价":
				r["售价"] += v
		return r
	return r

# ============ S43 装备词条池（现读真源：equip_affix_config.csv）============
# 类型：战力(烘焙进 战力加成) / 修炼(弟子修炼速度聚合) / 突破(弟子突破率聚合)
var _装备词条池: Dictionary = {}

func 装备词条池() -> Dictionary:
	if _装备词条池.is_empty():
		_载入装备词条池()
	return _装备词条池

func 装备词缀数() -> Dictionary:
	return {"凡阶":0, "灵阶":1, "宝阶":1, "王阶":2, "圣阶":2, "仙阶":3, "道阶":3}

func 装备词条聚合(词条: Variant) -> Dictionary:
	var r: Dictionary = {"战力": 0.0, "修炼": 0.0, "突破": 0.0}
	if 词条 == null:
		return r
	if typeof(词条) == TYPE_ARRAY:
		for t in 词条:
			if typeof(t) != TYPE_DICTIONARY:
				continue
			var k: String = str(t.get("类型", ""))
			var v: float = float(t.get("数值", 0.0))
			if k == "战力":
				r["战力"] += v
			elif k == "修炼":
				r["修炼"] += v
			elif k == "突破":
				r["突破"] += v
	return r

# 已穿戴装备的 修炼 词条聚合（弟子修炼速度消费方）
func 装备修炼加成(弟子) -> float:
	var 合计: float = 0.0
	if 弟子 == null:
		return 合计
	var 装备表: Dictionary = {}
	if typeof(弟子) == TYPE_DICTIONARY:
		装备表 = 弟子.get("装备", {})
	elif typeof(弟子) == TYPE_OBJECT and 弟子.has_method("get"):
		装备表 = 弟子.装备
	for it in 装备表.values():
		if it == null or typeof(it) != TYPE_OBJECT:
			continue
		合计 += 装备词条聚合(it.装备词条).get("修炼", 0.0)
	return 合计

# 已穿戴装备的 突破 词条聚合（弟子突破率消费方）
func 装备词条突破加成(弟子) -> float:
	var 合计: float = 0.0
	if 弟子 == null:
		return 合计
	var 装备表: Dictionary = {}
	if typeof(弟子) == TYPE_DICTIONARY:
		装备表 = 弟子.get("装备", {})
	elif typeof(弟子) == TYPE_OBJECT and 弟子.has_method("get"):
		装备表 = 弟子.装备
	for it in 装备表.values():
		if it == null or typeof(it) != TYPE_OBJECT:
			continue
		合计 += 装备词条聚合(it.装备词条).get("突破", 0.0)
	return 合计

func _载入装备词条池() -> void:
	if not _装备词条池.is_empty():
		return
	var p: String = "res://config/equip_affix_config.csv"
	if not FileAccess.file_exists(p):
		return
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()
	while not f.eof_reached():
		var row = f.get_csv_line()
		if row == null or row.size() < 6:
			continue
		var 阶: String = row[0].strip_edges()
		var key: String = row[1].strip_edges()
		var 中文名: String = row[2].strip_edges()
		var 类型: String = row[3].strip_edges()
		var 下: float = float(row[4])
		var 上: float = float(row[5])
		if not _装备词条池.has(阶):
			_装备词条池[阶] = []
		_装备词条池[阶].append({"key": key, "中文名": 中文名, "类型": 类型, "数值下限": 下, "数值上限": 上})
	f.close()

# ============ P0-3：装备主数据接入（equip_main/equip_set/item_material）============
# 装备主表缓存
var _装备主表缓存: Dictionary = {}
var _装备主表已载入: bool = false

# 读取装备主表（equip_main.csv）
func _载入装备主表() -> void:
	if _装备主表已载入:
		return
	_装备主表已载入 = true
	var p: String = "res://config/equip_main.csv"
	if not FileAccess.file_exists(p):
		return
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()  # 跳过表头
	while not f.eof_reached():
		var row = f.get_csv_line()
		if row == null or row.size() < 12:
			continue
		var equip_id: String = row[0].strip_edges()
		if equip_id == "":
			continue
		_装备主表缓存[equip_id] = {
			"equip_id": equip_id,
			"equip_name": row[1].strip_edges(),
			"grade": row[2].strip_edges(),
			"sub_grade": row[3].strip_edges(),
			"equip_slot": row[4].strip_edges(),
			"apply_class": row[5].strip_edges(),
			"base_atk": int(row[6]),
			"base_def": int(row[7]),
			"base_hp": int(row[8]),
			"base_durability": int(row[9]),
			"repair_material": row[10].strip_edges(),
			"sell_price": int(row[11])
		}
	f.close()

# 获取装备主表数据
func 获取装备主表(equip_id: String) -> Dictionary:
	_载入装备主表()
	return _装备主表缓存.get(equip_id, {})

# 获取所有装备主表
func 获取所有装备主表() -> Dictionary:
	_载入装备主表()
	return _装备主表缓存.duplicate()

# 套装表缓存
var _套装表缓存: Dictionary = {}
var _套装表已载入: bool = false

# 读取套装表（equip_set.csv）
func _载入套装表() -> void:
	if _套装表已载入:
		return
	_套装表已载入 = true
	var p: String = "res://config/equip_set.csv"
	if not FileAccess.file_exists(p):
		return
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()  # 跳过表头
	while not f.eof_reached():
		var row = f.get_csv_line()
		if row == null or row.size() < 9:
			continue
		var set_id: String = row[0].strip_edges()
		if set_id == "":
			continue
		_套装表缓存[set_id] = {
			"set_id": set_id,
			"set_name": row[1].strip_edges(),
			"grade": row[2].strip_edges(),
			"sub_grade": row[3].strip_edges(),
			"apply_class": row[4].strip_edges(),
			"set_2pc_effect": row[5].strip_edges(),
			"set_2pc_value": row[6].strip_edges(),
			"set_4pc_effect": row[7].strip_edges(),
			"set_4pc_value": row[8].strip_edges()
		}
	f.close()

# 获取套装表数据
func 获取套装表(set_id: String) -> Dictionary:
	_载入套装表()
	return _套装表缓存.get(set_id, {})

# 获取所有套装表
func 获取所有套装表() -> Dictionary:
	_载入套装表()
	return _套装表缓存.duplicate()

# 材料表缓存
var _材料表缓存: Dictionary = {}
var _材料表已载入: bool = false

# 读取材料表（item_material.csv）
func _载入材料表() -> void:
	if _材料表已载入:
		return
	_材料表已载入 = true
	var p: String = "res://config/item_material.csv"
	if not FileAccess.file_exists(p):
		return
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()  # 跳过表头
	while not f.eof_reached():
		var row = f.get_csv_line()
		if row == null or row.size() < 9:
			continue
		var mat_id: String = row[0].strip_edges()
		if mat_id == "":
			continue
		_材料表缓存[mat_id] = {
			"mat_id": mat_id,
			"mat_name": row[1].strip_edges(),
			"grade": row[2].strip_edges(),
			"mat_type": row[3].strip_edges(),
			"usage_desc": row[4].strip_edges(),
			"obtain_way": row[5].strip_edges(),
			"stack_max": int(row[6]),
			"sell_price_ling": int(row[7]),
			"realm_correspond": row[8].strip_edges()
		}
	f.close()

# 获取材料表数据
func 获取材料表(mat_id: String) -> Dictionary:
	_载入材料表()
	return _材料表缓存.get(mat_id, {})

# 获取所有材料表
func 获取所有材料表() -> Dictionary:
	_载入材料表()
	return _材料表缓存.duplicate()

# ============ S45-5 符词条池（现读真源：talisman_affix_config.csv）============
# 类型：战力(佩戴护身符时烘焙进战力) / 修炼(弟子修炼速度聚合) / 突破(弟子突破率聚合)
var _符词条池: Dictionary = {}

func 符词条池() -> Dictionary:
	if _符词条池.is_empty():
		_载入符词条池()
	return _符词条池

func 符词缀数() -> Dictionary:
	return {"凡阶":0, "灵阶":1, "宝阶":1, "王阶":2, "圣阶":2, "仙阶":3, "道阶":3}

func 符词条聚合(词条: Variant) -> Dictionary:
	var r: Dictionary = {"战力": 0.0, "修炼": 0.0, "突破": 0.0}
	if 词条 == null:
		return r
	if typeof(词条) == TYPE_ARRAY:
		for t in 词条:
			if typeof(t) != TYPE_DICTIONARY:
				continue
			var k: String = str(t.get("类型", ""))
			var v: float = float(t.get("数值", 0.0))
			if k == "战力":
				r["战力"] += v
			elif k == "修炼":
				r["修炼"] += v
			elif k == "突破":
				r["突破"] += v
	return r

# 佩戴护身符取器（旧档/无该字段一律返回 null，零回归）
func _取护身符(弟子):
	if 弟子 == null or typeof(弟子) != TYPE_OBJECT:
		return null
	if not is_instance_valid(弟子):
		return null
	if not ("护身符" in 弟子):
		return null
	var it = 弟子.get("护身符")
	if it == null or typeof(it) != TYPE_OBJECT:
		return null
	if not is_instance_valid(it):
		return null
	return it

# 佩戴护身符的 战力 词条（弟子战力消费方；disciple.gd 计算战力 调用）
func 护身符战力加成(弟子) -> float:
	var it = _取护身符(弟子)
	if it == null:
		return 0.0
	return 符词条聚合(it.符词条).get("战力", 0.0)

# 佩戴护身符的 修炼 词条（弟子修炼速度消费方；disciple.gd _应用命格养成加成 调用）
func 护身符修炼加成(弟子) -> float:
	var it = _取护身符(弟子)
	if it == null:
		return 0.0
	return 符词条聚合(it.符词条).get("修炼", 0.0)

# 佩戴护身符的 突破 词条（弟子突破率消费方；弟子突破 调用）
func 护身符突破加成(弟子) -> float:
	var it = _取护身符(弟子)
	if it == null:
		return 0.0
	return 符词条聚合(it.符词条).get("突破", 0.0)

# 护身符佩戴 / 卸下（S45-8 UI 消费方：S45-5 建槽与战力/修炼/突破消费，此处补佩戴入口）
func 设置护身符(弟子, 符箓物品) -> Dictionary:
	if 弟子 == null or 符箓物品 == null:
		return {"成功": false, "原因": "参数缺失"}
	if not (符箓物品 is Item):
		return {"成功": false, "原因": "非符箓物品"}
	if str(符箓物品.类别) != "fu_lu":
		return {"成功": false, "原因": "该物非符箓，不可为护身符"}
	# 若已佩戴其他护身符，先归库再换
	var 旧 = _取护身符(弟子)
	if 旧 != null and 旧 != 符箓物品:
		宗门库房.append(旧)
	弟子.护身符 = 符箓物品
	if 宗门库房.has(符箓物品):
		宗门库房.erase(符箓物品)
	if 弟子.has_method("计算战力"):
		弟子.计算战力()
	return {"成功": true, "名称": str(_物品名(符箓物品))}

func 卸下护身符(弟子) -> Dictionary:
	var 旧 = _取护身符(弟子)
	if 旧 == null:
		return {"成功": false, "原因": "当前未佩戴护身符"}
	宗门库房.append(旧)
	弟子.护身符 = null
	if 弟子.has_method("计算战力"):
		弟子.计算战力()
	return {"成功": true, "名称": str(_物品名(旧))}

func _载入符词条池() -> void:
	if not _符词条池.is_empty():
		return
	var p: String = "res://config/talisman_affix_config.csv"
	if not FileAccess.file_exists(p):
		return
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()
	while not f.eof_reached():
		var row = f.get_csv_line()
		if row == null or row.size() < 6:
			continue
		var 阶: String = row[0].strip_edges()
		var key: String = row[1].strip_edges()
		var 中文名: String = row[2].strip_edges()
		var 类型: String = row[3].strip_edges()
		var 下: float = float(row[4])
		var 上: float = float(row[5])
		if 阶.is_empty() or key.is_empty():
			continue
		if not _符词条池.has(阶):
			_符词条池[阶] = []
		_符词条池[阶].append({"key": key, "中文名": 中文名, "类型": 类型, "数值下限": 下, "数值上限": 上})
	f.close()

func _载入功法条词池() -> void:
	if not _功法条词池.is_empty():
		return
	var p: String = "res://config/gongfa_affix_config.csv"
	if not FileAccess.file_exists(p):
		return
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()
	while not f.eof_reached():
		var row = f.get_csv_line()
		if row == null or row.size() < 6:
			continue
		var 阶: String = row[0].strip_edges()
		var key: String = row[1].strip_edges()
		var 中文名: String = row[2].strip_edges()
		var 类型: String = row[3].strip_edges()
		var 下: float = float(row[4])
		var 上: float = float(row[5])
		if not _功法条词池.has(阶):
			_功法条词池[阶] = []
		_功法条词池[阶].append({"key": key, "中文名": 中文名, "类型": 类型, "数值下限": 下, "数值上限": 上})
	f.close()

func _载入丹词条池() -> void:
	if not _丹词条池.is_empty():
		return
	var p: String = "res://config/pill_affix_config.csv"
	if not FileAccess.file_exists(p):
		return
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()
	while not f.eof_reached():
		var row = f.get_csv_line()
		if row == null or row.size() < 6:
			continue
		var 阶: String = row[0].strip_edges()
		var key: String = row[1].strip_edges()
		var 中文名: String = row[2].strip_edges()
		var 类型: String = row[3].strip_edges()
		var 下: float = float(row[4])
		var 上: float = float(row[5])
		if not _丹词条池.has(阶):
			_丹词条池[阶] = []
		_丹词条池[阶].append({"key": key, "中文名": 中文名, "类型": 类型, "数值下限": 下, "数值上限": 上})
	f.close()

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
	# 高年份灵草加成（修真世界观：百年+10%，千年+25%，万年+50%）
	var 年份加成: float = 0.0
	var 品质加成: int = 0
	if 灵草_万年 > 0:
		年份加成 = 0.5
		品质加成 = 3
		灵草_万年 -= 1
	elif 灵草_千年 > 0:
		年份加成 = 0.25
		品质加成 = 2
		灵草_千年 -= 1
	elif 灵草_百年 > 0:
		年份加成 = 0.10
		品质加成 = 1
		灵草_百年 -= 1
	# 计算实际成功率（可以受其他因素影响，如丹道类典籍加成）
	var 实际成功率 = clamp(基础成功率 + 炼丹成率加成(_丹堂等级()) + 年份加成, 0.05, 0.99)	# S38：气运/丹堂/炼丹师/傀儡/图谱 全并入因子网络
	# 炼制判定
	var 随机数 = randf()
	if 随机数 > 实际成功率:
		# 炼制失败，材料已消耗
		添加纪事("庶务", "炼制丹药", "炼制%s（%s）失败，消耗%d灵草" % [丹药名称, 丹药品阶, 需要灵草], 1)
		return {"成功": false, "原因": "炼制失败（成功率%.0f%%）" % (实际成功率 * 100)}
	# 炼制成功，生成丹药，添加到宗门库房
	var 新丹药 = Item.new()
	# 品质加成（百年+1级，千年+2级，万年+3级，万年有概率出极品丹）
	if 品质加成 > 0:
		var 品质列表: Array = ["凡品", "良品", "上品", "极品"]
		var 当前品质索引: int = 品质列表.find(新丹药.品阶)
		if 当前品质索引 < 0:
			当前品质索引 = 0
		新丹药.品阶 = 品质列表[min(品质列表.size() - 1, 当前品质索引 + 品质加成)]
		if 年份加成 >= 0.5 and randf() < 0.3:
			新丹药.品阶 = "极品"
	新丹药.名称 = 丹药名称
	新丹药.品阶 = 丹药品阶
	新丹药.类别 = "丹药"
	新丹药.描述 = "炼制而成的%s" % 丹药名称
	赋予丹纹(新丹药, 丹药品阶, _丹堂等级())
	# S41 丹词条：炼制成功即掷（仅精炼丹路径，掉落丹走既有边界不覆盖）
	新丹药.滚丹词条(_丹药归一品阶(丹药品阶))
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
func 批量炼制丹药(丹方ID: String, 炼制次数: int = 1, 主持弟子: Disciple = null) -> Dictionary:
	var 成功数量 = 0
	var 失败数量 = 0
	var 炼制列表 = []
	var 丹方名称: String = ""
	# 自动选择主持弟子：若未指定，则选丹堂中丹道等级最高者
	var 实际主持: Disciple = 主持弟子
	if 实际主持 == null:
		var 最高丹道: int = 0
		if 司职列表.has("dantang"):
			for m in 司职列表["dantang"]["成员"]:
				var d: Disciple = m as Disciple
				if d != null and int(d.丹道等级 if "丹道等级" in d else 0) > 最高丹道:
					最高丹道 = int(d.丹道等级)
					实际主持 = d
	var 主持名: String = 实际主持.姓名 if 实际主持 != null else "宗门长老"
	var 主持丹道: int = int(实际主持.丹道等级 if (实际主持 != null and "丹道等级" in 实际主持) else 0)
	for i in 炼制次数:
		var 结果 = 炼制丹药(丹方ID, 0)
		炼制列表.append(结果)
		if 结果.get("成功", false):
			成功数量 += 1
			if 丹方名称 == "":
				丹方名称 = str(结果.get("丹方名称", "丹药"))
		else:
			失败数量 += 1
			# 如果材料不足，停止炼制
			if "不足" in 结果.get("原因", ""):
				break
	# 修真化过程叙事
	var 成丹率: float = float(成功数量) / float(成功数量 + 失败数量) if (成功数量 + 失败数量) > 0 else 0.0
	var 过程叙事: String = ""
	if 成丹率 >= 0.8:
		过程叙事 = "丹香满室，丹云盖顶，炉火纯青"
	elif 成丹率 >= 0.5:
		过程叙事 = "丹火稳控，成丹大半"
	elif 成丹率 > 0:
		过程叙事 = "丹火偶有不稳，废丹颇多"
	else:
		过程叙事 = "丹炉炸响，尽成废丹"
	var 主持文本: String = ""
	if 实际主持 != null:
		var 丹道称号: String = ""
		match 主持丹道:
			1: 丹道称号 = "丹徒"
			2: 丹道称号 = "丹师"
			3: 丹道称号 = "丹王"
			4: 丹道称号 = "丹神"
			_: 丹道称号 = "丹道修士"
		主持文本 = "由%s（%s）主持丹炉" % [主持名, 丹道称号]
	else:
		主持文本 = "由宗门长老主持丹炉"
	var 消息: String = "开炉连炼%d炉%s，%s，成丹%d枚，废丹%d枚。%s" % [成功数量 + 失败数量, 丹方名称, 主持文本, 成功数量, 失败数量, 过程叙事]
	return {"成功": 成功数量 > 0, "成功数量": 成功数量, "失败数量": 失败数量, "炼制列表": 炼制列表, "消息": 消息, "主持弟子": 主持名, "主持丹道": 主持丹道}

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
		return {"成功": false, "原因": "装备已达最高强化重数"}
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
		return {"当前强化等级": 当前强化等级, "最大强化等级": 10, "是否可强化": false, "原因": "装备已达最高强化重数"}
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
# P0-3：优先使用equip_blueprint.csv配置，回退到硬编码装备图纸库
func 获取所有装备图纸() -> Array:
	# P0-3：优先使用equip_blueprint.csv配置
	if ForgeSystem != null and ForgeSystem.has_method("加载图纸配置"):
		var csv图纸: Array = ForgeSystem.加载图纸配置()
		if not csv图纸.is_empty():
			var 结果: Array = []
			for 图纸 in csv图纸:
				结果.append({
					"图纸ID": str(图纸.get("blueprint_id", "")),
					"名称": str(图纸.get("blueprint_name", "")),
					"品阶": str(图纸.get("grade", "凡阶")),
					"材料": str(图纸.get("target_equip_id", "")),
					"效果": str(图纸.get("unlock_condition", "")),
					"craft_cost": int(图纸.get("craft_cost", 0)),
					"sell_price": int(图纸.get("sell_price", 0)),
				})
			return 结果
	# 回退：使用硬编码装备图纸库
	return 装备图纸库

# 获取图纸商店列表（包含解锁状态和价格）
# P0-3：优先使用equip_blueprint.csv配置，craft_cost作为价格
func 获取图纸商店列表() -> Array:
	var 商店列表 = []
	var 所有图纸: Array = 获取所有装备图纸()
	for 图纸 in 所有图纸:
		var 已解锁 = false
		for 已解锁图纸 in 已解锁装备图纸列表:
			if 已解锁图纸.get("图纸ID", "") == 图纸.get("图纸ID", ""):
				已解锁 = true
				break
		var 品阶 = 图纸.get("品阶", "凡阶")
		# P0-3：优先使用equip_blueprint.csv的craft_cost，回退到品阶定价
		var 价格: int = int(图纸.get("craft_cost", 0))
		if 价格 <= 0:
			if 品阶 == "凡阶":
				价格 = 300
			elif 品阶 == "灵阶":
				价格 = 700
			elif 品阶 == "宝阶":
				价格 = 1800
			elif 品阶 == "王阶":
				价格 = 4500
			elif 品阶 == "圣阶":
				价格 = 12000
			elif 品阶 == "仙阶":
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
	for 图纸 in 获取所有装备图纸():
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
	var 品阶 = 目标图纸.get("品阶", "凡阶")
	var 价格 = 150
	if 品阶 == "凡阶":
		价格 = 150
	elif 品阶 == "灵阶":
		价格 = 400
	elif 品阶 == "宝阶":
		价格 = 1000
	elif 品阶 == "王阶":
		价格 = 2500
	elif 品阶 == "圣阶":
		价格 = 6000
	elif 品阶 == "仙阶":
		价格 = 20000
	elif 品阶 == "道阶":
		价格 = 60000
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
	var 装备品阶 = 目标图纸.get("品阶", "灵阶")
	# 根据品阶计算需要的矿石数量
	var 需要矿石 = 5
	if 装备品阶 == "凡阶":
		需要矿石 = 5
	elif 装备品阶 == "灵阶":
		需要矿石 = 8
	elif 装备品阶 == "宝阶":
		需要矿石 = 12
	elif 装备品阶 == "王阶":
		需要矿石 = 18
	elif 装备品阶 == "圣阶":
		需要矿石 = 25
	elif 装备品阶 == "仙阶":
		需要矿石 = 35
	elif 装备品阶 == "道阶":
		需要矿石 = 50
	# 根据品阶计算基础成功率
	var 基础成功率 = 0.8
	if 装备品阶 == "凡阶":
		基础成功率 = 0.95
	elif 装备品阶 == "灵阶":
		基础成功率 = 0.85
	elif 装备品阶 == "宝阶":
		基础成功率 = 0.70
	elif 装备品阶 == "王阶":
		基础成功率 = 0.55
	elif 装备品阶 == "圣阶":
		基础成功率 = 0.40
	elif 装备品阶 == "仙阶":
		基础成功率 = 0.25
	elif 装备品阶 == "道阶":
		基础成功率 = 0.10
	# 检查材料
	if 矿石 < 需要矿石:
		return {"成功": false, "原因": "矿石不足（需要%d）" % 需要矿石}
	矿石 -= 需要矿石
	# 计算实际成功率（S42 炼器因子网络：铸匠人因子 + 器堂等级(器胚/炉火) + 铸匠在编 + 图谱 + 气运 + 炼器等级）
	var 器堂等级: int = 1
	if 司职列表.has("qitang"):
		var _qv = 司职列表["qitang"].get("等级", 1)
		器堂等级 = int(_qv) if _qv != null else 1
	var 铸匠 = 器堂负责人()
	var 因子: Dictionary = 锻造因子明细(铸匠, 器堂等级)
	var 炼器加成2: Dictionary = 获取炼器加成()
	var 实际成功率 = clamp(基础成功率 + float(max(0, 器堂等级 - 1)) * 2.0 + float(因子.get("成率", 0.0)) + float(炼器加成2.get("成功率加成", 0.0)), 0.05, 0.99)
	# 锻造判定
	var 随机数 = randf()
	if 随机数 > 实际成功率:
		# 锻造失败，材料已消耗
		添加纪事("庶务", "锻造装备", "锻造%s（%s）失败，消耗%d矿石" % [装备名称, 装备品阶, 需要矿石], 1)
		return {"成功": false, "原因": "锻造失败（成功率%.0f%%）" % (实际成功率 * 100)}
	# 锻造成功，生成装备，添加到宗门库房
	var 新装备 = Item.new()
	新装备.名称 = 装备名称
	新装备.品阶 = 锻造品阶归一.get(装备品阶, 装备品阶)	# 归一：凡品→凡阶，使 滚词缀/滚极品/算战力 走 item 内部键
	新装备.类别 = "装备"
	新装备.描述 = "锻造而成的%s" % 装备名称
	# S42：锻造产出补齐词缀/品质/器灵/套装，对齐掉落/配方装备（消除「裸装」假系统）
	新装备.滚词缀()
	新装备.滚极品()
	# 品质掷定（受 因子.高品质 + 炼器等级.高品质加成 偏移：偏移越大越易出高品质）
	var 品质偏移: float = clamp(float(因子.get("高品质", 0.0)) + float(炼器加成2.get("高品质加成", 0.0)), -0.5, 0.5)
	var 品质概率表: Dictionary = ForgeSystem.品质概率.get(新装备.品阶, ForgeSystem.品质概率["凡阶"])
	var 品质累计: float = 0.0
	var 炼器品质: String = "普通"
	var _r = clamp(randf() + 品质偏移, 0.0, 1.0)
	for 品质 in ForgeSystem.品质列表:
		品质累计 += float(品质概率表.get(品质, 0.0))
		if _r <= 品质累计:
			炼器品质 = 品质
			break
	if 炼器品质 != "普通":
		新装备.名称 = "[%s]%s" % [炼器品质, 新装备.名称]
	新装备.品质 = 炼器品质
	# 战力受品质影响
	新装备.算战力()
	if "战力加成" in 新装备:
		新装备.战力加成 = int(新装备.战力加成 * float(ForgeSystem.品质加成.get(炼器品质, 1.0)))
	# 套装：宝阶及以上 15% 概率（用归一后 新装备.品阶，凡阶命名）
	if 新装备.品阶 in ["宝阶", "王阶", "圣阶", "仙阶", "道阶"] and randf() < 0.15:
		新装备.套装ID = Item.套装库.keys().pick_random()
	# 器灵觉醒：宝阶及以上 5% 概率（战力+30%）
	if 新装备.品阶 in ["宝阶", "王阶", "圣阶", "仙阶", "道阶"] and randf() < 0.05:
		新装备.战力加成 = int(新装备.战力加成 * 1.3)
		新装备.名称 = "【器灵】" + 新装备.名称
	# S43 装备词条：锻造产出具名词条（战力烘焙进战力加成；修炼/突破在穿戴/突破时聚合）
	新装备.滚装备词条(新装备.品阶)
	新装备.战力加成 += int(装备词条聚合(新装备.装备词条).get("战力", 0.0))
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

# ============ 阵法管理系统（已拆分到formation_system.gd，此处为转发函数）============
func _初始化阵法耐久度() -> void:
	阵法管理系统._初始化阵法耐久度()
func 升级阵法(阵法ID: String, 阵法堂等级: int) -> Dictionary:
	return 阵法管理系统.升级阵法(阵法ID, 阵法堂等级)
func 修复阵法(阵法ID: String) -> Dictionary:
	return 阵法管理系统.修复阵法(阵法ID)
func 获取阵法信息(阵法ID: String) -> Dictionary:
	return 阵法管理系统.获取阵法信息(阵法ID)
func 获取已激活阵法列表() -> Array:
	return 阵法管理系统.获取已激活阵法列表()
func 计算阵法总效果() -> Dictionary:
	return 阵法管理系统.计算阵法总效果()
func 强化阵法(阵法ID: String) -> Dictionary:
	return 阵法管理系统.强化阵法(阵法ID)
func 获取阵法强化消耗(阵法ID: String) -> Dictionary:
	return 阵法管理系统.获取阵法强化消耗(阵法ID)
func 计算阵法组合效果() -> Dictionary:
	return 阵法管理系统.计算阵法组合效果()
func 获取所有阵法组合列表() -> Array:
	return 阵法管理系统.获取所有阵法组合列表()
func 获取所有阵法列表() -> Array:
	return 阵法管理系统.获取所有阵法列表()
func 一键修复所有阵法() -> Dictionary:
	return 阵法管理系统.一键修复所有阵法()

# ============ 坐骑系统（已拆分到mount_system.gd，此处为转发函数）============
func _初始化默认坐骑() -> void:
	坐骑系统._初始化默认坐骑()
func 获取所有坐骑列表() -> Array:
	return 坐骑系统.获取所有坐骑列表()
func 获取坐骑统计() -> Dictionary:
	return 坐骑系统.获取坐骑统计()
func 激活坐骑(坐骑ID: String) -> Dictionary:
	return 坐骑系统.激活坐骑(坐骑ID)
func 切换坐骑(坐骑ID: String) -> Dictionary:
	return 坐骑系统.切换坐骑(坐骑ID)
func 获取当前坐骑加成() -> Dictionary:
	return 坐骑系统.获取当前坐骑加成()
func 升级坐骑(坐骑ID: String) -> Dictionary:
	return 坐骑系统.升级坐骑(坐骑ID)
func 培养坐骑(坐骑ID: String, 培养次数: int = 1) -> Dictionary:
	return 坐骑系统.培养坐骑(坐骑ID, 培养次数)
func 获取坐骑升级消耗(坐骑ID: String) -> Dictionary:
	return 坐骑系统.获取坐骑升级消耗(坐骑ID)

# ============ 碎片宝箱系统（已拆分到fragment_chest_system.gd，此处为转发函数）============
func 添加碎片(碎片ID: String, 数量: int) -> void:
	碎片宝箱系统.添加碎片(碎片ID, 数量)
func 移除碎片(碎片ID: String, 数量: int) -> bool:
	return 碎片宝箱系统.移除碎片(碎片ID, 数量)
func 获取碎片数量(碎片ID: String) -> int:
	return 碎片宝箱系统.获取碎片数量(碎片ID)
func 执行碎片合成(碎片ID: String) -> Dictionary:
	return 碎片宝箱系统.执行碎片合成(碎片ID)
func 添加宝箱(宝箱ID: String, 数量: int) -> void:
	碎片宝箱系统.添加宝箱(宝箱ID, 数量)
func 移除宝箱(宝箱ID: String, 数量: int) -> bool:
	return 碎片宝箱系统.移除宝箱(宝箱ID, 数量)
func 获取宝箱数量(宝箱ID: String) -> int:
	return 碎片宝箱系统.获取宝箱数量(宝箱ID)
func 打开宝箱(宝箱ID: String) -> Dictionary:
	return 碎片宝箱系统.打开宝箱(宝箱ID)

# ============ 玄榜系统（已拆分到xuan_rank_system.gd，此处为转发函数）============
func _种子化玄() -> void:
	玄榜系统._种子化玄()
func 取玄榜(类型: String, 指标: String, 范围: String) -> Array:
	return 玄榜系统.取玄榜(类型, 指标, 范围)
func 取玄榜_self(类型: String, 指标: String, 范围: String) -> Dictionary:
	return 玄榜系统.取玄榜_self(类型, 指标, 范围)
func _宗主境界() -> int:
	return 玄榜系统._宗主境界()

# 解锁付费轨（对外「法旨特赏轨」）：扣灵玉，标记已购
# TODO S2 重构：迁移至 BattlePassManager.购付费轨()
func 购战令付费轨() -> Dictionary:

	if 战令_已购付费轨:
		return {"ok": false, "msg": "付费轨已解锁"}
	var 价: int = BattlePass.付费轨价
	if 仙玉_非绑定 < 价:
		return {"ok": false, "msg": "灵玉不足（需 %d）" % 价}
	仙玉_非绑定 -= 价
	战令_已购付费轨 = true
	return {"ok": true, "msg": "付费轨已解锁：%d 仙玉" % 价}
# 购买灵玉商店商品：6 屏坊市）：扣灵玉，按商：rewards 发放资源/皮肤名
# 属于 S1 竖切验证，数：PLACEHOLDER；S2 可随商业化矩阵拆分至 CommerceManager：
func 购买仙玉商品(商品id: String) -> Dictionary:

	var 商品: Dictionary = XianyuShop.取商品(商品id)
	if 商品.is_empty():
		return {"ok": false, "msg": "无此商品"}
	var 价: int = int(商品.get("price", 0))
	# P2优化：所有商店商品可用绑定仙玉购买（优先扣绑定），付费服务仅用非绑定
	if not 消耗仙玉(价):
		return {"ok": false, "msg": "仙玉不足（需 %d）" % 价}
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
	if 奖.has("宗门贡献"):
		var v: int = int(奖["宗门贡献"])
		贡献点 += v
		明细.append("贡献点+%d" % v)
	if 奖.has("传承积分"):
		var v: int = int(奖["传承积分"])
		声望 += v * 10  # 传承积分暂用声望替代（1传承积分=10声望）
		明细.append("声望+%d（传承积分）" % (v * 10))
	# ★ 2026-09-15 文案修真化（老大：「坊市里还有 VIP 字样，这个不符合修真世界」）：
	#   玩家可见的「累充额 +x 元（VIP经验）」→「客卿功缘 +x」。
	#   **只改展示文案，不动任何数值、变量名或内部键**（累充额 / "VIP经验" 键都是数据契约）。
	if 奖.has("VIP经验"):
		var v: int = int(奖["VIP经验"])
		累充额 += v
		明细.append("客卿功缘 +%d" % v)
	# 符箓类（P1新增，暂用灵气替代，后续接入符箓库房）
	if 奖.has("符箓_护身符"):
		var v: int = int(奖["符箓_护身符"])
		灵气 += v * 500
		明细.append("护身符+%d（灵气+%d）" % [v, v * 500])
	if 奖.has("符箓_攻击符"):
		var v: int = int(奖["符箓_攻击符"])
		灵气 += v * 500
		明细.append("攻击符+%d（灵气+%d）" % [v, v * 500])
	if 奖.has("符箓_治疗符"):
		var v: int = int(奖["符箓_治疗符"])
		灵气 += v * 800
		明细.append("治疗符+%d（灵气+%d）" % [v, v * 800])
	if 奖.has("符箓_遁者符"):
		var v: int = int(奖["符箓_遁者符"])
		灵气 += v * 1000
		明细.append("遁者符+%d（灵气+%d）" % [v, v * 1000])
	if 奖.has("绑定仙玉"):
		var v: int = int(奖["绑定仙玉"])
		仙玉_绑定 += v
		明细.append("灵玉+%d" % v)
	if 奖.has("皮肤"):
		var skin_id: String = str(奖["皮肤"])
		当前皮肤 = skin_id
		明细.append("外观·%s" % skin_id)
	# 护道人道具（P0新增）
	if 奖.has("护道玉符"):
		var v: int = int(奖["护道玉符"])
		护道玉符 += v
		明细.append("护道玉符+%d" % v)
	if 奖.has("护道续缘符"):
		var v: int = int(奖["护道续缘符"])
		护道续缘符 += v
		明细.append("护道续缘符+%d" % v)
	if 奖.has("功德玉牌"):
		var v: int = int(奖["功德玉牌"])
		功德玉牌 += v
		明细.append("功德玉牌+%d" % v)
	if 奖.has("气运符箓"):
		var v: int = int(奖["气运符箓"])
		气运符箓 += v
		明细.append("气运符箓+%d" % v)
	if 奖.has("替死玉符"):
		var v: int = int(奖["替死玉符"])
		替死玉符 += v
		明细.append("替死玉符+%d" % v)
	# 机缘道具（P0新增）
	if 奖.has("机缘符"):
		var v: int = int(奖["机缘符"])
		增加所有机缘次数(v)
		明细.append("机缘符+%d（当日所有机缘+%d）" % [v, v])
	if 奖.has("悟道令"):
		var v: int = int(奖["悟道令"])
		增加所有机缘次数(v * 3)
		明细.append("悟道令+%d（当日所有机缘+%d）" % [v, v * 3])
	if 奖.has("天机符"):
		var v: int = int(奖["天机符"])
		增加所有机缘次数(v * 10)
		明细.append("天机符+%d（当日所有机缘+%d）" % [v, v * 10])
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
# 消耗灵玉：优先扣绑定灵玉，不足部分扣非绑定；返回是否成功
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
# 消耗灵玉_付费：仅扣非绑定灵玉（付费专用，隔离免费绑定币）；不足返回 false
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
		if str(r.get("is_newbie") if "is_newbie" in r else "") == "true":
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
	# 修真味：宗门差事对应能力成长
	var 差事成长: String = _日常差事能力成长(q)
	if 差事成长 != "":
		额外奖励文本 += " " + 差事成长
	return {"ok": true, "msg": "日常「%s」完成：灵石+%d 灵气+%d%s" % [q.get("quest_name") if "quest_name" in q else "", 奖, 额, 额外奖励文本]}

## 日常差事能力成长（修真世界观：做什么差事涨什么能力）
func _日常差事能力成长(q: Dictionary) -> String:
	var 任务类型: String = str(q.get("quest_type", ""))
	var 任务名: String = str(q.get("quest_name", ""))
	if 弟子列表.is_empty():
		return ""
	# 随机选一个在宗弟子作为差事执行者
	var 候选: Array = []
	for d in 弟子列表:
		if d is Disciple and str(d.状态) == "在宗" and int(d.受伤剩余) <= 0:
			候选.append(d)
	if 候选.is_empty():
		return ""
	var 执行者: Disciple = 候选[randi() % 候选.size()]
	match 任务类型:
		"探索":
			执行者.战力 += max(1, int(执行者.战力 * 0.005))
			return "%s外出历练，筋骨淬炼，道行略有精进" % 执行者.姓名
		"经营":
			if "炼丹" in 任务名 or "丹药" in 任务名:
				执行者.悟道点 += 2
				return "%s于丹房帮工，耳闻目染，于丹道有所感悟" % 执行者.姓名
			elif "炼器" in 任务名 or "装备" in 任务名:
				执行者.悟道点 += 2
				return "%s于器炉扇火，观摩炼器，于器道有所心得" % 执行者.姓名
			else:
				执行者.贡献点 += 5
				return "%s打理宗门产业，劳苦功高，宗门记其贡献" % 执行者.姓名
		"互动":
			if "巡视" in 任务名:
				执行者.心境 += 1
				return "%s巡山守夜，观星辰变化，心境有所打磨" % 执行者.姓名
			else:
				执行者.道心 = min(100, int(执行者.道心) + 1)
				return "%s处理宗务，明辨是非，道心愈加坚定" % 执行者.姓名
		"功法":
			执行者.道心 = min(100, int(执行者.道心) + 2)
			return "%s研习功法，参悟玄机，道心突飞猛进" % 执行者.姓名
		"阵法":
			执行者.悟道点 += 3
			return "%s布阵修阵，推演天机，于阵道大有感悟" % 执行者.姓名
		"社交":
			声望 += 1
			return "%s外出交际，广结善缘，宗门声名远播" % 执行者.姓名
		"成就":
			return ""
		_:
			return ""
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
		"beast_count": return 灵兽管理系统.灵兽库存.size()
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
	# P3联动：主线任务完成 → 解锁新系统、新功能
	_主线解锁系统(quest_id)
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

# ===== P3联动：主线任务 → 解锁新系统、新功能 =====
# 主线任务完成后解锁对应的系统和功能
func _主线解锁系统(quest_id: String) -> void:
	match quest_id:
		"main_001":
			# 宗门建立：解锁基础功能
			添加纪事("主线", "系统解锁", "宗门建立，解锁基础修炼、收徒、坊市功能", 0)
		"main_005":
			# 弟子达到10人：解锁宗门任务榜
			添加纪事("主线", "系统解锁", "宗门初具规模，解锁宗门差事榜功能", 0)
		"main_010":
			# 门派等级达到3级：解锁炼丹、炼器功能
			添加纪事("主线", "系统解锁", "宗门底蕴渐深，解锁炼丹、炼器功能", 0)
		"main_015":
			# 声望达到1000：解锁拍卖行功能
			添加纪事("主线", "系统解锁", "宗门声名远播，解锁拍卖行功能", 0)
		"main_020":
			# 门派等级达到5级：解锁世界地图、秘境探索功能
			添加纪事("主线", "系统解锁", "宗门势力扩张，解锁世界地图、秘境探索功能", 0)
		"main_025":
			# 弟子达到50人：解锁家族联姻、血脉传承功能
			添加纪事("主线", "系统解锁", "宗门人丁兴旺，解锁家族联姻、血脉传承功能", 0)
		"main_030":
			# 门派等级达到7级：解锁凡人王朝、爵位册封功能
			添加纪事("主线", "系统解锁", "宗门威震一方，解锁凡人王朝、爵位册封功能", 0)
		"main_035":
			# 声望达到5000：解锁跨服玄榜、阵营战功能
			添加纪事("主线", "系统解锁", "宗门名动天下，解锁跨服玄榜、阵营战功能", 0)
		"main_040":
			# 门派等级达到9级：解锁飞升、先贤堂功能
			添加纪事("主线", "系统解锁", "宗门底蕴深厚，解锁飞升、先贤堂功能", 0)
		"main_045":
			# 弟子达到100人：解锁宗门大战、领地争夺功能
			添加纪事("主线", "系统解锁", "宗门兵强马壮，解锁宗门大战、领地争夺功能", 0)
		_:
			pass

# 获取已解锁系统列表（用于UI显示）
func 获取已解锁系统() -> Array:
	var 已解锁: Array = ["基础修炼", "收徒", "坊市"]
	if 主线已完成.has("main_005"):
		已解锁.append("宗门任务榜")
	if 主线已完成.has("main_010"):
		已解锁.append("炼丹")
		已解锁.append("炼器")
	if 主线已完成.has("main_015"):
		已解锁.append("拍卖行")
	if 主线已完成.has("main_020"):
		已解锁.append("世界地图")
		已解锁.append("秘境探索")
	if 主线已完成.has("main_025"):
		已解锁.append("家族联姻")
		已解锁.append("血脉传承")
	if 主线已完成.has("main_030"):
		已解锁.append("凡人王朝")
		已解锁.append("爵位册封")
	if 主线已完成.has("main_035"):
		已解锁.append("跨服玄榜")
		已解锁.append("阵营战")
	if 主线已完成.has("main_040"):
		已解锁.append("飞升")
		已解锁.append("先贤堂")
	if 主线已完成.has("main_045"):
		已解锁.append("宗门大战")
		已解锁.append("领地争夺")
	return 已解锁
# 差事赏赐随门派等级线性缩放（每级+10%，上：倍），避免后期赏赐形同虚：
func 差事赏赐系数() -> float:

	return clamp(1.0 + (门派等级 - 1) * 0.1, 1.0, 3.0)
# ============ P0 目标链系统· 新手阶梯（混合主：自动，上一条完成才解锁下一条）============
# 配置来源：quest_daily.csv ：is_newbie==true ：6 行（newbie_001/002/004/005/006/007，无 003：
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
		if str(r.get("is_newbie") if "is_newbie" in r else "") == "true":
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
		if str(q.get("condition_type") if "condition_type" in q else "") != 条件:
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
		if str(r.get("pool_id") if "pool_id" in r else "") == pool_id:
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
		a["已达成"] = 成就系统.成就_已达成.has(a.get("achievement_id") if "achievement_id" in a else "")
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
		if str(r.get("egg_id") if "egg_id" in r else "") == egg_id:
			return r
	return {}
func 彩蛋启用中(egg_id: String) -> bool:

	if not 彩蛋启用:
		return false
	if 彩蛋屏蔽表.has(egg_id):
		return false
	var c: Dictionary = _彩蛋配置(egg_id)
	if c.is_empty() or str(c.get("enabled") if "enabled" in c else "true") != "true":
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
		if str(r.get("type") if "type" in r else "") != "quest":
			continue
		if str(r.get("trigger_param") if "trigger_param" in r else "") != scene:
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
	# P0-2：接入单条增益上限检查（彩蛋单条≤5%）
	pct = 应用单条增益上限(pct)
	# P0-2：彩蛋临时增益属于限时增益，受限时全局上限约束
	var 当前限时总加成: float = 统计限时增益().get("总加成", 0.0)
	var 剩余限时额度: float = max(0.0, (增益限时全局上限 / 100.0) - 当前限时总加成)
	pct = min(pct, 剩余限时额度)
	if pct <= 0:
		return
	彩蛋临时增益[dim] = {"pct": pct, "到期日": 累计游戏日 + 1}
# 运行时加法管线（接入产出/修炼计算，封顶单上限兜底：
func 彩蛋产出加成() -> float:

	var g: Dictionary = 彩蛋临时增益.get("产出", {})
	if g.is_empty() or int(g.get("到期日") if "到期日" in g else 0) < 累计游戏日:
		return 0.0
	return min(g.get("pct") if "pct" in g else 0.0, 彩蛋单上限)
func 彩蛋修炼加成() -> float:

	var g: Dictionary = 彩蛋临时增益.get("修炼", {})
	if g.is_empty() or int(g.get("到期日") if "到期日" in g else 0) < 累计游戏日:
		return 0.0
	return min(g.get("pct") if "pct" in g else 0.0, 彩蛋单上限)

# ============ 称号系统 ============
var 称号配置表: Array = []
var _称号已加载: bool = false

func _加载称号配置() -> void:
	if _称号已加载:
		return
	_称号已加载 = true
	var p: String = "res://config/title_config.csv"
	if not FileAccess.file_exists(p):
		return
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()  # 跳过表头
	while not f.eof_reached():
		var row = f.get_csv_line()
		if row == null or row.size() < 11:
			continue
		称号配置表.append({
			"title_id": str(row[0]).strip_edges(),
			"title_name": str(row[1]).strip_edges(),
			"quality": str(row[2]).strip_edges(),
			"target": str(row[3]).strip_edges(),
			"type": str(row[4]).strip_edges(),
			"condition_type": str(row[5]).strip_edges(),
			"condition_param": str(row[6]).strip_edges(),
			"description": str(row[7]).strip_edges(),
			"bonus_type": str(row[8]).strip_edges(),
			"bonus_value": float(row[9]),
			"sort_order": int(row[10])
		})
	f.close()

func 获取称号详情(title_id: String) -> Dictionary:
	_加载称号配置()
	for t in 称号配置表:
		if str(t.get("title_id", "")) == title_id:
			return t.duplicate()
	return {}

func 获取称号品质颜色(quality: String) -> Color:
	match quality:
		"凡品": return Color(0.8, 0.8, 0.8)
		"灵品": return Color(0.3, 0.9, 0.4)
		"宝品": return Color(0.3, 0.6, 1.0)
		"王品": return Color(0.8, 0.4, 1.0)
		"帝品": return Color(1.0, 0.85, 0.2)
		_: return Color(0.8, 0.8, 0.8)

# 检查弟子是否满足称号条件
func _检查称号条件(弟子: Disciple, title: Dictionary) -> bool:
	var cond_type: String = str(title.get("condition_type", ""))
	var cond_param: String = str(title.get("condition_param", ""))
	match cond_type:
		"境界":
			return 弟子.境界 == cond_param
		"职位":
			return 弟子.身份 == cond_param
		"丹道":
			return int(弟子.丹道等级 if "丹道等级" in 弟子 else 0) >= int(cond_param)
		"器道":
			return int(弟子.器道等级 if "器道等级" in 弟子 else 0) >= int(cond_param)
		"斩妖":
			return int(弟子.斩妖数) >= int(cond_param)
		"守护":
			return int(弟子.守护宗门次数) >= int(cond_param)
		"收徒":
			return int(弟子.徒弟列表.size() if "徒弟列表" in 弟子 else 0) >= int(cond_param)
		"年龄":
			return int(弟子.年龄) >= int(cond_param)
		"晚成":
			return int(弟子.年龄) >= 50 and 弟子.境界 == "金丹"
		"里程碑":
			return true  # 里程碑称号由事件触发
		"default":
			return true
	return false

# 判定弟子可获得的新称号
func 判定弟子称号(弟子: Disciple) -> Array:
	_加载称号配置()
	var 新称号: Array = []
	for t in 称号配置表:
		var tid: String = str(t.get("title_id", ""))
		if str(t.get("target", "")) != "弟子":
			continue
		if tid in 弟子.已获得称号:
			continue
		if _检查称号条件(弟子, t):
			弟子.已获得称号.append(tid)
			新称号.append(t)
			# 称号获得纪事
			var 称号名: String = str(t.get("title_name", ""))
			var 品质: String = str(t.get("quality", "凡品"))
			添加纪事("人物", "道号加封", "%s 获封道号「%s」（%s），宗门上下咸知。" % [弟子.姓名, 称号名, 品质], 1)
			# 自动装备品质最高的称号
			if 弟子.当前称号 == "":
				弟子.当前称号 = tid
			else:
				var 当前品质: String = str(获取称号详情(弟子.当前称号).get("quality", "凡品"))
				var 新品质: String = str(t.get("quality", "凡品"))
				var 品质顺序: Array = ["凡品", "灵品", "宝品", "王品", "帝品"]
				if 品质顺序.find(新品质) > 品质顺序.find(当前品质):
					弟子.当前称号 = tid
	return 新称号

# 检查宗主是否满足称号条件
func _检查宗主称号条件(title: Dictionary) -> bool:
	var cond_type: String = str(title.get("condition_type", ""))
	var cond_param: String = str(title.get("condition_param", ""))
	match cond_type:
		"境界":
			if 宗主 != null:
				return 宗主.境界 == cond_param
			return false
		"等级":
			return 门派等级 >= int(cond_param)
		"声望":
			return 声望 >= int(cond_param)
		"弟子":
			return 弟子列表.size() >= int(cond_param)
		"丹道":
			if 宗主 != null:
				return int(宗主.丹道等级 if "丹道等级" in 宗主 else 0) >= int(cond_param)
			return false
		"器道":
			if 宗主 != null:
				return int(宗主.器道等级 if "器道等级" in 宗主 else 0) >= int(cond_param)
			return false
		"奇遇":
			return true  # 奇遇称号由事件触发
		"default":
			return true
	return false

# 判定宗主可获得的新称号
func 判定宗主称号() -> Array:
	_加载称号配置()
	var 新称号: Array = []
	for t in 称号配置表:
		var tid: String = str(t.get("title_id", ""))
		if str(t.get("target", "")) != "宗主":
			continue
		if tid in 宗主已获得称号:
			continue
		if _检查宗主称号条件(t):
			宗主已获得称号.append(tid)
			新称号.append(t)
			# 宗主称号获得纪事
			var 称号名: String = str(t.get("title_name", ""))
			var 品质: String = str(t.get("quality", "凡品"))
			添加纪事("宗主", "道号加封", "宗主获封道号「%s」（%s），威震宗门，声名远播。" % [称号名, 品质], 2)
			# 自动装备品质最高的称号
			if 宗主当前称号 == "":
				宗主当前称号 = tid
			else:
				var 当前品质: String = str(获取称号详情(宗主当前称号).get("quality", "凡品"))
				var 新品质: String = str(t.get("quality", "凡品"))
				var 品质顺序: Array = ["凡品", "灵品", "宝品", "王品", "帝品"]
				if 品质顺序.find(新品质) > 品质顺序.find(当前品质):
					宗主当前称号 = tid
	return 新称号

# 获取宗主称号全局buff加成
func 获取宗主称号加成(bonus_type: String) -> float:
	if 宗主当前称号 == "":
		return 0.0
	var t: Dictionary = 获取称号详情(宗主当前称号)
	if t.is_empty():
		return 0.0
	var t_bonus_type: String = str(t.get("bonus_type", ""))
	if t_bonus_type == bonus_type:
		return float(t.get("bonus_value", 0.0))
	if t_bonus_type == "全属性":
		return float(t.get("bonus_value", 0.0))
	return 0.0

# 获取宗主称号显示文本（用于状态栏）
func 获取宗主称号显示() -> String:
	if 宗主当前称号 == "":
		return ""
	var t: Dictionary = 获取称号详情(宗主当前称号)
	if t.is_empty():
		return ""
	return str(t.get("title_name", ""))

# 获取称号属性加成
func 获取称号加成(弟子: Disciple, bonus_type: String) -> float:
	if 弟子.当前称号 == "":
		return 0.0
	var t: Dictionary = 获取称号详情(弟子.当前称号)
	if t.is_empty():
		return 0.0
	if str(t.get("bonus_type", "")) == bonus_type:
		return float(t.get("bonus_value", 0.0))
	if str(t.get("bonus_type", "")) == "全属性":
		return float(t.get("bonus_value", 0.0))
	return 0.0

# 批量判定所有在宗弟子称号
func 批量判定称号() -> void:
	for d in 弟子列表:
		if d != null and d is Disciple and d.状态 == "在宗":
			判定弟子称号(d)
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
	# 离线收益上限：根据特权加成计算（0氪8小时，最高48小时）
	var 离线上限小时: int = int(获取特权加成().get("离线上限小时", 8))
	var 离线上限日: int = int(离线上限小时 * 3600 / 现实秒每游戏日)
	流失日 = clamp(流失日, 0, min(单次推演上限日, 离线上限日))
	var 剩余 := 流失日
	# E 阶段「进入」卡顿异步化：分块推演，每块让出一帧，主线程不再长冻黑屏
	while 剩余 > 0:
		var 数: int = min(30, 剩余)
		推演一月(数)
		剩余 -= 数
		await get_tree().process_frame
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

# ============ 弟子自主服用丹药（拟人行为；P3.2）============
# 修真设定：弟子是独立人格，会按自身需求从宗门丹药库主动嗑药；
# 仅在存在明确需求（心魔过高/心境过低/寿元临危/大圆满待突破/灵根可洗）时消耗，绝不无脑烧库存。
# 丹药来源多元（贡献兑换/坊市购/自炼/击杀掉落/奇遇），健康宗门增量>日常消耗。
const _灵根序: Array = ["凡品", "良品", "上品", "极品", "天品"]

func _找丹药(关键词: Array) -> int:
	# S37：优先返回【丹纹最高】的匹配丹——好丹先给弟子吃，无纹丹留给玩家卖钱或手动处理
	# 注：宗门库房存 Item 对象，禁用 Dictionary 式 it.get(键, 默认) 两参调用（Item 无此签名 → SCRIPT ERROR）
	var 最佳: int = -1
	var 最佳纹: int = -1
	for i in range(宗门库房.size()):
		var it = 宗门库房[i]
		if not (it is Item):
			continue
		if str(it.类别) != "丹药":
			continue
		var n: String = str(it.名称)
		var 命中: bool = false
		for k in 关键词:
			if k in n:
				命中 = true
				break
		if not 命中:
			continue
		if int(it.丹纹) > 最佳纹:
			最佳纹 = int(it.丹纹)
			最佳 = i
	return 最佳
func _升灵根品阶(d: Object) -> void:
	var idx = _灵根序.find(str(d.灵根品阶))
	if idx >= 0 and idx < _灵根序.size() - 1:
		d.灵根品阶 = _灵根序[idx + 1]

# 把丹药效果实打到弟子身上（姓名子串匹配，复用既有丹药命名约定）。返回摘要文本。
func _应用丹药效果(d: Object, 丹药名: String, 纹: int = 0, 阶: String = "", 品级: String = "", 毒值: float = -1.0, 丹词条: Variant = []) -> String:
	var n = 丹药名
	var 倍: float = 丹纹药效倍率(阶, 纹) * float(丹品级配置(品级).get("effect_scale", 1.0))
	# S41 丹词条聚合：药效乘算、心境加算（全路径生效）、减毒在毒计算处抵扣
	var _agg: Dictionary = 丹词条聚合(丹词条)
	倍 *= (1.0 + float(_agg["药效"]))
	d.心境 = min(100, int(d.心境) + int(_agg["心境"]))
	if 纹 > 0 or 阶 != "":
		var 毒: float = 毒值 if 毒值 >= 0.0 else 丹纹丹毒变化(阶, 纹)
		毒 = max(0.0, 毒 - float(_agg["减毒"]))
		d.丹毒 = clamp(float(d.丹毒) + 毒, 0.0, 6.0)
	if "清心" in n:
		var v1: int = int(round(20.0 * 倍))
		var v2: int = int(round(5.0 * 倍))
		d.心魔值 = max(0, int(d.心魔值) - v1)
		d.心境 = min(100, int(d.心境) + v2)
		return "心魔-%d、道心+%d" % [v1, v2]
	if "静心" in n or "道心" in n or "宁神" in n:
		var v3: int = int(round(15.0 * 倍))
		d.心境 = min(100, int(d.心境) + v3)
		return "心境+%d" % v3
	if "长生" in n or "延寿" in n or "驻颜" in n:
		var v4: int = int(round(30.0 * 倍))
		d.寿元 += v4
		return "寿元+%d" % v4
	if "洗髓" in n:
		_升灵根品阶(d)
		return "灵根提升一阶"
	if "凝金" in n or "破婴" in n or "破境" in n or "冲关" in n or "突破" in n or "破壁" in n:
		var v5: int = int(round(12.0 * 倍))
		d.心境 = min(100, int(d.心境) + v5)
		return "突破成功率提升（心境+%d）" % v5
	var v6: int = int(round(5.0 * 倍))
	d.心境 = min(100, int(d.心境) + v6)
	return "心境+%d" % v6
	# ↑ S39 重写：原实现重复声明 n/倍，且未乘品级、未用锁定毒值
func _消耗宗门库房丹药(i: int, d: Object) -> void:
	var 药: Variant = 宗门库房[i]
	if not (药 is Item):
		return
	# Item 对象：直接取属性（禁用 Dictionary 式两参 .get）
	var 丹药名: String = str(药.名称)
	var 纹: int = int(药.丹纹)
	var 阶: String = str(药.品阶)
	var 级: String = str(药.品级)
	var 毒值: float = float(药.丹毒值)
	var 摘要 = _应用丹药效果(d, 丹药名, 纹, 阶, 级, 毒值, 药.丹词条)
	# S37 丹纹：摘要补纹数，让「炼出好丹」在日志里看得见
	if 纹 > 0:
		摘要 += "（%s·%s）" % [丹纹名(纹), 丹纹服用摘要(阶, 纹)]
	宗门库房.remove_at(i)
	_加推演条目("【%s】自行服用%s，%s" % [str(d.姓名), 丹药名, 摘要], ET_INFO, PRIO_TRIVIAL, {"弟子": str(d.姓名)})
func _弟子自动服用丹药(d: Object) -> void:
	if d == null or 宗门库房 == null or 宗门库房.size() == 0:
		return
	if str(d.状态) in ["陨落", "失踪", "叛出"]:
		return
	# S37：丹毒缠身者暂停自动服药（药毒攻心，须先化毒）——防「每日自动吃无纹丹→毒顶格」的不可控负螺旋
	if float(d.丹毒) >= 2.5:
		return
	if int(d.心魔值) > 50:
		var i = _找丹药(["清心"])
		if i >= 0:
			_消耗宗门库房丹药(i, d)
			return
	if int(d.心境) < 40:
		# §4.0 目标驱动：丹药偏好改由 goal_config 驱动，覆盖全部 9 类目标
		# 注：旧实现把「仁心济世/守礼尊师」（12 型性格名）误当目标名比对 → 永不命中，已剔除
		var 静心词: Array = Goal.丹药关键词(Goal.弟子目标(d))
		if 静心词.is_empty():
			静心词 = ["静心", "道心", "宁神", "清心"]
		var i = _找丹药(静心词)
		if i >= 0:
			_消耗宗门库房丹药(i, d)
			return
	if float(d.年龄) / float(d.寿元) > 0.85:
		var i = _找丹药(["长生", "延寿", "驻颜"])
		if i >= 0:
			_消耗宗门库房丹药(i, d)
			return
	if int(d.层数) >= 10 and int(d.心境) < 90:
		var i = _找丹药(["凝金", "破婴", "破境", "冲关", "突破", "破壁"])
		if i >= 0:
			_消耗宗门库房丹药(i, d)
			return
	if str(d.灵根品阶) not in ["天品", "极品"]:
		var i = _找丹药(["洗髓"])
		if i >= 0:
			_消耗宗门库房丹药(i, d)
			return

# 玩家手动喂食弟子（覆盖式；复用真实效果）。
func 弟子服用丹药(弟子ID: int, 丹药名: String) -> Dictionary:
	if 宗门库房 == null or 宗门库房.size() == 0:
		return {"成功": false, "原因": "宗门丹药库为空"}
	var idx = -1
	for i in range(宗门库房.size()):
		if 宗门库房[i] != null and str(宗门库房[i].get("名称", "")) == 丹药名:
			idx = i
			break
	if idx < 0:
		return {"成功": false, "原因": "丹药库无%s" % 丹药名}
	var d = _取弟子(弟子ID)
	if d == null:
		return {"成功": false, "原因": "弟子不存在"}
	_消耗宗门库房丹药(idx, d)
	return {"成功": true, "原因": "已服用%s" % 丹药名}

# ============ §4.0 目标驱动行为（弟子真人模拟核心）============
# 主目标（人生目标）默认=修成大道，可因事件/状态/性格突变；目标决定大部分自主行为。
# 突变非随机：由 _检查目标突变 按状态+性格触发，或由世界事件(§10.1)调 _突变目标。

# 设定弟子新主目标（突变核心 setter）。保留旧目标为执念，记入目标栈形成因果链。
func _突变目标(d: Object, 新目标: String, 来源: String) -> void:
	if d == null:
		return
	if not ("主目标" in d):
		return
	if str(d.主目标) == 新目标:
		return
	d.执念 = str(d.主目标)
	d.主目标 = 新目标
	if not ("目标栈" in d):
		d.目标栈 = []
	d.目标栈.append({"目标": 新目标, "来源": 来源, "起始日": 累计游戏日})
	_加推演条目("【%s】心境生变，人生目标转为「%s」（%s）" % [str(d.姓名), 新目标, 来源], ET_INFO, PRIO_TRIVIAL, {"弟子": str(d.姓名)})

# 状态+性格驱动的目标突变检查（推演月内调用）：实现"中途受其他影响改变目标"。
func _检查目标突变(d: Object) -> void:
	if d == null or str(d.状态) in ["陨落", "失踪", "叛出"]:
		return
	if not ("主目标" in d):
		return
	var 目标v: String = str(d.主目标)
	# 心魔深重 + 激进性格 → 入魔道
	if int(d.心魔值) >= 80 and str(d.性格) in ["杀伐果断", "狂傲绝世", "桀骜不羁"]:
		_突变目标(d, "魔道", "心魔深重·性格使然")
		return
	# 心境崩坏 → 避世
	if int(d.心境) <= 10 and 目标v != "避世":
		_突变目标(d, "避世", "道心受创·看破红尘")
		return
	# 大机缘（极低概率）→ 问道
	if 目标v == "修成大道" and randf() < 0.0005:
		_突变目标(d, "问道", "偶得大机缘")
		return

	# ---- 自身状态触发源：补齐 复仇/守护/证明自己/权力野心/情劫 的自身触发 ----
	# （此前这 5 类只能由世界事件被动写入，情劫 全仓 0 命中）
	var 伴侣 = (_取弟子(int(d.道侣ID)) if (("道侣ID" in d) and int(d.道侣ID) >= 0) else null)
	# 情劫：道侣在世 + 心境摇动（情深易乱）
	if 目标v != "情劫" and 伴侣 != null and str(伴侣.状态) == "在宗" and int(d.心境) <= 60:
		if randf() < 0.02:
			_突变目标(d, "情劫", "道侣牵绊·情根深种")
			return
	# 道侣罹难：性格决定走向复仇或避世
	if 目标v not in ["复仇", "魔道", "避世"] and 伴侣 != null and str(伴侣.状态) in ["陨落", "失踪", "叛出"]:
		if randf() < 0.08:
			if str(d.性格) in ["杀伐果断", "狂傲绝世", "桀骜不羁", "锐意争先"]:
				_突变目标(d, "复仇", "道侣罹难·矢志复仇")
			else:
				_突变目标(d, "避世", "道侣罹难·万念俱灰")
			return
	# 证明自己：修为已达金丹却仍未授阶，心有不甘
	if 目标v != "证明自己" and str(d.阶位) == "无" and Disciple.境界索引(str(d.境界)) >= Disciple.境界索引("金丹"):
		if str(d.性格) in ["锐意争先", "狂傲绝世"] and randf() < 0.01:
			_突变目标(d, "证明自己", "久居人下·意欲自证")
			return
	# 权力野心：元婴以上 + 好胜性格，觊觎权柄
	if 目标v not in ["权力野心", "魔道"] and Disciple.境界索引(str(d.境界)) >= Disciple.境界索引("元婴"):
		if str(d.性格) in ["锐意争先", "狂傲绝世", "桀骜不羁", "贪心逐缘"] and randf() < 0.008:
			_突变目标(d, "权力野心", "野心滋长·图谋权柄")
			return
	# 守护：年长且有子嗣，重心转向护持后人
	if 目标v != "守护" and ("子嗣列表" in d) and (d.子嗣列表 as Array).size() > 0 and float(d.年龄) >= 200.0:
		if str(d.性格) in ["仁心济世", "守礼尊师", "豪迈仗义", "沉稳守道"] and randf() < 0.015:
			_突变目标(d, "守护", "子嗣绕膝·转为护持")
			return
	# 转世执念：带前世记忆者，初入宗门便已非白纸
	if 目标v == "修成大道" and ("前世记忆" in d) and str(d.前世记忆) != "":
		if randf() < 0.03:
			var 记忆: String = str(d.前世记忆)
			if 记忆.find("冤") >= 0 or 记忆.find("仇") >= 0:
				_突变目标(d, "复仇", "前世含冤·执念未消")
			elif 记忆.find("未竟") >= 0 or 记忆.find("道") >= 0:
				_突变目标(d, "问道", "前世未竟·再求证道")
		return


# ============ §4.0 叛离（目标驱动的离宗判定）============
# 叛出弟子不从名册删除：留在册中以为叙事（可供后续寻回/复仇/图鉴收录），
# 但 状态="叛出" 会被所有「在宗」白名单判点自动排除，不再参与历练/产出/双修。
func _检查叛离(d: Object) -> void:
	if d == null or str(d.状态) != "在宗":
		return
	if 弟子列表.size() > 0 and d == 弟子列表[0]:
		return   # 宗主不叛离
	# §4.0 查抄积怨逐月平复
	# ⚠ 顺序铁律：必须写在叛离判定之前——下方「率<=0 或 未掷中」会提前 return，放后面永远走不到
	if ("查抄积怨" in d) and int(d.查抄积怨) > 0:
		d.查抄积怨 = int(d.查抄积怨) - 1
	var 率: float = Goal.叛离月概率(d)
	if 率 <= 0.0 or randf() >= 率:
		return
	_执行叛离(d)

# P0：低境界弟子道心不稳离去机制（自然消耗，避免弟子只进不出）
# 练气/筑基弟子，心境<30 或 忠诚<30，每年2%概率道心不稳，下山离去
# 与叛离不同：离去是主动离开，不是背叛；不带走宗门贵重物品
func _道心不稳离去判定(d: Object) -> void:
	if d == null or str(d.状态) != "在宗":
		return
	if 弟子列表.size() > 0 and d == 弟子列表[0]:
		return   # 宗主不离去
	# 只针对练气/筑基低境界弟子
	var 序: int = Disciple.境界索引(str(d.境界))
	if 序 > Disciple.境界索引("筑基"):
		return
	# 心境<30 或 忠诚<30 才可能道心不稳
	var 心境值: int = int(d.心境) if d.心境 != null else 50
	var 忠诚值: int = int(d.忠诚) if d.忠诚 != null else 50
	if 心境值 >= 30 and 忠诚值 >= 30:
		return
	# 每年2%概率（月度推演，所以月概率=2%/12≈0.17%）
	var 月概率: float = 0.02 / 12.0
	if randf() >= 月概率:
		return
	# 道心不稳，下山离去
	_执行道心不稳离去(d)

# 执行道心不稳离去：弟子主动下山，带走少量私人物品，宗门装备归还
func _执行道心不稳离去(d: Object) -> void:
	# 归还宗门装备
	for it in d.装备.values():
		宗门库房.append(it)
	d.装备.clear()
	# 背包物品：只带走私库物品，背包物品归还宗门
	for it in d.背包:
		宗门库房.append(it)
	d.背包.clear()
	# 灵兽归还御兽堂
	if d.主宠灵兽 != null:
		var 兽: Beast = d.主宠灵兽
		d.主宠灵兽 = null
		兽.取消出战()
		if not 灵兽管理系统.灵兽库存.has(兽):
			灵兽管理系统.灵兽库存.append(兽)
	if d.副宠灵兽 != null:
		var 兽: Beast = d.副宠灵兽
		d.副宠灵兽 = null
		兽.取消出战()
		if not 灵兽管理系统.灵兽库存.has(兽):
			灵兽管理系统.灵兽库存.append(兽)
	# 设置状态为"离去"
	d.状态 = "离去"
	# 纪事与推演条目
	_加推演条目("【%s】道心不稳，自觉仙缘浅薄，拜别宗门，下山而去" % d.姓名, ET_SECT, PRIO_NORMAL, {"弟子": d.姓名})
	添加纪事("离去", "道心不稳", "%s 道心不稳，自觉仙缘浅薄，拜别宗门，下山而去，自此仙俗两隔" % d.姓名, 1)
	# 断链师父离场
	_断链_师父离场(d.弟子ID)
	# 从弟子列表移除
	弟子列表.erase(d)


# === S29 收徒拜师：师徒传承 + 传功 + 断链（字段已在 Disciple 加，不升 SAVE_VERSION） ===
func 收徒(徒ID: int, 师ID: int) -> Dictionary:
	if 徒ID == 师ID:
		return {"成功": false, "原因": "不可自拜为师"}
	var 徒 = _取弟子(徒ID)
	var 师 = _取弟子(师ID)
	if 徒 == null or 师 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if str(徒.状态) != "在宗" or str(师.状态) != "在宗":
		return {"成功": false, "原因": "双方须同在宗门"}
	if int(徒.师父ID) >= 0:
		return {"成功": false, "原因": "%s 已有师父" % str(徒.姓名)}
	var 师阶: int = Disciple.境界序.find(str(师.境界))
	var 徒阶: int = Disciple.境界序.find(str(徒.境界))
	if 师阶 < 0 or 徒阶 < 0 or (师阶 - 徒阶) < 2:
		return {"成功": false, "原因": "师父须高出至少两大境界"}
	徒.师父ID = 师ID
	if not 师.徒弟列表.has(徒ID):
		师.徒弟列表.append(徒ID)
	var 授功数: int = 0
	for 功法 in 师.已学功法:
		if not 功法 in 徒.已学功法:
			徒.已学功法.append(功法)
			授功数 += 1
	# S30 性格相冲：师徒性格相冲 → 徒心魔涨（强度×5）
	var 相冲强度: int = Disciple.性格相冲度(str(师.性格), str(徒.性格))
	if 相冲强度 > 0:
		徒.增加心魔(相冲强度 * 5)
	_加推演条目("%s 拜 %s 为师，承传功法 %d 式" % [str(徒.姓名), str(师.姓名), 授功数], ET_SECT, PRIO_NORMAL, {"弟子": str(徒.姓名)})
	添加纪事("收徒", "拜师入门", "%s 正式拜入 %s 门下，承蒙传授功法 %d 式，师徒之缘自此结" % [str(徒.姓名), str(师.姓名), 授功数], 1)
	return {"成功": true, "授功数": 授功数, "师名": str(师.姓名), "徒名": str(徒.姓名)}

func 逐师(徒ID: int) -> Dictionary:
	var 徒 = _取弟子(徒ID)
	if 徒 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if int(徒.师父ID) < 0:
		return {"成功": false, "原因": "该弟子无师"}
	var 师ID: int = int(徒.师父ID)
	var 师 = _取弟子(师ID)
	var 师名: String = str(师.姓名) if 师 != null else "故师"
	徒.师父ID = -1
	if 师 != null and 师.徒弟列表.has(徒ID):
		师.徒弟列表.erase(徒ID)
	_加推演条目("%s 已脱离 %s 门下" % [str(徒.姓名), 师名], ET_SECT, PRIO_NORMAL, {"弟子": str(徒.姓名)})
	return {"成功": true, "师名": 师名}

func _断链_师父离场(师ID: int) -> void:
	var 师 = _取弟子(师ID)
	if 师 == null:
		return
	var 受冲击徒: int = 0
	for 徒ID in 师.徒弟列表:
		var 徒 = _取弟子(int(徒ID))
		if 徒 != null and int(徒.师父ID) == 师ID:
			徒.师父ID = -1
			if str(徒.状态) == "在宗":
				# S30 情感冲击：师陨/师叛 → 徒弟 道心↓/忠诚↓/心境↓
				徒.增加道心(-10)
				徒.增加忠诚(-15)
				徒.增加心境(-8)
				受冲击徒 += 1
	师.徒弟列表.clear()
	if 受冲击徒 > 0:
		_加推演条目("【%s】之师离场，门下 %d 徒道心动摇、忠心受挫" % [str(师.姓名), 受冲击徒], ET_SECT, PRIO_NORMAL, {})

func _执行叛离(d: Object) -> void:

	if d == null:
		return
	var 旧目标: String = str(d.主目标) if ("主目标" in d) else "修成大道"
	d.状态 = "叛出"
	_叛离清退司职(d)
	# 断开道侣（双向解链，避免叛出者仍占用伴侣位）
	if ("道侣ID" in d) and int(d.道侣ID) >= 0:
		var 伴侣 = _取弟子(int(d.道侣ID))
		if 伴侣 != null and int(伴侣.道侣ID) == int(d.弟子ID):
			伴侣.道侣ID = -1
			伴侣.道侣 = ""
		d.道侣ID = -1
		d.道侣 = ""
	_断链_师父离场(d.弟子ID)   # S29：师父叛出 → 徒弟弟子失师
	_加推演条目("【%s】心生异志，叛出宗门（原志：%s）" % [str(d.姓名), 旧目标], ET_INFO, PRIO_HIGH, {"弟子": str(d.姓名)})
	添加纪事("叛离", "叛出宗门", "%s 因「%s」之心生变，趁夜叛出宗门，从此恩断义绝" % [str(d.姓名), 旧目标], 2)


func _叛离清退司职(d: Object) -> void:
	if d == null:
		return
	for key in 司职列表.keys():
		var 堂: Dictionary = 司职列表[key]
		var 成员: Array = 堂.get("成员", [])
		if d in 成员:
			成员.erase(d)
			堂["成员"] = 成员
		if 堂.get("负责人", null) == d:
			堂["负责人"] = null
			司职负责人存档[key] = ""
	d.司职 = ""

# ============ §12 人生线（双修/子嗣/飞升/转世）============
# 目标：让弟子成为"真实的人"——有伴侣、有后代、有生死轮回。
# 调用点：推演月内 each 弟子，于 _检查目标突变 之后、推进修炼 之前。
# 返回本月新孕育的子嗣列表（循环外统一 append，避免遍历中改数组）。

const _孕育达标境界: Array = ["金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫", "仙阶", "道阶"]

func _结算弟子人生线(d: Object) -> Array:
	var 新生儿: Array = []
	if d == null or str(d.状态) in ["陨落", "失踪", "叛出"]:
		return 新生儿
	# §12.2 双修结算：道侣互链且双方均在宗 → 修炼速度+15%、心境+2
	_结算双修(d)
	# §12.4 飞升前兆判定：渡劫大圆满弟子提前预警
	_飞升前兆判定(d)
	# §12.4 飞升判定：渡劫境每月小概率白日飞升
	_飞升判定(d)
	# §12.3 孕育子嗣：双方互链+在宗+金丹及以上，月概率≤2%
	if d.道侣ID >= 0 and str(d.状态) == "在宗":
		var 伴侣 = _取弟子(d.道侣ID)
		if 伴侣 != null and 伴侣.道侣ID == d.弟子ID and str(伴侣.状态) == "在宗":
			if d.境界 in _孕育达标境界 and 伴侣.境界 in _孕育达标境界:
				if randf() < 0.02:
					var 孩 = _孕育子嗣(d, 伴侣)
					if 孩 != null:
						新生儿.append(孩)
	return 新生儿

# §12.4 飞升前兆系统：渡劫大圆满弟子提前30游戏日预警，可举办飞升大典
func _飞升前兆判定(d: Object) -> void:
	if d.飞升:
		return
	var 序: int = Disciple.境界索引(str(d.境界))
	if 序 < Disciple.境界索引("渡劫"):
		return
	# 检查是否已在前兆队列
	for 前兆 in 飞升前兆队列:
		if int(前兆["弟子ID"]) == int(d.弟子ID):
			return
	# 渡劫大圆满（层数=9）有5%概率进入飞升前兆
	if int(d.层数) >= 9 and randf() < 0.05:
		飞升前兆队列.append({
			"弟子ID": d.弟子ID, "姓名": d.姓名, "境界": d.境界,
			"预警日": 累计游戏日, "飞升日": 累计游戏日 + 30
		})
		_加推演条目("【%s】修为已达渡劫大圆满，天地感应，飞升之兆初现！三十日内或将历劫飞升" % d.姓名, ET_BREAKTHROUGH, PRIO_HIGH, {"弟子": d.姓名})
		添加纪事("飞升", "飞升前兆", "%s 修为圆满，天地感应，飞升之兆初现" % d.姓名, 2)

# 检查飞升前兆队列，到期触发飞升
func _检查飞升前兆() -> void:
	var 到期列表: Array = []
	for 前兆 in 飞升前兆队列:
		if 累计游戏日 >= int(前兆["飞升日"]):
			到期列表.append(前兆)
	for 前兆 in 到期列表:
		var d = _按ID找弟子(str(前兆["弟子ID"]))
		if d != null and not d.飞升:
			_执行飞升(d)
		飞升前兆队列.erase(前兆)

# 举办飞升大典：消耗资源，增加飞升成功率（对前兆弟子）
func 举办飞升大典(弟子ID: int) -> Dictionary:
	var d = _按ID找弟子(str(弟子ID))
	if d == null:
		return {"成功": false, "原因": "弟子不存在"}
	# 检查是否在飞升前兆队列
	var 在前兆: bool = false
	for 前兆 in 飞升前兆队列:
		if int(前兆["弟子ID"]) == 弟子ID:
			在前兆 = true
			break
	if not 在前兆:
		return {"成功": false, "原因": "该弟子尚无飞升之兆"}
	# 消耗资源：灵石1000+灵草100
	if 灵石 < 1000:
		return {"成功": false, "原因": "灵石不足（需1000）"}
	if 灵草 < 100:
		return {"成功": false, "原因": "灵草不足（需100）"}
	灵石 -= 1000
	灵草 -= 100
	# 立即触发飞升（成功率提升至80%）
	if randf() < 0.8:
		_执行飞升(d)
		return {"成功": true, "消息": "%s 在飞升大典中历劫功成，白日飞升！" % d.姓名}
	else:
		_加推演条目("【%s】飞升大典中渡劫失败，修为受损，需再修时日" % d.姓名, ET_INFO, PRIO_NORMAL, {"弟子": d.姓名})
		return {"成功": false, "原因": "渡劫失败，修为受损"}

# §12.2 双修结算（每月写回 d.双修加成，供推进修炼乘区使用）
func _结算双修(d: Object) -> void:
	var 伴侣 = (_取弟子(d.道侣ID) if d.道侣ID >= 0 else null)
	if 伴侣 != null and 伴侣.道侣ID == d.弟子ID and str(d.状态) == "在宗" and str(伴侣.状态) == "在宗":
		d.双修加成 = 0.15
		if int(d.心境) < 100:
			d.心境 = int(d.心境) + 2
	else:
		d.双修加成 = 0.0

# ============ 散仙/鬼仙系统（修真世界观正确设定）============
# 散仙：渡劫失败后兵解，舍弃肉身以元婴存活，寿元1000年，每300年一次散仙劫
# 鬼仙：大乘期特殊情况兵解，寿元500年，每200年一次鬼仙劫
# 散仙/鬼仙不占弟子编制，独立存储，可参与宗门防御
# 渡过九次劫数后真正飞升，入祖师堂

# 散仙/鬼仙数据存储（独立于弟子列表，不占编制）
var 散仙列表: Array = []   # 散仙/鬼仙档案：{弟子ID,姓名,类型(散仙/鬼仙),寿元,已渡劫数,战力,功德,业力}

# §12.4 飞升判定：渡劫及以上弟子每月小概率历劫功成、白日飞升
# 大乘期不直接飞升，只有特殊情况才会兵解成为鬼仙
func _飞升判定(d: Object) -> void:
	if d.飞升:
		return
	var 序: int = Disciple.境界索引(str(d.境界))
	# 大乘期特殊情况兵解→鬼仙（寿元将尽或身受重伤）
	if 序 == Disciple.境界索引("大乘"):
		_大乘期特殊兵解判定(d)
		return
	if 序 < Disciple.境界索引("渡劫"):
		return   # 未达渡劫（含未知境界）不可能飞升
	# 境界越高，飞升概率越大：渡劫 2% / 仙阶 5% / 道阶 10%
	var 飞升率: float = [0.02, 0.05, 0.10][clamp(序 - Disciple.境界索引("渡劫"), 0, 2)]
	if randf() < 飞升率:
		_执行飞升(d)

# 大乘期特殊情况兵解判定（寿元将尽或身受重伤）
# 正常大乘期不会兵解，只有特殊情况才会
func _大乘期特殊兵解判定(d: Object) -> void:
	# 寿元将尽（剩余寿元<100年）且无法突破
	var 剩余寿元: float = float(d.寿元) - float(d.年龄)
	if 剩余寿元 > 100:
		return
	# 身受重伤（战力<50%）
	var 基础战力: float = float(Disciple.境界表[str(d.境界)]["战力"])
	if float(d.战力) > 基础战力 * 0.5:
		return
	# 特殊情况：寿元将尽且身受重伤，有5%概率选择兵解成为鬼仙
	if randf() >= 0.05:
		return
	_执行兵解成鬼仙(d)

# 执行兵解成鬼仙（大乘期特殊情况）
func _执行兵解成鬼仙(d: Object) -> void:
	# 归还宗门物品
	_兵解归还物品(d)
	# 成为鬼仙，不占弟子编制
	var 鬼仙: Dictionary = {
		"弟子ID": d.弟子ID, "姓名": d.姓名, "类型": "鬼仙",
		"原境界": d.境界, "寿元": 500, "已渡劫数": 0,
		"战力": int(float(d.战力) * 0.3),  # 鬼仙战力只有生前30%
	"功德": int(d.功德) if d.功德 != null else 0,
	"业力": int(d.业力) if d.业力 != null else 0,
		"兵解日": 累计游戏日, "下次劫日": 累计游戏日 + 200
	}
	散仙列表.append(鬼仙)
	# 纪事与推演条目
	_加推演条目("【%s】寿元将尽且身受重伤，毅然兵解，舍弃肉身，以元婴成鬼仙！" % d.姓名, ET_INFO, PRIO_HIGH, {"弟子": d.姓名})
	添加纪事("兵解", "成为鬼仙", "%s 寿元将尽且身受重伤，毅然兵解，舍弃肉身，以元婴成鬼仙，守护宗门" % d.姓名, 2)
	# 从弟子列表移除
	弟子列表.erase(d)

# 渡劫失败兵解→散仙（在渡劫失败时调用）
func 渡劫失败兵解成散仙(d: Object) -> void:
	# 归还宗门物品
	_兵解归还物品(d)
	# 成为散仙，不占弟子编制
	var 散仙: Dictionary = {
		"弟子ID": d.弟子ID, "姓名": d.姓名, "类型": "散仙",
		"原境界": d.境界, "寿元": 1000, "已渡劫数": 0,
		"战力": int(float(d.战力) * 0.5),  # 散仙战力有生前50%
	"功德": int(d.功德) if d.功德 != null else 0,
	"业力": int(d.业力) if d.业力 != null else 0,
		"兵解日": 累计游戏日, "下次劫日": 累计游戏日 + 300
	}
	散仙列表.append(散仙)
	# 纪事与推演条目
	_加推演条目("【%s】渡劫失败，兵解成仙，舍弃肉身，以元婴成散仙！" % d.姓名, ET_INFO, PRIO_HIGH, {"弟子": d.姓名})
	添加纪事("兵解", "成为散仙", "%s 渡劫失败，兵解成仙，舍弃肉身，以元婴成散仙，隐居宗门灵脉" % d.姓名, 2)
	# 从弟子列表移除
	弟子列表.erase(d)

# 兵解时归还宗门物品（通用函数）
func _兵解归还物品(d: Object) -> void:
	# 装备归还宗门
	for it in d.装备.values():
		宗门库房.append(it)
	d.装备.clear()
	# 背包归还宗门
	for it in d.背包:
		宗门库房.append(it)
	d.背包.clear()
	# 灵兽归还御兽堂
	if d.主宠灵兽 != null:
		var 兽: Beast = d.主宠灵兽
		d.主宠灵兽 = null
		兽.取消出战()
		if not 灵兽管理系统.灵兽库存.has(兽):
			灵兽管理系统.灵兽库存.append(兽)
	if d.副宠灵兽 != null:
		var 兽: Beast = d.副宠灵兽
		d.副宠灵兽 = null
		兽.取消出战()
		if not 灵兽管理系统.灵兽库存.has(兽):
			灵兽管理系统.灵兽库存.append(兽)

# 散仙/鬼仙月度结算（寿元消耗+劫数判定）
func _散仙月度结算() -> void:
	if 散仙列表.is_empty():
		return
	var 待移除: Array = []
	for 仙 in 散仙列表:
		# 寿元消耗（每月1年）
		仙["寿元"] = int(仙["寿元"]) - 1
		# 寿元耗尽，形神俱灭
		if int(仙["寿元"]) <= 0:
			待移除.append(仙)
			_加推演条目("【%s】%s寿元耗尽，形神俱灭，惜哉！" % [仙["姓名"], 仙["类型"]], ET_INFO, PRIO_NORMAL, {})
			添加纪事("陨落", "形神俱灭", "%s %s寿元耗尽，形神俱灭，自此世间再无此人" % [仙["姓名"], 仙["类型"]], 1)
			continue
		# 劫数判定
		if 累计游戏日 >= int(仙["下次劫日"]):
			_散仙渡劫(仙)
	# 移除形神俱灭的散仙/鬼仙
	for 仙 in 待移除:
		散仙列表.erase(仙)

# 散仙/鬼仙渡劫（每300/200年一次）
func _散仙渡劫(仙: Dictionary) -> void:
	var 劫数: int = int(仙["已渡劫数"]) + 1
	var 类型: String = str(仙["类型"])
	# 劫数难度递增：第N次劫成功率=80% - N*5%
	var 成功率: float = 0.80 - float(劫数) * 0.05
	成功率 = clamp(成功率, 0.20, 0.80)
	if randf() < 成功率:
		# 渡劫成功
		仙["已渡劫数"] = 劫数
		var 下次间隔: int = 300 if 类型 == "散仙" else 200
		仙["下次劫日"] = 累计游戏日 + 下次间隔
		# 战力提升
		仙["战力"] = int(float(仙["战力"]) * 1.1)
		_加推演条目("【%s】%s渡过第%d次劫数，道行精进！" % [仙["姓名"], 类型, 劫数], ET_INFO, PRIO_NORMAL, {})
		# 渡过九次劫数→真正飞升
		if 劫数 >= 9:
			_散仙飞升(仙)
	else:
		# 渡劫失败，形神俱灭
		散仙列表.erase(仙)
		_加推演条目("【%s】%s第%d次劫数失败，形神俱灭，惜哉！" % [仙["姓名"], 类型, 劫数], ET_INFO, PRIO_HIGH, {})
		添加纪事("陨落", "渡劫失败", "%s %s第%d次劫数失败，形神俱灭" % [仙["姓名"], 类型, 劫数], 2)

# 散仙/鬼仙渡过九劫→真正飞升，入祖师堂
func _散仙飞升(仙: Dictionary) -> void:
	散仙列表.erase(仙)
	# 入祖师堂
	祖师堂.append({
		"弟子ID": 仙["弟子ID"], "姓名": 仙["姓名"], "境界": 仙["原境界"],
		"飞升日": 累计游戏日, "飞升路线": "散仙飞升",
		"传承列表": ["散仙九劫飞升"], "功德": 仙["功德"], "业力": 仙["业力"],
		"飞升方式": "散仙飞升", "散仙劫数": 9
	})
	# 纪事与推演条目
	_加推演条目("【%s】%s渡过九次劫数，功德圆满，白日飞升！" % [仙["姓名"], 仙["类型"]], ET_BREAKTHROUGH, PRIO_HIGH, {"弟子": 仙["姓名"]})
	添加纪事("飞升", "散仙飞升", "%s %s渡过九次劫数，功德圆满，白日飞升，位列仙班" % [仙["姓名"], 仙["类型"]], 3)
	# 飞升回馈：全宗修炼加成+1%
	_加推演条目("【祖师堂】%s 散仙飞升，宗门气运加持，全宗修炼速度永久+1%%" % 仙["姓名"], ET_SECT, PRIO_NORMAL, {})

# 获取散仙/鬼仙总战力（用于宗门防御）
func 获取散仙总战力() -> int:
	var 总战力: int = 0
	for 仙 in 散仙列表:
		总战力 += int(仙["战力"])
	return 总战力

# ============ 身外化身系统（§6.21 / §11.8.13）============
# 元婴期解锁，消耗资源创建化身
# 化身以散修身份游历天下，触发奇遇，所得资源反哺宗门
# 化身实力不超过本体50%，月度价值≤宗门产出10%
# 偏休闲+角色扮演玩法

# 化身数据存储（独立于弟子列表，不占编制）
var 化身列表: Array = []   # 化身档案：{化身ID,姓名,境界,战力,性格,道心,当前位置,游历状态,背包,人脉}
var 化身切换冷却结束日: int = 0   # 化身切换冷却（1游戏日=240现实秒，设定1小时现实=15游戏日）

# 化身创建配置
const 化身创建消耗: Dictionary = {"灵石": 10000, "灵草": 500, "元婴丹": 1}
const 化身解锁境界: String = "元婴"   # 元婴期解锁化身
const 化身实力上限比例: float = 0.5   # 化身实力不超过本体50%
const 化身月度价值上限比例: float = 0.10   # 化身月度价值≤宗门产出10%

# ============ 化身皮肤/立绘系统（预留接口）============
# 设计：化身立绘可出售，仙玉购买，高级抽奖获取
# 皮肤品质：普通/稀有/史诗/传说/限定
var 已拥有化身皮肤: Array = ["默认男", "默认女"]   # 已拥有的皮肤ID列表
var 化身皮肤配置: Dictionary = {
	# 普通皮肤（仙玉购买）
	"青衫客": {"品质": "普通", "价格": 100, "性别": "男", "描述": "青衫磊落，江湖侠客"},
	"白衣仙": {"品质": "普通", "价格": 100, "性别": "女", "描述": "白衣胜雪，仙子临凡"},
	"玄衣卫": {"品质": "普通", "价格": 150, "性别": "男", "描述": "玄衣如墨，冷面寒枪"},
	"紫霞女": {"品质": "普通", "价格": 150, "性别": "女", "描述": "紫霞绕身，剑气如虹"},
	# 稀有皮肤（仙玉购买）
	"剑仙": {"品质": "稀有", "价格": 500, "性别": "男", "描述": "一剑破万法，剑仙临尘"},
	"琴魔": {"品质": "稀有", "价格": 500, "性别": "女", "描述": "琴音摄魂，魔音灌耳"},
	"丹圣": {"品质": "稀有", "价格": 600, "性别": "男", "描述": "丹道通神，活死人肉白骨"},
	"符仙": {"品质": "稀有", "价格": 600, "性别": "女", "描述": "符法通天，一纸定乾坤"},
	# 史诗皮肤（抽奖获取）
	"真龙天子": {"品质": "史诗", "价格": 0, "性别": "男", "描述": "真龙转世，九五之尊", "抽奖概率": 0.05},
	"九天玄女": {"品质": "史诗", "价格": 0, "性别": "女", "描述": "九天玄女，战神临凡", "抽奖概率": 0.05},
	"魔尊": {"品质": "史诗", "价格": 0, "性别": "男", "描述": "魔道至尊，君临天下", "抽奖概率": 0.03},
	"妖皇": {"品质": "史诗", "价格": 0, "性别": "女", "描述": "万妖之皇，魅惑众生", "抽奖概率": 0.03},
	# 传说皮肤（抽奖获取，极低概率）
	"鸿钧老祖": {"品质": "传说", "价格": 0, "性别": "男", "描述": "鸿钧一道传三友，万仙之师", "抽奖概率": 0.01},
	"女娲娘娘": {"品质": "传说", "价格": 0, "性别": "女", "描述": "女娲补天，造人救世", "抽奖概率": 0.01},
}
const 化身抽奖消耗: int = 100   # 每次抽奖消耗仙玉
const 化身抽奖保底次数: int = 50   # 50次保底史诗以上

## 购买化身皮肤
func 购买化身皮肤(皮肤ID: String) -> Dictionary:
	if not 化身皮肤配置.has(皮肤ID):
		return {"成功": false, "原因": "无此皮肤"}
	var 配置: Dictionary = 化身皮肤配置[皮肤ID]
	if int(配置["价格"]) <= 0:
		return {"成功": false, "原因": "此皮肤仅可通过抽奖获取"}
	if 已拥有化身皮肤.has(皮肤ID):
		return {"成功": false, "原因": "已拥有此皮肤"}
	if 仙玉_绑定 < int(配置["价格"]):
		return {"成功": false, "原因": "仙玉不足（需%d）" % int(配置["价格"])}
	仙玉_绑定 -= int(配置["价格"])
	已拥有化身皮肤.append(皮肤ID)
	添加纪事("大事件", "化身皮肤", "购得化身皮肤【%s】" % 皮肤ID, 2)
	return {"成功": true, "皮肤": 皮肤ID}

## 化身皮肤抽奖
func 化身皮肤抽奖(次数: int = 1) -> Dictionary:
	var 消耗: int = 化身抽奖消耗 * 次数
	if 仙玉_绑定 < 消耗:
		return {"成功": false, "原因": "仙玉不足（需%d）" % 消耗}
	仙玉_绑定 -= 消耗
	var 结果: Array = []
	for i in range(次数):
		var 品质: String = _化身抽奖品质()
		var 候选皮肤: Array = []
		for 皮肤ID in 化身皮肤配置:
			var 配置: Dictionary = 化身皮肤配置[皮肤ID]
			if 配置["品质"] == 品质:
				候选皮肤.append(皮肤ID)
		if 候选皮肤.size() > 0:
			var 获得皮肤: String = str(候选皮肤[randi() % 候选皮肤.size()])
			结果.append(获得皮肤)
			if not 已拥有化身皮肤.has(获得皮肤):
				已拥有化身皮肤.append(获得皮肤)
	添加纪事("大事件", "化身抽奖", "化身皮肤抽奖%d次，获得%s" % [次数, "、".join(结果)], 2)
	return {"成功": true, "结果": 结果}

## 抽奖品质判定
func _化身抽奖品质() -> String:
	var r: float = randf()
	if r < 0.01:
		return "传说"
	elif r < 0.08:
		return "史诗"
	elif r < 0.30:
		return "稀有"
	else:
		return "普通"

## 装备化身皮肤
func 装备化身皮肤(化身ID: int, 皮肤ID: String) -> Dictionary:
	var 化身: Dictionary = _获取化身(化身ID)
	if 化身.is_empty():
		return {"成功": false, "原因": "化身不存在"}
	if not 已拥有化身皮肤.has(皮肤ID):
		return {"成功": false, "原因": "未拥有此皮肤"}
	var 配置: Dictionary = 化身皮肤配置.get(皮肤ID, {})
	if 配置.has("性别") and str(配置["性别"]) != str(化身.get("性别", "男")):
		return {"成功": false, "原因": "此皮肤为%s性，化身性别不符" % 配置["性别"]}
	化身["皮肤"] = 皮肤ID
	添加纪事("庶务", "化身皮肤", "化身%s装备皮肤【%s】" % [化身["姓名"], 皮肤ID], 1)
	return {"成功": true, "化身": 化身["姓名"], "皮肤": 皮肤ID}

# 游历区域配置（不同区域机缘偏向不同）
const 游历区域: Dictionary = {
	"蛮荒之地": {"描述": "妖兽横行，机缘偏妖兽材料", "危险度": 0.6, "奇遇概率": 0.15, "产出偏向": "妖兽材料"},
	"仙城闹市": {"描述": "繁华仙城，机缘偏坊市商机", "危险度": 0.1, "奇遇概率": 0.20, "产出偏向": "灵石商机"},
	"深山老林": {"描述": "隐世高人出没，机缘偏传承", "危险度": 0.3, "奇遇概率": 0.10, "产出偏向": "功法传承"},
	"东海之滨": {"描述": "海市蜃楼，机缘偏天材地宝", "危险度": 0.4, "奇遇概率": 0.12, "产出偏向": "天材地宝"},
	"北境雪原": {"描述": "苦寒之地，机缘偏冰属性宝物", "危险度": 0.5, "奇遇概率": 0.08, "产出偏向": "冰属性宝物"},
	"南疆密林": {"描述": "瘴气弥漫，机缘偏毒丹灵药", "危险度": 0.45, "奇遇概率": 0.10, "产出偏向": "毒丹灵药"}
}

# 奇遇事件池（角色扮演元素）
const 化身奇遇池: Array = [
	{"id": "偶遇高人", "描述": "路遇隐世高人指点，道心大涨", "效果": "道心+10", "奖励": {"道心": 10}},
	{"id": "捡获秘籍", "描述": "于山洞中捡获残破功法", "效果": "获得功法残卷", "奖励": {"功法残卷": 1}},
	{"id": "路见不平", "描述": "出手相助被欺压的散修", "效果": "人脉+1，道心+5", "奖励": {"人脉": 1, "道心": 5}},
	{"id": "加入商队", "描述": "加入商队护送货物，获得报酬", "效果": "灵石+500", "奖励": {"灵石": 500}},
	{"id": "妖兽围攻", "描述": "遭遇妖兽围攻，苦战得脱", "效果": "道行+50，妖兽材料+3", "奖励": {"战力": 50, "妖兽内丹一阶": 3}},
	{"id": "坊市捡漏", "描述": "在坊市以低价购得宝物", "效果": "灵石-200，获得天材地宝", "奖励": {"灵石": -200, "圣品灵草": 1}},
	{"id": "闭关感悟", "描述": "寻得灵地闭关，修为精进", "效果": "修炼进度+30天", "奖励": {"修炼进度": 30}},
	{"id": "结交道友", "描述": "与志同道合的散修结为道友", "效果": "人脉+2", "奖励": {"人脉": 2}},
	{"id": "遭遇劫匪", "描述": "遭遇劫匪，损失部分财物", "效果": "灵石-300", "奖励": {"灵石": -300}},
	{"id": "灵药现世", "描述": "发现千年灵药", "效果": "获得灵草+10", "奖励": {"灵草": 10}}
]

# 检查是否可以创建化身
func 可创建化身() -> Dictionary:
	# 检查宗主境界
	var 宗主: Object = 弟子列表[0] if 弟子列表.size() > 0 else null
	if 宗主 == null:
		return {"成功": false, "原因": "宗主不存在"}
	var 宗主境界序: int = Disciple.境界索引(str(宗主.境界))
	if 宗主境界序 < Disciple.境界索引(化身解锁境界):
		return {"成功": false, "原因": "宗主需达%s期方可修炼身外化身" % 化身解锁境界}
	# 检查化身数量上限（元婴1个，化神2个，炼虚3个，合体4个，大乘5个）
	var 化身上限: int = 1
	if 宗主境界序 >= Disciple.境界索引("化神"):
		化身上限 = 2
	if 宗主境界序 >= Disciple.境界索引("炼虚"):
		化身上限 = 3
	if 宗主境界序 >= Disciple.境界索引("合体"):
		化身上限 = 4
	if 宗主境界序 >= Disciple.境界索引("大乘"):
		化身上限 = 5
	if 化身列表.size() >= 化身上限:
		return {"成功": false, "原因": "已达化身数量上限（%d个）" % 化身上限}
	# 检查资源
	if 灵石 < 化身创建消耗["灵石"]:
		return {"成功": false, "原因": "灵石不足（需%d）" % 化身创建消耗["灵石"]}
	if 灵草 < 化身创建消耗["灵草"]:
		return {"成功": false, "原因": "灵草不足（需%d）" % 化身创建消耗["灵草"]}
	return {"成功": true, "化身上限": 化身上限}

# 创建化身（可选择性别，默认继承宗主性别）
func 创建化身(化身姓名: String = "", 化身性别: String = "") -> Dictionary:
	var 检查: Dictionary = 可创建化身()
	if not 检查.get("成功", false):
		return 检查
	# 消耗资源
	灵石 -= 化身创建消耗["灵石"]
	灵草 -= 化身创建消耗["灵草"]
	# 创建化身
	var 宗主: Object = 弟子列表[0]
	var 化身ID: int = randi()
	# 性别处理：默认继承宗主性别，可手动选择
	var 实际性别: String = 化身性别 if 化身性别 in ["男", "女"] else 宗主性别
	var 姓名: String = 化身姓名 if 化身姓名 != "" else _随机化身姓名_按性别(实际性别)
	var 化身: Dictionary = {
		"化身ID": 化身ID,
		"姓名": 姓名,
		"性别": 实际性别,   # 化身性别（可独立选择，方便皮肤/立绘系统）
		"境界": "练气",   # 化身从练气开始
		"层数": 0,
		"修炼进度": 0.0,
		"战力": int(float(宗主.战力) * 0.1),   # 初始战力为宗主10%
		"性格": Disciple.性格表.pick_random(),
		"道心": 50,
		"当前位置": "宗门附近",
		"游历状态": "闲置",   # 闲置/游历中/闭关
		"游历区域": "",
		"游历结束日": 0,
		"背包": {},   # 化身背包（临时存储，月度反哺宗门）
		"人脉": 0,
		"皮肤": "默认",   # 化身皮肤/立绘（预留，仙玉购买/抽奖）
		"创建日": 累计游戏日,
		"本月已反哺价值": 0
	}
	化身列表.append(化身)
	_加推演条目("【宗主】修炼身外化身，以一缕元神分化出化身「%s」，自此可分身游历天下！" % 姓名, ET_BREAKTHROUGH, PRIO_HIGH, {})
	添加纪事("化身", "创建化身", "宗主修炼身外化身，分化出化身「%s」，可代宗主游历天下" % 姓名, 3)
	return {"成功": true, "化身ID": 化身ID, "姓名": 姓名}

# 随机化身姓名（继承宗主性别）
func _随机化身姓名() -> String:
	return _随机化身姓名_按性别(宗主性别)

# 派遣化身游历
func 派遣化身游历(化身ID: int, 区域: String) -> Dictionary:
	var 化身: Dictionary = _获取化身(化身ID)
	if 化身.is_empty():
		return {"成功": false, "原因": "化身不存在"}
	if str(化身["游历状态"]) == "游历中":
		return {"成功": false, "原因": "化身正在游历中"}
	if not 游历区域.has(区域):
		return {"成功": false, "原因": "未知游历区域"}
	化身["游历状态"] = "游历中"
	化身["游历区域"] = 区域
	化身["游历结束日"] = 累计游戏日 + 60   # 每次游历60游戏日=4现实小时（与红尘历练一致）
	_加推演条目("【化身%s】前往%s游历，寻机缘求大道" % [化身["姓名"], 区域], ET_INFO, PRIO_NORMAL, {})
	return {"成功": true, "消息": "化身%s已前往%s游历，60日后归来" % [化身["姓名"], 区域]}

# 化身月度结算（游历推进+奇遇触发+资源反哺）
func _化身月度结算() -> void:
	if 化身列表.is_empty():
		return
	for 化身 in 化身列表:
		if str(化身["游历状态"]) != "游历中":
			continue
		# 检查游历是否结束
		if 累计游戏日 >= int(化身["游历结束日"]):
			_化身游历归来(化身)
		else:
			# 游历中，每月有概率触发奇遇
			var 区域配置: Dictionary = 游历区域.get(str(化身["游历区域"]), {})
			var 奇遇概率: float = float(区域配置.get("奇遇概率", 0.1))
			if randf() < 奇遇概率:
				_触发化身奇遇(化身)
			# 游历中修炼（每月推进15天修炼进度）
			化身["修炼进度"] = float(化身["修炼进度"]) + 15.0
			_检查化身突破(化身)

# 化身游历归来
func _化身游历归来(化身: Dictionary) -> void:
	化身["游历状态"] = "闲置"
	化身["当前位置"] = "宗门附近"
	# 游历归来，自动反哺资源
	_化身资源反哺(化身)
	# P1-2.1 大地图联动：化身游历归来，记入五域足迹（不复用 Disciple.状态，独立记账）
	if 世界地图系统 != null:
		世界地图系统.记录化身归来(化身)
	_加推演条目("【化身%s】游历归来，带回诸多机缘" % 化身["姓名"], ET_INFO, PRIO_NORMAL, {})

# 触发化身奇遇（角色扮演元素）
func _触发化身奇遇(化身: Dictionary) -> void:
	var 奇遇: Dictionary = 化身奇遇池.pick_random()
	var 描述: String = str(奇遇["描述"])
	var 奖励: Dictionary = 奇遇["奖励"]
	# 应用奖励
	for key in 奖励.keys():
		var 值: int = int(奖励[key])
		if key == "道心":
			化身["道心"] = int(化身["道心"]) + 值
		elif key == "人脉":
			化身["人脉"] = int(化身["人脉"]) + 值
		elif key == "战力":
			化身["战力"] = int(化身["战力"]) + 值
		elif key == "修炼进度":
			化身["修炼进度"] = float(化身["修炼进度"]) + float(值)
		elif key == "灵石":
			# 灵石直接进入化身背包（月度反哺）
			var 当前灵石: int = int(化身["背包"].get("灵石", 0))
			化身["背包"]["灵石"] = 当前灵石 + 值
		elif key == "灵草":
			var 当前灵草: int = int(化身["背包"].get("灵草", 0))
			化身["背包"]["灵草"] = 当前灵草 + 值
		else:
			# 其他材料进入背包
			var 当前: int = int(化身["背包"].get(key, 0))
			化身["背包"][key] = 当前 + 值
	_加推演条目("【化身%s·奇遇】%s" % [化身["姓名"], 描述], ET_INFO, PRIO_NORMAL, {})
	# 检查突破
	_检查化身突破(化身)

# 检查化身突破
func _检查化身突破(化身: Dictionary) -> void:
	var 当前境界序: int = Disciple.境界索引(str(化身["境界"]))
	var 所需日: float = float(Disciple.每层所需日_新.get(str(化身["境界"]), 30.0)) * 9.0   # 大圆满需要9层
	if float(化身["修炼进度"]) >= 所需日:
		# 突破到下一境界
		var 下一境界序: int = 当前境界序 + 1
		if 下一境界序 < Disciple.境界序.size():
			var 下一境界: String = Disciple.境界序[下一境界序]
			# 化身实力不超过宗主50%
			var 宗主: Object = 弟子列表[0] if 弟子列表.size() > 0 else null
			var 战力上限: int = int(float(宗主.战力) * 化身实力上限比例) if 宗主 != null else 999999
			var 新战力: int = int(Disciple.境界表[下一境界]["战力"] * 0.3)   # 化身战力为同境界30%
			新战力 = min(新战力, 战力上限)
			化身["境界"] = 下一境界
			化身["层数"] = 0
			化身["修炼进度"] = 0.0
			化身["战力"] = 新战力
			_加推演条目("【化身%s】修为精进，突破至%s！" % [化身["姓名"], 下一境界], ET_BREAKTHROUGH, PRIO_HIGH, {})

# 化身资源反哺（游历归来后自动将背包资源送回宗门）
func _化身资源反哺(化身: Dictionary) -> void:
	var 背包: Dictionary = 化身["背包"]
	if 背包.is_empty():
		return
	# 计算本月反哺价值（上限为宗门产出10%）
	var 反哺价值: int = 0
	var 月度上限: int = int(_估算宗门月产出() * 化身月度价值上限比例)
	for key in 背包.keys():
		var 数量: int = int(背包[key])
		var 单价: int = _获取物品单价(key)
		反哺价值 += 数量 * 单价
	# 如果超过上限，按比例缩减
	if 反哺价值 > 月度上限 and 月度上限 > 0:
		var 缩减比例: float = float(月度上限) / float(反哺价值)
		for key in 背包.keys():
			背包[key] = int(int(背包[key]) * 缩减比例)
	# 反哺到宗门
	for key in 背包.keys():
		var 数量: int = int(背包[key])
		if 数量 <= 0:
			continue
		if key == "灵石":
			灵石 += 数量
		elif key == "灵草":
			灵草 += 数量
		elif key == "妖兽内丹一阶":
			妖兽内丹["一阶"] += 数量
		elif key == "圣品灵草":
			圣品灵草 += 数量
	_加推演条目("【化身%s】将游历所得反哺宗门，共计%d份资源" % [化身["姓名"], 反哺价值], ET_SECT, PRIO_NORMAL, {})
	# 清空背包
	化身["背包"] = {}
	化身["本月已反哺价值"] = 反哺价值

# 估算宗门月产出（用于化身反哺上限计算）
func _估算宗门月产出() -> int:
	# 简化估算：弟子数量×境界平均产出
	var 总产出: int = 0
	for d in 弟子列表:
		if d != null and str(d.状态) == "在宗":
			var 境界战力: int = int(Disciple.境界表.get(str(d.境界), {}).get("战力", 100))
			总产出 += int(境界战力 / 100)   # 每100战力月产出1单位价值
	return max(总产出, 100)

# 获取物品单价（简化）
func _获取物品单价(物品名: String) -> int:
	var 价格表: Dictionary = {
		"灵石": 1, "灵草": 2, "妖兽内丹一阶": 5, "圣品灵草": 50,
		"功法残卷": 100, "冰属性宝物": 30, "毒丹灵药": 20
	}
	return int(价格表.get(物品名, 10))

# 获取化身
func _获取化身(化身ID: int) -> Dictionary:
	for 化身 in 化身列表:
		if int(化身["化身ID"]) == 化身ID:
			return 化身
	return {}

# ============ 红尘历练系统（化身入凡·红尘炼心）============
# 修真世界观：化身可入凡人王朝，体验人生百态，磨练道心
# 每甲子（60年）更换一次人生，凡人寿命约60年
# 不同职业有不同历练效果，娶妻生子增加人生阅历
# 红尘阅历可转化为道心加成，影响化身修炼速度

# 凡人职业配置（不同职业有不同历练效果）
const 凡人职业: Dictionary = {
	"厨师": {"描述": "掌勺大厨，遍尝人间百味", "道心加成": 2, "人脉加成": 1, "灵石收入": 50, "阅历类型": "人间百味"},
	"医者": {"描述": "悬壶济世，救死扶伤", "道心加成": 3, "人脉加成": 2, "灵石收入": 80, "阅历类型": "生老病死"},
	"士兵": {"描述": "沙场征战，保家卫国", "道心加成": 2, "战力加成": 10, "灵石收入": 40, "阅历类型": "铁血沙场"},
	"将军": {"描述": "运筹帷幄，决胜千里", "道心加成": 4, "战力加成": 30, "灵石收入": 200, "阅历类型": "权谋兵法"},
	"书生": {"描述": "寒窗苦读，金榜题名", "道心加成": 3, "人脉加成": 2, "灵石收入": 60, "阅历类型": "诗书礼仪"},
	"商人": {"描述": "走南闯北，富甲一方", "道心加成": 1, "人脉加成": 3, "灵石收入": 150, "阅历类型": "世态炎凉"},
	"工匠": {"描述": "匠心独运，精益求精", "道心加成": 2, "战力加成": 5, "灵石收入": 70, "阅历类型": "匠心之道"},
	"农夫": {"描述": "日出而作，日落而息", "道心加成": 1, "灵石收入": 30, "阅历类型": "田园之乐"},
	"猎户": {"描述": "深山狩猎，与兽为伴", "道心加成": 2, "战力加成": 8, "灵石收入": 45, "阅历类型": "山野生存"},
	"戏子": {"描述": "粉墨登场，演绎人生", "道心加成": 3, "人脉加成": 1, "灵石收入": 55, "阅历类型": "戏如人生"}
}

# 红尘历练事件池（角色扮演深度）
const 红尘事件池: Array = [
	{"id": "初入凡尘", "描述": "化身初入凡尘，对一切充满好奇", "道心": 1},
	{"id": "人间冷暖", "描述": "见识人间冷暖，世态炎凉", "道心": 2},
	{"id": "生离死别", "描述": "经历生离死别，感悟人生无常", "道心": 3},
	{"id": "功成名就", "描述": "在凡人世界功成名就，体验荣华富贵", "道心": 1},
	{"id": "穷困潦倒", "描述": "遭遇穷困潦倒，尝尽人间疾苦", "道心": 3},
	{"id": "金榜题名", "描述": "寒窗苦读终金榜题名，喜极而泣", "道心": 2},
	{"id": "沙场点兵", "描述": "沙场点兵，体验铁血豪情", "道心": 2},
	{"id": "悬壶济世", "描述": "悬壶济世，救死扶伤，感悟生命可贵", "道心": 3},
	{"id": "富甲一方", "描述": "经商致富，富甲一方，体验金钱万能", "道心": 1},
	{"id": "看破红尘", "描述": "历经人生百态，看破红尘，道心大涨", "道心": 5}
]

# 凡人姓氏池（用于娶妻生子）
const 凡人姓氏: Array = ["李", "王", "张", "刘", "陈", "杨", "赵", "黄", "周", "吴", "徐", "孙", "胡", "朱", "高", "林", "何", "郭", "马", "罗"]
const 凡人名字_男: Array = ["伟", "强", "磊", "军", "洋", "勇", "艳", "杰", "涛", "明", "超", "辉", "鹏", "华", "健", "亮", "峰", "斌", "波", "宇"]
const 凡人名字_女: Array = ["芳", "娜", "敏", "静", "丽", "艳", "娟", "霞", "秀英", "慧", "婷", "玉", "梅", "兰", "凤", "云", "莲", "真", "环", "雪"]

# 派遣化身入凡历练
func 派遣化身入凡(化身ID: int, 职业: String = "") -> Dictionary:
	var 化身: Dictionary = _获取化身(化身ID)
	if 化身.is_empty():
		return {"成功": false, "原因": "化身不存在"}
	if str(化身["游历状态"]) == "游历中":
		return {"成功": false, "原因": "化身正在游历中"}
	if str(化身["游历状态"]) == "红尘历练中":
		return {"成功": false, "原因": "化身正在红尘历练中"}
	# 选择职业
	var 选择职业: String = 职业 if 职业 != "" and 凡人职业.has(职业) else 凡人职业.keys().pick_random()
	var 职业配置: Dictionary = 凡人职业[选择职业]
	# 入凡（初始化轮回状态）
	化身["游历状态"] = "红尘历练中"
	化身["红尘职业"] = 选择职业
	化身["红尘年龄"] = 16   # 凡人16岁成年
	化身["红尘寿命"] = 60   # 凡人寿命60年（一甲子）
	化身["红尘配偶"] = ""
	化身["红尘子女"] = 0
	化身["红尘阅历"] = 0
	化身["红尘入凡日"] = 累计游戏日
	化身["红尘结束日"] = 累计游戏日 + 60   # 60游戏日=60凡人年（游戏日=凡人年）
	化身["轮回世"] = 0   # 轮回世数（第一世）
	化身["轮回记录"] = []   # 轮回记录
	_加推演条目("【化身%s】入凡历练，化身%s，体验红尘百态" % [化身["姓名"], 选择职业], ET_INFO, PRIO_NORMAL, {})
	return {"成功": true, "消息": "化身%s已入凡，化身%s，一甲子后归来" % [化身["姓名"], 选择职业]}

# 红尘历练月度结算（化身历劫版：化身无寿终，凡人角色有寿终/意外）
func _红尘历练月度结算() -> void:
	if 化身列表.is_empty():
		return
	for 化身 in 化身列表:
		if str(化身.get("游历状态", "")) != "红尘历练中":
			continue
		# 凡人年龄增长（每月1岁）
		化身["红尘年龄"] = int(化身["红尘年龄"]) + 1
		# 伤残状态影响收入
		var 收入系数: float = 1.0
		if 化身.has("红尘伤残") and str(化身["红尘伤残"]) != "":
			var 伤残: String = str(化身["红尘伤残"])
			if 伤残 == "受伤致残":
				收入系数 = 0.5
			elif 伤残 == "重病缠身":
				收入系数 = 0.7
			elif 伤残 == "眼盲耳聋":
				收入系数 = 0.3
		# 蒙冤入狱暂停收入
		if 化身.has("红尘蒙冤") and int(化身.get("红尘蒙冤", 0)) > 0:
			收入系数 = 0.0
			化身["红尘蒙冤"] = int(化身["红尘蒙冤"]) - 1
		# 职业收入
		var 职业配置: Dictionary = 凡人职业.get(str(化身.get("红尘职业", "")), {})
		var 月收入: int = int(int(职业配置.get("灵石收入", 0)) * 收入系数)
		var 当前灵石: int = int(化身["背包"].get("灵石", 0))
		化身["背包"]["灵石"] = 当前灵石 + 月收入
		# 道心磨练（每月有概率触发红尘事件，50%概率为抉择事件）
		if randf() < 0.2:
			if randf() < 0.5:
				_触发红尘抉择(化身)
			else:
				_触发红尘事件(化身)
		# 娶妻生子（凡人20岁后有概率娶妻，伤残/蒙冤时概率降低）
		if int(化身["红尘年龄"]) >= 20 and str(化身.get("红尘配偶", "")) == "" and randf() < 0.1 * 收入系数:
			_化身娶妻(化身)
		# 生子（娶妻后每年有概率生子）
		if str(化身.get("红尘配偶", "")) != "" and int(化身.get("红尘子女", 0)) < 3 and randf() < 0.15 * 收入系数:
			_化身生子(化身)
		# 意外事件判定（16岁后每年有概率遭遇意外）
		if int(化身["红尘年龄"]) >= 16 and randf() < 0.05:
			_触发红尘意外(化身)
			# 如果意外死亡，结束这一世
			if str(化身.get("游历状态", "")) != "红尘历练中":
				continue
		# 检查是否寿终（60岁）
		if int(化身["红尘年龄"]) >= int(化身.get("红尘寿命", 60)):
			_红尘一世结束(化身, "寿终正寝")

# 触发红尘事件
func _触发红尘事件(化身: Dictionary) -> void:
	var 事件: Dictionary = 红尘事件池.pick_random()
	var 道心加成: int = int(事件.get("道心", 1))
	化身["道心"] = int(化身["道心"]) + 道心加成
	化身["红尘阅历"] = int(化身.get("红尘阅历", 0)) + 道心加成
	_加推演条目("【化身%s·红尘】%s（道心+%d）" % [化身["姓名"], 事件["描述"], 道心加成], ET_INFO, PRIO_NORMAL, {})

# 化身婚娶（根据性别决定娶妻/嫁夫）
func _化身娶妻(化身: Dictionary) -> void:
	var 化身性别: String = str(化身.get("性别", 宗主性别))
	if 化身性别 == "女":
		# 女化身：嫁夫
		var 夫姓: String = 凡人姓氏.pick_random()
		var 夫名: String = 凡人名字_男.pick_random()
		var 夫名全称: String = 夫姓 + 夫名
		化身["红尘配偶"] = 夫名全称
		化身["道心"] = int(化身["道心"]) + 1
		化身["红尘阅历"] = int(化身.get("红尘阅历", 0)) + 2
		_加推演条目("【化身%s·红尘】嫁与%s为妻，体验人间烟火" % [化身["姓名"], 夫名全称], ET_INFO, PRIO_NORMAL, {})
	else:
		# 男化身：娶妻
		var 妻姓: String = 凡人姓氏.pick_random()
		var 妻名: String = 凡人名字_女.pick_random()
		var 妻名全称: String = 妻姓 + 妻名
		化身["红尘配偶"] = 妻名全称
		化身["道心"] = int(化身["道心"]) + 1
		化身["红尘阅历"] = int(化身.get("红尘阅历", 0)) + 2
		_加推演条目("【化身%s·红尘】娶%s为妻，体验人间烟火" % [化身["姓名"], 妻名全称], ET_INFO, PRIO_NORMAL, {})

# 化身生子
func _化身生子(化身: Dictionary) -> void:
	化身["红尘子女"] = int(化身.get("红尘子女", 0)) + 1
	化身["道心"] = int(化身["道心"]) + 1
	化身["红尘阅历"] = int(化身.get("红尘阅历", 0)) + 1
	var 性别: String = "儿" if randf() < 0.5 else "女"
	_加推演条目("【化身%s·红尘】喜得贵%s，体验为人父母" % [化身["姓名"], 性别], ET_INFO, PRIO_NORMAL, {})

# 红尘一世结束（寿终或意外死亡，化身进入轮回等待状态）
func _红尘一世结束(化身: Dictionary, 结束原因: String) -> void:
	# 计算这一世的道心加成
	var 职业配置: Dictionary = 凡人职业.get(str(化身.get("红尘职业", "")), {})
	var 职业道心: int = int(职业配置.get("道心加成", 1))
	var 人生完整度: int = 0
	if str(化身.get("红尘配偶", "")) != "":
		人生完整度 += 1
	if int(化身.get("红尘子女", 0)) > 0:
		人生完整度 += 1
	# 意外死亡有额外道心加成（大彻大悟）
	var 意外加成: int = 0
	if 结束原因 != "寿终正寝":
		意外加成 = {"战乱身亡": 5, "疾病身亡": 3, "意外身亡": 2, "仇杀身亡": 4, "殉情身亡": 6}.get(结束原因, 3)
	var 这一世道心: int = 职业道心 + 人生完整度 + 意外加成
	# 轮回阅历+1，道心加成递增（第N世 × (1 + N×10%)）
	var 轮回世: int = int(化身.get("轮回世", 0)) + 1
	化身["轮回世"] = 轮回世
	var 递增系数: float = 1.0 + float(轮回世) * 0.1
	var 实际道心: int = int(这一世道心 * 递增系数)
	化身["道心"] = int(化身["道心"]) + 实际道心
	# 记录这一世
	if not 化身.has("轮回记录"):
		化身["轮回记录"] = []
	化身["轮回记录"].append({
		"世": 轮回世, "职业": 化身.get("红尘职业", ""),
		"原因": 结束原因, "道心": 实际道心,
		"配偶": 化身.get("红尘配偶", ""), "子女": 化身.get("红尘子女", 0)
	})
	# 生成人生回顾纪事
	_生成轮回回顾(化身, 结束原因, 实际道心)
	# 进入轮回等待状态（可选择继续轮回或回归宗门）
	化身["游历状态"] = "轮回等待"
	化身["当前位置"] = "轮回之中"
	_加推演条目("【化身%s】第%d世结束：%s，道心+%d，可选择继续轮回或回归宗门" % [化身["姓名"], 轮回世, 结束原因, 实际道心], ET_BREAKTHROUGH, PRIO_HIGH, {})
	# 清理这一世的状态（保留轮回世/轮回记录/道心/背包）
	化身.erase("红尘职业")
	化身.erase("红尘年龄")
	化身.erase("红尘寿命")
	化身.erase("红尘配偶")
	化身.erase("红尘子女")
	化身.erase("红尘阅历")
	化身.erase("红尘入凡日")
	化身.erase("红尘结束日")
	化身.erase("红尘事件记录")
	化身.erase("红尘伤残")
	化身.erase("红尘蒙冤")

# 继续轮回（开始新的一世）
func 化身继续轮回(化身ID: int, 新职业: String = "") -> Dictionary:
	var 化身: Dictionary = _获取化身(化身ID)
	if 化身.is_empty():
		return {"成功": false, "原因": "化身不存在"}
	if str(化身.get("游历状态", "")) != "轮回等待":
		return {"成功": false, "原因": "化身不在轮回等待状态"}
	# 最多轮回9世（九九归一）
	if int(化身.get("轮回世", 0)) >= 9:
		return {"成功": false, "原因": "已达九九归一之数，必须回归宗门"}
	# 选择新职业
	var 选择职业: String = 新职业 if 新职业 != "" and 凡人职业.has(新职业) else 凡人职业.keys().pick_random()
	# 开始新的一世
	化身["游历状态"] = "红尘历练中"
	化身["红尘职业"] = 选择职业
	化身["红尘年龄"] = 16
	化身["红尘寿命"] = 60
	化身["红尘配偶"] = ""
	化身["红尘子女"] = 0
	化身["红尘阅历"] = 0
	化身["红尘入凡日"] = 累计游戏日
	化身["红尘结束日"] = 累计游戏日 + 60
	_加推演条目("【化身%s】第%d世入凡，化身%s，再历红尘" % [化身["姓名"], int(化身.get("轮回世", 0)) + 1, 选择职业], ET_INFO, PRIO_NORMAL, {})
	return {"成功": true, "消息": "化身%s第%d世入凡，化身%s" % [化身["姓名"], int(化身.get("轮回世", 0)) + 1, 选择职业]}

# 红尘历练回归（结束轮回，携带所得回归宗门）
func 化身红尘回归(化身ID: int) -> Dictionary:
	var 化身: Dictionary = _获取化身(化身ID)
	if 化身.is_empty():
		return {"成功": false, "原因": "化身不存在"}
	if str(化身.get("游历状态", "")) != "轮回等待":
		return {"成功": false, "原因": "化身不在轮回等待状态"}
	# 回归宗门
	化身["游历状态"] = "闲置"
	化身["当前位置"] = "宗门附近"
	# 资源反哺
	_化身资源反哺(化身)
	var 总世: int = int(化身.get("轮回世", 0))
	var 总道心: int = 0
	for 记录 in 化身.get("轮回记录", []):
		总道心 += int(记录.get("道心", 0))
	_加推演条目("【化身%s】红尘历练圆满回归，历经%d世轮回，累计道心+%d，携所得归来" % [化身["姓名"], 总世, 总道心], ET_BREAKTHROUGH, PRIO_HIGH, {})
	添加纪事("化身", "红尘圆满", "%s 历经%d世红尘轮回，道心大成，圆满回归" % [化身["姓名"], 总世], 3)
	# 清理轮回状态
	化身.erase("轮回世")
	化身.erase("轮回记录")
	return {"成功": true, "消息": "化身%s历经%d世轮回，圆满回归，累计道心+%d" % [化身["姓名"], 总世, 总道心]}

# 触发红尘意外（意外死亡/伤残/其他意外）
func _触发红尘意外(化身: Dictionary) -> void:
	var 意外类型: float = randf()
	if 意外类型 < 0.23:
		# 意外死亡（23%概率：战乱5%+疾病8%+意外5%+仇杀3%+殉情2%）
		var 死亡类型: float = randf()
		var 原因: String = "意外身亡"
		if 死亡类型 < 0.22:
			原因 = "战乱身亡"
		elif 死亡类型 < 0.57:
			原因 = "疾病身亡"
		elif 死亡类型 < 0.78:
			原因 = "意外身亡"
		elif 死亡类型 < 0.91:
			原因 = "仇杀身亡"
		else:
			原因 = "殉情身亡"
		_加推演条目("【化身%s·红尘意外】%s，这一世结束" % [化身["姓名"], 原因], ET_INFO, PRIO_HIGH, {})
		_红尘一世结束(化身, 原因)
	elif 意外类型 < 0.38:
		# 伤残（15%概率）
		var 伤残类型: float = randf()
		var 伤残: String = "重病缠身"
		if 伤残类型 < 0.33:
			伤残 = "受伤致残"
		elif 伤残类型 < 0.87:
			伤残 = "重病缠身"
		else:
			伤残 = "眼盲耳聋"
		化身["红尘伤残"] = 伤残
		var 道心加成: int = {"受伤致残": 2, "重病缠身": 1, "眼盲耳聋": 4}.get(伤残, 2)
		化身["道心"] = int(化身["道心"]) + 道心加成
		化身["红尘阅历"] = int(化身.get("红尘阅历", 0)) + 道心加成
		_加推演条目("【化身%s·红尘意外】%s，体验人间疾苦，道心+%d" % [化身["姓名"], 伤残, 道心加成], ET_INFO, PRIO_NORMAL, {})
	else:
		# 其他意外（62%概率）
		var 其他类型: float = randf()
		if 其他类型 < 0.20:
			# 家破人亡
			化身["背包"]["灵石"] = 0
			化身["红尘配偶"] = ""
			化身["红尘子女"] = 0
			化身["道心"] = int(化身["道心"]) + 3
			化身["红尘阅历"] = int(化身.get("红尘阅历", 0)) + 3
			_加推演条目("【化身%s·红尘意外】家破人亡，体验世态炎凉，道心+3" % 化身["姓名"], ET_INFO, PRIO_NORMAL, {})
		elif 其他类型 < 0.53:
			# 破产负债
			var 当前灵石: int = int(化身["背包"].get("灵石", 0))
			化身["背包"]["灵石"] = int(当前灵石 * 0.5)
			化身["道心"] = int(化身["道心"]) + 2
			化身["红尘阅历"] = int(化身.get("红尘阅历", 0)) + 2
			_加推演条目("【化身%s·红尘意外】经商失败，负债累累，道心+2" % 化身["姓名"], ET_INFO, PRIO_NORMAL, {})
		elif 其他类型 < 0.73:
			# 妻离子散
			化身["红尘配偶"] = ""
			化身["红尘子女"] = 0
			化身["道心"] = int(化身["道心"]) + 4
			化身["红尘阅历"] = int(化身.get("红尘阅历", 0)) + 4
			_加推演条目("【化身%s·红尘意外】妻离子散，体验亲情可贵，道心+4" % 化身["姓名"], ET_INFO, PRIO_NORMAL, {})
		else:
			# 蒙冤入狱
			化身["红尘蒙冤"] = 10
			化身["道心"] = int(化身["道心"]) + 5
			化身["红尘阅历"] = int(化身.get("红尘阅历", 0)) + 5
			_加推演条目("【化身%s·红尘意外】蒙冤入狱，体验人间冤屈，道心+5" % 化身["姓名"], ET_INFO, PRIO_NORMAL, {})

# 生成轮回回顾纪事
func _生成轮回回顾(化身: Dictionary, 原因: String, 道心: int) -> void:
	var 职业: String = str(化身.get("红尘职业", ""))
	var 配偶: String = str(化身.get("红尘配偶", ""))
	var 子女: int = int(化身.get("红尘子女", 0))
	var 世: int = int(化身.get("轮回世", 0))
	var 化身性别: String = str(化身.get("性别", 宗主性别))
	var 婚娶词: String = "嫁与" if 化身性别 == "女" else "娶妻"
	var 回顾: String = "第%d世：化身%s，%s。" % [世, 职业, 原因]
	if 配偶 != "":
		回顾 += "%s%s，" % [婚娶词, 配偶]
		if 子女 > 0:
			回顾 += "育有%d子，" % 子女
	else:
		回顾 += "孤身一人，"
	回顾 += "道心+%d。" % 道心
	添加纪事("化身", "轮回回顾", 回顾, 1)

# ============ P1：化身系统扩展（红尘抉择+坊市独行+功法传承+人生回顾）============

# P1：红尘抉择事件池（带选择的事件，不同选择影响道心/人脉/奖励）
const 红尘抉择事件: Array = [
	{
		"id": "路见不平", "描述": "路见恶霸欺压百姓，是否出手相助？",
		"选项": [
			{"text": "出手相助", "道心": 3, "人脉": 2, "灵石": -100, "描述": "仗义出手，虽损财物但道心大涨"},
			{"text": "袖手旁观", "道心": -2, "人脉": 0, "灵石": 0, "描述": "明哲保身，但道心有亏"},
			{"text": "趁火打劫", "道心": -5, "人脉": -1, "灵石": 200, "描述": "趁乱取财，虽得利但道心大损"}
		]
	},
	{
		"id": "病患求医", "描述": "遇重病患者求医，是否倾力救治？",
		"选项": [
			{"text": "倾力救治", "道心": 4, "人脉": 3, "灵石": -200, "描述": "悬壶济世，道心人脉双收"},
			{"text": "收取诊金", "道心": 1, "人脉": 1, "灵石": 100, "描述": "等价交换，无功无过"},
			{"text": "拒之门外", "道心": -3, "人脉": -2, "灵石": 0, "描述": "见死不救，道心有亏"}
		]
	},
	{
		"id": "商机现前", "描述": "发现一桩稳赚不赔的买卖，但需大笔本金",
		"选项": [
			{"text": "倾囊投入", "道心": 0, "人脉": 1, "灵石": 500, "描述": "胆识过人，大赚一笔"},
			{"text": "小额试水", "道心": 0, "人脉": 0, "灵石": 100, "描述": "稳健经营，小赚一笔"},
			{"text": "放弃机会", "道心": 1, "人脉": 0, "灵石": 0, "描述": "不贪不躁，道心微涨"}
		]
	},
	{
		"id": "权贵招揽", "描述": "当地权贵招揽你为幕僚，是否答应？",
		"选项": [
			{"text": "欣然应允", "道心": -1, "人脉": 3, "灵石": 300, "描述": "攀附权贵，人脉大进但道心有亏"},
			{"text": "婉言谢绝", "道心": 2, "人脉": 0, "灵石": 0, "描述": "不慕权贵，道心坚定"},
			{"text": "虚与委蛇", "道心": 0, "人脉": 1, "灵石": 100, "描述": "左右逢源，无功无过"}
		]
	},
	{
		"id": "故人重逢", "描述": "偶遇昔日故人，对方正遭难处",
		"选项": [
			{"text": "倾力相助", "道心": 3, "人脉": 2, "灵石": -150, "描述": "重情重义，道心人脉双收"},
			{"text": "略尽绵力", "道心": 1, "人脉": 1, "灵石": -50, "描述": "量力而行，无功无过"},
			{"text": "假装不识", "道心": -3, "人脉": -1, "灵石": 0, "描述": "忘恩负义，道心大损"}
		]
	},
	{
		"id": "秘籍现世", "描述": "偶然发现一部残缺古籍，似是功法残卷",
		"选项": [
			{"text": "潜心研读", "道心": 2, "人脉": 0, "灵石": 0, "功法残卷": 1, "描述": "感悟大道，获得功法残卷"},
			{"text": "高价售卖", "道心": -1, "人脉": 0, "灵石": 300, "描述": "换得灵石，但错失机缘"},
			{"text": "赠予有缘人", "道心": 4, "人脉": 2, "灵石": 0, "描述": "成人之美，道心大涨"}
		]
	},
	{
		"id": "沙场点兵", "描述": "敌军来犯，是否参军御敌？",
		"选项": [
			{"text": "奋勇杀敌", "道心": 2, "战力": 20, "灵石": 100, "描述": "保家卫国，道行大涨"},
			{"text": "运筹帷幄", "道心": 3, "战力": 10, "灵石": 150, "描述": "智谋退敌，道心道行双收"},
			{"text": "避战南迁", "道心": -2, "战力": 0, "灵石": -50, "描述": "苟且偷生，道心有亏"}
		]
	},
	{
		"id": "金榜题名", "描述": "科举在即，是否全力备考？",
		"选项": [
			{"text": "寒窗苦读", "道心": 3, "人脉": 2, "灵石": -100, "描述": "金榜题名，道心人脉双收"},
			{"text": "敷衍了事", "道心": 0, "人脉": 0, "灵石": 0, "描述": "名落孙山，无功无过"},
			{"text": "舞弊投机", "道心": -4, "人脉": 1, "灵石": 200, "描述": "侥幸得中，但道心大损"}
		]
	}
]

# P1：触发红尘抉择事件（带选择，自动选择符合化身性格的选项）
func _触发红尘抉择(化身: Dictionary) -> void:
	var 事件: Dictionary = 红尘抉择事件.pick_random()
	var 性格: String = str(化身.get("性格", ""))
	# 根据性格自动选择选项（简单AI：正义性格选正义选项，贪婪性格选利益选项）
	var 选择索引: int = 0
	if 性格 in ["贪婪", "自私", "狡诈"]:
		选择索引 = 2  # 倾向利益选项
	elif 性格 in ["正义", "善良", "仁慈", "刚正"]:
		选择索引 = 0  # 倾向正义选项
	else:
		选择索引 = 1  # 中庸选项
	var 选项: Dictionary = 事件["选项"][选择索引]
	# 应用选择效果
	if 选项.has("道心"):
		化身["道心"] = int(化身["道心"]) + int(选项["道心"])
	if 选项.has("人脉"):
		化身["人脉"] = int(化身["人脉"]) + int(选项["人脉"])
	if 选项.has("战力"):
		化身["战力"] = int(化身["战力"]) + int(选项["战力"])
	if 选项.has("灵石"):
		var 当前灵石: int = int(化身["背包"].get("灵石", 0))
		化身["背包"]["灵石"] = 当前灵石 + int(选项["灵石"])
	if 选项.has("功法残卷"):
		var 当前残卷: int = int(化身["背包"].get("功法残卷", 0))
		化身["背包"]["功法残卷"] = 当前残卷 + int(选项["功法残卷"])
	# 记录事件
	if not 化身.has("红尘事件记录"):
		化身["红尘事件记录"] = []
	化身["红尘事件记录"].append({"事件": 事件["id"], "选择": 选项["text"], "描述": 选项["描述"]})
	化身["红尘阅历"] = int(化身.get("红尘阅历", 0)) + abs(int(选项.get("道心", 0))) + 1
	_加推演条目("【化身%s·红尘抉择】%s → %s（%s）" % [化身["姓名"], 事件["描述"], 选项["text"], 选项["描述"]], ET_INFO, PRIO_NORMAL, {})

# P1：坊市独行（化身游历仙城闹市时可低买高卖）
const 坊市商品: Dictionary = {
	"灵草": {"买入价": 5, "卖出价": 8, "波动": 0.3},
	"灵石": {"买入价": 1, "卖出价": 1, "波动": 0.0},
	"妖兽内丹一阶": {"买入价": 20, "卖出价": 35, "波动": 0.4},
	"精铁": {"买入价": 15, "卖出价": 25, "波动": 0.35},
	"灵品灵草": {"买入价": 30, "卖出价": 50, "波动": 0.4},
	"玉石": {"买入价": 25, "卖出价": 40, "波动": 0.35}
}

# P1：化身坊市交易（低买高卖，休闲玩法）
func 化身坊市交易(化身ID: int, 商品: String, 数量: int, 买入: bool = true) -> Dictionary:
	var 化身: Dictionary = _获取化身(化身ID)
	if 化身.is_empty():
		return {"成功": false, "原因": "化身不存在"}
	if str(化身.get("游历状态", "")) != "游历中" or str(化身.get("游历区域", "")) != "仙城闹市":
		return {"成功": false, "原因": "化身需在仙城闹市游历中方可交易"}
	if not 坊市商品.has(商品):
		return {"成功": false, "原因": "未知商品"}
	var 商品配置: Dictionary = 坊市商品[商品]
	var 价格: int = int(商品配置["买入价"] if 买入 else 商品配置["卖出价"])
	# 价格波动
	var 波动: float = float(商品配置["波动"])
	价格 = int(价格 * (1.0 + randf_range(-波动, 波动)))
	var 总金额: int = 价格 * 数量
	if 买入:
		# 买入：消耗灵石，获得商品
		var 当前灵石: int = int(化身["背包"].get("灵石", 0))
		if 当前灵石 < 总金额:
			return {"成功": false, "原因": "化身灵石不足（需%d）" % 总金额}
		化身["背包"]["灵石"] = 当前灵石 - 总金额
		var 当前商品: int = int(化身["背包"].get(商品, 0))
		化身["背包"][商品] = 当前商品 + 数量
		return {"成功": true, "消息": "买入%d份%s，花费%d灵石" % [数量, 商品, 总金额]}
	else:
		# 卖出：消耗商品，获得灵石
		var 当前商品: int = int(化身["背包"].get(商品, 0))
		if 当前商品 < 数量:
			return {"成功": false, "原因": "化身%s不足（仅有%d）" % [商品, 当前商品]}
		化身["背包"][商品] = 当前商品 - 数量
		var 当前灵石: int = int(化身["背包"].get("灵石", 0))
		化身["背包"]["灵石"] = 当前灵石 + 总金额
		return {"成功": true, "消息": "卖出%d份%s，获得%d灵石" % [数量, 商品, 总金额]}

# P1：化身功法传承（将游历/红尘中获得的功法残卷传承回藏经阁）
func 化身传承功法(化身ID: int) -> Dictionary:
	var 化身: Dictionary = _获取化身(化身ID)
	if 化身.is_empty():
		return {"成功": false, "原因": "化身不存在"}
	var 残卷数量: int = int(化身["背包"].get("功法残卷", 0))
	if 残卷数量 <= 0:
		return {"成功": false, "原因": "化身背包中没有功法残卷"}
	# 传承到藏经阁（简化：增加悟道点）
	悟道点 += 残卷数量 * 10
	化身["背包"]["功法残卷"] = 0
	_加推演条目("【化身%s】将游历所得功法残卷传承回藏经阁，宗门悟道点+%d" % [化身["姓名"], 残卷数量 * 10], ET_SECT, PRIO_NORMAL, {})
	return {"成功": true, "消息": "传承%d份功法残卷，宗门悟道点+%d" % [残卷数量, 残卷数量 * 10]}

# P1：生成人生回顾纪事（化身寿终归来时）
func _生成人生回顾(化身: Dictionary) -> void:
	var 职业: String = str(化身.get("红尘职业", ""))
	var 配偶: String = str(化身.get("红尘配偶", ""))
	var 子女: int = int(化身.get("红尘子女", 0))
	var 阅历: int = int(化身.get("红尘阅历", 0))
	var 事件记录: Array = 化身.get("红尘事件记录", [])
	# 生成人生回顾文本
	var 回顾: String = "%s化身%s，" % [化身["姓名"], 职业]
	if 配偶 != "":
		回顾 += "娶妻%s，" % 配偶
		if 子女 > 0:
			回顾 += "育有%d子，" % 子女
	else:
		回顾 += "孤身一人，"
	回顾 += "历经%d件红尘事，" % 事件记录.size()
	回顾 += "红尘阅历%d点。" % 阅历
	# 评价
	if 阅历 >= 30:
		回顾 += "此生波澜壮阔，看破红尘，道心大成。"
	elif 阅历 >= 15:
		回顾 += "此生有苦有乐，感悟颇深，道心精进。"
	else:
		回顾 += "此生平淡如水，虽无大起大落，亦有所得。"
	添加纪事("化身", "人生回顾", 回顾, 2)
	_加推演条目("【化身%s·人生回顾】%s" % [化身["姓名"], 回顾], ET_INFO, PRIO_NORMAL, {})

# ============ P2：化身系统扩展（宗门客卿+人脉转化）============

# P2：宗门客卿配置（化身可加入他宗做客卿）
const 客卿宗门: Array = [
	{"名": "青云宗", "声望": "正道大派", "待遇": 200, "道心要求": 50},
	{"名": "合欢宗", "声望": "邪道旁门", "待遇": 300, "道心要求": 30},
	{"名": "万剑门", "声望": "剑道正宗", "待遇": 250, "道心要求": 60},
	{"名": "百药谷", "声望": "丹道世家", "待遇": 180, "道心要求": 40},
	{"名": "机关城", "声望": "器道重镇", "待遇": 220, "道心要求": 35}
]

# P2：化身加入宗门客卿
func 化身加入客卿(化身ID: int, 宗门名: String) -> Dictionary:
	var 化身: Dictionary = _获取化身(化身ID)
	if 化身.is_empty():
		return {"成功": false, "原因": "化身不存在"}
	if str(化身.get("游历状态", "")) != "闲置":
		return {"成功": false, "原因": "化身需闲置时方可加入客卿"}
	# 查找宗门
	var 目标宗门: Dictionary = {}
	for 宗 in 客卿宗门:
		if 宗["名"] == 宗门名:
			目标宗门 = 宗
			break
	if 目标宗门.is_empty():
		return {"成功": false, "原因": "未知宗门"}
	# 检查道心要求
	if int(化身["道心"]) < int(目标宗门["道心要求"]):
		return {"成功": false, "原因": "道心不足（需%d）" % 目标宗门["道心要求"]}
	# 加入客卿
	化身["游历状态"] = "客卿中"
	化身["客卿宗门"] = 宗门名
	化身["客卿待遇"] = int(目标宗门["待遇"])
	化身["客卿结束日"] = 累计游戏日 + 90   # 客卿任期90游戏日
	_加推演条目("【化身%s】加入%s做客卿，任期90日，月俸%d灵石" % [化身["姓名"], 宗门名, 目标宗门["待遇"]], ET_INFO, PRIO_NORMAL, {})
	return {"成功": true, "消息": "化身%s已加入%s做客卿" % [化身["姓名"], 宗门名]}

# P2：客卿月度结算
func _客卿月度结算() -> void:
	if 化身列表.is_empty():
		return
	for 化身 in 化身列表:
		if str(化身.get("游历状态", "")) != "客卿中":
			continue
		# 月俸
		var 待遇: int = int(化身.get("客卿待遇", 0))
		var 当前灵石: int = int(化身["背包"].get("灵石", 0))
		化身["背包"]["灵石"] = 当前灵石 + 待遇
		# 人脉增长
		化身["人脉"] = int(化身["人脉"]) + 1
		# 检查任期结束
		if 累计游戏日 >= int(化身.get("客卿结束日", 0)):
			化身["游历状态"] = "闲置"
			化身["当前位置"] = "宗门附近"
			_加推演条目("【化身%s】%s客卿任期结束，携所得归来" % [化身["姓名"], 化身.get("客卿宗门", "")], ET_INFO, PRIO_NORMAL, {})
			化身.erase("客卿宗门")
			化身.erase("客卿待遇")
			化身.erase("客卿结束日")

# P2：化身人脉转化为宗门外交关系
func 化身人脉转化(化身ID: int) -> Dictionary:
	var 化身: Dictionary = _获取化身(化身ID)
	if 化身.is_empty():
		return {"成功": false, "原因": "化身不存在"}
	var 人脉: int = int(化身.get("人脉", 0))
	if 人脉 <= 0:
		return {"成功": false, "原因": "化身无人脉可转化"}
	# 转化为宗门声望（简化：每10点人脉=1点声望）
	var 声望增加: int = int(人脉 / 10)
	声望 += 声望增加
	化身["人脉"] = 人脉 % 10
	_加推演条目("【化身%s】将游历人脉转化为宗门声望，宗门声望+%d" % [化身["姓名"], 声望增加], ET_SECT, PRIO_NORMAL, {})
	return {"成功": true, "消息": "转化%d点人脉，宗门声望+%d" % [人脉, 声望增加]}

# 执行飞升：移出列表、留下传承、入册祖师堂、持续回馈

# 执行飞升：移出列表、留下传承、入册祖师堂、持续回馈
func _执行飞升(d: Object) -> void:
	d.飞升 = true
	# 1. 判定飞升路线：正道飞升（功德≥500）/ 魔道飞升（业力≥500）/ 普通飞升
	var 路线: String = "普通飞升"
	var 功德值: int = int(d.功德) if d.功德 != null else 0
	var 业力值: int = int(d.业力) if d.业力 != null else 0
	if 功德值 >= 500:
		路线 = "正道飞升"
	elif 业力值 >= 500:
		路线 = "魔道飞升"
	# 2. 留下传承：功法纳入藏经阁、本命法宝归入宗门、修炼经验化为传承心得
	var 传承列表: Array = []
	# 功法传承：弟子已学功法有30%概率纳入藏经阁
	if d.已学功法 != null and d.已学功法.size() > 0:
		for 功法 in d.已学功法:
			if randf() < 0.3:
				传承列表.append("功法：" + str(功法))
	# 法宝传承：装备中有50%概率留下本命法宝
	if d.装备.size() > 0:
		for 部位 in d.装备.keys():
			if randf() < 0.5:
				var 法宝 = d.装备[部位]
				if 法宝 != null:
					传承列表.append("法宝：" + str(法宝.名称))
					宗门库房.append(法宝)
		d.装备.clear()
	# 背包/私库归还宗门
	for it in d.背包:
		宗门库房.append(it)
	d.背包.clear()
	if d.私库.size() > 0:
		for it in d.私库:
			宗门库房.append(it)
		d.私库.clear()
	# 灵兽归还御兽堂
	if d.主宠灵兽 != null:
		var 兽: Beast = d.主宠灵兽
		d.主宠灵兽 = null
		兽.取消出战()
		if not 灵兽管理系统.灵兽库存.has(兽):
			灵兽管理系统.灵兽库存.append(兽)
	if d.副宠灵兽 != null:
		var 兽: Beast = d.副宠灵兽
		d.副宠灵兽 = null
		兽.取消出战()
		if not 灵兽管理系统.灵兽库存.has(兽):
			灵兽管理系统.灵兽库存.append(兽)
	# 3. 入册祖师堂（轻量存储）
	祖师堂.append({
		"弟子ID": d.弟子ID, "姓名": d.姓名, "境界": d.境界,
		"飞升日": 累计游戏日, "飞升路线": 路线,
		"传承列表": 传承列表, "功德": 功德值, "业力": 业力值
	})
	# 4. 纪事与推演条目
	if 路线 == "正道飞升":
		_加推演条目("【%s】功德圆满，九重天劫加身，历劫功成，正道飞升！" % d.姓名, ET_BREAKTHROUGH, PRIO_HIGH, {"弟子": d.姓名})
		添加纪事("飞升", "正道飞升", "%s 功德圆满，历九重天劫而不灭，白日飞升，位列仙班" % d.姓名, 3)
	elif 路线 == "魔道飞升":
		_加推演条目("【%s】以杀证道，业火焚身，历劫功成，魔道飞升！" % d.姓名, ET_BREAKTHROUGH, PRIO_HIGH, {"弟子": d.姓名})
		添加纪事("飞升", "魔道飞升", "%s 以杀证道，业火焚身而不灭，白日飞升，魔道称尊" % d.姓名, 3)
	else:
		_加推演条目("【%s】历劫功成，白日飞升！自此超脱凡尘" % d.姓名, ET_BREAKTHROUGH, PRIO_HIGH, {"弟子": d.姓名})
		添加纪事("飞升", "白日飞升", "%s 于渡劫之境历劫功成，白日飞升，宗门共贺" % d.姓名, 2)
	# 5. 传承事件与里程碑
	if d.身份 == "长老":
		_传承事件("首位长老飞升")
	_复检里程碑()
	_复检成就()
	# 6. 断链师父离场
	_断链_师父离场(d.弟子ID)
	# 7. 从弟子列表移除
	弟子列表.erase(d)
	# 8. 飞升回馈：全宗修炼加成（每个飞升弟子+1%，运行时计算）
	_加推演条目("【祖师堂】%s 飞升后留下传承，宗门气运加持，全宗修炼速度永久+1%%" % d.姓名, ET_SECT, PRIO_NORMAL, {})

# 计算祖师堂气运加成（每个飞升弟子全宗修炼+1%，上限30%）
func 祖师堂气运加成() -> float:
	return clamp(float(祖师堂.size()) * 0.01, 0.0, 0.30)

# 祖师堂定期回馈：每30游戏日，飞升弟子有概率送来仙界资源
func _祖师堂定期回馈() -> void:
	if 祖师堂.is_empty():
		return
	if 累计游戏日 % 30 != 0:
		return
	for 祖师 in 祖师堂:
		if randf() < 0.1:  # 每个飞升弟子10%概率送来资源
			var 资源类型 = ["灵石", "灵草", "矿石", "丹药"].pick_random()
			var 数量 = randi_range(10, 50)
			if 资源类型 == "灵石":
				灵石 += 数量
			elif 资源类型 == "灵草":
				灵草 += 数量
			elif 资源类型 == "矿石":
				矿石 += 数量
			_加推演条目("【祖师堂】%s 自仙界送来%s %d份，感念宗门培育之恩" % [祖师["姓名"], 资源类型, 数量], ET_SECT, PRIO_NORMAL, {})

# §12.3 孕育子嗣（遗传算法：镜像 recruit 流程，父母属性加权遗传 + 小概率突变）
func _孕育子嗣(父: Object, 母: Object) -> Object:
	var 孩 = Disciple.new()
	孩.司职 = "yuying"
	孩.来源 = 父.来源 if randf() < 0.5 else 母.来源
	# 性格：继承父母之一，小概率突变
	if randf() < 0.85:
		孩.性格 = (父.性格 if randf() < 0.5 else 母.性格)
	else:
		孩.性格 = Disciple.性格表.pick_random()
	# 灵根：父母灵根加权，偏向高品阶；小概率隔代升阶
	var 候选灵根 = [父.灵根, 母.灵根]
	孩.灵根 = 候选灵根[randi() % 候选灵根.size()]
	if Lore._灵根品阶值(父.灵根品阶) >= Lore._灵根品阶值(母.灵根品阶):
		孩.灵根品阶 = 父.灵根品阶
	else:
		孩.灵根品阶 = 母.灵根品阶
	if randf() < 0.08:
		_提升灵根品阶一档(孩)
	# 身份按灵根品阶破格
	if 孩.灵根品阶 == "天品":
		孩.身份 = "核心弟子"
	elif 孩.灵根品阶 == "极品":
		孩.身份 = "内门弟子"
	else:
		孩.身份 = "外门"
	孩.辈分序 = 0
	# §4.0 目标驱动：子嗣初始主目标=修成大道
	孩.主目标 = "修成大道"
	孩.目标栈 = [{"目标": "修成大道", "来源": "家学", "起始日": 累计游戏日}]
	# §12.3 家族链路 + 遗传记忆
	孩.父母ID = [int(父.弟子ID), int(母.弟子ID)]
	var 遗传: String = ""
	if 父.灵根品阶 in ["天品", "极品"]:
		遗传 += "承父辈%s之资；" % 父.灵根品阶
	if 母.灵根品阶 in ["天品", "极品"]:
		遗传 += "承母辈%s之资；" % 母.灵根品阶
	if 遗传 == "":
		遗传 = "父母修为一般，望其自力更生。"
	孩.遗传记忆 = 遗传
	# 双向登记子嗣
	if not (父.子嗣列表 is Array):
		父.子嗣列表 = []
	if not (母.子嗣列表 is Array):
		母.子嗣列表 = []
	父.子嗣列表.append(int(孩.弟子ID))
	母.子嗣列表.append(int(孩.弟子ID))
	_加推演条目("【%s】与%s喜得麟儿%s（%s）" % [父.姓名, 母.姓名, 孩.姓名, 孩.灵根品阶], ET_INFO, PRIO_NORMAL, {"弟子": 孩.姓名})
	添加纪事("家族", "喜得麟儿", "%s 与 %s 孕育子嗣%s，%s灵根，家门添丁" % [父.姓名, 母.姓名, 孩.姓名, 孩.灵根品阶], 1)
	return 孩

# §12.5 转世/夺舍判定：弟子将离场（寿元坐化 或 历练陨落）时，
# 依特殊命格/业力小概率（≤1%）转世重修或夺舍再生，原地重生（保留前世记忆）。
# 返回 true 表示已转世（调用方不应再将其坐化/标记陨落）。
func _转世判定(d: Object) -> bool:
	if d == null:
		return false
	# 转世概率：按境界分级，高境界弟子转世概率更高
	# 练气/筑基：1%（需特殊命格）/ 金丹/元婴：5% / 化神/炼虚：10% / 合体/大乘：20% / 渡劫以上：30%
	var 序: int = Disciple.境界索引(str(d.境界))
	var 转世概率: float = 0.01
	if 序 >= Disciple.境界索引("金丹") and 序 < Disciple.境界索引("化神"):
		转世概率 = 0.05
	elif 序 >= Disciple.境界索引("化神") and 序 < Disciple.境界索引("合体"):
		转世概率 = 0.10
	elif 序 >= Disciple.境界索引("合体") and 序 < Disciple.境界索引("渡劫"):
		转世概率 = 0.20
	elif 序 >= Disciple.境界索引("渡劫"):
		转世概率 = 0.30
	# 低境界需要特殊命格才能转世
	if 序 < Disciple.境界索引("金丹") and not d.有特殊命格():
		return false
	if randf() >= 转世概率:
		return false
	# 重生：境界归练气、年龄归少、清空世俗牵连，保留前世记忆与弟子ID
	var 旧名: String = d.姓名
	var 旧境界: String = str(d.境界)
	d.境界 = "练气"
	d.层数 = 0
	d.修炼进度 = 0.0
	d.年龄 = 0.0
	d.寿元 = Disciple.境界表["练气"]["寿元"]
	d.战力 = Disciple.境界表["练气"]["战力"]
	d.心境 = 50
	d.道侣ID = -1
	d.道侣 = ""
	d.主目标 = "修成大道"
	d.目标栈 = [{"目标": "修成大道", "来源": "转世重修", "起始日": 累计游戏日}]
	d.前世记忆 = "曾为%s境修士%s，一世修为尽付东流，唯余道心不灭。" % [旧境界, 旧名]
	d.状态 = "在宗"
	d.飞升 = false
	# 转世保留部分修炼经验：修炼速度加成（前世记忆）
	d.转世加成 = 0.2  # 转世重修修炼速度+20%
	_加推演条目("【%s】转世重修！前尘尽忘，唯道心不灭，再踏仙途" % 旧名, ET_INFO, PRIO_HIGH, {"弟子": 旧名})
	添加纪事("轮回", "转世重修", "%s 身死道消之际转世重修，再入轮回，道心不灭" % 旧名, 2)
	return true

# ============ B2 方针接入自动执行层（玩家定方向·系统执行）============
# 方针由 ui/page_policy.gd 设置；本块在推演月内把方针翻译为自动行为：
# 自动派遣（空闲弟子按 方针.历练 自动历练+续派）、自动供给（按阈值自动炼丹/锻造）。
func _执行方针() -> void:
	if not (方针 is Dictionary):
		方针 = _方针默认.duplicate(true)
	if 方针.get("历练", {}).get("自动派遣", false) and ExpeditionSystem != null:
		_方针自动派遣()
	if 方针.get("供给", {}).get("丹药自动炼制", false):
		_自动供给丹药()
	if 方针.get("供给", {}).get("装备自动锻造", false):
		_自动供给装备()
	if 方针.get("供给", {}).get("符箓自动绘制", false):
		_自动供给符箓()

func _方针自动派遣() -> void:
	if ExpeditionSystem == null:
		return
	var 风险偏好: float = float(方针.get("历练", {}).get("风险偏好", 0.5))
	var 目标表: Array = 方针.get("历练", {}).get("目标掉落表", [])
	for d in 弟子列表:
		if d == null or str(d.状态) != "在宗":
			continue
		if ExpeditionSystem._弟子是否在历练中(int(d.弟子ID)):
			continue
		# §4.0 目标驱动：历练意愿（避世/问道 明显少去，复仇/魔道 格外积极）
		var 派遣目标名: String = Goal.弟子目标(d)
		var 意愿: float = Goal.历练意愿(派遣目标名)
		if 意愿 < 1.0 and randf() > 意愿:
			continue
		# §4.0 目标驱动：风险偏好与宗门方针各占一半权重 → 战力比门槛
		var 战力门槛: float = 0.55 + clamp(风险偏好 * 0.55 + Goal.风险偏好(派遣目标名) * 0.45, 0.0, 1.25) * 0.75
		var 候选: Array = []
		for 关ID in ExpeditionSystem.关卡库.keys():
			var 关 = ExpeditionSystem.关卡库[关ID]
			if 关["类型"] != "daily" and 关["类型"] != "secret":
				continue
			if not ExpeditionSystem._境界达标(str(d.境界), str(关["解锁境界"])):
				continue
			var 战力比: float = float(d.战力) / max(1.0, float(关["推荐战力"]))
			if 战力比 < 战力门槛:
				continue
			候选.append(关ID)
		if 候选.is_empty():
			continue
		var 选定: String = ""
		for t in 目标表:
			if t in 候选:
				选定 = t
				break
		if 选定 == "":
			选定 = 候选.pick_random()
		var 结果 = ExpeditionSystem.开始历练(选定, [int(d.弟子ID)])
		if 结果.get("成功", false):
			_加推演条目("【%s】遵宗门方针，自动前往【%s】历练" % [str(d.姓名), str(ExpeditionSystem.关卡库[选定]["名称"])], ET_INFO, PRIO_TRIVIAL, {"弟子": str(d.姓名)})

## 当前丹堂等级（司职列表 dantang；缺失→1）
func _丹堂等级() -> int:
	if 司职列表.has("dantang"):
		var v = 司职列表["dantang"].get("等级", 1)
		return int(v) if v != null else 1
	return 1

func _自动供给丹药() -> void:
	var 囤积线: int = int(方针.get("供给", {}).get("丹药囤积线", 20))
	var 现丹: int = 0
	for it in 宗门库房:
		if it != null and _物品类别码(it) == "dan_yao":
			现丹 += 1
	if 现丹 >= 囤积线:
		return
	var 丹堂等级: int = 1
	if 司职列表.has("dantang"):
		var v = 司职列表["dantang"].get("等级", 1)
		丹堂等级 = int(v) if v != null else 1
	var 常用: Array = ["pill_005", "pill_001", "pill_006", "pill_002", "pill_003"]
	for pid in 常用:
		var r = 执行炼丹(pid, 丹堂等级)
		if r.get("成功", false):
			_加推演条目("【丹堂】遵宗门方针自动炼制%s" % str(pid), ET_INFO, PRIO_TRIVIAL, {})
			break

func _自动供给装备() -> void:
	var 囤积线: int = int(方针.get("供给", {}).get("装备囤积线", 10))
	var 现装: int = 0
	for it in 宗门库房:
		if it != null and _物品类别码(it) == "fabao":
			现装 += 1
	if 现装 >= 囤积线:
		return
	var 器堂等级: int = 1
	if 司职列表.has("qitang"):
		var v = 司职列表["qitang"].get("等级", 1)
		器堂等级 = int(v) if v != null else 1
	var 蓝图: Array = ["bp_001", "bp_002", "bp_003", "bp_004", "bp_005"]
	for bid in 蓝图:
		var r = 执行炼器(bid, 器堂等级)
		if r.get("成功", false):
			_加推演条目("【器殿】遵宗门方针自动锻造%s" % str(bid), ET_INFO, PRIO_TRIVIAL, {})
			break

func _自动供给符箓() -> void:
	var 囤积线: int = int(方针.get("供给", {}).get("符箓囤积线", 10))
	var 现符: int = 0
	for it in 宗门库房:
		if it != null and _物品类别码(it) == "fu_lu":
			现符 += 1
	if 现符 >= 囤积线:
		return
	var 符堂等级: int = 1
	if 司职列表.has("futang"):
		var v = 司职列表["futang"].get("等级", 1)
		符堂等级 = int(v) if v != null else 1
	var 常用: Array = ["tal_001", "tal_002", "tal_003", "tal_004", "tal_005"]
	for tid in 常用:
		var r = 执行炼符(tid, 符堂等级)
		if r.get("成功", false):
			_加推演条目("【符堂】遵宗门方针自动绘符%s" % str(tid), ET_INFO, PRIO_TRIVIAL, {})
			break

# ============ §10.1 世界事件引擎（设定3 总开关）+ §5.4 奏折（三国志式）============
# 推演月内抽取月度事件：L1 静默结算、L2/L3 呈奏折；事件突变触发器接 §4.0 _突变目标。
func _加载世界事件() -> void:
	if 世界事件表.is_empty():
		世界事件表 = DestinyDataLoader._read_csv("res://config/world_event_config.csv")

func 抽取月度事件() -> void:
	if 世界事件表.is_empty():
		_加载世界事件()
	if 世界事件表.is_empty():
		return
	var 抽数: int = 1 + (1 if randf() < 0.4 else 0)
	for _i in range(抽数):
		var 事件: Dictionary = _按权重抽事件()
		if not 事件.is_empty():
			处理事件(事件)

func _按权重抽事件() -> Dictionary:
	var 总权: float = 0.0
	for e in 世界事件表:
		总权 += float(e.get("权重", 1)) * _事件阵营权重(e)
	if 总权 <= 0:
		return {}
	var r: float = randf() * 总权
	for e in 世界事件表:
		r -= float(e.get("权重", 1)) * _事件阵营权重(e)
		if r <= 0:
			return e
	return {}
# §12/B2 方针·修炼风格 → 推演月内修炼速度乘区（不改 disciple.gd 内部，纯调用参数调制）
func _修炼风格乘区() -> float:
	var 风: String = str(方针.get("修炼", {}).get("风格", "均衡"))
	if 风 == "激进":
		return 1.15   # 快，更频繁触顶→更常尝试突破，风险自然浮现
	elif 风 == "稳健":
		return 0.85   # 慢而稳
	return 1.0

# §12/B2 方针·外交阵营姿态 → 调制世界事件抽取权重（纯增量，零战斗触碰）
func _事件阵营权重(事件: Dictionary) -> float:
	var 姿态: String = str(方针.get("外交", {}).get("阵营姿态", "均衡"))
	if 姿态 == "均衡":
		return 1.0
	var 文: String = str(事件.get("文本", "")) + str(事件.get("类型", ""))
	var 魔: bool = ("魔修" in 文) or ("魔道" in 文)
	var 正: bool = ("仙人" in 文) or ("正道" in 文) or ("盟友" in 文)
	if 姿态 == "魔道":
		return 1.8 if 魔 else (0.6 if 正 else 1.0)
	if 姿态 == "正道":
		return 1.6 if 正 else (0.5 if 魔 else 1.0)
	if 姿态 == "中立":
		return 1.2 if 正 else (0.8 if 魔 else 1.0)
	return 1.0


func 处理事件(事件: Dictionary) -> void:
	var 层: String = str(事件.get("层", "L1"))
	var 文本: String = str(事件.get("文本", ""))
	var 触发: String = str(事件.get("突变触发器", ""))
	var 事件id: String = str(事件.get("id", ""))
	var 当事人: Object = _随机在宗弟子()
	var 名: String = str(当事人.姓名) if 当事人 != null else "宗门"
	var 正文: String = 文本.replace("%s", 名) if "%s" in 文本 else 文本
	if 层 == "L1":
		if 当事人 != null:
			当事人.履历.append({"事件": 正文, "日": 累计游戏日})
			# 根据事件类型给予不同效果
			match 事件id:
				"ev_daily_5", "ev_daily_14", "ev_daily_15":  # 顿悟/道人授法/旧书批注
					当事人.修炼进度 = min(1.0, 当事人.修炼进度 + 0.05)
					当事人.心境 = min(100, int(当事人.心境) + 3)
				"ev_daily_2", "ev_daily_9":  # 膳堂笑谈/切磋
					当事人.心境 = min(100, int(当事人.心境) + 3)
				"ev_daily_3", "ev_daily_7", "ev_daily_10":  # 采灵草/灵药成熟/野生灵草
					灵草 += randi_range(5, 20)
				"ev_daily_11":  # 坊市淘宝
					灵石 += randi_range(20, 100)
				"ev_daily_13":  # 丹成异香
					灵石 += randi_range(30, 80)
				_:  # 默认效果
					if randf() < 0.5:
						当事人.心境 = min(100, int(当事人.心境) + 2)
		_加推演条目("【世事】" + 正文, ET_INFO, PRIO_TRIVIAL, {})
	else:
		var 选项: Array = _解析选项(str(事件.get("选项", "")))
		var 重大性: String = "存亡" if 层 == "L3" else "重大"
		呈奏折(str(事件.get("类型", "宗门")), 正文, 选项, 重大性)
	if 触发 != "" and 当事人 != null:
		var 候选: Array = 触发.split("/")
		var 目标: String = 候选.pick_random()
		_突变目标(当事人, 目标, "世事触动·" + str(事件.get("类型", "")))

func _随机在宗弟子() -> Object:
	var 候选: Array = []
	for d in 弟子列表:
		if d != null and str(d.状态) == "在宗":
			候选.append(d)
	if 候选.is_empty():
		return null
	return 候选.pick_random()

func _解析选项(s: String) -> Array:
	var out: Array = []
	for part in s.split(";"):
		if part.strip_edges() == "":
			continue
		var f: Array = part.split("|")
		var 推荐: bool = (f[1] if f.size() > 1 else "否") == "是"
		out.append({"文本": f[0] if f.size() > 0 else "", "推荐": 推荐, "后果预览": f[2] if f.size() > 2 else ""})
	return out

func 呈奏折(提议人: String, 事由: String, 选项: Array, 重大性: String) -> void:
	var 敏感度: String = 方针.get("奏折敏感度", "仅重大")
	if 敏感度 == "仅存亡" and 重大性 != "存亡":
		_自动处置奏折(提议人, 事由, 选项)
		return
	if 敏感度 == "全弹" or 重大性 in ["重大", "存亡"]:
		待决奏折.append({"提议人": 提议人, "事由": 事由, "选项": 选项, "重大性": 重大性, "日": 累计游戏日})
		_加推演条目("【奏折·%s】%s" % [提议人, 事由], ET_INFO, PRIO_NORMAL, {})
	else:
		_自动处置奏折(提议人, 事由, 选项)

func _自动处置奏折(提议人: String, 事由: String, 选项: Array) -> void:
	for o in 选项:
		if bool(o.get("推荐", false)):
			_加推演条目("【奏折·%s】依方针自动：%s" % [提议人, str(o.get("文本", ""))], ET_INFO, PRIO_TRIVIAL, {})
			return

func 裁决奏折(索引: int, 选项文本: String) -> void:
	if 索引 < 0 or 索引 >= 待决奏折.size():
		return
	var 折: Dictionary = 待决奏折[索引]
	_加推演条目("【裁决·%s】%s" % [str(折.get("提议人", "")), 选项文本], ET_INFO, PRIO_NORMAL, {})
	待决奏折.remove_at(索引)
# ——— 异闻日志：宗门自己的因果记录（零依赖，不依赖王朝邸报）———
# 载体：宗门纪事（纪事分类已含"异闻"）——零新增持久字段、零存档改动。
# 与王朝邸报的关系：邸报是「世俗朝局」渠道，需王朝开启；本纪事是宗门自身渠道，
# 任何存档都能记录，二者各自每月至多 1 条，互不阻塞。
# 玩家读到的是传闻而非数字（文本真源在 Karma）。
func _记录异闻_S45() -> void:
	var 本月: int = int(累计游戏日 / 30)
	# 月度去重：本月已记过异闻则不重复（分境/扁平都受此约束）
	var 已记本月: bool = false
	for r in 宗门纪事:
		var 记: Dictionary = r as Dictionary
		if str(记.get("分类", "")) != "异闻":
			continue
		if int(记.get("游戏日", -1)) / 30 == 本月:
			已记本月 = true
			break
	if 已记本月:
		return
	# 大宗门（>=阈值）：按境界分区多条播报，标题带【境界】前缀
	if 弟子列表.size() >= 异闻分区阈值:
		var 候: Array = Karma.宗门异闻分区(弟子列表)
		var 计数: int = 0
		for c in 候:
			var 境: String = str(c.get("境界", ""))
			var 弟子 = c.get("弟子", null)
			if 弟子 == null:
				continue
			var 键: String = "%d|%s|%d" % [本月, 境, int(弟子.弟子ID)]
			if 异闻分区已播.has(键):
				continue
			异闻分区已播[键] = true
			var 文本: String = str(c.get("文本", ""))
			if 文本 == "":
				continue
			var 名前: String = str(弟子.姓名)
			if 名前 == "":
				名前 = "某弟子"
			添加纪事("异闻", "【%s】%s洞府有异" % [境, 名前], 文本, 2)
			计数 += 1
			if 计数 >= 异闻分区月上限:
				break
		return
	# 小宗门：维持旧扁平单条（无【境界】前缀）
	var 闻: Array = Karma.宗门异闻(弟子列表)
	if 闻.is_empty():
		return
	var 首: Dictionary = 闻[0] as Dictionary
	var 文本: String = str(首.get("文本", ""))
	var d = 首.get("弟子", null)
	if 文本 == "" or d == null:
		return
	var 名前: String = str(d.姓名)
	if 名前 == "":
		名前 = "某弟子"
	添加纪事("异闻", "%s洞府有异" % 名前, 文本, 2)


# ============ S48：狩猎采药系统（入山采撷·宗主亲为+弟子自动）============
# 设计铁则：三维度（好玩/修真世界观/玩家操作习惯）+核心玩法（仿真修仙宗门）+文案修真化+手机端流畅
# 触屏交互：单指点按采集点、拖拽选择区域、长按蓄力（狩猎）
# 与现有系统联动：炼丹/炼器材料来源、灵兽系统、弟子历练、坊市系统

var 狩猎等级: int = 1          # 宗主狩猎等级（1-10）
var 采药等级: int = 1          # 宗主采药等级（1-10）
var 狩猎经验: int = 0          # 狩猎经验
var 采药经验: int = 0          # 采药经验
var 今日狩猎次数: int = 0      # 今日狩猎次数（现实日重置）
var 今日采药次数: int = 0      # 今日采药次数（现实日重置）
var 狩猎区域列表: Array = []   # 已解锁狩猎区域
var 采药区域列表: Array = []   # 已解锁采药区域

# 狩猎区域配置（修真世界观：不同区域产出不同妖兽材料）
const 狩猎区域配置: Array = [
	{"id": "后山浅林", "名称": "后山浅林", "等级要求": 1, "危险度": 1, "产出": ["妖兽血", "妖兽皮", "妖兽筋骨"], "稀有产出": ["狐火晶"], "描述": "宗门后山的浅林，常见低阶妖兽出没。"},
	{"id": "黑风山脉", "名称": "黑风山脉", "等级要求": 3, "危险度": 3, "产出": ["妖兽筋骨", "妖兽皮", "狐火晶"], "稀有产出": ["鹏羽"], "描述": "黑风呼啸的山脉，中阶妖兽的栖息地。"},
	{"id": "万兽深谷", "名称": "万兽深谷", "等级要求": 5, "危险度": 5, "产出": ["鹏羽", "狐火晶", "妖兽筋骨"], "稀有产出": ["麒麟鳞"], "描述": "万兽聚居的深谷，常有高阶妖兽踪迹。"},
	{"id": "蛮荒古林", "名称": "蛮荒古林", "等级要求": 7, "危险度": 7, "产出": ["麒麟鳞", "鹏羽", "狐火晶"], "稀有产出": ["凤凰羽"], "描述": "蛮荒之地的古老森林，传说有神兽栖息。"},
	{"id": "九天仙境", "名称": "九天仙境", "等级要求": 9, "危险度": 9, "产出": ["凤凰羽", "麒麟鳞", "鹏羽"], "稀有产出": ["龙鳞"], "描述": "九天之上的仙境，只有大能方可进入。"},
]

# 采药区域配置
const 采药区域配置: Array = [
	{"id": "药圃后山", "名称": "药圃后山", "等级要求": 1, "危险度": 1, "产出": ["凡阶灵草"], "稀有产出": ["百年灵草"], "描述": "宗门药圃后的山坡，常见低阶灵草。"},
	{"id": "幽谷灵溪", "名称": "幽谷灵溪", "等级要求": 3, "危险度": 2, "产出": ["百年灵草", "凡阶灵草"], "稀有产出": ["三百年灵草"], "描述": "灵气氤氲的幽谷溪流，中阶灵草生长之地。"},
	{"id": "毒瘴沼泽", "名称": "毒瘴沼泽", "等级要求": 5, "危险度": 5, "产出": ["三百年灵草", "百年灵草"], "稀有产出": ["五百年灵草"], "描述": "毒瘴弥漫的沼泽，珍稀毒草与灵药并存。"},
	{"id": "万年药谷", "名称": "万年药谷", "等级要求": 7, "危险度": 6, "产出": ["五百年灵草", "三百年灵草"], "稀有产出": ["千年灵草"], "描述": "万年不遇的药谷，高阶灵草遍地。"},
	{"id": "瑶池仙园", "名称": "瑶池仙园", "等级要求": 9, "危险度": 8, "产出": ["千年灵草", "五百年灵草"], "稀有产出": ["万年灵草"], "描述": "西王母的瑶池仙园，只有仙人可入。"},
]

## 获取狩猎区域列表（已解锁）
func 获取狩猎区域列表() -> Array:
	var 结果: Array = []
	for 区域 in 狩猎区域配置:
		if 狩猎等级 >= int(区域["等级要求"]):
			结果.append(区域)
	return 结果

## 获取采药区域列表（已解锁）
func 获取采药区域列表() -> Array:
	var 结果: Array = []
	for 区域 in 采药区域配置:
		if 采药等级 >= int(区域["等级要求"]):
			结果.append(区域)
	return 结果

## 宗主亲自狩猎
func 宗主狩猎(区域ID: String) -> Dictionary:
	# 查找区域
	var 目标区域: Dictionary = {}
	for 区域 in 狩猎区域配置:
		if str(区域["id"]) == 区域ID:
			目标区域 = 区域
			break
	if 目标区域.is_empty():
		return {"成功": false, "原因": "未找到该狩猎区域"}
	if 狩猎等级 < int(目标区域["等级要求"]):
		return {"成功": false, "原因": "狩猎品级不足，需%d品" % int(目标区域["等级要求"])}
	# 次数限制（每日10次，修真化：精力有限）
	if 今日狩猎次数 >= 10:
		return {"成功": false, "原因": "今日精力已竭，明日再入山狩猎"}
	今日狩猎次数 += 1
	# 计算收获（基于狩猎等级和区域危险度）
	var 基础收获: int = 1 + int(狩猎等级 / 3)
	var 危险度: int = int(目标区域["危险度"])
	var 收获列表: Array = []
	# 普通产出
	for i in range(基础收获):
		var 产出列表: Array = 目标区域["产出"]
		var 材料名: String = str(产出列表[randi() % 产出列表.size()])
		收获列表.append(材料名)
		_添加材料到库房(材料名, 1)
	# 稀有产出（概率=狩猎等级*2%）
	if randf() < float(狩猎等级) * 0.02:
		var 稀有列表: Array = 目标区域["稀有产出"]
		var 稀有材料: String = str(稀有列表[randi() % 稀有列表.size()])
		收获列表.append(稀有材料)
		_添加材料到库房(稀有材料, 1)
	# 增加经验
	狩猎经验 += 危险度 * 10
	# 升级判定
	while 狩猎经验 >= 狩猎等级 * 100:
		狩猎经验 -= 狩猎等级 * 100
		狩猎等级 += 1
		添加纪事("大事件", "狩猎精进", "宗主狩猎技艺提升至%d级" % 狩猎等级, 2)
	# 意外事件（低概率）
	var 意外文本: String = ""
	if randf() < 0.05:
		意外文本 = "狩猎时偶遇灵兽幼崽，心生怜悯将其放生，积累功德。"
		功德 += 10
	elif randf() < 0.03:
		意外文本 = "狩猎时不慎被妖兽所伤，耗费些许灵力。"
		# 轻微损失（不扣血，只减经验）
		狩猎经验 = max(0, 狩猎经验 - 10)
	添加纪事("庶务", "入山狩猎", "宗主前往%s狩猎，获得%s%s" % [目标区域["名称"], "、".join(收获列表), "。" + 意外文本 if 意外文本 else ""], 1)
	return {"成功": true, "区域": 目标区域["名称"], "收获": 收获列表, "意外": 意外文本, "狩猎等级": 狩猎等级}

## 宗主亲自采药
func 宗主采药(区域ID: String) -> Dictionary:
	var 目标区域: Dictionary = {}
	for 区域 in 采药区域配置:
		if str(区域["id"]) == 区域ID:
			目标区域 = 区域
			break
	if 目标区域.is_empty():
		return {"成功": false, "原因": "未找到该采药区域"}
	if 采药等级 < int(目标区域["等级要求"]):
		return {"成功": false, "原因": "采药品级不足，需%d品" % int(目标区域["等级要求"])}
	if 今日采药次数 >= 10:
		return {"成功": false, "原因": "今日精力已竭，明日再入山采药"}
	今日采药次数 += 1
	var 基础收获: int = 1 + int(采药等级 / 3)
	var 危险度: int = int(目标区域["危险度"])
	var 收获列表: Array = []
	for i in range(基础收获):
		var 产出列表: Array = 目标区域["产出"]
		var 材料名: String = str(产出列表[randi() % 产出列表.size()])
		收获列表.append(材料名)
		_添加材料到库房(材料名, 1)
	if randf() < float(采药等级) * 0.02:
		var 稀有列表: Array = 目标区域["稀有产出"]
		var 稀有材料: String = str(稀有列表[randi() % 稀有列表.size()])
		收获列表.append(稀有材料)
		_添加材料到库房(稀有材料, 1)
	采药经验 += 危险度 * 10
	while 采药经验 >= 采药等级 * 100:
		采药经验 -= 采药等级 * 100
		采药等级 += 1
		添加纪事("大事件", "采药精进", "宗主采药技艺提升至%d级" % 采药等级, 2)
	var 意外文本: String = ""
	if randf() < 0.05:
		意外文本 = "采药时发现一株异种灵草，欣喜之余小心翼翼采下。"
		采药经验 += 20
	elif randf() < 0.03:
		意外文本 = "采药时误触毒草，手指微麻，耗费些许灵力化解。"
		采药经验 = max(0, 采药经验 - 10)
	添加纪事("庶务", "入山采药", "宗主前往%s采药，获得%s%s" % [目标区域["名称"], "、".join(收获列表), "。" + 意外文本 if 意外文本 else ""], 1)
	return {"成功": true, "区域": 目标区域["名称"], "收获": 收获列表, "意外": 意外文本, "采药等级": 采药等级}

## 弟子自动狩猎采药（月度推演调用）
func _弟子自动狩猎采药_S48() -> void:
	# 每季度，在宗弟子中选择适合的弟子自动狩猎采药
	# 选择标准：无司职、境界在练气-金丹、性格喜好山林
	var 狩猎弟子: Array = []
	var 采药弟子: Array = []
	for d in 弟子列表:
		if d == null or not (d is Disciple) or str(d.状态) != "在宗":
			continue
		if str(d.司职) != "":
			continue  # 有司职的弟子不参与
		var 境界序: int = Disciple.境界序.find(str(d.境界))
		if 境界序 < 0 or 境界序 > 3:  # 练气-金丹
			continue
		# 根据性格选择
		if str(d.性格) in ["好动", "勇敢", "鲁莽"]:
			狩猎弟子.append(d)
		elif str(d.性格) in ["细心", "沉稳", "温和"]:
			采药弟子.append(d)
	# 狩猎弟子（每季度最多5人）
	for i in range(min(5, 狩猎弟子.size())):
		var d = 狩猎弟子[i]
		var 区域列表: Array = 获取狩猎区域列表()
		if 区域列表.size() == 0:
			break
		var 区域: Dictionary = 区域列表[randi() % 区域列表.size()]
		var 产出列表: Array = 区域["产出"]
		var 材料名: String = str(产出列表[randi() % 产出列表.size()])
		_添加材料到库房(材料名, 1)
		_加推演条目("%s前往%s狩猎，获得%s" % [d.姓名, 区域["名称"], 材料名], "庶务", "低")
	# 采药弟子（每季度最多5人）
	for i in range(min(5, 采药弟子.size())):
		var d = 采药弟子[i]
		var 区域列表: Array = 获取采药区域列表()
		if 区域列表.size() == 0:
			break
		var 区域: Dictionary = 区域列表[randi() % 区域列表.size()]
		var 产出列表: Array = 区域["产出"]
		var 材料名: String = str(产出列表[randi() % 产出列表.size()])
		_添加材料到库房(材料名, 1)
		_加推演条目("%s前往%s采药，获得%s" % [d.姓名, 区域["名称"], 材料名], "庶务", "低")

## 辅助：添加材料到库房
func _添加材料到库房(材料名: String, 数量: int) -> void:
	# 查找现有材料
	for it in 宗门库房:
		if it != null and it is Item and str(it.名称) == 材料名:
			it.数量 += 数量
			return
	# 创建新材料
	var 新材 = Item.new()
	新材.名称 = 材料名
	新材.类别 = "材料"
	新材.数量 = 数量
	新材.描述 = "狩猎采药获得的%s" % 材料名
	宗门库房.append(新材)

## 检查材料库存
func _检查材料库存(材料名: String, 数量: int) -> bool:
	for it in 宗门库房:
		if it != null and it is Item and str(it.名称) == 材料名:
			return it.数量 >= 数量
	return false

# ===== S52 弟子休闲行为系统 =====
# 修真世界观：弟子闲暇时自主参与休闲活动，产出按设置比例上交宗门
func _弟子休闲行为_S52() -> void:
	# 每季度，有休闲天赋的弟子自主参与休闲活动
	var 休闲弟子: Array = []
	for d in 弟子列表:
		if d == null or not (d is Disciple) or str(d.状态) != "在宗":
			continue
		if str(d.休闲天赋) == "无" and str(d.指定休闲) == "":
			continue  # 无休闲天赋且未指定的弟子不主动参与
		# 闭关/受伤/突破中的弟子不参与
		if str(d.状态) != "在宗":
			continue
		休闲弟子.append(d)
	# 每季度最多15人参与休闲（性能控制，专精弟子优先）
	休闲弟子.sort_custom(func(a, b): return int(a.休闲专精) > int(b.休闲专精))
	var 参与人数: int = min(15, 休闲弟子.size())
	for i in range(参与人数):
		var d = 休闲弟子[i]
		# S55 P1：优先使用指定休闲，否则使用天赋
		var 休闲类型: String = str(d.指定休闲) if str(d.指定休闲) != "" else str(d.休闲天赋)
		# 专精弟子产出+50%
		var 产出倍率: float = 1.5 if bool(d.休闲专精) else 1.0
		# 根据休闲类型进行休闲活动
		match 休闲类型:
			"钓道":
				_弟子钓鱼_S52(d, 产出倍率)
			"酿道":
				_弟子酿酒_S52(d, 产出倍率)
			"茶道":
				_弟子品茶_S52(d, 产出倍率)
			"琴道":
				_弟子弹琴_S52(d, 产出倍率)
			"厨道":
				_弟子烹饪_S52(d, 产出倍率)
			"棋道":
				_弟子弈棋_S52(d, 产出倍率)
			"画道":
				_弟子作画_S52(d, 产出倍率)
		# S55 P1：休闲技能经验升级
		_提升休闲技能_S55(d, 休闲类型)
		# S55 P2：休闲奇遇事件（5%概率触发）
		if randf() < 0.05:
			_触发休闲奇遇_S55(d, 休闲类型)
	# S55 P2：师徒休闲传承（每季度，师傅传授休闲技能给徒弟）
	_师徒休闲传承_S55()

# S55 P2：师徒休闲传承
func _师徒休闲传承_S55() -> void:
	# 遍历所有有徒弟的师傅
	for 师 in 弟子列表:
		if 师 == null or not (师 is Disciple) or str(师.状态) != "在宗":
			continue
		if 师.徒弟列表.size() == 0:
			continue
		# 师傅擅长的休闲技能（等级>=3的）
		var 擅长技能: Array = []
		for 类型 in ["钓道", "酿道", "茶道", "琴道", "厨道", "棋道", "画道"]:
			if int(师.休闲技能.get(类型, 0)) >= 3:
				擅长技能.append(类型)
		if 擅长技能.size() == 0:
			continue
		# 每季度传授1-2个徒弟
		var 传授数: int = min(2, 师.徒弟列表.size())
		for i in range(传授数):
			var 徒ID: int = int(师.徒弟列表[i])
			var 徒: Disciple = _按ID找弟子(徒ID)
			if 徒 == null or str(徒.状态) != "在宗":
				continue
			# 随机选择一个师傅擅长的技能传授
			var 传授类型: String = 擅长技能[randi() % 擅长技能.size()]
			var 师等级: int = int(师.休闲技能.get(传授类型, 0))
			var 徒等级: int = int(徒.休闲技能.get(传授类型, 0))
			if 徒等级 >= 师等级:
				continue  # 徒弟等级不低于师傅，无需传授
			# 传授经验：师傅等级×10，师徒关系加成
			var 传授经验: int = 师等级 * 10
			# 师徒亲密度加成（简化：忠诚越高效果越好）
			if int(徒.忠诚) >= 80:
				传授经验 = int(传授经验 * 1.5)
			徒.休闲经验[传授类型] = int(徒.休闲经验.get(传授类型, 0)) + 传授经验
			# 30%概率触发深度传承（徒弟直接升一级）
			if randf() < 0.3 and 徒等级 < 师等级:
				徒.休闲技能[传授类型] = 徒等级 + 1
				_加推演条目("%s向徒弟%s深度传承%s技艺，徒弟技艺大进！" % [师.姓名, 徒.姓名, 传授类型], "机缘", "中")
				添加纪事("休闲", "师徒传承", "%s向%s深度传承%s，徒弟技艺精进。" % [师.姓名, 徒.姓名, 传授类型], 1)
			else:
				_加推演条目("%s向徒弟%s传授%s技艺。" % [师.姓名, 徒.姓名, 传授类型], "庶务", "低")

# S55 P2：宗门休闲大赛（每季度举办，钓鱼比赛/品酒大会/琴棋书画大赛）
var _休闲大赛冷却: int = 0  # 冷却季度数
func _宗门休闲大赛_S55() -> void:
	# 每3季度举办一次大赛
	if _休闲大赛冷却 > 0:
		_休闲大赛冷却 -= 1
		return
	_休闲大赛冷却 = 3
	# 随机选择大赛类型
	var 大赛类型: Array = ["钓鱼大赛", "品酒大会", "琴艺大赛", "厨艺大赛", "棋艺大赛", "画艺大赛"]
	var 类型: String = 大赛类型[randi() % 大赛类型.size()]
	var 对应技能: Dictionary = {
		"钓鱼大赛": "钓道",
		"品酒大会": "酿道",
		"琴艺大赛": "琴道",
		"厨艺大赛": "厨道",
		"棋艺大赛": "棋道",
		"画艺大赛": "画道",
	}
	var 技能类型: String = str(对应技能.get(类型, "钓道"))
	# 报名弟子（技能等级>=1的在宗弟子）
	var 报名: Array = []
	for d in 弟子列表:
		if d == null or not (d is Disciple) or str(d.状态) != "在宗":
			continue
		if int(d.休闲技能.get(技能类型, 0)) >= 1:
			报名.append(d)
	if 报名.size() < 3:
		_加推演条目("宗门欲举办%s，但报名弟子不足，赛事取消。" % 类型, "庶务", "低")
		return
	# 按技能等级排序（高到低），加入随机因素
	报名.sort_custom(func(a, b):
		var 分a: int = int(a.休闲技能.get(技能类型, 0)) * 10 + randi_range(0, 20)
		var 分b: int = int(b.休闲技能.get(技能类型, 0)) * 10 + randi_range(0, 20)
		return 分a > 分b
	)
	# 前三名
	var 冠军: Disciple = 报名[0]
	var 亚军: Disciple = 报名[1] if 报名.size() > 1 else null
	var 季军: Disciple = 报名[2] if 报名.size() > 2 else null
	# 奖励
	var 冠军奖励: int = 500
	var 亚军奖励: int = 300
	var 季军奖励: int = 100
	灵石 -= 冠军奖励 + (亚军奖励 if 亚军 != null else 0) + (季军奖励 if 季军 != null else 0)
	冠军.贡献点 = int(冠军.贡献点) + 50
	冠军.忠诚 = min(100, int(冠军.忠诚) + 5)
	if 亚军 != null:
		亚军.贡献点 = int(亚军.贡献点) + 30
		亚军.忠诚 = min(100, int(亚军.忠诚) + 3)
	if 季军 != null:
		季军.贡献点 = int(季军.贡献点) + 10
		季军.忠诚 = min(100, int(季军.忠诚) + 2)
	# 所有参赛弟子获得参与奖
	for d in 报名:
		d.忠诚 = min(100, int(d.忠诚) + 1)
	# 纪事和推演
	var 结果: String = "宗门举办%s，%s技压群雄夺得冠军，获灵石%d、贡献点50。" % [类型, 冠军.姓名, 冠军奖励]
	if 亚军 != null:
		结果 += "%s获亚军。" % 亚军.姓名
	if 季军 != null:
		结果 += "%s获季军。" % 季军.姓名
	添加纪事("休闲", "宗门大赛", 结果, 2)
	_加推演条目(结果, "机缘", "高")
	# 冠军技能经验大增
	冠军.休闲经验[技能类型] = int(冠军.休闲经验.get(技能类型, 0)) + 200

# S55 P1：休闲技能经验升级（基于经验值，满级10级）
func _提升休闲技能_S55(d: Disciple, 休闲类型: String) -> void:
	var 经验: int = int(d.休闲经验.get(休闲类型, 0))
	var 当前等级: int = int(d.休闲技能.get(休闲类型, 0))
	if 当前等级 >= 10:
		return  # 已满级
	# 升级所需经验：等级×100
	var 升级所需: int = (当前等级 + 1) * 100
	if 经验 >= 升级所需:
		d.休闲技能[休闲类型] = 当前等级 + 1
		d.休闲经验[休闲类型] = 经验 - 升级所需
		_加推演条目("%s的%s技艺精进，已达%d级。" % [d.姓名, 休闲类型, 当前等级 + 1], "庶务", "中")
		# 满级时特殊通知
		if 当前等级 + 1 >= 10:
			添加纪事("休闲", "技艺大成", "%s的%s技艺已达化境，堪称一代宗师！" % [d.姓名, 休闲类型], 2)

# S55 P2：弟子休闲奇遇事件（修真小说常见桥段）
func _触发休闲奇遇_S55(d: Disciple, 休闲类型: String) -> void:
	var 技能等级: int = int(d.休闲技能.get(休闲类型, 0))
	match 休闲类型:
		"钓道":
			# 钓鱼奇遇：钓到宝箱/古修遗物/灵龟献宝
			var 奇遇: int = randi() % 3
			match 奇遇:
				0:
					# 钓到宝箱
					var 宝箱灵石: int = randi_range(100, 1000) * (1 + int(技能等级 / 3))
					灵石 += 宝箱灵石
					添加纪事("休闲", "垂钓奇遇", "%s垂钓时钓得一只古旧宝箱，内藏%d灵石！" % [d.姓名, 宝箱灵石], 2)
					_加推演条目("%s垂钓奇遇，钓得宝箱，获灵石%d。" % [d.姓名, 宝箱灵石], "机缘", "高")
				1:
					# 灵龟献宝
					var 物品名: String = ["避水珠", "定风珠", "聚灵珠"][randi() % 3]
					_添加灵材到库房(物品名, "宝阶", "灵龟献宝")
					添加纪事("休闲", "灵龟献宝", "%s垂钓时遇千年灵龟，灵龟口衔%s相赠。" % [d.姓名, 物品名], 2)
					_加推演条目("%s遇灵龟献宝，得%s。" % [d.姓名, 物品名], "机缘", "高")
				2:
					# 水中悟道
					d.修炼速度 = float(d.修炼速度) * 1.05
					添加纪事("休闲", "水中悟道", "%s垂钓时观水面涟漪，忽有所悟，修炼速度永久提升。" % d.姓名, 2)
					_加推演条目("%s垂钓悟道，修炼速度提升。" % d.姓名, "机缘", "中")
		"酿道":
			# 酿酒奇遇：酿出神品/酒仙入梦/灵泉涌现
			var 奇遇: int = randi() % 3
			match 奇遇:
				0:
					# 酿出神品
					_添加灵材到库房("仙酿·瑶池玉液", "圣阶", "弟子神品酿造")
					添加纪事("休闲", "神品佳酿", "%s酿酒时忽得灵感，酿出一坛瑶池玉液，堪称神品！" % d.姓名, 2)
					_加推演条目("%s酿出神品佳酿瑶池玉液。" % d.姓名, "机缘", "高")
				1:
					# 酒仙入梦
					d.休闲经验["酿道"] = int(d.休闲经验.get("酿道", 0)) + 500
					添加纪事("休闲", "酒仙入梦", "%s梦中得酒仙指点，酿道技艺大进。" % d.姓名, 2)
					_加推演条目("%s梦遇酒仙，酿道精进。" % d.姓名, "机缘", "中")
				2:
					# 灵泉涌现
					灵石 += 500
					添加纪事("休闲", "灵泉涌现", "%s酿酒时引动地下灵泉，宗门灵石增加500。" % d.姓名, 2)
					_加推演条目("%s引动灵泉，宗门灵石+500。" % d.姓名, "机缘", "中")
		"茶道":
			# 品茶奇遇：茶圣指点/悟道/灵茶化形
			var 奇遇: int = randi() % 3
			match 奇遇:
				0:
					# 茶圣指点
					d.休闲经验["茶道"] = int(d.休闲经验.get("茶道", 0)) + 500
					添加纪事("休闲", "茶圣指点", "%s品茶时似有茶圣在侧指点，茶道技艺大进。" % d.姓名, 2)
					_加推演条目("%s得茶圣指点，茶道精进。" % d.姓名, "机缘", "中")
				1:
					# 品茶悟道
					悟道点 += 20
					添加纪事("休闲", "品茶悟道", "%s品茶时心境澄明，悟得大道，悟道点+20。" % d.姓名, 2)
					_加推演条目("%s品茶悟道，悟道点+20。" % d.姓名, "机缘", "高")
				2:
					# 灵茶化形
					_添加灵材到库房("悟道仙茶", "宝阶", "灵茶化形")
					添加纪事("休闲", "灵茶化形", "%s培育的灵茶忽化人形，拜谢后留下一株悟道仙茶。" % d.姓名, 2)
					_加推演条目("%s培育灵茶化形，得悟道仙茶。" % d.姓名, "机缘", "高")
		"琴道":
			# 弹琴奇遇：百鸟朝凤/知音相遇/琴心剑胆
			var 奇遇: int = randi() % 3
			match 奇遇:
				0:
					# 百鸟朝凤
					d.忠诚 = min(100, int(d.忠诚) + 10)
					添加纪事("休闲", "百鸟朝凤", "%s抚琴一曲，引得百鸟来朝，宗门弟子忠诚提升。" % d.姓名, 2)
					_加推演条目("%s抚琴引百鸟朝凤，弟子忠诚提升。" % d.姓名, "机缘", "中")
				1:
					# 知音相遇
					添加纪事("休闲", "知音相遇", "%s抚琴时遇知音，二人结为莫逆之交。" % d.姓名, 2)
					_加推演条目("%s抚琴遇知音。" % d.姓名, "机缘", "中")
				2:
					# 琴心剑胆
					d.修炼速度 = float(d.修炼速度) * 1.03
					添加纪事("休闲", "琴心剑胆", "%s抚琴时悟得琴心剑胆之境，修炼速度提升。" % d.姓名, 2)
					_加推演条目("%s悟得琴心剑胆，修炼速度提升。" % d.姓名, "机缘", "中")
		"厨道":
			# 烹饪奇遇：食神降临/美食化灵/满汉全席
			var 奇遇: int = randi() % 3
			match 奇遇:
				0:
					# 食神降临
					for 弟子 in 弟子列表:
						if 弟子 != null and 弟子 is Disciple and str(弟子.状态) == "在宗":
							弟子.忠诚 = min(100, int(弟子.忠诚) + 5)
					添加纪事("休闲", "食神降临", "%s烹饪时引得食神降临，全宗弟子品尝美食后忠诚大增。" % d.姓名, 2)
					_加推演条目("%s烹饪引食神降临，全宗忠诚提升。" % d.姓名, "机缘", "高")
				1:
					# 美食化灵
					_添加灵材到库房("灵食·龙肝凤髓", "宝阶", "美食化灵")
					添加纪事("休闲", "美食化灵", "%s烹饪的美食忽化灵气，凝成一份龙肝凤髓。" % d.姓名, 2)
					_加推演条目("%s烹饪美食化灵，得龙肝凤髓。" % d.姓名, "机缘", "高")
				2:
					# 厨艺大成
					d.休闲经验["厨道"] = int(d.休闲经验.get("厨道", 0)) + 500
					添加纪事("休闲", "厨艺大成", "%s烹饪时忽得灵感，厨艺大进。" % d.姓名, 2)
					_加推演条目("%s厨艺大成。" % d.姓名, "机缘", "中")
		"棋道":
			# 弈棋奇遇：棋仙对弈/棋局悟道/珍珑棋局
			var 奇遇: int = randi() % 3
			match 奇遇:
				0:
					# 棋仙对弈
					d.休闲经验["棋道"] = int(d.休闲经验.get("棋道", 0)) + 500
					悟道点 += 10
					添加纪事("休闲", "棋仙对弈", "%s弈棋时遇棋仙下凡对弈，虽败犹荣，棋道与悟性大进。" % d.姓名, 2)
					_加推演条目("%s遇棋仙对弈，棋道精进，悟道点+10。" % d.姓名, "机缘", "高")
				1:
					# 棋局悟道
					悟道点 += 30
					添加纪事("休闲", "棋局悟道", "%s弈棋时于棋局中悟得大道，悟道点+30。" % d.姓名, 2)
					_加推演条目("%s棋局悟道，悟道点+30。" % d.姓名, "机缘", "高")
				2:
					# 珍珑棋局
					添加纪事("休闲", "珍珑棋局", "%s弈棋时摆出珍珑棋局，引来全宗弟子围观参悟。" % d.姓名, 2)
					_加推演条目("%s摆出珍珑棋局。" % d.姓名, "机缘", "中")
		"画道":
			# 作画奇遇：画龙点睛/画中仙/神来之笔
			var 奇遇: int = randi() % 3
			match 奇遇:
				0:
					# 画龙点睛
					_添加灵材到库房("神龙图", "圣阶", "画龙点睛")
					添加纪事("休闲", "画龙点睛", "%s作画时画龙点睛，神龙破壁而出，留下一幅神龙图。" % d.姓名, 2)
					_加推演条目("%s画龙点睛，得神龙图。" % d.姓名, "机缘", "高")
				1:
					# 画中仙
					添加纪事("休闲", "画中仙", "%s作画时画中走出一位仙子，与论道后翩然离去。" % d.姓名, 2)
					_加推演条目("%s遇画中仙。" % d.姓名, "机缘", "高")
				2:
					# 神来之笔
					d.休闲经验["画道"] = int(d.休闲经验.get("画道", 0)) + 500
					添加纪事("休闲", "神来之笔", "%s作画时忽得神来之笔，画道大进。" % d.姓名, 2)
					_加推演条目("%s得神来之笔，画道精进。" % d.姓名, "机缘", "中")

# 弟子钓鱼（修真世界观：弟子没有宗主的机缘和资源，顶级鱼获极难获得）
func _弟子钓鱼_S52(d: Disciple, 产出倍率: float = 1.0) -> void:
	# 有钓道天赋的弟子每季度钓1-3条鱼（专精+50%）
	var 钓鱼数: int = int(randi_range(1, 3) * 产出倍率)
	var 技能等级: int = int(d.休闲技能.get("钓道", 0))
	var 上交比例: float = float(d.休闲上交比例) / 100.0
	for i in range(钓鱼数):
		# 弟子钓鱼品阶限制（避免玩家感情受伤）：
		# 默认凡阶/灵阶；宝阶需技能≥5且15%概率；王阶需技能≥8且5%概率；圣阶以上基本不可能
		var 品阶: String = "凡阶"
		var rp: float = randf()
		if 技能等级 >= 10 and rp < 0.01:
			品阶 = "圣阶"  # 技能满级才有1%概率钓到圣阶
		elif 技能等级 >= 8 and rp < 0.05:
			品阶 = "王阶"  # 技能8级以上才有5%概率钓到王阶
		elif 技能等级 >= 5 and rp < 0.15:
			品阶 = "宝阶"  # 技能5级以上才有15%概率钓到宝阶
		elif rp < 0.4:
			品阶 = "灵阶"  # 40%概率灵阶
		else:
			品阶 = "凡阶"  # 其余凡阶
		# 弟子钓不到需要特殊条件的鱼（如龙、鲛人等），只钓普通灵鱼
		var 鱼名: String = _随机普通鱼名(品阶)
		# 按设置比例上交宗门，其余自留
		if randf() < 上交比例:
			_添加灵材到库房(鱼名, 品阶, "弟子垂钓所得")
			d.上月休闲产出["钓道"] = str(d.上月休闲产出.get("钓道", "")) + 鱼名 + "、"
		else:
			# 自留（简化处理，记录到弟子私库）
			d.上月休闲产出["钓道_自留"] = int(d.上月休闲产出.get("钓道_自留", 0)) + 1
	# 增加休闲经验
	d.休闲经验["钓道"] = int(d.休闲经验.get("钓道", 0)) + randi_range(10, 30)
	_加推演条目("%s闲暇垂钓，收获颇丰。" % d.姓名, "庶务", "低")

# 弟子酿酒
func _弟子酿酒_S52(d: Disciple, 产出倍率: float = 1.0) -> void:
	var 技能等级: int = int(d.休闲技能.get("酿道", 0))
	var 酒名: String = _随机酒名(技能等级)
	var 品阶: String = "凡阶"
	if 技能等级 >= 3:
		品阶 = "灵阶"
	if 技能等级 >= 5:
		品阶 = "宝阶"
	var 上交比例: float = float(d.休闲上交比例) / 100.0
	# 按设置比例上交宗门
	if randf() < 上交比例:
		_添加灵材到库房(酒名, 品阶, "弟子酿造")
		d.上月休闲产出["酿道"] = 酒名
	else:
		d.上月休闲产出["酿道_自留"] = 酒名
	# 增加休闲经验
	d.休闲经验["酿道"] = int(d.休闲经验.get("酿道", 0)) + randi_range(10, 30)
	_加推演条目("%s闲暇酿酒，酿得一壶%s。" % [d.姓名, 酒名], "庶务", "低")

# 弟子品茶
func _弟子品茶_S52(d: Disciple, 产出倍率: float = 1.0) -> void:
	# 品茶主要是心境提升，产出较少
	var 技能等级: int = int(d.休闲技能.get("茶道", 0))
	# 品茶提升心境，增加修炼速度（临时）
	d.修炼速度 = float(d.修炼速度) * 1.02
	# 增加休闲经验
	d.休闲经验["茶道"] = int(d.休闲经验.get("茶道", 0)) + randi_range(10, 30)
	_加推演条目("%s闲暇品茶，心境澄明，修炼略有精进。" % d.姓名, "庶务", "低")

# 弟子弹琴
func _弟子弹琴_S52(d: Disciple, 产出倍率: float = 1.0) -> void:
	var 技能等级: int = int(d.休闲技能.get("琴道", 0))
	# 弹琴有概率遇到知音（结为好友/道侣）
	if randf() < 0.05 and 技能等级 >= 3:
		_加推演条目("%s抚琴一曲，遇知音相和，二人结为好友。" % d.姓名, "机缘", "中")
	# 增加休闲经验
	d.休闲经验["琴道"] = int(d.休闲经验.get("琴道", 0)) + randi_range(10, 30)
	_加推演条目("%s闲暇抚琴，琴音袅袅。" % d.姓名, "庶务", "低")

# 弟子烹饪
func _弟子烹饪_S52(d: Disciple, 产出倍率: float = 1.0) -> void:
	var 技能等级: int = int(d.休闲技能.get("厨道", 0))
	var 菜名: String = _随机菜名(技能等级)
	var 上交比例: float = float(d.休闲上交比例) / 100.0
	# 按设置比例上交宗门（提升全宗弟子忠诚）
	if randf() < 上交比例:
		# 烹饪美食提升在宗弟子忠诚
		for 弟子 in 弟子列表:
			if 弟子 != null and 弟子 is Disciple and str(弟子.状态) == "在宗":
				弟子.忠诚 = min(100, int(弟子.忠诚) + 1)
		d.上月休闲产出["厨道"] = 菜名
	else:
		d.上月休闲产出["厨道_自留"] = 菜名
	# 增加休闲经验
	d.休闲经验["厨道"] = int(d.休闲经验.get("厨道", 0)) + randi_range(10, 30)
	_加推演条目("%s烹饪美食%s，全宗弟子品尝后皆大欢喜，忠诚提升。" % [d.姓名, 菜名], "庶务", "低")

# 弟子弈棋
func _弟子弈棋_S52(d: Disciple, 产出倍率: float = 1.0) -> void:
	# 弈棋提升悟性
	var 技能等级: int = int(d.休闲技能.get("棋道", 0))
	if randf() < 0.2:
		悟道点 += 5 + 技能等级
	# 增加休闲经验
	d.休闲经验["棋道"] = int(d.休闲经验.get("棋道", 0)) + randi_range(10, 30)
	_加推演条目("%s闲暇弈棋，于棋局中悟得道理，悟道点+%d。" % [d.姓名, 5 + 技能等级], "庶务", "低")

# 弟子作画
func _弟子作画_S52(d: Disciple, 产出倍率: float = 1.0) -> void:
	var 技能等级: int = int(d.休闲技能.get("画道", 0))
	var 画名: String = _随机画名(技能等级)
	var 品阶: String = "凡阶"
	if 技能等级 >= 3:
		品阶 = "灵阶"
	if 技能等级 >= 5:
		品阶 = "宝阶"
	var 上交比例: float = float(d.休闲上交比例) / 100.0
	if randf() < 上交比例:
		_添加灵材到库房(画名, 品阶, "弟子画作")
		d.上月休闲产出["画道"] = 画名
	else:
		d.上月休闲产出["画道_自留"] = 画名
	# 增加休闲经验
	d.休闲经验["画道"] = int(d.休闲经验.get("画道", 0)) + randi_range(10, 30)
	_加推演条目("%s闲暇作画，绘得一幅%s。" % [d.姓名, 画名], "庶务", "低")

# 辅助：随机鱼名（弟子用，只有普通灵鱼，没有特殊条件鱼）
func _随机普通鱼名(品阶: String) -> String:
	var 鱼名池: Dictionary = {
		"凡阶": ["灵鲫", "灵鲤", "灵鲢", "灵鲈", "灵鳅", "灵鳝"],
		"灵阶": ["银鳞鲤", "金背鲫", "灵鳗", "灵鳝", "青鳞鱼", "赤尾鲤"],
		"宝阶": ["玄甲鲤", "金鳞鲤", "灵龟", "灵鳖", "银龙鱼", "赤龙鱼"],
		"王阶": ["金睛鲤", "玄水龟", "灵蛟", "碧水鲤", "紫金鳞", "天河鲫"],
		"圣阶": ["仙鲤", "灵鳌", "神龟", "天鳞鱼", "瑶池鲫", "银河鲤"],
	}
	var 池: Array = 鱼名池.get(品阶, ["灵鲫"])
	return 池[randi() % 池.size()]

# 辅助：随机鱼名（宗主用，包含特殊条件鱼）
func _随机鱼名(品阶: String) -> String:
	var 鱼名池: Dictionary = {
		"凡阶": ["灵鲫", "灵鲤", "灵鲢", "灵鲈"],
		"灵阶": ["龙鲤", "凤鲤", "灵鳗", "灵鳝"],
		"宝阶": ["蛟龙幼崽", "玄龟", "灵鲛"],
		"王阶": ["金睛蛟龙", "北冥玄龟"],
	}
	var 池: Array = 鱼名池.get(品阶, ["灵鲫"])
	return 池[randi() % 池.size()]

# 辅助：随机酒名
func _随机酒名(技能等级: int) -> String:
	if 技能等级 >= 5:
		return ["琼浆玉液", "蟠桃仙酿", "九天仙露"][randi() % 3]
	elif 技能等级 >= 3:
		return ["灵泉酿", "百花蜜酒", "松醪春"][randi() % 3]
	else:
		return ["米酒", "灵谷酒", "清醪"][randi() % 3]

# 辅助：随机菜名
func _随机菜名(技能等级: int) -> String:
	if 技能等级 >= 5:
		return ["熊掌炙", "龙肝凤髓", "蟠桃宴"][randi() % 3]
	elif 技能等级 >= 3:
		return ["灵鱼脍", "百禽羹", "灵米饭"][randi() % 3]
	else:
		return ["清炒灵蔬", "灵米粥", "烤鱼"][randi() % 3]

# 辅助：随机画名
func _随机画名(技能等级: int) -> String:
	if 技能等级 >= 5:
		return ["千里江山图", "百鸟朝凤图", "群仙宴饮图"][randi() % 3]
	elif 技能等级 >= 3:
		return ["山水图", "花鸟图", "仕女图"][randi() % 3]
	else:
		return ["涂鸦", "小品", "速写"][randi() % 3]

# 辅助：添加灵材到库房
func _添加灵材到库房(名称: String, 品阶: String, 描述: String) -> void:
	for it in 宗门库房:
		if it != null and it is Item and str(it.名称) == 名称:
			it.数量 += 1
			return
	var 新材 = Item.new()
	新材.名称 = 名称
	新材.类别 = "ling_cai"
	新材.品阶 = 品阶
	新材.数量 = 1
	新材.描述 = 描述
	宗门库房.append(新材)

## 消耗材料
func _消耗材料(材料名: String, 数量: int) -> void:
	for it in 宗门库房:
		if it != null and it is Item and str(it.名称) == 材料名:
			it.数量 -= 数量
			if it.数量 <= 0:
				宗门库房.erase(it)
			return



# ============ S49：灵酿酝造系统（仙家美酒·宗主亲酿+宴席外交）============
var 酿道等级: int = 1
var 酿道经验: int = 0
var 今日酿酒次数: int = 0
var 灵酿列表: Array = []  # 正在发酵的灵酿 [{名称, 配方, 开始日, 完成日}]

const 灵酿配方: Array = [
	{"id": "培元酒", "名称": "培元酒", "等级要求": 1, "材料": ["凡阶灵草", "灵米"], "发酵日": 30, "效果": "修炼速度+5%（持续90日）", "描述": "培元固本的入门灵酒，适合初入修仙者。"},
	{"id": "百花酿", "名称": "百花酿", "等级要求": 2, "材料": ["百年灵草", "灵米"], "发酵日": 60, "效果": "弟子忠诚+5（宴席用）", "描述": "以百花灵草酿制，香气馥郁，适合宴席款待。"},
	{"id": "清心酿", "名称": "清心酿", "等级要求": 3, "材料": ["三百年灵草", "灵米"], "发酵日": 90, "效果": "道心+10", "描述": "清心静神的灵酒，饮之可明心见性。"},
	{"id": "合欢酒", "名称": "合欢酒", "等级要求": 4, "材料": ["三百年灵草", "百年灵草"], "发酵日": 120, "效果": "外交声望+10（馈赠用）", "描述": "增进情谊的灵酒，外交馈赠佳品。"},
	{"id": "庆功酒", "名称": "庆功酒", "等级要求": 5, "材料": ["五百年灵草", "三百年灵草"], "发酵日": 150, "效果": "全宗士气+10（持续90日）", "描述": "庆祝大胜的灵酒，饮之士气大振。"},
	{"id": "琼浆玉液", "名称": "琼浆玉液", "等级要求": 7, "材料": ["千年灵草", "五百年灵草"], "发酵日": 300, "效果": "修炼速度+15%（持续180日）", "描述": "仙家极品灵酒，饮之修为大进。"},
	{"id": "猴儿酒", "名称": "猴儿酒", "等级要求": 9, "材料": ["万年灵草", "千年灵草"], "发酵日": 600, "效果": "全宗修炼+20%（持续360日）", "描述": "传说中灵猴所酿的绝世美酒，可遇不可求。"},
]

## 获取可酿造配方列表
func 获取灵酿配方列表() -> Array:
	var 结果: Array = []
	for 配方 in 灵酿配方:
		if 酿道等级 >= int(配方["等级要求"]):
			结果.append(配方)
	return 结果

## 宗主开始酿造灵酿
func 开始酿造灵酿(配方ID: String) -> Dictionary:
	var 目标配方: Dictionary = {}
	for 配方 in 灵酿配方:
		if str(配方["id"]) == 配方ID:
			目标配方 = 配方
			break
	if 目标配方.is_empty():
		return {"成功": false, "原因": "未找到该配方"}
	if 酿道等级 < int(目标配方["等级要求"]):
		return {"成功": false, "原因": "酿道品级不足，需%d品" % int(目标配方["等级要求"])}
	if 今日酿酒次数 >= 5:
		return {"成功": false, "原因": "今日精力已竭，明日再酿"}
	# 检查材料
	var 材料列表: Array = 目标配方["材料"]
	for 材料名 in 材料列表:
		if not _检查材料库存(str(材料名), 1):
			return {"成功": false, "原因": "材料不足：%s" % 材料名}
	# 消耗材料
	for 材料名 in 材料列表:
		_消耗材料(str(材料名), 1)
	今日酿酒次数 += 1
	# 开始发酵
	var 发酵日: int = int(目标配方["发酵日"])
	灵酿列表.append({
		"名称": 目标配方["名称"],
		"配方ID": 配方ID,
		"开始日": 累计游戏日,
		"完成日": 累计游戏日 + 发酵日,
		"效果": 目标配方["效果"]
	})
	酿道经验 += 10
	while 酿道经验 >= 酿道等级 * 100:
		酿道经验 -= 酿道等级 * 100
		酿道等级 += 1
	添加纪事("庶务", "酝造灵酿", "宗主开始酝造%s，需%d日方成" % [目标配方["名称"], 发酵日], 1)
	return {"成功": true, "名称": 目标配方["名称"], "完成日": 累计游戏日 + 发酵日}

## 灵酿月度结算（发酵完成）
func _灵酿月度结算_S49() -> void:
	var 完成列表: Array = []
	for 酿 in 灵酿列表:
		if 累计游戏日 >= int(酿["完成日"]):
			完成列表.append(酿)
	for 酿 in 完成列表:
		灵酿列表.erase(酿)
		# 生成灵酿物品
		var 新酿 = Item.new()
		新酿.名称 = str(酿["名称"])
		新酿.类别 = "灵酿"
		新酿.数量 = 1
		新酿.描述 = str(酿["效果"])
		宗门库房.append(新酿)
		_加推演条目("酝造的%s已成，入库房待用" % 酿["名称"], "庶务", "低")

## 举办灵酿宴席（消耗灵酿，增加弟子忠诚/士气）
func 举办灵酿宴席(灵酿名称: String) -> Dictionary:
	var 找到: bool = false
	for it in 宗门库房:
		if it != null and it is Item and str(it.名称) == 灵酿名称 and str(it.类别) == "灵酿":
			it.数量 -= 1
			if it.数量 <= 0:
				宗门库房.erase(it)
			找到 = true
			break
	if not 找到:
		return {"成功": false, "原因": "库房无此灵酿"}
	# 增加弟子忠诚和士气
	for d in 弟子列表:
		if d != null and d is Disciple and str(d.状态) == "在宗":
			d.增加忠诚(2)
	添加纪事("大事件", "灵酿宴席", "宗主以%s宴请全宗，弟子欢欣鼓舞，忠诚提升" % 灵酿名称, 2)
	return {"成功": true, "效果": "全宗弟子忠诚+2"}

# ============ S52：灵厨系统（仙家美食·灵食制作+临时增益）============
# 基于灵米/灵草/妖兽材料制作灵食，效果包括临时修炼加成、突破加成、心境提升等
# 修真世界观：高阶修士辟谷，但灵食仍可辅助修炼、提升心境
var 厨道等级: int = 1
var 厨道经验: int = 0
var 今日烹饪次数: int = 0

const 灵食配方: Array = [
	{"id": "灵米饭", "名称": "灵米饭", "等级要求": 1, "材料": ["灵米"], "效果": "修炼速度+3%（持续30日）", "描述": "最基础的灵食，以灵米蒸煮而成，灵气充沛。"},
	{"id": "百草羹", "名称": "百草羹", "等级要求": 2, "材料": ["凡阶灵草", "灵米"], "效果": "突破成功率+5%（持续30日）", "描述": "以百草灵草熬制，可辅助突破瓶颈。"},
	{"id": "妖兽烤肉", "名称": "妖兽烤肉", "等级要求": 3, "材料": ["妖兽肉", "灵米"], "效果": "道行+5%（持续30日）", "描述": "以妖兽精肉烤制，筋骨强健，道行提升。"},
	{"id": "清心莲子羹", "名称": "清心莲子羹", "等级要求": 4, "材料": ["百年灵草", "灵米"], "效果": "道心+5，心魔-5", "描述": "清心静神的灵食，可明心见性，驱除心魔。"},
	{"id": "龙虎金丹汤", "名称": "龙虎金丹汤", "等级要求": 5, "材料": ["三百年灵草", "妖兽内丹"], "效果": "修炼速度+10%（持续60日）", "描述": "以龙虎之精炼制，大补元气，修为精进。"},
	{"id": "凤髓龙肝", "名称": "凤髓龙肝", "等级要求": 7, "材料": ["五百年灵草", "高阶妖兽内丹"], "效果": "全宗修炼+8%（持续90日）", "描述": "仙家极品灵食，传说可令人脱胎换骨。"},
	{"id": "蟠桃盛宴", "名称": "蟠桃盛宴", "等级要求": 9, "材料": ["千年灵草", "万年灵草"], "效果": "全宗修炼+15%（持续180日）", "描述": "以仙家蟠桃为主料，可遇不可求的绝世灵食。"},
]

## 获取可烹饪灵食列表
func 获取灵食配方列表() -> Array:
	var 结果: Array = []
	for 配方 in 灵食配方:
		if 厨道等级 >= int(配方["等级要求"]):
			结果.append(配方)
	return 结果

## 宗主烹饪灵食
func 烹饪灵食(配方ID: String) -> Dictionary:
	var 目标配方: Dictionary = {}
	for 配方 in 灵食配方:
		if str(配方["id"]) == 配方ID:
			目标配方 = 配方
			break
	if 目标配方.is_empty():
		return {"成功": false, "原因": "未找到该灵食配方"}
	if 厨道等级 < int(目标配方["等级要求"]):
		return {"成功": false, "原因": "厨道品级不足，需%d品" % int(目标配方["等级要求"])}
	if 今日烹饪次数 >= 5:
		return {"成功": false, "原因": "今日精力已竭，明日再烹"}
	# 检查材料
	for 材料名 in 目标配方["材料"]:
		var 有材料: bool = false
		for it in 宗门库房:
			if it != null and it is Item and str(it.名称) == 材料名 and int(it.数量) > 0:
				有材料 = true
				break
		if not 有材料:
			return {"成功": false, "原因": "材料不足，缺少%s" % 材料名}
	# 消耗材料
	for 材料名 in 目标配方["材料"]:
		for it in 宗门库房:
			if it != null and it is Item and str(it.名称) == 材料名 and int(it.数量) > 0:
				it.数量 -= 1
				if it.数量 <= 0:
					宗门库房.erase(it)
				break
	今日烹饪次数 += 1
	# 增加厨道经验
	厨道经验 += 10
	if 厨道经验 >= 厨道等级 * 100:
		厨道经验 = 0
		厨道等级 += 1
		添加纪事("庶务", "厨道精进", "宗主厨道精进，升至%d级" % 厨道等级, 1)
	# 生成灵食物品
	var 新灵食 = Item.new()
	新灵食.名称 = str(目标配方["名称"])
	新灵食.类别 = "灵食"
	新灵食.数量 = 1
	新灵食.描述 = str(目标配方["描述"]) + "效果：" + str(目标配方["效果"])
	宗门库房.append(新灵食)
	添加纪事("庶务", "烹饪灵食", "宗主烹饪%s，入库房待用" % 目标配方["名称"], 1)
	return {"成功": true, "灵食": 目标配方["名称"], "效果": 目标配方["效果"]}

## 食用灵食（宗主或弟子食用，获得临时增益）
func 食用灵食(灵食名称: String, 弟子ID: int = -1) -> Dictionary:
	var 找到: bool = false
	var 目标灵食: Item = null
	for it in 宗门库房:
		if it != null and it is Item and str(it.名称) == 灵食名称 and str(it.类别) == "灵食":
			it.数量 -= 1
			if it.数量 <= 0:
				宗门库房.erase(it)
			找到 = true
			目标灵食 = it
			break
	if not 找到:
		return {"成功": false, "原因": "库房无此灵食"}
	# 应用效果（简化：根据名称匹配效果）
	var 效果文本: String = ""
	match 灵食名称:
		"灵米饭":
			设置气运buff(0.03, 0.0, 30)
			效果文本 = "修炼速度+3%（30日）"
		"百草羹":
			效果文本 = "突破成功率+5%（30日）"
		"妖兽烤肉":
			效果文本 = "道行+5%（30日）"
		"清心莲子羹":
			效果文本 = "道心+5，心魔-5"
		"龙虎金丹汤":
			设置气运buff(0.10, 0.0, 60)
			效果文本 = "修炼速度+10%（60日）"
		"凤髓龙肝":
			设置气运buff(0.08, 0.05, 90)
			效果文本 = "全宗修炼+8%（90日）"
		"蟠桃盛宴":
			设置气运buff(0.15, 0.10, 180)
			效果文本 = "全宗修炼+15%（180日）"
	添加纪事("庶务", "食用灵食", "%s食用%s，%s" % ["宗主" if 弟子ID < 0 else "弟子", 灵食名称, 效果文本], 1)
	return {"成功": true, "效果": 效果文本}

# ============ S53：灵茶系统（仙家茶道·灵茶冲泡+悟道加成）============
# 基于灵草/灵花制作灵茶，效果包括悟道加成、心境提升、灵感激发
# 修真世界观：茶道与悟道相通，品茶可明心见性、激发灵感
var 茶道等级: int = 1
var 茶道经验: int = 0
var 今日泡茶次数: int = 0

const 灵茶配方: Array = [
	{"id": "清心茶", "名称": "清心茶", "等级要求": 1, "材料": ["凡阶灵草"], "效果": "悟道点+5", "描述": "最基础的灵茶，可清心静神。"},
	{"id": "悟道茶", "名称": "悟道茶", "等级要求": 2, "材料": ["百年灵草"], "效果": "悟道点+15", "描述": "辅助悟道的灵茶，饮之思路清晰。"},
	{"id": "云雾茶", "名称": "云雾茶", "等级要求": 3, "材料": ["三百年灵草"], "效果": "道心+10", "描述": "生长于高山云雾之中，可明心见性。"},
	{"id": "忘忧茶", "名称": "忘忧茶", "等级要求": 4, "材料": ["三百年灵草", "百年灵草"], "效果": "心魔-10", "描述": "可驱除心魔、忘却烦忧的灵茶。"},
	{"id": "灵感茶", "名称": "灵感茶", "等级要求": 5, "材料": ["五百年灵草"], "效果": "顿悟概率+10%（持续90日）", "描述": "激发灵感的灵茶，饮之豁然开朗。"},
	{"id": "仙露茶", "名称": "仙露茶", "等级要求": 7, "材料": ["千年灵草"], "效果": "悟道点+50，道心+20", "描述": "以仙家仙露冲泡，可遇不可求。"},
	{"id": "道韵茶", "名称": "道韵茶", "等级要求": 9, "材料": ["万年灵草"], "效果": "全宗悟道+30（持续360日）", "描述": "蕴含大道韵律的绝世灵茶，饮之可近大道。"},
]

## 获取可冲泡灵茶列表
func 获取灵茶配方列表() -> Array:
	var 结果: Array = []
	for 配方 in 灵茶配方:
		if 茶道等级 >= int(配方["等级要求"]):
			结果.append(配方)
	return 结果

## 宗主冲泡灵茶
func 冲泡灵茶(配方ID: String) -> Dictionary:
	var 目标配方: Dictionary = {}
	for 配方 in 灵茶配方:
		if str(配方["id"]) == 配方ID:
			目标配方 = 配方
			break
	if 目标配方.is_empty():
		return {"成功": false, "原因": "未找到该灵茶配方"}
	if 茶道等级 < int(目标配方["等级要求"]):
		return {"成功": false, "原因": "茶道品级不足，需%d品" % int(目标配方["等级要求"])}
	if 今日泡茶次数 >= 5:
		return {"成功": false, "原因": "今日精力已竭，明日再泡"}
	# 检查材料
	for 材料名 in 目标配方["材料"]:
		var 有材料: bool = false
		for it in 宗门库房:
			if it != null and it is Item and str(it.名称) == 材料名 and int(it.数量) > 0:
				有材料 = true
				break
		if not 有材料:
			return {"成功": false, "原因": "材料不足，缺少%s" % 材料名}
	# 消耗材料
	for 材料名 in 目标配方["材料"]:
		for it in 宗门库房:
			if it != null and it is Item and str(it.名称) == 材料名 and int(it.数量) > 0:
				it.数量 -= 1
				if it.数量 <= 0:
					宗门库房.erase(it)
				break
	今日泡茶次数 += 1
	# 增加茶道经验
	茶道经验 += 10
	if 茶道经验 >= 茶道等级 * 100:
		茶道经验 = 0
		茶道等级 += 1
		添加纪事("庶务", "茶道精进", "宗主茶道精进，升至%d级" % 茶道等级, 1)
	# 生成灵茶物品
	var 新灵茶 = Item.new()
	新灵茶.名称 = str(目标配方["名称"])
	新灵茶.类别 = "灵茶"
	新灵茶.数量 = 1
	新灵茶.描述 = str(目标配方["描述"]) + "效果：" + str(目标配方["效果"])
	宗门库房.append(新灵茶)
	添加纪事("庶务", "冲泡灵茶", "宗主冲泡%s，入库房待用" % 目标配方["名称"], 1)
	return {"成功": true, "灵茶": 目标配方["名称"], "效果": 目标配方["效果"]}

## 品饮灵茶（获得悟道/道心加成）
func 品饮灵茶(灵茶名称: String) -> Dictionary:
	var 找到: bool = false
	for it in 宗门库房:
		if it != null and it is Item and str(it.名称) == 灵茶名称 and str(it.类别) == "灵茶":
			it.数量 -= 1
			if it.数量 <= 0:
				宗门库房.erase(it)
			找到 = true
			break
	if not 找到:
		return {"成功": false, "原因": "库房无此灵茶"}
	# 应用效果
	var 效果文本: String = ""
	match 灵茶名称:
		"清心茶":
			悟道点 += 5
			效果文本 = "悟道点+5"
		"悟道茶":
			悟道点 += 15
			效果文本 = "悟道点+15"
		"云雾茶":
			效果文本 = "道心+10"
		"忘忧茶":
			效果文本 = "心魔-10"
		"灵感茶":
			设置气运buff(0.0, 0.0, 90)
			效果文本 = "顿悟概率+10%（90日）"
		"仙露茶":
			悟道点 += 50
			效果文本 = "悟道点+50，道心+20"
		"道韵茶":
			设置气运buff(0.0, 0.10, 360)
			效果文本 = "全宗悟道+30（360日）"
	添加纪事("庶务", "品饮灵茶", "宗主品饮%s，%s" % [灵茶名称, 效果文本], 1)
	return {"成功": true, "效果": 效果文本}

# ============ S50：风水堪舆系统（殿阁布局引灵脉）============
var 堪舆等级: int = 1
var 堪舆经验: int = 0
var 今日堪舆次数: int = 0
var 风水布局: Dictionary = {}  # {殿阁ID: {位置, 风水评级, 灵眼加成}}
var 已发现灵眼: Array = []  # 已发现的灵眼位置

const 殿阁列表: Array = [
	{"id": "lingtian", "名称": "灵田", "基础位置": "东方"},
	{"id": "kuangmai", "名称": "矿脉", "基础位置": "西方"},
	{"id": "dantang", "名称": "丹堂", "基础位置": "南方"},
	{"id": "qitang", "名称": "器堂", "基础位置": "北方"},
	{"id": "futang", "名称": "符堂", "基础位置": "东南"},
	{"id": "cangjingge", "名称": "藏经阁", "基础位置": "中央"},
	{"id": "yushouge", "名称": "御兽阁", "基础位置": "东北"},
	{"id": "zhentang", "名称": "阵堂", "基础位置": "西南"},
	{"id": "xunliantang", "名称": "训练堂", "基础位置": "西北"},
	{"id": "gongxuntang", "名称": "功勋堂", "基础位置": "正南"},
]

const 风水评级: Array = ["大凶", "凶", "平", "吉", "大吉", "上上大吉"]

## 堪舆宗门地脉（发现灵眼）
func 堪舆地脉() -> Dictionary:
	if 今日堪舆次数 >= 3:
		return {"成功": false, "原因": "今日精力已竭，明日再堪"}
	今日堪舆次数 += 1
	# 发现灵眼概率（堪舆等级越高，概率越高）
	var 发现概率: float = 0.1 + float(堪舆等级) * 0.05
	var 结果: Dictionary = {"成功": true, "发现灵眼": false, "灵眼位置": ""}
	if randf() < 发现概率:
		var 位置列表: Array = ["东方", "西方", "南方", "北方", "中央", "东南", "东北", "西南", "西北"]
		var 灵眼位置: String = str(位置列表[randi() % 位置列表.size()])
		if not 已发现灵眼.has(灵眼位置):
			已发现灵眼.append(灵眼位置)
			结果["发现灵眼"] = true
			结果["灵眼位置"] = 灵眼位置
			添加纪事("大事件", "堪舆得灵眼", "宗主堪舆地脉，在%s发现灵眼一处" % 灵眼位置, 2)
	堪舆经验 += 10
	while 堪舆经验 >= 堪舆等级 * 100:
		堪舆经验 -= 堪舆等级 * 100
		堪舆等级 += 1
	return 结果

## 调整殿阁布局（改变风水评级）
func 调整殿阁布局(殿阁ID: String, 新位置: String) -> Dictionary:
	var 目标殿阁: Dictionary = {}
	for 殿阁 in 殿阁列表:
		if str(殿阁["id"]) == 殿阁ID:
			目标殿阁 = 殿阁
			break
	if 目标殿阁.is_empty():
		return {"成功": false, "原因": "未找到该殿阁"}
	# 计算风水评级（灵眼位置+50%概率大吉）
	var 评级索引: int = 2  # 默认平
	if 已发现灵眼.has(新位置):
		评级索引 = 4 if randf() < 0.5 else 3  # 大吉或吉
	else:
		评级索引 = randi_range(1, 3)  # 凶/平/吉
	var 评级: String = 风水评级[评级索引]
	风水布局[殿阁ID] = {"位置": 新位置, "评级": 评级, "灵眼": 已发现灵眼.has(新位置)}
	添加纪事("庶务", "调整布局", "将%s移至%s，风水评级：%s" % [目标殿阁["名称"], 新位置, 评级], 1)
	return {"成功": true, "殿阁": 目标殿阁["名称"], "位置": 新位置, "评级": 评级}

## 获取风水总加成（全宗修炼/产出加成）
func 获取风水总加成() -> float:
	var 加成: float = 0.0
	for 殿阁ID in 风水布局:
		var 布局: Dictionary = 风水布局[殿阁ID]
		var 评级: String = str(布局["评级"])
		match 评级:
			"大凶": 加成 -= 0.05
			"凶": 加成 -= 0.02
			"平": pass
			"吉": 加成 += 0.02
			"大吉": 加成 += 0.05
			"上上大吉": 加成 += 0.1
	return clamp(加成, -0.2, 0.3)

# ============ S51：音律抚琴系统（抚琴养性引灵潮）============
var 琴道等级: int = 1
var 琴道经验: int = 0
var 今日抚琴次数: int = 0
var 当前琴曲: String = ""
var 琴曲熟练度: Dictionary = {}  # {琴曲名: 熟练度}

const 琴曲列表: Array = [
	{"id": "清心谱", "名称": "清心谱", "等级要求": 1, "效果": "道心+5", "描述": "清心静神的入门琴曲，抚之可平心静气。"},
	{"id": "引灵曲", "名称": "引灵曲", "等级要求": 2, "效果": "修炼速度+3%（持续90日）", "描述": "引动天地灵气的琴曲，抚之灵气汇聚。"},
	{"id": "高山流水", "名称": "高山流水", "等级要求": 3, "效果": "弟子好感+5", "描述": "伯牙子期所遗名曲，抚之遇知音。"},
	{"id": "十面埋伏", "名称": "十面埋伏", "等级要求": 4, "效果": "战斗攻击+5%（持续一场）", "描述": "杀伐之音，抚之士气大振。"},
	{"id": "广陵散", "名称": "广陵散", "等级要求": 5, "效果": "战斗防御+5%（持续一场）", "描述": "聂政刺韩王所遗曲，慷慨激昂。"},
	{"id": "梅花三弄", "名称": "梅花三弄", "等级要求": 6, "效果": "道心+15", "描述": "咏梅之曲，抚之心神澄澈。"},
	{"id": "阳春白雪", "名称": "阳春白雪", "等级要求": 7, "效果": "全宗修炼+5%（持续90日）", "描述": "高雅之曲，抚之如沐春风。"},
	{"id": "天魔琴音", "名称": "天魔琴音", "等级要求": 9, "效果": "战斗全属性+10%（持续一场）", "描述": "魔道秘曲，抚之天地变色。"},
]

## 获取可弹奏琴曲列表
func 获取琴曲列表() -> Array:
	var 结果: Array = []
	for 琴曲 in 琴曲列表:
		if 琴道等级 >= int(琴曲["等级要求"]):
			结果.append(琴曲)
	return 结果

## 宗主抚琴
func 宗主抚琴(琴曲ID: String) -> Dictionary:
	var 目标琴曲: Dictionary = {}
	for 琴曲 in 琴曲列表:
		if str(琴曲["id"]) == 琴曲ID:
			目标琴曲 = 琴曲
			break
	if 目标琴曲.is_empty():
		return {"成功": false, "原因": "未找到该琴曲"}
	if 琴道等级 < int(目标琴曲["等级要求"]):
		return {"成功": false, "原因": "琴道品级不足，需%d品" % int(目标琴曲["等级要求"])}
	if 今日抚琴次数 >= 5:
		return {"成功": false, "原因": "今日精力已竭，明日再抚"}
	今日抚琴次数 += 1
	当前琴曲 = str(目标琴曲["名称"])
	# 增加熟练度
	var 熟练度: int = int(琴曲熟练度.get(琴曲ID, 0))
	琴曲熟练度[琴曲ID] = 熟练度 + 1
	# 增加经验
	琴道经验 += 10
	while 琴道经验 >= 琴道等级 * 100:
		琴道经验 -= 琴道等级 * 100
		琴道等级 += 1
	# 应用效果
	var 效果文本: String = str(目标琴曲["效果"])
	if "道心" in 效果文本:
		# 宗主道心+（简化处理）
		pass
	添加纪事("庶务", "抚琴养性", "宗主弹奏《%s》，%s" % [目标琴曲["名称"], 效果文本], 1)
	return {"成功": true, "琴曲": 目标琴曲["名称"], "效果": 效果文本, "熟练度": 琴曲熟练度[琴曲ID]}

## 琴道知音奇遇（低概率触发）
func _琴道知音奇遇_S51() -> void:
	# S51：琴道知音奇遇，走统一奇遇触发接口（宗主作为Disciple传入）
	if 宗主 == null:
		return
	var 事: Dictionary = _尝试触发奇遇(宗主, "琴道")
	if not 事.is_empty():
		# 奇遇已由_尝试触发奇遇统一处理（添加纪事、奖励等）
		pass


func 推演一月(月: int):

	天品突破播报 = ""
	# S1：季度内容门控——仅在跨越季界时执行经济类季度结算（原月度结算频率过高，改为季度90天）
	var _当前季界: int = int(累计游戏日 / 90)
	var _新季界: int = int((累计游戏日 + 月) / 90)
	var _需月度结算: bool = _新季界 > _当前季界
	# S2-3：香火/信徒月结产出（原 _结算香火_S1 空桩已实装）
	if _需月度结算:
		_结算香火_S1()
	# §6.16 月度家族结算（资源点产出+声望变化+事件随机触发+AI托管）
	if _需月度结算:
		月度家族结算()
	# P1-2 王朝奇观建造推进
	推进奇观建造_S34(1)
	# 异闻日志：因果征兆进宗门纪事（零依赖王朝，未开王朝同样记录）
	if _需月度结算:
		异闻分区已播.clear()  # 决策#3：月度刷新分境去重键
		_记录异闻_S45()
	# 宗门大比/论剑大会（每年举办一次）
	if _需月度结算:
		_宗门大比月度推进(月)
	# 散修来访（月度概率触发）
	if _需月度结算:
		_散修来访月度推进(月)
	# 宗门关系月度推进（好感度自然变化）
	if _需月度结算:
		_宗门关系月度推进(月)
	# 邪修来袭月度推进（概率触发）
	if _需月度结算:
		_邪修来袭月度推进(月)
	# 情劫月度推进（自然化解）
	if _需月度结算:
		_情劫月度推进(月)
	# 辈分/字辈谱系推进（每百年晋升一代）
	if _需月度结算:
		_辈分月度推进(月)
	# 称号系统：月度批量判定弟子称号
	if _需月度结算:
		批量判定称号()
	# 称号系统：月度判定宗主称号
	if _需月度结算:
		判定宗主称号()
	# 护道人系统：月度检查过期
	if _需月度结算:
		检查护道人过期()
	# 占卜冷却递减
	if 占卜冷却 > 0:
		占卜冷却 = max(0, 占卜冷却 - int(月 * 30))
	# 个人灵田月产出
	if _需月度结算:
		_灵田月度产出()
	# 储物袋祭炼推进
	if _需月度结算:
		祭炼储物袋月度推进(月)
	# 月度随机彩蛋（修真小说常见桥段）
	if _需月度结算:
		月度随机彩蛋(月)
	# S56-P1：坊市闲谈月度生成（每月50%概率1-2条）
	if _需月度结算 and randf() < 0.5:
		var 闲谈次数: int = randi_range(1, 2)
		for i in range(闲谈次数):
			消息系统.随机生成坊市闲谈()
	# S56-P1：NPC宗门聊天月度触发（每月3-8条）
	if _需月度结算:
		var 聊天次数: int = randi_range(3, 8)
		for i in range(聊天次数):
			消息系统._生成npc聊天()
	# S56-P2：天机秘闻月度生成（每月20%概率1条）
	if _需月度结算 and randf() < 0.2:
		消息系统.随机生成天机秘闻()
	# S56-P2：打探冷却递减
	if 消息系统.打探冷却 > 0:
		消息系统.打探冷却 = max(0, 消息系统.打探冷却 - int(月 * 30))
	# S56-P2：卧底情报传回
	if _需月度结算:
		消息系统.卧底传回情报()
	# S57：玩家交易系统每日推进（检查运输到达和被劫）- 集成到商队系统
	商队系统.玩家交易每日推进()
	# S59：闭关嘱托系统每日推进（离线代理）
	闭关嘱托.每日推进()
	# S48：弟子自动狩猎采药（无司职弟子根据性格自动入山）
	if _需月度结算:
		_弟子自动狩猎采药_S48()
	# S52：弟子休闲行为（有休闲天赋的弟子自主参与休闲活动）
	if _需月度结算:
		_弟子休闲行为_S52()
		# S55 P2：宗门休闲大赛（每3季度举办一次）
		_宗门休闲大赛_S55()
	# ★ 2026-09-14 新增：执事殿月课 —— 弟子身份升迁（外门→内门）
	#   「谁该执行」先行：升迁属执事殿司职弟子的常例职分，不该是宗主点的一键钮。
	#   （原弟子录「批量操作」钮已删；此处承接其正当部分，白送忠诚一项不予承接。）
	if _需月度结算:
		_月课_执事殿升迁()
	# ★ 2026-09-14 新增：丹堂月课 —— 施药（宗门库房 → 按需施予同门）
	#   同上「谁该执行」前置：丹药的分发服用是丹堂职分，不该由宗主在详情页逐人点「服用丹药」。
	if _需月度结算:
		_月课_丹堂施药()
	# ★ 2026-09-15 新增：洗池月课 —— 灵泉开年，弟子自费以个人功勋入池洗髓（自动流转，不设玩家按钮）
	#   同上「谁该执行」前置：入池洗髓是弟子自己的造化、耗自己的功勋 ⇒ 弟子自主层。
	#   宗主侧保留「耗仙玉强开灵泉」的手动入口（详情页·洗池 · 洗髓），二者并行不替代。
	if _需月度结算:
		_月课_洗池灵泉()
	# S54：全服玩家拍卖会推进（每游戏日推进，月度推演批量处理）
	全服拍卖系统.推进全服拍卖(月 * 30)
	# S49：灵酿月度结算（发酵完成）
	if _需月度结算:
		_灵酿月度结算_S49()
	# S51：琴道知音奇遇
	if _需月度结算:
		_琴道知音奇遇_S51()
	# 论道系统：悟性增益剩余日递减
	if _需月度结算:
		if 论道系统.悟性增益剩余日 > 0:
			论道系统.悟性增益剩余日 = max(0, 论道系统.悟性增益剩余日 - 30)
			if 论道系统.悟性增益剩余日 == 0:
				论道系统.悟性增益幅度 = 0.0
	# 祭祖大典：每年清明（游戏日第90天）自动举办
	if _需月度结算:
		var 当前年日: int = int(累计游戏日) % 360
		if 当前年日 >= 90 and 当前年日 < 120:  # 清明前后30天内触发一次
			# 用标记避免重复举办
			if not has_method("_祭祖大典已举办今年") or not _祭祖大典已举办今年():
				举办祭祖大典()
				_标记祭祖大典已举办()
	# 气运事件：根据气运等级概率触发机缘/灾厄事件
	if _需月度结算:
		_气运事件月度触发()
	# 实时传讯：弟子历练中重大事件触发传讯（每月10%概率）
	if _需月度结算 and randf() < 0.1:
		_历练传讯月度触发()
	# P2 NPC行为模拟：更新NPC状态和位置
	_更新NPC状态(月 * 30)
	# P2 NPC行为模拟第二阶段：推进任务进度
	_推进NPC任务进度(月 * 30)
	# P0 敌对生态系统：敌对势力月度行动（魔道骚扰/敌对NPC行动/阵营冲突）
	var 敌对行动: Array = 敌对势力月度行动()
	for act in 敌对行动:
		_加推演条目(str(act), "敌对势力", "中")
	# P1 敌对生态深度系统
	# P1-1 兽潮事件：月度触发检查
	var 兽潮结果: Dictionary = 兽潮月度触发检查()
	if bool(兽潮结果.get("触发", false)):
		_加推演条目("⚠ " + str(兽潮结果.get("兽潮", {}).get("名称", "")), "兽潮", "高")
	# P1-2 敌对NPC月度成长
	var npc成长: Array = 敌对NPC月度成长()
	for 成长 in npc成长:
		_加推演条目(str(成长), "敌对NPC", "低")
	# P1-4 阵营战争：月度检查/推进
	if 进行中阵营战争.is_empty():
		var 阵营战争结果: Dictionary = 阵营战争月度检查()
		if bool(阵营战争结果.get("触发", false)):
			_加推演条目("◆ 正魔大战爆发！", "阵营战争", "高")
	else:
		var 推进结果: Dictionary = 推进阵营战争月度()
		if bool(推进结果.get("战争结束", false)):
			_加推演条目(str(推进结果.get("战争结果", "")), "阵营战争", "高")
	# P2 敌对生态高阶系统
	# P2-1 势力兴衰：月度检查
	var 势力兴衰事件: Array = 势力兴衰月度检查()
	for 事件 in 势力兴衰事件:
		_加推演条目(str(事件), "势力兴衰", "中")
	# P2-4 稀有怪物刷新：月度检查/推进
	if 稀有怪物刷新.is_empty():
		var 稀有刷新结果: Dictionary = 稀有怪物月度刷新检查()
		if bool(稀有刷新结果.get("刷新", false)):
			_加推演条目("★ " + str(稀有刷新结果.get("怪物", {}).get("名称", "")) + "出现！", "稀有怪物", "高")
	else:
		稀有怪物月度推进()
	# P1 多种族修炼体系：种族月度推进（妖族化形/魔族心魔/鬼族阴气/龙族龙珠）
	_种族月度推进()
	# P0修复：体力系统已移除，改为每日次数自动重置（跨日时检查每日次数字典）
	# 每日次数在检查时自动重置，无需月度恢复
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
	var 气运修炼pct: float = 0.0  # P0-2：分离气运加成，纳入限时增益全局上限
	if 累计游戏日< 气运到期日:
		气运修炼pct = 气运修炼加成
	var 负责人修炼pct: float = 汇总负责人全局buff().get("修炼", 0.0)
	var 藏经阁pct: float = max(0.0, _藏经阁修炼乘区() - 1.0)
	var 大阵pct: float = max(0.0, _宗门大阵修炼乘区() - 1.0)
	var 血脉共鸣pct: float = max(0.0, 血脉共鸣修炼乘区() - 1.0)  # §6.16 血脉共鸣修炼加成
	# §6.16 血脉加成：全宗血脉觉醒弟子的平均修炼加成
	var 血脉pct: float = 0.0
	var 血脉觉醒数: int = 0
	var 血脉总加成: float = 0.0
	var 家族秘宝pct: float = 0.0
	var 血脉功法pct: float = 0.0
	for d in 弟子列表:
		if d != null and d is Disciple and d.状态 == "在宗":
			if d.血脉觉醒:
				var 血脉加: Dictionary = 计算血脉加成(d)
				血脉总加成 += float(血脉加.get("修炼加成", 0.0))
				血脉觉醒数 += 1
			# 家族秘宝修炼加成
			if d.家族秘宝 != "":
				var 秘宝加: Dictionary = 计算家族秘宝加成(d)
				家族秘宝pct += float(秘宝加.get("修炼加成", 0.0))
			# 血脉功法修炼加成
			if not d.血脉功法列表.is_empty():
				var 血脉功法加: Dictionary = 计算血脉功法加成(d)
				血脉功法pct += float(血脉功法加.get("修炼加成", 0.0))
	if 血脉觉醒数 > 0:
		血脉pct = min(血脉总加成 / float(血脉觉醒数), 0.015)  # 全宗血脉加成上限1.5%
	家族秘宝pct = min(家族秘宝pct, 0.01)  # 全宗家族秘宝加成上限1%
	血脉功法pct = min(血脉功法pct, 0.015)  # 全宗血脉功法加成上限1.5%
	# 家族阵法修炼加成
	var 家族阵法pct: float = 0.0
	for d in 弟子列表:
		if d != null and d is Disciple and d.状态 == "在宗" and d.家族ID != "":
			var 阵法加: Dictionary = 计算家族阵法加成(d)
			家族阵法pct += float(阵法加.get("修炼加成", 0.0))
	家族阵法pct = min(家族阵法pct, 0.01)  # 全宗家族阵法加成上限1%
	# 家族培养加成（学塾+资源倾斜）
	var 家族培养pct: float = 0.0
	for d in 弟子列表:
		if d != null and d is Disciple and d.状态 == "在宗" and d.家族ID != "":
			var 培养加: Dictionary = 计算家族培养加成(d)
			家族培养pct += float(培养加.get("修炼加成", 0.0))
	家族培养pct = min(家族培养pct, 0.01)  # 全宗家族培养加成上限1%
	# 家族社交加成（联盟+联姻）
	var 家族社交pct: float = 0.0
	for d in 弟子列表:
		if d != null and d is Disciple and d.状态 == "在宗" and d.家族ID != "":
			var 社交加: Dictionary = 计算家族社交加成(d)
			家族社交pct += float(社交加.get("修炼加成", 0.0))
	家族社交pct = min(家族社交pct, 0.01)  # 全宗家族社交加成上限1%
		# P0-2：限时增益单独计算并应用8%全局上限（气运+彩蛋+藏书阁临时）
	var 限时修炼pct: float = 气运修炼pct + 彩蛋修炼加成() + 获取藏书阁加成()
	限时修炼pct = 应用限时增益上限(限时修炼pct)
	# 基础增益（不受限时上限约束）+ 受限的限时增益
	var 宗门加成pct: float = clamp(灵脉加成pct + 负责人修炼pct + 藏经阁pct + 大阵pct + 血脉共鸣pct + 血脉pct + 家族秘宝pct + 血脉功法pct + 家族阵法pct + 家族培养pct + 家族社交pct + 限时修炼pct, 0.0, 1.0)
	var 修炼乘区: float = 1.0 + 宗门加成pct
	# 1. 弟子修炼 / 升层 / 突破 / 月度事件：0层体系双轨播报）
	if _需月度结算:
		_执行方针()
		抽取月度事件()
	var 待坐化: Array[Disciple] = []
	var 新生儿: Array = []   # §12.3 本月新孕育子嗣（循环内收集，循环外 append 避免遍历中改数组）
	# S2：宗主独立修炼推进（不进弟子列表，独立推进）
	if 宗主 != null and 宗主.状态 == "在宗":
		var 闭关加成: float = 2.0 if 宗主闭关中 else 1.0  # S3：闭关期间修炼速度×2
		# S58-P2：区域修炼加成
		var 宗主区域修炼加成: float = 0.0
		if 世界地图系统 != null:
			宗主区域修炼加成 = float(世界地图系统.获取当前区域特性().get("修炼加成", 0.0))
		宗主.推进修炼(float(月) * 闭关加成, 修炼乘区 * (1.0 + 宗主.双修加成) * _修炼风格乘区() * (1.0 + 宗主区域修炼加成), Callable(self, "构建渡劫准备"))
		# 宗主精力每日恢复（闭关期间恢复更快）
		var 精力恢复: int = 20 if 宗主闭关中 else 10
		宗主精力 = min(宗主精力上限, 宗主精力 + 精力恢复)
		if 宗主闭关中:
			宗主闭关累计天 += 月
		# E：宗主寿元检测
		_检测宗主寿元(月)
	for d in 弟子列表:
		var 旧境界: String = d.境界
		var 旧层数: int = d.层数
		# P0修复：突破护法加成正确应用到突破率（原错位乘进修炼速度）
		if SectManager != null and d.境界 in ["筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫"]:
			var 护法加成 = SectManager.获取护法成功率加成(int(d.弟子ID))
			if 护法加成 > 0:
				d.临时突破护法加成 = 护法加成
				SectManager.标记护法已处理(int(d.弟子ID))
		# P3.2：弟子自主嗑药（拟人行为）——闭关/在宗时按需求自动服用宗门丹药库丹药
		_弟子自动服用丹药(d)
		# S34-P0：弟子私库物品自动使用（信息不对称核心乐趣）——先穿装备再服丹药，宗主不可见具体过程
		d.私库自动使用()
		# S34-P1：弟子月例发放（按境界发放灵石入私库，职位加成+50%）
		if _需月度结算:
			_发放弟子月例_S34(d)
		# P2性能优化：低境界弟子（练气/筑基）跳过复杂AI行为，只保留基础修炼
		var _弟子境界序: int = Disciple.境界索引(str(d.境界))
		if _弟子境界序 > Disciple.境界索引("筑基"):
			# S34-P1：弟子AI竞拍决策（自主决定是否参与拍卖行竞拍）
			_弟子AI竞拍决策_S34(d)
			# S34-P1：弟子委托拍卖（出售不需要的物品，所得入私库）
			_弟子委托拍卖_S34(d)
		# §4.0：目标驱动——按状态+性格检查人生目标是否突变（中途改变目标）
		_检查目标突变(d)
		# §4.0 目标驱动：叛离判定（目标叛离倾向 × 心境/心魔/道心调制）
		_检查叛离(d)
		# P0：低境界弟子道心不稳离去判定（自然消耗机制）
		_道心不稳离去判定(d)
		# P2性能优化：低境界弟子（练气）跳过任务/悬赏/功勋复杂AI
		if _弟子境界序 > Disciple.境界索引("练气"):
			# S27 宗门任务榜：弟子自主接取 / 主动请命（须在 _弟子月度事件 之前，该函数有 50% 早退）
			_弟子任务榜月度(d)
			# S28 宗门悬赏榜：弟子自主接取悬赏
			_弟子悬赏月度(d)
			# S28 功勋堂：弟子自主消费个人功勋（同上，须在 50% 早退之前）
			_弟子兑换月度(d)
		# §12 人生线：双修/孕育/飞升结算（返回本月新生子嗣，循环外统一入册）
		新生儿.append_array(_结算弟子人生线(d))
		# §4.0 目标驱动：修炼投入（守 §4.1 通用增益 ≤25% 红线，见 Goal.修炼增益上限）
		var 目标修炼: float = Goal.修炼投入(Goal.弟子目标(d))
		var 弟子行为加成: float = 获取弟子行为修炼加成(d)  # P2 弟子AI行为权重：公共区偏好→修炼加成（上限3%）
		# S58-P2：区域修炼加成（北域苦寒淬炼+20%、南疆灵气充沛+15%、中州+10%、东西域+5%）
		var 区域修炼加成: float = 0.0
		if 世界地图系统 != null:
			区域修炼加成 = float(世界地图系统.获取当前区域特性().get("修炼加成", 0.0))
		# 护道人系统：护道人修炼加成
		var 护道人修炼加成: float = 获取护道人修炼加成(d.弟子ID)
		# P0联动：宗主传功状态递减
		var 传功乘区: float = 1.0
		if d.传功剩余日 > 0:
			传功乘区 = 1.0 + d.传功加成
			d.传功剩余日 -= 1
			if d.传功剩余日 <= 0:
				d.传功加成 = 0.0
				d.传功剩余日 = 0
		# P0优化：灵气消耗机制（弟子修炼消耗灵气，形成资源循环）
		var 灵气消耗表: Dictionary = {"练气":1, "筑基":3, "金丹":10, "元婴":30, "化神":100, "炼虚":200, "合体":400, "大乘":800, "渡劫":1500, "仙阶":2000, "道阶":3000}
		var 月灵气消耗: int = int(灵气消耗表.get(d.境界, 1))
		var 灵气不足惩罚: float = 1.0
		if 灵气 >= 月灵气消耗:
			灵气 -= 月灵气消耗
		else:
			灵气不足惩罚 = 0.5  # 灵气不足时修炼效率降低50%
			if randf() < 0.1:  # 10%概率提示，避免刷屏
				_加推演条目("【灵气】宗门灵气不足，%s修炼受阻，效率减半" % d.姓名, ET_SECT, PRIO_NORMAL, {})
		# 弟子AI行为决策：大圆满弟子主动决定是否突破（性格驱动+风险评估）
		if d.层数 >= 10 and d.瓶颈打磨值 >= 1.0 and d.突破冷却剩余 <= 0:
			if d.AI决定是否突破():
				# 决定突破：主动准备（服用丹药、请求护法）
				d.AI主动准备突破()
			else:
				# 决定不突破：主动寻机缘（历练/闭关/论道）
				var 行为: String = d.AI主动寻机缘()
				if 行为 == "历练" and randf() < 0.3:
					# 30%概率外出历练寻机缘（简化处理，实际历练由历练系统处理）
					_加推演条目("【外出寻道】%s自觉突破时机未到，外出游历寻机缘，以求顿悟。" % d.姓名, ET_SECT, PRIO_NORMAL, {})
		# C3②：弟子自主申请洞府（大圆满且未得道阶洞府时低概率触发，需宗主批复）
		if d.层数 >= 10 and int(d.洞府等级) < 7:
			d.AI申请洞府()
		d.推进修炼(float(月), 修炼乘区 * (1.0 + d.双修加成) * _修炼风格乘区() * 目标修炼 * 万仙誓修炼乘区() * (1.0 + 弟子行为加成) * (1.0 + 祖师堂气运加成()) * (1.0 + 区域修炼加成) * (1.0 + 护道人修炼加成) * 传功乘区 * (1.0 + 获取先贤堂修炼加成()) * (1.0 + 获取活动产出加成().get("修炼加成", 0.0)) * (1.0 + 好友系统.获取道友拜访修炼加成()) * 灵气不足惩罚, Callable(self, "构建渡劫准备"))   # P0修复：原参数错位（天数位误传乘区串、乘区位写死1.0）→ 修炼恒推进约1日/次。月=游戏日，直接传月。飞升系统：祖师堂气运加成（每个飞升弟子+1%，上限30%）。护道人系统：护道人修炼加成。P0优化：灵气不足惩罚。P0联动：宗主传功乘区。P1联动：先贤堂修炼加成。P2联动：活动修炼加成。P3联动：道友拜访修炼加成
		# 护道人系统：日常功德积累
		护道人日常功德(d)
		# 技能系统：条件化领悟 + AI自动兑换功法
		_弟子自动领悟技能(d)
		_弟子AI自动兑换功法(d)
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
				天品突破播报 += "【%s】突破至%s\n" % [d.姓名, d.境界]
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
			# 护道人系统：危机救援（寿元将尽时护道人出手救援）
			if 护道人危机救援(d):
				_加推演条目("【%s】寿元将尽之际，护道人%s倾力相救，延寿一甲子！" % [d.姓名, 护道人列表.get(d.弟子ID, {}).get("护道人姓名", "")], ET_INFO, PRIO_HIGH, {"弟子": d.姓名})
				continue  # 救援成功，不加入待坐化
			if not _转世判定(d):
				待坐化.append(d)
		# 突破失败陨落处理（渡劫期及以上突破失败死亡）
		if str(d.状态) == "陨落":
			# 天才弟子陨落：留下传承（功法/资源）
			if str(d.资质) in ["tiancai", "yaonie", "kuangshi"] or int(d.弟子ID) in 天骄弟子ID:
				_天才陨落传承(d)
			待坐化.append(d)  # 复用坐化处理逻辑（归还物品+先贤堂入册）
	# S34-P1：检查关注拍品即将结束提醒
	_检查关注提醒_S34()
	# S34-P2：检查并触发特殊拍卖事件
	_检查特殊事件_S34()
	# S34-P2：推进特殊事件（减少剩余天数）
	_推进特殊事件_S34()
	# §12.5 转世新生儿已就地重生（_转世判定 内部改写 d 并留宗），本月新孕育子嗣统一入册
	for nd in 新生儿:
		弟子列表.append(nd)
	_新手_评估后续()   # 状态型 newbie（弟子层数达标）月内预判
	# 2. 资源殿阁产出
	处理坐化(待坐化)   # P0 终局：寿元耗尽弟子离场（灵：装备归还宗门、纪事入册）
	# P1优化：弟子主动申请洞府（高境界+高贡献弟子自动申请，宗门有空闲洞府则分配）
	_弟子主动申请洞府()
	# 飞升系统：检查飞升前兆队列
	_检查飞升前兆()
	# 飞升系统：祖师堂定期回馈
	_祖师堂定期回馈()
	# 散仙/鬼仙系统：月度结算（寿元消耗+劫数判定）
	_散仙月度结算()
	# 身外化身系统：月度结算（游历推进+奇遇触发+资源反哺）
	_化身月度结算()
	# 红尘历练系统：月度结算（凡人年龄增长+事件+娶妻生子）
	_红尘历练月度结算()
	# P2：客卿月度结算（月俸+人脉+任期）
	_客卿月度结算()
	_资源殿阁产出()
	# P1优化：外门弟子杂役产出
	var 外门产出: Dictionary = 外门弟子杂役产出()
	if 外门产出.get("灵石", 0) > 0:
		添加纪事("庶务", "外门杂役", "外门弟子杂役产出：灵石+%d，灵草+%d，矿石+%d" % [外门产出.get("灵石", 0), 外门产出.get("灵草", 0), 外门产出.get("矿石", 0)], 0)
	# P2优化：排行榜每周结算（每7游戏日结算一次）
	var 排行结算: Dictionary = 玄榜系统.每周结算(累计游戏日)
	if 排行结算.get("已结算", false) and 排行结算.get("排名", 0) > 0:
		var 排名: int = int(排行结算.get("排名", 0))
		var 灵石奖: int = int(排行结算.get("灵石", 0))
		var 声望奖: int = int(排行结算.get("声望", 0))
		var 称号奖: String = str(排行结算.get("称号", ""))
		if 称号奖 != "":
			添加纪事("玄榜", "周榜结算", "玄榜周榜结算：贵宗位列第%d名，获得「%s」称号，灵石+%d，声望+%d" % [排名, 称号奖, 灵石奖, 声望奖], 0)
		else:
			添加纪事("玄榜", "周榜结算", "玄榜周榜结算：贵宗位列第%d名，灵石+%d，声望+%d" % [排名, 灵石奖, 声望奖], 0)
	# P2-12：殿阁产出感知（缓解「产出感知弱」；把本周期殿阁真实产出写入纪事，玩家回看推演日志可见 +N）
	if _本月灵田产出 > 0 or _本月矿脉产出 > 0 or _本月丹堂产出 > 0 or _本月器殿产出 > 0:
		添加纪事("庶务", "殿阁产出", "灵田+%d 灵草｜矿脉+%d 矿石｜丹堂+%d｜器殿+%d" % [_本月灵田产出, _本月矿脉产出, _本月丹堂产出, _本月器殿产出], 0)
	# 藏经阁月度悟道点产出
	var 藏经阁等级: int = 1
	if 司职列表.has("cangjing"):
		藏经阁等级= int(司职列表["cangjing"].get("等级", 1))
	var 月产出 = GongFaSystem.计算月产出(藏经阁等级)
	# 宗主称号全宗悟道加成
	var 宗主悟道加成: float = 获取宗主称号加成("全宗悟道")
	if 宗主悟道加成 > 0:
		月产出 = int(月产出 * (1.0 + 宗主悟道加成))
	悟道点 += 月产出
	# 灵气月度产出（基于宗门等：灵脉：
	var 灵气月产值= 30 + 灵脉等级 * 20  # S1：灵气产出基于灵脉等级（原基于门派等级）
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
	var 招徒周期: int = _校准("招徒周期", 2)  # P1优化：从3月缩短到2月，弥补高突破死亡率
	var 招徒起月: int = int(累计游戏日/ 30)
	var 招徒止月: int = int((累计游戏日 + 月) / 30)
	for 招徒月 in range(招徒起月, 招徒止月):
		if 招徒月% 招徒周期 != 0:
			continue
		var 招徒概率: float = _校准("招徒基础概率", 0.8) + (门派等级 - 1) * _校准("招徒等级缩放", 0.02)  # P1优化：基础概率从0.75提高到0.8
		招徒概率 = clamp(招徒概率, 0.0, _校准("招徒概率上限", 0.95))
		if randf() < 招徒概率 and not 是否超编():
			var n: int = 1 + (1 if randf() < 0.4 else 0) + (1 if randf() < 0.1 else 0)  # P1优化：1-3人（40%概率2人，10%概率3人）
			for i in n:
				if 是否超编():
					break
				var nd := Disciple.new()
				nd.司职 = "yuying"   # 育英堂候补
				_分配弟子故乡郡(nd)   # P1-4 弟子-凡间情感绑定：随机分配故乡郡
				弟子列表.append(nd)
		# P1优化：超编惩罚（修真世界观：洞府不足、灵气短缺、资源难以为继）
		if 是否超编():
			var 超编数: int = 在宗弟子数() - 宗门编制上限()
			# 灵气短缺：每超编1人，灵气额外消耗
			灵气 = max(0, 灵气 - 超编数 * 5)
			# 弟子忠诚下降：超编导致资源紧张，弟子心生不满
			for d in 弟子列表:
				if d != null and randf() < 0.1:
					d.忠诚 = max(0, int(d.忠诚) - 1)
			# 推演条目通知（每季度一次，避免刷屏）
			if 招徒起月 % 3 == 0:
				_加推演条目("【宗门预警】宗门灵脉承载力已达极限，洞府不足、灵气短缺、资源难以为继。当前超编%d人，需提升宗门品级、升级灵脉或扩建大阵以增承载力。" % 超编数, ET_SECT, PRIO_NORMAL, {})
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
	if _需月度结算:
		_结算俸禄_S1()            # 俸禄/福利按月发放，扣公库
		_结算灵米消耗_S1()        # S1：灵米消耗，弟子日常吃食
		_洞府拥挤惩罚_S1()        # S1：洞府拥挤惩罚
		_结算运维成本_S1()        # D1 宗门运维成本（刚性耗），接：global_cost_rate 阀门
		_结算宗门领地_S1()       # S31 宣战/领地战：占领领地按月产出（灵石/声望/灵材）
		_结算王朝_S34()                    # S34 凡人王朝：国祚涨跌/阶段推进/改朝换代
		_刷新宣战周期_S32()      # S32 现实周/赛季跨越检测（周结算+守成+赛季结算）
		_结算负面事件_S1()        # D3 负面影响经济侧（S1-P0 批次三）：negative_event.csv + 经济阀门.csv neg_*
		_可能触发特殊登门_S1()    # 声望阈值→特殊弟子主动投奔
		_确保字派_S1()            # S1 ：-B：旧档首次进入自动生成字派序列并持久：
		_检查正邪解锁_S1()         # S1 ：-C：正邪路线解锁检测（空桩，当前仅读门派等：七载大考标记）
		_结算大阵耐久_S1()    # S1 ：-A：宗门大阵耐久月度结算（当前空桩，[PLACEHOLDER]：
	累计游戏日 += 月  # S1：修复离线1/30，按实际推进日数增加
	# 商队系统：每日更新商队状态，结算返回的商：
	更新商队状态()
	# S27 宗门任务榜：到期任务结算（与商队共用月度推演挂点）
	_结算到期宗门任务()
	# S28 宗门悬赏榜：到期悬赏结算
	_结算到期悬赏()
	# 历练系统：检查并结算到期历练，每日重置日常，：日重置秘：
	if ExpeditionSystem != null:
		var 结算列表 = ExpeditionSystem.检查并结算历练()
		for 结果 in 结算列表:
			if str(结果.get("类型", "")) == "investigate":
				continue   # 调查任务结算已在 ExpeditionSystem 内记纪事，不计入日常历练埋点
			if 结果.get("成功", false):
				# S1-2 自动产出型埋点：历练由系统自动结算，玩家只做「派遣」配置
				var 关卡类型: String = str(结果.get("类型", ""))
				if 关卡类型 == "secret":
					记任务进度("clear_stage", "完整")     # 秘境通关·完整（周常 weekly_005 · condition_param=完整）
					记任务进度("clear_stage")            # 秘境通关（日常 daily_011 · 无参键）
				else:
					记任务进度("expedition")              # 野外/境界历练（日常 daily_003）
				_加推演条目("【历练：%s 完成，评：%s】" % [结果.get("关卡名称",""), 结果.get("评级","")], ET_LOOT, PRIO_NORMAL)
			else:
				_加推演条目("【历练：%s 失败】" % 结果.get("关卡名称",""), ET_INFO, PRIO_TRIVIAL)
		# P0-1历练优化：每日触发进行中历练的奇遇事件（玩家可在UI中做选择）
		ExpeditionSystem.每日触发奇遇()
		ExpeditionSystem.每日重置()
		if 累计游戏日% 7 == 0:
			ExpeditionSystem.每周重置()
	_宗门集市_日推进(1)     # WAVE-C #7：宗门集市窗口进：退出刷新（仅刷新规则，零经济）
	_推进差事系统()        # S0：每日刷日常 / ：日刷周常 / 月度随机概率事件
	# P1：年结周期评分（累计游戏日= 365 日）；支持单次大跨度推演结算多年
	while (累计游戏日- 上次结算年>= 365):
		上次结算年+= 365
		_年结评分()
# P1：年结评分（：推演一月：365 日边界触发）
	# ===== 五大系统全面优化：月度自动结算 =====
	# 拍卖行月度结算
	if _需月度结算:
		var _拍卖行结算: Dictionary = 结算拍卖行()
		if _拍卖行结算.get("结算记录", []).size() > 0:
			添加纪事("拍卖行", "月度结算", "拍卖行月度结算完成，进行中%d场" % int(_拍卖行结算.get("进行中数量", 0)), 1)

	# 正魔大战赛季进度（每7天一个赛季）
	if 累计游戏日 % 7 == 0:
		var _正魔状态: Dictionary = 获取正魔大战状态()
		添加纪事("正魔大战", "赛季结算", "第%d赛季结算：正道%d战功 vs 魔道%d战功" % [int(_正魔状态.get("赛季", 1)), int(_正魔状态.get("正道战功", 0)), int(_正魔状态.get("魔道战功", 0))], 2)

	# 王朝事件随机触发（10%概率）
	if randf() < 0.1:
		var _王朝事件列表: Array = ["科举", "灾荒", "叛乱", "和亲", "商路", "变法", "外敌", "祥瑞"]
		var _随机事件: String = _王朝事件列表[randi() % _王朝事件列表.size()]
		触发王朝事件(_随机事件)

func _年结评分():

	var 当前总战力: int = 0
	for d in 弟子列表:
		当前总战力+= d.实时战力()
	# 计算新维度数据
	var 宗主战力增量: int = 0
	var 宗主境界提升: int = 0
	if 宗主 != null:
		宗主战力增量 = int(宗主.实时战力()) - 年始宗主战力
		if 年始宗主境界 != "" and str(宗主.境界) != 年始宗主境界:
			宗主境界提升 = 1
	# 技艺殿阁等级（丹殿+器殿+符堂等级之和）
	var 技艺殿阁等级: int = 0
	if 司职列表.has("dantang"):
		技艺殿阁等级 += int(司职列表["dantang"].get("等级", 1))
	if 司职列表.has("qitang"):
		技艺殿阁等级 += int(司职列表["qitang"].get("等级", 1))
	if 司职列表.has("futang"):
		技艺殿阁等级 += int(司职列表["futang"].get("等级", 1))
	# 高阶产出（宝品及以上丹药/法宝数量，简化为宗门库房中宝品及以上物品数）
	var 高阶产出: int = 0
	for item in 宗门库房:
		if item != null and str(item.get("品阶", "")) in ["宝品", "王品", "圣品", "仙品"]:
			高阶产出 += 1
	# 洞府数量（有洞府的弟子数量）
	var 洞府数量: int = 0
	var 灵田等级总和: int = 0
	for d in 弟子列表:
		if d != null:
			if "洞府等级" in d and int(d.洞府等级) > 0:
				洞府数量 += 1
			if "个人灵田等级" in d:
				灵田等级总和 += int(d.个人灵田等级)
	var 局: Dictionary = 周期评分.结算(门派等级, {
		"资源产能": 预估月产出(),
		"灵石增量": 灵石 - 年始灵石,
		"总战力增量": 当前总战力 - 年始总战力,
		"宗主战力增量": 宗主战力增量,
		"宗主境界提升": 宗主境界提升,
		"技艺殿阁等级": 技艺殿阁等级,
		"高阶产出": 高阶产出,
		"洞府数量": 洞府数量,
		"灵田等级": 灵田等级总和,
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
		# ★ 2026-09-16 修：原为 `"岁末考评裁定 %sbs" % [评级级, 岁末评语]` —— 格式串仅 1 个占位符、
		#   实参却给了 2 个 ⇒ 抛「String formatting error: not all arguments converted」，
		#   年结评分整段中断（此前被 period_settlement 的 float 崩溃挡在前面，故从未暴露）。
		"文案": "岁末考评裁定 %s。%s" % [评级级, 岁末评语], "category": "日常庶务"})
	年始灵石 = 灵石
	年始总战力= 当前总战力
	if 宗主 != null:
		年始宗主战力 = int(宗主.实时战力())
		年始宗主境界 = str(宗主.境界)
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
		# ★ 2026-09-16 修：格式串尾部悬空 `： %s`（3 占位符只给 2 参）⇒ 本行即抛
		#   「String formatting error: not all arguments converted」，周期赏赐整段中断。
		_加推演条目("【宗门】周期评：%s，论功行赏，灵石+%d" % [评级, 额], ET_SECT, PRIO_NORMAL, {})
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
	# 修真味奖励：根据评级赐予丹药、功法等（B级及以上才有）
	_评级修真赏赐(评级)
	if 等级平移 and not 弟子列表.is_empty():
		var 物: Item = _造低阶物品("fabao", "上品")
		七载待发掉落.append({"类型": 物.类别, "品阶": 物.品阶, "名称": 物.名称})
		_加推演条目("【宗门】评：%s，上品法宝：%s】" % [评级, 物.名称], ET_LOOT, PRIO_HIGH, {})
	return {"年度发": 年度发, "入池": 入池, "平移法宝": 等级平移}

## 评级修真赏赐（B级及以上赐予丹药、功法等修真味奖励）
func _评级修真赏赐(评级: String) -> void:
	var 评级序: Array = ["D", "C", "B", "A", "A+", "S", "SS", "SSS"]
	if not 评级序.has(评级):
		return
	var 评级索引: int = 评级序.find(评级)
	# B级及以上才赐丹药
	if 评级索引 >= 2:
		var 丹药数: int = 评级索引 - 1  # B=1, A=2, A+=3, S=4...
		var 丹药品阶: String = "凡品"
		if 评级索引 >= 4:  # A+及以上
			丹药品阶 = "灵品"
		if 评级索引 >= 6:  # SS及以上
			丹药品阶 = "宝品"
		for i in range(丹药数):
			var 丹: Item = _造低阶物品("dan", 丹药品阶)
			宗门库房.append(丹)
		_加推演条目("【宗门】岁末考评%s，赐%s丹药%d枚，入宗门库房。" % [获取评级修真名(评级), 丹药品阶, 丹药数], ET_LOOT, PRIO_NORMAL, {})
	# A级及以上赐功法残卷
	if 评级索引 >= 3:
		var 功法数: int = 1
		if 评级索引 >= 5:  # S及以上
			功法数 = 2
		for i in range(功法数):
			var 功: Item = _造低阶物品("gongfa", "凡阶")
			宗门库房.append(功)
		_加推演条目("【宗门】岁末考评%s，赐功法残卷%d卷，入藏经阁。" % [获取评级修真名(评级), 功法数], ET_LOOT, PRIO_HIGH, {})
	# S级及以上赐灵脉淬炼（直接赐予灵气）
	if 评级索引 >= 5:
		var 灵气赐: int = 100 * (评级索引 - 4)  # S=100, SS=200, SSS=300
		灵气 += 灵气赐
		_加推演条目("【宗门】岁末考评%s，灵脉得天地灵气滋养，灵气+%d。" % [获取评级修真名(评级), 灵气赐], ET_SECT, PRIO_HIGH, {})

## 计算当前年度预估评级（用于UI实时显示）
func 获取当前预估评级() -> Dictionary:
	var 当前总战力: int = 0
	for d in 弟子列表:
		当前总战力 += d.实时战力()
	var 已过天数: int = max(1, 累计游戏日 - 上次结算年)
	var 年度进度: float = float(已过天数) / 365.0
	# 按年度进度折算当前增量
	var 预估灵石增量: int = int((灵石 - 年始灵石) / 年度进度)
	var 预估战力增量: int = int((当前总战力 - 年始总战力) / 年度进度)
	# 新维度数据
	var 宗主战力增量: int = 0
	var 宗主境界提升: int = 0
	if 宗主 != null:
		宗主战力增量 = int((int(宗主.实时战力()) - 年始宗主战力) / 年度进度)
		if 年始宗主境界 != "" and str(宗主.境界) != 年始宗主境界:
			宗主境界提升 = 1
	var 技艺殿阁等级: int = 0
	if 司职列表.has("dantang"):
		技艺殿阁等级 += int(司职列表["dantang"].get("等级", 1))
	if 司职列表.has("qitang"):
		技艺殿阁等级 += int(司职列表["qitang"].get("等级", 1))
	if 司职列表.has("futang"):
		技艺殿阁等级 += int(司职列表["futang"].get("等级", 1))
	var 高阶产出: int = 0
	for item in 宗门库房:
		if item != null and str(item.get("品阶", "")) in ["宝品", "王品", "圣品", "仙品"]:
			高阶产出 += 1
	var 洞府数量: int = 0
	var 灵田等级总和: int = 0
	for d in 弟子列表:
		if d != null:
			if "洞府等级" in d and int(d.洞府等级) > 0:
				洞府数量 += 1
			if "个人灵田等级" in d:
				灵田等级总和 += int(d.个人灵田等级)
	# 综合底蕴维度数据（毒道/傀儡/休闲/飞升/世界探索）
	var 毒道境界总和: int = 0
	var 傀儡总数: int = 0
	var 休闲等级总和: int = 0
	for d in 弟子列表:
		if d != null:
			if "毒道境界" in d and d.毒道境界 != "":
				毒道境界总和 += 1
			if "傀儡" in d and d.傀儡 != null:
				傀儡总数 += 1
			if "休闲经验" in d:
				休闲等级总和 += int(d.休闲经验.size())
	var 飞升弟子数: int = 0
	# 注：GDScript 在编译期就校验 self 上是否存在该方法，has_method 保护挡不住静态检查，
	#     故改用动态 call 调用，避免「Function not found in base self」阻断整个文件解析。
	if has_method("获取飞升弟子数"):
		飞升弟子数 = int(call("获取飞升弟子数"))
	var 世界探索度: int = 0
	if 世界地图系统 != null and 世界地图系统.has_method("获取探索进度"):
		世界探索度 = int(世界地图系统.获取探索进度())
	var 局: Dictionary = 周期评分.结算(门派等级, {
		"资源产能": 预估月产出(),
		"灵石增量": 预估灵石增量,
		"总战力增量": 预估战力增量,
		"宗主战力增量": 宗主战力增量,
		"宗主境界提升": 宗主境界提升,
		"技艺殿阁等级": 技艺殿阁等级,
		"高阶产出": 高阶产出,
		"洞府数量": 洞府数量,
		"灵田等级": 灵田等级总和,
		"毒道境界": 毒道境界总和,
		"傀儡数量": 傀儡总数,
		"休闲等级": 休闲等级总和,
		"飞升弟子": 飞升弟子数,
		"世界探索度": 世界探索度,
	})
	return {
		"评级": 局["评级"],
		"修真名": 获取评级修真名(str(局["评级"])),
		"总分": 局["总分"],
		"年度进度": int(年度进度 * 100),
		"距岁末": max(0, 365 - 已过天数),
	}
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
# 懒加：七载大典文案.csv ：{评级: {标题,开篇,收尾,评语}}（缺文件/缺档不报错）
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
			"开篇": parts[2].strip_edges(),
			"收尾": parts[3].strip_edges(),
			"评语": parts[4].strip_edges(),
		}
	return _七载大典文案缓存
# 硬编码默认文案（与七载大典文：csv 内容一致，作为回退；零数值）
func _七载大典文案_默认(评级: String) -> Dictionary:

	var 局: Dictionary = {
		"D":   {"标题": "七载考评·守拙", "开篇": "根基尚浅，然守拙归真，来日方长", "收尾": "%d七载，宗门稳守本心，来年期可待", "评语": "岁末考评守拙，根基虽浅，来日方长"},
		"C":   {"标题": "七载考评·筑基", "开篇": "百事初立，稳中有进，假以时日可期大成", "收尾": "%d七载，宗门筑基渐稳，来年再图进取", "评语": "岁末考评筑基，稳中有进，来年可期"},
		"B":   {"标题": "七载考评·兴业", "开篇": "产业渐丰，弟子用命，宗门气象一新", "收尾": "%d七载，宗门兴业有成，道途愈宽", "评语": "岁末考评兴业，基业渐丰，气象一新"},
		"A":   {"标题": "七载考评·昌盛", "开篇": "七载经营，宗门昌盛，灵脉日盛", "收尾": "%d七载，宗门昌盛绵延，声望渐起", "评语": "岁末考评昌盛，灵脉日盛，声望渐起"},
		"A+":   {"标题": "七载考评·隆盛", "开篇": "贤才云集，基业隆盛，已具大宗气象", "收尾": "%d七载，宗门隆盛日彰，名动一方", "评语": "岁末考评隆盛，贤才云集，名动一方"},
		"S":   {"标题": "七载大考·宗门鼎盛", "开篇": "七载积淀，道基再固，宗门鼎盛，四海仰止", "收尾": "%d七载，宗门鼎盛，道途至此再进一步", "评语": "七载大考鼎盛，道基再固，四海仰止"},
		"SS":   {"标题": "七载大考·威震一方", "开篇": "七载砥砺，威震一方，诸宗来朝，灵脉通玄", "收尾": "%d七载，宗门威名远播，基业永固", "评语": "七载大考威震一方，诸宗来朝，基业永固"},
		"SSS":   {"标题": "七载大考·道途无双", "开篇": "七载问道，道途无双，太玄宗之名，响彻修真界", "收尾": "%d七载，太玄宗立不朽之基，万世流芳", "评语": "七载大考道途无双，太玄之名响彻修真界"},
	}
	return 局.get(评级, 局["C"])

## 评级修真名称映射（内部计算用D/C/B/A，显示用修真味名称）
func 获取评级修真名(评级: String) -> String:
	var 映射: Dictionary = {
		"D": "守拙",
		"C": "筑基",
		"B": "兴业",
		"A": "昌盛",
		"A+": "隆盛",
		"S": "鼎盛",
		"SS": "威震一方",
		"SSS": "道途无双",
	}
	return str(映射.get(评级, 评级))

## 评级修真描述（用于UI tooltip）
func 获取评级修真描述(评级: String) -> String:
	var 映射: Dictionary = {
		"D": "根基尚浅，然守拙归真，来日方长",
		"C": "百事初立，稳中有进，假以时日可期大成",
		"B": "产业渐丰，弟子用命，宗门气象一新",
		"A": "七载经营，宗门昌盛，灵脉日盛",
		"A+": "贤才云集，基业隆盛，已具大宗气象",
		"S": "七载积淀，道基再固，宗门鼎盛，四海仰止",
		"SS": "七载砥砺，威震一方，诸宗来朝，灵脉通玄",
		"SSS": "七载问道，道途无双，太玄宗之名，响彻修真界",
	}
	return str(映射.get(评级, ""))

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
		# H项：宗门晋升时更新复兴进度→色彩饱和/明度派生
		if get_node_or_null("/root/UITheme") != null:
			UITheme.设置复兴进度(门派等级)
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
## S1：灵米消耗结算（含辟谷机制：练气全耗、筑基半耗、金丹以上不耗）
func _结算灵米消耗_S1() -> void:
	var 需消耗: int = 0
	var 辟谷数: int = 0
	for d in 弟子列表:
		if d == null or not (d is Disciple) or str(d.状态) != "在宗":
			continue
		var 境界序: int = Disciple.境界序.find(str(d.境界))
		if 境界序 >= 2:  # 金丹及以上完全辟谷
			辟谷数 += 1
			continue
		elif 境界序 == 1:  # 筑基减半消耗
			需消耗 += 1 if randf() < 0.5 else 0
		else:  # 练气全额消耗
			需消耗 += 1
	if 需消耗 == 0:
		return
	if 灵米 >= 需消耗:
		灵米 -= 需消耗
	else:
		var 缺额: int = 需消耗 - 灵米
		灵米 = 0
		# 灵米不足：未辟谷弟子忠诚度下降
		for d in 弟子列表:
			if d == null or not (d is Disciple) or str(d.状态) != "在宗":
				continue
			var 境界序: int = Disciple.境界序.find(str(d.境界))
			if 境界序 < 2:  # 只有未辟谷弟子受影响
				d.增加忠诚(-1)
		_加推演条目("宗门灵米告罄，低阶弟子饥肠辘辘，忠心渐失（缺%d灵米，%d名高阶弟子已辟谷）" % [缺额, 辟谷数], "庶务", "中")
		添加纪事("庶务", "灵米不足", "宗门灵米告罄，低阶弟子食不果腹，怨声载道", 2)

## S1：购买灵种（坊市）
func 购买灵种(数量: int) -> Dictionary:
	var 总价: int = 数量 * 灵种购买价格
	if 灵石 < 总价:
		return {"成功": false, "原因": "灵石不足（需%d）" % 总价}
	灵石 -= 总价
	灵种 += 数量
	_加推演条目("坊市购入灵种%d份，共耗灵石%d" % [数量, 总价], "庶务", "低")
	return {"成功": true, "数量": 数量, "消耗": 总价}

## S1：售卖灵草（坊市，单价2灵石，受坊市折扣影响）
func 售卖灵草(数量: int) -> Dictionary:
	if 灵草 < 数量:
		return {"成功": false, "原因": "灵草不足（当前%d）" % 灵草}
	var 单价: int = max(1, int(2 * 坊市折扣率()))
	var 总价: int = 数量 * 单价
	灵草 -= 数量
	灵石 += 总价
	_加推演条目("坊市售出灵草%d份，获得灵石%d" % [数量, 总价], "庶务", "低")
	return {"成功": true, "数量": 数量, "获得": 总价}

## S1：售卖灵米（坊市，单价3灵石，受坊市折扣影响）
func 售卖灵米(数量: int) -> Dictionary:
	if 灵米 < 数量:
		return {"成功": false, "原因": "灵米不足（当前%d）" % 灵米}
	var 单价: int = max(1, int(3 * 坊市折扣率()))
	var 总价: int = 数量 * 单价
	灵米 -= 数量
	灵石 += 总价
	_加推演条目("坊市售出灵米%d份，获得灵石%d" % [数量, 总价], "庶务", "低")
	return {"成功": true, "数量": 数量, "获得": 总价}

## S1：洞府拥挤惩罚（弟子无洞府可住，修炼效率下降+忠诚度下降）
func _洞府拥挤惩罚_S1() -> void:
	var 拥挤度: float = 洞府拥挤度()
	if 拥挤度 <= 0.8:
		return  # 舒适，无惩罚
	var 惩罚系数: float = clamp((拥挤度 - 0.8) * 2.0, 0.0, 0.5)  # 最多50%惩罚
	var 受影响: int = 0
	for d in 弟子列表:
		if d != null and d is Disciple and str(d.状态) == "在宗":
			# 拥挤时随机部分弟子受影响（超出洞府数量的部分）
			if randf() < (拥挤度 - 1.0) if 拥挤度 > 1.0 else 惩罚系数:
				d.增加忠诚(-1)
				受影响 += 1
	if 受影响 > 0:
		_加推演条目("洞府拥挤，%d名弟子无处可居，修炼懈怠、心生不满" % 受影响, "庶务", "中")

func _结算俸禄_S1() -> void:

	# S30 完整俸禄账本：按月按(基础俸×身份倍率×境界系数)真实发放；足额→欠俸清零+忠诚微涨；不足→欠俸月数+1+忠诚↓
	累计发放俸禄次数 += 1
	_复检成就()
	var 境系数表: Array = [1.0, 1.1, 1.25, 1.4, 1.6, 1.8, 2.0, 2.2, 2.5, 3.0, 3.5]  # 练气→道阶
	var 在宗俸: Array = []   # 元素 [弟子, 应发额]
	var 应发总额: float = 0.0
	for d in 弟子列表:
		if d == null or str(d.状态) != "在宗":
			continue
		var 阶: int = Disciple.境界序.find(str(d.境界))
		var 境系数: float = 境系数表[阶] if 阶 >= 0 and 阶 < 境系数表.size() else 1.0
		var 应发: float = 4.5 * _身份俸禄倍率(str(d.身份)) * 境系数
		在宗俸.append([d, 应发])
		应发总额 += 应发
	if 在宗俸.is_empty():
		return
	if 灵石 >= int(round(应发总额)):
		for 项 in 在宗俸:
			var d: Object = 项[0]
			var 发: int = int(round(项[1]))
			灵石 -= 发
			d.欠俸月数 = 0
			d.增加忠诚(1)
	else:
		for 项 in 在宗俸:
			var d: Object = 项[0]
			d.欠俸月数 += 1
			d.增加忠诚(-clamp(2 + d.欠俸月数, 2, 12))
		var 示例欠: int = int(在宗俸[0][0].欠俸月数)
		_加推演条目("宗门灵石拮据，本月俸禄难继，弟子忠心渐失（连续欠俸 %d 月）" % [示例欠], ET_SECT, PRIO_HIGH, {})
		添加纪事("俸禄", "欠俸", "公库空虚，本月俸禄无以为继，门下弟子渐生怨怼之心", 2)
var _经济基线缓存: Dictionary = {}   # D1：经济基：csv 缓存（clamp 边界来源，R5 非硬编码：
# ============ D3 负面影响经济侧（S1-P0 批次三· 数据对齐版）============
# 轻量管理器状态（运行时瞬时，不持久化；规：design/08-功能提案/12-D3实现规格_数据对齐：md §8：
var _经济阀门缓存: Dictionary= {}      # 经济阀门.csv ：{阀门 {系数,开：说明}}（懒加载：
var _负面事件缓存: Array = []           # negative_event.csv 行缓存（懒加载）
var _本月负面已触发: Dictionary= {}     # 本月：event_id 触发次数（月度重置）
var _本月灵石冲击: float = 0.0          # 本月负面事件灵石冲击累计（月末截断至 62：
var _弟子负面属性累计: Dictionary= {}   # 纯属性惩罚累计（零副作用占位；键=弟子姓名：
var _坊市负面卖价下限: float = 1.0       # 声望外部类浅联动下限（P0 neg_reputation=0，默认不触发：
# D3 开关缓存（：_加载负面开关_S1 ：经济阀门.csv 读取；默认值对齐规：§6 默认安全态）
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
	var 上限: float = float(基线.get("标准局月耗_上限", "318"))
	# S30 去重：C4 俸禄占位已移至 _结算俸禄_S1 真实发放（不再在此双重扣减）
	var c5: float = 3.0 * 司职列表.size()
	var c6: float = 0.73 * 弟子列表.size()
	var c7: float = 0.375 * 弟子列表.size()
	var 刚性耗: float = c5 + c6 + c7          # 运维upkeep（不含俸禄，C4已移至 _结算俸禄_S1）
	# R5：仅封顶，不再强制 293 地板（俸禄已独立核算，避免公库虚耗）
	刚性耗 = clamp(刚性耗, 0.0, 上限)
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
		# ★ 2026-09-16 修：下面三行原被误缩进到 `if 行== "": / continue` 之内（continue 之后不可达）
		#   ⇒ 缓存恒空 ⇒ 全项目唯一消费点 _结算运维成本_S1 一直静默用硬编码兜底值，
		#   「R5 非硬编码」名存实亡。缩进回正后 CSV 才真正生效（CSV 值=硬编码兜底值，行为不变）。
		var 列: PackedStringArray = 行.split(",")
		if 列.size() >= 2:
			_经济基线缓存[列[0].strip_edges()] = 列[1].strip_edges()
	f.close()
	return _经济基线缓存
# ============ ECON-03 P0-A 双货币汇率基座（2026-09-16）============
# R = 1 仙玉兑多少灵石（越大 ⇒ 灵石越不值钱）；锚 ECON-01「标准局月产」，clamp[6,30]。
# ★ 汇率**不进存档**：跨日读档若读回旧牌价，会出现「显示价 ≠ 实扣价」（本项目踩过的老坑）。
var 汇率_日缓存: float = 0.0
var 汇率_缓存日: int = -1
# 预留全服注入点：未来接云端行情只需让本函数返回服务端 R，
# 下面的本地公式自动降级为「离线兜底」，全部消费点零改动。
func _汇率_取自云端() -> float:
	return 0.0
# 确定性日浮动因子：同一天多次调用必然同值（禁用 randi，否则「一刷新就变」显廉价）。
# 以「累计游戏日」为种做散列 ⇒ 跨日自然轮换，既满足「能浮动」又可复现。
func _汇率_浮动因子(日: int) -> float:
	var 种: int = (日 * 1103515245 + 12345) & 0x7fffffff
	return float(种 % 10000) / 10000.0
func 当前汇率() -> float:
	var 日: int = int(累计游戏日)
	if 汇率_缓存日 == 日 and 汇率_日缓存 > 0.0:
		return 汇率_日缓存
	var 基线: Dictionary = _读经济基线()
	var 基准: float = float(基线.get("仙玉基准汇率", "10"))
	var 下限: float = float(基线.get("汇率下限", "6"))
	var 上限: float = float(基线.get("汇率上限", "30"))
	var 远端: float = _汇率_取自云端()
	if 远端 > 0.0:
		汇率_日缓存 = clamp(远端, 下限, 上限)
		汇率_缓存日 = 日
		return 汇率_日缓存
	# f_产：本局月产相对标准局(366)越高 ⇒ 灵石越泛滥 ⇒ R 越大（灵石通胀的直接锚）
	var f产: float = clamp(float(预估月产出()) / 366.0, 0.70, 2.00)
	# f_望：声望越高 ⇒ 宗门在修真界越有牌面 ⇒ 换汇议价强 ⇒ 仙玉更便宜 ⇒ R 越小
	var f望: float = clamp(1.40 - float(声望) / 6000.0, 0.75, 1.40)
	# f_浮：±8% 日浮动
	var f浮: float = 1.0 + (_汇率_浮动因子(日) - 0.5) * 0.16
	汇率_日缓存 = clamp(基准 * f产 * f望 * f浮, 下限, 上限)
	汇率_缓存日 = 日
	return 汇率_日缓存
func 汇率牌价文案() -> String:
	var r: float = 当前汇率()
	var 势: String = "市价平稳"
	if r >= 12.0:
		势 = "仙玉见涨"
	elif r < 9.0:
		势 = "灵石渐贵"
	# 百枚仙玉的灵石等价一并报出 —— 玩家手上多是数十上百枚，单枚报价不够用。
	return "今日牌价：1 仙玉 ≈ %.1f 灵石 ｜ 百枚仙玉 ≈ %d 灵石（%s）" % [r, 仙玉折灵石(100), 势]
func 仙玉结算溢价() -> float:
	return float(_读经济基线().get("仙玉结算溢价", "1.15"))
# 灵石计价 → 仙玉价：仙玉是硬通货，用硬通货买流通货物理应不划算 ⇒ 主动加价，
# 引导玩家用灵石参与中低端竞拍、只在抢高阶货时才动用仙玉。
func 灵石折仙玉(灵石价: int) -> int:
	if 灵石价 <= 0:
		return 0
	return int(ceil(float(灵石价) / 当前汇率() * 仙玉结算溢价()))
# 仙玉计价 → 灵石价：与 灵石折仙玉() 互为逆运算（同 R 下往返自洽）。
func 仙玉折灵石(仙玉价: int) -> int:
	if 仙玉价 <= 0:
		return 0
	return int(floor(float(仙玉价) * 当前汇率() / 仙玉结算溢价()))
# ============ D3 负面影响经济侧（S1-P0 批次三）运行时管理器 ============
# 消费 config/negative_event.csv（_读负面事件表： config/经济阀门.csv（neg_* 开关簇 + event_damage_rate：
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
	for r in DestinyDataLoader._read_csv("res://config/经济阀门.csv"):
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
		_加推演条目("【负面】%s：%s" % [str(行.get("event_name", eid)), "，".join(PackedStringArray(后果))], ET_SECT, PRIO_NORMAL, {"事件": eid})
# —：品级权限类惩处（D4 本批：权益回收= 罢免阶位 + 治理失序罚金）—：
func _权益回收惩处(罚金: float, 后果: Array) -> void:

	_本月灵石冲击 += 罚金                       # ：_负面总冲击卡：) 卡位后扣公库
	后果.append("治理失序罚金-%d" % int(round(罚金)))
	var 候选: Array = 弟子列表.filter(func(d): return d.阶位 != "无")
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
# —：：经济阀门.csv 加载 D3 开关簇（neg_*；event_damage_rate 由平：) 读取，本处不重复）—：
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
	# 修真味：声望阈值触发特殊弟子主动投奔
	if 特殊投奔冷却 > 0:
		特殊投奔冷却 -= 1
		return
	# 声望≥500且弟子数量<编制上限时，5%概率触发
	if 声望 >= 500 and 弟子列表.size() < 洞府数量 and randf() < 0.05:
		var d := Disciple.new()
		_随机弟子种族(d)
		_确保字派_S1()
		d.辈分序 = 0
		# 特殊投奔弟子资质更好
		d.灵根品阶 = ["上品", "极品", "天品"][randi() % 3]
		d.资质 = ["良好", "优秀", "绝顶"][randi() % 3]
		d.境界 = "练气"
		d.层级 = randi() % 5 + 1
		d.战力 = d.计算战力()
		弟子列表.append(d)
		特殊投奔冷却 = 90  # 90游戏日冷却
		_加推演条目("【投奔】%s闻宗门声望，千里迢迢前来投奔！" % str(d.姓名), "弟子", "中")
		弟子变动.emit()
# === S1 ：-A：凡人香火月度结算（当前空操作桩：==
# 调用位置：推演一：月循环（紧接 _可能触发特殊登门_S1 之后）：
# 入参：无（读取全局 香火值/ 信徒数/ 凡人城镇）：
# 返回值：void；S1 实装后：按月累加香火/信徒、重算月产预估与增益档、产出计：§11.9 财政：
# 依赖：数：[PLACEHOLDER]，真机校准。状态：空操作，零副作用：
func _结算香火_S1() -> void:
	# S2-3：补香火/信徒产出出口（原为空桩：空操作零副作用）
	if 门派等级 <= 0:
		门派等级 = 1
	# S34：香火 = 宗门基础香火（日度）+ 凡间郡县供奉（月度摊日均；感恩度 × 王朝阶段 × 国策）
	# 基础香火（日频）：满配 门派10级+100弟子 = 50+140 = 190；+凡间供奉89 = 279 ≈ 设计锚点280
	var 基础香火: int = 门派等级 * 5 + int(弟子列表.size() * 1.4)
	var 供奉日均: int = int(float(_郡县供奉香火_S34()) / float(王朝月长))
	var 信仰香火: int = _信仰香火日产_S34()
	var 月产: int = max(0, 基础香火 + 供奉日均 + 信仰香火)
	香火值 = max(0, 香火值 + 月产)
	香火日产预估 = 月产
	# 信徒随宗门规模 + 凡间人口累积（供晋阶消耗；不随香火绝对值回退，避免覆盖已花费的信徒）
	信徒数 += 门派等级 + 弟子列表.size() + clamp(int(_凡间信众_S34() / 10), 0, 10)
	添加纪事("庶务", "香火月结", "本月香火+%d（宗门%d＋凡间供奉%d），累计%d，信徒%d人（增益：%s）"
		% [月产, 基础香火, 供奉日均, 香火值, 信徒数, 信徒增益档], 0)

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
#   气运基础 = 香火日产预估×2.0 + 愿力×0.1 + 功德×0.5 - 业力×0.5
#   归一化：(基础+500)/1500*100，clamp到0-100
# 设计要点：
#   1. 香火用月产速率（不是存量）→ 消耗香火供奉不影响气运（解决模型倒置）
#   2. 香火速率加显式软上限（气运香火速率上限=560）→ 弟子数再多也不溢出恒锁昌隆，正邪路由不失效（解决归一化溢出）
#   3. 功德/业力权重高（0.5）→ 正邪路线真正决定气运走向
#   4. 愿力权重低（0.1）→ 愿力升华修为不显著影响气运
# 气运等级：昌隆(≥80)/旺盛(≥60)/平稳(≥40)/低迷(≥20)/衰败(<20)
# 加成系数：昌隆+20%/旺盛+10%/平稳0%/低迷-10%/衰败-20%

func 获取气运值() -> int:
	# 产出速率+存量模型
	# 香火速率加软上限：弟子数无上限会让月产×2 溢出，锁到 气运香火速率上限 防止气运恒锁昌隆
	var 香火速率: float = min(float(香火日产预估) * 2.0, 气运香火速率上限)   # 香火日产速率（软上限560）
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

## S1：驱逐弟子（从宗门除名）
func 驱逐弟子(弟子ID: int) -> bool:
	for i in range(弟子列表.size()):
		var d = 弟子列表[i]
		if d != null and d is Disciple and int(d.弟子ID) == 弟子ID:
			弟子列表.remove_at(i)
			_加推演条目("【%s】被逐出宗门" % str(d.姓名), "人事", "中")
			return true
	return false

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
		"灵脉等级": 灵脉等级,
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
	var n: int = randi_range(5, 候选池.size())
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
## ★ 2026-09-14 新增：执事殿月课 —— 弟子身份升迁（自动流转，不设玩家按钮）
## 职责归属（老大 2026-09-14 拍板：「先分清谁该执行」）：
##   · 弟子身份升迁＝宗门常例，由【执事殿】司职弟子依境界考核办理 ⇒ **自动**；
##   · 宗主只保留不可代劳的决策（任命主事／驱逐／裁决请誓／定方针／洗池付费重铸）。
## 旧版这是弟子录顶栏「批量操作」一键钮（顺手白送全体忠诚+5 ⇒ 越权 + 违铁律 11），
## 现已迁回自动流转；白送忠诚一项直接删除（忠诚本由 14722 每月俸禄账本决定）。
## 门槛：在宗的「外门」弟子，境界已达筑基及以上 ⇒ 执事殿录名升入内门。
## 名额：1 + (执事殿等级-1) + (有殿主在任 ? 1 : 0)；无执事殿主事在任时仍保底 1 人（不彻底卡死）。
func _月课_执事殿升迁() -> void:
	var 名额: int = 1
	var 殿: Variant = 司职列表.get("yuying", null)
	if 殿 is Dictionary:
		var 殿D: Dictionary = 殿
		var 等级: int = int(殿D.get("等级", 1))
		var 殿主: Variant = 殿D.get("负责人", null)
		名额 = 1 + max(0, 等级 - 1) + (1 if 殿主 != null else 0)
	var 候补: Array = []
	for d in 弟子列表:
		if d == null or not (d is Disciple):
			continue
		if str(d.状态) != "在宗":
			continue
		if str(d.身份) != "外门":
			continue
		var 序: int = Disciple.境界序.find(str(d.境界))
		if 序 >= 0 and 序 >= Disciple.境界序.find("筑基"):
			候补.append(d)
	if 候补.is_empty():
		return
	# 境界高者先录名；同境按战力。
	候补.sort_custom(func(a, b):
		var sa: int = Disciple.境界序.find(str(a.境界))
		var sb: int = Disciple.境界序.find(str(b.境界))
		if sa != sb:
			return sa > sb
		return int(a.战力) > int(b.战力))
	var 升数: int = min(名额, 候补.size())
	for i in range(升数):
		var 弟子 = 候补[i]
		弟子.身份 = "内门弟子"
		添加纪事("宗门", "身份升迁", "执事殿录名：%s 道基已固，依例升入内门。" % str(弟子.姓名), 1)
		_加推演条目("【执事殿】%s 境界已至%s，依例录名升入内门弟子。" % [str(弟子.姓名), str(弟子.境界)], ET_APPOINT, PRIO_NORMAL, {"弟子": 弟子.姓名})

## ★ 2026-09-14 新增：丹堂月课 —— 施药（宗门库房 → 按需施予同门）
## 职责归属（承接老大 2026-09-14「先分清谁该执行」）：
##   · 丹药的「分发／服用」是【丹堂】职分 ⇒ **自动**；不该由宗主在弟子详情页逐人点「服用丹药」。
##   · 弟子对「自己私库」的自动服用已由 disciple.gd::私库自动服用丹药() 负责，与本课互补（公库/私库两层）。
## 门槛：在宗 ·（受伤未愈 或 心魔≥30）。名额＝1 + (丹堂等级-1) + (有殿主在任 ? 1 : 0)。
## 取药一律走 `弟子服用丹药()` 统一入口（与玩家/未来「丹房·择人赐丹」同一条路径，不另开旁路）。
func _月课_丹堂施药() -> void:
	if 宗门库房 == null or 宗门库房.size() == 0:
		return
	var 名额: int = 1
	var 殿: Variant = 司职列表.get("dantang", null)
	if 殿 is Dictionary:
		var 殿D: Dictionary = 殿
		名额 = 1 + max(0, int(殿D.get("等级", 1)) - 1) + (1 if 殿D.get("负责人", null) != null else 0)
	# 宗门库房内的丹药（★2026-09-15 修正：类别常量是拼音码 `dan_yao`，旧写中文「丹药」永不命中
	#   ⇒ 丹堂月课从未真正施过药，属静默死课。此处与 Item.类别 的全局口径对齐。）
	var 丹名: Array = []
	for it in 宗门库房:
		if it != null and _物品类别码(it) == "dan_yao":
			丹名.append(_物品名(it))
	if 丹名.is_empty():
		return
	# 候补：伤重／心魔高者先（伤 2 分、心魔 1 分）
	var 候补: Array = []
	for d in 弟子列表:
		if d == null or not (d is Disciple):
			continue
		if str(d.状态) != "在宗":
			continue
		if int(d.受伤剩余) > 0 or int(d.心魔值) >= 30:
			候补.append(d)
	if 候补.is_empty():
		return
	候补.sort_custom(func(a, b):
		return int(a.受伤剩余) * 2 + int(a.心魔值) > int(b.受伤剩余) * 2 + int(b.心魔值))
	var 施数: int = min(名额, 候补.size())
	for i in range(施数):
		var 病者: Disciple = 候补[i]
		# 心魔缠身者优先取宁神类丹药；无对症者取库房首味（不挑肥拣瘦，先救急）。
		var 用丹: String = ""
		if int(病者.心魔值) >= 30:
			for nm in 丹名:
				var s: String = str(nm)
				if s.contains("宁神") or s.contains("清心") or s.contains("静心") or s.contains("定神"):
					用丹 = s
					break
		if 用丹 == "":
			用丹 = str(丹名[0])
		var 果: Dictionary = 弟子服用丹药(int(病者.弟子ID), 用丹)
		if bool(果.get("成功", false)):
			添加纪事("丹堂", "施药", "丹堂弟子为%s施予「%s」，气机转顺。" % [str(病者.姓名), 用丹], 1)
			_加推演条目("【丹堂】%s 得丹堂施药（%s）。" % [str(病者.姓名), 用丹], ET_RESOURCE, PRIO_NORMAL, {"弟子": 病者.姓名})

## ★ 2026-09-15 新增：洗池月课 —— 灵泉开年，弟子自费入池洗髓
## 职责归属（铁律 11）：洗髓是弟子自己的造化，须自己以**个人功勋（贡献账户）**叩请 ⇒ 弟子自主层。
##   宗主侧只保留「耗仙玉强开灵泉」的手动付费入口（详情页·洗池 · 洗髓）——仙玉＝外力催动，贵而随心。
## 天时（修真世界观）：洗池灵泉十二载一开、开则三十日（`XiChiSystem.灵泉开启信息`）；
##   一轮灵泉内每人至多洗髓一次（闸门 = `弟子.灵泉洗髓轮`），避免开年三十日反复刷命格。
## 名额：不设人为配额（自费花钱即是门槛），但按池级取前 N 人，防一月内透支式排队。
## 真源：一律走 `XiChiSystem.弟子自费洗髓()`（与玩家仙玉路径共用同一条 重铸命格() 落点）。
func _月课_洗池灵泉() -> void:
	var 泉: Dictionary = XiChiSystem.灵泉开启信息(累计游戏日)
	if not bool(泉.get("开启", false)):
		return
	var 轮: int = int(泉.get("轮", 0))
	var 池: Variant = 司职列表.get("xichi", null)
	var 池级: int = 1
	if 池 is Dictionary:
		池级 = int((池 as Dictionary).get("等级", 1))
	var 耗勋: int = int(XiChiSystem.自费洗髓耗功勋)
	# 候补：在宗 · 本轮未洗 · 功勋够（功勋厚者先，合乎「能者多得造化」）
	var 候补: Array = []
	for d in 弟子列表:
		if d == null or not (d is Disciple):
			continue
		if str(d.状态) != "在宗":
			continue
		if int(d.灵泉洗髓轮) == 轮:
			continue
		if int(d.贡献账户) < 耗勋:
			continue
		候补.append(d)
	if 候补.is_empty():
		return
	候补.sort_custom(func(a, b): return int(a.贡献账户) > int(b.贡献账户))
	var 名额: int = min(候补.size(), max(1, 池级))
	for i in range(名额):
		var 弟子: Disciple = 候补[i]
		var 结果: Dictionary = XiChiSystem.弟子自费洗髓(弟子, 池级, 累计游戏日)
		if bool(结果.get("成功", false)):
			添加纪事("洗池", "灵泉洗髓", "%s以个人功勋%d叩请，入灵泉洗池重铸道基。" % [str(弟子.姓名), 耗勋], 2)
			_加推演条目("【洗池】%s 自费入池洗髓：%s" % [str(弟子.姓名), str(结果.get("原因", ""))], ET_APPOINT, PRIO_NORMAL, {"弟子": 弟子.姓名})

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
				# §4.0 弟子自主层：所得先过弟子本人这一关——瞒报私藏则直接入私库，不进待抉择队列
				if _弟子是否私藏(d, it):
					_弟子私藏入库(d, it)
				else:
					待抉择.append({"弟子": d, "物品": it, "文本": 文本})
		if randf() < 0.05:
			var 兽: Beast = Beast.new()
			灵兽蛋列表.append(兽)
			文本 += " 寻得灵兽蛋一枚"
	else:
		var 原因池: Array[String] = [
			"寻宝未获，空手而归",
			"遭遇迷障，寸步难行",
			"探寻无果，徒劳往返",
			"灵气稀薄，无功而返",
			"妖兽出没，被迫绕行",
			"天候骤变，折返避祸",
			"路径生疏，迷失林中",
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
	if q.is_empty() or str(q.get("event_id") if "event_id" in q else "") == "":
		return 结果
	# Sprint-02b：单条冷却检查（cooldown_hour 转游戏日比较：
	var eid := q.get("event_id") if "event_id" in q else "" as String
	var cd_hour := q.get("cooldown_hour") if "cooldown_hour" in q else 0 as int
	if cd_hour > 0 and _单条冷却记录.has(eid):
		var 上次触发日:= _单条冷却记录[eid] as int
		if 累计游戏日- 上次触发日< ceil(cd_hour / 24.0):
			return 结果
	# S0 P0：奇遇防重复冷却（月份维度，3个月：
	if quest_cooldown.has(eid) and _当前月() < quest_cooldown[eid]:
		return 结果
	_今日奇遇次数 += 1
	_单条冷却记录[eid] = 累计游戏日
	quest_cooldown[eid] = _当前月() + 3
	# 声望：稀有及以上品质奇遇（配套规则+10~20：
	if str(q.get("稀有度") if "稀有度" in q else "普通") != "普通":
		_加声望(randi_range(10, 20))
	# 分流收尾（ADR-002 / ADR-003：
	if q.需干预:
		# ： 进干预队列（UI 灰模：art-lead 后续出）；兜底期恒不触发
		奇遇待抉择.append({"弟子": d, "奇遇": q, "选项": Quest.干预选项})
	else:
		if str(q.get("event_type") if "event_type" in q else "") == "征伐":
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
		if str(evt.get("trigger_scene") if "trigger_scene" in evt else "") != "机缘":
			continue
		if int(evt.get("unlock_sect_level") if "unlock_sect_level" in evt else 1) > 门派等级:
			continue
		var d_idx: int = Disciple.境界序.find(d.境界)
		var e_idx: int = Disciple.境界序.find(evt.get("unlock_realm") if "unlock_realm" in evt else "练气")
		if e_idx < 0 or d_idx < 0 or e_idx > d_idx:
			continue
		var eid: String = evt.get("event_id") if "event_id" in evt else ""
		if quest_cooldown.has(eid) and _当前月() < quest_cooldown[eid]:
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
		if str(evt.get("rarity") if "rarity" in evt else "普通") != "普通":
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
			"baoming":
				# P3 保命环节：奇遇获赠保命法宝（来源：奇遇）——以实物道具入背包
				for _i in 数量:
					var 机缘道具 = 构造保命道具("机缘护身符", "宝阶", "fabao",
						"奇遇所得护身法宝，致命劫数下瞒过天地替弟子避劫", "机缘巧合所得的护身之宝，危难时自发护主。")
					d.获得物品(机缘道具)
				摘要 += " 机缘护身符×%d" % 数量
			"jiadan":
				# P3 保命环节：奇遇得假死丹（背包道具，致命时可替死）
				for _i in 数量:
					var it: Item = Item.new()
					it.类别 = "dan_yao"
					it.品阶 = "宝阶"
					it.名称 = "假死丹"
					it.功效 = "服之假死敛息，致命劫数下瞒过天地，替弟子避过一劫"
					it.描述 = "丹色青灰，气绝假象，危难时可保命替死"
					it.保命 = true
					d.获得物品(it)
				摘要 += " 假死丹×%d" % 数量
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
			# ★ 2026-09-16 修：原为 `_百分比文本`（漏括号）⇒ 塞进格式串的是 Callable，且上面解析出的 值 反被弃用
			return "(全宗%s提升%s)" % [_buff文本(bid), _百分比文本(值)]
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
		"combat_power": "道行", "loot_rate": "掉落率", "sect_reputation": "声望"
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
	if str(q.get("稀有度") if "稀有度" in q else "普") in ["稀有", "上品", "极品", "天品"]:
		高级奇遇完成数+= 1
	var 摘要: String = "奇遇·" + str(q.get("稀有度") if "稀有度" in q else "普")
	if str(q.get("稀有度") if "稀有度" in q else "普") in ["上品", "极品", "天品"]:   # P1：高稀有度奇遇计入周期评分
		周期评分.记稀有道具()
	# Sprint-02b：宗门等级缩放赏赐（：q 有缩放字段时：
	var base := q.get("base_value") if "base_value" in q else 0.0 as float
	var 灵石赏赐 := 0
	if base > 0.0:
		var factor := q.get("level_factor") if "level_factor" in q else 0.15 as float
		var min_v := q.get("min_value") if "min_value" in q else 0.0 as float
		var max_v := q.get("max_value") if "max_value" in q else 999.0 as float
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
	var 赏赐文本: String = q.get("opt1_reward") if "opt1_reward" in q else ""
	if 赏赐文本.strip_edges() != "":
		var 解析摘要: String = _解析并发放奇遇赏赐(d, 赏赐文本)
		if 解析摘要 != "":
			摘要 += 解析摘要
			宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": q.get("稀有度") if "稀有度" in q else "普通", "名称": q.get("event_name") if "event_name" in q else "奇遇赏赐", "文案": "获得赏赐：%s" % 解析摘要.strip_edges()})
	# 道心值：待道心系统；：Sprint 先记 履历（ADR-002 D5）：
	d.履历.append(摘要)
	# 修真式领悟：奇遇机缘领悟（稀有度越高概率越大）
	var 稀有度: String = str(q.get("稀有度") if "稀有度" in q else "普通")
	var 奇遇概率: float = 0.0
	match 稀有度:
		"普通":
			奇遇概率 = 0.0
		"稀有":
			奇遇概率 = 0.05
		"上品":
			奇遇概率 = 0.10
		"极品":
			奇遇概率 = 0.15
		"天品":
			奇遇概率 = 0.25
	if 奇遇概率 > 0:
		_尝试领悟技能(d, "奇遇", 奇遇概率)
# ============ 奇遇·征伐：战斗收尾（ADR-003 D6：/ ADR-002 hook：===========
# ：Quest.结算征伐 发起战斗（BattleManager 调用 BattleCalculator 纯逻辑）返回统一 BattleResult：
# 本函数按胜负发放赏赐/：履历，完成「奇遇管理器」收尾（ADR-003 D6：战斗影：履历/声望）：
func 结算征伐奇遇(d: Disciple, q: Dictionary):

	_上次奇遇时刻 = Time.get_ticks_msec()
	奇遇完成总数 += 1
	if str(q.get("稀有度") if "稀有度" in q else "普") in ["稀有", "上品", "极品", "天品"]:
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
		结果["error"] = "秘境不存在 %s" % stage_id
		return 结果
	if not StageDataLoader.is_unlocked(stage_id, 门派等级, 已通关秘境):
		结果["error"] = "秘境未解锁"
		return 结果
	if 出战弟子.is_empty():
		结果["error"] = "未选择出战弟子"
		return 结果
	# S1 器殿赠宝：缓存最近出战阵容（：P1 权重判定；存姓名，可序列化，save/load 持久化）
	if 出战弟子.size() > 0:
		_上次出战弟子 = 出战弟子.filter(func(d): return d is Disciple).map(func(d): return d.姓名)
	var 节点类型: String = stage.get("node_type") if "node_type" in stage else "normal"
	# P0修复：体力系统改为每日机缘校验
	var 机缘检查: Dictionary = 检查机缘("探秘境缘")
	if not 机缘检查.get("足够", false):
		结果["error"] = "今日探秘境缘已尽（%d/%d），可提升仙缘位阶以增机缘" % [机缘检查.get("已用", 0), 机缘检查.get("上限", 0)]
		return 结果
	# 精英每日次数校验
	if 节点类型 == "elite":
		var 今日: String = "%d" % 累计游戏日
		if not 精英每日次数.has(今日):
			精英每日次数[今日] = {}
		var 上限: int = int(stage.get("daily_limit") if "daily_limit" in stage else 0)
		if 上限 > 0 and 精英每日次数[今日].get(stage_id, 0) >= 上限:
			结果["error"] = "今日精英挑战次数已用完"
			return 结果
	# P0修复：体力系统改为每日机缘消耗
	if not 消耗机缘("探秘境缘"):
		结果["error"] = "今日探秘境缘已尽"
		return 结果
	# 组装敌方（CSV 驱动：
	var 怪物: Array = StageDataLoader.build_monster_units(stage_id)
	if 怪物.is_empty():
		# P0修复：机缘回退
		每日机缘["探秘境缘"] = max(0, int(每日机缘.get("探秘境缘", 0)) - 1)
		结果["error"] = "秘境无怪物配置"
		return 结果
	# 组装我方快照（弟子：战斗属性聚合，唯一入口 get_final_combat_attr：
	var 我方: Array = []
	for d in 出战弟子:
		if d is Disciple:
			我方.append(d.get_final_combat_attr())
	if 我方.is_empty():
		# P0修复：机缘回退
		每日机缘["探秘境缘"] = max(0, int(每日机缘.get("探秘境缘", 0)) - 1)
		结果["error"] = "出战弟子属性无效"
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
	# P1深化：临阵突破触发（修真小说常见桥段：战斗绝境中压力激发潜能）
	# 触发条件：战斗回合数≥5（激战）+ 弟子大圆满 + 瓶颈打磨≥0.8 + 10%概率
	var 临阵突破触发: bool = 结果["round_count"] >= 5 and randf() < 0.10
	if 临阵突破触发:
		for d in 出战弟子:
			if d is Disciple and d.层数 >= 10 and d.瓶颈打磨值 >= 0.8:
				var 突结: Dictionary = d.临阵突破("历练")
				if 突结.get("成功", false):
					结果["battle_log"].append("【临阵突破】%s于激战中突破至%s！" % [d.姓名, d.境界])
				break  # 每次历练最多触发1人临阵突破
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
				# 修真式领悟：激战临阵领悟
				var 回合数: int = int(结果.get("round_count", 0))
				if 回合数 > 5:
					_尝试领悟技能(承载, "战斗", float(回合数 - 5) * 0.01)
				# 修真式领悟：濒死绝境顿悟（剩余血量<30%）
				var 剩余血: float = float(结果.get("remaining_hp", 0))
				if 剩余血 > 0 and 剩余血 < 0.3:
					_尝试领悟技能(承载, "濒死")
				# 彩蛋：秘境奇遇（前人坐化/神秘传功/灵泉沐浴等）
				if 结果.get("is_win", false):
					var 秘境等级: int = int(stage.get("recommend_power", 1000)) / 1000
					秘境奇遇彩蛋(承载, max(1, 秘境等级))
	# 弟子履历
	for d in 出战弟子:
		if d is Disciple:
			d.履历.append("历练·%s%s" % [stage.get("stage_name") if "stage_name" in d else stage_id,
				("胜" if 结果["is_win"] else "败") + 结果["赏赐摘要"]])
	弟子变动.emit()
	return 结果
func 历练结算(秘境ID: String, 出战: Array = [], 怪物列表: Array = [], mode: String = "full") -> Dictionary:

	# S45-7：历练符箓加成（消耗符箓→临时提升出战弟子战力，战后还原）
	var 历练符箓加成: float = 符箓消耗加成(3 * max(1, 出战.size()))
	if 历练符箓加成 > 0 and not 出战.is_empty():
		var _原战力: Array = []
		for _d in 出战:
			if _d is Disciple:
				_原战力.append(int(_d.战力))
				_d.战力 = int(float(_d.战力) * (1.0 + 历练符箓加成))
		var _历结: Dictionary = 挑战秘境(秘境ID, 出战, mode)
		for _i in range(_原战力.size()):
			出战[_i].战力 = _原战力[_i]
		return _历结
	return 挑战秘境(秘境ID, 出战, mode)

# ============ P2 高级秘境系统（secret_config.csv接入） ============
var _高级秘境配置缓存: Array = []
var _高级秘境配置已加载: bool = false

## 加载高级秘境配置
func _加载高级秘境配置() -> void:
	if _高级秘境配置已加载:
		return
	_高级秘境配置已加载 = true
	var 路径: String = "res://config/secret_config.csv"
	var 文件: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		return
	var 表头: Array = 文件.get_csv_line()
	while not 文件.eof_reached():
		var 行: Array = 文件.get_csv_line()
		if 行.size() < 表头.size() or 行[0] == "":
			continue
		var 秘境: Dictionary = {}
		for i in range(表头.size()):
			秘境[str(表头[i])] = 行[i] if i < 行.size() else ""
		_高级秘境配置缓存.append(秘境)
	文件.close()

## 获取所有高级秘境列表（含解锁状态）
func 获取所有高级秘境列表() -> Array:
	_加载高级秘境配置()
	var 结果: Array = []
	for 秘境 in _高级秘境配置缓存:
		var 秘境ID: String = str(秘境.get("secret_id", ""))
		var 名称: String = str(秘境.get("secret_name", ""))
		var 解锁条件: String = str(秘境.get("unlock_cond", ""))
		var 主属性: String = str(秘境.get("main_attr", ""))
		var 体力消耗: int = int(秘境.get("stamina_cost", 20))
		var 层数: int = int(秘境.get("layers", 3))
		var BOSS: String = str(秘境.get("boss_info", ""))
		var 核心掉落: String = str(秘境.get("core_drop_pool", ""))
		var 专属事件: String = str(秘境.get("exclusive_event", ""))
		var 通关奖励: String = str(秘境.get("clear_reward", ""))
		# 检查解锁状态（简单判断：宗门等级≥对应境界门槛）
		var 已解锁: bool = false
		var 解锁提示: String = 解锁条件
		match 秘境ID:
			"secret_001":
				已解锁 = 门派等级 >= 2
				if not 已解锁:
					解锁提示 = "需宗门品级二品（筑基圆满）+秘境钥匙"
			"secret_002":
				已解锁 = 门派等级 >= 3
				if not 已解锁:
					解锁提示 = "需宗门品级三品（金丹圆满）+秘境钥匙"
			"secret_003":
				已解锁 = 门派等级 >= 4
				if not 已解锁:
					解锁提示 = "需宗门品级四品（元婴圆满）+秘境钥匙"
			"secret_004":
				已解锁 = 门派等级 >= 4
				if not 已解锁:
					解锁提示 = "需宗门品级四品+阵营尊敬"
		# 检查是否已通关
		var 已通关: bool = 已通关秘境.has(秘境ID)
		结果.append({
			"secret_id": 秘境ID,
			"名称": 名称,
			"解锁条件": 解锁条件,
			"解锁提示": 解锁提示,
			"主属性": 主属性,
			"体力消耗": 体力消耗,
			"层数": 层数,
			"BOSS": BOSS,
			"核心掉落": 核心掉落,
			"专属事件": 专属事件,
			"通关奖励": 通关奖励,
			"已解锁": 已解锁,
			"已通关": 已通关
		})
	return 结果

## 挑战高级秘境（多层战斗系统）
func 挑战高级秘境(秘境ID: String, 出战弟子: Array = []) -> Dictionary:
	var 结果: Dictionary = {"成功": false, "原因": "", "秘境ID": 秘境ID, "到达层数": 0, "总层数": 0, "掉落": [], "战报": [], "通关": false}
	_加载高级秘境配置()
	# 查找秘境配置
	var 配置: Dictionary = {}
	for s in _高级秘境配置缓存:
		if str(s.get("secret_id", "")) == 秘境ID:
			配置 = s
			break
	if 配置.is_empty():
		结果["原因"] = "秘境不存在"
		return 结果
	# 检查解锁
	var 列表: Array = 获取所有高级秘境列表()
	var 已解锁: bool = false
	for item in 列表:
		if str(item.get("secret_id", "")) == 秘境ID:
			已解锁 = bool(item.get("已解锁", false))
			break
	if not 已解锁:
		结果["原因"] = "秘境未解锁"
		return 结果
	# 检查出战弟子
	if 出战弟子.is_empty():
		结果["原因"] = "未选择出战弟子"
		return 结果
	# P0修复：体力系统改为每日机缘校验
	var 机缘检查: Dictionary = 检查机缘("探秘境缘")
	if not 机缘检查.get("足够", false):
		结果["原因"] = "今日探秘境缘已尽（%d/%d），可提升仙缘位阶以增机缘" % [机缘检查.get("已用", 0), 机缘检查.get("上限", 0)]
		return 结果
	# 扣机缘
	if not 消耗机缘("探秘境缘"):
		结果["原因"] = "今日探秘境缘已尽"
		return 结果
	# 开始多层战斗
	var 总层数: int = int(配置.get("layers", 3))
	结果["总层数"] = 总层数
	var 秘境名称: String = str(配置.get("secret_name", ""))
	var 主属性: String = str(配置.get("main_attr", "全"))
	var BOSS信息: String = str(配置.get("boss_info", ""))
	# 准备出战弟子的战斗属性
	var 攻方列表: Array = []
	for d in 出战弟子:
		if d == null:
			continue
		if d.has_method("get_final_combat_attr"):
			var 战斗属性: Dictionary = d.get_final_combat_attr()
			# 技能系统：注入弟子已学技能
			战斗属性["技能"] = 获取弟子技能(int(d.弟子ID))
			攻方列表.append(战斗属性)
		else:
			# 简化版战斗属性
			攻方列表.append({
				"名称": str(d.get("姓名", "弟子")),
				"气血": int(d.get("战力", 100)) * 10,
				"攻击": int(d.get("战力", 100)) / 5,
				"防御": int(d.get("战力", 100)) / 10,
				"速度": 50,
				"暴击率": 0.1,
				"闪避率": 0.05,
				"五行属性": 主属性,
				"职业": str(d.get("道途", "道修")),
				"技能": 获取弟子技能(int(d.弟子ID))
			})
	if 攻方列表.is_empty():
		结果["原因"] = "出战弟子无效"
		# P0修复：机缘回退
		每日机缘["探秘境缘"] = max(0, int(每日机缘.get("探秘境缘", 0)) - 1)
		return 结果
	# 逐层战斗
	var 累计奖励: Dictionary = {"灵石": 0, "悟道点": 0, "材料": []}
	var 战斗日志: Array = []
	var 通关: bool = true
	for 层 in range(1, 总层数 + 1):
		结果["到达层数"] = 层
		# 生成本层怪物
		var 守方列表: Array = _生成秘境怪物(秘境ID, 层, 总层数, 主属性, BOSS信息)
		if 守方列表.is_empty():
			战斗日志.append("第%d层：怪物生成失败，跳过" % 层)
			continue
		# 战斗
		var 战斗结果: Dictionary = {}
		if 攻方列表.size() >= 3 and 守方列表.size() >= 3:
			战斗结果 = BattleCalculator.结算_3v3(攻方列表, 守方列表, "quick")
		else:
			# 1v1战斗
			战斗结果 = BattleCalculator.结算_1v1(攻方列表[0], 守方列表[0], "quick")
		var 胜利: bool = bool(战斗结果.get("胜利", false))
		if 胜利:
			# 计算本层奖励
			var 层奖励: Dictionary = _计算秘境层奖励(秘境ID, 层, 总层数)
			累计奖励["灵石"] += int(层奖励.get("灵石", 0))
			累计奖励["悟道点"] += int(层奖励.get("悟道点", 0))
			if 层奖励.has("材料"):
				for mat in 层奖励["材料"]:
					累计奖励["材料"].append(mat)
			战斗日志.append("第%d层：胜利！获得灵石%d、悟道点%d" % [层, int(层奖励.get("灵石", 0)), int(层奖励.get("悟道点", 0))])
			# 恢复部分气血（胜利后恢复30%）
			for unit in 攻方列表:
				unit["气血"] = int(float(unit.get("气血", 100)) * 1.3)
		else:
			战斗日志.append("第%d层：失败，秘境挑战结束" % 层)
			通关 = false
			break
	# 发放奖励
	if 累计奖励["灵石"] > 0:
		灵石 += int(累计奖励["灵石"])
	if 累计奖励["悟道点"] > 0:
		悟道点 += int(累计奖励["悟道点"])
	# 通关奖励
	if 通关:
		var 通关奖励文本: String = str(配置.get("clear_reward", ""))
		战斗日志.append("◆ 通关%s！%s" % [秘境名称, 通关奖励文本])
		# 额外通关奖励
		灵石 += 总层数 * 500
		悟道点 += 总层数 * 50
		累计奖励["灵石"] += 总层数 * 500
		累计奖励["悟道点"] += 总层数 * 50
		结果["通关"] = true
	# 记录结果
	结果["成功"] = true
	结果["战报"] = 战斗日志
	结果["掉落"] = 累计奖励["材料"]
	结果["灵石奖励"] = 累计奖励["灵石"]
	结果["悟道点奖励"] = 累计奖励["悟道点"]
	# 记录纪事
	添加纪事("历练", "高级秘境", "%s挑战%s，到达%d/%d层%s" % [出战弟子[0].姓名 if 出战弟子.size() > 0 else "弟子", 秘境名称, 结果["到达层数"], 总层数, "（通关）" if 通关 else ""], 2)
	return 结果

## 生成秘境怪物（根据层数和秘境品阶）
func _生成秘境怪物(秘境ID: String, 当前层: int, 总层数: int, 主属性: String, BOSS信息: String) -> Array:
	var 怪物列表: Array = []
	var 是BOSS层: bool = (当前层 == 总层数)
	var 是精英层: bool = (当前层 == 总层数 / 2 + 1)
	# 基础战力根据秘境和层数计算
	var 基础战力: int = 500 + 当前层 * 300
	if 秘境ID == "secret_002":
		基础战力 = 1000 + 当前层 * 500
	elif 秘境ID == "secret_003":
		基础战力 = 2000 + 当前层 * 800
	elif 秘境ID == "secret_004":
		基础战力 = 3000 + 当前层 * 1000
	if 是BOSS层:
		基础战力 *= 3
	elif 是精英层:
		基础战力 *= 2
	# 生成怪物
	if 是BOSS层:
		# BOSS层：1个BOSS
		var BOSS名: String = BOSS信息.split("（")[0] if "（" in BOSS信息 else "秘境守护者"
		怪物列表.append({
			"名称": BOSS名,
			"气血": 基础战力 * 15,
			"攻击": 基础战力 / 3,
			"防御": 基础战力 / 5,
			"速度": 60,
			"暴击率": 0.2,
			"闪避率": 0.1,
			"五行属性": 主属性,
			"职业": "BOSS",
			"是BOSS": true
		})
	elif 是精英层:
		# 精英层：1个精英怪
		怪物列表.append({
			"名称": "秘境精英·%s" % 主属性,
			"气血": 基础战力 * 10,
			"攻击": 基础战力 / 4,
			"防御": 基础战力 / 6,
			"速度": 55,
			"暴击率": 0.15,
			"闪避率": 0.08,
			"五行属性": 主属性,
			"职业": "精英",
			"是精英": true
		})
	else:
		# 普通层：2-3个普通怪
		var 怪物数: int = 2 + (当前层 % 2)
		for i in range(怪物数):
			怪物列表.append({
				"名称": "%s系守卫%d" % [主属性, i + 1],
				"气血": 基础战力 * 5,
				"攻击": 基础战力 / 5,
				"防御": 基础战力 / 8,
				"速度": 50,
				"暴击率": 0.1,
				"闪避率": 0.05,
				"五行属性": 主属性,
				"职业": "守卫"
			})
	return 怪物列表

## 计算秘境层奖励
func _计算秘境层奖励(秘境ID: String, 当前层: int, 总层数: int) -> Dictionary:
	var 奖励: Dictionary = {"灵石": 0, "悟道点": 0, "材料": []}
	var 基础灵石: int = 100 + 当前层 * 50
	var 基础悟道点: int = 10 + 当前层 * 5
	if 秘境ID == "secret_002":
		基础灵石 *= 2
		基础悟道点 *= 2
	elif 秘境ID == "secret_003":
		基础灵石 *= 3
		基础悟道点 *= 3
	elif 秘境ID == "secret_004":
		基础灵石 *= 4
		基础悟道点 *= 4
	# BOSS层额外奖励
	if 当前层 == 总层数:
		基础灵石 *= 2
		基础悟道点 *= 2
		# 随机材料
		var 材料列表: Array = ["灵晶", "玄晶", "圣晶", "百年玄铁", "千年玄铁", "万年玄铁"]
		var 随机材料: String = 材料列表[randi() % 材料列表.size()]
		奖励["材料"].append(随机材料)
		# 妖兽材料掉落（修真世界观：击杀BOSS妖兽，按境界掉落对应等阶的内丹/精血/骨/皮/筋/爪/毛）
		var 秘境妖兽境界: String = "练气"
		match 秘境ID:
			"secret_001": 秘境妖兽境界 = "筑基" if randf() < 0.3 else "练气"
			"secret_002": 秘境妖兽境界 = "金丹" if randf() < 0.3 else "筑基"
			"secret_003": 秘境妖兽境界 = "元婴" if randf() < 0.3 else "金丹"
			"secret_004": 秘境妖兽境界 = "化神" if randf() < 0.3 else "元婴"
		var 掉落结果: Dictionary = 击杀妖兽掉落(秘境妖兽境界)
		if 掉落结果.get("成功", false):
			var 等阶: String = 掉落结果.get("等阶", "一阶")
			var d: Dictionary = 掉落结果.get("掉落", {})
			if int(d.get("内丹", 0)) > 0:
				奖励["材料"].append("%s妖兽内丹" % 等阶)
			if int(d.get("精血", 0)) > 0:
				奖励["材料"].append("%s妖兽精血" % 等阶)
			if int(d.get("骨", 0)) > 0:
				奖励["材料"].append("%s妖兽骨" % 等阶)
			if int(d.get("皮", 0)) > 0:
				奖励["材料"].append("%s妖兽皮" % 等阶)
			if int(d.get("筋", 0)) > 0:
				奖励["材料"].append("%s妖兽筋" % 等阶)
			if int(d.get("爪", 0)) > 0:
				奖励["材料"].append("%s妖兽爪" % 等阶)
			if int(d.get("毛", 0)) > 0:
				奖励["材料"].append("%s妖兽毛" % 等阶)
	# 普通层也有小概率掉落低阶内丹
	else:
		if randf() < 0.1:
			var 普通层境界: String = "练气"
			match 秘境ID:
				"secret_001": 普通层境界 = "练气"
				"secret_002": 普通层境界 = "筑基"
				"secret_003": 普通层境界 = "金丹"
				"secret_004": 普通层境界 = "元婴"
			增加妖兽材料(普通层境界, 1, 0)
	奖励["灵石"] = 基础灵石
	奖励["悟道点"] = 基础悟道点
	return 奖励

# ============ P2 弟子AI行为权重系统（area_stay_weight.csv接入） ============
var _弟子行为权重配置: Array = []
var _弟子行为权重已加载: bool = false
# 性格中文→配置ID映射
const _性格ID映射: Dictionary = {
	"沉稳守道": "p_steady", "锐意争先": "p_impulse", "恬淡悟道": "p_detach",
	"桀骜不羁": "p_impulse", "仁心济世": "p_benevolent", "杀伐果断": "p_impulse",
	"勤勉": "p_diligent", "慵懒": "p_lazy", "沉稳": "p_steady", "急躁": "p_impulse",
	"淡泊": "p_detach", "仁厚": "p_benevolent"
}
# 道途中→配置ID映射
const _道途ID映射: Dictionary = {
	"道修": "pa_sword", "体修": "pa_sword", "法修": "pa_array",
	"御兽师": "pa_forge", "符箓师": "pa_talis", "毒师": "pa_pill", "傀儡师": "pa_forge"
}
# 默认区域权重（无匹配配置时使用）
const _默认区域权重: Dictionary = {
	"灵田": 0.1, "丹殿": 0.2, "演武场": 0.2, "山门": 0.1, "公共区": 0.4
}

## 加载弟子行为权重配置
func _加载弟子行为权重配置() -> void:
	if _弟子行为权重已加载:
		return
	_弟子行为权重已加载 = true
	var 路径: String = "res://config/area_stay_weight.csv"
	var 文件: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		return
	var 表头: Array = 文件.get_csv_line()
	while not 文件.eof_reached():
		var 行: Array = 文件.get_csv_line()
		if 行.size() < 表头.size() or 行[0] == "":
			continue
		var 配置: Dictionary = {}
		for i in range(表头.size()):
			配置[str(表头[i])] = 行[i] if i < 行.size() else ""
		_弟子行为权重配置.append(配置)
	文件.close()

## 获取弟子区域偏好（根据性格×道途）
func 获取弟子区域偏好(弟子: Disciple) -> Dictionary:
	_加载弟子行为权重配置()
	if 弟子 == null:
		return _默认区域权重.duplicate()
	var 性格ID: String = _性格ID映射.get(弟子.性格, "")
	var 道途ID: String = _道途ID映射.get(弟子.道途, "")
	# 精确匹配性格×道途
	for cfg in _弟子行为权重配置:
		if str(cfg.get("personality_id", "")) == 性格ID and str(cfg.get("path_id", "")) == 道途ID:
			return {
				"灵田": float(cfg.get("lingtian_weight", 0.1)),
				"丹殿": float(cfg.get("danfang_weight", 0.2)),
				"演武场": float(cfg.get("yanwuchang_weight", 0.2)),
				"山门": float(cfg.get("shanmen_weight", 0.1)),
				"公共区": float(cfg.get("public_weight", 0.4))
			}
	# 只匹配性格
	for cfg in _弟子行为权重配置:
		if str(cfg.get("personality_id", "")) == 性格ID:
			return {
				"灵田": float(cfg.get("lingtian_weight", 0.1)),
				"丹殿": float(cfg.get("danfang_weight", 0.2)),
				"演武场": float(cfg.get("yanwuchang_weight", 0.2)),
				"山门": float(cfg.get("shanmen_weight", 0.1)),
				"公共区": float(cfg.get("public_weight", 0.4))
			}
	# 无匹配，使用默认
	return _默认区域权重.duplicate()

## 获取弟子本月活动区域（根据权重随机选择）
func 获取弟子本月活动区域(弟子: Disciple) -> String:
	var 权重: Dictionary = 获取弟子区域偏好(弟子)
	var 总权重: float = 0.0
	for v in 权重.values():
		总权重 += float(v)
	if 总权重 <= 0:
		return "公共区"
	var 随机值: float = randf() * 总权重
	var 累计: float = 0.0
	for 区域 in 权重.keys():
		累计 += float(权重[区域])
		if 随机值 <= 累计:
			return str(区域)
	return "公共区"

## 弟子行为修炼加成（公共区权重越高，修炼速度略快，上限3%）
func 获取弟子行为修炼加成(弟子: Disciple) -> float:
	var 权重: Dictionary = 获取弟子区域偏好(弟子)
	var 公共区权重: float = float(权重.get("公共区", 0.4))
	# 公共区权重0.4→0%加成，0.6→3%加成，线性映射
	var 加成: float = clamp((公共区权重 - 0.4) * 0.15, 0.0, 0.03)
	return 加成

# ============ P2 NPC系统（npc_config.csv接入） ============
var _NPC配置缓存: Array = []
var _NPC配置已加载: bool = false
# 阵营ID→中文名映射
const _阵营名映射: Dictionary = {
	"fz_zhengdao": "正道盟", "fz_zhongli": "同盟会", "fz_danqi": "丹器公会",
	"fz_mo": "魔宗", "fz_yaozu": "妖族古族", "neutral": "中立/宗门"
}

## 加载NPC配置
func _加载NPC配置() -> void:
	if _NPC配置已加载:
		return
	_NPC配置已加载 = true
	var 路径: String = "res://config/npc_config.csv"
	var 文件: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		return
	var 表头: Array = 文件.get_csv_line()
	while not 文件.eof_reached():
		var 行: Array = 文件.get_csv_line()
		if 行.size() < 表头.size() or 行[0] == "":
			continue
		var NPC: Dictionary = {}
		for i in range(表头.size()):
			NPC[str(表头[i])] = 行[i] if i < 行.size() else ""
		_NPC配置缓存.append(NPC)
	文件.close()

## 获取所有阵营NPC列表（按阵营分组，含解锁状态）
func 获取所有阵营NPC列表() -> Dictionary:
	_加载NPC配置()
	var 结果: Dictionary = {}
	for NPC in _NPC配置缓存:
		var 阵营ID: String = str(NPC.get("faction_id", "neutral"))
		var 阵营名: String = _阵营名映射.get(阵营ID, 阵营ID)
		if not 结果.has(阵营名):
			结果[阵营名] = []
		var NPCID: String = str(NPC.get("npc_id", ""))
		var 名称: String = str(NPC.get("npc_name", ""))
		var 身份: String = str(NPC.get("identity", ""))
		var 核心功能: String = str(NPC.get("core_function", ""))
		var 解锁说明: String = str(NPC.get("rep_unlock_note", ""))
		# 判断解锁状态（中立NPC默认解锁，阵营NPC根据声望判断）
		var 已解锁: bool = true
		var 解锁提示: String = "常驻"
		if 阵营ID != "neutral":
			var 声望值: int = int(阵营声望系统.阵营声望.get(阵营ID, 0))
			if "崇拜" in 解锁说明:
				已解锁 = 声望值 >= 10000
				解锁提示 = "需阵营声望崇拜（10000）"
			elif "尊敬" in 解锁说明:
				已解锁 = 声望值 >= 5000
				解锁提示 = "需阵营声望尊敬（5000）"
			elif "友善" in 解锁说明:
				已解锁 = 声望值 >= 1000
				解锁提示 = "需阵营声望友善（1000）"
		结果[阵营名].append({
			"npc_id": NPCID,
			"名称": 名称,
			"身份": 身份,
			"核心功能": 核心功能,
			"解锁说明": 解锁说明,
			"解锁提示": 解锁提示,
			"已解锁": 已解锁,
			"阵营ID": 阵营ID
		})
	return 结果

## 获取指定阵营的NPC列表
func 获取阵营NPC列表(阵营ID: String) -> Array:
	var 全部: Dictionary = 获取所有阵营NPC列表()
	var 阵营名: String = _阵营名映射.get(阵营ID, 阵营ID)
	return 全部.get(阵营名, [])

# ============ 派系与权力斗争系统 P0：基础框架 ============

# ===== 派系与权力斗争系统（已拆分到faction_system.gd，此处为转发函数）=====
func _识别派系():
	派系系统._识别派系()
func _判断派系类型(成员列表: Array):
	return 派系系统._判断派系类型(成员列表)
func _生成派系名称(类型: String, 领袖: Disciple):
	return 派系系统._生成派系名称(类型, 领袖)
func _计算派系团结度(成员列表: Array):
	return 派系系统._计算派系团结度(成员列表)
func _计算派系影响力(派系: Dictionary):
	return 派系系统._计算派系影响力(派系)
func _计算派系关系():
	派系系统._计算派系关系()
func _计算派系满意度(派系: Dictionary):
	return 派系系统._计算派系满意度(派系)
func _月度派系更新():
	派系系统._月度派系更新()
func 获取派系列表():
	return 派系系统.获取派系列表()
func 获取派系详情(派系ID: String):
	return 派系系统.获取派系详情(派系ID)
func 获取派系成员详情(派系ID: String):
	return 派系系统.获取派系成员详情(派系ID)
func 获取弟子所属派系(弟子ID: String):
	return 派系系统.获取弟子所属派系(弟子ID)
func _检查职位空缺():
	派系系统._检查职位空缺()
func 宗主钦命职位(弟子ID: String, 职位: String):
	return 派系系统.宗主钦命职位(弟子ID, 职位)
func 设置资源分配(派系ID: String, 比例: float):
	return 派系系统.设置资源分配(派系ID, 比例)
func _月度资源分配检查():
	派系系统._月度资源分配检查()
func 制定宗门政策(政策名: String, 持续日: int = 365):
	return 派系系统.制定宗门政策(政策名, 持续日)
func _月度政策检查():
	派系系统._月度政策检查()
func _检查宗门内斗():
	派系系统._检查宗门内斗()
func _触发宗门内斗(派系: Dictionary, 严重程度: String):
	派系系统._触发宗门内斗(派系, 严重程度)
func 调解宗门内斗(冲突ID: String):
	return 派系系统.调解宗门内斗(冲突ID)
func _月度权力斗争推演():
	派系系统._月度权力斗争推演()
func 获取职位空缺列表():
	return 派系系统.获取职位空缺列表()
func 获取宗门内斗列表():
	return 派系系统.获取宗门内斗列表()
func 获取宗门政策列表():
	return 派系系统.获取宗门政策列表()
func 取消宗门政策(政策名: String):
	return 派系系统.取消宗门政策(政策名)
func 培养心腹(弟子ID: String):
	return 派系系统.培养心腹(弟子ID)
func 提升心腹等级(弟子ID: String):
	return 派系系统.提升心腹等级(弟子ID)
func _月度心腹培养():
	派系系统._月度心腹培养()
func 拉拢派系成员(弟子ID: String):
	return 派系系统.拉拢派系成员(弟子ID)
func 离间派系成员(弟子ID1: String, 弟子ID2: String):
	return 派系系统.离间派系成员(弟子ID1, 弟子ID2)
func 人事调动(弟子ID: String, 调动类型: String, 新职位: String = ""):
	return 派系系统.人事调动(弟子ID, 调动类型, 新职位)
func 促成派系联盟(派系ID1: String, 派系ID2: String):
	return 派系系统.促成派系联盟(派系ID1, 派系ID2)
func 挑起派系对抗(派系ID1: String, 派系ID2: String):
	return 派系系统.挑起派系对抗(派系ID1, 派系ID2)
func _月度玩家管理推演():
	派系系统._月度玩家管理推演()
func 获取心腹列表():
	return 派系系统.获取心腹列表()
func 获取派系联盟列表():
	return 派系系统.获取派系联盟列表()
func 获取派系对抗列表():
	return 派系系统.获取派系对抗列表()
func 获取人事调动记录():
	return 派系系统.获取人事调动记录()
func _触发派系政变(派系: Dictionary):
	派系系统._触发派系政变(派系)
func _触发暗杀事件(派系: Dictionary):
	派系系统._触发暗杀事件(派系)
func _触发叛出宗门(派系: Dictionary):
	派系系统._触发叛出宗门(派系)
func _触发派系合作(派系1: Dictionary, 派系2: Dictionary):
	派系系统._触发派系合作(派系1, 派系2)
func _触发弟子冲突():
	派系系统._触发弟子冲突()
func _触发领袖更替(派系: Dictionary):
	派系系统._触发领袖更替(派系)
func _月度派系事件触发():
	派系系统._月度派系事件触发()
func 获取派系事件记录(类型: String = "", 限制: int = 20):
	return 派系系统.获取派系事件记录(类型, 限制)
func 获取派系斗争编年史():
	return 派系系统.获取派系斗争编年史()
func _月度炼丹派系争夺():
	派系系统._月度炼丹派系争夺()
func _月度历练派系争夺():
	派系系统._月度历练派系争夺()
func _月度家族派系联动():
	派系系统._月度家族派系联动()
func _月度拍卖行派系影响():
	派系系统._月度拍卖行派系影响()
func _月度派系系统融入():
	派系系统._月度派系系统融入()
func 获取炼丹派系争夺记录():
	return 派系系统.获取炼丹派系争夺记录()
func 获取历练派系争夺记录():
	return 派系系统.获取历练派系争夺记录()
func 获取家族派系联动记录():
	return 派系系统.获取家族派系联动记录()
func 获取拍卖行派系影响记录():
	return 派系系统.获取拍卖行派系影响记录()

# ============ 拟真NPC系统 P0-7：关联反应系统 ============
## 弟子叛逃连锁反应
func _弟子叛逃连锁反应(叛逃弟子: Disciple) -> void:
	if 叛逃弟子 == null:
		return
	var 反应记录: Array = []
	
	# 1. 道侣反应
	if 叛逃弟子.道侣 != "":
		var 道侣: Disciple = _按姓名找弟子(叛逃弟子.道侣)
		if 道侣 != null:
			var 随机: float = randf()
			if 随机 < 0.3:
				# 30%跟随叛逃
				道侣.状态 = "叛逃"
				反应记录.append("%s跟随道侣%s叛逃" % [道侣.姓名, 叛逃弟子.姓名])
			elif 随机 < 0.8:
				# 50%留下但悲伤
				道侣.触发情绪("悲伤", 7)
				道侣.心境 = max(0, 道侣.心境 - 10)
				道侣.增加好感度(str(叛逃弟子.弟子ID), -30)
				反应记录.append("%s因道侣%s叛逃而悲伤" % [道侣.姓名, 叛逃弟子.姓名])
			else:
				# 20%愤怒
				道侣.触发情绪("愤怒", 3)
				道侣.增加好感度(str(叛逃弟子.弟子ID), -50)
				反应记录.append("%s因道侣%s叛逃而愤怒" % [道侣.姓名, 叛逃弟子.姓名])
	
	# 2. 子嗣反应
	for 子嗣 in 通婚子嗣系统.子嗣列表:
		if str(子嗣.get("父方ID", "")) == str(叛逃弟子.弟子ID) or str(子嗣.get("母方ID", "")) == str(叛逃弟子.弟子ID):
			var 子嗣年龄: int = int(子嗣.get("年龄", 0))
			var 子嗣弟子: Disciple = _按ID找弟子(str(子嗣.get("子嗣ID", "")))
			if 子嗣弟子 == null:
				continue
			if 子嗣年龄 < 15:
				# 未成年跟随叛逃
				子嗣弟子.状态 = "叛逃"
				反应记录.append("%s（未成年子嗣）跟随父/母%s叛逃" % [子嗣弟子.姓名, 叛逃弟子.姓名])
			else:
				var 随机: float = randf()
				if 随机 < 0.2:
					# 20%跟随叛逃
					子嗣弟子.状态 = "叛逃"
					反应记录.append("%s（子嗣）跟随父/母%s叛逃" % [子嗣弟子.姓名, 叛逃弟子.姓名])
				elif 随机 < 0.7:
					# 50%留下但心境下降
					子嗣弟子.心境 = max(0, 子嗣弟子.心境 - 10)
					子嗣弟子.触发情绪("悲伤", 5)
					反应记录.append("%s（子嗣）因父/母%s叛逃而心境受损" % [子嗣弟子.姓名, 叛逃弟子.姓名])
				else:
					# 30%愤怒
					子嗣弟子.触发情绪("愤怒", 3)
					子嗣弟子.增加好感度(str(叛逃弟子.弟子ID), -30)
					反应记录.append("%s（子嗣）因父/母%s叛逃而愤怒" % [子嗣弟子.姓名, 叛逃弟子.姓名])
	
	# 3. 道友反应
	for 道友 in 叛逃弟子.道友列表:
		var 道友ID: String = str(道友.get("弟子ID", ""))
		var 道友弟子: Disciple = _按ID找弟子(道友ID)
		if 道友弟子 == null or 道友弟子.状态 != "在宗":
			continue
		var 随机: float = randf()
		if 随机 < 0.2:
			# 20%跟随叛逃
			道友弟子.状态 = "叛逃"
			反应记录.append("%s（道友）跟随%s叛逃" % [道友弟子.姓名, 叛逃弟子.姓名])
		elif 随机 < 0.7:
			# 50%好感度大幅下降
			道友弟子.增加好感度(str(叛逃弟子.弟子ID), -20)
			道友弟子.心境 = max(0, 道友弟子.心境 - 5)
			反应记录.append("%s（道友）因%s叛逃而好感度下降" % [道友弟子.姓名, 叛逃弟子.姓名])
		else:
			# 30%心境受损
			道友弟子.心境 = max(0, 道友弟子.心境 - 5)
			反应记录.append("%s（道友）因%s叛逃而心境受损" % [道友弟子.姓名, 叛逃弟子.姓名])
	
	# 4. 好友反应（好感度>60）
	for d in 弟子列表:
		if d == null or not (d is Disciple) or d.状态 != "在宗":
			continue
		if d.弟子ID == 叛逃弟子.弟子ID:
			continue
		var 好感度: int = d.获取好感度(str(叛逃弟子.弟子ID))
		if 好感度 > 60 and randf() < 0.8:
			d.增加好感度(str(叛逃弟子.弟子ID), -10)
			d.心境 = max(0, d.心境 - 3)
			反应记录.append("%s（好友）因%s叛逃而心境受损" % [d.姓名, 叛逃弟子.姓名])
		elif 好感度 < 20 and randf() < 0.5:
			# 仇人幸灾乐祸
			d.增加好感度(str(叛逃弟子.弟子ID), 5)
			d.触发情绪("喜悦", 1)
			反应记录.append("%s（仇人）因%s叛逃而幸灾乐祸" % [d.姓名, 叛逃弟子.姓名])
	
	# 记录推演条目
	for 记录 in 反应记录:
		_加推演条目("◇ " + str(记录), "叛逃余波", "中")

## 弟子死亡连锁反应
func _弟子死亡连锁反应(死亡弟子: Disciple) -> void:
	if 死亡弟子 == null:
		return
	var 反应记录: Array = []
	
	# 1. 道侣反应
	if 死亡弟子.道侣 != "":
		var 道侣: Disciple = _按姓名找弟子(死亡弟子.道侣)
		if 道侣 != null and 道侣.状态 == "在宗":
			道侣.触发情绪("悲伤", 14)
			道侣.心境 = max(0, 道侣.心境 - 15)
			反应记录.append("%s因道侣%s离世而悲痛欲绝" % [道侣.姓名, 死亡弟子.姓名])
	
	# 2. 子嗣反应
	for 子嗣 in 通婚子嗣系统.子嗣列表:
		if str(子嗣.get("父方ID", "")) == str(死亡弟子.弟子ID) or str(子嗣.get("母方ID", "")) == str(死亡弟子.弟子ID):
			var 子嗣弟子: Disciple = _按ID找弟子(str(子嗣.get("子嗣ID", "")))
			if 子嗣弟子 != null and 子嗣弟子.状态 == "在宗":
				子嗣弟子.触发情绪("悲伤", 7)
				子嗣弟子.心境 = max(0, 子嗣弟子.心境 - 10)
				反应记录.append("%s因父/母%s离世而悲伤" % [子嗣弟子.姓名, 死亡弟子.姓名])
	
	# 3. 道友反应
	for 道友 in 死亡弟子.道友列表:
		var 道友弟子: Disciple = _按ID找弟子(str(道友.get("弟子ID", "")))
		if 道友弟子 != null and 道友弟子.状态 == "在宗":
			道友弟子.触发情绪("悲伤", 3)
			道友弟子.心境 = max(0, 道友弟子.心境 - 5)
			反应记录.append("%s（道友）因%s离世而悲伤" % [道友弟子.姓名, 死亡弟子.姓名])
	
	# 4. 好友/仇人反应
	for d in 弟子列表:
		if d == null or not (d is Disciple) or d.状态 != "在宗":
			continue
		var 好感度: int = d.获取好感度(str(死亡弟子.弟子ID))
		if 好感度 > 60 and randf() < 0.5:
			d.触发情绪("悲伤", 1)
			d.心境 = max(0, d.心境 - 3)
		elif 好感度 < 20 and randf() < 0.5:
			d.触发情绪("喜悦", 3)
			d.增加好感度(str(死亡弟子.弟子ID), 10)
	
	for 记录 in 反应记录:
		_加推演条目("◇ " + str(记录), "身故余波", "中")

## 化解弟子走火入魔（后端完整，UI零调用→此处封装供UI调用）
## 方式：闭关（30%+道心加成）、丹药（60%，需清心丹）、佛法（80%，需佛门功法）
func 化解走火入魔(弟子ID: int, 方式: String = "闭关") -> Dictionary:
	var 目标弟子 = null
	for d in 弟子列表:
		if d != null and d.弟子ID == 弟子ID:
			目标弟子 = d
			break
	if 目标弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if not 目标弟子.是否走火入魔():
		return {"成功": false, "原因": "弟子未走火入魔"}
	var 结果: Dictionary = 目标弟子.化解走火入魔(方式)
	if 结果.get("成功", false):
		添加纪事("庶务", "化解走火入魔", "%s通过%s化解走火入魔！" % [目标弟子.姓名, 方式], 2)
	else:
		添加纪事("庶务", "化解走火入魔", "%s化解走火入魔失败，仍需休养。" % 目标弟子.姓名, 1)
	return 结果

## 宗门大比/论剑大会（每年举办一次，弟子自动报名，按境界分组淘汰赛）
var 宗门大比倒计时: int = 360  # 距离下次宗门大比的天数（每年一次）
var 宗门大比记录: Array = []  # 历届宗门大比记录

## 月度推进：宗门大比倒计时
func _宗门大比月度推进(月: float) -> void:
	宗门大比倒计时 -= int(月 * 30)
	if 宗门大比倒计时 <= 0:
		举办宗门大比()
		宗门大比倒计时 = 360

## 举办宗门大比
func 举办宗门大比() -> void:
	if 弟子列表.size() < 4:
		添加纪事("庶务", "宗门大比", "宗门弟子不足4人，本届宗门大比取消。", 1)
		return
	# 按境界分组
	var 分组: Dictionary = {}
	for d in 弟子列表:
		if d == null or str(d.状态) != "在宗":
			continue
		var 境: String = str(d.境界)
		if not 分组.has(境):
			分组[境] = []
		分组[境].append(d)
	# 每个境界组进行淘汰赛
	var 总冠军: String = ""
	var 总战力: int = 0
	for 境 in 分组.keys():
		var 选手: Array = 分组[境]
		if 选手.size() < 2:
			continue
		# 随机配对战斗（简化版：战力高者胜，有10%爆冷）
		选手.sort_custom(func(a, b): return a.总战力() > b.总战力())
		var 冠军 = 选手[0]
		var 亚军 = 选手[1] if 选手.size() > 1 else null
		# 10%概率爆冷
		if randf() < 0.1 and 亚军 != null:
			var 临时 = 冠军
			冠军 = 亚军
			亚军 = 临时
		# 奖励
		贡献点 += 50
		if 冠军 != null:
			冠军.增加心境(5)
			添加纪事("庶务", "宗门大比", "%s组冠军：%s（道行%d）！获得50贡献点+心境+5。" % [境, 冠军.姓名, 冠军.总战力()], 2)
			if 冠军.总战力() > 总战力:
				总战力 = 冠军.总战力()
				总冠军 = 冠军.姓名
		if 亚军 != null:
			亚军.增加心境(2)
	# 宗门声望提升
	声望 += 5
	添加纪事("庶务", "宗门大比", "本届宗门大比圆满结束！总冠军：%s。宗门声望+5。" % 总冠军, 3)
	宗门大比记录.append({"年份": int(累计游戏日 / 360.0), "总冠军": 总冠军, "总战力": 总战力})

# ============ 散修招募系统（修真世界观：游历散修来访，可招募入宗）============
# 月度有概率有散修来访，玩家可以选择招募或拒绝
# 散修品质随机，招募后成为宗门弟子
var 来访散修: Array = []  # 当前来访的散修列表 [{名称, 境界, 资质, 灵根, 战力, 来访日, 要求}]
var 散修来访冷却: int = 0  # 距离下次散修来访的天数

## 月度推进：散修来访
func _散修来访月度推进(月: float) -> void:
	散修来访冷却 -= int(月 * 30)
	if 散修来访冷却 <= 0 and 来访散修.size() < 3:
		# 20%概率有散修来访
		if randf() < 0.2:
			_生成来访散修()
			散修来访冷却 = 90  # 下次来访至少90游戏日后

## 生成来访散修
func _生成来访散修() -> void:
	# 随机生成散修属性
	var 姓名池: Array = ["青云子", "玄真子", "清风道人", "明月散人", "赤霞真人", "寒江客", "孤云野鹤", "天涯过客", "醉仙翁", "墨衣行者"]
	var 资质列表: Array = ["凡俗", "平庸", "优良", "天才", "妖孽"]
	var 灵根列表: Array = ["天灵根", "变异灵根", "五行灵根", "四灵根", "三灵根"]
	var 境界列表: Array = ["练气", "筑基", "金丹", "元婴"]
	var 散修: Dictionary = {
		"名称": 姓名池[randi() % 姓名池.size()],
		"境界": 境界列表[randi() % min(4, 门派等级)],
		"资质": 资质列表[randi() % min(5, 门派等级 + 1)],
		"灵根": 灵根列表[randi() % 5],
		"战力": 100 + randi() % 500,
		"来访日": 累计游戏日,
		"要求": 100 + randi() % 500  # 招募要求的灵石
	}
	来访散修.append(散修)
	添加纪事("庶务", "散修来访", "散修%s来访宗门，境界%s，资质%s。" % [散修["名称"], 散修["境界"], 散修["资质"]], 1)
	_加推演条目("【散修来访】散修%s游历至太玄宗，境界%s，资质%s，可招募入宗。" % [散修["名称"], 散修["境界"], 散修["资质"]], ET_SECT, PRIO_NORMAL, {})

## 获取来访散修列表
func 获取来访散修() -> Array:
	# 新档保底：月度来访仅 20% 概率且冷却 90 日，开宗头几天「招贤纳士」几乎必为空页，
	# 玩家会以为该功能未实装 ⇒ 开局阶段列表空则直接引一位散修上门。
	if 来访散修.is_empty() and 累计游戏日 <= 3:
		_生成来访散修()
	# 清理超过30天未招募的散修
	var 有效散修: Array = []
	for 散修 in 来访散修:
		if 累计游戏日 - int(散修.get("来访日", 0)) <= 30:
			有效散修.append(散修)
	来访散修 = 有效散修
	return 来访散修

## 招募散修
func 招募散修(散修名称: String) -> Dictionary:
	var 目标散修: Dictionary = {}
	for 散修 in 来访散修:
		if str(散修.get("名称", "")) == 散修名称:
			目标散修 = 散修
			break
	if 目标散修.is_empty():
		return {"成功": false, "原因": "该散修已离开"}
	# 检查灵石
	var 要求灵石: int = int(目标散修.get("要求", 100))
	if 灵石 < 要求灵石:
		return {"成功": false, "原因": "灵石不足，招募需%d灵石" % 要求灵石}
	# 检查弟子上限
	if 弟子列表.size() >= 宗门编制上限():
		return {"成功": false, "原因": "宗门弟子已满"}
	灵石 -= 要求灵石
	# 创建弟子
	var 新弟子 = Disciple.new()
	新弟子.姓名 = str(目标散修.get("名称", ""))
	新弟子.境界 = str(目标散修.get("境界", "练气"))
	新弟子.资质 = str(目标散修.get("资质", "平庸"))
	新弟子.灵根 = str(目标散修.get("灵根", "五行灵根"))
	新弟子.状态 = "在宗"
	新弟子.忠诚 = 60  # 散修初始忠诚60
	新弟子.年龄 = 20 + randi() % 30
	弟子列表.append(新弟子)
	# 从来访列表移除
	来访散修.erase(目标散修)
	添加纪事("庶务", "招募散修", "散修%s加入太玄宗，境界%s，资质%s。" % [新弟子.姓名, 新弟子.境界, 新弟子.资质], 2)
	_加推演条目("【招募散修】散修%s仰慕太玄宗威名，正式加入宗门。" % 新弟子.姓名, ET_SECT, PRIO_NORMAL, {})
	return {"成功": true, "弟子": 新弟子.姓名}

## 拒绝散修
func 拒绝散修(散修名称: String) -> void:
	for 散修 in 来访散修:
		if str(散修.get("名称", "")) == 散修名称:
			来访散修.erase(散修)
			添加纪事("庶务", "拒绝散修", "散修%s被宗门拒绝，继续游历天下。" % 散修名称, 1)
			break

# ============ 宗门外交系统（修真世界观：宗门间结盟/联姻/宣战）============
# 简化版：显示友好/敌对宗门，可结盟/宣战
var 宗门关系: Dictionary = {}  # {宗门名: {关系: 友好/中立/敌对, 好感度: 0-100}}
var 已知宗门: Array = ["青云宗", "丹霞派", "万剑门", "合欢宗", "血煞门", "幽冥教"]  # 已知宗门列表

## 初始化宗门关系
func _初始化宗门关系() -> void:
	for 宗门 in 已知宗门:
		if not 宗门关系.has(宗门):
			宗门关系[宗门] = {"关系": "中立", "好感度": 50}

## 登记宗门关系（P2-3.1：供世界大地图把「遭遇的宗门」登记进外交表，初始好感由来源方按实力给定）
func 登记宗门关系(宗门名: String, 初始好感: int = 50) -> void:
	if 宗门名.is_empty():
		return
	if not 宗门关系.has(宗门名):
		宗门关系[宗门名] = {"关系": "中立", "好感度": clampi(初始好感, 0, 100)}

## 获取宗门关系列表
func 获取宗门关系列表() -> Array:
	_初始化宗门关系()
	var 结果: Array = []
	for 宗门 in 宗门关系.keys():
		var 关系: Dictionary = 宗门关系[宗门]
		结果.append({"宗门": 宗门, "关系": 关系.get("关系", "中立"), "好感度": int(关系.get("好感度", 50))})
	return 结果

## 与宗门结盟
func 与宗门结盟(宗门名: String) -> Dictionary:
	_初始化宗门关系()
	if not 宗门关系.has(宗门名):
		return {"成功": false, "原因": "未知宗门"}
	var 关系: Dictionary = 宗门关系[宗门名]
	if int(关系.get("好感度", 0)) < 70:
		return {"成功": false, "原因": "好感度不足（需>=70），当前%d" % int(关系.get("好感度", 0))}
	if str(关系.get("关系", "")) == "敌对":
		return {"成功": false, "原因": "与该宗门处于敌对状态"}
	# 消耗灵石
	var 消耗灵石: int = 1000 * max(1, 门派等级)
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足，结盟需%d灵石" % 消耗灵石}
	灵石 -= 消耗灵石
	关系["关系"] = "友好"
	关系["好感度"] = min(100, int(关系.get("好感度", 0)) + 20)
	宗门关系[宗门名] = 关系
	添加纪事("外交", "宗门结盟", "太玄宗与%s结为友好宗门，守望相助。" % 宗门名, 2)
	_加推演条目("【宗门结盟】太玄宗与%s正式结盟，双方守望相助，共抗魔道。" % 宗门名, ET_SECT, PRIO_HIGH, {})
	return {"成功": true, "效果": "与%s结为友好宗门" % 宗门名}

## 与宗门宣战
func 与宗门宣战(宗门名: String) -> Dictionary:
	_初始化宗门关系()
	if not 宗门关系.has(宗门名):
		return {"成功": false, "原因": "未知宗门"}
	var 关系: Dictionary = 宗门关系[宗门名]
	if str(关系.get("关系", "")) == "敌对":
		return {"成功": false, "原因": "已与该宗门处于敌对状态"}
	关系["关系"] = "敌对"
	关系["好感度"] = max(0, int(关系.get("好感度", 0)) - 30)
	宗门关系[宗门名] = 关系
	添加纪事("外交", "宗门宣战", "太玄宗向%s宣战，双方势不两立！" % 宗门名, 3)
	_加推演条目("【宗门宣战】太玄宗正式向%s宣战，宗门大战一触即发！" % 宗门名, ET_SECT, PRIO_HIGH, {})
	return {"成功": true, "效果": "与%s进入敌对状态" % 宗门名}

## 月度推进：宗门关系自然变化
func _宗门关系月度推进(月: float) -> void:
	_初始化宗门关系()
	for 宗门 in 宗门关系.keys():
		var 关系: Dictionary = 宗门关系[宗门]
		# 友好关系每月+1好感，敌对关系每月-1好感，中立不变
		if str(关系.get("关系", "")) == "友好":
			关系["好感度"] = min(100, int(关系.get("好感度", 0)) + 1)
		elif str(关系.get("关系", "")) == "敌对":
			关系["好感度"] = max(0, int(关系.get("好感度", 0)) - 1)
		宗门关系[宗门] = 关系

# ============ 邪修来袭系统（修真世界观：魔道邪修觊觎宗门，弟子入魔）============
# 月度有概率触发邪修来袭，弟子迎战，心魔过高弟子有概率入魔
var 邪修来袭冷却: int = 0  # 距离下次邪修来袭的天数
var 历史邪修来袭: Array = []  # 历史邪修来袭记录

## 月度推进：邪修来袭
func _邪修来袭月度推进(月: float) -> void:
	邪修来袭冷却 -= int(月 * 30)
	if 邪修来袭冷却 <= 0:
		# 10%概率触发邪修来袭（宗门等级越高，概率越高）
		var 触发概率: float = 0.05 + float(门派等级) * 0.01
		if randf() < 触发概率:
			_触发邪修来袭()
			邪修来袭冷却 = 180  # 下次来袭至少180游戏日后

## 触发邪修来袭
func _触发邪修来袭() -> void:
	# 邪修实力根据宗门等级
	var 邪修战力: int = 500 + 门派等级 * 200 + randi() % 500
	var 邪修名称: String = ["血煞老祖", "幽冥鬼母", "合欢魔君", "万毒尊者", "噬魂老魔"][randi() % 5]
	# 宗门迎战（取在宗弟子总战力）
	var 宗门总战力: int = 0
	for d in 弟子列表:
		if d != null and d is Disciple and str(d.状态) == "在宗":
			宗门总战力 += int(d.总战力())
	# 战斗结果
	var 结果: String = ""
	if 宗门总战力 >= 邪修战力:
		结果 = "胜利"
		# 奖励：灵石+贡献点
		var 灵石奖励: int = 300 * max(1, 门派等级)
		灵石 += 灵石奖励
		贡献点 += 100
		添加纪事("大事件", "邪修来袭", "%s率邪修来袭，被宗门击退！获灵石%d，贡献点+100。" % [邪修名称, 灵石奖励], 3)
		_加推演条目("【邪修来袭】%s率邪修来袭，宗门弟子齐心协力，将其击退！获灵石%d，贡献点+100。" % [邪修名称, 灵石奖励], ET_SECT, PRIO_HIGH, {})
	else:
		结果 = "失败"
		# 损失：灵石+弟子受伤
		var 灵石损失: int = min(int(灵石 * 0.1), 500 * max(1, 门派等级))
		灵石 = max(0, 灵石 - 灵石损失)
		# 随机弟子受伤
		var 在宗弟子: Array = []
		for d in 弟子列表:
			if d != null and d is Disciple and str(d.状态) == "在宗":
				在宗弟子.append(d)
		if 在宗弟子.size() > 0:
			var 受伤弟子: Disciple = 在宗弟子[randi() % 在宗弟子.size()]
			受伤弟子.受伤剩余 = 30
			添加纪事("大事件", "邪修来袭", "%s率邪修来袭，宗门不敌，损失灵石%d，%s受伤。" % [邪修名称, 灵石损失, 受伤弟子.姓名], 3)
			_加推演条目("【邪修来袭】%s率邪修来袭，宗门不敌，损失灵石%d，%s受伤。宗门需加紧修炼，以报此仇！" % [邪修名称, 灵石损失, 受伤弟子.姓名], ET_SECT, PRIO_HIGH, {})
	历史邪修来袭.append({"游戏日": 累计游戏日, "邪修": 邪修名称, "邪修战力": 邪修战力, "宗门战力": 宗门总战力, "结果": 结果})
	# 检查弟子入魔（心魔>=80的弟子有概率入魔）
	for d in 弟子列表:
		if d != null and d is Disciple and str(d.状态) == "在宗" and int(d.心魔值) >= 80:
			if randf() < 0.1:  # 10%概率入魔
				d.状态 = "入魔"
				添加纪事("大事件", "弟子入魔", "%s心魔难抑，堕入魔道！" % d.姓名, 3)
				_加推演条目("【弟子入魔】%s心魔难抑，堕入魔道，叛出宗门！" % d.姓名, ET_SECT, PRIO_HIGH, {})

# ============ 情劫系统（修真世界观：道侣牵绊·情根深种·影响修炼）============
# 道侣死亡/叛逃时触发情劫，情劫影响修炼速度和突破成功率
# 情劫可以通过时间或特殊物品化解
var 情劫弟子: Array = []  # 正在经历情劫的弟子 [{弟子ID, 情劫日, 情劫强度}]

## 月度推进：情劫系统
func _情劫月度推进(月: float) -> void:
	var 化解列表: Array = []
	for 情劫 in 情劫弟子:
		var 弟子ID: int = int(情劫.get("弟子ID", 0))
		var 情劫日: int = int(情劫.get("情劫日", 0))
		情劫日 += int(月 * 30)
		情劫["情劫日"] = 情劫日
		# 情劫持续180游戏日后自然化解
		if 情劫日 >= 180:
			化解列表.append(情劫)
			# 找到弟子，恢复正常
			for d in 弟子列表:
				if d != null and d is Disciple and int(d.弟子ID) == 弟子ID:
					添加纪事("庶务", "情劫化解", "%s情劫已过，道心重固。" % d.姓名, 1)
					break
	for 情劫 in 化解列表:
		情劫弟子.erase(情劫)

## 触发情劫（道侣死亡/叛逃时调用）
func _触发情劫(弟子: Disciple) -> void:
	if 弟子 == null:
		return
	# 检查是否已经在情劫中
	for 情劫 in 情劫弟子:
		if int(情劫.get("弟子ID", 0)) == int(弟子.弟子ID):
			return
	# 情劫强度根据心境（心境越低，情劫越强）
	var 情劫强度: int = max(1, 10 - int(弟子.心境) / 10)
	情劫弟子.append({"弟子ID": int(弟子.弟子ID), "情劫日": 0, "情劫强度": 情劫强度})
	添加纪事("庶务", "情劫", "%s痛失道侣，情根深种，修炼受阻。" % 弟子.姓名, 2)
	_加推演条目("【情劫】%s痛失道侣，情根深种，道心动摇，修炼受阻。需时日化解。" % 弟子.姓名, ET_SECT, PRIO_NORMAL, {})

## 获取弟子情劫状态
func 获取情劫状态(弟子ID: int) -> Dictionary:
	for 情劫 in 情劫弟子:
		if int(情劫.get("弟子ID", 0)) == 弟子ID:
			return 情劫
	return {}

## 情劫对修炼速度的影响
func 情劫修炼加成(弟子ID: int) -> float:
	var 情劫: Dictionary = 获取情劫状态(弟子ID)
	if 情劫.is_empty():
		return 0.0
	var 强度: int = int(情劫.get("情劫强度", 1))
	var 日: int = int(情劫.get("情劫日", 0))
	# 情劫前90日影响最大，之后逐渐减弱
	var 影响: float = -0.1 * float(强度)
	if 日 > 90:
		影响 *= (1.0 - float(日 - 90) / 90.0)
	return 影响

# ============ 高阶修士进阶系统（神魂+法相+领域）============
# 修真世界观：元婴修神魂，化神凝法相，炼虚辟领域
# 神魂：元婴以上可修炼，影响战力和悟道
# 法相：化神以上可凝聚，提供大量战力加成
# 领域：炼虚以上可开辟，领域内修士获得加成

## 修炼神魂（元婴以上修士可修炼）
func 修炼神魂(弟子: Disciple) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if str(弟子.境界) not in ["元婴", "化神", "炼虚", "合体", "大乘", "渡劫"]:
		return {"成功": false, "原因": "需元婴以上境界才能修炼神魂"}
	if 弟子.神魂等级 >= 9:
		return {"成功": false, "原因": "神魂已达极致（9级）"}
	# 消耗悟道点
	var 消耗悟道: int = 100 * (弟子.神魂等级 + 1)
	if 悟道点 < 消耗悟道:
		return {"成功": false, "原因": "悟道点不足，需%d" % 消耗悟道}
	悟道点 -= 消耗悟道
	# 增加神魂经验
	弟子.神魂经验 += 50
	# 升级判断
	var 升级所需: int = 100 * (弟子.神魂等级 + 1)
	if 弟子.神魂经验 >= 升级所需:
		弟子.神魂经验 = 0
		弟子.神魂等级 += 1
		添加纪事("修炼", "神魂进阶", "%s神魂修炼至%d级，道行+%d%%，悟道+%d%%" % [弟子.姓名, 弟子.神魂等级, 弟子.神魂等级 * 5, 弟子.神魂等级 * 3], 2)
		弟子.计算战力()
		return {"成功": true, "升级": true, "神魂等级": 弟子.神魂等级}
	添加纪事("修炼", "修炼神魂", "%s修炼神魂，修为+50" % 弟子.姓名, 1)
	return {"成功": true, "升级": false, "神魂经验": 弟子.神魂经验}

## 凝聚法相（化神以上修士可凝聚）
func 凝聚法相(弟子: Disciple, 法相名: String = "") -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if str(弟子.境界) not in ["化神", "炼虚", "合体", "大乘", "渡劫"]:
		return {"成功": false, "原因": "需化神以上境界才能凝聚法相"}
	if 弟子.法相等级 >= 9:
		return {"成功": false, "原因": "法相已达极致（9级）"}
	# 消耗灵石和悟道点
	var 消耗灵石: int = 5000 * (弟子.法相等级 + 1)
	var 消耗悟道: int = 200 * (弟子.法相等级 + 1)
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足，需%d" % 消耗灵石}
	if 悟道点 < 消耗悟道:
		return {"成功": false, "原因": "悟道点不足，需%d" % 消耗悟道}
	灵石 -= 消耗灵石
	悟道点 -= 消耗悟道
	# 首次凝聚法相
	if 弟子.法相等级 == 0:
		var 法相名称池: Array = ["金刚法相", "青莲法相", "剑仙法相", "雷霆法相", "烈焰法相", "玄冰法相", "菩提法相", "魔龙法相"]
		弟子.法相名称 = 法相名 if 法相名 != "" else 法相名称池[randi() % 法相名称池.size()]
	弟子.法相等级 += 1
	添加纪事("修炼", "凝聚法相", "%s凝聚%s至%d级，道行+%d%%" % [弟子.姓名, 弟子.法相名称, 弟子.法相等级, 弟子.法相等级 * 10], 2)
	弟子.计算战力()
	return {"成功": true, "法相名称": 弟子.法相名称, "法相等级": 弟子.法相等级}

## 开辟领域（炼虚以上修士可开辟）
func 开辟领域(弟子: Disciple, 领域名: String = "") -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if str(弟子.境界) not in ["炼虚", "合体", "大乘", "渡劫"]:
		return {"成功": false, "原因": "需炼虚以上境界才能开辟领域"}
	if 弟子.领域等级 >= 9:
		return {"成功": false, "原因": "领域已达极致（9级）"}
	# 消耗灵石和悟道点
	var 消耗灵石: int = 10000 * (弟子.领域等级 + 1)
	var 消耗悟道: int = 500 * (弟子.领域等级 + 1)
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足，需%d" % 消耗灵石}
	if 悟道点 < 消耗悟道:
		return {"成功": false, "原因": "悟道点不足，需%d" % 消耗悟道}
	灵石 -= 消耗灵石
	悟道点 -= 消耗悟道
	# 首次开辟领域
	if 弟子.领域等级 == 0:
		var 领域名称池: Array = ["剑之领域", "火之领域", "冰之领域", "雷之领域", "风之领域", "土之领域", "光之领域", "暗之领域"]
		弟子.领域名称 = 领域名 if 领域名 != "" else 领域名称池[randi() % 领域名称池.size()]
	弟子.领域等级 += 1
	添加纪事("修炼", "开辟领域", "%s开辟%s至%d级，道行+%d%%" % [弟子.姓名, 弟子.领域名称, 弟子.领域等级, 弟子.领域等级 * 8], 2)
	弟子.计算战力()
	return {"成功": true, "领域名称": 弟子.领域名称, "领域等级": 弟子.领域等级}

## 获取高阶修士列表（元婴以上）
func 获取高阶修士列表() -> Array:
	var 结果: Array = []
	for d in 弟子列表:
		if d != null and d is Disciple and str(d.状态) == "在宗":
			if str(d.境界) in ["元婴", "化神", "炼虚", "合体", "大乘", "渡劫"]:
				结果.append(d)
	return 结果

## 辈分/字辈谱系（修真味：宗门弟子按入门时间排辈分，道号含辈分字）
## 太玄宗门字辈谱系（共20代，开山祖师为"太"字辈）
const 太玄宗门字辈: Array = [
	"太", "玄", "清", "虚", "无", "极", "道", "灵", "真", "常",
	"明", "悟", "慧", "定", "寂", "照", "妙", "圆", "通", "化"
]
var 当前辈分序: int = 1  # 当前宗门辈分（0=开山，1=第二代，以此类推）

## 获取当前辈分字
func 获取当前辈分字() -> String:
	var idx: int = 当前辈分序 % 太玄宗门字辈.size()
	return 太玄宗门字辈[idx]

## 新弟子入门时分配辈分和道号
func _辈分月度推进(月: float) -> void:
	# 每100年（36000游戏日）晋升一代
	var 总日: int = int(累计游戏日 + 月 * 30)
	var 目标辈分: int = int(总日 / 36000)
	if 目标辈分 > 当前辈分序:
		当前辈分序 = 目标辈分
		添加纪事("庶务", "辈分晋升", "宗门已传承%d代，当前辈分字：%s" % [当前辈分序 + 1, 获取当前辈分字()], 2)

## 占卜/天机系统（修真味：宗主消耗悟道点占卜，预测突破/事件/机缘）
## 占卜类型：突破吉凶、近期事件、机缘方向
var 占卜冷却: int = 0  # 占卜冷却（游戏日）

## 占卜（消耗悟道点，预测未来）
func 占卜(类型: String = "突破吉凶") -> Dictionary:
	if 宗主 == null:
		return {"成功": false, "原因": "宗主未初始化"}
	if 占卜冷却 > 0:
		return {"成功": false, "原因": "天机紊乱，需%d日后再占" % 占卜冷却}
	# 消耗悟道点
	var 消耗: int = 100
	if 悟道点 < 消耗:
		return {"成功": false, "原因": "悟道点不足（需%d）" % 消耗}
	悟道点 -= 消耗
	占卜冷却 = 30  # 30日冷却
	# 占卜准确率（宗主境界+神识影响）
	var 境界序_idx: int = Disciple.境界序.find(str(宗主.境界))
	var 准确率: float = 0.50 + float(境界序_idx) * 0.05 + 宗主.神识生产加成()
	准确率 = clamp(准确率, 0.50, 0.95)
	# 占卜结果
	var 结果: String = ""
	var 准确: bool = randf() < 准确率
	match 类型:
		"突破吉凶":
			# 随机选一个在宗弟子预测突破
			var 在宗: Array = []
			for d in 弟子列表:
				if d != null and str(d.状态) == "在宗" and d.层数 >= 8:
					在宗.append(d)
			if 在宗.is_empty():
				结果 = "宗门暂无弟子临近突破，天机不显。"
			else:
				var 目标 = 在宗[randi() % 在宗.size()]
				var 突破率: float = 目标.突破成功率修正() / 100.0
				if 准确:
					if 突破率 > 0.6:
						结果 = "%s突破可期，大吉之象，成功率约%.0f%%。" % [目标.姓名, 突破率 * 100]
					elif 突破率 > 0.3:
						结果 = "%s突破有阻，需谨慎行事，成功率约%.0f%%。" % [目标.姓名, 突破率 * 100]
					else:
						结果 = "%s突破凶险，心魔扰道，成功率约%.0f%%，建议暂缓。" % [目标.姓名, 突破率 * 100]
				else:
					结果 = "天机模糊，卦象难辨，仅知%s近期有关口。" % 目标.姓名
		"近期事件":
			if 准确:
				var 事件: Array = ["有客来访", "灵草丰收", "矿脉异动", "妖兽出没", "高人路过", "魔道窥伺"]
				结果 = "近期%s，宗门需留意。" % 事件[randi() % 事件.size()]
			else:
				结果 = "近期气运平稳，无大灾亦无大喜。"
		"机缘方向":
			if 准确:
				var 方向: Array = ["东方有灵气汇聚", "南方有火焰异动", "西方有金气冲天", "北方有水汽氤氲", "中央有土德厚载"]
				结果 = "%s，或有机缘。" % 方向[randi() % 方向.size()]
			else:
				结果 = "机缘天定，不可强求，顺其自然即可。"
		_:
			结果 = "未知占卜类型。"
	添加纪事("庶务", "占卜", "宗主占卜【%s】：%s" % [类型, 结果], 1)
	return {"成功": true, "结果": 结果, "准确率": 准确率, "消耗": 消耗}

## 个人洞府/灵田系统（修真味：弟子有个人洞府用于闭关，灵田种植灵草）
## 弟子主动申请洞府（月度推演调用：高境界+高贡献弟子自动申请，宗门有空闲洞府则分配）
func _弟子主动申请洞府() -> void:
	# 检查宗门是否有空闲洞府
	var 已分配: int = 0
	for d in 弟子列表:
		if d != null and int(d.洞府等级) > 0:
			已分配 += 1
	if 已分配 >= 洞府数量:
		return  # 无空闲洞府
	# 寻找符合条件的弟子（金丹及以上、无洞府、贡献点足够）
	var 候选弟子: Array = []
	for d in 弟子列表:
		if d == null or str(d.状态) != "在宗":
			continue
		if int(d.洞府等级) > 0:
			continue  # 已有洞府
		var 境界序: int = Disciple.境界序.find(str(d.境界))
		if 境界序 < Disciple.境界序.find("金丹"):
			continue  # 金丹以下不主动申请
		if int(d.贡献账户) < 500:
			continue  # 贡献点不足
		候选弟子.append(d)
	if 候选弟子.is_empty():
		return
	# 按境界+贡献排序，优先分配给高境界高贡献弟子
	候选弟子.sort_custom(func(a, b): return int(a.贡献账户) > int(b.贡献账户))
	# 分配洞府（最多分配3个/月，避免灵石消耗过快）
	var 分配数: int = 0
	for d in 候选弟子:
		if 分配数 >= 3:
			break
		if 已分配 + 分配数 >= 洞府数量:
			break
		# 消耗弟子贡献点（500点）
		d.贡献账户 = max(0, int(d.贡献账户) - 500)
		d.洞府等级 = 1  # 初始1级洞府
		分配数 += 1
		_加推演条目("【洞府分配】%s修为已达%s，贡献卓著，主动向宗门申请洞府，获赐1级洞府，闭关修炼效率提升。" % [str(d.姓名), str(d.境界)], ET_SECT, PRIO_NORMAL, {"弟子": str(d.姓名)})

## 分配洞府给弟子（消耗灵石，洞府等级1-7）
func 分配洞府(弟子ID: int, 洞府等级: int = 1) -> Dictionary:
	var 目标 = null
	for d in 弟子列表:
		if d != null and int(d.弟子ID) == 弟子ID:
			目标 = d
			break
	if 目标 == null:
		return {"成功": false, "原因": "弟子不存在"}
	# 检查宗门洞府数量
	var 已分配: int = 0
	for d in 弟子列表:
		if d != null and d.洞府等级 > 0:
			已分配 += 1
	if 已分配 >= 洞府数量:
		return {"成功": false, "原因": "宗门洞府不足（已分配%d/%d），需扩建洞府" % [已分配, 洞府数量]}
	# 消耗灵石（洞府等级×1000）
	var 消耗: int = 洞府等级 * 1000
	if 灵石 < 消耗:
		return {"成功": false, "原因": "灵石不足（需%d）" % 消耗}
	灵石 -= 消耗
	目标.洞府等级 = 洞府等级
	添加纪事("庶务", "分配洞府", "%s获得%d级洞府，修炼效率+%d%%。" % [目标.姓名, 洞府等级, int(目标.洞府修炼加成() * 100)], 1)
	# 彩蛋：洞府遗留
	洞府遗留彩蛋(目标, 洞府等级)
	return {"成功": true, "原因": "分配%d级洞府" % 洞府等级, "消耗": 消耗}

## 升级洞府
func 升级洞府(弟子ID: int) -> Dictionary:
	var 目标 = null
	for d in 弟子列表:
		if d != null and int(d.弟子ID) == 弟子ID:
			目标 = d
			break
	if 目标 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if 目标.洞府等级 >= 7:
		return {"成功": false, "原因": "洞府已达最高品级"}
	if 目标.洞府等级 <= 0:
		return {"成功": false, "原因": "弟子尚无洞府，请先分配"}
	var 新等级: int = 目标.洞府等级 + 1
	var 消耗: int = 新等级 * 2000
	if 灵石 < 消耗:
		return {"成功": false, "原因": "灵石不足（需%d）" % 消耗}
	灵石 -= 消耗
	目标.洞府等级 = 新等级
	添加纪事("庶务", "升级洞府", "%s洞府升级至%d级，修炼效率+%d%%。" % [目标.姓名, 新等级, int(目标.洞府修炼加成() * 100)], 1)
	# 彩蛋：洞府遗留（升级时探索新区域）
	洞府遗留彩蛋(目标, 新等级)
	return {"成功": true, "原因": "升级至%d级" % 新等级, "消耗": 消耗}

## 个人灵田月产出（每个有灵田的弟子每月产灵草）
func _灵田月度产出() -> void:
	var 总产出: int = 0
	for d in 弟子列表:
		if d != null and d.个人灵田等级 > 0 and str(d.状态) == "在宗":
			var 产出: int = d.灵田月产出()
			灵草 += 产出
			总产出 += 产出
	if 总产出 > 0:
		添加纪事("庶务", "灵田产出", "弟子个人灵田共产出%d株灵草。" % 总产出, 1)

## 上古洞府传承系统（修真味：秘境中发现上古洞府，通过考验获得传承）
## 上古洞府配置（品阶越高，传承越丰厚，考验越难）
const 上古洞府配置: Array = [
	{"名称": "炼气士洞府", "品阶": "凡阶", "门槛": "练气", "悟道点": 50, "灵石": 500, "概率": 0.10},
	{"名称": "筑基修士洞府", "品阶": "灵阶", "门槛": "筑基", "悟道点": 100, "灵石": 1000, "概率": 0.08},
	{"名称": "金丹真人洞府", "品阶": "宝阶", "门槛": "金丹", "悟道点": 200, "灵石": 2000, "概率": 0.06},
	{"名称": "元婴老祖洞府", "品阶": "王阶", "门槛": "元婴", "悟道点": 400, "灵石": 4000, "概率": 0.04},
	{"名称": "化神圣尊洞府", "品阶": "圣阶", "门槛": "化神", "悟道点": 800, "灵石": 8000, "概率": 0.02},
	{"名称": "炼虚道君洞府", "品阶": "仙阶", "门槛": "炼虚", "悟道点": 1500, "灵石": 15000, "概率": 0.01},
	{"名称": "大乘仙帝洞府", "品阶": "道阶", "门槛": "合体", "悟道点": 3000, "灵石": 30000, "概率": 0.005},
]

## 秘境探索时概率发现上古洞府
func 检查上古洞府(弟子境界: String) -> Dictionary:
	var 可进入: Array = []
	for 洞府 in 上古洞府配置:
		var 门槛序: int = Disciple.境界序.find(str(洞府.get("门槛", "练气")))
		var 弟子序: int = Disciple.境界序.find(弟子境界)
		if 弟子序 >= 门槛序 and randf() < float(洞府.get("概率", 0.01)):
			可进入.append(洞府)
	if 可进入.is_empty():
		return {"发现": false}
	# 选择品阶最高的洞府
	可进入.sort_custom(func(a, b): return str(a.get("品阶", "")) > str(b.get("品阶", "")))
	return {"发现": true, "洞府": 可进入[0]}

## 进入上古洞府获取传承（消耗灵石开启，获得悟道点+概率获得功法/丹药）
func 进入上古洞府(弟子: Object, 洞府: Dictionary) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	var 消耗灵石: int = int(洞府.get("灵石", 1000))
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（开启洞府需%d）" % 消耗灵石}
	灵石 -= 消耗灵石
	# 获得悟道点
	var 悟道: int = int(洞府.get("悟道点", 100))
	悟道点 += 悟道
	# 概率获得功法（30%概率）
	var 获得功法名: String = ""
	if randf() < 0.30 and 宗主 != null:
		var 功法列表: Array = ["吐纳术", "清心诀", "紫霞神功", "太玄经", "道德经", "黄庭经", "天道诀"]
		获得功法名 = 功法列表[randi() % 功法列表.size()]
		if 宗主.已学功法 == null:
			宗主.已学功法 = []
		if 获得功法名 not in 宗主.已学功法:
			宗主.已学功法.append(获得功法名)
	# 概率获得丹药（50%概率）
	var 获得丹药: String = ""
	if randf() < 0.50:
		var 丹药列表: Array = ["筑基丹", "金丹", "元婴丹", "化神丹", "悟道丹"]
		获得丹药 = 丹药列表[randi() % 丹药列表.size()]
	添加纪事("庶务", "上古洞府", "%s发现%s（%s），获得%d悟道点%s%s！" % [
		弟子.姓名, 洞府.get("名称", ""), 洞府.get("品阶", ""), 悟道,
		"+《%s》" % 获得功法名 if 获得功法名 != "" else "",
		"+%s" % 获得丹药 if 获得丹药 != "" else ""
	], 3)
	return {"成功": true, "悟道点": 悟道, "功法": 获得功法名, "丹药": 获得丹药, "消耗": 消耗灵石}

## 布阵阵位玩法（修真味：阵法有阵位，弟子分配到对应阵位，匹配度影响威力）
## 阵位类型定义
const 阵位类型: Dictionary = {
	"攻": {"名称": "攻击位", "描述": "主杀伐，适合攻伐型弟子", "匹配道途": ["道修", "刀修", "法修", "体修"]},
	"防": {"名称": "防御位", "描述": "主守御，适合防御型弟子", "匹配道途": ["体修", "道修"]},
	"辅": {"名称": "辅助位", "描述": "主辅助，适合辅助型弟子", "匹配道途": ["丹修", "符修", "医修"]},
	"控": {"名称": "控制位", "描述": "主控制，适合控制型弟子", "匹配道途": ["法修", "符修"]},
}

## 各阵法的阵位配置（team类型阵法）
const 阵法阵位配置: Dictionary = {
	"arr_t_001": ["攻", "攻"],           # 两仪协攻阵：2攻击位
	"arr_t_002": ["防", "防", "辅"],       # 三才守御阵：2防御+1辅助
	"arr_t_003": ["攻", "防", "辅", "控"],  # 四象聚灵阵：各1位
	"arr_t_004": ["防", "防", "防", "辅", "辅"],  # 五岳镇魔阵：3防御+2辅助
	"arr_t_005": ["攻", "攻", "攻", "攻", "攻", "控", "辅"],  # 七星破阵：5攻击+1控制+1辅助
	"arr_t_006": ["攻", "防", "辅", "控", "攻"],  # 周天同心阵：2攻击+1防御+1辅助+1控制
}

## 宗门大阵阵位分配（阵法ID -> [{弟子ID, 阵位类型}]）
var 宗门阵位分配: Dictionary = {}

## 分配弟子到阵位
func 分配阵位(阵法ID: String, 弟子ID: int, 阵位类型: String) -> Dictionary:
	if not 阵法阵位配置.has(阵法ID):
		return {"成功": false, "原因": "该阵法无阵位配置"}
	var 阵位列表: Array = 阵法阵位配置[阵法ID]
	if 阵位类型 not in 阵位列表:
		return {"成功": false, "原因": "该阵法无%s位" % 阵位类型}
	# 检查弟子是否存在
	var 目标 = null
	for d in 弟子列表:
		if d != null and int(d.弟子ID) == 弟子ID:
			目标 = d
			break
	if 目标 == null:
		return {"成功": false, "原因": "弟子不存在"}
	# 初始化分配
	if not 宗门阵位分配.has(阵法ID):
		宗门阵位分配[阵法ID] = []
	# 检查该阵位是否已分配
	var 已分配: Array = 宗门阵位分配[阵法ID]
	for i in range(已分配.size()):
		if str(已分配[i].get("阵位", "")) == 阵位类型:
			已分配[i] = {"弟子ID": 弟子ID, "阵位": 阵位类型, "弟子名": 目标.姓名}
			添加纪事("庶务", "阵位调整", "%s调整至%s的%s。" % [目标.姓名, 阵法ID, 阵位类型], 1)
			return {"成功": true, "原因": "调整阵位成功"}
	# 新分配
	已分配.append({"弟子ID": 弟子ID, "阵位": 阵位类型, "弟子名": 目标.姓名})
	添加纪事("庶务", "分配阵位", "%s分配至%s的%s。" % [目标.姓名, 阵法ID, 阵位类型], 1)
	return {"成功": true, "原因": "分配阵位成功"}

## 计算阵法加成（填充率+匹配度）
func 计算阵法加成(阵法ID: String) -> Dictionary:
	var 结果: Dictionary = {"填充率": 0.0, "匹配度": 0.0, "总加成": 0.0, "攻击加成": 0.0, "防御加成": 0.0}
	if not 阵法阵位配置.has(阵法ID):
		return 结果
	var 阵位列表: Array = 阵法阵位配置[阵法ID]
	var 已分配: Array = 宗门阵位分配.get(阵法ID, [])
	# 填充率
	var 填充数: int = 已分配.size()
	结果["填充率"] = float(填充数) / float(阵位列表.size())
	# 匹配度（弟子道途与阵位类型匹配）
	var 匹配数: int = 0
	for 分配 in 已分配:
		var 弟子ID: int = int(分配.get("弟子ID", -1))
		var 阵位: String = str(分配.get("阵位", ""))
		var 目标 = null
		for d in 弟子列表:
			if d != null and int(d.弟子ID) == 弟子ID:
				目标 = d
				break
		if 目标 == null:
			continue
		var 匹配道途: Array = 阵位类型.get(阵位, {}).get("匹配道途", [])
		if str(目标.道途) in 匹配道途:
			匹配数 += 1
	结果["匹配度"] = float(匹配数) / float(max(1, 填充数))
	# 基础加成（从阵法配置表读取）
	var 配置: Dictionary = 阵法配置表.get(阵法ID, {})
	var 基础加成: float = float(str(配置.get("eff_val_base", "0")).replace("%", "")) / 100.0
	# 总加成 = 基础加成 × 填充率 × (1 + 匹配度×0.5)
	结果["总加成"] = 基础加成 * 结果["填充率"] * (1.0 + 结果["匹配度"] * 0.5)
	# 按阵位类型分配加成
	var 攻位数: int = 0
	var 防位数: int = 0
	for 位 in 阵位列表:
		if 位 == "攻":
			攻位数 += 1
		elif 位 == "防":
			防位数 += 1
	if 攻位数 > 0:
		结果["攻击加成"] = 结果["总加成"] * (float(攻位数) / float(阵位列表.size()))
	if 防位数 > 0:
		结果["防御加成"] = 结果["总加成"] * (float(防位数) / float(阵位列表.size()))
	return 结果

## 彩蛋系统：修真小说常见桥段（洞府遗留/储物袋/秘境奇遇/坊市捡漏）
## 储物袋配置（击败敌对NPC掉落，需祭炼抹除神识才能打开）
const 储物袋配置: Dictionary = {
	"凡品储物袋": {"祭炼天数": 1, "灵石范围": [10, 100], "丹药概率": 0.3, "功法概率": 0.05, "法宝概率": 0.02},
	"灵品储物袋": {"祭炼天数": 3, "灵石范围": [50, 500], "丹药概率": 0.4, "功法概率": 0.10, "法宝概率": 0.05},
	"宝品储物袋": {"祭炼天数": 7, "灵石范围": [200, 2000], "丹药概率": 0.5, "功法概率": 0.15, "法宝概率": 0.08},
	"王品储物袋": {"祭炼天数": 15, "灵石范围": [500, 5000], "丹药概率": 0.6, "功法概率": 0.20, "法宝概率": 0.12},
	"圣品储物袋": {"祭炼天数": 30, "灵石范围": [2000, 20000], "丹药概率": 0.7, "功法概率": 0.30, "法宝概率": 0.20},
	"仙品储物袋": {"祭炼天数": 60, "灵石范围": [5000, 50000], "丹药概率": 0.8, "功法概率": 0.40, "法宝概率": 0.30},
}
var 储物袋列表: Array = []  # 未开启的储物袋 [{名称, 品阶, 剩余祭炼天数, 来源}]

## 洞府遗留彩蛋（分配/升级洞府时触发，发现上任所有者遗留物品）
func 洞府遗留彩蛋(弟子: Object, 洞府等级: int) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	# 概率随洞府等级提升（高级洞府上任所有者更可能有遗留）
	var 基础概率: float = 0.05 + float(洞府等级) * 0.02
	if randf() > 基础概率:
		return {"触发": false}
	# 随机遗留类型
	var roll: float = randf()
	if roll < 0.40:
		# 灵石遗留
		var 灵石数: int = randi_range(50, 500) * 洞府等级
		灵石 += 灵石数
		添加纪事("奇遇", "洞府遗留", "%s在洞府静室暗格中发现上任修士遗留的%d灵石！" % [弟子.姓名, 灵石数], 3)
		return {"触发": true, "类型": "灵石", "数量": 灵石数}
	elif roll < 0.65:
		# 灵草遗留
		var 灵草数: int = randi_range(3, 10) * 洞府等级
		灵草 += 灵草数
		添加纪事("奇遇", "洞府遗留", "%s在洞府药圃中发现上任修士遗留的%d株灵草！" % [弟子.姓名, 灵草数], 2)
		return {"触发": true, "类型": "灵草", "数量": 灵草数}
	elif roll < 0.85:
		# 丹药遗留
		var 丹药数: int = randi_range(1, 3)
		添加纪事("奇遇", "洞府遗留", "%s在洞府丹房中发现上任修士遗留的%d瓶丹药！" % [弟子.姓名, 丹药数], 2)
		return {"触发": true, "类型": "丹药", "数量": 丹药数}
	elif roll < 0.95:
		# 功法残篇
		var 悟道: int = randi_range(20, 100) * 洞府等级
		悟道点 += 悟道
		添加纪事("奇遇", "洞府遗留", "%s在洞府书阁中发现上任修士遗留的功法残篇，研读后获得%d悟道点！" % [弟子.姓名, 悟道], 3)
		return {"触发": true, "类型": "功法残篇", "悟道点": 悟道}
	else:
		# 上古传承（稀有彩蛋）
		var 悟道: int = randi_range(100, 500) * 洞府等级
		悟道点 += 悟道
		声望 += 10
		添加纪事("奇遇", "上古传承", "%s在洞府密室中发现上古修士坐化遗骸，旁有一部完整传承！获得%d悟道点，宗门声望+10。" % [弟子.姓名, 悟道], 4)
		return {"触发": true, "类型": "上古传承", "悟道点": 悟道, "声望": 10}

## 击败敌对NPC掉落储物袋
func 掉落储物袋(敌对境界: String, 来源: String = "战斗") -> Dictionary:
	var 境界序_idx: int = Disciple.境界序.find(敌对境界)
	var 品阶: String = "凡品储物袋"
	if 境界序_idx >= 7:
		品阶 = "仙品储物袋"
	elif 境界序_idx >= 5:
		品阶 = "圣品储物袋"
	elif 境界序_idx >= 4:
		品阶 = "王品储物袋"
	elif 境界序_idx >= 3:
		品阶 = "宝品储物袋"
	elif 境界序_idx >= 1:
		品阶 = "灵品储物袋"
	var 配置: Dictionary = 储物袋配置.get(品阶, 储物袋配置["凡品储物袋"])
	var 袋: Dictionary = {
		"名称": 品阶,
		"品阶": 品阶.replace("储物袋", ""),
		"剩余祭炼天数": int(配置.get("祭炼天数", 1)),
		"总祭炼天数": int(配置.get("祭炼天数", 1)),
		"来源": 来源,
	}
	储物袋列表.append(袋)
	添加纪事("战利品", "储物袋", "击败敌人后获得%s，需祭炼%d日抹除神识后方可打开。" % [品阶, 袋["总祭炼天数"]], 2)
	return {"成功": true, "储物袋": 袋}

## 祭炼储物袋（每日推进）
func 祭炼储物袋月度推进(月: float) -> void:
	var 已开启: Array = []
	for i in range(储物袋列表.size()):
		var 袋: Dictionary = 储物袋列表[i]
		袋["剩余祭炼天数"] = max(0, int(袋["剩余祭炼天数"]) - int(月 * 30))
		if int(袋["剩余祭炼天数"]) <= 0:
			已开启.append(i)
	# 倒序移除并开启
	for i in range(已开启.size() - 1, -1, -1):
		var idx: int = 已开启[i]
		var 袋: Dictionary = 储物袋列表[idx]
		储物袋列表.remove_at(idx)
		开启储物袋(袋)

## 开启储物袋（祭炼完成后自动开启）
func 开启储物袋(袋: Dictionary) -> Dictionary:
	var 品阶: String = str(袋.get("品阶", "凡品"))
	var 配置: Dictionary = 储物袋配置.get(品阶 + "储物袋", 储物袋配置["凡品储物袋"])
	var 结果: Dictionary = {"品阶": 品阶, "物品": []}
	# 灵石
	var 灵石范围: Array = 配置.get("灵石范围", [10, 100])
	var 灵石数: int = randi_range(int(灵石范围[0]), int(灵石范围[1]))
	灵石 += 灵石数
	结果["物品"].append("灵石×%d" % 灵石数)
	# 丹药
	if randf() < float(配置.get("丹药概率", 0.3)):
		var 丹药数: int = randi_range(1, 3)
		结果["物品"].append("丹药×%d" % 丹药数)
	# 功法
	if randf() < float(配置.get("功法概率", 0.05)):
		var 悟道: int = randi_range(50, 200)
		悟道点 += 悟道
		结果["物品"].append("功法心得（%d悟道点）" % 悟道)
	# 法宝
	if randf() < float(配置.get("法宝概率", 0.02)):
		结果["物品"].append("神秘法宝一件")
	添加纪事("战利品", "储物袋开启", "%s祭炼完成，开启后获得：%s" % [袋.get("名称", ""), "、".join(结果["物品"])], 3)
	return 结果

## 秘境奇遇彩蛋（修真小说常见桥段：前人坐化/神秘传承/灵泉沐浴/滴血认主）
func 秘境奇遇彩蛋(弟子: Object, 秘境等级: int = 1) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	# 基础概率5%，秘境等级越高概率越大
	var 概率: float = 0.05 + float(秘境等级) * 0.01
	if randf() > 概率:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.25:
		# 前人坐化洞府
		var 悟道: int = randi_range(50, 200) * 秘境等级
		悟道点 += 悟道
		添加纪事("奇遇", "前人坐化", "%s在秘境深处发现一处前人坐化洞府，遗骸旁留有一部手札，研读后获得%d悟道点！" % [弟子.姓名, 悟道], 4)
		return {"触发": true, "类型": "前人坐化", "悟道点": 悟道}
	elif roll < 0.45:
		# 神秘老者传功
		var 心境加: int = randi_range(5, 20)
		弟子.增加心境(心境加)
		添加纪事("奇遇", "神秘传功", "%s在秘境中偶遇一位神秘老者，老者见其根骨不俗，随手点拨几句，心境+%d！" % [弟子.姓名, 心境加], 4)
		return {"触发": true, "类型": "神秘传功", "心境": 心境加}
	elif roll < 0.65:
		# 灵泉沐浴
		var 寿元加: int = randi_range(1, 5)
		弟子.寿元 += 寿元加
		添加纪事("奇遇", "灵泉沐浴", "%s发现一处灵泉，入内沐浴后只觉通体舒泰，寿元+%d年！" % [弟子.姓名, 寿元加], 3)
		return {"触发": true, "类型": "灵泉沐浴", "寿元": 寿元加}
	elif roll < 0.80:
		# 滴血认主
		var 灵石数: int = randi_range(100, 500) * 秘境等级
		灵石 += 灵石数
		添加纪事("奇遇", "滴血认主", "%s在秘境中捡到一件蒙尘宝物，滴血认主后发现内藏%d灵石的储物空间！" % [弟子.姓名, 灵石数], 3)
		return {"触发": true, "类型": "滴血认主", "灵石": 灵石数}
	elif roll < 0.92:
		# 上古洞府传承（调用已有系统）
		var 洞府结果: Dictionary = 检查上古洞府(str(弟子.境界))
		if bool(洞府结果.get("发现", false)):
			进入上古洞府(弟子, 洞府结果["洞府"])
			return {"触发": true, "类型": "上古洞府"}
		return {"触发": false}
	else:
		# 捡漏（买到/捡到隐藏价值物品）
		var 灵草数: int = randi_range(5, 20) * 秘境等级
		灵草 += 灵草数
		添加纪事("奇遇", "秘境捡漏", "%s在一处废弃营地中发现被人遗漏的%d株灵草！" % [弟子.姓名, 灵草数], 2)
		return {"触发": true, "类型": "秘境捡漏", "灵草": 灵草数}

## 坊市捡漏彩蛋（修真小说常见桥段：摊主不识货/隐藏价值物品/淘宝）
func 坊市捡漏彩蛋(购买物品: String = "") -> Dictionary:
	# 基础概率3%
	if randf() > 0.03:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.40:
		# 摊主不识货，低价买到宝贝
		var 灵石数: int = randi_range(50, 300)
		灵石 += 灵石数
		添加纪事("奇遇", "坊市捡漏", "在坊市中遇到一位不识货的摊主，低价购入的物品转手卖出，净赚%d灵石！" % 灵石数, 3)
		return {"触发": true, "类型": "摊主不识货", "灵石": 灵石数}
	elif roll < 0.70:
		# 隐藏价值物品（内含储物袋）
		var 悟道: int = randi_range(20, 100)
		悟道点 += 悟道
		添加纪事("奇遇", "隐藏价值", "购入的物品中竟藏有一张古旧丹方，研读后获得%d悟道点！" % 悟道, 3)
		return {"触发": true, "类型": "隐藏价值", "悟道点": 悟道}
	else:
		# 遇到神秘商人
		var 声望加: int = 5
		声望 += 声望加
		添加纪事("奇遇", "神秘商人", "在坊市角落遇到一位神秘商人，相谈甚欢，宗门声望+%d！" % 声望加, 2)
		return {"触发": true, "类型": "神秘商人", "声望": 声望加}

# ============ 扩展彩蛋系统：六大类修真小说常见桥段 ============

## 一、路见不平类彩蛋
## 遇到恶霸欺负人（历练/坊市/外出时触发）
func 彩蛋_路见不平(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.40:
		var 声望加: int = randi_range(3, 10)
		声望 += 声望加
		var 贡献: int = randi_range(10, 30)
		弟子.贡献点 += 贡献
		添加纪事("奇遇", "路见不平", "%s外出时遇恶霸欺压散修，出手相助击退恶霸，散修感激涕零。宗门声望+%d，%s获得贡献点+%d。" % [弟子.姓名, 声望加, 弟子.姓名, 贡献], 3)
		return {"触发": true, "类型": "恶霸欺压", "声望": 声望加, "贡献": 贡献}
	elif roll < 0.70:
		var 灵石数: int = randi_range(100, 500)
		灵石 += 灵石数
		添加纪事("奇遇", "救人报恩", "%s路遇被追杀的重伤修士，出手将其救下。修士伤愈后留下%d灵石作为谢礼，飘然而去。" % [弟子.姓名, 灵石数], 3)
		return {"触发": true, "类型": "救人报恩", "灵石": 灵石数}
	else:
		声望 += 5
		添加纪事("奇遇", "结下善缘", "%s救下被邪修追杀的女修，女修感激不尽，承诺日后必有厚报。宗门声望+5，结下一段善缘。" % 弟子.姓名, 3)
		return {"触发": true, "类型": "结下善缘", "声望": 5}

## 二、夺宝/黑吃黑类彩蛋
## 拍卖会后被人盯上夺宝
func 彩蛋_拍卖会夺宝(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	if randf() > 0.20:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.50:
		var 境界: String = str(弟子.境界)
		掉落储物袋(境界, "反杀夺宝")
		添加纪事("奇遇", "反杀夺宝", "%s拍卖会结束后被人尾随夺宝，早有防备的%s反手将其击杀，获得储物袋一个！" % [弟子.姓名, 弟子.姓名], 4)
		return {"触发": true, "类型": "反杀夺宝"}
	elif roll < 0.80:
		添加纪事("奇遇", "击退夺宝", "%s拍卖会结束后遭人偷袭夺宝，激战数十回合后将对方击退，对方仓皇逃窜。" % 弟子.姓名, 2)
		return {"触发": true, "类型": "击退夺宝"}
	else:
		var 损失: int = min(灵石, randi_range(50, 200))
		灵石 -= 损失
		添加纪事("奇遇", "被夺宝", "%s拍卖会结束后遭高手偷袭，不敌对方，损失%d灵石后侥幸逃脱。" % [弟子.姓名, 损失], 3)
		return {"触发": true, "类型": "被夺宝", "损失": 损失}

## 秘境中被人背后偷袭
func 彩蛋_秘境偷袭(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	if randf() > 0.08:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.40:
		var 境界: String = str(弟子.境界)
		掉落储物袋(境界, "反杀偷袭")
		添加纪事("奇遇", "反杀偷袭", "%s在秘境中遭人背后偷袭，早有防备的%s反手将其击杀，黑吃黑获得储物袋！" % [弟子.姓名, 弟子.姓名], 4)
		return {"触发": true, "类型": "反杀偷袭"}
	elif roll < 0.70:
		var 受伤: int = randi_range(5, 15)
		弟子.受伤剩余 = max(int(弟子.受伤剩余), 受伤)
		添加纪事("奇遇", "秘境激战", "%s在秘境中遭人偷袭，激战数十回合后将对方击退，但也身受重伤，需养伤%d日。" % [弟子.姓名, 受伤], 3)
		return {"触发": true, "类型": "秘境激战", "受伤": 受伤}
	else:
		var 声望加: int = randi_range(5, 15)
		声望 += 声望加
		添加纪事("奇遇", "制止恶行", "%s在秘境中发现有人正在杀人夺宝，出手制止了这场恶行，被救修士感恩戴德。宗门声望+%d。" % [弟子.姓名, 声望加], 3)
		return {"触发": true, "类型": "制止恶行", "声望": 声望加}

## 三、邪修/魔道类彩蛋
## 发现邪修祭炼生魂（历练时触发）
func 彩蛋_邪修祭炼(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	if randf() > 0.05:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.40:
		# 出手摧毁祭坛，解救生魂
		var 功德加: int = randi_range(50, 200)
		var 业力减: int = randi_range(20, 50)
		弟子.功德 += 功德加
		弟子.业力 = max(0, int(弟子.业力) - 业力减)
		声望 += 10
		添加纪事("奇遇", "摧毁祭坛", "%s发现邪修正在祭炼生魂，出手摧毁祭坛，解救数百生魂。功德+%d，业力-%d，宗门声望+10。" % [弟子.姓名, 功德加, 业力减], 4)
		return {"触发": true, "类型": "摧毁祭坛", "功德": 功德加, "业力": 业力减}
	elif roll < 0.70:
		# 邪修太强，只能暗中破坏
		var 功德加: int = randi_range(20, 50)
		弟子.功德 += 功德加
		添加纪事("奇遇", "暗中破坏", "%s发现邪修祭炼生魂的祭坛，对方实力太强只能暗中破坏，解救部分生魂后悄然离去。功德+%d。" % [弟子.姓名, 功德加], 3)
		return {"触发": true, "类型": "暗中破坏", "功德": 功德加}
	else:
		# 被邪修发现，激战逃脱
		var 受伤: int = randi_range(10, 30)
		弟子.受伤剩余 = max(int(弟子.受伤剩余), 受伤)
		添加纪事("奇遇", "邪修追杀", "%s发现邪修祭炼生魂时被对方察觉，激战一番后身受重伤逃脱，需养伤%d日。" % [弟子.姓名, 受伤], 3)
		return {"触发": true, "类型": "邪修追杀", "受伤": 受伤}

## 遇到魔修采补（历练时触发）
func 彩蛋_魔修采补(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	if randf() > 0.04:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.50:
		# 救下受害者，击杀魔修
		var 境界: String = str(弟子.境界)
		掉落储物袋(境界, "击杀魔修")
		声望 += 15
		添加纪事("奇遇", "击杀魔修", "%s撞见魔修正在采补修士，怒而出手将其击杀，救下受害者。获得储物袋，宗门声望+15。" % 弟子.姓名, 4)
		return {"触发": true, "类型": "击杀魔修", "声望": 15}
	else:
		# 魔修太强，只能救下受害者逃走
		var 功德加: int = randi_range(30, 80)
		弟子.功德 += 功德加
		添加纪事("奇遇", "救下受害者", "%s撞见魔修采补，对方实力太强，只能救下受害者后迅速离去。功德+%d。" % [弟子.姓名, 功德加], 3)
		return {"触发": true, "类型": "救下受害者", "功德": 功德加}

## 发现血祭阵法（历练/探索时触发）
func 彩蛋_血祭阵法(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	if randf() > 0.03:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.50:
		# 破阵成功，获得阵法传承
		var 悟道: int = randi_range(100, 300)
		悟道点 += 悟道
		声望 += 20
		添加纪事("奇遇", "破阵传承", "%s发现一座上古血祭大阵，耗费心力将其破去，在阵眼处获得一部阵法传承。悟道点+%d，宗门声望+20。" % [弟子.姓名, 悟道], 4)
		return {"触发": true, "类型": "破阵传承", "悟道": 悟道, "声望": 20}
	else:
		# 阵法反噬，受伤撤退
		var 受伤: int = randi_range(15, 40)
		弟子.受伤剩余 = max(int(弟子.受伤剩余), 受伤)
		添加纪事("奇遇", "阵法反噬", "%s尝试破解血祭大阵时遭到阵法反噬，身受重伤撤退，需养伤%d日。" % [弟子.姓名, 受伤], 3)
		return {"触发": true, "类型": "阵法反噬", "受伤": 受伤}

## 四、机缘/奇遇类彩蛋
## 树下捡到功法（历练/外出时触发）
func 彩蛋_树下捡功法(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	if randf() > 0.03:
		return {"触发": false}
	var 悟道: int = randi_range(50, 200)
	悟道点 += 悟道
	添加纪事("奇遇", "树下捡功", "%s在古树下休憩时，发现树洞中藏有一部古旧功法，研读后获得%d悟道点！" % [弟子.姓名, 悟道], 3)
	return {"触发": true, "类型": "树下捡功", "悟道": 悟道}

## 湖中得到传承（历练时触发）
func 彩蛋_湖中传承(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	if randf() > 0.02:
		return {"触发": false}
	var 悟道: int = randi_range(150, 400)
	var 寿元加: int = randi_range(3, 10)
	悟道点 += 悟道
	弟子.寿元 += 寿元加
	添加纪事("奇遇", "湖中传承", "%s在灵湖中沐浴时，意外发现湖底有一处上古洞府，入内得到高人传承。悟道点+%d，寿元+%d年！" % [弟子.姓名, 悟道, 寿元加], 4)
	return {"触发": true, "类型": "湖中传承", "悟道": 悟道, "寿元": 寿元加}

## 悬崖下发现洞府（历练时触发）
func 彩蛋_悬崖洞府(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	if randf() > 0.02:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.50:
		var 灵石数: int = randi_range(500, 2000)
		灵石 += 灵石数
		添加纪事("奇遇", "悬崖洞府", "%s不慎跌落悬崖，却意外发现崖壁上有一处隐蔽洞府，内藏%d灵石！" % [弟子.姓名, 灵石数], 4)
		return {"触发": true, "类型": "悬崖洞府", "灵石": 灵石数}
	else:
		var 悟道: int = randi_range(100, 300)
		悟道点 += 悟道
		添加纪事("奇遇", "悬崖传承", "%s不慎跌落悬崖，却意外发现崖壁上古修士的闭关洞府，获得一部传承。悟道点+%d！" % [弟子.姓名, 悟道], 4)
		return {"触发": true, "类型": "悬崖传承", "悟道": 悟道}

## 古战场捡漏（历练时触发）
func 彩蛋_古战场捡漏(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	if randf() > 0.04:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.40:
		var 灵石数: int = randi_range(200, 1000)
		灵石 += 灵石数
		添加纪事("奇遇", "古战场捡漏", "%s在古战场遗迹中探索，从一具遗骸上找到一个未被发现的储物袋，内有%d灵石！" % [弟子.姓名, 灵石数], 3)
		return {"触发": true, "类型": "古战场捡漏", "灵石": 灵石数}
	elif roll < 0.70:
		var 悟道: int = randi_range(50, 150)
		悟道点 += 悟道
		添加纪事("奇遇", "残碑悟道", "%s在古战场中发现一块残破石碑，上刻上古战技，研读后获得%d悟道点！" % [弟子.姓名, 悟道], 3)
		return {"触发": true, "类型": "残碑悟道", "悟道": 悟道}
	else:
		var 境界: String = str(弟子.境界)
		掉落储物袋(境界, "古战场")
		添加纪事("奇遇", "战将遗骸", "%s在古战场深处发现一位上古战将的遗骸，其随身储物袋仍在，获得%s！" % [弟子.姓名, 境界], 4)
		return {"触发": true, "类型": "战将遗骸"}

## 五、人物互动类彩蛋
## 遇到故人（历练/坊市时触发）
func 彩蛋_遇到故人(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	if randf() > 0.05:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.40:
		# 遇到旧友，获得馈赠
		var 灵石数: int = randi_range(50, 200)
		灵石 += 灵石数
		添加纪事("奇遇", "故人相遇", "%s在外出时偶遇多年未见的旧友，故人如今已是一方豪强，盛情款待后赠予%d灵石。" % [弟子.姓名, 灵石数], 3)
		return {"触发": true, "类型": "故人馈赠", "灵石": 灵石数}
	elif roll < 0.70:
		# 遇到师门长辈，得到指点
		var 悟道: int = randi_range(30, 100)
		悟道点 += 悟道
		添加纪事("奇遇", "长辈指点", "%s偶遇一位师门长辈，长辈见其修为精进，欣然指点一番。悟道点+%d。" % [弟子.姓名, 悟道], 3)
		return {"触发": true, "类型": "长辈指点", "悟道": 悟道}
	else:
		# 遇到仇人，激战一场
		var 受伤: int = randi_range(5, 20)
		弟子.受伤剩余 = max(int(弟子.受伤剩余), 受伤)
		添加纪事("奇遇", "仇人相遇", "%s外出时偶遇昔日仇人，双方激战一场，两败俱伤各自退去。%s需养伤%d日。" % [弟子.姓名, 弟子.姓名, 受伤], 3)
		return {"触发": true, "类型": "仇人相遇", "受伤": 受伤}

## 被人挑衅（坊市/历练时触发）
func 彩蛋_被挑衅(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	if randf() > 0.06:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.40:
		# 轻松击败挑衅者，获得名声
		var 声望加: int = randi_range(3, 10)
		声望 += 声望加
		添加纪事("奇遇", "击败挑衅", "%s在坊市被人挑衅，三招两式便将对方击败，围观修士纷纷叫好。宗门声望+%d。" % [弟子.姓名, 声望加], 2)
		return {"触发": true, "类型": "击败挑衅", "声望": 声望加}
	elif roll < 0.70:
		# 对方背景不简单，结下梁子
		添加纪事("奇遇", "结下梁子", "%s在坊市被人挑衅，出手教训了对方，却不知对方是某宗门嫡系，就此结下一段梁子。" % 弟子.姓名, 3)
		return {"触发": true, "类型": "结下梁子"}
	else:
		# 隐忍不发，获得心境提升
		var 心境加: int = randi_range(2, 8)
		弟子.增加心境(心境加)
		添加纪事("奇遇", "隐忍心境", "%s被人挑衅却隐忍不发，事后回想反而心境有所突破。心境+%d。" % [弟子.姓名, 心境加], 3)
		return {"触发": true, "类型": "隐忍心境", "心境": 心境加}

## 遇到隐世高人（历练时触发）
func 彩蛋_隐世高人(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"触发": false}
	if randf() > 0.02:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.40:
		# 高人传功
		var 悟道: int = randi_range(200, 500)
		悟道点 += 悟道
		var 心境加: int = randi_range(5, 15)
		弟子.增加心境(心境加)
		添加纪事("奇遇", "高人传功", "%s在深山之中遇到一位隐世高人，高人见其根骨不俗，传下一段功法心得。悟道点+%d，心境+%d！" % [弟子.姓名, 悟道, 心境加], 4)
		return {"触发": true, "类型": "高人传功", "悟道": 悟道, "心境": 心境加}
	elif roll < 0.70:
		# 高人赠宝
		var 境界: String = str(弟子.境界)
		掉落储物袋(境界, "高人赠宝")
		添加纪事("奇遇", "高人赠宝", "%s遇到一位隐世高人，高人与其相谈甚欢，临别时赠予一个储物袋。" % 弟子.姓名, 4)
		return {"触发": true, "类型": "高人赠宝"}
	else:
		# 高人指点迷津
		var 道心加: int = randi_range(5, 20)
		弟子.道心 = min(100, int(弟子.道心) + 道心加)
		添加纪事("奇遇", "指点迷津", "%s遇到一位隐世高人，高人一语点破其修炼瓶颈，道心+%d！" % [弟子.姓名, 道心加], 4)
		return {"触发": true, "类型": "指点迷津", "道心": 道心加}

## 六、宗门事件类彩蛋（月度随机触发）
## 其他宗门挑衅
func 彩蛋_宗门挑衅() -> Dictionary:
	if randf() > 0.03:
		return {"触发": false}
	var roll: float = randf()
	if roll < 0.50:
		# 上门切磋
		var 声望变化: int = randi_range(-10, 10)
		声望 = max(0, int(声望) + 声望变化)
		if 声望变化 >= 0:
			添加纪事("宗门", "上门切磋", "邻宗修士上门切磋，本宗弟子大胜而归，宗门声望+%d。" % 声望变化, 2)
		else:
			添加纪事("宗门", "上门切磋", "邻宗修士上门切磋，本宗弟子惜败，宗门声望%d。" % 声望变化, 3)
		return {"触发": true, "类型": "上门切磋", "声望变化": 声望变化}
	else:
		# 索要资源
		添加纪事("宗门", "索要资源", "邻宗派人前来索要灵脉资源，态度傲慢。宗主可选择交涉或强硬回应。", 3)
		return {"触发": true, "类型": "索要资源"}

## 散修投奔
func 彩蛋_散修投奔() -> Dictionary:
	if randf() > 0.05:
		return {"触发": false}
	# 生成一个随机散修投奔（简化为纪事提示，实际招募由招徒系统处理）
	var 声望加: int = randi_range(2, 8)
	声望 += 声望加
	添加纪事("宗门", "散修投奔", "有散修慕名前来投奔，称仰慕本宗威名。宗门声望+%d，可在招徒时优先考虑。" % 声望加, 2)
	return {"触发": true, "类型": "散修投奔", "声望": 声望加}

## 魔道入侵警报
func 彩蛋_魔道入侵() -> Dictionary:
	if randf() > 0.02:
		return {"触发": false}
	var 声望加: int = randi_range(5, 20)
	声望 += 声望加
	添加纪事("宗门", "魔道入侵", "魔道修士在宗门附近出没，本宗弟子出手将其击退，守护了一方安宁。宗门声望+%d。" % 声望加, 3)
	return {"触发": true, "类型": "魔道入侵", "声望": 声望加}

## 月度随机彩蛋总调度（在月度推演中调用）
func 月度随机彩蛋(月: float) -> void:
	# 每月5%概率触发宗门级随机彩蛋
	if randf() > 0.05:
		return
	var roll: float = randf()
	if roll < 0.30:
		彩蛋_宗门挑衅()
	elif roll < 0.60:
		彩蛋_散修投奔()
	elif roll < 0.80:
		彩蛋_魔道入侵()
	else:
		# 随机选一名外出弟子触发个人彩蛋
		var 外出弟子: Array = []
		for d in 弟子列表:
			if d is Disciple and d.状态 == "历练":
				外出弟子.append(d)
		if 外出弟子.size() > 0:
			var 幸运儿: Object = 外出弟子[randi() % 外出弟子.size()]
			var 个人roll: float = randf()
			if 个人roll < 0.20:
				彩蛋_路见不平(幸运儿)
			elif 个人roll < 0.35:
				彩蛋_邪修祭炼(幸运儿)
			elif 个人roll < 0.50:
				彩蛋_树下捡功法(幸运儿)
			elif 个人roll < 0.65:
				彩蛋_遇到故人(幸运儿)
			elif 个人roll < 0.80:
				彩蛋_被挑衅(幸运儿)
			else:
				彩蛋_隐世高人(幸运儿)

## 弟子突破连锁反应
## 功法纳入藏经阁：宗主/弟子获得的功法可选择纳入藏经阁，全宗可参悟
var 藏经阁功法列表: Array = []  # 藏经阁中的功法列表（含基础功法+自创功法+宗主纳入的功法）

func 纳入藏经阁(功法ID: String, 功法名称: String, 功法品阶: String, 功法类型: String, 功法效果: String, 纳入者: String = "宗主") -> Dictionary:
	# 检查是否已纳入
	for g in 藏经阁功法列表:
		if str(g.get("id", "")) == 功法ID:
			return {"成功": false, "原因": "该功法已在藏经阁中"}
	# 纳入藏经阁
	var 新功法: Dictionary = {
		"id": 功法ID,
		"名称": 功法名称,
		"品阶": 功法品阶,
		"类型": 功法类型,
		"效果": 功法效果,
		"纳入者": 纳入者,
		"纳入日": 累计游戏日,
		"参悟次数": 0
	}
	藏经阁功法列表.append(新功法)
	添加纪事("庶务", "藏经阁", "%s将《%s》（%s）纳入藏经阁，全宗弟子可参悟！" % [纳入者, 功法名称, 功法品阶], 2)
	return {"成功": true, "功法": 新功法, "原因": "《%s》已纳入藏经阁" % 功法名称}

## 自创功法系统（6.17.1）：筑基期及以上弟子突破时灵光乍现，有概率自创专属功法
func 尝试自创功法(弟子: Disciple) -> Dictionary:
	if 弟子 == null:
		return {"成功": false, "原因": "弟子不存在"}
	# 境界门槛：筑基期及以上才能自创功法
	var 境界顺序: Array = ["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫"]
	var 境界索引: int = 境界顺序.find(弟子.境界)
	if 境界索引 < 1:  # 练气期不能自创
		return {"成功": false, "原因": "境界不足（需筑基期及以上）"}
	# 自创概率：境界越高概率越高（筑基1%，金丹3%，元婴5%，化神8%，炼虚12%，合体15%，大乘20%，渡劫25%）
	var 自创概率: float = 0.01 + float(境界索引) * 0.03
	# 道心加成：道心越高概率越高
	var 道心加成: float = float(弟子.心境) / 100.0 * 0.05
	自创概率 += 道心加成
	自创概率 = min(0.3, 自创概率)  # 最高30%
	if randf() > 自创概率:
		return {"成功": false, "原因": "未触发灵光乍现（概率%.1f%%）" % (自创概率 * 100)}
	# 自创成功！生成功法
	自创功法总数 += 1
	var 功法ID: String = "zichuang_%d_%d" % [弟子.弟子ID, 自创功法总数]
	# 品阶：基于境界，筑基=灵品，金丹=宝品，元婴=王品，化神=圣品，炼虚+=仙品
	var 品阶映射: Dictionary = {1: "灵品", 2: "宝品", 3: "王品", 4: "圣品", 5: "仙品", 6: "仙品", 7: "道品", 8: "道品"}
	var 功法品阶: String = 品阶映射.get(境界索引, "灵品")
	# 功法类型：基于弟子职业/道途
	var 功法类型: String = "攻伐类"
	if 弟子.道途 != "":
		var 道途: String = str(弟子.道途)
		if "剑" in 道途 or "刀" in 道途 or "枪" in 道途:
			功法类型 = "攻伐类"
		elif "体" in 道途 or "锻" in 道途:
			功法类型 = "锻体类"
		elif "丹" in 道途 or "器" in 道途 or "符" in 道途:
			功法类型 = "技艺类"
		elif "心" in 道途 or "道" in 道途:
			功法类型 = "修心类"
	# 功法名称：基于弟子姓名+类型
	var 名称前缀: Array = ["玄", "紫", "太", "元", "灵", "宝", "圣", "仙", "道", "神"]
	var 名称后缀: Dictionary = {"攻伐类": ["剑诀", "刀法", "枪法", "拳法", "掌法", "指诀"], "锻体类": ["炼体诀", "金身诀", "霸体诀", "淬体经"], "技艺类": ["丹经", "器典", "符录", "阵图"], "修心类": ["心经", "道典", "养神经", "悟道诀"], "辅助类": ["护道诀", "长生诀", "回春术", "增益法"]}
	var 后缀列表: Array = 名称后缀.get(功法类型, ["秘法"])
	var 功法名称: String = "%s%s%s" % [名称前缀[randi() % 名称前缀.size()], 弟子.姓名[0] if 弟子.姓名.length() > 0 else "玄", 后缀列表[randi() % 后缀列表.size()]]
	# 功法效果：基于类型和品阶
	var 效果值: float = {"灵品": 0.03, "宝品": 0.05, "王品": 0.08, "圣品": 0.12, "仙品": 0.18, "道品": 0.25}.get(功法品阶, 0.03)
	var 功法效果: String = ""
	match 功法类型:
		"攻伐类":
			功法效果 = "攻击+%.0f%%" % (效果值 * 100)
		"锻体类":
			功法效果 = "防御+%.0f%%，气血+%.0f%%" % [效果值 * 100, 效果值 * 50]
		"技艺类":
			功法效果 = "对应技艺成功率+%.0f%%" % (效果值 * 100)
		"修心类":
			功法效果 = "道心+%.0f，心魔抗性+%.0f%%" % [效果值 * 100, 效果值 * 100]
		_:
			功法效果 = "全属性+%.0f%%" % (效果值 * 50)
	# 元婴以上有概率留个人道韵
	var 有道韵: bool = (境界索引 >= 3 and randf() < 0.3)
	# 创建功法
	var 新功法: Dictionary = {
		"id": 功法ID,
		"名称": 功法名称,
		"品阶": 功法品阶,
		"类型": 功法类型,
		"效果": 功法效果,
		"效果值": 效果值,
		"创始人ID": 弟子.弟子ID,
		"创始人名": 弟子.姓名,
		"创建日": 累计游戏日,
		"道韵": 有道韵,
		"参悟次数": 0
	}
	自创功法列表.append(新功法)
	# 创始人自动学习
	if 弟子.已学功法 == null:
		弟子.已学功法 = []
	弟子.已学功法.append(功法ID)
	# 自创功法自动纳入藏经阁（全宗可参悟）
	纳入藏经阁(功法ID, 功法名称, 功法品阶, 功法类型, 功法效果, 弟子.姓名)
	# 记录纪事
	添加纪事("庶务", "自创功法", "%s突破时灵光乍现，自创%s《%s》（%s）！" % [弟子.姓名, 功法品阶, 功法名称, 功法效果], 3)
	if 有道韵:
		添加纪事("庶务", "自创功法", "%s的《%s》留有个人道韵，后世弟子参悟可获额外加成！" % [弟子.姓名, 功法名称], 3)
	return {"成功": true, "功法": 新功法, "原因": "%s自创《%s》成功！" % [弟子.姓名, 功法名称]}

func _弟子突破连锁反应(突破弟子: Disciple) -> void:
	if 突破弟子 == null:
		return
	var 反应记录: Array = []
	
	# 1. 道侣反应
	if 突破弟子.道侣 != "":
		var 道侣: Disciple = _按姓名找弟子(突破弟子.道侣)
		if 道侣 != null and 道侣.状态 == "在宗":
			道侣.触发情绪("喜悦", 3)
			道侣.增加好感度(str(突破弟子.弟子ID), 5)
			反应记录.append("%s因道侣%s突破而喜悦" % [道侣.姓名, 突破弟子.姓名])
	
	# 2. 子嗣反应
	for 子嗣 in 通婚子嗣系统.子嗣列表:
		if str(子嗣.get("父方ID", "")) == str(突破弟子.弟子ID) or str(子嗣.get("母方ID", "")) == str(突破弟子.弟子ID):
			var 子嗣弟子: Disciple = _按ID找弟子(str(子嗣.get("子嗣ID", "")))
			if 子嗣弟子 != null and 子嗣弟子.状态 == "在宗":
				子嗣弟子.触发情绪("喜悦", 2)
				子嗣弟子.心境 = min(100, 子嗣弟子.心境 + 5)
				反应记录.append("%s因父/母%s突破而喜悦" % [子嗣弟子.姓名, 突破弟子.姓名])
	
	# 3. 道友反应
	for 道友 in 突破弟子.道友列表:
		var 道友弟子: Disciple = _按ID找弟子(str(道友.get("弟子ID", "")))
		if 道友弟子 != null and 道友弟子.状态 == "在宗":
			道友弟子.触发情绪("喜悦", 1)
			道友弟子.增加好感度(str(突破弟子.弟子ID), 2)
			反应记录.append("%s（道友）因%s突破而喜悦" % [道友弟子.姓名, 突破弟子.姓名])
	
	# 4. 仇人反应
	for d in 弟子列表:
		if d == null or not (d is Disciple) or d.状态 != "在宗":
			continue
		var 好感度: int = d.获取好感度(str(突破弟子.弟子ID))
		if 好感度 < 20 and randf() < 0.3:
			d.触发情绪("愤怒", 1)
			d.增加好感度(str(突破弟子.弟子ID), -3)

	# 5. 自创功法触发（6.17.1）：突破时灵光乍现
	尝试自创功法(突破弟子)
	
	for 记录 in 反应记录:
		_加推演条目("◆ " + str(记录), "突破之喜", "低")

## 结成道侣连锁反应
func _结成道侣连锁反应(弟子1: Disciple, 弟子2: Disciple) -> void:
	if 弟子1 == null or 弟子2 == null:
		return
	var 反应记录: Array = []
	
	# 1. 道友祝福
	for 道友 in 弟子1.道友列表:
		var 道友弟子: Disciple = _按ID找弟子(str(道友.get("弟子ID", "")))
		if 道友弟子 != null and 道友弟子.状态 == "在宗":
			道友弟子.触发情绪("喜悦", 1)
			道友弟子.增加好感度(str(弟子1.弟子ID), 2)
			反应记录.append("%s祝福%s与%s结为道侣" % [道友弟子.姓名, 弟子1.姓名, 弟子2.姓名])
	for 道友 in 弟子2.道友列表:
		var 道友弟子: Disciple = _按ID找弟子(str(道友.get("弟子ID", "")))
		if 道友弟子 != null and 道友弟子.状态 == "在宗":
			道友弟子.触发情绪("喜悦", 1)
			道友弟子.增加好感度(str(弟子2.弟子ID), 2)
	
	# 2. 追求者伤心（好感度>70但未婚）
	for d in 弟子列表:
		if d == null or not (d is Disciple) or d.状态 != "在宗":
			continue
		if d.弟子ID == 弟子1.弟子ID or d.弟子ID == 弟子2.弟子ID:
			continue
		if d.道侣 != "":
			continue
		var 对1好感: int = d.获取好感度(str(弟子1.弟子ID))
		var 对2好感: int = d.获取好感度(str(弟子2.弟子ID))
		if (对1好感 > 70 or 对2好感 > 70) and randf() < 0.5:
			d.触发情绪("悲伤", 3)
			if 对1好感 > 70:
				d.增加好感度(str(弟子1.弟子ID), -10)
			if 对2好感 > 70:
				d.增加好感度(str(弟子2.弟子ID), -10)
			反应记录.append("%s因心上人%s结为道侣而伤心" % [d.姓名, 弟子1.姓名])
	
	for 记录 in 反应记录:
		_加推演条目("★ " + str(记录), "道侣之喜", "低")

# ============ 拟真NPC系统 P0-8：弟子关系查看数据接口 ============
## 获取弟子关系网络（用于UI显示）
func 获取弟子关系网络(弟子ID: String) -> Dictionary:
	var d: Disciple = _按ID找弟子(弟子ID)
	if d == null:
		return {}
	
	var 结果: Dictionary = {
		"弟子ID": d.弟子ID,
		"姓名": d.姓名,
		"道侣": d.道侣,
		"道友列表": [],
		"好友列表": [],
		"仇人列表": [],
		"子嗣列表": [],
		"父母": []
	}
	
	# 道友列表
	for 道友 in d.道友列表:
		var 道友ID: String = str(道友.get("弟子ID", ""))
		var 道友弟子: Disciple = _按ID找弟子(道友ID)
		if 道友弟子 != null:
			结果["道友列表"].append({
				"弟子ID": 道友ID,
				"姓名": 道友弟子.姓名,
				"好感度": d.获取好感度(道友ID),
				"关系": "道友"
			})
	
	# 好友/仇人列表
	for 其他 in 弟子列表:
		if 其他 == null or not (其他 is Disciple) or 其他.弟子ID == d.弟子ID:
			continue
		var 好感度: int = d.获取好感度(str(其他.弟子ID))
		if 好感度 > 60 and not d.是道友(str(其他.弟子ID)):
			结果["好友列表"].append({
				"弟子ID": 其他.弟子ID,
				"姓名": 其他.姓名,
				"好感度": 好感度,
				"关系": "好友"
			})
		elif 好感度 < 20:
			结果["仇人列表"].append({
				"弟子ID": 其他.弟子ID,
				"姓名": 其他.姓名,
				"好感度": 好感度,
				"关系": "仇人"
			})
	
	# 子嗣列表
	for 子嗣 in 通婚子嗣系统.子嗣列表:
		if str(子嗣.get("父方ID", "")) == str(d.弟子ID) or str(子嗣.get("母方ID", "")) == str(d.弟子ID):
			var 子嗣弟子: Disciple = _按ID找弟子(str(子嗣.get("子嗣ID", "")))
			var 子嗣名: String = str(子嗣.get("子嗣名", ""))
			if 子嗣弟子 != null:
				子嗣名 = 子嗣弟子.姓名
			结果["子嗣列表"].append({
				"子嗣ID": str(子嗣.get("子嗣ID", "")),
				"姓名": 子嗣名,
				"年龄": int(子嗣.get("年龄", 0)),
				"血脉": str(子嗣.get("血脉", "")),
				"品质": str(子嗣.get("品质", ""))
			})
	
	return 结果

## 获取弟子互动历史（最近10条）
func 获取弟子互动历史(弟子ID: String) -> Array:
	var d: Disciple = _按ID找弟子(弟子ID)
	if d == null:
		return []
	var 结果: Array = []
	for 记忆 in d.记忆列表:
		结果.append({
			"对象ID": str(记忆.get("对象ID", "")),
			"对象名": str(记忆.get("对象名", "")),
			"类型": str(记忆.get("类型", "")),
			"内容": str(记忆.get("内容", "")),
			"好感度影响": int(记忆.get("好感度影响", 0))
		})
	return 结果

## 获取弟子印象评价（对其他弟子的总体印象）
func 获取弟子印象评价(弟子ID: String, 对象ID: String) -> String:
	var d: Disciple = _按ID找弟子(弟子ID)
	if d == null:
		return "未知"
	return d.获取对象印象(对象ID)

## 获取弟子当前心境（性格/情绪/需求）
func 获取弟子心理状态(弟子ID: String) -> Dictionary:
	var d: Disciple = _按ID找弟子(弟子ID)
	if d == null:
		return {}
	return {
		"性格": d.性格,
		"情绪": d.情绪,
		"情绪持续天数": d.情绪持续天数,
		"需求修炼": d.需求修炼,
		"需求社交": d.需求社交,
		"需求休息": d.需求休息,
		"需求安全": d.需求安全,
		"最迫切需求": d.获取最迫切需求(),
		"心境": d.心境,
		"互动计数": d.互动计数
	}
# ============ 拟真NPC系统 P0：弟子日常互动 ============
## 月度门下日常往来（基于需求/性格/情绪）
func _月度弟子日常互动() -> void:
	var 在宗弟子: Array = []
	for d in 弟子列表:
		if d != null and (d is Disciple) and d.状态 == "在宗":
			在宗弟子.append(d)
	
	# 每个弟子需求衰减和情绪衰减
	for d in 在宗弟子:
		d.需求衰减()
		d.情绪衰减()
	
	# 随机配对进行互动（每对弟子30%概率互动）
	var 互动次数: int = 0
	for i in range(在宗弟子.size()):
		for j in range(i + 1, 在宗弟子.size()):
			if randf() > 0.3:
				continue
			var d1: Disciple = 在宗弟子[i]
			var d2: Disciple = 在宗弟子[j]
			
			# 根据需求和性格决定互动类型
			var 互动类型: String = _决定互动类型(d1, d2)
			var 结果: Dictionary = _执行弟子互动(d1, d2, 互动类型)
			if bool(结果.get("成功", false)):
				互动次数 += 1
				# 重大互动记录推演条目
				var 类型: String = str(结果.get("类型", ""))
				if 类型 in ["论道切磋", "口角之争", "馈赠", "施以援手", "义结金兰", "传功授法", "护法守关", "斗法印证", "心魔互诉"]:
					_加推演条目("◇ " + str(结果.get("消息", "")), ET_INFO, PRIO_TRIVIAL)

	# 每100个弟子最多记录1次互动摘要（避免刷屏）
	if 互动次数 > 0 and randf() < 0.1:
		_加推演条目("◇ 本月门下弟子往来%d次" % 互动次数, ET_INFO, PRIO_TRIVIAL)

## 决定往来类型（基于需求/性格/情绪）
func _决定互动类型(d1: Disciple, d2: Disciple) -> String:
	# 计算双方需求
	var d1需求: String = d1.获取最迫切需求()
	var d2需求: String = d2.获取最迫切需求()
	
	# 性格偏好
	var d1偏好: Dictionary = d1.获取性格行为偏好()
	var d2偏好: Dictionary = d2.获取性格行为偏好()
	
	# 情绪效果
	var d1情绪: Dictionary = d1.获取情绪效果()
	var d2情绪: Dictionary = d2.获取情绪效果()
	
	# 好感度
	var 好感度: int = d1.获取好感度(str(d2.弟子ID))
	
	# 计算各互动类型权重
	var 权重: Dictionary = {
		"闲谈": 30.0,
		"论道切磋": 15.0,
		"探讨修为": 20.0,
		"结伴闭关": 10.0,
		"口角之争": 10.0,
		"馈赠": 5.0,
		"施以援手": 10.0,
		# —— 修真味往来（本轮扩充）：基础权重仅作基准，实际由下方条件修正放大/压制 ——
		"传功授法": 8.0,
		"共参道藏": 10.0,
		"护法守关": 6.0,
		"斗法印证": 8.0,
		"心魔互诉": 8.0,
		"义结金兰": 3.0,
		"同祭祖师": 8.0
	}
	
	# 需求修正
	if d1需求 == "社交" or d2需求 == "社交":
		权重["闲谈"] = float(权重["闲谈"]) + 15
		权重["馈赠"] = float(权重["馈赠"]) + 5
	if d1需求 == "修炼" or d2需求 == "修炼":
		权重["探讨修为"] = float(权重["探讨修为"]) + 10
		权重["结伴闭关"] = float(权重["结伴闭关"]) + 10
	if d1需求 == "休息" or d2需求 == "休息":
		权重["闲谈"] = float(权重["闲谈"]) - 5
		权重["论道切磋"] = float(权重["论道切磋"]) - 5
	
	# 性格修正
	权重["论道切磋"] = float(权重["论道切磋"]) * (float(d1偏好.get("冲突概率", 0.08)) + float(d2偏好.get("冲突概率", 0.08))) * 5
	if d1.性格 == "好斗" or d2.性格 == "好斗":
		权重["口角之争"] = float(权重["口角之争"]) + 10
	if d1.性格 == "社交" or d2.性格 == "社交":
		权重["闲谈"] = float(权重["闲谈"]) + 10
	if d1.性格 == "勤奋" or d2.性格 == "勤奋":
		权重["探讨修为"] = float(权重["探讨修为"]) + 10
	
	# 情绪修正
	if d1.情绪 == "愤怒" or d2.情绪 == "愤怒":
		权重["口角之争"] = float(权重["口角之争"]) + 20
		权重["闲谈"] = float(权重["闲谈"]) - 10
	if d1.情绪 == "喜悦" or d2.情绪 == "喜悦":
		权重["闲谈"] = float(权重["闲谈"]) + 10
		权重["馈赠"] = float(权重["馈赠"]) + 5
	if d1.情绪 == "悲伤" or d2.情绪 == "悲伤":
		权重["施以援手"] = float(权重["施以援手"]) + 10
	
	# 好感度修正
	if 好感度 > 80:
		权重["闲谈"] = float(权重["闲谈"]) + 15
		权重["结伴闭关"] = float(权重["结伴闭关"]) + 10
		权重["口角之争"] = float(权重["口角之争"]) - 10
	elif 好感度 < 20:
		权重["口角之争"] = float(权重["口角之争"]) + 15
		权重["闲谈"] = float(权重["闲谈"]) - 10
		权重["馈赠"] = float(权重["馈赠"]) - 5
	
	# —— 修真味往来条件修正：前置不满足时压到近零，等价于该行迹不出现 ——
	var 境界差: int = abs(Disciple.境界索引(d1.境界) - Disciple.境界索引(d2.境界))
	var 高者境: int = max(Disciple.境界索引(d1.境界), Disciple.境界索引(d2.境界))
	# 传功授法：须有境界落差，且授者已入筑基方可言「法」
	if 境界差 >= 1 and 高者境 >= Disciple.境界索引("筑基"):
		权重["传功授法"] = float(权重["传功授法"]) * 3.0
	else:
		权重["传功授法"] = 0.1
	# 心魔互诉：须有人心魔缠身才谈得上倾诉
	if d1.心魔值 >= 30.0 or d2.心魔值 >= 30.0:
		权重["心魔互诉"] = float(权重["心魔互诉"]) * 4.0
	else:
		权重["心魔互诉"] = 0.1
	# 护法守关：须有人将破关或心魔压身（守关才有意义）
	if _处于冲关边缘(d1) or _处于冲关边缘(d2):
		权重["护法守关"] = float(权重["护法守关"]) * 4.0
	else:
		权重["护法守关"] = 0.5
	# 斗法印证：筑基以下道法未成，只能算拳脚切磋
	if 高者境 >= Disciple.境界索引("筑基"):
		权重["斗法印证"] = float(权重["斗法印证"]) * 3.0
	else:
		权重["斗法印证"] = 0.3
	# 义结金兰：情分未到不可结拜
	if 好感度 >= 85:
		权重["义结金兰"] = float(权重["义结金兰"]) * 6.0
	else:
		权重["义结金兰"] = 0.1
	# 心性浅薄者难以静心参玄
	if int(d1.属性.get("心性", 50)) < 30 or int(d2.属性.get("心性", 50)) < 30:
		权重["共参道藏"] = float(权重["共参道藏"]) * 0.4

	# 确保所有权重>=0
	for key in 权重:
		权重[key] = max(0.1, float(权重[key]))
	
	# 加权随机选择
	var 总权重: float = 0.0
	for key in 权重:
		总权重 += float(权重[key])
	var 随机值: float = randf() * 总权重
	var 累计: float = 0.0
	for key in 权重:
		累计 += float(权重[key])
		if 随机值 <= 累计:
			return key
	return "闲谈"

## 执行弟子互动
func _执行弟子互动(d1: Disciple, d2: Disciple, 互动类型: String) -> Dictionary:
	match 互动类型:
		"闲谈":
			return _互动聊天(d1, d2)
		"论道切磋":
			return _互动切磋(d1, d2)
		"探讨修为":
			return _互动讨论修炼(d1, d2)
		"结伴闭关":
			return _互动一起闭关(d1, d2)
		"口角之争":
			return _互动争执(d1, d2)
		"馈赠":
			return _互动送礼(d1, d2)
		"施以援手":
			return _互动帮助(d1, d2)
		"传功授法":
			return _互动传功授法(d1, d2)
		"共参道藏":
			return _互动共参道藏(d1, d2)
		"护法守关":
			return _互动护法守关(d1, d2)
		"斗法印证":
			return _互动斗法印证(d1, d2)
		"心魔互诉":
			return _互动心魔互诉(d1, d2)
		"义结金兰":
			return _互动义结金兰(d1, d2)
		"同祭祖师":
			return _互动同祭祖师(d1, d2)
	return {"成功": false, "因": "未知互动类型"}

## 互动辅助：是否已到冲关边缘（顶层圆满将破境，或心魔压身需人护持）
func _处于冲关边缘(d: Disciple) -> bool:
	if d == null:
		return false
	return (d.层数 >= 10 and d.修炼进度 >= 0.5) or d.心魔值 >= 40.0

## 互动辅助：取境界更高者为授者（同阶则前者充任）
func _择长幼(d1: Disciple, d2: Disciple) -> Array:
	if Disciple.境界索引(d2.境界) > Disciple.境界索引(d1.境界):
		return [d2, d1]
	return [d1, d2]

## 互动：聊天
func _互动聊天(d1: Disciple, d2: Disciple) -> Dictionary:
	d1.满足需求("社交", 10)
	d2.满足需求("社交", 10)
	var 好感增量: int = randi() % 3 + 1
	d1.增加好感度(str(d2.弟子ID), 好感增量)
	d2.增加好感度(str(d1.弟子ID), 好感增量)
	# 添加记忆
	d1.添加记忆(str(d2.弟子ID), d2.姓名, "正面", "与%s愉快聊天" % d2.姓名, 1)
	d2.添加记忆(str(d1.弟子ID), d1.姓名, "正面", "与%s愉快聊天" % d1.姓名, 1)
	return {"成功": true, "类型": "闲谈", "消息": "%s与%s聊天" % [d1.姓名, d2.姓名]}

## 互动：切磋
func _互动切磋(d1: Disciple, d2: Disciple) -> Dictionary:
	d1.满足需求("社交", 15)
	d2.满足需求("社交", 15)
	d1.满足需求("修炼", 5)
	d2.满足需求("修炼", 5)
	var 好感增量: int = randi() % 4 + 2
	d1.增加好感度(str(d2.弟子ID), 好感增量)
	d2.增加好感度(str(d1.弟子ID), 好感增量)
	# 10%概率受伤
	if randf() < 0.1:
		var 受伤者: Disciple = d1 if randf() < 0.5 else d2
		受伤者.触发情绪("愤怒", 2)
		d1.添加记忆(str(d2.弟子ID), d2.姓名, "负面", "切磋时被%s打伤" % d2.姓名, -3)
		d2.添加记忆(str(d1.弟子ID), d1.姓名, "负面", "切磋时打伤%s" % d1.姓名, -2)
		return {"成功": true, "类型": "论道切磋", "消息": "%s与%s切磋，%s受伤" % [d1.姓名, d2.姓名, 受伤者.姓名]}
	d1.添加记忆(str(d2.弟子ID), d2.姓名, "正面", "与%s切磋武艺" % d2.姓名, 2)
	d2.添加记忆(str(d1.弟子ID), d1.姓名, "正面", "与%s切磋武艺" % d1.姓名, 2)
	return {"成功": true, "类型": "论道切磋", "消息": "%s与%s切磋武艺" % [d1.姓名, d2.姓名]}

## 互动：讨论修炼
func _互动讨论修炼(d1: Disciple, d2: Disciple) -> Dictionary:
	d1.满足需求("修炼", 10)
	d2.满足需求("修炼", 10)
	d1.满足需求("社交", 5)
	d2.满足需求("社交", 5)
	var 好感增量: int = randi() % 3 + 1
	d1.增加好感度(str(d2.弟子ID), 好感增量)
	d2.增加好感度(str(d1.弟子ID), 好感增量)
	d1.添加记忆(str(d2.弟子ID), d2.姓名, "正面", "与%s讨论修炼心得" % d2.姓名, 1)
	d2.添加记忆(str(d1.弟子ID), d1.姓名, "正面", "与%s讨论修炼心得" % d1.姓名, 1)
	return {"成功": true, "类型": "探讨修为", "消息": "%s与%s讨论修炼" % [d1.姓名, d2.姓名]}

## 互动：一起闭关
func _互动一起闭关(d1: Disciple, d2: Disciple) -> Dictionary:
	d1.满足需求("修炼", 20)
	d2.满足需求("修炼", 20)
	var 好感增量: int = randi() % 3 + 3
	d1.增加好感度(str(d2.弟子ID), 好感增量)
	d2.增加好感度(str(d1.弟子ID), 好感增量)
	d1.添加记忆(str(d2.弟子ID), d2.姓名, "正面", "与%s一起闭关修炼" % d2.姓名, 3)
	d2.添加记忆(str(d1.弟子ID), d1.姓名, "正面", "与%s一起闭关修炼" % d1.姓名, 3)
	return {"成功": true, "类型": "结伴闭关", "消息": "%s与%s一起闭关" % [d1.姓名, d2.姓名]}

## 互动：争执
func _互动争执(d1: Disciple, d2: Disciple) -> Dictionary:
	var 好感减少: int = randi() % 8 + 3
	d1.增加好感度(str(d2.弟子ID), -好感减少)
	d2.增加好感度(str(d1.弟子ID), -好感减少)
	d1.触发情绪("愤怒", 2)
	d2.触发情绪("愤怒", 2)
	d1.添加记忆(str(d2.弟子ID), d2.姓名, "负面", "与%s发生争执" % d2.姓名, -好感减少)
	d2.添加记忆(str(d1.弟子ID), d1.姓名, "负面", "与%s发生争执" % d1.姓名, -好感减少)
	return {"成功": true, "类型": "口角之争", "消息": "%s与%s发生争执" % [d1.姓名, d2.姓名]}

## 互动：送礼
func _互动送礼(d1: Disciple, d2: Disciple) -> Dictionary:
	d2.满足需求("社交", 20)
	d2.满足需求("安全", 5)
	var 好感增量: int = randi() % 6 + 5
	d1.增加好感度(str(d2.弟子ID), 好感增量)
	d2.增加好感度(str(d1.弟子ID), 好感增量)
	d2.触发情绪("喜悦", 2)
	d1.添加记忆(str(d2.弟子ID), d2.姓名, "正面", "收到%s的礼物" % d2.姓名, 好感增量)
	d2.添加记忆(str(d1.弟子ID), d1.姓名, "正面", "送给%s礼物" % d1.姓名, 好感增量)
	return {"成功": true, "类型": "馈赠", "消息": "%s送给%s礼物" % [d1.姓名, d2.姓名]}

## 互动：帮助
func _互动帮助(d1: Disciple, d2: Disciple) -> Dictionary:
	d2.满足需求("安全", 15)
	d2.满足需求("社交", 10)
	var 好感增量: int = randi() % 6 + 5
	d1.增加好感度(str(d2.弟子ID), 好感增量)
	d2.增加好感度(str(d1.弟子ID), 好感增量)
	d2.触发情绪("喜悦", 3)
	d1.添加记忆(str(d2.弟子ID), d2.姓名, "正面", "帮助了%s" % d2.姓名, 好感增量)
	d2.添加记忆(str(d1.弟子ID), d1.姓名, "正面", "得到%s的帮助" % d1.姓名, 好感增量)
	return {"成功": true, "类型": "施以援手", "消息": "%s帮助了%s" % [d1.姓名, d2.姓名]}

## 互动：传功授法（境界高者为低者讲法，受者道心微固、进度小进）
func _互动传功授法(d1: Disciple, d2: Disciple) -> Dictionary:
	var 长幼: Array = _择长幼(d1, d2)
	var 授者: Disciple = 长幼[0]
	var 受者: Disciple = 长幼[1]
	授者.满足需求("社交", 12)
	受者.满足需求("修炼", 15)
	受者.满足需求("社交", 8)
	var 好感增量: int = randi() % 4 + 3
	授者.增加好感度(str(受者.弟子ID), 好感增量)
	受者.增加好感度(str(授者.弟子ID), 好感增量 + 3)
	# 传法即传心：受者道心稍固；讲者温故知新，心境亦长
	受者.增加道心(1)
	授者.增加心境(1)
	受者.修炼进度 = min(1.0, 受者.修炼进度 + 0.05)
	授者.添加记忆(str(受者.弟子ID), 受者.姓名, "正面", "为%s讲解功法真意" % 受者.姓名, 好感增量)
	受者.添加记忆(str(授者.弟子ID), 授者.姓名, "正面", "得%s指点迷津" % 授者.姓名, 好感增量 + 3)
	return {"成功": true, "类型": "传功授法", "消息": "%s为%s讲解功法真意，%s若有所悟" % [授者.姓名, 受者.姓名, 受者.姓名]}

## 互动：共参道藏（同阅典籍，心境同长，偶有顿悟）
func _互动共参道藏(d1: Disciple, d2: Disciple) -> Dictionary:
	d1.满足需求("修炼", 12)
	d2.满足需求("修炼", 12)
	var 好感增量: int = randi() % 3 + 3
	d1.增加好感度(str(d2.弟子ID), 好感增量)
	d2.增加好感度(str(d1.弟子ID), 好感增量)
	d1.增加心境(1)
	d2.增加心境(1)
	if randf() < 0.25:
		d1.修炼进度 = min(1.0, d1.修炼进度 + 0.03)
		d2.修炼进度 = min(1.0, d2.修炼进度 + 0.03)
	d1.添加记忆(str(d2.弟子ID), d2.姓名, "正面", "与%s同参道藏" % d2.姓名, 好感增量)
	d2.添加记忆(str(d1.弟子ID), d1.姓名, "正面", "与%s同参道藏" % d1.姓名, 好感增量)
	return {"成功": true, "类型": "共参道藏", "消息": "%s与%s共参道藏，各有所悟" % [d1.姓名, d2.姓名]}

## 互动：护法守关（一人冲关，一人护持，屏退外扰）
func _互动护法守关(d1: Disciple, d2: Disciple) -> Dictionary:
	# 更近破关或心魔更重者冲关，另一人护法
	var 冲关者: Disciple = d1
	var 护法者: Disciple = d2
	if (d2.层数 >= 10 and d2.修炼进度 > d1.修炼进度) or d2.心魔值 > d1.心魔值:
		冲关者 = d2
		护法者 = d1
	护法者.满足需求("社交", 10)
	护法者.满足需求("安全", 8)
	冲关者.满足需求("修炼", 18)
	冲关者.满足需求("安全", 15)
	# 护法之德：守关者心境长进；受护者道心稳固、心魔稍退
	护法者.增加心境(1)
	冲关者.增加道心(2)
	if 冲关者.心魔值 > 0.0:
		冲关者.降低心魔(randi() % 4 + 3)
	var 好感增量: int = randi() % 4 + 6
	护法者.增加好感度(str(冲关者.弟子ID), 好感增量)
	冲关者.增加好感度(str(护法者.弟子ID), 好感增量 + 4)
	护法者.添加记忆(str(冲关者.弟子ID), 冲关者.姓名, "正面", "为%s护法守关" % 冲关者.姓名, 好感增量)
	冲关者.添加记忆(str(护法者.弟子ID), 护法者.姓名, "正面", "得%s护法，心无旁骛" % 护法者.姓名, 好感增量 + 4)
	return {"成功": true, "类型": "护法守关", "消息": "%s为%s护法守关，屏退外扰" % [护法者.姓名, 冲关者.姓名]}

## 互动：斗法印证（筑基以上以道法相搏，胜负皆长见识）
func _互动斗法印证(d1: Disciple, d2: Disciple) -> Dictionary:
	d1.满足需求("修炼", 10)
	d2.满足需求("修炼", 10)
	d1.满足需求("社交", 8)
	d2.满足需求("社交", 8)
	# 印证重在心境砥砺，非为胜负
	d1.增加心境(1)
	d2.增加心境(1)
	var 好感增量: int = randi() % 4 + 3
	d1.增加好感度(str(d2.弟子ID), 好感增量)
	d2.增加好感度(str(d1.弟子ID), 好感增量)
	# 斗法有失手之虞：落败者心气受挫，反生心魔
	if randf() < 0.15:
		var 败者: Disciple = d1 if randf() < 0.5 else d2
		var 胜者: Disciple = d2 if 败者 == d1 else d1
		败者.触发情绪("愤怒", 2)
		败者.增加心魔(2)
		败者.添加记忆(str(胜者.弟子ID), 胜者.姓名, "负面", "斗法败于%s之手" % 胜者.姓名, -3)
		胜者.添加记忆(str(败者.弟子ID), 败者.姓名, "正面", "斗法胜%s一筹" % 败者.姓名, 2)
		return {"成功": true, "类型": "斗法印证", "消息": "%s与%s斗法印证，%s稍落下风" % [d1.姓名, d2.姓名, 败者.姓名]}
	d1.添加记忆(str(d2.弟子ID), d2.姓名, "正面", "与%s斗法印证" % d2.姓名, 好感增量)
	d2.添加记忆(str(d1.弟子ID), d1.姓名, "正面", "与%s斗法印证" % d1.姓名, 好感增量)
	return {"成功": true, "类型": "斗法印证", "消息": "%s与%s斗法印证，各有所得" % [d1.姓名, d2.姓名]}

## 互动：心魔互诉（心魔缠身者向同道倾吐，心境得纾）
func _互动心魔互诉(d1: Disciple, d2: Disciple) -> Dictionary:
	# 心魔更重者为诉者
	var 诉者: Disciple = d1
	var 听者: Disciple = d2
	if d2.心魔值 > d1.心魔值:
		诉者 = d2
		听者 = d1
	诉者.满足需求("社交", 20)
	听者.满足需求("社交", 12)
	诉者.降低心魔(randi() % 6 + 5)
	诉者.增加道心(1)
	听者.增加心境(1)
	# 听者心性浅薄，闻他人心魔反受其扰
	if int(听者.属性.get("心性", 50)) < 40:
		听者.增加心魔(2)
	var 好感增量: int = randi() % 5 + 5
	诉者.增加好感度(str(听者.弟子ID), 好感增量)
	听者.增加好感度(str(诉者.弟子ID), 好感增量)
	诉者.添加记忆(str(听者.弟子ID), 听者.姓名, "正面", "向%s倾诉心魔，胸中稍平" % 听者.姓名, 好感增量)
	听者.添加记忆(str(诉者.弟子ID), 诉者.姓名, "正面", "为%s解心魔之困" % 诉者.姓名, 好感增量)
	return {"成功": true, "类型": "心魔互诉", "消息": "%s向%s倾诉心魔之苦，心境稍平" % [诉者.姓名, 听者.姓名]}

## 互动：义结金兰（情分已深，结为异姓手足）
func _互动义结金兰(d1: Disciple, d2: Disciple) -> Dictionary:
	d1.满足需求("社交", 25)
	d2.满足需求("社交", 25)
	d1.触发情绪("喜悦", 3)
	d2.触发情绪("喜悦", 3)
	d1.增加好感度(str(d2.弟子ID), 15)
	d2.增加好感度(str(d1.弟子ID), 15)
	# 结义同心，道心互勉
	d1.增加道心(1)
	d2.增加道心(1)
	d1.添加记忆(str(d2.弟子ID), d2.姓名, "正面", "与%s义结金兰，同气连枝" % d2.姓名, 15)
	d2.添加记忆(str(d1.弟子ID), d1.姓名, "正面", "与%s义结金兰，同气连枝" % d1.姓名, 15)
	return {"成功": true, "类型": "义结金兰", "消息": "%s与%s义结金兰，誓同进退" % [d1.姓名, d2.姓名]}

## 互动：同祭祖师（共祭宗门祖师，追本溯源）
func _互动同祭祖师(d1: Disciple, d2: Disciple) -> Dictionary:
	d1.满足需求("社交", 12)
	d2.满足需求("社交", 12)
	d1.增加道心(1)
	d2.增加道心(1)
	var 好感增量: int = randi() % 4 + 4
	d1.增加好感度(str(d2.弟子ID), 好感增量)
	d2.增加好感度(str(d1.弟子ID), 好感增量)
	d1.添加记忆(str(d2.弟子ID), d2.姓名, "正面", "与%s同祭祖师" % d2.姓名, 好感增量)
	d2.添加记忆(str(d1.弟子ID), d1.姓名, "正面", "与%s同祭祖师" % d1.姓名, 好感增量)
	return {"成功": true, "类型": "同祭祖师", "消息": "%s与%s同祭祖师，追本溯源" % [d1.姓名, d2.姓名]}
# ============ P2 NPC行为模拟（第一阶段：日常作息+位置+简单对话） ============
var _NPC运行时状态: Dictionary = {}  # {npc_id: {位置, 状态, 心情, 上次更新日}}
# NPC工作地点映射（根据身份）
const _NPC工作地点: Dictionary = {
	"盟主": "大殿", "宗主": "大殿", "族长": "大殿", "总会长": "大殿",
	"执法堂堂主": "山门", "器殿堂主": "器殿", "灵兽堂主": "御兽堂",
	"百宝商人": "坊市", "暗市使者": "坊市", "坊市掌柜": "坊市",
	"传令使": "山门", "接引弟子": "山门", "外务执事": "山门", "外使少女": "山门",
	"公会执事": "丹殿", "内务总管": "大殿", "药堂医师": "丹殿", "器殿师傅": "器殿",
	"神秘散修": "后山", "市井艺人": "公共区", "宗门伴侣NPC": "大殿"
}
# NPC状态列表
const _NPC状态列表: Array = ["工作", "休息", "巡逻", "外出"]
# NPC位置列表
# NPC默认对话（根据身份）
const _NPC默认对话: Dictionary = {
	"盟主": ["宗门大事，需从长计议。", "你我同盟，共襄盛举。", "近日局势，你怎么看？"],
	"宗主": ["魔道未除，我辈当自强。", "宗门兴衰，系于你我。", "修炼一途，不可懈怠。"],
	"族长": ["古族传承，不可断绝。", "灵兽通灵，需用心培育。", "上古秘辛，你可知晓？"],
	"总会长": ["丹器一道，殊途同归。", "好材料，才能炼出好东西。", "公会事务，繁忙得很。"],
	"执法堂堂主": ["宗门规矩，不可逾越。", "违法者，必严惩。", "近日可有异动？"],
	"器殿堂主": ["炼器需静心，不可急躁。", "好火，好铁，好手艺。", "你那件法器，该修修了。"],
	"灵兽堂主": ["灵兽有灵，需以诚待之。", "这只灵兽，品相不错。", "培育灵兽，是个慢功夫。"],
	"百宝商人": ["来来来，看看有什么好东西！", "童叟无欺，价格公道。", "这批货，可是稀罕物。"],
	"暗市使者": ["这里的东西，不该问的别问。", "价格嘛，好商量。", "下次有好货，通知你。"],
	"坊市掌柜": ["欢迎光临，需要点什么？", "今日特价，不容错过。", "小店薄利，还请多多关照。"],
	"传令使": ["有消息，我会第一时间通知你。", "近日宗门有何动向？", "跑腿的活，不好干啊。"],
	"接引弟子": ["新来的？跟我来登记。", "宗门规矩，要记牢。", "有什么不懂的，问我。"],
	"外务执事": ["外事繁杂，需谨慎处理。", "近日外交，可有收获？", "宗门颜面，不可丢。"],
	"外使少女": ["外面的世界，很精彩呢。", "我带了些稀罕物，你看看？", "跑了这么远，好累啊。"],
	"公会执事": ["材料上交，有奖励哦。", "宗门差事，需按时了却。", "制作加成，了解一下？"],
	"内务总管": ["宗门事务，井井有条。", "俸禄已发放，请注意查收。", "人事安排，需慎重。"],
	"药堂医师": ["哪里不舒服？我给你看看。", "这副药，按时服用。", "伤病宜早治，不可拖延。"],
	"器殿师傅": ["装备坏了？拿来我修。", "锻造这门手艺，讲究火候。", "你这把武器，该升级了。"],
	"神秘散修": ["机缘巧合，在此相遇。", "我这里有些稀罕物，你可有兴趣？", "云游四方，见多识广。"],
	"市井艺人": ["来来来，听我讲个故事！", "话说当年，有一位仙人……", "打赏个灵石呗？"],
	"宗门伴侣NPC": ["你来了，我等你很久了。", "宗门的事，辛苦了。", "无论何时，我都在你身边。"]
}

## 初始化NPC运行时状态
func _初始化NPC状态() -> void:
	_加载NPC配置()
	for NPC in _NPC配置缓存:
		var NPCID: String = str(NPC.get("npc_id", ""))
		if NPCID == "":
			continue
		if not _NPC运行时状态.has(NPCID):
			var 身份: String = str(NPC.get("identity", ""))
			var 工作地点: String = _NPC工作地点.get(身份, "公共区")
			_NPC运行时状态[NPCID] = {
				"位置": 工作地点,
				"状态": "工作",
				"心情": 70,
				"好感度": 30,  # P2 第二阶段：好感度（0-100）
				"已接任务": "",  # P2 第二阶段：当前已接任务ID
				"任务进度": 0,  # P2 第二阶段：任务进度
				"上次送礼日": 0,  # P2 第二阶段：上次送礼日期（冷却）
				"记忆": [],  # P2 第三阶段：记忆列表（最近10条交互）
				"上次更新日": 累计游戏日
			}

## 更新NPC状态（月度推演调用）
## 历练传讯月度触发（弟子历练中重大事件触发实时传讯）
func _历练传讯月度触发() -> void:
	# 找一个正在历练的弟子
	var 历练中弟子: Array = []
	for d in 弟子列表:
		if d != null and str(d.状态) == "历练中":
			历练中弟子.append(d)
	if 历练中弟子.is_empty():
		return
	var 选中弟子: Object = 历练中弟子[randi() % 历练中弟子.size()]
	# 随机事件类型
	var 事件类型列表: Array = ["遭遇危险", "发现机缘", "获得重宝"]
	var 事件类型: String = 事件类型列表[randi() % 事件类型列表.size()]
	# 区域名称（简化处理）
	var 区域列表: Array = ["蛮荒之地", "深山老林", "东海之滨", "北境雪原", "南疆密林", "仙城闹市"]
	var 区域: String = 区域列表[randi() % 区域列表.size()]
	# 触发传讯
	弟子历练传讯(int(选中弟子.弟子ID), 事件类型, 区域)

func _更新NPC状态(天数: int) -> void:
	_初始化NPC状态()
	for NPCID in _NPC运行时状态.keys():
		var 状态: Dictionary = _NPC运行时状态[NPCID]
		# 每30天有概率改变状态
		if randf() < 0.3:
			var 新状态: String = _NPC状态列表[randi() % _NPC状态列表.size()]
			状态["状态"] = 新状态
			# 根据状态更新位置
			match 新状态:
				"工作":
					var NPC配置: Dictionary = _获取NPC配置(NPCID)
					var 身份: String = str(NPC配置.get("identity", ""))
					状态["位置"] = _NPC工作地点.get(身份, "公共区")
				"休息":
					状态["位置"] = "居所"
				"巡逻":
					状态["位置"] = ["山门", "公共区", "后山"][randi() % 3]
				"外出":
					状态["位置"] = "外出"
		# 心情随机波动（±10）
		var 心情变化: int = randi() % 21 - 10
		状态["心情"] = clamp(int(状态["心情"]) + 心情变化, 20, 100)
		状态["上次更新日"] = 累计游戏日
		_NPC运行时状态[NPCID] = 状态

## 获取NPC配置
func _获取NPC配置(NPCID: String) -> Dictionary:
	_加载NPC配置()
	for NPC in _NPC配置缓存:
		if str(NPC.get("npc_id", "")) == NPCID:
			return NPC
	return {}

## 获取NPC当前状态
func 获取NPC当前状态(NPCID: String) -> Dictionary:
	_初始化NPC状态()
	return _NPC运行时状态.get(NPCID, {"位置": "未知", "状态": "未知", "心情": 50})

## 获取NPC当前位置
func 获取NPC当前位置(NPCID: String) -> String:
	return str(获取NPC当前状态(NPCID).get("位置", "未知"))

## 获取当前在宗门内的NPC列表（可交互）
func 获取可交互NPC列表() -> Array:
	_初始化NPC状态()
	var 结果: Array = []
	for NPCID in _NPC运行时状态.keys():
		var 状态: Dictionary = _NPC运行时状态[NPCID]
		if str(状态.get("位置", "")) != "外出":
			var NPC配置: Dictionary = _获取NPC配置(NPCID)
			结果.append({
				"npc_id": NPCID,
				"名称": str(NPC配置.get("npc_name", "")),
				"身份": str(NPC配置.get("identity", "")),
				"位置": str(状态.get("位置", "")),
				"状态": str(状态.get("状态", "")),
				"心情": int(状态.get("心情", 50))
			})
	return 结果

## 与NPC对话（返回对话内容）
func 与NPC对话(NPCID: String) -> String:
	_初始化NPC状态()
	var NPC配置: Dictionary = _获取NPC配置(NPCID)
	var 身份: String = str(NPC配置.get("identity", ""))
	var 状态: Dictionary = 获取NPC当前状态(NPCID)
	var 心情: int = int(状态.get("心情", 50))
	var 当前状态: String = str(状态.get("状态", ""))
	var 好感度: int = int(状态.get("好感度", 30))
	# 获取对话列表
	var 对话列表: Array = _NPC默认对话.get(身份, ["你好，有什么事吗？", "今日天气不错。", "宗门之事，需谨慎。"])
	# 根据状态选择对话
	var 状态前缀: String = ""
	match 当前状态:
		"工作":
			状态前缀 = ""
		"休息":
			状态前缀 = "（休息中）"
		"巡逻":
			状态前缀 = "（巡逻中）"
		"外出":
			return "此人目前不在宗门内，无法对话。"
	# P2 第二阶段：根据好感度选择对话语气
	var 好感前缀: String = ""
	if 好感度 >= 80:
		好感前缀 = "（亲密）"
	elif 好感度 >= 50:
		好感前缀 = "（友善）"
	elif 好感度 >= 20:
		好感前缀 = "（冷淡）"
	else:
		好感前缀 = "（敌视）"
	# 根据心情选择对话
	var 对话索引: int = randi() % 对话列表.size()
	if 心情 < 40:
		return 状态前缀 + 好感前缀 + "（心情不佳）" + str(对话列表[对话索引])
	elif 心情 > 80:
		return 状态前缀 + 好感前缀 + "（心情愉悦）" + str(对话列表[对话索引])
	else:
		return 状态前缀 + 好感前缀 + str(对话列表[对话索引])

# ============ P2 NPC行为模拟（第二阶段：好感度+任务+礼物+动态对话） ============
# NPC日常任务配置（硬编码，性能友好，每个NPC1个任务）
const _NPC日常任务: Dictionary = {
	"盟主": {"名称": "宗门事务", "类型": "等待", "目标": 3, "奖励灵石": 500, "奖励声望": 50, "描述": "协助处理宗门事务，需3日"},
	"宗主": {"名称": "魔道动向", "类型": "等待", "目标": 5, "奖励灵石": 800, "奖励声望": 80, "描述": "探查魔道动向，需5日"},
	"族长": {"名称": "灵兽培育", "类型": "等待", "目标": 4, "奖励灵石": 600, "奖励声望": 60, "描述": "协助培育灵兽，需4日"},
	"总会长": {"名称": "丹器研讨", "类型": "等待", "目标": 3, "奖励灵石": 500, "奖励声望": 50, "描述": "参与丹器研讨会，需3日"},
	"执法堂堂主": {"名称": "巡逻任务", "类型": "等待", "目标": 2, "奖励灵石": 300, "奖励声望": 40, "描述": "协助宗门巡逻，需2日"},
	"器殿堂主": {"名称": "法器维修", "类型": "消耗灵石", "目标": 200, "奖励灵石": 400, "奖励声望": 40, "描述": "捐赠200灵石用于法器维修"},
	"灵兽堂主": {"名称": "灵兽饲料", "类型": "消耗灵石", "目标": 150, "奖励灵石": 300, "奖励声望": 30, "描述": "捐赠150灵石购买灵兽饲料"},
	"百宝商人": {"名称": "商品收购", "类型": "消耗灵石", "目标": 300, "奖励灵石": 500, "奖励声望": 50, "描述": "以300灵石收购珍稀商品"},
	"暗市使者": {"名称": "暗市情报", "类型": "等待", "目标": 3, "奖励灵石": 600, "奖励声望": 60, "描述": "获取暗市情报，需3日"},
	"坊市掌柜": {"名称": "店铺打理", "类型": "等待", "目标": 2, "奖励灵石": 200, "奖励声望": 20, "描述": "协助打理店铺，需2日"},
	"传令使": {"名称": "消息传递", "类型": "等待", "目标": 1, "奖励灵石": 100, "奖励声望": 20, "描述": "传递宗门消息，需1日"},
	"接引弟子": {"名称": "新徒接待", "类型": "等待", "目标": 2, "奖励灵石": 150, "奖励声望": 20, "描述": "接待新入门弟子，需2日"},
	"外务执事": {"名称": "外交事务", "类型": "等待", "目标": 3, "奖励灵石": 400, "奖励声望": 50, "描述": "处理外交事务，需3日"},
	"外使少女": {"名称": "外出采购", "类型": "等待", "目标": 2, "奖励灵石": 300, "奖励声望": 30, "描述": "外出采购物资，需2日"},
	"公会执事": {"名称": "材料上交", "类型": "消耗灵石", "目标": 100, "奖励灵石": 200, "奖励声望": 20, "描述": "上交100灵石价值的材料"},
	"内务总管": {"名称": "俸禄核算", "类型": "等待", "目标": 1, "奖励灵石": 200, "奖励声望": 30, "描述": "协助核算俸禄，需1日"},
	"药堂医师": {"名称": "药材采集", "类型": "消耗灵石", "目标": 150, "奖励灵石": 300, "奖励声望": 30, "描述": "捐赠150灵石购买药材"},
	"器殿师傅": {"名称": "矿石收购", "类型": "消耗灵石", "目标": 200, "奖励灵石": 350, "奖励声望": 30, "描述": "以200灵石收购矿石"},
	"神秘散修": {"名称": "云游见闻", "类型": "等待", "目标": 5, "奖励灵石": 800, "奖励声望": 80, "描述": "听云游散修讲述见闻，需5日"},
	"市井艺人": {"名称": "说书表演", "类型": "等待", "目标": 1, "奖励灵石": 100, "奖励声望": 10, "描述": "听说书先生讲故事，需1日"},
	"宗门伴侣NPC": {"名称": "相伴时光", "类型": "等待", "目标": 2, "奖励灵石": 0, "奖励声望": 0, "描述": "与伴侣相伴，需2日（好感度+10）"}
}
# NPC喜欢的礼物类型（硬编码，性能友好）
const _NPC喜欢礼物: Dictionary = {
	"盟主": "典籍", "宗主": "兵器", "族长": "灵兽", "总会长": "丹器",
	"执法堂堂主": "兵器", "器殿堂主": "矿石", "灵兽堂主": "灵兽",
	"百宝商人": "灵石", "暗市使者": "奇物", "坊市掌柜": "灵石",
	"传令使": "丹药", "接引弟子": "丹药", "外务执事": "典籍",
	"外使少女": "饰品", "公会执事": "材料", "内务总管": "典籍",
	"药堂医师": "药材", "器殿师傅": "矿石", "神秘散修": "奇物",
	"市井艺人": "灵石", "宗门伴侣NPC": "饰品"
}

## 获取NPC好感度
func 获取NPC好感度(NPCID: String) -> int:
	_初始化NPC状态()
	var 状态: Dictionary = _NPC运行时状态.get(NPCID, {})
	return int(状态.get("好感度", 30))

## 增加NPC好感度（内部调用，性能友好）
func _增加NPC好感度(NPCID: String, 增加量: int) -> void:
	_初始化NPC状态()
	if not _NPC运行时状态.has(NPCID):
		return
	var 状态: Dictionary = _NPC运行时状态[NPCID]
	状态["好感度"] = clamp(int(状态.get("好感度", 30)) + 增加量, 0, 100)
	_NPC运行时状态[NPCID] = 状态

## 获取NPC任务详情
func 获取NPC任务(NPCID: String) -> Dictionary:
	var NPC配置: Dictionary = _获取NPC配置(NPCID)
	var 身份: String = str(NPC配置.get("identity", ""))
	return _NPC日常任务.get(身份, {})

## 获取NPC任务状态（是否已接取/进度）
func 获取NPC任务状态(NPCID: String) -> Dictionary:
	_初始化NPC状态()
	var 状态: Dictionary = _NPC运行时状态.get(NPCID, {})
	var 任务: Dictionary = 获取NPC任务(NPCID)
	if 任务.is_empty():
		return {}
	return {
		"任务": 任务,
		"已接取": str(状态.get("已接任务", "")) != "",
		"进度": int(状态.get("任务进度", 0)),
		"目标": int(任务.get("目标", 1)),
		"可完成": int(状态.get("任务进度", 0)) >= int(任务.get("目标", 1))
	}

## 接取NPC任务
func 接取NPC任务(NPCID: String) -> Dictionary:
	_初始化NPC状态()
	if not _NPC运行时状态.has(NPCID):
		return {"ok": false, "error": "NPC不存在"}
	var 状态: Dictionary = _NPC运行时状态[NPCID]
	if str(状态.get("已接任务", "")) != "":
		return {"ok": false, "error": "已有进行中的差事"}
	var 任务: Dictionary = 获取NPC任务(NPCID)
	if 任务.is_empty():
		return {"ok": false, "error": "此道友暂无差事相托"}
	状态["已接任务"] = NPCID
	状态["任务进度"] = 0
	_NPC运行时状态[NPCID] = 状态
	_增加NPC好感度(NPCID, 2)
	return {"ok": true, "msg": "已接取差事：%s" % str(任务.get("名称", "")), "任务": 任务}

## 推进NPC任务进度（月度推演调用，性能友好）
func _推进NPC任务进度(天数: int) -> void:
	_初始化NPC状态()
	for NPCID in _NPC运行时状态.keys():
		var 状态: Dictionary = _NPC运行时状态[NPCID]
		if str(状态.get("已接任务", "")) == "":
			continue
		var 任务: Dictionary = 获取NPC任务(NPCID)
		if 任务.is_empty():
			continue
		if str(任务.get("类型", "")) == "等待":
			状态["任务进度"] = int(状态.get("任务进度", 0)) + 天数
			_NPC运行时状态[NPCID] = 状态

## 完成NPC任务
func 完成NPC任务(NPCID: String) -> Dictionary:
	_初始化NPC状态()
	if not _NPC运行时状态.has(NPCID):
		return {"ok": false, "error": "NPC不存在"}
	var 状态: Dictionary = _NPC运行时状态[NPCID]
	if str(状态.get("已接任务", "")) == "":
		return {"ok": false, "error": "未接取任务"}
	var 任务: Dictionary = 获取NPC任务(NPCID)
	if int(状态.get("任务进度", 0)) < int(任务.get("目标", 1)):
		return {"ok": false, "error": "任务未完成"}
	# 发放奖励
	var 奖励灵石: int = int(任务.get("奖励灵石", 0))
	var 奖励声望: int = int(任务.get("奖励声望", 0))
	if 奖励灵石 > 0:
		灵石 += 奖励灵石
	if 奖励声望 > 0:
		声望 += 奖励声望
	# 特殊任务：宗门伴侣NPC加好感度
	var NPC配置: Dictionary = _获取NPC配置(NPCID)
	var 身份: String = str(NPC配置.get("identity", ""))
	if 身份 == "宗门伴侣NPC":
		_增加NPC好感度(NPCID, 10)
	else:
		_增加NPC好感度(NPCID, 5)
	# 重置任务状态
	状态["已接任务"] = ""
	状态["任务进度"] = 0
	_NPC运行时状态[NPCID] = 状态
	return {"ok": true, "msg": "差事了却！获得灵石%d、声望%d" % [奖励灵石, 奖励声望], "奖励灵石": 奖励灵石, "奖励声望": 奖励声望}

## 给NPC送礼
func 给NPC送礼(NPCID: String, 礼物类型: String, 礼物价值: int) -> Dictionary:
	_初始化NPC状态()
	if not _NPC运行时状态.has(NPCID):
		return {"ok": false, "error": "NPC不存在"}
	var 状态: Dictionary = _NPC运行时状态[NPCID]
	# 送礼冷却（每日1次）
	if int(状态.get("上次送礼日", 0)) == 累计游戏日:
		return {"ok": false, "error": "今日已送过礼，明日再来"}
	# 检查灵石是否足够
	if 灵石 < 礼物价值:
		return {"ok": false, "error": "灵石不足"}
	# 扣除灵石
	灵石 -= 礼物价值
	# 计算好感度增加（喜欢的礼物×2，普通×1）
	var NPC配置: Dictionary = _获取NPC配置(NPCID)
	var 身份: String = str(NPC配置.get("identity", ""))
	var 喜欢礼物: String = str(_NPC喜欢礼物.get(身份, "灵石"))
	var 好感增加: int = int(礼物价值 / 50)  # 每50灵石价值=1好感度
	if 礼物类型 == 喜欢礼物:
		好感增加 *= 2  # 喜欢的礼物双倍好感度
	好感增加 = clamp(好感增加, 1, 20)  # 单次最多+20
	_增加NPC好感度(NPCID, 好感增加)
	# 更新送礼日期
	状态["上次送礼日"] = 累计游戏日
	_NPC运行时状态[NPCID] = 状态
	return {"ok": true, "msg": "送礼成功！%s好感度+%d" % [str(NPC配置.get("npc_name", "")), 好感增加], "好感增加": 好感增加}

## 获取NPC喜欢的礼物类型
func 获取NPC喜欢礼物(NPCID: String) -> String:
	var NPC配置: Dictionary = _获取NPC配置(NPCID)
	var 身份: String = str(NPC配置.get("identity", ""))
	return str(_NPC喜欢礼物.get(身份, "灵石"))

# ============ P2 NPC行为模拟（第三阶段：记忆+关系+随机事件，轻量化性能优化） ============
# NPC关系配置（硬编码，性能友好，只记录关键关系）
const _NPC关系: Dictionary = {
	"npc_zq001": [{"目标": "npc_zq002", "关系": "上下级", "描述": "凌岳长老是玄清真人的得力助手"}],
	"npc_zq002": [{"目标": "npc_zq001", "关系": "上下级", "描述": "玄清真人是凌岳长老的盟主"}],
	"npc_zl001": [{"目标": "npc_zl002", "关系": "朋友", "描述": "酒剑仙与胡不归是多年酒友"}],
	"npc_zl002": [{"目标": "npc_zl001", "关系": "朋友", "描述": "胡不归与酒剑仙是多年酒友"}],
	"npc_dq001": [{"目标": "npc_dq002", "关系": "同僚", "描述": "墨玄丹尊与欧冶石同为丹器公会高层"}],
	"npc_dq002": [{"目标": "npc_dq001", "关系": "同僚", "描述": "欧冶石与墨玄丹尊同为丹器公会高层"}],
	"npc_mo001": [{"目标": "npc_mo002", "关系": "上下级", "描述": "幽姬是血影魔尊的暗市使者"}],
	"npc_mo002": [{"目标": "npc_mo001", "关系": "上下级", "描述": "血影魔尊是幽姬的宗主"}],
	"npc_yz001": [{"目标": "npc_yz002", "关系": "上下级", "描述": "鹿童长老是青鸾圣姑的灵兽堂主"}],
	"npc_yz002": [{"目标": "npc_yz001", "关系": "上下级", "描述": "青鸾圣姑是鹿童长老的族长"}],
	"npc_sec001": [{"目标": "npc_sec002", "关系": "长辈", "描述": "吴伯看着苏清禾长大"}],
	"npc_sec002": [{"目标": "npc_sec001", "关系": "晚辈", "描述": "苏清禾是吴伯看着长大的"}]
}
# NPC随机事件配置（硬编码，性能友好，5%概率触发）
const _NPC随机事件: Array = [
	{"类型": "偶遇", "描述": "你在宗门内偶遇此人，对方微笑着向你点头致意。", "好感变化": 1},
	{"类型": "求助", "描述": "此人面露难色，似乎遇到了什么困难，需要你的帮助。", "好感变化": 2},
	{"类型": "赠礼", "描述": "此人心情不错，主动赠送给你一些小礼物。", "好感变化": 3, "奖励灵石": 50},
	{"类型": "冲突", "描述": "你与此人发生了一些小摩擦，气氛有些尴尬。", "好感变化": -2},
	{"类型": "指点", "描述": "此人见你修炼遇到瓶颈，主动为你指点了几句。", "好感变化": 2, "奖励声望": 20},
	{"类型": "闲聊", "描述": "你与此人闲聊了一会儿，了解到了一些宗门趣闻。", "好感变化": 1},
	{"类型": "论道切磋", "描述": "你与此人进行了一场友好的切磋，双方都有所收获。", "好感变化": 2, "奖励声望": 10}
]

## 记录NPC记忆（内部调用，性能友好，最多10条）
func _记录NPC记忆(NPCID: String, 交互类型: String, 内容: String) -> void:
	_初始化NPC状态()
	if not _NPC运行时状态.has(NPCID):
		return
	var 状态: Dictionary = _NPC运行时状态[NPCID]
	var 记忆: Array = 状态.get("记忆", [])
	记忆.append({"类型": 交互类型, "内容": 内容, "日期": 累计游戏日})
	# 只保留最近10条
	if 记忆.size() > 10:
		记忆 = 记忆.slice(记忆.size() - 10, 记忆.size())
	状态["记忆"] = 记忆
	_NPC运行时状态[NPCID] = 状态

## 获取NPC记忆（最近10条交互）
func 获取NPC记忆(NPCID: String) -> Array:
	_初始化NPC状态()
	var 状态: Dictionary = _NPC运行时状态.get(NPCID, {})
	return 状态.get("记忆", [])

## 获取NPC关系网络
func 获取NPC关系(NPCID: String) -> Array:
	return _NPC关系.get(NPCID, [])

## 获取关系NPC的名称
func _获取关系NPC名称(关系NPCID: String) -> String:
	var NPC配置: Dictionary = _获取NPC配置(关系NPCID)
	return str(NPC配置.get("npc_name", 关系NPCID))

## 触发NPC随机事件（玩家交互时5%概率触发，性能友好）
func _触发NPC随机事件(NPCID: String) -> Dictionary:
	if randf() > 0.05:  # 5%概率
		return {}
	var 事件: Dictionary = _NPC随机事件[randi() % _NPC随机事件.size()]
	var 结果: Dictionary = {
		"类型": str(事件.get("类型", "")),
		"描述": str(事件.get("描述", "")),
		"好感变化": int(事件.get("好感变化", 0))
	}
	# 应用好感度变化
	var 好感变化: int = int(事件.get("好感变化", 0))
	if 好感变化 != 0:
		_增加NPC好感度(NPCID, 好感变化)
	# 应用奖励
	var 奖励灵石: int = int(事件.get("奖励灵石", 0))
	if 奖励灵石 > 0:
		灵石 += 奖励灵石
		结果["奖励灵石"] = 奖励灵石
	var 奖励声望: int = int(事件.get("奖励声望", 0))
	if 奖励声望 > 0:
		声望 += 奖励声望
		结果["奖励声望"] = 奖励声望
	# 记录记忆
	_记录NPC记忆(NPCID, "事件", str(事件.get("类型", "")) + "：" + str(事件.get("描述", "")))
	return 结果

## 与NPC对话（增强版：记录记忆+随机事件+关系引用）
func 与NPC对话增强(NPCID: String) -> Dictionary:
	_初始化NPC状态()
	var NPC配置: Dictionary = _获取NPC配置(NPCID)
	var 身份: String = str(NPC配置.get("identity", ""))
	var 状态: Dictionary = 获取NPC当前状态(NPCID)
	var 心情: int = int(状态.get("心情", 50))
	var 当前状态: String = str(状态.get("状态", ""))
	var 好感度: int = int(状态.get("好感度", 30))
	# 获取对话列表
	var 对话列表: Array = _NPC默认对话.get(身份, ["你好，有什么事吗？", "今日天气不错。", "宗门之事，需谨慎。"])
	# 根据状态选择对话
	var 状态前缀: String = ""
	match 当前状态:
		"工作":
			状态前缀 = ""
		"休息":
			状态前缀 = "（休息中）"
		"巡逻":
			状态前缀 = "（巡逻中）"
		"外出":
			return {"对话": "此人目前不在宗门内，无法对话。", "事件": {}}
	# 根据好感度选择对话语气
	var 好感前缀: String = ""
	if 好感度 >= 80:
		好感前缀 = "（亲密）"
	elif 好感度 >= 50:
		好感前缀 = "（友善）"
	elif 好感度 >= 20:
		好感前缀 = "（冷淡）"
	else:
		好感前缀 = "（敌视）"
	# 根据心情选择对话
	var 对话索引: int = randi() % 对话列表.size()
	var 对话内容: String = ""
	if 心情 < 40:
		对话内容 = 状态前缀 + 好感前缀 + "（心情不佳）" + str(对话列表[对话索引])
	elif 心情 > 80:
		对话内容 = 状态前缀 + 好感前缀 + "（心情愉悦）" + str(对话列表[对话索引])
	else:
		对话内容 = 状态前缀 + 好感前缀 + str(对话列表[对话索引])
	# 记录记忆
	_记录NPC记忆(NPCID, "对话", 对话内容)
	# 触发随机事件（5%概率）
	var 事件: Dictionary = _触发NPC随机事件(NPCID)
	return {"对话": 对话内容, "事件": 事件}

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
# S31 宣战/领地战：战斗类型 → 占领领地类型；领地模板池（数据驱动，可扩展）
const 战斗类型_领地映射: Dictionary = {"宗门攻防战": "城池", "秘境争夺战": "矿脉", "妖兽围剿战": "秘境", "阵营围剿战": "灵脉"}
# S32 数值重算：月度结算真实频率 = 30 累计游戏日 × 240s = 每 2 现实小时（1 现实天触发 12 次），
#   原值单块 400~1000 灵石/月 ≈ 全宗门月运维上限(318) 的 1.3~3.1 倍 → 印钞机。
#   重算锚点：单块月产 ≈ 宗门月运维的 15%~30%，灵材由 30~60 件降至 2~3 件（原值 1 现实天进 360~720 件必爆库房）。
const 领地模板表: Array = [
	# [名称, 类型, 月灵石, 月灵材, 月声望, 灵材名, 防守线]
	["青冥城", "城池", 70, 0, 2, "", 600],
	["玄清城", "城池", 70, 0, 2, "", 600],
	["天机城", "城池", 70, 0, 2, "", 600],
	["太玄灵脉", "灵脉", 90, 2, 0, "灵脉结晶", 800],
	["九霄灵脉", "灵脉", 90, 2, 0, "灵脉结晶", 800],
	["寒渊灵脉", "灵脉", 90, 2, 0, "灵脉结晶", 800],
	["赤铁矿脉", "矿脉", 45, 3, 0, "玄铁矿石", 400],
	["庚金矿脉", "矿脉", 45, 3, 0, "庚金矿石", 400],
	["紫晶矿脉", "矿脉", 45, 3, 0, "紫晶矿石", 400],
	["上古秘境", "秘境", 35, 2, 1, "天材地宝", 500],
	["残仙秘境", "秘境", 35, 2, 1, "天材地宝", 500],
	["幽墟秘境", "秘境", 35, 2, 1, "天材地宝", 500],
]
# S32 周期常量：玩家层全部锚定现实时间（与日常 86400 / 周常 604800 同源）
const 宣战周期秒: int = 604800          # 现实 7 天 = 一个小周期
const 赛季周期秒: int = 2419200         # 现实 28 天 = 4 周 = 一个大周期
const 宣战周配额基础: int = 12          # 每现实周宣战次数（月卡 +4）
const 领地上限基础: int = 4             # 领地基础上限，门派等级每级 +1
const 领地硬顶: int = 12                # 领地硬上限（对齐贸易 12 城）
const 守军上限: int = 3                 # 单处领地可派驻守军人数
const 领地失守概率_无守军: float = 0.25 # 无守军时周结算失守概率
const 战功_胜: Dictionary = {"宗门攻防战": 60, "秘境争夺战": 50, "妖兽围剿战": 40, "阵营围剿战": 35}
const 战功_败: int = 8                  # 战败安慰战功（不让空手而归）
const 战功_满版图折算: int = 40         # 版图已满时胜利不占领，折算战功
const 战功_领地月产: int = 3            # 每处领地每游戏月产战功
const 战功_硬战倍率: float = 1.5        # 难度系数≥1.0（敌强于我）的战型，胜则战功×1.5
const 周胜场战功阶梯: Array = [[8, 300], [5, 180], [3, 90], [1, 30]]
const 赛季名次战功: Array = [1500, 900, 500, 300, 200]
const 战功赛季保留率: float = 0.5       # 赛季结束战功保留比例（不全清零，避免挫伤长线玩家）
func 发起宗门战(战斗类型: String, 出战队伍: Array, 增益: Dictionary = {}, 守方阵营: String = "") -> Dictionary:
	var 结果: Dictionary = {"ok": false, "error": "", "战报": {}, "奖励文本": ""}
	if not 战斗类型 in ZongmenBattle.BATTLE_TYPES:
		结果["error"] = "未知战斗类型：%s" % 战斗类型
		return 结果
	# P0修复：增加征伐机缘校验
	var 机缘检查: Dictionary = 检查机缘("征伐机缘")
	if not 机缘检查.get("足够", false):
		结果["error"] = "今日征伐机缘已尽（%d/%d），可提升仙缘位阶以增机缘" % [机缘检查.get("已用", 0), 机缘检查.get("上限", 0)]
		return 结果
	if not 消耗机缘("征伐机缘"):
		结果["error"] = "今日征伐机缘已尽"
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
	# S33-4：阵营克制态势 —— 攻方标签 = 玩家立场（正道声望−魔道声望 现算，PROP_23 §5，零持久字段）；
	#   守方标签优先取调用方显式指定（S33-5 的 faction_conflict.csv 走这条），否则按战斗类型默认值。
	var 攻方阵营标签: String = FactionSystem.get_player_stance(阵营声望系统.阵营声望)
	var 守方阵营标签: String = 守方阵营
	if 守方阵营标签 == "":
		守方阵营标签 = ZongmenBattle.resolve_defender_tag(战斗类型, 攻方阵营标签)
	else:
		守方阵营标签 = ZongmenBattle.normalize_faction_tag(守方阵营标签)
	var 状态: Dictionary = ZongmenBattle.create_battle_state(战斗类型, 我方快照队伍, 敌方队伍, 大阵等级, int(float(敌方总战力) * 0.2), 攻方阵营标签, 守方阵营标签)
	# 6 战前增益代入（PRE_BATTLE_BUFFS 常量为准，UI 侧已完成资源扣除）
	for 名 in ZongmenBattle.PRE_BATTLE_BUFFS:
		if not bool(增益.get(名, false)):
			continue
		var 定义: Dictionary = ZongmenBattle.PRE_BATTLE_BUFFS[名] as Dictionary
		# S32b 战功道具硬扣：带「消耗战功道具」的增益由后端扣库存（UI 漏扣也不会无限用），
		#   库存不足则该增益静默不生效，不阻断开战。
		var 道具id: String = str(定义.get("消耗战功道具", ""))
		if 道具id != "":
			if int(战功道具库存.get(道具id, 0)) <= 0:
				continue
			战功道具库存[道具id] = int(战功道具库存.get(道具id, 0)) - 1
			if int(战功道具库存[道具id]) <= 0:
				战功道具库存.erase(道具id)
		状态["攻方增益"].append(定义.duplicate())
	# S45-7：符箓战前增益（主动消费方接入；仅追加至攻方增益，零触碰 72 战斗断言）
	var 符箓增益表: Array = 符箓战前增益(出战队伍)
	for _b in 符箓增益表:
		状态["攻方增益"].append(_b)
	# 毒道：毒傀儡战前施毒（降低敌方攻防，零触碰 72 战斗断言）
	var 毒傀儡毒伤: int = 获取毒傀儡毒伤()
	if 毒傀儡毒伤 > 0:
		var 毒减益: Dictionary = {"名称": "毒傀儡淬毒", "攻击加成": -0.05, "防御加成": -0.05, "持续回合": 5, "毒伤": 毒傀儡毒伤}
		状态["守方增益"].append(毒减益)
		添加纪事("毒道", "战前施毒", "毒傀儡战前施放淬毒，敌方攻防下降，持续5回合。", 2)
	# 毒道：实际毒伤结算（战前施毒直接造成伤害，零触碰 72 战斗断言）
	var 毒道境界: String = 获取毒道境界()
	var 毒体加成: Dictionary = 获取毒体加成()
	if 毒傀儡毒伤 > 0 or 毒道境界 != "毒道学徒":
		var 总毒伤: int = 毒傀儡毒伤 + int(float(毒道境界表.find(毒道境界)) * 20) + int(float(毒体加成["毒伤加成"]) * 100)
		if 总毒伤 > 0:
			# 给敌方每个队员造成毒伤
			var 中毒人数: int = 0
			var 实际毒伤: int = 0
			for 队 in 敌方队伍:
				for 成员 in 队.get("队员", []):
					var 最大生命: int = int(成员.get("最大生命", 100))
					实际毒伤 = min(int(最大生命 * 0.15), 总毒伤)  # 最多扣15%最大生命
					成员["当前生命"] = max(1, int(成员.get("当前生命", 100)) - 实际毒伤)
					中毒人数 += 1
			状态["战斗日志"].append("毒道·战前施毒：敌方%d人中招，每人受到%d点毒素伤害！" % [中毒人数, 实际毒伤])
			添加纪事("毒道", "毒伤结算", "战前施毒生效，敌方%d人中招，每人受到%d点毒素伤害。" % [中毒人数, 实际毒伤], 2)

	# 7 推演 + 战报
	ZongmenBattle.simulate_battle(状态)
	var 战报: Dictionary = ZongmenBattle.generate_battle_report(状态)
	结果["战报"] = 战报
	结果["ok"] = true
	# P1深化：临阵突破触发（宗门战激战中压力激发潜能）
	# 触发条件：总回合数≥8（大战）+ 弟子大圆满 + 瓶颈打磨≥0.8 + 15%概率
	var 宗门战临阵突破: bool = int(战报.get("总回合数", 0)) >= 8 and randf() < 0.15
	if 宗门战临阵突破:
		# 注：GDScript 4 不支持 Python 式 for...else，改用标志位实现「首个符合条件者处理后即止」
		var 已处理: bool = false
		for 队 in 我方队伍:
			if 已处理:
				break
			for d in 队:
				if d is Disciple and d.层数 >= 10 and d.瓶颈打磨值 >= 0.8:
					var 突结: Dictionary = d.临阵突破("战斗")
					if 突结.get("成功", false):
						状态["战斗日志"].append("【临阵突破】%s于宗门大战中突破至%s！" % [d.姓名, d.境界])
					已处理 = true
					break
	# S32 additive：回传双方总战力（generate_battle_report 只给「剩余战力」，宣战需战前口径判硬战）
	结果["我方总战力"] = 我方战力
	结果["敌方总战力"] = 敌方总战力
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

# ============ S31 宣战 / 领地战（在 发起宗门战 基础上包一层持久层）============
# 宣战 = 发起宗门战 的持久化封装：胜则占领对应类型领地（纳入宗门领地按月产出），
# 败则参战弟子情感冲击（联动 S30 忠诚/心境）+ 复用 受伤剩余 进入养伤。
func 宣战(战斗类型: String, 出战队伍: Array, 增益: Dictionary = {}, 目标名: String = "") -> Dictionary:
	# S32 周期闸门：宣战次数按现实周配额限流（原先零冷却零上限 → 可无限连点刷领地）
	_刷新宣战周期_S32()
	var 配额: int = 获取宣战配额()
	if 宣战周已用 >= 配额:
		return {"ok": false, "error": "本周宣战已用尽（%d/%d），下周重置" % [宣战周已用, 配额], "战报": {}, "奖励文本": ""}
	var 结果: Dictionary = 发起宗门战(战斗类型, 出战队伍, 增益)
	if not bool(结果.get("ok", false)):
		return 结果
	宣战周已用 += 1
	var 战报: Dictionary = 结果.get("战报", {})
	var 结果文本: String = str(战报.get("战斗结果", ""))
	var 参战: Array = []
	for 队 in 出战队伍:
		for d in 队:
			if d is Disciple:
				参战.append(d)
	if 结果文本 == "攻方胜利":
		本周宣战胜场 += 1
		var 功: int = int(战功_胜.get(战斗类型, 40))
		# 硬战犒赏：敌方战前总战力高于我方（难度系数≥1.0 的战型）→ 战功×1.5
		if int(结果.get("敌方总战力", 0)) > int(结果.get("我方总战力", 0)):
			功 = int(round(float(功) * 战功_硬战倍率))
		var 上限: int = 获取领地上限()
		if 宗门领地.size() >= 上限:
			# 版图已满：不占领，折算战功（仍鼓励开战挣战功，而非硬禁开战）
			功 += 战功_满版图折算
			_加推演条目("◆ 宣战告捷，然版图已满（%d处），战果折为战功+%d" % [上限, 战功_满版图折算], ET_SECT, PRIO_NORMAL, {})
		else:
			var 类型: String = 战斗类型_领地映射.get(战斗类型, "城池")
			var 模板 = _取领地模板(类型)
			if 模板 != null:
				var 领地: Dictionary = {"名称": 模板[0], "类型": 模板[1], "月灵石": int(模板[2]), "月灵材": int(模板[3]), "月声望": int(模板[4]), "灵材名": str(模板[5]), "防守线": int(模板[6]), "守军": [], "占领日": 累计游戏日}
				宗门领地.append(领地)
				_加推演条目("◆ 宣战告捷，攻占【%s】（%s），自此岁入灵石%d、声望%d" % [str(模板[0]), str(模板[1]), int(模板[2]), int(模板[4])], ET_SECT, PRIO_HIGH, {})
				添加纪事("宗门", "宣战占领", "攻占%s（%s），纳入版图" % [str(模板[0]), str(模板[1])], 2)
				结果["占领领地"] = 领地
		加战功(功)
		结果["战功"] = 功
	else:
		加战功(战功_败)
		结果["战功"] = 战功_败
		var 养伤日: int = 30
		for d in 参战:
			d.增加忠诚(-3)
			d.增加心境(-5)
			if randf() < 0.5:
				d.受伤剩余 = max(int(d.受伤剩余), 养伤日)
		if 结果文本 == "守方胜利":
			_加推演条目("◆ 宣战失利，门下弟子折损，忠心受挫（战功+%d）" % 战功_败, ET_SECT, PRIO_HIGH, {})
			添加纪事("宗门", "宣战失利", "出师未捷，弟子养伤", 1)
	结果["宣战余量"] = max(0, 配额 - 宣战周已用)
	return 结果

# ============ S32 宣战周期 / 战功 / 领地守成 ============
func 加战功(数量: int) -> void:
	if 数量 <= 0:
		return
	战功 += 数量
	赛季累计战功 += 数量

func 获取宣战配额() -> int:
	var 额: int = 宣战周配额基础
	if 月卡有效():
		额 += 4
	return 额

func 获取宣战余量() -> int:
	_刷新宣战周期_S32()
	return max(0, 获取宣战配额() - 宣战周已用)

func 获取领地上限() -> int:
	return min(领地硬顶, 领地上限基础 + max(0, 门派等级 - 1))

# 现实时间周期驱动：挂 推演一月（每游戏日 = 每 240 现实秒调用一次，检测频率足够），
# UI 打开时亦可主动调用，保证离线归来立即补算（while 累加锚点，正确处理长期离线）。
func _刷新宣战周期_S32() -> void:
	var 现在: int = int(Time.get_unix_time_from_system())
	if 上次宣战周真实秒 <= 0:
		上次宣战周真实秒 = 现在
	if 上次赛季真实秒 <= 0:
		上次赛季真实秒 = 现在
	var 补周: int = 0
	while 现在 - 上次宣战周真实秒 >= 宣战周期秒 and 补周 < 60:
		上次宣战周真实秒 += 宣战周期秒
		补周 += 1
		_周结算_S32()
	var 补季: int = 0
	while 现在 - 上次赛季真实秒 >= 赛季周期秒 and 补季 < 24:
		上次赛季真实秒 += 赛季周期秒
		补季 += 1
		_赛季结算_S32()

func _周结算_S32() -> void:
	var 赏: int = 0
	for 档 in 周胜场战功阶梯:
		if 本周宣战胜场 >= int(档[0]):
			赏 = int(档[1])
			break
	if 赏 > 0:
		加战功(赏)
		_加推演条目("★ 周战功犒赏：本周宣战%d胜，战功+%d" % [本周宣战胜场, 赏], ET_SECT, PRIO_HIGH, {})
	_守成判定_S32()
	宣战周已用 = 0
	本周宣战胜场 = 0
	阵营战役周已用 = 0   # S33-5：阵营战役与宣战同周期重置（配额分账，不相互挤占）

func _领地守军战力(领地: Dictionary) -> int:
	var 合计: int = 0
	for 名 in (领地.get("守军", []) as Array):
		for d in 弟子列表:
			if d != null and str(d.姓名) == str(名):
				合计 += int(d.总战力())
				break
	return 合计

# 周结算守成：无守军 25% 失守；有守军但战力低于防守线 → 按缺口比例折算失守概率。
# 失守时守军受伤（复用 受伤剩余）+ 忠诚下滑（联动 S30 情感）。
func _守成判定_S32() -> void:
	var 失守: Array = []
	for i in range(宗门领地.size()):
		var 领: Dictionary = 宗门领地[i]
		var 守军: Array = 领.get("守军", [])
		var 防守线: int = int(领.get("防守线", 500))
		if 守军.is_empty():
			if randf() < 领地失守概率_无守军:
				失守.append(i)
			continue
		var 战力: int = _领地守军战力(领)
		if 战力 < 防守线:
			var 缺口: float = 1.0 - float(战力) / float(max(1, 防守线))
			if randf() < 领地失守概率_无守军 * 缺口:
				失守.append(i)
	失守.reverse()
	for i in 失守:
		var 领: Dictionary = 宗门领地[i]
		for 名 in (领.get("守军", []) as Array):
			for d in 弟子列表:
				if d != null and str(d.姓名) == str(名):
					d.受伤剩余 = max(int(d.受伤剩余), 20)
					d.增加忠诚(-2)
					break
		_加推演条目("◆ 领地【%s】失守，为他宗所夺" % str(领.get("名称", "")), ET_SECT, PRIO_HIGH, {})
		添加纪事("宗门", "领地失守", "%s易主，守军折损" % str(领.get("名称", "")), 1)
		宗门领地.remove_at(i)

func _赛季名次_S32() -> int:
	if 赛季累计战功 >= 3000:
		return 1
	if 赛季累计战功 >= 1800:
		return 2
	if 赛季累计战功 >= 1000:
		return 3
	if 赛季累计战功 >= 400:
		return 4
	return 5

# 赛季结算：先按名次定犒赏，再把存量战功折半承继，最后全额发放犒赏（犒赏不被折半）。
func _赛季结算_S32() -> void:
	var 名次: int = _赛季名次_S32()
	var 赏: int = int(赛季名次战功[min(名次 - 1, 赛季名次战功.size() - 1)])
	战功 = int(round(float(战功) * 战功赛季保留率))
	var 旧季: int = 赛季序号
	加战功(赏)
	赛季序号 += 1
	赛季累计战功 = 0
	_加推演条目("★ 第%d赛季落幕：名列第%d，战功犒赏+%d，余功折半承继" % [旧季, 名次, 赏], ET_SECT, PRIO_HIGH, {})
	添加纪事("宗门", "赛季落幕", "第%d赛季名列第%d，战功+%d" % [旧季, 名次, 赏], 2)

func 派驻守军(领地索引: int, d: Object) -> Dictionary:
	if 领地索引 < 0 or 领地索引 >= 宗门领地.size():
		return {"ok": false, "error": "领地不存在"}
	if d == null or not (d is Disciple):
		return {"ok": false, "error": "弟子不存在"}
	if int(d.受伤剩余) > 0:
		return {"ok": false, "error": "%s正在养伤，不可派驻" % str(d.姓名)}
	for 领 in 宗门领地:
		if str(d.姓名) in (领.get("守军", []) as Array):
			return {"ok": false, "error": "%s已驻守【%s】" % [str(d.姓名), str(领.get("名称", ""))]}
	var 领地: Dictionary = 宗门领地[领地索引]
	if not 领地.has("守军"):
		领地["守军"] = []
	if (领地["守军"] as Array).size() >= 守军上限:
		return {"ok": false, "error": "该处守军已满（%d人）" % 守军上限}
	(领地["守军"] as Array).append(str(d.姓名))
	添加纪事("宗门", "派驻守军", "%s驻守%s" % [str(d.姓名), str(领地.get("名称", ""))], 1)
	弟子变动.emit()
	return {"ok": true, "error": ""}

func 撤回守军(领地索引: int, 姓名: String) -> Dictionary:
	if 领地索引 < 0 or 领地索引 >= 宗门领地.size():
		return {"ok": false, "error": "领地不存在"}
	var 领地: Dictionary = 宗门领地[领地索引]
	var 守军: Array = 领地.get("守军", [])
	var idx: int = 守军.find(姓名)
	if idx < 0:
		return {"ok": false, "error": "该弟子未驻守此地"}
	守军.remove_at(idx)
	弟子变动.emit()
	return {"ok": true, "error": ""}

# ============ S33-5 阵营战役（正魔大战 P0-3，config/faction_conflict.csv 数据驱动）============
# 与 S31 宣战的分工：宣战 = 打领地（占版图、按月产出），阵营战役 = 打阵营立场
# （产战功 + 阵营声望，胜亦不占领地）。两者配额分账、互不挤占，且战役不能绕过
# 领地上限刷版图。守方阵营标签直接喂 发起宗门战 第4参 → 激活 S33-4 非对称克制乘区。
const 阵营战役表路径: String = "res://config/faction_conflict.csv"
const 阵营战役周配额基础: int = 6      # 每现实周出征次数（月卡 +2）；6×~50 战功/周，仅及宣战路径一半，不印钵
const 阵营战役首胜声望倍率: float = 2.0 # 每条战役首次告捷声望翻倍（一次性，鼓励打通全部战役）

func _读阵营战役() -> Array:
	if not _阵营战役缓存.is_empty():
		return _阵营战役缓存
	for r in DestinyDataLoader._read_csv(阵营战役表路径):
		var 战型: String = str(r.get("battle_type", ""))
		if not 战型 in ZongmenBattle.BATTLE_TYPES:
			continue
		_阵营战役缓存.append({
			"id": str(r.get("conflict_id", "")),
			"阵营id": str(r.get("faction_id", "")),
			"阵营": str(r.get("faction", "")),
			"守方阵营": str(r.get("enemy_tag", "")),
			"名称": str(r.get("conflict_name", "")),
			"战斗类型": 战型,
			"门槛等级": str(r.get("unlock_reputation", "冷淡")),
			"耗灵石": int(str(r.get("cost_lingshi", "0"))),
			"声望奖励": int(str(r.get("reward_reputation", "0"))),
			"说明": str(r.get("description", "")),
		})
	return _阵营战役缓存

# 门槛以声望「等级名」配置（与 faction_quests 同口径），运行时翻译为阀值，避开 CSV 硬编码数值漂移
func _阵营战役门槛(战役: Dictionary) -> int:
	var 序: int = FactionSystem.REPUTATION_LEVELS.find(str(战役.get("门槛等级", "冷淡")))
	if 序 < 0:
		return 0
	return int(FactionSystem.REPUTATION_THRESHOLDS[序])

func 获取阵营战役配额() -> int:
	var 额: int = 阵营战役周配额基础
	if 月卡有效():
		额 += 2
	return 额

func 获取阵营战役余量() -> int:
	_刷新宣战周期_S32()
	return max(0, 获取阵营战役配额() - 阵营战役周已用)

# UI 视图：每条战役附「是否解锁/当前声望/基准战功/累计告捷」，避免 UI 自行推算规则
func 获取阵营战役列表() -> Array:
	var 出: Array = []
	for c in _读阵营战役():
		var 阵: String = str(c.get("阵营", ""))
		var 需: int = _阵营战役门槛(c)
		var 现: int = int(阵营声望系统.阵营声望.get(阵, 0))
		var 项: Dictionary = c.duplicate(true)
		项["需声望"] = 需
		项["当前声望"] = 现
		项["已解锁"] = 现 >= 需
		项["基准战功"] = int(战功_胜.get(str(c.get("战斗类型", "")), 40))
		项["告捷次数"] = int(阵营战役战绩.get(str(c.get("id", "")), 0))
		出.append(项)
	return 出

# 出征：声望门槛 → 周配额 → 灵石硬扣（开打失败则原额退回）→ 宗门战引擎（带守方阵营标签）→ 战功/声望结算
func 发起阵营战役(战役id: String, 出战队伍: Array, 增益: Dictionary = {}) -> Dictionary:
	_刷新宣战周期_S32()
	var 战役: Dictionary = {}
	for c in _读阵营战役():
		if str(c.get("id", "")) == 战役id:
			战役 = c
			break
	if 战役.is_empty():
		return {"ok": false, "error": "未知阵营战役：%s" % 战役id, "战报": {}, "奖励文本": ""}
	var 阵: String = str(战役.get("阵营", ""))
	var 需: int = _阵营战役门槛(战役)
	if int(阵营声望系统.阵营声望.get(阵, 0)) < 需:
		return {"ok": false, "error": "%s声望不足（%d/%d）" % [阵, int(阵营声望系统.阵营声望.get(阵, 0)), 需], "战报": {}, "奖励文本": ""}
	var 配额: int = 获取阵营战役配额()
	if 阵营战役周已用 >= 配额:
		return {"ok": false, "error": "本周阵营战役已用尽（%d/%d），下周重置" % [阵营战役周已用, 配额], "战报": {}, "奖励文本": ""}
	var 耗: int = int(战役.get("耗灵石", 0))
	if 灵石 < 耗:
		return {"ok": false, "error": "出征需灵石%d（现有%d）" % [耗, 灵石], "战报": {}, "奖励文本": ""}
	# 先扣后打：战斗未能开打则原额退回（不留吞钱窗口）
	灵石 -= 耗
	var 结果: Dictionary = 发起宗门战(str(战役.get("战斗类型", "")), 出战队伍, 增益, str(战役.get("守方阵营", "")))
	if not bool(结果.get("ok", false)):
		灵石 += 耗
		return 结果
	阵营战役周已用 += 1
	结果["战役id"] = 战役id
	结果["战役名"] = str(战役.get("名称", ""))
	结果["耗灵石"] = 耗
	var 战报: Dictionary = 结果.get("战报", {})
	var 参战: Array = []
	for 队 in 出战队伍:
		for d in 队:
			if d is Disciple:
				参战.append(d)
	if str(战报.get("战斗结果", "")) == "攻方胜利":
		var 功: int = int(战功_胜.get(str(战役.get("战斗类型", "")), 40))
		if int(结果.get("敌方总战力", 0)) > int(结果.get("我方总战力", 0)):
			功 = int(round(float(功) * 战功_硬战倍率))
		加战功(功)
		var 望: int = int(战役.get("声望奖励", 0))
		var 首胜: bool = int(阵营战役战绩.get(战役id, 0)) <= 0
		if 首胜:
			望 = int(round(float(望) * 阵营战役首胜声望倍率))
		阵营战役战绩[战役id] = int(阵营战役战绩.get(战役id, 0)) + 1
		# 声望变动走已有 增加阵营声望（内建对立阵营 −30% 衰减）→ 正魔此消彼长自洽，零新逻辑
		增加阵营声望(阵, 望)
		结果["战功"] = 功
		结果["声望奖励"] = 望
		结果["首胜"] = 首胜
		_加推演条目("◆ %s告捷：战功+%d，%s声望+%d%s" % [str(战役.get("名称", "")), 功, 阵, 望, "（首捷双赏）" if 首胜 else ""], ET_SECT, PRIO_HIGH, {})
		添加纪事("宗门", "阵营战役", "%s告捷，战功+%d、%s声望+%d" % [str(战役.get("名称", "")), 功, 阵, 望], 2)
	else:
		加战功(战功_败)
		结果["战功"] = 战功_败
		结果["声望奖励"] = 0
		结果["首胜"] = false
		for d in 参战:
			d.增加忠诚(-3)
			d.增加心境(-5)
			if randf() < 0.5:
				d.受伤剩余 = max(int(d.受伤剩余), 30)
		_加推演条目("◆ %s失利，弟子折损养伤（战功+%d）" % [str(战役.get("名称", "")), 战功_败], ET_SECT, PRIO_HIGH, {})
		添加纪事("宗门", "阵营战役", "%s失利，弟子养伤" % str(战役.get("名称", "")), 1)
	结果["战役余量"] = max(0, 配额 - 阵营战役周已用)
	return 结果

# ============ S32 战功商店（config/battle_merit_shop.csv 数据驱动）============
# 丹药一律使用 AlchemySystem.丹药效果 中已存在的真名，入宗门库房后由既有
# _应用丹药效果 / 弟子自动服用丹药 链路消费——零新逻辑，不造假功能。
func _读战功商店() -> Array:
	if not _战功商店缓存.is_empty():
		return _战功商店缓存
	var f: FileAccess = FileAccess.open("res://config/battle_merit_shop.csv", FileAccess.READ)
	if f == null:
		return []
	var 首行: bool = true
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line == "":
			continue
		if 首行:
			首行 = false
			continue
		var p: PackedStringArray = line.split(",")
		if p.size() < 7:
			continue
		_战功商店缓存.append({
			"id": str(p[0]), "名称": str(p[1]), "类别": str(p[2]),
			"价格": int(str(p[3])), "数量": int(str(p[4])),
			"品阶": str(p[5]), "说明": str(p[6]),
		})
	f.close()
	return _战功商店缓存

func 兑换战功商品(商品id: String) -> Dictionary:
	var 目: Dictionary = {}
	for it in _读战功商店():
		if str(it.get("id", "")) == 商品id:
			目 = it
			break
	if 目.is_empty():
		return {"ok": false, "error": "无此商品"}
	var 价: int = int(目.get("价格", 0))
	if 战功 < 价:
		return {"ok": false, "error": "战功不足（%d/%d）" % [战功, 价]}
	战功 -= 价
	var 类别: String = str(目.get("类别", ""))
	var 数量: int = max(1, int(目.get("数量", 1)))
	var 名: String = str(目.get("名称", ""))
	if 类别 == "战斗道具":
		战功道具库存[商品id] = int(战功道具库存.get(商品id, 0)) + 数量
	else:
		for i in range(数量):
			var it2: Item = Item.new()
			it2.名称 = 名
			it2.品阶 = str(目.get("品阶", "灵阶"))
			it2.类别 = "丹药"
			it2.描述 = str(目.get("说明", ""))
			it2.功效 = str(AlchemySystem.丹药效果.get(名, {}).get("描述", ""))
			宗门库房.append(it2)
	添加纪事("宗门", "战功兑换", "耗战功%d兑换%s×%d" % [价, 名, 数量], 1)
	return {"ok": true, "error": "", "名称": 名, "数量": 数量}


func _取领地模板(类型: String) -> Variant:
	var 候选: Array = []
	for t in 领地模板表:
		if str(t[1]) == 类型:
			候选.append(t)
	if 候选.is_empty():
		return null
	return 候选[randi() % 候选.size()]

func _添加灵材(数量: int, 名称: String = "灵材") -> void:
	# S31 领地矿脉/灵脉/秘境月产灵材入宗门库房（类别=材料）
	for i in range(数量):
		var it: Item = Item.new()
		it.名称 = 名称
		it.品阶 = "灵品"
		it.类别 = "材料"
		it.描述 = "领地开采所得灵材"
		宗门库房.append(it)

func _结算宗门领地_S1() -> void:
	if 宗门领地.is_empty():
		return
	var 总灵石: int = 0
	var 总声望: int = 0
	for 领 in 宗门领地:
		总灵石 += int(领.get("月灵石", 0))
		总声望 += int(领.get("月声望", 0))
		var 灵材数: int = int(领.get("月灵材", 0))
		if 灵材数 > 0:
			_添加灵材(灵材数, str(领.get("灵材名", "灵材")))
	if 总灵石 > 0:
		灵石 += 总灵石
	if 总声望 > 0:
		_加声望(总声望)
	# S32 领地亦产战功（每处每游戏月）
	加战功(战功_领地月产 * 宗门领地.size())
	if 总灵石 > 0 or 总声望 > 0:
		_加推演条目("◇ 领地岁入：灵石+%d 声望+%d（共%d处领地）" % [总灵石, 总声望, 宗门领地.size()], ET_SECT, PRIO_NORMAL, {})
# ============================================================
# S34 凡人王朝：王朝周期引擎（GDD: design/03-系统设计/GDD-凡人王朝.md）
# 定位：玩家是王朝的「客卿」——影响王朝，不统治王朝（称帝建国属 S35 沙盒）
# 三铁律①：新增持久字段必须同时改 存档 / 读档 / new_game 三处
# ============================================================
const 王朝国号池: Array = ["大胤", "大景", "大乾", "大晟", "大雍", "大昭", "大宁", "大梁"]
const 王朝帝姓池: Array = ["姬", "轩辕", "南宫", "慕容", "赵", "李", "独孤", "宇文"]
const 王朝帝名池: Array = ["昌", "煜", "珩", "玄", "熙", "瑾", "珏", "渊", "澈", "晏"]
const 王朝性格池: Array = ["守成", "雄才", "昏聩", "多疑", "仁厚"]
const 王朝阶段序: Array = ["开国", "盛世", "中衰", "乱世"]   # 唯一真源：国祚递降顺序
# 配置懒加载（复用项目 CSV 解析惯例：_CSV去BOM）

# ===== 凡人王朝系统（已拆分到dynasty_system.gd，此处为转发函数）=====
func _读王朝配置():
	return 王朝系统._读王朝配置()
func _读王朝阶段表():
	return 王朝系统._读王朝阶段表()
func _读差事模板表():
	return 王朝系统._读差事模板表()
func _王朝阶段配置(阶段名: String):
	return 王朝系统._王朝阶段配置(阶段名)
func _王朝国策配置(国策名: String):
	return 王朝系统._王朝国策配置(国策名)
func _新王朝(朝代序: int):
	return 王朝系统._新王朝(朝代序)
func _初始化郡县状态_S34():
	王朝系统._初始化郡县状态_S34()
func _凡俗郡县数_S34():
	return 王朝系统._凡俗郡县数_S34()
func _新帝继位_S34(驾崩: bool):
	王朝系统._新帝继位_S34(驾崩)
func _生成皇子_S34():
	王朝系统._生成皇子_S34()
func _择储_S34(表: Array):
	return 王朝系统._择储_S34(表)
func 押注继承人_S34(皇子ID: String):
	return 王朝系统.押注继承人_S34(皇子ID)
func _结算继承押注_S34(继位ID: String):
	王朝系统._结算继承押注_S34(继位ID)
func _可调停民变_S34():
	return 王朝系统._可调停民变_S34()
func _改朝换代_S34():
	王朝系统._改朝换代_S34()

# ===== P1联动：凡人王朝 × 宗门系统 =====
# 获取宗门爵位加成（爵位越高，王朝委托奖励越多）
func 获取宗门爵位加成() -> float:
	var 爵位: String = "未册封"
	if 王朝系统.王朝 != null:
		爵位 = str(王朝系统.王朝.get("宗门爵位", "未册封"))
	var 爵位加成: Dictionary = {
		"未册封": 1.0,
		"九品": 1.1,
		"八品": 1.2,
		"七品": 1.3,
		"六品": 1.4,
		"五品": 1.5,
		"四品": 1.6,
		"三品": 1.8,
		"二品": 2.0,
		"一品": 2.5,
	}
	return float(爵位加成.get(爵位, 1.0))

# 王朝委托完成奖励（宗门声望+资源）
func 王朝委托完成奖励(委托ID: String, 基础奖励: Dictionary) -> Dictionary:
	var 爵位加成: float = 获取宗门爵位加成()
	var 声望奖励: int = int(float(基础奖励.get("声望", 100)) * 爵位加成)
	var 灵石奖励: int = int(float(基础奖励.get("灵石", 500)) * 爵位加成)
	var 灵气奖励: int = int(float(基础奖励.get("灵气", 50)) * 爵位加成)
	# 发放奖励
	声望 += 声望奖励
	灵石 += 灵石奖励
	灵气 += 灵气奖励
	# 添加纪事
	添加纪事("王朝", "委托完成", "完成王朝委托「%s」，获得声望+%d，灵石+%d，灵气+%d（爵位加成%.1f倍）" % [委托ID, 声望奖励, 灵石奖励, 灵气奖励, 爵位加成], 0)
	_加推演条目("【王朝】完成王朝委托「%s」，宗门声望大增" % 委托ID, "王朝", "中")
	return {"声望": 声望奖励, "灵石": 灵石奖励, "灵气": 灵气奖励, "爵位加成": 爵位加成}
func _刷新郡县忠顺_S34():
	王朝系统._刷新郡县忠顺_S34()
func _推进王朝阶段_S34():
	王朝系统._推进王朝阶段_S34()
func _读开国表():
	return 王朝系统._读开国表()
func _开国配置(id: String):
	return 王朝系统._开国配置(id)
func _开国表(kind: String):
	return 王朝系统._开国表(kind)
func _开国路线缺口(配: Dictionary):
	return 王朝系统._开国路线缺口(配)
func 开国路线状态_S34():
	return 王朝系统.开国路线状态_S34()
func 开国选项_S34():
	return 王朝系统.开国选项_S34()
func 建立新朝_S34(答案: Dictionary):
	return 王朝系统.建立新朝_S34(答案)
func _开国建制系数_S34(郡: Dictionary):
	return 王朝系统._开国建制系数_S34(郡)
func _开国苗子系数_S34():
	return 王朝系统._开国苗子系数_S34()
func _开国战功系数_S34():
	return 王朝系统._开国战功系数_S34()
func _开国民心月修正_S34():
	return 王朝系统._开国民心月修正_S34()
func _读传送阵表():
	return 王朝系统._读传送阵表()
func _传送距离(城: Dictionary):
	return 王朝系统._传送距离(城)
func _传送阵补缺():
	王朝系统._传送阵补缺()
func 已建传送阵():
	return 王朝系统.已建传送阵()
func 传送阵当前档():
	return 王朝系统.传送阵当前档()
func 传送阵可达城邦():
	return 王朝系统.传送阵可达城邦()
func 传送阵建造信息():
	return 王朝系统.传送阵建造信息()
func 建造传送阵():
	return 王朝系统.建造传送阵()
func _推进传送阵建造():
	王朝系统._推进传送阵建造()
func _推进传送阵待机_S34(天: int):
	王朝系统._推进传送阵待机_S34(天)
func _物品传送重量(it):
	return 王朝系统._物品传送重量(it)
func _物品传送价值(it):
	return 王朝系统._物品传送价值(it)
func 传送调度(城市ID: String, 货物索引: Array):
	return 王朝系统.传送调度(城市ID, 货物索引)
func _今日序号():
	return 王朝系统._今日序号()
func _加朝报(类型: String, 标题: String, 正文: String = "", 重要度: int = 1):
	王朝系统._加朝报(类型, 标题, 正文, 重要度)
func 标记朝报已读():
	王朝系统.标记朝报已读()
func _读祥瑞表():
	return 王朝系统._读祥瑞表()
func _读朝奏表():
	return 王朝系统._读朝奏表()
func _随机凡俗郡():
	return 王朝系统._随机凡俗郡()
func _祥瑞文(模板: String, 郡id: String):
	return 王朝系统._祥瑞文(模板, 郡id)
func _郡键(英文: String):
	return 王朝系统._郡键(英文)
func _推进祥瑞_S34():
	王朝系统._推进祥瑞_S34()
func _施加祥瑞效果(配: Dictionary, 郡id: String):
	return 王朝系统._施加祥瑞效果(配, 郡id)
func _生成朝奏_S34():
	王朝系统._生成朝奏_S34()
func _推进朝奏_S34():
	王朝系统._推进朝奏_S34()
func 应对朝奏_S34(索引: int):
	return 王朝系统.应对朝奏_S34(索引)
func _施加朝奏效果(编码: String, 郡id: String):
	return 王朝系统._施加朝奏效果(编码, 郡id)
func _保底邸报_S34():
	王朝系统._保底邸报_S34()
func _读表_香火庙():
	return 王朝系统._读表_香火庙()
func _读表_异端():
	return 王朝系统._读表_异端()
func _读表_国教():
	return 王朝系统._读表_国教()
func _香火庙档(等级: int):
	return 王朝系统._香火庙档(等级)
func _国教配置():
	return 王朝系统._国教配置()
func _异端配置(id: String):
	return 王朝系统._异端配置(id)
func _香火庙信息(郡id: String):
	return 王朝系统._香火庙信息(郡id)
func _郡信仰取(郡id: String):
	return 王朝系统._郡信仰取(郡id)
func 香火庙等级(郡id: String):
	return 王朝系统.香火庙等级(郡id)
func _香火庙覆盖人口(郡id: String):
	return 王朝系统._香火庙覆盖人口(郡id)
func 香火庙建造信息(郡id: String):
	return 王朝系统.香火庙建造信息(郡id)
func 建造香火庙(郡id: String):
	return 王朝系统.建造香火庙(郡id)
func _推进香火庙建造():
	王朝系统._推进香火庙建造()
func _香火庙维护总额_S34():
	return 王朝系统._香火庙维护总额_S34()
func _抽异端主():
	return 王朝系统._抽异端主()
func _推进信仰_S34():
	王朝系统._推进信仰_S34()
func _信仰供奉系数_S34(郡: Dictionary):
	return 王朝系统._信仰供奉系数_S34(郡)
func _信仰苗子系数_S34(郡id: String):
	return 王朝系统._信仰苗子系数_S34(郡id)
func _信仰香火日产_S34():
	return 王朝系统._信仰香火日产_S34()
func _信仰愿力月产_S34():
	return 王朝系统._信仰愿力月产_S34()
func _信仰民心月修正_S34():
	return 王朝系统._信仰民心月修正_S34()
func 信仰总览_S34():
	return 王朝系统.信仰总览_S34()
func _信仰补缺():
	王朝系统._信仰补缺()
func _结算王朝_S34():
	王朝系统._结算王朝_S34()
func _取弟子_S34(弟子ID: String):
	return 王朝系统._取弟子_S34(弟子ID)
func _分配弟子故乡郡(弟子: Disciple):
	王朝系统._分配弟子故乡郡(弟子)
func 决策办差奇遇(索引: int, 选项索引: int):
	return 王朝系统.决策办差奇遇(索引, 选项索引)
func _弟子在故乡办差(弟子: Disciple, 郡id: String):
	return 王朝系统._弟子在故乡办差(弟子, 郡id)
func _刷新凡间差事榜_S34():
	王朝系统._刷新凡间差事榜_S34()
func 接取凡间差事_S34(差事ID: String, 弟子ID: String):
	return 王朝系统.接取凡间差事_S34(差事ID, 弟子ID)
func _推进凡间差事_S34(天: int):
	王朝系统._推进凡间差事_S34(天)
func 获取所有奇观列表():
	return 王朝系统.获取所有奇观列表()
func 开始建造奇观(奇观ID: String):
	return 王朝系统.开始建造奇观(奇观ID)
func 推进奇观建造_S34(月数: int):
	王朝系统.推进奇观建造_S34(月数)
func _检查奇观里程碑(奇观ID: String):
	王朝系统._检查奇观里程碑(奇观ID)
func 获取奇观总效果():
	return 王朝系统.获取奇观总效果()
func _检查王朝里程碑():
	王朝系统._检查王朝里程碑()
func _结算凡间差事_S34(差事ID: String):
	王朝系统._结算凡间差事_S34(差事ID)
func _寻访灵根得苗子_S34(郡id: String):
	王朝系统._寻访灵根得苗子_S34(郡id)
func _尝试王朝事件_S34():
	王朝系统._尝试王朝事件_S34()
func _王朝补缺_S34():
	王朝系统._王朝补缺_S34()
func _读反制配置():
	return 王朝系统._读反制配置()
func _反制配置(反制ID: String):
	return 王朝系统._反制配置(反制ID)
func _供奉月收入_S34():
	return 王朝系统._供奉月收入_S34()
func _反制成本_S34(配: Dictionary):
	return 王朝系统._反制成本_S34(配)
func _解析转化效果_S34(文本: String):
	return 王朝系统._解析转化效果_S34(文本)
func _施加转化效果_S34(效: Array, 郡id: String):
	王朝系统._施加转化效果_S34(效, 郡id)
func _反制触发判定_S34(配: Dictionary, 郡id: String):
	return 王朝系统._反制触发判定_S34(配, 郡id)
func _反制预警判定_S34(配: Dictionary, 郡id: String):
	return 王朝系统._反制预警判定_S34(配, 郡id)
func _读委托模板表():
	return 王朝系统._读委托模板表()
func _须应征调_S34():
	return 王朝系统._须应征调_S34()
func _结算王朝委托_S34():
	王朝系统._结算王朝委托_S34()
func _推进委托_S34(天: int):
	王朝系统._推进委托_S34(天)
func 应对王朝委托_S34(实例ID: String, 选择: String, 弟子ID: String = ""):
	return 王朝系统.应对王朝委托_S34(实例ID, 选择, 弟子ID)
func _结算委托后果_S34(项: Dictionary, 模式: String):
	王朝系统._结算委托后果_S34(项, 模式)
func _移除委托(项: Dictionary):
	王朝系统._移除委托(项)
func _读拍卖配置表():
	return 王朝系统._读拍卖配置表()
func _拍卖配置浮(param: String, 默认: float):
	return 王朝系统._拍卖配置浮(param, 默认)
func _读拍卖AI表():
	return 王朝系统._读拍卖AI表()
func _拍卖当前等级():
	return 王朝系统._拍卖当前等级()
func _拍卖当前佣金率():
	return 王朝系统._拍卖当前佣金率()
func _拍卖增加声望(金额: int):
	return 王朝系统._拍卖增加声望(金额)
func _拍卖等级名称(等级: int):
	return 王朝系统._拍卖等级名称(等级)
func _新拍卖会():
	return 王朝系统._新拍卖会()
func _拍卖会补缺():
	return 王朝系统._拍卖会补缺()
func _拍卖品阶基准(品阶: String):
	return 王朝系统._拍卖品阶基准(品阶)
func _基准估值(it):
	return 王朝系统._基准估值(it)
func _造拍卖物品(目标品阶集: Array):
	return 王朝系统._造拍卖物品(目标品阶集)
func _生成单个拍品_S34(场次: String):
	return 王朝系统._生成单个拍品_S34(场次)
func _生成常驻拍品_S34():
	return 王朝系统._生成常驻拍品_S34()
func _生成大拍拍品_S34():
	return 王朝系统._生成大拍拍品_S34()
func _推进拍卖会_S34(天: int):
	return 王朝系统._推进拍卖会_S34(天)
func 拍卖会确保就绪_S34():
	return 王朝系统.拍卖会确保就绪_S34()
func 设置拍卖交付_S34(交付: Dictionary):
	return 王朝系统.设置拍卖交付_S34(交付)
func 玩家竞拍出价_S34(lot_id: String, 出价: int, 交付: Dictionary, 货币: String = "灵石"):
	# ★ 2026-09-16（ECON-03 P1）：新增可选 货币 参数并透传（缺省「灵石」⇒ 既有调用零改动）。
	return 王朝系统.玩家竞拍出价_S34(lot_id, 出价, 交付, 货币)
func _AI应价_S34(lot: Dictionary):
	return 王朝系统._AI应价_S34(lot)
func _结算单个拍品_S34(lot: Dictionary):
	return 王朝系统._结算单个拍品_S34(lot)
func 设置委托竞拍_S34(lot_id: String, 委托价: int):
	return 王朝系统.设置委托竞拍_S34(lot_id, 委托价)
func 取消委托竞拍_S34(lot_id: String):
	return 王朝系统.取消委托竞拍_S34(lot_id)
func _取消委托竞拍内部_S34(lot_id: String):
	return 王朝系统._取消委托竞拍内部_S34(lot_id)
func _处理委托出价_S34(lot: Dictionary):
	return 王朝系统._处理委托出价_S34(lot)
func _查找拍品_S34(lot_id: String):
	return 王朝系统._查找拍品_S34(lot_id)
func _延时结算检查_S34(lot: Dictionary):
	return 王朝系统._延时结算检查_S34(lot)
func _添加结算通知_S34(通知: Dictionary):
	return 王朝系统._添加结算通知_S34(通知)
func 获取结算通知_S34():
	return 王朝系统.获取结算通知_S34()
func 清除结算通知_S34():
	return 王朝系统.清除结算通知_S34()
func _发放弟子月例_S34(d: Disciple):
	return 王朝系统._发放弟子月例_S34(d)
func _弟子AI竞拍决策_S34(d: Disciple):
	return 王朝系统._弟子AI竞拍决策_S34(d)
func _计算弟子拍品兴趣_S34(d: Disciple, lot: Dictionary):
	return 王朝系统._计算弟子拍品兴趣_S34(d, lot)
func _设置弟子委托_S34(d: Disciple, lot: Dictionary, 兴趣值: int):
	return 王朝系统._设置弟子委托_S34(d, lot, 兴趣值)
func _弟子委托拍卖_S34(d: Disciple):
	return 王朝系统._弟子委托拍卖_S34(d)
func 设置弟子拍卖权限_S34(弟子ID: int, 允许: bool):
	return 王朝系统.设置弟子拍卖权限_S34(弟子ID, 允许)
func 设置弟子拍卖预算_S34(弟子ID: int, 预算: int):
	return 王朝系统.设置弟子拍卖预算_S34(弟子ID, 预算)
func 玩家寄售物品_S34(物品索引: int, 起拍价: int, 时长类型: String = "7日"):
	return 王朝系统.玩家寄售物品_S34(物品索引, 起拍价, 时长类型)
func 获取拍卖行回放_S34():
	return 王朝系统.获取拍卖行回放_S34()
func 发布求购_S34(物品类别: String, 品阶: String, 最高出价: int):
	return 王朝系统.发布求购_S34(物品类别, 品阶, 最高出价)
func 取消求购_S34(求购ID: String):
	return 王朝系统.取消求购_S34(求购ID)
func 关注拍品_S34(拍品ID: String):
	return 王朝系统.关注拍品_S34(拍品ID)
func 取消关注_S34(拍品ID: String):
	return 王朝系统.取消关注_S34(拍品ID)
func _检查关注提醒_S34():
	return 王朝系统._检查关注提醒_S34()
func _获取当前拍卖师_S34(大拍: bool):
	return 王朝系统._获取当前拍卖师_S34(大拍)
func _拍卖师话术_S34(拍卖师: Dictionary):
	return 王朝系统._拍卖师话术_S34(拍卖师)
func 创建暗拍拍品_S34(物品: Item, 起拍价: int, 时长日: int):
	return 王朝系统.创建暗拍拍品_S34(物品, 起拍价, 时长日)
func 暗拍出价_S34(拍品ID: String, 出价: int):
	return 王朝系统.暗拍出价_S34(拍品ID, 出价)
func _暗拍结算_S34(lot: Dictionary):
	return 王朝系统._暗拍结算_S34(lot)
func 创建未知拍品_S34(基础品阶: String, 鉴定费: int):
	return 王朝系统.创建未知拍品_S34(基础品阶, 鉴定费)
func 鉴定拍品_S34(拍品ID: String):
	return 王朝系统.鉴定拍品_S34(拍品ID)
func _检查特殊事件_S34():
	王朝系统._检查特殊事件_S34()
func _推进特殊事件_S34():
	王朝系统._推进特殊事件_S34()
func 获取当前特殊事件_S34():
	return 王朝系统.获取当前特殊事件_S34()
func _结算王朝反制_S34():
	王朝系统._结算王朝反制_S34()
func _反制_办差失利_S34(郡id: String):
	王朝系统._反制_办差失利_S34(郡id)
func 应对王朝反制_S34(实例ID: String, 选择: String):
	return 王朝系统.应对王朝反制_S34(实例ID, 选择)
func _执行反制后果_S34(项: Dictionary, 选择: String):
	王朝系统._执行反制后果_S34(项, 选择)
func _营救判定_S34(郡id: String):
	return 王朝系统._营救判定_S34(郡id)
func _打郡标记_S34(郡id: String, 标记: String):
	王朝系统._打郡标记_S34(郡id, 标记)
func _移除郡标记_S34(郡id: String, 标记: String):
	王朝系统._移除郡标记_S34(郡id, 标记)
func _郡有标记_S34(郡id: String, 标记: String):
	return 王朝系统._郡有标记_S34(郡id, 标记)
func _断供郡数_S34():
	return 王朝系统._断供郡数_S34()
func _弟子被扣押中_S34(弟子ID: String):
	return 王朝系统._弟子被扣押中_S34(弟子ID)
func _推进被扣押弟子_S34():
	王朝系统._推进被扣押弟子_S34()
func _爵位门槛_S34():
	return 王朝系统._爵位门槛_S34()
func _爵位生效中_S34():
	return 王朝系统._爵位生效中_S34()
func _结算爵位停权_S34():
	王朝系统._结算爵位停权_S34()
func _读派系配置():
	return 王朝系统._读派系配置()
func _读爵位配置():
	return 王朝系统._读爵位配置()
func _派系配置(派系名: String):
	return 王朝系统._派系配置(派系名)
func _爵位配置(位阶: String):
	return 王朝系统._爵位配置(位阶)
func _派系初值数组_S34():
	return 王朝系统._派系初值数组_S34()
func _初始化派系_S34():
	王朝系统._初始化派系_S34()
func _取派系项_S34(派系名: String):
	return 王朝系统._取派系项_S34(派系名)
func _权重最高派系_S34():
	return 王朝系统._权重最高派系_S34()
func _刷新掌权派系_S34(静默: bool):
	王朝系统._刷新掌权派系_S34(静默)
func _新朝气象_S34(新掌权: String):
	王朝系统._新朝气象_S34(新掌权)
func _掌权派系_S34():
	return 王朝系统._掌权派系_S34()
func _派系清算_S34(新掌权: String, 旧掌权: String):
	王朝系统._派系清算_S34(新掌权, 旧掌权)
func _结算派系零和_S34():
	王朝系统._结算派系零和_S34()
func _结算派系_S34():
	王朝系统._结算派系_S34()
func _派系系数_S34(列名: String):
	return 王朝系统._派系系数_S34(列名)
func _派系供奉系数_S34():
	return 王朝系统._派系供奉系数_S34()
func _派系苗子系数_S34():
	return 王朝系统._派系苗子系数_S34()
func _派系危机系数_S34():
	return 王朝系统._派系危机系数_S34()
func _派系战功系数_S34():
	return 王朝系统._派系战功系数_S34()
func _爵位差事榜上限_S34():
	return 王朝系统._爵位差事榜上限_S34()
func _爵位供奉加成_S34():
	return 王朝系统._爵位供奉加成_S34()
func 荐举派系_S34(派系名: String):
	return 王朝系统.荐举派系_S34(派系名)
func 扶持派系_S34(派系名: String):
	return 王朝系统.扶持派系_S34(派系名)
func _扶持资源足够_S34(派系名: String):
	return 王朝系统._扶持资源足够_S34(派系名)
func _扶持类型中文(类型: String):
	return 王朝系统._扶持类型中文(类型)
func _扣除扶持资源_S34(派系名: String):
	王朝系统._扣除扶持资源_S34(派系名)
func _库房丹药数_S34():
	return 王朝系统._库房丹药数_S34()
func _消耗库房丹药_S34(数量: int):
	return 王朝系统._消耗库房丹药_S34(数量)
func _感恩达标郡数_S34(门槛: int):
	return 王朝系统._感恩达标郡数_S34(门槛)


# ===== 爵位、皇权、外戚相关函数（已拆分到dynasty_system.gd）=====
func _爵位门槛达成_S34(位阶: String):
	return 王朝系统._爵位门槛达成_S34(位阶)
func 可受封爵位_S34():
	return 王朝系统.可受封爵位_S34()
func 受封爵位_S34(位阶: String):
	return 王朝系统.受封爵位_S34(位阶)
func 辞去爵位_S34():
	return 王朝系统.辞去爵位_S34()
func _结算爵位义务_S34():
	王朝系统._结算爵位义务_S34()
func _结算监国摄政义务_S34(位阶: String):
	王朝系统._结算监国摄政义务_S34(位阶)
func 废立皇帝_S34(新帝名: String = ""):
	return 王朝系统.废立皇帝_S34(新帝名)
func 操控国策_S34(国策名: String):
	return 王朝系统.操控国策_S34(国策名)
func 自立为王_S34():
	return 王朝系统.自立为王_S34()
func _改朝换代爵位后果_S34(旧位阶: String):
	王朝系统._改朝换代爵位后果_S34(旧位阶)
func _可送走弟子_S34():
	return 王朝系统._可送走弟子_S34()
func _外戚索弟子_S34(强制: bool = false):
	王朝系统._外戚索弟子_S34(强制)
func 应对外戚索要_S34(答应: bool):
	return 王朝系统.应对外戚索要_S34(答应)
func _加派系权重_S34(派系名: String, 增量: int):
	王朝系统._加派系权重_S34(派系名, 增量)

func _送弟子入赘_S34(弟子ID: int) -> Dictionary:
	var 目标 = null
	for d in 弟子列表:
		if int(d.弟子ID) == 弟子ID:
			目标 = d
			break
	if 目标 == null:
		return {"成功": false, "原因": "该弟子已不在宗"}
	# ① 资产归还宗门（抄 处理坐化：灵兽归栏、装备背包入库房）
	if 目标.主宠灵兽 != null:
		var 兽: Beast = 目标.主宠灵兽
		目标.主宠灵兽 = null
		兽.取消出战()
		if not 灵兽管理系统.灵兽库存.has(兽):
			灵兽管理系统.灵兽库存.append(兽)
	if 目标.副宠灵兽 != null:
		var 兽2: Beast = 目标.副宠灵兽
		目标.副宠灵兽 = null
		兽2.取消出战()
		if not 灵兽管理系统.灵兽库存.has(兽2):
			灵兽管理系统.灵兽库存.append(兽2)
	for it in 目标.装备.values():
		宗门库房.append(it)
	目标.装备.clear()
	for it in 目标.背包:
		宗门库房.append(it)
	目标.背包.clear()
	# ② 同门人心浮动（先记名，再断链，避免目标自身被误伤）
	var 至亲: Array = []
	for d in 弟子列表:
		if int(d.弟子ID) == 弟子ID:
			continue
		if d.状态 == "失踪" or d.状态 == "陨落" or d.状态 == "叛出":
			continue
		var 至: bool = false
		if int(d.师父ID) == 弟子ID or int(目标.师父ID) == int(d.弟子ID):
			至 = true
		if int(d.道侣ID) == 弟子ID:
			至 = true
		if 至:
			至亲.append(d)
			d.忠诚 = clamp(int(d.忠诚) - 王朝系统.入赘至亲忠诚罚, 0, 100)
		else:
			d.忠诚 = clamp(int(d.忠诚) - 王朝系统.入赘同门忠诚罚, 0, 100)
	# ③ 清退司职 + 断道侣 + 断师徒链（复用 S29 既有断链，保证不残留悬挂引用）
	_叛离清退司职(目标)
	if int(目标.道侣ID) >= 0:
		var 伴侣 = _取弟子_S34(str(目标.道侣ID))
		if 伴侣 != null and int(伴侣.道侣ID) == 弟子ID:
			伴侣.道侣ID = -1
			伴侣.道侣 = ""
	目标.道侣ID = -1
	目标.道侣 = ""
	_断链_师父离场(弟子ID)
	# ④ 留档 + 移出弟子列表
	var 姓名: String = str(目标.姓名)
	var 资质: String = str(Disciple.资质显示.get(目标.资质, "?"))
	var 境界: String = str(目标.境界)
	王朝系统.入赘名录.append({
		"名": 姓名,
		"资质": 资质,
		"境界": 境界,
		"去向": "外戚府",
		"日": 累计游戏日,
	})
	目标.状态 = "入赘"
	弟子列表.erase(目标)
	添加纪事("王朝", "弟子入赘", "%s（%s·%s）应外戚之请入赘，脱离宗门。至亲%d人心绪不宁"
		% [姓名, 境界, 资质, 至亲.size()], 2)
	_加推演条目("◇ %s 入赘外戚府，自此脱离宗门" % 姓名, ET_SECT, PRIO_HIGH, {"弟子": 姓名})
	return {"成功": true, "消息": "%s 已入赘外戚府，%d 名至亲忠诚下滑" % [姓名, 至亲.size()]}

# 郡县月香火 / 月灵石基准（按城邦等级；对齐 GDD §4.3 等级表）
# 凡间郡县供奉基准【日频实加】—— 项目「月产」命名全部误导，实为每次推演(1累计游戏日)全额加
# 满版图(9凡俗城)盛世×崇道 ≈ 2700/30 日均89；配基础香火190 → 合计279 ≈ 设计锚点280
# （280×2 = 560 = 气运香火速率软上限，刚好卡住不满溢）
const 郡县月香火: Dictionary = {1: 130, 2: 220, 3: 350, 4: 530}
const 王朝月长: int = 30              # 1 王朝月 = 30 游戏日（推演一月 每次推进 1 游戏日）
const 王朝差事榜上限: int = 4         # 凡间差事榜同时悬挂条数
# 凡间郡县供奉灵石基准【日频实加】，对齐 S32 领地月灵石 与 运维封顶 318 的同口径
# 满版图盛世×崇道 ≈ 79（运维封顶318 的 24.5%，落在 S32 的 11%~28% 区间内）
# 乱世×崇道 ≈ 12、灭法国策 = 0 —— 供奉随王朝阶段断崖，玩家才有理由经营王朝
const 郡县月灵石: Dictionary = {1: 4, 2: 7, 3: 11, 4: 14}
# 感恩系数：感恩0 → 0.4 倍，感恩100 → 1.0 倍（双轴设计：感恩度决定供奉意愿，忠顺度决定叛乱）
const 郡县供奉感恩下限: float = 0.4
const 郡县供奉感恩权重: float = 0.6
# S34 批次 3 地基：对宗门关系进入供奉公式。
#   原实现供奉 = 感恩 × 阶段 × 国策 × 派系 × 爵位，唯独不含关系；而爵位只增不减
#   → 关系是「达标即永久」的一次性门票。五种反制有三种靠「扣关系」做代价，
#     玩家拿到帝师后拒绝任何反制都是零代价，两难根本不成立（实测结论，非推测）。
#   关系 0 → ×0.6、50 → ×1.0（不赚不赔中枢）、100 → ×1.4
const 王朝关系供奉下限: float = 0.6
const 王朝关系供奉权重: float = 0.8
# ============ S34 批次 3：王朝反制（有牙齿） ============
# 反制决策窗口：生成待决后有 N 个王朝月可决策，逾期自动按最坏结果结算
const 反制决策窗口: int = 2
# 业力来源拓宽（原实现只有「择九幽邪道」一处 +10，灭法令需 200 → 永远触发不了）
const 反制抗命业力: int = 5
const 反制扶持叛军业力: int = 15
const 反制迎战得胜业力: int = 10
# 扣押弟子的三条路：赎回（灵石）/ 营救（遣弟子，胜则感恩大涨）/ 拖延（忠诚罚、数月后放回）
const 反制等待忠诚罚: int = 20
const 反制等待月数: int = 6
const 反制营救成功率基: float = 0.35
const 反制营救成功率权: float = 0.30
# 郡县兵力 → 战力换算（GDD §4.3：L1 200 / L2 800 / L3 3000 / L4 12000 兵力；
# 练气弟子战力基准 100 → 换算 0.1 后 L1 需 20 战力、L4 需 1200 战力，梯度合理）
const 禁军战力换算: float = 0.10
# 断供不归零：降至三成，留修复余地（原设计归零 → 玩家更没资源修复 → 死亡螺旋）
const 断供供奉折损: float = 0.30
# 每座断供郡每月拖累民心（常量化，便于校验器与仿真现读）。
#   取 3 而非 1：民心向中值 55 回归的速率在民心 30 时为 +2.5/月，
#   单郡 -1/月 压不过回归 → 实测 240 月民变 0 次触发（死代码）。
const 断供民心拖累: int = 3
# 灭法令二级条件的国祚线 / 邪道业力线
const 灭法令国祚线: int = 30
const 灭法令业力线: int = 100
# ============ S34 批次3收尾：朝廷委托（护国宗不可拒征调） ============
# 与反制对称：王朝主动点名宗门、强制接的差事。仅护国宗收，自立为王豁免。
const 委托决策窗口: int = 3          # 生成待决后有 N 个王朝月可应征，逾期按拖延最严档结算
const 委托生成间隔: int = 6           # 两条强制委托之间至少隔 N 个王朝月
# 皇子系统（GDD §5：中衰期玩家焦点 = 站队、押注继承人）
const 皇子数下限: int = 2
const 皇子数上限: int = 4
const 皇子生成国祚线: int = 55      # 国祚低于此值（中衰/乱世）才生皇子
const 皇子年龄下限: int = 16
const 皇子年龄上限: int = 40
const 押对关系增: int = 40
const 押对恩遇增: int = 2
const 押错关系罚: int = 40
const 改押关系罚: int = 5
# 可调停民变的最低爵位（国师及以上 —— 兑现爵位表 right_desc 的承诺）
const 调停民变爵位序: Array = ["国师", "帝师", "监国", "摄政"]
# 皇子登基时其所属派系获得的权重增益（让押注与党争两套系统咬合）
const 皇子继位派系增益: int = 10
# 对宗门关系每月自然衰减基数（× 国策 attitude_decay 0.7~2.5）
# 基准 2.0 → 崇道1.4/月（约36月见底）、重文2.0、尚武2.6、猜忌4.0、灭法5.0（约10月见底）
# 回升通道：凡间差事成/败按 reward_gratitude / 4 折算（见 _结算凡间差事_S34）
# TODO(S34批次3)：反制机制接入后，按「关系阈值触发朝廷打压」的实际手感回调此值
const 王朝关系衰减基数: float = 2.0
# 已解锁的凡俗郡县 key 列表（未解锁城市不产供奉，避免新档白拿满版图收益）

# ===== 供奉相关函数（已拆分到dynasty_system.gd）=====
func _已解锁凡俗郡_S34():
	return 王朝系统._已解锁凡俗郡_S34()
func _郡县供奉系数_S34(郡: Dictionary):
	return 王朝系统._郡县供奉系数_S34(郡)
func _郡县供奉香火_S34():
	return 王朝系统._郡县供奉香火_S34()
func _郡县供奉灵石_S34():
	return 王朝系统._郡县供奉灵石_S34()

func _凡间信众_S34() -> int:
	if 王朝系统.郡县状态.is_empty():
		return 0
	var 人口: int = 0
	for k in _已解锁凡俗郡_S34():
		人口 += int((王朝系统.郡县状态[k] as Dictionary).get("人口", 0))
	return int(人口 / 50000)
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
# P1优化：入册仪式感，首次收录添加推演条目
func _记录图录(匹配名: String, 来源 := "") -> bool:

	if 匹配名== "":
		return false
	var 新收录:= false
	var 收录名称: String = ""
	var 收录类别: String = ""
	var 是否稀有: bool = false
	for r in 图录配置:
		if str(r.get("匹配名") if "匹配名" in r else "") == 匹配名:
			var 类别: String = r.get("类别") if "类别" in r else ""
			if not 收藏图录_已收集.has(类别):
				收藏图录_已收集[类别] = []
			if not 收藏图录_已收集[类别].has(匹配名):
				收藏图录_已收集[类别].append(匹配名)
				新收录= true
				收录名称 = str(r.get("名称", 匹配名))
				收录类别 = 类别
				是否稀有 = str(r.get("是否稀有", "否")) == "是"
				_检查图录类别集(类别)
	if 新收录:
		# 入册仪式感：添加推演条目
		var 文案: String = ""
		if 是否稀有:
			文案 = "宗门典藏阁新入仙品异物【%s】，灵气氤氲，全宗皆惊。" % 收录名称
		else:
			文案 = "宗门典藏阁新入册【%s】，典藏又添一物。" % 收录名称
		_加推演条目(文案, "典藏", "低", {"名称": 收录名称, "类别": 收录类别, "稀有": 是否稀有})
		图录更新.emit()
	return 新收录
# 某类别全：匹配：是否已收录；集齐则解：产出池轴 增益（单：：%，全：：0% via clamp 兜底期
# P1优化：集齐仪式感，添加推演条目
func _检查图录类别集(类别: String):

	var 全部: Array = []
	var 增益值: float = 0.0
	for r in 图录配置:
		if str(r.get("类别") if "类别" in r else "") == 类别:
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
	# 集齐仪式感：添加推演条目
	var 集齐文案: String = "宗门典藏阁【%s】圆满集齐，气运加持，宗门产出+%d%%。" % [类别, int(增益值* 100)]
	_加推演条目(集齐文案, "典藏", "中", {"类别": 类别, "增益": int(增益值* 100)})
	传承史册.append({"日期": 累计游戏日, "弟子": "", "名称": "典藏集齐", "文案": 文案表["heritage_codex_complete"] % [类别, int(增益值* 100)], "category": "传承"})
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
	"宗门建设": {"描述": "宗门建设相关里程碑", "图标": "◇"},
	"弟子培养": {"描述": "弟子培养相关里程碑", "图标": "◇◇"},
	"实力提升": {"描述": "实力提升相关里程碑", "图标": "▲"},
	"财富积累": {"描述": "财富积累相关里程碑", "图标": "◇"},
	"探索发现": {"描述": "探索发现相关里程碑", "图标": "◇"},
	"特殊事件": {"描述": "特殊事件相关里程碑", "图标": "◆"},
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
			"灵兽": 当前值 = float(灵兽管理系统.灵兽库存.size())
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
		if not bool(m.get("已达成") if "已达成" in m else false) and str(m.get("触发类型") if "触发类型" in m else "") == "事件" and str(m.get("触发事件") if "触发事件" in m else "") == 事:
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
				"灵兽": 达成 = 灵兽管理系统.灵兽库存.size() >= v
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
				"成就数量": 达成 = 成就系统.成就_已达成.size() >= v
				"里程碑数量": 达成 = 里程碑_已达成.size() >= v
				"体修弟子":
					var 体修数: int = 0
					for d in 弟子列表:
						if d != null and str(d.get("修炼方向") if "修炼方向" in d else "") == "体修":
							体修数 += 1
					达成 = 体修数 >= v
				"法修弟子":
					var 法修数: int = 0
					for d in 弟子列表:
						if d != null and str(d.get("修炼方向") if "修炼方向" in d else "") == "法修":
							法修数 += 1
					达成 = 法修数 >= v
				"道修弟子":
					var 道修数: int = 0
					for d in 弟子列表:
						if d != null and str(d.get("修炼方向") if "修炼方向" in d else "") == "道修":
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
					var 境界顺序: Array = Disciple.境界序   # 唯一真源；>=1 仍表"筑基以上"（前5阶索引不变）
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
# ============ 成就系统（已拆分到achievement_system.gd，此处为转发函数）============
func 获取所有成就列表() -> Array:
	return 成就系统.获取所有成就列表()
func 获取成就统计() -> Dictionary:
	return 成就系统.获取成就统计()
func 按稀有度筛选成就(稀有度: String) -> Array:
	return 成就系统.按稀有度筛选成就(稀有度)
func 按分类筛选成就(分类: String) -> Array:
	return 成就系统.按分类筛选成就(分类)
func 获取成就分类统计() -> Dictionary:
	return 成就系统.获取成就分类统计()
func 获取成就进度(成就ID: String) -> Dictionary:
	return 成就系统.获取成就进度(成就ID)
func 获取所有未达成成就进度() -> Array:
	return 成就系统.获取所有未达成成就进度()
func 领取成就奖励(成就ID: String) -> Dictionary:
	return 成就系统.领取成就奖励(成就ID)
func _复检成就():
	成就系统._复检成就()
func _达成成就(a: Dictionary):
	成就系统._达成成就(a)
func _里程碑奖励描述(m: Dictionary) -> String:
	return 成就系统._里程碑奖励描述(m)
func _存在已筑基弟子() -> bool:
	return 成就系统._存在已筑基弟子()
func _存在长老() -> bool:
	return 成就系统._存在长老()
func _存在长寿弟子() -> bool:
	return 成就系统._存在长寿弟子()

# WAVE-D #6：稀有藏品捐赠藏宝库 ：声望（复用现：声望，不落凝聚力：
func 捐赠图录(图录ID: String) -> Dictionary:

	var res: Dictionary = {"ok": false, "msg": ""}
	if 捐赠记录.has(图录ID):
		res["msg"] = "该仙品已供奉藏宝阁"
		return res
	for r in 图录配置:
		if str(r.get("图录ID") if "图录ID" in r else "") == 图录ID:
			if str(r.get("是否稀有") if "是否稀有" in r else "否") != "是":
				res["msg"] = "非仙品异物，不可供奉"
				return res
			var 声望值: int = int(r.get("捐赠声望") if "捐赠声望" in r else 0)
			var 名称: String = str(r.get("名称", ""))
			if 声望值> 0:
				_加声望(声望值)
				捐赠记录[图录ID] = true
				# 供奉仪式感：添加推演条目
				var 供奉文案: String = "宗门将仙品【%s】供奉于藏宝阁，灵气冲天，宗门声望+%d。" % [名称, 声望值]
				_加推演条目(供奉文案, "典藏", "中", {"名称": 名称, "声望": 声望值})
			res["ok"] = true
			res["msg"] = "供奉成功，宗门声望+%d" % 声望值
			# S55：宗门典藏入册弹窗
			AchievementPopup.show_achievement("宗门典藏", "%s 入册藏宝阁" % 名称, "仙品【%s】供奉于藏宝阁，灵气冲天，宗门声望+%d。" % [名称, 声望值], Color(0.2, 0.7, 0.9))
			图录更新.emit()
			return res
	res["msg"] = "未找到该藏品"
	return res
# 体力上限：初：50，门派每：1 ：+5
# P0修复：移除体力系统，改为每日机缘+VIP加成
# 修真化文案：每日次数→机缘，不同类型有不同修真名称
const 每日机缘配置: Dictionary = {
	"探秘境缘": {"基础": 3, "描述": "探索秘境的机缘"},
	"游历机缘": {"基础": 2, "描述": "宗主外出游历的机缘"},
	"历练机缘": {"基础": 5, "描述": "弟子外出历练的机缘"},
	"征伐机缘": {"基础": 3, "描述": "宗门征伐的机缘"},
	"入山机缘": {"基础": 5, "描述": "入山狩猎采药的机缘"},
}

## 获取机缘上限（基础次数 + VIP梯度加成）
## VIP加成：VIP9+20%，VIP11+50%（避免VIP12比VIP0多5倍差距）
func 获取机缘上限(类型: String) -> int:
	var 配置: Dictionary = 每日机缘配置.get(类型, {"基础": 3})
	var 基础: int = int(配置.get("基础", 3))
	var VIP加成: float = _计算机缘加成()
	return int(基础 * (1.0 + VIP加成))

## 检查机缘是否足够
func 检查机缘(类型: String) -> Dictionary:
	# 跨日重置
	if int(每日机缘.get("日期", -1)) != 累计游戏日:
		每日机缘 = {"日期": 累计游戏日}
	var 已用: int = int(每日机缘.get(类型, 0))
	var 上限: int = 获取机缘上限(类型)
	return {"足够": 已用 < 上限, "已用": 已用, "上限": 上限, "剩余": max(0, 上限 - 已用)}

## 消耗机缘
func 消耗机缘(类型: String) -> bool:
	var 检查: Dictionary = 检查机缘(类型)
	if not 检查.get("足够", false):
		return false
	每日机缘[类型] = int(每日机缘.get(类型, 0)) + 1
	return true

## 增加机缘（使用道具时调用）
func 增加机缘(类型: String, 数量: int = 1) -> void:
	每日机缘[类型] = max(0, int(每日机缘.get(类型, 0)) - 数量)  # 减少已用=增加剩余

## 使用机缘符（增加指定类型机缘1次）
## 机缘符类型：探秘境缘符、游历机缘符、历练机缘符、征伐机缘符、入山机缘符
func 使用机缘符(符类型: String) -> Dictionary:
	var 类型映射: Dictionary = {
		"探秘境缘符": "探秘境缘",
		"游历机缘符": "游历机缘",
		"历练机缘符": "历练机缘",
		"征伐机缘符": "征伐机缘",
		"入山机缘符": "入山机缘",
	}
	var 机缘类型: String = 类型映射.get(符类型, "")
	if 机缘类型 == "":
		return {"成功": false, "原因": "未知机缘符类型"}
	# 检查库房是否有该符
	if not _库房有物品(符类型, 1):
		return {"成功": false, "原因": "库房无%s" % 符类型}
	# 扣除道具
	_库房移除物品(符类型, 1)
	# 增加机缘
	增加机缘(机缘类型, 1)
	var 检查: Dictionary = 检查机缘(机缘类型)
	添加纪事("机缘", "使用机缘符", "使用%s，%s剩余%d/%d" % [符类型, 每日机缘配置.get(机缘类型, {}).get("描述", 机缘类型), 检查.get("剩余", 0), 检查.get("上限", 0)], 1)
	return {"成功": true, "原因": "使用%s成功，%s剩余%d/%d" % [符类型, 每日机缘配置.get(机缘类型, {}).get("描述", 机缘类型), 检查.get("剩余", 0), 检查.get("上限", 0)]}

## 使用悟道令（增加所有类型机缘1次）
func 使用悟道令() -> Dictionary:
	if not _库房有物品("悟道令", 1):
		return {"成功": false, "原因": "库房无悟道令"}
	_库房移除物品("悟道令", 1)
	# 增加所有类型机缘
	for 类型 in 每日机缘配置:
		增加机缘(类型, 1)
	添加纪事("机缘", "使用悟道令", "使用悟道令，所有机缘各+1", 2)
	return {"成功": true, "原因": "使用悟道令成功，所有机缘各+1"}

## 增加所有机缘次数（用于仙玉商店购买机缘符/悟道令/天机符）
func 增加所有机缘次数(次数: int) -> void:
	for 类型 in 每日机缘配置:
		增加机缘(类型, 次数)

# ===== 护道人系统函数 =====
## 检查弟子是否需要护道人（超潜力/亲传/嫡系）
func 检查护道人需求(d: Disciple) -> String:
	# 超潜力弟子：天品灵根 + 资质≥90 + 年龄<30
	if d.灵根品阶 == "天品" and int(d.资质) >= 90 and int(d.年龄) < 30:
		return "超潜力"
	# 宗主亲传
	if d.是否亲传:
		return "宗主亲传"
	# 核心人员嫡系血脉：检查是否有长老/峰主/堂主的血缘关系
	if d.家族关系 != "" and d.家族关系 in ["长老之子", "峰主之女", "堂主之子", "堂主之女", "峰主之子", "长老之女"]:
		return "嫡系血脉"
	return ""

## 自动配备护道人
func 自动配备护道人(d: Disciple) -> Dictionary:
	var 需求: String = 检查护道人需求(d)
	if 需求 == "":
		return {"成功": false, "原因": "该弟子无需护道人"}
	# 检查是否已有护道人
	if 护道人列表.has(d.弟子ID):
		return {"成功": false, "原因": "该弟子已有护道人"}
	# 根据需求类型确定护道人等级
	var 护道等级: String = "外门护道"
	if 需求 == "超潜力":
		护道等级 = "长老护道"
	elif 需求 == "宗主亲传":
		护道等级 = "太上护道"
	elif 需求 == "嫡系血脉":
		护道等级 = "内门护道"
	# 检查VIP等级是否满足
	var 配置: Dictionary = 护道人配置.get(护道等级, {})
	var VIP需求: int = int(配置.get("VIP需求", 0))
	if 当前VIP等级() < VIP需求:
		# VIP不足，降级为外门护道
		护道等级 = "外门护道"
	# 创建护道人
	护道人计数器 += 1
	var 护道人ID: int = 护道人计数器
	var 护道人姓名: String = _生成护道人姓名()
	护道人列表[d.弟子ID] = {
		"护道人ID": 护道人ID,
		"护道人等级": 护道等级,
		"护道人姓名": 护道人姓名,
		"功德": 0,
		"到期日": 累计游戏日 + 365,
		"替死玉符": false,
		"气运加持": 0,
	}
	添加纪事("护道", "配备护道人", "为弟子【%s】配备%s【%s】（%s）" % [d.姓名, 护道等级, 护道人姓名, 需求], 2)
	return {"成功": true, "护道人ID": 护道人ID, "护道人等级": 护道等级, "护道人姓名": 护道人姓名}

## 生成护道人姓名
func _生成护道人姓名() -> String:
	var 姓氏: Array = ["李", "王", "张", "刘", "陈", "杨", "赵", "黄", "周", "吴", "徐", "孙", "胡", "朱", "高", "林", "何", "郭", "马", "罗"]
	var 名字: Array = ["青云", "紫霞", "玄真", "太虚", "玉清", "上清", "太清", "无极", "混元", "鸿钧", "鲲鹏", "接引", "准提", "女娲", "伏羲", "神农", "轩辕", "蚩尤", "刑天", "后羿"]
	return 姓氏[randi() % 姓氏.size()] + 名字[randi() % 名字.size()]

## 获取护道人修炼加成
func 获取护道人修炼加成(弟子ID: int) -> float:
	if not 护道人列表.has(弟子ID):
		return 0.0
	var 护道人: Dictionary = 护道人列表[弟子ID]
	var 等级: String = str(护道人.get("护道人等级", "外门护道"))
	var 配置: Dictionary = 护道人配置.get(等级, {})
	var 加成: float = float(配置.get("修炼加成", 0.0))
	# 气运加持
	var 气运: int = int(护道人.get("气运加持", 0))
	if 气运 > 0 and 累计游戏日 < 气运:
		加成 *= 1.2
	# VIP12双重护道人：效果翻倍
	if 当前VIP等级() >= 12:
		加成 *= 2.0
	return 加成

## 获取护道人突破加成
func 获取护道人突破加成(弟子ID: int) -> float:
	if not 护道人列表.has(弟子ID):
		return 0.0
	var 护道人: Dictionary = 护道人列表[弟子ID]
	var 等级: String = str(护道人.get("护道人等级", "外门护道"))
	var 配置: Dictionary = 护道人配置.get(等级, {})
	var 加成: float = float(配置.get("突破加成", 0.0))
	# VIP12双重护道人：效果翻倍
	if 当前VIP等级() >= 12:
		加成 *= 2.0
	return 加成

## 获取护道人救援概率
func 获取护道人救援概率(弟子ID: int) -> float:
	if not 护道人列表.has(弟子ID):
		return 0.0
	var 护道人: Dictionary = 护道人列表[弟子ID]
	var 等级: String = str(护道人.get("护道人等级", "外门护道"))
	var 配置: Dictionary = 护道人配置.get(等级, {})
	var 概率: float = float(配置.get("救援概率", 0.0))
	# 替死玉符确保100%救援
	if bool(护道人.get("替死玉符", false)):
		概率 = 1.0
	return 概率

## 护道人危机救援（返回是否救援成功）
func 护道人危机救援(d: Disciple) -> bool:
	if not 护道人列表.has(d.弟子ID):
		return false
	var 概率: float = 获取护道人救援概率(d.弟子ID)
	var 成功: bool = randf() < 概率
	if 成功:
		# 增加护道人功德
		var 护道人: Dictionary = 护道人列表[d.弟子ID]
		护道人["功德"] = int(护道人.get("功德", 0)) + 50
		# 如果使用了替死玉符，消耗掉
		if bool(护道人.get("替死玉符", false)):
			护道人["替死玉符"] = false
		# 延寿一甲子（60年），并重置年龄避免立即再次触发
		d.寿元 += 60
		d.年龄 = max(0, d.年龄 - 30)  # 回退30年，避免立即再次触发
		添加纪事("护道", "危机救援", "护道人【%s】成功救援弟子【%s】，延寿一甲子，功德+50" % [str(护道人.get("护道人姓名", "")), d.姓名], 3)
	return 成功

## 护道人功德积累（日常保护弟子）
func 护道人日常功德(d: Disciple) -> void:
	if not 护道人列表.has(d.弟子ID):
		return
	var 护道人: Dictionary = 护道人列表[d.弟子ID]
	护道人["功德"] = int(护道人.get("功德", 0)) + 1
	# 检查是否可以晋升
	_检查护道人晋升(d.弟子ID)

## 检查护道人晋升
func _检查护道人晋升(弟子ID: int) -> void:
	if not 护道人列表.has(弟子ID):
		return
	var 护道人: Dictionary = 护道人列表[弟子ID]
	var 当前等级: String = str(护道人.get("护道人等级", "外门护道"))
	var 当前功德: int = int(护道人.get("功德", 0))
	# 晋升顺序
	var 晋升顺序: Array = ["外门护道", "内门护道", "长老护道", "太上护道"]
	var 当前索引: int = 晋升顺序.find(当前等级)
	if 当前索引 < 0 or 当前索引 >= 晋升顺序.size() - 1:
		return
	var 下一等级: String = 晋升顺序[当前索引 + 1]
	var 下一配置: Dictionary = 护道人配置.get(下一等级, {})
	var 功德需求: int = int(下一配置.get("功德需求", 9999))
	var VIP需求: int = int(下一配置.get("VIP需求", 0))
	# 检查功德和VIP
	if 当前功德 >= 功德需求 and 当前VIP等级() >= VIP需求:
		护道人["护道人等级"] = 下一等级
		护道人["功德"] = 0
		添加纪事("护道", "护道人晋升", "护道人【%s】功德圆满，晋升为%s" % [str(护道人.get("护道人姓名", "")), 下一等级], 2)

## 使用护道玉符（召唤护道人）
func 使用护道玉符(d: Disciple, 等级: String = "外门护道") -> Dictionary:
	if 护道玉符 <= 0:
		return {"成功": false, "原因": "库房无护道玉符"}
	if 护道人列表.has(d.弟子ID):
		return {"成功": false, "原因": "该弟子已有护道人"}
	# 检查VIP等级
	var 配置: Dictionary = 护道人配置.get(等级, {})
	var VIP需求: int = int(配置.get("VIP需求", 0))
	if 当前VIP等级() < VIP需求:
		return {"成功": false, "原因": "仙缘位阶不足，需仙缘%d" % VIP需求}
	护道玉符 -= 1
	护道人计数器 += 1
	var 护道人ID: int = 护道人计数器
	var 护道人姓名: String = _生成护道人姓名()
	护道人列表[d.弟子ID] = {
		"护道人ID": 护道人ID,
		"护道人等级": 等级,
		"护道人姓名": 护道人姓名,
		"功德": 0,
		"到期日": 累计游戏日 + 365,
		"替死玉符": false,
		"气运加持": 0,
	}
	添加纪事("护道", "使用护道玉符", "使用护道玉符，为弟子【%s】召唤%s【%s】" % [d.姓名, 等级, 护道人姓名], 2)
	return {"成功": true, "护道人ID": 护道人ID, "护道人等级": 等级, "护道人姓名": 护道人姓名}

## 使用护道续缘符（延长保护时间）
func 使用护道续缘符(弟子ID: int) -> Dictionary:
	if 护道续缘符 <= 0:
		return {"成功": false, "原因": "库房无护道续缘符"}
	if not 护道人列表.has(弟子ID):
		return {"成功": false, "原因": "该弟子无护道人"}
	护道续缘符 -= 1
	var 护道人: Dictionary = 护道人列表[弟子ID]
	护道人["到期日"] = int(护道人.get("到期日", 累计游戏日)) + 365
	添加纪事("护道", "使用护道续缘符", "护道人【%s】续缘成功，保护期延长365日" % str(护道人.get("护道人姓名", "")), 2)
	return {"成功": true, "原因": "续缘成功"}

## 使用功德玉牌（增加护道人功德）
func 使用功德玉牌(弟子ID: int) -> Dictionary:
	if 功德玉牌 <= 0:
		return {"成功": false, "原因": "库房无功德玉牌"}
	if not 护道人列表.has(弟子ID):
		return {"成功": false, "原因": "该弟子无护道人"}
	功德玉牌 -= 1
	var 护道人: Dictionary = 护道人列表[弟子ID]
	护道人["功德"] = int(护道人.get("功德", 0)) + 200
	_检查护道人晋升(弟子ID)
	添加纪事("护道", "使用功德玉牌", "护道人【%s】功德+200" % str(护道人.get("护道人姓名", "")), 2)
	return {"成功": true, "原因": "功德+200"}

## 使用气运符箓（临时提升护道人效果20%，持续7天）
func 使用气运符箓(弟子ID: int) -> Dictionary:
	if 气运符箓 <= 0:
		return {"成功": false, "原因": "库房无气运符箓"}
	if not 护道人列表.has(弟子ID):
		return {"成功": false, "原因": "该弟子无护道人"}
	气运符箓 -= 1
	var 护道人: Dictionary = 护道人列表[弟子ID]
	护道人["气运加持"] = 累计游戏日 + 7
	添加纪事("护道", "使用气运符箓", "护道人【%s】获得气运加持，效果提升20%，持续7日" % str(护道人.get("护道人姓名", "")), 2)
	return {"成功": true, "原因": "气运加持7日"}

## 使用替死玉符（确保一次危机救援成功）
func 使用替死玉符(弟子ID: int) -> Dictionary:
	if 替死玉符 <= 0:
		return {"成功": false, "原因": "库房无替死玉符"}
	if not 护道人列表.has(弟子ID):
		return {"成功": false, "原因": "该弟子无护道人"}
	替死玉符 -= 1
	var 护道人: Dictionary = 护道人列表[弟子ID]
	护道人["替死玉符"] = true
	添加纪事("护道", "使用替死玉符", "护道人【%s】佩戴替死玉符，下次危机确保救援成功" % str(护道人.get("护道人姓名", "")), 2)
	return {"成功": true, "原因": "替死玉符已激活"}

## 检查护道人是否过期
func 检查护道人过期() -> void:
	var 过期列表: Array = []
	for 弟子ID in 护道人列表.keys():
		var 护道人: Dictionary = 护道人列表[弟子ID]
		if 累计游戏日 > int(护道人.get("到期日", 0)):
			过期列表.append(弟子ID)
	for 弟子ID in 过期列表:
		var 护道人: Dictionary = 护道人列表[弟子ID]
		添加纪事("护道", "护道人离去", "护道人【%s】保护期满，离去云游" % str(护道人.get("护道人姓名", "")), 2)
		护道人列表.erase(弟子ID)

## 获取所有护道人列表
func 获取所有护道人() -> Array:
	var 结果: Array = []
	for 弟子ID in 护道人列表.keys():
		var 护道人: Dictionary = 护道人列表[弟子ID]
		var d: Disciple = _按ID找弟子(int(弟子ID))
		if d != null:
			结果.append({
				"弟子ID": 弟子ID,
				"弟子姓名": d.姓名,
				"护道人ID": 护道人.get("护道人ID", 0),
				"护道人等级": 护道人.get("护道人等级", ""),
				"护道人姓名": 护道人.get("护道人姓名", ""),
				"功德": 护道人.get("功德", 0),
				"到期日": 护道人.get("到期日", 0),
				"剩余天数": max(0, int(护道人.get("到期日", 0)) - 累计游戏日),
				"替死玉符": 护道人.get("替死玉符", false),
				"气运加持": 护道人.get("气运加持", 0),
			})
	return 结果

func 体力上限() -> int:
	# P0修复：体力系统已移除，保留函数兼容旧调用，返回固定值
	return 999
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
	_本月符堂产出 = 0
	var 经营基数: Dictionary = {"lingtian": 5, "kuangmai": 6, "dantang": 3, "qitang": 3, "cangjing": 2, "zhifa": 2, "gongxun": 2, "tanwei": 2, "yuying": 1, "yushou": 1, "zhenfa": 1, "xichi": 1, "futang": 3}
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
				经营加成 += float(命格数据.get("数值", 0)) / 100.0
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
			产出值 = int(n * base * (1.0 + 经营加成) * 气运乘 * (1.0 + 获取气运产出加成()) * (1.0 + 产出buff + 彩蛋产出加成() + 产出池加成) * 等级乘区 * 宗主灵石系数 * _殿阁等级_乘区(key))
			# S1：灵田不直接产出灵石（修真世界观：灵田种灵草灵米，灵石来自矿脉/交易/历练）
			if key != "lingtian":
				灵石 += 产出值
		# S1 ： D7 解锁①：Lv.2+ 保底津贴（与成员产出叠加，结构性产出）
		if int(职.get("等级", 1)) >= 2:
			灵石 += int(职.get("等级", 1)) * 殿阁保底津贴
		# 阶段2：记录各资源殿阁本月实际产出额，：_殿阁被动结算 概率翻倍（灵草丰收/富矿/额外丹元/器魂）时直接加回
		# 资源系统补全（偏：3）：灵田/矿脉除普适灵石外，额外产出专属材料，：S1 丹器消：
		match key:
			"lingtian":
				# S1：灵田产出需要消耗灵种，灵种不足时产出减半
				var 灵田消耗灵种: int = min(灵种, max(1, int(产出值 / 10)))
				var 灵田产出系数: float = 1.0 if 灵种 >= 灵田消耗灵种 else 0.5
				灵种 -= 灵田消耗灵种
				_本月灵田产出 = int(产出值 * 灵田产出系数)
				灵草 += int(产出值 * 灵田产出系数)
				灵米 += int(ceil(产出值 * 0.3 * 灵田产出系数))   # S1：灵田副产灵米（30%转化率）
				灵气 += int(ceil(产出值* 0.5))   # 灵气减半产出（老大拍板 2026-07-21）：初期不溢出，核心产出仍以灵草为主
				# 灵田等级系统：高等级灵田产出高阶灵草（灵田等级=司职列表lingtian等级）
				var 灵田等级: int = 1
				if 司职列表.has("lingtian"):
					灵田等级 = int(司职列表["lingtian"].get("等级", 1))
				if 灵田等级 >= 3:
					灵品灵草 += int(产出值 * 0.2 * 灵田产出系数 * (灵田等级 - 2))
				if 灵田等级 >= 5:
					宝品灵草 += int(产出值 * 0.1 * 灵田产出系数 * (灵田等级 - 4))
				if 灵田等级 >= 7:
					王品灵草 += int(产出值 * 0.05 * 灵田产出系数 * (灵田等级 - 6))
				# 灵田副产灵木（修真世界观：灵田边种灵木，炼器琴/扇/拂尘柄用）
				if 灵田等级 >= 2:
					灵木 += int(产出值 * 0.1 * 灵田产出系数 * (灵田等级 - 1))
				# 灵田有概率产出高年份灵草（修真世界观：种植时间久了灵草年份增长）
				if 灵田等级 >= 3 and randf() < 0.15:
					灵草_百年 += max(1, int(产出值 * 0.05 * 灵田等级))
				if 灵田等级 >= 5 and randf() < 0.08:
					灵草_千年 += max(1, int(产出值 * 0.03 * 灵田等级))
				if 灵田等级 >= 7 and randf() < 0.03:
					灵草_万年 += 1
				if 灵田产出系数 < 1.0:
					_加推演条目("灵田灵种不足，产出减半（需补充灵种）", "庶务", "低")
			"kuangmai":
				_本月矿脉产出 = 产出值
				矿石 += 产出值
				灵晶 += int(产出值 * 0.5)   # P0-3：灵晶产出（原恒0致装备强化必失败）；随矿脉开采凝结
				# 矿脉等级=殿阁等级：高等级矿脉月度额外产出高阶矿物
				var 矿脉殿阁等级: int = int(职.get("等级", 1))
				if 矿脉殿阁等级 >= 4:
					精铁 += int(产出值 * 0.3 * (矿脉殿阁等级 - 3))
				if 矿脉殿阁等级 >= 6:
					玄铁 += int(产出值 * 0.2 * (矿脉殿阁等级 - 5))
				if 矿脉殿阁等级 >= 7:
					庚金 += int(产出值 * 0.15 * (矿脉殿阁等级 - 6))
				if 矿脉殿阁等级 >= 8:
					紫晶 += int(产出值 * 0.1 * (矿脉殿阁等级 - 7))
				if 矿脉殿阁等级 >= 9:
					星辰铁 += int(产出值 * 0.05 * (矿脉殿阁等级 - 8))
			"dantang":
				_本月丹堂产出 = 产出值
			"qitang":
				_本月器殿产出 = 产出值
			"futang":
				_本月符堂产出 = 产出值
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
	var 经营基数: Dictionary = {"lingtian": 5, "kuangmai": 6, "dantang": 3, "qitang": 3, "cangjing": 2, "zhifa": 2, "gongxun": 2, "tanwei": 2, "yuying": 1, "yushou": 1, "zhenfa": 1, "xichi": 1, "futang": 3}
	var 产出buff: float = 汇总负责人全局buff().get("产出", 0.0)
	# 宗主称号全宗产出加成
	var 宗主产出加成: float = 获取宗主称号加成("全宗产出")
	产出buff += 宗主产出加成
	var 等级乘区: float = 1.0 + 0.02 * max(0, 门派等级 - 1)
	var 气运乘: float = (1.0 + 气运产出加成) if (累计游戏日 < 气运到期日) else 1.0
	var 经营加成: float = 0.0
	for m in 成员:
		var 弟子: Disciple = m as Disciple
		var 命格数据: Dictionary = DestinyDataLoader.get_destiny(弟子.destiny_id)
		if 命格数据.get("类型", "") == "经营" and 命格数据.get("维度", "") == "产出":
			经营加成 += float(命格数据.get("数值", 0)) / 100.0
	经营加成 = clamp(经营加成, 0.0, 0.20)   # F3 预览单殿阁封顶（与结算一致，独立 clamp 不接 economy_balance：
	var base: int = 经营基数.get(key, 1)
	var 保底: int = int(职.get("等级", 1)) * 殿阁保底津贴 if int(职.get("等级", 1)) >= 2 else 0
	return int(n * base * (1.0 + 经营加成) * 气运乘 * (1.0 + 产出buff + 产出池加成) * 等级乘区 * _殿阁等级_乘区(key) + 保底)
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
	# 灵田 8%：灵草丰收，当月灵石产出翻倍，有概率出高阶灵草
	if _本月灵田产出 > 0 and randf() < 0.08:
		灵石 += _本月灵田产出
		_加推演条目(文案表["hall_lingtian_harvest"], ET_RESOURCE, PRIO_NORMAL, {"殿阁": "lingtian"})
		# 丰收有概率产出高阶灵草（修真世界观：灵气充沛时灵草变异进阶）
		var 灵田殿阁等级: int = 1
		if 司职列表.has("lingtian"):
			灵田殿阁等级 = int(司职列表["lingtian"].get("等级", 1))
		if 灵田殿阁等级 >= 3 and randf() < 0.3:
			灵品灵草 += max(1, _本月灵田产出 / 10)
			_加推演条目("【灵田】丰收中灵草变异为灵品灵草！", "庶务", "低")
		if 灵田殿阁等级 >= 5 and randf() < 0.2:
			宝品灵草 += max(1, _本月灵田产出 / 15)
			_加推演条目("【灵田】丰收中灵草变异为宝品灵草！", "庶务", "低")
		if 灵田殿阁等级 >= 7 and randf() < 0.1:
			王品灵草 += max(1, _本月灵田产出 / 20)
			_加推演条目("【灵田】丰收中灵草变异为王品灵草！", "庶务", "中")
		# 极小概率出圣品/仙品灵草（可遇不可求）
		if randf() < 0.02:
			圣品灵草 += 1
			_加推演条目("【灵田】天降祥瑞，灵田中生出一株圣品灵草！", "庶务", "高")
		if randf() < 0.005:
			仙品灵草 += 1
			_加推演条目("【灵田】大道感应，灵田中生出一株仙品灵草！", "庶务", "极高")
	# 灵兽堂月度产出（修真世界观：饲养灵兽获取灵蚕丝/灵禽羽/灵马尾等特殊材料）
	if 司职列表.has("yushou"):
		var 灵兽堂等级: int = int(司职列表["yushou"].get("等级", 1))
		if 灵兽堂等级 >= 1:
			var 灵兽产出基数: int = 灵兽堂等级 * 2
			# 灵蚕丝：养蚕灵兽产出
			if randf() < 0.5:
				灵蚕丝 += max(1, 灵兽产出基数)
			# 灵禽羽：饲养灵禽产出
			if randf() < 0.4:
				灵禽羽 += max(1, 灵兽产出基数 / 2)
			# 灵马尾：饲养灵马产出
			if randf() < 0.3:
				灵马尾 += max(1, 灵兽产出基数 / 3)
			# 玉石：灵兽堂有概率产出玉石（灵兽衔玉）
			if randf() < 0.2:
				玉石 += max(1, 灵兽堂等级)
	# 矿脉 7%：富矿现世，当月灵石产出翻倍，有概率出高阶矿物
	if _本月矿脉产出 > 0 and randf() < 0.07:
		灵石 += _本月矿脉产出
		_加推演条目("【矿脉】富矿现世，灵石产出翻倍！", ET_RESOURCE, PRIO_NORMAL, {"殿阁": "kuangmai"})
		# 富矿有概率产出高阶矿物（修真世界观：富矿脉中伴生稀有矿）
		var 矿脉殿阁等级: int = 1
		if 司职列表.has("kuangmai"):
			矿脉殿阁等级 = int(司职列表["kuangmai"].get("等级", 1))
		if 矿脉殿阁等级 >= 4 and randf() < 0.3:
			精铁 += max(1, _本月矿脉产出 / 10)
			_加推演条目("【矿脉】富矿中伴生精铁！", "庶务", "低")
		if 矿脉殿阁等级 >= 6 and randf() < 0.2:
			玄铁 += max(1, _本月矿脉产出 / 15)
			_加推演条目("【矿脉】富矿中伴生玄铁！", "庶务", "低")
		if 矿脉殿阁等级 >= 8 and randf() < 0.1:
			庚金 += max(1, _本月矿脉产出 / 20)
			_加推演条目("【矿脉】富矿中伴生庚金！", "庶务", "中")
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
	# 符堂 15%：额外符润（灵石翻倍计入）；弟子赠符（S45-9 可参照丹堂 _造低阶物品 扩展）
	if _本月符堂产出 > 0 and randf() < 0.15:
		灵石 += _本月符堂产出
		_加推演条目("【符堂】符润外溢，灵石产出翻倍！", ET_RESOURCE, PRIO_NORMAL, {"殿阁": "futang"})
	# 器殿赠宝（P0 配置驱动梯度：+ P1 分配权重/保底/冗余 + P2 轻量堂主加成：
	if _本月器殿产出 > 0:
		# --- P2 轻量堂主加成：仅 1 层判断（匠心命格负责人）---
		var 触发率: float = 0.12
		var 稀有概率: float = 0.10
		var 器殿主: Variant = 司职列表.get("qitang", {}).get("负责人", null)
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
						# P1 冗余：法宝同品阶及以上已持有 ：拆解折算阵纹碎片入背包（不建宗门库房：
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
# ==================== 普通法宝系统（treasure_normal.csv 37件） ====================
var _普通法宝配置缓存: Dictionary = {}
var _普通法宝配置已载入: bool = false

# 载入普通法宝配置表
func _载入普通法宝配置() -> void:
	if _普通法宝配置已载入:
		return
	_普通法宝配置已载入 = true
	var p: String = "config/treasure_normal.csv"
	if not FileAccess.file_exists(p):
		return
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()  # 跳表头
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < 10:
			continue
		var tid: String = row[0].strip_edges()
		if tid == "":
			continue
		_普通法宝配置缓存[tid] = {
			"treasure_id": tid,
			"名称": row[1].strip_edges(),
			"品阶": row[2].strip_edges(),
			"子品阶": row[3].strip_edges(),
			"类型": row[4].strip_edges(),
			"基础攻击": int(row[5]) if row[5] != "" else 0,
			"基础防御": int(row[6]) if row[6] != "" else 0,
			"基础气血": int(row[7]) if row[7] != "" else 0,
			"被动效果": row[8].strip_edges(),
			"效果数值": row[9].strip_edges(),
			"售价": int(row[10]) if row.size() > 10 and row[10] != "" else 0,
		}
	f.close()

# 获取单个普通法宝配置
func 获取普通法宝配置(treasure_id: String) -> Dictionary:
	_载入普通法宝配置()
	return _普通法宝配置缓存.get(treasure_id, {})

# 获取所有普通法宝配置
func 获取所有普通法宝配置() -> Dictionary:
	_载入普通法宝配置()
	return _普通法宝配置缓存

# 计算弟子普通法宝战斗加成（口径＝储物袋临阵择一，与 Disciple.战斗属性 同源）
func 计算普通法宝战斗加成(弟子: Object) -> Dictionary:
	var 加成: Dictionary = {"攻击": 0, "防御": 0, "气血": 0, "被动效果": "", "效果数值": ""}
	if 弟子 == null:
		return 加成
	if not 弟子.has_method("选择出战法宝"):
		return 加成
	var tid: String = str(弟子.选择出战法宝(弟子.推断战况()))
	if tid == "":
		return 加成
	var 配置: Dictionary = 获取普通法宝配置(tid)
	if 配置.is_empty():
		return 加成
	加成["攻击"] = int(配置.get("基础攻击", 0))
	加成["防御"] = int(配置.get("基础防御", 0))
	加成["气血"] = int(配置.get("基础气血", 0))
	加成["被动效果"] = str(配置.get("被动效果", ""))
	加成["效果数值"] = str(配置.get("效果数值", ""))
	return 加成

# 收入弟子储物袋（原「装备普通法宝」）—— 普通法宝是外物，入袋随行携带，临阵由弟子自动择一祭出
func 装备普通法宝(弟子ID: int, treasure_id: String) -> Dictionary:
	var 配置: Dictionary = 获取普通法宝配置(treasure_id)
	if 配置.is_empty():
		return {"成功": false, "原因": "法宝不存在"}
	for d in 弟子列表:
		if d != null and d.弟子ID == 弟子ID:
			var 名: String = str(配置.get("名称", ""))
			if d.储物袋法宝.has(treasure_id):
				return {"成功": false, "原因": "储物袋中已有「%s」" % 名}
			if not d.收入储物袋(treasure_id):
				return {"成功": false, "原因": "储物袋已满（上限%d件），须先取出或提升境界" % d.储物袋容量()}
			return {"成功": true, "原因": "「%s」已收入储物袋" % 名}
	return {"成功": false, "原因": "弟子不存在"}

# 从储物袋取出（原「卸下普通法宝」）—— 不传法宝ID 则取出最后收入的一件
func 卸下普通法宝(弟子ID: int, treasure_id: String = "") -> Dictionary:
	for d in 弟子列表:
		if d != null and d.弟子ID == 弟子ID:
			var tid: String = treasure_id
			if tid == "":
				if d.储物袋法宝.is_empty():
					return {"成功": false, "原因": "储物袋空空如也"}
				tid = str(d.储物袋法宝[d.储物袋法宝.size() - 1])
			if not d.取出储物袋(tid):
				return {"成功": false, "原因": "储物袋中并无此法宝"}
			return {"成功": true, "原因": "「%s」已取出储物袋" % str(获取普通法宝配置(tid).get("名称", tid))}
	return {"成功": false, "原因": "弟子不存在"}

# ==================== 本命法宝配置表加载（treasure_innate.csv 26件） ====================
var _本命法宝配置缓存: Dictionary = {}
var _本命法宝配置已载入: bool = false

# 载入本命法宝配置表
func _载入本命法宝配置() -> void:
	if _本命法宝配置已载入:
		return
	_本命法宝配置已载入 = true
	var p: String = "config/treasure_innate.csv"
	if not FileAccess.file_exists(p):
		return
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()  # 跳表头
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < 8:
			continue
		var iid: String = row[0].strip_edges()
		if iid == "":
			continue
		_本命法宝配置缓存[iid] = {
			"innate_id": iid,
			"名称": row[1].strip_edges(),
			"品阶": row[2].strip_edges(),
			"子品阶": row[3].strip_edges(),
			"适用职业": row[4].strip_edges(),
			"主动技能": row[5].strip_edges(),
			"被动效果": row[6].strip_edges(),
			"成长值": row[7].strip_edges(),
			"最大等级": int(row[8]) if row.size() > 8 and row[8] != "" else 1,
		}
	f.close()

# ==================== 本命法宝：弟子自身祭炼（2026-09-15 老大定）====================
# 世界观铁则（修真小说通行设定，故**不可**改成"外购/宗主发放"模型）：
#   · 本命法宝是修士以**自身精血与神识**温养而成的贴身之物，与神魂相连、同生共死；
#     损毁则重伤、有损道基 —— 故**不可购买、不可赠予、不可夺取**，只能本人在洞府祭炼。
#   · 成器须「**境界基础 + 机缘**」双门槛：境界不足者神识撑不住器胚；机缘不济者无功而返。
#     ⇒ **并非人人都有本命法宝**，故不设"人人一件"的保底。
# 流程：境界 ≥ 金丹 → 宗门出灵石备料 → 祭炼（机缘检定）→ 成器（器型/品阶取自 treasure_innate.csv）
const 本命法宝境界门槛: String = "金丹"
const 本命法宝消耗系数: int = 1200        # 祭炼基础灵石消耗（按境界序递增）
const 本命法宝温养上限: int = 10           # 祭炼等级上限（每级 +10% 成长加成，与 disciple.gd 注释一致）

# 祭炼一次所需灵石（境界越高，器胚与材料越贵）
func 本命法宝祭炼消耗(弟子: Object) -> int:
	if 弟子 == null:
		return 本命法宝消耗系数
	var 序: int = Disciple.境界索引(str(弟子.境界))
	return 本命法宝消耗系数 * maxi(1, 序)

# 机缘检定成功率：六维·机缘主导，气运微调；区间 [0.35, 0.90] —— 永不保底、永不满
func 本命法宝祭炼成功率(弟子: Object) -> float:
	if 弟子 == null:
		return 0.35
	var 属: Dictionary = 弟子.属性 if typeof(弟子.属性) == TYPE_DICTIONARY else {}
	var 机缘: float = float(属.get("机缘", 500))
	var 气运: float = float(属.get("气运", 500))
	return clampf(0.35 + (机缘 - 400.0) / 1000.0 + (气运 - 400.0) / 2000.0, 0.35, 0.90)

# 弟子现持本命法宝配置（空 dict = 尚未祭炼）
func 弟子本命法宝配置(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {}
	return 获取本命法宝配置(str(弟子.本命法宝ID))

# 可否祭炼（供 UI 前置提示：门槛/成功率/消耗一次问清，避免"点了才知道不行"）
func 弟子可祭炼本命法宝(弟子: Object) -> Dictionary:
	if 弟子 == null:
		return {"ok": false, "reason": "无此弟子"}
	if str(弟子.本命法宝ID) != "":
		return {"ok": false, "reason": "已立本命法宝「%s」" % str(弟子本命法宝配置(弟子).get("名称", ""))}
	if not Disciple.境界达标(str(弟子.境界), 本命法宝境界门槛):
		return {"ok": false, "reason": "境界未至：需 %s 期，现为 %s" % [本命法宝境界门槛, str(弟子.境界)]}
	return {"ok": true, "reason": "", "成功率": 本命法宝祭炼成功率(弟子), "消耗": 本命法宝祭炼消耗(弟子)}

# 可及器胚：品阶上限随境界放开（金丹起步宝品，境界每升两阶放开一档）
func 本命法宝可祭炼列表(弟子: Object) -> Array:
	_载入本命法宝配置()
	var 出: Array = []
	if 弟子 == null:
		return 出
	var 品阶序: Array = ["宝品", "王品", "圣品", "仙品", "道品"]
	var 序: int = Disciple.境界索引(str(弟子.境界))
	var 档: int = clampi(int((序 - 2) / 2), 0, 品阶序.size() - 1)
	for iid in _本命法宝配置缓存.keys():
		var c: Dictionary = _本命法宝配置缓存[iid]
		if 品阶序.find(str(c.get("品阶", ""))) <= 档:
			出.append(c)
	return 出

# 祭炼：扣灵石 + 机缘检定；成器后写入 弟子.本命法宝ID（不可重复、不可转让）
func 祭炼本命法宝(弟子: Object) -> Dictionary:
	var 可: Dictionary = 弟子可祭炼本命法宝(弟子)
	if not bool(可.get("ok", false)):
		return {"ok": false, "msg": str(可.get("reason", "不可祭炼"))}
	var 耗: int = int(可.get("消耗", 0))
	if 灵石 < 耗:
		return {"ok": false, "msg": "宗门灵石不足（需 %d，现 %d）" % [耗, 灵石]}
	灵石 -= 耗
	if randf() > float(可.get("成功率", 0.35)):
		# 失败：精血虚耗、器胚崩散 —— 灵石已耗、法宝未成（修真常识：器不成则精血空耗，不作安慰性保底）
		弟子.履历.append({"日": 累计游戏日, "事件": "祭炼本命法宝未成（器胚崩散，耗灵石 %d）" % 耗})
		return {"ok": true, "成功": false, "msg": "%s 闭关祭炼，神识不继、器胚崩散，本命法宝未成。" % str(弟子.姓名)}
	var 候选: Array = 本命法宝可祭炼列表(弟子)
	if 候选.is_empty():
		灵石 += 耗
		return {"ok": false, "msg": "无可用器胚"}
	var 选: Dictionary = 候选[randi() % 候选.size()]
	弟子.本命法宝ID = str(选.get("innate_id", ""))
	弟子.履历.append({"日": 累计游戏日, "事件": "祭炼本命法宝「%s」" % str(选.get("名称", ""))})
	return {"ok": true, "成功": true, "名称": str(选.get("名称", "")),
		"msg": "%s 闭关祭炼，器成「%s」，神魂自此有寄。" % [str(弟子.姓名), str(选.get("名称", ""))]}

# 温养：以灵石养器，提升祭炼等级（每级 +10% 成长加成，上限 10 级）
func 温养本命法宝(弟子: Object) -> Dictionary:
	if 弟子 == null or str(弟子.本命法宝ID) == "":
		return {"ok": false, "msg": "尚无本命法宝，须先祭炼成器"}
	var 级: int = int(弟子.本命法宝祭炼等级)
	if 级 >= 本命法宝温养上限:
		return {"ok": false, "msg": "本命法宝已至温养极境（%d 重）" % 本命法宝温养上限}
	var 耗: int = 600 * (级 + 1)
	if 灵石 < 耗:
		return {"ok": false, "msg": "宗门灵石不足（需 %d，现 %d）" % [耗, 灵石]}
	灵石 -= 耗
	弟子.本命法宝祭炼等级 = 级 + 1
	return {"ok": true, "等级": 弟子.本命法宝祭炼等级,
		"msg": "%s 温养「%s」至第 %d 重，器灵渐明。" % [str(弟子.姓名), str(弟子本命法宝配置(弟子).get("名称", "")), 弟子.本命法宝祭炼等级]}

# 获取单个本命法宝配置
func 获取本命法宝配置(innate_id: String) -> Dictionary:
	_载入本命法宝配置()
	return _本命法宝配置缓存.get(innate_id, {})

# 获取所有本命法宝配置
func 获取所有本命法宝配置() -> Dictionary:
	_载入本命法宝配置()
	return _本命法宝配置缓存

# 计算本命法宝成长值加成（解析如"10%"、"12.5%"的成长值，返回全属性加成比例）
func 计算本命法宝成长加成(弟子: Object) -> Dictionary:
	var 加成: Dictionary = {"攻": 0.0, "防": 0.0, "血": 0.0, "速": 0.0}
	if 弟子 == null:
		return 加成
	# ★ 2026-09-15：本命法宝改为「弟子自身祭炼所得」，唯一来源 = `弟子.本命法宝ID`
	#   （旧实现读 装备["本命法宝"] 并按**名称**匹配 CSV —— 而祭炼链路写的是 id；
	#    且装备槽存档只在 dan_yao/ling_cai 两类回填，本命法宝放槽里读档即丢。）
	if 弟子 == null:
		return 加成
	# 弟子身上没有本命法宝 → 无加成（祭炼成器后才有）
	var iid: String = str(弟子.本命法宝ID) if "本命法宝ID" in 弟子 else ""
	if iid == "":
		return 加成
	var 配置: Dictionary = 获取本命法宝配置(iid)
	if 配置.is_empty():
		return 加成
	var 法宝名: String = str(配置.get("名称", ""))
	if 法宝名 == "":
		return 加成
	# 解析成长值（如"10%" → 0.10）
	var 成长值Str: String = str(配置.get("成长值", "0%"))
	var 成长值: float = 0.0
	if 成长值Str.contains("%"):
		成长值 = float(成长值Str.replace("%", "")) / 100.0
	else:
		成长值 = float(成长值Str) / 100.0
	# 祭炼等级加成（每级+10%成长加成，上限10级=+100%）
	var 祭炼等级: int = 0
	if 弟子 != null and "本命法宝祭炼等级" in 弟子:
		祭炼等级 = int(弟子.本命法宝祭炼等级)
	var 祭炼倍率: float = 1.0 + float(祭炼等级) * 0.10
	# 全属性成长加成（受祭炼等级影响）
	加成["攻"] = 成长值 * 祭炼倍率
	加成["防"] = 成长值 * 祭炼倍率
	加成["血"] = 成长值 * 祭炼倍率
	加成["速"] = 成长值 * 祭炼倍率
	return 加成


# 获取所有本命法宝列表（★ 2026-09-15：数据源从「弟子背包里穿戴位=本命法宝的物品」改为
#   弟子自身祭炼所得的 `弟子.本命法宝ID` —— 本命法宝不是物品、不进背包、不可转让）
func 获取所有本命法宝列表() -> Array:
	var 法宝列表: Array = []
	for d in 弟子列表:
		if d == null:
			continue
		var iid: String = str(d.本命法宝ID) if "本命法宝ID" in d else ""
		if iid == "":
			continue
		var cfg: Dictionary = 获取本命法宝配置(iid)
		if cfg.is_empty():
			continue
		法宝列表.append({
			"名称": str(cfg.get("名称", "")),
			"品阶": str(cfg.get("品阶", "")),
			"类别": "本命法宝",
			"战力": 0,
			"所属弟子": str(d.姓名),
			"已装备": true,
			"祭炼等级": int(d.本命法宝祭炼等级) if "本命法宝祭炼等级" in d else 0,
			"成长值": str(cfg.get("成长值", "")),
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

# 获取弟子当前的本命法宝（★ 2026-09-15：同源于 `弟子.本命法宝ID`，祭炼所得）
func 获取弟子本命法宝(弟子ID: int) -> Dictionary:
	for d in 弟子列表:
		if d != null and d.弟子ID == 弟子ID:
			var iid: String = str(d.本命法宝ID) if "本命法宝ID" in d else ""
			if iid == "":
				return {}
			var cfg: Dictionary = 获取本命法宝配置(iid)
			if cfg.is_empty():
				return {}
			return {
				"名称": str(cfg.get("名称", "")),
				"品阶": str(cfg.get("品阶", "")),
				"类别": "本命法宝",
				"战力": 0,
				"所属弟子": str(d.姓名),
				"祭炼等级": int(d.本命法宝祭炼等级) if "本命法宝祭炼等级" in d else 0,
			}
	return {}

# 造一枚指定类：品阶的物品（殿阁被动掉落用；仅填模板+算战力，不污染战斗数值红线）
# ===== 宗门库房物品读取辅助（Item 是 RefCounted，不是 Dictionary）=====
# 铁律：对 Item 只能用属性访问或单参 `get(属性名)`；写 `it.get("类别", "")` 会抛
#   "Invalid call to function 'get' in base 'RefCounted (Item)'. Expected 1 argument(s)"
#   并**中断整段逻辑**（丹堂施药 / 自动供给三课曾因此静默失效）。
# 另：历史生成点类别码不统一（"dan"/"dan_yao"/"丹药" 三码并存），此处统一归一到拼音码再比较。
func _物品类别码(it) -> String:
	if it == null:
		return ""
	var c: String = ""
	if it is Dictionary:
		c = str((it as Dictionary).get("类别", ""))
	else:
		c = str(it.get("类别"))
	match c:
		"dan", "丹药":
			return "dan_yao"
		"gongfa", "功法":
			return "gongfa"
		"fa_qi", "fabao", "装备", "法宝":
			return "fabao"
		"fu_lu", "符箓":
			return "fu_lu"
		_:
			return c

func _物品名(it) -> String:
	if it == null:
		return ""
	if it is Dictionary:
		return str((it as Dictionary).get("名称", ""))
	return str(it.get("名称"))

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
	# 负责人按加成高者优先自动◇ 宗主钦命：为空取最高分；新成员更高则替换（含掌门手定后被超越的情况：
	# P0-BUILD-2：已锁定的岗位不参与自动顶替（手动任：解除：◇ 宗主钦命负责人/ 解除负责人锁定）
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
	# 初始◇ 宗主钦命(：null)/应用负责人存：读档)/解除锁定 不触发清零（EC-P2~P4）：
	var 旧主事: Variant = 司职列表[key].get("负责人", null)
	司职列表[key]["负责人"] = d
	司职负责人存档[key] = d.姓名
	if 旧主事 != null and 旧主事 != d:
		司职列表[key]["政绩"] = 0
		var _st: Dictionary = 司职状态存档.get(key, {})
		_st["里程碑"] = 0
		_st["高政绩事件"] = false
		司职状态存档[key] = _st
# 人事任命负责人（UI 调用）
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
# 掌门◇ 宗主钦命负责人（UI 调用：
func 宗主钦命负责人(key: String, d: Disciple):

	if not 司职列表.has(key):
		return
	# S1 ：：阶位门槛闸（additive；legacy 阶位已按身份给到对应阶位，veteran 不被误拦，：.2：
	if d.阶位索引() < int(司职阶位门槛.get(key, 0)):
		return false
	_设负责人(key, d)
	司职列表[key]["负责人锁定"] = true
	宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "稀有度": "宗门", "名称": "人事◇ 宗主钦命", "文案": "【人事%s】被◇ 宗主钦命为%s主事" % [d.姓名, 司职列表[key]["名称"]]})
	_加推演条目("【人事%s】被◇ 宗主钦命为【%s】主事" % [d.姓名, 司职列表[key]["名称"]], ET_APPOINT, PRIO_NORMAL, {"弟子": d.姓名, "司职": key})
	弟子变动.emit()
func 应用负责人存档():

	for key in 司职负责人存档.keys():
		var 负: String = 司职负责人存档[key]
		var d: Disciple = _按姓名找(负)
		if d != null and 司职列表.has(key):
			司职列表[key]["负责人"] = d
# P0-BUILD-2：汇总所有「有负责人的殿阁」的全局微量 buff（每：+1%，按 加成维度→全局buff 映射累加）：
# 返回字典（数值为小数，表示百分比）：攻/防/血/速/修炼/产出/测灵
# 无负责人 ：：0 ：各应用点乘区 = 1.0，不改变任何数值（保证 test_combat 等数值红线不被触碰）：
func 汇总负责人全局buff() -> Dictionary:

	var buff: Dictionary = {"攻": 0.0, "防": 0.0, "血": 0.0, "速": 0.0, "修炼": 0.0, "产出": 0.0, "测灵": 0.0}
	# 殿阁 key ：全局 buff 维度 映射（功勋阁/御兽：洗髓：本项无负责人 buff，属阶段2：
	var 映射: Dictionary = {
		"qitang": "攻", "kuangmai": "防", "zhenfa": "防",
		"dantang": "血", "zhifa": "速", "tanwei": "速",
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
		var 阵维: String = 映射.get("zhenfa", "")
		if 阵维 != "":
			buff[阵维] = float(buff.get(阵维, 0.0)) + 0.01
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
		return {"ok": false, "msg": "已达品级上限（需更高宗门品级）"}
	if 门派等级 < 2:
		return {"ok": false, "msg": "需灵阶及以上宗门解锁殿阁升阶"}
	var 费: int = _升级消耗_灵石(等级)
	if 灵石 < 费:
		return {"ok": false, "msg": "灵石不足（需 %d灵石）" % [费]}
	灵石 -= 费
	司职列表[key]["等级"] = 等级 + 1
	_存司职状态(key)
	宗门纪事.append({"日期": 累计游戏日, "弟子": "", "稀有度": "宗门", "名称": "殿阁升级",
		"文案": "【营建%s】修缮至第 %d 重，产出增益" % [司职列表[key]["名称"], 等级 + 1]})
	_加推演条目("【营建%s】升至第 %d 重" % [司职列表[key]["名称"], 等级 + 1], ET_SECT, PRIO_NORMAL, {"殿阁": key})
	记任务进度("upgrade_building")   # S1-2：升级产业殿阁（玩家决策，日常 daily_009 / 周常 weekly_008）
	return {"ok": true, "msg": "%s 升至第 %d 重，消耗%d灵石" % [司职列表[key]["名称"], 等级 + 1, 费]}
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
	if d.阶位 == "无":
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

# 派系/权力斗争系统调用的查找工具（2026-09-08 补：外部批次只写了调用，未建实现）
# 入参兼容 String 与 int（调用处有 str(成员ID) 写法），内部统一按 int 比较 弟子ID。
func _按ID找弟子(弟子ID) -> Disciple:
	var 目标: int = int(弟子ID)
	if 目标 <= 0:
		return null
	for d in 弟子列表:
		if d.弟子ID == 目标:
			return d
	return null

func _按姓名找弟子(名: String) -> Disciple:
	return _按姓名找(名)

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
		# A0 性格统一：阵营→12型性格映射（disciple.gd:50 唯一来源），确保所有弟子落到12型之一
		var 阵营性格池: Dictionary = {
			"正道宗门": ["沉稳守道", "仁心济世", "守礼尊师"],
			"魔道邪宗": ["桀骜不羁", "杀伐果断", "狂傲绝世"],
			"中立散修": ["恬淡悟道", "谨慎多疑", "贪心逐缘"],
			"上古妖兽": ["豪迈仗义", "锐意争先"],
			"远古遗泽": ["孤僻清修", "恬淡悟道"],
		}
		if 抽取阵营 in 阵营性格池:
			d.性格 = 阵营性格池[抽取阵营].pick_random()
		else:
			d.性格 = Disciple.性格表.pick_random()
		# §4.0 目标驱动：初始人生主目标=修成大道，记入目标栈
		d.主目标 = "修成大道"
		d.目标栈 = [{"目标": "修成大道", "来源": "初心", "起始日": 累计游戏日}]
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

# ===== 测灵大典·首页活动窗后端（方案 B：改造现有招徒测灵，挂首页常驻 + 选人换人 + 奖励）=====
# 设计：首页小窗显示「今年测灵候选」；宗主可逐个换人 / 换一批，确认招收后按资质灵根结算奖励。
# 预览候选用 Disciple.new(true) 生成（不占 ID、不写纪事、不入册），确认时才落档。

# 测灵是否可办（冷却 测灵根冷却日 游戏日；从未办过亦可）
func 测灵可用() -> bool:
	if 上次测灵日 <= 0:
		return true
	return (累计游戏日 - 上次测灵日) >= 测灵根冷却日

# 本届名额（与 举办测灵根 一致）
func 测灵名额() -> int:
	var N: int = 5 + int(门派等级 / 2) + int(声望 / 500)
	return clampi(N, 5, 20)

# 生成单名预览候选（不占 ID / 不写纪事 / 不入册）
func _生成单个候选() -> Disciple:
	var d: Disciple = Disciple.new(true)
	d.司职 = "yuying"
	d.来源 = Disciple.弟子来源池.pick_random()
	var 抽取阵营: String = 加权抽取阵营("")
	var 阵营性格池: Dictionary = {
		"正道宗门": ["沉稳守道", "仁心济世", "守礼尊师"],
		"魔道邪宗": ["桀骜不羁", "杀伐果断", "狂傲绝世"],
		"中立散修": ["恬淡悟道", "谨慎多疑", "贪心逐缘"],
		"上古妖兽": ["豪迈仗义", "锐意争先"],
		"远古遗泽": ["孤僻清修", "恬淡悟道"],
	}
	if 抽取阵营 in 阵营性格池:
		d.性格 = 阵营性格池[抽取阵营].pick_random()
	else:
		d.性格 = Disciple.性格表.pick_random()
	d.主目标 = "修成大道"
	d.目标栈 = [{"目标": "修成大道", "来源": "初心", "起始日": 累计游戏日}]
	# 身份破格（仅按灵根品阶；与 举办测灵根 一致：升档在破格之后，故以原始品阶定身份）
	if d.灵根品阶 == "天品":
		d.身份 = "核心弟子"
	elif d.灵根品阶 == "极品":
		d.身份 = "内门弟子"
	# 测灵 buff / 气运升档（预览也允许，展示更真实的高品质概率）
	var 测灵buff: float = 汇总负责人全局buff().get("测灵", 0.0) + _执事殿测灵加()
	if 测灵buff > 0.0 and d.灵根品阶 != "天品" and randf() < 测灵buff:
		_提升灵根品阶一档(d)
	var 气运招募: float = 获取气运招募加成()
	if 气运招募 > 0.0 and d.灵根品阶 != "天品" and randf() < 气运招募:
		_提升灵根品阶一档(d)
	return d

# 生成本届候选名单（默认按名额）
func 生成测灵候选(数量: int = 0) -> Array[Disciple]:
	if 数量 <= 0:
		数量 = 测灵名额()
	var 候选: Array[Disciple] = []
	for i in 数量:
		候选.append(_生成单个候选())
	return 候选

# 替换单名候选（换人）
func 换测灵候选(候选: Array[Disciple], 索引: int) -> void:
	if 索引 >= 0 and 索引 < 候选.size():
		候选[索引] = _生成单个候选()

# 重掷整批
func 重掷测灵候选(数量: int = 0) -> Array[Disciple]:
	return 生成测灵候选(数量)

# 奖励预览（不落档）：返回 {贡献点, 灵石, 高潜人数}
func 测灵奖励预览(候选: Array[Disciple]) -> Dictionary:
	return _结算测灵奖励值(候选)

# 确认招收：落档候选、补 ID、结算奖励、更新冷却、天品纪事/buff、过场
func 确认测灵招收(候选: Array[Disciple]) -> Dictionary:
	if not 测灵可用():
		var 剩余: int = 测灵根冷却日 - int(累计游戏日 - 上次测灵日)
		return {"人数": 0, "过场": "", "新徒": [], "冷却剩余": 剩余, "奖励": {}}
	_确保字派_S1()
	var 新徒: Array[Disciple] = []
	for d in 候选:
		# 补真实 ID（预览时未分配）
		if d.弟子ID <= 0:
			d.弟子ID = Disciple.下一弟子ID
			Disciple.下一弟子ID += 1
		# D7：前三新徒默认内门（防卡进度）
		if 弟子列表.size() < 3 and d.身份 == "外门":
			d.身份 = "内门弟子"
		# 道号（外门取辈分字）
		d.辈分序 = 0
		if d.身份 == "外门" and not 辈分字派.is_empty():
			d.道号 = 辈分字派[0] + (d.姓名.left(1) if d.姓名.length() > 0 else "")
		# 高品质记入周期评分
		if d.灵根品阶 in ["天品", "极品", "上品"]:
			周期评分.记高品质新弟子()
		弟子列表.append(d)
		新徒.append(d)
		_新手_检查条件("recruit_count")
		_新手_评估后续()
	_加声望(新徒.size())
	上次测灵日 = 累计游戏日
	# 天品破格：纪事 + 全宗气运 buff
	for 徒 in 新徒:
		if 徒.灵根品阶 == "天品":
			宗门纪事.append({"日期": 累计游戏日, "弟子": 徒.姓名, "弟子ID": 徒.弟子ID, "稀有度": "天品", "名称": "天品灵根弟子", "文案": 文案表["recruit_tianpin_found"] % [徒.姓名]})
			设置气运buff(0.03, 0.02, 7)
			立大功标记[徒.姓名] = true
			break
	# 奖励结算（贡献点 + 灵石 + 忠诚）
	var 奖励: Dictionary = _结算测灵奖励落档(新徒)
	var 有天品: bool = false
	for 新弟子 in 新徒:
		if 新弟子.灵根品阶 == "天品":
			有天品 = true
			break
	var 过场: String = Lore.取测灵根过场(新徒.size(), 新徒, 有天品)
	弟子变动.emit()
	return {"人数": 新徒.size(), "过场": 过场, "新徒": 新徒, "奖励": 奖励}

# 奖励数值（纯计算，不落档）：贡献点随资质灵根，高潜力（上品+）额外贡献+灵石
func _结算测灵奖励值(候选: Array[Disciple]) -> Dictionary:
	var 品阶值: Dictionary = {"凡品": 1, "良品": 2, "上品": 3, "极品": 4, "天品": 5}
	var 贡献: int = 0
	var 灵石: int = 0
	var 高潜: int = 0
	for d in 候选:
		var pv: int = int(品阶值.get(d.灵根品阶, 1))
		var 资质值: float = d.资质.to_float() if d.资质 != "" else 50.0
		var 个贡: int = pv * 2 + int(round(资质值 / 20.0))
		贡献 += 个贡
		if pv >= 3:
			高潜 += 1
			贡献 += pv * 3
			if pv == 3:
				灵石 += 80
			elif pv == 4:
				灵石 += 200
			else:
				灵石 += 500
	return {"贡献点": 贡献, "灵石": 灵石, "高潜人数": 高潜}

# 奖励落档：调用 _结算测灵奖励值 并写入宗门资源 + 新弟子忠诚
func _结算测灵奖励落档(新徒: Array[Disciple]) -> Dictionary:
	var 奖励: Dictionary = _结算测灵奖励值(新徒)
	if int(奖励.get("贡献点", 0)) > 0:
		贡献点 += int(奖励.get("贡献点", 0))
	if int(奖励.get("灵石", 0)) > 0:
		灵石 += int(奖励.get("灵石", 0))
	for d in 新徒:
		d.忠诚 = clampi(int(d.忠诚) + 5, 0, 100)
	return 奖励

func _注册全部():

	for d in 弟子列表:
		if d.司职 != "":
			_注册入堂(d)
# ============ 门派等级 / 声望 / 繁荣 ============
const 门派等级上限: int = 10   # P0 ：10 级（S1 赛季接入殿阁等级体系后可上调：
func 更新门派():

	var 总战力:= 0
	var 最高境界序: int = 0
	for d in 弟子列表:
		总战力+= d.总战力()
		var 境序: int = Disciple.境界序.find(d.境界)
		if 境序 > 最高境界序:
			最高境界序 = 境序
	# 修真世界观7维综合评估：灵脉根基 > 顶尖战力 > 护山大阵 > 基础设施 > 资源储备 > 底蕴传承 > 宗门声望
	# 1.灵脉根基（20%）：灵脉是宗门立足之本，1级灵脉最多支撑3级宗门
	var 灵脉贡献: float = float(min(灵脉等级, 10)) * 0.3
	# 2.顶尖战力（15%）：修真世界看顶尖战力，一人镇宗
	var 顶尖战力贡献: float = float(最高境界序) * 0.4
	# 3.护山大阵（15%）：无阵不成宗，大阵等级决定防御力
	var 大阵贡献: float = float(min(int(阵法管理系统.阵法等级.get("hushan", 0)), 10)) * 0.2
	# 4.基础设施（15%）：殿阁数量+洞府规模
	var 殿阁数: int = 司职列表.size()
	var 基础设施贡献: float = (float(殿阁数) * 0.2 + float(洞府数量) / 20.0) * 0.3
	# 5.资源储备（15%）：灵石+材料+丹药的家底
	var 资源贡献: float = (float(灵石) / 20000.0 + float(灵草) / 2000.0 + float(矿石) / 2000.0) * 0.5
	资源贡献 = min(资源贡献, 2.0)
	# 6.底蕴传承（10%）：藏经阁功法数量
	var 底蕴贡献: float = float(藏经阁功法列表.size()) / 10.0
	底蕴贡献 = min(底蕴贡献, 1.0)
	# 7.宗门声望（10%）：弟子在外历练/做任务闯出的名声
	var 声望贡献: float = float(声望) / 1000.0
	声望贡献 = min(声望贡献, 1.0)
	# 综合计算
	var 综合评分: float = 灵脉贡献 + 顶尖战力贡献 + 大阵贡献 + 基础设施贡献 + 资源贡献 + 底蕴贡献 + 声望贡献
	var 新等级: int = 1 + int(综合评分)
	# 硬约束：灵脉品级决定宗门上限（修真世界常识）
	var 灵脉上限: int = 3
	if 灵脉等级 >= 3:
		灵脉上限 = 5
	if 灵脉等级 >= 5:
		灵脉上限 = 7
	if 灵脉等级 >= 7:
		灵脉上限 = 9
	if 灵脉等级 >= 9:
		灵脉上限 = 10
	# 硬约束：护山大阵等级决定宗门上限
	var 大阵等级_实际: int = int(阵法管理系统.阵法等级.get("hushan", 0))
	var 大阵上限: int = 2
	if 大阵等级_实际 >= 2:
		大阵上限 = 4
	if 大阵等级_实际 >= 4:
		大阵上限 = 6
	if 大阵等级_实际 >= 6:
		大阵上限 = 8
	if 大阵等级_实际 >= 8:
		大阵上限 = 10
	var 等级上限: int = min(灵脉上限, 大阵上限, 门派等级上限)
	新等级 = clamp(新等级, 1, 等级上限)
	# P1：计算可晋升等级（综合评分达到下一级门槛且未超过上限）
	if 新等级 > 门派等级 and 新等级 <= 等级上限:
		可晋升等级 = 新等级
	else:
		可晋升等级 = 0
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
	# S34：凡人城镇改为真数据源（派生自 郡县状态；不再由信徒数捏造假镇，避免每次 更新门派() 覆盖经营结果）
	王朝系统.凡人城镇.clear()
	if 王朝系统.郡县状态.is_empty():
		_初始化郡县状态_S34()
	for k in 王朝系统.郡县状态.keys():
		var 郡: Dictionary = 王朝系统.郡县状态[k]
		if not bool(郡.get("凡俗", false)):
			continue
		王朝系统.凡人城镇.append({"名": str(郡.get("名", "")), "人口": int(郡.get("人口", 0))})
# 距下一级信息（主界面展示用）：基于已存储门派等级，计算单靠声望补齐时的缺口
func 距下一级信息() -> Dictionary:

	var 总战力:= 0
	var 最高境界序: int = 0
	for d in 弟子列表:
		总战力+= d.总战力()
		var 境序: int = Disciple.境界序.find(d.境界)
		if 境序 > 最高境界序:
			最高境界序 = 境序
	# 7维综合评分（与更新门派一致）
	var 灵脉贡献: float = float(min(灵脉等级, 10)) * 0.3
	var 顶尖战力贡献: float = float(最高境界序) * 0.4
	var 大阵贡献: float = float(min(int(阵法管理系统.阵法等级.get("hushan", 0)), 10)) * 0.2
	var 殿阁数: int = 司职列表.size()
	var 基础设施贡献: float = (float(殿阁数) * 0.2 + float(洞府数量) / 20.0) * 0.3
	var 资源贡献: float = min((float(灵石) / 20000.0 + float(灵草) / 2000.0 + float(矿石) / 2000.0) * 0.5, 2.0)
	var 底蕴贡献: float = min(float(藏经阁功法列表.size()) / 10.0, 1.0)
	var 声望贡献: float = min(float(声望) / 1000.0, 1.0)
	var 综合评分: float = 灵脉贡献 + 顶尖战力贡献 + 大阵贡献 + 基础设施贡献 + 资源贡献 + 底蕴贡献 + 声望贡献
	var 等级 := 门派等级
	# 硬约束上限
	var 灵脉上限: int = 3
	if 灵脉等级 >= 3: 灵脉上限 = 5
	if 灵脉等级 >= 5: 灵脉上限 = 7
	if 灵脉等级 >= 7: 灵脉上限 = 9
	if 灵脉等级 >= 9: 灵脉上限 = 10
	var 大阵等级_实际: int = int(阵法管理系统.阵法等级.get("hushan", 0))
	var 大阵上限: int = 2
	if 大阵等级_实际 >= 2: 大阵上限 = 4
	if 大阵等级_实际 >= 4: 大阵上限 = 6
	if 大阵等级_实际 >= 6: 大阵上限 = 8
	if 大阵等级_实际 >= 8: 大阵上限 = 10
	var 等级上限: int = min(灵脉上限, 大阵上限, 门派等级上限)
	var 已满: bool = 等级 >= 等级上限
	var 缺口 := 0
	if not 已满:
		var 下一级评分: float = float(等级)  # 升到下一级需要综合评分>=当前等级
		var 评分缺口: float = 下一级评分 - 综合评分
		if 评分缺口 > 0:
			缺口 = int(ceil(评分缺口 * 100.0))
	# 瓶颈提示
	var 瓶颈: String = ""
	if 灵脉上限 < 等级 + 1:
		瓶颈 = "灵脉品级不足，需升级灵脉"
	elif 大阵上限 < 等级 + 1:
		瓶颈 = "护山大阵品级不足，需升级大阵"
	return {"等级": 等级, "下一级": min(等级 + 1, 等级上限), "声望缺口": max(缺口, 0), "已满": 已满, "综合评分": 综合评分, "等级上限": 等级上限, "瓶颈": 瓶颈,
		"灵脉贡献": 灵脉贡献, "顶尖战力贡献": 顶尖战力贡献, "大阵贡献": 大阵贡献, "基础设施贡献": 基础设施贡献, "资源贡献": 资源贡献, "底蕴贡献": 底蕴贡献, "声望贡献": 声望贡献}

# P1：举办晋升大典（达到门槛后玩家主动举办，立即生效）
func 举办晋升大典() -> Dictionary:
	if 可晋升等级 <= 0 or 可晋升等级 <= 门派等级:
		return {"成功": false, "原因": "当前无可晋升品级"}
	# 大典消耗：灵石（按等级递增，调用统一函数）
	var 消耗灵石: int = 获取晋升大典消耗()
	if 灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足，举办晋升大典需%d灵石" % 消耗灵石}
	灵石 -= 消耗灵石
	# 立即晋升
	var 旧等级: int = 门派等级
	门派等级 = 可晋升等级
	可晋升等级 = 0
	门派等级目标 = 门派等级
	# 仪式感：全宗庆祝
	声望 += 可晋升等级 * 10  # 大典昭告天下，声望大涨
	繁荣 = min(100, 繁荣 + 10)  # 全宗欢庆，繁荣提升
	# 弟子士气提升（临时修炼加成，持续30游戏日）
	for d in 弟子列表:
		if d != null and d is Disciple and d.状态 == "在宗":
			d.增加心境(5)  # 大典激励，道心提升
	# 纪事和推演条目
	var 等级称呼: String = ""
	if 门派等级 <= 3:
		等级称呼 = "小型宗门"
	elif 门派等级 <= 6:
		等级称呼 = "中型宗门"
	elif 门派等级 <= 9:
		等级称呼 = "大型宗门"
	else:
		等级称呼 = "超级宗门"
	添加纪事("宗门大事件", "晋升大典", "太玄宗举办晋升大典，正式晋升至%d级，位列%s之林。大典之上，万宗来贺，声威远播。" % [门派等级, 等级称呼], 3)
	_加推演条目("太玄宗晋升大典圆满成功，宗门品级升至%d品，位列%s。全宗上下欢欣鼓舞，弟子道心皆有精进。" % [门派等级, 等级称呼], ET_SECT, PRIO_HIGH, {})
	_复检里程碑()
	_复检成就()
	return {"成功": true, "旧等级": 旧等级, "新等级": 门派等级, "消耗灵石": 消耗灵石, "等级称呼": 等级称呼}

# 获取晋升大典消耗
func 获取晋升大典消耗() -> int:
	if 可晋升等级 <= 0:
		return 0
	return 可晋升等级 * 500

# ============ 宗主独立场所系统 ============
## 获取宗主场所等级
func 获取宗主场所等级(场所: String) -> int:
	match 场所:
		"丹房": return 宗主丹房等级
		"炼器室": return 宗主炼器室等级
		"制符室": return 宗主制符室等级
		"傀儡工坊": return 宗主傀儡工坊等级
		"毒室": return 宗主毒室等级
	return 1

## 获取宗主场所加成（成功率/高品质率）
func 获取宗主场所加成(场所: String) -> Dictionary:
	var 等级: int = 获取宗主场所等级(场所)
	var 成功率加成: float = 0.0
	var 高品质加成: float = 0.0
	if 等级 >= 3:
		成功率加成 = 0.05
	if 等级 >= 5:
		成功率加成 = 0.10
		高品质加成 = 0.05
	if 等级 >= 7:
		成功率加成 = 0.15
		高品质加成 = 0.10
	if 等级 >= 10:
		成功率加成 = 0.20
		高品质加成 = 0.15
	return {"等级": 等级, "成功率加成": 成功率加成, "高品质加成": 高品质加成}

## 获取宗主场所升级消耗
func 获取宗主场所升级消耗(场所: String) -> int:
	var 等级: int = 获取宗主场所等级(场所)
	return 等级 * 1000

## 升级宗主场所
func 升级宗主场所(场所: String) -> Dictionary:
	var 等级: int = 获取宗主场所等级(场所)
	if 等级 >= 10:
		return {"成功": false, "原因": "场所已达最高品级"}
	var 消耗: int = 获取宗主场所升级消耗(场所)
	if 灵石 < 消耗:
		return {"成功": false, "原因": "灵石不足（需%d）" % 消耗}
	灵石 -= 消耗
	match 场所:
		"丹房": 宗主丹房等级 += 1
		"炼器室": 宗主炼器室等级 += 1
		"制符室": 宗主制符室等级 += 1
		"傀儡工坊": 宗主傀儡工坊等级 += 1
		"毒室": 宗主毒室等级 += 1
	添加纪事("宗主", "升级场所", "宗主%s升级至%d级，地火旺盛，生产效率大增。" % [场所, 等级 + 1], 2)
	return {"成功": true, "场所": 场所, "新等级": 等级 + 1, "消耗": 消耗}

## 获取所有宗主场所列表
func 获取宗主场所列表() -> Array:
	return [
		{"场所": "丹房", "名称": "宗主丹房", "描述": "宗主专属炼丹之所，地火醇厚", "等级": 宗主丹房等级},
		{"场所": "炼器室", "名称": "宗主炼器室", "描述": "宗主专属炼器之地，锤法通灵", "等级": 宗主炼器室等级},
		{"场所": "制符室", "名称": "宗主制符室", "描述": "宗主专属绘符之室，灵墨飘香", "等级": 宗主制符室等级},
		{"场所": "傀儡工坊", "名称": "宗主傀儡工坊", "描述": "宗主专属炼制傀儡之地", "等级": 宗主傀儡工坊等级},
		{"场所": "毒室", "名称": "宗主毒室", "描述": "宗主专属制毒之所，毒雾缭绕", "等级": 宗主毒室等级},
	]

# ============ 毒道系统（修真界旁门大道） ============
## 毒药配置（品阶×类型）
const 毒药配置: Dictionary = {
	# 腐蚀毒：腐蚀肉身/法宝
	"化骨水": {"品阶": "凡品", "类型": "腐蚀毒", "效果": "腐蚀肉身", "伤害": 50, "材料": "毒草×5+矿石×3"},
	"腐仙散": {"品阶": "灵品", "类型": "腐蚀毒", "效果": "腐蚀法宝", "伤害": 150, "材料": "毒草×15+矿石×10"},
	"蚀仙毒": {"品阶": "宝品", "类型": "腐蚀毒", "效果": "腐蚀仙躯", "伤害": 400, "材料": "毒草×40+毒兽内丹×1"},
	# 麻痹毒：麻痹灵力/行动
	"软筋散": {"品阶": "凡品", "类型": "麻痹毒", "效果": "麻痹行动", "伤害": 30, "材料": "毒草×3+毒虫×2"},
	"迷仙散": {"品阶": "灵品", "类型": "麻痹毒", "效果": "麻痹灵力", "伤害": 100, "材料": "毒草×10+毒虫×8"},
	"销魂散": {"品阶": "宝品", "类型": "麻痹毒", "效果": "销魂蚀骨", "伤害": 300, "材料": "毒草×30+毒虫×20"},
	# 元神毒：侵蚀元神/道心
	"噬魂烟": {"品阶": "灵品", "类型": "元神毒", "效果": "侵蚀元神", "伤害": 200, "材料": "毒兽内丹×2+毒草×20"},
	"心魔散": {"品阶": "宝品", "类型": "元神毒", "效果": "诱发心魔", "伤害": 500, "材料": "毒兽内丹×5+毒草×50"},
	"灭魂毒": {"品阶": "王品", "类型": "元神毒", "效果": "湮灭元神", "伤害": 1000, "材料": "毒兽内丹×10+万年毒草×1"},
	# 瘟疫毒：传染性群体伤害
	"瘟癀散": {"品阶": "宝品", "类型": "瘟疫毒", "效果": "传染瘟疫", "伤害": 300, "材料": "毒兽内丹×3+毒虫×30"},
	"痘毒": {"品阶": "王品", "类型": "瘟疫毒", "效果": "天花痘毒", "伤害": 800, "材料": "毒兽内丹×8+毒虫×50"},
	# 慢性毒：长期积累发作
	"三尸脑神丹": {"品阶": "王品", "类型": "慢性毒", "效果": "三尸入脑", "伤害": 600, "材料": "毒虫×50+毒草×100"},
	"七日醉": {"品阶": "灵品", "类型": "慢性毒", "效果": "七日发作", "伤害": 150, "材料": "毒草×20+毒虫×10"},
	# 解毒药
	"解毒丹": {"品阶": "灵品", "类型": "解毒药", "效果": "解除凡品/灵品毒", "伤害": 0, "材料": "灵草×15+灵晶×3"},
	"辟毒丹": {"品阶": "宝品", "类型": "解毒药", "效果": "免疫毒素+50%", "伤害": 0, "材料": "灵草×30+灵晶×5"},
}

## 获取所有毒药列表
func 获取毒药列表() -> Array:
	var 列表: Array = []
	for 毒药名 in 毒药配置.keys():
		var cfg = 毒药配置[毒药名]
		列表.append({"名称": 毒药名, "品阶": cfg["品阶"], "类型": cfg["类型"], "效果": cfg["效果"], "伤害": cfg["伤害"], "材料": cfg["材料"]})
	return 列表

## 炼制毒药（宗主或弟子使用）
func 炼制毒药(毒药名: String, 制作者 = null) -> Dictionary:
	if not 毒药配置.has(毒药名):
		return {"成功": false, "原因": "未知毒药：%s" % 毒药名}
	var cfg = 毒药配置[毒药名]
	# 使用宗主毒室等级 + 毒道境界加成
	var 毒室等级: int = 获取宗主场所等级("毒室")
	var 境界加成: Dictionary = 获取毒道境界加成()
	var 成功率: float = 0.4 + float(毒室等级) * 0.05 + float(境界加成["成功率加成"])
	成功率 = min(0.95, 成功率)
	# 消耗精力（宗主制作）
	if 制作者 != null and 制作者 is Disciple:
		if 制作者.精力 < 15:
			return {"成功": false, "原因": "精力不足"}
		制作者.精力 -= 15
	# 炼制
	if randf() < 成功率:
		var 毒药 = Item.new()
		毒药.名称 = 毒药名
		毒药.类型 = "毒药"
		毒药.品阶 = cfg["品阶"]
		毒药.类别 = "du_yao"
		宗门库房.append(毒药)
		添加纪事("毒道", "炼制毒药", "炼制%s（%s/%s）成功，毒雾缭绕，令人心悸。" % [毒药名, cfg["品阶"], cfg["类型"]], 2)
		# 按毒药类型区分代价（修真世界观：杀伤性毒有伤天和，控制性毒只是手段，解毒药正面）
		var 毒类型: String = str(cfg["类型"])
		if 毒类型 == "解毒药":
			# 解毒药：正面，无代价，反而增加正道声望
			增加阵营声望("正道宗门", 2)
			if 制作者 != null and 制作者 is Disciple:
				制作者.功德 = int(制作者.功德) + 5
		elif 毒类型 == "麻痹毒":
			# 麻痹毒：控制性，可解，不加业力心魔，正道声望小幅下降
			增加阵营声望("正道宗门", -1)
			增加阵营声望("魔道邪宗", 1)
		else:
			# 杀伤性毒（腐蚀/元神/瘟疫/慢性）：有伤天和，加业力心魔，正道声望大幅下降
			if 制作者 != null and 制作者 is Disciple:
				制作者.业力 = int(制作者.业力) + 5
				制作者.心魔值 = clamp(float(制作者.心魔值) + 1.0, 0.0, 100.0)
			增加阵营声望("正道宗门", -3)
			增加阵营声望("魔道邪宗", 2)
		# 增加毒道经验（按品阶）
		var 经验值: int = 10
		match cfg["品阶"]:
			"凡品": 经验值 = 5
			"灵品": 经验值 = 15
			"宝品": 经验值 = 40
			"王品": 经验值 = 100
			"道品": 经验值 = 250
			"圣品": 经验值 = 500
			"仙品": 经验值 = 1000
			_: 经验值 = 10
		增加毒道经验(经验值)
		return {"成功": true, "产出": 毒药名, "品阶": cfg["品阶"], "类型": cfg["类型"]}
	else:
		添加纪事("毒道", "炼制失败", "炼制%s失败，毒气反噬，材料损毁。" % 毒药名, 1)
		# 炼制失败也有代价：毒气反噬，心魔+2（仅杀伤性毒）
		var 毒类型: String = str(cfg["类型"])
		if 毒类型 != "解毒药" and 毒类型 != "麻痹毒":
			if 制作者 != null and 制作者 is Disciple:
				制作者.心魔值 = clamp(float(制作者.心魔值) + 2.0, 0.0, 100.0)
		return {"成功": false, "原因": "炼制失败", "成功率": 成功率}

## 战斗中使用毒药（战前施毒）
func 战斗施毒(毒药名: String, 目标战力: int) -> Dictionary:
	if not 毒药配置.has(毒药名):
		return {"成功": false, "原因": "未知毒药"}
	var cfg = 毒药配置[毒药名]
	if cfg["类型"] == "解毒药":
		return {"成功": false, "原因": "解毒药不能用于进攻"}
	# 从库房消耗毒药
	var 找到: bool = false
	for i in range(宗门库房.size()):
		var it = 宗门库房[i]
		if it != null and it.名称 == 毒药名:
			宗门库房.remove_at(i)
			找到 = true
			break
	if not 找到:
		return {"成功": false, "原因": "库房无%s" % 毒药名}
	# 毒伤计算（按品阶和类型）
	var 毒伤: int = int(cfg["伤害"])
	var 减伤: float = 0.0
	match cfg["类型"]:
		"腐蚀毒": 减伤 = 0.3  # 腐蚀法宝，降低防御
		"麻痹毒": 减伤 = 0.2  # 麻痹行动，降低输出
		"元神毒": 减伤 = 0.4  # 侵蚀元神，大幅削弱
		"瘟疫毒": 减伤 = 0.25 # 群体伤害
		"慢性毒": 减伤 = 0.15 # 持续伤害
		_:
			减伤 = 0.2
	var 实际减伤: int = int(目标战力 * 减伤)
	添加纪事("毒道", "战斗施毒", "战前施放%s（%s），敌人道行削弱%d，毒伤%d。" % [毒药名, cfg["类型"], 实际减伤, 毒伤], 2)
	# 按毒药类型区分战斗用毒代价
	var 毒类型: String = str(cfg["类型"])
	if 毒类型 == "麻痹毒":
		# 麻痹毒：控制性，正道声望小幅下降
		增加阵营声望("正道宗门", -2)
		增加阵营声望("魔道邪宗", 1)
	else:
		# 杀伤性毒：正道声望大幅下降
		增加阵营声望("正道宗门", -5)
		增加阵营声望("魔道邪宗", 3)
	return {"成功": true, "毒伤": 毒伤, "战力削弱": 实际减伤, "毒药": 毒药名}

## 获取毒道总览
func 毒道总览() -> Dictionary:
	var 毒药数量: int = 0
	for it in 宗门库房:
		if it != null and it.类别 == "du_yao":
			毒药数量 += 1
	var 境界: String = 获取毒道境界()
	var 毒体: String = 获取毒体境界()
	var 炼丹加成: Dictionary = 获取毒道炼丹加成()
	return {"毒药数量": 毒药数量, "毒室等级": 获取宗主场所等级("毒室"), "可炼制毒药": 获取毒药列表().size(), "毒道境界": 境界, "毒道经验": 毒道经验, "毒体境界": 毒体, "毒体经验": 毒体经验, "炼丹成功率加成": 炼丹加成["成功率加成"], "解毒药效果加成": 获取解毒药效果加成()}

## 毒道境界配置（修真界毒道旁门的修为境界）
const 毒道境界表: Array = [
	{"境界": "毒道学徒", "所需经验": 0, "成功率加成": 0.0, "毒伤加成": 0.0, "描述": "初窥毒道门径，认得几株毒草"},
	{"境界": "毒师", "所需经验": 100, "成功率加成": 0.05, "毒伤加成": 0.1, "描述": "熟练制毒，小有名气，旁人不敢轻易招惹"},
	{"境界": "大毒师", "所需经验": 500, "成功率加成": 0.1, "毒伤加成": 0.2, "描述": "毒道大成，一炉毒出，百里无生机"},
	{"境界": "毒仙", "所需经验": 2000, "成功率加成": 0.15, "毒伤加成": 0.35, "描述": "毒道入仙，举手投足皆是毒，令人闻风丧胆"},
	{"境界": "毒圣", "所需经验": 5000, "成功率加成": 0.2, "毒伤加成": 0.5, "描述": "毒道巅峰，万毒之祖，传说中可毒杀仙人的存在"},
]

## 获取当前毒道境界
func 获取毒道境界() -> String:
	var 当前境界: String = "毒道学徒"
	for 境 in 毒道境界表:
		if 毒道经验 >= int(境["所需经验"]):
			当前境界 = str(境["境界"])
	return 当前境界

## 获取毒道境界加成
func 获取毒道境界加成() -> Dictionary:
	var 境界: String = 获取毒道境界()
	for 境 in 毒道境界表:
		if str(境["境界"]) == 境界:
			return {"成功率加成": float(境["成功率加成"]), "毒伤加成": float(境["毒伤加成"]), "描述": str(境["描述"])}
	return {"成功率加成": 0.0, "毒伤加成": 0.0, "描述": ""}

## 增加毒道经验
func 增加毒道经验(数量: int) -> void:
	var 旧境界: String = 获取毒道境界()
	毒道经验 += 数量
	var 新境界: String = 获取毒道境界()
	if 新境界 != 旧境界:
		添加纪事("毒道", "境界突破", "毒道修为突破至%s！%s" % [新境界, 获取毒道境界加成()["描述"]], 3)
	# 毒体修炼：炼制毒药时自动积累毒体经验（长期接触毒物，身体产生抗性）
	毒体经验 += int(数量 / 2)
	_检查毒体突破()

# ============ 毒医双修系统（用毒大师即药理专家，治疗也是一把好手） ============
## 毒体境界配置（长期用毒制毒，身体产生抗毒性）
const 毒体境界表: Array = [
	{"境界": "凡躯", "所需经验": 0, "毒抗": 0.0, "毒伤加成": 0.0, "描述": "凡俗之躯，中毒即伤"},
	{"境界": "凡毒不侵", "所需经验": 200, "毒抗": 0.2, "毒伤加成": 0.05, "描述": "常触毒物，凡品毒药已难伤身"},
	{"境界": "灵毒不侵", "所需经验": 800, "毒抗": 0.4, "毒伤加成": 0.1, "描述": "灵品毒药亦能抵御，毒道小成"},
	{"境界": "宝毒不侵", "所需经验": 2000, "毒抗": 0.6, "毒伤加成": 0.2, "描述": "宝品毒药难侵，毒道大成"},
	{"境界": "万毒不侵", "所需经验": 5000, "毒抗": 0.8, "毒伤加成": 0.35, "描述": "万毒辟易，毒道入仙"},
	{"境界": "百毒不侵", "所需经验": 10000, "毒抗": 0.95, "毒伤加成": 0.5, "描述": "传说中的毒体，天下万毒皆不能伤，反能为己用"},
]

## 获取当前毒体境界
func 获取毒体境界() -> String:
	var 当前境界: String = "凡躯"
	for 境 in 毒体境界表:
		if 毒体经验 >= int(境["所需经验"]):
			当前境界 = str(境["境界"])
	return 当前境界

## 获取毒体境界加成
func 获取毒体加成() -> Dictionary:
	var 境界: String = 获取毒体境界()
	for 境 in 毒体境界表:
		if str(境["境界"]) == 境界:
			return {"毒抗": float(境["毒抗"]), "毒伤加成": float(境["毒伤加成"]), "描述": str(境["描述"])}
	return {"毒抗": 0.0, "毒伤加成": 0.0, "描述": ""}

## 检查毒体突破
func _检查毒体突破() -> void:
	var 当前境界: String = 获取毒体境界()
	if 当前境界 != _上次毒体境界:
		_上次毒体境界 = 当前境界
		添加纪事("毒道", "毒体突破", "毒体修炼至%s！%s" % [当前境界, 获取毒体加成()["描述"]], 3)

## 毒医双修：毒道境界影响炼丹（懂药理者，炼丹亦精）
func 获取毒道炼丹加成() -> Dictionary:
	var 境界加成: Dictionary = 获取毒道境界加成()
	var 毒体加成: Dictionary = 获取毒体加成()
	# 毒道境界每级给炼丹成功率+2%，高品质率+1%
	# 毒体境界额外给炼丹成功率+1%（身体抗毒，敢用猛药）
	var 成功率加成: float = float(境界加成["成功率加成"]) * 0.4 + float(毒体加成["毒抗"]) * 0.1
	var 高品质加成: float = float(境界加成["成功率加成"]) * 0.2
	return {"成功率加成": 成功率加成, "高品质加成": 高品质加成, "毒医等级": 获取毒道境界()}

## 毒医双修：解毒药炼制效果加成（用毒大师最懂如何解毒）
func 获取解毒药效果加成() -> float:
	var 境界: String = 获取毒道境界()
	var 加成: float = 1.0
	match 境界:
		"毒道学徒": 加成 = 1.0
		"毒师": 加成 = 1.2
		"大毒师": 加成 = 1.5
		"毒仙": 加成 = 2.0
		"毒圣": 加成 = 3.0
		_: 加成 = 1.0
	return 加成

## 毒医双修：以毒攻毒治疗（用微量毒药中和毒素，毒道越高效果越好）
func 以毒攻毒治疗(中毒者: Disciple) -> Dictionary:
	if 中毒者 == null:
		return {"成功": false, "原因": "无治疗对象"}
	var 境界: String = 获取毒道境界()
	var 毒体: String = 获取毒体境界()
	# 治疗成功率 = 毒道境界基础 + 毒体加成
	var 成功率: float = 0.3
	match 境界:
		"毒道学徒": 成功率 = 0.3
		"毒师": 成功率 = 0.5
		"大毒师": 成功率 = 0.7
		"毒仙": 成功率 = 0.85
		"毒圣": 成功率 = 0.95
		_: 成功率 = 0.3
	成功率 += float(获取毒体加成()["毒抗"]) * 0.1
	成功率 = min(0.98, 成功率)
	if randf() < 成功率:
		# 治疗成功：清除中毒状态，恢复少量气血，减少受伤天数
		var 治疗天数: int = 0
		if 中毒者.受伤剩余 > 0:
			治疗天数 = min(中毒者.受伤剩余, 3 + int(毒道境界表.find(境界)))
			中毒者.受伤剩余 = max(0, 中毒者.受伤剩余 - 治疗天数)
		添加纪事("毒道", "以毒攻毒", "毒医以毒攻毒，为%s解毒疗伤成功，毒道境界%s，毒体%s，伤势恢复%d日。" % [中毒者.姓名, 境界, 毒体, 治疗天数], 2)
		return {"成功": true, "治疗者境界": 境界, "毒体": 毒体, "治疗天数": 治疗天数}
	else:
		添加纪事("毒道", "治疗失败", "以毒攻毒失败，%s毒素未能清除。" % 中毒者.姓名, 1)
		return {"成功": false, "原因": "治疗失败", "成功率": 成功率}

## 弟子AI用毒判定（按性格/道途决定用毒类型，符合修真世界观）
func 弟子AI用毒判定(弟子: Disciple) -> Dictionary:
	if 弟子 == null:
		return {"可用毒": false, "偏好类型": "无", "原因": "无弟子", "业力代价": 0, "心魔代价": 0}
	var 性格: String = str(弟子.性格)
	var 道途: String = str(弟子.道途)
	var 可用毒: bool = true
	var 偏好类型: String = "任意"  # 任意/麻痹毒/控制毒/迷幻毒/致残毒/杀伤性毒/拒绝用毒
	var 原因: String = ""
	var 业力代价: int = 0  # 杀伤性/致残性毒增加业力
	var 心魔代价: int = 0  # 杀伤性/致残性毒增加心魔
	# 道途判定（正道拒毒，魔道喜毒）
	if 道途.find("正") >= 0 or 道途.find("儒") >= 0 or 道途.find("佛") >= 0:
		可用毒 = false
		偏好类型 = "拒绝用毒"
		原因 = "正道弟子不屑于用毒，有违道心"
	elif 道途.find("魔") >= 0 or 道途.find("邪") >= 0 or 道途.find("鬼") >= 0:
		偏好类型 = "杀伤性毒"
		业力代价 = 5
		心魔代价 = 3
		原因 = "魔道弟子以毒为道，无所不用其极"
	# 性格判定（在道途基础上微调）
	if 可用毒:
		match 性格:
			"谨慎", "开朗", "温和":
				偏好类型 = "麻痹毒"
				原因 = "%s性格%s，只愿用麻痹毒制敌，不愿伤人性命" % [弟子.姓名, 性格]
			"好斗", "孤僻", "冷酷":
				偏好类型 = "杀伤性毒"
				业力代价 = 3
				心魔代价 = 2
				原因 = "%s性格%s，狠辣果决，杀伤性毒最合其意" % [弟子.姓名, 性格]
			"狡诈", "阴险":
				偏好类型 = "致残毒"
				业力代价 = 4
				心魔代价 = 3
				原因 = "%s性格%s，擅用致残毒废人修为，阴狠毒辣" % [弟子.姓名, 性格]
			"聪慧", "机智":
				偏好类型 = "迷幻毒"
				原因 = "%s性格%s，喜用迷幻毒扰敌心智，不战而屈人之兵" % [弟子.姓名, 性格]
			_:
				偏好类型 = "任意"
				原因 = "%s性格%s，两种毒药皆可使用" % [弟子.姓名, 性格]
	# 毒道境界影响（毒道越高，越愿意用毒，且业力代价越低）
	if 弟子.has_method("获取毒道境界"):
		var 毒道境: String = str(弟子.获取毒道境界())
		if 毒道境 in ["毒师", "大毒师", "毒宗", "毒圣"]:
			可用毒 = true
			业力代价 = max(0, 业力代价 - 2)  # 毒道高深者，以毒入道，业力渐消
			if 偏好类型 == "拒绝用毒":
				偏好类型 = "控制毒"
				原因 = "%s虽为正道，但毒道境界已达%s，以毒济世，不违道心" % [弟子.姓名, 毒道境]
	return {"可用毒": 可用毒, "偏好类型": 偏好类型, "原因": 原因, "性格": 性格, "道途": 道途, "业力代价": 业力代价, "心魔代价": 心魔代价}

# ============ 毒丹系统（毒医双修的高阶应用，以毒入药，以毒攻毒） ============
## 毒丹配置（修真界毒医的独门丹药）
const 毒丹配置: Dictionary = {
	# 攻毒丹：增强毒伤，服用后临时提升毒道能力
	"攻毒丹": {"品阶": "灵品", "类型": "攻毒", "效果": "毒伤+50%，持续3场战斗", "材料": "毒草×20+妖兽内丹×1", "毒道经验": 30},
	"剧毒丹": {"品阶": "宝品", "类型": "攻毒", "效果": "毒伤+100%，持续5场战斗", "材料": "毒草×50+毒兽内丹×2", "毒道经验": 80},
	"万毒丹": {"品阶": "王品", "类型": "攻毒", "效果": "毒伤+200%，持续10场战斗", "材料": "万年毒草×1+毒兽内丹×5", "毒道经验": 200},
	# 抗毒丹：增加毒体经验，加速百毒不侵修炼
	"抗毒丹": {"品阶": "灵品", "类型": "抗毒", "效果": "毒体修为+100", "材料": "毒草×15+灵草×10", "毒道经验": 20},
	"辟毒丹": {"品阶": "宝品", "类型": "抗毒", "效果": "毒体修为+300，临时免疫凡品毒", "材料": "毒草×40+灵草×30", "毒道经验": 60},
	"万毒不侵丹": {"品阶": "王品", "类型": "抗毒", "效果": "毒体修为+1000，临时免疫宝品毒", "材料": "万年毒草×1+灵草×100", "毒道经验": 150},
	# 疗伤丹：以毒攻毒，治疗伤势（毒道越高效果越好）
	"毒疗丹": {"品阶": "灵品", "类型": "疗伤", "效果": "以毒攻毒，恢复大量气血，清除负面状态", "材料": "毒草×10+灵草×20", "毒道经验": 25},
	"九转毒疗丹": {"品阶": "宝品", "类型": "疗伤", "效果": "以毒攻毒，起死回生，清除所有负面状态", "材料": "毒草×30+灵草×50+妖兽内丹×1", "毒道经验": 70},
	# 化功丹：消散敌人功力，剧毒无比（战斗中使用）
	"化功丹": {"品阶": "宝品", "类型": "化功", "效果": "敌人道行-30%，持续3回合", "材料": "毒草×50+毒兽内丹×3", "毒道经验": 100},
	"散功毒丹": {"品阶": "王品", "类型": "化功", "效果": "敌人道行-50%，持续5回合", "材料": "万年毒草×1+毒兽内丹×5", "毒道经验": 250},
}

## 获取所有毒丹列表
func 获取毒丹列表() -> Array:
	var 列表: Array = []
	for 毒丹名 in 毒丹配置.keys():
		var cfg = 毒丹配置[毒丹名]
		列表.append({"名称": 毒丹名, "品阶": cfg["品阶"], "类型": cfg["类型"], "效果": cfg["效果"], "材料": cfg["材料"], "毒道经验": cfg["毒道经验"]})
	return 列表

## 炼制毒丹（毒医双修的高阶应用，需要毒道境界达到毒师以上）
func 炼制毒丹(毒丹名: String, 制作者 = null) -> Dictionary:
	if not 毒丹配置.has(毒丹名):
		return {"成功": false, "原因": "未知毒丹：%s" % 毒丹名}
	var cfg = 毒丹配置[毒丹名]
	# 毒道境界要求：至少毒师才能炼制毒丹
	var 境界: String = 获取毒道境界()
	if 境界 == "毒道学徒":
		return {"成功": false, "原因": "毒道境界不足，至少需达到毒师方可炼制毒丹"}
	# 使用宗主毒室等级 + 毒道境界加成
	var 毒室等级: int = 获取宗主场所等级("毒室")
	var 境界加成: Dictionary = 获取毒道境界加成()
	var 成功率: float = 0.3 + float(毒室等级) * 0.05 + float(境界加成["成功率加成"])
	成功率 = min(0.9, 成功率)
	# 消耗精力（宗主制作）
	if 制作者 != null and 制作者 is Disciple:
		if 制作者.精力 < 20:
			return {"成功": false, "原因": "精力不足"}
		制作者.精力 -= 20
	# 炼制
	if randf() < 成功率:
		var 毒丹 = Item.new()
		毒丹.名称 = 毒丹名
		毒丹.类型 = "毒丹"
		毒丹.品阶 = cfg["品阶"]
		毒丹.类别 = "du_dan"
		宗门库房.append(毒丹)
		添加纪事("毒道", "炼制毒丹", "炼制%s（%s/%s）成功，以毒入药，丹成之时毒雾弥漫。" % [毒丹名, cfg["品阶"], cfg["类型"]], 2)
		# 炼制毒丹增加毒道经验和毒体经验
		增加毒道经验(int(cfg["毒道经验"]))
		# 毒丹无业力代价（以毒入药，是医术不是毒术）
		return {"成功": true, "产出": 毒丹名, "品阶": cfg["品阶"], "类型": cfg["类型"]}
	else:
		添加纪事("毒道", "炼制失败", "炼制%s失败，丹药炸炉，毒气四散。" % 毒丹名, 1)
		return {"成功": false, "原因": "炼制失败", "成功率": 成功率}

## 服用毒丹（根据类型产生不同效果）
func 服用毒丹(毒丹名: String, 服用者: Disciple) -> Dictionary:
	if not 毒丹配置.has(毒丹名):
		return {"成功": false, "原因": "未知毒丹"}
	var cfg = 毒丹配置[毒丹名]
	# 从库房消耗毒丹
	var 找到: bool = false
	for i in range(宗门库房.size()):
		var it = 宗门库房[i]
		if it != null and it.名称 == 毒丹名:
			宗门库房.remove_at(i)
			找到 = true
			break
	if not 找到:
		return {"成功": false, "原因": "库房无%s" % 毒丹名}
	# 根据类型产生效果
	var 类型: String = str(cfg["类型"])
	match 类型:
		"抗毒":
			# 抗毒丹：增加毒体经验
			var 经验值: int = 100
			if 毒丹名 == "辟毒丹": 经验值 = 300
			elif 毒丹名 == "万毒不侵丹": 经验值 = 1000
			毒体经验 += 经验值
			_检查毒体突破()
			添加纪事("毒道", "服用抗毒丹", "%s服用%s，毒体修为+%d，身体抗毒性增强。" % [服用者.姓名, 毒丹名, 经验值], 2)
			return {"成功": true, "效果": "毒体修为+%d" % 经验值}
		"疗伤":
			# 疗伤丹：以毒攻毒，恢复气血
			添加纪事("毒道", "以毒攻毒", "%s服用%s，以毒攻毒，伤势痊愈，负面状态清除。" % [服用者.姓名, 毒丹名], 2)
			return {"成功": true, "效果": "恢复气血，清除负面状态"}
		"攻毒":
			# 攻毒丹：临时提升毒伤
			添加纪事("毒道", "服用攻毒丹", "%s服用%s，毒道能力临时提升，毒伤大增。" % [服用者.姓名, 毒丹名], 2)
			return {"成功": true, "效果": "毒伤临时提升"}
		"化功":
			# 化功丹：战斗中使用，消散敌人功力
			添加纪事("毒道", "炼制化功丹", "%s服下%s，此丹剧毒，战斗中可消散敌人功力。" % [服用者.姓名, 毒丹名], 2)
			return {"成功": true, "效果": "战斗中消散敌人功力"}
		_:
			return {"成功": false, "原因": "未知毒丹类型"}

## 获取毒傀儡总毒伤（供战斗系统调用）
func 获取毒傀儡毒伤() -> int:
	var 总毒伤: int = 0
	for 傀儡 in 傀儡系统.傀儡列表:
		if 傀儡.get("类型", "") == "毒傀儡":
			var 等级: int = int(傀儡.get("等级", 1))
			总毒伤 += 等级 * 10  # 每级10点毒伤
	return 总毒伤

## 战斗中毒傀儡施毒（战前自动施放）
func 毒傀儡战前施毒(目标战力: int) -> Dictionary:
	var 毒伤: int = 获取毒傀儡毒伤()
	if 毒伤 <= 0:
		return {"成功": false, "原因": "无毒傀儡"}
	var 战力削弱: int = int(目标战力 * 0.1)  # 毒傀儡降低敌人10%战力
	# 毒傀儡施毒代价：正道声望-2，魔道声望+1（毒傀儡被动施毒，代价较小）
	增加阵营声望("正道宗门", -2)
	增加阵营声望("魔道邪宗", 1)
	添加纪事("毒道", "毒傀儡施毒", "毒傀儡战前施放毒素，敌人道行削弱%d，毒伤%d。" % [战力削弱, 毒伤], 2)
	return {"成功": true, "毒伤": 毒伤, "战力削弱": 战力削弱}

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
		灵兽管理系统.灵兽库存.append(e)
		_记录图录(e.种类名, "御兽")   # WAVE-D #6：孵化即收录妖兽图录（匹配名 = 灵兽种类名）
	if 已孵.size() > 0:
		战报更新.emit(文案表["beast_eggs_hatched"] % [已孵.size()])
# T03 引育计划队列：周期结算遍历启用条目，灵石足够则拨付经：按偏好生成兽卵入孵化列表
func 处理兑换队列():

	for 条目 in 灵兽管理系统.灵兽兑换队列:
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
# ============ 灵兽管理系统（已拆分到beast_management_system.gd，此处为转发函数）============
func 灵兽兑换_新增(偏好: Dictionary, 经费: int) -> String:
	return 灵兽管理系统.灵兽兑换_新增(偏好, 经费)
func 灵兽兑换_启停(序号: int) -> String:
	return 灵兽管理系统.灵兽兑换_启停(序号)
func 灵兽兑换_删除(序号: int) -> String:
	return 灵兽管理系统.灵兽兑换_删除(序号)
func 获取所有灵兽列表() -> Array:
	return 灵兽管理系统.获取所有灵兽列表()
func 获取灵兽统计() -> Dictionary:
	return 灵兽管理系统.获取灵兽统计()
func 一键培养灵兽() -> Dictionary:
	return 灵兽管理系统.一键培养灵兽()
func 获取灵兽技能列表(灵兽类型: String, 灵兽等级: int) -> Array:
	return 灵兽管理系统.获取灵兽技能列表(灵兽类型, 灵兽等级)
func 灵兽进化(灵兽索引: int) -> Dictionary:
	var 结果: Dictionary = 灵兽管理系统.灵兽进化(灵兽索引)
	# 旧实现在本层做过「推演条目 + 成就复检」两个副作用，而 灵兽管理系统 内部只写纪事。
	# 迁移为转发后由本层补齐，否则灵兽进化不再进推演面板、也不再触发相关成就。
	if bool(结果.get("成功", false)):
		var 兽 = 结果.get("灵兽", null)
		var 兽名: String = str(兽.种类名) if 兽 != null else "灵兽"
		_加推演条目("【灵兽进化】%s进化成功，品阶提升至%s！" % [兽名, 结果.get("新品阶显示", "")], ET_SECT, PRIO_HIGH, {})
		_复检成就()
	return 结果
func 获取灵兽进化消耗(灵兽索引: int) -> Dictionary:
	return 灵兽管理系统.获取灵兽进化消耗(灵兽索引)
func 出战灵兽月度养成():
	灵兽管理系统.出战灵兽月度养成()
func 绑定灵兽给首只合体(灵兽: Beast) -> String:
	return 灵兽管理系统.绑定灵兽给首只合体(灵兽)
func 绑定灵兽给指定弟子(灵兽: Beast, 弟子: Disciple, 槽位: String = "主宠") -> String:
	return 灵兽管理系统.绑定灵兽给指定弟子(灵兽, 弟子, 槽位)
func 解绑灵兽(弟子: Disciple, 槽位: String) -> String:
	return 灵兽管理系统.解绑灵兽(弟子, 槽位)

# ============ 天才陨落传承机制（情感缓冲：天才弟子死亡留下传承，减轻玩家损失感）============
## 天才弟子陨落时留下传承（功法心得/修炼资源/本命法宝）
func _天才陨落传承(d: Disciple) -> void:
	if d == null:
		return
	var 传承物品: Array = []
	# 1. 留下功法心得（根据已学功法数量）
	if d.已学功法.size() > 0:
		var 心得数量: int = min(2, d.已学功法.size())
		for i in range(心得数量):
			var 功法ID: String = str(d.已学功法[i])
			# 创建功法心得物品
			var 心得: Dictionary = {
				"名称": "%s的功法心得" % d.姓名,
				"类别": "传承",
				"品阶": "宝品",
				"描述": "%s坐化前留下的功法心得，记载其毕生修炼感悟，研读可增进修为。" % d.姓名,
				"功法ID": 功法ID
			}
			传承物品.append(心得)
	# 2. 留下修炼资源（根据境界）
	var 境界序: int = Disciple.境界序.find(str(d.境界))
	var 灵石数量: int = (境界序 + 1) * 500
	灵石 += 灵石数量
	# 3. 留下悟道点
	var 悟道点数量: int = (境界序 + 1) * 100
	悟道点 += 悟道点数量
	# 4. 加入传承物品到库房
	for it in 传承物品:
		宗门库房.append(it)
	# 5. 推演条目通知
	_加推演条目("【天才陨落】%s冲击大道失败，陨落道消。临终前留下毕生传承：功法心得%d部、灵石%d、悟道点%d，尽数归入宗门，以遗后人。" % [d.姓名, 传承物品.size(), 灵石数量, 悟道点数量], ET_SECT, PRIO_HIGH, {"弟子": d.姓名})
	# 6. 宗门史馆弹窗
	AchievementPopup.show_achievement("天才陨落", "%s 陨落留传承" % str(d.姓名), "%s坐化前留下毕生传承，功法心得与修炼资源尽数归入宗门，永受后人瞻仰。" % str(d.姓名), Color(0.8, 0.6, 0.2))

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
			if not 灵兽管理系统.灵兽库存.has(兽):
				灵兽管理系统.灵兽库存.append(兽)
		if d.副宠灵兽 != null:
			var 兽: Beast = d.副宠灵兽
			d.副宠灵兽 = null
			兽.取消出战()
			if not 灵兽管理系统.灵兽库存.has(兽):
				灵兽管理系统.灵兽库存.append(兽)
		# 装备/背包归还宗门库房
		for it in d.装备.values():
			宗门库房.append(it)
		d.装备.clear()
		for it in d.背包:
			宗门库房.append(it)
		d.背包.clear()
		# §4.0 弟子自主层：清理遗物时起获暗藏私货 —— 随坐化归还宗门（避免物品随人永久蒸发）
		if d.私库.size() > 0:
			var 私藏数: int = d.私库.size()
			for it in d.私库:
				宗门库房.append(it)
			d.私库.clear()
			添加纪事("私藏", "遗物起获", "清理%s遗物时，于其储物法宝中起获私藏 %d 件，尽数归入宗门库房" % [str(d.姓名), 私藏数], 1)
		# 先贤祠入册（坐化弟子静态档案：复制字段，不持有 Disciple 引用，防悬空；EC-2/EC-4：
		先贤堂.append({
			"弟子ID": d.弟子ID, "姓名": d.姓名, "境界": d.境界,
			"坐化日": 累计游戏日, "事迹摘要": _坐化纪事文案(d)
		})
		# S55：宗门史馆入册弹窗
		AchievementPopup.show_achievement("宗门史馆", "%s 入册先贤堂" % str(d.姓名), "%s 坐化，事迹载入宗门史册，永受后人瞻仰。" % str(d.姓名), Color(0.6, 0.4, 0.2))
		# 纪事入册（按身份分档： 先贤缅怀分类（R1：填充「先贤缅怀」Tab：
		宗门纪事.append({"日期": 累计游戏日, "弟子": d.姓名, "弟子ID": d.弟子ID, "名称": "坐化", "文案": _坐化纪事文案(d), "category": "先贤缅怀"})
		_加推演条目("%s】寿元耗尽，坐化于山门" % [d.姓名], ET_SECT, PRIO_NORMAL, {"弟子": d.姓名})
		if d.身份 == "长老":
			_传承事件("首位长老飞升")   # WAVE-D #8：长老坐：：先贤事迹图录 + 事件型里程碑
		_复检里程碑()                      # WAVE-D #8：弟：长老状态变化复检
		_复检成就()                              # S1 ：：弟：长老变化后按境：灵根/掌门境界补达成成：
		_断链_师父离场(d.弟子ID)   # S29：师父坐化/陨落 → 徒弟弟子失师
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
# ============ 弟子自主层：所得归属（私藏 / 查抄）============

## §4.0 弟子自主层：弟子按 目标/性格/心境 自主决定所得是上报宗门还是瞒报私藏。
##   私藏不产生纪事、不入待抉择队列——玩家只见「私藏件数」，不知具体品名，须「查抄」方可揭晓。
##   容量是硬闸门：储物法宝藏满了就藏不住，只能老实上报。
func _弟子是否私藏(d: Disciple, it: Item) -> bool:
	if d == null or it == null:
		return false
	if str(d.状态) != "在宗":
		return false
	if d.私库.size() >= d.私库容量上限():
		return false   # 储物法宝已满，藏不下 → 只能上报
	return randf() < Goal.弟子私藏率(d)


## 私藏入库：从背包（获得物品已先入背包）移入私库，玩家视角就此「消失」
func _弟子私藏入库(d: Disciple, it: Item) -> void:
	if d == null or it == null:
		return
	if d.背包.has(it):
		d.背包.erase(it)
	d.私库.append(it)
	d.私藏次数 += 1


## 查抄：没收弟子私库全部私藏——撕破脸的代价（心境 -30 + 积怨推高叛离，数月方平）
##   设计取「重罚」：查抄不是常规的资源回收手段，是要掂量人才损失的决定。
##   积怨 +4 且每月 -1（见 _检查叛离）→ 约 3 个月高危期：当月 ×2.8、次月 ×2.2、再次 ×1.6
func 查抄弟子(d: Disciple) -> Dictionary:
	if d == null:
		return {"成功": false, "原因": "查无此人"}
	if str(d.状态) != "在宗":
		return {"成功": false, "原因": "%s 已不在宗门，无从查抄" % str(d.姓名)}
	if d.私库.is_empty():
		return {"成功": false, "原因": "%s 的储物法宝中空无一物，查无所获" % str(d.姓名)}
	var 没收数: int = 0
	var 品名: Array = []
	for it in d.私库:
		if it == null:
			continue
		品名.append(str(it.名称))
		宗门库房.append(it)
		没收数 += 1
	d.私库.clear()
	var 旧心境: int = int(d.心境)
	d.心境 = max(0, 旧心境 - 30)
	d.查抄积怨 += 4
	添加纪事("私藏", "查抄私库", "%s 私藏 %d 件之物被宗主查抄没收（%s），其心大恸，心境 %d → %d" % [str(d.姓名), 没收数, "、".join(品名), 旧心境, int(d.心境)], 2)
	弟子变动.emit()
	return {"成功": true, "没收": 没收数, "物品": 品名, "心境": int(d.心境)}

# ============ S27 宗门任务榜：发布 / 接取 / 请命 ============

## 玩家挂榜。报酬品阶留空=按模板标准档；可压档（省钱但冷清）或加档（热门但割肉）。
func 发布宗门任务(模板ID: String, 报酬品阶: String = "") -> Dictionary:
	var 模板: Dictionary = SectBounty.取模板(模板ID)
	if 模板.is_empty():
		return {"成功": false, "原因": "无此任务模板"}
	var 实给: String = 报酬品阶 if 报酬品阶 != "" else SectBounty.标准报酬品阶(模板)
	宗门任务计数器 += 1
	var tid: String = "sb_%d" % 宗门任务计数器
	宗门任务榜[tid] = {
		"任务ID": tid,
		"模板ID": 模板ID,
		"任务名": str(模板.get("bounty_name", "")),
		"类型": str(模板.get("bounty_type", "collect")),
		"难度": SectBounty.难度(模板),
		"报酬品阶": 实给,
		"要求数量": SectBounty.要求数量(模板),
		"接取弟子ID": -1,
		"发布日": int(累计游戏日),
		"状态": "招募中",
	}
	添加纪事("任务", "宗门挂榜", "宗门挂出【%s】（%s·难度%d），酬以%s之物，静待弟子接取" % [
		str(模板.get("bounty_name", "")), SectBounty.类型名(str(模板.get("bounty_type", ""))),
		SectBounty.难度(模板), 实给], 1)
	return {"成功": true, "任务ID": tid}


## 撤销尚未被接取的任务（已被接取则不可撤，避免弟子白跑）
func 撤销宗门任务(任务ID: String) -> Dictionary:
	if not 宗门任务榜.has(任务ID):
		return {"成功": false, "原因": "任务不存在"}
	var 任务: Dictionary = 宗门任务榜[任务ID]
	if str(任务.get("状态", "")) != "招募中":
		return {"成功": false, "原因": "已被接取，不可撤销"}
	宗门任务榜.erase(任务ID)
	return {"成功": true}


## 月度挂点：弟子自主接取；榜上无合意任务则据主目标主动请命
func _弟子任务榜月度(d: Disciple) -> void:
	if d == null:
		return
	# 已有任务在身则不再接取
	for iid in 宗门任务进行中:
		var 实: Dictionary = 宗门任务进行中[iid]
		if int(实.get("弟子ID", -1)) == int(d.弟子ID):
			return
	if 宗门任务榜.is_empty():
		return
	# 1. 自主接取：取所有招募中任务里意愿最高者
	var 最佳ID: String = ""
	var 最佳分: float = 0.0
	for tid in 宗门任务榜:
		var 任务: Dictionary = 宗门任务榜[tid]
		if str(任务.get("状态", "")) != "招募中":
			continue
		var 模板: Dictionary = SectBounty.取模板(str(任务.get("模板ID", "")))
		if 模板.is_empty():
			continue
		var 分: float = SectBounty.接取意愿(d, 模板, str(任务.get("报酬品阶", "")))
		if 分 > 最佳分:
			最佳分 = 分
			最佳ID = tid
	if 最佳ID != "" and 最佳分 >= SectBounty.接取意愿阈值 and randf() < 最佳分:
		_接取宗门任务(最佳ID, d)
		return
	# 2. 榜上无合意任务 → 主动请命（8%/月，避免刷屏）
	if randf() < 0.08:
		_生成请命(d)


## 弟子接取任务（内部）：从榜单移入进行中
func _接取宗门任务(任务ID: String, d: Disciple) -> void:
	var 任务: Dictionary = 宗门任务榜.get(任务ID, {})
	if 任务.is_empty() or d == null:
		return
	var 模板: Dictionary = SectBounty.取模板(str(任务.get("模板ID", "")))
	if 模板.is_empty():
		return
	任务["接取弟子ID"] = int(d.弟子ID)
	任务["状态"] = "执行中"
	宗门任务计数器 += 1
	var iid: String = "sbrun_%d" % 宗门任务计数器
	宗门任务进行中[iid] = {
		"实例ID": iid,
		"任务ID": 任务ID,
		"弟子ID": int(d.弟子ID),
		"模板ID": str(任务.get("模板ID", "")),
		"报酬品阶": str(任务.get("报酬品阶", "")),
		"开始游戏日": int(累计游戏日),
		"预计结束游戏日": int(累计游戏日) + SectBounty.耗时(模板),
	}
	宗门任务榜.erase(任务ID)
	添加纪事("任务", "弟子接取", "【%s】主动接下【%s】，约 %d 日可归" % [
		str(d.姓名), str(任务.get("任务名", "")), SectBounty.耗时(模板)], 1)


## 据主目标生成请命（内部）
func _生成请命(d: Disciple) -> void:
	if d == null:
		return
	# 同一弟子不重复请命
	for q in 弟子请命列表:
		if int(q.get("弟子ID", -1)) == int(d.弟子ID):
			return
	# 上限 10 条，避免刷屏
	if 弟子请命列表.size() >= 10:
		return
	var 建议: Dictionary = SectBounty.请命建议(d)
	if 建议.is_empty():
		return
	建议["弟子ID"] = int(d.弟子ID)
	建议["弟子名"] = str(d.姓名)
	建议["发布日"] = int(累计游戏日)
	弟子请命列表.append(建议)


## 批准请命：立即发榜并接取（弟子已在候命，不再掷骰）
func 批准请命(索引: int) -> Dictionary:
	if 索引 < 0 or 索引 >= 弟子请命列表.size():
		return {"成功": false, "原因": "请命不存在"}
	var q: Dictionary = 弟子请命列表[索引]
	var d: Object = _取弟子(int(q.get("弟子ID", -1)))
	if d == null:
		弟子请命列表.remove_at(索引)
		return {"成功": false, "原因": "弟子已不在宗"}
	for iid in 宗门任务进行中:
		var 实: Dictionary = 宗门任务进行中[iid]
		if int(实.get("弟子ID", -1)) == int(d.弟子ID):
			弟子请命列表.remove_at(索引)
			return {"成功": false, "原因": "%s 已有差事在身" % str(d.姓名)}
	var 发榜: Dictionary = 发布宗门任务(str(q.get("模板ID", "")))
	if not bool(发榜.get("成功", false)):
		弟子请命列表.remove_at(索引)
		return 发榜
	_接取宗门任务(str(发榜.get("任务ID", "")), d)
	弟子请命列表.remove_at(索引)
	添加纪事("任务", "准其所请", "宗主准【%s】所请，遣其往办【%s】" % [
		str(d.姓名), str(q.get("任务名", ""))], 1)
	return {"成功": true}


## 驳回请命：其志难伸，心境 -3
func 驳回请命(索引: int) -> Dictionary:
	if 索引 < 0 or 索引 >= 弟子请命列表.size():
		return {"成功": false, "原因": "请命不存在"}
	var q: Dictionary = 弟子请命列表[索引]
	var d: Object = _取弟子(int(q.get("弟子ID", -1)))
	弟子请命列表.remove_at(索引)
	if d != null:
		d.心境 = max(0, int(d.心境) - 3)
		添加纪事("任务", "驳其所请", "宗主驳【%s】所请，其志难伸，心境 -3" % str(d.姓名), 1)
	return {"成功": true}


# ============ S27 宗门任务榜：结算 ============

## 到期任务结算（月度推演调用，与商队共用挂点）
func _结算到期宗门任务() -> void:
	if 宗门任务进行中.is_empty():
		return
	var 今日: int = int(累计游戏日)
	var 到期: Array = []
	for iid in 宗门任务进行中:
		var 实: Dictionary = 宗门任务进行中[iid]
		if int(实.get("预计结束游戏日", 0)) <= 今日:
			到期.append(iid)
	for iid in 到期:
		_结算单个宗门任务(str(iid))


func _结算单个宗门任务(实例ID: String) -> void:
	var 实: Dictionary = 宗门任务进行中.get(实例ID, {})
	if 实.is_empty():
		return
	宗门任务进行中.erase(实例ID)
	var 模板: Dictionary = SectBounty.取模板(str(实.get("模板ID", "")))
	if 模板.is_empty():
		return
	var d: Object = _取弟子(int(实.get("弟子ID", -1)))
	if d == null:
		return
	# 弟子已非在宗（陨落/叛出/失踪）则任务作废
	if str(d.状态) != "在宗":
		return
	var 类型: String = str(模板.get("bounty_type", "collect"))
	var 难度: int = SectBounty.难度(模板)
	var 报酬品阶: String = str(实.get("报酬品阶", ""))
	if 类型 == "collect":
		_结算征缴(d, 模板, 报酬品阶)
	else:
		_结算清剿或寻访(d, 模板, 报酬品阶, 类型, 难度)


## 征缴结算：先扣背包（弟子保住私藏的第一选择），不足则动私库——私藏由此暴露
func _结算征缴(d: Object, 模板: Dictionary, 报酬品阶: String) -> void:
	var 需: int = SectBounty.要求数量(模板)
	var 已交: Array = []
	已交.append_array(_从容器扣物(d.背包, 需))
	var 动私库: int = 0
	if 已交.size() < 需:
		var 缺: int = 需 - 已交.size()
		var 自私库: Array = _从容器扣物(d.私库, 缺)
		动私库 = 自私库.size()
		已交.append_array(自私库)
	if 已交.size() < 需:
		添加纪事("任务", "征缴未足", "【%s】筹措不足，仅得 %d/%d，征缴之命未能达成" % [
			str(d.姓名), 已交.size(), 需], 1)
		return
	for it in 已交:
		宗门库房.append(it)
	var 报酬: Object = _拨付任务报酬(d, 报酬品阶)
	if 动私库 > 0:
		添加纪事("任务", "私藏外露", "【%s】为完征缴之命，不得已取出私藏 %d 件充数——其所匿之物，宗门已尽知" % [
			str(d.姓名), 动私库], 2)
	添加纪事("任务", "征缴完成", "【%s】缴物 %d 件入库，宗门酬以 %s" % [
		str(d.姓名), 已交.size(), (str(报酬.名称) if 报酬 != null else "无物可酬")], 1)


## 清剿 / 寻访结算：按战力比定成败，难度≥4 另赐保命护身
func _结算清剿或寻访(d: Object, 模板: Dictionary, 报酬品阶: String, 类型: String, 难度: int) -> void:
	var 战力: int = int(d.战力)
	var 需战力: int = SectBounty.要求战力(模板)
	var 率: float = clamp(float(战力) / float(max(需战力, 1)) * 0.70, 0.15, 0.95)
	if randf() >= 率:
		var 伤: int = 难度 * 2
		d.受伤剩余 = max(int(d.受伤剩余), 伤)
		添加纪事("任务", "任务失利", "【%s】往办【%s】失利，负伤而归（养伤 %d 日）" % [
			str(d.姓名), str(模板.get("bounty_name", "")), 伤], 2)
		return
	var 报酬: Object = _拨付任务报酬(d, 报酬品阶)
	var 额外: String = ""
	if 难度 >= 4:
		d.保命护身 += 1
		额外 = "，另赐保命护身一枚"
	添加纪事("任务", "%s完成" % SectBounty.类型名(类型), "【%s】办妥【%s】，宗门酬以 %s%s" % [
		str(d.姓名), str(模板.get("bounty_name", "")),
		(str(报酬.名称) if 报酬 != null else "无物可酬"), 额外], 2)


## 从容器（背包/私库）按品阶从低到高扣 N 件，返回被扣物品（原容器原地修改）
func _从容器扣物(容器: Array, 数量: int) -> Array:
	var 出: Array = []
	if 数量 <= 0 or 容器 == null:
		return 出
	var 序: Array = Item.品阶序
	for _n in range(数量):
		var 最低: Object = null
		var 最低档: int = 999
		for it in 容器:
			if it == null or not (it is Item):
				continue
			var 档: int = 序.find(str(it.品阶))
			if 档 < 0:
				档 = 0
			if 档 < 最低档:
				最低档 = 档
				最低 = it
		if 最低 == null:
			break
		容器.erase(最低)
		出.append(最低)
	return 出


# ============ S28 宗门悬赏榜：发布 / 接单 / 结算 ============

## 悬赏目标物类别（修真世界观常见材料）
const 悬赏目标类别: Array = ["灵草", "矿石", "妖兽材料", "丹药", "符箓", "功法", "法宝", "灵兽", "特殊物品"]

## 计算悬赏评级（S/A/B/C，基于需求价值和奖励价值）
func _计算悬赏评级(需求数量: int, 奖励数量: int, 奖励类型: String) -> String:
	# 奖励价值换算（灵石为基准）
	var 奖励价值: float = float(奖励数量)
	if 奖励类型 == "贡献点":
		奖励价值 = float(奖励数量) * 10.0  # 1贡献点=10灵石
	# 综合价值 = 需求数量 × 奖励价值 / 100（归一化）
	var 综合价值: float = float(需求数量) * 奖励价值 / 100.0
	if 综合价值 >= 500:
		return "S"
	elif 综合价值 >= 100:
		return "A"
	elif 综合价值 >= 20:
		return "B"
	else:
		return "C"

## 发布悬赏（玩家自由指定目标物和奖励）
## 参数：目标物类别、目标物名称、需求数量、奖励类型（灵石/贡献点/物品）、奖励数量、有效期（游戏日）、奖励物品名称（物品类型时必填）
func 发布悬赏(目标物类别: String, 目标物名称: String, 需求数量: int, 奖励类型: String = "灵石", 奖励数量: int = 100, 有效期: int = 30, 奖励物品名称: String = "") -> Dictionary:
	if 目标物类别 == "" or 目标物名称 == "":
		return {"成功": false, "原因": "目标物不能为空"}
	if 需求数量 <= 0:
		return {"成功": false, "原因": "需求数量必须大于0"}
	if 奖励数量 <= 0:
		return {"成功": false, "原因": "奖励数量必须大于0"}
	# 检查宗门是否有足够奖励（灵石类型）
	if 奖励类型 == "灵石" and 灵石 < 奖励数量:
		return {"成功": false, "原因": "宗门灵石不足，无法发布悬赏"}
	# 物品奖励：检查库房是否有该物品
	if 奖励类型 == "物品":
		if 奖励物品名称 == "":
			return {"成功": false, "原因": "物品奖励需指定物品名称"}
		var 找到: bool = false
		for it in 宗门库房:
			if it != null and it is Item and str(it.名称) == 奖励物品名称:
				找到 = true
				break
		if not 找到:
			return {"成功": false, "原因": "宗门库房中没有【%s】" % 奖励物品名称}
	# 扣除奖励（先暂扣，完成后发给弟子，过期退还）
	if 奖励类型 == "灵石":
		灵石 -= 奖励数量
	elif 奖励类型 == "物品":
		# 从库房移除物品暂扣
		for i in range(宗门库房.size()):
			var it = 宗门库房[i]
			if it != null and it is Item and str(it.名称) == 奖励物品名称:
				宗门库房.remove_at(i)
				break
	宗门悬赏计数器 += 1
	var 悬赏ID: String = "bounty_%d" % 宗门悬赏计数器
	# 计算悬赏评级（S/A/B/C，基于需求价值和奖励价值）
	var 评级: String = _计算悬赏评级(需求数量, 奖励数量, 奖励类型)
	宗门悬赏榜[悬赏ID] = {
		"悬赏ID": 悬赏ID,
		"目标物类别": 目标物类别,
		"目标物名称": 目标物名称,
		"需求数量": 需求数量,
		"已收集": 0,
		"奖励类型": 奖励类型,
		"奖励数量": 奖励数量,
		"奖励物品名称": 奖励物品名称,
		"评级": 评级,
		"接取弟子ID": -1,
		"发布日": int(累计游戏日),
		"有效期": 有效期,
		"状态": "招募中",
	}
	添加纪事("悬赏", "发布悬赏", "宗门发布悬赏：求购%s×%d，酬%s×%d，有效期%d日。" % [目标物名称, 需求数量, 奖励类型, 奖励数量, 有效期], 1)
	return {"成功": true, "悬赏ID": 悬赏ID}

## 撤销悬赏（未被接取时可撤销，退还奖励）
func 撤销悬赏(悬赏ID: String) -> Dictionary:
	if not 宗门悬赏榜.has(悬赏ID):
		return {"成功": false, "原因": "悬赏不存在"}
	var 悬赏: Dictionary = 宗门悬赏榜[悬赏ID]
	if str(悬赏.get("状态", "")) != "招募中":
		return {"成功": false, "原因": "悬赏已被接取，不可撤销"}
	# 退还奖励
	if str(悬赏.get("奖励类型", "")) == "灵石":
		灵石 += int(悬赏.get("奖励数量", 0))
	宗门悬赏榜.erase(悬赏ID)
	添加纪事("悬赏", "撤销悬赏", "撤销悬赏【%s】，奖励已退还。" % str(悬赏.get("目标物名称", "")), 1)
	return {"成功": true}

## 月度挂点：弟子自主接取悬赏
func _弟子悬赏月度(d: Disciple) -> void:
	if d == null:
		return
	# 已有悬赏在身则不再接取
	for bid in 宗门悬赏榜:
		var 悬赏: Dictionary = 宗门悬赏榜[bid]
		if int(悬赏.get("接取弟子ID", -1)) == int(d.弟子ID):
			return
	if 宗门悬赏榜.is_empty():
		return
	# 找意愿最高的悬赏
	var 最佳ID: String = ""
	var 最佳分: float = 0.0
	for bid in 宗门悬赏榜:
		var 悬赏: Dictionary = 宗门悬赏榜[bid]
		if str(悬赏.get("状态", "")) != "招募中":
			continue
		# 意愿计算：奖励越高越愿意，难度越高越谨慎
		var 奖励: float = float(悬赏.get("奖励数量", 0))
		var 需求: float = float(悬赏.get("需求数量", 1))
		var 意愿: float = clamp(奖励 / (需求 * 50.0), 0.1, 0.9)
		# 评级加成：S级悬赏弟子更愿意接（高回报高声望）
		var 评级: String = str(悬赏.get("评级", "C"))
		var 评级加成: float = 1.0
		match 评级:
			"S": 评级加成 = 1.5
			"A": 评级加成 = 1.3
			"B": 评级加成 = 1.1
			"C": 评级加成 = 1.0
		意愿 *= 评级加成
		# 弟子目标修正：求财者更愿意
		var 目标: String = Goal.弟子目标(d)
		if 目标 == "积累财富" or 目标 == "证道飞升":
			意愿 *= 1.3
		if 目标 == "清静无为" or 目标 == "逍遥世间":
			意愿 *= 0.6
		# 战力修正：战力高者更敢接
		var 战力比: float = float(d.战力) / 1000.0
		意愿 *= clamp(0.5 + 战力比 * 0.3, 0.5, 1.5)
		if 意愿 > 最佳分:
			最佳分 = 意愿
			最佳ID = bid
	if 最佳ID != "" and randf() < 最佳分:
		_接取悬赏(最佳ID, d)

## 弟子接取悬赏（内部）
func _接取悬赏(悬赏ID: String, d: Disciple) -> void:
	var 悬赏: Dictionary = 宗门悬赏榜.get(悬赏ID, {})
	if 悬赏.is_empty() or d == null:
		return
	悬赏["接取弟子ID"] = int(d.弟子ID)
	悬赏["状态"] = "进行中"
	添加纪事("悬赏", "接取悬赏", "%s接取悬赏【%s×%d】，承诺%d日内完成。" % [d.姓名, str(悬赏.get("目标物名称", "")), int(悬赏.get("需求数量", 0)), int(悬赏.get("有效期", 30))], 1)

## 月度结算：检查悬赏完成/过期
func _结算到期悬赏() -> void:
	if 宗门悬赏榜.is_empty():
		return
	var 今日: int = int(累计游戏日)
	var 到期: Array = []
	for bid in 宗门悬赏榜:
		var 悬赏: Dictionary = 宗门悬赏榜[bid]
		var 发布日: int = int(悬赏.get("发布日", 0))
		var 有效期: int = int(悬赏.get("有效期", 30))
		if 今日 >= 发布日 + 有效期:
			到期.append(bid)
	for bid in 到期:
		_结算单个悬赏(bid)

## 结算单个悬赏（完成/过期）
func _结算单个悬赏(悬赏ID: String) -> void:
	var 悬赏: Dictionary = 宗门悬赏榜.get(悬赏ID, {})
	if 悬赏.is_empty():
		return
	var 已收集: int = int(悬赏.get("已收集", 0))
	var 需求: int = int(悬赏.get("需求数量", 0))
	var 弟子ID: int = int(悬赏.get("接取弟子ID", -1))
	var d: Object = _取弟子(弟子ID) if 弟子ID >= 0 else null
	if 已收集 >= 需求 and d != null:
		# 完成：发放奖励
		var 奖励类型: String = str(悬赏.get("奖励类型", ""))
		var 奖励数量: int = int(悬赏.get("奖励数量", 0))
		var 评级: String = str(悬赏.get("评级", "C"))
		if 奖励类型 == "灵石":
			# 奖励已暂扣，直接发给弟子
			d.私库灵石 += 奖励数量
		elif 奖励类型 == "贡献点":
			d.贡献点 += 奖励数量
		elif 奖励类型 == "物品":
			# 物品奖励：创建物品实例发给弟子
			var 物品名: String = str(悬赏.get("奖励物品名称", ""))
			if 物品名 != "":
				var 奖励物: Item = Item.new()
				奖励物.名称 = 物品名
				奖励物.品阶 = "宝阶"
				奖励物.类型 = "奖励物品"
				d.获得物品(奖励物)
		# 评级额外奖励：S/A级悬赏完成后额外加声望
		var 额外声望: int = 0
		match 评级:
			"S": 额外声望 = 10
			"A": 额外声望 = 5
			"B": 额外声望 = 2
		if 额外声望 > 0:
			声望 += 额外声望
		添加纪事("悬赏", "悬赏完成", "%s完成%s级悬赏【%s×%d】，获得%s×%d，宗门声望+%d！" % [str(d.姓名), 评级, str(悬赏.get("目标物名称", "")), 需求, 奖励类型, 奖励数量, 额外声望], 2)
	else:
		# 未完成/过期：退还奖励给宗门
		if str(悬赏.get("奖励类型", "")) == "灵石":
			灵石 += int(悬赏.get("奖励数量", 0))
		elif str(悬赏.get("奖励类型", "")) == "物品":
			# 物品奖励退还库房
			var 物品名: String = str(悬赏.get("奖励物品名称", ""))
			if 物品名 != "":
				var 退还物: Item = Item.new()
				退还物.名称 = 物品名
				退还物.品阶 = "宝阶"
				退还物.类型 = "奖励物品"
				宗门库房.append(退还物)
		if d != null:
			添加纪事("悬赏", "悬赏过期", "%s未能在期限内完成悬赏【%s】，悬赏作废。" % [str(d.姓名), str(悬赏.get("目标物名称", ""))], 2)
		else:
			添加纪事("悬赏", "悬赏过期", "悬赏【%s】无人接取，已过期作废，奖励退还。" % str(悬赏.get("目标物名称", "")), 1)
	宗门悬赏榜.erase(悬赏ID)

## 弟子上交悬赏物品（历练回来后调用）
func 上交悬赏物品(弟子ID: int, 物品名称: String, 数量: int) -> Dictionary:
	var d: Object = _取弟子(弟子ID)
	if d == null:
		return {"成功": false, "原因": "弟子不存在"}
	# 查找该弟子接取的悬赏
	for bid in 宗门悬赏榜:
		var 悬赏: Dictionary = 宗门悬赏榜[bid]
		if int(悬赏.get("接取弟子ID", -1)) != 弟子ID:
			continue
		if str(悬赏.get("目标物名称", "")) != 物品名称:
			continue
		var 需求: int = int(悬赏.get("需求数量", 0))
		var 已收集: int = int(悬赏.get("已收集", 0))
		var 实际上交: int = min(数量, 需求 - 已收集)
		悬赏["已收集"] = 已收集 + 实际上交
		# 物品入宗门库房
		for i in range(实际上交):
			var it: Item = Item.new()
			it.名称 = 物品名称
			it.品阶 = "凡阶"
			it.类型 = str(悬赏.get("目标物类别", "材料"))
			宗门库房.append(it)
		if 悬赏["已收集"] >= 需求:
			# 立即结算
			_结算单个悬赏(bid)
		return {"成功": true, "上交": 实际上交, "进度": "%d/%d" % [int(悬赏["已收集"]), 需求]}
	return {"成功": false, "原因": "未找到匹配的悬赏"}

## 从宗门库房拨一件该品阶之物进弟子背包（优先挑战力加成最低者，宗门不拿重宝当常酬）
## 库房混有 Item 与 Dictionary（存档按类型分流），故必须 is Item 防御
func _拨付任务报酬(d: Object, 报酬品阶: String) -> Object:
	if d == null or 报酬品阶 == "":
		return null
	var 候选: Array = []
	for it in 宗门库房:
		if it == null or not (it is Item):
			continue
		if str(it.品阶) == 报酬品阶:
			候选.append(it)
	if 候选.is_empty():
		return null
	var 最优: Object = 候选[0]
	for it in 候选:
		if int(it.战力加成) < int(最优.战力加成):
			最优 = it
	宗门库房.erase(最优)
	d.背包.append(最优)
	return 最优


## UI 读取：进行中的任务（含进度，供展示）
func 取宗门任务进行中() -> Array:
	var 出: Array = []
	for iid in 宗门任务进行中:
		var 实: Dictionary = 宗门任务进行中[iid]
		var 模板: Dictionary = SectBounty.取模板(str(实.get("模板ID", "")))
		var d: Object = _取弟子(int(实.get("弟子ID", -1)))
		var 总: int = max(SectBounty.耗时(模板), 1)
		var 已过: int = int(累计游戏日) - int(实.get("开始游戏日", 0))
		出.append({
			"实例ID": str(iid),
			"任务名": str(模板.get("bounty_name", "")),
			"类型": SectBounty.类型名(str(模板.get("bounty_type", ""))),
			"难度": SectBounty.难度(模板),
			"弟子名": (str(d.姓名) if d != null else "—"),
			"进度": clamp(float(已过) / float(总), 0.0, 1.0),
			"剩余日": max(int(实.get("预计结束游戏日", 0)) - int(累计游戏日), 0),
			"报酬品阶": str(实.get("报酬品阶", "")),
		})
	return 出


# ============ 交宗 / 自留 ============
func 交宗(条目: Dictionary):

	var 弟子: Disciple = 条目["弟子"]
	var 物品: Item = 条目["物品"]
	var 贡献: int = {"凡阶": 10, "灵阶": 20, "宝阶": 40, "王阶": 80, "圣阶": 150, "仙阶": 300, "道阶": 600}.get(物品.品阶, 10)
	# S28：交宗不再是白送——个人功勋账户记七成，公中（宗门池）留三成（公中至少 1）
	# 旧行为：贡献点全进宗门池，弟子本人得 0，而「自留」零惩罚 → 交宗是严格劣势选项
	var 入账: int = int(round(float(贡献) * ContributionShop.交宗个人占比))
	var 公中: int = max(1, 贡献 - 入账)
	var 已交: bool = false
	if 弟子.背包.has(物品):
		弟子.背包.erase(物品)
		已交 = true
	elif 弟子.装备.has(物品.穿戴位) and 弟子.装备[物品.穿戴位] == 物品:
		弟子.装备.erase(物品.穿戴位)
		已交 = true
	if 已交:
		弟子.贡献账户 += 入账
		贡献点 += 公中
		# 旧行为：交宗之物凭空消失，库房收不到货 → 功勋堂无货可兑
		宗门库房.append(物品)
	移除待抉择条目(条目)
	弟子变动.emit()
	if 已交:
		战报更新.emit("%s】将%s】交予宗门，功勋入账 +%d（公中 +%d）" % [弟子.姓名, 物品.名称, 入账, 公中])
	else:
		战报更新.emit("%s】欲将%s】交予宗门，然遍寻不见此物" % [弟子.姓名, 物品.名称])
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
# ============ S28 宗门功勋堂：个人贡献账户 / 交宗返还 / 兑换出口 ============
# 闭环：历练所得 → 交宗（七成入个人账户、三成入公中、实物入库房）
#       → 功勋堂按类别×品阶定价兑换（弟子月度自主 + 玩家代兑）
# 修的是「交宗 = 严格劣势选项」这个根本逻辑洞：弟子交出宝物本人颗粒无收，自留却零惩罚。

## 弟子以个人功勋兑换宗门库藏中的一件物品（价格见 config/contribution_shop.csv）
func 弟子兑换(弟子ID: int, 物) -> Dictionary:
	var 目标 = _取弟子(弟子ID)
	if 目标 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if 目标.状态 != "在宗":
		return {"成功": false, "原因": "%s 不在宗中，不可兑换" % 目标.姓名}
	if not (物 is Item):
		return {"成功": false, "原因": "非库藏物品"}
	var 价: int = ContributionShop.兑换价(物.类别, 物.品阶)
	if 价 <= 0:
		return {"成功": false, "原因": "%s 无定价，不可兑换" % 物.名称}
	if 目标.贡献账户 < 价:
		return {"成功": false, "原因": "个人功勋不足（现有%d，需%d）" % [目标.贡献账户, 价]}
	if not 宗门库房.has(物):
		return {"成功": false, "原因": "库藏中已无此物"}
	目标.贡献账户 -= 价
	宗门库房.erase(物)
	目标.获得物品(物)
	添加纪事("功勋", "库藏兑换", "%s 以 %d 功勋自库藏兑下 %s" % [目标.姓名, 价, 物.名称], 1)
	弟子变动.emit()
	return {"成功": true, "弟子": 目标.姓名, "物品": 物.名称, "消耗功勋": 价, "余功勋": 目标.贡献账户}

## 弟子以个人功勋兑换保命护身（一条命，非库藏物品，价 5000）
func 弟子兑换保命(弟子ID: int, 数量: int = 1) -> Dictionary:
	var 目标 = _取弟子(弟子ID)
	if 目标 == null:
		return {"成功": false, "原因": "弟子不存在"}
	if 目标.状态 == "陨落":
		return {"成功": false, "原因": "%s 已陨落，无需保命道具" % 目标.姓名}
	var 价: int = ContributionShop.保命价() * 数量
	if 价 <= 0 or 数量 <= 0:
		return {"成功": false, "原因": "兑换数量有误"}
	if 目标.贡献账户 < 价:
		return {"成功": false, "原因": "个人功勋不足（现有%d，需%d）" % [目标.贡献账户, 价]}
	目标.贡献账户 -= 价
	目标.保命护身 += 数量
	添加纪事("功勋", "兑换保命", "%s 以个人功勋%d兑下保命护身%d枚" % [目标.姓名, 价, 数量], 1)
	弟子变动.emit()
	return {"成功": true, "弟子": 目标.姓名, "发放": 数量, "消耗功勋": 价, "当前保命护身": 目标.保命护身, "余功勋": 目标.贡献账户}

## 月度：弟子自主消费个人功勋（每月至多兑一件，且留得住余额、不掏空库藏）
func _弟子兑换月度(d: Disciple) -> void:
	if d == null or d.状态 != "在宗":
		return
	var 候选: Array = ContributionShop.自主候选(d, 宗门库房)
	if 候选.is_empty():
		return
	var 条目: Dictionary = 候选[0]
	if randf() >= ContributionShop.兑换意愿(d, 条目):
		return
	if str(条目.get("类别", "")) == "护身":
		弟子兑换保命(d.弟子ID, 1)
		return
	var 物 = 条目.get("物品", null)
	if 物 is Item:
		弟子兑换(d.弟子ID, 物)

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
		if str(a.get("id") if "id" in a else "") == id:
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
		if str(a.get("id") if "id" in a else "") != id:
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
		"lingshi": 灵石, "lingcao": 灵草, "lingcao_bainian": 灵草_百年, "lingcao_qiannian": 灵草_千年, "lingcao_wannian": 灵草_万年, "自创功法列表": 自创功法列表, "自创功法总数": 自创功法总数, "藏经阁功法列表": 藏经阁功法列表, "kuangshi": 矿石, "lingqi": 灵气, "lingjing": 灵晶, "gongxian": 贡献点, "精铁": 精铁, "玄铁": 玄铁, "庚金": 庚金, "紫晶": 紫晶, "星辰铁": 星辰铁, "太阳精金": 太阳精金, "灵品灵草": 灵品灵草, "宝品灵草": 宝品灵草, "王品灵草": 王品灵草, "圣品灵草": 圣品灵草, "仙品灵草": 仙品灵草, "妖兽内丹": 妖兽内丹, "妖兽精血": 妖兽精血, "妖兽骨": 妖兽骨, "妖兽皮": 妖兽皮, "妖兽筋": 妖兽筋, "妖兽爪": 妖兽爪, "妖兽毛": 妖兽毛, "灵木": 灵木, "灵蚕丝": 灵蚕丝, "灵禽羽": 灵禽羽, "灵马尾": 灵马尾, "玉石": 玉石,
		"仙玉_绑定": 仙玉_绑定, "仙玉_非绑定": 仙玉_非绑定,
		"付费增益值": 付费增益值, "历练额外次数": 历练额外次数,  # S1-4 付费状态持久化（旧档缺键→默认0）
		"改名卡数量": 改名卡数量,  # S1 新增：宗主改名消耗品（不升SAVE_VERSION，旧档缺键→默认0：
		"dizi": [], "lingshou_dan": [], "lingshou_kucun": [], "lingshou_duilie": 灵兽管理系统.灵兽兑换队列,
		"累计游戏日": 累计游戏日, "最后登录": 最后登录, "门派等级": 门派等级, "声望": 声望, "繁荣": 繁荣, "繁荣经营值": 繁荣经营值, "当前皮肤": 当前皮肤,
		"香火值": 香火值, "信徒数": 信徒数, "凡人城镇": 王朝系统.凡人城镇, "香火日产预估": 香火日产预估, "信徒增益档": 信徒增益档,
		# 开宗捏脸（不升 SAVE_VERSION，旧档缺键→默认零回归）
		"宗门": 宗门名, "宗主名": 宗主名, "宗主性别": 宗主性别, "宗主头像": 宗主头像,
		# 称号系统：宗主称号（旧档缺键→默认空）
		"宗主当前称号": 宗主当前称号, "宗主已获得称号": 宗主已获得称号,
		# 头像选择系统 + 三类渠道计数：充值状态（不升 SAVE_VERSION，旧档缺键→默认零回归；头像框系统已：2026-08-21 取消：
		"已解锁头像": 已解锁头像,
		"奇遇完成总数": 奇遇完成总数, "高级奇遇完成数": 高级奇遇完成数, "已首充": 已首充, "累充额": 累充额,
		"邮件系统.邮件列表": 邮件系统.邮件列表,   # 灵讯（邮件）系统（不升SAVE_VERSION，旧档缺键→默认[]，零回归：
		"消息系统": 消息系统.to_dict(),   # S56 修真世界消息系统（不升SAVE_VERSION，旧档缺键→默认空）
		"世界地图系统": 世界地图系统.to_dict(),   # S58 世界地图系统（不升SAVE_VERSION，旧档缺键→默认空）
		"宗门外交.宗门关系": 宗门关系,   # P2-3.1 宗门外交关系表（不升SAVE_VERSION，旧档缺键→默认{}后由 _初始化宗门关系 重新播种）
		"闭关嘱托": 闭关嘱托.to_dict(),   # S59 闭关嘱托系统（不升SAVE_VERSION，旧档缺键→默认空）
		"传讯系统.待处理传讯": 待处理传讯,   # 实时传讯系统（不升SAVE_VERSION，旧档缺键→默认[]，零回归）
		"传讯系统.传讯历史": 传讯历史,   # 传讯历史记录（不升SAVE_VERSION，旧档缺键→默认[]，零回归）
		"庆典系统.论道大会冷却": 论道大会冷却,   # 论道大会冷却（不升SAVE_VERSION，旧档缺键→默认0，零回归）
		"庆典系统.祭祖大典年份": _祭祖大典年份标记,   # 祭祖大典年份标记（不升SAVE_VERSION，旧档缺键→默认-1，零回归）
		"玄榜系统.玄榜虚拟宗门": 玄榜系统.玄榜虚拟宗门,   # 玄榜（排行榜）：虚拟对手宗门（不升SAVE_VERSION，旧档缺键→默认[]，零回归：
		"碎片宝箱系统.碎片库存": 碎片宝箱系统.碎片库存,   # 碎片合成系统（不升SAVE_VERSION，旧档缺键→默认{}，零回归：
		"碎片宝箱系统.宝箱库存": 碎片宝箱系统.宝箱库存,   # 宝箱系统（不升SAVE_VERSION，旧档缺键→默认{}，零回归：
		"辈分字派": 辈分字派, "门规严格度": 门规严格度, "正邪路线": 正邪路线, "宗门大阵": 宗门大阵,
		"功德": 功德, "业力": 业力, "愿力": 愿力,
		"连锁进度": 连锁进度,   # P3：连锁链进度（旧档缺键→默认空 dict 回归）
		"设置": 设置项, "道友列表": 道友系统._道友列表, "道友消息": 道友系统._道友消息,   # 设置/本地道友（不升SAVE_VERSION，旧档缺键→默认零回归）
		# S1 ：：日供（不升 SAVE_VERSION，旧档缺键→默认零回归）
		"日供最后领取日": 日供_最后领取日, "日供最后领取现实日": 日供_最后领取现实日, "连续理事天数": 连续理事天数,
		"日供总领取次": 日供_总领取次数, "回溯玉符数量": 回溯玉符数量,
		"司职负责人存档": 司职负责人存档, "司职状态存档": 司职状态存档, "引导阶段": 引导阶段,
		"上次出战弟子": _上次出战弟子, "器殿赠宝连计": _器殿赠宝未中上阵连计,   # 器殿赠宝 P1 状态（不升 SAVE_VERSION，旧档缺键→默认零回归）
		"每日机缘": 每日机缘, "已通关秘境": 已通关秘境, "精英每日次数": 精英每日次数,
		"护道人列表": 护道人列表, "护道人计数器": 护道人计数器, "护道玉符": 护道玉符, "护道续缘符": 护道续缘符, "功德玉牌": 功德玉牌, "气运符箓": 气运符箓, "替死玉符": 替死玉符,
		"渡劫准备配置": 渡劫准备配置,   # 天劫渡劫外力预设（不升 SAVE_VERSION，旧档缺键→默认零配置）
		"宗主观礼配置": 宗主观礼配置,   # S46 宗主观礼邀请配置（不升 SAVE_VERSION，旧档缺键→默认全开）
		"气运修炼加成": 气运修炼加成, "气运产出加成": 气运产出加成, "气运到期日": 气运到期日,
		"历史周期评级": 周期评分.历史, "上次结算年": 上次结算年, "年始灵石": 年始灵石, "年始总战力": 年始总战力, "年始宗主战力": 年始宗主战力, "年始宗主境界": 年始宗主境界, "活动上次重置日期": 活动上次重置日期, "活动上次重置周": 活动上次重置周, "活动积分": 活动积分, "连续参与天数": 连续参与天数, "上次参与现实日": 上次参与现实日, "历史总参与天数": 历史总参与天数,
		"七载赏赐池": 七载赏赐池, "七载待发掉落": 七载待发掉落, "门派等级目标": 门派等级目标, "上次七载日": 上次七载日,
		# S0 差事/商店系统（不升SAVE_VERSION：load ：.get 默认兼容老档：
		"先贤堂": 先贤堂,   # WAVE-C #3：先贤祠静态档案（不升 SAVE_VERSION，旧档缺键→默认[]：
		"祖师堂": 祖师堂, "飞升前兆队列": 飞升前兆队列, "散仙列表": 散仙列表, "化身列表": 化身列表,   # 飞升系统+化身系统（不升SAVE_VERSION，旧档缺键→默认[]）
		# S1 赛季战令（功：/ 宗门令；不升 SAVE_VERSION，旧档缺键→默认零回归）
		"战令_赛季": 战令_赛季, "战令_等级": 战令_等级, "战令_经验": 战令_经验,
		"战令_已购付费": 战令_已购付费轨, "战令_已领免费": 战令_已领免费, "战令_已领付费": 战令_已领付费,
		# WAVE-D #6/#8：图：里程：传承史册（不升SAVE_VERSION：load ：.get 默认兼容老档：
		"图录_已收集": 收藏图录_已收集, "产出池加成": 产出池加成,
		"里程碑_已达成": 里程碑_已达成, "捐赠记录": 捐赠记录, "传承史册": 传承史册,
		# S1 ：：成就系统（不升 SAVE_VERSION：load ：.get 默认空数组，老档零回归）
		"成就系统.成就_已达成": 成就系统.成就_已达成,
		"kucun": [], "fangshi": 坊市购买记录, "fs_list": 坊市上架集,
		# S27 宗门任务榜（4 键，与 load 严格对称）
		"sect_bounty": 宗门任务榜, "sect_bounty_run": 宗门任务进行中,
		"sect_bounty_petition": 弟子请命列表, "sect_bounty_seq": 宗门任务计数器,
		"fangshi_leibie": 坊市类别月购, "fangshi_month_start": 坊市月购窗口起始日,
		"fangshi_buyback": 坊市回购列表, "fangshi_tehui": 坊市每日特惠, "fangshi_tehui_day": 坊市特惠卡,
		"daily": {"当前": 当前日常, "已领": 日常已领, "上次日常日": 上次日常日, "上次日常真实秒": 上次日常真实秒, "计数": 日常计数},
		"weekly": {"当前": 当前周常, "已领": 周常已领, "上次周常日": 上次周常日, "上次周常真实秒": 上次周常真实秒, "计数": 周常计数},
		"main_done": 主线已完成,
		"policy": 方针,
		# 灵兽方针（喂养/培养）：不升SAVE_VERSION，旧档缺键→默认零回归
		"beast_policy": {"喂养": 灵兽喂养方针, "培养": 灵兽培养方针},
		"daily_policy": 日常方针,
		# 突破方针（C3 宗主干预接口③）：不升SAVE_VERSION，旧档缺键→默认零回归
		"breakthrough_policy": 突破方针,
		"memorials": 待决奏折,
		"randcd": 随机事件冷却, "rtypecd": 随机事件类型冷却, "qcd": quest_cooldown,
		"newbie_active": 新手目标链激活, "newbie_done": 新手完成列表,
		# 皮肤系统（不升SAVE_VERSION，旧档缺键→默认零回归）
		"当前宗主皮肤": 当前宗主皮肤, "已拥有宗主皮肤": 已拥有宗主皮肤,
		"已拥有弟子皮肤": 已拥有弟子皮肤,
		# 历练派遣系统（不升SAVE_VERSION，旧档缺键→默认零回归）
		"历练系统": ExpeditionSystem.to_dict() if ExpeditionSystem != null else {},
		# P0-2渡劫系统存档（不升SAVE_VERSION，旧档缺键→默认零回归）
		"渡劫系统": Tribulation.to_dict() if Tribulation != null else {},
		# P0-3炼丹系统存档（不升SAVE_VERSION，旧档缺键→默认零回归）
		"炼丹系统": AlchemySystem.to_dict() if AlchemySystem != null else {},
		# §11.15 商路贸易：商队系统状态持久化（已拆分到caravan_system.gd）
		"商队系统": 商队系统.to_dict(),
		"灵钓系统": 灵钓系统.to_dict(),
		"探秘系统": 探秘系统.to_dict(),
		"饲灵系统": 饲灵系统.to_dict(),
		"卜算系统": 卜算系统.to_dict(),
		"药圃系统": 药圃系统.to_dict(),
		"论道系统": 论道系统.to_dict(),
		# S34c 传送阵（不升SAVE_VERSION，旧档缺键→默认值）
		"传送阵等级": 传送阵等级, "传送阵建造中": 传送阵建造中, "传送阵今日已用": 传送阵今日已用, "传送阵待机欠费": 传送阵待机欠费, "enable_teleport_system": enable_teleport_system,
		"朝报": 朝报, "朝报未读": 朝报未读, "朝奏": 朝奏, "上次朝奏日": 上次朝奏日, "上次祥瑞日": 上次祥瑞日, "上次祥瑞日序号": 上次祥瑞日序号, "今日祥瑞数": 今日祥瑞数, "下次必降祥瑞": 下次必降祥瑞, "enable_dynasty_gazette": enable_dynasty_gazette,
		# §11.15 优化#69/#72/#73/#74/#75 贸易拓展持久化（不升SAVE_VERSION）
		"商队系统.累计贸易次数": 商队系统.累计贸易次数, "商队系统.累计贸易收益": 商队系统.累计贸易收益,
		"宗门领地": 宗门领地,   # S31 宣战/领地战（不升SAVE_VERSION，旧档缺键→默认[]）
		# S32 宣战周期化 / 战场功勋（不升SAVE_VERSION，旧档缺键→默认值）
		"战功": 战功,
		"赛季序号": 赛季序号,
		"宣战周已用": 宣战周已用,
		"本周宣战胜场": 本周宣战胜场,
		"赛季累计战功": 赛季累计战功,
		"上次宣战周真实秒": 上次宣战周真实秒,
		"上次赛季真实秒": 上次赛季真实秒,
		"战功道具库存": 战功道具库存,
		# S33-5 阵营战役（不升SAVE_VERSION，旧档缺键→默认值）
		"阵营战役周已用": 阵营战役周已用,
		"阵营战役战绩": 阵营战役战绩,
		# S34 凡人王朝（不升SAVE_VERSION，旧档缺键→兜底）
		"王朝": 王朝系统.王朝,
		"凡间差事榜": 王朝系统.凡间差事榜,
		"凡间差事进行中": 王朝系统.凡间差事进行中,
		"郡县状态": 王朝系统.郡县状态,
		"香火庙": 香火庙, "郡信仰": 王朝系统.郡信仰, "enable_faith_system": enable_faith_system,   # S35-2
		"誓约待批": 誓约待批, "万仙大誓": 万仙大誓, "誓约推进日": 誓约推进日,   # S36 心魔誓
		"丹纹图谱": 丹纹系统.丹纹图谱, "丹纹日志": 丹纹系统.丹纹日志, "丹纹今日纪事": 丹纹系统.丹纹今日纪事, "丹纹纪事日": 丹纹系统.丹纹纪事日,   # S37 丹纹
		"丹方熟练度": 丹方熟练度, "已领悟丹方": 已领悟丹方, "丹方领悟进度": 丹方领悟进度, "当前丹炉": 当前丹炉, "丹炉列表": 丹炉列表,
		"符箓熟练度": 符箓熟练度, "当前符纸": 当前符纸,
		"绘符经验值": 绘符经验值,
		"符纹图谱": 符纹系统.符纹图谱, "符纹日志": 符纹系统.符纹日志, "符纹今日纪事": 符纹系统.符纹今日纪事, "符纹纪事日": 符纹系统.符纹纪事日,   # S45-4 符纹
		"入赘名录": 王朝系统.入赘名录,
		"外戚索要待决": 王朝系统.外戚索要待决,
		# S34b 通用拍卖会（不升SAVE_VERSION，旧档缺键->默认{}）
		"拍卖行系统": 拍卖行系统.to_dict(),
		# v3 新增：阵营任务和商店系统（旧档缺键→默认零回归）
		"阵营任务进度": 阵营声望系统.阵营任务进度,
		"阵营商店购买记录": 阵营声望系统.阵营商店购买记录,
		# v3 新增：道友互动系统（旧档缺键→默认零回归）
		"结义道友列表": 道友系统.结义道友列表,
		"道友拜访冷却": 道友系统.道友拜访冷却,
		"道友切磋冷却": 道友系统.道友切磋冷却,
		# v3 新增：探索事件分支选择系统（旧档缺键→默认零回归）
		"探索事件冷却": 探索事件冷却,
		# 傀儡系统（已拆分到puppet_system.gd）
		"傀儡系统": 傀儡系统.to_dict(),
		# 藏书阁系统（已拆分到library_system.gd）
		"藏书阁系统": 藏书阁系统.to_dict(),
		# 阵法管理系统（已拆分到formation_system.gd）
		"阵法管理系统": 阵法管理系统.to_dict(),
		# 坐骑系统（已拆分到mount_system.gd）
		"坐骑系统": 坐骑系统.to_dict(),
		# 碎片宝箱系统（已拆分到fragment_chest_system.gd）
		"碎片宝箱系统": 碎片宝箱系统.to_dict(),
		# 邮件系统（已拆分到mail_system.gd）
		"邮件系统": 邮件系统.to_dict(),
		# 宗门科技系统（已拆分到sect_tech_system.gd）
		"宗门科技系统": 宗门科技系统.to_dict(),
		# 玄榜系统（已拆分到xuan_rank_system.gd）
		"玄榜系统": 玄榜系统.to_dict(),
		# 炼丹炼器封装系统（已拆分到alchemy_forge_system.gd）
		"炼丹炼器系统": 炼丹炼器系统.to_dict(),
		# 符箓系统封装（已拆分到talisman_system.gd）
		"符箓封装系统": 符箓封装系统.to_dict(),
		# 功法管理系统（已拆分到gongfa_management_system.gd）
		"功法管理系统": 功法管理系统.to_dict(),
		# 灵兽管理系统（已拆分到beast_management_system.gd）
		"灵兽管理系统": 灵兽管理系统.to_dict(),
		# 弟子突破系统（已拆分到breakthrough_system.gd，无状态变量）
		"弟子突破系统": 弟子突破系统.to_dict(),
		# 成就系统（已拆分到achievement_system.gd）
		"成就系统": 成就系统.to_dict(),
		# 休闲玩法：酿道/厨道/茶道/琴道（不升SAVE_VERSION，旧档缺键→默认1级/0经验）
		"酿道等级": 酿道等级, "酿道经验": 酿道经验,
		"厨道等级": 厨道等级, "厨道经验": 厨道经验,
		"茶道等级": 茶道等级, "茶道经验": 茶道经验,
		"琴道等级": 琴道等级, "琴道经验": 琴道经验,
		"灵酿列表": 灵酿列表,
	}
	for it in 宗门库房:
		# S25 类型防御：库房原则上只装 Item；历史来源曾塞入裸 Dictionary（gongxun），
		# 直接调 to_dict() 会令存档崩溃（Dictionary 无此方法）→ 按类型分流
		if it is Item:
			data["kucun"].append(it.to_dict())
		elif typeof(it) == TYPE_DICTIONARY:
			data["kucun"].append(it)
	for d in 弟子列表:
		data["dizi"].append(d.to_dict())
	for e in 灵兽蛋列表:
		data["lingshou_dan"].append(e.to_dict())
	for b in 灵兽管理系统.灵兽库存:
		data["lingshou_kucun"].append(b.to_dict())
	# 存档安全：先写临时文件，校验后原子替换；写前滚动备份（按当前账号路径：
	if 当前账号id == "":
		push_warning("save_game: 当前账号id 为空，跳过存档")
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
	更新在线时间戳()  # S3：保存时更新最后在线时间
	f.close()
	var da: DirAccess = DirAccess.open("user://")
	var err: int = OK
	if da:
		err = da.rename(tmp, 路径)
	if err != OK:
		push_error("存档失败：原子替换错：%d" % err)
	更新账号摘要(当前账号id)
func load_game(账号id: String = "") -> void:
	# S2：旧档懒迁移宗主实体（读档后检查）
	call_deferred("_迁移宗主实体")

	if 账号id != "":
		当前账号id = 账号id
	if 当前账号id == "":
		return
	var 路径: String = 账号存档路径(当前账号id)
	if not FileAccess.file_exists(路径):
		# 全新账号：直接初始建宗（首次进入该账号）
		初始建宗()
		# 2026-09-14 修：新档此前只走 初始建宗 便 return，从不经 世界地图系统.from_dict ⇒
		#   地图系统全程未初始化：宗门落在 (0,0)（正压在紫府仙都上）、资源点列表为空（天下总览「资源点数 0」、
		#   地图上永远无资源可采）、模拟宗门为空。要等第二次登录走读档路径才自愈。
		#   此处按读档同款口径补一次空字典初始化（随机分配宗门位置 + 生成模拟宗门 + 初始化周边资源点）。
		世界地图系统.from_dict({})
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
		世界地图系统.from_dict({})   # 2026-09-14：同「全新账号」分支，补地图系统初始化（见上）
		_传承事件("开宗立派")
		更新账号摘要(当前账号id)
		save_game()
		重建司职()
		_复检里程碑()
		_复检成就()   # S1 ：：损坏兜底按当前状态补达成成就
		弟子变动.emit()
		return
	var _迁移后需存盘: bool = false
	if int(data.get("version") if "version" in data else 0) != SAVE_VERSION:
		push_warning("存档版本不一（%d），尝试兼容读取" % [data.get("version") if "version" in data else 0])
		_版本升级备份(data.get("version") if "version" in data else 0)
		# 存档迁移：处理旧版本的键名重命名和结构变更
		data = _迁移存档(data, data.get("version") if "version" in data else 0)
		_迁移后需存盘 = true
	灵石 = data.get("lingshi") if "lingshi" in data else 0
	灵草 = data.get("lingcao") if "lingcao" in data else 0
	灵草_百年 = data.get("lingcao_bainian") if "lingcao_bainian" in data else 0
	灵草_千年 = data.get("lingcao_qiannian") if "lingcao_qiannian" in data else 0
	灵草_万年 = data.get("lingcao_wannian") if "lingcao_wannian" in data else 0
	自创功法列表 = data.get("自创功法列表", []) if typeof(data.get("自创功法列表", [])) == TYPE_ARRAY else []
	自创功法总数 = int(data.get("自创功法总数", 0))
	藏经阁功法列表 = data.get("藏经阁功法列表", []) if typeof(data.get("藏经阁功法列表", [])) == TYPE_ARRAY else []
	矿石 = data.get("kuangshi") if "kuangshi" in data else 0
	精铁 = data.get("精铁") if "精铁" in data else 0
	玄铁 = data.get("玄铁") if "玄铁" in data else 0
	庚金 = data.get("庚金") if "庚金" in data else 0
	紫晶 = data.get("紫晶") if "紫晶" in data else 0
	星辰铁 = data.get("星辰铁") if "星辰铁" in data else 0
	太阳精金 = data.get("太阳精金") if "太阳精金" in data else 0
	灵品灵草 = data.get("灵品灵草") if "灵品灵草" in data else 0
	宝品灵草 = data.get("宝品灵草") if "宝品灵草" in data else 0
	王品灵草 = data.get("王品灵草") if "王品灵草" in data else 0
	圣品灵草 = data.get("圣品灵草") if "圣品灵草" in data else 0
	仙品灵草 = data.get("仙品灵草") if "仙品灵草" in data else 0
	# 妖兽内丹/精血：旧档是数字（统一算一阶），新档是Dictionary按等阶
	var _raw内丹 = data.get("妖兽内丹", 0)
	var _raw精血 = data.get("妖兽精血", 0)
	if typeof(_raw内丹) == TYPE_INT:
		妖兽内丹 = {"一阶": int(_raw内丹), "二阶": 0, "三阶": 0, "四阶": 0, "五阶": 0, "六阶": 0, "七阶": 0, "八阶": 0, "九阶": 0}
	else:
		妖兽内丹 = _raw内丹 if typeof(_raw内丹) == TYPE_DICTIONARY else {"一阶": 0, "二阶": 0, "三阶": 0, "四阶": 0, "五阶": 0, "六阶": 0, "七阶": 0, "八阶": 0, "九阶": 0}
	if typeof(_raw精血) == TYPE_INT:
		妖兽精血 = {"一阶": int(_raw精血), "二阶": 0, "三阶": 0, "四阶": 0, "五阶": 0, "六阶": 0, "七阶": 0, "八阶": 0, "九阶": 0}
	else:
		妖兽精血 = _raw精血 if typeof(_raw精血) == TYPE_DICTIONARY else {"一阶": 0, "二阶": 0, "三阶": 0, "四阶": 0, "五阶": 0, "六阶": 0, "七阶": 0, "八阶": 0, "九阶": 0}
	# 新材料（旧档缺键→默认0）
	var _默认等阶: Dictionary = {"一阶": 0, "二阶": 0, "三阶": 0, "四阶": 0, "五阶": 0, "六阶": 0, "七阶": 0, "八阶": 0, "九阶": 0}
	妖兽骨 = data.get("妖兽骨", _默认等阶.duplicate()) if typeof(data.get("妖兽骨", {})) == TYPE_DICTIONARY else _默认等阶.duplicate()
	妖兽皮 = data.get("妖兽皮", _默认等阶.duplicate()) if typeof(data.get("妖兽皮", {})) == TYPE_DICTIONARY else _默认等阶.duplicate()
	妖兽筋 = data.get("妖兽筋", _默认等阶.duplicate()) if typeof(data.get("妖兽筋", {})) == TYPE_DICTIONARY else _默认等阶.duplicate()
	妖兽爪 = data.get("妖兽爪", _默认等阶.duplicate()) if typeof(data.get("妖兽爪", {})) == TYPE_DICTIONARY else _默认等阶.duplicate()
	妖兽毛 = data.get("妖兽毛", _默认等阶.duplicate()) if typeof(data.get("妖兽毛", {})) == TYPE_DICTIONARY else _默认等阶.duplicate()
	灵木 = int(data.get("灵木", 0))
	灵蚕丝 = int(data.get("灵蚕丝", 0))
	灵禽羽 = int(data.get("灵禽羽", 0))
	灵马尾 = int(data.get("灵马尾", 0))
	玉石 = int(data.get("玉石", 0))

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
	已拥有弟子皮肤= data.get("已拥有弟子皮肤") if "已拥有弟子皮肤" in data else []
	# 历练派遣系统（旧档缺键→默认零回归，不升 SAVE_VERSION）
	if ExpeditionSystem != null:
		ExpeditionSystem.from_dict(data.get("历练系统") if "历练系统" in data else {})
		# P0-2渡劫系统加载（旧档缺键→默认零回归，不升SAVE_VERSION）
		if Tribulation != null:
			Tribulation.from_dict(data.get("渡劫系统") if "渡劫系统" in data else {})
		# P0-3炼丹系统加载（旧档缺键→默认零回归，不升SAVE_VERSION）
		if AlchemySystem != null:
			AlchemySystem.from_dict(data.get("炼丹系统") if "炼丹系统" in data else {})
	# §11.15 商路贸易：商队系统状态加载（已拆分到caravan_system.gd，兼容旧存档）
	if "商队系统" in data:
		商队系统.from_dict(data["商队系统"])
	if "灵钓系统" in data:
		灵钓系统.from_dict(data["灵钓系统"])
	if "探秘系统" in data:
		探秘系统.from_dict(data["探秘系统"])
	if "饲灵系统" in data:
		饲灵系统.from_dict(data["饲灵系统"])
	if "卜算系统" in data:
		卜算系统.from_dict(data["卜算系统"])
	if "药圃系统" in data:
		药圃系统.from_dict(data["药圃系统"])
	if "论道系统" in data:
		论道系统.from_dict(data["论道系统"])
	else:
		# 旧存档兼容：从旧键恢复
		var _旧商队数据: Dictionary = {
			"商队列表": data.get("商队列表", []),
			"商队历史": data.get("商队历史", []),
			"商队地区": data.get("商队地区", []),
			"商路声望": data.get("商路声望", {}),
			"行情事件列表": data.get("行情事件列表", []),
			"商队每日已派": data.get("商队每日已派", 0),
			"上次配额日真实秒": data.get("上次配额日真实秒", 0),
			"上次行情日真实秒": data.get("上次行情日真实秒", 0),
			"灵舟坞等级": data.get("灵舟坞等级", 0),
			"黑市禁闭日": data.get("黑市禁闭日", 0),
			"商路竞争状态": data.get("商路竞争状态", {}),
			"灵舟库存": data.get("灵舟库存", []),
			"灵舟坞建造中": data.get("灵舟坞建造中", {}),
			"灵舟建造队列": data.get("灵舟建造队列", []),
			"虚空大阵冷却日": data.get("虚空大阵冷却日", 0),
			"累计贸易次数": data.get("累计贸易次数", 0),
			"累计贸易收益": data.get("累计贸易收益", 0),
		}
		商队系统.from_dict(_旧商队数据)
	# S34c 传送阵（不升SAVE_VERSION，旧档缺键→默认值）
	传送阵等级 = int(data.get("传送阵等级", 0)) if "传送阵等级" in data else 0
	传送阵建造中 = data.get("传送阵建造中") if "传送阵建造中" in data else {}
	传送阵今日已用 = int(data.get("传送阵今日已用", 0)) if "传送阵今日已用" in data else 0
	传送阵待机欠费 = bool(data.get("传送阵待机欠费", false)) if "传送阵待机欠费" in data else false
	香火庙 = (data.get("香火庙", {}) as Dictionary) if "香火庙" in data else {}
	誓约待批 = (data.get("誓约待批", []) as Array) if "誓约待批" in data else []
	万仙大誓 = (data.get("万仙大誓", {}) as Dictionary) if "万仙大誓" in data else {}
	誓约推进日 = int(data.get("誓约推进日", 0))   # S36 旧档缺键→0，首个日切只记不判
	丹纹系统.丹纹图谱 = (data.get("丹纹图谱", {}) as Dictionary) if "丹纹图谱" in data else {}
	丹方熟练度 = (data.get("丹方熟练度", {}) as Dictionary) if "丹方熟练度" in data else {}
	已领悟丹方 = (data.get("已领悟丹方", {}) as Dictionary) if "已领悟丹方" in data else {}
	丹方领悟进度 = (data.get("丹方领悟进度", {}) as Dictionary) if "丹方领悟进度" in data else {}
	_初始化领悟丹方()
	当前丹炉 = str(data.get("当前丹炉", "")) if "当前丹炉" in data else ""
	符箓熟练度 = (data.get("符箓熟练度", {}) as Dictionary) if "符箓熟练度" in data else {}
	当前符纸 = str(data.get("当前符纸", "")) if "当前符纸" in data else ""
	绘符经验值 = int(data.get("绘符经验值", 0)) if "绘符经验值" in data else 0
	符纹系统.符纹图谱 = (data.get("符纹图谱", {}) as Dictionary) if "符纹图谱" in data else {}
	符纹系统.符纹日志 = (data.get("符纹日志", []) as Array) if "符纹日志" in data else []
	符纹系统.符纹今日纪事 = int(data.get("符纹今日纪事", 0)) if "符纹今日纪事" in data else 0
	符纹系统.符纹纪事日 = int(data.get("符纹纪事日", 0)) if "符纹纪事日" in data else 0
	丹炉列表 = (data.get("丹炉列表", []) as Array) if "丹炉列表" in data else []
	丹纹系统.丹纹日志 = (data.get("丹纹日志", []) as Array) if "丹纹日志" in data else []
	丹纹系统.丹纹今日纪事 = int(data.get("丹纹今日纪事", 0)) if "丹纹今日纪事" in data else 0
	丹纹系统.丹纹纪事日 = int(data.get("丹纹纪事日", 0)) if "丹纹纪事日" in data else 0
	_丹纹补缺()
	符纹校验()
	王朝系统.郡信仰 = (data.get("郡信仰", {}) as Dictionary) if "郡信仰" in data else {}
	enable_faith_system = bool(data.get("enable_faith_system", true)) if "enable_faith_system" in data else true
	信仰表缓存.clear()
	_信仰补缺()
	enable_teleport_system = bool(data.get("enable_teleport_system", true)) if "enable_teleport_system" in data else true
	朝报 = (data.get("朝报", []) as Array) if "朝报" in data else []
	朝报未读 = int(data.get("朝报未读", 0)) if "朝报未读" in data else 0
	朝奏 = (data.get("朝奏", {}) as Dictionary) if "朝奏" in data else {}
	上次朝奏日 = int(data.get("上次朝奏日", -1)) if "上次朝奏日" in data else -1
	上次祥瑞日 = int(data.get("上次祥瑞日", -999)) if "上次祥瑞日" in data else -999
	上次祥瑞日序号 = int(data.get("上次祥瑞日序号", -1)) if "上次祥瑞日序号" in data else -1
	今日祥瑞数 = int(data.get("今日祥瑞数", 0)) if "今日祥瑞数" in data else 0
	下次必降祥瑞 = bool(data.get("下次必降祥瑞", false)) if "下次必降祥瑞" in data else false
	enable_dynasty_gazette = bool(data.get("enable_dynasty_gazette", true)) if "enable_dynasty_gazette" in data else true
	_传送阵补缺()
	# 灵舟建造队列/虚空大阵冷却日已移至商队系统（上面已加载）
	宗门领地 = data.get("宗门领地") if "宗门领地" in data else []   # S31 宣战/领地战（不升SAVE_VERSION，旧档缺键→默认[]）
	宗主观礼配置 = data.get("宗主观礼配置") if "宗主观礼配置" in data else {"本宗人员": true, "道友道侣": true, "友好阵营": true, "同盟阵营": true, "手动名单": [], "其他玩家": []}   # S46（不升SAVE_VERSION，旧档缺键→默认全开）
	# S32 宣战周期化 / 战场功勋（旧档缺键→默认值，不升SAVE_VERSION）
	战功 = int(data.get("战功") if "战功" in data else 0)
	赛季序号 = int(data.get("赛季序号") if "赛季序号" in data else 1)
	宣战周已用 = int(data.get("宣战周已用") if "宣战周已用" in data else 0)
	本周宣战胜场 = int(data.get("本周宣战胜场") if "本周宣战胜场" in data else 0)
	赛季累计战功 = int(data.get("赛季累计战功") if "赛季累计战功" in data else 0)
	上次宣战周真实秒 = int(data.get("上次宣战周真实秒") if "上次宣战周真实秒" in data else 0)
	上次赛季真实秒 = int(data.get("上次赛季真实秒") if "上次赛季真实秒" in data else 0)
	战功道具库存 = data.get("战功道具库存") if "战功道具库存" in data else {}
	# S33-5 阵营战役（旧档缺键→默认值，不升SAVE_VERSION）
	阵营战役周已用 = int(data.get("阵营战役周已用") if "阵营战役周已用" in data else 0)
	阵营战役战绩 = data.get("阵营战役战绩") if "阵营战役战绩" in data else {}
	# S34 凡人王朝（旧档缺键→_新王朝()兜底初始化，不升SAVE_VERSION）
	var _王朝数据 = data.get("王朝") if "王朝" in data else {}
	if _王朝数据 is Dictionary and not (_王朝数据 as Dictionary).is_empty():
		王朝系统.王朝 = _王朝数据
	else:
		王朝系统.王朝 = _新王朝(1)
	王朝系统.凡间差事榜 = data.get("凡间差事榜") if "凡间差事榜" in data else {}
	王朝系统.凡间差事进行中 = data.get("凡间差事进行中") if "凡间差事进行中" in data else {}
	王朝系统.郡县状态 = data.get("郡县状态") if "郡县状态" in data else {}
	if 王朝系统.郡县状态.is_empty():
		_初始化郡县状态_S34()
	# 批次 2：入赘名录 / 外戚索要待决（旧档缺键→空，不升 SAVE_VERSION）
	王朝系统.入赘名录 = data.get("入赘名录") if "入赘名录" in data else []
	王朝系统.外戚索要待决 = data.get("外戚索要待决") if "外戚索要待决" in data else {}
	if 王朝系统.王朝.get("派系", []).is_empty():
		_初始化派系_S34()
	_王朝补缺_S34()
	# 拍卖行系统状态加载（已拆分到auction_system.gd，兼容旧存档）
	if "拍卖行系统" in data:
		拍卖行系统.from_dict(data["拍卖行系统"])
	else:
		# 旧存档兼容
		var _旧拍卖会数据: Dictionary = {}
		if "拍卖会" in data:
			_旧拍卖会数据["拍卖会"] = data["拍卖会"]
		拍卖行系统.from_dict(_旧拍卖会数据)
	# 商队系统.累计贸易次数/收益已移至商队系统（上面已加载）
	# 开宗捏脸（旧档缺键→默认零回归，不升SAVE_VERSION）
	宗门名 = data.get("宗门名") if "宗门名" in data else "太玄宗"
	宗主名= data.get("宗主名") if "宗主名" in data else "太虚道君"
	宗主性别 = data.get("宗主性别") if "宗主性别" in data else ""
	宗主头像 = data.get("宗主头像") if "宗主头像" in data else ""
	if 宗主头像 == "":
		var _默认头像: Dictionary = 默认解锁头像(宗主性别)
		宗主头像 = _默认头像.get("id", "")
	# 称号系统：宗主称号（旧档缺键→默认空）
	宗主当前称号 = data.get("宗主当前称号") if "宗主当前称号" in data else ""
	宗主已获得称号 = data.get("宗主已获得称号") if "宗主已获得称号" in data else []
	# 头像选择系统（旧档缺键→默认零回归，不升 SAVE_VERSION；头像框系统已于 2026-08-21 取消，相关键忽略：
	已解锁头像= data.get("已解锁头像") if "已解锁头像" in data else []
	邮件系统.邮件列表 = data.get("邮件系统.邮件列表") if "邮件系统.邮件列表" in data else []   # 灵讯（邮件）系统：旧档缺键→默认[]，零回归（不升SAVE_VERSION）
	消息系统.from_dict(data.get("消息系统", {}))   # S56 修真世界消息系统：旧档缺键→默认空
	世界地图系统.from_dict(data.get("世界地图系统", {}))   # S58 世界地图系统：旧档缺键→随机分配位置
	宗门关系 = data.get("宗门外交.宗门关系", {})   # P2-3.1 宗门外交关系表：旧档缺键→{}，随后 _初始化宗门关系 补种已知宗门
	闭关嘱托.from_dict(data.get("闭关嘱托", {}))   # S59 闭关嘱托系统：旧档缺键→默认空
	待处理传讯 = data.get("传讯系统.待处理传讯") if "传讯系统.待处理传讯" in data else []   # 实时传讯系统：旧档缺键→默认[]，零回归（不升SAVE_VERSION）
	传讯历史 = data.get("传讯系统.传讯历史") if "传讯系统.传讯历史" in data else []   # 传讯历史：旧档缺键→默认[]，零回归（不升SAVE_VERSION）
	论道大会冷却 = int(data.get("庆典系统.论道大会冷却", 0))   # 论道大会冷却：旧档缺键→默认0，零回归（不升SAVE_VERSION）
	_祭祖大典年份标记 = int(data.get("庆典系统.祭祖大典年份", -1))   # 祭祖大典年份标记：旧档缺键→默认-1，零回归（不升SAVE_VERSION）
	玄榜系统.玄榜虚拟宗门 = data.get("玄榜系统.玄榜虚拟宗门") if "玄榜系统.玄榜虚拟宗门" in data else []   # 玄榜（排行榜）：旧档缺键→默认[]，零回归（不升SAVE_VERSION）
	碎片宝箱系统.碎片库存 = data.get("碎片宝箱系统.碎片库存") if "碎片宝箱系统.碎片库存" in data else {}   # 碎片合成系统：旧档缺键→默认{}，零回归（不升SAVE_VERSION）
	碎片宝箱系统.宝箱库存 = data.get("碎片宝箱系统.宝箱库存") if "碎片宝箱系统.宝箱库存" in data else {}   # 宝箱系统：旧档缺键→默认{}，零回归（不升SAVE_VERSION）
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
	王朝系统.凡人城镇.clear()
	for 镇 in data.get("凡人城镇") if "凡人城镇" in data else []:
		王朝系统.凡人城镇.append(镇)
	# WAVE-C #3：先贤祠静态档案（旧档缺键→默认[]，零回归：
	先贤堂= data.get("先贤堂") if "先贤堂" in data else []
	# 飞升系统+化身系统（旧档缺键→默认[]，零回归）
	祖师堂 = data.get("祖师堂") if "祖师堂" in data else []
	飞升前兆队列 = data.get("飞升前兆队列") if "飞升前兆队列" in data else []
	散仙列表 = data.get("散仙列表") if "散仙列表" in data else []
	化身列表 = data.get("化身列表") if "化身列表" in data else []
	# WAVE-D #6/#8：图录里程/传承史册（旧档缺键→默认零回归）
	# 修复 2026-09-15：读键原为乱码「图录_已收：」，与 save_game 写键「图录_已收集」不一致，
	#   导致图鉴数据写入后读档永远回落 {}（图鉴全开不生效的根因）。
	收藏图录_已收集= data.get("图录_已收集") if "图录_已收集" in data else {}
	产出池加成= data.get("产出池加成") if "产出池加成" in data else 0.0
	里程碑_已达成= data.get("里程碑_已达成") if "里程碑_已达成" in data else []
	# S1 ：：成就系统（旧档缺键→默认空数组，零回归：
	成就系统.成就_已达成= data.get("成就系统.成就_已达成") if "成就系统.成就_已达成" in data else []
	捐赠记录 = data.get("捐赠记录") if "捐赠记录" in data else {}
	传承史册 = data.get("传承史册") if "传承史册" in data else []
	香火日产预估 = data.get("香火日产预估") if "香火日产预估" in data else (data.get("香火月产预估") if "香火月产预估" in data else 0)
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
	设置项= data.get("设置") if "设置" in data else {}
	# 战斗模式同步：从设置项中读取战斗模式（完整结算→full，加速结算→quick）
	var 设置战斗模式: String = str(设置项.get("战斗模式", "完整结算"))
	战斗模式 = "full" if 设置战斗模式 == "完整结算" else "quick"
	道友系统._道友列表 = data.get("道友列表") if "道友列表" in data else []
	道友系统._道友消息 = data.get("道友消息") if "道友消息" in data else []
	# S1 赛季战令（功：/ 宗门令；旧档缺键→默认零回归，不升SAVE_VERSION）
	战令_赛季 = data.get("战令_赛季") if "战令_赛季" in data else 1
	战令_等级 = data.get("战令_等级") if "战令_等级" in data else 0
	战令_经验 = data.get("战令_经验") if "战令_经验" in data else 0
	战令_已购付费轨= bool(data.get("战令_已购付费") if "战令_已购付费" in data else false)
	战令_已领免费 = data.get("战令_已领免费") if "战令_已领免费" in data else []
	战令_已领付费 = data.get("战令_已领付费") if "战令_已领付费" in data else []
	# S1 ：：日供（旧档缺键→默认零回归，不升SAVE_VERSION）
	日供_最后领取日 = data.get("日供最后领取日") if "日供最后领取日" in data else 0
	日供_最后领取现实日 = data.get("日供最后领取现实日") if "日供最后领取现实日" in data else ""
	连续理事天数 = data.get("连续理事天数") if "连续理事天数" in data else 0
	日供_总领取次数= data.get("日供总领取次") if "日供总领取次" in data else 0
	回溯玉符数量 = data.get("回溯玉符数量") if "回溯玉符数量" in data else 0
	已解锁单人法阵= data.get("已解锁单人法阵") if "已解锁单人法阵" in data else {}   # D5：弟子已解锁单人法阵集合（旧档缺键→默认：Dict：
	司职负责人存档= data.get("司职负责人存档") if "司职负责人存档" in data else {}
	司职状态存档= data.get("司职状态存档") if "司职状态存档" in data else {}   # S1 ：：等：政绩持久化（旧档缺键→默认空，零回归：
	引导阶段 = data.get("引导阶段") if "引导阶段" in data else 6   # 老档无此字段 ：默认6（已完成，不强制弹入门指引；阶段语义：§5.2：
	_上次出战弟子 = data.get("上次出战弟子") if "上次出战弟子" in data else []   # 器殿赠宝 P1 缓存（旧档缺键→默认空，零回归）：注意：赋值给模块变量 _上次出战弟子（带下划线），与声明/保存一：
	_器殿赠宝未中上阵连计 = data.get("器殿赠宝连计") if "器殿赠宝连计" in data else 0   # 保底计数器（旧档缺键→默认0）：同上，须写回 _器殿赠宝未中上阵连计
	气运修炼加成 = data.get("气运修炼加成") if "气运修炼加成" in data else 0.0
	气运产出加成 = data.get("气运产出加成") if "气运产出加成" in data else 0.0
	气运到期日= data.get("气运到期日") if "气运到期日" in data else 0
	# P0修复：体力系统已移除，改为每日机缘（旧档兼容：缺键默认空字典）
	每日机缘 = data.get("每日机缘") if "每日机缘" in data else {}
	已通关秘境 = data.get("已通关秘境") if "已通关秘境" in data else {}
	精英每日次数 = data.get("精英每日次数") if "精英每日次数" in data else {}
	# 护道人系统（旧档兼容：缺键默认值）
	护道人列表 = data.get("护道人列表") if "护道人列表" in data else {}
	护道人计数器 = int(data.get("护道人计数器", 0))
	护道玉符 = int(data.get("护道玉符", 0))
	护道续缘符 = int(data.get("护道续缘符", 0))
	功德玉牌 = int(data.get("功德玉牌", 0))
	气运符箓 = int(data.get("气运符箓", 0))
	替死玉符 = int(data.get("替死玉符", 0))
	渡劫准备配置 = data.get("渡劫准备配置", {"道具": [], "用护阵": false, "用护法": false})
	# v3 新增：阵营任务和商店系统（旧档缺键→默认零回归）
	阵营声望系统.阵营任务进度 = data.get("阵营任务进度") if "阵营任务进度" in data else {}
	阵营声望系统.阵营商店购买记录 = data.get("阵营商店购买记录") if "阵营商店购买记录" in data else {}
	# v3 新增：道友互动系统（旧档缺键→默认零回归）
	道友系统.结义道友列表 = data.get("结义道友列表") if "结义道友列表" in data else []
	道友系统.道友拜访冷却 = data.get("道友拜访冷却") if "道友拜访冷却" in data else {}
	道友系统.道友切磋冷却 = data.get("道友切磋冷却") if "道友切磋冷却" in data else {}
	# v3 新增：探索事件分支选择系统（旧档缺键→默认零回归）
	探索事件冷却 = data.get("探索事件冷却") if "探索事件冷却" in data else {}
	# 傀儡系统（已拆分到puppet_system.gd）
	if "傀儡系统" in data:
		傀儡系统.from_dict(data["傀儡系统"])
	else:
		# 旧档兼容：从旧字段加载
		傀儡系统.傀儡列表 = data.get("傀儡列表") if "傀儡列表" in data else []
		傀儡系统.傀儡ID计数器 = data.get("傀儡ID计数器") if "傀儡ID计数器" in data else 0
		傀儡系统.累计制作傀儡数 = data.get("累计制作傀儡数") if "累计制作傀儡数" in data else 0
	# 藏书阁系统（已拆分到library_system.gd）
	if "藏书阁系统" in data:
		藏书阁系统.from_dict(data["藏书阁系统"])
	else:
		# 旧档兼容：从旧字段加载
		藏书阁系统.藏书阁列表 = data.get("藏书阁列表") if "藏书阁列表" in data else []
		藏书阁系统.藏书阁ID计数器 = data.get("藏书阁ID计数器") if "藏书阁ID计数器" in data else 0
		藏书阁系统.藏书阁收录数 = data.get("藏书阁收录数") if "藏书阁收录数" in data else 0
		藏书阁系统.藏书阁临时加成 = data.get("藏书阁临时加成") if "藏书阁临时加成" in data else 0.0
		藏书阁系统.藏书阁加成到期日 = data.get("藏书阁加成到期日") if "藏书阁加成到期日" in data else 0
	# 阵法管理系统（已拆分到formation_system.gd）
	if "阵法管理系统" in data:
		阵法管理系统.from_dict(data["阵法管理系统"])
	else:
		# 旧档兼容：从旧字段加载
		阵法管理系统.阵法等级 = data.get("阵法等级") if "阵法等级" in data else {}
		阵法管理系统.阵法耐久度 = data.get("阵法耐久度") if "阵法耐久度" in data else {}
		阵法管理系统.阵法驻守弟子 = data.get("阵法驻守弟子") if "阵法驻守弟子" in data else {}
		阵法管理系统.阵法强化等级 = data.get("阵法强化等级") if "阵法强化等级" in data else {}
	# 坐骑系统（已拆分到mount_system.gd）
	if "坐骑系统" in data:
		坐骑系统.from_dict(data["坐骑系统"])
	else:
		坐骑系统.坐骑列表 = data.get("坐骑列表") if "坐骑列表" in data else []
		坐骑系统.当前坐骑 = data.get("当前坐骑") if "当前坐骑" in data else ""
		坐骑系统.坐骑ID计数器 = data.get("坐骑ID计数器") if "坐骑ID计数器" in data else 0
	# 碎片宝箱系统（已拆分到fragment_chest_system.gd）
	if "碎片宝箱系统" in data:
		碎片宝箱系统.from_dict(data["碎片宝箱系统"])
	else:
		碎片宝箱系统.碎片库存 = data.get("碎片库存") if "碎片库存" in data else {}
		碎片宝箱系统.宝箱库存 = data.get("宝箱库存") if "宝箱库存" in data else {}
	# 邮件系统（已拆分到mail_system.gd）
	if "邮件系统" in data:
		邮件系统.from_dict(data["邮件系统"])
	else:
		邮件系统.邮件列表 = data.get("邮件列表") if "邮件列表" in data else []
	# 宗门科技系统（已拆分到sect_tech_system.gd）
	if "宗门科技系统" in data:
		宗门科技系统.from_dict(data["宗门科技系统"])
	else:
		宗门科技系统.已研究宗门科技 = data.get("已研究宗门科技") if "已研究宗门科技" in data else []
	# 玄榜系统（已拆分到xuan_rank_system.gd）
	if "玄榜系统" in data:
		玄榜系统.from_dict(data["玄榜系统"])
	else:
		玄榜系统.玄榜虚拟宗门 = data.get("玄榜虚拟宗门") if "玄榜虚拟宗门" in data else []
	# 炼丹炼器封装系统（已拆分到alchemy_forge_system.gd）
	if "炼丹炼器系统" in data:
		炼丹炼器系统.from_dict(data["炼丹炼器系统"])
	else:
		炼丹炼器系统.炼器经验值 = data.get("炼器经验值") if "炼器经验值" in data else 0
	# 符箓系统封装（已拆分到talisman_system.gd，无状态变量）
	if "符箓封装系统" in data:
		符箓封装系统.from_dict(data["符箓封装系统"])
	# 功法管理系统（已拆分到gongfa_management_system.gd）
	if "功法管理系统" in data:
		功法管理系统.from_dict(data["功法管理系统"])
	else:
		功法管理系统.功法熟练度 = data.get("功法熟练度") if "功法熟练度" in data else {}
	# 灵兽管理系统（已拆分到beast_management_system.gd）
	# 灵兽库存/兑换队列由本函数后段的 lingshou_kucun / lingshou_duilie 扁平键统一回填（Beast 逐只重建）。
	# 原 else 分支用 data.get() 直接重赋 Array[Beast]（typed array 拒绝原始 Array）→ 运行期报错，已移除。
	if "灵兽管理系统" in data and typeof(data["灵兽管理系统"]) == TYPE_DICTIONARY:
		灵兽管理系统.from_dict(data["灵兽管理系统"])
	# 弟子突破系统（已拆分到breakthrough_system.gd，无状态变量）
	if "弟子突破系统" in data:
		弟子突破系统.from_dict(data["弟子突破系统"])
	# 成就系统（已拆分到achievement_system.gd）
	if "成就系统" in data:
		成就系统.from_dict(data["成就系统"])
	else:
		成就系统.成就_已达成 = data.get("成就_已达成") if "成就_已达成" in data else []
		成就系统.已领取成就奖励 = data.get("已领取成就奖励") if "已领取成就奖励" in data else []
	# S1 修复：存档恢复"成就_已达成"后须回填 成就配置[i]["已达成"]，否则后续 _复检成就 把已得成就当新达成重弹顶部弹窗
	for a in 成就配置:
		a["已达成"] = 成就系统.成就_已达成.has(a.get("achievement_id") if "achievement_id" in a else "")
	# 休闲玩法：酿道/厨道/茶道/琴道（不升SAVE_VERSION，旧档缺键→默认1级/0经验）
	酿道等级 = int(data.get("酿道等级", 1))
	酿道经验 = int(data.get("酿道经验", 0))
	厨道等级 = int(data.get("厨道等级", 1))
	厨道经验 = int(data.get("厨道经验", 0))
	茶道等级 = int(data.get("茶道等级", 1))
	茶道经验 = int(data.get("茶道经验", 0))
	琴道等级 = int(data.get("琴道等级", 1))
	琴道经验 = int(data.get("琴道经验", 0))
	灵酿列表 = data.get("灵酿列表", []) if typeof(data.get("灵酿列表", [])) == TYPE_ARRAY else []
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
	# P0修复：体力系统已移除，无需修正
	累计游戏日 = _修正负值(累计游戏日, "累计游戏日")
	# P1：周期评分存档（计数器不持久化，读档后重置；历史与年：年始快照恢复：
	历史周期评级 = data.get("历史周期评级") if "历史周期评级" in data else []
	周期评分.历史 = 历史周期评级
	周期评分.计数 = {"灵石获取": 0, "稀有道具": 0, "突破": 0, "高品质新弟子": 0, "首通": 0}
	上次结算年= data.get("上次结算年") if "上次结算年" in data else 0
	年始灵石 = data.get("年始灵石") if "年始灵石" in data else 灵石
	年始总战力= data.get("年始总战力") if "年始总战力" in data else 0
	年始宗主战力 = data.get("年始宗主战力") if "年始宗主战力" in data else 0
	年始宗主境界 = data.get("年始宗主境界") if "年始宗主境界" in data else ""
	活动上次重置日期 = data.get("活动上次重置日期") if "活动上次重置日期" in data else ""
	活动上次重置周 = data.get("活动上次重置周") if "活动上次重置周" in data else ""
	活动积分 = data.get("活动积分") if "活动积分" in data else 0
	连续参与天数 = data.get("连续参与天数") if "连续参与天数" in data else 0
	上次参与现实日 = data.get("上次参与现实日") if "上次参与现实日" in data else ""
	历史总参与天数 = data.get("历史总参与天数") if "历史总参与天数" in data else 0
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
	灵兽管理系统.灵兽库存.clear()
	灵兽管理系统.灵兽兑换队列.clear()
	for _q in data.get("lingshou_duilie") if "lingshou_duilie" in data else []:
		if _q is Dictionary:
			灵兽管理系统.灵兽兑换队列.append(_q)
	for dd in data.get("dizi") if "dizi" in data else []:
		var d := Disciple.new()
		d.from_dict(dd)
		弟子列表.append(d)
	_净化弟子与宗主同名()   # 2026-09-15：净化旧「创始人冠名」遗留（幂等，无同名则秒返）
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
		灵兽管理系统.灵兽库存.append(b)
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
	# S27 宗门任务榜：旧档无此 4 键则回落空（不升 SAVE_VERSION）
	# 类型化容器不可用 data.get() 的 Variant 直接重赋（丢类型信息，F5 期崩），一律 clear()+逐项回填
	宗门任务榜.clear()
	var 旧任务榜: Dictionary = data.get("sect_bounty") if "sect_bounty" in data else {}
	for 任务键 in 旧任务榜:
		宗门任务榜[任务键] = 旧任务榜[任务键]
	宗门任务进行中.clear()
	var 旧进行中: Dictionary = data.get("sect_bounty_run") if "sect_bounty_run" in data else {}
	for 实例键 in 旧进行中:
		宗门任务进行中[实例键] = 旧进行中[实例键]
	弟子请命列表.clear()
	for 请命项 in (data.get("sect_bounty_petition") if "sect_bounty_petition" in data else []):
		if typeof(请命项) == TYPE_DICTIONARY:
			弟子请命列表.append(请命项)
	宗门任务计数器 = int(data.get("sect_bounty_seq") if "sect_bounty_seq" in data else 0)
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
	主线已完成= data.get("main_done") if "main_done" in data else []   # PH7-BATCH1D：键在 root，原误用 wjson ⇒ 恒落空值
	方针 = data.get("policy", _方针默认).duplicate(true) if (data.get("policy") is Dictionary) else _方针默认.duplicate(true)
	# 灵兽方针（喂养/培养）：旧档缺键→默认零回归
	var bpolicy: Dictionary = data.get("beast_policy") if (data.get("beast_policy") is Dictionary) else {}
	灵兽喂养方针 = String(bpolicy.get("喂养", "普通"))
	灵兽培养方针 = String(bpolicy.get("培养", "均衡"))
	# 日常方针：旧档缺键 / 非法值 → 默认「充库」，零回归
	var dp: String = String(data.get("daily_policy", "充库"))
	日常方针 = dp if dp in ["养士", "充库", "扬名"] else "充库"
	# 突破方针（C3）：旧档缺键 / 非法值 → 默认「顺其自然」，零回归
	var bp: String = String(data.get("breakthrough_policy", "顺其自然"))
	突破方针 = bp if bp in ["稳中求进", "顺其自然", "搏一线天机"] else "顺其自然"
	待决奏折 = data.get("memorials", [])
	随机事件冷却 = data.get("randcd") if "randcd" in data else {}   # PH7-BATCH1D：键在 root，原误用 wjson
	随机事件类型冷却 = data.get("rtypecd") if "rtypecd" in data else {}   # PH7-BATCH1D：键在 root，原误用 wjson
	quest_cooldown = data.get("qcd") if "qcd" in data else {}   # PH7-BATCH1D：键在 root，原误用 wjson
	# P0 目标链：新手阶梯状态
	# PH7-BATCH1C·M2r：老档（缺 newbie_active 键）一次性「熄灯迁移」——
	#   置「激活=true + 完成列表=全部 newbie_*」⇒ 新手_有红点()(game_state.gd:9897) 恒 false（熄灯且永不亮），
	#   同时阻止「激活式补亮」。已写过键的档一律照旧取值，零外溢。
	# ★ guard 修正：save 键写在存档 root（见 :24915），原 `in wjson`（weekly 子字典）恒 false，
	#   会使**所有**存档（含新档）都误入迁移分支 ⇒ 全员熄灯，违背「仅 legacy 走新分支/零外溢」；按语义改为 `in data`。
	# 注：新手完成列表 schema = 字符串 quest_id（见 _新手_完成() :9953 新手完成列表.append(qid)）；
	#     直接赋值、绝不调用 _新手_完成()（该函数会发灵石/灵气/抽池奖励）。
	#     ID 取 config/quest_daily.csv 中 is_newbie==true 的全部行：newbie_001/002/004/005/006/007
	#     （实为 6 条，无 newbie_003）；数量 == _新手_配置().size() ⇒ 新手_全部完成()(:9892) 稳定 true。
	if "newbie_active" in data:
		新手目标链激活 = bool(data.get("newbie_active"))
		新手完成列表 = data.get("newbie_done") if "newbie_done" in data else []
	else:
		新手目标链激活 = true
		新手完成列表 = ["newbie_001", "newbie_002", "newbie_004", "newbie_005", "newbie_006", "newbie_007"]
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
	# 存档迁移后自动存盘，确保version=SAVE_VERSION写回文件，避免下次重复升级
	if _迁移后需存盘:
		save_game()
		push_warning("存档迁移完成，已自动保存v%d" % SAVE_VERSION)
	弟子变动.emit()
	call_deferred("离线结算")  # S3：读档后执行离线结算
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
	# 2026-09-16 修（PH6）：原用 da.copy(相对, 相对)。实测 Godot 4.7 的 DirAccess.copy 对相对路径解析
	#   失效（err=7 ERR_FILE_NOT_FOUND，即便 da.file_exists("save.json") 为 true）⇒ save.bak1/bak2 从未生成
	#   ⇒ 主档损坏时 _恢复最新备份() 恒空、退化为「初始建宗」丢档。改用绝对路径（与 _版本升级备份 同款思路）。
	if FileAccess.file_exists(账号目录 + "/save.bak2.json"):
		da.remove(账号目录 + "/save.bak2.json")
	if FileAccess.file_exists(账号目录 + "/save.bak1.json"):
		da.copy(账号目录 + "/save.bak1.json", 账号目录 + "/save.bak2.json")
	if FileAccess.file_exists(账号目录 + "/save.bak1.json"):
		da.remove(账号目录 + "/save.bak1.json")
	da.copy(账号目录 + "/save.json", 账号目录 + "/save.bak1.json")
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
	DirAccess.copy_absolute(账号目录 + "/save.json", 账号目录 + "/" + 目标)
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
	if 转换后.has("碎片宝箱系统.宝箱库存"):
		for 宝箱ID in 转换后["碎片宝箱系统.宝箱库存"].keys():
			var 宝箱 = 转换后["宝箱库存"][宝箱ID]
			if typeof(宝箱) == TYPE_DICTIONARY and 宝箱.has("品阶"):
				宝箱["品阶"] = 转换品质名称(宝箱["品阶"])
	# 转换碎片库存（碎片名称中包含品质名称）
	if 转换后.has("碎片宝箱系统.碎片库存"):
		for 碎片ID in 转换后["碎片宝箱系统.碎片库存"].keys():
			var 新ID: String = 碎片ID
			for 旧品质 in 品质转换表.keys():
				if 新ID.contains(旧品质):
					新ID = 新ID.replace(旧品质, 品质转换表[旧品质])
			if 新ID != 碎片ID:
				转换后["碎片宝箱系统.碎片库存"][新ID] = 转换后["碎片宝箱系统.碎片库存"][碎片ID]
				转换后["碎片宝箱系统.碎片库存"].erase(碎片ID)
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
	# v3→v4：品质名称统一（品→阶），傀儡/藏书阁/宝箱/碎片系统
	if 旧版本 < 4:
		迁移后 = 转换存档品质名称(迁移后)
		push_warning("存档迁移 v3→v4：品质名称统一（品→阶）")
	# 更新版本号
	迁移后["version"] = SAVE_VERSION
	return 迁移后
# 开始新游戏：删除存：+ 重置所有状态到初始：+ 重新初始化
# ：main.gd 调试按钮触发（OS.is_debug_build 包裹：
func new_game():

	if 当前账号id == "":
		push_warning("new_game: 当前账号id 为空，跳过")
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
	灵兽管理系统.灵兽库存.clear()
	灵兽管理系统.灵兽兑换队列.clear()
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
	# P0修复：体力系统已移除，改为每日机缘
	每日机缘 = {}
	已通关秘境.clear()
	精英每日次数.clear()
	# 护道人系统初始化
	护道人列表.clear()
	护道人计数器 = 0
	护道玉符 = 0
	护道续缘符 = 0
	功德玉牌 = 0
	气运符箓 = 0
	替死玉符 = 0
	# P1：周期评分状态复：
	上次结算年= 0
	年始灵石 = 灵石
	年始总战力= 0
	年始宗主战力 = 0
	年始宗主境界 = ""
	活动上次重置日期 = ""
	活动上次重置周 = ""
	活动积分 = 0
	连续参与天数 = 0
	上次参与现实日 = ""
	历史总参与天数 = 0
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
	成就系统.成就_已达成= []
	# S31 宣战/领地战复位（原缺失：切账号会继承上一宗门版图）
	宗门领地 = []
	# S32 战场功勋 / 宣战周期复位
	战功 = 0
	赛季序号 = 1
	宣战周已用 = 0
	本周宣战胜场 = 0
	赛季累计战功 = 0
	上次宣战周真实秒 = int(Time.get_unix_time_from_system())
	上次赛季真实秒 = int(Time.get_unix_time_from_system())
	战功道具库存 = {}
	# S33-5 阵营战役复位（切账号不继承上一宗门战绩）
	阵营战役周已用 = 0
	阵营战役战绩 = {}
	# S34 凡人王朝复位（切账号不继承上一宗门经营的王朝与差事）
	王朝系统.王朝 = _新王朝(1)
	王朝系统.凡间差事榜 = {}
	王朝系统.凡间差事进行中 = {}
	王朝系统.郡县状态 = {}
	_初始化郡县状态_S34()
	_刷新凡间差事榜_S34()
	# 批次 2：入赘名录 / 外戚索要待决 复位（切账号不继承上一宗门的入赘旧账）
	王朝系统.入赘名录 = []
	王朝系统.外戚索要待决 = {}
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
	誓约待批.clear()      # S36 心魔誓：新档复位
	万仙大誓 = {}
	誓约推进日 = 0
	丹纹系统.丹纹图谱 = {}          # S37 丹纹：新档复位
	丹方熟练度 = {}        # S39：新档复位（切号不残留）
	已领悟丹方 = {}       # S46：新档复位
	丹方领悟进度 = {}     # S46：新档复位
	_初始化领悟丹方()
	当前丹炉 = ""
	符箓熟练度 = {}        # S45-3：新档复位（切号不残留）
	当前符纸 = ""
	绘符经验值 = 0         # S45-6：新档复位（切号不残留）
	符纹系统.符纹图谱 = {}          # S45-4：新档复位（切号不残留）
	符纹系统.符纹日志 = []
	符纹系统.符纹今日纪事 = 0
	符纹系统.符纹纪事日 = 0
	丹炉列表 = []
	丹纹系统.丹纹日志 = []
	丹纹系统.丹纹今日纪事 = 0
	丹纹系统.丹纹纪事日 = 0
	# 顺手补既有漏项：S34/S35 动态状态容器此前漏 new_game 复位（切号会残留上一档）
	香火庙 = {}
	王朝系统.郡信仰 = {}
	朝报 = []
	传送阵等级 = 0
	传送阵建造中 = {}
	传送阵今日已用 = 0
	传送阵待机欠费 = false
	save_game()
	弟子变动.emit()

# ==================== S36 心魔誓（以道心立誓·天地为证）====================
# 设计三铁律：
# ① 现实日推进：每次日切只推进 1 日，离线不做批量跳变（避免「上线即违约」）
# ② 零货币产出：奖励只调真数值（道心/心境/忠诚/声望），杜绝通胀
# ③ 破誓有代价：心魔冲顶 + 激进性格 → 走火入魔 / 目标突变魔道（复用 §4.0 既有 _突变目标）

const 誓约每日请誓上限: int = 2     # 每日最多生成 2 道弟子请誓（现实日限流）

func _读表_誓约() -> Dictionary:
	if 誓约表缓存.has("oath"):
		return 誓约表缓存["oath"] as Dictionary
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/oath_config.csv", FileAccess.READ)
	if f == null:
		push_warning("oath_config.csv 缺失，誓约表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 16:
			continue
		var id: String = p[0].strip_edges()
		if id.is_empty():
			continue
		表[id] = {
			"oath_id": id, "name": p[1].strip_edges(), "kind": p[2].strip_edges(), "desc": p[3].strip_edges(),
			"need_daoxin": int(p[4]), "need_loyal": int(p[5]), "duration_days": int(p[6]),
			"cond_type": p[7].strip_edges(), "cond_value": int(p[8]),
			"buff_cult": float(p[9]), "buff_breakthrough": float(p[10]),
			"cost_demon_per_day": float(p[11]), "forbid_expedition": int(p[12]),
			"reward": p[13].strip_edges(), "punish": p[14].strip_edges(), "weight": int(p[15]),
		}
	誓约表缓存["oath"] = 表
	return 表

func _读表_万仙大誓() -> Dictionary:
	if 誓约表缓存.has("sect_oath"):
		return 誓约表缓存["sect_oath"] as Dictionary
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/oath_sect_config.csv", FileAccess.READ)
	if f == null:
		push_warning("oath_sect_config.csv 缺失，万仙大誓表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 9:
			continue
		var id: String = p[0].strip_edges()
		if id.is_empty():
			continue
		表[id] = {
			"sect_oath_id": id, "name": p[1].strip_edges(), "desc": p[2].strip_edges(),
			"duration_days": int(p[3]),
			"cond_type": p[4].strip_edges(), "cond_value": int(p[5]),
			"buff_cult": float(p[6]),
			"reward": p[7].strip_edges(), "punish": p[8].strip_edges(),
		}
	誓约表缓存["sect_oath"] = 表
	return 表

## 效果串解析："daoxin:8|xinjing:5" → {daoxin:8, xinjing:5}
func _解析誓约效果串(s: String) -> Dictionary:
	var r: Dictionary = {}
	if s.strip_edges() == "":
		return r
	for seg in s.split("|"):
		var kv = seg.split(":")
		if kv.size() < 2:
			continue
		var k: String = kv[0].strip_edges()
		if k.is_empty():
			continue
		r[k] = int(kv[1])
	return r

## 对个人应用效果（真消费方：道心→突破率/心魔抗性；心境→修炼效率/突破率；忠诚→叛离/产出）
func _应用誓约效果(d: Object, 效果: Dictionary) -> void:
	for k in 效果.keys():
		var v: int = int(效果[k])
		match str(k):
			"daoxin":
				d.道心 = clamp(int(d.道心) + v, 0, 100)
			"xinjing":
				d.心境 = clamp(int(d.心境) + v, 0, 100)
			"loyal":
				d.忠诚 = clamp(int(d.忠诚) + v, 0, 100)
			"demon":
				d.心魔值 = clamp(int(d.心魔值) + v, 0, 100)
			"prestige":
				声望 = max(0, 声望 + v)
			_:
				pass

## 对全宗应用效果（万仙大誓专用）
func _应用全宗誓约效果(效果: Dictionary) -> void:
	for k in 效果.keys():
		var v: int = int(效果[k])
		match str(k):
			"prestige":
				声望 = max(0, 声望 + v)
			"daoxin_all":
				for d in 弟子列表:
					if d != null and str(d.状态) == "在宗":
						d.道心 = clamp(int(d.道心) + v, 0, 100)
			"xinjing_all":
				for d2 in 弟子列表:
					if d2 != null and str(d2.状态) == "在宗":
						d2.心境 = clamp(int(d2.心境) + v, 0, 100)
			"loyal_all":
				for d3 in 弟子列表:
					if d3 != null and str(d3.状态) == "在宗":
						d3.忠诚 = clamp(int(d3.忠诚) + v, 0, 100)
			"demon_all":
				for d4 in 弟子列表:
					if d4 != null and str(d4.状态) == "在宗":
						d4.心魔值 = clamp(int(d4.心魔值) + v, 0, 100)
			_:
				pass

## 立誓时记录的条件基线快照（全部取自真字段，绝不手抄常量）
func _誓约快照(d: Object, 条件: String) -> int:
	match 条件:
		"realm_up":
			return Disciple.境界序.find(str(d.境界))
		"merit_gain":
			return 战功
		"contrib_gain":
			return int(d.贡献账户)
		"disciple_gain":
			return (d.徒弟列表 as Array).size()
		"heart_max":
			return int(d.心魔值)
		"loyal_keep":
			return int(d.忠诚)
		"daoxin_reach":
			return int(d.道心)
		"target_alive":
			return 1
	return 0

## 到期/即时达成判定（快照对比，离线亦正确）
func _誓约达成判定(d: Object, 誓: Dictionary) -> bool:
	var 条件: String = str(誓.get("cond_type", ""))
	var 阈值: int = int(誓.get("cond_value", 0))
	var 快照: int = int(誓.get("快照", 0))
	match 条件:
		"realm_up":
			return Disciple.境界序.find(str(d.境界)) - 快照 >= 阈值
		"merit_gain":
			return 战功 - 快照 >= 阈值
		"contrib_gain":
			return int(d.贡献账户) - 快照 >= 阈值
		"disciple_gain":
			return (d.徒弟列表 as Array).size() - 快照 >= 阈值
		"heart_max":
			return int(d.心魔值) <= 阈值
		"loyal_keep":
			if str(d.状态) in ["叛出", "陨落", "失踪"]:
				return false
			return int(d.忠诚) >= 阈值
		"daoxin_reach":
			return int(d.道心) >= 阈值
		"target_alive":
			var 目标id: int = int(誓.get("目标ID", -1))
			if 目标id < 0:
				return true
			var 目 = _取弟子(目标id)
			return (目 != null and str(目.状态) == "在宗")
	return false

## 状态类誓约是否仍可履行（护道对象已陨落 / 本人已叛出 → 即刻破誓，不等到期）
func _誓约仍可履行(d: Object, 誓: Dictionary) -> bool:
	var 条件: String = str(誓.get("cond_type", ""))
	if 条件 == "loyal_keep":
		return str(d.状态) not in ["叛出", "陨落", "失踪"]
	if 条件 == "target_alive":
		var 目标id: int = int(誓.get("目标ID", -1))
		if 目标id < 0:
			return true
		var 目 = _取弟子(目标id)
		return (目 != null and str(目.状态) == "在宗")
	return true

## 宗主为弟子立誓（护道誓须指定目标ID）
func 立心魔誓(弟子ID: int, oath_id: String, 目标ID: int = -1) -> Dictionary:
	var d = _取弟子(弟子ID)
	if d == null:
		return {"成功": false, "原因": "弟子不存在"}
	if not d.誓言.is_empty():
		return {"成功": false, "原因": "该弟子已身负誓约，不可再立"}
	if str(d.状态) != "在宗":
		return {"成功": false, "原因": "该弟子不在宗内"}
	var 配: Dictionary = _读表_誓约().get(oath_id, {}) as Dictionary
	if 配.is_empty():
		return {"成功": false, "原因": "誓约不存在"}
	var 需道心: int = int(配.get("need_daoxin", 0))
	var 需忠诚: int = int(配.get("need_loyal", 0))
	if int(d.道心) < 需道心:
		return {"成功": false, "原因": "道心不足（需%d）" % 需道心}
	if int(d.忠诚) < 需忠诚:
		return {"成功": false, "原因": "忠诚不足（需%d）" % 需忠诚}
	var 条件: String = str(配.get("cond_type", ""))
	if 条件 == "target_alive" and 目标ID < 0:
		return {"成功": false, "原因": "护道誓须指定护持对象"}
	var 期限: int = int(配.get("duration_days", 7))
	d.誓言 = {
		"oath_id": oath_id, "名称": str(配.get("name", "")),
		"起始日": _今日序号(), "期限": 期限, "剩余日": 期限,
		"cond_type": 条件, "cond_value": int(配.get("cond_value", 0)),
		"快照": _誓约快照(d, 条件),
		"buff_cult": float(配.get("buff_cult", 1.0)),
		"buff_breakthrough": float(配.get("buff_breakthrough", 0.0)),
		"demon_per_day": float(配.get("cost_demon_per_day", 0.0)),
		"forbid_expedition": int(配.get("forbid_expedition", 0)),
		"reward": str(配.get("reward", "")), "punish": str(配.get("punish", "")),
		"目标ID": 目标ID,
	}
	添加纪事("宗门", "立心魔誓", "%s指道心为誓：「%s」，限期%d日。" % [str(d.姓名), str(配.get("name", "")), 期限], 1)
	return {"成功": true, "誓约": d.誓言}

## 主动解誓 = 按破誓论处
## ★ 2026-09-14 删：`解除心魔誓(弟子ID)`。
##   它只是 `_结算誓约(d, false)`（＝按破誓结算）的一层包装，唯一调用方是弟子详情页的「解誓」钮；
##   按职责归属，心魔誓由弟子依经历自行请誓、到期/违约由 `_推进誓约_S36()` 自动结算，
##   宗主不该随手解除（誓的严肃性）⇒ 玩家入口删除后该包装即无消费方，直接移除，不留死函数。
##   如需在别处「按破誓处理」，直接调 `_结算誓约(d, false)`（`_推进誓约_S36` 已在用）。

## 苦修誓：期间禁出战（真拦截，见 expedition.开始历练）
func 誓约禁历练(弟子ID: int) -> bool:
	var d = _取弟子(弟子ID)
	if d == null or d.誓言.is_empty():
		return false
	return int(d.誓言.get("forbid_expedition", 0)) == 1

## 万仙大誓：全宗共誓修炼乘区
func 万仙誓修炼乘区() -> float:
	if 万仙大誓.is_empty():
		return 1.0
	return float(万仙大誓.get("buff_cult", 1.0))

## 每日推进（现实日口径，一次日切只推进 1 日）
func _推进誓约_S36() -> void:
	var 今日: int = _今日序号()
	if 誓约推进日 == 0:
		誓约推进日 = 今日
		return
	if 今日 == 誓约推进日:
		return
	誓约推进日 = 今日
	var 有誓弟子: Array = []
	for d in 弟子列表:
		if d != null and not d.誓言.is_empty():
			有誓弟子.append(d)
	for dd in 有誓弟子:
		# 状态类誓约（护道/不叛）：违约即刻破誓，绝不空挂等到期
		if not _誓约仍可履行(dd, dd.誓言):
			_结算誓约(dd, false)
			continue
		var 日增: float = float(dd.誓言.get("demon_per_day", 0.0))
		if 日增 > 0.0:
			dd.心魔值 = clamp(int(dd.心魔值) + int(round(日增)), 0, 100)
		elif 日增 < 0.0:
			dd.心魔值 = clamp(int(dd.心魔值) + int(round(日增)), 0, 100)
		var 剩余: int = int(dd.誓言.get("剩余日", 0)) - 1
		dd.誓言["剩余日"] = 剩余
		if _誓约达成判定(dd, dd.誓言):
			_结算誓约(dd, true)
		elif 剩余 <= 0:
			_结算誓约(dd, false)
	_推进万仙大誓_S36()
	_生成请誓_S36()

func _结算誓约(d: Object, 达成: bool) -> void:
	var 誓: Dictionary = d.誓言
	var 名: String = str(誓.get("名称", "无名之誓"))
	if 达成:
		_应用誓约效果(d, _解析誓约效果串(str(誓.get("reward", ""))))
		d.誓言史.append({"oath_id": str(誓.get("oath_id", "")), "名称": 名, "结果": "达成", "日": 累计游戏日})
		添加纪事("宗门", "誓约达成", "%s践诺「%s」，道心澄明、修为大进。" % [str(d.姓名), 名], 1)
	else:
		d.破誓次数 = int(d.破誓次数) + 1
		_应用誓约效果(d, _解析誓约效果串(str(誓.get("punish", ""))))
		d.誓言史.append({"oath_id": str(誓.get("oath_id", "")), "名称": 名, "结果": "破誓", "日": 累计游戏日})
		添加纪事("宗门", "心魔反噬", "%s违背「%s」，心魔反噬、道基动摇。" % [str(d.姓名), 名], 2)
		_破誓入魔分支_S36(d)
	d.誓言 = {}

## 破誓入魔分支：心魔冲顶 → 跌境重伤；激进性格 → 目标突变魔道
func _破誓入魔分支_S36(d: Object) -> void:
	var 心魔: int = int(d.心魔值)
	if 心魔 < 70:
		return
	var 激进: bool = str(d.性格) in ["杀伐果断", "狂傲绝世", "桀骜不羁", "锐意争先"]
	if 心魔 >= 90:
		d.层数 = max(1, int(d.层数) - 3)
		d.修炼进度 = 0.0
		d.受伤剩余 = max(int(d.受伤剩余), 30)
		if 激进:
			_突变目标(d, "魔道", "破誓反噬·心魔噬心")
		添加纪事("宗门", "走火入魔", "%s破誓反噬，心魔噬心，跌境重伤！" % str(d.姓名), 3)
	elif 激进 and randf() < 0.5:
		d.受伤剩余 = max(int(d.受伤剩余), 10)
		_突变目标(d, "魔道", "破誓反噬·道心蒙尘")

## 弟子主动请誓（每日现实日限流，登录就有新东西）
func _生成请誓_S36() -> void:
	if 誓约待批.size() >= 誓约每日请誓上限:
		return
	var 候选: Array = []
	for d in 弟子列表:
		if d == null or not d.誓言.is_empty():
			continue
		if str(d.状态) != "在宗":
			continue
		if int(d.道心) < 5:
			continue
		候选.append(d)
	if 候选.is_empty():
		return
	var 人 = 候选[randi() % 候选.size()]
	var 表: Dictionary = _读表_誓约()
	var 池: Array = []
	for k in 表.keys():
		var 配: Dictionary = 表[k] as Dictionary
		if str(配.get("cond_type", "")) == "target_alive":
			continue   # 护道誓须宗主指定对象，不进随机请誓池
		if int(人.道心) < int(配.get("need_daoxin", 0)) or int(人.忠诚) < int(配.get("need_loyal", 0)):
			continue
		var w: int = max(1, int(配.get("weight", 1)))
		for i in range(w):
			池.append(k)
	if 池.is_empty():
		return
	var 选id: String = str(池[randi() % 池.size()])
	誓约待批.append({
		"弟子ID": int(人.弟子ID), "弟子名": str(人.姓名), "oath_id": 选id,
		"名称": str((表[选id] as Dictionary).get("name", "")),
		"desc": str((表[选id] as Dictionary).get("desc", "")),
		"日": _今日序号(),
	})

func 批准请誓(序号: int) -> Dictionary:
	if 序号 < 0 or 序号 >= 誓约待批.size():
		return {"成功": false, "原因": "请誓不存在"}
	var 项: Dictionary = 誓约待批[序号] as Dictionary
	var r: Dictionary = 立心魔誓(int(项.get("弟子ID", -1)), str(项.get("oath_id", "")))
	if bool(r.get("成功", false)):
		誓约待批.remove_at(序号)
	return r

func 驳回请誓(序号: int) -> Dictionary:
	if 序号 < 0 or 序号 >= 誓约待批.size():
		return {"成功": false, "原因": "请誓不存在"}
	var 项: Dictionary = 誓约待批[序号] as Dictionary
	var d = _取弟子(int(项.get("弟子ID", -1)))
	if d != null:
		d.心境 = clamp(int(d.心境) - 2, 0, 100)
	誓约待批.remove_at(序号)
	return {"成功": true}

## 万仙大誓：宗门级共誓
func 发起万仙大誓(so_id: String) -> Dictionary:
	if not 万仙大誓.is_empty():
		return {"成功": false, "原因": "宗门已有在身大誓"}
	var 配: Dictionary = _读表_万仙大誓().get(so_id, {}) as Dictionary
	if 配.is_empty():
		return {"成功": false, "原因": "大誓不存在"}
	var 条件: String = str(配.get("cond_type", ""))
	var 期限: int = int(配.get("duration_days", 14))
	万仙大誓 = {
		"sect_oath_id": so_id, "名称": str(配.get("name", "")),
		"起始日": _今日序号(), "期限": 期限, "剩余日": 期限,
		"cond_type": 条件, "cond_value": int(配.get("cond_value", 0)),
		"快照": _全宗誓约快照(条件),
		"buff_cult": float(配.get("buff_cult", 1.0)),
		"reward": str(配.get("reward", "")), "punish": str(配.get("punish", "")),
	}
	添加纪事("宗门", "万仙大誓", "全宗心香共燃，立「%s」，限期%d日。" % [str(配.get("name", "")), 期限], 2)
	return {"成功": true}

func _全宗誓约快照(条件: String) -> int:
	match 条件:
		"sect_realm_up":
			var s: int = 0
			for d in 弟子列表:
				if d != null and str(d.状态) == "在宗":
					s += Disciple.境界序.find(str(d.境界))
			return s
		"sect_merit":
			return 战功
		"sect_member":
			return 弟子列表.size()
	return 0

func _全宗誓约达成判定() -> bool:
	var 条件: String = str(万仙大誓.get("cond_type", ""))
	var 阈值: int = int(万仙大誓.get("cond_value", 0))
	var 快照: int = int(万仙大誓.get("快照", 0))
	return (_全宗誓约快照(条件) - 快照) >= 阈值

func _推进万仙大誓_S36() -> void:
	if 万仙大誓.is_empty():
		return
	var 剩余: int = int(万仙大誓.get("剩余日", 0)) - 1
	万仙大誓["剩余日"] = 剩余
	if _全宗誓约达成判定():
		_结算万仙大誓(true)
	elif 剩余 <= 0:
		_结算万仙大誓(false)

func _结算万仙大誓(达成: bool) -> void:
	var 名: String = str(万仙大誓.get("名称", "无名大誓"))
	if 达成:
		_应用全宗誓约效果(_解析誓约效果串(str(万仙大誓.get("reward", ""))))
		添加纪事("宗门", "大誓达成", "全宗践诺「%s」，上下同心、声威大振。" % 名, 2)
	else:
		_应用全宗誓约效果(_解析誓约效果串(str(万仙大誓.get("punish", ""))))
		添加纪事("宗门", "大誓落空", "「%s」未能践诺，全宗心魔浮动。" % 名, 3)
	万仙大誓 = {}

## UI 读取：宗门誓约总览
func 誓约总览_S36() -> Dictionary:
	var 在誓: Array = []
	for d in 弟子列表:
		if d != null and not d.誓言.is_empty():
			在誓.append({
				"弟子ID": int(d.弟子ID), "姓名": str(d.姓名),
				"名称": str(d.誓言.get("名称", "")),
				"剩余日": int(d.誓言.get("剩余日", 0)), "期限": int(d.誓言.get("期限", 0)),
				"buff_cult": float(d.誓言.get("buff_cult", 1.0)),
				"demon_per_day": float(d.誓言.get("demon_per_day", 0.0)),
				"forbid": int(d.誓言.get("forbid_expedition", 0)),
			})
	return {"在誓": 在誓, "待批": 誓约待批, "万仙": 万仙大誓}
# ==================== S37 丹纹系统（丹成生纹·图谱收集） ====================
# 铁律：①丹纹只放大【既有】丹药效果与售价，不新增任何货币产出（售价倍率 clamp 2.0）
#      ②丹毒轴激活：无纹/低纹丹涨毒，高纹丹净清毒（disciple.丹毒 原本只减不增，是死轴）
#      ③所有数值走 CSV（pill_mark_config / pill_mark_tier / pill_mark_codex）
# 丹纹图谱已移至 dan_mark_system.gd
# 丹纹日志已移至 dan_mark_system.gd
# 丹纹表缓存已移至 dan_mark_system.gd
# 丹纹分档缓存已移至 dan_mark_system.gd
# 丹纹图谱档缓存已移至 dan_mark_system.gd
# 丹纹今日纪事已移至 dan_mark_system.gd
# 丹纹纪事日已移至 dan_mark_system.gd
const 丹纹每日纪事上限: int = 3     # 每日最多 3 条「丹纹天成」纪事
const 丹纹日志上限: int = 20
const 丹纹售价上限倍率: float = 2.0

func _读表_丹纹():
	return 丹纹系统._读表_丹纹()

func _读表_丹纹分档():
	return 丹纹系统._读表_丹纹分档()

func _读表_丹纹图谱档():
	return 丹纹系统._读表_丹纹图谱档()

func _丹纹归一品阶(阶: String):
	return 丹纹系统._丹纹归一品阶(阶)

func _丹纹配置(阶: String):
	return 丹纹系统._丹纹配置(阶)

func 丹纹分档(纹: int):
	return 丹纹系统.丹纹分档(纹)

func 丹纹名(纹: int):
	return 丹纹系统.丹纹名(纹)

func 掷丹纹(阶: String, 丹堂等级: int = 1):
	return 丹纹系统.掷丹纹(阶, 丹堂等级)

func 丹纹药效倍率(阶: String, 纹: int):
	return 丹纹系统.丹纹药效倍率(阶, 纹)

func 丹纹售价倍率(纹: int):
	return 丹纹系统.丹纹售价倍率(纹)

func 丹纹丹毒变化(阶: String, 纹: int):
	return 丹纹系统.丹纹丹毒变化(阶, 纹)

func 丹纹图谱总分():
	return 丹纹系统.丹纹图谱总分()
func 丹纹图谱加成():
	return 丹纹系统.丹纹图谱加成()
func 丹纹图谱成功率加成():
	return 丹纹系统.丹纹图谱成功率加成()
func 赋予丹纹(丹药, 阶: String, 丹堂等级: int = 1):
	return 丹纹系统.赋予丹纹(丹药, 阶, 丹堂等级)
func _丹纹纪事(丹名: String, 纹: int, 阶: String, 新纪录: bool):
	丹纹系统._丹纹纪事(丹名, 纹, 阶, 新纪录)
func 丹纹服用摘要(阶: String, 纹: int):
	return 丹纹系统.丹纹服用摘要(阶, 纹)
func 丹纹图谱总览():
	return 丹纹系统.丹纹图谱总览()
func 丹纹总览():
	return 丹纹系统.丹纹总览()
func _丹纹补缺():
	丹纹系统._丹纹补缺()

# ==================== S45 符箓因子网络（人/器/法/势 四源决定成率与符纹，镜像 S38/S42 范式） ====================
# 设计：炼符产出由 多维度因子 决定 成功率 与 符纹率，
#   人：符师灵根品阶/灵根类型/道途（档位）+ 心境/心魔/忠诚/境界序/政绩（连续）
#   器/法/势：符纸（符堂等级·成率）/朱砂（符堂等级·出纹）/符师在编/符箓图谱/宗门气运
# 杜绝假系统：CSV 为唯一真源，炼符成功率/符纹率真消费，符堂 UI 真展示。
var 符箓因子档缓存: Array = []
var 符箓因子线缓存: Array = []
var 符箓来源缓存: Dictionary = {}
var 符箓表缓存: Dictionary = {}   # config/item_talisman.csv -> {talisman_id: cfg}（懒加载，不入库）
var _符品级缓存: Array = []       # config/talisman_grade_config.csv（懒加载，不入库）
var _符产量缓存: Dictionary = {}   # config/talisman_yield_config.csv（懒加载，不入库）
var _符纸表缓存: Dictionary = {}   # config/talisman_paper_config.csv（懒加载，不入库）
# S45-4 符纹三表缓存（镜像丹纹 S37，懒加载，不入库）
# _符纹表缓存已移至 talisman_mark_system.gd
# _符纹分档缓存已移至 talisman_mark_system.gd
# _符纹图谱档缓存已移至 talisman_mark_system.gd
var _符等级缓存: Array = []       # S45-6 config/talisman_level_config.csv（按 level 升序，懒加载）
const 符箓个人封顶成率: float = 0.18
const 符箓个人封顶出纹: float = 0.18
const 符纹每级符堂加成: float = 0.03   # 符堂每级 +3% 逐纹概率（镜像 丹纹每级丹堂加成）
const 符纹售价上限倍率: float = 2.0    # 符纹售价加价封顶（镜像 丹纹售价上限倍率）
const 符纹日志上限: int = 20

func _读表_符箓因子档() -> Array:
	if not 符箓因子档缓存.is_empty():
		return 符箓因子档缓存
	var 表: Array = []
	for p in _S38_读表行("res://config/talisman_factor_step.csv"):
		if p.size() < 7:
			continue
		表.append({"id": str(p[0]).strip_edges(), "类别": str(p[1]).strip_edges(),
		"名称": str(p[2]).strip_edges(), "维度": str(p[3]).strip_edges(),
		"键": str(p[4]).strip_edges(), "成率": float(p[5]), "出纹": float(p[6])})
	符箓因子档缓存 = 表
	return 表

func _读表_符箓因子线() -> Array:
	if not 符箓因子线缓存.is_empty():
		return 符箓因子线缓存
	var 表: Array = []
	for p in _S38_读表行("res://config/talisman_factor_linear.csv"):
		if p.size() < 9:
			continue
		表.append({"id": str(p[0]).strip_edges(), "类别": str(p[1]).strip_edges(),
		"名称": str(p[2]).strip_edges(), "维度": str(p[3]).strip_edges(),
		"每成": float(p[4]), "每纹": float(p[5]),
		"上成": float(p[6]), "上纹": float(p[7])})
	符箓因子线缓存 = 表
	return 表

func _读表_符箓来源() -> Dictionary:
	if not 符箓来源缓存.is_empty():
		return 符箓来源缓存
	var 表: Dictionary = {}
	for p in _S38_读表行("res://config/talisman_source_config.csv"):
		if p.size() < 6:
			continue
		表[str(p[0]).strip_edges()] = {"名称": str(p[2]).strip_edges(),
		"成率": float(p[3]), "出纹": float(p[4])}
	符箓来源缓存 = 表
	return 表

## 符堂负责人 = 实际符师（无人则 null，因子只吃宗门侧）
func 符堂负责人():
	if 司职列表.has("futang"):
		return (司职列表["futang"] as Dictionary).get("负责人", null)
	return null

func _符堂政绩() -> int:
	if 司职列表.has("futang"):
		return int((司职列表["futang"] as Dictionary).get("政绩", 0))
	return 0

## 符箓因子明细：返回 {成率, 出纹, 人成, 人纹, 明细}
func 符箓因子明细(符师弟子, 符堂等级: int = 1) -> Dictionary:
	var 明细: Array = []
	var 人成: float = 0.0
	var 人纹: float = 0.0
	var 宗成: float = 0.0
	var 宗纹: float = 0.0
	var d = 符师弟子
	if d != null:
		for 行 in _读表_符箓因子档():
			var r: Dictionary = 行 as Dictionary
			var 实: String = ""
			match str(r["维度"]):
				"灵根品阶": 实 = str(d.灵根品阶)
				"灵根类型": 实 = str(d.灵根)
				"道途": 实 = str(d.道途)
				_: 实 = ""
			if 实.is_empty() or 实 != str(r["键"]):
				continue
			人成 += float(r["成率"])
			人纹 += float(r["出纹"])
			明细.append({"名称": str(r["名称"]), "类别": str(r["类别"]),
			"成率": float(r["成率"]), "出纹": float(r["出纹"])})
		for 行2 in _读表_符箓因子线():
			var r2: Dictionary = 行2 as Dictionary
			if str(r2["维度"]) == "殿阁等级":
				continue
			var 值: float = 0.0
			match str(r2["维度"]):
				"心境": 值 = float(d.心境)
				"心魔值": 值 = float(d.心魔值)
				"忠诚": 值 = float(d.忠诚)
				"境界序": 值 = float(max(0, Disciple.境界序.find(str(d.境界))))
				"政绩": 值 = float(_符堂政绩())
				_: 值 = 0.0
			if 值 == 0.0:
				continue
			var 成2: float = _S38_限幅(值 * float(r2["每成"]), float(r2["上成"]))
			var 纹2: float = _S38_限幅(值 * float(r2["每纹"]), float(r2["上纹"]))
			if abs(成2) < 0.0001 and abs(纹2) < 0.0001:
				continue
			人成 += 成2
			人纹 += 纹2
			明细.append({"名称": "%s（%s）" % [str(r2["名称"]), str(int(值))], "类别": str(r2["类别"]),
			"成率": 成2, "出纹": 纹2})
	人成 = clamp(人成, -符箓个人封顶成率, 符箓个人封顶成率)
	人纹 = clamp(人纹, -符箓个人封顶出纹, 符箓个人封顶出纹)
	var 源: Dictionary = _读表_符箓来源()
	var 级值: float = float(max(0, 符堂等级 - 1))
	# 符纸（势·成率，每符堂等级+3%，封顶15%）
	var 纸: Dictionary = 源.get("asc_fuzhi", {}) as Dictionary
	var 纸成: float = _S38_限幅(级值 * float(纸.get("成率", 0.0)), 0.15)
	if 纸成 > 0.0:
		宗成 += 纸成
		明细.append({"名称": "符纸（L%d）" % 符堂等级, "类别": "势", "成率": 纸成, "出纹": 0.0})
	# 朱砂（势·出纹，每符堂等级+3%，封顶15%）
	var 砂: Dictionary = 源.get("asc_futan", {}) as Dictionary
	var 砂纹: float = _S38_限幅(级值 * float(砂.get("出纹", 0.0)), 0.15)
	if 砂纹 > 0.0:
		宗纹 += 砂纹
		明细.append({"名称": "朱砂（L%d）" % 符堂等级, "类别": "势", "成率": 0.0, "出纹": 砂纹})
	# 符师在编（器）
	if 司职列表.has("futang"):
		var 在编: Dictionary = 源.get("asc_futang", {}) as Dictionary
		var 成: float = float(在编.get("成率", 0.0))
		if 成 > 0.0 and 符堂负责人() != null:
			宗成 += 成
			明细.append({"名称": "符师在编", "类别": "器", "成率": 成, "出纹": 0.0})
	# 符箓图谱（法·出纹，封顶8%）
	var 图: Dictionary = 源.get("asc_codex_fu", {}) as Dictionary
	var 图纹: float = float(图.get("出纹", 0.0))
	if 图纹 > 0.0:
		宗纹 += 图纹
		明细.append({"名称": "符箓图谱", "类别": "法", "成率": 0.0, "出纹": 图纹})
	# 宗门气运（势，±10%）
	var 气: float = 获取气运炼丹加成()
	if abs(气) > 0.0001:
		宗成 += 气
		宗纹 += 气
		明细.append({"名称": "宗门气运", "类别": "势", "成率": 气, "出纹": 气})
	return {"成率": 人成 + 宗成, "出纹": 人纹 + 宗纹, "人成": 人成, "人纹": 人纹, "明细": 明细}

func 符箓成率加成(符堂等级: int = 1) -> float:
	return float(符箓因子明细(符堂负责人(), 符堂等级).get("成率", 0.0))

func 符箓出纹加成(符堂等级: int = 1) -> float:
	return float(符箓因子明细(符堂负责人(), 符堂等级).get("出纹", 0.0))

## 符箓师摘要（UI 用）
func 符箓师摘要() -> String:
	var d = 符堂负责人()
	if d == null:
		return "符堂无负责人，仅宗门侧加成生效"
	return "%s（%s·%s·%s）" % [str(d.姓名), str(d.境界), str(d.灵根), str(d.道途)]

# ==================== S42 炼器因子网络（人/器/法/势 四源决定成率与高品质，沿用 S38 范式） ====================
# 设计：锻造产出（矿石路径 锻造装备 / 配方路径 执行炼器）由 多维度因子 决定 成功率 与 高品质率，
#   人：铸匠灵根品阶/灵根类型/道途（档位）+ 心境/心魔/忠诚/境界序/政绩（连续）
#   器/势：器胚（器堂等级·成率）/炉火（器堂等级·高品质）/铸匠在编/锻造图谱/宗门气运
# 杜绝假系统：CSV 为唯一真源（与 alchemy 同构），锻造成功率/高品质率真消费，器堂 UI 真展示。
var 锻造因子档缓存: Array = []
var 锻造因子线缓存: Array = []
var 锻造来源缓存: Dictionary = {}

const 锻造个人封顶成率: float = 0.18
const 锻造个人封顶高品质: float = 0.18

# 炼器品阶归一（矿石路径用 凡品/灵品…，item/forge 内部用 凡阶/灵阶…）
const 锻造品阶归一: Dictionary = {"凡品":"凡阶","灵品":"灵阶","宝品":"宝阶","王品":"王阶","圣品":"圣阶","仙品":"仙阶","道品":"道阶"}

func _读表_锻造因子档() -> Array:
	if not 锻造因子档缓存.is_empty():
		return 锻造因子档缓存
	var 表: Array = []
	for p in _S38_读表行("res://config/forge_factor_step.csv"):
		if p.size() < 7:
			continue
		表.append({"id": str(p[0]).strip_edges(), "类别": str(p[1]).strip_edges(),
		"名称": str(p[2]).strip_edges(), "维度": str(p[3]).strip_edges(),
		"键": str(p[4]).strip_edges(), "成率": float(p[5]), "高品质": float(p[6])})
	锻造因子档缓存 = 表
	return 表

func _读表_锻造因子线() -> Array:
	if not 锻造因子线缓存.is_empty():
		return 锻造因子线缓存
	var 表: Array = []
	for p in _S38_读表行("res://config/forge_factor_linear.csv"):
		if p.size() < 9:
			continue
		表.append({"id": str(p[0]).strip_edges(), "类别": str(p[1]).strip_edges(),
		"名称": str(p[2]).strip_edges(), "维度": str(p[3]).strip_edges(),
		"每成": float(p[4]), "每高": float(p[5]),
		"上成": float(p[6]), "上高": float(p[7])})
	锻造因子线缓存 = 表
	return 表

func _读表_锻造来源() -> Dictionary:
	if not 锻造来源缓存.is_empty():
		return 锻造来源缓存
	var 表: Dictionary = {}
	for p in _S38_读表行("res://config/forge_source_config.csv"):
		if p.size() < 7:
			continue
		表[str(p[0]).strip_edges()] = {"名称": str(p[2]).strip_edges(), "键": str(p[3]).strip_edges(),
		"成率": float(p[4]), "高品质": float(p[5])}
	锻造来源缓存 = 表
	return 表

## 器堂负责人 = 实际铸匠（无人则 null，因子只吃宗门侧），镜像 丹堂负责人
func 器堂负责人():
	if 司职列表.has("qitang"):
		return (司职列表["qitang"] as Dictionary).get("负责人", null)
	return null

func _器堂政绩() -> int:
	if 司职列表.has("qitang"):
		return int((司职列表["qitang"] as Dictionary).get("政绩", 0))
	return 0

## 锻造因子明细：返回 {成率, 高品质, 人成, 人高, 明细}
## 明细为 [{名称, 类别, 成率, 高品质}]，供 UI 展示「该培养谁/升什么」
func 锻造因子明细(铸匠弟子, 器堂等级: int = 1) -> Dictionary:
	var 明细: Array = []
	var 人成: float = 0.0
	var 人高: float = 0.0
	var 宗成: float = 0.0
	var 宗高: float = 0.0
	var d = 铸匠弟子
	if d != null:
		# --- 档位因子：灵根品阶 / 灵根类型 / 道途 ---
		for 行 in _读表_锻造因子档():
			var r: Dictionary = 行 as Dictionary
			var 实: String = ""
			match str(r["维度"]):
				"灵根品阶": 实 = str(d.灵根品阶)
				"灵根类型": 实 = str(d.灵根)
				"道途": 实 = str(d.道途)
				_: 实 = ""
			if 实.is_empty() or 实 != str(r["键"]):
				continue
			人成 += float(r["成率"])
			人高 += float(r["高品质"])
			明细.append({"名称": str(r["名称"]), "类别": str(r["类别"]),
				"成率": float(r["成率"]), "高品质": float(r["高品质"])})
		# --- 连续因子：心境 / 心魔 / 忠诚 / 境界 / 政绩 ---
		for 行2 in _读表_锻造因子线():
			var r2: Dictionary = 行2 as Dictionary
			var 值: float = 0.0
			match str(r2["维度"]):
				"心境": 值 = float(d.心境)
				"心魔值": 值 = float(d.心魔值)
				"忠诚": 值 = float(d.忠诚)
				"境界序": 值 = float(max(0, Disciple.境界序.find(str(d.境界))))
				"政绩": 值 = float(_器堂政绩())
				_: 值 = 0.0
			if 值 == 0.0:
				continue
			var 成2: float = _S38_限幅(值 * float(r2["每成"]), float(r2["上成"]))
			var 高2: float = _S38_限幅(值 * float(r2["每高"]), float(r2["上高"]))
			if abs(成2) < 0.0001 and abs(高2) < 0.0001:
				continue
			人成 += 成2
			人高 += 高2
			明细.append({"名称": "%s（%s）" % [str(r2["名称"]), str(int(值))], "类别": str(r2["类别"]),
				"成率": 成2, "高品质": 高2})
	人成 = clamp(人成, -锻造个人封顶成率, 锻造个人封顶成率)
	人高 = clamp(人高, -锻造个人封顶高品质, 锻造个人封顶高品质)
	# --- 宗门侧：器/法/势（不受个人封顶限制，否则升级建筑毫无意义）---
	var 源: Dictionary = _读表_锻造来源()
	var 级值: float = float(max(0, 器堂等级 - 1))
	# 器胚（势·成率，每器堂等级+3%，封顶15%）
	var 胚: Dictionary = 源.get("fsc_qipei", {}) as Dictionary
	var 胚成: float = _S38_限幅(级值 * float(胚.get("成率", 0.0)), 0.15)
	if 胚成 > 0.0:
		宗成 += 胚成
		明细.append({"名称": "器胚（L%d）" % 器堂等级, "类别": "势", "成率": 胚成, "高品质": 0.0})
	# 炉火（势·高品质，每器堂等级+3%，封顶15%）
	var 火: Dictionary = 源.get("fsc_luhuo", {}) as Dictionary
	var 火高: float = _S38_限幅(级值 * float(火.get("高品质", 0.0)), 0.15)
	if 火高 > 0.0:
		宗高 += 火高
		明细.append({"名称": "炉火（L%d）" % 器堂等级, "类别": "势", "成率": 0.0, "高品质": 火高})
	# 铸匠在编（器）
	if 司职列表.has("qitang"):
		var 在编: Dictionary = 源.get("fsc_zhujian", {}) as Dictionary
		var 成: float = float(在编.get("成率", 0.0))
		if 成 > 0.0 and 器堂负责人() != null:
			宗成 += 成
			明细.append({"名称": "铸匠在编", "类别": "器", "成率": 成, "高品质": 0.0})
	# 锻造图谱（法·高品质，按已解锁装备图纸数折算，封顶8%）
	var 图: Dictionary = 源.get("fsc_tupu", {}) as Dictionary
	var 图高上限: float = float(图.get("高品质", 0.08))
	var 图高: float = clamp(float(已解锁装备图纸列表.size()) * 0.01, 0.0, 图高上限)
	if 图高 > 0.0:
		宗高 += 图高
		明细.append({"名称": "锻造图谱·%d图" % 已解锁装备图纸列表.size(), "类别": "法", "成率": 0.0, "高品质": 图高})
	# 宗门气运（势，±10%，复用获取气运炼丹加成）
	var 气: float = 获取气运炼丹加成()
	if abs(气) > 0.0001:
		宗成 += 气
		宗高 += 气
		明细.append({"名称": "宗门气运", "类别": "势", "成率": 气, "高品质": 气})
	return {"成率": 人成 + 宗成, "高品质": 人高 + 宗高, "人成": 人成, "人高": 人高, "明细": 明细}

func 炼器成率加成(器堂等级: int = 1) -> float:
	return float(锻造因子明细(器堂负责人(), 器堂等级).get("成率", 0.0))

func 炼器高品质加成(器堂等级: int = 1) -> float:
	return float(锻造因子明细(器堂负责人(), 器堂等级).get("高品质", 0.0))

## 炼器师摘要（UI 用）
func 炼器师摘要() -> String:
	var d = 器堂负责人()
	if d == null:
		return "器堂无负责人，仅宗门侧加成生效"
	return "%s（%s·%s·%s）" % [str(d.姓名), str(d.境界), str(d.灵根), str(d.道途)]

# ==================== S38 炼丹因子网络（人/器/法/势 四源决定成率与丹纹） ====================
# 铁律：①每个因子必须来自真字段或真配置，禁恒真表达式
#      ②单人因子封顶，防某一维度独大
#      ③CSV 里写给玩家看的加成必须有真消费方（本块即为道途/傀儡/建筑的消费方）
var 炼丹因子档缓存: Array = []
var 炼丹因子线缓存: Array = []
var 炼丹来源缓存: Dictionary = {}
const 炼丹个人封顶成率: float = 0.18
const 炼丹个人封顶出纹: float = 0.18

## 通用 CSV 行读取（跳过表头，去空行）
func _S38_读表行(路径: String) -> Array:
	var 行: Array = []
	var f = FileAccess.open(路径, FileAccess.READ)
	if f == null:
		push_warning("S38 配置缺失：%s" % 路径)
		return 行
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() >= 2 and not str(p[0]).strip_edges().is_empty():
			行.append(p)
	return 行

func _读表_炼丹因子档() -> Array:
	if not 炼丹因子档缓存.is_empty():
		return 炼丹因子档缓存
	var 表: Array = []
	for p in _S38_读表行("res://config/alchemy_factor_step.csv"):
		if p.size() < 7:
			continue
		表.append({"id": str(p[0]).strip_edges(), "类别": str(p[1]).strip_edges(),
			"名称": str(p[2]).strip_edges(), "维度": str(p[3]).strip_edges(),
			"键": str(p[4]).strip_edges(), "成率": float(p[5]), "出纹": float(p[6])})
	炼丹因子档缓存 = 表
	return 表

func _读表_炼丹因子线() -> Array:
	if not 炼丹因子线缓存.is_empty():
		return 炼丹因子线缓存
	var 表: Array = []
	for p in _S38_读表行("res://config/alchemy_factor_linear.csv"):
		if p.size() < 9:
			continue
		表.append({"id": str(p[0]).strip_edges(), "类别": str(p[1]).strip_edges(),
			"名称": str(p[2]).strip_edges(), "维度": str(p[3]).strip_edges(),
			"每成": float(p[4]), "每纹": float(p[5]),
			"上成": float(p[6]), "上纹": float(p[7])})
	炼丹因子线缓存 = 表
	return 表

func _读表_炼丹来源() -> Dictionary:
	if not 炼丹来源缓存.is_empty():
		return 炼丹来源缓存
	var 表: Dictionary = {}
	for p in _S38_读表行("res://config/alchemy_source_config.csv"):
		if p.size() < 6:
			continue
		表[str(p[0]).strip_edges()] = {"名称": str(p[2]).strip_edges(),
			"成率": float(p[3]), "出纹": float(p[4])}
	炼丹来源缓存 = 表
	return 表

## 带符号限幅：cap 为正取 [0,cap]，为负取 [cap,0]
func _S38_限幅(v: float, cap: float) -> float:
	if cap >= 0.0:
		return clamp(v, 0.0, cap)
	return clamp(v, cap, 0.0)

## 丹堂负责人 = 实际炼丹师（无人则 null，因子只吃宗门侧）
func 丹堂负责人():
	if 司职列表.has("dantang"):
		return (司职列表["dantang"] as Dictionary).get("负责人", null)
	return null

func _丹堂政绩() -> int:
	if 司职列表.has("dantang"):
		return int((司职列表["dantang"] as Dictionary).get("政绩", 0))
	return 0

## 丹道傀儡加成：读 puppet.csv（类型=炼丹），按宗门已制作傀儡名称累加（救活既有死配置）
func 丹道傀儡加成() -> Dictionary:
	var 源: Dictionary = _读表_炼丹来源()
	var 上成: float = float((源.get("asc_puppet", {}) as Dictionary).get("成率", 0.17))
	var 上纹: float = float((源.get("asc_puppet", {}) as Dictionary).get("出纹", 0.06))
	var 成: float = 0.0
	var 名: Array = []
	for p in _S38_读表行("res://config/puppet.csv"):
		if p.size() < 7:
			continue
		if str(p[4]).strip_edges() != "炼丹":
			continue
		var 傀名: String = str(p[1]).strip_edges()
		var n: int = 0
		for 傀 in 傀儡系统.傀儡列表:
			if str((傀 as Dictionary).get("名称", "")) == 傀名:
				n += 1
		if n <= 0:
			continue
		var v: float = float(str(p[6]).strip_edges().replace("%", "")) / 100.0
		成 += v * float(n)
		名.append("%s×%d" % [傀名, n])
	成 = clamp(成, 0.0, 上成)
	return {"成率": 成, "出纹": clamp(成 * 0.35, 0.0, 上纹), "名": "、".join(名)}

## 炼丹因子明细：返回 {成率, 出纹, 人成, 人纹, 明细}
## 明细为 [{名称, 类别, 成率, 出纹}]，供 UI 展示「该培养谁」
func 炼丹因子明细(炼丹师, 丹堂等级: int = 1) -> Dictionary:
	var 明细: Array = []
	var 人成: float = 0.0
	var 人纹: float = 0.0
	var 宗成: float = 0.0
	var 宗纹: float = 0.0
	var d = 炼丹师
	if d != null:
		# --- 档位因子：灵根品阶 / 灵根类型 / 道途 ---
		for 行 in _读表_炼丹因子档():
			var r: Dictionary = 行 as Dictionary
			var 实: String = ""
			match str(r["维度"]):
				"灵根品阶": 实 = str(d.灵根品阶)
				"灵根类型": 实 = str(d.灵根)
				"道途": 实 = str(d.道途)
				_: 实 = ""
			if 实.is_empty() or 实 != str(r["键"]):
				continue
			人成 += float(r["成率"])
			人纹 += float(r["出纹"])
			明细.append({"名称": str(r["名称"]), "类别": str(r["类别"]),
				"成率": float(r["成率"]), "出纹": float(r["出纹"])})
		# --- 连续因子：心境 / 心魔 / 忠诚 / 境界 / 政绩（殿阁等级属宗门侧，见下） ---
		for 行2 in _读表_炼丹因子线():
			var r2: Dictionary = 行2 as Dictionary
			if str(r2["维度"]) == "殿阁等级":
				continue
			var 值: float = 0.0
			match str(r2["维度"]):
				"心境": 值 = float(d.心境)
				"心魔值": 值 = float(d.心魔值)
				"忠诚": 值 = float(d.忠诚)
				"境界序": 值 = float(max(0, Disciple.境界序.find(str(d.境界))))
				"政绩": 值 = float(_丹堂政绩())
				_: 值 = 0.0
			if 值 == 0.0:
				continue
			var 成2: float = _S38_限幅(值 * float(r2["每成"]), float(r2["上成"]))
			var 纹2: float = _S38_限幅(值 * float(r2["每纹"]), float(r2["上纹"]))
			if abs(成2) < 0.0001 and abs(纹2) < 0.0001:
				continue
			人成 += 成2
			人纹 += 纹2
			明细.append({"名称": "%s（%s）" % [str(r2["名称"]), str(int(值))], "类别": str(r2["类别"]),
				"成率": 成2, "出纹": 纹2})
	人成 = clamp(人成, -炼丹个人封顶成率, 炼丹个人封顶成率)
	人纹 = clamp(人纹, -炼丹个人封顶出纹, 炼丹个人封顶出纹)
	# --- 宗门侧：器/法/势（不受个人封顶限制，否则升级建筑毫无意义） ---
	var 源2: Dictionary = _读表_炼丹来源()
	# 丹堂等级（器）：随等级线性增长，是升级丹堂的核心回报
	for 行3 in _读表_炼丹因子线():
		var r3: Dictionary = 行3 as Dictionary
		if str(r3["维度"]) != "殿阁等级":
			continue
		var 级值: float = float(max(0, 丹堂等级 - 1))
		var 成3: float = _S38_限幅(级值 * float(r3["每成"]), float(r3["上成"]))
		var 纹3: float = _S38_限幅(级值 * float(r3["每纹"]), float(r3["上纹"]))
		宗成 += 成3
		宗纹 += 纹3
		if 级值 > 0.0:
			明细.append({"名称": "%s（L%d）" % [str(r3["名称"]), 丹堂等级], "类别": "器",
				"成率": 成3, "出纹": 纹3})
	if 司职列表.has("dantang"):
		var s成: float = float((源2.get("asc_dantang", {}) as Dictionary).get("成率", 0.0))
		if s成 > 0.0:
			宗成 += s成
			明细.append({"名称": "丹堂在编", "类别": "器", "成率": s成, "出纹": 0.0})
	var 傀: Dictionary = 丹道傀儡加成()
	if float(傀["成率"]) > 0.0:
		宗成 += float(傀["成率"])
		宗纹 += float(傀["出纹"])
		明细.append({"名称": "丹道傀儡·%s" % str(傀["名"]), "类别": "器",
			"成率": float(傀["成率"]), "出纹": float(傀["出纹"])})
	var 图: Dictionary = 丹纹图谱加成()
	var 图成: float = float(图.get("success", 0.0)) / 100.0
	var 图纹: float = float(图.get("rate", 0.0))
	if 图成 > 0.0 or 图纹 > 0.0:
		宗成 += 图成
		宗纹 += 图纹
		明细.append({"名称": "丹纹图谱·%s" % str(图.get("name", "")), "类别": "法",
			"成率": 图成, "出纹": 图纹})
	var 气: float = 获取气运炼丹加成()
	if abs(气) > 0.0001:
		宗成 += 气
		宗纹 += 气
		明细.append({"名称": "宗门气运", "类别": "势", "成率": 气, "出纹": 气})
	# === S40 灵植「料」因子（宗门侧·势：库房内灵材平均年份越高，丹成/丹纹越佳）===
	var 均年: int = 宗门灵植平均年份()
	if 均年 > 0:
		var 料: Dictionary = 灵植年份炼丹加成(均年)
		if abs(float(料.get("成率", 0.0))) > 0.0001 or abs(float(料.get("出纹", 0.0))) > 0.0001:
			宗成 += float(料.get("成率", 0.0))
			宗纹 += float(料.get("出纹", 0.0))
			明细.append({"名称": "灵植·均%d年" % 均年, "类别": "料", "成率": float(料.get("成率", 0.0)), "出纹": float(料.get("出纹", 0.0))})
	return {"成率": 人成 + 宗成, "出纹": 人纹 + 宗纹, "人成": 人成, "人纹": 人纹, "明细": 明细}

# ==================== S40 灵植年份（料因子 + 坊市价值倍率） ====================
# 设计：灵田产出 / 历练掉落灵材带「年份」；年份档（herb_age_config.csv）映射出
#   · 炼丹「料」因子加成（宗门灵植平均年份）→ 接 S38 因子网络，喂 掷丹纹/执行炼丹/炼制丹药
#   · 坊市/商队售价价值倍率（_品阶售价 消费）
# 杜绝「加了字段没人用」的假系统：两条消费链均为真接。
var _灵植年份档缓存: Array = []

func _读表_灵植年份档() -> Array:
	if not _灵植年份档缓存.is_empty():
		return _灵植年份档缓存
	var 表: Array = []
	for p in _S38_读表行("res://config/herb_age_config.csv"):
		if p.size() < 6:
			continue
		表.append({"档名": str(p[0]).strip_edges(),
			"下限年份": int(p[1]), "上限年份": int(p[2]),
			"价值系数": float(p[3]), "成率加成": float(p[4]), "出纹加成": float(p[5])})
	_灵植年份档缓存 = 表
	return 表

## 命中年份档（档按 下限年份 升序；最后一档 上限年份=-1 为开放上限）
func 灵植年份档(年份: int) -> Dictionary:
	for r in _读表_灵植年份档():
		var lo: int = int(r.get("下限年份", 0))
		var hi: int = int(r.get("上限年份", -1))
		if 年份 >= lo and (hi < 0 or 年份 <= hi):
			return r
	return {}

## 坊市/商队售价倍率（按年份档，_品阶售价 消费；普通材料年份=0 → ×1.0 零影响）
func 灵植年份价值系数(年份: int) -> float:
	var r: Dictionary = 灵植年份档(年份)
	if r.is_empty():
		return 1.0
	return float(r.get("价值系数", 1.0))

## 炼丹「料」因子加成（按宗门灵植平均年份档）
func 灵植年份炼丹加成(年份: int) -> Dictionary:
	var r: Dictionary = 灵植年份档(年份)
	if r.is_empty():
		return {"成率": 0.0, "出纹": 0.0}
	return {"成率": float(r.get("成率加成", 0.0)), "出纹": float(r.get("出纹加成", 0.0))}

## 宗门库房内灵材平均年份（仅计 ling_cai 且 年份>0，避免年份=0 材料稀释均值）
func 宗门灵植平均年份() -> int:
	var 总: int = 0
	var n: int = 0
	if 宗门库房 == null:
		return 0
	for it in 宗门库房:
		if it is Object and str(it.get("类别") if "类别" in it else "") == "ling_cai":
			var y: int = int(it.get("年份") if "年份" in it else 0)
			if y > 0:
				总 += y
				n += 1
	if n <= 0:
		return 0
	return int(round(float(总) / float(n)))

func 炼丹成率加成(丹堂等级: int = 1) -> float:
	return float(炼丹因子明细(丹堂负责人(), 丹堂等级).get("成率", 0.0))

func 炼丹出纹加成(丹堂等级: int = 1) -> float:
	return float(炼丹因子明细(丹堂负责人(), 丹堂等级).get("出纹", 0.0))

## 炼丹师摘要（UI 用）：无人则提示
func 炼丹师摘要() -> String:
	var d = 丹堂负责人()
	if d == null:
		return "丹堂无负责人，仅宗门侧加成生效"
	return "%s（%s·%s·%s）" % [str(d.姓名), str(d.境界), str(d.灵根), str(d.道途)]


# ==================== S39 丹药品级与产出体系 ====================
# 设计：产物 = 品阶（丹方决定）× 品级（下/中/上/极品，掷）× 丹纹（0..上限，逐纹递进）
# 产出数量 = 品阶基准 + 境界压制 + 丹方熟练度 + 丹炉产量，再乘品级数量系数
# 老大定调：高阶炼丹师炼低阶丹 → 量大；同一丹方炼得多 → 熟练加成；丹炉 → 成率/出纹/产量/品级
var 丹方熟练度: Dictionary = {}      # recipe_id -> 累计成功炉数（熟练度唯一真源）
var 已领悟丹方: Dictionary = {}       # S46 领悟丹方：recipe_id -> 领悟时间（0=未领悟）
var 丹方领悟进度: Dictionary = {}     # S46 领悟丹方：recipe_id -> 累计炼制次数（用于反推领悟）
var 当前丹炉: String = ""            # 已装备丹炉ID（空=无炉）
var 符箓熟练度: Dictionary = {}      # talisman_id -> 累计成功次数（熟练度/经验唯一真源，S45-3/6）
var 当前符纸: String = ""            # 已装备符纸ID（空=无纸加成，S45-3/8）
var 绘符经验值: int = 0              # S45-6 绘符经验值（宗门级，用于提升绘符等级；旧档默认0）
# S45-4 符纹图谱（镜像 S37 丹纹图谱）：符名 -> 该符历史最高纹数（0 不入谱）
# 符纹图谱已移至 talisman_mark_system.gd
# 符纹日志已移至 talisman_mark_system.gd
# 符纹今日纪事已移至 talisman_mark_system.gd
# 符纹纪事日已移至 talisman_mark_system.gd
var 丹炉列表: Array = []             # 已购得的丹炉ID列表
var _丹方表缓存: Dictionary = {}
var _丹品级缓存: Array = []
var _丹产量缓存: Dictionary = {}
var _丹炉表缓存: Dictionary = {}

func _读表_丹方() -> Dictionary:
	if not _丹方表缓存.is_empty():
		return _丹方表缓存
	for p in _S38_读表行("res://config/pill_recipe_config.csv"):
		if p.size() < 15:
			continue
		_丹方表缓存[str(p[0]).strip_edges()] = {
			"id": str(p[0]).strip_edges(), "名称": str(p[1]).strip_edges(),
			"品阶": str(p[2]).strip_edges(), "需求境界": str(p[3]).strip_edges(),
			"需求境界序": int(p[4]), "材料描述": str(p[5]).strip_edges(),
			"cost_herb": int(p[6]), "cost_ore": int(p[7]), "cost_jing": int(p[8]),
			"cost_stone": int(p[9]), "cost_qi": int(p[10]),
			"基础成功率": float(p[11]) / 100.0, "产出丹名": str(p[12]).strip_edges(),
			"描述": str(p[13]).strip_edges(), "来源": str(p[14]).strip_edges()}
	return _丹方表缓存

func _读表_丹品级() -> Array:
	if not _丹品级缓存.is_empty():
		return _丹品级缓存
	for p in _S38_读表行("res://config/pill_grade_config.csv"):
		if p.size() < 9:
			continue
		_丹品级缓存.append({
			"grade_id": str(p[0]).strip_edges(), "grade_name": str(p[1]).strip_edges(),
			"effect_scale": float(p[2]), "price_scale": float(p[3]), "toxin_scale": float(p[4]),
			"mark_cap_delta": int(p[5]), "mark_rate_scale": float(p[6]),
			"yield_scale": float(p[7]), "weight": float(p[8])})
	return _丹品级缓存

func _读表_丹产量() -> Dictionary:
	if not _丹产量缓存.is_empty():
		return _丹产量缓存
	for p in _S38_读表行("res://config/pill_yield_config.csv"):
		if p.size() < 5:
			continue
		_丹产量缓存[str(p[0]).strip_edges()] = {
			"base_yield": float(p[1]), "per_realm_surplus": float(p[2]),
			"per_prof_level": float(p[3]), "furnace_scale": float(p[4])}
	return _丹产量缓存

func _读表_丹炉() -> Dictionary:
	if not _丹炉表缓存.is_empty():
		return _丹炉表缓存
	for p in _S38_读表行("res://config/pill_furnace_config.csv"):
		if p.size() < 12:
			continue
		_丹炉表缓存[str(p[0]).strip_edges()] = {
			"id": str(p[0]).strip_edges(), "名称": str(p[1]).strip_edges(), "品质": str(p[2]).strip_edges(),
			"成率": float(p[3]), "出纹": float(p[4]), "产量": float(p[5]), "品级分": float(p[6]),
			"减毒率": float(p[7]), "省材率": float(p[8]), "价灵石": int(p[9]), "价灵晶": int(p[10]),
			"描述": str(p[11]).strip_edges()}
	return _丹炉表缓存

func 丹方配置(rid: String) -> Dictionary:
	var t: Dictionary = _读表_丹方()
	if t.has(rid):
		return (t[rid] as Dictionary).duplicate()
	return {}

func 全部丹方() -> Array:
	return _读表_丹方().values()

## ==================== S45-2 符箓配置读取（镜像 丹方配置 / 炼制丹方） ====================
func _读表_符箓() -> Dictionary:
	if not 符箓表缓存.is_empty():
		return 符箓表缓存
	for p in _S38_读表行("res://config/item_talisman.csv"):
		if p.size() < 11:
			continue
		符箓表缓存[str(p[0]).strip_edges()] = {
			"id": str(p[0]).strip_edges(), "名称": str(p[1]).strip_edges(),
			"grade": str(p[2]).strip_edges(), "sub_grade": str(p[3]).strip_edges(),
			"talisman_type": str(p[4]).strip_edges(), "use_effect": str(p[5]).strip_edges(),
			"effect_value": str(p[6]).strip_edges(), "use_limit": int(p[7]),
			"base_rate": float(p[8]), "craft_material": str(p[9]).strip_edges(),
			"sell_price": int(p[10])}
	return 符箓表缓存

func 符箓配置(rid: String) -> Dictionary:
	var t: Dictionary = _读表_符箓()
	if t.has(rid):
		return (t[rid] as Dictionary).duplicate()
	return {}

func 符箓配置按名(名: String) -> Dictionary:
	var t: Dictionary = _读表_符箓()
	for k in t.keys():
		var row: Dictionary = t[k] as Dictionary
		if str(row.get("名称", "")) == 名:
			return row.duplicate()
	return {}

func _解析符箓效果值(cfg: Dictionary) -> float:
	if cfg.is_empty():
		return 0.0
	var raw: String = str(cfg.get("effect_value", "0"))
	raw = raw.strip_edges().replace("%", "")
	if raw == "":
		return 0.0
	return float(raw) / 100.0

func _符类型转增益(类: String, 效: float) -> Dictionary:
	match 类:
		"攻击类":
			return {"攻击加成": 效, "持续回合": 5}
		"防御类":
			return {"防御加成": 效, "持续回合": 5}
		"辅助类":
			return {"攻击加成": 效 * 0.5, "防御加成": 效 * 0.5, "生命加成": 效 * 0.5, "持续回合": 5}
		"控制类":
			# 控制类符箓：定身/昏睡/冰封，敌人被控后输出环境更好，转化为伤害加成+闪避
			return {"攻击加成": 效 * 0.8, "防御加成": 效 * 0.3, "持续回合": 5}
		"特殊类":
			# 特殊类符箓：传送/隐身/破邪，转化为综合增益+生命加成
			return {"攻击加成": 效 * 0.4, "防御加成": 效 * 0.4, "生命加成": 效 * 0.4, "持续回合": 5}
		_:
			return {"生命加成": 0.10, "防御加成": 0.10, "持续回合": 5}

## S45-7 符箓战前增益（战斗主动消费方接入；零触碰 72 战斗断言，仅追加至攻方增益）
## 出战队伍 = 数组的数组（每队弟子）；每名弟子最多消耗 3 张符箓（攻击/防御/辅助/控制/特殊 五类路由）
func 符箓战前增益(出战队伍: Array) -> Array:
	var 增益列表: Array = []
	if 宗门库房.is_empty():
		return 增益列表
	# 品阶阈值：只自动消耗凡品/灵品低阶符箓，宝品及以上为珍贵符箓需宗主手动分配
	var 自动品阶: Array = ["凡品", "灵品"]
	var 候选: Array = []
	for i in range(宗门库房.size()):
		var it = 宗门库房[i]
		if it != null and (it is Item) and it.类别 == "fu_lu" and str(it.品阶) in 自动品阶:
			候选.append(i)
	# 按品阶升序+符纹升序：先消耗最低阶、符纹最低的符箓
	var 品阶序: Dictionary = {"凡品": 1, "灵品": 2, "宝品": 3, "王品": 4, "道品": 5, "圣品": 6, "仙品": 7}
	候选.sort_custom(func(a, b):
		var 阶a = 品阶序.get(str(宗门库房[a].品阶), 99)
		var 阶b = 品阶序.get(str(宗门库房[b].品阶), 99)
		if 阶a != 阶b:
			return 阶a < 阶b
		return float(宗门库房[a].符纹) < float(宗门库房[b].符纹))
	var 弟子数: int = 0
	for 队 in 出战队伍:
		for d in 队:
			if d is Disciple:
				弟子数 += 1
	var 可消耗: int = min(候选.size(), 弟子数 * 3)
	var 已消耗: Array = []
	for k in range(可消耗):
		var it = 宗门库房[候选[k]]
		var cfg: Dictionary = 符箓配置按名(it.名称)
		var 类: String = it.符类型
		var 效: float = _解析符箓效果值(cfg)
		增益列表.append(_符类型转增益(类, 效))
		已消耗.append(候选[k])
	已消耗.sort()
	已消耗.reverse()
	for idx in 已消耗:
		宗门库房.remove_at(idx)
	return 增益列表

## S45-7 通用符箓消耗（宗门防御/历练接入；消耗上限张数，返回综合战力增益系数）
func 符箓消耗加成(上限张数: int) -> float:
	var 总: float = 0.0
	if 宗门库房.is_empty() or 上限张数 <= 0:
		return 0.0
	# 品阶阈值：只自动消耗凡品/灵品低阶符箓
	var 自动品阶: Array = ["凡品", "灵品"]
	var 候选: Array = []
	for i in range(宗门库房.size()):
		var it = 宗门库房[i]
		if it != null and (it is Item) and it.类别 == "fu_lu" and str(it.品阶) in 自动品阶:
			候选.append(i)
	# 按品阶升序+符纹升序：先消耗最低阶
	var 品阶序: Dictionary = {"凡品": 1, "灵品": 2, "宝品": 3, "王品": 4, "道品": 5, "圣品": 6, "仙品": 7}
	候选.sort_custom(func(a, b):
		var 阶a = 品阶序.get(str(宗门库房[a].品阶), 99)
		var 阶b = 品阶序.get(str(宗门库房[b].品阶), 99)
		if 阶a != 阶b:
			return 阶a < 阶b
		return float(宗门库房[a].符纹) < float(宗门库房[b].符纹))
	var n: int = min(候选.size(), 上限张数)
	var 已: Array = []
	for k in range(n):
		var it = 宗门库房[候选[k]]
		var cfg: Dictionary = 符箓配置按名(it.名称)
		var 效: float = _解析符箓效果值(cfg)
		match it.符类型:
			"攻击类": 总 += 效
			"防御类": 总 += 效
			"辅助类": 总 += 效 * 0.5
			"控制类": 总 += 效 * 0.6
			_: 总 += 0.10
		已.append(候选[k])
	已.sort()
	已.reverse()
	for idx in 已:
		宗门库房.remove_at(idx)
	return 总

## ==================== S45-3 符箓产出体系（镜像 S39 丹药品级与产出） ====================
func _读表_符品级() -> Array:
	if not _符品级缓存.is_empty():
		return _符品级缓存
	for p in _S38_读表行("res://config/talisman_grade_config.csv"):
		if p.size() < 9:
			continue
		_符品级缓存.append({
			"grade_id": str(p[0]).strip_edges(), "grade_name": str(p[1]).strip_edges(),
			"effect_scale": float(p[2]), "price_scale": float(p[3]), "toxin_scale": float(p[4]),
			"mark_cap_delta": int(p[5]), "mark_rate_scale": float(p[6]),
			"yield_scale": float(p[7]), "weight": float(p[8])})
	return _符品级缓存

func _读表_符产量() -> Dictionary:
	if not _符产量缓存.is_empty():
		return _符产量缓存
	for p in _S38_读表行("res://config/talisman_yield_config.csv"):
		if p.size() < 5:
			continue
		_符产量缓存[str(p[0]).strip_edges()] = {
			"base_yield": float(p[1]), "per_realm_surplus": float(p[2]),
			"per_prof_level": float(p[3]), "paper_scale": float(p[4])}
	return _符产量缓存

func _读表_符纸() -> Dictionary:
	if not _符纸表缓存.is_empty():
		return _符纸表缓存
	for p in _S38_读表行("res://config/talisman_paper_config.csv"):
		if p.size() < 12:
			continue
		_符纸表缓存[str(p[0]).strip_edges()] = {
			"id": str(p[0]).strip_edges(), "名称": str(p[1]).strip_edges(), "品质": str(p[2]).strip_edges(),
			"成率": float(p[3]), "出纹": float(p[4]), "产量": float(p[5]), "品级分": float(p[6]),
			"减毒率": float(p[7]), "省材率": float(p[8]), "价灵石": int(p[9]), "价灵晶": int(p[10]),
			"描述": str(p[11]).strip_edges()}
	return _符纸表缓存

func 符品级配置(名: String) -> Dictionary:
	for g in _读表_符品级():
		if str(g["grade_name"]) == 名:
			return g as Dictionary
	return {"grade_id": "tg_mid", "grade_name": "中品", "effect_scale": 1.0, "price_scale": 1.0,
		"toxin_scale": 1.0, "mark_cap_delta": 0, "mark_rate_scale": 1.0, "yield_scale": 1.0, "weight": 32.0}

## 掷符品级：分越高越向上品/极品倾斜（分来自符堂等级+因子成率+熟练分+符纸分+压制分）
## 注：修正原 掷丹品级 仅对 极品 执行 权重.append 的潜在 bug——此处每个品级都 append，否则 range(表.size()) 越界
func 掷符品级(分: float) -> Dictionary:
	var 表: Array = _读表_符品级()
	if 表.is_empty():
		return 符品级配置("中品")
	var 权重: Array = []
	var 总: float = 0.0
	for g in 表:
		var w: float = float((g as Dictionary).get("weight", 1.0))
		var gid: String = str((g as Dictionary).get("grade_id", ""))
		if gid == "tg_low":
			w *= max(0.30, 1.0 - 分 / 60.0)
		elif gid == "tg_high":
			w *= 0.60 + 分 / 80.0
		elif gid == "tg_top":
			w *= 0.15 + 分 / 120.0
		权重.append(w)
		总 += w
	if 总 <= 0.0:
		return 符品级配置("中品")
	var r: float = randf() * 总
	var acc: float = 0.0
	for i in range(表.size()):
		acc += float(权重[i])
		if r <= acc:
			return 表[i] as Dictionary
	return 表[表.size() - 1] as Dictionary

## 符箓熟练：成功次数 -> 等级 0-5（0/5/15/30/60/100）
func 符箓熟练等级(rid: String) -> int:
	var n: int = int(符箓熟练度.get(rid, 0))
	if n >= 100: return 5
	elif n >= 60: return 4
	elif n >= 30: return 3
	elif n >= 15: return 2
	elif n >= 5: return 1
	return 0

func 符箓熟练加成(rid: String) -> Dictionary:
	var lv: int = 符箓熟练等级(rid)
	return {"等级": lv, "次数": int(符箓熟练度.get(rid, 0)),
		"成率": float(lv) * 0.012, "出纹": float(lv) * 0.010,
		"品级分": float(lv) * 2.0, "产量": float(lv)}

## 符箓需求境界序（按 grade 映射：凡品→练气，道品→渡劫）
func 符箓需求境界序(阶: String) -> int:
	var 表: Dictionary = {"凡品": 0, "灵品": 1, "宝品": 2, "王品": 3, "圣品": 4, "仙品": 5, "道品": 6}
	return int(表.get(阶, 0))

## 符师压制：自身境界序 - 符箓需求境界序（正=降维绘符，量产）
func 符师压制(符师, 需求境界序: int) -> int:
	if 符师 == null:
		return 0
	var i: int = Disciple.境界序.find(str(符师.境界))
	if i < 0:
		return 0
	return i - 需求境界序

## 符纸配置（镜像 丹炉配置）
func 符纸配置(pid: String) -> Dictionary:
	if pid.is_empty():
		return {}
	var t: Dictionary = _读表_符纸()
	if t.has(pid):
		return (t[pid] as Dictionary).duplicate()
	return {}

func 当前符纸配置() -> Dictionary:
	return 符纸配置(当前符纸)

## 符箓一炉产量：数量 = (品阶基准 + 压制×系数 + 熟练×系数 + 符纸产量) × 品级数量系数
func 符箓产出数量(rid: String, 符师, 符堂等级: int, 品级: String) -> int:
	var cfg = 符箓配置(rid)
	if cfg.is_empty():
		return 1
	var 阶: String = str(cfg.get("grade", "凡品"))
	var 产: Dictionary = _读表_符产量().get(阶, {"base_yield": 1.0, "per_realm_surplus": 0.0, "per_prof_level": 0.0, "paper_scale": 1.0})
	var 压制: int = 符师压制(符师, 符箓需求境界序(阶))
	var 熟练: Dictionary = 符箓熟练加成(rid)
	var 纸: Dictionary = 当前符纸配置()
	var 数量浮: float = float(产.get("base_yield", 1.0))
	数量浮 += float(压制) * float(产.get("per_realm_surplus", 0.0))
	数量浮 += float(熟练.get("产量", 0.0)) * float(产.get("per_prof_level", 0.0))
	数量浮 += float(纸.get("产量", 0.0)) * float(产.get("paper_scale", 1.0))
	数量浮 *= float(符品级配置(品级).get("yield_scale", 1.0))
	return max(1, int(round(数量浮)))

# ============ S45-4 符纹系统（镜像 S37 丹纹；CSV 为唯一真源） ============

# ===== 符纹系统（已拆分到talisman_mark_system.gd，此处为转发函数）=====
func _读表_符纹():
	return 符纹系统._读表_符纹()
func _读表_符纹分档():
	return 符纹系统._读表_符纹分档()
func _读表_符纹图谱档():
	return 符纹系统._读表_符纹图谱档()
func _符纹归一品阶(阶: String):
	return 符纹系统._符纹归一品阶(阶)
func _符纹配置(阶: String):
	return 符纹系统._符纹配置(阶)
func 符纹分档(纹: int):
	return 符纹系统.符纹分档(纹)
func 符纹名(纹: int):
	return 符纹系统.符纹名(纹)
func 符纹上限(品阶: String, 品级: String):
	return 符纹系统.符纹上限(品阶, 品级)
func 掷符纹(阶: String, 符堂等级: int = 1, 额外出纹: float = 0.0, 级系数: float = 1.0, 上限: int = -1):
	return 符纹系统.掷符纹(阶, 符堂等级, 额外出纹, 级系数, 上限)
func 符纹效力倍率(阶: String, 纹: int):
	return 符纹系统.符纹效力倍率(阶, 纹)
func 符纹售价倍率(阶: String, 纹: int):
	return 符纹系统.符纹售价倍率(阶, 纹)
func 符纹图谱总分():
	return 符纹系统.符纹图谱总分()
func 符纹图谱加成():
	return 符纹系统.符纹图谱加成()
func 符纹图谱成功率加成():
	return 符纹系统.符纹图谱成功率加成()
func 符纹图谱出纹加成():
	return 符纹系统.符纹图谱出纹加成()
func 符纹图谱入谱(符箓, 纹: int, 阶: String):
	符纹系统.符纹图谱入谱(符箓, 纹, 阶)
func 符纹总览():
	return 符纹系统.符纹总览()
func 符纹校验():
	符纹系统.符纹校验()

# ============ S45-6 绘符经验/等级（镜像炼器 forge.gd；CSV 为唯一真源） ============
func _读表_符等级() -> Array:
	if not _符等级缓存.is_empty():
		return _符等级缓存
	var 表: Array = []
	var f = FileAccess.open("res://config/talisman_level_config.csv", FileAccess.READ)
	if f == null:
		push_warning("talisman_level_config.csv 缺失，绘符等级表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 4:
			continue
		var lv: String = p[0].strip_edges()
		if lv.is_empty():
			continue
		表.append({"level": int(p[0]), "need_exp": int(p[1]),
			"success_bonus": float(p[2]), "quality_bonus": float(p[3]),
			"desc": p[4].strip_edges() if p.size() > 4 else ""})
	表.sort_custom(func(a, b): return int(a["level"]) < int(b["level"]))
	_符等级缓存 = 表
	return 表

func 绘符等级表() -> Array:
	return _读表_符等级()

## 按经验取绘符等级（表按 level 升序，取最后一个 need_exp <= 经验 的档）
func 绘符等级按经验(经验值: int) -> int:
	var 表: Array = _读表_符等级()
	var 等级: int = 1
	for t in 表:
		var d: Dictionary = t as Dictionary
		if 经验值 >= int(d.get("need_exp", 0)):
			等级 = int(d.get("level", 1))
	return 等级

## 按经验取绘符加成 {等级, 成功率加成(百分点), 高品质加成(品级分用)}
func 绘符加成按经验(经验值: int) -> Dictionary:
	var 表: Array = _读表_符等级()
	var 等级: int = 绘符等级按经验(经验值)
	for t in 表:
		var d: Dictionary = t as Dictionary
		if int(d.get("level", 1)) == 等级:
			return {"等级": 等级, "成功率加成": float(d.get("success_bonus", 0.0)),
				"高品质加成": float(d.get("quality_bonus", 0.0))}
	return {"等级": 1, "成功率加成": 0.0, "高品质加成": 0.0}

## 计算单次绘符获得经验（按品阶；失败得一半；镜像 ForgeSystem.计算炼器经验）
func 计算绘符经验(品阶: String, 成功: bool) -> int:
	var 基础经验: Dictionary = {"凡阶": 10, "灵阶": 20, "宝阶": 40, "王阶": 80,
		"圣阶": 120, "仙阶": 200, "道阶": 300}
	var 经验: int = int(基础经验.get(品阶, 10))
	if not 成功:
		经验 = int(经验 * 0.5)
	return 经验

## 当前绘符等级（宗门级）
func 获取绘符等级() -> int:
	return TalismanSystem.获取绘符等级(绘符经验值)

## 当前绘符加成
func 获取绘符加成() -> Dictionary:
	return TalismanSystem.获取绘符加成(绘符经验值)

## 增加绘符经验（升级时打日志，便于 UI 提示）
func 增加绘符经验(数量: int) -> void:
	if 数量 <= 0:
		return
	var 旧等级: int = 获取绘符等级()
	绘符经验值 += 数量
	var 新等级: int = 获取绘符等级()
	if 新等级 > 旧等级:
		print("[绘符] 绘符等级提升：%d → %d" % [旧等级, 新等级])

## 绘符总览（S45-8 UI 消费方）
func 绘符总览() -> Dictionary:
	var 加成: Dictionary = 获取绘符加成()
	var 表: Array = _读表_符等级()
	var 下一档: Dictionary = {}
	var 当前: int = int(加成.get("等级", 1))
	for t in 表:
		var d: Dictionary = t as Dictionary
		if int(d.get("level", 1)) > 当前:
			下一档 = d
			break
	return {"经验": 绘符经验值, "等级": 当前, "成功率加成": float(加成.get("成功率加成", 0.0)),
		"高品质加成": float(加成.get("高品质加成", 0.0)), "下一档": 下一档}

func 全部符箓() -> Array:
	return _读表_符箓().values()

func 丹炉配置(fid: String) -> Dictionary:
	if fid.is_empty():
		return {}
	var t: Dictionary = _读表_丹炉()
	if t.has(fid):
		return (t[fid] as Dictionary).duplicate()
	return {}

func 当前丹炉配置() -> Dictionary:
	return 丹炉配置(当前丹炉)

## 丹方熟练等级 0-5（成功炉数：0/5/15/30/60/100）
func 丹方熟练等级(rid: String) -> int:
	var n: int = int(丹方熟练度.get(rid, 0))
	if n >= 100:
		return 5
	elif n >= 60:
		return 4
	elif n >= 30:
		return 3
	elif n >= 15:
		return 2
	elif n >= 5:
		return 1
	return 0

func 丹方熟练加成(rid: String) -> Dictionary:
	var lv: int = 丹方熟练等级(rid)
	return {"等级": lv, "次数": int(丹方熟练度.get(rid, 0)),
		"成率": float(lv) * 0.012, "出纹": float(lv) * 0.010,
		"品级分": float(lv) * 2.0, "产量": float(lv)}

# ==================== S46 领悟丹方系统（丹道传承·触类旁通·顿悟天成） ====================
## 新档初始化：师承传授基础丹方（入门时师父传授2-3个基础丹方）
func _初始化领悟丹方() -> void:
	if 已领悟丹方.is_empty():
		var 基础丹方: Array = ["juqi", "ip_002", "ip_006"]
		for rid in 基础丹方:
			if not 已领悟丹方.has(rid):
				已领悟丹方[rid] = _今日序号()
		if 丹方熟练度.size() > 0 and 已领悟丹方.size() <= 3:
			for rid in 丹方熟练度.keys():
				if not 已领悟丹方.has(rid):
					已领悟丹方[rid] = _今日序号()

## 检查是否领悟某丹方
func 是否领悟丹方(rid: String) -> bool:
	return 已领悟丹方.has(rid) and int(已领悟丹方[rid]) > 0

## 领悟某个丹方（返回是否新领悟）
func 领悟丹方(rid: String) -> bool:
	if 是否领悟丹方(rid):
		return false
	var cfg: Dictionary = 丹方配置(rid)
	if cfg.is_empty():
		return false
	已领悟丹方[rid] = _今日序号()
	丹方领悟进度[rid] = 0
	return true

## 获取未领悟的丹方列表（按品阶筛选）
func _获取未领悟丹方(最高品阶序: int = 99) -> Array:
	var 未领悟: Array = []
	for 方 in 全部丹方():
		var rid: String = str(方.get("id", ""))
		if not 是否领悟丹方(rid):
			var 阶序: int = int(方.get("需求境界序", 0))
			if 阶序 <= 最高品阶序:
				未领悟.append(方)
	return 未领悟

## 炼丹成功时触发领悟检查（反推领悟 + 随机顿悟）
func _炼丹成功触发领悟(rid: String, 丹堂等级: int = 1) -> Dictionary:
	var 结果: Dictionary = {"反推领悟": false, "顿悟领悟": false, "领悟丹方": ""}
	if rid == "" or not 是否领悟丹方(rid):
		return 结果
	丹方领悟进度[rid] = int(丹方领悟进度.get(rid, 0)) + 1
	var cfg: Dictionary = 丹方配置(rid)
	if cfg.is_empty():
		return 结果
	var 当前阶序: int = int(cfg.get("需求境界序", 0))
	var 反推基础概率: Dictionary = {0: 0.05, 1: 0.04, 2: 0.03, 3: 0.02, 4: 0.015, 5: 0.01, 6: 0.005}
	var 基础率: float = float(反推基础概率.get(当前阶序, 0.01))
	var 进度加成: float = float(int(丹方领悟进度.get(rid, 0)) / 10) * 0.01
	var 反推率: float = 基础率 * (1.0 + float(丹堂等级) * 0.05 + 进度加成)
	反推率 = clamp(反推率, 0.005, 0.30)
	if randf() < 反推率:
		var 可领悟: Array = _获取未领悟丹方(当前阶序 + 2)
		if 可领悟.size() > 0:
			var idx: int = randi() % 可领悟.size()
			var 新丹方: Dictionary = 可领悟[idx] as Dictionary
			var 新rid: String = str(新丹方.get("id", ""))
			if 领悟丹方(新rid):
				结果["反推领悟"] = true
				结果["领悟丹方"] = 新rid
				return 结果
	if randf() < 0.01:
		var 可顿悟: Array = _获取未领悟丹方(当前阶序 + 3)
		if 可顿悟.size() > 0:
			var idx2: int = randi() % 可顿悟.size()
			var 顿悟丹方: Dictionary = 可顿悟[idx2] as Dictionary
			var 顿悟rid: String = str(顿悟丹方.get("id", ""))
			if 领悟丹方(顿悟rid):
				结果["顿悟领悟"] = true
				结果["领悟丹方"] = 顿悟rid
	return 结果

## 获取领悟丹方统计
func 领悟丹方统计() -> Dictionary:
	var 总数: int = 全部丹方().size()
	var 已领悟数: int = 0
	for 方 in 全部丹方():
		var rid: String = str(方.get("id", ""))
		if 是否领悟丹方(rid):
			已领悟数 += 1
	return {"总数": 总数, "已领悟": 已领悟数, "未领悟": 总数 - 已领悟数,
		"进度": float(已领悟数) / float(max(1, 总数))}

# ==================== S46 炼器领悟系统（器道传承·触类旁通·顿悟天成） ====================
## 获取全部配方列表（从ForgeSystem读取 + 配置表扩展）
func 全部配方() -> Array:
	_加载炼器配方配置表()
	var 列表: Array = []
	# 优先使用配置表配方（更完整）
	for fid in 配置表配方.keys():
		var 配方: Dictionary = 配置表配方[fid] as Dictionary
		列表.append({"id": fid, "名称": 配方.get("名称", fid), "品阶": 配方.get("品阶", "凡阶"),
			"基础成功率": float(配方.get("基础成功率", 50)) / 100.0, "需求境界序": int(配方.get("需求境界序", 0))})
	# 补充ForgeSystem中独有的配方（配置表未覆盖的）
	for fid in ForgeSystem.配方库.keys():
		var 已存在: bool = false
		for it in 列表:
			if str(it.get("id", "")) == fid:
				已存在 = true
				break
		if not 已存在:
			var 配方2: Dictionary = ForgeSystem.配方库[fid] as Dictionary
			列表.append({"id": fid, "名称": 配方2.get("名称", fid), "品阶": 配方2.get("品阶", "凡阶"),
				"基础成功率": float(配方2.get("基础成功率", 50)) / 100.0, "需求境界序": int(配方2.get("需求境界序", 0))})
	return 列表

## 加载炼器配方配置表（forge_recipe_config.csv）
func _加载炼器配方配置表() -> void:
	if not 配置表配方.is_empty():
		return
	var 路径: String = "res://config/forge_recipe_config.csv"
	if not FileAccess.file_exists(路径):
		return
	var f: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if f == null:
		return
	var 表头: Array = f.get_csv_line()
	while not f.eof_reached():
		var 行: Array = f.get_csv_line()
		if 行.size() < 13 or 行[0] == "":
			continue
		var rid: String = str(行[0])
		配置表配方[rid] = {
			"名称": str(行[1]), "品阶": str(行[2]), "产出名": str(行[3]),
			"产出类别": str(行[4]), "产出穿戴位": str(行[5]),
			"材料": [{"名": str(行[6]), "数量": int(行[7])}, {"名": str(行[8]), "数量": int(行[9])}],
			"基础成功率": int(行[10]), "需求境界序": int(行[11]), "描述": str(行[12])
		}
	f.close()
	# 将配置表配方传递给ForgeSystem
	ForgeSystem.设置配置表配方(配置表配方)

## 新档初始化：师承传授基础配方
func _初始化领悟配方() -> void:
	if 已领悟配方.is_empty():
		# 师承传授：2个凡阶基础配方（剑、衣袍）
		var 基础配方: Array = ["jian_fan", "yipao_fan"]
		for rid in 基础配方:
			if not 已领悟配方.has(rid):
				已领悟配方[rid] = _今日序号()
		# 旧档兼容：如果已领悟为空，全部领悟
		if 已领悟配方.is_empty():
			_加载炼器配方配置表()
			for rid in 配置表配方.keys():
				已领悟配方[rid] = _今日序号()

## 检查是否领悟某配方
func 是否领悟配方(rid: String) -> bool:
	return 已领悟配方.has(rid) and int(已领悟配方[rid]) > 0

## 领悟某个配方（返回是否新领悟）
func 领悟配方(rid: String) -> bool:
	if 是否领悟配方(rid):
		return false
	var 配方: Dictionary = ForgeSystem.获取配方(rid)
	if 配方.is_empty():
		return false
	已领悟配方[rid] = _今日序号()
	配方领悟进度[rid] = 0
	var 配方名: String = str(配方.get("名称", rid))
	添加纪事("庶务", "器道领悟", "于锻造中触类旁通，领悟了【%s】锻造之法！" % 配方名, 2)
	return true

## 获取未领悟的配方列表（按品阶筛选）
func _获取未领悟配方(最高品阶序: int = 99) -> Array:
	var 未领悟: Array = []
	for 方 in 全部配方():
		var rid: String = str(方.get("id", ""))
		if not 是否领悟配方(rid):
			var 阶序: int = int(方.get("需求境界序", 0))
			if 阶序 <= 最高品阶序:
				未领悟.append(方)
	return 未领悟

## 炼器成功时触发领悟检查（反推领悟 + 随机顿悟）
func _炼器成功触发领悟(rid: String, 器堂等级: int = 1) -> Dictionary:
	var 结果: Dictionary = {"反推领悟": false, "顿悟领悟": false, "领悟配方": ""}
	if rid == "" or not 是否领悟配方(rid):
		return 结果
	配方领悟进度[rid] = int(配方领悟进度.get(rid, 0)) + 1
	var 配方: Dictionary = ForgeSystem.获取配方(rid)
	if 配方.is_empty():
		return 结果
	var 当前阶序: int = int(配方.get("需求境界序", 0))
	var 反推基础概率: Dictionary = {0: 0.06, 1: 0.05, 2: 0.04, 3: 0.03, 4: 0.02, 5: 0.015, 6: 0.01}
	var 基础率: float = float(反推基础概率.get(当前阶序, 0.01))
	var 进度加成: float = float(int(配方领悟进度.get(rid, 0)) / 8) * 0.01
	var 反推率: float = 基础率 * (1.0 + float(器堂等级) * 0.05 + 进度加成)
	反推率 = clamp(反推率, 0.005, 0.35)
	if randf() < 反推率:
		var 可领悟: Array = _获取未领悟配方(当前阶序 + 2)
		if 可领悟.size() > 0:
			var idx: int = randi() % 可领悟.size()
			var 新配方: Dictionary = 可领悟[idx] as Dictionary
			var 新rid: String = str(新配方.get("id", ""))
			if 领悟配方(新rid):
				结果["反推领悟"] = true
				结果["领悟配方"] = 新rid
				return 结果
	if randf() < 0.012:
		var 可顿悟: Array = _获取未领悟配方(当前阶序 + 3)
		if 可顿悟.size() > 0:
			var idx2: int = randi() % 可顿悟.size()
			var 顿悟配方: Dictionary = 可顿悟[idx2] as Dictionary
			var 顿悟rid: String = str(顿悟配方.get("id", ""))
			if 领悟配方(顿悟rid):
				结果["顿悟领悟"] = true
				结果["领悟配方"] = 顿悟rid
				添加纪事("庶务", "器道顿悟", "炉火纯青，于锻造中顿悟，领悟了【%s】锻造之法！" % str(顿悟配方.get("名称", "")), 3)
	return 结果

## 获取领悟配方统计
func 领悟配方统计() -> Dictionary:
	var 总数: int = 全部配方().size()
	var 已领悟数: int = 0
	for 方 in 全部配方():
		var rid: String = str(方.get("id", ""))
		if 是否领悟配方(rid):
			已领悟数 += 1
	return {"总数": 总数, "已领悟": 已领悟数, "未领悟": 总数 - 已领悟数,
		"进度": float(已领悟数) / float(max(1, 总数))}

## 炼丹师压制：自身境界序 - 丹方需求境界序（正=降维炼丹，负=勉强炼丹）
func 炼丹师压制(炼丹师, 需求境界序: int) -> int:
	if 炼丹师 == null:
		return 0
	var i: int = Disciple.境界序.find(str(炼丹师.境界))
	if i < 0:
		return 0
	return i - 需求境界序

func 丹品级配置(名: String) -> Dictionary:
	for g in _读表_丹品级():
		if str(g["grade_name"]) == 名:
			return g as Dictionary
	return {"grade_id": "sg_mid", "grade_name": "中品", "effect_scale": 1.0, "price_scale": 1.0,
		"toxin_scale": 1.0, "mark_cap_delta": 0, "mark_rate_scale": 1.0, "yield_scale": 1.0, "weight": 32.0}

## 掷丹品级：分越高越向上品/极品倾斜（分来自超额成率+熟练度+丹炉+压制）
func 掷丹品级(分: float) -> Dictionary:
	var 表: Array = _读表_丹品级()
	if 表.is_empty():
		return 丹品级配置("中品")
	var 权重: Array = []
	var 总: float = 0.0
	for g in 表:
		var w: float = float((g as Dictionary).get("weight", 1.0))
		var gid: String = str((g as Dictionary).get("grade_id", ""))
		if gid == "sg_low":
			w *= max(0.30, 1.0 - 分 / 60.0)
		elif gid == "sg_high":
			w *= 0.60 + 分 / 80.0
		elif gid == "sg_top":
			w *= 0.15 + 分 / 120.0
		权重.append(w)
		总 += w
	if 总 <= 0.0:
		return 丹品级配置("中品")
	var r: float = randf() * 总
	var acc: float = 0.0
	for i in range(表.size()):
		acc += float(权重[i])
		if r <= acc:
			return 表[i] as Dictionary
	return 表[表.size() - 1] as Dictionary

## 丹纹上限 = 品阶上限 + 品级偏移（凡品3 → 道品9；极品+2、下品-1）
func 丹纹上限(品阶: String, 品级: String):
	return 丹纹系统.丹纹上限(品阶, 品级)

func 炼丹产量(品阶: String, 品级: String, 压制: int, 熟练等级: int, 炉: Dictionary) -> int:
	var r: Dictionary = (_读表_丹产量().get(品阶, {}) as Dictionary)
	var base: float = float(r.get("base_yield", 1.0))
	var pr: float = float(r.get("per_realm_surplus", 0.0))
	var pp: float = float(r.get("per_prof_level", 0.0))
	var fs: float = float(r.get("furnace_scale", 1.0))
	var n: float = (base + float(max(0, 压制)) * pr + float(熟练等级) * pp
		+ float(炉.get("产量", 0.0)) * fs) * float(丹品级配置(品级).get("yield_scale", 1.0))
	return max(1, int(round(n)))

func _S39_掷纹(品阶: String, 额外出纹: float, 上限: int, 级系数: float, 丹堂等级: int) -> int:
	if 上限 <= 0:
		return 0
	var c: Dictionary = _丹纹配置(品阶)
	var p: float = float(c.get("base_rate", 0.35)) * 级系数
	p += 炼丹出纹加成(丹堂等级) + 额外出纹
	p = clamp(p, 0.02, 0.95)
	var 纹: int = 0
	while 纹 < 上限:
		if randf() > p:
			break
		纹 += 1
	return 纹

## 炼制一炉（S39 统一入口）：返回 {成功, 品级, 数量, 产出列表, 产出, 成功率, 纹, 原因}
func 炼制丹方(rid: String, 丹堂等级: int = 1) -> Dictionary:
	var cfg: Dictionary = 丹方配置(rid)
	if cfg.is_empty():
		return {"成功": false, "原因": "丹方不存在"}
	var 炉: Dictionary = 当前丹炉配置()
	var 省: float = clamp(float(炉.get("省材率", 0.0)), 0.0, 0.5)
	var 减毒: float = clamp(float(炉.get("减毒率", 0.0)), 0.0, 0.9)
	var 需草: int = int(ceil(float(cfg["cost_herb"]) * (1.0 - 省)))
	var 需矿: int = int(ceil(float(cfg["cost_ore"]) * (1.0 - 省)))
	var 需晶: int = int(ceil(float(cfg["cost_jing"]) * (1.0 - 省)))
	var 需石: int = int(ceil(float(cfg["cost_stone"]) * (1.0 - 省)))
	var 需气: int = int(ceil(float(cfg["cost_qi"]) * (1.0 - 省)))
	# 修真世界观：按丹方功效分配独特材料组合（每种丹方材料不同）
	var 丹方品阶: String = str(cfg.get("品阶", "凡品"))
	var 丹方名: String = str(cfg.get("名称", ""))
	var 需灵品灵草: int = 0
	var 需宝品灵草: int = 0
	var 需王品灵草: int = 0
	var 需圣品灵草: int = 0
	var 需仙品灵草: int = 0
	var 需妖兽内丹: String = ""
	var 需内丹数: int = 0
	var 需妖兽精血: String = ""
	var 需精血数: int = 0
	var 需灵晶额外: int = 0
	# 按功效分类（修真小说丹方设定）
	var 是突破丹: bool = false
	var 是回血丹: bool = false
	var 是修炼丹: bool = false
	var 是特殊丹: bool = false
	for k in ["筑基", "破障", "冲窍", "破婴", "凝金", "化神", "固金", "婴变"]:
		if k in 丹方名:
			是突破丹 = true
			break
	for k in ["回血", "续命", "回春", "养元", "固元"]:
		if k in 丹方名:
			是回血丹 = true
			break
	for k in ["聚气", "凝气", "培元"]:
		if k in 丹方名:
			是修炼丹 = true
			break
	for k in ["洗髓", "悟道", "化劫", "道果", "驻颜", "清颜", "延寿", "神识", "体丹", "力丹"]:
		if k in 丹方名:
			是特殊丹 = true
			break
	# 品阶→等阶映射
	var 品阶内丹等阶: Dictionary = {"灵品": "二阶", "宝品": "三阶", "王品": "四阶", "圣品": "五阶", "仙品": "七阶", "道品": "九阶"}
	var 品阶精血等阶: Dictionary = {"灵品": "一阶", "宝品": "二阶", "王品": "三阶", "圣品": "四阶", "仙品": "六阶", "道品": "八阶"}
	if 丹方品阶 in 品阶内丹等阶:
		var 等阶: String = 品阶内丹等阶[丹方品阶]
		var 精血等阶: String = 品阶精血等阶[丹方品阶]
		if 是突破丹:
			# 突破丹：高阶灵草为主 + 妖兽内丹（突破需妖兽精华）
			if 丹方品阶 == "灵品": 需灵品灵草 = max(2, 需草)
			elif 丹方品阶 == "宝品": 需宝品灵草 = max(2, 需草); 需灵品灵草 = 需晶
			elif 丹方品阶 == "王品": 需王品灵草 = max(2, 需草); 需宝品灵草 = 需晶; 需妖兽内丹 = 等阶; 需内丹数 = 1
			elif 丹方品阶 == "圣品": 需圣品灵草 = max(2, 需草); 需王品灵草 = 需晶; 需妖兽内丹 = 等阶; 需内丹数 = 2
			elif 丹方品阶 == "仙品": 需仙品灵草 = max(2, 需草); 需圣品灵草 = 需晶; 需妖兽内丹 = 等阶; 需内丹数 = 2
			elif 丹方品阶 == "道品": 需仙品灵草 = 需草; 需妖兽内丹 = 等阶; 需内丹数 = 3
		elif 是回血丹:
			# 回血丹：灵草为主 + 妖兽精血（精血生血）
			if 丹方品阶 == "灵品": 需灵品灵草 = max(1, 需草 / 2); 需妖兽精血 = 精血等阶; 需精血数 = 1
			elif 丹方品阶 == "宝品": 需宝品灵草 = max(1, 需草 / 2); 需妖兽精血 = 精血等阶; 需精血数 = 2
			elif 丹方品阶 == "王品": 需王品灵草 = max(1, 需草 / 2); 需妖兽精血 = 精血等阶; 需精血数 = 2; 需妖兽内丹 = 等阶; 需内丹数 = 1
			elif 丹方品阶 == "圣品": 需圣品灵草 = max(1, 需草 / 2); 需妖兽精血 = 精血等阶; 需精血数 = 3
			elif 丹方品阶 == "仙品": 需仙品灵草 = max(1, 需草 / 2); 需妖兽精血 = 精血等阶; 需精血数 = 3
			elif 丹方品阶 == "道品": 需仙品灵草 = 需草; 需妖兽精血 = 精血等阶; 需精血数 = 5
		elif 是修炼丹:
			# 修炼丹：灵草为主 + 灵晶（聚气凝元）
			if 丹方品阶 == "灵品": 需灵品灵草 = max(1, 需草 / 2); 需灵晶额外 = 需晶
			elif 丹方品阶 == "宝品": 需宝品灵草 = max(1, 需草 / 2); 需灵晶额外 = 需晶 * 2
			elif 丹方品阶 == "王品": 需王品灵草 = max(1, 需草 / 2); 需灵晶额外 = 需晶 * 2
			elif 丹方品阶 == "圣品": 需圣品灵草 = max(1, 需草 / 2); 需灵晶额外 = 需晶 * 3
			elif 丹方品阶 == "仙品": 需仙品灵草 = max(1, 需草 / 2); 需灵晶额外 = 需晶 * 3
			elif 丹方品阶 == "道品": 需仙品灵草 = 需草; 需灵晶额外 = 需晶 * 5
		else:
			# 特殊丹：稀有材料 + 高阶妖兽内丹
			if 丹方品阶 == "灵品": 需灵品灵草 = max(2, 需草); 需妖兽精血 = 精血等阶; 需精血数 = 1
			elif 丹方品阶 == "宝品": 需宝品灵草 = max(2, 需草); 需妖兽内丹 = 等阶; 需内丹数 = 1
			elif 丹方品阶 == "王品": 需王品灵草 = max(2, 需草); 需妖兽内丹 = 等阶; 需内丹数 = 2; 需妖兽精血 = 精血等阶; 需精血数 = 1
			elif 丹方品阶 == "圣品": 需圣品灵草 = max(2, 需草); 需妖兽内丹 = 等阶; 需内丹数 = 2
			elif 丹方品阶 == "仙品": 需仙品灵草 = max(2, 需草); 需妖兽内丹 = 等阶; 需内丹数 = 3
			elif 丹方品阶 == "道品": 需仙品灵草 = 需草; 需妖兽内丹 = 等阶; 需内丹数 = 5
	# 基础材料检查
	if 灵草 < 需草:
		return {"成功": false, "原因": "灵草不足（需%d）" % 需草}
	if 矿石 < 需矿:
		return {"成功": false, "原因": "矿石不足（需%d）" % 需矿}
	if 灵晶 < 需晶:
		return {"成功": false, "原因": "灵晶不足（需%d）" % 需晶}
	if 灵石 < 需石:
		return {"成功": false, "原因": "灵石不足（需%d）" % 需石}
	if 灵气 < 需气:
		return {"成功": false, "原因": "灵气不足（需%d）" % 需气}
	# 高阶灵草检查
	if 灵品灵草 < 需灵品灵草:
		return {"成功": false, "原因": "灵品灵草不足（需%d）" % 需灵品灵草}
	if 宝品灵草 < 需宝品灵草:
		return {"成功": false, "原因": "宝品灵草不足（需%d）" % 需宝品灵草}
	if 王品灵草 < 需王品灵草:
		return {"成功": false, "原因": "王品灵草不足（需%d）" % 需王品灵草}
	if 圣品灵草 < 需圣品灵草:
		return {"成功": false, "原因": "圣品灵草不足（需%d）" % 需圣品灵草}
	if 仙品灵草 < 需仙品灵草:
		return {"成功": false, "原因": "仙品灵草不足（需%d）" % 需仙品灵草}
	# 妖兽内丹检查
	if 需妖兽内丹 != "" and 获取妖兽内丹(需妖兽内丹) < 需内丹数:
		return {"成功": false, "原因": "%s妖兽内丹不足（需%d）" % [需妖兽内丹, 需内丹数]}
	if 需妖兽精血 != "" and 获取妖兽精血(需妖兽精血) < 需精血数:
		return {"成功": false, "原因": "%s妖兽精血不足（需%d）" % [需妖兽精血, 需精血数]}
	if 灵晶 < 需晶 + 需灵晶额外:
		return {"成功": false, "原因": "灵晶不足（需%d）" % (需晶 + 需灵晶额外)}
	# 扣除材料
	灵草 -= 需草
	矿石 -= 需矿
	灵晶 -= 需晶
	灵石 -= 需石
	灵气 -= 需气
	灵品灵草 -= 需灵品灵草
	宝品灵草 -= 需宝品灵草
	王品灵草 -= 需王品灵草
	圣品灵草 -= 需圣品灵草
	仙品灵草 -= 需仙品灵草
	if 需妖兽内丹 != "":
		妖兽内丹[需妖兽内丹] = int(妖兽内丹.get(需妖兽内丹, 0)) - 需内丹数
	if 需妖兽精血 != "":
		妖兽精血[需妖兽精血] = int(妖兽精血.get(需妖兽精血, 0)) - 需精血数
	if 需灵晶额外 > 0:
		灵晶 -= 需灵晶额外
	# ---- 成功率：丹方基础（每丹不同）+ 因子网络 + 丹炉 + 熟练 + 压制 ----
	var d = 丹堂负责人()
	var 基础: float = float(cfg["基础成功率"])
	var 因子: Dictionary = 炼丹因子明细(d, 丹堂等级)
	var 压: int = 炼丹师压制(d, int(cfg["需求境界序"]))
	var 熟: Dictionary = 丹方熟练加成(rid)
	var 率: float = 基础 + float(因子.get("成率", 0.0)) + float(炉.get("成率", 0.0)) + float(熟["成率"])
	if 压 > 0:
		率 += float(压) * 0.02
	elif 压 < 0:
		率 += float(压) * 0.05
	率 = clamp(率, 0.02, 0.98)
	if randf() > 率:
		return {"成功": false, "原因": "炼制失败（成功率%.0f%%）" % (率 * 100.0), "成功率": 率}
	# ---- 品级 ----
	var 分: float = (率 - 基础) * 100.0 * 0.6 + float(熟["品级分"])     + float(炉.get("品级分", 0.0)) + float(max(0, 压)) * 1.5
	var 级: Dictionary = 掷丹品级(分)
	var 级名: String = str(级["grade_name"])
	var 数量: int = 炼丹产量(str(cfg["品阶"]), 级名, 压, int(熟["等级"]), 炉)
	var 额外出纹: float = float(炉.get("出纹", 0.0)) + float(熟["出纹"])
	var 上限: int = 丹纹上限(str(cfg["品阶"]), 级名)
	var 级系数: float = float(级.get("mark_rate_scale", 1.0))
	var 毒基: float = float(_丹纹配置(str(cfg["品阶"])).get("base_toxin", 1.0))
	var 产出: Array = []
	var 首纹: int = 0
	for i in range(数量):
		var it = Item.new()
		it.类别 = "dan_yao"
		it.品阶 = str(cfg["品阶"])
		it.品级 = 级名
		it.名称 = str(cfg["产出丹名"])
		it.功效 = str(cfg.get("描述", ""))
		it.描述 = "%s炼制（%s）" % [str(cfg.get("需求境界", "")), 级名]
		it.战力加成 = 0
		it.丹毒值 = 毒基 * float(级.get("toxin_scale", 1.0)) * (1.0 - 减毒)
		it.算战力()
		var 纹: int = _S39_掷纹(str(cfg["品阶"]), 额外出纹, 上限, 级系数, 丹堂等级)
		it.丹纹 = 纹
		if i == 0:
			首纹 = 纹
		丹纹图谱入谱(it, 纹, str(cfg["品阶"]))
		宗门库房.append(it)
		产出.append(it)
	丹方熟练度[rid] = int(丹方熟练度.get(rid, 0)) + 1
	# S46 领悟丹方：炼丹成功时触发反推领悟 + 随机顿悟
	var 领悟结果: Dictionary = _炼丹成功触发领悟(rid, 丹堂等级)
	if bool(领悟结果.get("反推领悟", false)) or bool(领悟结果.get("顿悟领悟", false)):
		var 新丹方名: String = str(丹方配置(str(领悟结果.get("领悟丹方", ""))).get("名称", ""))
		if 新丹方名 != "":
			添加纪事("庶务", "丹道领悟", "于炼丹中触类旁通，领悟了【%s】！" % 新丹方名, 2)
	return {"成功": true, "品级": 级名, "数量": 数量, "纹": 首纹, "产出": 产出[0],
		"产出列表": 产出, "成功率": 率, "压制": 压,
		"原因": "成丹%d枚·%s（%s·%d纹，成功率%.0f%%）" % [数量, str(cfg["产出丹名"]), 级名, 首纹, 率 * 100.0]}

## 丹纹入谱（S37 图谱按「品阶+丹名」记录，避免同名不同阶混淆）
func 丹纹图谱入谱(丹药, 纹: int, 阶: String):
	丹纹系统.丹纹图谱入谱(丹药, 纹, 阶)

func 购置丹炉(fid: String) -> Dictionary:
	var f: Dictionary = 丹炉配置(fid)
	if f.is_empty():
		return {"成功": false, "原因": "丹炉不存在"}
	if 丹炉列表.has(fid):
		return {"成功": false, "原因": "已拥有此炉"}
	var 石: int = int(f.get("价灵石", 0))
	var 晶: int = int(f.get("价灵晶", 0))
	if 灵石 < 石 or 灵晶 < 晶:
		return {"成功": false, "原因": "资材不足（需灵石%d、灵晶%d）" % [石, 晶]}
	灵石 -= 石
	灵晶 -= 晶
	丹炉列表.append(fid)
	if 当前丹炉.is_empty():
		当前丹炉 = fid
	return {"成功": true, "原因": "购得%s（%s）" % [str(f["名称"]), str(f["品质"])]}

func 装备丹炉(fid: String) -> Dictionary:
	if not fid.is_empty() and not 丹炉列表.has(fid):
		return {"成功": false, "原因": "尚未拥有此炉"}
	当前丹炉 = fid
	if fid.is_empty():
		return {"成功": true, "原因": "已撤下丹炉"}
	return {"成功": true, "原因": "已装备%s" % str(丹炉配置(fid).get("名称", "丹炉"))}

## 全部丹炉（UI 购置/装备用）
func 全部丹炉() -> Array:
	return _读表_丹炉().values()

## 丹炉摘要（UI 用）
func 丹炉摘要() -> String:
	if 当前丹炉.is_empty():
		return "未装备丹炉（徒手炼丹，无器加成）"
	var f: Dictionary = 当前丹炉配置()
	return "%s（%s）成率+%d%% 出纹+%d%% 产量+%.1f 品级分+%.0f 减毒%d%% 省材%d%%" % [
		str(f.get("名称", "")), str(f.get("品质", "")), int(float(f.get("成率", 0.0)) * 100.0),
		int(float(f.get("出纹", 0.0)) * 100.0), float(f.get("产量", 0.0)), float(f.get("品级分", 0.0)),
		int(float(f.get("减毒率", 0.0)) * 100.0), int(float(f.get("省材率", 0.0)) * 100.0)]


# ============ §6.16 AI托管深度优化（方向2实现）============
## AI外交自动执行

func AI外交自动执行(家族ID: String) -> Dictionary:
	return 家族系统.AI外交自动执行(家族ID)


## 家族战争自动结算

# ===== 扩展家族系统函数（已拆分到family_system.gd，此处为转发函数）=====
func 家族战争自动结算():
	return 家族系统.家族战争自动结算()
func NPC家族动态生成():
	return 家族系统.NPC家族动态生成()
func 触发扩展家族事件(家族ID: String, 事件类型: String):
	return 家族系统.触发扩展家族事件(家族ID, 事件类型)
func 家族兴衰周期判定(家族ID: String):
	return 家族系统.家族兴衰周期判定(家族ID)
func 获取家族完整详情(家族ID: String):
	return 家族系统.获取家族完整详情(家族ID)
func 获取家族成员列表(家族ID: String):
	return 家族系统.获取家族成员列表(家族ID)
func 发起拍卖(物品ID: String, 物品名: String, 品阶: String, 起拍价: int, 卖家ID: String, 卖家类型: String):
	return 家族系统.发起拍卖(物品ID, 物品名, 品阶, 起拍价, 卖家ID, 卖家类型)
func 参与竞价(拍卖ID: String, 买家ID: String, 买家类型: String, 出价: int):
	return 家族系统.参与竞价(拍卖ID, 买家ID, 买家类型, 出价)
func 结算拍卖行():
	return 家族系统.结算拍卖行()
func 获取拍卖行列表(品阶过滤: String = "", 状态过滤: String = "进行中"):
	return 家族系统.获取拍卖行列表(品阶过滤, 状态过滤)
func 加入正魔阵营(弟子: Disciple, 阵营: String):
	return 家族系统.加入正魔阵营(弟子, 阵营)
func 参战正魔大战(弟子: Disciple, 战场: String = "中场"):
	return 家族系统.参战正魔大战(弟子, 战场)
func 兑换正魔战功(弟子: Disciple, 物品ID: String, 所需战功: int):
	return 家族系统.兑换正魔战功(弟子, 物品ID, 所需战功)
func 获取正魔大战状态():
	return 家族系统.获取正魔大战状态()
func 炼丹优化(弟子: Disciple, 丹方ID: String, 材料: Dictionary):
	return 家族系统.炼丹优化(弟子, 丹方ID, 材料)
func 炼器优化(弟子: Disciple, 器方ID: String, 材料: Dictionary):
	return 家族系统.炼器优化(弟子, 器方ID, 材料)
func 触发王朝事件(事件类型: String, 郡: String = ""):
	return 家族系统.触发王朝事件(事件类型, 郡)
func 王朝办差优化(弟子: Disciple, 差事类型: String, 郡: String):
	return 家族系统.王朝办差优化(弟子, 差事类型, 郡)
func 获取王朝状态():
	return 家族系统.获取王朝状态()
func 三元运算(条件: bool, 真值, 假值):
	return 家族系统.三元运算(条件, 真值, 假值)
func 获取拍卖行增强状态():
	return 家族系统.获取拍卖行增强状态()
func 发起拍卖增强(物品ID: String, 起拍价: int):
	return 家族系统.发起拍卖增强(物品ID, 起拍价)
func 获取正魔大战增强状态():
	return 家族系统.获取正魔大战增强状态()
func _统计弟子阵营():
	return 家族系统._统计弟子阵营()
func 获取炼丹炼器增强状态():
	return 家族系统.获取炼丹炼器增强状态()
func 炼丹增强(弟子: Disciple, 丹方ID: String):
	return 家族系统.炼丹增强(弟子, 丹方ID)
func 炼器增强(弟子: Disciple, 器方ID: String):
	return 家族系统.炼器增强(弟子, 器方ID)
func 获取凡人王朝增强状态():
	return 家族系统.获取凡人王朝增强状态()
func 王朝办差增强(弟子: Disciple, 差事类型: String, 郡: String):
	return 家族系统.王朝办差增强(弟子, 差事类型, 郡)
func 获取家族UI汇总数据():
	return 家族系统.获取家族UI汇总数据()

func _获取所有资源点状态() -> Array:
	var 资源点列表: Array = []
	var 资源点配置: Dictionary = _资源点配置 if "_资源点配置" in self else {}
	if 资源点配置.is_empty():
		# 默认资源点配置
		资源点配置 = {
			"灵脉矿脉": {"产出": "灵石100/月", "占领者": ""},
			"灵药园": {"产出": "灵草50/月", "占领者": ""},
			"炼器坊": {"产出": "矿石30/月", "占领者": ""},
			"聚灵地": {"产出": "修炼+20%", "占领者": ""},
			"秘境入口": {"产出": "定期探索", "占领者": ""}
		}
	for 资源点名 in 资源点配置.keys():
		var 资源点: Dictionary = 资源点配置[资源点名]
		资源点列表.append({"名": 资源点名, "产出": 资源点.get("产出", ""), "占领者": 资源点.get("占领者", "无")})
	return 资源点列表
# ============ P0 敌对生态系统（怪物/敌对NPC/阵营冲突/敌对势力AI） ============

# ---- P0-1 扩展怪物库 ----
var _扩展怪物配置: Array = []
var _扩展怪物已加载: bool = false

func _加载扩展怪物配置() -> void:
	if _扩展怪物已加载:
		return
	_扩展怪物已加载 = true
	var p: String = "res://config/monster_main.csv"
	if not FileAccess.file_exists(p):
		return
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()
	while not f.eof_reached():
		var row = f.get_csv_line()
		if row == null or row.size() < 18:
			continue
		_扩展怪物配置.append({
			"id": str(row[0]).strip_edges(),
			"名称": str(row[1]).strip_edges(),
			"境界": str(row[2]).strip_edges(),
			"属性": str(row[3]).strip_edges(),
			"气血": int(row[4]),
			"攻击": int(row[5]),
			"防御": int(row[6]),
			"速度": int(row[7]),
			"暴击": float(row[8]),
			"闪避": float(row[9]),
			"是否BOSS": str(row[13]).strip_edges() == "true",
			"族类": str(row[14]).strip_edges() if row.size() > 14 else "异兽",
			"行为": str(row[15]).strip_edges() if row.size() > 15 else "游荡",
			"区域": str(row[16]).strip_edges() if row.size() > 16 else "未知",
			"智慧": str(row[17]).strip_edges() if row.size() > 17 else "无智慧",
			"法宝": str(row[18]).strip_edges() if row.size() > 18 else "无",
			"本命物": str(row[19]).strip_edges() if row.size() > 19 else "无",
			"战斗道具": str(row[20]).strip_edges() if row.size() > 20 else "无",
			"描述": str(row[21]).strip_edges() if row.size() > 21 else ""
		})
	f.close()

func 获取所有怪物() -> Array:
	_加载扩展怪物配置()
	return _扩展怪物配置.duplicate()

func 按族类获取怪物(族类: String) -> Array:
	_加载扩展怪物配置()
	var result: Array = []
	for m in _扩展怪物配置:
		if str(m.get("族类", "")) == 族类:
			result.append(m)
	return result

func 按境界获取怪物(境界: String) -> Array:
	_加载扩展怪物配置()
	var result: Array = []
	for m in _扩展怪物配置:
		if str(m.get("境界", "")) == 境界:
			result.append(m)
	return result

func 按区域获取怪物(区域: String) -> Array:
	_加载扩展怪物配置()
	var result: Array = []
	for m in _扩展怪物配置:
		if str(m.get("区域", "")) == 区域:
			result.append(m)
	return result

func 生成怪物战斗属性(怪物ID: String) -> Dictionary:
	_加载扩展怪物配置()
	for m in _扩展怪物配置:
		if str(m.get("id", "")) == 怪物ID:
			return {
				"名称": m.get("名称", ""),
				"气血": m.get("气血", 100),
				"攻击": m.get("攻击", 10),
				"防御": m.get("防御", 5),
				"速度": m.get("速度", 50),
				"暴击率": m.get("暴击", 0.1),
				"闪避率": m.get("闪避", 0.05),
				"五行属性": m.get("属性", "全"),
				"职业": m.get("族类", "异兽"),
				"是BOSS": m.get("是否BOSS", false)
			}
	return {}

func 获取怪物法宝详情(怪物ID: String) -> Dictionary:
	_加载扩展怪物配置()
	for m in _扩展怪物配置:
		if str(m.get("id", "")) == 怪物ID:
			return {
				"怪物名称": str(m.get("名称", "")),
				"境界": str(m.get("境界", "")),
				"族类": str(m.get("族类", "")),
				"智慧": str(m.get("智慧", "无智慧")),
				"法宝": str(m.get("法宝", "无")),
				"本命物": str(m.get("本命物", "无")),
				"战斗道具": str(m.get("战斗道具", "无"))
			}
	return {}

func 获取所有怪物法宝() -> Array:
	_加载扩展怪物配置()
	var result: Array = []
	for m in _扩展怪物配置:
		if str(m.get("智慧", "")) == "高智慧" or str(m.get("法宝", "")) != "无":
			result.append({
				"怪物名称": str(m.get("名称", "")),
				"境界": str(m.get("境界", "")),
				"族类": str(m.get("族类", "")),
				"法宝": str(m.get("法宝", "无")),
				"本命物": str(m.get("本命物", "无")),
				"战斗道具": str(m.get("战斗道具", "无"))
			})
	return result

# ---- P0-2 敌对NPC系统 ----
var _敌对NPC配置: Array = []
var _敌对NPC已加载: bool = false
var 敌对NPC仇恨值: Dictionary = {}  # npc_id -> 仇恨值(0-100)
var 敌对NPC位置: Dictionary = {}    # npc_id -> 当前位置
var 敌对NPC状态: Dictionary = {}    # npc_id -> 状态(游荡/挑衅/掠夺/追杀/潜伏)

func _加载敌对NPC配置() -> void:
	if _敌对NPC已加载:
		return
	_敌对NPC已加载 = true
	var p: String = "res://config/hostile_npc_config.csv"
	if not FileAccess.file_exists(p):
		return
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()
	while not f.eof_reached():
		var row = f.get_csv_line()
		if row == null or row.size() < 17:
			continue
		var npc_id: String = str(row[0]).strip_edges()
		_敌对NPC配置.append({
			"id": npc_id,
			"名称": str(row[1]).strip_edges(),
			"境界": str(row[2]).strip_edges(),
			"势力": str(row[3]).strip_edges(),
			"性格": str(row[4]).strip_edges(),
			"基础仇恨": int(row[5]),
			"初始位置": str(row[6]).strip_edges(),
			"战力": int(row[7]),
			"功法": str(row[8]).strip_edges(),
			"功法效果": str(row[9]).strip_edges(),
			"武器": str(row[10]).strip_edges(),
			"防具": str(row[11]).strip_edges(),
			"饰品": str(row[12]).strip_edges(),
			"背景": str(row[13]).strip_edges(),
			"行为模式": str(row[14]).strip_edges(),
			"掉落": str(row[15]).strip_edges(),
			"可和解": str(row[16]).strip_edges() == "true",
			"和解条件": str(row[17]).strip_edges() if row.size() > 17 else ""
		})
		# 初始化仇恨值和位置
		if not 敌对NPC仇恨值.has(npc_id):
			敌对NPC仇恨值[npc_id] = int(row[5])
		if not 敌对NPC位置.has(npc_id):
			敌对NPC位置[npc_id] = str(row[6]).strip_edges()
		if not 敌对NPC状态.has(npc_id):
			敌对NPC状态[npc_id] = "游荡"
	f.close()

func 获取所有敌对NPC() -> Array:
	_加载敌对NPC配置()
	var result: Array = []
	for npc in _敌对NPC配置:
		var npc_id: String = str(npc.get("id", ""))
		var copy: Dictionary = npc.duplicate()
		copy["当前仇恨"] = int(敌对NPC仇恨值.get(npc_id, 0))
		copy["当前位置"] = str(敌对NPC位置.get(npc_id, ""))
		copy["当前状态"] = str(敌对NPC状态.get(npc_id, "游荡"))
		result.append(copy)
	return result

func 获取敌对NPC详情(npc_id: String) -> Dictionary:
	_加载敌对NPC配置()
	for npc in _敌对NPC配置:
		if str(npc.get("id", "")) == npc_id:
			var copy: Dictionary = npc.duplicate()
			copy["当前仇恨"] = int(敌对NPC仇恨值.get(npc_id, 0))
			copy["当前位置"] = str(敌对NPC位置.get(npc_id, ""))
			copy["当前状态"] = str(敌对NPC状态.get(npc_id, "游荡"))
			return copy
	return {}

func 增加敌对NPC仇恨(npc_id: String, 数量: int) -> void:
	_加载敌对NPC配置()
	var 当前: int = int(敌对NPC仇恨值.get(npc_id, 0))
	敌对NPC仇恨值[npc_id] = clamp(当前 + 数量, 0, 100)

func 减少敌对NPC仇恨(npc_id: String, 数量: int) -> void:
	_加载敌对NPC配置()
	var 当前: int = int(敌对NPC仇恨值.get(npc_id, 0))
	敌对NPC仇恨值[npc_id] = clamp(当前 - 数量, 0, 100)

func _更新敌对NPC状态(npc_id: String) -> void:
	var 仇恨: int = int(敌对NPC仇恨值.get(npc_id, 0))
	if 仇恨 < 30:
		敌对NPC状态[npc_id] = "游荡"
	elif 仇恨 < 50:
		敌对NPC状态[npc_id] = "挑衅"
	elif 仇恨 < 70:
		敌对NPC状态[npc_id] = "掠夺"
	else:
		敌对NPC状态[npc_id] = "追杀"

func 敌对NPC月度行动() -> Array:
	_加载敌对NPC配置()
	var 行动日志: Array = []
	for npc in _敌对NPC配置:
		var npc_id: String = str(npc.get("id", ""))
		var 行为模式: String = str(npc.get("行为模式", "游荡"))
		# 潜伏型NPC不主动行动
		if 行为模式 == "潜伏":
			continue
		# 更新状态
		_更新敌对NPC状态(npc_id)
		var 状态: String = str(敌对NPC状态.get(npc_id, "游荡"))
		# 根据状态执行行动
		if 状态 == "挑衅":
			行动日志.append("%s在%s挑衅宗门弟子" % [str(npc.get("名称", "")), str(敌对NPC位置.get(npc_id, ""))])
		elif 状态 == "掠夺":
			var 损失: int = randi() % 100 + 50
			灵石 = max(0, 灵石 - 损失)
			行动日志.append("%s掠夺宗门商队，损失%d灵石" % [str(npc.get("名称", "")), 损失])
			增加敌对NPC仇恨(npc_id, 10)
		elif 状态 == "追杀":
			行动日志.append("⚠ %s正在追杀宗门落单弟子，请加强戒备！" % str(npc.get("名称", "")))
			增加敌对NPC仇恨(npc_id, 5)
		# 小概率移动位置
		if randf() < 0.2:
			var 区域列表: Array = ["后山", "古道", "坊市", "密林", "秘境", "魔渊", "血河"]
			敌对NPC位置[npc_id] = 区域列表[randi() % 区域列表.size()]
	return 行动日志

func 击杀敌对NPC(npc_id: String) -> Dictionary:
	_加载敌对NPC配置()
	var npc: Dictionary = 获取敌对NPC详情(npc_id)
	if npc.is_empty():
		return {"成功": false, "原因": "NPC不存在"}
	# 增加业力
	业力 += 5
	# 移除NPC（标记为已击杀）
	敌对NPC仇恨值[npc_id] = -1
	敌对NPC状态[npc_id] = "已击杀"
	添加纪事("战斗", "击杀敌对NPC", "击杀%s，获得%s" % [str(npc.get("名称", "")), str(npc.get("掉落", ""))], 2)
	return {"成功": true, "掉落": str(npc.get("掉落", "")), "业力增加": 5}

func 和解敌对NPC(npc_id: String) -> Dictionary:
	_加载敌对NPC配置()
	var npc: Dictionary = 获取敌对NPC详情(npc_id)
	if npc.is_empty():
		return {"成功": false, "原因": "NPC不存在"}
	if not bool(npc.get("可和解", false)):
		return {"成功": false, "原因": "此NPC不可和解"}
	# 清零仇恨
	敌对NPC仇恨值[npc_id] = 0
	敌对NPC状态[npc_id] = "已和解"
	添加纪事("外交", "和解敌对NPC", "与%s达成和解，条件：%s" % [str(npc.get("名称", "")), str(npc.get("和解条件", ""))], 1)
	return {"成功": true, "和解条件": str(npc.get("和解条件", ""))}

# ---- P0-3 阵营冲突扩展 ----
const _阵营关系网: Dictionary = {
	"正道宗门": {"魔道邪宗": "敌对", "中立散修": "友好", "上古妖兽": "中立", "远古遗泽": "中立", "丹器师公会": "友好"},
	"魔道邪宗": {"正道宗门": "敌对", "中立散修": "中立", "上古妖兽": "友好", "远古遗泽": "中立", "丹器师公会": "中立"},
	"中立散修": {"正道宗门": "友好", "魔道邪宗": "中立", "上古妖兽": "中立", "远古遗泽": "中立", "丹器师公会": "竞争"},
	"上古妖兽": {"正道宗门": "中立", "魔道邪宗": "友好", "中立散修": "中立", "远古遗泽": "敌对", "丹器师公会": "中立"},
	"远古遗泽": {"正道宗门": "中立", "魔道邪宗": "中立", "中立散修": "中立", "上古妖兽": "敌对", "丹器师公会": "中立"},
	"丹器师公会": {"正道宗门": "友好", "魔道邪宗": "中立", "中立散修": "竞争", "上古妖兽": "中立", "远古遗泽": "中立"}
}

func 获取阵营关系(阵营A: String, 阵营B: String) -> String:
	if 阵营A == 阵营B:
		return "同盟"
	if _阵营关系网.has(阵营A) and _阵营关系网[阵营A].has(阵营B):
		return str(_阵营关系网[阵营A][阵营B])
	return "中立"

func 获取敌对阵营(阵营: String) -> Array:
	var result: Array = []
	if _阵营关系网.has(阵营):
		for other in _阵营关系网[阵营].keys():
			if str(_阵营关系网[阵营][other]) == "敌对":
				result.append(other)
	return result

func 获取友好阵营(阵营: String) -> Array:
	var result: Array = []
	if _阵营关系网.has(阵营):
		for other in _阵营关系网[阵营].keys():
			if str(_阵营关系网[阵营][other]) == "友好":
				result.append(other)
	return result

func 阵营冲突月度事件() -> Array:
	var 事件日志: Array = []
	# 正道vs魔道冲突（高概率）
	if randf() < 0.4:
		var 事件类型: Array = ["边境冲突", "资源争夺", "弟子摩擦", "互相悬赏"]
		var 事件: String = 事件类型[randi() % 事件类型.size()]
		事件日志.append("◆ 正道与魔道在边境发生%s" % 事件)
		# 影响玩家声望
		if randf() < 0.5:
			增加阵营声望("fz_zhengdao", 5)
		else:
			增加阵营声望("fz_mo", 5)
	# 散修vs丹器公会竞争（中概率）
	if randf() < 0.2:
		事件日志.append("◇ 中立散修与丹器师公会在坊市发生商业竞争")
	# 妖族vs远古遗泽冲突（低概率）
	if randf() < 0.1:
		事件日志.append("◇ 上古妖兽与远古遗泽在禁地发生冲突")
	return 事件日志

# ---- P0-4 敌对势力AI基础 ----
func 敌对势力月度行动() -> Array:
	var 行动日志: Array = []
	# 魔道邪宗边境骚扰（高概率）
	if randf() < 0.5:
		var 骚扰类型: Array = ["边境哨站被袭", "商队被劫", "弟子被掳", "资源被掠夺"]
		var 骚扰: String = 骚扰类型[randi() % 骚扰类型.size()]
		行动日志.append("⚠ 魔道邪宗在边境发起骚扰：%s" % 骚扰)
		# 小概率造成实际损失
		if randf() < 0.3:
			var 损失: int = randi() % 200 + 100
			灵石 = max(0, 灵石 - 损失)
			行动日志.append("  损失：%d灵石" % 损失)
	# 敌对NPC行动
	var npc行动: Array = 敌对NPC月度行动()
	for act in npc行动:
		行动日志.append(act)
	# 阵营冲突事件
	var 阵营事件: Array = 阵营冲突月度事件()
	for evt in 阵营事件:
		行动日志.append(evt)
	return 行动日志

func 获取敌对势力威胁等级() -> Dictionary:
	var 威胁: Dictionary = {"魔道邪宗": 0, "敌对NPC": 0, "总体": "安全"}
	# 魔道威胁（基于声望）
	var 魔道声望: int = 0
	if 阵营声望系统.阵营声望.has("fz_mo"):
		魔道声望 = int(阵营声望系统.阵营声望["fz_mo"])
	威胁["魔道邪宗"] = clamp(100 - 魔道声望, 0, 100)
	# 敌对NPC威胁（基于仇恨值总和）
	var 总仇恨: int = 0
	for npc_id in 敌对NPC仇恨值.keys():
		var h: int = int(敌对NPC仇恨值[npc_id])
		if h > 0:
			总仇恨 += h
	威胁["敌对NPC"] = clamp(总仇恨 / 5, 0, 100)
	# 总体威胁
	var 总体威胁: int = max(威胁["魔道邪宗"], 威胁["敌对NPC"])
	if 总体威胁 < 30:
		威胁["总体"] = "安全"
	elif 总体威胁 < 60:
		威胁["总体"] = "警戒"
	elif 总体威胁 < 80:
		威胁["总体"] = "危险"
	else:
		威胁["总体"] = "极度危险"
	return 威胁
# ============ P1 敌对生态深度系统（兽潮/敌对NPC成长/势力战争/阵营战争） ============

# ---- P1-1 兽潮事件系统 ----
var _兽潮配置: Array = []
var _兽潮已加载: bool = false
var 当前兽潮: Dictionary = {}  # 当前正在进行的兽潮

func _加载兽潮配置() -> void:
	if _兽潮已加载:
		return
	_兽潮已加载 = true
	var p: String = "res://config/beast_wave_config.csv"
	if not FileAccess.file_exists(p):
		return
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()
	while not f.eof_reached():
		var row = f.get_csv_line()
		if row == null or row.size() < 9:
			continue
		_兽潮配置.append({
			"id": str(row[0]).strip_edges(),
			"名称": str(row[1]).strip_edges(),
			"族类": str(row[2]).strip_edges(),
			"怪物数量": int(row[3]),
			"推荐战力": int(row[4]),
			"触发概率": float(row[5]),
			"基础伤害": int(row[6]),
			"基础奖励": int(row[7]),
			"描述": str(row[8]).strip_edges()
		})
	f.close()

func 兽潮月度触发检查() -> Dictionary:
	_加载兽潮配置()
	# 如果已有进行中的兽潮，不重复触发
	if not 当前兽潮.is_empty():
		return {"触发": false, "原因": "已有进行中的兽潮"}
	# 遍历所有兽潮，按概率触发
	for wave in _兽潮配置:
		if randf() < float(wave.get("触发概率", 0.05)):
			当前兽潮 = wave.duplicate()
			当前兽潮["状态"] = "进行中"
			当前兽潮["剩余怪物"] = int(wave.get("怪物数量", 10))
			添加纪事("事件", "兽潮来袭", "⚠ %s来袭！%s" % [str(wave.get("名称", "")), str(wave.get("描述", ""))], 3)
			return {"触发": true, "兽潮": 当前兽潮}
	return {"触发": false}

func 兽潮防御(策略: String) -> Dictionary:
	if 当前兽潮.is_empty():
		return {"成功": false, "原因": "当前无兽潮"}
	var 兽潮: Dictionary = 当前兽潮
	var 基础伤害: int = int(兽潮.get("基础伤害", 100))
	var 基础奖励: int = int(兽潮.get("基础奖励", 200))
	var 推荐战力: int = int(兽潮.get("推荐战力", 1000))
	# 计算宗门总战力，并筛选在宗弟子
	var 宗门总战力: int = 0
	var 在宗弟子: Array = []
	for d in 弟子列表:
		if d != null and d is Disciple and d.状态 == "在宗":
			宗门总战力 += int(d.战力)
			在宗弟子.append(d)
	# 散仙/鬼仙参与宗门防御（隐居灵脉的守护者，大难时出手）
	var 散仙战力: int = 获取散仙总战力()
	if 散仙战力 > 0:
		宗门总战力 += 散仙战力
		添加纪事("散仙", "兽潮防御", "隐居宗门灵脉的散仙/鬼仙感知兽潮来袭，出手相助，道行+%d。" % 散仙战力, 2)
	# 按战力排序，取前3为出战主力
	# 毒道：兽潮防御时毒傀儡和毒药自动生效（毒雾弥漫，妖兽畏毒）
	var 毒傀儡毒伤: int = 获取毒傀儡毒伤()
	var 毒道境界: String = 获取毒道境界()
	var 毒体加成: Dictionary = 获取毒体加成()
	var 总毒伤: int = 0
	var 毒伤减伤: float = 0.0
	var 毒伤战利品加成: float = 0.0
	if 毒傀儡毒伤 > 0 or 毒道境界 != "毒道学徒":
		总毒伤 = 毒傀儡毒伤 + int(float(毒道境界表.find(毒道境界)) * 30) + int(float(毒体加成["毒伤加成"]) * 150)
		# 毒伤降低兽潮基础伤害（妖兽中毒，攻击力下降）
		毒伤减伤 = min(0.3, float(总毒伤) / float(max(1, 推荐战力)))
		# 毒伤增加战利品（妖兽中毒，更容易击杀，获得更多材料）
		毒伤战利品加成 = min(0.5, float(总毒伤) / float(max(1, 推荐战力)) * 1.5)
		基础伤害 = int(float(基础伤害) * (1.0 - 毒伤减伤))
		添加纪事("毒道", "兽潮毒防", "毒傀儡布下毒雾大阵，妖兽中毒，攻击力下降%d%%，战利品+%d%%。" % [int(毒伤减伤 * 100), int(毒伤战利品加成 * 100)], 2)
	# S45-7：兽潮符箓加成（消耗符箓→临时战力增益，主动消费方接入）
	var 兽潮符箓加成: float = 符箓消耗加成(6)
	if 兽潮符箓加成 > 0:
		宗门总战力 = int(float(宗门总战力) * (1.0 + 兽潮符箓加成))
	if 毒傀儡毒伤 > 0:
		宗门总战力 += 毒傀儡毒伤 * 2  # 毒傀儡毒伤翻倍计入防御
	var 出战弟子: Array = 在宗弟子.duplicate()
	出战弟子.sort_custom(func(a, b): return int(a.战力) > int(b.战力))
	出战弟子 = 出战弟子.slice(0, min(3, 出战弟子.size()))
	var 出战弟子名: Array = []
	for d in 出战弟子:
		出战弟子名.append(d.姓名)
	var 结果: Dictionary = {"策略": 策略, "兽潮名称": 兽潮.get("名称", ""), "出战弟子": 出战弟子名}
	# 根据兽潮等级决定战利品池
	var 战利品: Dictionary = {}
	if 推荐战力 <= 800:
		战利品 = {"妖兽血": 3, "妖兽皮": 2, "妖兽内丹": 1}
	elif 推荐战力 <= 1500:
		战利品 = {"妖兽血": 5, "妖兽筋骨": 2, "妖兽内丹": 1, "妖兽精血": 1}
	elif 推荐战力 <= 2500:
		战利品 = {"妖兽筋骨": 3, "妖兽内丹": 2, "妖兽精血": 1, "狐火晶": 1}
	else:
		战利品 = {"妖兽内丹": 3, "妖兽精血": 2, "鹏羽": 1, "麒麟鳞": 1}
	# 毒道：毒伤战利品加成（妖兽中毒，更容易击杀，获得更多材料）
	if 毒伤战利品加成 > 0:
		for k in 战利品.keys():
			战利品[k] = int(战利品[k] * (1.0 + 毒伤战利品加成))
	if 策略 == "坚守":
		# 坚守：减少伤害，战利品减半
		var 伤害减免: float = 0.5 if 宗门总战力 >= 推荐战力 else 0.2
		# 护山大阵联动：大阵等级提供额外减伤（每级+3%，上限+30%）
		var 大阵抗性: float = 获取护山大阵抗性() if has_method("获取护山大阵抗性") else 0.0
		伤害减免 += clamp(大阵抗性, 0.0, 0.3)
		伤害减免 = clamp(伤害减免, 0.0, 0.9)  # 最高90%减伤
		var 实际伤害: int = int(基础伤害 * (1.0 - 伤害减免))
		灵石 = max(0, 灵石 - 实际伤害)
		结果["伤害"] = 实际伤害
		结果["奖励"] = 基础奖励 / 2
		灵石 += 基础奖励 / 2
		# 坚守战利品减半
		var 坚守战利品: Dictionary = {}
		for k in 战利品.keys():
			坚守战利品[k] = max(1, int(战利品[k] / 2))
		结果["战利品"] = 坚守战利品
		# 守护宗门：在宗弟子各加功德（护道安民）
		for d in 在宗弟子:
			if d.has_method("增加功德"):
				d.增加功德(10)
		# 坚守时低阶弟子有概率受伤（护山大阵也会有疏漏）
		var 伤亡名单: Array = []
		for d in 在宗弟子:
			if int(d.战力) < 推荐战力 / 3 and randf() < 0.1:
				d.受伤剩余 = max(int(d.受伤剩余), 10)
				伤亡名单.append(d.姓名)
		结果["伤亡"] = 伤亡名单
		结果["成功"] = true
		var 战利品文本: String = ""
		for k in 坚守战利品.keys():
			if 战利品文本 != "":
				战利品文本 += "、"
			战利品文本 += "%s×%d" % [k, 坚守战利品[k]]
		var 伤亡文本: String = "，%d名弟子受伤" % 伤亡名单.size() if not 伤亡名单.is_empty() else ""
		var 大阵文本: String = "，护山大阵减伤%d%%" % int(大阵抗性 * 100) if 大阵抗性 > 0 else ""
		结果["描述"] = "坚守不出，以护山大阵抵御兽潮%s，损失%d灵石，获得%d灵石及战利品【%s】%s，在宗弟子各积功德10" % [大阵文本, 实际伤害, 基础奖励 / 2, 战利品文本, 伤亡文本]
	elif 策略 == "出击":
		# 出击：高风险高回报
		var 胜率: float = float(宗门总战力) / float(推荐战力 * 2)
		胜率 = clamp(胜率, 0.1, 0.9)
		if randf() < 胜率:
			# 胜利
			var 奖励: int = 基础奖励 * 2
			灵石 += 奖励
			悟道点 += 20
			结果["战利品"] = 战利品
			# 击退兽潮：出战弟子加功德（守护一方），同时杀妖兽造少量杀业
			for d in 出战弟子:
				if d.has_method("增加功德"):
					d.增加功德(20)
					d.增加业力(5)
			# 出战弟子有概率临阵突破（修真小说常见桥段）
			var 突破名单: Array = []
			for d in 出战弟子:
				if d.层数 >= 8 and randf() < 0.15:
					d.层数 = 10
					突破名单.append(d.姓名)
			# 出战弟子有概率受伤
			var 伤亡名单: Array = []
			for d in 出战弟子:
				if randf() < 0.2:
					d.受伤剩余 = max(int(d.受伤剩余), 15)
					伤亡名单.append(d.姓名)
			结果["突破"] = 突破名单
			结果["伤亡"] = 伤亡名单
			结果["胜利"] = true
			结果["奖励"] = 奖励
			结果["悟道点"] = 20
			var 战利品文本: String = ""
			for k in 战利品.keys():
				if 战利品文本 != "":
					战利品文本 += "、"
				战利品文本 += "%s×%d" % [k, 战利品[k]]
			var 突破文本: String = ""
			if not 突破名单.is_empty():
				突破文本 = "，%s临阵突破" % "、".join(突破名单)
			var 伤亡文本: String = "，%d名弟子受伤" % 伤亡名单.size() if not 伤亡名单.is_empty() else ""
			var 出战名: String = "、".join(出战弟子名)
			结果["描述"] = "主动出击，大败兽潮！出战弟子%s，获得%d灵石、20悟道点及战利品【%s】%s%s，出战弟子各积功德20、杀业5" % [出战名, 奖励, 战利品文本, 突破文本, 伤亡文本]
		else:
			# 失败
			var 伤害: int = 基础伤害 * 2
			灵石 = max(0, 灵石 - 伤害)
			# 失败时出战弟子必受伤
			var 伤亡名单: Array = []
			for d in 出战弟子:
				d.受伤剩余 = max(int(d.受伤剩余), 20)
				伤亡名单.append(d.姓名)
			结果["伤亡"] = 伤亡名单
			结果["胜利"] = false
			结果["伤害"] = 伤害
			var 出战名2: String = "、".join(出战弟子名)
			结果["描述"] = "出击失利，被兽潮击退，出战弟子%s皆受伤，损失%d灵石" % [出战名2, 伤害]
		结果["成功"] = true
	elif 策略 == "求和":
		# 求和：付出代价，避免战斗
		var 代价: int = 基础奖励
		if 灵石 >= 代价:
			灵石 -= 代价
			结果["代价"] = 代价
			结果["成功"] = true
			结果["描述"] = "以%d灵石为代价，与兽潮达成和解，避免战斗" % 代价
		else:
			结果["成功"] = false
			结果["原因"] = "灵石不足，无法求和"
	else:
		结果["成功"] = false
		结果["原因"] = "未知策略"
	# 结束兽潮
	if 结果.get("成功", false):
		当前兽潮 = {}
		添加纪事("事件", "兽潮结束", "%s已结束：%s" % [str(兽潮.get("名称", "")), str(结果.get("描述", ""))], 2)
	return 结果

func 获取当前兽潮() -> Dictionary:
	return 当前兽潮.duplicate()

# ---- P1-2 敌对NPC成长/化敌为友 ----
func 敌对NPC月度成长() -> Array:
	_加载敌对NPC配置()
	var 成长日志: Array = []
	for npc in _敌对NPC配置:
		var npc_id: String = str(npc.get("id", ""))
		var 状态: String = str(敌对NPC状态.get(npc_id, "游荡"))
		# 已击杀/已和解的NPC不成长
		if 状态 == "已击杀" or 状态 == "已和解":
			continue
		# 月度修炼（小概率突破）
		if randf() < 0.1:
			var 当前境界: String = str(npc.get("境界", "练气"))
			var 境界列表: Array = ["练气", "筑基", "金丹", "元婴", "化神", "炼虚"]
			var 当前索引: int = 境界列表.find(当前境界)
			if 当前索引 >= 0 and 当前索引 < 境界列表.size() - 1:
				var 新境界: String = 境界列表[当前索引 + 1]
				npc["境界"] = 新境界
				成长日志.append("%s突破至%s境界！" % [str(npc.get("名称", "")), 新境界])
		# 战力自然增长
		var 当前战力: int = int(npc.get("战力", 500))
		var 增长: int = randi() % 50 + 10
		npc["战力"] = 当前战力 + 增长
	return 成长日志

func 尝试化敌为友(npc_id: String, 方式: String) -> Dictionary:
	_加载敌对NPC配置()
	var npc: Dictionary = 获取敌对NPC详情(npc_id)
	if npc.is_empty():
		return {"成功": false, "原因": "NPC不存在"}
	if not bool(npc.get("可和解", false)):
		return {"成功": false, "原因": "此NPC不可化敌为友"}
	var 仇恨: int = int(npc.get("当前仇恨", 0))
	if 仇恨 > 30:
		return {"成功": false, "原因": "仇恨值过高（%d），需先降低仇恨至30以下" % 仇恨}
	var 结果: Dictionary = {"成功": false}
	if 方式 == "击败收服":
		# 击败后收服（需要宗门战力足够）
		var 宗门总战力: int = 0
		for d in 弟子列表:
			if d != null and d is Disciple and d.状态 == "在宗":
				宗门总战力 += int(d.战力)
		if 宗门总战力 >= int(npc.get("战力", 500)) * 2:
			结果["成功"] = true
			结果["描述"] = "击败%s后将其收服，加入宗门" % str(npc.get("名称", ""))
		else:
			结果["原因"] = "宗门道行不足，无法击败收服"
	elif 方式 == "满足条件":
		# 满足和解条件
		var 条件: String = str(npc.get("和解条件", ""))
		if 条件 != "":
			结果["成功"] = true
			结果["描述"] = "满足条件：%s，%s化敌为友" % [条件, str(npc.get("名称", ""))]
		else:
			结果["原因"] = "此NPC无明确和解条件"
	elif 方式 == "真情打动":
		# 小概率成功
		if randf() < 0.2:
			结果["成功"] = true
			结果["描述"] = "以真情打动%s，化敌为友" % str(npc.get("名称", ""))
		else:
			结果["原因"] = "真情打动失败，对方不为所动"
			减少敌对NPC仇恨(npc_id, 5)
	else:
		结果["原因"] = "未知方式"
	# 化敌为友成功
	if 结果.get("成功", false):
		敌对NPC仇恨值[npc_id] = 0
		敌对NPC状态[npc_id] = "已和解"
		声望 += 50
		添加纪事("外交", "化敌为友", "%s：%s" % [str(npc.get("名称", "")), str(结果.get("描述", ""))], 2)
	return 结果

func 获取敌对NPC背景故事(npc_id: String) -> String:
	_加载敌对NPC配置()
	for npc in _敌对NPC配置:
		if str(npc.get("id", "")) == npc_id:
			return "%s，%s境界，%s势力。%s" % [
				str(npc.get("名称", "")),
				str(npc.get("境界", "")),
				str(npc.get("势力", "")),
				str(npc.get("背景", ""))
			]
	return ""

func 获取敌对NPC功法详情(npc_id: String) -> Dictionary:
	_加载敌对NPC配置()
	for npc in _敌对NPC配置:
		if str(npc.get("id", "")) == npc_id:
			return {
				"功法名称": str(npc.get("功法", "")),
				"功法效果": str(npc.get("功法效果", "")),
				"NPC名称": str(npc.get("名称", "")),
				"境界": str(npc.get("境界", ""))
			}
	return {}

func 获取所有敌对NPC功法() -> Array:
	_加载敌对NPC配置()
	var result: Array = []
	for npc in _敌对NPC配置:
		result.append({
			"NPC名称": str(npc.get("名称", "")),
			"功法": str(npc.get("功法", "")),
			"功法效果": str(npc.get("功法效果", "")),
			"境界": str(npc.get("境界", ""))
		})
	return result

func 获取敌对NPC装备详情(npc_id: String) -> Dictionary:
	_加载敌对NPC配置()
	for npc in _敌对NPC配置:
		if str(npc.get("id", "")) == npc_id:
			return {
				"NPC名称": str(npc.get("名称", "")),
				"武器": str(npc.get("武器", "")),
				"防具": str(npc.get("防具", "")),
				"饰品": str(npc.get("饰品", "")),
				"境界": str(npc.get("境界", ""))
			}
	return {}

func 获取所有敌对NPC装备() -> Array:
	_加载敌对NPC配置()
	var result: Array = []
	for npc in _敌对NPC配置:
		result.append({
			"NPC名称": str(npc.get("名称", "")),
			"武器": str(npc.get("武器", "")),
			"防具": str(npc.get("防具", "")),
			"饰品": str(npc.get("饰品", "")),
			"境界": str(npc.get("境界", ""))
		})
	return result

# ============ P2接入：敌对NPC挑战战斗 ============
## 挑战敌对NPC（使用BattleManager真实战斗引擎）
## 参数：npc_id - 敌对NPC ID，出战弟子 - 弟子对象数组
## 返回：{成功, 战报, 奖励, NPC详情}
func 挑战敌对NPC(npc_id: String, 出战弟子: Array = []) -> Dictionary:
	_加载敌对NPC配置()
	var npc: Dictionary = 获取敌对NPC详情(npc_id)
	if npc.is_empty():
		return {"成功": false, "原因": "NPC不存在", "战报": {}, "奖励": {}}

	var 状态: String = str(npc.get("当前状态", "游荡"))
	if 状态 == "已击杀":
		return {"成功": false, "原因": "此NPC已被击杀", "战报": {}, "奖励": {}}
	if 状态 == "已和解":
		return {"成功": false, "原因": "此NPC已化敌为友", "战报": {}, "奖励": {}}

	# 检查出战弟子
	if 出战弟子.is_empty():
		return {"成功": false, "原因": "未选择出战弟子", "战报": {}, "奖励": {}}

	# 构造敌对NPC战斗快照（根据战力和境界估算属性）
	var npc战力: int = int(npc.get("战力", 500))
	var npc境界: String = str(npc.get("境界", "练气"))
	var 境界加成: Dictionary = {"练气": 0, "筑基": 20, "金丹": 50, "元婴": 100, "化神": 200, "炼虚": 400}
	var 境界灵力: int = int(境界加成.get(npc境界, 0))
	var npc快照: Dictionary = {
		"名称": str(npc.get("名称", "敌对NPC")),
		"境界": npc境界,
		"属性": {
			"血": int(npc战力 * 0.5),
			"攻": int(npc战力 * 0.15),
			"防": int(npc战力 * 0.1),
			"灵力上限": 50 + 境界灵力,
			"灵力回复": 5 + int(境界灵力 / 10),
			"当前灵力": 50 + 境界灵力,
			"暴击率": 0.05,
			"闪避率": 0.03
		},
		"战力": npc战力,
		"功法": str(npc.get("功法", "")),
		"武器": str(npc.get("武器", "")),
		"防具": str(npc.get("防具", ""))
	}

	# 获取出战弟子战斗快照
	var 弟子快照: Array = []
	for d in 出战弟子:
		if d != null and d.has_method("get_final_combat_attr"):
			弟子快照.append(d.get_final_combat_attr())

	if 弟子快照.is_empty():
		return {"成功": false, "原因": "出战弟子无效", "战报": {}, "奖励": {}}

	# 使用BattleManager计算战斗（1v1取第一名弟子）
	var 战报: Dictionary
	if 弟子快照.size() == 1:
		战报 = BattleManager.发起1v1(弟子快照[0], npc快照, "full", false)
	else:
		# 多弟子取前3名3v3
		var 攻方: Array = 弟子快照.slice(0, min(3, 弟子快照.size()))
		战报 = BattleManager.发起3v3(攻方, [npc快照], "full", false)

	var 胜利: bool = bool(战报.get("is_win", false))
	var 奖励: Dictionary = {}

	# 处理战斗结果
	if 胜利:
		# 击杀NPC
		敌对NPC状态[npc_id] = "已击杀"
		# 增加仇恨（其他敌对NPC）
		for other_id in 敌对NPC状态.keys():
			if other_id != npc_id and 敌对NPC状态[other_id] == "游荡":
				增加敌对NPC仇恨(str(other_id), 5)
		# 弟子级业力：斩杀修士/妖兽皆造杀业（修真世界观：因果随身）
		var npc类型: String = str(npc.get("类型", "修士"))
		var 杀业业力: int = 20
		match npc类型:
			"邪修", "魔族": 杀业业力 = 15  # 斩妖除魔，业力较轻
			"妖兽": 杀业业力 = 10  # 杀妖兽，业力微
			_: 杀业业力 = 30  # 斩杀修士，业力较重
		for d in 出战弟子:
			if d != null and d.has_method("增加业力"):
				d.增加业力(杀业业力)
		# 宗门级业力
		业力 += 5
		# 奖励：灵石、声望、掉落
		var 灵石奖励: int = int(npc战力 * 0.2) + randi() % 100
		灵石 += 灵石奖励
		声望 += 20
		奖励["灵石"] = 灵石奖励
		奖励["声望"] = 20
		奖励["掉落"] = str(npc.get("掉落", ""))
		添加纪事("战斗", "击杀敌对NPC", "击杀%s，出战弟子各增杀业%d，获得灵石%d、声望20" % [str(npc.get("名称", "")), 杀业业力, 灵石奖励], 2)
	else:
		# 失败：NPC仇恨增加，弟子受伤
		增加敌对NPC仇恨(npc_id, 15)
		for d in 出战弟子:
			if d != null and d.has_method("受伤剩余"):
				d.受伤剩余 = max(int(d.受伤剩余), 15)
		奖励["灵石"] = 0
		奖励["声望"] = 0
		添加纪事("战斗", "挑战失败", "挑战%s失败，弟子受伤，仇恨+15" % str(npc.get("名称", "")), 1)

	return {
		"成功": true,
		"胜利": 胜利,
		"战报": 战报,
		"奖励": 奖励,
		"NPC详情": npc,
		"攻方快照": 弟子快照,
		"守方快照": [npc快照]
	}

# ---- P1-3 势力战争系统 ----
var 进行中战争: Dictionary = {}  # 当前进行中的战争
const _可争夺资源点: Array = ["灵脉矿脉", "灵药园", "炼器坊", "聚灵地", "秘境入口"]

func 发起势力战争(战争类型: String, 目标势力: String, 出战队伍: Array) -> Dictionary:
	if not 进行中战争.is_empty():
		return {"成功": false, "原因": "已有进行中的战争"}
	# 检查出战队伍
	if 出战队伍.is_empty():
		return {"成功": false, "原因": "未选择出战队伍"}
	# 计算双方战力
	var 攻方战力: int = 0
	for d in 出战队伍:
		if d != null:
			攻方战力 += int(d.get("战力", 0))
	var 守方战力: int = 攻方战力 / 2 + randi() % 攻方战力
	# 创建战争
	进行中战争 = {
		"类型": 战争类型,
		"目标势力": 目标势力,
		"攻方战力": 攻方战力,
		"守方战力": 守方战力,
		"状态": "备战",
		"回合": 0,
		"最大回合": 3,
		"攻方损失": 0,
		"守方损失": 0
	}
	添加纪事("战争", "宣战", "宗门向%s宣战，%s之战拉开帷幕！" % [目标势力, 战争类型], 3)
	_加推演条目("【宗门】向%s宣战，%s之战拉开帷幕。" % [目标势力, 战争类型], ET_SECT, PRIO_HIGH, {})
	return {"成功": true, "战争": 进行中战争.duplicate()}

func 推进战争回合() -> Dictionary:
	if 进行中战争.is_empty():
		return {"成功": false, "原因": "无进行中的战争"}
	var 战争: Dictionary = 进行中战争
	战争["回合"] = int(战争.get("回合", 0)) + 1
	# 战斗结算
	var 攻方战力: int = int(战争.get("攻方战力", 1000))
	var 守方战力: int = int(战争.get("守方战力", 1000))
	var 攻方胜率: float = float(攻方战力) / float(攻方战力 + 守方战力)
	var 回合结果: String = ""
	if randf() < 攻方胜率:
		# 攻方胜
		var 损失: int = 守方战力 / 5
		战争["守方损失"] = int(战争.get("守方损失", 0)) + 损失
		战争["守方战力"] = max(0, 守方战力 - 损失)
		回合结果 = "第%d阵交锋：我军占优，敌方法力折损%d" % [int(战争["回合"]), 损失]
	else:
		# 守方胜
		var 损失: int = 攻方战力 / 5
		战争["攻方损失"] = int(战争.get("攻方损失", 0)) + 损失
		战争["攻方战力"] = max(0, 攻方战力 - 损失)
		回合结果 = "第%d阵交锋：敌军顽抗，我军折损%d" % [int(战争["回合"]), 损失]
	# 检查战争结束
	var 战争结束: bool = false
	var 战争结果: String = ""
	if int(战争.get("回合", 0)) >= int(战争.get("最大回合", 3)):
		战争结束 = true
		if int(战争.get("攻方战力", 0)) > int(战争.get("守方战力", 0)):
			战争结果 = "大获全胜！敌军溃败，我军凯旋！"
			# 战利品
			var 战利品: int = 500 + randi() % 500
			灵石 += 战利品
			声望 += 30
			战争结果 += "缴获灵石%d、宗门声望+30" % 战利品
		else:
			战争结果 = "战事失利，我军败退！"
			var 损失: int = 300 + randi() % 300
			灵石 = max(0, 灵石 - 损失)
			战争结果 += "军需损耗灵石%d" % 损失
	elif int(战争.get("攻方战力", 0)) <= 0:
		战争结束 = true
		战争结果 = "我军尽殁，敌军大获全胜！"
	elif int(战争.get("守方战力", 0)) <= 0:
		战争结束 = true
		战争结果 = "敌军尽灭，我军大获全胜！缴获无数战利品！"
		灵石 += 1000
		声望 += 50
	# 记录
	添加纪事("战争", "战争回合", 回合结果, 2)
	if 战争结束:
		添加纪事("战争", "战争结束", 战争结果, 3)
		进行中战争 = {}
	return {"成功": true, "回合结果": 回合结果, "战争结束": 战争结束, "战争结果": 战争结果, "当前战争": 战争.duplicate()}

func 获取可争夺资源点() -> Array:
	return _可争夺资源点.duplicate()

func 获取进行中战争() -> Dictionary:
	return 进行中战争.duplicate()

# ---- P1-4 阵营战争系统 ----
var 进行中阵营战争: Dictionary = {}

func 阵营战争月度检查() -> Dictionary:
	# 如果已有进行中的阵营战争，不重复触发
	if not 进行中阵营战争.is_empty():
		return {"触发": false, "原因": "已有进行中的阵营战争"}
	# 正道vs魔道战争（低概率触发）
	if randf() < 0.1:
		进行中阵营战争 = {
			"名称": "正魔大战",
			"攻方": "正道宗门",
			"守方": "魔道邪宗",
			"状态": "进行中",
			"持续月数": 3,
			"已过月数": 0,
			"正道战绩": 0,
			"魔道战绩": 0
		}
		添加纪事("战争", "阵营战争", "正魔大战爆发！正道诸宗与魔道邪宗在边境展开旷世激战！", 3)
		_加推演条目("【天下】正魔大战爆发，正道与魔道在边境激战。", ET_SECT, PRIO_HIGH, {})
		return {"触发": true, "战争": 进行中阵营战争.duplicate()}
	return {"触发": false}

func 阵营战争玩家选择(选择: String) -> Dictionary:
	if 进行中阵营战争.is_empty():
		return {"成功": false, "原因": "当前无阵营战争"}
	var 战争: Dictionary = 进行中阵营战争
	var 结果: Dictionary = {"选择": 选择}
	if 选择 == "参战正道":
		# 加入正道阵营
		增加阵营声望("fz_zhengdao", 20)
		增加阵营声望("fz_mo", -10)
		战争["正道战绩"] = int(战争.get("正道战绩", 0)) + 1
		结果["描述"] = "投入正道阵营，共抗魔道！正道声望+20，魔道声望-10"
		结果["奖励"] = {"正道声望": 20, "魔道声望": -10}
	elif 选择 == "参战魔道":
		增加阵营声望("fz_mo", 20)
		增加阵营声望("fz_zhengdao", -10)
		战争["魔道战绩"] = int(战争.get("魔道战绩", 0)) + 1
		结果["描述"] = "投入魔道阵营，与正道为敌！魔道声望+20，正道声望-10"
		结果["奖励"] = {"魔道声望": 20, "正道声望": -10}
	elif 选择 == "中立":
		# 保持中立，获得少量资源
		灵石 += 100
		结果["描述"] = "闭关中立，坐山观虎斗，两方皆有馈赠，得灵石100"
		结果["奖励"] = {"灵石": 100}
	elif 选择 == "渔利":
		# 趁火打劫，高风险高回报
		if randf() < 0.5:
			var 收益: int = 300 + randi() % 300
			灵石 += 收益
			结果["描述"] = "趁乱取利，缴获灵石%d！" % 收益
			结果["奖励"] = {"灵石": 收益}
		else:
			var 损失: int = 200 + randi() % 200
			灵石 = max(0, 灵石 - 损失)
			结果["描述"] = "取利不成，反被两方夹击，损耗灵石%d" % 损失
			结果["损失"] = 损失
	else:
		结果["成功"] = false
		结果["原因"] = "未知选择"
		return 结果
	结果["成功"] = true
	添加纪事("战争", "阵营战争", "玩家选择：%s" % str(结果.get("描述", "")), 2)
	return 结果

func 推进阵营战争月度() -> Dictionary:
	if 进行中阵营战争.is_empty():
		return {"成功": false, "原因": "无进行中的阵营战争"}
	var 战争: Dictionary = 进行中阵营战争
	战争["已过月数"] = int(战争.get("已过月数", 0)) + 1
	# 月度战斗
	var 正道胜: bool = randf() < 0.5
	if 正道胜:
		战争["正道战绩"] = int(战争.get("正道战绩", 0)) + 1
	else:
		战争["魔道战绩"] = int(战争.get("魔道战绩", 0)) + 1
	# 检查战争结束
	var 战争结束: bool = false
	var 战争结果: String = ""
	if int(战争.get("已过月数", 0)) >= int(战争.get("持续月数", 3)):
		战争结束 = true
		if int(战争.get("正道战绩", 0)) > int(战争.get("魔道战绩", 0)):
			战争结果 = "正道大胜！魔道败退，正道诸宗声势大振！"
			增加阵营声望("fz_zhengdao", 30)
		else:
			战争结果 = "魔道大胜！正道退守，魔道气焰嚣张！"
			增加阵营声望("fz_mo", 30)
		添加纪事("战争", "阵营战争结束", 战争结果, 3)
		进行中阵营战争 = {}
	return {"成功": true, "战争结束": 战争结束, "战争结果": 战争结果, "当前战争": 战争.duplicate()}

func 获取进行中阵营战争() -> Dictionary:
	return 进行中阵营战争.duplicate()
# ============ P2 敌对生态高阶系统（势力兴衰/宗门战争/幕后黑手/稀有刷新） ============

# ---- P2-1 势力兴衰系统 ----
var 势力状态: Dictionary = {}  # 势力名 -> 状态(崛起/鼎盛/衰落/灭亡)
var 势力实力: Dictionary = {}  # 势力名 -> 实力值
const _势力列表: Array = ["正道宗门", "魔道邪宗", "中立散修", "上古妖兽", "远古遗泽", "丹器师公会"]
const _势力初始实力: Dictionary = {
	"正道宗门": 8000, "魔道邪宗": 7500, "中立散修": 5000,
	"上古妖兽": 6000, "远古遗泽": 4000, "丹器师公会": 5500
}

func _初始化势力状态() -> void:
	for 势力 in _势力列表:
		if not 势力状态.has(势力):
			势力状态[势力] = "鼎盛"
		if not 势力实力.has(势力):
			势力实力[势力] = int(_势力初始实力.get(势力, 5000))

func 势力兴衰月度检查() -> Array:
	_初始化势力状态()
	var 事件日志: Array = []
	for 势力 in _势力列表:
		var 状态: String = str(势力状态.get(势力, "鼎盛"))
		var 实力: int = int(势力实力.get(势力, 5000))
		# 实力自然波动
		var 波动: int = randi() % 500 - 200
		实力 = max(1000, 实力 + 波动)
		势力实力[势力] =实力
		# 状态转换
		if 状态 == "崛起" and 实力 > 7000:
			势力状态[势力] = "鼎盛"
			事件日志.append("★ %s势力崛起，进入鼎盛时期！" % 势力)
		elif 状态 == "鼎盛" and 实力 < 4000:
			势力状态[势力] = "衰落"
			事件日志.append("▼ %s势力衰落，内部混乱！" % 势力)
		elif 状态 == "衰落" and 实力 < 2000:
			势力状态[势力] = "灭亡"
			事件日志.append("◇ %s势力灭亡！资源重新分配！" % 势力)
			# 灭亡后资源分配给其他势力
			var 存活势力: Array = []
			for s in _势力列表:
				if str(势力状态.get(s, "鼎盛")) != "灭亡":
					存活势力.append(s)
			if 存活势力.size() > 0:
				var 分配: int = 实力 / 存活势力.size()
				for s in 存活势力:
					势力实力[s] = int(势力实力.get(s, 5000)) + 分配
		elif 状态 == "灭亡" and randf() < 0.05:
			# 小概率新势力崛起
			势力状态[势力] = "崛起"
			势力实力[势力] = 3000
			事件日志.append("▲ %s势力重新崛起！" % 势力)
	return 事件日志

func 获取势力状态(势力: String) -> Dictionary:
	_初始化势力状态()
	return {
		"势力": 势力,
		"状态": 势力状态.get(势力, "鼎盛"),
		"实力": 势力实力.get(势力, 5000)
	}

func 获取所有势力状态() -> Array:
	_初始化势力状态()
	var result: Array = []
	for 势力 in _势力列表:
		result.append(获取势力状态(势力))
	return result

# ---- P2-2 宗门战争系统（灭宗/臣服） ----
var 进行中宗门战争: Dictionary = {}

func 发起宗门战争(目标宗门: String, 战争目标: String, 出战队伍: Array) -> Dictionary:
	if not 进行中宗门战争.is_empty():
		return {"成功": false, "原因": "已有进行中的宗门战争"}
	if 出战队伍.is_empty():
		return {"成功": false, "原因": "未选择出战队伍"}
	# 计算攻方战力
	var 攻方战力: int = 0
	for d in 出战队伍:
		if d != null:
			攻方战力 += int(d.get("战力", 0))
	# 守方战力（基于目标宗门）
	var 守方战力: int = 攻方战力 / 2 + randi() % 攻方战力
	if 战争目标 == "灭宗":
		守方战力 = int(守方战力 * 1.5)  # 灭宗难度更高
	# 创建战争
	进行中宗门战争 = {
		"目标宗门": 目标宗门,
		"战争目标": 战争目标,  # 灭宗/臣服
		"攻方战力": 攻方战力,
		"守方战力": 守方战力,
		"回合": 0,
		"最大回合": 5,
		"攻方损失": 0,
		"守方损失": 0
	}
	添加纪事("战争", "宗门战争", "向%s发起%s战争！" % [目标宗门, 战争目标], 3)
	return {"成功": true, "战争": 进行中宗门战争.duplicate()}

func 推进宗门战争回合() -> Dictionary:
	if 进行中宗门战争.is_empty():
		return {"成功": false, "原因": "无进行中的宗门战争"}
	var 战争: Dictionary = 进行中宗门战争
	战争["回合"] = int(战争.get("回合", 0)) + 1
	# 战斗结算（受策略影响）
	var 攻方战力: int = int(战争.get("攻方战力", 1000))
	var 守方战力: int = int(战争.get("守方战力", 1000))
	var 策略: String = str(战争.get("当前策略", "进攻"))
	var 攻方胜率: float = float(攻方战力) / float(攻方战力 + 守方战力)
	var 损失倍率: float = 1.0
	var 策略文本: String = ""
	var 回合结果: String = ""
	match 策略:
		"进攻":
			攻方胜率 += 0.1  # 激进进攻，胜率+10%
			损失倍率 = 1.5   # 但失败时损失+50%
			策略文本 = "（全力进攻）"
		"防守":
			攻方胜率 -= 0.1  # 稳守反击，胜率-10%
			损失倍率 = 0.5   # 但失败时损失-50%
			策略文本 = "（稳守反击）"
		"偷袭":
			if int(战争.get("回合", 0)) == 1:
				攻方胜率 += 0.3  # 首回合偷袭，胜率+30%
				策略文本 = "（夜袭敌营）"
			else:
				策略文本 = "（偷袭已被识破）"
		"谈判":
			# 谈判：有概率直接结束战争
			var 谈判成功率: float = 0.3 + float(min(攻方战力, 守方战力)) / float(max(攻方战力, 守方战力)) * 0.3
			if randf() < 谈判成功率:
				战争["回合"] = int(战争.get("最大回合", 5))  # 直接结束
				var 赔偿: int = min(攻方战力, 守方战力) / 10
				if 攻方战力 >= 守方战力:
					灵石 += 赔偿
					战争["守方战力"] = max(0, 守方战力 - 赔偿)
					回合结果 = "第%d回合：谈判成功，敌方赔偿%d灵石，双方罢兵" % [int(战争["回合"]), 赔偿]
				else:
					灵石 = max(0, 灵石 - 赔偿)
					战争["攻方战力"] = max(0, 攻方战力 - 赔偿)
					回合结果 = "第%d回合：谈判成功，我方赔偿%d灵石，双方罢兵" % [int(战争["回合"]), 赔偿]
				添加纪事("战争", "宗门战争回合", 回合结果, 2)
				进行中宗门战争 = {}
				return {"成功": true, "回合结果": 回合结果, "战争结束": true, "战争结果": "谈判罢兵", "战后处理": "双方各退一步", "当前战争": 战争.duplicate()}
			else:
				攻方胜率 -= 0.05  # 谈判破裂，士气受损
				策略文本 = "（谈判破裂）"
	攻方胜率 = clamp(攻方胜率, 0.05, 0.95)
	if randf() < 攻方胜率:
		var 损失: int = int(守方战力 / 4 * 损失倍率)
		战争["守方损失"] = int(战争.get("守方损失", 0)) + 损失
		战争["守方战力"] = max(0, 守方战力 - 损失)
		回合结果 = "第%d回合%s：攻方胜，守方损失%d道行" % [int(战争["回合"]), 策略文本, 损失]
	else:
		var 损失: int = int(攻方战力 / 4 * 损失倍率)
		战争["攻方损失"] = int(战争.get("攻方损失", 0)) + 损失
		战争["攻方战力"] = max(0, 攻方战力 - 损失)
		回合结果 = "第%d回合%s：守方胜，攻方损失%d道行" % [int(战争["回合"]), 策略文本, 损失]
	# 检查战争结束
	var 战争结束: bool = false
	var 战争结果: String = ""
	var 战后处理: String = ""
	if int(战争.get("回合", 0)) >= int(战争.get("最大回合", 5)):
		战争结束 = true
		if int(战争.get("攻方战力", 0)) > int(战争.get("守方战力", 0)):
			战争结果 = "攻方胜利！"
			if str(战争.get("战争目标", "")) == "灭宗":
				战后处理 = "灭宗成功！获得对方全部资源"
				灵石 += 2000
				声望 += 100
				业力 += 20
			else:
				战后处理 = "对方臣服！成为附庸宗门"
				灵石 += 1000
				声望 += 50
		else:
			战争结果 = "守方胜利！"
			var 损失: int = 500 + randi() % 500
			灵石 = max(0, 灵石 - 损失)
			战后处理 = "攻方失利，损失%d灵石" % 损失
	elif int(战争.get("攻方战力", 0)) <= 0:
		战争结束 = true
		战争结果 = "攻方全军覆没，守方胜利！"
		灵石 = max(0, 灵石 - 1000)
		战后处理 = "惨败，损失1000灵石"
	elif int(战争.get("守方战力", 0)) <= 0:
		战争结束 = true
		战争结果 = "守方全军覆没，攻方胜利！"
		if str(战争.get("战争目标", "")) == "灭宗":
			战后处理 = "灭宗成功！获得对方全部资源"
			灵石 += 3000
			声望 += 150
			业力 += 30
		else:
			战后处理 = "对方臣服！成为附庸宗门"
			灵石 += 1500
			声望 += 80
	# 记录
	添加纪事("战争", "宗门战争回合", 回合结果, 2)
	if 战争结束:
		添加纪事("战争", "宗门战争结束", 战争结果 + " " + 战后处理, 3)
		进行中宗门战争 = {}
	return {"成功": true, "回合结果": 回合结果, "战争结束": 战争结束, "战争结果": 战争结果, "战后处理": 战后处理, "当前战争": 战争.duplicate()}

# 设置战争策略（进攻/防守/谈判/偷袭）
func 设置战争策略(策略: String) -> Dictionary:
	if 进行中宗门战争.is_empty():
		return {"成功": false, "原因": "无进行中的宗门战争"}
	var 合法策略: Array = ["进攻", "防守", "谈判", "偷袭"]
	if 策略 not in 合法策略:
		return {"成功": false, "原因": "未知策略"}
	进行中宗门战争["当前策略"] = 策略
	var 策略说明: Dictionary = {
		"进攻": "全力进攻，胜率+10%，但失败损失+50%",
		"防守": "稳守反击，胜率-10%，但失败损失-50%",
		"谈判": "尝试谈判罢兵，成功则直接结束战争",
		"偷袭": "首回合夜袭，胜率+30%，之后被识破"
	}
	添加纪事("战争", "战争策略", "我方改取【%s】之策：%s" % [策略, str(策略说明.get(策略, ""))], 1)
	return {"成功": true, "策略": 策略, "说明": str(策略说明.get(策略, ""))}

func 获取进行中宗门战争() -> Dictionary:
	return 进行中宗门战争.duplicate()

# ---- P2-3 幕后黑手/合纵连横 ----
var 暗中支持势力: String = ""  # 暗中支持的势力
var 挑拨离间记录: Array = []

func 暗中支持(势力: String, 支持类型: String, 数量: int) -> Dictionary:
	if 势力 == "":
		return {"成功": false, "原因": "未选择支持势力"}
	_初始化势力状态()
	var 结果: Dictionary = {"支持势力": 势力, "支持类型": 支持类型}
	if 支持类型 == "灵石":
		if 灵石 < 数量:
			return {"成功": false, "原因": "灵石不足"}
		灵石 -= 数量
		势力实力[势力] = int(势力实力.get(势力, 5000)) + 数量 / 2
		结果["描述"] = "暗中向%s提供%d灵石支持" % [势力, 数量]
	elif 支持类型 == "物资":
		if 灵石 < 数量 / 2:
			return {"成功": false, "原因": "灵石不足（物资折算）"}
		灵石 -= 数量 / 2
		势力实力[势力] = int(势力实力.get(势力, 5000)) + 数量 / 4
		结果["描述"] = "暗中向%s提供物资支持" % 势力
	elif 支持类型 == "情报":
		if 灵石 < 数量 / 4:
			return {"成功": false, "原因": "灵石不足（情报折算）"}
		灵石 -= 数量 / 4
		势力实力[势力] = int(势力实力.get(势力, 5000)) + 数量 / 8
		结果["描述"] = "暗中向%s提供情报支持" % 势力
	else:
		return {"成功": false, "原因": "未知支持类型"}
	暗中支持势力 = 势力
	声望 -= 10  # 暗中操作降低声望
	业力 += 5
	添加纪事("外交", "暗中支持", 结果["描述"], 2)
	结果["成功"] = true
	return 结果

func 挑拨离间(势力A: String, 势力B: String) -> Dictionary:
	if 势力A == 势力B:
		return {"成功": false, "原因": "不能挑拨同一势力"}
	_初始化势力状态()
	# 挑拨成功率（基于双方关系）
	var 关系: String = 获取阵营关系(势力A, 势力B)
	var 成功率: float = 0.3
	if 关系 == "敌对":
		成功率 = 0.6
	elif 关系 == "友好":
		成功率 = 0.1
	if randf() < 成功率:
		# 挑拨成功，双方实力下降
		势力实力[势力A] = max(1000, int(势力实力.get(势力A, 5000)) - 200)
		势力实力[势力B] = max(1000, int(势力实力.get(势力B, 5000)) - 200)
		挑拨离间记录.append({"势力A": 势力A, "势力B": 势力B, "结果": "成功"})
		声望 -= 20
		业力 += 10
		添加纪事("外交", "挑拨离间", "成功挑拨%s与%s的关系！" % [势力A, 势力B], 2)
		return {"成功": true, "描述": "挑拨成功！%s与%s关系恶化，双方实力下降" % [势力A, 势力B]}
	else:
		挑拨离间记录.append({"势力A": 势力A, "势力B": 势力B, "结果": "失败"})
		添加纪事("外交", "挑拨离间", "挑拨%s与%s失败" % [势力A, 势力B], 1)
		return {"成功": false, "原因": "挑拨失败，对方不为所动"}

func 合纵连横(目标势力: String, 结盟势力: Array) -> Dictionary:
	if 结盟势力.size() < 2:
		return {"成功": false, "原因": "至少需要2个势力结盟"}
	_初始化势力状态()
	# 合纵连横成功率
	var 成功率: float = 0.4
	if randf() < 成功率:
		# 结盟成功，结盟势力实力提升
		for 势力 in 结盟势力:
			势力实力[势力] = int(势力实力.get(势力, 5000)) + 500
		声望 += 30
		添加纪事("外交", "合纵连横", "成功促成%s等%d个势力结盟！" % [目标势力, 结盟势力.size()], 3)
		return {"成功": true, "描述": "合纵连横成功！%d个势力结盟，共同对抗%s" % [结盟势力.size(), 目标势力]}
	else:
		添加纪事("外交", "合纵连横", "合纵连横失败" , 1)
		return {"成功": false, "原因": "合纵连横失败，势力间存在分歧"}

func 获取暗中支持状态() -> Dictionary:
	return {"暗中支持势力": 暗中支持势力, "挑拨记录": 挑拨离间记录.duplicate()}

# ---- P2-4 龙族/上古凶兽稀有刷新 ----
var 稀有怪物刷新: Dictionary = {}  # 当前刷新的稀有怪物
var 稀有怪物刷新历史: Array = []

func 稀有怪物月度刷新检查() -> Dictionary:
	# 如果已有刷新中的稀有怪物，不重复刷新
	if not 稀有怪物刷新.is_empty():
		return {"刷新": false, "原因": "已有稀有怪物"}
	# 低概率刷新（5%）
	if randf() > 0.05:
		return {"刷新": false}
	# 随机选择稀有怪物类型
	var 稀有类型: Array = ["龙族", "上古凶兽", "上古神兽", "域外天魔"]
	var 类型: String = 稀有类型[randi() % 稀有类型.size()]
	var 怪物名: String = ""
	var 战力: int = 0
	var 掉落: String = ""
	if 类型 == "龙族":
		var 龙族列表: Array = ["青龙", "应龙", "蛟龙", "火龙", "冰龙"]
		怪物名 = 龙族列表[randi() % 龙族列表.size()]
		战力 = 5000 + randi() % 3000
		掉落 = "龙鳞+龙角+龙珠"
	elif 类型 == "上古凶兽":
		var 凶兽列表: Array = ["饕餮", "穷奇", "梼杌", "混沌", "相柳"]
		怪物名 = 凶兽列表[randi() % 凶兽列表.size()]
		战力 = 6000 + randi() % 4000
		掉落 = "凶兽内丹+凶兽皮+上古材料"
	elif 类型 == "上古神兽":
		var 神兽列表: Array = ["白虎", "朱雀", "玄武", "麒麟", "白泽"]
		怪物名 = 神兽列表[randi() % 神兽列表.size()]
		战力 = 7000 + randi() % 3000
		掉落 = "神兽精血+神兽羽+神兽传承"
	else:
		var 天魔列表: Array = ["域外天魔", "深渊恶魔", "虚空魔神", "混沌天魔"]
		怪物名 = 天魔列表[randi() % 天魔列表.size()]
		战力 = 8000 + randi() % 4000
		掉落 = "天魔晶+魔核+域外材料"
	# 创建稀有怪物
	稀有怪物刷新 = {
		"名称": 怪物名,
		"类型": 类型,
		"战力": 战力,
		"掉落": 掉落,
		"状态": "可挑战",
		"剩余时间": 3  # 3个月后消失
	}
	稀有怪物刷新历史.append(稀有怪物刷新.duplicate())
	添加纪事("事件", "稀有怪物刷新", "★ %s（%s）出现！道行%d，掉落：%s" % [怪物名, 类型, 战力, 掉落], 3)
	return {"刷新": true, "怪物": 稀有怪物刷新.duplicate()}

func 挑战稀有怪物(出战队伍: Array) -> Dictionary:
	if 稀有怪物刷新.is_empty():
		return {"成功": false, "原因": "当前无稀有怪物"}
	if 出战队伍.is_empty():
		return {"成功": false, "原因": "未选择出战队伍"}
	# 计算攻方战力
	var 攻方战力: int = 0
	for d in 出战队伍:
		if d != null:
			攻方战力 += int(d.get("战力", 0))
	var 守方战力: int = int(稀有怪物刷新.get("战力", 5000))
	var 胜率: float = float(攻方战力) / float(攻方战力 + 守方战力)
	胜率 = clamp(胜率, 0.1, 0.9)
	var 结果: Dictionary = {"怪物名称": 稀有怪物刷新.get("名称", "")}
	if randf() < 胜率:
		# 胜利
		灵石 += 1000 + randi() % 1000
		悟道点 += 50
		声望 += 30
		结果["胜利"] = true
		结果["奖励"] = "灵石%d、悟道点50、声望30、%s" % [1000 + randi() % 1000, str(稀有怪物刷新.get("掉落", ""))]
		结果["描述"] = "击败%s！获得：%s" % [str(稀有怪物刷新.get("名称", "")), 结果["奖励"]]
		添加纪事("战斗", "稀有怪物击杀", 结果["描述"], 3)
	else:
		# 失败
		var 损失: int = 300 + randi() % 300
		灵石 = max(0, 灵石 - 损失)
		结果["胜利"] = false
		结果["损失"] = 损失
		结果["描述"] = "挑战%s失败，损失%d灵石" % [str(稀有怪物刷新.get("名称", "")), 损失]
		添加纪事("战斗", "稀有怪物挑战失败", 结果["描述"], 2)
	# 挑战后稀有怪物消失
	稀有怪物刷新 = {}
	结果["成功"] = true
	return 结果

func 稀有怪物月度推进() -> void:
	if 稀有怪物刷新.is_empty():
		return
	var 剩余: int = int(稀有怪物刷新.get("剩余时间", 3)) - 1
	if 剩余 <= 0:
		添加纪事("事件", "稀有怪物消失", "%s消失了..." % str(稀有怪物刷新.get("名称", "")), 2)
		稀有怪物刷新 = {}
	else:
		稀有怪物刷新["剩余时间"] = 剩余

func 获取当前稀有怪物() -> Dictionary:
	return 稀有怪物刷新.duplicate()

func 获取稀有怪物刷新历史() -> Array:
	return 稀有怪物刷新历史.duplicate()

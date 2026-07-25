# GDD-战斗系统进阶_S1批3：Buff 系统 + 功法实体

> 版本：S1 批3 v1.0（设计稿，待主理人批3决策会拍板）
> 作者：文策渊（design-strategist）
> 状态：**可落地设计文档 · 不直接改游戏代码 · 仅产出设计决策**
> 对接文档：GDD-战斗与道心.md（§9.3/§9.4/§9.5/§9.7/§9.8.5/§9.10）、GDD-弟子养成.md、S0-S1-S2阶段规划 §4.2、S1-S2功能储备清单
> 现役代码核实：BattleCalculator.gd / BattleManager.gd / disciple.gd / item.gd / csv_validator.gd / config/skill.csv / config/skill_cultivation.csv（均已 Read 核实，下文落地点以实际代码为准）

---

## 0. 执行摘要（给主理人 / engineering-lead）

**本批是 S1 体量最大的战斗核心改动，但落地策略是「机制全部接通、现役战斗零变化」**——靠「默认无数据驱动」实现低风险。

| 子项 | 本批落地结论 | 回归风险 |
|---|---|---|
| 1. Buff 系统 | 新建 `battle_buff.csv` + `结算_1v1` 内函数级 active_buffs 生命周期（局部工作态，不回写快照） | **低** |
| 2. 功法实体 | 复用 `skill_cultivation.csv`；填充 `_聚合未来战力来源` 的「功法加成」TODO；新增 `已修功法` 字段（默认 `[]`） | **低**（默认空→零战斗变化） |
| 3. 战斗日志扩展 | 新增 `log_type` + 填充已有 `ref_*` 占位字段；UI 点击联动留批4 | **低** |
| 4. 装备加成统一链路 | **审计结论＝已满足**（机制已落地）；本批只固化文档，不改链路 | **无** |

**★ 主理人最关键输入：现役战斗循环是否需要「从快照一次性结算」重构为「逐回合状态化」？**
**结论：不需要重构。** 详见 §7.3。简言之：`BattleManager` 的车轮编排层（while 循环按对调用 `结算_1v1`）保持不变；`结算_1v1` 本就是回合内循环，本批只在**该函数内部**引入「单位工作态」（base+current 属性 split、active_buffs、cooldown、mp），全部为**函数局部变量**，不 mutate 调用方快照（ADR-003 安全，且 1v1 模式不再需 `duplicate`）。当快照不含 `技能`/`active_buffs` 时，行为与今日 100% 一致 → Sprint-03 的 72 条战斗断言不回归。

**唯一中风险点**：base/current 属性拆分或 hp 追踪若实现错误会令伤害数字漂移。缓解＝`calc_hit_damage` 签名与内部**完全不改**，只给它传一个「键名与今日快照一致」的瞬时 `actor_view` 字典。验收以 72 断言不回归为硬门槛。

**文档偏差**：发现 6 处 GDD 与代码不符（回合上限 20≠30、防御减伤 200≠60×等级、减伤上限 0.75≠0.70、skill_type 枚举不符、§9.5.1 ×1.8 攻击乘区未落地、skill 命名空间不一致），全部 **以代码为准**，清单见附录 A。

---

## 1. 概述

### 1.1 范围
S1 批3 在「不破坏 ADR-003 纯函数结算层、不引入 Game/实例依赖、不堆虚高战力」三条铁律下，为战斗核心接入四类能力：Buff 生命周期、功法实体（被动属性 + 技能释放/冷却）、战斗日志结构化扩展、装备加成统一链路审计固化。

### 1.2 设计支柱（2 条，贯穿全批）
- **P1 状态化而非数值膨胀**：所有战斗差异通过「单位携带状态（buff/cooldown/mp）按回合流转」表达，绝不直接堆总战力；任何属性增益必须折算 攻防血速（入口 `get_final_combat_attr`）。
- **P2 默认零影响、显式开启**：新机制全部以「快照携带数据才生效」为前提；现役快照不含 `技能`/`active_buffs`/`已修功法` → 行为不变，杜绝回归。

### 1.3 不目标（守边界）
- 不做手动操作 UI（游戏为度假式自动推演，仅自动 AI，§9.8.5）。
- 不做 Buff/技能跨车轮战保留（3v3 逐对独立，见 §7.2）。
- 不做功法养成/参悟 UI（数据填充留批4；本批只接通机制 + 入口）。
- 不重构 `BattleCalculator`/`BattleManager` 架构、不引入 Game 单例进结算层。

---

## 2. 目标

### 2.1 玩家心理映射（MDA / 自我决定论 / 心流 / Bartle）
- **MDA**：Mechanic＝单位状态流转（buff/cd/mp）；Dynamic＝「读条-释放-冷却」节奏；Aesthetic＝策略性自动推演的「养成兑现感」。
- **自我决定论**：胜任感（功法被动让养成数值在战斗中可见兑现）、自主性（技能释放优先级策略）、关联感（功法→技能解锁链）。
- **心流**：技能冷却 + 灵力约束形成「资源节奏」，避免无脑普攻的单调；但自动推演下不提高操作门槛。
- **Bartle**：成就型（功法收集/参悟）为主，杀手型（技能 combo）为辅；本批不服务社交/探索型。

### 2.2 范围分层
- **MVP（本批必做）**：Buff 生命周期（4 类）+ 技能释放/冷却机制 + 日志扩展 + 装备链路审计固化。
- **目标（本批机制 + 数据待批4）**：功法被动实际生效（需 `已修功法` 数据）、Buff/技能在 3v3 跨对保留。
- **愿景（后续）**：多职业（御兽师/符箓师/毒师/傀儡师）技能、手动操作、功法参悟 UI。

---

## 3. 机制（核心 · 逐子项落地）

### 3.1 子项1 · Buff 系统

#### 3.1.1 现役代码现状（已核实）
- `BattleCalculator.gd::结算_1v1`（L136-211）：回合循环已存在（L152 `while true`），每回合 `出手序`（L157-161）依次普攻；**无** active_buffs、无技能释放、无冷却、无 mp。伤害经 `calc_hit_damage`（L110-130）纯函数结算。
- `BattleManager.gd`：仅接收 CombatantData 快照数组；`_log_entry`（BC L270-295）**已预留** `log_type/tags/extra/ref_type/ref_id/ref_name` 字段（S0 预埋），本批复用。
- 战斗代码内**无任何** active_buffs 生命周期、无增益/减益/dot/控制 处理 → 本批为净新增。

#### 3.1.2 落地点（ADR-003 合规：纯函数、快照内状态流转）
| 步骤 | 文件 / 函数 | 改动 |
|---|---|---|
| 单位工作态初始化 | `BattleCalculator.gd::结算_1v1` 函数开头 | 对 `atk`/`def` 各建 **局部** `单位状态`：`{base属性, cur属性, active_buffs:[], cooldowns:{}, mp, mp_max}`，深拷贝快照 `属性` 进 base/cur（**不**改调用方 `atk`/`def`） |
| 回合开始 tick | `结算_1v1` 回合循环内、`出手序` 之前 | 按 §9.7.2 顺序结算：持续伤害→控制→增益→减益→灵力回复 |
| 控制跳过行动 | `出手序` 遍历内 | 若 actor 含 `控制` 类 active_buff → 跳过其本次行动（仍 tick 其余） |
| 属性重算 | tick 后、行动前 | `cur属性 = base属性 + Σ(增益buff) − Σ(减益buff)`；`速` 变动时按 `get_final_combat_attr` 口径（速×0.004/0.003 + 灵根修正）重算该单位 `闪避率/暴击率` |
| 消散判定 | tick 末尾 | `剩余回合 -= 1`；`<=0` 则移出 `active_buffs` 并写一条 `buff_expire` 日志 |
| 施加入口 | 技能释放 / 道具 / 进场被动 | 调 `_施加buff(单位状态, buff模板, 数值)` 推入 `active_buffs` |

> **关键**：`calc_hit_damage` **不改**。行动时给它传 `actor_view = 快照.merge(cur属性)`，键名与今日一致，`actor_view["属性"] = cur属性`。保证现役普攻路径数学不变。

#### 3.1.3 active_buffs 运行时结构（单位工作态内，非 CSV）
```
active_buff = {
  "buff_id":   String,        # 关联 battle_buff.csv
  "类型":      "增益|减益|dot|控制",
  "作用属性":  "攻|防|血|速|灵力|全",
  "数值":      float,
  "数值类型":  "flat|percent|none",
  "剩余回合":  int,           # 每回合开始 -1
  "来源":      String,        # skill_id / item_id / passive / environment
  "可叠加":     bool,
  "层数":       int            # 可叠加时累加，默认1
}
```

#### 3.1.4 `battle_buff.csv` schema（新建 · 必须注册 csv_validator）
```
buff_id,buff名,类型,作用属性,数值,数值类型,持续回合,来源类型,可叠加,备注
```
- `buff_id`：主键，如 `bf_burn`/`bf_freeze`/`bf_stun`/`bf_shield`/`bf_atkup`/`bf_defdown`/`bf_defup`/`bf_spdup`/`bf_regen`
- `类型`：enum `增益|减益|dot|控制`
- `作用属性`：enum `攻|防|血|速|灵力|全`
- `数值`：float；dot＝每回合伤害比例（对当前气血）/flat；控制＝0；增益/减益＝属性增量
- `数值类型`：enum `flat|percent|none`
- `持续回合`：int > 0；控制＝眩晕/冰冻回合数；dot＝持续回合
- `来源类型`：enum `skill|item|passive|environment`
- `可叠加`：bool（同 buff_id 是否叠层/刷新）
- 样例行（数值待校准，标 `[PLACEHOLDER]`）：
  `bf_burn,灼烧,dot,血,0.05,percent,2,skill,false,每回合损失5%当前气血`
  `bf_freeze,冰冻,控制,全,0,none,1,skill,false,冻结1回合无法行动`
  `bf_stun,眩晕,控制,全,0,none,1,skill,false,眩晕1回合`
  `bf_shield,护盾,增益,血,[PLACEHOLDER],flat,[PLACEHOLDER],skill,false,吸收等同于最大气血比例伤害`
  `bf_atkup,攻击增益,增益,攻,[PLACEHOLDER],percent,[PLACEHOLDER],skill,true,攻击提升`
  `bf_defdown,破甲,减益,防,[PLACEHOLDER],percent,[PLACEHOLDER],skill,false,防御降低`

#### 3.1.5 §9.7.2 结算顺序落地伪代码（置于 `结算_1v1` 回合循环内）
```
每回合开始（出手序之前）:
  for 单位 in [攻方态, 守方态]:
    # ① 持续伤害 dot
    for b in 单位.active_buffs if b.类型=="dot":
      损 = int(单位.cur属性.血 * b.数值) if b.数值类型=="percent" else int(b.数值)
      单位.hp -= max(1, 损)            # 伤害下限兜底（对齐 AC7①）
      写日志(buff_tick, ref=buff_id)
    # ② 控制状态（仅标记，行动阶段跳过）
    # ③ 增益 buff → 重算 cur属性（base + Σ增益 − Σ减益）
    # ④ 减益 buff → 同上
    重算单位.cur属性; 若速变→重算闪避率/暴击率
    # ⑤ 灵力回复
    单位.mp = min(单位.mp_max, 单位.mp + 灵力回复值)   # 灵力回复值见 §4
    # 消散
    for b in 单位.active_buffs: b.剩余回合 -= 1
    移除 剩余回合<=0 的 b（写 buff_expire 日志）
```

#### 3.1.6 控制状态跳过行动
`出手序` 遍历中，若该 `actor` 工作态含 `类型=="控制"` 的 active_buff → 跳过本次普攻/技能（写一条 `log_type="control_skip"` 占位日志或静默），但**仍参与本回合 dot/增益 tick**（已在回合开始处理）。控制 buff 不阻止其受击。

---

### 3.2 子项2 · 功法实体

#### 3.2.1 决策：复用 `skill_cultivation.csv`（不新建 gongfa.csv）
**理由（给主理人）**：
1. `skill_cultivation.csv` 本就是「功法/参悟」配置表（39 行，覆盖 7 品阶 × 4 类型 `攻击/控制/辅助防御/通用`，字段含 `effect_value` 被动增益、`unlock_realm` 解锁境界、`learn_cost` 参悟消耗），与「功法＝被动属性」定义吻合。
2. 新建 `gongfa.csv` 会重复数据、引发 schema 漂移、增加 pre_f5 注册负担（双 CSV 校验），违背「数据层不可动 / 保守」铁律。
3. `skill.csv` 已是「主动战斗技能」表（含 `damage_rate/cooldown/mp_cost/effect_type`）。「功法解锁/升级 skill.csv 技能」通过**数据链接**实现，而非新表。

> **文档偏差预警**：`skill_cultivation.csv` 的 `skill_id` 命名空间为 `sk_001`…，`skill.csv` 为 `sk_ti_01`…，两者**不互通**。故「功法→解锁 skill.csv 技能」的链接数据**当前不存在**（见 §3.2.5 数据缺口，留批4）。

#### 3.2.2 功法被动 → `get_final_combat_attr` 入口（填充 TODO）
`disciple.gd::_聚合未来战力来源`（L1122-1134）已有 `TODO(S1): 功法加成 = 主修功法.四维加成`。本批**填充**该 TODO：
```
func _聚合未来战力来源() -> Dictionary:
    var 聚合 = {"攻":0,"防":0,"血":0,"速":0}
    # 功法被动（本批新增；已修功法为空则贡献0，现役战斗零变化）
    for gid in 已修功法:
        var g = _查功法(skill_cultivation, gid)   # .get 默认防空
        if g == null: continue
        var 加成 = _功法四维加成(g)               # 受 §4 上限约束，[PLACEHOLDER]
        聚合[四维] += 加成
    # 灵兽（既有，不动）
    var 兽 = 灵兽属性加成()
    for _st in ["攻","防","血","速"]: 聚合[_st] += 兽.get(_st, 0)
    return 聚合
```
**战力映射铁律守边界**：功法被动**只**经此入口加为 攻防血速 增量，不堆 `总战力()` 虚高。由于默认 `已修功法=[]`，本批现役战斗零变化。

#### 3.2.3 新增字段 `已修功法`（默认 `[]`，数据层兼容）
- `disciple.gd` 新增 `var 已修功法: Array[String] = []`（与 `背包/装备` 同级）。
- `to_dict`/`from_dict` 用 `.get("已修功法", [])` 兼容旧档（空数组默认）。
- `get_final_combat_attr` 在返回字典中**新增** `"技能": [...skill_id...]`（由 `已修功法` 解析出可释放技能，批4 数据就绪后填充；本批恒为 `[]`）与 `"功法被动": {...}`（本批恒为 `{攻:0,防:0,血:0,速:0}`）。

#### 3.2.4 技能释放 + 冷却（回合行动阶段 · 自动 AI §9.8.5）
在 `结算_1v1` 的 `出手序` 行动步内，普攻前插入 `_选择技能(actor态, 战场上下文)`：
- **就绪判定**：快照 `技能` 含某 `skill_id` 且 `actor态.cooldowns[skill_id]==0` 且 `actor态.mp >= skill.mp_cost`。
- **选技规则（§9.8.5 自动我方 AI）**：优先冷却好的高 `damage_rate` 技能；体修 `hp < 50%×maxhp` 优先护盾/防御技；法修敌方多存活优先群体技（`target_type` 含「全体/前排全体」）；敌方仅 1 单位优先单体高伤。
- **释放效果**：`伤害 = calc_hit_damage(actor_view×damage_rate, target)` → 施加减益/dot/控制 buff（由 `skill.effect_type` 映射 `battle_buff` 模板，`skill.effect_value` 作数值）→ 写 `cast_skill` 日志（带 `ref_skill_id`）→ `cooldowns[skill_id]=skill.cooldown` → `mp -= skill.mp_cost`。
- **冷却 tick**：每回合结束（出手序之后）`for k: cooldowns[k]=max(0,cooldowns[k]-1)`。
- **现役零影响**：快照无 `技能` → 该分支恒不触发 → 仅普攻，与今日一致。

#### 3.2.5 skill.csv → buff 映射（**不改 skill.csv schema**，代码内查表）
`skill.csv` 的 `effect_type`/`effect_value` 直接映射 `battle_buff.csv` 模板（避免双源）。现有 16 技能映射（节选）：

| skill | effect_type | 映射 buff | 数值来源 |
|---|---|---|---|
| 磐石护盾 | 护盾 | bf_shield | effect_value 0.15 |
| 裂山反击 | 反击 | （批4 反击机制，本批预留 log） | 0.8 |
| 厚土之躯(被动) | 减伤 | 进场的常驻增益（非 battle_buff，走 §3.2.2 被动） | 0.08 |
| 山岳镇压 | 伤害+控制 | 伤害 + bf_stun | 0.3 概率 |
| 破甲剑诀 | 伤害+破甲 | 伤害 + bf_defdown | 0.1 |
| 玄金斩 | 伤害+暴击 | 伤害 + 临时 bf_critup（[PLACEHOLDER]） | 0.2 |
| 烈焰波动 | 伤害+灼烧 | 伤害 + bf_burn | 0.05 |
| 寒冰禁锢 | 伤害+冰冻 | 伤害 + bf_freeze | 0.4 概率 |
| 天火燎原 | 伤害+灼烧 | 伤害 + bf_burn(升级为真伤，[PLACEHOLDER]) | 1.0 |

> 映射表实现为 `BattleCalculator` 内 `static func _skill_buff映射(skill: Dictionary) -> Array[Dictionary]`（返回要施加的 buff 列表）。**不修改 `skill.csv` 任何列** → pre_f5 零风险。

#### 3.2.6 数据缺口（留批4 / 后续，本批只标接口）
- 功法→skill.csv 解锁链接：`skill_cultivation.csv` 增 ADD-ONLY 列 `unlock_skill`（默认 `""`，指向 `skill.csv.skill_id`），待批4 参悟 UI 填充。
- 多职业（御兽师/符箓师/毒师/傀儡师）技能：本批仅 3 核心职业（数据已存在），其余 `[PLACEHOLDER]`。

---

### 3.3 子项3 · 战斗日志扩展

#### 3.3.1 新增 `log_type`（复用 `_log_entry` 既有 `ref_*` 字段）
| log_type | 触发 | 必填 ref 字段 |
|---|---|---|
| `cast_skill` | 技能释放 | `ref_type="skill"`, `ref_id=skill_id`, `ref_name=skill_name` |
| `buff_apply` | buff 施加 | `ref_type="buff"`, `ref_id=buff_id`, `ref_name=buff名` |
| `buff_tick` | dot 每回合结算 | 同上 |
| `buff_expire` | buff 消散 | 同上 |
| `control_skip` | 被控跳过行动 | `ref_type="buff"` |
| `item_use` | 道具使用（**本批仅预留类型，机制留后续**） | `ref_type="item"` |

> `ref_type/ref_id/ref_name` 字段**已于 S0 预埋**（`BattleCalculator._log_entry` L292-294），本批只**填充**它们，不新增字段 → 打印/存储兼容。

#### 3.3.2 `_log_entry` 与 `打印战斗` 扩展
- `_log_entry` 增加对上述 `log_type` 的构造分支（保持既有 `round/actor/target/damage/attacker_hp/defender_hp` 键；非伤害类 `damage=0`）。
- `BattleManager.打印战斗`（L129-143）**必须**对新增 `log_type` 增加分支（文本摘要，如 `R3 攻方→守方 释放[寒冰禁锢] 施加冰冻`），否则 D7 调试输出会漏打/格式错。此改动 additive。

#### 3.3.3 边界（严守）
- **本批只产出日志数据结构 + 生成逻辑**；UI 点击联动渲染属批4，本批仅预留 `ref` 字段，不实现点击、不引入 UI 依赖。
- `item_use` 类型本批仅占位（自动推演下道具使用机制未定），不实现实际消耗。

---

### 3.4 子项4 · 装备加成统一链路（审计结论＝已满足）

#### 3.4.1 审计结论（已 Read 核实 `disciple.gd::get_final_combat_attr` L919-999）
装备加成**已**统一折算进 攻防血速 真实属性，机制完整，无需补代码：
1. **装备→攻防血速**（L943-965）：`槽位映射` 按 9 个槽位把 `装备基础战力()` flat 分发到 攻/防/血/速（加法叠加，非堆总战力）。
2. **战斗命格→攻防血速**（L966-969）：战斗型命格按维度等比乘性。
3. **境界倍率→攻防血速**（L970-974）：`境界战斗倍率` 乘入四维。
4. **灵兽→攻防血速**（L978-980 经 `_聚合未来战力来源`→`灵兽属性加成`）。
5. **负责人全局 buff→攻防血速**（L983-985）。
→ 全链路守「战力映射铁律」：任何加总战力均折算 攻防血速，无虚高裸属性。

#### 3.4.2 本批动作
- **审计确认 + 文档固化**（本文件即固化），**不改任何装备/折算代码**。
- 仅补充：把「功法被动」接入同一 `_聚合未来战力来源` 入口（§3.2.2），与装备/灵兽同链路、同铁律。

#### 3.4.3 审计验收点（pre_f5 友好，见 §8）
- 断言：对任意已穿戴单位，`get_final_combat_attr()["属性"][四维]` ≥ 其 `属性` 基础值（装备只增不减）。
- 断言：`总战力()` 与 `实时战力()`（经 `BattleCalculator.战力度量`）同向变动，无「总战力涨、实战属性不涨」脱钩。

---

## 4. 数值（守边界 · 不冲击基线）

### 4.1 对齐现役上限（以代码为准，详见附录 A）
| 上限 | 现役代码值 | 来源 |
|---|---|---|
| 攻击加成乘区软上限 | ×1.8（**代码未实现**，仅 GDD §9.5.1 规定；本批功法走 flat 攻防血速，不直接命中该乘区） | §9.5.1 |
| 防御减伤硬上限 | `防御减伤上限=0.75` | BC L44 |
| 通用增益软/硬 | 软 25% / 硬 30%（`_clamp_soft(0.25,0.30,0.2)`） | disciple L210 |
| 暴击率/闪避率 | 0.70 / 0.40 | BC L47-48 |
| 回合上限 | 20 | BC L60 |

### 4.2 本批数值建议（未实测全部标 `[PLACEHOLDER]`）
- **Buff 数值**：dot 每回合伤害 ≤ 当前气血 `[PLACEHOLDER]`%（建议 ≤8%，防秒杀）；增益/减益 单 buff ≤ `[PLACEHOLDER]`%（建议 ≤15%）；控制持续 ≤ 2 回合（§9.4.2 临时效果 ≤3 回合）。
- **功法被动四维加成**：单功法 ≤ `[PLACEHOLDER]`%；全功法聚合 ≤ `[PLACEHOLDER]`%（建议聚合 ≤ 通用增益硬上限 30% 同量级，防 dominant strategy）。**当前默认 `已修功法=[]` → 实际贡献 0**。
- **灵力（mp）**：初始 `mp=[PLACEHOLDER]`；每回合回复 **10**（取自 §9.7.1「每回合回复 10 点基础灵力」，`[DESIGN_BASELINE]` 已文档化）；`mp_max=[PLACEHOLDER]`。
- **技能冷却**：沿用 `skill.csv.cooldown`（0/2/3/5），不超 validator `max=10`。

### 4.3 不冲击基线原则
- 所有新增增益经 §4.1 上限夹取；dot 有伤害下限兜底（≥1）。
- 现役战斗（无技能/buff/功法数据）数学不变 → 72 断言不回归为硬门槛。

---

## 5. UI 与日志
- **本批无 UI 改动**（纯逻辑 + 日志数据结构）。
- 日志 `ref_*` 字段按批4 消费约定预留：`ref_type ∈ {skill,buff,item}`、`ref_id` 为对应表主键、`ref_name` 为展示名。
- 批4 责任：读取 `battle_log` 中带 `ref_*` 的条目，渲染可点击实体（跳转技能/功法/Buff 详情）。本批不实现。

---

## 6. 联动
- **装备/灵兽/命格/境界**：均经 `get_final_combat_attr` 已折算 攻防血速；Buff/功法在同一快照口径上加成，互不冲突。
- **`skill.csv` / `skill_cultivation.csv`**：前者驱动战斗技能释放，后者驱动功法被动 + （批4）技能解锁；映射经代码查表，不改两表结构。
- **批4 点击联动**：消费本批预留 `ref_*` 字段。
- **`csv_validator.gd`**：`battle_buff.csv` 须在此注册（仿 §9.10.2 `skill` 规则），否则 pre_f5 闸门2（validate_all.py）FAIL。

---

## 7. 边界（本批做 / 不做 / 回归风险）

### 7.1 本批做
1. 新建 `config/battle_buff.csv` + `csv_validator.gd` 注册。
2. `BattleCalculator.结算_1v1` 内 active_buffs 生命周期 + §9.7.2 tick + 控制跳过 + 消散日志。
3. `skill.csv → buff` 代码映射表（不改 skill.csv）。
4. 技能释放 + 冷却机制（auto AI §9.8.5），快照含 `技能` 时生效。
5. `disciple.gd` 填充 `_聚合未来战力来源` 功法 TODO + 新增 `已修功法`（默认 `[]`）+ 快照暴露 `技能`/`功法被动`。
6. 战斗日志新增 `log_type` + 填充 `ref_*`；`打印战斗` 兼容分支。
7. 装备加成统一链路审计固化（本文件）。

### 7.2 本批不做（留批4 / 后续）
- 功法实际养成/参悟 UI 与 `已修功法` 数据填充（批4）。
- 功法→skill.csv 解锁链接列（`skill_cultivation.unlock_skill`，批4）。
- Buff/技能在 3v3 **跨对**保留（本批每 `结算_1v1` 独立；车轮下一位满血由副本保证，buff 不继承——已知限制，批4 可扩展）。
- 多职业（御兽师等）技能、手动操作、道具实际使用（item_use 仅占位）。
- §9.5.1 ×1.8 攻击乘区硬实现（代码暂无，后续统一治理）。

### 7.3 ★ 现役循环重构判定（主理人决策关键输入）
- **是否需要「从快照一次性结算」重构为「逐回合状态化」？→ 否。**
- **理由**：`结算_1v1` 本就是回合循环（BC L152）；「状态」以**函数局部工作态**引入（base/cur 属性、active_buffs、cooldowns、mp），不依赖调用方快照持久化，不改动 `BattleManager` 车轮编排。
- **ADR-003 守边界**：工作态为局部变量，调用方 `atk`/`def` 不被 mutate（1v1 模式无需 `duplicate`；3v3 模式 `BattleManager._实例化` 仍做深拷贝，气血继承经日志 hp 回写，路径不变）。
- **回归风险等级：低（LOW）。** 现役快照无 `技能`/`active_buffs`/`已修功法` → 所有新分支休眠 → 行为与今日一致。
- **唯一中风险点（MEDIUM，可控）**：base/cur 属性拆分或 hp 追踪实现偏差会令伤害漂移。缓解＝`calc_hit_damage` **不改**，仅传键名一致的 `actor_view`；以 72 战斗断言不回归为验收硬门槛。

---

## 8. 验收

### 8.1 pre_f5 友好判定点
1. **CSV 注册**：`battle_buff.csv` 在 `csv_validator.gd::TABLE_RULES` 注册，主键 `buff_id`，字段规则含 类型/作用属性/数值类型/来源类型 enum → 闸门2（validate_all.py）通过。
2. **纯函数可测**：`结算_1v1` 仍 `static func`、无 Game 依赖 → 可在 Python 断言验证（TEST_STRATEGY LOGIC 层），不依赖引擎。
3. **72 断言不回归**：现役普攻路径输出与批3前逐字节一致（比对 `battle_log` 结构 + `is_win`/`round_count`/`remaining_hp`）。

### 8.2 伪代码级边界判定（工程自测清单）
```
# active_buffs 消散判定
for b in 单位.active_buffs:
    b.剩余回合 -= 1
单位.active_buffs = 单位.active_buffs.filter(b => b.剩余回合 > 0)   # 移除过期

# 技能冷却判定
就绪 = (skill_id in 快照.技能) and (cooldowns.get(skill_id,0)==0) and (mp >= skill.mp_cost)
释放后: cooldowns[skill_id] = skill.cooldown; mp -= skill.mp_cost
每回合末: for k: cooldowns[k] = max(0, cooldowns[k]-1)

# 装备折算审计结论（本批结论＝已满足）
断言 已穿戴单位.属性[四维] >= 基础属性[四维]
断言 总战力() 与 实时战力() 同向（无脱钩）
```

### 8.3 文档偏差验收（以代码为准，本批不修正 GDD）
- 回合上限 20（非 GDD 30）；防御减伤基准 200（非 60×等级）；减伤上限 0.75（非 0.70）；`skill_type` 枚举以 skill.csv 为准（普攻/主动/被动天赋）；§9.5.1 ×1.8 乘区代码未落地；skill 两表命名空间不互通。详见附录 A。

---

## 附录 A：文档偏差清单（GDD vs 现役代码，全部以代码为准）

| # | GDD 表述 | 代码现状 | 处置 |
|---|---|---|---|
| A1 | §9.7 单场最高 **30 回合** | `BattleCalculator.回合上限=20`（L60） | **以代码 20 为准**；批3 不改回合上限，避免超时/平衡回归 |
| A2 | §9.5.2 防御减伤率 = 防御/(防御+**60×目标等级**) | `防御减伤基准=200.0` 常数（L43） | **以代码 200 为准**；批3 不碰该常数 |
| A3 | §9.4.2.2 常驻全减伤硬上限 **70%** | `防御减伤上限=0.75`（L44） | 二者为不同 cap（公式 cap vs 堆叠 cap）；**以代码 0.75 为准** |
| A4 | `skill_type` 应为 `攻击/控制/辅助防御/通用` | `csv_validator.SKILL_TYPES` 如此定义，但 `skill.csv` 实际用 `普攻/主动/被动天赋` | **以 skill.csv 为准**；validator enum 与 CSV 不符系 pre_f5 潜在风险，建议批3 同步把 `SKILL_TYPES` 扩为 `{普攻,主动,被动天赋,通用}`（ADD-ONLY，不阻断） |
| A5 | §9.5.1 攻击加成乘区软上限 ×1.8 | 代码仅有 `通用增益` 软25/硬30，**无独立 ×1.8 攻击乘区** | 本批功法走 flat 攻防血速，不命中该乘区；×1.8 落地留后续统一治理 |
| A6 | 功法/技能为同一体系 | `skill_cultivation.csv`(sk_001…) 与 `skill.csv`(sk_ti_01…) **命名空间不互通** | 以代码为准；解锁链接留批4（§3.2.5） |
| A7 | §9.6.1 克制 +20%（1.2）/ 被克 -15%（0.85） | 代码 `纯度克制.单=1.25`（§9.6.2 值），与 §9.6.1 基础 1.2 内部不一致 | **以代码 1.25（单灵根）为准** |

---

## 附录 B：待主理人确认决策点（推荐默认 + `[PLACEHOLDER]`）

| # | 决策点 | 推荐默认 | 待确认 / 占位 |
|---|---|---|---|
| D1 | 功法实体是否复用 `skill_cultivation.csv` | **是**（理由见 §3.2.1） | 若另建 `gongfa.csv` 需评估双表风险 |
| D2 | 功法被动进入战斗的时机 | 机制接通 + `已修功法` 默认 `[]`（零战斗变化） | 是否批3 即 seed 默认功法供测试？建议加测试开关，不进生产平衡 |
| D3 | `battle_buff.csv` 数值校准 | 样例见 §3.1.4 | 全部数值 `[PLACEHOLDER]`，待战斗基线实测 |
| D4 | mp 初始/上限 | 回复=10（§9.7.1） | 初始=`[PLACEHOLDER]`、上限=`[PLACEHOLDER]` |
| D5 | 功法被动四维聚合上限 | 建议 ≤ 通用增益硬上限 30% 同量级 | 具体值 `[PLACEHOLDER]` |
| D6 | `csv_validator.SKILL_TYPES` 与 skill.csv 不符 | 批3 扩 enum 为 `{普攻,主动,被动天赋,通用}` | 是否同步修正（ADD-ONLY） |
| D7 | Buff/技能 3v3 跨对保留 | 本批不做（逐对独立） | 是否批4 扩展（需改气血继承回写逻辑） |

---

> 本文档为设计交付物，未改动任何游戏代码。落地以主理人批3 决策会拍板为准；所有 `[PLACEHOLDER]` 数值须于战斗基线实测后回填，且回填后须保证 72 战斗断言不回归、pre_f5 19 闸门全绿。

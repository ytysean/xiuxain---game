---
doc_id: GDD_战斗扭转类功能
doc_title: 《太玄宗门录》战斗扭转类功能 GDD（替死法宝 / 傀儡挡刀 / 灵宠护主）
doc_version: v1.0
update_date: 2026-07-27
doc_type: 功能提案归档 GDD（战斗内事件扭转类）
game_formal_name: 太玄宗门录
game_market_name: 开局接手太玄宗
game_core_ip: 太玄宗
author: design-strategist（文策渊）
status: 提案归档 · 【S2中期落地 · S1仅配置预留】· 待主理人（游承峰）拍板后交 engineering-lead 落地
version_tag: S2中期落地 · S1仅配置预留
aligned_doc:
  - design/03-系统设计/战斗系统_铁律放开治理与S2路线图.md（零战斗触碰铁律 / S2 接口分层：属性聚合→生命周期钩子→效果组件）
  - design/03-系统设计/GDD-战斗系统进阶_S1批3.md（BattleCalculator.gd 现状）
  - design/03-系统设计/GDD-灵兽.md（spirit_pet / beast 灵兽属性聚合）
  - design/03-系统设计/GDD-道具与装备.md（treasure_normal/innate / equip_main / EQUIP_SLOTS）
  - design/03-系统设计/战斗系统_铁律放开治理与S2路线图.md §四（BattleEffect 接口 on_apply/on_damage_calc/on_remove）
  - design/04-数值体系/数值体系细则.md §4.4（防御溢出治理）/ §4.6（乘区归属）
  - design/08-功能提案/00-提案索引.md（S2 灰占位清单总入口）
runtime_anchor:
  - BattleCalculator.gd L282-305（battle_buff.csv 运行时镜像，真实框架非摆设）
  - disciple.gd::get_final_combat_attr / _聚合未来战力来源（L1163，S1 属性聚合接口，冻结不改）
  - beast.gd（灵兽属性加成）→ 已聚合进 get_final_combat_attr
  - puppet.csv「战斗」类型（function_effect 纯经济，不进战前聚合）
  - treasure_normal.csv / treasure_innate.csv（base_atk/def/hp + passive_effect）
  - equip_main.csv + EQUIP_SLOTS 枚举
  - battle_buff.csv（S2 钩子点承载框架）
---

# 《太玄宗门录》战斗扭转类功能 GDD（替死法宝 / 傀儡挡刀 / 灵宠护主）

> ## ⛔ 版本标签与红线（醒目，全程生效）
> **版本标签**：`S2中期落地 · S1仅配置预留`
> **铁律（S1 阶段）**：**严格禁止修改 `BattleManager.gd` / `BattleCalculator.gd` / `get_final_combat_attr` 核心文件**。任何「接入战斗结算 / 伤害拦截 / 死亡回退」的设计，一律标 `[S2-战斗放开]` 占位，不当 S1 交付。S1 阶段只做外围资产与配置字段预留。
> **依赖说明**：本组功能统一基于现有 `battle_buff.csv` 框架（BattleCalculator.gd L282-305 运行时镜像，已是真实框架非摆设）落地，复用战斗生命周期钩子（`on_damage_calc` / `on_unit_death` 等 S2 预埋），不重写战斗核心。

---

## 〇、定位与核心结论

### 1. 功能定义
**战斗内状态扭转类**（替死 / 挡刀 / 护主）本质 = **战斗内事件触发 + 战斗流程扭转**。
- **替死法宝**：单位濒死 / 死亡判定时，消耗法宝 / 灵宠代为承受死亡结果，使本体「死而复生」或「免死一次」。
- **傀儡挡刀**：受到伤害的瞬间，由傀儡 / 护体单位代为承受该次伤害（伤害转移）。
- **灵宠护主**：本体受到致命 / 阈值伤害时，灵宠触发护主效果（减伤 / 替承 / 复活）。

三类共性：它们**不是为了「加数值」而存在**，而是为了在战斗某一节点**改变战斗走向**（打断死亡、转移伤害、扭转胜负）。

### 2. 核心结论（为什么 S1 不能落地、必须等接口抽象）
**单纯「战前属性聚合 + 战后只读回调」无法等效实现战斗内状态扭转类功能。** 理由：
- 战前聚合（S1 `get_final_combat_attr` 模式）只能把属性「叠」到开局最终属性上，**无法在「受到伤害瞬间」「死亡判定瞬间」插入流程干预**；
- 战后回调只能读取战斗结果做后续处理，**无法在战斗进行中改写伤害流向或撤销死亡**。
- 扭转类功能的两个关键动作——**伤害拦截（on_damage_calc 修改伤害）/ 死亡回退（on_unit_death 撤销死亡）**——都是战斗核心链路内的事件。

> **结论**：须等战斗系统完成「接口抽象（生命周期钩子）+ 效果组件化（BattleEffect 标准接口）」后，以**低侵入、可插拔**方式落地（对应治理文档 §四 第三层「效果组件接口」，S2 中期）。S1 只做配置字段预留与外围资产铺垫，零战斗触碰。

### 3. 与铁律治理文档的一致性
- 本组功能明确落入治理文档 §五「必要性」中「核心玩法无法实现」项：**状态 buff/debuff、回合触发类机制、组队合击援护**属 S2 核心卖点，100% 无法用属性等效实现 → 适用 S2 放开路径，不做 S1 破例。
- 落地方式严格对齐治理文档 §四「开闭原则」：只加扩展（钩子 + 组件），**不动核心逻辑**，出问题可整体关闭（见 §六 边界与兜底）。

---

## 一、分阶段落地路线图

> 节奏严格对齐《战斗系统铁律放开治理与 S2 路线图》三阶段，本组功能主体在 **S2 中期（效果组件化）** 落地。

| 阶段 | 目标 | 本组功能动作 | 战斗核心触碰？ |
|---|---|---|---|
| **S1 全周期** | 外围铺垫，零战斗触碰 | 追加 CSV 配置字段（预留位，`is_*_active=false`）；梳理现有灵宠/傀儡/法宝资产；完成本文档与审计附录；**不接任何战斗逻辑** | ❌ 零触碰（铁律） |
| **S2 初期** | 战斗接口层预埋信号钩子，搭框架不做功能 | 在 `BattleManager` 预埋 `on_damage_calc` / `on_unit_death` 等只读钩子（默认关闭）；复用 `battle_buff.csv` 框架；**用 1 个灵宠护主 demo 验证钩子可用性**（仅验证，不铺量） | ⚠️ 仅加钩子（扩展层，不开核心） |
| **S2 中期** | 组件化正式落地，按优先级梯队 | 抽象 `BattleEffect` 组件接口；按 §二 梯队正式落地灵宠护主 → 傀儡替死 → 多段复活/法宝主动 | ⚠️ 组件化（扩展层，核心冻结） |
| **S2 后期 / S3** | 深度扩展 | 更多战斗触发类功能（见 §五 四类盘点）、PVP 竞技场平衡、状态交互型 debuff 体系 | ⏳ 按需求评估第四层 |

**S1 配置字段预留的价值**：S2 中期落地时直接填字段、开 `is_*_active` 开关即可，无需回头改 CSV schema，避免 S2 中期与数值/配置口径反复返工。

---

## 二、S2 中期落地优先级梯队

> 排序依据：战斗钩子成熟度（伤害触发钩子 `on_damage_calc` 先于死亡钩子 `on_unit_death` 稳定）+ 实现复杂度（护主 < 替死 < 主动多段）。

| 梯队 | 功能 | 触发点 | S2 承载钩子 | 效果组件方法 | 复杂度 |
|---|---|---|---|---|---|
| **第一梯队** | **灵宠护主**（伤害触发） | 本体受到 ≥ 阈值伤害 | `on_damage_calc` | `BattleEffect.on_damage_calc`（减伤 / 替承） | 低（钩子在 S2 初期已验证） |
| **第二梯队** | **傀儡替死**（死亡触发） | 本体死亡判定 | `on_unit_death` | `BattleEffect.on_apply`（撤销死亡 + 复位 HP） | 中（死亡回退需状态恢复） |
| **第三梯队** | **多段复活 / 法宝主动** | 玩家主动触发 / 多次死亡 | `on_battle_start` + 玩家指令点 | `BattleEffect.on_apply` ×N + cooldown 管理 | 高（多实例 + 主动指令 UI） |

**梯队间依赖**：
- 第一梯队是钩子可用性验证的延伸（S2 初期灵宠护主 demo 直接转正）；
- 第二梯队需等 `on_unit_death` 钩子在 S2 初期（或中期初）稳定，且组件化接口就绪；
- 第三梯队依赖前两者成熟 + 主动指令 UI（玩家在战斗中手动触发法宝/复活），优先级最低。

---

## 三、S1 配置字段预留规范（已落地 / 将落地的确切字段）

> **用途**：S1 阶段在对应 CSV 追加下列列，全部默认 `is_*_active=false`、统一注释 `[S2预留，S1不生效]`；S1 运行时这些列被忽略，仅作 schema 预留，供 S2 中期直接填充启用。
> **不破坏既有列**：仅**追加新列**，不修改任何现存列定义，旧档读 `.get(列名, 默认)` 即可兼容（见 §六 存档兼容）。

### 3.1 法宝类（treasure_normal.csv / treasure_innate.csv 各追加 7 列）

| 列名 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `battle_effect_type` | string | 空 | 战斗效果类型（如 `减伤` / `替承` / `复活`），S2 枚举 |
| `trigger_condition` | string | 空 | 触发条件（如 `本体受致命伤` / `本体死亡`） |
| `effect_value_1` | float | 0 / 空 | 主数值（如减伤比例 / 替承伤害比例） |
| `effect_value_2` | float | 0 / 空 | 副数值（如触发次数上限 / 持续时间） |
| `consume_on_trigger` | bool | false | 触发后是否消耗该法宝 |
| `is_battle_effect_active` | bool | **false** | 战斗效果总开关（S1 恒 false） |
| `fallback_attr_bonus` | string | 空 | S1 降级常驻属性加成（如 `+防御` / `+血量`，仅战前聚合口径），S2 接管后作废 |

### 3.2 灵宠类（spirit_pet.csv 追加 6 列）

| 列名 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `skill_effect_type` | string | 空 | 护主技能效果类型（如 `护主减伤` / `护主替承`） |
| `skill_trigger_rate` | float | 0 / 空 | 触发概率（0~1） |
| `skill_cooldown` | int | 0 / 空 | 触发冷却（回合数） |
| `skill_effect_value` | float | 0 / 空 | 效果数值（比例 / 固定值） |
| `is_skill_active` | bool | **false** | 护主技能开关（S1 恒 false） |
| `fallback_defense_bonus` | string | 空 | S1 降级常驻防御加成（仅战前聚合口径），S2 接管后作废 |

### 3.3 傀儡类（puppet.csv 追加，同法宝 7 列）

| 列名 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `battle_effect_type` | string | 空 | 挡刀效果类型（如 `伤害转移` / `替死`） |
| `trigger_condition` | string | 空 | 触发条件（如 `主人受伤害` / `主人濒死`） |
| `effect_value_1` | float | 0 / 空 | 转移比例 / 承受比例 |
| `effect_value_2` | float | 0 / 空 | 触发次数上限 / 耐久 |
| `consume_on_trigger` | bool | false | 触发后是否消耗傀儡耐久 |
| `is_battle_effect_active` | bool | **false** | 战斗效果总开关（S1 恒 false） |
| `fallback_attr_bonus` | string | 空 | S1 降级常驻属性加成（仅战前聚合口径），S2 接管后作废 |

> **统一约定**：所有 `is_*_active` 默认 `false`；列尾统一注释 `[S2预留，S1不生效]`。
> **S1 文案口径（防误导）**：降级常驻加成只标「常驻防御 / 血量加成 + 待御兽大成显化」，**不承诺减伤**（见附录 Gotcha G1）。

---

## 四、战斗效果属性全量规范表（S2 配置规范附录）

> 本表为 S2 中期组件化落地时的**统一配置规范**，覆盖 6 大类字段。它把 §三 的 S1 预留列扩展为完整战斗效果 schema，供 engineering-lead 设计 CSV / 组件时对齐。

| 类别 | 字段 | 类型 | 说明 | 对应 S1 预留列 |
|---|---|---|---|---|
| **基础标识** | `effect_id` | string | 唯一效果 ID（引用现有 item/treasure/spirit_pet 注册 ID，不新增悬空 ID） | — |
| | `effect_name` | string | 效果展示名 | — |
| | `effect_category` | enum | 护主 / 替死 / 挡刀 / 复活 / 反伤 | `battle_effect_type` / `skill_effect_type` |
| | `source_type` | enum | 法宝 / 灵宠 / 傀儡 | CSV 来源表 |
| **触发规则** | `trigger_type` | enum | 伤害触发 / 死亡触发 / 主动触发 / 回合周期 | `trigger_condition` |
| | `trigger_condition` | string | 触发条件表达式 | `trigger_condition` |
| | `trigger_rate` | float(0~1) | 触发概率 | `skill_trigger_rate` |
| | `trigger_cooldown` | int | 冷却回合 | `skill_cooldown` |
| **数值效果** | `effect_value_1` | float | 主数值（比例 / 固定） | `effect_value_1` / `skill_effect_value` |
| | `effect_value_2` | float | 副数值（次数 / 时长） | `effect_value_2` |
| | `effect_unit` | enum | 比例% / 固定值 / 回合数 | — |
| | `value_formula` | string | 复杂数值公式（可选） | — |
| **生命周期** | `apply_timing` | enum | on_damage_calc / on_unit_death / on_battle_start | 钩子点 |
| | `duration_rounds` | int | 持续回合（0=瞬时） | — |
| | `consume_on_trigger` | bool | 触发消耗本体 | `consume_on_trigger` |
| | `stack_rule` | enum | 不可叠加 / 刷新 / 叠加上限 | — |
| **平衡控制** | `max_trigger_per_battle` | int | 单场触发上限（防无敌） | `effect_value_2` 复用 |
| | `max_value_cap` | float | 数值上限（如减伤≤80%） | — |
| | `pve_coefficient` | float | PVE 场景系数（默认 1.0） | — |
| | `pvp_coefficient` | float | PVP 场景系数（默认 <1，防竞技场失衡） | — |
| **兼容降级** | `fallback_attr_bonus` | string | S1 降级常驻属性 | `fallback_attr_bonus` |
| | `is_battle_effect_active` | bool | 战斗效果开关（S1=false） | `is_battle_effect_active` / `is_skill_active` |
| | `fallback_defense_bonus` | string | S1 降级常驻防御 | `fallback_defense_bonus` |
| | `s1_inert_flag` | bool | S1 惰性标记（恒 true，S2 置 false） | — |

---

## 五、更多战斗触发类功能盘点（四类，标注 S2 / S3 时机）

> 在核心三类（护主/替死/挡刀）之外，盘点可复用同一「钩子 + 组件」体系的扩展功能，避免后续重复设计。

| 类别 | 功能 | 触发点 | 承载钩子 | 建议时机 | 备注 |
|---|---|---|---|---|---|
| **伤害触发型** | 灵宠护主（减伤/替承） | 受 ≥阈值伤害 | `on_damage_calc` | **S2 中期（第一梯队）** | 主体功能 |
| | 法宝反震 | 受近战伤害 | `on_damage_calc` | S2 中期 | 反弹比例伤害 |
| | 荆棘反伤 | 受伤害 | `on_damage_calc` | S2 中期 | 被动反伤 |
| | 护主减伤光环 | 主人受伤害 | `on_damage_calc` | S2 中期 | 灵宠群体护主 |
| **生死扭转型** | 傀儡替死（挡刀） | 主人死亡/濒死 | `on_unit_death` | **S2 中期（第二梯队）** | 主体功能 |
| | 多段复活 | 多次死亡 | `on_unit_death` ×N | **S2 中期（第三梯队）** | 需冷却 + 次数上限 |
| | 同归于尽 | 自身死亡 | `on_unit_death` | S2 后期 | 死亡时对敌造成爆发 |
| | 献祭换命 | 单位主动献祭 | `on_battle_start` + 指令 | S2 后期 / S3 | 主动牺牲换队友复活 |
| **回合周期型** | 每回合回血（阵法） | 回合结束 | `on_round_end` | S2 初期钩子验证（批6-B `[PLACEHOLDER]` 已预留） | 复用既有阵法端口 |
| | 回合开始护盾 | 回合开始 | `on_round_start` | S2 中期 | 周期护盾 |
| | 蓄力爆发 | 蓄力 N 回合 | `on_round_end` + 计数 | S2 后期 | 周期性蓄能 |
| **状态交互型** | 眩晕 / 冰冻 / 灼烧 / 中毒 | 命中 / 持续 | `BattleEffect.on_apply` + 状态 tick | S2 中期（组件化）/ **S3 深度** | debuff 体系，需状态管理组件 |
| | 净化 / 驱散 | 主动 / 受击 | `BattleEffect.on_remove` | S3 | 解除负面状态 |

> **时机判定原则**：伤害触发型、生死扭转型优先（S2 中期，钩子最成熟）；回合周期型部分可 S2 初期借钩子验证；状态交互型 debuff 体系最重，留 S3 深度扩展（对应治理文档 §三 第四层评估）。

---

## 六、边界与兜底

> 所有兜底以「**可整体关闭、可回滚、不破数值上限、PVE/PVP 双轨**」为设计红线。

1. **工程隔离可开关**
   - 总开关：`is_battle_effect_active` / `is_skill_active` 全局默认 `false`（S1 恒关）。
   - 独立开关：每个 `effect_id` 独立 active 标记，单功能出问题只关该效果，不影响其他。
   - 钩子隔离：`on_damage_calc` / `on_unit_death` 等钩子默认关闭，仅启用对应功能时注册监听（治理文档 §四 中间层「默认关闭」原则）。

2. **数值上限防无敌**
   - 单次减伤 `max_value_cap ≤ 80%`，禁止「免伤 100%」式无敌。
   - 单场复活 / 替死次数 `max_trigger_per_battle` 上限（建议 ≤2/场）。
   - 护主触发 `effect_value_2`（次数上限）+ `trigger_cooldown` 双重节流。

3. **PVE / PVP 双轨**
   - `pve_coefficient` 默认 1.0；`pvp_coefficient` 默认 <1（建议 0.5~0.7），防止竞技场因护主/替死导致平衡崩坏。
   - PVP 场景额外限制：禁用「多段复活」类高反转效果，或仅在娱乐模式开放。

4. **存档兼容**
   - S1 追加列均为**可空追加**，旧档读 `.get(列名, 默认false/空)` 不报错。
   - **不修改任何既有列定义**，现有战斗逻辑零影响（铁律）。
   - S2 启用时无需迁移旧档，`is_*_active` 由 false 翻 true 即生效。

5. **回滚预案**
   - 一键回退：关闭 `is_battle_effect_active` 总开关 = 整体回退到 S1 行为（仅降级常驻属性生效）。
   - 组件化隔离：所有扭转逻辑在外部 `BattleEffect` 组件，核心 `BattleCalculator.gd` / `BattleManager.gd` 未改，回滚不影响战斗基础链路。
   - 灰度：S2 中期先开第一梯队（灵宠护主）单功能灰度，验证无回归再铺第二/第三梯队。

---

## 七、复用现状 · 诚实标注与跨文档一致性

### 1. 诚实标注（本组功能真实落地成本）
- ⚠️ **S1 零代码改动**：S1 仅追加 CSV 列（schema 预留）+ 本文档归档；**不接任何战斗逻辑**，不触碰 `BattleManager.gd` / `BattleCalculator.gd` / `get_final_combat_attr`。
- ⚠️ **S2 中期需组件化代码**：灵宠护主/傀儡替死/多段复活均需 `BattleEffect` 组件 + 钩子注册，**非纯配置**（要加组件类 + 钩子接入 + 触发逻辑）。
- ✅ **复用 battle_buff.csv 框架**：不另起炉灶，统一经现有 `battle_buff.csv`（BattleCalculator L282-305 镜像）承载效果数据。
- ✅ **item_id 复用**：`effect_id` 引用现有 treasure/spirit_pet/puppet 注册 ID，**不新增悬空 ID**。

### 2. 跨文档一致性
- **铁律对齐**：本组功能全部标 `[S2-战斗放开]`（除 S1 降级常驻属性走 `get_final_combat_attr` 口径，仅 S2 体感）；S1 不修改战斗核心三文件（见附录红线）。
- **数值治理**：降级常驻防御/血量加成须守 `数值体系细则.md` §4.4 防御溢出治理、§4.6 乘区归属（软 25%/硬 30%）；S2 接管后减伤/替承数值另立平衡控制（§四 平衡控制类）。
- **灵兽现状**：灵宠属性已聚合进 `get_final_combat_attr`（攻防血速），S1 护主仅作降级常驻加成，不承诺减伤（Gotcha G1）。
- **索引对齐**：本功能作为 `00-提案索引.md` 第 07 号条目归档，标 `S2中期` 标签（见索引更新）。

### 3. 边缘情况（≥3）
- **EC-1 钩子未就绪时误开 `is_battle_effect_active`**：S1 阶段读取层应强制忽略该列（即使 CSV 被误改为 true，运行时仍按 false 处理），双保险防破铁律。
- **EC-2 灵宠已离队 / 傀儡已损毁**：触发前校验持有单位在职/存活，跳过不报错，不造成空引用。
- **EC-3 单场多次触发突破上限**：`max_trigger_per_battle` 截断，超出不生效（提示「本场已达触发上限」）。
- **EC-4 PVP 场景系数失衡**：PVP 自动套 `pvp_coefficient`（<1），与 PVE 数值隔离，不参与 PVE 平衡计算。

---

## 附录 A · 审计结论（系统现状 + 三个 Gotcha）

> 本附录为本次代码核实结论留存，避免后续重复审计。核实范围：灵宠/傀儡/法宝/装备/battle_buff 五类资产与运行时消费者。

### A.1 系统现状（真实存在且有运行时消费者）

| 资产 | 现状 | 运行时消费者 | S1 可否直接用 |
|---|---|---|---|
| **灵宠** `spirit_pet.csv` + `beast.gd` + `disciple.gd` 灵兽属性加成 | 灵兽攻防血速已聚合进 `get_final_combat_attr` | `get_final_combat_attr`（战前聚合） | ✅ 降级常驻加成可用（不承诺减伤） |
| **傀儡** `puppet.csv` | 已含「战斗」类型，但 `function_effect` 纯经济、不进战前聚合 | 无战斗消费者 | ❌ 未进聚合，S1 不接战斗 |
| **法宝** `treasure_normal.csv` / `treasure_innate.csv` | 带 `base_atk/def/hp` + `passive_effect` | `get_final_combat_attr`（被动属性） | ✅ 降级常驻加成可用 |
| **装备槽** `equip_main.csv` + `EQUIP_SLOTS` 枚举 | 装备槽位框架成熟 | 战前属性聚合 | ✅ 现有体系 |
| **battle_buff.csv** | **真实框架**（BattleCalculator L282-305 镜像，S2 钩子点） | `BattleCalculator.gd` 运行时读取 | ✅ S2 承载框架，S1 仅预留 |

> 结论：`battle_buff.csv` 是真实框架非摆设，本组功能统一基于此落地，不重写战斗核心。

### A.2 三个 Gotcha（S1 不做代码改动的原因）

- **G1 减伤% ≠ 防御属性**：若 S1 把「常驻减伤」降级进战前聚合，会因减伤与防御属性计算口径不同，导致 **S2 数值跳变**（减伤在伤害公式内结算，防御在属性层结算）。→ S1 文案只标「常驻防御 / 血量加成 + 待御兽大成显化」，**不承诺减伤**。
- **G2 傀儡未进战前聚合**：傀儡 `function_effect` 纯经济，未聚合进 `get_final_combat_attr`；若 S1 补聚合需**修改 `get_final_combat_attr`**，突破铁律。→ S1 不做，留 S2 经钩子接管。
- **G3 拆解链路**：本次仅**核查不新增**；凡有通用机制（如 battle_buff 框架、钩子）则补配置对接，无通用机制则留 S2 组件化实现，不临时堆补丁。

---

## 八、文档级汇总

| 项 | 内容 |
|---|---|
| 版本标签 | `S2中期落地 · S1仅配置预留` |
| 铁律红线 | S1 禁止修改 `BattleManager.gd` / `BattleCalculator.gd` / `get_final_combat_attr`；扭转类设计全标 `[S2-战斗放开]` |
| 依赖框架 | `battle_buff.csv`（BattleCalculator L282-305 镜像）+ `on_damage_calc` / `on_unit_death` 钩子 |
| S1 预留字段 | 法宝 7 列 / 灵宠 6 列 / 傀儡 7 列，均 `is_*_active=false`，注释 `[S2预留，S1不生效]` |
| S2 中期梯队 | 第一：灵宠护主 → 第二：傀儡替死 → 第三：多段复活/法宝主动 |
| 配置规范 | §四 六类全量字段表（S2 落地用） |
| 扩展盘点 | §五 四类（伤害触发/生死扭转/回合周期/状态交互），标注 S2/S3 |
| 兜底 | §六 可开关 / 防无敌 / PVE-PVP 双轨 / 存档兼容 / 回滚 |
| 审计附录 | 附录 A：系统现状 5 项 + Gotcha G1/G2/G3 |

> **S1 交付确认**：S1 仅交付本文档归档 + CSV 字段预留（schema）+ 审计附录；**任何战斗结算 / 伤害拦截 / 死亡回退逻辑均不当 S1 交付**，统一 `[S2-战斗放开]`。

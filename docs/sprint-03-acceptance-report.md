# Sprint-03 验收报告 · 战斗系统（ADR-003 v1.1）

> 工程负责人：程基岩（engineering-lead-1）｜ 主理人：游承峰
> 引擎：Godot 4.7（纯代码 UI 灰模 + 水墨风）｜ 项目根：`E:\Xiuxian\taixuanzongmenlu`
> 状态：**P0 全部交付，待主理人本地 Godot 验收**
> 约束：严格按锁定 ADR-003 v1.1 实现，不做设计决策、不写设计文档、无 git 提交、战斗数值零硬编码。

---

## 1. 概览

| 任务 | 范围 | 状态 |
| --- | --- | --- |
| T0 职业重命名 | 剑修→道修 全量替换 + 校验门 | ✅ 自门通过 |
| T1 BattleCalculator | 纯逻辑结算器（D1/D4） | ✅ 54/54 断言通过 |
| T2 BattleManager | 编排层 + 灰模调试入口 | ✅ 完成 |
| T3 跨系统对接 | 弟子快照 / 奇遇征伐 / 历练 stub | ✅ 完成 |
| T4 验证与验收 | 本报告 | ✅ 已出具 |
| P1 可选 | 跳过战斗 / 血条 / 掉落结算 | ⏸ 未做（P0 已干净，但非必需） |

**统一 BattleResult 契约（全链路一致）：**
`{ is_win, round_count, remaining_hp, drop_reward, battle_log }`

---

## 2. TASK 0 — 职业重命名（剑修→道修）

**自门结果：PASS。** `validate_all.py` 0 错误（37 表 / 1046 行），新增「职业枚举孤儿检查」门通过（残留 `剑修` 仅存于 `disciple.gd` 的 `@LEGACY-MIGRATION` 旧档迁移分支，已用哨兵排除）。

变更文件：
- `disciple.gd`：`职业名`/`职业属性权重`/`判定职业`/`解锁职业池`/`灵兽联动`/ `from_dict` 旧档迁移兜底
- `lore.gd`：职业效果 / 职业堂口 文案
- `beast.gd`：天赋池关联 `道修`
- `item.gd`：`极品道修` 重命名 + `const 职业名`
- `game_state.gd`：`已解锁职业()` 候选池
- `config/path_config.csv`、`config/area_stay_weight.csv`
- `validate_all.py`：新增 `validate_profession_renamed()` + `@LEGACY-MIGRATION` 排除逻辑

---

## 3. TASK 1 — BattleCalculator.gd（纯逻辑结算器）

`class_name BattleCalculator extends RefCounted`，**无 UI / 无 Game 依赖 / 不 preload 业务脚本**。消费战斗快照 `CombatantData`，返回统一 `BattleResult`。

实现要点（对齐 ADR-003 D3/D4/AC2–AC7）：
- **五行乘率** `wuxing_multiplier`：链 `金→木→土→水→火→金`；克制/被克 ×纯度档（单1.25/0.82、双1.0/1.0、三0.75/0.67、四+0.5/0.33）；真实伤害恒 1.0。
- **职业克制闭环**：`道修克法修 / 体修克道修 / 法修克体修`（显式 map，不解析文案）。
- **伤害公式**：`攻击 × 职业倍率 ×(1+通用增益)×(1+道心) × wuxing ×(1-防御减伤率) × 暴击`，双模式（full 随机 / quick 期望值）。
- **边界红线**：伤害下限=1、攻击=0 不出伤、暴击率≤70%、闪避率≤40%、浮动∈[0.9,1.1]、20 回合超时判守方胜、双亡判守方胜。
- **强制结构化日志**：每回合记录 行动单位/目标/伤害/暴击/克制/双方剩余血量（D7）。

**Python 真值镜像** `tests/combat/combat_math.py` 与 GDScript 逐行同步；`tests/combat/test_combat.py` **54/54 断言通过**（见 §6）。

---

## 4. TASK 2 — BattleManager.gd + 灰模调试入口

`class_name BattleManager extends RefCounted`，`preload BattleCalculator`。
- `发起1v1(攻方, 守方, mode, 打印日志)` / `发起3v3(攻方列表, 守方列表, mode, 打印日志)`（车轮战：速序行动、败者下位满血上、胜者气血继承）。
- 状态机枚举 `状态 { 战前准备, 回合执行, 结算收尾 }`。
- `打印战斗()` 结构化控制台日志（含【暴击】【克制】标记）。
- `main.gd` 调试按钮「调试战斗」：经 `名册[0].get_final_combat_attr()` 组装 1v1 与 3v3 快照（无硬编码）。

---

## 5. TASK 3 — 跨系统对接

| 对接点 | 实现 | 说明 |
| --- | --- | --- |
| `disciple.gd` | `get_final_combat_attr()` 返回 `CombatantData` 快照 | 全取自最终属性接口（攻/防/血/速/职业/灵根/暴击/闪避均真实推导，**零硬编码**）；`_推导纯度()` P0 占位「单」 |
| `quest.gd` | `征伐敌方快照()` + `结算征伐()` | 征伐事件确定性派生敌方快照（随境界缩放），调用 `BattleManager` 发起 1v1 / 1vN 车轮，返回 `BattleResult` 给奇遇管理器 |
| `game_state.gd` | `结算征伐奇遇()` | 按 `Quest.结算征伐` 结果发放奖励/记 `履历`（奇遇管理器收尾） |
| `game_state.gd` | `历练结算()`（stub） | 预留 关卡ID→怪物列表→`BattleManager` 通路；数据未接入时返回 `stub` 占位 `BattleResult`，契约齐备 |

**路由**：`_弟子月度事件` 中 `event_type == "征伐"` 时走 `结算征伐奇遇`，否则走普通奖励。

---

## 6. TASK 4 — 验证结果

### 6.1 Python 数值断言（无引擎可跑，100% 通过）
```
python tests/combat/test_combat.py
通过 54 / 失败 0
```
覆盖：五行 5 关系 × 4 纯度档、五行边界 max1.25/min0.82、职业克制闭环、AC7 四类边界、速算 vs 完整 偏差≤10%、BattleResult 五字段契约、强制结构化日志八字段契约。

### 6.2 本地 Godot 验收（3 核心用例，⚠️ NEEDS LOCAL GODOT RUN BY USER）
主理人需在 Godot 4.7 引擎内 solo 走查（本环境无运行器）：

| # | 用例 | 预期 | 状态 |
| --- | --- | --- | --- |
| 1 | 基础 1v1 | 单弟子 vs 同境界怪物，伤害/日志误差在浮动内，五行·暴击·克制生效 | ⏳ NEEDS LOCAL GODOT |
| 2 | 3v3 车轮战 | 行动顺序 / 车轮规则 / 胜方气血继承 正确 | ⏳ NEEDS LOCAL GODOT |
| 3 | 奇遇·征伐联动 | 征伐类奇遇触发战斗→结算→奖励发放→履历收尾，链路打通 | ⏳ NEEDS LOCAL GODOT |

> **用例 #3 前置条件**：`config/event_quest.csv` 需含 `event_type=="征伐"` 的行；若当前 CSV 无征伐行，正常推演不会触发该分支。验收时请确认 CSV 含征伐事件，或告知我补一个「调试征伐奇遇」main 按钮以强制走该路径。
> 调试入口：运行后点 main 灰模「调试战斗」按钮可验证 #1/#2（控制台打印结构化日志）。

### 6.3 P0 缺陷发现与修复（均为 Python 断言捕获的真实 Bug）
1. **[T1] `wuxing_multiplier` 全局 clamp 破坏纯度表**
   - 现象：原 `return clamp(mult, 五行下限, 五行上限)` 把多灵根挡位（三 0.75/0.67、四+ 0.5/0.33）一律顶到 0.82，与 §9.6.2 纯度表冲突（断言 克制/三、克制/四+、被克/三、被克/四+ 全 FAIL）。
   - 修复：移除全局 clamp，直接 `return mult`（纯度表已含全部挡位乘率，单灵根极端值即边界 §9.6.3）。GDScript 与 Python 同步修复。
2. **[T3] `结算_1v1` 漏记攻方出手日志**
   - 现象：日志 `append` 仅写在 `target == 攻方`（守方反击）分支，导致**攻方每次主动出手不进日志**，违反 D7「每回合行动单位/伤害」要求；`is_restrain` 标记也随之只反映守方职业。
   - 修复：每回合双方出手均 `append` 结构化日志。GDScript 与 Python 同步修复，并新增 5 条结构化日志契约断言佐证。

---

## 7. 文件变更清单（全量）

**GDScript（逻辑）**
- `disciple.gd`（T0 重命名 + T3 `get_final_combat_attr`/`_推导纯度`）
- `lore.gd`（T0）
- `beast.gd`（T0）
- `item.gd`（T0）
- `game_state.gd`（T0 候选池 + T3 `结算征伐奇遇`/`历练结算`/`BattleManager` 预载 + 路由）
- `quest.gd`（T3 `征伐敌方快照`/`结算征伐`/`BattleManager` 预载）
- `BattleCalculator.gd`（T1 + 日志 Bug 修复）
- `BattleManager.gd`（T2）
- `main.gd`（T2 调试按钮）

**配置 / 校验**
- `config/path_config.csv`、`config/area_stay_weight.csv`（T0）
- `validate_all.py`（T0 职业枚举孤儿检查）

**测试**
- `tests/combat/combat_math.py`（T1 + 日志同步）
- `tests/combat/test_combat.py`（T1 49 条 + T3 5 条结构化日志断言 = 54）

---

## 8. 待主理人审批 / 本地验收项
1. **本地 Godot 走查** §6.2 三个用例（重点 #3 征伐联动的 CSV 前置条件）。
2. **设计裁决回填**：`get_final_combat_attr()` 中暴击/闪避推导系数、`征伐敌方快照` 敌方属性缩放、`结算征伐奇遇` 奖励数值均为 `[PLACEHOLDER]`，待 design 录入校准（非阻断）。
3. **架构取舍确认（见下）**：T3 中 `quest.gd` 预载 `BattleManager` 并直接发起战斗（而非仅提供数据、由 game_state 调用）。若主理人更倾向严格 ADR-002「叶子无业务预载」口径，我可改为「Quest 仅产征伐战斗请求包，game_state 调 BattleManager」——两版功能等价。

---

## 9. 知识缺口 / 风险
- **无 Godot 运行器**：所有运行时行为（车轮战、灰模打印、CSV 征伐触发）仅能靠代码评审 + Python 真值镜像保证；引擎内 3 用例须主理人 solo 验收（ADR-003 R4）。
- **多灵根模型未就位**：`灵根` 当前为单字段，`_推导纯度()` 恒返回「单」；双/三/四+ 纯度挡位待灵根组合数据模型到位后启用。
- **灵兽战力口径（ADR-003 R2/H5）**：`灵兽契约战力()` 仍按弟子折算，战斗内灵兽贡献口径待 H5 修正；P0 不阻断。
- **关卡表缺失**：`历练结算` stub 因 `config/level.csv` 未录入而返回占位，通路已通、数据源待接（S1）。

---

## 10. 下一步建议
- 主理人完成 §6.2 本地 Godot 验收后，可进入 **S1**：5+2 站位 AI / 敌方 AI / 灵力系统 / 道心实时影响 / 复杂 Buff / 极品特效钩子落地。
- 若需，我可补「调试征伐奇遇」main 按钮，使用例 #3 不依赖 CSV 内容即可本地验证。
- P1（跳过战斗 / 极简血条 / 基础掉落结算）在 P0 内核稳定后可择机追加。

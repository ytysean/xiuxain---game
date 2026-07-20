---
doc_id: TEST_STRATEGY
doc_title: 测试策略（TEST_STRATEGY）
doc_version: v1.0
update_date: 2026-07-18
doc_type: 测试文档
game_formal_name: 太玄宗门录
game_market_name: 开局接手太玄宗
game_core_ip: 太玄宗
---

# 测试策略（TEST_STRATEGY）

> 版本：v1.0 ｜ 适用阶段：Phase 4 收口 ｜ 模式：solo 评审（无 Godot 运行器，无真机 playtest）
> 作者：quality-lead（严守真）｜ 对齐：QUALITY_GATES.md、csv_validator.gd、太玄宗门录_核心设定总览.md §4/§9.6/§11.21/§11.24

## 0. 策略总纲

本环境无引擎运行器，因此**无法做真机烟雾 / 真机 playtest**。测试策略以「**能在无引擎下验证的，尽量自动化；只能在真机/人工下验证的，明确留给人工并给出走查清单**」为原则，分四层组织：

| 层 | 代号 | 测什么 | 能自动化？ | 主要手段 |
| --- | --- | --- | --- | --- |
| (a) 数据层 | DATA | config/ 48 张 CSV 的字段/枚举/关系/权重和 | ✅ 完全可自动化 | csv_validator.gd + 跨表关系校验 |
| (b) 逻辑层 | LOGIC | 纯函数：战力聚合 / 奇遇权重 / 五行克制 / 增益乘区 | ✅ 可自动化（镜像实现） | GDScript assert 或独立 py 逻辑镜像 |
| (c) 集成层 | INTEG | 多系统串联、存档往返、跨模块状态 | ⚠️ 无引擎不可真跑；以代码评审 + 存档 diff 替代 | CR + SC（save.json 构造/比对） |
| (d) 人工层 | MANUAL | UI/UX、手感、竖屏单手、降级表现 | ❌ 必须人工 | UX 走查清单（待 design-lead 验收点） |

**优先级排序（先装备穿戴相关）**：P0 装备穿戴（战力聚合/卸载回退/存档不丢/乘区不破）→ P1 奇遇权重和=100 → P2 五行克制判定 → P3 经济平衡闭环 → P4 战斗/引导（仅逻辑自查，依赖 §11.24 模拟器）。

---

## 1. (a) 数据层 —— CSV 校验（完全可自动化）

**手段**：复用 `csv_validator.gd`（已覆盖 48 表 schema）。扩展点：补齐跨表关系校验（调用方 validate_all 镜像，当前仓库缺失）。

### 1.1 已落地校验（直接复用）
- 单行 schema：必填字段、主键、枚举值、数值区间（如 `passive_value` ≤50%、`damage_rate` ∈[0,3]）。
- 经济四表：`drop_common` 同 `drop_id` 池内 `drop_weight` 之和=100（`economy.drop_check`）。
- 任务/奇遇：`quest_reward_pool` 同 `pool_id` 池内 `weight` 之和=100；`event_quest` 同 `event_type` 池内 `trigger_weight` 之和=100。

### 1.2 需扩展覆盖的新表（按首个冲刺 + 四大缺口）
| 新表/系统 | 校验重点 | 优先级 |
| --- | --- | --- |
| 装备穿戴 | `equip_main`/`equip_set`/`equip_blueprint` 字段与槽位枚举（`EQUIP_SLOTS`）一致；`target_equip_id` 必须存在 | P0 |
| 奇遇（未接线） | `event_quest` 触发场景/稀有度枚举合法；`trigger_weight` 同池和=100；`unlock_realm`/`sect_level` 区间 | P1 |
| 战斗配置 | `skill` 倍率/冷却/灵耗区间；若新增战斗数值表须先入 `TABLE_RULES` | P3 |
| 经济闭环 | `output_daily`/`sink_cost` 按 stage 汇总做 `balance_check`（通用结余 5%-25% / 稀有 -40%~0）；`resource_loop_check` 无孤岛资源 | P3 |

### 1.3 自动化形态
- 建议 eng-lead 在测试框架提案中落地 **validate_all 镜像**（Python 或 GDScript 调用），CI 门控：48 表 + 跨表关系校验零错误才放行。
- 当前缺口：仓库无 validate_all.py，跨表关系校验为 CONCERNS（见 QUALITY_GATES §0 缺口提示）。

---

## 2. (b) 逻辑层 —— pure-function 自测（可自动化，镜像实现）

**思路**：把无副作用纯函数从 .gd 抽出，用 GDScript `assert` 或独立 Python 镜像复算，断言关键不变量。

### 2.1 战力聚合（P0，对齐 §4.2）
- 函数：`compute_power(realm_base, aptitude, spirit_root, prof_coeff, general_gain_sum, daoheart_gain, beast_bonus)`
- 断言：
  1. 穿戴装备后 = 基础 × 资质 × 灵根 × 职业 ×(1+通用[含装备词缀]) ×(1+道心) + 灵兽。
  2. 卸载后回到穿戴前原值（浮点用 epsilon 容差）。
  3. 通用增益总和被 `clamp_soft(0.25, 0.30, decay=0.2)` 收口。
- 边界：满境界 + 道胎资质 + 天灵根 + 7 传说装备 → 仍不破 30%。

### 2.2 奇遇权重（P1，对齐 奇遇系统落地规范 + csv_validator）
- 函数：`roll_rarity(weights)` / `roll_entry(pool)`
- 断言：
  1. 同 `event_type` 池 `trigger_weight` 之和 == 100。
  2. 总权重 10000 四档稀有度映射正确（普通/稀有/珍稀/传说）。
  3. 低于弟子 2 大境界的奇遇触发重 roll（边界：恰好差 2 界不重 roll）。

### 2.3 五行克制判定（P2，对齐 §9.6）
- 函数：`wuxing_multiplier(atk_attr, def_attr, root_purity)`
- 断言：
  1. 克制链 金→木→土→水→火→金：克制 +20% / 被克 -15% / 同属 0。
  2. 灵根纯度：单灵根克制 +25% 被克 -18%；双灵根按主灵根基础不变；杂灵根克制 +15% 被克 -10%。
  3. 真实/固定伤害不触发克制（乘率恒 1.0）。
  4. 多段伤害每段独立判定（用序列输入逐段断言）。

### 2.4 增益乘区聚合（P0/P3，对齐 §4.1/§4.6）
- 函数：`aggregate_multipliers(zone_map)` → 最终属性 = 基础 × ∏(各乘区系数)
- 断言：
  1. 跨乘区严格相乘，绝不加减混合。
  2. 通用增益池：单源子帽收敛后加算汇入，(1+总和) 卡 25%/30%。
  3. 道心独立乘区 ≤10%，不占通用 25%。
  4. 减耗专属 ≤40%，不作用于战力。
  5. 产出效率池单建筑 ≤20% / 全建筑 ≤30%，不进战力公式。

### 2.5 自动化形态
- 方案 A（推荐）：GDScript 内 `assert` 测试场景（需 eng-lead 测试框架支持 headless 跑 assert）。
- 方案 B（solo 兜底）：独立 `tests/logic_mirror/*.py` 复算关键公式，Python `pytest` 跑断言，不依赖引擎。
- flaky 防护：纯函数无随机性即无 flaky；含随机的奇遇抽取用固定 seed + 分布断言，隔离不确定性。

---

## 3. (c) 集成层 —— 代码评审 + 存档 diff 替代（无引擎不可真跑）

**手段**：因无引擎，集成测试以 **CR（读 .gd 串联逻辑）+ SC（构造 save.json 做存读 diff）** 替代。

### 3.1 存档往返 diff（P0，对齐 §11.21）
- 构造 `save_v0.json`：含 sect/disciples/items(含穿戴装备)/buildings 等分区典型数据。
- 执行：存 → 改（穿戴/卸载装备）→ 存 → 读 → 再存。
- 比对：业务分区字段无丢失、类型无漂移；`items` 分区装备槽位与仓库持有一致。
- 触发 §11.21.5 自修复：构造悬空 `equip_id`（指向不存在物品）→ 读档应自动卸下归还仓库、不空指针。

### 3.2 代码评审串联（各优先级）
- 对照 QUALITY_GATES G2 清单：确认穿戴→战力→存档→读档的代码链路落点正确。
- 确认无跨乘区加算混用、无硬编码增益/克制/权重。

### 3.3 自动化形态
- 存档 diff 可脚本化（Python 比对 JSON 字段集合/类型）。
- 真机集成（战斗结算、奇遇全流程、引导串联）**无法自动化**，标记为「待真机补齐」。

---

## 4. (d) 人工层 —— UI/UX 走查清单（必须人工，待 design-lead 验收点）

**说明**：竖屏 480×854 移动端，本环境无人工真机走查能力，列出清单供 design-lead/主理人评审时使用。

### 4.1 走查清单（初版，待 design-lead 验收点细化）
- [ ] **竖屏适配**：480×854 下核心信息不溢出、不重叠；顶部资源栏 4 核心值（灵石/宗门等级/在途商队/弟子总数）常驻。
- [ ] **单手操作**：主操作按钮落在单手可达热区（底部/右下）；高频一键操作（收菜/发车/疗伤）一步可达（对齐 §11.22.2）。
- [ ] **降级表现**：art-lead 降级开关开启时，复杂视觉降级为灰模/占位，不白屏、不卡死（对齐 §11.22 异常才提醒、§8 开关式兜底）。
- [ ] **渐进解锁**：宗门 1-2 级仅核心循环，新系统解锁仅 1 条轻提示（对齐 §11.22.3）。
- [ ] **状态可视化**：正常绿/待处理黄/严重红/外出蓝，色值对齐 §4.4 / §15（待 art-lead 色值表）。
- [ ] **装备穿戴可感知**：穿戴后战力数值即时变化、槽位高亮，玩家能确认「穿了有用」（直接对应 P0 缺口②）。

### 4.2 自动化形态
- ❌ 完全人工。建议后续补「真机 playtest 报告模板」（production/playtests/）由主理人 solo 走查填写。

---

## 5. 优先级执行路线图

| 序 | 测试项 | 层 | 自动化 | 对应质量门 | 依赖 |
| --- | --- | --- | --- | --- | --- |
| 1 | 装备穿戴战力聚合/卸载回退/存档不丢/乘区不破 | LOGIC+INTEG | ✅(镜像)+⚠️(diff) | G3 出口 E1~E4 | design-lead 装备子帽基线 |
| 2 | 奇遇 trigger_weight 同池和=100 | DATA+LOGIC | ✅ | G1/G3 | validate_all 镜像 |
| 3 | 五行克制乘率矩阵 | LOGIC | ✅ | G3 通用 | — |
| 4 | 经济 balance/loop 闭环 | DATA | ✅(待数据) | G4 | §11.24 模拟器 |
| 5 | 战斗全流程 | — | ❌无引擎 | G3 通用 | 战斗代码(缺口①) |
| 6 | UI/UX 竖屏单手降级 | MANUAL | ❌ | 人工层 | design-lead/art-lead 验收点+降级开关 |

---

## 6. 风险与待办

1. **无引擎**：战斗/奇遇/引导只能逻辑自查 + 代码评审，无端到端验证 → 风险高，发布前须主理人 solo 走查兜底。
2. **validate_all 镜像缺失**：跨表关系校验（权重和=100 等）暂无法在 CI 跑 → 依赖 eng-lead 测试框架提案。
3. **数值平衡需 §11.24 模拟器支撑**：balance_check / resource_loop_check 待产出/消耗明细充实后实现。
4. **flaky 防护**：纯函数层无 flaky；含随机层（奇遇抽取）用固定 seed + 分布断言隔离，不污染 CI 信号。

---
*本策略与 QUALITY_GATES.md 配套：策略定义「测什么/怎么测/谁来做」，质量门定义「何时放行」。solo 模式下，能自动化的（DATA/LOGIC）尽量自动化，不能的（INTEG 真机/MANUAL）明确留给人工并附清单。*

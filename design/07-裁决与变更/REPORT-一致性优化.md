---
doc_id: REPORT_一致性优化
doc_title: 《太玄宗门录》设计规则一致性优化报告
doc_version: v1.0
update_date: 2026-07-18
doc_type: 设计规则一致性优化报告
game_formal_name: 太玄宗门录
game_market_name: 开局接手太玄宗
game_core_ip: 太玄宗
---

# 设计规则一致性优化报告 ·《太玄宗门录》

> 范围：13 份 GDD + 核心总览 + 48 张 config csv + 7 个核心 .gd + `csv_validator.gd`。
> 三项交付：全规则校验 / 矛盾排查 / 架构合理性评估。
> 结论：设计层规则密度高、红线清晰；但**校验器执行器缺失 + 代码↔配置脱节 + 数处数值/命名矛盾**待修。

---

## 一、全规则校验（对照 csv_validator.gd 声明 vs 实际）

`csv_validator.gd` 是**数据型**校验器（仅 `const TABLE_RULES` + 跨表规则注释），其头注释与正文多次声明"跨表关系校验实现于调用方（`validate_all.py` 镜像）"。实测：

- **`validate_all.py` 在仓库中不存在**（全仓 grep 无此文件）→ 声明中的 7 项跨表校验（权重和=100、faction 阈值单调、片区权重和=1 等）**全部未落地执行**。
- **无任何 .gd `import csv_validator`** → 运行时根本不跑校验；根目录 `validate_report.txt` 仅是空 Frontmatter 壳，无真实校验结果。
- **设计层已具备、且可静态验证通过的项**（本次用脚本复算）：
  - `drop_common.csv` 同 `drop_id` 池 `drop_weight` 和 = 100 ✓
  - `quest_reward_pool.csv` 同 `pool_id` 池 `weight` 和 = 100 ✓
  - `area_stay_weight.csv` 五片区权重和 = 1.0000（5 行全 ✓）
  - `faction_shop.csv` `item_grade` 品阶秩 ≤ `unlock_reputation` 映射阈值（1000→灵品/3000→宝品/8000→王品）✓

> **判定**：校验"规则已定义、执行器未建"——当前是**文档承诺型校验**，非运行期强制校验。这与 §4.8「全表格驱动、零硬编码」及 §11.23 八「随 CSV 热更一并跑全量校验」的要求存在落地缺口。

---

## 二、矛盾排查（本轮新发现，按严重度）

| 编号 | 矛盾点 | 现状 | 严重度 | 建议终裁 |
|---|---|---|---|---|
| **C-NEW-1** | 装备部位数量 | DESIGN-RULINGS **C5 终裁 8 位**；但 `equip_main.csv` 去重 **7 个**（武器/法袍/头盔/护腕/腰带/靴子/饰品），`csv_validator.gd` `EQUIP_SLOTS` 亦 **7 个** | 高 | 以数据/校验器为准**定为 7 位**并修订 C5；或补第 8 位（如「法宝/项链」）并同步数据 |
| **C-NEW-2** | 品阶倍率表述 vs 实际 | §9 称「每大品阶≈×2」；§4.7 实际阶跃 2.1~2.8；`equip_main` 实测阶跃 **1.95~3.81 不规则**、高端超标最高 267% | 中-高 | 见数值报告 §三，统一为平滑标尺（A/B 二选一） |
| **C-NEW-3** | 主动技表缺品阶 | `skill.csv` 无 grade/sub_grade 列（带 damage_rate 却无品阶）→ §4.7 倍率无法套主动战斗技 | 中 | 补 grade 列，或明示主动技走独立平衡轴 |
| **C-NEW-4** | 品阶命名不统一 | `random_entry_pool.tier_grade` 用 `T1灵品/T2宝品…`，全局其余用「凡品/灵品」体系 | 低-中 | 统一为「大品阶+细分品级」命名 |
| **C-NEW-5** | 成就奖励悬空引用 | `achievement_config.reward_id` 去重 131 个，其中 **130 个**在全部已知 item/skill/quest 表查无 → 运行期奖励可能发不出 | 高 | 建全局 `item_id` 注册表 + 外键校验；补全物品或改合法 id |
| **C-NEW-6** | 占位未填 | `resource_base.stack_limit` 全 = `TBD` | 低 | 补全堆叠上限 |

**已存在裁决回顾（DESIGN-RULINGS 现状，本轮未发现新增冲突）**：R-003（C03~C09 交易商路口径）已终裁且内部自洽；C1~C5（七境界命名/四维性格/15建筑/3职业/8装备位）已归口。其中 **C5「8 装备位」与 C-NEW-1 直接相撞**，建议优先复核。

---

## 三、架构合理性评估

### 3.1 设计层（优点）
- **时间轴单点**：`game_state.gd` 为 Autoload 单例「Game」，统一驱动时间推演 → 对齐 §4.5 铁则六「全游戏只允许单一时间轴」，从架构根上杜绝倍率错位。
- **模块解耦干净**：`main/disciple/item/beast/lore/game_state` 用 `preload("res://…")` 强类型互引，无循环依赖迹象。
- **强类型 + 信号**：`弟子列表: Array[Disciple]`、`signal 弟子变动()` 等，GDScript 4.x 类型化良好。
- **红线文档完备**：§4.1~§4.8 乘区/封顶/性能/平衡体系完整，设计层自洽度高。

### 3.2 代码↔配置脱节（核心缺口）
- **7 个核心 .gd 无任何 CSV 读取逻辑**（仅见 `user://save.json` 存读档），48 张 `config/*.csv` 在运行时是**孤儿数据**。
- `csv_validator.gd` 未接入运行时 → 「全规则校验」无执行入口。
- 结论：§4.8「全表格驱动、零硬编码」在**代码层尚未落地**；当前数值实际由 .gd 内联常量驱动（与「零硬编码」原则相悖），配置表仅作设计存档。符合项目 M1.5 早期状态，但须在 MVP 前补 CSV 加载层 + 校验接线。

### 3.3 性能铁则
- §4.5 六条铁则（区间批量结算/推演步长上限/同屏软上限/存档预算/事件堆积上限/时间倍率一致性）设计层完备且针对性强，但**全部依赖代码落实**，目前无对应实现可核验。

---

## 四、修复建议清单（按优先级）

1. **【高】落地 `validate_all.py`**（或 GDScript 镜像）：实现 csv_validator 声明的 7 项跨表校验 + 经济 `balance_check`，接入 CI/热更。→ 解决 S1/S7、C-NEW-5 校验前提。
2. **【高】建全局 `item_id` 注册表 + 外键校验**：消除 130 个成就悬空引用（C-NEW-5/S2）。
3. **【高】终裁 C-NEW-1（8 vs 7 装备位）**：修订 DESIGN-RULINGS C5 或补全第 8 位并同步数据。
4. **【中-高】统一品阶倍率标尺**（C-NEW-2）：选 A（§4.7 为权威重生成）或 B（CSV 反推）方案。
5. **【中】补 `skill.csv` grade 列**（C-NEW-3）、补后 5 阶段经济数据（S3）、统一 `random_entry_pool` 命名（C-NEW-4）。
6. **【低】填 `resource_base.stack_limit`**（C-NEW-6）。

> 以上 C-NEW-1~6 已登记于 `DESIGN-RULINGS.md`「待裁矛盾」区，待主理人拍板；本文件不替代终裁。

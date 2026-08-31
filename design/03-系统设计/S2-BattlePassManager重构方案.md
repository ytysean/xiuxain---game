---
doc_id: S2-battlepass-manager-refactor
doc_title: S2-BattlePassManager 单例重构方案（战令逻辑层抽离）
doc_version: v0.1
update_date: 2026-08-14
doc_type: 系统设计 / S2 架构合规
game_formal_name: 太玄宗门录
game_market_name: 开局接手太玄宗
game_core_ip: 太玄宗
---

# S2-BattlePassManager 单例重构方案（战令逻辑层抽离）

> 本文档为 S2 前置准备产物，对应 S1 评审结论「分层技术债：S2 迁移至 BattlePassManager」。
> S1 阶段 `game_state.gd` 暂存 4 个战令方法（已标 `TODO S2 重构`），本方案将其抽离为独立逻辑层单例，严守「数据层只读」铁律。

## 1. 概述
- **定位**：功勋（对外「宗门季度法旨」）的战令系统业务逻辑层，承载经验累计、等级判定、奖励发放、付费轨解锁、赛季结算。
- **目标**：`game_state` 仅保留纯数据存储；经验/等级/已领记录等全部状态读写经 `BattlePassManager` 单例，UI 层（`page_battlepass.gd`）只调单例接口，不直接碰 `game_state` 战令字段。
- **范围**：S2 P0 架构合规硬验收项之一；不涉及数值平衡（数值仍走 `battle_pass_library.gd` 配置表）。

## 2. 当前 S1 暂存（待迁移）
`game_state.gd` L633–744 区块，含 4 个方法 + 2 个私有辅助：
- `战令信息() -> Dictionary`
- `增加战令经验(增量: int) -> void`（对外称「功绩值」）
- `领战令奖励(轨道: String, 等级: int) -> Dictionary`
- `购战令付费轨() -> Dictionary`
- 私有：`_战令最大等级()` / `_战令本级所需(等级: int)`

`game_state` 保留的纯数据字段（迁移后只存不写业务）：
`战令_赛季` / `战令_等级` / `战令_经验` / `战令_已购付费轨` / `战令_已领免费[]` / `战令_已领付费[]`

## 3. BattlePassManager 单例接口清单
新增 `battle_pass_manager.gd`（Autoload 名 `BattlePass`，与现有 `BattlePass` 配置库区分——配置库保留 `BattlePass` 常量名，单例另命名 `BattlePassMgr` 或沿用 `BattlePass` 需先解 naming 冲突，见 §6）。

### 3.1 公开方法（对齐既有 4 个，签名不变，调用方零改）
| 方法 | 签名 | 说明 |
|---|---|---|
| 战令信息 | `func 战令信息() -> Dictionary` | 供 `page_battlepass.gd` 读数（赛季/等级/经验/本级所需/最大等级/已购付费轨/已领免费/已领付费） |
| 增加功绩值 | `func 增加功绩值(增量: int) -> void` | 替代 `增加战令经验`；累计功绩值并循环升级，写 `game_state` 纯字段 |
| 领奖励 | `func 领奖励(轨道: String, 等级: int) -> Dictionary` | 替代 `领战令奖励`；校验轨道/等级/付费轨/重复领取，发放资源与皮肤 |
| 购付费轨 | `func 购付费轨() -> Dictionary` | 替代 `购战令付费轨`；扣非绑定仙玉、标记已购 |

### 3.2 S2 新增（评审中优先级项，随重构一并落地）
| 方法 | 签名 | 说明 |
|---|---|---|
| 赛季切换 | `func 赛季切换(新赛季: int) -> void` | 触发赛季结算，清经验/等级/已领记录，写新赛季起始态 |
| 结算溢出兑换 | `func 结算溢出兑换() -> Dictionary` | 赛季结束溢出功绩值按 1:1 兑弟子晋升「功勋」（S1 仅占位注释，S2 实现） |
| 纪事联动钩子 | `func _记纪事(事件类型: String, 文案: String) -> void` | 升级/领大奖/解锁付费法旨自动入「庶务/大事件」分类 |
| 离线托管累计 | `func 闭关累计(日功绩: int, 周功绩: int) -> void` | 宗主闭关期间完成的日常/周常功绩自动累计，出关汇报展示 |

### 3.3 私有辅助（从 game_state 搬入）
- `_最大等级() -> int`（读 `BattlePass.等级表` 末行）
- `_本级所需(等级: int) -> int`

## 4. 重构步骤
1. **新建单例**：`battle_pass_manager.gd`，`class_name BattlePassMgr extends Node`；`project.godot` 注册 Autoload `BattlePassMgr`。
2. **搬逻辑**：将 §2 的 4 个方法 + 2 个私有辅助整体迁入单例，内部对 `Game.战令_*` 字段做读写（数据层字段保留，仅移除「写业务逻辑」的方法）。
3. **改 UI 调用**：`page_battlepass.gd` 中 `Game.战令信息()` → `BattlePassMgr.战令信息()` 等 4 处；守卫 `is_instance_valid(BattlePassMgr)` + `has_method` 保留。
4. **清数据层**：`game_state.gd` 删除 §2 的 4 方法 + 2 私有辅助，仅留纯字段声明与 save/load 同步；移除 `TODO S2 重构` 标记。
5. **经验来源**：`game_state.领取日常` 的 `增加战令经验(10)` → `BattlePassMgr.增加功绩值(10)`；周常 `+30` 同步改；推演等未来来源统一走单例。
6. **验证**：`pre_f5_check.py` 全绿；`page_battlepass` 实机跑通「日常→功绩→升级→领双轨→解锁付费轨」全链路。

## 5. 数据层职责边界（铁律）
- `game_state` 战令字段：仅声明 + save/load 序列化，无任何业务方法。
- 业务逻辑（升级循环、奖励发放、仙玉扣减、赛季结算）全部在 `BattlePassMgr`。
- UI 层禁止直接读写 `Game.战令_*` 字段，一律经单例接口。

## 6. 排期绑定与命名
- **S2 P0 架构合规硬验收项**：本重构与「game_state 纯数据只读」铁律解除绑定，必须在 S2 首发前完成，不得再次拖欠。
- **命名注意**：现有配置库 `BattlePass`（battle_pass_library.gd）与计划单例可能撞名；单例建议定名 `BattlePassMgr`（调用方 `BattlePassMgr.战令信息()`），配置库维持 `BattlePass.等级表` 不变，二者职责清晰（库=数据配置 / 单例=运行时逻辑）。
- **联动预留**（评审中优先级，本重构预留钩子不实现）：纪事联动、离线托管累计、刑律堂任命后周功绩加成——接口见 §3.2，S2 后续迭代填充。

## 7. 验收标准
- [ ] `game_state.gd` 无战令业务方法，仅剩纯字段 + save/load。
- [ ] `BattlePassMgr` 单例 4 个公开方法签名与 S1 一致，UI 调用零报错。
- [ ] `pre_f5_check.py` 全绿；类型名扫描无新增 WARN。
- [ ] 实机：功勋全链路主流程可用，功绩值与功勋两货币文案不混。

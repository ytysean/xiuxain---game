# CSV 资产治理台账（S2 基线）

> 生成：2026-07-28 · 汇编：游承峰（主理人）
> 关联：`csv_摆设型清零清单.md` / `配置消费者映射.md` / `csv_预留白名单.md` / `交付标准_三位一体闭环.md`
> 定位：本轮数据治理的**验收基准 + 后续决策记录 + S2 规划依据**。分类明细见上述关联文档，本台账只存「快照 + 决策 + 待办」。

## 1. 验收结论（2026-07-28 主理人确认）
- 质量门禁 `pre_f5` 总判定 PASS，exit 0；消费者闸门报告 OK=28 / RESERVED=24 / BAK=0 / ORPHAN=16 / 总 68。
- 分类边界清晰、无错分，予以确认。

## 2. 分类结果快照（68 张，`config/` 运行时域）
| 类别 | 数量 | 说明 |
|---|---|---|
| 运行时有效 OK | 28 | 已接线消费者 |
| 预留 RESERVED | 24 | 入白名单（`csv_预留白名单.md`） |
| 孤儿 ORPHAN | 16 | = B 桶 6 + ⚠️ 桶 10，非阻断 |
| 备份 BAK | 0 | 已清零（删 `equip_main.bak.csv`） |
| 合计 | 68 | — |

## 3. 后续决策记录（已拍板）
| # | 议题 | 决策 | 状态 |
|---|------|------|------|
| 1 | 远程推送 | 本地 `main` 已与 `origin/main` 同步（0 ahead / 0 behind，末提交 `be445a3`）；治理 8 提交已上远程基线 | ✅ 已同步 |
| 2 | 孤儿 10 张 | 维持 ORPHAN；S1 不删、不启用、不接入运行时白名单；S2 规划明确后再判定归属 | 🔒 S1 冻结 |
| 3 | B 桶 6 张补闭环 | 纳入 S1 收尾补漏清单；排期在批次 B 波次 C/D 全部落地之后；优先级低于 UI 重构与核心玩法；不阻塞主线 | 📋 排期 |
| 4 | 设计文档旧路径 | 非运行时、不影响功能/校验；随下一轮设计文档更新批量修正；不单排、不单提 | 📝 待迭代 |
| 5 | `--strict` 严格模式 | 暂不启用；待 S1 全量落地 + 孤儿全判定后开启，避免迭代期频繁拦截 | ⏸ 延后 |

## 4. S2 规划基准清单
### 4.1 孤儿资产（10 张，S2 待拍板，当前禁止删除 / 入白名单）
`caravan_member_data` · `caravan_post_config` · `caravan_vehicle_config` · `flying_beast_config` · `personal_flight_config` · `sect_ship_config` · `ship_dock_config` · `teleport_array_config` · `random_entry_pool` · `item_material`

### 4.2 B 桶补闭环（6 张，S1 收尾）
`achievement_config` · `battle_buff` · `equip_main` · `defense_array_config` · `spirit_array_config` · `quest_item`
（建议消费者与依据见 `csv_摆设型清零清单.md` 第二节）

## 5. 已知文档债 / 待关注
- **文档旧路径**：`design/08-功能提案`、`design/09-经济专项审计` 中仍有 `config/新功能冲击声明.csv` 等 prose 旧路径（实际已迁 `tools/config/`）；功能代码已改、文档未同步。
- **工作树未提交**：`config/event_quest.csv.import`、`config/validate_report.txt`（治理提交时刻意排除，属无关 / 自动生成产物），仍留工作树，未纳入任何提交。
- **remote URL 仍为旧仓库名** `xiuxain---game.git`（对应已弃用《玄洲仙宗》）；当前《太玄宗门录》内容推至该远端，若 GitHub 已重命名仓库需同步更新 remote。

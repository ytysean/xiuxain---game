# CSV 摆设型清零清单（Standing-CSV Clearance）

> 治理依据：`docs/交付标准_三位一体闭环.md` 第三章「存量问题清零」。
> 对 45 张摆设型 CSV 的权威分类与清零动作。三桶定义：
> - **A** = S2 / 预留（合法，入白名单）→ 动作：补 `[Sx预留]` 标注 + 入 `docs/csv_预留白名单.md`。
> - **B** = S1 应落地但遗漏消费者 → 动作：排期补消费闭环（注明建议批次）。
> - **C** = 废表（建议删）→ 动作：删除（高影响，需主理人逐类拍板）。
> - **⚠️** = 待主理人拍板（S1/S2 边界无法从代码/GDD 确定）→ 不归入 A/C，禁止删除/入白名单，待拍板。

---

## 一、A 桶 · S2 / 预留（24 张 · 入白名单）

| 文件名 | 桶 | 推荐动作 | 依据（S1S2 判定线索） | 不确定性标注 |
|---|---|---|---|---|
| spirit_pet.csv | A | 入白名单（补 [S1预留] 表头） | csv_validator L49-55 显式 [S1预留] 护主战斗效果字段（默认关闭，仅配置预留）；灵兽系统 S1 已落但 CSV 未接线 | — |
| puppet.csv | A | 入白名单 | csv_validator L75-82 显式 [S1预留] 挡刀战斗效果字段 | — |
| treasure_normal.csv | A | 入白名单 | csv_validator L161-168 显式 [S1预留] 替死战斗效果字段 | — |
| treasure_innate.csv | A | 入白名单 | csv_validator L180-187 显式 [S1预留] 本命战斗效果字段 | — |
| item_pill.csv | A | 入白名单 | 丹药内容品类；丹堂生产/服用系统 P2（doc16 #40/#8），当前无服用函数 | — |
| item_talisman.csv | A | 入白名单 | 符箓内容品类；符堂 S2（doc16 #42） | — |
| equip_blueprint.csv | A | 入白名单 | 装备配方系统 P2（doc16 #41） | — |
| equip_set.csv | A | 入白名单 | 套装效果，装备扩展 S2 | — |
| inner_demon.csv | A | 入白名单 | 心魔/心境系统 P2（doc16 #36） | — |
| tribulation_config.csv | A | 入白名单 | 渡劫系统 P2（§11.16 既有 19 列，心魔渡劫体系） | — |
| tribulation_item.csv | A | 入白名单 | 渡劫道具 P2（§11.26.6 新表） | — |
| map_config.csv | A | 入白名单 | 历练地图内容扩充 §11.27；秘境探索 P2（doc16 #15/#44） | — |
| secret_config.csv | A | 入白名单 | 秘境内容扩充 §11.27；P2（doc16 #44） | — |
| npc_config.csv | A | 入白名单 | 阵营 NPC 人设内容扩充 §11.27 | — |
| personality_config.csv | A | 入白名单 | 弟子性格行为系统 P2（doc16 #35） | — |
| path_config.csv | A | 入白名单 | 弟子修行路线系统 P2（doc16 #35） | — |
| area_stay_weight.csv | A | 入白名单 | 居所/片区驻留 P2（doc16 #18） | — |
| disciple_interact.csv | A | 入白名单 | 弟子互动/动态关系 P2（doc16 #37） | — |
| morale_loyalty_config.csv | A | 入白名单 | 凝聚力/忠诚士气 P2（doc16 #22） | — |
| drop_common.csv | A | 入白名单 | 经济掉落闭环 P2（validator §11.24；doc16 #45 全资源循环） | — |
| resource_base.csv | A | 入白名单 | 资源基线 P2（validator §11.24） | — |
| output_daily.csv | A | 入白名单 | 日均产出 P2（validator §11.24） | — |
| sink_cost.csv | A | 入白名单 | 消耗出口 P2（validator §11.24） | — |
| faction_base.csv | A | 入白名单 | 阵营声望等级权益 S2（faction_shop 已消费，本表未消费） | — |

## 二、B 桶 · S1 应落地但遗漏消费者（6 张 · 排期补闭环）

| 文件名 | 桶 | 推荐动作 | 依据（S1S2 判定线索） | 不确定性标注 |
|---|---|---|---|---|
| achievement_config.csv | B | 排期补消费者（建议批次 B） | 成就系统属批次 B/S1（doc17 正式 GDD）；validator 标 [PL] 框架，reward_id 回填时启用（§17.8 缺口）；消费者未接线 | — |
| battle_buff.csv | B | 排期补消费者（S1 战斗补闭环） | 战斗系统 S1 已完工（BattleCalculator/Manager.gd）；本表为 buff 模板，仅被 BattleCalculator.gd L282-305 以「内联镜像」引用（非 `_read_csv`），主循环未接线 | 若主理人认为战斗 buff 属 S2 扩展，则转 A |
| equip_main.csv | B | 排期补消费者（S1 制式装备） | 制式装备发放 S1（S1-S2 doc §二）；装备主表 CSV 未接线 | — |
| defense_array_config.csv | B | 排期补消费者（S1 阵法子表） | 阵法系统 S1（doc16 #10 含 defense/spirit/teleport_array_config）；array_config.csv 已接线，本子表未接线 | — |
| spirit_array_config.csv | B | 排期补消费者（S1 聚灵阵） | 聚灵阵 S1 实装（S1-S2 doc §一）；子表未接线 | — |
| quest_item.csv | B | 排期补消费者（S1 主线信物合成） | 主线信物/合成碎片（核心设定总览 §16.2.4）；合成消费者缺失 | 若主线剧情判为 S2，则转 A |

## 三、C 桶 · 废表（0 张 · 已删）

> 原 C 桶 1 张（`equip_main.bak.csv`）已删除；`skill.csv` 经 q-1 复核后并入 C 桶并一并删除（见第五节）。C 桶现清空，无待删废表。

## 四、⚠️ 待主理人拍板（10 张 · 暂不归入 A/C，禁止删除/入白名单）

| 文件名 | 桶 | 推荐动作 | 依据（GDD 归属） | 不确定性标注 |
|---|---|---|---|---|
| caravan_member_data.csv | ⚠️ | 待拍板 | 商队实例人员 · 核心设定总览 §11.15 七·3 | ⚠️ 待主理人拍板（S1/S2 边界不明） |
| caravan_post_config.csv | ⚠️ | 待拍板 | 商队岗位 · §11.15 七·1 | ⚠️ 待主理人拍板 |
| caravan_vehicle_config.csv | ⚠️ | 待拍板 | 商队载具 · §11.15 七·2 | ⚠️ 待主理人拍板 |
| flying_beast_config.csv | ⚠️ | 待拍板 | 飞行灵兽/坐骑 · §11.17 | ⚠️ 待主理人拍板 |
| personal_flight_config.csv | ⚠️ | 待拍板 | 个人飞行法器 · §11.17 | ⚠️ 待主理人拍板 |
| sect_ship_config.csv | ⚠️ | 待拍板 | 宗门飞舟 · §11.17 | ⚠️ 待主理人拍板 |
| ship_dock_config.csv | ⚠️ | 待拍板 | 飞舟坞 · §11.17 | ⚠️ 待主理人拍板 |
| teleport_array_config.csv | ⚠️ | 待拍板 | 传送阵 · §11.17（核心概述标第一阶段，但 doc16 未纳入 S1 路线图） | ⚠️ 待主理人拍板 |
| random_entry_pool.csv | ⚠️ | 待拍板 | 随机入口池 · 无明确系统归属 | ⚠️ 待主理人拍板 |
| item_material.csv | ⚠️ | 待拍板 | 材料库 · 无明确系统归属 | ⚠️ 待主理人拍板 |

> 注：原 ⚠️ 桶另含 `item_id_registry.csv` / `新功能冲击声明.csv` / `resource_flow.csv` 三张，经 q-3 拍板认定为 dev 工具/测试专用、非运行时配置，已迁 `tools/config/`（见 `docs/配置消费者映射.md` 第三节），不再计入 ⚠️ 待拍板范围。

---

## 五、已删除废表清单（已执行）

> 以下废表经主理人 q-1 / q-2 拍板，已于本轮数据治理中删除（Git 可回溯）。

1. **equip_main.bak.csv** —— `.bak` 备份文件，非运行配置，无任何消费者，纯冗余。
2. **skill.csv** —— 功法/战斗 S1 实际权威表为 `skill_cultivation.csv`；`skill.csv` 仅 `BattleCalculator.gd` L305 注释提及、零真实读取，确认为冗余源，转 C 后删除。

> 说明：其余 43 张摆设型表均已有明确 GDD/validator 归属（A/B/⚠️），不构成确定性废表：
> - A 桶 24 张：合法预留，走白名单流程，不得删。
> - B 桶 6 张：S1 系统 missing consumer，应补闭环，不得删。
> - ⚠️ 桶 10 张：禁止删除，待主理人拍板其 S1/S2 命运；若拍板为「无规划」，再转入 C 执行删除。
> - 另 3 张 dev 工具/测试表已迁 `tools/config/`，不属 config/ 废表范畴。

---

*统计：原摆设型 45 张 = A(24) + B(7) + C(1) + ⚠️(13)，现已全量处置 —— A 24 入白名单不变；B 7→6（`skill.csv` 转 C 删除）；C 1→0（`equip_main.bak.csv` 删除 + `skill.csv` 并入删除，共删 2 废表）；⚠️ 13→10（`item_id_registry` / `新功能冲击声明` / `resource_flow` 三张迁 `tools/config/`，脱离运行时）。`config/` 内摆设型现余 40 张。A 桶白名单登记见 `docs/csv_预留白名单.md`；全量映射见 `docs/配置消费者映射.md`。*

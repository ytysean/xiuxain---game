# CSV 预留白名单（Reserved Whitelist）

> 治理依据：`docs/交付标准_三位一体闭环.md` 第二章「预留型 CSV 白名单机制」。
> 本表仅收录判定为 **A（S2 / 预留）** 的配置表 —— 即满足「合法例外」三条件：①表头/validator 已标 `[Sx预留，当前版本无消费者]`；②GDD/设计文档登记预留说明与计划落地版本；③`pre_f5` 不阻断、仅黄色提醒。
> **`⚠️ 待主理人拍板` 的 13 张表不列入本白名单**（见 `docs/csv_摆设型清零清单.md`），待拍板后再决议是否入册。

---

## 一、机器可读清单（gate 脚本 `check_csv_consumer.py` 解析区）

> 格式：`文件名.csv|Sx|理由`（每行 `|` 分隔；Sx = 计划落地版本）。
> 仅解析 `RESERVED_LIST_START` / `RESERVED_LIST_END` 之间的内容。

<!-- RESERVED_LIST_START -->
spirit_pet.csv|S1|灵兽护主战斗效果字段预留（csv_validator 标[S1预留，默认关闭]，仅配置预留）；灵兽系统S1已落但CSV未接线
puppet.csv|S1|傀儡挡刀战斗效果字段预留（csv_validator 标[S1预留，默认关闭]，仅配置预留）
treasure_normal.csv|S1|法宝替死战斗效果字段预留（csv_validator 标[S1预留，默认关闭]，仅配置预留）
treasure_innate.csv|S1|本命法宝战斗效果字段预留（csv_validator 标[S1预留，默认关闭]，仅配置预留）
item_pill.csv|S2|丹药内容品类；丹堂生产/服用系统P2（doc16 #40/#8），当前无服用函数
item_talisman.csv|S2|符箓内容品类；符堂系统S2（doc16 #42）
equip_blueprint.csv|S2|装备配方系统P2（doc16 #41）
equip_set.csv|S2|套装效果系统S2（装备扩展）
inner_demon.csv|S2|心魔/心境系统P2（doc16 #36）
tribulation_config.csv|S2|渡劫系统P2（§11.16 既有19列，心魔渡劫体系）
tribulation_item.csv|S2|渡劫道具P2（§11.26.6 新表）
map_config.csv|S2|历练地图内容扩充§11.27；秘境探索P2（doc16 #15/#44）
secret_config.csv|S2|秘境内容扩充§11.27；P2（doc16 #44）
npc_config.csv|S2|阵营NPC人设内容扩充§11.27
personality_config.csv|S2|弟子性格行为系统P2（doc16 #35）
path_config.csv|S2|弟子修行路线系统P2（doc16 #35）
area_stay_weight.csv|S2|居所/片区驻留系统P2（doc16 #18）
disciple_interact.csv|S2|弟子互动/动态关系P2（doc16 #37）
morale_loyalty_config.csv|S2|凝聚力/忠诚士气系统P2（doc16 #22）
drop_common.csv|S2|经济掉落闭环P2（validator §11.24；doc16 #45 全资源循环）
resource_base.csv|S2|资源基线P2（validator §11.24）
output_daily.csv|S2|日均产出P2（validator §11.24）
sink_cost.csv|S2|消耗出口P2（validator §11.24）
faction_base.csv|S2|阵营声望等级权益S2（faction_shop已消费，本表未消费）
<!-- RESERVED_LIST_END -->

---

## 二、人类可读登记（每张预留表）

> 标注格式：`[Sx预留，当前版本无消费者]` + GDD/设计文档登记位置 + 计划落地时间/责任人（不能填者标 TBD）。

### A-1 战斗效果预留（validator 显式 [S1预留] 字段）
| 表名 | 标注 | 登记位置 | 计划落地 / 责任人 |
|---|---|---|---|
| spirit_pet.csv | [S1预留，当前版本无消费者] | csv_validator.gd L49-55（护主字段）；核心设定总览 §7 灵兽 | TBD（S1 战斗增强批次） |
| puppet.csv | [S1预留，当前版本无消费者] | csv_validator.gd L75-82（挡刀字段） | TBD（S1 战斗增强批次） |
| treasure_normal.csv | [S1预留，当前版本无消费者] | csv_validator.gd L161-168（替死字段） | TBD（S1 战斗增强批次） |
| treasure_innate.csv | [S1预留，当前版本无消费者] | csv_validator.gd L180-187（本命字段） | TBD（S1 战斗增强批次） |

### A-2 内容品类 / 内容扩充（S2）
| 表名 | 标注 | 登记位置 | 计划落地 / 责任人 |
|---|---|---|---|
| item_pill.csv | [S2预留，当前版本无消费者] | 核心设定总览 §8 丹堂；doc16 #8/#40 | TBD（批次 G，丹堂 P2） |
| item_talisman.csv | [S2预留，当前版本无消费者] | doc16 #42 符堂(S2) | TBD（批次 G） |
| equip_blueprint.csv | [S2预留，当前版本无消费者] | doc16 #41 配方(P2) | TBD（批次 G） |
| equip_set.csv | [S2预留，当前版本无消费者] | 装备套装扩展 | TBD（批次 G） |
| map_config.csv | [S2预留，当前版本无消费者] | validator §11.27；doc16 #15/#44 | TBD（批次 G，秘境 P2） |
| secret_config.csv | [S2预留，当前版本无消费者] | validator §11.27；doc16 #44 | TBD（批次 G） |
| npc_config.csv | [S2预留，当前版本无消费者] | validator §11.27 阵营 taxonomy | TBD（批次 G/E） |

### A-3 弟子深层 / 心境 / 渡劫（S2）
| 表名 | 标注 | 登记位置 | 计划落地 / 责任人 |
|---|---|---|---|
| personality_config.csv | [S2预留，当前版本无消费者] | validator §11.26；doc16 #35 | TBD（批次 F） |
| path_config.csv | [S2预留，当前版本无消费者] | validator §11.26；doc16 #35 | TBD（批次 F） |
| area_stay_weight.csv | [S2预留，当前版本无消费者] | validator §11.26；doc16 #18 居所 | TBD（批次 F） |
| disciple_interact.csv | [S2预留，当前版本无消费者] | validator §11.26；doc16 #37 | TBD（批次 F） |
| morale_loyalty_config.csv | [S2预留，当前版本无消费者] | validator §11.26；doc16 #22 凝聚力 | TBD（批次 E） |
| inner_demon.csv | [S2预留，当前版本无消费者] | validator §11.26；doc16 #36 心境 | TBD（批次 F） |
| tribulation_config.csv | [S2预留，当前版本无消费者] | §11.16 心魔渡劫体系 | TBD（批次 F） |
| tribulation_item.csv | [S2预留，当前版本无消费者] | validator §11.26.6 | TBD（批次 F） |

### A-4 经济闭环 / 阵营（S2）
| 表名 | 标注 | 登记位置 | 计划落地 / 责任人 |
|---|---|---|---|
| drop_common.csv | [S2预留，当前版本无消费者] | validator §11.24；doc16 #45 | TBD（批次 G，经济闭环 P2） |
| resource_base.csv | [S2预留，当前版本无消费者] | validator §11.24；doc16 #45 | TBD（批次 G） |
| output_daily.csv | [S2预留，当前版本无消费者] | validator §11.24；doc16 #45 | TBD（批次 G） |
| sink_cost.csv | [S2预留，当前版本无消费者] | validator §11.24；doc16 #45 | TBD（批次 G） |
| faction_base.csv | [S2预留，当前版本无消费者] | validator §11.26 阵营 taxonomy | TBD（批次 E，阵营权益生效） |

---

*生效动作：本白名单登记后，`pre_f5` 对以上 24 张表输出黄色提醒（不阻断）。同时需在对应 CSV 表头补 `[Sx预留，当前版本无消费者]` 注释（A-1 四类已由 validator 注释覆盖，建议回填 CSV 表头）。新增预留表须同步追加至 `RESERVED_LIST` 区块与第二节登记。*

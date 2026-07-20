---
doc_id: sprint_01_plan
doc_title: Sprint-01 计划 ·《太玄宗门录》Phase 4 收口汇编 → Phase 5 冲刺
doc_version: v1.0
update_date: 2026-07-18
doc_type: 冲刺计划文档
game_formal_name: 太玄宗门录
game_market_name: 开局接手太玄宗
game_core_ip: 太玄宗
---

# Sprint-01 计划 ·《太玄宗门录》Phase 4 收口汇编 → Phase 5 冲刺

> 汇编人：主理人 游承峰 ｜ 日期：2026-07-18 ｜ 评审强度：solo（无 Godot 运行器）
> 阶段判定：**收口 PASS（文档齐全）**，Sprint-01 入口门 **PASS**（R1-R4 已裁决，2026-07-18 老大终裁采纳 csv_validator 作权威）

---

## 一、当前阶段结论

- **你处在 Phase 5 制作（中后期）**，带着一笔"工作室脚手架债"。本次收口已补齐 SOP 过程产物。
- 收口门（G2 架构评审 / G1 设计评审）：**PASS** —— 架构文档、3 条 ADR、GDD 索引、4 套 UX、4 份资产规格、质量门全部落盘，且均未改动任何 `.gd` 代码。
- **Sprint-01 入口门已 PASS**（R1-R4 已裁决），可启动 A1~A5；代码重命名（剑修→道修、仙阶→品、9槽→7槽）留待后续 Sprint，本 Sprint-01 不碰 .gd。

---

## 二、收口交付物清单（16 份，均已落盘）

| 成员 | 文件 | 路径 |
| --- | --- | --- |
| eng-lead | 架构文档 | `docs/architecture/ARCHITECTURE.md` |
| eng-lead | ADR-001 装备穿戴 | `docs/architecture/adr/ADR-001-equip-wearing.md` |
| eng-lead | ADR-002 奇遇接入 | `docs/architecture/adr/ADR-002-quest-event-hook.md` |
| eng-lead | ADR-003 战斗模块 | `docs/architecture/adr/ADR-003-combat-module.md` |
| eng-lead | Epic/Story 拆分 | `production/epics/epics-gap-systems.md` |
| eng-lead | 测试框架提案 | `tests/TEST_FRAMEWORK.md` |
| design-lead | GDD 索引 | `design/gdd/INDEX.md` |
| design-lead | UX-装备穿戴 | `design/gdd/ux/UX-装备穿戴.md` |
| design-lead | UX-奇遇触发 | `design/gdd/ux/UX-奇遇触发.md` |
| design-lead | UX-战斗斗法 | `design/gdd/ux/UX-战斗斗法.md` |
| design-lead | UX-新手引导 | `design/gdd/ux/UX-新手引导.md` |
| art-lead | 资产-装备穿戴 | `design/gdd/art/ASSET-装备穿戴.md` |
| art-lead | 资产-奇遇弹窗 | `design/gdd/art/ASSET-奇遇弹窗.md` |
| art-lead | 资产-战斗 | `design/gdd/art/ASSET-战斗.md` |
| art-lead | 可访问性分级 | `design/gdd/art/ACCESSIBILITY.md` |
| qa-lead | 质量门 | `tests/QUALITY_GATES.md` |
| qa-lead | 测试策略 | `tests/TEST_STRATEGY.md` |

---

## 三、冲刺路线图（依赖与顺序）

```
设计系数基线(design) ──阻塞──> [Sprint-01] 装备穿戴 ──战力前置──> [Sprint-02] 奇遇
                                                        └──────────> [Sprint-03] 战斗(可与02并行)
                                                                          │
                                                                          ▼
                                                              [Sprint-04] 新手引导+UI美术
```

- **Sprint-01 装备穿戴**：代码量最小，是奇遇/战斗的战力结算前置。锁定 Epic A（A1~A5 主线 + A4 存档），A6 与 E4 在 design 系数就位后补。
- **Sprint-02 奇遇**：依赖①战力 + design 性格四维表 + `event_quest.csv` 数据层。
- **Sprint-03 战斗**：依赖①战力 + ADR-003 边界 + art 战斗 UI；可与 02 并行。
- **Sprint-04 引导+UI**：多为表现/内容层，依赖 art 资源 + design 文案（章节式文案 doc 缺失，需补写）。

---

## 四、Sprint-01 详细范围（Epic A）

| # | Story | 优先级 | 依赖 | 验收（qa 出口门 E1~E4） |
| --- | --- | --- | --- | --- |
| A1 | 槽位枚举对齐：弃用 `item.穿戴位名` 9 槽 → `csv_validator.EQUIP_SLOTS` 7 槽（衣袍→法袍、配饰→饰品；本命法宝单列）；更新 `槽显示` | P0 | 裁决 R4 | 生成装备 `穿戴位` 仅落 7 槽；CSV 校验一致 |
| A2 | 弟子持有模型：新增 `背包:Array[Item]` + `装备:Dictionary{槽位:Item}`；`穿戴(槽位,it)`/`卸载(槽位)` | P0 | A1 | 穿戴后 `装备[槽位]==it` 且 `背包`不含 it；重复槽位自动替换 |
| A3 | 战力改乘性：实现 `计算战力()`(§4.2)+`聚合通用增益()`(clamp 25%/30%)；`总战力()` 改调之；`灵兽契约战力()`=(主×1.0+副×0.7)×0.30 | P0 | A2 | **E1** 穿戴后战力按公式变、不再计未穿背包；**E2** 卸载回原值(epsilon) |
| A4 | 存档兼容：重写 `to_dict/from_dict` 增 `装备` 分区、`背包`(兼容旧 `物品`)；加 §11.21 元数据头(save_version/checksum/reserved) | P0 | A2 | **E3** save→load 槽位背包一致；悬空 equip_id 自修复；新字段有默认 |
| A5 | UI 槽位面板（灰模）：弟子详情 7 槽+本命法宝，点击穿戴/卸载；战力即时刷新 | P1 | A2,A3 | 穿戴后战力即时变、槽位高亮 |
| A6 | 乘区单源子帽 + 设计系数回填：拿 design 基线后填 灵根/道心/职业系数、item.flat 占坑 §4.6 | P1 | design 系数 | **E4** 任意组合通用增益 ≤30% |

**Sprint-01 出口门（G3 装备门）**：E1~E3 任一 FAIL 即阻塞提测；**E4 在 design 系数（DESIGN-RULINGS 裁决② 装备子帽 8% 基线）就位后可判 PASS**，H4（职业命名）随终裁解除。

---

## 五、待裁决项（阻断 Sprint-01 入口门，需老大拍板）

核查 `csv_validator.gd`（数据契约/可运行真相源）后，分歧已可裁：该文件**已**采用下列口径，建议以它为权威，反向对齐代码与美术。

| # | 争议 | csv_validator 现状（权威裁决） | 裁决结果（2026-07-18 老大终裁） |
| --- | --- | --- | --- |
| R1 | 品阶命名 | `VALID_GRADES`=品体系：凡品/灵品/宝品/王品/圣品/真品/道品（顶阶**道品**） | ✅ 已裁决：采纳品体系；代码/美术/UX 统一为「品」 |
| R2 | 职业命名 | `APPLY_CLASSES`=道修/体修/法修（非"剑修"） | ✅ 已裁决：采纳**道修**（维持上轮裁决）；剑修作废，代码重命名留后续 Sprint |
| R3 | 奇遇稀有度 | `rarity`=3 档：普通/稀有/传说 | ✅ 已裁决：采纳 3 档；§10 四档映射入 3 档（TODO-① 数据层） |
| R4 | 装备槽位 | `EQUIP_SLOTS`=7 槽：武器/法袍/头盔/护腕/腰带/靴子/饰品（本命法宝单列、无长裤） | ✅ 已裁决：采纳 7 槽+本命法宝；代码 9→7、UI/UX 对齐 |

> 四项于 2026-07-18 由老大终裁，**一律采纳 csv_validator 为唯一真相源**。design/art/eng 文档已回填对齐（主理人已核盘验证）；代码侧重命名（剑修→道修、仙阶→品、9槽→7槽）留待后续 Sprint，本 Sprint-01 不碰 .gd。

**另两项非阻塞待办**：
- 缺口④ 章节式新手指引文案.doc 经检索**不存在**，需 design-lead 据 §13.1+§11.1.1 推导补写（标 [文案待补]）。
- `validate_all.py` 缺失：csv_validator 头部引用但仓库仅 `docx_extract.py`，跨表权重校验暂只能 CI 记 CONCERNS，待 eng-lead 测试框架补镜像。

---

## 六、架构隐患（来自 ARCHITECTURE §5，H1-H8）

🔴 高：
- **H1 战力公式矛盾**：`disciple.总战力()` 纯加性，§4.2 要求乘性多乘区 → 直接违反 G2。需 design §4.2 系数才能落地（A3/E4 阻塞）。
- **H2 存档违反 §11.21**：save/load 单层 flat dict，无元数据头 → 无法兼容/完整性校验。Sprint-01 A4 一并补。

🟠 中：
- **H3 穿戴位 9 vs 7**（见 R4，ADR-001 裁 7）。
- **H4 职业命名 剑修 vs 道修**（见 R2，裁 道修）。
- **H5 奇遇接口未接线**：`Lore.取奇遇()` 已实现但 game_state 未调用；config 有候选数据未接。
- **H7 csv_validator 无执行函数**，缺 validate_all 镜像（CI 缺口）。

🟡 低：
- **H6 灵兽战力按弟子 30% 折算**，非自持（§4.2 口径不符）。
- **H8 disciple 缺 灵根系数/道心/主辅修字段**（§4.2 落地必需）。

---

## 七、已知风险与缓解

| 风险 | 等级 | 缓解 |
| --- | --- | --- |
| 无引擎，战斗/奇遇/引导只能逻辑自查+代码评审，无端到端验证 | 高 | solo 走查兜底；纯函数层先做可单测逻辑；发布前人工审批 |
| 设计严重领先代码，易漂移 | 中 | 以 csv_validator 数据契约为单一真相源；R1-R4 裁决锁口径 |
| 灰模→赛博国风成品渲染工作量未计入 | 中 | 收口仅锁视觉令牌；成品渲染排 Sprint-04 及以后 |
| 竖屏 480×854 信息密度偏高（9→7 槽后缓解） | 中 | 词缀/极品折叠、底部背包收起、五行浮标限时淡出（见 UX 文档） |
| 数值平衡（§11.24）待产出/消耗明细充实 + 模拟器 | 中 | 暂缓，Sprint-01 先卡 §4.1 红线 |

---

## 八、质量门（solo 映射，详见 `tests/QUALITY_GATES.md`）

- **G1 设计评审** / **G2 架构评审**：收口 PASS（文档齐全）。
- **G3 烟雾测试**：Sprint-01 走装备门 E1~E4（代码评审 + CSV 校验 + 逻辑自查 + 存档兼容）。
- **G4 发布检查**：D 冲刺走人工层降级走查；高影响动作（发布签字）须人工审批。

---

*本计划为 Phase 5 冲刺规划；R1-R4 已于 2026-07-18 由老大终裁（采纳 csv_validator 作权威），Sprint-01 入口门由 CONCERNS 转 **PASS**，可启动 A1~A5（代码重命名留后续 Sprint，本 Sprint 不碰 .gd）。*

---

## 九、收口补记（2026-07-18 终裁后）

### 9.1 E4 出口门解锁
- `DESIGN-RULINGS-P5.md` 裁决② 已给出**装备单源子帽设计基线 ≤8%**，H1/H4 设计系数缺口闭合；E4（任意组合通用增益 ≤30%）判定条件现已可解，Sprint-01 A6 落地时按 8% 基线回填即可。
- H4（职业命名 剑修 vs 道修）= **已裁决 道修**，跨成员风险项关闭（design-lead 已在 DESIGN-RULINGS 标「已解除（裁道修）」）。

### 9.2 奇遇核心池缺失（待 Sprint-02）
- `config/` 下**缺 §10 奇遇核心池**（`adventures.csv`：8 类×25=200 则 / 四档稀有度权重合计 10000）。现状仅 `event_quest.csv`（10 行桩，干预分支层）、`random_entry_pool.csv`（属性词条层，缺第 4 档「传说」）、`quest_random.csv`（访客委托，非奇遇）。
- Sprint-02 须新建 `adventures.csv` 核心池，否则 `Lore.取奇遇()` 持续走兜底（与 ADR-002 R1 预警一致）。

### 9.3 协作铁律与违规记录
- **铁律**：成员间禁止直连，所有跨成员产出/协调一律经主理人（team-lead）中转。
- **违规记录（本次收口）**：
  - design-lead：3 次越级直连 art-lead（含推翻老大「道修」裁决改剑修），已认罚，终裁后已回退。
  - art-lead：1 次直连 eng-lead（发「token 重命名 + 职业口径回填」通知），HOLD 后核盘确认 4 份资产文档已正确对齐道修/7槽/品系/3档，工作无碍，违规记入。
  - eng-lead：1 次直接回复 art-lead（未转主理人），工作正确但渠道违规，记入。
- 后续 Sprint 严格执行中转规则；再犯升级处理。

# PH7 · CSV「玩家可见文案表面」清单（第二大文案表面）

- **维护**：quality-lead-2（严守真）
- **触发**：team-lead `PH7-QA-12` P0 —— 补上「数值表达违规/文案残缺」断言只覆盖 `.gd` 字面量、**未含 `config/*.csv` 玩家可见列**的系统性盲区
- **已确认盲区出处**（非推测）：`design/10-上线冲刺优化/PhaseB-前三页改动规格.md:195` ＋ `逐页优化改动汇总.md:905` 两处独立登记
- **铁证**：B-19 第 8 站 `config/dynasty_counter_config.csv:4 penalty_desc`、第 9 站 `config/auction_ai_config.csv:2 lines` 均为 **CSV 泄漏样本**，原 `.gd` 扫描结构上扫不到
- **模式**：**只读**（未改任何 `.gd` / `.csv` 产品文件；未启 Godot；未改 `tests/` 战斗红线）
- **扫描范围**：`config/*.csv` **132 个**（全量，非抽样）
- **更新**：2026-09-16（PH7-QA-12）

---

## 0. 方法与判据（可复现）

### 0.1 CSV 读取机制（盘上回盘）
项目统一经 `DestinyDataLoader._read_csv(path)`（`DestinyDataLoader.gd:20`）→ 返回 **`Array[Dictionary]`，每行字典以 **CSV 表头列名** 为键**（`:34-37 d[header[i]]=line[i]`）。上层封装：`Game._CSV去BOM()`（`game_state.gd:15052`，剥 BOM + 逐键 `\ufeff` 清理）。
⇒ 列访问形态 = `行.get("<列名>")` / `行["<列名>"]`；**另有少量「位置访问」** `行[N]`（如 `forge.gd:24 "equip_name": str(行[1])`）—— 判据须同时覆盖**命名访问**与**位置访问**两条路。

### 0.2 「玩家可见」判据（**只写"疑似"不算**）
一列判为**确认上屏**，须给**完整消费链**：
> `CSV 站点` → `读取点 file:line` → `装配/拼接 file:line` → **`UI 控件 file:line`（`.text=` / `_label` / `show_hint` / `add_child` 之一）**

- **UI 控件**是链的终点，必须命中（这是 team-lead 明示的「至少追到 UI 那一跳」）。
- **追一层消费者不够**：`auction_ai_config.csv` 的正例即是 `:283 → :284 → :726（换键）→ :728 → page_auction.gd:582 → :586`，**中间 `:726` 换键（`台词池`→`竞价台词`）** 是 lead 独家核到、QA 原报漏掉的一跳 —— 本清单逐链补足。
- **反例同样登记**：零引用列（死列）**不算**玩家可见（见 §3）。

### 0.3 扫描脚本
`%TEMP%\qa12_scan.py`（BOM/CRLF/违规扫描）、`qa12_scan2.py`（逐列 read-point + UI hit 机械矩阵）、`qa12_summary.py`（prose 列摘要）。原始产物已归档：
- `production/qa/PH7-CSV-扫描原始矩阵.txt`（597 KB · 逐 CSV×列 的 read-point/UI 命中）
- `production/qa/PH7-CSV-文案列摘要.txt`（18 KB · prose 列 + 零命名消费者清单）

---

## 1. 确认上屏（完整消费链 · **逐站回盘核过**）

> 链中每个 `file:line` 均本轮实读；未核到者不列。UI 终点加 **粗**。

| # | CSV | 列 | 样例（截断） | 消费链（CSV 读取 → 装配 → **UI 控件**） |
|---|---|---|---|---|
| 1 | `七载大典文案.csv` | `开篇` | 根基尚浅，然守拙归真… | `:14700 FileAccess` → `:14711-14715 缓存[k]={开篇/收尾/评语}` → `Game._七载大典文案()`（`main.gd:1255`）→ **`main.gd:1265 开.text=文["开篇"]`** |
| 2 | `七载大典文案.csv` | `收尾` | 第%d七载，宗门稳守本心… | 同上 → **`main.gd:1300 铭.text=(文["收尾"]%序号)+…`** |
| 3 | `七载大典文案.csv` | `评语` | 岁末考评守拙… | 同上 → `game_state.gd:14513 岁末评语` → 岁末考评链路 |
| 4 | `lore_narrative.csv` | `text` | 御兽峰按月引育… | `game_state.gd:4557 FileAccess` → `:4569 文案表[k]=parts[1]` → **45+ 消费**：`宗门纪事.append({"文案":…})`、`_加推演条目(文案表[…])`（`:14222/:14557/:14782…`）、**`mail_system.gd:60-63 "内容": Game.文案表[…]`** |
| 5 | `dynasty_counter_config.csv` | `penalty_desc` | 该郡供奉降至30%… | `dynasty_system.gd:2328 _读王朝反制 → _CSV去BOM` → **`ui/page_dynasty.gd:1241 险.text="后果：%s" % 配.get("penalty_desc")`**；另 `dynasty_system.gd:2794/:2798/:2829 "说明"/纪事` |
| 6 | `dynasty_counter_config.csv` | `convert_desc` | 抗命不缴反得民心… | 同上 → **`ui/page_dynasty.gd:1246 机.text="转机：%s"`**；另 `dynasty_system.gd:2958 推演条目` |
| 7 | `auction_ai_config.csv` | `lines` | …万宝商盟再加10%… | `auction_system.gd:55 _CSV去BOM` → `:283 台词池=split("|")` → `:284` → **`:726 var 池=a.get("台词池",[])`（换键）→ `:728 lot["竞价台词"].append`** → **`ui/page_auction.gd:582` → `:586 _label("　· "+str(t),false)`** |
| 8 | `品级权益映射.csv` | `弹窗文案` | 开宗立派，编户十人… | `main.gd:1203 FileAccess` → `:1211-1218 缓存={…弹窗文案:parts[5]}` → **`main.gd:1290 案.text=权益.get("弹窗文案","")`** |
| 9 | `品级权益映射.csv` | `弹窗标题`/`解锁功能` | 〔九品·开宗〕/周边历练 | 同上 → 弹窗标题/解锁功能行 |
| 10 | `quest_main.csv` | `quest_name`/`target_desc` | 建立你的宗门根基 | `game_state.gd:9512/:9524/:9698` → **`ui/page_quest.gd:1133 desc.text=q.get("target_desc")`**、**`main.gd:3262 描.text`**、**`main.gd:5010 标.text="%s：%s…"`** |
| 11 | `quest_daily.csv`/`quest_weekly.csv` | `quest_name`/`target_desc` | 完成普通野外历练2次 | 同上 → **`main.gd:5043 标.text`** |
| 12 | `event_quest.csv` | `event_content` | 一群灵鼠偷啃灵田… | `quest.gd:122 parts[7]` → `quest.gd:235 "文案":evt["event_content"]` → `game_state.gd:15858 "文案":evt.get("event_content")` → 奇遇弹窗 |
| 13 | `引育纪事.csv` | `文案` | 御兽峰按月引育… | `game_state.gd:941 _引育纪事表` → `:944 _引育纪事文案(兽)` → **`:23858-23859 战报更新.emit(引纪["文案"])`** → `:23860 宗门纪事.append("文案")` |
| 14 | `宗门里程碑.csv` | `史册文案` | 【里程碑】太玄宗开宗立派… | `game_state.gd:21305 传承史册.append({"文案": m.get("史册文案")})` → 传承史册/功德录 |
| 15 | `auction_config.csv` | `description` | 常驻场每隔多少游戏日… | 参 `dynasty_counter_config` 同族；机械命中 UI（待逐站补全链） |
| 16 | `world_event_config.csv` | `文本` | %s 于坊市购得一本残破功法… | 机械命中 UI（`ui_hits=4`）；链路待补 |
| 17 | `收藏图录分类.csv` | `描述`/`名称` | 聚灵之阵图 | 机械命中 UI（`ui_hits=36`） |
| 18 | `oath_config.csv`/`oath_sect_config.csv` | `desc`/`name` | 指道心为誓… | 机械命中 UI（`ui_hits=10`） |

> **说明**：#15 起的「机械命中 UI」指该列在 `ui_hits` 中出现 ≥1 条含 UI 赋值 token 的消费行 —— 因列名较通用（如 `description`/`desc`）**存在跨 CSV 归并噪声**，本清单**只把已逐站回盘核实的 #1-#14 列为"确认上屏"**；#15-#18 标「机械命中·待逐站补链」。

---

## 2. 机械矩阵摘要（全量 132 CSV）

| 指标 | 值 |
|---|---|
| CSV 总数 | **132** |
| prose 列（值含 CJK 且长度 ≥ 6、非纯数字）实例 | **198** |
| 零命名消费者（`get("列")`/`["列"]` 双缺）候选列 | **27**（其中含**位置访问**误判，见 §3） |
| 全量矩阵 | `production/qa/PH7-CSV-扫描原始矩阵.txt` |
| prose 列摘要 | `production/qa/PH7-CSV-文案列摘要.txt` |

**按 CSV 的 prose 列（示例，全量见摘要文件）**：`七载大典文案.csv`(标题/开篇/收尾/评语)、`品级权益映射.csv`(解锁功能/弹窗标题/弹窗文案)、`lore_narrative.csv`(text)、`dynasty_counter_config.csv`(penalty_desc/convert_desc/description)、`dynasty_decree_config.csv`(decree_name/description)、`dynasty_faction_config.csv`(description)、`dynasty_faith/found/heresy/temple/omen/memorial/phase_config.csv`(desc/text)、`quest_main/daily/weekly/random.csv`(quest_name/target_desc)、`event_quest.csv`(event_name/event_content/opt*_desc)、`faction_quests.csv`(target_desc/description)、`faction_shop.csv`(item_name/description)、`引育纪事.csv`(文案)、`宗门里程碑.csv`(史册文案)、`收藏图录分类.csv`(匹配名/名称/描述)、`auction_ai_config.csv`(lines)… 等。

> **★ 判据性质声明**：`名称`（rp=661/ui=107）、`描述`（rp=202/ui=36）、`desc`（rp=14/ui=10）等**通用列名**的计数为**跨 CSV 归并**（该列名在多个表都存在）⇒ **不可直接当作单表证据**；单表结论以 §1 的逐站链为准。

---

## 3. 零消费者 / 死列（反例登记）—— 判据有效性证明

> **判据意义**：**同一个表里，有的列上屏、有的列是死的**。清单必须能区分二者 ⇒ 故单列本节。

### 3.1 **确认死列**（回盘核过，非机械命中）

| 字段 | 表:行 | 内容 | 消费者 | 判定 |
|---|---|---|---|---|
| `description` | `config/dynasty_faction_config.csv` **全列**（5 行） | `:4`「内廷近侍，贪墨无度；掌权则供奉厚三成…」 | **0**：加载点 `dynasty_system.gd:3135 _CSV去BOM`；唯一消费入口 `_派系配置(派系名)`（`:3142`）→ 8 个消费站（`dynasty_system.gd:3268/3302/3361/3384/3517/3548`、`ui/page_dynasty.gd:1088/1105`）**只读** `faction_name/desire_type/desire_cost/tribute_rate/talent_rate/crisis_rate/merit_rate`；全仓 `.gd` 的 `"description"` **0 处**命中 dynasty 侧 | **死列**（无 UI 消费者 ⇒ 玩家不可见） |

**★ 该列含 `三成`**（本可命中 `[数字]+[成倍]`）—— 若**不做可见性判定**会误入 B-19 ⇒ 即 **B-19 的第 10 处假阳性**。**可见性判据在此显式挡下 1 例。**

### 3.2 **候选零命名消费者（27 条）—— 非"确认死列"**

> **⚠ 重要**：下列列的 `rp=0` 只代表**无命名访问**（`get("列")`/`["列"]`）。**位置访问**（`行[N]`）不会被本判据捕获 —— 实证：`equip_main.csv.equip_name` 看似 rp=0，实为 `forge.gd:24 "equip_name": str(行[1])` ＋ `game_state.gd:8217 row[1]` **位置读后重键**。⇒ 下列为**候选**，须逐列再判「是否位置访问 / 是否整体透传」。

`achievement_config.unlock_tip`、`area_stay_weight.verify_note`、`atlas_intent.反查`、`dynasty_memorial_config.opt{1,2,3}_text`、`equip_main.equip_name/repair_material`、`fishing_tackle.可钓`、`hostile_npc_config.background`、`inner_demon.opt1_fail_punish/opt2_success_reward/opt2_fail_punish`、`item_material.usage_desc/obtain_way/realm_correspond`、`negative_event.trigger_condition`、`puppet.puppet_name`、`stage_main.designer_note`、`treasure_innate.innate_name/active_skill/sacrifice_material`、`treasure_normal.treasure_name/passive_effect`、`unlock_order.解锁条件类型/设计意图`、`经济基线.锚点`。

**初判**：多为**设计注释列/内部字段**（`designer_note`/`verify_note`/`设计意图`/`反查`/`锚点`）+ **位位置访问列**（`equip_name` 等）⇒ **须与设计线/工程线对账后定死列**（本清单不擅自判死）。

---

## 4. 复现

```powershell
# 违规扫描 + 逐列矩阵（只读，不启 Godot）
python %TEMP%\qa12_scan.py    # -> %TEMP%\qa12_scan_out.txt（违规 + 逐列消费）
python %TEMP%\qa12_scan2.py   # -> %TEMP%\qa12_scan2_out.txt（read-point + UI hit）
python %TEMP%\qa12_summary.py # -> %TEMP%\qa12_summary.txt（prose 列摘要）
```
产物已归档至 `production/qa/PH7-CSV-扫描原始矩阵.txt`、`PH7-CSV-文案列摘要.txt`。

---

## 5. 对断言升级的建议（交 team-lead）

1. **数值表达违规断言**：扫描面由 `.gd` **扩至 `config/*.csv` 全部单元格**（口径见 `PH7-CSV-数值表达违规.md`），**排除 `倍率`/`倍速`、`万`/`亿`**。
2. **文案残缺/上屏判据**：CSV 的 prose 列（§2 的 198 列）纳入「不得含悬空/残缺冒号」等文案判据的巡检面。
3. **死列**：`dynasty_faction_config.description` 二选一处置（补 UI 展示 / 标死列待清理，见登记册 §七）。

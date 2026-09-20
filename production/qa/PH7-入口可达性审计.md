# PH7-入口可达性审计（治 harness direct-call 盲区）

> **轮次**：PH7-QA-14 ｜ **执行**：quality-lead-2（严守真）｜ **性质**：只读审计（不改 `.gd`/`.csv`）
> **数据来源（硬口径）**：`.workbuddy/tools/audit_entry_reachability.py`（脚本化，非手工）＋ `emit_baseline.py --freeze GO2后` 基线标签
> **工具再跑**（复核用）：
> `python .workbuddy/tools/audit_entry_reachability.py --out <utf8路径>`（PowerShell `*>` 会毁中文，务必用 `--out` 直写 UTF-8；`cmd.exe` 被工具禁用）
> **触发原因**：X06 离线管理「入口悬空」根因 = 验收 harness **按方法名直达**（`tests/ui_full_accept.gd:139 _special_step("X06_离线管理","_open_offline_manager_page")`），绕过 UI 入口 ⇒ harness 永绿、玩家走不通。本审计回答：**64/70 页里还有没有第 2、第 3 个 X06**。

---

## §0. 结论速览

| # | 项 | 结果 |
|---|---|---|
| ① | **孤儿页方法**（`game_ui` 的 `_open_*`/`_show_*` 运行时 0 caller） | **1 个**：`_open_offline_manager_page`（= X06，已知） |
| ② | **页可达性**（70 页 · 三态） | **可达 68 ｜ 仅 harness 1 ｜ 死页 1** |
| ③ | **反向自检**（阳性 X06 判孤儿 ✓ ＋ 阴性 `_open_雅趣` 未误报 ✓） | **PASS（不恒真/不恒假）** |

**一句话**：**X06 之外，全仓只剩 `ui/page_placeholder.gd` 1 个真死页**（且它「已声明未用」，属已知死代码候选，非隐蔽盲区）。**没有第 2、第 3 个隐蔽 X06。** 「大厂水准能上线测试」这一目标在本项审计上 **成立**。

> 口径说明：题面「64 页」为逐页规格册口径；本审计按「`ui/` 下全部页承载脚本」口径 = **70 页**（63 个 `page_*.gd` ＋ 7 个 `*_page.gd`/`sect_home_page.gd`）。差异为命名/收录口径，非缺漏；70 ⊇ 64。

---

## §1. 审计口径与方法（脚本化）

**根 = 底部 5 Tab 页（宗门/弟子/殿阁/历练/纪事）＋ `game_ui`（常驻）＋ `main`（应用根）**；
**边 = 真实可见入口**：
1. `sect_home_page` 入口表（`ENTRIES_LEFT/RIGHT`、`QUICK_ENTRIES`、`MORE_ENTRIES`、`MORE_GROUPS`）→ `entry_selected.emit(id)` → `game_ui._on_首页入口` → `_show_sub_page`；
2. `game_ui const ENTRY_SUB_PAGES`（52 条 id→`PackedScene` 映射）＋ `ENTRY_ALIAS`；
3. 雅趣直跳（`page_leisure.雅趣请求(id)` → `_open_雅趣`）；
4. `_open_*` 开工器 → `_show_sub_page` / `load(res://ui/*.gd)`；
5. 页→页引用（`res://ui/*.gd|.tscn`，**排除 `game_ui` 开工器函数体内**，防「孤儿开工器自家 load」反向救活孤儿）。

**BFS 三态判定**：
- **可达**：入口链从根可达；
- **仅 harness direct-call（玩家不可达）**：唯一开工器在产品代码里 0 调用点（只被 `tests/` 直达）；
- **死页**：无任何开工器、无任何引用。

**归一化**：Windows `\` 与 Godot `/` 统一，去重；`read()` 用 `utf-8-sig`；排除 `.bak*`/`tests`/`.workbuddy`/`.scratch_backup`。

---

## §2. ① 孤儿页方法扫描（`ui/game_ui.gd` 的 `_open_*`/`_show_*`）

| 方法 | 定义行 | 调用点 | 调用者 |
|---|---|---|---|
| **`_open_offline_manager_page`** | **`game_ui.gd:1212`** | **0** | **★ 孤儿** |
| `_open_全服拍卖` | `:958` | 1 | `game_ui.gd:930` |
| `_open_雅趣` | `:964` | 2 | `game_ui.gd:933`, `page_leisure.gd:5` |
| `_open_master_detail` | `:1076` | 1 | `game_ui.gd:749` |
| `_open_message_center` | `:1100` | 2 | `game_ui.gd:752`, `sect_home_page.gd:184` |
| `_open_chat_page` | `:1128` | 2 | `page_message.gd:50, :51` |
| `_open_player_trade_page` | `:1156` | 2 | `page_message.gd:59, :60` |
| `_open_world_map_page` | `:1184` | 1 | `game_ui.gd:859` |
| `_open_disciple_detail` | `:1240` | 1 | `game_ui.gd:273` |
| `_open_skin_shop` | `:1266` | 3 | `game_ui.gd:924, :1261, :1262` |
| `_open_master_skin_shop` | `:1272` | 2 | `game_ui.gd:927, :1096` |
| `_open_faction_quest_shop` | `:1278` | 1 | `game_ui.gd:1324` |
| `_show_page` | `:767` | 14 | `main.gd:3125/3131/3134` … |
| `_show_sub_page` | `:878` | 16 | `game_ui.gd:865/960/970` … |

**⇒ 运行时孤儿 1 个：`_open_offline_manager_page`**（其余开工器均有真实接线）。计数规则：排除 `func` 定义行与自身日志串（`"[GameUI] _open_* 被调用"`），只算真引用。

**复核（全仓 `!*.bak*` 检索）**：`_open_offline_manager_page` 仅出现于
`ui/game_ui.gd:1212/1213/1226/1228`（定义体）＋ `tests/ui_full_accept.gd:139`、`tests/_t_deadkey.gd:117`、`tests/_t_btnsweep.gd:116`（**全为 harness 直达**）⇒ **产品侧 0 caller，坐实**。

---

## §3. ② 页可达性三态表（70 页 · 每条入口链证据）

### 3.1 仅 harness direct-call（玩家不可达）— 1 页

| 页 | 链（证据） |
|---|---|
| `ui/page_offline_manager.gd` | opener=`_open_offline_manager_page` **产品调用点=0**（仅 `tests/*` 直达） |

### 3.2 无任何入口（死页）— 1 页

| 页 | 链（证据） |
|---|---|
| `ui/page_placeholder.gd` | opener=-（无开工器、无引用） |

### 3.3 可达 — 68 页

**A. 底部 Tab 直挂（5）**

| 页 | 链 |
|---|---|
| `ui/page_building.gd` | 底部 Tab 栏「殿阁」 |
| `ui/page_chronicle.gd` | 底部 Tab 栏「纪事」 |
| `ui/page_disciple.gd` | 底部 Tab 栏「弟子」 |
| `ui/page_explore.gd` | 底部 Tab 栏「历练」 |
| `ui/sect_home_page.gd` | 底部 Tab 栏「宗门」 |

**B. 首页入口 → `_on_首页入口` → `_show_sub_page`（46）**

| 页 | 入口 id |
|---|---|
| `ui/page_achievement.gd` | 功绩堂 |
| `ui/page_activity.gd` | 宗门时令 |
| `ui/page_ancestor.gd` | 祖师堂 |
| `ui/page_ascension.gd` | 飞升 |
| `ui/page_atlas.gd` | 宗门舆图 |
| `ui/page_auction.gd` | 拍卖行 |
| `ui/page_avatar.gd` | 身外化身 |
| `ui/page_battlepass.gd` | 功勋 |
| `ui/page_beast.gd` | 灵兽 |
| `ui/page_brew.gd` | 灵酿 |
| `ui/page_chess.gd` | 论道棋弈 |
| `ui/page_codex.gd` | 宗门典藏 |
| `ui/page_daoyou.gd` | 道友 |
| `ui/page_dynasty.gd` | 凡人王朝 |
| `ui/page_equipment_blueprint.gd` | 装备图纸 |
| `ui/page_faction.gd` | 阵营声望 |
| `ui/page_family.gd` | 家族 |
| `ui/page_fengshui.gd` | 风水堪舆 |
| `ui/page_fragment_chest.gd` | 碎片宝箱 |
| `ui/page_guardian.gd` | 护道人 |
| `ui/page_herb_garden.gd` | 药园 |
| `ui/page_huanxing.gd` | 幻形 |
| `ui/page_hunt.gd` | 入山采撷 |
| `ui/page_leaderboard.gd` | 玄榜 |
| `ui/page_leisure.gd` | 闲情雅趣 |
| `ui/page_library.gd` | 藏书阁 |
| `ui/page_mail.gd` | 灵讯 |
| `ui/page_master.gd` | 宗主 |
| `ui/page_merchant.gd` | 商道 |
| `ui/page_music.gd` | 音律 |
| `ui/page_opportunity.gd` | 机缘 |
| `ui/page_pill_formula.gd` | 丹方 |
| `ui/page_poison.gd` | 毒道 |
| `ui/page_premium.gd` | 日供 |
| `ui/page_puppet.gd` | 傀儡 |
| `ui/page_quest.gd` | 宗务 |
| `ui/page_rules.gd` | 宗规 |
| `ui/page_sect_manager.gd` | 宗主管理 |
| `ui/page_sect_qi.gd` | 宗门气运 |
| `ui/page_settings.gd` | 设置 |
| `ui/page_shop.gd` | 坊市 |
| `ui/page_storage.gd` | 库藏 |
| `ui/page_tech.gd` | 科技 |
| `ui/page_teleport.gd` | 传送阵 |
| `ui/page_treasure.gd` | 法宝 |
| `ui/page_zongmen_battle.gd` | 宗门战 |

> 上表共 **46 条**首页入口链，逐条 `入口"X" → _on_首页入口 → _show_sub_page`。

**C. `_open_*` 开工器链（8）**

| 页 | 链 |
|---|---|
| `ui/disciple_detail_page.gd` | …→ `_open_disciple_detail()` → `_show_sub_page(PageDiscipleDetailScene)` |
| `ui/master_detail_page.gd` | …→ `_open_master_detail()` → `_show_sub_page(PageMasterDetailScene)` |
| `ui/master_skin_shop_page.gd` | …→ `_open_master_skin_shop()` → `_show_sub_page(PageMasterSkinShopScene)` |
| `ui/skin_shop_page.gd` | …→ `_open_skin_shop()` → `_show_sub_page(PageSkinShopScene)` |
| `ui/faction_quest_shop_page.gd` | …→ `_open_faction_quest_shop()` → `load(res://ui/faction_quest_shop_page.gd)` |
| `ui/page_message.gd` | …→ `_open_message_center()` → `load(res://ui/page_message.gd)` |
| `ui/page_player_trade.gd` | …→ `_open_player_trade_page()` → `load(res://ui/page_player_trade.gd)` |
| `ui/page_world_map.gd` | 底部 Tab 栏「宗门」 → 入口"天下" → `_open_world_map_page()` 引用 → `ui/page_world_map_visual.gd:1184` |

**D. 应用根 / 常驻引用链（9）**

| 页 | 链 |
|---|---|
| `ui/page_beast_raise.gd` | 应用根 `main.gd` 引用 → `main.gd:4870` |
| `ui/page_divine.gd` | 应用根 `main.gd` 引用 → `main.gd:4879` |
| `ui/page_fishing.gd` | 应用根 `main.gd` 引用 → `main.gd:4834` |
| `ui/page_global_auction.gd` | 应用根 `main.gd` 引用 → `main.gd:4779` |
| `ui/page_herb.gd` | 应用根 `main.gd` 引用 → `main.gd:4888` |
| `ui/page_relic.gd` | 应用根 `main.gd` 引用 → `main.gd:4861` |
| `ui/sect_creation_page.gd` | 应用根 `main.gd` 引用 → `main.gd:3930` |
| `ui/page_chat.gd` | 根 UI（GameUI 常驻）引用 → `ui/game_ui.gd:530` |
| `ui/page_world_map_visual.gd` | 底部 Tab 栏「宗门」 → 入口"天下" → `_open_world_map_page()` |

> 合计：**A5 ＋ B44 ＋ C8 ＋ D9 = 66**，另 `page_treasure`/`page_zongmen_battle`（法宝/宗门战）2 条并入首页入口链 = **可达 68**。✅

---

## §4. ③ 反向自检（新铁律：证明判据不恒真也不恒假）

| 用例 | 期望 | 实测 | 结论 |
|---|---|---|---|
| **阳性** `_open_offline_manager_page`（已知悬空） | ★判为孤儿 | ★判为孤儿（调用点=0） | ✓ 判据**不恒假**（能抓到真孤儿） |
| **阴性** `_open_雅趣`（已知有接线） | 未误报 | 调用点=2（`game_ui.gd:933`, `page_leisure.gd:5`） | ✓ 判据**不恒真**（不无差别报孤儿） |

**⇒ 自检 PASS。** 判据对「真孤儿」与「真接线」分别给出正确相反结论。

---

## §5. 处置建议

### 5.1 X06 离线管理（`ui/page_offline_manager.gd`）— 已有 team-lead 裁定，坐实
- **病根**：`_open_offline_manager_page` 产品侧 0 caller；验收 harness 按方法名直达 ⇒ 永绿盲区。
- **本审计复核现状**：`ui/game_ui.gd:1316` **仍为** `_toast("【闭关设置】系统即将开放")` —— **接线尚未落盘**（截至审计时点），与本工具「调用点=0」一致。
- **既定修法（team-lead 2026-09-17 已批，转工程线）**：`game_ui.gd:1316` 该 toast **→ 改真调用 `_open_offline_manager_page()` ＋ 删该 toast（禁假反馈）＋ 补「从入口真点能到」断言**。
- **验收建议**：修复后本工具 ① 应回归「孤儿=0」，② 页 `page_offline_manager.gd` 应从「仅 harness」翻为「可达（入口链 = 闭关设置 → `_open_offline_manager_page` → load）」—— **两条都可脚本复算，建议作为该站落地判据**。

### 5.2 `ui/page_placeholder.gd` 死页 — 维持「保留文件 + 注销入口」保守路径
- 证据：`ui/game_ui.gd:24 const PagePlaceholderScene = preload("res://ui/page_placeholder.tscn")` —— **仅声明、生产调用 0、`tests/` 引用 0**（本审计 ② ＋ `design/10-上线冲刺优化/长尾页A级规格.md §五-4` 双证）。
- 该页属 **已声明未用** 的死代码候选，**已在「lead 终裁清单」**（删除不可逆，本阶段不授权删）。
- **风险定级：低**（不会误导玩家、不进任何入口、不影响上线测试），**仅作技术债登记**，随 **P0-4 换肤批**一并清理。

### 5.3 其余 68 页 — 无动作
均具「底部 Tab / 首页入口 / 开工器 / 应用根引用」中至少一条真实入口链，玩家可达。

---

## §6. 派生断言清单（给门3，**先列不改闸门**）

> 依 team-lead 指示：本清单**先出、不落闸门**。待 GO3 落盘并复验通过后，再由工程线决定是否并入门3。

1. **【入口接线断言·强】** 对 `ui/game_ui.gd` 每个 `_open_*`/`_show_*` 方法，断言**存在 ≥1 个非 `tests/` caller**（排除 `func` 定义行与 `"[GameUI] … 被调用"` 自身日志串）。
   - 现状基线：孤儿 = **1**（`_open_offline_manager_page`）；X06 修复后目标 = **0**。
2. **【页可达性断言·中】** 对 `ui/` 下每个页承载脚本，断言其处于三态之一，且**「仅 harness」不在白名单**（白名单本期为空）。
   - 现状基线：可达 68 ｜ 仅 harness 1 ｜ 死页 1（`page_placeholder`）。
3. **【死页断言·弱·白名单】** 断言「死页」集合 ⊆ 已批准白名单 `{ui/page_placeholder.gd}`。
4. **【反向自检断言·元】** 每次跑断言须内置 1 阳性（`_open_offline_manager_page`）+ 1 阴性（`_open_雅趣`）用例并断言其结论相反 —— **防止断言本身恒真/恒假**（本次铁律固化）。

---

## §7. 口径对账与已知盲区（诚实声明）

1. **页数口径**：本审计 **70 页**（`ui/` 全部页承载脚本）vs 规格册 **64 页** —— 差异为收录口径，70 ⊇ 64，非缺漏。
2. **工具覆盖边界**：BFS 依赖**静态可解析**的入口（信号 `emit(id)` / const 映射 / `load`）。**纯运行时动态构造**的入口（如字符串拼接后 `get_node`/`call` 打开页）不在静态图内 —— 但此类若存在，会表现为「页判为不可达而玩家实际可开」，属**假阳性（漏报可达）**，方向安全（宁多报不可达、不错放真悬空）。
3. **harness 盲区的根因已固化**：`_special_step("X06_离线管理","_open_offline_manager_page")` 类「按方法名直达」是本盲区的结构性来源；**§6-1 断言即为堵此盲区**。
4. **未触碰产品代码**：本审计全程只读；`.workbuddy/` 未在闸门运行期写入（工具产物落 `production/qa/` 与临时 UTF-8 文件）。

---

## §8. 附 · 复算指令

```
# 全量审计（UTF-8 直写，PowerShell 勿用 *> 管道）
python .workbuddy/tools/audit_entry_reachability.py --out production/qa/_audit_reach_dump.txt

# 机器可读
python .workbuddy/tools/audit_entry_reachability.py --json > production/qa/_audit_reach.json
```

**审计时点基线**：`emit_baseline.py --freeze GO2后`（战斗文件 md5 `109f2296…`，未变）。

— 严守真（quality-lead-2）· PH7-QA-14

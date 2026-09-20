# PH7 · `audit_ui` 棘轮「三值不一致」根因（只读调查）

- **产出**：quality-lead-2（严守真）｜ task PH7-QA-19（team-lead 任务A）
- **性质**：**只读**。未改基线 / 未改阈值 / 未改代码 / 未起 Godot。全部结论来自盘上文件 + 独立复算。
- **触发**：P0-A 归零报告（`_ph7visual/report_before_after.md:145`）标记「阈值 ≤159 ／ 基线 json 163 ／ 实测 166 三者不一致」。

---

## 0. 结论摘要（先给答案）

| 值 | 是什么 | 出处（盘上可核） | 能否当"判据" |
|---|---|---|---|
| **159** | **文档级验收上限**（P0-A 施工清单 §验证写的「裸 StyleBoxFlat ≤159」） | `design/10-上线冲刺优化/批2-ui_theme漂移修正施工清单.md:193`；来源链 `design/06-角色与UI/P0-4换肤验收与优化建议_20260913.md:43`（184→159） | 目标值，非门禁 |
| **163** | **仓内基线 json**（棘轮比较基准） | `.workbuddy/auto_ui/audit_ui_baseline.json`（mtime **2026-09-13 03:56:28**） | 已陈旧 4 天，**当前不可用** |
| **166** | **当前实测**（脚本对现盘复算） | 本报告 §3 独立复算 ＋ `.workbuddy/auto_ui/_out/audit_ui_report.txt:137/213` | 事实值 |

**★ 关键更正（对 team-lead 口径）**：题面写「阈值 ≤159（**脚本内**）」——**不成立**。`audit_ui.py` **没有任何硬编码阈值**；它的棘轮是「当前 METRICS vs 基线 json」，源码见 §1。`159` 是**文档里的验收上限**，`163` 才是**脚本真正使用的门禁数**。三值不是一个体系的数，**是两个体系（文档门 vs 脚本门）＋ 一个事实值混在了一起**。

**★ 根因（一句话）**：**基线 json 是 09-13 03:56 首次运行自动生成的一次性快照、且 `.workbuddy/` 不入 git ⇒ 4 天从未 rebase**；文档门 `159` 来自更晚的 P0-4 验收；两者**从未对齐**；叠加 4 天的真实漂移，才出现「159 / 163 / 166」互不相同。

---

## 1. ① `159` 从哪来（写死？文档推的？）

**答：不是写死，是文档推的。脚本内无 `159`。**

盘上核证：以 `159` 检索 `.workbuddy/auto_ui/audit_ui.py`（431 行全文）——**零命中**。脚本的判定逻辑（`:246-271`）是：

```
METRICS = {"硬编码Color": len(live_color), "裸StyleBoxFlat": len(live_sbf), ...}
base = json.load(open(BASELINE))              # ← 门禁数 = 基线 json
ratchet_fail = [k for k,v in METRICS.items() if v > base.get(k, v)]
```

即**脚本唯一的"阈值"就是基线 json 的 163**；`159` 只活在文档里。来源链：

1. `design/06-角色与UI/P0-4换肤验收与优化建议_20260913.md:43`
   > 「裸 StyleBoxFlat **184→159**」——P0-4 换肤一次性把 184 收敛到 159（该批**实测达成值**）。
2. `design/10-上线冲刺优化/批2-ui_theme漂移修正施工清单.md:193`（P0-A 施工清单 · §验证）
   > 「硬编码 Color **≤1240**、裸 `StyleBoxFlat` **≤159**、TOTAL **≤2014**」
   —— P0-A 把 P0-4 的达成值 `159` **抄成了本批的验收上限**。
3. 旁证同一口径：`P0-5首页重排_定稿裁决_v1.0.md:156`、`P0-7首页去面板化_评审与裁决_v1.0.md:169` 均记「裸 StyleBoxFlat **159**」。

⇒ **`159` = P0-4 的达成水位，被 P0-A 施工清单采纳为验收上限**（文档门），**与脚本的基线 json（163）相差 4，且比它更严 4**。

---

## 2. ② 基线 json 的 `163` 何时生成、`git log`/mtime 能否定位

**答：能，用 mtime；`git log` 不行（文件不入 git）。**

| 项 | 证据 |
|---|---|
| **mtime** | `.workbuddy/auto_ui/audit_ui_baseline.json` = **2026-09-13 03:56:28** |
| 内容 | `{硬编码Color:1242, 裸StyleBoxFlat:163, 魔法数字尺寸:585, 字号越界:24, _伪合规_不计入棘轮:337}` |
| 与首跑对应 | `.workbuddy/_audit_ui_p035.txt:2` `METRICS {...1242,163,585,24}  TOTAL=2014  BASE_TOTAL=2014` ⇒ `BASE_TOTAL==TOTAL` = **该次运行"建/重设"了基线**（源码 `:263 if is_rebase or base is None:` 才会写 json） |
| **`git log` 不可用** | `.gitignore:12` = `.workbuddy/` ⇒ 整个工具目录被忽略。实测 `git log -- .workbuddy/auto_ui/audit_ui_baseline.json` **输出空**（我实跑，见 §5 证据）。 |
| **尺子自 09-13 起冻结** | `audit_ui.py` mtime = 09-13 03:58:43（与 json 差 2 分钟）⇒ 09-13 之后**统计口径未再改动**。故 163→166 的差**不是"尺子变了"，是"地盘变了"**。 |

⇒ **`163` = 2026-09-13 03:56 合并版工具首跑的自动快照**，此后 **4 天从未 `--rebase`**。（`memory/2026-09-14.md:328` 明文「…报 FAIL ⇒ …转绿，**未 `--rebase`**」——佐证团队一直坚持"改代码降水位"而非"抬高基线"。）

**`163` 的最后一次实测（用于界定 ③ 的窗口）**：

| 探针文件 | mtime | 裸 StyleBoxFlat | 判定 |
|---|---|---:|---|
| `.workbuddy/_chk_auditui3.txt` | 2026-09-16 04:01:00 | 163 | PASS |
| `.workbuddy/_audit_ui_redsys.txt` | **2026-09-16 07:17:03** | 163 | PASS ← **最后已知 163** |
| `.workbuddy/auto_ui/_out/audit_ui_report.txt` | 2026-09-17 01:40:51 | **166** | **FAIL** |

⇒ **漂移窗口 = [2026-09-16 07:17, 2026-09-17 01:40]，净 +3。**

---

## 3. ③ 实测 `166` 的三处（`SBF_*` 站点 file:line）

**先给口径**：`166 − 163 = +3` 是**净增**；它是相对**已陈旧的基线**而言，故"三处"= 该窗口内的**净增 3 站**。

**独立复算（我自己的只读脚本，镜像 `audit_ui.py` 口径：`SKIP_DIRS` ＋ `BAK_HINT` ＋ `SBF_EXEMPT={ui_theme.gd}` ＋ `DEAD_LEGACY={main.gd}`）**：

```
SBF(new) 总命中(不含 ui_theme 豁免) = 187
  其中 live(不含 main.gd 死代码) = 166    dead(main.gd) = 21
```

⇒ **与工具自报的 166 逐字一致**，口径复现成功。

**归因方法（只读）**：`.workbuddy` 不入 git、`133` 个 `.gd` 未被 git 跟踪 ⇒ **无法 bisect**。改用**备份轨迹法**：对**每个含 SBF 的 .gd**，把「现盘 SBF 数」与「其最新 `.bak` 的 SBF 数」比较，枚举**净增文件**。全库结果 —— **只有两个文件净增**：

| 文件 | 最新 .bak | .bak SBF | 现盘 SBF | 净增 | 牵涉站点（现盘行号） |
|---|---|---:|---:|---:|---|
| `ui/page_world_map_visual.gd` | `…bak_p1font`（09-14 12:36） | 4 | 7 | **+3** | `:226` `var 条底: StyleBoxFlat = StyleBoxFlat.new()` / `:310` `var dsb: StyleBoxFlat = StyleBoxFlat.new()` / `:633` `var 斑式: StyleBoxFlat = StyleBoxFlat.new()` |
| `ui/sect_home_page.gd` | `…bak_relayout_20260915`（09-15 04:29） | 0 | 2 | **+2** | `:798` `var sb := StyleBoxFlat.new()` / `:829` `var 光晕sb := StyleBoxFlat.new()` |

（备份差分逐行证据见本报告 §5；`.bak_p1font` 原有 4 行均 `var style:…`，与现盘 `:432/:572/:698/:917` 对应，故**新增的恰是 `:226`/`:310`/`:633` 三行非-`style` 命名站点**。）

**★ 诚实边界（必须说清）**：

- 两文件**毛增合计 +5**（3+2），而**净增只有 +3** ⇒ 窗口内另有 **≥2 站被他处删除**抵消，故 **"+3 恰好等于哪三站"在现存证据下无法唯一钉死**。三条硬约束：
  1. 基线 `163` 生成于 **09-13**，比"最后已知 163"（09-16 07:17）早 3 天，**无 163 当刻的站点清单落盘**（当时报告写到了 `_out/audit_ui_report.txt`，已被后续运行覆盖）；
  2. `.workbuddy/` 被 gitignore ⇒ **没有提交点可 bisect**；
  3. 工作树 **133 个 `.gd` 未被 git 跟踪** ⇒ `git diff HEAD` 也**不可用**（我实跑验证，见 §5）。
- **最可能的三处**（唯一"单文件净增 = +3"者，与净增等长）：**`ui/page_world_map_visual.gd:226 / :310 / :633`**。
  次候选（同窗口毛增、被他处删除抵消）：`ui/sect_home_page.gd:798 / :829`。
- **另注**：这两处新增**均不在 `ui_theme.gd`**（`ui_theme.gd` 受 `SBF_EXEMPT` 豁免）⇒ **P0-A 批次与这 +3 无关**（与 art 线的「改前/改后 METRICS 逐字相同」举证一致）。

---

## 4. ④ 三值以谁为准 ＋「这个棘轮还能不能当判据用」

### 4.1 以谁为准（建议 · 供 team-lead 裁定）

| 用途 | 取值 | 理由 |
|---|---|---|
| **陈述"当前事实"** | **实测 166** | 脚本对现盘复算；他两值一个是目标、一个是 4 天前的快照，都不是现况 |
| **陈述"目标/验收线"** | **文档门 159** | 是 P0-4/ P0-A 明确写入的验收上限（比 json 更严） |
| **陈述"脚本门禁"** | **json 163（已废）** | 只是 09-13 首跑快照，**不得再作为通过/失败的判据** |

**建议**：三值分列、各标性质（事实 / 目标 / 已废快照），**不再对外只报一个数**。

### 4.2 棘轮还能不能当判据

**当前：不能当独立判据（只能当"趋势提示"）。** 依据三条：

1. **基线陈旧 4 天**：`audit_ui.py --strict` 现在必然 **FAIL**（`裸StyleBoxFlat 166 > 163`），**与代码好坏无关**——它报的是"4 天累计漂移"，不是"这一批有没有变坏"。**会污染 CI 信号**（典型 false 红）。
2. **基线整体过期**：同一次失败里，`硬编码Color 1242→1215`（**降 27**）、`字号越界 24→3`（**降 21**）都远超阈值——说明**其它三项早被真实改好了**，唯独被 4 天前的数字卡着；报 FAIL 反而**掩盖**了"净下降 69"的实况（这是 art 线 `report_before_after.md:145` 已察觉的）。
3. **尺子本身没问题**：`audit_ui.py` 口径自 09-13 冻结、`ui_theme.gd` 受豁免、复算可逐字重现 ⇒ **是"基准失效"，不是"工具坏"**。

**建议处置（二选一，均需 team-lead 指令；本轮未动基线）**：

- **方案 P（推荐）**：`--rebase` 把基线刷到**当前受控状态**（此刻 166 / 1215 / 561 / 3），并在 json 或紧邻文件写**"rebase 日期 + 当时 HEAD/说明"**；之后棘轮恢复"只减不增"语义、可作为本批的门。
- **方案 Q**：不 rebase，改为**"锚定式对比"**——每批前后各跑一次、**只比较该批的 `before/after` METRICS**（如 P0-A 的 `_ratchet_probe.txt` 那样自证"本批未移动指标"），**不引仓内 json**。适合"基线不可信、但想守住'单批不升高'"的场景。

> **不建议**：既不 rebase、又继续拿 `--strict` 的 FAIL 当"发布阻断"。那会把"4 天漂移"误判成"本批缺陷"，正是本轮口径混乱的来源。

### 4.3 ★ 该判据是否需要修正（直答 · 依 team-lead 给的 `_ratchet_probe` 线索）

**答：需要修正 —— 但要修的不是"阈值数字"，而是"判据形态"。**

**线索坐实**：`ui_theme.gd` 改前/改后两态 METRICS **逐字相同**（`{硬编码Color:1215, 裸StyleBoxFlat:166, 魔法数字尺寸:561, 字号越界:3} TOTAL=1945 BASE_TOTAL=2014`），两态**均** `RATCHET: FAIL 裸StyleBoxFlat`（rc=1，见 `.workbuddy/_ph7visual/_ratchet_probe.txt`）。⇒ **`166` 是改前既存、本批未动它**；FAIL 信号与本批代码**零因果**。

**为什么"修形态"而非"调数字"**：

| 现形态 | 失效机理 | 修正后 |
|---|---|---|
| `ratchet_fail = [k for k,v in METRICS if v > base.get(k,v)]`（**绝对水位棘轮**，base = 仓内 json） | 只有当"每次授权变更都 rebase 基线"时才成立。一旦基线不刷新（现状：json 冻结 09-13，4 天未 rebase），它测的是**累计漂移**，不是**本批增量** ⇒ 必然假红，且掩盖"Color −27 / 字号 −21"的净改善 | **相对棘轮**：`METRICS(after) ≤ METRICS(before)`（**只锁"本批不升高"**，不引仓内 json） |

**落地方案（承 §4.2）**：

- **立即**：判据改为 §4.2 **方案 Q**（本批 `before/after` 自证，如 `_ratchet_probe.txt`）——已实证可行，且与本批因果直接对齐。
- **随后**：完成 §4.2 **方案 P**（`--rebase` 到受控态 166/1215/561/3）后，**再**启用绝对水位棘轮；届时 json 才重新具备"门"的语义。
- **两条并行**时须在报告里**显式标注当前是哪种棘轮**，避免再把"绝对棘轮的 FAIL"当成"本批缺陷"。

**判据是否"要不要留"**：**留**（它有价值：`SBF_EXEMPT`/`DEAD_LEGACY` 口径清晰、复算可逐字重现）。**只改它比较的对象**（json → 本批 before）。

---

## 5. 附 · 证据清单（全部可复现 · 只读）

**复算脚本（临时，产出后已删）**：镜像 `audit_ui.py` 的 `SKIP_DIRS`/`BAK_HINT`/`SBF_EXEMPT`/`DEAD_LEGACY` 复算 SBF ⇒ 166（与工具逐字一致）。

**实跑命令与结果（要点）**：

- `git -C <root> rev-parse --is-inside-work-tree` → `true`（是 git 仓）。
- `git check-ignore -v .workbuddy/auto_ui/audit_ui_baseline.json` → **`.gitignore:12:.workbuddy/`** ⇒ 基线 json **被忽略**。
- `git log -- .workbuddy/auto_ui/audit_ui_baseline.json` → **空**（无提交可定位）。
- `git log -1 --format=%ci` → **2026-09-13 00:49:58**（HEAD `b4fdb0e`）⇒ 09-13 之后的全部 UI 改动**均未提交**。
- `git status --porcelain` → 未跟踪 `.gd` = **133 个**（含 `boot.gd` / `ui/battle_scene.gd` / `ui/page_achievement.gd` …）⇒ `git diff HEAD` 无法当"自基线以来的改动"用。
- 备份轨迹（每文件「现盘 SBF 数 vs 最新 .bak SBF 数」）⇒ 全库仅 `page_world_map_visual.gd`(+3) 与 `sect_home_page.gd`(+2) 净增。

**关键盘上原文（逐字）**：

- `audit_ui.py:271` `ratchet_fail = [k for k, v in METRICS.items() if v > base.get(k, v)]`
- `audit_ui.py:263` `if is_rebase or base is None:`（→ 只有首跑/`--rebase` 才写 json）
- `audit_ui.py:194-197` `if base not in SBF_EXEMPT: … viol_sbf.append(...)`；`:51 SBF_EXEMPT = {"ui_theme.gd"}`
- `_out/audit_ui_report.txt:213` `裸StyleBoxFlat             166        163  上升 ✗`
- `_out/audit_ui_report.txt:256` `棘轮判定：FAIL —— 以下指标高于基线：裸StyleBoxFlat`
- 施工清单 `批2-ui_theme漂移修正施工清单.md:193`（「裸 StyleBoxFlat ≤159」）

**未做（遵 team-lead 范围）**：未跑 `gate_all.py` / 未跑战斗探针 / 未起 Godot / 未 `--rebase` / 未改任何 `.gd`·`.json`。

---

*PH7-QA-19 ｜ quality-lead-2 ｜ 只读产出，未落任何代码/基线改动。*

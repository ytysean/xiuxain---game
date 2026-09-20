# PH7 · P0-A 底色漂移批 · 逐页 before/after 差分 QA 复核

- **执行**：quality-lead-2（严守真）· **独立跑**
- **口径基准**：老大 2026-09-17（逐页视觉精修=第一优先级；每视觉批由 QC 独立跑差分）
- **引擎**：`.workbuddy/_art_diff/diff_shots.py`（美术线；QA 独立 selftest PASS）＋ QA 执行器 `production/qa/qa16_diff_runner.py`
- **输入**：before=`.workbuddy/_ph7visual/baseline_before/`（64 页）｜ after=`.workbuddy/_ph7visual/after/`（64 页）
- **时点**：2026-09-17（after 摄于 01:30:20–01:30:22；ui_theme.gd 改于 01:28:33）
- **性质**：本报告是 P0-A 验收的**补充视觉证据**，**不单独判 PASS/FAIL**（须并入 §D 静态判据＋门0–6＋战斗红线）

---

## §1 硬闸门先验（两段式 · PASS）

| 段 | 判据 | 实测 | 判定 |
|---|---|---|---|
| **before-leg** | `min(before png mtime) > max(源文件 mtime · 排除本批)` | `01:27:19 > 00:56:19`（`ui\page_auction.gd`；本批 `ui_theme.gd` 已排除） | **PASS ✅** |
| **after-leg** | `min(after png mtime) > max(源文件 mtime · 含本批)` | `01:30:20 > 01:28:33`（`ui_theme.gd`） | **PASS ✅** |

- 佐证：`ui_theme.gd` md5 `21c4ece5ec30fdb09ec8b80354248af2`（改前）→ **`a3a5ff723e8538a26fa197be0c1ff4e3`**（改后）；`_apply_report.txt`：`edited_lines=26`。
- **★ 判据校正留痕（我上轮的错，已改）**：我上轮判「`ui_baseline_before/` 可当 before」是**错的** —— 该目录摄于 09-16 23:57，**早于** GO3(`game_state.gd` 00:39)/GO7(00:56) 落盘 ⇒ 是"GO3/GO7 之前"的旧态。team-lead 校正的两点已吸收：① 正解目录＝`.workbuddy/_ph7visual/baseline_before/`；② 判据从「只核 ui_theme.gd md5」升级为 **mtime 硬判据**（md5 只能证"底色没改"，**验不出文案/其它批次**，正是我上轮溜过的盲区）。

---

## §2 差分结论

- 配对 **64/64**（无缺页、无尺寸不符）；引擎判定：**可见变化 43 ｜ 未变 21 ｜ 位移 0**。
- 产物：`production/qa/_qa16_out/qa16_逐页差分.tsv`（machine）＋ `qa16_逐页差分.md`（human）＋ `cmp/<页id>_cmp.png`（**43 张左右并排图**，左=before 右=after）。

### §2.1 ★ 口径差公示（与美术线 `_p0a_diff.py` 对账 · 关键）

| 来源 | 判据 | 结果 |
|---|---|---|
| 美术线 `_p0a_diff.py` | **md5 不等 ∨ 任一像素≠0** ⇒ 变 | 变化 **64/64** |
| QA `qa16_diff_runner.py` | **改动像素占比 ≥ NOISE_TOL(0.05%)** ⇒ 变（滤 PIX_TOL=8 内噪点） | 变化 **43/64** |

**差额 21 页 = 亚阈值差异**（详见 §2.2）。两口径**均非错**，但**必须具名**：art 的「64/64 全变」含**量化噪声级**差异，若直接对老大报「64/64 全生效」会**高估本批覆盖面**。**建议对外口径取 QA 的 43 页**。

### §2.2 21 页「未变」的性质（探针实证）

对代表性页逐像素定位（`production/qa/_qa16_strip_probe.txt`）：

| 类型 | 页数 | 实证 | 性质 |
|---|---|---|---|
| **仅顶右条微变** | ~18 | >8 像素**全部**落在 `y=24..80, x=698..702`（约 244 px ＝ 0.026% 全页） | **真实但极微**：疑似顶右安全区/角标元素接了改后 token |
| **纯量化噪声** | 3 | `X04_宗主详情`/`X05_玩家交易`/`X06_离线管理`：>8 像素＝**0**，max 通道差 ≤ **6** | **视觉无变化**（md5 差异仅 PNG 量化） |

- 代表：`S01_丹方`、`S20_宗门舆图` 仅 244 px（全在段0 顶带）；`S38_科技` 顶带 + 段2 各一处；`X06` max=4。
- 对比：`S11_坊市` 9860 px 跨 4 个带区 ⇒ 真·可见变化。

---

## §3 可行动结论（供 team-lead / 美术 / 设计）

1. **P0-A 可见生效面 = 43 页**（名单见 TSV）；**21 页未被本批 token 触及主视觉**（18 仅顶右条 + 3 无变化）。
2. ⇒ 这 21 页正是**「逐页视觉精修」必须接管**的对象 —— **全局 token 修正到达不了它们的主背景**（候选：主背景为硬编码 `Color(...)`、或用了未纳入本批 26 行的其它 token）。**建议逐页回盘核 `Color(` 字面量**（与「未变页判据」同义）。
3. **归因观察（人工）**：多页主改签名重复出现 `#393631→#332F24`、`#34322E→#302B23` 等（暗暖底→更暗暖底），≈ `MAT_*`/面板渐变族 —— 与 `ui_theme.gd` 12 条 `MAT_*` 改值方向一致；但引擎「共享常量聚合」未触发（GLOBAL_MIN_PAGES=8，因各页区域均值异）⇒ **不建议**仅凭视觉差分反推 token 级归属。
4. **待并入 §D 静态判据**：本差分**不替代** §D 的 ① 26 行逐字节核 ② 语义出口值断言 ③ §5 移出行 not-FAIL ④ 枢纽常量四出口 ⑤ 门0–6 ＋ 战斗红线。**请 team-lead 确认 P0-A 是否已"落闸"**（若已落闸，我立即跑 §D 静态判据；纯静态、不启 Godot）。

---

## §4 产物清单

| 产物 | 路径 |
|---|---|
| 逐页差分 machine 表 | `production/qa/_qa16_out/qa16_逐页差分.tsv` |
| 逐页差分 human 报告 | `production/qa/_qa16_out/qa16_逐页差分.md` |
| 左右并排图（43） | `production/qa/_qa16_out/cmp/<页id>_cmp.png` |
| 基线先验（两段式） | `production/qa/_qa16_out/qa16_基线先验.txt` |
| after-leg 先验 | `production/qa/_qa16_out/qa16_after先验.txt` |
| 微量页定位探针 | `production/qa/_qa16_strip_probe.txt` |
| QA 执行器 | `production/qa/qa16_diff_runner.py` |

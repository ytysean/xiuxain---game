# D2 Phase 2 收口 · 独立验收报告

> **验收人**：严守真（quality-lead） · 游戏质量保障与测试工程师
> **验收对象**：commit `4f1daed7c6ad21288c2f625ca9535feb4ba78ebb`「style(ui): D2 进度条单源化收口——三处 ProgressBar 继承 .tres 默认绿样式」
> **项目**：《太玄宗门录》 `E:\Xiuxian\taixuanzongmenlu` · Godot 4.7 竖屏修仙经营
> **验收方式**：静态 + 代码级独立复验（沙箱无 Godot binary，真机 F5 像素签字留待用户本地）
> **验收日期**：2026-08-09
> **最终判定**：**✅ PASS（放行）· D2 收口结项** —— 主理人 2026-08-09 裁定，详见 [§9 主理人裁定与放行](#9-主理人裁定与放行)
> **QA 初判**：CONCERNS（核心目标全达成，R1/R2 提请主理人显式决策）→ 经裁定 R1/R2 定性为**前置提交时序历史债**、转后续专项待办，**不阻塞放行** → **改判 PASS**
> **T1 收尾复验**：✅ **已闭环（2026-08-09）** —— HEAD `sb_pbar_*` radius=6、索引洁净、G8 PASS → **R1 正式关闭**，§4.2 已更新（见 [§9.5.6](#最终结论956-r1-关闭签字先行呈现过程记录见下)）
> **D2 范围内唯一未决**：**T8 真机 F5 像素签字**（留待用户本地，见 §7·R4）——**在此之前本报告不构成最终发布签字**
> **范围外仍开放**：T2 显式路径纪律 / T4 索引洁净度预检 / T5 闸门正则+白名单断言 / **T6 `pre_f5_check.py` flaky 修复（优先级最高）** / T7 伴生文件入库（见 §9.3）

---

## 0. 判定摘要（TL;DR）

| 维度 | 结论 |
|---|---|
| D2 主目标（金→绿 + in-code 单源化） | ✅ **完全达成**，代码级实证 |
| 三道闸门 | ✅ **全部 EXIT 0**（串行裸跑真值） |
| 红线（main_theme.tres / G8 / tests / data 零触碰） | ✅ **全部未触碰** |
| 新增闸门有效性 | ✅ **变异测试证伪通过**（不是空断言） |
| 回归 / 功能缺陷 | ✅ **零回归、零功能缺陷** |
| 横向一致性 corner_radius=6 | ✅ **已闭环**（T1 复验：HEAD 提交态 `sb_pbar_*` radius=6，三处一致）→ **R1 已关闭** |
| 仓库卫生（暂存区脏） | ✅ **已清空**（T1 复验：`git status --porcelain` 无 `M`/`A`/`D`，索引洁净）→ R2 短期风险解除 |
| 真机像素签字 | ⏸ **留待用户本地 F5**（见 R4，照例留置） |
| **最终门禁** | **✅ PASS · 放行** |

**放行依据（主理人裁定）**：核心目标 6/6 达成、三闸全绿、零红线触碰、零回归、零功能缺陷、变异测试证伪闸门有效。R1/R2 根因均在 **D2 范围之外**（P1-B / T5-fix 前置未提交、暂存区历史累积），非 D2 引入之缺陷，转「后续专项待办」处理。

> 📌 **QA 立场留痕（原始初判，不删）**：我方初判 CONCERNS 的理由是——D2 的颜色意图（金→绿）与单源化机制均已在提交态闭环、零红线触碰，这部分可签字；但验收清单第 4 条「三处 ProgressBar 全局 corner_radius=6」在**提交态（HEAD）下不成立**，该断言依赖一份尚未提交的 P1-B `.tres` 变更。这不是 D2 引入的缺陷，而是 D2 的一致性声明**挂在了别人未落地的前置上**，故当时判定应由主理人裁定提交顺序，而非由 QA 单方放行。
> 初判亦已明确「**为何不是 FAIL**」：无任何红线触碰、无回归、无功能性缺陷，闸门全绿且经证伪验证；R1 属范围/顺序问题，非质量缺陷。
> **主理人已就此作出裁定并承接后续专项 → 判定升级为 PASS。原始诊断证据全部保留于 §4 / §7，供后续专项直接引用。**

---

## 1. 变更 diff 清单核对

`git show 4f1daed --name-status --pretty=format:` 真值输出：

| 状态 | 文件 | 说明 |
|---|---|---|
| `M` | `design/06-角色与UI/5页样式收口规范.md` | §3.6 等过时描述对齐现状（+6/−6 行） |
| `M` | `pre_f5_check.py` | 新增 `check_progress_bar_single_source()`（+40 行） |
| `A` | `ui/page_battlepass.gd` | 新增纳入版本控制（+240 行）——此前 untracked，属正常 |
| `M` | `ui/page_building.gd` | 删 in-code 金 fill/bg（+2/−8 行） |

合计 **4 files changed, 288 insertions(+), 14 deletions(-)**。

**核对结论**：文件清单与主理人裁定边界 1/2/5/6 逐条对应。裁定边界 3（`page_disciple.gd` 免改）→ 该文件确实**不在** commit 中，符合「白名单免改」预期。

---

## 2. 三道闸门签字（串行裸跑，PYTHONIOENCODING=utf-8）

> ⚠️ **取值方法说明**：首轮我将 `pre_f5_check.py` 与 `tools/p1b_token_gate.py` **并行**执行，`pre_f5` 报 `EXIT=1`。经排查为**假 FAIL**（详见 R5），非代码缺陷。以下为**串行**重跑真值。

| # | 闸门 | 退出码 | 判定 | 关键证据 |
|---|---|---|---|---|
| 1 | `python pre_f5_check.py` | **EXIT=0** | ✅ PASS | 总判定 `[PASS] 全部通过，可放心 F5`；24 项子闸门全绿 |
| 2 | `python tools/p1b_token_gate.py` | **EXIT=0** | ✅ PASS | 合计 8 项：**PASS 7 / WAIVED 1 / FAIL 0** |
| 3 | `python gdscript_type_check.py` | **EXIT=0** | ✅ PASS | `ALL CLEAN`，Scanned: 55 files |

### 2.1 闸门 1 关键行（本次新增闸门）

```
[22/22] 品阶色单一数据源校验   [PASS]  品阶色已收口至 UIThemeConfig（main.gd 无硬编码字典，入口已委托）
[23/23] 进度条单源化校验       [PASS]  ProgressBar 进度条全部继承 .tres 默认样式（白名单 page_disciple.gd 动态色除外）
[24/24] 阵法拆解经济校验       [PASS]  全部可拆解阵法 拆解返还≤投入 且 L1 产出=0
```

**[23] 进度条单源化校验 = PASS** ✅（主理人指定必查项）

### 2.2 闸门 2 · G8 颜色红线（硬红线）

```
[PASS  ] G8  颜色零改动（硬红线）
         main_theme.tres 色行 42 条指纹一致；#2C5F52 渲染路径 2 处未变
         （addons/taixuan_ui_editor/data_manager.gd×1、main.gd×1）
[PASS  ] G7  pre_f5_check.py EXIT 0
```

**我方独立复算指纹（不采信闸门自述）**：

```
色行数 = 42
SHA256 = 346884663b08f23a292b1e4fdc4bb0bcde80417dc91976f1aa7dde7d1a8dfbd2
```

42 条色行与 G8 自述数量一致。**G8 零触碰确认。**

> G3 为 `WAIVED`（`art/auto_ui/scenes/main_menu.tscn` 5 处内联字号，按 P1-B 裁定 Q4 推迟 S2）——**属既有豁免，非本次 D2 引入**。

---

## 3. 代码层核对（逐文件实证）

### 3.1 `ui/page_building.gd` — ✅ 通过

删除的 8 行（in-code 金 fill / bg 重建）：

```gdscript
-	var fill := StyleBoxFlat.new()
-	fill.bg_color = UITheme.color_text_gold()      # ← 金 fill，D2 裁定移除
-	fill.set_corner_radius_all(UITheme.RADIUS_BUTTON)
-	bar.add_theme_stylebox_override("fill", fill)
-	var bg := StyleBoxFlat.new()
-	bg.bg_color = UITheme.color_bg_content()
-	bg.set_corner_radius_all(UITheme.RADIUS_BUTTON)
-	bar.add_theme_stylebox_override("background", bg)
```

全文件扫描 `Color(` / `color_text_gold` / `StyleBoxFlat.new()` / `add_theme_stylebox_override` 结果：

```
559: panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
864: panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
897: panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
933: var bar := ProgressBar.new()
```

- `color_text_gold` 出现次数 = **0** → 金 fill 已彻底移除 ✅
- `StyleBoxFlat.new()` = **0** ✅
- ProgressBar（L933）**无任何 fill/background 覆盖** ✅
- 残留 3 处 `"panel"` 覆盖为 **PanelContainer 面板样式**（走 `UITheme.make_panel_stylebox`），**非 ProgressBar**，不在 D2 范围，合规保留 ✅

### 3.2 `ui/page_battlepass.gd` — ✅ 通过

```
20: var _进度条: ProgressBar
79: _进度条 = ProgressBar.new()
```

- `Color(` = **0** ✅
- `StyleBoxFlat.new()` = **0** ✅
- `add_theme_stylebox_override` = **0** ✅

ExpBar 完全继承 `.tres` 默认，零 in-code 重建。

### 3.3 `ui/page_disciple.gd` — ✅ 通过（白名单合法例外）

in-code 机制保留（`_make_progress`，L656–675）：

```gdscript
bg.bg_color   = UITheme.COLOR_BG_CONTENT          # 常量，非裸 Color
fill.bg_color = fill_color                        # 参数，来源见下
bar.add_theme_stylebox_override("background", bg)
bar.add_theme_stylebox_override("fill", fill)
bar.add_theme_stylebox_override("disabled", bg)
```

**四处调用方 fill 来源逐条追溯**（硬约束：必须取自 UITheme token，禁裸 `Color()`）：

| 行 | 调用 | fill 来源 | 判定 |
|---|---|---|---|
| L506 | 修炼进度 | `UITheme.COLOR_TEXT_GOLD` | ✅ token |
| L507 | 瓶颈打磨 | `UITheme.COLOR_STATUS_SUCCESS` | ✅ token |
| L509 | 丹毒(心魔风险) | `丹毒色` → L508 `UITheme.COLOR_STATUS_SUCCESS if 丹毒v < 0.5 else UITheme.COLOR_TEXT_RED` | ✅ token（三元两支均为 token） |
| L510 | 道心(待实装) | `UITheme.COLOR_TEXT_AUX` | ✅ token |

**裸 `Color(` 字面量计数 = 0**（全文件） → 硬约束 3 满足 ✅

> 说明：实现取的是 `UITheme.COLOR_*` **常量**形式而非 `color_*()` getter 形式。二者同源（`ui_theme.gd:203 func color_bg_content() -> Color: return COLOR_BG_CONTENT`），语义等价，**不构成偏差**。

### 3.4 `pre_f5_check.py :: check_progress_bar_single_source()` — ✅ 逻辑正确且经证伪

实现要点复核：
- 扫描范围 `ui/*.gd`，白名单 `whitelist = {"page_disciple.gd"}` ✅
- 断言正则 `add_theme_stylebox_override\(\s*"(fill|background)"` ✅
- 命中即记 `文件:行号`，返回 `(ok, summary, detail)` 三元组，与其余闸门签名一致 ✅
- 已注册进 `main()` 编排表 → 输出为 `[23]` ✅

**⭐ 变异测试（Mutation Test）——验证该断言不是空转**：

我临时注入违规探针 `ui/__qa_probe.gd`（含 `bar.add_theme_stylebox_override("fill", fill)`），单独调用闸门函数：

```
OK= False
SUMMARY= ProgressBar 单源化违规 1 处（非白名单文件不得手写 fill/background 覆盖）
DETAIL= __qa_probe.gd:5 仍存在 in-code ProgressBar 样式覆盖（应继承 .tres 默认）
```

**闸门正确捕获违规并精确定位行号 → 该闸门具备真实拦截力，非「永远 PASS」的假断言。** 探针已删除，`ui/__qa_probe.gd` 已确认不存在，工作区无残留。

**白名单有效性**：`page_disciple.gd` 实际含 2 处 `fill`/`background` 覆盖（L668/L673），闸门仍 PASS → 白名单确实生效 ✅

**全仓普查佐证**（`grep -rn 'add_theme_stylebox_override("fill"|"background")' ui/*.gd`）：

```
ui/page_disciple.gd:668
ui/page_disciple.gd:673
```

全仓仅剩白名单文件，**闸门覆盖范围与实际状态完全吻合** ✅

---

## 4. 横向一致性核对

| 项 | 期望 | 工作区实测 | HEAD 提交态实测 | 判定 |
|---|---|---|---|---|
| battlepass fill | `.tres` 绿 `#7ED39A` | ✅ 继承 | ✅ 继承 | ✅ |
| building fill | `.tres` 绿 `#7ED39A` | ✅ 继承 | ✅ 继承 | ✅ |
| disciple fill | token 动态色 | ✅ 4 处全 token | ✅ | ✅ |
| `.tres` sb_pbar_fill 色 | `#7ED39A` | `Color(0.4941, 0.8275, 0.6039, 1)` | **同上，未变** | ✅ |
| `.tres` sb_pbar_bg 色 | `#2C3D43` | `Color(0.1725, 0.2392, 0.2627, 1)` | **同上，未变** | ✅ |
| **corner_radius 全局=6** | 6 | **6** ✅ | 验收时 `4f1daed` 态 = ~~**4**~~ ❌ → T1 后 `ad19e77` 态 = **6** ✅ | ✅ **已闭环**（R1 已关闭，见 §4.2 / §9.5.6） |

> 表内「HEAD 提交态实测」列为**验收当时（HEAD = `4f1daed`）**的实测值。T1 专项提交 `a329b3e` + `ad19e77` 后 HEAD 已前移，`sb_pbar_*` radius 固化为 6 —— 原始 4 值按留痕原则保留删除线呈现，不抹除。

### 4.1 像素等价性核算（disciple in-code bg vs .tres bg）

- `ui_theme.gd:23` `COLOR_BG_CONTENT = Color(0.173, 0.239, 0.263)`
- `.tres sb_pbar_bg` `Color(0.1725, 0.2392, 0.2627, 1)`

8-bit 量化：`0.173×255=44.12→44=0x2C`；`0.1725×255=43.99→44=0x2C` ／ `0.239→61=0x3D`，`0.2392→61=0x3D` ／ `0.263→67=0x43`，`0.2627→67=0x43`
→ 两者均量化为 **#2C3D43**，**渲染像素完全一致** ✅（浮点字面量精度差异不影响出图）

### 4.2 圆角一致性（⚠️ 原关键发现 → ✅ **已闭环**）

`ui_theme.gd:188 const RADIUS_BUTTON: int = 6`，disciple in-code 用 `set_corner_radius_all(RADIUS_BUTTON)` = **6**。

#### 【D2 验收时 · 2026-08-09 初测】原始发现（保留，不删）

- **工作区** `theme/main_theme.tres` sb_pbar_bg/fill `corner_radius = 6` → 三处一致 ✅
- **HEAD 提交态** `git show HEAD:theme/main_theme.tres` sb_pbar_bg/fill `corner_radius = **4**` ❌

→ 在**干净检出 4f1daed** 的场景下，battlepass/building 进度条圆角 = 4，disciple = 6，**横向不一致**，且 building 相对改动前（原 in-code `RADIUS_BUTTON`=6）会出现 **6→4 的 2px 圆角回退**。详见 R1。

#### 【T1 复验 · 已闭环】提交态实测：`corner_radius = 6` ✅

前置清理已提交（`a329b3e` T5-fix + 主题挂载 + P1-B 令牌/圆角/字号；`ad19e77` M2-M3 场景层颜色单源化），
`sb_pbar_*` 圆角已固化进 HEAD。**`git show HEAD:theme/main_theme.tres` 原始输出**（2026-08-08 主理人独立 Bash 环境裸跑真值）：

```
[sub_resource type="StyleBoxFlat" id="sb_pbar_bg"]                    (L197)
bg_color = Color(0.1725, 0.2392, 0.2627, 1)   ; bg.content #2C3D43    (L198)
corner_radius_top_left     = 6                                        (L203)
corner_radius_top_right    = 6                                        (L204)
corner_radius_bottom_right = 6                                        (L205)
corner_radius_bottom_left  = 6                                        (L206, 对称同值)

[sub_resource type="StyleBoxFlat" id="sb_pbar_fill"]                  (L212)
bg_color = Color(0.4941, 0.8275, 0.6039, 1)   ; 进度条 success #7ED39A (L213)
corner_radius_top_left     = 6                                        (L218)
corner_radius_top_right    = 6                                        (L219)
corner_radius_bottom_right = 6                                        (L220)
corner_radius_bottom_left  = 6                                        (L221, 对称同值)
```

**闭环后横向一致性终值**：

| 位置 | fill 来源 | corner_radius | 判定 |
|---|---|---|---|
| `page_building.gd` 升级条 | `.tres` 绿 `#7ED39A` | **6**（继承 `.tres`） | ✅ |
| `page_battlepass.gd` ExpBar | `.tres` 绿 `#7ED39A` | **6**（继承 `.tres`） | ✅ |
| `page_disciple.gd` ×4 动态条 | UITheme token 动态色 | **6**（in-code `RADIUS_BUTTON`） | ✅ |

→ **三处 ProgressBar 全局 `corner_radius = 6` 在提交态成立**；`page_building.gd` 注释「radius=6 由 .tres 继承，像素等价」的声明**现已属实**，6→4 回退风险消除。
→ **主理人验收清单第 4 条「三处 ProgressBar 全局 corner_radius=6」正式达成 ✅**，**R1 关闭**（详见 §9.5）。

---

## 5. 红线核对

| 红线 | 检查方法 | 结果 |
|---|---|---|
| `main_theme.tres` 零触碰 | `git show 4f1daed --name-only --pretty=format:` 精确比对（**排除 commit message 干扰**） | ✅ **不在变更清单** |
| 任何 `.tres` 零触碰 | 同上，过滤 `\.tres$` | ✅ **本 commit 未改动任何 .tres** |
| `theme/main_theme.tres` 差异 | `git diff 4f1daed~1 4f1daed -- theme/main_theme.tres --stat` | ✅ **空输出（零差异）** |
| G8 颜色指纹 | `tools/p1b_token_gate.py` 裸跑 + 我方独立 SHA256 复算 | ✅ **42 色行一致** |
| `tests/` 零触碰 | `git show --name-only \| grep -E '^tests/'` | ✅ **零命中** |
| `data/` 零触碰 | `git show --name-only \| grep -E '^data/'` | ✅ **零命中** |

> 🔍 **取证纠错留痕**：我首轮用 `git show 4f1daed --name-only \| grep -i main_theme.tres` 得到命中，一度判为「触碰」。经复核为**我方误报**——`--name-only` 默认包含 commit message，而该 message 正文含「不动 main_theme.tres」字样被 grep 命中。改用 `--pretty=format:` 剥离 message 后确认**零触碰**，并以 `git diff` 空输出双重佐证。此处记录以免后续误读。

---

## 6. 文档核对

`design/06-角色与UI/5页样式收口规范.md` §3.6 及关联段落（§6.1 / §6.2 / §6.3）修正后描述与现状**逐条吻合**：

| 文档声明 | 独立核实 | 判定 |
|---|---|---|
| top_bar 手写 ProgressBar 覆盖「已删除」 | `grep -n "ProgressBar\|_progress" ui/top_bar.gd` → **空** | ✅ 属实 |
| 该删除发生于 commit `cd53084` | `git log --oneline -1 cd53084` → `style(ui): 顶栏删手写 ProgressBar 覆盖，等级进度条改绿（D2）` | ✅ **commit 真实存在且语义吻合** |
| 风险等级由「低中」降为「低」 | 覆盖已删、无待办 | ✅ 合理 |
| §6.3 D2 待决项改为「已拍板（绿）」 | 与主理人裁定一致 | ✅ |
| §6.2 回退策略删除「金/绿临时态」 | 与现状一致 | ✅ |

> 📝 **微瑕（不阻断）**：文档标注「D2 已拍板（2026-07-29 · D2 收口）」，而本次 commit 日期为 2026-08-08。日期指向拍板日而非落地日，语义可接受，但建议补一句落地 commit 号 `4f1daed` 以便追溯。

---

## 7. 已知风险与缓解

### R1 · 横向一致性依赖未提交的 P1-B `.tres` 变更 —— ~~Major / 需主理人决策~~ → 已裁定转专项 T1 → ✅ **已关闭（2026-08-09，T1 复验闭环，见 §9.5.6）**

**现象**：`theme/main_theme.tres` 存在**大量已暂存但未提交**的 P1-B/M2/M3 变更，其中包含 `sb_pbar_bg` / `sb_pbar_fill` 的 `corner_radius 4 → 6`。

**影响**：
- 主理人验收清单第 4 条「三处 ProgressBar 全局 `corner_radius=6`」**仅在当前工作区成立**；
- 干净检出 commit `4f1daed` 时，battlepass/building 圆角为 **4**、disciple 为 **6** → 横向不一致；
- 且 building 进度条相对改动前（in-code `RADIUS_BUTTON`=6）会 **6→4 回退 2px**，与 `page_building.gd` 内注释「radius=6 由 .tres 继承，**像素等价**」的声明**在提交态下不成立**。

**不影响**：颜色意图（金→绿）与 `#7ED39A`/`#2C3D43` 色值在**两种状态下完全一致**，G8 指纹不受影响。**D2 的颜色目标本身是安全的。**

**缓解建议（三选一，请主理人裁定）**：
1. **推荐**：将 P1-B 的 `theme/main_theme.tres` 变更**先行独立提交**（走 G8 复验），使 radius=6 进入提交态，D2 一致性声明随之成立；
2. 若 P1-B 暂不落地：把 `page_building.gd` 注释中的「像素等价」修正为「圆角随 `.tres` 当前档位，P1-B 落地后统一为 6」，避免注释与提交态失配；
3. 维持现状但在验收结论中**显式标注**该断言的适用范围为「工作区」。

> ✅ **裁定结果（2026-08-09 主理人）**：**采纳选项 ① 精神并扩大为根治**——将 **T5-fix + P1-B** 这批前置作为**独立检查点提交**，固化 `sb_pbar` radius=6 进 HEAD，使 D2「继承 `.tres`=6」的断言在提交态成立。认定 D2 代码本身正确、金→绿安全（颜色两态一致、G8 不受影响），根因在前置未落地而非 D2。**此清理属 D2 范围外专项，不阻塞 D2 放行。** → 详见 §9·T1。

---

### R2 · 暂存区已挂载 `main_theme.tres`，下次裸 commit 会误带 —— ~~Major / 流程风险~~ → **已裁定：历史累积债，转专项 + 即时纪律，不阻塞放行** → ⚠️ **短期风险已解除（T3 完成，索引洁净），T2/T4 纪律与加固项仍开放**

**现象**：`git status --porcelain` 显示 `M  theme/main_theme.tres`（**M 在第 1 列 = 已入暂存区**），同时暂存的还有 `project.godot`、`ui_theme.gd`、`ui/bottom_tab_bar.gd/.tscn`、`ui/home_page.tscn`、`ui/sect_home_page.tscn`、`ui/top_bar.tscn`、`.gitignore`。

**影响**：D2 本次之所以「零触碰」，是因为提交时**显式指定了文件路径**。但只要后续任何人执行一次不带路径的 `git commit`，这批暂存变更（含 `main_theme.tres`）会被**静默扫入**该 commit → 届时 G8 红线将呈现为「被触碰」，且污染的是一个与颜色无关的 commit，追溯成本高。

**缓解建议**：
- 短期：后续所有 commit **强制显式列出文件路径**，禁止裸 `git commit`；
- 根治：尽快将暂存区内容按主题拆分提交（P1-B `.tres` 一笔、`ui_theme.gd` 一笔……），把索引清空；
- 加固：在 `tools/p1b_token_gate.py` 增加一项「索引洁净度」预检——若 `main_theme.tres` 处于 staged 状态则告警。

> ✅ **裁定结果（2026-08-09 主理人）**：认定为**历史累积债，非 D2 引入**；D2 的「零触碰」靠显式路径提交实现，**纪律正确**。三项缓解**全部采纳**：①短期纪律——所有 commit 强制显式路径、**禁止裸 `git commit`**（即时生效）；②根治——按主题（**T5-fix / P1-B / M2-M3**）拆分提交清空索引；③技术加固——`p1b_token_gate` 增加「索引洁净度」预检。**不阻塞 D2 放行。** → 详见 §9·T2 / T3 / T4。
>
> 🔄 **执行进展（2026-08-09 T1/T3 复验）**：②**已落地** —— 索引已按主题拆为 `a329b3e` + `ad19e77`，`git status --porcelain` 仅剩 `??` untracked，**「裸 commit 静默扫入 `main_theme.tres`」这一具体风险已消除**（T3 完结）。①属长期纪律、③闸门预检**尚未实现**——即索引若再次被填充，同样的风险会重现且**当前无自动化拦截**。**故 R2 整体不判关闭，仅降级为「短期风险已解除」，T2/T4 保持开放。**

---

### R3 · 新增闸门存在两处覆盖盲区 —— ~~Minor / 建议加固~~ → **已裁定：采纳为后续基建改进项**

1. **`"disabled"` stylebox 未纳入断言**：正则仅匹配 `fill|background`。`page_disciple.gd:674` 实际用了 `add_theme_stylebox_override("disabled", bg)`。当前因白名单豁免无碍，但**非白名单文件**若用 `"disabled"` 重建 ProgressBar 样式，可绕过闸门。建议正则扩为 `(fill|background|disabled)`。
2. **白名单是「整文件跳过」，未落实「禁裸 Color」硬约束**：主理人裁定 3 要求 disciple 的 fill 必须取自 UITheme token。当前闸门对该文件**完全不检查**，该硬约束靠人工核对（本次我已人工核实通过：裸 `Color(` = 0）。建议白名单改为「不检查 stylebox 覆盖，但**追加检查该文件裸 `Color(` 字面量 = 0**」，把人工约束固化为自动断言，防止后续回归。
3. **正则不区分控件类型**：`add_theme_stylebox_override("background", ...)` 在非 ProgressBar 控件上亦会被判违规（偏严）。当前全仓无此用法，属**安全的偏严**，仅记录备查。

---

### R4 · 真机 F5 像素签字未完成 —— **待用户执行 / 按预案留置**

沙箱无 Godot binary，本报告全部结论为**静态 + 代码级**。以下需用户本地 F5 目视确认：
- [ ] 殿阁页（building）升级进度条 fill 由**金变绿** `#7ED39A`，bg `#2C3D43`，无突兀
- [ ] 战令页（battlepass）ExpBar 绿 fill 正常渲染，非透明/非黑（确认 `.tres` 确已挂载生效）
- [ ] 弟子页（disciple）四条进度条动态色正常：修炼=金 / 打磨=绿 / 丹毒<50%=绿 ≥50%=红 / 道心=辅助灰
- [ ] 三处进度条圆角观感一致（~~**与 R1 强相关**——若 P1-B 未提交，此项预计会看到 building/battlepass 比 disciple 略方~~ → **R1 已闭环**：P1-B 已随 `a329b3e` 进 HEAD，`sb_pbar_*` radius=6，**预期三处观感一致**；若仍见 building/battlepass 偏方，属新问题，请回报）
- [ ] 进度条无 content_margin 导致的 fill 内缩/错位

**若 F5 出现 fill 不显示**：优先排查 `project.godot` 是否绑定 `theme/main_theme.tres` 为默认主题（~~`project.godot` 亦在暂存区，见 R2~~ → **主题挂载已随 `a329b3e` 提交进 HEAD，索引已清空**；此项若仍复现，说明挂载路径或 `theme/` 资源本身有问题，非暂存区遗漏）。

---

### R5 · `pre_f5_check.py` 并发不安全，存在 flaky 假 FAIL —— ~~Minor / 测试稳定性~~ → **已裁定：采纳，优先级最高的基建改进项**

**现象**：首轮并行执行 `pre_f5_check.py` 与 `tools/p1b_token_gate.py` 时，`pre_f5` 抛异常退出：

```
PermissionError: [WinError 5] 拒绝访问。:
'...\Temp\build_style_board.py.pre_f5_compile.2115640761008'
-> '...\Temp\build_style_board.py.pre_f5_compile'
EXIT=1
```

**根因**：`check_python_compile()`（`pre_f5_check.py:603`）将 `.pyc` 写入**共享 `%TEMP%` 下的固定文件名** `<name>.py.pre_f5_compile`，无 PID/唯一化后缀。而 `p1b_token_gate.py` 的 **G7 会以子进程再次调用 `pre_f5_check.py`** → 两个 `pre_f5` 进程同时对同一目标文件做原子 rename → Windows 下触发 WinError 5。

**佐证**：同一轮中 p1b 的 G7 反而报告 `pre_f5_check.py EXIT 0`（子进程先完成），与外层 EXIT=1 自相矛盾；改为**串行**后连续两次 `EXIT=0`、`PermissionError` 计数为 **0**，稳定复现结论。

**结论**：**与 D2 变更无关**，为既有基础设施缺陷。但它会污染 CI 信号——任何两次闸门运行重叠即随机假 FAIL。

**缓解建议**：`check_python_compile()` 改用 `tempfile.mkdtemp()` 建每轮独立目录，或 cfile 名加 `os.getpid()`；在此之前，**约定闸门串行执行**，且 `%TEMP%` 下已积压大量历史 `*.pre_f5_compile` 残留文件建议清理。

---

### R6 · `page_battlepass` 伴生文件未纳入版本控制 —— ~~Minor / 仓库完整性~~ → **已裁定：采纳为后续基建改进项**

`git ls-files` 实测：

```
ui/page_battlepass.gd          ← 已跟踪（本次 A）
ui/page_battlepass.tscn        ← 未跟踪
ui/page_battlepass.gd.uid      ← 未跟踪
```

`.gd` 已入库但 `.tscn` / `.uid` 仍 untracked。Godot 4 依赖 `.uid` 做资源引用解析，干净检出可能出现引用漂移。

**注**：这是**既有的仓库卫生问题、非 D2 引入**——`page_quest` / `page_shop` / `page_storage` / `page_xianyu` / `home_page` 等一整批新页面同样处于 untracked 状态。建议独立开一个「新页面入库」批次统一处理，不建议塞进 D2。

---

## 8. 验收判定

> ### 最终判定：**✅ PASS（放行）**
> （核心目标 6/6 达成、三闸全绿、零红线触碰、零回归、零功能缺陷、变异测试证伪闸门有效；
> R1/R2 经主理人裁定定性为**前置提交时序 / 历史累积债**，非 D2 引入之缺陷，转后续专项待办，**不阻塞放行**）
>
> **判定演进**：QA 初判 `CONCERNS`（两项非缺陷类风险提请主理人显式决策）→ 主理人 2026-08-09 裁定并承接后续专项 → **改判 `PASS`** → **T1 复验闭环、R1 正式关闭（2026-08-09）→ D2 收口结项**。
> 初判的原始诊断证据与立场全部保留（§0 留痕 / §4 / §7 / §9.5.1–9.5.5），未作删改。

### ✅ 已达成（可签字部分）

1. **裁定 1 达成**：`page_building.gd` in-code 金 fill 已删（`color_text_gold` 归零），ProgressBar 无 fill/bg 覆盖，继承 `.tres` 绿；
2. **裁定 2 达成**：`page_battlepass.gd` 零 `StyleBoxFlat.new()`、零 stylebox 覆盖、零 `Color(`；
3. **裁定 3 达成**：`page_disciple.gd` 四处动态 fill **全部** token 化，裸 `Color(` 字面量 = **0**；
4. **裁定 4 达成**：`main_theme.tres` **零触碰**（三重取证），G8 42 色行指纹一致（我方独立 SHA256 复算佐证）；
5. **裁定 5 达成**：新增闸门实现正确、白名单生效、已注册为 `[23]`，且**变异测试证明具备真实拦截力**；
6. **裁定 6 达成**：文档 §3.6 与现状吻合，所引 commit `cd53084` 真实存在且语义匹配；
7. **三道闸门串行裸跑全部 EXIT 0**；`tests/`、`data/` 零触碰。

### ⚖️ 提请决策项 → 已裁定（不阻塞放行）

| 编号 | 事项 | 提请的决策 | 裁定结果 |
|---|---|---|---|
| **R1** | 圆角一致性依赖未提交的 P1-B `.tres`（HEAD 态 radius=4，工作区=6） | 先提交 P1-B `.tres` ／ 修正 building 注释措辞 ／ 接受并标注适用范围 | **采纳①并扩大为根治**：T5-fix + P1-B 作独立检查点提交，固化 radius=6 进 HEAD。属 D2 范围外专项 → §9·T1 |
| **R2** | 暂存区挂着 `main_theme.tres` 等 9 项，下次裸 commit 会误带、触发 G8 红线 | 是否立即拆分提交清空索引；是否强制「commit 必带路径」纪律 | **三项缓解全采纳**：即时纪律 + 按主题拆分提交 + 闸门加索引洁净度预检 → §9·T2/T3/T4 |

### ⏸ 留置项

- **R4 真机 F5 像素签字**：沙箱无 Godot binary，须由用户本地执行 §7·R4 清单。**本报告不代替像素签字**——按裁定「照例留待用户本地 F5」，属放行后的常规验证动作，不构成放行前置。

### 📌 建议 → 已采纳为后续基建改进项

- **R3**：闸门正则补 `disabled`；白名单改为「豁免 stylebox 检查 + 追加裸 `Color(` = 0 断言」，把人工约束固化 → §9·T5；
- **R5**：`check_python_compile()` 唯一化临时文件名，消除 flaky；**在修复前闸门必须串行执行** → §9·T6（优先级最高）；
- **R6**：另开批次将 `page_battlepass.tscn/.uid` 等一批新页面伴生文件统一入库 → §9·T7。

---

## 9. 主理人裁定与放行

> **裁定人**：游承峰（主理人 · team-lead）
> **裁定日期**：2026-08-09
> **裁定结论**：**D2 Phase 2 = ✅ PASS（放行）**

### 9.1 放行理由（主理人原文要点）

核心目标 **6/6 达成**、**三闸全绿**、**零红线触碰**、**零回归**、**零功能缺陷**、**变异测试证伪闸门有效**；
R1/R2 为**前置提交时序历史债**，转「后续专项待办」，**不阻塞本次放行**；
R4 真机像素签字**照例留待用户本地 F5**。

### 9.2 逐项裁定

#### R1 裁定 —— 采纳选项①精神，扩大为根治

- **认定**：D2 代码本身正确、金→绿安全（颜色两态一致、G8 不受影响）。
- **根因定性**：横向不一致的根因是 **P1-B 的 `.tres`（含 `sb_pbar` radius 4→6）+ T5-fix 一直 staged 未提交**，使 D2「继承 `.tres`=6」在提交态依赖未落地的前置。**非 D2 引入。**
- **处置**：将 **T5-fix + P1-B** 这批前置作为**独立检查点提交**（固化 pbar radius=6 进 HEAD），使 D2 断言在提交态成立。
- **边界**：此清理属 **D2 范围外专项**，**不阻塞 D2 放行**。

#### R2 裁定 —— 历史累积债，纪律 + 根治 + 加固三管齐下

- **认定**：暂存区脏为**历史累积债，非 D2 引入**；D2 的零触碰靠**显式路径提交**实现，**纪律正确**。
- **短期纪律（即时生效）**：所有 commit **强制显式路径**，**禁止裸 `git commit`**。
- **根治**：按主题（**T5-fix / P1-B / M2-M3**）拆分提交，清空索引。
- **技术加固**：`tools/p1b_token_gate.py` 增加「**索引洁净度**」预检。

#### R3 / R5 / R6 裁定 —— 全部采纳为后续基建改进项

其中 **R5 尤其重要**：`pre_f5_check.py` 并发固定文件名需改 `tempfile.mkdtemp()` + PID；**在修复前，闸门必须串行跑。**

### 9.3 后续专项待办清单

| ID | 来源 | 待办事项 | 类型 | 优先级 | 阻塞 D2？ |
|---|---|---|---|---|---|
| **T1** | R1 | 将 **T5-fix + P1-B** 作为独立检查点提交，固化 `sb_pbar` radius=6 进 HEAD（须走 G8 复验）<br>→ ✅ **已完成**：`a329b3e` + `ad19e77` 提交，HEAD radius=6、索引洁净、G8 PASS；**QA 复验闭环，R1 已关闭**（§9.5.6） | 前置债根治 | 高 | ✅ **已完结** |
| **T2** | R2 | **即时纪律**：所有 commit 强制显式路径，禁止裸 `git commit` | 流程纪律 | **即时生效** | ❌ 否 |
| **T3** | R2 | 按主题（T5-fix / P1-B / M2-M3）拆分提交，清空暂存区索引<br>→ ✅ **已完成**：拆为 `a329b3e`（T5-fix + 主题挂载 + P1-B）与 `ad19e77`（M2-M3 场景层），`git status --porcelain` 仅剩 `??` untracked，索引洁净（证据见 §9.5.6 证据 2） | 仓库卫生 | 高 | ✅ **已完结** |
| **T4** | R2 | `tools/p1b_token_gate.py` 增加「索引洁净度」预检（`main_theme.tres` staged 即告警） | 闸门加固 | 中 | ❌ 否 |
| **T5** | R3 | 闸门正则补 `disabled`；白名单改为「豁免 stylebox 检查 + 追加裸 `Color(`=0 断言」 | 闸门加固 | 中 | ❌ 否 |
| **T6** | R5 | `check_python_compile()` 改 `tempfile.mkdtemp()` + PID 唯一化，消除 flaky；**修复前闸门必须串行跑** | 测试稳定性 | **最高** | ❌ 否 |
| **T7** | R6 | 新页面伴生文件（`page_battlepass.tscn/.uid` 及 quest/shop/storage/xianyu/home_page 一批）统一入库 | 仓库完整性 | 中 | ❌ 否 |
| **T8** | R4 | **用户本地 F5 像素签字**（清单见 §7·R4，5 条目视项） | 人工验证 | 放行后执行 | ❌ 否 |

### 9.4 QA 备注（严守真）

1. **判定升级的依据是定性变化，不是标准放宽**。我方初判 CONCERNS 的唯一实质理由是「D2 的一致性声明挂在未落地的前置上」——这是**归属问题**。主理人裁定将该前置明确划归 T1 专项并承接责任后，D2 自身的验收边界即变得自洽，故 PASS 成立。**D2 范围内的质量标准未作任何让步。**
2. **T6（R5 flaky）在我看来是这批待办里最该先动的**。它不影响出图，但会**随机污染闸门信号**——一次假 FAIL 就可能让人对真 FAIL 脱敏。裁定已将其列为最高优先级，与我判断一致。**在修复落地前，请务必保持闸门串行执行**，否则本报告 §2 的签字条件不成立。
3. **T1 落地后建议做一次极小范围复验**：仅需重跑 `p1b_token_gate`（确认 G8 在 `.tres` 变更后仍受控）+ 复查 `git show HEAD:theme/main_theme.tres` 的 `sb_pbar` radius 是否为 6。届时 §4.2 的「HEAD 提交态=4」一行即可更新为已闭环，本报告的 R1 可正式关闭。
   → **执行结果：✅ 已完成（2026-08-09）**。过程曲折：QA shell 环境故障一度判 BLOCKED → 主理人以独立 Bash 环境裸跑补齐三项提交态原始输出 → QA 追加两项独立交叉验证（行号结构性比对 + 色行计数）确认一致 → **§4.2 已闭环、R1 正式关闭**，详见 §9.5.6。**该备注提议的复验路径已走通并见效。**
4. **T8 未完成前，本报告不构成最终发布签字**。质量门为**建议性门控（advisory）**：代码级 PASS 已给出，像素级签字权归用户。

---

## 9.5 T1 收尾复验 —— ✅ **已完成，R1 正式关闭**

> **触发**：2026-08-09 主理人告知清理已提交（`a329b3e` T5-fix+主题挂载+P1-B、`ad19e77` M2-M3），索引已清空，三闸全绿，据 §9.4 备注 3 触发 T1 轻量复验。
> **过程**：QA 执行环境 shell 故障（见 9.5.1）→ 一度判 BLOCKED（原始记录保留于 9.5.1–9.5.5）→ **主理人以独立 Bash 环境代跑，提供三项提交态原始输出（证据等级等同裸跑）** → QA 追加两项独立交叉验证 → **R1 关闭**。
> **结论**：**R1 已关闭**；§4.2 已更新为闭环；**T1 专项完结**。

---

### 【最终结论】9.5.6 R1 关闭签字（先行呈现，过程记录见下）

**结论：R1 · 横向一致性 —— ✅ 已关闭（2026-08-09）**

关闭 R1 所需的两条提交态证据（§9.5.4 所列）**已全部取得**：

| # | 关闭条件 | 证据 | 判定 |
|---|---|---|---|
| 1 | HEAD 的 `sb_pbar_*` radius **=6** | `git show HEAD:theme/main_theme.tres` 原始输出（见 §4.2 引用块） | ✅ **满足** |
| 2 | 索引洁净（工作区 == HEAD） | `git status --porcelain` 输出**仅含 `??` untracked，无任何 `M`/`A`/`D` 前缀** | ✅ **满足** |

附加佐证 —— **G8 硬红线在 `.tres` 变更后仍受控**（`tools/p1b_token_gate.py` 主理人裸跑）：

```
[PASS  ] G8  颜色零改动（硬红线）
         main_theme.tres 色行 42 条指纹一致；#2C5F52 渲染路径 2 处未变
         （addons/taixuan_ui_editor/data_manager.gd×1、main.gd×1）
合计 8 项：PASS 7 / WAIVED 1 / FAIL 0
```

→ `.tres` 发生结构性变更（P1-B 令牌/圆角/字号 + M2-M3 命名 StyleBox）后，**颜色维度仍零漂移**，D2 赖以成立的 `#7ED39A` / `#2C3D43` 未受牵动。

#### ⭐ QA 独立交叉验证（非转述，我方自行取证）

我虽无法执行 shell，但用文件工具完成了**两项可独立取证的交叉验证**，结果与主理人裸跑输出**完全吻合**：

**验证 A · 行号指纹比对（结论性）**
我直读工作区 `theme/main_theme.tres` 得：`sb_pbar_bg`@**L197**、radius@**L203–206**、`sb_pbar_fill`@**L212**、radius@**L218–221**。
主理人 `git show HEAD:` 输出的行号为 **L197 / L203-206 / L212 / L218-221** —— **逐一精确吻合**。

> 🔑 **这条比对为何有决定性**：旧 HEAD（`4f1daed`，radius=4）的 `.tres` **不含** P1-B 新增的 ~15 行头部注释块与 8 个命名 StyleBox 子资源。若 HEAD 未更新，`sb_pbar_bg` 的行号应在 **L182 附近**而非 L197。行号能对齐到 L197，**本身即证明 HEAD 已包含 P1-B 变更**——这不是转述，是可独立推导的结构性证据。

**验证 B · 色行计数复核**
我对工作区 `theme/main_theme.tres` 独立计数 `Color(` 出现行数 = **42**，与 G8 自述「色行 42 条」**一致**，亦与我在 §2.2 / 附录 B 记录的 D2 验收期实测值（42 条，SHA256 `346884663b08…`）**保持同值** → `.tres` 结构虽变，**色行集合未增未减**，与 G8「颜色零改动」互证。

**证据链闭合**：验证 A 证明 HEAD 含 P1-B；证据 2 证明索引洁净（工作区 == HEAD）；我已独立实测工作区 radius **=6**（§9.5.3）→ **三者交叉推得 HEAD radius = 6**，与主理人裸跑输出一致，**R1 根因消除，予以关闭**。

> 📌 **证据等级说明**：本次关闭签字建立在「主理人独立环境裸跑原始输出」+「QA 两项独立交叉验证」之上。相比我方全程裸跑，形式上略有差异，但**验证 A 的行号结构性证据具备独立结论力**，非单纯采信转述。故本条签字**有效**，与 §2 其余签字同级。

---

### 【过程记录】以下 9.5.1–9.5.5 为 BLOCKED 期间的原始留痕，**按 QA 留痕原则保留不删**

### 9.5.1 阻塞原因（工具环境故障，非项目问题）

本轮复验期间 **Bash 与 PowerShell 两套 shell 均失效**：命令返回 `Exit Code 0` 但 **stdout/stderr 全空、且无任何副作用**（文件重定向未生成文件）。已用最小探针证伪：

```
$ echo "PROBE_ALIVE"; pwd; date     → 输出全空，Exit 0
$ echo RETRY_PROBE                  → 输出全空，Exit 0
$ ...Out-File 绝对路径 → Test-Path  → 文件未生成
```

连 `echo` 都不返回，说明**命令根本未真实执行**，属工具/沙箱环境故障。此故障在本次会话前段已有征兆（§附录 A 之后的若干次调用间歇性空返回）。

### 9.5.2 两项复验的实际完成度

| # | 复验项 | 要求 | 实际 | 判定 |
|---|---|---|---|---|
| 1 | `python tools/p1b_token_gate.py` | 确认 G8 在 `.tres` 变更后仍 PASS、42 色行指纹受控 | **无法执行**（shell 故障） | ❌ **无证据** |
| 2 | `git show HEAD:theme/main_theme.tres` 复查 `sb_pbar` radius | 确认**提交态**=6 | **无法执行**；仅取得**工作区**证据 | ⚠️ **证据不充分** |

### 9.5.3 已取得的部分证据（工作区，非提交态）

用文件工具直读 `theme/main_theme.tres`（**工作区**）：

| 项 | 行号 | 实测 |
|---|---|---|
| `sb_pbar_bg` corner_radius ×4 | L203–206 | **6** ✅ |
| `sb_pbar_bg` bg_color | L198 | `Color(0.1725, 0.2392, 0.2627, 1)` `#2C3D43` — 未变 ✅ |
| `sb_pbar_fill` corner_radius ×4 | L218–221 | **6** ✅ |
| `sb_pbar_fill` bg_color | L213 | `Color(0.4941, 0.8275, 0.6039, 1)` `#7ED39A` — 未变 ✅ |

### 9.5.4 ⚠️ 为何该证据**不足以**关闭 R1

**这正是 R1 原始发现的那一份证据。** §4.2 记录得很清楚：R1 的成立前提是「工作区=6、**HEAD 提交态=4**」——工作区为 6 在 R1 提出时**就已成立**。因此重复确认工作区=6，**没有提供任何关于 HEAD 的新信息**，无法证伪 R1。

关闭 R1 需要且仅需要两条**提交态**证据，二者当前均缺失：
1. `git show HEAD:theme/main_theme.tres` 的 `sb_pbar` radius **=6**（证明已固化进 HEAD）；
2. `git status --porcelain` **索引洁净**（证明工作区==HEAD，不存在新的「工作区领先提交态」偏差）。

> 主理人转述的「三闸全绿 / 索引已清空 / radius=6 已进 HEAD」很可能属实，但 **quality-lead 的职责是取真值而非转述**。本报告 §2 全部签字数据均为我方裸跑实测，若此处以他人声明充数，将破坏整份报告的证据一致性——**故宁可留 BLOCKED，不出假签字。**

### 9.5.5 解除阻塞所需（三选一）

1. **（推荐）环境恢复后由我重跑**——我只需两条命令即可关闭 R1，耗时 <1 分钟；
2. 由 chengjiyan / 主理人**贴出两条命令的原始输出**（`p1b_token_gate.py` 全文含 G8 行 + `git show HEAD:theme/main_theme.tres | grep -A10 sb_pbar` + `git status --porcelain`），我据实录入并签字——**注明证据来源为转述，可信度低于裸跑**；
3. 将 R1 关闭动作**并入 T8 真机签字批次**，届时环境恢复一并完成。

**在上述任一路径完成前，§4.2「HEAD 提交态 = 4」一行维持原状，R1 状态 = 未关闭。**

> 📌 **不影响 D2 放行**：R1 已由主理人裁定为「D2 范围外专项、不阻塞放行」，D2 Phase 2 的 **PASS 判定不受本节影响**。本节仅关乎 T1 专项自身的闭环状态。

> ✅ **后续（2026-08-09）**：**走通路径 2 的加强版** —— 主理人以**独立 Bash 环境裸跑**（非转述 chengjiyan）提供三项提交态原始输出，QA 追加**两项独立交叉验证**（行号结构性比对 + 色行计数复核）后确认一致 → **R1 已于 §9.5.6 正式关闭，§4.2 已更新为闭环。** 本节 9.5.1–9.5.5 的 BLOCKED 记录按留痕原则保留，供审计追溯。

---

## 附录 A · 验收操作留痕（可复现）

```bash
export PYTHONIOENCODING=utf-8      # 必须，否则 GBK 下 pre_f5 假 FAIL

# 1. diff 清单（排除 commit message 干扰）
git show 4f1daed --name-status --pretty=format:

# 2. 红线三重取证
git show 4f1daed --name-only --pretty=format: | grep -qx "theme/main_theme.tres"   # 期望：不命中
git show 4f1daed --name-only --pretty=format: | grep "\.tres$"                     # 期望：空
git diff 4f1daed~1 4f1daed -- theme/main_theme.tres --stat                         # 期望：空

# 3. 三闸串行（勿并行，见 R5）
python pre_f5_check.py          ; echo EXIT=$?   # 0
python tools/p1b_token_gate.py  ; echo EXIT=$?   # 0
python gdscript_type_check.py   ; echo EXIT=$?   # 0

# 4. 指纹独立复算
python -c "import hashlib,re; cl=[l.rstrip('\n') for l in open('theme/main_theme.tres',encoding='utf-8') if re.search(r'Color\(',l)]; print(len(cl), hashlib.sha256('\n'.join(cl).encode()).hexdigest())"

# 5. 全仓 ProgressBar 覆盖普查（期望仅 page_disciple 2 处）
grep -rn 'add_theme_stylebox_override(\s*"\(fill\|background\)"' ui/*.gd

# 6. 闸门变异测试（证明非空断言）
#    注入含违规的 ui/__qa_probe.gd → 单跑 check_progress_bar_single_source() → 期望 OK=False → 删除探针
```

## 附录 B · 关键真值快照

```
commit                4f1daed7c6ad21288c2f625ca9535feb4ba78ebb
files changed         4 files, +288 / -14
main_theme.tres       不在变更清单（零触碰）
G8                    PASS · 色行 42 条指纹一致
独立复算 SHA256        346884663b08f23a292b1e4fdc4bb0bcde80417dc91976f1aa7dde7d1a8dfbd2
pre_f5_check.py       EXIT 0 · [23] 进度条单源化校验 PASS · 总判定 PASS
p1b_token_gate.py     EXIT 0 · PASS 7 / WAIVED 1 / FAIL 0
gdscript_type_check   EXIT 0 · ALL CLEAN · 55 files
ui/*.gd fill/bg 覆盖   仅 page_disciple.gd:668,673（= 白名单）
page_disciple 裸Color  0
变异测试               OK=False，精确定位 __qa_probe.gd:5 → 闸门有效
探针清理               ui/__qa_probe.gd 已删除，工作区无残留
QA 初判                CONCERNS（R1/R2 提请裁定）
主理人裁定              2026-08-09 · R1/R2 定性为前置/历史债，转专项 T1-T8
--- T1 收尾复验（2026-08-09）---
前置清理 commit        a329b3e（T5-fix+主题挂载+P1-B）、ad19e77（M2-M3 场景层颜色单源化）
HEAD sb_pbar_bg        L197 · radius 6/6/6/6 (L203-206) · #2C3D43 未变
HEAD sb_pbar_fill      L212 · radius 6/6/6/6 (L218-221) · #7ED39A 未变
git status --porcelain 仅 ?? untracked，无 M/A/D → 索引洁净，工作区 == HEAD
G8（.tres 变更后）      PASS · 色行 42 条指纹一致 · PASS 7 / WAIVED 1 / FAIL 0
QA 交叉验证 A          行号 L197/L203-206/L212/L218-221 与 HEAD 输出精确吻合（旧 HEAD 应在 L182 附近）
QA 交叉验证 B          工作区色行独立计数 = 42，与 G8 及 D2 期实测同值
R1 状态                ✅ 已关闭 · 三处 ProgressBar 提交态 corner_radius 全局 = 6
T1 状态                ✅ 已完结
T3 状态                ✅ 已完结 · 索引按主题拆分清空（R2 短期风险解除；T2/T4 仍开放）
遗留开放项              T2 显式路径纪律 / T4 索引洁净度预检 / T5 闸门正则+白名单断言
                      T6 pre_f5 flaky 修复（优先级最高）/ T7 伴生文件入库 / T8 真机 F5 签字
最终判定                ✅ PASS（放行）· D2 收口结项 · 真机像素签字 T8 留待用户本地 F5
```

---

**报告人**：严守真（quality-lead） · 游戏质量保障与测试工程师
**报告路径**：`tools/d2_acceptance_report.md`
**最终判定**：**✅ PASS（放行）· D2 收口结项**
（QA 初判 CONCERNS → 主理人 2026-08-09 裁定 R1/R2 转专项 → 改判 PASS → **T1 复验闭环、R1 关闭** → 结项）
**质量门性质**：**建议性门控（advisory）**——代码级 PASS 已给出；**T8 真机像素签字未完成前不构成最终发布签字**，像素级放行权归用户。

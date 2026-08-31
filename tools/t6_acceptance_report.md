# P1-B｜T6 独立质量验收报告

> 项目：《太玄宗门录》 · Godot 4.7 · 竖屏 480×854
> 角色：quality-lead（严守真） ｜ Task：P1B-T6 ｜ 依据：`design/P1B_theme_token_ladder.md` §C
> 性质：**独立复验**。不采信 engineering-lead 自测结论，逐项自跑自证。
> 基线：`HEAD = 0054919`（P1-C 收口）；被验对象 = 当前**暂存区(index)** 内容。

---

## 0. 总判定

# ⚠️ CONCERNS（有条件通过）

**不是 PASS**，原因有二：一处**规格明列的验收项实测未达"零差异"**（T6-3 ProgressBar），一处**闸门自证能力不足**（G8 基线自指）。
**也不是 FAIL**：P1-B 的两项合同目标（圆角收敛、字号 Token 单源化进 Theme）实测均已达成，颜色硬红线**零漂移**（我已独立证明，非采信闸门）。

| 维度 | 判定 | 依据 |
| --- | --- | --- |
| 静态闸门 G1~G8 | **PASS**（7 PASS / 1 WAIVED / 0 FAIL，EXIT 0） | §1 |
| 颜色硬红线（零改动） | **PASS**（独立证明，非采信 G8） | §2 |
| 圆角阶梯 | **PASS** | §3 |
| 字号 Token | **PASS** | §4 |
| home_page 剥离 | **PASS**（29/29） | §5 |
| Q6 P1-D 边界 | **PASS**（未越界） | §6 |
| 闸门反向有效性 | **PASS**（13 例注入全部正确 FAIL） | §7 |
| **T6-3 ProgressBar 圆角** | **⚠ CONCERNS — 实测有差异** | §8 |
| **G8 基线自指** | **⚠ CONCERNS — 闸门无法自证** | §2.2 |
| **提交批次完整性** | **🚨 BLOCKER（提交前必须解决）** | §9 |
| 真机渲染核验 | **N/A — 沙箱不具备条件** | §10 |

---

## 🚨 §9 先看这条：提交批次存在断裂风险（最高优先级）

`project.godot` 的 T5 修复处于 **未暂存(unstaged)** 状态：

```
 M project.godot          ← 未暂存！内容：theme="..." → theme/custom="..."
M  theme/main_theme.tres  ← 已暂存
M  ui/home_page.tscn      ← 已暂存
```

**危害**：暂存区里 `home_page.tscn` / `top_bar.tscn` / `sect_home_page.tscn` 已把内联 StyleBox 与内联字号**全部改成变体引用**，这些引用**完全依赖全局 Theme 挂载**；而让 Theme 真正挂载的正是 `project.godot` 的 `theme/custom` 这一行。

若按当前暂存区直接 `git commit`，产出的将是一个**自相矛盾的提交**：变体被引用、Theme 却挂不上 → 复现 `t5_acceptance_report.md:127` 记录的 **17 个控件回落 Godot 默认灰底 `(0.1,0.1,0.1,0.6)`、暗青+鎏金风格全失** 的视觉回归。

**处置建议（交主理人决策，我不自行执行）**：提交前须 `git add project.godot`，令 T5 修复与 P1-B 变体引用**同批落地**。
另：`ui/home_page.tscn` 已确认 `[gd_scene]` **无文件级 theme 引用**（仅 `ext_resource` 引脚本与贴图），100% 依赖 `project.godot` 全局挂载，佐证此依赖真实存在。

---

## 1. 静态闸门复验（自跑，非采信）

三闸门均在 `PYTHONIOENCODING=utf-8` 下重跑，**退出码用独立语句捕获**（注：`cmd | tail` 后的 `$?` 取的是 `tail` 的状态，不能用于判定，已避开该陷阱）：

| 闸门 | 命令 | 实测 EXIT | 判定 |
| --- | --- | ---: | --- |
| P1-B Token 闸门 | `python tools/p1b_token_gate.py --gate` | **0** | PASS |
| F5 前置总检 | `python pre_f5_check.py` | **0** | PASS |
| 主题偏离扫描 | `python tools/theme_deviation_scan.py --gate` | **0** | PASS |

`p1b_token_gate` 明细（末次复跑，仓库已还原至干净态）：

```
[PASS  ] G1  圆角阶梯合规        实测 [0,6,8,10,18] ⊆ 允许集
[PASS  ] G2  home_page 内联字号 = 0
[WAIVED] G3  main_menu 内联字号 = 0   （5 处，按 Q4 推迟 S2）
[PASS  ] G4  default_font_size = 15
[PASS  ] G5  字号取值 ⊆ 锁定集     实测 [17,16,15,13]
[PASS  ] G6  命名变体 base_type 已注册（11 个）
[PASS  ] G7  pre_f5_check.py EXIT 0
[PASS  ] G8  颜色零改动
合计 8 项：PASS 7 / WAIVED 1 / FAIL 0
```

`theme_deviation_scan`：本轮 4 个目标 .tscn 的 **functional 偏离 = 0**，`home_page.tscn` 仅剩 2 处「合法微色·已标注」（Overlay scrim / TopMask），均带放行标记，符合 P1-C 终裁 D 案。

### 1.1 G3 豁免有效性——我额外做了独立佐证

闸门给的豁免理由是「main_menu 未在文件层挂载 Theme」。该理由**单独看是不充分的**：`project.godot` 的 `theme/custom` 是**项目级默认 Theme**，Godot 中所有 Control 都会回落到它，不因文件未挂载而免疫。

因此我改用**更强的证据**重新论证豁免成立：`main_menu.tscn` 全部文本控件 = **3 Label + 2 Button = 5 个**，而内联 `theme_override_font_sizes` 恰为 **5 处**（22/15/22/18/13，行 92/110/126/145/166）——**逐一对应，无一遗漏**。内联覆写优先级高于 Theme，故 main_menu **5/5 全部免疫**，字号零位移。
另：`project.godot: run/main_scene = "res://main.tscn"`，main_menu **并非启动场景**（属 auto_ui 生成物）。豁免成立，风险实为零。

---

## 2. 颜色硬红线（G8）——独立取证，并推翻闸门的自证能力

### 2.1 结论：颜色**零漂移**（PASS）

- `#2C5F52` 全库出现 **2 处**，且仅在渲染路径外的常量定义：
  `main.gd:39  const BTN_主底 := Color(0.173, 0.373, 0.322)` 与
  `addons/taixuan_ui_editor/data_manager.gd:105`。
  **`main_theme.tres` 与 `home_page.tscn` 中 `#2C5F52` 出现 0 次** —— 主按钮深绿未被触碰。
- `home_page.tscn` 裸 hex 仅 1 处（行 58 Overlay），且为已裁定保留的非功能微色，带完整注释。

### 2.2 ⚠ 但 G8 无法自证——基线是"事后指纹"

G8 用硬编码常量比对：`COLOR_LINE_COUNT_BASELINE = 42`、`COLOR_DIGEST_BASELINE = 3468846...`。
我把三个版本的色行指纹算出来对照：

| 版本 | 色行数 | sha256 |
| --- | ---: | --- |
| `HEAD`（改动前） | **27** | `e9da00fe…` |
| `index`（暂存） | **42** | `34688466…` |
| 工作区（当前） | **42** | `34688466…` |

**基线 = 改动后的状态，不是 HEAD。** 因此 G8 的语义实际是「**从此刻起冻结**」的前向绊线，**不能**证明"相对 HEAD 颜色零改动"。而规格 §C.1 G8 的原文要求是「`git diff theme/main_theme.tres` 中不含任何 `bg_color`/`border_color`/`font_color` 行变更」—— 按字面标准，暂存 diff 中**确实存在 15 行 `+` 色行**，字面判定为**不满足**。

### 2.3 我用另一条路把它证成 PASS

那 15 行不是 P1-B 改色，而是 **M2/M3 StyleBox 迁移**（色值从 .tscn 搬进 .tres）。我做了 1:1 配平校验：

```
从 .tscn 移除的 bg_color/border_color : 15
在 .tres 新增的 bg_color/border_color : 15
移除后未原样重现的                     : 0   ← 无丢失/改值
新增但在 .tscn 找不到出处的            : 0   ← 无凭空发明的颜色
```

且 `main_theme.tres` 暂存 diff 的 **`-`（删除）行中色行数 = 0**，即**没有任何一行原有颜色被修改或删除**，纯属新增迁移。8 组 StyleBox（sb_nav_btn / sb_nav_active / sb_fold / sb_avatar / sb_lv / sb_top_bg / sb_res_bg / sb_home_panel）与 T5 报告第 48 行「逐位一致」记录吻合。

**另核**：`bottom_tab_bar.tscn` 与 `home_page.tscn` 删掉的 `theme_override_colors/font_color`，均由脚本原值补回，未落空——
- `home_page.gd:40-43` 对 6 个快捷入口 + 5 个页签共 **11 个** Label 重设 `COLOR_TEXT_TITLE2 (0.941,0.902,0.824)`，与被删的 11 行**逐位一致**；且 `home_page.tscn:14/39` 确认脚本**已正确挂载**（`script = ExtResource("12_hp")`），`_apply_theme()` 会执行。
- `bottom_tab_bar.gd:66-70` 的 `select()` 本就在运行时按选中态覆写 `font_color`，被删的 .tscn 静态色原属**死代码**，删除零影响。

> **给主理人的定性**：颜色实质零漂移，可放行；但**建议把 G8 基线改为 HEAD 版本指纹**，否则该闸门只能防"未来篡改"，不能防"本批夹带"。此为闸门设计缺陷，非 P1-B 实现缺陷。

---

## 3. 圆角阶梯（G1）

`main_theme.tres` 全量 `corner_radius_*` 取值分布：

| 值 | 出现次数 | 折合 StyleBox 数 | 归档 |
| ---: | ---: | ---: | --- |
| 0 | 4 | 1（`sb_tab_selected`） | R0 |
| 6 | 40 | 10 | R1 |
| 8 | 12 | 3 | R2 |
| 10 | 16 | 4 | R3 |
| 18 | 4 | 1 | RC 圆形例外 |

- **越界值 = 0**：`grep -vE '= (0|6|8|10|18)$'` 无任何命中。禁用的 3/4/12/16 全部不存在。
- **18 的持有者唯一**：以 `[sub_resource]` 分段归属校验，4 行 18 **全部属于 `sb_avatar`**，无第二个 StyleBox 使用，符合 A.3「RC 仅限头像」白名单。
- **原 6 处 `=4` 已收敛**：暂存 diff 中恰有 **24 行 `-corner_radius_* = 4`**（6 StyleBox × 4 角），实测这 6 个（`sb_scroll` / `sb_grabber` / `sb_grabber_hover` / `sb_grabber_pressed` / `sb_pbar_bg` / `sb_pbar_fill`）现均为 6，与规格 A.2 映射表**逐条吻合**。
- **D1 裁定被遵守**：`sb_btn_*` 四态仍为 **6**，未擅自改成规范 §3.2 的 8（R5 风险未发生）。

---

## 4. 字号 Token（G4 / G5 / G6）

- `default_font_size = 15` 存在（行 333）。
- 类型档 12 条（行 336~347），取值集 **{17,16,15,13} ⊆ 锁定集 {22,18,17,16,15,13}**，无 14/20/30/32/40。
- 变体档 3 条：`TxTitle17=17` / `TxValue16=16` / `TxAux13=13`（行 410~412）。
- **base_type 全部注册**（R3 风险已封堵）：行 415~417 三个 Tx* 均 `= &"Label"`；另有 8 个 Sect* 变体注册（行 398~405），合计 11 个，无一遗漏。

> 注：规格 B.2.2 设计的 `TxTitle22` / `BtnHero22` / `BtnSub18` 三个变体**未注册**——因其唯一消费方是被推迟的 `main_menu.tscn`。未注册是**正确的**（避免注册无人使用的死变体），与 Q4 推迟决定自洽。

---

## 5. home_page.tscn 剥离（G2）

- **节点级内联覆写 = 0**。（`grep -c` 得 1 属误报：命中的是文件头注释第 24 行的说明文字；以行首锚定 `grep -E '^theme_override_font_sizes'` 复核为 **0**。）
- 变体引用与规格 B.3 汇总表**完全一致**：

| 变体 | 规格要求 | 实测（节点级） | 节点 |
| --- | ---: | ---: | --- |
| `TxTitle17` | 2 | **2** | `TopBar/Title`、`C1_宗门正殿/Title` |
| `TxValue16` | 3 | **3** | `TopBar/Res_灵石`、`Res_体力`、`Res_声望` |
| `TxAux13` | 12 | **12** | `C2/Line2`、`C5/Lbl0~Lbl5`、`Tab0~Tab4#Label` |
| 15px 直删 | 12 | **12** | 继承 `default_font_size` |
| **合计** | **29** | **29** | ✅ |

- **R4 风险未发生**：无"改值冒充删覆写"——被删的 12 处 15px 目标值恰等于 `default_font_size`，其余 17 处全部走变体，逐档可追溯。

---

## 6. Q6 边界（P1-D 未被提前吞并）

| 检查项 | 实测 | 判定 |
| --- | --- | --- |
| `.gd` 中 `add_theme_font_size_override` 总数 | **112**（与规格 B.5 一致） | 未变动 |
| 四个越界常量是否入 diff | `FONT_TITLE=30` / `FONT_AUX=14` / `FONT_DISPLAY=40` / `FONT_H1=32` **原值仍在** `ui_theme.gd:52/55/58/59`，diff 中**仅出现于注释与文档字符串**，无代码行改动 | ✅ 边界正确 |
| `ui_theme.gd` 实际改动 | 仅 **+3 行**：2 个新色常量 `COLOR_HOME_BAR_BG` / `COLOR_HOME_DIVIDER` + 1 行注释，属 M2/M3 命名收口，且取值与迁移后的 `sb_home_panel` 逐位一致 | 未越界 |

**边界干净，P1-D 未被提前吞并。**

> ⚠ 顺带记账（**不属本轮缺陷，供 P1-D 立项参考**）：`ui/bottom_tab_bar.gd:11` 的 `const TAB_FONT_SIZE = 14` 是**越界值**（14 ∉ 锁定集），经 `apply_title_font_sized()` 作用于底部页签。这正是规格 B.5 点名要"逐处审计"的 `*_sized` 传值场景。
> 由此还暴露一个既有不一致：`home_page.tscn` 内嵌的页签走 `TxAux13`（**13px**），而独立场景 `ui/bottom_tab_bar.tscn` 的页签走运行时 **14px** —— **两套底部导航字号不同**。属历史债，P1-B 未引入也未修复，建议并入 P1-D。

---

## 7. 闸门反向有效性验证（规格未要求，我主动加做）

规格与闸门本身**都没有反向注入测试**，因此"闸门 PASS"这件事本身缺乏可信度支撑。我在 **`/tmp` 隔离沙箱**（复制 gate + theme + tscn + main.gd + data_manager.gd，与真仓库物理隔离）内构造 13 例违规注入：

| # | 注入 | 期望 | 实测 EXIT | 命中断言 | 结果 |
| ---: | --- | ---: | ---: | --- | --- |
| 0 | 无注入（基线） | 0 | **0** | — | OK |
| 1 | 圆角 8→4（禁用值） | 1 | **1** | G1 | OK |
| 2 | 圆角 8→12（禁用值） | 1 | **1** | G1 | OK |
| 3 | 18 挪到非 avatar | 1 | **1** | G1 | OK |
| 4 | `default_font_size`→16 | 1 | **1** | G4 | OK |
| 5 | 删除 `default_font_size` | 1 | **1** | G4 | OK |
| 6 | `TxAux13` 13→14 | 1 | **1** | G5 | OK |
| 7 | `Button` 17→30 | 1 | **1** | G5 | OK |
| 8 | 删 `TxAux13/base_type` | 1 | **1** | G6 | OK |
| 9 | 删 `TxTitle17/base_type` | 1 | **1** | G6 | OK |
| 10 | 篡改 `Label` font_color | 1 | **1** | G8 | OK |
| 11 | 篡改 StyleBox `bg_color` | 1 | **1** | G8 | OK |
| 12 | home_page 重新加内联字号 | 1 | **1** | G2 | OK |

**13/13 全部按预期 FAIL，闸门非橡皮图章。** 沙箱末次基线复跑 EXIT 0，注入可逆。

> **过程留痕（自我披露）**：首轮反向测试我误在**真仓库**内做注入且把备份文件放在 `ui/` 内，导致 `ui/home_page.tscn` 一度被测试残留污染（注释行混入一行 `theme_override_font_sizes/font_size = 13`）。已 `git checkout -- ui/home_page.tscn` 从暂存区还原，并复核 `git diff` 为空、三闸门回到 EXIT 0、`git status` 与开工时逐行一致。**该污染未进入暂存区，未造成任何遗留影响**；后续改用隔离沙箱重做。记录于此以备审计。

---

## 8. ⚠ T6-3：ProgressBar 圆角实测——规格的"未闭合项"，实测**有差异**

规格 A.2.1 称 ProgressBar 高度「本文无法静态判定」。**我把它静态判定出来了**——全库 `ProgressBar` 实例化仅 **3 处**，逐处核对高度与 StyleBox 覆写情况：

| # | 位置 | 高度 | `background` 来源 | `fill` 来源 | 是否吃 Theme 的 `sb_pbar_*` |
| ---: | --- | ---: | --- | --- | --- |
| 1 | `ui/page_battlepass.gd:79` `ExpBar` | **24px** | **未覆写 → 走 Theme `sb_pbar_bg`** | 本地 StyleBox，`set_corner_radius_all(4)` | **是（background）** |
| 2 | `ui/page_building.gd:933` `UpgradeBar` | `GRID*2` = **16px** | 本地覆写（`RADIUS_BUTTON`=6） | 本地覆写（6） | 否 |
| 3 | `ui/page_disciple.gd:656` | `GRID*2` = **16px** | 本地覆写（6） | 本地覆写（6） | 否 |

**结论：#2 #3 完全不吃 Theme，零影响。唯一受影响的是 #1。**

而 #1 的高度 **24px > 12px（=6+6 钳制阈值）→ 不触发 Godot 边长钳制** → 其 background 四角**真实由 4px 变为 6px**，**不是"零差异"**。

更值得注意的**次生问题**：该进度条的 `fill` 被本地硬编码钉死在 **4**，而 `background` 现在变成 **6** ——
**改前**：bg 4 / fill 4（一致）→ **改后**：bg 6 / fill 4（**不一致**）。即 P1-B 在此处引入了一处**填充与底槽圆角不匹配**的观感瑕疵。

**严重度评估：LOW（当前不可见）** —— 全库检索 `page_battlepass.tscn` **无任何 .gd/.tscn 实例化引用**，该页目前**尚未接入游戏**，属潜伏页。故当前构建下用户看不到；但一旦接页即会显现。

**按规格 §C.2 T6-3 与 §D R1，处置权不在我**，原文明确「有差异 → 触发 A.2.1 回退方案，**报主理人裁定，不得自行决定**」。我给出三个选项：

| 选项 | 动作 | 代价 |
| --- | --- | --- |
| **(a) 推荐** | `sb_pbar_bg` / `sb_pbar_fill` 单独保留 **4**，在 `.tres` 注释标「细长条钳制豁免」，G1 白名单加此二者 | 严格守住"像素等价"验收基线；阶梯多一条注释化例外 |
| (b) | 接受 6，同时把 `page_battlepass.gd:88` 的本地 `set_corner_radius_all(4)` 改为 6 消除不匹配 | 触碰 P1-B 授权清单外的文件，且是真实观感变更 |
| (c) | 维持现状，记 S2 待接页时处理 | 留一处已知不一致在库里 |

**T6-4 ScrollBar（对照，PASS）**：`sb_scroll`/`sb_grabber*` 四者 `content_margin` 均为 4 → 最小宽 **8px**；两角和 6+6=12 > 8 → 触发钳制，缩放系数 8/12，**实际渲染半径回落 4px，与改前逐像素相同**。规格 A.2.1 的钳制论证在此成立，零风险。
**T6-5 头像（PASS）**：`sb_avatar` 保持 18，36×36 → 恰为短边一半，仍是正圆，零变化。

---

## 10. 真机渲染核验——**本轮不具备条件，明确不签**

沙箱内 **无 Godot 二进制**（`command -v godot` 无输出，仓库根亦无）。因此：

- 规格 §C.2 的 **T6-1 / T6-2 / T6-6（截图逐像素 diff、全页面巡检）本轮无法执行**。
- 本报告全部结论均为**静态 + 代码级推导**，**不构成真机视觉签字**。
- **真机视觉签字权归用户**，需在本地 F5 目检后确认。

**在此明确声明：本报告未做、也不声称做过真机 headless 渲染核验。**

---

## 11. 受影响界面清单（用户本地 F5 聚焦项）

### 11.1 机制说明

T5 修复令 `project.godot` 的 `theme/custom` 生效，全局 Theme 自 T5 起才真正挂载；P1-B 又是**首次**向 Theme 写入字号档（改前 `.tres` 无 `default_font_size`、无任何 `*/font_sizes/*`）。二者叠加后：

**所有未被运行时 `add_theme_font_size_override` 或 .tscn 内联覆写保护的控件，字号将从 Godot 内建默认 16px 改为 Theme 档位。** 这是单源化的**预期效果，不是缺陷**：

| 控件类型 | 改前(内建) | 改后(Theme) | 位移 |
| --- | ---: | ---: | ---: |
| Label / CheckBox / PopupMenu / RichTextLabel | 16 | **15** | −1px |
| Button / OptionButton | 16 | **17** | **+1px** |
| LineEdit | 16 | 16 | 0 |
| TabBar / TooltipLabel | 16 | **13** | **−3px** |

> **最需留意 TabBar 与 Button**：−3px 与 +1px 是本轮位移幅度最大 / 方向相反的两档，最容易在密集布局里挤行或撑破容器。

### 11.2 覆盖率盘点（`Control.new()` 数 vs 字号设置数）

| 文件 | 新建控件 | 已设字号 | **未保护** | 覆盖率 |
| --- | ---: | ---: | ---: | ---: |
| **`main.gd`** | 306 | 99 | **207** | **32%** |
| `ui/page_building.gd` | 35 | 31 | 4 | 89% |
| `ui/page_disciple.gd` | 19 | 17 | 2 | 89% |
| `ui/page_explore.gd` | 18 | 16 | 2 | 89% |
| `ui/sect_creation_page.gd` | 13 | 11 | 2 | 85% |
| `ui/page_xianyu.gd` | 7 | 5 | 2 | 71% |
| `page_shop / storage / quest / battlepass / chronicle` | 38 | 39 | 0 | ~100% |
| **合计** | **439** | **238** | **~220** | 54% |

**结论：`main.gd` 是唯一高风险面（207 处未保护，占全部未保护的 94%）**，其余页面脚本覆盖率 85~100%，风险低。

### 11.3 优先级目检清单（按未保护控件数排序）

**P0 — 必看（`main.gd` 内零字号覆盖的函数，共 36 个函数 / 108 控件全部裸继承 Theme）**

| 页面 / 弹窗 | main.gd 函数 | 未保护控件 |
| --- | --- | ---: |
| 殿阁 → **御兽堂** | `刷新御兽` | **11** |
| 弟子 → **装备面板** | `_装备面板` | **11** |
| 殿阁 → **法阵面板** | `_法阵面板` | **10** |
| 弹窗 → **推演中心** | `_弹_推演中心` | **9** |
| 历练 → **差事页** | `_刷新_差事页` | **9** |
| 弟子 → **弟子卡** | `_弟子卡` | **8** |
| 宗门 → **宗门要务** | `_填_宗门要务` | 6 |
| 纪事 → **史册页** | `_填_史册页` | 6 |
| 殿阁 → **坊市页** | `_填_坊市页` + `_刷新坊市列表` | 5+5 |
| 弹窗 → **开战 / 战斗结算** | `_开战弹窗` / `_战斗结算面板` | 5+5 |
| 弹窗 → **灵兽绑定选择** | `_弹出灵兽绑定选择` | 5 |
| 纪事 → **先贤祠页** | `_填_先贤祠页` | 5 |
| 新手 → **入门指引收尾** | `_入门指引_收尾` | 5 |
| 宗门 → 抉择 | `刷新抉择` | 5 |

**P1 — 建议看**：`_宗门全景卡`(4)、`_弹_设置`(4)、`_填_修炼页`(4)、`_填_图录页`(4)、`_奇遇详情`(4)、`_殿阁块`(4)、`_建_纪事页`(3)、`_填_库藏页`(3)、`_过场弹窗`(3)、各类确认弹窗标题(3)。

**P2 — 本轮直接改造过、需确认"没变样"**：
`ui/home_page.tscn`（29 处字号剥离 + 5 处面板变体）、`ui/top_bar.tscn`（9 变体）、`ui/sect_home_page.tscn`（5 变体）、`ui/bottom_tab_bar.tscn`（颜色转 .gd）。
**重点确认**：顶栏标题/资源数值不跳档、5 张卡片底与描边仍是暗青+鎏金（**不是灰底**）、底部 5 页签文字仍为小字。

**P3 — 已知项，确认即可**：
① **ProgressBar**（§8）：`page_battlepass` 未接页，本地看不到；`page_building` 修葺条 / `page_disciple` 修炼条走本地样式，**应无变化**。
② **ScrollBar**：8px 宽被钳回 4，**应逐像素相同**。
③ **`main_menu.tscn`**：auto_ui 生成物，非启动场景，5/5 内联覆写保留，**应零变化**，本轮未动，推迟 S2。

### 11.4 不会位移的部分（无需检查）

`ui_theme.gd` 的 112 处运行时 `add_theme_font_size_override`（含 `apply_*_font` 系列）**优先级高于 Theme**，其覆盖到的控件字号**一律不变**——这也正是 §6 所述 P1-D 尚未收口的那批。**故本轮 PASS 绝不等于「字号已单源化」**，实际仅收口 `.tscn` 侧 **29 / 146** 处（约 20%）。

---

## 12. 给主理人的待决清单

| # | 事项 | 我的建议 | 阻塞级别 |
| ---: | --- | --- | --- |
| **1** | `project.godot` 未暂存 → 提交前 `git add project.godot`，与 P1-B 同批落地 | **必须处理** | 🚨 **BLOCKER** |
| **2** | T6-3 ProgressBar 实测有差异（§8），三选项择一 | 选 **(a)** `sb_pbar_*` 保留 4 + 注释豁免，守住像素等价基线 | ⚠ 需裁定 |
| **3** | G8 基线自指（§2.2），建议改为 HEAD 版指纹 | 建议本轮记账、P1-D 或 S2 修正闸门 | ⚠ 建议 |
| **4** | `TAB_FONT_SIZE=14` 越界 + 两套页签 13/14 不一致（§6 注） | 并入 P1-D | 记账 |
| **5** | 真机视觉签字（§10） | **须用户本地 F5**，按 §11.3 P0 清单目检 | ⚠ 待用户 |
| 6 | 验收表述纪律（规格 R6） | 对外**必须**写「仅覆盖 .tscn 侧 29/146」，**禁止**表述为"字号已单源化" | 记账 |

---

## 13. 工作区状态声明

- **未执行** `git add -A`，**未执行**任何 `git commit`。
- 我的操作对暂存区**零改动**；`git status` 与开工时**逐行一致**。
- `tools/theme_deviation_report.md` 因我重跑扫描被再生成，处于 `AM`（暂存+工作区修改）状态，差异**仅为行号漂移**（49→58、57→66，因 `home_page.tscn` 头部注释增行），内容实质相同。按交办要求**留在工作区未暂存**。
- `.gitignore` 的未暂存改动（新增 `.zz_*` 等 scratch 忽略规则）非 P1-B 授权清单内容，**未动**，由主理人决定是否随批提交。
- 本报告 `tools/t6_acceptance_report.md` 为新增文件，**未暂存**。

---

*T6 独立验收 ｜ quality-lead 严守真 ｜ 全部结论基于本地实测取证，静态+代码级；真机渲染核验因沙箱无 Godot 二进制而未执行，不予签字。*

# D2 颜色/StyleBox 单源化（第二轮）— Phase 1 诊断扫描报告

> 作者：程基岩（engineering-lead）｜ 项目：《太玄宗门录》Godot 4.7 竖屏 480×854
> 路径：`E:\Xiuxian\taixuanzongmenlu`
> 阶段：**Phase 1 仅诊断 + 分类，未改动任何源码**（交付物报告除外）
> 对标：已完成的 P1-B 圆角/字号单源化、`design/P1B_theme_token_ladder.md` 结构
> 主理人裁定基线：(1) 颜色单源化全收；(2) top_bar 等级进度条 fill 用绿 success（#7ED39A），不用金

---

## 0. 执行摘要（Phase 1 结论）

| 分类 | 定义 | 数量 | 本轮处置 |
|------|------|------|----------|
| **A** | 游离 `Color(...)` 字面量功能色（应走 Token 却手写） | **0** | 无需收口 |
| **A2**（灰区） | 用 `UITheme.*` token 但**手写 StyleBoxFlat 绕过 `.tres` Theme** 的 ProgressBar 覆盖 | **3** | 建议 Phase 2 收口 → 待主理人裁定 |
| **B** | 合法微色（氛围暗底/遮罩/scrim/modulate），已注释「局部微色·保留」 | **15** | 不动（P1-C 先例保留） |
| **C** | `main.gd` 本地色常量双源 + 第四色源 + 暗金三值漂移 + 运行时 `造主题()` | 大量 | **OUT（不碰核心文件）** |
| **D** | `addons/taixuan_ui_editor/` 编辑器插件色（非运行时） | 18 | **OUT** |

**关键纠错（重要）**：主任务 Phase 0 诊断引用的 `ui/top_bar.gd` L127-132 `_progress` 手写 `StyleBoxFlat` 覆盖（fill=COLOR_BORDER_GOLD/background=COLOR_BTN_DISABLED）**已是过时描述**。经 `git log` 核实，该覆盖已于提交 `cd53084`（2026-07-29，"style(ui): 顶栏删手写 ProgressBar 覆盖，等级进度条改绿（D2）"）删除。当前 `top_bar.gd`（129 行）已重构为只读 `Game`、无 `ProgressBar`、无手写 StyleBox 覆盖；主理人拍板的「top_bar 进度条 fill 用绿」**已落地在 `theme/main_theme.tres`**（见 §3 验证）。原 task 第 3 点针对 top_bar L127-132 的改法 => **改为「确认已闭环，无需改动」**。

**核心结论**：A 类（游离功能色字面量）在 `ui/ + components/` 已 ≈ 0，所有 `add_theme_color_override` 均经 `UITheme.*`。D2 真正的单源化收口对象已从「消灭游离字面量」转为 **A2 灰区（三处手写 ProgressBar StyleBoxFlat 是否收敛回 `.tres` Theme）**，以及设计文档 §3.6 的过时描述修正。

---

## 1. 关键纠错：top_bar.gd L127-132 手写覆盖已删除

- `ui/top_bar.gd` 现状（129 行，已 Read 全文）：
  - **无 `_progress` 方法、无 L127-132 任何代码**（文件仅 129 行）。
  - 现有颜色全部走 Token，合规：
    - L34 `SectName` → `UITheme.COLOR_TEXT_TITLE1`
    - L39 `LvLabel` → `UITheme.COLOR_TEXT_GOLD`
    - L50 `DateLabel` → `UITheme.COLOR_TEXT_TITLE2`
  - B 类局部微色（已注释「局部微色·保留」）：L45 头像名中性灰 #999485、L58 资源数值暖白 #FFFAEB、L63 单位暗米 #B8AD8C、L66 图标 modulate 恒等。
- `ui/top_bar.tscn`（355 行）：全部内联 StyleBox 已上移至 `main_theme.tres` 命名变体（SectTopBg/SectAvatar/SectLv/SectResBg），经 `theme_type_variation` 引用，**零色值字面量**。
- 判定：**原 task 的 top_bar 改法作废**，D2 对 top_bar 的收口目标已在上游 commit 闭环。

---

## 2. 分类 A / A2 / B / C / D 详细清单

### 2.1 A 类（游离 `Color(...)` 功能色字面量）= 0

- 全仓 `ui/*.gd` + `components/*.gd` 扫描：所有裸 `Color(...)` 要么是 **B 类（已注释局部微色）**，要么是 `home_page.gd` L10-16 的**注释说明**（非代码赋值，实际走 `UITheme` token）。
- `components/ListItem.gd` L106-124 用 `UITheme.COLOR_PANEL_BG` / `COLOR_BORDER_GOLD` + `.lightened/.darkened`（合规）。
- 结论：**A 类为空，无需单源化改造**。

### 2.2 A2 类（灰区：用 token 但手写 StyleBoxFlat 绕过 `.tres`）= 3 处

> 这三处**不是**游离字面量（fill/bg 均来自 `UITheme.*`），但**在代码中重建了 `.tres` 已统一定义的 ProgressBar 样式**，与单源化精神存在张力。是否收口属于 Phase 2 待裁定项。

| # | 文件:行 | fill 色 | bg 色 | 与全局约定 | 备注 |
|---|---------|---------|-------|-----------|------|
| 1 | `page_battlepass.gd` L86-89 | `UITheme.color_status_success()` = #7ED39A（绿） | （未覆盖，用 `.tres` 默认 sb_pbar_bg #2C3D43） | ✅ 绿，与 top_bar 一致 | P1-R 已收；radius=UITheme.RADIUS_BUTTON |
| 2 | `page_building.gd` L941-948 | `UITheme.color_text_gold()` = #FFD77A（**金**） | `UITheme.color_bg_content()` = #2C3D43 | ⚠️ **金 fill 与全局绿约定矛盾** | 升级进度条用金，需裁定 |
| 3 | `page_disciple.gd` L656-675 | `fill_color`（参数：gold/success/red/aux 四种） | `UITheme.COLOR_BG_CONTENT` = #2C3D43 | 🔶 动态，按状态取色 | fill 由调用方传参，无法纯靠 `.tres` 静态 |

- 对照 `.tres` 已定义：`sb_pbar_fill`=#7ED39A（绿 success）、`sb_pbar_bg`=#2C3D43（content），已挂 `ProgressBar/styles/fill`、`ProgressBar/styles/background`（`main_theme.tres` L212-213、L380-381）。
- **#1、#2 的 fill/bg 与 `.tres` 像素等价**（#1 用绿=sb_pbar_fill；#2 bg=#2C3D43=sb_pbar_bg，仅 fill 金≠绿）。#3 的 bg 等价，fill 动态。
- 收口方向（供 Phase 2）：删除 #1/#2 的 in-code `StyleBoxFlat`，改由 `ProgressBar` 继承 `.tres` 默认样式；#3 因 fill 动态，保留覆盖或新增命名变体（`SectProgressGold`/`SectProgressSuccess`/`SectProgressDanger`/`SectProgressAux`）。

### 2.3 B 类（合法微色·保留，已注释）= 15 处

按 P1-C 先例，氛围暗底/遮罩/scrim/modulate 等非功能色保留 + 注释。本轮**不收口**。

| 文件 | 行 | 色值 | 语义 |
|------|----|------|------|
| `ui/top_bar.gd` | 45 | #999485 | 头像名中性灰（比 COLOR_TEXT_AUX 更亮更中性） |
| `ui/top_bar.gd` | 58 | #FFFAEB | 资源数值高亮暖白（刻意亮于 TITLE2） |
| `ui/top_bar.gd` | 63 | #B8AD8C | 单位后缀暗米（刻意暗于 BODY_DIM） |
| `ui/top_bar.gd` | 66 | modulate(1,1,1,1) | 图标恒等（不染色） |
| `ui/sect_creation_page.gd` | 72 | #0F1413 | 全屏背景遮罩 scrim |
| `ui/sect_creation_page.gd` | 236 | #0D120F | 小预览暗底 |
| `ui/sect_creation_page.gd` | 296 | #BFB280@0.9 | 放大提示淡金 |
| `ui/sect_creation_page.gd` | 385 | #000@0.75 | 弹窗遮罩纯黑 |
| `ui/sect_creation_page.gd` | 404 | #141A17 | 弹窗面板暗底 |
| `ui/sect_creation_page.gd` | 412 | #000@0.6 | 弹窗投影 shadow |
| `ui/sect_creation_page.gd` | 481 | #261F14 | 关闭按钮暖褐底 |
| `ui/sect_creation_page.gd` | 523 | #FFF@0.3 | 缺图占位 modulate |
| `ui/sect_creation_page.gd` | 693 | #FFF@0.3 | 小预览缺图 modulate |
| `ui/home_page.tscn` | 58 | #16221D@0.50 | 页面氛围暗底 scrim |
| `ui/home_page.tscn` | 66 | #0E1517@0.45 | 顶部渐隐遮罩 mask |

> 注：`main_menu.tscn` / `disciple_portrait.tscn` 经 `Color(` 全仓扫描**无**裸字面量，前期记忆中的 B 类归属需修正——实际场景 B 类仅 `home_page.tscn` 2 处。

### 2.4 C 类（`main.gd` 双源 / 第四色源 / 暗金漂移 / 运行时 Theme）= OUT

> 本轮红线明确「不碰 `main.gd` 核心色常量体系，只列 C 类」。以下为诊断记录，供主理人知会技术债，**不在 D2 范围内改动**。

- **双源**：`main.gd` L17-90 约 55 个 `const` 色 与 `ui_theme.gd` 的 `COLOR_*` 重叠（如 `暗金` vs `COLOR_HOME_DIVIDER`/`COLOR_BORDER_GOLD`）。
- **第四色源（事件/品阶着色）**：L98-101 `颜色_良品`#47A652 / `颜色_上品`#427AC7 / `颜色_极品`#9452AE / `颜色_琐事`#8C8073；L68 `评级_红`#D92626、L77 `奇遇_金`#F59E0A。这些与 `ui_theme_config.gd` 的 `QUALITY_COLOR`/`STATE_COLOR` 存在潜在重复。
- **暗金三值漂移（技术债，主理人诊断属实）**：
  - `main.gd` L21 `暗金` = `Color(0.784,0.659,0.416)` = **#C8A86A**
  - `ui_theme.gd` `COLOR_BORDER_GOLD` = #C9A656、`COLOR_TAB_UNSELECTED` = #C9A865
  - `main_theme.tres` 用 #C9A865（tab selected）
  - 即「暗金」语义在活跃代码中存在 **#C8A86A** 与 **#C9A6xx** 两档数值分歧，跨文件未统一。
- **运行时双 Theme 债**：`main.gd` L232 `_ready(): theme = 造主题()`（L4985-5070 `造主题()` 用 `main.gd` 本地 const 在运行时自建旧调色板），仅作用于 `启用新UI=false` 灰模路径；新 UI 默认 `启用新UI=true` 走 `game_ui.tscn` 继承 `main_theme.tres`。两 Theme 并存。

### 2.5 D 类（`addons/taixuan_ui_editor/`）= OUT

- `addons/taixuan_ui_editor/` 下 `data_manager.gd` / `properties_panel.gd` / `toolbox_panel.gd` / `ui_editor.gd` 共 **18 处**裸 `Color(...)` 字面量。
- 性质：编辑器插件 UI，非游戏运行时，不进包。D2 不收口。

---

## 3. top_bar 进度条改法（原 task 第 3 点）→ 已闭环，无需改动

- 原 task 要求「删 top_bar.gd L127-132 `_progress` 页内 StyleBoxFlat 覆盖，改走 `.tres` `ProgressBar/styles/*`，fill=success 绿 / bg=content 色」。
- **现状验证（已闭环）**：
  - `ui/top_bar.gd` 已无 `_progress` 方法、无 ProgressBar（见 §1）。
  - `theme/main_theme.tres` 已统一定义并挂载：
    ```
    [sub_resource type="StyleBoxFlat" id="sb_pbar_fill"]
    bg_color = Color(0.4941, 0.8275, 0.6039, 1)   ; 进度条 success #7ED39A   (L212-213)
    [sub_resource type="StyleBoxFlat" id="sb_pbar_bg"]
    bg_color = Color(0.1725, 0.2392, 0.2627, 1)   ; bg.content #2C3D43       (L197-198)
    ProgressBar/styles/background = SubResource("sb_pbar_bg")   (L380)
    ProgressBar/styles/fill      = SubResource("sb_pbar_fill")  (L381)
    ```
  - 主理人拍板的「top_bar 等级进度条 fill 用绿」**已落地在 `.tres`，像素等价（除 fill 金→绿这一处有意语义变更，早已在上游完成）**。
- **结论**：top_bar 改法 = **无动作**。D2 对此项的收口已在上游 commit `cd53084` 完成，本轮仅确认闭环。

---

## 4. 其余三处 ProgressBar 覆盖收敛建议（A2 灰区，Phase 2 待裁定）

> 这三处是 D2 真正的「单源化收口」候选。是否收口、如何收口，需主理人裁定 Phase 2 边界。

| 文件 | 现状 | 与 `.tres` 关系 | 建议 |
|------|------|----------------|------|
| `page_battlepass.gd` L86-89 | fill=绿(`color_status_success`)，bg 用 `.tres` 默认 | 完全等价 | 可删 in-code `StyleBoxFlat`，纯继承 `.tres`（冗余消除） |
| `page_building.gd` L941-948 | fill=**金**(`color_text_gold`)，bg=#2C3D43 | bg 等价，fill 金≠绿 | **需裁定**：升级进度是否改绿（与全局一致）或保留金（建筑/养成语义） |
| `page_disciple.gd` L656-675 | fill=动态参数(gold/success/red/aux)，bg=#2C3D43 | bg 等价，fill 动态 | 保留覆盖机制，或新增命名变体 `SectProgress{State}` 收口到 `.tres` |

- **统一收口模式（若主理人同意 Phase 2 收口）**：在 `main_theme.tres` 新增 `SectProgressGold`/`SectProgressSuccess`/`SectProgressDanger`/`SectProgressAux` 命名 StyleBoxFlat 变体，三处代码改为 `theme_type_variation` 引用或 `add_theme_stylebox_override("fill", preload(...))`，消除 in-code 重建。
- **原则**：收口必须像素等价；仅 `page_building` 金→绿属有意语义变更，须主理人显式拍板。

---

## 5. 闸门 / 校验挂接建议（Phase 2 参考）

现有校验已覆盖部分颜色类：
- `pre_f5_check.py`：
  - `check_color_token_drift`（L238）：仅校验 `COLOR_STATUS_SUCCESS/success` + `COLOR_TEXT_RED/danger` 双写一致性（2 组，范围红线）。
  - `check_rarity_color_single_source`（L306）：品阶色单一源。
  - 注册于 L877-878。
- `tools/p1b_token_gate.py`：
  - **G8 颜色零改动（硬红线）**（L297-333）：`color_digest()` 对 `main_theme.tres` 全部含 `Color(` 的非注释行算 SHA256；`gate_g8()` 比对指纹。**⚠️ 若 Phase 2 改动 `.tres` 任何颜色，必须同步重算并提交新指纹，否则 G8 FAIL。**

**建议新增 D2 闸门**（Phase 2 实施时挂 `pre_f5_check.py`）：
- `check_progress_bar_single_source()`：扫描 `ui/*.gd`，断言不再出现 `ProgressBar` + `add_theme_stylebox_override("fill"/"background", StyleBoxFlat.new())` 的 in-code 重建；允许 `page_disciple.gd` 动态 fill 例外（白名单），或要求改用 `.tres` 命名变体。

---

## 6. 风险与待裁定清单

### 6.1 风险
- **R1（语义分歧）**：`page_building.gd` 升级进度条 fill 用金（#FFD77A），与 top_bar / battlepass 的全局绿（#7ED39A）约定矛盾。需主理人裁定统一为绿或保留金。
- **R2（技术债·C 类）**：`main.gd` 暗金三值漂移（#C8A86A vs #C9A656 vs #C9A865）+ 第四色源 + 运行时 `造主题()` 双 Theme。正式债，D2 不碰，建议另立专项。
- **R3（G8 指纹）**：Phase 2 若改 `.tres` 颜色，必须重算 `p1b_token_gate.py` G8 指纹，否则 CI 红。
- **R4（真机签字）**：沙箱无 Godot binary，本轮仅静态 + 代码层；F5 真机视觉签字归用户本地，D2 Phase 2 完成后需用户在本地 F5 复核像素等价。
- **R5（文档过时）**：`design/06-角色与UI/5页样式收口规范.md` §3.6 仍描述「top_bar L127-132 `_progress` 手写 StyleBoxFlat 覆盖 fill=COLOR_BORDER_GOLD」——与现状不符（已删）。该文档此节需随 D2 更新（属文档同步，非源码改动；可纳入 Phase 2 或单独小改）。

### 6.2 待主理人裁定（Phase 2 边界）
1. **是否收口 A2 三处 ProgressBar 覆盖**回 `.tres`（删 in-code StyleBoxFlat）？
2. **`page_building` 升级进度条 fill**：改绿（与全局一致）还是保留金？
3. **`page_disciple` 动态 fill**：保留 in-code 覆盖，还是新增 `.tres` 命名变体（`SectProgress{State}`）收口？
4. 是否**新增 `pre_f5_check.py` 的 `check_progress_bar_single_source` 闸门**？
5. 是否顺带**修正 `5页样式收口规范.md` §3.6 过时描述**（文档同步）？
6. Phase 2 是否触碰 **C 类 `main.gd` 暗金漂移**（建议 NO，另立专项）？

---

## 7. 附录：扫描方法与证据
- 全仓 `ui/*.gd` + `components/*.gd` 裸 `Color(` 字面量扫描（Grep，含注释排除）。
- `ui_theme.gd` `COLOR_*` 常量与 `color_*` getter 提取（L12/23/30/196/203/208）。
- `main_theme.tres` ProgressBar 段（L196-213、L378-381）。
- `git log` 核实 top_bar 手写覆盖删除（commit `cd53084`，2026-07-29）。
- 现有闸门核对：`pre_f5_check.py` L223-306/877-878；`p1b_token_gate.py` L53-54/297-333。
- 未执行：Godot 运行、F5 真机（沙箱无 binary）。

# T5 独立验收报告 — M2/M3「.tscn 颜色单源化」收口

- 验收人：严守真（quality-lead），独立验收方，**全程未修改任何源码**
- 仓库：`E:\Xiuxian\taixuanzongmenlu` · 引擎：Godot v4.7.stable.official.5b4e0cb0f
- 第 1 轮判定：**FAIL（阻塞）** — 静态项 6/6 全过，但引擎级运行时验证发现机制① 全量失效
- **第 2 轮（复验·终审）判定：PASS — 签字放行**（详见文末「七、复验签字」）

---

## 一、总判定

| # | 验收项 | 结论 |
|---|---|---|
| 1 | 扫描回归有效性（`--gate`） | **PASS** |
| 2 | pre_f5 绿 | **PASS** |
| 3 | 命名变体完整性 + StyleBox RGBA | **PASS**（静态）／**FAIL**（运行时不生效） |
| 4 | 运行时常量正确性 | **PASS** |
| 5 | 结构合法性 + #2C5F52 零改动 | **PASS** |
| 6 | 微色裁定吻合 P1-C | **PASS** |
| ★ | **端到端渲染等价（QA 追加）** | **FAIL** |

机制②（运行时 apply）完全正确；机制①（theme_type_variation）**8/8 全部回落 Godot 默认样式**。

---

## 二、逐项证据

### 1. 扫描回归（PASS）
裸跑取真实退出码：

```
python tools/theme_deviation_scan.py --gate ; echo $?
→ EXIT 0
  ui/home_page.tscn        共 2  functional=0  待裁定=0  微色=0  已标注=2
  ui/top_bar.tscn          共 0  functional=0
  ui/sect_home_page.tscn   共 0  functional=0
  ui/bottom_tab_bar.tscn   共 0  functional=0
[PASS] 目标 .tscn 的 functional 偏离已归零
```

> 备注：全仓仍有 `functional=12`，位于非目标文件，属 M2/M3 范围外，不阻塞本次。

### 2. pre_f5（PASS）
`python pre_f5_check.py` → `总判定: [PASS] 全部通过，可放心 F5`，exit 0。

### 3. 命名变体完整性（静态 PASS）
- 使用集 = 注册集 = 8 个，**无悬空引用、无冗余注册**。
- 8 个 StyleBox 的 bg/border RGBA 与交办规格**逐位一致**（sb_nav_btn / sb_nav_active / sb_fold / sb_avatar / sb_lv / sb_top_bg / sb_res_bg / sb_home_panel 全部核对通过）。
- `load_steps`：13 原有 + 8 新增 = 21 子资源 + 1 主资源 = **22** ✓
- 节点类型匹配：`SectNavBtn/SectNavActive` → Button（注册 normal/pressed/hover）；其余 6 个 → Panel（注册 panel）✓

### 4. 运行时常量（PASS）
`ui_theme.gd` 7 个常量逐位比对全部一致：

| 常量 | 值 | 结果 |
|---|---|---|
| COLOR_STATUSBAR_BG | (0.055, 0.082, 0.090) | ✓ |
| COLOR_HOME_DIVIDER | (0.784, 0.659, 0.416) | ✓ |
| COLOR_HOME_BAR_BG | (0.118, 0.169, 0.157) | ✓ |
| COLOR_TEXT_TITLE2 | (0.941, 0.902, 0.824) | ✓ |
| COLOR_PANEL_BG | (0.173, 0.243, 0.271) | ✓ |
| COLOR_BORDER_GOLD | (0.788, 0.651, 0.337) | ✓ |
| COLOR_TEXT_TITLE1 | (0.902, 0.780, 0.471) | ✓ |

**节点路径可达性（QA 追加·防静默失效）**：`home_page.gd` 15 条路径（TopBar/TopBG、TopBar/Divider、BottomBar/BarBG、BottomBar/TopLine、C5_快捷入口/Lbl0~5、Tab0~4#Label）**全部命中**，缺失 0。`bottom_tab_bar.gd` 的 BG / TopDivider / Tab_*/Underline ×5 **全部命中**。

**删除字面量覆盖闭环**：
- home_page.tscn 删 4 处 ColorRect.color + 11 处 font_color → `_apply_theme()` 4 + 11 全覆盖 ✓
- bottom_tab_bar.tscn 删 12 行 = BG 1 + TopDivider 1 + Underline 5 + Label font_color 5。
  其中 **Label font_color ×5 不在 `_apply_theme()` 内**，但由 `select()`（第 66–70 行，`_ready()` 第 30 行无条件调用）覆盖赋值，原 .tscn 字面量本就是被运行时覆盖的死值 → **行为等价，无回归**。（此 5 处未被工程侧 `.zz_pixel_proof` 覆盖，由 QA 补验。）

### 5. 结构合法性（PASS）
引擎级 `load()` + `instantiate()` 实测（Godot 4.7 headless）：

```
OK  home_page.tscn        root=Control children=20
OK  top_bar.tscn          root=Control children=2
OK  sect_home_page.tscn   root=Control children=4
OK  bottom_tab_bar.tscn   root=Control children=7
```

4 场景全部合法加载并实例化，`theme_type_variation` 语法正确，无悬空引用。

**#2C5F52 零改动**：仅存于 `main.gd:39`、`addons/taixuan_ui_editor/data_manager.gd:105`，二者均不在本次 `git diff` 范围（改动仅 `theme/`、`ui/`、`ui_theme.gd`）→ **未触碰** ✓

### 6. 微色裁定（PASS）
两处均保留内联字面量且注释到位，语义确为非功能性氛围/遮罩，符合 P1-C：

```gdscript
Overlay  color = Color(0.086, 0.133, 0.114, 0.5)   ; 非功能色·局部微色·保留（页面氛围暗底 scrim #16221D@0.50，终裁 D 案，不收口）
TopMask  color = Color(0.055, 0.082, 0.09, 0.45)   ; 非功能色·局部微色·保留（顶部渐隐遮罩 mask @0.45，非 token 语义，不收口）
```

---

## 三、🔴 阻塞项（BLOCKER）

### B-1　项目级主题未挂载：`[gui] theme=` 是无效键
`project.godot:37` 为 `theme="res://theme/main_theme.tres"`。Godot 4 实际读取的键是 **`gui/theme/custom`**，`gui/theme` 会被存储但**永不生效**。

实测（Godot 4.7）：

| 配置 | ThemeDB.get_project_theme() | 变体解析 |
|---|---|---|
| `theme=`（**当前仓库**） | **null** | ❌ 回落默认 |
| `theme/custom=` | Theme 对象 | ❌ 仍回落（见 B-2） |
| `theme/custom=` + `base_type` | Theme 对象 | ✅ 正确 |

> 溯源：该键系 P0「双主题解除」时删除 `theme/custom="uid://cdacbo1s6f55c"` 所致 —— 删掉的恰是唯一生效键，留下的是惰性键。属 M2/M3 之前引入的既有缺陷，但被本次改造放大为致命。

### B-2　8 个命名变体缺 `base_type` 注册
`main_theme.tres` 只写了 `Xxx/styles/...`，未写 `Xxx/base_type`。即使主题挂载成功，`Control` 的主题依赖链仍不会纳入该变体 → 继续回落默认样式。

### 合并影响（真机实测，真实场景）
当前配置下 `project_theme_mounted = false`：

```
[M1-variation] C1_宗门正殿        exp=(0.118,0.169,0.157,1)  got=(0.1,0.1,0.1,0.6)  *** MISMATCH ***
[M1-variation] C5_快捷入口        exp=(0.118,0.169,0.157,1)  got=(0.1,0.1,0.1,0.6)  *** MISMATCH ***
[M1-variation] LeftNav/Nav_总览   exp=(0.18,0.25,0.32,0.95)  got=(0.1,0.1,0.1,0.6)  *** MISMATCH ***
[M2-runtime]   TopBar/TopBG       ... OK
[M2-runtime]   BottomBar/BarBG    ... OK
[M2-runtime]   BG / TopDivider    ... OK
[micro-kept]   Overlay            ... OK
```

**改造前** .tscn 持有内联 StyleBoxFlat，无论主题是否挂载都能正确渲染；**改造后**改为变体引用，渲染完全依赖主题解析 → 由「一直对」变成「一直错」。这是本次改造引入的**真实视觉回归**：首页 5 张卡片、顶栏信息条/头像框/等级徽章/5 个资源槽、宗门首页 2 导航按钮 + 2 折叠区共 **17 个控件**将渲染为 Godot 默认灰底 `(0.1,0.1,0.1,0.6)`，暗青+鎏金风格全失。

---

## 四、修复建议（已验证有效，需工程侧执行）

1. `project.godot:37`：`theme=` → **`theme/custom=`**
2. `main_theme.tres` `[resource]` 段补 8 行：
   ```
   SectNavBtn/base_type = &"Button"
   SectNavActive/base_type = &"Button"
   SectFold/base_type = &"Panel"
   SectAvatar/base_type = &"Panel"
   SectLv/base_type = &"Panel"
   SectTopBg/base_type = &"Panel"
   SectResBg/base_type = &"Panel"
   SectHomePanel/base_type = &"Panel"
   ```

修复后同一套真机用例结果：

```
project_theme_mounted = true
C1_宗门正殿 OK  C5_快捷入口 OK  LeftNav/Nav_总览 OK
TopBar/TopBG OK  BottomBar/BarBG OK  BG OK  TopDivider OK  Overlay OK
SUMMARY: 8/8 variations resolved to intended color
```

---

## 五、流程改进建议

1. **扫描器存在盲区**：`theme_deviation_scan.py` 只证明「.tscn 里没有字面量」，不证明「颜色仍渲染正确」。建议增加**运行时等价闸门**（headless 加载场景 → 比对 `get_theme_stylebox().bg_color` 与期望值），否则「删字面量」永远能刷绿。
2. **pre_f5 建议纳入**：`gui/theme/custom` 非空 + 变体 `base_type` 注册完整性两项静态断言，成本极低。
3. 工程侧 `.zz_pixel_proof.py` 做的是**文本层等价**，未覆盖引擎解析层；建议升级为引擎级。

---

## 六、签字

**FAIL — 不予放行。** 值域/结构/单源化手法均正确且质量高（静态 6/6 全过），但机制① 在当前工程配置下 100% 不生效，合入即导致 17 个控件视觉回归。修复 B-1 + B-2 两处（共 9 行，已验证有效）后，本人可即刻复验签字。

---

## 七、复验签字（T5-FIX 后 · 终审）

修复已落地并经本人独立复验：
- `project.godot:37` → `theme/custom="res://theme/main_theme.tres"`（B-1 已解）
- `main_theme.tres` `[resource]` 段新增 8 行 `base_type`（NavBtn/NavActive=`&"Button"`，其余 6 个=`&"Panel"`）（B-2 已解）

### 引擎级真机复测（Godot 4.7 headless，测试工程 `[gui]` 段逐字镜像真实 project.godot）

`project_theme_mounted = true`（原为 false）· **26/26 检查项 OK，0 MISMATCH**

| 控件 | 期望 | 实测 | 一轮 → 二轮 |
|---|---|---|---|
| C1_宗门正殿 | (0.118,0.169,0.157,1) | 同左 | 灰底 → **OK** |
| C2/C3/C4/C5 卡片 | (0.118,0.169,0.157,1) | 同左 | 灰底 → **OK** |
| LeftNav/Nav_总览 | (0.18,0.25,0.32,0.95) | 同左 | 灰底 → **OK** |
| LeftNav/Nav_功能 | (0.12,0.17,0.23,0.92) | 同左 | 灰底 → **OK** |
| InfoBar / AvatarFrame | (0.07,0.1,0.14,0.94) / (0.14,0.2,0.26,1) | 同左 | 灰底 → **OK** |
| TopBG / Divider / BarBG / TopLine | — | 同左 | OK → OK |
| BG / TopDivider（底栏） | — | 同左 | OK → OK |
| Lbl0 / Tab0#Label（font_color） | (0.941,0.902,0.824,1) | 同左 | OK → OK |
| Overlay / TopMask（微色保留） | (0.086,0.133,0.114,0.5) / (0.055,0.082,0.09,0.45) | 同左 | OK → OK |

**命名变体解析：8/8 全部正确**（SectHomePanel / SectTopBg / SectAvatar / SectLv / SectResBg / SectFold / SectNavBtn / SectNavActive）。
场景内变体绑定实测：`Nav_总览`→SectNavActive、`Nav_功能`→SectNavBtn、`FoldSection_动态/BG` 与 `FoldSection_殿阁/BG`→SectFold。

### 回归与锁定复查
- 8 组 StyleBox bg/border RGBA **drift = 0**（修复未触碰任何色值）
- `base_type` 注册 8/8 类型正确；`load_steps=22` = 21 子资源 + 1 ✓
- `project.godot` 仅 1 行变更；4 个 .tscn 与 `ui_theme.gd` 本轮**零改动**（diff 行数与一轮完全一致）
- **#2C5F52 在 8 个在范围文件中出现 0 次** ✓
- 4 个 .tscn 残留色字面量：仅 home_page.tscn 那 2 处已标注微色，其余 3 个文件为 0 ✓

### 双闸门
- `theme_deviation_scan.py --gate` → **EXIT 0**，4 目标 functional 全 0，home_page 仅 2 微色·已标注
- `pre_f5_check.py` → **exit 0，[PASS]**
  > 注：在 PowerShell 默认 GBK 控制台下会误报 3~4 项 FAIL（`git` 不在该 shell PATH + 子进程打印 `\u2705` 触发 UnicodeEncodeError）。受控 A/B 实证：同一仓库同一时刻，仅切换 `PYTHONIOENCODING=utf-8` → exit 1/4 FAIL 变为 exit 0/0 FAIL。属**环境编码假阳性**，非代码缺陷。建议 CI 固定 `PYTHONIOENCODING=utf-8`。

### 终审结论

**PASS — 同意签字放行。** 一轮的两项阻塞（B-1/B-2）已全部闭环并经引擎级实测确认；机制① 由 0/8 恢复为 8/8，机制② 保持全绿，微色保留项与 #2C5F52 锁定项均未受影响，无新增回归。

> 遗留建议（不阻塞本次）：扫描器仅证「无字面量」不证「渲染正确」，建议将本次的 headless 运行时等价用例固化为常驻闸门，并把 `gui/theme/custom` 非空 + `base_type` 完整性纳入 pre_f5 静态断言，防止同类静默失效复发。

> 质量门为建议性门控，最终放行由用户决定。

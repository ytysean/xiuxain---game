# PH7-QA-B1 独立复核（allow_clip 四数 + X06 真实入口）

> 复核人：quality-lead-2（严守真）｜2026-09-17｜**只读**（未改任何 `.gd`/`.csv`/资产；**未起 Godot**）
> 派单人：team-lead（msg「重新激活 · 两项不用起 Godot 的独立复核」）
> 交付对象：team-lead
> **版本**：v1（§0–§6：allow_clip 四数 + X06 入口）→ **v2 增补 §7「判据口径」**（真噪声判定模板 + 跨批复现留痕；于 QA-C1 轮补入）

## §0 结论摘要

| 项 | 结论 | 判定 |
|---|---|---|
| **A-1** `natural=2194` 的 API 出处 | `Font.get_string_size()`（**未换行固有宽度**，**非** `get_minimum_size()`）⇒ **量正确**，但标签名「实际绘制宽度」应改为「未换行固有宽度」 | 见 §2.1 |
| **A-2** 量纲自洽 | 95 × 23 ≈ 2185 vs 实测 2194（Δ **+0.41%**），单位一致（viewport）；**不是量纲错位** | PASS |
| **A-3** `min=(1,1)` | 出自 `get_minimum_size()`；该控件 `min.x` **恒≈1**（与产品注释 `sect_home_page.gd:1318` 一致）⇒ **不提供文本宽**；`natural` 另出 `get_string_size` 正确 | PASS |
| **A-4 ★ 反证用错量** | probe `:88` 的「横向溢出」判据 = `min_noclip.x > 框宽+0.5`，而 `min.x` **恒≈1** ⇒ **该反证恒假、结构上不可能成立** ⇒ 不能据此宣称「clip 用于横向裁切」 | **CONCERNS（点名）** |
| **A-5** 「allow_clip=true 是刚需」 | **结论成立、但机制归因错**：实测实为**纵向**防撑高（67.5→145，+115%），**非**横向溢出；live `autowrap_mode=3` 使横向溢出不可能发生 | **CONCERNS** |
| **B-1** X06 帧驱动方式 | **direct-call**（`tests/ui_full_accept.gd:139` → `_special_step` → `_ui.call(...)`）；**非真实入口** | 确认 |
| **B-2** X06 底色普查 `0.954 #213533` | 颜色**值**本身有效（源 = 页面级硬编码 `page_offline_manager.gd:17`），但 **① 该页 0 产品入口（不可达）② 该帧走非标准底色路径（无 `_sub_bg`）** ⇒ 不能当「玩家可见/标准二级页」基线 | 须标注 |
| **B-3** 不走 `ENTRY_SUB_PAGES` 的帧 | **6 特例 X01–X06**（+ 5 Tab + 首页）；其中**仅 X06 为孤儿**（X01–X05 均真实可达） | 清单见 §3.3 |

**总判定：CONCERNS。**
- 四数**方法层面**：3 项自洽（A-2/A-3）+ 1 项标签不精确（A-1），**四数本身无错误**。
- 四数**结论层面**：**「横向裁切刚需」的归因不成立**（A-4 反证恒假 + A-5 机制实为纵向）——这是本轮**唯一需要工程线回炉**的点。
- B 段：X06 帧性质确认 = direct-call + 不可达，底色值可留但须加两处标注。

---

## §1 复核对象与状态

### 1.1 任务 A 材料（allow_clip 四数）

| 材料 | 路径 | 说明 |
|---|---|---|
| 探针脚本 | `.workbuddy/_ph7visual/_src_backup/_color2_band.gd.txt` | 126 LF / 4303 B / md5 `cf130eb5209753636d099731d030bc56` / mtime 03:19:52 |
| 探针场景 | `.workbuddy/_ph7visual/_src_backup/_color2_band.tscn.txt` | 6 LF / 173 B / md5 `ba63d0e7c522b9aecbe1d71a67efc97d` |
| 引擎日志 | `.workbuddy/_ph7visual/bandprobe/godot_log.txt` | 29 LF/29 CR（CRLF）/ 1996 B / md5 `c019cb98f95e566a629b5fc774c4cf51` / mtime 03:21:00 |
| 截图 clip=true | `.workbuddy/_ph7visual/bandprobe/_color2_band_clip_true.png` | 1472116 B / md5 `0fbc7f414bc70ed283580122506ae58f` |
| 截图 clip=false | `.workbuddy/_ph7visual/bandprobe/_color2_band_clip_false.png` | 1478241 B / md5 `8f771b2564cf2352197b3fc484e980f0` |
| 跑分器 | `.workbuddy/_ph7visual/_color2_band_run.py` | 54 LF / 1826 B / md5 `8d04c47ca19266af44e70e10bdb32181` |
| 跑分输出 | `.workbuddy/_ph7visual/_color2_band_out.txt` | `EXIT=0` ＋ 两张 PNG |

> 交叉核对：`accept_shots_full/_color2_band_clip_{true,false}.png` 与 `bandprobe/` 同名文件 **md5 逐字节相同**（`0fbc7f41…` / `8f771b25…`）⇒ 帧集一致，无二次拍摄混入。

**产品侧现状（只读）**：`ui/sect_home_page.gd` = 65453 B / LF1422 / md5 **`d47cc422327c906f368a065fa7534693`** / mtime 03:15:54（= team-lead 裁定的「预期中间态」，含 COLOR-2 Step 1 的 `allow_clip` 形参）。BandText 构造点 = `sect_home_page.gd:730-733`（`allow_clip=true`），形参 = `:1303`，`lbl.clip_text = allow_clip` = `:1311`，shadow `sh.clip_text = allow_clip` = `:1339`。

### 1.2 任务 B 材料（X06 真实入口）

| 材料 | 路径 | md5 / 关键 |
|---|---|---|
| 验收 harness | `tests/ui_full_accept.gd` | 18512 B / LF425 / md5 `bb0c50c7dfd9c3dfde38ac218c08a8d7` / mtime 09-16 03:08:45 |
| 路由中枢 | `ui/game_ui.gd` | 64688 B / LF1393 / md5 `f25068edce0bdef7f9a3c7b063e815bc` / mtime 09-16 21:46:47 |
| X06 承载页 | `ui/page_offline_manager.gd` | 21922 B / LF573 / md5 `d1359c1d130b750703c8c86816ddf93d` / mtime 09-16 21:42:33 |

### 1.3 量纲约定（本项目纪律，本文全篇沿用）

`frame 720×1280 = 逻辑 480×1.5 = viewport(1080)×0.6667`；`UI_SCALE = 2.25`（`ui_theme.gd:145`）为 **逻辑→viewport** 的倍率。
本文凡写像素/尺寸**必标空间**（逻辑 / viewport-1080 / frame-720），禁裸写换算数字。

---

## §2 任务 A：`allow_clip` 四数独立复核

被复核的四数（工程线报）：
| # | 工程线报值 | 空间口径 |
|---|---|---|
| ① | 框宽物理 **729.0**（= 324 逻辑 × 2.25） | **viewport-1080** |
| ② | 文本实际绘制宽度 natural = **2194.0** = 3.01× 框宽（95 字「测」） | **viewport-1080** |
| ③ | 横向裁住 = **是** | — |
| ④ | 纵向完整 = **是**（行高 `Font.get_height(23)=34.0` ≤ 框高 67.5） | **viewport-1080** |

日志原文（`godot_log.txt`）：
```
>>>C2B fsz=23 行高=34.0 框宽物理=729.0 框高物理=67.5 clip_text=true
>>>C2B 长文 字数=95 文本实际绘制宽度(natural)=2194.0 = 3.01×框宽
>>>C2B 属性 autowrap_mode=3 (OFF=0) overrun=0 line_count=4 visible_line_count=1 fsz=23
>>>C2B [clip=true ] size=(729.0, 67.5) min=(1.0, 1.0)  → 横向裁住=true
>>>C2B [clip=false] size=(729.0, 145.0) min=(1.0, 145.0)  → 横向溢出=false
>>>C2B 纵向完整=true（行高 34.0 <= 框高 67.5）
```

### 2.1 Q1 —— `natural=2194.0` 从哪个 API 读出？语义对不对？

**出处（原文行）**：probe `_color2_band.gd.txt:63` 与 `:68`
```
:63   nat = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
:68   nat = f.get_string_size(长文, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
:69   prints(... 文本实际绘制宽度(natural)=%.1f ...)
```
⇒ 2194.0 = **`Font.get_string_size("测"×95, LEFT, -1, 23).x`**。

**语义判定**：`get_string_size()` 返回的是**未换行（单行）固有宽度**——这正是判断「文案是否需要裁切」的**正确量**，**不是** `get_minimum_size()`。**Q1 断言用对了量**，不必点名。

**唯一措辞问题（不精确、非错误）**：probe 与工程线皆把它叫「**文本实际绘制宽度**」。但该 Label live `autowrap_mode=3`（日志第 3 行），**实际屏幕上是换行后逐行绘制**（`line_count=4`、`visible_line_count=1`），每行宽 ≤ 框宽。故「实际绘制宽度」是**误称**，应写「**未换行固有宽度（single-line intrinsic width）**」。

### 2.2 Q2 —— 独立算术路径：量级是否证明不是量纲错位？

**独立估算**（不取信探针输出，自算）：
- 全角 CJK 字形 advance ≈ **1.0 em = font_size(px)** ⇒ 95 字 @ fsz=23 期望宽 ≈ **95 × 23 = 2185**。
- 实测 **2194** ⇒ 差 **+9**（**+0.41%**）；逐字 advance = 2194/95 = **23.09** = **1.004 em**。
- 反查若量纲错位会现的伪值：×0.6667 ⇒ 1463；×1.5 ⇒ 3291；÷2.25 ⇒ 975（= 逻辑口径）。**均不命中 2194。**

**结论**：2194 与「95 个全角字 @ 23px」**同量级**，且与 ① 框宽 **同处 viewport-1080 空间**（`lbl.size.x` 与 `get_string_size` 皆 viewport 像素）⇒ **比值 3.01× 成立，非量纲错位**。**PASS**。

### 2.3 Q3 —— `size=(729,67.5)` / `min=(1,1)` 从哪读？`min=(1,1)` 说明什么？

**出处**：probe `:76`（`size_clip = lbl.size`）、`:77`（`min_clip = lbl.get_minimum_size()`）；反证侧 `:85`、`:86` 同法。

**`min=(1,1)` 的含义**：该 Label `get_minimum_size().x` **恒≈1**——**开 clip 时 (1,1)、关 clip 时仍 `min.x=1`（只是 `min.y` 变 145）**。这与**产品代码自己的注释**完全吻合：
```
sect_home_page.gd:1318  # 框高 < 字体行高 ⇒ Godot 会「整行不绘」且无任何告警（clip 时 get_minimum_size 恒返 (1,1)）。
```
⇒ `get_minimum_size()` **恒定退化，取不到文本宽**。因此：`natural`（=2194）**必须且确实**另走 `get_string_size` —— **两量来源独立、无重复计数、无冲突**。**PASS**。

### 2.4 Q4 —— `clip=false` ⇒ `size` 变 `729×145` 的机制归因 ★

**机制（实证链）**：
1. Label live `autowrap_mode=3`（`AUTOWRAP_WORD_SMART`，日志第 3 行）。该值**非 `_mk_label_in` 所设**，而由**全局入树兜底钩子**在入树后延迟赋予：`ui_theme.gd:1987-2004`（`_入树_补折行` → `_折行安全` 判真 → `_补折行_延迟:2004 lb.autowrap_mode = AUTOWRAP_WORD_SMART`）。
2. 换行把长文折成 4 行；`clip=false` 时 Label 的 **`get_minimum_size().y` = 全折行高 = 145**（日志 `min=(1,145)`）。
3. **`Control.size` 被钳到 ≥ `get_minimum_size()`** ⇒ 关 clip ⇒ `size.y` 由 67.5 **顶高到 145**（+115%）；开 clip ⇒ `min=(1,1)` ⇒ `size` 保持节点被分配的 67.5。
4. **宽度全程 729 不变**（日志 `size=(729,…)` 两侧一致）——因为 `autowrap=3` 把行宽**锁在分配宽**内，**不是** size flags 撑宽。

**结论：归因 = 「`clip_text` 门控『节点矩形是否跟随折行文本高』」，直接驱动量是 `autowrap_mode=3` + `Control.size ≥ get_minimum_size()` 钳制；与 `LineEdit/Label` 的 size flags 无关。** 工程线若写「autowrap 撑高」方向对，但**必须补上「clip 关 ⇒ min-height 变全折行高 ⇒ 节点被顶高」这一环**，否则无法解释「为何开 clip 高度就回去」。

**这能否支持「allow_clip=true 是刚需」？—— 分两层，答案不同：**
- ✅ **结论层「是刚需」成立**：关 clip ⇒ band 从 67.5 撑到 145 viewport（**+77.5 viewport = +51.7 frame**），会顶穿快照条/气象带布局。clip **确为承重件**。
- ❌ **机制层「为了横向裁切」不成立**：见 §2.5——**反证恒假**且 **`autowrap=3` 下横向溢出不可能发生**。
- ⚠ **「刚需」仅在最坏工况（3× 框宽伪造文案）下被证**；真实「心念」文案长度是否触及折行**未证** ⇒ 若真要下「刚需」定论，需补一条**真实文案长度 → 是否折行**的实测。

### 2.5 ★ 独立发现：反证用错了量（本条必须点名）

probe `:82-88` 的「反证」：
```
:82  # B) 反证：临时 clip_text=false ⇒ Label 顶开最小尺寸 = 文本宽（不裁）
:86  var min_noclip: Vector2 = lbl.get_minimum_size()
:88  ... → 横向溢出=%s" % [..., str(min_noclip.x > 框宽 + 0.5)]
```
**判据 = `min_noclip.x > 框宽 + 0.5`**。但 §2.3 已证 **`min.x` 恒≈1** ⇒ `1 > 729.5` **恒假** ⇒ **该判据结构上不可能为真**，日志 `横向溢出=false` 是「量具坏了」而非「横向不溢出」。**这正是 team-lead Q1 担心的「用错量」，但它不在 `natural`，而在反证判据。**

**三重实证该反证确为伪**：① probe 自带期望（`:82`「顶开最小尺寸 = 文本宽」）与实测 `min=(1,145)` **不符**，工程线未标注；② `autowrap=3` 使横向溢出**物理上不可能**（换行即消解）；③ 截图 clip=false 目视 = band **纵向增行**（两行「测」），**无**任何横向出框。

⇒ **「allow_clip 用于横向裁切」这一归因（亦见产品注释 `sect_home_page.gd:1300`「删了 BandText 的超长文案会横向溢出」）在本探针数据下不成立。** 需工程线二选一收口：
- (a) 若坚持「横向」语义 ⇒ **重做反证**：临时 `autowrap_mode = AUTOWRAP_OFF` 再测 `size_noclip.x`（或 `get_string_size` vs 框宽），得真横向溢出证据；
- (b) 若承认实为纵向 ⇒ **订正产品注释 `:1300` 与探针标签**为「纵向防撑高」，保留 `allow_clip=true` 不动。

### 2.6 任务 A 判定

**CONCERNS**（四数无误，但结论归因需回炉）。

| 阻塞项 | file:行 | 描述 | 严重度 |
|---|---|---|---|
| A-C1 | `_color2_band.gd.txt:88` ＋ `_color2_band.gd.txt:82` | 「横向溢出」反证判据用 `get_minimum_size()`（恒≈1）⇒ 恒假、无判别力；须改判据或用 `get_string_size`/`AUTOWRAP_OFF` 重做 | Major（方法缺陷） |
| A-C2 | `ui/sect_home_page.gd:1300` | 注释「删了 BandText 的超长文案会横向溢出」与实测机制（纵向）不符；且 live `autowrap=3` 使横向溢出不可能 | Major（文档/认知） |
| A-C3 | `_color2_band.gd.txt:69`、日志第 2 行 | 「文本实际绘制宽度」应作「未换行固有宽度」 | Minor（措辞） |
| A-C4 | 探针整体 | 「刚需」仅在最坏工况成立，缺真实文案长度实测 | Minor（证据面） |

> 四数本体（729 / 2194 / 横向裁住=是 / 纵向完整=是）**逐条量正确、口径一致**，可留用；**唯「横向」归因须按 A-C1/A-C2 收口**。

---

## §3 任务 B：`X06_离线管理` 真实入口复核

### 3.1 B-1 —— X06 帧是真实入口还是 direct-call？

**确证行（现盘口径）**：`tests/ui_full_accept.gd:139`
```
:139  	await _special_step("X06_离线管理", "_open_offline_manager_page")
```
驱动体 `_special_step`（`ui_full_accept.gd:165-171`）：
```
:165  func _special_step(tag: String, method: String) -> void:
:167  	if not _ui.has_method(method):
:171  		_ui.call(method)
```
⇒ **按「方法名直达」**：`_ui.call("_open_offline_manager_page")` —— **绕过任何 UI 入口控件/信号**，直接调路由方法。**判定：direct-call，非真实入口。**

**可达性独立复核（只读，全仓非 `.bak` 检索）**：
- `ui/game_ui.gd` 内 `_open_offline_manager_page` 仅出现于 **`:1212`（定义）** 与 **`:1213`（自日志 `print("[GameUI] _open_offline_manager_page 被调用")`）** —— **产品调用点 = 0**。
- 声明处 `:1212` 起，`load("res://ui/page_offline_manager.gd")` 在 **`:1226`**（与美术线线索一致）。
- 真实入口落点 `ui/game_ui.gd:1316` **现文仍为占位**：
```
:1316  		_toast("【闭关设置】系统即将开放")
```
⇒ **X06 全仓无产品 caller，玩家点不到**（与既有 `production/qa/PH7-入口可达性审计.md`「运行时孤儿 1 个：`_open_offline_manager_page`」一致；本条为**独立复现**，非照抄）。

**同类 direct-call 盲区（顺带，供后续定性）**：同一「方法名直达」范式亦见 `tests/_t_deadkey.gd:117`、`tests/_t_btnsweep.gd:116`、`tests/headless_main_enter.gd:68` ⇒ 是**结构性盲区**，非 X06 孤例。

> 补充（口径提醒）：其实**整份 harness 都是 direct-call**——Tab 走 `_ui._show_page`（`:117`）、二级页走 `_ui._show_sub_page`（`:153`，且**绕过 gating**）。故「direct-call」本身不是 X06 的原罪；**X06 的独有问题 = 连一个真实入口都没有**（X01–X05 均有真实接线，见 §3.3）。

### 3.2 B-2 —— 是否影响底色普查里 `X06_离线管理 0.954 #213533` 的有效性？

**颜色来源（独立定位）**：X06 底色 = **页面级硬编码**，非 harness 产物：
```
ui/page_offline_manager.gd:16-19
	bg.color = Color(0.086, 0.125, 0.141, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
```
（与 `design/10-上线冲刺优化/PH7-背景蓝灰重映射方案.md:82` 的归属一致：X06 = 页面级硬编码 → P0-4。）

**判定：颜色「值」有效，但该行须加两处标注：**
1. **不可达 ⇒ 非玩家可见基线**：X06 0 产品入口（§3.1）⇒ 该行**不能**作为「玩家可见页面」统计口径的一部分；后续任何「按可见性」的背景决策须先把它排除或标注为「待接线(B8 已批 `:1316`→`:1212`)」。
2. **渲染路径非标准 ⇒ 与 S0x 行不可直接横比**：`_open_offline_manager_page`（`:1212-1237`）**未**像 `_show_sub_page`（`:941-944`）那样点亮 `_sub_bg`/`_sub_top_bg`（它在 `:1214` 先 `_close_sub_page()` 把二者**隐藏**）⇒ **X06 帧缺二级页标准底衬**，其底色 = 页面自绘 ColorRect(α=0.95) **叠在首页之上**的合成值。⇒ 若普查把 X06 行拿去与 `S01…S52` 行并列比较，属**跨口径**比较，须注记。
   - **缓解**：B8 已批的修法正是 `:1316` 改真调 `_open_offline_manager_page()` ⇒ 接线后**真实入口与 harness 走同一函数** ⇒ 届时帧 = 真实入口态，标注①可解除；标注②（非 `_sub_bg`）则**是新入口的既有行为**，是否要补 `_sub_bg` 属另议。

**结论**：`#213533` / `0.954` 数值**可留**（源为页面硬编码、harness 未污染颜色），但**须打两处标注**（不可达 + 路径非标准）。

### 3.3 B-3 —— 不走 `ENTRY_SUB_PAGES` 的帧清单（64 页口径）

**口径**：64 页 = 首页 1（`00_home`）+ 主 Tab 5（`TAB_宗门/弟子/殿阁/历练/纪事`）+ 二级页 52（`ENTRY_SUB_PAGES`，帧名 `S01…S52`）+ 特例 6（`X01…X06`）。
**不走 `ENTRY_SUB_PAGES` 的 = 特例 6 + Tab 5 + 首页 1 = 12**；其中驱动函数为独立 `_open_*_page()` 的 = **特例 6**（亦即 team-lead 所指）。

| 帧 | harness 驱动行 | 驱动函数（定义行） | 产品侧真实入口 | 可达？ |
|---|---|---|---|---|
| `X01_天下` | `ui_full_accept.gd:134` | `_open_world_map_page`（`game_ui.gd:1184`） | `game_ui.gd:858`（首页入口 id「天下」专用分支） | ✅ |
| `X02_心弦` | `:135` | `_open_chat_page`（`:1128`） | `game_ui.gd:418`（气象抽屉内嵌）＋ `page_message.gd:50-51`（X03 内「心弦」钮） | ✅ |
| `X03_传讯中心` | `:136` | `_open_message_center`（`:1100`） | `game_ui.gd:752`（顶栏「消息中心请求」） | ✅ |
| `X04_宗主详情` | `:137` | `_open_master_detail`（`:1076`） | `game_ui.gd:749`（顶栏「宗主详情请求」） | ✅ |
| `X05_玩家交易` | `:138` | `_open_player_trade_page`（`:1156`） | `page_message.gd:59-60`（X03 内「商队交易」钮） | ✅ |
| **`X06_离线管理`** | **`:139`** | **`_open_offline_manager_page`（`:1212`）** | **无**（`:1316` 仍占位 toast） | **❌ 孤儿** |
| `TAB_宗门/弟子/殿阁/历练/纪事`（5） | `:115-121` | `_ui._show_page`（注：非 `_open_*`，主 Tab 导航） | 底部 Tab 栏 | ✅ |
| `00_home` | `:108-112` | 登录初始态 | — | ✅ |

**口径更正（与派单线索差异）**：派单括注「即入口是**「更多」面板** / 独立 `_open_*_page()`」——**「更多」面板的入口 id 仍是 `ENTRY_SUB_PAGES` 的键**（`_on_首页入口` `game_ui.gd:851-875` 统一走 `ENTRY_SUB_PAGES.get`）⇒ **「更多」面板入口不属于「不走 `ENTRY_SUB_PAGES`」这一集合**。真正「不走」的只有上表的特例 6（独立 `_open_*`）＋ Tab 5 ＋ 首页 1。

**⇒ 后续需重新定性的帧**：**`X06_离线管理`**（不可达 + 非标准底色路径，见 §3.2）。`X01–X05` 虽然同走 direct-call，但**存在真实入口**，其帧可标注「入口链已核、帧走 harness 直达」后继续沿用；**唯 X06 需按「不可达页面」单独定性**。

---

## §4 本轮修正 / 推翻

| # | 对象 | 原（工程线/线索） | 本复核 | 依据 |
|---|---|---|---|---|
| 1 | A-Q1 | 疑 `natural` 用了「最小尺寸」量 | **不成立**：`natural` 出自 `get_string_size`，量正确 | probe `:63/:68` |
| 2 | A-反证 | 「clip=false ⇒ 横向溢出」（隐含：clip 防横向） | **推翻**：反证判据（`min_noclip.x > 框宽+0.5`）**恒假**；且 `autowrap=3` 令横向溢出不可能 | probe `:86/:88` ＋ 日志第 3/5 行 |
| 3 | A-机制 | 未明确 | **补正**：关 clip ⇒ `min-height=145` ⇒ `Control.size` 被顶高（非 size flags） | 日志 `min=(1,145)`、`size=(729,145)`；`ui_theme.gd:1987-2004` |
| 4 | A-标签 | 「文本实际绘制宽度」 | 应作「**未换行固有宽度**」 | `autowrap=3` 下实际绘制为逐行 ≤ 框宽 |
| 5 | B-线索 | 「X06 走 `:1212`，`load:1226`」 | **坐实**，并补：`:1316` **现文仍占位** ⇒ 产品调用点=0 ⇒ **不可达** | `game_ui.gd:1316` 现盘 |
| 6 | B-口径 | 「「更多」面板入口不走 `ENTRY_SUB_PAGES`」 | **更正**：「更多」入口仍是 `ENTRY_SUB_PAGES` 键 | `game_ui.gd:851-875` |

---

## §5 阻塞项 / 待批

| ID | 项 | 归属 | 说明 |
|---|---|---|---|
| A-C1 | 反证判据用错量（恒假） | 工程线 | 重做横向反证（`AUTOWRAP_OFF` + `size_noclip.x` 或 `get_string_size`）**或**认纵向 |
| A-C2 | 产品注释 `sect_home_page.gd:1300` 与实测机制不符 | 工程线 | 按 §2.5 (a)/(b) 收口 |
| B-1 | X06 帧定性 = direct-call + 不可达 | design/工程（B8 已批接线） | 底色行加「不可达」「路径非标准」标注 |
| B-2 | 其余 63 帧无同类隐蔽孤儿 | 质量线（已完成） | 与 `PH7-入口可达性审计.md` 一致：**仅 X06 一个孤儿** |

> **无新增 Blocker**；A-C1/A-C2 为**方法/文档**级收口，不影响 `allow_clip=true` 保留结论（承重性成立，见 §2.4）。
> 待 team-lead 裁定：A-C1 取 (a) 重做反证 or (b) 认纵向订正注释。

---

## §6 证据清单（可复算）

| 文件 | 关键指纹 |
|---|---|
| `tests/ui_full_accept.gd` | `bb0c50c7dfd9c3dfde38ac218c08a8d7` / 18512 B / LF425 |
| `ui/game_ui.gd` | `f25068edce0bdef7f9a3c7b063e815bc` / 64688 B / LF1393 |
| `ui/sect_home_page.gd` | `d47cc422327c906f368a065fa7534693` / 65453 B / LF1422 |
| `ui/page_offline_manager.gd` | `d1359c1d130b750703c8c86816ddf93d` / 21922 B / LF573 |
| `.workbuddy/_ph7visual/_src_backup/_color2_band.gd.txt` | `cf130eb5209753636d099731d030bc56` / 4303 B / LF126 |
| `.workbuddy/_ph7visual/bandprobe/godot_log.txt` | `c019cb98f95e566a629b5fc774c4cf51` / 1996 B |
| `.workbuddy/_ph7visual/bandprobe/_color2_band_clip_true.png` | `0fbc7f414bc70ed283580122506ae58f` / 1472116 B |
| `.workbuddy/_ph7visual/bandprobe/_color2_band_clip_false.png` | `8f771b2564cf2352197b3fc484e980f0` / 1478241 B |
| `.workbuddy/_ph7visual/_qaB1_meta.py` / `_qaB1_meta_out.txt` | 本报告元数据脚本 + 输出 |

**方法论留痕（承 team-lead §一·顺带记，写进本报告）**：**「帧绑定代码态」须显式记录** —— 每批帧附「本批帧绑定的文件 md5」。本报告已对全部被引文件落 md5/字节/mtime（§1.1/§1.2/§6），后续帧批沿用此格式。

---

## §7 判据口径（真噪声判定模板 · 跨批复现）〔补充节 · 承 team-lead「采纳通律 + 要求写入规范」〕

> 本节的**是判据写法，不是结论**（承 team-lead 原话）。目的：把「双模噪声」这条从**一次观测**升格为**可复跑的量具口径**，供 PH7-DET-1 与后续帧批直接引用。
> 缘起：engineering-lead 通报 COLOR-2 两条工具链缺陷（双模噪声 + `PIX_TOL=8` 漏计低幅 hue），我方独立对账后立此口径；team-lead 已**采纳并升格为通律**。

### 7.1 ★ 通律（team-lead 采纳并升格）——「噪声」的测法

1. **定义**：`噪声` = **同一代码态**下、**重拍两次**所得两帧之间的逐像素差（本应为 0，因渲染不确定性而不为 0）。
2. **测法（唯一合法）**：**噪声只能在「逐字节相同（md5 相等）的重拍对」上测**。
   - 若两拍 **md5 相等** ⇒ 重拍稳定性好 ⇒ 噪声 **= 0**。
   - 若两拍 **md5 不等** ⇒ 才有可量噪声，用 `Δ = |帧A − 帧B|` 量化。
3. **禁令**：**`Δ(before→null)`（`Δ(b→n)`）是跨批共模，不是噪声**。它同时含 **① 批间真实改动** ＋ **② 系统性量具偏移**，**两条腿绑的 md5 不同** ⇒ **不得**当噪声（更不得据此把某页标「噪声页」）。
4. **对偶推论（team-lead 原话照录）**：**「同码重拍对 md5 相等」≠「没变化」** —— 而是「**该页在本量具下不可判**」（要么分辨率不足、要么该页本为动态页/多状态）。
5. **命名纪律**：验收门把「**噪声页**」→ **「跨批共模量」**，并**强制标腿定义**（哪两条腿相比、**各自绑定的文件 md5**）。

### 7.2 真噪声判定模板（三步 · 可脚本复跑）

```
① 找「md5 逐字节相等」的两帧（同代码态、重拍）      → 记 pair(N0)，噪声=0
② 与第三帧（同批另一次重拍 / 另一腿）比            → 记 ΔX
③ 若 ① 的 pair 内 md5 已相等：该对差量恒 0 ⇒ 噪声「不可量」
   若 ② 的第三帧跨代码态：其 ΔX 必须显式声明为「跨批共模」，不得记入噪声项
```
- **落地**：PH7-DET-1 的正式交付物 = **两张名单**（**禁合成一张**）：
  1. **真噪声名单**（在**同码 md5 相等对**上测得噪声 > 0 的页）；
  2. **跨批共模名单**（两腿绑不同 md5、Δ 属批间改动+系统性偏移的页）。
- **附带量具口径（对偶，来自 engineering-lead 缺陷②）**：`PIX_TOL=8` 的 `ImageChops.difference().convert("L")` 系**亮度塌缩**，**只配结构性变化**；**色系（hue）变化**的正确仪器 = **全帧色族占比 probe（阈值 A>8）**，**非** `PIX_TOL` 差分。

### 7.3 ★ 跨批复现记录（X03 证据链）〔记一笔〕

- engineering-lead 报 X03「同码两跑 `Δ(null) = 224870`」。我方**独立对账**：
  - `224870` 与 **A2 批 `before_p1_full` 帧逐字节同源**（md5 `6b0d943b55cd…`）。
  - ⇒ `224870` 是 **`before` 腿（批）↔ `null` 腿（批）的跨批共模**，**非** X03 页自身噪声。
- **连带作废**：COLOR-2 的 **28「噪声页」名单** 系**误判**——根因是 **`before` 腿复用了 `before_p1_full`**（绑的是 P1 批代码态，非 COLOR-2 前态），两腿 md5 不同 ⇒ Δ 全为跨批共模。**该名单不得再用**。
- **另一独立复核**（我方）：`00_home 亚阈 505155` / `S22_幻形 亚阈 785668` 复算一致 ⇒ 坐实「`PIX_TOL=8` 漏计低幅 hue」缺陷②（全帧色族 probe 显示 `00_home` 绿 0.695→0.591、蓝灰 0.201→0.299；`S22` 绿 0.846→0.270、蓝灰 0.098→0.655 ⇒ 色系确已变、但被亮度差分漏掉）。

> **口径归属**：7.1/7.2 为本报告补充的**判据级规范**（team-lead 已升格为通律）；7.3 为**跨批复现留痕**。后续任何「噪声」结论**须先满足 7.1-2（md5 相等的重拍对）**，否则只可称「跨批共模量」。

---

*（完）quality-lead-2 · PH7-QA-B1 · 只读复核，未起 Godot，写盘仅本报告。（§7 于 QA-C1 轮补入）*

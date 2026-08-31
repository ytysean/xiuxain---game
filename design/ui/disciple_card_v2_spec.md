# 弟子卡片 v2 布局规格

> 任务 ID：P0-DESIGN-②　|　对应 bug：② 信息不完整
> 页面：`ui/page_disciple.gd`（一级页「弟子」列表项卡片）
> 设计基准：UI 逻辑 480×854，实机 1080×1920，`UITheme.UI_SCALE = 2.25`，`UITheme.GRID = 12`
> 本文档含「当前代码现状」对照，engineering-lead 可据此直接改代码，**不要 commit**。

---

## 0. 当前代码现状（改前对照，便于定位）

卡片构建函数：`ui/page_disciple.gd` → `func _add_disciple_row(d, 索引)`（**当前约 line 305–434**，非任务里估的 340–420，行号已漂移）。现状盘点：

| 元素 | 现状 | 与 v2 差距 |
|---|---|---|
| 头像（真圆） | 已有，`GRID×7=189px`，`avatar_circle_mask.gdshader` 真裁圆（line 344–383） | ✅ 保留；补「无立绘时显示名字首字」占位（见 §8） |
| 名字 | 已有，18px，主色 `C01_TEXT_PRIMARY`（line 391–395） | ✅ 保留 |
| 境界 | 已有，13px，三级色 `C01_TEXT_TERTIARY`（line 397–401） | ✅ 保留；文本格式「练气:五层」由数据层给，UI 透传 |
| 身份 | 已有，但为**纯文字 Label**，12px，用品质色染色（line 403–407） | ❌ 需改为 **pill（bg+border）**，内门青绿/外门灰 |
| 资质 tag（右上） | **完全缺失** | ❌ 新增，右上角，彩色圆角矩形 |
| 战力 | 已有，14px，金色 `C01_TEXT_GOLD`，底部左（line 418–423） | ✅ 保留；规范 icon 与数字间距 `4*UI_SCALE` |
| 道途·性格 pills（右下） | 仅当 道途≠"" 时显示**单个纯文字 Label**（10px，line 425–430）；**性格根本没渲染** | ❌ 改为右下 **2 个并排 pill**：道途 + 性格 |
| 边框色 | 已有，用本地 `_品质颜色(资质)`（line 436–444）染色 | ⚠️ 颜色值**与本文 §4 色板不一致**，且散落在本地函数；建议上收至 `UIThemeConfig`（见 §6） |
| 边框粗细 | 当前 `set_border_width_all(2)`（**未乘 UI_SCALE**） | ⚠️ 与 avatar 框同为 raw 2；建议统一为 `2*UI_SCALE` |

> 结论：v2 不是从零重写，而是**在 `_add_disciple_row` 内做 4 处增量改造**（加资质 tag、身份改 pill、底部改双 pill、颜色上收+对齐色板）。其余保留。

---

## 1. 总体结构

- **卡片容器**：`PanelContainer`，最小高 `GRID*20*UI_SCALE = 540px`（已有，保留），宽由父级 `GridContainer(columns=2)` 自动均分（**只设最小高、不设最小宽**，否则列宽撑出屏外——沿用 line 316–321 注释约定）。
- **内部纵向布局**（`VBoxContainer` 卡片vb，已有）：
  1. **顶行** `HBoxContainer`：`[头像框] [信息列: 名字/境界/身份pill] [资质 tag（顶右对齐）]`
  2. 分隔线 `HSeparator`（已有，保留，可弱化）
  3. **底行** `HBoxContainer`：`[战力（左 expand）] [道途 pill] [性格 pill（右，两 pill 并排）]`
- **字号缩放基准**：所有字号 = `int(round(N * UITheme.UI_SCALE))`，与现有代码一致。
- **品质色边框**：`StyleBoxFlat.border_color = 资质色`，圆角 `8*UI_SCALE`，粗细 `2*UI_SCALE`。

---

## 2. 元素清单与位置（ASCII 草图）

```
+--------------------------------------------------+
| (头像圆形189)   名字 18px             [资质 tag]  |  ← 顶行：头像 | 信息列 | 资质(右上)
|  霜/青/渊/玄     境界 13px    (无立绘显首字)                |
|                  [身份 pill 12px]                          |
|  ──────────────────────────────────────────────  |  ← 分隔线
|  ⚔ 战力 14px        [道途 pill] [性格 pill]      |  ← 底行：战力(左) | 双 pill(右)
+--------------------------------------------------+
        ↑ 整卡 PanelContainer.border_color = 资质色
```

顶行三栏比例建议：头像固定 `189px`；信息列 `SIZE_EXPAND_FILL`；资质 tag 固定宽、`counter_axis_align = TOP`（贴顶右）。
底行：战力 `SIZE_EXPAND_FILL` 占左；道途/性格两 pill 在右，间距 `4*UI_SCALE`，`counter_axis_align = CENTER`。

---

## 3. 元素详细规格（表格）

| 元素 | 位置 | 字号 | 颜色 | 形态 / 备注 |
|---|---|---|---|---|
| avatar circle | 左上 | — | bg `#2A3A4A` | `GRID*7=189px` 真圆 shader（`res://ui/avatar_circle_mask.gdshader`）；无立绘时居中显示**名字首字** Label（见 §8） |
| 名字 | 信息列顶 | 18px | `C01_TEXT_PRIMARY`(#F2F5F3) | 单字/全名透传 `_safe_get(d,"姓名","—")` |
| 境界 | 名字下 | 13px | `C01_TEXT_TERTIARY`(#9FB3B0) | 文本如「练气:五层」，数据层给，UI 透传 |
| 身份 pill | 境界下 | 12px | 内门=青绿 / 外门=灰（见 §8 阶梯） | **圆角矩形 bg+border**，白字；替代原纯文字 Label |
| 资质 tag | 顶行右上 | 10–11px | 白字 `#FFFFFF` | **圆角矩形 bg = 资质色**，文字=中文资质（天才/优良/…）；顶右对齐，不与名字重叠 |
| 战力 | 底行左 | 14px | `C01_TEXT_GOLD`(#D6B16A) | `⚔` icon + 数字，左对齐；icon 与数字间距 `4*UI_SCALE` |
| 道途 pill | 底行右1 | 11px | 灰底白字 | 文本 = 道途；为空时显示「未入门」 |
| 性格 pill | 底行右2 | 11px | 灰底白字 | 文本 = 性格字段值（清冷/豪迈/…）；与道途 pill 间距 `4*UI_SCALE` |
| 边框 | 整卡 | — | 品质色（=资质色） | `PanelContainer` StyleBoxFlat border；圆角 `8*UI_SCALE`，粗细 `2*UI_SCALE` |

**pill / tag 圆角**：`8*UI_SCALE`（与卡片圆角一致即可，tag 可略小取 `6*UI_SCALE`，由 engineering-lead 定）。
**pill / tag 内边距**：左右 `6*UI_SCALE`，上下 `2*UI_SCALE`（文字不贴边）。

---

## 4. 资质色板（必须对齐 UITheme —— 权威来源）

> 此表为**权威目标色**，覆盖全部 6 档资质。当前 `page_disciple.gd._品质颜色()` 的本地色值**与本表不一致**（如妖孽当前 `#E67D21`、旷世当前 `#E84D3D`），须以本表为准并上收至 `UIThemeConfig`（见 §6）。

| 资质 key | 中文 | 边框色 / tag bg 色 | tag 文字色 |
|---|---|---|---|
| `fan_su` | 凡俗 | `#555555` | `#FFFFFF` |
| `pingyong` | 平庸 | `#6FA86F` | `#FFFFFF` |
| `youliang` | 优良 | `#5BA0E5` | `#FFFFFF` |
| `tiancai` | 天才 | `#B888D8` | `#FFFFFF` |
| `yaonie` | 妖孽 | `#E59545` | `#FFFFFF` |
| `kuangshi` | 旷世 | `#E04F4F` | `#FFFFFF` |

- 中文映射（已有，复用）：`page_disciple.gd` 顶部 `const _资质显示`（line 84）与 `disciple.gd.资质显示` 均为 `{"fan_su":"凡俗",…}`，tag 文本取中文。
- 边框色、资质 tag bg 色**共用同一资质色**。

---

## 5. 字号 / 尺寸基准

- 所有字号 = `int(round(N * UITheme.UI_SCALE))`
- 卡片高 = `GRID * 20 * UI_SCALE` = `12*20*2.25` = **540px**（已有，保留）
- avatar 圆框 = `GRID * 7 * UI_SCALE` = `12*7*2.25` = **189px**（已有，保留）
- 边框粗细 = `2 * UI_SCALE` = **4.5px**（当前代码为 raw `2`，需改为乘缩放，见 §0）
- 圆角 = `8 * UI_SCALE` = **18px**（已有，保留）
- pill / tag 间距 = `4 * UI_SCALE` = **9px**；内部左右 padding = `6 * UI_SCALE` = **13.5px**

---

## 6. 与现有代码的对应（给 engineering-lead 的改法）

1. **资质色上收（关键）**：在 `ui_theme_config.gd` 新增（与 `QUALITY_COLOR`/`REALM_COLOR` 同级，遵循「色值唯一来源」架构约定）：
   ```gdscript
   @onready var APTITUDE_COLOR: Dictionary = {
       "fan_su":   Color.from_string("#555555", Color.WHITE),
       "pingyong": Color.from_string("#6FA86F", Color.WHITE),
       "youliang": Color.from_string("#5BA0E5", Color.WHITE),
       "tiancai":  Color.from_string("#B888D8", Color.WHITE),
       "yaonie":   Color.from_string("#E59545", Color.WHITE),
       "kuangshi": Color.from_string("#E04F4F", Color.White),
   }
   func get_aptitude_color(a: String) -> Color:
       return APTITUDE_COLOR.get(a, Color.from_string("#555555", Color.WHITE))
   ```
   - 删除 `page_disciple.gd` 本地 `_品质颜色()`（line 436–444），改调 `UIThemeConfig.get_aptitude_color(资质)`。
   - 边框色、资质 tag bg 色统一取此函数。
2. **复用既有 UITheme 能力**：字体/字号用现有 `add_theme_font_size_override` 范式（已大量使用）；如需统一样式可用 `UITheme.make_panel_stylebox_flat(bg, border, radius, border_w)`（line 417）替代手写 `StyleBoxFlat`，避免散落色值。**不要**在 `page_disciple.gd` 内硬编码颜色字面量。
3. **头像真圆**：沿用 `res://ui/avatar_circle_mask.gdshader`（line 366，已验证），不动。补占位首字 Label（见 §8）。
4. **身份改 pill**：用 `PanelContainer`+`StyleBoxFlat`（bg+border，圆角 `6*UI_SCALE`）包裹一个 `Label`；颜色按 §8 阶梯（内门青绿 `#4CAF7A`、外门灰 `#55554F` 取自 `UIThemeConfig.STATE_COLOR.disabled`）。**不再**用品质色染身份文字。
5. **底部双 pill**：`底部hb` 内追加「道途 pill」「性格 pill」两个 `PanelContainer`；道途文本 = `道途 if 道途!="" else "未入门"`，性格文本 = `_safe_get(d,"性格","—")`。删掉原 line 425–430 的单 道途 Label。
6. **资质 tag**：顶行新增右侧节点，文本 = `_资质显示.get(资质, "凡俗")`，bg = 资质色，白字，圆角矩形，顶右对齐。
7. **边界粗细**：`set_border_width_all(int(round(2 * UITheme.UI_SCALE)))`，与 avatar 框统一缩放。

---

## 7. 验收清单

- [ ] 同屏可见 ≥4 张弟子卡片，每张 `border_color` 对应其资质（凡俗灰/平庸绿/优良蓝/天才紫/妖孽橙/旷世红）
- [ ] 资质 tag 位于**右上角**，不与名字重叠，bg=资质色、白字
- [ ] 身份为 **pill（bg+border）**，内门青绿 / 外门灰；5 级阶梯见 §8
- [ ] 道途·性格为**右下角 2 个并排 pill**，间距 `4*UI_SCALE`；道途为空显示「未入门」
- [ ] 战力数字**左对齐**底部，`⚔` icon 与数字间距 `4*UI_SCALE`，金色
- [ ] 头像为真圆（shader 裁切），无立绘时显示名字首字占位
- [ ] 所有字号 = `int(round(N*UI_SCALE))`，实机 1080×1920 视觉一致
- [ ] 资质色全部来自 `UIThemeConfig.APTITUDE_COLOR`，`page_disciple.gd` 无散落色值、无本地 `_品质颜色()`

---

## 8. Open Issues（规范未覆盖 / 需主理人拍板）

1. **【高·数据对齐】性格显示值冲突**：参考截图 pill 显示 `清冷 / 豪迈 / 谨慎 / 狂傲`，但 `disciple.gd.性格表`（line 50）是 `沉稳守道 / 锐意争先 / 恬淡悟道 / 桀骜不羁 / 仁心济世 / 杀伐果断 …`（12 项长串）。二者**完全不匹配**。
   - 需主理人确认：截图是手搓 mockup，还是存在一套「短性格码」？卡片 pill 应取 `disciple.性格` 原值（长串）还是另一套短显示？
   - 若用长串（如「沉稳守道」4 字），11px pill 宽度需自适应，可能挤压战力；建议 pill 用 `size_flags` 自适应 + 卡片宽够放。
2. **【中】身份 5 级阶梯**：`disciple.gd.身份层级序`（line 152）= `外门 / 内门弟子 / 核心弟子 / 亲传弟子 / 长老`。规范只定了内门青绿、外门灰。建议其余映射（待主理人确认）：
   - 外门 → 灰 `#55554F`；内门弟子 → 青绿 `#4CAF7A`；核心弟子 → 蓝 `#5B8BD9`；亲传弟子 → 紫 `#B04CD9`；长老 → 金 `#E6C778`（取自 `STATE_COLOR.gold`）。
   - 或简化为「内门系青绿 / 外门系灰」两色，其余按内门处理。
3. **【中】道途「未入门」语义**：筑基前 `道途==""`，卡片 pill 显示「未入门」（与详情页 line 735 一致）；筑基后显示实际道途（道修/体修/…）。确认无误，已写入 §3。
4. **【低】头像占位首字**：无立绘（`取头像路径()` 失败或为空）时，在圆形框内居中放一个 `Label` 显示 `姓名` 首字（如 霜/青/渊/玄），字号约 `round(48*UI_SCALE)`、主色。当前代码失败即留空，需补。
5. **【低】边框粗细缩放**：当前 `set_border_width_all(2)` 未乘 `UI_SCALE`（实机仅 ~0.9 逻辑 px，偏细）。按 §5 改为 `2*UI_SCALE`；avatar 框同为 raw 2，建议一并修，保持视觉重量一致。是否同步改 avatar 框由 engineering-lead 决定。
6. **【低】资质色放置位置**：本文建议放 `UIThemeConfig.APTITUDE_COLOR`（与 `QUALITY_COLOR`/`REALM_COLOR` 同层，符合架构）。任务原文写「UITheme.资质颜色」——若主理人坚持放 `ui_theme.gd`，则在该文件加 `const APTITUDE_COLOR` 并去掉本地函数即可，逻辑不变。

---

_— 设计交付：design-card-spec（文策渊）｜仅出规格，代码由 engineering-lead 实现，未 commit。_

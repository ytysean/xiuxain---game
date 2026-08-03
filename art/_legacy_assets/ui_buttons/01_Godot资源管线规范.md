# 《太玄宗门录》UI 按钮 — Godot 资源管线规范

> 技术美术产出。
> - 最终美术风格：深青灰哑光玉石底板、暗金金属浮雕描边、如意云头切角、浮雕祥云暗纹、无文字、透明背景（已对齐弟子立绘套图A与项目既有AI参考图）。
> - 本次已本地生成：`png/` 下 45 张 AI 写实厚涂 PNG（底板 12 + 导航图标 5 + 方形图标 17 + 微型图标 11），总览见 `png/contact_sheet_ai.png`。
> - 风格板/提示词：`04_写实国漫油画风_UI风格板.md`（已锁色/锁材质/锁不可出现元素）。
> - 本地占位生成器：`gen_buttons.py`（Pillow 矢量占位，当AI底板不可用时 fallback，无法达到油画浮雕质感）。

---

## 0. 本地生成器（关键变更）

已不再依赖 HoloPix/Gemini 等外部 API。`gen_buttons.py` 用 Pillow 在本地程序化绘制：

```bash
# 每次改完 gen_buttons.py 后直接重跑，秒出全部 47 张
"C:/Users/Administrator/.workbuddy/binaries/python/envs/ui/Scripts/python.exe" "E:/Xiuxian/taixuanzongmenlu/美术资源/ui_buttons/gen_buttons.py"
```

**生成策略：底板 + 图标完全解耦**
- 底板只出：Tab 常态/选中、方底板常态/选中、正向 3 态、负向 3 态、开关 2 态、微型 1 态
- 图标只出：导航 5 个、方形 17 个、微型 10 个，全部透明 PNG
- Godot 里把图标作为 Button 子节点 `TextureRect` 叠在底板之上，这样同一个底板可复用于 N 个按钮。

## 1. 目录结构（res://）

```
res://art/_legacy_assets/ui_buttons/
├── nav/          # 底部导航 Tab 底板 + 5 个图标
├── icon/         # 方形图标（17 个）+ 方底板
├── btn_pos/      # 正向主操作底板 3 态
├── btn_neg/      # 负向次操作底板 3 态
├── btn_toggle/   # 功能开关底板 2 态
├── micro/        # 微型底板 + 微型图标
├── contact_sheet.png  # 总览图
└── _import_presets/   # .import 预设（见下）
```

> 当前生成目录：`美术资源/ui_buttons/png/`，落盘后可按上表手动归类或改 `gen_buttons.py` 的 `OUT` 变量直接输出到 Godot 目录。

## 2. 导入预设（Import Preset）—— 全 UI 统一

| 参数 | 值 | 理由 |
|------|-----|------|
| Mipmaps | **Off** | UI 不缩放采样，开 mipmap 反而糊 + 占显存 |
| Filter | On (Linear) | 缩放平滑 |
| Repeat | Off | UI 图不平铺（矩形靠 9-slice，不靠 repeat） |
| Compress > Mode | BC7（PC）／ **ASTC 4×4**（移动） | 项目纹理铁律：UI 用 ASTC 4×4 |
| Compress > Normal | 不适用 | UI 无法线 |
| Alpha > Mode | Detect / Opaque (若全不透明) | 透明 PNG 用 Detect |

> 做法：在 Godot Editor 调好一个 `.import` 后「Save as Preset」，其余文件导入时一键套用，杜绝逐文件手调。

## 3. 九宫格（9-slice）—— 视底板形状而定

### A. 方形底板 / 圆角矩形底板
- `Stretch Mode = NinePatch`；
- `Patch Margins`：左右各 20%（≈51px@256²），上下各 8px；
- 这样文字变长只拉伸中段，圆角不变形。

### B. 如意云头切角的长条主按钮 / 竖版 Tab（参考图风格）
**问题**：四角是中式云头/花角，不是普通圆角，简单 9-slice 会拉变形。

**推荐方案**：
1. **固定宽度**：所有主操作按钮统一 512×128，只换 Label 文字。这是最简单、最稳、最符合参考图的做法。
2. **若必须可变宽度**：用 `NinePatchRect`，手调 `Patch Margins` 保护四角云头区域不拉伸；中段设可拉伸区。需要美术出图时四角留足安全边距（每角 ≥ 64px）。
3. **不要**对云头底板直接 `Stretch Mode = Scale`。

## 4. Button 三态接线 + 图标复用结构

Godot 推荐用 **Theme** 统一管理：
- 建 `ui_buttons.theme`（Theme 资源）；
- 在 Theme 里为 `Button` 设 `styles/normal|hover|pressed` = 对应 `StyleBoxTexture`（引用 `btn_pos` 三态图，并设好 9-slice margins）;
- 所有正向按钮共用此 Theme → 一处改全局生效。
- 选中/禁用态同理用 `focus`/`disabled` 纹理。

**图标层（底板与图标解耦）**：
- `Button` 的 `text` 置空；
- 子节点 `TextureRect`（命名 `Icon`）放图标透明 PNG，锚点居中/自定义偏移；
- 这样 `确认/升级/派遣/炼制…` 共用一个 `rect_pos_*.png` 底板，只换子节点的 `Label.text` 和 `Icon.texture`。
- 导航 Tab 同理：底板是 Button，图标 TextureRect 在上部，文字 Label 在下部。

> 文字层：Button 下再挂 `Label`（或直接用 `Button.text`），字体用项目锁定的 type scale {22,17,18,16,15,13}，颜色 `#F4EFE3`，**绝不烧进图里**，从根源避免错字。

## 5. 合批与 Draw Call 预算（竖屏 480×854 移动端）

- **同底板复用**：17 个方形图标若各自独立 .png 仍占 17 个纹理；建议把 17 图标 + 微型图标 **打一张 AtlasTexture / 用 TextureAtlas 合图**，把相关 draw call 合并。
- 导航 Tab 5 个各自独立可接受（仅 5 个）。
- **显存预算**（移动端参考）：UI 纹理总显存建议 < 8MB；256² ASTC4×4 ≈ 32KB/张，17 张 ≈ 0.5MB，余量充足。
- 禁止给 UI 用 `Repeat` + 大图平铺，避免隐式额外采样。

## 6. 命名规范

`{类别}_{名称}_{状态}.png`
- 底板：`nav_base_N.png`、`nav_base_S.png`、`rect_pos_N.png`/`rect_pos_H.png`/`rect_pos_P.png`、`rect_neg_N.png`/`rect_neg_H.png`/`rect_neg_P.png`、`toggle_off.png`/`toggle_on.png`、`micro_base.png`、`sq_base_N.png`/`sq_base_S.png`
- 图标：`icon_nav_jy.png`、`icon_sq_zd_zd.png`、`icon_micro_check.png`
- 状态后缀：N=normal, H=hover, P=pressed, S=selected, on/off
- 全小写 + 下划线，禁中文文件名（避免编码坑，符合项目 Git 净化 LF 约定）

## 7. 与 pre_f5 的衔接（可选增强）

当前 `pre_f5_check.py` 已校验 Tab 数/按钮色值/背景透明度。可加一条轻量校验：
- 扫描 `res://art/_legacy_assets/ui_buttons/` 下文件命名是否符合 `{类别}_{名称}_{状态}.png`；
- 校验方形图标尺寸 = 256×256、主按钮 = 512×128（防美术导出错尺寸）。
> 仅建议，不阻塞现有 19 道闸门。

## 8. 落地检查清单（美术交付前自查）

- [x] 已本地生成最终 AI 底板与图标（`png/` 45 张，见 `contact_sheet_ai.png`）
- [ ] 本地 `gen_buttons.py` 占位底板已移至 `png/_legacy_local/`，不混入最终资源
- [ ] 所有图透明背景、无白底无投影
- [ ] 如意云头底板优先固定宽度；若可变宽度，已手调 NinePatch 保护云头
- [ ] 命名符合规范、状态齐全（3 态 / 开关 2 态 / Tab 2 态）
- [ ] 导入预设已套用（mipmap off、ASTC 4×4）
- [ ] 底板复用到位（正向 8 动作共用 1 套、负向 5 动作共用 1 套）
- [ ] Godot 内文字用 Label（#F4EFE3）、图标用子节点 TextureRect，**不烧进底板图**

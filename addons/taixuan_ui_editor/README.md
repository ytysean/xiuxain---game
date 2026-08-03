# 太玄UI编辑器（Taixuan UI Editor）

《太玄宗门录》竖屏修仙手游的 **UI 可视化编辑器** EditorPlugin，纯 GDScript 实现，Godot 4.7 原生可运行，不依赖任何第三方插件。

> 设计铁律：画布上所有被设计的控件一律使用 **绝对 position / size**，不使用 HBox/VBox 等容器，彻底规避 Godot 4.7 容器把子节点压缩成 0 像素的 bug；所有控件默认设置 minimum_size，禁止文字/图标被裁剪。

---

## 一、插件文件结构

```
addons/taixuan_ui_editor/
├── plugin.cfg            # 插件注册文件（Godot 自动识别，启用即可）
├── editor_plugin.gd      # 插件入口：注入“太玄工具 → UI编辑器”菜单，打开编辑窗口
├── ui_editor.gd          # 编辑器主窗口（核心逻辑：画布/缩放/平移/网格/选中/对齐/撤销/保存导出）
├── data_manager.gd       # 数据管理类 TaixuanUIData：控件工厂 / 数据↔节点 / 保存 / 导出
├── toolbox_panel.gd      # 左侧控件工具箱（6 类控件添加入口）
├── properties_panel.gd   # 右侧属性编辑面板（动态生成可编辑行 + 资源浏览对话框）
└── README.md             # 本说明文档
```

文件即完整代码，直接可用，无需额外生成 `.tscn`（编辑器界面在 `ui_editor.gd` 中纯代码构建）。

---

## 二、安装步骤

1. 将整个 `addons/taixuan_ui_editor/` 文件夹复制到你的 Godot 4.7 工程根目录下（与 `project.godot` 同级）。
2. 打开 Godot 编辑器 → 顶部菜单 **项目(Project) → 项目设置(Project Settings) → 插件(Plugins)**。
3. 在插件列表中找到 **太玄UI编辑器**（作者：牛马，版本 1.2），将右侧开关切到 **启用(Enable)**。
4. 启用成功后，顶部菜单栏会出现 **太玄工具** 菜单，点击 **太玄工具 → UI编辑器** 即可打开编辑器窗口。
   - 兼容兜底：若因编辑器版本差异未能注入顶级菜单，则会在 **工具(Tools)** 菜单下出现 **“太玄工具：UI编辑器”** 项。
5. 首次打开默认画布 768×1344（9:16 竖屏）。

> 资源路径统一使用 `res://` 相对路径，与工程目录结构对齐；导入图片/字体时请用编辑器内的“浏览”按钮选取，自动落为 `res://...`。

---

## 三、基础使用教程

### 1. 认识界面
- **顶部工具栏**：新建 / 打开 / 保存 / 导出JSON / 撤销 / 重做 / 复制 / 删除 / 层级(上移下移置顶置底) / 多选对齐(8 种) / 网格尺寸 / 缩放显示 / 基准图(导入·透明度·显示·锁定·适配) / **字体(默认字体选择·清除)**。
- **左侧工具箱**：点击「图片控件 / 文字控件 / 按钮控件 / 面板控件 / 动画帧」添加到画布中心。
- **中间画布**：滚轮缩放、空格+左键拖动(或中键拖动)平移、空白处拖拽框选。
- **右侧属性面板**：选中单个控件后实时编辑其属性；多选时仅支持对齐。

### 2. 添加与编辑控件
1. 左侧点控件类型 → 画布中央出现默认控件。
2. 在画布上点选控件 → 右侧出现属性面板。
3. 修改坐标 / 尺寸 / 文字 / 字号 / 颜色 / 对齐 / 纹理 / 透明度 / 底色 / 圆角等，画布即时刷新。
4. 拖动控件移动；按住 `Shift` 或 `Ctrl` 点选可加选；空白处框选多选。

### 3. 基准图（设计稿对齐）
- 点工具栏 **基准图 → 导入** 选择 PNG/JPG/WEBP/SVG 作为参考底图。
- 调 **透明度**(0~1)、勾 **显示/锁定**、选 **适配方式**（包含 contain / 覆盖 cover / 原始 origin）。
- 基准图默认按画布比例居中适配，避免拉伸变形。

### 4. 网格与吸附
- 工具栏「网格」数值框调整网格尺寸；
- 拖动控件时默认按网格吸附（保证对齐整齐）。

### 5. 多选批量对齐
- 选中 2 个及以上控件，点工具栏对齐按钮：
  左对齐 / 右对齐 / 水平居中 / 顶对齐 / 底对齐 / 垂直居中 / 等宽 / 等高。

### 6. 撤销 / 重做 / 快捷键
- 撤销 `Ctrl+Z`，重做 `Ctrl+Y`（或 `Ctrl+Shift+Z`）。
- 复制 `Ctrl+D`，删除 `Delete` / `Backspace`。

### 7. 保存与导出
- **保存**：生成 `.taixuan_ui` 工程文件（含画布、基准图、全部控件及编辑器临时态如缩放/平移），可随时打开继续编辑。
- **导出JSON**：生成规范 JSON 布局数据（仅含 canvas / reference_image / controls），供后续 AI 或直接解析生成 Godot 原生 `.tscn` 场景文件。
- **导出tscn**（推荐）：直接生成 Godot 4 可打开的原生场景文件 `.tscn`，导入工程后即可作为子场景实例化，**所见即所得、实机零偏差**。节点类型、绝对坐标、锚点、主题覆盖、资源引用与编辑器预览一一对应。

> **导出 tscn 的一致性保证**：控件锚点采用精确的 `anchor_*` + `offset_*` 写法（非 `anchors_preset` 便捷属性），`offset` 按"相对锚点的像素偏移"换算（父尺寸 = 画布尺寸），与编辑器预览的渲染基准完全一致，避免 Godot 加载时重算偏移导致错位。根节点固定为设计画布尺寸（`layout_mode=3`），背景色通过 `ColorRect` 子节点实现，基准图作为最底参考层。
>
> **九宫格导出**：Button 底板图与 Panel 纹理底板在导出时生成 `StyleBoxTexture` 子资源，并写入 `nine_patch_stretch`、四边 `margin_*`、`axis_stretch_horizontal/vertical`，与编辑器预览（`build_control` 同样构建 `StyleBoxTexture`）完全一致——实机缩放不变形。纯色面板仍导出为 `StyleBoxFlat`。`load_steps` 按"资源对象数"精确计算（= 1 + 外部资源数 + 子资源数）。
>
> **动画帧导出**：动画帧控件导出为 `TextureRect` 节点 + `AnimatedTexture` 子资源（`frames`/`fps`/`frame_i/texture`），实机运行时自动按帧率循环播放，无需额外节点或脚本——天然"带动态效果的图"。仅 1 帧时退化为普通 `TextureRect`；≥2 帧才生成 `AnimatedTexture`。所有帧纹理作为 `ext_resource` 引用，零悬空。
>
> **精灵表/图集导出**：精灵表控件导出为 `TextureRect` 节点 +（`≥2` 帧时）`AtlasTexture`×N + `AnimatedTexture` 子资源——`AtlasTexture.region` 按精灵表真实像素尺寸切片（`region = Rect2(col*frameW, row*frameH, frameW, frameH)`），避免任何缩放漂移。单帧退化为整图。同一张图只占用 1 个 `ext_resource`，draw call 与体积最优。属性面板「导出 SpriteFrames.tres」还会额外生成 `SpriteFrames` 资源（`animations` 含 `SpriteFrame` 子资源，`AnimatedSprite2D` 可直接消费），实现 UI 与内容双轨输出。

---

## 四、导出 JSON 字段规范说明

导出文件为 UTF-8 JSON，顶层结构如下：

```json
{
  "version": "1.0",
  "generator": "太玄UI编辑器",
  "canvas": {
    "width": 768,
    "height": 1344,
    "background_color": [0.09, 0.11, 0.10, 1.0]
  },
  "reference_image": {
    "path": "res://art/ui_ref/main_menu.png",
    "opacity": 1.0,
    "locked": false,
    "visible": true,
    "fit": "contain"
  },
  "controls": [ /* 见下 */ ]
}
```

### 顶层字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `version` | string | 格式版本，当前固定 `"1.0"` |
| `generator` | string | 生成器标识 `"太玄UI编辑器"` |
| `canvas` | object | 画布信息 |
| `reference_image` | object | 设计基准图信息（可为空配置） |
| `controls` | array | 控件列表，顺序即 Z 轴从底到顶 |

### `canvas`

| 字段 | 类型 | 说明 |
|------|------|------|
| `width` | int | 画布宽（像素） |
| `height` | int | 画布高（像素） |
| `background_color` | [r,g,b,a] | 画布底色，分量 0~1 |

### `reference_image`

| 字段 | 类型 | 说明 |
|------|------|------|
| `path` | string | `res://` 纹理路径，空字符串表示无 |
| `opacity` | float | 透明度 0~1 |
| `locked` | bool | 是否锁定（状态标记） |
| `visible` | bool | 是否显示 |
| `fit` | string | `contain` / `cover` / `origin` |

### `controls[]`（每个控件通用字段）

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | string | `TextureRect` / `Label` / `Button` / `Panel` / `AnimatedTexture` / `SpriteSheet` |
| `name` | string | 控件名称（建议唯一，将映射为节点名） |
| `position` | [x, y] | 绝对坐标（像素，相对画布左上角） |
| `size` | [w, h] | 绝对尺寸（像素） |
| `min_size` | [w, h] | 最小尺寸（像素，防裁剪） |
| `z_index` | int | Z 层级（越大越靠上） |
| `anchor_preset` | int | 锚点预设（默认 0 = 左上，绝对布局） |
| `style` | object | 类型相关样式（见下表） |

### `style` 按 `type` 区分

**Label（文字控件）**
| 字段 | 类型 | 说明 |
|------|------|------|
| `text` | string | 文字内容 |
| `font_size` | int | 字号 |
| `color` | [r,g,b,a] | 字色 |
| `horizontal_alignment` | int | 0=左 1=居中 2=右 |
| `vertical_alignment` | int | 0=上 1=居中 2=下 |
| `font_path` | string | `res://` 字体路径，空=默认字体 |

**TextureRect（图片控件）**
| 字段 | 类型 | 说明 |
|------|------|------|
| `texture_path` | string | `res://` 纹理路径 |
| `modulate_alpha` | float | 整体透明度 0~1 |
| `stretch_mode` | int | 0 缩放填充 / 1 平铺 / 2 保持 / 3 居中保持 / 4 保持比例 / 5 居中比例 / 6 覆盖比例 |

**Button（按钮控件）**
| 字段 | 类型 | 说明 |
|------|------|------|
| `button_text` | string | 按钮文字 |
| `icon_path` | string | `res://` 图标纹理路径 |
| `bg_path` | string | `res://` 底板图路径（九宫格 StyleBoxTexture） |
| `font_path` | string | `res://` 字体路径，空=项目默认字体（见下） |
| `font_size` | int | 字号 |
| `color` | [r,g,b,a] | 字色 |
| `bg_nine_patch` | bool | 底板图是否九宫格缩放（默认 true） |
| `bg_margin_left/Top/Right/Bottom` | int | 底板图四边“不动区”厚度（像素），缩放时四角与边缘保持原样 |
| `bg_axis_h` | int | 横向缩放轴模式：0=拉伸 1=平铺 2=平铺适配 |
| `bg_axis_v` | int | 纵向缩放轴模式：同上 |

> **九宫格（nine-patch）**：设置 `bg_path` 后，底板图按 `bg_margin_*` 切分为九个区域——四角与四边保持原始像素不动，仅中间区域随控件尺寸拉伸/平铺。这是 UI 按钮/边框图在任意分辨率下不变形的关键。边距全为 0 时等价于整图拉伸（旧工程向后兼容）。

**Panel（面板控件）**
| 字段 | 类型 | 说明 |
|------|------|------|
| `bg_color` | [r,g,b,a] | 底色（无 `bg_path` 时生效） |
| `border_color` | [r,g,b,a] | 描边色 |
| `border_width` | int | 描边宽度（四边相同） |
| `corner_radius` | int | 圆角半径（四角相同） |
| `bg_path` | string | `res://` 纹理底板路径（可选）；设置后改为九宫格纹理面板，覆盖纯色底色 |
| `bg_nine_patch` | bool | 纹理底板是否九宫格（默认 true） |
| `bg_margin_left/Top/Right/Bottom` | int | 纹理底板四边不动区厚度（像素） |
| `bg_axis_h` | int | 横向缩放轴模式：0=拉伸 1=平铺 2=平铺适配 |
| `bg_axis_v` | int | 纵向缩放轴模式：同上 |

**AnimatedTexture（动画帧控件）**
| 字段 | 类型 | 说明 |
|------|------|------|
| `frames` | array[string] | 帧纹理路径列表（`res://`），按数组顺序循环播放 |
| `fps` | float | 帧率（每秒帧数），默认 8.0 |
| `loop` | bool | 是否循环（AnimatedTexture 运行时始终循环，字段保留语义/后续扩展） |
| `stretch_mode` | int | 同 TextureRect：0 缩放填充 / 1 平铺 / 2 保持 / 3 居中保持 / 4 保持比例 / 5 居中比例 / 6 覆盖比例 |
| `modulate_alpha` | float | 整体透明度 0~1 |

> 动画帧用于弟子立绘、过场动画、任何"带动态效果的图"。编辑器内用 `AnimatedTexture` 实例化预览（引擎运行时会自动播放）；导出后实机零偏差自动循环。

**SpriteSheet（精灵表/图集控件）**
| 字段 | 类型 | 说明 |
|------|------|------|
| `sheet_path` | string | `res://` 精灵表（图集）图片路径，一张图内含网格排列的多帧 |
| `hframes` | int | 横向切片数（列数），默认 4 |
| `vframes` | int | 纵向切片数（行数），默认 4 |
| `frame_count` | int | 实际帧数（0 = 使用 `hframes*vframes`；用于非满格表，如 4×4 只取前 12 帧） |
| `fps` | float | 帧率，默认 8.0 |
| `loop` | bool | 是否循环（编辑语义保留，AnimatedTexture 运行时始终循环） |
| `stretch_mode` | int | 同 TextureRect |
| `modulate_alpha` | float | 整体透明度 0~1 |

> 精灵表专为"大量小帧合并在一张图"优化——相比动画帧（每帧一张图），它**只引用一张图 + 网格坐标**，体积与 draw call 更优，适合弟子战斗帧、特效序列。编辑器内按 `hframes*vframes` 网格切出 `AtlasTexture` 帧并组 `AnimatedTexture` 预览自动播放；导出 `.tscn` 时生成 `AtlasTexture` + `AnimatedTexture` 子资源（`region` 按图片真实像素切片，与预览完全一致）。属性面板还有「导出 SpriteFrames.tres」按钮，一键生成可直接挂到 `AnimatedSprite2D` 的 `SpriteFrames` 资源，用于纯内容（非 UI）场景。

> **真实字体预览（项目默认字体）**：编辑器首次打开会自动识别工程 `res://art/fonts/`（或 `res://art/_references/fonts/`）下的字体文件并设为"默认字体"；所有 Label/Button 在自身 `font_path` 为空时统一回退到该字体渲染预览，**所见即游戏字体**。工具栏「字体 → 选择字体」可手动指定任意 `res://` 字体，「清除」恢复 Godot 默认字体。该设置随工程文件（`.taixuan_ui`）一并保存，并作为 `doc.default_font` 写入导出 `.tscn` 的 `theme_override_fonts/font`，保证实机文字与编辑器预览一致。

> 字段命名统一、结构稳定，可直接由脚本/AI 解析为目标 `.tscn`：
> - `type` → 对应节点类型
> - `position`/`size`/`min_size`/`z_index`/`anchor_preset` → `Control` 基础属性
> - `style` 各字段 → 对应 `theme_override_*` / `texture` / `modulate` 等
> - 资源路径统一为 `res://`，可直接 `load()`

---

## 五、技术约束与注意事项

- 纯 GDScript，Godot 4.7 原生，无第三方依赖。
- 所有资源路径使用 `res://` 相对路径，与工程目录对齐。
- 所有“可调参数 / 默认值”集中在各脚本 **顶部常量区**（`data_manager.gd` 的 `DEFAULT_CANVAS_W/H`、`ui_editor.gd` 的 `ZOOM_*` / `GRID_DEFAULT` / `BG_DEFAULT` 等），便于统一调整。
- 工程文件 `.taixuan_ui` = 规范文档 + `editor` 临时态（网格/缩放/平移），与导出 JSON 共用同一套数据模型，保证“保存即所见、导出即规范”。
- 已知限制：本编辑器专注于 UI 布局与样式可视化；复杂交互逻辑需导出后在目标场景脚本中补充。

## 六、全自动资源管线（0 干预）

插件负责「手动可视化编辑」，而 **`tools/auto_ui/`** 负责「AI / 脚本全自动」路径——无需点一下，直接把工作空间里的美术资源变成 Godot 可导入场景：

- `tools/auto_ui/taixuan_tscn.py` —— 与 `data_manager.gd::export_tscn` 一一对应的纯 Python 镜像（含九宫格、AnimatedTexture、AtlasTexture 精灵表切片、SpriteFrames.tres）。
- `tools/auto_ui/auto_asset_pipeline.py` —— 扫描美术资源 → 自动分类（背景/面板/按钮/头像框/立绘/精灵表）→ 清洗命名为 `res://art/auto_ui/` → 自动布局生成 `main_menu.tscn`/`disciple_portrait.tscn` → 生成 `config/auto_ui_manifest.json` 游戏清单。带 `--self-test` 验证精灵表切片。
- `res://auto_ui_loader.gd`（`class_name AutoUI`）—— 游戏侧加载器，`AutoUI.load_manifest()` / `AutoUI.instance_scene()` 直接把自动生成的场景实例化进游戏，实现「资源 → 0 干预 → 游戏界面/内容」闭环。

> 运行：`python tools/auto_ui/auto_asset_pipeline.py`（需 Pillow）。生成产物为 LF 换行，规避 Godot Parser Error。

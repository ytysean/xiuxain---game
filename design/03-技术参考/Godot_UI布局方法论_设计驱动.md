# Godot UI 布局方法论：从「猜坐标」到「设计驱动」

> **问题**：每次写完 UI 代码 → F5 → 截图 → 位置/大小全错 → 瞎猜新坐标 → 再 F5 → 还错 → 循环
> **根因**：缺少 **Ardot 设计稿 → Godot 代码** 的系统化坐标映射流程
> **方案**：「设计驱动布局」四步法 + 锚定模式速查表

---

## 一、为什么之前在「猜」？

### 三个坑

| 坑 | 表现 | 正确做法 |
|---|------|----------|
| **`custom_minimum_size` 不是固定尺寸** | 设了 `Vector2(480, 110)` 结果被撑到 300+px | 用 **anchor + offset** 锁定精确尺寸 |
| **坐标来源不统一** | Ardot 画布 480×854、Godot viewport 可能不同、凭记忆估 | 从 **batch_read** 取精确值，用公式换算 |
| **节点父子关系不清** | 节点 A 在父容器 B 内，但用的却是屏幕绝对坐标 | 明确每个坐标是**相对父节点**还是**相对画布** |

### 核心认知

```
Godot Control 尺寸层次（优先级从高到低）：
  1. anchor + offset    ← 唯一能锁定精确像素的方式 ✅
  2. size_flags         ← 容器内自动扩展
  3. custom_minimum_size ← 仅是最小值，可被更大！⚠️
  4. 内容驱动的最小尺寸   ← 文字/子节点撑开
```

---

## 二、「设计驱动布局」四步法

### Step 1：从 Ardot 取精确坐标（唯一数据源）

```gdscript
# 用 mcp__ardot__batch_read 读设计稿关键节点
# fileId = 711346431458529 (宗门页)

# 需要提取的属性：
patterns = [
    {"name": "顶栏_宗门信息", "type": "CONTROL"},     # 2:6 → x,y,w,h
    {"name": "资源栏",      "type": "CONTROL"},     # 2:7 → x,y,w,h
    {"name": "顶部压暗",    "type": "FRAME"},       # 2:3 → 渐变规格
    {"name": "总览把手",    "type": "CONTROL"},     # 11:61 → x,y,w,h
    {"name": "功能把手",    "type": "CONTROL"},     # 11:64 → x,y,w,h
    {"name": "近期动态",    "type": "CONTROL"},     # 2:92 → x,y,w,h
    {"name": "殿阁概况",    "type": "CONTROL"},     # 2:106 → x,y,w,h
]
properties = ["x", "y", "width", "height"]  # 必须取这4个
```

输出示例（Ardot 返回的真实值）：
```
2:6  顶栏_宗门信息  → x=0, y=0,   w=480, h=46
2:7  资源栏        → x=0, y=46,  w=480, h=52
2:3  顶部压暗      → x=0, y=0,   w=480, h=170(渐变区)
11:61 总览把手     → x=0, y=16,  w=34,  h=80  (相对于抽屉层11:55)
11:64 功能把手     → x=0, y=204, w=34,  h=80  (相对于抽屉层11:55)
2:92 近期动态      → x=12,y=704, w=456, h=42
2:106 殿阁概况     → x=12,y=746, w=456, h=42
```

### Step 2：坐标换算（Ardot → Godot）

#### 情况 A：1:1 映射（最常见）

当 Godot viewport == Ardot canvas（本项目：均为 480×854）：

```
Godot坐标 = Ardot坐标 （直接套用，无需换算）
```

#### 情况 B：缩放映射

```
scale_x = Godot_viewport_w / ArdoT_canvas_w   (例: 480/480 = 1.0)
scale_y = Godot_viewport_h / ArdoT_canvas_h   (例: 774/854 = 0.906)

godot_x = ardot_x × scale_x
godot_y = ardot_y × scale_y
godot_w = ardot_w × scale_x
godot_h = ardot_h × scale_y
```

#### 关键：区分「画布绝对坐标」vs「父节点相对坐标」

| 场景 | Ardot 坐标系 | Godot 对应 |
|------|-------------|-----------|
| 顶层节点（直接在 Page 下） | 画布绝对 (0,0) = 左上角 | `_collapsed` FULL_RECT 内的 position |
| 子节点（在某 Container/Frame 内） | 相对于父节点左上角 | 同样相对于 Godot 父节点的 position |
| 抽屉层内的把手 | 相对于抽屉层 (11:55) 的 (0,0) | 需要加上抽屉层的绝对 Y |

**本项目实例**：
- Ardot 抽屉层 `11:55` 的绝对位置 = y=98
- 把手 `11:61` 在抽屉内相对 y=16 → 绝对 y = 98+16 = **114**
- 把手 `11:64` 在抽屉内相对 y=204 → 绝对 y = 98+204 = **302**

### Step 3：选锚定模式（查表，不猜）

#### 模式速查表

| 模式名 | anchor 设置 | offset 设置 | 适用场景 | 代码模板 |
|--------|------------|-------------|---------|----------|
| **FULL_RECT** | L=0,R=1,T=1,B=1 | 全0 | 全屏背景/遮罩层 | `set_anchors_and_offsets_preset(PRESET_FULL_RECT)` |
| **TOP_WIDE** | L=0,R=1,**T=0,B=0** | left=0,right=0,**bottom=H** | 顶栏/固定高度头部 | 见下方代码 |
| **BOTTOM_WIDE** | L=0,R=1,**T=1,B=1** | left=0,right=0,**top=-H** | 底部Tab/固定底部栏 | 见下方代码 |
| **ABSOLUTE** | L=0,T=0,R=0,B=0 | position=(x,y), size=(w,h) | 左把手/浮层按钮 | `position=Vector2(x,y)` + `custom_minimum_size=Vector2(w,h)` |

#### TOP_WIDE 代码模板（顶栏专用）

```gdscript
# 固定高度顶栏 —— 绝不被撑开
var bar: Control = Control.new()
bar.anchor_left = 0.0     # 左边贴父节点左边
bar.anchor_right = 1.0    # 右边贴父节点右边
bar.anchor_top = 0.0      # 上边贴父节点上边
bar.anchor_bottom = 0.0   # ⚠️ 下边也贴上边！= 高度由 offset 决定
bar.offset_left = 0.0
bar.offset_right = 0.0
bar.offset_bottom = float(HEIGHT)  # ← 唯一决定高度的地方
```

#### BOTTOM_WIDE 代码模板（底栏专用）

```gdscript
# 固定高度底栏（如 Tab 栏）
var tab_bar: Control = Control.new()
tab_bar.anchor_left = 0.0
tab_bar.anchor_right = 1.0
tab_bar.anchor_top = 1.0     # ⚠️ 上边贴父节点下边
tab_bar.anchor_bottom = 1.0  # 下边也贴下边
tab_bar.offset_left = 0.0
tab_bar.offset_right = 0.0
tab_bar.offset_top = float(-HEIGHT)  # ← 负数 = 向上延伸
```

### Step 4：验证闭环

```
┌─────────────────────────────────────────────┐
│  batch_read 取坐标                           │
│       ↓                                     │
│  换算 + 选锚定模式 + 写代码                  │
│       ↓                                     │
│  pre_f5_check.py（26/26 绿？）               │
│       ↓ Yes                                 │
│  F5 实机截图                                │
│       ↓                                     │
│  截图 vs Ardot 设计稿 逐元素对比             │
│       ↓                                     │
│  有偏差？→ 回到 Step 1 重读坐标 → 修正      │
│  无偏差？→ ✅ 通过                          │
└─────────────────────────────────────────────┘
```

**对比检查清单**：
- [ ] 顶栏高度是否 = Ardot HEADER_TOTAL (98px)
- [ ] 渐变层高度是否 = Ardot HEADER_FADE_H (110px)
- [ ] 左把手 Y 坐标是否 = Ardot 绝对坐标 (114 / 302)
- [ ] 紧凑行底边距是否贴近 Tab 上方
- [ ] 背景图是否全屏铺开无裁切

---

## 三、本项目已踩坑记录（不要重复踩）

| # | 坑 | 正确写法 | 错误写法 |
|---|---|---------|---------|
| 1 | TextureRect 贴渐变纹理 | `TextureRect` + `.texture` | ❌ `ColorRect` 无 .texture 属性 |
| 2 | 固定高度控件 | `anchor_bottom=0` + `offset_bottom=H` | ❌ `custom_minimum_size` 只是最小值 |
| 3 | 全屏背景图 | 三件套: expand_mode=1 + grow=2,2 + stretch_mode=6 | ❌ 缺任一即错位/平铺/裁切 |
| 4 | Game.get() | 单参数 `Game.get("key")` + null 检查 | ❌ 双参数 `Game.get("key", 0)` 不存在 |
| 5 | 局部变量类型 | 显式 `var x: Type = value` | ❌ `:=` 推断可能 pre_f5 FAIL |
| 6 | Label 文本 | 只能用 `Label.text` | ❌ Label 无 bbcode/text 属性 |
| 7 | 隐藏全局 TopBar 后 | `pc_ctrl.offset_top = 0` | ❌ 不调则顶栏偏下 56px |

---

## 四、快速参考卡（打印贴显示器旁）

```
╔══════════════════════════════════════╗
║  写 UI 前必问自己 3 个问题：          ║
║  ① 这个节点用什么锚定模式？（查表）    ║
║  ② 坐标是从 batch_read 取的还是猜的？ ║
║  ③ 高度是用 offset_bottom 锁了吗？    ║
╚══════════════════════════════════════╝

TOP_WIDE（固定高度头部）:
  anchor: L=0 R=1 T=0 B=0
  offset: bottom = 高度px

BOTTOM_WIDE（固定高度底部）:
  anchor: L=0 R=1 T=1 B=1
  offset: top = -高度px

ABSOLUTE（绝对定位）:
  position = Vector2(x, y)
  custom_minimum_size = Vector2(w, h)

FULL_RECT（全屏）:
  set_anchors_and_offsets_preset(PRESET_FULL_RECT)

禁止: custom_minimum_size 当固定尺寸用！
```

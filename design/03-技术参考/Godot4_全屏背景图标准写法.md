# Godot 4 全屏背景图标准写法（TextureRect KEEP_ASPECT_COVERED）

> **适用场景**：宗门页 / 任何需要全屏铺开背景图的页面
> **验证状态**：✅ 实机 F5 通过（2026-08-05）
> **参考来源**：之前团队做的 `ui/宗门首页.tscn`（424行完整版，已验证正确显示）

---

## 一、标准 .tscn 写法（5 行关键属性）

```tscn
[node name="BG" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2          # ← 关键①：双向跟随父容器宽
grow_vertical = 2            # ← 关键②：双向跟随父容器高
mouse_filter = 2
z_index = -100
expand_mode = 1              # ← 关键③：EXPAND_IGNORE_SIZE（解除纹理原始尺寸锁）
stretch_mode = 6             # ← 关键④：KEEP_ASPECT_COVERED（等比缩放铺满不变形）
texture = ExtResource("X_bg") # ← 你的背景图资源
```

### 属性详解

| 属性 | 值 | 含义 | 缺失后果 |
|------|-----|------|---------|
| `layout_mode` | `1` | 使用容器锚定布局 | 节点不跟随父容器 |
| `anchors_preset` | `15` | FULL_RECT 四角锚定 | 无法全屏 |
| `grow_horizontal` | `2` | 双向生长（SHRINK_END + GROW_BOTH） | 宽度不跟随容器 |
| `grow_vertical` | `2` | 双向生长 | 高度不跟随容器 |
| **`expand_mode`** | **`1`** | **EXPAND_IGNORE_SIZE** | **❌ 致命：纹理被原始尺寸撑爆，锚定全失效** |
| **`stretch_mode`** | **`6`** | **KEEP_ASPECT_COVERED** | **❌ 错误值会导致平铺/裁切/变形** |

---

## 二、.gd 双重保险代码（_ready() 里强制设置）

```gdscript
func _ready() -> void:
    # 确保 BG 全屏铺开（对齐宗门首页.tscn 正确写法）
    var bg: TextureRect = get_node_or_null("BG") as TextureRect
    if bg != null:
        bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE      # 解除尺寸锁
        bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 等比铺满
    # ... 其他初始化 ...
```

### 为什么需要双重保险？

- `.tscn` 是声明式配置，可能被编辑器误操作覆盖
- `_ready()` 代码在运行时强制执行，确保无论 tscn 怎么改都能正确显示
- 两处同时写 = 防御性编程

---

## 三、常见错误对照表

| 错误写法 | 症状 | 正确写法 |
|---------|------|---------|
| `stretch_mode = 1` (STRETCH_TILE) | 背景图平铺重复 / 只显示局部 | `stretch_mode = 6` (KEEP_ASPECT_COVERED) |
| **缺 `expand_mode`**（默认 KEEP_SIZE） | 纹理被 960×1708 撑爆，所有锚定/offset 失效，UI 全面错位 | `expand_mode = 1` (EXPAND_IGNORE_SIZE) |
| **缺 `grow_horizontal/vertical`** | 节点不跟随容器 resize | `grow_horizontal = 2; grow_vertical = 2` |
| `STRETCH_SCALE` (模式1) + 同比例图 | 理论可行但不够健壮，换不同比例图就变形 | `KEEP_ASPECT_COVERED` (模式6) 自动裁切边缘保比例 |

---

## 四、换背景图操作步骤

### 步骤 1：准备新背景图

```
1. 新背景图放入 art/backgrounds/ 目录
2. 推荐尺寸：960 × 1708（与画布 480×854 同比例 ≈0.562）
3. 格式：PNG（支持透明底）/ JPEG（文件更小）
4. 命名规范：home_bg_xxx.png
```

### 步骤 2：修改 .tscn

```tscn
# 方法 A：直接改资源路径（推荐）
[ext_resource type="Texture2D" path="res://art/backgrounds/你的新背景.png" id="2_bg"]

# 方法 B：运行时动态切换（见步骤3）
```

### 步骤 3：运行时动态切换（幻形换肤）

```gdscript
## 切换背景图函数
func set_background_texture(tex_path: String) -> void:
    var bg: TextureRect = get_node_or_null("BG") as TextureRect
    if bg == null:
        return
    var tex: Texture2D = load(tex_path) as Texture2D
    if tex == null:
        push_error("背景图加载失败: " + tex_path)
        return
    bg.texture = tex
    # 强制重置属性确保不变形
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

## 示例调用
set_background_texture("res://art/backgrounds/home_bg_season_spring.png")
```

### 步骤 4：验证清单

- [ ] 背景图完整铺开（顶部天空 + 主体 + 底部云海都可见）
- [ ] 无平铺重复、无局部放大、无拉伸变形
- [ ] UI 元素位置正常（不被背景图撑偏）
- [ ] 不同分辨率/窗口尺寸下仍正确（KEEP_ASPECT_COVERED 自动适配）

---

## 五、完整可复制模板

### 最小可用 .tscn 片段

```tscn
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/your_page.gd" id="1_sh"]
[ext_resource type="Texture2D" path="res://art/backgrounds/你的背景.png" id="2_bg"]

[node name="YourPage" type="Control"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_sh")

[node name="BG" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
z_index = -100
expand_mode = 1
stretch_mode = 6
texture = ExtResource("2_bg")
```

### 配套 .gd _ready() 片段

```gdscript
extends Control

func _ready() -> void:
    var bg: TextureRect = get_node_or_null("BG") as TextureRect
    if bg != null:
        bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    # ... 后续 UI 构建逻辑 ...
```

---

## 六、踩坑记录（2026-08-05 实战）

| 时间 | 错误 | 修复 | 耗时 |
|------|------|------|------|
| 09:15 | `stretch_mode=1`(STRETCH_TILE) → 背景平铺/局部放大 | 改为 `6`(KEEP_ASPECT_COVERED) | 10min |
| 09:19 | 改后还是错位 | 发现缺 `expand_mode=1`，纹理原始尺寸撑爆锚定 | 20min |
| 09:23 | 搜索项目找到 `宗门首页.tscn` 正确版本 | 对齐三件套：`expand_mode=1` + `grow=2,2` + `stretch_mode=6` | 5min |
| 09:32 | ✅ 实机 F5 通过 | 背景完整铺开，UI 不错位 | — |

**核心教训**：Godot 4 的 TextureRect 默认 `expand_mode=KEEP_SIZE`，会强制节点保持纹理原始尺寸（如 960×1708），导致所有锚定和 offset 计算基于错误的节点尺寸。**必须显式设 `EXPAND_IGNORE_SIZE`**。

---

*文档维护：UI Designer · 2026-08-05 · 基于 sect_home_page.tscn/gd 实机验证*

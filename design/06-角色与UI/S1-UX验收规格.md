---
doc_id: s1_ux_acceptance_spec
doc_title: 《太玄宗门录》S1 UI 重构 · 全页面 UX 验收规格（五页 wireframe + 信号契约）
doc_version: v1.0
update_date: 2026-07-28
based_on:
  - design/06-角色与UI/UI交互规范_古风经营A版_V1.0.md（§2 栅格 / §2.2 垂直分区 / §2.3 字体层级 / §4 交互反馈 / §5 导航 / §7 决策基线）
  - 地基代码 ui_theme.gd / ui/*.gd（提交 4b720be，engineering-lead 落地）
scope: UX / 文档层落地；零战斗 / 数值 / 玩法触碰。所有样式走 UITheme，禁止硬编码颜色/尺寸。
---

# 《太玄宗门录》S1 UI 重构 · 全页面 UX 验收规格（五页 wireframe + 信号契约）

## 0. 全局基线（对齐 §2 / §7）
- 基准分辨率 480×854（竖屏）；最小栅格 8px，所有边距/尺寸/间距为 8 的整数倍。
- 主题全部收敛至 `ui_theme.gd`（Autoload "UITheme"）：业务 UI 仅调用统一接口，组件内禁止硬编码颜色/尺寸。
- UITheme 关键常量：GRID=8 / MARGIN=16 / OVERVIEW_H=120 / CORE_GRID_H=240 / TAB_H=64 / TOPBAR_H=48 / BTN_H_PRIMARY=64 / BTN_H_SECONDARY=48 / FONT_TITLE=24 / FONT_VALUE=18 / FONT_BODY=16 / FONT_AUX=12。
- 5-Tab 导航（§7.1，权威）：宗门 / 弟子 / 建筑 / 历练 / 纪事（与 `ui/bottom_tab_bar.gd` TABS 一致）。
- 字体层级（§2.3）：一级标题 24 暗金 / 核心数值 18 亮金（异常暗红）/ 正文 16 浅米 / 辅助 12 浅灰。
- 信息层级铁律（§5）：P0 首屏常驻最高权重；P1 默认精简；P2 收纳二级。所有一级页复用「TopBar + 内容区 + BottomTabBar」骨架，仅替换内容区。

## 1. 信号契约总表（组件 ↔ 宿主）
| 组件 | 信号 / 接口 | 方向 | 契约 |
|---|---|---|---|
| BottomTabBar | `tab_selected(tab_id: String)` | → 宿主 | 点击 Tab 发出；宿主按 tab_id 切换内容区 |
| TopBar | `time_advance_requested` | → 宿主 | 点「推演时日」发出；宿主推进时间（玩法侧，不碰战斗） |
| TopBar | `set_time / set_sect_level / set_level_progress / set_resource(slot, value, abnormal)` | 宿主 → | 宿主从 Game 只读拉取后推送；abnormal→暗红 |
| CoreActionGrid | `action_requested(action_id: String)` | → 宿主 | 点宫格按钮发出；action_id ∈ {建筑,坊市,修炼,洞府,任务,账册} |
| ActionButton | `pressed(action_id: String)` | 内部 | grid 内转发为 action_requested |
| CollapsibleCategory | `toggled(open: bool)` | → 宿主 | 点标题发出；宿主可首次展开时懒加载内容（add_content） |
| SectHomePage | `refresh_overview()` (public) | 宿主 → | 推演/结算后宿主调用，刷新 4 字段 + 状态标签（只读 Game） |

## 2. 宗门页（§7.1 首页锚点）— 详细 wireframe
```
┌──────────────────────────────────┐ 48dp  TopBar（固定顶部）
│ 时辰·—  宗门Lv?  ▓▓  灵石 灵气 弟子 [推演时日] │ ← set_time/set_sect_level/set_level_progress/set_resource×3 + 推演时日→time_advance_requested
├──────────────────────────────────┤
│ 经营概览                  [宗门安定]│ 120dp OverviewPlaceholder（§2.2）
│ 月产出↑   月消耗   在岗弟子   繁荣度 │   4 列：caption(aux12) + value(value18) + trend(aux12)
├──────────────────────────────────┤
│ [ 建筑 ]   [ 坊市 ]   [ 修炼 ]    │ 240dp CoreActionGrid（上排 3 大按钮 64dp）
│ [ 洞府 ]   [ 任务 ]   [ 账册 ]    │       （下排 3 小按钮 48dp）action_requested
├──────────────────────────────────┤
│ ▸ 凡世香火                      │ 折叠次功能区（ScrollContainer，剩余高）
│ ▸ 宗门规制                      │   3× CollapsibleCategory（默认折叠）+ BeastSlot
│ ▸ 道统传承                      │
│ [ 御兽占位槽 · 非宫格模块 ]      │   BeastSlot（御兽落点，归「宗门规制」分类）
└──────────────────────────────────┘
│ 宗门 │ 弟子 │ 建筑 │ 历练 │ 纪事 │ 64dp BottomTabBar（固定底部）tab_selected
```

- 尺寸/边距（对齐 §2.2）：TopBar 48 / 概览 120（内边距上下12、左右16）/ 宫格 240（上下16、左右16、按钮间距 GRID+4=12）/ 次功能区 左右16、模块间距16 / 底Tab 64（无额外边距）。全局安全边距 左右16。
- 信息层级：概览与宫格为 P0 首屏常驻；次功能区为 P1/P2 默认折叠；御兽占位为 P2 收纳。
- 概览面板字段（裁决#4）：月产出（配 ↑/↓ 环比细箭头）/ 月消耗 / 在岗弟子 / 繁荣度；右上角状态标签：宗门安定（暗金）/ 财政吃紧（暗红，入不敷出）/ 人手短缺（暗红，人手不足）。
- 数据契约（只读 Game，不编造玩法）：月产出=`Game.预估月产出()`；繁荣度=`Game.繁荣`；在岗弟子=`Game.弟子列表.size()`；月消耗 & 上月产出（环比）玩法侧暂未暴露公开访问器 → 占位「—」+ 预留信号。异常（负/短缺）→ 暗红（`UITheme.apply_value_font(lbl, abnormal)` / `color_value`）。

## 3. 弟子页（§7.1 高频核心）
- 结构：TopBar + 内容区 + BottomTabBar。
- P0 内容区（首屏）：弟子列表（总战力 + 排序）+ 接引决策区（待抉择并入，原 `抉择区`）。
- 信号：点弟子 → 详情弹窗（二级页：保留 TopBar，底部替换为「返回」+ 标题）；共享 TopBar.set_resource 推送在岗弟子数。
- 验收：信息去重（不在 TopBar 重复列弟子数）；触摸目标 ≥ 44×44（§6 旧预算）。

## 4. 建筑页（§7.1 核心经营）
- P0 内容区：建筑总览 + 建造/升级入口（与宫格「建筑」二级入口同源，不重复）。
- 信号：建造/升级按钮 → 玩法侧（只读 UI 触发）；时间推进仍走 TopBar 推演时日。

## 5. 历练页（§7.1 玩法探索）
- P0 内容区：历练派发 + 进度。
- 灰锁：🔒 Lv.3 或 FTUE 完成（与 legacy `_功能解锁("历练")` 一致），置灰可显（disabled + 🔒 + tooltip），不隐藏。

## 6. 纪事页（§7.1 辅助信息）
- P0 内容区：纪事分类浏览（大事件/岁纪/庶务/异闻），配合 `宗门纪事` 数据。
- 常开，无灰锁。

## 7. 推演（不入 Tab）
- 落点：TopBar 最右「推演时日」常驻按钮（§7.1 / §7.4）→ `time_advance_requested`；全页面可见，不占 Tab 名额。

## 8. 导航冲突收敛（交付 E · 权威基线）
- 旧文档 `信息架构与导航硬性约束.md` 为旧 9 页扁平架构（御兽/坊市/任务/推演 独立一级页），其 §2 页面树与本规范 §7 的 5-Tab 冲突。该旧文档首部已标注「架构已作废（2026-07-24 最终定夺）」，但 §2 页面树未同步，存在分歧。
- **权威基线 = 本规范 §7 / §5.2 的 5-Tab（宗门/弟子/建筑/历练/纪事）**。落点收敛：
  - 坊市、任务 → 宗门页核心宫格（二级入口），全规范对齐，无独立一级入口（裁决#2）。
  - 御兽 → 宗门页次功能收纳区（sect_home_page BeastSlot 占位槽），不进核心宫格；归属折叠分类 = 「宗门规制」（或 S1 后续新增「御兽」分类）（裁决#3）。
  - 推演 → 顶部状态栏最右常驻「推演时日」按钮，不占 Tab 名额（§7.4）。
- 旧 9 页文档**需后续修订**（移除 §2 九页树 / 对齐 5-Tab），不在本次改动范围；本规格（D）+ 规范文档 §7.5 为权威基线。

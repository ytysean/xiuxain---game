# 《太玄宗门录》P1 二级详情页（弟子 / 建筑）QA 报告

> 质量负责人：严守真（quality-lead）｜ 日期：2026-07-29 ｜ 引擎：Godot 4.7 · 竖屏 480×854
> 范围：建筑详情页从零实现（`ui/page_building.gd`）+ 弟子详情页 P1 品质升级（`ui/page_disciple.gd`）
> 依据（已 Read 核实）：上述两文件、设计规格 `P1-二级详情页设计规格.md`、`pre_f5_check.py`、`ui_theme.gd`/`ui_theme_config.gd`/`ui_tween.gd`、`item.gd`、`components/ItemSlot.gd`
> 性质：本文仅产出 QA 结论与清单，未写/改任何 `.gd` 实现，未 git commit。质量门为**建议性门控**，最终放行由用户决定。

---

## 0. 结论速览（Executive Summary）

| 维度 | 判定 | 阻塞项 |
|---|---|---|
| 设计评审 | **PASS**（附 2 项低风险 CONCERN） | 无 |
| 架构评审 | **PASS** | 无 |
| 静态门控（pre_f5 26 闸） | **PASS**（引用结论，未重跑） | 无 |
| 烟雾测试 | **已交付清单 21 条，待真机 F5 执行**（QA 环境无 Godot runtime，未运行） | 无 |

> 总判定：**PASS（有条件）**——无阻塞项，可进入真机 F5 烟雾测试；2 项为已知低风险缺口，建议 P2 收口（见 §1.1 / §4）。

---

## 1. 质量门判定

### 1.1 设计评审 —— PASS（2 项 CONCERN）

逐条对照设计规格验收点（表 1 = §2.2 建筑字段映射；表 2 = §3.1 弟子 section；表 3 = §3.4 红点）：

| 规格条目 | 实现位置 | 核对 | 备注 |
|---|---|---|---|
| 建筑 §2.1 布局（ListRoot/DetailRoot 显隐同构） | `_build_detail_root` L280-309、`_show_detail` L311-317 | ✅ | 与 `page_disciple` 完全同构；`fade_in` 淡入 |
| 建筑 §2.2 字段映射 | `_populate_building_detail` L325-383 | ✅ | 头部/产出/升级/人员/被动 字段齐全；`预估月产出`(L349 `Game.预估建筑产出`)、`等级乘区`(L352 派生) 按规格 |
| 建筑 §2.3 交互 | `_on_hall_gui_input` L267-272 → `建筑详情请求.emit` → `_show_detail`；`_on_back_pressed` L319-323 | ✅ | 进/出仅 emit 占位信号 |
| 建筑 §2.4 升级进度条 | `_build_upgrade_bar` L456-478 | ✅ | `ratio = 等级/上限` 派生（P1 临时，规格已确认）；达上限 `disabled`「已达上限」 |
| 建筑 §2.4/§3.4 升级入口「暗金红点角标」 | `_build_upgrade_button` L480-493 | ⚠️ **CONCERN-C1** | 仅做 `disabled`/「修葺升级」文案 + primary 样式，**未渲染 §3.4 规定的升级暗金红点角标** |
| 建筑 附录 B 信号 `建筑开关请求` | signal L10 `(key,开启)`；emit L561-562 `(key,开启)` | ⚠️ **CONCERN-C2** | 规格附录 B 记为 `(key:String, 项:String, 值:bool)`、§2.3 记 `emit(key,"负责人锁定",val)`；实现简化为 `(key,开启)`。**功能正确，但信号契约与文档不符，业务层接线须对齐实现签名** |
| 弟子 §3.1 六 section 收口 + 装备 section | `_add_section` L555-572、`_add_equip_section` L574-613 | ✅ | 统一 flat 面板 + 标题红点 + KV 行；装备 9 槽 Grid |
| 弟子 §3.2 进度条（4 条） | `_make_progress` L640-676；调用 L506-510 | ✅ | 修炼(金)/打磨(绿)/丹毒(>0.5 变红)/道心(恒空灰)，取值与配色按规格 |
| 弟子 §3.3 动效 | `_show_detail` L305 `fade_in`；`_on_btn_press` L707-709 `button_press` | ✅ | 全部走 `UITween`，无页面内手搓 Tween |
| 弟子 §3.4 红点（突破/互动/状态/装备） | L432-441 判定 + `_make_red_dot` L627-637 | ✅ | 突破→danger 红点；互动(有抉择)→任职区暗金点；丹毒≥0.5/冷却>0→值 danger 红；装备<9 槽→暗金点（注：状态警示以「字段值 danger 红」呈现，符合规格「显示位置=字段值」） |

**结论**：结构、字段、进度条、动效、红点四项核心验收全部对齐规格；仅余 C1（建筑升级红点视觉缺漏）与 C2（信号签名文档漂移）两项低风险已知项，不阻塞门控。

### 1.2 架构评审 —— PASS

- **红线：UI 层零 GameState 写入**（Grep 实证见 §2.2）——两文件所有 `Game.` 用法均为只读（`.get` / `.has_method` / 方法调用 `预估建筑产出` / `取弟子纪事` / `_建筑等级上限`），无任何 `Game.x =` 赋值，所有交互仅 `emit` 占位信号。
- **信号契约**：建筑新增 `建筑任免请求`/`建筑开关请求`/`建筑详情返回`（L9-11）；弟子新增 `弟子装备查看请求`（L26）。与附录 B 基本一致（C2 偏差见上）。
- **API 存在性（防 F5 崩溃）**：逐一核实被调用符号均真实存在——
  - `UITheme`：`MARGIN/GRID/SIZE_SM/RADIUS_BUTTON/BTN_H_PRIMARY/BTN_H_SECONDARY/COLOR_BG_CONTENT/COLOR_TEXT_GOLD/COLOR_TEXT_RED/COLOR_TEXT_AUX/COLOR_STATUS_SUCCESS` + `apply_title_font/apply_aux_font/apply_body_font/apply_value_font/apply_primary_button_style/apply_secondary_button_style/apply_panel_style/make_panel_stylebox/make_divider_control/load_icon_sized`（ui_theme.gd L11-327）——**全部命中**。
  - `UIThemeConfig`：`get_quality_color/get_realm_color/get_state_color`（ui_theme_config.gd L71-77）——**全部命中**。
  - `UITween`：`fade_in(node,dur=0.2)`、`button_press(btn)`（ui_tween.gd L7/16）——**命中**。
  - `ItemSlot.set_item(id,count,q)`（components/ItemSlot.gd L48）——签名与调用 `slot.set_item(名,1,stem)` 一致。
- **装备数据契约**：`item.gd` 确认 `品阶` 域 = 凡阶/灵阶/宝阶/王阶/圣阶/仙阶/道阶（L19），`Item` 含 `名称`(L155)、`穿戴位`(L153)；页内 `_EQUIP_SLOT_KEYS`(L59) 与 item.gd `槽显示`(L28) 完全一致，装备 Dict 穿戴位→Item 结构成立（详见 §4 R4）。

### 1.3 烟雾测试 —— 待真机 F5

QA 环境无 Godot 运行时，无法在本环境执行真机点击；§3 交付 **21 条 Smoke Test Cases** 供主理人/用户真机 F5 逐条勾验。判定为「清单已交付、待执行」，不构成门控 FAIL。

---

## 2. 静态证据

### 2.1 pre_f5 26 闸全绿（引用结论，未重跑）

依据主理人提供的结论 `pre_f5_check.py` 已跑过 **26 闸全绿（PASS）**。与本任务强相关的闸门定义（引自 `pre_f5_check.py` 源码，供审计）：

| 闸门 | 名称 | 与本任务关系 |
|---|---|---|
| 闸门 8 | GDScript 静态扫描（`static_check.py`） | 拦孤立缩进/class body 裸语句/跨作用域引用——覆盖两页结构正确性 |
| 闸门 9 | GDScript 语法解析（gdtoolkit 真 parser） | 拦缩进错位/lambda 提前结束等语法灾难 |
| 闸门 10 | GDScript 类型名存在性扫描（`gdscript_type_resolve.py`） | 拦注解里不存在的类型名 |
| 闸门 24 | **零战斗触碰红线校验**（`check_zero_battle_touch`，L561-581） | `git diff HEAD` 比对 `BattleCalculator.gd`/`BattleManager.gd` 无改动——本任务 P1 二级详情页改动不涉及战斗结算 |

> 结论引用：26 闸全绿，含闸门 24 零战斗触碰绿。本次 QA 不重跑 pre_f5，仅在其上叠加针对两文件的定向 Grep 复核（§2.2）。

### 2.2 零战斗触碰红线 + 零 GameState 写入（Grep 实证）

**① 战斗触碰（0 命中）**——对两文件执行 `BattleManager|战斗|伤害|BattleCalculator`：

```
ui/page_disciple.gd  → 0 matches
ui/page_building.gd  → 0 matches
```

**② GameState 写入（0 处赋值）**——对两文件执行 `Game\.`：

- `page_disciple.gd`：L235/L321/L439 `Game.get(...)`；L531 `Game.has_method`；L533 `Game.取弟子纪事(...)`（只读方法调用）。**无任何 `Game.x =`**。
- `page_building.gd`：L150/L162/L177/L334 `Game.get(...)`；L349 `Game.has_method`；L350 `Game.预估建筑产出(key)`；L565 `Game.has_method`；L566 `Game._建筑等级上限()`（只读方法调用）。**无任何 `Game.x =`**。

**③ 信号均为 emit（占位）**——两文件所有交互回调（`_on_升级_pressed`/`_on_任免_pressed`/`_on_lock_toggled`/`_on_equip_clicked`/`_on_disciple_item_selected`/`_on_back_pressed` 等）仅 `emit` 信号，无状态写入。

> 实证结论：两页严守「UI 层零 GameState 写入、零战斗触碰」红线。

---

## 3. 烟雾测试清单（Smoke Test Cases）

> 用法：真机 F5 后，进入「弟子」与「建筑」两页，按用例逐条操作；每条记录「实际结果」并对照「通过标准」。出现任意 FAIL 即回传主理人。

### 3.1 建筑详情页（BD，9 条）

| 用例ID | 操作步骤 | 预期 | 通过标准 |
|---|---|---|---|
| BD-01 | 建筑列表点任一堂口行 | 切入二级详情，列表隐藏、详情显示，`fade_in` 淡入，头部字段出现 | 不崩；`_detail_root.visible=true` 且 `_list_root.visible=false`；见「名称/职能/等级/加成」 |
| BD-02 | 查看二级详情各区块 | 头部/产出信息/升级操作/人员管理/被动效果 全部渲染 | 各区块标题与字段齐全；无空白面板异常 |
| BD-03 | 观察升级进度条与按钮 | 进度条 `value=等级/上限`，下方「修葺 Lv x / y」；未达上限按钮「修葺升级」可点，达上限「已达上限」disabled | 进度与文案正确；达上限时按钮 `disabled=true` |
| BD-04 | 堂口 entry **有** `负责人锁定(bool)` / **无**该字段 各测一次 | 有则显示「功能开关」区 + 主事锁定 Toggle；无则整区隐藏 | 条件显示正确，不崩 |
| BD-05 | 点「修葺升级」「任免主事」「主事锁定」Toggle | 仅触发占位信号（接日志/监听验证），Game 状态无变化 | 进入前后 `Game.堂口列表[key]` 不变；信号有 emit |
| BD-06 | 点「← 返回」与底部「返回列表」 | 切回列表视图，`emit 建筑详情返回` | 详情隐藏、列表显示；不崩 |
| BD-07 | 复核升级按钮暗金红点（已知缺口 C1） | 规格要求 等级<上限 时按钮右上角暗金点；**当前实现未渲染** | 预期应有红点→实际无 → 记为 KNOWN GAP，不判 FAIL（见 §4 R1） |
| BD-08 | 空列表 / 堂口 entry 缺字段（如缺「产出」「政绩」） | 缺字段显示「—」，不崩 | 全部缺字段回落「—」，无 Invalid access |
| BD-09 | 门派等级较低使 `_建筑等级上限()` 取小值 | 等级达真实上限即禁用升级；兜底常量 10 仅在无方法时生效 | 上限取 `min(门派等级,7)`；disabled 逻辑正确 |

### 3.2 弟子详情页（DP，10 条）

| 用例ID | 操作步骤 | 预期 | 通过标准 |
|---|---|---|---|
| DP-01 | 弟子列表点任一弟子行 | 切入详情，`fade_in` 淡入；6 section + 装备 section 渲染 | 不崩；`_detail_root.visible=true`、`_list_root.visible=false` |
| DP-02 | 查看各 section 字段 | 基本信息(6)/资质灵根/修炼状态/任职/四维/个人纪事/装备(9槽) 齐全 | 区块与字段无缺失、无空白异常 |
| DP-03 | 观察 4 条进度条 | 修炼(金)/打磨(绿)/丹毒(心魔风险,>0.5 变红)/道心(恒空灰)，百分比正确 | 配色与数值随字段变化；道心恒 0% |
| DP-04 | 点任意按钮（返回/排序/升级等） | `button_press` 按压反馈后触发业务回调 | 有动效；无报错 |
| DP-05 | 构造红点触发数据（突破就绪 / 有待抉择 / 丹毒≥0.5 / 冷却>0 / 装备<9槽） | 突破→section danger 红点；有抉择→任职区暗金点；丹毒/冷却→值 danger 红；装备<9→暗金点 | 四类红点判定与 §3.4 一致 |
| DP-06 | 查看装备 9 槽 | 有装备槽显示「槽位·名称」+ 品阶色；空槽灰显 +「槽位·空」；点槽 emit `弟子装备查看请求` | ItemSlot 渲染正确；空槽 `modulate` 灰；点击仅 emit |
| DP-07 | 资质/命格缺失或存在 | 资质经 `DiscipleData.资质显示`、命格经 `DestinyDataLoader.get_destiny` 解析；缺失 fallback「—」 | 无解析崩溃；缺值显「—」 |
| DP-08 | 点「返回」 | 切回列表，`emit 弟子详情返回` | 详情隐藏、列表显示；不崩 |
| DP-09 | 空数据兜底：待抉择空 / 纪事空 / 装备全空 | 「暂无待抉择」「暂无个人纪事」、9 空槽灰显；不崩 | 全空场景平稳，无 Invalid access |
| DP-10 | 验证装备品阶取色 | 凡阶→fan…道阶→dao 七档取色正确（与 item.gd 七品阶一致） | 各品阶槽位色与 `UIThemeConfig.QUALITY_COLOR` 对应档一致 |

### 3.3 红线 / 通用（CX，2 条）

| 用例ID | 操作步骤 | 预期 | 通过标准 |
|---|---|---|---|
| CX-01 | 在两页执行全部交互前后对比 `Game` 快照 | 无任何 GameState 字段变化 | 交互仅 emit 信号；红线守稳 |
| CX-02 | 静态确认（已做，见 §2.2） | 两页无 `BattleManager/战斗/伤害` 引用 | 0 命中，零战斗触碰 |

---

## 4. 已知风险与缓解

| 编号 | 风险 | 影响 | 缓解 / 建议 |
|---|---|---|---|
| **R1** | **建筑升级红点未实现**（C1，§3.4/§2.4 缺口） | 升级可点态缺暗金点视觉提示，弱提醒降级 | P1 可暂缓放行；P2 由 `RedDotManager` 统一补升级红点；或更新规格删除该视觉项 |
| **R2** | **建筑开关信号签名偏差**（C2） | 业务层若按附录 B `(key,项,值)` 接线会参数错位 | 接线以**实现签名 `(key,开启)`** 为准；或统一改回 `(key,项,值)` 并同步升级两处 |
| **R3** | **丹毒代理心魔 视觉歧义** | 玩家可能将「丹毒」条误读为「心魔值」（真实心魔字段不存在） | 条 label 已注明「丹毒(心魔风险)」+ 0.5 阈值变红；P2 接入真实心魔值后替换 |
| **R4** | **装备 Dict 真实结构依赖** | 装备渲染依赖 `Item.名称/品阶` 与穿戴位 key；若 `item.gd` 改结构会错位 | 已核实 item.gd：`品阶`=七品阶、含 `名称`、穿戴位 key 与 `_EQUIP_SLOT_KEYS` 一致；建议将「装备结构」纳入字段改名护栏 |
| **R5** | **品阶域文档漂移** | 设计规格 §1 误称 `Item.品阶=凡品/良品/上品/极品/天品`，实际 item.gd=凡阶/灵阶/宝阶/王阶/圣阶/仙阶/道阶；实现 `_ITEM_QUALITY_STEM` 与 item.gd **精确匹配（实现正确）** | **实现无误**；建议更新规格 §1 与附录 A「待确认项」，避免后续误判为 bug |
| **R6** | **无全局红点管理器** | 红点用各页本地标记位，P2 接入 `RedDotManager` 时需重构 | 已在 §3.4 立项 P2；本地判定与 `Game` 刷新时机一致，P1 可接受 |
| **R7** | **重定向风险（字段改名）** | 建筑详情读 `Game.get("堂口列表")` + entry 字段经 `_safe_get`；业务层改 `堂口列表` key 或 entry 字段名 → UI 静默回落「—」，掩盖绑定断裂 | 加字段重命名护栏（如 pre_f5 废弃字段扫描扩展）或运行时告警，避免「显式—」掩盖真实断链 |
| **R8** | **修葺进度条为派生值** | `ratio=等级/上限` 非真实「修葺进度」；真实字段上线后须替换 | 规格 §2.2 已列为待确认项；真实 `修葺进度(0~1)` 字段接入后直接替换派生逻辑 |

---

## 5. 待用户审批项

1. **C1（建筑升级红点缺口）**：是否作为 P1 已知项放行？还是要求补实现/改规格？
2. **C2（建筑开关信号签名）**：业务层接线按实现 `(key,开启)` 还是改回规格 `(key,项,值)`？
3. **R5（规格文档漂移）**：是否同步修订设计规格 §1 / 附录 A 的品阶域描述，避免后续误解？
4. **烟雾测试**：请在真机 F5 后按 §3 勾验 21 条；任一 FAIL 回传主理人游承峰。

---

*—— 严守真（quality-lead）｜ 本文档为建议性质量门控结论，最终放行由用户决定。*

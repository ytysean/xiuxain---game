# GDD-详情弹窗扩展 + 富文本点击联动_S1批4

> 版本：S1 批4 v1.0（设计稿，交付工程落地）
> 作者：文策渊（design-strategist）
> 状态：**可落地设计文档 · 纯 UI/渲染层 · 不改动任何战斗结算代码**
> 对接文档：GDD-战斗系统进阶_S1批3.md（批4 边界在 §3.2.5 / §7.2 / 批3-D7）、GDD-弟子阶位轴.md、GDD-建筑等级与任期政绩.md
> 现役代码核实：`main.gd`（L16-62 / L175 / L195 / L1527-1615 / L2093-2122 / L3330-3367 / L3952-4021）、`BattleCalculator.gd`(L281)、`SkillCultivationLoader.gd`(L39)、`game_state.gd`(L51/L203/L254-273)、`beast.gd`(L117-131/L264)、`config/battle_buff.csv`（已 Read 核实）

---

## ① 目标与范围

**本批是「纯 UI/渲染层」扩展**：在批1/2/3 已落地的实体映射与 `ref_*` 字段基础上，把「点不到的实体」变成「点得到、看得到详情」的实体，并安全启用 S1 预埋的对象池。

| 子项 | 本批落地结论 | 回归风险 |
|---|---|---|
| A. 详情弹窗扩展 | `_解析实体` 扩至 8 类；新增 4 个富模板（功法/Buff/建筑/丹药）+ 3 个轻量通用模板（灵兽/奇遇/纪事）；`open_detail` 全分发 | 低 |
| B. 富文本点击联动 | 战斗日志行尾追加 `ref` 链接；纪事 tab 弟子名包成 disciple 链接 | 低 |
| C. `_attr_line_pool` 安全启用 | 新增 `_属性行`/`_关闭详情`/`_回收详情行`，所有关闭路径统一经回收函数 | 低（不改生命周期） |
| D7 模拟跨对 | **本批不做**（仅 UI 层诠释，见 §7） | — |
| mp 数值回填 | **本批不做**（铁律禁改战斗结算代码，见 §8） | — |

**铁律（本批不可逾越）**：严禁写任何 `.gd` 代码、严禁改 `BattleCalculator.gd` / `BattleManager.gd` / `game_state.gd`；不触碰 ADR-003 纯函数边界；只动 `main.gd` 的详情弹窗与富文本渲染层，且 `battle_buff.csv` 仅改备注文本不改数值列。

---

## ② 当前代码事实（引用行号，已核对勿重做）

| 事实 | 位置 | 现状 |
|---|---|---|
| 详情分发骨架 `_解析实体` | `main.gd` L3978 | `match` 仅处理 `disciple`（遍历 `Game.弟子列表` 按 `d.姓名==_id`）、`item/equip`（`Game._物品定义表.get(id)` → `Game._造低阶物品(参[0],参[1])`）；其余返回 `null` |
| 统一分发 `open_detail` | `main.gd` L3999 | `match type`：`item/equip`→`_弹出物品详情`，`disciple`→`_弹出弟子属性弹窗`，否则 `_toast("（暂无详情）")` |
| URL 分发 `open_detail_by_url` | `main.gd` L4017 | `url_str.split(":",false,1)` → `[type,id]` → `open_detail` |
| 对象池（预埋未用） | `main.gd` L175 | `var _attr_line_pool: Array = []` |
| 弹窗外壳 `_new_detail_popup` | `main.gd` L1571 | 返回 `{"遮","内容","关"}`；单实例守卫 `_当前详情遮`（L1574 `queue_free` 旧窗）；内联 `背板.pressed`/`关.pressed`/ESC 三处均 `遮.queue_free()`（L1587/L1602/L1606） |
| 物品详情模板 | `main.gd` L3952 | `_弹出物品详情(物品: Item)`，含 `简介()`+`描述` |
| 弟子属性弹窗 | `main.gd` L1618 | `_弹出弟子属性弹窗(类型,内容文本,_d)` |
| 战斗日志 `构建日志` | `main.gd` L3340-3367 | `链名(名)="[url=disciple:%s]%s[/url]"%[名,名]` 仅把 actor/target 名字包成弟子链接；**未消费 `ref_type/ref_id/ref_name`**；`meta_clicked.connect(open_detail_by_url)`（L3336） |
| 纪事 tab 渲染 | `main.gd` L2093-2122 | `文案.contains("[url=")` → `RichTextLabel` + `meta_clicked`；否则 `Label`；`弟子名` 当前未做成链接（仅作 `【弟子名】` 前缀文本） |
| 批量考核弹窗 | `main.gd` L1527-1566 | 用 `_new_detail_popup`；L1562-1563 直接 `弹["遮"].queue_free()` |
| 颜色常量 | `main.gd` L16-30 | `宣纸亮/墨黑/次墨/暗金/青灰/墨底/朱砂`，及 `墨底半透/面板底`（半透）；bbcode 用 `X.to_html(false)` |
| 背景常量 | `main.gd` L53-55 | `BG_SCENE_ALPHA=0.30`、`BG_OVERLAY_COLOR=Color(0.086,0.133,0.114)=#16221D`、`BG_OVERLAY_ALPHA=0.50` |
| Tab 名常量 | `main.gd` L195 | `const 页名 := ["宗门","弟子","御兽","历练","纪事"]`（5 项） |
| 字号常量 | `main.gd` L57-62 | 唯一集合 `{22,17,18,16,15,13}` |
| Buff 模板（只读） | `BattleCalculator.gd` L281 | `static func _buff模板(buff_id:String)->Dictionary`（镜像 `battle_buff.csv`，**只读调用，勿改**） |
| 功法访问器 | `SkillCultivationLoader.gd` L39 | `static func get_skill(id:String)->Dictionary` |
| 灵兽库存 | `game_state.gd` L51 | `var 灵兽库存: Array[Beast] = []`；`Beast` 字段：`种类名`(L117)/`品阶`(L118)/`等级`(L130)/`等级上限`(L131)/`简介()`(L264)/`beast_type`/`忠诚度` |
| 堂口列表 | `game_state.gd` L203 | `var 堂口列表: Dictionary`；条目含 `名称/等级/政绩/状态/加成维度/负责人/成员`（L254-273 引用证实） |

---

## ③ 落地决策 D1..D7

### D1 · 实体类型 → 弹窗模板映射
- **决策点**：8 类实体各自落到哪个详情模板？
- **推荐默认**：
  - `disciple` → 现有 `_弹出弟子属性弹窗`（不变）
  - `item`/`equip` → 现有 `_弹出物品详情`（不变）
  - `gongfa` → 新增 `_弹出功法详情(id)`
  - `buff` → 新增 `_弹出Buff详情(id)`
  - `building` → 新增 `_弹出建筑详情(key)`
  - `dan_yao` → 新增 `_弹出丹药详情(物品)`
  - `beast` / `encounter` / `chronicle` → **轻量通用详情**（复用 `_new_detail_popup` 外壳 + 字段行，字段表见 §④ 副表）；不在用户原列 4 模板内，仅满足点击联动闭环，不单独做美术化模板
- **替代方案**：为 `beast/encounter/chronicle` 各做独立富模板（与 4 模板同级）
- **采纳默认理由**：用户明确只列 4 个富模板；`beast/encounter/chronicle` 走轻量通用可达成「点得到→看得到」且避免范围膨胀；`_解析实体` 仍全类型支持，将来升级富模板零返工。

### D2 · `open_detail` 分发扩展方式
- **决策点**：如何把 7 个新类型接入 `open_detail`？
- **推荐默认**：在 `open_detail` 的 `match type` 中新增分支：`gongfa/buff/building/beast/encounter/chronicle/dan_yao`；每分支先 `_解析实体(type,id)`，成功调对应模板，失败 `_toast("（暂无详情）")`。保留 `skill` 别名分支（见 D4）。
- **替代方案**：用 `Dictionary[type] = Callable` 映射表
- **采纳默认理由**：`match` 与现有风格（L3999-4014）一致，可读、易审计、降级路径统一；分支少（≤8），字典映射无收益且增加间接层。

### D3 · `_解析实体` 扩展（各类型解析逻辑）
- **决策点**：8 类如何由 `id` 解析到实体？
- **推荐默认**（全部失败返回 `null`，由 `open_detail` 降级）：
  - `disciple`：遍历 `Game.弟子列表`，`d.姓名 == _id`（现有，保留首条匹配）
  - `item`/`equip`：现有 item 路径（`Game._物品定义表.get(id)` → `Game._造低阶物品`）
  - `gongfa`：`SkillCultivationLoader.get_skill(_id)`（空字典→返回 `null` 语义：`get_skill` 未命中返回 `{}`，调用方判 `if g.is_empty(): return null`）
  - `buff`：`BattleCalculator._buff模板(_id)`（只读，未命中返回 `{}`→判空 `null`）
  - `building`：`Game.堂口列表.get(_id)`（Dictionary，未含→`null`）
  - `beast`：遍历 `Game.灵兽库存`，`b.种类名 == _id` 返回 `Beast`
  - `encounter`：遍历 `Game.宗门纪事`，`记.get("名称","") == _id` 返回该 `Dictionary`（首条匹配）
  - `chronicle`：支持两种 `_id` 格式——① `"日:名称"`（`split(":",false,1)` 取日+名称匹配 `记.get("日")` 与 `记.get("名称")`）；② 纯数字 → `Game.宗门纪事[int(_id)]`
  - `dan_yao`：走 item 路径（`Game._物品定义表.get(id)` → `Game._造低阶物品`），返回 `Item`（由 `open_detail` 判 `category=="dan_yao"` 后调 `_弹出丹药详情`）
- **替代方案**：`encounter/chronicle` 仅按索引
- **采纳默认理由**：纪事文本可能以「名称」或「日:名称」引用，双格式更鲁棒；全部 `null` 降级，零崩溃。

### D4 · 战斗日志 `ref_type` 与 `open_detail` 分发集不一致（关键）
- **决策点**：批3 日志 `ref_type ∈ {skill,buff,item}`，但批4 分发集为 `{gongfa,buff,building,beast,encounter,chronicle,dan_yao}`——**缺 `skill`、多 `gongfa`/其余**。批3 的 `cast_skill` 日志 `ref_type="skill"` 点击后该如何？
- **推荐默认**：`open_detail` 显式分发 `gongfa/buff/building/beast/encounter/chronicle/dan_yao` + 现有 `disciple/item/equip`；**额外保留 `"skill"` 别名分支 → 路由到 gongfa 详情**（`SkillCultivationLoader.get_skill(_id)`，解析失败降级 `_toast`）。即：`"skill": _解析实体("gongfa",_id)` 等价调用 `_弹出功法详情`。
- **替代方案**：
  - (a) 完全不处理 `"skill"` → 点 skill 链接触发 `_` 分支 → 恒 toast「暂无详情」（死链，体验差）
  - (b) 新增 `_弹出技能详情(skill.csv)` 独立模板（超本批 4 模板范围；`skill.csv` 字段未为详情 UI 设计）
- **采纳默认理由**：零新增模板、复用 gongfa 详情、降级安全；符合「功法=玩家心智中的技能」叙事统一。**已知代价**：`skill.csv`（`sk_ti_01…`）与 `skill_cultivation.csv`（`sk_001…`）命名空间不通（批3 偏差 A6），真实 `skill_id` 经 `get_skill` 解析失败→toast，属已知限制，待批3 A6 治理。战斗日志拼接时 `ref_type` 原样透传（`skill/buff/item`），映射在 `open_detail` 内完成，**不改批3 日志生成代码**（铁律）。

### D5 · 纪事/奇遇 弟子名 链接化渲染条件
- **决策点**：纪事 tab 何时用 `RichTextLabel` 渲染弟子名链接？
- **推荐默认**：渲染分支条件改为 `if 文案.contains("[url=") or 弟子名 != ""` → `RichTextLabel`；否则 `Label`。组装文本时，弟子名前缀改为 `[url=disciple:%s]【%s】[/url] % [_id, _id]`（即 `【弟子名】` 整体可点）。保留 `文案` 内已有 `[url=]` 物品链接（`open_detail_by_url` 已处理）。
- **替代方案**：始终 `RichTextLabel`（即使无链接/无弟子名）
- **采纳默认理由**：仅在有链接需求时切 `RichTextLabel`，避免无链接文案（可能含 `[ ]` 字符）被 bbcode 误解析（安全），且与现有分支风格一致。

### D6 · `encounter`/`chronicle` 在 `_解析实体` 的定位
- **决策点**：见 D3（`encounter` 按名称、`chronicle` 按「日:名称」或索引）
- **推荐默认 / 替代 / 理由**：见 D3 对应行。

### D7 · `_attr_line_pool` 安全启用方案
- **决策点**：如何启用预埋对象池且不改变现有弹窗生命周期？
- **推荐默认**：见 §⑥ 完整方案（新增 `_属性行`/`_关闭详情`/`_回收详情行` + 惰性回收站节点；所有关闭路径统一经 `_关闭详情`）。新模板统一用 `_属性行` 构造字段行；现有模板（`_弹出物品详情`/`_弹出弟子属性弹窗`）**维持原 `Label.new()` 不变**，避免回归（其 Label 不被池化、随 `queue_free` 销毁，与原行为一致）。
- **替代方案**：改造现有模板也用 `_属性行`（池化收益更大但回归面更广）
- **采纳默认理由**：守「不改变现有弹窗生命周期」铁律，新模板启用池化即达成优化目标，现有模板零改动、零风险。

---

## ④ 四类详情模板字段表（含轻量副表）

> 标题色均取已定义常量：`gongfa`→暗金，`buff`→朱砂，`building`→青灰，`dan_yao`→`get_rarity_color(品阶)`（复用物品逻辑）。

### ④-A 四个富模板（用户指定）

**`_弹出功法详情(id)`** — 源：`SkillCultivationLoader.get_skill(id)`（空→toast）
| 字段 | 来源键 | 展示 |
|---|---|---|
| 功法名 | `skill_name` | 标题 |
| 功法ID | `skill_id` | 副行 |
| 品阶·亚阶 | `grade`+`sub_grade` | 如「天阶·上」 |
| 适用职业 | `apply_class` | 文本 |
| 功法类型 | `skill_type` | 文本 |
| 效果数值 | `effect_value` | 被动四维加成值 |
| 最大参悟等级 | `max_level` | 整数 |
| 解锁境界 | `unlock_realm` | 文本 |
| 参悟消耗 | `learn_cost` | 文本 |
| 描述 | （`skill_cultivation.csv` 无描述列） | 不显示或「（暂无描述）」，不臆造 |

**`_弹出Buff详情(id)`** — 源：`BattleCalculator._buff模板(id)`（只读，空→toast）
| 字段 | 来源键 | 展示 |
|---|---|---|
| Buff名 | `buff名` | 标题 |
| BuffID | `buff_id` | 副行 |
| 类型 | `类型` | 增益/减益/dot/控制（用 `次墨`/`朱砂` 区分） |
| 作用属性 | `作用属性` | 攻/防/血/速/灵力/全 |
| 数值·类型 | `数值`+`数值类型` | 如「15%（固定）」/`「10%（百分比）」` |
| 持续回合 | `持续回合` | 整数 |
| 来源类型 | `来源类型` | skill/item/passive/environment |
| 可叠加 | `可叠加` | 是/否 |
| 备注 | `备注` | 正式文案（见 §⑧，替换 `[PLACEHOLDER]`） |

**`_弹出建筑详情(key)`** — 源：`Game.堂口列表.get(key)`（空→toast）
| 字段 | 来源键 | 展示 |
|---|---|---|
| 建筑名称 | `名称` | 标题 |
| 堂口key | `key`（入参） | 副行 |
| 等级 | `等级` | 整数 |
| 政绩 | `政绩` | 整数 |
| 状态 | `状态` | 文本 |
| 加成维度 | `加成维度` | 攻/防/血/速/修炼/产出/测灵 |
| 负责人 | `负责人.姓名` | 若 `负责人 is Disciple` 显示姓名（否则「—」） |
| 成员数 | `成员.size()` | 整数 |

**`_弹出丹药详情(物品)`** — 源：`Item`（`category=="dan_yao"`，走 item 路径）
| 字段 | 来源 | 展示 |
|---|---|---|
| 丹药名 | `物品.名称` | 标题，色=`get_rarity_color(物品.品阶)` |
| 品阶 | `物品.品阶` | 文本 |
| 品类标记 | `物品.category` | 固定显示「丹药」 |
| 简介 | `物品.简介()` | 文本 |
| 描述 | `物品.描述` | 文本（`次墨`色） |
| 说明 | — | 「丹药功效详见简介/描述」（不臆造 Item 额外字段） |

### ④-B 轻量通用模板（D1 决定，待主理人确认）

| 类型 | 模板入口 | 源 | 字段 |
|---|---|---|---|
| `beast` | `_弹出灵兽详情(b)` | `_解析实体("beast",种类名)`→`Beast` | 种类名(标题)/品阶/等级 Lv.x/上限/类型(`beast_type`)/忠诚度/`简介()` |
| `encounter` | `_弹出纪事详情(记)` | `_解析实体("encounter",名称)`→`Dictionary` | 名称(标题)/日/category/稀有度/弟子/文案 |
| `chronicle` | `_弹出纪事详情(记)` | `_解析实体("chronicle",id)`→`Dictionary` | 同上（整条纪事展示） |

> 三者复用 `_new_detail_popup` 外壳 + 字段行，不做美术化差异。`encounter`/`chronicle` 共用 `_弹出纪事详情`，仅入参来源不同。

---

## ⑤ 富文本联动规格

### 5.1 战斗日志（`构建日志` Callable，L3340-3367）
- **拼接规则**：遍历 `显示日志` 每条 `e`，若 `e.get("ref_type","") != ""` 且 `e.get("ref_name","") != ""`，在该行行尾追加一个空格 + `[url=ref_type:ref_id]ref_name[/url]`。
  - `ref_type` 原样透传（批3 取值 `skill/buff/item`）；`ref_id` = `e.get("ref_id","")`；`ref_name` = `e.get("ref_name","")`。
  - 现有 actor/target 的 `disciple:` 链接（L3343-3346）保持不变，行尾 `ref` 链接追加其后。
- **点击**：`meta_clicked.connect(open_detail_by_url)`（L3336 已存在）自动生效；`open_detail_by_url` → `open_detail(type,id)` → D2/D4 分发。
- **bbcode 颜色**：新链接文本不加额外颜色（沿用 RichTextLabel 默认），或统一用 `暗金.to_html(false)` 包裹以示可点；**严禁裸 `#xxxxxx`**（见 §⑨）。
- **边界**：`ref_type==""` 或 `ref_name==""` 的条目不追加（与批3 预留一致，零回归）。

### 5.2 奇遇/纪事（L2093-2122）
- **渲染条件**（D5）：`if 文案.contains("[url=") or 弟子名 != ""` → `RichTextLabel`；否则 `Label`。
- **弟子名链接**：组装文本时，原 `弟子前缀 = "【%s】" % 弟子名` 改为 `弟子前缀 = "[url=disciple:%s]【%s】[/url]" % [弟子名, 弟子名]`（仅 `RichTextLabel` 分支生效）。
- **物品链接**：`文案` 内已有 `[url=item:xxx]` 链接保留原样，`open_detail_by_url` 经 `item` 分支打开物品详情。
- **点击**：`RichTextLabel.meta_clicked.connect(open_detail_by_url)`（L2109 已存在）自动生效。

---

## ⑥ `_attr_line_pool` 安全启用方案（含调用点）

### 6.1 新增成员与函数
- **新增 `var _详情回收站: Node = null`**（惰性创建）：首次用到时 `_详情回收站 = Node.new(); add_child(_详情回收站)`。纯 `Node`（非 CanvasItem），子 `Label` 不渲染、不占布局，仅保活。
- **`func _属性行(文本: String, 色: Color) -> Label`**：
  ```
  var l: Label
  if not _attr_line_pool.is_empty():
      l = _attr_line_pool.pop_back()
      if is_instance_valid(l):
          l.text = 文本
          l.visible = true
          l.modulate = Color(1,1,1,1)
          l.add_theme_color_override("font_color", 色)
      else:
          l = Label.new()
  else:
      l = Label.new()
  if l.get_meta("pooled", false) == false:
      l.set_meta("pooled", true)
  return l
  ```
  > 池内 Label 当前为 `_详情回收站` 子节点；调用方 `内容.add_child(l)` 时 Godot 自动 reparent 出回收站、挂入弹窗，无需手动移除。
- **`func _回收详情行(遮: Control) -> void`**：递归遍历 `遮` 子树，收集 `get_meta("pooled",false)==true` 的 `Label`；对每个有效 Label 设 `visible=false` 并 `_详情回收站.add_child(l)`（reparent 出弹窗保活），推入 `_attr_line_pool`。其余 `Label`/`Button`/`RichTextLabel` 不处理，随 `queue_free` 销毁。
- **`func _关闭详情(遮: Control) -> void`**（统一关闭入口）：
  ```
  if 遮 == null or not is_instance_valid(遮): return
  _回收详情行(遮)
  遮.queue_free()
  ```

### 6.2 调用点（全部关闭路径统一经 `_关闭详情`）
| # | 原位置 | 原代码 | 改为 |
|---|---|---|---|
| 1 | `_new_detail_popup` L1587 | `背板.pressed.connect(func(): 遮.queue_free())` | `func(): _关闭详情(遮)` |
| 2 | `_new_detail_popup` L1602 | `关.pressed.connect(func(): 遮.queue_free())` | `func(): _关闭详情(遮)` |
| 3 | `_new_detail_popup` L1606 | ESC `遮.queue_free()` | `_关闭详情(遮)` |
| 4 | `_new_detail_popup` L1573-1574（单实例守卫） | `if _当前详情遮!=null and is_instance_valid(_当前详情遮): _当前详情遮.queue_free()` | 改为 `_关闭详情(_当前详情遮)`（先回收上一窗池化 Label 再开新窗） |
| 5 | `_弹出批量考核` L1562-1563 | `if is_instance_valid(弹["遮"]): 弹["遮"].queue_free()` | `if is_instance_valid(弹["遮"]): _关闭详情(弹["遮"])` |

> 因所有详情弹窗均经 `_new_detail_popup` 外壳（含 4 新模板 + 现有 item/disciple/批量考核），上述 1-4 已统一覆盖；5 为直接 `queue_free` 的特例，一并接入。

### 6.3 池化使用约定
- **新模板（gongfa/buff/building/dan_yao + 轻量 beast/纪事）统一用 `_属性行` 构造字段行**（入池、可回收）。
- **现有模板（`_弹出物品详情`/`_弹出弟子属性弹窗`）维持原 `Label.new()` 不变**（不入池，随弹窗销毁，与原行为一致，零回归）。
- `RichTextLabel` 不进池（范围限定「属性行控件对象池」）。

### 6.4 安全要点（不破坏生命周期）
- 弹窗**视觉生命周期不变**：关闭即时 `queue_free`，玩家无感。
- 池化 Label 在 `queue_free` 前 reparent 到纯 `Node` 回收站，故不被销毁。
- 单实例守卫先回收旧窗再开新窗，避免池内 Label 仍挂在已销毁节点。
- 仅 `meta("pooled")==true` 的 Label 入池，零误回收。

### 6.5 边缘情况（≥3，含 6 类）
1. **池为空** → `_属性行` 走 `Label.new()`，行为等同原逻辑。
2. **池内 Label 失效**（`is_instance_valid==false`，理论上不会因回收站保活）→ 跳过，新建。
3. **快速连点** → 单实例守卫在 `_new_detail_popup` 开头调 `_关闭详情(旧遮)` 回收其池化 Label，新窗正常。
4. **重复关闭**（`遮` 已被别处 `queue_free`）→ `_关闭详情` 首行 `is_instance_valid` 守卫，避免重复回收/错误。
5. **富文本不进池** → `RichTextLabel` 不被 `_回收详情行` 收集，随弹窗销毁。
6. **调用方未 `add_child`**（`_属性行` 返回后异常路径）→ 该 Label 仍挂回收站或游离，下次池取安全；约定模板必须 `add_child`。

---

## ⑦ 偏差与铁律冲突（批3-D7 / mp）

### 7.1 批3-D7（3v3 跨对 buff/技能保留）
- **批3 结论**：本批不做（逐对独立）；批3-GDD §7.2 明确「Buff/技能在 3v3 跨对保留（本批每 `结算_1v1` 独立）」。
- **本批铁律**：不改现役战斗结算代码、不触碰 ADR-003 纯函数边界。
- **本批动作（仅 UI 层诠释）**：战斗日志中所有对的 `buff`/`skill` 条目已带 `ref_*` 字段（批3 预留），批4 在 §5.1 把它们渲染为可点击实体（gongfa/buff 直达）。**模拟层跨对保留（气血继承回写改造）本批不做。**
- **标注**：D7 模拟扩展**待用户豁免铁律 / 真机数据后另立批次**，不在本批 scope。

### 7.2 mp 数值回填（③）
- `BattleCalculator.gd` 的 `灵力初始=30[PLACEHOLDER]`、`灵力上限=60[PLACEHOLDER]`、`回复=10` 属战斗结算代码，铁律禁止改动 → **本批保持 `[PLACEHOLDER]`/10，不回填**。
- Buff 数值（`battle_buff.csv` 数值列 + `BattleCalculator._buff模板`）批3 已填设计值（0.05/0.10/0.15…），本批**仅将 `battle_buff.csv` 备注列 `[PLACEHOLDER]待校准` 文本改写为正式描述**（仅改 config 文本，不改数值列、不改 `BattleCalculator`）。正式备注文案见 §⑧。

---

## ⑧ `[PLACEHOLDER]` 去向表

| 项 | 位置 | 当前值 | 本批动作 | 铁律依据 |
|---|---|---|---|---|
| mp 初始 | `BattleCalculator.gd` 灵力初始 | `30[PLACEHOLDER]` | **保留，不回填** | 禁改战斗结算代码 |
| mp 上限 | `BattleCalculator.gd` 灵力上限 | `60[PLACEHOLDER]` | **保留，不回填** | 同上 |
| mp 回复 | `BattleCalculator.gd` 回复 | `10` | 保留（设计基线，非占位） | 同上 |
| buff 备注 ×9 | `config/battle_buff.csv` 备注列 | `[PLACEHOLDER]待校准` | **改写为正式描述**（见下，仅改文本） | 仅改 config 文本，不改数值/不改 `BattleCalculator` |
| 批3-D7 模拟跨对 | `BattleCalculator/BattleManager` 气血继承回写 | 逐对独立 | **本批不做（仅 UI 诠释）** | 铁律 + 批3-D7 留批4 |

**buff 备注正式文案（数值列不变，仅改备注文本）**：
| buff_id | 数值列（不变） | 新备注（替换 `[PLACEHOLDER]待校准`） |
|---|---|---|
| bf_burn | 0.05 / percent | 每回合损失当前气血的5% |
| bf_freeze | 0 / none | 冻结1回合，无法行动 |
| bf_stun | 0 / none | 眩晕1回合，无法行动 |
| bf_shield | 0.15 / flat | 吸收等同于最大气血15%的伤害 |
| bf_atkup | 0.10 / percent | 攻击提升10% |
| bf_defdown | 0.20 / percent | 防御降低20% |
| bf_defup | 0.15 / percent | 防御提升15% |
| bf_spdup | 0.15 / percent | 速度提升15% |
| bf_regen | 0.08 / percent | 每回合恢复当前气血的8% |

---

## ⑨ pre_f5 合规声明（17/18/19 不破坏）

- **闸门 17（Tab 数）**：`const 页名 := ["宗门","弟子","御兽","历练","纪事"]`（L195，5 项）。本批所有改动在 `main.gd` 详情弹窗/富文本层，**不增删 Tab、不动 `页名`** → **不破坏**。
- **闸门 18（裸 hex）**：本批新代码只用已定义颜色常量（`墨底/暗金/朱砂/青灰/次墨/墨黑/宣纸亮/面板底/墨底半透`）；bbcode 颜色统一用 `已定义常量.to_html(false)`（沿用 L3349/L3360/L3361/L3366 既有写法），**不引入任何新颜色常量、不写裸 `#xxxxxx`**；字号只用 `{22,17,18,16,15,13}` 集合（标题 `FONT_PANEL`/正文 `FONT_BODY`/副 `FONT_SUB`）→ **不破坏**。
- **闸门 19（背景常量）**：`BG_SCENE_ALPHA=0.30(≤0.35)`、`BG_OVERLAY_COLOR=#16221D`、`BG_OVERLAY_ALPHA=0.50`。本批**不触碰这三个常量** → **不破坏**。

---

## ⑩ 风险与缓解

| # | 风险 | 等级 | 缓解 |
|---|---|---|---|
| R1 | `_attr_line_pool` reparent 逻辑错 → Label 错位/泄漏 | 低 | 仅 `meta("pooled")` 入池；惰性回收站纯 Node；单实例守卫先回收；模板约定必 `add_child` |
| R2 | `RichTextLabel` bbcode 误解析（文案含 `[ ]`） | 低 | D5 仅在确需链接时切 RichTextLabel；纪事文案为系统生成，风险低 |
| R3 | `ref_type="skill"` 死链（`skill.csv` 命名空间不通） | 中(已知) | D4 别名路由 gongfa + 降级 toast；列入已知限制，待批3 A6 治理 |
| R4 | 弟子名链接误命中（多名同姓同名） | 低 | `_解析实体` disciple 取首条匹配，与现有 open_detail disciple 行为一致 |
| R5 | 关闭路径遗漏 → 池化 Label 泄漏 | 低 | §6.2 全 5 处关闭路径统一经 `_关闭详情`；`_关闭详情` 守卫防重复 |
| R6 | 战斗日志行尾链接致竖屏(480)超宽 | 低 | 链接仅追加行尾，RichTextLabel 自动换行；可加前导空格分隔 |
| R7 | 闸门18 误引入裸 hex | 低 | 全用 const + `.to_html(false)`；代码评审核对 |

---

> 本文档为设计交付物，未改动任何游戏战斗结算代码；`battle_buff.csv` 仅备注文本改写、数值列不变。落地以主理人批4 决策会拍板为准；所有 `[PLACEHOLDER]` 数值回填须于战斗基线实测后、且保证 pre_f5 全绿方可执行。

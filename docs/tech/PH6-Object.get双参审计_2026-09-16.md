# PH6-E2 · 全项目「双参 `.get()` 打在 Object 上」静默缺陷静态审计

- **日期**：2026-09-16
- **责任**：严守真（质量保障与测试工程师）
- **性质**：纯静态、只读（**未启动任何 Godot 进程**，未改动任何 `.gd`）
- **扫描快照**：working tree @ 2026-09-16 18:37（扫描期间工程线仍在并发编辑，实测 `disciple_detail_page.gd` 的 L1643 在两次扫描间被修掉，见 §4.3）
- **扫描器**：`tools/audit_object_get.py`
- **范围**：251 个 `.gd`（跳过 `art/addons/.godot/.scratch_backup/backup*` 等）

---

## 0. 结论速览（TL;DR）

| 分级 | 数量 | 处置 |
|---|---|---|
| **P0 确诊**（Object 接收者，2 参 `.get` ⇒ 运行期必抛/必中断） | **7** | **建议作硬门**（已逐条人工核验为真，误报率 0） |
| P1 疑似（未标注 Variant / 字段类型未知 / 纯链式） | 3514 | **不可作硬门**（77% 是未标注 Variant，误报率极高） |
| LEGAL 合法（Dictionary 接收者） | 7657 | 仅计数，供旁证 |

- **灵敏度自检：5/5 命中** —— 任务给定的 5 处 ground truth（`game_state.gd` 备份 L8364/8371/8378/8397/8407）**全部**落入 P0（见 §4）。
- **既有闸门无此检查** —— 全库无任何门做「Object vs Dictionary 双参 `get`」通用检测；`validate_all.py` 只有**逐特性硬编码字面量**白/黑名单（见 §7）。
- **建议新增「门6」**：调用 `audit_object_get.py --strict`，**仅当 P0>0 时 FAIL**。

---

## 1. 缺陷原理（为什么必须静态抓）

`Item` / `Disciple` / `Beast` 等是 `RefCounted`（**Object**）。GDScript 里：

- `Object.get()` **只接受 1 个参数**（`get(property)`）；
- 只有 `Dictionary.get()` 接受 `(key, default)`。

因此 `x.get("k", <default>)` 当 `x` 是 Object 时，运行期抛
`Invalid call. Nonexistent function 'get' ... Expected 1 argument(s)`，
**并当场中断整个函数**（不是回退默认值——是整段逻辑死掉，静默吞掉后续全部副作用）。

**为什么门1/门3 都抓不到**：当接收者是**未标注的 `var x = ...`**（隐式 Variant）时，gdtoolkit 只做语法解析、不看运行期类型；`pre_f5_check.py` 不做类型推断 ⇒ 缺陷可长期潜伏，直到某条 UI 路径/某次结算才炸，且炸点与真因隔着一整个调用栈。

**已核前提**：全项目**无任何 class 定义 `func get(`**（`grep '^\s*func get\('` 零命中）⇒ 2 参 `get` 打在 Object 上**一律**是缺陷，无「自定义 get 兼容」的例外。

**正确写法范式**（`game_state.gd:22381 _物品类别码` / `:22401 _物品名`）：

```gdscript
func _物品名(it) -> String:
    if it is Dictionary:
        return str((it as Dictionary).get("名称", ""))   # Dictionary：2 参合法
    return str(it.get("名称"))                            # Object：注意**单参**
```

---

## 2. 扫描器判据与灵敏度自检

### 2.1 三级判据

**P0（确诊 Object 系接收者）**——满足任一：
1. 裸标识符有 Object 系**类型标注**（`var x: Item` / 形参 `x: Disciple`）；
2. 处于 `is <ObjectType>` / `typeof(x)==TYPE_OBJECT` 的**收窄**之后（含负向早退守卫 `if not (x is Item): return`，收窄有效至**函数末或下一次再赋值前**）；
3. 由 **Object 返回函数**赋值（显式 `-> T`；或函数体含 `typeof(x)!=TYPE_OBJECT` 守卫者，如 `_取护身符`）、`T.new()`、或 `self`；
4. 点字段接收者 `root.field`，且 `field` 被声明为 Object 系（或 ∈ `OBJECT_FIELD_HINTS = {护身符, 本命法宝}`）。
5. 三元 `A if C else B` 中，`.get` 落在使 `x` 为 Object 的分支（例：`x.get(k,d) if x is Object else d` ⇒ THEN 分支）。

**LEGAL（合法 Dictionary 接收者）**——对称判据：`:Dictionary` 标注 / `is Dictionary` / `typeof==TYPE_DICTIONARY` / 字典字面量 `{...}` 初始化 / 字段声明为 Dictionary（如 `Disciple.属性: Dictionary`）/ 返回 `Dictionary` 的函数 / 链式 `FUNC(...).get` 且 `FUNC -> Dictionary`。

**P1（疑似，需运行期证伪）**——以上皆不成立者（未标注 Variant、字段类型未知、链深>2、纯链式、返回类型未标注）。

### 2.2 灵敏度自检（必做，已通过）

在**修复前备份** `game_state.gd.bak_ph6e1b_m5_20260916` 上跑单文件模式（现行 `game_state.gd` 中这 5 处已被程基岩修复，故改用备份作 ground-truth 语料）：

```
python tools/audit_object_get.py --file game_state.gd.bak_ph6e1b_m5_20260916
```

**结果：P0=6，5 处 ground truth 全命中**（另 1 处为同族新增）：

| 备份行 | 代码 | 依据 | 命中 |
|---|---|---|---|
| 8364 | `return 符词条聚合(it.get("符词条", [])).get("战力", 0.0)` | `it = _取护身符(弟子)` ⇒ Object | ✅ P0 |
| 8371 | `...it.get("符词条", [])...("修炼", 0.0)` | 同上 | ✅ P0 |
| 8378 | `...it.get("符词条", [])...("突破", 0.0)` | 同上 | ✅ P0 |
| 8397 | `return {"成功": true, "名称": str(符箓物品.get("名称", ""))}` | 形参守卫 `if not (符箓物品 is Item): return` 收窄 | ✅ P0 |
| 8407 | `return {"成功": true, "名称": str(旧.get("名称", ""))}` | `旧 = _取护身符(弟子)` ⇒ Object | ✅ P0 |

> 注：`符词条聚合(...).get("战力",0.0)` 这 3 处**链式** `.get` 被正确判为 **LEGAL**（`符词条聚合 -> Dictionary`），未混入 P0 —— 说明链式返回类型推断生效。

---

## 3. P0 确诊清单（7 处，全部人工核验为真）

> 接收者均为 Object，2 参 `.get` 运行期必抛并中断所在函数。**均已逐行读源码确认。**

| # | 位置 | 代码 | 推断依据 | 核验 |
|---|---|---|---|---|
| 1 | `forge.gd:590` | `心境 = str(炼器弟子.get("心境", ""))` | L580 `if 炼器弟子 != null and typeof(炼器弟子) == TYPE_OBJECT:` 块内；`恰因 elif 炼器弟子.has_method("get")`（对所有 Object 恒真）该行**可达** | ✅ 真 |
| 2 | `game_state.gd:7295` | `var _丹词 = 丹词条聚合(it.get("丹词条", []))` | L7294 `if it is Object:` 块内 | ✅ 真 |
| 3 | `ui/disciple_detail_page.gd:1681` | `名.text = "◆ %s（战力+%d）" % [str(it.get("名称", "")), int(it.get("战力加成", 0))]` | L1670 `if it == null or typeof(it) != TYPE_OBJECT: continue` 之后 | ✅ 真（**部分修复**：同行 L1675 `it.get("类别")` 已改单参、L1672-1674 注释自认本 bug 族，却漏改 L1681） |
| 4 | 同上（同行的第 2 个 `.get`） | `int(it.get("战力加成", 0))` | 同上 | ✅ 真 |
| 5 | `ui/page_daoyou.gd:200` | `var 名: String = str(d.get("姓名", "—")) if d is Object else "—"` | 三元 THEN 分支**恰在 `d` 是 Object 时**求值 | ✅ 真 |
| 6 | `ui/page_daoyou.gd:201` | `var 境界: String = str(d.get("境界", "")) if d is Object else ""` | 同上 | ✅ 真 |
| 7 | `ui/page_daoyou.gd:202` | `var 战力: int = int(d.get("战力", 0)) if d is Object and d.get("战力") != null else 0` | 同上 | ✅ 真 |

**P0 涉及文件指纹**（供复现/回溯）：

| 文件 | md5(前12) | size | mtime |
|---|---|---|---|
| `forge.gd` | `2a493c41086b` | 31103 | 2026-09-09 00:34 |
| `game_state.gd` | `067980fd262f` | 1428774 | 2026-09-16 18:20 |
| `ui/disciple_detail_page.gd` | `97a932a154d6` | 209061 | 2026-09-16 18:31 |
| `ui/page_daoyou.gd` | `d4a0d735ec31` | 18400 | 2026-09-14 01:57 |

> ⚠️ 与 `game_state.gd:7295`（#2）同源的 `game_state.gd` 现行 L8383/8390/8397/8416/8426 已被程基岩修复，**不在本清单内**（本清单是现行文件的独立发现，非任务给定 ground truth）。

---

## 4. P1 疑似清单（构成与定位线索；**不建议作硬门**）

**P1 = 3514 处。按成因分布：**

| 成因 | 数量 | 占比 | 典型 |
|---|---|---|---|
| 未标注 Variant（多为成员/局部字典） | 2722 | 77.5% | `BattleCalculator.gd:95 纯度克制.get(root_purity, 1.0)` |
| 接收者为纯链式/索引取值 | 369 | 10.5% | `xxx()[...].get(k, d)` |
| 接收者链深 >2 | 128 | 3.6% | `a.b.c.get(k, d)` |
| 字段类型未知（`Game.XXX` / `Disciple.XXX` 无标注成员） | ~250 | 7.1% | `Game.代拍方略`、`Game.朝奏`、`Item.套装库` |
| 函数返回类型未标注 | ~45 | 1.3% | `方针(...)`、`atk(...)`、`结果(...)` |

**P1 文件 Top12**：`game_state.gd` 651 · `caravan_system.gd` 236 · `ui/page_sect_manager.gd` 183 · `ui/page_building.gd` 150 · `main.gd` 122 · `dynasty_system.gd` 117 · `ui/page_dynasty.gd` 97 · `expedition.gd` 82 · `ui/page_global_auction.gd` 73 · `ui/page_explore.gd` 72 · `auction_system.gd` 65 · `ui/page_auction.gd` 65。

**为什么不能作硬门**：77% 是「变量无类型标注」，其中绝大多数实为 **成员字典**（如 `纯度克制` / `职业克制` 等`= {...}`或`const` 声明），本身**合法**。把 3514 条塞进 CI 只会淹没信号。**建议**：仅作**非阻塞提示**，或先由人抽样降噪（给成员补类型标注即可自动转 LEGAL）。

**降噪留待下一步（可选）**：给高频 P1 文件的成员变量补 `: Dictionary` 标注，可一次性把上千条 P1 转 LEGAL。

---

## 5. LEGAL 计数（7657，旁证）

构成：`变量标注 :Dictionary` 5390 · `形参标注 :Dictionary` 1561 · `由 Dictionary 赋值` 455 · 字段声明为 Dictionary（`Disciple.属性/休闲技能/休闲经验/当前法阵/装备`、`FactionReputationSystem.旧阵营映射`、`FormationSystem.阵法等级`、`DanMarkSystem.丹纹图谱` …）· 返回 Dictionary 的函数（`符词条聚合`/`装备词条聚合`/`丹品级配置` …）· 字典收窄（`is Dictionary` / `typeof==TYPE_DICTIONARY`）。

> 该桶是 P0 判据的「反向对照」——它证明扫描器**没有**把 Dictionary 接收者误报为缺陷（早期版本曾把 `d.属性.get("悟性",50)` 全误判为 P0，修复见 §9）。

---

## 6. 门控建议（本节为交付重点）

### 6.1 既有闸门是否已有此检查？——**没有**

`grep` 全库四道相关脚本（`gate_all.py` / `pre_f5_check.py` / `validate_all.py` / `audit_uitheme_calls.py`）后确认：

- **无任何门**做「接收者类型推断 + Object/Dictionary 双参 `get`」的**通用**检测；
- `validate_all.py` 只有**逐特性硬编码字面量**白/黑名单，例如：
  - L2456 要求 game_state.gd **存在**字面量 `丹词条聚合(it.get("丹词条"`；
  - L2628 禁止 xichi.gd **存在**字面量 `弟子.get("命格重铸失败次数"`。
  
  这类检查**只能覆盖作者已想到的具名点**——正是本次 7 处 P0 漏网的根因：它们从没被写进任何白/黑名单。
- `pre_f5_check.py:1159-1162` 的死函数棘轮、`audit_uitheme_calls.py` 的 UITheme 调用检查，均与本题无关。

### 6.2 建议：新增「门6 · Object 双参 get」

- **落点**：**独立脚本** `.workbuddy/check_object_get.py`，在 `gate_all.py` 的 `GATES` 追加一行 `("门6 Object双参get", .../check_object_get.py)`。**不并入门2**——门2 语义是 CSV/配置校验，混入会污染其失败含义。
- **脚本内容**：`subprocess` 调用 `python tools/audit_object_get.py --strict`（已就绪：P0>0 ⇒ exit 1）。
- **拦截级别**：**只拦 P0**（当前 7 处，人工核验误报率 0）。**P1 不拦**（噪声 3514，误报率高）。若需留痕，可在门6 里额外打印 P1 总数作趋势，但**不影响 exit code**。
- **为什么值得设硬门**：与门5（重复字典键）**同源**——都是「gdtoolkit 语法过关、但运行期炸」的盲区；本类缺陷一旦触发就是**整段函数静默死掉**（比崩溃更难查）。且**零误报**，具备作硬门的资格。

### 6.3 误报率评估（供拍板）

- **P0 误报率：0/7**（在 §9 的四类误报修复后，7 处逐条核验为真）。
- **P1 误报率：高**（77% 未标注 Variant 中多为合法成员字典）⇒ **P1 不可门控**。
- **结论**：门6 设 `P0 > 0 ⇒ FAIL` 是**低风险、高收益**；不建议对 P1 做任何阻塞。

---

## 7. 复现方法

```bash
cd E:/Xiuxian/taixuanzongmenlu
python tools/audit_object_get.py                 # 报告模式（恒 exit 0）：打印 P0/P1/LEGAL 三级清单
python tools/audit_object_get.py --strict         # 门控模式：P0>0 ⇒ exit 1
python tools/audit_object_get.py --file X.gd      # 单文件（灵敏度自检用）
python tools/audit_object_get.py --json out.json  # 机器可读输出
```

实测：`--strict` ⇒ `汇总: P0=7 P1=3514 LEGAL=7657`、`[STRICT] 存在 7 处确诊 P0 ⇒ FAIL`、exit 1；报告模式 exit 0。

---

## 8. 已知限制与误报边界（引擎）

扫描器是**语法级**类型推断（无编译器类型信息），边界如下（按「宁漏勿误判/尽量归 P1」设计）：

1. **跨行三元**（条件换行书写）不识别分支 ⇒ 归 P1（不漏报，但可能不升级为 P0）；
2. **负向守卫收窄**已处理「再赋值打断」（取用点前最近一次赋值）；但**嵌套作用域内的再绑定**（深层 if/for 里 `x = ...`）为近似处理；
3. **`self` / `root.field`** 仅在字段有**显式类型标注**时可判；无标注成员 ⇒ P1；
4. **未标注形参**（`func f(x):`）无法定类型 ⇒ P1；
5. **链深 >2 / 纯链式 / Lambda·Callable 内**的 `get` ⇒ P1（无法定）；
6. 只统计「**顶层恰 2 参**」的 `.get(`；3 参（无此形态）/ 1 参不涉及。

> 以上限制**均只会导致「降级为 P1」而不会「漏报」**（P0 判据是"可静态证明为 Object"的保守集）——符合任务「宁可分错类别也不要漏报」的要求。

---

## 9. 附录：扫描器迭代记录（发现的 4 类误报及修复）

初版在备份上 P0=40/全项目 108，且 5 处 ground truth 只命中 3 处。经 4 轮定位修复后收敛到全项目 **P0=7、自检 5/5**：

| # | 症状 | 根因 | 修复 |
|---|---|---|---|
| 1 | `符箓物品.get("名称","")` 落 P1 | 负向早退守卫 `if not (x is Item):` 的 `return` 在下一行，守卫未被识别 | 守卫识别加**下一行 lookahead**；并把负向守卫收窄区间从"if 块"改成**函数末**（早退 ⇒ 此后恒为 T） |
| 2 | `d.属性/弟子.装备/…` 等**字段接收者**被误判 P0（全项目 108→37 的主因） | 按 **root 变量的类型**判字段，而字段本身多为 Dictionary | 新增**字段类型索引**（从 `class_name` + 顶层成员 `var 名: T` 采集）：接收者 = `root.field` 时按**字段类型**判 |
| 3 | `page_sect_manager.gd:3213 行.get(...)`、`page_building.gd:2847 效果.get(...)` 等误判 P0 | 跨作用域兜底用**整文件 last-wins**，被**他处同名局部**（`var 行: HBoxContainer`）污染 | 兜底**收窄为仅顶层成员声明**（缩进 0） |
| 4 | `page_daoyou.gd:200` 漏 / `disciple_detail_page.gd:2513` 误 | (a) 三元 `x is T` 无 `if` 前缀 ⇒ 守卫正则不匹配；(b) 语句守卫压过**同行更精确的三元分支** | (a) 新增无 `if` 前缀的 `is` 表达式正则；(b) **三元分支收窄优先于语句守卫** |
| 5 | `page_premium.gd:305 b.get(...)` 误判 P0（`最近赋值: L327`——**赋值在使用点之后**） | 赋值表为**整函数 last-wins**，时序错误 | 改为**按行累积 + 取用点前最近一次**（时序正确） |

---

## 10. 交付物

1. **扫描器**：`tools/audit_object_get.py`（含 `--strict` / `--file` / `--json`）
2. **报告**：本文件 `docs/tech/PH6-Object.get双参审计_2026-09-16.md`
3. **回执**：已 `SendMessage` 给 team-lead（≤25 行摘要）

**未决（转交 team-lead 拍板）**：
- 是否按 §6.2 新增「门6」？（建议：是，仅拦 P0）
- 7 处 P0 是否立**新 Bug 单**并指派程基岩修复？（建议：是，均为「整段函数静默死掉」级别）
- 是否安排一轮 P1 降噪（给高频文件的成员补 `: Dictionary` 标注）？

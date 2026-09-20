# PH7 · `tests/headless_ui_decouple_check.gd` 处置表（只读 · 逐字引用）

- **产出**：quality-lead-2（严守真）｜ 依 team-lead「★ 你的处置表必须做到」三条要求
- **对象**：`tests/headless_ui_decouple_check.gd`（UI 视觉/门控解耦 harness）
- **三条纪律**：① 每条**逐字引用** `_check(...)` 原文；② 区分**「断言文本里的数」** vs **「盘上常量里的数」**；③ `:59` 等**是否 PASS/FAIL 只能实跑** —— 起 Godot ⇒ **先报 team-lead 排时段，禁与工程线并发**。
- **本表性质**：**纯静态**。**未实跑**（我未起 Godot）。凡"实跑"列写「未实跑」。

---

## 0. 更正声明

我此前对 `:59` 报「恒 FAIL」——**错误**。我当时把断言里的 `6` 与**原始** `QUICK_ENTRIES.size()` 比，忽略了断言比较的是 **`_过滤已解锁(...)`（过滤后）**。经 team-lead 指出后逐字复核源码，**撤回该结论**。`:59` **结构上不必然 FAIL**，见 §2。

---

## 1. 全量 `_check(...)` 处置表

> "数"列：**断言文本里的数** = 断言字符串里的期望值；**盘上常量里的数** = `ui/sect_home_page.gd` 中对应常量的实际规模（盘上回盘）。

| # | 行 | `_check(...)` 原文（逐字） | 断言文本里的数 | 盘上常量里的数 | 静态判定 |
|---|---|---:|---|---|
| A1 | `:30` | `_check("A1 入口可显示(天下) == true", SystemUnlock.入口可显示("天下") == true)` | `true` | — | 依赖 `SystemUnlock` 运行时态 → 实跑 |
| A2 | `:31` | `_check("A2 陌生入口 fail-open == true", SystemUnlock.入口可显示("__不存在__") == true)` | `true` | — | 断言「陌生 id → fail-open」设计（与 `:331` 的 fail-open 一致） |
| A3 | `:32` | `_check("A3 静态与实例结果一致(库藏)", SystemUnlock.入口可显示("库藏") == U.入口已解锁("库藏"))` | — | — | 一致性断言 → 实跑 |
| B1 | `:38` | `_check("B1 sect_home_page.gd 可编译", sp != null)` | `!= null` | — | 编译态 → 实跑 |
| B2 | `:39` | `_check("B2 game_ui.gd 可编译", gu != null)` | `!= null` | — | 编译态 → 实跑 |
| C1 | `:58` | `_check("C1 全条件成立 侧边左列 = 3", page._过滤已解锁(page.ENTRIES_LEFT).size() == 3)` | **3** | `ENTRIES_LEFT` = **3**（`sect_home_page.gd:24-28`：天下/宗务/坊市） | 过滤后==3 ⇐ 需三项皆 `入口可显示` → **实跑** |
| **C2** | **`:59`** | `_check("C2 全条件成立 快捷栏 = 6", page._过滤已解锁(page.QUICK_ENTRIES).size() == 6)` | **6** | `QUICK_ENTRIES` = **7**（`sect_home_page.gd:59-67`） | **见 §2：非恒 FAIL** |
| C3 | `:60` | `_check("C3 全条件成立 更多面板 = 36", page._过滤已解锁(page.MORE_ENTRIES).size() == 36)` | **36** | `MORE_ENTRIES` = **36**（`sect_home_page.gd:109-145`） | 过滤后==36 ⇐ 需全解锁 → 实跑 |
| C4 | `:61` | `_check("C4 可见序号 天下=0 / 宗务=1 / 坊市=2", …)`（跨行） | 0/1/2 | `_可见序号`（`sect_home_page.gd:336-341`） | **实跑** |
| C5 | `:69` | `_check("C5 锁定后 入口可显示(宗务) = false", SystemUnlock.入口可显示("宗务") == false)` | `false` | — | **实跑** |
| C6 | `:71` | `_check("C6 锁定后 侧边左列 = 2", page2._过滤已解锁(page2.ENTRIES_LEFT).size() == 2)` | **2** | `ENTRIES_LEFT` = 3（锁 1 ⇒ 2） | **实跑** |
| C7 | `:72` | `_check("C7 锁定后 坊市序号 = 1（紧凑上移）", page2._可见序号(page2.ENTRIES_LEFT, "坊市") == 1)` | **1** | — | **实跑** |
| C8 | `:73` | `_check("C8 锁定后 宗务序号 = -1", page2._可见序号(page2.ENTRIES_LEFT, "宗务") == -1)` | **-1** | — | **实跑** |
| D1 | `:130` | `_check("%s _chrome 已构建" % 标签, chrome != null)` | `!= null` | — | **实跑** |
| D2 | `:147` | `_check("%s 左列 Y 槽连续无空洞" % 标签, _近似(左ys, _前缀(page.ENTRY_YS, 左ys.size())))` | — | `ENTRY_YS` = **[150,222,294,366]**（4 槽，`sect_home_page.gd:38`） | **实跑** |
| D3 | `:148` | `_check("%s 右列 Y 槽连续无空洞" % 标签, _近似(右ys, _前缀(page.ENTRY_YS, 右ys.size())))` | — | 同上 | **实跑** |
| **D4** | **`:149`** | `_check("%s 快捷栏 X 槽连续无空洞" % 标签, _近似(qxs, _前缀(page.QUICK_XS, qxs.size())))` | — | `QUICK_XS` = **7 槽**（`sect_home_page.gd:69`） | **★ 恒 FAIL（静态已定案，无需实跑）** —— 见 §3 |

---

## 2. `:59` 专项（逐字 · 非恒 FAIL）

**源码逐字**：

```gdscript
# tests/headless_ui_decouple_check.gd:59
	_check("C2 全条件成立 快捷栏 = 6", page._过滤已解锁(page.QUICK_ENTRIES).size() == 6)
```

**盘上常量逐字**（`ui/sect_home_page.gd:59-67`，共 **7** 项）：

```gdscript
const QUICK_ENTRIES: Array = [
	{"id": "库藏"}, {"id": "灵讯"}, {"id": "日供"}, {"id": "幻形"},
	{"id": "设置"}, {"id": "隐藏UI"}, {"id": "更多", "fold": true},
]
```

**过滤规则逐字**（`ui/sect_home_page.gd:328-333`）：

```gdscript
func _过滤已解锁(配置表: Array) -> Array:
	var 结果: Array = []
	for cfg in 配置表:
		if bool(cfg.get("fold", false)) or SystemUnlock.入口可显示(String(cfg["id"])):
			结果.append(cfg)
	return 结果
```

**结论（静态）**：
- **断言文本里的数** = `6`（期望）；**盘上常量里的数** = `QUICK_ENTRIES.size()` = **7**（**原始**）。
- **但断言比较的是 `_过滤已解锁(QUICK_ENTRIES).size()`（过滤后）**，不是原始 7。过滤规则：`fold==true`（仅「更多」）**恒定保留**；另 6 项各凭 `SystemUnlock.入口可显示(id)`。
- ⇒ 过滤后 = `1 + #{库藏,灵讯,日供,幻形,设置,隐藏UI 中 入口可显示 者}`。**等于 6 ⇔ 恰好其中 5 项 `可显示`、1 项不可显示。**
- ⇒ **`:59` 不必然 FAIL**（我此前判断有误）。它**通过了与否取决于运行时解锁态**（"全条件成立"下那 6 项的 `可显示` 结果）——**只能实跑**。
- **设计侧旁证**（仅供理解，不构成结论）：该页注释 `sect_home_page.gd:35` 明确「该形状与 `tests/headless_ui_decouple_check.gd` 的双列连续性断言**同源**」⇒ 设计线判「`:59` 保留」**结构上说得通**。
- **★ 像素侧旁证（QA-21 独立实测）**：`after_p1/00_home.png` 的 dock **实为 6 个槽**（青环列簇 = 6，见 `.workbuddy/_ph7visual/_q21_geo2.txt`）⇒ 与断言期望的**过滤后 `6`** 在数量上**自洽** ⇒ **反向支持 `:59` 非恒 FAIL（保留判断成立）**。（注：此为"数量自洽"旁证，不替代实跑给 PASS/FAIL。）

---

## 3. `:149` 专项（**★ 恒 FAIL · 静态定案，无需实跑**）

### 3.1 逐字源码

```gdscript
# tests/headless_ui_decouple_check.gd:149
	_check("%s 快捷栏 X 槽连续无空洞" % 标签, _近似(qxs, _前缀(page.QUICK_XS, qxs.size())))
```

配套逐字（同一 harness）：

```gdscript
# tests/headless_ui_decouple_check.gd:160-166
func _近似(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if abs(float(a[i]) - float(b[i])) > 0.05:
			return false
	return true
```

```gdscript
# tests/headless_ui_decouple_check.gd:142
				qxs.append(c.offset_left / UITheme.UI_SCALE + page.QUICK_BTN_W * 0.5)
```

### 3.2 盘上常量逐字

```gdscript
# ui/sect_home_page.gd:69
const QUICK_XS: Array = [54.0, 116.0, 178.0, 240.0, 302.0, 364.0, 426.0]  # 7 槽等距（中点 240 对称，间距 62）
# ui/sect_home_page.gd:70
const QUICK_BTN_W: float = 32.0
# ui/sect_home_page.gd:88 / :90
const INTEL_X: float = 24.0
const INTEL_W: float = 432.0
```

```gdscript
# ui/sect_home_page.gd:936-946（现状——dock 中心列的唯一真源）
func _算dock中心列(n: int) -> Array:
	if n <= 1:
		return [240.0]
	var 可用宽: float = INTEL_W - QUICK_BTN_W
	var 间距: float = 可用宽 / float(n - 1)
	var 起始: float = INTEL_X + QUICK_BTN_W * 0.5
	var 列: Array = []
	for i in range(n):
		列.append(起始 + 间距 * float(i))
	return 列
# ui/sect_home_page.gd:951-958
	var x: float = cx - QUICK_BTN_W * 0.5
	...
	btn.name = "Quick_" + id
	_place(btn, x, y, QUICK_BTN_W, QUICK_BTN_H)
```

### 3.3 推导（对**任意** n 成立 ⇒ 恒 FAIL）

**实际 `qxs[0]`（与可见项数 n 无关）**：

1. `_算dock中心列(n)` 的**起始中心** = `INTEL_X + QUICK_BTN_W*0.5 = 24.0 + 16.0 = **40.0**`（`n≥2`；`n≤1` 时返回 `[240.0]`）。
2. `_make_quick_entry` 取 `x = cx - QUICK_BTN_W*0.5 = 40.0 − 16.0 = 24.0`，`_place()` ⇒ `btn.offset_left = x × UI_SCALE = 24.0 × 2.25 = 54.0`。
3. harness `:142` 回算：`qxs[0] = 54.0 / 2.25 + 32.0*0.5 = 24.0 + 16.0 = **40.0**`。

**期望 `_前缀(page.QUICK_XS, k)[0]`** = `QUICK_XS[0] = **54.0**`（`k≥1`）。

**比较**：`_近似` 容差 **0.05** ⇒ `|40.0 − 54.0| = 14.0 ≫ 0.05` ⇒ **首元素即 FALSE** ⇒ `_近似` 返回 `false` ⇒ **`:149` FAIL**。

- `qxs.size() == 0`（无 Quick_ 时）⇒ `_前缀(…,0)=[]`，`_近似([],[])` 会**通过**——但 `_实例化并测` 总在 `_chrome` 构建后至少含 dock，实际 n≥6（见 §3.4），不会走空分支。
- `n==1` ⇒ 实际 `[40.0]`（同一 `起始`）vs 期望 `[54.0]` ⇒ 仍 FAIL。
- ⇒ **对一切实际 n，`:149` 恒 FAIL。** 与 `:59`（比较**过滤后数量**，运行时可成立）性质不同：`:59` 是"取决于运行时态"，`:149` 是"**几何常量已经对不上，静态即死**"。

### 3.4 像素侧旁证（QA-21，独立）

`after_p1/00_home.png` 实测 dock = **6 个槽**，环中心 x ≈ 40 / 179 / 299 / 419 / 540 / 678（屏幕 px）。
按 §3.3 反算：`_算dock中心列(6)` = `40,120,200,280,360,440`（逻辑）→ 屏幕 `×1.5` = `60,180,300,420,540,660` ⇒ **与实测逐槽吻合**（首环贴左边被裁半个，故 40）。
⇒ **运行时确实走 `_算dock中心列(6)`，而非静态 `QUICK_XS`**；`:149` 的期望值自 dock 改为动态计算起**早已失真**（与 S3 无关）。

### 3.5 处置

| 项 | 处置 |
|---|---|
| **`:149` 期望值** | 改为**按 `_算dock中心列(n)` 复算**：`_近似(qxs, page._算dock中心列(qxs.size()))`（或等价：把 `QUICK_BTN_W*0.5` 的换算与 `起始` 对齐）。**不得**继续拿 `QUICK_XS` 当前缀。 |
| **`QUICK_XS`（`sect_home_page.gd:69`）** | **已成死常量**（全仓仅 `:69` 定义 + harness `:149` 引用）⇒ **可随 S3 一并退役**；退役前须同步改 `:149`（否则 `:149` 会 `IndexError`）。 |
| **契约变更说明** | 按 `首页-节点级施工点清单.md` 要求**写明「契约为何变了」**（dock 由"固定 7 槽常量"→"按可见数动态计算"），**非直接删断言**。 |
| **无需实跑** | 本结论由静态推导 + 像素旁证闭合；实跑只会再确认一次 FAIL。 |

---

## 4. 该 harness 是否在闸门内 ＋ 建议挂哪一门

### 4.1 现状：**不在 `gate_all.py` 门0–门6 内**

- **`gate_all.py` 的 6 门全是 Python 静态检查器**（逐字）：
  `门0 .workbuddy/_norm_all.py` / `门1 gdtoolkit_check.py` / `门2 validate_all.py` / `门3 pre_f5_check.py` / `门4 audit_teach_chain.py` / `门5 .workbuddy/check_dup_dict_key.py` / `门6 tools/audit_object_get.py --strict`。
  **没有任何一门运行 Godot headless 场景** ⇒ `tests/headless_ui_decouple_check.tscn` **结构上不可能被门0–6 触发**。
- **全仓 `.py` 检索 `decouple_check\.tscn` / `headless_ui_decouple` = 0 命中**（我实跑 `Grep`，见证据）⇒ 除它**自己的 `.tscn:3`** 与若干 `.md` **文档**外，**无任何脚本引用**。
- ⇒ **这是它长期失真的真正原因**：断言早已对不上（§3），却**没有门会红**，于是无人发现。

### 4.2 建议：纳入闸门

**建议新增「门7 · headless UI 契约自检」**，理由与挂法：

| 方案 | 内容 | 评价 |
|---|---|---|
| **A（推荐）· 新增门7** | 在 `gate_all.py GATES` 追加一项，运行 `godot --headless tests/headless_ui_decouple_check.tscn`，**只看 exit code**（与门4/门6 同构：`exit=0` PASS）。并把同类的 `headless_smoke` 一并纳入，形成"headless 门" | 与现有 6 门"只看得懂 exit code"的约定一致；**但**它需起 Godot ⇒ 必须遵守 **Godot 独占铁律**，**不能与工程线并发**；建议门7 **默认 `SKIP`**，仅在显式 `--with-godot` 时启用 |
| B · 折进现有 headless 链 | 若已有 `run_headless_chain.py`（`gate_all.py:43` 注释提及），把本 harness 追加进该链的场景列表 | 改动最小，但该链**不在** `GATES` 里 ⇒ 仍不构成"门"（除非同时把该链挂进门4/新门） |
| C · 挂到门4 | ❌ **不可** | 门4 = `audit_teach_chain.py`（纯静态，且语义是"引导链"），语义不匹配，且会把静态门变成"需起引擎的门"，破坏其可离线性 |

⇒ **建议：方案 A（新增门7，默认 SKIP、`--with-godot` 启用）**；**挂门位置 = `GATES` 列表末（门6 之后）**，与门6 平级、只看 exit code。
**附加建议**：门7 启用前，**先按 §3.5 修好 `:149`**，否则新门一开即恒红（会把"新门"直接证伪）。

---

## 5. 待办（报 team-lead）

- **`:149`**：静态已定案 **恒 FAIL** ⇒ **无需实跑**；按 §3.5 修期望值（或随 S3 退役 `QUICK_XS`）。
- **`:59`**：**保留**（非恒 FAIL）；像素侧旁证（dock 6 槽）支持其期望值 `6` 与现实自洽（见 §2）。
- **其余标「实跑」的行**（A1–A3 / B1–B2 / C1 / C3–C8 / D1–D3）：唯一验证途径仍是运行 harness。
- **遵铁律**：起 Godot 前**先报 team-lead 排时段**，**禁与工程线并发**（Godot 独占）。
- 实跑产出建议：逐行落盘（`_check` 原文 ＋ PASS/FAIL），交回本表回填"实跑"列。

---

## 6. 证据（本轮新增 · 均为只读）

- `Grep` 全仓 `*.py`：`decouple_check\.tscn|headless_ui_decouple` = **0 命中**。
- `gate_all.py:15-31`：`GATES` 六项**逐字**（全 Python 静态）。
- `ui/sect_home_page.gd:69-70 / :88-90 / :936-958`（§3.2 逐字）。
- `tests/headless_ui_decouple_check.gd:142 / :149 / :160-166`（§3.1 逐字）。
- `.workbuddy/_ph7visual/_q21_geo2.txt`：dock 青环列簇 = **6**（像素旁证）。

---

*PH7-QA-19 附（v2 · 依 team-lead 第二轮指令修订）｜ quality-lead-2 ｜ 只读产出，未起 Godot、未改任何文件。*


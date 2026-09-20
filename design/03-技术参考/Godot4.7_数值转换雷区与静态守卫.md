# Godot 4.7 数值转换雷区与两道静态守卫

> 制定：2026-09-16 ｜ 触发：老大报「游戏无法启动」，错误面板 `Invalid call. Nonexistent 'float' constructor.`
> 涉及：`period_settlement.gd` / `game_state.gd` / `faction_system.gd`
> 复现证据：`tests/_probe_float_diag.tscn`（22 条断言）｜`tests/_probe_year_settle.tscn`
> 静态守卫：`.workbuddy/scan_missing_parens.py`｜`.workbuddy/scan_format_arity.py`

---

## 一、雷区：`float()` / `int()` 的实参不能是 null / 数组 / 字典 / Callable

**Godot 4.7 实测**（`tests/_probe_float_diag.gd` A 段逐条断言）：

| 实参 | `float(x)` | `int(x)` |
|---|---|---|
| `null` | ✗ 抛错 | ✗ 抛错 |
| `[]` 数组 | ✗ 抛错 | ✗ 抛错 |
| `{}` 字典 | ✗ 抛错 | ✗ 抛错 |
| `Callable` | ✗ 抛错 | ✗ 抛错 |
| `int` / `float` / `bool` / 数字字符串 | ✓ | ✓ |

抛出的原文是 **`Invalid call. Nonexistent 'float' constructor.`**
（注意不是 "non-existent"——排查时按原文检索才搜得到；`int` 同理会报 `'int'`）。

**与早期版本的关键差别**：Godot 3.x / 早期 4.x 对 `float(null)` 是**静默转 0**，
4.7 改为**抛错**。所以「以前这么写没事」的代码现在会炸。

---

## 二、为什么这一条杀伤力极大

1. **抛错 = 当前函数当场中断**，不是返回空值后继续。中断会沿调用栈一路向上传染。
2. **年结评分位于「推演一月」链路正中**：`推演一月` → `_年结评分` → `周期评分.结算`。
   一处坏值 ⇒ 整段推演中断 ⇒ 对外表现就是「**游戏打不开**」（无窗口、只有错误面板刷屏）。
3. **所有静态检查都看不见**：gdtoolkit 解析通过、既有 36 道闸门全 PASS、
   `compile_all` 无一报错 —— 因为它只在**该行真正被执行**时才炸。

---

## 三、事故链（可完整复现）

```
game_state.gd:14427   "资源产能": 预估月产出,        ← ★ 方法名漏括号
        ⇒ 快照字典里塞进的不是数值，而是 Callable（typeof=25）
period_settlement.gd:100  float(快照.get("资源产能", 0))   ← ★ 抛错
        ⇒ 结算() 中断 → _年结评分()(14426) 中断 → 推演一月()(14372) 中断
```

线上证据（老大的错误面板）：错误 838 条，栈帧
`结算(period_settlement.gd:100)` ← `_年结评分(game_state.gd:14426)` ← `推演一月(14372)`，
局部变量 `门派等级=10`、`快照 Dictionary(大小 9)`、`期望 Dictionary(大小 18)`。

> `预估月产出` 是方法（`game_state.gd:21788`），全项目另外 7 处调用**都写了 `()`**，
> 只有这两个结算快照漏了 —— 说明是笔误而非设计。

---

## 四、修复清单

| 文件 | 改动 | 性质 |
|---|---|---|
| `game_state.gd:14427` / `:14584` | `预估月产出` → `预估月产出()` | **根因**（启动中断） |
| `period_settlement.gd` | 新增 `_数()` + `_收敛数值()`，`结算()` 入口对 14 个数值键统一净化 | 防单点坏值掀翻整个年结 |
| `game_state.gd:14476` | 删掉格式串尾部悬空的 `： %s`（3 占位符只给 2 参） | 被上一处**掩盖**的同批 bug |
| `game_state.gd:15917` | `_百分比文本` → `_百分比文本(值)`（裸引用使 `值` 被弃用） | 同类「漏括号」 |
| `faction_system.gd:569` | 政策条目格式串补 `%d` 并让 `持续日` 真正落地 | 同类格式串不匹配 |

**排障纪律（本次最重要的经验）**：修掉第一个抛错点后，**必须重跑同一条链路**。
错误会互相掩盖 —— 14476 与 faction 569 都是在修掉前面那个之后才浮现的。

---

## 五、两道新静态守卫

### 5.1 `scan_missing_parens.py` —— 方法名漏括号被当值用

裸写方法名在 GDScript 里是**合法**的（`connect(方法名)` 就靠它），所以必须过滤：
只保留**从未被声明为 var / const / 参数**的方法名，且出现在**要求数值/字符串的槽位**
（字典值、`%` 格式数组）才算强信号。当前结果：**A 级 0 处**，B 级 67 处均为合法回调。

### 5.2 `scan_format_arity.py` —— 格式串占位符 ≠ 实参个数

这类错误同样只在执行到那一行时才抛
`ERROR: String formatting error: not all arguments converted / not enough arguments`。
实现要点（v1 踩过的坑）：必须用**引号/括号状态机**在整份文件文本上扫 ——
实参数组里可能有 `x[i]` 下标（不能用 `\[[^\]]*\]` 抓）、可能跨多行、
格式串可能是多个字面量 `+` 拼接、`[...]` 之后紧跟 `[`/`.`/`(` 的是下标不是实参列表。
当前结果：**全项目 0 处不匹配**。

---

## 六、写代码时的铁律

1. **`float(x)` / `int(x)` 的实参只要来自 `.get()`、字典下标、跨模块字段，就必须先判类型**，
   或统一走模块内的净化函数（参考 `period_settlement._数()`）。
2. **无返回值的 `Func()` 不要写成裸 `Func`**。
3. **格式串占位符个数与实参数组长度必须一眼可数**；多行拼接的格式串尤其危险。
4. **改动 .gd 后跑 `_run_probe.py` 打这条链路**，而不是只看闸门绿。
5. 涉缩进真伪一律用 Python 打 TAB 数 —— `Read` 工具的缩进渲染本会话误报 3 次。

## 七、回归探针

| 探针 | 断言数 | 覆盖 |
|---|---|---|
| `tests/_probe_float_diag.tscn` | 22 | 引擎雷区（A）+ 事故成因（B）+ 净化生效（C/D） |
| `tests/_probe_year_settle.tscn` | — | 直打线上崩溃点 `_年结评分` 全路径 |

运行：`.workbuddy/_run_probe.py res://tests/_probe_float_diag.tscn <日志名>`（headless，无窗口）

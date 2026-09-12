# 报告：headless 实机消报错 + P0-3 战斗快播接线 + UITheme 臆造清零

日期：2026-09-11
范围：运行时报错消除 / 全系统实机验证 / P0-3 战斗快播接线 / UITheme 红线项清零
状态：**完成**（未 commit，遵 F5 前纪律）

---

## 一、结论速览

| 项 | 结果 |
|---|---|
| headless 全系统冒烟 | **零 SCRIPT ERROR / 零 ERROR，EXIT=0，四阶段全执行** |
| 消除运行期 bug | **14 类**（含 3 处 F5 阻断级 PARSE ERROR / 重复声明） |
| P0-3 战斗快播 | 数据层 + UI 层接线完成，实机验证通过 |
| UITheme 臆造红线 | **清零**（`--strict` exit=0，扫 184 个 .gd） |
| 门禁 | 门0 PASS｜门1 PASS｜门2 仅剩 1 项预存文案 lint｜门3 预存基线 |

---

## 二、headless 实机验证（可复用范式）

引擎 `E:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe`：

```
MSYS_NO_PATHCONV=1 <exe> --headless --path E:/Xiuxian/taixuanzongmenlu \
  --scene res://tests/headless_smoke.tscn > .workbuddy/xxx.log 2>&1
```

harness `tests/headless_smoke.tscn` 四阶段：
1. `推演一月(1)` × 100 —— 跨季界，触发全部月度钩子（含 S48/S49/S51 自动调用）
2. 15 个系统动作函数（灵钓/探秘/饲灵/卜算/药圃/论道/商队 + 豆包 5 后端）
3. `save_game()` / `load_game("")` round-trip
4. 强制调用死亡/转世路径（`_道心不稳离去判定`/`_执行兵解成鬼仙`/`_执行飞升`/`_转世判定`）

关键坑：`--script` 模式不注册 autoload `Game`，必须用 `--scene`；单表达式 lambda 不返回调用结果，须 `func(): return X.foo()`（void 函数不能 `return`）。

---

## 三、本轮消除的 14 类运行期 bug

| # | 位置 | 问题 | 修法 |
|---|---|---|---|
| 1 | game_state.gd（6 处：9750/10044/10045/11126/11127/11135/11311） | `Disciple`（RefCounted 对象）被当 Dictionary 调 `.has()` | 改 `属性 != null`；转世成功无条件 `d.转世加成 = 0.2` |
| 2 | auction_system.gd:172 | `it.基础价值` 赋值（Item 无此属性）→ 连锁 Nil 崩 | 删死赋值（价格走 `_基准估值`） |
| 3 | game_state.gd:9315 | `弟子.职位`（真字段是 `身份`） | 改 `弟子.身份`；title_config.csv T008/009/010 cond_param 补「弟子」 |
| 4 | ui/game_ui.gd:290 | 内联 lambda 单行 `if` — GDScript4 解析拒绝（PARSE ERROR，F5 必挂） | 改块式 lambda |
| 5 | disciple.gd:60 | 「剑修」命名 lint | 改「道修」 |
| 6 | **game_state.gd:18764** | **Python 式 `for...else`** — GDScript4 不支持（PARSE ERROR，整个文件无法解析） | 标志位改写，零语义变更 |
| 7 | game_state.gd:1920 / 22875 | `灵兽进化` **重复声明** | 删旧实现，副作用（推演条目+成就复检）补进委托层 |
| 8 | disciple.gd:2414 | `宗门等级` **变量重复声明**（连锁致 disciple/game_state/expedition 全崩） | 删重复块 |
| 9 | family_system.gd:829/838 | `资质`(String) 与 int 比较 + 臆造 `随机生成弟子名()`（无定义） | 用 Disciple 名库取姓名 |
| 10 | beast.gd:496 | `品阶序.key(...)`（Array 无 `.key()`） | 改索引取值 |
| 11 | xuan_rank_system.gd:84 | `Game.仙玉`（无此属性，中断周结算） | 读真字段 `仙玉_绑定 + 仙玉_非绑定` |
| 12 | auction_system.gd | `Game.UIHint` 不存在 | `"UIHint" in Game` 守卫 |
| 13 | AchievementPopupManager.gd | `load(achievement_popup.tscn)` 文件不存在喷 ERROR | 加 `ResourceLoader.exists` 守卫（已有代码兜底） |
| 14 | **item.gd** | **缺 `数量` 字段**：S52 灵材/灵酒/灵食/灵茶堆叠 20+ 处用 `it.数量`，从未声明 → 新建物品分支每次必炸 | 补 `var 数量: int = 1` + to_dict/from_dict/克隆 三处同步 |

备份：`.scratch_backup/*_20260911.gd`（随改随备）。

**根因归纳**：① 字典→对象迁移遗留（`.has()`/`职位`/`数量`）；② 外部批次引入的语法错误（`for...else`/重复声明/单行 lambda）；③ 臆造 API（`随机生成弟子名`/`仙玉`/`UIHint`/`基础价值`）。这与既有认知「外部批次常损坏文件」一致。

---

## 四、P0-3 战斗快播接线

**认知更正**：`ui/battle_scene.gd` 是**完整演出场景**（日志回放/加速/跳过/技能横幅/飘字池），`ui/game_ui.gd:837/853` **已接入** `显示战斗`/`播放战报`。P0-3 不是「从零做快播」，而是补上「历练结算数据 → 回放入口」这条断线。

- **数据层** expedition.gd：结算结果补 `原始战报/攻方快照/守方快照`，写入历练历史记录；**存档仅保留最近 20 场回放数据**（更早记录降级为纯文字战绩，避免存档膨胀）。
- **UI 层** page_explore.gd：史册卡片加「观战回放」按钮 → `Game.UI.播放战报(战报, 攻方快照, 守方快照, 关卡名)`；无回放数据的记录显示「（此战已归档，仅存战绩）」而非静默隐藏。
- **实机验证** `headless_replay6.log`：写入 25 条 → 可取回 25 条、可回放 20 条、裁剪 5 条，文字战绩保留，统计不崩。

设计意义：战力投资（词条/丹纹/装备/境界）从「只体现在数字」变为「结算时刻被看见」。

---

## 五、UITheme 臆造 API 清零（红线项）

`audit_uitheme_calls.py --strict` 扫出**非 backup 代码 40 处臆造调用 / 7 个缺失符号**，分布在 6 个 UI 页：

| 符号 | 命中 | 性质 |
|---|---|---|
| `apply_button_style` | 18 | 语义别名（→ `apply_primary_button_style`） |
| `GRID_SM` | 10 | 缺失 token（紧凑栅格 =6） |
| `apply_title_text` | 7 | 语义别名（→ `apply_section_title`） |
| `apply_aux_font_sized` | 2 | 家族缺口（与 `apply_title/body_font_sized` 对称） |
| `color_accent` | 1 | 缺失 getter（→ `COLOR_TEXT_GOLD`） |
| `C05_PROG_FILL` | 1 | 别名（= `C05_PROG_FILL_CYAN`） |
| `C01_PANEL_B` | 1 | 缺失 token（次级面板/进度条底） |

**风险定性**：打开这 6 页即 `Nonexistent function` 崩。headless 冒烟不覆盖 UI 页面，故此前未暴露——这是「headless 通过 ≠ UI 页可用」的边界。

**处置**：给 `ui_theme.gd` 补齐 7 个符号（单一来源，一处修好 40 处崩点）。同时修审计脚本，**排除 `.workbuddy` / `backup` / `.scratch_backup` 非编译路径**（历史副本噪声长期掩盖真实水位）。

结果：`audit_uitheme_calls.py --strict` → **OK 全部命中真实 API，exit=0，扫 184 个 .gd**。

---

## 六、门禁与遗留

- **门0 归一化 PASS ｜ 门1 gdtoolkit PASS**（ui_theme.gd 语法 OK）
- **门2** 仅剩 1 项：`world_map_system.gd:288`「剑修→道修」命名 lint —— 秘境「剑冢」的**文案**（"为上古剑修陨落之地"），预存、非运行时。**待老大定夺**：改文案 or 加专有名词白名单。
- **门3 pre_f5** 9 项全为预存基线：类型推断扫描 / 配置表 / 弟子终局断言 / 产耗红线 / 静态扫描 / 类型名存在性 / 进度条单源 2 处 / 零战斗触碰（git 环境）/ 死函数 393>380。**本轮改动零引入。**

遗留（非本轮）：
- 豆包休闲 P0/P1（挂载/持久化、UITheme、奇遇受控）—— 已定「豆包按报告返工」。
- 门3 死函数水位（393/380）与 29 死表 —— 并行清理专项。

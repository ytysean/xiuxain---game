# PH7-V7 · 字形探针（实机豆腐块实测）

> doc_id: QA-PH7-V7 ｜ owner: art-director-2（林绘澄）｜ task: PH7-VIS-V7
> **状态：⛔ 本轮未跑（待 team-lead 放行 Godot 时段；本文件为落盘脚手架）**

## 0. 这是什么 / 为什么需要

把「实机字形是否有豆腐块」**取证脚本化**：headless 跑 `tests/_probe_font_glyph2.tscn`，
逐**码位**问引擎「思源黑体有无该字形」。**144 码位白名单是全项目唯一依据**，
后续每一处 UI 文案的符号选择都引它 ⇒ 故本文件必须给**可被第三方复算的原始数据**，而非结论表。

## 1. 前置铁律（不满足勿跑）

1. **同项目禁并发跑 Godot**（争抢 `.godot` 缓存）。跑前确认拍摄链/headless 链**未在跑**。
   → 脚本内置自检：检测到 `Godot*` 进程即**拒绝执行**（除非 `--force`）。
2. 待 team-lead 明确「Godot 空出来了」再执行。

## 2. 本次探测的字体资源与 font_size（明标）

| 项 | 值 |
|---|---|
| 字体资源路径 | `res://art/fonts/SourceHanSansCN-Regular.otf` |
| 字体资源路径 | `res://art/fonts/SourceHanSansCN-Bold.otf` |
| `font_size` | **不适用** —— 探针调 `FontFile.has_char(cp)`，**字形覆盖与字号解耦**（不是按字号栅格化再判）⇒ 无 size 输入 |
| 引擎/场景 | `Godot_v4.7-stable_win64_console.exe` ｜ `res://tests/_probe_font_glyph2.tscn` |
| 探针脚本 | `tests/_probe_font_glyph2.gd`（`码位` 表 `:5-7` 共 **144** 项；`字体路径` `:9-12`） |

## 3. 判据

- 逐码位：`>>>GLYPH <font> U+XXXX 有=<bool>`；`有=false` ⇒ **实机豆腐块**。
- 每字体汇总：`>>>FONT_SUM <font> 缺=<m>/<n>`。
- 本次与前次一致性：`VERDICT=NOTRUN(未跑)`。

## 4. 原始逐码位表（可复算）

> 格式：`U+XXXX | 字符 | Regular: 有/缺 | Bold: 有/缺`。

```
U+XXXX | 字符 | Regular: 有/缺 | Bold: 有/缺
—（待跑；此表由 run_v7_glyph.py 运行时自动填充，逐 144 行）—
```

## 5. 汇总（Regular / Bold 分列）

- **总码位 N = 144**
- Regular：可用 — ｜ 缺 —（待跑）
- Bold：可用 — ｜ 缺 —（待跑）

## 6. ★ 与「旧 144 码位白名单」的差异对照

> 旧基线来源：`.workbuddy/memory/MEMORY.md` 的「★ 字形安全白名单」**条目**（稳定锚 = `tests/_probe_font_glyph2`）。
> ⚠ 依 MEMORY 主册条目「禁止对主册按行号引用」⇒ 本文件**不引 MEMORY 行号**，只引条目标题 + 稳定锚。
> **不许直接覆盖旧结论**：若本次与旧白名单不一致，先查是**探针脚本变了 / 字体变了**，再下结论。

| 类别 | 条数 | 码位 |
|---|---|---|
| 从可用 → 变缺 | 0 | —（待跑） |
| 从缺 → 变可用 | 0 | —（待跑） |
| 新缺·旧未列（需人工看） | 0 | —（待跑） |

## 7. 结论（art-director-2）

- **本轮未跑 ⇒ 无实测结论**。落盘本脚手架 + 一键脚本（含并发自检），待放行后一键出结果并自动回填本文件。

## 8. 复跑方式（一键）

```powershell
# 系统 python 即可（脚本仅标准库，无 numpy/PIL 依赖）
& "D:\Program Files\Python314\python.exe" .workbuddy\_ph7v7\run_v7_glyph.py
```

产物：`.workbuddy/_ph7v7/` 下 `v7_glyph_raw.txt` / `v7_glyph_table.txt` / `v7_glyph_summary.txt`；本文件自动回填。


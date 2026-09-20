# PH6-Q1 · 基线包 headless 冒烟验收报告（g3 包）

- 日期：2026-09-16
- 作者：quality-lead（严守真）
- 对象包：`build/windows/taixuanzongmenlu.exe` = 109,019,648 B（mtime 2026-09-16 20:00:33）；`taixuanzongmenlu.pck` = 405,823,444 B（mtime 20:00:47）= **g3**
- 冒烟日志：`.workbuddy/tmp/_qa_pkg_smoke.txt`（932 B，mtime 20:01:53）

---

## 0. 总判定：**FAIL**（判据 1 未过）

冒烟成功启动、自退、`EXIT=0`，**CSV 无缺失告警（你的 132/132 结论在本机被独立支持）**；
**但**导出包在加载主脚本 `main.gd` 时抛 **Parse Error**（无法 preload 两个 UI 场景）⇒ **主场景无法装配 ⇒ 基线包不可玩**。

---

## 1. 命令原文（前台单进程，无 wrapper）

```bash
cd /e/Xiuxian/taixuanzongmenlu/build/windows
APPDATA='C:\Users\Administrator\AppData\Roaming' \
  ./taixuanzongmenlu.exe --headless --quit-after 30 \
  > /e/Xiuxian/taixuanzongmenlu/.workbuddy/tmp/_qa_pkg_smoke.txt 2>&1
echo "EXIT=$?" >> /e/Xiuxian/taixuanzongmenlu/.workbuddy/tmp/_qa_pkg_smoke.txt
```

- 跑前自证：`tasklist` 无 Godot 进程（20:01:35）；pck = 405,823,444 / 20:00:47（= g3）✓；旧日志已清空 ✓。
- 退出码：**EXIT=0**

## 2. 日志全文（15 行）

```
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

SCRIPT ERROR: Parse Error: Could not preload resource file "res://ui/sect_creation_page.tscn".
   at: GDScript::reload (res://main.gd:3885)
SCRIPT ERROR: Parse Error: Cannot infer the type of "p" variable because the value doesn't have a set type.
   at: GDScript::reload (res://main.gd:3885)
SCRIPT ERROR: Parse Error: Could not preload resource file "res://ui/game_ui.tscn".
   at: GDScript::reload (res://main.gd:3936)
SCRIPT ERROR: Parse Error: Cannot infer the type of "g" variable because the value doesn't have a set type.
   at: GDScript::reload (res://main.gd:3936)
ERROR: Failed to load script "res://main.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2535)
EXIT=0
```

## 3. 四条判据逐条

| # | 判据 | 结果 | 证据 |
|---|---|---|---|
| 1 | 无 fatal / Parse Error / 无法启动类报错 | **FAIL** | 5 条 SCRIPT ERROR（main.gd 2×preload 失败 + 2×类型无法推断 + 1×脚本加载失败） |
| 2 | CSV 真被读到（无「缺失/为空」） | **PASS** | 日志中**无**任何「缺失 / 为空 / FileAccess ERROR」（boot 期 `game_state.gd:4571-4592` 会读十余张 CSV，若被 remap 抢走必报） |
| 3 | EXIT=0 | **PASS** | EXIT=0 |
| 4 | 日志 mtime ≈ 本次执行 | **PASS** | 日志 mtime 20:01:53，执行起始 20:01:35（同一次运行） |

> 对本项目最深风险的结论：**CSV 侧通过**（boot 期读取点零告警，与你的 132/132 字节级取证一致）；**但包因另一处缺陷整体 FAIL**。

## 4. 新发现（高严重度）：导出包内 `ui/*.tscn` 场景缺失

- 引擎层确证：`main.gd:3885` 无法 `preload("res://ui/sect_creation_page.tscn")`、`main.gd:3936` 无法 `preload("res://ui/game_ui.tscn")`。
- 这两个场景的唯一依赖（各自的 `.gd`）**在包内存在且语法 OK**（门1 gdtoolkit：`ALL GDScript PARSE OK (260 files)`），故失败只能是 **`.tscn` 本身不在包内**。
- pck 取证（`_qa_pck_locate.py`，`build/windows/taixuanzongmenlu.pck`，= g3 405,823,444 B）：

  | 目标 | 包内出现次数 |
  |---|---|
  | `res://ui/game_ui.tscn` | **0** |
  | `res://ui/sect_creation_page.tscn` | **0** |
  | `res://ui/top_bar.tscn` / `bottom_tab_bar.tscn` / `sect_home_page.tscn` / `page_disciple.tscn` / `page_explore.tscn` / `page_building.tscn` / `page_daoyou.tscn` / `disciple_detail_page.tscn` | **各 0** |
  | `res://ui/page_atlas.tscn` | 1（**唯一在包内的 ui 场景**） |
  | `res://ui/game_ui.gd` / `page_disciple.gd` | 有（真实条目） |
  | `res://main.tscn` / `res://boot.tscn` / `res://theme/main_theme.tres` | 有（真实条目） |

- ⇒ **几乎全部 `ui/*.tscn` 未被打包**（仅 `page_atlas.tscn` 例外），而 `ui/*.gd`、根场景、主题资源均正常打包。
- **后果链**：`game_ui.gd` 有 **~70 个** `preload("res://ui/page_*.tscn")`（`ui/game_ui.gd:12-81`）⇒ 场景缺失使其无法装配 ⇒ `main.gd` 两个 preload 失败 ⇒ `main.gd` 编译失败 ⇒ 主场景无法加载 ⇒ **包不可玩**。

## 5. 判据 item 3：工程内 userdata 未新增写入（PASS）

| 目录 | 运行前 | 运行后 | 结论 |
|---|---|---|---|
| `Godot/app_userdata/太玄宗门录/logs/godot.log`（工程内） | 6379 B @ 09-10 20:23:04 | **6379 B @ 09-10 20:23:04** | **无变化** ✓ |
| `%APPDATA%\Godot\app_userdata\太玄宗门录\logs\godot2026-09-16T20.01.45.log`（真实 user://） | 不存在 | 1255 B @ 20:01:45 | 新写入落在 **APPDATA**（重定向生效）✓ |

⇒ **`APPDATA` 显式设置有效**：本次运行未触发工程内降级路径。**不升级 P0。**

## 6. 风险 / 观察（非本次判据）

- APPDATA 下另有 `godot2026-09-16T20.02.12 / 20.04.03 / 20.06.31.log` 及 `godot.log@20:07:13` —— 系 **本次冒烟之后他人发起的 Godot 运行**（我的单进程只在 20:01:45 产出一条）。仅记录，不归因。
- 待补：`ui/*.tscn` 缺失的**根因**（`export_filter=all_resources` 本应包含它们）。建议由导出责任人核查 g3 导出的文件枚举路径 / include-exclude / 是否用了自定义文件清单。

## 7. 建议下一步

1. **导出侧核对**：确认 g3 打包为何漏掉 `ui/*.tscn`（对照 `export_presets.cfg` 的 `export_filter=all_resources` / `exclude_filter`）。
2. 修正后**重导** → 我**复跑本冒烟**（同命令同判据）。
3. 可选：以 `--verbose` 复跑一次取更详尽的加载失败原因（需引擎空闲 + 你要的单独 GO）。
4. CSV 侧无需再证（本机已独立支持 132/132）。

## 8. 取证文件

- `.workbuddy/tmp/_qa_pkg_smoke.txt` —— 冒烟 stdout/stderr 全量
- `.workbuddy/tmp/_qa_precheck.txt` / `_qa_postcheck.txt` —— 跑前/跑后进程与 userdata 快照
- `.workbuddy/tmp/_qa_pck_locate.py` / `_qa_pck_locate.txt` —— pck 路径定位（可复跑）
- `.workbuddy/tmp/_qa_pck_tscn.py` / `_qa_pck_tscn.txt` —— pck 内全部 `.tscn` 枚举
- `.workbuddy/tmp/_qa_gdtoolkit.txt` —— 门1 语法自证（260 files OK）

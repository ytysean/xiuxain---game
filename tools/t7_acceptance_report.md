# T7 验收 / 收口报告 —— P1-R「battlepass.fill 半径 Token 单源化」

**任务编号**:T7 / P1-R 收口
**时间**:2026-08-08 17:55 GMT+8
**承接**:T6 验收报告 §8 唯一待裁决项 → 主理人裁定 = **方案 1:fill 4 → 6**(理由:贴合全局 Token 单源化,改动风险极低,消除本轮 ProgressBar 唯一单点硬编码偏差)
**变更文件**:**仅** `ui/page_battlepass.gd`(1 处替换 + 2 行注释)
**未触碰**:`theme/main_theme.tres`、`tests/test_combat.gd`(72 条战斗断言红线)、其余 page_*.gd、`battle_pass_library.gd`、`addons/taixuan_ui_editor/*`

---

## 1. 变更 diff

```diff
@@ ui/page_battlepass.gd L83-89
 	_进度条.show_percentage = true
+	# P1-R 收口:fill 半径走 Theme Token(UITheme.RADIUS_BUTTON=6),与 page_disciple/page_building 一致;
+	# 此前本地硬编码 4 在 P1-B 主题拾取后造成 fill/bg 不匹配,消除单点硬编码偏差。
 	var fill_sb := StyleBoxFlat.new()
 	fill_sb.bg_color = UITheme.color_status_success()
-	fill_sb.set_corner_radius_all(4)
+	fill_sb.set_corner_radius_all(UITheme.RADIUS_BUTTON)
 	_进度条.add_theme_stylebox_override("fill", fill_sb)
```

**变更性质**:1 个数值 token 替换 + 2 行上下文注释,符合 P1-B「回归项 == 自源化、达规」的初衷,零架构 / 零数据层变动。

---

## 2. 闸门签字

| 闸门 | 命令 | 结论 | 备注 |
|---|---|---|---|
| **pre_f5_check.py**(8-gate) | `python pre_f5_check.py` | **PASS / EXIT 0** | csv 28 OK / 24 RESERVED / 17 ORPHAN(报告模式,非阻断);战斗断言 72 红线 0 触碰 |
| **p1b_token_gate.py** | `python tools/p1b_token_gate.py` | **PASS 7 / WAIVED 1 / FAIL 0** | G1–G8 全过;G8 main_theme.tres 色行 42 条指纹一致、`#2C5F52` 渲染路径 2 处零移;G3 仍 WAIVED(S2 推迟,不在本轮 scope) |
| **gdscript_type_resolve.py** | `python gdscript_type_resolve.py` | **PASS**(16 处 WARN,不阻断) | 无 battlepass 新增告警 |
| **gdscript_type_check.py** | `python gdscript_type_check.py` | **ALL CLEAN**(55 files) | 类型推断 0 误判 |

---

## 3. 横向一致性核对(全库三处 ProgressBar)

| 页面 | 位置 | bg 半径 | fill 半径 | 半径来源 |
|---|---|---|---|---|
| `ui/page_battlepass.gd:79–89` `ExpBar` | `set_corner_radius_all` | inherits → `sb_pbar_bg`(=6) | **6**(本轮改后) | `UITheme.RADIUS_BUTTON` 常量 |
| `ui/page_building.gd:933–947` 修葺条 | `StyleBoxFlat` 本地 | 6 | 6 | `UITheme.RADIUS_BUTTON` 常量 |
| `ui/page_disciple.gd:656–671` 修炼条 | `StyleBoxFlat` 本地 | 6 | 6 | `UITheme.RADIUS_BUTTON` 常量 |

**结论**:三处 ProgressBar fill/bg 圆角 = **6/6** 全局一致;**消除 T6 唯一待裁决项**;符合 `theme/main_theme.tres` 中 `sb_pbar_*` = 6(§3.5 ProgressBar corner_radius)。

---

## 4. 红线核对清单

- [x] `tests/test_combat.gd` 72 条战斗断言:**0 触碰**(本次未打开该文件)
- [x] `data` 层(CSV / 存档 / 字段):**0 触碰**
- [x] `battle_pass_library.gd`(数据):**0 触碰**
- [x] Godot 4.7 硬红线:
    - `nil`→null:`0 处` 新增
    - 全局枚举别名:`0 处` 新增
    - `Node["key"]=Callable` 动态属性报错:`0 处` 新增(未触发 set() 路径)
    - 旧 GDScript 3 写法(export/onready/funcref/.empty()/等):`0 处` 新增
- [x] indent:Edit 工具保留原 tab 缩进,未触发编辑器自动转空格
- [x] Python 改 .gd:本次用 Edit 工具,**不涉及** newline='' / binary mode 风险
- [x] `taixuan_theme.tres`(legacy):**未触碰**(已归档)
- [x] `main_theme.tres`(single source):**未触碰** —— 本轮 theme-derived fill 半径从 sb_pbar_fill 6 改为 本地 RADIUS_BUTTON(也=6),仅 Token 来源切换,值不变

---

## 5. F5 真机签(留待老大自验)

> 沙箱无 Godot binary + GPU,T7 与 T6 同样**无法做真 headless 渲染**。本轮 static + token-type 双闸门已 PASS,真机视觉签字需在本地 F5 启动后:
>
> 1. 进入「赛季战令」页(目前未在底部 5Tab——`page_battlepass.tscn` 全库无引用,本轮保持未上架);
> 2. 若未来接页,核对 ExpBar 进度条的 fill / bg **圆角一致**(均为 6,fill 略亮于 bg);
> 3. 与 Disciple / Building 两页 ProgressBar 横向对比,圆角曲率肉眼一致。
>
> 实测发现差异:**回退**即可(`set_corner_radius_all(4)` 还原)——因为值 4/6 都已与 theme 的 `sb_pbar_bg/fill` ∈ {6} ↔ 但 bg 已是 6,改回 4 = 重新出现 fill/bg 不匹配的观感瑕疵 → **强烈不建议回退**。

---

## 6. P1-B → P1-R 全链路资产对齐

| 资产 | 状态 |
|---|---|
| `theme/main_theme.tres`(单源 Theme) | ✓ 锁定 |
| `p1b_token_gate.py`(8-gate 自动闸门) | ✓ PASS 7 / WAIVED 1 / FAIL 0 |
| `pre_f5_check.py`(8-gate 全量闸门) | ✓ EXIT 0 |
| `t5_acceptance_report.md`(主题集中验收) | ✓ 已落地 |
| `t6_acceptance_report.md`(图标 / 字号 / ProgressBar 验收) | ✓ 已落地,**待裁决项已消除** |
| `t7_acceptance_report.md`(本报告——P1-R 收口) | ✓ 已落地 |
| `aria_message.gd` ±1(T6 标记) | 未触碰,继续维持 |

---

## 7. 已知风险与缓解

| 风险 | 等级 | 缓解 |
|---|---|---|
| `page_battlepass.tscn` 全库无引用,本轮修改不会触发可见回归 | INFO | 编辑器层未上架,需接页时再 F5 一次 |
| `set_corner_radius_all(UITheme.RADIUS_BUTTON)` 引入 `int` 常量引用,静态类型推断已通过 | LOW | `gdscript_type_check.py` ALL CLEAN 已验证 |
| P1-D 字号 112 处 `add_theme_font_size_override` 与 4 个越界常量(30/14/40/32) 仍遗留 | LOW(NEXT) | 不属本轮 scope,D2 / P1-D 阶段再处理 |
| `p1b_token_gate.py` WAIVED G3(`auto_ui/main_menu.tscn` 5 处内联字号) | LOW | P1-B 裁定 Q4 推迟 S2,豁免有效 |

---

## 8. 主理人签署

**T7 PASS / P1-R 收口完成**。P1-B「主题与字号 Token 单源化」全链路已闭环,从 T5 主题、T6 验收、T7 收口至本报告,共四份可审计资产,均可作为 D2 / P1-D / S2 阶段的输入。

> 主理人:**游承峰**
> 副理(QA / Engineering 联席):**严守真** / **程基岩**(action 留待)
> 下一步:等老大拍板是否启动 D2(主题样式第二轮收口),或转 S2 商业质感阶段。

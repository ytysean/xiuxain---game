# UI 图标功能映射导出

> 状态：2026-08-02 顶栏资源图标已按写实国漫油画风重出，与 `nav_*`/`bld_*`/`grid_*` 同风格同尺寸  
> 旧 SVG 线稿目录 `ui/assets/icons/` 已废弃删除，备份在 `美术资源/ui_buttons/_legacy_local/ui_assets_icons_backup/`；旧 20×20 扁平资源图标备份在 `art/ui/buttons/_legacy_local/`。

---

## 1. 资产位置

```
res://art/ui/buttons/
```

- 所有新 UI 图标均为 `.png`，写实国漫油画风，墨青底板 `#1E2B28` + 暗金描边 `#C8A86A`。
- 来源清单：`美术资源/ui_buttons/prompts_ui_regen.json`、`美术资源/ui_buttons/03_重出清单_manifest_68.csv`。
- 旧 `ui/assets/icons/` 已删除，不要再引用。

---

## 2. 代码接入方式

### 2.1 单态图标

```gdscript
var tex: Texture2D = UITheme.load_icon("宗门正殿")
```

### 2.2 底部导航 Tab 图标（自动切 normal/selected）

```gdscript
var normal: Texture2D = UITheme.load_tab_icon("宗门", false)
var selected: Texture2D = UITheme.load_tab_icon("宗门", true)
```

### 2.3 路径常量

- `UITheme.ICON_DIR == "res://art/ui/buttons/"`
- 所有图标扩展名 `.png`。

---

## 3. 底部主导航 5 Tab 映射

| Tab 文字 | normal 图标 | selected 图标 | 说明 |
|---------|-------------|---------------|------|
| 宗门 | `nav_jy_normal.png` | `nav_jy_selected.png` | 宗门大殿飞檐剪影（原“经营”图标） |
| 弟子 | `nav_dz_normal.png` | `nav_dz_selected.png` | 道冠修士侧身像 |
| 建筑 | `grid_jz.png` | — | 六宫格“建筑总览”，作为进入建筑页的入口图标 |
| 历练 | `nav_ll_normal.png` | `nav_ll_selected.png` | 古朴飞剑斜插 |
| 纪事 | `nav_js_normal.png` | `nav_js_selected.png` | 卷云玉简 |

> 注：新 nav 图标只有 4+1（宗门/弟子/历练/纪事/更多），“建筑”Tab 用 `grid_jz.png` 补充。

---

## 4. 顶栏资源图标（res_*）

| 资源名称 | 图标文件 | 尺寸 | 画面主体 | 映射键 |
|----------|----------|------|----------|--------|
| 灵石 | `res_lingshi.png` | **256×256** | 暗青底板上的发光灵石晶体 | `"灵石"` / `"lingshi"` |
| 灵气 | `res_lingqi.png` | **256×256** | 暗青底板上的盘旋灵气光晕 | `"灵气"` / `"lingqi"` |
| 草药 | `res_caoyao.png` | **256×256** | 暗青底板上的灵芝仙草 | `"草药"` / `"caoyao"` |
| 声望 | `res_shengwang.png` | **256×256** | 暗青底板上的暗金令旗与官印 | `"声望"` / `"shengwang"` |

> 接入：`UITheme.load_icon("灵石")` 等；已在 `ui_theme.gd::ICON_BY_LABEL` 中接线。
> 说明：2026-08-02 重出，风格与 `nav_*`/`bld_*`/`grid_*` 统一（墨青底板 `#1E2B28` + 暗金描边 `#C8A86A` + 云纹浮雕 + 写实厚涂）。顶栏中 Godot 会缩放到合适大小，若觉 256×256 整体过暗，可改用「无底板纯主体」版本。

---

## 5. 宗门首页六宫格入口映射

| 功能 | 图标文件 | 画面主体 |
|------|----------|----------|
| 建筑总览 | `grid_jz.png` | 层叠楼阁建筑微缩 |
| 弟子录 | `grid_dz.png` | 弟子名册卷轴 |
| 丹器炼制 | `grid_dq.png` | 丹炉与灵剑交叉 |
| 宗门洞府 | `grid_df.png` | 洞府山门牌坊 |
| 任务目标 | `grid_rw.png` | 任务玉牌 |
| 宗门账册 | `grid_zc.png` | 账册算筹 |

---

## 6. 建筑页内部建筑图标（bld_*）

| 建筑名称 | 图标文件 | 画面主体 |
|----------|----------|----------|
| 宗门正殿 | `bld_zd.png` | 宗门正殿巍峨剪影 |
| 接引堂 | `bld_jy.png` | 接引堂迎客牌楼 |
| 灵田 | `bld_lt.png` | 灵田梯田与灵气光点 |
| 矿脉 | `bld_km.png` | 矿脉晶簇 |
| 探微阁 | `bld_tw.png` | 探微阁星盘浑天仪 |
| 丹堂 | `bld_dt.png` | 丹堂三足丹炉 |
| 器堂 | `bld_qt.png` | 器堂锻造铁砧 |
| 功勋阁 | `bld_gx.png` | 功勋阁勋章令旗 |
| 阵堂 | `bld_zt.png` | 阵堂八卦阵盘 |
| 藏书阁 | `bld_cs.png` | 多层楼阁与成捆竹简 |
| 商驿 | `bld_sy.png` | 商驿货箱铜钱 |

---

## 7. 按钮底板（无中心图，纯底板）

| 功能 | normal | hover/悬浮 | press/点击 |
|------|--------|-----------|-----------|
| 主按钮 | `btn_primary_normal.png` | `btn_primary_hover.png` | `btn_primary_press.png` |
| 次按钮 | `btn_secondary_normal.png` | `btn_secondary_hover.png` | `btn_secondary_press.png` |
| 返回按钮 | `btn_back_normal.png` | — | `btn_back_press.png` |
| 子标签 | `subtab_normal.png` | — | `subtab_selected.png` |
| 筛选标签 | `filter_normal.png` | — | `filter_selected.png` |
| 确认弹窗-确认 | `confirm_ok.png` | — | — |
| 确认弹窗-取消 | `confirm_cancel.png` | — | — |
| 确认弹窗-危险 | `confirm_danger.png` | — | — |
| 确认弹窗-关闭 | `confirm_close.png` | — | — |

---

## 8. 玩法入口按钮（play_*）

| 功能 | 图标文件 | 画面主体 |
|------|----------|----------|
| 历练派遣 | `play_lj.png` | 飞剑与远山 |
| 炼制 | `play_lz.png` | 丹炉火纹 |
| 招募 | `play_zm.png` | 令旗与号角 |
| 突破 | `play_tp.png` | 破境雷纹 |

---

## 9. 管理操作按钮（op_*）

| 功能 | 图标文件 | 画面主体 |
|------|----------|----------|
| 任命 | `op_renming.png` | 朱砂官印与绶带 |
| 罢免 | `op_bamian.png` | 破碎官印与断裂绶带 |
| 自动 | `op_auto.png` | 齿轮循环 |
| 调配 | `op_tiaopei.png` | 调配天平 |
| 审核 | `op_shenhe.png` | 朱红毛笔与卷宗 |
| 记录 | `op_jilu.png` | 玉简与毛笔 |

---

## 10. 炼制操作按钮（refine_*）

| 功能 | 图标文件 | 画面主体 |
|------|----------|----------|
| 开始炼制 | `refine_start.png` | 点燃丹火 |
| 加速炼制 | `refine_speed.png` | 加速风纹 |
| 切换丹方 | `refine_recipe.png` | 丹方卷轴与草药 |
| 布阵 | `refine_array.png` | 布阵星图 |

---

## 11. 商店入口按钮（shop_*）

| 功能 | 图标文件 | 画面主体 |
|------|----------|----------|
| 签到 | `shop_signin.png` | 签到日晷 |
| 商城 | `shop_mall.png` | 宝阁楼阁与珍宝 |
| 活动 | `shop_event.png` | 节庆灯笼 |
| 首充 | `shop_firstpay.png` | 首充玉匣 |

---

## 12. 物品品阶槽位（slot_*）

| 品阶 | 图标文件 | 说明 |
|------|----------|------|
| 凡 | `slot_fan.png` | 素银灰品级辉光 |
| 灵 | `slot_ling.png` | 青玉品级辉光 |
| 宝 | `slot_bao.png` | 碧绿品级辉光 |
| 王 | `slot_wang.png` | 赤金品级辉光 |
| 圣 | `slot_sheng.png` | 紫晶品级辉光 |
| 仙 | `slot_xian.png` | 月白品级辉光 |
| 道 | `slot_dao.png` | 混沌玄金品级辉光 |

---

## 13. ui_theme.gd 中的 ICON_BY_LABEL 映射

完整映射见 `ui_theme.gd` 中 `ICON_BY_LABEL` 字典。主要规则：

- `{Tab名}` → normal 图标
- `{Tab名}_选中` → selected 图标
- `建筑` → `grid_jz`（无 selected，fallback 自身）
- 建筑/六宫格/play/op/refine/shop/slot 均按中文语义映射
- 按钮底板映射到 `btn_primary_*` / `btn_secondary_*` / `btn_back_*` / `subtab_*` / `filter_*` / `confirm_*`

---

## 14. 已知缺口与注意事项

1. **微图标未重出**：旧的 `icon_micro_*.png` 仍留在 `art/ui/buttons/_legacy_local/`，如果需要风格统一的微图标（勾选/箭头/关闭/i/更多等），需单独出图或继续沿用 `_legacy_local` 中的版本。
2. **底部“建筑”Tab**：新 nav 资源无建筑图标，当前用 `grid_jz.png`（建筑总览）兜底。
3. **主按钮底板**：PNG 本身是“无中心图的纯净金属底板”，需要在 Godot 中叠加 Label 或 Text 使用。
4. **路径含中文**：`res://art/ui/buttons/` 是中文路径，Godot 4 支持，但如需迁移到 `res://art/buttons/`，批量替换即可。

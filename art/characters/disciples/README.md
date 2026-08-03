# 弟子性格原型套组（路线 A）

> 太玄宗门录 · 纯代码 UI 阶段矢量占位皮。v2.0 写实最终立绘后续走 AI 出图替换。

## 这是什么
按「灵根(5) × 性格(6)」确定性产出的弟子原型资产，**共 30 个原型**（头像 + 立绘各 30）。
游戏生成弟子时按属性 roll 出 `prototype_id`，直接显示对应图——零运行时合成成本。

## 目录
```
generate_prototypes.py   生成器（性格→视觉特征映射的单一事实源）
build_style_board.py     合成系统总览板 style_board.svg
style_board.svg          灵根(列)×性格(行) 总览，先看这张
avatars/                 disciple_{element}_{personality}.svg   头像 120×120 圆形
portraits/               disciple_{element}_{personality}_portrait.svg  立绘 240×320 半身
```

## 命名 / ID 约定
- 灵根序：金0 木1 水2 火3 土4
- 性格序：沉稳0 活泼1 孤傲2 暴躁3 温润4 狡黠5
- `prototype_id = 灵根序 × 6 + 性格序`（0–29）
- 文件名与之一致：`disciple_{element}_{personality}.svg`
  - element ∈ {jin, mu, shui, huo, tu}；personality ∈ {p_chen, p_huo, p_gu, p_bao, p_wen, p_jiao}

## 游戏接入（Godot）
```gdscript
# 生成弟子时
var e_idx = randi_range(0, 4)      # 灵根
var p_idx = randi_range(0, 5)      # 性格
var prototype_id = e_idx * 6 + p_idx
# 加载（建议在 Autoload 建一张 id→路径 表，或按命名规则拼路径）
var tex = load("res://art/characters/disciples/avatars/disciple_%s_%s.svg" % [ELEMENTS[e_idx], PERSONS[p_idx]])
$TextureRect.texture = tex
```
- 头像 → 名册 / 弟子卡 / 招募列表
- 立绘 → 弟子详情弹窗
- 导出 PNG：SVG 可用任意工具批量转 96 / 192px 喂 `TextureRect`（Godot 亦可直接导入 SVG 作纹理）

## 视觉规则（与 UI 锁色同源）
- 锁色：青黛#6E8F88 宣纸米白#F4EFE3 墨青#1E2B28 暗金#C8A86A 朱砂红#B3423D 玉石绿#8FBF9F
- 发色/描边统一墨青；肤色统一暖玉白#E8D8BE（中性，不占五行）；袍服=灵根主+次色
- 性格决定脸（眉眼嘴型 / 发型 / 微配饰 / 气质），灵根决定袍服与灵气色
- 修改映射：只改 `generate_prototypes.py` 内 `_hair / _face / _accessory`，重跑即全量更新

## 已知限制
- 本批为占位皮，脸型仅 6 种（性格区分），灵根只换袍服/灵气色；要更无限随机需上路线 B 分层拼装。
- 需在桌面端编辑器或浏览器预览查看渲染；纯代码沙箱无法本地栅格化校验。

# 太玄宗门录 · 图标三阶生成提示词模板（可直接复制进 WorkBuddy / ImageGen）

> 适用管线：`tier_system.py`（模板/边框/底纹/光效/阶点 全部代码绘制，零积分）。
> 本文件只负责**中心物本体**的生成提示词。边框、底纹、光效、阶点由代码叠加，不要在这类提示词里写边框/底盘/背景。
> 策略：**hybrid** —— 每个原型出 2 张中心物：`{archetype}_normal.png`（凡/灵共用，参数化缩放+光效）与 `{archetype}_top.png`（玄阶专属重绘，材质拉满）。

## 通用硬约束（每张都必须满足）
- 透明背景（PNG alpha），物体居中，占画布约 55%–60%，四周留透明空间给后续边框。
- **构图安全边距（评审强制）**：物体主体必须控制在画布中央 **60% 区域**内，四周保留充足透明留白；**禁止任何部分贴近或超出画布边缘/圆形边界**，防后续裁切残缺。
- **禁止**任何边框/圆环/牌匾/底盘/装饰外框——只画物体本体。
- 1024×1024，禁止文字、禁止水印、禁止人物。
- 写实修仙风，低饱和，清冷玄妙；项目色板：青黛 #6E8F88 / 宣纸米白 #F4EFE3 / 墨青 #1E2B28 / 暗金 #C8A86A / 玉石绿 #8FBF9F / 朱砂 #B3423D。
- 风格参考：凡人修仙传/诛仙 海报质感，厚涂油画、伦勃朗暗调 + rim light。

---

## 一、{archetype}_normal.png 模板（凡阶/灵阶共用）
> 凡/灵共用此图；代码侧用更小占比(35%)和更大占比(45%)+不同底纹/光效区分两档，中心物本体材质取"中性中档"。

```
A {OBJECT} of refined xianxia craftsmanship, {MATERIAL_NORMAL}, with fine surface
weathering, pitting and aged patina, matte non-reflective finish, kept well within
the central 60% of the canvas with ample transparent margin, centered object only,
no frame, no border, no decoration, no background, transparent background,
realistic xianxia fantasy illustration, dark moody lighting, rim light.
```

- `{OBJECT}`：物体英文名（如 `treasure orb` / `jade gourd vessel` / `bronze mirror disc` / `cultivation sword` / `helmet` / `robe` / `pills bottle` / `talisman scroll` / `spirit herb`）。
- `{MATERIAL_NORMAL}`：中性中档材质（如 `warm jade with subtle gold cloud inlays, gentle metallic sheen`）。

**凡/灵的区别由代码负责**（凡=粗粝麻石底+无光+35%；灵=暖白玉底+柔光+45%），所以此图不用区分两档。

---

## 二、{archetype}_top.png 模板（玄阶专属重绘，材质拉满）
> 玄阶(60%占比+深灵玉底+强聚光+星点溢出) 需要真正"稀有宝物"质感，必须单独重绘，禁止用 normal 图放大冒充。
> **发光上限（评审强制）**：合成端 `glow_alpha` 已设为 **0.55**（见 `tier_config.json`），不拉满，预留游戏内 UI 滤镜叠加空间；提示词侧也只写"内蕴微光"，禁止写整体强光/过曝。

```
A top-tier spirit {OBJECT}, {MATERIAL_TOP}, heavy substantial feel,
inner spirit light glowing gently from deep within (NOT overall glowing, NOT glassy,
NOT transparent plastic, NOT crystal, NOT overexposed), fine gold vein inlays,
kept well within the central 60% of the canvas with ample transparent margin,
top-down lighting, dark moody background, centered object only, no frame, no border,
no background, transparent background, realistic xianxia fantasy illustration.
```

- `{OBJECT}`：同上。
- `{MATERIAL_TOP}`：按品类从下表选（去琉璃玻璃感，转厚重金属/蕴光灵玉）：
  - 宝珠类：`icy matte jade body (NOT glossy glass) with raised gilt gold cloud-pattern reliefs, core of condensed cyan inner spirit light, gold vein inlays`
  - 葫芦类：`heavy dark purple-gold metal with subtle gilt worn patina (NOT glassy), two or three embedded dark red gemstones, spirit light only seeping from gem gaps and metal engraved lines`
  - 镜盘类：`bronze-gilt worn metal frame, dark jade mirror face engraved with dark-gold talisman runes, light only from rune groove gaps (NOT an overall bright lightbulb glow)`
  - 武器类：`heavy dark steel blade with gilt guard and jade grip inlay, cold rim light on the edge, inner restrained glow along the fuller`
  - 防具类：`antique dark metal armor piece with jade inserts and gilt rivets,厚重 metallic weight, restrained inner spirit sheen`
  - 丹药类：`icy jade pill bottle with embedded red gem cork, dense spirit pill glowing from within, NOT transparent glass`
  - 符箓类：`ancient jade talisman slip / gold spirit tablet, dark-gold runes glowing from grooves, heavy antique feel`

---

## 三、按品类快速填充示例（宝珠/葫芦/镜盘，已验证可用）
- `orb_normal.png`：A treasure orb of refined xianxia craftsmanship, warm jade with subtle gold cloud inlays and gentle metallic sheen, centered object only, no frame, no border, no background, transparent background, realistic xianxia fantasy illustration, dark moody lighting, rim light.
- `orb_top.png`：A top-tier spirit treasure orb, icy matte jade body with raised gilt gold cloud-pattern reliefs, core of condensed cyan inner spirit light glowing gently from deep within (NOT overall glowing, NOT glassy), fine gold vein inlays, top-down lighting, dark moody background, centered object only, no frame, no border, no background, transparent background, realistic xianxia fantasy illustration.
- `gourd_normal.png`：A jade-inlaid gold gourd vessel of refined xianxia craftsmanship, warm jade body with gold cloud-pattern inlays, gentle metallic sheen, centered object only, no frame, no border, no background, transparent background, realistic xianxia fantasy illustration, dark moody lighting, rim light.
- `gourd_top.png`：A top-tier purple-gold spirit gourd, heavy dark purple-gold metal with subtle gilt worn patina (NOT glassy), embedded dark red gemstones, spirit light only seeping from gem gaps and metal engraved lines, top-down lighting, dark moody background, centered object only, no frame, no border, no background, transparent background, realistic xianxia fantasy illustration.
- `mirror_normal.png`：A jade-framed bronze mirror disc of refined xianxia craftsmanship, jade frame with bronze core, weak reflective sheen, centered object only, no frame, no border, no background, transparent background, realistic xianxia fantasy illustration, dark moody lighting, rim light.
- `mirror_top.png`：A top-tier ancient spirit mirror, bronze-gilt worn metal frame, dark jade mirror face engraved with dark-gold talisman runes, light only from rune groove gaps (NOT overall bright glow), top-down lighting, dark moody background, centered object only, no frame, no border, no background, transparent background, realistic xianxia fantasy illustration.

---

## 四、批量生产工作流（对接 tier_system.py）
1. 用本模板逐原型生成 `{archetype}_normal.png` + `{archetype}_top.png`，落盘到 `icon/_centers/`。
2. 填好 `asset_batch_template.csv` 的 `center_normal` / `center_top` 列（指向 `icon/_centers/` 下文件名）。
3. 跑：
   ```
   python tools/icon_pipeline/tier_system.py --batch --csv asset_batch_template.csv --center-root icon/_centers --out .
   ```
   脚本按 `grade`→`tier` 自动选 center_top(玄) 或 center_normal(凡/灵)，套边框/底纹/光效/阶点，输出到 `icon/<folder>/<id>.png`。
4. 自动质检：中心物占比校验、亮度采样、96px 缩略 `_gradient_small_preview.png`。

# -*- coding: utf-8 -*-
"""
《太玄宗门录》弟子立绘 90 原型提示词包生成器（单一事实源）
- 维度：灵根(5) × 性格(6) × 资质(3) = 90
- 风格锚点：凡人修仙传/诛仙 写实厚涂油画（已样张验证）
- 对齐：design/06-角色与UI/ASSET-弟子性格轴视觉扩展.md v1.3
- 正交修正：头冠等级归资质档；性格只管发型样式+微配饰+神态
- 工业化优化（v1.3 收口）：背景统一深灰纯色+轮廓光；构图标准化头顶留白10%下摆至胯；
  普通档袍服改为素面麻质道袍保修仙制式感（去凡人粗布感）
- 输出：提示词包_90原型.md（人读） + prompts_90.json（机读，可脚本循环出图）
"""
import json, os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
# 风格锚点（固定，铁律对齐 v2.0 §4.1）
# ---------------------------------------------------------------------------
STYLE_CN = ("写实国漫油画风修仙弟子立绘，凡人修仙传/诛仙 电影海报质感，"
            "写实厚涂油画笔触，真人比例东方古风")
STYLE_EN = ("realistic guofeng oil-painting style xianxia disciple character art, "
            "Mortal Cultivation Legends / Zhu Xian cinematic poster quality, "
            "realistic thick-brush oil painting, photorealistic proportions, Eastern ancient costume")

# 背景统一（所有档共用，避免杂乱；资质只改灵气强度）
BG_BASE_CN = "深灰纯色暗背景，微弱环境轮廓光"
BG_BASE_EN = "deep gray solid dark background, faint ambient rim light"

QUALITY_CN = ("严格半身构图锁：1024×1536 竖幅，头顶留白约10%，头整体位于画面上部15%–25%，"
              "头高占图像高度22%–28%，面部无俯仰、头部不歪，发髻/冠饰完整露出且不遮挡眉眼，"
              "下摆至腰下胯部，人物居中对齐，保证头像裁切后位置一致。电影级写实光影，8k 极高细节，"
              "皮肤与丝绸布料金属材质极致写实。避免扁平、卡通、简化、低质量、"
              "二次元、Q版、纯玻璃拟态、杂乱背景、现代元素、多余手指、畸变。")
QUALITY_EN = ("Strict half-body composition lock: 1024×1536 vertical portrait, "
              "headroom ~10%, head placed in upper 15%-25% of frame, "
              "head height 22%-28% of image height, face level without pitch or tilt, "
              "hair bun/crown fully visible and not covering eyebrows/eyes, "
              "hem at hip, centered figure, consistent for avatar cropping. "
              "cinematic realistic lighting, 8k extremely detailed, "
              "hyper-realistic skin and fabric and metal materials. Avoid flat, cartoon, simplified, "
              "low quality, anime, chibi, pure glassmorphism, cluttered background, "
              "modern elements, extra fingers, deformed.")

NEGATIVE_CN = ("赛博朋克、霓虹、数据流、机械义体、现代都市、重金属、夸张妆容、"
               "Q版、卡通、纯玻璃拟态、杂乱背景、真人照片感、毛笔字正文、"
               "低分辨率、多余手指、肢体畸变")
NEGATIVE_EN = ("cyberpunk, neon, data stream, cybernetic limb, modern city, heavy metal, "
               "exaggerated makeup, chibi, cartoon, pure glassmorphism, cluttered background, "
               "real photo, calligraphy body text, low resolution, extra fingers, deformed")

# ---------------------------------------------------------------------------
# 灵根（决定制式底袍色 + 灵气光效色；发色/轮廓统一墨青，肤色暖玉白）
# robe_cn/en = 精英/顶级档（带纹样）；robe_plain = 普通档（素面麻质道袍，保修仙制式感）
# aura_color = 灵气光效颜色（强度由资质档给）
# ---------------------------------------------------------------------------
ELEMENTS = [
    ("jin", "金",
     "暗金色云纹长袍", "暗金色素色无纹道袍", "金色灵气",
     "dark-gold cloud-patterned robe", "dark-gold plain unpatterned taoist robe", "golden spirit"),
    ("mu", "木",
     "玉石绿色古风衣袍", "玉石绿色素色无纹道袍", "翠绿灵气",
     "jade-green ancient robe", "jade-green plain unpatterned taoist robe", "emerald spirit"),
    ("shui", "水",
     "青黛色水墨纹长袍", "青黛色素色无纹道袍", "青蓝灵气",
     "celadon blue-green ink-patterned robe", "celadon plain unpatterned taoist robe", "cyan-blue spirit"),
    ("huo", "火",
     "朱砂红古风衣袍", "朱砂红色素色无纹道袍", "赤红灵气",
     "cinnabar-red ancient robe", "cinnabar-red plain unpatterned taoist robe", "crimson spirit"),
    ("tu", "土",
     "棕褐色古风道袍", "棕褐色素色无纹道袍", "土黄灵气",
     "earthy brown ancient robe", "earthy brown plain unpatterned taoist robe", "ochre spirit"),
]

# ---------------------------------------------------------------------------
# 性格（只管：发型样式 + 眉眼嘴神态 + 姿态 + 非武器微配饰；头冠让位资质档）
# ---------------------------------------------------------------------------
PERSONALITIES = [
    ("chen", "沉稳",
     "整齐束发",
     "平眉、目光沉静平视、唇线抿直无弧",
     "直立端正、肩线平、不偏头",
     "手持拂尘",
     "calm expression, steady level gaze, composed straight lips",
     "upright composed stance, level shoulders",
     "holding a whisk",
     "神情沉静，仪态端正"),
    ("huo2", "活泼",
     "双髻/松散小揪",
     "圆润杏眼、眉梢微扬、浅弧笑露三分笑意",
     "微前倾、头微侧、灵动",
     "发系小银铃、腕缠红绳",
     "round almond eyes, slightly raised brows, light smiling arc",
     "slightly leaning forward, head tilted, lively",
     "small silver bell on hair, red string on wrist",
     "神采灵动，眉眼含笑"),
    ("gu", "孤傲",
     "高束长发、一缕披肩",
     "细长挑眉、半阖凤眼、紧抿一线",
     "侧身、微抬颌、疏离",
     "背后悬古剑（未见鞘光）",
     "thin arched brows, half-lidded phoenix eyes, tightly pressed lips",
     "side stance, slightly raised chin, detached",
     "ancient sword suspended on back",
     "神情疏冷，目光如刃"),
    ("bao", "暴躁",
     "利落短发、散发不羁",
     "浓眉压目、瞪目、齿微露",
     "前倾跨步、肩背绷紧",
     "手戴拳套（或持短斧）",
     "heavy brows over eyes, glaring, teeth slightly bared",
     "leaning forward mid-stride, shoulders tense",
     "wearing gauntlets (or holding short axe)",
     "眉目凌厉，怒意外显"),
    ("wen", "温润",
     "柔顺披发、木簪轻挽",
     "弯眉、笑眼含光、浅笑唇角微扬",
     "微躬、双手拢袖",
     "手捧药葫芦",
     "gentle curved brows, warm smiling eyes, faint smile",
     "slightly bowed, hands gathered in sleeves",
     "holding a medicine gourd",
     "眉眼温和，气质温厚"),
    ("jiao", "狡黠",
     "偏分短束发、耳坠轻晃",
     "单边挑眉、眯眼带笑、斜笑嘴角微歪",
     "抱臂、歪头、似笑非笑",
     "手持半开折扇（或钱袋）",
     "one-sided raised brow, squinting smile, crooked smirk",
     "arms crossed, head tilted, ambiguous smile",
     "holding half-open folding fan (or coin pouch)",
     "眼神狡黠，仪态轻佻"),
]

# ---------------------------------------------------------------------------
# 资质三档（决定：头冠等级 + 灵气光效强度 + 神态精度；不改灵根色/性格神态）
# aura_int 模板含 {c} 占位，组装时填入灵根灵气色
# ---------------------------------------------------------------------------
APTITUDE = [
    ("common", "普通",
     "无冠，仅以粗布带简单束发",
     "几乎无{c}光晕",
     "面容寻常，五官平实",
     "no crown, simple cloth band tied hair",
     "minimal {c} aura",
     "ordinary features, plain face"),
    ("elite", "精英",
     "暗金描边玉冠（或银冠）",
     "淡{c}侧逆光、小范围{c}光晕",
     "眉眼有神采，神态精修气质出众",
     "jade crown (or silver crown) with dark-gold trim",
     "soft {c} backlight, small-range {c} aura",
     "spirited eyes, refined features, outstanding bearing"),
    ("top", "顶级",
     "高冠嵌珠、垂羽饰，宝光流转",
     "浓郁多层{c}光环迸发星点、磅礴体积光与{c}光带环绕，符文隐现",
     "威严从容，面部叙事专属感，材质极致写实",
     "high crown with pearls and feathers, jeweled brocade ornaments",
     "radiant multi-layer {c} halo with starlight, majestic volumetric light, {c} light bands, runes faintly appearing",
     "majestic and composed, exclusive facial narrative, hyper-realistic materials"),
]

# 性别轮换分配（保证 90 张约半数男半数女；批量时改一个词即可互换）
# ---------------------------------------------------------------------------
# 方案A：差异化变体候选池（确定性候选，不死随机；批量脚本随机选注，降低同组同质化）
# 用法：同灵根+同资质+同性别的小组内，出图时把主发型替换为 hair 候选之一，
#       并在神态/微配饰后追加 face / accessory_material 候选之一，即可同组不全一样。
# 主 prompt 仍是确定性基线，不动；variants 仅作批量出图的差异注入来源。
# ---------------------------------------------------------------------------
HAIR_VARIANTS = {
    "chen": ["高束发加玄色发带", "束发嵌玉簪", "半披发束于脑后"],
    "huo2": ["双丸子髻偏侧", "单髻歪扎缀小铃", "松散双马尾"],
    "gu":   ["全束高马尾垂至腰", "侧分长发垂落", "低束发一缕额发"],
    "bao":  ["短发微乱带额发", "寸头额角一道旧痕", "半剃短发硬朗"],
    "wen":  ["低挽发髻木簪斜插", "侧分柔顺披发", "双辫垂肩"],
    "jiao": ["高扎马尾斜挑", "短卷发微蓬", "不对称半扎发"],
}
HAIR_VARIANTS_EN = {
    "chen": ["high ponytail with black band", "hair pinned with jade hairpin",
             "half-loose hair tied at back"],
    "huo2": ["twin buns tilted to one side", "single tilted bun with small bell",
             "loose twin ponytails"],
    "gu":   ["high ponytail down to waist", "side-parted long hair falling",
             "low tie with a strand of fringe"],
    "bao":  ["messy short hair with fringe", "buzz cut with old mark on brow",
             "half-shaved hard short hair"],
    "wen":  ["low bun with slanted wooden pin", "side-parted soft loose hair",
             "twin braids over shoulders"],
    "jiao": ["high tilted ponytail", "short fluffy waves",
             "asymmetric half-tied hair"],
}
FACE_FEATURES = ["清晰下颌线", "高挺鼻梁", "立体颧骨", "饱满天庭", "清瘦面颊"]
FACE_FEATURES_EN = ["defined jawline", "high straight nose bridge",
                    "sculpted cheekbones", "full forehead", "lean cheeks"]
ACC_MAT = ["镶玉点缀", "鎏金描边", "银丝缠绕", "木纹肌理", "宝石嵌饰"]
ACC_MAT_EN = ["jade inlay accents", "gilt edging", "silver wire twining",
              "wood-grain texture", "gemstone inlay"]

# ---------------------------------------------------------------------------
# 方案B：顶级档专属元素（内联进 30 张顶级档主 prompt，确定性，拉开与精英档差距）
# 每个性格 1 处专属华丽细节（服装/信物），在 elite 基础上叠加；不占装备槽。
# ---------------------------------------------------------------------------
TOP_EXCLUSIVE = {
    "chen": ("肩胸织锦暗纹护肩，腰封繁复玉扣悬垂",
             "brocade dark-pattern shoulder guards, ornate jade waist buckle hanging"),
    "huo2": ("衣摆流苏飘带轻扬，多重银铃缀饰",
             "tasseled ribbons fluttering on hem, multiple silver bells"),
    "gu":   ("肩绕纱质披帛，冷银描边流转",
             "gauze shawl over shoulders, cold silver trim flowing"),
    "bao":  ("皮质护肩嵌铆钉，金属护臂硬朗",
             "leather studded shoulder guard, metal bracer hard"),
    "wen":  ("衣襟刺绣药草纹，暖玉腰佩悬垂",
             "embroidered herb pattern on collar, warm-jade waist pendant"),
    "jiao": ("折扇暗金描边，耳坠长流苏垂落",
             "folding fan with dark-gold trim, long tassel earring"),
}


def gender_for(e_idx, p_idx):
    return "男子" if (e_idx + p_idx) % 2 == 0 else "女子"

GENDER_EN = {"男子": "male", "女子": "female"}
AGE_MOD_CN = {"少年": "面容年轻，少年气质", "青年": "青年面容",
              "中年": "面容成熟沉稳，略带风霜", "长老": "老者须发，仙风道骨质"}
AGE_MOD_EN = {"少年": "youthful face", "青年": "young adult face",
              "中年": "mature weathered face", "长老": "elderly with beard and immortal bearing"}


def build_prompt(e_idx, p_idx, a_idx):
    ek, en_cn, robe_cn, robe_plain_cn, aura_color_cn, robe_en, robe_plain_en, aura_color_en = ELEMENTS[e_idx]
    pk, pn, hair_cn, face_cn, pose_cn, acc_cn, face_en, pose_en, acc_en, extra_cn = PERSONALITIES[p_idx]
    ak, an, crown_cn, aura_int_cn, feat_cn, crown_en, aura_int_en, feat_en = APTITUDE[a_idx]
    gender_cn = gender_for(e_idx, p_idx)
    gender_en = GENDER_EN[gender_cn]

    # 普通档用素色无纹道袍，精英/顶级用纹样袍
    robe_cn_use = robe_plain_cn if ak == "common" else robe_cn
    robe_en_use = robe_plain_en if ak == "common" else robe_en
    aura_int_cn_use = aura_int_cn.format(c=aura_color_cn)
    aura_int_en_use = aura_int_en.format(c=aura_color_en)

    # 方案B：顶级档内联专属元素（确定性，拉开与精英档差距）
    top_ex_cn = ""
    top_ex_en = ""
    if ak == "top":
        top_ex_cn, top_ex_en = TOP_EXCLUSIVE[pk]

    cn = (f"{STYLE_CN}{gender_cn}。"
          f"{robe_cn_use}（灵根色制式袍，保留宗门制式领缘），{crown_cn}，{hair_cn}，"
          f"{face_cn}，{pose_cn}，{acc_cn}{('，' + top_ex_cn) if top_ex_cn else ''}。"
          f"{BG_BASE_CN}，{aura_int_cn_use}，{feat_cn}。{extra_cn}。"
          f"{QUALITY_CN}")
    en = (f"{STYLE_EN}, {gender_en}. "
          f"{robe_en_use} (sect base robe in element color, with sect collar trim), {crown_en}, {hair_cn} style, "
          f"{face_en}, {pose_en}, {acc_en}{(', ' + top_ex_en) if top_ex_en else ''}. "
          f"{BG_BASE_EN}, {aura_int_en_use}, {feat_en}. {extra_cn}. "
          f"{QUALITY_EN}")
    pid = f"{ek}_{pk}_{ak}"
    return {
        "id": pid,
        "element": en_cn, "element_key": ek,
        "personality": pn, "personality_key": pk,
        "aptitude": an, "aptitude_key": ak,
        "gender": gender_cn,
        "prompt_cn": cn,
        "prompt_en": en,
        "variants": {
            "hair": {"cn": HAIR_VARIANTS[pk], "en": HAIR_VARIANTS_EN[pk]},
            "face_feature": {"cn": FACE_FEATURES, "en": FACE_FEATURES_EN},
            "accessory_material": {"cn": ACC_MAT, "en": ACC_MAT_EN},
        },
    }


def main():
    records = []
    for e_idx in range(len(ELEMENTS)):
        for p_idx in range(len(PERSONALITIES)):
            for a_idx in range(len(APTITUDE)):
                records.append(build_prompt(e_idx, p_idx, a_idx))

    with open(os.path.join(OUT_DIR, "prompts_90.json"), "w", encoding="utf-8") as f:
        json.dump({
            "meta": {
                "game": "太玄宗门录",
                "style": "凡人修仙传/诛仙 写实厚涂油画",
                "dimensions": "灵根(5) × 性格(6) × 资质(3) = 90",
                "negative_cn": NEGATIVE_CN,
                "negative_en": NEGATIVE_EN,
                "age_modifiers_cn": AGE_MOD_CN,
                "age_modifiers_en": AGE_MOD_EN,
                "gender_swap": "将提示词中'男子'/'女子'互换即可；英文 male/female 互换",
                "bg_unify": "所有档共用深灰纯色暗背景+轮廓光，资质只改灵气强度",
                "composition": "严格半身构图锁：1024×1536，头顶留白约10%，头位于画面上部15%-25%，头高占图高22%-28%，面部无俯仰、头部不歪，发髻/冠饰不遮眉眼，下摆至胯，人物居中",
                "common_robe": "普通档素色无纹道袍，保留宗门制式领缘，去凡人粗布感",
                "ref_doc": "design/06-角色与UI/ASSET-弟子性格轴视觉扩展.md v1.3",
                "wear_note": "立绘锁定本体基础态；实穿法袍/道冠不在立绘体现，走装备UI面板（见规范第十章）",
                "variants_a": "方案A差异化变体候选池：每条 prompts 含 variants.hair(发型3选)/face_feature(面部弱特征)/accessory_material(配饰材质)。批量出图时随机选注其一，降低同灵根+同资质+同性别小组的同质化；主prompt仍是确定性基线。",
                "variants_b": "方案B顶级档专属元素：顶级档主prompt已内联性格专属华丽细节（护肩/披帛/护臂/腰佩等），确定性拉开与精英档差距，不占装备槽。",
            },
            "prompts": records,
        }, f, ensure_ascii=False, indent=2)

    lines = []
    lines.append("# 《太玄宗门录》弟子立绘 90 原型提示词包\n")
    lines.append("> 风格：凡人修仙传/诛仙 写实厚涂油画（已样张验证）\n")
    lines.append("> 维度：灵根(5) × 性格(6) × 资质(3) = 90\n")
    lines.append("> 对齐：ASSET-弟子性格轴视觉扩展.md v1.3\n")
    lines.append("> 正交修正：头冠等级归资质档；性格只管发型样式+神态+非武器微配饰\n")
    lines.append("> 工业化：背景统一深灰纯色+轮廓光；构图标准化；普通档素面麻质道袍保制式感\n")
    lines.append("> 穿戴：立绘锁定本体基础态，实穿法袍/道冠走装备UI面板（第十章）\n")
    lines.append("\n## 通用负向词（每次出图必带）\n")
    lines.append(f"- 中文：`{NEGATIVE_CN}`\n")
    lines.append(f"- 英文：`{NEGATIVE_EN}`\n")
    lines.append("\n## 背景 / 构图 / 普通档 统一规则（工业化，全部提示词已内置）\n")
    lines.append(f"- 背景：{BG_BASE_CN}（资质只改灵气强度，不换背景）\n")
    lines.append("- 构图：严格半身构图锁，1024×1536，头顶留白约10%，头位于画面上部15%–25%，"
                 "头高占图高22%–28%，面部无俯仰、头部不歪，发髻/冠饰不遮眉眼，"
                 "下摆至腰下胯部，人物居中（头像裁切齐平）\n")
    lines.append("- 普通档袍服：素色无纹道袍 + 宗门制式领缘，去凡人粗布感，五灵根普通档均保修仙制式感\n")
    lines.append("\n## 差异化变体（方案A：降低同组同质化，批量脚本随机选注）\n")
    lines.append("> 同灵根+同资质+同性别的小组内视觉趋同属正常现象。每条原型在 JSON 的 `variants` 字段提供候选池，批量出图时从中随机选注，即可同组不全一样，且主 prompt 仍是确定性基线（可审核）。\n")
    lines.append("- **发型变体 hair**（替换主发型，3 选）：\n")
    for pk, pn, *_ in PERSONALITIES:
        hs = " / ".join(HAIR_VARIANTS[pk])
        lines.append(f"  - {pn}（{pk}）：{hs}\n")
    lines.append("- **面部弱特征 face_feature**（追加 1 项，轮廓/骨骼类，不与神态冲突）：" + " / ".join(FACE_FEATURES) + "\n")
    lines.append("- **配饰材质 accessory_material**（追加 1 项）：" + " / ".join(ACC_MAT) + "\n")
    lines.append("\n## 顶级档专属元素（方案B：确定性内联，拉开与精英档差距）\n")
    lines.append("> 顶级档主 prompt 已直接内置下列性格专属华丽细节（不占装备槽）：\n")
    for pk, pn, *_ in PERSONALITIES:
        lines.append(f"  - {pn}（{pk}）：{TOP_EXCLUSIVE[pk][0]}\n")
    lines.append("\n## 性别 / 年龄 修饰（正交，默认 青年，批量可整体替换）\n")
    lines.append("- 性别：提示词中 `男子`↔`女子` 互换；英文 `male`↔`female` 互换。90 张已按 `(灵根序+性格序)%2` 轮换约半数男半数女。\n")
    for an, ac in AGE_MOD_CN.items():
        lines.append(f"- 年龄 `{an}`：中文追加「{ac}」；英文追加「{AGE_MOD_EN[an]}」。\n")

    for e_idx, (ek, en_cn, *_rest) in enumerate(ELEMENTS):
        lines.append(f"\n---\n\n## 灵根：{en_cn}（{ek}）\n")
        for p_idx, (pk, pn, *_p) in enumerate(PERSONALITIES):
            lines.append(f"\n### 性格：{pn}（{pk}）\n")
            for a_idx, (ak, an, *_a) in enumerate(APTITUDE):
                rec = records[e_idx * 18 + p_idx * 3 + a_idx]
                lines.append(f"**{an}档 · {rec['gender']}** `{rec['id']}`\n")
                lines.append(f"> {rec['prompt_cn']}\n")
                lines.append(f"> *EN:* {rec['prompt_en']}\n")

    lines.append("\n---\n\n## 六性格 ControlNet 姿态 / 构图参考\n")
    lines.append("> 立绘统一半身构图锁（1024×1536，头顶留白约10%，头位于画面上部15%–25%，"
                 "头高占图高22%–28%，面部无俯仰、头不歪，发髻/冠饰不遮眉眼，下摆至胯，人物居中）。"
                 "ControlNet 锁定人体骨架/比例，性格仅切换神态与微配饰。\n")
    ctrl = {
        "chen": "直立端正，肩线水平，头部居中不偏，重心垂直。OpenPose：脊柱竖直，双臂自然垂落或一手持拂尘于身前。",
        "huo2": "微前倾约 5°，头向画面左侧轻侧，重心略前移显灵动。OpenPose：上半身前倾，头颈微转，手腕红绳可加小动作。",
        "gu": "侧身约 30°，下颌微抬，目光侧前。OpenPose：躯干侧向，一肩靠前，背后古剑竖直悬于脊线。",
        "bao": "前倾跨步，双肩绷紧前耸，重心在前脚。OpenPose：前腿弓步，双臂张力外展或握拳于前。",
        "wen": "微躬约 8°，双肩内收，双手拢于袖中于腹前。OpenPose：脊柱略前曲，双臂交于身前，药葫芦捧于袖口。",
        "jiao": "抱臂，头向一侧歪约 10°，似笑非笑。OpenPose：双臂交叉于胸前，颈部侧倾，折扇半开持于臂弯。",
    }
    for pk, pn, *_ in PERSONALITIES:
        lines.append(f"- **{pn}（{pk}）**：{ctrl[pk]}\n")
    lines.append("\n> 已出样张（samples/ 目录）可直接作为 ControlNet / img2img 参考图：\n")
    lines.append("> - 沉稳·金·男（精英档）→ 端正直立参考\n")
    lines.append("> - 孤傲·水·男（精英档）→ 侧身抬颌参考\n")
    lines.append("> - 温润·木·女（精英档）→ 微躬拢袖参考\n")
    lines.append("> - 普通/顶级档（沉稳·金·男）→ 资质光效量级参考\n")

    with open(os.path.join(OUT_DIR, "提示词包_90原型.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"OK: {len(records)} prompts generated.")
    print("  - 提示词包_90原型.md")
    print("  - prompts_90.json")


if __name__ == "__main__":
    main()

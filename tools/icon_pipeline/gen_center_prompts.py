# -*- coding: utf-8 -*-
"""为每原型生成 normal/top 中心物提示词(JSON清单)。
每张提示词以唯一 slug 前缀开头(如 zzorb_normal), 便于 ImageGen 落盘后按前缀重命名。
仅对 CSV 中实际出现的 tier 生成(凡/灵->normal, 玄->top), 避免无效张数。
"""
import csv, json, os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CSV_PATH = os.path.join(ROOT, "tools/icon_pipeline/asset_batch_template.csv")
OUT_JSON = os.path.join(ROOT, "tools/icon_pipeline/center_prompts.json")

# 每原型: (object_en, material_normal, material_top)
A = {
    # ---- 材料 ----
    "herb":        ("cluster of spirit herbs with slender leaves",
                    "fresh green jade-like leaves with faint vein sheen",
                    "icy jade herb with condensed cyan spirit light at the core, fine gold vein inlays"),
    "beast":       ("spirit beast fang and claw relic",
                    "bone-white surface with subtle dark streaks",
                    "ancient beast bone with embedded dark red gemstone, spirit light seeping from grooves"),
    "ore":         ("raw spirit ore chunk",
                    "rough dark stone with faint mineral specks, matte",
                    "heavy dark metal ore with gilt veins and inner cyan glow from within"),
    "crystal":     ("spirit crystal cluster",
                    "translucent pale crystal with soft inner sheen",
                    "icy jade crystal with condensed cyan core light, fine gold vein inlays"),
    "fabric":      ("bolt of spirit silk fabric",
                    "fine pale silk with subtle woven texture",
                    "woven spirit silk with gold thread patterns and faint inner glow"),
    "mat_special": ("rare spirit material relic",
                    "weathered dark material with aged patina, matte",
                    "rare spirit relic of heavy dark metal with gilt inlays and inner glow"),
    "food":        ("spirit fruit",
                    "matte jade-green fruit with a small leaf",
                    "glossy spirit fruit with core glow and gold rim"),
    # ---- 丹药 ----
    "pill":        ("spirit pill bottle with rounded pills",
                    "jade bottle with rounded pills, subtle sheen",
                    "icy jade pill bottle with embedded red gem cork, dense spirit pill glowing from within"),
    # ---- 符箓 ----
    "talisman":    ("talisman slip",
                    "pale talisman paper with faint red rune",
                    "ancient jade talisman slip with dark-gold runes glowing from grooves, heavy antique feel"),
    # ---- 装备 ----
    "weapon":      ("cultivation melee weapon",
                    "steel blade with simple guard, matte finish",
                    "heavy dark steel blade with gilt guard and jade grip inlay, cold rim light, restrained inner glow"),
    "helmet":      ("xianxia helmet",
                    "dark metal helm with simple rivets, matte",
                    "antique dark metal helm with jade crest insert and gilt rivets, restrained inner spirit sheen"),
    "robe":        ("folded xianxia robe",
                    "pale fabric robe with simple trim, matte",
                    "ceremonial robe of heavy dark silk with gold embroidery and jade clasps, faint glow"),
    "bracer":      ("xianxia arm guard",
                    "leather bracer with metal band, matte",
                    "heavy dark metal bracer with jade core and gilt bands, restrained glow"),
    "boot":        ("xianxia boot",
                    "leather boot with simple sole, matte",
                    "heavy dark leather boot with gilt trim and jade accent, faint glow"),
    "belt":        ("xianxia belt sash",
                    "woven belt with simple buckle, matte",
                    "heavy dark sash with gold clasp and jade plaque, restrained glow"),
    "accessory":   ("xianxia pendant accessory",
                    "simple jade pendant, matte",
                    "heavy dark metal pendant with red gem and gilt inlays, inner glow"),
    # ---- 装备图纸 / 套装 ----
    "blueprint":   ("crafting blueprint scroll",
                    "rolled scroll with faint schematic lines, matte",
                    "ancient gold-trimmed scroll with spirit schematic glow"),
    "setpiece":    ("set armor emblem insignia",
                    "metal insignia plaque, matte",
                    "heavy dark gold emblem with jade inlay and spirit glow"),
    # ---- 功法 ----
    "scripture":   ("cultivation scripture scroll",
                    "classic scroll with title band, matte",
                    "ancient jade-bound scripture with gold seal and rune glow"),
    # ---- 本命法宝 ----
    "sword":       ("spirit flying sword",
                    "slender jade sword with simple guard, matte",
                    "heavy dark steel flying sword with gilt guard and jade grip, cold rim light, restrained inner glow"),
    "tower":       ("spirit pagoda",
                    "jade miniature pagoda with tiers, matte",
                    "heavy dark gold pagoda with jade eaves and inner cyan glow"),
    "mirror":      ("spirit mirror disc",
                    "bronze-framed stone mirror with weathered worn surface, pitting and aged patina, matte non-reflective",
                    "bronze-gilt worn metal frame, dark jade mirror face engraved with dark-gold talisman runes, light only from rune groove gaps"),
    "flag":        ("spirit banner",
                    "cloth banner with simple pole, matte",
                    "heavy dark banner with gold trim and jade tassel, faint glow"),
    "orb":         ("spirit orb",
                    "warm jade orb with subtle gold cloud inlays, gentle sheen",
                    "icy matte jade orb with raised gilt gold cloud-pattern reliefs, core of condensed cyan inner spirit light, gold vein inlays"),
    # ---- 普通法宝 ----
    "treasure_def":("defensive spirit treasure",
                    "rounded jade shield-charm with simple band, matte",
                    "heavy dark gold shield-charm with jade boss and inner glow"),
    "treasure_atk":("offensive spirit treasure",
                    "jade spike-charm with sharp form, matte",
                    "heavy dark metal spike-treasure with gilt edge and inner glow"),
    "treasure_sup":("support spirit treasure",
                    "jade ring-charm with simple inlay, matte",
                    "heavy dark gold ring-treasure with jade inlay and faint glow"),
    # ---- 渡劫 / 任务 / 阵图 ----
    "tribulation": ("tribulation thunder motif relic",
                    "stylized lightning bolt relic, matte",
                    "heavy dark thunder relic with gold arc inlays and inner glow"),
    "quest":       ("quest token",
                    "simple jade token with marking, matte",
                    "heavy dark gold quest token with jade inlay and glow"),
    "array_book":  ("array formation scroll",
                    "rolled formation diagram scroll, matte",
                    "ancient gold-trimmed formation scroll with spirit glow"),
}

NORMAL_TPL = ("A {OBJ} of refined xianxia craftsmanship, {MAT}, with fine surface weathering, "
              "pitting and aged patina, matte non-reflective finish, kept well within the central "
              "60% of the canvas with ample transparent margin, centered object only, no frame, no "
              "border, no decoration, no background, transparent background, realistic xianxia fantasy "
              "illustration, dark moody lighting, rim light.")

TOP_TPL = ("A top-tier spirit {OBJ}, {MAT}, heavy substantial feel, inner spirit light glowing gently "
           "from deep within (NOT overall glowing, NOT glassy, NOT transparent plastic, NOT crystal, NOT "
           "overexposed), fine gold vein inlays, kept well within the central 60% of the canvas with ample "
           "transparent margin, top-down lighting, dark moody background, centered object only, no frame, "
           "no border, no background, transparent background, realistic xianxia fantasy illustration.")


def main():
    rows = list(csv.DictReader(open(CSV_PATH, encoding="utf-8-sig")))
    need = {}
    for r in rows:
        a = (r.get("archetype") or "").strip()
        t = (r.get("tier") or "").strip()
        if a not in A:
            continue
        need.setdefault(a, set())
        if t in ("low", "mid"):
            need[a].add("normal")
        elif t == "high":
            need[a].add("top")

    entries = []
    for a, kinds in sorted(need.items()):
        obj, mat_n, mat_t = A[a]
        if "normal" in kinds:
            slug = f"zz{a}_normal"
            prompt = slug + " " + NORMAL_TPL.format(OBJ=obj, MAT=mat_n)
            entries.append({"target": f"{a}_normal.png", "slug": slug,
                            "tier": "normal", "archetype": a, "prompt": prompt})
        if "top" in kinds:
            slug = f"zz{a}_top"
            prompt = slug + " " + TOP_TPL.format(OBJ=obj, MAT=mat_t)
            entries.append({"target": f"{a}_top.png", "slug": slug,
                            "tier": "top", "archetype": a, "prompt": prompt})

    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(entries, f, ensure_ascii=False, indent=2)
    print(f"写入 {len(entries)} 条 -> {OUT_JSON}")
    from collections import Counter
    print("normal:", sum(1 for e in entries if e["tier"] == "normal"),
          " top:", sum(1 for e in entries if e["tier"] == "top"))


if __name__ == "__main__":
    main()

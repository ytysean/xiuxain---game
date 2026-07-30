"""
《太玄宗门录》图标后处理 + 全量合成管线
- clean_base: 把任意 AI 出图统一裁成"居中圆形牌匾"（圆外强制透明，顺带去水印/雾）
- make_grade_badge: 品阶色角徽（右上角，gacha 标配）
- compose_item: clean base + 贴角徽 -> 最终 icon/<folder>/<id>.png
- compose_all: 按 manifest 全量 341 张，含底图缓存
"""
import csv, os, sys
from PIL import Image, ImageDraw

ROOT = "E:/Xiuxian/taixuanzongmenlu"
BASES = os.path.join(ROOT, "icon", "_bases")
CLEAN = os.path.join(ROOT, "icon", "_bases", "_clean")
MANIFEST = os.path.join(ROOT, "icon_manifest.csv")
SIZE = 1024
KEEP_R = 460
ALPHA_MIN = 18
BADGE_CX, BADGE_CY = 908, 116
BADGE_R = 78
GOLD = (200, 168, 106, 255)

GRADE_COLORS = {
    "凡品": (183, 178, 168, 255),
    "灵品": (127, 191, 160, 255),
    "宝品": (111, 163, 199, 255),
    "王品": (168, 143, 208, 255),
    "圣品": (214, 154, 92, 255),
    "仙品": (226, 197, 102, 255),
    "道品": (194, 80, 74, 255),
}

ALIASES = {
    "talisman": "tal_off",
    "skill_slip": "sk_sup",
    "treasure_orb": "tr_orb",
    "equip_sword": "eq_sword",
    "equip_robe": "eq_robe",
    "array_book": "arr_book",
}


def clean_base(img, size=SIZE, keep_r=KEEP_R, alpha_min=ALPHA_MIN):
    """把 AI 出图统一成'居中圆形牌匾'：极淡雾清掉 + 圆外强制透明。"""
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    if img.size != (size, size):
        img = img.resize((size, size), Image.LANCZOS)
    px = img.load()
    cx = cy = size // 2
    for y in range(size):
        for x in range(size):
            r, g, b, a = px[x, y]
            if a < alpha_min:
                px[x, y] = (r, g, b, 0)
    for y in range(size):
        dy = y - cy
        for x in range(size):
            dx = x - cx
            if dx * dx + dy * dy > keep_r * keep_r:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
    return img


def make_grade_badge(grade, size=SIZE):
    """生成品阶角徽（RGBA 透明底），贴到右上角。"""
    color = GRADE_COLORS.get(grade, GRADE_COLORS["凡品"])
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for r, a in [(BADGE_R + 16, 36), (BADGE_R + 8, 56)]:
        d.ellipse([BADGE_CX - r, BADGE_CY - r, BADGE_CX + r, BADGE_CY + r],
                  fill=(color[0], color[1], color[2], a))
    d.ellipse([BADGE_CX - BADGE_R - 4, BADGE_CY - BADGE_R - 4,
               BADGE_CX + BADGE_R + 4, BADGE_CY + BADGE_R + 4],
              outline=GOLD, width=8)
    d.ellipse([BADGE_CX - BADGE_R, BADGE_CY - BADGE_R,
               BADGE_CX + BADGE_R, BADGE_CY + BADGE_R],
              fill=color)
    d.ellipse([BADGE_CX - BADGE_R + 12, BADGE_CY - BADGE_R + 12,
               BADGE_CX + BADGE_R - 12, BADGE_CY + BADGE_R - 12],
              outline=(color[0], color[1], color[2], 180), width=3)
    hl = (min(255, color[0] + 50), min(255, color[1] + 50),
          min(255, color[2] + 50), 160)
    d.arc([BADGE_CX - BADGE_R + 6, BADGE_CY - BADGE_R + 6,
           BADGE_CX + BADGE_R - 6, BADGE_CY + BADGE_R - 6],
          start=200, end=260, fill=hl, width=4)
    return img


def compose_item(base_img, grade, out_path, size=SIZE):
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas = Image.alpha_composite(canvas, base_img)
    canvas = Image.alpha_composite(canvas, make_grade_badge(grade, size))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    canvas.save(out_path)


def _innate_obj(name):
    for k, b in [("剑", "inn_sword"), ("塔", "inn_tower"), ("镜", "inn_mirror"),
                 ("幡", "inn_banner"), ("珠", "inn_orb")]:
        if k in name:
            return b
    return "inn_orb"


def _normal_obj(name):
    if "镜" in name:
        return "tr_mirror"
    if "葫" in name:
        return "tr_gourd"
    return "tr_orb"


def base_for(row):
    folder = row["folder"]; typ = row["type"]; name = row["item_name"]
    if folder == "material":
        m = {"灵草类": "mat_herb", "矿石类": "mat_ore", "织物类": "mat_cloth",
             "妖兽类": "mat_beast", "晶石类": "mat_crystal", "食材类": "mat_food",
             "特殊材料": "mat_special"}
        return m.get(typ, "mat_special")
    if folder == "pill":
        return "pill_special" if typ == "特殊类" else "pill_bottle"
    if folder == "talisman":
        return "tal_off" if typ in ("攻击类", "控制类", "特殊类") else "tal_sup"
    if folder == "equip":
        if typ == "本命法宝":
            return _innate_obj(name)
        m = {"武器": "eq_sword", "衣袍": "eq_robe", "头盔": "eq_helm",
             "护腕": "eq_bracer", "腰带": "eq_belt", "靴子": "eq_boots",
             "配饰": "eq_acc"}
        return m.get(typ, "eq_acc")
    if folder == "equip_blueprint":
        return "bp_blueprint"
    if folder == "equip_set":
        return "set_emblem"
    if folder == "skill":
        return "sk_atk" if typ in ("攻击", "控制") else "sk_sup"
    if folder == "array":
        return "arr_book" if typ == "array_book" else "arr_shard"
    if folder == "treasure_innate":
        return _innate_obj(name)
    if folder == "treasure":
        return _normal_obj(name)
    if folder == "tribulation":
        m = {"渡劫丹": "tri_pill", "护阵": "tri_array", "长老护法": "tri_guard",
             "防御法宝": "tri_def"}
        return m.get(typ, "tri_def")
    if folder == "quest":
        return "q_token" if typ == "主线信物" else "q_frag"
    return "mat_herb"


def resolve_base_path(base_name):
    p = os.path.join(BASES, base_name + ".png")
    if os.path.exists(p):
        return p
    if base_name in ALIASES:
        pa = os.path.join(BASES, ALIASES[base_name] + ".png")
        if os.path.exists(pa):
            return pa
    return None


def dest_path(row):
    folder = row["folder"]; rid = row["item_id"]
    if folder == "array" and row["type"] == "array_book":
        d = os.path.join(ROOT, "icon", "array", "book")
    else:
        d = os.path.join(ROOT, "icon", folder)
    return os.path.join(d, rid + ".png")


def main():
    check_only = "--check" in sys.argv
    os.makedirs(CLEAN, exist_ok=True)
    with open(MANIFEST, encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))

    cache = {}
    missing = set()
    done = 0
    for r in rows:
        b = base_for(r)
        if b in cache:
            cleaned = cache[b]
        else:
            bp = resolve_base_path(b)
            if bp is None:
                missing.add(b)
                cache[b] = None
                continue
            raw = Image.open(bp).convert("RGBA")
            cleaned = clean_base(raw)
            cache[b] = cleaned
        if cleaned is None:
            continue
        grade = r["grade"] if r["grade"] in GRADE_COLORS else "凡品"
        out = dest_path(r)
        if check_only:
            done += 1
            continue
        compose_item(cleaned, grade, out)
        done += 1

    if not check_only:
        for b, im in cache.items():
            if im is None:
                continue
            cp = os.path.join(CLEAN, b + ".png")
            if not os.path.exists(cp):
                im.save(cp)

    if missing:
        print("MISSING BASES (%d):" % len(missing))
        for m in sorted(missing):
            print("  -", m)
    print("composited: %d / %d" % (done, len(rows)))


if __name__ == "__main__":
    main()
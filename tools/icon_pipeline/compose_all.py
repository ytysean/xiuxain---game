"""
《太玄宗门录》图标全量合成器
读取 icon_manifest.csv：(folder, type, name) -> 原型底图 -> 叠加品阶边框 -> 落盘 icon/<folder>/<id>.png
底图位于 icon/_bases/<base>.png；缺失则列出，不中断。

用法：
  python compose_all.py            # 合成全部（底图齐了之后）
  python compose_all.py --check    # 只检查底图缺失，不合成
"""
import csv, os, sys, shutil
from PIL import Image
import icon_frame as F

ROOT = "E:/Xiuxian/taixuanzongmenlu"
BASES = os.path.join(ROOT, "icon", "_bases")
MANIFEST = os.path.join(ROOT, "icon_manifest.csv")

# pilot 产出文件名 -> 规范底图名 的别名（首批样张命名与规范名略有差异）
ALIASES = {
    "talisman": "tal_off",
    "skill_slip": "sk_sup",
    "treasure_orb": "tr_orb",
    "equip_sword": "eq_sword",
    "equip_robe": "eq_robe",
    "array_book": "arr_book",
}

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
        m = {"武器": "eq_sword", "衣袍": "eq_robe", "头盔": "eq_helm", "护腕": "eq_bracer",
             "腰带": "eq_belt", "靴子": "eq_boots", "配饰": "eq_acc"}
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

def resolve_base(base_name):
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
    rows = []
    with open(MANIFEST, encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    missing = set()
    done = 0
    for r in rows:
        b = base_for(r)
        bp = resolve_base(b)
        if bp is None:
            missing.add(b)
            continue
        grade = r["grade"] if r["grade"] in F.GRADE_COLORS else "凡品"
        out = dest_path(r)
        if check_only:
            done += 1
            continue
        os.makedirs(os.path.dirname(out), exist_ok=True)
        F.compose(bp, grade, out)
        done += 1
    if missing:
        print("缺失底图 (%d):" % len(missing))
        for m in sorted(missing):
            print("  -", m)
    print("可合成/已合成: %d / %d" % (done, len(rows)))

if __name__ == "__main__":
    main()

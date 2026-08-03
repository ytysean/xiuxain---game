# tests/destiny/destiny_math.py
# 命格系统单测（Python 镜像 disciple.gd 命格加成逻辑）
# 验收：同基础属性弟子有无命格的差值，与 CSV 配置值误差 <= 0.1%
import csv, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CSV_PATH = os.path.join(ROOT, "config", "destiny_main.csv")


def load_destiny():
    rows = []
    with open(CSV_PATH, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            ep = r.get("效果参数", "")
            if ":" in ep:
                dim, val = ep.split(":", 1)
                r["_dim"] = dim
                r["_val"] = int(val)
            rows.append(r)
    return rows


def get_destiny(did, rows):
    for r in rows:
        if r["destiny_id"] == did:
            return r
    return None


def snapshot(attrs, did, rows):
    """镜像 disciple.属性快照()：战斗型命格乘性加成攻防血速"""
    dg = get_destiny(did, rows)
    out = dict(attrs)
    if dg and dg.get("类型") == "战斗" and dg.get("_dim") in out:
        out[dg["_dim"]] = int(out[dg["_dim"]] * (1 + dg["_val"] / 100.0))
    return out


def apply_cultivation(spd, did, rows):
    """镜像 disciple._应用命格养成加成()：修行型命格乘入修炼速度"""
    dg = get_destiny(did, rows)
    if dg and dg.get("类型") == "修行" and dg.get("_dim") == "修炼":
        spd *= (1 + dg["_val"] / 100.0)
    return spd


def manage_coef(member_ids, rows):
    """镜像 game_state._资源殿阁产出()：经营型命格驻守乘性加成"""
    coef = 0.0
    for did in member_ids:
        dg = get_destiny(did, rows)
        if dg and dg.get("类型") == "经营" and dg.get("_dim") == "产出":
            coef += dg["_val"] / 100.0
    return 1.0 + coef


def test():
    rows = load_destiny()
    assert len(rows) == 20, "expected 20 destiny rows, got " + str(len(rows))

    # 断言1：战斗型命格使属性快照加成正确（攻 +9%）
    snap = snapshot({"攻": 100, "防": 100, "血": 100, "速": 100}, "D_ZHANWANG", rows)
    assert snap["攻"] == 109, "combat atk+9% expected 109, got " + str(snap["攻"])

    # 断言2：修行型命格使修炼速度修正生效（修炼 +9%，1.8 -> 1.962）
    spd = apply_cultivation(1.8, "D_JULING", rows)
    assert abs(spd - 1.962) < 1e-6, "cultivation+9% expected 1.962, got " + str(spd)

    # 断言3：经营型命格使殿阁产出系数匹配（产出 +9%，系数 1.09）
    coef = manage_coef(["D_DANXIN"], rows)
    assert abs(coef - 1.09) < 1e-9, "manage+9% expected 1.09, got " + str(coef)

    # 边界：无命格不改变属性
    snap0 = snapshot({"攻": 100, "防": 100, "血": 100, "速": 100}, "", rows)
    assert snap0["攻"] == 100, "no destiny should not alter attrs"

    # 边界：负向命格（衰星 修炼 -5%，1.8 -> 1.71）
    spd2 = apply_cultivation(1.8, "D_SHUAIXING", rows)
    assert abs(spd2 - 1.71) < 1e-6, "negative destiny expected 1.71, got " + str(spd2)

    print("destiny_math: ALL ASSERTIONS PASSED (combat/cultivation/manage + edge cases)")


if __name__ == "__main__":
    test()

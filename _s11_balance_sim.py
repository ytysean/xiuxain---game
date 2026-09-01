# -*- coding: utf-8 -*-
# S1-1 战斗平衡验证器：逐行移植 BattleCalculator 的 calc_hit_damage + _结算_1v1_原版(quick)
# 目的：量化验证「历练接真实战斗」后的实际胜率 vs 原成功率口径，判断平衡是否崩溃。
# 只读验证，不改任何 .gd。

# ============ BattleCalculator 常量（逐字节对齐） ============
WUXING = ["金", "木", "土", "水", "火"]
PROF_COUNTER = {"道修": "法修", "体修": "道修", "法修": "体修"}
PURITY_CT = {"单": 1.25, "双": 1.0, "三": 0.75, "四+": 0.5}
PURITY_CTED = {"单": 0.82, "双": 1.0, "三": 0.67, "四+": 0.33}
PROF_CT_MULT = 1.20
PROF_CTED_MULT = 0.85
DEF_BASE = 200.0
DEF_CAP = 0.75
CRIT_CAP = 0.70
DODGE_CAP = 0.40
CRIT_MULT_K = 1.5
DMG_MIN = 1
ROUND_CAP = 20


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def wuxing_multiplier(a, d, purity):
    if a == "" or d == "" or a == d:
        return 1.0
    if a not in WUXING or d not in WUXING:
        return 1.0
    tgt = WUXING[(WUXING.index(a) + 1) % len(WUXING)]
    if tgt == d:
        return PURITY_CT.get(purity, 1.0)
    if WUXING[(WUXING.index(d) + 1) % len(WUXING)] == a:
        return PURITY_CTED.get(purity, 1.0)
    return 1.0


def profession_multiplier(ap, dp):
    if ap == "" or dp == "":
        return 1.0
    if PROF_COUNTER.get(ap, "") == dp:
        return PROF_CT_MULT
    if PROF_COUNTER.get(dp, "") == ap:
        return PROF_CTED_MULT
    return 1.0


def calc_hit_damage(atk, dfn, float_factor, crit_mult, dodge_mult):
    if dodge_mult <= 0.0:
        return 0
    a = float(atk.get("属性", {}).get("攻", 0))
    if a <= 0:
        return 0
    d = float(dfn.get("属性", {}).get("防", 0))
    red = clamp(d / (d + DEF_BASE), 0.0, DEF_CAP)
    wux = wuxing_multiplier(
        atk.get("灵根", {}).get("主", ""),
        dfn.get("灵根", {}).get("主", ""),
        atk.get("灵根", {}).get("纯度", "单"),
    )
    pm = profession_multiplier(atk.get("职业", ""), dfn.get("职业", ""))
    g1 = 1.0 + float(atk.get("通用增益", 0.0))
    g2 = 1.0 + float(atk.get("道心增益", 0.0))
    dmg = a * pm * g1 * g2 * wux * (1.0 - red) * crit_mult * float_factor
    return int(max(DMG_MIN, round(dmg)))


def settle_1v1_quick(atk, dfn):
    """_结算_1v1_原版 的 quick 模式（确定性，取期望值）"""
    a_hp = int(atk.get("属性", {}).get("血", 1))
    d_hp = int(dfn.get("属性", {}).get("血", 1))
    a_spd = float(atk.get("属性", {}).get("速", 0))
    d_spd = float(dfn.get("属性", {}).get("速", 0))
    a_crit = clamp(float(atk.get("暴击率", 0.0)), 0.0, CRIT_CAP)
    d_crit = clamp(float(dfn.get("暴击率", 0.0)), 0.0, CRIT_CAP)
    a_dodge = clamp(float(atk.get("闪避率", 0.0)), 0.0, DODGE_CAP)
    d_dodge = clamp(float(dfn.get("闪避率", 0.0)), 0.0, DODGE_CAP)
    rnd = 0
    atk_first = a_spd >= d_spd
    while True:
        rnd += 1
        if rnd > ROUND_CAP:
            break
        order = [(atk, dfn, True), (dfn, atk, False)] if atk_first else [(dfn, atk, False), (atk, dfn, True)]
        for actor, target, actor_is_atk in order:
            if a_hp <= 0 or d_hp <= 0:
                break
            actor_crit = a_crit if actor_is_atk else d_crit
            target_dodge = d_dodge if actor_is_atk else a_dodge
            crit_mult = 1.0 + actor_crit * (CRIT_MULT_K - 1.0)
            dodge_mult = 1.0 - target_dodge
            dmg = calc_hit_damage(actor, target, 1.0, crit_mult, dodge_mult)
            if actor_is_atk:
                d_hp -= dmg
            else:
                a_hp -= dmg
        if a_hp <= 0 or d_hp <= 0:
            break
    is_win = (d_hp <= 0 and a_hp > 0)
    return {"is_win": is_win, "rounds": rnd, "a_hp": a_hp, "d_hp": d_hp}


def power_metric(u):
    """BattleCalculator.战力度量"""
    a = u.get("属性", {})
    return int(float(a.get("攻", 0)) * 1.0 + float(a.get("防", 0)) * 0.5
               + float(a.get("血", 0)) * 0.4 + float(a.get("速", 0)) * 0.3
               + float(u.get("暴击率", 0.0)) * 60.0 + float(u.get("闪避率", 0.0)) * 40.0)


# ============ Disciple 口径（逐行移植） ============
REALM_TABLE = {"练气": 100, "筑基": 400, "金丹": 1500, "元婴": 6000, "化神": 25000, "仙阶": 80000}
REALM_BATTLE_MULT = {"练气": 1.0, "筑基": 2.0, "金丹": 4.0, "元婴": 8.0, "化神": 15.0, "仙阶": 25.0}
PATH_W = {
    "": {"攻": 0.25, "防": 0.25, "血": 0.25, "速": 0.25},
    "道修": {"攻": 0.40, "防": 0.15, "血": 0.20, "速": 0.25},
    "体修": {"攻": 0.20, "防": 0.40, "血": 0.30, "速": 0.10},
    "法修": {"攻": 0.35, "防": 0.10, "血": 0.15, "速": 0.40},
}
APT_K = {"pingyong": 1.0, "youliang": 1.15, "yaonie": 1.6}


def make_disciple(realm="练气", path="道修", apt="pingyong", root="金"):
    total = int(150 + APT_K[apt] * 30)
    w = PATH_W[path]
    attr = {k: int(total * w[k]) for k in ["攻", "防", "血", "速"]}
    mult = REALM_BATTLE_MULT.get(realm, 1.0)
    if mult > 1.0:
        for k in attr:
            attr[k] = int(attr[k] * mult)
    crit = clamp(float(attr["速"]) * 0.004, 0.0, 1.0)
    if root in ["雷", "金"]:
        crit += 0.05
    dodge = clamp(float(attr["速"]) * 0.003, 0.0, 1.0)
    if root in ["风", "水"]:
        dodge += 0.05
    power = int(REALM_TABLE[realm] * APT_K[apt])
    return {
        "战力": power, "属性": attr, "道途": path, "职业": path,
        "灵根": {"主": root, "纯度": "单"}, "通用增益": 0.0, "道心增益": 0.0,
        "暴击率": crit, "闪避率": dodge, "名称": "弟子", "技能": [],
    }


def aggregate(team):
    """expedition._聚合队伍快照"""
    if not team:
        return {}
    lead = team[0]
    agg = {"攻": 0, "防": 0, "血": 0, "速": 0}
    tp, tc, td = 0, 0.0, 0.0
    for s in team:
        for k in agg:
            agg[k] += int(s["属性"][k])
        tp += int(s["战力"])
        tc += float(s["暴击率"])
        td += float(s["闪避率"])
    n = len(team)
    return {
        "战力": tp, "属性": agg, "道途": lead["道途"], "职业": lead["职业"],
        "灵根": lead["灵根"], "通用增益": 0.0, "道心增益": 0.0,
        "暴击率": tc / n, "闪避率": td / n, "名称": "队伍", "技能": [],
    }


# ============ 当前 S1-1 实现的敌方构造（待验证的可疑实现） ============
def enemy_current(stage):
    p = int(float(stage["推荐战力"]) * float(stage["难度"]))
    return {
        "战力": p,
        "属性": {"攻": int(p * 0.25), "防": int(p * 0.15), "血": int(p * 3.0), "速": max(1, int(p * 0.05))},
        "道途": "道修", "职业": "道修", "灵根": {"主": "金", "纯度": "单"},
        "通用增益": 0.0, "道心增益": 0.0, "暴击率": 0.0, "闪避率": 0.0,
        "名称": "关卡守军", "技能": [],
    }


# ============ 真实怪物口径（monster_main.csv + StageDataLoader） ============
MONSTER_MULT = {"练气": 1.0, "筑基": 2.0, "金丹": 4.0, "元婴": 8.0, "化神": 15.0}
MONSTERS = {
    "M101": dict(name="野狼", realm="练气", el="土", hp=279, atk=70, df=28, spd=28, crit=0.05, dodge=0.02),
    "M105": dict(name="山匪头目", realm="练气", el="金", hp=307, atk=77, df=31, spd=31, crit=0.08, dodge=0.03),
    "M2BOSS": dict(name="古道魔头", realm="筑基", el="金", hp=711, atk=178, df=71, spd=71, crit=0.12, dodge=0.05),
}


def monster_unit(mid):
    m = MONSTERS[mid]
    k = MONSTER_MULT.get(m["realm"], 1.0)
    return {
        "属性": {"攻": int(m["atk"] * k), "防": int(m["df"] * k), "血": int(m["hp"] * k), "速": int(m["spd"] * k)},
        "道途": "", "职业": "", "灵根": {"主": m["el"], "纯度": "单"},
        "通用增益": 0.0, "道心增益": 0.0,
        "暴击率": m["crit"], "闪避率": m["dodge"], "名称": m["name"], "技能": [],
    }


# ============ 原成功率公式（expedition.gd:534-554） ============
def legacy_rate(total_power, stage, xinjing=60, daoxin=20, xinmo=0):
    rec = int(stage["推荐战力"])
    diff = float(stage["难度"])
    ratio = float(total_power) / float(rec) if rec > 0 else 1.0
    r = clamp(ratio / diff, 0.1, 0.95)
    r += (float(xinjing) * 0.05 + float(daoxin) * 0.08 - float(xinmo) * 0.1) / 100.0
    return clamp(r, 0.05, 0.95)


STAGES = [
    {"id": "daily_lingcai", "名称": "灵草采集", "推荐战力": 100, "难度": 1, "解锁境界": "练气"},
    {"id": "daily_xunluo", "名称": "山门巡逻", "推荐战力": 150, "难度": 1, "解锁境界": "练气"},
    {"id": "daily_yaoshou", "名称": "妖兽清剿", "推荐战力": 300, "难度": 2, "解锁境界": "筑基"},
    {"id": "realm_zhuji_1", "名称": "筑基·幽谷试炼", "推荐战力": 500, "难度": 2, "解锁境界": "练气"},
    {"id": "realm_zhuji_3", "名称": "筑基·妖兽围猎", "推荐战力": 1200, "难度": 3, "解锁境界": "筑基"},
]

TEAMS = [
    ("1名练气道修", [make_disciple("练气", "道修")]),
    ("3名练气道修", [make_disciple("练气", "道修") for _ in range(3)]),
    ("3名筑基道修", [make_disciple("筑基", "道修") for _ in range(3)]),
    ("3名金丹道修", [make_disciple("金丹", "道修") for _ in range(3)]),
    ("3名筑基体修", [make_disciple("筑基", "体修") for _ in range(3)]),
]

print("=" * 96)
print("【验证1】S1-1 当前实现：真实战斗胜负 vs 原成功率口径")
print("=" * 96)
print("%-14s %-16s %10s %10s %8s %8s %s" % ("队伍", "关卡", "队伍战力", "原成功率", "真实", "回合", "残血(我/敌)"))
print("-" * 96)
disaster = 0
total_case = 0
for tname, team in TEAMS:
    for st in STAGES:
        agg = aggregate(team)
        en = enemy_current(st)
        r = settle_1v1_quick(agg, en)
        lr = legacy_rate(agg["战力"], st)
        total_case += 1
        flag = ""
        if lr >= 0.5 and not r["is_win"]:
            flag = "  <<< 崩溃(原本该赢)"
            disaster += 1
        print("%-14s %-16s %10d %9.0f%% %8s %8d   %d/%d%s" % (
            tname, st["名称"], agg["战力"], lr * 100,
            "胜" if r["is_win"] else "败", r["rounds"], r["a_hp"], r["d_hp"], flag))
print("-" * 96)
print("崩溃案例：%d / %d（原成功率≥50%% 却真实战斗必败）" % (disaster, total_case))

print()
print("=" * 96)
print("【验证2】口径错配根因：弟子 vs 真实怪物（monster_main.csv，副本战斗现役口径）")
print("=" * 96)
print("%-16s %-14s %8s %8s %8s %8s | %s" % ("我方", "敌方", "我攻", "我血", "敌攻", "敌血", "结果"))
print("-" * 96)
for tname, team in [("1名练气道修", [make_disciple("练气", "道修")]),
                    ("1名练气体修", [make_disciple("练气", "体修")]),
                    ("1名筑基道修", [make_disciple("筑基", "道修")]),
                    ("3名练气道修", [make_disciple("练气", "道修") for _ in range(3)])]:
    for mid in ["M101", "M105", "M2BOSS"]:
        agg = aggregate(team)
        mu = monster_unit(mid)
        r = settle_1v1_quick(agg, mu)
        print("%-16s %-14s %8d %8d %8d %8d | %s (%d回合, 残血 我%d/敌%d)" % (
            tname, mu["名称"], agg["属性"]["攻"], agg["属性"]["血"],
            mu["属性"]["攻"], mu["属性"]["血"],
            "胜" if r["is_win"] else "败", r["rounds"], r["a_hp"], r["d_hp"]))

print()
print("=" * 96)
print("【验证3】节奏诊断：四维结构对比（谁是秒杀节奏，谁是耐久节奏）")
print("=" * 96)
for label, u in [("练气道修弟子", make_disciple("练气", "道修")),
                 ("练气体修弟子", make_disciple("练气", "体修")),
                 ("练气法修弟子", make_disciple("练气", "法修")),
                 ("野狼M101(练气怪)", monster_unit("M101")),
                 ("S1-1构造敌方(推荐100难1)", enemy_current(STAGES[0]))]:
    a = u["属性"]
    ratio = float(a["血"]) / max(1.0, float(a["攻"]))
    print("%-26s 攻%6d 防%5d 血%6d 速%5d | 血/攻=%5.2f  战力度量=%6d  %s" % (
        label, a["攻"], a["防"], a["血"], a["速"], ratio, power_metric(u),
        "秒杀节奏(血<2攻)" if ratio < 2.0 else "耐久节奏"))
print()
print("诊断：弟子血/攻 < 1 → 挨 1 击就残；怪物血/攻 ≈ 4 → 耐久。")
print("      双方口径不对称 = 谁先手谁赢 / 或血厚方靠 20 回合超时判胜。")

# -*- coding: utf-8 -*-
# S1-1 修正后平衡验证器：敌方 = 真实怪物(monster_main.csv) 经 StageDataLoader(怪物境界倍率)
# 镜像 expedition._构造敌方快照 的修正实现。Monte-Carlo 取真实胜率，对比游戏显示成功率。
# 只读验证，不改任何 .gd。

import random
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
    wux = wuxing_multiplier(atk.get("灵根", {}).get("主", ""), dfn.get("灵根", {}).get("主", ""),
                            atk.get("灵根", {}).get("纯度", "单"))
    pm = profession_multiplier(atk.get("职业", ""), dfn.get("职业", ""))
    g1 = 1.0 + float(atk.get("通用增益", 0.0))
    g2 = 1.0 + float(atk.get("道心增益", 0.0))
    dmg = a * pm * g1 * g2 * wux * (1.0 - red) * crit_mult * float_factor
    return int(max(DMG_MIN, round(dmg)))


def settle_1v1_mc(atk, dfn, trials=400):
    """Monte-Carlo：每击随机浮动[0.9,1.1] + 暴击/闪避掷骰，返回胜率"""
    wins = 0
    for _ in range(trials):
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
                crit_mult = 1.0 + actor_crit * (CRIT_MULT_K - 1.0) if random.random() < actor_crit else 1.0
                dodge_mult = 0.0 if random.random() < target_dodge else 1.0
                ff = random.uniform(0.9, 1.1)
                dmg = calc_hit_damage(actor, target, ff, crit_mult, dodge_mult)
                if actor_is_atk:
                    d_hp -= dmg
                else:
                    a_hp -= dmg
            if a_hp <= 0 or d_hp <= 0:
                break
        if d_hp <= 0 and a_hp > 0:
            wins += 1
    return wins / trials


def power_metric(u):
    a = u.get("属性", {})
    return int(float(a.get("攻", 0)) * 1.0 + float(a.get("防", 0)) * 0.5
               + float(a.get("血", 0)) * 0.4 + float(a.get("速", 0)) * 0.3
               + float(u.get("暴击率", 0.0)) * 60.0 + float(u.get("闪避率", 0.0)) * 40.0)


# ============ Disciple 口径 ============
REALM_TABLE = {"练气": 100, "筑基": 400, "金丹": 1500, "元婴": 6000, "化神": 25000, "仙阶": 80000}
REALM_BATTLE_MULT = {"练气": 1.0, "筑基": 2.0, "金丹": 4.0, "元婴": 8.0, "化神": 15.0, "仙阶": 25.0}
PATH_W = {
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


# ============ 真实怪物口径（逐字节对齐 monster_main.csv + StageDataLoader.怪物境界倍率）============
MONSTER_MULT = {"练气": 1.0, "筑基": 2.0, "金丹": 4.0, "元婴": 8.0, "化神": 15.0}
MONSTERS = {
    "M101": dict(name="野狼", realm="练气", el="土", hp=279, atk=70, df=28, spd=28, crit=0.05, dodge=0.02),
    "M102": dict(name="山贼", realm="练气", el="金", hp=279, atk=70, df=28, spd=28, crit=0.05, dodge=0.02),
    "M103": dict(name="低阶妖兽", realm="练气", el="木", hp=279, atk=70, df=28, spd=28, crit=0.05, dodge=0.02),
    "M104": dict(name="山贼喽啰", realm="练气", el="金", hp=156, atk=39, df=16, spd=16, crit=0.04, dodge=0.02),
    "M105": dict(name="山匪头目", realm="练气", el="金", hp=307, atk=77, df=31, spd=31, crit=0.08, dodge=0.03),
    "M106": dict(name="林间精怪", realm="练气", el="水", hp=156, atk=39, df=16, spd=16, crit=0.05, dodge=0.04),
    "M107": dict(name="矿洞石傀", realm="练气", el="土", hp=307, atk=77, df=31, spd=31, crit=0.03, dodge=0.01),
    "M110": dict(name="后山狼王", realm="练气", el="土", hp=293, atk=73, df=29, spd=29, crit=0.10, dodge=0.03),
    "M2PH": dict(name="青冥散修", realm="筑基", el="水", hp=574, atk=143, df=57, spd=57, crit=0.08, dodge=0.04),
    "M2BOSS": dict(name="古道魔头", realm="筑基", el="金", hp=711, atk=178, df=71, spd=71, crit=0.12, dodge=0.05),
    "M3PH": dict(name="玄雾阴魂", realm="金丹", el="水", hp=283, atk=71, df=28, spd=28, crit=0.10, dodge=0.04),
    "M3BOSS": dict(name="峡谷亡灵将", realm="金丹", el="土", hp=317, atk=79, df=32, spd=32, crit=0.15, dodge=0.05),
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


# ============ 修正后 _构造敌方快照（镜像 expedition.gd）============
关卡怪物映射 = {
    "daily_lingcai": ["M103"], "daily_xunluo": ["M102"], "daily_shangmao": ["M104", "M101"],
    "daily_yaoshou": ["M2PH", "M2PH"], "daily_kuangshi": ["M2PH"],
    "realm_zhuji_1": ["M2PH"], "realm_zhuji_2": ["M2PH", "M2PH"], "realm_zhuji_3": ["M2BOSS"],
    "realm_zhuji_4": ["M2BOSS"], "realm_zhuji_5": ["M2BOSS", "M2PH"],
    "realm_jindan_1": ["M3PH"], "realm_jindan_2": ["M3BOSS"],
    "secret_gumu": ["M2BOSS"], "secret_jianzhong": ["M3BOSS"], "secret_yaoyu": ["M3BOSS", "M3PH"],
}


def enemy_corrected(关卡ID):
    ids = 关卡怪物映射.get(关卡ID, [])
    units = [monster_unit(m) for m in ids]
    if not units:
        units = [monster_unit("M101")]
    if len(units) == 1:
        u = units[0]
        return {"战力": power_metric(u), "属性": u["属性"], "道途": u["道途"], "职业": u["职业"],
                "灵根": u["灵根"], "暴击率": u["暴击率"], "闪避率": u["闪避率"], "名称": u["名称"], "技能": []}
    agg = {"攻": 0, "防": 0, "血": 0, "速": 0}
    tp, tc, td = 0, 0.0, 0.0
    names = []
    for u in units:
        a = u["属性"]
        agg["攻"] += a["攻"]; agg["防"] += a["防"]; agg["血"] += a["血"]; agg["速"] += a["速"]
        tp += power_metric(u); tc += u["暴击率"]; td += u["闪避率"]; names.append(u["名称"])
    n = len(units)
    return {"战力": tp, "属性": agg, "道途": "", "职业": "", "灵根": units[0]["灵根"],
            "暴击率": tc / n, "闪避率": td / n, "名称": "妖兽群·" + "、".join(names), "技能": []}


# ============ 关卡库 + 队伍 ============
STAGES = [
    ("daily_lingcai", "灵草采集", "练气", 100, 1),
    ("daily_xunluo", "山门巡逻", "练气", 150, 1),
    ("daily_shangmao", "坊市采买", "练气", 80, 1),
    ("daily_yaoshou", "妖兽清剿", "筑基", 300, 2),
    ("daily_kuangshi", "矿脉勘探", "筑基", 250, 2),
    ("realm_zhuji_1", "筑基·幽谷试炼", "练气", 500, 2),
    ("realm_zhuji_2", "筑基·断崖悟道", "练气", 800, 3),
    ("realm_zhuji_3", "筑基·妖兽围猎", "筑基", 1200, 3),
    ("realm_zhuji_4", "筑基·心魔试炼", "筑基", 1800, 4),
    ("realm_zhuji_5", "筑基·宗门大比", "筑基", 2500, 4),
    ("realm_jindan_1", "金丹·丹火试炼", "筑基", 4000, 4),
    ("realm_jindan_2", "金丹·雷劫洗礼", "金丹", 6000, 5),
    ("secret_gumu", "秘境·古木洞天", "筑基", 3000, 4),
    ("secret_jianzhong", "秘境·剑冢", "金丹", 8000, 5),
    ("secret_yaoyu", "秘境·妖域", "元婴", 15000, 5),
]

TEAMS = [
    ("1名练气道修", [make_disciple("练气", "道修")]),
    ("1名筑基道修", [make_disciple("筑基", "道修")]),
    ("3名练气道修", [make_disciple("练气", "道修") for _ in range(3)]),
    ("3名筑基道修", [make_disciple("筑基", "道修") for _ in range(3)]),
    ("3名金丹道修", [make_disciple("金丹", "道修") for _ in range(3)]),
    ("3名元婴道修", [make_disciple("元婴", "道修") for _ in range(3)]),
]

print("=" * 110)
print("【修正后】敌方=真实怪物(monster_main.csv) | 真实胜率(MC 400局) vs 游戏显示成功率(clamp 战力度量比)")
print("=" * 110)
print("%-14s %-18s %6s %6s %7s %9s %9s %s" % ("队伍", "关卡", "我度量", "敌度量", "战力比", "显示成功率", "真实胜率", "判定"))
print("-" * 110)
for tname, team in TEAMS:
    agg = aggregate(team)
    my_pow = power_metric(agg)
    for sid, sname, unlock, rec, diff in STAGES:
        en = enemy_corrected(sid)
        enemy_pow = power_metric(en)
        ratio = float(my_pow) / float(enemy_pow) if enemy_pow > 0 else 1.0
        显示 = clamp(ratio, 0.1, 0.95)
        rate = settle_1v1_mc(agg, en, trials=400)
        tag = ""
        if 显示 >= 0.6 and rate < 0.4:
            tag = " ⚠偏差大"
        elif 显示 < 0.4 and rate >= 0.6:
            tag = " ⚠偏差大"
        print("%-14s %-18s %6d %6d %7.2f %8.0f%% %9.0f%%%s" % (
            tname, sname, my_pow, enemy_pow, ratio, 显示 * 100, rate * 100, tag))
    print("-" * 110)
print("说明：显示成功率 = clamp(我方战力度量/敌方战力度量)；真实胜率 = Monte-Carlo 400 局。")
print("      二者接近 = 修正成功（真实战斗决定生死，且胜率贴合界面预估，无崩溃）。")

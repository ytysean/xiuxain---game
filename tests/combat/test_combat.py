# -*- coding: utf-8 -*-
# test_combat.py —— BattleCalculator 数值红线断言（ADR-003 D7，Python 托管跑）
#
# 覆盖：
#  · 五行 5 关系 × 4 纯度档 乘率（AC2）
#  · 职业克制闭环（AC3 / D2）
#  · 4 类边界（AC7）：伤害下限=1 / 攻击=0 不出负伤 / 暴击·闪避封顶 / 浮动∈[0.9,1.1] / 速算vs完整偏差≤10%
#  · 五行边界 max1.25 / min0.82
# 运行：python tests/combat/test_combat.py  →  全部断言必须 100% 通过
import random
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import combat_math as M

PASS = 0
FAIL = 0


def check(name, cond, detail=""):
    global PASS, FAIL
    if cond:
        PASS += 1
        print("  [OK] %s" % name)
    else:
        FAIL += 1
        print("  [FAIL] %s  %s" % (name, detail))


# ============ 1. 五行 5 关系 × 4 纯度档（AC2 / §9.6）============
def test_wuxing_matrix():
    print("== 五行乘率：5 关系 × 4 纯度档 ==")
    纯度档 = ["单", "双", "三", "四+"]
    关系 = {
        "克制": ("金", "木"),   # 金克木
        "被克": ("木", "金"),   # 木被金克
        "同属": ("金", "金"),
        "真实": (None, None),   # is_true_damage
        "中性": ("天灵根", "金"),  # 非五行主灵根
    }
    期望 = {
        "克制": {"单": 1.25, "双": 1.0, "三": 0.75, "四+": 0.5},
        "被克": {"单": 0.82, "双": 1.0, "三": 0.67, "四+": 0.33},
        "同属": {"单": 1.0, "双": 1.0, "三": 1.0, "四+": 1.0},
        "真实": {"单": 1.0, "双": 1.0, "三": 1.0, "四+": 1.0},
        "中性": {"单": 1.0, "双": 1.0, "三": 1.0, "四+": 1.0},
    }
    for rel, (a, d) in 关系.items():
        for p in 纯度档:
            if rel == "真实":
                v = M.wuxing_multiplier("金", "木", p, True)
            else:
                v = M.wuxing_multiplier(a, d, p)
            want = 期望[rel][p]
            check("wuxing %s/%s = %s" % (rel, p, want), abs(v - want) < 1e-9,
                  "got %s" % v)


# ============ 2. 五行边界 max1.25 / min0.82（§9.6.3）============
def test_wuxing_bounds():
    print("== 五行边界 max1.25 / min0.82 ==")
    maxv = M.wuxing_multiplier("金", "木", "单")          # 单克制 = 1.25
    minv = M.wuxing_multiplier("木", "金", "单")          # 单被克 = 0.82
    check("五行上限 = 1.25", abs(maxv - 1.25) < 1e-9, "got %s" % maxv)
    check("五行下限 = 0.82", abs(minv - 0.82) < 1e-9, "got %s" % minv)
    # 单灵根极端值 ∈ [0.82, 1.25]（§9.6.3）；多灵根档可低至 0.33（四+被克）
    ok_single = True
    ok_all = True
    for a in M.五行序:
        for d in M.五行序:
            for p in ["单", "双", "三", "四+"]:
                v = M.wuxing_multiplier(a, d, p)
                if v > M.五行上限 + 1e-9 or v < 0.33 - 1e-9:
                    ok_all = False
                if p == "单" and (v > M.五行上限 + 1e-9 or v < M.五行下限 - 1e-9):
                    ok_single = False
    check("单灵根组合 ∈ [0.82, 1.25]（§9.6.3 边界）", ok_single)
    check("所有组合 ∈ [0.33, 1.25]（多灵根可低至0.33）", ok_all)


# ============ 3. 职业克制闭环（AC3 / D2）============
def test_profession_loop():
    print("== 职业克制闭环 道修→法修→体修→道修 ==")
    check("道修克法修 ×1.20", M.profession_multiplier("道修", "法修") == 1.20)
    check("法修克体修 ×1.20", M.profession_multiplier("法修", "体修") == 1.20)
    check("体修克道修 ×1.20", M.profession_multiplier("体修", "道修") == 1.20)
    check("法修被道修克 ×0.85", M.profession_multiplier("法修", "道修") == 0.85)
    check("体修被法修克 ×0.85", M.profession_multiplier("体修", "法修") == 0.85)
    check("道修被体修克 ×0.85", M.profession_multiplier("道修", "体修") == 0.85)
    check("同职业中性 ×1.0", M.profession_multiplier("道修", "道修") == 1.0)
    check("空职业中性 ×1.0", M.profession_multiplier("", "") == 1.0)
    check("未知职业(御兽师)中性 ×1.0", M.profession_multiplier("道修", "御兽师") == 1.0)


# ============ 4. 边界红线（AC7）============
def test_boundaries():
    print("== 边界红线 AC7 ==")
    # ① 伤害下限=1（防御极高）；攻击=0 不出负伤
    atk_lo = M.make_unit(3, 0, 100, 0, "道修", "金", "单")
    def_hi = M.make_unit(0, 100000, 100, 0, "体修", "木", "单")
    d_lo = M.calc_hit_damage(atk_lo, def_hi, 1.0, 1.0, 1.0, False)
    check("高防兜底 伤害下限=1", d_lo == 1, "got %s" % d_lo)

    atk_zero = M.make_unit(0, 0, 100, 0, "道修", "金", "单")
    d_zero = M.calc_hit_damage(atk_zero, def_hi, 1.0, 1.0, 1.0, False)
    check("攻击=0 不出负伤(=0)", d_zero == 0, "got %s" % d_zero)

    # ② 暴击率>70% / 闪避率>40% 封顶
    check("暴击率>70% 封顶=0.70", M.封顶暴击率(0.95) == 0.70)
    check("暴击率 0.5 不封顶", M.封顶暴击率(0.5) == 0.5)
    check("闪避率>40% 封顶=0.40", M.封顶闪避率(0.6) == 0.40)
    check("闪避率 0.2 不封顶", M.封顶闪避率(0.2) == 0.2)

    # ③ 浮动伤害严格∈[0.9,1.1]（作为直接乘区验证）
    atk_f = M.make_unit(100, 0, 100, 0, "道修", "金", "单")  # 同属→wux=1, prof=1
    def_f = M.make_unit(0, 0, 100, 0, "道修", "金", "单")
    base = M.calc_hit_damage(atk_f, def_f, 1.0, 1.0, 1.0, False)
    d09 = M.calc_hit_damage(atk_f, def_f, 0.9, 1.0, 1.0, False)
    d11 = M.calc_hit_damage(atk_f, def_f, 1.1, 1.0, 1.0, False)
    check("浮动下限 0.9 乘区正确", abs(d09 / base - 0.9) < 1e-9, "%.3f" % (d09 / base))
    check("浮动上限 1.1 乘区正确", abs(d11 / base - 1.1) < 1e-9, "%.3f" % (d11 / base))

    # 闪避生效：dodge_mult=0 → 伤害 0
    check("闪避命中 伤害=0", M.calc_hit_damage(atk_f, def_f, 1.0, 1.0, 0.0, False) == 0)


# ============ 5. 速算 vs 完整 偏差≤10%（AC7④）============
def test_quick_vs_full():
    print("== 速算 vs 完整 偏差≤10% ==")
    rng = random.Random(20260719)
    # 决定性对局：攻方明显强于守方，两模式均应由攻方取胜
    atk = M.make_unit(200, 80, 300, 50, "道修", "金", "单",
                       暴击=0.3, 闪避=0.1, 名称="攻方")
    dfn = M.make_unit(80, 40, 150, 30, "体修", "木", "单",
                      暴击=0.1, 闪避=0.05, 名称="守方")
    quick = M.结算_1v1(atk, dfn, "quick")
    N = 400
    wins = 0
    rounds_sum = 0
    for _ in range(N):
        r = M.结算_1v1(atk, dfn, "full", rng)
        if r["is_win"]:
            wins += 1
        rounds_sum += r["round_count"]
    full_winrate = wins / N
    full_avg_rounds = rounds_sum / N
    quick_win = 1.0 if quick["is_win"] else 0.0
    dev_win = abs(full_winrate - quick_win)
    dev_round = abs(full_avg_rounds - quick["round_count"]) / max(1, quick["round_count"])
    check("速算/完整 胜负偏差≤10%% (dev=%.3f)" % dev_win, dev_win <= 0.10, "full wr=%.3f quick=%s" % (full_winrate, quick_win))
    check("速算/完整 回合偏差≤10%% (dev=%.3f)" % dev_round, dev_round <= 0.10,
          "full=%.2f quick=%d" % (full_avg_rounds, quick["round_count"]))
    # 结构契约校验
    for k in ("is_win", "round_count", "remaining_hp", "drop_reward", "battle_log"):
        check("BattleResult 含字段 %s" % k, k in quick)


# ============ 6. 强制结构化战斗日志契约（D7 / AC8）============
# 每回合日志条目须含：行动单位/目标/伤害值/是否暴击/是否克制/双方剩余血量。
# 注：BattleCalculator 的 is_restrain 标记 = 职业克制（D2 闭环）；
#     选 体修(金) 攻 道修(木) → 体修克道修(职业) 且 金克木(五行) 同时成立。
def test_structured_log_schema():
    print("== 强制结构化战斗日志契约 D7 ==")
    atk = M.make_unit(150, 60, 250, 40, "体修", "金", "单", 名称="攻方")
    dfn = M.make_unit(70, 35, 200, 25, "道修", "木", "单", 名称="守方")
    r = M.结算_1v1(atk, dfn, "full")
    log = r["battle_log"]
    check("battle_log 为列表", isinstance(log, list))
    check("battle_log 至少 1 条", len(log) >= 1, "len=%d" % len(log))
    必备键 = ("round", "actor", "target", "damage", "is_crit", "is_restrain",
             "attacker_hp", "defender_hp")
    ok_schema = True
    ok_bool = True
    for e in log:
        for k in 必备键:
            if k not in e:
                ok_schema = False
        if not isinstance(e.get("is_crit"), bool) or not isinstance(e.get("is_restrain"), bool):
            ok_bool = False
    check("每条日志含 8 个结构化字段", ok_schema)
    check("is_crit / is_restrain 为布尔", ok_bool)
    # 职业克制可验证：体修 攻 道修 → 体修克道修 → 日志应出现 is_restrain=true
    any_restrain = any(e.get("is_restrain") for e in log)
    check("体修克道修 至少一次触发克制标记", any_restrain)


# ============ 7. 车轮战 结算_3v3（与 GDScript 同步，AC7④ / D7）============
def test_wheel_3v3():
    print("== 车轮战 结算_3v3 ==")
    # 攻方强队（2 人），守方弱队（2 人）→ 攻方应全灭守方，is_win=True
    a1 = M.make_unit(200, 80, 300, 50, "道修", "金", "单", 名称="攻1")
    a2 = M.make_unit(180, 70, 280, 45, "体修", "木", "单", 名称="攻2")
    d1 = M.make_unit(60, 30, 120, 20, "法修", "木", "单", 名称="守1")
    d2 = M.make_unit(50, 25, 100, 18, "法修", "土", "单", 名称="守2")

    r = M.结算_3v3([a1, a2], [d1, d2], "quick")
    check("3v3 强攻方胜 is_win=True", r["is_win"] is True, str(r))
    check("3v3 round_count>0", r["round_count"] > 0, "round=%s" % r["round_count"])
    check("3v3 remaining_hp>=0", r["remaining_hp"] >= 0, "hp=%s" % r["remaining_hp"])
    # 统一 BattleResult 结构契约
    for k in ("is_win", "round_count", "remaining_hp", "drop_reward", "battle_log"):
        check("3v3 BattleResult 含字段 %s" % k, k in r)
    # 合并日志每条含 8 个结构化字段（D7）
    ok_schema = all(
        all(kk in e for kk in ("round", "actor", "target", "damage",
                               "is_crit", "is_restrain", "attacker_hp", "defender_hp"))
        for e in r["battle_log"]
    )
    check("3v3 每条日志含 8 结构化字段", ok_schema)
    check("3v3 合并日志非空", len(r["battle_log"]) >= 1)

    # 1v1 等价：攻方1人 vs 守方1人，结算_3v3 结果应与 结算_1v1 一致
    s1 = M.make_unit(200, 80, 300, 50, "道修", "金", "单", 名称="攻")
    s2 = M.make_unit(60, 30, 120, 20, "法修", "木", "单", 名称="守")
    r1v1 = M.结算_1v1(s1, s2, "quick")
    r3v3 = M.结算_3v3([s1], [s2], "quick")
    check("3v3(1v1) 与 1v1 胜负一致", r1v1["is_win"] == r3v3["is_win"])
    check("3v3(1v1) 与 1v1 回合一致", r1v1["round_count"] == r3v3["round_count"])
    check("3v3(1v1) 与 1v1 剩余气血一致", r1v1["remaining_hp"] == r3v3["remaining_hp"])

    # 守方强（强于攻方）→ 攻方败，is_win=False（is_win=攻方是否全灭守方）
    d_strong = M.make_unit(400, 150, 600, 80, "法修", "木", "单", 名称="强守")
    r3 = M.结算_3v3([a1], [d_strong], "quick")
    check("3v3 守方强 攻方败 is_win=False", r3["is_win"] is False, str(r3))

    # quick 确定性：同输入两次结果完全一致
    r_a = M.结算_3v3([a1, a2], [d1, d2], "quick")
    r_b = M.结算_3v3([a1, a2], [d1, d2], "quick")
    check("3v3 quick 确定性（同输入同结果）",
          r_a["is_win"] == r_b["is_win"] and r_a["round_count"] == r_b["round_count"]
          and r_a["remaining_hp"] == r_b["remaining_hp"])

    # 深拷贝：结算_3v3 不改动外部传入单位的血量
    ext = M.make_unit(200, 80, 300, 50, "道修", "金", "单", 名称="攻")
    M.结算_3v3([ext], [M.make_unit(60, 30, 120, 20, "法修", "木", "单", 名称="守")], "quick")
    check("3v3 深拷贝不改动外部传入单位血", ext["属性"]["血"] == 300, "hp=%s" % ext["属性"]["血"])

    # quick / full 偏差≤10%（AC7④）：攻方明显强于守方时两模式胜率与回合应接近
    rng = random.Random(20260719)
    atk = M.make_unit(220, 90, 320, 55, "道修", "金", "单", 暴击=0.3, 闪避=0.1, 名称="攻")
    dfn = M.make_unit(70, 40, 160, 30, "法修", "木", "单", 暴击=0.1, 闪避=0.05, 名称="守")
    q = M.结算_3v3([atk], [dfn], "quick")
    N = 200
    wins = 0
    rounds_sum = 0
    for _ in range(N):
        rr = M.结算_3v3([atk], [dfn], "full", rng)
        if rr["is_win"]:
            wins += 1
        rounds_sum += rr["round_count"]
    full_wr = wins / N
    full_avg = rounds_sum / N
    dev_win = abs(full_wr - (1.0 if q["is_win"] else 0.0))
    dev_round = abs(full_avg - q["round_count"]) / max(1, q["round_count"])
    check("3v3 速算/完整 胜负偏差≤10%% (dev=%.3f)" % dev_win, dev_win <= 0.10,
          "full wr=%.3f quick=%s" % (full_wr, q["is_win"]))
    check("3v3 速算/完整 回合偏差≤10%% (dev=%.3f)" % dev_round, dev_round <= 0.10,
          "full=%.2f quick=%d" % (full_avg, q["round_count"]))


# ============ 8. S1 灵兽行动日志注入（编排层，与主宠高频/副宠低频关键 规则）============
def test_灵兽行动日志():
    print("== S1 灵兽行动日志注入（主宠高频 / 副宠低频关键）==")
    # 合成子战斗 局：含一条暴击条目
    局_暴击 = {"battle_log": [
        {"round": 1, "actor": "甲", "target": "乙", "damage": 10, "is_crit": True,
         "is_restrain": False, "attacker_hp": 80, "defender_hp": 50},
        {"round": 2, "actor": "乙", "target": "甲", "damage": 8, "is_crit": False,
         "is_restrain": False, "attacker_hp": 72, "defender_hp": 50},
    ]}
    攻 = M.make_unit(150, 60, 250, 40, "道修", "金", "单", 名称="甲",
                     灵兽=[{"名": "朱雀", "类型": "攻伐型", "主副": "主"},
                           {"名": "灵尾兔", "类型": "辅助型", "主副": "副"}])
    守 = M.make_unit(70, 35, 200, 25, "法修", "木", "单", 名称="乙", 灵兽=[])
    总日志 = []
    M.注入灵兽日志(总日志, 局_暴击, 攻, 守)
    主宠 = [e for e in 总日志 if e.get("主副") == "主"]
    副宠 = [e for e in 总日志 if e.get("主副") == "副"]
    check("主宠条目存在(攻方)", len(主宠) == 1 and "朱雀" in 主宠[0]["actor"])
    check("副宠条目存在(本局有暴击)", len(副宠) == 1 and "灵尾兔" in 副宠[0]["actor"])
    必备键 = ("round", "actor", "target", "damage", "is_crit", "is_restrain", "attacker_hp", "defender_hp")
    check("灵兽条目含全部 8 结构化键", 主宠 and all(k in 主宠[0] for k in 必备键))
    check("灵兽条目 damage=0(仅叙事不双算)", 主宠 and 主宠[0]["damage"] == 0 and (not 副宠 or 副宠[0]["damage"] == 0))
    check("灵兽条目标记 pet_action", 主宠 and 主宠[0].get("pet_action") and (not 副宠 or 副宠[0].get("pet_action")))

    # 无暴击局：副宠不出现（低频关键），主宠仍出现（高频可见）
    局_无暴击 = {"battle_log": [
        {"round": 1, "actor": "甲", "target": "乙", "damage": 10, "is_crit": False,
         "is_restrain": False, "attacker_hp": 80, "defender_hp": 50},
    ]}
    总日志2 = []
    M.注入灵兽日志(总日志2, 局_无暴击, 攻, 守)
    主宠2 = [e for e in 总日志2 if e.get("主副") == "主"]
    副宠2 = [e for e in 总日志2 if e.get("主副") == "副"]
    check("无暴击局主宠仍出现", len(主宠2) == 1)
    check("无暴击局副宠不出现(低频关键)", len(副宠2) == 0)

    # 守方有副宠但无暴击 → 守方副宠也不出现
    守2 = M.make_unit(70, 35, 200, 25, "法修", "木", "单", 名称="乙",
                      灵兽=[{"名": "土甲龟", "类型": "防御型", "主副": "副"}])
    总日志3 = []
    M.注入灵兽日志(总日志3, 局_无暴击, 攻, 守2)
    副宠3 = [e for e in 总日志3 if e.get("主副") == "副"]
    check("守方副宠(无暴击)不出现", len(副宠3) == 0)


def main():
    print("==== BattleCalculator 数值红线断言 ====")
    test_wuxing_matrix()
    test_wuxing_bounds()
    test_profession_loop()
    test_boundaries()
    test_quick_vs_full()
    test_structured_log_schema()
    test_wheel_3v3()
    test_灵兽行动日志()
    print("")
    print("通过 %d / 失败 %d" % (PASS, FAIL))
    return FAIL


if __name__ == "__main__":
    sys.exit(1 if main() > 0 else 0)

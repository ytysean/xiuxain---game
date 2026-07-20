# -*- coding: utf-8 -*-
# combat_math.py —— BattleCalculator.gd 的 Python 真值镜像（TEST_STRATEGY LOGIC 层）
#
# 本文件是战斗核心数学的「断言真值源」：wuxing_multiplier + 伤害公式 + 1v1 结算 + 3v3 车轮。
# 必须与 E:\Xiuxian\taixuanzongmenlu\BattleCalculator.gd 保持逐行同步；
# 任何口径改动须同时改 GDScript 与 Python，否则 Python 单测即失效。
import copy
import random

# ============ 常量（与 BattleCalculator.gd 完全一致）============
五行序 = ["金", "木", "土", "水", "火"]
职业克制 = {"道修": "法修", "体修": "道修", "法修": "体修"}
纯度克制 = {"单": 1.25, "双": 1.0, "三": 0.75, "四+": 0.5}
纯度被克 = {"单": 0.82, "双": 1.0, "三": 0.67, "四+": 0.33}
五行上限 = 1.25
五行下限 = 0.82
职业克制乘率 = 1.20
职业被克乘率 = 0.85
防御减伤基准 = 200.0
防御减伤上限 = 0.75
暴击率上限 = 0.70
闪避率上限 = 0.40
暴击系数 = 1.5
浮动下限 = 0.9
浮动上限 = 1.1
伤害下限 = 1
回合上限 = 20


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


# ============ 纯函数：五行乘率（AC2 / D3）============
def wuxing_multiplier(atk_attr, def_attr, root_purity, is_true_damage=False):
    if is_true_damage:
        return 1.0
    if atk_attr == "" or def_attr == "" or atk_attr == def_attr:
        return 1.0
    if atk_attr not in 五行序 or def_attr not in 五行序:
        return 1.0
    i = 五行序.index(atk_attr)
    克制目标 = 五行序[(i + 1) % len(五行序)]
    mult = 1.0
    if 克制目标 == def_attr:
        mult = 纯度克制.get(root_purity, 1.0)
    elif 五行序[(五行序.index(def_attr) + 1) % len(五行序)] == atk_attr:
        mult = 纯度被克.get(root_purity, 1.0)
    return mult


# ============ 纯函数：职业克制乘率（AC3 / D2）============
def profession_multiplier(atk_prof, def_prof):
    if atk_prof == "" or def_prof == "":
        return 1.0
    if 职业克制.get(atk_prof, "") == def_prof:
        return 职业克制乘率
    if 职业克制.get(def_prof, "") == atk_prof:
        return 职业被克乘率
    return 1.0


# ============ 比率封顶（AC7② 边界）============
def 封顶暴击率(率):
    return clamp(率, 0.0, 暴击率上限)


def 封顶闪避率(率):
    return clamp(率, 0.0, 闪避率上限)


def _attrs(d, key):
    return d.get("属性", {}).get(key, 0)


# ============ 纯函数：单段伤害（ADR-003 D4）============
def calc_hit_damage(atk, def_, float_factor, crit_mult, dodge_mult, is_true=False):
    if dodge_mult <= 0.0:
        return 0
    攻击 = float(_attrs(atk, "攻"))
    if 攻击 <= 0:
        return 0
    防御 = float(_attrs(def_, "防"))
    减伤率 = clamp(防御 / (防御 + 防御减伤基准), 0.0, 防御减伤上限)
    wux = wuxing_multiplier(
        atk.get("灵根", {}).get("主", ""),
        def_.get("灵根", {}).get("主", ""),
        atk.get("灵根", {}).get("纯度", "单"),
        is_true,
    )
    dmg = (
        攻击
        * profession_multiplier(atk.get("职业", ""), def_.get("职业", ""))
        * (1.0 + float(atk.get("通用增益", 0.0)))
        * (1.0 + float(atk.get("道心增益", 0.0)))
        * wux
        * (1.0 - 减伤率)
        * crit_mult
    )
    dmg *= float_factor
    return int(max(伤害下限, round(dmg)))


# ============ 单场 1v1 结算（双模式，与 GDScript 结算_1v1 同步）============
def 结算_1v1(atk, def_, mode="full", rng=None):
    rng = rng or random
    a_hp = int(_attrs(atk, "血"))
    d_hp = int(_attrs(def_, "血"))
    a_spd = float(_attrs(atk, "速"))
    d_spd = float(_attrs(def_, "速"))
    a_crit = 封顶暴击率(float(atk.get("暴击率", 0.0)))
    d_crit = 封顶暴击率(float(def_.get("暴击率", 0.0)))
    a_dodge = 封顶闪避率(float(atk.get("闪避率", 0.0)))
    d_dodge = 封顶闪避率(float(def_.get("闪避率", 0.0)))
    a_name = atk.get("名称", "攻方")
    d_name = def_.get("名称", "守方")
    回合 = 0
    日志 = []
    攻先手 = a_spd >= d_spd
    while True:
        回合 += 1
        if 回合 > 回合上限:
            break
        if 攻先手:
            出手序 = [{"actor": atk, "target": def_}, {"actor": def_, "target": atk}]
        else:
            出手序 = [{"actor": def_, "target": atk}, {"actor": atk, "target": def_}]
        for 步 in 出手序:
            if a_hp <= 0 or d_hp <= 0:
                break
            actor = 步["actor"]
            target = 步["target"]
            actor_crit = a_crit if actor is atk else d_crit
            target_dodge = d_dodge if target is def_ else a_dodge
            actor_label = a_name if actor is atk else d_name
            target_label = d_name if target is def_ else a_name
            if mode == "quick":
                float_factor = 1.0
                crit_mult = 1.0 + actor_crit * (暴击系数 - 1.0)
                dodge_mult = 1.0 - target_dodge
            else:
                float_factor = rng.uniform(浮动下限, 浮动上限)
                crit_mult = 暴击系数 if rng.random() < actor_crit else 1.0
                dodge_mult = 0.0 if rng.random() < target_dodge else 1.0
            伤害 = calc_hit_damage(actor, target, float_factor, crit_mult, dodge_mult, False)
            if target is def_:
                d_hp -= 伤害
            else:
                a_hp -= 伤害
            # D7 强制结构化日志：每回合双方出手均记录（行动单位/伤害/暴击/克制/双方剩余血量）
            日志.append(
                {
                    "round": 回合,
                    "actor": actor_label,
                    "target": target_label,
                    "damage": 伤害,
                    "is_crit": crit_mult > 1.0,
                    "is_restrain": profession_multiplier(
                        actor.get("职业", ""), target.get("职业", "")
                    )
                    > 1.0,
                    "attacker_hp": a_hp,
                    "defender_hp": d_hp,
                }
            )
        if a_hp <= 0 or d_hp <= 0:
            break
    is_win = False
    if d_hp <= 0 and a_hp > 0:
        is_win = True
    elif a_hp <= 0 and d_hp > 0:
        is_win = False
    else:
        is_win = False
    remaining = a_hp if is_win else d_hp
    return {
        "is_win": is_win,
        "round_count": 回合,
        "remaining_hp": remaining,
        "drop_reward": [],
        "battle_log": 日志,
    }


def make_unit(攻, 防, 血, 速, 职业, 灵根主, 纯度, 暴击=0.0, 闪避=0.0, 名称="", 通用增益=0.0, 道心增益=0.0):
    """测试用快照工厂：结构与 disciple.get_final_combat_attr() 一致。"""
    return {
        "属性": {"攻": 攻, "防": 防, "血": 血, "速": 速},
        "职业": 职业,
        "灵根": {"主": 灵根主, "纯度": 纯度},
        "通用增益": 通用增益,
        "道心增益": 道心增益,
        "暴击率": 暴击,
        "闪避率": 闪避,
        "名称": 名称,
    }


# ============ 车轮战 3v3 结算（双模式，与 GDScript 结算_3v3 同步）============
# 注：GDScript 生产版 结算_3v3 签名为 (atk_list, def_list, mode="quick")，full 模式用全局 randf()；
#     本 Python 镜像额外接受可选 rng（仅测试用），转发给 结算_1v1 以便可复现采样。
def 结算_3v3(atk_list, def_list, mode="quick", rng=None):
    # 深拷贝单位，避免改动外部传入字典（车轮下位满血由副本保证）
    攻 = [copy.deepcopy(u) for u in atk_list]
    守 = [copy.deepcopy(u) for u in def_list]
    a_idx = 0
    d_idx = 0
    总日志 = []
    总回合 = 0
    while a_idx < len(攻) and d_idx < len(守):
        局 = 结算_1v1(攻[a_idx], 守[d_idx], mode, rng)
        总回合 += 局["round_count"]
        总日志.extend(局["battle_log"])
        # 气血继承：把本局终态写回当前单位（胜者保留剩余气血，败者记为 0）
        if 局["battle_log"]:
            末 = 局["battle_log"][-1]
            攻[a_idx]["属性"]["血"] = 末["attacker_hp"]
            守[d_idx]["属性"]["血"] = 末["defender_hp"]
        # 战败方下一位上场
        if 局["is_win"]:
            d_idx += 1
        else:
            a_idx += 1
    攻胜 = a_idx < len(攻)
    剩余 = 0
    if 攻胜:
        for i in range(a_idx, len(攻)):
            剩余 += max(0, int(攻[i]["属性"].get("血", 0)))
    else:
        for i in range(d_idx, len(守)):
            剩余 += max(0, int(守[i]["属性"].get("血", 0)))
    return {
        "is_win": 攻胜,
        "round_count": 总回合,
        "remaining_hp": 剩余,
        "drop_reward": [],
        "battle_log": 总日志,
    }

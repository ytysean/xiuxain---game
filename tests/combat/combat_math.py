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

# 灵力（mp）资源（§9.7.1 / D4：回复=10 已定；初始/上限 [PLACEHOLDER] 待实测）
灵力回复 = 10.0      # §9.7.1 每回合回复 10 点基础灵力（D4 已定）
灵力初始 = 30.0      # [PLACEHOLDER] D4：mp 初始值，待战斗基线实测校准
灵力上限 = 60.0      # [PLACEHOLDER] D4：mp 上限，须 ≥ 最大 mp_cost(40)
常驻回合 = 999       # 被动天赋常驻增益持续回合（整场战斗不消散）


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


# ============ 结构化战斗日志单条（D7 / S0 / S1）============
# log_type/tags/extra + S1预埋 ref_type/ref_id/ref_name；
# tags 自动映射 暴击/克制/闪避(伤害0且damage)/击败(守方血<=0且damage)。
def _log_entry(回合, actor, target, 伤害, 暴击, 克制, 攻方血, 守方血, log_type="damage", extra="", ref_type="", ref_id="", ref_name=""):
    标签 = []
    if 暴击:
        标签.append("暴击")
    if 克制:
        标签.append("克制")
    if 伤害 == 0 and log_type == "damage":
        标签.append("闪避")
    if 守方血 <= 0 and log_type == "damage":
        标签.append("击败")
    return {
        "round": 回合,
        "actor": actor,
        "target": target,
        "damage": 伤害,
        "is_crit": 暴击,
        "is_restrain": 克制,
        "attacker_hp": 攻方血,
        "defender_hp": 守方血,
        "log_type": log_type,
        "tags": 标签,
        "extra": extra,
        "ref_type": ref_type,
        "ref_id": ref_id,
        "ref_name": ref_name,
    }


# ============ S1 批3：单位工作态 / Buff / 技能 辅助（纯函数，无 Game 依赖）============
def _带技能(u):
    return len(u.get("技能", [])) > 0


def _build_unit_state(snap):
    base = {}
    cur = {}
    src = snap.get("属性", {})
    for k in ["攻", "防", "血", "速", "灵力"]:
        v = float(src.get(k, 0))
        base[k] = v
        cur[k] = v
    st = {
        "snapshot": snap,
        "base属性": base,
        "cur属性": cur,
        "active_buffs": [],
        "cooldowns": {},
        "mp": 灵力初始,
        "mp_max": 灵力上限,
        "base闪避": 封顶闪避率(float(snap.get("闪避率", 0.0))),
        "base暴击": 封顶暴击率(float(snap.get("暴击率", 0.0))),
        "cur闪避": 封顶闪避率(float(snap.get("闪避率", 0.0))),
        "cur暴击": 封顶暴击率(float(snap.get("暴击率", 0.0))),
    }
    # 进场被动天赋 → 常驻自增益（§3.2.5；本批 技能恒为[]故不触发，批4 接管）
    for sk in snap.get("技能", []):
        if not isinstance(sk, dict):
            continue
        if sk.get("skill_type", "") == "被动天赋":
            pb = _被动_to_buff(sk)
            if pb:
                _apply_buff(st, pb, "passive")
    return st


def _recompute_attr(st):
    base = st["base属性"]
    cur = st["cur属性"]
    for k in ["攻", "防", "速"]:
        v = float(base[k])
        for b in st["active_buffs"]:
            if b["类型"] == "控制":
                continue
            if b["作用属性"] != "全" and b["作用属性"] != k:
                continue
            sign = 1.0 if b["类型"] == "增益" else -1.0
            if b["数值类型"] == "percent":
                v += float(base[k]) * float(b["数值"]) * sign
            elif b["数值类型"] == "flat":
                v += float(b["数值"]) * sign
        cur[k] = max(0.0, v)
    # 速变动 → 重算 闪避率/暴击率（按 base 比例代理，[PLACEHOLDER] 待校准）
    base速 = float(base["速"])
    if base速 > 0:
        ratio = float(cur["速"]) / base速
        st["cur闪避"] = clamp(st["base闪避"] * ratio, 0.0, 闪避率上限)
        st["cur暴击"] = clamp(st["base暴击"] * ratio, 0.0, 暴击率上限)
    else:
        st["cur闪避"] = st["base闪避"]
        st["cur暴击"] = st["base暴击"]


def _tick_buffs(st, other_st, side_is_atk, 回合, 日志):
    # ① 持续伤害 dot
    for b in st["active_buffs"]:
        if b["类型"] != "dot":
            continue
        损 = 0
        if b["数值类型"] == "percent":
            损 = int(st["cur属性"]["血"] * float(b["数值"]))
        else:
            损 = int(float(b["数值"]))
        st["cur属性"]["血"] = float(st["cur属性"]["血"]) - max(1, 损)
        日志.append(_log_entry(回合, st["snapshot"].get("名称", "?"), st["snapshot"].get("名称", "?"), 0, False, False,
            int(st["cur属性"]["血"]) if side_is_atk else int(other_st["cur属性"]["血"]),
            int(other_st["cur属性"]["血"]) if side_is_atk else int(st["cur属性"]["血"]),
            "buff_tick", "", "buff", b["buff_id"], b["buff名"]))
    # ② 控制：仅标记（行动阶段跳过），此处不处理
    # ③ 增益/减益 → 重算 cur属性（含 速，触发 闪避/暴击重算）
    _recompute_attr(st)
    # ④ 灵力回复
    st["mp"] = min(float(st["mp_max"]), float(st["mp"]) + 灵力回复)
    # ⑤ 消散：剩余回合 -=1，<=0 移除并写 buff_expire
    keep = []
    for b in st["active_buffs"]:
        if b.get("常驻", False):
            keep.append(b)
            continue
        b["剩余回合"] = int(b["剩余回合"]) - 1
        if b["剩余回合"] > 0:
            keep.append(b)
        else:
            日志.append(_log_entry(回合, st["snapshot"].get("名称", "?"), st["snapshot"].get("名称", "?"), 0, False, False,
                int(st["cur属性"]["血"]) if side_is_atk else int(other_st["cur属性"]["血"]),
                int(other_st["cur属性"]["血"]) if side_is_atk else int(st["cur属性"]["血"]),
                "buff_expire", "", "buff", b["buff_id"], b["buff名"]))
    st["active_buffs"] = keep


def _has_control(st):
    for b in st["active_buffs"]:
        if b["类型"] == "控制":
            return True
    return False


def _apply_buff(st, template, source):
    b = copy.deepcopy(template)
    b["剩余回合"] = int(b.get("持续回合", 1))
    b["来源"] = source
    b["层数"] = 1
    b["常驻"] = False
    # 不可叠加：同 buff_id 先移除旧层
    if not b.get("可叠加", False):
        keep = []
        for old in st["active_buffs"]:
            if old["buff_id"] != b["buff_id"]:
                keep.append(old)
        st["active_buffs"] = keep
    st["active_buffs"].append(b)
    # 作用属性 == 血：增益即时折算到 HP 池（dot 由 tick 处理；护盾/回春近似即时治疗，[PLACEHOLDER]）
    if b["作用属性"] == "血" and b["类型"] == "增益":
        heal = max(1, int(float(st["base属性"]["血"]) * float(b["数值"])))
        st["cur属性"]["血"] = float(st["cur属性"]["血"]) + heal


def _被动_to_buff(sk):
    et = sk.get("effect_type", "")
    ev = float(sk.get("effect_value", 0))
    if et == "减伤":
        return {"buff_id": sk.get("skill_id", ""), "buff名": sk.get("skill_name", "被动"), "类型": "增益", "作用属性": "防", "数值": ev, "数值类型": "percent", "持续回合": 常驻回合, "来源类型": "passive", "可叠加": False}
    if et == "增伤":
        return {"buff_id": sk.get("skill_id", ""), "buff名": sk.get("skill_name", "被动"), "类型": "增益", "作用属性": "攻", "数值": ev, "数值类型": "percent", "持续回合": 常驻回合, "来源类型": "passive", "可叠加": False}
    return {}


def _buff模板(buff_id):
    if buff_id == "bf_burn":
        return {"buff_id": "bf_burn", "buff名": "灼烧", "类型": "dot", "作用属性": "血", "数值": 0.05, "数值类型": "percent", "持续回合": 2, "来源类型": "skill", "可叠加": False}
    if buff_id == "bf_freeze":
        return {"buff_id": "bf_freeze", "buff名": "冰冻", "类型": "控制", "作用属性": "全", "数值": 0.0, "数值类型": "none", "持续回合": 1, "来源类型": "skill", "可叠加": False}
    if buff_id == "bf_stun":
        return {"buff_id": "bf_stun", "buff名": "眩晕", "类型": "控制", "作用属性": "全", "数值": 0.0, "数值类型": "none", "持续回合": 1, "来源类型": "skill", "可叠加": False}
    if buff_id == "bf_shield":
        return {"buff_id": "bf_shield", "buff名": "护盾", "类型": "增益", "作用属性": "血", "数值": 0.15, "数值类型": "flat", "持续回合": 3, "来源类型": "skill", "可叠加": False}
    if buff_id == "bf_atkup":
        return {"buff_id": "bf_atkup", "buff名": "攻击增益", "类型": "增益", "作用属性": "攻", "数值": 0.10, "数值类型": "percent", "持续回合": 3, "来源类型": "skill", "可叠加": True}
    if buff_id == "bf_defdown":
        return {"buff_id": "bf_defdown", "buff名": "破甲", "类型": "减益", "作用属性": "防", "数值": 0.20, "数值类型": "percent", "持续回合": 2, "来源类型": "skill", "可叠加": False}
    if buff_id == "bf_defup":
        return {"buff_id": "bf_defup", "buff名": "防御增益", "类型": "增益", "作用属性": "防", "数值": 0.15, "数值类型": "percent", "持续回合": 3, "来源类型": "passive", "可叠加": False}
    if buff_id == "bf_spdup":
        return {"buff_id": "bf_spdup", "buff名": "疾行", "类型": "增益", "作用属性": "速", "数值": 0.15, "数值类型": "percent", "持续回合": 3, "来源类型": "passive", "可叠加": False}
    if buff_id == "bf_regen":
        return {"buff_id": "bf_regen", "buff名": "回春", "类型": "增益", "作用属性": "血", "数值": 0.08, "数值类型": "percent", "持续回合": 3, "来源类型": "item", "可叠加": False}
    return {}


def _skill_buff映射(skill):
    sid = skill.get("skill_id", "")
    if sid == "sk_ti_02":
        return [{"buff": "bf_shield", "目标": "self"}]
    if sid == "sk_ti_05":
        return [{"buff": "bf_stun", "目标": "enemy"}]
    if sid == "sk_dao_02":
        return [{"buff": "bf_defdown", "目标": "enemy"}]
    if sid == "sk_fa_02":
        return [{"buff": "bf_burn", "目标": "enemy"}]
    if sid == "sk_fa_03":
        return [{"buff": "bf_freeze", "目标": "enemy"}]
    if sid == "sk_fa_05":
        return [{"buff": "bf_burn", "目标": "enemy"}]
    return []


def _select_skill(actor_st, target_st):
    cands = []
    for sk in actor_st["snapshot"].get("技能", []):
        if not isinstance(sk, dict):
            continue
        if sk.get("skill_type", "") == "被动天赋":
            continue
        sid = sk.get("skill_id", "")
        cd = int(actor_st["cooldowns"].get(sid, 0))
        cost = float(sk.get("mp_cost", 0))
        if cd == 0 and float(actor_st["mp"]) >= cost:
            cands.append(sk)
    if not cands:
        return {}
    # §9.8.5：体修残血优先护盾/防御技；法修多目标优先群体（1v1 退化为高伤优先）
    prof = actor_st["snapshot"].get("职业", "")
    hp_pct = float(actor_st["cur属性"]["血"]) / max(1.0, float(actor_st["base属性"]["血"]))
    if prof == "体修" and hp_pct < 0.5:
        for sk in cands:
            if sk.get("effect_type", "") in ["护盾", "减伤", "伤害+控制"]:
                return sk
    # 高伤优先：按 damage_rate 降序取最高
    best = {}
    best_rate = -1.0
    for sk in cands:
        r = float(sk.get("damage_rate", 0))
        if r > best_rate:
            best_rate = r
            best = sk
    return best


def _build_actor_view(st):
    view = copy.deepcopy(st["snapshot"])
    view["属性"] = st["cur属性"]   # cur属性 含 攻/防/血/速/灵力（与快照键名一致）
    return view


def _cast_skill(actor_st, target_st, skill, 回合, 日志, rng=None):
    rng = rng or random
    actor_view = _build_actor_view(actor_st)
    target_view = _build_actor_view(target_st)
    rate = float(skill.get("damage_rate", 1.0))
    # 技能伤害 = calc_hit_damage(actor_view × damage_rate, target)；攻 × damage_rate
    actor_view["属性"] = copy.deepcopy(actor_st["cur属性"])
    actor_view["属性"]["攻"] = float(actor_st["cur属性"]["攻"]) * rate
    float_factor = rng.uniform(浮动下限, 浮动上限)
    crit_mult = 暴击系数 if rng.random() < float(actor_st["cur暴击"]) else 1.0
    dodge_mult = 0.0 if rng.random() < float(target_st["cur闪避"]) else 1.0
    伤害 = calc_hit_damage(actor_view, target_view, float_factor, crit_mult, dodge_mult, False)
    target_st["cur属性"]["血"] = float(target_st["cur属性"]["血"]) - 伤害
    # 施加 buff（按 §3.2.5 映射：self/enemy）
    for m in _skill_buff映射(skill):
        buff_id = m["buff"]
        tgt = target_st if m["目标"] == "enemy" else actor_st
        tpl = _buff模板(buff_id)
        if tpl:
            _apply_buff(tgt, tpl, "skill")
            # buff_apply 日志（§3.3）
            日志.append(_log_entry(回合, actor_st["snapshot"].get("名称", "攻方"), target_st["snapshot"].get("名称", "守方"), 0, False, False,
                int(actor_st["cur属性"]["血"]), int(target_st["cur属性"]["血"]),
                "buff_apply", "", "buff", buff_id, tpl["buff名"]))
    # cast_skill 日志（带 ref）
    日志.append(_log_entry(回合, actor_st["snapshot"].get("名称", "攻方"), target_st["snapshot"].get("名称", "守方"), 伤害,
        crit_mult > 1.0,
        profession_multiplier(actor_view.get("职业", ""), target_view.get("职业", "")) > 1.0,
        int(actor_st["cur属性"]["血"]), int(target_st["cur属性"]["血"]),
        "cast_skill", "", "skill", skill.get("skill_id", ""), skill.get("skill_name", "")))
    # 冷却 + 灵力
    actor_st["cooldowns"][skill.get("skill_id", "")] = int(skill.get("cooldown", 0))
    actor_st["mp"] = float(actor_st["mp"]) - float(skill.get("mp_cost", 0))


def _tick_cooldowns(st):
    for k in list(st["cooldowns"].keys()):
        st["cooldowns"][k] = max(0, int(st["cooldowns"][k]) - 1)


# ============ 单场 1v1 结算（双模式）============
# S1 批3：快照无 技能（现役默认）时走 _结算_1v1_原版（与批3前逐字节一致，72 断言硬门槛）；
#         含 技能 时走 _结算_1v1_增强（单位工作态 + Buff 生命周期 + 技能释放/冷却）。
def 结算_1v1(atk, def_, mode="full", rng=None):
    rng = rng or random
    if not _带技能(atk) and not _带技能(def_):
        return _结算_1v1_原版(atk, def_, mode, rng)
    return _结算_1v1_增强(atk, def_, mode, rng)


# ============ 原版（批3前逐字节一致；休眠路径，现役快照无 技能 走此）============
def _结算_1v1_原版(atk, def_, mode="full", rng=None):
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
            日志.append(_log_entry(回合, actor_label, target_label, 伤害, crit_mult > 1.0,
                profession_multiplier(actor.get("职业", ""), target.get("职业", "")) > 1.0,
                a_hp, d_hp))
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


# —— 增强版（S1 批3：单位工作态 + Buff 生命周期 + 技能释放/冷却；ADR-003 纯函数）——
def _结算_1v1_增强(atk, def_, mode="full", rng=None):
    rng = rng or random
    a_state = _build_unit_state(atk)
    d_state = _build_unit_state(def_)
    a_name = atk.get("名称", "攻方")
    d_name = def_.get("名称", "守方")
    回合 = 0
    日志 = []
    攻先手 = a_state["cur属性"]["速"] >= d_state["cur属性"]["速"]
    while True:
        回合 += 1
        if 回合 > 回合上限:
            break
        # §9.7.2 回合开始 tick（出手序之前）：dot→控制标记→重算→灵力回复→消散
        _tick_buffs(a_state, d_state, True, 回合, 日志)
        _tick_buffs(d_state, a_state, False, 回合, 日志)
        # 速变动 → 重算先手
        攻先手 = a_state["cur属性"]["速"] >= d_state["cur属性"]["速"]
        if 攻先手:
            出手序 = [{"atk": True}, {"atk": False}]
        else:
            出手序 = [{"atk": False}, {"atk": True}]
        for 步 in 出手序:
            if a_state["cur属性"]["血"] <= 0 or d_state["cur属性"]["血"] <= 0:
                break
            is_atk = 步["atk"]
            actor_st = a_state if is_atk else d_state
            target_st = d_state if is_atk else a_state
            actor_label = a_name if is_atk else d_name
            target_label = d_name if is_atk else a_name
            # 控制跳过行动（§3.1.6）
            if _has_control(actor_st):
                日志.append(_log_entry(回合, actor_label, target_label, 0, False, False,
                    int(a_state["cur属性"]["血"]), int(d_state["cur属性"]["血"]),
                    "control_skip", "", "buff", "", "控制"))
                continue
            # 技能释放（§9.8.5 自动 AI）：就绪则释放并跳过普攻
            chosen = _select_skill(actor_st, target_st)
            if chosen:
                _cast_skill(actor_st, target_st, chosen, 回合, 日志, rng)
                continue
            # 普攻（与今日数学一致：calc_hit_damage 签名不改，仅喂 cur属性 视图）
            actor_view = _build_actor_view(actor_st)
            target_view = _build_actor_view(target_st)
            actor_crit = actor_st["cur暴击"]
            target_dodge = target_st["cur闪避"]
            if mode == "quick":
                float_factor = 1.0
                crit_mult = 1.0 + actor_crit * (暴击系数 - 1.0)
                dodge_mult = 1.0 - target_dodge
            else:
                float_factor = rng.uniform(浮动下限, 浮动上限)
                crit_mult = 暴击系数 if rng.random() < actor_crit else 1.0
                dodge_mult = 0.0 if rng.random() < target_dodge else 1.0
            伤害 = calc_hit_damage(actor_view, target_view, float_factor, crit_mult, dodge_mult, False)
            if is_atk:
                d_state["cur属性"]["血"] = float(d_state["cur属性"]["血"]) - 伤害
            else:
                a_state["cur属性"]["血"] = float(a_state["cur属性"]["血"]) - 伤害
            # D7 强制结构化日志：每次普攻均记录
            日志.append(_log_entry(回合, actor_label, target_label, 伤害, crit_mult > 1.0,
                profession_multiplier(actor_view.get("职业", ""), target_view.get("职业", "")) > 1.0,
                int(a_state["cur属性"]["血"]), int(d_state["cur属性"]["血"])))
        # 回合末冷却 tick
        _tick_cooldowns(a_state)
        _tick_cooldowns(d_state)
        if a_state["cur属性"]["血"] <= 0 or d_state["cur属性"]["血"] <= 0:
            break
    is_win = False
    if d_state["cur属性"]["血"] <= 0 and a_state["cur属性"]["血"] > 0:
        is_win = True
    elif a_state["cur属性"]["血"] <= 0 and d_state["cur属性"]["血"] > 0:
        is_win = False
    else:
        is_win = False
    remaining = int(a_state["cur属性"]["血"]) if is_win else int(d_state["cur属性"]["血"])
    return {
        "is_win": is_win,
        "round_count": 回合,
        "remaining_hp": remaining,
        "drop_reward": [],
        "battle_log": 日志,
    }


def make_unit(攻, 防, 血, 速, 职业, 灵根主, 纯度, 暴击=0.0, 闪避=0.0, 名称="", 通用增益=0.0, 道心增益=0.0, 灵兽=None):
    """测试用快照工厂：结构与 disciple.get_final_combat_attr() 一致。灵兽=S1 出战灵兽快照列表。"""
    return {
        "属性": {"攻": 攻, "防": 防, "血": 血, "速": 速},
        "职业": 职业,
        "灵根": {"主": 灵根主, "纯度": 纯度},
        "通用增益": 通用增益,
        "道心增益": 道心增益,
        "暴击率": 暴击,
        "闪避率": 闪避,
        "名称": 名称,
        "灵兽": 灵兽 if 灵兽 is not None else [],
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
        # S1 战斗生效·优先级2：灵兽行动日志（编排层注入，不碰 结算_1v1 核心计算）
        注入灵兽日志(总日志, 局, 攻[a_idx], 守[d_idx])
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


# ============ 灵兽行动日志注入（镜像 BattleManager._注入灵兽日志，纯编排层）============
# 主宠每局一条（高频可见）；副宠仅本局出现暴击时一条（低频关键）；复用现有日志键。
def 注入灵兽日志(总日志, 局, 攻单位, 守单位):
    if not 局["battle_log"]:
        return
    日志 = 局["battle_log"]
    首 = 日志[0]
    局有暴击 = any(e.get("is_crit", False) for e in 日志)
    _注入单侧灵兽(总日志, 攻单位, 守单位, 首, True, 局有暴击)
    _注入单侧灵兽(总日志, 守单位, 攻单位, 首, False, 局有暴击)


def _注入单侧灵兽(总日志, 本方, 对方, 首, 本方是攻, 局有暴击):
    for p in 本方.get("灵兽", []):
        主副 = p.get("主副", "")
        if 主副 == "副" and not 局有暴击:
            continue
        本方_hp = 首.get("attacker_hp", 0) if 本方是攻 else 首.get("defender_hp", 0)
        对方_hp = 首.get("defender_hp", 0) if 本方是攻 else 首.get("attacker_hp", 0)
        总日志.append({
            "round": 首.get("round", 0),
            "actor": "%s·%s[%s]" % (本方.get("名称", ""), p.get("名", ""), p.get("类型", "")),
            "target": 对方.get("名称", ""),
            "damage": 0,
            "is_crit": False,
            "is_restrain": False,
            "attacker_hp": 本方_hp,
            "defender_hp": 对方_hp,
            "pet_action": True,
            "主副": 主副,
        })

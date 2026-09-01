# _s13_enhanced_sim.py
# 验证 S2 增强档三处新增机制（精确镜像 BattleCalculator.gd / disciple.gd 真实逻辑，不编译 Godot）。
# 机制1: 3v3 全队光环传播  —— 结算_3v3 L738-757 + _应用初始buff L223-232 / _recompute_attr L234-258
# 机制2: 3v3 复活一次       —— 增强路径 _build_unit_state + _cast_skill L488-493 + _try_revive L304-321
# 机制3: 5件套装共鸣 +10%   —— disciple.gd 套装战斗加成 L325-356
#
# 所有镜像函数均标注对应 GDScript 行号，确保仿真即"预言机"。

# ───────────── 共享：buff 模板 / 应用 / 复活 ─────────────
def buff模板(buff_id):
    # 镜像 _buff模板 L352-380（仅取本仿真所需）
    if buff_id == "bf_revive":
        return {"buff_id": "bf_revive", "buff名": "复活", "类型": "增益", "作用属性": "无",
                "数值": 0.30, "数值类型": "percent", "持续回合": 9999}
    if buff_id == "bf_aura":
        return {"buff_id": "bf_aura", "buff名": "灵光护佑", "类型": "增益", "作用属性": "全",
                "数值": 0.15, "数值类型": "percent", "持续回合": 3}
    return {}

def apply_buff(st, template, source):
    # 镜像 _apply_buff L323-325
    b = dict(template)
    b["剩余回合"] = int(b.get("持续回合", 1))
    st["active_buffs"].append(b)

def try_revive(st, 回合, 日志):
    # 镜像 _try_revive L304-321
    if st["cur属性"]["血"] > 0:
        return
    idx = -1
    for i in range(len(st["active_buffs"])):
        if st["active_buffs"][i]["buff_id"] == "bf_revive":
            idx = i
            break
    if idx < 0:
        return
    b = st["active_buffs"][idx]
    frac = float(b.get("数值", 0.0))
    st["cur属性"]["血"] = float(int(float(st["base属性"]["血"]) * frac))
    del st["active_buffs"][idx]
    日志.append({"revive": True})

def skill_buff映射(skill):
    # 镜像 _skill_buff映射 L382-424（仅取 set_revive / set_aura 两条）
    sid = skill.get("skill_id", "")
    if sid == "set_revive":
        return [{"buff": "bf_revive", "目标": "self"}]
    if sid == "set_aura":
        return [{"buff": "bf_aura", "目标": "self"}]
    return []

def build_unit_state(snap):
    # 镜像 _build_unit_state L182-219（仅取与机制相关的 属性/初始buff/被动天赋）
    base = {}; cur = {}
    src = snap.get("属性", {})
    for k in ["攻", "防", "血", "速"]:
        v = float(src.get(k, 0))
        base[k] = v; cur[k] = v
    st = {"snapshot": snap, "base属性": base, "cur属性": cur, "active_buffs": []}
    # 进场被动天赋 → 常驻自增益（L204-210，本仿真单元无被动，跳过）
    # S2 增强·3v3 全队光环：快照携带 初始buff（常驻）（L212-218）
    for bid in snap.get("初始buff", []):
        if not isinstance(bid, str):
            continue
        tpl = buff模板(bid)
        if tpl:
            apply_buff(st, tpl, "aura")
            st["active_buffs"][-1]["常驻"] = True
            # 全属性类常驻 buff（bf_aura）最大生命加成：血属损耗池，进场一次性作用于 base/cur 血（L216-218 增补）
            if tpl.get("作用属性", "") == "全":
                mult = 1.0 + float(tpl.get("数值", 0.0))
                st["base属性"]["血"] *= mult
                st["cur属性"]["血"] *= mult
    return st

def recompute_attr(st):
    # 镜像 _recompute_attr L234-249：注意只重算 攻/防/速，不含 血（这是代码真实行为，见机制1 备注）
    base = st["base属性"]; cur = st["cur属性"]
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

def 应用初始buff(snap):
    # 镜像 _应用初始buff L223-232：原版路径（无技能）兜底消费 初始buff
    if "初始buff" not in snap:
        return
    for bid in snap["初始buff"]:
        if str(bid) == "bf_aura":
            a = snap.get("属性", {})
            for k in ["攻", "防", "血", "速"]:
                if k in a:
                    a[k] = float(a[k]) * 1.15
            break

# ───────────── 机制1：3v3 全队光环传播 ─────────────
def 注入全队光环(攻, 守):
    # 镜像 结算_3v3 L738-757：任一队员持 set_aura → 全队获得常驻 bf_aura，并移除个人 set_aura
    for 侧 in [攻, 守]:
        有光环 = False
        for u in 侧:
            for sk in u.get("技能", []):
                if isinstance(sk, dict) and sk.get("skill_id", "") == "set_aura":
                    有光环 = True
                    break
            if 有光环:
                break
        if 有光环:
            for u in 侧:
                if "初始buff" not in u:
                    u["初始buff"] = []
                if "bf_aura" not in u["初始buff"]:
                    u["初始buff"].append("bf_aura")
                新技能 = []
                for sk in u.get("技能", []):
                    if isinstance(sk, dict) and sk.get("skill_id", "") != "set_aura":
                        新技能.append(sk)
                u["技能"] = 新技能

print("=== 机制1：3v3 全队光环传播 ===")
# 攻方3人，第0人持 set_aura；守方无光环
攻方 = [
    {"名称": "攻A", "属性": {"攻": 100, "防": 100, "血": 100, "速": 100},
     "技能": [{"skill_id": "set_aura", "skill_name": "灵光佑", "skill_type": "增益"}]},
    {"名称": "攻B", "属性": {"攻": 100, "防": 100, "血": 100, "速": 100}, "技能": []},
    {"名称": "攻C", "属性": {"攻": 100, "防": 100, "血": 100, "速": 100}, "技能": []},
]
守方 = [
    {"名称": "守A", "属性": {"攻": 100, "防": 100, "血": 100, "速": 100}, "技能": []},
]
注入全队光环(攻方, 守方)
# 断言：攻方全队都拿到 bf_aura 初始buff，且个人 set_aura 已移除
for u in 攻方:
    assert "bf_aura" in u.get("初始buff", []), f"{u['名称']} 未获得全队光环"
    for sk in u.get("技能", []):
        assert sk.get("skill_id") != "set_aura", f"{u['名称']} 个人 set_aura 未移除"
assert "bf_aura" not in 守方[0].get("初始buff", []), "守方不应被注入光环"
print("  [OK] 攻方全队注入 bf_aura，个人 set_aura 已移除；守方未受影响")

# 应用：3v3 子战在 set_aura 移除后通常无其余技能 → 走原版路径 _应用初始buff（攻防血速全+15%）
for u in 攻方:
    应用初始buff(u)
for u in 攻方:
    for k in ["攻", "防", "血", "速"]:
        assert abs(float(u["属性"][k]) - 115.0) < 1e-6, f"{u['名称']}.{k} 应为115，实得{u['属性'][k]}"
print("  [OK] 原版路径应用：攻方全队 攻防血速 均 ×1.15 (100→115)")

# 增强路径(带其它技能)下，bf_aura 现在也应增幅 血：进场一次性作用于 base/cur 损耗池（不进 _recompute_attr 重置）
enh = build_unit_state({"属性": {"攻": 100, "防": 100, "血": 100, "速": 100}, "初始buff": ["bf_aura"]})
recompute_attr(enh)
assert abs(enh["cur属性"]["攻"] - 115.0) < 1e-6, "增强路径 攻 应+15%"
assert abs(enh["base属性"]["血"] - 115.0) < 1e-6, "增强路径 血(base) 应+15%"
assert abs(enh["cur属性"]["血"] - 115.0) < 1e-6, "增强路径 血(cur) 应+15%（进场一次性加成，不随回合重置）"
print("  [OK] 增强路径 bf_aura 现对 攻/防/血/速 均 +15%（血进场作用于损耗池，避免每回合回满）")

# ───────────── 机制2：3v3 复活一次 ─────────────
print("\n=== 机制2：3v3 复活一次（增强路径子战复用）===")
# 3v3 子战：单位带 set_revive 技能 → 增强路径；技能释放时注入 bf_revive，回合末 _try_revive 复活一次
unit = {"名称": "守将", "属性": {"攻": 100, "防": 100, "血": 1000, "速": 100},
        "技能": [{"skill_id": "set_revive", "skill_name": "浴火", "skill_type": "增益",
                  "effect_type": "增伤", "damage_rate": 1.0, "mp_cost": 0, "cooldown": 4}]}
st = build_unit_state(unit)
日志 = []
# 模拟第1回合技能释放：_cast_skill 内部对 set_revive 施加 bf_revive(self)（L488-493）
for m in skill_buff映射({"skill_id": "set_revive"}):
    if m["目标"] == "self":
        apply_buff(st, buff模板(m["buff"]), "skill")
assert any(b["buff_id"] == "bf_revive" for b in st["active_buffs"]), "bf_revive 应已注入"
# 致命伤
st["cur属性"]["血"] = 0
try_revive(st, 1, 日志)
print(f"  致命伤→复活：恢复血={st['cur属性']['血']} (期望300=1000*0.30)，触发={len(日志)>0}")
assert st["cur属性"]["血"] == 300 and len(日志) > 0, "revive 应恢复30%最大生命"
# 二次致命：buff 已消耗，不再复活
st["cur属性"]["血"] = 0
try_revive(st, 2, 日志)
assert st["cur属性"]["血"] == 0, "revive 仅触发一次"
print("  [OK] 3v3 子战复活机制复用增强路径：致命伤恢复一次(30%)后 buff 消耗，二次致死不触发")

# ───────────── 机制3：5件套装共鸣 +10% ─────────────
print("\n=== 机制3：5件套装共鸣 +10% ===")
# 镜像 disciple.gd 套装战斗加成 L325-356 + _解析套装效果/_解析单段 L358-381
套装库 = {
    "taiyi":   {"名称": "太一套", "2件": "全属性+3%", "3件": "全属性+5%", "5件": "全属性+12%"},
    "zhuxian": {"名称": "诛仙套", "毕业": True, "2件": "攻击+12%", "3件": "暴击+12%", "5件": "攻击+30%"},
}

def 解析单段(段, 合计):
    # 镜像 _解析单段 L366-381
    数文 = 段.replace("+", "").replace("%", "")
    for 词 in ["攻击", "防御", "全属性", "暴击", "反伤", "穿透", "减伤", "吸血", "闪避", "速度", "气血", "血"]:
        数文 = 数文.replace(词, "")
    数 = float(数文.strip() or 0) / 100.0
    if 数 <= 0.0:
        return
    if "全属性" in 段:
        for _st in ["攻", "防", "血", "速"]:
            合计[_st] += 数
    elif "攻击" in 段:
        合计["攻"] += 数
    elif "防御" in 段:
        合计["防"] += 数

def 解析套装效果(文案, 合计):
    # 镜像 _解析套装效果 L359-364
    if 文案 == "":
        return
    for 段 in 文案.replace("，", " ").replace("、", " ").split(" "):
        if 段:
            解析单段(段, 合计)

def 套装战斗加成(装备列表, 套装库):
    # 镜像 套装战斗加成 L325-356
    合计 = {"攻": 0.0, "防": 0.0, "血": 0.0, "速": 0.0, "暴击": 0.0, "反伤": 0.0, "穿透": 0.0,
            "减伤": 0.0, "吸血": 0.0, "闪避": 0.0}
    套装计数 = {}
    for it in 装备列表:
        sid = str(it.get("套装ID", ""))
        if sid == "":
            continue
        套装计数[sid] = 套装计数.get(sid, 0) + 1
    触发共鸣 = False
    for sid in 套装计数:
        数量 = 套装计数[sid]
        配置 = 套装库.get(sid, {})
        if not 配置:
            continue
        档位键 = ""
        if 数量 >= 5:
            档位键 = "5件"; 触发共鸣 = True
        elif 数量 >= 3:
            档位键 = "3件"
        elif 数量 >= 2:
            档位键 = "2件"
        if 档位键 == "":
            continue
        解析套装效果(配置.get(档位键, ""), 合计)
    if 触发共鸣:
        for _st in ["攻", "防", "血", "速"]:
            合计[_st] += 0.10
    return 合计, 触发共鸣

# 用例A：太一套 5件（全属性+12%）+ 共鸣+10% → 四维各 +0.22
装备A = [{"套装ID": "taiyi"} for _ in range(5)]
合计A, 共鸣A = 套装战斗加成(装备A, 套装库)
print(f"  太一套×5：攻={合计A['攻']:.2f} 防={合计A['防']:.2f} 血={合计A['血']:.2f} 速={合计A['速']:.2f} 共鸣={共鸣A}")
assert 共鸣A, "5件应触发共鸣"
for _st in ["攻", "防", "血", "速"]:
    assert abs(合计A[_st] - 0.22) < 1e-9, f"太一套5件 应=0.22，实得{合计A[_st]}"
print("  [OK] 太一套×5：5件档(全属性+12%) + 共鸣(+10%) = 攻防血速各 +22%")

# 用例B：诛仙套×5（攻击+30%）+ 共鸣+10%（仅四维，不含暴击）→ 攻=0.40 暴击=0
装备B = [{"套装ID": "zhuxian"} for _ in range(5)]
合计B, 共鸣B = 套装战斗加成(装备B, 套装库)
print(f"  诛仙套×5：攻={合计B['攻']:.2f} 暴击={合计B['暴击']:.2f} 共鸣={共鸣B}")
assert abs(合计B["攻"] - 0.40) < 1e-9, "诛仙5件 攻应=0.40(30%+10%共鸣)"
assert abs(合计B["暴击"] - 0.0) < 1e-9, "共鸣只加成四维，不染指暴击"
print("  [OK] 诛仙套×5：攻击+30% + 共鸣攻+10% = 攻+40%，暴击不受影响（共鸣仅限攻防血速）")

# 用例C：未达5件（3件）→ 不触发共鸣，仅档位效果
装备C = [{"套装ID": "taiyi"} for _ in range(3)]
合计C, 共鸣C = 套装战斗加成(装备C, 套装库)
print(f"  太一套×3：攻={合计C['攻']:.2f} 共鸣={共鸣C}")
assert not 共鸣C and abs(合计C["攻"] - 0.05) < 1e-9, "3件不触发共鸣，仅3件档全属性+5%"
print("  [OK] 太一套×3：仅3件档(全属性+5%)，未触发共鸣")

print("\n增强档三处新增机制仿真验证全部通过 ✓")

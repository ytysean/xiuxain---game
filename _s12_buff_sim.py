# 聚焦仿真：验证 S2 毕业新增 buff 的算法正确性（镜像 BattleCalculator.gd 相关逻辑）
# 不编译 Godot，仅复刻 _buff模板 / _tick_buffs(dot) / _try_revive 三段逻辑。

def buff模板(buff_id):
    if buff_id == "bf_true_dmg":
        return {"buff_id": "bf_true_dmg", "类型": "dot", "数值": 0.05, "数值类型": "percent", "持续回合": 2}
    if buff_id == "bf_burn":
        return {"buff_id": "bf_burn", "类型": "dot", "数值": 0.05, "数值类型": "percent", "持续回合": 2}
    if buff_id == "bf_revive":
        return {"buff_id": "bf_revive", "类型": "增益", "作用属性": "无", "数值": 0.30, "数值类型": "percent", "持续回合": 9999}
    return {}

def apply_buff(st, buff_id):
    b = dict(buff模板(buff_id))
    b["剩余回合"] = b["持续回合"]
    # 不可叠加：先移除同名
    st["active_buffs"] = [x for x in st["active_buffs"] if x["buff_id"] != buff_id]
    st["active_buffs"].append(b)

def tick_buffs(st, 回合):
    # ① dot
    for b in st["active_buffs"]:
        if b["类型"] != "dot":
            continue
        if b["buff_id"] == "bf_true_dmg":
            损 = int(st["base属性"]["血"] * b["数值"])   # 真实伤害：按最大生命%
        elif b["数值类型"] == "percent":
            损 = int(st["cur属性"]["血"] * b["数值"])
        else:
            损 = int(b["数值"])
        st["cur属性"]["血"] -= max(1, 损)
    # ⑤ 消散
    keep = []
    for b in st["active_buffs"]:
        if b.get("常驻"):
            keep.append(b); continue
        b["剩余回合"] -= 1
        if b["剩余回合"] > 0:
            keep.append(b)
    st["active_buffs"] = keep

def try_revive(st, 回合):
    if st["cur属性"]["血"] > 0:
        return False
    idx = -1
    for i, b in enumerate(st["active_buffs"]):
        if b["buff_id"] == "bf_revive":
            idx = i; break
    if idx < 0:
        return False
    b = st["active_buffs"][idx]
    st["cur属性"]["血"] = int(st["base属性"]["血"] * b["数值"])
    st["active_buffs"].pop(idx)
    return True

# ── 场景 ──
print("=== 场景A：真实伤害按最大生命%(无视当前血量) ===")
st = {"base属性": {"血": 1000}, "cur属性": {"血": 200}, "active_buffs": []}
apply_buff(st, "bf_true_dmg")
# 当前血被压到 200，真实伤害应仍按最大 1000 的 5% = 50/回合
tick_buffs(st, 1)
print(f"  初始血200 + 真实伤害(应=50) → 第1回合后血={st['cur属性']['血']} (期望150)")
assert st["cur属性"]["血"] == 150, "true_dmg 应按最大生命%计算"
print("  [OK] true_dmg 按最大生命% 正确")

print("=== 场景B：复活致命伤恢复一次 ===")
st2 = {"base属性": {"血": 1000}, "cur属性": {"血": 1000}, "active_buffs": []}
apply_buff(st2, "bf_revive")
st2["cur属性"]["血"] = 0   # 致命伤
r1 = try_revive(st2, 1)
print(f"  致命伤后复活 → 恢复血={st2['cur属性']['血']} (期望300=1000*0.30), 触发={r1}")
assert r1 and st2["cur属性"]["血"] == 300, "revive 应恢复30%最大生命"
# 再次致命：buff 已消耗，不应再复活
st2["cur属性"]["血"] = 0
r2 = try_revive(st2, 2)
print(f"  二次致命伤 → 触发={r2} (期望False, buff已消耗)")
assert not r2, "revive 仅触发一次"
print("  [OK] revive 致命伤恢复一次且只触发一次")

print("=== 场景C：真实伤害+复活组合（道阶神兵/超阶灵宠典型）===")
st3 = {"base属性": {"血": 1000}, "cur属性": {"血": 1000}, "active_buffs": []}
apply_buff(st3, "bf_true_dmg"); apply_buff(st3, "bf_revive")
for t in range(1, 4):
    tick_buffs(st3, t)
    print(f"  第{t}回合 dot 后血={st3['cur属性']['血']} (期望 1000-50t)")
    if st3["cur属性"]["血"] <= 0:
        revived = try_revive(st3, t)
        print(f"    致命→复活 触发={revived} 血={st3['cur属性']['血']}")
# bf_true_dmg 持续回合=2，第3回合 buff 到期消失 → 血停在 900（验证到期逻辑）
assert st3["cur属性"]["血"] == 900, "组合场景真实伤害累积错误"
print("  [OK] 组合场景真实伤害持续正确(第3回合buff到期)，未误触发复活")

print("\n全部新增 buff 算法验证通过 ✓")

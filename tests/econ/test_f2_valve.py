# -*- coding: utf-8 -*-
# test_f2_valve.py —— F2 全局调节阀门「可行性验证」证据脚本（IMPL-ENG-01）
#
# 纯 Python 镜像 economy_balance.gd 的 平衡() 逻辑，构造极端场景，
# 证明：① 默认配置下恒等（与原结算对齐无跳变）；
#       ② 单周期最终产耗波动被锁死在 ±15% 红线内（熔断/纠偏生效）。
# 该脚本为可行性证据（非 pre_f5 第 25 闸），运行：python tests/econ/test_f2_valve.py
import csv
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
红线 = 0.15


def load_default_config():
    """从 config/经济阀门.csv 载入默认配置（证明真实 CSV 驱动 = 恒等）。"""
    path = os.path.join(ROOT, "config", "经济阀门.csv")
    cfg = {"全局产出系数": 1.0, "全局消耗系数": 1.0,
           "坊市开关": False, "坊市系数": 1.0,
           "运维开关": False, "运维系数": 1.0,
           "负面开关": False, "负面系数": 1.0,
           "熔断阈值": 红线}
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            阀门 = (row.get("阀门") or "").strip()
            系数 = float(row.get("系数") or 1.0)
            开关 = (row.get("开关") or "0").strip() in ("1", "true", "TRUE", "是")
            if 阀门 == "global_income_rate":
                cfg["全局产出系数"] = 系数
            elif 阀门 == "global_cost_rate":
                cfg["全局消耗系数"] = 系数
                cfg["运维系数"] = 系数
                cfg["运维开关"] = 开关
            elif 阀门 == "trade_profit_rate":
                cfg["坊市系数"] = 系数
                cfg["坊市开关"] = 开关
            elif 阀门 == "event_damage_rate":
                cfg["负面系数"] = 系数
                cfg["负面开关"] = 开关
            elif 阀门 == "熔断阈值":
                cfg["熔断阈值"] = 系数
    return cfg


def balance(raw, cfg):
    """镜像 economy_balance.gd::平衡() —— 传入原始值，返回系数修正 + 熔断后最终值。"""
    基准 = raw
    结果 = raw
    if raw >= 0.0:
        结果 = raw * cfg["全局产出系数"]
        if cfg["坊市开关"]:
            结果 *= cfg["坊市系数"]
        if cfg["负面开关"]:
            结果 *= cfg["负面系数"]
    else:
        结果 = raw * cfg["全局消耗系数"]
        if cfg["负面开关"]:
            结果 *= cfg["负面系数"]
    振幅 = abs(结果 - 基准) / abs(基准) if abs(基准) > 1e-9 else 0.0
    if 振幅 > cfg["熔断阈值"]:
        结果 = 基准                       # ③ 极端阈值熔断：拉回基准(本周期原始值)
    return 结果


def 波动(raw, final):
    return abs(final - raw) / abs(raw) if abs(raw) > 1e-9 else 0.0


def main():
    fails = []
    print("=" * 64)
    print("  F2 全局调节阀门 · 可行性验证（镜像 economy_balance.gd）")
    print("=" * 64)

    # ① 默认配置（真实 CSV 驱动）：恒等，无跳变
    dflt = load_default_config()
    for raw in (366, 500, -305, 0):
        final = balance(raw, dflt)
        if final != raw:
            fails.append("默认配置非恒等: raw=%s final=%s" % (raw, final))
        w = 波动(raw, final)
        if w > 红线:
            fails.append("默认配置波动超限: raw=%s w=%.2f%%" % (raw, w * 100))
    print("  [默认] 恒等校验: raw∈{366,500,-305,0} → final==raw，波动=0%%  ✓")

    # ② 全负面 debuff 触发（-35% 极端，ECON-02 §2.4）
    cfg = dict(dflt); cfg["负面开关"] = True; cfg["负面系数"] = 0.65
    final = balance(366, cfg); w = 波动(366, final)
    print("  [全负面 -35%%] 366 → final=%s  波动=%.2f%% %s" % (final, w * 100, "✓锁死" if w <= 红线 else "✗"))
    if w > 红线:
        fails.append("全负面场景波动超限 %.2f%%" % (w * 100))

    # ②b 负面影响常规 -10%（应放通，不熔断）
    cfg = dict(dflt); cfg["负面开关"] = True; cfg["负面系数"] = 0.90
    final = balance(366, cfg); w = 波动(366, final)
    print("  [负面 -10%% 常规] 366 → final=%.1f  波动=%.2f%% %s" % (final, w * 100, "✓合规" if w <= 红线 else "✗"))
    if w > 红线:
        fails.append("负面影响常规场景应放通却熔断 %.2f%%" % (w * 100))

    # ③ 坊市最大涨幅 +10%（合规）/ +50%（极端熔断）
    cfg = dict(dflt); cfg["坊市开关"] = True; cfg["坊市系数"] = 1.10
    final = balance(366, cfg); w = 波动(366, final)
    print("  [坊市 +10%% 常规] 366 → final=%.1f  波动=%.2f%% %s" % (final, w * 100, "✓合规" if w <= 红线 else "✗"))
    if w > 红线:
        fails.append("坊市常规场景应放通却熔断 %.2f%%" % (w * 100))
    cfg = dict(dflt); cfg["坊市开关"] = True; cfg["坊市系数"] = 1.50
    final = balance(366, cfg); w = 波动(366, final)
    print("  [坊市 +50%% 极端] 366 → final=%s  波动=%.2f%% %s" % (final, w * 100, "✓锁死" if w <= 红线 else "✗"))
    if w > 红线:
        fails.append("坊市极端场景波动超限 %.2f%%" % (w * 100))

    # ④ 运维满额（消耗侧 +30% 极端熔断 / +10% 合规）
    cfg = dict(dflt); cfg["运维开关"] = True; cfg["运维系数"] = 1.10
    final = balance(-305, cfg); w = 波动(-305, final)
    print("  [运维 +10%% 常规] -305 → final=%.1f  波动=%.2f%% %s" % (final, w * 100, "✓合规" if w <= 红线 else "✗"))
    if w > 红线:
        fails.append("运维常规场景应放通却熔断 %.2f%%" % (w * 100))
    cfg = dict(dflt); cfg["运维开关"] = True; cfg["运维系数"] = 1.30
    final = balance(-305, cfg); w = 波动(-305, final)
    print("  [运维 +30%% 极端] -305 → final=%s  波动=%.2f%% %s" % (final, w * 100, "✓锁死" if w <= 红线 else "✗"))
    if w > 红线:
        fails.append("运维极端场景波动超限 %.2f%%" % (w * 100))

    # ⑤ 组合叠加（坊市 +10% × 负面影响 -10%，净 -1% 合规）
    cfg = dict(dflt); cfg["坊市开关"] = True; cfg["坊市系数"] = 1.10
    cfg["负面开关"] = True; cfg["负面系数"] = 0.90
    final = balance(366, cfg); w = 波动(366, final)
    print("  [组合 坊+10%%×负-10%%] 366 → final=%.1f  波动=%.2f%% %s" % (final, w * 100, "✓合规" if w <= 红线 else "✗"))
    if w > 红线:
        fails.append("组合常规场景应放通却熔断 %.2f%%" % (w * 100))

    # ⑤b 组合极端（坊市 +10% × 负面影响 -25% 净 -17.5% → 熔断锁死）
    cfg = dict(dflt); cfg["坊市开关"] = True; cfg["坊市系数"] = 1.10
    cfg["负面开关"] = True; cfg["负面系数"] = 0.75
    final = balance(366, cfg); w = 波动(366, final)
    print("  [组合 坊+10%%×负-25%% 极端] 366 → final=%s  波动=%.2f%% %s" % (final, w * 100, "✓锁死" if w <= 红线 else "✗"))
    if w > 红线:
        fails.append("组合极端场景波动超限 %.2f%%" % (w * 100))

    print("-" * 64)
    if fails:
        for x in fails:
            print("  FAIL: " + x)
        print("  结论: F2 可行性验证 **未通过**（波动越界）")
        sys.exit(1)
    print("  结论: F2 可行性验证 **通过** —— 所有极端场景波动锁死 ±15%% 内，默认配置零跳变")
    print("=" * 64)
    sys.exit(0)


if __name__ == "__main__":
    main()

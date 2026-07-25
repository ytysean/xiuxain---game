#!/usr/bin/env python3
# 增益数值红线断言（全游戏统一，所有buff遵守）：
#   单条buff ≤ 5%          （彩蛋/付费/活动/建筑，永久限时统一）
#   永久类全局总增益 ≤ 3%  （与彩蛋永久红线对齐）
#   限时类全局总增益 ≤ 8%  （全局总和上限，非单条）
#   通用增益(战斗)硬帽 30% （软25/硬30，见 disciple.gd _clamp_soft，本断言仅文档化常量）
# 扫描 config/*.csv 中所有 buff_pct 列，越线即 FAIL 阻断提交。
import os, sys, csv

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REDLINE = {
    "single": 5.0,
    "perm_global": 3.0,
    "timed_global": 8.0,
    "combat_hard": 30.0,
}


def scan_csv_buffs():
    bad = []
    perm_sum = 0.0
    timed_sum = 0.0
    cfgdir = os.path.join(ROOT, "config")
    for fn in sorted(os.listdir(cfgdir)):
        if not fn.endswith(".csv"):
            continue
        p = os.path.join(cfgdir, fn)
        with open(p, encoding="utf-8-sig", newline="") as fh:
            rd = csv.DictReader(fh)
            if rd.fieldnames is None or "buff_pct" not in rd.fieldnames:
                continue
            for row in rd:
                bp = (row.get("buff_pct") or "").strip()
                if bp == "":
                    continue
                try:
                    v = float(bp)
                except ValueError:
                    bad.append("%s: buff_pct 非数值 %r" % (fn, bp))
                    continue
                if v > REDLINE["single"] + 1e-9:
                    bad.append("%s: 单条buff %.4f 超5%%红线" % (fn, v))
                dur = (row.get("duration") or "").strip()
                if dur == "永久":
                    perm_sum += v
                elif dur in ("日", "月", "限时", "无"):
                    timed_sum += v
    return bad, perm_sum, timed_sum


def main():
    errors = []
    bad, perm_sum, timed_sum = scan_csv_buffs()
    errors.extend(bad)
    if perm_sum > REDLINE["perm_global"] + 1e-9:
        errors.append("永久类全局总增益 %.4f 超3%%红线" % perm_sum)
    if timed_sum > REDLINE["timed_global"] + 1e-9:
        errors.append("限时类全局总增益 %.4f 超8%%红线" % timed_sum)
    if errors:
        print("BUFF REDLINE ASSERT FAILED:")
        for e in errors:
            print("  - " + e)
        sys.exit(1)
    print("ALL ASSERTIONS PASSED · 单条≤5%% · 永久全局≤3%% · 限时全局≤8%% · 战斗硬30%%")
    sys.exit(0)


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
# 彩蛋数值红线断言（pre_f5 第七道闸门）
#
# 校验 config/easter_egg_config.csv：
#   1) 单彩蛋数值加成 buff_pct ∈ [0, 5]（硬上限 5%）
#   2) 永久(duration=永久)类彩蛋全局总加成 ≤ 3%（软上限，防长期叠加破平衡）
#   临时(日/月/无)类彩蛋按单条 ≤5% 管控，不计入永久全局和（符合「临时轻量buff」设计）。
#
# 退出码：全部通过 -> 0；任一违反 -> 1。
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CSV = os.path.join(ROOT, "config", "easter_egg_config.csv")

单上限 = 5.0
永久总上限 = 3.0


def load_rows():
    rows = []
    with open(CSV, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()
    if not lines:
        return rows
    header = lines[0].split(",")
    for ln in lines[1:]:
        if not ln.strip():
            continue
        parts = ln.split(",")
        rows.append(dict(zip(header, parts)))
    return rows


def main():
    if not os.path.exists(CSV):
        print("FAIL: 配置缺失 %s" % CSV)
        return 1
    rows = load_rows()
    if not rows:
        print("FAIL: 彩蛋配置为空")
        return 1

    fails = []
    perm_sum = 0.0
    for r in rows:
        if r.get("enabled", "true") != "true":
            continue
        egg_id = r.get("egg_id", "?")
        try:
            pct = float(r.get("buff_pct", "0"))
        except ValueError:
            fails.append("%s: buff_pct 非数值 %r" % (egg_id, r.get("buff_pct")))
            continue
        if pct < 0 or pct > 单上限:
            fails.append("%s: 单彩蛋数值加成 %.2f%% 超出红线[0, %.0f%%]" % (egg_id, pct, 单上限))
        if r.get("duration", "") == "永久":
            perm_sum += pct

    if perm_sum > 永久总上限:
        fails.append("永久类彩蛋全局总加成 %.2f%% 超出红线 %.0f%%" % (perm_sum, 永久总上限))

    if fails:
        for x in fails:
            print("FAIL: " + x)
        print("彩蛋数值红线断言：%d 项失败" % len(fails))
        return 1

    print("ALL ASSERTIONS PASSED · 彩蛋 %d 条 · 永久全局加成 %.2f%% (≤%.0f%%)" % (len(rows), perm_sum, 永久总上限))
    return 0


if __name__ == "__main__":
    sys.exit(main())

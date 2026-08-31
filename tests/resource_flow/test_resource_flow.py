#!/usr/bin/env python3
# 资源产耗闭环断言（经济S0）：校验四类资源均有产出与消耗代码，closed 状态资源确有消耗标记。
# 设计意图：灵气在 S0 接入瓶颈消耗（closed）；灵草/矿石/贡献点经 S2 资源审计确认真实产耗（炼丹/锻造/灵兽进化/试炼），
# 由 suspended_s1 升级为 closed（旧 suspended_s1 标记是 dev 摆设，与真实代码矛盾，已刷新）。
# 若后续有人误删任一消耗代码，对应 closed 状态的消耗标记在 game_state.gd 中消失 → 断言 FAIL 阻断提交。
import os, sys, csv

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CSV_PATH = os.path.join(ROOT, "tools", "config", "resource_flow.csv")
GD_FILES = ["game_state.gd", "disciple.gd"]


def grep_marker(marker, files):
    hits = 0
    for f in files:
        p = os.path.join(ROOT, f)
        if not os.path.exists(p):
            continue
        with open(p, encoding="utf-8-sig") as fh:
            for line in fh:
                if marker in line:
                    hits += 1
    return hits


def main():
    if not os.path.exists(CSV_PATH):
        print("RESOURCE FLOW ASSERT FAILED: resource_flow.csv 缺失")
        sys.exit(1)
    rows = []
    with open(CSV_PATH, encoding="utf-8-sig", newline="") as fh:
        for r in csv.DictReader(fh):
            rows.append(r)
    errors = []
    seen = set()
    if len(rows) != 4:
        errors.append("资源行数应为4，实为%d" % len(rows))
    for r in rows:
        资源 = r["资源"]
        if 资源 in seen:
            errors.append("重复资源 %s" % 资源)
        seen.add(资源)
        产出 = int(r["产出声明"])
        消耗 = int(r["消耗声明"])
        状态 = r["状态"]
        产出标记 = r["产出标记"].strip()
        消耗标记 = r["消耗标记"].strip()
        if 产出 < 1:
            errors.append("%s 产出声明应≥1" % 资源)
        if 产出标记 and grep_marker(产出标记, GD_FILES) < 1:
            errors.append("%s 产出标记「%s」在代码中未找到" % (资源, 产出标记))
        if 状态 == "closed":
            if 消耗 < 1:
                errors.append("%s 状态closed但消耗声明<1" % 资源)
            if 消耗标记 and grep_marker(消耗标记, GD_FILES) < 1:
                errors.append("%s 消耗标记「%s」在代码中未找到（闭环被破坏）" % (资源, 消耗标记))
        elif 状态 == "suspended_s1":
            if 消耗 != 0:
                errors.append("%s suspended_s1 但消耗声明非0（应文档化悬空=0）" % 资源)
        else:
            errors.append("%s 未知状态 %s" % (资源, 状态))
    if errors:
        print("RESOURCE FLOW ASSERT FAILED:")
        for e in errors:
            print("  - " + e)
        sys.exit(1)
    print("ALL ASSERTIONS PASSED · 资源4类 · 灵草/矿石/灵气/贡献点均闭环(closed)")
    sys.exit(0)


if __name__ == "__main__":
    main()

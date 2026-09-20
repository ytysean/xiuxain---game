#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# PH7-QA-15 · C：① page_placeholder 归零路径（前置核证 + 删除清单）
#                  ② X06 离线管理「修后回归判据」（供修完后一键复算）
# 【写而不跑】—— 待 team-lead 派工/关闸信号后执行。只读；不启动 Godot。
#
# 运行：python production/qa/qa15_placeholder_x06.py [--out <utf8.txt>]

import os
import re
import sys

ROOT = r"E:\Xiuxian\taixuanzongmenlu"
GUI = "ui/game_ui.gd"
PLACEHOLDER = "ui/page_placeholder.gd"
PLACEHOLDER_TSCN = "ui/page_placeholder.tscn"
OFFLINE_OPENER = "_open_offline_manager_page"
HARNESS_REFS = [
    ("tests/ui_full_accept.gd", 139),
    ("tests/_t_btnsweep.gd", 116),
    ("tests/_t_deadkey.gd", 117),
]


def all_gd():
    out = []
    for dp, dn, fn in os.walk(ROOT):
        dn[:] = [d for d in dn if d not in {".git", ".godot", ".workbuddy",
                                            ".scratch_backup", "addons"}]
        for x in fn:
            if x.endswith(".gd"):
                out.append(os.path.relpath(os.path.join(dp, x), ROOT).replace("\\", "/"))
    return out


def rd(rel):
    with open(os.path.join(ROOT, rel), "r", encoding="utf-8-sig") as f:
        return f.read()


def main():
    R = []

    def chk(cid, ok, detail):
        R.append((cid, ok, detail))

    # ════ ① page_placeholder 归零路径 ════
    # C1: PagePlaceholderScene 全仓 live .gd 出现点
    pp_hits = []
    pp_ref_files = []
    for rel in all_gd():
        if rel.startswith("tests/"):
            src = rd(rel)
            for i, l in enumerate(src.split("\n"), 1):
                if "PagePlaceholderScene" in l:
                    pp_hits.append("%s:%d" % (rel, i))
        else:
            src = rd(rel)
            for i, l in enumerate(src.split("\n"), 1):
                if "PagePlaceholderScene" in l:
                    pp_hits.append("%s:%d" % (rel, i))
    chk("C1 PagePlaceholderScene 出现点 == 1 且仅在 game_ui.gd:24",
        pp_hits == ["ui/game_ui.gd:24"], "实测: %s" % pp_hits)

    # C2: 字符串 "page_placeholder" 的 live 引用（.gd/.tscn 自身除外）
    refs = []
    for rel in all_gd():
        if rel == PLACEHOLDER:
            continue
        for i, l in enumerate(rd(rel).split("\n"), 1):
            if "page_placeholder" in l:
                refs.append("%s:%d" % (rel, i))
    chk("C2 page_placeholder 外部引用 == 1（game_ui.gd:24 preload）",
        refs == ["ui/game_ui.gd:24"], "实测: %s" % refs)

    # C3: 无兜底消费 —— ENTRY_SUB_PAGES.get 的默认值为 null（非 PagePlaceholderScene）
    gui = rd(GUI)
    m = re.findall(r"ENTRY_SUB_PAGES\.get\([^)]*\)", gui)
    default_null = all(("null" in x) for x in m) and len(m) > 0
    chk("C3 ENTRY_SUB_PAGES.get(...) 默认值均为 null（无占位兜底）",
        default_null, "命中: %s" % m)

    # C4: _on_首页入口 尾部兜底为 _toast（非实例化占位场景）
    tail_ok = '_toast("【%s】系统即将开放" % entry_id)' in gui
    chk("C4 _on_首页入口 尾部兜底 = _toast 文案（非 PagePlaceholderScene）",
        tail_ok, "含 `_toast(\"【%s】系统即将开放\" % entry_id)` = %s" % tail_ok)

    # ════ ② X06 修后回归判据 ════
    # X1: _open_offline_manager_page 的「产品 code 调用点」（排除 def 行、自日志行、tests/）
    def_line_re = re.compile(r"\s*func\s+" + re.escape(OFFLINE_OPENER) + r"\s*\(")
    selflog_re = re.compile(re.escape(OFFLINE_OPENER) + r"[^\"']*被调用")
    prod_callers = []
    for rel in all_gd():
        if rel.startswith("tests/"):
            continue
        for i, l in enumerate(rd(rel).split("\n"), 1):
            if OFFLINE_OPENER not in l:
                continue
            if def_line_re.match(l):
                continue
            if selflog_re.search(l) and "print(" in l:  # 自日志字符串
                continue
            prod_callers.append("%s:%d" % (rel, i))
    chk("X1 %s 产品 code 调用点 >= 1（X06 修完后应成立）" % OFFLINE_OPENER,
        len(prod_callers) >= 1,
        "当前 %d 个: %s" % (len(prod_callers), prod_callers))

    # X2: 3 处 harness 字符串引用保持不变
    harness_ok = True
    detail = []
    for rel, ln in HARNESS_REFS:
        ls = rd(rel).split("\n")
        hit = (1 <= ln <= len(ls)) and (OFFLINE_OPENER in ls[ln - 1])
        harness_ok = harness_ok and hit
        detail.append("%s:%d=%s" % (rel, ln, hit))
    chk("X2 3 处 harness 直达引用保持不变", harness_ok, " ".join(detail))

    # X3: 入口接线落点核证（game_ui.gd:1316 现为占位 toast；修后应为真调用）
    ls = gui.split("\n")
    seg = "\n".join(ls[1312:1320])
    wired = (OFFLINE_OPENER + "()") in seg
    chk("X3 game_ui.gd:~1316 闭关设置分发已改真调用（修后应为 True）",
        wired, "该段落含 `%s()` = %s" % (OFFLINE_OPENER, wired))

    # ── 输出 ──
    print("=" * 72)
    print("PH7-QA-15 · C：page_placeholder 归零路径 + X06 修后回归判据")
    print("=" * 72)
    print("【① page_placeholder 归零路径】")
    for cid, ok, d in R[:4]:
        print("  [%s] %-52s %s" % ("PASS" if ok else "INFO", cid, d))
    print()
    print("  ── 删除清单（本阶段不授权执行；仅供 lead 终裁）──")
    print("    del %s" % PLACEHOLDER)
    print("    del %s" % PLACEHOLDER_TSCN)
    print("    del line: %s:24  const PagePlaceholderScene = preload(\"res://ui/page_placeholder.tscn\")" % GUI)
    print("    → 无 ENTRY_SUB_PAGES 条目指向它 ⇒ 无需改映射表")
    print("    → 连带销项：术语表 P3「系统即将开放，敬请期待」(page_placeholder.gd:57)")
    print()
    print("【② X06 修后回归判据】")
    for cid, ok, d in R[4:]:
        print("  [%s] %-52s %s" % ("PASS" if ok else "PENDING", cid, d))
    print("=" * 72)
    hard_fail = [c for c in R[:4] if not c[1]]
    print(">>> ① 前置核证: %s" % ("PASS（可安全删除）" if not hard_fail else "FAIL（有前置不满足）"))
    print(">>> ② X06 回归: %s（X1/X3 在修复落盘前预期 PENDING）"
          % ("PASS" if all(c[1] for c in R[4:]) else "PENDING（等 X06 修复落盘）"))
    return 0 if not hard_fail else 1


if __name__ == "__main__":
    if "--out" in sys.argv:
        import io
        buf = io.StringIO()
        old = sys.stdout
        sys.stdout = buf
        try:
            rc = main()
        finally:
            sys.stdout = old
        out = sys.argv[sys.argv.index("--out") + 1]
        open(out, "w", encoding="utf-8").write(buf.getvalue())
        print("written:", out, "rc=", rc)
        sys.exit(rc)
    else:
        sys.exit(main())

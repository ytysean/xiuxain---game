#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# PH7-QA-15 · A：门0 扫描范围【独立复算】（只读，不改任何 .gd/.csv）
#
# 目的：独立于工程线的口径，复算「修前 473 → 修后 ?」，并回答：
#   (a) 修后 .gd 计入数是否回落 268 量级？实际是多少？
#   (b) .scratch_backup 下 212 个 scratch .gd 是否真被排除？
#   (c) 是否产生「连带翻转」—— 其它门/其它统计口径被一起改变？
#
# 方法：① 自建 os.walk + 自写 before/after 判据（不复用门0函数）；② 再用 importlib
#      加载门0真实 is_skipped() 交叉校验（三方一致才算数）；③ 逐顶层目录出直方图。

import os
import sys
import importlib.util

ROOT = r"E:\Xiuxian\taixuanzongmenlu"
GATE0 = os.path.join(ROOT, ".workbuddy", "_norm_all.py")

SKIP_DIRS = {
    ".git", ".godot", "Godot", "addons", "Lib", "archive_legacy",
    ".artifacts", ".cache", "__pycache__", ".venv_genai",
}
SKIP_PATH_PARTS = {".workbuddy", ".scratch_backup"}


# ---- ① 自建遍历（只剪 SKIP_DIRS，与门0 os.walk 剪枝一致）----
def self_walk_gd():
    out = []
    walk_dirs = []
    for dp, dn, fn in os.walk(ROOT):
        dn[:] = [d for d in dn if d not in SKIP_DIRS]
        for f in fn:
            if f.endswith(".gd"):
                out.append(os.path.relpath(os.path.join(dp, f), ROOT))
        # 记录被剪掉的顶层目录（供直方图）
    for d in os.listdir(ROOT):
        if os.path.isdir(os.path.join(ROOT, d)) and d in SKIP_DIRS:
            walk_dirs.append(d)
    return out, walk_dirs


# ---- ② 自写 before / after 判据（不复用门0）----
def self_skipped_after(rel):
    parts = rel.replace("\\", "/").split("/")
    for p in parts:
        if p in SKIP_DIRS:
            return True
    for p in parts:
        if p in SKIP_PATH_PARTS:
            return True
    return False


def self_skipped_before(rel):
    # 原实现：只手写判 parts[0] == ".workbuddy"（SKIP_PATH_PARTS 定义了却未被引用）
    parts = rel.replace("\\", "/").split("/")
    for p in parts:
        if p in SKIP_DIRS:
            return True
    if parts and parts[0] == ".workbuddy":
        return True
    return False


# ---- ③ 加载门0真实 is_skipped 交叉校验 ----
def load_gate0_is_skipped():
    spec = importlib.util.spec_from_file_location("_norm_all_qa15", GATE0)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # 模块级仅定义，无副作用（main 在 __main__ 守卫内）
    return mod.is_skipped, mod.SKIP_PATH_PARTS


def hist(paths, depth=2):
    from collections import Counter
    c = Counter()
    for rel in paths:
        parts = rel.replace("\\", "/").split("/")
        key = "/".join(parts[:depth]) if len(parts) > depth else "/".join(parts[:-1]) or "(root)"
        c[key] += 1
    return c


def main():
    all_gd, pruned_top = self_walk_gd()

    before = [r for r in all_gd if not self_skipped_before(r)]
    after = [r for r in all_gd if not self_skipped_after(r)]

    # 门0真实判据交叉校验
    real_is_skipped, real_parts = load_gate0_is_skipped()
    after_real = [r for r in all_gd if not real_is_skipped(r)]

    # .scratch_backup 命中
    scratch = [r for r in all_gd if ".scratch_backup" in r.replace("\\", "/").split("/")]
    # addons（被 SKIP_DIRS 剪枝，进不了 all_gd）单独数
    addons_dir = os.path.join(ROOT, "addons")
    addons_gd = 0
    if os.path.isdir(addons_dir):
        for dp, dn, fn in os.walk(addons_dir):
            addons_gd += sum(1 for f in fn if f.endswith(".gd"))

    print("=" * 70)
    print("QA-15 A · 门0 扫描范围独立复算")
    print("=" * 70)
    print("ROOT                 : %s" % ROOT)
    print("os.walk 顶层剪掉目录 : %s" % ", ".join(sorted(pruned_top)))
    print()
    print("自建遍历（已剪 SKIP_DIRS）全部 .gd : %d" % len(all_gd))
    print("  自写 before 判据  计入 .gd      : %d" % len(before))
    print("  自写 after  判据  计入 .gd      : %d" % len(after))
    print("  门0真实 is_skipped 计入 .gd     : %d" % len(after_real))
    print()
    print("三方一致性 : %s" % ("✔ PASS（自写=门0真实）" if after == after_real else "✘ FAIL（不一致）"))
    print("before vs after 差 : %d（应 = .scratch_backup 命中数）" % (len(before) - len(after)))
    print()
    print("被 .skipped 的 .scratch_backup .gd 命中数 : %d" % len(scratch))
    print("addons/ 下 .gd（被 SKIP_DIRS 剪枝，两门都不计）: %d" % addons_gd)
    print("SKIP_PATH_PARTS（门0真实）: %s" % sorted(real_parts))
    print()
    print("--- after 计入 .gd 的顶层分布（Top 12）---")
    for k, v in hist(after).most_common(12):
        print("  %-30s %d" % (k, v))
    print()
    print("--- before 计入 .gd 的顶层分布（Top 12）---")
    for k, v in hist(before).most_common(12):
        print("  %-30s %d" % (k, v))
    print()
    # 连带翻转检查点
    print("--- 连带翻转检查 ---")
    flip = sorted(set(before) - set(after))
    print("  被新排除的文件总数 : %d" % len(flip))
    non_scratch = [r for r in flip if ".scratch_backup" not in r.replace("\\", "/").split("/")]
    print("  其中【非 .scratch_backup】者 : %d （>0 则为真连带翻转，须查）" % len(non_scratch))
    for r in non_scratch[:40]:
        print("      " + r)
    # 嵌套 SKIP_PATH_PARTS 命中（除顶层）
    nested_workbuddy = [r for r in all_gd if "workbuddy" in r.replace("\\", "/").lower()
                        and not r.replace("\\", "/").startswith(".workbuddy/")]
    print("  嵌套 .workbuddy 命中（非顶层） : %d" % len(nested_workbuddy))
    for r in nested_workbuddy[:40]:
        print("      " + r)
    print("=" * 70)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        import io
        buf = io.StringIO()
        old = sys.stdout
        sys.stdout = buf
        try:
            main()
        finally:
            sys.stdout = old
        with open(sys.argv[1], "w", encoding="utf-8") as fh:
            fh.write(buf.getvalue())
        print("written:", sys.argv[1])
    else:
        main()

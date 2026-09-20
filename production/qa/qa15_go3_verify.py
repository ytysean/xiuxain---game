#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# PH7-QA-15 · B：GO3 11 站独立复验脚本（【写而不跑】——待 team-lead「关闸」信号后执行）
#
# 纪律：本脚本只读产品文件；不启动 Godot；不写任何 .gd/.csv。
# 运行：python production/qa/qa15_go3_verify.py [--out <utf8.txt>]
#
# 覆盖：
#   ① 11 站逐站「原串 0 残留 / 新串在」双向断言
#   ② 字节账断言：main.gd Δ+0 / ui/page_disciple.gd Δ+0 / game_state.gd Δ+12；
#      三文件 CR=0 / BOM=False / LF 不变；并与 GO2 冻结基线交叉（main/game_state）
#   ③ 反向断言（4 组）：
#        R1 main.gd:832 同行 `招.name = "Button_开启接引大典"`（＋全 main.gd 该串计数=4）
#        R2 game_state.gd:15738/:15741/:15743/:15745 四行逐字未变
#        R3 ui/page_storage.gd 整文 md5 未变（QA-13 反向断言继承）
#        R4  跨批污染守卫 = GO2 落盘 9 文件（main/game_state 取 **GO3-after**）＋ GO3 落盘 page_disciple
#        R4′ ui/page_explore.gd「GO7∪GO8 落盘前冻结基线」
#            ★ 口径 = 「零 UNEXPECTED」：**变则须在 GO7/GO8 expected_changes.tsv 内有据**，
#              有据 ⇒ 合法放行；无据 ⇒ 越权 ⇒ FAIL。**不要求「必须不变」。**
#              期望表路径可用 `--expected <tsv>` 覆盖（默认 .workbuddy/_ph7go7/GO7_expected_changes.tsv）。
#
# 数据来源（硬口径）：
#   - 改前副本（GO3-A apply 时快照）: .workbuddy/_ph7go3/snapshot_before/{main,game_state}.gd, ui/page_disciple.gd
#   - GO2 冻结基线: .workbuddy/_baseline_current.json（tag=GO2后）
#   - 期望改动表: .workbuddy/_ph7go3/GO3_expected_changes.tsv

import os
import sys
import hashlib
import json

ROOT = r"E:\Xiuxian\taixuanzongmenlu"
SNAP = os.path.join(ROOT, ".workbuddy", "_ph7go3", "snapshot_before")
BASE = os.path.join(ROOT, ".workbuddy", "_baseline_current.json")

# ── 11 站（页id / 文件 / 行 / 原串 / 新串）────────────────────────────
# A1 · F1 族：开启测灵大典 → 举办测灵大典（7 站）
F1_STATIONS = [
    ("main.gd",                 832,  "开启测灵大典", "举办测灵大典"),
    ("main.gd",                 1113, "开启测灵大典", "举办测灵大典"),
    ("main.gd",                 2220, "开启测灵大典", "举办测灵大典"),
    ("main.gd",                 2938, "开启测灵大典", "举办测灵大典"),
    ("main.gd",                 3069, "开启测灵大典", "举办测灵大典"),
    ("main.gd",                 3126, "开启测灵大典", "举办测灵大典"),
    ("ui/page_disciple.gd",     551,  "开启测灵大典", "举办测灵大典"),
]
# A2 · B-20：尾截断补 1 字（4 站）
B20_STATIONS = [
    ("game_state.gd", 15739, "遭遇迷障，不得不", "遭遇迷障，寸步难行"),
    ("game_state.gd", 15740, "探寻无果，徒劳往", "探寻无果，徒劳往返"),
    ("game_state.gd", 15742, "妖兽出没，被迫绕", "妖兽出没，被迫绕行"),
    ("game_state.gd", 15744, "路径生疏，迷失林", "路径生疏，迷失林中"),
]
# 反向断言：game_state.gd 保留行（逐字未变）
B20_KEEP = {
    15738: "寻宝未获，空手而归",
    15741: "灵气稀薄，无功而返",
    15743: "天候骤变，折返避祸",
    15745: "所获之物品相不佳，弃之而归",
}
# 反向断言：main.gd:832 同行禁动标识符
R1_LINE = 832
R1_MUST_CONTAIN = '招.name = "Button_开启接引大典"'
R1_FILE_COUNT = 4  # 全 main.gd `Button_开启接引大典` 计数
# 反向断言：page_storage.gd 整文 md5（GO2 基线）
R3_FILE = "ui/page_storage.gd"
R3_MD5 = "e37e23aa36a422307747632d44e8f441"

# ── R4 / R4′ · 跨批污染守卫（口径 = 「零 UNEXPECTED」，**非**「零变化」）────
# team-lead PH7-QA-15 裁定 2 · 收窄版：
#   R4  真实集合 = **GO2 落盘那 9 个文件**（非 2 个）。
#   R4′          = `ui/page_explore.gd`「GO7∪GO8 落盘前冻结基线」（**与 GO2 无关**）。
# ★ 断言口径（关键·否则必误报）：**不要求「必须不变」**，要求
#     「若变，则必须在 GO7/GO8 的 expected_changes.tsv 内有据」：
#        有据 ⇒ 合法变更，放行；无据 ⇒ 越权 ⇒ FAIL（停批报警）。
#   理由：GO7(B7) 本就要动 page_sect_manager/page_building；GO8 会动 game_ui.gd
#         ⇒ 写「必须等于」= 必然假 FAIL。
# ★★ 排程坑：GO2 与 GO3 都改 **game_state.gd / main.gd** ⇒ GO3 后值 ≠ GO2 后值。
#     下表这两行取 **GO3-after**，否则关闸后必假 FAIL。
R4_BASELINE = {
    # —— GO2 落盘 9 件 ——
    "ui/page_building.gd":               "d20ac4966f60e7484bbc64cb47dfa90b",  # GO2-after
    "ui/page_global_auction.gd":         "6bba46ac42d6ed9463268f7faecafed0",  # GO2-after
    "ui/page_sect_manager.gd":           "5906f36aa4041c71e1fd6b5c4f51496e",  # GO2-after
    "ui/page_shop.gd":                   "76c174071ea385bed014cc44531313df",  # GO2-after
    "dynasty_system.gd":                 "4547fcb7f6eacf99992db30263310b47",  # GO2-after（★路径=仓库根，非 ui/）
    "config/dynasty_counter_config.csv": "7d89fd12f15bd307f6821faaf303b277",  # GO2-after
    "config/auction_ai_config.csv":      "5fb64c54a70bd5a05e419a1ca620eeeb",  # GO2-after
    "main.gd":                           "dd440880fb00660f7fee32a45c5e5632",  # ★GO3-after（非 GO2 的 9c9d03bf…）
    "game_state.gd":                     "ffd2b68acd15b4d5e64e069d89201400",  # ★GO3-after（非 GO2 的 6458745c…）
    # —— GO3 落盘件（供 GO7/GO8 守卫；team-lead 冻结表含此件）——
    "ui/page_disciple.gd":               "3224c9f0207c41440447d8a5b9a27e27",  # GO3-after
}
R4_PRIME = {
    "ui/page_explore.gd":                "1d6f0cd7f6a49e61e58195fcd46aafed",  # R4′·GO7∪GO8 前冻结（71704 B）
}
# GO7/GO8 期望改动表（存在则载入，用于「若变有据」放行）
EXPECTED_TSV = os.path.join(ROOT, ".workbuddy", "_ph7go7", "GO7_expected_changes.tsv")

# 字节账预期（Δbytes 相对 snapshot_before）
BYTELEDGER = {
    "main.gd":              {"d_size": 0,  "d_lf": 0},
    "ui/page_disciple.gd":  {"d_size": 0,  "d_lf": 0},
    "game_state.gd":        {"d_size": 12, "d_lf": 0},
}

BOM = b"\xef\xbb\xbf"


def read_raw(rel):
    with open(os.path.join(ROOT, rel), "rb") as f:
        return f.read()


def read_snap(rel):
    with open(os.path.join(SNAP, rel), "rb") as f:
        return f.read()


def md5(b):
    return hashlib.md5(b).hexdigest()


def lines_of(raw):
    # 与门0 口径一致：按 \n 切（尾 LF ⇒ 多 1 空元素）
    return raw.split(b"\n")


def decode_lines(raw):
    return [l.decode("utf-8-sig", "replace") for l in lines_of(raw)]


def load_expected_files():
    """读 GO7/GO8 期望改动表的『文件』列（第 2 列 TAB 分隔），返回 set。
    表不存在 ⇒ 空集（= R4/R4′ 退化为「必须 == 基线」的严格模式）。"""
    if not os.path.exists(EXPECTED_TSV):
        return set()
    files = set()
    with open(EXPECTED_TSV, encoding="utf-8-sig") as f:
        for line in f:
            c = line.rstrip("\n").split("\t")
            if len(c) >= 2 and c[1].strip():
                files.add(c[1].strip().replace("\\", "/"))
    return files


def count_sub(rel, sub):
    raw = read_raw(rel)
    return raw.count(sub.encode("utf-8"))


def main():
    results = []

    def chk(cid, ok, detail):
        results.append((cid, ok, detail))

    # ── ① 11 站逐站双向断言 ────────────────────────────────────────
    for f, ln, old, new in F1_STATIONS + B20_STATIONS:
        raw = read_raw(f)
        txt = raw.decode("utf-8-sig", "replace")
        ls = txt.split("\n")
        line_ok = (1 <= ln <= len(ls)) and (new in ls[ln - 1])
        old_total = txt.count(old)
        chk("①-%s:%d" % (f, ln),
            (old_total == 0) and line_ok,
            "原串全文件残留=%d(期望0) 行%d含新串=%s" % (old_total, ln, line_ok))

    # ① 全局：全仓 .gd 中「开启测灵大典」应为 0（保留「开启接引大典」不受影响）
    f1_old_global = 0
    for dp, dn, fn in os.walk(ROOT):
        dn[:] = [d for d in dn if d not in {".git", ".godot", ".workbuddy",
                                            ".scratch_backup", "addons"}]
        for x in fn:
            if x.endswith(".gd"):
                b = open(os.path.join(dp, x), "rb").read()
                if "开启测灵大典".encode("utf-8") in b:
                    f1_old_global += 1
    chk("①-global 开启测灵大典 文件数", f1_old_global == 0,
        "残留文件数=%d(期望0)" % f1_old_global)

    # ── ② 字节账 ───────────────────────────────────────────────────
    for rel, exp in BYTELEDGER.items():
        cur = read_raw(rel)
        pre = read_snap(rel)
        cur_lf = cur.count(b"\n")
        pre_lf = pre.count(b"\n")
        d_size = len(cur) - len(pre)
        d_lf = cur_lf - pre_lf
        cr_ok = (b"\r" not in cur)
        bom_ok = (cur[:3] != BOM)
        ok = (d_size == exp["d_size"] and d_lf == exp["d_lf"] and cr_ok and bom_ok)
        chk("②-%s" % rel, ok,
            "Δsize=%+d(期望%+d) ΔLF=%+d(期望%+d) CR=%s BOM=%s LF=%d md5=%s"
            % (d_size, exp["d_size"], d_lf, exp["d_lf"],
               (b"\x0d" in cur), (cur[:3] == BOM), cur_lf, md5(cur)))

    # ②b GO2 冻结基线交叉（main / game_state / combat）
    if os.path.exists(BASE):
        led = json.load(open(BASE, encoding="utf-8"))
        for key in ("main.gd", "game_state.gd"):
            base = led["files"].get(key)
            cur = read_raw(key)
            if base:
                chk("②-base %s LF不变" % key, cur.count(b"\n") == base["lf"],
                    "LF %d vs 基线 %d" % (cur.count(b"\n"), base["lf"]))

    # ── ③ 反向断言 ─────────────────────────────────────────────────
    # R1
    ml = read_raw("main.gd").decode("utf-8-sig", "replace").split("\n")
    r1_line_ok = R1_MUST_CONTAIN in ml[R1_LINE - 1]
    r1_cnt = read_raw("main.gd").count("Button_开启接引大典".encode("utf-8"))
    chk("③-R1 main.gd:832 Button_开启接引大典 未动",
        r1_line_ok and r1_cnt == R1_FILE_COUNT,
        "行含锚=%s 全文件计数=%d(期望%d)" % (r1_line_ok, r1_cnt, R1_FILE_COUNT))

    # R2
    ok_r2 = True
    detail_r2 = []
    gl = read_raw("game_state.gd").decode("utf-8-sig", "replace").split("\n")
    for ln, s in B20_KEEP.items():
        hit = s in gl[ln - 1]
        ok_r2 = ok_r2 and hit
        detail_r2.append(":%d=%s" % (ln, hit))
    chk("③-R2 game_state.gd 保留 4 行逐字未变", ok_r2, " ".join(detail_r2))

    # R3
    r3_md5 = md5(read_raw(R3_FILE))
    chk("③-R3 %s md5 未变" % R3_FILE, r3_md5 == R3_MD5,
        "%s vs 期望 %s" % (r3_md5, R3_MD5))

    # R4 / R4′ · 跨批污染守卫（口径 = 零 UNEXPECTED：变则须有据，无据即越权）
    expected_files = load_expected_files()
    r4_files = dict(R4_BASELINE)
    r4_files.update(R4_PRIME)
    ok_r4, d_r4 = True, []
    for rel, base in r4_files.items():
        got = md5(read_raw(rel))
        if got == base:
            verdict = "="
        elif rel.replace("\\", "/") in expected_files:
            verdict = "合法(期望表有据)"
        else:
            verdict = "★越权(!=%s)" % got[:12]
            ok_r4 = False
        d_r4.append("%s:%s" % (rel.split("/")[-1], verdict))
    chk("③-R4/R4′ 跨批污染守卫 %d 件·零UNEXPECTED" % len(r4_files), ok_r4,
        (" ".join(d_r4) +
         ("  [期望表: %s]" % (sorted(expected_files) if expected_files else "无(严格=基线)"))))

    # ── 汇总 ───────────────────────────────────────────────────────
    print("=" * 72)
    print("PH7-QA-15 · B：GO3 11 站独立复验")
    print("=" * 72)
    npass = sum(1 for _, ok, _ in results if ok)
    for cid, ok, detail in results:
        print("  [%s] %-46s %s" % ("PASS" if ok else "FAIL", cid, detail))
    print("-" * 72)
    print("总计 %d 项：PASS %d / FAIL %d" % (len(results), npass, len(results) - npass))
    print(">>> 判定: %s" % ("全部通过 [PASS]" if npass == len(results) else "存在失败 [FAIL]"))
    print("     [12] 战斗红线请单独跑：python tests/combat/test_combat.py （期望 93/0，md5=109f2296…）")
    print("     [门0–6] 全门复跑请走 gate_all.py（本脚本不代替门禁）")
    return 0 if npass == len(results) else 1


if __name__ == "__main__":
    # 可选：--expected <tsv> 覆盖 GO7/GO8 期望改动表路径（用于「若变有据」放行）
    if "--expected" in sys.argv:
        EXPECTED_TSV = sys.argv[sys.argv.index("--expected") + 1]
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

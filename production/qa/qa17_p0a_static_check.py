# -*- coding: utf-8 -*-
"""PH7-QA-17 · P0-A 静态专项判据（QA 独立 · 只读 · 不启 Godot）
================================================================================
覆盖 team-lead 指定 §D 的纯静态项 ①–⑤（不含棘轮/门/战斗——那些归工程线且调 Godot）：
  ① 26 行逐字节核        —— 实参 == 目标实参（hex ＋ 字面）
  ② 语义出口值断言        —— 5 个 getter 指向常量且常量 hex == 期望
  ③ 残留漂移             —— 实参 ≠ 同行注释 hex（分「陈旧注释 3」＋「移出项 5」两类）
  ④ 枢纽常量出口数        —— MAT_EDGE_LIGHT → 4；MAT_EDGE_DARK → 3
  ⑤ 26 行「实参==注释」计数
口径：与 spec §5.1 及 `_p0a_tool.py cmd_verify` 一致（实参 hex vs 同行注释 hex）。
输出：production/qa/_qa17_out/qa17_p0a_static.txt（UTF-8 无 BOM + LF）
"""
import os, io, re, sys, hashlib

ROOT = r"E:\Xiuxian\taixuanzongmenlu"
TARGET = os.path.join(ROOT, "ui_theme.gd")
SNAP = os.path.join(ROOT, ".workbuddy", "_ph7visual", "snapshot_before", "ui_theme.gd")
OUTDIR = os.path.join(ROOT, "production", "qa", "_qa17_out")
OUT = os.path.join(OUTDIR, "qa17_p0a_static.txt")

# spec v3.1 目标（行号1based: 常量名, 目标实参字面, 目标 hex）
EDITS = [
    (1470, "MAT_BASE_TOP", "Color8(34, 51, 58)", "#22333A"),
    (1471, "MAT_BASE_BOTTOM", "Color8(22, 32, 36)", "#162024"),
    (1472, "MAT_SURFACE", "Color8(27, 39, 43)", "#1B272B"),
    (1473, "MAT_ROW_TOP", "Color8(39, 57, 66)", "#273942"),
    (1474, "MAT_ROW_BOTTOM", "Color8(28, 38, 44)", "#1C262C"),
    (1475, "MAT_CARD_TOP", "Color8(43, 64, 73)", "#2B4049"),
    (1476, "MAT_CARD_BOTTOM", "Color8(31, 43, 49)", "#1F2B31"),
    (1477, "MAT_EDGE_DARK", "Color8(110, 87, 38)", "#6E5726"),
    (1478, "MAT_EDGE_LIGHT", "Color8(232, 206, 138)", "#E8CE8A"),
    (1479, "MAT_GOLD_TOP", "Color8(200, 168, 106)", "#C8A86A"),
    (1480, "MAT_GOLD_BOTTOM", "Color8(140, 110, 46)", "#8C6E2E"),
    (1481, "MAT_GOLD_HI", "Color8(240, 220, 160)", "#F0DCA0"),
    (8, "COLOR_PANEL_BG", "Color(0.141, 0.204, 0.224)", "#243439"),
    (11, "COLOR_BORDER_GOLD", "Color8(200, 168, 106)", "#C8A86A"),
    (16, "COLOR_TEXT_BODY_GOLD", "Color8(212, 184, 106)", "#D4B86A"),
    (20, "COLOR_BTN_PRIMARY", "Color(0.173, 0.373, 0.322)", "#2C5F52"),
    (26, "COLOR_TEXT_TITLE1", "Color8(230, 199, 120)", "#E6C778"),
    (27, "COLOR_TEXT_TITLE2", "Color8(240, 230, 210)", "#F0E6D2"),
    (28, "COLOR_TEXT_BODY_DIM", "Color8(200, 184, 150)", "#C8B896"),
    (29, "COLOR_TEXT_DISABLED", "Color8(85, 85, 79)", "#55554F"),
    (33, "COLOR_HOME_BAR_BG", "Color8(30, 43, 40)", "#1E2B28"),
    (34, "COLOR_HOME_DIVIDER", "Color8(200, 168, 106)", "#C8A86A"),
    (43, "C01_TEXT_PRIMARY", "Color8(242, 245, 243)", "#F2F5F3"),
    (44, "C01_TEXT_GOLD", "Color8(214, 177, 106)", "#D6B16A"),
    (45, "C01_TEXT_SECONDARY", "Color8(207, 198, 178)", "#CFC6B2"),
    (46, "C01_TEXT_TERTIARY", "Color8(159, 179, 176)", "#9FB3B0"),
]
# 期望的陈旧注释行（spec §1.4 声称"目标=注释"对这 3 行不成立）
EXPECT_STALE_COMMENT = {8, 11, 1479}
MOVED_OUT = [17, 24, 55, 56, 57]

GETTERS = [
    (1505, "获取页面底色", "MAT_BASE_TOP", "#22333A"),
    (1507, "获取面板底色", "MAT_BASE_BOTTOM", "#162024"),
    (1517, "获取金文字色", "MAT_EDGE_LIGHT", "#E8CE8A"),
    (1519, "获取暗金边色", "MAT_EDGE_DARK", "#6E5726"),
    (1521, "获取亮金边色", "MAT_EDGE_LIGHT", "#E8CE8A"),
]
HUB = [("MAT_EDGE_LIGHT", 4), ("MAT_EDGE_DARK", 3)]


def arg_hex(arg):
    m = re.match(r"Color8\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)", arg)
    if m:
        return "#%02X%02X%02X" % (int(m.group(1)), int(m.group(2)), int(m.group(3)))
    m = re.match(r"Color\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)", arg)
    if m:
        return "#%02X%02X%02X" % (round(float(m.group(1)) * 255),
                                  round(float(m.group(2)) * 255),
                                  round(float(m.group(3)) * 255))
    return None


def arg_of(line):
    m = re.search(r"=\s*(Color8?\([^)]*\))", line)
    return m.group(1) if m else None


def comment_hex(line):
    m = re.search(r"#([0-9A-Fa-f]{6})\b", line)
    return ("#" + m.group(1).upper()) if m else None


def main():
    with open(TARGET, "rb") as f:
        raw = f.read()
    md5 = hashlib.md5(raw).hexdigest()
    parts = raw.decode("utf-8").split("\n")
    L = []
    L.append("== PH7-QA-17 · P0-A 静态专项判据（QA 独立 · 只读） ==")
    L.append("target=%s" % TARGET)
    L.append("现盘 stat: size=%d md5=%s lf=%d cr=%d bom=%s" % (
        len(raw), md5, raw.count(0x0A), raw.count(0x0D), raw[:3] == b"\xef\xbb\xbf"))
    if os.path.isfile(SNAP):
        sb = open(SNAP, "rb").read()
        L.append("snapshot_before: size=%d md5=%s" % (len(sb), hashlib.md5(sb).hexdigest()))
        L.append("  → 改前 md5 %s %s" % (
            ("MATCH" if hashlib.md5(sb).hexdigest() == "21c4ece5ec30fdb09ec8b80354248af2" else "MISMATCH"),
            "（= 真·改前副本）"))
    L.append("")

    # ① 26 行逐字节核
    L.append("① 26 行逐字节核（实参 == 目标实参）")
    n_hex_ok = n_lit_ok = 0
    for (ln, name, lit, hexv) in EDITS:
        line = parts[ln - 1]
        a = arg_of(line)
        ah = arg_hex(a) if a else None
        lit_ok = (a == lit)
        hex_ok = (ah == hexv)
        n_lit_ok += lit_ok
        n_hex_ok += hex_ok
        L.append("  行%-5d %-22s 实参=%-24s hex=%-8s 目标=%-8s |字面 %s|hex %s" % (
            ln, name, a, ah, hexv, "OK" if lit_ok else "DIFF", "OK" if hex_ok else "DIFF"))
    L.append("  ⇒ 字面相等 %d/26 ｜ hex 相等 %d/26 → %s" % (
        n_lit_ok, n_hex_ok, "PASS ✅" if n_lit_ok == 26 and n_hex_ok == 26 else "FAIL ❌"))
    L.append("")

    # ⑤ 26 行「实参==注释」
    L.append("⑤ 26 行「实参 hex == 同行注释 hex」")
    stale = []
    for (ln, name, lit, hexv) in EDITS:
        line = parts[ln - 1]
        ah = arg_hex(arg_of(line))
        ch = comment_hex(line)
        if ah != ch:
            stale.append((ln, name, ah, ch))
    L.append("  相等 %d/26 ｜ 不等 %d 行（陈旧注释）" % (26 - len(stale), len(stale)))
    for (ln, name, ah, ch) in stale:
        mark = "★预期(spec 数据源≠注释)" if ln in EXPECT_STALE_COMMENT else "★非预期"
        L.append("  行%-5d %-22s 实参=%s 注释=%s  %s" % (ln, name, ah, ch, mark))
    extra = [s[0] for s in stale if s[0] not in EXPECT_STALE_COMMENT]
    L.append("  ⇒ %s" % ("PASS ✅（仅 spec 已承认的 3 陈旧注释）" if not extra
                         else "❌ 出现非预期行 %s" % extra))
    L.append("")

    # ③ 残留漂移
    L.append("③ 残留漂移（实参 ≠ 注释）")
    L.append("  · 类A 陈旧注释（施工行内，spec §1.5 已裁定覆盖）: %s → %d 行" % (
        sorted(s[0] for s in stale), len(stale)))
    mo = []
    for ln in MOVED_OUT:
        line = parts[ln - 1]
        mo.append((ln, arg_hex(arg_of(line)), comment_hex(line)))
        L.append("  · 类B 移出项 行%-4d 实参=%s 注释=%s（预期）" % mo[-1])
    total = len(stale) + len(mo)
    L.append("  ⇒ 实参≠注释 合计 = %d（类A %d ＋ 类B %d）" % (total, len(stale), len(mo)))
    L.append("     ★ 口径具名：team-lead 口径「残留漂移=5」= **类B 移出项**；")
    L.append("       若按 spec §5.1「实参 vs 同行注释」平口径，则 = **%d**（含类别A 3 陈旧注释）。" % total)
    L.append("")

    # ② 语义出口值断言
    L.append("② 语义出口值断言（getter → 常量 → 常量 hex）")
    gall = True
    defs = {}
    for i, l in enumerate(parts, 1):
        m = re.match(r"\s*const\s+(\w+)\s*:", l)
        if m:
            a = arg_of(l)
            if a:
                defs[m.group(1)] = arg_hex(a)
    for (ln, name, const, hexv) in GETTERS:
        gl = parts[ln - 1]
        ref_ok = (const in gl)
        ch = defs.get(const)
        ok = ref_ok and (ch == hexv)
        gall = gall and ok
        L.append("  :%d %s() -> %s = %s (期望 %s) ref=%s val=%s → %s" % (
            ln, name, const, ch, hexv, ref_ok, "OK" if ch == hexv else "ERR", "OK" if ok else "ERR"))
    L.append("  ⇒ 语义出口 %s" % ("全部 OK ✅" if gall else "有 ERR ❌"))
    L.append("")

    # ④ 枢纽常量出口数
    L.append("④ 枢纽常量出口数（引用点计数，含 getter 引用）")
    hall = True
    for (name, exp) in HUB:
        cnt = 0
        lines_ref = []
        for i, l in enumerate(parts, 1):
            # 引用 = 出现 name 且该行不是其 const 定义行
            if re.search(r"\b%s\b" % re.escape(name), l) and not re.match(r"\s*const\s+%s\s*:" % re.escape(name), l):
                cnt += 1
                lines_ref.append(i)
        ok = (cnt == exp)
        hall = hall and ok
        L.append("  %s: 引用 %d 处（期望 %d）行=%s → %s" % (
            name, cnt, exp, lines_ref, "OK" if ok else "ERR"))
    L.append("  ⇒ 枢纽出口 %s" % ("符合 spec §6.2 ✅" if hall else "有 ERR ❌"))
    L.append("")

    # 汇总
    allpass = (n_lit_ok == 26 and n_hex_ok == 26 and gall and hall
               and not extra)
    L.append("== 汇总 ==")
    L.append("① 26 行逐字节  : %s" % ("PASS" if (n_lit_ok == 26 and n_hex_ok == 26) else "FAIL"))
    L.append("② 语义出口     : %s" % ("PASS" if gall else "FAIL"))
    L.append("③ 残留漂移     : 类A 3 ＋ 类B 5 = %d（口径见上）" % total)
    L.append("④ 枢纽出口     : %s" % ("PASS" if hall else "FAIL"))
    L.append("⑤ 实参==注释   : %d/26（%d 陈旧注释 = spec 已知）" % (26 - len(stale), len(stale)))
    L.append("综合（纯静态 ①②④⑤）：%s" % ("PASS ✅" if allpass else "CONCERNS ❌"))

    os.makedirs(OUTDIR, exist_ok=True)
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    print("WROTE", OUT)
    print("\n".join(L[-8:]))
    return 0 if allpass else 1


if __name__ == "__main__":
    sys.exit(main())

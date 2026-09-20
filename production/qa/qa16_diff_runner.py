# -*- coding: utf-8 -*-
"""
PH7-QA-16 · 逐页 before/after 差分 QA 执行器（quality-lead-2 独立跑）
================================================================================
角色
    老大新验收口径（2026-09-17）：**逐页视觉精修 = 第一优先级**，每页 before/after 实机图；
    每个视觉批由 **quality-lead-2 独立跑** 差分。本脚本 = QA 侧执行器：
      · **不重复造像素算法** —— 像素引擎复用美术线 `.workbuddy/_art_diff/diff_shots.py`
        （经 QA 独立 selftest 验证 PASS），保证两侧数字一致、不漂移；
      · **只加 QA 增量**：① 基线有效性先验（**硬闸门**）② 「未变页判据」 ③ 归因表
        （带区定位 + 共享常量）④ 变化/未变导出 ⑤ `<页id>_cmp.png` 左右并排图。

★ 基线有效性判据（team-lead 2026-09-17 校正 · 比"只核 ui_theme.gd md5"更硬）
    **判据**：`min(before/*.png 的 mtime)` **>** `max(全仓『被渲染的源文件』的 mtime)`
    盲区教训（**本判据的由来**）：只核 `ui_theme.gd` md5 只能证「底色没改过」，
    **验不出「文案/其它批次改过没有」** ⇒ 一个早于 GO3/GO7 落盘拍的目录会溜过。
    源文件集 = 全仓 `.gd/.tscn/.tres/.csv/.json`（排除 `.git/.workbuddy/.godot/
    `.scratch_backup/addons/tests/production/docs/design` 及任何 `*.bak*`）。
    **硬闸门**：不过即停（`exit 2`）、**不出任何差分结论**（除非 `--force`）。

★ 铁律
    · 颜色判断**禁肉眼读图**，一律程序化量测（承接美术线铁律）。
    · **不启动 Godot**、不改任何 `.gd/.csv`（本脚本仅读 PNG + 源文件 mtime + ui_theme.gd md5）。
    · 输出 UTF-8 无 BOM + 纯 LF。

用法
    # ① 基线先验（不需要 after；P0-A 落盘前即可跑）
    python qa16_diff_runner.py --baseline-check --before .workbuddy/_ph7visual/baseline_before
    #   （--baseline-check 与 --baseline-only 等价）

    # ② 正式差分（P0-A 落盘、after 到位后跑）
    python qa16_diff_runner.py --before .workbuddy/_ph7visual/baseline_before --after <after_dir> \
        [--expected-pages expected_pages.txt] [--tag P0-A] [--cmp] [--out production/qa/_qa16_out]

预期改动页表 --expected-pages：一行一个页 id（= 文件名去扩展名），可 `#` 注释。
    → 用于**未变页判据**：清单内页面若实测 IDENTICAL ⇒ ⚠️「预期改但未变 ⇒ 硬编码 Color 未接 token 线索」。
"""
import os
import io
import sys
import time
import argparse
import hashlib
import importlib.util
import collections

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

import numpy as np
from PIL import Image

ROOT = r"E:\Xiuxian\taixuanzongmenlu"
DEFAULT_ENGINE = os.path.join(ROOT, ".workbuddy", "_art_diff", "diff_shots.py")
DEFAULT_BEFORE = os.path.join(ROOT, ".workbuddy", "_ph7visual", "baseline_before")
EXPECT_UI_THEME_MD5 = "21c4ece5ec30fdb09ec8b80354248af2"   # P0-A 改前权威 md5（辅助signal）
UI_THEME = os.path.join(ROOT, "ui_theme.gd")

# 全仓「被渲染的源文件」扫描口径
SRC_EXT = (".gd", ".tscn", ".tres", ".csv", ".json")
SRC_EXCLUDE_DIRS = {".git", ".workbuddy", ".godot", ".scratch_backup",
                    "addons", "tests", "production", "docs", "design"}


# ------------------------------------------------------------------ 工具
def _write(path, text):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with io.open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())


def _md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _fmt(t):
    if t is None:
        return "-"
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(t))


def load_engine(path):
    if not os.path.isfile(path):
        raise SystemExit("引擎不存在: %s" % path)
    spec = importlib.util.spec_from_file_location("art_diff_engine", path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def list_pages(d, engine):
    return engine.list_pages(d)


def newest_sources(root, exts=SRC_EXT, exclude_dirs=SRC_EXCLUDE_DIRS):
    """全仓『会被渲染的源文件』按 mtime 降序：[(mtime, relpath), ...]。"""
    newest = []
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in exclude_dirs and not d.lower().startswith(".bak")]
        for fn in fns:
            low = fn.lower()
            if not low.endswith(exts):
                continue
            if "backup" in low or ".bak" in low:
                continue
            p = os.path.join(dp, fn)
            try:
                newest.append((os.path.getmtime(p), os.path.relpath(p, root)))
            except OSError:
                pass
    newest.sort(reverse=True)
    return newest


# ------------------------------------------------------------------ 基线先验（硬闸门）
def baseline_check(before_dir, expected_md5, root=ROOT, ignore_relpaths=None):
    """核 before 是否确为「改前」clean 快照。硬判据（**两段式**）：
      · before-leg（本函数）：`min(before png mtime) > max(源文件 mtime · 排除本批改动文件)`
        —— 证 before 拍于「上一批落盘之后、本批落盘之前」的干净点。
      · after-leg（`after_freshness_check`）：`min(after png mtime) > max(源文件 mtime · 含本批)`
        —— 证 after 拍于本批落盘之后。
    `ignore_relpaths` = 本批改动文件（相对仓库路径，正/反斜杠皆可）；不传＝全集比较。
    返回 (ok, report_lines, info)。"""
    ign = {(p or "").strip().replace("/", "\\").lower()
           for p in (ignore_relpaths or []) if (p or "").strip()}
    L = []
    info = {"ok": False, "count": 0, "before_min": None, "before_max": None,
            "src_max": None, "src_max_rel": None, "src_max_all": None,
            "ui_theme_md5": None, "ui_theme_mtime": None,
            "span_h": None, "mixed_vintage": False, "ignored": sorted(ign)}

    # --- before 图 ---
    if not os.path.isdir(before_dir):
        L.append("- ❌ before 目录不存在：`%s`" % before_dir)
        return False, L, info
    pngs = []
    for fn in sorted(os.listdir(before_dir)):
        p = os.path.join(before_dir, fn)
        if os.path.isfile(p) and fn.lower().endswith((".png", ".webp", ".jpg", ".jpeg")):
            pngs.append((fn, os.path.getmtime(p)))
    info["count"] = len(pngs)
    if not pngs:
        L.append("- ❌ before 目录内无图片")
        return False, L, info
    ts = [t for _, t in pngs]
    info["before_min"], info["before_max"] = min(ts), max(ts)
    span_h = (max(ts) - min(ts)) / 3600.0
    info["span_h"] = span_h
    info["mixed_vintage"] = span_h > 12.0
    L.append("- before = `%s`：**%d 张**，mtime %s .. %s（跨度 %.2f h → %s）" % (
        before_dir, len(pngs), _fmt(info["before_min"]), _fmt(info["before_max"]), span_h,
        "⚠️ 混龄" if info["mixed_vintage"] else "✅ 同批"))

    # --- 全仓源文件最新 mtime ---
    src = newest_sources(root)
    info["src_max_all"] = src[0] if src else None
    src_eff = None
    for mt, rel in src:
        if rel.replace("/", "\\").lower() in ign:
            continue
        src_eff = (mt, rel)
        break
    if src_eff:
        info["src_max"], info["src_max_rel"] = src_eff
    L.append("- 全仓源文件（`.gd/.tscn/.tres/.csv/.json`，排除备份/工具目录）最新 5 笔：")
    for mt, rel in src[:5]:
        flag = "  ← 本批改动文件（before-leg 排除）" if rel.replace("/", "\\").lower() in ign else ""
        L.append("    · %s  `%s`%s" % (_fmt(mt), rel, flag))
    if info["src_max_all"]:
        if src_eff:
            L.append("- 源文件最新 mtime＝%s（`%s`）；**排除本批改动文件后＝%s（`%s`）**" % (
                _fmt(info["src_max_all"][0]), info["src_max_all"][1],
                _fmt(info["src_max"]), info["src_max_rel"]))
        else:
            L.append("- 源文件最新 mtime＝%s（`%s`）；排除本批后无源文件" % (
                _fmt(info["src_max_all"][0]), info["src_max_all"][1]))

    # --- 硬判据（before-leg）---
    if info["src_max"] is None:
        L.append("- ⚠️ 未扫到源文件，无法执行 mtime 硬判据")
        ok = False
    else:
        ok = info["before_min"] > info["src_max"]
        L.append("- **硬判据（before-leg）**：`min(before png)=%s` **>** `max(源文件·排除本批)=%s`（%s）→ **%s**" % (
            _fmt(info["before_min"]), _fmt(info["src_max"]), info["src_max_rel"],
            "PASS ✅" if ok else "FAIL ❌（before 早于非本批源改动 ⇒ 不能当 before）"))

    # --- 辅助 signal：ui_theme.gd md5（只能证"底色没改过"）---
    if os.path.isfile(UI_THEME):
        info["ui_theme_md5"] = _md5(UI_THEME)
        info["ui_theme_mtime"] = os.path.getmtime(UI_THEME)
        m = (info["ui_theme_md5"] == expected_md5)
        L.append("- 辅助 signal：`ui_theme.gd` md5=`%s` mtime=%s → %s" % (
            info["ui_theme_md5"], _fmt(info["ui_theme_mtime"]),
            "MATCH（改前未动）" if m else "MISMATCH（已非改前）"))
        L.append("  （★ 此 signal **单独不可作数** —— 它只验底色、验不出文案/其它批次 ⇒ 以硬判据为准）") 

    info["ok"] = bool(ok)
    L.append("- **基线先验判定：%s**" % ("PASS ✅" if ok else "FAIL ❌（硬闸门：不出结论）"))
    return bool(ok), L, info


def after_freshness_check(after_dir, root=ROOT):
    """after-leg 硬判据：`min(after png mtime) > max(源文件 mtime · 含本批)`
    —— 证 after 拍于**本批全部落盘之后**。返回 (ok, lines, info)。"""
    L = []
    info = {"ok": False, "count": 0, "after_min": None, "after_max": None,
            "src_max": None, "src_max_rel": None}
    if not os.path.isdir(after_dir):
        L.append("- ❌ after 目录不存在：`%s`" % after_dir)
        return False, L, info
    ts = []
    for fn in os.listdir(after_dir):
        p = os.path.join(after_dir, fn)
        if os.path.isfile(p) and fn.lower().endswith((".png", ".webp", ".jpg", ".jpeg")):
            ts.append(os.path.getmtime(p))
    info["count"] = len(ts)
    if not ts:
        L.append("- ❌ after 目录内无图片")
        return False, L, info
    info["after_min"], info["after_max"] = min(ts), max(ts)
    L.append("- after = `%s`：**%d 张**，mtime %s .. %s" % (
        after_dir, len(ts), _fmt(info["after_min"]), _fmt(info["after_max"])))
    src = newest_sources(root)
    if src:
        info["src_max"], info["src_max_rel"] = src[0]
    if info["src_max"] is None:
        L.append("- ⚠️ 未扫到源文件，无法执行 after-leg 判据")
        return False, L, info
    ok = info["after_min"] > info["src_max"]
    L.append("- **硬判据（after-leg）**：`min(after png)=%s` **>** `max(源文件·含本批)=%s`（`%s`）→ **%s**" % (
        _fmt(info["after_min"]), _fmt(info["src_max"]), info["src_max_rel"],
        "PASS ✅" if ok else "FAIL ❌（after 早于本批源改动 ⇒ 请重拍 after）"))
    info["ok"] = bool(ok)
    return bool(ok), L, info


# ------------------------------------------------------------------ 带区定位
def band_ratios(a, b, engine):
    diff = np.abs(a - b)
    mask = diff.max(axis=2) > engine.PIX_TOL
    h = mask.shape[0]
    t = [mask[:h // 3], mask[h // 3:2 * h // 3], mask[2 * h // 3:]]
    return [float(m.mean()) if m.size else 0.0 for m in t]


# ------------------------------------------------------------------ 左右并排图
def write_cmp(bpath, apath, opath, bar=4):
    try:
        b = Image.open(bpath).convert("RGB")
        a = Image.open(apath).convert("RGB")
    except Exception as e:
        return False
    w = b.width + a.width + bar
    h = max(b.height, a.height)
    canvas = Image.new("RGB", (w, h), (255, 64, 64))
    canvas.paste(b, (0, 0))
    canvas.paste(a, (b.width + bar, 0))
    os.makedirs(os.path.dirname(opath), exist_ok=True)
    canvas.save(opath)
    return True


# ------------------------------------------------------------------ 主流程
def run_diff(before_dir, after_dir, out_dir, expected_pages, tag, engine, do_cmp):
    pages_a = list_pages(before_dir, engine)
    pages_b = list_pages(after_dir, engine)
    common = sorted(set(pages_a) & set(pages_b))
    only_a = sorted(set(pages_a) - set(pages_b))
    only_b = sorted(set(pages_b) - set(pages_a))

    rows = []
    for pid in common:
        a, sa = engine.load_rgb(pages_a[pid])
        b, sb = engine.load_rgb(pages_b[pid])
        if sa != sb:
            rows.append({"page": pid, "verdict": "SIZE_MISMATCH", "ratio": 0.0,
                         "mean": 0.0, "bands": [0, 0, 0], "frm": None, "to": None,
                         "dhue": 0.0, "dy": 0, "dx": 0, "regions": 0})
            continue
        r = engine.compare_page(a, b)
        bands = band_ratios(a, b, engine)
        rows.append({"page": pid, "verdict": r["verdict"], "ratio": r["changed_ratio"],
                     "mean": r["mean_abs_delta"], "bands": bands,
                     "frm": r["from"], "to": r["to"], "dhue": r["dhue"],
                     "dy": r["dy"], "dx": r["dx"], "regions": len(r["regions"])})

    changed = [r for r in rows if r["verdict"] in ("COLOR_DELTA", "MICRO_DELTA", "LAYOUT_SHIFT")]
    identical = [r for r in rows if r["verdict"] == "IDENTICAL"]
    size_mm = [r for r in rows if r["verdict"] == "SIZE_MISMATCH"]

    # ---- 左右并排图（给老大看的形态）
    n_cmp = 0
    if do_cmp:
        cmp_dir = os.path.join(out_dir, "cmp")
        for r in sorted(changed, key=lambda x: -x["ratio"]):
            if write_cmp(pages_a[r["page"]], pages_b[r["page"]],
                         os.path.join(cmp_dir, "%s_cmp.png" % r["page"])):
                n_cmp += 1

    # ---- 归因：共享常量候选
    sig = collections.defaultdict(list)
    for r in changed:
        if r["frm"] is not None:
            k = (tuple(np.round(r["frm"] / 4).astype(int)), tuple(np.round(r["to"] / 4).astype(int)))
            sig[k].append(r["page"])
    globals_ = [(k, v) for k, v in sig.items() if len(v) >= engine.GLOBAL_MIN_PAGES]
    globals_.sort(key=lambda kv: -len(kv[1]))

    # ---- 未变页判据
    exp_set = set(expected_pages or [])
    exp_missed = [r["page"] for r in identical if r["page"] in exp_set]

    # ---- machine TSV
    tsv = ["页id\t判定\t改动占比\t平均Δ\t带上\t带中\t带下\t主改前\t主改后\tΔHue°\t位移dx\t位移dy\t区域数\t在预期表\t线索"]
    for r in sorted(rows, key=lambda x: (x["verdict"], -x["ratio"])):
        note = ""
        if r["verdict"] == "IDENTICAL" and r["page"] in exp_set:
            note = "⚠️预期改但未变=硬编码Color未接token线索"
        tsv.append("\t".join([
            r["page"], r["verdict"], "%.5f" % r["ratio"], "%.3f" % r["mean"],
            "%.4f" % r["bands"][0], "%.4f" % r["bands"][1], "%.4f" % r["bands"][2],
            engine._hex(r["frm"]) if r["frm"] is not None else "-",
            engine._hex(r["to"]) if r["to"] is not None else "-",
            "%.1f" % r["dhue"], str(r["dx"]), str(r["dy"]), str(r["regions"]),
            "Y" if r["page"] in exp_set else "-", note,
        ]))
    _write(os.path.join(out_dir, "qa16_逐页差分.tsv"), "\n".join(tsv) + "\n")

    # ---- human Markdown
    md = []
    md.append("# PH7 逐页 before/after 差分报告%s" % ("｜" + tag if tag else ""))
    md.append("")
    md.append("> quality-lead-2 独立跑；像素引擎 = `.workbuddy/_art_diff/diff_shots.py`（QA 已独立 selftest PASS）。")
    md.append("> **颜色判断全程量测、无肉眼读图**；本报告 = 引擎数字 + QA 增量（未变页判据 / 归因 / 带区定位）。")
    md.append("")
    md.append("## §1 总览")
    md.append("")
    md.append("- before：`%s`（%d 页）" % (before_dir, len(pages_a)))
    md.append("- after ：`%s`（%d 页）" % (after_dir, len(pages_b)))
    md.append("- 配对 %d 页 ｜ **变化 %d** ｜ **未变 %d** ｜ 位移 %d ｜ 尺寸不符 %d" % (
        len(common), len(changed), len(identical),
        sum(1 for r in rows if r["verdict"] == "LAYOUT_SHIFT"), len(size_mm)))
    if do_cmp:
        md.append("- 左右并排图：`%s`（%d 张 `<页id>_cmp.png`，左=before 右=after）" % (
            os.path.join(out_dir, "cmp"), n_cmp))
    if only_a:
        md.append("- ⚠️ 仅 before 有（after 缺页）：%s" % "、".join(only_a))
    if only_b:
        md.append("- ⚠️ 仅 after 有（before 缺页）：%s" % "、".join(only_b))
    md.append("- 阈值（承引擎）：PIX_TOL=%d NOISE_TOL=%g SHIFT_TOL=%d COLOR_EPS=%d GLOBAL_MIN_PAGES=%d" % (
        engine.PIX_TOL, engine.NOISE_TOL, engine.SHIFT_TOL, engine.COLOR_EPS, engine.GLOBAL_MIN_PAGES))

    if globals_:
        md.append("")
        md.append("## §2 ★ 共享常量候选（同 from→to 命中 ≥ %d 页 ⇒ 一次原子改动，须整体验收）" % engine.GLOBAL_MIN_PAGES)
        md.append("")
        md.append("| from | to | ΔHue° | 命中页数 | 样例页 |")
        md.append("|---|---|---|---|---|")
        for (fk, tk), pgs in globals_[:20]:
            fa = np.array(fk, dtype=np.float64) * 4
            ta = np.array(tk, dtype=np.float64) * 4
            md.append("| `%s` | `%s` | %.1f | %d | %s |" % (
                engine._hex(fa), engine._hex(ta),
                engine._hue_signed(engine._hue_of(fa), engine._hue_of(ta)),
                len(pgs), "、".join(pgs[:6]) + ("…" if len(pgs) > 6 else "")))

    md.append("")
    md.append("## §3 变化页 + 归因（带区定位：上/中/下 三带改动占比）")
    md.append("")
    md.append("| 页 id | 判定 | 改动占比 | 平均Δ | 带上 | 带中 | 带下 | 主改 前→后 | 位移(dx,dy) |")
    md.append("|---|---|---|---|---|---|---|---|---|")
    for r in sorted(changed, key=lambda x: -x["ratio"]):
        f = engine._hex(r["frm"]) if r["frm"] is not None else "-"
        t = engine._hex(r["to"]) if r["to"] is not None else "-"
        md.append("| %s | %s | %.3f%% | %.2f | %.2f%% | %.2f%% | %.2f%% | %s→%s | (%d,%d) |" % (
            r["page"], r["verdict"], r["ratio"] * 100.0, r["mean"],
            r["bands"][0] * 100.0, r["bands"][1] * 100.0, r["bands"][2] * 100.0,
            f, t, r["dx"], r["dy"]))

    md.append("")
    md.append("## §4 未变页（★ 关键判据）")
    md.append("")
    if exp_missed:
        md.append("**⚠️ 预期改动但实测未变（%d 页）** —— 判为「**硬编码 Color 未接 token 线索**」：" % len(exp_missed))
        md.append("")
        md.append("> 现象：该页在预期改动清单内，但逐页差分 IDENTICAL（改动占比 < NOISE_TOL=%g）。" % engine.NOISE_TOL)
        md.append("> 归因候选：① 该页颜色为**硬编码 `Color(...)`**、未接 `ui_theme` 语义 getter ⇒ 改 token 不生效；")
        md.append("> ② 该页本批未覆盖；③ 截图未刷新（旧图）。**须逐页回盘核 `Color(` 字面量。**")
        md.append("")
        md.append("- " + "、".join("`%s`" % p for p in exp_missed))
    else:
        md.append("（无：预期改动清单内页面均已实测变化，或未提供 `--expected-pages`）")
    md.append("")
    if identical:
        md.append("全部未变页（%d）：%s" % (
            len(identical), "、".join("`%s`" % r["page"] for r in identical[:80]) +
            ("…" if len(identical) > 80 else "")))

    md.append("")
    md.append("## §5 阈值与口径")
    md.append("")
    md.append("- `PIX_TOL=%d`：每通道绝对差 > %d 才算「该像素变了」（滤 PNG 压缩 / 抗锯齿抖动）。" % (engine.PIX_TOL, engine.PIX_TOL))
    md.append("- `NOISE_TOL=%g`：改动像素占比 < %.2f%% ⇒ 判 `IDENTICAL`（无可见改动）。" % (engine.NOISE_TOL, engine.NOISE_TOL * 100))
    md.append("- `SHIFT_TOL=%d`：布局位移 > %d px ⇒ 判 `LAYOUT_SHIFT`（几何改动，非纯改色）。" % (engine.SHIFT_TOL, engine.SHIFT_TOL))
    md.append("- **未变页判据**（本表核心）：预期改动清单内页面若判 `IDENTICAL` ⇒ 上文 §4 归因，**不得默认「没问题」**。")
    _write(os.path.join(out_dir, "qa16_逐页差分.md"), "\n".join(md) + "\n")

    return {"common": len(common), "changed": len(changed), "identical": len(identical),
            "shift": sum(1 for r in rows if r["verdict"] == "LAYOUT_SHIFT"),
            "size_mm": len(size_mm), "globals": len(globals_), "exp_missed": exp_missed,
            "cmp": n_cmp}


# ------------------------------------------------------------------ 期望页表
def read_expected(path):
    out = []
    if not path or not os.path.isfile(path):
        return out
    with io.open(path, encoding="utf-8-sig") as f:
        for ln in f:
            ln = ln.strip()
            if not ln or ln.startswith("#"):
                continue
            out.append(ln)
    return out


# ------------------------------------------------------------------ entry
def main():
    ap = argparse.ArgumentParser(description="PH7 逐页 before/after 差分 QA 执行器")
    ap.add_argument("--before", default=DEFAULT_BEFORE)
    ap.add_argument("--after", default=None)
    ap.add_argument("--out", default=os.path.join(ROOT, "production", "qa", "_qa16_out"))
    ap.add_argument("--expected-pages", default=None,
                    help="预期改动页清单（一行一页 id，可 # 注释）；用于未变页判据")
    ap.add_argument("--engine", default=DEFAULT_ENGINE)
    ap.add_argument("--expected-md5", default=EXPECT_UI_THEME_MD5)
    ap.add_argument("--tag", default="")
    ap.add_argument("--cmp", action="store_true", help="输出 <页id>_cmp.png 左右并排图")
    ap.add_argument("--baseline-check", "--baseline-only", dest="baseline_only",
                    action="store_true", help="仅跑基线先验硬闸门")
    ap.add_argument("--batch-files", default="",
                    help="本批改动文件（逗号分隔，相对仓库路径）；before-leg 判据会排除它们")
    ap.add_argument("--force", action="store_true", help="基线 FAIL 仍继续差分（默认不出结论）")
    args = ap.parse_args()
    batch = [s.strip() for s in args.batch_files.split(",") if s.strip()]

    os.makedirs(args.out, exist_ok=True)

    # 1) 基线先验（硬闸门 · before-leg）
    ok, blines, binfo = baseline_check(args.before, args.expected_md5, ignore_relpaths=batch)
    _write(os.path.join(args.out, "qa16_基线先验.txt"), "\n".join(blines) + "\n")
    print("\n".join(blines))
    print("")

    if args.baseline_only or not args.after:
        if not args.after and not args.baseline_only:
            print("[提示] 未给 --after ⇒ 仅出基线先验。P0-A 落盘、after 到位后重跑本脚本。")
        return 0 if ok else 2

    # 2) 差分（硬闸门：before-leg / after-leg 任一 FAIL 即停）
    afok, aflines, _ = after_freshness_check(args.after)
    _write(os.path.join(args.out, "qa16_after先验.txt"), "\n".join(aflines) + "\n")
    print("\n".join(aflines))
    print("")
    if (not ok or not afok) and not args.force:
        print("[硬闸门] before-leg=%s after-leg=%s ⇒ 拒绝出差分结论。修基线/重拍后重跑，或 --force 覆盖。" % (
            "PASS" if ok else "FAIL", "PASS" if afok else "FAIL"))
        return 2
    if (not ok or not afok):
        print("[警告] --force：基线未全过，结论不可采信为「改前→改后」。")
    engine = load_engine(args.engine)
    exp = read_expected(args.expected_pages)
    res = run_diff(args.before, args.after, args.out, exp, args.tag, engine, args.cmp)
    print("TOTAL=%d CHANGED=%d IDENTICAL=%d SHIFT=%d SIZE_MM=%d GLOBALS=%d EXP_MISSED=%d CMP=%d" % (
        res["common"], res["changed"], res["identical"], res["shift"],
        res["size_mm"], res["globals"], len(res["exp_missed"]), res["cmp"]))
    print("OUT: %s" % args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())

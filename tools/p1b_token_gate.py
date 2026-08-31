# -*- coding: utf-8 -*-
# tools/p1b_token_gate.py —— 《太玄宗门录》P1-B「圆角 / 字号 Token 阶梯」回归闸门
#
# 【为什么要有这个脚本】
#   P1-B 把散落的圆角值与 .tscn 内联字号收敛进 theme/main_theme.tres 的 Token 阶梯。
#   收敛本身是一次性的；**难的是不回退** —— 任何人后续在 .tres 里手写一个 corner_radius=4，
#   或在 .tscn 里补一句 theme_override_font_sizes/font_size = 14，收口成果就悄悄漏了。
#   本脚本把 design/P1B_theme_token_ladder.md §C.1 的 G1~G8 八条断言固化成可执行闸门。
#
# 【设计前提 —— 与 theme_deviation_scan.py 的分工】
#   theme_deviation_scan.py 管【颜色】散值取证；本脚本管【圆角 + 字号】阶梯合规。
#   两者都遵循同一条铁律：**只读校验，绝不自动改任何文件**。
#
# 【范围诚实声明（务必先读，避免误判收口进度）】
#   P1-B 只覆盖 .tscn 侧 34 处内联字号中的 home_page 29 处。
#   `.gd` 内 add_theme_font_size_override 共 112 处，以及 ui_theme.gd 的四个越界常量
#   （FONT_TITLE=30 / FONT_AUX=14 / FONT_DISPLAY=40 / FONT_H1=32）**均不在本闸门范围**，
#   属 P1-D「运行时字号收口」。本脚本 PASS **不等于**「字号已单源化」。
#
# 【用法】（项目根目录执行）
#   PYTHONIOENCODING=utf-8 python tools/p1b_token_gate.py            # 报告模式，恒 exit 0
#   PYTHONIOENCODING=utf-8 python tools/p1b_token_gate.py --gate     # 闸门模式，任一断言 FAIL -> exit 1
#   ... --gate --skip-pre-f5                                         # 跳过 G7（避免被 pre_f5 反向调用时递归）
#
# 【退出码】
#   报告模式恒 0；--gate 模式：存在 FAIL -> 1，否则 0。WAIVED（已裁定豁免）不计 FAIL。
#
# 【幂等】纯只读，反复跑结果一致，可挂 CI。
import argparse
import hashlib
import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

THEME = "theme/main_theme.tres"
HOME_PAGE = "ui/home_page.tscn"
MAIN_MENU = "art/auto_ui/scenes/main_menu.tscn"

# ── G1 圆角阶梯（UI硬性约束规范 §3.4 / 太玄UI主题规范 §1，项目锁定，禁止 3/4/12/16 等零星半径）──
RADIUS_ALLOWED = {0, 6, 8, 10}
# RC 圆形例外：半径 = 短边/2。当前唯一持有者 sb_avatar（36×36 头像 → 18）。
# 新增此类须走设计评审并在此登记，否则其他 StyleBox 出现 18 一律判违规。
RADIUS_CIRCLE_WHITELIST = {"sb_avatar": 18}

# ── G4/G5 字号阶梯（锁定集，正文禁止 <15，辅助禁止 <13，禁止新增档位）──
FONT_SIZE_ALLOWED = {22, 18, 17, 16, 15, 13}
DEFAULT_FONT_SIZE_EXPECT = 15

# ── G8 颜色零改动指纹 ──
# main_theme.tres 内全部含 Color(...) 的非注释行（strip 后按序拼接）的 SHA256。
# 基线取自 P1-B 落地前（= M2/M3 收口完成态，git index :0）。P1-B 只碰圆角与字号，
# 该指纹必须逐位不变；任何色值/新增色行都会改变它。
COLOR_DIGEST_BASELINE = "346884663b08f23a292b1e4fdc4bb0bcde80417dc91976f1aa7dde7d1a8dfbd2"
COLOR_LINE_COUNT_BASELINE = 42
# 锁定色 #2C5F52（主按钮深青玉绿，终裁 §4.1）在【渲染路径文件】(.gd/.tscn/.tres/.godot)
# 中的出现次数基线。文档(.md/.py)不计入 —— 文档里提及该 hex 不影响渲染，
# 计入会让闸门被无关的文档编辑打成假 FAIL。
LOCKED_HEX = "2C5F52"
LOCKED_HEX_COUNT_BASELINE = 2
RENDER_PATH_EXTS = (".gd", ".tscn", ".tres", ".godot")
EXCLUDE_DIRS = {".git", ".godot", "__pycache__", "node_modules", ".venv", ".venv_genai", "venv", "env"}

# ── G6 base_type 注册校验用：Godot 4 内建控件/主题类型白名单 ──
# 不在此列表内的 Theme 类型名一律视为「自定义命名变体」，必须显式注册 base_type，
# 否则 Godot 4 变体解析会静默回落默认样式（M2/M3 已踩过的坑）。
GODOT_BUILTIN_TYPES = {
    "Button", "Label", "Panel", "PanelContainer", "LineEdit", "TextEdit", "RichTextLabel",
    "TabBar", "TabContainer", "ScrollBar", "HScrollBar", "VScrollBar", "ProgressBar",
    "OptionButton", "CheckBox", "CheckButton", "PopupMenu", "TooltipLabel", "TooltipPanel",
    "ItemList", "Tree", "SpinBox", "SliderJoint", "HSlider", "VSlider", "MenuButton",
    "LinkButton", "TextureButton", "SeparatorLine", "HSeparator", "VSeparator",
    "MarginContainer", "AcceptDialog", "Window", "GraphNode", "CodeEdit", "Control",
}

RE_SECTION = re.compile(r"^\s*\[([a-z_]+)([^\]]*)\]\s*$")
RE_ATTR = re.compile(r'(\w+)\s*=\s*"([^"]*)"')
RE_PROP = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*(?:/[A-Za-z0-9_]+)*)\s*=\s*(.+?)\s*$")
RE_VARIATION = re.compile(r'theme_type_variation\s*=\s*&"([A-Za-z0-9_]+)"')


class Result(object):
    """一条闸门断言的判定结果。

    status 三态而非布尔：WAIVED 用于「已由主理人裁定推迟」的项（如 main_menu 推迟 S2），
    它必须在报告里显性可见 —— 静默跳过等于把技术债藏起来，是本项目明令禁止的。
    """

    def __init__(self, gid, title, status, detail):
        self.gid = gid
        self.title = title
        self.status = status  # PASS / FAIL / WAIVED
        self.detail = detail


def read_text(path):
    for enc in ("utf-8", "utf-8-sig", "gbk"):
        try:
            with io.open(path, "r", encoding=enc) as f:
                return f.read()
        except (UnicodeDecodeError, LookupError):
            continue
    with io.open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def abspath(rel):
    return os.path.join(ROOT, rel.replace("/", os.sep))


def parse_tres(path):
    """把 .tres 拆成 (sub_resources, resource_props)。

    sub_resources: {id: {prop: raw_value}}   —— 各 StyleBoxFlat 等子资源
    resource_props: [(prop, raw_value)]      —— [resource] 段，保序（便于报错定位）
    `;` 之后为注释，不参与解析。
    """
    subs, res = {}, []
    cur_kind, cur_id = "?", "?"
    for raw in read_text(path).splitlines():
        ms = RE_SECTION.match(raw)
        if ms:
            cur_kind = ms.group(1)
            attrs = dict(RE_ATTR.findall(ms.group(2)))
            cur_id = attrs.get("id", cur_kind)
            continue
        code = raw.split(";", 1)[0]
        mp = RE_PROP.match(code)
        if not mp:
            continue
        prop, val = mp.group(1), mp.group(2).strip()
        if cur_kind == "sub_resource":
            subs.setdefault(cur_id, {})[prop] = val
        elif cur_kind == "resource":
            res.append((prop, val))
    return subs, res


def as_int(val):
    try:
        return int(float(val))
    except (TypeError, ValueError):
        return None


# ───────────────────────── G1 圆角阶梯 ─────────────────────────
def gate_g1(subs):
    bad = []
    for sid, props in subs.items():
        for prop, val in props.items():
            if not prop.startswith("corner_radius_"):
                continue
            v = as_int(val)
            if v is None:
                bad.append("%s.%s = %s（非数值）" % (sid, prop, val))
            elif v in RADIUS_ALLOWED:
                continue
            elif RADIUS_CIRCLE_WHITELIST.get(sid) == v:
                continue  # RC 圆形例外，已登记
            else:
                bad.append("%s.%s = %s（不在 {0,6,8,10} 且非登记的 RC 例外）" % (sid, prop, v))
    allowed_show = sorted(RADIUS_ALLOWED) + sorted(set(RADIUS_CIRCLE_WHITELIST.values()))
    if bad:
        return Result("G1", "圆角阶梯合规", "FAIL",
                      "违规 %d 处：\n      - %s" % (len(bad), "\n      - ".join(bad)))
    seen = sorted({as_int(v) for p in subs.values() for k, v in p.items()
                   if k.startswith("corner_radius_") and as_int(v) is not None})
    return Result("G1", "圆角阶梯合规", "PASS",
                  "实测取值集 %s ⊆ 允许集 %s（18 仅 sb_avatar，RC 圆形例外）" % (seen, allowed_show))


# ───────────────────────── G4/G5 字号阶梯 ─────────────────────────
def gate_g4(res_props):
    hits = [v for p, v in res_props if p == "default_font_size"]
    if not hits:
        return Result("G4", "default_font_size 存在且 = 15", "FAIL", "main_theme.tres 未定义 default_font_size")
    v = as_int(hits[-1])
    if v != DEFAULT_FONT_SIZE_EXPECT:
        return Result("G4", "default_font_size 存在且 = 15", "FAIL",
                      "实测 = %s，期望 %d" % (v, DEFAULT_FONT_SIZE_EXPECT))
    return Result("G4", "default_font_size 存在且 = 15", "PASS", "default_font_size = 15（FS_BODY，正文下限）")


def gate_g5(res_props):
    bad, seen = [], set()
    for prop, val in res_props:
        leaf = prop.rsplit("/", 1)[-1]
        if not (leaf.endswith("font_size") or "/font_sizes/" in prop):
            continue
        v = as_int(val)
        if v is None:
            bad.append("%s = %s（非数值）" % (prop, val))
        elif v not in FONT_SIZE_ALLOWED:
            bad.append("%s = %s（不在锁定集 %s）" % (prop, v, sorted(FONT_SIZE_ALLOWED, reverse=True)))
        else:
            seen.add(v)
    if bad:
        return Result("G5", "字号取值 ⊆ 锁定集", "FAIL",
                      "违规 %d 处：\n      - %s" % (len(bad), "\n      - ".join(bad)))
    return Result("G5", "字号取值 ⊆ 锁定集", "PASS",
                  "实测取值集 %s ⊆ {22,18,17,16,15,13}" % sorted(seen, reverse=True))


# ───────────────────────── G6 变体 base_type 注册 ─────────────────────────
def gate_g6(res_props):
    declared_types, base_types = set(), set()
    for prop, _ in res_props:
        if "/" not in prop:
            continue
        head, rest = prop.split("/", 1)
        if rest == "base_type":
            base_types.add(head)
        else:
            declared_types.add(head)
    custom = sorted(t for t in declared_types if t not in GODOT_BUILTIN_TYPES)
    missing = [t for t in custom if t not in base_types]
    orphan = sorted(t for t in base_types if t not in declared_types)
    notes = []
    if orphan:
        notes.append("（提示：%s 注册了 base_type 但无任何样式/字号条目，属空注册）" % "、".join(orphan))
    if missing:
        return Result("G6", "命名变体 base_type 已注册", "FAIL",
                      "缺失 base_type 的变体：%s —— Godot4 会静默回落默认" % "、".join(missing))
    return Result("G6", "命名变体 base_type 已注册", "PASS",
                  "%d 个自定义变体全部已注册：%s%s" % (len(custom), "、".join(custom), "".join(notes)))


# ───────────────────────── G2/G3 .tscn 内联字号剥离 ─────────────────────────
def count_inline_font_size(path):
    n = 0
    for raw in read_text(path).splitlines():
        code = raw.split(";", 1)[0]
        if "theme_override_font_sizes" in code:
            n += 1
    return n


def used_variations(path):
    return sorted(set(RE_VARIATION.findall(read_text(path))))


def has_file_level_theme(path):
    """判断 .tscn 是否在【文件层】挂载了 main_theme.tres。

    只认两种写法：[ext_resource] 引 theme/main_theme.tres，或某节点写 `theme = ExtResource(...)`。
    注意：project.godot 的 gui/theme/custom 是【项目层】兜底主题，作用域更广，
    但它不是文件层挂载 —— 二者区别写进报告，交主理人裁定，脚本不替人做判断。
    """
    txt = read_text(path)
    if "theme/main_theme.tres" in txt:
        return True
    return bool(re.search(r"^\s*theme\s*=\s*ExtResource", txt, re.M))


def gate_tscn(gid, rel, registered_variants, waive_when_unmounted):
    path = abspath(rel)
    if not os.path.exists(path):
        return Result(gid, "%s 内联字号 = 0" % rel, "WAIVED", "文件不存在，跳过")
    n = count_inline_font_size(path)
    used = used_variations(path)
    unknown = [v for v in used if v not in registered_variants]
    if unknown:
        return Result(gid, "%s 内联字号 = 0" % rel, "FAIL",
                      "引用了未在 main_theme.tres 注册的变体：%s" % "、".join(unknown))
    if n == 0:
        return Result(gid, "%s 内联字号 = 0" % rel, "PASS",
                      "内联覆写 0 处；引用变体 %s（均已注册）" % ("、".join(used) or "无"))
    if waive_when_unmounted and not has_file_level_theme(path):
        return Result(gid, "%s 内联字号 = 0" % rel, "WAIVED",
                      "仍有 %d 处内联覆写，但该文件未在文件层挂载 main_theme.tres，"
                      "按 P1-B 裁定 Q4 推迟 S2（豁免有效）" % n)
    return Result(gid, "%s 内联字号 = 0" % rel, "FAIL", "仍有 %d 处内联 font_size 覆写未剥离" % n)


# ───────────────────────── G7 pre_f5_check ─────────────────────────
def gate_g7(skip):
    if skip or os.environ.get("P1B_GATE_NO_RECURSE") == "1":
        return Result("G7", "pre_f5_check.py EXIT 0", "WAIVED", "按 --skip-pre-f5 / 防递归环境变量跳过")
    env = dict(os.environ)
    env["PYTHONIOENCODING"] = "utf-8"      # PowerShell GBK 下不设此项会因编码异常假 FAIL
    env["P1B_GATE_NO_RECURSE"] = "1"
    try:
        p = subprocess.run([sys.executable, "pre_f5_check.py"], cwd=ROOT, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
    except Exception as e:
        return Result("G7", "pre_f5_check.py EXIT 0", "FAIL", "调用失败：%s" % e)
    if p.returncode != 0:
        tail = p.stdout.decode("utf-8", "replace").strip().splitlines()[-6:]
        return Result("G7", "pre_f5_check.py EXIT 0", "FAIL",
                      "EXIT=%d\n      %s" % (p.returncode, "\n      ".join(tail)))
    return Result("G7", "pre_f5_check.py EXIT 0", "PASS", "EXIT=0")


# ───────────────────────── G8 颜色零改动 ─────────────────────────
def color_digest(path):
    lines = [l.strip() for l in read_text(path).splitlines()
             if "Color(" in l and not l.lstrip().startswith(";")]
    return len(lines), hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()


def count_locked_hex():
    total, per_file = 0, []
    for dp, dn, fn in os.walk(ROOT):
        dn[:] = [d for d in dn if d not in EXCLUDE_DIRS]
        for f in fn:
            if not f.endswith(RENDER_PATH_EXTS):
                continue
            p = os.path.join(dp, f)
            c = len(re.findall(LOCKED_HEX, read_text(p), re.I))
            if c:
                total += c
                per_file.append((os.path.relpath(p, ROOT).replace("\\", "/"), c))
    return total, sorted(per_file)


def gate_g8():
    n, dig = color_digest(abspath(THEME))
    locked, per_file = count_locked_hex()
    errs = []
    if n != COLOR_LINE_COUNT_BASELINE:
        errs.append("色行数 %d ≠ 基线 %d" % (n, COLOR_LINE_COUNT_BASELINE))
    if dig != COLOR_DIGEST_BASELINE:
        errs.append("色行指纹变了：\n        实测 %s\n        基线 %s" % (dig, COLOR_DIGEST_BASELINE))
    if locked != LOCKED_HEX_COUNT_BASELINE:
        errs.append("#%s 渲染路径出现次数 %d ≠ 基线 %d（%s）"
                    % (LOCKED_HEX, locked, LOCKED_HEX_COUNT_BASELINE,
                       "、".join("%s×%d" % x for x in per_file)))
    if errs:
        return Result("G8", "颜色零改动（硬红线）", "FAIL", "\n      - ".join([""] + errs).strip())
    return Result("G8", "颜色零改动（硬红线）", "PASS",
                  "main_theme.tres 色行 %d 条指纹一致；#%s 渲染路径 %d 处未变（%s）"
                  % (n, LOCKED_HEX, locked, "、".join("%s×%d" % x for x in per_file)))


# ───────────────────────── main ─────────────────────────
def main():
    ap = argparse.ArgumentParser(description="P1-B 圆角/字号 Token 阶梯回归闸门（G1~G8）")
    ap.add_argument("--gate", action="store_true", help="闸门模式：任一 FAIL -> exit 1")
    ap.add_argument("--skip-pre-f5", action="store_true", help="跳过 G7（pre_f5_check 子进程）")
    args = ap.parse_args()

    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

    subs, res_props = parse_tres(abspath(THEME))
    registered = {p.split("/", 1)[0] for p, _ in res_props if "/" in p}

    results = [
        gate_g1(subs),
        gate_tscn("G2", HOME_PAGE, registered, waive_when_unmounted=False),
        gate_tscn("G3", MAIN_MENU, registered, waive_when_unmounted=True),
        gate_g4(res_props),
        gate_g5(res_props),
        gate_g6(res_props),
        gate_g7(args.skip_pre_f5),
        gate_g8(),
    ]
    results.sort(key=lambda r: r.gid)

    print("=" * 76)
    print("P1-B 圆角 / 字号 Token 阶梯闸门 —— 依据 design/P1B_theme_token_ladder.md §C.1")
    print("=" * 76)
    for r in results:
        print("  [%-6s] %s  %s" % (r.status, r.gid, r.title))
        print("           %s" % r.detail)
    n_fail = sum(1 for r in results if r.status == "FAIL")
    n_waive = sum(1 for r in results if r.status == "WAIVED")
    print("-" * 76)
    print("  合计 %d 项：PASS %d / WAIVED %d / FAIL %d"
          % (len(results), len(results) - n_fail - n_waive, n_waive, n_fail))
    print("  ⚠ 范围诚实：本闸门仅覆盖 .tscn 侧；.gd 的 112 处 add_theme_font_size_override 与")
    print("    ui_theme.gd 四个越界常量(30/14/40/32) 属 P1-D，PASS ≠「字号已单源化」。")
    print("=" * 76)

    if args.gate:
        return 1 if n_fail else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())

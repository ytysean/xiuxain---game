# -*- coding: utf-8 -*-
# tools/theme_deviation_scan.py —— 《太玄宗门录》场景层（.tscn）Theme 偏离扫描
#
# 【为什么要有这个脚本】
#   颜色单源化第一程（P0/P1）已把 **代码层** 的品阶色收口到 UIThemeConfig.QUALITY_COLOR，
#   并由 pre_f5_check.py 第 [22/22] 道闸门看守（main.gd 再出现 `const 品阶色` 即 FAIL）。
#   但 **场景层（.tscn）** 仍散落大量 `Color(...)` 字面量：Panel 的 StyleBoxFlat 底/边、
#   ColorRect 的 color、Label 的 theme_override_colors/font_color……
#   本脚本负责把这些散色**全部揪出来并分类**，作为 M2/M3 收口的事实依据与防回归闸门。
#
# 【最重要的设计前提 —— 扫描 ≠ 盲目收口】
#   P1-C 主理人裁定（先例，必须继承）：
#     - functional 类（品阶色/境界色/描边金/文字色/功能底色…）→ 必须单源化，走 Theme Token。
#     - 合法微色类（scrim / 遮罩 / 阴影 / 页面氛围暗底，且不承载功能语义）
#       → **保留硬编码值**，仅加注释标明，不收口。
#   因此本脚本只做「取证 + 建议分类」，**绝不自动改任何文件**。最终分类由主理人拍板。
#
# 【锁定色红线】
#   #2C5F52（主按钮深青玉绿，终裁规范 §4.1「深青玉绿底+暗金边」）等锁定 hex 的
#   **值绝不可改**；它们若在 .tscn 硬编码，属「冗余写法」→ 只做单源化（引用 token，同值），
#   不做改值。脚本会对锁定 hex 单独打 [LOCKED] 标记提醒。
#
# 【用法】（项目根目录执行）
#   python tools/theme_deviation_scan.py                  # 全量扫描 → 写 tools/theme_deviation_report.md
#   python tools/theme_deviation_scan.py --json out.json  # 附带机器可读 JSON
#   python tools/theme_deviation_scan.py --gate           # 闸门模式：目标文件仍有未确认 functional 偏离即 exit 1
#   python tools/theme_deviation_scan.py --quiet          # 只写报告不刷屏
#
# 【退出码】
#   默认（报告模式）恒为 0 —— 不影响 pre_f5_check.py。
#   --gate 模式：目标文件存在未标注的 functional 偏离 -> 1，否则 0。
#
# 【幂等 / 可重跑】
#   纯只读解析 + 覆盖写报告，反复跑结果一致，可挂 CI 防回归。
#
# 【放行标记（Phase 2 用）】
#   .tscn 与 .tres 同属 Godot 文本资源，支持 `;` 行内注释（参见 theme/main_theme.tres 现网写法）。
#   在散色所在行尾（或紧邻上一行）写入下列任一标记，即视为「已裁定的合法微色」，
#   闸门放行，报告中归入 micro-ack：
#       ; 非功能色·局部微色·保留
#       ; theme-deviation:allow  <理由>
import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ───────────────────────── 扫描范围 ─────────────────────────
# 目录级排除：引擎缓存 / 虚拟环境 / 版本库 / 历史废弃资产。
EXCLUDE_DIR_NAMES = {
    ".git", ".godot", "__pycache__", "node_modules", ".workbuddy",
    ".venv", ".venv_genai", "venv", "env",
}
# 路径片段级排除（相对根目录，正斜杠形式）。
EXCLUDE_PATH_PARTS = (
    "art/_legacy_assets/",           # 历史废弃美术资产
    "art/characters/disciples/提示词包/",  # 提示词包自带 venv
    "tools/auto_ui/_selftest/",      # 工具自测夹具，非产品场景
)

# M2/M3 本轮收口目标（brief 指定的 4 个 .tscn）。闸门只对这些文件生效。
TARGET_FILES = (
    "ui/home_page.tscn",
    "ui/top_bar.tscn",
    "ui/sect_home_page.tscn",
    "ui/bottom_tab_bar.tscn",
)

# 作用域标注：影响报告分组与闸门范围，不影响是否扫描。
SCOPE_TARGET = "target"      # 本轮目标
SCOPE_UI = "ui"              # 其余业务 UI 场景（下一轮候选）
SCOPE_COMPONENT = "component"
SCOPE_ROOT = "root"          # 根目录场景
SCOPE_ADDON = "addon"        # 编辑器插件，不属产品渲染路径
SCOPE_GENERATED = "generated"  # 工具生成物

# ───────────────────────── 分类常量 ─────────────────────────
CLS_FUNCTIONAL = "functional"    # 功能色 → 必须单源化
CLS_MICRO = "micro"              # 合法微色（建议）→ 保留 + 加注释
CLS_MICRO_ACK = "micro-ack"      # 合法微色（已带放行标记）→ 闸门放行
CLS_IDENTITY = "identity"        # 恒等/无害（如 modulate=白）→ 无需处理
CLS_REVIEW = "review"            # 语义不明 → 需主理人裁定

CLASS_ORDER = [CLS_FUNCTIONAL, CLS_REVIEW, CLS_MICRO, CLS_MICRO_ACK, CLS_IDENTITY]

CLASS_CN = {
    CLS_FUNCTIONAL: "functional·必须单源化",
    CLS_MICRO: "合法微色·保留+注释",
    CLS_MICRO_ACK: "合法微色·已标注",
    CLS_IDENTITY: "恒等无害·忽略",
    CLS_REVIEW: "待裁定",
}

# 放行标记（Phase 2 注释用）
ALLOW_MARKERS = ("非功能色", "局部微色", "theme-deviation:allow")

# 项目锁定 hex（终裁规范 §4.1 等）：值绝不可改，只允许单源化。
LOCKED_HEX = {
    "#2C5F52": "主按钮 深青玉绿底（终裁 §4.1）",
    "#B89B5A": "主按钮 暗金描边（终裁 §4.1）",
    "#F0E6D2": "主按钮 米白金文字（终裁 §4.1 / = token title2）",
    "#5C3333": "危险按钮 暗红棕底（终裁 §4.1）",
    "#4A3B2A": "次按钮 深原木棕底（终裁 §4.1）",
    "#16221D": "背景暗叠层（终裁 D 案，alpha 0.50）",
}

# ───────────────────────── 正则 ─────────────────────────
RE_SECTION = re.compile(r"^\s*\[([a-z_]+)([^\]]*)\]\s*$")
RE_ATTR = re.compile(r'(\w+)\s*=\s*"([^"]*)"')
RE_PROP = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*(?:/[A-Za-z0-9_]+)*)\s*=\s*(.+?)\s*$")
RE_COLOR = re.compile(
    r"Color\(\s*(-?[\d.]+(?:e-?\d+)?)\s*,\s*(-?[\d.]+(?:e-?\d+)?)\s*,"
    r"\s*(-?[\d.]+(?:e-?\d+)?)\s*(?:,\s*(-?[\d.]+(?:e-?\d+)?)\s*)?\)"
)
RE_GD_COLOR_CONST = re.compile(
    r"const\s+(COLOR_\w+)\s*:\s*Color\s*=\s*Color\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,"
    r"\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)"
)
RE_GD_DICT = re.compile(r"(QUALITY_COLOR|REALM_COLOR|STATE_COLOR)\s*:\s*Dictionary\s*=\s*\{(.*?)\n\}", re.DOTALL)
RE_GD_DICT_ITEM = re.compile(r'"(\w+)"\s*:\s*Color\.from_string\(\s*"(#[0-9A-Fa-f]{6})"')

# ── 语义判定用 ──
# 氛围/遮罩类节点名（合法微色的强信号）
RE_MICRO_NODE = re.compile(
    r"(Overlay|Mask|Scrim|Shadow|Dim|Vignette|Veil|Glow|Fade|Backdrop|遮罩|暗底|氛围|投影|阴影)",
    re.IGNORECASE,
)
# 结构性功能节点名（描边/分割线/下划线/进度条 —— 功能色的强信号）
RE_FUNC_NODE = re.compile(
    r"(Divider|Underline|Separator|Line\d*$|TopLine|BottomLine|Border|Bar$|Fill|分割线|下划线|描边)",
    re.IGNORECASE,
)
# 实心底板节点名（面板/栏/背景板的 color —— 功能底色，非氛围遮罩）
RE_PLATE_NODE = re.compile(
    r"(^|/)(BG|Bg|BarBG|TopBG|Background|BgColor|Plate|底板|背景板|状态栏背景)$",
)
# 功能色属性（无论挂在哪儿，都是功能语义）
FUNC_PROPS = {
    "border_color",
    "font_color", "font_hover_color", "font_pressed_color", "font_disabled_color",
    "font_focus_color", "font_selected_color", "font_outline_color",
    "bg_color",
    "progress_color", "grabber_color", "icon_color",
}
# 微色属性（阴影一律微色）
MICRO_PROPS = {"shadow_color"}

NEAR_EPS = 3.5 / 255.0   # 近似阈值：≤ ~3/255 视为「手抄漂移」，同一 token 的变体


# ───────────────────────── 工具函数 ─────────────────────────
def to_hex(r, g, b):
    def c(x):
        return max(0, min(255, int(round(float(x) * 255))))
    return "#%02X%02X%02X" % (c(r), c(g), c(b))


def rel(path):
    # Windows 跨盘符（如临时目录在 C: 而项目在 E:）时 relpath 会抛 ValueError，
    # 退化为绝对路径即可 —— 正常扫描路径恒在 ROOT 下，此分支只在自测/外部调用触发。
    try:
        return os.path.relpath(path, ROOT).replace("\\", "/")
    except ValueError:
        return os.path.abspath(path).replace("\\", "/")


def read_text(path):
    for enc in ("utf-8", "utf-8-sig", "gbk"):
        try:
            with open(path, "r", encoding=enc) as f:
                return f.read()
        except (UnicodeDecodeError, LookupError):
            continue
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


# ───────────────────────── Token 表构建 ─────────────────────────
def build_token_table():
    """汇总全项目「合法色源」，供 .tscn 散色比对。

    三层来源（依 UI设计令牌v1.0 §4 分层边界）：
      1. ui_theme.gd        —— const COLOR_*（静态视觉基线 token）
      2. ui_theme_config.gd —— QUALITY/REALM/STATE_COLOR（数据驱动动态业务色）
      3. theme/main_theme.tres —— 全局 Theme 的原生控件基础样式
         （.tscn 里与之同值的 override 属于「重复写了全局 Theme 已有的东西」，
           收口手段是删 override 走全局 Theme，而非再造 token）
    返回 {hex: [token_desc, ...]}。
    """
    table = {}

    def add(hexv, desc):
        table.setdefault(hexv.upper(), [])
        if desc not in table[hexv.upper()]:
            table[hexv.upper()].append(desc)

    # 1) ui_theme.gd
    fp = os.path.join(ROOT, "ui_theme.gd")
    if os.path.exists(fp):
        src = read_text(fp)
        for m in RE_GD_COLOR_CONST.finditer(src):
            add(to_hex(m.group(2), m.group(3), m.group(4)), "UITheme.%s" % m.group(1))

    # 2) ui_theme_config.gd
    fp = os.path.join(ROOT, "ui_theme_config.gd")
    if os.path.exists(fp):
        src = read_text(fp)
        for dm in RE_GD_DICT.finditer(src):
            dict_name, body = dm.group(1), dm.group(2)
            for im in RE_GD_DICT_ITEM.finditer(body):
                add(im.group(2), "UIThemeConfig.%s['%s']" % (dict_name, im.group(1)))

    # 3) theme/main_theme.tres
    fp = os.path.join(ROOT, "theme", "main_theme.tres")
    if os.path.exists(fp):
        section = "?"
        for line in read_text(fp).splitlines():
            ms = RE_SECTION.match(line)
            if ms:
                attrs = dict(RE_ATTR.findall(ms.group(2)))
                section = attrs.get("id", ms.group(1))
                continue
            code = line.split(";", 1)[0]
            mp = RE_PROP.match(code)
            if not mp:
                continue
            for mc in RE_COLOR.finditer(mp.group(2)):
                add(to_hex(mc.group(1), mc.group(2), mc.group(3)),
                    "main_theme.tres[%s].%s" % (section, mp.group(1)))
    return table


def nearest_token(hexv, token_table):
    """返回 (kind, hex, descs, dmax)：
    kind = 'exact' 完全同值 / 'near' 通道差 ≤ NEAR_EPS / None 无匹配。"""
    hexv = hexv.upper()
    if hexv in token_table:
        return "exact", hexv, token_table[hexv], 0.0

    def unhex(h):
        return (int(h[1:3], 16) / 255.0, int(h[3:5], 16) / 255.0, int(h[5:7], 16) / 255.0)

    src = unhex(hexv)
    best = None
    for th, descs in token_table.items():
        t = unhex(th)
        d = max(abs(src[0] - t[0]), abs(src[1] - t[1]), abs(src[2] - t[2]))
        if best is None or d < best[3]:
            best = ("near", th, descs, d)
    if best and best[3] <= NEAR_EPS:
        return best
    return None, None, [], (best[3] if best else 1.0)


# ───────────────────────── .tscn 解析 ─────────────────────────
def scan_file(path, token_table):
    """解析单个 .tscn/.tres，返回散色条目列表。

    逐行状态机：追踪当前 section（node / sub_resource / resource），
    对每条 `属性 = 值` 抽出其中全部 Color(...) 字面量。
    `;` 之后视为注释（Godot 文本资源注释语法），只用于放行标记探测，不参与色值解析。
    """
    items = []
    lines = read_text(path).splitlines()
    sec_kind, sec_desc, sec_type = "?", "?", ""
    prev_comment = ""

    for idx, raw in enumerate(lines, start=1):
        ms = RE_SECTION.match(raw)
        if ms:
            sec_kind = ms.group(1)
            attrs = dict(RE_ATTR.findall(ms.group(2)))
            sec_type = attrs.get("type", "")
            if sec_kind == "node":
                parent = attrs.get("parent", "")
                name = attrs.get("name", "?")
                sec_desc = ("%s/%s" % (parent, name)) if parent and parent != "." else name
            elif sec_kind == "sub_resource":
                sec_desc = "%s#%s" % (sec_type, attrs.get("id", "?"))
            else:
                sec_desc = sec_kind
            prev_comment = ""
            continue

        code, _, comment = raw.partition(";")
        if raw.lstrip().startswith(";"):
            prev_comment = raw.strip()
            continue

        mp = RE_PROP.match(code)
        if not mp:
            if not raw.strip():
                prev_comment = ""
            continue
        prop, value = mp.group(1), mp.group(2)

        for mc in RE_COLOR.finditer(value):
            r, g, b = mc.group(1), mc.group(2), mc.group(3)
            a = mc.group(4) if mc.group(4) is not None else "1"
            hexv = to_hex(r, g, b)
            marker_src = (comment or "") + " " + prev_comment
            acked = any(mk in marker_src for mk in ALLOW_MARKERS)
            items.append({
                "file": rel(path),
                "line": idx,
                "section_kind": sec_kind,
                "section": sec_desc,
                "node_type": sec_type,
                "prop": prop,
                "literal": mc.group(0),
                "hex": hexv,
                "alpha": float(a),
                "acked": acked,
                "marker": marker_src.strip()[:60],
            })
        prev_comment = ""

    for it in items:
        kind, thex, descs, d = nearest_token(it["hex"], token_table)
        it["token_kind"] = kind
        it["token_hex"] = thex
        it["token_descs"] = descs
        it["token_delta"] = round(d, 4)
        it["locked"] = it["hex"] in LOCKED_HEX
        cls, reason, advice = classify(it)
        it["cls"], it["reason"], it["advice"] = cls, reason, advice
    return items


# ───────────────────────── 分类规则引擎 ─────────────────────────
def classify(it):
    """按【语义位置】而非 hex 值分类。返回 (class, reason, advice)。

    ★ 排序铁律（P1-C 裁定的直接推论）：
      「语义位置」规则必须**优先于**「hex 命中 token」规则。
      否则一个 scrim/遮罩只要碰巧用了 token 同值，就会被误判成 functional 而被强行收口——
      那正是 P1-C 明令禁止的「按 hex 一刀切」。故 R2/R3 排在 R5/R6 之前。

    规则优先级（先命中先返回，规则编号写进 reason 便于人工复核/反驳）：
      R0 已带放行标记                  -> micro-ack
      R1 白色 modulate（含半透明）      -> identity（纯透明度控制，无色值语义）
      R2 shadow_color / 阴影            -> micro
      R3 氛围/遮罩节点 + 半透明          -> micro（P1-C 先例：scrim/暗底保留）
      R4 命中 token（同值）              -> functional（冗余重复，删 override 或引 token）
      R5 近似 token（≤3/255）            -> functional（手抄漂移，须对齐 token）
      R6 功能属性（描边/文字/StyleBox底） -> functional
      R7 结构功能节点（分割线/下划线）    -> functional
      R8 实心底板节点的 color            -> functional（面板/栏底色）
      R9 其余                           -> review（需主理人裁定）
    """
    prop, hexv, alpha = it["prop"], it["hex"], it["alpha"]
    node = it["section"]
    base_prop = prop.rsplit("/", 1)[-1]
    lock_note = ("  [LOCKED %s：值锁定，只可单源化不可改值]" % LOCKED_HEX[hexv]) if it["locked"] else ""
    # token 巧合提示：微色若碰巧与 token 同值，附注供主理人复核（但不改变语义分类）
    coincide = ""
    if it["token_kind"] == "exact":
        coincide = "（注：该值恰与 %s 同值，属巧合，语义仍非功能色）" % it["token_descs"][0]

    if it["acked"]:
        return CLS_MICRO_ACK, "R0 已带放行标记（%s）" % it["marker"], "保持现状"

    if base_prop in ("modulate", "self_modulate") and hexv == "#FFFFFF":
        return (CLS_IDENTITY,
                "R1 白色 modulate（α=%.2f）：仅作整体透明度控制，不含色值语义" % alpha,
                "无需处理")

    if base_prop in MICRO_PROPS:
        return CLS_MICRO, "R2 阴影色（%s），非功能语义%s" % (base_prop, coincide), "保留值 + 加注释"

    if RE_MICRO_NODE.search(node) and alpha < 1.0:
        return (CLS_MICRO,
                "R3 氛围/遮罩节点「%s」+ 半透明 α=%.2f，无功能语义（P1-C 先例）%s"
                % (node, alpha, coincide),
                "保留值 + 加注释「非功能色·局部微色·保留」")

    if it["token_kind"] == "exact":
        src = "、".join(it["token_descs"][:3])
        return (CLS_FUNCTIONAL,
                "R4 与既有 token 同值（%s = %s）→ 属冗余硬编码" % (src, hexv),
                "收口：删 override 走全局 Theme / 由脚本引 %s%s" % (it["token_descs"][0], lock_note))

    if it["token_kind"] == "near":
        src = "、".join(it["token_descs"][:3])
        return (CLS_FUNCTIONAL,
                "R5 与 token 近似漂移（%s = %s，本处 %s，Δ=%.4f）"
                % (src, it["token_hex"], hexv, it["token_delta"]),
                "对齐到 %s（视觉差 <1.5%%，可安全归一）%s" % (it["token_descs"][0], lock_note))

    if base_prop in FUNC_PROPS:
        return (CLS_FUNCTIONAL,
                "R6 功能属性 %s（描边/文字/StyleBox 功能底色）承载功能语义，未走 token" % base_prop,
                "新增/复用 Theme token 后收口%s" % lock_note)

    if RE_FUNC_NODE.search(node) and base_prop == "color":
        return (CLS_FUNCTIONAL,
                "R7 结构功能节点「%s」的 color（分割线/下划线/进度条类）" % node,
                "新增/复用 Theme token 后收口%s" % lock_note)

    if RE_PLATE_NODE.search(node) and base_prop == "color":
        return (CLS_FUNCTIONAL,
                "R8 实心底板节点「%s」的 color（面板/栏底色，α=%.2f 属半透底板非遮罩）" % (node, alpha),
                "新增/复用 Theme token 后收口%s" % lock_note)

    return (CLS_REVIEW,
            "R9 语义不明：节点「%s」(%s) 属性 %s α=%.2f，最近 token Δ=%.3f"
            % (node, it["node_type"] or "-", prop, alpha, it["token_delta"]),
            "待主理人裁定 functional / 合法微色")


# ───────────────────────── 文件收集 ─────────────────────────
def scope_of(relpath):
    if relpath in TARGET_FILES:
        return SCOPE_TARGET
    if relpath.startswith("addons/"):
        return SCOPE_ADDON
    if relpath.startswith("art/") or relpath.startswith("tools/"):
        return SCOPE_GENERATED
    if relpath.startswith("ui/"):
        return SCOPE_UI
    if relpath.startswith("components/"):
        return SCOPE_COMPONENT
    return SCOPE_ROOT


def collect_files(include_tres):
    exts = (".tscn", ".tres") if include_tres else (".tscn",)
    out = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIR_NAMES]
        for fn in filenames:
            if not fn.endswith(exts):
                continue
            full = os.path.join(dirpath, fn)
            r = rel(full)
            if any(part in r for part in EXCLUDE_PATH_PARTS):
                continue
            out.append(full)
    out.sort(key=lambda p: (scope_of(rel(p)) != SCOPE_TARGET, rel(p)))
    return out


# ───────────────────────── 报告输出 ─────────────────────────
def md_escape(s):
    return str(s).replace("|", r"\|")


def write_report(items, files, token_table, out_path):
    by_file = {}
    for it in items:
        by_file.setdefault(it["file"], []).append(it)

    def counts(lst):
        c = dict((k, 0) for k in CLASS_ORDER)
        for it in lst:
            c[it["cls"]] = c.get(it["cls"], 0) + 1
        return c

    total = counts(items)
    L = []
    A = L.append
    A("# .tscn Theme 偏离扫描报告")
    A("")
    A("> 生成器：`tools/theme_deviation_scan.py`（只读扫描，**不修改任何文件**，可重跑防回归）  ")
    A("> 分类原则（继承 P1-C 主理人裁定）：**按语义位置分类，不按 hex 一刀切**。  ")
    A("> `functional` = 品阶/境界/描边/文字/功能底色 → 必须单源化；  ")
    A("> `合法微色` = scrim / 遮罩 / 阴影 / 页面氛围暗底 → 保留硬编码 + 加注释，不收口。  ")
    A("> 锁定 hex（如 `#2C5F52` 主按钮深青玉绿，终裁 §4.1）**只可单源化，绝不可改值**。")
    A("")
    A("## 一、总览")
    A("")
    A("| 项 | 值 |")
    A("|---|---|")
    A("| 扫描文件数 | %d |" % len(files))
    A("| 含散色文件数 | %d |" % len(by_file))
    A("| 散色总处数 | %d |" % len(items))
    for k in CLASS_ORDER:
        A("| └ %s | %d |" % (CLASS_CN[k], total.get(k, 0)))
    A("| Token 表色数（合法色源） | %d |" % len(token_table))
    A("")

    A("## 二、按文件汇总")
    A("")
    A("| 作用域 | 文件 | functional | 待裁定 | 合法微色 | 已标注 | 恒等 | 合计 |")
    A("|---|---|---:|---:|---:|---:|---:|---:|")
    for f in sorted(by_file, key=lambda x: (scope_of(x) != SCOPE_TARGET, x)):
        c = counts(by_file[f])
        mark = " **←本轮目标**" if scope_of(f) == SCOPE_TARGET else ""
        A("| %s | `%s`%s | %d | %d | %d | %d | %d | %d |" % (
            scope_of(f), f, mark,
            c[CLS_FUNCTIONAL], c[CLS_REVIEW], c[CLS_MICRO], c[CLS_MICRO_ACK], c[CLS_IDENTITY],
            len(by_file[f])))
    A("")

    A("## 三、逐处明细")
    A("")
    for f in sorted(by_file, key=lambda x: (scope_of(x) != SCOPE_TARGET, x)):
        lst = sorted(by_file[f], key=lambda it: (CLASS_ORDER.index(it["cls"]), it["line"]))
        A("### `%s`  <sub>作用域 %s</sub>" % (f, scope_of(f)))
        A("")
        A("| line | 节点 / 子资源 | 属性 | 色值 | #hex | α | 分类 | 判定理由 | 处置建议 |")
        A("|---:|---|---|---|---|---:|---|---|---|")
        for it in lst:
            A("| %d | `%s` | `%s` | `%s` | `%s`%s | %.2f | **%s** | %s | %s |" % (
                it["line"], md_escape(it["section"]), md_escape(it["prop"]),
                md_escape(it["literal"]), it["hex"], " 🔒" if it["locked"] else "",
                it["alpha"], CLASS_CN[it["cls"]],
                md_escape(it["reason"]), md_escape(it["advice"])))
        A("")

    A("## 四、Token 表（当前合法色源）")
    A("")
    A("| #hex | 来源（token / 全局 Theme 条目） |")
    A("|---|---|")
    for h in sorted(token_table):
        A("| `%s`%s | %s |" % (
            h, " 🔒" if h in LOCKED_HEX else "",
            md_escape("、".join(token_table[h]))))
    A("")
    A("## 五、无散色文件")
    A("")
    clean = [rel(p) for p in files if rel(p) not in by_file]
    A("共 %d 个：%s" % (len(clean), ("`" + "`、`".join(clean) + "`") if clean else "无"))
    A("")

    with open(out_path, "w", encoding="utf-8", newline="\n") as fo:
        fo.write("\n".join(L))
    return total


# ───────────────────────── 闸门 ─────────────────────────
def gate(items):
    bad = [it for it in items
           if scope_of(it["file"]) == SCOPE_TARGET and it["cls"] in (CLS_FUNCTIONAL, CLS_REVIEW)]
    return bad


# ───────────────────────── main ─────────────────────────
def main():
    ap = argparse.ArgumentParser(description=".tscn Theme 偏离扫描（颜色单源化取证）")
    ap.add_argument("--out", default=os.path.join(ROOT, "tools", "theme_deviation_report.md"),
                    help="Markdown 报告输出路径")
    ap.add_argument("--json", default="", help="附带写出机器可读 JSON")
    ap.add_argument("--include-tres", action="store_true", help="同时扫描 .tres")
    ap.add_argument("--gate", action="store_true",
                    help="闸门模式：目标 .tscn 仍有 functional/待裁定 偏离即 exit 1")
    ap.add_argument("--quiet", action="store_true", help="只写报告，不打印明细")
    args = ap.parse_args()

    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

    token_table = build_token_table()
    files = collect_files(args.include_tres)
    items = []
    for p in files:
        items.extend(scan_file(p, token_table))

    total = write_report(items, files, token_table, args.out)

    if args.json:
        with open(args.json, "w", encoding="utf-8") as fo:
            json.dump(items, fo, ensure_ascii=False, indent=2)

    if not args.quiet:
        print("=" * 72)
        print(".tscn Theme 偏离扫描 —— 扫描 %d 文件，检出散色 %d 处" % (len(files), len(items)))
        print("=" * 72)
        for k in CLASS_ORDER:
            print("  %-24s %3d" % (CLASS_CN[k], total.get(k, 0)))
        print("-" * 72)
        print("本轮目标文件：")
        for tf in TARGET_FILES:
            sub = [it for it in items if it["file"] == tf]
            c = dict((k, 0) for k in CLASS_ORDER)
            for it in sub:
                c[it["cls"]] += 1
            print("  %-28s 共%3d  functional=%-3d 待裁定=%-3d 微色=%-3d 已标注=%-3d 恒等=%d"
                  % (tf, len(sub), c[CLS_FUNCTIONAL], c[CLS_REVIEW],
                     c[CLS_MICRO], c[CLS_MICRO_ACK], c[CLS_IDENTITY]))
        print("-" * 72)
        print("报告已写入: %s" % rel(args.out))

    if args.gate:
        bad = gate(items)
        if bad:
            print("[FAIL] 目标 .tscn 仍有 %d 处未收口/未裁定的偏离：" % len(bad))
            for it in bad[:40]:
                print("   %s:%d  %s.%s = %s  (%s)"
                      % (it["file"], it["line"], it["section"], it["prop"], it["hex"], it["cls"]))
            return 1
        print("[PASS] 目标 .tscn 的 functional 偏离已归零（合法微色均带放行标记）")
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())

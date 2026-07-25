# -*- coding: utf-8 -*-
# pre_f5_check.py —— 《太玄宗门录》F5 前必跑检查（一键编排 · 十九道闸门）
#
# 把十九道验证闸门串起来，输出一份统一总判定，让你 F5 之前一眼看清能不能放心开：
#   1) GDScript 4.x 类型推断扫描  (gdscript_type_check.py)
#   2) 配置表全量校验             (validate_all.py)
#   3) 战斗数值红线断言           (tests/combat/test_combat.py)
#   4) 命格数值断言               (tests/destiny/destiny_math.py)
#   5) 灵兽数值红线断言           (tests/beast/test_beast.py：双槽战力/双层适配加成/本体战力镜像)
#   6) 弟子终局机制断言           (tests/disciple/test_disciple.py：资质天花板/坐化触发/资产回收镜像)
#   7) 废弃字段引用扫描           (内联：grep 已改名/已删除字段的 `.属性` 点访问)
#   6) GDScript 缩进结构扫描      (indent_scan.py：开块后紧跟同级/降级行的结构性缩进错误)
#   7) 裸全角字符/跨行未闭字符串扫描 (内联：拦 Godot 真机才报、类型/缩进闸都漏的语法类错误)
#   8) GDScript 静态扫描          (static_check.py：孤立缩进/class body 裸语句/跨作用域引用
#                                  三类「只有 Godot 真机才报」的崩溃，纯文本零误报兜底)
#   9) GDScript 真实语法解析       (gdtoolkit_check.py：用 gdtoolkit 真 parser 拦缩进错位/
#                                  lambda 提前结束/match case 错位等只有 Godot 才报的语法灾难)
#   17) 底部导航 Tab 数校验         (内联：页名 数组 == ["宗门","弟子","御兽","历练","纪事"] 且长度 5)
#   18) 按钮色值/裸 hex 校验        (内联：全文件裸 #xxxxxx 比对顶部常量+四类锁定 hex，未定义即 FAIL)
#   19) 背景透明度校验             (内联：BG_SCENE_ALPHA≤0.35 / BG_OVERLAY_ALPHA==0.50 / #16221D)
#
# 用法（在项目根目录执行）：
#   python pre_f5_check.py
# 退出码：全部通过 -> 0；任一失败 -> 1（可直接挂 pre-commit / CI）。
#
# 说明：本脚本用 sys.executable 启动子进程，保证与运行它的解释器一致；
#       各子工具自带路径解析逻辑，cwd 统一设为项目根目录即可。
import os
import re
import sys
import subprocess

ROOT = os.path.dirname(os.path.abspath(__file__))

# (展示名, 相对根目录的脚本路径, cwd)
CHECKS = [
    ("GDScript 类型推断扫描", "gdscript_type_check.py", ROOT),
    ("配置表全量校验",       "validate_all.py",        ROOT),
    ("战斗数值红线断言",     "tests/combat/test_combat.py",  ROOT),
    ("命格数值断言",         "tests/destiny/destiny_math.py", ROOT),
    ("灵兽数值红线断言",     "tests/beast/test_beast.py", ROOT),
    ("弟子终局机制断言",     "tests/disciple/test_disciple.py", ROOT),
    ("彩蛋数值红线断言",     "tests/easter_egg/test_easter_egg.py", ROOT),
    ("资源产耗闭环断言",     "tests/resource_flow/test_resource_flow.py", ROOT),
    ("增益数值红线断言",     "tests/buff_redline/test_buff_redline.py", ROOT),
    ("七载奖励零通胀校验",   "check_rating_inflation.py", ROOT),
]

# 第九道闸门依赖 gdtoolkit（真实 GDScript parser），它装在 managed Python venv 里，
# 不在 sys.executable（运行本脚本的解释器）里。故第九道单独用这个 venv 的 python 启动。
# 若此 venv 不存在（如换机/未装 gdtoolkit），第九道自动 SKIP 不阻断。
GD_VENV_PY = os.path.join(
    os.path.expanduser("~"),
    ".workbuddy", "binaries", "python", "envs", "default", "Scripts", "python.exe",
)

# 废弃字段引用护栏：命格重构(2026-07-19)把字段 `命格:String` 改名为 `destiny_id`，
# 漏改的 `d.命格` 属性访问会在 F5 运行期崩（Invalid access to property '命格'）。
# 在此列所有「已改名/已删除」的字段名；脚本扫全部 .gd 里 `.字段名` 形式的属性点访问，命中即 FAIL。
# 注意：`.get("字段名")` 字典读旧档写法是安全的（from_dict 兼容），正则只匹配「.字段名」点访问，
#       不匹配 `.get("...")`，也不匹配注释/显示串里的字面 `命格`（无前导点）。
# 以后再做字段改名，直接往这里加一行即可。
DEPRECATED_FIELD_ACCESS = [
    ("命格", "destiny_id", "命格重构：字段改名 destiny_id（2026-07-19）"),
]

PASS_MARK = "\033[92m✅ PASS\033[0m"
FAIL_MARK = "\033[91m❌ FAIL\033[0m"
LINE_W = 60  # 名称与判定之间的填充宽度


def run_check(name, rel_path, cwd):
    """返回 (ok: bool, summary: str)"""
    script = os.path.join(ROOT, rel_path)
    if not os.path.exists(script):
        return False, "脚本缺失: %s" % rel_path, ""
    try:
        proc = subprocess.run(
            [sys.executable, script],
            cwd=cwd,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
    except Exception as e:  # pragma: no cover
        return False, "启动失败: %s" % e

    out = (proc.stdout or "") + (proc.stderr or "")
    ok = (proc.returncode == 0)

    # 从输出里提炼一行摘要
    summary = ""
    for line in out.splitlines():
        s = line.strip()
        if not s:
            continue
        # 各工具的关键摘要行
        if "ALL CLEAN" in s or "校验完成" in s or ("通过" in s and "失败" in s) \
           or "ALL ASSERTIONS PASSED" in s or "可疑结构" in s:
            summary = s
            break
    if not summary:
        # 退化：取最后一行非空输出
        nonempty = [l.strip() for l in out.splitlines() if l.strip()]
        summary = nonempty[-1] if nonempty else ("returncode=%d" % proc.returncode)
    return ok, summary, out


def check_deprecated_fields():
    """内联扫描：禁止对已废弃字段做属性点访问（如 `.命格`）。
    返回 (ok: bool, summary: str, detail: str) —— detail 为命中行的可读明细。"""
    hits = []  # (rel_path, lineno, line_text, old, new)
    for root, dirs, files in os.walk(ROOT):
        # 跳过隐藏/缓存目录（.godot、.workbuddy 等），避免扫到缓存副本误报
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for fn in files:
            if not fn.endswith(".gd"):
                continue
            fp = os.path.join(root, fn)
            rel = os.path.relpath(fp, ROOT)
            try:
                with open(fp, "r", encoding="utf-8") as f:
                    lines = f.readlines()
            except Exception:
                continue
            for idx, raw in enumerate(lines, 1):
                for old, new, _note in DEPRECATED_FIELD_ACCESS:
                    # 匹配 `.命格` 或 `. 命格`（点后可选空白）；`.get("命格")` 不在点后紧跟命格，不会命中
                    if re.search(r"\.\s*" + re.escape(old) + r"\b", raw):
                        hits.append((rel, idx, raw.rstrip("\n"), old, new))
    if not hits:
        return True, "未检出废弃字段属性访问", ""
    detail = "\n".join(
        "%s:%d  .%s → 应改为 .%s  | %s" % (rel, ln, old, new, text.strip())
        for rel, ln, text, old, new in hits
    )
    return False, "检出 %d 处废弃字段属性访问" % len(hits), detail


def check_fullwidth_strings():
    """内联扫描：拦『裸代码区的全角/非法字符』与『跨行未闭合字符串』。
    这类问题只有 Godot 真机才报——gdscript_type_check 只查 :=、indent_scan 只查缩进，
    都会漏（2026-07-20 game_state.gd L306 一处跨行未闭字符串，Godot 真机报 307~742 一长串
    Invalid character 级联，六道闸门全绿却没拦住）。本道在 F5 前即可发现。
    返回 (ok, summary, detail)。"""
    # 代码裸区绝不该出现的中文/全角标点（普通汉字不在内，合法中文变量名如 弟子 不报）
    illegal = set('（）：，！。·【】×｜═「」《》？；、‘’…—')
    hits = []  # (rel, ln, flag, ctx)
    for root, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for fn in files:
            if not fn.endswith('.gd'):
                continue
            fp = os.path.join(root, fn)
            rel = os.path.relpath(fp, ROOT)
            try:
                with open(fp, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
            except Exception:
                continue
            in_str = False
            for ln, raw in enumerate(lines, 1):
                line = raw.rstrip('\n')
                in_comment = False
                i = 0
                while i < len(line):
                    c = line[i]
                    if in_comment:
                        i += 1
                        continue
                    if c == '#' and not in_str:
                        in_comment = True
                        i += 1
                        continue
                    if c == '"':
                        if in_str and i + 1 < len(line) and line[i + 1] == '"':
                            i += 2
                            continue
                        in_str = not in_str
                        i += 1
                        continue
                    if not in_str and (c in illegal or c == '?'):
                        # GDScript 4.x 不支持 C 风格三元 (a) ? b : c，字符串外的 ASCII '?' 一律非法；
                        # 字符串/注释内的 '?' 已被 in_str / in_comment 跳过，不会误报。
                        flag = ('裸全角 ' + c) if c in illegal else '非法字符 ?（GDScript 不支持三元 ? :）'
                        hits.append((rel, ln, flag, line.strip()[:70]))
                    i += 1
                if in_str:
                    hits.append((rel, ln, '跨行未闭字符串', line.strip()[:60]))
                    in_str = False  # 标记为 bug 后重置，避免后续行持续误累积
    if not hits:
        return True, "未检出裸全角字符/未闭字符串", ""
    detail = "\n".join(
        ("%s:%d  裸全角 %s | %s" % (rel, ln, ch, ctx)
         if ch.startswith('裸全角') else
         "%s:%d  %s" % (rel, ln, ctx))
        for rel, ln, ch, ctx in hits
    )
    return False, "检出 %d 处裸全角/未闭字符串" % len(hits), detail


# ── UI 整改「三」新增校验（闸门 17/18/19）────────────────────────────────
# 17) 底部主导航 Tab 数恒为 5（宗门/弟子/御兽/历练/纪事）
# 18) 按钮色值 / 裸 hex：全文件裸 #xxxxxx 比对顶部常量 + 四类锁定 hex，未定义即 FAIL
# 19) 背景透明度：BG_SCENE_ALPHA ≤ 0.35、BG_OVERLAY_ALPHA == 0.50、BG_OVERLAY_COLOR == #16221D
NEW_UI_GATES = ("底部导航 Tab 数校验", "按钮色值/裸 hex 校验", "背景透明度校验")


def check_tab_count():
    """闸门17：底部主导航 Tab 数量恒为 5（宗门/弟子/御兽/历练/纪事）。
    扫描 main.gd 的 `页名` 常量数组，须精确等于该 5 项，否则 FAIL。
    返回 (ok, summary, detail)。"""
    fp = os.path.join(ROOT, "main.gd")
    if not os.path.exists(fp):
        return False, "main.gd 缺失", ""
    try:
        src = open(fp, "r", encoding="utf-8").read()
    except Exception as e:
        return False, "读取失败: %s" % e, ""
    m = re.search(r"页名\s*:?=\s*\[(.*?)\]", src, re.DOTALL)
    if not m:
        return False, "未找到 页名 常量定义", ""
    items = re.findall(r'"([^"]*)"', m.group(1))
    expected = ["宗门", "弟子", "御兽", "历练", "纪事"]
    if items == expected and len(items) == 5:
        return True, "页名 = 5 Tab（宗门/弟子/御兽/历练/纪事）", ""
    detail = "页名 = %s（应为 %s）" % (items, expected)
    return False, "页名 Tab 数/项不匹配（实为 %d 项）" % len(items), detail


def check_button_hex():
    """闸门18：扫描 main.gd 中「规范色表外裸 hex」。
    FAIL 触发条件（用户指定）：存在未定义为顶部常量、且不属于四类按钮锁定 hex 的裸 `#xxxxxx` 字面。
    另对 `Color(r,g,b[,a])` 裸色字面做非阻断扫描：列出现行非常量裸 Color 供复查（不阻断）。
    返回 (ok, summary, detail)。"""
    fp = os.path.join(ROOT, "main.gd")
    if not os.path.exists(fp):
        return False, "main.gd 缺失", ""
    try:
        lines = open(fp, "r", encoding="utf-8").readlines()
    except Exception as e:
        return False, "读取失败: %s" % e, ""

    # 1) 收集「已定义」颜色 hex：顶部 const 直接定义 + 字典条目（如 品阶色）中的 Color 字面
    defined_hex = set()
    color_re = re.compile(
        r"Color\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)(?:\s*,\s*([\d.]+)\s*)?\)")
    for raw in lines:
        is_const = ("const " in raw) or raw.strip().startswith("const")
        is_dict_entry = bool(re.search(r'["\w\u4e00-\u9fff]+"\s*:\s*Color\(', raw))
        if not (is_const or is_dict_entry):
            continue
        for cm in color_re.finditer(raw):
            r, g, b = float(cm.group(1)), float(cm.group(2)), float(cm.group(3))
            a = cm.group(4)
            hx = "%02X%02X%02X" % (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))
            defined_hex.add(hx.lower())
            if a is not None:
                av = int(round(float(a) * 255))
                defined_hex.add(("%08X" % ((int(hx, 16) << 8) | av)).lower())

    # 2) 四类按钮锁死 hex（终裁 · 写实规范 §7.1.1 / 绘图强制规范 §3.2）
    locked = {
        "2c5f52", "b89b5a", "f0e6d2",          # 主按钮
        "4a3b2a", "3e6b5e", "e8dcc8",          # 次按钮
        "3a6f6080", "5a8b7d", "d4e5de",        # 标签/筛选
        "5c3333", "8b5a5a", "e8c8c8",          # 危险按钮
    }
    allowed = defined_hex | locked

    hex_hits = []       # 未定义裸 hex（FAIL）
    color_hits = []     # 非阻断：裸 Color(...) 非常量（供复查）
    for idx, raw in enumerate(lines, 1):
        # 裸 #xxxxxx / #xxxxxxxx
        for hx in re.findall(r"#([0-9A-Fa-f]{6,8})", raw):
            if hx.lower() not in allowed:
                hex_hits.append((idx, "#" + hx))
        # 裸 Color(r,g,b[,a])：仅四通道全为数字字面才算真裸色（引用常量/变量者跳过）
        for cm in color_re.finditer(raw):
            r, g, b = float(cm.group(1)), float(cm.group(2)), float(cm.group(3))
            a = cm.group(4)
            comps = [r, g, b] + ([float(a)] if a else [])
            if all(c in (0.0, 1.0) for c in comps):   # 跳过白/黑/透明等运行期调制色
                continue
            hx = "%02X%02X%02X" % (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))
            if hx.lower() in defined_hex:
                continue
            if a is not None and ("%08X" % ((int(hx, 16) << 8) | int(round(float(a) * 255)))).lower() in defined_hex:
                continue
            color_hits.append((idx, "Color(%s,%s,%s%s)" % (
                cm.group(1), cm.group(2), cm.group(3), ("," + a) if a else "")))

    if hex_hits:
        detail = "\n".join("%s:%d 未定义裸 hex %s" % (os.path.relpath(fp, ROOT), ln, h)
                           for ln, h in hex_hits)
        return False, "检出 %d 处规范色表外裸 hex" % len(hex_hits), detail
    note = ""
    if color_hits:
        note = "（非阻断：%d 处裸 Color 未收口常量，建议复查：%s）" % (
            len(color_hits),
            ", ".join("%d:%s" % (ln, c) for ln, c in color_hits[:5]),
        )
    return True, "未检出规范色表外裸 hex" + note, ""


def check_bg_alpha():
    """闸门19：背景透明度校验。
    BG_SCENE_ALPHA ≤ 0.35；BG_OVERLAY_ALPHA == 0.50；BG_OVERLAY_COLOR == #16221D。
    任一不满足即 FAIL。返回 (ok, summary, detail)。"""
    fp = os.path.join(ROOT, "main.gd")
    if not os.path.exists(fp):
        return False, "main.gd 缺失", ""
    try:
        src = open(fp, "r", encoding="utf-8").read()
    except Exception as e:
        return False, "读取失败: %s" % e, ""
    detail = []
    m = re.search(r"const\s+BG_SCENE_ALPHA\s*:?\s*float\s*=\s*([\d.]+)", src)
    if not m:
        return False, "未找到 BG_SCENE_ALPHA", ""
    scene_a = float(m.group(1))
    if not (scene_a <= 0.35):
        detail.append("BG_SCENE_ALPHA=%s > 0.35" % scene_a)
    m = re.search(r"const\s+BG_OVERLAY_ALPHA\s*:?\s*float\s*=\s*([\d.]+)", src)
    if not m:
        return False, "未找到 BG_OVERLAY_ALPHA", ""
    overlay_a = float(m.group(1))
    if overlay_a != 0.50:
        detail.append("BG_OVERLAY_ALPHA=%s != 0.50" % overlay_a)
    m = re.search(r"const\s+BG_OVERLAY_COLOR\s*:?\s*Color\s*=\s*Color\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)", src)
    if not m:
        return False, "未找到 BG_OVERLAY_COLOR", ""
    rh = "%02X%02X%02X" % (int(round(float(m.group(1)) * 255)),
                           int(round(float(m.group(2)) * 255)),
                           int(round(float(m.group(3)) * 255)))
    if rh.lower() != "16221d":
        detail.append("BG_OVERLAY_COLOR=#%s != #16221D" % rh)
    if detail:
        return False, "背景透明度校验未通过", "; ".join(detail)
    return True, "BG_SCENE_ALPHA=%.2f(≤0.35) / BG_OVERLAY_ALPHA=%.2f / #16221D" % (scene_a, overlay_a), ""


def main():
    print("=" * 64)
    print("  太玄宗门录 · F5 前必跑检查（一键编排 · 必跑闸门）")
    print("=" * 64)

    results = []
    total_steps = len(CHECKS) + 5  # 4 子进程 + 废弃字段 + 缩进结构 + 全角/未闭字符串 + 静态扫描 + gdtoolkit解析
    for i, (name, path, cwd) in enumerate(CHECKS, 1):
        print("  运行中 [%d/%d] %s ..." % (i, total_steps, name), end="\r")
        ok, summary, full = run_check(name, path, cwd)
        results.append((name, ok, summary, full))
        mark = PASS_MARK if ok else FAIL_MARK
        # 名称右侧填充到 LINE_W，再接判定 + 摘要
        pad = LINE_W - len(name)
        if pad < 1:
            pad = 1
        print("  [%d/%d] %s%s %s  %s" % (i, len(CHECKS), name, " " * pad, mark, summary))

    # 第五道：废弃字段引用护栏（内联，不依赖外部脚本）
    d_ok, d_sum, d_detail = check_deprecated_fields()
    total = len(CHECKS) + 1
    results.append(("废弃字段引用扫描", d_ok, d_sum, d_detail))
    mark = PASS_MARK if d_ok else FAIL_MARK
    pad = LINE_W - len("废弃字段引用扫描")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "废弃字段引用扫描", " " * pad, mark, d_sum))

    # 第六道：GDScript 缩进结构扫描（subprocess：indent_scan.py，全量扫 .gd）
    #   gdscript_type_check 只查 `:=` 不查缩进/语法，故此类灾难会漏网直到 F5；
    #   此道专门拦"开块后紧跟同级/降级行"的结构性缩进错误。
    i_ok, i_sum, i_full = run_check("GDScript 缩进结构扫描", "indent_scan.py", ROOT)
    total = total + 1
    results.append(("GDScript 缩进结构扫描", i_ok, i_sum, i_full))
    mark = PASS_MARK if i_ok else FAIL_MARK
    pad = LINE_W - len("GDScript 缩进结构扫描")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "GDScript 缩进结构扫描", " " * pad, mark, i_sum))

    # 第七道：裸全角字符 / 跨行未闭字符串扫描（内联）
    #   gdscript_type_check 只查 :=、indent_scan 只查缩进，二者都漏语法/全角类错误；
    #   2026-07-20 L306 一处跨行未闭字符串，Godot 真机报 307~742 一长串 Invalid character 级联，
    #   六道闸门全绿却没拦住。本道专门拦此类，F5 前即可发现。
    fw_ok, fw_sum, fw_detail = check_fullwidth_strings()
    total = total + 1
    results.append(("裸全角/未闭字符串扫描", fw_ok, fw_sum, fw_detail))
    mark = PASS_MARK if fw_ok else FAIL_MARK
    pad = LINE_W - len("裸全角/未闭字符串扫描")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "裸全角/未闭字符串扫描", " " * pad, mark, fw_sum))

    # 第八道：GDScript 静态扫描（subprocess：static_check.py，全量扫 .gd）
    #   gdscript_type_check 只查 :=、indent_scan 只查开块词后同级/降级；二者都漏
    #   「孤立缩进 / class body 裸语句 / 跨作用域变量引用」这类 Godot 才报的崩溃
    #   （2026-07-20 战斗结算面板连环 class body 崩溃 + 离山汇总面板 7 个 not declared）。
    #   本道基于缩进栈 + 跨行括号追踪，纯文本零误报兜底。
    s_ok, s_sum, s_full = run_check("GDScript 静态扫描", "static_check.py", ROOT)
    total = total + 1
    results.append(("GDScript 静态扫描", s_ok, s_sum, s_full))
    mark = PASS_MARK if s_ok else FAIL_MARK
    pad = LINE_W - len("GDScript 静态扫描")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "GDScript 静态扫描", " " * pad, mark, s_sum))

    # 第九道：GDScript 真实语法解析（gdtoolkit，需 managed venv）
    #   pre_f5_check 既有八道闸门都不调真解析器，对 GDScript 语法错（缩进错位 / lambda 提前结束 /
    #   match case 错位）完全失明，三次被 F5 当人肉解析器才抓到（2026-07-21~22）。
    #   本道用 gdtoolkit 真 parser 兜底；venv 不存在/未装则自动 SKIP 不阻断。
    g_ok = None
    if os.path.exists(GD_VENV_PY):
        try:
            proc = subprocess.run(
                [GD_VENV_PY, os.path.join(ROOT, "gdtoolkit_check.py")],
                cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
            )
            g_out = (proc.stdout or "") + (proc.stderr or "")
            g_ok = (proc.returncode == 0)
            g_sum = ""
            for line in g_out.splitlines():
                s = line.strip()
                if s.startswith("ALL GDScript PARSE OK") or s.startswith("SKIP"):
                    g_sum = s
                    break
            if not g_sum:
                nonempty = [l.strip() for l in g_out.splitlines() if l.strip()]
                g_sum = nonempty[-1] if nonempty else ("returncode=%d" % proc.returncode)
            g_full = g_out
        except Exception as e:
            g_ok = True  # 解析器自身故障不阻断
            g_sum = "gdtoolkit 启动失败，跳过: %s" % e
            g_full = ""
    else:
        g_ok = True
        g_sum = "venv 未检测到，跳过 gdtoolkit 解析（不阻断）"
        g_full = ""
    total = total + 1
    results.append(("GDScript 语法解析(gdtoolkit)", g_ok, g_sum, g_full))
    mark = PASS_MARK if g_ok else FAIL_MARK
    pad = LINE_W - len("GDScript 语法解析(gdtoolkit)")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "GDScript 语法解析(gdtoolkit)", " " * pad, mark, g_sum))

    # 第十道：GDScript 类型名存在性扫描（gdscript_type_resolve.py，纯标准库，无需 venv）
    #   gdtoolkit（第9道）只做语法解析、不解析类型；而 Godot 编辑器一打开 .gd 就跑静态类型检查，
    #   显式注解里写了「语法合法但作用域不存在的类型名」（如 SceneTreeTween，正确是 Tween）会实时标红、
    #   F5 直接崩溃。本道模拟编辑器类型存在性检查：KNOWN_BAD 硬拦，未知大写类型名 WARN 不阻断。
    try:
        proc = subprocess.run(
            [sys.executable, os.path.join(ROOT, "gdscript_type_resolve.py")],
            cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
        )
        tr_full = (proc.stdout or "") + (proc.stderr or "")
        tr_ok = (proc.returncode == 0)
        nonempty = [l.strip() for l in tr_full.splitlines() if l.strip()]
        tr_sum = nonempty[-1] if nonempty else ("returncode=%d" % proc.returncode)
    except Exception as e:
        tr_ok = True
        tr_sum = "类型扫描启动失败，跳过: %s" % e
        tr_full = ""
    total = total + 1
    results.append(("GDScript 类型名存在性扫描", tr_ok, tr_sum, tr_full))
    mark = PASS_MARK if tr_ok else FAIL_MARK
    pad = LINE_W - len("GDScript 类型名存在性扫描")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "GDScript 类型名存在性扫描", " " * pad, mark, tr_sum))
    if tr_ok and "WARN" in tr_full:
        print("    \033[93m⚠ 存在未知类型名（WARN），请人工确认是否拼错/为内部类型，不阻断 F5\033[0m")

    # 第十七~十九道：UI 整改「三」新增校验（Tab 数 / 按钮裸色 / 背景透明度）
    for fn, name in (
        (check_tab_count, "底部导航 Tab 数校验"),
        (check_button_hex, "按钮色值/裸 hex 校验"),
        (check_bg_alpha, "背景透明度校验"),
    ):
        ok, summary, detail = fn()
        total = total + 1
        results.append((name, ok, summary, detail))
        mark = PASS_MARK if ok else FAIL_MARK
        pad = LINE_W - len(name)
        if pad < 1:
            pad = 1
        print("  [%d/%d] %s%s %s  %s" % (total, total, name, " " * pad, mark, summary))

    print("-" * 64)
    all_ok = all(ok for _, ok, _, _ in results)
    if not all_ok:
        # 展开各失败项的问题明细（含文件名/行号/原因）
        print("  \033[91m未通过项明细：\033[0m")
        for name, ok, summary, full in results:
            if ok:
                continue
            print("  --- %s ---" % name)
            if name in NEW_UI_GATES:
                for line in full.splitlines():
                    if line.strip():
                        print("    \033[91m%s\033[0m" % line.strip())
                continue
            for line in full.splitlines():
                s = line.strip()
                if not s:
                    continue
                # gdscript 扫描器的逐条问题行形如 "L123 | TAG | name := val"
                # 或 validate_all 的 "ERR ..."；其余跳过以保持精简
                if s.startswith("L") and "|" in s and ":=" in s:
                    print("    \033[91m%s\033[0m" % s)
                elif s.startswith("ERR") or "FAIL" in s or "Error" in s or "AssertionError" in s:
                    print("    \033[91m%s\033[0m" % s)
                elif "→ 应改为" in s:   # 废弃字段护栏的明细行
                    print("    \033[91m%s\033[0m" % s)
                elif "开块缩进" in s or "开块:" in s or "后继:" in s:  # 缩进结构扫描明细
                    print("    \033[91m%s\033[0m" % s)
                elif "裸全角" in s or "跨行未闭" in s:                # 第7道明细
                    print("    \033[91m%s\033[0m" % s)
                elif "孤立缩进" in s or "class body" in s or "跨作用域引用" in s or "未声明" in s:  # 第8道明细
                    print("    \033[91m%s\033[0m" % s)
                elif "PARSE ERROR" in s or "读取失败" in s:  # 第9道明细
                    print("    \033[91m%s\033[0m" % s)
        print("")
    if all_ok:
        print("  \033[92m总判定: ✅ 全部通过，可放心 F5\033[0m")
    else:
        failed = [n for n, ok, _, _ in results if not ok]
        print("  \033[91m总判定: ❌ 有 %d 项未通过，先修再 F5：%s\033[0m" % (len(failed), "、".join(failed)))
    print("=" * 64)

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())

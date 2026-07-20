# -*- coding: utf-8 -*-
# pre_f5_check.py —— 《太玄宗门录》F5 前必跑三件套（一键编排）
#
# 把七道验证闸门串起来，输出一份统一总判定，让你 F5 之前一眼看清能不能放心开：
#   1) GDScript 4.x 类型推断扫描  (gdscript_type_check.py)
#   2) 配置表全量校验             (validate_all.py)
#   3) 战斗数值红线断言           (tests/combat/test_combat.py)
#   4) 命格数值断言               (tests/destiny/destiny_math.py)
#   5) 废弃字段引用扫描           (内联：grep 已改名/已删除字段的 `.属性` 点访问)
#   6) GDScript 缩进结构扫描      (indent_scan.py：开块后紧跟同级/降级行的结构性缩进错误)
#   7) 裸全角字符/跨行未闭字符串扫描 (内联：拦 Godot 真机才报、类型/缩进闸都漏的语法类错误)
#   8) GDScript 静态扫描          (static_check.py：孤立缩进/class body 裸语句/跨作用域引用
#                                  三类「只有 Godot 真机才报」的崩溃，纯文本零误报兜底)
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
]

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


def main():
    print("=" * 64)
    print("  太玄宗门录 · F5 前必跑检查（一键编排 · 八道闸门）")
    print("=" * 64)

    results = []
    total_steps = len(CHECKS) + 4  # 4 子进程 + 废弃字段 + 缩进结构 + 全角/未闭字符串 + 静态扫描
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

    print("-" * 64)
    all_ok = all(ok for _, ok, _, _ in results)
    if not all_ok:
        # 展开各失败项的问题明细（含文件名/行号/原因）
        print("  \033[91m未通过项明细：\033[0m")
        for name, ok, summary, full in results:
            if ok:
                continue
            print("  --- %s ---" % name)
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

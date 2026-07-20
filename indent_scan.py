#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# indent_scan.py —— GDScript 结构性缩进扫描器（pre_f5_check 第 6 闸门）
#
# 干什么：找出 GDScript 中"开块语句后紧跟同级或降级行"的结构性缩进错误。
#   规则：若某行以块开关键(if/elif/else/for/while/match/func/class/with)开头且以':'结尾，
#         或含行内匿名函数定义 `func(`，则其后的首个非空非注释行缩进必须严格更深，
#         否则极可能是扁平化/少层 bug（Godot 解析崩的根因类）。
#   注：GDScript 的 gdscript_type_check 只查 `:=` 不查缩进/语法，故此类灾难会漏网直到 F5；
#       本脚本正是补这个洞。
#
# 用法：
#   python indent_scan.py            # 扫描项目全部 .gd（跳过 . 开头隐藏目录）
#   python indent_scan.py main.gd    # 只扫单个文件（调试用）
#
# 退出码：0 = 无问题；1 = 发现可疑结构。
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
OPENER = re.compile(r'^\s*(?:static\s+)?(if|elif|else|for|while|match|func|class|with)\b')
INLINE_FUNC = re.compile(r'func\s*\(')  # 行内匿名函数定义


def tab_count(s):
    n = 0
    for ch in s:
        if ch == '\t':
            n += 1
        else:
            break
    return n


def strip_comment(s):
    in_s = False
    in_d = False
    for i, ch in enumerate(s):
        if ch == '"' and not in_s:
            in_d = not in_d
        elif ch == "'" and not in_d:
            in_s = not in_s
        elif ch == '#' and not in_s and not in_d:
            return s[:i]
    return s


def scan_file(path):
    """返回该文件的可疑结构列表 [(lineno, indent_i, indent_j, cur, nxt)]"""
    with open(path, encoding='utf-8') as f:
        lines = f.read().split('\n')
    n = len(lines)
    flags = []
    for i in range(n):
        raw = lines[i]
        if raw.strip() == '':
            continue
        m = OPENER.match(raw)
        is_opener = m is not None
        if not is_opener and INLINE_FUNC.search(raw):
            is_opener = True
        if not is_opener:
            continue
        body = strip_comment(raw).rstrip()
        if not body.endswith(':'):
            continue
        last_colon = body.rfind(':')
        after = body[last_colon + 1:].strip()
        if after != '' and not after.startswith('#'):
            continue  # 单行形式（如 if x: y=1），不检查
        indent_i = tab_count(raw)
        j = i + 1
        while j < n and (lines[j].strip() == '' or strip_comment(lines[j]).strip().startswith('#')):
            j += 1
        if j >= n:
            continue
        indent_j = tab_count(lines[j])
        if indent_j <= indent_i:
            flags.append((i + 1, indent_i, indent_j, raw.strip(), lines[j].strip()))
    return flags


def check_crlf(paths):
    """检查 .gd 文件是否有 CRLF 换行（GDScript 解析器不兼容，会导致 token 边界混乱）"""
    bad = []
    for fp in paths:
        with open(fp, 'rb') as f:
            raw = f.read()
        crlf = raw.count(b'\r\n')
        if crlf > 0:
            bad.append((fp, crlf))
    return bad


def main():
    targets = sys.argv[1:] if len(sys.argv) > 1 else None
    all_flags = []  # (rel_path, lineno, ii, ij, cur, nxt)
    scanned = 0
    file_list = []  # 用于 CRLF 全量扫描

    if targets:
        for t in targets:
            fp = os.path.join(ROOT, t) if not os.path.isabs(t) else t
            file_list.append(fp)
    else:
        for root, dirs, files in os.walk(ROOT):
            dirs[:] = [d for d in dirs if not d.startswith('.')]
            for fn in files:
                if not fn.endswith('.gd'):
                    continue
                file_list.append(os.path.join(root, fn))

    # ---- CRLF 预检（必须在缩进扫描之前，CRLF 会让一切后续检查失效）----
    crlf_bad = check_crlf(file_list)
    if crlf_bad:
        print("=== CRLF 换行符检测：发现 %d 个文件含 \\r\\n（GDScript 不兼容）===" % len(crlf_bad))
        for fp, n in crlf_bad:
            rel = os.path.relpath(fp, ROOT)
            print("  ⚠️ %s : %d 行 CRLF" % (rel, n))
        # 自动修复
        for fp, _ in crlf_bad:
            with open(fp, 'rb') as f:
                raw = f.read()
            fixed = raw.replace(b'\r\n', b'\n').replace(b'\r', b'\n')
            with open(fp, 'wb') as f:
                f.write(fixed)
        print("  → 已自动转为 LF")
        print("缩进结构扫描完成：扫描 %d 个 .gd 文件，共发现 %d 处可疑结构。" % (len(file_list), len(crlf_bad)))
        return 1

    # ---- 缩进结构扫描 ----
    for fp in file_list:
        rel = os.path.relpath(fp, ROOT)
        for ln, ii, ij, cur, nxt in scan_file(fp):
            all_flags.append((rel, ln, ii, ij, cur, nxt))
        scanned += 1

    if all_flags:
        print("=== 缩进结构扫描：发现 %d 处可疑结构（开块后紧跟同级/降级行）===" % len(all_flags))
        for rel, ln, ii, ij, cur, nxt in all_flags:
            print("[%s:L%d] 开块缩进=%d 后继缩进=%d (需更深)" % (rel, ln, ii, ij))
            print("    开块: %s" % cur)
            print("    后继: %s" % nxt)
    print("缩进结构扫描完成：扫描 %d 个 .gd 文件，共发现 %d 处可疑结构。" % (scanned, len(all_flags)))
    return 0 if not all_flags else 1


if __name__ == '__main__':
    sys.exit(main())

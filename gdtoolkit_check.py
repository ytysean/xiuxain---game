# -*- coding: utf-8 -*-
# gdtoolkit_check.py —— pre_f5_check 第九道闸门的解析器后端
#
# 用 gdtoolkit（真实 GDScript parser）parse 全部 .gd，拦 pre_f5_check 既有八道闸门都漏的
# 语法类错误：缩进错位导致 lambda 体提前结束、match case 缩进错位、裸语法畸形等。
# 这类错误只有 Godot 真机才报，此前三次被 F5 当人肉解析器才抓到（2026-07-21/22）。
#
# 由 pre_f5_check.py 用 managed venv 的 python 启动（gdtoolkit 只装在那个 venv）。
# 若 venv 不存在或 gdtoolkit 未安装，本脚本 exit(0) 跳过（不阻断），仅提示。
#
# 退出码：全部 parse OK -> 0；有语法错 -> 1；解析器自身不可用 -> 0（跳过）。
import os
import sys
import glob

ROOT = os.path.dirname(os.path.abspath(__file__))


def main():
    try:
        import gdtoolkit.parser.parser as pp
        parse = pp.parse
    except Exception as e:
        print("SKIP: gdtoolkit 未安装 (%s)，跳过真实 GDScript 语法解析" % e)
        return 0

    files = []
    for p in glob.glob(os.path.join(ROOT, "**", "*.gd"), recursive=True):
        parts = os.path.relpath(p, ROOT).split(os.sep)
        if any(d.startswith(".") for d in parts):  # 跳过 .godot/.workbuddy 等缓存
            continue
        files.append(p)
    files.sort()

    errs = []
    for fp in files:
        rel = os.path.relpath(fp, ROOT)
        try:
            with open(fp, "r", encoding="utf-8") as f:
                src = f.read()
        except Exception as e:
            errs.append("%s | 读取失败: %s" % (rel, e))
            continue
        try:
            parse(src)
        except Exception as e:
            msg = str(e).strip().replace("\n", " ")
            errs.append("%s | PARSE ERROR: %s" % (rel, msg))

    if errs:
        print("GDScript 语法解析未通过，共 %d 处：" % len(errs))
        for e in errs:
            print("  " + e)
        return 1
    print("ALL GDScript PARSE OK (%d files)" % len(files))
    return 0


if __name__ == "__main__":
    sys.exit(main())

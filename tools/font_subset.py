#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
font_subset.py — 《太玄宗门录》S1 UI 字体子集化工具
=====================================================================

【背景】
    Godot 4.7 重新导入 S1 字体 NotoSerifSC-Regular.otf（约 11.6MB，含数万汉字
    字形）时内存爆炸崩溃。本脚本只保留“游戏实际用到的字符”，把字体体积压到 1MB
    以内，让 Godot 重新导入稳定。

【运行前准备 · 依赖】
    需要 Python 3.8+ 与 fonttools。若未安装，脚本在真正执行子集化时会给出清晰的
    pip 安装提示并退出：
        pip install fonttools

【运行命令】
        python tools/font_subset.py
    可选参数：
        --project-root DIR   项目根目录（默认取本脚本上级目录，即仓库根，与 cwd 无关）
        --fonts-dir DIR      字体目录（默认 <项目根>/ui/assets/fonts）
        --report-only        只扫描并统计字符集，不执行子集化（字体文件暂缺时可用）
        --no-cjk-punct       不加 CJK 标点安全网（默认会补 U+3000–U+303F）

【输出】
    子集化结果写入 <fonts-dir>/ 下的 -Subset 文件：
        NotoSerifSC-Regular.otf  -> NotoSerifSC-Subset.otf
        MaShanZheng-Regular.ttf  -> MaShanZheng-Subset.ttf
    并对每个字体打印：原始文件大小、子集字符集大小、子集后保留字形数、子集后文件大小。

【重要 · 子集化后需人工改 UITheme 字体路径】
    Godot 不会自动切换 UI 主题字体。子集化后请把 ui_theme.gd 中两处路径常量改为
    -Subset 文件名（当前字体被临时移出项目，恢复后先跑本脚本）：
        ui_theme.gd:47  FONT_TITLE_PATH = ASSET_DIR + "fonts/MaShanZheng-Regular.ttf"
                                                  -> "fonts/MaShanZheng-Subset.ttf"
        ui_theme.gd:48  FONT_BODY_PATH  = ASSET_DIR + "fonts/NotoSerifSC-Regular.otf"
                                                  -> "fonts/NotoSerifSC-Subset.otf"
    另请全局搜索 "MaShanZheng-Regular" 与 "NotoSerifSC-Regular"，确认无其它硬编码引用。
    （设计文档 design/06-角色与UI/UI美术资产规格_V1.0.md 中也列了路径，可按需同步。）

【设计说明 · 为什么额外补 CJK 标点】
    扫描提取的是“游戏文案里实际出现的所有字符”（汉字、英文、数字、中文标点都算）。
    此外额外保证两项体积可忽略（<百字形）但能保证子集字体真正可用的内容：
      * 全部 ASCII 可见字符 0x20–0x7E：即使文案未用到，也保证数字/英文/符号正常；
      * CJK Symbols and Punctuation 区 U+3000–U+303F：。，、！？「」《》等中文标点，
        作为安全网，避免仅按“汉字 + ASCII”子集化时中文标点变成 tofu 方块。
    注意：中文标点大量出现在 .gd 字符串与 csv 中，本就会被扫描提取；补这一块只是
    兜底“仅运行时拼出、文案里没字面出现”的标点，确保不漏字形。

本脚本为本地工具脚本，不修改任何游戏运行时代码。
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

# ----- 可配置常量 ---------------------------------------------------------
# 默认项目根：本脚本位于 <项目根>/tools/，故取上级目录（与运行 cwd 无关）。
DEFAULT_PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_FONTS_DIR = DEFAULT_PROJECT_ROOT / "ui" / "assets" / "fonts"

# 待子集化的字体：（源文件名 -> 子集文件名）
FONT_TARGETS = [
    ("NotoSerifSC-Regular.otf", "NotoSerifSC-Subset.otf"),
    ("MaShanZheng-Regular.ttf", "MaShanZheng-Subset.ttf"),
]

# 扫描的文案文件扩展名
SCAN_EXTS = {".gd", ".csv", ".md", ".txt"}

# 扫描时剪枝跳过的目录（版本控制 / 引擎缓存 / 工具缓存 / 第三方库）
EXCLUDE_DIRS = {".git", ".godot", "__pycache__", ".workbuddy", "addons"}

# 保证包含的字符范围（纯增量安全网）
ASCII_PRINTABLE = set(chr(c) for c in range(0x20, 0x7F))   # 空格 ~ tilde
CJK_PUNCT = set(chr(c) for c in range(0x3000, 0x3040))      # CJK 标点安全网


def _is_collectable(ch: str) -> bool:
    """仅收集“可见”字符（跳过控制字符 < 0x20 与 DEL 0x7F）。"""
    o = ord(ch)
    return o >= 0x20 and o != 0x7F


def iter_text_files(project_root: Path):
    """遍历项目根下所有文案文件，目录级剪枝跳过 EXCLUDE_DIRS。"""
    for root, dirs, files in os.walk(project_root):
        # 原地修剪，避免进入 .git/.godot/第三方库等目录（性能 + 避免无关文本）
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for name in files:
            if Path(name).suffix.lower() in SCAN_EXTS:
                yield Path(root) / name


def collect_charset(project_root: Path) -> set[str]:
    """递归扫描文案文件，收集游戏实际用到的全部字符（去重）。"""
    charset: set[str] = set()
    scanned = 0
    for path in iter_text_files(project_root):
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception as exc:  # 个别文件读不出则跳过，不阻断整体
            print(f"  [warn] 跳过无法读取的文件 {path}: {exc}", file=sys.stderr)
            continue
        charset.update(ch for ch in text if _is_collectable(ch))
        scanned += 1
    print(f"[scan] 已扫描 {scanned} 个文案文件（.gd/.csv/.md/.txt，已排除 "
          f"{'/'.join(sorted(EXCLUDE_DIRS))} 等目录）")
    return charset


def human_size(n: int) -> str:
    size = float(n)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if size < 1024 or unit == "TB":
            return f"{size:.0f} {unit}" if unit == "B" else f"{size:.2f} {unit}"
        size /= 1024.0
    return f"{size:.2f} TB"


def subset_one(src: Path, dst: Path, final_charset: set[str]) -> int:
    """对单个字体做子集化，返回子集后实际保留的字形数（cmap 条目数）。"""
    try:
        from fontTools.ttLib import TTFont
        from fontTools.subset import Subsetter, Options
    except ImportError:
        print(
            "缺少依赖 fonttools，无法执行子集化。请先安装：\n"
            "    pip install fonttools\n"
            "（本脚本依赖 fontTools.subset 做字体子集化；也可加 --report-only 仅看字符集。）",
            file=sys.stderr,
        )
        sys.exit(1)

    charset_str = "".join(sorted(final_charset))  # 排序保证结果可复现
    options = Options()
    font = TTFont(str(src))
    subsetter = Subsetter(options=options)
    subsetter.populate(text=charset_str)
    subsetter.subset(font)
    font.save(str(dst))
    return len(font.getBestCmap())


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="《太玄宗门录》S1 UI 字体子集化工具（fonttools）"
    )
    parser.add_argument("--project-root", type=Path, default=DEFAULT_PROJECT_ROOT,
                        help="项目根目录（默认：本脚本上级目录）")
    parser.add_argument("--fonts-dir", type=Path, default=None,
                        help="字体目录（默认：<项目根>/ui/assets/fonts）")
    parser.add_argument("--report-only", action="store_true",
                        help="只扫描统计字符集，不执行子集化（字体文件暂缺时可用）")
    parser.add_argument("--no-cjk-punct", action="store_true",
                        help="不补 CJK 标点安全网（默认会补 U+3000–U+303F）")
    args = parser.parse_args(argv)

    project_root = args.project_root.resolve()
    fonts_dir = (args.fonts_dir or (project_root / "ui" / "assets" / "fonts")).resolve()

    # 扫描目录存在性校验：不存在则明确报错并退出
    if not project_root.is_dir():
        print(f"[error] 项目根目录不存在：{project_root}", file=sys.stderr)
        return 1

    print(f"[info] 项目根 ：{project_root}")
    print(f"[info] 字体目录：{fonts_dir}")
    print("[step 1/3] 扫描文案，收集字符集 ...")
    collected = collect_charset(project_root)

    # 叠加保证项（安全网）
    final = set(collected)
    final |= ASCII_PRINTABLE
    if not args.no_cjk_punct:
        final |= CJK_PUNCT

    print(f"[result] 游戏文案提取字符数：{len(collected)}")
    print(f"[result] 叠加保证项后子集字符集：{len(final)} 个字符"
          f"（含全部 ASCII 可见字符"
          f"{' + CJK 标点 U+3000–U+303F' if not args.no_cjk_punct else ''}）")

    if args.report_only:
        print("[done] --report-only：未执行子集化。恢复字体文件后去掉该参数再运行。")
        return 0

    if not fonts_dir.is_dir():
        print(f"[error] 字体目录不存在：{fonts_dir}", file=sys.stderr)
        return 1

    print("[step 2/3] 对字体做子集化 ...")
    any_ok = False
    for src_name, dst_name in FONT_TARGETS:
        src = fonts_dir / src_name
        dst = fonts_dir / dst_name
        if not src.is_file():
            print(f"[error] 字体文件不存在，跳过：{src}\n"
                  f"        请先把 {src_name} 放回 {fonts_dir} 后再运行本脚本。",
                  file=sys.stderr)
            continue
        original_size = src.stat().st_size
        print(f"\n  子集化：{src_name} -> {dst_name}")
        try:
            retained = subset_one(src, dst, final)
        except Exception as exc:  # 单字体失败不影响另一个
            print(f"[error] 子集化失败 {src_name}：{exc}", file=sys.stderr)
            continue
        new_size = dst.stat().st_size
        any_ok = True
        print(f"    原始大小   : {human_size(original_size)} ({original_size} B)")
        print(f"    子集字符集 : {len(final)} 个字符")
        print(f"    保留字形数 : {retained}")
        print(f"    子集后大小 : {human_size(new_size)} ({new_size} B)")
        if original_size:
            ratio = (1 - new_size / original_size) * 100
            print(f"    压缩比     : 减少 {ratio:.1f}%")

    print("\n[step 3/3] 完成。")
    if not any_ok:
        print("[warn] 没有任何字体被子集化（字体文件均不存在）。请恢复字体文件后重试。",
              file=sys.stderr)
        return 1

    print("[next] 记得把 ui_theme.gd 的 FONT_TITLE_PATH / FONT_BODY_PATH 改为 -Subset 文件名，")
    print("       并全局搜索 MaShanZheng-Regular / NotoSerifSC-Regular 确认无其它硬编码引用。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

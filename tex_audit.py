#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""技术美术纹理审计脚本（Godot 4.7）。

扫描工程内所有纹理 .import，统计 compress/mode 分布、分辨率、磁盘体积，
并估算：原图 RGBA8 内存  vs  VRAM 压缩(ASTC 6x6 ~ 1/8) 内存，定位手机端内存/加载热点。

用法: python tex_audit.py [根目录]
默认根: 脚本所在目录。
"""
import os
import re
import sys
from collections import Counter

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))

# Godot 4 纹理 compress/mode 枚举
MODE_NAME = {
    0: "Lossless(无损/RGBA8)",
    1: "Lossy(WebP)",
    2: "VRAM(压缩 ASTC/BC7)",
    3: "Uncompressed(RAW)",
}

def parse_import(path):
    """极简解析 .import 的 [params] 段关键字段。"""
    data = {
        "compress_mode": None,
        "mipmaps": None,
        "size_limit": None,
        "detect_3d": None,
    }
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            txt = f.read()
    except Exception:
        return data
    # 只在 [params] 之后取，免得 [deps] 等段同名干扰
    in_params = False
    for line in txt.splitlines():
        s = line.strip()
        if s.startswith("[params]"):
            in_params = True
            continue
        if s.startswith("[") and not s.startswith("[params]"):
            in_params = False
            continue
        if not in_params:
            continue
        if s.startswith("compress/mode="):
            try: data["compress_mode"] = int(s.split("=", 1)[1])
            except: pass
        elif s.startswith("mipmaps/generate="):
            data["mipmaps"] = s.split("=", 1)[1].strip()
        elif s.startswith("process/size_limit="):
            try: data["size_limit"] = int(s.split("=", 1)[1])
            except: pass
        elif s.startswith("detect_3d/compress_to="):
            try: data["detect_3d"] = int(s.split("=", 1)[1])
            except: pass
    return data

def png_size(png_path):
    """读 PNG IHDR 拿宽高（无第三方库）。"""
    try:
        with open(png_path, "rb") as f:
            head = f.read(33)
        if head[:8] != b"\x89PNG\r\n\x1a\n":
            return None, None
        w = int.from_bytes(head[16:20], "big")
        h = int.from_bytes(head[20:24], "big")
        return w, h
    except Exception:
        return None, None

def main():
    mode_counter = Counter()
    ext_counter = Counter()
    rows = []
    total_png_bytes = 0
    total_rgba8 = 0        # 估算: 当前未压缩 RGBA8 内存(字节)
    total_astc = 0         # 估算: 若改 VRAM ASTC6x6 内存(字节)
    lossless_rgba8 = 0
    lossless_count = 0
    big = []

    for dirpath, _, files in os.walk(ROOT):
        # 跳过引擎缓存与导入产物
        if ".godot" in dirpath or "addons" in dirpath:
            continue
        for fn in files:
            if not fn.endswith(".import"):
                continue
            ipath = os.path.join(dirpath, fn)
            src = os.path.splitext(ipath)[0]
            # 只审计真实纹理源(非 svg/csv/ttf 等导入的 import)
            if not os.path.exists(src):
                continue
            ext = os.path.splitext(src)[1].lower()
            if ext not in (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".exr", ".hdr"):
                continue
            d = parse_import(ipath)
            if d["compress_mode"] is None:
                continue
            ext_counter[ext] += 1
            mode_counter[d["compress_mode"]] += 1

            w, h = png_size(src)
            try:
                raw = os.path.getsize(src)
            except OSError:
                raw = 0
            total_png_bytes += raw

            if w and h:
                rgba8 = w * h * 4
                # mipmap 链额外 ~33%
                if d["mipmaps"] == "true":
                    rgba8_m = int(rgba8 * 1.333)
                else:
                    rgba8_m = rgba8
                astc = int(w * h * 16 / 64)  # ASTC 6x6 ~ 2bpp -> 16bit/px? 实际 6x6=36texel/16byte => ~3.56bpp. 用 4bpp 保守估
                # 用更准的 6x6 => 16 bytes / 36 texels ≈ 3.56 bpp
                astc = int(w * h * 3.56 / 8)
                if d["mipmaps"] == "true":
                    astc = int(astc * 1.333)
            else:
                rgba8_m = 0
                astc = 0

            rows.append((src, w, h, d["compress_mode"], d["mipmaps"], raw, rgba8_m, astc))
            total_rgba8 += rgba8_m
            total_astc += astc
            if d["compress_mode"] == 0:  # Lossless
                lossless_count += 1
                lossless_rgba8 += rgba8_m
            if raw > 300_000:  # >300KB 源文件
                big.append((raw, src, w, h, MODE_NAME.get(d["compress_mode"], "?")))

    def mb(b):
        return b / 1024 / 1024

    print("=" * 70)
    print("技术美术纹理审计  —  根目录:", ROOT)
    print("=" * 70)
    print("\n[1] compress/mode 分布（纹理源文件数）")
    for m, c in sorted(mode_counter.items(), key=lambda x: -x[1]):
        print(f"   mode {m:>2}  {MODE_NAME.get(m,'?'):<22} : {c:>6} 张")

    print("\n[2] 纹理源文件类型")
    for e, c in ext_counter.most_common():
        print(f"   {e:<8} : {c:>6}")

    print("\n[3] 内存估算（仅统计能解析分辨率的）")
    print(f"   当前未压缩 RGBA8 合计(若全载入) : {mb(total_rgba8):>10.1f} MB")
    print(f"   若改 VRAM/ASTC6x6 合计         : {mb(total_astc):>10.1f} MB")
    if total_rgba8:
        print(f"   压缩比(内存)                  : {total_rgba8/max(total_astc,1):>8.1f}x")
    print(f"   仅 Lossless 立绘部分 RGBA8      : {mb(lossless_rgba8):>10.1f} MB ({lossless_count} 张)")
    print(f"   源 PNG 磁盘总大小              : {mb(total_png_bytes):>10.1f} MB")

    print("\n[4] 最大源文件 TOP15（>300KB，按体积降序）")
    big.sort(reverse=True)
    for raw, src, w, h, mode in big[:15]:
        rel = os.path.relpath(src, ROOT)
        print(f"   {mb(raw):>7.1f}MB  {w}x{h:<6} {mode:<20} {rel}")

    print("\n[5] 风险汇总")
    if lossless_count:
        print(f"   ⚠ {lossless_count} 张纹理为 Lossless(RGBA8 未压缩)，手机端内存/加载首要治理对象")
    print(f"   ⚠ default_texture_filter=0(Nearest) 见 project.godot，写实立绘缩放建议改 Linear")
    print("=" * 70)

if __name__ == "__main__":
    main()

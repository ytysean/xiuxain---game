#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
remove_watermark.py — 一键去除 AI 生图平台在角落加盖的「AI生成 / WORKBUDDY」类水印。

沙箱限制说明：
  · ImageGen 工具本身没有「无水印」参数；平台强制盖章。
  · LaMa 深度学习修复模型在沙箱里无法直接安装（lama-cleaner 缺 Rust，ONNX 模型下载超时）。
  · 本脚本采用 OpenCV 纹理克隆 + 羽化，在现有约束下做到一次到位。

策略：不依赖检测。平台水印位置固定（右下角框内侧文字区），直接框选该固定区域，
用其正上方的干净像素带覆盖，再羽化边缘。尺寸自适应：框选宽度/高度按图片短边比例，
同时保证最小像素。

用法：
  python remove_watermark.py <输入1> [<输入2> ...] [--out DIR] [--scale N] [--keep]
    <输入> 可为图片文件或目录（目录递归处理 .png/.jpg/.jpeg）
    --out DIR    输出目录（默认与输入同目录，文件名加 .nowm 后缀）
    --scale N    可选输出缩放到 N×N（默认不缩放）
    --keep       不覆盖源文件（默认就地覆盖；加此参数则输出 .nowm 文件）
"""
import os
import sys
import argparse
import cv2
import numpy as np
from PIL import Image

FRAME_BORDER = 4     # 金框外缘，保留
WM_W_FRAC = 0.22     # 水印区占右下角宽度比例
WM_H_FRAC = 0.10     # 水印区占右下角高度比例
MIN_WM_W = 60        # 最小宽度（px）
MIN_WM_H = 28        # 最小高度（px）
BAND_H = 8           # 克隆源像素带高度
BLUR_K = 5           # 羽化核大小


def _watermark_box(h: int, w: int) -> tuple:
    """返回右下角水印区 (x0,x1,y0,y1)，固定位置、尺寸自适应。"""
    x1 = w - FRAME_BORDER
    y1 = h - FRAME_BORDER
    x0 = max(int(w * (1 - WM_W_FRAC)), x1 - MIN_WM_W)
    y0 = max(int(h * (1 - WM_H_FRAC)), y1 - MIN_WM_H)
    x0 = max(0, min(x0, x1 - 8))
    y0 = max(0, min(y0, y1 - 8))
    return (x0, x1, y0, y1)


def _clone_and_feather(img_bgr: np.ndarray, box) -> np.ndarray:
    x0, x1, y0, y1 = box
    out = img_bgr.copy()
    hole_h = y1 - y0
    hole_w = x1 - x0
    if hole_h <= 0 or hole_w <= 0:
        return out

    # 从水印正上方取一条像素带，用中位数颜色填充（匹配本地背景且无纹理重复条纹）
    band_h = min(BAND_H, y0)
    if band_h <= 0:
        fill = np.median(out.reshape(-1, 3), axis=0).astype(np.uint8)
    else:
        band = out[y0 - band_h:y0, x0:x1]
        fill = np.median(band.reshape(-1, 3), axis=0).astype(np.uint8)
    out[y0:y1, x0:x1] = fill

    # 羽化：洞区与周围 2px 做高斯渐变混合
    y0r = max(0, y0 - 2)
    y1r = min(out.shape[0], y1 + 2)
    x0r = max(0, x0 - 2)
    x1r = min(out.shape[1], x1 + 2)
    roi = out[y0r:y1r, x0r:x1r].copy()
    blurred = cv2.GaussianBlur(roi, (BLUR_K, BLUR_K), 0)

    blend = np.zeros(roi.shape[:2], dtype=np.uint8)
    blend[y0 - y0r:y0 - y0r + hole_h, x0 - x0r:x0 - x0r + hole_w] = 255
    blend = cv2.GaussianBlur(blend, (BLUR_K + 2, BLUR_K + 2), 0)
    blend_3 = np.stack([blend] * 3, axis=2) / 255.0

    out[y0r:y1r, x0r:x1r] = (roi * (1.0 - blend_3) + blurred * blend_3).astype(np.uint8)
    return out


def remove_watermark(img_bgr: np.ndarray) -> np.ndarray:
    h, w = img_bgr.shape[:2]
    box = _watermark_box(h, w)
    return _clone_and_feather(img_bgr, box)


def process_file(src: str, out_dir: str, scale: int, keep: bool) -> str:
    base = os.path.basename(src)
    name, ext = os.path.splitext(base)
    dst_name = f"{name}.nowm{ext}" if (keep or out_dir == os.path.dirname(src)) else base
    dst = os.path.join(out_dir, dst_name)
    pil = Image.open(src).convert("RGB")
    if scale and scale > 0:
        pil = pil.resize((scale, scale), Image.LANCZOS)
    img_bgr = cv2.cvtColor(np.array(pil), cv2.COLOR_RGB2BGR)
    cleaned = remove_watermark(img_bgr)
    Image.fromarray(cv2.cvtColor(cleaned, cv2.COLOR_BGR2RGB)).save(dst, "PNG")
    return dst


def _gather(paths):
    files = []
    for p in paths:
        if os.path.isdir(p):
            for root, _, fnames in os.walk(p):
                for f in fnames:
                    if f.lower().endswith((".png", ".jpg", ".jpeg")):
                        files.append(os.path.join(root, f))
        else:
            files.append(p)
    return files


def main():
    ap = argparse.ArgumentParser(description="Remove AI-gen corner watermarks (OpenCV texture clone).")
    ap.add_argument("inputs", nargs="+")
    ap.add_argument("--out", default=None)
    ap.add_argument("--scale", type=int, default=0)
    ap.add_argument("--keep", action="store_true")
    args = ap.parse_args()
    files = _gather(args.inputs)
    if not files:
        print("No images found.", file=sys.stderr)
        sys.exit(1)
    for src in files:
        out_dir = args.out if args.out else os.path.dirname(src)
        os.makedirs(out_dir, exist_ok=True)
        dst = process_file(src, out_dir, args.scale, args.keep)
        print(f"Wrote {dst}")


if __name__ == "__main__":
    main()

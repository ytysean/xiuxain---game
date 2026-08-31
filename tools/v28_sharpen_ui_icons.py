#!/usr/bin/env python3
"""
v28 全局清晰度优化 — UI 图标批量硬化管线
============================================
目标：消除「AI 大图缩放发虚」导致的整体模糊感

原理：
  - AI 生成 256×256 大图 → Godot 缩放到 44×44 显示 → 细节全丢 → 发虚
  - 本脚本：缩放到 @2x 目标尺寸(88px/64px) + USM 锐化 + 对比度增强
  - Godot 只需再缩 0.5x → 质量损失极小 → 清晰度大幅提升

处理分组：
  ① bld_func (6张): 功能区图标 256→88×88 (@2x of 44)
  ② res_bar  (5张): 资源栏图标  96→64×64 (@2x of ~32)
  ③ nav_tab  (10张): 底部Tab图标 256→96×96 (@2x of ~48)

USM 参数（针对小尺寸图标优化）：
  - radius=0.4px (精细边缘锐化，不产生光晕)
  - amount=120% (增强20%，适度不过度)
  - threshold=0 (全图锐化，图标不需要保护平滑区)

后处理：
  - 对比度 +8%（拉开层次）
  - 备份原图到 _legacy/ 目录
"""

import os
import sys
import glob
import shutil
from pathlib import Path
from PIL import Image, ImageFilter, ImageEnhance
import numpy as np

BASE_DIR = Path(r"E:\Xiuxian\taixuanzongmenlu")
BTN_DIR = BASE_DIR / "art" / "ui" / "buttons"
LEGACY_DIR = BTN_DIR / "_legacy_v28"

# ──────────────────────────────────────────────
# 图标分组配置
# ──────────────────────────────────────────────
ICON_GROUPS = {
    "bld_func": {
        "files": ["bld_dt.png", "bld_xc.png", "bld_sy.png",
                  "bld_zd.png", "bld_zf.png", "bld_zl.png"],
        "target_size": (88, 88),     # @2x of 44×44 显示
        "usm_radius": 0.4,
        "usm_amount": 120,           # 百分比
        "usm_threshold": 0,
        "contrast": 1.10,            # +10% 对比度（功能区图标偏暗）
        "desc": "功能区图标",
    },
    "res_bar": {
        "files": ["res_lingshi.png", "res_lingqi.png", "res_lingzhi.png",
                  "res_shengwang.png", "res_xianyu.png"],
        "target_size": (64, 64),     # @2x of ~32×32 显示
        "usm_radius": 0.35,
        "usm_amount": 115,
        "usm_threshold": 0,
        "contrast": 1.05,            # +5% 对比度（资源图标已去背，保持自然）
        "desc": "资源栏图标",
    },
    "nav_tab": {
        "files": [
            "nav_dz_normal.png", "nav_dz_selected.png",
            "nav_gd_normal.png", "nav_gd_selected.png",
            "nav_js_normal.png", "nav_js_selected.png",
            "nav_jy_normal.png", "nav_jy_selected.png",
            "nav_ll_normal.png", "nav_ll_selected.png",
        ],
        "target_size": (96, 96),     # @2x of ~48×48 Tab 图标
        "usm_radius": 0.45,
        "usm_amount": 125,
        "usm_threshold": 0,
        "contrast": 1.08,
        "desc": "底部Tab导航图标",
    },
}


def backup_original(filepath: Path) -> None:
    """备份原图到 _legacy_v28/ 目录"""
    LEGACY_DIR.mkdir(exist_ok=True)
    rel = filepath.relative_to(BTN_DIR)
    dest = LEGACY_DIR / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists():
        shutil.copy2(filepath, dest)
        print(f"  备份: {rel}")


def process_icon(
    src_path: Path,
    target_size: tuple[int, int],
    usm_radius: float,
    usm_amount: int,
    usm_threshold: int,
    contrast_factor: float,
) -> Image.Image | None:
    """
    单张图标硬化流程：
      1. RGBA 加载
      2. LANCZOS 高质量缩小到目标尺寸
      3. USM 锐化（Unsharp Mask）
      4. 对比度增强
      5. 返回处理后的 Image
    """
    try:
        img = Image.open(src_path).convert("RGBA")

        # Step 1: 高质量缩小（LANCZOS 是 PIL 最佳降采样滤波器）
        if img.size != target_size:
            resized = img.resize(target_size, Image.LANCZOS)
        else:
            resized = img

        # Step 2: USM 锐化
        sharpened = resized.filter(ImageFilter.UnsharpMask(
            radius=usm_radius,
            percent=usm_amount,
            threshold=usm_threshold,
        ))

        # Step 3: 对比度增强
        if contrast_factor != 1.0:
            enhancer = ImageEnhance.Contrast(sharpened)
            result = enhancer.enhance(contrast_factor)
        else:
            result = sharpened

        return result

    except Exception as e:
        print(f"  ❌ 处理失败 {src_path.name}: {e}")
        return None


def analyze_quality(img: Image.Image, label: str) -> dict:
    """分析图片质量指标（用于前后对比）"""
    arr = np.array(img.convert("RGB"))
    # Laplacian 方差（清晰度指标，越高越清晰）
    from PIL import ImageOps
    gray = ImageOps.grayscale(img.convert("RGB"))
    gray_arr = np.array(gray)
    laplacian = np.var(gray_arr)
    # 边缘强度（Sobel）
    sx = np.array([[-1,0,1],[-2,0,2],[-1,0,1]], dtype=float)
    sy = np.array([[-1,-2,-1],[0,0,0],[1,2,1]], dtype=float)
    gx = np.abs(np.convolve(gray_arr.flatten(), sx.flatten(), 'same'))
    gy = np.abs(np.convolve(gray_arr.flatten(), sy.flatten(), 'same'))
    edge_strength = (gx.mean() + gy.mean()) / 2
    return {
        "label": label,
        "size": img.size,
        "brightness": arr.mean(),
        "laplacian_var": laplacian,
        "edge_strength": edge_strength,
    }


def main():
    print("=" * 60)
    print("v28 全局清晰度优化 — UI 图标批量硬化管线")
    print("=" * 60)
    print(f"按钮目录: {BTN_DIR}")
    print(f"备份目录: {LEGACY_DIR}")
    print()

    total_processed = 0
    total_skipped = 0
    results = []

    for group_name, config in ICON_GROUPS.items():
        desc = config["desc"]
        files = config["files"]
        print(f"┌─ {'─' * 56}")
        print(f"│ [{group_name}] {desc} ({len(files)} 张)")
        print(f"│   目标尺寸: {config['target_size'][0]}×{config['target_size'][1]}  "
              f"USM({config['usm_radius']}, {config['usm_amount']}%, "
              f"阈值{config['usm_threshold']})  对比度×{config['contrast']}")

        for fname in files:
            src = BTN_DIR / fname
            if not src.exists():
                print(f"│   ⚠️  跳过(不存在): {fname}")
                total_skipped += 1
                continue

            # 备份原图
            backup_original(src)

            # 分析原图
            orig_img = Image.open(src).convert("RGBA")
            before = analyze_quality(orig_img, f"{fname} (前)")

            # 处理
            result = process_icon(
                src,
                config["target_size"],
                config["usm_radius"],
                config["usm_amount"],
                config["usm_threshold"],
                config["contrast"],
            )

            if result is None:
                total_skipped += 1
                continue

            # 分析处理后
            after = analyze_quality(result, f"{fname} (后)")

            # 保存（覆盖原文件）
            result.save(src, optimize=True)
            total_processed += 1

            # 报告
            size_change = f"{orig_img.size[0]}×{orig_img.size[1]} → {result.size[0]}×{result.size[1]}"
            lap_delta = after["laplacian_var"] - before["laplacian_var"]
            edge_delta = after["edge_strength"] - before["edge_strength"]
            lap_sign = "+" if lap_delta > 0 else ""
            edge_sign = "+" if edge_delta > 0 else ""

            print(f"│   ✅ {fname:28s} {size_change:20s}  "
                  f"Laplacian:{lap_sign}{lap_delta:.0f}  Edge:{edge_sign}{edge_delta:.1f}")

            results.append({
                "file": fname,
                "before": before,
                "after": after,
            })

        print(f"└─ {'─' * 56}")
        print()

    # ──────────────────────────────────────────
    # 汇总报告
    # ──────────────────────────────────────────
    print("=" * 60)
    print(f"📊 处理完成: {total_processed} 张成功, {total_skipped} 张跳过")
    print(f"   原图已备份至: _legacy_v28/")
    print()

    # 清晰度提升汇总
    if results:
        avg_lap = sum(r["after"]["laplacian_var"] - r["before"]["laplacian_var"] for r in results) / len(results)
        avg_edge = sum(r["after"]["edge_strength"] - r["before"]["edge_strength"] for r in results) / len(results)
        lap_sign = "+" if avg_lap > 0 else ""
        edge_sign = "+" if avg_edge > 0 else ""
        print(f"   平均清晰度变化:")
        print(f"     Laplacian方差: {lap_sign}{avg_lap:.0f} (↑=更清晰)")
        print(f"     边缘强度:     {edge_sign}{avg_edge:.2f} (↑=更锐利)")
    print("=" * 60)


if __name__ == "__main__":
    main()

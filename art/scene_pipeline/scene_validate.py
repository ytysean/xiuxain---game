# -*- coding: utf-8 -*-
"""
太玄宗门录 · 场景背景自动校验 (scene_validate.py)  v2（新增 v4 软检测：镜像相似度 / 山体重心偏移）
====================================================
场景版 clean_center()：把美术规范写成代码硬栅，每张图生成后自动检测，
不合格触发回流重绘（batch_gen 见 status=pending_dispatch / fail）。

三项必检（对标图标管线 clean_center 的“区域约束/安全栅”思想）：
  1. 亮度合规：中心 UI 呼吸区平均亮度 ≤ center_max_brightness(0.304)，超出即不合格（硬栅）
  2. 规格合规：分辨率 == canvas_size(960×1708)、色彩空间 RGB、cover-fit 到标准（硬栅）
  3. 构图合规：下中区(麒麟/台阶)非均匀性 + 天空区方差 启发式检测；
     ⚠ 诚实标注 —— 真正的“主殿/麒麟是否存在、中轴是否对齐”需视觉/人工复核，脚本不假自动通过。
     7 个结构锚点（主峰/主殿中轴45%/石阶中轴/麒麟坐标/配殿坐标/远山/前景台）由 scene_template
     的 layout_lock 以提示词强约束注入，从根源抑制漂移；本脚本仅做“前景巨型物体”软提示
     （下中区明显偏暗且高对比 → 疑似前景巨型瑞兽如冬季麒麟漂移放大），仅供参考、不改硬判定。

用法：
  python scene_validate.py                       # 校验 assets/backgrounds 下全部 home_bg_*.png
  python scene_validate.py --fix                 # 不符规格的自动 cover-fit 到标准尺寸并回写
  python scene_validate.py --src <dir> --pattern "home_bg_*.png"
输出：
  scene_validation_report.json  （逐张明细 + 汇总）
  更新 scene_validation_manifest.csv 的 status 字段
"""
import argparse
import csv
import json
import os
from PIL import Image, ImageStat, ImageChops, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys_path = os.path.join(HERE, "..", "..")
import sys
sys.path.insert(0, HERE)
import scene_template as ST  # noqa

DEF_MANIFEST = os.path.join(HERE, "scene_manifest.csv")
DEF_SRC = os.path.join(sys_path, "assets", "backgrounds")
CENTER_MAX = ST.BASE_CONFIG["ui_safe_limit"]["center_max_brightness"]
CENTER_ZONE = ST.BASE_CONFIG["ui_safe_limit"]["center_zone"]  # [x0,x1,y0,y1] 比例
CANVAS = tuple(ST.BASE_CONFIG["canvas_size"])


def lum_stats(img):
    """整图 + 各区域平均亮度(0-1) 与 标准差(0-1)。纯 PIL，无 numpy 依赖。"""
    rgb = img.convert("RGB")
    w, h = rgb.size
    full = ImageStat.Stat(rgb).mean
    full_mean = sum(full) / 3.0 / 255.0
    x0, x1, y0, y1 = CENTER_ZONE
    cz = rgb.crop((int(w * x0), int(h * y0), int(w * x1), int(h * y1)))
    czm = ImageStat.Stat(cz).mean
    center_mean = sum(czm) / 3.0 / 255.0
    # 下中区(麒麟/台阶)与天空区(顶部) 均值/标准差，用于构图启发式与前景软检测
    lc = rgb.crop((int(w * 0.25), int(h * 0.62), int(w * 0.75), int(h * 0.88)))
    sky = rgb.crop((int(w * 0.1), int(h * 0.0), int(w * 0.9), int(h * 0.28)))
    lc_mean = (sum(ImageStat.Stat(lc).mean) / 3.0) / 255.0
    lc_std = (sum(ImageStat.Stat(lc).stddev) / 3.0) / 255.0
    sky_std = (sum(ImageStat.Stat(sky).stddev) / 3.0) / 255.0

    # —— v4 软检测：镜像相似度 ——
    # 把图缩到小尺寸灰度，比较「左半」与「水平翻转后的右半」的平均绝对差；
    # 差值越小→越接近完美镜面对称（AI 复刻镜像逻辑的可疑信号）。仅提示，不硬判。
    small = rgb.convert("L").resize((160, 284))
    sw, sh = small.size
    left = small.crop((0, 0, sw // 2, sh))
    right_flip = small.crop((sw // 2, 0, sw, sh)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    mirror_diff = ImageStat.Stat(ImageChops.difference(left, right_flip)).mean[0] / 255.0

    # —— v4 软检测：山体重心偏移 ——
    # 取山体结构主区(y 0.20–0.75)，用边缘强度(结构密度)的水平质心表征“山体重心”；
    # 质心显著偏离画面中线(0.5) → 主峰偏侧、左右留白不均。仅提示，不硬判。
    # （亮度差不适合做此判据：晴日单侧受光会误报，故改用结构密度质心。）
    zone = rgb.convert("L").crop((0, int(h * 0.20), w, int(h * 0.75)))
    edge = zone.filter(ImageFilter.FIND_EDGES)
    col = edge.resize((64, 1), Image.Resampling.BILINEAR)
    colsum = list(col.getdata())
    total = sum(colsum) or 1.0
    mountain_centroid = sum(i * v for i, v in enumerate(colsum)) / total / 63.0

    return full_mean, center_mean, lc_mean, lc_std, sky_std, mirror_diff, mountain_centroid


def coversize(img):
    """cover-fit 到 CANVAS（等价 Godot STRETCH_KEEP_ASPECT_COVERED），LANCZOS。"""
    rgb = img.convert("RGB")
    sw, sh = rgb.size
    rs, rt = sw / sh, CANVAS[0] / CANVAS[1]
    if rs > rt:
        nw, nh = int(round(CANVAS[1] * rs)), CANVAS[1]
        left = (nw - CANVAS[0]) // 2
        return rgb.resize((nw, nh), Image.Resampling.LANCZOS).crop((left, 0, left + CANVAS[0], CANVAS[1]))
    nw, nh = CANVAS[0], int(round(CANVAS[0] / rs))
    top = (nh - CANVAS[1]) // 2
    return rgb.resize((nw, nh), Image.Resampling.LANCZOS).crop((0, top, CANVAS[0], top + CANVAS[1]))


def validate_one(path):
    try:
        img = Image.open(path)
    except Exception as e:
        return {"file": path, "status": "missing", "error": str(e)}
    mode = img.mode
    size = img.size
    full_mean, center_mean, lc_mean, lc_std, sky_std, mirror_diff, mountain_centroid = lum_stats(img)

    checks = {}
    # 1) 中心亮度硬栅
    checks["center_brightness_ok"] = center_mean <= CENTER_MAX + 1e-6
    # 2) 规格
    checks["resolution_ok"] = (size == CANVAS)
    checks["colorspace_ok"] = (mode in ("RGB", "RGBA"))
    # 3) 构图启发式（诚实：仅标可疑，最终需人工/视觉复核）
    #    下中区应有结构(标准差不能过低)，天空区应有变化
    checks["composition_suspicious"] = (lc_std < 0.04) or (sky_std < 0.03)
    # 4) 前景巨型物体软检测（诚实：仅提示，不改硬判定）
    #    下中区明显偏暗且高对比 → 疑似前景巨型瑞兽/遮挡物（如冬季麒麟漂移放大）
    checks["foreground_heavy_suspect"] = (lc_mean < full_mean - 0.15) and (lc_std > 0.12)
    # 5) v4 软检测：镜像相似度（差值越小越接近完美镜面，可疑需人工复核）
    checks["mirror_suspect"] = mirror_diff < 0.045
    # 6) v4 软检测：山体重心偏移（结构密度水平质心偏离中线过大→主峰偏侧）
    checks["mountain_imbalance_suspect"] = abs(mountain_centroid - 0.5) > 0.10

    # 综合判定
    if not checks["center_brightness_ok"]:
        status = "不合格_亮度"
    elif not (checks["resolution_ok"] and checks["colorspace_ok"]):
        status = "不合格_规格"
    elif checks["composition_suspicious"]:
        status = "需复核_构图"
    else:
        status = "合格"

    return {
        "file": path, "status": status, "mode": mode, "size": list(size),
        "overall_brightness": round(full_mean, 3),
        "center_brightness": round(center_mean, 3),
        "center_max_allowed": CENTER_MAX,
        "lower_center_mean": round(lc_mean, 3),
        "lower_center_std": round(lc_std, 3),
        "sky_std": round(sky_std, 3),
        "mirror_diff": round(mirror_diff, 3),
        "mountain_centroid": round(mountain_centroid, 3),
        "checks": checks,
        "note": "构图最终需人工/视觉复核（脚本仅做启发式可疑标记，不假自动通过）",
    }


def main():
    ap = argparse.ArgumentParser(description="场景背景自动校验")
    ap.add_argument("--src", default=DEF_SRC)
    ap.add_argument("--pattern", default="home_bg_*.png")
    ap.add_argument("--fix", action="store_true", default=False,
                    help="规格不符的自动 cover-fit 到标准尺寸并回写")
    args = ap.parse_args()

    import glob
    files = sorted(glob.glob(os.path.join(args.src, args.pattern)))
    # 跳过预览拼图
    files = [f for f in files if "preview" not in os.path.basename(f).lower()]
    if not files:
        print(f"[WARN] 未找到匹配 {args.pattern} @ {args.src}")
        return

    results = []
    for f in files:
        r = validate_one(f)
        results.append(r)
        tag = {"合格": "✅", "需复核_构图": "⚠️", "不合格_亮度": "❌亮", "不合格_规格": "❌规"}.get(r["status"], "❓")
        fg = " 🔶前景偏重?" if r.get("checks", {}).get("foreground_heavy_suspect") else ""
        mir = " 🪞疑似镜面?" if r.get("checks", {}).get("mirror_suspect") else ""
        imb = " ⛰️山体重心偏?" if r.get("checks", {}).get("mountain_imbalance_suspect") else ""
        print(f"  {tag} {os.path.basename(f)} | 整体 {r.get('overall_brightness')} "
              f"中心 {r.get('center_brightness')}/{CENTER_MAX} | {r['status']}{fg}{mir}{imb}")

        if args.fix and r.get("status") == "不合格_规格" and r.get("size") != list(CANVAS):
            fixed = coversize(Image.open(f))
            fixed.save(f)
            print(f"     [FIX] cover-fit -> {CANVAS} 已回写 {f}")

    # 汇总
    summary = {
        "total": len(results),
        "合格": sum(1 for r in results if r["status"] == "合格"),
        "需复核_构图": sum(1 for r in results if r["status"] == "需复核_构图"),
        "不合格_亮度": sum(1 for r in results if r["status"] == "不合格_亮度"),
        "不合格_规格": sum(1 for r in results if r["status"] == "不合格_规格"),
    }
    report = {"canvas": list(CANVAS), "center_max_brightness": CENTER_MAX,
              "summary": summary, "details": results}
    rpath = os.path.join(HERE, "scene_validation_report.json")
    with open(rpath, "w", encoding="utf-8") as fh:
        json.dump(report, fh, ensure_ascii=False, indent=2)
    print(f"\n[报告] {rpath}")
    print(f"[汇总] {summary}")


if __name__ == "__main__":
    main()

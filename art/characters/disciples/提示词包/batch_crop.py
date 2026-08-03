# -*- coding: utf-8 -*-
"""
太玄宗门录 · 弟子立绘批量裁切头像脚本  (batch_crop.py)
=================================================================
从立绘中按「人脸检测动态裁切框」裁切头像，输出多尺寸标准头像，对齐 Godot 资源规范。

两种输入模式：
  1. 清单模式（默认）：读取 disciple_asset_manifest.csv，对每行立绘重跑人脸检测并裁切，
     头像写入「立绘所在目录/avatar/」子目录，回写 avatar_paths 列，并把
     固定坐标字段（crop_x/y/w/h）替换为动态检测字段：
        face_center_x, face_center_y, avatar_crop_x, avatar_crop_y,
        avatar_size, detect_method
  2. 目录模式（--dir）：直接裁切某目录下全部 *.png（用于样张/临时验证），
     并把检测结果打印/写入 <dir>/avatar/crop_report.csv 供人工抽检。

裁切逻辑全部委托 crop_lib（单一事实源），本脚本只负责 IO 与清单回写。

Usage:
  python batch_crop.py --manifest ../out/disciple_asset_manifest.csv
  python batch_crop.py --dir ../samples --sizes 128 256 512
"""

import argparse
import csv
import os
import sys

import crop_lib


def main():
    ap = argparse.ArgumentParser(description="太玄宗门录 弟子头像批量裁切（人脸检测动态裁切）")
    ap.add_argument("--manifest", default=None, help="disciple_asset_manifest.csv 路径（清单模式）")
    ap.add_argument("--base", default=None, help="清单模式：file_path 相对基准（默认=清单所在目录）")
    ap.add_argument("--dir", default=None, help="目录模式：直接裁切该目录全部 *.png")
    ap.add_argument("--sizes", type=int, nargs="+", default=[128, 256, 512], help="输出头像尺寸列表")
    ap.add_argument("--avatar-sub", default="avatar", help="头像输出子目录名（位于立绘目录内）")
    ap.add_argument("--conf", type=float, default=0.5, help="人脸检测置信阈值")
    args = ap.parse_args()

    sizes = tuple(sorted(set(args.sizes)))

    # ---- 目录模式 ----
    if args.dir:
        files = sorted([f for f in os.listdir(args.dir) if f.lower().endswith(".png")
                        and not f.lower().endswith(".import")])
        out_root = os.path.join(args.dir, args.avatar_sub)
        report_rows = []
        done, skip = 0, 0
        for f in files:
            src = os.path.join(args.dir, f)
            stem = os.path.splitext(f)[0]
            try:
                paths, meta = crop_lib.crop_avatars(src, out_root, stem, sizes)
            except Exception as e:  # noqa
                print(f"[WARN] 裁切失败 {f}: {e}", file=sys.stderr)
                skip += 1
                continue
            done += 1
            report_rows.append({
                "file": f,
                "face_center_x": meta["face_center_x"],
                "face_center_y": meta["face_center_y"],
                "avatar_crop_x": meta["avatar_crop_x"],
                "avatar_crop_y": meta["avatar_crop_y"],
                "avatar_size": meta["avatar_size"],
                "detect_method": meta["detect_method"],
                "avatar_256": paths.get("256", ""),
            })
        # 写抽检报告
        os.makedirs(out_root, exist_ok=True)
        rcols = ["file", "face_center_x", "face_center_y", "avatar_crop_x",
                 "avatar_crop_y", "avatar_size", "detect_method", "avatar_256"]
        with open(os.path.join(out_root, "crop_report.csv"), "w",
                  encoding="utf-8-sig", newline="") as rf:
            w = csv.DictWriter(rf, fieldnames=rcols)
            w.writeheader()
            for r in report_rows:
                w.writerow(r)
        print(f"[DONE] 目录模式裁切 {done} 张（跳过 {skip}），输出 {out_root}")
        print(f"       抽检报告：{os.path.join(out_root, 'crop_report.csv')}")
        return

    # ---- 清单模式 ----
    if not args.manifest or not os.path.exists(args.manifest):
        print("[FATAL] 请提供 --manifest 或 --dir", file=sys.stderr)
        sys.exit(1)
    base = args.base or os.path.dirname(os.path.abspath(args.manifest))
    rows = []
    updated = 0
    skip = 0
    with open(args.manifest, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        cols = list(reader.fieldnames)
        for r in reader:
            fp = r.get("file_path", "")
            if not fp:
                rows.append(r)
                continue
            if not os.path.isabs(fp):
                fp = os.path.join(base, fp)
            if not os.path.exists(fp):
                skip += 1
                rows.append(r)
                continue
            stem = os.path.splitext(os.path.basename(r["file_path"]))[0]
            portrait_dir = os.path.dirname(fp)
            avatar_out_dir = os.path.join(portrait_dir, args.avatar_sub)
            try:
                paths, meta = crop_lib.crop_avatars(fp, avatar_out_dir, stem, sizes)
            except Exception as e:  # noqa
                print(f"[WARN] 裁切失败 {stem}: {e}", file=sys.stderr)
                skip += 1
                rows.append(r)
                continue
            r["avatar_paths"] = "|".join(f"{k}:{v}" for k, v in paths.items())
            # 用动态检测字段覆盖/补充旧固定字段
            r["face_center_x"] = meta["face_center_x"]
            r["face_center_y"] = meta["face_center_y"]
            r["avatar_crop_x"] = meta["avatar_crop_x"]
            r["avatar_crop_y"] = meta["avatar_crop_y"]
            r["avatar_size"] = meta["avatar_size"]
            r["detect_method"] = meta["detect_method"]
            updated += 1
            rows.append(r)

    # 列顺序：移除旧固定字段，加入动态字段（保持清单向后兼容）
    for old in ("crop_x", "crop_y", "crop_w", "crop_h"):
        if old in cols:
            cols.remove(old)
    for new in ("face_center_x", "face_center_y", "avatar_crop_x",
                "avatar_crop_y", "avatar_size", "detect_method"):
        if new not in cols:
            cols.append(new)
    with open(args.manifest, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow(r)
    print(f"[DONE] 清单模式裁切 {updated} 张（跳过 {skip}），头像写入各立绘目录/avatar/，"
          f"清单已回写动态坐标字段（face_center_*/avatar_crop_*/avatar_size/detect_method）")


if __name__ == "__main__":
    main()

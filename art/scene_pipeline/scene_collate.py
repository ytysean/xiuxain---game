# -*- coding: utf-8 -*-
"""
太玄宗门录 · 场景背景拼图与归档 (scene_collate.py)  v1
======================================================
标准化输出层（对标图标管线输出归档）：
  1. 自动 4 合 1 预览拼图（2×2，标注季节），方便美术快速验收
  2. 输出 scene_godot_config.json（季节→亮度目标/色调叠层/文件名），
     游戏逻辑层直接读取切换：`load("res://ui/assets/backgrounds/home_bg_%s.png" % season)`
  3. 按 home_bg_{season}.png 规范命名归档（校验 assets/backgrounds 下文件齐备）

用法：
  python scene_collate.py
  python scene_collate.py --src <backgrounds_dir> --preview <预览输出路径>
"""
import argparse
import csv
import json
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys_path = os.path.join(HERE, "..", "..")
DEF_MANIFEST = os.path.join(HERE, "scene_manifest.csv")
DEF_SRC = os.path.join(sys_path, "assets", "backgrounds")
DEF_PREVIEW = os.path.join(HERE, "home_bg_seasons_preview.png")


def read_manifest(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def main():
    ap = argparse.ArgumentParser(description="场景背景拼图与归档")
    ap.add_argument("--src", default=DEF_SRC)
    ap.add_argument("--preview", default=DEF_PREVIEW)
    ap.add_argument("--manifest", default=DEF_MANIFEST)
    args = ap.parse_args()

    rows = read_manifest(args.manifest)
    # 按 scene 分组，取每 scene 的四季（当前仅 sect_gate）
    groups = {}
    for m in rows:
        groups.setdefault(m["scene_id"], []).append(m)

    godot = {"load_template": "res://ui/assets/backgrounds/home_bg_%s.png",
             "default": "spring", "scenes": {}}
    missing = []

    for sid, items in groups.items():
        seasons_sorted = sorted(items, key=lambda x: x["season"])
        cells = []
        season_map = {}
        for m in seasons_sorted:
            fp = os.path.join(args.src, m["out_name"])
            ok = os.path.exists(fp)
            if not ok:
                missing.append(m["out_name"])
            season_map[m["season"]] = {
                "file": m["out_name"],
                "season_label": m["season_label"],
                "brightness_target": float(m["brightness_target"]),
                "color_overlay": m["color_overlay"],
                "present": ok,
            }
            cells.append((m, fp))
        godot["scenes"][sid] = {"name": items[0]["scene_name"], "seasons": season_map}

        # 2×2 预览拼图（仅 sect_gate 当前有 4 季）
        if len(cells) >= 4:
            cell_w, cell_h = 480, 854
            sheet = Image.new("RGB", (cell_w * 2, cell_h * 2), (20, 30, 28))
            d = ImageDraw.Draw(sheet)
            for i, (m, fp) in enumerate(cells[:4]):
                if os.path.exists(fp):
                    im = Image.open(fp).convert("RGB").resize((cell_w, cell_h), Image.Resampling.LANCZOS)
                    x, y = (i % 2) * cell_w, (i // 2) * cell_h
                    sheet.paste(im, (x, y))
                    d.text((x + 10, y + 10), m["season_label"], fill=(244, 239, 227))
                    d.rectangle([x, y, x + cell_w - 1, y + cell_h - 1], outline=(200, 168, 106), width=2)
            os.makedirs(os.path.dirname(args.preview), exist_ok=True)
            sheet.save(args.preview)
            print(f"[预览] {args.preview} ({sheet.size})")

    gpath = os.path.join(HERE, "scene_godot_config.json")
    with open(gpath, "w", encoding="utf-8") as fh:
        json.dump(godot, fh, ensure_ascii=False, indent=2)
    print(f"[配置] {gpath}")
    if missing:
        print(f"[WARN] 缺失文件（需先生成）: {missing}")
    else:
        print("[归档] assets/backgrounds 下 home_bg_{{season}}.png 命名齐备")


if __name__ == "__main__":
    main()

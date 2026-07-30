# -*- coding: utf-8 -*-
"""按 center_prompts.json 的 slug 前缀, 把 ImageGen 自动命名文件重命名为 target。
用法: python match_centers.py [--dir icon/_centers] [--check]
  --check 只校验已存在的 target 四角透明 + 中心内容, 不重命名。
"""
import csv, json, os, glob
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
JSON_PATH = os.path.join(ROOT, "tools/icon_pipeline/center_prompts.json")


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=os.path.join(ROOT, "icon/_centers"))
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    entries = json.load(open(JSON_PATH, encoding="utf-8"))
    d = args.dir
    renamed = 0
    unmatched = []
    for e in entries:
        target = os.path.join(d, e["target"])
        if os.path.exists(target):
            continue
        # 找含 slug 的文件
        cands = [f for f in os.listdir(d)
                 if e["slug"] in f and f.lower().endswith(".png")]
        if not cands:
            unmatched.append(e["slug"])
            continue
        src = os.path.join(d, sorted(cands)[0])
        os.replace(src, target)
        renamed += 1
    print(f"重命名 {renamed} 张; 未匹配 slug 数: {len(unmatched)}")
    if unmatched:
        print("  未匹配:", unmatched)

    if args.check:
        print("\n--- 透明/内容校验 ---")
        bad = 0
        for e in entries:
            p = os.path.join(d, e["target"])
            if not os.path.exists(p):
                print(f"  [缺失] {e['target']}")
                bad += 1
                continue
            im = Image.open(p).convert("RGBA"); W, H = im.size; px = im.load()
            corners = [px[4, 4], px[W - 4, 4], px[4, H - 4], px[W - 4, H - 4]]
            ca = all(c[3] == 0 for c in corners)
            cx, cy = W // 2, H // 2; op = 0; tot = 0
            for y in range(cy - 220, cy + 220, 10):
                for x in range(cx - 220, cx + 220, 10):
                    tot += 1
                    if px[x, y][3] > 10:
                        op += 1
            if not ca or op / tot < 0.01:
                bad += 1
                print(f"  [异常] {e['target']} 角透明={ca} 中心不透明={op/tot:.2f}")
        print("异常数:", bad)


if __name__ == "__main__":
    main()

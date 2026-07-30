# -*- coding: utf-8 -*-
"""
图标整包光影凝合后处理 (icon_cohesion.py)
=========================================
对已完成合成的图标成品做轻度统一后处理，消除中心物各自 ImageGen 光照带来的零散感：
  1) 统一主光源方向：自左上(45°)叠加柔和顶光，给整包一致的光照方向感知。
  2) 轻度白平衡/对比度归一化：把各图偏色/亮度向整包目标均值拉近(弱强度)，不破坏原画。
仅作用于不透明像素；透明区不受影响。可逆(原始 PNG 可经 --batch 重合成还原)。

用法:
  python icon_cohesion.py --test  icon/_validation/test_tr_001.png icon/_validation/test_tr_024.png ...
       -> 对给定文件生成 *_coh.png 预览(不覆盖原图)
  python icon_cohesion.py --apply --root icon --backup icon/_validation/cohesion_backup
       -> 对 icon/ 下全部成品做凝合并覆盖(先备份)
"""
import os, sys, glob, argparse
import numpy as np
from PIL import Image

SIZE = 1024
# 顶光方向: 左上 45° 光源点
LIGHT_X, LIGHT_Y = int(SIZE * 0.28), int(SIZE * 0.28)
LIGHT_STRENGTH = 0.12      # 顶光叠加强度(保守)
GRADE_STRENGTH = 0.18      # 白平衡/对比度归一强度


def build_light_mask():
    """左上 45° 柔和顶光掩码(白, 越靠光源越亮, 右下趋暗)。"""
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    dist = np.sqrt((xx - LIGHT_X) ** 2 + (yy - LIGHT_Y) ** 2)
    maxd = np.sqrt((SIZE - LIGHT_X) ** 2 + (SIZE - LIGHT_Y) ** 2)
    # 0(远) -> 1(近光源)
    m = 1.0 - dist / maxd
    m = np.clip(m, 0, 1) ** 1.5
    return m.astype(np.float32)


LIGHT_MASK = build_light_mask()


def screen_blend(src, light, strength):
    """Screen 混合顶光(src/light 均为 0-255 float, light 单通道)。"""
    out = 255.0 - (255.0 - src) * (255.0 - light * strength) / 255.0
    return out


def cohesion_pass(rgba, target_mean=None):
    rgb = rgba[:, :, :3].astype(np.float32)
    al = rgba[:, :, 3]
    opaque = al > 10

    # --- 1) 顶光方向统一 ---
    for c in range(3):
        rgb[:, :, c] = screen_blend(rgb[:, :, c], LIGHT_MASK * 255.0, LIGHT_STRENGTH)

    # --- 2) 白平衡 + 对比度归一(弱) ---
    if target_mean is None:
        # 目标: 轻微暖中性, 亮度贴近当前图自身均值(只去偏色, 不强拉)
        m = rgb[opaque].reshape(-1, 3).mean(axis=0)
        target_mean = m
    else:
        m = rgb[opaque].reshape(-1, 3).mean(axis=0)
        # 把整图均值向全局 target 拉近
        shift = (target_mean - m) * GRADE_STRENGTH
        rgb[opaque] = np.clip(rgb[opaque] + shift[None, :], 0, 255)
        m = rgb[opaque].reshape(-1, 3).mean(axis=0)
    # 轻度对比度(围绕均值拉伸 1.05x)
    rgb[opaque] = np.clip((rgb[opaque] - m[None, :]) * 1.05 + m[None, :], 0, 255)

    out = np.zeros_like(rgba)
    out[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[:, :, 3] = al
    return out


def compute_global_target(root):
    means = []
    files = []
    for dp, dn, fn in os.walk(root):
        if any(w in dp for w in ("_bases", "_centers", "_validation", "_gen", "__trash")):
            continue
        for f in fn:
            if f.endswith(".png"):
                files.append(os.path.join(dp, f))
    for p in files[:120]:
        a = np.array(Image.open(p).convert("RGBA"))
        op = a[:, :, 3] > 10
        if op.sum() > 1000:
            means.append(a[op][:, :3].mean(axis=0))
    return np.array(means).mean(axis=0)


def process_file(path, target_mean, out_path=None, overwrite=False):
    a = np.array(Image.open(path).convert("RGBA"))
    res = cohesion_pass(a, target_mean)
    if overwrite:
        Image.fromarray(res).save(path)
        return path
    out = out_path or (path[:-4] + "_coh.png")
    Image.fromarray(res).save(out)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test", nargs="+", help="给定文件列表, 生成 _coh.png 预览")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--root", default="icon")
    ap.add_argument("--backup", default="icon/_validation/cohesion_backup")
    args = ap.parse_args()

    if args.test:
        for p in args.test:
            if not os.path.exists(p):
                print("[skip] 不存在:", p); continue
            out = process_file(p, None)
            print("预览:", out)
        return

    if args.apply:
        target = compute_global_target(args.root)
        print("全局目标均值(用于白平衡归一):", np.round(target, 1))
        os.makedirs(args.backup, exist_ok=True)
        files = []
        for dp, dn, fn in os.walk(args.root):
            if any(w in dp for w in ("_bases", "_centers", "_validation", "_gen", "__trash")):
                continue
            for f in fn:
                if f.endswith(".png"):
                    files.append(os.path.join(dp, f))
        done = 0
        for p in files:
            # 备份
            rel = os.path.relpath(p, args.root)
            bk = os.path.join(args.backup, rel)
            os.makedirs(os.path.dirname(bk), exist_ok=True)
            if not os.path.exists(bk):
                Image.open(p).save(bk)
            process_file(p, target, overwrite=True)
            done += 1
        print(f"凝合完成: {done} 张 (原图已备份至 {args.backup})")


if __name__ == "__main__":
    main()

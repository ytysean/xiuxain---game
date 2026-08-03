# -*- coding: utf-8 -*-
"""
弟子立绘 · Depth 深度代理图生成器（与 OpenPose 骨架同源）
========================================================
复用 gen_openpose_refs.py 的 UPPER / BASE_POSES / build_kp 坐标，
按人体「前-后」层次渲染灰度深度图（近=白 255，远=黑 0）：

  头/脸   235  (最前)
  躯干    220
  上臂    175
  前臂    150
  手      135
  大腿    155
  小腿    115
  背景      0  (最远)

用途：作为 ControlNet depth 模块的参考图，进一步锁定构图景深与人物前后层次，
降低同批次 90 张立绘的构图漂移概率（尤其背景层次、人物与背景的分离）。

与姿态锁的关系（分层约束，互不冲突）：
  - OpenPose 控制「体态/姿态」（XY 平面骨架）
  - Depth   控制「前后层次/景深」（Z 轴）
  - 两者参考图都由同一套骨架坐标生成，天然对齐，不互相打架。

命名：depth_{性格}_{性别}_{姿态}.png  （与 pose_{...} 三段式一致）
  性格键严格沿用 build_prompt_package.PERSONALITIES：
  chen/gu/wen/bao/jiao/huo2

输出目录：弟子立绘/depth/  （1024×1536，与立绘/姿态同分辨率）

用法：
  python gen_depth_refs.py            # 生成全部 36 张
  python gen_depth_refs.py --out DIR
  python gen_depth_refs.py --gender 女
  python gen_depth_refs.py --pers bao
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import gen_openpose_refs as G

W, H = G.W, G.H

# 每段肢体的深度值（近=大）。键为 POSE_PAIRS 的 (a,b) 索引对。
PAIRS = G.POSE_PAIRS
SEG_DEPTH = {
    (1, 2): 220, (1, 5): 220,          # 肩（躯干上缘）
    (2, 3): 175, (3, 4): 150,          # 右臂
    (5, 6): 175, (6, 7): 150,          # 左臂
    (1, 8): 220, (1, 11): 220,         # 躯干侧
    (8, 9): 155, (9, 10): 115,         # 右腿
    (11, 12): 155, (12, 13): 115,      # 左腿
    (2, 8): 220, (5, 11): 220, (8, 11): 220,  # 髋线/侧身躯干
}
JOINT_DEPTH = {0: 235, 1: 225, 2: 215, 5: 215, 3: 170, 6: 170,
               4: 135, 7: 135, 8: 210, 11: 210, 9: 150, 12: 150,
               10: 110, 13: 110, 14: 235, 15: 235, 16: 230, 17: 230}
HEAD_DEPTH = 235


def _head_center(kp, head_r):
    """取头中心（与 gen_openpose_refs._head 同算法）。"""
    if 0 in kp and 14 in kp and 15 in kp:
        cx = kp[0][0]
        cy = (kp[14][1] + kp[0][1]) // 2
        return (cx, cy), head_r
    return None, 0


def draw_depth(kp, halfbody, out_path, head_r=170, head_y=0, lw=16):
    """按骨架渲染平滑深度灰度图。"""
    img = Image.new("L", (W, H), 0)          # 背景=最远(黑)
    d = ImageDraw.Draw(img)
    pairs = PAIRS[:6] if halfbody else PAIRS

    # 头部位移副本（与 draw_pose 一致，保证头位置对齐）
    kp_h = dict(kp)
    for i in (0, 14, 15, 16, 17):
        if i in kp_h:
            x, y = kp_h[i]
            kp_h[i] = (x, y + head_y)

    # 肢体：粗线 + 深度值（亮度=近度）
    for (a, b) in pairs:
        if a in kp and b in kp:
            val = SEG_DEPTH.get((a, b), 150)
            d.line([kp[a], kp[b]], fill=val, width=lw + 14)
    # 关节：圆点深度
    for idx, pt in kp.items():
        if idx in (8, 9, 10, 11, 12, 13) and halfbody:
            continue
        val = JOINT_DEPTH.get(idx, 160)
        r = 22 if idx in (4, 7, 10, 13) else 26
        d.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r], fill=val)
    # 头部：填充椭圆（最前）
    center, r = _head_center(kp_h, head_r)
    if center:
        d.ellipse([center[0] - r * 0.92, center[1] - r * 0.92,
                   center[0] + r * 0.92, center[1] + r * 0.92], fill=HEAD_DEPTH)

    # 平滑化：深度图需要柔和过渡，否则 controlnet 会学到硬边
    img = img.filter(ImageFilter.GaussianBlur(radius=22))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path)
    return out_path


def main():
    ap = argparse.ArgumentParser(description="弟子立绘 Depth 深度代理图生成（与骨架同源）")
    ap.add_argument("--out", default="../弟子立绘/depth", help="Depth 参考图输出目录")
    ap.add_argument("--gender", default=None, choices=["男", "女"], help="只生成指定性别")
    ap.add_argument("--pers", default=None, choices=["chen", "gu", "wen", "bao", "jiao", "huo2"],
                    help="只生成指定性格")
    args = ap.parse_args()

    genders = [args.gender] if args.gender else list(G.GENDER_PARAMS.keys())
    n = 0
    for (pers, ptype), (base, hb) in G.BASE_POSES.items():
        if args.pers and pers != args.pers:
            continue
        for gender in genders:
            eff = G.GENDER_PARAMS[gender]
            # battle 女性回调已在 build_kp 内处理（与 pose 一致）
            kp, eff2 = G.build_kp(base, gender, ptype)
            fname = f"depth_{pers}_{gender}_{ptype}.png"
            out = os.path.join(args.out, fname)
            draw_depth(kp, hb, out, head_r=eff2["head_r"], head_y=eff2["head_y"], lw=eff2["lw"])
            print(f"[OK] {fname}  (halfbody={hb})")
            n += 1
    print(f"\n共生成 {n} 张 -> {os.path.abspath(args.out)}")


if __name__ == "__main__":
    main()

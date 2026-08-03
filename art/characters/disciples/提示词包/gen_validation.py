# -*- coding: utf-8 -*-
"""
弟子立绘 · 验证组试运行脚本  (gen_validation.py)
=================================================
消费 disciple_manifest.csv（身份层）+ prompts/disciple_00X_prompt.json（写死提示词），
逐弟子逐姿态出图 → 动态裁切头像 → 写 validation_manifest.csv（产出层）。

复用：
  - batch_generate.py 的 Backend（DryRun / ComfyUI / A1111），ControlNet 用 OpenPose 参考图
  - crop_lib.crop_avatars（人脸检测动态裁切，与 90 包同库）
  - build_prompt_package.py 的 STYLE/QUALITY/BG/NEGATIVE（与 90 包同源，不漂移）

提示词组合（每次出图确定性，无随机）：
  final_cn = STYLE_CN + 身份写死描述 + BG_BASE_CN + 姿态描述 + QUALITY_CN
  final_en = STYLE_EN + 身份写死描述 + BG_BASE_EN + 姿态描述 + QUALITY_EN

用法（带卡机器）：
  python gen_validation.py --backend dryrun                      # 本沙箱逻辑验证
  python gen_validation.py --backend comfyui --url http://127.0.0.1:8188
  python gen_validation.py --backend a1111   --url http://127.0.0.1:7860
  python gen_validation.py --only disciple_001 --backend comfyui  # 只跑单个弟子
"""
import argparse
import csv
import json
import os
import shutil
import sys
import time

# 同目录模块（batch_generate / crop_lib / build_prompt_package 均在 提示词包/）
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from batch_generate import (DryRunBackend, ComfyUIBackend, A1111Backend,
                            DEPTH_STRENGTH, IP_ADAPTER_STRENGTH)  # noqa
from crop_lib import crop_avatars  # noqa
import qc_lib  # noqa
import build_prompt_package as BPP  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
DEF_MANIFEST = os.path.join(HERE, "..", "弟子立绘", "disciple_manifest.csv")
DEF_PROMPTS = os.path.join(HERE, "..", "弟子立绘", "prompts")
DEF_POSE = os.path.join(HERE, "..", "弟子立绘", "pose")
DEF_DEPTH = os.path.join(HERE, "..", "弟子立绘", "depth")
DEF_REF = os.path.join(HERE, "..", "弟子立绘", "reference")
DEF_OUT = os.path.join(HERE, "..", "弟子立绘", "output", "v1")

# ControlNet 权重按性别微调（用户验收要点三：女版下调避免强行拉宽肩胯导致生硬）
# 男版维持默认 0.75 锁姿力度足够；女版 0.70 更柔，尤其广袖长裙角色不易穿模/畸变。
CN_STRENGTH = {"男": 0.75, "女": 0.70}


# ---------------------------------------------------------------------------
# 提示词组合（身份字段写死 → 自然语言，留 0 自由发挥空间）
# ---------------------------------------------------------------------------
def identity_cn(d):
    verb = d.get("weapon_verb", "手持")
    return (f"{d['gender']}{d['age_range']}，{d['temperament']}气质，{d['face_shape']}，"
            f"{d['hair_color']}{d['hair_style']}，身着{d['main_color']}{d['costume_type']}，"
            f"{verb}{d['weapon']}")


def identity_en(d):
    verb = d.get("weapon_verb", "holding")
    return (f"{d['gender']} {d['age_range']}, {d['temperament']} temperament, {d['face_shape']}, "
            f"{d['hair_color']} {d['hair_style']}, wearing {d['main_color']} {d['costume_type']}, "
            f"{verb} {d['weapon']}")


def compose(d, pose):
    cn = (BPP.STYLE_CN + "，" + identity_cn(d) + "，" + BPP.BG_BASE_CN + "，"
          + pose["desc_cn"] + "，" + BPP.QUALITY_CN)
    en = (BPP.STYLE_EN + ", " + identity_en(d) + ", " + BPP.BG_BASE_EN + ", "
          + pose["desc_en"] + ", " + BPP.QUALITY_EN)
    neg_cn = BPP.NEGATIVE_CN + ("，" + d["negative_extra_cn"] if d.get("negative_extra_cn") else "")
    neg_en = BPP.NEGATIVE_EN + (", " + d["negative_extra_en"] if d.get("negative_extra_en") else "")
    return cn, en, neg_cn, neg_en


# ---------------------------------------------------------------------------
# 清单读写
# ---------------------------------------------------------------------------
def read_manifest(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def write_manifest(path, rows, cols):
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow(r)


def load_prompt(prompts_dir, role_id):
    p = os.path.join(prompts_dir, f"{role_id}_prompt.json")
    with open(p, encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="弟子验证组试产（消费 disciple_manifest + prompts）")
    ap.add_argument("--backend", default="dryrun", choices=["dryrun", "comfyui", "a1111"])
    ap.add_argument("--url", default="http://127.0.0.1:8188")
    ap.add_argument("--manifest", default=DEF_MANIFEST)
    ap.add_argument("--prompts-dir", default=DEF_PROMPTS)
    ap.add_argument("--pose-dir", default=DEF_POSE)
    ap.add_argument("--depth-dir", default=DEF_DEPTH)
    ap.add_argument("--ref-dir", default=DEF_REF)
    ap.add_argument("--out", default=DEF_OUT)
    ap.add_argument("--no-crop", dest="crop", action="store_false", default=True)
    ap.add_argument("--avatar-sizes", type=int, nargs="+", default=[128, 256, 512])
    ap.add_argument("--only", default=None, help="只跑指定 role_id")
    ap.add_argument("--seed", type=int, default=20260730)
    ap.add_argument("--mark", action="store_true", default=True,
                    help="真实后端运行时把 disciple_manifest 状态置为 生成中（dryrun 不生效）")
    args = ap.parse_args()

    rows = read_manifest(args.manifest)
    os.makedirs(args.out, exist_ok=True)

    if args.backend == "dryrun":
        backend = DryRunBackend(args.out)
    elif args.backend == "comfyui":
        backend = ComfyUIBackend(args.url)
    else:
        backend = A1111Backend(args.url)
    vrows = []
    seq = 0

    for m in rows:
        role_id = m["role_id"]
        if args.only and role_id != args.only:
            continue
        if m.get("status", "") in ("已验收",):
            print(f"[SKIP] {role_id} 状态=已验收")
            continue
        try:
            d = load_prompt(args.prompts_dir, role_id)
        except FileNotFoundError:
            print(f"[WARN] {role_id} 缺少 prompts JSON，跳过", file=sys.stderr)
            continue

        if args.mark and args.backend != "dryrun":
            m["status"] = "生成中"

        # 性别专属姿态 + Depth + IP-Adapter 两遍式
        gender = (m.get("gender") or d.get("gender") or "男")
        pers = d.get("personality", "")
        # 先跑 stand（建立脸参考），再跑其他姿态（复用脸参考保证同角色一致）
        pose_items = sorted(d["poses"].items(), key=lambda kv: (kv[0] != "stand", kv[0]))
        face_ref = None
        for pose_id, pose in pose_items:
            t0 = time.time()
            cn, en, neg_cn, neg_en = compose(d, pose)
            ptype = pose.get("pose_type", pose_id)
            pose_fname = f"pose_{pers}_{gender}_{ptype}.png" if pers else ""
            cn_img = os.path.join(args.pose_dir, pose_fname) if pose_fname else ""
            if not (cn_img and os.path.exists(cn_img)):
                print(f"[WARN] {role_id}/{pose_id} 缺 OpenPose 参考图 {pose_fname}，跳过 ControlNet",
                      file=sys.stderr)
                cn_img = ""
            depth_fname = f"depth_{pers}_{gender}_{ptype}.png" if pers else ""
            depth_img = os.path.join(args.depth_dir, depth_fname) if depth_fname else ""
            if not (depth_img and os.path.exists(depth_img)):
                print(f"[WARN] {role_id}/{pose_id} 缺 Depth 参考图 {depth_fname}，跳过 Depth",
                      file=sys.stderr)
                depth_img = ""
            strength = CN_STRENGTH.get(gender, 0.75)
            # IP-Adapter：已有脸参考则复用（非 stand 姿态用 stand 的脸）
            ip_img = face_ref if face_ref else None
            ip_strength = IP_ADAPTER_STRENGTH if ip_img else ""
            img = backend.generate(cn, en, neg_cn, cn_img, args.seed + seq,
                                   controlnet_strength=strength,
                                   depth_image=depth_img or None, depth_strength=DEPTH_STRENGTH,
                                   ip_adapter_image=ip_img,
                                   ip_adapter_strength=ip_strength or 0)
            cost = round(time.time() - t0, 2)

            fname = f"{role_id}_{pose_id}_v1.png"
            fpath = os.path.join(args.out, fname)
            avatar_paths_str = ""
            crop_meta = {"face_center_x": "", "face_center_y": "", "avatar_crop_x": "",
                         "avatar_crop_y": "", "avatar_size": "", "detect_method": "none"}
            qc_crop_l, qc_crop_r, qc_face_l, qc_face_r = ("skip", "dryrun", "skip", "dryrun")
            status = "ok" if img is not None else ("dryrun" if args.backend == "dryrun" else "fail")
            if img is not None:
                with open(fpath, "wb") as fh:
                    fh.write(img)
                if args.crop:
                    stem = os.path.splitext(fname)[0]
                    avatar_dir = os.path.join(args.out, f"{stem}_avatar")
                    res = crop_avatars(fpath, avatar_dir, stem, tuple(args.avatar_sizes))
                    if res:
                        paths, meta = res
                        avatar_paths_str = "|".join(f"{k}:{v}" for k, v in paths.items())
                        crop_meta = meta
                        # 以 stand 姿态的 256 头像作为该角色脸参考
                        if pose_id == "stand":
                            os.makedirs(args.ref_dir, exist_ok=True)
                            ref_path = os.path.join(args.ref_dir, f"{role_id}_face_ref.png")
                            if "256" in paths and os.path.exists(paths["256"]):
                                shutil.copy2(paths["256"], ref_path)
                                face_ref = ref_path
                                print(f"[REF] {role_id}_face_ref.png")
                        # 质检软检测（仅预警，不硬拦截）
                        try:
                            if os.path.exists(fpath):
                                qc_crop_l, qc_crop_r, qc_face_l, qc_face_r = qc_lib.qc_image_path(fpath, crop_meta)
                        except Exception as e:  # noqa
                            qc_crop_l, qc_crop_r, qc_face_l, qc_face_r = ("skip", f"qc_err:{e}", "skip", f"qc_err:{e}")

            vrows.append({
                "role_id": role_id, "name": d.get("name", ""), "pose_id": pose_id,
                "file_path": fpath, "avatar_paths": avatar_paths_str,
                "gender": gender, "temperament": d.get("temperament", ""),
                "costume_type": d.get("costume_type", ""), "main_color": d.get("main_color", ""),
                "weapon": d.get("weapon", ""), "pose_ref": cn_img,
                "depth_ref": depth_img, "depth_strength": DEPTH_STRENGTH,
                "ip_ref": (ip_img or ""), "ip_strength": (ip_strength or ""),
                "cn_strength": strength, "seed": args.seed + seq,
                "face_center_x": crop_meta["face_center_x"], "face_center_y": crop_meta["face_center_y"],
                "avatar_crop_x": crop_meta["avatar_crop_x"], "avatar_crop_y": crop_meta["avatar_crop_y"],
                "avatar_size": crop_meta["avatar_size"], "detect_method": crop_meta["detect_method"],
                "qc_crop": f"{qc_crop_l}:{qc_crop_r}", "qc_face": f"{qc_face_l}:{qc_face_r}",
                "backend": args.backend, "status": status, "time_cost_s": cost,
            })
            seq += 1

    if hasattr(backend, "close"):
        backend.close()

    vcols = ["role_id", "name", "pose_id", "file_path", "avatar_paths", "gender", "temperament",
             "costume_type", "main_color", "weapon", "pose_ref", "depth_ref", "depth_strength",
             "ip_ref", "ip_strength", "cn_strength", "seed",
             "face_center_x", "face_center_y", "avatar_crop_x", "avatar_crop_y",
             "avatar_size", "detect_method", "qc_crop", "qc_face",
             "backend", "status", "time_cost_s"]
    vpath = os.path.join(args.out, "validation_manifest.csv")
    write_manifest(vpath, vrows, vcols)

    # 回写 disciple_manifest 状态（仅真实后端 + --mark）
    if args.mark and args.backend != "dryrun":
        write_manifest(args.manifest, rows, list(rows[0].keys()) if rows else [])

    print(f"[DONE] 验证组 {len(vrows)} 条 | 后端={args.backend} | 清单={vpath}")


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
"""
太玄宗门录 · 弟子立绘质检软检测库  (qc_lib.py)
=================================================
两项软检测，仅预警、不硬拦截：

  1. qc_crop_consistency  —— 头像裁切一致性
     基于 crop_lib.compute_avatar_crop 产出的裁切元数据（face_center_x/y、
     detect_method），判断脸中心归一化位置是否落在预期带内；越带即预警，
     避免后续裁头像出现偏移/穿帮。

  2. qc_face_integrity    —— 人脸完整性预警
     复用 crop_lib 的 OpenCV DNN SSD 检测器（与裁切系统同源），检测：
       - 无人脸（0 face）→ 标记 no_face，疑似崩坏/无脸
       - 多脸（>1）      → 标记 multi_face，疑似残影/双脸
       - 主脸面积占比过小 → 标记 face_too_small，疑似脸过小/崩坏
       - 主脸中心偏离预期带 → 标记 face_offcenter

所有检测返回 (level, reason[, detail])，level ∈ {ok, warn, fail, skip}。
fail 仅作软标记，调用方不得据此阻断产出。

依赖：crop_lib（间接依赖 cv2 / numpy / PIL）。
"""
import os

import numpy as np
import cv2  # noqa: F401  (crop_lib 间接依赖；此处显式声明便于环境自检)
import crop_lib
from PIL import Image


# 头像裁切一致性：脸中心归一化位置预期带（与 batch_generate 的「构图锁」同源）
#   x：居中略偏皆可（检测器自适应），仅拦极端偏移
#   y：头在画面上部（头顶留白 ~10%、头高占图高 22–28%）
CROP_X_BAND = (0.30, 0.70)
CROP_Y_BAND = (0.10, 0.35)
FACE_AREA_MIN_RATIO = 0.06   # 主脸面积 / 图面积 下限，过低判 too_small


def qc_crop_consistency(img_w, img_h, crop_meta):
    """基于裁切元数据做一致性软检测。

    入参 crop_meta: dict，含 face_center_x / face_center_y / detect_method。
    返回 (level, reason)：level ∈ {ok, warn, skip}。
    """
    if not crop_meta or crop_meta.get("detect_method") in (None, "none", ""):
        return ("skip", "未裁切（dryrun/关闭）")
    fcx = crop_meta.get("face_center_x")
    fcy = crop_meta.get("face_center_y")
    if not fcx or not fcy:
        return ("warn", "缺 face_center 元数据")
    nx = fcx / img_w if img_w else 0
    ny = fcy / img_h if img_h else 0
    msgs = []
    if not (CROP_X_BAND[0] <= nx <= CROP_X_BAND[1]):
        msgs.append(f"脸水平偏移 nx={nx:.2f} 超出带{CROP_X_BAND}")
    if not (CROP_Y_BAND[0] <= ny <= CROP_Y_BAND[1]):
        msgs.append(f"脸垂直偏移 ny={ny:.2f} 超出带{CROP_Y_BAND}")
    if msgs:
        return ("warn", "；".join(msgs))
    return ("ok", "")


def _all_faces(img_np, conf_threshold=0.5):
    """返回所有达标人脸 list[(conf,x1,y1,x2,y2)]；复用 crop_lib 单例检测器。"""
    net = crop_lib.load_detector()
    h, w = img_np.shape[:2]
    blob = cv2.dnn.blobFromImage(cv2.resize(img_np, (300, 300)), 1.0, (300, 300),
                                 (104.0, 177.0, 123.0))
    net.setInput(blob)
    dets = net.forward()
    out = []
    for i in range(dets.shape[2]):
        conf = float(dets[0, 0, i, 2])
        if conf < conf_threshold:
            continue
        out.append((conf,
                    int(dets[0, 0, i, 3] * w), int(dets[0, 0, i, 4] * h),
                    int(dets[0, 0, i, 5] * w), int(dets[0, 0, i, 6] * h)))
    return out


def qc_face_integrity(img_np, conf_threshold=0.5):
    """基于 DNN 检测器做人脸完整性软检测。

    入参 img_np: RGB numpy（H×W×3）。
    返回 (level, reason, detail)：detail 含 face_count / best_conf / area_ratio / bbox。
    """
    try:
        dets = _all_faces(img_np, conf_threshold)
    except Exception as e:  # noqa
        return ("skip", f"检测器不可用: {e}", {})
    h, w = img_np.shape[:2]
    area = h * w
    if not dets:
        return ("fail", "未检测到人脸（可能崩坏/无脸），人工复核", {"face_count": 0})
    best = max(dets, key=lambda d: d[0])
    fx1, fy1, fx2, fy2 = best[1], best[2], best[3], best[4]
    face_area = (fx2 - fx1) * (fy2 - fy1)
    ratio = face_area / area if area else 0
    msgs = []
    if len(dets) > 1:
        msgs.append(f"检测到 {len(dets)} 张脸（疑似多脸/残影）")
    if ratio < FACE_AREA_MIN_RATIO:
        msgs.append(f"主脸占比 {ratio:.2%} 过小（疑似脸过小/崩坏）")
    fcx, fcy = (fx1 + fx2) / 2, (fy1 + fy2) / 2
    nx, ny = fcx / w, fcy / h
    if not (CROP_X_BAND[0] <= nx <= CROP_X_BAND[1]):
        msgs.append(f"主脸水平偏移 nx={nx:.2f}")
    if not (CROP_Y_BAND[0] <= ny <= CROP_Y_BAND[1]):
        msgs.append(f"主脸垂直偏移 ny={ny:.2f}")
    if not msgs:
        level = "ok"
    elif len(dets) > 1 or ratio < FACE_AREA_MIN_RATIO:
        level = "fail"
    else:
        level = "warn"
    return (level, "；".join(msgs),
            {"face_count": len(dets), "best_conf": round(best[0], 3),
             "area_ratio": round(ratio, 4), "bbox": [fx1, fy1, fx2, fy2]})


def qc_image_path(img_path, crop_meta):
    """对单张已出图做两项 QC（统一入口，供 gen_validation / batch_generate 调用）。

    入参 img_path: 立绘 PNG 绝对路径；crop_meta: 该图裁切元数据（可为空 dict）。
    返回 (crop_level, crop_reason, face_level, face_reason)。
    """
    try:
        im = Image.open(img_path).convert("RGB")
    except Exception as e:  # noqa
        return ("skip", f"无法读取图像: {e}", "skip", f"无法读取图像: {e}")
    img_w, img_h = im.size
    arr = np.array(im)
    crop_level, crop_reason = qc_crop_consistency(img_w, img_h, crop_meta)
    face_level, face_reason, _ = qc_face_integrity(arr)
    return (crop_level, crop_reason, face_level, face_reason)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        p = sys.argv[1]
        meta = crop_lib.crop_avatars.__globals__  # noqa
        # 仅演示：用 crop_lib 拿裁切元数据再 QC
        from crop_lib import crop_avatars
        res = crop_avatars(p, os.path.dirname(p), "qc_demo", (256,))
        _, cmeta = res
        print("crop_meta:", cmeta)
        print("qc:", qc_image_path(p, cmeta))

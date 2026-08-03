# -*- coding: utf-8 -*-
"""
太玄宗门录 · 立绘头像动态裁切核心库  (crop_lib.py)
=================================================
单一事实源：人脸检测 -> 动态裁切框 -> 多尺寸头像。
batch_crop.py（独立重裁）与 batch_generate.py（出图后自动裁切）共用本库，
禁止在各自脚本内重复实现检测/兜底逻辑。

检测器：OpenCV DNN SSD 人脸检测器（res10_300x300_ssd_iter_140000）。
       相比 Haar 级联：每图稳定返回 1 个高置信主脸，无多脸误检；
       相比 InsightFace：无需联网下载 buffalo_l 模型，本沙箱可离线运行。

设计要点（解决固定坐标切到半张脸的根因）：
   立绘头部位置不统一（有的偏上/偏下/缩放过大），固定坐标必切残。
   本库以「检测框 + 自适应留白」为中心计算裁切框：
     - 头顶留 0.30×脸高余量（护住发际/发髻）
     - 下巴下留 1.15×脸高余量（护住颈/肩）
     - 左右各留 0.60×脸宽余量（护住鬓发）
   裁切框恒为正方形，脸中心落在框内上部约 1/3 处 ——
   既保证头完整居中，又统一了不同立绘的头像观感。

fallback：检测失败（无 >= conf 的脸）时，回落到「上中构图」合理坐标，
   并在 manifest 标记 detect_method=fallback_upper_center，便于人工抽检。

模型路径：默认 C:/opencv_face_detector/；若提供环境变量 CV2_FACE_MODEL_DIR 则优先。
"""

import os

import cv2
import numpy as np
from PIL import Image

# ---------------------------------------------------------------------------
# 检测器加载（懒加载，进程内单例）
# ---------------------------------------------------------------------------
# 默认模型目录；用环境变量可覆盖（便于换机器/模型版本）
_MODEL_DIR = os.environ.get("CV2_FACE_MODEL_DIR", "C:/opencv_face_detector")
PROTOTXT = os.path.join(_MODEL_DIR, "deploy.prototxt")
CAFFEMODEL = os.path.join(_MODEL_DIR, "res10_300x300_ssd_iter_140000_fp16.caffemodel")

_net = None


def load_detector():
    """加载 OpenCV DNN 人脸检测器（仅首次调用时加载）。"""
    global _net
    if _net is not None:
        return _net
    if not os.path.exists(PROTOTXT) or not os.path.exists(CAFFEMODEL):
        raise FileNotFoundError(
            f"[crop_lib] 人脸检测模型缺失：\n  {PROTOTXT}\n  {CAFFEMODEL}\n"
            f"请确认 CV2_FACE_MODEL_DIR 指向包含 deploy.prototxt 与 "
            f"res10_300x300_ssd_iter_140000_fp16.caffemodel 的目录。"
        )
    _net = cv2.dnn.readNetFromCaffe(PROTOTXT, CAFFEMODEL)
    return _net


# ---------------------------------------------------------------------------
# 人脸检测
# ---------------------------------------------------------------------------
def detect_face(img_np, conf_threshold=0.5):
    """对 RGB numpy 图像做人脸检测。

    返回 (confidence, x1, y1, x2, y2) 或 None（未检测到达标人脸）。
    取置信度最高的一张脸作为主脸。
    """
    net = load_detector()
    h, w = img_np.shape[:2]
    blob = cv2.dnn.blobFromImage(
        cv2.resize(img_np, (300, 300)),
        1.0,
        (300, 300),
        (104.0, 177.0, 123.0),
    )
    net.setInput(blob)
    detections = net.forward()

    best = None
    for i in range(detections.shape[2]):
        confidence = float(detections[0, 0, i, 2])
        if confidence < conf_threshold:
            continue
        x1 = int(detections[0, 0, i, 3] * w)
        y1 = int(detections[0, 0, i, 4] * h)
        x2 = int(detections[0, 0, i, 5] * w)
        y2 = int(detections[0, 0, i, 6] * h)
        if best is None or confidence > best[0]:
            best = (confidence, x1, y1, x2, y2)
    return best


# ---------------------------------------------------------------------------
# 动态裁切框计算
# ---------------------------------------------------------------------------
def compute_avatar_crop(img_w, img_h, det, pad_top=0.30, pad_bottom=1.15, pad_side=0.60):
    """根据检测结果计算头像裁切框（源图坐标，正方形）。

    det: (conf, x1, y1, x2, y2) 或 None（触发 fallback）。
    返回 dict（与 manifest 新 schema 对齐）：
        face_center_x, face_center_y, avatar_crop_x, avatar_crop_y,
        avatar_size, detect_method
    """
    if det is None:
        # fallback：上中构图。脸中心放在图像宽中、高约 30% 处，
        # 取头肩区域（高度约为图高 55%，宽度不超图宽 90%）。
        cx = int(img_w * 0.5)
        cy = int(img_h * 0.30)
        size = int(min(img_w * 0.9, img_h * 0.55))
        left = max(0, cx - size // 2)
        top = max(0, cy - int(size * 0.18))  # 略上移，头条在上方
        size = min(size, img_w - left, img_h - top)
        return {
            "face_center_x": cx,
            "face_center_y": cy,
            "avatar_crop_x": left,
            "avatar_crop_y": top,
            "avatar_size": size,
            "detect_method": "fallback_upper_center",
        }

    conf, x1, y1, x2, y2 = det
    face_w = x2 - x1
    face_h = y2 - y1
    fcx = (x1 + x2) // 2
    fcy = (y1 + y2) // 2

    top = y1 - int(face_h * pad_top)
    bottom = y2 + int(face_h * pad_bottom)
    raw_h = bottom - top
    # 方形：边长取「身高需求」与「脸宽需求」较大者
    side_half = max(raw_h / 2.0, face_w / 2.0 + face_w * pad_side)
    size = int(round(side_half * 2))
    left = int(round(fcx - side_half))
    top = int(round(top))

    # 钳制到图像边界；若触边导致尺寸变小，保持左上角不变（脸仍在框内上部）
    left = max(0, left)
    top = max(0, top)
    size = min(size, img_w - left, img_h - top)
    # 二次防御：size 仍可能为 0（极端异常图），直接给整图中心大方块
    if size <= 0:
        size = min(img_w, img_h)
        left = (img_w - size) // 2
        top = int(img_h * 0.10)

    return {
        "face_center_x": fcx,
        "face_center_y": fcy,
        "avatar_crop_x": left,
        "avatar_crop_y": top,
        "avatar_size": size,
        "detect_method": "dnn_ssd",
    }


# ---------------------------------------------------------------------------
# 裁切执行（多尺寸）
# ---------------------------------------------------------------------------
def crop_avatars(src_path, out_dir, stem, sizes=(128, 256, 512)):
    """从单张立绘动态裁切多尺寸头像。

    返回 (avatar_paths_dict, crop_meta_dict)。
    avatar_paths_dict: {"128": abs, "256": abs, "512": abs}
    crop_meta_dict: compute_avatar_crop 的结果（供 manifest 回写）。
    """
    im = Image.open(src_path).convert("RGBA")
    img_w, img_h = im.width, im.height
    arr = np.array(im.convert("RGB"))

    det = detect_face(arr)
    meta = compute_avatar_crop(img_w, img_h, det)

    sx = meta["avatar_crop_x"]
    sy = meta["avatar_crop_y"]
    ss = meta["avatar_size"]
    # 源裁切区域（钳制，绝对安全）
    box = (max(0, sx), max(0, sy), min(img_w, sx + ss), min(img_h, sy + ss))
    region = im.crop(box)

    os.makedirs(out_dir, exist_ok=True)
    out_paths = {}
    for size in sizes:
        s = int(size)
        resized = region.resize((s, s), Image.LANCZOS)
        fname = f"{stem}_avatar_{s}.png"
        fpath = os.path.join(out_dir, fname)
        resized.save(fpath)
        out_paths[str(s)] = fpath
    del im
    return out_paths, meta


if __name__ == "__main__":
    # 自检：对单图打印检测 + 裁切框
    import sys

    if len(sys.argv) > 1:
        p = sys.argv[1]
        imt = Image.open(p).convert("RGBA")
        d = detect_face(np.array(imt.convert("RGB")))
        print("det:", d)
        print("crop:", compute_avatar_crop(imt.width, imt.height, d))

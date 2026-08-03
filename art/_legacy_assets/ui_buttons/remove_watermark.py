#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Remove "AI生成 WORKBUDDY" platform watermark from bottom-right corner of UI assets.

Strategy:
  1. Extract a binary text mask from a high-contrast 1024x1024 reference
     (sq_base_N.png) where the watermark is clearly visible.
  2. For each target image, scale the mask by target_height / 1024 and align
     it to the bottom-right corner using margins that scale by the same factor.
  3. Dilate the mask generously (17x17 kernel, radius 8) to cover anti-aliasing
     fringe and any subtle text shadow/glow.
  4. Inpaint masked pixels with OpenCV TELEA for robust text removal.
  5. Preserve the original image mode (RGB/RGBA).

Backups of the original watermarked files are kept in png/_watermarked/.
"""
from __future__ import annotations
import os
import glob
import shutil
from PIL import Image
import numpy as np
import cv2

ROOT = r"E:\Xiuxian\taixuanzongmenlu\美术资源\ui_buttons"
PNG_DIR = os.path.join(ROOT, "png")
BACKUP_DIR = os.path.join(PNG_DIR, "_watermarked")
REF_NAME = "sq_base_N.png"
REF_HEIGHT = 1024  # reference height for watermark scaling

# Watermark tight bounding-box in the 1024x1024 reference.
# Measured from sq_base_N.png: full coords x=903..1013, y=964..1013.
RIGHT_INNER = 11   # px from right edge to watermark right side
RIGHT_OUTER = 121  # px from right edge to watermark left side
BOTTOM_INNER = 11  # px from bottom edge to watermark bottom side
BOTTOM_OUTER = 60  # px from bottom edge to watermark top side

# Extra padding around the tight bbox for the reference mask crop.
REF_PAD = 10

# Heavy dilation + inpaint to fully erase the watermark (including soft fringe).
DILATE_KERNEL = 17
DILATE_ITER = 1
INPAINT_RADIUS = 8
INPAINT_METHOD = cv2.INPAINT_TELEA


def extract_reference_mask(ref_path: str) -> np.ndarray:
    """Return a binary mask (H, W) of the watermark text shape."""
    img = Image.open(ref_path).convert("RGBA")
    arr = np.array(img)
    h, w = arr.shape[:2]

    x0 = w - RIGHT_OUTER - REF_PAD
    x1 = w - RIGHT_INNER + REF_PAD
    y0 = h - BOTTOM_OUTER - REF_PAD
    y1 = h - BOTTOM_INNER + REF_PAD
    roi = arr[y0:y1, x0:x1]

    gray = cv2.cvtColor(roi[:, :, :3], cv2.COLOR_RGB2GRAY)
    med = np.median(gray)
    # Bright text on dark plate
    mask = (gray.astype(np.float32) - med) > 22

    mask_u8 = mask.astype(np.uint8) * 255
    return mask_u8


def remove_watermark_from_image(img: Image.Image, mask_ref: np.ndarray) -> Image.Image:
    """Remove watermark and return image in the same mode as input."""
    original_mode = img.mode
    arr = np.array(img.convert("RGBA"))
    h, w = arr.shape[:2]
    scale = h / REF_HEIGHT

    # Target watermark bounding box, scaled by image height
    x0 = int(w - RIGHT_OUTER * scale)
    x1 = int(w - RIGHT_INNER * scale)
    y0 = int(h - BOTTOM_OUTER * scale)
    y1 = int(h - BOTTOM_INNER * scale)

    # Clamp to image bounds (handles very small images safely)
    x0, x1 = max(0, x0), min(w, x1)
    y0, y1 = max(0, y0), min(h, y1)
    if x1 <= x0 or y1 <= y0:
        return img

    roi_w, roi_h = x1 - x0, y1 - y0
    mask = cv2.resize(mask_ref, (roi_w, roi_h), interpolation=cv2.INTER_NEAREST)
    mask_bin = mask > 127

    if not mask_bin.any():
        return img

    # Dilate to cover fringe
    kernel = np.ones((DILATE_KERNEL, DILATE_KERNEL), np.uint8)
    mask_u8 = (mask_bin.astype(np.uint8)) * 255
    mask_u8 = cv2.dilate(mask_u8, kernel, iterations=DILATE_ITER)

    roi_rgb = arr[y0:y1, x0:x1, :3]
    inpainted = cv2.inpaint(roi_rgb, mask_u8, INPAINT_RADIUS, INPAINT_METHOD)
    arr[y0:y1, x0:x1, :3] = inpainted

    # Keep alpha consistent with surrounding unmasked pixels
    roi_a = arr[y0:y1, x0:x1, 3]
    unmasked_a = roi_a[mask_u8 == 0]
    if len(unmasked_a):
        med_a = int(np.median(unmasked_a))
        roi_a[mask_u8 > 127] = med_a
    arr[y0:y1, x0:x1, 3] = roi_a

    out = Image.fromarray(arr)
    if original_mode != "RGBA":
        out = out.convert(original_mode)
    return out


def main() -> None:
    ref_path = os.path.join(PNG_DIR, REF_NAME)
    if not os.path.exists(ref_path):
        raise FileNotFoundError(f"Reference image not found: {ref_path}")

    mask_ref = extract_reference_mask(ref_path)
    print(f"Reference mask size: {mask_ref.shape}, text pixels: {mask_ref.sum() // 255}")

    os.makedirs(BACKUP_DIR, exist_ok=True)
    paths = sorted(glob.glob(os.path.join(PNG_DIR, "*.png")))
    processed = 0
    skipped = []

    for p in paths:
        name = os.path.basename(p)
        if name.lower() == "contact_sheet_ai.png":
            skipped.append(name)
            continue

        backup_path = os.path.join(BACKUP_DIR, name)
        if not os.path.exists(backup_path):
            shutil.copy2(p, backup_path)

        img = Image.open(p)
        clean = remove_watermark_from_image(img, mask_ref)
        clean.save(p)
        processed += 1
        print(f"[OK] {name}")

    print(f"\nProcessed: {processed}")
    print(f"Backed up to: {BACKUP_DIR}")
    if skipped:
        print(f"Skipped: {', '.join(skipped)}")


if __name__ == "__main__":
    main()

import os
import cv2
import numpy as np
from PIL import Image

SRC_DIR = r"E:\Xiuxian\taixuanzongmenlu\art\ui\buttons\_gen\res_icons"
DST_DIR = r"E:\Xiuxian\taixuanzongmenlu\art\ui\buttons"
LEGACY_DIR = r"E:\Xiuxian\taixuanzongmenlu\art\ui\buttons\_legacy_local"

# Order matches generation sequence
PAIRS = [
    ("写实国漫油画风修真UI组件_深青灰哑光金属底板___1E2B_2026-08-02T14-45-43.png", "res_lingshi.png"),
    ("写实国漫油画风修真UI组件_深青灰哑光金属底板___1E2B_2026-08-02T14-46-25.png", "res_lingqi.png"),
    ("写实国漫油画风修真UI组件_深青灰哑光金属底板___1E2B_2026-08-02T14-47-12.png", "res_lingzhi.png"),
    ("写实国漫油画风修真UI组件_深青灰哑光金属底板___1E2B_2026-08-02T14-47-46.png", "res_shengwang.png"),
]

TARGET_SIZE = (256, 256)


def remove_watermark(img: Image.Image) -> Image.Image:
    """Remove bottom-right 'AI生成' watermark by cropping bottom-right edge."""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    # Crop 10% from right and bottom where watermark sits; content is centered
    crop_w = int(w * 0.90)
    crop_h = int(h * 0.90)
    return rgba.crop((0, 0, crop_w, crop_h))


def process():
    os.makedirs(LEGACY_DIR, exist_ok=True)

    for src_name, dst_name in PAIRS:
        src_path = os.path.join(SRC_DIR, src_name)
        dst_path = os.path.join(DST_DIR, dst_name)

        print(f"Processing {src_name} -> {dst_name}")
        img = Image.open(src_path)
        print(f"  original size: {img.size}")

        # Remove watermark
        clean = remove_watermark(img)

        # Resize to target
        resized = clean.resize(TARGET_SIZE, Image.LANCZOS)

        # Backup old file if exists
        if os.path.exists(dst_path):
            legacy_path = os.path.join(LEGACY_DIR, dst_name)
            old = Image.open(dst_path)
            old.save(legacy_path)
            print(f"  backed up old to {legacy_path}")

        resized.save(dst_path)
        print(f"  saved {dst_path} size={resized.size}")


if __name__ == "__main__":
    process()

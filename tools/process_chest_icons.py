# 太玄宗门录 · 活动宝箱三态图标预处理
# 去白底 + 去水印 + 缩放 80×80 + USM 锐化 + alpha 清理 + 生成 .import
import os
import sys
import hashlib
import random
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageFilter

PROJECT_ROOT = Path("E:/Xiuxian/taixuanzongmenlu")
OUT_DIR = PROJECT_ROOT / "art" / "icons" / "hd"
SOURCE_FILES = {
    "chest_claimed_36": "C:/Users/Administrator/.workbuddy/clipboard-images/clipboard-2026-08-13T18-15-49-026Z-d827bbcf.jpg",   # 宝箱已领取
    "chest_canclaim_36": "C:/Users/Administrator/.workbuddy/clipboard-images/clipboard-2026-08-13T18-15-49-027Z-bbe6587d.jpg",  # 宝箱可领取
    "chest_locked_36": "C:/Users/Administrator/.workbuddy/clipboard-images/clipboard-2026-08-13T18-15-49-028Z-0e78baa0.jpg",    # 宝箱未开启
}
TARGET_SIZE = 80

ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

def uid() -> str:
    """生成 Godot 风格 uid://xxx"""
    n = random.getrandbits(64)
    s = ""
    while n:
        n, r = divmod(n, 58)
        s = ALPHABET[r] + s
    return f"uid://{s[:13]:0<13}"

def md5_str(s: str) -> str:
    return hashlib.md5(s.encode("utf-8")).hexdigest()

def remove_watermark(img: np.ndarray) -> np.ndarray:
    """抹掉右下角水印（豆包AI生成），仅对右下角小区域做 inpaint。"""
    h, w = img.shape[:2]
    mask = np.zeros((h, w), dtype=np.uint8)
    # 覆盖右下角水印区域（宽 220px / 高 70px，底部留 10px 边距）
    wm_w, wm_h, margin = min(220, w // 4), min(70, h // 12), 10
    x1, y1 = max(0, w - wm_w - margin), max(0, h - wm_h - margin)
    x2, y2 = w, h
    mask[y1:y2, x1:x2] = 255
    return cv2.inpaint(img, mask, 3, cv2.INPAINT_TELEA)

def remove_white_bg(img: np.ndarray) -> np.ndarray:
    """去除白/浅灰背景，输出 RGBA。"""
    # BGR -> RGB
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float32)
    h, s, v = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
    # 白色/浅灰：亮度高且饱和度低
    white = (v > 200) & (s < 35)
    # 扩展到稍暗的过渡像素
    light = (v > 235)
    bg = white | light
    # 形态学开运算去 JPG 噪点，再轻微腐蚀消除白边
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    bg = cv2.morphologyEx(bg.astype(np.uint8) * 255, cv2.MORPH_OPEN, kernel)
    bg = cv2.erode(bg, np.ones((3, 3), np.uint8), iterations=1)
    alpha = cv2.GaussianBlur(255 - bg, (5, 5), 0)
    rgba = np.dstack([rgb, alpha])
    return rgba

def process_one(src_path: str, out_name: str) -> None:
    print(f"\n>>> 处理 {out_name} ...")
    img = cv2.imread(src_path, cv2.IMREAD_COLOR)
    if img is None:
        raise RuntimeError(f"无法读取 {src_path}")
    print(f"    源图尺寸 {img.shape[1]}×{img.shape[0]}")

    # 1. 去水印
    img = remove_watermark(img)
    # 2. 去白底
    rgba = remove_white_bg(img)
    pil = Image.fromarray(rgba, "RGBA")
    # 3. 内容居中裁剪为正方形（保持主体填充率）
    bbox = pil.getbbox()
    if bbox:
        cx = (bbox[0] + bbox[2]) // 2
        cy = (bbox[1] + bbox[3]) // 2
        side = max(bbox[2] - bbox[0], bbox[3] - bbox[1])
        side = int(side * 1.05)  # 留 5% 边距
        x0, y0 = cx - side // 2, cy - side // 2
        x1, y1 = x0 + side, y0 + side
        # 限制在图内
        x0, y0 = max(0, x0), max(0, y0)
        x1, y1 = min(pil.width, x1), min(pil.height, y1)
        pil = pil.crop((x0, y0, x1, y1))
    # 4. 缩放至 80×80（INTER_AREA 适合下采样）
    cv_arr = cv2.cvtColor(np.array(pil), cv2.COLOR_RGBA2BGRA)
    scaled = cv2.resize(cv_arr, (TARGET_SIZE, TARGET_SIZE), interpolation=cv2.INTER_AREA)
    pil = Image.fromarray(cv2.cvtColor(scaled, cv2.COLOR_BGRA2RGBA), "RGBA")
    # 5. USM 锐化（amount=1.0 / radius=0.6 / threshold=2）
    pil = pil.filter(ImageFilter.UnsharpMask(radius=0.6, percent=100, threshold=2))
    # 6. alpha 清理：去除极弱边缘，透明像素 RGB 置 0
    arr = np.array(pil)
    arr[arr[:, :, 3] < 20] = [0, 0, 0, 0]
    pil = Image.fromarray(arr, "RGBA")

    out_png = OUT_DIR / f"{out_name}.png"
    pil.save(out_png, "PNG")
    print(f"    输出 {out_png} ({TARGET_SIZE}×{TARGET_SIZE})")

    # 7. 生成 .import
    uid_str = uid()
    source_file = f"res://art/icons/hd/{out_name}.png"
    h = md5_str(source_file)
    import_text = f"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid_str}"
path="res://.godot/imported/{out_name}.png-{h}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{source_file}"
dest_files=["res://.godot/imported/{out_name}.png-{h}.ctex"]

[params]

compress/mode=0
compress/high_quality=true
compress/lossy_quality=0.95
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
    (OUT_DIR / f"{out_name}.png.import").write_text(import_text, encoding="utf-8", newline="\n")
    print(f"    生成 {out_name}.png.import  uid={uid_str}")

    # 8. 清理旧 ctex 缓存（若存在）
    cache_pattern = f"{out_name}.png-*.ctex"
    cache_dir = PROJECT_ROOT / ".godot" / "imported"
    if cache_dir.exists():
        for f in cache_dir.glob(cache_pattern):
            f.unlink()
            print(f"    清理缓存 {f.name}")

def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for out_name, src_path in SOURCE_FILES.items():
        if not os.path.exists(src_path):
            print(f"[ERROR] 源文件不存在: {src_path}")
            return 1
        process_one(src_path, out_name)
    print("\n全部完成。建议运行 pre_f5_check.py 验证。")
    return 0

if __name__ == "__main__":
    sys.exit(main())

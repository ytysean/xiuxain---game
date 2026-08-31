"""方案3：底部 Tab 图标单独提亮（nav_*.png 10张）"""
from PIL import Image, ImageEnhance, ImageFilter
import os, glob, shutil
import numpy as np

nav_files = sorted(glob.glob('art/ui/buttons/nav_*.png'))
nav_files = [f for f in nav_files if not f.endswith('.import') and '_legacy' not in f and '_b2' not in f]

backup_dir = 'art/ui/buttons/_legacy_b2_nav'
os.makedirs(backup_dir, exist_ok=True)

stats_before = []
stats_after = []

for f in nav_files:
    name = os.path.basename(f)
    img = Image.open(f).convert('RGBA')

    # 备份
    bk = os.path.join(backup_dir, name)
    if not os.path.exists(bk):
        shutil.copy2(f, bk)

    # 处理前指标
    arr = np.array(img)
    brightness_before = arr[:,:,:3].mean()
    contrast_before = arr[:,:,:3].std()
    lap_before = np.array(img.convert('L').filter(ImageFilter.FIND_EDGES)).mean()
    stats_before.append((name, brightness_before, contrast_before, lap_before))

    # === Tab 图标针对性增强 ===
    # 1) 亮度 +18%
    img = ImageEnhance.Brightness(img).enhance(1.18)
    # 2) 对比度 +12%
    img = ImageEnhance.Contrast(img).enhance(1.12)
    # 3) 饱和度 +8%（金色描边更突出）
    img = ImageEnhance.Color(img).enhance(1.08)
    # 4) USM 锐化加强版（半径0.5 / 130% / 阈值2）
    arr_f = np.array(img).astype(np.float32)
    rgb = arr_f[:,:,:3]
    alpha = arr_f[:,:,3:4] if arr_f.shape[2] == 4 else None

    blurred = img.filter(ImageFilter.GaussianBlur(radius=0.5))
    b_arr = np.array(blurred).astype(np.float32)
    b_rgb = b_arr[:,:,:3]

    amount = 1.30
    threshold = 2.0
    diff = rgb - b_rgb
    mask = np.abs(diff) < threshold
    diff_masked = diff.copy()
    diff_masked[mask] = 0
    sharpened = np.clip(rgb + amount * diff_masked, 0, 255).astype(np.uint8)

    if alpha is not None:
        result = np.dstack([sharpened, alpha.astype(np.uint8)])
    else:
        result = sharpened

    img_out = Image.fromarray(result, 'RGBA')
    img_out.save(f, 'PNG')

    # 处理后指标
    a_arr = np.array(img_out)
    brightness_after = a_arr[:,:,:3].mean()
    contrast_after = a_arr[:,:,:3].std()
    lap_after = np.array(img_out.convert('L').filter(ImageFilter.FIND_EDGES)).mean()
    stats_after.append((name, brightness_after, contrast_after, lap_after))

# 输出报告
print("=== 底部 Tab 图标提亮完成 ===")
header = f"{'文件':24s} | {'亮度':>7s} | {'对比度':>7s} | {'边缘':>7s} || {'亮度Δ':>6s} | {'对比度Δ':>7s} | {'边缘Δ':>6s}"
print(header)
print("-" * len(header))
for (n, b, c, l), (n2, b2, c2, l2) in zip(stats_before, stats_after):
    print(f"{n:24s} | {b:7.1f} | {c:7.1f} | {l:7.1f} || {b2-b:+6.1f} | {c2-c:+7.1f} | {l2-l:+6.1f}")

avg_b0 = sum(s[1] for s in stats_before) / len(stats_before)
avg_c0 = sum(s[2] for s in stats_before) / len(stats_before)
avg_l0 = sum(s[3] for s in stats_before) / len(stats_before)
avg_b = sum(s[1] for s in stats_after) / len(stats_after)
avg_c = sum(s[2] for s in stats_after) / len(stats_after)
avg_l = sum(s[3] for s in stats_after) / len(stats_after)
print("-" * len(header))
print(f"{'平均变化':24s} | {avg_b-avg_b0:+7.1f} | {avg_c-avg_c0:+7.1f} | {avg_l-avg_l0:+7.1f}")
print(f"备份位置: {backup_dir}/")

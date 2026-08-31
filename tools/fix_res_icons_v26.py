"""
v26 资源图标后处理：
1. 新生成的灵气/灵植 AI 图 → 方裁中心 → 缩 96×96 → 覆盖原文件
2. 全部 5 个资源图标 → 去除深青底色 → 透明背景输出
"""
import os
import numpy as np
from PIL import Image, ImageFilter

BASE = "E:/Xiuxian/taixuanzongmenlu/art/ui/buttons"
GEN_DIR = os.path.join(BASE, "_gen_icons")
OUT_SIZE = 96

# ── 1) 处理新 AI 生成的灵气 + 灵植 ──────────────────────────
new_icons = {
    "res_lingqi.png": "仙侠游戏UI图标_灵气_真元_明亮的青白色发光漩涡或流动的光_2026-08-06T14-41-09.png",
    "res_lingzhi.png": "仙侠游戏UI图标_灵草_灵芝_仙莲_一朵发光的莲花花苞或灵芝_2026-08-06T14-41-36.png",
}

for out_name, src_name in new_icons.items():
    src_path = os.path.join(GEN_DIR, src_name)
    out_path = os.path.join(BASE, out_name)

    if not os.path.exists(src_path):
        print(f"⚠️ 源文件不存在: {src_name}")
        continue

    img = Image.open(src_path).convert("RGBA")
    print(f"\n📐 处理 {out_name}: 原始 {img.size}")

    # 方裁：取中心正方形
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    img = img.crop((left, top, left + side, top + side))
    print(f"   方裁中心: {side}×{side}")

    # 缩放到 96×96 (LANCZOS 高质量)
    img = img.resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS)

    # 轻微锐化（AI 图缩放后偏软）
    img = img.filter(ImageFilter.UnsharpMask(radius=0.8, percent=40, threshold=3))

    img.save(out_path, "PNG")
    print(f"   ✅ 已保存: {out_path} ({OUT_SIZE}×{OUT_SIZE})")


# ── 2) 全部 5 资源图标去背（透明化）─────────────────────────
# 策略：检测底色(取四角平均) → 颜色距离阈值 → 边缘羽化防硬切
res_icons = ["res_lingshi.png", "res_lingqi.png", "res_lingzhi.png", "res_shengwang.png", "res_xianyu.png"]

for fn in res_icons:
    path = os.path.join(BASE, fn)
    if not os.path.exists(path):
        continue

    img = Image.open(path).convert("RGBA")
    arr = np.array(img, dtype=np.float32)

    # 取四角像素平均值作为"底色参考"
    h, w = arr.shape[:2]
    corner_colors = [
        arr[0, 0, :3],
        arr[0, w-1, :3],
        arr[h-1, 0, :3],
        arr[h-1, w-1, :3],
    ]
    bg_color = np.mean(corner_colors, axis=0)
    print(f"\n🎨 去背 {fn}: 底色≈RGB({bg_color[0]:.0f},{bg_color[1]:.0f},{bg_color[2]:.0f})")

    # 计算每个像素与底色的欧氏距离
    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]
    dist = np.sqrt((r - bg_color[0])**2 + (g - bg_color[1])**2 + (b - bg_color[2])**2)

    # 动态阈值：底色越暗，阈值越小（更激进去背）；底色越亮，阈值越大
    bg_luminance = np.dot(bg_color, [0.299, 0.587, 0.114])
    if bg_luminance < 40:
        threshold = 30   # 暗底色：小阈值
    elif bg_luminance < 80:
        threshold = 45
    else:
        threshold = 55   # 亮底色：大阈值

    # 创建蒙版：距离 < 阈值 → 透明；距离 > 阈值*1.5 → 完全保留
    mask = np.clip((dist - threshold * 0.6) / (threshold * 0.8), 0, 1)
    mask = (mask * 255).astype(np.uint8)

    # 应用蒙版到 alpha 通道
    arr[:,:,3] = np.minimum(arr[:,:,3], mask)

    # 边缘羽化：对 alpha 通道做轻微高斯模糊，消除硬切边缘
    from scipy.ndimage import gaussian_filter
    alpha_smooth = gaussian_filter(arr[:,:,3].astype(np.float32), sigma=1.2)
    arr[:,:,3] = np.clip(alpha_smooth, 0, 255).astype(np.uint8)

    result = Image.fromarray(arr.astype(np.uint8), "RGBA")
    result.save(path, "PNG")

    # 统计透明度变化
    new_alpha = arr[:,:,3]
    transparent_pct = 100.0 * np.sum(new_alpha == 0) / new_alpha.size
    print(f"   ✅ 去背完成: 透明区域 {transparent_pct:.1f}% | 阈值={threshold}")

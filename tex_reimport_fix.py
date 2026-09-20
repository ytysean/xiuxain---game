#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""技术美术批量重导入修复器（Godot 4.7）— v2 用途分级版

作用：
  1) 无损(Lossless, compress/mode=0) → VRAM 压缩(compress/mode=2)：手机端显存降约 9x
  2) 按【显示用途分级】设置 process/size_limit（最大边上限，等比缩放）：
       - 单边 > 4096                                → 4096  超宽 UI 表 / 巨图
       - 备份/参考/样本/pose（运行时不加载）          → 512
       - 半身像 _halfbody / 战斗 _battle / 头像 _avatar → 512   （代码实测显示 ≤240px）
       - 图标 icons / 头像框 / 圆形头像 masters_circle / 怪物·NPC·拍卖师 → 512
       - B 任务小元素目录 characters/{master,guardian,npc,beasts,fish} → 512
       - 全屏立绘 *_stand / 宗主立绘 masters/ / 背景 / 殿阁场景 → 不设限（保持源分辨率）

  ★ 为什么不给全屏立绘压 512：
    disciple_detail_page 以 cover 模式把立绘铺满上半屏（宽 ~1080px），
    源 1024 宽 → 放大 1.05x（清晰）；压到 512 宽 → 放大 2.1x（明显模糊）。
    故 stand 全身立绘、宗主立绘、全屏背景一律保持源尺寸。

  ★ 像素级契约豁免（_PIXEL_EXACT_EXEMPT）：
    art/ui/patch/ · art/ui/icon_base* · art/ui/master_detail/ · art/ui/entry_fragment_chest_36
    这些图有「逐像素 / 边距」契约 —— ui_theme.gd:1468 的 9-patch 拉伸要求原图逐像素一致，
    ui_theme.gd:1724 有边距契约；对它们做 mode=0→2 的 VRAM 压缩会破坏契约。
    ⇒ 本脚本对匹配目录 **整体跳过：既不改 compress/mode，也不改 process/size_limit**。

  ★ 本脚本不改 compress/high_quality；全库该字段应为 false。
    hq 只影响编码质量（true→BPTC/ASTC 8bpp，false→S3TC/ETC2 4bpp），不由本脚本管理。

  ★ 源 PNG/JPG 完全不动；仅改写 .import 参数，Godot 下次打开自动按新参数重导入。

用法:
  python tex_reimport_fix.py [根目录] [--dry]   # --dry 仅预览不落盘
"""
import os
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else \
    os.path.dirname(os.path.abspath(__file__))
DRY = "--dry" in sys.argv

TEX_EXT = (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga")

CAP_512 = 512
CAP_4096 = 4096

# 运行时不加载的资源（备份 / 骨架参考 / 出图样本 / 姿势参考 / 外部参考 / 预览）
# → 只需留档，可压到最小
_NON_RUNTIME_TOKENS = (
    "backup", "_skeleton_ref", "/samples/", "samples/", "/pose/",
    "_references", "_preview", "dryrun", "out_90", "out_dryrun",
)

# 按「文件名用途标记」判定小尺寸显示（实测：battle 战斗框 180x240 / halfbody 列表头像 ~120px）
_SMALL_USAGE_TOKENS = ("_halfbody", "_battle", "_avatar")

# 明确的小尺寸元素目录（图标 / 头像框 / 圆形头像 / 怪物 / NPC / B 任务小元素）
# 注意 "art/characters/master/" 不会误匹配 "art/characters/masters/"（后者末尾是 s 非 /）
_SMALL_ELEMENT_DIRS = (
    "art/icons/",
    "art/avatar_frames/",
    "art/characters/beasts/",
    "art/characters/npc/",
    "art/characters/master/",
    "art/characters/guardian/",
    "art/characters/fish/",
    "art/characters/masters_circle/",
    "art/characters/monsters/",
    "art/characters/hostile_npc/",
    "art/characters/auctioneer/",
)

# 像素级契约豁免目录：脚本对其【零改写】（不转 mode 0->2，也不改 size_limit）
#   - ui_theme.gd:1468 的 9-patch 拉伸要求原图逐像素一致
#   - ui_theme.gd:1724 有边距契约
_PIXEL_EXACT_EXEMPT = (
    "art/ui/patch/",
    "art/ui/icon_base",
    "art/ui/master_detail/",
    "art/ui/entry_fragment_chest_36",
)


def _is_pixel_exact_exempt(rel_src):
    """命中像素级契约豁免目录 → 本脚本对其零改写。"""
    r = rel_src.replace("\\", "/").lower()
    return any(d in r for d in _PIXEL_EXACT_EXEMPT)


def _cap_target(rel_src, w, h):
    """按用途返回 size_limit 目标；None = 不设限（保持源分辨率）。

    rel_src: 相对工程根的源文件路径（如 art/characters/disciples/...）。
    """
    r = rel_src.replace("\\", "/").lower()
    maxdim = max(w or 0, h or 0)

    # 1) 巨图 / 超宽 UI 表统一压 4096
    if maxdim > CAP_4096:
        return CAP_4096

    # 2) 运行时不加载的备份 / 参考 / 样本 → 512
    if any(t in r for t in _NON_RUNTIME_TOKENS):
        return CAP_512

    # 3) 半身 / 战斗 / 头像用途标记 → 512
    if any(t in r for t in _SMALL_USAGE_TOKENS):
        return CAP_512

    # 4) 明确的小尺寸元素目录 → 512
    if any(d in r for d in _SMALL_ELEMENT_DIRS):
        return CAP_512

    # 5) 其余（全屏 stand 立绘 / 宗主立绘 masters / 背景 / 殿阁场景 / 大 UI 图）→ 保持源尺寸
    return None


def img_dims(path):
    """读 PNG/JPG 尺寸（无第三方库）。"""
    try:
        with open(path, "rb") as f:
            head = f.read(64)
        if head[:8] == b"\x89PNG\r\n\x1a\n":
            return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")
        if head[:2] == b"\xff\xd8":  # JPEG
            f = open(path, "rb")
            f.read(2)
            while True:
                b = f.read(1)
                if not b or b != b"\xff":
                    break
                marker = f.read(1)
                if marker in (b"\xc0", b"\xc1", b"\xc2", b"\xc3"):
                    f.read(3)
                    h = int.from_bytes(f.read(2), "big")
                    w = int.from_bytes(f.read(2), "big")
                    f.close()
                    return w, h
                seg = f.read(2)
                if len(seg) < 2:
                    break
                f.seek(int.from_bytes(seg, "big") - 2, 1)
            f.close()
    except Exception:
        pass
    return None, None


def fix_import(ipath, src_rel):
    """改写单个 .import：无损→VRAM，并按用途分级设 size_limit。返回 (changed, cap)。"""
    try:
        with open(ipath, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except Exception:
        return False, 0
    txt = "".join(lines)
    if 'importer="texture"' not in txt:
        return False, 0

    # 像素级契约豁免目录：零改写（保 mode=0 与现有 size_limit）
    if _is_pixel_exact_exempt(src_rel):
        return False, 0

    src = os.path.splitext(ipath)[0]
    w, h = img_dims(src)
    cap_target = _cap_target(src_rel, w, h)

    changed = False
    capped = False
    seen_limit = False
    out = []
    in_params = False
    for ln in lines:
        s = ln.strip()
        if s.startswith("[params]"):
            in_params = True
            out.append(ln)
            continue
        if s.startswith("[") and not s.startswith("[params]"):
            in_params = False
            out.append(ln)
            continue
        if in_params and s.startswith("compress/mode="):
            val = s.split("=", 1)[1].strip()
            if val == "0":  # Lossless -> VRAM Compress
                out.append(ln.replace("compress/mode=0", "compress/mode=2"))
                changed = True
                continue
        if in_params and s.startswith("process/size_limit="):
            seen_limit = True
            if cap_target is not None:
                cur = s.split("=", 1)[1].strip()
                if cur != str(cap_target):  # 无条件套用目标值（可纠正已是非 0 的错值）
                    eol = "\r\n" if ln.endswith("\r\n") else "\n"
                    out.append("process/size_limit=%d%s" % (cap_target, eol))
                    capped = True
                else:
                    out.append(ln)  # 已等于目标：幂等，不写盘
                continue
        out.append(ln)
    # 需要 cap 但 params 里根本没有 size_limit 行 → 在 [params] 后插入
    if cap_target is not None and not seen_limit:
        for i, ln in enumerate(out):
            if ln.strip().startswith("[params]"):
                out.insert(i + 1, "process/size_limit=%d\n" % cap_target)
                capped = True
                break
    if changed or capped:
        if not DRY:
            with open(ipath, "w", encoding="utf-8", newline="") as f:
                f.write("".join(out))
        return changed, (cap_target if capped else 0)
    return False, 0


def main():
    n_total = n_changed = n_capped = n_4096 = n_512 = 0
    caps = []
    for dirpath, _, files in os.walk(ROOT):
        # 跳过引擎缓存、插件、本工具/备份/归档目录（非游戏运行资源）
        if any(s in dirpath for s in (".godot", "addons", ".workbuddy", ".git", "archive_legacy")):
            continue
        for fn in files:
            if not fn.endswith(".import"):
                continue
            ipath = os.path.join(dirpath, fn)
            src = os.path.splitext(ipath)[0]
            if not os.path.exists(src) or os.path.splitext(src)[1].lower() not in TEX_EXT:
                continue
            n_total += 1
            c, cap = fix_import(ipath, os.path.relpath(src, ROOT))
            if c:
                n_changed += 1
            if cap:
                n_capped += 1
                if cap == CAP_4096:
                    n_4096 += 1
                elif cap == CAP_512:
                    n_512 += 1
                caps.append(os.path.relpath(src, ROOT))
    print(f"[{'DRY' if DRY else 'APPLY'}] 扫描纹理 .import: {n_total}")
    print(f"  改为 VRAM 压缩(mode 0->2): {n_changed}")
    print(f"  设 size_limit(总): {n_capped}  [ 4096 巨图: {n_4096} | 512 小图/备份: {n_512} ]")
    if caps:
        print("  被降尺寸的图(前20):")
        for c in caps[:20]:
            print("    -", c)
        if len(caps) > 20:
            print(f"    ... 共 {len(caps)} 张")


if __name__ == "__main__":
    main()

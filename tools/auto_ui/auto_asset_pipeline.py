# =============================================================================
# auto_asset_pipeline.py —— 太玄UI编辑器「0 干预」资源自动化管线
# -----------------------------------------------------------------------------
# 目标：扫描工作空间美术资源 → 自动分类 → 清洗命名 → 自动布局 → 直接生成
#       Godot 可导入的 .tscn 场景 + SpriteFrames.tres + 游戏清单 JSON。
# 全程无需人工点击；美术资源可由用户在对话框提供，或由本脚本直接调取工作空间。
#
# 用法：
#   python auto_asset_pipeline.py            # 跑完整流水线（扫描/分类/生成）
#   python auto_asset_pipeline.py --self-test # 仅验证精灵表切片导出正确性
# =============================================================================

import os
import sys
import json
import shutil
import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))  # E:/Xiuxian/taixuanzongmenlu
sys.path.insert(0, HERE)

import taixuan_tscn as T  # 纯 Python 导出镜像

T.set_res_root(PROJECT_ROOT)

CANVAS_W, CANVAS_H = 768, 1344
OUT_ART = "art/auto_ui"          # res://art/auto_ui
OUT_SCENES = os.path.join(OUT_ART, "scenes")
OUT_SHEETS = os.path.join(OUT_ART, "sheets")
OUT_MANIFEST = "config/auto_ui_manifest.json"

# 默认扫描的「成品美术」根目录（排除生成中间态目录）
AUTO_ROOTS = [
    "assets/ai_art/2026-07-22",
    "美术资源/弟子原型套组_A/samples",
    "美术资源",  # 顶层 4 张竖屏大图（背景/ splash）
]


# ------------------------- 分类 -------------------------

def classify(name, w, h):
    n = name.lower()
    if any(k in n for k in ("面板", "弹窗", "panel")):
        return "panel"
    if any(k in n for k in ("按钮", "button", "btn")):
        return "button"
    if any(k in n for k in ("头像框", "头像", "frame", "框")):
        return "avatar_frame"
    if any(k in n for k in ("立绘", "portrait", "角色")):
        return "portrait"
    if any(k in n for k in ("sheet", "atlas", "sprites", "序列", "frames")):
        return "spritesheet"
    if any(k in n for k in ("icon", "图标", "nav", "sq_", "micro")):
        return "icon"
    if any(k in n for k in ("背景", "远景", "bg", "background", "splash")):
        return "background"
    # 兜底：按尺寸（竖屏大图当作背景）
    if h >= 1.3 * w and max(w, h) >= 800:
        return "background"
    return "other"


# ------------------------- 资源发现 -------------------------

def discover():
    found = []
    seen = set()
    for root in AUTO_ROOTS:
        abs_root = os.path.join(PROJECT_ROOT, root)
        if not os.path.isdir(abs_root):
            continue
        for fn in sorted(os.listdir(abs_root)):
            if fn.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                p = os.path.join(abs_root, fn)
                if p in seen:
                    continue
                seen.add(p)
                try:
                    from PIL import Image
                    with Image.open(p) as im:
                        w, h = im.size
                except Exception:
                    w = h = 0
                role = classify(fn, w, h)
                found.append({"src": p, "name": fn, "w": w, "h": h, "role": role})
    return found


# ------------------------- 清洗拷贝（重命名为干净 res 路径）-------------------------

def sanitize_ext(fn):
    return os.path.splitext(fn)[1].lower()


def copy_assets(assets):
    """按 role_<nn> 重命名拷贝到 res://art/auto_ui/，返回 {原始src: res路径}。"""
    counters = {}
    mapping = {}
    for a in assets:
        role = a["role"]
        counters[role] = counters.get(role, 0) + 1
        nn = "%02d" % counters[role]
        ext = sanitize_ext(a["name"])
        new_name = "%s_%s%s" % (role, nn, ext)
        dst = os.path.join(PROJECT_ROOT, OUT_ART, new_name)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(a["src"], dst)
        res = "res://%s/%s" % (OUT_ART.replace("\\", "/"), new_name)
        mapping[a["src"]] = res
        a["res"] = res
    return mapping


# ------------------------- 透明间隙网格检测（判断真·精灵表）-------------------------

def detect_grid(p):
    """若图为带透明间隙的网格，返回 (hframes, vframes, frame_count)；否则 None。"""
    try:
        from PIL import Image
        im = Image.open(p).convert("RGBA")
        W, H = im.size
        adata = list(im.getchannel("A").getdata())
        def colmax(x):
            m = 0
            for y in range(H):
                v = adata[y * W + x]
                if v > m:
                    m = v
            return m
        def rowmax(y):
            base = y * W
            m = 0
            for x in range(W):
                v = adata[base + x]
                if v > m:
                    m = v
            return m
        gap_c = [x for x in range(W) if colmax(x) == 0]
        gap_r = [y for y in range(H) if rowmax(y) == 0]
        if not gap_c and not gap_r:
            return None  # 无透明间隙 → 不是可切片的精灵表
        def runs(gap, n):
            if not gap:
                return [(0, n - 1)]
            s = set(gap); i = 0; out = []
            while i < n:
                if i in s:
                    i += 1; continue
                j = i
                while j < n and (j not in s):
                    j += 1
                out.append((i, j - 1)); i = j
            return out
        cr = runs(gap_c, W); rr = runs(gap_r, H)
        hf = len(cr); vf = len(rr)
        cnt = 0
        for (r0, r1) in rr:
            for (c0, c1) in cr:
                cy = (r0 + r1) // 2; cx = (c0 + c1) // 2
                if adata[cy * W + cx] > 10:
                    cnt += 1
        return (hf, vf, cnt)
    except Exception:
        return None


# ------------------------- 布局生成 -------------------------

def _ctrl(type_, name, x, y, w, h, style, z=0):
    return {
        "type": type_, "name": name,
        "position": [x, y], "size": [w, h], "min_size": [w, h],
        "z_index": z, "anchor_preset": 0, "style": style,
    }


# 自动识别游戏自带字体作为默认字体（让自动生成的场景文字与游戏一致）
def detect_game_font():
    candidates = [
        "res://ui/assets/fonts/NotoSerifSC-Subset.otf",
        "res://ui/assets/fonts/MaShanZheng-Subset.ttf",
    ]
    for c in candidates:
        if os.path.exists(c.replace("res://", PROJECT_ROOT + "/")):
            return c
    return ""


def build_main_menu(bg_res, panel_res, button_res, frame_res, portrait_res):
    cw, ch = CANVAS_W, CANVAS_H
    controls = []
    # 背景：铺满，cover
    controls.append(_ctrl("TextureRect", "Bg", 0, 0, cw, ch,
                          {"texture_path": bg_res, "modulate_alpha": 1.0, "stretch_mode": 6}, z=0))
    # 标题
    controls.append(_ctrl("Label", "Title", (cw - 480) // 2, 64, 480, 64, {
        "text": "太玄宗", "font_size": 44, "color": [0.78, 0.66, 0.42, 1.0],
        "horizontal_alignment": 1, "vertical_alignment": 1, "font_path": ""}, z=5))
    # 立绘（keep aspect）
    pw, ph = 380, 540
    controls.append(_ctrl("TextureRect", "Portrait", (cw - pw) // 2, int(ch * 0.28), pw, ph,
                          {"texture_path": portrait_res, "modulate_alpha": 1.0, "stretch_mode": 4}, z=1))
    # 面板
    pww, phh = min(cw - 80, 600), 360
    controls.append(_ctrl("Panel", "Panel", (cw - pww) // 2, int(ch * 0.46), pww, phh, {
        "bg_color": [0.07, 0.13, 0.11, 0.92], "border_color": [0.78, 0.66, 0.42, 1.0],
        "border_width": 3, "corner_radius": 12, "bg_path": "", "bg_nine_patch": True,
        "bg_margin_left": 0, "bg_margin_top": 0, "bg_margin_right": 0, "bg_margin_bottom": 0,
        "bg_axis_h": 0, "bg_axis_v": 0}, z=2))
    # 头像框
    fw, fh = 150, 150
    controls.append(_ctrl("TextureRect", "AvatarFrame", cw - fw - 24, 24, fw, fh,
                          {"texture_path": frame_res, "modulate_alpha": 1.0, "stretch_mode": 0}, z=3))
    # 按钮（九宫格底板）
    bw, bh = 260, 80
    controls.append(_ctrl("Button", "EnterBtn", (cw - bw) // 2, ch - 170, bw, bh, {
        "button_text": "进入宗门", "icon_path": "", "bg_path": button_res, "font_size": 26,
        "color": [1.0, 1.0, 1.0, 1.0], "bg_nine_patch": True,
        "bg_margin_left": 24, "bg_margin_top": 24, "bg_margin_right": 24, "bg_margin_bottom": 24,
        "bg_axis_h": 0, "bg_axis_v": 0}, z=4))
    doc = {
        "version": "1.0", "generator": "太玄UI编辑器-自动管线",
        "canvas": {"width": cw, "height": ch, "background_color": [0.04, 0.06, 0.05, 1.0]},
        "reference_image": {"path": "", "opacity": 1.0, "locked": False, "visible": True, "fit": "contain"},
        "default_font": detect_game_font(),
        "controls": controls,
    }
    return doc


def build_portrait_showcase(bg_res, frame_res, portrait_res):
    cw, ch = CANVAS_W, CANVAS_H
    controls = []
    controls.append(_ctrl("TextureRect", "Bg", 0, 0, cw, ch,
                          {"texture_path": bg_res, "modulate_alpha": 0.35, "stretch_mode": 6}, z=0))
    pw, ph = 460, 660
    controls.append(_ctrl("TextureRect", "Portrait", (cw - pw) // 2, (ch - ph) // 2, pw, ph,
                          {"texture_path": portrait_res, "modulate_alpha": 1.0, "stretch_mode": 4}, z=1))
    fw, fh = 200, 200
    controls.append(_ctrl("TextureRect", "AvatarFrame", (cw - fw) // 2, (ch - ph) // 2 - 20, fw, fh,
                          {"texture_path": frame_res, "modulate_alpha": 1.0, "stretch_mode": 0}, z=2))
    doc = {
        "version": "1.0", "generator": "太玄UI编辑器-自动管线",
        "canvas": {"width": cw, "height": ch, "background_color": [0.02, 0.03, 0.03, 1.0]},
        "reference_image": {"path": "", "opacity": 1.0, "locked": False, "visible": True, "fit": "contain"},
        "default_font": detect_game_font(),
        "controls": controls,
    }
    return doc


def build_spritesheet_doc(sheet_res, hf, vf, fc, fps=8.0):
    cw, ch = CANVAS_W, CANVAS_H
    sw, sh = 360, 360
    controls = [_ctrl("SpriteSheet", "Sheet", (cw - sw) // 2, (ch - sh) // 2, sw, sh, {
        "sheet_path": sheet_res, "hframes": hf, "vframes": vf, "frame_count": fc,
        "fps": fps, "loop": True, "stretch_mode": 0, "modulate_alpha": 1.0}, z=1)]
    doc = {
        "version": "1.0", "generator": "太玄UI编辑器-自动管线",
        "canvas": {"width": cw, "height": ch, "background_color": [0.05, 0.07, 0.06, 1.0]},
        "reference_image": {"path": "", "opacity": 1.0, "locked": False, "visible": True, "fit": "contain"},
        "default_font": detect_game_font(),
        "controls": controls,
    }
    return doc


# ------------------------- 主流程 -------------------------

def run():
    print("[1/5] 扫描工作空间美术资源…")
    assets = discover()
    by_role = {}
    for a in assets:
        by_role.setdefault(a["role"], []).append(a)
    for role in sorted(by_role):
        print("   - %-12s %d 张" % (role, len(by_role[role])))

    print("[2/5] 清洗命名并拷贝到 res://%s/ …" % OUT_ART)
    copy_assets(assets)

    print("[3/5] 自动布局生成场景…")
    roles = {r: [a for a in assets if a["role"] == r] for r in by_role}

    def first(role):
        return roles.get(role, [{}])[0].get("res", "")

    bg = first("background")
    panel = first("panel")
    button = first("button")
    frame = first("avatar_frame")
    portrait = first("portrait")

    scene_paths = {}
    if bg and panel and button and frame and portrait:
        doc = build_main_menu(bg, panel, button, frame, portrait)
        mp = os.path.join(PROJECT_ROOT, OUT_SCENES, "main_menu.tscn")
        T.export_tscn(mp, doc)
        # 同时导出可编辑工程
        proj = os.path.join(PROJECT_ROOT, OUT_ART, "main_menu.taixuan_ui")
        with open(proj, "w", encoding="utf-8", newline="") as fh:
            json.dump({"format": "taixuan_ui", "version": "1.0", "doc": doc, "editor": {}}, fh, ensure_ascii=False, indent="\t")
        scene_paths["main_menu"] = "res://%s/main_menu.tscn" % OUT_SCENES.replace("\\", "/")
        print("   - main_menu.tscn (背景+面板+按钮+头像框+立绘+标题，自动布局)")
    else:
        print("   ! 缺少必要角色资源（需要 background/panel/button/avatar_frame/portrait 各至少一张），跳过主菜单场景")

    if bg and frame and portrait:
        doc2 = build_portrait_showcase(bg, frame, portrait)
        pp = os.path.join(PROJECT_ROOT, OUT_SCENES, "disciple_portrait.tscn")
        T.export_tscn(pp, doc2)
        scene_paths["disciple_portrait"] = "res://%s/disciple_portrait.tscn" % OUT_SCENES.replace("\\", "/")
        print("   - disciple_portrait.tscn (弟子立绘展示：暗背景+立绘+头像框)")

    # 精灵表：仅对「带透明间隙的真网格」自动切片
    spritesheets = []
    for a in assets:
        if a["role"] != "spritesheet":
            continue
        g = detect_grid(a["src"])
        if g:
            hf, vf, fc = g
            tres = os.path.join(PROJECT_ROOT, OUT_SHEETS, os.path.splitext(os.path.basename(a["res"]))[0] + ".frames.tres")
            T.export_spritesheet_tres(tres, a["res"], hf, vf, 8.0, True, fc, sheet_local=a["src"])
            doc3 = build_spritesheet_doc(a["res"], hf, vf, fc)
            sp = os.path.join(PROJECT_ROOT, OUT_SCENES, "spritesheet_%s.tscn" % os.path.splitext(os.path.basename(a["res"]))[0])
            T.export_tscn(sp, doc3)
            spritesheets.append({
                "src_name": a["name"], "res": a["res"],
                "hframes": hf, "vframes": vf, "frame_count": fc,
                "tres": "res://%s" % os.path.relpath(tres, PROJECT_ROOT).replace("\\", "/"),
                "scene": "res://%s" % os.path.relpath(sp, PROJECT_ROOT).replace("\\", "/"),
            })
            print("   - 精灵表 %s → %dx%d 网格, %d 帧, 已生成 SpriteFrames.tres + 场景" % (a["name"], hf, vf, fc))
        else:
            spritesheets.append({
                "src_name": a["name"], "res": a["res"],
                "needs_grid_hint": True,
                "note": "检测到不透明整图/无透明间隙，无法自动切片；请在编辑器或清单中指定 hframes/vframes",
            })
            print("   - 精灵表 %s 标记为需人工给网格（不透明整图，自动跳过切片）" % a["name"])

    print("[4/5] 写入游戏清单 %s …" % OUT_MANIFEST)
    manifest = {
        "generated_by": "taixuan_auto_ui",
        "generated_at": datetime.datetime.now().isoformat(timespec="seconds"),
        "canvas": {"width": CANVAS_W, "height": CANVAS_H},
        "note": "本清单由自动化管线生成；main.gd 可用 FileAccess 读取后按 role 取资源/场景，直接实例化为游戏界面与内容。",
        "assets": {role: [a["res"] for a in assets if a["role"] == role] for role in by_role},
        "spritesheets": spritesheets,
        "scenes": scene_paths,
    }
    mpath = os.path.join(PROJECT_ROOT, OUT_MANIFEST)
    os.makedirs(os.path.dirname(mpath), exist_ok=True)
    with open(mpath, "w", encoding="utf-8", newline="") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent="\t")

    print("[5/5] 完成。")
    print("   资源目录: res://%s/" % OUT_ART.replace("\\", "/"))
    print("   场景目录: res://%s/" % OUT_SCENES.replace("\\", "/"))
    print("   游戏清单: res://%s" % OUT_MANIFEST.replace("\\", "/"))
    return manifest


# ------------------------- 精灵表切片自测 -------------------------

def self_test():
    print("== 精灵表切片自测 ==")
    tmp = os.path.join(HERE, "_selftest")
    os.makedirs(tmp, exist_ok=True)
    # 生成 2x2 透明间隙网格（每格 64x64，间隙 8px）
    from PIL import Image, ImageDraw
    cell, gap = 64, 8
    W = cell * 2 + gap * 3
    H = cell * 2 + gap * 3
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cols = [(200, 50, 50, 255), (50, 200, 50, 255), (50, 50, 200, 255), (200, 200, 50, 255)]
    for i in range(4):
        r, c = divmod(i, 2)
        x = gap + c * (cell + gap)
        y = gap + r * (cell + gap)
        d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=cols[i])
    sheet = os.path.join(tmp, "test_sheet.png")
    im.save(sheet)

    # 检测网格
    g = detect_grid(sheet)
    assert g == (2, 2, 4), "网格检测应为 (2,2,4)，实际 %s" % str(g)
    print("   ✓ 网格检测 (2,2,4)")

    # 导出 SpriteFrames.tres
    tres = os.path.join(tmp, "test_sheet.frames.tres")
    T.export_spritesheet_tres(tres, "res://_selftest/test_sheet.png", 2, 2, 8.0, True, 0, sheet_local=sheet)
    txt = open(tres, encoding="utf-8").read()
    assert "type=\"SpriteFrames\"" in txt
    assert txt.count("[sub_resource type=\"AtlasTexture\"") == 4
    # 偶数网格切片：fw = sw/hframes = 152/2 = 76；cell(0,0)=(0.0,0.0,76.0,76.0)，cell(1,1)=(76.0,76.0,76.0,76.0)
    assert "region = Rect2(0.0, 0.0, 76.0, 76.0)" in txt
    assert "region = Rect2(76.0, 76.0, 76.0, 76.0)" in txt
    print("   ✓ SpriteFrames.tres 结构正确（4 AtlasTexture, region 正确）")

    # 导出 spritesheet .tscn
    doc = build_spritesheet_doc("res://_selftest/test_sheet.png", 2, 2, 4)
    tscn = os.path.join(tmp, "test_sheet.tscn")
    T.set_res_root(tmp)
    T.export_tscn(tscn, doc)
    ttxt = open(tscn, encoding="utf-8").read()
    assert "AtlasTexture" in ttxt
    assert "AnimatedTexture" in ttxt
    assert "load_steps=" in ttxt
    print("   ✓ spritesheet .tscn 结构正确（AtlasTexture + AnimatedTexture）")
    T.set_res_root(PROJECT_ROOT)

    # 清理
    shutil.rmtree(tmp, ignore_errors=True)
    print("自测通过，临时文件已清理。")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        run()

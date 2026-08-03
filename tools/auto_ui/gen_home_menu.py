#!/usr/bin/env python3
# =============================================================================
# tools/auto_ui/gen_home_menu.py
# -----------------------------------------------------------------------------
# 把「太玄UI编辑器」原生工程 home_page.taixuan_ui 忠实地转换为 Godot 场景
# art/auto_ui/scenes/main_menu.tscn，并刷新 config/auto_ui_manifest.json 中的
# main_menu 场景路径。
#
# 逻辑逐行移植自 addons/taixuan_ui_editor/data_manager.gd::export_tscn，
# 因此沙箱内无需 Godot 即可产出与插件「导出 .tscn」字节一致的首屏场景。
#
# 用法（项目根目录执行）：
#   python tools/auto_ui/gen_home_menu.py
#
# 约定：
#   - 源文件 home_page.taixuan_ui 是唯一数据源；在编辑器里改完布局后重跑本脚本即可重导出。
#   - 输出 .tscn 使用 LF 换行、format=3、无注释、无手写 UID（与 Godot 4.7 规范一致）。
# =============================================================================
import json
import os
import struct
import sys
from datetime import datetime


def png_size(path: str):
    """读取 PNG 宽高（仅用于 SpriteSheet 切片计算）。"""
    try:
        with open(path, "rb") as fh:
            if fh.read(8) != b"\x89PNG\r\n\x1a\n":
                return 0.0, 0.0
            fh.read(4)
            fh.read(4)  # length + 'IHDR'
            w, h = struct.unpack(">II", fh.read(8))
            return float(w), float(h)
    except Exception:
        return 0.0, 0.0

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(PROJECT_ROOT, "ui_editor_projects", "home_page.taixuan_ui")
OUT_TSCN = os.path.join(PROJECT_ROOT, "art", "auto_ui", "scenes", "main_menu.tscn")
MANIFEST = os.path.join(PROJECT_ROOT, "config", "auto_ui_manifest.json")

TYPE_TEXTURE = "TextureRect"
TYPE_LABEL = "Label"
TYPE_BUTTON = "Button"
TYPE_PANEL = "Panel"
TYPE_ANIMATED = "AnimatedTexture"
TYPE_SPRITESHEET = "SpriteSheet"


# -------- 浮点格式化：去尾零，保留至少一位小数（移植自 data_manager._f）--------
def f(v: float) -> str:
    s = "%.3f" % v
    while len(s) > 1 and s.endswith("0") and s[-2] != ".":
        s = s[:-1]
    if s.endswith("."):
        s += "0"
    return s


# -------- 字符串转义（.tscn 双引号文本）--------
def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


# -------- 锚点预设 → [l, t, r, b]（移植自 _preset_anchors）--------
def preset_anchors(preset: int):
    table = {
        0: [0.0, 0.0, 0.0, 0.0], 1: [1.0, 0.0, 1.0, 0.0], 2: [0.0, 1.0, 0.0, 1.0],
        3: [1.0, 1.0, 1.0, 1.0], 4: [0.0, 0.5, 0.0, 0.5], 5: [1.0, 0.5, 1.0, 0.5],
        6: [0.5, 0.0, 0.5, 0.0], 7: [0.5, 1.0, 0.5, 1.0], 8: [0.5, 0.5, 0.5, 0.5],
        9: [0.0, 0.0, 0.0, 1.0], 10: [0.0, 0.0, 1.0, 0.0], 11: [1.0, 0.0, 1.0, 1.0],
        12: [0.0, 1.0, 1.0, 1.0], 13: [0.5, 0.0, 0.5, 1.0], 14: [0.0, 0.5, 1.0, 0.5],
        15: [0.0, 0.0, 1.0, 1.0],
    }
    return table.get(preset, [0.0, 0.0, 0.0, 0.0])


def res_type_of(path: str) -> str:
    ext = path.split(".")[-1].lower()
    if ext in ("ttf", "otf", "font"):
        return "FontFile"
    return "Texture2D"


def emit_nine_patch(subs: list, s: dict) -> None:
    subs.append("nine_patch_stretch = %s" % ("true" if bool(s.get("bg_nine_patch", True)) else "false"))
    subs.append("margin_left = %s" % f(float(s.get("bg_margin_left", 0))))
    subs.append("margin_top = %s" % f(float(s.get("bg_margin_top", 0))))
    subs.append("margin_right = %s" % f(float(s.get("bg_margin_right", 0))))
    subs.append("margin_bottom = %s" % f(float(s.get("bg_margin_bottom", 0))))
    subs.append("axis_stretch_horizontal = %d" % int(s.get("bg_axis_h", 0)))
    subs.append("axis_stretch_vertical = %d" % int(s.get("bg_axis_v", 0)))


def export_tscn(doc: dict) -> str:
    canvas = doc.get("canvas", {})
    cw = int(canvas.get("width", 768))
    ch = int(canvas.get("height", 1344))
    bg = canvas.get("background_color", [0.0, 0.0, 0.0, 0.0])
    controls = doc.get("controls", [])
    df = doc.get("default_font", "")

    # ---- 收集外部资源（去重 + 顺序分配 id）----
    res_order = []
    res_id_of = {}
    res_type_of_map = {}
    ridx = 1
    for ci in controls:
        s = ci.get("style", {})
        t = ci.get("type", "")
        paths = []
        if t == TYPE_TEXTURE:
            paths.append(s.get("texture_path", ""))
        elif t == TYPE_BUTTON:
            paths.append(s.get("icon_path", ""))
            paths.append(s.get("bg_path", ""))
        elif t == TYPE_PANEL:
            paths.append(s.get("bg_path", ""))
        elif t == TYPE_ANIMATED:
            for fp in s.get("frames", []):
                paths.append(fp)
        elif t == TYPE_SPRITESHEET:
            paths.append(s.get("sheet_path", ""))
        if t == TYPE_LABEL or t == TYPE_BUTTON:
            fp = s.get("font_path", "")
            if fp == "":
                fp = df
            paths.append(fp)
        else:
            paths.append(s.get("font_path", ""))
        for p in paths:
            if p != "" and p not in res_id_of:
                res_id_of[p] = str(ridx)
                res_type_of_map[p] = res_type_of(p)
                res_order.append(p)
                ridx += 1

    subs: list = []
    sub_id = 1
    nodes: list = []

    # 根节点
    nodes.append('[node name="UI" type="Control"]')
    nodes.append("layout_mode = 3")
    nodes.append("offset_left = 0")
    nodes.append("offset_top = 0")
    nodes.append("offset_right = %d" % cw)
    nodes.append("offset_bottom = %d" % ch)

    # 背景色
    if len(bg) >= 4 and bg[3] > 0.0:
        nodes.append('[node name="BgColor" type="ColorRect" parent="."]')
        nodes.append("layout_mode = 1")
        nodes.append("anchors_preset = 15")
        nodes.append("offset_left = 0")
        nodes.append("offset_top = 0")
        nodes.append("offset_right = %d" % cw)
        nodes.append("offset_bottom = %d" % ch)
        nodes.append("color = Color(%s, %s, %s, %s)" % (f(bg[0]), f(bg[1]), f(bg[2]), f(bg[3])))

    # 基准图（path 为空则跳过）
    ref = doc.get("reference_image", {})
    if isinstance(ref, dict) and ref.get("path", "") != "":
        rpath = str(ref["path"])
        rid = res_id_of.get(rpath, "")
        if rid != "":
            nodes.append('[node name="Reference" type="TextureRect" parent="."]')
            nodes.append("layout_mode = 1")
            nodes.append("anchors_preset = 15")
            nodes.append("offset_left = 0")
            nodes.append("offset_top = 0")
            nodes.append("offset_right = %d" % cw)
            nodes.append("offset_bottom = %d" % ch)
            nodes.append('texture = ExtResource("%s")' % rid)
            nodes.append("expand_mode = 1")
            nodes.append("stretch_mode = 0")
            op = float(ref.get("opacity", 1.0))
            nodes.append("modulate = Color(1, 1, 1, %s)" % f(op))
            if not bool(ref.get("visible", True)):
                nodes.append("visible = false")

    # 各控件
    for cj in controls:
        t = cj.get("type", "")
        nm = str(cj.get("name", "Node"))
        pos = cj.get("position", [0, 0])
        sz = cj.get("size", [0, 0])
        mn = cj.get("min_size", [0, 0])
        z = int(cj.get("z_index", 0))
        preset = int(cj.get("anchor_preset", 0))
        s = cj.get("style", {})
        x = float(pos[0]); y = float(pos[1]); w = float(sz[0]); h = float(sz[1])
        node_type = t
        if t == TYPE_ANIMATED or t == TYPE_SPRITESHEET:
            node_type = "TextureRect"
        nodes.append('[node name="%s" type="%s" parent="."]' % (nm, node_type))
        nodes.append("layout_mode = 1")
        anch = preset_anchors(preset)
        nodes.append("anchor_left = %s" % f(anch[0]))
        nodes.append("anchor_top = %s" % f(anch[1]))
        nodes.append("anchor_right = %s" % f(anch[2]))
        nodes.append("anchor_bottom = %s" % f(anch[3]))
        nodes.append("offset_left = %s" % f(x - anch[0] * cw))
        nodes.append("offset_top = %s" % f(y - anch[1] * ch))
        nodes.append("offset_right = %s" % f((x + w) - anch[2] * cw))
        nodes.append("offset_bottom = %s" % f((y + h) - anch[3] * ch))
        if mn[0] != 0 or mn[1] != 0:
            nodes.append("custom_minimum_size = Vector2(%s, %s)" % (f(float(mn[0])), f(float(mn[1]))))
        if z != 0:
            nodes.append("z_index = %d" % z)
        if t == TYPE_LABEL:
            nodes.append('text = "%s"' % esc(str(s.get("text", ""))))
            nodes.append("horizontal_alignment = %d" % int(s.get("horizontal_alignment", 1)))
            nodes.append("vertical_alignment = %d" % int(s.get("vertical_alignment", 1)))
            nodes.append("theme_override_font_sizes/font_size = %d" % int(s.get("font_size", 24)))
            col = s.get("color", [1, 1, 1, 1])
            nodes.append("theme_override_colors/font_color = Color(%s, %s, %s, %s)" % (f(col[0]), f(col[1]), f(col[2]), f(col[3])))
            fp = s.get("font_path", "")
            if fp == "":
                fp = df
            if fp != "" and fp in res_id_of:
                nodes.append('theme_override_fonts/font = ExtResource("%s")' % res_id_of[fp])
        elif t == TYPE_TEXTURE:
            tp = s.get("texture_path", "")
            if tp != "" and tp in res_id_of:
                nodes.append('texture = ExtResource("%s")' % res_id_of[tp])
            nodes.append("expand_mode = 1")
            nodes.append("stretch_mode = %d" % int(s.get("stretch_mode", 0)))
            al = float(s.get("modulate_alpha", 1.0))
            nodes.append("modulate = Color(1, 1, 1, %s)" % f(al))
        elif t == TYPE_BUTTON:
            nodes.append('text = "%s"' % esc(str(s.get("button_text", "按钮"))))
            nodes.append("theme_override_font_sizes/font_size = %d" % int(s.get("font_size", 22)))
            col2 = s.get("color", [1, 1, 1, 1])
            nodes.append("theme_override_colors/font_color = Color(%s, %s, %s, %s)" % (f(col2[0]), f(col2[1]), f(col2[2]), f(col2[3])))
            fp2 = s.get("font_path", "")
            if fp2 == "":
                fp2 = df
            if fp2 != "" and fp2 in res_id_of:
                nodes.append('theme_override_fonts/font = ExtResource("%s")' % res_id_of[fp2])
            ip = s.get("icon_path", "")
            if ip != "" and ip in res_id_of:
                nodes.append('icon = ExtResource("%s")' % res_id_of[ip])
            bp = s.get("bg_path", "")
            if bp != "" and bp in res_id_of:
                sid = "StyleBoxTexture_%d" % sub_id; sub_id += 1
                subs.append('[sub_resource type="StyleBoxTexture" id="%s"]' % sid)
                subs.append('texture = ExtResource("%s")' % res_id_of[bp])
                emit_nine_patch(subs, s)
                nodes.append('theme_override_styles/normal = SubResource("%s")' % sid)
                nodes.append('theme_override_styles/hover = SubResource("%s")' % sid)
                nodes.append('theme_override_styles/pressed = SubResource("%s")' % sid)
            else:
                # 纯色底板（无 bg_path 时）：bg_color + border_color + 圆角，normal/hover/pressed 同色避免露底色
                sid = "StyleBoxFlat_%d" % sub_id; sub_id += 1
                subs.append('[sub_resource type="StyleBoxFlat" id="%s"]' % sid)
                bc = s.get("bg_color", [0.12, 0.18, 0.16, 1])
                bc2 = s.get("border_color", [0.72, 0.67, 0.35, 1])
                bw = int(s.get("border_width", 2))
                cr = int(s.get("corner_radius", 8))
                subs.append("bg_color = Color(%s, %s, %s, %s)" % (f(bc[0]), f(bc[1]), f(bc[2]), f(bc[3])))
                subs.append("border_color = Color(%s, %s, %s, %s)" % (f(bc2[0]), f(bc2[1]), f(bc2[2]), f(bc2[3])))
                subs.append("border_width_left = %d" % bw)
                subs.append("border_width_top = %d" % bw)
                subs.append("border_width_right = %d" % bw)
                subs.append("border_width_bottom = %d" % bw)
                subs.append("corner_radius_top_left = %d" % cr)
                subs.append("corner_radius_top_right = %d" % cr)
                subs.append("corner_radius_bottom_left = %d" % cr)
                subs.append("corner_radius_bottom_right = %d" % cr)
                nodes.append('theme_override_styles/normal = SubResource("%s")' % sid)
                nodes.append('theme_override_styles/hover = SubResource("%s")' % sid)
                nodes.append('theme_override_styles/pressed = SubResource("%s")' % sid)
        elif t == TYPE_PANEL:
            bp2 = s.get("bg_path", "")
            if bp2 != "" and bp2 in res_id_of:
                sid2 = "StyleBoxTexture_%d" % sub_id; sub_id += 1
                subs.append('[sub_resource type="StyleBoxTexture" id="%s"]' % sid2)
                subs.append('texture = ExtResource("%s")' % res_id_of[bp2])
                emit_nine_patch(subs, s)
                nodes.append('theme_override_styles/panel = SubResource("%s")' % sid2)
            else:
                sid2 = "StyleBoxFlat_%d" % sub_id; sub_id += 1
                subs.append('[sub_resource type="StyleBoxFlat" id="%s"]' % sid2)
                bc = s.get("bg_color", [0.12, 0.18, 0.16, 1])
                bc2 = s.get("border_color", [0.72, 0.67, 0.35, 1])
                bw = int(s.get("border_width", 2))
                cr = int(s.get("corner_radius", 8))
                subs.append("bg_color = Color(%s, %s, %s, %s)" % (f(bc[0]), f(bc[1]), f(bc[2]), f(bc[3])))
                subs.append("border_color = Color(%s, %s, %s, %s)" % (f(bc2[0]), f(bc2[1]), f(bc2[2]), f(bc2[3])))
                subs.append("border_width_left = %d" % bw)
                subs.append("border_width_top = %d" % bw)
                subs.append("border_width_right = %d" % bw)
                subs.append("border_width_bottom = %d" % bw)
                subs.append("corner_radius_top_left = %d" % cr)
                subs.append("corner_radius_top_right = %d" % cr)
                subs.append("corner_radius_bottom_left = %d" % cr)
                subs.append("corner_radius_bottom_right = %d" % cr)
                nodes.append('theme_override_styles/panel = SubResource("%s")' % sid2)
        elif t == TYPE_ANIMATED:
            fr = s.get("frames", [])
            valid_fr = [fpv for fpv in fr if fpv != "" and fpv in res_id_of]
            if len(valid_fr) >= 2:
                asid = "AnimatedTexture_%d" % sub_id; sub_id += 1
                subs.append('[sub_resource type="AnimatedTexture" id="%s"]' % asid)
                subs.append("fps = %s" % f(float(s.get("fps", 8.0))))
                subs.append("frames = %d" % len(valid_fr))
                for i in range(len(valid_fr)):
                    subs.append('frame_%d/texture = ExtResource("%s")' % (i, res_id_of[valid_fr[i]]))
                nodes.append('texture = SubResource("%s")' % asid)
            elif len(valid_fr) == 1:
                nodes.append('texture = ExtResource("%s")' % res_id_of[valid_fr[0]])
            nodes.append("expand_mode = 1")
            nodes.append("stretch_mode = %d" % int(s.get("stretch_mode", 0)))
            nodes.append("modulate = Color(1, 1, 1, %s)" % f(float(s.get("modulate_alpha", 1.0))))
        elif t == TYPE_SPRITESHEET:
            shp = s.get("sheet_path", "")
            if shp != "" and shp in res_id_of:
                sw = 0.0; shh = 0.0
                p = os.path.join(PROJECT_ROOT, shp.replace("res://", "", 1))
                if os.path.isfile(p):
                    sw, shh = png_size(p)
                hf = max(1, int(s.get("hframes", 4)))
                vf = max(1, int(s.get("vframes", 4)))
                fw = sw / float(hf); fh2 = shh / float(vf)
                total = hf * vf
                fc = int(s.get("frame_count", 0))
                if fc > 0:
                    total = min(fc, total)
                if total <= 1:
                    nodes.append('texture = ExtResource("%s")' % res_id_of[shp])
                else:
                    atid = "AnimatedTexture_%d" % sub_id; sub_id += 1
                    subs.append('[sub_resource type="AnimatedTexture" id="%s"]' % atid)
                    subs.append("fps = %s" % f(float(s.get("fps", 8.0))))
                    subs.append("frames = %d" % total)
                    idx = 0
                    for r in range(vf):
                        for c in range(hf):
                            if idx >= total:
                                break
                            asid = "AtlasTexture_%d" % sub_id; sub_id += 1
                            subs.append('[sub_resource type="AtlasTexture" id="%s"]' % asid)
                            subs.append('atlas = ExtResource("%s")' % res_id_of[shp])
                            subs.append("region = Rect2(%s, %s, %s, %s)" % (f(c * fw), f(r * fh2), f(fw), f(fh2)))
                            subs.append('frame_%d/texture = SubResource("%s")' % (idx, asid))
                            idx += 1
                    nodes.append('texture = SubResource("%s")' % atid)
                nodes.append("expand_mode = 1")
                nodes.append("stretch_mode = %d" % int(s.get("stretch_mode", 0)))
                nodes.append("modulate = Color(1, 1, 1, %s)" % f(float(s.get("modulate_alpha", 1.0))))

    sub_count = sub_id - 1
    load_steps = 1 + len(res_order) + sub_count
    out = ['[gd_scene load_steps=%d format=3]' % load_steps]
    for pv in res_order:
        out.append('[ext_resource type="%s" path="%s" id="%s"]' % (res_type_of_map[pv], pv, res_id_of[pv]))
    for sline in subs:
        out.append(sline)
    for nline in nodes:
        out.append(nline)
    out.append("")
    return "\n".join(out)


def main() -> int:
    if not os.path.isfile(SRC):
        print("[ERROR] 源工程不存在: %s" % SRC)
        return 1
    with open(SRC, "r", encoding="utf-8") as fh:
        parsed = json.load(fh)
    doc = parsed.get("doc", parsed)
    tscn = export_tscn(doc)

    os.makedirs(os.path.dirname(OUT_TSCN), exist_ok=True)
    with open(OUT_TSCN, "w", encoding="utf-8", newline="") as fh:
        fh.write(tscn)
    print("[OK] 已生成场景: %s (%d 字节)" % (OUT_TSCN, len(tscn.encode("utf-8"))))

    # 刷新 manifest（保持 scenes.main_menu 指向正确路径）
    if os.path.isfile(MANIFEST):
        with open(MANIFEST, "r", encoding="utf-8") as fh:
            m = json.load(fh)
        m["generated_at"] = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
        m.setdefault("scenes", {})["main_menu"] = "res://art/auto_ui/scenes/main_menu.tscn"
        with open(MANIFEST, "w", encoding="utf-8", newline="") as fh:
            json.dump(m, fh, ensure_ascii=False, indent="\t")
        print("[OK] 已刷新 manifest: %s" % MANIFEST)

    # 自检
    assert tscn.startswith("[gd_scene load_steps="), "场景头缺失"
    assert 'name="EnterBtn"' in tscn, "缺少 EnterBtn 节点（main.gd 需要它关闭覆盖层）"
    print("[OK] 自检通过：含 EnterBtn、format 头正确")
    return 0


if __name__ == "__main__":
    sys.exit(main())

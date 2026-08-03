# =============================================================================
# taixuan_tscn.py —— 太玄UI编辑器导出逻辑的纯 Python 镜像（构建期自动化用）
# -----------------------------------------------------------------------------
# 与 addons/taixuan_ui_editor/data_manager.gd::export_tscn / export_spritesheet_tres
# 保持字段与排版一一对应，保证「AI 自动生成」与「编辑器手动导出」零偏差。
# 不依赖 Godot 运行时：图像尺寸用 Pillow 读取（精灵表切片需要真实像素）。
# 写入一律 newline=''（LF），规避 Windows CRLF 导致 Godot Parser Error 的坑。
# =============================================================================

import os
import json


# ------------------------- 基础格式化（镜像 GDScript _f / _esc）-------------------------

def f(v):
    """浮点格式化：去尾零，保留 3 位精度，且与 GDScript %.3f 一致。"""
    s = "%.3f" % float(v)
    while len(s) > 1 and s.endswith("0") and s[-2] != ".":
        s = s[:-1]
    if s.endswith("."):
        s += "0"
    return s


def esc(s):
    """字符串转义（.tscn 文本字符串用双引号包裹）。"""
    return str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def _res_type_of(path):
    ext = os.path.splitext(path)[1].lower().lstrip(".")
    if ext in ("ttf", "otf", "font"):
        return "FontFile"
    return "Texture2D"


def preset_anchors(preset):
    table = {
        0: [0.0, 0.0, 0.0, 0.0], 1: [1.0, 0.0, 1.0, 0.0],
        2: [0.0, 1.0, 0.0, 1.0], 3: [1.0, 1.0, 1.0, 1.0],
        4: [0.0, 0.5, 0.0, 0.5], 5: [1.0, 0.5, 1.0, 0.5],
        6: [0.5, 0.0, 0.5, 0.0], 7: [0.5, 1.0, 0.5, 1.0],
        8: [0.5, 0.5, 0.5, 0.5], 9: [0.0, 0.0, 0.0, 1.0],
        10: [0.0, 0.0, 1.0, 0.0], 11: [1.0, 0.0, 1.0, 1.0],
        12: [0.0, 1.0, 1.0, 1.0], 13: [0.5, 0.0, 0.5, 1.0],
        14: [0.0, 0.5, 1.0, 0.5], 15: [0.0, 0.0, 1.0, 1.0],
    }
    return table.get(int(preset), [0.0, 0.0, 0.0, 0.0])


# ------------------------- 图像尺寸（精灵表切片需要）-------------------------

def image_size(path):
    """返回 (w, h)；读不到返回 (0, 0)。"""
    try:
        from PIL import Image
        with Image.open(path) as im:
            return im.size
    except Exception:
        return (0, 0)


# ------------------------- 九宫格字段（镜像 _emit_nine_patch）-------------------------

def _emit_nine_patch(subs, s):
    subs.append("nine_patch_stretch = %s" % ("true" if bool(s.get("bg_nine_patch", True)) else "false"))
    subs.append("margin_left = %s" % f(float(s.get("bg_margin_left", 0))))
    subs.append("margin_top = %s" % f(float(s.get("bg_margin_top", 0))))
    subs.append("margin_right = %s" % f(float(s.get("bg_margin_right", 0))))
    subs.append("margin_bottom = %s" % f(float(s.get("bg_margin_bottom", 0))))
    subs.append("axis_stretch_horizontal = %d" % int(s.get("bg_axis_h", 0)))
    subs.append("axis_stretch_vertical = %d" % int(s.get("bg_axis_v", 0)))


# ------------------------- 主导出：.tscn（镜像 export_tscn）-------------------------

def export_tscn(path, doc):
    canvas = doc.get("canvas", {})
    cw = int(canvas.get("width", 768))
    ch = int(canvas.get("height", 1344))
    bg = canvas.get("background_color", [0.0, 0.0, 0.0, 0.0])
    controls = doc.get("controls", [])
    df = doc.get("default_font", "")   # 项目默认字体（回退基准）

    # 收集外部资源
    res_order, res_id_of, res_type_of = [], {}, {}
    ridx = 1
    for c in controls:
        s = c.get("style", {})
        t = c.get("type", "")
        paths = []
        if t == "TextureRect":
            paths.append(s.get("texture_path", ""))
        elif t == "Button":
            paths.append(s.get("icon_path", ""))
            paths.append(s.get("bg_path", ""))
        elif t == "Panel":
            paths.append(s.get("bg_path", ""))
        elif t == "AnimatedTexture":
            for fp in s.get("frames", []):
                paths.append(fp)
        elif t == "SpriteSheet":
            paths.append(s.get("sheet_path", ""))
        # 字体：Label/Button 优先自身 font_path，否则回退项目默认字体
        if t in ("Label", "Button"):
            fp = s.get("font_path", "")
            if not fp:
                fp = df
            paths.append(fp)
        else:
            paths.append(s.get("font_path", ""))
        for p in paths:
            if p and p not in res_id_of:
                res_id_of[p] = str(ridx)
                res_type_of[p] = _res_type_of(p)
                res_order.append(p)
                ridx += 1

    subs = []
    sub_id = 1
    nodes = []

    nodes.append('[node name="UI" type="Control"]')
    nodes.append("layout_mode = 3")
    nodes.append("offset_left = 0")
    nodes.append("offset_top = 0")
    nodes.append("offset_right = %d" % cw)
    nodes.append("offset_bottom = %d" % ch)

    if len(bg) >= 4 and bg[3] > 0.0:
        nodes.append('[node name="BgColor" type="ColorRect" parent="."]')
        nodes.append("layout_mode = 1")
        nodes.append("anchors_preset = 15")
        nodes.append("offset_left = 0")
        nodes.append("offset_top = 0")
        nodes.append("offset_right = %d" % cw)
        nodes.append("offset_bottom = %d" % ch)
        nodes.append("color = Color(%s, %s, %s, %s)" % (f(bg[0]), f(bg[1]), f(bg[2]), f(bg[3])))

    ref = doc.get("reference_image", {})
    if isinstance(ref, dict) and ref.get("path", ""):
        rpath = str(ref["path"])
        rid = res_id_of.get(rpath, "")
        if rid:
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
            nodes.append("modulate = Color(1, 1, 1, %s)" % f(float(ref.get("opacity", 1.0))))
            if not bool(ref.get("visible", True)):
                nodes.append("visible = false")

    for c in controls:
        t = c.get("type", "")
        nm = str(c.get("name", "Node"))
        pos = c.get("position", [0, 0])
        sz = c.get("size", [0, 0])
        mn = c.get("min_size", [0, 0])
        z = int(c.get("z_index", 0))
        preset = int(c.get("anchor_preset", 0))
        s = c.get("style", {})
        x = float(pos[0]); y = float(pos[1])
        w = float(sz[0]); h = float(sz[1])
        node_type = t
        if t in ("AnimatedTexture", "SpriteSheet"):
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

        if t == "Label":
            nodes.append('text = "%s"' % esc(str(s.get("text", ""))))
            nodes.append("horizontal_alignment = %d" % int(s.get("horizontal_alignment", 1)))
            nodes.append("vertical_alignment = %d" % int(s.get("vertical_alignment", 1)))
            nodes.append("theme_override_font_sizes/font_size = %d" % int(s.get("font_size", 24)))
            col = s.get("color", [1, 1, 1, 1])
            nodes.append("theme_override_colors/font_color = Color(%s, %s, %s, %s)" % (f(col[0]), f(col[1]), f(col[2]), f(col[3])))
            fp = s.get("font_path", "")
            if not fp:
                fp = df
            if fp and res_id_of.get(fp):
                nodes.append('theme_override_fonts/font = ExtResource("%s")' % res_id_of[fp])
        elif t == "TextureRect":
            tp = s.get("texture_path", "")
            if tp and res_id_of.get(tp):
                nodes.append('texture = ExtResource("%s")' % res_id_of[tp])
            nodes.append("expand_mode = 1")
            nodes.append("stretch_mode = %d" % int(s.get("stretch_mode", 0)))
            al = float(s.get("modulate_alpha", 1.0))
            nodes.append("modulate = Color(1, 1, 1, %s)" % f(al))
        elif t == "Button":
            nodes.append('text = "%s"' % esc(str(s.get("button_text", "按钮"))))
            nodes.append("theme_override_font_sizes/font_size = %d" % int(s.get("font_size", 22)))
            col2 = s.get("color", [1, 1, 1, 1])
            nodes.append("theme_override_colors/font_color = Color(%s, %s, %s, %s)" % (f(col2[0]), f(col2[1]), f(col2[2]), f(col2[3])))
            fp2 = s.get("font_path", "")
            if not fp2:
                fp2 = df
            if fp2 and res_id_of.get(fp2):
                nodes.append('theme_override_fonts/font = ExtResource("%s")' % res_id_of[fp2])
            ip = s.get("icon_path", "")
            if ip and res_id_of.get(ip):
                nodes.append('icon = ExtResource("%s")' % res_id_of[ip])
            bp = s.get("bg_path", "")
            if bp and res_id_of.get(bp):
                sid = "StyleBoxTexture_%d" % sub_id; sub_id += 1
                subs.append('[sub_resource type="StyleBoxTexture" id="%s"]' % sid)
                subs.append('texture = ExtResource("%s")' % res_id_of[bp])
                _emit_nine_patch(subs, s)
                nodes.append('theme_override_styles/normal = SubResource("%s")' % sid)
                nodes.append('theme_override_styles/hover = SubResource("%s")' % sid)
                nodes.append('theme_override_styles/pressed = SubResource("%s")' % sid)
        elif t == "Panel":
            bp2 = s.get("bg_path", "")
            if bp2 and res_id_of.get(bp2):
                sid2 = "StyleBoxTexture_%d" % sub_id; sub_id += 1
                subs.append('[sub_resource type="StyleBoxTexture" id="%s"]' % sid2)
                subs.append('texture = ExtResource("%s")' % res_id_of[bp2])
                _emit_nine_patch(subs, s)
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
        elif t == "AnimatedTexture":
            fr = s.get("frames", [])
            valid_fr = [fp for fp in fr if fp and res_id_of.get(fp)]
            if len(valid_fr) >= 2:
                asid = "AnimatedTexture_%d" % sub_id; sub_id += 1
                subs.append('[sub_resource type="AnimatedTexture" id="%s"]' % asid)
                subs.append("fps = %s" % f(float(s.get("fps", 8.0))))
                subs.append("frames = %d" % len(valid_fr))
                for i, fp in enumerate(valid_fr):
                    subs.append('frame_%d/texture = ExtResource("%s")' % (i, res_id_of[fp]))
                nodes.append('texture = SubResource("%s")' % asid)
            elif len(valid_fr) == 1:
                nodes.append('texture = ExtResource("%s")' % res_id_of[valid_fr[0]])
            nodes.append("expand_mode = 1")
            nodes.append("stretch_mode = %d" % int(s.get("stretch_mode", 0)))
            nodes.append("modulate = Color(1, 1, 1, %s)" % f(float(s.get("modulate_alpha", 1.0))))
        elif t == "SpriteSheet":
            shp = s.get("sheet_path", "")
            if shp and res_id_of.get(shp):
                sw, shh = image_size(_resolve_local(shp))
                hf = max(1, int(s.get("hframes", 4)))
                vf = max(1, int(s.get("vframes", 4)))
                fw = (sw / float(hf)) if sw else 0.0
                fh = (shh / float(vf)) if shh else 0.0
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
                            subs.append("region = Rect2(%s, %s, %s, %s)" % (f(c * fw), f(r * fh), f(fw), f(fh)))
                            subs.append("frame_%d/texture = SubResource(\"%s\")" % (idx, asid))
                            idx += 1
                    nodes.append('texture = SubResource("%s")' % atid)
                nodes.append("expand_mode = 1")
                nodes.append("stretch_mode = %d" % int(s.get("stretch_mode", 0)))
                nodes.append("modulate = Color(1, 1, 1, %s)" % f(float(s.get("modulate_alpha", 1.0))))

    sub_count = sub_id - 1
    load_steps = 1 + len(res_order) + sub_count
    out = ['[gd_scene load_steps=%d format=3]' % load_steps]
    for p in res_order:
        out.append('[ext_resource type="%s" path="%s" id="%s"]' % (res_type_of[p], p, res_id_of[p]))
    out.extend(subs)
    out.extend(nodes)
    out.append("")
    _write_text(path, "\n".join(out))
    return True


# ------------------------- SpriteFrames.tres 导出（镜像 export_spritesheet_tres）-------------------------

def export_spritesheet_tres(out_path, sheet_path, hframes, vframes, fps, loop, frame_count=0, sheet_local=""):
    sw, shh = image_size(sheet_local or _resolve_local(sheet_path))
    hf = max(1, int(hframes)); vf = max(1, int(vframes))
    fw = (sw / float(hf)) if sw else 0.0
    fh = (shh / float(vf)) if shh else 0.0
    total = hf * vf
    if frame_count > 0:
        total = min(frame_count, total)
    dur = 1.0 / max(0.001, float(fps))
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (2 + total * 2), ""]
    lines.append('[ext_resource type="Texture2D" path="%s" id="1"]' % sheet_path)
    lines.append("")
    sf_ids = []
    idx = 0
    for r in range(vf):
        for c in range(hf):
            if idx >= total:
                break
            aid = "AtlasTexture_%d" % (idx + 1)
            sid = "SpriteFrame_%d" % (idx + 1)
            lines.append('[sub_resource type="AtlasTexture" id="%s"]' % aid)
            lines.append('atlas = ExtResource("1")')
            lines.append("region = Rect2(%s, %s, %s, %s)" % (f(c * fw), f(r * fh), f(fw), f(fh)))
            lines.append("")
            lines.append('[sub_resource type="SpriteFrame" id="%s"]' % sid)
            lines.append('texture = SubResource("%s")' % aid)
            lines.append("duration = %s" % f(dur))
            lines.append("")
            sf_ids.append(sid)
            idx += 1
    fr_refs = ", ".join('SubResource("%s")' % sid for sid in sf_ids)
    lines.append("[resource]")
    lines.append("animations = [{")
    lines.append('"frames": [%s],' % fr_refs)
    lines.append('"loop": %s,' % ("true" if loop else "false"))
    lines.append('"name": "default",')
    lines.append('"speed": %s' % f(fps))
    lines.append("}]")
    lines.append("")
    _write_text(out_path, "\n".join(lines))
    return True


# ------------------------- 本地路径解析（res:// -> 项目绝对路径）-------------------------
# 由调用方通过 set_res_root 注入项目根，默认用当前工作目录。

_RES_ROOT = os.getcwd()


def set_res_root(root):
    global _RES_ROOT
    _RES_ROOT = root


def _resolve_local(res_path):
    if not res_path:
        return ""
    if os.path.isabs(res_path):
        return res_path
    if res_path.startswith("res://"):
        return os.path.join(_RES_ROOT, res_path[len("res://"):])
    return os.path.join(_RES_ROOT, res_path)


def _write_text(path, txt):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(txt)
    return True

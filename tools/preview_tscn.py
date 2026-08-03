# -*- coding: utf-8 -*-
"""
.tscn 预览器（离线近似渲染）
把 Godot 4.7 的 .tscn（绝对定位 layout_mode=0 + offset_*）解析成一张 PNG，
用于在没有 GPU/Godot 的环境下自查布局（坐标、尺寸、溢出、重叠、颜色）。
非真实渲染，仅复现几何与文本位置，够抓"挤在左上角 / 超出画布 / 叠错"类错误。
用法：python tools/preview_tscn.py <scene.tscn> [out.png]
"""
import re, os, sys
from PIL import Image, ImageDraw, ImageFont

PROJECT = r'E:\Xiuxian\taixuanzongmenlu'

def res_to_local(p):
    if p.startswith('res://'):
        p = p[len('res://'):]
    return os.path.join(PROJECT, p.replace('/', os.sep))

def parse_color(s):
    m = re.search(r'Color\(([\d.]+),\s*([\d.]+),\s*([\d.]+)(?:,\s*([\d.]+))?\)', s)
    if not m: return (0,0,0,255)
    r,g,b = float(m.group(1)),float(m.group(2)),float(m.group(3))
    a = float(m.group(4)) if m.group(4) else 1.0
    return (int(r*255), int(g*255), int(b*255), int(a*255))

def f(v):
    try: return float(v)
    except: return 0.0

def parse(path):
    text = open(path, encoding='utf-8').read()
    lines = text.split('\n')
    ext, sub, nodes = {}, {}, []
    i, n = 0, len(lines)
    while i < n:
        line = lines[i]
        if line.startswith('[ext_resource'):
            m = re.search(r'path="([^"]+)"\s+id="([^"]+)"', line)
            if m: ext[m.group(2)] = m.group(1)
        elif line.startswith('[sub_resource'):
            sid = re.search(r'id="([^"]+)"', line).group(1)
            d = {}; i += 1
            while i < n and not lines[i].startswith('['):
                kv = re.match(r'(\w+)\s*=\s*(.+)', lines[i])
                if kv: d[kv.group(1)] = kv.group(2).strip()
                i += 1
            sub[sid] = d; continue
        elif line.startswith('[node'):
            m = re.search(r'name="([^"]+)"\s+type="([^"]+)"(?:\s+parent="([^"]+)")?', line)
            d = {'name': m.group(1), 'type': m.group(2), 'parent': m.group(3), 'props': {}}
            i += 1
            while i < n and not lines[i].startswith('['):
                kv = re.match(r'([\w/]+)\s*=\s*(.+)', lines[i])
                if kv: d['props'][kv.group(1)] = kv.group(2).strip()
                i += 1
            nodes.append(d); continue
        i += 1
    return ext, sub, nodes

def compute_rects(nodes, W=480, H=854):
    # 线性扫描：Godot .tscn 父节点先于子节点出现；父名在本文件唯一，子名可重复但不做父
    abs_rect = {}
    for nd in nodes:
        pr = nd['props']
        pname = nd['parent']
        if pname in (None, '.'):
            # 根节点：layout_mode=1 全屏填充时按画布尺寸算；否则按 offset
            if f(pr.get('anchor_right','0'))==1.0 and f(pr.get('anchor_bottom','0'))==1.0:
                l,t,r,b = 0.0,0.0,float(W),float(H)
            else:
                l = f(pr.get('offset_left','0')); t = f(pr.get('offset_top','0'))
                r = f(pr.get('offset_right','0')); b = f(pr.get('offset_bottom','0'))
        else:
            pr2 = abs_rect.get(pname, (0.0,0.0,0.0,0.0))
            ox, oy = pr2[0], pr2[1]
            l = ox + f(pr.get('offset_left','0')); t = oy + f(pr.get('offset_top','0'))
            r = ox + f(pr.get('offset_right','0')); b = oy + f(pr.get('offset_bottom','0'))
        nd['rect'] = (l,t,r,b)
        abs_rect[nd['name']] = (l,t,r,b)

def main():
    scene = sys.argv[1] if len(sys.argv)>1 else os.path.join(PROJECT,'ui','home_page.tscn')
    out = sys.argv[2] if len(sys.argv)>2 else os.path.join(PROJECT,'art','_preview','home_page_preview.png')
    ext, sub, nodes = parse(scene)
    W,H = 480,854
    compute_rects(nodes, W, H)
    canvas = Image.new('RGBA',(W,H),(20,20,20,255))
    # 字体
    font_cache = {}
    def font(sz):
        if sz not in font_cache:
            try: font_cache[sz] = ImageFont.truetype(os.path.join(PROJECT,'art','fonts','LXGWWenKai-Regular.ttf'), max(10,int(sz)))
            except: font_cache[sz] = ImageFont.load_default()
        return font_cache[sz]
    def overlay(rect, fill):
        layer = Image.new('RGBA',(W,H),(0,0,0,0))
        d = ImageDraw.Draw(layer)
        d.rectangle([rect[0],rect[1],rect[2],rect[3]], fill=fill)
        return Image.alpha_composite(canvas, layer)
    def overlay_round(rect, fill, r):
        layer = Image.new('RGBA',(W,H),(0,0,0,0))
        d = ImageDraw.Draw(layer)
        d.rounded_rectangle([rect[0],rect[1],rect[2],rect[3]], radius=r, fill=fill)
        return Image.alpha_composite(canvas, layer)

    def render_node(nd):
        nonlocal canvas
        pr = nd['props']; rect = nd['rect']; t = nd['type']
        # 背景图
        if 'texture' in pr and t=='TextureRect':
            p = res_to_local(ext.get(pr['texture'].strip('ExtResource("')[:-2], '')) if pr['texture'].startswith('ExtResource') else pr['texture']
            if os.path.exists(p):
                try:
                    img = Image.open(p).convert('RGBA').resize((int(rect[2]-rect[0]), int(rect[3]-rect[1])))
                    canvas.paste(img,(int(rect[0]),int(rect[1])))
                except Exception as e: print('tex err',e)
        # 颜色矩形
        if t=='ColorRect' and 'color' in pr:
            canvas = overlay(rect, parse_color(pr['color']))
        # 面板
        if t=='Panel' and 'theme_override_styles/panel' in pr:
            sid = pr['theme_override_styles/panel'].strip('SubResource("')[:-2]
            st = sub.get(sid,{})
            bg = parse_color(st.get('bg_color','Color(0.118,0.169,0.157,1)'))
            bw = int(f(st.get('border_width_left','1')))
            bcol = parse_color(st.get('border_color','Color(0.784,0.659,0.416,1)'))
            rad = int(f(st.get('corner_radius_top_left','0')))
            canvas = overlay_round(rect, bg, rad)
            if bw>0:
                layer = Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(layer)
                d.rounded_rectangle([rect[0],rect[1],rect[2],rect[3]], radius=rad, outline=bcol, width=bw)
                canvas = Image.alpha_composite(canvas, layer)
        # 图标按钮
        for key in ('texture_normal','texture_pressed'):
            if key in pr:
                rid = pr[key].strip('ExtResource("')[:-2]
                p = res_to_local(ext.get(rid,''))
                if os.path.exists(p):
                    try:
                        img = Image.open(p).convert('RGBA').resize((int(rect[2]-rect[0]), int(rect[3]-rect[1])))
                        canvas.paste(img,(int(rect[0]),int(rect[1])),img)
                    except Exception as e: print('icon err',e)
        # 文字
        if t=='Label' and 'text' in pr:
            txt = pr['text'].strip('"')
            sz = 15
            for k,v in pr.items():
                if k.endswith('font_size'): sz = f(v)
            d = ImageDraw.Draw(canvas)
            d.text((rect[0]+4, rect[1]+4), txt, font=font(sz), fill=(237,230,214,255))
    compute_rects(nodes)
    for nd in nodes:
        render_node(nd)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    canvas.convert('RGB').save(out)
    print('saved', out)
    # 调试：打印根与几个关键节点矩形
    for nd in nodes:
        if nd['name'] in ('HomePage','BottomBar','C1_宗门正殿','C5_快捷入口','TopBar'):
            print(nd['name'], [round(x) for x in nd['rect']])

if __name__=='__main__':
    main()

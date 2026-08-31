# -*- coding: utf-8 -*-
"""
check_godot3_legacy.py —— Godot 3.x 旧语法残留扫描（报告模式·非阻断）

《太玄宗门录》Godot 4.7 项目铁律：禁用任何 Godot 3.x 旧语法，一律用 Godot 4 语法。
pre_f5 / gdtoolkit 宽松扫描抓不到这些编译期/作用域错误（如 nil、旧式 export），
须靠本扫描兜底（报告模式，exit 0，绝不改变 pre_f5 退出码）。

致命旧语法清单（命中即 Parse/Compile Error，Godot 4 直接崩）：
  nil            -> null
  export var     -> @export var
  onready var    -> @onready var
  yield(         -> await
  .instance()    -> .instantiate()
  setget        -> getter/setter 或 @property
  funcref(       -> Callable(obj,"m") 或 obj.method
  ColorN(        -> Color.from_string("red", Color()) 或 Color.RED
  rand_range(    -> randf_range(
  to_json(       -> JSON.stringify(
  parse_json(    -> JSON.parse_string(
  rect_*         -> position/size/scale/rotation/pivot_offset/...
  margin_*       -> offset_*

用法：python check_godot3_legacy.py   （自动定位项目根目录并扫描全部 *.gd）
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # 项目根 = tools/..

# (正则, 旧语法标签, Godot4 替代, 严重度)
# 负向后顾说明：
#   (?<![\w])   前面不能是单词字符（允许 . 等，用于抓 .rect_position 点访问属性）
#   (?<![\w@])  额外排除 @，用于 export/onready 修饰符（避免误报 @export/@onready）
PATTERNS = [
    (r'(?<![\w])nil(?![\w])', 'nil', 'null', 'hard'),
    (r'(?<![\w@])export\s+var', 'export var', '@export var', 'hard'),
    (r'(?<![\w@])export\s*\(', 'export(...)', '@export', 'hard'),
    (r'(?<![\w@])onready\s+var', 'onready var', '@onready var', 'hard'),
    (r'(?<![\w])yield\s*\(', 'yield(', 'await', 'hard'),
    (r'(?<![\w])setget\b', 'setget', 'getter/setter 或 @property', 'hard'),
    (r'\.instance\s*\(\s*\)', '.instance()', '.instantiate()', 'hard'),
    (r'(?<![\w])funcref\s*\(', 'funcref(', 'Callable(obj,"m") 或 obj.method', 'hard'),
    (r'(?<![\w])ColorN\s*\(', 'ColorN(', 'Color.from_string("red", Color()) 或 Color.RED', 'hard'),
    (r'(?<![\w])rand_range\s*\(', 'rand_range(', 'randf_range(', 'hard'),
    (r'(?<![\w])to_json\s*\(', 'to_json(', 'JSON.stringify(', 'hard'),
    (r'(?<![\w])parse_json\s*\(', 'parse_json(', 'JSON.parse_string(', 'hard'),
    (r'(?<![\w])(rect_position|rect_size|rect_scale|rect_rotation|rect_pivot_offset|rect_global_position|rect_min_size|rect_minimum_size)\b',
     'rect_*', 'position/size/scale/rotation/pivot_offset/global_position/min_size/minimum_size', 'hard'),
    (r'(?<![\w])(margin_left|margin_top|margin_right|margin_bottom)\b',
     'margin_*', 'offset_left/top/right/bottom', 'hard'),
]

COMPILED = [(re.compile(p), old, new, sev) for p, old, new, sev in PATTERNS]


def code_only(line):
    """剥离注释与字符串字面，返回纯净代码区，避免字符串/注释内的字面误报。"""
    s = line.split('#', 1)[0]
    s = re.sub(r'"[^"\n]*"', ' "" ', s)
    s = re.sub(r"'[^'\n]*'", " '' ", s)
    return s


def scan():
    hits = []  # (rel, ln, old, new, sev, snippet)
    for root, dirs, files in os.walk(ROOT):
        # 排除隐藏/缓存/第三方插件目录，避免扫到编辑器插件噪音
        dirs[:] = [d for d in dirs
                   if d not in ('.git', '__pycache__', '.godot', 'addons')
                   and not d.startswith('.')]
        for fn in files:
            if not fn.endswith('.gd'):
                continue
            fp = os.path.join(root, fn)
            rel = os.path.relpath(fp, ROOT)
            try:
                with open(fp, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
            except Exception:
                continue
            for ln, raw in enumerate(lines, 1):
                code = code_only(raw)
                for rx, old, new, sev in COMPILED:
                    if rx.search(code):
                        hits.append((rel, ln, old, new, sev, raw.strip()[:90]))
                        break  # 同一行多个模式只报一次，减少噪音
    return hits


def main():
    hits = scan()
    hard = [h for h in hits if h[4] == 'hard']
    print("Godot 3.x 旧语法残留扫描（报告模式·非阻断）")
    print("-" * 64)
    if not hits:
        print("  [OK] 未检出 Godot 3.x 致命旧语法残留")
        return 0
    print("  [HARD] 检出 %d 处致命旧语法（Godot 4 会直接 Parse/Compile Error）：" % len(hard))
    for rel, ln, old, new, sev, snip in hard:
        print("    %s:%d  %s -> 应改为 %s" % (rel, ln, old, new))
    print("-" * 64)
    print("  [REPORT-ONLY] 本扫描为报告模式，不改变 pre_f5 退出码。")
    return 0  # 非阻断


if __name__ == '__main__':
    sys.exit(main())

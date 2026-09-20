# -*- coding: utf-8 -*-
# 未声明标识符扫描（pre_f5 第 32 道闸门）
# 立闸背景：gdtoolkit 只做语法解析、不解析标识符；pre_f5 的「类型名存在性扫描」只查类型名。
#   事故：S34 _结算王朝_S34 引用了从未声明的 `王朝关系衰减基数`，
#         「113 files PARSE OK」全绿、类型名扫描全绿，但 Godot 一打开就报
#         Identifier not found —— F5 必崩。故立此闸兜底。
# 白名单来源（全部自动收集，禁止手抄）：
#   1) project.godot [autoload] 单例名
#   2) 全仓 .gd 的 `class_name X` 声明
#   3) Godot 4 内置类型/全局函数/常量（下表）
# 铁律：断言必须走剥注释视图（`"x" in text` 会被注释蒙混）；每个切片视图各自剥。
import os, re, sys, glob

GD_BUILTIN = set("""
void bool int float String StringName Vector2 Vector2i Vector3 Vector3i Vector4 Vector4i
Rect2 Rect2i Transform2D Transform3D Plane Quaternion AABB Basis Projection RID Callable Signal
Array Dictionary PackedByteArray PackedInt32Array PackedInt64Array PackedFloat32Array
PackedFloat64Array PackedStringArray PackedVector2Array PackedVector3Array PackedVector4Array
PackedColorArray Node Node2D Node3D Control CanvasItem CanvasLayer Object Resource RefCounted
Texture2D Texture3D Image ImageTexture ImageTexture3D AtlasTexture GradientTexture2D
FileAccess DirAccess FileAccess File HTTPRequest JSON XML HTTPClient OS Time Input Engine
abs absi acos acosh asin asinh atan atan2 atanh ceil clamp clampf clampi cos cosh
deg_to_rad exp floor floori fmod fposmod inverse_lerp is_equal_approx is_finite is_inf
is_nan is_same is_zero_approx lerp lerpf lerp_angle log max maxf maxi min minf mini
move_toward posmod pow print print_rich print_verbose printerr printraw printt prints
push_error push_warning rad_to_deg randf randf_range rand_from_seed randi randi_range
randomize remap round roundi sign signf sin sinh smoothstep snapped snappedf sqrt
stepify str tan tanh wrap wrapf wrapi type_convert typeof
len range error_string instantiate load preload assert is_instance_valid
OK FAILED ERR_ DOUBLED_PI INF NAN PI TAU
TYPE_NIL TYPE_BOOL TYPE_INT TYPE_FLOAT TYPE_STRING TYPE_VECTOR2 TYPE_RECT2 TYPE_VECTOR3
TYPE_TRANSFORM2D TYPE_PLANE TYPE_QUATERNION TYPE_AABB TYPE_BASIS TYPE_TRANSFORM3D
TYPE_PROJECTION TYPE_COLOR TYPE_STRING_NAME TYPE_NODE_PATH TYPE_RID TYPE_OBJECT
TYPE_INPUT_EVENT TYPE_DICTIONARY TYPE_ARRAY TYPE_PACKED_BYTE_ARRAY TYPE_MAX
NOTIFICATION_ KEY_ MOUSE_BUTTON_ JOY_BUTTON_ SIDE_ CORNER_ ORIENTATION_ VERTICAL HORIZONTAL
Disciple Item Quest Lore Alchemy ItemSystem EventSystem
""".split())

GD_KEYWORDS = set("""
and or not if elif else for while break continue pass return match when
var const func class extends signal enum static export onready
self null true false in is as yield await super setget breakpoint
""".split())


def strip_comments_and_strings(src: str) -> str:
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == '#':
            j = src.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i)); i = j
        elif c == '"':
            j = i + 1
            while j < n:
                if src[j] == '\\':
                    j += 2; continue
                if src[j] == '"':
                    j += 1; break
                j += 1
            out.append(' ' * (j - i)); i = j
        elif c == "'":
            j = src.find("'", i + 1)
            j = n if j < 0 else j + 1
            out.append(' ' * (j - i)); i = j
        else:
            out.append(c); i += 1
    return ''.join(out)


def collect_global_names(root: str) -> set:
    """自动收集 Autoload 单例 + class_name 声明（禁止手抄）"""
    names = set()
    pg = os.path.join(root, 'project.godot')
    if os.path.exists(pg):
        s = open(pg, encoding='utf-8').read()
        m = re.search(r'\[autoload\](.*?)(?=\n\[|\Z)', s, re.S)
        if m:
            for line in m.group(1).strip().split('\n'):
                if '=' in line:
                    names.add(line.split('=')[0].strip().strip('"'))
    for p in glob.glob(os.path.join(root, '**', '*.gd'), recursive=True):
        if '.scratch_backup' in p or '.godot' in p:
            continue
        try:
            src = open(p, encoding='utf-8').read()
        except Exception:
            continue
        for mm in re.finditer(r'^\s*@?tool\s*$|^\s*class_name\s+([A-Za-z_]\w*)', src, re.M):
            if mm.group(1):
                names.add(mm.group(1))
    return names


def scan_file(path: str, globals_: set):
    raw = open(path, 'rb').read()
    if raw.startswith(b'\xef\xbb\xbf'):
        return ['BOM 文件，拒绝扫描']
    code = strip_comments_and_strings(raw.decode('utf-8'))

    declared = set()
    for m in re.finditer(r'^\s*(?:@\w+\s+)*(?:static\s+)?(?:const|var|func|class|enum|signal)\s+([A-Za-z_\u4e00-\u9fff][\w\u4e00-\u9fff]*)', code, re.M):
        declared.add(m.group(1))
    for m in re.finditer(r'^\s+var\s+([A-Za-z_\u4e00-\u9fff][\w\u4e00-\u9fff]*)', code, re.M):
        declared.add(m.group(1))
    # 形参：func / signal / lambda(匿名 func) 三种声明形式都要收
    for m in re.finditer(r'(?:func|signal)\s*[\w\u4e00-\u9fff]*\s*\(([^)]*)\)', code):
        for p in m.group(1).split(','):
            mm = re.match(r'\s*([A-Za-z_\u4e00-\u9fff][\w\u4e00-\u9fff]*)', p)
            if mm:
                declared.add(mm.group(1))
    # enum 花括号成员：enum 状态 { 战前准备, 回合执行, 结算收尾 }
    for m in re.finditer(r'^\s*enum\s+[\w\u4e00-\u9fff]*\s*\{([^}]*)\}', code, re.M):
        for p in m.group(1).split(','):
            mm = re.match(r'\s*([A-Za-z_\u4e00-\u9fff][\w\u4e00-\u9fff]*)', p)
            if mm:
                declared.add(mm.group(1))
    for m in re.finditer(r'\bfor\s+([A-Za-z_\u4e00-\u9fff][\w\u4e00-\u9fff]*)\s+in\b', code):
        declared.add(m.group(1))
    for m in re.finditer(r'\bcatch\s*\(\s*([A-Za-z_\u4e00-\u9fff][\w\u4e00-\u9fff]*)', code):
        declared.add(m.group(1))

    bad = {}
    for m in re.finditer(r'(?<![\w.\u4e00-\u9fff])([A-Za-z_\u4e00-\u9fff][\w\u4e00-\u9fff]*)', code):
        name = m.group(1)
        # 只扫【中文标识符】：Godot 内置类/常量/全局函数全是 ASCII，
        # 而本项目自定义的逻辑标识符（持久字段、const 常量、函数名）绝大多数是中文。
        # 这一条把信噪比从「101/113 文件误报」拉到接近 0，且恰好覆盖真实事故面
        # （S34 事故里的 `王朝关系衰减基数` 就是中文标识符）。
        if not re.search(r'[\u4e00-\u9fff]', name):
            continue
        if name in GD_KEYWORDS or name in GD_BUILTIN or name in globals_ or name in declared:
            continue
        # 排除字典键访问  foo["名"] / foo.名
        s_pos, e_pos = m.start(), m.end()
        prev = code[max(0, s_pos - 2):s_pos]
        nxt = code[e_pos:e_pos + 2]
        if '"' in prev or "'" in prev or '"' in nxt or "'" in nxt:
            continue
        if prev.endswith('.'):
            continue
        line = code[:s_pos].count('\n') + 1
        bad.setdefault(name, line)
    return bad


def main(root='.'):
    globals_ = collect_global_names(root)
    print('自动收集全局名 %d 个（Autoload %s）' % (len(globals_), 'project.godot'))
    files = [p for p in glob.glob(os.path.join(root, '**', '*.gd'), recursive=True)
             if '.scratch_backup' not in p and '.godot' not in p
             and 'backup' not in os.path.relpath(p, root).split(os.sep)]
    total, badfiles = 0, 0
    for p in sorted(files):
        bad = scan_file(p, globals_)
        total += 1
        if isinstance(bad, dict) and bad:
            badfiles += 1
            print('  [%s]' % os.path.relpath(p, root))
            for n in sorted(bad, key=lambda x: bad[x]):
                print('      L%-6d %s' % (bad[n], n))
    print('扫描 %d 个 .gd，可疑 %d 个文件' % (total, badfiles))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else '.'))

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# static_check.py —— GDScript 轻量静态扫描（pre_f5_check 第 8 闸门）
#
# 不依赖 Godot，纯 Python 文本解析，在 F5 之前拦住三类「只有 Godot 真机才报」的崩溃：
#   A. 孤立缩进        —— 某行缩进比上一行深，但上一行不是开块语句
#                          → Godot: "Expected statement, found Indent"
#                          （2026-07-20 战斗结算面板连环 class body 崩溃根因）
#   B. class body 裸语句 —— class 作用域（func 之外）出现非声明类语句
#                          → Godot: "Unexpected identifier in class body"（上同次连锁）
#   C. 跨作用域变量引用 —— var 声明在更深的块内（if/for/while），却被更浅层引用
#                          → Godot: "Identifier 'X' not declared in the current scope"
#                          （2026-07-20 离山汇总面板 7 个 not declared 崩溃中的 4 个根因）
#
# 设计原则：只做「确定性强、零误报」的阻断级检查。GDScript 的 { } [ ] ( ) 只用于
# 字典/数组字面量与表达式延续，绝不表示代码块；本扫描器据此跨行追踪括号深度，
# 处于「字面量/表达式延续」状态的行一律跳过语义检查，彻底规避字典跨行误报。
#
# 用法：
#   python static_check.py            # 扫描项目全部 .gd（跳过 . 开头隐藏目录）
#   python static_check.py main.gd    # 只扫单个文件（调试用）
#
# 退出码：0 = 无阻断级问题；1 = 发现阻断级问题（孤立缩进 / class body 裸语句 / 跨作用域引用）。
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))

# GDScript 关键字（非变量引用、非声明）
KEYWORDS = {
    "if", "elif", "else", "for", "while", "match", "func", "class", "signal",
    "enum", "extends", "class_name", "tool", "var", "const", "return", "break",
    "continue", "pass", "await", "yield", "self", "super", "and", "or", "not",
    "in", "is", "as", "void", "true", "false", "null", "preload", "load",
    "static", "remote", "master", "puppet", "sync", "export", "onready",
    "setget", "with", "assert", "push_error", "push_warning", "set", "get",
    "is_instance_valid", "is_same", "is_zero_approx", "is_equal_approx",
}

# 全局已知标识符（内置类型/函数 + 项目 Autoload 单例），引用它们不算未声明
BUILTINS = {
    "Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i",
    "Color", "Rect2", "Rect2i", "Transform2D", "Transform3D", "Quaternion",
    "Plane", "Basis", "AABB", "Dictionary", "Array", "String", "StringName",
    "NodePath", "RID", "Variant", "Callable", "Signal", "Object", "RefCounted",
    "Node", "Resource", "PackedStringArray", "PackedInt32Array", "PackedByteArray",
    "PackedFloat32Array", "PackedVector2Array", "Error", "OK", "FAILED",
    "int", "float", "str", "bool", "abs", "min", "max", "clamp", "floor",
    "ceil", "round", "sqrt", "pow", "sin", "cos", "tan", "atan", "atan2",
    "randi", "randf", "rand_range", "randi_range", "randf_range", "randomize",
    "hash", "typeof", "len", "lerp", "lerp_angle", "move_toward", "sign",
    "stepify", "snapped", "wrap", "ease", "smoothstep", "pingpong",
    "linear2db", "db2linear", "deg2rad", "rad2deg", "remap", "nearest_po2",
    "inverse_lerp", "posmod", "fmod", "is_inf", "is_nan", "print", "prints",
    "printerr", "printraw", "print_stack", "get_stack", "weakref", "var2str",
    "str2var", "bytes2var", "var2bytes", "inst2dict", "dict2inst",
    "PI", "TAU", "INF", "NAN",
    "OS", "Engine", "ProjectSettings", "ResourceLoader", "ResourceSaver",
    "ClassDB", "Geometry", "JSON", "Marshalls", "FileAccess", "DirAccess",
    "Time", "DisplayServer", "Input", "TranslationServer", "IP", "Mutex",
    "Semaphore", "Thread", "Timer", "Tween", "AudioServer", "SceneTree",
    "Viewport", "Game", "Lore", "Item", "BattleCalculator", "BattleManager",
    "Quest", "Disciple", "Beast", "SaveSystem",
}

# 视为「进入函数体」的 opener 判定
FUNC_RE = re.compile(r"^(?:@\w+(?:\s*\([^)]*\))?\s+)*(?:static\s+)?func\b")
BLOCK_OPENERS = {"if", "elif", "else", "for", "while", "match", "func", "class", "with", "enum"}
CLASS_TOP_DECL = {
    "var", "const", "func", "signal", "enum", "class", "extends", "class_name",
    "tool", "static",
}
ATTRIB_RE = re.compile(r"^@\w+")
IDENT_RE = re.compile(r"[A-Za-z_一-鿿][A-Za-z_0-9一-鿿]*")
CONT_TAILS = ("(", "[", "{", ",", "\\", "+", "-", "*", "/", "%", "=", "|", "&", ">", "<", ":")


def tab_count(s):
    n = 0
    for ch in s:
        if ch == "\t":
            n += 1
        else:
            break
    return n


def strip_comment(s):
    in_s = in_d = False
    for i, ch in enumerate(s):
        if ch == '"' and not in_s:
            in_d = not in_d
        elif ch == "'" and not in_d:
            in_s = not in_s
        elif ch == "#" and not in_s and not in_d:
            return s[:i]
    return s


def bracket_net(code):
    """统计本行括号净变化（忽略字符串内）。返回 (开 - 闭) 增量。"""
    net = 0
    in_s = in_d = False
    i = 0
    while i < len(code):
        c = code[i]
        if c == '"' and not in_s:
            in_d = not in_d
            i += 1
            continue
        if c == "'" and not in_d:
            in_s = not in_s
            i += 1
            continue
        if in_s or in_d:
            i += 1
            continue
        if c in "([{":
            net += 1
        elif c in ")]}":
            net -= 1
        i += 1
    return net


def first_token(code):
    m = re.match(
        r"(@\w+(?:\s*\([^)]*\))?\s+)*(?:static\s+)?"
        r"((?:var|const|func|class|signal|enum|if|elif|else|"
        r"for|while|match|with|extends|class_name|tool|return|break|continue|"
        r"pass|await|assert|print\w*))\b", code)
    if not m:
        toks = re.findall(r"[A-Za-z_一-鿿]+", code)
        return toks[0] if toks else ""
    return m.group(2)


def parse_var_name(code):
    m = re.match(r"^(?:static\s+)?(?:var|const)\s+([A-Za-z_一-鿿][\w一-鿿]*)\b", code)
    return m.group(1) if m else None


def parse_func_params(code):
    m = re.search(r"func\s+\w+\s*\(([^)]*)\)", code)
    if not m:
        return set()
    body = m.group(1).strip()
    if not body:
        return set()
    params = set()
    for part in body.split(","):
        part = part.strip()
        if not part or part == "...":
            continue
        name = re.split(r"[:=]", part)[0].strip()
        if re.match(r"[A-Za-z_一-鿿]\w*", name):
            params.add(name)
    return params


def parse_for_var(code):
    m = re.match(r"for\s+([A-Za-z_一-鿿]\w*)\s*(?::\s*[A-Za-z_一-鿿][\w一-鿿.]*\s*)?(?:in|:=)", code)
    return m.group(1) if m else None


def extract_ident_refs(code):
    """提取裸标识符引用：排除 .属性 的属名、字符串、数字、关键字。
    用于跨作用域判定的引用收集（调用目标/属性接收者已被排除或交由全局集合过滤）。"""
    tmp = []
    in_s = in_d = False
    i = 0
    while i < len(code):
        c = code[i]
        if c == '"' and not in_s:
            in_d = not in_d
            i += 1
            continue
        if c == "'" and not in_d:
            in_s = not in_s
            i += 1
            continue
        if (in_s or in_d) and c == "\\":
            i += 2
            continue
        tmp.append(c if not (in_s or in_d) else " ")
        if (in_s or in_d) and c in ('"', "'"):
            in_s = in_d = False
        i += 1
    cleaned = "".join(tmp)
    refs = set()
    for m in IDENT_RE.finditer(cleaned):
        tok = m.group(0)
        start = m.start()
        if start > 0 and cleaned[start - 1] == ".":
            continue  # .属性
        if tok in KEYWORDS:
            continue
        refs.add(tok)
    return refs


def is_continuation(prev_code):
    if not prev_code:
        return False
    return prev_code.rstrip().endswith(CONT_TAILS)


def _is_block_opener(prev_code):
    if prev_code is None:
        return False
    code = prev_code.strip()
    if code.endswith(":"):
        return True
    if re.search(r"func\s*\(", code):
        return True
    return first_token(code) in BLOCK_OPENERS


def scan_file(path):
    """返回 blocking: list[dict]（确定性结构错误，阻断 F5）。
    覆盖三类「只有 Godot 真机才报」的崩溃：
      1. 孤立缩进（非开块词行后跟更深缩进）
      2. class body 裸语句（class 作用域出现非声明类语句）
      3. 跨作用域变量引用（var 声明在更深块内，被更浅层引用）
    「未声明标识符（拼错变量名）」因纯文本无法可靠区分引擎类/全局枚举/前向引用
    信号回调与真拼错，交由 Godot 编译器在 F5 时兜底，不纳入本扫描。
    """
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    n = len(lines)
    blocking = []

    bracket_depth = 0          # 跨行括号净深度（字面量/表达式延续）
    indent_stack = [0]
    func_stack = []            # 每个 func 起始缩进
    class_members = set()
    local_depth = {}           # 局部变量名 -> 声明缩进
    func_params = set()
    prev_code = None

    for i in range(n):
        raw = lines[i]
        if raw.strip() == "":
            continue
        no_cmt = strip_comment(raw)
        code = no_cmt.strip()
        if code == "":
            continue
        indent = tab_count(raw)
        lineno = i + 1

        delta = bracket_net(no_cmt)
        prev_depth = bracket_depth
        bracket_depth += delta

        # 字面量/表达式延续行：跳过一切语义检查（GDScript 的 {}[]() 仅用于字面量）
        if prev_depth > 0:
            prev_code = raw
            continue

        ftok = first_token(code)

        # ---- 维护缩进栈 ----
        if indent > indent_stack[-1]:
            if prev_code is not None and not _is_block_opener(prev_code) and not is_continuation(prev_code):
                blocking.append({
                    "type": "孤立缩进",
                    "line": lineno,
                    "prev": prev_code.strip()[:70],
                    "cur": code[:70],
                })
            indent_stack.append(indent)
        elif indent < indent_stack[-1]:
            while indent_stack and indent < indent_stack[-1]:
                indent_stack.pop()
            while func_stack and indent <= func_stack[-1]:
                func_stack.pop()
                local_depth = {}
                func_params = set()

        # ---- 进入 func ----
        if FUNC_RE.match(code):
            func_stack.append(indent)
            local_depth = {}
            func_params = parse_func_params(code)
            fm = re.search(r"func\s+([A-Za-z_一-鿿]\w*)", code)
            if fm:
                class_members.add(fm.group(1))

        in_func = bool(func_stack)

        # ---- class body 裸语句检查 ----
        if not in_func and indent == 0:
            if not (ftok in CLASS_TOP_DECL or ATTRIB_RE.match(code)
                    or code.startswith("class_name") or code.startswith("extends")
                    or code.startswith("tool")):
                blocking.append({
                    "type": "class body 裸语句",
                    "line": lineno,
                    "prev": "",
                    "cur": code[:70],
                })

        # ---- 声明收集 ----
        if ftok in ("var", "const"):
            vname = parse_var_name(code)
            if vname:
                if in_func:
                    local_depth[vname] = indent
                else:
                    class_members.add(vname)
        elif ftok == "signal":
            sm = re.search(r"signal\s+([A-Za-z_一-鿿]\w*)", code)
            if sm:
                class_members.add(sm.group(1))
        elif ftok == "enum":
            em = re.search(r"enum\s+([A-Za-z_一-鿿]\w*)", code)
            if em:
                class_members.add(em.group(1))
        elif ftok == "for" and in_func:
            fv = parse_for_var(code)
            if fv:
                local_depth[fv] = indent

        # ---- 跨作用域引用 / 未声明标识符 检查（仅 func 内）----
        if in_func:
            for r in extract_ident_refs(code):
                if r in KEYWORDS or r in BUILTINS or r in func_params or r in class_members:
                    continue
                if re.search(r"(?<![\w.])" + re.escape(r) + r"\s*\(", code):
                    continue  # 函数调用目标（拼错函数名属另一类，留 Godot 兜底）
                if r in local_depth:
                    if indent < local_depth[r]:
                        blocking.append({
                            "type": "跨作用域引用",
                            "line": lineno,
                            "prev": "变量 '%s' 声明于缩进 %d 的块内" % (r, local_depth[r]),
                            "cur": code[:70],
                        })
                else:
                    # 未声明标识符（拼错变量名如 _离山内容区 / 折叠_container）：
                    # 纯文本无法可靠区分「引擎类/全局枚举(ASCII)」「前向引用的信号回调
                    # (_on_x)」「func 定义」与真拼错，强行检测会大量误报（狼来了），
                    # 故不纳入扫描，交由 Godot 编译器在 F5 时兜底。
                    continue

        prev_code = raw

    return blocking


def main():
    targets = sys.argv[1:] if len(sys.argv) > 1 else None
    all_blocking = []
    scanned = 0

    if targets:
        file_list = [os.path.join(ROOT, t) if not os.path.isabs(t) else t for t in targets]
    else:
        file_list = []
        for root, dirs, files in os.walk(ROOT):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for fn in files:
                if fn.endswith(".gd"):
                    file_list.append(os.path.join(root, fn))

    for fp in file_list:
        rel = os.path.relpath(fp, ROOT)
        for e in scan_file(fp):
            all_blocking.append((rel, e))
        scanned += 1

    print("静态扫描完成：扫描 %d 个 .gd 文件，发现 %d 处阻断级问题。"
          % (scanned, len(all_blocking)))

    if all_blocking:
        print("=== 阻断级问题（需在 F5 前修复）===")
        for rel, e in all_blocking:
            print("  [%s:L%d] %s" % (rel, e["line"], e["type"]))
            if e.get("prev"):
                print("    前一行: %s" % e["prev"])
            print("    本行:   %s" % e["cur"])

    return 1 if all_blocking else 0


if __name__ == "__main__":
    sys.exit(main())

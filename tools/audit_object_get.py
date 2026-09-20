#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/audit_object_get.py  —— PH6-E2 静态审计：Object 上的「双参 .get(k, default)」静默缺陷

背景（为何必须静态抓）:
  - Item / Disciple 是 RefCounted(Object)。GDScript 里 `Object.get()` **只接受 1 个参数**；
    只有 `Dictionary.get()` 接受 `(key, default)`。
  - 若 `x.get("k", <default>)` 的接收者 x 是 Object ⇒ 运行期抛
    `Invalid call. Nonexistent function 'get' ... Expected 1 argument(s)`，
    **当场中断整个函数**（不是回退默认值，是整段逻辑死掉）。
  - 当接收者是未标注的 `var x = ...`（Variant）时，**门1(gdtoolkit)/门3(pre_f5) 都不报** ⇒ 长期潜伏。
  - 全项目无任何 class 自定义 `func get(` （已核），故 2 参 get 打在 Object 上一律是缺陷。

本脚本纯静态（不启 Godot、不写任何 .gd）。对每个「双参 .get」的**接收者**做类型推断，三级分类：
  P0  确诊：接收者静态可定为 Object 系
        - 裸标识符：类型标注 / is ObjectType 收窄 / typeof==TYPE_OBJECT 收窄 / Object 返回函数赋值 / ().new() / self
        - 点字段 receiver.field：root 类型已知 **且** 该字段被声明为 Object 系；或字段 ∈ OBJECT_FIELD_HINTS
  P1  疑似：接收者未标注 Variant / 字段类型未知 / 纯链式 ⇒ 需运行期 headless 探针证伪
  LEGAL 合法（仅计数）：接收者静态可定为 Dictionary（标注 / is Dictionary / typeof==TYPE_DICTIONARY /
        字段声明为 Dictionary / 返回 Dictionary 的函数 / 链式 FUNC(...).get 且 FUNC 返回 Dictionary）

用法:
  python tools/audit_object_get.py                # 扫全项目（跳过 art/addons/.scratch_backup 等），打 P0/P1/LEGAL 全量
  python tools/audit_object_get.py --file X.gd    # 只扫单文件（用于 ground-truth 灵敏度自检）
  python tools/audit_object_get.py --json out.json
  python tools/audit_object_get.py --strict            # 接门用：仅打 P0 段 + 汇总行 + FAIL 行（P1/LEGAL 明细免刷屏）
  python tools/audit_object_get.py --strict --verbose  # strict 判定，但打 P0/P1/LEGAL 全量明细（调试用）
退出码: 0 = 无确诊 P0（报告模式恒 0）；1 = --strict 且存在确诊 P0（门6 FAIL）
"""
import os, re, sys, json, io

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {".git", ".godot", ".workbuddy", "art", "addons", "__pycache__",
             ".venv_genai", ".scratch_backup", "icon", "assets", "Godot",
             "backup", "backups", "temp_check", "backup_scripts"}

# ── 判定为 Object 系的类型名（内建 + 项目 class_name 动态补齐）─────────────
BUILTIN_OBJECT = {
    "Object", "RefCounted", "Resource", "Node", "Node2D", "Node3D", "Control",
    "CanvasLayer", "Timer", "Button", "Label", "Panel", "PanelContainer",
    "VBoxContainer", "HBoxContainer", "GridContainer", "TabBar", "TabContainer",
    "TextureRect", "ColorRect", "ScrollContainer", "LineEdit", "RichTextLabel",
    "Tween", "SceneTree", "PackedScene", "FileAccess", "DirAccess", "JSON",
    "Image", "Texture2D", "Sprite2D", "PopupPanel", "Window", "OptionButton",
    "CheckBox", "SpinBox", "ProgressBar", "MarginContainer", "CenterContainer",
    "SubViewport", "SubViewportContainer", "HTTPRequest", "AudioStreamPlayer",
    "AnimationPlayer", "Tree", "ItemList", "Separator", "HSeparator", "VSeparator",
}
# 已知的 Object 字段名（receiver 形如 `<obj>.<field>` 时用）——保守，宁缺勿滥
OBJECT_FIELD_HINTS = {"护身符", "本命法宝"}

NAME = r"[A-Za-z_\u4e00-\u9fff][\w\u4e00-\u9fff]*"
RE_FUNC = re.compile(r"^([ \t]*)(?:static[ \t]+)?func[ \t]+(" + NAME + r")[ \t]*\(([^)]*)\)[ \t]*(?:->[ \t]*(" + NAME + r"))?[ \t]*:")
RE_ASSIGN = re.compile(r"^[ \t]*(?:(?:var|const)[ \t]+)?" + r"(" + NAME + r")(?:[ \t]*:[ \t]*(" + NAME + r"))?[ \t]*=(?!=)[ \t]*(.+)$")
RE_ASSIGN2 = re.compile(r"^[ \t]*(?:@\w+[ \t]+)*[ \t]*(?:var|const)[ \t]+(" + NAME + r")[ \t]*:=[ \t]*(.+)$")
RE_FOR = re.compile(r"^[ \t]*for[ \t]+(" + NAME + r")[ \t]+in[ \t]+(.+?)[ \t]*:")
RE_GUARD_IS = re.compile(r"if[ \t]+(not[ \t]+)?\(?[ \t]*(" + NAME + r")[ \t]+is[ \t]+(" + NAME + r")")
RE_GUARD_TYPEOF = re.compile(r"typeof[ \t]*\([ \t]*(" + NAME + r")[ \t]*\)[ \t]*(==|!=)[ \t]*(TYPE_OBJECT|TYPE_DICTIONARY)")
# 表达式上下文（三元条件等）里的 `x is T` / `not (x is T)`，不要求 if 前缀
RE_IS_CHECK = re.compile(r"\b(not[ \t]+)?\(?[ \t]*(" + NAME + r")[ \t]+is[ \t]+(" + NAME + r")\b")
RE_NEW = re.compile(r"^(" + NAME + r")\.new[ \t]*\(")
RE_CALL = re.compile(r"^(" + NAME + r")[ \t]*\(")
RE_INDEX_ASSIGN = re.compile(r"^[ \t]*(" + NAME + r")[ \t]*\[")
RE_GET2 = re.compile(r"\.get[ \t]*\(")
RE_MEMBER = re.compile(r"^[ \t]*(?:@\w+[ \t]+)*[ \t]*(?:var|const)[ \t]+(" + NAME + r")[ \t]*:[ \t]*(" + NAME + r")")
RE_CLASSNAME = re.compile(r"^[ \t]*class_name[ \t]+(" + NAME + r")", re.M)


def strip_comment(line):
    """去掉行内 # 注释（尊重字符串）。"""
    out = []
    instr, q, i = False, "", 0
    while i < len(line):
        c = line[i]
        if instr:
            out.append(c)
            if c == "\\":
                if i + 1 < len(line):
                    out.append(line[i + 1]); i += 2; continue
            elif c == q:
                instr = False
        else:
            if c in "\"'":
                instr = True; q = c; out.append(c)
            elif c == "#":
                break
            else:
                out.append(c)
        i += 1
    return "".join(out)


def indent_of(line):
    n = 0
    for c in line:
        if c == "\t":
            n += 4
        elif c == " ":
            n += 1
        else:
            break
    return n


def find_2arg_gets(code):
    """返回 [(col, receiver, calltext, kind)]，kind in {"ident","call","none"}。
    只保留顶层 2 参数的 .get( 调用。"""
    res = []
    for m in RE_GET2.finditer(code):
        i = m.end() - 1  # 指向 '('
        depth, j, instr, q = 0, i, False, ""
        while j < len(code):
            c = code[j]
            if instr:
                if c == "\\":
                    j += 2; continue
                if c == q:
                    instr = False
            else:
                if c in "\"'":
                    instr = True; q = c
                elif c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                    if depth == 0:
                        break
            j += 1
        call = code[i:j + 1]
        # 顶层逗号计数
        depth, instr, q, commas = 0, False, "", 0
        for c in call[1:-1]:
            if instr:
                if c == q:
                    instr = False
            else:
                if c in "\"'":
                    instr = True; q = c
                elif c in "([{":
                    depth += 1
                elif c in ")]}":
                    depth -= 1
                elif c == "," and depth == 0:
                    commas += 1
        if commas != 1:
            continue
        # 接收者：向前取点链
        k = m.start() - 1
        end = k + 1
        recv, kind = "", "ident"
        while k >= 0 and (code[k] in "._" or code[k].isalnum() or "\u4e00" <= code[k] <= "\u9fff"):
            k -= 1
        raw = code[k + 1:end].strip().lstrip(".")
        if raw:
            recv = raw
        elif end > 0 and code[end - 1] == ")":
            # 链式 FUNC(...).get(...)：回溯配对括号，取括前标识符
            depth, j2 = 0, end - 1
            while j2 >= 0:
                if code[j2] == ")":
                    depth += 1
                elif code[j2] == "(":
                    depth -= 1
                    if depth == 0:
                        break
                j2 -= 1
            k2 = j2 - 1
            e2 = k2 + 1
            while k2 >= 0 and (code[k2] in "._" or code[k2].isalnum() or "\u4e00" <= code[k2] <= "\u9fff"):
                k2 -= 1
            nm = code[k2 + 1:e2].strip().lstrip(".")
            if nm:
                recv, kind = nm, "call"
        res.append((m.start(), recv if recv else None, call, kind))
    return res


def collect_field_types(gds):
    """{class_name: {field: Type}} —— 从各 .gd 顶层成员 var/const 声明采集。"""
    idx = {}
    for p in gds:
        txt = io.open(p, encoding="utf-8", errors="replace").read()
        m = RE_CLASSNAME.search(txt)
        if not m:
            continue
        cls = m.group(1)
        fields = idx.setdefault(cls, {})
        for line in txt.split("\n"):
            if line[:1] in (" ", "\t"):   # 成员声明在顶层（缩进 0）
                continue
            mm = RE_MEMBER.match(line)
            if mm:
                fields[mm.group(1)] = mm.group(2)
    return idx


def parse_file(path, obj_types, field_types):
    raw = io.open(path, encoding="utf-8", errors="replace").read().split("\n")
    codes = [strip_comment(l) for l in raw]
    indents = [indent_of(l) for l in raw]

    cm = RE_CLASSNAME.search("\n".join(codes[:60]))
    file_class = cm.group(1) if cm else None

    # 函数区间
    funcs = []
    for idx_, c in enumerate(codes):
        m = RE_FUNC.match(c)
        if m:
            funcs.append({"name": m.group(2), "indent": len(m.group(1)), "start": idx_,
                          "params_raw": m.group(3), "ret": m.group(4), "end": len(codes) - 1})
    for a, b in zip(funcs, funcs[1:]):
        a["end"] = b["start"] - 1
    for f in funcs:
        f["params"] = {}
        for p in f["params_raw"].split(","):
            p = p.strip()
            mm = re.match(r"^(" + NAME + r")[ \t]*:[ \t]*(" + NAME + r")", p)
            if mm:
                f["params"][mm.group(1)] = mm.group(2)

    def func_at(line):
        cur = None
        for f in funcs:
            if f["start"] <= line <= f["end"]:
                cur = f
        return cur

    # 函数返回类型（显式 -> T；或函数体含 typeof(x)!=TYPE_OBJECT 守卫 ⇒ 视作 Object 系）
    func_ret = {}
    for f in funcs:
        if f["ret"]:
            func_ret[f["name"]] = f["ret"]
    for f in funcs:
        if f["ret"]:
            continue
        body = "\n".join(codes[f["start"]:f["end"] + 1])
        if re.search(r"typeof[ \t]*\([ \t]*" + NAME + r"[ \t]*\)[ \t]*!=[ \t]*TYPE_OBJECT", body):
            func_ret[f["name"]] = "Object"

    # 守卫（var -> 类型信号），带生效区间
    #  负向早退守卫 `if not (x is T): return/continue/break`：此后 x 在整个函数内被收窄为 T
    #  正向守卫 `if x is T:`：仅 if-block 内收窄
    def func_end_line(i2):
        f = func_at(i2)
        return (f["end"] + 1) if f else len(codes)

    # 变量赋值行清单（供「负向守卫收窄是否被后续再赋值打断」判定）
    assign_lines = {}
    for idx_, c in enumerate(codes):
        f = func_at(idx_); fname = f["name"] if f else "<module>"
        m = RE_ASSIGN.match(c)
        if m and not c.lstrip().startswith(("return", "if", "elif", "while", "for", "match")):
            assign_lines.setdefault((fname, m.group(1)), []).append(idx_ + 1)
        else:
            m12 = RE_ASSIGN2.match(c)
            if m12:
                assign_lines.setdefault((fname, m12.group(1)), []).append(idx_ + 1)
        m3 = RE_FOR.match(c)
        if m3:
            assign_lines.setdefault((fname, m3.group(1)), []).append(idx_ + 1)

    def guard_block_end(idx_, var, neg):
        if not neg:
            return _block_end(indents, idx_)
        end = func_end_line(idx_)
        f = func_at(idx_); fname = f["name"] if f else "<module>"
        later = [l for l in assign_lines.get((fname, var), []) if l > idx_ + 1]
        if later:
            end = min(end, later[0] - 1)   # 再赋值后收窄失效
        return end

    guards = []  # (start_line, end_line, var, kind)  kind in {obj, dict}
    for idx_, c in enumerate(codes):
        # 只认真正的 if/elif 语句；行内 `is`（三元/表达式）交由 ternary_narrowing 分支判定
        if not re.match(r"^\s*(?:el)?if\b", c):
            continue
        nxt = codes[idx_ + 1] if idx_ + 1 < len(codes) else ""
        for m in RE_GUARD_IS.finditer(c):
            neg, var, typ = bool(m.group(1)), m.group(2), m.group(3)
            if neg and not re.search(r"\b(return|continue|break)\b", c + " " + nxt):
                continue
            kind = "obj" if typ in obj_types else ("dict" if typ == "Dictionary" else None)
            if kind:
                guards.append((idx_ + 1, guard_block_end(idx_, var, neg), var, kind))
        for m in RE_GUARD_TYPEOF.finditer(c):
            var, op, t = m.group(1), m.group(2), m.group(3)
            neg = (op == "!=")
            if neg and not re.search(r"\b(return|continue|break)\b", c + " " + nxt):
                continue
            kind = "obj" if t == "TYPE_OBJECT" else "dict"
            guards.append((idx_ + 1, guard_block_end(idx_, var, neg), var, kind))

    # 变量状态：标注 / 赋值 / 字典索引（按行累积；解析时取「使用点之前最近一次」= 时序正确）
    def _add(d, key, line, val):
        d.setdefault(key, []).append((line, val))

    def _latest(hist, line):
        best = None
        for ln, val in hist:
            if ln <= line and (best is None or ln >= best[0]):
                best = (ln, val)
        return best

    ann, assigns, indexed = {}, {}, set()
    for idx_, c in enumerate(codes):
        f = func_at(idx_); fname = f["name"] if f else "<module>"
        ln = idx_ + 1
        m = RE_ASSIGN.match(c)
        if m and not c.lstrip().startswith(("return", "if", "elif", "while", "for", "match")):
            var, typ, expr = m.group(1), m.group(2), m.group(3).strip()
            if typ:
                _add(ann, (fname, var), ln, typ)
            _add(assigns, (fname, var), ln, expr)
        else:
            m12 = RE_ASSIGN2.match(c)          # `var/const X := expr`（:= 真声明）
            if m12:
                _add(assigns, (fname, m12.group(1)), ln, m12.group(2).strip())
        m2 = RE_INDEX_ASSIGN.match(c)
        if m2 and re.search(r"\[[^\]]*\][ \t]*=", c):
            indexed.add((fname, m2.group(1)))
        m3 = RE_FOR.match(c)
        if m3:
            _add(assigns, (fname, m3.group(1)), ln, "@iter(" + m3.group(2).strip() + ")")

    # 跨作用域兜底：**仅**取顶层成员声明（缩进 0）——避免同名局部变量跨函数互相污染
    ann_member, assign_member = {}, {}
    for idx_, c in enumerate(codes):
        if indents[idx_] != 0:
            continue
        mm = RE_MEMBER.match(c)
        if mm:
            _add(ann_member, mm.group(1), idx_ + 1, mm.group(2))
        m = RE_ASSIGN.match(c)
        if m and re.match(r"^\s*(?:@\w+[ \t]+)*[ \t]*(?:var|const)\s", c):
            _add(assign_member, m.group(1), idx_ + 1, m.group(3).strip())

    def ann_of(fname, var, line):
        h = ann.get((fname, var))
        r = _latest(h, line) if h else None
        if r:
            return r[1]
        h2 = ann_member.get(var)
        r2 = _latest(h2, line) if h2 else None
        return r2[1] if r2 else None

    def assign_of(fname, var, line):
        h = assigns.get((fname, var))
        r = _latest(h, line) if h else None
        if r:
            return r
        h2 = assign_member.get(var)
        r2 = _latest(h2, line) if h2 else None
        return r2

    def var_type(fname, var, line, depth=0):
        """推断变量类型名（class name / Dictionary / ...），无法定则 None。"""
        if depth > 4:
            return None
        t = ann_of(fname, var, line)
        if t:
            return t
        if (fname, var) in indexed:
            return "Dictionary"
        a = assign_of(fname, var, line)
        if not a:
            return None
        expr = a[1]
        if expr.startswith("{"):        # 字典字面量初始化 ⇒ Dictionary
            return "Dictionary"
        mn = RE_NEW.match(expr)
        if mn:
            return mn.group(1)
        mc = RE_CALL.match(expr)
        if mc:
            return func_ret.get(mc.group(1))
        mm = re.match(r"^(" + NAME + r")(?:\.(" + NAME + r"))?[ \t]*$", expr)
        if mm:
            base, field = mm.group(1), mm.group(2)
            if field:
                bt = var_type(fname, base, line, depth + 1)
                if bt:
                    return field_types.get(bt, {}).get(field)
            elif base != var:
                return var_type(fname, base, line, depth + 1)
        return None

    def classify_type(t):
        if not t:
            return None
        if t == "Dictionary":
            return "LEGAL"
        if t in obj_types:
            return "P0"
        return None

    # 行内三元 `A if C else B` 的分支收窄：.get 落在 A 分支 ⇒ 按 C 收窄；落在 B 分支 ⇒ 按 ¬C 收窄。
    # 例：`x.get(k,d) if x is Object else d` ⇒ A 分支 ⇒ x 是 Object ⇒ P0（真缺陷）
    #     `x.属性 if x is Object else x.get(k,d)` ⇒ B 分支 ⇒ x 非 Object ⇒ Dictionary ⇒ LEGAL
    def _find_top(c, tok):
        res = []
        instr, q, depth, i = False, "", 0, 0
        while i < len(c):
            ch = c[i]
            if instr:
                if ch == "\\":
                    i += 2; continue
                if ch == q:
                    instr = False
            else:
                if ch in "\"'":
                    instr = True; q = ch
                elif ch in "([{":
                    depth += 1
                elif ch in ")]}":
                    depth -= 1
                elif depth == 0 and c.startswith(tok, i):
                    res.append(i); i += len(tok); continue
            i += 1
        return res

    def _cond_narrow(cond, negate):
        out = {}
        for m in RE_IS_CHECK.finditer(cond):
            neg0, var, typ = bool(m.group(1)), m.group(2), m.group(3)
            kind = "obj" if typ in obj_types else ("dict" if typ == "Dictionary" else None)
            if not kind:
                continue
            is_obj = (kind == "obj")
            if neg0:
                is_obj = not is_obj
            if negate:
                is_obj = not is_obj
            out[var] = "obj" if is_obj else "dict"
        for m in RE_GUARD_TYPEOF.finditer(cond):
            var, op, t = m.group(1), m.group(2), m.group(3)
            is_obj = (t == "TYPE_OBJECT")
            if op == "!=":
                is_obj = not is_obj
            if negate:
                is_obj = not is_obj
            out[var] = "obj" if is_obj else "dict"
        return out

    def ternary_narrowing(c, col):
        ifs = _find_top(c, " if ")
        if not ifs:
            return {}
        els = _find_top(c, " else ")
        for ifpos in reversed(ifs):
            elsepos = next((ep for ep in els if ep > ifpos), None)
            if elsepos is None:
                continue
            if col < ifpos:                  # THEN 分支（A）
                return _cond_narrow(c[ifpos + 4:elsepos], negate=False)
            if col > elsepos:                # ELSE 分支（B）
                return _cond_narrow(c[ifpos + 4:elsepos], negate=True)
            return {}                        # 位于条件区 C，不做收窄
        return {}

    # 主扫描
    out = []
    for idx_, c in enumerate(codes):
        f = func_at(idx_); fname = f["name"] if f else "<module>"
        for col, recv, call, kind in find_2arg_gets(c):
            line_no = idx_ + 1
            cat = reason = None
            if recv is None:
                cat, reason = "P1", "接收者为纯链式/索引取值，静态不可定"
            else:
                parts = recv.split(".")
                if len(parts) > 2:
                    cat, reason = "P1", "接收者链深 >2，静态不可定"
                else:
                    root = parts[0]
                    field = parts[1] if len(parts) == 2 else None
                    if kind == "call":
                        t = func_ret.get(root)
                        c2 = classify_type(t)
                        if c2 == "P0":
                            cat, reason = "P0", "接收者为 %s(...)（返回类型 %s，Object 系）" % (root, t)
                        elif c2 == "LEGAL":
                            cat, reason = "LEGAL", "接收者为 %s(...)（返回类型 %s=Dictionary，合法）" % (root, t)
                        else:
                            cat, reason = "P1", "接收者为 %s(...)，返回类型未标注，需运行期证伪" % root
                    elif field:
                        if field in OBJECT_FIELD_HINTS:
                            cat, reason = "P0", "接收者为已知 Object 字段 .%s" % field
                        else:
                            if root == "self":
                                root_t = file_class
                            elif f and root in f["params"]:
                                root_t = f["params"][root]
                            else:
                                root_t = var_type(fname, root, line_no)
                            ft = field_types.get(root_t, {}).get(field) if root_t else None
                            c2 = classify_type(ft)
                            if c2 == "P0":
                                cat, reason = "P0", "接收者 %s.%s（%s.%s: %s，Object 系）" % (root, field, root_t, field, ft)
                            elif c2 == "LEGAL":
                                cat, reason = "LEGAL", "%s.%s: %s（Dictionary，合法）" % (root_t, field, ft)
                            else:
                                cat, reason = "P1", "接收者 %s.%s 字段类型未知（root 类型 %s），需运行期证伪" % (root, field, root_t)
                    else:
                        if root == "self":
                            cat, reason = "P0", "接收者 self（Object/Node）"
                        if cat is None and f and root in f["params"]:
                            c2 = classify_type(f["params"][root])
                            if c2 == "P0":
                                cat, reason = "P0", "形参标注 :%s（Object 系）" % f["params"][root]
                            elif c2 == "LEGAL":
                                cat, reason = "LEGAL", "形参标注 :Dictionary"
                        if cat is None:
                            at = ann_of(fname, root, line_no)
                            c2 = classify_type(at)
                            if c2 == "P0":
                                cat, reason = "P0", "变量标注 :%s（Object 系）" % at
                            elif c2 == "LEGAL":
                                cat, reason = "LEGAL", "变量标注 :Dictionary"
                        if cat is None:
                            tn = ternary_narrowing(c, col).get(root)   # 同行的分支收窄最精确，优先
                            gk = tn if tn is not None else _guard_kind(guards, line_no, root)
                            if gk == "obj":
                                cat, reason = "P0", "处于 `%s` is Object系 / typeof==TYPE_OBJECT 收窄之后" % root
                            elif gk == "dict":
                                cat, reason = "LEGAL", "处于 `%s` is Dictionary / typeof==TYPE_DICTIONARY 收窄之后" % root
                        if cat is None:
                            t = var_type(fname, root, line_no)
                            c2 = classify_type(t)
                            if c2 == "P0":
                                cat, reason = "P0", "由 Object 系赋值（%s，最近赋值: %s）" % (t, _assign_desc(assign_of, fname, root, line_no))
                            elif c2 == "LEGAL":
                                cat, reason = "LEGAL", "由 Dictionary 赋值（最近赋值: %s）" % _assign_desc(assign_of, fname, root, line_no)
                        if cat is None:
                            cat, reason = "P1", "未标注 Variant，需运行期证伪（最近赋值: %s）" % _assign_desc(assign_of, fname, root, line_no)
            out.append((line_no, recv, call, cat, reason))
    return out, funcs


def _assign_desc(assign_of, fname, var, line):
    a = assign_of(fname, var, line)
    if not a:
        return "无（可能为形参/成员/未在本函数赋值）"
    ln, expr = a
    return "L%d: %s" % (ln, expr[:60])


def _block_end(indents, idx):
    base = indents[idx]
    j = idx + 1
    while j < len(indents):
        if indents[j] <= base:
            break
        j += 1
    return j


def _guard_kind(guards, line_no, var):
    kind = None
    for s, e, v, k in guards:
        if v == var and s <= line_no <= e:
            kind = k
    return kind


def collect_gds():
    gds = []
    for dp, dn, fn in os.walk(ROOT):
        dn[:] = [d for d in dn if d not in SKIP_DIRS]
        for f in fn:
            if f.endswith(".gd"):
                gds.append(os.path.abspath(os.path.join(dp, f)))   # 钉成绝对路径：显示用 _rel 不依赖调用者 cwd
    return sorted(gds)


def collect_obj_types(gds):
    types = set(BUILTIN_OBJECT)
    for p in gds:
        t = io.open(p, encoding="utf-8", errors="replace").read()
        for m in RE_CLASSNAME.finditer(t):
            types.add(m.group(1))
    return types


def _rel(p):
    """显示用相对路径；跨盘符时回退绝对路径。
    os.path.relpath(p, ROOT) 在 p 与 ROOT 不同盘符时抛未捕获 ValueError ⇒ 进程崩、rc=1，
    而 rc=1 正是门6 的 FAIL 信号 ⇒ 会让「工具崩溃」伪装成「发现 P0」的假红线。
    仅影响报告显示，不影响扫描范围与判定。── PH6-E3."""
    try:
        return os.path.relpath(p, ROOT)
    except ValueError:
        return os.path.abspath(p)


def main():
    args = sys.argv[1:]
    single = None
    json_out = None
    strict = "--strict" in args
    verbose = ("--verbose" in args) or ("--all" in args)
    if "--file" in args:
        single = args[args.index("--file") + 1]
    if "--json" in args:
        json_out = args[args.index("--json") + 1]

    all_gds = collect_gds()
    obj_types = collect_obj_types(all_gds)
    field_types = collect_field_types(all_gds)
    gds = [os.path.abspath(single)] if single else all_gds

    buckets = {"P0": [], "P1": [], "LEGAL": []}
    for p in gds:
        try:
            rows, _funcs = parse_file(p, obj_types, field_types)
        except Exception as e:
            buckets["P1"].append((_rel(p), 0, "", "PARSE_ERR %s" % e, "P1"))
            continue
        for line_no, recv, call, cat, reason in rows:
            buckets[cat].append((_rel(p), line_no, recv or "(链式)", call, reason))

    print("=" * 78)
    print("PH6-E2 Object 双参 .get 静态审计  扫描文件 %d  接收者类型集 %d  字段索引类 %d" % (
        len(gds), len(obj_types), len(field_types)))
    print("=" * 78)
    # ★ 2026-09-16 PH6-E3：--strict 收窄输出 —— 只打 P0 段（+下方汇总行/FAIL 行）。
    #   起因：① 全量 22355 行 / 1.3MB，[STRICT] FAIL 落在第 22348 行；
    #         ② gate_all.run_gate 只透出子进程输出**最后 15 行** ⇒ 门6 日志里永远只剩 P1 明细，
    #            汇总行与 FAIL 行被挤出窗口。故 strict 下默认免刷 P1/LEGAL；
    #            非 strict 或 --verbose 仍打全量（报告/调试不受影响）。P1/LEGAL 计数仍在汇总行可见。
    cats = ("P0", "P1", "LEGAL") if ((not strict) or verbose) else ("P0",)
    for cat in cats:
        print("\n### %s  共 %d 处" % (cat, len(buckets[cat])))
        for rec in buckets[cat]:
            f, ln, recv, call, reason = rec
            print("  %s:%d  recv=%s  %s\n        ↑ %s" % (f, ln, recv, call.strip(), reason))
    print("\n" + "=" * 78)
    print("汇总: P0=%d  P1=%d  LEGAL=%d" % (len(buckets["P0"]), len(buckets["P1"]), len(buckets["LEGAL"])))
    if json_out:
        io.open(json_out, "w", encoding="utf-8").write(json.dumps(buckets, ensure_ascii=False, indent=1))
    if strict and buckets["P0"]:
        print("\n[STRICT] 存在 %d 处确诊 P0（Object 双参 .get）⇒ FAIL" % len(buckets["P0"]))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

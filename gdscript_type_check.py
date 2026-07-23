"""GDScript 4.x := type inference safety scanner.
Scans all .gd files for var X := patterns where the RHS value
cannot be reliably inferred by GDScript 4's parser.

REAL unsafe patterns (confirmed by Godot 4.x parser):
- .get() / .find() / .open() / any method call -> returns Variant
- int() / float() / str() / round() without 'as' -> returns Variant
- randi() / randf() / randi_range() -> returns Variant
- Dictionary indexing dict["key"] or arr[i] -> returns Variant
- Ternary: x if cond else y -> may return Variant
- String format: "..." % [...] -> returns String (but complex)
- Complex arithmetic with mixed types

SAFE patterns (GDScript 4 CAN infer these):
- Simple literals: 0, 1.0, "text", true, false, null
- Explicit cast: expr as Type
- Constructor: ClassName.new()
- Bare variable reference (already typed)
- Empty containers: [], {}

Run: python gdscript_type_check.py
"""
import re, os, sys


def check_line(val: str) -> tuple[bool, str]:
    """Returns (is_safe, reason). True = safe to keep as :="""
    stripped = val.strip()

    # === SAFE patterns ===
    if re.match(r'^-?\d+\.?\d*$', stripped):
        return True, 'numeric literal'
    if re.match(r'^["\x27].*["\x27]$', stripped):
        return True, 'string literal'
    if stripped in ('true', 'false', 'null'):
        return True, 'bool/null literal'
    if ' as ' in stripped.lower():
        return True, 'explicit cast'
    if '.new()' in stripped:
        return True, 'constructor'
    if stripped in ('[]', '{}'):
        return True, 'empty container'

    # === UNSAFE patterns ===
    # Godot 4 能可靠推断返回具体类型的方法调用 → 视为安全，允许 := 让引擎自己推断，
    # 避免被逼退回去手填类型名（手填反而易填错内部类型名如 SceneTreeTween）。
    known_safe_calls = (
        'create_tween', 'preload', 'load', 'get_node', 'get_node_or_null',
        'instantiate', 'duplicate', 'get_script', 'ResourceLoader',
    )
    if re.search(r'\.(?:' + '|'.join(known_safe_calls) + r')\s*\(', stripped):
        return True, 'known safe call'
    if re.search(r'\.\w+\(', stripped):
        return False, 'METHOD_CALL'
    if re.search(r'\w+\[', stripped):
        return False, 'INDEX_ACCESS'
    if re.search(r'\b(?:int|float|str|round|read_json)\s*\(', stripped):
        return False, 'CAST_FUNC'
    if re.search(r'\b(?:randi|randf|randi_range)\b', stripped):
        return False, 'RAND_FUNC'
    if re.search(r'\bif\b.*\belse\b', stripped):
        return False, 'TERNARY'
    if '%[' in stripped or re.search(r'%\s*\w+$', stripped):
        return False, 'STR_FORMAT'

    # Bare identifier — probably safe
    if re.match(r'^[A-Za-z_\u4e00-\u9fff]\w*$', stripped):
        return True, 'bare ref'

    # Complex expression with operators
    if any(op in stripped for op in ['+', '-', '*', '/', '%']):
        return False, 'COMPLEX_EXPR'

    return False, 'UNKNOWN'


def scan_file(filepath: str) -> list[tuple[int, str, str, str]]:
    issues = []
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for i, line in enumerate(lines, 1):
        s = line.strip()
        if not s.startswith('var ') or ':=' not in s:
            continue
        m = re.match(r'var\s+(\w+)\s*:=', s)
        if not m:
            continue
        var_name = m.group(1)
        val = s[s.index(':=')+2:].strip()
        # Strip inline comments (# ...) before checking
        if '#' in val:
            val = val[:val.index('#')].strip()
        is_safe, reason = check_line(val)
        if not is_safe:
            issues.append((i, var_name, val[:100], reason))

    return issues


def main():
    gd_files = []
    for dirpath, _, filenames in os.walk('.'):
        if '.godot' in dirpath:
            continue
        for fn in filenames:
            if fn.endswith('.gd') and not fn.startswith('test_'):
                gd_files.append(os.path.join(dirpath, fn))

    total_issues = 0
    file_results = {}

    for fp in sorted(gd_files):
        issues = scan_file(fp)
        if issues:
            total_issues += len(issues)
            rel = os.path.relpath(fp, '.').replace('\\', '/')
            file_results[rel] = issues

    print(f"=== GDScript Type Inference Scanner v2 ===")
    print(f"Scanned: {len(gd_files)} files")

    if not file_results:
        print("\n✅ ALL CLEAN")
        return 0

    print(f"\n⚠️  {total_issues} real issue(s) across {len(file_results)} file(s):\n")
    for rel, issues in file_results.items():
        print(f"  [{rel}] ({len(issues)})")
        for ln, name, val, tag in issues:
            print(f"     L{ln:3d} | {tag:12s} | {name} := {val}")
        print()

    return 1


if __name__ == '__main__':
    sys.exit(main())

import os, sys

ROOT = r"E:\Xiuxian\taixuanzongmenlu"
SKIP_DIRS = {".venv", "__pycache__", "node_modules", ".git"}
EXTS = {".gd", ".py", ".tscn", ".cfg", ".csv"}

# 典型乱码标记：Latin-1 误读 UTF-8 字节产生的字符
SUSPECT_CHARS = set("\u00c2\u00c3\u00e2")  # Â Ã â
REPLACEMENT = "\ufffd"  # ï¿½

def has_markers(text):
    hits = []
    for i, ch in enumerate(text):
        if ch in SUSPECT_CHARS or ch == REPLACEMENT:
            # 取前后文
            line_start = text.rfind("\n", 0, i) + 1
            line_end = text.find("\n", i)
            if line_end == -1:
                line_end = len(text)
            line = text[line_start:line_end]
            hits.append((i, line.rstrip()))
            if len(hits) >= 3:
                break
    return hits

def detect(raw):
    has_bom = raw[:3] == b"\xef\xbb\xbf"
    text = None
    enc = None
    try:
        text = raw.decode("utf-8")
        enc = "utf-8"
    except UnicodeDecodeError:
        try:
            text = raw.decode("gbk")
            enc = "gbk"
        except UnicodeDecodeError:
            text = raw.decode("latin-1")
            enc = "latin-1"
    return text, enc, has_bom

def try_repair_double_utf8(text):
    """UTF-8 被当 Latin-1 再编码回去：encode latin-1 -> decode utf-8"""
    try:
        repaired = text.encode("latin-1").decode("utf-8")
        return repaired
    except (UnicodeEncodeError, UnicodeDecodeError):
        return None

def main():
    do_fix = "--fix" in sys.argv
    report = []
    fixed_files = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        # 过滤跳过目录
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        # 跳过 art 大目录（主要是图片与 venv）
        if os.path.basename(dirpath) == "art":
            dirnames[:] = []
        for fn in filenames:
            ext = os.path.splitext(fn)[1].lower()
            if ext not in EXTS:
                continue
            full = os.path.join(dirpath, fn)
            try:
                with open(full, "rb") as f:
                    raw = f.read()
            except Exception as e:
                report.append(f"[ERR] {full}: {e}")
                continue
            if not raw:
                continue
            text, enc, bom = detect(raw)
            hits = has_markers(text)
            status = "OK"
            action = ""
            if hits:
                status = "MOJIBAKE"
                # 尝试修复
                if enc == "gbk":
                    action = "convert-gbk->utf8"
                    if do_fix:
                        out = text
                        with open(full, "wb") as f:
                            f.write(out.encode("utf-8"))
                        fixed_files.append(full)
                elif enc == "utf-8":
                    repaired = try_repair_double_utf8(text)
                    if repaired is not None and not has_markers(repaired):
                        action = "repair-double-utf8"
                        if do_fix:
                            with open(full, "wb") as f:
                                f.write(repaired.encode("utf-8"))
                            fixed_files.append(full)
                    else:
                        action = "NEED-MANUAL (utf-8 with markers, repair failed)"
                else:  # latin-1
                    action = "NEED-MANUAL (binary/unknown)"
            elif bom:
                status = "BOM"
                action = "strip-bom"
                if do_fix:
                    with open(full, "wb") as f:
                        f.write(raw[3:])
                    fixed_files.append(full)
            if status != "OK" or bom:
                rel = os.path.relpath(full, ROOT)
                report.append(f"[{status}] {rel}  enc={enc}  {action}")
                for idx, line in hits:
                    snippet = line[:160]
                    report.append(f"    L~{text.count(chr(10),0,idx)+1}: {snippet!r}")

    out_path = os.path.join(ROOT, "_mojibake_report.txt")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(report) if report else "NO ISSUES FOUND")
        f.write(f"\n\n--- mode={'FIX' if do_fix else 'SCAN'}  fixed={len(fixed_files)} ---\n")
        for ff in fixed_files:
            f.write(ff + "\n")
    print(f"report -> {out_path}  issues={len([r for r in report if r.startswith('[')])}  fixed={len(fixed_files)}")

if __name__ == "__main__":
    main()

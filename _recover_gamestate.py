import os, re, sys

ROOT = r"E:\Xiuxian\taixuanzongmenlu"
MARKER = "\ufffd?"  # the 2-char corruption (U+FFFD + literal ?)
CLASS = r"[A-Za-z0-9_\u3400-\u9fff]"
CLASS_RE = re.compile(CLASS)
TOKEN_RE = re.compile(r"[A-Za-z0-9_\u3400-\u9fff]+")
STR_RE = re.compile(r'"[^"\n]*[\u3400-\u9fff][^"\n]*"')

def collect_corpus():
    corpus = set()
    for dp, dn, fn in os.walk(ROOT):
        if ".venv" in dp or "__pycache__" in dp:
            continue
        if os.path.basename(dp) == "art":
            dn[:] = []
        for f in fn:
            if not f.endswith(".gd"):
                continue
            if f == "game_state.gd":
                continue
            p = os.path.join(dp, f)
            try:
                text = open(p, "rb").read().decode("utf-8")
            except Exception:
                continue
            if "\ufffd" in text:
                continue  # skip any other corrupted file
            for m in TOKEN_RE.finditer(text):
                corpus.add(m.group())
            for m in STR_RE.finditer(text):
                corpus.add(m.group()[1:-1])  # strip quotes
    # also add game_state.gd's own uncorrupted tokens (correct forms elsewhere in file)
    try:
        gs = open(os.path.join(ROOT, "game_state.gd"), "rb").read().decode("utf-8")
        for m in TOKEN_RE.finditer(gs):
            if "\ufffd" not in m.group():
                corpus.add(m.group())
        for m in STR_RE.finditer(gs):
            s = m.group()[1:-1]
            if "\ufffd" not in s:
                corpus.add(s)
    except Exception:
        pass
    return corpus

def prefix_suffix(line, i):
    # i = index of MARKER start
    # prefix: trailing CLASS chars before i
    pre = i
    while pre > 0 and CLASS_RE.match(line[pre - 1]):
        pre -= 1
    prefix = line[pre:i]
    # suffix: leading CLASS chars after marker (i+2)
    j = i + 2
    post = j
    while post < len(line) and CLASS_RE.match(line[post]):
        post += 1
    suffix = line[j:post]
    return prefix, suffix

def main():
    dry = "--apply" not in sys.argv
    corpus = collect_corpus()
    # index corpus by (prefix, suffix) where corpus token T = prefix + 1char + suffix
    idx = {}
    for t in corpus:
        L = len(t)
        for k in range(1, L):  # k = len(prefix); the 1 lost char is at position k
            p = t[:k]
            s = t[k + 1:]  # suffix after the 1 lost char
            idx.setdefault((p, s), []).append(t)
    gs_path = os.path.join(ROOT, "game_state.gd")
    lines = open(gs_path, "rb").read().decode("utf-8").split("\n")
    total_markers = 0
    matched = 0
    unmatched = []
    new_lines = []
    for n, line in enumerate(lines, 1):
        if MARKER not in line:
            new_lines.append(line)
            continue
        # process markers right-to-left to keep indices stable
        positions = [m.start() for m in re.finditer(re.escape(MARKER), line)]
        total_markers += len(positions)
        out = line
        is_comment = line.lstrip().startswith("#")
        for i in sorted(positions, reverse=True):
            prefix, suffix = prefix_suffix(out, i)
            # build key for exactly-1-lost-char: (prefix, suffix)
            cands = idx.get((prefix, suffix), [])
            if len(cands) == 1:
                ch = cands[0][len(prefix):len(prefix) + 1]
                out = out[:i] + ch + out[i + 2:]
                matched += 1
            else:
                unmatched.append((n, is_comment, prefix, suffix, out[max(0, i - 25):i + 25]))
        new_lines.append(out)
    print(f"total_markers={total_markers}  matched={matched}  unmatched={len(unmatched)}")
    if dry:
        rep = os.path.join(ROOT, "_recover_dryrun.txt")
        with open(rep, "w", encoding="utf-8") as f:
            f.write(f"total_markers={total_markers} matched={matched} unmatched={len(unmatched)}\n\n")
            for u in unmatched[:400]:
                f.write(f"L{u[0]} comment={u[1]} prefix={u[2]!r} suffix={u[3]!r} ctx={u[4]!r}\n")
        print("dry-run report ->", rep)
    else:
        with open(gs_path, "wb") as f:
            f.write("\n".join(new_lines).encode("utf-8"))
        # verify
        left = open(gs_path, "rb").read().decode("utf-8").count("\ufffd")
        print("APPLIED. remaining U+FFFD in file:", left)

if __name__ == "__main__":
    main()

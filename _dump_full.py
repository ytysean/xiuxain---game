import os, re
from collections import defaultdict

ROOT = r"E:\Xiuxian\taixuanzongmenlu"
MARKER = "\ufffd?"
CLASS = r"[A-Za-z0-9_\u3400-\u9fff]"
CLASS_RE = re.compile(CLASS)

gs_path = os.path.join(ROOT, "game_state.gd")
lines = open(gs_path, "rb").read().decode("utf-8").split("\n")

# Section 1: non-empty prefixes -> distinct, with up to 2 example lines
byprefix = defaultdict(list)
for n, line in enumerate(lines, 1):
    if MARKER not in line:
        continue
    for m in re.finditer(re.escape(MARKER), line):
        i = m.start()
        pre = i
        while pre > 0 and CLASS_RE.match(line[pre - 1]):
            pre -= 1
        prefix = line[pre:i]
        if prefix == "":
            continue
        byprefix[prefix].append(n)

out = []
out.append("##### NON-EMPTY PREFIXES (%d) #####" % len(byprefix))
for prefix in sorted(byprefix, key=lambda p: (-len(byprefix[p]), p)):
    occ = byprefix[prefix]
    # find 2 example lines
    exs = []
    for ln in occ[:2]:
        exs.append(lines[ln - 1].replace("\t", "  ").strip())
    out.append(f"P|{prefix}|{len(occ)}")
    for e in exs:
        out.append("   | " + e[:120])

# Section 2: empty-prefix markers -> every line (for per-line E_LINE override)
out.append("")
out.append("##### EMPTY-PREFIX LINES (single-char losses) #####")
empties = []
for n, line in enumerate(lines, 1):
    if MARKER not in line:
        continue
    cnt = line.count(MARKER)
    # only keep lines where ALL markers have empty prefix
    all_empty = True
    for m in re.finditer(re.escape(MARKER), line):
        i = m.start()
        pre = i
        while pre > 0 and CLASS_RE.match(line[pre - 1]):
            pre -= 1
        if pre != i:
            all_empty = False
            break
    if all_empty:
        empties.append((n, cnt, line.replace("\t", "  ")))
out.append("COUNT_EMPTY_LINES=%d" % len(empties))
for n, cnt, line in empties:
    out.append(f"E|{n}|{cnt}|{line.strip()[:160]}")

open(os.path.join(ROOT, "_dump_full.txt"), "w", encoding="utf-8").write("\n".join(out))
print("written _dump_full.txt ; non-empty prefixes:", len(byprefix), "; empty-prefix lines:", len(empties))

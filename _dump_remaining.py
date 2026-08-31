import os, re
from collections import defaultdict

ROOT = r"E:\Xiuxian\taixuanzongmenlu"
MARKER = "\ufffd?"
CLASS = r"[A-Za-z0-9_\u3400-\u9fff]"
CLASS_RE = re.compile(CLASS)

gs_path = os.path.join(ROOT, "game_state.gd")
lines = open(gs_path, "rb").read().decode("utf-8").split("\n")

byprefix = defaultdict(list)  # prefix -> list of (lineno, suffix, window)
for n, line in enumerate(lines, 1):
    if MARKER not in line:
        continue
    for m in re.finditer(re.escape(MARKER), line):
        i = m.start()
        pre = i
        while pre > 0 and CLASS_RE.match(line[pre - 1]):
            pre -= 1
        j = i + 2
        post = j
        while post < len(line) and CLASS_RE.match(line[post]):
            post += 1
        prefix = line[pre:i]
        suffix = line[j:post]
        window = line[max(0, i - 25):i + 25]
        byprefix[prefix].append((n, suffix, window))

print("DISTINCT PREFIXES:", len(byprefix))
print("TOTAL MARKERS:", sum(len(v) for v in byprefix.values()))
print("=" * 80)
for prefix in sorted(byprefix, key=lambda p: (-len(byprefix[p]), p)):
    occ = byprefix[prefix]
    # show up to 2 example windows
    ex = occ[0][2].replace("\n", " ")
    ex2 = occ[1][2].replace("\n", " ") if len(occ) > 1 else ""
    suf0 = occ[0][1]
    print(f"[{len(occ):>3}x] prefix={prefix!r} suf0={suf0!r}")
    print(f"        ex1 L{occ[0][0]}: {ex}")
    if ex2:
        print(f"        ex2 L{occ[1][0]}: {ex2}")

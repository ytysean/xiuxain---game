import re
ROOT = r"E:\Xiuxian\taixuanzongmenlu"
MARKER = "\ufffd?"
CLASS = r"[A-Za-z0-9_\u3400-\u9fff]"
CLASS_RE = re.compile(CLASS)
lines = open(ROOT + r"\game_state.gd", "rb").read().decode("utf-8").split("\n")
out = []
for n, line in enumerate(lines, 1):
    if MARKER not in line:
        continue
    for m in re.finditer(re.escape(MARKER), line):
        i = m.start()
        pre = i
        while pre > 0 and CLASS_RE.match(line[pre - 1]):
            pre -= 1
        prefix = line[pre:i]
        j = i + 2
        post = j
        while post < len(line) and CLASS_RE.match(line[post]):
            post += 1
        suffix = line[j:post]
        in_str = line[:i].count('"') % 2 == 1
        hidx = line.find("#")
        in_cmt = hidx != -1 and i > hidx
        tag = "S" if in_str else ("C" if in_cmt else "code")
        out.append(f"{tag}|{n}|pre={prefix!r}|suf={suffix!r}|{line.strip()}")
open(ROOT + r"\_remaining_452.txt", "w").write("\n".join(out))
print("total markers:", sum(1 for l in lines if MARKER in l))
print("dumped:", len(out))

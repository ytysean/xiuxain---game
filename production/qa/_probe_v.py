import os, glob, hashlib, datetime
ROOT = r"E:\Xiuxian\taixuanzongmenlu"
for mod in ("PIL", "numpy"):
    try:
        m = __import__(mod); print("HAVE", mod, getattr(m, "__version__", "?"))
    except Exception as e:
        print("NO  ", mod, e)
# ui_theme.gd locate + md5
hits = glob.glob(os.path.join(ROOT, "**", "ui_theme.gd"), recursive=True)
for p in hits:
    if ".bak" in p or ".scratch" in p or ".workbuddy" in p:
        continue
    b = open(p, "rb").read()
    print("UITHEME", os.path.relpath(p, ROOT), len(b), hashlib.md5(b).hexdigest(),
          datetime.datetime.fromtimestamp(os.path.getmtime(p)))
# accept_shots_full mtime range
d = os.path.join(ROOT, "accept_shots_full")
ps = glob.glob(os.path.join(d, "*.png"))
print("accept_shots_full png n=", len(ps))
if ps:
    ms = [os.path.getmtime(x) for x in ps]
    print("  mtime min", datetime.datetime.fromtimestamp(min(ms)))
    print("  mtime max", datetime.datetime.fromtimestamp(max(ms)))
print("expect ui_theme md5(before) = 21c4ece5ec30fdb09ec8b80354248af2")

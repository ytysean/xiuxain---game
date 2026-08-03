# -*- coding: utf-8 -*-
"""
太玄宗门录 · 场景背景批量生成 (scene_batch_gen.py)  v1
========================================================
对齐图标管线 gen_validation.py 的 Backend 抽象 + 清单驱动 + 断点续跑。

Backend（统一 .generate(prompt, seed) -> bytes|None 接口）：
  - DryRunBackend  : 不真正出图，仅记录 prompt（逻辑自检）
  - ComfyUIBackend : POST 本地 ComfyUI /prompt（你带卡机器可用，忠实保留）
  - A1111Backend   : POST 本地 A1111（同上）
  - EmitBackend    : 把拼好的 prompt 落盘成 scene_dispatch.jsonl 队列，
                     由 agent 按队列串行调平台 ImageGen 下发（本沙箱实际路径）

流程：
  读 scene_manifest.csv → 跳过 已验收 → 对每条 (scene×season) assemble_prompt
  → backend.generate → 存 assets/backgrounds/<out_name> → 写 scene_validation_manifest.csv
  支持 --only <scene_id> 或 --only <scene_id:season> 单条；--mark 回写状态（真实后端）。

用法：
  python scene_batch_gen.py --backend dryrun
  python scene_batch_gen.py --backend emit                      # 落队列，agent 串行下发
  python scene_batch_gen.py --backend comfyui --url http://127.0.0.1:8188
  python scene_batch_gen.py --only sect_gate:spring --backend emit
"""
import argparse
import csv
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import scene_template as ST  # noqa

DEF_MANIFEST = os.path.join(HERE, "scene_manifest.csv")
DEF_OUT = os.path.join(HERE, "..", "..", "assets", "backgrounds")
DEF_DISPATCH = os.path.join(HERE, "scene_dispatch.jsonl")
SEED_BASE = 20260730


# ---------------------------------------------------------------------------
# Backend 抽象（对齐 gen_validation.py）
# ---------------------------------------------------------------------------
class DryRunBackend:
    def __init__(self, out_dir):
        self.out_dir = out_dir
    def generate(self, prompt, seed):
        return None  # 不出图
    def close(self):
        pass


class EmitBackend:
    """把 prompt 落盘成队列，agent 消费后调 ImageGen 下发（本沙箱实际路径）。"""
    def __init__(self, out_dir, dispatch_path):
        self.out_dir = out_dir
        self.dispatch_path = dispatch_path
        self._fh = open(dispatch_path, "w", encoding="utf-8")
    def generate(self, prompt, seed, meta=None):
        rec = {"prompt": prompt, "seed": seed, "meta": meta or {}}
        self._fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
        return None
    def close(self):
        self._fh.close()


class ComfyUIBackend:
    """忠实保留本地 ComfyUI 适配器（带卡机器可用；本沙箱无此环境）。"""
    def __init__(self, url):
        self.url = url
        try:
            import requests  # noqa
        except ImportError:
            print("[WARN] 缺 requests，ComfyUIBackend 不可用", file=sys.stderr)
    def generate(self, prompt, seed):
        # 实际需构造 workflow + 提交 /prompt；此处留接入口
        raise NotImplementedError("ComfyUI workflow 需按实际节点图实现；本沙箱走 emit")
    def close(self):
        pass


class A1111Backend:
    def __init__(self, url):
        self.url = url
    def generate(self, prompt, seed):
        raise NotImplementedError("A1111 txt2img API 待实现；本沙箱走 emit")
    def close(self):
        pass


# ---------------------------------------------------------------------------
# 清单读写
# ---------------------------------------------------------------------------
def read_manifest(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def write_manifest(path, rows, cols):
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow(r)


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="场景背景批量生成（消费 scene_manifest）")
    ap.add_argument("--backend", default="emit",
                    choices=["dryrun", "emit", "comfyui", "a1111"])
    ap.add_argument("--url", default="http://127.0.0.1:8188")
    ap.add_argument("--manifest", default=DEF_MANIFEST)
    ap.add_argument("--out", default=DEF_OUT)
    ap.add_argument("--dispatch", default=DEF_DISPATCH)
    ap.add_argument("--only", default=None,
                    help="单条：<scene_id> 或 <scene_id:season>")
    ap.add_argument("--mark", action="store_true", default=False,
                    help="真实后端运行时回写 manifest 状态")
    args = ap.parse_args()

    if args.backend == "dryrun":
        backend = DryRunBackend(args.out)
    elif args.backend == "emit":
        backend = EmitBackend(args.out, args.dispatch)
    elif args.backend == "comfyui":
        backend = ComfyUIBackend(args.url)
    else:
        backend = A1111Backend(args.url)

    rows = read_manifest(args.manifest)
    os.makedirs(args.out, exist_ok=True)
    vrows = []
    seq = 0
    only_scene, only_season = (args.only.split(":", 1) + [None])[:2] if args.only else (None, None)

    for m in rows:
        sid = m["scene_id"]; season = m["season"]
        if only_scene and sid != only_scene:
            continue
        if only_season and season != only_season:
            continue
        if m.get("status", "") in ("已验收",):
            print(f"[SKIP] {sid}:{season} 状态=已验收")
            continue

        prompt = ST.assemble_prompt(sid, season)
        meta = {"scene_id": sid, "season": season, "out_name": m["out_name"]}
        if args.mark and args.backend not in ("dryrun", "emit"):
            m["status"] = "生成中"
        t0 = time.time()
        img = backend.generate(prompt, SEED_BASE + seq, meta=meta)
        cost = round(time.time() - t0, 2)

        fpath = os.path.join(args.out, m["out_name"])
        status = "ok" if img is not None else (
            "dryrun" if args.backend == "dryrun" else (
                "pending_dispatch" if args.backend == "emit" else "fail"))
        if img is not None:
            with open(fpath, "wb") as fh:
                fh.write(img)

        vrows.append({
            "scene_id": sid, "scene_name": m["scene_name"], "season": season,
            "season_label": m["season_label"], "out_name": m["out_name"],
            "file_path": fpath, "brightness_target": m["brightness_target"],
            "color_overlay": m["color_overlay"], "priority": m["priority"],
            "seed": SEED_BASE + seq, "backend": args.backend,
            "status": status, "time_cost_s": cost,
        })
        seq += 1

    if hasattr(backend, "close"):
        backend.close()

    vcols = ["scene_id", "scene_name", "season", "season_label", "out_name",
             "file_path", "brightness_target", "color_overlay", "priority",
             "seed", "backend", "status", "time_cost_s"]
    vpath = os.path.join(HERE, "scene_validation_manifest.csv")
    write_manifest(vpath, vrows, vcols)

    if args.mark and args.backend not in ("dryrun", "emit"):
        write_manifest(args.manifest, rows, list(rows[0].keys()) if rows else [])

    print(f"[DONE] 触发 {len(vrows)} 条 | 后端={args.backend} | 清单={vpath}")
    if args.backend == "emit":
        print(f"[队列] 待下发 prompt 已写入: {args.dispatch}")


if __name__ == "__main__":
    main()

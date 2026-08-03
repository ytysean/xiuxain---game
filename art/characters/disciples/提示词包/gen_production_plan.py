# -*- coding: utf-8 -*-
"""分批量产计划验证 + 计划表生成（无 GPU，纯 dryrun 验证 + 文件产出）。

产出：
  ../production_plan.csv  —— 90 原型逐条登记，含 batch 归属与逐批执行命令，status=未产出，可逐批勾选。
副作用：
  ../out_b1..out_b6       —— 6 批 dryrun 中间产物（验证后由调用方清理）。
"""
import csv
import json
import os
import subprocess
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
BS = 15
OUT = "../弟子立绘/output/production"


def main():
    mpy = sys.executable
    # 1) 跑 6 批 dryrun（variants-per-base 1 → 每批 15 图，全量 90）
    for b in range(1, 7):
        subprocess.run(
            [mpy, "batch_generate.py", "--backend", "dryrun", "--batch", str(b),
             "--variants-per-base", "1", "--out", f"../out_b{b}"],
            check=True, cwd=HERE,
        )

    # 2) 聚合验证：6 批必须正好铺满 90、无重叠
    all_rows = []
    for b in range(1, 7):
        with open(f"../out_b{b}/disciple_asset_manifest.csv", encoding="utf-8-sig") as f:
            all_rows += list(csv.DictReader(f))
    print("total rows across 6 batches :", len(all_rows))
    print("unique seq_id              :", len(set(r["seq_id"] for r in all_rows)))
    print("per-batch count            :",
          dict(sorted(((int(k), v) for k, v in Counter(r["batch"] for r in all_rows).items()))))
    ids = [r["seq_id"] for r in all_rows]
    dups = [k for k, v in Counter(ids).items() if v > 1]
    print("duplicate seq_id           :", dups if dups else "NONE")
    print("batch1 first / batch6 last :", all_rows[0]["seq_id"], "/", all_rows[-1]["seq_id"])

    # 3) 生成 production_plan.csv
    with open(os.path.join(HERE, "prompts_90.json"), encoding="utf-8") as f:
        prompts = json.load(f)["prompts"]
    plan = []
    for i, e in enumerate(prompts):
        batch = (i // BS) + 1
        cmd = (f"python batch_generate.py --backend comfyui --url http://127.0.0.1:8188 "
               f"--crop-avatar --variants-per-base 1 --batch {batch} --out {OUT}")
        plan.append({
            "idx": i + 1, "id": e["id"], "element": e["element"],
            "personality": e["personality"], "aptitude": e["aptitude"],
            "gender": e["gender"], "batch": batch, "status": "未产出",
            "run_command": cmd,
        })
    plan_path = os.path.join(HERE, "..", "production_plan.csv")
    with open(plan_path, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(
            f, fieldnames=["idx", "id", "element", "personality", "aptitude",
                           "gender", "batch", "status", "run_command"])
        w.writeheader()
        w.writerows(plan)
    print("wrote production_plan.csv  :", len(plan), "rows")
    print("batch composition (aptitude):")
    for b in range(1, 7):
        comp = Counter(r["aptitude"] for r in plan if r["batch"] == b)
        print(f"  batch {b}: {dict(comp)}")


if __name__ == "__main__":
    main()

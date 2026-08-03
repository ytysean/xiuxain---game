# -*- coding: utf-8 -*-
"""
太玄宗门录 · UI 核心按钮无水印批量出图  (batch_generate_ui.py)
=====================================================================
单一事实源：prompts_ui_regen.json（禁止在脚本内硬编码提示词）

职责（工业化量产节点，输出即对接 Godot 工程与数据层）：
  1. 解析 prompts_ui_regen.json（meta 模板 + 68 条 P0/P1/P2 核心按钮）
  2. 按 meta.prompt_template 注入 {icon} 与 {state} 描述，合成中英双向提示词
  3. 按 shape 取 gen_size 出图，再降采样到 deliver_size 对齐 Godot 组件尺寸
  4. 三级归档 + 规范命名（priority/kind/id.png）
  5. 按优先级分批（P0/P1/P2）+ 断点续跑（state.json）
  6. 资源清单 CSV
  7. 可选 --watermark-clean：对产出图跑 remove_watermark（默认关，仅平台通道应急）

后端抽象（Backends 插件式）：
  - DryRunBackend  : 仅产出参数 + 提示词 JSONL，不调用 API（本沙箱可验证逻辑）
  - ComfyUIBackend : 生产用，txt2img（需本地 ComfyUI 端点，天然无水印）
  - A1111Backend   : 生产用，AUTOMATIC1111 API（需本地端点，天然无水印）
  （平台 ImageGen 不走脚本；脚本只负责本地 SD 管线。--watermark-clean 仅供
   接了会带水印的通道时兜底）

人工只做决策与验收，不做重复操作：模板/负向词/尺寸/命名全部脚本强制锁定。

Usage:
  python batch_generate_ui.py --source prompts_ui_regen.json --out out_ui --backend dryrun
  python batch_generate_ui.py --priority P0 --backend comfyui --url http://127.0.0.1:8188
  python batch_generate_ui.py --id nav_jy_selected --backend a1111 --url http://127.0.0.1:7860
"""
from __future__ import annotations
import argparse
import csv
import json
import os
import sys
import time
from abc import ABC, abstractmethod

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REF_WATERMARK = os.path.join(SCRIPT_DIR, "png", "sq_base_N.png")


# ----------------------------------------------------------------------------
# 单一事实源加载 + 提示词合成
# ----------------------------------------------------------------------------
def load_prompts(source):
    with open(source, encoding="utf-8") as f:
        data = json.load(f)
    meta = data.get("meta", {})
    prompts = data.get("prompts", [])
    if not prompts:
        raise SystemExit("[FATAL] prompts_ui_regen.json 无 prompts 字段")
    return meta, prompts


def compose_prompt(entry, meta):
    """返回 (prompt_cn, prompt_en)。"""
    tpl_cn = meta["prompt_template_cn"]
    tpl_en = meta["prompt_template_en"]
    state_desc_cn = meta.get("state_desc_cn", {})
    state_desc_en = meta.get("state_desc_en", {})
    st = entry.get("state", "normal")
    state_cn = state_desc_cn.get(st, state_desc_cn.get("normal", ""))
    state_en = state_desc_en.get(st, state_desc_en.get("normal", ""))
    prompt_cn = tpl_cn.format(icon=entry["icon_cn"], state=state_cn)
    prompt_en = tpl_en.format(icon=entry["icon_en"], state=state_en)
    return prompt_cn, prompt_en


# ----------------------------------------------------------------------------
# 后端抽象
# ----------------------------------------------------------------------------
class Backend(ABC):
    @abstractmethod
    def generate(self, prompt_cn, prompt_en, negative, width, height, seed):
        """返回 PNG bytes；DryRun 返回 None。"""
        raise NotImplementedError


class DryRunBackend(Backend):
    """不调用任何 API，仅把每条完整参数写入 params JSONL，用于逻辑验证。"""
    def __init__(self, out_dir):
        self.param_log = os.path.join(out_dir, "_dryrun_params.jsonl")
        self._fh = open(self.param_log, "w", encoding="utf-8")

    def generate(self, prompt_cn, prompt_en, negative, width, height, seed):
        rec = {
            "seed": seed, "width": width, "height": height,
            "prompt_cn": prompt_cn, "prompt_en": prompt_en, "negative": negative,
        }
        self._fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
        return None

    def close(self):
        self._fh.close()


class ComfyUIBackend(Backend):
    """生产用：ComfyUI /prompt API，txt2img（无 ControlNet，UI 靠提示词锁形）。
    需本地端点（--url）与可用 checkpoint（--ckpt）。自动轮询 /history 并拉取
    /view 取回 PNG 二进制。透明背景依赖 --rmbg 后处理或你 ComfyUI 内 alpha 节点。"""
    def __init__(self, url, ckpt="v1-5-pruned-emaonly.safetensors", steps=30, cfg=7.0):
        import urllib.request
        import uuid
        self.url = url.rstrip("/")
        self._urllib = urllib.request
        self.ckpt = ckpt
        self.steps = steps
        self.cfg = cfg
        self.client_id = str(uuid.uuid4())

    def _post(self, path, payload):
        data = json.dumps(payload).encode("utf-8")
        req = self._urllib.Request(self.url + path, data=data,
                                   headers={"Content-Type": "application/json"})
        with self._urllib.urlopen(req, timeout=600) as resp:
            return json.loads(resp.read().decode("utf-8"))

    def _get(self, path):
        req = self._urllib.Request(self.url + path)
        with self._urllib.urlopen(req, timeout=600) as resp:
            ctype = resp.headers.get("Content-Type", "")
            body = resp.read()
            if ctype.startswith("application/json"):
                return json.loads(body.decode("utf-8"))
            return body  # 原始字节（图片）

    def generate(self, prompt_cn, prompt_en, negative, width, height, seed):
        # 完整 txt2img workflow：CheckpointLoaderSimple 输出 [MODEL, CLIP, VAE]
        workflow = {
            "3": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": self.ckpt}},
            "4": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt_cn, "clip": ["3", 1]}},
            "5": {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": ["3", 1]}},
            "6": {"class_type": "EmptyLatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
            "7": {"class_type": "KSampler", "inputs": {
                "seed": seed, "steps": self.steps, "cfg": self.cfg,
                "sampler_name": "dpmpp_2m", "scheduler": "karras", "denoise": 1.0,
                "model": ["3", 0], "positive": ["4", 0], "negative": ["5", 0],
                "latent_image": ["6", 0]}},
            "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["3", 2]}},
            "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "ui_btn"}},
        }
        payload = {"prompt": workflow, "client_id": self.client_id}
        try:
            r = self._post("/prompt", payload)
            prompt_id = r.get("prompt_id")
            if not prompt_id:
                print(f"[WARN] ComfyUI 未返回 prompt_id：{r}", file=sys.stderr)
                return None
            import time as _t
            for _ in range(180):  # 最多轮询 ~15 分钟
                hist = self._get(f"/history/{prompt_id}")
                if prompt_id in hist and "outputs" in hist[prompt_id]:
                    outputs = hist[prompt_id]["outputs"]
                    imgs = outputs.get("9", {}).get("images")
                    if imgs:
                        info = imgs[0]
                        raw = self._get(
                            f"/view?filename={info['filename']}"
                            f"&subfolder={info.get('subfolder', '')}"
                            f"&type={info.get('type', '')}"
                        )
                        if isinstance(raw, bytes):
                            return raw
                    return None
                _t.sleep(5)
            print("[WARN] ComfyUI 轮询超时（15min），请检查端点", file=sys.stderr)
            return None
        except Exception as e:  # noqa
            print(f"[WARN] ComfyUI 调用失败（端点 {self.url}）：{e}", file=sys.stderr)
            return None


class A1111Backend(Backend):
    """生产用：AUTOMATIC1111 /sdapi/v1/txt2img。"""
    def __init__(self, url):
        import urllib.request
        self.url = url.rstrip("/")
        self._urllib = urllib.request

    def generate(self, prompt_cn, prompt_en, negative, width, height, seed):
        payload = {
            "prompt": prompt_cn, "negative_prompt": negative,
            "width": width, "height": height,
            "seed": seed, "steps": 30, "cfg_scale": 7.0,
            "sampler_name": "DPM++ 2M Karras", "n_iter": 1, "batch_size": 1,
        }
        try:
            data = json.dumps(payload).encode("utf-8")
            req = self._urllib.Request(self.url + "/sdapi/v1/txt2img", data=data,
                                       headers={"Content-Type": "application/json"})
            with self._urllib.urlopen(req, timeout=600) as resp:
                r = json.loads(resp.read().decode("utf-8"))
                import base64
                return base64.b64decode(r["images"][0])
        except Exception as e:  # noqa
            print(f"[WARN] A1111 调用失败（端点 {self.url}）：{e}", file=sys.stderr)
            return None


# ----------------------------------------------------------------------------
# 归档 / 状态 / 清单
# ----------------------------------------------------------------------------
def archive_dir(out_dir, entry):
    d = os.path.join(out_dir, entry["priority"], entry["kind"])
    os.makedirs(d, exist_ok=True)
    return d


def asset_filename(entry):
    return f"{entry['id']}.png"


def load_state(out_dir):
    sp = os.path.join(out_dir, "state.json")
    if os.path.exists(sp):
        with open(sp, encoding="utf-8") as f:
            return json.load(f).get("done", {})
    return {}


def save_state(out_dir, done):
    with open(os.path.join(out_dir, "state.json"), "w", encoding="utf-8") as f:
        json.dump({"done": done}, f, ensure_ascii=False, indent=2)


def write_manifest(out_dir, rows):
    cols = ["seq_id", "asset_id", "priority", "kind", "shape",
            "file_path", "gen_w", "gen_h", "deliver_w", "deliver_h",
            "seed", "backend", "watermark_cleaned", "status", "time_cost_s"]
    with open(os.path.join(out_dir, "ui_asset_manifest.csv"), "w",
              newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow(r)


# ----------------------------------------------------------------------------
# 可选水印清理（应急兜底，默认关）
# ----------------------------------------------------------------------------
def maybe_clean(path, enabled, mask_ref):
    if not enabled or mask_ref is None:
        return False
    try:
        from PIL import Image
        import remove_watermark as rw
        img = Image.open(path)
        cleaned = rw.remove_watermark_from_image(img, mask_ref)
        cleaned.save(path)
        return True
    except Exception as e:  # noqa
        print(f"[WARN] 水印清理失败 {path}: {e}", file=sys.stderr)
        return False


def maybe_rmbg(im):
    """可选透明背景后处理：SD 原生输出 RGB 无 alpha，需 rembg（BiRefNet/RMBG）补透明通道。
    若未安装 rembg，则返回原图并告警（此时应在 ComfyUI 内用 alpha 节点，如 LayerDiffuse）。"""
    try:
        from rembg import remove
        return remove(im.convert("RGBA"))
    except Exception as e:  # noqa
        print(f"[WARN] rmbg 不可用（需 pip install rembg，或在 ComfyUI 内用 alpha 节点）：{e}", file=sys.stderr)
        return im


# ----------------------------------------------------------------------------
# 主流程
# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="太玄宗门录 UI 按钮批量出图")
    ap.add_argument("--source", default=os.path.join(SCRIPT_DIR, "prompts_ui_regen.json"))
    ap.add_argument("--out", default=os.path.join(SCRIPT_DIR, "out_ui"))
    ap.add_argument("--backend", default="dryrun", choices=["dryrun", "comfyui", "a1111"])
    ap.add_argument("--url", default="http://127.0.0.1:8188")
    ap.add_argument("--priority", default="ALL", choices=["ALL", "P0", "P1", "P2"])
    ap.add_argument("--id", default=None, help="仅跑指定 id")
    ap.add_argument("--seed", type=int, default=20260730)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--watermark-clean", dest="wm_clean", action="store_true", default=False)
    ap.add_argument("--no-downscale", dest="downscale", action="store_false", default=True)
    ap.add_argument("--ckpt", default=None, help="ComfyUI 使用的 checkpoint 文件名（覆盖 meta.comfyui_ckpt）")
    ap.add_argument("--rmbg", action="store_true", default=False, help="出图后去背（需 pip install rembg），解决 SD 原生无透明通道问题")
    args = ap.parse_args()

    meta, prompts = load_prompts(args.source)
    negative = meta.get("negative_prompt", "")
    ckpt = args.ckpt or meta.get("comfyui_ckpt", "v1-5-pruned-emaonly.safetensors")
    gen_size = meta.get("gen_size", {"square": [1024, 1024], "bar": [1024, 256]})
    deliver_size = meta.get("deliver_size", {"square": [256, 256], "bar": [512, 128]})
    wm_default = meta.get("watermark_clean_default", False)
    wm_enabled = args.wm_clean or wm_default

    os.makedirs(args.out, exist_ok=True)
    if args.backend == "dryrun":
        backend = DryRunBackend(args.out)
    elif args.backend == "comfyui":
        backend = ComfyUIBackend(args.url, ckpt=ckpt)
    else:
        backend = A1111Backend(args.url)

    # 水印掩膜（仅 --watermark-clean 时加载）
    mask_ref = None
    if wm_enabled:
        if os.path.exists(REF_WATERMARK):
            try:
                import remove_watermark as rw
                mask_ref = rw.extract_reference_mask(REF_WATERMARK)
                print(f"[INFO] 水印清理已启用，参考掩膜来自 {REF_WATERMARK}")
            except Exception as e:  # noqa
                print(f"[WARN] 无法加载水印掩膜：{e}", file=sys.stderr)
        else:
            print(f"[WARN] 参考图缺失 {REF_WATERMARK}，跳过水印清理", file=sys.stderr)

    done = {} if args.force else load_state(args.out)
    rows = []
    seq_counter = 0

    targets = prompts
    if args.id:
        targets = [p for p in prompts if p["id"] == args.id]
    elif args.priority != "ALL":
        targets = [p for p in prompts if p["priority"] == args.priority]

    for entry in targets:
        if args.limit and seq_counter >= args.limit:
            break
        key = entry["id"]
        if key in done and not args.force:
            continue
        shape = entry.get("shape", "square")
        gw, gh = gen_size.get(shape, gen_size["square"])
        dw, dh = deliver_size.get(shape, deliver_size["square"])

        t0 = time.time()
        prompt_cn, prompt_en = compose_prompt(entry, meta)
        img_bytes = backend.generate(prompt_cn, prompt_en, negative, gw, gh,
                                     args.seed + seq_counter)
        cost = round(time.time() - t0, 2)

        d = archive_dir(args.out, entry)
        fpath = os.path.join(d, asset_filename(entry))
        cleaned = False
        status = "ok" if img_bytes is not None else ("dryrun" if args.backend == "dryrun" else "fail")

        if img_bytes is not None:
            import base64
            from PIL import Image
            import io
            im = Image.open(io.BytesIO(img_bytes)).convert("RGBA")
            if args.rmbg:
                im = maybe_rmbg(im)
            if args.downscale and (im.width != dw or im.height != dh):
                im = im.resize((dw, dh), Image.LANCZOS)
            im.save(fpath)
            cleaned = maybe_clean(fpath, wm_enabled, mask_ref)

        rows.append({
            "seq_id": key, "asset_id": entry["id"], "priority": entry["priority"],
            "kind": entry["kind"], "shape": shape, "file_path": fpath,
            "gen_w": gw, "gen_h": gh, "deliver_w": dw, "deliver_h": dh,
            "seed": args.seed + seq_counter, "backend": args.backend,
            "watermark_cleaned": "yes" if cleaned else "no",
            "status": status, "time_cost_s": cost,
        })
        done[key] = {"path": fpath, "status": status}
        save_state(args.out, done)
        seq_counter += 1

    if hasattr(backend, "close"):
        backend.close()
    write_manifest(args.out, rows)
    print(f"[DONE] 生成 {len(rows)} 条 | 后端={args.backend} | 水印清理={'开' if wm_enabled else '关'} | 清单={os.path.join(args.out, 'ui_asset_manifest.csv')}")


if __name__ == "__main__":
    main()

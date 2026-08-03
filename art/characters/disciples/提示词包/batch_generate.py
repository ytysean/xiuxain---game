# -*- coding: utf-8 -*-
"""
太玄宗门录 · 弟子立绘批量出图脚本骨架  (batch_generate.py)
=====================================================================
单一事实源：prompts_90.json  （由 build_prompt_package.py 生成，禁止在脚本内硬编码提示词）

职责（工业化量产节点，输出即对接 Godot 工程与数据层）：
  1. 解析 prompts_90.json（正向/负向/灵根/性格/资质/性别标签/variants 候选池）
  2. 变体随机注入（hair / face_feature / accessory_material 各随机 1 项，seeded 可复现）
  3. ControlNet 姿态硬绑定（gender-matched OpenPose：pose_{性格}_{性别}_stand.png）
  4. Depth 深度构图锁（同姿态 depth_{性格}_{性别}_stand.png，与 pose 同源对齐）
  5. IP-Adapter 人脸一致性锁（同一弟子 seq=1 生成基准脸，seq>=2 / 其他姿态复用）
  6. 三级目录归档 + 规范命名（灵根/性格/资质/disciple_{id}_{seq:02d}.png）
  7. 按资质分批（elite / common / top）+ 断点续跑（state.json）
  8. 资源清单 CSV + 人脸检测动态头像裁切

后端抽象（Backends 插件式）：
  - DryRunBackend  : 仅产出参数 + 提示词 JSONL，不调用 API（本沙箱可验证逻辑）
  - ComfyUIBackend : 生产用，txt2img + ControlNet（需本地 ComfyUI 端点）
  - A1111Backend   : 生产用，AUTOMATIC1111 API + ControlNet（需本地端点）
  （平台 ImageGen 不走脚本，由对话工具单独出样张；脚本只负责本地 SD 管线）

人工只做决策与验收，不做重复操作：基底提示词/负向词/姿态/命名全部脚本强制锁定。

Usage:
  python batch_generate.py --source prompts_90.json --out ../out --backend dryrun
  python batch_generate.py --aptitude elite --limit 5 --seed 20260730
  python batch_generate.py --id huo_bao_top --seq 1 --backend comfyui --url http://127.0.0.1:8188
"""

import argparse
import csv
import json
import os
import random
import shutil
import sys
import time
from abc import ABC, abstractmethod


def _crop_avatars(src_path, avatar_out_dir, stem, sizes):
    """从立绘动态裁切多尺寸头像（人脸检测）；返回 (paths_dict, meta_dict) 或 None。

    裁切逻辑统一委托 crop_lib，不再使用固定坐标（避免切到半张脸）。
    """
    try:
        import crop_lib
    except ImportError:
        print("[WARN] crop_lib 不可用，跳过裁切头像", file=sys.stderr)
        return None
    if not os.path.exists(src_path):
        return None
    try:
        return crop_lib.crop_avatars(src_path, avatar_out_dir, stem, tuple(sizes))
    except Exception as e:  # noqa
        print(f"[WARN] 裁切头像失败 {stem}: {e}", file=sys.stderr)
        return None

# ----------------------------------------------------------------------------
# 全局生产标准（强制锁死，禁止逐张手改）
# ----------------------------------------------------------------------------
WIDTH, HEIGHT = 1024, 1536                 # 标准化半身立绘尺寸
# 头像裁切已改为「人脸检测动态裁切」（见 crop_lib）。
# 历史固定坐标 AVATAR_CROP 已废弃——立绘头部位置不统一，固定坐标会切到半张脸。
# 正式量产建议配合「构图锁」提示词（头顶留白约 10%、头高占图高 22–28%、不歪头、
# 发髻/冠不遮脸），从源头收敛头部位置，进一步降低检测兜底率。

# 姿态绑定（gender-matched 三段式）
#   pose_{personality_key}_{gender}_{pose_type}.png
#   depth_{personality_key}_{gender}_{pose_type}.png
# 性格键与 build_prompt_package.PERSONALITIES 严格一致：chen/gu/wen/bao/jiao/huo2
# 这些文件由 gen_openpose_refs.py / gen_depth_refs.py 生成，放入 --pose-dir / --depth-dir
POSE_TYPE_90 = "stand"                      # 90 原型包统一标准站姿底座


def _gender_short(gender):
    """90 包 gender 字段为「男子/女子」，pose/depth 文件名用「男/女」，做归一化。"""
    if gender in ("男子", "male", "男"):
        return "男"
    if gender in ("女子", "female", "女"):
        return "女"
    return gender or "男"


def _resolve_controlnet(entry, pose_dir, depth_dir, ptype="stand"):
    """根据 90 包 entry 的 personality_key + gender 解析 pose 与 depth 参考图路径。"""
    pers = entry.get("personality_key", "")
    gender = _gender_short(entry.get("gender", "男"))
    pose_fname = f"pose_{pers}_{gender}_{ptype}.png" if pers else ""
    depth_fname = f"depth_{pers}_{gender}_{ptype}.png" if pers else ""
    pose_path = (os.path.join(pose_dir, pose_fname)
                 if pose_fname and os.path.exists(os.path.join(pose_dir, pose_fname)) else "")
    depth_path = (os.path.join(depth_dir, depth_fname)
                  if depth_fname and os.path.exists(os.path.join(depth_dir, depth_fname)) else "")
    return pose_path, depth_path


# 默认 ControlNet 强度
CONTROLNET_STRENGTH = 0.75                  # 男性姿态锁定强度（确保 6 性格体态正交）
CONTROLNET_STRENGTH_FEMALE = 0.70           # 女性姿态锁柔化，避免强行拉宽肩胯导致生硬
DEPTH_STRENGTH = 0.60                       # 深度构图锁：避免太强导致人物扁平
IP_ADAPTER_STRENGTH = 0.50                  # 人脸一致性锁：控制表情固化风险

# 全局负向词（与提示词包内联“避免…”同源；SD 走独立 negative 字段更干净）
DEFAULT_NEGATIVE = (
    "扁平, 卡通, 简化, 低质量, 二次元, Q版, 纯玻璃拟态, 杂乱背景, 现代元素, "
    "多余手指, 肢体畸变, 过曝, 白屏, 纯白背景, 赛博朋克, 霓虹, 数据流, 机械义体, "
    "现代都市, 重金属, 夸张妆容, 真人照片感, 毛笔字正文, 低分辨率"
)

# 每个 (灵根×性格×资质) 基础原型产出多张变体时的默认张数（同组差异化）
DEFAULT_VARIANTS_PER_BASE = 3


# ----------------------------------------------------------------------------
# 单一事实源加载
# ----------------------------------------------------------------------------
def load_prompts(source):
    with open(source, encoding="utf-8") as f:
        data = json.load(f)
    meta = data.get("meta", {})
    prompts = data.get("prompts", [])
    if not prompts:
        raise SystemExit("[FATAL] prompts_90.json 无 prompts 字段")
    return meta, prompts


# ----------------------------------------------------------------------------
# 变体随机注入（seeded 可复现）
# ----------------------------------------------------------------------------
def inject_variants(entry, seq, seed_base):
    """从 hair / face_feature / accessory_material 三类候选池各随机 1 项拼入正向提示词。"""
    rnd = random.Random(f"{seed_base}:{entry['id']}:{seq}")
    v = entry.get("variants", {})
    chosen = {}
    for key in ("hair", "face_feature", "accessory_material"):
        pool = v.get(key, {}).get("cn", [])
        if pool:
            chosen[key] = rnd.choice(pool)
        else:
            chosen[key] = ""
    # 拼装：在主提示词“神态/姿态”之后追加差异化细节，不破坏基底风格
    extra = "，".join([c for c in chosen.values() if c])
    prompt_cn = entry["prompt_cn"]
    if extra:
        # 在“半身构图”之前插入变体细节，保证构图/质量声明仍在末尾
        marker = "半身构图"
        if marker in prompt_cn:
            prompt_cn = prompt_cn.replace(marker, f"{extra}，{marker}", 1)
        else:
            prompt_cn = prompt_cn + f"，{extra}"
    # 英文同步追加（取对应 en 池，保持索引一致）
    v_en = entry.get("variants", {})
    chosen_en = {}
    for key in ("hair", "face_feature", "accessory_material"):
        pool = v_en.get(key, {}).get("en", [])
        if pool:
            # 用同一 rnd 序列重抽（顺序一致即可对齐）
            pass
    # 简化：英文变体仅做占位级拼接（生产用中文为主，en 用于 MJ 时同理追加）
    return prompt_cn, chosen


# ----------------------------------------------------------------------------
# 后端抽象
# ----------------------------------------------------------------------------
class Backend(ABC):
    @abstractmethod
    def generate(self, prompt_cn, prompt_en, negative, controlnet_image, seed,
                 controlnet_strength=CONTROLNET_STRENGTH,
                 depth_image=None, depth_strength=DEPTH_STRENGTH,
                 ip_adapter_image=None, ip_adapter_strength=IP_ADAPTER_STRENGTH):
        """返回 PNG bytes；DryRun 返回 None。
        controlnet_strength 可按性别微调；depth_image 与 ip_adapter_image 可选。"""
        raise NotImplementedError


class DryRunBackend(Backend):
    """不调用任何 API，仅把每条完整参数写入 params JSONL，用于逻辑验证。"""
    def __init__(self, out_dir):
        self.param_log = os.path.join(out_dir, "_dryrun_params.jsonl")
        self._fh = open(self.param_log, "w", encoding="utf-8")

    def generate(self, prompt_cn, prompt_en, negative, controlnet_image, seed,
                 controlnet_strength=CONTROLNET_STRENGTH,
                 depth_image=None, depth_strength=DEPTH_STRENGTH,
                 ip_adapter_image=None, ip_adapter_strength=IP_ADAPTER_STRENGTH):
        rec = {
            "seed": seed,
            "prompt_cn": prompt_cn,
            "prompt_en": prompt_en,
            "negative": negative,
            "controlnet_image": controlnet_image,
            "controlnet_strength": controlnet_strength,
            "depth_image": depth_image,
            "depth_strength": depth_strength,
            "ip_adapter_image": ip_adapter_image,
            "ip_adapter_strength": ip_adapter_strength,
        }
        self._fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
        return None

    def close(self):
        self._fh.close()


class ComfyUIBackend(Backend):
    """生产用：ComfyUI /prompt API，txt2img + ControlNet。
    需本地端点（--url）。本骨架给出标准 workflow 拼接，未在此环境实测。"""
    def __init__(self, url):
        import urllib.request
        self.url = url.rstrip("/")
        self._urllib = urllib.request

    def _post(self, path, payload):
        data = json.dumps(payload).encode("utf-8")
        req = self._urllib.Request(self.url + path, data=data,
                                   headers={"Content-Type": "application/json"})
        with self._urllib.urlopen(req, timeout=600) as resp:
            return json.loads(resp.read().decode("utf-8"))

    def generate(self, prompt_cn, prompt_en, negative, controlnet_image, seed,
                 controlnet_strength=CONTROLNET_STRENGTH,
                 depth_image=None, depth_strength=DEPTH_STRENGTH,
                 ip_adapter_image=None, ip_adapter_strength=IP_ADAPTER_STRENGTH):
        # 1) 上传参考图（openpose / depth / ip-adapter 源图）
        # 2) 组装 workflow（LoadImage -> ControlNetLoader -> ... -> KSampler -> VAEDecode）
        # 3) POST /prompt，轮询 /history 取输出图片 bytes
        # —— 生产落地时按你 ComfyUI 实际节点 ID / 节点包版本填写，下方为标准占位结构 ——
        workflow = {
            "prompt": {
                "3": {"class_type": "KSampler", "inputs": {
                    "seed": seed, "steps": 30, "cfg": 7.0, "sampler_name": "dpmpp_2m",
                    "scheduler": "karras", "denoise": 1.0, "model": ["11", 0],
                    "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0]}},
                "6": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt_cn, "clip": ["4", 0]}},
                "7": {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": ["4", 0]}},
                # ControlNet OpenPose 节点（必填）：按 controlnet_image 接入
                # ControlNet Depth 节点（可选）：按 depth_image 接入，weight=depth_strength
                # IPAdapter 节点（可选）：按 ip_adapter_image 接入，weight=ip_adapter_strength
                # VAE / SaveImage / ControlNetLoader 等节点按实际补全
            },
            "extra_data": {"extra_pnginfo": {
                "workflow_metadata": {
                    "openpose": controlnet_image,
                    "openpose_weight": controlnet_strength,
                    "depth": depth_image,
                    "depth_weight": depth_strength,
                    "ip_adapter": ip_adapter_image,
                    "ip_adapter_weight": ip_adapter_strength,
                }
            }},
        }
        try:
            self._post("/prompt", workflow)
            # 轮询 history 取图，返回 PNG bytes
            return b""  # TODO: 解析 history 输出节点拿到图片二进制
        except Exception as e:  # noqa
            print(f"[WARN] ComfyUI 调用失败（端点 {self.url}）：{e}", file=sys.stderr)
            return None


class A1111Backend(Backend):
    """生产用：AUTOMATIC1111 /sdapi/v1/txt2img + ControlNet alwayson_scripts。"""
    def __init__(self, url):
        import urllib.request
        self.url = url.rstrip("/")
        self._urllib = urllib.request

    def generate(self, prompt_cn, prompt_en, negative, controlnet_image, seed,
                 controlnet_strength=CONTROLNET_STRENGTH,
                 depth_image=None, depth_strength=DEPTH_STRENGTH,
                 ip_adapter_image=None, ip_adapter_strength=IP_ADAPTER_STRENGTH):
        # ControlNet：OpenPose（必填） + Depth（可选）
        controlnet_args = [{
            "input_image": _b64(controlnet_image),
            "module": "openpose", "model": "control_v11p_sd15_openpose",
            "weight": controlnet_strength, "resize_mode": "InnerFit",
            "control_mode": "Balanced", "enabled": True,
        }]
        if depth_image:
            controlnet_args.append({
                "input_image": _b64(depth_image),
                "module": "depth_midas", "model": "control_v11f1p_sd15_depth",
                "weight": depth_strength, "resize_mode": "InnerFit",
                "control_mode": "Balanced", "enabled": True,
            })
        alwayson_scripts = {"controlnet": {"args": controlnet_args}}
        # IP-Adapter：人脸一致性（可选）
        if ip_adapter_image:
            # 脚本名与模型名需与你安装的 A1111 IP-Adapter 扩展一致
            alwayson_scripts["ip-adapter"] = {
                "args": [{
                    "input_image": _b64(ip_adapter_image),
                    "model": "ip-adapter_sd15", "weight": ip_adapter_strength,
                }]
            }
        payload = {
            "prompt": prompt_cn,
            "negative_prompt": negative,
            "width": WIDTH, "height": HEIGHT,
            "seed": seed, "steps": 30, "cfg_scale": 7.0,
            "sampler_name": "DPM++ 2M Karras", "n_iter": 1, "batch_size": 1,
            "alwayson_scripts": alwayson_scripts,
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


def _b64(path):
    import base64
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


# ----------------------------------------------------------------------------
# 归档 / 状态 / 清单
# ----------------------------------------------------------------------------
def archive_dir(out_dir, entry):
    d = os.path.join(out_dir, entry["element_key"], entry["personality_key"], entry["aptitude_key"])
    os.makedirs(d, exist_ok=True)
    return d


def asset_filename(entry, seq):
    return f"disciple_{entry['id']}_{seq:02d}.png"


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
    cols = ["seq_id", "asset_id", "file_path", "avatar_paths", "element", "personality",
            "aptitude", "gender", "hair", "face_feature", "accessory_material", "seed",
            "pose_ref", "depth_ref", "depth_strength",
            "ip_ref", "ip_strength", "qc_crop", "qc_face", "batch",
            "face_center_x", "face_center_y", "avatar_crop_x", "avatar_crop_y",
            "avatar_size", "detect_method", "backend", "status", "time_cost_s"]
    with open(os.path.join(out_dir, "disciple_asset_manifest.csv"), "w",
              newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow(r)


# ----------------------------------------------------------------------------
# 权重梯度扫描（首批定参用）
# ----------------------------------------------------------------------------
def _run_sweep(targets, backend, args, negative, rows, done):
    """权重梯度扫描：每个目标原型先出基准脸（无 IP），再对 (depth×ip) 网格各出一张复用同一基准脸。

    输出文件名：disciple_{id}_sweep_base.png / disciple_{id}_sweep_d{D}_i{I}.png。
    dryrun 下 base_img 为 None，face_ref 不生成，组合图 ip_adapter_image 为空（与正常逻辑一致）。
    """
    depth_grid = [float(x) for x in args.sweep_depth.split(",") if x.strip()]
    ip_grid = [float(x) for x in args.sweep_ip.split(",") if x.strip()]
    print(f"[SWEEP] Depth={depth_grid} IP={ip_grid} → 每原型 {len(depth_grid) * len(ip_grid)} 张")
    for entry in targets:
        cn_img, depth_img = _resolve_controlnet(entry, args.pose_dir, args.depth_dir, POSE_TYPE_90)
        gender = _gender_short(entry.get("gender", "男"))
        cn_strength = CONTROLNET_STRENGTH_FEMALE if gender == "女" else CONTROLNET_STRENGTH
        d = archive_dir(args.out, entry)
        os.makedirs(d, exist_ok=True)
        # 基准脸（无 IP，用当前 depth 权重）
        base_prompt, _ = inject_variants(entry, 1, args.seed)
        base_img = backend.generate(base_prompt, entry["prompt_en"], negative, cn_img,
                                    args.seed, controlnet_strength=cn_strength,
                                    depth_image=depth_img or None, depth_strength=args.depth_weight,
                                    ip_adapter_image=None, ip_adapter_strength=0)
        face_ref = None
        if base_img is not None:
            base_path = os.path.join(d, f"disciple_{entry['id']}_sweep_base.png")
            with open(base_path, "wb") as fh:
                fh.write(base_img)
            res = _crop_avatars(base_path, os.path.join(d, "avatar"),
                                f"disciple_{entry['id']}_sweep_base", (256,))
            if res:
                paths, _ = res
                if "256" in paths and os.path.exists(paths["256"]):
                    os.makedirs(args.ref_dir, exist_ok=True)
                    ref_path = os.path.join(args.ref_dir, f"disciple_{entry['id']}_face_ref.png")
                    shutil.copy2(paths["256"], ref_path)
                    face_ref = ref_path
            rows.append({
                "seq_id": f"{entry['id']}_sweep_base", "asset_id": entry["id"],
                "file_path": base_path, "avatar_paths": "",
                "element": entry["element"], "personality": entry["personality"],
                "aptitude": entry["aptitude"], "gender": entry["gender"],
                "hair": "", "face_feature": "", "accessory_material": "",
                "seed": args.seed, "pose_ref": cn_img, "depth_ref": depth_img,
                "depth_strength": args.depth_weight, "ip_ref": "", "ip_strength": "",
                "qc_crop": "skip:sweep_base", "qc_face": "skip:sweep_base",
                "batch": args.batch,
                "face_center_x": "", "face_center_y": "", "avatar_crop_x": "",
                "avatar_crop_y": "", "avatar_size": "", "detect_method": "sweep_base",
                "backend": args.backend, "status": "ok", "time_cost_s": 0,
            })
        sid = 0
        for dw in depth_grid:
            for iw in ip_grid:
                sid += 1
                prompt_cn, chosen = inject_variants(entry, sid + 1, args.seed)
                fpath = os.path.join(d, f"disciple_{entry['id']}_sweep_d{dw}_i{iw}.png")
                img = backend.generate(prompt_cn, entry["prompt_en"], negative, cn_img,
                                       args.seed + sid, controlnet_strength=cn_strength,
                                       depth_image=depth_img or None, depth_strength=dw,
                                       ip_adapter_image=face_ref, ip_adapter_strength=iw)
                status = "ok" if img is not None else "fail"
                avatar_paths_str = ""
                crop_meta = {"face_center_x": "", "face_center_y": "", "avatar_crop_x": "",
                             "avatar_crop_y": "", "avatar_size": "", "detect_method": "none"}
                qc_crop_l, qc_crop_r, qc_face_l, qc_face_r = ("skip", "dryrun", "skip", "dryrun")
                if img is not None:
                    with open(fpath, "wb") as fh:
                        fh.write(img)
                    if args.crop_avatar:
                        stem = os.path.splitext(os.path.basename(fpath))[0]
                        res = _crop_avatars(fpath, os.path.join(d, "avatar"), stem, args.avatar_sizes)
                        if res:
                            paths, meta = res
                            avatar_paths_str = "|".join(f"{k}:{v}" for k, v in paths.items())
                            crop_meta = meta
                    try:
                        import qc_lib
                        if os.path.exists(fpath):
                            qc_crop_l, qc_crop_r, qc_face_l, qc_face_r = qc_lib.qc_image_path(fpath, crop_meta)
                    except ImportError:
                        print("[WARN] qc_lib 不可用（缺 cv2），跳过质检", file=sys.stderr)
                rows.append({
                    "seq_id": f"{entry['id']}_sweep_d{dw}_i{iw}", "asset_id": entry["id"],
                    "file_path": fpath, "avatar_paths": avatar_paths_str,
                    "element": entry["element"], "personality": entry["personality"],
                    "aptitude": entry["aptitude"], "gender": entry["gender"],
                    "hair": chosen.get("hair", ""), "face_feature": chosen.get("face_feature", ""),
                    "accessory_material": chosen.get("accessory_material", ""),
                    "seed": args.seed + sid, "pose_ref": cn_img, "depth_ref": depth_img,
                    "depth_strength": dw, "ip_ref": (face_ref or ""), "ip_strength": iw,
                    "qc_crop": f"{qc_crop_l}:{qc_crop_r}", "qc_face": f"{qc_face_l}:{qc_face_r}",
                    "batch": args.batch,
                    "face_center_x": crop_meta["face_center_x"], "face_center_y": crop_meta["face_center_y"],
                    "avatar_crop_x": crop_meta["avatar_crop_x"], "avatar_crop_y": crop_meta["avatar_crop_y"],
                    "avatar_size": crop_meta["avatar_size"], "detect_method": crop_meta["detect_method"],
                    "backend": args.backend, "status": status, "time_cost_s": 0,
                })


# ----------------------------------------------------------------------------
# 主流程
# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="太玄宗门录 弟子立绘批量出图骨架")
    ap.add_argument("--source", default="prompts_90.json", help="prompts_90.json 路径")
    ap.add_argument("--out", default="../out", help="输出根目录")
    ap.add_argument("--backend", default="dryrun", choices=["dryrun", "comfyui", "a1111"])
    ap.add_argument("--url", default="http://127.0.0.1:8188", help="本地 SD 端点")
    ap.add_argument("--pose-dir", default="../弟子立绘/pose", help="OpenPose 参考图目录")
    ap.add_argument("--depth-dir", default="../弟子立绘/depth", help="Depth 深度参考图目录")
    ap.add_argument("--ref-dir", default="../弟子立绘/reference", help="IP-Adapter 人脸参考图输出目录")
    ap.add_argument("--aptitude", default=None, choices=["elite", "common", "top"],
                    help="仅跑某资质批次")
    ap.add_argument("--id", default=None, help="仅跑指定原型 id（如 huo_bao_top）")
    ap.add_argument("--variants-per-base", type=int, default=DEFAULT_VARIANTS_PER_BASE,
                    help="每个基础原型产出变体张数")
    ap.add_argument("--seed", type=int, default=20260730, help="随机种子（可复现）")
    ap.add_argument("--limit", type=int, default=0, help="调试用：最多跑 N 条")
    ap.add_argument("--force", action="store_true", help="忽略断点续跑，重跑全部")
    ap.add_argument("--crop-avatar", dest="crop_avatar", action="store_true", default=True,
                    help="生成立绘后自动裁切头像（默认开启）")
    ap.add_argument("--no-crop", dest="crop_avatar", action="store_false",
                    help="关闭自动生成头像")
    ap.add_argument("--avatar-sizes", type=int, nargs="+", default=[128, 256, 512],
                    help="输出头像尺寸列表，默认 128 256 512")
    # —— 扩 90 调优与分批基础设施 ——
    ap.add_argument("--ip-weight", type=float, default=IP_ADAPTER_STRENGTH,
                    help="IP-Adapter 人脸一致性权重（首批梯度调优用，默认 0.50）")
    ap.add_argument("--depth-weight", type=float, default=DEPTH_STRENGTH,
                    help="Depth 深度构图锁权重（首批梯度调优用，默认 0.60）")
    ap.add_argument("--batch", type=int, default=0,
                    help="分批量产：指定第 N 批（1-6），每批 --batch-size 张；0=全部")
    ap.add_argument("--batch-size", type=int, default=15,
                    help="每批张数（默认 15，90 张建议分 6 批）")
    ap.add_argument("--sweep", action="store_true", default=False,
                    help="权重梯度扫描：对目标原型跑 Depth×IP 组合网格，用于首批定参")
    ap.add_argument("--sweep-depth", default="0.50,0.60,0.70",
                    help="扫描用 Depth 权重列表（逗号分隔）")
    ap.add_argument("--sweep-ip", default="0.40,0.50,0.60",
                    help="扫描用 IP-Adapter 权重列表（逗号分隔）")
    args = ap.parse_args()

    meta, prompts = load_prompts(args.source)
    negative = meta.get("negative_prompt", DEFAULT_NEGATIVE)

    os.makedirs(args.out, exist_ok=True)
    if args.backend == "dryrun":
        backend = DryRunBackend(args.out)
    elif args.backend == "comfyui":
        backend = ComfyUIBackend(args.url)
    else:
        backend = A1111Backend(args.url)

    done = {} if args.force else load_state(args.out)
    rows = []
    seq_counter = 0

    targets = prompts
    if args.id:
        targets = [p for p in prompts if p["id"] == args.id]
    elif args.aptitude:
        targets = [p for p in prompts if p["aptitude_key"] == args.aptitude]

    # 分批量产：取第 N 批（每批 --batch-size 张）
    if args.batch and args.batch > 0:
        bs = args.batch_size
        start = (args.batch - 1) * bs
        targets = targets[start:start + bs]
        print(f"[BATCH] 第 {args.batch} 批：取第 {start}-{start + len(targets) - 1} 条（共 {len(targets)}）")

    # 权重梯度扫描（首批定参）：每个原型出基准脸 + Depth×IP 组合网格
    if args.sweep:
        _run_sweep(targets, backend, args, negative, rows, done)
        if hasattr(backend, "close"):
            backend.close()
        write_manifest(args.out, rows)
        print(f"[DONE] 扫描 {len(rows)} 条 | 后端={args.backend} | 清单={os.path.join(args.out, 'disciple_asset_manifest.csv')}")
        return

    for entry in targets:
        if args.limit and seq_counter >= args.limit:
            break
        # gender-matched pose + depth（90 包统一 stand）
        cn_img, depth_img = _resolve_controlnet(entry, args.pose_dir, args.depth_dir, POSE_TYPE_90)
        gender = _gender_short(entry.get("gender", "男"))
        cn_strength = CONTROLNET_STRENGTH_FEMALE if gender == "女" else CONTROLNET_STRENGTH
        # 人脸参考：同一弟子第 1 张变体生成后，提取其 256 头像作为 seq>=2 的 IP-Adapter 源
        face_ref = None
        for seq in range(1, args.variants_per_base + 1):
            key = f"{entry['id']}_{seq:02d}"
            if key in done and not args.force:
                continue
            t0 = time.time()
            prompt_cn, chosen = inject_variants(entry, seq, args.seed)
            # IP-Adapter：seq==1 不用（生成基准脸），seq>=2 用已保存的脸参考
            ip_img = face_ref if (face_ref and seq > 1) else None
            ip_strength = args.ip_weight if ip_img else ""
            img = backend.generate(prompt_cn, entry["prompt_en"], negative, cn_img,
                                   args.seed + seq_counter, controlnet_strength=cn_strength,
                                   depth_image=depth_img or None, depth_strength=args.depth_weight,
                                   ip_adapter_image=ip_img, ip_adapter_strength=ip_strength or 0)
            cost = round(time.time() - t0, 2)

            d = archive_dir(args.out, entry)
            fpath = os.path.join(d, asset_filename(entry, seq))
            avatar_paths_str = ""
            crop_meta = {"face_center_x": "", "face_center_y": "", "avatar_crop_x": "",
                         "avatar_crop_y": "", "avatar_size": "", "detect_method": "none"}
            status = "ok" if img is not None else ("dryrun" if args.backend == "dryrun" else "fail")
            qc_crop_l, qc_crop_r, qc_face_l, qc_face_r = ("skip", "dryrun", "skip", "dryrun")
            if img is not None:
                with open(fpath, "wb") as fh:
                    fh.write(img)
                if args.crop_avatar:
                    stem = os.path.splitext(os.path.basename(fpath))[0]
                    avatar_res = _crop_avatars(fpath, os.path.join(d, "avatar"), stem, args.avatar_sizes)
                    if avatar_res:
                        paths, meta = avatar_res
                        avatar_paths_str = "|".join(f"{k}:{v}" for k, v in paths.items())
                        crop_meta = meta
                        # 第 1 张变体：把 256 头像复制到 reference/ 作为该弟子脸参考
                        if seq == 1:
                            os.makedirs(args.ref_dir, exist_ok=True)
                            ref_name = f"disciple_{entry['id']}_face_ref.png"
                            ref_path = os.path.join(args.ref_dir, ref_name)
                            if "256" in paths and os.path.exists(paths["256"]):
                                shutil.copy2(paths["256"], ref_path)
                                face_ref = ref_path
                                print(f"[REF] {ref_name}")
                        # 质检软检测（仅预警，不硬拦截）
                        try:
                            import qc_lib
                            if os.path.exists(fpath):
                                qc_crop_l, qc_crop_r, qc_face_l, qc_face_r = qc_lib.qc_image_path(fpath, crop_meta)
                        except ImportError:
                            print("[WARN] qc_lib 不可用（缺 cv2），跳过质检", file=sys.stderr)
            else:
                # dryrun / 失败也预留统一路径，保持清单结构对齐
                crop_meta = {"face_center_x": "", "face_center_y": "",
                             "avatar_crop_x": "", "avatar_crop_y": "",
                             "avatar_size": "", "detect_method": "none"}

            rows.append({
                "seq_id": key, "asset_id": entry["id"], "file_path": fpath,
                "avatar_paths": avatar_paths_str,
                "element": entry["element"], "personality": entry["personality"],
                "aptitude": entry["aptitude"], "gender": entry["gender"],
                "hair": chosen.get("hair", ""), "face_feature": chosen.get("face_feature", ""),
                "accessory_material": chosen.get("accessory_material", ""),
                "seed": args.seed + seq_counter,
                "pose_ref": cn_img, "depth_ref": depth_img, "depth_strength": args.depth_weight,
                "ip_ref": (ip_img or ""), "ip_strength": (ip_strength or ""),
                "qc_crop": f"{qc_crop_l}:{qc_crop_r}", "qc_face": f"{qc_face_l}:{qc_face_r}",
                "batch": args.batch,
                "face_center_x": crop_meta["face_center_x"],
                "face_center_y": crop_meta["face_center_y"],
                "avatar_crop_x": crop_meta["avatar_crop_x"],
                "avatar_crop_y": crop_meta["avatar_crop_y"],
                "avatar_size": crop_meta["avatar_size"],
                "detect_method": crop_meta["detect_method"],
                "backend": args.backend, "status": status, "time_cost_s": cost,
            })
            done[key] = {"path": fpath, "status": status}
            save_state(args.out, done)
            seq_counter += 1
            if args.limit and seq_counter >= args.limit:
                break

    if hasattr(backend, "close"):
        backend.close()
    write_manifest(args.out, rows)
    print(f"[DONE] 生成 {len(rows)} 条 | 后端={args.backend} | 清单={os.path.join(args.out, 'disciple_asset_manifest.csv')}")


if __name__ == "__main__":
    main()

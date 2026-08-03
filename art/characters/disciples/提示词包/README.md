# 弟子立绘批量出图流水线

## 文件说明

| 文件 | 作用 |
|------|------|
| `build_prompt_package.py` | 单一事实源：从性格/灵根/资质映射生成 `prompts_90.json`（90 条基础原型 + variants 候选池）。 |
| `prompts_90.json` | 机读版 90 条原型，被 `batch_generate.py` 直接读取。 |
| `提示词包_90原型.md` | 人读版提示词包。 |
| `batch_generate.py` | 批量出图脚本骨架：变体注入、ControlNet 姿态绑定、三级目录归档、断点续跑、清单 CSV + 裁切坐标。 |
| `batch_crop.py` | 批量裁切头像脚本：读清单 CSV 或目录，按固定坐标裁切 128/256/512 头像，输出到各立绘目录 `avatar/` 子目录，回写 `avatar_paths` 列。 |

## 快速使用

### 1. 先改映射再重跑提示词包（如需）

编辑 `build_prompt_package.py` 中的人格/灵根/资质常量，然后：

```bash
python build_prompt_package.py
```

会重新生成 `prompts_90.json` 和 `提示词包_90原型.md`。

### 2. 本地 SD 批量出图（生产）

#### ComfyUI

```bash
python batch_generate.py \
  --source prompts_90.json \
  --out ../out \
  --backend comfyui \
  --url http://127.0.0.1:8188 \
  --aptitude elite \
  --variants-per-base 3 \
  --seed 20260730
```

#### AUTOMATIC1111

```bash
python batch_generate.py \
  --source prompts_90.json \
  --out ../out \
  --backend a1111 \
  --url http://127.0.0.1:7860 \
  --aptitude top \
  --variants-per-base 3
```

### 3. 本机验证逻辑（DryRun，不调用 API）

```bash
python batch_generate.py --source prompts_90.json --out ../_dryrun --backend dryrun --aptitude elite --limit 3
```

输出：

- `_dryrun/_dryrun_params.jsonl`：每条最终注入后的提示词、负向词、ControlNet 参数。
- `_dryrun/state.json`：断点续跑状态。
- `_dryrun/disciple_asset_manifest.csv`：资产清单，含文件路径、变体、种子、裁切坐标。
- `_dryrun/灵根/性格/资质/disciple_xxx_01.png`：占位文件（DryRun 不写真实图片）。

### 4. 分批建议

1. 先跑 `--aptitude elite`（30 原型 × 变体张数，出场率最高）。
2. 再跑 `--aptitude common`（量大但规格简单）。
3. 最后跑 `--aptitude top`（稀有高阶，光效复杂，需品质校准）。

每批独立生成 `state.json`，断点续跑互不干扰。

### 5. 自动生成头像（默认开启）

`batch_generate.py` 在保存每张真实立绘后，会自动调用裁切逻辑，输出 `avatar/` 子目录：

```bash
python batch_generate.py \
  --source prompts_90.json \
  --out ../out \
  --backend comfyui \
  --aptitude elite
# 默认产出 128/256/512 三种头像
```

关闭裁切：

```bash
python batch_generate.py ... --no-crop
```

### 6. 仅对已有立绘批量裁切（独立脚本）

```bash
# 清单模式：按 CSV 中的 crop_x/y/w/h 自动裁切，回写 avatar_paths 列
python batch_crop.py --manifest ../out/disciple_asset_manifest.csv

# 目录模式：直接裁切某目录下全部 *.png（样张/临时验证用）
python batch_crop.py --dir ../samples --sizes 128 256 512
```

## 输出结构

```text
out/
├── jin/
│   ├── chen/
│   │   ├── elite/
│   │   │   ├── disciple_jin_chen_elite_01.png
│   │   │   ├── disciple_jin_chen_elite_01_avatar_128.png
│   │   │   ├── disciple_jin_chen_elite_01_avatar_256.png
│   │   │   ├── disciple_jin_chen_elite_01_avatar_512.png
│   │   │   ├── disciple_jin_chen_elite_02.png
│   │   │   └── ...
│   │   ├── avatar/          # 旧版直接裁切目录（兼容 batch_crop --dir）
│   │   └── common/
│   └── gu/
├── mu/
│   ...
├── state.json
└── disciple_asset_manifest.csv   # 新增 avatar_paths 列，记录各尺寸头像绝对/相对路径
```

## ControlNet 姿态参考图

脚本按 `personality_key` 自动匹配 `--pose-dir` 下的 OpenPose 参考图：

| 性格 | 参考图 | 姿态 |
|------|--------|------|
| 沉稳 | `pose_chen.png` | 直立端正、肩线平、不偏头 |
| 活泼 | `pose_huo.png`  | 微前倾、侧头灵动 |
| 孤傲 | `pose_gu.png`   | 侧身、抬颌 |
| 暴躁 | `pose_bao.png`  | 前倾跨步、肩背绷紧 |
| 温润 | `pose_wen.png`  | 微躬、拢袖 |
| 狡黠 | `pose_jiao.png` | 抱臂、歪头 |

首次生产前，请在 `--pose-dir` 中放入这 6 张 OpenPose 骨架图。

## 头像裁切坐标

脚本在清单 CSV 中固定输出：

- `crop_x=384, crop_y=153, crop_w=256, crop_h=256`

对应 `1024×1536` 立绘的标准化半身构图（头顶留白 10%、人物居中）。

多尺寸规则：

| 尺寸 | 源裁切区域 | 输出尺寸 | 用途 |
|------|-----------|---------|------|
| 128 | 256 区域缩放 | 128×128 | 弟子列表小头像 |
| 256 | (384,153,256,256) | 256×256 | 详情页标准头像 |
| 512 | (256,153,512,512) | 512×512 | 高清展示/放大预览 |

所有尺寸共享同一人物中心（x=512 / y≈153），切换尺寸时视觉上无偏移。`batch_crop.py` 默认同时产出 128/256/512。

# UI 核心按钮本地批量出图 RUNBOOK

> 适用：`美术资源/ui_buttons/batch_generate_ui.py` + `prompts_ui_regen.json`
> 目标：本地 ComfyUI / A1111 一次产出 68 个无水印正式 UI 按钮（P0=15 / P1=33 / P2=20）
> 前置：本沙箱无 GPU，以下操作全在你的**带卡本地机器**执行。

---

## 0. 前置环境（本地机器）

1. 启动 ComfyUI 并开放 API 监听（默认 `http://127.0.0.1:8188`）。
   - 若跨机访问：`python main.py --listen 0.0.0.0`（注意防火墙）。
2. 确认你要用的 checkpoint 已放入 ComfyUI `models/checkpoints/`。
   - 写实国漫油画风推荐：麦橘超然 / juggernautXL / 墨幽人造人 等擅长厚涂质感的模型。
3. **透明背景处理**（SD 原生输出 RGB 无 alpha，必须二选一）：
   - 方案 A（推荐，脚本内置）：`pip install rembg`，出图后加 `--rmbg` 自动去背为透明 PNG。
   - 方案 B：ComfyUI 内用 alpha 节点（如 LayerDiffuse / IC-Light），但需你自行改 script 的 SaveImage 为对应输出节点，**本脚本默认走 SaveImage + --rmbg**。

---

## 1. 标准命令

```bash
cd 美术资源/ui_buttons

# 先跑 P0（15 个门面组件）验证风格/尺寸/无水印
python batch_generate_ui.py --priority P0 --backend comfyui \
    --url http://127.0.0.1:8188 \
    --ckpt "你的模型.safetensors" \
    --rmbg

# 确认无误后，全量（P0+P1+P2 = 68 个）
python batch_generate_ui.py --backend comfyui \
    --url http://127.0.0.1:8188 \
    --ckpt "你的模型.safetensors" \
    --rmbg
```

- `--ckpt` 也可在 `prompts_ui_regen.json` 的 `meta.comfyui_ckpt` 字段写死，省去每次传参。
- 断点续跑：`state.json` 记录已完成 id，中断后重跑同命令自动跳过（加 `--force` 全重跑）。
- A1111 用户：`--backend a1111 --url http://127.0.0.1:7860`（API 已内置，无需 rmbg 节点，但同样建议 `--rmbg`）。

---

## 2. 输出结构

```
out_ui/
├─ P0/nav_tab/nav_jy_normal.png        # 命名 = 资产 id
├─ P0/nav_tab/nav_jy_selected.png
├─ P0/main_btn/sq_base_N_normal.png
├─ ... (P1/, P2/ 同理，按 kind 分子目录)
├─ ui_asset_manifest.csv               # 资产清单（尺寸/seed/状态）
└─ state.json                          # 断点续跑
```

- 方形图标 deliver 256×256，长条按钮 deliver 512×128（gen 阶段 1024 出图后降采样，保留细节）。
- 全中文提示词喂 ComfyUI（与现有弟子立绘管线一致）。若你的模型偏英文，把 `compose_prompt` 里喂给 `generate` 的 `prompt_cn` 换成 `prompt_en` 即可。

---

## 3. 替换进 Godot 工程

归档文件名 == `png/` 内现有 45 张的 id（如 `nav_jy_normal.png`）。按同名覆盖即可，Godot 自动刷新引用：

```bash
# 在 美术资源/ui_buttons/ 下执行（PowerShell）
Get-ChildItem out_ui -Recurse -Filter *.png | ForEach-Object {
    Copy-Item $_.FullName -Destination "png/$($_.Name)" -Force
}
```

> ⚠️ 替换前先 `git stash` 或备份 `png/`，replace 是同名覆盖，旧修复版会被冲掉。

---

## 4. 应急：带水印通道才开 `--watermark-clean`

本地 SD 输出**天然无水印**，无需此开关。仅当你改用会盖水印的通道（如平台 ImageGen）时，加 `--watermark-clean` 跑 `remove_watermark.py` 兜底。默认关。

---

## 5. 验收红线（门面级 P0 必查）

- [ ] 右下角无 "AI生成 WORKBUDDY" 水印（本地 SD 不应有）
- [ ] 透明背景：用 `--rmbg` 后，非按钮主体区域 alpha≈0（Godot 拼图集前留 1–2px 透明边距防采样色差）
- [ ] 暗金描边粗细、墨青底板色值（#1E2B28 / #C8A86A）与现有 45 张视觉连续
- [ ] 无任何文字/字母/数字（负向词已锁）

---

## 6. 常见失败排查

| 现象 | 原因 | 处理 |
|---|---|---|
| `[WARN] ComfyUI 未返回 prompt_id` | 端点不可达 / JSON 非法 | 确认 `--url` 正确、`--ckpt` 文件名存在 |
| 轮询超时 15min | 显存不足 / 步数过高 | 降低 `--steps` 或 batch；看 ComfyUI 终端日志 |
| 图全黑/透明异常 | checkpoint 与 CLIP/VAE 不匹配 | 换用同源 VAE，或确认模型为 SD1.5/SDXL |
| 去背后主体被抠掉 | rembg 模型误判 | 改用 ComfyUI 内 alpha 节点，或调 rembg 参数 |

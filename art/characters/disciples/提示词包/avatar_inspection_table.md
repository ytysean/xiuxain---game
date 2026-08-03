# 太玄宗门录 · 弟子头像人工抽检表

> 用途：人脸检测动态裁切后，对 `*_avatar_256.png` 做人工复核；
> 重点抓「检测器误判 / 构图锁失效 / 配饰遮挡」三类异常。

## 一、必检项（每张头像 4 项）

| 序号 | 检查项 | 合格标准 | 不合格表现 |
|------|--------|----------|------------|
| 1 | 头部完整 | 额头、发髻/冠饰顶部、双耳上沿完整保留 | 头顶被切、额头缺一块、发髻/冠顶不见 |
| 2 | 面部居中 | 鼻尖位于头像水平中心 ±8% 以内，双眼完整可见 | 脸偏到一侧、只露半张脸、鼻尖明显偏离中线 |
| 3 | 耳朵未被裁切 | 双耳或至少一侧耳朵完整露出 | 耳廓被切掉、耳朵只剩一半 |
| 4 | 冠饰/发髻保留 | 头冠、发簪、发带等头部装饰完整露出且不遮挡眉眼 | 冠饰被切、发簪只剩半截、刘海/冠檐遮住眼睛 |

附加项（抽查 20%）：

| 序号 | 检查项 | 合格标准 | 不合格表现 |
|------|--------|----------|------------|
| 5 | 表情清晰 | 眉眼、嘴角神态可辨，无模糊/重影 | 表情糊成一团、嘴部被切、眼神无神 |
| 6 | 光线一致 | 面部主光源方向与立绘一致，无过曝/死黑 | 脸部大面积过曝或死黑 |
| 7 | 肩颈自然 | 头像底部可见适量肩颈过渡，不突兀截断 | 下巴刚切完就截断、肩膀只剩一半 |

## 二、抽检比例

- **首批评量（≤30 张）**：100% 全检。
- **稳定量产后（每批次 ≤100 张）**：至少 30% 抽检，其中 `detect_method != dnn_ssd` 的全部强制人工复核。
- **新加性格 / 新加灵根色 / 提示词调整后**：该组 100% 全检。

## 三、记录表模板

复制以下行，每批填一张 CSV（示例：`avatar/inspection_batch_YYYYMMDD.csv`）：

```csv
file,head_intact,face_centered,ears_ok,crown_kept,expression_clear,pass,notes
修仙女弟子_xxx_avatar_256.png,Y,Y,Y,Y,Y,Y,
诛仙男弟子_xxx_avatar_256.png,Y,Y,Y,N,Y,N,冠饰右侧被切
```

字段说明：

- `file`：头像文件名。
- `head_intact` / `face_centered` / `ears_ok` / `crown_kept` / `expression_clear`：Y/N。
- `pass`：全部 Y 则 Y；任一项 N 则 N。
- `notes`：失败时写明原因（如「头顶被切 5%」「面部偏右」）。

## 四、异常处理流程

| 异常类型 | 处理方式 |
|----------|----------|
| 单张 dnn_ssd 检测框偏小/偏大导致裁切异常 | 在该行的 manifest 里将 `detect_method` 改为 `manual_adjust`，手动填写 `avatar_crop_x/y/size` 后重跑 `batch_crop.py --manifest` |
| 连续多张同一 pose 检测失败 | 检查 OpenPose 参考图是否头部位移过大；回到 `build_prompt_package.py` 加强构图锁提示词 |
| 冠饰/发髻频繁被切 | 优先加大 `crop_lib.compute_avatar_crop` 的 `pad_top`（如 0.30 → 0.40）；仍不行则返回生成端加「冠饰不遮眉眼」约束 |
| 表情模糊/面部过曝 | 不属裁切问题，生成端调整光照/采样步数；该样本降级为不合格 |

## 五、与资产清单的联动

资产清单 `disciple_asset_manifest.csv` 新字段含义（动态裁切后）：

```csv
face_center_x,face_center_y,avatar_crop_x,avatar_crop_y,avatar_size,detect_method
```

- `face_center_x/y`：DNN 检测到的人脸中心（源图坐标）。
- `avatar_crop_x/y/size`：实际裁切框左上角与边长（源图坐标）。
- `detect_method`：
  - `dnn_ssd`：检测成功。
  - `fallback_upper_center`：检测失败，用上中兜底坐标 —— **必须人工复核**。
  - `manual_adjust`：人工修正 —— **以该值为准**。

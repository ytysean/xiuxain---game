# 工作概览：让 AI 能“看见” Godot 界面

## 做了什么
- 解决了沙箱无法运行 Godot、无法实时看编辑器渲染的瓶颈。
- 上线 `tools/preview_tscn.py`：用 Python/PIL 解析 `.tscn` 场景文件，按节点的绝对定位 offset、颜色矩形、面板、图标、文字近似渲染成 480×854 PNG。
- 跑通 `ui/home_page.tscn` 预览，关键节点坐标与《宗门首页线框规范》一致。

## 关键结论
- 当前 `ui/home_page.tscn` 文件本身的坐标和布局是**正确的**；之前截图显示「挤在左上角 / 底部 Tab 不见」是因为 Godot 缓存了旧版 `layout_mode=1` 锚点模式。
- 用户端需要**完整重启 Godot**（不是只保存或重开场景），再打开 `ui/home_page.tscn`，即可看到正确首页。

## 后续工作流
1. 我改 `.tscn` 后，先跑 `preview_tscn.py` 自查坐标/溢出/重叠。
2. 把预览图/结论发给你，你在 Godot 里做最终真机验收（只需看审美和细节）。
3. 后续其他界面也按此流程批量生成 `.tscn` + 预览器验收，大幅减少来回截图。

## 文件
- `tools/preview_tscn.py` —— 离线场景预览器
- `art/_preview/home_page_preview.png` —— 当前首页近似渲染图
- `ui/home_page.tscn` —— 完整首页布局场景（待 Godot 重启验收）

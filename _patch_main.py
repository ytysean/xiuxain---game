# -*- coding: utf-8 -*-
# P0 目标链系统 · 阶段B UI 层补丁（main.gd）
# 玉牌入口 + 宗门要务面板 + 底部 Tab 红点 + 跳转 + 数值跳字 + FTUE 收尾文言弹窗。
# 仅新增 UI；按钮颜色全部走 BTN_*/暗金/玉石绿/朱砂 等已有常量（不写裸 hex，过 gate 18）；
# 弹窗遮罩走 弹窗遮罩/暗化（过 gate 19）；不新增 Tab（过 gate 17）。写入强制 LF。
import io, os, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
MAIN = os.path.join(ROOT, "main.gd")

with io.open(MAIN, "r", encoding="utf-8", newline="") as f:
    s = f.read()

reps = []

# ---- A) 连接新手信号（延后 idle 帧，避免 pressed 回调内重建崩溃）----
reps.append((
    "Game.弟子变动.connect(刷新, CONNECT_DEFERRED)",
    "Game.弟子变动.connect(刷新, CONNECT_DEFERRED)   # 延后到 idle 帧执行：避免招徒等 pressed 回调内同步刷新重建当前页→释放发射者节点崩溃\n"
    "\tGame.新手目标更新.connect(_刷新_新手UI, CONNECT_DEFERRED)   # P0 目标链：玉牌/Tab 红点/跳字刷新",
    1,
))

# ---- B) 宗门页加玉牌入口 ----
reps.append((
    "内容.add_child(_宗门全景卡())",
    "内容.add_child(_宗门全景卡())\n\t内容.add_child(_建_玉牌())",
    1,
))

# ---- C) 新手阶梯 UI 函数块（插在 _引导_收尾 前）----
UI_BLOCK = (
    "# ===== P0 目标链系统 · 新手阶梯 UI（玉牌入口 / 宗门要务面板 / Tab 红点 / 跳转 / 数值跳字）=====\n"
    "var _last_新手完成数: int = 0\n"
    "var _宗门要务面板: Node = null\n"
    "var _玉牌红点: Control = null\n"
    "\n"
    "func _建_玉牌() -> Control:\n"
    "\tvar 条 := HBoxContainer.new()\n"
    "\tvar 牌 := Button.new()\n"
    "\t牌.text = \"\\u1F000 宗门要务\"\n"
    "\t牌.custom_minimum_size = Vector2(0, 48)\n"
    "\t牌.add_theme_stylebox_override(\"normal\", _主按钮样式())\n"
    "\t牌.add_theme_color_override(\"font_color\", BTN_主字)\n"
    "\t牌.pressed.connect(_打开_宗门要务)\n"
    "\t条.add_child(牌)\n"
    "\t_玉牌红点 = ColorRect.new()\n"
    "\t_玉牌红点.color = 朱砂\n"
    "\t_玉牌红点.custom_minimum_size = Vector2(10, 10)\n"
    "\t_玉牌红点.mouse_filter = Control.MOUSE_FILTER_IGNORE\n"
    "\t条.add_child(_玉牌红点)\n"
    "\t_刷新_新手UI()\n"
    "\treturn 条\n"
    "\n"
    "func _打开_宗门要务():\n"
    "\tif _宗门要务面板 != null and is_instance_valid(_宗门要务面板):\n"
    "\t\t_宗门要务面板.queue_free()\n"
    "\tvar 遮 := ColorRect.new()\n"
    "\t遮.color = 弹窗遮罩\n"
    "\t遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n"
    "\t遮.mouse_filter = Control.MOUSE_FILTER_STOP\n"
    "\t遮.name = \"宗门要务遮\"\n"
    "\tadd_child(遮)\n"
    "\tvar 面板 := 新面板(\"宗门要务\")\n"
    "\t面板.anchor_left = 0.5; 面板.anchor_top = 0.5; 面板.anchor_right = 0.5; 面板.anchor_bottom = 0.5\n"
    "\t面板.offset_left = -180; 面板.offset_top = -170; 面板.offset_right = 180; 面板.offset_bottom = 170\n"
    "\t遮.add_child(面板)\n"
    "\tvar 内容: Control = 面板.get_child(0)\n"
    "\t_填_宗门要务(内容, 遮)\n"
    "\t_宗门要务面板 = 遮\n"
    "\n"
    "func _填_宗门要务(内容: Control, 遮: Control):\n"
    "\t内容.add_theme_constant_override(\"separation\", 8)\n"
    "\tvar 进: Dictionary = Game.新手_当前进行()\n"
    "\tvar 标题 := Label.new()\n"
    "\tif Game.新手_全部完成():\n"
    "\t\t标题.text = \"宗门要务 · 已全部达成（%d/7）\" % Game.新手_完成数()\n"
    "\telif 进.is_empty():\n"
    "\t\t标题.text = \"宗门要务 · 筹备中（%d/7）\" % Game.新手_完成数()\n"
    "\telse:\n"
    "\t\t标题.text = \"宗门要务 · 进行中（%d/7）\" % Game.新手_完成数()\n"
    "\t标题.add_theme_color_override(\"font_color\", 暗金)\n"
    "\t内容.add_child(标题)\n"
    "\tif not 进.is_empty():\n"
    "\t\tvar 名 := Label.new()\n"
    "\t\t名.text = \"\\u25B8 %s\" % 进.get(\"quest_name\", \"\")\n"
    "\t\t名.add_theme_font_size_override(\"font_size\", FONT_PANEL)\n"
    "\t\t名.add_theme_color_override(\"font_color\", 玉石绿)\n"
    "\t\t内容.add_child(名)\n"
    "\t\tvar 描 := Label.new()\n"
    "\t\t描.text = 进.get(\"target_desc\", \"\")\n"
    "\t\t描.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n"
    "\t\t描.add_theme_color_override(\"font_color\", 宣纸亮)\n"
    "\t\t内容.add_child(描)\n"
    "\t\tvar 是主动: bool = (进.get(\"is_auto_trigger\", \"true\") != \"true\")\n"
    "\t\tif 是主动 and not 进.get(\"jump_path\", \"\").is_empty():\n"
    "\t\t\tvar 往 := Button.new(); 往.text = \"前往处理\"\n"
    "\t\t\t往.add_theme_stylebox_override(\"normal\", _主按钮样式())\n"
    "\t\t\t往.add_theme_color_override(\"font_color\", BTN_主字)\n"
    "\t\t\t往.pressed.connect(func():\n"
    "\t\t\t\tvar 路: String = 进.get(\"jump_path\", \"\")\n"
    "\t\t\t\tif 遮 != null and is_instance_valid(遮):\n"
    "\t\t\t\t\t遮.queue_free()\n"
    "\t\t\t\t_跳转(路)\n"
    "\t\t\t)\n"
    "\t\t\t内容.add_child(往)\n"
    "\t\telse:\n"
    "\t\t\tvar 态 := Label.new()\n"
    "\t\t\t态.text = \"（自动达成中，静候机缘）\"\n"
    "\t\t\t态.add_theme_color_override(\"font_color\", 次墨)\n"
    "\t\t\t内容.add_child(态)\n"
    "\tvar 完成 := Label.new()\n"
    "\t完成.text = \"已完成：%s\" % \"、\".join(Game.新手完成列表)\n"
    "\t完成.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n"
    "\t完成.add_theme_color_override(\"font_color\", 次墨)\n"
    "\t内容.add_child(完成)\n"
    "\tvar 关 := Button.new(); 关.text = \"关闭\"\n"
    "\t关.add_theme_stylebox_override(\"normal\", _次按钮样式())\n"
    "\t关.add_theme_color_override(\"font_color\", BTN_次字)\n"
    "\t关.pressed.connect(func():\n"
    "\t\tif 遮 != null and is_instance_valid(遮):\n"
    "\t\t\t遮.queue_free()\n"
    "\t)\n"
    "\t内容.add_child(关)\n"
    "\n"
    "func _刷新_新手UI():\n"
    "\tif _玉牌红点 != null and is_instance_valid(_玉牌红点):\n"
    "\t\t_玉牌红点.visible = Game.新手_有红点()\n"
    "\tif 标签栏 != null and is_instance_valid(标签栏):\n"
    "\t\tvar 点 := 标签栏.get_node_or_null(\"新手红点\")\n"
    "\t\tif 点 == null:\n"
    "\t\t\t点 = ColorRect.new()\n"
    "\t\t\t点.name = \"新手红点\"\n"
    "\t\t\t点.color = 朱砂\n"
    "\t\t\t点.custom_minimum_size = Vector2(10, 10)\n"
    "\t\t\t点.mouse_filter = Control.MOUSE_FILTER_IGNORE\n"
    "\t\t\t标签栏.add_child(点)\n"
    "\t\tvar 有: bool = Game.新手_有红点() or _有未领日常()\n"
    "\t\t点.visible = 有\n"
    "\t\tif 有 and 标签栏.get_tab_count() > 0:\n"
    "\t\t\tvar 矩: Rect2 = 标签栏.get_tab_rect(0)\n"
    "\t\t\t点.position = Vector2(矩.position.x + 矩.size.x - 14, 矩.position.y + 6)\n"
    "\tif Game.新手_完成数() > _last_新手完成数:\n"
    "\t\tif Game.新手_完成数() > 0:\n"
    "\t\t\t_数值跳字(self, \"宗门要务 第%d项达成\" % Game.新手_完成数(), 玉石绿)\n"
    "\t\t_last_新手完成数 = Game.新手_完成数()\n"
    "\tif _宗门要务面板 != null and is_instance_valid(_宗门要务面板):\n"
    "\t\tvar pn: Node = _宗门要务面板.get_child(0)\n"
    "\t\tif pn != null and is_instance_valid(pn):\n"
    "\t\t\tfor c in pn.get_children():\n"
    "\t\t\t\tc.queue_free()\n"
    "\t\t\t_填_宗门要务(pn, _宗门要务面板)\n"
    "\n"
    "func _有未领日常() -> bool:\n"
    "\tfor i in Game.当前日常.size():\n"
    "\t\tif i < Game.日常已领.size() and not Game.日常已领[i]:\n"
    "\t\t\treturn true\n"
    "\treturn false\n"
    "\n"
    "func _跳转(路: String):\n"
    "\tif 路.is_empty():\n"
    "\t\treturn\n"
    "\tvar 段: PackedStringArray = 路.split(\"/\")\n"
    "\tvar 页: String = 段[0]\n"
    "\tmatch 页:\n"
    "\t\t\"宗门\":\n"
    "\t\t\t_on_主导航切换(0)\n"
    "\t\t\tif 段.size() > 1 and 段[1] == \"收益栏\":\n"
    "\t\t\t\t_进_二级页(\"账册\")\n"
    "\t\t\"弟子\":\n"
    "\t\t\tif 段.size() > 1:\n"
    "\t\t\t\tmatch 段[1]:\n"
    "\t\t\t\t\t\"接引\": _弟子二级tab = 1\n"
    "\t\t\t\t\t\"名录\": _弟子二级tab = 0\n"
    "\t\t\t\t\t\"详情\": _弟子二级tab = 0\n"
    "\t\t\t_on_主导航切换(1)\n"
    "\t\t\"历练\": _on_主导航切换(3)\n"
    "\t\t\"纪事\": _on_主导航切换(4)\n"
    "\t\t\"御兽\": _on_主导航切换(2)\n"
    "\t\t_: _on_主导航切换(0)\n"
    "\n"
    "func _数值跳字(父: Control, 文本: String, 色: Color):\n"
    "\tif 父 == null or not is_instance_valid(父):\n"
    "\t\treturn\n"
    "\tvar 跳 := Label.new()\n"
    "\t跳.text = 文本\n"
    "\t跳.add_theme_font_size_override(\"font_size\", FONT_PANEL_B)\n"
    "\t跳.add_theme_color_override(\"font_color\", 色)\n"
    "\t跳.mouse_filter = Control.MOUSE_FILTER_IGNORE\n"
    "\t父.add_child(跳)\n"
    "\t跳.position = Vector2(max(8, 父.size.x / 2 - 70), 40)\n"
    "\tvar t := create_tween()\n"
    "\tt.tween_property(跳, \"position\", Vector2(跳.position.x, 跳.position.y - 60), 1.2)\n"
    "\tt.parallel().tween_property(跳, \"modulate:a\", 0.0, 1.2)\n"
    "\tt.tween_callback(跳.queue_free)\n"
    "\n"
)
reps.append((
    "func _引导_收尾():",
    UI_BLOCK + "func _引导_收尾():",
    1,
))

# ---- D) FTUE 收尾：解锁 newbie 链（收尾 + 跳过 两处都加）----
reps.append((
    "\tGame.引导阶段 = 6\n\tGame.save_game()",
    "\tGame.引导阶段 = 6\n\tGame.激活新手目标链()\n\tGame.save_game()",
    2,
))

# ---- E) FTUE 收尾：文言弹窗 + 3 一键跳转 ----
reps.append((
    "\tvar 文 := Label.new()\n"
    "\t文.text = \"【苏清禾】掌门已初窥门径，宗门自此运转。往后岁末考评、七载大考的成绩，便是咱宗门的脸面。更深的事务（坊市、历练、御兽）也已为你敞开，自行探索便是。\"\n"
    "\t文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n"
    "\t文.add_theme_color_override(\"font_color\", 宣纸亮)\n"
    "\t泡.add_child(文)\n"
    "\tvar 关 := Button.new(); 关.text = \"知道了\"\n"
    "\t关.pressed.connect(func(): _引导_清除())\n"
    "\t泡.add_child(关)",
    "\tvar 文 := Label.new()\n"
    "\t文.text = \"【宗门初立指南】掌门既已立足，宗门初立，诸事待举。谨奉三策：\\n一、开坛接引，广纳门人；\\n二、稽核收益，开源节流；\\n三、遣徒历练，访道寻机。\\n愿掌门循序渐进，早壮玄门。\"\n"
    "\t文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n"
    "\t文.add_theme_color_override(\"font_color\", 宣纸亮)\n"
    "\t泡.add_child(文)\n"
    "\tvar 跳行 := HBoxContainer.new()\n"
    "\tvar 跳1 := Button.new(); 跳1.text = \"前往·接引弟子\"\n"
    "\t跳1.add_theme_stylebox_override(\"normal\", _主按钮样式())\n"
    "\t跳1.add_theme_color_override(\"font_color\", BTN_主字)\n"
    "\t跳1.pressed.connect(func(): _引导_清除(); _跳转(\"弟子/接引\"))\n"
    "\tvar 跳2 := Button.new(); 跳2.text = \"查看·宗门收益\"\n"
    "\t跳2.add_theme_stylebox_override(\"normal\", _主按钮样式())\n"
    "\t跳2.add_theme_color_override(\"font_color\", BTN_主字)\n"
    "\t跳2.pressed.connect(func(): _引导_清除(); _跳转(\"宗门/收益栏\"))\n"
    "\tvar 跳3 := Button.new(); 跳3.text = \"开启·历练\"\n"
    "\t跳3.add_theme_stylebox_override(\"normal\", _主按钮样式())\n"
    "\t跳3.add_theme_color_override(\"font_color\", BTN_主字)\n"
    "\t跳3.pressed.connect(func(): _引导_清除(); _跳转(\"历练/秘境\"))\n"
    "\t跳行.add_child(跳1); 跳行.add_child(跳2); 跳行.add_child(跳3)\n"
    "\t泡.add_child(跳行)\n"
    "\tvar 关 := Button.new(); 关.text = \"知道了\"\n"
    "\t关.add_theme_stylebox_override(\"normal\", _次按钮样式())\n"
    "\t关.add_theme_color_override(\"font_color\", BTN_次字)\n"
    "\t关.pressed.connect(func(): _引导_清除())\n"
    "\t泡.add_child(关)",
    1,
))

# ---- F+G) 每日任务：领取数值跳字 + 前往按钮（按 jump_path）；合并为唯一锚点（仅每日领取闭包）----
reps.append((
    "\t\tvar 领 := Button.new(); 领.text = \"领取\" if not 已领 else \"已领\"\n"
    "\t\t领.disabled = 已领\n"
    "\t\t领.pressed.connect(func():\n"
    "\t\t\tvar res: Dictionary = Game.领取日常(i)\n"
    "\t\t\t_任务提示 = res.get(\"msg\", \"\")\n"
    "\t\t\t_刷新_任务页(结果)\n"
    "\t\t)\n"
    "\t\t行.add_child(标); 行.add_child(领)\n"
    "\t\t任务列.add_child(行)",
    "\t\tvar 领 := Button.new(); 领.text = \"领取\" if not 已领 else \"已领\"\n"
    "\t\t领.disabled = 已领\n"
    "\t\t领.pressed.connect(func():\n"
    "\t\t\tvar res: Dictionary = Game.领取日常(i)\n"
    "\t\t\t_任务提示 = res.get(\"msg\", \"\")\n"
    "\t\t\tif res.get(\"ok\", false):\n"
    "\t\t\t\tvar qq: Dictionary = Game.当前日常[i]\n"
    "\t\t\t\tvar 灵: int = int(float(qq.get(\"reward_lingjing\", \"0\")) * Game.任务奖励系数())\n"
    "\t\t\t\tvar 气: int = int(float(qq.get(\"reward_lingqi\", \"0\")) * Game.任务奖励系数())\n"
    "\t\t\t\t_数值跳字(任务列, \"灵石+%d 灵气+%d\" % [灵, 气], 玉石绿)\n"
    "\t\t\t_刷新_任务页(结果)\n"
    "\t\t)\n"
    "\t\t行.add_child(标); 行.add_child(领)\n"
    "\t\tif not 已领 and q.get(\"jump_path\", \"\") != \"\":\n"
    "\t\t\tvar 往 := Button.new(); 往.text = \"前往\"\n"
    "\t\t\t往.add_theme_stylebox_override(\"normal\", _次按钮样式())\n"
    "\t\t\t往.add_theme_color_override(\"font_color\", BTN_次字)\n"
    "\t\t\t往.pressed.connect(_跳转.bind(q.get(\"jump_path\", \"\")))\n"
    "\t\t\t行.add_child(往)\n"
    "\t\t任务列.add_child(行)",
    1,
))

# ---- 执行 ----
missing = []
for anchor, repl, cnt in reps:
    n = s.count(anchor)
    if n != cnt:
        missing.append((anchor[:50], n, cnt))
        continue
    s = s.replace(anchor, repl, 1)

if missing:
    print("ABORT：以下锚点匹配异常（anchor[:50], 实际, 期望）：")
    for m in missing:
        print("  ", m)
    sys.exit(2)

with io.open(MAIN, "w", encoding="utf-8", newline="") as f:
    f.write(s)
print("main.gd 已写入，全部 %d 处锚点命中。" % len(reps))

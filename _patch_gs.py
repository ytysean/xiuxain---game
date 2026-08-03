# -*- coding: utf-8 -*-
# P0 目标链系统 · 阶段A 数据层补丁（game_state.gd）
# 仅新增：状态/信号/函数 + 5 处业务钩子调用 + save/load/reset 兼容字段；不改动既有字段/键/存档结构。
# 写入强制 LF（newline=''）。锚点尽量取行中段唯一子串，规避前导 tab 计数误差。
import io, os, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
GS = os.path.join(ROOT, "game_state.gd")

with io.open(GS, "r", encoding="utf-8", newline="") as f:
    s = f.read()

reps = []  # (anchor, replacement, count_expected)

# ---- 1) 状态变量 + 信号 ----
reps.append((
    "# quest_type -> 上次触发累计游戏日（同类型1月冷却）",
    "# quest_type -> 上次触发累计游戏日（同类型1月冷却）\n\n"
    "# ===== P0 目标链系统 · 新手阶梯状态（2026-07-25 新增；不升 SAVE_VERSION，load 用 .get 默认兼容老档）=====\n"
    "var 新手目标链激活: bool = false          # FTUE 收尾后解锁（激活 newbie_001）\n"
    "var 新手完成列表: Array = []              # 已完成 newbie quest_id 列表（靠 prev_quest_id 推导解锁链）\n"
    "signal 新手目标更新()                      # UI 玉牌红点 / 宗门要务面板刷新\n",
    1,
))

# ---- 2) 新手阶梯函数块（插在 S0 随机事件 前）----
NB_BLOCK = (
    "# ============ P0 目标链系统 · 新手阶梯（混合主动/自动，上一条完成才解锁下一条）============\n"
    "# 配置来源：quest_daily.csv 中 is_newbie==true 的 7 行（newbie_001..007）\n"
    "# 事件型条件（recruit_count / realm_first_enter / collect_income / event_first_trigger）由 5 处业务钩子\n"
    "#   调用 _新手_检测(条件) 触发完成；状态型条件（recruit_count_5 / disciple_realm_3 / disciple_realm_5）\n"
    "#   由 _新手_评估后续() 依据当前状态预判，避免“死目标”。\n"
    "func 激活新手目标链():\n"
    "\tif 新手目标链激活:\n"
    "\t\treturn\n"
    "\t新手目标链激活 = true\n"
    "\t_新手_评估后续()   # 解锁 newbie_001 并预检状态型条件是否已满足\n"
    "\n"
    "func _新手_配置() -> Array:\n"
    "\tvar 链: Array = []\n"
    "\tfor r in DestinyDataLoader._read_csv(\"res://config/quest_daily.csv\"):\n"
    "\t\tif r.get(\"is_newbie\", \"\") == \"true\":\n"
    "\t\t\t链.append(r)\n"
    "\treturn 链\n"
    "\n"
    "func _新手_已解锁(q: Dictionary) -> bool:\n"
    "\tvar prev: String = q.get(\"prev_quest_id\", \"\")\n"
    "\tif prev == \"\" or prev == null:\n"
    "\t\treturn true\n"
    "\treturn 新手完成列表.has(prev)\n"
    "\n"
    "func 新手_当前进行() -> Dictionary:\n"
    "\t# 首个未完成且已解锁的 newbie（供 UI 展示）；未激活/全完成返回 {}\n"
    "\tif not 新手目标链激活:\n"
    "\t\treturn {}\n"
    "\tfor q in _新手_配置():\n"
    "\t\tif 新手完成列表.has(q.get(\"quest_id\", \"\")):\n"
    "\t\t\tcontinue\n"
    "\t\tif _新手_已解锁(q):\n"
    "\t\t\treturn q\n"
    "\treturn {}\n"
    "\n"
    "func 新手_完成数() -> int:\n"
    "\treturn 新手完成列表.size()\n"
    "\n"
    "func 新手_全部完成() -> bool:\n"
    "\tif not 新手目标链激活:\n"
    "\t\treturn false\n"
    "\treturn 新手完成列表.size() >= _新手_配置().size()\n"
    "\n"
    "func 新手_有红点() -> bool:\n"
    "\tif not 新手目标链激活 or 新手_全部完成():\n"
    "\t\treturn false\n"
    "\treturn not 新手_当前进行().is_empty()\n"
    "\n"
    "func _新手_检测(条件: String):\n"
    "\t# 事件型钩子入口：满足 条件 且已解锁&未完成的 newbie 立即完成（钩子本身即证据）\n"
    "\tif not 新手目标链激活:\n"
    "\t\treturn\n"
    "\tfor q in _新手_配置():\n"
    "\t\tvar qid: String = q.get(\"quest_id\", \"\")\n"
    "\t\tif 新手完成列表.has(qid):\n"
    "\t\t\tcontinue\n"
    "\t\tif not _新手_已解锁(q):\n"
    "\t\t\tcontinue\n"
    "\t\tif q.get(\"condition_type\", \"\") != 条件:\n"
    "\t\t\tcontinue\n"
    "\t\t_新手_完成(q)\n"
    "\t\treturn\n"
    "\n"
    "func _新手_评估后续():\n"
    "\t# 状态型条件预检 + 链推进（解锁后/每次完成后调用；可连续解锁多条）\n"
    "\tif not 新手目标链激活:\n"
    "\t\treturn\n"
    "\tfor q in _新手_配置():\n"
    "\t\tvar qid: String = q.get(\"quest_id\", \"\")\n"
    "\t\tif 新手完成列表.has(qid):\n"
    "\t\t\tcontinue\n"
    "\t\tif not _新手_已解锁(q):\n"
    "\t\t\tcontinue\n"
    "\t\tif _新手_条件满足(q):\n"
    "\t\t\t_新手_完成(q)\n"
    "\t\t\treturn\n"
    "\n"
    "func _新手_条件满足(q: Dictionary) -> bool:\n"
    "\tvar 条件: String = q.get(\"condition_type\", \"\")\n"
    "\tmatch 条件:\n"
    "\t\t\"recruit_count_5\":\n"
    "\t\t\treturn 弟子列表.size() >= 5\n"
    "\t\t\"disciple_realm_3\":\n"
    "\t\t\tfor d in 弟子列表:\n"
    "\t\t\t\tif d.境界 == \"练气\" and d.层数 >= 3:\n"
    "\t\t\t\t\treturn true\n"
    "\t\t\treturn false\n"
    "\t\t\"disciple_realm_5\":\n"
    "\t\t\tfor d in 弟子列表:\n"
    "\t\t\t\tif d.境界 == \"练气\" and d.层数 >= 5:\n"
    "\t\t\t\t\treturn true\n"
    "\t\t\treturn false\n"
    "\treturn false   # 事件型条件不在状态预检中自动满足，交由对应钩子触发\n"
    "\n"
    "func _新手_完成(q: Dictionary):\n"
    "\tvar qid: String = q.get(\"quest_id\", \"\")\n"
    "\tif 新手完成列表.has(qid):\n"
    "\t\treturn\n"
    "\t新手完成列表.append(qid)\n"
    "\tvar 灵: int = int(float(q.get(\"reward_lingjing\", \"0\")) * 差事赏赐系数())\n"
    "\tvar 气: int = int(float(q.get(\"reward_lingqi\", \"0\")) * 差事赏赐系数())\n"
    "\t灵石 += 灵\n"
    "\t灵气 += 气\n"
    "\t_新手_抽池(q.get(\"reward_pool_id\", \"\"))\n"
    "\t宗门纪事.append({\"日\": 累计游戏日, \"稀有度\": \"琐事\", \"名称\": \"新手目标\",\n"
    "\t\t\"文案\": \"【新手目标】%s 达成，获灵石+%d 灵气+%d。\" % [q.get(\"quest_name\", \"\"), 灵, 气]})\n"
    "\t新手目标更新.emit()\n"
    "\t_新手_评估后续()   # 推进链（可能连续解锁多条状态型）\n"
    "\n"
    "func _新手_抽池(pool_id: String):\n"
    "\t# P0 范围：仅结算可量化部分（灵石/气运）；材料/丹药按 +灵石 折算，\n"
    "\t# 避免向 宗门库房（Item 实例数组）写入非 Item 字典，破坏 save/load。\n"
    "\tif pool_id == \"\" or pool_id == null:\n"
    "\t\treturn\n"
    "\tvar 行: Array = []\n"
    "\tfor r in DestinyDataLoader._read_csv(\"res://config/quest_reward_pool.csv\"):\n"
    "\t\tif r.get(\"pool_id\", \"\") == pool_id:\n"
    "\t\t\t行.append(r)\n"
    "\tif 行.is_empty():\n"
    "\t\treturn\n"
    "\tvar 总: float = 0.0\n"
    "\tfor r in 行:\n"
    "\t\t总 += float(r.get(\"weight\", \"0\"))\n"
    "\tif 总 <= 0:\n"
    "\t\treturn\n"
    "\tvar 抽: float = randf() * 总\n"
    "\tvar 中: Dictionary = 行[0]\n"
    "\tfor r in 行:\n"
    "\t\t抽 -= float(r.get(\"weight\", \"0\"))\n"
    "\t\tif 抽 <= 0:\n"
    "\t\t\t中 = r\n"
    "\t\t\tbreak\n"
    "\tvar 名: String = 中.get(\"item_name\", \"\")\n"
    "\tif \"气运\" in 名:\n"
    "\t\t玄玉 += 1\n"
    "\telse:\n"
    "\t\t灵石 += 20\n"
    "\n"
)
reps.append((
    "# ============ S0 随机事件（轻量挂载：月度推演概率触发）============\n",
    NB_BLOCK + "# ============ S0 随机事件（轻量挂载：月度推演概率触发）============\n",
    1,
))

# ---- 3) 刷新日常差事：排除 newbie 行（插在 池.append(r) 与 池.shuffle() 之间）----
reps.append((
    "池.append(r)\n\t池.shuffle()",
    "池.append(r)\n\t\tif r.get(\"is_newbie\", \"\") == \"true\":\n\t\t\tcontinue\n\t池.shuffle()",
    1,
))

# ---- 4) 领取日常钩子：collect_income ----
reps.append((
    "日常已领[序号] = true\n\treturn {\"ok\": true",
    "日常已领[序号] = true\n\t_新手_检测(\"collect_income\")\n\treturn {\"ok\": true",
    1,
))

# ---- 5) 已通关秘境钩子：realm_first_enter ----
reps.append((
    "已通关秘境[stage_id] = true\n",
    "已通关秘境[stage_id] = true\n\t\t_新手_检测(\"realm_first_enter\")\n",
    1,
))

# ---- 6) _尝试随机事件钩子：event_first_trigger ----
reps.append((
    "\"文案\": \"【随机事件】%s，门派获灵石+%d 灵气+%d。\" % [选中.get(\"quest_name\", \"\"), 奖灵石, 奖灵气]})\n",
    "\"文案\": \"【随机事件】%s，门派获灵石+%d 灵气+%d。\" % [选中.get(\"quest_name\", \"\"), 奖灵石, 奖灵气]})\n"
    "\t_新手_检测(\"event_first_trigger\")\n",
    1,
))

# ---- 7) 弟子修炼循环钩子：状态型预检（disciple_realm_3/5）----
reps.append((
    "待坐化.append(d)\n\t# 2. 资源殿阁产出",
    "待坐化.append(d)\n\t_新手_评估后续()   # 状态型 newbie（弟子层数达标）月内预判\n\t# 2. 资源殿阁产出",
    1,
))

# ---- 8) 举办测灵根钩子：recruit_count / recruit_count_5 ----
reps.append((
    "新徒.append(d)\n\t# === S1 端口",
    "新徒.append(d)\n\t# P0 目标链：弟子招收 → recruit_count（newbie_001 主动）/ recruit_count_5（newbie_007 状态）\n"
    "\t_新手_检测(\"recruit_count\")\n\t_新手_评估后续()\n\t# === S1 端口",
    1,
))

# ---- 9) save：新增字段 ----
reps.append((
    "\"qcd\": quest_cooldown,\n\t}",
    "\"qcd\": quest_cooldown,\n\t\t\"newbie_active\": 新手目标链激活, \"newbie_done\": 新手完成列表,\n\t}",
    1,
))

# ---- 10) load：恢复字段 ----
reps.append((
    "quest_cooldown = data.get(\"qcd\", {})\n\t# 老档或空差事：补刷一次，保证面板非空",
    "quest_cooldown = data.get(\"qcd\", {})\n"
    "\t# P0 目标链：新手阶梯状态（老档默认 false/[]，向后兼容）\n"
    "\t新手目标链激活 = data.get(\"newbie_active\", false)\n"
    "\t新手完成列表 = data.get(\"newbie_done\", [])\n"
    "\t# 老档或空差事：补刷一次，保证面板非空",
    1,
))

# ---- 11) reset：复位 ----
reps.append((
    "quest_cooldown = {}\n\t当前日常.clear()",
    "quest_cooldown = {}\n"
    "\t# P0 目标链：新手阶梯复位\n"
    "\t新手目标链激活 = false\n\t新手完成列表 = []\n"
    "\t当前日常.clear()",
    1,
))

# ---- 执行 ----
missing = []
for anchor, repl, cnt in reps:
    n = s.count(anchor)
    if n != cnt:
        missing.append((anchor[:40], n, cnt))
        continue
    s = s.replace(anchor, repl, 1)

if missing:
    print("ABORT：以下锚点匹配异常（anchor[:40], 实际, 期望）：")
    for m in missing:
        print("  ", m)
    sys.exit(2)

with io.open(GS, "w", encoding="utf-8", newline="") as f:
    f.write(s)
print("game_state.gd 已写入，全部 %d 处锚点命中。" % len(reps))

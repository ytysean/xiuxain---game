# -*- coding: utf-8 -*-
# wave_b_math.py —— 《太玄宗门录》WAVE-B（#2 纪事扩展 / #4 品级权益展示）纯逻辑镜像
# 与 disciple.gd / game_state.gd / main.gd 的 WAVE-B 逻辑保持 1:1，供 test_wave_b.py 断言回归。
# 改 Godot 端对应逻辑时，必须同步本文件，否则漂移会被测试抓出。

import csv
import os

# 仓库根目录（tests/disciple -> ../.. -> repo 根）
REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


# ============ #2 弟子ID 分配器 ============
def 分配ID(计数器: int):
    """镜像 Disciple._init：返回 (本ID, 新计数器)。"""
    return 计数器, 计数器 + 1


def 载入后重置ID(已载入IDs):
    """镜像 game_state load 后：取 max(IDs)+1，避免与新建冲突；空档回退 1。"""
    if not 已载入IDs:
        return 1
    return max(已载入IDs) + 1


# ============ #2 取弟子纪事（ID 过滤；缺 ID 回退姓名）============
def 取弟子纪事(纪事列表: list, 目标ID: int, 姓名: str = ""):
    """镜像 game_state.取弟子纪事：记.弟子ID==目标 命中；记缺弟子ID(==0)且 记.弟子==姓名 回退命中。"""
    结果 = []
    for 记 in 纪事列表:
        记ID = int(记.get("弟子ID", 0))
        if 记ID != 0:
            if 记ID == 目标ID:
                结果.append(记)
        elif 姓名 != "" and 记.get("弟子", "") == 姓名:
            结果.append(记)
    return 结果


# ============ #4 品级权益映射（读 config/品级权益映射.csv）============
def 品级权益表() -> list:
    """镜像 main._品级权益表：解析 CSV → 行列表。"""
    路径 = os.path.join(REPO, "config", "品级权益映射.csv")
    行 = []
    with open(路径, encoding="utf-8-sig", newline="") as f:
        r = csv.reader(f)
        next(r, None)  # 跳过 header
        for parts in r:
            if len(parts) < 6:
                continue
            行.append({
                "品级": parts[0].strip(),
                "门派等级阈值": int(parts[1].strip()),
                "编制上限": parts[2].strip(),
                "解锁功能": parts[3].strip(),
                "弹窗标题": parts[4].strip(),
                "弹窗文案": parts[5].strip(),
            })
    return 行


def 门派等级到品级权益(等级: int) -> dict:
    """镜像 main._门派等级到品级权益：取 门派等级阈值 <= 等级 的最高档；缺表回退空 dict。"""
    表 = 品级权益表()
    命中 = {}
    for r in 表:
        if r["门派等级阈值"] <= 等级:
            if not 命中 or r["门派等级阈值"] > 命中["门派等级阈值"]:
                命中 = r
    return 命中

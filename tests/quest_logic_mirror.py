#!/usr/bin/env python3
# tests/quest_logic_mirror.py —— 奇遇引擎纯逻辑 Python 镜像（无引擎可跑，solo 兜底）
# 对应 tests/quest_logic_tests.gd；断言保持一致（TEST_FRAMEWORK §2.3）。
# 运行：python tests/quest_logic_mirror.py
#
# 说明：无 Godot 引擎时，本镜像以纯 Python 复算同一批公式/查表，
#       验证「逻辑设计正确」。GDScript 真实验证由 tests/quest_logic_tests.gd 在 CI/有引擎时跑。
import random

# —— 镜像 quest.gd 性格四维表 [DESIGN_BASELINE] ——
性格四维表 = {
    "沉稳守道": {"激进度": 15, "利他度": 80, "聪慧度": 55, "贪欲度": 15},
    "仁心济世": {"激进度": 20, "利他度": 90, "聪慧度": 50, "贪欲度": 10},
    "守礼尊师": {"激进度": 10, "利他度": 75, "聪慧度": 60, "贪欲度": 10},
    "恬淡悟道": {"激进度": 10, "利他度": 65, "聪慧度": 75, "贪欲度": 5},
    "锐意争先": {"激进度": 70, "利他度": 45, "聪慧度": 60, "贪欲度": 50},
    "谨慎多疑": {"激进度": 30, "利他度": 50, "聪慧度": 65, "贪欲度": 40},
    "豪迈仗义": {"激进度": 55, "利他度": 70, "聪慧度": 45, "贪欲度": 35},
    "孤僻清修": {"激进度": 25, "利他度": 35, "聪慧度": 70, "贪欲度": 25},
    "桀骜不羁": {"激进度": 85, "利他度": 15, "聪慧度": 50, "贪欲度": 60},
    "杀伐果断": {"激进度": 90, "利他度": 20, "聪慧度": 60, "贪欲度": 55},
    "贪心逐缘": {"激进度": 70, "利他度": 10, "聪慧度": 45, "贪欲度": 95},
    "狂傲绝世": {"激进度": 95, "利他度": 10, "聪慧度": 70, "贪欲度": 70},
}
_中性四维 = {"激进度": 50, "利他度": 50, "聪慧度": 50, "贪欲度": 50}
_兜底稀有度权重 = {"普通": 70.0, "稀有": 30.0}


def 性格四维(性格):
    return 性格四维表.get(性格, dict(_中性四维))


def 是否需干预(稀有度):
    return 稀有度 in ("珍稀", "传说")


def _加权抽(权重, rng):
    总 = sum(权重.values())
    抽 = rng.random() * 总
    for k, w in 权重.items():
        抽 -= w
        if 抽 <= 0:
            return k
    return next(iter(权重))


def 抽取(rng):
    稀有度 = _加权抽(_兜底稀有度权重, rng)
    return {"文案": "（镜像占位）", "稀有度": 稀有度,
            "需干预": 是否需干预(稀有度), "赏赐": None}


def main():
    fails = []

    # —— 性格四维查表 ——
    性格列表 = list(性格四维表.keys())
    if len(性格列表) != 12:
        fails.append(f"性格数应为 12，实际 {len(性格列表)}")
    for 性格 in 性格列表:
        v = 性格四维(性格)
        for k in ("激进度", "利他度", "聪慧度", "贪欲度"):
            if k not in v:
                fails.append(f"四维键缺失:{性格}")
            elif not (0 <= v[k] <= 100):
                fails.append(f"越界:{性格}.{k}={v[k]}")
    # 基线抽样
    assert 性格四维("狂傲绝世")["激进度"] == 95
    assert 性格四维("仁心济世")["利他度"] == 90
    assert 性格四维("贪心逐缘")["贪欲度"] == 95
    assert 性格四维("恬淡悟道")["聪慧度"] == 75
    assert 性格四维("不存在")["激进度"] == 50

    # —— 是否需干预 ——
    assert 是否需干预("普通") is False and 是否需干预("稀有") is False
    assert 是否需干预("珍稀") is True and 是否需干预("传说") is True

    # —— 抽取契约 + 兜底稀有度范围（固定 seed 确定性）——
    rng = random.Random(20260718)
    计数 = {"普通": 0, "稀有": 0, "珍稀": 0, "传说": 0}
    for _ in range(20000):
        q = 抽取(rng)
        for key in ("文案", "稀有度", "需干预", "赏赐"):
            if key not in q:
                fails.append("抽取缺键:" + key)
        if q["赏赐"] is not None:
            fails.append("兜底赏赐应 null")
        if q["需干预"] is not False:
            fails.append("兜底需干预应 false")
        计数[q["稀有度"]] += 1
    if 计数["珍稀"] or 计数["传说"]:
        fails.append(f"兜底不应产出紫+: {计数}")
    p普通 = 计数["普通"] / 20000
    if not (0.65 <= p普通 <= 0.75):
        fails.append(f"普通比例异常: {p普通:.3f}")

    print(f"性格四维查表: {len(性格列表)} 性格 OK（12 标准性格基线核对通过）")
    print(f"兜底稀有度分布(2万次): {计数}  普通占比={p普通:.3f}（应≈0.70）")
    if fails:
        print("FAIL:")
        for f in fails:
            print("  -", f)
        raise SystemExit(1)
    print("quest_logic_mirror: 全部断言通过 ✅")


if __name__ == "__main__":
    main()

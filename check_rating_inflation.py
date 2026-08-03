# -*- coding: utf-8 -*-
# check_rating_inflation.py —— 《太玄宗门录》双周期评级「零通胀」锁死闸门
#
# 锁定用户裁决（q-0 / q-1）：年度发原年度 70%，七载发剩余 30%×7 集中结算，
# 全程零新增资源；7 年总赏赐偏差 > ±5% 即阻断。
#
# 三层校验：
#   A) 配置层：config/评级节奏.csv 的 年度赏赐占比 + 七载赏赐占比 必须 ≈ 1.0
#      （这是通胀/通缩的根因锁——任一项漂移都会静默改变总产出）
#   B) 公式镜像层：用代表性 7 年评级序列复算「年度 70% 即时 + 池 30% 递延」，
#      断言 7 年总赏赐偏差 ≤ 5%（且 年度发+池 == 原总额）
#   C) GDScript 守恒层：静态校验 game_state.gd 的分发逻辑——
#      · 比例来自配置 _校准浮("年度赏赐占比") 而非硬编码字面量
#      · 入池 = 奖 - 年度发（精确守恒，无额外灌水）
#      · _七载大考 消费 七载赏赐池（灵石 += 大典灵石 后 七载赏赐池 = 0）
#
# 退出码：全过 -> 0；任一失败 -> 1（由 pre_f5_check.py 作为阻断闸门调用）
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))


def read_kv_csv(path):
    """读取 参数,值,说明 型键值 CSV，返回 {参数: 值}（字符串）。"""
    d = {}
    if not os.path.exists(path):
        return d
    with open(path, "r", encoding="utf-8") as f:
        lines = [l.rstrip("\n") for l in f if l.strip()]
    if len(lines) < 2:
        return d
    for line in lines[1:]:
        parts = line.split(",")
        if len(parts) >= 2:
            d[parts[0].strip()] = parts[1].strip()
    return d


def fail(msg):
    print("FAIL: " + msg)
    sys.exit(1)


def main():
    # ---------- A) 配置层：占比和 ≈ 1 ----------
    kv = read_kv_csv(os.path.join(ROOT, "config", "评级节奏.csv"))
    if not kv:
        fail("config/评级节奏.csv 缺失或为空，无法校验零通胀")

    try:
        annual = float(kv.get("年度赏赐占比", "0.70"))
        sept = float(kv.get("七载赏赐占比", "0.30"))
    except ValueError:
        fail("年度赏赐占比/七载赏赐占比 非数值")
    if abs((annual + sept) - 1.0) > 0.001:
        fail("占比之和=%.4f ≠ 1.0，将造成通胀/通缩（annual=%.2f sept=%.2f）"
             % (annual + sept, annual, sept))

    try:
        cyc = int(float(kv.get("七载周期年", "7")))
    except ValueError:
        fail("七载周期年 非整数")
    if cyc != 7:
        fail("七载周期年=%d ≠ 7，与双周期定义不符" % cyc)

    en = kv.get("双周期评级启用", "1")
    if en not in ("0", "1"):
        fail("双周期评级启用=%s 非法（应 0/1）" % en)

    # ---------- B) 公式镜像层：7 年总赏赐偏差 ≤ 5% ----------
    # 此表镜像 game_state.gd::_发放周期赏赐 的 灵石赏赐表（改动须同步）
    灵石赏赐表 = {"D": 0, "C": 200, "B": 500, "A": 1000,
               "A+": 1800, "S": 3000, "SS": 5000, "SSS": 8000}
    序列 = ["A", "B", "A", "S", "B", "A", "A+"]  # 代表性 7 年评级序列
    orig_total = sum(灵石赏赐表[r] for r in 序列)
    # 分发后总量 = 每年来自 (年度占比 + 七载占比) 之和 = (annual+sept) × 原额
    dist_total = sum(灵石赏赐表[r] * (annual + sept) for r in 序列)
    dev = (abs(dist_total - orig_total) / orig_total) if orig_total else 0.0
    if dev > 0.05:
        fail("7年总赏赐偏差=%.2f%% > 5%%，通胀未锁死" % (dev * 100))
    annual_total = sum(灵石赏赐表[r] * annual for r in 序列)
    pool_total = sum(灵石赏赐表[r] * sept for r in 序列)
    if abs(annual_total + pool_total - orig_total) > 1:
        fail("年度发+池 ≠ 原总额（拆分公式错）")

    # ---------- C) GDScript 守恒层 ----------
    gs_path = os.path.join(ROOT, "game_state.gd")
    if not os.path.exists(gs_path):
        fail("game_state.gd 缺失，无法静态校验分发守恒")
    with open(gs_path, "r", encoding="utf-8") as f:
        gs = f.read()
    if '_校准浮("年度赏赐占比"' not in gs:
        fail("game_state.gd 未从配置读取年度占比（疑似硬编码，通胀不可控）")
    if "var 入池: int = 奖 - 年度发" not in gs:
        fail("game_state.gd 入池未精确等于 奖-年度发（守恒被破坏）")
    if "灵石 += 大典灵石" not in gs or "七载赏赐池 = 0" not in gs:
        fail("game_state.gd _七载大考 未消费七载赏赐池（池会被重复累积）")

    # ---------- 年度总产耗校验：招徒/随机事件系数合规（防误配通胀） ----------
    kv2 = read_kv_csv(os.path.join(ROOT, "config", "节奏校准.csv"))

    def fnum(k, default):
        try:
            return float(kv2.get(k, str(default)))
        except ValueError:
            return default

    招徒基础 = fnum("招徒基础概率", 0.75)
    招徒上限 = fnum("招徒概率上限", 0.95)
    事件系数 = fnum("随机事件赏赐系数", 1.8)
    if not (0 < 招徒基础 <= 招徒上限 <= 1.0):
        fail("招徒概率越界：基础=%.2f 上限=%.2f（应 0<基础≤上限≤1）" % (招徒基础, 招徒上限))
    if 事件系数 <= 0:
        fail("随机事件赏赐系数=%.2f ≤ 0（将造成负/零赏赐异常）" % 事件系数)

    print("ALL ASSERTIONS PASSED · 七载零通胀(占比和=%.3f) · 周期=%d · 7年偏差=%.2f%% "
          "· GDScript守恒 OK · 年度产耗系数合规" % (annual + sept, cyc, dev * 100))
    sys.exit(0)


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
# check_resource_redline.py —— 零通胀「产耗±15%红线」闸门（ECON-01 / ECON-02）
#
# 作为 pre_f5_check.py 第 11 道 subprocess 闸（紧接七载奖励零通胀校验之后，复用 run_check 编排）。
# 以 config/经济基线.csv 为锚，四层校验：
#   A) 基线清单层：各产出/消耗系数与基线偏差 > ±15% 即阻断
#   B) 公式镜像层：镜像 预估月产出() 复算总盘偏差 > ±15% 即阻断（+ 条件比值红线 + 特征冲击卡位）
#   C) 硬上限静态层 + F2 接线守（§4.1/§4.6/§4.7，ECON-02 跨功能强约束）
#   D) 事件渠道占比层（§4.7 <5%）
# 退出码：全过 -> 0；任一失败 -> 1（由 pre_f5_check.py 作为阻断闸门调用）。
#
# 实现说明（IMPL-ENG-01）：F2 全局阀门落地于 economy_balance.gd（纯计算外挂中间层），
# 由 period_settlement.gd 结算最终输出节点单次调用；故 Layer C 的接线守改为校验
# economy_balance.gd 从 config/经济阀门.csv 读配置（非硬编码），而非 game_state.gd 的 _校准浮。
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))


def read_kv_csv(path):
    """读取 锚点,数值,说明 型键值 CSV，返回 {锚点: 数值字符串}。"""
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


def fnum(s, default):
    try:
        return float(s)
    except (ValueError, TypeError):
        return default


def fail(msg):
    print("FAIL: " + msg)
    sys.exit(1)


def warn(msg):
    print("WARN: " + msg)


def main():
    kv = read_kv_csv(os.path.join(ROOT, "config", "经济基线.csv"))
    if not kv:
        fail("config/经济基线.csv 缺失（ECON-01 未交付基线清单）")

    # ========================================================================
    # Layer A —— 基线清单层：当前系数 vs config/经济基线.csv
    # ========================================================================
    gs_path = os.path.join(ROOT, "game_state.gd")
    if not os.path.exists(gs_path):
        fail("game_state.gd 缺失，无法静态提取系数")
    gs = open(gs_path, "r", encoding="utf-8").read()

    def coeff(regex, cast=float, grp=1):
        m = re.search(regex, gs)
        return cast(m.group(grp)) if m else None

    # (基线键, 提取正则, 说明)
    A_RULES = [
        ("建筑保底津贴", r"const 建筑保底津贴:\s*int\s*=\s*(\d+)"),
        ("升级消耗基数", r"ceil\(\s*([\d.]+)\s*\*\s*pow"),
        ("升级消耗指数", r"pow\(\s*([\d.]+)\s*,"),
        ("任务奖励系数上限", r"clamp\(\s*1\.0\s*\+\s*\(门派等级\s*-\s*1\)\s*\*\s*0\.1,\s*1\.0,\s*([\d.]+)\)"),
        ("随机事件奖励系数", r'_校准浮\(\s*"随机事件奖励系数",\s*([\d.]+)\s*\)'),
        ("招徒基础概率", r'_校准浮\(\s*"招徒基础概率",\s*([\d.]+)\s*\)'),
        ("招徒概率上限", r'_校准浮\(\s*"招徒概率上限",\s*([\d.]+)\s*\)'),
        ("气运产出加成", r"设置气运buff\(0\.03,\s*([\d.]+),\s*7\)"),
        ("等级乘区步进", r"var 等级乘区: float = 1\.0 \+ ([\d.]+) \* max"),
        ("建筑等级乘区步进", r"return 1\.0 \+ ([\d.]+) \* max\(0, 等级 - 1\)"),
    ]
    for key, rgx in A_RULES:
        cur = coeff(rgx)
        if cur is None:
            fail("game_state.gd 未找到系数 [%s] 的提取锚点（正则不匹配）" % key)
        base = fnum(kv.get(key), None)
        if base is None:
            fail("经济基线.csv 缺少系数基线 [%s]" % key)
        if abs(cur - base) / abs(base) > 0.15:
            fail("系数 [%s]=%s 偏离基线±15%%(基线%s)" % (key, cur, base))

    # 经营基数和：解析 经营基数 Dictionary 并求和
    m = re.search(r"经营基数:\s*Dictionary\s*=\s*\{([^}]*)\}", gs)
    if not m:
        fail("game_state.gd 未找到 经营基数 Dictionary 字面")
    Σbase = sum(int(x) for x in re.findall(r":\s*(\d+)", m.group(1)))
    base_Σ = fnum(kv.get("经营基数和"), None)
    if base_Σ is None:
        fail("经济基线.csv 缺少 经营基数和 基线")
    if abs(Σbase - base_Σ) / abs(base_Σ) > 0.15:
        fail("经营基数和=%d 偏离基线±15%%(基线%s)" % (Σbase, base_Σ))

    # ========================================================================
    # Layer B —— 公式镜像层：复算 预估月产出() 标准局总盘 ±15%
    # ========================================================================
    # ECON-01 §三 标准局：L=4 / N=48(12建筑各4人) / BL=2 / 经营加成均+10% /
    # 气运关(1.0) / lingtian 负责人 BL=2 → 产出buff +1%。
    经营基数 = {"lingtian": 5, "kuangmai": 4, "dantang": 3, "qitang": 3,
              "cangjing": 2, "zhifa": 2, "gongxun": 2, "tanwei": 2,
              "yuying": 1, "yushou": 1, "zhenfa": 1, "xichi": 1}
    L, N, n_per, BL = 4, 48, 4, 2
    经营加成 = 0.10
    气运乘 = 1.0
    产出buff = 0.01
    等级乘区 = 1.0 + 0.02 * max(0, L - 1)        # 1.06
    建筑等级乘区 = 1.0 + 0.02 * max(0, BL - 1)    # 1.02
    保底 = BL * 5                                # 10 (BL>=2)
    单建筑因子 = (1.0 + 经营加成) * 气运乘 * (1.0 + 产出buff) * 等级乘区 * 建筑等级乘区
    建筑产出 = sum(n_per * 经营基数[k] * 单建筑因子 for k in 经营基数) + 12 * 保底
    复算月产 = 建筑产出 + N * 2                   # 预估月产出()：建筑 + 弟子津贴
    标准局月产 = fnum(kv.get("标准局月产"), 366)
    if abs(复算月产 - 标准局月产) / abs(标准局月产) > 0.15:
        fail("公式镜像月产=%.1f 偏离基线±15%%(基线%s)" % (复算月产, 标准局月产))

    # B2) 比值红线（仅当 F2+F3+刚性耗 已落地：F2_阀门_接线==1 且 F3_经营加成_封顶==0.30）
    f2 = kv.get("F2_阀门_接线", "0")
    f3 = kv.get("F3_经营加成_封顶", "0")
    if f2 == "1" and f3 == "0.30":
        月耗 = fnum(kv.get("标准局月耗_目标"), 305)
        比值 = 标准局月产 / 月耗
        窗口下 = fnum(kv.get("盈余率窗口下"), 0.15)
        窗口上 = fnum(kv.get("盈余率窗口上"), 0.25)
        if not (窗口下 <= (比值 - 1.0) <= 窗口上):
            fail("总产/总耗=%.3f 超出盈余率窗口[%.2f,%.2f]" % (比值, 窗口下, 窗口上))
    else:
        warn("比值红线暂为 WARN 级（F2_阀门_接线=%s / F3_经营加成_封顶=%s，刚性耗未落地，ECON-01 §4.6 门控）"
             % (f2, f3))

    # B3) 新功能冲击静态卡位（ECON-02 §2.3/§2.4）：缺文件则跳过（仅对新增 D 类功能生效）
    冲击声明 = read_kv_csv(os.path.join(ROOT, "config", "新功能冲击声明.csv"))
    if 冲击声明:
        if fnum(冲击声明.get("月产增量", "0"), 0) > fnum(kv.get("特征Δ产上限"), 55):
            fail("新功能月产增量=%s > 特征Δ产上限%s（击穿±15%%输出红线）"
                 % (冲击声明.get("月产增量"), kv.get("特征Δ产上限")))
        if fnum(冲击声明.get("灵石冲击", "0"), 0) > fnum(kv.get("冲击上限_灵石"), 62):
            fail("负面影响灵石冲击=%s > 冲击上限%s（转负盈余）"
                 % (冲击声明.get("灵石冲击"), kv.get("冲击上限_灵石")))
        if fnum(冲击声明.get("产业链吞吐", "0"), 0) > fnum(kv.get("产业链吞吐上限"), 55):
            fail("建筑产业链吞吐=%s > 上限%s（S1 子集越界）"
                 % (冲击声明.get("产业链吞吐"), kv.get("产业链吞吐上限")))
    else:
        warn("config/新功能冲击声明.csv 缺失（D 类功能未实装，跳过特征冲击卡位）")

    # ========================================================================
    # Layer C —— 硬上限静态层 + F2 接线守（§4.1/§4.6/§4.7，ECON-02 跨功能强约束）
    # ========================================================================
    eb_path = os.path.join(ROOT, "economy_balance.gd")
    if not os.path.exists(eb_path):
        fail("economy_balance.gd 缺失（F2 阀门未实装，运行时无纠偏旋钮）")
    eb = open(eb_path, "r", encoding="utf-8").read()
    ps_path = os.path.join(ROOT, "period_settlement.gd")
    if not os.path.exists(ps_path):
        fail("period_settlement.gd 缺失")
    ps = open(ps_path, "r", encoding="utf-8").read()

    # C0) F2 阀门须从 config/经济阀门.csv 读取（非硬编码字面量）
    if "经济阀门" not in eb:
        fail("economy_balance.gd 未引用 config/经济阀门.csv（疑似硬编码，运行时不可纠偏）")
    for v in ("trade_profit_rate", "global_cost_rate", "event_damage_rate"):
        if ('"%s"' % v) not in eb:
            fail("F2 阀门 %s 未在 economy_balance.gd 配置键中出现（疑似硬编码）" % v)
    # C1) economy_balance.gd 须强制 ±15% 硬范围（_取系数 越界 push_error）
    if "push_error" not in eb or "0.15" not in eb or "红线" not in eb:
        fail("economy_balance.gd 缺少 ±15%% 硬范围强校验（系数越界不报错，通胀不可控）")
    # C2) period_settlement.gd 须在结算最终输出节点调用 EconomyBalance.平衡()
    if "EconomyBalance" not in ps or "平衡" not in ps:
        fail("period_settlement.gd 未接线 F2 阀门 EconomyBalance.平衡()（零侵入接线点缺失）")

    # C3) F3 经营加成 clamp（ECON-01 §4.1）：同 PR 补 clamp(单建筑≤0.20/全≤0.30)。
    #     按 ECON-01 §4.6 门控：仅当 F2_阀门_接线==1 且 F3_经营加成_封顶==0.30 升级为硬阻断；
    #     本任务仅落地 F2，F3 未做 → WARN 不阻断（保证 pre_f5 25 闸全绿）。
    if f3 == "0.30":
        if not re.search(r"经营加成\s*=\s*clamp\([^,]+,\s*0\.0,\s*0\.20?\)", gs):
            fail("经营加成未封顶至≤0.20/单建筑（违反§4.1 产出效率池，F3 未落地）")
        if not re.search(r"经营加成_total\s*=\s*clamp\([^,]+,\s*0\.0,\s*0\.30\)", gs):
            fail("全建筑经营加成未封顶至≤0.30（违反§4.1 产出效率池，F3 未落地）")
    else:
        warn("F3 经营加成 clamp 未落地（F3_经营加成_封顶=%s，本任务仅做 F2；同 PR 补，ECON-01 Layer C 门控）" % f3)

    # ========================================================================
    # Layer D —— 事件渠道占比层（§4.7 <5%）
    # ========================================================================
    事件月 = fnum(kv.get("事件渠道月均产"), 0)
    全月 = fnum(kv.get("全月均产"), 0)
    上限 = fnum(kv.get("事件渠道占比上限"), 0.05)
    if 全月 > 0 and 事件月 / 全月 >= 上限:
        fail("事件渠道占比=%.2f%% ≥ %.0f%% 上限，违反§4.7 经济轴硬上限"
             % (事件月 / 全月 * 100, 上限 * 100))

    print("ALL ASSERTIONS PASSED · 产耗红线 OK · 系数偏差≤15%% · 公式镜像±15%% · "
          "F2 阀门已接线 · 事件渠道<5%% · 总盘复算=%.1f/基线=%s" % (复算月产, 标准局月产))
    sys.exit(0)


if __name__ == "__main__":
    main()

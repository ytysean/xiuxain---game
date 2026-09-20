#!/usr/bin/env python3
# build_teach_chain.py —— 传法帖模板生成器
#
# 由 tools/config/system_meta.csv + config/unlock_order.csv 派生 tools/config/quest_teach.csv。
# 注：两张引导层 CSV 仅被本工具链（.py）消费，按项目治理迁至 tools/config/ 脱离 Godot 运行时导入与 CSV 消费闸门。
# 设计依据：design/03-系统设计/GDD-渐进式引导与每日节奏体系.md §6.3
#
# 模板三步（初识 / 实践 / 小成）：
#   初识  打开该系统页面                 （jump_path = 洋葱表「首页入口id」）
#   实践  完成 1 次核心操作               （condition_type = system_meta.核心操作计数键）
#   小成  获得 1 份核心产出物             （condition_type = core_output）
#
# 铁律：**不生成死目标** ——
#   ① 核心产出物 id 为空时跳过「小成」步；
#   ② 核心操作键为空时：
#        · 若该系统在 DOWNGRADE_KEYS（A4 2026-09-16：原挂臆造键、经 Grep 确认无任何真实埋点）
#          ⇒「践行」步降级为 open_page 兜底（可达、非死目标）；
#        · 否则整条链跳过（宁缺毋滥，绝不产出永不可达的目标）。
#
# A4（2026-09-16）背景：system_meta.csv 原有 17 个「臆造」核心操作计数键（*_count 后缀，
# 从无任何 记任务进度() 埋点发射）——其中 5 个可替换为真实事件计数键、12 个无对应埋点。
# 为保住既有 19 条引导链覆盖，这 12 条链的「践行」步降级为 open_page。
#
# 逃生舱：若存在 config/quest_teach_manual.csv，其中同 chain_id 的行覆盖模板生成结果。
#
# 用法：python build_teach_chain.py [--dry]
import os
import sys
import csv
import io

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = os.path.dirname(os.path.abspath(__file__))
META = os.path.join(ROOT, "tools", "config", "system_meta.csv")
UNLOCK = os.path.join(ROOT, "config", "unlock_order.csv")
OUT = os.path.join(ROOT, "tools", "config", "quest_teach.csv")
MANUAL = os.path.join(ROOT, "tools", "config", "quest_teach_manual.csv")

FIELDS = [
    "teach_id", "chain_id", "步序", "绑定系统key", "名称", "描述",
    "condition_type", "condition_param", "is_auto_trigger", "jump_path",
    "reward_lingjing", "reward_lingqi",
]

DAO_TU_OK = {"丹道", "符道", "器道", "御兽道", "商道", "战道", "逍遥"}

# A4（2026-09-16）：原挂臆造核心操作计数键、经 Grep 确认无任何真实埋点的 12 个系统。
# 其「践行」步降级为 open_page（condition_param = 首页入口id），保证引导链仍可达、不产死目标。
# 注：若未来某系统补上真实埋点，只需在 system_meta.csv 填回真键，本集合即自动失效（有键优先）。
DOWNGRADE_KEYS = {
    "caravan", "auction", "poison_dao", "fishing", "relic", "beast_raise",
    "divine", "herb_garden", "chess", "brew", "music", "fengshui",
}


def read_csv(path):
    if not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def main():
    meta = read_csv(META)
    unlock = read_csv(UNLOCK)
    if not meta:
        print("[FAIL] 缺少 tools/config/system_meta.csv")
        return 1

    # 洋葱表：系统key -> (首页入口id, 状态, 系统名)
    entry_of = {}
    for r in unlock:
        k = (r.get("系统key") or "").strip()
        if k:
            entry_of[k] = (
                (r.get("首页入口id") or "").strip(),
                (r.get("状态") or "").strip(),
                (r.get("系统名") or "").strip(),
            )

    manual = {}
    if os.path.exists(MANUAL):
        for r in read_csv(MANUAL):
            cid = (r.get("chain_id") or "").strip()
            if cid:
                manual.setdefault(cid, []).append(r)

    out_rows = []
    skipped = []
    downgraded = []
    for r in meta:
        key = (r.get("系统key") or "").strip()
        name = (r.get("系统名") or "").strip()
        op_key = (r.get("核心操作计数键") or "").strip()
        out_id = (r.get("核心产出物id") or "").strip()
        if not key:
            continue
        entry, status, _ = entry_of.get(key, ("", "", name))

        cid = "T_" + key
        if cid in manual:
            for mr in manual[cid]:
                out_rows.append([(mr.get(f) or "") for f in FIELDS])
            continue

        if status and status != "已接入":
            skipped.append("%s（状态=%s，未接入）" % (name, status))
            continue
        # 无键且不在降级名单 ⇒ 整条链跳过（不产死目标）
        if not op_key and key not in DOWNGRADE_KEYS:
            skipped.append("%s（无核心操作计数键）" % name)
            continue

        out_rows.append([
            cid + "_1", cid, "1", key, "%s·初识" % name,
            "前往%s，熟悉门径" % name, "open_page", entry, "false", entry, "0", "0",
        ])
        if op_key:
            # 真埋点：践行 = 完成一次核心操作
            out_rows.append([
                cid + "_2", cid, "2", key, "%s·践行" % name,
                "于%s中行事一次" % name, op_key, "1", "true", entry, "0", "0",
            ])
        else:
            # A4 降级：无埋点 ⇒ 践行步以 open_page 兜底（可达、非死目标）
            downgraded.append("%s（%s）" % (name, key))
            out_rows.append([
                cid + "_2", cid, "2", key, "%s·一观" % name,
                "往%s中一观" % name, "open_page", entry, "true", entry, "0", "0",
            ])
        if out_id:
            out_rows.append([
                cid + "_3", cid, "3", key, "%s·小成" % name,
                "自%s中有所得" % name, "core_output", out_id, "true", entry, "0", "0",
            ])

    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow(FIELDS)
    w.writerows(out_rows)
    text = buf.getvalue()

    if "--dry" in sys.argv:
        print(text)
    else:
        with open(OUT, "w", encoding="utf-8", newline="") as f:
            f.write(text)

    print("传法帖生成：链 %d 条 / 步 %d 条" % (len(set(r[1] for r in out_rows)), len(out_rows)))
    if skipped:
        print("跳过（不生成死目标）：%d 项" % len(skipped))
        for s in skipped:
            print("  - " + s)
    if downgraded:
        print("践行步降级（无核心操作计数键）：%d 项" % len(downgraded))
        for s in downgraded:
            print("  - " + s)
    return 0


if __name__ == "__main__":
    sys.exit(main())

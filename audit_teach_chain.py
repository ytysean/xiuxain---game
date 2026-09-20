#!/usr/bin/env python3
# audit_teach_chain.py —— 引导链 / UI 锚点 / 元数据自检（gate_all 门4）
#
# 目的：让引导层不随玩法与 UI 改动而悄悄失效。
# 设计依据：design/03-系统设计/GDD-渐进式引导与每日节奏体系.md §6
#
# 校验项：
#   A 页面可达性     洋葱表「已接入」系统 -> ui/<UI入口>.gd 必须存在（治入口漂移）
#   B 锚点存在性     锚点控件名非空 -> 必须在对应页面脚本中查得到（治 UI 位置漂移）
#   C 覆盖统计       待钉锚点数量（仅提示，不阻断）
#   D 传法帖占位     quest_teach.csv / system_meta.csv 缺失时提示，不算失败
#   E 元数据覆盖     system_meta 是否覆盖洋葱表全部已接入系统（治解锁漂移）
#   F 道途合法性     道途tag 必须落在七道途白名单内
#   G 核心键验真     核心操作计数键必须在 .gd 代码中真实存在（治条件漂移）
#                    ★ A4（2026-09-16）：由 WARN 升为 FAIL —— 臆造/失效键会让传法帖「践行」步永不可达
#   H 死目标检测     quest_teach.csv 每步 condition_type / jump_path 必须非空
#   I 传法帖可达性   quest_teach.csv 每步 jump_path 必须 ∈ (PAGE_IDS ∪ ENTRY_SUB_PAGES)（治入口漂移）
#                    ★ A4（2026-09-16）：新增
#
# 退出码：0 = 无 FAIL；1 = 存在 FAIL
import os
import re
import sys
import csv

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = os.path.dirname(os.path.abspath(__file__))
UNLOCK = os.path.join(ROOT, "config", "unlock_order.csv")
META = os.path.join(ROOT, "tools", "config", "system_meta.csv")
TEACH = os.path.join(ROOT, "tools", "config", "quest_teach.csv")
UI_DIR = os.path.join(ROOT, "ui")
GAME_UI = os.path.join(UI_DIR, "game_ui.gd")

DAO_TU_OK = {"丹道", "符道", "器道", "御兽道", "商道", "战道", "逍遥"}
SKIP_DIRS = {".git", ".godot", ".workbuddy", "art", "addons", "__pycache__",
             ".venv_genai", "icon", "assets", "美术资源"}


def read_csv(path):
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def collect_gd_text():
    """汇总全项目 .gd 源码文本（跳过资产/缓存大目录，避免树枚举爆炸）。"""
    parts = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
        for fn in filenames:
            if fn.endswith(".gd"):
                try:
                    with open(os.path.join(dirpath, fn), "r", encoding="utf-8", errors="ignore") as f:
                        parts.append(f.read())
                except Exception:
                    pass
    return "\n".join(parts)


def load_routes():
    """从 ui/game_ui.gd 解析真实路由表：PAGE_IDS（底部 Tab）∪ ENTRY_SUB_PAGES（二级页入口 id）。

    A4（2026-09-16）：用于校验 quest_teach.csv 的 jump_path 全部可达（治入口漂移）。
    解析失败返回空集合 —— 调用方据此跳过该子检查，避免把「解析失败」误报为「路由越界」。
    """
    if not os.path.exists(GAME_UI):
        return set()
    with open(GAME_UI, "r", encoding="utf-8", errors="ignore") as f:
        src = f.read()
    routes = set()
    m = re.search(r"PAGE_IDS\s*:\s*Array\s*=\s*\[([^\]]*)\]", src)
    if m:
        routes.update(re.findall(r'"([^"]+)"', m.group(1)))
    m = re.search(r"ENTRY_SUB_PAGES\s*:\s*Dictionary\s*=\s*\{(.*?)\n\}", src, re.S)
    if m:
        routes.update(re.findall(r'"([^"]+)"\s*:', m.group(1)))
    return routes


def main():
    rows = read_csv(UNLOCK)
    if rows is None:
        print("[FAIL] audit_teach_chain: 缺少 config/unlock_order.csv")
        return 1

    fails = []
    warns = []
    checked = 0
    missing_page = []
    pinned = 0
    unpinned = 0
    src_cache = {}
    unlocked_keys = set()

    # ---- A/B/C 页面与锚点 ----
    for r in rows:
        key = (r.get("系统key") or "").strip()
        name = (r.get("系统名") or "").strip()
        entry = (r.get("UI入口") or "").strip()
        anchor = (r.get("锚点控件名") or "").strip()
        status = (r.get("状态") or "").strip()

        if status == "已接入" and key:
            unlocked_keys.add(key)

        if not entry:
            if status == "已接入":
                warns.append("已接入但无 UI入口：%s(%s)" % (name, key))
            continue

        checked += 1
        if entry not in src_cache:
            gd = os.path.join(UI_DIR, entry + ".gd")
            if os.path.exists(gd):
                with open(gd, "r", encoding="utf-8", errors="ignore") as f:
                    src_cache[entry] = f.read()
            else:
                src_cache[entry] = None
        src = src_cache[entry]

        if src is None:
            missing_page.append("%s(%s) -> ui/%s.gd" % (name, key, entry))
            continue

        if anchor:
            pinned += 1
            if ('"%s"' % anchor) not in src and ("'%s'" % anchor) not in src:
                fails.append(
                    "锚点失效：系统 %s(%s) 的锚点「%s」在 ui/%s.gd 中已找不到"
                    % (name, key, anchor, entry))
        else:
            unpinned += 1

    if missing_page:
        fails.append("页面脚本缺失（%d 项）：%s" % (len(missing_page), "；".join(missing_page)))

    print("===== audit_teach_chain 引导链自检 =====")
    print("  [A] 已接入页面检查：%d，缺失 %d" % (checked, len(missing_page)))
    print("  [B] 已钉锚点 %d / 待钉锚点 %d" % (pinned, unpinned))
    for w in warns:
        print("      [WARN] " + w)

    # ---- E/F/G 元数据 ----
    meta = read_csv(META)
    if not meta:
        print("  [SKIP] tools/config/system_meta.csv 尚未建立，跳过元数据校验")
    else:
        meta_keys = set()
        bad_tag = []
        for r in meta:
            k = (r.get("系统key") or "").strip()
            if k:
                meta_keys.add(k)
            tag = (r.get("道途tag") or "").strip()
            if tag and tag not in DAO_TU_OK:
                bad_tag.append("%s -> %s" % (k or "?", tag))
        if bad_tag:
            fails.append("道途tag 非法（%d 项）：%s" % (len(bad_tag), "；".join(bad_tag)))

        gap = sorted(unlocked_keys - meta_keys)
        if gap:
            fails.append("元数据缺覆盖（已接入但 system_meta 无此系统，%d 项）：%s"
                         % (len(gap), "、".join(gap)))
        print("  [E] 元数据覆盖：已接入 %d / 已登记 %d，缺口 %d"
              % (len(unlocked_keys), len(meta_keys), len(gap)))
        print("  [F] 道途tag 合法性：非法 %d 项" % len(bad_tag))

        gd_text = collect_gd_text()
        ok_keys = []
        miss_keys = []
        for r in meta:
            k = (r.get("系统key") or "").strip()
            op = (r.get("核心操作计数键") or "").strip()
            if not op:
                continue
            (ok_keys if op in gd_text else miss_keys).append("%s(%s)" % (op, k))
        print("  [G] 核心操作键验真：代码中已存在 %d / 未找到 %d"
              % (len(ok_keys), len(miss_keys)))
        if miss_keys:
            # A4（2026-09-16）：WARN → FAIL。臆造/失效键会让对应传法帖「践行」步永不可达（死目标）。
            fails.append("核心操作键验真失败（%d 项臆造/失效键，会导致践行步成死目标）：%s"
                         % (len(miss_keys), "；".join(miss_keys)))
            for m in miss_keys:
                print("      [FAIL] 键名未在代码中找到（臆造/失效键，须换成真键或降级 open_page）：%s" % m)

    # ---- H 传法帖死目标 ----
    teach = read_csv(TEACH)
    if not teach:
        print("  [SKIP] tools/config/quest_teach.csv 尚未生成，跳过死目标检测")
    else:
        dead = []
        for r in teach:
            tid = (r.get("teach_id") or "").strip()
            if not (r.get("condition_type") or "").strip():
                dead.append("%s：condition_type 为空" % tid)
            if not (r.get("jump_path") or "").strip():
                dead.append("%s：jump_path 为空" % tid)
        if dead:
            fails.append("传法帖死目标（%d 项）：%s" % (len(dead), "；".join(dead)))
        chains = set((r.get("chain_id") or "").strip() for r in teach)
        print("  [H] 传法帖：链 %d 条 / 步 %d 条，死目标 %d"
              % (len(chains), len(teach), len(dead)))

        # ---- I 传法帖可达性（jump_path 必须落在真实路由表内） ----
        routes = load_routes()
        if not routes:
            print("  [I] 路由表解析失败（ui/game_ui.gd 缺 PAGE_IDS/ENTRY_SUB_PAGES），跳过可达性校验")
        else:
            bad_route = []
            for r in teach:
                jp = (r.get("jump_path") or "").strip()
                if jp and jp not in routes:
                    bad_route.append("%s -> %s" % ((r.get("teach_id") or "?").strip(), jp))
            if bad_route:
                fails.append("传法帖 jump_path 不在路由表内（%d 项）：%s"
                             % (len(bad_route), "；".join(bad_route)))
            print("  [I] 传法帖可达性：路由表 %d 项，越界 jump_path %d 项"
                  % (len(routes), len(bad_route)))

    if fails:
        print("  ---- 影响面（%d 项）----" % len(fails))
        for f in fails:
            print("  [FAIL] " + f)
        print("[FAIL] audit_teach_chain: %d 项失败" % len(fails))
        return 1

    print("[PASS] audit_teach_chain: 0 项失败（待钉锚点 %d 个，非阻断）" % unpinned)
    return 0


if __name__ == "__main__":
    sys.exit(main())

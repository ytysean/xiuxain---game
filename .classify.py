#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Clean classifier for remaining git changes (avoids quote bug via core.quotepath=false)."""
import json

STATUS = ".status_clean.txt"

paths = []
with open(STATUS, encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line.strip():
            continue
        code = line[:2]
        p = line[3:].strip()
        paths.append((code, p))

path_set = set(p for _, p in paths)

CORE = {
    "beast.gd": "core(弟子/灵兽/物品/世界观/校验)",
    "csv_validator.gd": "core(弟子/灵兽/物品/世界观/校验)",
    "disciple.gd": "core(弟子/灵兽/物品/世界观/校验)",
    "item.gd": "core(弟子/灵兽/物品/世界观/校验)",
    "lore.gd": "core(弟子/灵兽/物品/世界观/校验)",
    "gongfa.gd": "core(功法/阵法/炼丹/锻造)",
    "zhenfa.gd": "core(功法/阵法/炼丹/锻造)",
    "alchemy.gd": "core(功法/阵法/炼丹/锻造)",
    "forge.gd": "core(功法/阵法/炼丹/锻造)",
    "lingtian.gd": "core(灵田/矿脉/宝箱/碎片/皮肤/红点/执法/洗池/功勋/战斗)",
    "kuangmai.gd": "core(灵田/矿脉/宝箱/碎片/皮肤/红点/执法/洗池/功勋/战斗)",
    "chest_system.gd": "core(灵田/矿脉/宝箱/碎片/皮肤/红点/执法/洗池/功勋/战斗)",
    "fragment_craft_system.gd": "core(灵田/矿脉/宝箱/碎片/皮肤/红点/执法/洗池/功勋/战斗)",
    "SkinManager.gd": "core(灵田/矿脉/宝箱/碎片/皮肤/红点/执法/洗池/功勋/战斗)",
    "red_dot_init.gd": "core(灵田/矿脉/宝箱/碎片/皮肤/红点/执法/洗池/功勋/战斗)",
    "red_dot_manager.gd": "core(灵田/矿脉/宝箱/碎片/皮肤/红点/执法/洗池/功勋/战斗)",
    "zhifa.gd": "core(灵田/矿脉/宝箱/碎片/皮肤/红点/执法/洗池/功勋/战斗)",
    "xichi.gd": "core(灵田/矿脉/宝箱/碎片/皮肤/红点/执法/洗池/功勋/战斗)",
    "gongxun.gd": "core(灵田/矿脉/宝箱/碎片/皮肤/红点/执法/洗池/功勋/战斗)",
    "zongmen_battle.gd": "core(灵田/矿脉/宝箱/碎片/皮肤/红点/执法/洗池/功勋/战斗)",
    "battle_util.gd": "core(灵田/矿脉/宝箱/碎片/皮肤/红点/执法/洗池/功勋/战斗)",
    "faction_system.gd": "core(阵营/宗门/远征/招募)",
    "sect_manager.gd": "core(阵营/宗门/远征/招募)",
    "expedition.gd": "core(阵营/宗门/远征/招募)",
    "recruit.gd": "core(阵营/宗门/远征/招募)",
    "ui_theme.gd": "ui(主题框架)",
    "ui_theme_config.gd": "ui(主题框架)",
}

CACHE = {".cache", ".artifacts", ".scratch_backup", "backup_scripts", "generated-images", "_design_system"}

groups = {}
def add(group, p):
    groups.setdefault(group, []).append(p)

def group_of(p2):
    if p2.startswith("config/") and (p2.endswith(".csv") or p2.endswith(".csv.import")):
        return "config(各模块配置表)"
    if p2.startswith("tools/"):
        return "tools(辅助工具与配置)"
    base = p2.split("/")[-1]
    if p2.count("/") == 0 and base in CORE:
        return CORE[base]
    if p2.startswith("ui/") or p2 == "宗门首页.tscn" or p2.startswith("components/"):
        return "ui(其余页面/场景/组件)"
    if p2 == "project.godot":
        return "chore(引擎工程配置)"
    if base.endswith(".py") and "/" not in p2:
        return "chore(AI辅助脚本:修复/增强/分析/生成)"
    if base.endswith(".html"):
        return "chore(UI原型HTML)"
    if base.endswith(".md"):
        return "docs(补充设计文档)"
    if base == "whitepaper_text.txt":
        return "docs(补充设计文档)"
    if base.endswith(".txt"):
        return "chore(临时诊断/恢复报告)"
    if p2 == "theme" or p2.startswith("theme/"):
        return "chore(UI主题资源)"
    if p2 in CACHE or p2.startswith("draft_") or p2.startswith("generated-images/") or p2.startswith("_design_system/") or base.endswith(".png"):
        return "chore(生成/缓存/备份目录)"
    if base == "icon_manifest.csv":
        return "chore(根目录清单/Manifest)"
    return None

for code, p in paths:
    if code.strip() == "D":
        add("legacy(删除遗留文件)", p)
        continue
    p2 = p.rstrip("/")
    base = p2.split("/")[-1]
    # .gd.uid -> assign to its parent's group
    if base.endswith(".gd.uid"):
        stem = p2[:-4]
        grp = group_of(stem)
        if grp:
            add(grp, p)
        elif stem.startswith("ui/"):
            add("ui(其余页面/场景/组件)", p)
        else:
            add("misc(其他)", p)
        continue
    if p2 == ".group_plan.json":
        continue  # own scratch file, never commit
    grp = group_of(p2)
    if grp is None:
        add("misc(其他)", p)
    else:
        add(grp, p)

for g in groups:
    groups[g].sort()

with open(".groups.json", "w", encoding="utf-8") as f:
    json.dump(groups, f, ensure_ascii=False, indent=1)

print("TOTAL groups:", len(groups))
tot = 0
for g in sorted(groups):
    n = len(groups[g])
    tot += n
    print(f"  {n:4d}  {g}")
print("TOTAL files:", tot)
print("\n--- misc(其他) contents ---")
for p in groups.get("misc(其他)", []):
    print("   ", p)

# ---- verification: every status path covered exactly once (except own scratch) ----
covered = {}
dup = False
for g, lst in groups.items():
    for p in lst:
        if p in covered:
            print("DUPLICATE:", p, "in", covered[p], "AND", g)
            dup = True
        covered[p] = g
status_paths = set(p for _, p in paths if p != ".group_plan.json")
missing = status_paths - set(covered)
extra = set(covered) - status_paths
print("\nstatus count (excl .group_plan.json):", len(status_paths))
print("covered count:", len(covered))
print("MISSING:", sorted(missing) if missing else "none")
print("EXTRA:", sorted(extra) if extra else "none")
print("DUPLICATES:", "YES" if dup else "none")

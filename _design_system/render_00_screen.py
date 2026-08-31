# -*- coding: utf-8 -*-
"""
《太玄宗门录》00 屏规范 · 统一渲染器
================================================================
读取 `source.py` 的单一数据源（Tokens + 导航 + 资源红线），
统一渲染输出 00 屏设计系统规范文档（Markdown）。
—— 数据整合与渲染流程统一处理，Tokens 与导航逻辑合并输出。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from source import DESIGN_SYSTEM  # noqa: E402

OUT_PATH = r"E:\Xiuxian\taixuanzongmenlu\.artifacts\00_设计系统规范.md"


def _table(headers, rows):
    out = ["| " + " | ".join(headers) + " |",
           "| " + " | ".join(["---"] * len(headers)) + " |"]
    for r in rows:
        out.append("| " + " | ".join(str(c) for c in r) + " |")
    return "\n".join(out)


def render():
    ds = DESIGN_SYSTEM
    L = []

    # ---- 头部 ----
    L.append(f"# {ds['meta']['screen']} 规范（{ds['meta']['version']}）\n")
    L.append(f"> 对齐来源：{ds['meta']['alignment']}\n")
    L.append(f"> {ds['meta']['note']}\n")

    # ============================================================
    # 一、Design Tokens
    # ============================================================
    L.append("\n## 一、Design Tokens\n")

    L.append("### 1.1 色板（Color）\n")
    L.append(_table(
        ["Token", "Godot 常量", "Hex", "用途"],
        [[c["token"], f"`{c['godot']}`", c["hex"], c["use"]] for c in ds["tokens"]["color"]]
    ))

    L.append("\n### 1.2 圆角 / 描边（Radius & Border）\n")
    L.append(_table(
        ["Token", "Godot 常量", "值", "用途"],
        [[c["token"], f"`{c['godot']}`", c["value"], c["use"]] for c in ds["tokens"]["radius_border"]]
    ))

    L.append("\n### 1.3 字号阶梯（Type Scale）\n")
    L.append(_table(
        ["Token", "Godot 常量", "px", "用途"],
        [[c["token"], f"`{c['godot']}`", c["px"], c["use"]] for c in ds["tokens"]["type_scale"]]
    ))

    L.append("\n### 1.4 间距栅格（Spacing · 8px Grid）\n")
    L.append(_table(
        ["Token", "Godot 常量", "px", "用途"],
        [[c["token"], f"`{c['godot']}`", c["px"], c["use"]] for c in ds["tokens"]["spacing"]]
    ))

    L.append("\n### 1.5 图标基线（Icon Baseline）\n")
    ib = ds["tokens"]["icon_baseline"]
    L.append(f"- **风格**：{ib['style']}")
    L.append(f"- **目录**：`{ib['dir']}`")
    L.append(f"- **命名**：{ib['naming']}")
    L.append("- **顶栏资源图标**：")
    for k, v in ib["topbar_icons"].items():
        L.append(f"  - {k} → `{v}`")
    L.append(f"- **底部导航**：{ib['bottom_nav']}")
    L.append(f"- **取图**：`{ib['loader']}`")
    L.append(f"- **设计稿要求**：{ib['design_rule']}")

    # ============================================================
    # 二、导航架构（Navigation）— 与 Tokens 合并输出
    # ============================================================
    L.append("\n## 二、导航架构（Navigation）\n")
    L.append(f"> {ds['navigation']['principle']}\n")

    L.append("### 2.1 底部 5Tab（全局功能分类导航 · 管理向）\n")
    L.append(_table(
        ["Tab", "定位", "核心范围"],
        [[t["name"], t["role"], t["scope"]] for t in ds["navigation"]["bottom_tabs"]]
    ))

    L.append("\n### 2.2 侧边快捷栏（高频/沉浸入口 · 场景化）\n")
    L.append(_table(
        ["入口", "定位", "核心范围"],
        [[s["name"], s["role"], s["scope"]] for s in ds["navigation"]["side_entries"]]
    ))

    L.append("\n### 2.3 山门定位决策（升级A方案 · 2026-08-09 拍板）\n")
    sm = ds["navigation"]["shanmen"]
    L.append(f"- **决策**：{sm['decision']}")
    L.append(f"- **S1 阶段**：{sm['phase_s1']}")
    L.append(f"- **大地图阶段**：{sm['phase_map']}")
    L.append(f"- **否决 B 方案**：{sm['reject_b']}")
    L.append(f"- **否决 C 方案**：{sm['reject_c']}")
    L.append(f"- **视觉暗示**：{sm['visual_hint']}")
    L.append(f"- **铁律兼容**：{sm['combat_rule']}")
    L.append(f"- **落地节奏**：{sm['landing']}")

    # ============================================================
    # 三、资源命名红线（Resource Naming）
    # ============================================================
    L.append("\n## 三、资源命名红线（Resource Naming）\n")
    res = ds["resource"]
    L.append(f"- **已批准命名**：{ ' / '.join(res['approved']) }")
    L.append(f"- **禁止表述**：{ ' / '.join(res['banned']) }（出现即返工）")
    L.append(f"- **顶栏A方案**：{ ' / '.join(res['topbar_a']) }")
    L.append(f"- **规则**：{res['rule']}")
    L.append(f"- **红线**：{res['note']}")

    L.append("\n---\n")
    L.append("> 本规范由 `_design_system/source.py` 单一数据源生成，"
             "与 00 屏真·Tokens 模块同源同构，9 屏设计稿共享受此权威。\n")

    text = "\n".join(L)
    with open(OUT_PATH, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print("rendered ->", OUT_PATH)


if __name__ == "__main__":
    render()

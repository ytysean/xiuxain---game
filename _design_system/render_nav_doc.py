# -*- coding: utf-8 -*-
"""
《太玄宗门录》导航架构 · 独立渲染器
==================================
数据源：_design_system/source.py :: DESIGN_SYSTEM["navigation"]
（与 00 屏 Tokens 共用同一数据源，不重复维护）

输出：.artifacts/导航架构_决策.md（工程组可直接引用的路由预留清单载体）

运行：python render_nav_doc.py
"""

import os
from source import DESIGN_SYSTEM

NAV = DESIGN_SYSTEM["navigation"]
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   ".artifacts", "导航架构_决策.md")


def render() -> str:
    n = NAV
    s = n["shanmen"]
    lines = []

    lines.append("# 导航架构 · 决策文档")
    lines.append("")
    lines.append("> 数据源：`_design_system/source.py :: navigation`（单一数据源，"
                 "与 `00_设计系统规范.md` 同源，改动只动 source.py 一处）")
    lines.append("> 适用范围：9 屏设计稿 + Godot 工程路由扩展")
    lines.append("")

    # ---- 一、总原则 ----
    lines.append("## 一、导航总原则")
    lines.append("")
    lines.append(n["principle"])
    lines.append("")

    # ---- 二、底部 5Tab ----
    lines.append("## 二、底部 5Tab（全局功能分类导航 · 管理向）")
    lines.append("")
    lines.append("| Tab | 定位 | 核心范围 |")
    lines.append("| :--- | :--- | :--- |")
    for t in n["bottom_tabs"]:
        lines.append(f"| {t['name']} | {t['role']} | {t['scope']} |")
    lines.append("")

    # ---- 三、侧边 7 入口 ----
    lines.append("## 三、侧边快捷栏（高频/沉浸功能入口 · 场景化）")
    lines.append("")
    lines.append("| 入口 | 定位 | 核心范围 |")
    lines.append("| :--- | :--- | :--- |")
    for e in n["side_entries"]:
        lines.append(f"| {e['name']} | {e['role']} | {e['scope']} |")
    lines.append("")

    # ---- 四、权责对照 ----
    lines.append("## 四、导航权责对照表")
    lines.append("")
    lines.append("| 导航位置 | 定位 | 核心属性 | 典型功能 |")
    lines.append("| :--- | :--- | :--- | :--- |")
    lines.append("| 底部 5Tab | 全局功能分类导航 | 管理向、列表式 | 宗门、弟子、殿阁、历练、纪事 |")
    lines.append("| 侧边快捷栏 | 高频/沉浸功能入口 | 场景化、沉浸感 | 山门（外部探索总入口）、飞书、仙迹、规制、榜单、宗门令、坊市 |")
    lines.append("")

    # ---- 五、山门定位决策（核心） ----
    lines.append("## 五、山门定位决策（升级A方案 · 2026-08-09 拍板）")
    lines.append("")
    lines.append("### 5.1 决策结论")
    lines.append("")
    lines.append(s["decision"])
    lines.append("")
    lines.append("### 5.2 分阶段落地路径")
    lines.append("")
    lines.append("**S1 阶段（无大地图，先做功能收口）**")
    lines.append("")
    lines.append("- " + s["phase_s1"])
    lines.append("- 底部「历练」Tab 保留为快捷管理页（领奖/次数/扫荡），与山门沉浸探索互补不重叠。")
    lines.append("")
    lines.append("**大地图阶段（无缝升级）**")
    lines.append("")
    lines.append("- " + s["phase_map"])
    lines.append("- 历练关卡 / 秘境洞府 / 凡间城镇 / 敌对势力 / 己方分据点 在大地图点位化呈现。")
    lines.append("- 山门成为「宗门主城 ↔ 大世界」唯一切换枢纽。")
    lines.append("")
    lines.append("### 5.3 方案取舍说明")
    lines.append("")
    lines.append("- **放弃 B 方案**：" + s["reject_b"])
    lines.append("- **放弃 C 方案**：" + s["reject_c"])
    lines.append("")
    lines.append("### 5.4 视觉与战斗铁律")
    lines.append("")
    lines.append("- 视觉暗示：" + s["visual_hint"])
    lines.append("- 战斗铁律：" + s["combat_rule"])
    lines.append("")
    lines.append("### 5.5 设计/工程落地节奏")
    lines.append("")
    lines.append("- " + s["landing"])
    lines.append("- **工程侧路由预留**：山门入口须预留路由扩展位（S1 指向「外出探索」子页；"
                 "大地图上线后改为指向世界大地图），入口逻辑切换无需改动导航结构。")
    lines.append("")

    lines.append("---")
    lines.append("*本文档由 `render_nav_doc.py` 从 `source.py` 统一渲染，数据变更请改 source.py 后重跑渲染。*")
    lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    md = render()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="") as f:
        f.write(md)
    print("written:", OUT, "(", len(md), "chars )")

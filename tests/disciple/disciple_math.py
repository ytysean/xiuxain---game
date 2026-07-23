# -*- coding: utf-8 -*-
# disciple_math.py —— 《太玄宗门录》终局机制（P0）数值/规则镜像
# 与 disciple.gd / game_state.gd 的终局逻辑保持 1:1，供 test_disciple.py 断言回归。
# 改 Godot 端终局公式时，必须同步本文件，否则 pre_f5 闸门会抓出漂移。

# 境界序（与 disciple.gd const 境界序 一致；7 境，仙阶/道阶收尾）
境界序 = ["练气", "筑基", "金丹", "元婴", "化神", "仙阶", "道阶"]

# 资质→终身境界天花板（与 disciple.gd const 资质境界天花板 一致）
资质境界天花板 = {
    "fan_su": "金丹", "pingyong": "元婴", "youliang": "化神",
    "tiancai": "仙阶", "yaonie": "道阶", "kuangshi": "道阶",
}

# 各境界寿元基准（与 disciple.gd 境界表["寿元"] 一致；P0 沿用代码现有值）
境界寿元 = {
    "练气": 80, "筑基": 200, "金丹": 500, "元婴": 1200,
    "化神": 3000, "仙阶": 5000, "道阶": 8000,
}


def 资质上限境界(资质: str) -> str:
    return 资质境界天花板.get(资质, "道阶")


def 是否达资质上限(境界: str, 资质: str) -> bool:
    """镜像 disciple.gd::是否达资质上限()：达到上限境即封顶"""
    return 境界序.index(境界) >= 境界序.index(资质上限境界(资质))


def 尝试突破_allowed(境界: str, 资质: str) -> bool:
    """镜像 disciple.gd::尝试突破() 天花板拦截：目标境超出资质上限则返回 False（不惩罚）"""
    i = 境界序.index(境界)
    if i < 0 or i >= len(境界序) - 1:
        return False  # 已至顶阶
    目标境 = 境界序[i + 1]
    return 境界序.index(目标境) <= 境界序.index(资质上限境界(资质))


def 是否坐化(年龄: float, 寿元: int) -> bool:
    """镜像 推演一月 坐化触发条件：年龄 >= 当前境界寿元上限"""
    return 年龄 >= 寿元


def 坐化回收(弟子: dict) -> dict:
    """镜像 game_state.处理坐化() 的资产回收统计（纯函数，便于断言）：
    返回 {灵兽回收, 物品回收} 计数。"""
    灵兽回收 = 0
    if 弟子.get("主宠灵兽") is not None:
        灵兽回收 += 1
    if 弟子.get("副宠灵兽") is not None:
        灵兽回收 += 1
    物品回收 = len(弟子.get("装备", {})) + len(弟子.get("背包", []))
    return {"灵兽回收": 灵兽回收, "物品回收": 物品回收}

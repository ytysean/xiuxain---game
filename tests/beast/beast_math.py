# -*- coding: utf-8 -*-
# beast_math.py —— 灵兽数值核心公式的 Python 镜像（与 beast.gd / disciple.gd 保持同步）
#
# 本镜像对应 Godot 端：
#   beast.gd::本体战力() / disciple.gd::calc_beast_bonus() / disciple.gd::灵兽契约战力()
# 因本环境无 Godot 运行器，pre_f5_check 通过此纯 Python 镜像对边做数值红线断言，
# 防止「双槽战力 / 双层适配加成 / 本体战力 / 等级 / 忠诚度」公式被误改。
# 改 Godot 端公式时，务必同步改这里，否则断言会抓出来。
# 运行：python tests/beast/beast_math.py  （被 pre_f5_check 第 11 道闸门调用）

# ---- 与 beast.gd 对齐的常量 ----
品阶序 = ["凡阶", "灵阶", "宝阶", "王阶", "圣阶", "仙阶", "道阶"]
品阶显示 = {
    "fan_jie": "凡阶", "ling_jie": "灵阶", "bao_jie": "宝阶", "wang_jie": "王阶",
    "sheng_jie": "圣阶", "xian_jie": "仙阶", "dao_jie": "道阶",
}
品阶等级上限 = {
    "fan_jie": 10, "ling_jie": 20, "bao_jie": 30, "wang_jie": 40,
    "sheng_jie": 50, "xian_jie": 60, "dao_jie": 80,
}   # T13：等级上限按品阶锁死
# 类型 → 适配职业（attack→道修/法修；defense→体修；support→御兽师/符箓师/毒师/傀儡师）
类型适配职业 = {
    "attack": ["道修", "法修"],
    "defense": ["体修"],
    "support": ["御兽师", "符箓师", "毒师", "傀儡师"],
}
# 类型 → 本体四维属性权重（和为 1.0）：攻伐偏攻速、防御偏防血、辅助偏血速续航
类型属性权重 = {
    "attack":  {"攻": 0.40, "防": 0.15, "血": 0.20, "速": 0.25},
    "defense": {"攻": 0.10, "防": 0.40, "血": 0.30, "速": 0.20},
    "support": {"攻": 0.20, "防": 0.20, "血": 0.35, "速": 0.25},
}
战力比例 = 0.30   # beast.gd 常量：灵兽出战战力按 30% 计入弟子总战力

# 全品阶灵兽种类（镜像 beast.gd::灵兽种类，39 种）
灵兽种类 = [
    {"名": "青纹狼", "品阶": "fan_jie"}, {"名": "灵尾兔", "品阶": "fan_jie"},
    {"名": "水纹蛇", "品阶": "fan_jie"}, {"名": "火羽雀", "品阶": "fan_jie"},
    {"名": "土甲龟", "品阶": "fan_jie"}, {"名": "风翎燕", "品阶": "fan_jie"},
    {"名": "赤焰虎", "品阶": "ling_jie"}, {"名": "玄冰蟾", "品阶": "ling_jie"},
    {"名": "金毛猿", "品阶": "ling_jie"}, {"名": "青藤蛇", "品阶": "ling_jie"},
    {"名": "岩甲犀", "品阶": "ling_jie"}, {"名": "雷纹鹰", "品阶": "ling_jie"},
    {"名": "暗影狐", "品阶": "ling_jie"},
    {"名": "烈火狮", "品阶": "bao_jie"}, {"名": "碧水蛟", "品阶": "bao_jie"},
    {"名": "金翅雕", "品阶": "bao_jie"}, {"名": "木灵鹿", "品阶": "bao_jie"},
    {"名": "撼山熊", "品阶": "bao_jie"}, {"名": "冰魄狼", "品阶": "bao_jie"},
    {"名": "风刃豹", "品阶": "bao_jie"}, {"名": "紫电貂", "品阶": "bao_jie"},
    {"名": "赤焰麒麟幼崽", "品阶": "wang_jie"}, {"名": "玄水玄武幼崽", "品阶": "wang_jie"},
    {"名": "金睛蛟龙", "品阶": "wang_jie"}, {"名": "青木凤凰幼崽", "品阶": "wang_jie"},
    {"名": "戊土貔貅", "品阶": "wang_jie"}, {"名": "雷霆夔牛", "品阶": "wang_jie"},
    {"名": "八荒火龙", "品阶": "sheng_jie"}, {"名": "北冥玄龟", "品阶": "sheng_jie"},
    {"名": "九尾天狐", "品阶": "sheng_jie"}, {"名": "金翅大鹏", "品阶": "sheng_jie"},
    {"名": "建木灵神", "品阶": "sheng_jie"},
    {"名": "朱雀", "品阶": "xian_jie"}, {"名": "玄武", "品阶": "xian_jie"},
    {"名": "青龙", "品阶": "xian_jie"}, {"名": "白虎", "品阶": "xian_jie"},
    {"名": "祖龙", "品阶": "dao_jie"}, {"名": "元凤", "品阶": "dao_jie"},
    {"名": "始麒麟", "品阶": "dao_jie"},
]
# 种类 → 类型（镜像 beast.gd::种类类型）
种类类型 = {}
for _s in 灵兽种类:
    种类类型[_s["名"]] = "attack"  # 占位，下方覆盖
种类类型.update({
    "青纹狼": "attack", "灵尾兔": "support", "水纹蛇": "attack", "火羽雀": "attack", "土甲龟": "defense", "风翎燕": "attack",
    "赤焰虎": "attack", "玄冰蟾": "support", "金毛猿": "defense", "青藤蛇": "attack", "岩甲犀": "defense", "雷纹鹰": "attack", "暗影狐": "attack",
    "烈火狮": "attack", "碧水蛟": "attack", "金翅雕": "attack", "木灵鹿": "support", "撼山熊": "defense", "冰魄狼": "attack", "风刃豹": "attack", "紫电貂": "attack",
    "赤焰麒麟幼崽": "attack", "玄水玄武幼崽": "defense", "金睛蛟龙": "attack", "青木凤凰幼崽": "support", "戊土貔貅": "defense", "雷霆夔牛": "attack",
    "八荒火龙": "attack", "北冥玄龟": "defense", "九尾天狐": "support", "金翅大鹏": "attack", "建木灵神": "support",
    "朱雀": "attack", "玄武": "defense", "青龙": "attack", "白虎": "attack",
    "祖龙": "attack", "元凤": "support", "始麒麟": "defense",
})


def 本体战力(品阶key: str, beast_type: str, 神兽血脉: bool, 等级: int = 1, 等级上限: int = None) -> int:
    """镜像 beast.gd::本体战力()：品阶平方递增 + 类型微调 + 神兽血脉×1.5
    + T13等级增幅红线：单级系数=0.3/(等级上限-1)，满级(等级=上限)总增幅恰为30%，不随品阶上限放大"""
    序 = max(0, 品阶序.index(品阶显示.get(品阶key, "凡阶")))
    基准 = 60 * (序 + 1) * (序 + 1)
    类型微调 = 1.0
    if beast_type == "attack":
        类型微调 = 1.10
    elif beast_type in ("defense", "support"):
        类型微调 = 0.95
    v = int(float(基准) * 类型微调)
    if 神兽血脉:
        v = int(float(v) * 1.5)
    if 等级上限 is None:
        等级上限 = 品阶等级上限.get(品阶key, 10)
    单级 = 0.3 / max(等级上限 - 1, 1)   # 等级增幅红线：满级总增幅锁死+30%
    v = int(float(v) * (1.0 + 单级 * (等级 - 1)))
    return v


def calc_beast_bonus(beast_type: str, 天赋类型: str, 天赋关联: str,
                     弟子职业: str, 弟子灵根: str, 忠诚度: int = 50) -> float:
    """镜像 disciple.gd::calc_beast_bonus()：职业类型+20% + 灵根属性+8% + T14忠诚(忠诚/100)×8%，上限36%"""
    加成 = 0.0
    if 弟子职业 != "" and beast_type in 类型适配职业:
        if 弟子职业 in 类型适配职业[beast_type]:
            加成 += 0.20
    if 天赋类型 == "灵根" and 天赋关联 == 弟子灵根:
        加成 += 0.08
    # T14 忠诚度：满忠诚额外+8%加法叠加，忠诚0不惩罚（只加不减）
    加成 += (float(忠诚度) / 100.0) * 0.08
    return min(加成, 0.36)


def 战力贡献(本体: int, is_main: bool, is_deputy: bool) -> int:
    """镜像 beast.gd::战力贡献()：本体×战力比例×槽位比例(主1.0/副0.3/待命0)"""
    比例 = 1.0
    if is_deputy:
        比例 = 0.3
    elif not is_main:
        比例 = 0.0
    return int(float(本体) * 战力比例 * 比例)


def 灵兽契约战力(pets: list, 弟子职业: str, 弟子灵根: str) -> int:
    """镜像 disciple.gd::灵兽契约战力()：逐槽 [本体×(1+适配加成)] 后走战力贡献汇总"""
    总和 = 0
    for p in pets:
        if p is None or p["孵化中"]:
            continue
        本体 = 本体战力(p["品阶key"], p["beast_type"], p["神兽血脉"], p.get("等级", 1), p.get("等级上限"))
        加成 = calc_beast_bonus(p["beast_type"], p["天赋类型"], p["天赋关联"], 弟子职业, 弟子灵根, p.get("忠诚度", 50))
        加成后 = int(float(本体) * (1.0 + 加成))
        总和 += 战力贡献(加成后, p["is_main"], p["is_deputy"])
    return 总和


def 本体属性(品阶key: str, beast_type: str, 神兽血脉: bool, 等级: int = 1, 等级上限: int = None) -> dict:
    """镜像 beast.gd::本体属性()：将 本体战力 按类型权重拆为 攻防血速（取整求和≤本体）"""
    本 = 本体战力(品阶key, beast_type, 神兽血脉, 等级, 等级上限)
    w = 类型属性权重.get(beast_type, 类型属性权重["attack"])
    r = {}
    for _st in ["攻", "防", "血", "速"]:
        r[_st] = int(float(本) * w.get(_st, 0.0))
    return r


def 灵兽属性加成(pets: list, 弟子职业: str, 弟子灵根: str) -> dict:
    """镜像 disciple.gd::灵兽属性加成()：本体属性 × 战力比例帽(0.30) × 槽位比例(主1.0/副0.3) × 适配加成(1+bonus)，加法汇总四维"""
    聚合 = {"攻": 0, "防": 0, "血": 0, "速": 0}
    for p in pets:
        if p is None or p["孵化中"]:
            continue
        if not p["is_main"] and not p["is_deputy"]:
            continue
        槽位比例 = 1.0 if p["is_main"] else 0.3
        加成 = calc_beast_bonus(p["beast_type"], p["天赋类型"], p["天赋关联"], 弟子职业, 弟子灵根, p.get("忠诚度", 50))
        系数 = 战力比例 * 槽位比例 * (1.0 + 加成)
        本体 = 本体属性(p["品阶key"], p["beast_type"], p["神兽血脉"], p.get("等级", 1), p.get("等级上限"))
        for _st in ["攻", "防", "血", "速"]:
            聚合[_st] += int(float(本体.get(_st, 0)) * 系数)
    return 聚合


# ---- T13 等级养成（镜像 game_state::出战灵兽月度养成 等级截断）----
def 升级后等级(当前: int, 上限: int) -> int:
    """出战灵兽每月+1级，封顶等级上限"""
    return min(当前 + 1, 上限)


# ---- 老档迁移：from_dict 默认值兜底（镜像 beast.gd::from_dict 的 d.get 默认逻辑）----
def 灵兽_from_dict(d: dict) -> dict:
    """镜像 beast.gd::from_dict 的默认值兜底：老存档缺 等级/忠诚度/等级上限 字段不报错、属性无跳变"""
    品阶 = d.get("品阶", "")
    return {
        "品阶key": 品阶,
        "beast_type": d.get("beast_type", 种类类型.get(d.get("种类名", ""), "attack")),
        "神兽血脉": d.get("神兽血脉", False),
        "等级": d.get("等级", 1),
        "等级上限": d.get("等级上限", 品阶等级上限.get(品阶, 10)),
        "忠诚度": d.get("忠诚度", 50),
    }


# ---- T03 自动兑换：偏好筛选（镜像 beast.gd::随机成蛋 偏好筛选逻辑）----
def 按偏好筛选种类(品阶偏好: str = "", 类型偏好: str = "") -> list:
    """按品阶或类型偏好筛选可用灵兽种类；两者皆空返回全部"""
    候选 = 灵兽种类
    if 品阶偏好 != "":
        候选 = [s for s in 候选 if s["品阶"] == 品阶偏好]
    elif 类型偏好 != "":
        候选 = [s for s in 候选 if 种类类型.get(s["名"], "attack") == 类型偏好]
    return 候选

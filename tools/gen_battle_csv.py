# -*- coding: utf-8 -*-
# gen_battle_csv.py —— 战斗秘境数据生成器（Day1，可重跑）
# 口径对齐代码枚举：
#   境界 = 练气/筑基/金丹/元婴/化神/仙阶/道阶（disciple.gd 境界序）
#   五行 = 金/木/水/火/土（disciple.gd 灵根五行）
#   品阶 = 凡品/良品/上品/极品（drop_pool.quality）
#   槽位 = 9 槽（武器/头盔/衣袍/护腕/腰带/长裤/靴子/配饰/本命法宝）
# 产出：config/stage_main.csv + monster_main.csv + drop_pool.csv
# 第一章 10 关全量；第二/三章占位（怪物用 M2PH/M3PH/M2BOSS/M3BOSS 占位）。
import csv, os

CFG = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "config"))

# (id,name,realm,element,base_hp,base_atk,base_def,base_spd,base_crit,base_dodge,skill_id,drop_item_ids,drop_weights,is_boss,description)
monsters = [
    ("M101", "野狼", "练气", "土", 180, 18, 6, 12, 0.05, 0.02, "", "herb,eq_frag_1", "60,40", "false", "后山常见的野狼，攻击性不强"),
    ("M102", "山贼", "练气", "金", 200, 20, 8, 10, 0.05, 0.02, "", "herb,eq_frag_1", "60,40", "false", "落单的山贼，劫掠过往行人"),
    ("M103", "低阶妖兽", "练气", "木", 220, 22, 7, 9, 0.05, 0.02, "", "eq_frag_1,herb", "50,50", "false", "修炼未成的低阶妖兽"),
    ("M104", "山贼喽啰", "练气", "金", 160, 16, 6, 11, 0.04, 0.02, "", "herb", "100", "false", "山贼团伙的杂兵"),
    ("M105", "山匪头目", "练气", "金", 300, 30, 12, 11, 0.08, 0.03, "", "eq_frag_2,eq_whole_1", "60,40", "false", "后山匪帮的小头目，实力不俗"),
    ("M106", "林间精怪", "练气", "水", 210, 20, 8, 14, 0.05, 0.04, "", "herb,eq_frag_1", "70,30", "false", "山林间汇聚灵气的小妖"),
    ("M107", "矿洞石傀", "练气", "土", 260, 24, 14, 6, 0.03, 0.01, "", "eq_frag_1,mat_1", "60,40", "false", "矿洞中活化的石傀儡"),
    ("M110", "后山狼王", "练气", "土", 500, 40, 16, 13, 0.10, 0.03, "", "eq_whole_1,mat_1", "50,50", "true", "后山秘境关底BOSS，统御群狼"),
    ("M2PH", "青冥散修", "练气", "水", 500, 50, 20, 15, 0.08, 0.04, "", "eq_frag_2,herb", "50,50", "false", "古道上的散修（第二章占位）"),
    ("M2BOSS", "古道魔头", "筑基", "金", 800, 80, 32, 18, 0.12, 0.05, "", "eq_whole_1,mat_1", "50,50", "true", "青冥古道关底BOSS（占位）"),
    ("M3PH", "玄雾阴魂", "筑基", "水", 800, 80, 32, 18, 0.10, 0.04, "", "eq_frag_2,mat_1", "50,50", "false", "峡谷阴魂（第三章占位）"),
    ("M3BOSS", "峡谷亡灵将", "筑基", "土", 1250, 125, 50, 20, 0.15, 0.05, "", "eq_whole_1,mat_1", "50,50", "true", "玄雾峡谷关底BOSS（占位）"),
]
# 推荐战力 = 攻击*2 + 气血*0.5 + 防御*1.5 + 速度*3
mp = {m[0]: m[5] * 2 + m[4] * 0.5 + m[6] * 1.5 + m[7] * 3 for m in monsters}

layouts = {
    1: [("normal", "M101"), ("normal", "M102"), ("normal", "M103"), ("normal", "M101,M104"), ("elite", "M105"),
        ("treasure", ""), ("normal", "M103,M106"), ("normal", "M102,M104"), ("normal", "M107"), ("boss", "M110")],
    2: [("normal", "M2PH"), ("normal", "M2PH"), ("normal", "M2PH"), ("normal", "M2PH,M2PH"), ("elite", "M2PH"),
        ("treasure", ""), ("normal", "M2PH"), ("normal", "M2PH"), ("normal", "M2PH"), ("boss", "M2BOSS")],
    3: [("normal", "M3PH"), ("normal", "M3PH"), ("normal", "M3PH"), ("normal", "M3PH,M3PH"), ("elite", "M3PH"),
        ("treasure", ""), ("normal", "M3PH"), ("normal", "M3PH"), ("normal", "M3PH"), ("boss", "M3BOSS")],
}
stamina = {"normal": 5, "elite": 10, "treasure": 3, "boss": 15}
daily = {"normal": 0, "elite": 3, "treasure": 0, "boss": 0}
diff = {"normal": 0.9, "elite": 1.2, "treasure": 1.0, "boss": 1.8}
reward_res = {
    1: {"normal": 30, "elite": 80, "boss": 200, "treasure": 40},
    2: {"normal": 60, "elite": 120, "boss": 300, "treasure": 60},
    3: {"normal": 100, "elite": 160, "boss": 400, "treasure": 80},
}
ch_name = {1: "一", 2: "二", 3: "三"}

stages = []
for c in (1, 2, 3):
    prev = None
    for i, (nt, ms) in enumerate(layouts[c], start=1):
        sid = "S%d%02d" % (c, i)
        if c == 1 and i == 1:
            uc = "sect_level>=1"
        elif i == 1:
            uc = "sect_level>=%d;pre_stage=S%d10" % (c, c - 1)
        else:
            uc = "pre_stage=%s" % prev
        rp = int(sum(mp[x] for x in [m for m in ms.split(",") if m])) if ms else 0
        pool = "dp_ch%d_%s" % (c, nt)
        fr_num = reward_res[c][nt]
        fr_id = "spirit_stone" if nt != "treasure" else "mat_1"
        stages.append((sid, c, "第%d章%s·节点%d" % (c, ch_name[c], i), nt, uc, rp,
                       ms, stamina[nt], daily[nt], "res", fr_id, fr_num, pool, diff[nt], "true",
                       "第%d章第%d关 %s" % (c, i, nt)))
        prev = sid

with open(os.path.join(CFG, "monster_main.csv"), "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["monster_id", "monster_name", "realm", "element", "base_hp", "base_atk", "base_def",
                "base_spd", "base_crit", "base_dodge", "skill_id", "drop_item_ids", "drop_weights", "is_boss", "description"])
    for m in monsters:
        w.writerow(list(m))

with open(os.path.join(CFG, "stage_main.csv"), "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["stage_id", "chapter", "stage_name", "node_type", "unlock_condition", "recommend_power",
                "monster_ids", "stamina_cost", "daily_limit", "first_reward_type", "first_reward_id",
                "first_reward_num", "repeat_drop_pool", "difficulty_factor", "fail_reduce_enable", "designer_note"])
    for s in stages:
        w.writerow(list(s))

pools = [
    ("dp_ch1_normal", "herb", "灵植", 60, 1, 3, "凡品"), ("dp_ch1_normal", "eq_frag_1", "凡品装备碎片", 40, 1, 2, "凡品"),
    ("dp_ch1_elite", "eq_frag_2", "良品装备碎片", 50, 1, 2, "良品"), ("dp_ch1_elite", "eq_whole_1", "凡品整装", 30, 1, 1, "凡品"), ("dp_ch1_elite", "herb", "灵植", 20, 1, 2, "凡品"),
    ("dp_ch1_boss", "eq_whole_1", "凡品整装", 60, 1, 1, "凡品"), ("dp_ch1_boss", "mat_1", "灵材", 40, 1, 2, "良品"),
    ("dp_ch1_treasure", "herb", "灵植", 50, 1, 3, "凡品"), ("dp_ch1_treasure", "mat_1", "灵材", 50, 1, 1, "良品"),
    ("dp_ch2_normal", "herb", "灵植", 50, 1, 3, "凡品"), ("dp_ch2_normal", "eq_frag_2", "良品装备碎片", 50, 1, 2, "良品"),
    ("dp_ch2_elite", "eq_frag_2", "良品装备碎片", 40, 1, 2, "良品"), ("dp_ch2_elite", "eq_whole_1", "凡品整装", 40, 1, 1, "凡品"), ("dp_ch2_elite", "mat_1", "灵材", 20, 1, 1, "良品"),
    ("dp_ch2_boss", "eq_whole_1", "凡品整装", 50, 1, 1, "凡品"), ("dp_ch2_boss", "mat_1", "灵材", 50, 1, 2, "良品"),
    ("dp_ch2_treasure", "mat_1", "灵材", 50, 1, 2, "良品"), ("dp_ch2_treasure", "herb", "灵植", 50, 1, 3, "凡品"),
    ("dp_ch3_normal", "eq_frag_2", "良品装备碎片", 50, 1, 2, "良品"), ("dp_ch3_normal", "mat_1", "灵材", 50, 1, 1, "良品"),
    ("dp_ch3_elite", "eq_whole_1", "凡品整装", 40, 1, 1, "凡品"), ("dp_ch3_elite", "mat_1", "灵材", 40, 1, 2, "良品"), ("dp_ch3_elite", "eq_frag_2", "良品装备碎片", 20, 1, 2, "良品"),
    ("dp_ch3_boss", "eq_whole_1", "凡品整装", 50, 1, 1, "凡品"), ("dp_ch3_boss", "mat_1", "灵材", 50, 1, 3, "良品"),
    ("dp_ch3_treasure", "mat_1", "灵材", 60, 1, 2, "良品"), ("dp_ch3_treasure", "herb", "灵植", 40, 1, 3, "凡品"),
]
with open(os.path.join(CFG, "drop_pool.csv"), "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["pool_id", "item_id", "item_name", "weight", "min_count", "max_count", "quality"])
    for p in pools:
        w.writerow(list(p))

print("monster_main: %d rows | stage_main: %d rows | drop_pool: %d rows" % (len(monsters), len(stages), len(pools)))

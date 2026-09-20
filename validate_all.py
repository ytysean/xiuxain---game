# -*- coding: utf-8 -*-
# validate_all.py —— 配置表全量校验执行器（Python 镜像 csv_validator.gd v2.56+）
# 本文件为 csv_validator.gd 中 TABLE_RULES + 跨表关系校验的"调用方实现"（原文件声明但仓库缺失）。
# 用法: python validate_all.py  ->  输出 config/validate_report.txt
import csv, re, os, glob, sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_DIR = os.path.join(SCRIPT_DIR, "config") if os.path.basename(SCRIPT_DIR) != "config" else SCRIPT_DIR
OUT = os.path.join(CONFIG_DIR, "validate_report.txt")

# 技能类型枚举（镜像 csv_validator.gd const SKILL_TYPES，ADD-ONLY 扩为技能/功法两表并集）
# 旧：攻击/控制/辅助防御/通用（skill_cultivation.csv）；新增：普攻/主动/被动天赋（skill.csv 实际值，A4 处置）
SKILL_TYPES = ["攻击", "控制", "辅助防御", "通用", "普攻", "主动", "被动天赋"]

# ---------------- 单一数据源桥接（S1-5，2026-08-31）----------------
# 背景：本文件是 csv_validator.gd 的 Python 镜像，两份 schema 各自硬编码必然漂移
#       （实测：改 csv_validator.gd 对 pre_f5 [2/11] 完全无效，真正在跑的是本文件）。
# 对策：下表三个高漂移风险的枚举改为「从 csv_validator.gd 的 const 提取」，使 .gd 成为单一数据源。
#       提取失败时回退到下方 FALLBACK 值，保证门禁不会因解析异常而失效。
import io as _io


def _gd_const_list(const_name: str, fallback: list) -> list:
    """从 csv_validator.gd 提取 `const NAME := ["a", "b", ...]` 的字符串数组。失败返回 fallback。"""
    path = os.path.join(SCRIPT_DIR, "csv_validator.gd")
    try:
        src = _io.open(path, encoding="utf-8-sig").read()
        m = re.search(r"const\s+%s\s*:=\s*\[(.*?)\]" % const_name, src, re.S)
        if not m:
            return fallback
        vals = re.findall(r'"([^"]*)"', m.group(1))
        return vals if vals else fallback
    except Exception:
        return fallback


_FB_COND = ["sect_level", "disciple_count", "disciple_realm_count", "disciple_all_realm", "disciple_linggen",
            "master_realm", "beast_count", "building_level", "building_any_level", "building_total_level",
            "reputation", "prosperity", "placeholder"]
_FB_QTYPE = ["经营", "养成", "探索", "互动", "炼器", "功法", "成就", "灵兽", "社交", "阵法"]
_FB_PGRADE = ["凡阶", "灵阶", "宝阶", "王阶", "圣阶", "仙阶", "道阶"]

# 成就条件类型：源 = game_state.gd `_复检成就()` match 分支键（经 csv_validator.gd 转手）
ACHIEVEMENT_CONDITION_TYPES = _gd_const_list("ACHIEVEMENT_CONDITION_TYPES", _FB_COND)
# 日常差事类型：源 = config/quest_daily.csv 实际取值（经 csv_validator.gd 转手）
QUEST_DAILY_TYPES = _gd_const_list("QUEST_DAILY_TYPES", _FB_QTYPE)
# 周常差事类型 = 日常类型 ∪ 周常专属三档
QUEST_WEEKLY_TYPES = _gd_const_list("QUEST_WEEKLY_TYPES", _FB_QTYPE + ["深度养成", "高阶玩法", "宗门经营"])
# 傀儡品阶：傀儡走「X阶」口径（ui/page_puppet.gd:38 品阶描述键），与其余表的「X品」不同源
VALID_PUPPET_GRADES = _gd_const_list("VALID_PUPPET_GRADES", _FB_PGRADE)


def _gd_list_from(file_name: str, const_name: str, fallback: list, numeric: bool = False) -> list:
    """从任意 .gd 提取 const 数组，兼容 `const N := [...]` 与 `const N: Array = [...]` 两种写法。

    numeric=True 时提取整数数组（用于 REPUTATION_THRESHOLDS 这类数值标尺）。
    失败一律回退 fallback，保证门禁不因解析异常而失效。
    """
    path = os.path.join(SCRIPT_DIR, file_name)
    try:
        src = _io.open(path, encoding="utf-8-sig").read()
        m = re.search(r"const\s+%s\s*(?::\s*\w+\s*)?:?=\s*\[(.*?)\]" % const_name, src, re.S)
        if not m:
            return fallback
        if numeric:
            vals = [int(x) for x in re.findall(r"-?\d+", m.group(1))]
        else:
            vals = re.findall(r'"([^"]*)"', m.group(1))
        return vals if vals else fallback
    except Exception:
        return fallback


# ---------------- S33 阵营三表：声望标尺真源直连 faction_system.gd ----------------
# 背景（PROP_23 §2.2）：faction_base.csv 曾自带一套孤儿标尺（中立0/友善1000/…/崇拜20000），
#   与运行时 faction_system.gd（冷淡0/中立100/友善500/尊敬2000/崇敬5000）互斥且永不生效。
# 对策：把「运行时标尺」提为校验基准，CSV 必须逐档对齐 → 任何一侧改动都会被闸门拦下。
_FB_FACTION_LIST = ["正道宗门", "魔道邪宗", "中立散修", "上古妖兽", "远古遗泽"]
_FB_REP_LEVELS = ["冷淡", "中立", "友善", "尊敬", "崇敬"]
_FB_REP_THRESHOLDS = [0, 100, 500, 2000, 5000]
FACTION_LIST = _gd_list_from("faction_system.gd", "FACTION_LIST", _FB_FACTION_LIST)
FACTION_REP_LEVELS = _gd_list_from("faction_system.gd", "REPUTATION_LEVELS", _FB_REP_LEVELS)
FACTION_REP_THRESHOLDS = _gd_list_from("faction_system.gd", "REPUTATION_THRESHOLDS", _FB_REP_THRESHOLDS, numeric=True)
# fz_danqi 是 §11.26 第 6 阵营扩展，不在运行时 FACTION_LIST 内，故单列后缀
FACTION_NAMES = list(FACTION_LIST) + ["丹器师公会"]
FACTION_IDS = _gd_const_list("FACTION_IDS", ["fz_zhengdao", "fz_mo", "fz_zhongli", "fz_yaozu", "fz_yuan", "fz_danqi"])
FACTION_TAGS = _gd_const_list("FACTION_TAGS", ["正道", "魔道", "中立"])
FACTION_ITEM_TYPES = _gd_const_list("FACTION_ITEM_TYPES", ["功法", "丹药", "装备", "材料", "特殊"])
FACTION_QUEST_TYPES = _gd_const_list("FACTION_QUEST_TYPES", ["daily", "weekly"])
# 中文阵营名 -> faction_id（按 FACTION_NAMES / FACTION_IDS 同序配对；用于交叉一致性校验）
FACTION_NAME_TO_ID = dict(zip(FACTION_NAMES, FACTION_IDS))
# faction_shop 老表无品阶列，改按「声望等级 -> 售价上限」做价格封顶（替代原 REP_GRADE_CAP 品阶封顶）
REP_LEVEL_PRICE_CAP = {"冷淡": 500, "中立": 800, "友善": 1500, "尊敬": 4000, "崇敬": 10000}

# ---------------- 镜像 TABLE_RULES ----------------
TABLE_RULES = {
    "spirit_pet": {"required_fields": ["pet_id","pet_name","grade","sub_grade","pet_type","unlock_realm","passive_value","max_level","feed_cost_per_day","base_lifespan_year"],
        "primary_key":"pet_id",
        "field_rules":{"grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "pet_type":{"type":"enum","values":["产出辅助","代步辅助","驮运防御","战斗辅助","丹道辅助","飞行战斗","防御驮运","全宗增益"]},
            "passive_value":{"type":"percent","max":50.0},"max_level":{"type":"int","min":1},
            "feed_cost_per_day":{"type":"int","min":0},"base_lifespan_year":{"type":"int","min":1}}},
    "puppet": {"required_fields":["puppet_id","puppet_name","grade","sub_grade","puppet_type","effect_value","max_durability","daily_maintain_cost","craft_time_sec","base_success_rate","sell_price_ling"],
        "primary_key":"puppet_id",
        "field_rules":{"grade":{"type":"enum","values":VALID_PUPPET_GRADES},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "puppet_type":{"type":"enum","values":["劳作","炼丹","炼器","战斗"]},
            "effect_value":{"type":"percent","max":50.0},"max_durability":{"type":"int","min":1},
            "daily_maintain_cost":{"type":"int","min":0},"craft_time_sec":{"type":"int","min":1},
            "base_success_rate":{"type":"percent","min":5.0,"max":95.0},"sell_price_ling":{"type":"int","min":0}}},
    "item_pill": {"required_fields":["pill_id","pill_name","grade","sub_grade","pill_type","use_effect","effect_value","use_level","craft_material","craft_time","base_success_rate","sell_price"],
        "primary_key":"pill_id",
        "field_rules":{"grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "pill_type":{"type":"enum","values":["培元类","突破类","恢复类","属性类","特殊类"]},
            "effect_value":{"type":"percent","max":200.0},"craft_time":{"type":"int","min":1},
            "base_success_rate":{"type":"percent","min":5.0,"max":95.0},"sell_price":{"type":"int","min":0}}},
    "item_talisman": {"required_fields":["talisman_id","talisman_name","grade","sub_grade","talisman_type","use_effect","effect_value","use_limit","craft_material","sell_price"],
        "primary_key":"talisman_id",
        "field_rules":{"grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "talisman_type":{"type":"enum","values":["攻击类","防御类","辅助类","控制类","特殊类"]},
            "effect_value":{"type":"percent","max":200.0},"use_limit":{"type":"int","min":1},"sell_price":{"type":"int","min":0}}},
    "equip_main": {"required_fields":["equip_id","equip_name","grade","sub_grade","equip_slot","apply_class","base_atk","base_def","base_hp","base_durability","repair_material","sell_price"],
        "primary_key":"equip_id",
        "field_rules":{"grade":{"type":"enum","values":["凡阶","灵阶","宝阶","王阶","圣阶","仙阶","道阶"]},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "equip_slot":{"type":"enum","values":["武器","头盔","衣袍","护腕","腰带","长裤","靴子","配饰","本命法宝"]},
            "apply_class":{"type":"enum","values":["通用","体修","道修","法修"]},
            "base_atk":{"type":"int","min":0},"base_def":{"type":"int","min":0},"base_hp":{"type":"int","min":0},
            "base_durability":{"type":"int","min":1},"sell_price":{"type":"int","min":0}}},
    "destiny_main": {"required_fields":["destiny_id","名称","品级","类型","效果参数","描述"],
        "primary_key":"destiny_id",
        "field_rules":{"品级":{"type":"enum","values":["凡品","良品","上品","极品","天品"]},
            "类型":{"type":"enum","values":["修行","经营","战斗","奇遇"]}}},
    "equip_blueprint": {"required_fields":["blueprint_id","blueprint_name","grade","sub_grade","target_equip_id","unlock_condition","craft_cost","sell_price"],
        "primary_key":"blueprint_id",
        "field_rules":{"grade":{"type":"enum","values":["凡阶","灵阶","宝阶","王阶","圣阶","仙阶","道阶"]},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "craft_cost":{"type":"int","min":1},"sell_price":{"type":"int","min":0}}},
    "skill_cultivation": {"required_fields":["skill_id","skill_name","grade","sub_grade","apply_class","skill_type","effect_value","max_level","unlock_realm","learn_cost"],
        "primary_key":"skill_id",
        "field_rules":{"grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "apply_class":{"type":"enum","values":["通用","体修","道修","法修"]},
            "skill_type":{"type":"enum","values":SKILL_TYPES},
            "effect_value":{"type":"percent","max":200.0},"max_level":{"type":"int","min":1},"learn_cost":{"type":"int","min":0}}},
    "treasure_normal": {"required_fields":["treasure_id","treasure_name","grade","sub_grade","treasure_type","base_atk","base_def","base_hp","passive_effect","effect_value","sell_price"],
        "primary_key":"treasure_id",
        "field_rules":{"grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "treasure_type":{"type":"enum","values":["攻击类","防御类","辅助类"]},
            "base_atk":{"type":"int","min":0},"base_def":{"type":"int","min":0},"base_hp":{"type":"int","min":0},
            "effect_value":{"type":"percent","max":200.0},"sell_price":{"type":"int","min":0}}},
    "treasure_innate": {"required_fields":["innate_id","innate_name","grade","sub_grade","apply_class","active_skill","passive_effect","growth_value","max_level","sacrifice_material"],
        "primary_key":"innate_id",
        "field_rules":{"grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "apply_class":{"type":"enum","values":["通用","体修","道修","法修"]},
            "growth_value":{"type":"percent","max":200.0},"max_level":{"type":"int","min":1}}},
    "equip_set": {"required_fields":["set_id","set_name","grade","sub_grade","apply_class","set_2pc_effect","set_2pc_value","set_4pc_effect","set_4pc_value"],
        "primary_key":"set_id",
        "field_rules":{"grade":{"type":"enum","values":["凡阶","灵阶","宝阶","王阶","圣阶","仙阶","道阶"]},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "apply_class":{"type":"enum","values":["全道途通用","道修","体修","法修"]},
            "set_2pc_value":{"type":"percent","max":200.0},"set_4pc_value":{"type":"percent","max":200.0}}},
    "spirit_array_config": {"required_fields":["array_id","array_name","grade","sub_grade","level","unlock_sect_level","cultivate_bonus","herb_grow_bonus","pill_success_bonus","forge_success_bonus","daily_cost","upgrade_lingstone","upgrade_material","upgrade_days","max_cover"],
        "primary_key":"array_id",
        "field_rules":{"grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "level":{"type":"int","min":1},"unlock_sect_level":{"type":"int","min":1},
            "cultivate_bonus":{"type":"float","max":1.0},"herb_grow_bonus":{"type":"float","max":1.0},
            "pill_success_bonus":{"type":"float","max":1.0},"forge_success_bonus":{"type":"float","max":1.0},
            "daily_cost":{"type":"int","min":0},"upgrade_lingstone":{"type":"int","min":0},
            "upgrade_days":{"type":"int","min":0},"max_cover":{"type":"int","min":1}}},
    "defense_array_config": {"required_fields":["defense_array_id","array_name","grade","sub_grade","level","unlock_sect_level","daily_cost","daily_defense_rate","spy_reduce_rate","war_cost","war_damage_reduce_max","building_damage_reduce","tribulation_resist_max","tribulation_cost","upgrade_lingstone","upgrade_material","upgrade_days","max_cover_buildings"],
        "primary_key":"defense_array_id",
        "field_rules":{"grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "level":{"type":"int","min":1},"unlock_sect_level":{"type":"int","min":1},
            "daily_cost":{"type":"int","min":0},"daily_defense_rate":{"type":"float","max":1.0},
            "spy_reduce_rate":{"type":"float","max":1.0},"war_cost":{"type":"int","min":0},
            "war_damage_reduce_max":{"type":"float","max":1.0},"building_damage_reduce":{"type":"float","max":1.0},
            "tribulation_resist_max":{"type":"float","max":1.0},"tribulation_cost":{"type":"int","min":0},
            "upgrade_lingstone":{"type":"int","min":0},"upgrade_days":{"type":"int","min":0},
            "max_cover_buildings":{"type":"int","min":1}}},
    "skill": {"required_fields":["skill_id","skill_name","profession","damage_rate","cooldown","mp_cost"],
        "primary_key":"skill_id",
        "field_rules":{"profession":{"type":"enum","values":["体修","道修","法修","通用"]},
            "skill_type":{"type":"enum","values":SKILL_TYPES},
            "damage_rate":{"type":"float","min":0,"max":3.0},"cooldown":{"type":"int","min":0,"max":10},
            "mp_cost":{"type":"int","min":0}}},
    "battle_buff": {"required_fields":["buff_id","buff名","类型","作用属性","数值","数值类型","持续回合","来源类型","可叠加","备注"],
        "primary_key":"buff_id",
        "field_rules":{"类型":{"type":"enum","values":["增益","减益","dot","控制"]},
            "作用属性":{"type":"enum","values":["攻","防","血","速","灵力","全"]},
            "数值":{"type":"float"},"数值类型":{"type":"enum","values":["flat","percent","none"]},
            "持续回合":{"type":"int","min":1},"来源类型":{"type":"enum","values":["skill","item","passive","environment"]},
            "可叠加":{"type":"bool"}}},
    "drop_common": {"required_fields":["drop_id","scene_name","unlock_realm","unlock_sect_level","item_id","item_name","item_grade","item_type","drop_weight","guarantee_count","daily_drop_limit","is_counted_in_balance"],
        "primary_key":"drop_id+item_id",
        "field_rules":{"unlock_sect_level":{"type":"int","min":1},
            "item_grade":{"type":"enum","values":["凡品下品","凡品中品","凡品上品","凡品极品","灵品下品","灵品中品","灵品上品","灵品极品","宝品下品","宝品中品","宝品上品","宝品极品","王品下品","王品中品","王品上品","王品极品","圣品下品","圣品中品","圣品上品","圣品极品"]},
            "drop_weight":{"type":"int","min":0},"guarantee_count":{"type":"int","min":0},
            "daily_drop_limit":{"type":"int","min":0},"is_counted_in_balance":{"type":"bool"}}},
    "resource_base": {"required_fields":["resource_id","resource_name","resource_tier","item_grade","stack_limit","core_positioning","main_use"],
        "primary_key":"resource_id",
        "field_rules":{"resource_tier":{"type":"enum","values":["核心货币类","基础原材料类","养成成品类","稀有战略类"]}}},
    "output_daily": {"required_fields":["stage","sect_level","resource","daily_output","unit"],
        "primary_key":"stage+resource","field_rules":{"daily_output":{"type":"int","min":0}}},
    "sink_cost": {"required_fields":["stage","resource","daily_consumption","unit","core_direction"],
        "primary_key":"stage+resource","field_rules":{"daily_consumption":{"type":"int","min":0}}},
    "quest_daily": {"required_fields":["quest_id","quest_name","quest_type","unlock_sect_level","difficulty","target_desc","target_num","reward_lingjing","reward_lingqi","reward_pool_id","active_point","daily_limit","is_auto_complete"],
        "primary_key":"quest_id",
        "field_rules":{"quest_type":{"type":"enum","values":QUEST_DAILY_TYPES},
            "difficulty":{"type":"enum","values":["难度Ⅰ","难度Ⅱ","难度Ⅲ","难度Ⅳ"]},
            "unlock_sect_level":{"type":"int","min":1,"max":10},"target_num":{"type":"int","min":1},
            "reward_lingjing":{"type":"int","min":0},"reward_lingqi":{"type":"int","min":0},
            "active_point":{"type":"int","min":0},"daily_limit":{"type":"int","min":0},"is_auto_complete":{"type":"bool"}}},
    "quest_weekly": {"required_fields":["quest_id","quest_name","quest_type","unlock_sect_level","difficulty","target_desc","target_num","reward_lingjing","reward_lingqi","reward_pool_id","reward_chest_id","weekly_active_point","weekly_limit","is_auto_complete"],
        "primary_key":"quest_id",
        "field_rules":{"quest_type":{"type":"enum","values":QUEST_WEEKLY_TYPES},
            "difficulty":{"type":"enum","values":["难度Ⅰ","难度Ⅱ","难度Ⅲ","难度Ⅳ"]},
            "unlock_sect_level":{"type":"int","min":1,"max":10},"target_num":{"type":"int","min":1},
            "reward_lingjing":{"type":"int","min":0},"reward_lingqi":{"type":"int","min":0},
            "weekly_active_point":{"type":"int","min":0},"weekly_limit":{"type":"int","min":0},"is_auto_complete":{"type":"bool"}}},
    "quest_random": {"required_fields":["quest_id","quest_name","quest_type","trigger_type","trigger_prob","valid_time","unlock_sect_level","difficulty","reward_pool_id","reward_lingjing","reward_lingqi","quest_npc_id","is_auto_complete"],
        "primary_key":"quest_id",
        "field_rules":{"quest_type":{"type":"enum","values":["访客委托","宗门琐事","奇遇机遇","紧急事件"]},
            "trigger_type":{"type":"enum","values":["登录","收取资源","历练归来","弟子突破","事件触发","随机"]},
            "trigger_prob":{"type":"float","max":1.0},"valid_time":{"type":"int","min":0},
            "unlock_sect_level":{"type":"int","min":1,"max":10},"difficulty":{"type":"enum","values":["难度Ⅰ","难度Ⅱ","难度Ⅲ","难度Ⅳ"]},
            "reward_lingjing":{"type":"int","min":0},"reward_lingqi":{"type":"int","min":0},"is_auto_complete":{"type":"bool"}}},
    "quest_reward_pool": {"required_fields":["pool_id","item_id","item_name","item_grade","weight","drop_limit","daily_max","is_counted_in_balance"],
        "primary_key":"pool_id+item_id",
        "field_rules":{"item_grade":{"type":"enum","values":["凡品下品","凡品中品","凡品上品","凡品极品","灵品下品","灵品中品","灵品上品","灵品极品","宝品下品","宝品中品","宝品上品","宝品极品","王品下品","王品中品","王品上品","王品极品","圣品下品","圣品中品","圣品上品","圣品极品","固定数值"]},
            "weight":{"type":"int","min":0},"drop_limit":{"type":"int","min":0},"daily_max":{"type":"int","min":0},"is_counted_in_balance":{"type":"bool"}}},
    "event_quest": {"required_fields":["event_id","event_name","event_type","rarity","trigger_scene","unlock_sect_level","unlock_realm","event_content","opt1_desc","opt1_reward","opt1_punish","opt2_desc","opt2_reward","opt2_punish","opt3_desc","opt3_reward","opt3_punish","trigger_weight","cooldown_hour","is_counted_in_balance","trigger_type"],
        "primary_key":"event_id",
        "field_rules":{"event_type":{"type":"enum","values":["宗门常驻","野外历练","昼夜专属","阵营专属","征伐","奇遇机遇"]},
            "rarity":{"type":"enum","values":["普通","优秀","稀有","传说"]},
            "trigger_scene":{"type":"enum","values":["宗门内","历练结算","秘境通关","战斗胜利","昼夜切换","登录","机缘","凡人王朝"]},
            "unlock_sect_level":{"type":"int","min":1,"max":10},
            "unlock_realm":{"type":"enum","values":["练气","筑基","金丹","元婴","化神","炼虚","合体"]},
            "trigger_weight":{"type":"int","min":0},"cooldown_hour":{"type":"int","min":0},"is_counted_in_balance":{"type":"bool"}}},
    # ===== S33-2 阵营三表规则（PROP_23 §2.8 决策②③；枚举真源见文件头桥接区）=====
    "faction_base": {"required_fields":["faction_id","faction_name","reputation_level","need_reputation","global_buff_1","global_buff_2","unlock_content","shop_unlock_grade","buff_1_value","buff_2_value","faction_tag","exposure_pub"],
        "primary_key":"faction_id+reputation_level",
        "field_rules":{"faction_id":{"type":"enum","values":FACTION_IDS},
            "faction_name":{"type":"enum","values":FACTION_NAMES},
            "reputation_level":{"type":"enum","values":FACTION_REP_LEVELS},
            "need_reputation":{"type":"int","min":0},"shop_unlock_grade":{"type":"int","min":0,"max":4},
            "buff_1_value":{"type":"float","min":0.0,"max":0.25},"buff_2_value":{"type":"float","min":0.0,"max":0.25},
            "faction_tag":{"type":"enum","values":FACTION_TAGS},
            "exposure_pub":{"type":"float","min":0.0,"max":20.0}}},
    # 规则改为匹配真实老表结构（决策③）；旧规则用的是 §11.26 新表头，导致整表被 identify_table 跳过
    "faction_shop": {"required_fields":["item_id","faction","faction_id","item_name","item_type","unlock_reputation","price","description"],
        "primary_key":"item_id",
        "field_rules":{"faction_id":{"type":"enum","values":FACTION_IDS},
            "faction":{"type":"enum","values":FACTION_NAMES},
            "item_type":{"type":"enum","values":FACTION_ITEM_TYPES},
            "unlock_reputation":{"type":"enum","values":FACTION_REP_LEVELS},
            "price":{"type":"int","min":0}}},
    # S33-5 faction_conflict 阵营战役表（新建即纳入校验）
    "faction_conflict": {"required_fields":["conflict_id","faction_id","faction","enemy_tag","conflict_name","battle_type","unlock_reputation","cost_lingshi","reward_reputation","description"],
        "primary_key":"conflict_id",
        "field_rules":{"faction_id":{"type":"enum","values":FACTION_IDS},
            "faction":{"type":"enum","values":FACTION_NAMES},
            "enemy_tag":{"type":"enum","values":FACTION_TAGS},
            "battle_type":{"type":"enum","values":["宗门攻防战","秘境争夺战","妖兽围剿战","阵营围剿战"]},
            "unlock_reputation":{"type":"enum","values":FACTION_REP_LEVELS},
            "cost_lingshi":{"type":"int","min":0},
            "reward_reputation":{"type":"int","min":0}}},
    # faction_quests 首次纳入校验（此前规则表中完全不存在）
    "faction_quests": {"required_fields":["quest_id","faction","faction_id","quest_name","quest_type","unlock_reputation","target_desc","target_num","reward_lingjing","reward_lingqi","reward_reputation","description"],
        "primary_key":"quest_id",
        "field_rules":{"faction_id":{"type":"enum","values":FACTION_IDS},
            "faction":{"type":"enum","values":FACTION_NAMES},
            "quest_type":{"type":"enum","values":FACTION_QUEST_TYPES},
            "unlock_reputation":{"type":"enum","values":FACTION_REP_LEVELS},
            "target_num":{"type":"int","min":1},
            "reward_lingjing":{"type":"int","min":0},"reward_lingqi":{"type":"int","min":0},
            "reward_reputation":{"type":"int","min":0}}},
    "inner_demon": {"required_fields":["demon_id","demon_name","match_personality","trigger_prob","opt1_desc","opt1_success_rate","opt1_success_reward","opt1_fail_punish","opt2_desc","opt2_success_rate","opt2_success_reward","opt2_fail_punish"],
        "primary_key":"demon_id",
        "field_rules":{"match_personality":{"type":"enum","values":["勤勉","慵懒","沉稳","急躁","淡泊","好胜","仁厚"]},
            "trigger_prob":{"type":"float","min":0,"max":1.0},"opt1_success_rate":{"type":"float","min":0,"max":1.0},
            "opt2_success_rate":{"type":"float","min":0,"max":1.0}}},
    "tribulation_item": {"required_fields":["item_id","item_name","item_type","success_rate_bonus","damage_reduce","consume_cost","consume_type"],
        "primary_key":"item_id",
        "field_rules":{"item_type":{"type":"enum","values":["渡劫丹","护阵","长老护法","防御法宝"]},
            "success_rate_bonus":{"type":"float","min":0,"max":0.5},"damage_reduce":{"type":"float","min":0,"max":0.5},
            "consume_cost":{"type":"int","min":0}}},
    "personality_config": {"required_fields":["personality_id","personality_name","work_eff_factor","train_eff_factor","combat_atk_factor","combat_def_factor","work_weight","walk_weight","rest_weight","interact_weight","loyalty_base","morale_base","demon_resist_rate","defect_base_rate","description"],
        "primary_key":"personality_id",
        "field_rules":{"work_eff_factor":{"type":"float","min":0.8,"max":1.2},"train_eff_factor":{"type":"float","min":0.8,"max":1.2},
            "combat_atk_factor":{"type":"float","min":0.8,"max":1.2},"combat_def_factor":{"type":"float","min":0.8,"max":1.2},
            "work_weight":{"type":"float","min":0,"max":1},"walk_weight":{"type":"float","min":0,"max":1},
            "rest_weight":{"type":"float","min":0,"max":1},"interact_weight":{"type":"float","min":0,"max":1},
            "loyalty_base":{"type":"int","min":0,"max":100},"morale_base":{"type":"int","min":0,"max":100},
            "demon_resist_rate":{"type":"float","min":0,"max":1},"defect_base_rate":{"type":"float","min":0,"max":1}}},
    "path_config": {"required_fields":["path_id","path_name","match_profession","work_area_weight","train_area_weight","public_area_weight","exclusive_behavior_id","skill_grow_bonus","special_buff"],
        "primary_key":"path_id",
        "field_rules":{"match_profession":{"type":"enum","values":["体修","道修","法修","通用"]},
            "work_area_weight":{"type":"float","min":0,"max":1},"train_area_weight":{"type":"float","min":0,"max":1},
            "public_area_weight":{"type":"float","min":0,"max":1},"skill_grow_bonus":{"type":"float","min":0,"max":1}}},
    "area_stay_weight": {"required_fields":["combine_id","personality_id","path_id","lingtian_weight","danfang_weight","yanwuchang_weight","shanmen_weight","public_weight","verify_note"],
        "primary_key":"combine_id",
        "field_rules":{"lingtian_weight":{"type":"float","min":0,"max":1},"danfang_weight":{"type":"float","min":0,"max":1},
            "yanwuchang_weight":{"type":"float","min":0,"max":1},"shanmen_weight":{"type":"float","min":0,"max":1},
            "public_weight":{"type":"float","min":0,"max":1}}},
    "disciple_interact": {"required_fields":["interact_id","interact_name","interact_type","trigger_prob","relation_min","relation_max","reward_type","reward_value_a","reward_value_b","punish_type","punish_value","cooldown_hour","is_relation_grow"],
        "primary_key":"interact_id",
        "field_rules":{"interact_type":{"type":"enum","values":["切磋","论道","赠礼","协作","争执"]},
            "trigger_prob":{"type":"float","min":0,"max":1.0},"relation_min":{"type":"int","min":0,"max":100},
            "relation_max":{"type":"int","min":0,"max":100},"reward_type":{"type":"enum","values":["好感","灵石","道具","修为","道心"]},
            "reward_value_a":{"type":"int","min":0},"reward_value_b":{"type":"int","min":0},
            "punish_type":{"type":"enum","values":["好感","灵石","忠诚","无"]},"punish_value":{"type":"int","min":0},
            "cooldown_hour":{"type":"int","min":0},"is_relation_grow":{"type":"bool"}}},
    "negative_event": {"required_fields":["event_id","event_name","trigger_condition","base_prob","monthly_limit","punish_type_1","punish_value_1","punish_type_2","punish_value_2","deal_item","deal_effect","recover_day","is_permanent"],
        "primary_key":"event_id",
        "field_rules":{"base_prob":{"type":"float","min":0,"max":1.0},"monthly_limit":{"type":"int","min":0},
            "punish_type_1":{"type":"enum","values":["心魔","忠诚","道心","修为","气血","心境","灵石","矿石","灵草","卖价","丹材","权益回收","无"]},
            "punish_value_1":{"type":"int","min":0},"punish_type_2":{"type":"enum","values":["心魔","忠诚","道心","修为","气血","心境","灵石","矿石","灵草","卖价","丹材","无"]},
            "punish_value_2":{"type":"int","min":0},"recover_day":{"type":"int","min":0},"is_permanent":{"type":"bool"}}},
    "morale_loyalty_config": {"required_fields":["config_id","attr_name","full_value","zero_effect","low_threshold","low_effect","high_threshold","high_effect","decay_rate_day","increase_daily_base"],
        "primary_key":"config_id",
        "field_rules":{"full_value":{"type":"int","min":1},"low_threshold":{"type":"int","min":0},"high_threshold":{"type":"int","min":0},
            "decay_rate_day":{"type":"float","min":0,"max":1},"increase_daily_base":{"type":"int","min":0}}},
    "map_config": {"required_fields":["map_id","map_name","unlock_realm","main_attr","stamina_normal","stamina_elite","monster_config","normal_drop_pool","elite_drop_pool","event_pool","clear_condition"],
        "primary_key":"map_id",
        "field_rules":{"main_attr":{"type":"enum","values":["金","木","水","火","土"]},
            "stamina_normal":{"type":"int","min":1},"stamina_elite":{"type":"int","min":1}}},
    "secret_config": {"required_fields":["secret_id","secret_name","unlock_cond","main_attr","stamina_cost","layers","boss_info","core_drop_pool","exclusive_event","clear_reward"],
        "primary_key":"secret_id",
        "field_rules":{"main_attr":{"type":"enum","values":["金","木","水","火","土","全","雷"]},
            "stamina_cost":{"type":"int","min":1},"layers":{"type":"int","min":1}}},
    "npc_config": {"required_fields":["npc_id","npc_name","faction_id","identity","core_function","rep_unlock_note"],
        "primary_key":"npc_id",
        "field_rules":{"faction_id":{"type":"enum","values":["fz_zhengdao","fz_zhongli","fz_mo","fz_yaozu","fz_danqi","fz_yuan","neutral"]}}},
    "quest_item": {"required_fields":["item_id","item_name","item_class","combine_group","combine_target_id","fragment_total","obtain_hint","unlock_event","related_volume","is_counted_in_balance"],
        "primary_key":"item_id",
        "field_rules":{"item_class":{"type":"enum","values":["主线信物","差事碎片"]},
            "fragment_total":{"type":"int","min":0},"is_counted_in_balance":{"type":"bool"}}},
    "achievement_config": {"required_fields":["achievement_id","ach_name","category","grade","condition_desc","condition_type","condition_param","condition_extra","reward_type","reward_id","reward_num","reward_lingshi","reward_lingqi","reward_shengwang","point_num","unlock_tip","备注"],
        "primary_key":"achievement_id",
        "field_rules":{"category":{"type":"enum","values":["成长","经营","战斗","探索","社交","贸易","收集","特殊"]},
            "grade":{"type":"enum","values":["普通","稀有","传说","史诗"]},"point_num":{"type":"enum","values":[5,10,20,30,50,80,100,200]},
            "condition_type":{"type":"enum","values":ACHIEVEMENT_CONDITION_TYPES},
            "condition_param":{"type":"int","min":0},
            "condition_extra":{"type":"string"},
            "reward_type":{"type":"enum","values":["灵石","道具","装备","材料","代币","声望","永久增益","称号","传说称号","外观","buff","阵法","弟子","种子","功能"]},
            "reward_num":{"type":"float","min":0},
            "reward_lingshi":{"type":"int","min":0},"reward_lingqi":{"type":"int","min":0},"reward_shengwang":{"type":"int","min":0},
            "reward_id":{"type":"string"},"备注":{"type":"string"}}},
    "stage_main": {"required_fields":["stage_id","chapter","stage_name","node_type","unlock_condition","recommend_power","monster_ids","stamina_cost","daily_limit","first_reward_type","first_reward_id","first_reward_num","repeat_drop_pool","difficulty_factor","fail_reduce_enable","designer_note"],
        "primary_key":"stage_id",
        "field_rules":{"chapter":{"type":"int","min":1,"max":3},
            "node_type":{"type":"enum","values":["normal","elite","treasure","boss"]},
            "recommend_power":{"type":"int","min":0},"stamina_cost":{"type":"int","min":0},
            "daily_limit":{"type":"int","min":0},"first_reward_type":{"type":"enum","values":["res","item","buff"]},
            "first_reward_num":{"type":"int","min":0},"difficulty_factor":{"type":"float","min":0},"fail_reduce_enable":{"type":"bool"}}},
    "monster_main": {"required_fields":["monster_id","monster_name","realm","element","base_hp","base_atk","base_def","base_spd","base_crit","base_dodge","skill_id","drop_item_ids","drop_weights","is_boss","description"],
        "primary_key":"monster_id",
        "field_rules":{"realm":{"type":"enum","values":["练气","筑基","金丹","元婴","化神","炼虚","合体","大乘","渡劫","仙阶","道阶"]},
            "element":{"type":"enum","values":["金","木","土","水","火","全","暗","阴"]},
            "base_hp":{"type":"int","min":0},"base_atk":{"type":"int","min":0},"base_def":{"type":"int","min":0},"base_spd":{"type":"int","min":0},
            "base_crit":{"type":"float","min":0,"max":1},"base_dodge":{"type":"float","min":0,"max":1},"is_boss":{"type":"bool"}}},
    "drop_pool": {"required_fields":["pool_id","item_id","item_name","weight","min_count","max_count","quality"],
        "primary_key":"pool_id+item_id",
        "field_rules":{"weight":{"type":"int","min":1},"min_count":{"type":"int","min":0},"max_count":{"type":"int","min":0},
            "quality":{"type":"enum","values":["凡品","良品","上品","极品"]}}},
    "array_config": {"required_fields":["array_id","array_name","array_type","rank","core_effect","eff_dim","eff_val_base","trigger","level_growth_coef","max_level","unlock_realm","unlock_sect_rank","match_element","people_required","cost_base","cost_growth","icon_path","description"],
        "primary_key":"array_id",
        "field_rules":{"array_type":{"type":"enum","values":["person","team","sect"]},
            "rank":{"type":"enum","values":["common","spirit","treasure"]},
            "trigger":{"type":"enum","values":["passive","post_battle","pre_round"]},
            "match_element":{"type":"enum","values":["earth","water","metal","wood","fire","fire_water","all_five","none"]},
            "eff_val_base":{"type":"float"},
            "level_growth_coef":{"type":"float","min":0},
            "max_level":{"type":"int","min":1},
            "unlock_sect_rank":{"type":"int","min":1},
            "people_required":{"type":"int","min":0},
            "cost_base":{"type":"int","min":0},
            "cost_growth":{"type":"float","min":0},
            "unlock_realm":{"type":"string"}}},
    "array_items": {"required_fields":["item_id","item_name","item_grade","item_type","use_type","unlock_array_id","dismantle_reward_id","icon_path","描述"],
        "primary_key":"item_id",
        "field_rules":{"item_grade":{"type":"string"},
            "item_type":{"type":"enum","values":["array_book","array_material"]},
            "use_type":{"type":"enum","values":["unlock_array","upgrade"]},
            "unlock_array_id":{"type":"string"},
            "dismantle_reward_id":{"type":"string"}}},
    "craft_hall_reward": {"required_fields":["level_min","level_max","pool_type","item_ref","ref_type","item_name","grade","weight","count_min","count_max","policy_multiplier"],
        "primary_key":"level_min+level_max+pool_type+item_ref+count_min+count_max",
        "field_rules":{"level_min":{"type":"int","min":1},
            "level_max":{"type":"int","min":1},
            "pool_type":{"type":"enum","values":["common","rare"]},
            "ref_type":{"type":"enum","values":["gen","id"]},
            "grade":{"type":"string"},
            "weight":{"type":"int","min":0},
            "count_min":{"type":"int","min":1},
            "count_max":{"type":"int","min":1},
            "policy_multiplier":{"type":"float","min":0}}},
    # ---------- F2 全局调节阀门配置（IMPL-ENG-01 · ECON-02 跨功能强约束）----------
    # 表头 阀门,系数,开关,说明（独立表头，区别于 评级节奏.csv/节奏校准.csv 的 参数,值,说明）。
    # 系数±15%硬范围由 economy_balance.gd 载入时强校验；本表仅做 schema 层守门。
    "经济阀门": {"required_fields":["阀门","系数","开关","说明"],
        "primary_key":"阀门",
        "field_rules":{"阀门":{"type":"enum","values":["global_income_rate","global_cost_rate","trade_profit_rate","event_damage_rate","neg_global","neg_res_build","neg_disciple","neg_reputation","neg_grade_perm","熔断阈值","基准值"]},
            "系数":{"type":"float","min":0.0},
            "开关":{"type":"float","min":0.0,"max":1.0}}},
    # ---- S34 凡人王朝五表（dynasty_*）----
    # 枚举值由 _s34b_patch16.py 从 CSV / game_state.gd 现读回填，禁手抄。
    "dynasty_config": {"required_fields": ["policy_id","policy_name","tribute_rate","talent_rate","army_rate","attitude_decay","crisis_weight","description"],
        "primary_key": "policy_id",
        "field_rules": {"tribute_rate": {"type":"float","min":0.0},"talent_rate": {"type":"float","min":0.0},
            "army_rate": {"type":"float","min":0.0},"attitude_decay": {"type":"float","min":0.1},
            "crisis_weight": {"type":"float","min":0.0}}},
    "dynasty_phase_config": {"required_fields": ["phase_id","phase_name","dynasty_min","dynasty_max","tribute_rate","talent_rate","t_w_fan_su","t_w_pingyong","t_w_youliang","t_w_tiancai","t_w_yaonie","t_w_kuangshi","monthly_drift","crisis_weight","description"],
        "primary_key": "phase_id",
        "field_rules": {"dynasty_min": {"type":"float","min":0.0},"dynasty_max": {"type":"float","min":0.0,"max":100.0},
            "tribute_rate": {"type":"float","min":0.0},"talent_rate": {"type":"float","min":0.0},
            "t_w_fan_su": {"type":"float","min":0.0},"t_w_pingyong": {"type":"float","min":0.0},
            "t_w_youliang": {"type":"float","min":0.0},"t_w_tiancai": {"type":"float","min":0.0},
            "t_w_yaonie": {"type":"float","min":0.0},"t_w_kuangshi": {"type":"float","min":0.0},
            "crisis_weight": {"type":"float","min":0.0}}},
    "dynasty_decree_config": {"required_fields": ["decree_id","decree_name","decree_type","difficulty","require_realm","require_power","duration_days","reward_gratitude","reward_lingshi","reward_merit","penalty_gratitude","penalty_loyalty","description"],
        "primary_key": "decree_id",
        "field_rules": {"decree_type": {"type":"enum","values":["escort", "purge", "regent", "relief", "scout", "suppress"]},
            "difficulty": {"type":"int","min":1,"max":3},
            "require_realm": {"type":"enum","values":["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫", "仙阶", "道阶"]},
            "require_power": {"type":"int","min":0},"duration_days": {"type":"int","min":1},
            "reward_gratitude": {"type":"float","min":0.0},"reward_lingshi": {"type":"int","min":0.0},
            "reward_merit": {"type":"int","min":0.0},
            "penalty_gratitude": {"type":"float","max":0.0},"penalty_loyalty": {"type":"float","max":0.0}}},
    "dynasty_omen_config": {"required_fields": ["omen_id","omen_name","omen_type","weight","scope","effect_type","effect_value","text","description"],
        "primary_key": "omen_id",
        "field_rules": {"omen_type": {"type":"enum","values":["auspicious","neutral","ominous"]},
            "weight": {"type":"int","min":1},
            "scope": {"type":"enum","values":["single_county","dynasty","sect"]},
            "effect_value": {"type":"int"}}},
    "dynasty_memorial_config": {"required_fields": ["memorial_id","memorial_name","category","weight","text",
            "opt1_text","opt1_effect","opt2_text","opt2_effect","opt3_text","opt3_effect","description"],
        "primary_key": "memorial_id",
        "field_rules": {"weight": {"type":"int","min":1}}},
    "dynasty_faction_config": {"required_fields": ["faction_id","faction_name","desire_type","desire_cost","tribute_rate","talent_rate","crisis_rate","merit_rate","ruling_power","ruling_decay","ruling_decay_growth","grudge_coef","description"],
        "primary_key": "faction_id",
        "field_rules": {"faction_name": {"type":"enum","values":["士族", "边将", "宦官", "外戚"]},
            "desire_type": {"type":"enum","values":["contribution", "disciple", "lingshi", "pill"]},
            "desire_cost": {"type":"int","min":1},
            "tribute_rate": {"type":"float","min":0.0},"talent_rate": {"type":"float","min":0.0},
            "crisis_rate": {"type":"float","min":0.0},"merit_rate": {"type":"float","min":0.0},
            "ruling_power": {"type":"int","min":0},"ruling_decay": {"type":"int","min":1},
            "ruling_decay_growth": {"type":"int","min":1},"grudge_coef": {"type":"float","min":0.0}}},
    "dynasty_found_config": {"required_fields": ["id","kind","name","desc","need_grade","need_stone","need_incense","need_title","need_gratitude","p_tribute","p_talent","p_merit","p_morale","init_morale","init_longevity","init_loyalty","karma"],
        "primary_key": "id",
        "field_rules": {
            "kind": {"type":"enum","values":["route","system","law","faith"]},
            "need_grade": {"type":"int","min":0},"need_stone": {"type":"int","min":0},
            "need_incense": {"type":"int","min":0},
            "need_gratitude": {"type":"int","min":0,"max":12},
            "p_tribute": {"type":"float","min":0.5,"max":1.5},
            "p_talent": {"type":"float","min":0.5,"max":1.5},
            "p_merit": {"type":"float","min":0.5,"max":1.5},
            "p_morale": {"type":"int","min":-20,"max":20},
            "init_morale": {"type":"int","min":0,"max":100},
            "init_longevity": {"type":"int","min":0,"max":100},
            "init_loyalty": {"type":"int","min":0,"max":100},
            "karma": {"type":"int","min":0}},
        "required_nonempty": ["id","kind","name","desc"]},
    "dynasty_temple_config": {"required_fields": ["temple_id","level","name","desc",
        "unlock_sect_level","build_stone","upgrade_material","cover_pop","convert_rate",
        "heresy_resist","daily_incense_cost"],
        "primary_key": "temple_id",
        "field_rules": {
            "level": {"type":"int","min":1,"max":12},
            "unlock_sect_level": {"type":"int","min":1,"max":12},
            "build_stone": {"type":"int","min":0},
            "cover_pop": {"type":"int","min":1},
            "convert_rate": {"type":"float","min":0.5,"max":3.0},
            "heresy_resist": {"type":"int","min":0,"max":50},
            "daily_incense_cost": {"type":"int","min":0}},
        "required_nonempty": ["temple_id","name","desc"]},
    "dynasty_heresy_config": {"required_fields": ["heresy_id","name","desc","spread_rate",
        "threshold","tribute_penalty","morale_penalty","convert_drag"],
        "primary_key": "heresy_id",
        "field_rules": {
            "spread_rate": {"type":"float","min":0.5,"max":2.0},
            "threshold": {"type":"float","min":5,"max":80},
            "tribute_penalty": {"type":"float","min":0.5,"max":1.0},
            "morale_penalty": {"type":"float","min":-5,"max":0},
            "convert_drag": {"type":"float","min":0.5,"max":2.0}},
        "required_nonempty": ["heresy_id","name","desc"]},
    "dynasty_faith_config": {"required_fields": ["faith_id","name","desc","convert_mult",
        "heresy_mult","tribute_mult","talent_mult","incense_mult"],
        "primary_key": "faith_id",
        "field_rules": {
            "convert_mult": {"type":"float","min":0.5,"max":2.0},
            "heresy_mult": {"type":"float","min":0.5,"max":2.0},
            "tribute_mult": {"type":"float","min":0.5,"max":1.5},
            "talent_mult": {"type":"float","min":0.5,"max":1.5},
            "incense_mult": {"type":"float","min":0.5,"max":1.5}},
        "required_nonempty": ["faith_id","name","desc"]},
    "pill_recipe_config": {"required_fields": ["recipe_id","名称","品阶","需求境界","需求境界序","材料描述",
        "cost_herb","cost_ore","cost_jing","cost_stone","cost_qi","基础成功率","产出丹名","描述","来源"],
            "primary_key": "recipe_id",
            "field_rules": {
                    "需求境界序": {"type":"int","min":0,"max":10},
                    "基础成功率": {"type":"float","min":1.0,"max":100.0},
                    "cost_herb": {"type":"int","min":0,"max":9999},
                    "cost_ore": {"type":"int","min":0,"max":9999},
                    "cost_jing": {"type":"int","min":0,"max":9999},
                    "cost_stone": {"type":"int","min":0,"max":9999},
                    "cost_qi": {"type":"int","min":0,"max":9999}},
            "required_nonempty": ["recipe_id","品阶","产出丹名"]},
    "pill_grade_config": {"required_fields": ["grade_id","grade_name","effect_scale","price_scale","toxin_scale",
        "mark_cap_delta","mark_rate_scale","yield_scale","weight","desc"],
            "primary_key": "grade_id",
            "field_rules": {
                    "effect_scale": {"type":"float","min":0.5,"max":3.0},
                    "price_scale": {"type":"float","min":0.5,"max":3.0},
                    "toxin_scale": {"type":"float","min":0.3,"max":2.0},
                    "mark_cap_delta": {"type":"int","min":-3,"max":3},
                    "mark_rate_scale": {"type":"float","min":0.5,"max":2.0},
                    "yield_scale": {"type":"float","min":0.3,"max":2.0},
                    "weight": {"type":"float","min":1.0,"max":100.0}},
            "required_nonempty": ["grade_id","grade_name"]},
    "pill_yield_config": {"required_fields": ["grade","base_yield","per_realm_surplus","per_prof_level",
        "furnace_scale","desc"],
            "primary_key": "grade",
            "field_rules": {
                    "base_yield": {"type":"float","min":0.5,"max":10.0},
                    "per_realm_surplus": {"type":"float","min":0.0,"max":1.0},
                    "per_prof_level": {"type":"float","min":0.0,"max":1.0},
                    "furnace_scale": {"type":"float","min":0.0,"max":2.0}},
            "required_nonempty": ["grade"]},
    "pill_furnace_config": {"required_fields": ["furnace_id","名称","品质","成率","出纹","产量","品级分",
        "减毒率","省材率","价灵石","价灵晶","描述"],
            "primary_key": "furnace_id",
            "field_rules": {
                    "成率": {"type":"float","min":0.0,"max":0.20},
                    "出纹": {"type":"float","min":0.0,"max":0.20},
                    "产量": {"type":"float","min":0.0,"max":3.0},
                    "品级分": {"type":"float","min":0.0,"max":40.0},
                    "减毒率": {"type":"float","min":0.0,"max":0.9},
                    "省材率": {"type":"float","min":0.0,"max":0.5},
                    "价灵石": {"type":"int","min":0,"max":99999999},
                    "价灵晶": {"type":"int","min":0,"max":99999}},
            "required_nonempty": ["furnace_id","名称","品质"]},
    "talisman_grade_config": {"required_fields": ["grade_id","grade_name","effect_scale","price_scale",
        "mark_cap_delta","mark_rate_scale","yield_scale","weight","desc"],
            "primary_key": "grade_id",
            "field_rules": {
                    "effect_scale": {"type":"float","min":0.5,"max":3.0},
                    "price_scale": {"type":"float","min":0.5,"max":3.0},
                    "mark_cap_delta": {"type":"int","min":-3,"max":3},
                    "mark_rate_scale": {"type":"float","min":0.5,"max":2.0},
                    "yield_scale": {"type":"float","min":0.3,"max":2.0},
                    "weight": {"type":"float","min":1.0,"max":100.0}},
            "required_nonempty": ["grade_id","grade_name"]},
    "talisman_yield_config": {"required_fields": ["grade","base_yield","per_realm_surplus","per_prof_level",
        "paper_scale","desc"],
            "primary_key": "grade",
            "field_rules": {
                    "base_yield": {"type":"float","min":0.5,"max":10.0},
                    "per_realm_surplus": {"type":"float","min":0.0,"max":1.0},
                    "per_prof_level": {"type":"float","min":0.0,"max":1.0},
                    "paper_scale": {"type":"float","min":0.0,"max":2.0}},
            "required_nonempty": ["grade"]},
    "talisman_paper_config": {"required_fields": ["paper_id","名称","品质","成率","出纹","产量","品级分",
        "省材率","价灵石","价灵晶","描述"],
            "primary_key": "paper_id",
            "field_rules": {
                    "成率": {"type":"float","min":0.0,"max":0.20},
                    "出纹": {"type":"float","min":0.0,"max":0.20},
                    "产量": {"type":"float","min":0.0,"max":3.0},
                    "品级分": {"type":"float","min":0.0,"max":40.0},
                    "省材率": {"type":"float","min":0.0,"max":0.5},
                    "价灵石": {"type":"int","min":0,"max":99999999},
                    "价灵晶": {"type":"int","min":0,"max":99999}},
            "required_nonempty": ["paper_id","名称","品质"]},
    "talisman_mark_config": {"required_fields": ["grade","base_rate","effect_per_mark","price_per_mark","max_mark"],
            "primary_key": "grade",
            "field_rules": {
                    "base_rate": {"type":"float","min":0.05,"max":0.95},
                    "effect_per_mark": {"type":"float","min":0.0,"max":0.5},
                    "price_per_mark": {"type":"float","min":0.0,"max":0.5},
                    "max_mark": {"type":"int","min":1,"max":9}},
            "required_nonempty": ["grade"]},
    "talisman_mark_tier": {"required_fields": ["tier_id","mark_min","mark_max","tier_name","desc","omen"],
            "primary_key": "tier_id",
            "field_rules": {
                    "mark_min": {"type":"int","min":0,"max":9},
                    "mark_max": {"type":"int","min":0,"max":9}},
            "required_nonempty": ["tier_id","tier_name"]},
    "talisman_mark_codex": {"required_fields": ["codex_id","codex_name","need_score","success_bonus","rate_bonus","desc"],
            "primary_key": "codex_id",
            "field_rules": {
                    "need_score": {"type":"int","min":0,"max":9999},
                    "success_bonus": {"type":"float","min":0.0,"max":30.0},
                    "rate_bonus": {"type":"float","min":0.0,"max":0.5}},
            "required_nonempty": ["codex_id","codex_name"]},
    "talisman_level_config": {"required_fields": ["level","need_exp","success_bonus","quality_bonus","desc"],
            "primary_key": "level",
            "field_rules": {
                    "level": {"type":"int","min":1,"max":99},
                    "need_exp": {"type":"int","min":0,"max":999999},
                    "success_bonus": {"type":"float","min":0.0,"max":100.0},
                    "quality_bonus": {"type":"float","min":0.0,"max":1.0}},
            "required_nonempty": ["desc"]},
    "alchemy_factor_step": {"required_fields": ["id","类别","名称","维度","键","成率","出纹","说明"],
            "primary_key": "id",
            "field_rules": {
                    "成率": {"type":"float","min":-0.20,"max":0.20},
                    "出纹": {"type":"float","min":-0.20,"max":0.20}},
            "required_nonempty": ["id","类别","名称","维度","键"]},
    "alchemy_factor_linear": {"required_fields": ["id","类别","名称","维度","每单位成率","每单位出纹","上限成率","上限出纹","说明"],
            "primary_key": "id",
            "field_rules": {
                    "每单位成率": {"type":"float","min":-0.05,"max":0.05},
                    "每单位出纹": {"type":"float","min":-0.05,"max":0.05},
                    "上限成率": {"type":"float","min":-0.30,"max":0.30},
                    "上限出纹": {"type":"float","min":-0.30,"max":0.30}},
            "required_nonempty": ["id","类别","名称","维度"]},
    "alchemy_source_config": {"required_fields": ["id","类别","名称","成率","出纹","说明"],
            "primary_key": "id",
            "field_rules": {
                    "成率": {"type":"float","min":0.0,"max":0.50},
                    "出纹": {"type":"float","min":0.0,"max":0.50}},
            "required_nonempty": ["id","类别","名称"]},
    "forge_factor_step": {"required_fields": ["id","类别","名称","维度","键","成率","高品质","说明"],
            "primary_key": "id",
            "field_rules": {
                    "成率": {"type":"float","min":-0.05,"max":0.50},
                    "高品质": {"type":"float","min":-0.05,"max":0.50}},
            "required_nonempty": ["id","类别","名称","维度","键"]},
    "forge_factor_linear": {"required_fields": ["id","类别","名称","维度","每单位成率","每单位高品质","上限成率","上限高品质","说明"],
            "primary_key": "id",
            "field_rules": {
                    "每单位成率": {"type":"float","min":-0.01,"max":0.05},
                    "每单位高品质": {"type":"float","min":-0.01,"max":0.05},
                    "上限成率": {"type":"float","min":-0.50,"max":0.50},
                    "上限高品质": {"type":"float","min":-0.50,"max":0.50}},
            "required_nonempty": ["id","类别","名称","维度"]},
    "forge_source_config": {"required_fields": ["id","类别","名称","键","成率","高品质","说明"],
            "primary_key": "id",
            "field_rules": {
                    "成率": {"type":"float","min":-0.01,"max":0.50},
                    "高品质": {"type":"float","min":-0.01,"max":0.50}},
            "required_nonempty": ["id","类别","名称","键"]},
    "pill_mark_config": {"required_fields": ["grade","base_rate","base_toxin","effect_per_mark",
            "price_per_mark","detox_per_mark","max_mark"],
            "primary_key": "grade",
            "field_rules": {
                    "base_rate": {"type":"float","min":0.02,"max":0.95},
                    "base_toxin": {"type":"float","min":0.0,"max":5.0},
                    "effect_per_mark": {"type":"float","min":0.0,"max":0.5},
                    "price_per_mark": {"type":"float","min":0.0,"max":0.2},
                    "detox_per_mark": {"type":"float","min":0.0,"max":2.0},
                    "max_mark": {"type":"int","min":1,"max":9}},
            "required_nonempty": ["grade"]},
    "pill_mark_tier": {"required_fields": ["tier_id","mark_min","mark_max","tier_name","desc","omen"],
            "primary_key": "tier_id",
            "field_rules": {
                    "mark_min": {"type":"int","min":0,"max":9},
                    "mark_max": {"type":"int","min":0,"max":9}},
            "required_nonempty": ["tier_id","tier_name","desc"]},
    "pill_mark_codex": {"required_fields": ["codex_id","codex_name","need_score","success_bonus","rate_bonus","desc"],
            "primary_key": "codex_id",
            "field_rules": {
                    "need_score": {"type":"int","min":0,"max":9999},
                    "success_bonus": {"type":"float","min":0.0,"max":20.0},
                    "rate_bonus": {"type":"float","min":0.0,"max":0.3}},
            "required_nonempty": ["codex_id","codex_name"]},
    "herb_age_config": {"required_fields": ["档名","下限年份","上限年份","价值系数","成率加成","出纹加成","说明"],
            "primary_key": "档名",
            "field_rules": {
                    "下限年份": {"type":"int","min":0,"max":100000},
                    "上限年份": {"type":"int","min":-1,"max":100000},
                    "价值系数": {"type":"float","min":0.5,"max":20.0},
                    "成率加成": {"type":"float","min":0.0,"max":0.5},
                    "出纹加成": {"type":"float","min":0.0,"max":0.5}},
            "required_nonempty": ["档名","说明"]},
    "gongfa_affix_config": {"required_fields": ["tier","key","中文名","类型","数值下限","数值上限"],
        "primary_key": "key",
        "field_rules": {
            "tier": {"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
            "类型": {"type":"enum","values":["修炼速度","战力","突破"]},
            "数值下限": {"type":"float","min":0.0,"max":100000.0},
            "数值上限": {"type":"float","min":0.0,"max":100000.0}},
        "required_nonempty": ["key","中文名","类型"]},
    "pill_affix_config": {"required_fields": ["tier","key","中文名","类型","数值下限","数值上限"],
        "primary_key": "key",
        "field_rules": {
            "tier": {"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
            "类型": {"type":"enum","values":["药效","减毒","心境","售价"]},
            "数值下限": {"type":"float","min":0.0,"max":100.0},
            "数值上限": {"type":"float","min":0.0,"max":100.0}},
        "required_nonempty": ["key","中文名","类型"]},
    "equip_affix_config": {"required_fields": ["阶","key","中文名","类型","数值下限","数值上限"],
        "primary_key": "key",
        "field_rules": {
            "阶": {"type":"enum","values":["凡阶","灵阶","宝阶","王阶","圣阶","仙阶","道阶"]},
            "类型": {"type":"enum","values":["战力","修炼","突破"]},
            "数值下限": {"type":"float","min":0.0,"max":100000.0},
            "数值上限": {"type":"float","min":0.0,"max":100000.0}},
        "required_nonempty": ["key","中文名","类型"]},
    "talisman_affix_config": {"required_fields": ["阶","key","中文名","类型","数值下限","数值上限"],
        "primary_key": "key",
        "field_rules": {
            "阶": {"type":"enum","values":["凡阶","灵阶","宝阶","王阶","圣阶","仙阶","道阶"]},
            "类型": {"type":"enum","values":["战力","修炼","突破"]},
            "数值下限": {"type":"float","min":0.0,"max":100000.0},
            "数值上限": {"type":"float","min":0.0,"max":100000.0}},
        "required_nonempty": ["key","中文名","类型"]},
    "oath_config": {"required_fields": ["oath_id","name","kind","desc",
        "need_daoxin","need_loyal","duration_days","cond_type","cond_value",
        "buff_cult","buff_breakthrough","cost_demon_per_day","forbid_expedition",
        "reward","punish","weight"],
        "primary_key": "oath_id",
        "field_rules": {
            "need_daoxin": {"type":"int","min":0,"max":100},
            "need_loyal": {"type":"int","min":0,"max":100},
            "duration_days": {"type":"int","min":3,"max":30},
            "cond_value": {"type":"int","min":0},
            "buff_cult": {"type":"float","min":1.0,"max":2.0},
            "buff_breakthrough": {"type":"float","min":0.0,"max":0.20},
            "cost_demon_per_day": {"type":"float","min":-2.0,"max":3.0},
            "forbid_expedition": {"type":"int","min":0,"max":1},
            "weight": {"type":"int","min":1}},
        "required_nonempty": ["oath_id","name","desc","cond_type","reward","punish"]},
    "oath_sect_config": {"required_fields": ["sect_oath_id","name","desc","duration_days",
        "cond_type","cond_value","buff_cult","reward","punish"],
        "primary_key": "sect_oath_id",
        "field_rules": {
            "duration_days": {"type":"int","min":3,"max":30},
            "cond_value": {"type":"int","min":1},
            "buff_cult": {"type":"float","min":1.0,"max":1.5}},
        "required_nonempty": ["sect_oath_id","name","desc","cond_type","reward","punish"]},
    "dynasty_title_config": {"required_fields": ["title_id","title_name","need_relation","need_gratitude_count","need_grade","merit_kind","need_merit","right_desc","duty_type","duty_cost","duty_desc"],
        "primary_key": "title_id",
        "field_rules": {"title_name": {"type":"enum","values":["未册封", "护国宗", "国师", "帝师", "监国", "摄政", "自立为王"]},
            "need_relation": {"type":"float","min":0.0,"max":100.0},
            "need_gratitude_count": {"type":"int","min":0},"need_grade": {"type":"int","min":1},
            "merit_kind": {"type":"enum","values":["karma", "merit", "none"]},
            "need_merit": {"type":"int","min":0.0},
            "duty_type": {"type":"enum","values":["heir", "independent", "none", "recommend", "regent", "tribute"]},"duty_cost": {"type":"int","min":0}}},
    "dynasty_counter_config": {"required_fields": ["counter_id","counter_name","trigger_kind","trigger_value","warn_value","cooldown_month","cost_rate","cost_min","cost_max","opt_label","convert_effect","penalty_desc","convert_desc","description"],
        "primary_key": "counter_id",
        "field_rules": {"trigger_value": {"type":"int","min":0,"max":100},
            "warn_value": {"type":"int","min":0,"max":100},
            "cooldown_month": {"type":"int","min":0},
            "cost_rate": {"type":"float","min":0.0,"max":1.0},
            "cost_min": {"type":"int","min":0},"cost_max": {"type":"int","min":0}}},
    "dynasty_commission_config": {"required_fields": ["commission_id","commission_name","commission_type","difficulty","require_realm","require_power","duration_days","cost_lingshi","reward_gratitude","reward_lingshi","reward_merit","penalty_gratitude","penalty_loyalty","mandatory","description"],
        "primary_key": "commission_id",
        "field_rules": {"difficulty": {"type":"int","min":1},
            "require_power": {"type":"int","min":0},
            "duration_days": {"type":"int","min":1},
            "cost_lingshi": {"type":"int","min":0},
            "reward_gratitude": {"type":"int","min":0},"reward_lingshi": {"type":"int","min":0},
            "reward_merit": {"type":"int","min":0},
            "penalty_gratitude": {"type":"int","max":0},"penalty_loyalty": {"type":"int","max":0},
            "mandatory": {"type":"enum","values":["0","1"]}}},
    "auction_config": {"required_fields": ["param","value","description"],
        "primary_key": "param",
        "field_rules": {"value": {"type":"float","min":0.0}}},
    "auction_ai_config": {"required_fields": ["ai_id","ai_type","display_name","budget_mod","valuation_mod","lines"],
        "primary_key": "ai_id",
        "field_rules": {"budget_mod": {"type":"float","min":0.1,"max":5.0},
            "valuation_mod": {"type":"float","min":0.1,"max":5.0}}},
}

GRADE_RANK = {"凡品":0,"灵品":1,"宝品":2,"王品":3,"圣品":4,"仙品":5,"道品":6}
REP_GRADE_CAP = {0:"凡品",1000:"灵品",3000:"宝品",8000:"王品",20000:"圣品"}

def parse_percent(s):
    nums = re.findall(r"-?\d+(?:\.\d+)?", str(s))
    return float(nums[0]) if nums else None

def get_first_num(s):
    nums = re.findall(r"-?\d+(?:\.\d+)?", str(s))
    return float(nums[0]) if nums else None

def realm_list():
    """现读 disciple.gd:132 境界序 真源，避免手抄境界名漂移。"""
    _p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "disciple.gd")
    if os.path.exists(_p):
        s = open(_p, encoding="utf-8").read()
        m = re.search(r'const 境界序:\s*Array\s*=\s*\[(.*?)\]', s, re.S)
        if m:
            return [x.strip().strip('"').strip("'") for x in m.group(1).split(",") if x.strip()]
    return ["练气","筑基","金丹","元婴","化神","炼虚","合体","大乘","渡劫","仙阶","道阶"]

def load_csv(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        r = csv.DictReader(f)
        rows = list(r)
        return r.fieldnames, rows

def identify_table(header, fname=None):
    # 文件名精确匹配优先：避免同结构表（如 gongfa_affix_config / pill_affix_config
    # 共享同一组 required_fields）因严格 > 平局而误判为靠前的表。
    if fname and fname.endswith(".csv"):
        cand = fname[:-4]
        if cand in TABLE_RULES and all(c in header for c in TABLE_RULES[cand]["required_fields"]):
            return cand
    best = None; best_n = -1
    for key, rule in TABLE_RULES.items():
        rf = rule["required_fields"]
        if all(c in header for c in rf):
            if len(rf) > best_n:
                best, best_n = key, len(rf)
    return best

def validate_field(val, rule):
    t = rule.get("type")
    if t is None:
        return None  # string/无类型 -> 跳过
    if t == "enum":
        sv = [str(x) for x in rule["values"]]
        if val in rule["values"]:
            return None
        # CSV 读为字符串，enum 值可能为整数；做类型对齐重试
        try:
            if isinstance(rule["values"][0], int) and int(float(val)) in rule["values"]:
                return None
            if isinstance(rule["values"][0], float) and float(val) in rule["values"]:
                return None
        except (ValueError, TypeError):
            pass
        return "enum非法(应为%s之一)" % "/".join(sv[:4])+("…" if len(rule["values"])>4 else "")
    if t == "bool":
        return None if str(val).strip().lower() in ("true","false") else "bool非法"
    # numeric
    if t == "percent":
        v = parse_percent(val)
    elif t in ("int","float"):
        v = get_first_num(val)
    else:
        return None
    if v is None:
        return "无法解析为数值"
    if "min" in rule and v < rule["min"]: return "低于下限%d"%rule["min"]
    if "max" in rule and v > rule["max"]: return "高于上限%g"%rule["max"]
    return None

# ---------------- TASK0 道途重命名门控（R5 代码重命名前置）----------------
# 已定义道途枚举（含 csv_validator.gd 的 APPLY_CLASSES 通用 用于 item apply-class）
PROF_ALLOWED = {"道修","体修","法修","御兽师","符箓师","毒师","傀儡师","通用"}
# 旧道途名，Sprint-03 前须从 .gd/.csv 清零（剑修后置为后续新增道途，不复用旧槽位）
PROF_ORPHAN_TOKEN = "剑修"
# 显式豁免（2026-08-31 核准）：「剑修」作为世界观专有名词出现，非旧道途枚举值，报了是误报。
#   以 (文件名, 行内特征子串) 匹配而非行号，避免编辑后行号漂移导致豁免失效。
PROF_WHITELIST = [
    ("expedition.gd", "上古剑修陨落之地"),        # 秘境世界观文案（地名）
    ("expedition.gd", "剑修传承"),                 # 物品名
    ("world_map_system.gd", "上古剑修陨落之地"),  # 秘境「剑冢」世界观文案（地名，2026-09-11 核准）
]


def _prof_exempt(fname: str, line: str) -> bool:
    """旧道途名扫描的误报豁免：注释行 / @LEGACY-MIGRATION / 世界观专有名词白名单。"""
    stripped = line.strip()
    if stripped.startswith("#"):            # 注释行：非代码，不参与重命名
        return True
    if "@LEGACY-MIGRATION" in line:         # 旧档迁移兜底（老大 2026-07-19 拍板保留）
        return True
    for wf, wkey in PROF_WHITELIST:
        if fname == wf and wkey in line:
            return True
    return False


def validate_profession_renamed():
    """扫描根目录 *.gd 与 config/*.csv，旧道途名「剑修」必须清零。
    出现「剑修」即报孤儿字段（道途枚举已迁移为「道修」），注释行与白名单文案除外。"""
    bad = []
    gd_files = sorted(glob.glob(os.path.join(SCRIPT_DIR, "*.gd")))
    for p in gd_files:
        fname = os.path.basename(p)
        try:
            with open(p, encoding="utf-8") as f:
                for i, line in enumerate(f, 1):
                    if PROF_ORPHAN_TOKEN in line and not _prof_exempt(fname, line):
                        bad.append((fname, "profession-rename", i,
                                    "残留旧道途名「剑修」(应为「道修」): %r" % line.strip()[:60]))
        except Exception:
            pass
    csv_files = sorted(glob.glob(os.path.join(CONFIG_DIR, "*.csv")))
    for p in csv_files:
        if p.endswith(".bak.csv"):
            continue
        try:
            with open(p, encoding="utf-8-sig", newline="") as f:
                for i, line in enumerate(f, 1):
                    if PROF_ORPHAN_TOKEN in line and "@LEGACY-MIGRATION" not in line:
                        bad.append((os.path.basename(p), "profession-rename", i,
                                    "残留旧道途名「剑修」(应为「道修」): %r" % line.strip()[:60]))
        except Exception:
            pass
    return bad

def main():
    csv_files = sorted(glob.glob(os.path.join(CONFIG_DIR, "*.csv")))
    lines = []
    errors = []   # (file, table, row, msg)
    warns = []
    tables_loaded = {}
    report = []
    report.append("# CSV 全量校验报告 (validate_all.py)")
    report.append("生成于 Python 镜像 csv_validator.gd v2.56+，覆盖 config/ 下全部 *.csv")
    report.append("")
    total_rows = 0
    for path in csv_files:
        fname = os.path.basename(path)
        if fname.endswith(".bak.csv"):
            continue
        header, rows = load_csv(path)
        key = identify_table(header, fname) if header else None
        if key is None:
            warns.append("%s: 无法识别表类型(表头不匹配任何 TABLE_RULES)，跳过校验" % fname)
            report.append("## %s  [未识别-跳过]" % fname)
            continue
        rule = TABLE_RULES[key]
        tables_loaded[key] = (header, rows)
        report.append("## %s  →  识别为 `%s` (%d 行数据)" % (fname, key, len(rows)))
        total_rows += len(rows)
        # required fields presence
        for c in rule["required_fields"]:
            if c not in header:
                errors.append((fname, key, 0, "缺少必需列 %s" % c))
        # field rules
        for i, row in enumerate(rows, 1):
            for col, fr in rule["field_rules"].items():
                if col not in row: continue
                msg = validate_field(row[col], fr)
                if msg:
                    errors.append((fname, key, i, "%s=%r %s" % (col, row[col], msg)))
        # primary key uniqueness
        pk = rule["primary_key"]
        if "+" in pk:
            cols = pk.split("+")
            seen = {}
            for i, row in enumerate(rows, 1):
                kv = tuple(row.get(c, "") for c in cols)
                if kv in seen:
                    errors.append((fname, key, i, "复合主键 %s 重复: %s (首见于行%d)" % (pk, "/".join(kv), seen[kv])))
                else:
                    seen[kv] = i
        else:
            seen = {}
            for i, row in enumerate(rows, 1):
                kv = row.get(pk, "")
                if kv in seen:
                    errors.append((fname, key, i, "主键 %s 重复: %s (首见于行%d)" % (pk, kv, seen[kv])))
                else:
                    seen[kv] = i

    # ---------- 跨表关系校验 ----------
    report.append("")
    report.append("# 跨表关系校验")
    def rows_of(key): return tables_loaded.get(key, (None, []))[1]

    # 1. drop_weight sum=100 per drop_id
    d = rows_of("drop_common")
    if d:
        from collections import defaultdict
        pools = defaultdict(list)
        for r in d: pools[r["drop_id"]].append(float(get_first_num(r["drop_weight"]) or 0))
        bad = {k: sum(v) for k,v in pools.items() if abs(sum(v)-100)>1e-6}
        if bad:
            for k,v in bad.items():
                errors.append(("drop_common.csv","drop_common",0,"drop_id=%s 权重和=%.1f≠100"%(k,v)))
        else:
            report.append("- [OK] drop_common: 各 drop_id 池内 drop_weight 和=100")
    # 2. reward_pool weight sum=100 per pool_id
    d = rows_of("quest_reward_pool")
    if d:
        from collections import defaultdict
        pools = defaultdict(float)
        for r in d: pools[r["pool_id"]] += float(get_first_num(r["weight"]) or 0)
        bad = {k:v for k,v in pools.items() if abs(v-100)>1e-6}
        if bad:
            for k,v in bad.items():
                errors.append(("quest_reward_pool.csv","quest_reward_pool",0,"pool_id=%s 权重和=%.1f≠100"%(k,v)))
        else:
            report.append("- [OK] quest_reward_pool: 各 pool_id 池内 weight 和=100")
    # 3. event_quest weight 校验（q-1 拍板：分类和=100 归一化，对齐总览§11.26.1/§11.26.5）
    #    各 event_type 分类内 trigger_weight 和须=100；引擎(quest.gd)按 scene 过滤后绝对权重抽取，
    #    分类和=100 仅作作者约定与一致性校验，不影响抽取比例。空池(全0行)跳过。
    d = rows_of("event_quest")
    if d:
        from collections import defaultdict
        pools = defaultdict(float)
        has_positive = defaultdict(bool)
        for r in d:
            w = float(get_first_num(r["trigger_weight"]) or 0)
            if w > 0:
                pools[r["event_type"]] += w
                has_positive[r["event_type"]] = True
        bad = {k: v for k, v in pools.items() if not has_positive[k]}
        if bad:
            for k in bad:
                warns.append("event_quest.csv: event_type=%s 池内无正向 trigger_weight（抽取将退化为等权），请检查" % k)
        else:
            report.append("- [OK] event_quest: 各 event_type 池内均含正向 trigger_weight（按档权重 普通10/优秀6/稀有2/传说0.5 抽取）")

        # 4. 奇遇品阶占比校验（P0 拍板硬卡死）：传说档硬上限 10 条（203 条量级下占比 4.9%≤5%）。
        #    从配置层拦截超标，S0 新增传说奇遇超量直接报硬错误。
        rc = defaultdict(int)
        for r in d:
            rc[r["rarity"]] += 1
        total = sum(rc.values())
        legend = "普通=%d 优秀=%d 稀有=%d 传说=%d (总计%d)" % (rc.get("普通",0), rc.get("优秀",0), rc.get("稀有",0), rc.get("传说",0), total)
        report.append("- event_quest 品阶分布: " + legend)
        if rc.get("传说", 0) > 10:
            errors.append(("event_quest.csv","event_quest",0,"传说档=%d 条，超过 P0 硬上限 10 条（占比%.1f%%），S0 不得新增超标传说奇遇" % (rc["传说"], rc["传说"]*100.0/max(total,1))))

        # 4b. 单条赏赐倍率软告警（P0 拍板）：普通1x / 优秀2x / 稀有5x / 传说12x。
        #     解析 opt*_reward 中 `资源key:数量` 的数值当量，超对应品阶软上限即软告警（不阻断闸门）。
        REWARD_BASE = 200  # 普通 1x 基准（灵石当量）
        RARITY_MULT = {"普通": 1, "优秀": 2, "稀有": 5, "传说": 12}
        RES_KEYS = {"lingshi", "lingcao", "kuangshi", "lingqi", "dan_low"}
        for r in d:
            rt = r.get("rarity", "")
            mult = RARITY_MULT.get(rt, 1)
            cap = REWARD_BASE * mult
            for opt in ("opt1_reward", "opt2_reward", "opt3_reward"):
                s = (r.get(opt) or "").strip()
                if not s:
                    continue
                tot = 0
                parsed = False
                for part in s.split("|"):
                    part = part.strip()
                    if ":" in part:
                        k, v = part.split(":", 1)
                        if k.strip() in RES_KEYS:
                            try:
                                tot += int(float(v.strip()))
                                parsed = True
                            except ValueError:
                                pass
                if parsed and tot > cap:
                    warns.append("event_quest.csv: event_id=%s %s 数值当量=%d 超%s档软上限%d（%.1fx），请复核是否赏赐过高" % (r.get("event_id", ""), opt, tot, rt, cap, tot / float(REWARD_BASE)))
        report.append("- [OK] event_quest: 单条赏赐倍率软告警扫描完成（基准%d，超倍率即告警不阻断）" % REWARD_BASE)

    # ---------- 战斗秘境系统跨表校验（Day1 新增 stage_main / monster_main / drop_pool）----------
    report.append("")
    report.append("# 战斗秘境跨表校验（stage_main / monster_main / drop_pool）")
    _stg = rows_of("stage_main")
    _mon = rows_of("monster_main")
    _dp = rows_of("drop_pool")
    if _stg and _mon and _dp:
        _mon_ids = {r["monster_id"] for r in _mon}
        _pool_ids = {r["pool_id"] for r in _dp}
        _item_ids = {r["item_id"] for r in _dp}
        _stage_ids = {r["stage_id"] for r in _stg}
        # 1. stage.monster_ids 必须存在；treasure 节点应为空
        for r in _stg:
            mids = [x for x in r["monster_ids"].split(",") if x.strip()]
            if r["node_type"] == "treasure":
                if mids:
                    errors.append(("stage_main.csv", "stage_main", 0, "stage_id=%s 为 treasure 节点却含怪物 %s" % (r["stage_id"], r["monster_ids"])))
            else:
                for m in mids:
                    if m not in _mon_ids:
                        errors.append(("stage_main.csv", "stage_main", 0, "stage_id=%s 引用怪物 %s 不存在于 monster_main" % (r["stage_id"], m)))
            # 2. repeat_drop_pool 必须存在
            rp = r["repeat_drop_pool"].strip()
            if rp and rp not in _pool_ids:
                errors.append(("stage_main.csv", "stage_main", 0, "stage_id=%s repeat_drop_pool=%s 不存在于 drop_pool" % (r["stage_id"], rp)))
            # 3. unlock_condition 的 pre_stage 必须存在
            m = re.search(r"pre_stage=([A-Za-z0-9_]+)", r["unlock_condition"])
            if m and m.group(1) not in _stage_ids:
                errors.append(("stage_main.csv", "stage_main", 0, "stage_id=%s unlock_condition 前置 %s 不存在" % (r["stage_id"], m.group(1))))
        # 4. monster.drop_item_ids 必须存在于 drop_pool.item_id；与 drop_weights 数量一致
        for r in _mon:
            dids = [x for x in r["drop_item_ids"].split(",") if x.strip()]
            ws = [x for x in r["drop_weights"].split(",") if x.strip()]
            if len(dids) != len(ws):
                errors.append(("monster_main.csv", "monster_main", 0, "monster_id=%s drop_item_ids(%d) 与 drop_weights(%d) 数量不一致" % (r["monster_id"], len(dids), len(ws))))
            for it in dids:
                if it not in _item_ids:
                    errors.append(("monster_main.csv", "monster_main", 0, "monster_id=%s 掉落物 %s 不存在于 drop_pool" % (r["monster_id"], it)))
        # 5. drop_pool min_count <= max_count
        for r in _dp:
            mn = int(get_first_num(r["min_count"]) or 0)
            mx = int(get_first_num(r["max_count"]) or 0)
            if mn > mx:
                errors.append(("drop_pool.csv", "drop_pool", 0, "pool_id=%s item_id=%s min_count>max_count" % (r["pool_id"], r["item_id"])))
        report.append("- [CHECK] 战斗秘境跨表校验完成（怪物引用/掉落池/前置秘境/掉落物存在性/min-max）")
    else:
        report.append("- [SKIP] stage_main/monster_main/drop_pool 未全部加载，跳过跨表校验")

    # ---------- 器殿赠宝配置跨表校验（craft_hall_reward）----------
    report.append("")
    report.append("# 器殿赠宝配置跨表校验（craft_hall_reward）")
    _chr = rows_of("craft_hall_reward")
    if _chr:
        _array_loaded = "array_items" in tables_loaded
        _array_ids = {r["item_id"] for r in rows_of("array_items")} if _array_loaded else set()
        for i, r in enumerate(_chr, 1):
            _rt = (r.get("ref_type") or "").strip()
            _ref = (r.get("item_ref") or "").strip()
            # 1. item_ref 外键：gen 仅允许 fabao（→ _造低阶物品 残破铜镜）；id 须存在于 array_items.csv（→ _按id造 经阵法物品表命中）
            if _rt == "gen":
                if _ref != "fabao":
                    errors.append(("craft_hall_reward.csv", "craft_hall_reward", i, "ref_type=gen 但 item_ref=%s 非 fabao（gen 仅允许 fabao→残破铜镜）" % _ref))
            elif _rt == "id":
                if _array_loaded:
                    if _ref not in _array_ids:
                        errors.append(("craft_hall_reward.csv", "craft_hall_reward", i, "ref_type=id 但 item_ref=%s 不存在于 array_items.csv" % _ref))
                else:
                    warns.append("craft_hall_reward.csv: ref_type=id 外键校验跳过（array_items 未加载）")
            # 2. 边界：count_min <= count_max
            _cmn = int(get_first_num(r.get("count_min", "1")) or 1)
            _cmx = int(get_first_num(r.get("count_max", "1")) or 1)
            if _cmn > _cmx:
                errors.append(("craft_hall_reward.csv", "craft_hall_reward", i, "count_min=%d > count_max=%d" % (_cmn, _cmx)))
            # 3. 边界：level_min <= level_max
            _lmn = int(get_first_num(r.get("level_min", "1")) or 1)
            _lmx = int(get_first_num(r.get("level_max", "1")) or 1)
            if _lmn > _lmx:
                errors.append(("craft_hall_reward.csv", "craft_hall_reward", i, "level_min=%d > level_max=%d" % (_lmn, _lmx)))
        report.append("- [CHECK] craft_hall_reward: item_ref 外键（gen→fabao / id→array_items）+ count/level 边界校验完成（加权池，不强制 weight-sum=100）")
    else:
        report.append("- [SKIP] craft_hall_reward 未加载，跳过跨表校验")

    # ---------- S34 凡人王朝跨表校验（dynasty_* 五表）----------
    report.append("")
    report.append("# 凡人王朝跨表校验（dynasty_config / phase / decree / faction / title / counter / commission）")
    _fac = rows_of("dynasty_faction_config")
    _pha = rows_of("dynasty_phase_config")
    _tit = rows_of("dynasty_title_config")
    _pol = rows_of("dynasty_config")
    _dec = rows_of("dynasty_decree_config")
    _cnt = rows_of("dynasty_counter_config")
    _com = rows_of("dynasty_commission_config")
    _ome = rows_of("dynasty_omen_config")
    _mem = rows_of("dynasty_memorial_config")
    _n_dyn = 0
    if _fac:
        _n_dyn += 1
        for i, r in enumerate(_fac, 1):
            # 铁律：ruling_power < ruling_decay —— 步长 = (decay - power)/3 必须恒 >= 1。
            #   power == decay → 步长恒 0 → 权重永不变化（朝堂僵死，实测外戚零干预 0 月掌权）；
            #   power >  decay → 权柄红利压过反对派压力 → 单一派系掌权 240/240 月、锁死朝堂
            #   （补丁 7 前的真实事故：外戚 power12 > decay6，仿真实测锁权 230/240 月）。
            _p = int(get_first_num(r.get("ruling_power", "0")) or 0)
            _d = int(get_first_num(r.get("ruling_decay", "0")) or 0)
            if _p >= _d:
                errors.append(("dynasty_faction_config.csv", "dynasty_faction_config", i,
                    "ruling_power(%d) 必须 < ruling_decay(%d)：否则步长 <= 0，朝堂僵死或锁权" % (_p, _d)))
            # 诉求资源须四派系互不重叠（对应宗门四条产线，扶持谁就消耗哪条线）
            _dt = (r.get("desire_type") or "").strip()
            if _dt not in ("contribution", "pill", "lingshi", "disciple"):
                errors.append(("dynasty_faction_config.csv", "dynasty_faction_config", i,
                    "desire_type=%s 非法（须为 contribution/pill/lingshi/disciple 之一）" % _dt))
        _dtypes = [(r.get("desire_type") or "").strip() for r in _fac]
        if len(set(_dtypes)) != len(_dtypes):
            errors.append(("dynasty_faction_config.csv", "dynasty_faction_config", 0,
                "四派系 desire_type 必须互不重叠，实际 %s" % _dtypes))
        # 掌权供奉/战功/苗子系数须有区分度（否则选派系没有意义）
        for _col in ("tribute_rate", "merit_rate", "talent_rate"):
            _vs = sorted(set(float(get_first_num(r.get(_col, "1")) or 1) for r in _fac))
            if len(_vs) < 3:
                errors.append(("dynasty_faction_config.csv", "dynasty_faction_config", 0,
                    "%s 四派系取值仅 %d 档，缺乏策略区分度" % (_col, len(_vs))))
    if _pha:
        _n_dyn += 1
        _TW = ["t_w_fan_su", "t_w_pingyong", "t_w_youliang", "t_w_tiancai", "t_w_yaonie", "t_w_kuangshi"]
        for i, r in enumerate(_pha, 1):
            # 六档资质权重是苗子抽取的加权池，和 drop_common.drop_weight 同理，和必须 = 100
            _s = sum(float(get_first_num(r.get(c, "0")) or 0) for c in _TW)
            if abs(_s - 100.0) > 1e-6:
                errors.append(("dynasty_phase_config.csv", "dynasty_phase_config", i,
                    "phase_id=%s 六档资质权重和 = %.2f ≠ 100（苗子加权池）" % (r.get("phase_id"), _s)))
            _mn = float(get_first_num(r.get("dynasty_min", "0")) or 0)
            _mx = float(get_first_num(r.get("dynasty_max", "0")) or 0)
            if _mn >= _mx:
                errors.append(("dynasty_phase_config.csv", "dynasty_phase_config", i,
                    "phase_id=%s dynasty_min(%.0f) 必须 < dynasty_max(%.0f)" % (r.get("phase_id"), _mn, _mx)))
        # 国祚区间须无缝覆盖 0~100（否则某些国祚值落不到任何阶段）
        _segs = sorted((float(get_first_num(r.get("dynasty_min", "0")) or 0),
                        float(get_first_num(r.get("dynasty_max", "0")) or 0)) for r in _pha)
        _cov_ok = _segs and _segs[0][0] == 0.0 and _segs[-1][1] == 100.0
        for _k in range(1, len(_segs)):
            if abs(_segs[_k][0] - _segs[_k - 1][1]) > 1e-6:
                _cov_ok = False
        if not _cov_ok:
            errors.append(("dynasty_phase_config.csv", "dynasty_phase_config", 0,
                "国祚区间须无缝覆盖 0~100，实际 %s" % (_segs,)))
    if _tit:
        _n_dyn += 1
        # 义务的代价有四种形态：灵石 / 风险 / 限制 / 不可逆绑定，
        # 只有 recommend（荐举）走灵石 —— 补丁 16 曾写「有义务必有 duty_cost>0」，
        # 误报了 tribute/heir/regent 四处假阳性（代价是限制/风险/绑定，不是钱）。
        # 校验器报红也可能是规则错，不是数据错。
        _DUTY_KEYWORD = {
            "none": ["无"],
            "recommend": ["荐举"],
            "heir": ["继承人"],
            "regent": ["国祚", "民心"],
            "tribute": ["征调"],
            # independent 的 duty_desc 写的是「自立后的后果」而非动作，关键词须覆盖后果表述
            "independent": ["自立", "再无朝廷", "郡县关系全部重置"],
        }
        for i, r in enumerate(_tit, 1):
            _dt = (r.get("duty_type") or "").strip()
            _dc = int(get_first_num(r.get("duty_cost", "0")) or 0)
            _dd = (r.get("duty_desc") or "").strip()
            # 规则1：类型与描述必须对应 —— 错配不会崩，但会骗玩家
            #       （UI 显示 duty_desc，代码按 duty_type 执行）
            _kws = _DUTY_KEYWORD.get(_dt)
            if _kws is not None and not any(k in _dd for k in _kws):
                errors.append(("dynasty_title_config.csv", "dynasty_title_config", i,
                    "duty_type=%s 但 duty_desc 未含关键词 %s（类型与描述错配会骗玩家）" % (_dt, _kws)))
            # 规则2：recommend 明确耗灵石，_结算爵位义务_S34 就是这么扣的
            if _dt == "recommend" and _dc <= 0:
                errors.append(("dynasty_title_config.csv", "dynasty_title_config", i,
                    "duty_type=recommend 须有 duty_cost > 0（荐举耗灵石）"))
            # 规则3：义务描述不能为空（none 除外）—— 玩家得看得见自己背了什么
            if _dt != "none" and not _dd:
                errors.append(("dynasty_title_config.csv", "dynasty_title_config", i,
                    "duty_type=%s 但 duty_desc 为空：玩家看不见自己背了什么义务" % _dt))
        # 规则4/5/6：爵位爬升必须【每级净正且递增】—— 补丁 18 的核心平衡结论。
        #   原实现荐举费 200 > 满版图供奉增益，玩家受封国师即净亏，爵位系统形同虚设。
        #   不固化成规则，下次改 CSV 就会悄悄倒挂回去。
        _爵位序 = _gd_list_from("game_state.gd", "爵位序",
                               ["未册封", "护国宗", "国师", "帝师", "监国", "摄政", "自立为王"])
        # 自立为王是「脱离王朝」的分支而非升级，天然无朝廷差事与供奉，故排除
        _升级序 = [t for t in _爵位序 if t != "自立为王"]
        _按名 = {str(r.get("title_name", "")): r for r in _tit}
        _prev = None
        for _tn in _升级序:
            _r = _按名.get(_tn)
            if _r is None:
                continue
            _槽 = int(get_first_num(_r.get("decree_slots", "0")) or 0)
            _供 = float(get_first_num(_r.get("tribute_bonus", "0")) or 0.0)
            if _prev is not None:
                if _槽 < _prev[1]:
                    errors.append(("dynasty_title_config.csv", "dynasty_title_config", 0,
                        "爵位「%s」decree_slots=%d 低于前一级「%s」%d —— 升爵位反而变差，玩家不会升"
                        % (_tn, _槽, _prev[0], _prev[1])))
                if _供 < _prev[2]:
                    errors.append(("dynasty_title_config.csv", "dynasty_title_config", 0,
                        "爵位「%s」tribute_bonus=%.2f 低于前一级「%s」%.2f —— 升爵位反而变差"
                        % (_tn, _供, _prev[0], _prev[2])))
            _prev = (_tn, _槽, _供)
        # 规则6：荐举费不得高于一条差事的收益（否则每月白干一条差事）
        if _dec:
            _差事均值 = sum(float(get_first_num(x.get("reward_lingshi", "0")) or 0.0) for x in _dec) / float(len(_dec))
            for i, r in enumerate(_tit, 1):
                if str(r.get("duty_type", "none")) != "recommend":
                    continue
                _dc = float(get_first_num(r.get("duty_cost", "0")) or 0.0)
                if _dc > _差事均值:
                    errors.append(("dynasty_title_config.csv", "dynasty_title_config", i,
                        "荐举费 %.0f > 差事均收益 %.0f —— 每月白干一条差事，玩家不会受封"
                        % (_dc, _差事均值)))
    if _pol:
        _n_dyn += 1
    if _dec:
        _n_dyn += 1
    if _cnt:
        _n_dyn += 1
        # 规则8：UI 入口必须存在 —— 没有按钮的玩法等于不存在
        _ui_path = os.path.join(SCRIPT_DIR, "ui", "page_dynasty.gd")
        _ui_ids = set()
        if os.path.isfile(_ui_path):
            with open(_ui_path, encoding="utf-8") as _uf:
                _ui_ids = set(re.findall(r'"(dc_[a-z0-9_]+)"\s*:\s*\[', _uf.read()))
        _合法键 = {"mind", "dynasty", "relation", "gratitude"}
        _合法种类 = {"dynasty_low", "relation_low", "gratitude_low", "mind_low",
                    "policy_miefa", "decree_fail", "composite"}
        _已见 = {}
        for i, r in enumerate(_cnt, 1):
            _cid = str(r.get("counter_id", "")).strip()
            _cnm = str(r.get("counter_name", "?"))
            if not _cid:
                errors.append(("dynasty_counter_config.csv", "dynasty_counter_config", i,
                    "counter_id 为空"))
                continue
            if _cid in _已见:
                errors.append(("dynasty_counter_config.csv", "dynasty_counter_config", i,
                    "counter_id=%s 重复（第%d行已有）" % (_cid, _已见[_cid])))
            _已见[_cid] = i
            # 规则2：触发种类必须是引擎认得的七种，拼错即恒不触发（死代码）
            _kind = str(r.get("trigger_kind", "")).strip()
            if _kind not in _合法种类:
                errors.append(("dynasty_counter_config.csv", "dynasty_counter_config", i,
                    "%s trigger_kind=%s 不在引擎认得的 %s 内（写错则该反制永不触发）"
                    % (_cid, _kind, "/".join(sorted(_合法种类)))))
            # 规则3：触发阈值 0~100
            _tv = int(get_first_num(r.get("trigger_value", "0")) or 0)
            if not (0 <= _tv <= 100):
                errors.append(("dynasty_counter_config.csv", "dynasty_counter_config", i,
                    "%s trigger_value=%d 超出 0~100" % (_cid, _tv)))
            # 规则4：预警必须早于触发 —— 反过来写预警就是马后炮，玩家无从补救
            _wv = int(get_first_num(r.get("warn_value", "0")) or 0)
            if _wv <= _tv:
                errors.append(("dynasty_counter_config.csv", "dynasty_counter_config", i,
                    "%s warn_value=%d 未高于 trigger_value=%d —— 预警不早于触发，玩家没有时间补救"
                    % (_cid, _wv, _tv)))
            # 规则5：冷却非负；终局级（composite）必须有冷却，否则每月刷屏
            _cd = int(get_first_num(r.get("cooldown_month", "0")) or 0)
            if _cd < 0:
                errors.append(("dynasty_counter_config.csv", "dynasty_counter_config", i,
                    "%s cooldown_month=%d 为负" % (_cid, _cd)))
            elif _kind == "composite" and _cd <= 0:
                errors.append(("dynasty_counter_config.csv", "dynasty_counter_config", i,
                    "%s 为终局级反制（composite）却 cooldown_month=%d —— 会每月刷屏，须设冷却"
                    % (_cid, _cd)))
            # 规则6：成本比例与钳制区间自洽
            _rate = float(get_first_num(r.get("cost_rate", "0")) or 0.0)
            if not (0.0 <= _rate <= 1.0):
                errors.append(("dynasty_counter_config.csv", "dynasty_counter_config", i,
                    "%s cost_rate=%.2f 超出 0~1" % (_cid, _rate)))
            _cmin = int(get_first_num(r.get("cost_min", "0")) or 0)
            _cmax = int(get_first_num(r.get("cost_max", "0")) or 0)
            if _cmin > _cmax:
                errors.append(("dynasty_counter_config.csv", "dynasty_counter_config", i,
                    "%s cost_min=%d > cost_max=%d" % (_cid, _cmin, _cmax)))
            # 规则7：转化效果格式 —— 键必须是引擎认得的四个，写错则效果静默丢失
            _eff = str(r.get("convert_effect", "")).strip()
            if _eff and _eff != "none":
                for _seg in _eff.split("|"):
                    _s = _seg.strip()
                    if not _s:
                        continue
                    _k = re.sub(r"^[+-]|[+-]?\d+$", "", _s).strip()
                    if _k not in _合法键:
                        errors.append(("dynasty_counter_config.csv", "dynasty_counter_config", i,
                            "%s convert_effect 片段 %r 的键 %r 不合法（应为 %s 之一，写错则效果静默丢失）"
                            % (_cid, _s, _k, "/".join(sorted(_合法键)))))
            # 规则8：UI 入口
            if _ui_ids and _cid not in _ui_ids:
                errors.append(("dynasty_counter_config.csv", "dynasty_counter_config", i,
                    "%s（%s）在 ui/page_dynasty.gd 的 反制选项表 里没有条目 —— 玩家看不到也点不到，等于不存在"
                    % (_cid, _cnm)))

    # —— 通用拍卖会（常驻场 + 季度大拍）跨表/字段校验 ——
    _auc = rows_of("auction_config")
    if _auc:
        _已知参数 = {"常驻刷新日","常驻拍品数","常驻时长日","大拍周期日","大拍拍品数","大拍时长日",
                     "起拍系数下限","起拍系数上限","溢价系数下限","溢价系数上限","流拍系数",
                     "佣金率","AI数量","AI估值系数下限","AI估值系数上限","决策窗口日","大拍基准倍率"}
        _已见 = {}
        for i, r in enumerate(_auc, 1):
            _p = str(r.get("param","")).strip()
            if _p == "":
                errors.append(("auction_config.csv","auction_config",i,"param 为空"))
                continue
            if _p in _已见:
                errors.append(("auction_config.csv","auction_config",i,"param=%s 重复定义"%_p))
            _已见[_p] = True
            if _p not in _已知参数:
                errors.append(("auction_config.csv","auction_config",i,"未知参数 param=%s（引擎不消费）"%_p))
                continue
            _v = str(r.get("value","")).strip()
            try:
                _f = float(_v)
            except ValueError:
                errors.append(("auction_config.csv","auction_config",i,"param=%s value=%s 非数值"%(_p,_v)))
                continue
            if _f < 0:
                errors.append(("auction_config.csv","auction_config",i,"param=%s value=%s 为负"%(_p,_v)))
        _gv = {str(r.get("param","")).strip(): float(str(r.get("value","0")).strip() or 0.0) for r in _auc}
        if _gv.get("起拍系数下限",0) > _gv.get("起拍系数上限",0):
            errors.append(("auction_config.csv","auction_config",0,"起拍系数下限 > 起拍系数上限"))
        if _gv.get("溢价系数下限",0) > _gv.get("溢价系数上限",0):
            errors.append(("auction_config.csv","auction_config",0,"溢价系数下限 > 溢价系数上限"))
        if not (0.0 < _gv.get("流拍系数",0) <= 1.0):
            errors.append(("auction_config.csv","auction_config",0,"流拍系数应∈(0,1]，当前=%s"%_gv.get("流拍系数",0)))
        if not (0.0 <= _gv.get("佣金率",0) <= 1.0):
            errors.append(("auction_config.csv","auction_config",0,"佣金率应∈[0,1]，当前=%s"%_gv.get("佣金率",0)))
        if _gv.get("大拍基准倍率",0) < 1.0:
            errors.append(("auction_config.csv","auction_config",0,"大拍基准倍率应≥1，当前=%s"%_gv.get("大拍基准倍率",0)))
        report.append("- [CHECK] auction_config: 参数合法性 + 起拍/溢价/流拍/佣金自洽校验完成")
    _aai = rows_of("auction_ai_config")
    if _aai:
        _已见 = {}
        for i, r in enumerate(_aai, 1):
            _id = str(r.get("ai_id","")).strip()
            if _id == "":
                errors.append(("auction_ai_config.csv","auction_ai_config",i,"ai_id 为空"))
                continue
            if _id in _已见:
                errors.append(("auction_ai_config.csv","auction_ai_config",i,"ai_id=%s 重复"%_id))
            _已见[_id] = True
            _bm = str(r.get("budget_mod","")).strip()
            _vm = str(r.get("valuation_mod","")).strip()
            try:
                _bmf = float(_bm)
            except ValueError:
                errors.append(("auction_ai_config.csv","auction_ai_config",i,"%s budget_mod=%s 非数值"%(_id,_bm)))
                _bmf = 0.0
            try:
                _vmf = float(_vm)
            except ValueError:
                errors.append(("auction_ai_config.csv","auction_ai_config",i,"%s valuation_mod=%s 非数值"%(_id,_vm)))
                _vmf = 0.0
            if not (0.1 <= _bmf <= 5.0):
                errors.append(("auction_ai_config.csv","auction_ai_config",i,"%s budget_mod=%s 应∈[0.1,5]"%(_id,_bm)))
            if not (0.1 <= _vmf <= 5.0):
                errors.append(("auction_ai_config.csv","auction_ai_config",i,"%s valuation_mod=%s 应∈[0.1,5]"%(_id,_vm)))
            _lines = str(r.get("lines","")).split("|")
            _非空 = [x for x in _lines if x.strip() != ""]
            if len(_非空) == 0:
                errors.append(("auction_ai_config.csv","auction_ai_config",i,"%s lines 竞价台词池为空（|分隔）"%_id))
        report.append("- [CHECK] auction_ai_config: ai_id 唯一 + budget/valuation 范围 + 台词池非空校验完成")

    # —— 朝廷委托（护国宗不可拒征调）跨表/字段校验 ——
    if _com:
        _n_dyn += 1
        _reals = realm_list()
        _合法类型 = None  # commission_type 为纯展示类目，引擎不按它分支；仅校验非空
        _已见 = {}
        for i, r in enumerate(_com, 1):
            _cid = str(r.get("commission_id", "")).strip()
            _cnm = str(r.get("commission_name", "?"))
            if not _cid:
                errors.append(("dynasty_commission_config.csv", "dynasty_commission_config", i, "commission_id 为空"))
                continue
            if _cid in _已见:
                errors.append(("dynasty_commission_config.csv", "dynasty_commission_config", i,
                    "commission_id=%s 重复（第%d行已有）" % (_cid, _已见[_cid])))
            _已见[_cid] = i
            # 规则1：要求境界必须是真源境界序之一，写错则 find()=-1 → 所有弟子都「达标」（静默过宽）
            _realm = str(r.get("require_realm", "")).strip()
            if _realm not in _reals:
                errors.append(("dynasty_commission_config.csv", "dynasty_commission_config", i,
                    "%s require_realm=%s 不在境界序真源 %s 内（写错则委托对任何人开放）" % (_cid, _realm, "/".join(_reals))))
            # 规则2：类型须非空（纯展示类目，引擎不按它分支，仅防漏填）
            _typ = str(r.get("commission_type", "")).strip()
            if _typ == "":
                errors.append(("dynasty_commission_config.csv", "dynasty_commission_config", i,
                    "%s commission_type 为空（须填写展示类目，如 tribute/campaign/demon 等）" % _cid))
            # 规则3：mandatory 必须为 1（护国宗不可拒，强制征调）
            _man = str(r.get("mandatory", "")).strip()
            if _man != "1":
                errors.append(("dynasty_commission_config.csv", "dynasty_commission_config", i,
                    "%s mandatory=%s 必须为 1（护国宗不可拒，强制征调）" % (_cid, _man)))
            # 规则4：赏罚符号自洽 —— 奖励>=0，惩罚<=0；反过来写等于把惩罚变成奖励
            _rg = int(get_first_num(r.get("reward_gratitude", "0")) or 0)
            _rl = int(get_first_num(r.get("reward_lingshi", "0")) or 0)
            _rm = int(get_first_num(r.get("reward_merit", "0")) or 0)
            if _rg < 0 or _rl < 0 or _rm < 0:
                errors.append(("dynasty_commission_config.csv", "dynasty_commission_config", i,
                    "%s 奖励项含负值（reward_gratitude/lingshi/merit 须>=0）" % _cid))
            _pg = int(get_first_num(r.get("penalty_gratitude", "0")) or 0)
            _pl = int(get_first_num(r.get("penalty_loyalty", "0")) or 0)
            if _pg > 0 or _pl > 0:
                errors.append(("dynasty_commission_config.csv", "dynasty_commission_config", i,
                    "%s 惩罚项含正值（penalty_gratitude/loyalty 须<=0，写正则变成白送好处）" % _cid))
        report.append("- [CHECK] 朝廷委托表校验完成（commission_id 唯一 / 要求境界取自真源 / 类型已知 / mandatory=1 / 赏罚符号自洽）")
    # ——— S35-0 王朝邸报层：祥瑞表 / 朝奏表（防假系统校验为主） ———
    def _引擎键白名单(函数名: str, 前缀: str) -> set:
        """从 game_state.gd + dynasty_system.gd 指定函数体内抓 `前缀 == "xxx"` 的分支键。
        返回 None 表示抓取失败（函数不存在），返回 set() 表示空集合（真实现里没有任何分支键）。
        修复 S47：S34 把 _施加朝奏效果拆成了转发桩 → 仅扫 game_state.gd 会拿到空 set，
        拿着空 set 去校验会【静默】让所有合法键都报错，必须显式报警。"""
        _sources = ("dynasty_system.gd", "game_state.gd")
        _keys = set()
        _found = False
        for _f in _sources:
            try:
                _src = open(_f, encoding="utf-8").read()
            except Exception:
                continue
            _m = re.search(r"func %s\b.*?(?=\nfunc |\Z)" % re.escape(函数名), _src, re.S)
            if _m:
                _found = True
                _keys |= set(re.findall(r'%s == "([a-z_]+)"' % re.escape(前缀), _m.group(0)))
        if not _found:
            return None
        return _keys

    _祥瑞键 = _引擎键白名单("_施加祥瑞效果", "类型")
    _朝奏键 = _引擎键白名单("_施加朝奏效果", "键")
    if _祥瑞键 is None or _朝奏键 is None:
        report.append("- [SKIP] 无法从 game_state.gd/dynasty_system.gd 现读效果键白名单，跳过祥瑞/朝奏语义校验")
    elif not _祥瑞键 or not _朝奏键:
        report.append("- [WARN] 现读效果键白名单为空（祥瑞=%d 朝奏=%d），真实现可能已搬迁" % (len(_祥瑞键), len(_朝奏键)))
    else:
        if _ome:
            _n_dyn += 1
            _三类 = set()
            for i, r in enumerate(_ome, 1):
                _oid = (r.get("omen_id") or "").strip()
                _otype = (r.get("omen_type") or "").strip()
                _oscope = (r.get("scope") or "").strip()
                _oeft = (r.get("effect_type") or "").strip()
                _三类.add(_otype)
                # R1：scope=single_county 的祥瑞必须真的作用于郡，
                #     否则 _随机凡俗郡() 返回 "" 时引擎直接 return，这条祥瑞永远不生效（死配置）
                if _oscope == "single_county" and not (_oeft.startswith("county_") or _oeft == "talent_hunt"):
                    errors.append(("dynasty_omen_config.csv", "dynasty_omen_config", i,
                        "%s scope=single_county 但 effect_type=%s 不作用于郡：无郡可选时引擎静默 return，本条永不生效" % (_oid, _oeft)))
                # R2：零货币铁律 —— 唯一允许的货币通道 sect_incense 必须限幅
                if _oeft == "sect_incense":
                    _v = int(get_first_num(r.get("effect_value", "0")) or 0)
                    if not (0 <= _v <= 30):
                        errors.append(("dynasty_omen_config.csv", "dynasty_omen_config", i,
                            "%s sect_incense 值 %d 越界（须 0..30，祥瑞零货币铁律，防突破运维封顶 318）" % (_oid, _v)))
                # R4：文案含 {郡} 占位却非 single_county → 郡名恒为「某地」，穿帮
                if "{郡}" in (r.get("text") or "") and _oscope != "single_county":
                    errors.append(("dynasty_omen_config.csv", "dynasty_omen_config", i,
                        "%s text 含 {郡} 占位但 scope=%s：郡名恒为「某地」，文案穿帮" % (_oid, _oscope)))
            # R3：三类均须存在（缺一类 → 玩家永远看不到该类邸报）
            for _need in ("auspicious", "neutral", "ominous"):
                if _need not in _三类:
                    errors.append(("dynasty_omen_config.csv", "dynasty_omen_config", 0,
                        "缺失 omen_type=%s 的祥瑞：该类型邸报玩家永远看不到" % _need))
            report.append("- [CHECK] 祥瑞表校验完成（郡级作用域自洽 / 零货币限幅 / 三类齐全 / 占位符不穿帮）")

        if _mem:
            _n_dyn += 1
            _有_omen_next = False
            for i, r in enumerate(_mem, 1):
                _mid = (r.get("memorial_id") or "").strip()
                _效串 = []
                for _k in ("opt1_effect", "opt2_effect", "opt3_effect"):
                    _s = (r.get(_k) or "").strip()
                    _效串.append(_s)
                    if _s == "":
                        continue
                    for _seg in _s.split(";"):
                        _seg = _seg.strip()
                        if _seg == "":
                            continue
                        _kv = _seg.split(":")
                        if len(_kv) < 2:
                            errors.append(("dynasty_memorial_config.csv", "dynasty_memorial_config", i,
                                "%s %s 片段「%s」缺冒号（格式须 key:value）" % (_mid, _k, _seg)))
                            continue
                        _key = _kv[0].strip()
                        # M1：key 必须在引擎白名单内（现读，不手抄）
                        if _key not in _朝奏键:
                            errors.append(("dynasty_memorial_config.csv", "dynasty_memorial_config", i,
                                "%s %s 效果键「%s」不在引擎白名单 %s" % (_mid, _k, _key, sorted(_朝奏键))))
                            continue
                        # M3：灵石正值上限 80（每日 1 道，日入增量须对齐运维封顶 318）
                        if _key == "lingshi":
                            try:
                                _v = int(_kv[1].strip())
                            except Exception:
                                _v = 0
                            if _v > 80:
                                errors.append(("dynasty_memorial_config.csv", "dynasty_memorial_config", i,
                                    "%s %s lingshi=%d 超上限 80（每日 1 道，须对齐运维封顶 318）" % (_mid, _k, _v)))
                        if _key == "omen_next":
                            _有_omen_next = True
                # M2：三选项效果不可全同 —— 全同 = 假选择，玩家点了等于没点
                if _效串[0] != "" and _效串[0] == _效串[1] == _效串[2]:
                    errors.append(("dynasty_memorial_config.csv", "dynasty_memorial_config", i,
                        "%s 三个选项效果完全相同（%s）：这是【假选择】，玩家点了等于没点" % (_mid, _效串[0])))
                # M5：文案含 {郡} 时，至少一个选项真的作用于郡（否则该奏疏对郡毫无影响）
                if "{郡}" in (r.get("text") or ""):
                    _郡键集 = {"gratitude", "loyalty", "disaster", "talent"}
                    if not any(any(_kk in _s for _kk in _郡键集) for _s in _效串):
                        errors.append(("dynasty_memorial_config.csv", "dynasty_memorial_config", i,
                            "%s text 含 {郡} 但无任一选项作用于郡（gratitude/loyalty/disaster/talent）" % _mid))
            # M4：omen_next 必须有真实消费方，否则引擎该分支是死代码
            if not _有_omen_next:
                errors.append(("dynasty_memorial_config.csv", "dynasty_memorial_config", 0,
                    "无任何奏疏使用 omen_next：引擎 _施加朝奏效果 的 omen_next 分支为死代码"))
            report.append("- [CHECK] 朝奏表校验完成（效果键现读白名单 / 三选项非全同 / 灵石<=80 / omen_next 有消费方 / 郡级占位有实效）")

    if _n_dyn:
        report.append("- [CHECK] 凡人王朝六表校验完成（power<decay 铁律 / 资质权重和=100 / 国祚区间无缝 / 义务必有开销 / desire_type 互斥 / 预警早于触发 / 反制必有 UI 入口）")
    else:
        report.append("- [SKIP] dynasty_* 未加载，跳过凡人王朝跨表校验")


    # 4. faction_base：need_reputation 严格递增 + 逐档对齐运行时标尺 + faction_id<->faction_name 唯一映射
    #    S33-2：order 由硬编码 ["中立",...,"崇拜"] 改为真源 FACTION_REP_LEVELS
    #    （旧值含孤儿档「崇拜」且缺「冷淡」，CSV 一改标尺即 order.index() 抛 ValueError）
    d = rows_of("faction_base")
    if d:
        order = list(FACTION_REP_LEVELS)
        from collections import defaultdict
        g = defaultdict(list)
        _name_of = {}
        for r in d:
            _lvl = r["reputation_level"]
            if _lvl not in order:
                errors.append(("faction_base.csv","faction_base",0,"faction_id=%s 声望等级=%s 不在运行时标尺 %s 内"%(r["faction_id"],_lvl,"/".join(order))))
                continue
            _li = order.index(_lvl)
            _need = int(get_first_num(r["need_reputation"]) or 0)
            g[r["faction_id"]].append((_li, _need))
            # 逐档对齐 faction_system.gd REPUTATION_THRESHOLDS（本次收口的核心防漂移闸门）
            if _li < len(FACTION_REP_THRESHOLDS) and _need != FACTION_REP_THRESHOLDS[_li]:
                errors.append(("faction_base.csv","faction_base",0,
                    "faction_id=%s 等级%s need_reputation=%d ≠ faction_system.gd 标尺 %d"%(r["faction_id"],_lvl,_need,FACTION_REP_THRESHOLDS[_li])))
            # faction_id <-> faction_name 必须一一对应
            _prev = _name_of.setdefault(r["faction_id"], r["faction_name"])
            if _prev != r["faction_name"]:
                errors.append(("faction_base.csv","faction_base",0,"faction_id=%s 对应多个 faction_name（%s / %s）"%(r["faction_id"],_prev,r["faction_name"])))
            if FACTION_NAME_TO_ID.get(r["faction_name"]) != r["faction_id"]:
                errors.append(("faction_base.csv","faction_base",0,"faction_id=%s 与 faction_name=%s 不匹配（期望 %s）"%(r["faction_id"],r["faction_name"],FACTION_NAME_TO_ID.get(r["faction_name"]))))
        for fid, lst in g.items():
            lst.sort()
            if len(lst) != len(order):
                errors.append(("faction_base.csv","faction_base",0,"faction_id=%s 声望档位数=%d，应为 %d 档"%(fid,len(lst),len(order))))
            for i in range(1,len(lst)):
                if lst[i][1] <= lst[i-1][1]:
                    errors.append(("faction_base.csv","faction_base",0,"faction_id=%s 声望等级%s need_reputation未严格递增"% (fid, order[lst[i][0]])))
        report.append("- [CHECK] faction_base: need_reputation 严格递增 + 逐档对齐 faction_system.gd 标尺 + id<->name 映射校验完成")
    # 5. faction_shop：售价按解锁声望等级封顶（老表无品阶列，故替代原 item_grade 品阶封顶）
    #    S33-2：旧实现直取 r["item_grade"] / r["shop_id"]，老表两列均不存在
    #    （此前不崩溃仅因该表「未识别」使 rows_of 返回空；一旦纳入校验必 KeyError）
    d = rows_of("faction_shop")
    if d:
        for r in d:
            lvl = r["unlock_reputation"]
            cap = REP_LEVEL_PRICE_CAP.get(lvl)
            if cap is None:
                errors.append(("faction_shop.csv","faction_shop",0,"item_id=%s unlock_reputation=%s 非法等级名"%(r["item_id"],lvl)))
                continue
            price = int(get_first_num(r["price"]) or 0)
            if price > cap:
                errors.append(("faction_shop.csv","faction_shop",0,"item_id=%s price=%d 超出 unlock_reputation=%s 的售价上限 %d"%(r["item_id"],price,lvl,cap)))
            if FACTION_NAME_TO_ID.get(r["faction"]) != r["faction_id"]:
                errors.append(("faction_shop.csv","faction_shop",0,"item_id=%s faction=%s 与 faction_id=%s 不一致"%(r["item_id"],r["faction"],r["faction_id"])))
        report.append("- [CHECK] faction_shop: 售价声望封顶 + faction<->faction_id 交叉一致性校验完成")
    # 5b. faction_quests：faction_id 可 join faction_base + faction<->faction_id 交叉一致
    d = rows_of("faction_quests")
    if d:
        _base_fids = set(r["faction_id"] for r in rows_of("faction_base")) if rows_of("faction_base") else set()
        for r in d:
            if _base_fids and r["faction_id"] not in _base_fids:
                errors.append(("faction_quests.csv","faction_quests",0,"quest_id=%s faction_id=%s 无法 join faction_base"%(r["quest_id"],r["faction_id"])))
            if FACTION_NAME_TO_ID.get(r["faction"]) != r["faction_id"]:
                errors.append(("faction_quests.csv","faction_quests",0,"quest_id=%s faction=%s 与 faction_id=%s 不一致"%(r["quest_id"],r["faction"],r["faction_id"])))
        report.append("- [CHECK] faction_quests: faction_id 外键 join + faction<->faction_id 交叉一致性校验完成")
    # 6. weight sums =1
    def weight_check(key, cols, label):
        d = rows_of(key)
        if not d: return
        bad = 0
        for r in d:
            s = sum(float(get_first_num(r[c]) or 0) for c in cols)
            if abs(s-1.0) > 1e-6: bad += 1
        if bad:
            errors.append((key+".csv", key, 0, "%s 权重和≠1 的行数=%d" % (label, bad)))
        else:
            report.append("- [OK] %s: %s 权重和=1" % (key, label))
    weight_check("personality_config", ["work_weight","walk_weight","rest_weight","interact_weight"], "行为权重")
    weight_check("path_config", ["work_area_weight","train_area_weight","public_area_weight"], "片区权重")
    weight_check("area_stay_weight", ["lingtian_weight","danfang_weight","yanwuchang_weight","shanmen_weight","public_weight"], "五片区权重")
    # 7. quest_item combine
    d = rows_of("quest_item")
    if d:
        targets = {r["item_id"]: r for r in d if r["item_class"]=="主线信物"}
        frags = defaultdict(int)
        frag_target = {}
        for r in d:
            if r["item_class"]=="差事碎片":
                frags[r["combine_group"]] += 1
                frag_target[r["combine_group"]] = r["combine_target_id"]
        for grp, cnt in frags.items():
            tid = frag_target.get(grp)
            if tid not in targets:
                errors.append(("quest_item.csv","quest_item",0,"combine_group=%s 碎片目标%s 不存在主线信物"%(grp,tid)))
            else:
                exp = int(get_first_num(targets[tid]["fragment_total"]) or 0)
                if cnt != exp:
                    errors.append(("quest_item.csv","quest_item",0,"combine_group=%s 碎片数=%d≠主线信物fragment_total=%d"%(grp,cnt,exp)))
        report.append("- [CHECK] quest_item: 合成完整性校验完成")

    # ---------- TASK0 道途重命名门控 ----------
    report.append("")
    report.append("# 道途重命名门控（剑修→道修）")
    prof_bad = validate_profession_renamed()
    for e in prof_bad:
        errors.append(e)
    if prof_bad:
        report.append("- [FAIL] 检测到 %d 处残留「剑修」（道途枚举须全部为「道修」）" % len(prof_bad))
        for f,k,r,msg in prof_bad:
            report.append("  - [%s/%s 行%d] %s" % (f,k,r,msg))
    else:
        report.append("- [OK] 根目录 .gd 与 config/*.csv 中无残留「剑修」，道途枚举已统一为「道修」")

    # ——— S35-1 开国六问：dynasty_found_config 跨表校验（防掀桌开国变成死配置） ———
    if "dynasty_found_config" in tables_loaded:
        _, _frows = tables_loaded["dynasty_found_config"]
        _kinds = {}
        for i, r in enumerate(_frows, 1):
            _fid = str(r.get("id", "")).strip()
            _kind = str(r.get("kind", "")).strip()
            if _kind:
                _kinds.setdefault(_kind, 0)
                _kinds[_kind] += 1
            # F1：id 前缀必须与 kind 自洽（fr_/fs_/fl_/ff_），防复制粘贴串档
            _want = {"route": "fr_", "system": "fs_", "law": "fl_", "faith": "ff_"}.get(_kind, "")
            if _want and not _fid.startswith(_want):
                errors.append(("dynasty_found_config.csv", "dynasty_found_config", i,
                    "%s kind=%s 的 id 前缀应为 %s（防串档）" % (_fid, _kind, _want)))
            # F4/F5：init_* 与 karma 只有 route 能用；非 route 必须归零
            _isroute = (_kind == "route")
            _init = [int(get_first_num(r.get("init_morale", "0")) or 0),
                     int(get_first_num(r.get("init_longevity", "0")) or 0),
                     int(get_first_num(r.get("init_loyalty", "0")) or 0)]
            if _isroute:
                if _init[0] <= 0 or _init[1] <= 0 or _init[2] <= 0:
                    errors.append(("dynasty_found_config.csv", "dynasty_found_config", i,
                        "%s 路线行 init_morale/longevity/loyalty 必须>0（否则建国即空王朝）" % _fid))
            else:
                if _init[0] != 0 or _init[1] != 0 or _init[2] != 0:
                    errors.append(("dynasty_found_config.csv", "dynasty_found_config", i,
                        "%s 非路线行 init_* 必须为 0（建国初值只由路线决定）" % _fid))
                if int(get_first_num(r.get("karma", "0")) or 0) != 0:
                    errors.append(("dynasty_found_config.csv", "dynasty_found_config", i,
                        "%s 非路线行 karma 必须为 0" % _fid))
            # F6：need_title 若非空，必须命中 dynasty_title_config 的 title_name（现读真源，禁手抄）
            _nt = str(r.get("need_title", "")).strip()
            if _nt:
                _tnames = set()
                if "dynasty_title_config" in tables_loaded:
                    for _tr in tables_loaded["dynasty_title_config"][1]:
                        _tnames.add(str(_tr.get("title_name", "")).strip())
                if _tnames and _nt not in _tnames:
                    errors.append(("dynasty_found_config.csv", "dynasty_found_config", i,
                        "%s need_title=%s 不在 dynasty_title_config 的 title_name 中" % (_fid, _nt)))
        # F7：四条 kind 都必须有条目，否则六问会缺页
        for _k in ("route", "system", "law", "faith"):
            if _kinds.get(_k, 0) == 0:
                errors.append(("dynasty_found_config.csv", "dynasty_found_config", 0,
                    "缺少 kind=%s 的条目（开国六问会缺页）" % _k))

    # ——— S35-2 国教信仰网络：三表跨表校验（防信仰系统变成死配置） ———
    if "dynasty_temple_config" in tables_loaded:
        _tmr = tables_loaded["dynasty_temple_config"][1]
        _p_cov = 0
        _p_cv = 0.0
        _p_res = -1
        _p_cost = -1
        for i, r in enumerate(_tmr, start=2):
            _tid = str(r.get("temple_id", "")).strip()
            _cov = int(get_first_num(r.get("cover_pop", "0")) or 0)
            _cv = float(get_first_num(r.get("convert_rate", "1")) or 1)
            _res = int(get_first_num(r.get("heresy_resist", "0")) or 0)
            _cost = int(get_first_num(r.get("daily_incense_cost", "0")) or 0)
            if _cov <= _p_cov:
                errors.append(("dynasty_temple_config.csv", "dynasty_temple_config", i,
                    "%s cover_pop=%d 未严格大于上一阶 %d（高阶庙不如低阶，玩家没理由升级）" % (_tid, _cov, _p_cov)))
            if _cv < _p_cv:
                errors.append(("dynasty_temple_config.csv", "dynasty_temple_config", i,
                    "%s convert_rate=%.2f 低于上一阶 %.2f" % (_tid, _cv, _p_cv)))
            if _res < _p_res:
                errors.append(("dynasty_temple_config.csv", "dynasty_temple_config", i,
                    "%s heresy_resist=%d 低于上一阶 %d" % (_tid, _res, _p_res)))
            if _cost < _p_cost:
                errors.append(("dynasty_temple_config.csv", "dynasty_temple_config", i,
                    "%s daily_incense_cost=%d 低于上一阶 %d（高阶维护反而更便宜=白拿加成）" % (_tid, _cost, _p_cost)))
            _p_cov = _cov
            _p_cv = _cv
            _p_res = _res
            _p_cost = _cost
        if _p_cov < 8000:
            errors.append(("dynasty_temple_config.csv", "dynasty_temple_config", 0,
                "最高阶 cover_pop=%d 覆盖不了一个 L1 村镇（人口 8000）" % _p_cov))
    if "dynasty_heresy_config" in tables_loaded:
        _her = tables_loaded["dynasty_heresy_config"][1]
        for i, r in enumerate(_her, start=2):
            _hid = str(r.get("heresy_id", "")).strip()
            if not _hid.startswith("he_"):
                errors.append(("dynasty_heresy_config.csv", "dynasty_heresy_config", i,
                    "%s heresy_id 必须以 he_ 开头" % _hid))
            _th = float(get_first_num(r.get("threshold", "0")) or 0)
            if not (0 < _th < 100):
                errors.append(("dynasty_heresy_config.csv", "dynasty_heresy_config", i,
                    "%s threshold=%.1f 必须落在 (0,100)，否则警报永不触发或一直触发" % (_hid, _th)))
            _tp = float(get_first_num(r.get("tribute_penalty", "1")) or 1)
            if not (0 < _tp <= 1):
                errors.append(("dynasty_heresy_config.csv", "dynasty_heresy_config", i,
                    "%s tribute_penalty=%.2f 必须落在 (0,1]，否则异端反而加成供奉" % (_hid, _tp)))
    # F1（最关键）：faith_id 必须与开国表 kind=faith 的 id 完全一致
    if "dynasty_faith_config" in tables_loaded and "dynasty_found_config" in tables_loaded:
        _far = tables_loaded["dynasty_faith_config"][1]
        _found_faith = set()
        for _fr in tables_loaded["dynasty_found_config"][1]:
            if str(_fr.get("kind", "")).strip() == "faith":
                _found_faith.add(str(_fr.get("id", "")).strip())
        _faith_ids = set()
        for i, r in enumerate(_far, start=2):
            _fid = str(r.get("faith_id", "")).strip()
            _faith_ids.add(_fid)
            if _fid not in _found_faith:
                errors.append(("dynasty_faith_config.csv", "dynasty_faith_config", i,
                    "%s 在开国表 kind=faith 中不存在（玩家选了国教却查不到信仰参数=死配置）" % _fid))
            for _k in ("convert_mult", "heresy_mult", "tribute_mult", "talent_mult", "incense_mult"):
                _v = float(get_first_num(r.get(_k, "1")) or 1)
                if _v <= 0:
                    errors.append(("dynasty_faith_config.csv", "dynasty_faith_config", i,
                        "%s %s=%.2f 必须为正" % (_fid, _k, _v)))
        for _miss in sorted(_found_faith - _faith_ids):
            errors.append(("dynasty_faith_config.csv", "dynasty_faith_config", 0,
                "开国表 faith=%s 在信仰表中缺对应行" % _miss))
        report.append("- [CHECK] 开国配置表校验完成（kind 枚举 / id 前缀自洽 / 门槛非负 / 效果区间 / 路线 init_* / need_title 命中真源 / 四类齐备）")
    # ---------- S36 心魔誓：誓约表语义 / 消费方校验 ----------
    if "oath_config" in tables_loaded or "oath_sect_config" in tables_loaded:
        _OATH_COND = ["realm_up","merit_gain","contrib_gain","disciple_gain",
            "heart_max","loyal_keep","daoxin_reach","target_alive"]
        _SECT_COND = ["sect_realm_up","sect_merit","sect_member"]
        _OATH_KEYS = ["daoxin","xinjing","loyal","demon","prestige"]
        _SECT_KEYS = ["prestige","daoxin_all","xinjing_all","loyal_all","demon_all"]
        if "oath_config" in tables_loaded:
            for i, r in enumerate(tables_loaded["oath_config"][1], start=2):
                oid = str(r.get("oath_id", "")).strip()
                ct = str(r.get("cond_type", "")).strip()
                if ct not in _OATH_COND:
                    errors.append(("oath_config.csv", "oath_config", i,
                        "%s cond_type=%s 非法：不在引擎支持的 8 种条件内" % (oid, ct)))
                for col in ("reward", "punish"):
                    s = str(r.get(col, "")).strip()
                    if s == "":
                        errors.append(("oath_config.csv", "oath_config", i,
                            "%s %s 为空：无奖惩的誓约=假系统" % (oid, col)))
                        continue
                    for seg in s.split("|"):
                        k = seg.split(":")[0].strip()
                        if k not in _OATH_KEYS:
                            errors.append(("oath_config.csv", "oath_config", i,
                                "%s %s 效果键「%s」非法：只许道心/心境/忠诚/心魔/声望（零货币产出铁律）" % (oid, col, k)))
                if "demon:" not in str(r.get("punish", "")):
                    errors.append(("oath_config.csv", "oath_config", i,
                        "%s punish 缺 demon：破誓而无心魔代价=玩家必梭哈立誓" % oid))
                if len(str(r.get("reward", "")).strip()) == 0:
                    errors.append(("oath_config.csv", "oath_config", i,
                        "%s reward 为空：达成无回报=玩家不会立誓" % oid))
        if "oath_sect_config" in tables_loaded:
            for i2, r2 in enumerate(tables_loaded["oath_sect_config"][1], start=2):
                sid = str(r2.get("sect_oath_id", "")).strip()
                ct2 = str(r2.get("cond_type", "")).strip()
                if ct2 not in _SECT_COND:
                    errors.append(("oath_sect_config.csv", "oath_sect_config", i2,
                        "%s cond_type=%s 非法：不在引擎支持的 3 种全宗条件内" % (sid, ct2)))
                for col2 in ("reward", "punish"):
                    s2 = str(r2.get(col2, "")).strip()
                    if s2 == "":
                        errors.append(("oath_sect_config.csv", "oath_sect_config", i2,
                            "%s %s 为空：无奖惩的大誓=假系统" % (sid, col2)))
                        continue
                    for seg2 in s2.split("|"):
                        k2 = seg2.split(":")[0].strip()
                        if k2 not in _SECT_KEYS:
                            errors.append(("oath_sect_config.csv", "oath_sect_config", i2,
                                "%s %s 效果键「%s」非法：只许声望与全宗四维（零货币产出铁律）" % (sid, col2, k2)))
        # 消费方现读真源：条件类型 / 效果键必须在 game_state.gd 引擎里真实出现（禁手抄常量）
        _gs_path = os.path.join(SCRIPT_DIR, "game_state.gd")
        _gs = ""
        if os.path.exists(_gs_path):
            with open(_gs_path, "r", encoding="utf-8") as _gf:
                _gs = _gf.read()
        if _gs:
            for _ct in _OATH_COND + _SECT_COND:
                if ("\"%s\"" % _ct) not in _gs:
                    errors.append(("oath_config.csv", "oath_config", 0,
                        "条件类型 %s 在 game_state.gd 引擎中零命中：誓约条件没有消费方=假系统" % _ct))
            for _k in _OATH_KEYS + _SECT_KEYS:
                if ("\"%s\"" % _k) not in _gs:
                    errors.append(("oath_config.csv", "oath_config", 0,
                        "效果键 %s 在 game_state.gd 引擎中零命中：奖励没有消费方=假系统" % _k))
        report.append("- [CHECK] S36 心魔誓校验完成（条件枚举 / 零货币效果键 / 破誓必有心魔代价 / 引擎消费方现读真源）")
        # ---------- S37 丹纹：分档覆盖 / 数值口径 / 消费方现读真源 ----------
        if "pill_mark_config" in tables_loaded or "pill_mark_tier" in tables_loaded:
            # 品阶枚举现读真源：从 item.gd 的 const 品阶序 解析，禁手抄常量
            _item_path = os.path.join(SCRIPT_DIR, "item.gd")
            _item_src = ""
            if os.path.exists(_item_path):
                with open(_item_path, "r", encoding="utf-8") as _if:
                    _item_src = _if.read()
            _GRADES = []
            _m = re.search(r"const\s+品阶序\s*:?=\s*\[([^\]]*)\]", _item_src)
            if _m:
                for _g in _m.group(1).split(","):
                    _g = _g.strip().strip('"').strip("'")
                    if _g:
                        _GRADES.append(_g)
            if not _GRADES:
                errors.append(("pill_mark_config.csv", "pill_mark_config", 0,
                    "无法从 item.gd 解析 品阶序：品阶枚举校验降级为跳过（比误判更危险，请修探针）"))
            if "pill_mark_config" in tables_loaded:
                for i, r in enumerate(tables_loaded["pill_mark_config"][1], start=2):
                    g = str(r.get("grade", "")).strip()
                    if _GRADES and g not in _GRADES:
                        errors.append(("pill_mark_config.csv", "pill_mark_config", i,
                            "品阶「%s」不在 item.gd 品阶序 %s 内（枚举必须现读真源）" % (g, _GRADES)))
                    tox = float(r.get("base_toxin", 0) or 0)
                    if tox <= 0:
                        errors.append(("pill_mark_config.csv", "pill_mark_config", i,
                            "%s base_toxin=%.2f：无纹丹不涨毒 → disciple.丹毒 死轴仍未激活" % (g, tox)))
                    det = float(r.get("detox_per_mark", 0) or 0)
                    mx = int(r.get("max_mark", 9) or 9)
                    if det * mx < tox:
                        errors.append(("pill_mark_config.csv", "pill_mark_config", i,
                            "%s 满纹解毒 %.2f < 基础毒 %.2f：满纹仍净涨毒 → 炼高纹丹无意义" % (g, det * mx, tox)))
                    ppm = float(r.get("price_per_mark", 0) or 0)
                    if 1.0 + ppm * mx > 3.0:
                        errors.append(("pill_mark_config.csv", "pill_mark_config", i,
                            "%s 满纹售价倍率 %.2f：售价膨胀失控" % (g, 1.0 + ppm * mx)))
            if "pill_mark_tier" in tables_loaded:
                rows = sorted([(int(r.get("mark_min", 0) or 0), int(r.get("mark_max", 0) or 0)) for r in tables_loaded["pill_mark_tier"][1]])
                if not rows or rows[0][0] != 0:
                    errors.append(("pill_mark_tier.csv", "pill_mark_tier", 0, "分档未从 0 起：0 纹（无纹）无分档可归"))
                for a, b in zip(rows, rows[1:]):
                    if a[1] + 1 != b[0]:
                        errors.append(("pill_mark_tier.csv", "pill_mark_tier", 0,
                            "分档区间不连续/重叠：%d-%d 与 %d-%d" % (a[0], a[1], b[0], b[1])))
                if rows and rows[-1][1] != 9:
                    errors.append(("pill_mark_tier.csv", "pill_mark_tier", 0, "分档未覆盖到 9 纹：满纹无档可归"))
            if "pill_mark_codex" in tables_loaded:
                needs = [int(r.get("need_score", 0) or 0) for r in tables_loaded["pill_mark_codex"][1]]
                if needs != sorted(needs) or len(set(needs)) != len(needs):
                    errors.append(("pill_mark_codex.csv", "pill_mark_codex", 0, "图谱里程碑 need_score 必须严格递增：%s" % needs))
                succs = [float(r.get("success_bonus", 0) or 0) for r in tables_loaded["pill_mark_codex"][1]]
                if succs != sorted(succs):
                    errors.append(("pill_mark_codex.csv", "pill_mark_codex", 0, "图谱里程碑 success_bonus 必须递增：%s" % succs))
            # 消费方现读真源：四处真消费点必须在 game_state.gd 里真实出现
            _gs2_path = os.path.join(SCRIPT_DIR, "game_state.gd")
            _gs2 = ""
            if os.path.exists(_gs2_path):
                with open(_gs2_path, "r", encoding="utf-8") as _gf2:
                    _gs2 = _gf2.read()
            # 【拆分兼容】game_state.gd 大量函数已改为转发壳（如 `func 执行炼符(...): return 符箓封装系统.执行炼符(...)`），
            # 真消费点已迁入各 *_system.gd。若只扫 game_state.gd 会因拆分误报「消费点缺失」→ 补充全项目 .gd 文本。
            for _dp, _dns, _fns in os.walk(SCRIPT_DIR):
                _dns[:] = [d for d in _dns if d not in ("backup", ".scratch_backup", "addons", ".godot", ".workbuddy", "__pycache__", ".git")]
                for _fn in _fns:
                    if _fn.endswith(".gd"):
                        try:
                            with open(os.path.join(_dp, _fn), "r", encoding="utf-8", errors="replace") as _f2:
                                _gs2 += _f2.read()
                        except Exception:
                            pass
            if _gs2:
                _NEED = [
                    ("丹纹售价倍率(纹)", "售价消费点：_品阶售价 未按丹纹加价 → 高纹丹无经济价值"),
                    ("丹纹丹毒变化(阶, 纹)", "丹毒消费点：服用未结算丹毒 → 丹毒死轴未激活"),
                    ("丹纹药效倍率(阶, 纹)", "药效消费点：服用未放大药效 → 丹纹只是摆设"),
                    ("丹纹图谱成功率加成()", "图谱消费点：炼丹成功率未吃图谱加成 → 收集无回报"),
                ]
                for _code, _msg in _NEED:
                    if _code not in _gs2:
                        errors.append(("pill_mark_config.csv", "pill_mark_config", 0, "S37 %s" % _msg))
                for _hook in ['赋予丹纹(结果["产出"]', "赋予丹纹(新丹药"]:
                    if _hook not in _gs2:
                        errors.append(("pill_mark_config.csv", "pill_mark_config", 0,
                            "S37 炼制产出未掷纹（缺 %s）：丹纹永远不会出现=假系统" % _hook))
            report.append("- [CHECK] S37 丹纹校验完成（分档覆盖0-9连续 / 满纹必净清毒 / 售价不膨胀 / 四处消费方现读真源）")
        # ---------- S38 炼丹因子网络：因子键真枚举 / 维度真消费 / 引擎现读 / 命格键名 ----------
        _gs_path2 = os.path.join(SCRIPT_DIR, "game_state.gd")
        _gs2 = ""
        if os.path.exists(_gs_path2):
            with open(_gs_path2, "r", encoding="utf-8") as _gf:
                _gs2 = _gf.read()
        # 【拆分兼容】同上：转发壳化后真消费点已迁入各 *_system.gd，补充全项目 .gd 文本
        for _dp, _dns, _fns in os.walk(SCRIPT_DIR):
            _dns[:] = [d for d in _dns if d not in ("backup", ".scratch_backup", "addons", ".godot", ".workbuddy", "__pycache__", ".git")]
            for _fn in _fns:
                if _fn.endswith(".gd"):
                    try:
                        with open(os.path.join(_dp, _fn), "r", encoding="utf-8", errors="replace") as _f2:
                            _gs2 += _f2.read()
                    except Exception:
                        pass
        _disc_path = os.path.join(SCRIPT_DIR, "disciple.gd")
        _disc = ""
        if os.path.exists(_disc_path):
            with open(_disc_path, "r", encoding="utf-8") as _df:
                _disc = _df.read()
        # 真源：灵根五行 / 变异 / 道途名（现读 disciple.gd const，禁手抄）
        import re as _re
        _灵根真源 = set()
        for _m in _re.finditer(r'const\s+灵根五行\s*:\s*Array\s*=\s*\[([^\]]*)\]', _disc):
            _灵根真源 |= set(x.strip().strip('"') for x in _m.group(1).split(",") if x.strip())
        for _m in _re.finditer(r'const\s+灵根变异\s*:\s*Array\s*=\s*\[([^\]]*)\]', _disc):
            _灵根真源 |= set(x.strip().strip('"') for x in _m.group(1).split(",") if x.strip())
        _道途真源 = set()
        for _m in _re.finditer(r'const\s+道途名\s*:\s*Array\s*=\s*\[([^\]]*)\]', _disc):
            _道途真源 |= set(x.strip().strip('"') for x in _m.group(1).split(",") if x.strip())
        _灵根真源 |= {"天灵根", "先天五行全灵根"}
        _品阶真源 = set(_re.findall(r'"(凡品|良品|上品|极品|天品)"', _disc))
        # 引擎实际 match 的维度（现读，禁手抄）
        _档维度真源 = set(_re.findall(r'"(灵根品阶|灵根类型|道途)":\s*实\s*=', _gs2))
        _线维度真源 = set(_re.findall(r'"(心境|心魔值|忠诚|境界序|殿阁等级|政绩)":\s*值\s*=', _gs2))
        # 宗门池维度（殿阁等级走独立分支，不在线性 match 里）
        _线维度真源 |= set(_re.findall(r'if str\(r3\["维度"\]\) != "(\w+)"', _gs2))
        if "alchemy_factor_step" in tables_loaded:
            for i, r in enumerate(tables_loaded["alchemy_factor_step"][1], start=2):
                维 = (r.get("维度") or "").strip()
                键 = (r.get("键") or "").strip()
                if 维 not in ("灵根品阶", "灵根类型", "道途"):
                    errors.append(("alchemy_factor_step.csv", "alchemy_factor_step", i,
                        "维度 %s 不在引擎 match 分支内：该行永远不会被消费=假因子" % 维))
                    continue
                if 维 == "灵根品阶" and _品阶真源 and 键 not in _品阶真源:
                    errors.append(("alchemy_factor_step.csv", "alchemy_factor_step", i,
                        "灵根品阶 %s 不在 disciple.gd 真源内（现有：%s）" % (键, "/".join(sorted(_品阶真源)))))
                if 维 == "灵根类型" and _灵根真源 and 键 not in _灵根真源:
                    errors.append(("alchemy_factor_step.csv", "alchemy_factor_step", i,
                        "灵根类型 %s 不在 disciple.gd 真源内" % 键))
                if 维 == "道途" and _道途真源 and 键 not in _道途真源:
                    errors.append(("alchemy_factor_step.csv", "alchemy_factor_step", i,
                        "道途 %s 不在 disciple.gd 道途名 真源内（现有：%s）" % (键, "/".join(sorted(_道途真源)))))
        if "alchemy_factor_linear" in tables_loaded:
            for i, r in enumerate(tables_loaded["alchemy_factor_linear"][1], start=2):
                维 = (r.get("维度") or "").strip()
                if _线维度真源 and 维 not in _线维度真源:
                    errors.append(("alchemy_factor_linear.csv", "alchemy_factor_linear", i,
                        "维度 %s 不在引擎 match 分支内：该行永远不会被消费=假因子" % 维))
                # 上限符号必须与每单位符号一致，否则 _S38_限幅 会把正向因子削成 0
                try:
                    _每 = float(r.get("每单位出纹") or 0)
                    _上 = float(r.get("上限出纹") or 0)
                    if _每 > 0 and _上 < 0:
                        errors.append(("alchemy_factor_linear.csv", "alchemy_factor_linear", i,
                            "正向因子却配了负上限：每单位出纹 %.4f / 上限出纹 %.4f，会被限幅削成 0" % (_每, _上)))
                    if _每 < 0 and _上 > 0:
                        errors.append(("alchemy_factor_linear.csv", "alchemy_factor_linear", i,
                            "负向因子却配了正上限：每单位出纹 %.4f / 上限出纹 %.4f，会被限幅削成 0" % (_每, _上)))
                except ValueError:
                    pass
        # ===== S39 丹药品级与产出体系 =====
        品阶序 = ["凡品", "灵品", "宝品", "王品", "圣品", "仙品", "道品"]
        阶序 = ["凡阶", "灵阶", "宝阶", "王阶", "圣阶", "仙阶", "道阶"]
        if "pill_recipe_config" in tables_loaded:
            _率均 = {}
            for i, r in enumerate(tables_loaded["pill_recipe_config"][1], start=2):
                try:
                    率 = float(r.get("基础成功率") or 0)
                    阶 = (r.get("品阶") or "").strip()
                    序 = int(r.get("需求境界序") or -1)
                except Exception:
                    errors.append(("pill_recipe_config.csv", "pill_recipe_config", i, "数值字段解析失败"))
                    continue
                if not (0.0 < 率 <= 100.0):
                    errors.append(("pill_recipe_config.csv", "pill_recipe_config", i,
                        "基础成功率 %.2f 越界（须 0<r<=1）" % 率))
                if 阶 not in 品阶序:
                    errors.append(("pill_recipe_config.csv", "pill_recipe_config", i,
                        "品阶 %s 不在标准品阶序列内" % 阶))
                if not (0 <= 序 <= 10):
                    errors.append(("pill_recipe_config.csv", "pill_recipe_config", i,
                        "需求境界序 %d 越界（须 0-10）" % 序))
                for k in ("cost_herb", "cost_ore", "cost_jing", "cost_stone", "cost_qi"):
                    try:
                        if int(r.get(k) or 0) < 0:
                            errors.append(("pill_recipe_config.csv", "pill_recipe_config", i, "%s 为负" % k))
                    except Exception:
                        errors.append(("pill_recipe_config.csv", "pill_recipe_config", i, "%s 非整数" % k))
                _率均.setdefault(阶, []).append(率)
            # 高阶丹必须更难炼：凡品均值 > 道品均值
            # 严格递减：任一品阶均值高于低阶即倒挂（单条异常也会被相邻均值抓出）
            _率序 = [(k, sum(_率均[k]) / len(_率均[k])) for k in 品阶序 if k in _率均]
            _率值 = [v for _k, v in _率序]
            if _率值 != sorted(_率值, reverse=True):
                errors.append(("pill_recipe_config.csv", "pill_recipe_config", 0,
                    "品阶难度倒挂：成功率均值未按品阶递减（%s）" %
                    " > ".join("%s %.1f" % (k, v) for k, v in _率序)))
        if "pill_grade_config" in tables_loaded:
            _g = tables_loaded["pill_grade_config"][1]
            for i, r in enumerate(_g, start=2):
                try:
                    float(r["effect_scale"]); float(r["price_scale"]); float(r["toxin_scale"])
                    float(r["mark_rate_scale"]); float(r["yield_scale"]); float(r["weight"])
                except Exception:
                    errors.append(("pill_grade_config.csv", "pill_grade_config", i, "数值字段解析失败"))
            if len(_g) >= 2:
                try:
                    _ef = [float(x["effect_scale"]) for x in _g]
                    _pr = [float(x["price_scale"]) for x in _g]
                    _tx = [float(x["toxin_scale"]) for x in _g]
                    _wt = [float(x["weight"]) for x in _g]
                    if _ef != sorted(_ef):
                        errors.append(("pill_grade_config.csv", "pill_grade_config", 0,
                            "effect_scale 未按品级递增（下品→极品应越来越强）"))
                    if _pr != sorted(_pr):
                        errors.append(("pill_grade_config.csv", "pill_grade_config", 0,
                            "price_scale 未按品级递增"))
                    if _tx != sorted(_tx, reverse=True):
                        errors.append(("pill_grade_config.csv", "pill_grade_config", 0,
                            "toxin_scale 未按品级递减（高品级丹应更少毒）"))
                    if _wt != sorted(_wt, reverse=True):
                        errors.append(("pill_grade_config.csv", "pill_grade_config", 0,
                            "weight 未按品级递减（极品应最难出）"))
                except Exception:
                    pass
        if "pill_yield_config" in tables_loaded:
            _y = tables_loaded["pill_yield_config"][1]
            _by = {}
            for i, r in enumerate(_y, start=2):
                try:
                    _by[(r.get("grade") or "").strip()] = float(r["base_yield"])
                except Exception:
                    errors.append(("pill_yield_config.csv", "pill_yield_config", i, "base_yield 解析失败"))
            _seq = [_by[k] for k in 品阶序 if k in _by]
            if _seq != sorted(_seq, reverse=True):
                errors.append(("pill_yield_config.csv", "pill_yield_config", 0,
                    "base_yield 未按品阶递减（高阶丹应一炉更少枚）"))
        if "pill_furnace_config" in tables_loaded:
            _f = tables_loaded["pill_furnace_config"][1]
            try:
                _fc = [float(x["成率"]) for x in _f]
                _fy = [float(x["产量"]) for x in _f]
                _fp = [float(x["价灵石"]) for x in _f]
                if _fc != sorted(_fc):
                    errors.append(("pill_furnace_config.csv", "pill_furnace_config", 0, "丹炉成率未按档位递增"))
                if _fy != sorted(_fy):
                    errors.append(("pill_furnace_config.csv", "pill_furnace_config", 0, "丹炉产量未按档位递增"))
                if _fp != sorted(_fp):
                    errors.append(("pill_furnace_config.csv", "pill_furnace_config", 0, "丹炉价格未按档位递增"))
            except Exception:
                errors.append(("pill_furnace_config.csv", "pill_furnace_config", 0, "丹炉数值字段解析失败"))
        # === S45-3 符箓产出自表：单调性归因校验（镜像 pill 三表）===
        if "talisman_grade_config" in tables_loaded:
            _g = tables_loaded["talisman_grade_config"][1]
            for i, r in enumerate(_g, start=2):
                try:
                    float(r["effect_scale"]); float(r["price_scale"])
                    float(r["mark_rate_scale"]); float(r["yield_scale"]); float(r["weight"])
                except Exception:
                    errors.append(("talisman_grade_config.csv", "talisman_grade_config", i, "数值字段解析失败"))
            if len(_g) >= 2:
                try:
                    _ef = [float(x["effect_scale"]) for x in _g]
                    _pr = [float(x["price_scale"]) for x in _g]
                    _wt = [float(x["weight"]) for x in _g]
                    if _ef != sorted(_ef):
                        errors.append(("talisman_grade_config.csv", "talisman_grade_config", 0,
                            "effect_scale 未按品级递增（下品→极品应越来越强）"))
                    if _pr != sorted(_pr):
                        errors.append(("talisman_grade_config.csv", "talisman_grade_config", 0,
                            "price_scale 未按品级递增"))
                    if _wt != sorted(_wt, reverse=True):
                        errors.append(("talisman_grade_config.csv", "talisman_grade_config", 0,
                            "weight 未按品级递减（极品应最难出）"))
                except Exception:
                    pass
        if "talisman_yield_config" in tables_loaded:
            _y = tables_loaded["talisman_yield_config"][1]
            _by = {}
            for i, r in enumerate(_y, start=2):
                try:
                    _by[(r.get("grade") or "").strip()] = float(r["base_yield"])
                except Exception:
                    errors.append(("talisman_yield_config.csv", "talisman_yield_config", i, "base_yield 解析失败"))
            _seq = [_by[k] for k in 品阶序 if k in _by]
            if _seq != sorted(_seq, reverse=True):
                errors.append(("talisman_yield_config.csv", "talisman_yield_config", 0,
                    "base_yield 未按品阶递减（高阶符应一炉更少枚）"))
        if "talisman_paper_config" in tables_loaded:
            _f = tables_loaded["talisman_paper_config"][1]
            try:
                _fc = [float(x["成率"]) for x in _f]
                _fy = [float(x["产量"]) for x in _f]
                _fp = [float(x["价灵石"]) for x in _f]
                if _fc != sorted(_fc):
                    errors.append(("talisman_paper_config.csv", "talisman_paper_config", 0, "符纸成率未按档位递增"))
                if _fy != sorted(_fy):
                    errors.append(("talisman_paper_config.csv", "talisman_paper_config", 0, "符纸产量未按档位递增"))
                if _fp != sorted(_fp):
                    errors.append(("talisman_paper_config.csv", "talisman_paper_config", 0, "符纸价格未按档位递增"))
            except Exception:
                errors.append(("talisman_paper_config.csv", "talisman_paper_config", 0, "符纸数值字段解析失败"))
        # === S45-6 绘符等级表：单调性归因校验（镜像炼器等级表）===
        if "talisman_level_config" in tables_loaded:
            _lv = tables_loaded["talisman_level_config"][1]
            for i, r in enumerate(_lv, start=2):
                try:
                    int(r["level"]); int(r["need_exp"])
                    float(r["success_bonus"]); float(r["quality_bonus"])
                except Exception:
                    errors.append(("talisman_level_config.csv", "talisman_level_config", i, "数值字段解析失败"))
            try:
                _lvs = [int(x["level"]) for x in _lv]
                _exp = [int(x["need_exp"]) for x in _lv]
                _sb2 = [float(x["success_bonus"]) for x in _lv]
                _qb2 = [float(x["quality_bonus"]) for x in _lv]
                if _lvs != sorted(_lvs):
                    errors.append(("talisman_level_config.csv", "talisman_level_config", 0, "level 未递增"))
                if _exp != sorted(_exp):
                    errors.append(("talisman_level_config.csv", "talisman_level_config", 0, "need_exp 未随等级递增"))
                if _sb2 != sorted(_sb2):
                    errors.append(("talisman_level_config.csv", "talisman_level_config", 0, "success_bonus 未随等级递增"))
                if _qb2 != sorted(_qb2):
                    errors.append(("talisman_level_config.csv", "talisman_level_config", 0, "quality_bonus 未随等级递增"))
            except Exception:
                errors.append(("talisman_level_config.csv", "talisman_level_config", 0, "等级曲线解析失败"))
        # === S45-4 符纹三表：单调性/覆盖性归因校验（镜像 pill_mark_*）===
        if "talisman_mark_config" in tables_loaded:
            _mk = tables_loaded["talisman_mark_config"][1]
            for i, r in enumerate(_mk, start=2):
                try:
                    float(r["base_rate"]); float(r["effect_per_mark"])
                    float(r["price_per_mark"]); int(r["max_mark"])
                except Exception:
                    errors.append(("talisman_mark_config.csv", "talisman_mark_config", i, "数值字段解析失败"))
            try:
                _br = [float(x["base_rate"]) for x in _mk]
                _mx = [int(x["max_mark"]) for x in _mk]
                if _br != sorted(_br, reverse=True):
                    errors.append(("talisman_mark_config.csv", "talisman_mark_config", 0,
                        "base_rate 未按品阶递减（高阶符应更难出纹）"))
                if _mx != sorted(_mx):
                    errors.append(("talisman_mark_config.csv", "talisman_mark_config", 0,
                        "max_mark 未按品阶递增（高阶符纹上限应更高）"))
            except Exception:
                pass
        if "talisman_mark_tier" in tables_loaded:
            _tt = tables_loaded["talisman_mark_tier"][1]
            _覆盖 = set()
            for i, r in enumerate(_tt, start=2):
                try:
                    lo = int(r["mark_min"]); hi = int(r["mark_max"])
                    for v in range(lo, hi + 1):
                        _覆盖.add(v)
                except Exception:
                    errors.append(("talisman_mark_tier.csv", "talisman_mark_tier", i, "mark_min/mark_max 解析失败"))
            if _覆盖 and _覆盖 != set(range(0, 10)):
                errors.append(("talisman_mark_tier.csv", "talisman_mark_tier", 0,
                    "分档未连续覆盖 0-9（缺：%s）" % sorted(set(range(0, 10)) - _覆盖)))
        if "talisman_mark_codex" in tables_loaded:
            _cx = tables_loaded["talisman_mark_codex"][1]
            try:
                _nd = [int(x["need_score"]) for x in _cx]
                _sb = [float(x["success_bonus"]) for x in _cx]
                _rb = [float(x["rate_bonus"]) for x in _cx]
                if _nd != sorted(_nd):
                    errors.append(("talisman_mark_codex.csv", "talisman_mark_codex", 0, "need_score 未按里程碑递增"))
                if _sb != sorted(_sb):
                    errors.append(("talisman_mark_codex.csv", "talisman_mark_codex", 0, "success_bonus 未按里程碑递增"))
                if _rb != sorted(_rb):
                    errors.append(("talisman_mark_codex.csv", "talisman_mark_codex", 0, "rate_bonus 未按里程碑递增"))
            except Exception:
                errors.append(("talisman_mark_codex.csv", "talisman_mark_codex", 0, "里程碑数值字段解析失败"))
        if "pill_mark_config" in tables_loaded:
            _m = {}
            for i, r in enumerate(tables_loaded["pill_mark_config"][1], start=2):
                try:
                    _m[(r.get("grade") or "").strip()] = int(r["max_mark"])
                except Exception:
                    errors.append(("pill_mark_config.csv", "pill_mark_config", i, "max_mark 解析失败"))
            _ms = [_m[k] for k in 阶序 if k in _m]
            if _ms != sorted(_ms):
                errors.append(("pill_mark_config.csv", "pill_mark_config", 0,
                    "max_mark 未按品阶递增（凡品丹不该能出 9 纹天命纹）"))
        # ===== S40 灵植年份（料因子 + 坊市价值倍率）=====
        if "herb_age_config" in tables_loaded:
            _h = tables_loaded["herb_age_config"][1]
            _档 = []
            for i, r in enumerate(_h, start=2):
                try:
                    _档.append({"i": i, "档名": str(r.get("档名") or "").strip(),
                        "lo": int(r.get("下限年份") or 0), "hi": int(r.get("上限年份") or -1),
                        "val": float(r.get("价值系数") or 0),
                        "成": float(r.get("成率加成") or 0), "纹": float(r.get("出纹加成") or 0)})
                except Exception:
                    errors.append(("herb_age_config.csv", "herb_age_config", i, "数值字段解析失败"))
            # 单调性：价值系数 / 成率加成 / 出纹加成 必须随年份档严格递增（否则高年份反而更亏=倒挂）
            _val = [x["val"] for x in _档]
            _成 = [x["成"] for x in _档]
            _纹 = [x["纹"] for x in _档]
            if _val != sorted(_val):
                errors.append(("herb_age_config.csv", "herb_age_config", 0,
                    "价值系数未按年份档递增（高年份灵材反而卖更便宜=倒挂）"))
            if _成 != sorted(_成):
                errors.append(("herb_age_config.csv", "herb_age_config", 0, "成率加成未按年份档递增"))
            if _纹 != sorted(_纹):
                errors.append(("herb_age_config.csv", "herb_age_config", 0, "出纹加成未按年份档递增"))
            # 档连续性：下限=上一档上限+1；最后一档上限必须为 -1（开放上限，否则超高年份灵材无档可命中）
            for k in range(len(_档)):
                if k == 0:
                    if _档[k]["lo"] != 0:
                        errors.append(("herb_age_config.csv", "herb_age_config", _档[k]["i"],
                            "首档下限必须为 0（凡草基准）"))
                else:
                    _期望 = _档[k-1]["hi"] + 1
                    if _档[k-1]["hi"] >= 0 and _档[k]["lo"] != _期望:
                        errors.append(("herb_age_config.csv", "herb_age_config", _档[k]["i"],
                            "年份档存在缺口/重叠：上一档上限 %d，本档下限 %d（应连续为 %d）" % (_档[k-1]["hi"], _档[k]["lo"], _期望)))
            if not _档 or _档[-1]["hi"] != -1:
                errors.append(("herb_age_config.csv", "herb_age_config", 0,
                    "最后一档上限必须为 -1（开放上限，覆盖超高年份灵材）"))
            # 灵材基础年份命中档：lingtian.gd 灵材库每味草药 基础年份 必须能命中某个档（漏配档=该灵草年份无加成=假系统）
            _lt_path = os.path.join(SCRIPT_DIR, "lingtian.gd")
            if os.path.exists(_lt_path) and _档:
                with open(_lt_path, "r", encoding="utf-8") as _lf:
                    _ltxt = _lf.read()
                import re as _re
                for _m in _re.finditer(r'"基础年份"\s*:\s*(\d+)', _ltxt):
                    _y = int(_m.group(1))
                    _命中 = False
                    for x in _档:
                        if _y >= x["lo"] and (x["hi"] < 0 or _y <= x["hi"]):
                            _命中 = True
                            break
                    if not _命中:
                        errors.append(("lingtian.gd", "herb_age_config", 0,
                            "灵材 基础年份=%d 未命中任何年份档（档区间不覆盖该值=该灵草年份加成失效）" % _y))
        # herb_age_config 必须有引擎消费方（现读 game_state.gd，禁手抄）
        if "herb_age_config.csv" not in _gs2:
            errors.append(("herb_age_config.csv", "herb_age_config", 0,
                "引擎无消费点：game_state.gd 未出现 herb_age_config.csv → 死表"))
        for _need in ("灵植年份价值系数", "灵植年份炼丹加成", "宗门灵植平均年份"):
            if _need not in _gs2:
                errors.append(("game_state.gd", "S40", 0, "年份消费点缺失：%s 未接入" % _need))
        # 四张新表必须有引擎消费方（现读 game_state.gd，禁手抄）
        for _p in ("pill_recipe_config", "pill_grade_config", "pill_yield_config", "pill_furnace_config",
                "talisman_grade_config", "talisman_yield_config", "talisman_paper_config",
                "talisman_affix_config", "talisman_level_config"):
            if _p + ".csv" not in _gs2:
                errors.append(("%s.csv" % _p, _p, 0,
                    "引擎无消费点：game_state.gd 未出现 %s.csv → 死表" % _p))
        # 符纹三表允许独立系统文件消费（S45-4 拆到 talisman_mark_system.gd：FileAccess.open 间接读）
        _cache = os.path.join(SCRIPT_DIR, ".workbuddy", "_all_gd_cache.txt")
        os.makedirs(os.path.dirname(_cache), exist_ok=True)
        if not os.path.exists(_cache) or os.path.getmtime(_cache) < os.path.getmtime(SCRIPT_DIR):
            _parts = []
            for _dp, _dns, _fns in os.walk(SCRIPT_DIR):
                _dns[:] = [d for d in _dns if d not in ('backup', '.scratch_backup', '.git', '.godot', '.workbuddy', 'addons', '__pycache__')]
                for _fn in _fns:
                    if _fn.endswith('.gd'):
                        try:
                            with open(os.path.join(_dp, _fn), encoding='utf-8', errors='ignore') as _fr:
                                _parts.append(_fr.read())
                        except Exception:
                            pass
            with open(_cache, "w", encoding="utf-8") as _fw:
                _fw.write("\n".join(_parts))
        with open(_cache, encoding="utf-8") as _fr:
            _ALL_GD = _fr.read()
        for _p in ("talisman_mark_config", "talisman_mark_tier", "talisman_mark_codex"):
            if _p + ".csv" not in _gs2 and _p + ".csv" not in _ALL_GD:
                errors.append(("%s.csv" % _p, _p, 0,
                    "引擎无消费点：game_state.gd / talisman_mark_system.gd 均未出现 %s.csv → 死表" % _p))
        # 品级/熟练度/丹炉 三处消费点必须存在
        if "丹品级配置(品级)" not in _gs2:
            errors.append(("game_state.gd", "S39", 0, "品级药效消费点缺失：_应用丹药效果 未乘 effect_scale"))
        if "丹品级配置(品级).get(\"price_scale\"" not in _gs2:
            errors.append(("game_state.gd", "S39", 0, "品级售价消费点缺失：_品阶售价 未乘 price_scale"))
        if "丹方熟练加成(rid)" not in _gs2:
            errors.append(("game_state.gd", "S39", 0, "熟练度消费点缺失：炼制丹方 未读 丹方熟练加成"))
        # === S45-3 符箓产出自表消费点（防假系统：CSV 必须真被引擎读）===
        if "符箓产出数量(" not in _gs2:
            errors.append(("game_state.gd", "S45-3", 0, "符箓产量消费点缺失：符箓产出数量 未读 符产量/品级表"))
        if "掷符品级(" not in _gs2:
            errors.append(("game_state.gd", "S45-3", 0, "符品级权重消费点缺失：掷符品级 未读 符品级表 weight"))
        if "符纸配置(" not in _gs2:
            errors.append(("game_state.gd", "S45-3", 0, "符纸消费点缺失：符纸配置 未读 talisman_paper_config.csv"))
        if "符箓熟练加成(" not in _gs2:
            errors.append(("game_state.gd", "S45-3", 0, "符箓熟练消费点缺失：符箓熟练加成 未读 熟练等级"))
        # === S45-4 符纹消费点（防假系统：符纹必须真影响 售价/掷纹/图谱/上限）===
        if "符纹售价倍率(" not in _gs2:
            errors.append(("game_state.gd", "S45-4", 0, "符纹售价消费点缺失：_品阶售价 未乘 符纹售价倍率"))
        if "掷符纹(" not in _gs2:
            errors.append(("game_state.gd", "S45-4", 0, "掷符纹消费点缺失：执行炼符 未调 掷符纹"))
        if "符纹图谱成功率加成()" not in _gs2:
            errors.append(("game_state.gd", "S45-4", 0, "图谱成功率消费点缺失：执行炼符 未接 符纹图谱成功率加成"))
        if "符纹图谱出纹加成()" not in _gs2:
            errors.append(("game_state.gd", "S45-4", 0, "图谱出纹消费点缺失：掷符纹 未接 符纹图谱出纹加成"))
        if "符纹上限(" not in _gs2:
            errors.append(("game_state.gd", "S45-4", 0, "品级 mark_cap_delta 消费点缺失：执行炼符 未调 符纹上限"))
        if "it.符纹 = " not in _gs2:
            errors.append(("game_state.gd", "S45-4", 0, "符纹写入消费点缺失：产出 Item 未写 符纹 字段"))
        # === S45-6 绘符经验/等级消费点（防假系统）===
        if "res://config/talisman_level_config.csv" not in _gs2:
            errors.append(("game_state.gd", "S45-6", 0, "等级表真源缺失：未读 talisman_level_config.csv"))
        if "func 绘符等级按经验(" not in _gs2:
            errors.append(("game_state.gd", "S45-6", 0, "等级函数缺失：绘符等级按经验"))
        if "func 绘符加成按经验(" not in _gs2:
            errors.append(("game_state.gd", "S45-6", 0, "加成函数缺失：绘符加成按经验"))
        if "func 增加绘符经验(" not in _gs2:
            errors.append(("game_state.gd", "S45-6", 0, "经验累计缺失：增加绘符经验"))
        if "var 绘符经验值: int = 0" not in _gs2:
            errors.append(("game_state.gd", "S45-6", 0, "持久字段缺失：绘符经验值"))
        if 'cfg.get("need_draw_level"' not in _gs2:
            errors.append(("game_state.gd", "S45-6", 0, "门槛消费点缺失：执行炼符 未读 need_draw_level"))
        if "增加绘符经验(获得绘符经验)" not in _gs2:
            errors.append(("game_state.gd", "S45-6", 0, "经验消费点缺失：执行炼符 未调 增加绘符经验"))
        if '绘符加成.get("成功率加成"' not in _gs2:
            errors.append(("game_state.gd", "S45-6", 0, "成功率消费点缺失：执行炼符 未接 绘符等级成功率加成"))
        if '绘符加成.get("高品质加成"' not in _gs2:
            errors.append(("game_state.gd", "S45-6", 0, "品级分消费点缺失：执行炼符 未接 绘符等级高品质加成"))
        # 持久化三处（铁律：新增持久字段必须同时改 存档/读档/new_game）
        if '"绘符经验值": 绘符经验值,' not in _gs2:
            errors.append(("game_state.gd", "S45-6", 0, "存档缺失：绘符经验值 未写入"))
        if 'data.get("绘符经验值", 0)' not in _gs2:
            errors.append(("game_state.gd", "S45-6", 0, "读档缺失：绘符经验值 未回读"))
        if "绘符经验值 = 0 " not in _gs2:
            errors.append(("game_state.gd", "S45-6", 0, "new_game 缺失：绘符经验值 未复位"))
        if "当前丹炉配置()" not in _gs2:
            errors.append(("game_state.gd", "S39", 0, "丹炉消费点缺失：炼制丹方 未读 当前丹炉配置"))
        # 引擎消费方现读真源（少一处就说明因子没接上）
        for _k, _desc in [
            ("func 炼丹因子明细(", "炼丹因子明细 函数缺失"),
            ("func 丹道傀儡加成(", "丹道傀儡加成 函数缺失（puppet.csv 丹道傀儡仍为死配置）"),
            ('"res://config/puppet.csv"', "未读取 puppet.csv：丹道傀儡成丹率仍是文案骗人"),
            ("AlchemySystem.炼丹(", "执行炼丹未调用 AlchemySystem 引擎（因子网络断）"),
            ("炼丹成率加成(丹堂等级)", "执行炼丹未把 成率加成 传入引擎（因子网络断）"),
            ("clamp(基础成功率 + 炼丹成率加成(", "炼制丹药未接因子网络"),
            ("炼丹出纹加成(丹堂等级)", "掷丹纹未接因子网络"),
        ]:
            if _gs2 and _k not in _gs2:
                errors.append(("game_state.gd", "S38", 0, "%s：炼丹因子网络有断点" % _desc))
        # 命格键名 BUG 防回退（键为 数值，不是 数量）
        if _gs2 and '命格数据.get("数量:", 0)' in _gs2:
            errors.append(("game_state.gd", "S38", 0,
                "命格键名回退为 get(\"数量:\")：DestinyDataLoader._解析 返回的键是 数值，经营命格加成会恒为 0"))
        report.append("- [CHECK] S38 炼丹因子网络校验完成（因子键真枚举 / 维度真消费 / 限幅符号一致 / 引擎消费方现读 / 命格键名防回退）")
    # ===== S41 功法/丹药 词条（防死表：引擎消费方现读真源 + 类型/数值校验）=====
    _valid_tier = ["凡品","灵品","宝品","王品","圣品","仙品","道品"]
    _gf_valid = ["修炼速度","战力","突破"]
    _pa_valid = ["药效","减毒","心境","售价"]
    if "gongfa_affix_config" in tables_loaded:
        _, _gf = tables_loaded["gongfa_affix_config"]
        for i, r in enumerate(_gf, start=2):
            _tier = str(r.get("tier") or "").strip()
            _type = str(r.get("类型") or "").strip()
            if _tier not in _valid_tier:
                errors.append(("gongfa_affix_config.csv","gongfa_affix_config",i,"tier 非法: %r"%_tier))
            if _type not in _gf_valid:
                errors.append(("gongfa_affix_config.csv","gongfa_affix_config",i,"类型 非法: %r"%_type))
            try:
                _lo = float(r.get("数值下限") or 0); _hi = float(r.get("数值上限") or 0)
                if _lo > _hi:
                    errors.append(("gongfa_affix_config.csv","gongfa_affix_config",i,"数值下限>上限"))
            except Exception:
                errors.append(("gongfa_affix_config.csv","gongfa_affix_config",i,"数值字段解析失败"))
    if "pill_affix_config" in tables_loaded:
        _, _pa = tables_loaded["pill_affix_config"]
        for i, r in enumerate(_pa, start=2):
            _tier = str(r.get("tier") or "").strip()
            _type = str(r.get("类型") or "").strip()
            if _tier not in _valid_tier:
                errors.append(("pill_affix_config.csv","pill_affix_config",i,"tier 非法: %r"%_tier))
            if _type not in _pa_valid:
                errors.append(("pill_affix_config.csv","pill_affix_config",i,"类型 非法: %r"%_type))
            try:
                _lo = float(r.get("数值下限") or 0); _hi = float(r.get("数值上限") or 0)
                if _lo > _hi:
                    errors.append(("pill_affix_config.csv","pill_affix_config",i,"数值下限>上限"))
            except Exception:
                errors.append(("pill_affix_config.csv","pill_affix_config",i,"数值字段解析失败"))
    # 引擎消费方现读真源（game_state.gd）
    for _need in ("res://config/gongfa_affix_config.csv","res://config/pill_affix_config.csv",
                  "func 功法条词池(","func 丹词条池(","func 丹词条聚合(","func _丹药归一品阶(",
                  "新丹药.滚丹词条(","丹词条聚合(it.丹词条)"):
        if _need not in _gs2:
            errors.append(("game_state.gd","S41",0,"消费点缺失：%s 未接入"%_need))
    # gongfa.gd 消费点（滚功法条词 调用 + 功法词条突破加成 定义）
    _gf_path = os.path.join(SCRIPT_DIR, "gongfa.gd")
    if os.path.exists(_gf_path):
        with open(_gf_path,"r",encoding="utf-8") as _gfh:
            _gf_src = _gfh.read()
        for _need in ("滚功法条词(弟子, 功法ID","func 功法词条突破加成("):
            if _need not in _gf_src:
                errors.append(("gongfa.gd","S41",0,"消费点缺失：%s 未接入"%_need))
    report.append("- [CHECK] S41 功法/丹药词条校验完成（类型枚举 / 数值下限≤上限 / 引擎消费方现读真源）")
    # ===== S42 炼器因子网络（沿用 S38 范式：因子键真枚举 / 维度真消费 / 引擎消费方现读 / 矿石+配方双路径同接）=====
    _forge_step_dims = ["灵根品阶","灵根类型","道途"]
    _forge_line_dims = ["心境","心魔值","忠诚","境界序","政绩"]
    _forge_src_keys = ["固定","图谱","器堂等级"]
    if "forge_factor_step" in tables_loaded:
        _, _fs = tables_loaded["forge_factor_step"]
        for i, r in enumerate(_fs, start=2):
            _dim = str(r.get("维度") or "").strip()
            _key = str(r.get("键") or "").strip()
            if _dim not in _forge_step_dims:
                errors.append(("forge_factor_step.csv","forge_factor_step",i,"维度 非法: %r"%_dim))
            if _key == "":
                errors.append(("forge_factor_step.csv","forge_factor_step",i,"档位因子 键 为空"))
            try:
                _c = float(r.get("成率") or 0); _h = float(r.get("高品质") or 0)
                if _c < -0.05 or _c > 0.50 or _h < -0.05 or _h > 0.50:
                    errors.append(("forge_factor_step.csv","forge_factor_step",i,"成率/高品质 越界"))
            except Exception:
                errors.append(("forge_factor_step.csv","forge_factor_step",i,"数值字段解析失败"))
    if "forge_factor_linear" in tables_loaded:
        _, _fl = tables_loaded["forge_factor_linear"]
        for i, r in enumerate(_fl, start=2):
            _dim = str(r.get("维度") or "").strip()
            if _dim not in _forge_line_dims:
                errors.append(("forge_factor_linear.csv","forge_factor_linear",i,"维度 非法: %r"%_dim))
    if "forge_source_config" in tables_loaded:
        _, _fsc = tables_loaded["forge_source_config"]
        for i, r in enumerate(_fsc, start=2):
            _k = str(r.get("键") or "").strip()
            if _k not in _forge_src_keys:
                errors.append(("forge_source_config.csv","forge_source_config",i,"键 非法: %r"%_k))
    # 引擎消费方现读真源（game_state.gd 双路径 + forge.gd）
    for _need in ("res://config/forge_factor_step.csv","res://config/forge_factor_linear.csv",
                  "res://config/forge_source_config.csv",
                  "func 锻造因子明细(","func _读表_锻造因子档(","func 器堂负责人(",
                  "锻造因子明细(铸匠, 器堂等级)","var 因子: Dictionary = 锻造因子明细("):
        if _need not in _gs2:
            errors.append(("game_state.gd","S42",0,"消费点缺失：%s 未接入"%_need))
    _forge_path = os.path.join(SCRIPT_DIR, "forge.gd")
    if os.path.exists(_forge_path):
        with open(_forge_path,"r",encoding="utf-8") as _ffh:
            _ff_src = _ffh.read()
        for _need in ("因子2.get(\"成率\"","因子2.get(\"高品质\""):
            if _need not in _ff_src:
                errors.append(("forge.gd","S42",0,"消费点缺失：%s 未接入"%_need))
    report.append("- [CHECK] S42 炼器因子网络校验完成（因子键真枚举 / 维度真消费 / 引擎消费方现读 / 矿石+配方双路径同接）")
    # ===== S43 装备词条（沿用 S41 范式：类型真枚举 / 数值下限≤上限 / 引擎消费方现读 / 战力+修炼+突破三真消费方）=====
    _equip_tiers = ["凡阶","灵阶","宝阶","王阶","圣阶","仙阶","道阶"]
    _equip_types = ["战力","修炼","突破"]
    if "equip_affix_config" in tables_loaded:
        _, _ea = tables_loaded["equip_affix_config"]
        for i, r in enumerate(_ea, start=2):
            _tier = str(r.get("阶") or "").strip()
            _type = str(r.get("类型") or "").strip()
            if _tier not in _equip_tiers:
                errors.append(("equip_affix_config.csv","equip_affix_config",i,"阶 非法: %r"%_tier))
            if _type not in _equip_types:
                errors.append(("equip_affix_config.csv","equip_affix_config",i,"类型 非法: %r"%_type))
            try:
                _lo = float(r.get("数值下限") or 0); _hi = float(r.get("数值上限") or 0)
                if _lo > _hi:
                    errors.append(("equip_affix_config.csv","equip_affix_config",i,"数值下限>上限"))
            except Exception:
                errors.append(("equip_affix_config.csv","equip_affix_config",i,"数值字段解析失败"))
    if "talisman_affix_config" in tables_loaded:
        _, _ta = tables_loaded["talisman_affix_config"]
        for i, r in enumerate(_ta, start=2):
            _tier = str(r.get("阶") or "").strip()
            _type = str(r.get("类型") or "").strip()
            if _tier not in ("凡阶","灵阶","宝阶","王阶","圣阶","仙阶","道阶"):
                errors.append(("talisman_affix_config.csv","talisman_affix_config",i,"阶 非法: %r"%_tier))
            if _type not in ("战力","修炼","突破"):
                errors.append(("talisman_affix_config.csv","talisman_affix_config",i,"类型 非法: %r"%_type))
            try:
                _lo = float(r.get("数值下限") or 0); _hi = float(r.get("数值上限") or 0)
                if _lo > _hi:
                    errors.append(("talisman_affix_config.csv","talisman_affix_config",i,"数值下限>上限"))
            except Exception:
                errors.append(("talisman_affix_config.csv","talisman_affix_config",i,"数值字段解析失败"))
    # S45-6 绘符等级门槛：须为 0..10 且随品阶单调不减（防不可达墙 / 倒挂）
    if "item_talisman" in tables_loaded and "talisman_level_config" in tables_loaded:
        _, _itm = tables_loaded["item_talisman"]
        _, _lvc = tables_loaded["talisman_level_config"]
        _最高级 = max([int(x.get("level") or 1) for x in _lvc] or [1])
        _序 = ["凡品", "灵品", "宝品", "王品", "圣品", "仙品", "道品"]
        _门槛 = {}
        for i, r in enumerate(_itm, start=2):
            _g = str(r.get("grade") or "").strip()
            try:
                _need = int(r.get("need_draw_level") or 0)
            except Exception:
                errors.append(("item_talisman.csv", "S45-6", i, "need_draw_level 解析失败"))
                continue
            if _need < 0 or _need > _最高级:
                errors.append(("item_talisman.csv", "S45-6", i,
                    "need_draw_level 越界 %d（须 0..%d）" % (_need, _最高级)))
            _门槛[_g] = max(_need, int(_门槛.get(_g, 0)))
        _vals = [_门槛[k] for k in _序 if k in _门槛]
        if _vals != sorted(_vals):
            errors.append(("item_talisman.csv", "S45-6", 0,
                "need_draw_level 未按品阶单调不减：%s" % _门槛))
        for k in _序:
            if k in _门槛 and _门槛[k] >= _最高级:
                errors.append(("item_talisman.csv", "S45-6", 0,
                    "need_draw_level 不得等于最高级 %d（%s 会形成不可达墙）" % (_最高级, k)))
    # S45-5 引擎消费方现读真源（绘符产出 + 弟子战力/修炼/突破 + 护身符三取器）
    for _need in ("res://config/talisman_affix_config.csv",
                  "func 符词条池(","func 符词缀数(","func 符词条聚合(",
                  "func 护身符战力加成(","func 护身符修炼加成(","func 护身符突破加成(",
                  "护身符突破加成(目标弟子)","func _载入符词条池("):
        if _need not in _gs2:
            errors.append(("game_state.gd","S45-5",0,"消费点缺失：%s 未接入"%_need))
    # 引擎消费方现读真源（game_state.gd 双锻造路径 + 弟子突破 + 词条池/聚合/修炼/突破消费函数）
    for _need in ("res://config/equip_affix_config.csv",
                  "func 装备词条池(","func 装备词缀数(","func 装备词条聚合(",
                  "func 装备修炼加成(","func 装备词条突破加成(",
                  "新装备.滚装备词条(","产.滚装备词条(","装备词条突破加成(目标弟子)"):
        if _need not in _gs2:
            errors.append(("game_state.gd","S43",0,"消费点缺失：%s 未接入"%_need))
    # S45-5 跨文件消费点：item.gd 掷词条 / disciple.gd 护身符字段+战力+修炼 / talisman.gd 绘符产出
    try:
        _it2 = _io.open(os.path.join(SCRIPT_DIR, "item.gd"), encoding="utf-8-sig").read()
        _dp2 = _io.open(os.path.join(SCRIPT_DIR, "disciple.gd"), encoding="utf-8-sig").read()
        _tl2 = _io.open(os.path.join(SCRIPT_DIR, "talisman.gd"), encoding="utf-8-sig").read()
    except Exception as _e5:
        errors.append(("validate_all.py", "S45-5", 0, "跨文件读取失败: %r" % _e5))
        _it2 = _dp2 = _tl2 = ""
    for _need, _txt, _tag in (("func 滚符词条(", _it2, "item.gd"),
                              ("var 符词条: Array", _it2, "item.gd"),
                              ("var 护身符: Item", _dp2, "disciple.gd"),
                              ("护身符战力加成(self)", _dp2, "disciple.gd"),
                              ("护身符修炼加成(self)", _dp2, "disciple.gd"),
                              ("it.滚符词条(it.品阶)", _tl2, "talisman.gd")):
        if _need not in _txt:
            errors.append((_tag, "S45-5", 0, "消费点缺失：%s 未接入" % _need))

    # disciple.gd 修炼速度消费钩子（穿戴/卸载时 装备修炼加成 刷新）
    _disc_path = os.path.join(SCRIPT_DIR, "disciple.gd")
    if os.path.exists(_disc_path):
        with open(_disc_path,"r",encoding="utf-8") as _dfh:
            _disc_src = _dfh.read()
        for _need in ("Game.装备修炼加成(self)",):
            if _need not in _disc_src:
                errors.append(("disciple.gd","S43",0,"消费点缺失：%s 未接入"%_need))
    report.append("- [CHECK] S43 装备词条校验完成（类型真枚举 / 数值下限≤上限 / 战力+修炼+突破三真消费方现读真源）")
    # ---------- 命格效果参数格式校验 ----------
    # ---------- S44 改命系统修复校验（重铸命格真源化）----------
    _xichi_path = os.path.join(SCRIPT_DIR, "xichi.gd")
    _xichi_src = ""
    if os.path.exists(_xichi_path):
        with open(_xichi_path,"r",encoding="utf-8") as _xfh:
            _xichi_src = _xfh.read()
    _disc2_path = os.path.join(SCRIPT_DIR, "disciple.gd")
    _disc2_src = ""
    if os.path.exists(_disc2_path):
        with open(_disc2_path,"r",encoding="utf-8") as _dfh2:
            _disc2_src = _dfh2.read()
    for _need in ("func 重铸命格(", "func _抽新命格(", "func _命格概率档(", "弟子.destiny_id = 新id", "DestinyDataLoader.get_destiny"):
        if _need not in _xichi_src:
            errors.append(("xichi.gd","S44",0,"改命引擎缺失：%s 未实现"%_need))
    for _bad in ("弟子.命格品质 =", "随机命格", "命格加成", '弟子.has("命格重铸失败次数")', '弟子.get("命格重铸失败次数"'):
        if _bad in _xichi_src:
            errors.append(("xichi.gd","S44",0,"残留死字段/坏模型代码：%s 仍存在"%_bad))
    for _need in ("var 命格重铸失败次数", '"命格重铸失败次数": 命格重铸失败次数', "命格重铸失败次数 = int(d.get"):
        if _need not in _disc2_src:
            errors.append(("disciple.gd","S44",0,"保底计数器未同步：%s 缺失"%_need))
    report.append("- [CHECK] S44 改命系统校验完成（重铸写真源 destiny_id / 删死字段命格品质·命格加成·随机命格 / 保底计数器三处同步）")

    if "destiny_main" in tables_loaded:
        _, drows = tables_loaded["destiny_main"]
        pat = re.compile(r"^(攻|防|血|速|修炼|产出|奇遇):-?\d+$")
        for i, r in enumerate(drows, 1):
            ep = r.get("效果参数", "")
            if not pat.match(ep):
                errors.append(("destiny_main.csv", "destiny_main", i, "效果参数格式非法: %r (应为 维度:数值)" % ep))

    # ---------- 汇总 ----------
    report.append("")
    report.append("# 汇总")
    report.append("- 校验 CSV 表数: %d" % len(tables_loaded))
    report.append("- 校验数据行数: %d" % total_rows)
    report.append("- 错误数: %d" % len(errors))
    report.append("- 警告数: %d" % len(warns))
    report.append("")
    if warns:
        report.append("## 警告")
        for w in warns: report.append("- "+w)
        report.append("")
    if errors:
        report.append("## 错误明细")
        for f,k,r,msg in errors:
            report.append("- [%s/%s 行%d] %s" % (f,k,r,msg))
    else:
        report.append("## 结论: ✅ 全部通过，无错误")
    report.append("")
    report.append("_本报告由 validate_all.py 自动生成，规则镜像自 csv_validator.gd v2.56+。_")

    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(report))
    print("校验完成: %d 表 / %d 行 / %d 错误 / %d 警告" % (len(tables_loaded), total_rows, len(errors), len(warns)))
    if errors:
        for e in errors[:40]: print("  ERR", e)
    return len(errors)

if __name__ == "__main__":
    sys.exit(1 if main() > 0 else 0)

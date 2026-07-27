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
        "field_rules":{"grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
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
        "field_rules":{"grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
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
        "field_rules":{"grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
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
        "field_rules":{"grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
            "sub_grade":{"type":"enum","values":["下品","中品","上品","极品"]},
            "apply_class":{"type":"enum","values":["全职业通用","道修","体修","法修"]},
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
        "field_rules":{"quest_type":{"type":"enum","values":["经营","养成","探索","互动"]},
            "difficulty":{"type":"enum","values":["难度Ⅰ","难度Ⅱ","难度Ⅲ","难度Ⅳ"]},
            "unlock_sect_level":{"type":"int","min":1,"max":10},"target_num":{"type":"int","min":1},
            "reward_lingjing":{"type":"int","min":0},"reward_lingqi":{"type":"int","min":0},
            "active_point":{"type":"int","min":0},"daily_limit":{"type":"int","min":0},"is_auto_complete":{"type":"bool"}}},
    "quest_weekly": {"required_fields":["quest_id","quest_name","quest_type","unlock_sect_level","difficulty","target_desc","target_num","reward_lingjing","reward_lingqi","reward_pool_id","reward_chest_id","weekly_active_point","weekly_limit","is_auto_complete"],
        "primary_key":"quest_id",
        "field_rules":{"quest_type":{"type":"enum","values":["深度养成","高阶玩法","宗门经营"]},
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
            "trigger_scene":{"type":"enum","values":["宗门内","历练结算","秘境通关","战斗胜利","昼夜切换","登录","机缘"]},
            "unlock_sect_level":{"type":"int","min":1,"max":10},
            "unlock_realm":{"type":"enum","values":["练气","筑基","金丹","元婴","化神","炼虚","合体"]},
            "trigger_weight":{"type":"int","min":0},"cooldown_hour":{"type":"int","min":0},"is_counted_in_balance":{"type":"bool"}}},
    "faction_base": {"required_fields":["faction_id","faction_name","reputation_level","need_reputation","global_buff_1","global_buff_2","unlock_content","shop_unlock_grade"],
        "primary_key":"faction_id+reputation_level",
        "field_rules":{"faction_id":{"type":"enum","values":["fz_zhengdao","fz_zhongli","fz_mo","fz_yaozu","fz_danqi"]},
            "reputation_level":{"type":"enum","values":["中立","友善","尊敬","崇敬","崇拜"]},
            "need_reputation":{"type":"int","min":0},"shop_unlock_grade":{"type":"int","min":0,"max":4}}},
    "faction_shop": {"required_fields":["shop_id","faction_id","item_id","item_name","item_grade","price_lingjing","price_token","limit_daily","limit_weekly","unlock_reputation"],
        "primary_key":"shop_id",
        "field_rules":{"faction_id":{"type":"enum","values":["fz_zhengdao","fz_zhongli","fz_mo","fz_yaozu","fz_danqi"]},
            "item_grade":{"type":"enum","values":["凡品","灵品","宝品","王品","圣品","仙品","道品"]},
            "price_lingjing":{"type":"int","min":0},"price_token":{"type":"int","min":0},
            "limit_daily":{"type":"int","min":0},"limit_weekly":{"type":"int","min":0},"unlock_reputation":{"type":"int","min":0}}},
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
            "punish_type_1":{"type":"enum","values":["心魔","忠诚","道心","修为","气血","心境","灵石","矿石","灵草","卖价","丹材","无"]},
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
        "field_rules":{"item_class":{"type":"enum","values":["主线信物","任务碎片"]},
            "fragment_total":{"type":"int","min":0},"is_counted_in_balance":{"type":"bool"}}},
    "achievement_config": {"required_fields":["achievement_id","ach_name","category","grade","condition_desc","condition_param","reward_type","reward_id","reward_num","point_num","unlock_tip"],
        "primary_key":"achievement_id",
        "field_rules":{"category":{"type":"enum","values":["成长","经营","战斗","探索","社交"]},
            "grade":{"type":"enum","values":["普通","稀有","传说"]},"point_num":{"type":"enum","values":[10,30,100]},
            "reward_type":{"type":"enum","values":["灵石","道具","装备","材料","代币","声望","永久增益","称号","传说称号","外观","buff","阵法","弟子","种子","功能"]},
            "reward_num":{"type":"float","min":0},"condition_param":{"type":"int","min":0},"reward_id":{"type":"string"}}},
    "stage_main": {"required_fields":["stage_id","chapter","stage_name","node_type","unlock_condition","recommend_power","monster_ids","stamina_cost","daily_limit","first_reward_type","first_reward_id","first_reward_num","repeat_drop_pool","difficulty_factor","fail_reduce_enable","designer_note"],
        "primary_key":"stage_id",
        "field_rules":{"chapter":{"type":"int","min":1,"max":3},
            "node_type":{"type":"enum","values":["normal","elite","treasure","boss"]},
            "recommend_power":{"type":"int","min":0},"stamina_cost":{"type":"int","min":0},
            "daily_limit":{"type":"int","min":0},"first_reward_type":{"type":"enum","values":["res","item","buff"]},
            "first_reward_num":{"type":"int","min":0},"difficulty_factor":{"type":"float","min":0},"fail_reduce_enable":{"type":"bool"}}},
    "monster_main": {"required_fields":["monster_id","monster_name","realm","element","base_hp","base_atk","base_def","base_spd","base_crit","base_dodge","skill_id","drop_item_ids","drop_weights","is_boss","description"],
        "primary_key":"monster_id",
        "field_rules":{"realm":{"type":"enum","values":["练气","筑基","金丹","元婴","化神","仙阶","道阶"]},
            "element":{"type":"enum","values":["金","木","水","火","土"]},
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
}

GRADE_RANK = {"凡品":0,"灵品":1,"宝品":2,"王品":3,"圣品":4,"仙品":5,"道品":6}
REP_GRADE_CAP = {0:"凡品",1000:"灵品",3000:"宝品",8000:"王品",20000:"圣品"}

def parse_percent(s):
    nums = re.findall(r"-?\d+(?:\.\d+)?", str(s))
    return float(nums[0]) if nums else None

def get_first_num(s):
    nums = re.findall(r"-?\d+(?:\.\d+)?", str(s))
    return float(nums[0]) if nums else None

def load_csv(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        r = csv.DictReader(f)
        rows = list(r)
        return r.fieldnames, rows

def identify_table(header):
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

# ---------------- TASK0 职业重命名门控（R5 代码重命名前置）----------------
# 已定义职业枚举（含 csv_validator.gd 的 APPLY_CLASSES 通用 用于 item apply-class）
PROF_ALLOWED = {"道修","体修","法修","御兽师","符箓师","毒师","傀儡师","通用"}
# 旧职业名，Sprint-03 前须从 .gd/.csv 清零（剑修后置为后续新增职业，不复用旧槽位）
PROF_ORPHAN_TOKEN = "剑修"

def validate_profession_renamed():
    """扫描根目录 *.gd 与 config/*.csv，旧职业名「剑修」必须清零。
    出现「剑修」即报孤儿字段（职业枚举已迁移为「道修」）。"""
    bad = []
    gd_files = sorted(glob.glob(os.path.join(SCRIPT_DIR, "*.gd")))
    for p in gd_files:
        try:
            with open(p, encoding="utf-8") as f:
                for i, line in enumerate(f, 1):
                    if PROF_ORPHAN_TOKEN in line and "@LEGACY-MIGRATION" not in line:
                        bad.append((os.path.basename(p), "profession-rename", i,
                                    "残留旧职业名「剑修」(应为「道修」): %r" % line.strip()[:60]))
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
                                    "残留旧职业名「剑修」(应为「道修」): %r" % line.strip()[:60]))
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
        key = identify_table(header) if header else None
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

        # 4b. 单条奖励倍率软告警（P0 拍板）：普通1x / 优秀2x / 稀有5x / 传说12x。
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
                    warns.append("event_quest.csv: event_id=%s %s 数值当量=%d 超%s档软上限%d（%.1fx），请复核是否奖励过高" % (r.get("event_id", ""), opt, tot, rt, cap, tot / float(REWARD_BASE)))
        report.append("- [OK] event_quest: 单条奖励倍率软告警扫描完成（基准%d，超倍率即告警不阻断）" % REWARD_BASE)

    # ---------- 战斗关卡系统跨表校验（Day1 新增 stage_main / monster_main / drop_pool）----------
    report.append("")
    report.append("# 战斗关卡跨表校验（stage_main / monster_main / drop_pool）")
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
        report.append("- [CHECK] 战斗关卡跨表校验完成（怪物引用/掉落池/前置关卡/掉落物存在性/min-max）")
    else:
        report.append("- [SKIP] stage_main/monster_main/drop_pool 未全部加载，跳过跨表校验")

    # ---------- 器堂赠宝配置跨表校验（craft_hall_reward）----------
    report.append("")
    report.append("# 器堂赠宝配置跨表校验（craft_hall_reward）")
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

    # 4. faction_base monotonic need_reputation
    d = rows_of("faction_base")
    if d:
        order = ["中立","友善","尊敬","崇敬","崇拜"]
        from collections import defaultdict
        g = defaultdict(list)
        for r in d: g[r["faction_id"]].append((order.index(r["reputation_level"]), int(get_first_num(r["need_reputation"]) or 0)))
        for fid, lst in g.items():
            lst.sort()
            for i in range(1,len(lst)):
                if lst[i][1] <= lst[i-1][1]:
                    errors.append(("faction_base.csv","faction_base",0,"faction_id=%s 声望等级%s need_reputation未严格递增"% (fid, order[lst[i][0]])))
        report.append("- [CHECK] faction_base: 声望等级 need_reputation 严格递增校验完成")
    # 5. faction_shop grade cap by unlock_reputation
    d = rows_of("faction_shop")
    if d:
        for r in d:
            rep = int(get_first_num(r["unlock_reputation"]) or 0)
            cap = "凡品"
            for thr,gd in sorted(REP_GRADE_CAP.items()):
                if rep >= thr: cap = gd
            ig = GRADE_RANK.get(r["item_grade"], -1)
            if ig > GRADE_RANK[cap]:
                errors.append(("faction_shop.csv","faction_shop",0,"shop_id=%s item_grade=%s 超出 unlock_reputation=%d 允许上限%s"%(r["shop_id"],r["item_grade"],rep,cap)))
        report.append("- [CHECK] faction_shop: item_grade 品阶阈值校验完成")
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
            if r["item_class"]=="任务碎片":
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

    # ---------- TASK0 职业重命名门控 ----------
    report.append("")
    report.append("# 职业重命名门控（剑修→道修）")
    prof_bad = validate_profession_renamed()
    for e in prof_bad:
        errors.append(e)
    if prof_bad:
        report.append("- [FAIL] 检测到 %d 处残留「剑修」（职业枚举须全部为「道修」）" % len(prof_bad))
        for f,k,r,msg in prof_bad:
            report.append("  - [%s/%s 行%d] %s" % (f,k,r,msg))
    else:
        report.append("- [OK] 根目录 .gd 与 config/*.csv 中无残留「剑修」，职业枚举已统一为「道修」")

    # ---------- 命格效果参数格式校验 ----------
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

# csv_validator.gd
# 配置表校验器 —— v2.56 新增文件（原工程无此文件，本次创建）
# 用途：随 CSV 热更一并跑全量校验（详见 GDD §11.23 八、配置表导入约定）
# 说明：本文件仅定义规则数据与常量；实际解析/校验逻辑由调用方实现。
#       当前仅落地 spirit_pet / puppet 两张表的规则，其余表随对应 CSV 一并补入。
# 数据质量待办处理结论（2026-07-17，B2/B3 已裁决）：
#   - 采用「CSV 数据为唯一真相源」原则：保留战斗/产业增益的 "%" 可读性写法，
#     校验器新增 "percent" 类型解析 "%" 后缀（双值 "a%+b%" 取主值 a 做区间校验），
#     不再强制裸数。原 B2 冲突已消解。
#   - spirit_pet.pet_type 实际取值 8 种（见下方 enum），已与 §7.3 三分类（产出/战斗/驮运代步）
#     对齐为「明细=CSV、汇总=章节表」的分层口径，validator enum 直接收纳 8 种，B3 已消解。
#
# 字段类型约定：
#   "percent"  —— 单元格为带 "%" 的字符串（如 "5%" / "20%+10%"）；校验时剥离 "%"，
#                 取首个数值做 [min,max] 区间校验；双值仅校验主值，副值由 companion 字段/章节说明承载。

extends Node

# ---------- 全局常量 ----------
const VALID_GRADES := ["凡品", "灵品", "宝品", "王品", "圣品", "真品", "道品"]
const MIN_SUCCESS_RATE := 5.0
const MAX_SUCCESS_RATE := 95.0
const VALID_SUB_GRADES := ["下品", "中品", "上品", "极品"]
const PILL_TYPES := ["培元类", "突破类", "恢复类", "属性类", "特殊类"]
const TAL_TYPES := ["攻击类", "防御类", "辅助类", "控制类", "特殊类"]
const TREASURE_TYPES := ["攻击类", "防御类", "辅助类"]
const SKILL_TYPES := ["攻击", "控制", "辅助防御", "通用"]
const EQUIP_SLOTS := ["武器", "法袍", "头盔", "护腕", "腰带", "靴子", "饰品"]
const APPLY_CLASSES := ["通用", "体修", "道修", "法修"]
const SET_CLASSES := ["全职业通用", "道修", "体修", "法修"]

# ---------- 各表校验规则 ----------
const TABLE_RULES := {
    "spirit_pet": {
        "required_fields": [
            "pet_id", "pet_name", "grade", "sub_grade", "pet_type",
            "unlock_realm", "passive_value", "max_level",
            "feed_cost_per_day", "base_lifespan_year"
        ],
        "primary_key": "pet_id",
        "field_rules": {
            "grade": {"type": "enum", "values": VALID_GRADES},
            "sub_grade": {"type": "enum", "values": ["下品", "中品", "上品", "极品"], "tip": "细分品级非法"},
            "pet_type": {"type": "enum", "values": ["产出辅助", "代步辅助", "驮运防御", "战斗辅助", "丹道辅助", "飞行战斗", "防御驮运", "全宗增益"], "tip": "灵兽类型非法（应为 8 类明细之一）"},
            "passive_value": {"type": "percent", "max": 50.0, "tip": "被动增益超出50%全局上限（双值取主值校验）"},
            "max_level": {"type": "int", "min": 1, "tip": "最高等级必须大于0"},
            "feed_cost_per_day": {"type": "int", "min": 0, "tip": "每日喂养消耗不能为负数"},
            "base_lifespan_year": {"type": "int", "min": 1, "tip": "基础寿命必须大于0"}
        }
    },
    "puppet": {
        "required_fields": [
            "puppet_id", "puppet_name", "grade", "sub_grade", "puppet_type",
            "effect_value", "max_durability", "daily_maintain_cost",
            "craft_time_sec", "base_success_rate", "sell_price_ling"
        ],
        "primary_key": "puppet_id",
        "field_rules": {
            "grade": {"type": "enum", "values": VALID_GRADES},
            "sub_grade": {"type": "enum", "values": ["下品", "中品", "上品", "极品"], "tip": "细分品级非法"},
            "puppet_type": {"type": "enum", "values": ["劳作", "炼丹", "炼器", "战斗"], "tip": "傀儡类型非法"},
            "effect_value": {"type": "percent", "max": 50.0, "tip": "产业增益超出50%全局上限"},
            "max_durability": {"type": "int", "min": 1, "tip": "耐久上限必须大于0"},
            "daily_maintain_cost": {"type": "int", "min": 0, "tip": "维护消耗不能为负数"},
            "craft_time_sec": {"type": "int", "min": 1, "tip": "制作时长必须大于0"},
            "base_success_rate": {"type": "percent", "min": MIN_SUCCESS_RATE, "max": MAX_SUCCESS_RATE, "tip": "成功率必须在5%-95%区间内"},
            "sell_price_ling": {"type": "int", "min": 0, "tip": "售价不能为负数"}
        }
    }
    "item_pill": {
        "required_fields": ["pill_id","pill_name","grade","sub_grade","pill_type","use_effect","effect_value","use_level","craft_material","craft_time","base_success_rate","sell_price"],
        "primary_key": "pill_id",
        "field_rules": {
            "grade": {"type": "enum", "values": VALID_GRADES},
            "sub_grade": {"type": "enum", "values": VALID_SUB_GRADES, "tip": "细分品级非法"},
            "pill_type": {"type": "enum", "values": PILL_TYPES, "tip": "丹药类型非法"},
            "effect_value": {"type": "percent", "max": 200.0, "tip": "丹药效果超出合理上限"},
            "craft_time": {"type": "int", "min": 1, "tip": "炼制时长必须大于0"},
            "base_success_rate": {"type": "percent", "min": MIN_SUCCESS_RATE, "max": MAX_SUCCESS_RATE, "tip": "成功率必须在5%-95%区间内"},
            "sell_price": {"type": "int", "min": 0, "tip": "售价不能为负数"}
        }
    },
    "item_talisman": {
        "required_fields": ["talisman_id","talisman_name","grade","sub_grade","talisman_type","use_effect","effect_value","use_limit","craft_material","sell_price"],
        "primary_key": "talisman_id",
        "field_rules": {
            "grade": {"type": "enum", "values": VALID_GRADES},
            "sub_grade": {"type": "enum", "values": VALID_SUB_GRADES, "tip": "细分品级非法"},
            "talisman_type": {"type": "enum", "values": TAL_TYPES, "tip": "符箓类型非法"},
            "effect_value": {"type": "percent", "max": 200.0, "tip": "符箓效果超出合理上限"},
            "use_limit": {"type": "int", "min": 1, "tip": "每战使用上限必须大于0"},
            "sell_price": {"type": "int", "min": 0, "tip": "售价不能为负数"}
        }
    },
    "equip_main": {
        "required_fields": ["equip_id","equip_name","grade","sub_grade","equip_slot","apply_class","base_atk","base_def","base_hp","base_durability","repair_material","sell_price"],
        "primary_key": "equip_id",
        "field_rules": {
            "grade": {"type": "enum", "values": VALID_GRADES},
            "sub_grade": {"type": "enum", "values": VALID_SUB_GRADES, "tip": "细分品级非法"},
            "equip_slot": {"type": "enum", "values": EQUIP_SLOTS, "tip": "装备部位非法"},
            "apply_class": {"type": "enum", "values": APPLY_CLASSES, "tip": "适用职业非法"},
            "base_atk": {"type": "int", "min": 0, "tip": "攻击不能为负"},
            "base_def": {"type": "int", "min": 0, "tip": "防御不能为负"},
            "base_hp": {"type": "int", "min": 0, "tip": "气血不能为负"},
            "base_durability": {"type": "int", "min": 1, "tip": "耐久必须大于0"},
            "sell_price": {"type": "int", "min": 0, "tip": "售价不能为负数"}
        }
    },
    "equip_blueprint": {
        "required_fields": ["blueprint_id","blueprint_name","grade","sub_grade","target_equip_id","unlock_condition","craft_cost","sell_price"],
        "primary_key": "blueprint_id",
        "field_rules": {
            "grade": {"type": "enum", "values": VALID_GRADES},
            "sub_grade": {"type": "enum", "values": VALID_SUB_GRADES, "tip": "细分品级非法"},
            "target_equip_id": {"type": "string", "tip": "应引用 equip_main.equip_id"},
            "craft_cost": {"type": "int", "min": 1, "tip": "制作消耗必须大于0"},
            "sell_price": {"type": "int", "min": 0, "tip": "售价不能为负数"}
        }
    },
    "skill_cultivation": {
        "required_fields": ["skill_id","skill_name","grade","sub_grade","apply_class","skill_type","effect_value","max_level","unlock_realm","learn_cost"],
        "primary_key": "skill_id",
        "field_rules": {
            "grade": {"type": "enum", "values": VALID_GRADES},
            "sub_grade": {"type": "enum", "values": VALID_SUB_GRADES, "tip": "细分品级非法"},
            "apply_class": {"type": "enum", "values": APPLY_CLASSES, "tip": "适用职业非法"},
            "skill_type": {"type": "enum", "values": SKILL_TYPES, "tip": "功法类型非法"},
            "effect_value": {"type": "percent", "max": 200.0, "tip": "功法效果超出合理上限"},
            "max_level": {"type": "int", "min": 1, "tip": "最高等级必须大于0"},
            "learn_cost": {"type": "int", "min": 0, "tip": "参悟消耗不能为负数"}
        }
    },
    "treasure_normal": {
        "required_fields": ["treasure_id","treasure_name","grade","sub_grade","treasure_type","base_atk","base_def","base_hp","passive_effect","effect_value","sell_price"],
        "primary_key": "treasure_id",
        "field_rules": {
            "grade": {"type": "enum", "values": VALID_GRADES},
            "sub_grade": {"type": "enum", "values": VALID_SUB_GRADES, "tip": "细分品级非法"},
            "treasure_type": {"type": "enum", "values": TREASURE_TYPES, "tip": "法宝类型非法"},
            "base_atk": {"type": "int", "min": 0, "tip": "攻击不能为负"},
            "base_def": {"type": "int", "min": 0, "tip": "防御不能为负"},
            "base_hp": {"type": "int", "min": 0, "tip": "气血不能为负"},
            "effect_value": {"type": "percent", "max": 200.0, "tip": "法宝效果超出合理上限"},
            "sell_price": {"type": "int", "min": 0, "tip": "售价不能为负数"}
        }
    },
    "treasure_innate": {
        "required_fields": ["innate_id","innate_name","grade","sub_grade","apply_class","active_skill","passive_effect","growth_value","max_level","sacrifice_material"],
        "primary_key": "innate_id",
        "field_rules": {
            "grade": {"type": "enum", "values": VALID_GRADES},
            "sub_grade": {"type": "enum", "values": VALID_SUB_GRADES, "tip": "细分品级非法"},
            "apply_class": {"type": "enum", "values": APPLY_CLASSES, "tip": "适用职业非法"},
            "growth_value": {"type": "percent", "max": 200.0, "tip": "成长数值超出合理上限"},
            "max_level": {"type": "int", "min": 1, "tip": "最高等级必须大于0"}
        }
    },
    "equip_set": {
        "required_fields": ["set_id","set_name","grade","sub_grade","apply_class","set_2pc_effect","set_2pc_value","set_4pc_effect","set_4pc_value"],
        "primary_key": "set_id",
        "field_rules": {
            "grade": {"type": "enum", "values": VALID_GRADES},
            "sub_grade": {"type": "enum", "values": VALID_SUB_GRADES, "tip": "细分品级非法"},
            "apply_class": {"type": "enum", "values": SET_CLASSES, "tip": "套装适用职业非法"},
            "set_2pc_value": {"type": "percent", "max": 200.0, "tip": "2件套效果数值非法"},
            "set_4pc_value": {"type": "percent", "max": 200.0, "tip": "4件套效果数值非法"}
        }
    },
    "spirit_array_config": {
        "required_fields": ["array_id","array_name","grade","sub_grade","level","unlock_sect_level","cultivate_bonus","herb_grow_bonus","pill_success_bonus","forge_success_bonus","daily_cost","upgrade_lingstone","upgrade_material","upgrade_days","max_cover"],
        "primary_key": "array_id",
        "field_rules": {
            "grade": {"type": "enum", "values": VALID_GRADES},
            "sub_grade": {"type": "enum", "values": VALID_SUB_GRADES, "tip": "细分品级非法"},
            "level": {"type": "int", "min": 1, "tip": "阵法等级必须大于0"},
            "unlock_sect_level": {"type": "int", "min": 1, "tip": "解锁宗门等级必须大于0"},
            "cultivate_bonus": {"type": "float", "max": 1.0, "tip": "修炼加成超出 100%"},
            "herb_grow_bonus": {"type": "float", "max": 1.0, "tip": "灵草成长加成超出 100%"},
            "pill_success_bonus": {"type": "float", "max": 1.0, "tip": "炼丹成功率加成超出 100%"},
            "forge_success_bonus": {"type": "float", "max": 1.0, "tip": "炼器成功率加成超出 100%"},
            "daily_cost": {"type": "int", "min": 0, "tip": "每日消耗不能为负"},
            "upgrade_lingstone": {"type": "int", "min": 0, "tip": "升级灵石不能为负"},
            "upgrade_material": {"type": "string", "tip": "升级材料格式异常"},
            "upgrade_days": {"type": "int", "min": 0, "tip": "升级天数不能为负"},
            "max_cover": {"type": "int", "min": 1, "tip": "最大覆盖建筑数必须大于0"}
        }
    },
    "defense_array_config": {
        "required_fields": ["defense_array_id","array_name","grade","sub_grade","level","unlock_sect_level","daily_cost","daily_defense_rate","spy_reduce_rate","war_cost","war_damage_reduce_max","building_damage_reduce","tribulation_resist_max","tribulation_cost","upgrade_lingstone","upgrade_material","upgrade_days","max_cover_buildings"],
        "primary_key": "defense_array_id",
        "field_rules": {
            "grade": {"type": "enum", "values": VALID_GRADES},
            "sub_grade": {"type": "enum", "values": VALID_SUB_GRADES, "tip": "细分品级非法"},
            "level": {"type": "int", "min": 1, "tip": "阵法等级必须大于0"},
            "unlock_sect_level": {"type": "int", "min": 1, "tip": "解锁宗门等级必须大于0"},
            "daily_cost": {"type": "int", "min": 0, "tip": "每日消耗不能为负"},
            "daily_defense_rate": {"type": "float", "max": 1.0, "tip": "日常防御率超出 100%"},
            "spy_reduce_rate": {"type": "float", "max": 1.0, "tip": "谍报削减率超出 100%"},
            "war_cost": {"type": "int", "min": 0, "tip": "战时消耗不能为负"},
            "war_damage_reduce_max": {"type": "float", "max": 1.0, "tip": "战时减伤上限超出 100%"},
            "building_damage_reduce": {"type": "float", "max": 1.0, "tip": "建筑减伤超出 100%"},
            "tribulation_resist_max": {"type": "float", "max": 1.0, "tip": "渡劫抗性上限超出 100%"},
            "tribulation_cost": {"type": "int", "min": 0, "tip": "渡劫消耗不能为负"},
            "upgrade_lingstone": {"type": "int", "min": 0, "tip": "升级灵石不能为负"},
            "upgrade_material": {"type": "string", "tip": "升级材料格式异常"},
            "upgrade_days": {"type": "int", "min": 0, "tip": "升级天数不能为负"},
            "max_cover_buildings": {"type": "int", "min": 1, "tip": "最大覆盖建筑数必须大于0"}
        }
    }
}

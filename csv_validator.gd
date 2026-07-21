# csv_validator.gd
# 配置表校验器 —— v2.56 新增文件（原工程无此文件，本次创建）
# 用途：随 CSV 热更一并跑全量校验（详见 GDD §11.23 八、配置表导入约定）
# 说明：本文件仅定义规则数据与常量；实际解析/校验逻辑由调用方实现。
#       当前随各系统 CSV 持续补入（含 economy 四表 drop_common/resource_base/output_daily/sink_cost，v2.59）。
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
const EQUIP_SLOTS := ["武器", "法袍", "头盔", "护腕", "腰带", "靴子", "饰品", "法宝"]
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
    },
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
    },
    "skill": {
        "required_fields": [
            "skill_id", "skill_name", "profession", "damage_rate", "cooldown", "mp_cost"
        ],
        "primary_key": "skill_id",
        "field_rules": {
            "profession": {"type": "enum", "values": ["体修", "道修", "法修", "通用"], "tip": "职业类型非法"},
            "damage_rate": {"type": "float", "min": 0, "max": 3.0, "tip": "技能倍率超出合理范围"},
            "cooldown": {"type": "int", "min": 0, "max": 10, "tip": "调息周期超出0-10范围"},
            "mp_cost": {"type": "int", "min": 0, "tip": "灵力消耗不能为负数"}
        }
    },
    "drop_common": {
        "required_fields": ["drop_id","scene_name","unlock_realm","unlock_sect_level","item_id","item_name","item_grade","item_type","drop_weight","guarantee_count","daily_drop_limit","is_counted_in_balance"],
        "primary_key": "drop_id+item_id",
        "field_rules": {
            "unlock_sect_level": {"type": "int", "min": 1, "tip": "解锁宗门等级必须大于0"},
            "item_grade": {"type": "enum", "values": ["凡品下品","凡品中品","凡品上品","凡品极品","灵品下品","灵品中品","灵品上品","灵品极品","宝品下品","宝品中品","宝品上品","宝品极品","王品下品","王品中品","王品上品","王品极品","圣品下品","圣品中品","圣品上品","圣品极品"], "tip": "道具品阶非法（应为 大品阶+细分品级 组合，对齐 7 品 4 级）"},
            "drop_weight": {"type": "int", "min": 0, "tip": "掉落权重不能为负"},
            "guarantee_count": {"type": "int", "min": 0, "tip": "保底次数不能为负"},
            "daily_drop_limit": {"type": "int", "min": 0, "tip": "每日掉落上限不能为负"},
            "is_counted_in_balance": {"type": "bool", "tip": "是否计入经济平衡测算应为 true/false"}
        }
    },
    "resource_base": {
        "required_fields": ["resource_id","resource_name","resource_tier","item_grade","stack_limit","core_positioning","main_use"],
        "primary_key": "resource_id",
        "field_rules": {
            "resource_tier": {"type": "enum", "values": ["核心货币类","基础原材料类","养成成品类","稀有战略类"], "tip": "资源层级非法"},
            "item_grade": {"type": "string", "tip": "品阶对应：通用 / 按产出品阶"},
            "stack_limit": {"type": "string", "tip": "堆叠上限：整数或 TBD（待配置）"}
        }
    },
    "output_daily": {
        "required_fields": ["stage","sect_level","resource","daily_output","unit"],
        "primary_key": "stage+resource",
        "field_rules": {
            "daily_output": {"type": "int", "min": 0, "tip": "日均产出不能为负"}
        }
    },
    "sink_cost": {
        "required_fields": ["stage","resource","daily_consumption","unit","core_direction"],
        "primary_key": "stage+resource",
        "field_rules": {
            "daily_consumption": {"type": "int", "min": 0, "tip": "日均消耗不能为负"}
        }
    },
    "quest_daily": {
        "required_fields": ["quest_id","quest_name","quest_type","unlock_sect_level","difficulty","target_desc","target_num","reward_lingjing","reward_lingqi","reward_pool_id","active_point","daily_limit","is_auto_complete"],
        "primary_key": "quest_id",
        "field_rules": {
            "quest_type": {"type": "enum", "values": ["经营","养成","探索","互动"], "tip": "日常任务类型非法"},
            "difficulty": {"type": "enum", "values": ["难度Ⅰ","难度Ⅱ","难度Ⅲ","难度Ⅳ"], "tip": "难度档位非法（应对四阶段成长节奏）"},
            "unlock_sect_level": {"type": "int", "min": 1, "max": 10, "tip": "解锁宗门等级须在1-10"},
            "target_num": {"type": "int", "min": 1, "tip": "目标数量必须大于0"},
            "reward_lingjing": {"type": "int", "min": 0, "tip": "灵石奖励不能为负"},
            "reward_lingqi": {"type": "int", "min": 0, "tip": "灵气奖励不能为负"},
            "active_point": {"type": "int", "min": 0, "tip": "活跃度不能为负"},
            "daily_limit": {"type": "int", "min": 0, "tip": "每日次数不能为负"},
            "is_auto_complete": {"type": "bool", "tip": "是否自动完成应为 true/false"}
        }
    },
    "quest_weekly": {
        "required_fields": ["quest_id","quest_name","quest_type","unlock_sect_level","difficulty","target_desc","target_num","reward_lingjing","reward_lingqi","reward_pool_id","reward_chest_id","weekly_active_point","weekly_limit","is_auto_complete"],
        "primary_key": "quest_id",
        "field_rules": {
            "quest_type": {"type": "enum", "values": ["深度养成","高阶玩法","宗门经营"], "tip": "周常任务类型非法"},
            "difficulty": {"type": "enum", "values": ["难度Ⅰ","难度Ⅱ","难度Ⅲ","难度Ⅳ"], "tip": "难度档位非法"},
            "unlock_sect_level": {"type": "int", "min": 1, "max": 10, "tip": "解锁宗门等级须在1-10"},
            "target_num": {"type": "int", "min": 1, "tip": "目标数量必须大于0"},
            "reward_lingjing": {"type": "int", "min": 0, "tip": "灵石奖励不能为负"},
            "reward_lingqi": {"type": "int", "min": 0, "tip": "灵气奖励不能为负"},
            "weekly_active_point": {"type": "int", "min": 0, "tip": "周活跃度不能为负"},
            "weekly_limit": {"type": "int", "min": 0, "tip": "每周次数不能为负"},
            "is_auto_complete": {"type": "bool", "tip": "是否自动完成应为 true/false"}
        }
    },
    "quest_random": {
        "required_fields": ["quest_id","quest_name","quest_type","trigger_type","trigger_prob","valid_time","unlock_sect_level","difficulty","reward_pool_id","reward_lingjing","reward_lingqi","quest_npc_id","is_auto_complete"],
        "primary_key": "quest_id",
        "field_rules": {
            "quest_type": {"type": "enum", "values": ["访客委托","宗门琐事","奇遇机遇","紧急事件"], "tip": "随机任务类型非法"},
            "trigger_type": {"type": "enum", "values": ["登录","收取资源","历练归来","弟子突破","事件触发","随机"], "tip": "触发类型非法"},
            "trigger_prob": {"type": "float", "max": 1.0, "tip": "触发概率须≤1"},
            "valid_time": {"type": "int", "min": 0, "tip": "有效期不能为负"},
            "unlock_sect_level": {"type": "int", "min": 1, "max": 10, "tip": "解锁宗门等级须在1-10"},
            "difficulty": {"type": "enum", "values": ["难度Ⅰ","难度Ⅱ","难度Ⅲ","难度Ⅳ"], "tip": "难度档位非法"},
            "reward_lingjing": {"type": "int", "min": 0, "tip": "灵石奖励不能为负"},
            "reward_lingqi": {"type": "int", "min": 0, "tip": "灵气奖励不能为负"},
            "is_auto_complete": {"type": "bool", "tip": "是否自动完成应为 true/false"}
        }
    },
    "quest_reward_pool": {
        "required_fields": ["pool_id","item_id","item_name","item_grade","weight","drop_limit","daily_max","is_counted_in_balance"],
        "primary_key": "pool_id+item_id",
        "field_rules": {
            "item_grade": {"type": "enum", "values": ["凡品下品","凡品中品","凡品上品","凡品极品","灵品下品","灵品中品","灵品上品","灵品极品","宝品下品","宝品中品","宝品上品","宝品极品","王品下品","王品中品","王品上品","王品极品","圣品下品","圣品中品","圣品上品","圣品极品","固定数值"], "tip": "道具品阶非法（应为 大品阶+细分品级 组合，对齐 7 品 4 级；灵石/气运等固定数值奖励填「固定数值」）"},
            "weight": {"type": "int", "min": 0, "tip": "权重不能为负"},
            "drop_limit": {"type": "int", "min": 0, "tip": "掉落上限不能为负"},
            "daily_max": {"type": "int", "min": 0, "tip": "每日上限不能为负"},
            "is_counted_in_balance": {"type": "bool", "tip": "是否计入经济平衡测算应为 true/false"}
        }
    },
    "event_quest": {
        "required_fields": ["event_id","event_name","event_type","rarity","trigger_scene","unlock_sect_level","unlock_realm","event_content","opt1_desc","opt1_reward","opt1_punish","opt2_desc","opt2_reward","opt2_punish","opt3_desc","opt3_reward","opt3_punish","trigger_weight","cooldown_hour","is_counted_in_balance"],
        "primary_key": "event_id",
        "field_rules": {
            "event_type": {"type": "enum", "values": ["宗门常驻","野外历练","昼夜专属","阵营专属","征伐"], "tip": "奇遇大类非法"},
            "rarity": {"type": "enum", "values": ["普通","稀有","传说"], "tip": "稀有度非法（3档映射§10四档）"},
            "trigger_scene": {"type": "enum", "values": ["宗门内","历练结算","秘境通关","战斗胜利","昼夜切换","登录"], "tip": "触发场景非法"},
            "unlock_sect_level": {"type": "int", "min": 1, "max": 10, "tip": "解锁宗门等级须在1-10"},
            "unlock_realm": {"type": "enum", "values": ["练气","筑基","金丹","元婴","化神","炼虚","合体"], "tip": "境界非法"},
            "trigger_weight": {"type": "int", "min": 0, "tip": "触发权重不能为负"},
            "cooldown_hour": {"type": "int", "min": 0, "tip": "调息周期不能为负"},
            "is_counted_in_balance": {"type": "bool", "tip": "是否计入经济平衡应为 true/false"}
        }
    },
    "faction_base": {
        "required_fields": ["faction_id","faction_name","reputation_level","need_reputation","global_buff_1","global_buff_2","unlock_content","shop_unlock_grade"],
        "primary_key": "faction_id+reputation_level",
        "field_rules": {
            "faction_id": {"type": "enum", "values": ["fz_zhengdao","fz_zhongli","fz_mo","fz_yaozu","fz_danqi"], "tip": "阵营编码非法（fz_yuan 暂缓 TODO-③）"},
            "reputation_level": {"type": "enum", "values": ["中立","友善","尊敬","崇敬","崇拜"], "tip": "声望等级非法"},
            "need_reputation": {"type": "int", "min": 0, "tip": "所需声望不能为负"},
            "shop_unlock_grade": {"type": "int", "min": 0, "max": 4, "tip": "商店解锁档位须在0-4"}
        }
    },
    "faction_shop": {
        "required_fields": ["shop_id","faction_id","item_id","item_name","item_grade","price_lingjing","price_token","limit_daily","limit_weekly","unlock_reputation"],
        "primary_key": "shop_id",
        "field_rules": {
            "faction_id": {"type": "enum", "values": ["fz_zhengdao","fz_zhongli","fz_mo","fz_yaozu","fz_danqi"], "tip": "阵营编码非法"},
            "item_grade": {"type": "enum", "values": ["凡品","灵品","宝品","王品","圣品","真品","道品"], "tip": "道具品阶非法（7大品阶）"},
            "price_lingjing": {"type": "int", "min": 0, "tip": "灵石价不能为负"},
            "price_token": {"type": "int", "min": 0, "tip": "代币价不能为负"},
            "limit_daily": {"type": "int", "min": 0, "tip": "每日限购不能为负"},
            "limit_weekly": {"type": "int", "min": 0, "tip": "每周限购不能为负"},
            "unlock_reputation": {"type": "int", "min": 0, "tip": "解锁声望阈值不能为负"}
        }
    },
    "inner_demon": {
        "required_fields": ["demon_id","demon_name","match_personality","trigger_prob","opt1_desc","opt1_success_rate","opt1_success_reward","opt1_fail_punish","opt2_desc","opt2_success_rate","opt2_success_reward","opt2_fail_punish"],
        "primary_key": "demon_id",
        "field_rules": {
            "match_personality": {"type": "enum", "values": ["勤勉","慵懒","沉稳","急躁","淡泊","好胜","仁厚"], "tip": "性格标签非法（7性格行为层）"},
            "trigger_prob": {"type": "float", "min": 0, "max": 1.0, "tip": "触发概率须∈[0,1]"},
            "opt1_success_rate": {"type": "float", "min": 0, "max": 1.0, "tip": "成功率须∈[0,1]"},
            "opt2_success_rate": {"type": "float", "min": 0, "max": 1.0, "tip": "成功率须∈[0,1]"}
        }
    },
    "tribulation_item": {
        "required_fields": ["item_id","item_name","item_type","success_rate_bonus","damage_reduce","consume_cost","consume_type"],
        "primary_key": "item_id",
        "field_rules": {
            "item_type": {"type": "enum", "values": ["渡劫丹","护阵","长老护法","防御法宝"], "tip": "渡劫道具类型非法"},
            "success_rate_bonus": {"type": "float", "min": 0, "max": 0.5, "tip": "成功率加成单件上限50%"},
            "damage_reduce": {"type": "float", "min": 0, "max": 0.5, "tip": "减伤单件上限50%（叠加上限同§11.16总抗性）"},
            "consume_cost": {"type": "int", "min": 0, "tip": "消耗不能为负"}
        }
    },
    "personality_config": {
        "required_fields": ["personality_id","personality_name","work_eff_factor","train_eff_factor","combat_atk_factor","combat_def_factor","work_weight","walk_weight","rest_weight","interact_weight","loyalty_base","morale_base","demon_resist_rate","defect_base_rate","description"],
        "primary_key": "personality_id",
        "field_rules": {
            "work_eff_factor": {"type": "float", "min": 0.8, "max": 1.2, "tip": "劳作效率因子须在±20%内"},
            "train_eff_factor": {"type": "float", "min": 0.8, "max": 1.2, "tip": "修炼效率因子须在±20%内"},
            "combat_atk_factor": {"type": "float", "min": 0.8, "max": 1.2, "tip": "攻击因子须在±20%内"},
            "combat_def_factor": {"type": "float", "min": 0.8, "max": 1.2, "tip": "防御因子须在±20%内"},
            "work_weight": {"type": "float", "min": 0, "max": 1, "tip": "行为权重须在[0,1]"},
            "walk_weight": {"type": "float", "min": 0, "max": 1, "tip": "行为权重须在[0,1]"},
            "rest_weight": {"type": "float", "min": 0, "max": 1, "tip": "行为权重须在[0,1]"},
            "interact_weight": {"type": "float", "min": 0, "max": 1, "tip": "行为权重须在[0,1]"},
            "loyalty_base": {"type": "int", "min": 0, "max": 100, "tip": "忠诚度须在0-100"},
            "morale_base": {"type": "int", "min": 0, "max": 100, "tip": "士气须在0-100"},
            "demon_resist_rate": {"type": "float", "min": 0, "max": 1, "tip": "抗心魔率须∈[0,1]"},
            "defect_base_rate": {"type": "float", "min": 0, "max": 1, "tip": "叛逃基础率须∈[0,1]"}
        }
    },
    "path_config": {
        "required_fields": ["path_id","path_name","match_profession","work_area_weight","train_area_weight","public_area_weight","exclusive_behavior_id","skill_grow_bonus","special_buff"],
        "primary_key": "path_id",
        "field_rules": {
            "match_profession": {"type": "enum", "values": ["体修","道修","法修","通用"], "tip": "职业非法"},
            "work_area_weight": {"type": "float", "min": 0, "max": 1, "tip": "片区权重须在[0,1]"},
            "train_area_weight": {"type": "float", "min": 0, "max": 1, "tip": "片区权重须在[0,1]"},
            "public_area_weight": {"type": "float", "min": 0, "max": 1, "tip": "片区权重须在[0,1]"},
            "skill_grow_bonus": {"type": "float", "min": 0, "max": 1, "tip": "技能成长加成须∈[0,1]"}
        }
    },
    "area_stay_weight": {
        "required_fields": ["combine_id","personality_id","path_id","lingtian_weight","danfang_weight","yanwuchang_weight","shanmen_weight","public_weight","verify_note"],
        "primary_key": "combine_id",
        "field_rules": {
            "lingtian_weight": {"type": "float", "min": 0, "max": 1, "tip": "片区权重须在[0,1]"},
            "danfang_weight": {"type": "float", "min": 0, "max": 1, "tip": "片区权重须在[0,1]"},
            "yanwuchang_weight": {"type": "float", "min": 0, "max": 1, "tip": "片区权重须在[0,1]"},
            "shanmen_weight": {"type": "float", "min": 0, "max": 1, "tip": "片区权重须在[0,1]"},
            "public_weight": {"type": "float", "min": 0, "max": 1, "tip": "片区权重须在[0,1]"}
        }
    },
    "disciple_interact": {
        "required_fields": ["interact_id","interact_name","interact_type","trigger_prob","relation_min","relation_max","reward_type","reward_value_a","reward_value_b","punish_type","punish_value","cooldown_hour","is_relation_grow"],
        "primary_key": "interact_id",
        "field_rules": {
            "interact_type": {"type": "enum", "values": ["切磋","论道","赠礼","协作","争执"], "tip": "互动类型非法"},
            "trigger_prob": {"type": "float", "min": 0, "max": 1.0, "tip": "触发概率须∈[0,1]"},
            "relation_min": {"type": "int", "min": 0, "max": 100, "tip": "关系下限须在0-100"},
            "relation_max": {"type": "int", "min": 0, "max": 100, "tip": "关系上限须在0-100"},
            "reward_type": {"type": "enum", "values": ["好感","灵石","道具","修为","道心"], "tip": "奖励类型非法"},
            "reward_value_a": {"type": "int", "min": 0, "tip": "奖励数值不能为负"},
            "reward_value_b": {"type": "int", "min": 0, "tip": "奖励数值不能为负"},
            "punish_type": {"type": "enum", "values": ["好感","灵石","忠诚","无"], "tip": "惩罚类型非法"},
            "punish_value": {"type": "int", "min": 0, "tip": "惩罚数值不能为负"},
            "cooldown_hour": {"type": "int", "min": 0, "tip": "调息周期不能为负"},
            "is_relation_grow": {"type": "bool", "tip": "是否增长关系应为 true/false"}
        }
    },
    "negative_event": {
        "required_fields": ["event_id","event_name","trigger_condition","base_prob","monthly_limit","punish_type_1","punish_value_1","punish_type_2","punish_value_2","deal_item","deal_effect","recover_day","is_permanent"],
        "primary_key": "event_id",
        "field_rules": {
            "base_prob": {"type": "float", "min": 0, "max": 1.0, "tip": "基础概率须∈[0,1]"},
            "monthly_limit": {"type": "int", "min": 0, "tip": "每月上限不能为负"},
            "punish_type_1": {"type": "enum", "values": ["心魔","忠诚","道心","修为","气血","心境","灵石","无"], "tip": "惩罚类型非法"},
            "punish_value_1": {"type": "int", "min": 0, "tip": "惩罚数值不能为负"},
            "punish_type_2": {"type": "enum", "values": ["心魔","忠诚","道心","修为","气血","心境","灵石","无"], "tip": "惩罚类型非法"},
            "punish_value_2": {"type": "int", "min": 0, "tip": "惩罚数值不能为负"},
            "recover_day": {"type": "int", "min": 0, "tip": "恢复天数不能为负"},
            "is_permanent": {"type": "bool", "tip": "是否永久应为 true/false"}
        }
    },
    "morale_loyalty_config": {
        "required_fields": ["config_id","attr_name","full_value","zero_effect","low_threshold","low_effect","high_threshold","high_effect","decay_rate_day","increase_daily_base"],
        "primary_key": "config_id",
        "field_rules": {
            "full_value": {"type": "int", "min": 1, "tip": "满值须>0"},
            "low_threshold": {"type": "int", "min": 0, "tip": "低阈值不能为负"},
            "high_threshold": {"type": "int", "min": 0, "tip": "高阈值不能为负"},
            "decay_rate_day": {"type": "float", "min": 0, "max": 1, "tip": "每日衰减率须∈[0,1]"},
            "increase_daily_base": {"type": "int", "min": 0, "tip": "每日增长基数不能为负"}
        }
    },
    "map_config": {
        "required_fields": ["map_id","map_name","unlock_realm","main_attr","stamina_normal","stamina_elite","monster_config","normal_drop_pool","elite_drop_pool","event_pool","clear_condition"],
        "primary_key": "map_id",
        "field_rules": {
            "main_attr": {"type": "enum", "values": ["金","木","水","火","土"], "tip": "主五行须∈金木水火土"},
            "stamina_normal": {"type": "int", "min": 1, "tip": "普通历练气力消耗须>0"},
            "stamina_elite": {"type": "int", "min": 1, "tip": "精英历练气力消耗须>0"}
        }
    },
    "secret_config": {
        "required_fields": ["secret_id","secret_name","unlock_cond","main_attr","stamina_cost","layers","boss_info","core_drop_pool","exclusive_event","clear_reward"],
        "primary_key": "secret_id",
        "field_rules": {
            "main_attr": {"type": "enum", "values": ["金","木","水","火","土","全","雷"], "tip": "主五行须∈金木水火土/全/雷(雷劫秘境)"},
            "stamina_cost": {"type": "int", "min": 1, "tip": "秘境气力消耗须>0"},
            "layers": {"type": "int", "min": 1, "tip": "秘境层数须≥1"}
        }
    },
    "npc_config": {
        "required_fields": ["npc_id","npc_name","faction_id","identity","core_function","rep_unlock_note"],
        "primary_key": "npc_id",
        "field_rules": {
            "faction_id": {"type": "enum", "values": ["fz_zhengdao","fz_zhongli","fz_mo","fz_yaozu","fz_danqi","fz_yuan","neutral"], "tip": "阵营ID须∈§11.26阵营集/neutral"}
        }
    },
    "quest_item": {
        "required_fields": ["item_id","item_name","item_class","combine_group","combine_target_id","fragment_total","obtain_hint","unlock_event","related_volume","is_counted_in_balance"],
        "primary_key": "item_id",
        "field_rules": {
            "item_class": {"type": "enum", "values": ["主线信物","任务碎片"], "tip": "剧情信物类别非法（信物=合成本体，碎片=合成组件）"},
            "fragment_total": {"type": "int", "min": 0, "tip": "所需碎片数不能为负（仅信物本体有意义，碎片填0）"},
            "is_counted_in_balance": {"type": "bool", "tip": "是否计入经济平衡应为 true/false（剧情信物恒为 false）"}
        }
    },
    # ---------- 成就系统（v2.67 新增，对应 GDD §17 成就系统）----------
    # 本批次为 [PL] 框架：reward_id 仅做格式（string）校验，跨表存在性校验
    # （ID 必须存在全局道具/称号/外观/功能库）留待奖励 ID 回填时启用（见 GDD §17.8 缺口清单）。
    "achievement_config": {
        "required_fields": ["achievement_id","ach_name","category","grade","condition_desc","condition_param","reward_type","reward_id","reward_num","point_num","unlock_tip"],
        "primary_key": "achievement_id",
        "field_rules": {
            "category": {"type": "enum", "values": ["成长","经营","战斗","探索","社交"], "tip": "成就分类非法"},
            "grade": {"type": "enum", "values": ["普通","稀有","传说"], "tip": "成就等级非法"},
            "point_num": {"type": "enum", "values": [10,30,100], "tip": "成就点数必须为10/30/100"},
            "reward_type": {"type": "enum", "values": ["灵石","道具","装备","材料","代币","声望","永久增益","称号","传说称号","外观","buff","阵法","弟子","种子","功能"], "tip": "奖励类型非法"},
            # reward_num 原拟 int；实测 ach_grow_021 为 1.5（永久增益 fang_yu 倍率）。
            # 依据本仓库「CSV 为唯一真相源」原则（见文件头 B2/B3 裁决）改为 float，min 0。
            # 整数数量（如灵石 50000）与小数倍率（如 1.5）均合法。
            "reward_num": {"type": "float", "min": 0, "tip": "奖励数量/倍率不能为负；永久增益类可为小数倍率（如 1.5）"},
            "condition_param": {"type": "int", "min": 0, "tip": "达成条件参数不能为负"},
            "reward_id": {"type": "string", "tip": "意图指向全局道具/称号/外观/功能ID；本批次[PL]不做跨表存在性校验，缺口见GDD §17.8"}
        }
    }
}

# ---------- 核心玩法深度系统关系校验（v2.61 新增，对应 GDD §11.26）----------
# TABLE_RULES 已含 §11.26 十一表：event_quest / faction_base / faction_shop /
# inner_demon / tribulation_item / personality_config / path_config /
# area_stay_weight / disciple_interact / negative_event / morale_loyalty_config。
# 跨表关系校验实现于调用方（validate_all.py 镜像），分层如下：
#   1. check_event_weight_sum：同 event_type 池内（仅 trigger_weight>0 的正式行）trigger_weight 之和必须 = 100。
#      豁免规则：若某 event_type 池内没有任何 trigger_weight>0 的行（纯测试/调试夹具池，如「征伐」），
#      则跳过该池的=100 校验；含 weight>0 行的正式池不受影响，weight=0 行不参与求和。
#   2. check_faction_base_monotonic：同 faction_id 内 need_reputation 必须严格递增。
#   3. check_faction_shop_grade：item_grade 品阶秩 ≤ 由 unlock_reputation 阈值映射的最大品阶
#      （1000→灵品 / 3000→宝品 / 8000→王品 / 20000→圣品 / 0→凡品）。
#   4. check_weight_sum（行为/片区）：personality_config 行为权重和=1、path_config 片区权重和=1、
#      area_stay_weight 五片区权重和=1（epsilon=1e-6）。
#   5. check_prob_range：inner_demon.trigger_prob 与成功率、disciple_interact.trigger_prob、
#      negative_event.base_prob 须∈[0,1]（单行 float 规则已含；此处仅声明口径）。
# 注：tribulation_config.csv（§11.16 既有 19 列）绝不覆盖；本层新增 inner_demon/tribulation_item
#     为独立新表（§11.26.6 硬裁决②）。fz_yuan（远古遗泽）按 TODO-③ 暂缓，未入 faction_base 枚举。

# ---------- 内容厚度扩充系统关系校验（v2.63 新增，对应 GDD §11.27）----------
# TABLE_RULES 已含 §11.27 三净新表：map_config / secret_config / npc_config。
# 本层仅补：历练/秘境地图（净新，含体力系统闸门）、阵营 NPC 人设（对齐 §11.26 阵营 taxonomy）。
# 跨表关系校验实现于调用方（validate_all.py 镜像），分层如下：
#   1. check_map_attr：map_config.main_attr ∈ {金,木,水,火,土}（单行 enum 规则已含）。
#   2. check_secret_layers：secret_config.layers>0 且 boss_info 非空（单行规则已含）。
#   3. check_npc_faction：npc_config.faction_id ∈ {fz_zhengdao,fz_zhongli,fz_mo,fz_yaozu,fz_danqi,fz_yuan,neutral}
#      （单行 enum 规则已含）；丹器师公会=fz_danqi 第6阵营、远古遗泽=fz_yuan 保留（TODO-③）。
# 注：五内容品类（丹药/功法/装备/灵兽/傀儡）引用现有 item_pill/skill/equip_main/spirit_pet/puppet，
#     不建并行表；其 attr 倍率偏差由 §4.7 基准校验、消耗闭环由 §11.24 sink_cost 校验拦截。

# ---------- 经济系统关系校验（v2.59 新增，对应 GDD §11.24）----------
# 本文件仅定义单行 schema 规则（TABLE_RULES 已含 drop_common/resource_base/output_daily/sink_cost）。
# 跨表关系校验实现于调用方（validate_all.py 镜像），分层如下：
#   1. check_drop_weight_sum（已落地）：同 drop_id 池内 drop_weight 之和必须 = 100。
#   2. resource_loop_check（暂缓）：每资源须同时存在产出渠道(output_daily)与消耗出口(sink_cost)，
#      无孤岛资源；待产出/消耗明细 CSV 充实后实现。
#   3. balance_check（暂缓）：各阶段通用资源结余率=5%-25%、稀有资源=-40%~0；
#      需汇总 output_daily vs sink_cost 按 stage 计算，待数据完整后实现。
# 注：GDD §11.24.6.2 原文「各品阶概率之和=100%」已据 CSV 实际结构（按道具权重）修正为
#     「同 drop_id 池内 drop_weight 之和=100」，以匹配 drop_common.csv 与 §11.24.8.4 校验说明。

# ---------- 任务系统关系校验（v2.60 新增，对应 GDD §11.25）----------
# TABLE_RULES 已含 quest_daily/quest_weekly/quest_random/quest_reward_pool 四表。
# 跨表关系校验实现于调用方（validate_all.py 镜像），分层如下：
#   1. check_reward_pool_weight_sum（已落地）：同 pool_id 池内 weight 之和必须 = 100。
#   2. balance_check（暂缓）：单阶段任务日均产出不得超过全局日均产出的 10%；
#      需汇总 quest_* 奖励 vs output_daily 按 stage 计算，待奖励明细充实后实现（同 §11.24 口径）。
# 注：GDD §11.25.8.2 原稿 13.8.2 误将 4 张表写成单一 "quest" 表并内嵌 reward_check/balance_check dict，
#     已按 4 表结构 + 权重和关系校验重写，避免入库即报错。

# ---------- 剧情信物合成校验（v2.66 新增，对应 GDD §16.2.4）----------
# TABLE_RULES 新增 quest_item 表（剧情主线信物 / 合成碎片，独立于 §11.25 任务四表）。
# 跨表关系校验（合成完整性）实现于调用方（validate_all.py 镜像）：
#   1. check_quest_item_combine：同 combine_group 内「任务碎片」行数 必须 == 对应「主线信物」行的 fragment_total；
#      碎片数不符即报错（防数据层漏配 / 多配碎片）。
#   2. check_quest_item_target：每枚「任务碎片」的 combine_target_id 必须指向存在的「主线信物」行，
#      否则报错（防悬空合成目标）。
# 注：quest_item 不参与经济平衡（is_counted_in_balance 恒 false），不计入 §11.24 产出 / 消耗闭环。

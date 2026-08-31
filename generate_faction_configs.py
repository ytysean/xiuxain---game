# -*- coding: utf-8 -*-
"""
生成阵营任务配置表和阵营商店配置表
"""

import os
import csv

config_dir = r"E:\Xiuxian\taixuanzongmenlu\config"

# ============ 1. 阵营任务配置表 ============
print("步骤1：生成阵营任务配置表...")

faction_quests = [
    # 正道宗门任务
    {"quest_id": "fz_zhengdao_001", "faction": "正道宗门", "quest_name": "正道巡山", "quest_type": "daily", "unlock_reputation": "中立", "target_desc": "完成3次山门巡逻", "target_num": 3, "reward_lingjing": 100, "reward_lingqi": 50, "reward_reputation": 20, "description": "正道宗门日常任务，维护山门安宁。"},
    {"quest_id": "fz_zhengdao_002", "faction": "正道宗门", "quest_name": "除魔卫道", "quest_type": "daily", "unlock_reputation": "友善", "target_desc": "清剿2处妖兽巢穴", "target_num": 2, "reward_lingjing": 200, "reward_lingqi": 100, "reward_reputation": 30, "description": "正道宗门日常任务，清剿妖兽保护百姓。"},
    {"quest_id": "fz_zhengdao_003", "faction": "正道宗门", "quest_name": "讲经论道", "quest_type": "weekly", "unlock_reputation": "尊敬", "target_desc": "举办1次讲经法会", "target_num": 1, "reward_lingjing": 800, "reward_lingqi": 400, "reward_reputation": 50, "description": "正道宗周山常任务，弘扬正道心法。"},
    {"quest_id": "fz_zhengdao_004", "faction": "正道宗门", "quest_name": "正道试炼", "quest_type": "weekly", "unlock_reputation": "崇敬", "target_desc": "通过正道高阶试炼", "target_num": 1, "reward_lingjing": 1500, "reward_lingqi": 800, "reward_reputation": 100, "description": "正道宗门专属任务，证明对正道的忠诚。"},
    
    # 魔道邪宗任务
    {"quest_id": "fz_modao_001", "faction": "魔道邪宗", "quest_name": "血祭修炼", "quest_type": "daily", "unlock_reputation": "中立", "target_desc": "完成3次血祭修炼", "target_num": 3, "reward_lingjing": 120, "reward_lingqi": 60, "reward_reputation": 20, "description": "魔道邪宗日常任务，以血祭提升修为。"},
    {"quest_id": "fz_modao_002", "faction": "魔道邪宗", "quest_name": "掠夺资源", "quest_type": "daily", "unlock_reputation": "友善", "target_desc": "掠夺2处商队", "target_num": 2, "reward_lingjing": 250, "reward_lingqi": 120, "reward_reputation": 30, "description": "魔道邪宗日常任务，掠夺资源壮大魔道。"},
    {"quest_id": "fz_modao_003", "faction": "魔道邪宗", "quest_name": "魔道大典", "quest_type": "weekly", "unlock_reputation": "尊敬", "target_desc": "举办1次魔道大典", "target_num": 1, "reward_lingjing": 900, "reward_lingqi": 450, "reward_reputation": 50, "description": "魔道邪宗周常任务，汇聚魔道力量。"},
    {"quest_id": "fz_modao_004", "faction": "魔道邪宗", "quest_name": "魔道试炼", "quest_type": "weekly", "unlock_reputation": "崇敬", "target_desc": "通过魔道高阶试炼", "target_num": 1, "reward_lingjing": 1800, "reward_lingqi": 900, "reward_reputation": 100, "description": "魔道邪宗专属任务，证明对魔道的忠诚。"},
    
    # 中立散修任务
    {"quest_id": "fz_sanxiu_001", "faction": "中立散修", "quest_name": "坊市跑腿", "quest_type": "daily", "unlock_reputation": "中立", "target_desc": "完成3次坊市交易", "target_num": 3, "reward_lingjing": 80, "reward_lingqi": 40, "reward_reputation": 15, "description": "中立散修日常任务，在坊市间奔波。"},
    {"quest_id": "fz_sanxiu_002", "faction": "中立散修", "quest_name": "游历天下", "quest_type": "daily", "unlock_reputation": "友善", "target_desc": "完成2次游历", "target_num": 2, "reward_lingjing": 150, "reward_lingqi": 80, "reward_reputation": 25, "description": "中立散修日常任务，游历四方增长见识。"},
    {"quest_id": "fz_sanxiu_003", "faction": "中立散修", "quest_name": "散修聚会", "quest_type": "weekly", "unlock_reputation": "尊敬", "target_desc": "举办1次散修聚会", "target_num": 1, "reward_lingjing": 700, "reward_lingqi": 350, "reward_reputation": 40, "description": "中立散修周常任务，联络散修情谊。"},
    {"quest_id": "fz_sanxiu_004", "faction": "中立散修", "quest_name": "散修试炼", "quest_type": "weekly", "unlock_reputation": "崇敬", "target_desc": "通过散修高阶试炼", "target_num": 1, "reward_lingjing": 1200, "reward_lingqi": 600, "reward_reputation": 80, "description": "中立散修专属任务，证明散修的自由精神。"},
    
    # 上古妖兽任务
    {"quest_id": "fz_yaoshou_001", "faction": "上古妖兽", "quest_name": "灵兽喂养", "quest_type": "daily", "unlock_reputation": "中立", "target_desc": "喂养3次灵兽", "target_num": 3, "reward_lingjing": 90, "reward_lingqi": 45, "reward_reputation": 15, "description": "上古妖兽日常任务，照料灵兽。"},
    {"quest_id": "fz_yaoshou_002", "faction": "上古妖兽", "quest_name": "妖兽契约", "quest_type": "daily", "unlock_reputation": "友善", "target_desc": "完成2次妖兽契约", "target_num": 2, "reward_lingjing": 180, "reward_lingqi": 90, "reward_reputation": 25, "description": "上古妖兽日常任务，与妖兽建立契约。"},
    {"quest_id": "fz_yaoshou_003", "faction": "上古妖兽", "quest_name": "万兽朝宗", "quest_type": "weekly", "unlock_reputation": "尊敬", "target_desc": "举办1次万兽大会", "target_num": 1, "reward_lingjing": 750, "reward_lingqi": 380, "reward_reputation": 45, "description": "上古妖兽周常任务，召唤万兽朝拜。"},
    {"quest_id": "fz_yaoshou_004", "faction": "上古妖兽", "quest_name": "妖兽试炼", "quest_type": "weekly", "unlock_reputation": "崇敬", "target_desc": "通过妖兽高阶试炼", "target_num": 1, "reward_lingjing": 1300, "reward_lingqi": 650, "reward_reputation": 90, "description": "上古妖兽专属任务，证明与妖兽的深厚羁绊。"},
    
    # 远古遗泽任务
    {"quest_id": "fz_yize_001", "faction": "远古遗泽", "quest_name": "遗迹探索", "quest_type": "daily", "unlock_reputation": "中立", "target_desc": "探索3处遗迹", "target_num": 3, "reward_lingjing": 150, "reward_lingqi": 75, "reward_reputation": 25, "description": "远古遗泽日常任务，探索远古遗迹。"},
    {"quest_id": "fz_yize_002", "faction": "远古遗泽", "quest_name": "宝物鉴定", "quest_type": "daily", "unlock_reputation": "友善", "target_desc": "鉴定2件远古宝物", "target_num": 2, "reward_lingjing": 300, "reward_lingqi": 150, "reward_reputation": 40, "description": "远古遗泽日常任务，鉴定远古宝物。"},
    {"quest_id": "fz_yize_003", "faction": "远古遗泽", "quest_name": "远古传承", "quest_type": "weekly", "unlock_reputation": "尊敬", "target_desc": "参悟1次远古传承", "target_num": 1, "reward_lingjing": 1200, "reward_lingqi": 600, "reward_reputation": 60, "description": "远古遗泽周常任务，参悟远古传承。"},
    {"quest_id": "fz_yize_004", "faction": "远古遗泽", "quest_name": "遗泽试炼", "quest_type": "weekly", "unlock_reputation": "崇敬", "target_desc": "通过遗泽高阶试炼", "target_num": 1, "reward_lingjing": 2000, "reward_lingqi": 1000, "reward_reputation": 120, "description": "远古遗泽专属任务，证明获得远古遗泽的认可。"},
]

# 写入阵营任务配置表
faction_quest_path = os.path.join(config_dir, "faction_quests.csv")
fieldnames = ["quest_id", "faction", "quest_name", "quest_type", "unlock_reputation", "target_desc", "target_num", "reward_lingjing", "reward_lingqi", "reward_reputation", "description"]
with open(faction_quest_path, 'w', encoding='utf-8-sig', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(faction_quests)

print(f"  ✅ 阵营任务配置表已生成：{faction_quest_path}")
print(f"  📊 共 {len(faction_quests)} 个阵营任务")

# ============ 2. 阵营商店配置表 ============
print("\n步骤2：生成阵营商店配置表...")

faction_shop_items = [
    # 正道宗门商店
    {"item_id": "shop_zhengdao_001", "faction": "正道宗门", "item_name": "正道心法残篇", "item_type": "功法", "unlock_reputation": "中立", "price": 500, "description": "正道宗门基础心法残篇，可用于学习正道功法。"},
    {"item_id": "shop_zhengdao_002", "faction": "正道宗门", "item_name": "清心丹", "item_type": "丹药", "unlock_reputation": "友善", "price": 300, "description": "正道宗门秘制丹药，可清除心魔，提升道心。"},
    {"item_id": "shop_zhengdao_003", "faction": "正道宗门", "item_name": "正阳剑", "item_type": "装备", "unlock_reputation": "尊敬", "price": 2000, "description": "正道宗门高阶法器，蕴含正阳之气，克制邪祟。"},
    {"item_id": "shop_zhengdao_004", "faction": "正道宗门", "item_name": "正道传承玉简", "item_type": "特殊", "unlock_reputation": "崇敬", "price": 5000, "description": "正道宗门至高传承，蕴含正道宗师毕生修为。"},
    
    # 魔道邪宗商店
    {"item_id": "shop_modao_001", "faction": "魔道邪宗", "item_name": "魔功残篇", "item_type": "功法", "unlock_reputation": "中立", "price": 500, "description": "魔道邪宗基础魔功残篇，可用于学习魔道功法。"},
    {"item_id": "shop_modao_002", "faction": "魔道邪宗", "item_name": "嗜血丹", "item_type": "丹药", "unlock_reputation": "友善", "price": 350, "description": "魔道邪宗秘制丹药，以精血炼制，短期大幅提升攻击力。"},
    {"item_id": "shop_modao_003", "faction": "魔道邪宗", "item_name": "噬魂幡", "item_type": "装备", "unlock_reputation": "尊敬", "price": 2200, "description": "魔道邪宗高阶法器，可吞噬敌人魂魄，增强自身。"},
    {"item_id": "shop_modao_004", "faction": "魔道邪宗", "item_name": "魔道传承玉简", "item_type": "特殊", "unlock_reputation": "崇敬", "price": 5500, "description": "魔道邪宗至高传承，蕴含魔道宗师毕生修为。"},
    
    # 中立散修商店
    {"item_id": "shop_sanxiu_001", "faction": "中立散修", "item_name": "散修心得", "item_type": "功法", "unlock_reputation": "中立", "price": 400, "description": "散修游历天下的心得笔记，包含各种实用技巧。"},
    {"item_id": "shop_sanxiu_002", "faction": "中立散修", "item_name": "辟谷丹", "item_type": "丹药", "unlock_reputation": "友善", "price": 200, "description": "散修常用丹药，服用后可数日不饥，适合长期游历。"},
    {"item_id": "shop_sanxiu_003", "faction": "中立散修", "item_name": "百宝囊", "item_type": "装备", "unlock_reputation": "尊敬", "price": 1500, "description": "散修常用储物法器，空间巨大，可收纳各种物品。"},
    {"item_id": "shop_sanxiu_004", "faction": "中立散修", "item_name": "散修传承玉简", "item_type": "特殊", "unlock_reputation": "崇敬", "price": 4000, "description": "历代散修高手的传承合集，蕴含自由修行的真谛。"},
    
    # 上古妖兽商店
    {"item_id": "shop_yaoshou_001", "faction": "上古妖兽", "item_name": "灵兽契约书", "item_type": "特殊", "unlock_reputation": "中立", "price": 600, "description": "上古妖兽一族的契约书，可与灵兽建立契约。"},
    {"item_id": "shop_yaoshou_002", "faction": "上古妖兽", "item_name": "灵兽食粮", "item_type": "材料", "unlock_reputation": "友善", "price": 150, "description": "上古妖兽一族特制的灵兽食粮，可提升灵兽亲密度。"},
    {"item_id": "shop_yaoshou_003", "faction": "上古妖兽", "item_name": "兽魂玉", "item_type": "装备", "unlock_reputation": "尊敬", "price": 1800, "description": "蕴含妖兽魂魄的玉石，可增强灵兽战斗力。"},
    {"item_id": "shop_yaoshou_004", "faction": "上古妖兽", "item_name": "上古灵兽蛋", "item_type": "特殊", "unlock_reputation": "崇敬", "price": 6000, "description": "上古妖兽一族的至宝，可孵化出稀有上古灵兽。"},
    
    # 远古遗泽商店
    {"item_id": "shop_yize_001", "faction": "远古遗泽", "item_name": "远古符文", "item_type": "材料", "unlock_reputation": "中立", "price": 800, "description": "远古遗迹中发现的神秘符文，蕴含远古力量。"},
    {"item_id": "shop_yize_002", "faction": "远古遗泽", "item_name": "时光丹", "item_type": "丹药", "unlock_reputation": "友善", "price": 500, "description": "远古遗泽秘制丹药，可短暂回溯时间，修复损伤。"},
    {"item_id": "shop_yize_003", "faction": "远古遗泽", "item_name": "远古神器碎片", "item_type": "材料", "unlock_reputation": "尊敬", "price": 3000, "description": "远古神器的碎片，收集足够数量可重铸远古神器。"},
    {"item_id": "shop_yize_004", "faction": "远古遗泽", "item_name": "远古传承玉简", "item_type": "特殊", "unlock_reputation": "崇敬", "price": 8000, "description": "远古文明的至高传承，蕴含失落的远古知识和力量。"},
]

# 写入阵营商店配置表
faction_shop_path = os.path.join(config_dir, "faction_shop.csv")
fieldnames = ["item_id", "faction", "item_name", "item_type", "unlock_reputation", "price", "description"]
with open(faction_shop_path, 'w', encoding='utf-8-sig', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(faction_shop_items)

print(f"  ✅ 阵营商店配置表已生成：{faction_shop_path}")
print(f"  📊 共 {len(faction_shop_items)} 个阵营商店商品")

print("\n🎉 阵营任务和阵营商店配置表生成完成！")

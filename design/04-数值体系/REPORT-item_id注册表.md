# item_id 主注册表与悬空引用扫描

## 一、主注册表统计（物品类 ID 全集）

| 来源表 | 主键列 | ID 数 |
| --- | --- | --- |
| item_pill | pill_id | 44 |
| item_talisman | talisman_id | 37 |
| equip_main | equip_id | 45 |
| treasure_normal | treasure_id | 36 |
| treasure_innate | innate_id | 25 |
| puppet | puppet_id | 36 |
| equip_blueprint | blueprint_id | 19 |
| quest_item | item_id | 3 |
| tribulation_item | item_id | 4 |
| item_material | item_id | 0 |
| spirit_pet | pet_id | 30 |
| skill | skill_id | 15 |
| skill_cultivation | skill_id | 39 |
| **合计（去重）** | — | **333** |

## 二、悬空引用明细（引用的 ID 不在主注册表内）

### achievement_config.reward_id —— 89 处悬空
- 去重缺失 ID（73 个）: bao_ji_dan、bao_pin_cailiao、bao_pin_gong_fa、bao_pin_kui_lei_hexin、bao_pin_zhuangbei、cang_bao_tu、chang_sheng_dan、chuan_cheng_suipian、dao_yu_dan、ding_hun_dan、duiying_mijing_taozhuang、duiying_pinjie_zhuangbei、dun_wu_dan、er_jie_kuang_shi、er_jie_ling_cao、fan_pin_wu_qi、gong_fa_can_juan、gu_jin_dan、guaiwu_cailiao、haoyou_shangxian、hexin_gongfa、hexin_jinengshu、hui_ling_dan、ji_guan_cai_liao、jian_zhu_cai_liao、jiaoyi_shouxufei、jie_e_dan、jin_gang_dan、jiu_zhuan_huan_hun_dan、ju_qi_dan、kuang_shi、kui_lei_weixiu_cailiao、li_zhuang_dan、lianmeng_jianzhu、liaotian_qipao、lilian_cishu、ling_cao、ling_cao_zhong_zi、ling_pin_qing_yan_lu、ling_pin_zhuangbei、ling_shou_si_liao、mijing_yaoshi、po_jia_dan、po_zhang_dan、qi_yu_xiansuo、qing_du_dan、qing_xin_dan、shang_gu_can_juan、shijie_boss_cailiao、ti_li_yao_shui、tian_nu_dan、tie_bi_dan、tujian_buquan_wupin、tupo_dan、wang_pin_dan_fang、wang_pin_kui_lei_tuzhi、wang_pin_suipian、wang_pin_tu_zhi、wu_xing_cailiao、xi_sui_dan…
- 示例行: 2行→zhu_ji_dan (type=道具); 3行→gu_jin_dan (type=道具); 4行→ying_yuan_dan (type=道具); 5行→ling_pin_qing_yan_lu (type=道具); 7行→gong_fa_can_juan (type=道具); 8行→xi_sui_dan (type=道具); 9行→qing_xin_dan (type=道具); 10行→tupo_dan (type=道具)

### drop_common.item_id —— 19 处悬空
- 去重缺失 ID（19 个）: equip_armor_002、equip_set_piece_01、equip_sword_001、mat_herb_001、mat_herb_002、mat_herb_003、mat_ore_001、mat_ore_002、mat_ore_003、mat_ore_004、mat_rare_001、mat_rare_002、mat_rare_003、mat_rare_004、pill_jin_001、pill_qi_001、pill_zhu_001、treasure_innate_frag、treasure_normal_001
- 示例行: 1行→mat_herb_001; 2行→mat_ore_001; 3行→pill_qi_001; 4行→equip_sword_001; 5行→mat_rare_001; 6行→mat_herb_002; 7行→mat_ore_002; 8行→pill_zhu_001

### quest_reward_pool.item_id —— 51 处悬空
- 去重缺失 ID（51 个）: pool_daily_1_frag、pool_daily_1_ling、pool_daily_1_luck、pool_daily_1_pill、pool_daily_1_raw、pool_daily_2_frag、pool_daily_2_ling、pool_daily_2_luck、pool_daily_2_pill、pool_daily_2_raw、pool_daily_3_frag、pool_daily_3_ling、pool_daily_3_luck、pool_daily_3_pill、pool_daily_3_raw、pool_daily_4_frag、pool_daily_4_ling、pool_daily_4_luck、pool_daily_4_pill、pool_daily_4_raw、pool_random_chore_ling、pool_random_chore_luck、pool_random_chore_raw、pool_random_omens_blue、pool_random_omens_ling、pool_random_omens_page、pool_random_urgent_def、pool_random_urgent_ling、pool_random_urgent_luck、pool_random_visit_ling、pool_random_visit_luck、pool_random_visit_mat、pool_random_visit_sp、pool_weekly_1_equip、pool_weekly_1_frag、pool_weekly_1_ling、pool_weekly_1_luck、pool_weekly_1_pill、pool_weekly_1_raw、pool_weekly_2_equip、pool_weekly_2_frag、pool_weekly_2_ling、pool_weekly_2_luck、pool_weekly_2_pill、pool_weekly_2_raw、pool_weekly_3_equip、pool_weekly_3_frag、pool_weekly_3_ling、pool_weekly_3_luck、pool_weekly_3_pill、pool_weekly_3_raw
- 示例行: 1行→pool_daily_1_raw; 2行→pool_daily_1_pill; 3行→pool_daily_1_ling; 4行→pool_daily_1_frag; 5行→pool_daily_1_luck; 6行→pool_daily_2_raw; 7行→pool_daily_2_pill; 8行→pool_daily_2_ling

### faction_shop.item_id —— 10 处悬空
- 去重缺失 ID（10 个）: item_dq_001、item_dq_002、item_mo_001、item_mo_002、item_yz_001、item_yz_002、item_zd_001、item_zd_002、item_zl_001、item_zl_002
- 示例行: 1行→item_zd_001; 2行→item_zd_002; 3行→item_zl_001; 4行→item_zl_002; 5行→item_mo_001; 6行→item_mo_002; 7行→item_yz_001; 8行→item_yz_002


## 三、汇总
- 主注册表物品类 ID 去重总数: **333**
- 悬空引用总数: **169**

> 说明：成就 reward_id 仅当 reward_type 为物品类（道具/装备/材料/阵法/种子/弟子/功能）时计入悬空；
> 灵石/代币/声望/永久增益/称号/传说称号/外观/buff 等非物品奖励，其 ID 库（称号/外观/功能）尚未建表，不计入本次悬空。
> 悬空引用为数据层隐患：奖励/掉落/售卖指向不存在的物品，运行期会发不出奖励或报错。建议补全物品或改为合法 ID。

_本报告由 build_item_registry.py 自动生成。_
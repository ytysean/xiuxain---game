# -*- coding: utf-8 -*-
# P0 目标链系统 · 阶段A 配置层补丁
# 仅改 .csv 本体（不碰 .import/.translation）：
#   1) quest_daily.csv 表头扩 5 字段；daily_001~003 补 5 列；追加 7 条 newbie（unlock_sect_level=1，合法枚举）
#   2) quest_reward_pool.csv 追加 pool_newbie（权重和=100）
# 写入强制 LF（newline=''），避免 Windows CRLF 触发 GDScript Parser Error
import io, os

ROOT = os.path.dirname(os.path.abspath(__file__))
QD = os.path.join(ROOT, "config", "quest_daily.csv")
RP = os.path.join(ROOT, "config", "quest_reward_pool.csv")

NEW_HEADER = "quest_id,quest_name,quest_type,unlock_sect_level,difficulty,target_desc,target_num,reward_lingjing,reward_lingqi,reward_pool_id,active_point,daily_limit,is_auto_complete,jump_path,condition_type,is_newbie,prev_quest_id,is_auto_trigger"

# daily_001~003 扩展的 5 列
EXT = {
    "daily_001": "宗门/收益栏/领取按钮,collect_daily_income,false,,true",
    "daily_002": "弟子/详情/修炼状态,close_cultivation,false,,true",
    "daily_003": "弟子/详情/境界,weekly_breakthrough,false,,true",
}

# 7 条 newbie（unlock_sect_level 原 7→1；quest_type 原 newbie→合法枚举；is_newbie=true）
NEWBIE = [
    "newbie_001,再纳一名弟子,互动,1,难度Ⅰ,宗门初立，当广纳弟子，以固根基,2,200,50,pool_newbie,10,0,false,弟子/接引,recruit_count,true,,false",
    "newbie_002,首遣弟子历练,探索,1,难度Ⅰ,根基初稳，可遣弟子外出历练，寻访机缘,1,300,80,pool_newbie,15,0,false,历练/秘境,realm_first_enter,true,newbie_001,false",
    "newbie_003,首次收取日供,经营,1,难度Ⅰ,宗门每日自有产出，待宗主查收,1,200,30,pool_newbie,8,0,false,宗门/收益栏,collect_income,true,newbie_002,true",
    "newbie_004,首桩宗门轶事,互动,1,难度Ⅰ,宗门运转，自有诸事发生，静候决断,1,200,40,pool_newbie,10,0,false,纪事,event_first_trigger,true,newbie_003,true",
    "newbie_005,炼气三层初成,养成,1,难度Ⅰ,弟子潜心修行，自有境界突破之喜,1,400,100,pool_newbie,20,0,false,弟子/详情,disciple_realm_3,true,newbie_004,true",
    "newbie_006,炼气五层精进,养成,1,难度Ⅰ,修行日深，炼气五层是宗门战力根基,1,600,150,pool_newbie,30,0,false,弟子/详情,disciple_realm_5,true,newbie_005,true",
    "newbie_007,五人宗门初具,养成,1,难度Ⅰ,弟子满五，宗门初具规模，道途渐宽,5,1000,200,pool_newbie,50,0,false,弟子/名录,recruit_count_5,true,newbie_006,true",
]

# ---- 读现有 quest_daily.csv（utf-8-sig 去 BOM）----
with io.open(QD, "r", encoding="utf-8-sig", newline="") as f:
    lines = [ln.rstrip("\n").rstrip("\r") for ln in f]
# 去掉可能的尾部空行
while lines and lines[-1].strip() == "":
    lines.pop()

# 现有 13 列表头校验
assert lines[0].startswith("quest_id,quest_name,quest_type,unlock_sect_level,difficulty"), "表头不匹配，中止"
# 替换表头
lines[0] = NEW_HEADER

out_lines = [lines[0]]
for ln in lines[1:]:
    if not ln.strip():
        continue
    cols = ln.split(",")
    qid = cols[0]
    if qid in EXT:
        # 维持原有 13 列 + 扩展 5 列
        out_lines.append(ln + "," + EXT[qid])
    else:
        # daily_004~016：维持原 13 列（短行由 _read_csv 补 ""，validate_all DictReader 补 None，均不报错）
        out_lines.append(ln)

# 追加 7 条 newbie
out_lines.extend(NEWBIE)

with io.open(QD, "w", encoding="utf-8", newline="") as f:
    f.write("\n".join(out_lines) + "\n")
print("quest_daily.csv 已写：%d 行（含表头）" % len(out_lines))

# ---- quest_reward_pool.csv 追加 pool_newbie（权重和=100）----
with io.open(RP, "r", encoding="utf-8-sig", newline="") as f:
    rlines = [ln.rstrip("\n").rstrip("\r") for ln in f]
while rlines and rlines[-1].strip() == "":
    rlines.pop()

# 去重保护：若已含 pool_newbie 则跳过
has_pool = any(ln.startswith("pool_newbie,") for ln in rlines)
POOL_NEWBIE = [
    "pool_newbie,pool_newbie_raw,基础材料·凡品下品,凡品下品,50,20,20,true",
    "pool_newbie,pool_newbie_pill,丹药符箓·凡品中品,凡品中品,25,10,10,true",
    "pool_newbie,pool_newbie_ling,灵石·额外,固定数值,15,5,5,true",
    "pool_newbie,pool_newbie_frag,材料碎片·凡品上品,凡品上品,8,3,3,true",
    "pool_newbie,pool_newbie_luck,气运·微量,固定数值,2,1,1,true",
]
if not has_pool:
    rlines.extend(POOL_NEWBIE)
    with io.open(RP, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(rlines) + "\n")
    print("quest_reward_pool.csv 已追加 pool_newbie：%d 行" % len(rlines))
else:
    print("quest_reward_pool.csv 已含 pool_newbie，跳过追加")

# 权重和自检
w = [50, 25, 15, 8, 2]
assert sum(w) == 100, "pool_newbie 权重和!=100"
print("pool_newbie 权重和 = %d (OK)" % sum(w))

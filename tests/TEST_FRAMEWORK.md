---
doc_id: TEST_FRAMEWORK
doc_title: 测试框架提案（solo 模式）
doc_version: v1.0
update_date: 2026-07-18
doc_type: 测试文档
game_formal_name: 太玄宗门录
game_market_name: 开局接手太玄宗
game_core_ip: 太玄宗
---

# 测试框架提案（solo 模式）

> 版本：v1.0 ｜ 阶段：Phase 4 收口 ｜ 作者：eng-lead（程基岩）
> 对齐：tests/QUALITY_GATES.md（qa-lead）、tests/TEST_STRATEGY.md（qa-lead）、csv_validator.gd、太玄宗门录_核心设定总览.md §4/§9.6/§11.21/§11.24
> 定位：**本文件在 qa-lead 两份文档之上提供「可执行落地方案」**。策略与门控定义权归 qa-lead；本文给出具体手段、文件落点与自动化/人工边界。

---

## 0. 模式说明与本环境约束

- 本环境**无 Godot 运行器**：真机 smoke / playtest 不可行（QUALITY_GATES §0）。
- 因此测试分两类：**能在无引擎下验证的 → 尽量自动化**；**只能真机/人工的 → 明确留给人工并给清单**（TEST_STRATEGY §0）。
- 本提案四类手段对应 QUALITY_GATES 的 **CR / CV / LS / SC**：
  - (a) 扩展 `csv_validator.gd` + `validate_all` 镜像 → **CV**
  - (b) GDScript 单元自测（pure-function 逻辑测）→ **LS**
  - (c) 人工代码评审清单 → **CR**
  - (d) 存档兼容验证脚本（§11.21）→ **SC**

> ⚠️ 边界：GDScript headless（`godot --headless`）需在 **CI/有引擎环境** 跑；(b) 的 Python 镜像(`logic_mirror`) 是无引擎时的 solo 兜底，两者断言应保持一致。

---

## 1. (a) CSV 校验扩展 + `validate_all` 镜像

### 1.1 现状缺口
- `csv_validator.gd` **仅有 `TABLE_RULES` + 枚举常量，无执行函数**；头部注释声明「实际解析/校验逻辑由调用方实现」。
- 跨表关系校验（权重和=100）依赖不存在的 `validate_all.py`（QUALITY_GATES §0 已标 CONCERNS）。
- 仓库无引擎时，**48 表 schema 校验当前也无法在 CI 跑**。

### 1.2 扩展 `csv_validator.gd`（仅新增规则，不改既有）
需为四大缺口新增/补表（仅在 `TABLE_RULES` 加条目，遵循「配置为唯一真相源」）：

| 新表 | 校验重点 | 关联缺口 | 优先级 |
| --- | --- | --- | --- |
| `adventures` **（新建 §10 核心池）** | `category`∈8类；`rarity`∈{普通,稀有,珍稀,传说}；四档权重合计=**10000**；`threshold_{aggro,altruism,wisdom,greed}`∈0–100；`wuxing_attr` 合法；低于弟子2大境界重roll 的权重分布 | 奇遇 B1/B4 | P0（核心池，缺则引擎降级 `Lore.取奇遇` 兜底） |
| `random_entry_pool` | `rarity` 补齐第4档「传说/金」（`weight_legend`）；`apply_slots` 含 9 穿戴位；四档权重映射；同 `pool_id` 权重和=100 | 奇遇 B4（奖励词条层） | P1 |
| `event_quest` | 扩写为 §10.1 珍稀+ 干预分支全集；`rarity` 对齐四档（绿/蓝/紫/金）；`opt1/2/3` 存在性；`trigger_weight` 同池和=100 | 奇遇 B5 | P1 |
| `quest_random` | 归属「访客委托/妖兽悬赏」独立随机任务系统（**非奇遇引擎源**）；`trigger_prob` 区间 | 独立随机任务 | P2（不并入奇遇池） |
| `equip_main` / `equip_set` / `equip_blueprint` | 槽位枚举对齐 `EQUIP_SLOTS`（7 槽）；`target_equip_id` 存在性 | 装备 A1 | P0（已部分存在，补全 `equip_set`） |
| `skill` / `skill_cultivation` | 倍率/冷却/灵耗区间；`profession` 枚举对齐裁决后的职业命名 | 战斗 C3 | P3 |

### 1.3 `validate_all` 镜像（落地形态）
**建议落 `tests/validate_all.py`**（Python，无引擎可跑；CI 也可复用）：
```python
# tests/validate_all.py 骨架（提案，非本阶段创建）
import csv, glob, sys
RULES = {...}  # 镜像 csv_validator.TABLE_RULES（单一真相源，可由 .gd 导出或手写保持同步）

def check_schema(path, rule): ...          # 必填/主键/枚举/区间
def check_cross_table_weight():            # drop_common: 同 drop_id 和=100
    # quest_reward_pool: 同 pool_id 和=100
    # event_quest/quest_random: 同 event_type 触发权重和=100
def main():
    errors = []
    for f in glob.glob("config/*.csv"):
        errors += check_schema(f, RULES.get(table_of(f), {}))
    errors += check_cross_table_weight()
    print(f"CSV 校验：{len(errors)} 错误")
    sys.exit(1 if errors else 0)
```
- **自动化**：✅ 完全可自动化（Python，无引擎）。CI 门控：48 表 + 跨表权重零错误才放行（TEST_STRATEGY §1.3）。
- 同步策略：`.gd` 的 `TABLE_RULES` 为权威；`validate_all.py` 镜像之，变更时同步（避免双源漂移）。

### 1.4 GDScript 运行器（有引擎时）
- 提案 `tests/run_csv_check.gd`：`extends SceneTree`，遍历 `config/*.csv` 调 `csv_validator` 规则，输出到 `validate_report.txt`（仓库已存在空文件，复用）。
- **自动化**：✅ 有引擎时；本环境 ❌（无运行器）。

---

## 2. (b) GDScript 单元自测模式（pure-function 逻辑测）

### 2.1 原则
- 把无副作用纯函数从 `.gd` 抽为可独立调用；用 `assert` 断言不变量（TEST_STRATEGY §2）。
- **可测纯函数清单**（对应四大缺口）：
  | 函数 | 文件落点 | 断言要点 | 对应质量门 |
  | --- | --- | --- | --- |
  | `计算战力()` / `聚合通用增益()` | disciple.gd / power.gd | §4.2 公式；穿戴↑卸载↓；通用增益 clamp 25%/30% | G3 E1/E2/E4 |
  | `wuxing_multiplier(atk,def,purity)` | combat.gd | §9.6 系数矩阵+纯度+边界 1.25/0.82+真实伤害 1.0 | G3 通用 |
  | `roll_rarity(weights)` / `roll_entry(pool)` | quest.gd | 四档 10000；同池和=100；重 roll 边界 | G1/G3 |
  | `aggregate_multipliers(zone_map)` | power.gd | 跨乘区严格相乘；道心≤10%；减耗≤40%不进战力 | G2/G3 |

### 2.2 GDScript headless 运行（有引擎/CI）
```gdscript
# tests/logic_tests.gd 骨架（提案）
extends SceneTree
func _init():
    assert_eq(计算战力(满配样例), 期望值, "E1 穿戴战力")
    assert_eq(wuxing_multiplier("金","木","单"), 1.25, "§9.6 单灵根克制")
    assert_eq(wuxing_multiplier("金","木","单", true), 1.0, "真实伤害不触发克制")
    quit()
```
- 运行：`godot --headless --script tests/logic_tests.gd`（CI 用）。
- **自动化**：✅ 有引擎；本环境 ❌。

### 2.3 Python 镜像兜底（solo 无引擎）
- 提案 `tests/logic_mirror/*.py`（`pytest`），复算同一批公式，断言一致。
- 含随机的（奇遇抽取）用**固定 seed + 分布断言**隔离 flaky（TEST_STRATEGY §2.5）。
- **自动化**：✅ 无引擎可跑（本环境首选）。

### 2.4 自动化边界
- ✅ 纯函数（战力/五行/增益乘区/奇遇权重）：全自动化。
- ❌ 含 UI/随机分布/真机集成：仅逻辑层可测，集成层靠 CR+SC 替代（见 §3/§4）。

---

## 3. (c) 人工代码评审清单（CR）

> 无法自动化，须人读 `.gd` 串联逻辑。清单对齐 QUALITY_GATES G2。

- [ ] **命名规范**：蛇形/项目风格一致；无 `tmp`/`test123`；常量集中，无散落字面量。
- [ ] **存档兼容 §11.21**：新增数据只在业务分区扩展；字段三原则（只新增+默认／不修改／不删除）；不改元数据头格式、不改主键 ID 规则、不改全局枚举顺序。
- [ ] **数值红线 §4.1**：所有增益显式归属乘区；通用 ≤25%(软)/30%(硬，溢出 20% 衰减)；道心 ≤10%；减耗 ≤40%；产出效率单建筑 ≤20%/全 ≤30% 不进战力。
- [ ] **无硬编码**：增益/克制/权重阈值从 config/CSV 或常量读取，提供单一可读来源。
- [ ] **乘区归属 §4.6**：同乘区内加算再转系数，跨乘区严格相乘；单源子帽+池总帽双重保险。
- [ ] **跨模块耦合**：战斗/奇遇只消费数据契约（快照），不反向持有 `Game`/单例；UI 不持有游戏状态。
- [ ] **回归对照**：本次变更未触达既有分区/枚举/主键（对照 G2「无回归」）。

**自动化**：❌ 必须人工。建议主理人 solo 走查 + eng/qa 互审。

---

## 4. (d) 存档兼容验证脚本（§11.21）

### 4.1 验证目标（对照 ARCHITECTURE §3.2 / ADR-001 §6）
当前 `save_game/load_game` 违反 §11.21（无元数据头/checksum）。脚本须验证：
1. **双层结构**：存档 = 元数据头（save_version/save_timestamp/save_index/data_checksum/reserved）+ 业务数据体。
2. **字段三原则**：只新增（有默认）/不修改/不删除。
3. **向后兼容**：旧档（单层 flat）读入不丢不崩，新增字段自动补全。
4. **自修复**：悬空 `equip_id`（指向不存在物品）读档自动卸下归还，不空指针（§11.21.5）。

### 4.2 脚本骨架（提案 `tests/save_compat_check.py`，无引擎可跑）
```python
# tests/save_compat_check.py 骨架（提案）
def build_legacy_save_v0(): ...        # 构造现有单层 flat 存档（含 disciples/items）
def migrate_to_double_layer(d): ...    # 包成 {meta:{...}, data:{...}} + CRC32
def roundtrip(d): ...                  # 存→改(穿/卸装备)→存→读→再存
def diff_fields(before, after): ...    # 业务分区无丢失/类型无漂移
def check_meta_head(d): ...            # save_version/checksum/reserved 合规
def check_three_principles(old, new): ... # 只新增+默认；无改名/删除
def check_self_heal(d): ...            # 悬空 equip_id → 自动卸下归还
def main():
    # 用例① 旧档兼容 ② 迁移(主版本) ③ 回退还原 ④ 自修复
    ...
```
- **自动化**：✅ 无引擎可跑（Python 比对 JSON）。
- 真机加载六步流程（备份→版本校验→完整性→增量→二次校验→结果）在**有引擎时**由 `save_game/load_game` 实现并单测；本环境只验证逻辑层 diff。

### 4.3 与质量门对应
- G3 通用项「存档读写往返」：构造含典型数据的 `save.json`，存→读→存 diff（§4.2 roundtrip）。
- G4 三项用例（旧档兼容/迁移/回退）：脚本覆盖 ①②④；迁移/回退脚本仅主版本需要（§11.21.2）。

---

## 5. 自动化矩阵（哪些能自动 / 哪些只能人工）

| 测试项 | 层 | 本环境可自动化？ | 手段 | 对应门 |
| --- | --- | --- | --- | --- |
| 48 表 schema + 跨表权重和=100 | DATA | ✅（Python 镜像） | validate_all.py | G1/G4 |
| 装备战力聚合 / 卸载回退 / 乘区不破 | LOGIC | ✅（Python 镜像）/ ✅(有引擎 GDScript) | logic_mirror / logic_tests.gd | G3 E1~E4 |
| 奇遇权重和=100 / 重 roll 边界 | LOGIC | ✅ | logic_mirror | G1/G3 |
| 五行克制矩阵 | LOGIC | ✅ | logic_mirror / logic_tests.gd | G3 通用 |
| 增益乘区聚合 | LOGIC | ✅ | logic_mirror | G2/G3 |
| 存档往返 diff / 双层结构 / 三原则 / 自修复 | INTEG | ✅（Python diff）/ ⚠️(真机加载需引擎) | save_compat_check.py | G3/G4 |
| 代码评审（命名/红线/无硬编码/耦合） | — | ❌ 人工 | CR 清单 §3 | G2 |
| UI/UX 竖屏单手 / 降级表现 / 引导走查 | MANUAL | ❌ 人工 | UX 清单（design/art） | 人工层 |

---

## 6. 风险与待办（回传主理人）

1. **validate_all 镜像缺失**：跨表权重校验当前在 CI 跑不了（CONCERNS）→ 本提案 §1.3 落地即解。
2. **csv_validator 无执行**：需补 §1.3/§1.4 运行器；仅加 TABLE_RULES 不够。
3. **无引擎**：LS 的 GDScript 形态与 SC 真机加载六步需 CI/有引擎环境；solo 阶段以 Python 镜像 + CR 兜底（QUALITY_GATES §0）。
4. **数值基线依赖**：E4（乘区不破红线）的 PASS 依赖 design-strategist 给装备单源子帽基线（G3 出口门）；在拿到前 E4 判 CONCERNS，属资料缺口非实现缺陷。
5. **存档双层改造**：§4.2 脚本依赖 ADR-001 §6 先把元数据头写入 `save_game`；建议首个冲刺 A4 一并补（H2）。

---

*本框架提案在 qa-lead 的 QUALITY_GATES/TEST_STRATEGY 之上提供可执行落点；具体 harness 文件（validate_all.py / logic_tests.gd / save_compat_check.py）为 Phase 5 实现物，不在本阶段创建。solo 模式最终放行权归主理人。*

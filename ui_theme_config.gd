# ui_theme_config.gd — 《太玄宗门录》S1 UI 重架构 · 数据驱动动态色值（Autoload: UIThemeConfig）
# 职责（见 UI设计令牌v1.0.md §4 分层边界）：
#   - 只放「以 Token ID 为键的动态色值表」，供运行时读取 / 换皮；
#   - 不放 StyleBox 实现、不放字体绑定（那属 .tres / ui_theme.gd）。
# 色值唯一来源：design/06-角色与UI/UI设计令牌v1.0.md。禁止在此硬编码散落色值。
# 两处主理人裁定（已定稿）：
#   - 灵品 = #3FA9C9（青蓝），不再与良品 #4CAF7A 同色。
#   - 正文拆为 body(#E0D5BE) + body-dim(#C8B896)（STATE/HINT 等弱色沿用此调性）。
extends Node

# ───────── 品级（物品/装备，8 档）─────────
# 键 = tier.* 的品级 stem（与 ICON_BY_LABEL / 业务数据约定一致）。
const QUALITY_COLOR: Dictionary = {
	"fan":   Color.from_string("#D6D6D6", Color.WHITE),   # 凡品
	"liang": Color.from_string("#4CAF7A", Color.WHITE),   # 良品
	"ling":  Color.from_string("#3FA9C9", Color.WHITE),   # 灵品（主理人裁定：青蓝，区别于良品）
	"bao":   Color.from_string("#5B8BD9", Color.WHITE),   # 宝品
	"wang":  Color.from_string("#D9A04C", Color.WHITE),   # 王品
	"sheng": Color.from_string("#B04CD9", Color.WHITE),   # 圣品
	"xian":  Color.from_string("#F0E6B0", Color.WHITE),   # 仙品
	"dao":   Color.from_string("#E8F0FF", Color.WHITE),   # 道品
}

# ───────── 境界（5 档）─────────
const REALM_COLOR: Dictionary = {
	"lianqi":   Color.from_string("#C8B896", Color.WHITE), # 练气（与 body-dim 同值）
	"zhuji":    Color.from_string("#4CAF7A", Color.WHITE), # 筑基
	"jindan":   Color.from_string("#5B8BD9", Color.WHITE), # 金丹
	"yuanying": Color.from_string("#D9A04C", Color.WHITE), # 元婴
	"huashen":  Color.from_string("#B04CD9", Color.WHITE), # 化神
}

# ───────── 状态色（success / warn / danger / disabled / 等）─────────
const STATE_COLOR: Dictionary = {
	"success":  Color.from_string("#7ED39A", Color.WHITE), # 成功 / 增益
	"danger":   Color.from_string("#E07878", Color.WHITE), # 警示 / 失败
	"warn":     Color.from_string("#E07878", Color.WHITE), # warn 别名 → 同 danger
	"disabled": Color.from_string("#55554F", Color.WHITE), # 禁用灰
	"gold":     Color.from_string("#E6C778", Color.WHITE), # 标题金（强调）
	"hint":     Color.from_string("#8A7E68", Color.WHITE), # 弱提示（aux）
}

# ───────── 工具函数 ─────────
# 未知 key 时回落默认（白，不染色）并打印 push_warning，不崩。
func set_quality_color(control: Control, quality: String) -> void:
	if control == null:
		return
	var c: Color = QUALITY_COLOR.get(quality, Color.WHITE)
	if not QUALITY_COLOR.has(quality):
		push_warning("UIThemeConfig: 未知品级 '%s'，回落默认色" % quality)
	control.modulate = c

func set_realm_color(control: Control, realm: String) -> void:
	if control == null:
		return
	var c: Color = REALM_COLOR.get(realm, Color.WHITE)
	if not REALM_COLOR.has(realm):
		push_warning("UIThemeConfig: 未知境界 '%s'，回落默认色" % realm)
	control.modulate = c

func set_state_color(control: Control, state: String) -> void:
	if control == null:
		return
	var c: Color = STATE_COLOR.get(state, Color.WHITE)
	if not STATE_COLOR.has(state):
		push_warning("UIThemeConfig: 未知状态 '%s'，回落默认色" % state)
	control.modulate = c

# 只读 getter：供需要取色（而非直接染色）的调用方使用。未知 key 返白。
func get_quality_color(quality: String) -> Color:
	return QUALITY_COLOR.get(quality, Color.WHITE)

func get_realm_color(realm: String) -> Color:
	return REALM_COLOR.get(realm, Color.WHITE)

func get_state_color(state: String) -> Color:
	return STATE_COLOR.get(state, Color.WHITE)

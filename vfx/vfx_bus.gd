extends Node

# VFX 全局总线（autoload: VFXBus）
# 玩家动作成功时由 UI 调用，触发预算内轻量 VFX。
# 仅消费方为 UI；不触碰任何战斗 / 模拟推演逻辑，不引入战斗断言风险。
#
# 实现要点（技术美术）：
# - 全程序化软粒子（GradientTexture2D 径向渐变），零纹理文件、零额外显存
# - 加色混合发光（blend_mode=1=ADD）；一次性爆发（one_shot + explosiveness=1）
# - 粒子数 ≤ 60；one-shot 结束自动 queue_free
# - 引擎属性优先具名直赋（编译期查错）；仅需运行期容错的少数处才用 Object.set()。
#   注意：Godot 4 的 Object.set() 返回 void，**不得取其返回值**（返回 bool 是 Godot 3 语义）。
# - 配色与 UITheme 暗金 / 木绿保持一致，保证视觉统一。

const PRESETS := {
	"breakthrough": {
		"amount": 42, "lifetime": 0.9, "spread": 55.0,
		"vel_min": 90.0, "vel_max": 220.0, "gravity": 120.0,
		"scale_min": 0.5, "scale_max": 1.3,
		"color": Color(1.0, 0.82, 0.36),   # 暗金（突破金光）
	},
	"talisman": {
		"amount": 30, "lifetime": 0.75, "spread": 360.0,
		"vel_min": 40.0, "vel_max": 130.0, "gravity": 0.0,
		"scale_min": 0.35, "scale_max": 1.0,
		"color": Color(0.56, 0.75, 0.62), # 木绿（灵气 / 符箓描金）
	},
	"sparkle": {
		"amount": 24, "lifetime": 0.6, "spread": 360.0,
		"vel_min": 30.0, "vel_max": 110.0, "gravity": 40.0,
		"scale_min": 0.25, "scale_max": 0.8,
		"color": Color(1.0, 0.92, 0.6),
	},
}

func emit_breakthrough(node: Node) -> void:
	_spawn(node, "breakthrough")


func emit_talisman(node: Node) -> void:
	_spawn(node, "talisman")


func emit_sparkle(node: Node) -> void:
	_spawn(node, "sparkle")


# 在 node 中心触发一次预设爆发（node 为 Control 时定位到其中心）
func _spawn(node: Node, preset_name: String) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not PRESETS.has(preset_name):
		return
	var cfg: Dictionary = PRESETS[preset_name]

	var ps := GPUParticles2D.new()
	ps.one_shot = true
	ps.emitting = false
	ps.amount = int(cfg["amount"])
	ps.lifetime = float(cfg["lifetime"])
	ps.explosiveness = 1.0
	ps.speed_scale = 1.0
	ps.texture = _soft_texture()

	var cm := CanvasItemMaterial.new()
	cm.set("blend_mode", 1)   # 1 = BLEND_MODE_ADD（加色发光）
	ps.material = cm

	var mat := ParticleProcessMaterial.new()
	mat.set("direction", Vector3(0.0, -1.0, 0.0))
	mat.set("spread", float(cfg.get("spread", 60.0)))
	mat.set("gravity", Vector3(0.0, float(cfg.get("gravity", 0.0)), 0.0))
	mat.set("initial_velocity_min", float(cfg.get("vel_min", 80.0)))
	mat.set("initial_velocity_max", float(cfg.get("vel_max", 160.0)))
	mat.set("scale_min", float(cfg.get("scale_min", 0.5)))
	mat.set("scale_max", float(cfg.get("scale_max", 1.0)))
	mat.set("color", cfg.get("color", Color(1.0, 1.0, 1.0)))
	mat.set("emission_shape", 0)  # 0 = 点发射
	ps.process_material = mat

	node.add_child(ps)
	if node is Control:
		ps.position = node.size * 0.5
	else:
		ps.position = Vector2.ZERO
	ps.emitting = true
	if not ps.is_connected("finished", ps.queue_free):
		ps.finished.connect(ps.queue_free)


# 程序化径向软粒子纹理（白心→透明边），零文件、零额外显存
func _soft_texture() -> Texture2D:
	var g := Gradient.new()
	g.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
	g.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g   # 具名属性直赋（编译期校验；Object.set() 返回 void，不可用作条件）
	t.fill = GradientTexture2D.FILL_RADIAL
	t.width = 64
	t.height = 64
	return t

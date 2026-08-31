class_name RadarChart
extends Control

var values: Array = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]

func _draw() -> void:
	var cx: float = size.x / 2.0
	var cy: float = size.y / 2.0
	var r: float = min(cx, cy) - 20.0
	# 网格
	for ring_idx in range(4):
		var ring: float = (ring_idx + 1) * 0.25
		var pts := PackedVector2Array()
		for i in range(6):
			var ang: float = -PI / 2.0 + i * PI / 3.0
			pts.append(Vector2(cx + cos(ang) * r * ring, cy + sin(ang) * r * ring))
		pts.append(pts[0])
		var line_col := Color(0.78, 0.65, 0.34, 0.3) if ring_idx == 3 else Color(1, 1, 1, 0.08)
		var line_w := 1.5 if ring_idx == 3 else 1.0
		draw_polyline(pts, line_col, line_w)
	# 轴线
	for i in range(6):
		var ang: float = -PI / 2.0 + i * PI / 3.0
		draw_line(Vector2(cx, cy), Vector2(cx + cos(ang) * r, cy + sin(ang) * r), Color(1, 1, 1, 0.06), 1.0)
	# 数据多边形
	var dpts := PackedVector2Array()
	for i in range(6):
		var ang: float = -PI / 2.0 + i * PI / 3.0
		var v: float = clampf(float(values[i]), 0.0, 1.0)
		dpts.append(Vector2(cx + cos(ang) * r * v, cy + sin(ang) * r * v))
	if dpts.size() >= 3:
		draw_colored_polygon(dpts, Color(0.95, 0.80, 0.30, 0.20))
		dpts.append(dpts[0])
		draw_polyline(dpts, Color(0.95, 0.80, 0.30, 0.8), 2.0)
		for i in range(6):
			draw_circle(dpts[i], 3.5, Color(0.95, 0.80, 0.30))

func set_values(v: Array) -> void:
	values = v
	queue_redraw()

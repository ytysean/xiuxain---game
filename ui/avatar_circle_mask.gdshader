shader_type canvas_item;

// 圆形头像遮罩：将方形 TextureRect 裁成圆形，边缘 1% 羽化抑制硬切锯齿。
// 配合 AtlasTexture 取「顶 1:1 段」使用——纹理已是胸像居中，此 shader 仅裁四角。
void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5, 0.5));
	float a = 1.0 - smoothstep(0.49, 0.50, d);
	COLOR.a *= a;
}

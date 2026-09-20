shader_type canvas_item;
render_mode unshaded, blend_mix;

// 图标底座换肤着色器（青瓷山水主题 · 2026-09-15）
// ───────── ★★★ 2026-09-15 改版：由「素材实心盘」改为「shader 自绘金环」─────────
// 演进两段，都要看：
// 【v2 · 素材实心盘】每套皮肤一张 AI 底座（8 列图集），整体是**实心彩色圆盘**。
//   老大实测反馈三条：①「金色反而看不清了」—— 实测帧4(冬)底色亮度 213、帧5(仙)181，
//   比金色器物本身还亮，金器压在亮彩底上直接糊成一片；②「这个皮肤下看又不太好看」；
//   ③ 正面判定：「可以不要底色只要边框吗？」
// 【v3 · 只留边框（当前）】改为径向环带 + 中心掏空。但实测发现素材的环**逐帧半径与
//   圆心都不一致**（环内径实测：帧0 0.79 / 帧2 0.87 / 帧3~5 明显偏心）——core=0.62 时
//   帧0/1/2 完整而帧3/4/5 被切出缺口，压到 core=0.44 才全完整（见 tests/_probe_base2 的
//   交叉扫描板）。即「无底色」与「环完整」在素材上不可兼得。
//   ⇒ 结论：**几何交给 shader，素材只借纹理**。环带内外径由 uniform 定死，6 帧共用同一
//   几何 ⇒ 永无缺口、色相统一为金（与器物同色系）；只用素材亮度做 ±5% 微起伏，
//   保住 AI 图的细节感，也让各皮肤留一点点色温差异。
//
// 性能：纯片元 ALU（RGB↔HSV 各 1 次），无额外采样；底座尺寸小（≤149 物理像素），移动端可忽略。
// 底图自带 alpha 圆形，外部不再叠 Panel，避免过度绘制。

// 参数：由 UITheme 持有的**唯一共享 ShaderMaterial** 设置（见 ui_theme.gd 设图标底座皮肤()）。
//   切皮肤 = 改这几个参数一次 → 所有底座（首页 / Tab / 各页图标）同帧换色，无需重建节点。
//
// ───────── ★★★ 2026-09-15 v4：金属色「参数化」+ 框体档位 ─────────
// 老大原话：「新的底座框一直是金色，能改成随背景图而换颜色吗？后期花仙玉购买的背景，
//   就能自带更高级更好看的框体了。」
// ① 【为什么要改】v3 是 `hsv.x += ico_hue` —— 在**金色**的 HSV 上做色相偏移，但饱和/明度
//    仍是金的（暗端 S0.90 / 亮端 S0.58）。只挪色相会得到"脏青金 / 灰绿金"，不是清透的青玉。
//    现改为**直接指定目标金属**：ico_hue = 目标色相、ico_sat = 目标亮端饱和，
//    而「暗部更饱和更沉、亮部更淡更亮」这段金属特性改由 hue/sat 上的固定偏移量复现。
//    默认值 (0.116, 0.62) 精确复现 v3 的金色（实算：暗端 H0.086/S0.96/V0.30、
//    亮端 H0.136/S0.62/V1.0 —— 与原 mix(vec3(0.30,0.17,0.03), vec3(1.00,0.86,0.42)) 逐通道吻合）。
// ② 【框体档位 ico_tier】为「仙玉背景自带更高级框」预留的机制：
//      0 = 素环（基础皮肤现状，**零副作用**：装饰项全部被 step() 归零）
//      1 = 双环（环内叠一道收边细线 + 外缘加一道亮线，层次更精致）
//      2 = 鎏金镶宝（双环 + 环带中线等距八颗宝石状亮点，最华丽）
//    档位是**共享材质参数**，切皮肤时由 SKIN_ICON_BASE 一并写入，O(1) 全屏生效。
uniform float ico_hue : hint_range(0.0, 1.0) = 0.116;  // 目标金属色相
uniform float ico_sat : hint_range(0.0, 1.0) = 0.62;   // 目标金属饱和（亮端）
uniform float ico_val : hint_range(0.0, 2.0) = 1.0;    // 明度倍率（基准 1.0）
uniform vec4 ico_tint : source_color = vec4(1.0);      // 乘算染色（基准 白）
uniform float ico_tier : hint_range(0.0, 2.0) = 0.0;   // 框体档位 0/1/2（见上方 ②）

// 图集帧采样：素材仅用于取「纹理亮度」，几何由下方 ico_ring_* 决定。
// grid = (列, 行)；单帧图（非图集）时 grid=(1,1)，走 UV 原样采样。
uniform float ico_frame : hint_range(0.0, 63.0) = 0.0;
uniform vec2 ico_grid = vec2(1.0, 1.0);

// ★ 环带几何（归一化半径：0 = 中心，1 = 画布内切圆）。
//   in=0.775 / out=0.965 与素材原环位置接近，但**由 shader 定死** ⇒ 6 帧完全一致、绝无缺口。
//   内径须大于图标主体外沿（白名单裸图实测中位 r 0.43~0.66、极值 ≤0.87），否则器物会压住环。
uniform float ico_ring_out : hint_range(0.0, 1.2) = 0.965;
uniform float ico_ring_px : hint_range(1.0, 40.0) = 5.5;    // 目标环带宽（**物理像素**）
uniform float ico_ring_aa : hint_range(0.0, 0.3) = 0.030;   // 环缘羽化下限（归一化）
// ★ 每实例参数：该图标的**物理直径** —— 由 UITheme.建图标底座() 用
//   set_instance_shader_parameter 逐节点写入（共享材质照旧，不产生材质副本）。
//   用途：环宽按物理像素恒定。若用固定归一化内径，同一内径在 149px 入口图标上是 7px 好边，
//   到 67.5px 的 dock 图标上只剩 3.2px —— 实机退化成一圈"脏边"。
instance uniform float ico_dia_px : hint_range(1.0, 4096.0) = 150.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	// 图集帧定位：fi = 帧号 → (列,行)；半像素内缩防相邻帧渗色
	vec2 uv = UV;
	if (ico_grid.x > 1.5 || ico_grid.y > 1.5) {
		float fi = floor(ico_frame + 0.5);
		float col = mod(fi, ico_grid.x);
		float row = floor(fi / ico_grid.x);
		vec2 cell = vec2(1.0) / ico_grid;
		vec2 ht = 0.5 * TEXTURE_PIXEL_SIZE;
		uv = clamp((UV + vec2(col, row)) * cell,
				vec2(col, row) * cell + ht,
				vec2(col + 1.0, row + 1.0) * cell - ht);
	}
	vec4 c = texture(TEXTURE, uv);

	// ★ 铁律：Godot 4 的 fragment() 内**禁用 `return`** —— 本函数全程顺序计算、无 early return。
	//   曾用 `if (c.a <= 0.001) { COLOR = vec4(0.0); return; }` 想跳过透明像素，
	//   结果整份 shader 编译失败（SHADER ERROR: Using 'return' in the 'fragment'
	//   processor function is incorrect），Godot 回退成无材质渲染，
	//   于是 TextureRect 把整张 2048×256 图集压进 149px → 实机表现为
	//   「一排 6~8 个底座竖条连在一起」。改回顺序计算即修复，勿再引入提前返回。
	float r = length(UV - vec2(0.5)) * 2.0;

	// 环带遮罩：中心全透空（不要底色），只有环上是实心的。
	// 内径由「目标环宽(物理px) ÷ 本图标物理直径」反推 ⇒ 各处环带宽视觉一致。
	float dia = max(ico_dia_px, 1.0);
	float ring_in = max(ico_ring_out - ico_ring_px * 2.0 / dia, 0.50);
	float aa = max(ico_ring_aa, 2.0 / dia);   // 羽化至少 1 物理像素，避免小尺寸出现硬阶梯
	float ring = smoothstep(ring_in - aa, ring_in + aa, r)
		* (1.0 - smoothstep(ico_ring_out - aa, ico_ring_out + aa, r));

	// 鎏金立体叠四层：① 柱面（内缘凹槽暗 → 内中段箍面亮 → 外缘收边）
	//   ② 外缘一道收边亮线（"箍"的高光边）③ 上亮下暗（受光方向）
	//   ④ 锻打微纹 —— **纯程序化，不取素材**，否则 6 帧亮度差 0.2~0.78 会让环明暗不一致。
	float tex_lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float vert = clamp(0.5 - UV.y, -0.5, 0.5);
	float t = clamp((r - ring_in) / max(ico_ring_out - ring_in, 0.001), 0.0, 1.0);
	float cyl = smoothstep(0.0, 0.26, t) * (1.0 - smoothstep(0.60, 1.0, t) * 0.55);
	float rim = smoothstep(0.76, 0.88, t) * (1.0 - smoothstep(0.88, 1.0, t)) * 0.30;
	float ang = atan(UV.y - 0.5, UV.x - 0.5);
	float grain = sin(ang * 34.0) * 0.014 + sin(t * 22.0) * 0.016;
	float lum = 0.20 + cyl * 0.66 + rim + vert * 0.44 + grain + (tex_lum - 0.5) * 0.05;
	lum = clamp(lum, 0.0, 1.0);

	// ── 框体档位装饰（tier=0 时以下各项被 step() 精确归零 ⇒ 基础皮肤零副作用）──
	float tier = floor(ico_tier + 0.5);
	// ① 环内一道收边细线 + ② 外缘一道亮线 —— 合起来给出"内包边 + 外收边"的双环精致感
	float in_line = smoothstep(0.18, 0.25, t) * (1.0 - smoothstep(0.29, 0.36, t));
	float out_line = smoothstep(0.68, 0.75, t) * (1.0 - smoothstep(0.79, 0.86, t));
	float dbl = step(0.5, tier) * (in_line * 0.26 + out_line * 0.22);
	// ③ 环带中线等距八颗宝石状亮点（cos 八峰锐化），仅 tier≥2 出现
	float gem_ang = ang + 1.5707963;                          // 从正上方起算，视觉对称
	float gems = pow(0.5 + 0.5 * cos(gem_ang * 8.0), 10.0);
	float gem_band = smoothstep(0.32, 0.48, t) * (1.0 - smoothstep(0.60, 0.76, t));
	float gem = step(1.5, tier) * gems * gem_band * 1.15;
	lum = clamp(lum + dbl + gem, 0.0, 1.0);

	// 金属基色（参数化）：暗端「更饱和 + 更沉 + 色相偏暖」，亮端「更淡 + 更亮 + 色相偏白」。
	//   这对 ±0.03 的色相偏移 + 1.55 倍的饱和提升，即真实金属的高光/暗部特性，
	//   无论基色是金 / 青玉 / 紫金 / 银都成立（银的 sat 很低，1.55 倍后仍接近中性灰）。
	vec3 base = mix(
		hsv2rgb(vec3(fract(ico_hue - 0.030), clamp(ico_sat * 1.55, 0.0, 1.0), 0.30)),
		hsv2rgb(vec3(fract(ico_hue + 0.020), ico_sat, 1.00)),
		lum);
	COLOR = vec4(base * ico_val * ico_tint.rgb, ring * ico_tint.a);
}

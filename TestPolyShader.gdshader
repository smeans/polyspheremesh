shader_type spatial;

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
	// EMISSION = COLOR.rgb;
	//ALBEDO = vec3(UV, 0.0);
}
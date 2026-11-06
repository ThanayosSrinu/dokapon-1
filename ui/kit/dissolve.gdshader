// Breaks a sprite into sparks of light, one art pixel at a time. Used on the character
// sheets, so a cell here is one pixel of the sheet.
shader_type canvas_item;

// 0 shows everything and 1 shows nothing.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 spark = vec3(0.66, 0.96, 0.94);
// How many pixels glow just before they go, as a share of the whole.
const float EDGE = 0.2;

void fragment() {
	vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
	float chance = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float reach = progress * (1.0 + EDGE);
	if (chance < reach - EDGE) {
		discard;
	}
	if (chance < reach) {
		COLOR.rgb = spark;
	}
}

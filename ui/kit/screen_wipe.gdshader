shader_type canvas_item;
// Covers the screen with diamonds that grow, sweeping from the left. At progress 0
// nothing is covered, and at 1 everything is.

uniform float progress = 0.0;
uniform vec2 area = vec2(1280.0, 720.0);
// One diamond's cell, in screen pixels. A multiple of the art's 2x pixels.
const float CELL = 48.0;
// How much of the sweep a single diamond takes to grow.
const float GROW = 0.45;

void fragment() {
	vec2 point = UV * area;
	// Rounded to whole art pixels, so the edge stays as chunky as the art.
	point = floor(point / 2.0) * 2.0;
	vec2 inside = fract(point / CELL) - 0.5;
	float reach = abs(inside.x) + abs(inside.y);
	float start = (UV.x + UV.y * 0.25) / 1.25 * (1.0 - GROW);
	float grown = clamp((progress - start) / GROW, 0.0, 1.0);
	COLOR.a = reach <= grown * 1.01 ? COLOR.a : 0.0;
}

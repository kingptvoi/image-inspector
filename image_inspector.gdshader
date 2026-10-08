shader_type canvas_item;

// image inspector diagnostic shader
// supports channel isolation, visual modes, transparency checkerboard, and pixel grid

uniform int channel_mode : hint_range(0, 6) = 0;
// 0: normal rgba, 1: red, 2: green, 3: blue, 4: alpha, 5: invert, 6: grayscale

uniform bool show_checkerboard = true;
uniform float checker_size = 16.0;
uniform vec4 checker_color1 : source_color = vec4(0.18, 0.18, 0.20, 1.0);
uniform vec4 checker_color2 : source_color = vec4(0.25, 0.25, 0.28, 1.0);

uniform bool show_pixel_grid = false;
uniform float current_zoom = 1.0;
uniform float min_grid_zoom = 6.0;
uniform vec4 grid_line_color : source_color = vec4(1.0, 1.0, 1.0, 0.25);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));

	// calculate checkerboard pattern in local pixel coordinates
	vec2 checker_coord = floor(UV * tex_size / checker_size);
	float pattern = mod(checker_coord.x + checker_coord.y, 2.0);
	vec4 checker = mix(checker_color1, checker_color2, pattern);

	vec4 base_color = tex_color;

	if (channel_mode == 1) {
		// red channel isolated
		base_color = vec4(tex_color.r, tex_color.r, tex_color.r, 1.0);
	} else if (channel_mode == 2) {
		// green channel isolated
		base_color = vec4(tex_color.g, tex_color.g, tex_color.g, 1.0);
	} else if (channel_mode == 3) {
		// blue channel isolated
		base_color = vec4(tex_color.b, tex_color.b, tex_color.b, 1.0);
	} else if (channel_mode == 4) {
		// alpha channel mask
		base_color = vec4(tex_color.a, tex_color.a, tex_color.a, 1.0);
	} else if (channel_mode == 5) {
		// invert rgb
		base_color = vec4(vec3(1.0) - tex_color.rgb, tex_color.a);
	} else if (channel_mode == 6) {
		// luminance grayscale
		float lum = dot(tex_color.rgb, vec3(0.2126, 0.7152, 0.0722));
		base_color = vec4(lum, lum, lum, tex_color.a);
	} else {
		// normal view with optional checkerboard behind transparency
		if (show_checkerboard) {
			base_color = vec4(mix(checker.rgb, tex_color.rgb, tex_color.a), 1.0);
		}
	}

	// overlay pixel grid lines when zoomed in
	if (show_pixel_grid && current_zoom >= min_grid_zoom) {
		vec2 pixel_pos = UV * tex_size;
		vec2 grid_dist = fract(pixel_pos);
		vec2 fw = fwidth(pixel_pos);
		if (grid_dist.x < fw.x || grid_dist.y < fw.y) {
			base_color = mix(base_color, grid_line_color, 0.6);
		}
	}

	COLOR = base_color;
}

shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
    // Invert the RGB channels if the pixel isn't transparent
    // This turns a black icon into a white icon at runtime
    COLOR = vec4(1.0, 1.0, 1.0, tex_color.a);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}

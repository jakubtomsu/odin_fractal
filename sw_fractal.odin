package sw_fractal

import "core:fmt"
import "core:mem"
import "core:math"
import c "core:c/libc"
import stbi "vendor:stb/image"



DEBUG :: false

RESOLUTION_X :: 1920
RESOLUTION_Y :: 1080
CHANNELS :: 3
ANTIALIASING :: 2 // samples = ANTIALIASING^2

rgb :: [3]u8
v2 :: [2]f32
iv2 :: [2]i32
v3 :: [3]f32

v2_dot :: proc(a: v2, b : v2) -> f32 {
	return (a[0] * b[0]) + (a[1] * b[1])
}

v2_len :: proc(a: v2) -> f32 {
	return math.sqrt(v2_dot(a, a))
}



texture :: struct {
	x: int,
	y: int,
	size: int,
	data: [^]byte,
}

texture_save :: proc(path: cstring, tex: texture) {
	//fmt.println("saving image to", string(path), "...")
	if stbi.write_jpg(path, cast(c.int)tex.x, cast(c.int)tex.y, CHANNELS, tex.data, 100) == 0 {
		fmt.println("failed to save image")
	}
	//else { fmt.println("done!") }
}

texture_index :: proc(tex: texture, x: int, y: int, channel: int) -> int {
	return ((x + (y * tex.y)) * 3) + channel
}

texture_print_data :: proc(tex: texture) {
	for i: int = 0; i < tex.size; i += 3 {
		fmt.println("index", i, "=\t", tex.data[i], tex.data[i + 1], tex.data[i + 2])
	}
}



mandelbrot_func :: proc(iter_max: int, pos: v2) -> f32 {
	di: f32 = 1.0;
	m2: f32 = 0.0;
	z: v2
	dz: v2
	for iter: int = 0; iter < iter_max; iter += 1 {
		if m2 > 1024.0 {
			di = 0.0
			break
		}
		// Z' -> 2·Z·Z' + 1
		dz = 2.0 * v2{z.x * dz.x - z.y * dz.y + 0.5, z.x * dz.y + z.y * dz.x}
		// Z -> Z² + c
		z = v2{z.x * z.x - z.y * z.y, 2.0 * z.x * z.y} + pos
		m2 = v2_dot(z, z)
	}
	
	// distance	
	// d(c) = |Z|·log|Z|/|Z'|
	dist: f32 = 0.5 * math.sqrt(v2_dot(z, z) / v2_dot(dz, dz)) * math.log_f32(v2_dot(z, z), 10)
	if di > 0.5 do dist = 0.0
	return dist
}

// @param iter_max: ~150 is nice
mandelbrot_fill_texture :: proc(iter_max: int, tex: texture) {
	fmt.print("rendering Mandelbrot fractal ... ")
	index: int = 0
	for y: int = 0; y < tex.y; y += 1 {
		for x: int = 0; x < tex.x; x += 1 {
			scale: f32 = 0.06
			offset: v2 = {-0.55, 0.5}
			xy: v2 = ({cast(f32)x, cast(f32)y} - {cast(f32)tex.x / 2, cast(f32)tex.y / 2}) * 2.0
			pos: v2 = offset + (xy / {cast(f32)tex.x, cast(f32)tex.x}) * scale
			col: v3 = {0.0, 0.0, 0.0}

			for aax: int = 0; aax < ANTIALIASING; aax += 1 {
				for aay: int = 0; aay < ANTIALIASING; aay += 1 {
					offset: v2 = ({cast(f32)aax / cast(f32)tex.x, cast(f32)aay / cast(f32)tex.y} / cast(f32)ANTIALIASING) * scale
					dist := mandelbrot_func(iter_max, pos + offset)
					COLOR_OUTSIDE :: v3{10, 50, 90}
					COLOR_INSIDE :: v3{10, 15, 15}
					COLOR_BORDER :: v3{255, 255, 255}
					COLOR_BLOOM :: v3{100, 185, 255}
					t: f32 = 0.001 / (math.pow(dist, 3.0) + 0.01) * scale
					col += dist <= 0.0 ? COLOR_INSIDE : (COLOR_BLOOM * t + COLOR_OUTSIDE * (1 - t)) + COLOR_BORDER * 0.4 / (math.pow(dist, 0.3) + 0.01) * scale
				}
			}
			col /= ANTIALIASING * ANTIALIASING

			tex.data[index + 0] = cast(u8)clamp(col[0], 0.0, 255.0)
			tex.data[index + 1] = cast(u8)clamp(col[1], 0.0, 255.0)
			tex.data[index + 2] = cast(u8)clamp(col[2], 0.0, 255.0)
			index += 3
		}
		if y % 100 == 0 do fmt.println("row", y)
	}
	fmt.println("done")
}


// good constants:
// {-0.4,  -0.59}
// { 0.34, -0.05}
// { 0.355  0.355}
julia_set_func :: proc(iter_max: int, pos: v2, constant: v2) -> int {
	z: v2 = constant
	iter: int;
	for ;iter < iter_max; iter += 1{
		z = {z.x * z.x - z.y * z.y, 2.0 * z.x * z.x} + constant
		if v2_len(z) > 2.0 do break
	}
	return iter
}

julia_set_fill_texture :: proc(iter_max: int, tex: texture) {
	fmt.print("rendering Julia set fractal ... ")
	index: int = 0
	for y: int = 0; y < tex.y; y += 1 {
		for x: int = 0; x < tex.x; x += 1 {
			zoom: f32 = 3.0
			offset: v2 = {}
			xy: v2 = {cast(f32)x, cast(f32)y}
			pos: v2 = offset + (((xy / v2{cast(f32)tex.x, cast(f32)tex.x}) * 2.0) - v2{1.0, 1.0}) * zoom
			col: v3 = {0.0, 0.0, 0.0}

			iter := julia_set_func(iter_max, pos, { 0.34, -0.05})
			val: f32 = cast(f32)iter
			col += {val, val, val}

			tex.data[index + 0] = cast(u8)col[0]
			tex.data[index + 1] = cast(u8)col[1]
			tex.data[index + 2] = cast(u8)col[2]
			index += 3
		}
		if y % 100 == 0 do fmt.println("row", y)
	}
	fmt.println("done")
}




main :: proc() {
	size: int = RESOLUTION_X * RESOLUTION_Y * CHANNELS
	tex := texture{
		x = RESOLUTION_X,
		y = RESOLUTION_Y,
		size = size,
		data = cast([^]byte)mem.alloc(size, 64),
	}
	fmt.println("resolution =", []int{tex.x, tex.y})

	mandelbrot_fill_texture(200, tex)
	texture_save("./mandelbrot.jpg", tex)

	//julia_set_fill_texture(200, tex)
	//texture_save("./julia_set.jpg", tex)



	when DEBUG {
		texture_print_data(tex)
	}

	fmt.println("[0, 0] = ", mandelbrot_func(200, v2{0, 0}))
	fmt.println("[1, 0] = ", mandelbrot_func(200, v2{1, 0}))
	fmt.println("[10, 0] = ", mandelbrot_func(200,v2{10, 10}))

	fmt.println("[0, 0] = ", julia_set_func(200, v2{0, 0}, {-0.4, 0.59}))
	fmt.println("[1, 0] = ", julia_set_func(200, v2{1, 0}, {-0.4, 0.59}))
	fmt.println("[10, 0] = ", julia_set_func(200,v2{10, 10}, {-0.4, 0.59}))
}
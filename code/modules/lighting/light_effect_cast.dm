#define BASE_PIXEL_OFFSET 224
#define BASE_TURF_OFFSET 2
#define WIDE_SHADOW_THRESHOLD 80
#define OFFSET_MULTIPLIER_SIZE 32
#define CORNER_OFFSET_MULTIPLIER_SIZE 16

var/light_power_multiplier = 5

// We actually see these "pseudo-light atoms" in order to ensure that wall shadows are only seen by people who can see the light.
// Yes, this is stupid, but it's one of the limitations of TILE_BOUND, which cannot be chosen on an overlay-per-overlay basis.
// So the "next best thing" is to divide the light atoms in two parts, one exclusively for wall shadows and one for general purpose.

// cast_light() is "master procs", shared by the two kinds.

/atom/movable/light/proc/cast_light()
	cast_light_init()
	cast_main_light()
	update_light_dir()
	cast_shadows()
	overlays = temp_appearance
	temp_appearance = null

/atom/movable/light/proc/CastShadow(var/turf/target_turf)
	//get the x and y offsets for how far the target turf is from the light
	var/x_offset = target_turf.x - x
	var/y_offset = target_turf.y - y
	cast_main_shadow(target_turf, x_offset, y_offset)

	if (is_valid_turf(target_turf))
		cast_turf_shadow(target_turf, x_offset, y_offset)

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
// -- The shared procs between lights and pesudo-lights.

// Initialisation of the cast_light proc.
/atom/movable/light/proc/cast_light_init()
	light_color = null

	temp_appearance = list()

	//cap light range to 5
	light_range = min(5, light_range)

	alpha = min(255,max(0,round(light_power*light_power_multiplier*25)))

	if(light_type == LIGHT_SOFT_FLICKER)
		alpha = initial(alpha)
		animate(src, alpha = initial(alpha) - rand(30, 60), time = 2, loop = -1, easing = SINE_EASING)

	for(var/turf/T in range(light_range, src))
		affecting_turfs |= T

	if(!isturf(loc))
		for(var/turf/T in affecting_turfs)
			T.lumcount = -1
			T.affecting_lights -= src
		affecting_turfs.Cut()
		return

	for(var/turf/T in affecting_turfs)
		T.affecting_lights |= src

// On how many turfs do we cast a shadow ?
/atom/movable/light/proc/cast_shadows()
	//no shadows
	if(light_range < 2 || light_type == LIGHT_DIRECTIONAL)
		return

	var/list/visible_turfs = list()

	for(var/turf/T in view(light_range, src))
		visible_turfs += T

	for(var/turf/T in visible_turfs)
		if(CheckOcclusion(T))
			CastShadow(T)

/atom/movable/light/proc/update_light_dir()
	if(light_type == LIGHT_DIRECTIONAL)
		follow_holder_dir()

/atom/movable/light/proc/CheckOcclusion(var/turf/T)
	if(!istype(T))
		return 0

	if(T.opacity)
		return 1

	for(var/obj/machinery/door/D in T)
		if(D.opacity)
			return 1

	return 0

// ----------------------------------------------------------------------------------------------------------------------------------------------------------------
// -- The procs related to the sources of lights

/atom/movable/light/proc/cast_main_light()
	if(light_type == LIGHT_DIRECTIONAL)
		icon = 'icons/lighting/directional_overlays.dmi'
		light_range = 2.5
	else
		pixel_x = pixel_y = -(world.icon_size * light_range)
		var/icon_path = "icons/lighting/light_range_[light_range].dmi"
		if (!isfile(file(icon_path)))
			CRASH("The light file does not exist. Path: [icon_path]")
		icon = file(icon_path)

	icon_state = "white"

	var/image/I = image(icon)
	I.layer = HIGHEST_LIGHTING_LAYER
	I.icon_state = "overlay"
	if(light_type == LIGHT_DIRECTIONAL)
		var/turf/next_turf = get_step(src, dir)
		for(var/i = 1 to 3)
			if(CheckOcclusion(next_turf))
				I.icon_state = "[I.icon_state]_[i]"
				break
			next_turf = get_step(next_turf, dir)

	temp_appearance += I

/atom/movable/light/proc/cast_main_shadow(var/turf/target_turf, var/x_offset, var/y_offset)
	var/num = 1
	if((abs(x_offset) > 0 && !y_offset) || (abs(y_offset) > 0 && !x_offset))
		num = 2

	//due to only having one set of shadow templates, we need to rotate and flip them for up to 8 different directions
	//first check is to see if we will need to "rotate" the shadow template
	var/xy_swap = 0
	if(abs(x_offset) > abs(y_offset))
		xy_swap = 1

	var/shadowoffset = WORLD_ICON_SIZE/2 + (WORLD_ICON_SIZE*light_range)

	//due to the way the offsets are named, we can just swap the x and y offsets to "rotate" the icon state
	var/shadowicon = "icons/lighting/light_range_[light_range]_shadows[num].dmi"
	if (!isfile(file(shadowicon)))
		CRASH("The shadow file does not exist. Path: [shadowicon]")
	var/image/I = image(file(shadowicon))

	if(xy_swap)
		I.icon_state = "[abs(y_offset)]_[abs(x_offset)]"
	else
		I.icon_state = "[abs(x_offset)]_[abs(y_offset)]"

	var/matrix/M = matrix()

	//TODO: rewrite this comment:
	//using scale to flip the shadow template if needed
	//horizontal (x) flip is easy, we just check if the offset is negative
	//vertical (y) flip is a little harder, if the shadow will be rotated we need to flip if the offset is positive,
	// but if it wont be rotated then we just check if its negative to flip (like the x flip)
	var/x_flip
	var/y_flip
	if(xy_swap)
		x_flip = y_offset > 0 ? -1 : 1
		y_flip = x_offset < 0 ? -1 : 1
	else
		x_flip = x_offset < 0 ? -1 : 1
		y_flip = y_offset < 0 ? -1 : 1

	M.Scale(x_flip, y_flip)

	//here we do the actual rotate if needed
	if(xy_swap)
		M.Turn(90)

	//warning: you are approaching shitcode (this is where we move the shadow to the correct quadrant based on its rotation and flipping)
	//shadows are only as big as a quarter or half of the light for optimization

	//please for the love of god change this if there's a better way

	if(num == 1)
		if((x_flip == 1 && y_flip == 1 && xy_swap == 0) || (x_flip == -1 && y_flip == 1 && xy_swap == 1))
			M.Translate(shadowoffset, shadowoffset)
		else if((x_flip == 1 && y_flip == -1 && xy_swap == 0) || (x_flip == 1 && y_flip == 1 && xy_swap == 1))
			M.Translate(shadowoffset, 0)
		else if((xy_swap == 0 && x_flip == -y_flip) || (xy_swap == 1 && x_flip == -1 && y_flip == -1))
			M.Translate(0, shadowoffset)
	else
		if(x_flip == 1 && y_flip == 1 && xy_swap == 0)
			M.Translate(0, shadowoffset)
		else if(x_flip == 1 && y_flip == 1 && xy_swap == 1)
			M.Translate(shadowoffset / 2, shadowoffset / 2)
		else if(x_flip == 1 && y_flip == -1 && xy_swap == 1)
			M.Translate(-shadowoffset / 2, shadowoffset / 2)

	//apply the transform matrix
	I.transform = M
	I.layer = LIGHTING_LAYER
	//and add it to the lights overlays
	temp_appearance += I

/atom/movable/light/proc/is_valid_turf(var/turf/target_turf)
	return !(iswallturf(target_turf) || CheckOcclusion(target_turf))

/atom/movable/light/shadow/is_valid_turf(var/turf/target_turf)
	return TRUE

/atom/movable/light/proc/cast_turf_shadow(var/turf/target_turf, var/x_offset, var/y_offset)
	var/targ_dir = get_dir(target_turf, src)
	// CHECK: may not actually smoothout that well.
	var/blocking_dirs = 0
	for(var/d in cardinal)
		var/turf/T = get_step(target_turf, d)
		if(CheckOcclusion(T))
			blocking_dirs |= d

	// The "edge" of the light, with images consisting of directional sprites from wall_lighting.dmi "pushed" in the correct direction.
	var/image/I = image('icons/lighting/wall_lighting.dmi', loc = get_turf(src))
	I.icon_state = "[blocking_dirs]-[targ_dir]"
	I.pixel_x = (world.icon_size * light_range) + (x_offset * world.icon_size)
	I.pixel_y = (world.icon_size * light_range) + (y_offset * world.icon_size)
	I.layer = ABOVE_LIGHTING_LAYER
	temp_appearance += I

#undef BASE_PIXEL_OFFSET
#undef BASE_TURF_OFFSET
#undef WIDE_SHADOW_THRESHOLD
#undef OFFSET_MULTIPLIER_SIZE
#undef CORNER_OFFSET_MULTIPLIER_SIZE

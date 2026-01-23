var/datum/subsystem/daynightcycle/SSDayNight

var/list/daynight_turfs = list()
var/list/daynight_z_lvls = list()

/*
 * Smooth Day/Night Cycle System
 *
 * Instead of stepping through discrete states, this system smoothly interpolates
 * between color stops along a continuous cycle. Each tick advances the cycle
 * position and calculates an interpolated color.
 *
 * Full cycle duration: ~74 minutes (configurable via cycle_duration)
 * Colors transition smoothly using linear interpolation in RGB space.
 * Sounds are triggered when crossing specific threshold positions.
 */

// Color definitions for time-of-day phases (used for threshold detection and reference)
#define TOD_MORNING 	"#4d6f86"
#define TOD_SUNRISE 	"#fdc5a0"
#define TOD_DAYTIME 	"#FFFFFF"
#define TOD_AFTERNOON 	"#ffeedf"
#define TOD_SUNSET 		"#75497e"
#define TOD_NIGHTTIME 	"#000b11"

// Cycle position thresholds (0.0 to 1.0) - these define when each phase STARTS
#define CYCLE_POS_MORNING    0.00  // 0%   - cycle begins at morning
#define CYCLE_POS_SUNRISE    0.07  // 7%   - ~5 min into cycle
#define CYCLE_POS_DAYTIME    0.11  // 11%  - ~8 min
#define CYCLE_POS_AFTERNOON  0.30  // 30%  - ~22 min
#define CYCLE_POS_SUNSET     0.50  // 50%  - ~37 min
#define CYCLE_POS_NIGHTTIME  0.54  // 54%  - ~40 min
// Nighttime runs from 54% to 100% (~34 min), then wraps to morning

/datum/subsystem/daynightcycle
	name          = "Day Night Cycle"
	init_order    = SS_INIT_DAYNIGHT
	display_order = SS_DISPLAY_DAYNIGHT
	priority      = SS_PRIORITY_DAYNIGHT
	wait          = 2 SECONDS
/*
On the map dm file, redefine the following:
	- 'daynight_z_lvls' to change the zLevels that the day/night cycle applies to. Do not redefine if you want this subsystem disabled.
	  The global cycle applies to all z-levels in this list EXCEPT map.zProcGen (planets have individual cycles).
	- 'advance_time()' to change the lighting scheme - supports both global and per-planet cycles.
	- 'play_globalsound()' to change or disable the sound played at sunrise and sunset (only for global cycle).
*/
	flags = SS_FIRE_IN_LOBBY

	var/current_timeOfDay = TOD_DAYTIME // Current interpolated color
	var/current_phase = TOD_DAYTIME     // Current phase constant (for sound triggers and compatibility)
	var/next_light_power = 10
	var/next_light_range = 1
	var/list/currentrun

	// Smooth cycle variables
	var/cycle_position = 0.20     // Current position in the cycle (0.0 to 1.0), starts near daytime
	var/prev_cycle_position = 0.20 // Previous position, used to detect threshold crossings
	var/cycle_duration = 74 MINUTES // Total duration for one full day/night cycle
	var/last_fire_time = 0        // Track when we last fired for delta time calculation

	// Color stops for interpolation: list of lists containing (position, color, light_power)
	var/list/color_stops

	// Phase thresholds for determining current_phase (sorted by position)
	var/static/list/phase_thresholds

	// Debug mode for rapid cycle testing
	var/debug_rapid_cycle = FALSE
	var/debug_cycle_multiplier = 100  // How much faster the cycle runs in debug mode

	// Active planets with day/night cycles
	var/list/active_planets = list()

	var/overwrite_solars=FALSE //if true, the solars will run off of the day/night cycle to determine light power.
	var/nearest_star_angle=0.0 //the angle of the star that the solars will use.
	var/nearest_star_power=1.0 //how much power does the star give the solars? multiplier to base solar generation.
	var/solar_orbit_period=60 //less than 0 = CCW (east to west), CW (west to east) is more than one. in minutes. doesn't really matter that much, it's just for text mostly.

	var/weather_mod = 1 //weather light modifier

/datum/subsystem/daynightcycle/New()
	NEW_SS_GLOBAL(SSDayNight)

/datum/subsystem/daynightcycle/Initialize()
	daynight_z_lvls += map.zProcGen
	if(!daynight_z_lvls.len)
		flags = SS_NO_INIT | SS_NO_FIRE
	AMB_SQUARE.filters += filter(type="layer", render_source=AMBLIGHT_RENDER_TARGET)

	// Initialize color stops for smooth interpolation
	// Format: list(position, color, light_power)
	color_stops = list(
		list(CYCLE_POS_MORNING,   TOD_MORNING,   8),
		list(CYCLE_POS_SUNRISE,   TOD_SUNRISE,   9),
		list(CYCLE_POS_DAYTIME,   TOD_DAYTIME,   10),
		list(CYCLE_POS_AFTERNOON, TOD_AFTERNOON, 10),
		list(CYCLE_POS_SUNSET,    TOD_SUNSET,    6),
		list(CYCLE_POS_NIGHTTIME, TOD_NIGHTTIME, 3)
	)

	// Initialize phase thresholds for current_phase determination
	// Format: list(threshold_position, phase_constant)
	phase_thresholds = list(
		list(CYCLE_POS_MORNING,   TOD_MORNING),
		list(CYCLE_POS_SUNRISE,   TOD_SUNRISE),
		list(CYCLE_POS_DAYTIME,   TOD_DAYTIME),
		list(CYCLE_POS_AFTERNOON, TOD_AFTERNOON),
		list(CYCLE_POS_SUNSET,    TOD_SUNSET),
		list(CYCLE_POS_NIGHTTIME, TOD_NIGHTTIME)
	)

	// Set initial color and phase based on starting position
	current_timeOfDay = get_interpolated_color(cycle_position)
	current_phase = get_current_phase(cycle_position)
	next_light_power = get_interpolated_power(cycle_position)
	last_fire_time = world.time

	get_turflist()
	..()

/datum/subsystem/daynightcycle/fire(resumed = FALSE)
	// Calculate time delta and advance cycle position
	var/delta_time = world.time - last_fire_time
	last_fire_time = world.time

	// Apply debug multiplier if rapid cycle testing is enabled
	if(debug_rapid_cycle)
		delta_time *= debug_cycle_multiplier

	// Advance cycle position based on elapsed time
	prev_cycle_position = cycle_position
	cycle_position += delta_time / cycle_duration

	// Wrap around when we complete a full cycle
	if(cycle_position >= 1.0)
		cycle_position -= 1.0
		prev_cycle_position = 0  // Reset for proper threshold detection across the wrap

	// Calculate interpolated color and power
	advance_time()

	// Animate to the new color over the wait period for smooth transitions
	animate(AMB_SQUARE, color = current_timeOfDay, time = wait)

	// Process planet day/night cycles
	for(var/datum/planet_type/planet in active_planets)
		advance_planet_cycle(planet, delta_time)

/**
 * Builds the global daynight_turfs list
 *
 * Scans all z-levels in daynight_z_lvls EXCEPT for map.zProcGen (which has planets with individual cycles)
 * and identifies turfs that should receive the global day/night cycle lighting.
 */
/datum/subsystem/daynightcycle/proc/get_turflist()
	for(var/z in daynight_z_lvls)
		// Skip the procgen z-level - planets have their own independent cycles
		if(z == map.zProcGen)
			continue

		for(var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
			var/area/A = get_area(T)
			if(isopensurface(A)) //If we are outside.
				daynight_turfs += T
				new /atom/movable/amblight_overlay(T)

/datum/subsystem/daynightcycle/proc/play_globalsound() //override in map files
	return

/**
 * Toggles rapid cycle mode for debugging transitions
 *
 * When enabled, the cycle runs 100x faster (configurable via debug_cycle_multiplier).
 * A full 74-minute cycle completes in ~44 seconds at default multiplier.
 *
 * Arguments:
 * * multiplier - Optional: Set a custom speed multiplier (default 100)
 *
 * Returns: Current state of debug_rapid_cycle after toggling
 */
/datum/subsystem/daynightcycle/proc/debug_toggle_rapid(multiplier = null)
	debug_rapid_cycle = !debug_rapid_cycle

	if(multiplier)
		debug_cycle_multiplier = multiplier

	var/cycle_time_seconds = (cycle_duration / 10) / debug_cycle_multiplier  // Convert to seconds
	message_admins("Day/Night debug rapid cycle: [debug_rapid_cycle ? "ENABLED (full cycle in ~[cycle_time_seconds]s at [debug_cycle_multiplier]x speed)" : "DISABLED"]")
	message_admins("Current position: [round(cycle_position * 100, 0.1)]% | Phase: [current_phase]")

	return debug_rapid_cycle

/**
 * Debug proc to jump to a specific cycle position
 *
 * Arguments:
 * * position - Cycle position to jump to (0.0 to 1.0)
 */
/datum/subsystem/daynightcycle/proc/debug_set_position(position)
	position = clamp(position, 0, 0.999)
	prev_cycle_position = cycle_position
	cycle_position = position
	advance_time()
	animate(AMB_SQUARE, color = current_timeOfDay, time = 5)  // Quick transition
	message_admins("Day/Night jumped to position [round(position * 100, 0.1)]% | Phase: [current_phase] | Color: [current_timeOfDay]")

/**
 * Advances time of day using smooth interpolation
 *
 * Calculates the interpolated color and power based on the current cycle position.
 * Detects threshold crossings to trigger sounds at sunrise and nighttime.
 * For planet-specific cycles, use advance_planet_time() instead.
 *
 * This function can be overridden in map.dm files for custom lighting schemes (like junglestation).
 */
/datum/subsystem/daynightcycle/proc/advance_time()
	// Calculate interpolated color and power based on cycle position
	current_timeOfDay = get_interpolated_color(cycle_position)
	next_light_power = get_interpolated_power(cycle_position)

	// Update the current discrete phase (for compatibility with sound triggers, grue spawning, etc.)
	var/old_phase = current_phase
	current_phase = get_current_phase(cycle_position)

	// Check for phase transitions to play sounds
	// Only play sound when we actually transition into sunrise or nighttime
	if(current_phase != old_phase)
		if(current_phase == TOD_SUNRISE || current_phase == TOD_NIGHTTIME)
			play_globalsound()

/**
 * Gets the current discrete phase based on cycle position
 *
 * Returns the TOD_* constant for the current phase based on which
 * threshold range the position falls within.
 *
 * Arguments:
 * * position - The cycle position (0.0 to 1.0)
 */
/datum/subsystem/daynightcycle/proc/get_current_phase(position)
	if(!phase_thresholds || !phase_thresholds.len)
		return TOD_DAYTIME

	var/result_phase = TOD_NIGHTTIME  // Default to last phase (nighttime wraps to morning)

	// Find which phase we're in by checking thresholds in order
	for(var/i = phase_thresholds.len to 1 step -1)
		var/list/threshold = phase_thresholds[i]
		if(position >= threshold[1])
			result_phase = threshold[2]
			break

	return result_phase

/**
 * Gets the time remaining until the next phase transition
 *
 * Useful for spawn timing logic (e.g., grue spawning in snaxi.dm).
 *
 * Returns: Time in deciseconds until the current phase ends
 */
/datum/subsystem/daynightcycle/proc/get_time_until_phase_change()
	if(!phase_thresholds || !phase_thresholds.len)
		return 0

	// Find the next threshold after current position
	var/next_threshold_pos = 1.0  // Default: wrap to start of cycle

	for(var/i = 1 to phase_thresholds.len)
		var/list/threshold = phase_thresholds[i]
		if(threshold[1] > cycle_position)
			next_threshold_pos = threshold[1]
			break

	// Calculate time until we reach that threshold
	var/position_remaining = next_threshold_pos - cycle_position
	if(position_remaining < 0)
		position_remaining += 1.0  // Handle wrap-around

	return position_remaining * cycle_duration

/**
 * Gets the time elapsed since the current phase started
 *
 * Useful for spawn timing logic.
 *
 * Returns: Time in deciseconds since the current phase began
 */
/datum/subsystem/daynightcycle/proc/get_time_since_phase_start()
	if(!phase_thresholds || !phase_thresholds.len)
		return 0

	// Find the threshold for current phase
	var/current_threshold_pos = 0

	for(var/i = phase_thresholds.len to 1 step -1)
		var/list/threshold = phase_thresholds[i]
		if(cycle_position >= threshold[1])
			current_threshold_pos = threshold[1]
			break

	// Calculate time since we crossed that threshold
	var/position_elapsed = cycle_position - current_threshold_pos
	if(position_elapsed < 0)
		position_elapsed += 1.0  // Handle wrap-around

	return position_elapsed * cycle_duration

/**
 * Gets the interpolated color for a given cycle position
 *
 * Finds the two color stops surrounding the position and linearly interpolates between them.
 *
 * Arguments:
 * * position - The cycle position (0.0 to 1.0)
 */
/datum/subsystem/daynightcycle/proc/get_interpolated_color(position)
	if(!color_stops || !color_stops.len)
		return TOD_DAYTIME

	// Find the two stops we're between
	var/list/prev_stop = color_stops[color_stops.len]  // Default to last (for wrap-around)
	var/list/next_stop = color_stops[1]  // Default to first

	for(var/i = 1 to color_stops.len)
		var/list/stop = color_stops[i]
		if(stop[1] > position)
			next_stop = stop
			prev_stop = (i > 1) ? color_stops[i - 1] : color_stops[color_stops.len]
			break
		if(i == color_stops.len)
			// Position is past all stops, interpolate between last and first (wrapped)
			prev_stop = stop
			next_stop = color_stops[1]

	// Calculate interpolation factor
	var/prev_pos = prev_stop[1]
	var/next_pos = next_stop[1]

	// Handle wrap-around case
	if(next_pos <= prev_pos)
		next_pos += 1.0
	if(position < prev_pos)
		position += 1.0

	var/range = next_pos - prev_pos
	var/factor = (range > 0) ? ((position - prev_pos) / range) : 0

	// Clamp factor
	factor = max(0, min(1, factor))

	// Interpolate between colors
	return lerp_color(prev_stop[2], next_stop[2], factor)

/**
 * Gets the interpolated light power for a given cycle position
 *
 * Arguments:
 * * position - The cycle position (0.0 to 1.0)
 */
/datum/subsystem/daynightcycle/proc/get_interpolated_power(position)
	if(!color_stops || !color_stops.len)
		return 10

	// Find the two stops we're between
	var/list/prev_stop = color_stops[color_stops.len]
	var/list/next_stop = color_stops[1]

	for(var/i = 1 to color_stops.len)
		var/list/stop = color_stops[i]
		if(stop[1] > position)
			next_stop = stop
			prev_stop = (i > 1) ? color_stops[i - 1] : color_stops[color_stops.len]
			break
		if(i == color_stops.len)
			prev_stop = stop
			next_stop = color_stops[1]

	// Calculate interpolation factor
	var/prev_pos = prev_stop[1]
	var/next_pos = next_stop[1]

	if(next_pos <= prev_pos)
		next_pos += 1.0
	if(position < prev_pos)
		position += 1.0

	var/range = next_pos - prev_pos
	var/factor = (range > 0) ? ((position - prev_pos) / range) : 0
	factor = max(0, min(1, factor))

	// Linear interpolation for power
	return prev_stop[3] + (next_stop[3] - prev_stop[3]) * factor

/**
 * Linearly interpolates between two hex colors
 *
 * Arguments:
 * * color1 - Starting color (hex string like "#RRGGBB")
 * * color2 - Ending color (hex string like "#RRGGBB")
 * * factor - Interpolation factor (0.0 = color1, 1.0 = color2)
 */
/datum/subsystem/daynightcycle/proc/lerp_color(color1, color2, factor)
	// Parse color1
	var/r1 = hex2num(copytext(color1, 2, 4))
	var/g1 = hex2num(copytext(color1, 4, 6))
	var/b1 = hex2num(copytext(color1, 6, 8))

	// Parse color2
	var/r2 = hex2num(copytext(color2, 2, 4))
	var/g2 = hex2num(copytext(color2, 4, 6))
	var/b2 = hex2num(copytext(color2, 6, 8))

	// Interpolate
	var/r = round(r1 + (r2 - r1) * factor)
	var/g = round(g1 + (g2 - g1) * factor)
	var/b = round(b1 + (b2 - b1) * factor)

	// Clamp values
	r = max(0, min(255, r))
	g = max(0, min(255, g))
	b = max(0, min(255, b))

	return rgb(r, g, b)

/**
 * Initializes a planet's day/night cycle
 *
 * Creates the planet's ambient light square and ambient overlays on turfs.
 * Uses the same animation system as the global cycle for smooth transitions.
 * Call this after setting the planet's cycle_position.
 *
 * Arguments:
 * * planet - The planet to initialize
 */
/datum/subsystem/daynightcycle/proc/initialize_planet_cycle(var/datum/planet_type/planet)
	if(!planet)
		return

	// Calculate initial color and phase
	planet.current_timeOfDay = get_interpolated_color(planet.cycle_position)
	planet.current_phase = get_current_phase(planet.cycle_position)
	planet.last_fire_time = world.time

	// Create planet-specific ambient light square (same as global AMB_SQUARE)
	planet.planet_amb_square = new /atom/movable/amblight_square()
	planet.planet_amb_square.color = planet.current_timeOfDay
	// Add the same filter as global AMB_SQUARE for ambient light rendering
	planet.planet_amb_square.filters += filter(type="layer", render_source=AMBLIGHT_RENDER_TARGET)

	// Create ambient overlays on planet turfs for smooth lighting
	for(var/turf/T in planet.daynight_turfs)
		if(!T.amblight_overlay)
			new /atom/movable/amblight_overlay(T)

	// Add to active planets list for processing
	active_planets |= planet

/**
 * Advances a planet's day/night cycle using smooth interpolation
 *
 * Called each fire() tick for all active planets. Animates the planet's
 * ambient square for smooth color transitions, identical to the global cycle.
 *
 * Arguments:
 * * planet - The planet to advance
 * * delta_time - Time elapsed since last tick (already includes debug multiplier)
 */
/datum/subsystem/daynightcycle/proc/advance_planet_cycle(var/datum/planet_type/planet, delta_time)
	if(!planet)
		return

	// Advance planet's cycle position
	planet.prev_cycle_position = planet.cycle_position
	planet.cycle_position += delta_time / planet.cycle_duration

	// Wrap around
	if(planet.cycle_position >= 1.0)
		planet.cycle_position -= 1.0
		planet.prev_cycle_position = 0

	// Calculate interpolated color and phase
	planet.current_timeOfDay = get_interpolated_color(planet.cycle_position)
	planet.current_phase = get_current_phase(planet.cycle_position)

	// Animate the planet's ambient square for smooth transitions (same as global)
	if(planet.planet_amb_square)
		animate(planet.planet_amb_square, color = planet.current_timeOfDay, time = wait)

/**
 * Removes a planet from the day/night cycle system
 *
 * Call this when a planet is destroyed. Cleans up the ambient square
 * and removes from processing.
 *
 * Arguments:
 * * planet - The planet to remove
 */
/datum/subsystem/daynightcycle/proc/remove_planet_cycle(var/datum/planet_type/planet)
	if(!planet)
		return

	active_planets -= planet

	// Clean up ambient square
	if(planet.planet_amb_square)
		qdel(planet.planet_amb_square)
		planet.planet_amb_square = null

/**
 * Sets which ambient light square a player sees
 *
 * Swaps the ambient square in the player's lighting plane master.
 * When on a planet, they see the planet's ambient square.
 * When not on a planet (or leaving), they see the global AMB_SQUARE.
 *
 * Arguments:
 * * player - The mob to update
 * * planet - The planet they're entering, or null to use global
 */
/datum/subsystem/daynightcycle/proc/set_player_ambient_square(var/mob/player, var/datum/planet_type/planet)
	if(!player?.lighting_planemaster)
		return

	var/obj/abstract/screen/plane/master/pm = player.lighting_planemaster

	// Remove any existing ambient squares from vis_contents
	if(AMB_SQUARE in pm.vis_contents)
		pm.vis_contents -= AMB_SQUARE

	// Remove any planet ambient squares
	for(var/datum/planet_type/P in active_planets)
		if(P.planet_amb_square && (P.planet_amb_square in pm.vis_contents))
			pm.vis_contents -= P.planet_amb_square

	// Add the appropriate ambient square
	if(planet?.planet_amb_square)
		pm.vis_contents += planet.planet_amb_square
	else
		pm.vis_contents += AMB_SQUARE

/**
 * Updates lighting for all turfs in the global cycle
 *
 * Applies the current global time of day to all turfs in daynight_turfs
 * (all z-levels except zProcGen, which has planets with individual cycles).
 */
/datum/subsystem/daynightcycle/proc/update_global_lighting()
	if(!daynight_turfs || !daynight_turfs.len)
		return

	var/lowpriority = TRUE // Use low priority for regular cycle updates
	for(var/turf/T in daynight_turfs)
		if(!T || T.gcDestroyed)
			continue
		var/power = next_light_power * weather_mod
		T.set_light(next_light_range, power, current_timeOfDay, lowpriority)

/**
 * Forces an immediate lighting update for a specific planet
 *
 * Arguments:
 * * planet - The planet to update lighting for
 * * immediate - If TRUE, applies lighting immediately instead of queueing (default TRUE for instant updates)
 */
/datum/subsystem/daynightcycle/proc/update_planet_lighting(var/datum/planet_type/planet, var/immediate = TRUE)
	if(!planet || !planet.daynight_turfs)
		return

	// Use interpolated light power based on planet's cycle position
	var/light_power = get_interpolated_power(planet.cycle_position)
	light_power *= planet.weather_mod // Apply planet-specific weather modifier
	var/lowpriority = !immediate

	for(var/turf/T in planet.daynight_turfs)
		if(!T || T.gcDestroyed)
			continue
		T.set_light(next_light_range, light_power, planet.current_timeOfDay, lowpriority)

// Force lighting change on a list of turfs (used mainly for when shuttles leave)
/datum/subsystem/daynightcycle/proc/update_turf_lighting(var/list/turf/turfs, var/datum/planet_type/planet = null)
	if(!turfs.len)
		return

	var/timeOfDay
	var/light_power

	if(planet)
		timeOfDay = planet.current_timeOfDay
		light_power = get_interpolated_power(planet.cycle_position)
		light_power *= planet.weather_mod
	else
		timeOfDay = current_timeOfDay
		light_power = next_light_power * weather_mod

	for(var/turf/T in turfs)
		T.set_light(next_light_range, light_power, timeOfDay, lowpriority = FALSE)

var/atom/movable/amblight_square/AMB_SQUARE = new()
/atom/movable/amblight_square
	icon = null
	color = "#FFFFFF"
	appearance_flags = RESET_COLOR|RESET_ALPHA|RESET_TRANSFORM
	vis_flags = VIS_INHERIT_PLANE|VIS_INHERIT_LAYER|VIS_UNDERLAY
	blend_mode = BLEND_ADD
	mouse_opacity = 0
	screen_loc = "1,1"

/atom/movable/amblight_overlay
	name = "white square of ambiance"
	icon = 'icons/effects/32x32.dmi'
	icon_state = "white"
	plane = MAP_EFX_PLANE
	appearance_flags = PIXEL_SCALE | TILE_BOUND | RESET_ALPHA | RESET_COLOR
	mouse_opacity = 0
	anchored = TRUE
	ignoreinvert = TRUE
	luminosity = 1

/atom/movable/amblight_overlay/New()
	. = ..()
	var/turf/T = loc
	T.amblight_overlay = src

/atom/movable/amblight_overlay/Destroy()
	var/turf/T = loc
	if(istype(T))
		T.amblight_overlay = null

	. = ..()

/atom/movable/amblight_overlay/ex_act(severity)
	return 0

/atom/movable/amblight_overlay/shuttle_act()
	return 0

/atom/movable/amblight_overlay/can_shuttle_move()
	return 0

/atom/movable/amblight_overlay/singularity_act()
	return

/atom/movable/amblight_overlay/singularity_pull()
	return

/atom/movable/amblight_overlay/blob_act()
	return

// Override here to prevent things accidentally moving around overlays.
/atom/movable/amblight_overlay/forceMove(atom/destination, step_x = 0, step_y = 0, no_tp = FALSE, harderforce = FALSE, glide_size_override = 0)
	if(harderforce)
		. = ..()

/atom/movable/amblight_overlay/send_to_future(var/duration)
	return

/atom/movable/amblight_overlay/send_to_past(var/duration)
	return

/atom/movable/amblight_overlay/clean_act(var/cleanliness)
	return


/turf
	var/atom/movable/amblight_overlay/amblight_overlay

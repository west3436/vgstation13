#define ZLEVEL_BASE_CHANCE			10  //Not a strict chance, but a relative one
#define ZLEVEL_STATION_MODIFIER		0.5 //multiplier on the chance
#define ZLEVEL_SPACE_MODIFIER		1.5

//**************************************************************
//
// Map Datums
// --------------
// Each map can have its own datum now. This means no more
// hardcoded bullshit. Same for each Z-level.
//
// Should be mostly self-explanatory. Define /datum/map/active
// in your map file. See current maps for examples.
//
// Base Turf
// --------------
// Because the times are changing, even space being space
// is now considered hardcoding. So now you can have
// grass or asteroid under the station
//
//**************************************************************

/datum/map

	var/nameShort = ""
	var/nameLong = ""
	var/list/datum/zLevel/zLevels = list()
	var/list/datum/virtual_z/vLevels = list()
	var/list/datum/virtual_z/systemVLevels = list() // System vLevels (holodeck, transit levels, dungeons, etc) - numbered 101+
	var/zMainStation = 1
	var/zCentcomm = 2
	var/zTCommSat = 3
	var/zDerelict = 4
	var/zAsteroid = 5
	var/zDeepSpace = 6

	var/zAdditionalStationZlevel = 0 // 0 because surely nothing will ever go to Z 0, right? why not null? because nullspace

	var/skip_hobo_shack = FALSE // if true, skips hobo shack generation. set to TRUE if you want to map your own custom one for the map.

	//Holomap offsets
	var/list/holomap_offset_x = list()
	var/list/holomap_offset_y = list()

	//List for traitor items which are not in the map
	var/list/unavailable_items

	//nanoui stuff
	var/map_dir = ""
	//buildmode reset
	var/file_dir = ""

	//Fuck the preprocessor
	var/dorf = 0
	var/linked_to_centcomm = 1
	var/shuttle_call_label = "Call Shuttle"
	var/shuttle_cancel_label = "Cancel Shuttle"

	//Disable holominimaps on generation, map-wide. If you're just testing things out, change config.txt instead.
	var/disable_holominimap_generation = 0

	//If 1, only spawn vaults that are exclusive to this map (other vaults aren't spawned). For more info, see code/modules/randomMaps/vault_definitions.dm
	var/only_spawn_map_exclusive_vaults = 0

	var/list/enabled_jobs = list() //Jobs that require enabling that are enabled on this map
	var/list/disabled_jobs = list() //Jobs that are disabled on this map

	var/list/event_blacklist = list(/datum/event/blizzard, /datum/event/omega_blizzard)
	var/list/event_whitelist = list()

	var/datum/shuttle/ship_shuttle = null //Reference to "the ship" for map-specific features (events, etc). Set by map-specific init code.

	//Map elements that should be loaded together with this map. Stuff like the holodeck areas, etc.
	var/list/load_map_elements = list()
	var/list/load_custom_fixedvaults = list() //don't use this
	var/center_x = 226
	var/center_y = 254

	var/snow_theme = FALSE
	var/can_enlarge = TRUE //can map elements expand this map? turn off for surface maps
	var/has_engines = FALSE // Is the map a space ship with big engines?
	var/broken_lights = TRUE //broken lights roundstart
	var/can_have_robots = TRUE
	var/planet_size = 0 // If set, overrides planet allocation size for this map

	var/list/daynight_z_lvls = list() //Z-levels that participate in the day/night cycle

//Used for events; override as-needed.
/datum/map/proc/map_specific_event_checks(var/datum/event/E)
	return 1

/datum/map/New()
	. = ..()
	src.loadZLevels(src.zLevels)

/datum/map/proc/map_ruleset(var/datum/dynamic_ruleset/DR)
	return TRUE //If false, fails Ready()

/datum/map/proc/ruleset_multiplier(var/datum/dynamic_ruleset/DR)
	return 1

/datum/map/proc/ignore_enemy_requirement(var/datum/dynamic_ruleset/DR)
	return 0

/datum/map/proc/loadZLevels(list/levelPaths)
	for(var/i = 1 to levelPaths.len)
		var/path = levelPaths[i]
		addZLevel(new path, i)

/datum/map/proc/addZLevel(datum/zLevel/level, z_to_use = 0, make_base_turf = FALSE, fast_base_turf = FALSE)
	if(!istype(level))
		warning("ERROR: addZLevel received [level ? "a bad level of type [ispath(level) ? "[level]" : "[level.type]" ]" : "no level at all!"]")
		return
	if(!level.base_turf)
		level.base_turf = /turf/space
	if(z_to_use > zLevels.len)
		zLevels.len = z_to_use
	zLevels[z_to_use] = level
	level.z = z_to_use
	if(!istype(level.base_turf,/turf/space) && make_base_turf)
		level.reset_base_turf(/turf/space,fast_base_turf)

/datum/map/proc/linkVLevel(datum/zLevel/level)
	var/datum/virtual_z/new_vz = new(level, world.maxx, world.maxy, 1, 1, skip_turf_setup = FALSE)
	new_vz.id = level.z
	new_vz.name = level.name
	if(level.z == zCentcomm)
		new_vz.level_type = VZ_PROTECTED
	else if(level.planetside)
		new_vz.level_type = VZ_PLANET
	if(level.z in daynight_z_lvls)
		daynight_v_lvls += new_vz
	new_vz.gps_allowed = level.z != zCentcomm
	new_vz.teleJammed = level.teleJammed ? VZ_TELEPORTATION_FORBIDDEN : VZ_TELEPORTATION_ALLOWED
	new_vz.bluespace_jammed = level.bluespace_jammed
	new_vz.movementJammed = level.movementJammed
	new_vz.movementChance = level.movementChance
	new_vz.transitionLoops = level.transitionLoops
	if(level.transition_crosswrap_z && level.transition_crosswrap_z.len == 4)
		new_vz.transition_crosswrap_v = level.transition_crosswrap_z.Copy()
	new_vz.update_settings()
	vLevels |= new_vz
	return new_vz

/datum/map/proc/addVLevel(var/size_x = ALLOCATION_SMALL, var/size_y = null, var/skip_turf_setup = FALSE, var/fill_turf_type = null, var/system = FALSE)
	if(!size_y)
		size_y = size_x
	var/found_x = 0
	var/found_y = 0

	var/spacing = VIRTUAL_Z_SPACING

	// Check existing dynamic zLevels for available space using 2D bin packing
	var/datum/zLevel/z_to_use = null
	for(var/datum/zLevel/check_z in zLevels)
		if(istype(check_z, /datum/zLevel/dynamic))
			var/list/placement = SSmapping.try_place_vz(check_z, size_x, size_y, spacing)
			if(placement)
				z_to_use = check_z
				found_x = placement["x"]
				found_y = placement["y"]
				break

	// Create a new dynamic zLevel if no suitable one was found
	if(!z_to_use)
		z_to_use = new /datum/zLevel/dynamic()
		// Skip turf initialization during z-level creation to avoid lag
		skip_turf_init = TRUE
		world.maxz++
		skip_turf_init = FALSE
		z_to_use.z = world.maxz
		map.zLevels += z_to_use
		found_x = 1
		found_y = 1

	if(fill_turf_type)
		skip_turf_setup = FALSE

	// Create the new virtual_z
	var/datum/virtual_z/new_vz = new(z_to_use, size_x, size_y, found_x, found_y, skip_turf_setup, system)

	if(fill_turf_type)
		for(var/turf/T in new_vz.get_turfs())
			T.ChangeTurf(fill_turf_type)

	return new_vz

/datum/map/proc/addTransitVLevel(datum/shuttle/shuttle, var/system = FALSE)
	var/buffer = world.view
	var/list/dims = shuttle.get_size()
	var/shuttle_width = dims[1]
	var/shuttle_height = dims[2]
	var/datum/virtual_z/new_vz = addVLevel(shuttle_width + 2*buffer, shuttle_height + 2*buffer, system = system)
	new_vz.name = "[shuttle.name] - transit area"
	new_vz.level_type = VZ_TRANSIT
	new_vz.linked_shuttle = shuttle
	for(var/turf/T in new_vz.get_turfs(FALSE))
		var/turf/space/transit/t_turf = T.ChangeTurf(/turf/space/transit,0,0,1,0)
		t_turf.v = new_vz
		t_turf.pushdirection = shuttle.dir
		t_turf.update_icon()
		CHECK_TICK
	return new_vz

/datum/map/proc/addMapElementVLevel(var/datum/map_element/ME, var/rotation = 0, var/fill_turf = null, var/buffer_size = 5, var/system = FALSE)
	var/ortho = rotation && !(rotation % 180) // Flip width and height if rotated 90 or 270 degrees
	var/w_to_use = ortho? ME.height : ME.width
	var/h_to_use = ortho? ME.width : ME.height
	var/datum/virtual_z/new_vz = src.addVLevel(w_to_use + buffer_size * 2, h_to_use + buffer_size * 2, fill_turf_type = fill_turf, system = system)
	var/prefix = "Map Element: "
	if(istype(ME, /datum/map_element/away_mission))
		prefix = "Away Mission: "
	new_vz.name = "[prefix][ME.name]"
	new_vz.level_type = VZ_PROTECTED
	new_vz.gps_allowed = FALSE
	new_vz.teleJammed = VZ_TELEPORTATION_FORBIDDEN
	new_vz.bluespace_jammed = TRUE
	new_vz.movementJammed = TRUE
	new_vz.set_status(FALSE)
	return new_vz

// Returns the vLevel with the given ID. When multiple vlevels share the same
// id (i.e. a multi-floor group), the anchor (floor == 1) is returned.
/datum/map/proc/getVLevel(var/vlevel_id)
	if(!vlevel_id)
		return null
	for(var/datum/virtual_z/V in vLevels)
		if(V.id == vlevel_id && V.floor == 1)
			return V
	for(var/datum/virtual_z/V in systemVLevels)
		if(V.id == vlevel_id && V.floor == 1)
			return V
	return null

// Returns the specific floor of a vlevel group. floor 1 = anchor.
/datum/map/proc/getVLevelFloor(var/vlevel_id, var/target_floor = 1)
	var/datum/virtual_z/anchor = getVLevel(vlevel_id)
	if(!anchor)
		return null
	if(target_floor == 1)
		return anchor
	var/datum/virtual_z/cur = anchor
	for(var/i in 2 to target_floor)
		cur = cur.vlevel_above
		if(!cur)
			return null
	return cur

// Allocates a new vlevel on top of the given group anchor and wires it into
// the chain. Returns the newly created floor, or null on failure.
/datum/map/proc/addFloorAbove(var/datum/virtual_z/group_anchor)
	if(!group_anchor || group_anchor.floor != 1)
		return null
	// Walk to current top floor.
	var/datum/virtual_z/top = group_anchor
	while(top.vlevel_above)
		top = top.vlevel_above
	// Allocate physical-z space sized to the anchor's full footprint.
	var/datum/virtual_z/new_floor = addVLevel(group_anchor.size_x, group_anchor.size_y)
	if(!new_floor)
		return null
	// Stamp group membership.
	new_floor.id = group_anchor.id
	new_floor.floor = top.floor + 1
	new_floor.group_anchor = group_anchor
	// Wire links.
	top.vlevel_above = new_floor
	new_floor.vlevel_below = top
	// First transition to multi-floor: clear group-level fields that are forbidden.
	if(top == group_anchor)
		var/old_channel = group_anchor.transition_channel
		if(old_channel && accessable_v_levels[old_channel])
			accessable_v_levels[old_channel] -= "[group_anchor.id]"
		group_anchor.transition_channel = null
		group_anchor.transition_crosswrap_v = list(null, null, null, null)
		log_admin("Multi-z: vlevel id=[group_anchor.id] became multi-floor; transition_channel and crosswrap cleared.")
	// Non-anchor floors must have group-level fields cleared to avoid stale-read confusion.
	new_floor.transition_channel = null
	new_floor.transition_crosswrap_v = list(null, null, null, null)
	new_floor.active = group_anchor.active
	new_floor.planet = null
	new_floor.linked_shuttle = null
	return new_floor

// Removes the top floor of a multi-floor group. Refuses if the top floor
// contains mobs or /obj/structure instances unless force = TRUE. Returns
// TRUE on success, FALSE on refusal or error.
/datum/map/proc/removeTopFloor(var/datum/virtual_z/group_anchor, var/force = FALSE)
	if(!group_anchor || group_anchor.floor != 1)
		return FALSE
	if(!group_anchor.vlevel_above)
		return FALSE  // Single-floor group; use vlevel-delete instead.
	// Walk to top floor.
	var/datum/virtual_z/top = group_anchor
	while(top.vlevel_above)
		top = top.vlevel_above
	if(!force)
		// Scan top's footprint for mobs and non-default structures.
		var/mob_count = 0
		var/structure_count = 0
		for(var/x in top.x_min to top.x_max)
			for(var/y in top.y_min to top.y_max)
				var/turf/T = locate(x, y, top.parent_z.z)
				if(!T) continue
				for(var/atom/movable/AM in T)
					if(ismob(AM))
						mob_count++
					else if(istype(AM, /obj/structure))
						structure_count++
		if(mob_count > 0 || structure_count > 0)
			log_admin("Multi-z: removeTopFloor refused on id=[group_anchor.id] floor=[top.floor]: [mob_count] mobs, [structure_count] structures.")
			return FALSE
	// Unlink.
	top.vlevel_below.vlevel_above = null
	// Unregister from global lists.
	vLevels -= top
	if(top.parent_z)
		top.parent_z.virtual_z_levels -= top
	qdel(top)
	return TRUE

// Multi-z aware map loader. Probes DMM dimensions, allocates an appropriately
// sized vlevel (or extends an existing group), then defers to the existing
// /dmm_suite/load_map placer. The lower-level load_map signature is NOT
// modified; multi-z aware loading is opt-in via this entry point.
//
//  multiz_group == null              -> single-floor load (default).
//  multiz_group == MULTIZ_NEW        -> allocate anchor (floor 1), return it.
//  multiz_group is a /datum/virtual_z anchor -> stack a new floor above it.
/datum/map/proc/load_map_into_vlevel(var/dmm_file, var/multiz_group = null)
	var/file = isfile(dmm_file) ? dmm_file : file(dmm_file)
	// get_map_dimensions returns list(width, height) as a positional list.
	var/list/dims = maploader.get_map_dimensions(file)
	if(!dims || dims.len < 2)
		CRASH("load_map_into_vlevel: could not probe DMM dimensions for [dmm_file].")
	var/dmm_size_x = dims[1]
	var/dmm_size_y = dims[2]

	if(multiz_group == MULTIZ_NEW)
		var/datum/virtual_z/anchor = addVLevel(dmm_size_x, dmm_size_y)
		if(!anchor)
			return null
		maploader.load_map(file, anchor.parent_z.z, anchor.x_min, anchor.y_min)
		return anchor

	if(istype(multiz_group, /datum/virtual_z))
		var/datum/virtual_z/existing_anchor = multiz_group
		if(existing_anchor.floor != 1)
			CRASH("multiz_group must be a group anchor (floor 1), got floor [existing_anchor.floor]")
		var/datum/virtual_z/new_floor = addFloorAbove(existing_anchor)
		if(!new_floor)
			return null
		maploader.load_map(file, new_floor.parent_z.z, new_floor.x_min, new_floor.y_min)
		new_floor.recompute_footprint()
		// Discard any channel/crosswrap that came in from the DMM metadata.
		if(new_floor.transition_channel != null \
			|| (new_floor.transition_crosswrap_v && (new_floor.transition_crosswrap_v[1] || new_floor.transition_crosswrap_v[2] || new_floor.transition_crosswrap_v[3] || new_floor.transition_crosswrap_v[4])))
			log_world("Multi-z: discarding channel/crosswrap from non-anchor DMM [dmm_file].")
			new_floor.transition_channel = null
			new_floor.transition_crosswrap_v = list(null, null, null, null)
		return new_floor

	// Default path: single-floor load.
	var/datum/virtual_z/single = addVLevel(dmm_size_x, dmm_size_y)
	if(!single)
		return null
	maploader.load_map(file, single.parent_z.z, single.x_min, single.y_min)
	return single

// Returns all vLevels (both system and regular) as a flat list
/datum/map/proc/getAllVLevels()
	return systemVLevels + vLevels

var/global/list/accessable_v_levels = list(
	"Default" = list()
)

/datum/map/proc/map_specific_init()

//For any map-specific UI, like AI jumps
/datum/map/proc/special_ui(var/obj/abstract/screen/S, mob/user)
	return FALSE

//This list contains the z-level numbers which can be accessed via space travel and the percentile chances to get there.
//Generated by the map datum on roundstart - and added to during the round
//This comment is a memorial to balance bickering from a long-gone TGstation - Errorage and Urist

/datum/map/proc/give_AI_jumps(var/list/L)
	var/obj/abstract/screen/using
	using = new /obj/abstract/screen
	using.name = "AI Core"
	using.icon = 'icons/mob/screen_ai.dmi'
	using.icon_state = "ai_core"
	using.screen_loc = ui_ai_core
	L += using
	return L

/datum/map/proc/generate_mapvaults()
	return FALSE

/datum/map/proc/map_equip(var/mob/living/carbon/human/H)
	return

////////////////////////////////////////////////////////////////

/datum/zLevel

	var/name = ""
	var/teleJammed = 0
	var/movementJammed = 0 //Prevents you from accessing the zlevel by drifting
	var/transitionLoops = FALSE //if true, transition sends you back to the same Z-level (see turfs/turf.dm)
	var/bluespace_jammed = 0
	var/movementChance = ZLEVEL_BASE_CHANCE
	var/base_turf //Our base turf, what shows under the station when destroyed. Defaults to space because it's fukken Space Station 13
	var/base_area = null //default base area type, what blueprints erase into; if null, space; be careful with parent areas because locate() could find a child!
	var/z //Number of the z-level (the z coordinate)
	var/list/transition_crosswrap_z=null // list(z_north,z_south,z_east,z_west). when you hit the edge, instead of drifting to a random zlevel or looping on the current one, teleports you to the corresponding edge on the z-level in the list.
	var/planetside=FALSE //if the z-level is supposed to represent being on a planet, surface or underground.

	var/list/virtual_z_levels = list() //list of virtual z-levels that use this z-level as their base

/datum/zLevel/proc/post_mapload()
	return

/datum/zLevel/proc/reset_base_turf(old_type, fast_base_turf = FALSE)
	for(var/turf/T in block(locate(1,1,z),locate(world.maxx,world.maxy,z)))
		if(istype(T,old_type))
			if(fast_base_turf)
				new base_turf(T)
			else
				T.set_area(base_area)
				T.ChangeTurf(base_turf)

/datum/zLevel/proc/blur_holomap(var/area/aera, var/turf/truf)
	return FALSE

/datum/zLevel/proc/is_box_free(low_x, low_y, high_x, high_y)
	for(var/datum/virtual_z/vlevel in virtual_z_levels)
		if(low_x <= vlevel.x_max && vlevel.x_min <= high_x && low_y <= vlevel.y_max && vlevel.y_min <= high_y)
			return FALSE
	return TRUE

// Returns the minimum Y position that would have at least 'spacing' turfs of separation from all existing vlevels
// Returns 0 if no adjustment needed
/datum/zLevel/proc/get_min_valid_y(low_x, high_x, low_y, spacing)
	var/min_y = 0
	for(var/datum/virtual_z/vlevel in virtual_z_levels)
		// Check if we overlap in X (meaning we need Y separation)
		if(low_x <= vlevel.x_max && vlevel.x_min <= high_x)
			// Calculate minimum Y to have 'spacing' turfs of gap from this vlevel
			var/required_y = vlevel.y_max + spacing + 1
			if(required_y > low_y && required_y > min_y)
				min_y = required_y
	return min_y

// Returns the minimum X position that would have at least 'spacing' turfs of separation from all existing vlevels
// Returns 0 if no adjustment needed
/datum/zLevel/proc/get_min_valid_x(low_y, high_y, low_x, spacing)
	var/min_x = 0
	for(var/datum/virtual_z/vlevel in virtual_z_levels)
		// Check if we overlap in Y (meaning we need X separation)
		if(low_y <= vlevel.y_max && vlevel.y_min <= high_y)
			// Calculate minimum X to have 'spacing' turfs of gap from this vlevel
			var/required_x = vlevel.x_max + spacing + 1
			if(required_x > low_x && required_x > min_x)
				min_x = required_x
	return min_x

////////////////////////////////

/datum/zLevel/station

	name = "station"
	movementChance = ZLEVEL_BASE_CHANCE * ZLEVEL_STATION_MODIFIER


/datum/zLevel/centcomm

	name = "centcomm"
	teleJammed = 1
	movementJammed = 1
	bluespace_jammed = 1

/datum/zLevel/space

	name = "space"
	movementChance = ZLEVEL_BASE_CHANCE * ZLEVEL_SPACE_MODIFIER

/datum/zLevel/mining
	name = "mining"

/datum/zLevel/krakenroid
	name = "krakenroid"

/datum/zLevel/krakenroid/blur_holomap(var/area/aera, var/turf/truf)
	if (istype(aera, /area/mine/explored) && !istype(truf, /turf/unsimulated/floor/airless))
		if (prob(80)) //blurring the shape of Snaxi's Kraken asteroid so it's a bit more subtle.
			return TRUE
	return FALSE

//for snowmap
/datum/zLevel/snowsurface
	name = "snowy surface"
	base_turf = /turf/unsimulated/floor/snow
	base_area = /area/surface/snow
	movementJammed = TRUE
	transitionLoops = TRUE
	planetside = TRUE

//for junglestation
/datum/zLevel/junglesurface
	name = "jungle surface"
	base_turf = /turf/unsimulated/floor/planetary/dirt/jungle
	base_area = /area/surface/jungle/landing //hacky workaround.
	planetside = TRUE

/datum/zLevel/jungleunderground
	name = "jungle underground"
	base_turf = /turf/unsimulated/floor/planetary/cave/jungle
	base_area = /area/surface/jungle/underground
	planetside = TRUE

/datum/zLevel/junglesurface/mining
	name = "Jungle Fallen Meteor"

//for Horizon
/datum/zLevel/hyperspace
	name = "hyperspace"
	base_turf = /turf/space/transit/horizon //NRV Horizon flies ever onward.  Replace this with faketransit if the change to the horizon turf goes through or crew will get chucked around like little dolls.
	movementJammed = TRUE

//Currently experimental, contains nothing worthy of interest
/datum/zLevel/desert

	name = "desert"
	teleJammed = 1
	movementJammed = 1
	base_turf = /turf/unsimulated/beach/sand

/datum/zLevel/snowmine //not used on snaxi
	name = "belowMine"
	base_turf = /turf/unsimulated/floor/asteroid/cave/permafrost
	base_area = /area/mine/explored
	movementJammed = TRUE
	transitionLoops = TRUE
	movementChance = ZLEVEL_BASE_CHANCE * ZLEVEL_SPACE_MODIFIER

/datum/zLevel/snow //not used on snaxi
	name = "snow"
	base_turf = /turf/unsimulated/floor/snow
	base_area = /area/surface/snow
	movementChance = ZLEVEL_BASE_CHANCE * ZLEVEL_SPACE_MODIFIER

/datum/zLevel/snow/post_mapload()
	var/lake_density = rand(2,8)
	for(var/i = 0 to lake_density)
		var/turf/T = locate(rand(1, world.maxx),rand(1, world.maxy), z)
		if(!istype(T, base_turf))
			continue
		var/generator = pick(typesof(/obj/structure/radial_gen/cellular_automata/ice))
		new generator(T)

	var/tree_density = rand(25,45)
	for(var/i = 0 to tree_density)
		var/turf/T = locate(rand(1,world.maxx),rand(1, world.maxy), z)
		if(!istype(T, base_turf))
			continue
		var/generator = pick(typesof(/obj/structure/radial_gen/movable/snow_nature/snow_forest) + typesof(/obj/structure/radial_gen/movable/snow_nature/snow_grass))
		new generator(T)

/datum/zLevel/dynamic
	name = "dynamic zLevel"
	movementJammed = TRUE
	transitionLoops = FALSE

// Debug ///////////////////////////////////////////////////////

/*
/mob/verb/getCurMapData()
	to_chat(src, "\nCurrent map data:")
	to_chat(src, "* Short name: [map.nameShort]")
	to_chat(src, "* Long name: [map.nameLong]")
	to_chat(src, "* [map.zLevels.len] Z-levels: [map.zLevels]")
	for(var/datum/zLevel/level in map.zLevels)
		to_chat(src, "  * [level.name], Telejammed : [level.teleJammed], Movejammed : [level.movementJammed]")
	to_chat(src, "* Main station Z: [map.zMainStation]")
	to_chat(src, "* Centcomm Z: [map.zCentcomm]")
	to_chat(src, "* Thunderdome coords: ([map.tDomeX],[map.tDomeY],[map.tDomeZ])")
	to_chat(src, "* Space movement chances: [accessable_z_levels]")
	for(var/z in accessable_z_levels)
		to_chat(src, "  * [z] has chance [accessable_z_levels[z]]")
	return
*/

// Base Turf //////////////////////////////////////////////////

//Returns the lowest turf available on a given Z-level, defaults to space.

/proc/get_base_turf(var/input_v_or_z)
	if(istype(input_v_or_z, /datum/virtual_z))
		var/datum/virtual_z/vz = input_v_or_z
		return vz.base_turf
	else if(isnum(input_v_or_z))
		var/datum/zLevel/L = map.zLevels[input_v_or_z]
		return L.base_turf
	else
		return /turf/space

//Area that blueprints should erase to
/proc/get_base_area(var/z)
	var/datum/zLevel/L = map.zLevels[z]
	if(L.base_area)
		return locate(L.base_area) //this is a type
	else
		return get_space_area()

/proc/change_base_turf(var/choice,var/new_base_path,var/update_old_base = 0)
	var/datum/zLevel/L = map.zLevels[choice]
	if(update_old_base)
		var/previous_base_turf = L.base_turf
		for(var/turf/T in world)
			CHECK_TICK
			if(T.type == previous_base_turf && T.z == choice)
				T.ChangeTurf(new_base_path)
	L.base_turf = new_base_path
	for(var/obj/docking_port/destination/D in all_docking_ports)
		if(D.z == choice)
			D.base_turf_type = new_base_path

/client/proc/set_base_turf()
	set category = "Debug"
	set name = "Set Base Turf"
	set desc = "Set the base turf for a z-level. Defaults to space, does not replace existing tiles."

	if(check_rights(R_DEBUG, 0))
		if(!holder)
			return
		var/choice = input("Which Z-level do you wish to set the base turf for?") as null|num
		if(!choice)
			return
		var/new_base_text = input("Filter to a turf type.","Turf Type") as text
		var/new_base_path = filter_typelist_input("Please select a turf path (cancel to reset to /turf/space).","Turf Path",get_matching_types(new_base_text,/turf))
		if(!new_base_path)
			new_base_path = /turf/space //Only hardcode in the whole thing, feel free to change this if somewhere in the distant future spess is deprecated
		var/update_old_base = alert(src, "Do you wish to update the old base? This will LAG.", "Update old turfs?", "Yes", "No")
		update_old_base = update_old_base == "No" ? 0 : 1
		if(update_old_base)
			message_admins("[key_name_admin(usr)] is replacing the old base turf on Z level [choice] with [get_base_turf(choice)]. This is likely to lag.")
			log_admin("[key_name_admin(usr)] has replaced the old base turf on Z level [choice] with [get_base_turf(choice)].")
		change_base_turf(choice,new_base_path,update_old_base)
		feedback_add_details("admin_verb", "BTC") //If you are copy-pasting this, ensure the 2nd parameter is unique to the new proc!
		message_admins("[key_name_admin(usr)] has set the base turf for Z-level [choice] to [get_base_turf(choice)]. This will affect all destroyed turfs from now on.")
		log_admin("[key_name(usr)] has set the base turf for Z-level [choice] to [get_base_turf(choice)]. This will affect all destroyed turfs from now on.")

/proc/increment_z()
	var/target_z = world.maxz + 1
	skip_turf_init = TRUE
	spawn(0)
		world.maxz++
	UNTIL(world.maxz == target_z)
	skip_turf_init = FALSE

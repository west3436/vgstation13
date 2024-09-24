// Subsystem for things such as vaults and away mission init.

var/datum/subsystem/map/SSmap


/datum/subsystem/map
	name       = "Map"
	init_order = SS_INIT_MAP
	flags      = SS_NO_FIRE

	/// List of all map zones
	var/list/map_zones = list()
	/// Translation of virtual level ID to a virtual level reference
	var/list/virtual_z_translation = list()

	/// List of z level (as number) -> plane offset of that z level
	/// Used to maintain the plane cube
	var/list/z_level_to_plane_offset = list()
	/// List of z level (as number) -> The lowest plane offset in that z stack
	var/list/z_level_to_lowest_plane_offset = list()
	// This pair allows for easy conversion between an offset plane, and its true representation
	// Both are in the form "input plane" -> output plane(s)
	/// Assoc list of string plane values to their true, non offset representation
	var/list/plane_offset_to_true
	/// Assoc list of true string plane values to a list of all potential offset planess
	var/list/true_to_offset_planes
	/// Assoc list of string plane to the plane's offset value
	var/list/plane_to_offset
	/// List of planes that do not allow for offsetting
	var/list/plane_offset_blacklist
	/// List of render targets that do not allow for offsetting
	var/list/render_offset_blacklist
	/// List of plane masters that are of critical priority
	var/list/critical_planes
	/// The largest plane offset we've generated so far
	var/max_plane_offset = 0

/datum/subsystem/map/New()
	NEW_SS_GLOBAL(SSmap)


/datum/subsystem/map/Initialize(timeofday)
	if (config.enable_roundstart_away_missions)
		log_startup_progress("Attempting to generate an away mission...")
		createRandomZlevel()

	if (!config.skip_vault_generation)
		var/watch = start_watch()
		log_startup_progress("Placing random space structures...")
		generate_vaults()
		generate_asteroid_secrets()
		make_mining_asteroid_secrets() // loops 3 times
		log_startup_progress("  Finished placing structures in [stop_watch(watch)]s.")
	else
		log_startup_progress("Not generating vaults - SKIP_VAULT_GENERATION found in config/config.txt")

	//hobo shack generation, one shack will spawn, 1/3 chance of two shacks
	generate_hoboshack()
	if (rand(1,3) == 3)
		generate_hoboshack()

	var/watch_prim = start_watch()
	for(var/datum/zLevel/z in map.zLevels)
		var/watch = start_watch()
		z.post_mapload()
		log_debug("Finished with zLevel [z.z] in [stop_watch(watch)]s.", FALSE)
	log_debug("Finished calling post on zLevels in [stop_watch(watch_prim)]s.", FALSE)

	var/watch = start_watch()
	map.map_specific_init()
	log_debug("Finished map-specific inits in [stop_watch(watch)]s.", FALSE)

	spawn_map_pickspawners() //this is down here so that it calls after allll the vaults etc are done spawning - if in the future some pickspawners don't fire, it's because this needs moving

	..()


///////////////////////////////////
// MAP ZONES & VIRTUAL Z-LEVELS //
//////////////////////////////////
/datum/subsystem/map/proc/get_map_zone_id(mapzone_id)
	var/datum/map_zone/returned_mapzone
	for(var/datum/map_zone/iterated_mapzone as anything in map_zones)
		if(iterated_mapzone.id == mapzone_id)
			returned_mapzone = iterated_mapzone
			break
	return returned_mapzone

/// Searches for a free allocation for the passed type and size, creates new physical levels if nessecary.
/datum/subsystem/map/proc/get_free_allocation(allocation_type, size_x, size_y, allocation_jump = DEFAULT_ALLOC_JUMP)
	var/list/allocation_list
	var/list/levels_to_check = map.zLevels.Copy()
	var/created_new_level = FALSE
	while(TRUE)
		for(var/datum/zLevel/iterated_level as anything in levels_to_check)
			if(iterated_level.allocation_type != allocation_type)
				continue
			allocation_list = find_allocation_in_level(iterated_level, size_x, size_y, allocation_jump)
			if(allocation_list)
				return allocation_list

		if(created_new_level)
			stack_trace("MAPPING: We have failed to find allocation after creating a new level just for it, something went terribly wrong")
			return FALSE
		/// None of the levels could faciliate a new allocation, make a new one
		created_new_level = TRUE
		levels_to_check.Cut()

		var/allocation_name
		switch(allocation_type)
			if(ALLOCATION_FREE)
				allocation_name = "Free Allocation"
			if(ALLOCATION_QUADRANT)
				allocation_name = "Quadrant Allocation"
			else
				allocation_name = "Unaccounted Allocation"

		levels_to_check += map.addZLevel(/datum/zLevel/space,allocate = allocation_type,title = "Generated [allocation_name] Level")

/// Finds a box allocation inside a Z level. Uses a methodical box boundary check method
/datum/subsystem/map/proc/find_allocation_in_level(datum/zLevel/level, size_x, size_y, allocation_jump)
	var/target_x = 1
	var/target_y = 1

	/// Sanity
	if(size_x > world.maxx || size_y > world.maxy)
		stack_trace("Tried to find virtual level allocation that cannot possibly fit in a physical level.")
		return FALSE

	/// Methodical trial and error method
	while(TRUE)
		var/upper_target_x = target_x+size_x
		var/upper_target_y = target_y+size_y

		var/out_of_bounds = FALSE
		if((target_x < 1 || upper_target_x > world.maxx) || (target_y < 1 || upper_target_y > world.maxy))
			out_of_bounds = TRUE

		if(!out_of_bounds && level.is_box_free(target_x, target_y, upper_target_x, upper_target_y))
			return list(target_x, target_y, level.z) //hallelujah we found the unallocated spot

		if(upper_target_x > world.maxx) //If we can't increment x, then the search is over
			break

		var/increments_y = TRUE
		if(upper_target_y > world.maxy)
			target_y = 1
			increments_y = FALSE
		if(increments_y)
			target_y += allocation_jump
		else
			target_x += allocation_jump

/// Creates and passes a new map zone
/datum/subsystem/map/proc/create_map_zone(new_name)
	return new /datum/map_zone(new_name)

/// Allocates, creates and passes a new virtual level
/datum/subsystem/map/proc/create_virtual_level(new_name, list/traits, datum/map_zone/mapzone, width, height, allocation_type = ALLOCATION_FREE, allocation_jump = DEFAULT_ALLOC_JUMP)
	/// Because we add an implicit 1 for the coordinate calcuations.
	width--
	height--
	var/list/allocation_coords = SSmap.get_free_allocation(allocation_type, width, height, allocation_jump)
	return new /datum/virtual_level(new_name, traits, mapzone, allocation_coords[1], allocation_coords[2], allocation_coords[1] + width, allocation_coords[2] + height, allocation_coords[3])

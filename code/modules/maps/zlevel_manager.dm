// Populate the space level list and prepare space transitions
/datum/subsystem/mapping/proc/InitializeDefaultZLevels()
	// IMPORT ON SWITCH TO MODULAR MAP WRITING
	// if (z_list)  // badminnery, no need
	// 	return

	// z_list = list()
	// var/list/default_map_traits = DEFAULT_MAP_TRAITS

	// if (default_map_traits.len != world.maxz)
	// 	WARNING("More or less map attributes pre-defined ([default_map_traits.len]) than existent z-levels ([world.maxz]). Ignoring the larger.")
	// 	if (default_map_traits.len > world.maxz)
	// 		default_map_traits.Cut(world.maxz + 1)
	// for (var/I in 1 to default_map_traits.len)
	// 	var/watch = start_watch()
	// 	var/list/features = default_map_traits[I]
	// 	var/name = features[DL_NAME]
	// 	var/list/traits = features[DL_TRAITS]
	// 	var/datum/zLevel/S = new(I, name)
	// 	z_list += S
	// 	var/datum/map_zone/mapzone = new(name)
	// 	new /datum/virtual_level(name, traits, mapzone, 1, 1, world.maxx, world.maxy, I)
	// 	S.post_mapload()
	// 	log_debug("Finished with zLevel [S.z] in [stop_watch(watch)]s.", FALSE)
	// log_debug("Finished calling post on zLevels in [stop_watch(watch_prim)]s.", FALSE)

	var/watch_prim = start_watch()
	for(var/datum/zLevel/z in map.zLevels)
		var/watch = start_watch()
		z.post_mapload()
		log_debug("Finished with zLevel [z.z] in [stop_watch(watch)]s.", FALSE)
	log_debug("Finished calling post on zLevels in [stop_watch(watch_prim)]s.", FALSE)

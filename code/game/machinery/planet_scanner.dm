// Configuration constants
#define PLANET_SCANNER_MAX_SCANS 25
#define PLANET_SCANNER_BASE_ENERGY_COST 1000000 // Base energy cost in Joules
#define PLANET_SCANNER_ENERGY_EXPONENT 2 // Exponential growth factor for scan costs
#define PLANET_SCANNER_SCAN_MODULE_EFFICIENCY 0.75 // Energy efficiency per scanning module tier
#define PLANET_SCANNER_TICK_DURATION 2 // Seconds per process tick
#define PLANET_SCANNER_DISK_PRINT_COOLDOWN 30 SECONDS // Cooldown between disk prints

// Power constants (Watts) for different capacitor tiers
#define POWER_T1 10000 // 10 kW
#define POWER_T1_MIXED 50000 // 50 kW
#define POWER_T2 100000 // 100 kW
#define POWER_T2_MIXED 250000 // 250 kW
#define POWER_T3 500000 // 500 kW
#define POWER_T3_MIXED 750000 // 750 kW
#define POWER_T4 1250000 // 1.25 MW

/obj/machinery/planet_scanner
	name = "deep space scanner"
	desc = "A sophisticated scanning array capable of detecting suitable planets for exploration. Each scan requires exponentially more power as space becomes more thoroughly explored."
	icon = 'icons/obj/machines/research.dmi'
	icon_state = "scanner_unanchor"
	density = TRUE
	anchored = FALSE
	use_power = MACHINE_POWER_USE_IDLE
	idle_power_usage = 10
	active_power_usage = 100

	// Scanning state
	var/scanning = FALSE
	var/scans_completed = 0
	var/current_scan_energy = 0 // Current energy accumulated in Joules
	var/required_scan_energy = 0 // Required energy for current scan in Joules
	var/waiting_for_generation = FALSE // Waiting for planet generation to complete

	// Upgrade modifiers
	var/max_power = POWER_T1 // Maximum power consumption in Watts (modified by upgrades)
	var/energy_efficiency_modifier = 1.0 // Modifier for energy requirements (lower = more efficient)

	// Cooldown tracking
	var/last_disk_print_time = 0 // World time of last disk print

	// === SCAN FILTERS ===
	// Each enabled filter increases power cost by 50% multiplicatively
	// Filter toggles
	var/filter_altitude = FALSE
	var/filter_gravity = FALSE
	var/filter_temperature = FALSE
	var/filter_humidity = FALSE
	var/filter_atmosphere = FALSE
	// Filter ranges (min, max) - planets must have parameters overlapping these ranges
	var/filter_altitude_min = 0.0
	var/filter_altitude_max = 1.0
	var/filter_gravity_min = 0.5
	var/filter_gravity_max = 2.0
	var/filter_temperature_min = 0.0
	var/filter_temperature_max = 1.0
	var/filter_humidity_min = 0.0
	var/filter_humidity_max = 1.0
	var/filter_atmosphere_min = 0.0
	var/filter_atmosphere_max = 2.0

	machine_flags = SCREWTOGGLE | CROWDESTROY | WRENCHMOVE
	component_parts = newlist(
		/obj/item/weapon/circuitboard/planet_scanner,
		/obj/item/weapon/stock_parts/scanning_module,
		/obj/item/weapon/stock_parts/scanning_module,
		/obj/item/weapon/stock_parts/console_screen,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor
	)

/obj/machinery/planet_scanner/New()
	..()
	RefreshParts()
	calculate_required_energy()
	update_icon()

/obj/machinery/planet_scanner/RefreshParts()
	calculate_energy_efficiency()
	calculate_max_power()
	calculate_required_energy()

/// Calculate energy efficiency based on scanning module upgrades
/obj/machinery/planet_scanner/proc/calculate_energy_efficiency()
	var/total_rating = 0
	for(var/obj/item/weapon/stock_parts/scanning_module/SM in component_parts)
		total_rating += SM.rating

	// Each scanning module tier reduces energy requirements
	// Formula: efficiency = 0.75^(tiers_above_base)
	// With 2 modules: T1=2, T2=4, T3=6, T4=8
	var/tiers_above_base = max(0, total_rating / 2 - 1)
	energy_efficiency_modifier = PLANET_SCANNER_SCAN_MODULE_EFFICIENCY ** tiers_above_base

/// Calculate maximum power consumption based on capacitor upgrades
/obj/machinery/planet_scanner/proc/calculate_max_power()
	var/total_rating = 0
	for(var/obj/item/weapon/stock_parts/capacitor/C in component_parts)
		total_rating += C.rating

	// With 2 capacitors: T1=2, T2=4, T3=6, T4=8
	// Power scales significantly with tier to reduce scan time
	switch(total_rating)
		if(2) // T1 capacitors
			max_power = POWER_T1
		if(3)
			max_power = POWER_T1_MIXED
		if(4) // T2 capacitors
			max_power = POWER_T2
		if(5)
			max_power = POWER_T2_MIXED
		if(6) // T3 capacitors
			max_power = POWER_T3
		if(7)
			max_power = POWER_T3_MIXED
		if(8) // T4 capacitors
			max_power = POWER_T4
		else
			max_power = POWER_T1

/// Calculate the energy required for the next scan
/// Energy requirement doubles with each completed scan, modified by efficiency upgrades
/// Active filters increase cost by 50% multiplicatively per filter
/obj/machinery/planet_scanner/proc/calculate_required_energy()
	var/filter_multiplier = 1.5 ** count_active_filters()
	required_scan_energy = round(PLANET_SCANNER_BASE_ENERGY_COST * (PLANET_SCANNER_ENERGY_EXPONENT ** scans_completed) * energy_efficiency_modifier * filter_multiplier)

/// Count the number of active scan filters
/// Returns: Integer count of enabled filters (0-5)
/obj/machinery/planet_scanner/proc/count_active_filters()
	var/count = 0
	if(filter_altitude) count++
	if(filter_gravity) count++
	if(filter_temperature) count++
	if(filter_humidity) count++
	if(filter_atmosphere) count++
	return count

/// Check if a planet type's parameter ranges can produce a planet matching the current filters
/// Arguments:
/// * planet_path - The planet type path to check
/// Returns: TRUE if the planet type could produce a matching planet, FALSE otherwise
/obj/machinery/planet_scanner/proc/planet_type_matches_filters(planet_path)
	// Create a temporary instance to check the ranges
	var/datum/planet_type/temp = new planet_path
	var/matches = TRUE

	// Check each active filter - planet type must be able to produce planets in the filter range
	// This means the planet type's parameter range must overlap with the filter range
	if(filter_altitude)
		if(temp.altitude_range[2] < filter_altitude_min || temp.altitude_range[1] > filter_altitude_max)
			matches = FALSE

	if(matches && filter_gravity)
		if(temp.gravity_range[2] < filter_gravity_min || temp.gravity_range[1] > filter_gravity_max)
			matches = FALSE

	if(matches && filter_temperature)
		if(temp.temperature_range[2] < filter_temperature_min || temp.temperature_range[1] > filter_temperature_max)
			matches = FALSE

	if(matches && filter_humidity)
		if(temp.humidity_range[2] < filter_humidity_min || temp.humidity_range[1] > filter_humidity_max)
			matches = FALSE

	if(matches && filter_atmosphere)
		if(temp.atmosphere_range[2] < filter_atmosphere_min || temp.atmosphere_range[1] > filter_atmosphere_max)
			matches = FALSE

	qdel(temp)
	return matches

/// Get the filter multiplier for display purposes
/// Returns: The power cost multiplier from active filters
/obj/machinery/planet_scanner/proc/get_filter_multiplier()
	return 1.5 ** count_active_filters()

/// Get the amount of power available from the area's APC
/// Returns: Available power in Watts, or 0 if no APC is available
/obj/machinery/planet_scanner/proc/get_available_power()
	var/area/our_area = get_area(src)
	if(!our_area || !our_area.areaapc)
		return 0

	var/obj/machinery/power/apc/apc = our_area.areaapc
	return apc.avail()

/obj/machinery/planet_scanner/update_icon()
	if(!anchored)
		icon_state = "scanner_unanchor"
	else if(stat & (BROKEN|NOPOWER))
		icon_state = "scanner_depower"
	else if(scanning || waiting_for_generation)
		icon_state = "scanner_active"
	else
		icon_state = "scanner_idle"

/obj/machinery/planet_scanner/power_change()
	..()
	update_icon()

/obj/machinery/planet_scanner/wrenchAnchor(var/mob/user, var/obj/item/I)
	if(scanning)
		to_chat(user, "<span class='notice'>Cannot unanchor while scanning!</span>")
		return FALSE
	. = ..()
	if(!.)
		return
	update_icon()

/obj/machinery/planet_scanner/attack_hand(mob/user)
	if(!anchored)
		to_chat(user, "<span class='warning'>\The [src] must be anchored before it can be operated!</span>")
		return
	tgui_interact(user)

/obj/machinery/planet_scanner/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PlanetScanner", "Deep Space Scanner")
		ui.set_autoupdate(TRUE)
		ui.open()

/obj/machinery/planet_scanner/ui_data(mob/user)
	var/list/data = list()

	// Machine status
	data["anchored"] = anchored
	data["powered"] = !(stat & (BROKEN|NOPOWER))
	data["scanning"] = scanning
	data["scans_completed"] = scans_completed
	data["max_scans"] = PLANET_SCANNER_MAX_SCANS
	data["at_scan_limit"] = scans_completed >= PLANET_SCANNER_MAX_SCANS
	data["can_scan"] = can_start_scan()
	data["waiting_for_generation"] = waiting_for_generation
	data["other_scan_in_progress"] = (SSmapping?.scanning || SSmapping?.generating) && !scanning && !waiting_for_generation
	data["scanning_disabled"] = SSmapping.scanning_disabled

	// Power and energy information
	data["required_energy"] = required_scan_energy
	data["min_power_rate"] = max_power
	data["available_power"] = get_available_power()
	data["current_energy"] = scanning ? current_scan_energy : null
	data["progress"] = get_scan_progress()

	// Generation stage information
	if(waiting_for_generation && SSmapping)
		data["generation_stage"] = SSmapping.current_stage
		data["generation_progress"] = get_generation_stage_progress()
	else
		data["generation_stage"] = null
		data["generation_progress"] = null

	// Planet discoveries
	data["has_discoveries"] = SSmapping?.planets.len > 0
	data["discovered_planets"] = get_planet_list_data()

	// Scan filter information
	data["filters"] = list(
		"altitude" = list(
			"enabled" = filter_altitude,
			"min" = filter_altitude_min,
			"max" = filter_altitude_max,
			"range_min" = 0.0,
			"range_max" = 1.0
		),
		"gravity" = list(
			"enabled" = filter_gravity,
			"min" = filter_gravity_min,
			"max" = filter_gravity_max,
			"range_min" = 0.5,
			"range_max" = 2.0
		),
		"temperature" = list(
			"enabled" = filter_temperature,
			"min" = filter_temperature_min,
			"max" = filter_temperature_max,
			"range_min" = 0.0,
			"range_max" = 1.0
		),
		"humidity" = list(
			"enabled" = filter_humidity,
			"min" = filter_humidity_min,
			"max" = filter_humidity_max,
			"range_min" = 0.0,
			"range_max" = 1.0
		),
		"atmosphere" = list(
			"enabled" = filter_atmosphere,
			"min" = filter_atmosphere_min,
			"max" = filter_atmosphere_max,
			"range_min" = 0.0,
			"range_max" = 2.0
		)
	)
	data["active_filter_count"] = count_active_filters()
	data["filter_multiplier"] = get_filter_multiplier()

	return data

/// Check if the scanner is ready to start a new scan
/obj/machinery/planet_scanner/proc/can_start_scan()
	return anchored && !(stat & (BROKEN|NOPOWER)) && !scanning && scans_completed < PLANET_SCANNER_MAX_SCANS && !SSmapping?.scanning && !SSmapping?.generating && !SSmapping.scanning_disabled

/// Get the current scan progress as a percentage (0-100), or null if not scanning
/obj/machinery/planet_scanner/proc/get_scan_progress()
	if(!scanning && !waiting_for_generation)
		return null
	if(waiting_for_generation)
		return 100 // Show 100% while waiting for generation
	var/progress = min(current_scan_energy / required_scan_energy, 1.0)
	return round(progress * 100, 1)

/// Get the progress of the current generation stage as a percentage (0-100)
/obj/machinery/planet_scanner/proc/get_generation_stage_progress()
	if(!SSmapping || !SSmapping.generating)
		return 0

	switch(SSmapping.current_stage)
		if(1)
			if(SSmapping.terrain_queue.len > 0)
				return round((SSmapping.queue_index / SSmapping.terrain_queue.len) * 100, 1)
		if(3)
			if(SSmapping.population_queue.len > 0)
				return round((SSmapping.queue_index / SSmapping.population_queue.len) * 100, 1)
		else
			return 100

	return 0

/// Build the list of discovered planets for the UI
/// Returns: List of planet data dictionaries, or null if no planets discovered
/obj/machinery/planet_scanner/proc/get_planet_list_data()
	if(!SSmapping?.planets.len)
		return null

	var/list/planet_data = list()
	for(var/datum/planet_type/planet in SSmapping.planets)
		if(planet.hidden)
			continue

		var/list/planet_info = list()
		planet_info["name"] = planet.name
		planet_info["desc"] = planet.desc
		planet_info["type"] = planet.type
		planet_info["procedural_name"] = planet.planet_name
		planet_info["icon_data"] = icon2base64(planet.ico)

		// Planet parameters (visible to scanner)
		planet_info["altitude"] = planet.altitude
		planet_info["gravity"] = planet.gravity
		planet_info["temperature"] = planet.temperature
		planet_info["humidity"] = planet.humidity
		planet_info["atmosphere"] = planet.atmosphere
		// Note: population and threat are intentionally not sent to the UI (hidden values)

		// Get all beacons on this planet
		var/list/beacons = list()
		var/has_active_beacon = FALSE
		if(planet.allocation)
			var/datum/allocation/alloc = planet.allocation
			for(var/obj/item/device/gps/planetary/gps in GPS_list)
				var/turf/gps_turf = get_turf(gps)
				if(!gps_turf || gps_turf.z != map.zProcGen)
					continue
				var/datum/allocation/gps_alloc = SSmapping.get_allocation(trf = gps_turf)
				if(gps_alloc == alloc && gps.transmitting)
					var/list/beacon_info = list()
					beacon_info["tag"] = gps.gpstag
					beacon_info["active"] = gps.beacon_active
					beacon_info["location"] = gps.get_location_name()
					if(gps.beacon_active)
						has_active_beacon = TRUE
					beacons += list(beacon_info)

		planet_info["beacons"] = beacons
		planet_info["has_active_beacon"] = has_active_beacon
		planet_data += list(planet_info)

	return planet_data

/obj/machinery/planet_scanner/ui_act(action, params)
	. = ..()
	if(.)
		return

	switch(action)
		if("start_scan")
			if(!can_start_scan())
				return FALSE
			start_scan(usr)
			return TRUE
		if("print_disk")
			var/planet_index = text2num(params["planet_index"])
			if(!validate_planet_index(planet_index, usr))
				return FALSE
			print_destination_disk(usr, planet_index)
			return TRUE
		if("toggle_filter")
			var/filter_name = params["filter"]
			toggle_filter(filter_name)
			calculate_required_energy()
			return TRUE
		if("set_filter_min")
			var/filter_name = params["filter"]
			var/value = text2num(params["value"])
			set_filter_min(filter_name, value)
			return TRUE
		if("set_filter_max")
			var/filter_name = params["filter"]
			var/value = text2num(params["value"])
			set_filter_max(filter_name, value)
			return TRUE

/// Toggle a scan filter on/off
/obj/machinery/planet_scanner/proc/toggle_filter(filter_name)
	switch(filter_name)
		if("altitude")
			filter_altitude = !filter_altitude
		if("gravity")
			filter_gravity = !filter_gravity
		if("temperature")
			filter_temperature = !filter_temperature
		if("humidity")
			filter_humidity = !filter_humidity
		if("atmosphere")
			filter_atmosphere = !filter_atmosphere

/// Set the minimum value for a scan filter
/obj/machinery/planet_scanner/proc/set_filter_min(filter_name, value)
	switch(filter_name)
		if("altitude")
			filter_altitude_min = clamp(value, 0.0, filter_altitude_max)
		if("gravity")
			filter_gravity_min = clamp(value, 0.5, filter_gravity_max)
		if("temperature")
			filter_temperature_min = clamp(value, 0.0, filter_temperature_max)
		if("humidity")
			filter_humidity_min = clamp(value, 0.0, filter_humidity_max)
		if("atmosphere")
			filter_atmosphere_min = clamp(value, 0.0, filter_atmosphere_max)

/// Set the maximum value for a scan filter
/obj/machinery/planet_scanner/proc/set_filter_max(filter_name, value)
	switch(filter_name)
		if("altitude")
			filter_altitude_max = clamp(value, filter_altitude_min, 1.0)
		if("gravity")
			filter_gravity_max = clamp(value, filter_gravity_min, 2.0)
		if("temperature")
			filter_temperature_max = clamp(value, filter_temperature_min, 1.0)
		if("humidity")
			filter_humidity_max = clamp(value, filter_humidity_min, 1.0)
		if("atmosphere")
			filter_atmosphere_max = clamp(value, filter_atmosphere_min, 2.0)

/// Validate that a planet index from the UI is valid
/// Args:
///   planet_index - 0-indexed planet index from the frontend
///   user - The mob to send error messages to
/// Returns: TRUE if valid, FALSE otherwise
/obj/machinery/planet_scanner/proc/validate_planet_index(planet_index, mob/user)
	if(!SSmapping || !SSmapping.planets || !SSmapping.planets.len)
		if(user)
			to_chat(user, "<span class='warning'>No planets discovered.</span>")
		return FALSE

	if(planet_index < 0 || planet_index >= SSmapping.planets.len)
		if(user)
			to_chat(user, "<span class='warning'>Invalid planet selected.</span>")
		return FALSE

	return TRUE

/obj/machinery/planet_scanner/ui_state(mob/user)
	return default_state

/// Start a new planet scan
/obj/machinery/planet_scanner/proc/start_scan(mob/user)
	scanning = TRUE
	current_scan_energy = 0
	use_power = MACHINE_POWER_USE_ACTIVE
	SSmapping.scanning = TRUE
	update_icon()
	return TRUE

/obj/machinery/planet_scanner/process()
	if(!anchored)
		update_icon()
		return

	if(stat & (BROKEN|NOPOWER|FORCEDISABLE))
		if(scanning)
			abort_scan("no power")
		return

	if(scanning)
		process_scanning()

	..()

/obj/machinery/planet_scanner/proc/process_scanning()
	if(waiting_for_generation)
		if(!SSmapping.generating)
			finalize_scan()
		return

	var/available_power = get_available_power()
	if(available_power <= 0)
		abort_scan("no power")
		return

	// Consume power and accumulate energy
	var/power_consumed = min(available_power, max_power)
	accumulate_scan_energy(power_consumed)
	use_power(power_consumed)

	// Check if scan is complete
	if(current_scan_energy >= required_scan_energy)
		complete_scan()

/// Accumulate energy for the current scan based on power consumed
/// Energy (Joules) = Power (Watts) × Time (seconds)
/obj/machinery/planet_scanner/proc/accumulate_scan_energy(power_consumed)
	var/energy_per_tick = power_consumed * PLANET_SCANNER_TICK_DURATION
	current_scan_energy += energy_per_tick

/// Abort the current scan due to an error condition
/obj/machinery/planet_scanner/proc/abort_scan(reason)
	visible_message("<span class='warning'>[src] stops scanning due to [reason]!</span>")
	scanning = FALSE
	waiting_for_generation = FALSE
	current_scan_energy = 0
	use_power = MACHINE_POWER_USE_IDLE
	SSmapping.scanning = FALSE
	playsound(src, 'sound/machines/alert.ogg', 50, 1)
	update_icon()

/// Complete the current scan and spawn a new planet (energy requirement met)
/obj/machinery/planet_scanner/proc/complete_scan()
	waiting_for_generation = TRUE
	use_power = MACHINE_POWER_USE_IDLE // Stop consuming power
	SSmapping.scanning = FALSE
	spawn_new_planet()

/// Finalize the scan after planet generation is complete
/obj/machinery/planet_scanner/proc/finalize_scan()
	scanning = FALSE
	waiting_for_generation = FALSE
	scans_completed++
	playsound(src, 'sound/machines/twobeep.ogg', 50, 1)
	visible_message("<span class='notice'>[src] completes its scan and displays the results.</span>")
	calculate_required_energy()
	update_icon()

/// Spawn a new planet with random type and ruin
/// Returns: The planet type that was spawned
/obj/machinery/planet_scanner/proc/spawn_new_planet()
	if(!SSmapping)
		CRASH("New planet spawn attempted before mapping subsystem initialized")

	var/selected_planet_type = select_random_planet_type()
	var/selected_ruin_type = select_random_ruin_type()

	SSmapping.spawn_planet(selected_planet_type, selected_ruin_type)

	return selected_planet_type

/// Select a random planet type from available types
/// Filters planet types based on active scan filters
/obj/machinery/planet_scanner/proc/select_random_planet_type()
	var/list/available_planets = SSmapping.planet_types.Copy()

	// If any filters are active, filter the available planet types
	if(count_active_filters() > 0)
		var/list/filtered_planets = list()
		for(var/planet_path in available_planets)
			if(planet_type_matches_filters(planet_path))
				filtered_planets += planet_path

		// If filters eliminated all options, fall back to unfiltered list
		// This shouldn't happen with proper filter validation in the UI
		if(filtered_planets.len > 0)
			available_planets = filtered_planets

	return pick(available_planets)

/// Select a random ruin type from available mining ruins
/// Returns: A ruin type path, or null if no ruins are available
/obj/machinery/planet_scanner/proc/select_random_ruin_type()
	var/list/available_ruins = list()
	for(var/ruin_path in subtypesof(/datum/map_element/ruin))
		available_ruins += ruin_path

	if(available_ruins.len)
		return pick(available_ruins)
	return null

/obj/machinery/planet_scanner/proc/print_destination_disk(mob/user, planet_index)
	if(world.time < last_disk_print_time + PLANET_SCANNER_DISK_PRINT_COOLDOWN)
		to_chat(user, "<span class='warning'>Disk printer is still cooling down! Please wait [(last_disk_print_time + PLANET_SCANNER_DISK_PRINT_COOLDOWN - world.time)] seconds.</span>")
		return FALSE

	// Convert from 0-indexed frontend to 1-indexed DM list
	var/dm_index = planet_index + 1

	var/datum/planet_type/planet = get_planet_by_index(dm_index)
	if(!planet)
		to_chat(user, "<span class='warning'>Planet data corrupted or invalid.</span>")
		return FALSE

	to_chat(user, "<span class='notice'>Printing destination disk for [planet.planet_name]...</span>")
	playsound(src, 'sound/effects/dotmatrixprinter.ogg', 40, 1)

	var/obj/item/weapon/disk/shuttle_coords/procedural/disk = new(get_turf(src))
	disk.planet_ref = planet
	disk.header = "[planet.planet_name] Landing"

	last_disk_print_time = world.time

	return TRUE

/// Get a planet from the discovered planets list by 1-indexed position
/// Returns: The planet datum, or null if invalid
/obj/machinery/planet_scanner/proc/get_planet_by_index(dm_index)
	if(!SSmapping?.planets?.len)
		return null

	if(dm_index < 1 || dm_index > SSmapping.planets.len)
		return null

	return SSmapping.planets[dm_index]


// Cleanup defines
#undef PLANET_SCANNER_MAX_SCANS
#undef PLANET_SCANNER_BASE_ENERGY_COST
#undef PLANET_SCANNER_ENERGY_EXPONENT
#undef PLANET_SCANNER_SCAN_MODULE_EFFICIENCY
#undef PLANET_SCANNER_TICK_DURATION
#undef PLANET_SCANNER_DISK_PRINT_COOLDOWN
#undef POWER_T1
#undef POWER_T1_MIXED
#undef POWER_T2
#undef POWER_T2_MIXED
#undef POWER_T3
#undef POWER_T3_MIXED
#undef POWER_T4

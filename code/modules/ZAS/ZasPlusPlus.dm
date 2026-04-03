// ZAS++ Debug Panel - Monitoring and control for the native atmos DLL

/datum/zas_plus_plus
	var/dll_loaded = FALSE
	var/dll_version = 0

	// Performance tracking
	var/last_dm_tick_ms = 0
	var/last_dll_tick_ms = 0
	var/avg_dm_tick_ms = 0
	var/avg_dll_tick_ms = 0
	var/benchmark_iterations = 0
	var/benchmark_running = FALSE
	var/last_dm_ops = 0
	var/last_dll_results = 0

	// Sync check results
	var/list/last_sync_report = null
	var/last_sync_time = 0

var/datum/zas_plus_plus/zas_plus_plus_panel_datum

/datum/zas_plus_plus/New()
	dll_loaded = TRUE
	dll_version = call_ext(ATMOS_DLL, "byond:atmos_get_version")()

/datum/zas_plus_plus/proc/get_dll_zone_count()
	return atmos_native_zone_count()

/datum/zas_plus_plus/proc/get_dll_edge_count()
	return atmos_native_edge_count()

/datum/zas_plus_plus/proc/get_dll_active_edge_count()
	return atmos_native_active_edge_count()

/datum/zas_plus_plus/proc/run_sync_check()
	var/list/report = list()
	var/dm_zones = SSair.zones.len
	var/dm_edges = SSair.edges.len
	var/dm_active = SSair.processing_parts[SSAIR_EDGES] ? length(SSair.processing_parts[SSAIR_EDGES]) : 0

	var/dll_zones = get_dll_zone_count()
	var/dll_edges = get_dll_edge_count()
	var/dll_active = get_dll_active_edge_count()

	report["zones_match"] = (dm_zones == dll_zones)
	report["edges_match"] = (dm_edges == dll_edges)
	report["active_match"] = (dm_active == dll_active)

	report["dll_zones"] = dll_zones
	report["dll_edges"] = dll_edges
	report["dll_active"] = dll_active

	// Sample up to 10 zones and compare air state
	var/list/zone_diffs = list()
	var/checked = 0
	for(var/zone/Z in SSair.zones)
		if(checked >= 10)
			break
		if(Z.invalid)
			continue
		var/list/dll_air = atmos_native_get_zone_air(Z.native_id)
		if(!dll_air || !dll_air.len)
			zone_diffs += list(list(
				"name" = Z.name,
				"native_id" = Z.native_id,
				"status" = "missing",
				"detail" = "Zone not found in DLL"
			))
			checked++
			continue

		// Compare pressure and temperature
		var/dm_pressure = Z.air.return_pressure()
		var/dm_temp = Z.air.temperature
		var/dll_pressure = dll_air[12]  // pressure is at index 12
		var/dll_temp = dll_air[10]      // temperature is at index 10

		var/pressure_diff = abs(dm_pressure - dll_pressure)
		var/temp_diff = abs(dm_temp - dll_temp)

		if(pressure_diff > 1 || temp_diff > 2)
			zone_diffs += list(list(
				"name" = Z.name,
				"native_id" = Z.native_id,
				"status" = "diverged",
				"detail" = "P:[round(dm_pressure, 0.1)] vs [round(dll_pressure, 0.1)] kPa, T:[round(dm_temp, 0.1)] vs [round(dll_temp, 0.1)] K"
			))
		else
			zone_diffs += list(list(
				"name" = Z.name,
				"native_id" = Z.native_id,
				"status" = "synced",
				"detail" = "P:[round(dm_pressure, 0.1)] kPa, T:[round(dm_temp, 0.1)] K"
			))
		checked++

	report["zone_samples"] = zone_diffs
	report["dm_zones"] = dm_zones
	report["dm_edges"] = dm_edges
	report["dm_active"] = dm_active

	last_sync_report = report
	last_sync_time = world.time
	return report

/datum/zas_plus_plus/proc/resync_all_zones()
	var/count = 0
	for(var/zone/Z in SSair.zones)
		if(Z.invalid)
			continue
		atmos_native_set_zone_air(Z.native_id, Z.air)
		count++
	return count

/datum/zas_plus_plus/proc/run_stress_test()
	var/zones_filled = 0
	var/zones_ignited = 0
	// Fill every zone with plasma and ignite it
	for(var/zone/Z in SSair.zones)
		if(Z.invalid)
			continue
		if(!Z.contents.len)
			continue
		// Inject plasma proportional to zone volume
		var/plasma_moles = Z.air.volume * ONE_ATMOSPHERE / (R_IDEAL_GAS_EQUATION * T20C) * 0.3
		Z.air.adjust_gas(GAS_PLASMA, plasma_moles)
		// Sync the modified air to the DLL
		atmos_native_set_zone_air(Z.native_id, Z.air)
		zones_filled++
		// Ignite a turf in the zone
		var/turf/simulated/T = pick(Z.contents)
		if(istype(T))
			T.hotspot_expose(1000, CELL_VOLUME)
			zones_ignited++
	to_chat(usr, "<span class='danger'>ZAS++ Stress Test: Filled [zones_filled] zones with plasma, ignited [zones_ignited].</span>")

/datum/zas_plus_plus/proc/run_benchmark()
	benchmark_running = TRUE

	// Resync zone air to DLL so comparison is fair
	resync_all_zones()

	// Benchmark DM-side: iterate ALL edges and run compare()
	var/dm_start = world.tick_usage
	last_dm_ops = 0
	for(var/connection_edge/zone/E in SSair.edges)
		if(E.A.invalid || E.B.invalid)
			continue
		E.A.air.compare(E.B.air)
		last_dm_ops++
	last_dm_tick_ms = TICK_DELTA_TO_MS(world.tick_usage - dm_start)

	// Benchmark DLL-side batch tick
	var/dll_start = world.tick_usage
	var/list/results = atmos_native_tick_edges()
	last_dll_tick_ms = TICK_DELTA_TO_MS(world.tick_usage - dll_start)
	last_dll_results = results ? length(results) / EDGE_RESULT_STRIDE : 0

	benchmark_iterations++
	if(benchmark_iterations == 1)
		avg_dm_tick_ms = last_dm_tick_ms
		avg_dll_tick_ms = last_dll_tick_ms
	else
		avg_dm_tick_ms = MC_AVERAGE(avg_dm_tick_ms, last_dm_tick_ms)
		avg_dll_tick_ms = MC_AVERAGE(avg_dll_tick_ms, last_dll_tick_ms)

	// Resync after benchmark since DLL tick mutated DLL zone air
	resync_all_zones()

	benchmark_running = FALSE

// ============================================================================
// TGUI Interface
// ============================================================================

/datum/zas_plus_plus/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ZasPlusPlus", "ZAS++")
		ui.open()
		ui.set_autoupdate(TRUE)

/datum/zas_plus_plus/ui_data(mob/user)
	var/list/data = list()

	data["dll_loaded"] = dll_loaded
	data["dll_version"] = dll_version

	// DM-side counts
	data["dm_zones"] = SSair.zones.len
	data["dm_edges"] = SSair.edges.len
	data["dm_active_edges"] = length(SSair.processing_parts[SSAIR_EDGES])
	data["dm_pending_tiles"] = length(SSair.processing_parts[SSAIR_TILES])
	data["dm_pending_zones"] = length(SSair.processing_parts[SSAIR_ZONE])
	data["dm_hotspots"] = length(SSair.processing_parts[SSAIR_HOTSPOT])

	// DLL-side counts
	data["dll_zones"] = get_dll_zone_count()
	data["dll_edges"] = get_dll_edge_count()
	data["dll_active_edges"] = get_dll_active_edge_count()

	// SSair tick costs (per-phase from cost_parts, total from subsystem)
	data["cost_tiles"] = round(SSair.cost_parts[SSAIR_TILES], 0.01)
	data["cost_deferred"] = round(SSair.cost_parts[SSAIR_DEFERRED], 0.01)
	data["cost_edges"] = round(SSair.cost_parts[SSAIR_EDGES], 0.01)
	data["cost_hotspot"] = round(SSair.cost_parts[SSAIR_HOTSPOT], 0.01)
	data["cost_zones"] = round(SSair.cost_parts[SSAIR_ZONE], 0.01)
	data["cost_total_subsystem"] = round(SSair.cost, 0.01)
	data["current_cycle"] = SSair.current_cycle

	// Subsystem health
	data["air_state"] = SSair.state
	data["air_cost"] = round(SSair.cost, 0.01)
	data["air_tick_usage"] = round(SSair.tick_usage, 0.01)
	data["air_ticks"] = round(SSair.ticks, 0.1)
	data["air_can_fire"] = SSair.can_fire
	data["air_times_fired"] = SSair.times_fired
	data["air_failed_ticks"] = SSair.failed_ticks

	data["pipenet_state"] = SSpipenet.state
	data["pipenet_cost"] = round(SSpipenet.cost, 0.01)
	data["pipenet_tick_usage"] = round(SSpipenet.tick_usage, 0.01)
	data["pipenet_ticks"] = round(SSpipenet.ticks, 0.1)
	data["pipenet_can_fire"] = SSpipenet.can_fire
	data["pipenet_times_fired"] = SSpipenet.times_fired


	// Benchmark data
	data["last_dm_tick_ms"] = round(last_dm_tick_ms, 0.01)
	data["last_dll_tick_ms"] = round(last_dll_tick_ms, 0.01)
	data["avg_dm_tick_ms"] = round(avg_dm_tick_ms, 0.01)
	data["avg_dll_tick_ms"] = round(avg_dll_tick_ms, 0.01)
	data["benchmark_iterations"] = benchmark_iterations
	data["benchmark_running"] = benchmark_running
	data["last_dm_ops"] = last_dm_ops
	data["last_dll_results"] = last_dll_results

	// Sync report
	if(last_sync_report)
		data["sync_report"] = last_sync_report
		data["sync_age"] = round((world.time - last_sync_time) / 10, 0.1)
	else
		data["sync_report"] = null
		data["sync_age"] = -1

	return data

/datum/zas_plus_plus/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return

	switch(action)
		if("sync_check")
			run_sync_check()
			return TRUE

		if("resync")
			var/count = resync_all_zones()
			to_chat(usr, "<span class='notice'>ZAS++: Resynced [count] zones to DLL.</span>")
			run_sync_check()
			return TRUE

		if("benchmark")
			if(!benchmark_running)
				run_benchmark()
			return TRUE

		if("stress_test")
			run_stress_test()
			return TRUE

		if("reset_benchmark")
			last_dm_tick_ms = 0
			last_dll_tick_ms = 0
			avg_dm_tick_ms = 0
			avg_dll_tick_ms = 0
			benchmark_iterations = 0
			last_dm_ops = 0
			last_dll_results = 0
			return TRUE

	return FALSE

/datum/zas_plus_plus/ui_status(mob/user, datum/ui_state/state)
	return UI_INTERACTIVE

// ============================================================================
// Admin Verb
// ============================================================================

/client/proc/zas_plus_plus()
	set name = "ZAS++"
	set category = "Debug"

	if(!zas_plus_plus_panel_datum)
		zas_plus_plus_panel_datum = new /datum/zas_plus_plus()
	zas_plus_plus_panel_datum.tgui_interact(usr)

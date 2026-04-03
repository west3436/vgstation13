// _atmos_native.dm - DM proxy layer for the atmos_native C++ DLL
//
// This file provides wrapper procs for all DLL calls and handles
// initialization of the native atmospherics simulation.

// Maps gas string IDs to native integer indices (must match C++ GasID enum)
var/list/atmos_native_gas_index = list(
	GAS_OXYGEN   = GAS_IDX_OXYGEN,
	GAS_NITROGEN = GAS_IDX_NITROGEN,
	GAS_CARBON   = GAS_IDX_CO2,
	GAS_PLASMA   = GAS_IDX_PLASMA,
	GAS_SLEEPING = GAS_IDX_N2O,
	GAS_CRYOTHEUM = GAS_IDX_CRYOTHEUM,
	GAS_VOLATILE = GAS_IDX_VOLATILE,
	GAS_OXAGENT  = GAS_IDX_OXAGENT,
	GAS_RADON    = GAS_IDX_RADON
)

// Ordered list of gas IDs matching native index order
var/list/atmos_native_gas_order = list(
	GAS_OXYGEN,
	GAS_NITROGEN,
	GAS_CARBON,
	GAS_PLASMA,
	GAS_SLEEPING,
	GAS_CRYOTHEUM,
	GAS_VOLATILE,
	GAS_OXAGENT,
	GAS_RADON
)

// Initialize the native atmos DLL. Call during SSair.Initialize().
/proc/atmos_native_init()
	// Reset DLL state
	call_ext(ATMOS_DLL, "byond:atmos_init")()

	// Register all gas types with their properties
	for(var/datum/gas/G in XGM.gases)
		var/idx = atmos_native_gas_index[G.id]
		if(!isnull(idx))
			call_ext(ATMOS_DLL, "byond:atmos_register_gas")(idx, G.specific_heat, G.molar_mass)

	// Set constants: min_air_to_suspend, sharing_lookup_table[6]
	call_ext(ATMOS_DLL, "byond:atmos_set_constants")(\
		MINIMUM_AIR_TO_SUSPEND,\
		0.30, 0.40, 0.48, 0.54, 0.60, 0.66\
	)

	var/version = call_ext(ATMOS_DLL, "byond:atmos_get_version")()
	to_chat(world, "<span class='info'>Atmos Native DLL v[version] initialized.</span>")

// ============================================================================
// Gas Mixture Packing/Unpacking
// ============================================================================

// Extract gas moles from a gas_mixture in native index order.
// Returns a flat list: [o2, n2, co2, plasma, n2o, cryo, volatile, oxagent, radon, temp, volume]
/proc/atmos_pack_gas(datum/gas_mixture/mix)
	var/list/result = list()
	for(var/gas_id in atmos_native_gas_order)
		result += (mix.gas[gas_id] || 0)
	result += mix.temperature
	result += mix.volume
	return result

// Write native index-ordered gas values back into a gas_mixture.
// `values` is a list: [o2, n2, co2, plasma, n2o, cryo, volatile, oxagent, radon, temp, volume, pressure, total_moles]
/proc/atmos_unpack_gas(datum/gas_mixture/mix, list/values)
	if(!values || !values.len)
		return
	var/i = 1
	for(var/gas_id in atmos_native_gas_order)
		var/moles = values[i++]
		if(moles > 0)
			mix.gas[gas_id] = moles
		else
			mix.gas -= gas_id
	if(i <= values.len)
		mix.temperature = values[i++]
	if(i <= values.len)
		mix.volume = values[i++]
	if(i <= values.len)
		mix.pressure = values[i++]
	if(i <= values.len)
		mix.total_moles = values[i++]

// Unpack gas from a flat list at a given offset (avoids list copy).
// Reads 13 values: gas0..8, temp, volume, pressure, total_moles starting at values[offset].
/proc/atmos_unpack_gas_at(datum/gas_mixture/mix, list/values, offset)
	for(var/gas_id in atmos_native_gas_order)
		var/moles = values[offset++]
		if(moles > 0)
			mix.gas[gas_id] = moles
		else
			mix.gas -= gas_id
	mix.temperature = values[offset++]
	mix.volume = values[offset++]
	mix.pressure = values[offset++]
	mix.total_moles = values[offset++]

// ============================================================================
// Zone Operations
// ============================================================================

/proc/atmos_native_add_zone(zone/Z)
	var/list/packed = atmos_pack_gas(Z.air)
	call_ext(ATMOS_DLL, "byond:atmos_add_zone")(\
		Z.native_id,\
		packed[1], packed[2], packed[3], packed[4], packed[5],\
		packed[6], packed[7], packed[8], packed[9],\
		packed[10], packed[11]\
	)

/proc/atmos_native_remove_zone(zone_id)
	call_ext(ATMOS_DLL, "byond:atmos_remove_zone")(zone_id)

/proc/atmos_native_merge_zones(from_id, into_id)
	call_ext(ATMOS_DLL, "byond:atmos_merge_zones")(from_id, into_id)

/proc/atmos_native_zone_add_turf(zone_id, datum/gas_mixture/turf_air)
	var/list/packed = atmos_pack_gas(turf_air)
	call_ext(ATMOS_DLL, "byond:atmos_zone_add_turf")(\
		zone_id,\
		packed[1], packed[2], packed[3], packed[4], packed[5],\
		packed[6], packed[7], packed[8], packed[9],\
		packed[10], packed[11]\
	)

/proc/atmos_native_zone_remove_turf(zone_id, turf_volume)
	return call_ext(ATMOS_DLL, "byond:atmos_zone_remove_turf")(zone_id, turf_volume)

/proc/atmos_native_get_zone_air(zone_id)
	return call_ext(ATMOS_DLL, "byond:atmos_get_zone_air")(zone_id)

/proc/atmos_native_set_zone_air(zone_id, datum/gas_mixture/mix)
	var/list/packed = atmos_pack_gas(mix)
	call_ext(ATMOS_DLL, "byond:atmos_set_zone_air")(\
		zone_id,\
		packed[1], packed[2], packed[3], packed[4], packed[5],\
		packed[6], packed[7], packed[8], packed[9],\
		packed[10], packed[11]\
	)

// ============================================================================
// Edge Operations
// ============================================================================

/proc/atmos_native_add_zone_edge(zone_a_id, zone_b_id)
	return call_ext(ATMOS_DLL, "byond:atmos_add_edge")(EDGE_TYPE_ZONE, zone_a_id, zone_b_id)

/proc/atmos_native_add_unsim_edge(zone_a_id, datum/gas_mixture/unsim_air)
	var/list/packed = atmos_pack_gas(unsim_air)
	return call_ext(ATMOS_DLL, "byond:atmos_add_edge")(\
		EDGE_TYPE_UNSIM, zone_a_id,\
		packed[1], packed[2], packed[3], packed[4], packed[5],\
		packed[6], packed[7], packed[8], packed[9],\
		packed[10], packed[11]\
	)

/proc/atmos_native_remove_edge(edge_id)
	call_ext(ATMOS_DLL, "byond:atmos_remove_edge")(edge_id)

/proc/atmos_native_edge_add_conn(edge_id, is_direct)
	call_ext(ATMOS_DLL, "byond:atmos_edge_add_conn")(edge_id, is_direct)

/proc/atmos_native_edge_remove_conn(edge_id, was_direct)
	call_ext(ATMOS_DLL, "byond:atmos_edge_remove_conn")(edge_id, was_direct)

/proc/atmos_native_edge_set_sleeping(edge_id, sleeping)
	call_ext(ATMOS_DLL, "byond:atmos_edge_set_sleeping")(edge_id, sleeping)

// ============================================================================
// Tick Processing
// ============================================================================

/proc/atmos_native_tick_edges()
	return call_ext(ATMOS_DLL, "byond:atmos_tick_edges")()

/proc/atmos_native_tick_zones()
	return call_ext(ATMOS_DLL, "byond:atmos_tick_zones")()

// Bulk-set multiple zone airs in a single DLL call.
// Takes a flat list: [count, zone_id1, gas0..8, temp, vol, zone_id2, ...]
/proc/atmos_native_bulk_set_zone_air(list/zone_data)
	return call_ext(ATMOS_DLL, "byond:atmos_bulk_set_zone_air")(arglist(zone_data))

// ============================================================================
// Standalone Gas Mixture Operations
// ============================================================================

/proc/atmos_native_mix_create(datum/gas_mixture/mix)
	var/list/packed = atmos_pack_gas(mix)
	return call_ext(ATMOS_DLL, "byond:atmos_mix_create")(\
		packed[11],\
		packed[1], packed[2], packed[3], packed[4], packed[5],\
		packed[6], packed[7], packed[8], packed[9],\
		packed[10]\
	)

/proc/atmos_native_mix_destroy(mixture_id)
	call_ext(ATMOS_DLL, "byond:atmos_mix_destroy")(mixture_id)

/proc/atmos_native_mix_get(mixture_id)
	return call_ext(ATMOS_DLL, "byond:atmos_mix_get")(mixture_id)

/proc/atmos_native_mix_set(mixture_id, datum/gas_mixture/mix)
	var/list/packed = atmos_pack_gas(mix)
	call_ext(ATMOS_DLL, "byond:atmos_mix_set")(\
		mixture_id,\
		packed[1], packed[2], packed[3], packed[4], packed[5],\
		packed[6], packed[7], packed[8], packed[9],\
		packed[10], packed[11]\
	)

/proc/atmos_native_mix_merge(target_id, source_id)
	call_ext(ATMOS_DLL, "byond:atmos_mix_merge")(target_id, source_id)

/proc/atmos_native_mix_remove_ratio(mixture_id, ratio)
	return call_ext(ATMOS_DLL, "byond:atmos_mix_remove_ratio")(mixture_id, ratio)

/proc/atmos_native_mix_heat_capacity(mixture_id)
	return call_ext(ATMOS_DLL, "byond:atmos_mix_heat_capacity")(mixture_id)

/proc/atmos_native_mix_compare(id_a, id_b)
	return call_ext(ATMOS_DLL, "byond:atmos_mix_compare")(id_a, id_b)

/proc/atmos_native_mix_share_ratio(id_a, id_b, ratio)
	call_ext(ATMOS_DLL, "byond:atmos_mix_share_ratio")(id_a, id_b, ratio)

// ============================================================================
// Batch Pipenet Reconcile
// ============================================================================

// Takes a list of gas_mixture datums, packs them inline, and calls the DLL to
// merge all into a transient, run reactions, and return the equalized state.
// Returns the result list or null on failure.
/proc/atmos_native_batch_reconcile(list/datum/gas_mixture/gases)
	var/count = gases.len
	if(!count)
		return null
	// Build flat arg list: count, then GAS_ARG_COUNT args per mixture
	var/list/arg_list = list(count)
	for(var/datum/gas_mixture/G in gases)
		arg_list += atmos_pack_gas(G)
	return call_ext(ATMOS_DLL, "byond:atmos_batch_reconcile")(arglist(arg_list))

// ============================================================================
// Debug
// ============================================================================

/proc/atmos_native_zone_count()
	return call_ext(ATMOS_DLL, "byond:atmos_zone_count")()

/proc/atmos_native_edge_count()
	return call_ext(ATMOS_DLL, "byond:atmos_edge_count")()

/proc/atmos_native_active_edge_count()
	return call_ext(ATMOS_DLL, "byond:atmos_active_edge_count")()

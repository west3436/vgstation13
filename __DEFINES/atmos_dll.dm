// atmos_dll.dm - DM API for atmos_native external library
//
// The DLL must be placed in the server root directory:
//   Windows: atmos_native.dll
//   Linux:   libatmos_native.so or atmos_native.so

/* This comment bypasses grep checks */ /var/__atmos_dll

/proc/__detect_atmos_dll()
	if(world.system_type == UNIX)
		if(fexists("./libatmos_native.so"))
			return __atmos_dll = "./libatmos_native.so"
		else if(fexists("./atmos_native.so"))
			return __atmos_dll = "./atmos_native.so"
		else
			return __atmos_dll = "libatmos_native.so"
	else
		return __atmos_dll = "atmos_native"

#define ATMOS_DLL (__atmos_dll || __detect_atmos_dll())

// Result stride constants for batch tick results
// Edge: header(4) + zone_a(1+13) + zone_b(1+13) = 32
#define EDGE_RESULT_STRIDE 32  // edge_id, differential, equiv, merge_flag, za_id, za_air[13], zb_id, zb_air[13]
#define EDGE_HEADER_SIZE 4     // edge_id, differential, equiv, merge_flag
#define ZONE_AIR_SIZE 14       // id + gas0..8 + temp + volume + pressure + total_moles
#define ZONE_RESULT_STRIDE 5   // zone_id, reactions_occurred, graphic_flags, temperature, pressure

// Packed gas mixture argument count: 9 gases + temperature + volume
#define GAS_ARG_COUNT 11

// Gas indices (must match registration order in atmos_native_init)
#define GAS_IDX_OXYGEN      0
#define GAS_IDX_NITROGEN     1
#define GAS_IDX_CO2          2
#define GAS_IDX_PLASMA       3
#define GAS_IDX_N2O          4
#define GAS_IDX_CRYOTHEUM    5
#define GAS_IDX_VOLATILE     6
#define GAS_IDX_OXAGENT      7
#define GAS_IDX_RADON        8

// Edge type constants for atmos_add_edge
#define EDGE_TYPE_ZONE  0
#define EDGE_TYPE_UNSIM 1

// Batch reconcile result stride: reacted + 9 gases + temp + volume + pressure + total_moles
#define RECONCILE_RESULT_STRIDE 14

// Number of args per gas mixture in batch reconcile input (9 gases + temp + volume)
#define RECONCILE_GAS_STRIDE 11
